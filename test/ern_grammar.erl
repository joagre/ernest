%% Report Appendix A read as data, for the tests that hold the grammar and
%% the parser to it: each rule its name and its expression, Wirth's EBNF as
%% a term, with §2's categories as the lexer's tokens; the paragraph after
%% the grammar, which names the tokens past the first; and §2.4's reserved
%% words.
-module(ern_grammar).

-export([rules/0, prose/0, reserved/0]).

-export_type([expression/0]).

-define(LANGUAGE, "../report/language.md").

%% A rule's expression: a sequence, a choice, an optional part, a
%% repetition, a nonterminal, or a terminal, the text a quoted one has or
%% the lexer's category of a token.
-type expression() :: {seq, [expression()]} | {alt, [expression()]} | {opt, expression()}
                    | {rep, expression()} | {nt, atom()} | {t, string() | atom()}.

%% Appendix A's rules, each its name and its expression.
-spec rules() -> [{atom(), expression()}].
rules() ->
    [_, Rest] = string:split(appendix(), "```\n"),
    [Grammar | _] = string:split(Rest, "```"),
    parse(tokens(Grammar)).

%% The paragraph after the grammar, which names the tokens past the first.
-spec prose() -> string().
prose() ->
    lists:last(string:split(appendix(), "```", all)).

%% §2.4's reserved words, every word its table quotes.
-spec reserved() -> [string()].
reserved() ->
    [_, FromSection] = string:split(language(), "### 2.4 Reserved words"),
    [Section | _] = string:split(FromSection, "### 2.5"),
    Rows = [Line || Line <- string:split(Section, "\n", all), lists:prefix("|", Line)],
    [Word || Row <- Rows, {Index, Word} <- lists:enumerate(string:split(Row, "`", all)),
             Index rem 2 =:= 0].

appendix() ->
    [_, FromAppendix] = string:split(language(), "## Appendix A. Grammar"),
    [Appendix | _] = string:split(FromAppendix, "## Appendix B"),
    Appendix.

language() ->
    {ok, Report} = file:read_file(?LANGUAGE),
    unicode:characters_to_list(Report).

tokens([]) -> [];
tokens([Char | Rest]) when Char =:= $\s; Char =:= $\n -> tokens(Rest);
tokens([$" | Rest]) ->
    {Quoted, [$" | After]} = lists:splitwith(fun(Char) -> Char =/= $" end, Rest),
    [{t, Quoted} | tokens(After)];
tokens([Letter | Rest]) when Letter >= $A, Letter =< $Z; Letter >= $a, Letter =< $z ->
    {Word, After} = lists:splitwith(fun is_word_char/1, [Letter | Rest]),
    [{name, Word} | tokens(After)];
tokens([Char | Rest]) -> [{punct, Char} | tokens(Rest)].

is_word_char(Char) ->
    Char >= $A andalso Char =< $Z orelse Char >= $a andalso Char =< $z
        orelse Char >= $0 andalso Char =< $9.

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
