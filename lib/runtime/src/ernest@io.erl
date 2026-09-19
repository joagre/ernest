%% Appendix E.1, namespace Io, as an Erlang module for MVP 1 (implementation
%% plan, Phase 2.4). Strings are UTF-8 binaries (report §8.4).
-module('ernest@io').

-export([print/1, println/1, debug/1]).

-spec print(binary()) -> 'Unit'.
print(S) -> ern_rt:send(ern_rt:sys(stdout), S).

-spec println(binary()) -> 'Unit'.
println(S) -> ern_rt:send(ern_rt:sys(stdout), <<S/binary, "\n">>).

%% Appendix E.1: the value as Ernest writes it, by its runtime representation
%% (report §8.4), printed and returned.
-spec debug(term()) -> term().
debug(V) ->
    println(iolist_to_binary(render(V))),
    V.

render(V) when is_integer(V) -> integer_to_list(V);
render(V) when is_float(V) -> io_lib:format("~p", [V]);
render(A) when is_atom(A) -> atom_to_list(A);
render(B) when is_binary(B) ->
    case unicode:characters_to_list(B) of
        L when is_list(L) -> [$", [escape(C) || C <- L], $"];
        _ -> ["<<", join([integer_to_list(X) || <<X>> <= B]), ">>"]
    end;
render(L) when is_list(L) -> ["[", join([render(X) || X <- L]), "]"];
render(T) when is_tuple(T), tuple_size(T) > 0, is_atom(element(1, T)) ->
    [Tag | Fields] = tuple_to_list(T),
    [atom_to_list(Tag), "(", join([render(F) || F <- Fields]), ")"];
render(T) when is_tuple(T) -> ["#(", join([render(F) || F <- tuple_to_list(T)]), ")"];
render(M) when is_map(M) ->
    Pairs = lists:sort(maps:to_list(M)),
    case lists:all(fun({_, V}) -> V =:= [] end, Pairs) of
        true -> ["Set.fromList([", join([render(K) || {K, _} <- Pairs]), "])"];
        false -> ["Map.fromList([", join([["#(", render(K), ", ", render(V), ")"] || {K, V} <- Pairs]), "])"]
    end;
render(P) when is_pid(P) -> "<address>";
render(R) when is_reference(R) -> "<reply>";
render(F) when is_function(F) -> "<function>";
render(_) -> "<foreign>".

join(Parts) -> lists:join(", ", Parts).

escape($") -> "\\\"";
escape($\\) -> "\\\\";
escape($\n) -> "\\n";
escape($\t) -> "\\t";
escape($\r) -> "\\r";
escape(C) -> C.
