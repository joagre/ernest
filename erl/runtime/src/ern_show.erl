%% Report Appendix E.1: a value as Ernest writes it, by the descriptor of
%% its type (ern_check); where the type is a variable, the descriptor is
%% `any` and the value is read by its runtime representation (§8.4).
-module(ern_show).

-export([show/2]).

-spec show(term(), term()) -> binary().
show(D, V) ->
    unicode:characters_to_binary(by_type(D, V, #{})).

by_type(any, V, _) -> represented(V);
by_type(int, V, _) -> integer_to_list(V);
by_type(float, V, _) -> float_text(V);
by_type(bool, V, _) -> atom_to_list(V);
by_type(char, V, _) -> [$', char_body(V), $'];
by_type(string, V, _) -> string(V);
by_type(bytes, V, _) -> bytes(V);
by_type({pid, _, _}, _, _) -> "<address>";
by_type(ref, _, _) -> "<reply>";
by_type({'fun', _}, _, _) -> "<function>";
by_type({abstract, _}, _, _) -> "<abstract>";
by_type({list, D}, V, B) -> ["[", join([by_type(D, X, B) || X <- V]), "]"];
by_type({tuple, Ds}, V, B) ->
    ["#(", join([by_type(D, X, B) || {D, X} <- lists:zip(Ds, tuple_to_list(V))]), ")"];
by_type({map, K, D}, V, B) ->
    Pairs = [["#(", by_type(K, Key, B), ", ", by_type(D, X, B), ")"]
             || {Key, X} <- lists:sort(maps:to_list(V))],
    ["Map.fromList([", join(Pairs), "])"];
by_type({set, D}, {set, S}, B) ->
    ["Set.fromList([", join([by_type(D, X, B) || X <- lists:sort(maps:keys(S))]), "])"];
by_type({con, _}, V, _) when is_atom(V) -> atom_to_list(V);
by_type({con, Cs}, V, B) when is_tuple(V) ->
    [Tag | Fields] = tuple_to_list(V),
    Parts = case lists:keyfind(Tag, 1, Cs) of
                {_, Ds} ->
                    [by_type(D, X, B) || {D, X} <- lists:zip(Ds, Fields)];
                {_, Ds, Names} ->
                    [[atom_to_list(N), " = ", by_type(D, X, B)]
                     || {N, D, X} <- lists:zip3(Names, Ds, Fields)]
            end,
    [atom_to_list(Tag), "(", join(Parts), ")"];
by_type({mu, Id, D}, V, B) -> by_type(D, V, B#{Id => D});
by_type({ref, Id}, V, B) -> by_type(maps:get(Id, B), V, B).

%% By the runtime's representation alone.
represented(V) when is_integer(V) -> integer_to_list(V);
represented(V) when is_float(V) -> float_text(V);
represented(A) when is_atom(A) -> atom_to_list(A);
represented(Bin) when is_binary(Bin) ->
    case unicode:characters_to_list(Bin) of
        L when is_list(L) -> string(Bin);
        _ -> bytes(Bin)
    end;
represented(L) when is_list(L) ->
    %% a foreign value may be an improper list, which Ernest has no form for
    case proper(L) of
        true -> ["[", join([represented(X) || X <- L]), "]"];
        false -> "<foreign>"
    end;
represented({set, S}) when is_map(S) ->
    ["Set.fromList([", join([represented(K) || K <- lists:sort(maps:keys(S))]), "])"];
represented(T) when is_tuple(T), tuple_size(T) > 0, is_atom(element(1, T)) ->
    %% report §8.4: a constructor's atom is its source spelling, capitalized;
    %% any other first atom, `true` among them, begins a tuple
    [Tag | Fields] = tuple_to_list(T),
    case atom_to_list(Tag) of
        [C | _] when C >= $A, C =< $Z ->
            [atom_to_list(Tag), "(", join([represented(F) || F <- Fields]), ")"];
        _ ->
            ["#(", join([represented(F) || F <- tuple_to_list(T)]), ")"]
    end;
represented(T) when is_tuple(T) -> ["#(", join([represented(F) || F <- tuple_to_list(T)]), ")"];
represented(M) when is_map(M) ->
    Pairs = [["#(", represented(K), ", ", represented(V), ")"]
             || {K, V} <- lists:sort(maps:to_list(M))],
    ["Map.fromList([", join(Pairs), "])"];
represented(P) when is_pid(P) -> "<address>";
represented(R) when is_reference(R) -> "<reply>";
represented(F) when is_function(F) -> "<function>";
represented(_) -> "<foreign>".

proper([]) -> true;
proper([_ | T]) -> proper(T);
proper(_) -> false.

float_text(F) -> float_to_list(F, [short]).

string(Bin) -> [$", [escape(C, $") || C <- unicode:characters_to_list(Bin)], $"].

bytes(Bin) -> ["<<", join([integer_to_list(X) || <<X>> <= Bin]), ">>"].

char_body(C) -> escape(C, $').

%% Report §2.5: the escapes a literal needs, the quote being the literal's own.
escape(Q, Q) -> [$\\, Q];
escape($\\, _) -> "\\\\";
escape($\n, _) -> "\\n";
escape($\t, _) -> "\\t";
escape($\r, _) -> "\\r";
escape(C, _) when C < 16#20; C =:= 16#7F -> ["\\u{", integer_to_list(C, 16), "}"];
escape(C, _) -> [C].

join(Parts) -> lists:join(", ", Parts).
