%% Report Appendix E.1: a value as Ernest writes it, by the descriptor of
%% its type (ern_boundary); where the type is a variable, the descriptor is
%% `any` and the value is read by its runtime representation (§8.4).
%%
%% Report §11.2: the shell prints to a depth and a length and shows what it
%% cut as `...`; `Io.debug` prints the value whole, which is show/2, the
%% same printer with neither bound.
-module(ern_show).

-export([show/2, show/4]).

%% The depth left, and how many elements of a list, map, or set are
%% printed; `unbounded` is neither.
-record(lim, {depth = unbounded, length = unbounded}).

-spec show(term(), term()) -> binary().
show(D, V) ->
    show(D, V, unbounded, unbounded).

-spec show(term(), term(), non_neg_integer() | unbounded,
           non_neg_integer() | unbounded) -> binary().
show(D, V, Depth, Length) ->
    unicode:characters_to_binary(by_type(D, V, #{}, #lim{depth = Depth, length = Length})).

%% Report §11.2: below the depth a value is `...`, whatever it is. A value
%% written without nesting, a number or a string, is not below it: depth
%% counts the brackets a reader would have to open, and a depth of 0 is
%% where by_type/4 and represented/2 stop at the first bracket.
deeper(#lim{depth = unbounded} = L) -> L;
deeper(#lim{depth = N} = L) -> L#lim{depth = N - 1}.

%% The elements the length allows, and whether any were left.
limited(Xs, #lim{length = unbounded}) -> {Xs, false};
limited(Xs, #lim{length = N}) ->
    case length(Xs) > N of
        true -> {lists:sublist(Xs, N), true};
        false -> {Xs, false}
    end.

%% The parts, with `...` last when something was cut.
parts(Xs, L, F) ->
    {Kept, Cut} = limited(Xs, L),
    [F(X) || X <- Kept] ++ ["..." || Cut].

by_type(any, V, _, L) -> represented(V, L);
by_type(int, V, _, _) -> integer_to_list(V);
by_type(float, V, _, _) -> float_text(V);
by_type(bool, V, _, _) -> atom_to_list(V);
by_type(char, V, _, _) -> [$', char_body(V), $'];
by_type(string, V, _, _) -> string(V);
by_type(bytes, V, _, L) -> bytes(V, L);
by_type({pid, _, _}, _, _, _) -> "<address>";
by_type(ref, _, _, _) -> "<reply>";
by_type({'fun', _}, _, _, _) -> "<function>";
by_type({abstract, _}, _, _, _) -> "<abstract>";
by_type({mu, Id, D}, V, B, L) -> by_type(D, V, B#{Id => D}, L);
by_type({ref, Id}, V, B, L) -> by_type(maps:get(Id, B), V, B, L);
by_type({con, _}, V, _, _) when is_atom(V) -> atom_to_list(V);
by_type(_, _, _, #lim{depth = 0}) -> "...";
by_type({list, D}, V, B, L) ->
    ["[", join(parts(V, L, fun(X) -> by_type(D, X, B, deeper(L)) end)), "]"];
by_type({tuple, Ds}, V, B, L) ->
    Es = lists:zip(Ds, tuple_to_list(V)),
    ["#(", join([by_type(D, X, B, deeper(L)) || {D, X} <- Es]), ")"];
by_type({map, K, D}, V, B, L) ->
    Pair = fun({Key, X}) ->
               ["#(", by_type(K, Key, B, deeper(L)), ", ", by_type(D, X, B, deeper(L)), ")"]
           end,
    ["Map.fromList([", join(parts(lists:sort(maps:to_list(V)), L, Pair)), "])"];
by_type({set, D}, {set, S}, B, L) ->
    Elem = fun(X) -> by_type(D, X, B, deeper(L)) end,
    ["Set.fromList([", join(parts(lists:sort(maps:keys(S)), L, Elem)), "])"];
by_type({con, Cs}, V, B, L) when is_tuple(V) ->
    [Tag | Fields] = tuple_to_list(V),
    Parts = case lists:keyfind(Tag, 1, Cs) of
                {_, Ds} ->
                    [by_type(D, X, B, deeper(L)) || {D, X} <- lists:zip(Ds, Fields)];
                {_, Ds, Names} ->
                    [[atom_to_list(N), " = ", by_type(D, X, B, deeper(L))]
                     || {N, D, X} <- lists:zip3(Names, Ds, Fields)]
            end,
    [atom_to_list(Tag), "(", join(Parts), ")"].

%% By the runtime's representation alone.
represented(V, _) when is_integer(V) -> integer_to_list(V);
represented(V, _) when is_float(V) -> float_text(V);
represented(A, _) when is_atom(A) -> atom_to_list(A);
represented(Bin, L) when is_binary(Bin) ->
    case unicode:characters_to_list(Bin) of
        Chars when is_list(Chars) -> string(Bin);
        _ -> bytes(Bin, L)
    end;
represented(P, _) when is_pid(P) -> "<address>";
represented(R, _) when is_reference(R) -> "<reply>";
represented(F, _) when is_function(F) -> "<function>";
represented(V, #lim{depth = 0}) when is_list(V); is_tuple(V); is_map(V) ->
    "...";
represented(V, L) when is_list(V) ->
    %% a foreign value may be an improper list, which Ernest has no form for
    case proper(V) of
        true -> ["[", join(parts(V, L, fun(X) -> represented(X, deeper(L)) end)), "]"];
        false -> "<foreign>"
    end;
represented({set, S}, L) when is_map(S) ->
    Elems = parts(lists:sort(maps:keys(S)), L, fun(K) -> represented(K, deeper(L)) end),
    ["Set.fromList([", join(Elems), "])"];
represented(T, L) when is_tuple(T), tuple_size(T) > 0, is_atom(element(1, T)) ->
    %% report §8.4: a constructor's atom is its source spelling, capitalized;
    %% any other first atom, `true` among them, begins a tuple
    [Tag | Fields] = tuple_to_list(T),
    case atom_to_list(Tag) of
        [C | _] when C >= $A, C =< $Z ->
            [atom_to_list(Tag), "(", join([represented(F, deeper(L)) || F <- Fields]), ")"];
        _ ->
            ["#(", join([represented(F, deeper(L)) || F <- tuple_to_list(T)]), ")"]
    end;
represented(T, L) when is_tuple(T) ->
    ["#(", join([represented(F, deeper(L)) || F <- tuple_to_list(T)]), ")"];
represented(M, L) when is_map(M) ->
    Pair = fun({K, V}) -> ["#(", represented(K, deeper(L)), ", ", represented(V, deeper(L)), ")"]
           end,
    ["Map.fromList([", join(parts(lists:sort(maps:to_list(M)), L, Pair)), "])"];
represented(_, _) -> "<foreign>".

proper([]) -> true;
proper([_ | T]) -> proper(T);
proper(_) -> false.

float_text(F) -> float_to_list(F, [short]).

string(Bin) -> [$", [escape(C, $") || C <- unicode:characters_to_list(Bin)], $"].

bytes(Bin, L) ->
    Bytes = parts([X || <<X>> <= Bin], L, fun integer_to_list/1),
    ["<<", join(Bytes), ">>"].

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
