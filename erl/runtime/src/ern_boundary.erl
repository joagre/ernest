%% Report §4.7, §8.4, §7.4: the foreign boundary. A foreign function is
%% called in place, in the code the compiler writes, inside a catch whose
%% exception raised/6 turns into a fault; its return is checked against the
%% declared type on first observation, as an answer foreign code gives is
%% (ern_rt). What crosses into foreign code, a foreign function's argument,
%% a message sent to a foreign address, or an answer given to a Reply
%% foreign code gave, is exposed: every Ernest address
%% in it is replaced by a proxy that checks each message the foreign side
%% sends against the address's mailbox type on delivery and forwards it, or
%% ends the target with the fault. An address that comes from foreign code
%% and names no process of the program is held as foreign, {foreign, Pid,
%% D, B}, D its messages' descriptor, so that what is sent to it is
%% exposed, and a Reply as {foreign_reply, Alias, D, B}, D its answer's
%% descriptor, so that its answer is exposed, given in foreign code's form,
%% and checked. The compiler describes a type as a term this module
%% interprets:
%% any | int | float | bool | char | string | bytes | {address, D, Text} | {reply, D, Text}
%% | process | {'fun', Arity, R, Text, Make, Exposer} | {'fun', Arity, R, Text, Ps, Texts}
%% | never | {list, D} | {tuple, [D]} | {map, K, V} | {set, D}
%% | {con, [{Tag, [D]} | {Tag, [D], [Name]}]} | {abstract, D} | {mu, Id, D} | {ref, Id},
%% mu binding Id for the ref inside it, which is how a recursive type is
%% described once; {address, D, Text} is an address whose messages D
%% describes, and {reply, D, Text} a Reply whose answer D describes; a
%% constructor with named fields carries their names, and an abstract type
%% seen from outside its module is wrapped, both for printing (ern_show).
%% A function's R describes its result, and Make wraps a function value,
%% given R closed over the recursive types around it, so that each call's
%% result is checked against R, faulting with Text (report §7.4); the
%% descriptors `Io.show` and `Io.debug` print by carry no Make, since
%% nothing is checked there. A function given to foreign code is
%% {callback, Make}, Make wrapping it to check each argument foreign code
%% calls it with (report §8.4).
-module(ern_boundary).

-export([raised/6, called_raised/3, expose/2, check/3, value/3, argument/4, expose/3]).

%% Report §7.4: an exception foreign function HostModule:HostFunction/Arity
%% raised, a fault of the calling process that names the implementation;
%% an Ernest fault raised inside foreign code, by a function it was given,
%% passes through as itself.
-spec raised(module(), atom(), arity(), error | exit | throw, term(), list()) -> no_return().
raised(_, _, _, throw, {ern, _, _} = Passing, _) ->
    throw(Passing);
raised(_, _, _, throw, {ern, _, _, _} = Passing, _) ->
    throw(Passing);
%% report §6.9: a restart asked for inside it is a restart
raised(_, _, _, throw, '$ern_restart', _) ->
    throw('$ern_restart');
raised(HostModule, HostFunction, Arity, Class, Error, Stack) ->
    ern_rt:fault(unicode:characters_to_binary(
                   io_lib:format("foreign function ~s:~s/~B raised ~p:~p",
                                 [HostModule, HostFunction, Arity, Class, Error])),
                 ern_rt:trace(Stack)).

%% Report §7.4: an exception a function of the program's raised where
%% foreign code called it is the fault it would be anywhere, raised again
%% as that fault, so that it passes through the foreign function as
%% itself; a restart asked for there stays one (§6.9).
-spec called_raised(error | exit | throw, term(), list()) -> no_return().
called_raised(throw, '$ern_restart', _) ->
    throw('$ern_restart');
called_raised(Class, Error, Stack) ->
    throw(ern_rt:fault_exit_reason(Class, Error, Stack)).

%% An argument given to foreign code (report §8.4): every address inside it
%% replaced by the proxy that checks what foreign code sends it, and a
%% function wrapped to check the arguments foreign code calls it with.
-spec expose(term(), term()) -> term().
expose(Descriptor, Value) ->
    expose(Descriptor, Value, #{}).

%% The value, or the fault Text (report §7.4), where the descriptor holds
%% no function, no address, no Reply and no float, so that the checked
%% value is the value itself.
-spec check(term(), term(), binary()) -> term().
check(Descriptor, Value, Text) ->
    case matches(Descriptor, Value, #{}) of
        true -> Value;
        false -> ern_rt:fault(Text)
    end.

%% The value, or the fault Text (report §7.4). A descriptor that is a word
%% describes a value with no function in it and nothing to make zero but a
%% float itself, so it is checked alone.
-spec value(term(), term(), binary()) -> term().
value(Descriptor, Value, Text) when is_atom(Descriptor) ->
    case matches(Descriptor, Value, #{}) of
        true when Descriptor =:= float -> Value + 0.0;
        true -> Value;
        false -> ern_rt:fault(Text)
    end;
value(Descriptor, Value, Text) ->
    case matches(Descriptor, Value, #{}) of
        true -> armed(Descriptor, zeroed(Descriptor, Value), #{});
        false -> ern_rt:fault(Text)
    end.

%% Report §8.4: an argument foreign code calls a function of the program's
%% with, where the function stood inside what crossed, the recursive types
%% around it in Bound: the value as the program holds it, or the fault
%% Text.
-spec argument(term(), term(), binary(), map()) -> term().
argument(Descriptor, Value, Text, Bound) ->
    case matches(Descriptor, Value, Bound) of
        true -> armed(Descriptor, zeroed(Descriptor, Value, Bound), Bound);
        false -> ern_rt:fault(Text)
    end.

%% Report §7.4, §8.4: a checked value from foreign code as the program
%% holds it: every function value in it wrapped so that its result is
%% checked at each call, and every address in it that names no process of
%% the program, and every Reply, held as foreign.
armed(Descriptor, Value, Bound) ->
    case lists:any(fun needs_arming/1, [Descriptor | maps:values(Bound)]) of
        true -> arm(Descriptor, Value, Bound);
        false -> Value
    end.

needs_arming({'fun', _, _, _, _, _}) -> true;
needs_arming({address, _, _}) -> true;
needs_arming({reply, _, _}) -> true;
needs_arming(Part) when is_tuple(Part) -> lists:any(fun needs_arming/1, tuple_to_list(Part));
needs_arming(Parts) when is_list(Parts) -> lists:any(fun needs_arming/1, Parts);
needs_arming(_) -> false.

arm({'fun', _, ResultDescriptor, _, Make, _}, Value, Bound) ->
    Make(Value, closed(ResultDescriptor, Bound));
arm({address, MessageDescriptor, _}, Value, Bound) when is_pid(Value) ->
    ern_rt:held(Value, MessageDescriptor, Bound);
arm({reply, AnswerDescriptor, _}, Value, Bound) when is_reference(Value) ->
    {foreign_reply, Value, AnswerDescriptor, Bound};
arm({list, Element}, Value, Bound) -> [arm(Element, Item, Bound) || Item <- Value];
arm({tuple, Elements}, Value, Bound) ->
    list_to_tuple([arm(Element, Item, Bound)
                   || {Element, Item} <- lists:zip(Elements, tuple_to_list(Value))]);
arm({map, _, Element}, Value, Bound) ->
    maps:map(fun(_, Item) -> arm(Element, Item, Bound) end, Value);
arm({con, Constructors}, Value, Bound) when is_tuple(Value) ->
    [Tag | Fields] = tuple_to_list(Value),
    Descriptors = constructor_fields(Tag, Constructors),
    list_to_tuple([Tag | [arm(Field, Item, Bound)
                          || {Field, Item} <- lists:zip(Descriptors, Fields)]]);
arm({abstract, Descriptor}, Value, Bound) -> arm(Descriptor, Value, Bound);
arm({mu, Id, Descriptor}, Value, Bound) -> arm(Descriptor, Value, Bound#{Id => Descriptor});
arm({ref, Id}, Value, Bound) -> arm(maps:get(Id, Bound), Value, Bound);
arm(_, Value, _) -> Value.

%% Report §7.4: a result's descriptor as the wrapper checks it at each call,
%% where no mu around it binds its refs any more: each ref free in it is its
%% mu again, which binds the refs inside it.
closed({ref, Id} = Descriptor, Bound) ->
    case Bound of
        #{Id := Body} -> {mu, Id, Body};
        _ -> Descriptor
    end;
closed({mu, Id, Descriptor}, Bound) -> {mu, Id, closed(Descriptor, maps:remove(Id, Bound))};
closed(Part, Bound) when is_tuple(Part) ->
    list_to_tuple([closed(Inner, Bound) || Inner <- tuple_to_list(Part)]);
closed(Parts, Bound) when is_list(Parts) -> [closed(Inner, Bound) || Inner <- Parts];
closed(Other, _) -> Other.

%% Report §3.1: a float entering from foreign code, the runtime's negative
%% zero among them, is the language's; X + 0.0 is 0.0 for either zero and
%% X otherwise. The value is already checked against the descriptor.
zeroed(Descriptor, Value) -> zeroed(Descriptor, Value, #{}).

zeroed(Descriptor, Value, Bound) ->
    case has_float([Descriptor | maps:values(Bound)]) of
        true -> zero(Descriptor, Value, Bound);
        false -> Value
    end.

has_float(float) -> true;
has_float(Part) when is_tuple(Part) -> lists:any(fun has_float/1, tuple_to_list(Part));
has_float(Parts) when is_list(Parts) -> lists:any(fun has_float/1, Parts);
has_float(_) -> false.

zero(float, Value, _) -> Value + 0.0;
zero({list, Element}, Value, Bound) -> [zero(Element, Item, Bound) || Item <- Value];
zero({tuple, Elements}, Value, Bound) ->
    list_to_tuple([zero(Element, Item, Bound)
                   || {Element, Item} <- lists:zip(Elements, tuple_to_list(Value))]);
zero({map, KeyDescriptor, ValueDescriptor}, Value, Bound) ->
    maps:from_list([{zero(KeyDescriptor, Key, Bound), zero(ValueDescriptor, Item, Bound)}
                    || {Key, Item} <- maps:to_list(Value)]);
zero({set, Element}, {set, Elements}, Bound) ->
    {set, maps:from_list([{zero(Element, Item, Bound), []} || Item <- maps:keys(Elements)])};
zero({con, Constructors}, Value, Bound) when is_tuple(Value) ->
    [Tag | Fields] = tuple_to_list(Value),
    Descriptors = constructor_fields(Tag, Constructors),
    list_to_tuple([Tag | [zero(Field, Item, Bound)
                          || {Field, Item} <- lists:zip(Descriptors, Fields)]]);
zero({abstract, Descriptor}, Value, Bound) -> zero(Descriptor, Value, Bound);
zero({mu, Id, Descriptor}, Value, Bound) -> zero(Descriptor, Value, Bound#{Id => Descriptor});
zero({ref, Id}, Value, Bound) -> zero(maps:get(Id, Bound), Value, Bound);
zero(_, Value, _) -> Value.

%% Whether Value is one Descriptor describes, inside the mu bindings Bound.
matches(any, _, _) -> true;
matches(foreign, _, _) -> true;
matches(int, Value, _) -> is_integer(Value);
matches(float, Value, _) -> is_float(Value);
matches(bool, Value, _) -> is_boolean(Value);
matches(char, Value, _) ->
    is_integer(Value) andalso Value >= 0 andalso Value =< 16#10FFFF
        andalso (Value < 16#D800 orelse Value > 16#DFFF);
matches(string, Value, _) -> is_binary(Value) andalso unicode:characters_to_binary(Value) =:= Value;
matches(bytes, Value, _) -> is_binary(Value);
%% an answer checked because its Reply crossed may be Ernest's own, which
%% holds an address in any of its forms
matches({address, _, _}, Value, _) -> ern_rt:is_address(Value);
matches({reply, _, _}, Value, _) when is_reference(Value) -> true;
matches({reply, _, _}, {foreign_reply, Value, _, _}, _) -> is_reference(Value);
matches({reply, _, _}, _, _) -> false;
matches(process, Value, _) -> is_pid(Value);
matches({'fun', Arity, _, _, _, _}, Value, _) -> is_function(Value, Arity);
matches(never, _, _) -> false;
matches({list, Element}, Value, Bound) ->
    is_list(Value) andalso elements_match(Element, Value, Bound);
matches({tuple, Elements}, Value, Bound) ->
    is_tuple(Value) andalso tuple_size(Value) =:= length(Elements)
        andalso pairwise_match(Elements, tuple_to_list(Value), Bound);
%% a type variable a parameter names matches any value (report §8.4), so a
%% map of such keys and values is checked alone, and a put costs what the
%% host's does
matches({map, any, any}, Value, _) -> is_map(Value);
matches({map, KeyDescriptor, ValueDescriptor}, Value, Bound) ->
    is_map(Value) andalso maps:fold(fun(Key, Item, Acc) ->
                                        Acc andalso matches(KeyDescriptor, Key, Bound)
                                            andalso matches(ValueDescriptor, Item, Bound)
                                    end, true, Value);
matches({set, Element}, {set, Elements}, Bound) ->
    %% a version 2 set is a map from element to [], tagged (ern@set)
    is_map(Elements) andalso maps:fold(fun(Item, Mark, Acc) ->
                                           Acc andalso Mark =:= []
                                               andalso matches(Element, Item, Bound)
                                       end, true, Elements);
matches({set, _}, _, _) ->
    false;
matches({con, Constructors}, Value, _) when is_atom(Value) ->
    constructor_fields(Value, Constructors) =:= [];
matches({con, Constructors}, Value, Bound)
  when is_tuple(Value), tuple_size(Value) > 1, is_atom(element(1, Value)) ->
    [Tag | Fields] = tuple_to_list(Value),
    case constructor_fields(Tag, Constructors) of
        Descriptors when is_list(Descriptors), length(Descriptors) =:= length(Fields) ->
            pairwise_match(Descriptors, Fields, Bound);
        _ ->
            false
    end;
matches({con, _}, _, _) -> false;
matches({abstract, Descriptor}, Value, Bound) -> matches(Descriptor, Value, Bound);
matches({mu, Id, Descriptor}, Value, Bound) -> matches(Descriptor, Value, Bound#{Id => Descriptor});
matches({ref, Id}, Value, Bound) -> matches(maps:get(Id, Bound), Value, Bound).

%% The field descriptors of constructor Tag, or false.
-spec constructor_fields(atom(), list()) -> [term()] | false.
constructor_fields(Tag, Constructors) ->
    case lists:keyfind(Tag, 1, Constructors) of
        {_, Descriptors} -> Descriptors;
        {_, Descriptors, _} -> Descriptors;
        false -> false
    end.

pairwise_match([], [], _) -> true;
pairwise_match([Descriptor | Descriptors], [Value | Values], Bound) ->
    matches(Descriptor, Value, Bound) andalso pairwise_match(Descriptors, Values, Bound).

%% Every element of a list checked against Element, the list proper
%% (report §8.4: a List is a list); an improper one does not match. A list
%% of values a parameter's type variable names is only walked.
elements_match(_, [], _) -> true;
elements_match(Element, [_ | Items], Bound) when Element =:= any; Element =:= foreign ->
    elements_match(Element, Items, Bound);
elements_match(Element, [Item | Items], Bound) ->
    matches(Element, Item, Bound) andalso elements_match(Element, Items, Bound);
elements_match(_, _, _) -> false.

%% What crosses into foreign code, exposed where mu bindings Bound are in
%% scope: a foreign function's argument, a message sent to a foreign
%% address, and an answer given to a Reply foreign code gave, whose
%% descriptor was read inside them.
-spec expose(term(), term(), map()) -> term().
%% report §8.4: a function given to foreign code checks the arguments it is
%% called with, whether it is the argument or stands in one, in a message
%% or in an answer
expose({callback, Make}, Value, _) when is_function(Value) -> Make(Value);
expose({'fun', _, _, _, _, Exposer}, Value, Bound) when is_function(Value) ->
    Exposer(Value, Bound);
expose({address, MessageDescriptor, Text}, Value, Bound) when is_pid(Value) ->
    proxy(Value, MessageDescriptor, Bound, Text);
%% report §6.5: an address seen through a function is an address too, and
%% foreign code must reach it through the same checking proxy
expose({address, MessageDescriptor, Text}, {via, _, _} = Value, Bound) ->
    proxy(Value, MessageDescriptor, Bound, Text);
%% an address foreign code gave goes back to it as it came
expose({address, _, _}, {foreign, Pid, _, _}, _) -> Pid;
%% a Reply foreign code gave goes back to it as it came
expose({reply, _, _}, {foreign_reply, Reply, _, _}, _) -> Reply;
expose({list, Element}, Value, Bound) when is_list(Value) ->
    [expose(Element, Item, Bound) || Item <- Value];
expose({tuple, Elements}, Value, Bound)
  when is_tuple(Value), tuple_size(Value) =:= length(Elements) ->
    list_to_tuple([expose(Element, Item, Bound)
                   || {Element, Item} <- lists:zip(Elements, tuple_to_list(Value))]);
expose({map, _, Element}, Value, Bound) when is_map(Value) ->
    maps:map(fun(_, Item) -> expose(Element, Item, Bound) end, Value);
expose({con, Constructors}, Value, Bound) when is_tuple(Value), tuple_size(Value) > 1 ->
    [Tag | Fields] = tuple_to_list(Value),
    case constructor_fields(Tag, Constructors) of
        Descriptors when is_list(Descriptors), length(Descriptors) =:= length(Fields) ->
            list_to_tuple([Tag | [expose(Field, Item, Bound)
                                  || {Field, Item} <- lists:zip(Descriptors, Fields)]]);
        _ ->
            Value
    end;
expose({abstract, Descriptor}, Value, Bound) -> expose(Descriptor, Value, Bound);
expose({mu, Id, Descriptor}, Value, Bound) -> expose(Descriptor, Value, Bound#{Id => Descriptor});
expose({ref, Id}, Value, Bound) -> expose(maps:get(Id, Bound), Value, Bound);
expose(_, Value, _) -> Value.

%% The proxy lives as long as the address it stands before, and there is
%% one of it per address and mailbox type however often the address is
%% exposed; a message that does not match ends the process behind the
%% address with the fault, as its own receive would have.
proxy(Behind, MessageDescriptor, Bound, Text) ->
    Key = {Behind, MessageDescriptor, Bound},
    ern_rt:proxy_for(Key, Behind,
                     fun() -> start_proxy(Key, Behind, MessageDescriptor, Bound, Text) end).

start_proxy(Key, Behind, MessageDescriptor, Bound, Text) ->
    erlang:spawn(fun() ->
                     MonitorRef = erlang:monitor(process, ern_rt:process_of(Behind)),
                     proxy_loop(Key, Behind, MonitorRef, MessageDescriptor, Bound, Text)
                 end).

proxy_loop(Key, Behind, MonitorRef, Descriptor, Bound, Text) ->
    receive
        {'DOWN', MonitorRef, process, _, _} ->
            ern_rt:proxy_forget(Key, erlang:self()),
            ok;
        Message ->
            case matches(Descriptor, Message, Bound) of
                true ->
                    Zeroed = zeroed(Descriptor, Message, Bound),
                    ern_rt:send(Behind, armed(Descriptor, Zeroed, Bound));
                false -> exit(ern_rt:process_of(Behind), {ern, fault, Text})
            end,
            proxy_loop(Key, Behind, MonitorRef, Descriptor, Bound, Text)
    end.
