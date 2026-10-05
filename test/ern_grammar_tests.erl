%% Report Appendix A read by a program, through ern_grammar: every
%% nonterminal it uses is defined and every one it defines is used, and
%% every choice the grammar makes is decided by the next token, its FIRST
%% set apart from its alternatives' and from what may follow it, or by the
%% later token the paragraph after the grammar names. The lexical
%% categories are §2's tokens: `conname` is a `typename`, `typevar` an
%% `ident`, and `literal`, `binop` and `userop` the tokens they list.
-module(ern_grammar_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix A: the grammar defines each nonterminal it uses, and
%% uses each one it defines but the start
defined_and_used_test() ->
    Rules = ern_grammar:rules(),
    Defined = [Name || {Name, _} <- Rules],
    Used = lists:usort([Name || {_, Expression} <- Rules,
                                Name <- ern_grammar:nonterminals(Expression)]),
    ?assertEqual([], Used -- Defined),
    ?assertEqual([], Defined -- ['Program' | Used]).

%% report Appendix A, §0 principle 4: each choice is decided by its first
%% token, or by the later token the paragraph after the grammar names
first_sets_test() ->
    Rules = ern_grammar:rules(),
    Grammar = maps:from_list(Rules),
    First = first_sets(Grammar),
    Follow = follow_sets(Rules, First),
    Conflicts = lists:usort(lists:append([conflicts(Rule, Expression, maps:get(Rule, Follow), First)
                                          || {Rule, Expression} <- Rules])),
    Prose = ern_grammar:prose(),
    Named = [{Rule, Token} || {Rule, Token, Phrase} <- decided(),
                              string:find(Prose, Phrase) =/= nomatch],
    ?assertEqual([], [Conflict || Conflict <- Conflicts, not lists:member(Conflict, Named)]),
    %% a decision below that no conflict needs, or whose phrase is gone
    Stale = [{Rule, Token} || {Rule, Token, _} <- decided(),
                              not lists:member({Rule, Token}, Named)
                                  orelse not lists:member({Rule, Token}, Conflicts)],
    ?assertEqual([], Stale).

%% The choices the next token does not decide, each the rule it is in, the
%% token its branches share, and the words of the paragraph after the
%% grammar that decide it.
decided() ->
    [{'Stmts', "fn", "an identifier or type name after `fn` makes it a declaration"},
     {'Type', "(", "is an `FnType` when `->` follows its `)`"},
     {'FnResult', "(", "is an `FnType` when `->` follows its `)`"},
     {'TypeAtom', typename, "of a type in `TypeAtom`"},
     {'ListedType', ident, "a type variable followed by `=` is marked"},
     {'QName', typename, "of a value in `QName`"},
     {'AtomPat', typename, "of a constructor in `AtomPat`"},
     {'QName', "(", "the parser consumes that argument in the constructor branch of `QName`"},
     {'Primary', ident, "are a type variable's member"},
     {'QName', ident, "whether `=` or `:` follows the first identifier"},
     {'AtomPat', ident, "whether `=` or `:` follows the first identifier"},
     {'Constructor', ident, "whether `=` or `:` follows the first identifier"},
     {'ReceiveExpr', "|", "a `|` followed by `after` begins its `AfterClause`"}].

%%
%% FIRST and FOLLOW
%%

%% Each nonterminal's FIRST set, with `empty` where it derives nothing,
%% to their fixed point.
first_sets(Grammar) ->
    Step = fun(First) -> maps:map(fun(_, Expression) -> first(Expression, First) end, Grammar) end,
    ern_grammar:fix(Step, maps:map(fun(_, _) -> [] end, Grammar)).

first({terminal, Token}, _) -> [Token];
first({nonterminal, Name}, First) -> maps:get(Name, First);
first({alternatives, Branches}, First) ->
    lists:usort(lists:append([first(Branch, First) || Branch <- Branches]));
first({optional, Expression}, First) -> lists:usort([empty | first(Expression, First)]);
first({repetition, Expression}, First) -> lists:usort([empty | first(Expression, First)]);
first({sequence, []}, _) -> [empty];
first({sequence, [Item | Items]}, First) ->
    FirstSet = first(Item, First),
    case lists:member(empty, FirstSet) of
        true -> lists:usort((FirstSet -- [empty]) ++ first({sequence, Items}, First));
        false -> FirstSet
    end.

%% Each nonterminal's FOLLOW set, `eof` after the start.
follow_sets(Rules, First) ->
    Initial = maps:from_list([{Name, case Name of 'Program' -> [eof]; _ -> [] end}
                              || {Name, _} <- Rules]),
    Step = fun(Follow) ->
                   lists:foldl(fun({Name, Expression}, Acc) ->
                                   follows(Expression, maps:get(Name, Follow), First, Acc)
                               end, Follow, Rules)
           end,
    ern_grammar:fix(Step, Initial).

follows({nonterminal, Name}, After, _, Acc) ->
    Acc#{Name => lists:usort(maps:get(Name, Acc) ++ After)};
follows({terminal, _}, _, _, Acc) -> Acc;
follows({alternatives, Branches}, After, First, Acc) ->
    lists:foldl(fun(Branch, BranchAcc) -> follows(Branch, After, First, BranchAcc) end, Acc,
                Branches);
follows({optional, Expression}, After, First, Acc) -> follows(Expression, After, First, Acc);
follows({repetition, Expression}, After, First, Acc) ->
    follows(Expression, then(first(Expression, First), After), First, Acc);
follows({sequence, Items}, After, First, Acc) ->
    Step = fun(Item, {ItemAfter, ItemAcc}) ->
               {then(first(Item, First), ItemAfter), follows(Item, ItemAfter, First, ItemAcc)}
           end,
    {_, Follows} = lists:foldr(Step, {After, Acc}, Items),
    Follows.

%% What may come first where a FIRST set stands before what may follow.
then(FirstSet, After) ->
    case lists:member(empty, FirstSet) of
        true -> lists:usort((FirstSet -- [empty]) ++ After);
        false -> FirstSet
    end.

%% Each choice of the rule that the next token does not decide, as the
%% rule and a token its branches share: two branches of a `|`, or an
%% optional or repeated part and what may follow it.
conflicts(Rule, {alternatives, Branches}, After, First) ->
    Sets = [then(first(Branch, First), After) || Branch <- Branches],
    Numbered = lists:enumerate(Sets),
    Shared = [Token || {Index, Set} <- Numbered, {OtherIndex, OtherSet} <- Numbered,
                       Index < OtherIndex, Token <- Set, lists:member(Token, OtherSet)],
    [{Rule, Token} || Token <- lists:usort(Shared)]
        ++ lists:append([conflicts(Rule, Branch, After, First) || Branch <- Branches]);
conflicts(Rule, {optional, Expression}, After, First) ->
    [{Rule, Token} || Token <- first(Expression, First) -- [empty], lists:member(Token, After)]
        ++ conflicts(Rule, Expression, After, First);
conflicts(Rule, {repetition, Expression}, After, First) ->
    [{Rule, Token} || Token <- first(Expression, First) -- [empty], lists:member(Token, After)]
        ++ conflicts(Rule, Expression, then(first(Expression, First), After), First);
conflicts(Rule, {sequence, Items}, After, First) ->
    Step = fun(Item, {ItemAfter, ItemAcc}) ->
               {then(first(Item, First), ItemAfter),
                conflicts(Rule, Item, ItemAfter, First) ++ ItemAcc}
           end,
    {_, Found} = lists:foldr(Step, {After, []}, Items),
    Found;
conflicts(_, _, _, _) ->
    [].
