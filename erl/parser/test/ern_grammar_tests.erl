%% Report Appendix A read by a program: every
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
    Defined = [Name || {Name, _} <- Rules],
    Used = lists:usort([Name || {_, Expr} <- Rules, Name <- nonterminals(Expr)]),
    ?assertEqual([], Used -- Defined),
    ?assertEqual([], Defined -- ['Program' | Used]).

%% report Appendix A, §0 principle 4: each choice is decided by its first
%% token, or by the later token the paragraph after the grammar names
first_sets_test() ->
    Rules = rules(),
    Grammar = maps:from_list(Rules),
    First = first_sets(Grammar),
    Follow = follow_sets(Rules, First),
    Conflicts = lists:usort(lists:append([conflicts(Rule, Expr, maps:get(Rule, Follow), First)
                                          || {Rule, Expr} <- Rules])),
    Prose = prose(),
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
%% {alt, Branches}, {opt, Expr}, {rep, Expr}, {nt, Name} or {t, Token}.
rules() ->
    {ok, Report} = file:read_file(?REPORT),
    Text = unicode:characters_to_list(Report),
    [_, FromAppendix] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(FromAppendix, "## Appendix B"),
    [_, Rest] = string:split(Appendix, "```\n"),
    [Grammar | _] = string:split(Rest, "```"),
    parse(tokens(Grammar)).

%% The paragraph after the grammar, which names the tokens past the first.
prose() ->
    {ok, Report} = file:read_file(?REPORT),
    Text = unicode:characters_to_list(Report),
    [_, FromAppendix] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(FromAppendix, "## Appendix B"),
    lists:last(string:split(Appendix, "```", all)).

tokens([]) -> [];
tokens([Char | Rest]) when Char =:= $\s; Char =:= $\n -> tokens(Rest);
tokens([$" | Rest]) ->
    {Quoted, [$" | After]} = lists:splitwith(fun(Char) -> Char =/= $" end, Rest),
    [{t, Quoted} | tokens(After)];
tokens([Letter | Rest]) when Letter >= $A, Letter =< $Z; Letter >= $a, Letter =< $z ->
    {Word, After} = lists:splitwith(fun(Char) -> Char >= $A andalso Char =< $Z
                                                     orelse Char >= $a andalso Char =< $z
                                                     orelse Char >= $0 andalso Char =< $9
                                    end, [Letter | Rest]),
    [{name, Word} | tokens(After)];
tokens([Char | Rest]) -> [{punct, Char} | tokens(Rest)].

parse([]) -> [];
parse([{name, Name}, {punct, $=} | Rest]) ->
    {Expr, [{punct, $.} | After]} = expr(Rest),
    [{list_to_atom(Name), Expr} | parse(After)].

expr(Tokens) ->
    {Term, Rest} = term(Tokens),
    alternatives(Rest, [Term]).

alternatives([{punct, $|} | Tokens], Terms) ->
    {Term, Rest} = term(Tokens),
    alternatives(Rest, [Term | Terms]);
alternatives(Tokens, [One]) -> {One, Tokens};
alternatives(Tokens, Terms) -> {{alt, lists:reverse(Terms)}, Tokens}.

term(Tokens) -> term(Tokens, []).

term([{punct, Char} | _] = Tokens, Factors)
  when Char =:= $|; Char =:= $.; Char =:= $); Char =:= $]; Char =:= $} ->
    {seq(lists:reverse(Factors)), Tokens};
term(Tokens, Factors) ->
    {Factor, Rest} = factor(Tokens),
    term(Rest, [Factor | Factors]).

seq([One]) -> One;
seq(Items) -> {seq, Items}.

factor([{t, Token} | Rest]) -> {{t, Token}, Rest};
factor([{name, [Initial | _] = Name} | Rest]) when Initial >= $A, Initial =< $Z ->
    {{nt, list_to_atom(Name)}, Rest};
factor([{name, Name} | Rest]) -> {lexical(Name), Rest};
factor([{punct, $(} | Rest]) -> close(expr(Rest), $), fun(Expr) -> Expr end);
factor([{punct, $[} | Rest]) -> close(expr(Rest), $], fun(Expr) -> {opt, Expr} end);
factor([{punct, ${} | Rest]) -> close(expr(Rest), $}, fun(Expr) -> {rep, Expr} end).

close({Expr, [{punct, Closer} | Rest]}, Closer, Wrap) -> {Wrap(Expr), Rest}.

%% §2's categories as the tokens the lexer gives.
lexical("conname") -> {t, typename};
lexical("typename") -> {t, typename};
lexical("typevar") -> {t, ident};
lexical("literal") -> {alt, [{t, int}, {t, float}, {t, char}, {t, string}, {t, "true"},
                             {t, "false"}]};
lexical("binop") -> {alt, [{t, Operator} || Operator <- ["*", "/", "%", "+", "-", "<>", "::",
                                                         "==", "!=", "<", "<=", ">", ">=", "&&",
                                                         "||", "|>"]]};
lexical("userop") -> {alt, [{t, Operator} || Operator <- ["+", "-", "*", "/", "%", "<>"]]};
lexical(Name) -> {t, list_to_atom(Name)}.

nonterminals({nt, Name}) -> [Name];
nonterminals({t, _}) -> [];
nonterminals({seq, Items}) -> lists:append([nonterminals(Item) || Item <- Items]);
nonterminals({alt, Branches}) -> lists:append([nonterminals(Branch) || Branch <- Branches]);
nonterminals({opt, Expr}) -> nonterminals(Expr);
nonterminals({rep, Expr}) -> nonterminals(Expr).

%%
%% FIRST and FOLLOW
%%

%% Each nonterminal's FIRST set, with `empty` where it derives nothing,
%% to their fixed point.
first_sets(Grammar) ->
    fix(fun(First) -> maps:map(fun(_, Expr) -> first(Expr, First) end, Grammar) end,
        maps:map(fun(_, _) -> [] end, Grammar)).

fix(Step, Value) ->
    case Step(Value) of
        Value -> Value;
        Next -> fix(Step, Next)
    end.

first({t, Token}, _) -> [Token];
first({nt, Name}, First) -> maps:get(Name, First);
first({alt, Branches}, First) ->
    lists:usort(lists:append([first(Branch, First) || Branch <- Branches]));
first({opt, Expr}, First) -> lists:usort([empty | first(Expr, First)]);
first({rep, Expr}, First) -> lists:usort([empty | first(Expr, First)]);
first({seq, []}, _) -> [empty];
first({seq, [Item | Items]}, First) ->
    FirstSet = first(Item, First),
    case lists:member(empty, FirstSet) of
        true -> lists:usort((FirstSet -- [empty]) ++ first({seq, Items}, First));
        false -> FirstSet
    end.

%% Each nonterminal's FOLLOW set, `eof` after the start.
follow_sets(Rules, First) ->
    Initial = maps:from_list([{Name, case Name of 'Program' -> [eof]; _ -> [] end}
                              || {Name, _} <- Rules]),
    fix(fun(Follow) ->
            lists:foldl(fun({Name, Expr}, Acc) ->
                                follows(Expr, maps:get(Name, Follow), First, Acc)
                        end, Follow, Rules)
        end, Initial).

follows({nt, Name}, After, _, Acc) -> Acc#{Name => lists:usort(maps:get(Name, Acc) ++ After)};
follows({t, _}, _, _, Acc) -> Acc;
follows({alt, Branches}, After, First, Acc) ->
    lists:foldl(fun(Branch, BranchAcc) -> follows(Branch, After, First, BranchAcc) end, Acc,
                Branches);
follows({opt, Expr}, After, First, Acc) -> follows(Expr, After, First, Acc);
follows({rep, Expr}, After, First, Acc) ->
    follows(Expr, then(first(Expr, First), After), First, Acc);
follows({seq, Items}, After, First, Acc) ->
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
conflicts(Rule, {alt, Branches}, After, First) ->
    Sets = [then(first(Branch, First), After) || Branch <- Branches],
    Numbered = lists:zip(lists:seq(1, length(Sets)), Sets),
    Shared = [Token || {Index, Set} <- Numbered, {OtherIndex, OtherSet} <- Numbered,
                       Index < OtherIndex, Token <- Set, lists:member(Token, OtherSet)],
    [{Rule, Token} || Token <- lists:usort(Shared)]
        ++ lists:append([conflicts(Rule, Branch, After, First) || Branch <- Branches]);
conflicts(Rule, {opt, Expr}, After, First) ->
    [{Rule, Token} || Token <- first(Expr, First) -- [empty], lists:member(Token, After)]
        ++ conflicts(Rule, Expr, After, First);
conflicts(Rule, {rep, Expr}, After, First) ->
    [{Rule, Token} || Token <- first(Expr, First) -- [empty], lists:member(Token, After)]
        ++ conflicts(Rule, Expr, then(first(Expr, First), After), First);
conflicts(Rule, {seq, Items}, After, First) ->
    Step = fun(Item, {ItemAfter, ItemAcc}) ->
                   {then(first(Item, First), ItemAfter),
                    conflicts(Rule, Item, ItemAfter, First) ++ ItemAcc}
           end,
    {_, Found} = lists:foldr(Step, {After, []}, Items),
    Found;
conflicts(_, _, _, _) ->
    [].
