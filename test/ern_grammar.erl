%% Report Appendix A read as data, for the tests that hold the grammar and
%% the parser to it: each rule its name and its expression, Wirth's EBNF as
%% a term, with §2's categories as the lexer's tokens, and the blocks the
%% rules are read from; the paragraph after
%% the grammar, which names the tokens past the first; §2.4's reserved
%% words; and what both suites ask of the rules, the nonterminals an
%% expression names and a fixed point.
-module(ern_grammar).

-export([rules/0, read_blocks/0, prose/0, reserved/0, nonterminals/1, fix/2]).

-export_type([expression/0]).

-define(LANGUAGE, "../report/language.md").

%% A rule's expression: a sequence, a choice, an optional part, a
%% repetition, a nonterminal, or a terminal, the text a quoted one has or
%% the lexer's category of a token.
-type expression() :: {sequence, [expression()]} | {alternatives, [expression()]}
                    | {optional, expression()} | {repetition, expression()}
                    | {nonterminal, atom()} | {terminal, string() | atom()}.

%% Appendix A's rules, each its name and its expression.
-spec rules() -> [{atom(), expression()}].
rules() ->
    {_, Grammar} = grammar(),
    parse(tokens(Grammar)).

%% The blocks rules/0 reads, Appendix A's grammar and §2.6's categories,
%% each by the line its fence opens on in the report's language file.
-spec read_blocks() -> {file:filename(), [pos_integer()]}.
read_blocks() ->
    {Grammar, _} = grammar(),
    {Operators, _} = operators_block(),
    {?LANGUAGE, [Grammar, Operators]}.

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

%% The nonterminals an expression names.
-spec nonterminals(expression()) -> [atom()].
nonterminals({nonterminal, Name}) -> [Name];
nonterminals({terminal, _}) -> [];
nonterminals({optional, Expression}) -> nonterminals(Expression);
nonterminals({repetition, Expression}) -> nonterminals(Expression);
nonterminals({_, Items}) -> lists:append([nonterminals(Item) || Item <- Items]).

%% Step applied from Value until it gives back what it was given.
-spec fix(fun((Value) -> Value), Value) -> Value.
fix(Step, Value) ->
    case Step(Value) of
        Value -> Value;
        Next -> fix(Step, Next)
    end.

%% Appendix A's grammar, its first block: its fence's line and its text.
grammar() ->
    [First | _] = blocks("## Appendix A. Grammar", "## Appendix B"),
    First.

%% §2.6's second block, which writes `binop` and `userop`.
operators_block() ->
    [_, Second | _] = blocks("### 2.6 Operators and delimiters", "## "),
    Second.

%% The fenced blocks from the line that begins with From to the next that
%% begins with To, each its fence's line and its text.
blocks(From, To) ->
    Numbered = lists:enumerate(string:split(language(), "\n", all)),
    [_ | Rest] = lists:dropwhile(fun({_, Line}) -> not lists:prefix(From, Line) end, Numbered),
    {Section, _} = lists:splitwith(fun({_, Line}) -> not lists:prefix(To, Line) end, Rest),
    Lines = [{Number, unicode:characters_to_binary(Line)} || {Number, Line} <- Section],
    [{Number, unicode:characters_to_list([[Line, "\n"] || Line <- Code])}
     || {Number, _, _, Code} <- ern_helpers:blocks(Lines)].

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
    [{terminal, Quoted} | tokens(After)];
tokens([Letter | Rest]) when Letter >= $A, Letter =< $Z; Letter >= $a, Letter =< $z ->
    {Word, After} = lists:splitwith(fun is_word_char/1, [Letter | Rest]),
    [{name, Word} | tokens(After)];
tokens([Char | Rest]) -> [{punct, Char} | tokens(Rest)].

is_word_char(Char) ->
    Char >= $A andalso Char =< $Z orelse Char >= $a andalso Char =< $z
        orelse Char >= $0 andalso Char =< $9.

parse([]) -> [];
parse([{name, Name}, {punct, $=} | Rest]) ->
    {Expression, [{punct, $.} | After]} = expr(Rest),
    [{list_to_atom(Name), Expression} | parse(After)].

expr(Tokens) ->
    {Term, Rest} = term(Tokens),
    alternatives(Rest, [Term]).

alternatives([{punct, $|} | Tokens], Terms) ->
    {Term, Rest} = term(Tokens),
    alternatives(Rest, [Term | Terms]);
alternatives(Tokens, [One]) -> {One, Tokens};
alternatives(Tokens, Terms) -> {{alternatives, lists:reverse(Terms)}, Tokens}.

term(Tokens) -> term(Tokens, []).

term([{punct, Char} | _] = Tokens, Factors)
  when Char =:= $|; Char =:= $.; Char =:= $); Char =:= $]; Char =:= $} ->
    {sequence(lists:reverse(Factors)), Tokens};
term(Tokens, Factors) ->
    {Factor, Rest} = factor(Tokens),
    term(Rest, [Factor | Factors]).

sequence([One]) -> One;
sequence(Items) -> {sequence, Items}.

factor([{terminal, Token} | Rest]) -> {{terminal, Token}, Rest};
factor([{name, [Initial | _] = Name} | Rest]) when Initial >= $A, Initial =< $Z ->
    {{nonterminal, list_to_atom(Name)}, Rest};
factor([{name, Name} | Rest]) -> {lexical(Name), Rest};
factor([{punct, $(} | Rest]) -> close(expr(Rest), $), fun(Expression) -> Expression end);
factor([{punct, $[} | Rest]) ->
    close(expr(Rest), $], fun(Expression) -> {optional, Expression} end);
factor([{punct, ${} | Rest]) ->
    close(expr(Rest), $}, fun(Expression) -> {repetition, Expression} end).

close({Expression, [{punct, Closer} | Rest]}, Closer, Wrap) -> {Wrap(Expression), Rest}.

%% §2's categories as the tokens the lexer gives.
lexical("conname") -> {terminal, typename};
lexical("typename") -> {terminal, typename};
lexical("typevar") -> {terminal, ident};
lexical("literal") ->
    {alternatives, [{terminal, int}, {terminal, float}, {terminal, char}, {terminal, string},
                    {terminal, "true"}, {terminal, "false"}]};
lexical(Name) when Name =:= "binop"; Name =:= "userop" ->
    {_, Expression} = lists:keyfind(list_to_atom(Name), 1, operators()),
    Expression;
lexical(Name) -> {terminal, list_to_atom(Name)}.

%% §2.6's categories built from the operators, `binop` and `userop`, read
%% from the section's second block as Appendix A's rules are read.
operators() ->
    {_, Rules} = operators_block(),
    [Rule || {Name, _} = Rule <- parse(tokens(Rules)), Name =/= literal].
