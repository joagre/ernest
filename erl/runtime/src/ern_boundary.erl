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
%% any | int | float | bool | char | string | bytes | {pid, D, Text} | {reply, D, Text} | process
%% | {'fun', Arity, R, Text, Make, Exposer} | {'fun', Arity, R, Text, Ps, Texts} | never | {list, D}
%% | {tuple, [D]} | {map, K, V} | {set, D} | {con, [{Tag, [D]} | {Tag, [D], [Name]}]}
%% | {abstract, D} | {mu, Id, D} | {ref, Id}, mu binding Id for the ref inside it, which is
%% how a recursive type is described once; {pid, D, Text} is an address
%% whose messages D describes, and {reply, D, Text} a Reply whose answer D
%% describes; a constructor with named fields carries
%% their names, and an abstract type seen from outside its module is
%% wrapped, both for printing (ern_show). A function's R describes its
%% result, and Make wraps a function value, given R closed over the
%% recursive types around it, so that each call's result is checked against
%% R, faulting with Text (report §7.4); the descriptors `Io.show` and
%% `Io.debug` print by carry no Make, since nothing is checked there. A
%% function given to foreign code is {callback, Make}, Make wrapping it to
%% check each argument foreign code calls it with (report §8.4).
-module(ern_boundary).

-export([raised/6, called_raised/3, expose/2, check/3, value/3, argument/4, expose/3]).

%% Report §7.4: an exception foreign function M:F/Arity raised, a fault of
%% the calling process that names the implementation; an Ernest fault
%% raised inside foreign code, by a function it was given, passes through
%% as itself.
-spec raised(module(), atom(), arity(), error | exit | throw, term(), list()) -> no_return().
raised(_, _, _, throw, {ern, _, _} = Passing, _) ->
    throw(Passing);
raised(_, _, _, throw, {ern, _, _, _} = Passing, _) ->
    throw(Passing);
%% report §6.9: a restart asked for inside it is a restart
raised(_, _, _, throw, '$ern_restart', _) ->
    throw('$ern_restart');
raised(M, F, Arity, Class, Reason, Stack) ->
    ern_rt:fault(unicode:characters_to_binary(
                   io_lib:format("foreign function ~s:~s/~B raised ~p:~p",
                                 [M, F, Arity, Class, Reason])),
                 ern_rt:trace(Stack)).

%% Report §7.4: an exception a function of the program's raised where
%% foreign code called it is the fault it would be anywhere, raised again
%% as that fault, so that it passes through the foreign function as
%% itself; a restart asked for there stays one (§6.9).
-spec called_raised(error | exit | throw, term(), list()) -> no_return().
called_raised(throw, '$ern_restart', _) ->
    throw('$ern_restart');
called_raised(Class, Reason, Stack) ->
    throw(ern_rt:fault_reason(Class, Reason, Stack)).

%% An argument given to foreign code (report §8.4): every address inside it
%% replaced by the proxy that checks what foreign code sends it, and a
%% function wrapped to check the arguments foreign code calls it with.
-spec expose(term(), term()) -> term().
expose(Desc, V) ->
    expose(Desc, V, #{}).

%% The value, or the fault Text (report §7.4), where the descriptor holds
%% no function, no address, no Reply and no float, so that the checked
%% value is the value itself.
-spec check(term(), term(), binary()) -> term().
check(Desc, V, Text) ->
    case chk(Desc, V, #{}) of
        true -> V;
        false -> ern_rt:fault(Text)
    end.

%% The value, or the fault Text (report §7.4). A descriptor that is a word
%% describes a value with no function in it and nothing to make zero but a
%% float itself, so it is checked alone.
-spec value(term(), term(), binary()) -> term().
value(Desc, V, Text) when is_atom(Desc) ->
    case chk(Desc, V, #{}) of
        true when Desc =:= float -> V + 0.0;
        true -> V;
        false -> ern_rt:fault(Text)
    end;
value(Desc, V, Text) ->
    case chk(Desc, V, #{}) of
        true -> armed(Desc, zeroed(Desc, V), #{});
        false -> ern_rt:fault(Text)
    end.

%% Report §8.4: an argument foreign code calls a function of the program's
%% with, where the function stood inside what crossed, the recursive types
%% around it in B: the value as the program holds it, or the fault Text.
-spec argument(term(), term(), binary(), map()) -> term().
argument(Desc, V, Text, B) ->
    case chk(Desc, V, B) of
        true -> armed(Desc, zeroed(Desc, V, B), B);
        false -> ern_rt:fault(Text)
    end.

%% Report §7.4, §8.4: a checked value from foreign code as the program
%% holds it: every function value in it wrapped so that its result is
%% checked at each call, and every address in it that names no process of
%% the program, and every Reply, held as foreign.
armed(D, V, B) ->
    case lists:any(fun arms/1, [D | maps:values(B)]) of
        true -> arm(D, V, B);
        false -> V
    end.

arms({'fun', _, _, _, _, _}) -> true;
arms({pid, _, _}) -> true;
arms({reply, _, _}) -> true;
arms(T) when is_tuple(T) -> lists:any(fun arms/1, tuple_to_list(T));
arms(L) when is_list(L) -> lists:any(fun arms/1, L);
arms(_) -> false.

arm({'fun', _, R, _, Make, _}, V, B) -> Make(V, closed(R, B));
arm({pid, D, _}, V, B) when is_pid(V) -> ern_rt:held(V, D, B);
arm({reply, D, _}, V, B) when is_reference(V) -> {foreign_reply, V, D, B};
arm({list, D}, V, B) -> [arm(D, X, B) || X <- V];
arm({tuple, Ds}, V, B) ->
    list_to_tuple([arm(D, X, B) || {D, X} <- lists:zip(Ds, tuple_to_list(V))]);
arm({map, _, D}, V, B) -> maps:map(fun(_, X) -> arm(D, X, B) end, V);
arm({con, Cs}, V, B) when is_tuple(V) ->
    Ds = con_fields(element(1, V), Cs),
    list_to_tuple([element(1, V) | [arm(D, X, B)
                                    || {D, X} <- lists:zip(Ds, tl(tuple_to_list(V)))]]);
arm({abstract, D}, V, B) -> arm(D, V, B);
arm({mu, Id, D}, V, B) -> arm(D, V, B#{Id => D});
arm({ref, Id}, V, B) -> arm(maps:get(Id, B), V, B);
arm(_, V, _) -> V.

%% Report §7.4: a result's descriptor as the wrapper checks it at each call,
%% where no mu around it binds its refs any more: each ref free in it is its
%% mu again, which binds the refs inside it.
closed({ref, Id} = D, B) ->
    case B of
        #{Id := Body} -> {mu, Id, Body};
        _ -> D
    end;
closed({mu, Id, D}, B) -> {mu, Id, closed(D, maps:remove(Id, B))};
closed(T, B) when is_tuple(T) -> list_to_tuple([closed(E, B) || E <- tuple_to_list(T)]);
closed(L, B) when is_list(L) -> [closed(E, B) || E <- L];
closed(X, _) -> X.

%% Report §3.1: a float entering from foreign code, the runtime's negative
%% zero among them, is the language's; X + 0.0 is 0.0 for either zero and
%% X otherwise. The value is already checked against D.
zeroed(D, V) -> zeroed(D, V, #{}).

zeroed(D, V, B) ->
    case has_float([D | maps:values(B)]) of
        true -> zero(D, V, B);
        false -> V
    end.

has_float(float) -> true;
has_float(T) when is_tuple(T) -> lists:any(fun has_float/1, tuple_to_list(T));
has_float(L) when is_list(L) -> lists:any(fun has_float/1, L);
has_float(_) -> false.

zero(float, V, _) -> V + 0.0;
zero({list, D}, V, B) -> [zero(D, X, B) || X <- V];
zero({tuple, Ds}, V, B) ->
    list_to_tuple([zero(D, X, B) || {D, X} <- lists:zip(Ds, tuple_to_list(V))]);
zero({map, K, D}, V, B) -> maps:from_list([{zero(K, Key, B), zero(D, X, B)}
                                          || {Key, X} <- maps:to_list(V)]);
zero({set, D}, {set, S}, B) -> {set, maps:from_list([{zero(D, X, B), []}
                                                    || X <- maps:keys(S)])};
zero({con, Cs}, V, B) when is_tuple(V) ->
    Ds = con_fields(element(1, V), Cs),
    list_to_tuple([element(1, V) | [zero(D, X, B)
                                    || {D, X} <- lists:zip(Ds, tl(tuple_to_list(V)))]]);
zero({abstract, D}, V, B) -> zero(D, V, B);
zero({mu, Id, D}, V, B) -> zero(D, V, B#{Id => D});
zero({ref, Id}, V, B) -> zero(maps:get(Id, B), V, B);
zero(_, V, _) -> V.

chk(any, _, _) -> true;
chk(foreign, _, _) -> true;
chk(int, V, _) -> is_integer(V);
chk(float, V, _) -> is_float(V);
chk(bool, V, _) -> is_boolean(V);
chk(char, V, _) ->
    is_integer(V) andalso V >= 0 andalso V =< 16#10FFFF andalso (V < 16#D800 orelse V > 16#DFFF);
chk(string, V, _) -> is_binary(V) andalso unicode:characters_to_binary(V) =:= V;
chk(bytes, V, _) -> is_binary(V);
%% an answer checked because its Reply crossed may be Ernest's own, which
%% holds an address in any of its forms
chk({pid, _, _}, V, _) -> ern_rt:is_address(V);
chk({reply, _, _}, V, _) when is_reference(V) -> true;
chk({reply, _, _}, {foreign_reply, V, _, _}, _) -> is_reference(V);
chk({reply, _, _}, _, _) -> false;
chk(process, V, _) -> is_pid(V);
chk({'fun', N, _, _, _, _}, V, _) -> is_function(V, N);
chk(never, _, _) -> false;
chk({list, D}, V, B) -> is_list(V) andalso every(D, V, B);
chk({tuple, Ds}, V, B) ->
    is_tuple(V) andalso tuple_size(V) =:= length(Ds) andalso all(Ds, tuple_to_list(V), B);
%% a type variable a parameter names matches any value (report §8.4), so a
%% map of such keys and values is checked alone, and a put costs what the
%% host's does
chk({map, any, any}, V, _) -> is_map(V);
chk({map, K, D}, V, B) ->
    is_map(V) andalso maps:fold(fun(Key, Val, Ok) ->
                                    Ok andalso chk(K, Key, B) andalso chk(D, Val, B)
                                end, true, V);
chk({set, D}, {set, V}, B) ->
    %% a version 2 set is a map from element to [], tagged (ern@set)
    is_map(V) andalso maps:fold(fun(E, Val, Ok) -> Ok andalso Val =:= [] andalso chk(D, E, B)
                                end, true, V);
chk({set, _}, _, _) ->
    false;
chk({con, Cs}, V, _) when is_atom(V) ->
    con_fields(V, Cs) =:= [];
chk({con, Cs}, V, B) when is_tuple(V), tuple_size(V) > 1, is_atom(element(1, V)) ->
    case con_fields(element(1, V), Cs) of
        Ds when is_list(Ds), length(Ds) =:= tuple_size(V) - 1 -> all(Ds, tl(tuple_to_list(V)), B);
        _ -> false
    end;
chk({con, _}, _, _) -> false;
chk({abstract, D}, V, B) -> chk(D, V, B);
chk({mu, Id, D}, V, B) -> chk(D, V, B#{Id => D});
chk({ref, Id}, V, B) -> chk(maps:get(Id, B), V, B).

%% The field descriptors of constructor Tag, or false.
-spec con_fields(atom(), list()) -> [term()] | false.
con_fields(Tag, Cs) ->
    case lists:keyfind(Tag, 1, Cs) of
        {_, Ds} -> Ds;
        {_, Ds, _} -> Ds;
        false -> false
    end.

all([], [], _) -> true;
all([D | Ds], [V | Vs], B) -> chk(D, V, B) andalso all(Ds, Vs, B).

%% Every element of a list checked against D, the list proper (report §8.4:
%% a List is a list); an improper one does not match. A list of values a
%% parameter's type variable names is only walked.
every(_, [], _) -> true;
every(D, [_ | Xs], B) when D =:= any; D =:= foreign -> every(D, Xs, B);
every(D, [X | Xs], B) -> chk(D, X, B) andalso every(D, Xs, B);
every(_, _, _) -> false.

%% What crosses into foreign code, exposed where mu bindings B are in scope:
%% a foreign function's argument, a message sent to a foreign address, and
%% an answer given to a Reply foreign code gave, whose descriptor was read
%% inside them.
-spec expose(term(), term(), map()) -> term().
%% report §8.4: a function given to foreign code checks the arguments it is
%% called with, whether it is the argument or stands in one, in a message
%% or in an answer
expose({callback, Make}, V, _) when is_function(V) -> Make(V);
expose({'fun', _, _, _, _, Exposer}, V, B) when is_function(V) -> Exposer(V, B);
expose({pid, D, Text}, V, B) when is_pid(V) -> proxy(V, D, B, Text);
%% report §6.5: an address seen through a function is an address too, and
%% foreign code must reach it through the same checking proxy
expose({pid, D, Text}, {via, _, _} = V, B) -> proxy(V, D, B, Text);
%% an address foreign code gave goes back to it as it came
expose({pid, _, _}, {foreign, Pid, _, _}, _) -> Pid;
%% a Reply foreign code gave goes back to it as it came
expose({reply, _, _}, {foreign_reply, Alias, _, _}, _) -> Alias;
expose({list, D}, V, B) when is_list(V) -> [expose(D, X, B) || X <- V];
expose({tuple, Ds}, V, B) when is_tuple(V), tuple_size(V) =:= length(Ds) ->
    list_to_tuple([expose(D, X, B) || {D, X} <- lists:zip(Ds, tuple_to_list(V))]);
expose({map, _, D}, V, B) when is_map(V) -> maps:map(fun(_, X) -> expose(D, X, B) end, V);
expose({con, Cs}, V, B) when is_tuple(V), tuple_size(V) > 1 ->
    case con_fields(element(1, V), Cs) of
        Ds when is_list(Ds), length(Ds) =:= tuple_size(V) - 1 ->
            Fields = lists:zip(Ds, tl(tuple_to_list(V))),
            list_to_tuple([element(1, V) | [expose(D, X, B) || {D, X} <- Fields]]);
        _ -> V
    end;
expose({abstract, D}, V, B) -> expose(D, V, B);
expose({mu, Id, D}, V, B) -> expose(D, V, B#{Id => D});
expose({ref, Id}, V, B) -> expose(maps:get(Id, B), V, B);
expose(_, V, _) -> V.

%% The proxy lives as long as the target, and there is one of it per
%% address and mailbox type however often the address is exposed; a message
%% that does not match ends the target with the fault, as its own receive
%% would have.
proxy(Target, D, B, Text) ->
    Key = {Target, D, B},
    ern_rt:proxy_for(Key, Target, fun() -> start_proxy(Key, Target, D, B, Text) end).

start_proxy(Key, Target, D, B, Text) ->
    erlang:spawn(fun() ->
                     MRef = erlang:monitor(process, ern_rt:process_of(Target)),
                     proxy_loop(Key, Target, MRef, D, B, Text)
                 end).

proxy_loop(Key, Target, MRef, D, B, Text) ->
    receive
        {'DOWN', MRef, process, _, _} ->
            ern_rt:proxy_forget(Key, erlang:self()),
            ok;
        Msg ->
            case chk(D, Msg, B) of
                true -> ern_rt:send(Target, armed(D, zeroed(D, Msg, B), B));
                false -> exit(ern_rt:process_of(Target), {ern, fault, Text})
            end,
            proxy_loop(Key, Target, MRef, D, B, Text)
    end.
