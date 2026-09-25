%% Match exhaustiveness, report §5.9: the unguarded clauses of every
%% `match` must cover the scrutinee's type, and no clause of a `match` or
%% a `receive` may be redundant. Maranget's usefulness algorithm; a
%% witness for the missing case goes into the message. `receive` is exempt
%% from coverage (report §6.3), not from redundancy.
-module(ern_exhaust).

-export([check/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("lexer/include/ern_diag.hrl").

%% Simplified patterns: wild | {con, key(), [pattern()]}
%%   key(): {con, QName} | {tuple, N} | nil | cons | {bool, B} | {lit, V}
%% QName is the constructor's qualified name, as the checker keeps it, so a
%% constructor is read back by it with no name to resolve (report §4.2).

-spec check(tuple(), ern_typecheck:env()) -> ok.
check(Node, Env) ->
    walk(fun(#e_match{pos = Pos, scrutinee = S, clauses = Clauses}) ->
                 redundant(Clauses, Env),
                 Rows = lists:append([alt_rows(P, Env)
                                      || #clause{pattern = P, guard = undefined} <- Clauses]),
                 case useful(Rows, [wild], Env) of
                     no -> ok;
                     {yes, [Witness]} ->
                         Ty = ern_typecheck:resolve_type(ern_typecheck:node_type(S), Env),
                         throw({type_error, Pos, lists:flatten(
                                 ["match on ", ern_types:format(Ty, ern_typecheck:type_state(Env)),
                                  " is not exhaustive; missing ", show(Witness, Env)])})
                 end;
            (#e_receive{clauses = Clauses}) ->
                 redundant(Clauses, Env);
            (_) -> ok
         end, Node).

%% Report §5.9: a clause, or an alternative of one, that can match no value
%% the clauses before it leave is an error. A guarded clause covers
%% nothing, since its guard may fail; the alternatives before it in its own
%% clause cover what they match. The label names the earliest clause with
%% which the cover is complete.
redundant(Clauses, Env) ->
    lists:foldl(fun(#clause{pattern = P, guard = G}, Prev) ->
                        Alts = alternatives(P),
                        Own = lists:foldl(fun(A, Before) ->
                                              judge(A, length(Alts) > 1, Before, Env),
                                              Before ++ [{[simplify(A, Env)], A}]
                                          end, Prev, Alts),
                        case G of
                            undefined -> Own;
                            _ -> Prev
                        end
                end, [], Clauses),
    ok.

alternatives(#p_or{alts = Alts}) -> Alts;
alternatives(P) -> [P].

judge(A, IsAlternative, Before, Env) ->
    Candidate = [relax(simplify(A, Env))],
    case useful([R || {R, _} <- Before], Candidate, Env) of
        {yes, _} -> ok;
        no ->
            What = case IsAlternative of
                       true -> "alternative";
                       false -> "clause"
                   end,
            [{Last, By} | _] = cover(Before, Candidate, [], Env),
            Label = case useful([Last], Candidate, Env) of
                        no -> "this pattern matches every value it would";
                        {yes, _} -> "with those before it, this one matches every value it would"
                    end,
            throw({type_error,
                   #diag{span = ern_diag:span(element(2, A)),
                         message = "this " ++ What ++ " can never match",
                         labels = [{ern_diag:span(element(2, By)), Label}],
                         help = "remove it, or move it above the patterns that cover it"}})
    end.

%% The shortest run of rows from the first that leaves Candidate useless:
%% the rows from the last of them on.
cover([Row | Rest], Candidate, Taken, Env) ->
    Taken1 = Taken ++ [Row],
    case useful([R || {R, _} <- Taken1], Candidate, Env) of
        no -> [Row | Rest];
        {yes, _} -> cover(Rest, Candidate, Taken1, Env)
    end.

%% A bitstring pattern counts as matching nothing among the rows that
%% cover, and as matching anything in the pattern judged, so that no
%% bitstring clause is called redundant for what its size may decide
%% (report §5.9, §5.11).
relax({con, bits, []}) -> wild;
relax({con, K, Subs}) -> {con, K, [relax(S) || S <- Subs]};
relax(wild) -> wild.

walk(F, Node) when is_tuple(Node), is_atom(element(1, Node)) ->
    F(Node),
    lists:foreach(fun(X) -> walk(F, X) end, tl(tuple_to_list(Node)));
walk(F, L) when is_list(L) ->
    lists:foreach(fun(X) -> walk(F, X) end, L);
walk(_, _) ->
    ok.

%%
%% Simplification
%%

%% Report §5.9: a clause with alternatives covers what each alternative covers.
alt_rows(#p_or{alts = Alts}, Env) -> [[simplify(A, Env)] || A <- Alts];
alt_rows(P, Env) -> [[simplify(P, Env)]].

simplify(#p_wild{}, _) -> wild;
simplify(#p_var{}, _) -> wild;
simplify(#p_as{pattern = P}, Env) -> simplify(P, Env);
simplify(#p_lit{kind = bool, value = V}, _) -> {con, {bool, V}, []};
simplify(#p_lit{value = V}, _) -> {con, {lit, V}, []};
simplify(#p_tuple{elems = Es}, Env) -> {con, {tuple, length(Es)}, [simplify(E, Env) || E <- Es]};
simplify(#p_list{elems = []}, _) -> {con, nil, []};
simplify(#p_list{elems = [E | Es]} = P, Env) ->
    {con, cons, [simplify(E, Env), simplify(P#p_list{elems = Es}, Env)]};
simplify(#p_cons{head = H, tail = T}, Env) -> {con, cons, [simplify(H, Env), simplify(T, Env)]};
simplify(#p_con{pos = Pos, path = Path, name = Name, args = Args}, Env) ->
    #cinfo{qname = Q, fields = Fields} = ern_typecheck:lookup_con(Pos, Path, Name, Env),
    Subs = case {Fields, Args} of
               {none, _} -> [];
               {positional, none} -> [wild];
               {positional, {positional, P}} -> [simplify(P, Env)];
               {{named, Names}, none} -> [wild || _ <- Names];
               {{named, Names}, {named, FPs}} ->
                   [case [P || #field_pat{name = FN, pattern = P} <- FPs, FN =:= N] of
                        [P] -> simplify(P, Env);
                        [] -> wild
                    end || N <- Names]
           end,
    {con, {con, Q}, Subs};
simplify(#p_bits{}, _) -> {con, bits, []}.

%%
%% Usefulness with a witness. useful(Rows, Vector) is no when every value
%% matching Vector is matched by some row, else {yes, Witness}.
%%

useful([], Qs, _Env) ->
    {yes, [wild || _ <- Qs]};
useful(_Rows, [], _Env) ->
    no;
useful(Rows, [{con, K, Subs} | Qs], Env) ->
    N = length(Subs),
    case useful(specialize(Rows, K, N), Subs ++ Qs, Env) of
        no -> no;
        {yes, W} ->
            {WSubs, WRest} = lists:split(N, W),
            {yes, [{con, K, WSubs} | WRest]}
    end;
useful(Rows, [wild | Qs], Env) ->
    Keys = lists:usort([K || [{con, K, _} | _] <- Rows]),
    case complete(Keys, Env) of
        {true, AllKeys} ->
            try_keys(AllKeys, Rows, Qs, Env);
        {false, Missing} ->
            Default = [Rest || [wild | Rest] <- Rows],
            case useful(Default, Qs, Env) of
                no -> no;
                {yes, W} ->
                    Witness = case Missing of
                                  any -> wild;
                                  K -> {con, K, [wild || _ <- lists:seq(1, arity(K, Env))]}
                              end,
                    {yes, [Witness | W]}
            end
    end.

try_keys([], _Rows, _Qs, _Env) ->
    no;
try_keys([K | Ks], Rows, Qs, Env) ->
    N = arity(K, Env),
    case useful(specialize(Rows, K, N), [wild || _ <- lists:seq(1, N)] ++ Qs, Env) of
        no -> try_keys(Ks, Rows, Qs, Env);
        {yes, W} ->
            {WSubs, WRest} = lists:split(N, W),
            {yes, [{con, K, WSubs} | WRest]}
    end.

specialize(Rows, K, N) ->
    lists:append([case Row of
                      [{con, K, Subs} | Rest] -> [Subs ++ Rest];
                      [wild | Rest] -> [[wild || _ <- lists:seq(1, N)] ++ Rest];
                      _ -> []
                  end || Row <- Rows]).

%% Is the set of keys a complete signature? Returns {true, AllKeys} or
%% {false, MissingKey | any}.
complete([], _Env) ->
    {false, any};
complete([{lit, _} | _], _Env) ->
    {false, any};
complete([bits | _], _Env) ->
    %% report §5.11, §6.3: a bitstring pattern can fail to match
    {false, any};
complete([{bool, _} | _] = Keys, _Env) ->
    All = [{bool, true}, {bool, false}],
    missing(All, Keys);
complete([{tuple, _} = K | _], _Env) ->
    {true, [K]};
complete([K | _] = Keys, _Env) when K =:= nil; K =:= cons ->
    missing([nil, cons], Keys);
complete([{con, Q} | _] = Keys, Env) ->
    #cinfo{type_qname = TQ} = ern_typecheck:con_info(Q, Env),
    #tinfo{constructors = Cs} = ern_typecheck:lookup_type(TQ, Env),
    missing([{con, CQ} || #cinfo{qname = CQ} <- Cs], Keys).

missing(All, Keys) ->
    case All -- Keys of
        [] -> {true, All};
        [M | _] -> {false, M}
    end.

arity({con, Q}, Env) -> (ern_typecheck:con_info(Q, Env))#cinfo.tag_arity;
arity({tuple, N}, _) -> N;
arity(cons, _) -> 2;
arity(_, _) -> 0.

%%
%% Witness printing
%%

show(wild, _) -> "_";
show({con, {bool, B}, []}, _) -> atom_to_list(B);
show({con, {lit, V}, []}, _) -> lists:flatten(io_lib:format("~p", [V]));
show({con, bits, []}, _) -> "<<...>>";
show({con, {tuple, _}, Subs}, Env) -> ["#(", join([show(S, Env) || S <- Subs]), ")"];
show({con, nil, []}, _) -> "[]";
show({con, cons, [H, T]}, Env) -> [show_atom(H, Env), " :: ", show(T, Env)];
show({con, {con, Q}, Subs}, Env) ->
    #cinfo{name = Name, fields = Fields} = ern_typecheck:con_info(Q, Env),
    case {Fields, Subs} of
        {none, []} -> atom_to_list(Name);
        {positional, [S]} -> [atom_to_list(Name), "(", show(S, Env), ")"];
        {{named, Names}, _} ->
            Shown = [[atom_to_list(N), " = ", show(S, Env)]
                     || {N, S} <- lists:zip(Names, Subs), S =/= wild],
            case Shown of
                [] -> atom_to_list(Name);
                _ -> [atom_to_list(Name), "(", join(Shown), ")"]
            end
    end.

show_atom({con, cons, _} = P, Env) -> ["(", show(P, Env), ")"];
show_atom(P, Env) -> show(P, Env).

join(Parts) -> lists:join(", ", Parts).
