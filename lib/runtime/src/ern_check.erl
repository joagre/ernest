%% Report §4.7, §8.4, §7.4: the foreign boundary. A foreign function is
%% called inside a catch that turns an exception into a fault; its return
%% and a reply are checked against the declared type on first observation;
%% and every Ernest address among its arguments is replaced by a proxy
%% that checks each message the foreign side sends against the address's
%% mailbox type on delivery and forwards it, or ends the target with the
%% fault. The compiler describes a type as a term this module interprets:
%% any | int | float | bool | char | string | bytes | {pid, D, Text} | ref
%% | {'fun', Arity} | never | {list, D} | {tuple, [D]} | {map, K, V}
%% | {set, D} | {con, [{Tag, [D]} | {Tag, [D], [Name]}]} | {abstract, D}
%% | {mu, Id, D} | {ref, Id}, mu binding Id for the ref inside it, which is
%% how a recursive type is described once; {pid, D, Text} is an address
%% whose messages D describes; a constructor with named fields carries
%% their names, and an abstract type seen from outside its module is
%% wrapped, both for printing (ern_show).
-module(ern_check).

-export([foreign/6, value/3]).

-spec foreign(module(), atom(), [term()], [term()], term(), binary()) -> term().
foreign(M, F, Args, ArgDescs, Desc, Text) ->
    Exposed = [expose(D, A, #{}) || {D, A} <- lists:zip(ArgDescs, Args)],
    V = try ern_rt:in_foreign(fun() -> apply(M, F, Exposed) end)
        catch
            throw:{ernest, _, _} = Passing -> throw(Passing);
            Class:Reason ->
                ern_rt:fault(unicode:characters_to_binary(
                               io_lib:format("foreign function ~s:~s/~B raised ~p:~p",
                                             [M, F, length(Args), Class, Reason])))
        end,
    value(Desc, V, Text).

%% The value, or the fault Text (report §7.4).
-spec value(term(), term(), binary()) -> term().
value(Desc, V, Text) ->
    case chk(Desc, V, #{}) of
        true -> V;
        false -> ern_rt:fault(Text)
    end.

chk(any, _, _) -> true;
chk(int, V, _) -> is_integer(V);
chk(float, V, _) -> is_float(V);
chk(bool, V, _) -> is_boolean(V);
chk(char, V, _) ->
    is_integer(V) andalso V >= 0 andalso V =< 16#10FFFF andalso (V < 16#D800 orelse V > 16#DFFF);
chk(string, V, _) -> is_binary(V) andalso unicode:characters_to_binary(V) =:= V;
chk(bytes, V, _) -> is_binary(V);
chk({pid, _, _}, V, _) -> is_pid(V);
chk(ref, V, _) -> is_reference(V);
chk({'fun', N}, V, _) -> is_function(V, N);
chk(never, _, _) -> false;
chk({list, D}, V, B) -> is_list(V) andalso lists:all(fun(X) -> chk(D, X, B) end, V);
chk({tuple, Ds}, V, B) ->
    is_tuple(V) andalso tuple_size(V) =:= length(Ds) andalso all(Ds, tuple_to_list(V), B);
chk({map, K, D}, V, B) ->
    is_map(V) andalso maps:fold(fun(Key, Val, Ok) ->
                                    Ok andalso chk(K, Key, B) andalso chk(D, Val, B)
                                end, true, V);
chk({set, D}, {set, V}, B) ->
    %% a version 2 set is a map from element to [], tagged (ernest@set)
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

%% An argument with every address inside it replaced by a proxy; none is
%% a parameter type without an address, left as it is.
expose(none, V, _) -> V;
expose({pid, D, Text}, V, B) when is_pid(V) -> proxy(V, D, B, Text);
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

%% The proxy lives as long as the target; a message that does not match
%% ends the target with the fault, as its own receive would have.
proxy(Target, D, B, Text) ->
    erlang:spawn(fun() ->
                     MRef = erlang:monitor(process, Target),
                     proxy_loop(Target, MRef, D, B, Text)
                 end).

proxy_loop(Target, MRef, D, B, Text) ->
    receive
        {'DOWN', MRef, process, Target, _} ->
            ok;
        Msg ->
            case chk(D, Msg, B) of
                true -> Target ! Msg;
                false -> exit(Target, {ernest, fault, Text})
            end,
            proxy_loop(Target, MRef, D, B, Text)
    end.
