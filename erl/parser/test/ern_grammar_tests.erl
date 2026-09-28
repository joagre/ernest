%% Report Appendix A read by a program (docs/coherence.md C18): every
%% nonterminal it uses is defined and every one it defines is used, and
%% every choice the grammar makes is decided by the next token, its FIRST
%% set apart from its alternatives' and from what may follow it, or by the
%% later token the paragraph after the grammar names. The lexical
%% categories are §2's tokens: `conname` is a `typename`, `typevar` an
%% `ident`, and `literal`, `binop` and `userop` the tokens they list.
-module(ern_grammar_tests).

-include_lib("eunit/include/eunit.hrl").

-define(REPORT, "../../../ernest_report.md").

%% report Appendix A: the grammar defines each nonterminal it uses, and
%% uses each one it defines but the start
defined_and_used_test() ->
    Rules = rules(),
    Defined = [N || {N, _} <- Rules],
    Used = lists:usort([N || {_, E} <- Rules, N <- nonterminals(E)]),
    ?assertEqual([], Used -- Defined),
    ?assertEqual([], Defined -- ['Program' | Used]).

%% report Appendix A, §0 principle 4: each choice is decided by its first
%% token, or by the later token the paragraph after the grammar names
first_sets_test() ->
    Rules = rules(),
    Grammar = maps:from_list(Rules),
    First = first_sets(Grammar),
    Follow = follow_sets(Rules, First),
    Conflicts = lists:usort(lists:append([conflicts(N, E, maps:get(N, Follow), First)
                                          || {N, E} <- Rules])),
    Prose = prose(),
    Named = [{R, T} || {R, T, Phrase} <- decided(), string:find(Prose, Phrase) =/= nomatch],
    ?assertEqual([], [C || C <- Conflicts, not lists:member(C, Named)]),
    %% a decision below that no conflict needs, or whose phrase is gone
    Stale = [{R, T} || {R, T, _} <- decided(),
                       not lists:member({R, T}, Named) orelse not lists:member({R, T}, Conflicts)],
    ?assertEqual([], Stale).

%% The choices the next token does not decide, each the rule it is in, the
%% token its branches share, and the words of the paragraph after the
%% grammar that decide it.
decided() ->
    [{'Stmt', "fn", "an identifier or type name after `fn` makes it a declaration"},
     {'Type', "(", "is an `FnType` when `->` follows its `)`"},
     {'FnType', "with", "A `with` after a function type belongs to that type"},
     {'TypeAtom', typename, "of a type in `TypeAtom`"},
     {'QName', typename, "of a value in `QName`"},
     {'AtomPat', typename, "of a constructor in `AtomPat`"},
     {'QName', "(", "the parser consumes that argument in the constructor branch of `QName`"},
     {'QName', ident, "whether `=` or `:` follows the first identifier"},
     {'AtomPat', ident, "whether `=` or `:` follows the first identifier"},
     {'Constructor', ident, "whether `=` or `:` follows the first identifier"},
     {'ReceiveExpr', "|", "a `|` followed by `after` begins its `AfterClause`"}].

%%
%% The grammar
%%

%% Appendix A's rules, each its name and its expression: {seq, Items},
%% {alt, Branches}, {opt, E}, {rep, E}, {nt, Name} or {t, Token}.
rules() ->
    {ok, Bin} = file:read_file(?REPORT),
    Text = unicode:characters_to_list(Bin),
    [_, Appendix0] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(Appendix0, "## Appendix B"),
    [_, Rest] = string:split(Appendix, "```\n"),
    [Grammar | _] = string:split(Rest, "```"),
    parse(tokens(Grammar)).

%% The paragraph after the grammar, which names the tokens past the first.
prose() ->
    {ok, Bin} = file:read_file(?REPORT),
    Text = unicode:characters_to_list(Bin),
    [_, Appendix0] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(Appendix0, "## Appendix B"),
    lists:last(string:split(Appendix, "```", all)).

tokens([]) -> [];
tokens([C | Rest]) when C =:= $\s; C =:= $\n -> tokens(Rest);
tokens([$" | Rest]) -> {T, [$" | After]} = lists:splitwith(fun(C) -> C =/= $" end, Rest),
                       [{t, T} | tokens(After)];
tokens([C | Rest]) when C >= $A, C =< $Z; C >= $a, C =< $z ->
    {W, After} = lists:splitwith(fun(D) -> D >= $A andalso D =< $Z orelse D >= $a andalso D =< $z
                                           orelse D >= $0 andalso D =< $9 end, [C | Rest]),
    [{name, W} | tokens(After)];
tokens([C | Rest]) -> [{punct, C} | tokens(Rest)].

parse([]) -> [];
parse([{name, N}, {punct, $=} | Rest]) ->
    {E, [{punct, $.} | After]} = expr(Rest),
    [{list_to_atom(N), E} | parse(After)].

expr(Ts) ->
    {T, Rest} = term(Ts),
    alts(Rest, [T]).

alts([{punct, $|} | Ts], Acc) ->
    {T, Rest} = term(Ts),
    alts(Rest, [T | Acc]);
alts(Ts, [One]) -> {One, Ts};
alts(Ts, Acc) -> {{alt, lists:reverse(Acc)}, Ts}.

term(Ts) -> term(Ts, []).

term([{punct, C} | _] = Ts, Acc) when C =:= $|; C =:= $.; C =:= $); C =:= $]; C =:= $} ->
    {seq(lists:reverse(Acc)), Ts};
term(Ts, Acc) ->
    {F, Rest} = factor(Ts),
    term(Rest, [F | Acc]).

seq([One]) -> One;
seq(Items) -> {seq, Items}.

factor([{t, T} | Rest]) -> {{t, T}, Rest};
factor([{name, [C | _] = N} | Rest]) when C >= $A, C =< $Z -> {{nt, list_to_atom(N)}, Rest};
factor([{name, N} | Rest]) -> {lexical(N), Rest};
factor([{punct, $(} | Rest]) -> close(expr(Rest), $), fun(E) -> E end);
factor([{punct, $[} | Rest]) -> close(expr(Rest), $], fun(E) -> {opt, E} end);
factor([{punct, ${} | Rest]) -> close(expr(Rest), $}, fun(E) -> {rep, E} end).

close({E, [{punct, C} | Rest]}, C, Wrap) -> {Wrap(E), Rest}.

%% §2's categories as the tokens the lexer gives.
lexical("conname") -> {t, typename};
lexical("typename") -> {t, typename};
lexical("typevar") -> {t, ident};
lexical("literal") -> {alt, [{t, int}, {t, float}, {t, char}, {t, string}, {t, "true"},
                             {t, "false"}]};
lexical("binop") -> {alt, [{t, Op} || Op <- ["*", "/", "%", "+", "-", "<>", "::", "==", "!=",
                                               "<", "<=", ">", ">=", "&&", "||", "|>"]]};
lexical("userop") -> {alt, [{t, Op} || Op <- ["+", "-", "*", "/", "%", "<>"]]};
lexical(N) -> {t, list_to_atom(N)}.

nonterminals({nt, N}) -> [N];
nonterminals({t, _}) -> [];
nonterminals({seq, Es}) -> lists:append([nonterminals(E) || E <- Es]);
nonterminals({alt, Es}) -> lists:append([nonterminals(E) || E <- Es]);
nonterminals({opt, E}) -> nonterminals(E);
nonterminals({rep, E}) -> nonterminals(E).

%%
%% FIRST and FOLLOW
%%

%% Each nonterminal's FIRST set, with `empty` where it derives nothing,
%% to their fixed point.
first_sets(Grammar) ->
    fix(fun(First) -> maps:map(fun(_, E) -> first(E, First) end, Grammar) end,
        maps:map(fun(_, _) -> [] end, Grammar)).

fix(F, X) ->
    case F(X) of
        X -> X;
        Y -> fix(F, Y)
    end.

first({t, T}, _) -> [T];
first({nt, N}, First) -> maps:get(N, First);
first({alt, Es}, First) -> lists:usort(lists:append([first(E, First) || E <- Es]));
first({opt, E}, First) -> lists:usort([empty | first(E, First)]);
first({rep, E}, First) -> lists:usort([empty | first(E, First)]);
first({seq, []}, _) -> [empty];
first({seq, [E | Es]}, First) ->
    F = first(E, First),
    case lists:member(empty, F) of
        true -> lists:usort((F -- [empty]) ++ first({seq, Es}, First));
        false -> F
    end.

%% Each nonterminal's FOLLOW set, `eof` after the start.
follow_sets(Rules, First) ->
    Start = maps:from_list([{N, case N of 'Program' -> [eof]; _ -> [] end} || {N, _} <- Rules]),
    fix(fun(Follow) ->
            lists:foldl(fun({N, E}, Acc) -> follows(E, maps:get(N, Follow), First, Acc) end,
                        Follow, Rules)
        end, Start).

follows({nt, N}, After, _, Acc) -> Acc#{N => lists:usort(maps:get(N, Acc) ++ After)};
follows({t, _}, _, _, Acc) -> Acc;
follows({alt, Es}, After, First, Acc) ->
    lists:foldl(fun(E, A) -> follows(E, After, First, A) end, Acc, Es);
follows({opt, E}, After, First, Acc) -> follows(E, After, First, Acc);
follows({rep, E}, After, First, Acc) -> follows(E, then(first(E, First), After), First, Acc);
follows({seq, Es}, After, First, Acc) ->
    {_, Acc1} = lists:foldr(fun(E, {A, Acc0}) ->
                                    {then(first(E, First), A), follows(E, A, First, Acc0)}
                            end, {After, Acc}, Es),
    Acc1.

%% What may come first where a FIRST set stands before what may follow.
then(F, After) ->
    case lists:member(empty, F) of
        true -> lists:usort((F -- [empty]) ++ After);
        false -> F
    end.

%% Each choice of the rule that the next token does not decide, as the
%% rule and a token its branches share: two branches of a `|`, or an
%% optional or repeated part and what may follow it.
conflicts(N, {alt, Es}, After, First) ->
    Sets = [then(first(E, First), After) || E <- Es],
    Shared = [T || {I, S} <- lists:zip(lists:seq(1, length(Sets)), Sets),
                   {J, S2} <- lists:zip(lists:seq(1, length(Sets)), Sets), I < J,
                   T <- S, lists:member(T, S2)],
    [{N, T} || T <- lists:usort(Shared)]
        ++ lists:append([conflicts(N, E, After, First) || E <- Es]);
conflicts(N, {opt, E}, After, First) ->
    [{N, T} || T <- first(E, First) -- [empty], lists:member(T, After)]
        ++ conflicts(N, E, After, First);
conflicts(N, {rep, E}, After, First) ->
    [{N, T} || T <- first(E, First) -- [empty], lists:member(T, After)]
        ++ conflicts(N, E, then(first(E, First), After), First);
conflicts(N, {seq, Es}, After, First) ->
    {_, Found} = lists:foldr(fun(E, {A, Acc}) ->
                                     {then(first(E, First), A), conflicts(N, E, A, First) ++ Acc}
                             end, {After, []}, Es),
    Found;
conflicts(_, _, _, _) ->
    [].
