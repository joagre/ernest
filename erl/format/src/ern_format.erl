%% The formatter, report §11.6: a module in its one layout, where only
%% line breaks and the spaces between tokens change. Every token is
%% written as it was written, cut from the source by its span, so a
%% literal's spelling, a parenthesis and the form a `|>` took stay as they
%% are; every comment stays beside the token it was beside.
%%
%% Two passes. The first walks the parse tree and builds a template of
%% the layout, one function per production of Appendix A, naming each
%% token in the order the source has it. The second walks the template in
%% that order with a cursor over the tokens, which fills in each token's
%% text and the comments before and after it, and yields the layout
%% ern_pretty prints. Parentheses make no node in the tree, so the second
%% pass finds a node's own by the brackets' pairs.
-module(ern_format).

-export([format/1, markdown/1]).

-include_lib("parser/include/ern_ast.hrl").

%% What the template reads: the code tokens and their text as written,
%% where each begins and ends, and each opening bracket's closing one.
-record(code, {tokens, texts, starts, ends, pairs}).

%% The cursor of the second pass: the next code token, the comments not
%% yet written, the last line written from the source, the code token
%% before, and whether a blank line must come before what comes next.
-record(cursor, {index = 1, trivia = [], last_line = 0, previous = none, force_blank = false}).

%% A module in the layout, or the diagnostic that stopped it.
-spec format(unicode:chardata()) ->
          {ok, unicode:unicode_binary()} | {error, ern_diagnostic:diagnostic()}.
format(Text) ->
    SourceLines = source_lines(Text),
    case ern_lexer:tokenize(Text, [comments]) of
        {error, _} = Error -> Error;
        {ok, Tokens} ->
            {CodeTokens, Trivia} = split(Tokens, SourceLines),
            case ern_parser:parse(CodeTokens) of
                {error, _} = Error -> Error;
                {ok, Declarations} ->
                    Code = code(CodeTokens, SourceLines),
                    Template = module(Declarations, Code),
                    {Layout, Cursor} = resolve(Template, Code, #cursor{trivia = Trivia}),
                    {Tail, Cursor1} = lead_trivia(Cursor, Code),
                    case {tuple_size(Code#code.tokens) =:= Cursor1#cursor.index,
                          Cursor1#cursor.trivia} of
                        {true, []} -> ok;
                        _ -> error({not_all_written, Cursor1#cursor.index, Cursor1#cursor.trivia})
                    end,
                    {ok, ern_pretty:render([Layout, Tail])}
            end
    end.

%% A CommonMark text with each Ernest block in the layout: one that
%% parses as a module is laid out as one, one that parses as a function's
%% body, as a doc block's example does, as that body, and any other is
%% left as it is (report §11.6).
-spec markdown(unicode:unicode_binary()) -> unicode:unicode_binary().
markdown(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    iolist_to_binary(lists:join(<<"\n">>, fences(Lines))).

fences([]) ->
    [];
fences([Line | Rest]) ->
    Trimmed = string:trim(Line, leading),
    case string:prefix(Trimmed, <<"```ernest">>) of
        nomatch -> [Line | fences(Rest)];
        _ ->
            Indent = byte_size(Line) - byte_size(Trimmed),
            IsInside = fun(BodyLine) -> string:trim(BodyLine) =/= <<"```">> end,
            case lists:splitwith(IsInside, Rest) of
                {Body, [Close | After]} ->
                    Dedented = [dedent(BodyLine, Indent) || BodyLine <- Body],
                    Pad = binary:copy(<<" ">>, Indent),
                    Laid = case fence(Dedented) of
                               Dedented -> Body;
                               Formatted ->
                                   [indent(Pad, FormattedLine) || FormattedLine <- Formatted]
                           end,
                    [Line] ++ Laid ++ [Close | fences(After)];
                {_, []} -> [Line | Rest]
            end
    end.

fence(Lines) ->
    Text = iolist_to_binary(lists:join(<<"\n">>, Lines)),
    case format(Text) of
        {ok, Formatted} -> lines(Formatted);
        {error, _} ->
            Wrapped = <<"fn f() = {\n", Text/binary, "\n}\n">>,
            case format(Wrapped) of
                {ok, Formatted} ->
                    Inner = lists:droplast(tl(lines(Formatted))),
                    [dedent(Line, 4) || Line <- Inner];
                {error, _} -> Lines
            end
    end.

lines(Formatted) ->
    binary:split(string:trim(Formatted, trailing, "\n"), <<"\n">>, [global]).

dedent(Line, Columns) ->
    case Line of
        <<Pad:Columns/binary, Rest/binary>> ->
            case string:trim(Pad, both, " ") of
                <<>> -> Rest;
                _ -> Line
            end;
        _ -> string:trim(Line, leading, " ")
    end.

indent(_Pad, <<>>) -> <<>>;
indent(Pad, Line) -> <<Pad/binary, Line/binary>>.

%%
%% The source: its lines, its code tokens, its comments
%%

source_lines(Text) ->
    Chars = case unicode:characters_to_list(Text) of
                [16#FEFF | Decoded] -> Decoded;
                Decoded when is_list(Decoded) -> Decoded;
                _ -> []
            end,
    list_to_tuple([strip_cr(Line) || Line <- string:split(Chars, "\n", all)]).

strip_cr(Line) ->
    case lists:reverse(Line) of
        [$\r | Reversed] -> lists:reverse(Reversed);
        _ -> Line
    end.

%% The code tokens, each told that the code token before it ended where it
%% did, so that the parser's spans end at code; and the comments and doc
%% blocks, as {Kind, Line, Column, EndLine, Text}.
split(Tokens, SourceLines) ->
    {CodeTokens, Trivia} = lists:partition(fun(Token) -> not is_trivium(Token) end, Tokens),
    {relink(CodeTokens, {1, 1}), [trivium(Token, SourceLines) || Token <- Trivia]}.

is_trivium({comment, _, _}) -> true;
is_trivium({doc, _, _}) -> true;
is_trivium(_) -> false.

relink([Token | Tokens], PreviousEnd) ->
    {Line, Column, End, _} = element(2, Token),
    [setelement(2, Token, {Line, Column, End, PreviousEnd}) | relink(Tokens, End)];
relink([], _) ->
    [].

trivium({comment, {Line, Column, {EndLine, _}, _}, Text}, _SourceLines) ->
    Kind = case Text of <<"/*", _/binary>> -> block; _ -> line end,
    {Kind, Line, Column, EndLine, Text};
trivium({doc, {Line, Column, {EndLine, _}, _}, _}, SourceLines) ->
    %% a doc block is kept as written, but for where its lines begin
    Lines = [unicode:characters_to_binary(string:trim(element(Number, SourceLines), leading))
             || Number <- lists:seq(Line, EndLine - 1)],
    {doc, Line, Column, EndLine - 1, doc_lines(Lines)}.

%% A doc block's lines, each Ernest example in it laid out; a line
%% outside an example, and an example that does not change, as written.
doc_lines([]) ->
    [];
doc_lines([Line | Rest]) ->
    case string:prefix(doc_content(Line), <<"```ernest">>) of
        nomatch -> [Line | doc_lines(Rest)];
        _ ->
            IsInside = fun(DocLine) -> string:trim(doc_content(DocLine)) =/= <<"```">> end,
            case lists:splitwith(IsInside, Rest) of
                {Body, [Close | After]} ->
                    Content = [doc_content(BodyLine) || BodyLine <- Body],
                    Laid = case fence(Content) of
                               Content -> Body;
                               Formatted -> [doc_line(FormattedLine) || FormattedLine <- Formatted]
                           end,
                    [Line] ++ Laid ++ [Close | doc_lines(After)];
                {_, []} -> [Line | Rest]
            end
    end.

doc_content(<<"/// ", Rest/binary>>) -> Rest;
doc_content(<<"///", Rest/binary>>) -> Rest.

doc_line(<<>>) -> <<"///">>;
doc_line(Line) -> <<"/// ", Line/binary>>.

code(CodeTokens, SourceLines) ->
    Indexed = lists:zip(lists:seq(1, length(CodeTokens)), CodeTokens),
    #code{tokens = list_to_tuple(CodeTokens),
          texts = list_to_tuple([text(Token, SourceLines) || Token <- CodeTokens]),
          starts = maps:from_list([{{Line, Column}, Index}
                                   || {Index, Token} <- Indexed,
                                      {Line, Column, _, _} <- [element(2, Token)]]),
          ends = maps:from_list([{End, Index} || {Index, Token} <- Indexed,
                                                 element(1, Token) =/= eof,
                                                 {_, _, End, _} <- [element(2, Token)]]),
          pairs = pairs(Indexed, [], #{})}.

%% A token's text as written.
text({eof, _}, _SourceLines) ->
    <<>>;
text(Token, SourceLines) ->
    {Line, Column, {EndLine, EndColumn}, _} = element(2, Token),
    Chars = case Line =:= EndLine of
                true -> lists:sublist(element(Line, SourceLines), Column, EndColumn - Column);
                false ->
                    [lists:nthtail(Column - 1, element(Line, SourceLines)), $\n,
                     [[element(Number, SourceLines), $\n]
                      || Number <- lists:seq(Line + 1, EndLine - 1)],
                     lists:sublist(element(EndLine, SourceLines), EndColumn - 1)]
            end,
    unicode:characters_to_binary(Chars).

%% Each opening bracket's index mapped to its closing one's.
pairs([], _Open, Acc) ->
    Acc;
pairs([{Index, Token} | Rest], Open, Acc) ->
    case element(1, Token) of
        Symbol when Symbol =:= '('; Symbol =:= '#('; Symbol =:= '['; Symbol =:= '{';
                    Symbol =:= '<<' ->
            pairs(Rest, [Index | Open], Acc);
        Symbol when Symbol =:= ')'; Symbol =:= ']'; Symbol =:= '}'; Symbol =:= '>>' ->
            [Opening | Outer] = Open,
            pairs(Rest, Outer, Acc#{Opening => Index});
        _ -> pairs(Rest, Open, Acc)
    end.

%%
%% Nodes and their tokens
%%

symbol(Token) -> element(1, Token).

%% Where a node's first token is: a call, an operator and a selection
%% begin with what they apply to.
start(#e_call{pipe = true, args = [Piped | _]}) -> start(Piped);
start(#e_call{callee = Callee}) -> start(Callee);
start(#e_binop{left = Left}) -> start(Left);
start(#e_selection{expr = Expr}) -> start(Expr);
start(Node) -> {Line, Column, _} = element(2, Node), {Line, Column}.

first_index(Node, Code) -> maps:get(start(Node), Code#code.starts).

last_index(Node, Code) ->
    {_, _, End} = element(2, Node),
    maps:get(End, Code#code.ends).

%% Whether parentheses stand around a node: its span ends at the closing
%% one, and the token before its first is the opening one.
is_parenthesized(Node, Code) ->
    Before = first_index(Node, Code) - 1,
    Before >= 1 andalso symbol(element(Before, Code#code.tokens)) =:= '('
        andalso maps:get(Before, Code#code.pairs) =:= last_index(Node, Code).

%% How a node's first line may end: a block's brace; a brace, for what
%% runs over lines inside braces and may stay on the line before them
%% (report §11.6); or neither.
ending(Node, Code) ->
    case is_parenthesized(Node, Code) of
        true -> other;
        false -> bare_ending(Node, Code)
    end.

bare_ending(#e_block{}, _) -> block;
bare_ending(#e_match{}, _) -> brace;
bare_ending(#e_receive{}, _) -> brace;
bare_ending(#e_lambda{body = Body}, Code) -> braced(Body, Code);
bare_ending(#e_call{pipe = false, args = [_ | _] = Args}, Code) -> braced(lists:last(Args), Code);
bare_ending(#e_constructor{args = {positional, Expr}}, Code) -> braced(Expr, Code);
bare_ending(#e_constructor{args = {named, _, [_ | _] = FieldSets}}, Code) ->
    braced((lists:last(FieldSets))#field_set.expr, Code);
bare_ending(_, _) -> other.

braced(Node, Code) ->
    case ending(Node, Code) of
        other -> other;
        _ -> brace
    end.

%%
%% The first pass: a template of the layout, in source order
%%

token(Symbol) -> {token, Symbol}.
token() -> {token, any}.
space() -> <<" ">>.

module(Declarations, Code) ->
    lists:join([hardline, force_blank], [declaration(Declaration, Code)
                                         || Declaration <- Declarations]).

declaration(#fn_declaration{export = Export, owner = Owner, params = Params,
                            result_type = ResultType, effect = Effect, body = Body}, Code) ->
    [export(Export), token(fn), space(), name(Owner), params(Params, Code),
     result_type(ResultType, Effect, Code), space(), token('='),
     case ending(Body, Code) of
         block -> [space(), expr(Body, Code)];
         _ -> {nest, 4, [hardline, expr(Body, Code)]}
     end];
declaration(#let_declaration{export = Export, annotation = Annotation, body = Body}, Code) ->
    [export(Export), token('let'), space(), token(), annotation(Annotation, Code), space(),
     token('='), {body, expr(Body, Code)}];
declaration(#type_declaration{export = Export, params = Params, constructors = Constructors},
            Code) ->
    [export(Export), type_declaration(Params, Constructors, Code)];
declaration(#abstract_declaration{export = Export,
                                  declaration = #type_declaration{params = Params,
                                                                  constructors = Constructors}},
            Code) ->
    [export(Export), token(abstract), space(), type_declaration(Params, Constructors, Code)];
declaration(#foreign_type_declaration{export = Export, params = Params, equality = Equality},
            _Code) ->
    Vars = case Params of
               [] -> [];
               _ -> bracket(token('('), [[token() | [token('=') || lists:member(Param, Equality)]]
                                         || Param <- Params], ')')
           end,
    [export(Export), token(foreign), space(), token(type), space(), token(), Vars];
declaration(#foreign_fn_declaration{export = Export, owner = Owner, params = Params,
                                    result_type = ResultType, effect = Effect}, Code) ->
    [export(Export), token(foreign), space(), token(fn), space(), name(Owner),
     params(Params, Code), result_type(ResultType, Effect, Code), space(), token('='),
     {nest, 4, [hardline, token(string)]}].

export(true) -> [token(export), space()];
export(false) -> [].

name(undefined) -> token();
name(_Owner) -> [token(), token('.'), token()].

params(Params, Code) ->
    bracket(token('('), [param(Param, Code) || Param <- Params], ')').

param(#param{pattern = Pattern, annotation = undefined}, Code) ->
    pattern(Pattern, Code);
param(#param{pattern = Pattern, annotation = Annotation}, Code) ->
    [pattern(Pattern, Code), space(), token(':'), space(), type(Annotation, Code)].

%% A head's result annotation is written `: T`, and a function type's
%% result after `->` (report §3.4, §4.5).
result_type(ResultType, Effect, Code) ->
    result_type(':', ResultType, Effect, Code).

result_type(_, undefined, _, _) ->
    [];
result_type(Symbol, ResultType, undefined, Code) ->
    [space(), token(Symbol), space(), type(ResultType, Code)];
result_type(Symbol, ResultType, Effect, Code) ->
    [space(), token(Symbol), space(), type(ResultType, Code), space(), token(with), space(),
     type(Effect, Code)].

annotation(undefined, _) -> [];
annotation(Annotation, Code) -> [space(), token(':'), space(), type(Annotation, Code)].

type_declaration(Params, Constructors, Code) ->
    Vars = case Params of
               [] -> [];
               _ -> bracket(token('('), [token() || _ <- Params], ')')
           end,
    [token(type), space(), token(), Vars, space(), token('='), alternatives(Constructors, Code)].

%% A type of one alternative keeps it on its line; alternatives that run
%% past the line break after the `=` and stand one a line, each further
%% line led by its bar, as a `match`'s arms do (report §11.6).
alternatives([Constructor], Code) ->
    %% a doc block puts the one alternative on a line of its own, a step in;
    %% one that does not fit breaks after the `=`, as several do, rather than
    %% inside the parentheses of the type's parameters or of its fields
    {if_lead, {nest, 4, [space(), constructor(Constructor, Code)]},
     {alternative, constructor(Constructor, Code)}};
alternatives([Constructor | Constructors], Code) ->
    Bar = {nest, -2, [line, token('|'), space()]},
    {group, {nest, 4, [line, constructor(Constructor, Code)
                       | lists:append([[Bar, constructor(Other, Code)]
                                       || Other <- Constructors])]}}.

constructor(#constructor{fields = none}, _) ->
    token();
constructor(#constructor{fields = {positional, Type}}, Code) ->
    [token(), bracket(token('('), [type(Type, Code)], ')')];
constructor(#constructor{fields = {named, Fields}}, Code) ->
    [token(),
     bracket(token('('), [[token(), space(), token(':'), space(), type(Annotation, Code)]
                          || #field{annotation = Annotation} <- Fields], ')')].

%% A bracket and its items, which the second pass lays out on one line or
%% one a line, aligned; Hug when its last item may stay on the bracket's
%% line with the brace it opens.
bracket(Open, Items, Close) ->
    {bracket, Open, Items, Close, false}.

bracket(Open, Items, Close, Last, Code) ->
    {bracket, Open, Items, Close, Last =/= none andalso ending(Last, Code) =/= other}.

last([]) -> none;
last(Nodes) -> lists:last(Nodes).

%% Types

type(Type, Code) -> {node, Type, bare_type(Type, Code)}.

bare_type(#t_named{path = Path, args = []}, _) ->
    [path(Path), token()];
bare_type(#t_named{path = Path, args = Args}, Code) ->
    [path(Path), token(), bracket(token('('), [type(Arg, Code) || Arg <- Args], ')')];
bare_type(#t_var{}, _) ->
    token();
bare_type(#t_tuple{elements = Elements}, Code) ->
    bracket(token('#('), [type(Element, Code) || Element <- Elements], ')');
bare_type(#t_fn{params = Params, result_type = ResultType, effect = Effect}, Code) ->
    [bracket(token('('), [type(Param, Code) || Param <- Params], ')'),
     result_type('->', ResultType, Effect, Code)].

path(Path) -> [[token(), token('.')] || _ <- Path].

%% Expressions

expr(Expr, Code) -> {node, Expr, bare_expr(Expr, Code)}.

bare_expr(#e_literal{}, _) ->
    token();
bare_expr(#e_var{path = Path}, _) ->
    [path(Path), token()];
bare_expr(#e_constructor{path = Path, args = none}, _) ->
    [path(Path), token()];
bare_expr(#e_constructor{path = Path, args = {positional, Expr}}, Code) ->
    [path(Path), token(), bracket(token('('), [expr(Expr, Code)], ')', Expr, Code)];
bare_expr(#e_constructor{path = Path, args = {named, Base, FieldSets}}, Code) ->
    Items = [[token('..'), expr(Base, Code)] || Base =/= undefined]
        ++ [[token(), space(), token('='), space(), expr(Expr, Code)]
            || #field_set{expr = Expr} <- FieldSets],
    Last = last([Expr || #field_set{expr = Expr} <- FieldSets]),
    [path(Path), token(), bracket(token('('), Items, ')', Last, Code)];
bare_expr(#e_tuple{elements = Elements}, Code) ->
    bracket(token('#('), [expr(Element, Code) || Element <- Elements], ')', last(Elements), Code);
bare_expr(#e_list{elements = Elements}, Code) ->
    bracket(token('['), [expr(Element, Code) || Element <- Elements], ']', last(Elements), Code);
bare_expr(#e_bitstring{segments = Segments}, Code) ->
    bracket(token('<<'), [segment(Segment, Code, fun expr/2) || Segment <- Segments], '>>');
bare_expr(#e_block{statements = Statements}, Code) ->
    braces([statements(Statements, Code), lead_trivia]);
bare_expr(#e_call{pipe = false, callee = Callee, args = Args}, Code) ->
    [expr(Callee, Code), args(Args, Code)];
bare_expr(#e_call{pipe = true} = Call, Code) ->
    {Base, Stages} = pipe_chain(Call, Code, []),
    {group, [expr(Base, Code),
             {nest, 4, [[line, token('|>'), space(), expr(Callee, Code), Args]
                        || {Callee, Args} <- Stages]}]};
bare_expr(#e_selection{expr = Expr}, Code) ->
    [expr(Expr, Code), token('.'), token()];
bare_expr(#e_negation{expr = Expr}, Code) ->
    [token('-'), expr(Expr, Code)];
bare_expr(#e_not{expr = Expr}, Code) ->
    [token('!'), expr(Expr, Code)];
bare_expr(#e_binop{} = Binop, Code) ->
    [First | Rest] = operands(Binop, Code),
    {group, [expr(First, Code),
             {nest, 4, [[line, token(Operator), space(), expr(Operand, Code)]
                        || {Operator, Operand} <- Rest]}]};
bare_expr(#e_lambda{params = Params, result_type = ResultType, effect = Effect, body = Body},
          Code) ->
    [token(fn), params(Params, Code), result_type(ResultType, Effect, Code), space(), token('='),
     {body, expr(Body, Code)}];
bare_expr(#e_if{} = If, Code) ->
    {group, ladder(If, Code)};
bare_expr(#e_match{scrutinee = Scrutinee, clauses = Clauses}, Code) ->
    [token(match), space(), expr(Scrutinee, Code), space(),
     braces([arms(Clauses, Code), lead_trivia])];
bare_expr(#e_receive{clauses = Clauses, 'after' = After}, Code) ->
    Arms = case {Clauses, After} of
               {[], #after_clause{}} -> after_clause(After, Code);
               {_, undefined} -> arms(Clauses, Code);
               _ -> [arms(Clauses, Code), bar(after_clause(After, Code))]
           end,
    [token('receive'), space(), braces([Arms, lead_trivia])].

args(Args, Code) ->
    bracket(token('('), [expr(Arg, Code) || Arg <- Args], ')', last(Args), Code).

%% A block's, a match's and a receive's brace runs over lines.
braces(Inside) ->
    [token('{'), {nest, 4, [hardline, Inside]}, hardline, token('}')].

statements(Statements, Code) ->
    lists:join([token(';'), hardline], [statement(Statement, Code) || Statement <- Statements]).

statement(#binding{pattern = Pattern, annotation = Annotation, expr = Expr}, Code) ->
    [token('let'), space(), pattern(Pattern, Code), annotation(Annotation, Code), space(),
     token(), {body, expr(Expr, Code)}];
statement(#fn_declaration{} = Declaration, Code) ->
    declaration(Declaration, Code);
statement(Expr, Code) ->
    expr(Expr, Code).

segment(#bit_segment{value = Value, specs = []}, Code, Template) ->
    Template(Value, Code);
segment(#bit_segment{value = Value, specs = Specs}, Code, Template) ->
    [Template(Value, Code), token(':'),
     lists:join(token('-'), [spec(Spec, Code) || Spec <- Specs])].

spec({size, Expr}, Code) -> [token(), token('('), expr(Expr, Code), token(')')];
spec(_, _) -> token().

%% `x |> f(a) |> g`: the first operand, then each callee with the
%% arguments after the first, where the call has its parentheses.
pipe_chain(#e_call{pipe = true, callee = Callee, args = [Piped | Rest]} = Call, Code, Acc) ->
    Args = case bracketed(Call, Callee, Code) of
               true -> args(Rest, Code);
               false -> []
           end,
    Stages = [{Callee, Args} | Acc],
    case Piped of
        #e_call{pipe = true} ->
            case is_parenthesized(Piped, Code) of
                false -> pipe_chain(Piped, Code, Stages);
                true -> {Piped, Stages}
            end;
        _ -> {Piped, Stages}
    end.

bracketed(Call, Callee, Code) ->
    Next = last_index(Callee, Code) + 1,
    Next =< last_index(Call, Code) andalso symbol(element(Next, Code#code.tokens)) =:= '('.

%% A chain of one operator, written as one: `a <> b <> c` breaks before
%% every `<>` or none. `::` groups to the right, every other to the left.
operands(#e_binop{operator = '::', left = Left, right = Right}, Code) ->
    [Left | right_chain(Right, Code)];
operands(#e_binop{operator = Operator, left = Left, right = Right}, Code) ->
    left_chain(Left, Operator, Code) ++ [{Operator, Right}].

left_chain(#e_binop{operator = Operator, left = Left, right = Right} = Node, Operator, Code) ->
    case is_parenthesized(Node, Code) of
        false -> left_chain(Left, Operator, Code) ++ [{Operator, Right}];
        true -> [Node]
    end;
left_chain(Node, _, _) ->
    [Node].

right_chain(#e_binop{operator = '::', left = Left, right = Right} = Node, Code) ->
    case is_parenthesized(Node, Code) of
        false -> [{'::', Left} | right_chain(Right, Code)];
        true -> [{'::', Node}]
    end;
right_chain(Node, _) ->
    [{'::', Node}].

%% An `if` on one line, or broken at every `then` and `else`, an `else
%% if` continuing the ladder; a block, or a branch whose first line ends
%% in a brace, stays beside its `then` or `else` (report §11.6).
ladder(#e_if{condition = Condition, then_branch = ThenBranch, else_branch = ElseBranch}, Code) ->
    Then = case ending(ThenBranch, Code) of
               block -> [space(), expr(ThenBranch, Code), space()];
               brace -> {hug_then, expr(ThenBranch, Code)};
               other -> [{nest, 4, [line, expr(ThenBranch, Code)]}, line]
           end,
    [token('if'), space(), expr(Condition, Code), space(), token(then), Then, token('else'),
     else_branch(ElseBranch, Code)].

else_branch(#e_if{} = ElseBranch, Code) ->
    case is_parenthesized(ElseBranch, Code) of
        false -> [space(), ladder(ElseBranch, Code)];
        true -> {nest, 4, [line, expr(ElseBranch, Code)]}
    end;
else_branch(ElseBranch, Code) ->
    case ending(ElseBranch, Code) of
        block -> [space(), expr(ElseBranch, Code)];
        brace -> {hug_else, expr(ElseBranch, Code)};
        other -> {nest, 4, [line, expr(ElseBranch, Code)]}
    end.

%% Each arm on a line of its own, a further one led by its bar two
%% columns to the left.
arms([Clause | Clauses], Code) ->
    [clause(Clause, Code) | [bar(clause(Other, Code)) || Other <- Clauses]].

bar(Arm) ->
    {nest, -2, [hardline, token('|'), space(), {nest, 2, Arm}]}.

clause(#clause{pattern = Pattern, guard = Guard, body = Body}, Code) ->
    When = case Guard of
               undefined -> [];
               _ -> [space(), token('when'), space(), expr(Guard, Code)]
           end,
    [pattern(Pattern, Code), When, space(), token('->'), {body, expr(Body, Code)}].

after_clause(#after_clause{timeout = Timeout, body = Body}, Code) ->
    [token('after'), space(), expr(Timeout, Code), space(), token('->'), {body, expr(Body, Code)}].

%% Patterns, which have no parentheses

pattern(#p_wildcard{}, _) ->
    token();
pattern(#p_var{}, _) ->
    token();
pattern(#p_literal{} = Literal, Code) ->
    case symbol(element(first_index(Literal, Code), Code#code.tokens)) of
        '-' -> [token('-'), token()];
        _ -> token()
    end;
pattern(#p_constructor{path = Path, args = none}, _) ->
    [path(Path), token()];
pattern(#p_constructor{path = Path, args = {named, []}}, _) ->
    [path(Path), token(), token('('), token(')')];
pattern(#p_constructor{path = Path, args = {named, FieldPatterns}}, Code) ->
    [path(Path), token(),
     bracket(token('('), [[token(), space(), token('='), space(), pattern(Pattern, Code)]
                          || #field_pattern{pattern = Pattern} <- FieldPatterns], ')')];
pattern(#p_constructor{path = Path, args = {positional, Pattern}}, Code) ->
    [path(Path), token(), bracket(token('('), [pattern(Pattern, Code)], ')')];
pattern(#p_tuple{elements = Elements}, Code) ->
    bracket(token('#('), [pattern(Element, Code) || Element <- Elements], ')');
pattern(#p_list{elements = Elements}, Code) ->
    bracket(token('['), [pattern(Element, Code) || Element <- Elements], ']');
pattern(#p_cons{head = Head, tail = Tail}, Code) ->
    [pattern(Head, Code), space(), token('::'), space(), pattern(Tail, Code)];
pattern(#p_as{pattern = Pattern}, Code) ->
    [pattern(Pattern, Code), space(), token(as), space(), token()];
pattern(#p_or{alternatives = Alternatives}, Code) ->
    lists:join([space(), token('or'), space()],
               [pattern(Alternative, Code) || Alternative <- Alternatives]);
pattern(#p_bitstring{segments = Segments}, Code) ->
    bracket(token('<<'), [segment(Segment, Code, fun pattern/2) || Segment <- Segments], '>>').

%%
%% The second pass: the template in source order, with the tokens' text
%%

resolve(Template, _Code, Cursor) when is_binary(Template) ->
    {Template, Cursor};
resolve(Template, Code, Cursor) when is_list(Template) ->
    lists:mapfoldl(fun(Part, PartCursor) -> resolve(Part, Code, PartCursor) end, Cursor,
                   Template);
resolve(Template, _Code, Cursor)
  when Template =:= line; Template =:= softline; Template =:= hardline; Template =:= blank ->
    {Template, Cursor};
resolve(force_blank, _Code, Cursor) ->
    {[], Cursor#cursor{force_blank = true}};
resolve(lead_trivia, Code, Cursor) ->
    lead_trivia(Cursor, Code);
resolve({nest, More, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{nest, More, Layout}, Cursor1};
resolve({align, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{align, Layout}, Cursor1};
resolve({group, Template}, Code, Cursor) ->
    %% the comments on lines before a group's first token stand before the
    %% group, which they would otherwise break
    {Lead, Cursor1} = case leading_break(Template) of
                          true -> {[], Cursor};
                          false -> lead_trivia(Cursor, Code)
                      end,
    {Layout, Cursor2} = resolve(Template, Code, Cursor1),
    {[Lead, {group, Layout}], Cursor2};
resolve({token, Expected}, Code, Cursor) ->
    consume(Expected, Code, Cursor);
resolve({if_lead, WithLead, Without}, Code, Cursor) ->
    {NextLine, NextColumn, _, _} = element(2, element(Cursor#cursor.index, Code#code.tokens)),
    case Cursor#cursor.trivia of
        [{_, Line, Column, _, _} | _] when {Line, Column} < {NextLine, NextColumn} ->
            resolve(WithLead, Code, Cursor);
        _ ->
            resolve(Without, Code, Cursor)
    end;
resolve({node, Node, Template}, Code, Cursor) ->
    parens(Node, Template, Code, Cursor);
resolve({bracket, Open, Items, Close, Hug}, Code, Cursor) ->
    items(Open, Items, Close, Hug, Code, Cursor);
resolve({body, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{choice, body, [space(), Layout, mark], {nest, 4, [hardline, Layout]}}, Cursor1};
resolve({alternative, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{choice, alternative, [space(), Layout, mark], {nest, 4, [hardline, Layout]}}, Cursor1};
resolve({hug_then, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{choice, branch, [space(), Layout, space()], [{nest, 4, [line, Layout]}, line]}, Cursor1};
resolve({hug_else, Template}, Code, Cursor) ->
    {Layout, Cursor1} = resolve(Template, Code, Cursor),
    {{choice, branch, [space(), Layout], {nest, 4, [line, Layout]}}, Cursor1}.

%% Whether a template begins with a line break.
leading_break(Template) when Template =:= line; Template =:= softline; Template =:= hardline ->
    true;
leading_break([]) -> false;
leading_break([[] | Rest]) -> leading_break(Rest);
leading_break([Head | _]) -> leading_break(Head);
leading_break({nest, _, Template}) -> leading_break(Template);
leading_break({align, Template}) -> leading_break(Template);
leading_break({group, Template}) -> leading_break(Template);
leading_break(_) -> false.

%% A node's own parentheses, the outermost closing where its span ends.
parens(Node, Template, Code, Cursor) ->
    {Opens, Cursor1} = opens(last_index(Node, Code), Code, Cursor, []),
    {Layout, Cursor2} = resolve(Template, Code, Cursor1),
    {Closes, Cursor3} = lists:mapfoldl(fun(_, Acc) -> consume(')', Code, Acc) end, Cursor2,
                                       Opens),
    case Opens of
        [] -> {Layout, Cursor2};
        _ -> {[lists:reverse(Opens), {align, Layout}, Closes], Cursor3}
    end.

opens(Last, Code, #cursor{index = Index} = Cursor, Acc) ->
    case symbol(element(Index, Code#code.tokens)) =:= '('
        andalso maps:get(Index, Code#code.pairs) =:= Last of
        true ->
            {Layout, Cursor1} = consume('(', Code, Cursor),
            opens(Last - 1, Code, Cursor1, [Layout | Acc]);
        false -> {Acc, Cursor}
    end.

%% A bracket on one line when it fits, else its first item on the
%% bracket's line and each further one on a line of its own under it; a
%% last item that opens a brace may keep the items on the bracket's line
%% (report §11.6).
items(Open, [], Close, _Hug, Code, Cursor) ->
    {OpenLayout, Cursor1} = resolve(Open, Code, Cursor),
    {Lead, Cursor2} = lead_trivia(Cursor1, Code),
    {CloseLayout, Cursor3} = consume(Close, Code, Cursor2),
    {[OpenLayout, Lead, CloseLayout], Cursor3};
items(Open, [First | Rest], Close, Hug, Code, Cursor) ->
    {Before, Cursor0} = lead_trivia(Cursor, Code),
    {OpenLayout, Cursor1} = resolve(Open, Code, Cursor0),
    {Above, Cursor1a} = lead_trivia(Cursor1, Code),
    {FirstLayout0, Cursor2} = resolve(First, Code, Cursor1a),
    FirstLayout = [Above, FirstLayout0],
    {Pairs, Cursor3} = lists:mapfoldl(fun(Item, Acc) ->
                                          {Comma, Acc1} = consume(',', Code, Acc),
                                          {Layout, Acc2} = resolve(Item, Code, Acc1),
                                          {{Comma, Layout}, Acc2}
                                      end, Cursor2, Rest),
    {Lead, Cursor4} = lead_trivia(Cursor3, Code),
    {CloseLayout, Cursor5} = consume(Close, Code, Cursor4),
    Items = [FirstLayout, [[Comma, line, Layout] || {Comma, Layout} <- Pairs], Lead],
    Broken = {bracket, [OpenLayout, {align, Items}, CloseLayout]},
    Laid = case {Pairs, Hug} of
               %% a comment or a doc block on the first item's lines puts it
               %% on a line of its own, and the items a step in
               _ when Above =/= [] -> {bracket, [OpenLayout, {nest, 4, Items}, CloseLayout]};
               {[], true} -> [OpenLayout, FirstLayout, Lead, CloseLayout];
               {[], false} -> [OpenLayout, {align, [FirstLayout, Lead]}, CloseLayout];
               {_, false} -> Broken;
               {_, true} ->
                   {choice, hug, [OpenLayout, FirstLayout,
                                  [[Comma, space(), Layout] || {Comma, Layout} <- Pairs], Lead,
                                  CloseLayout], Broken}
           end,
    {[Before, Laid], Cursor5}.

%% The next code token, with the comments on lines of their own before
%% it and those after it on its line. A blank line in the source before a
%% token or a comment is kept, but not after an opening bracket or before
%% a closing one, and one comes before a declaration after the first.
consume(Expected, Code, Cursor) ->
    Token = element(Cursor#cursor.index, Code#code.tokens),
    Expected =:= any orelse symbol(Token) =:= Expected
        orelse error({formatter_expected, Expected, Token}),
    {Lead, Cursor1} = lead_trivia(Cursor, Code),
    {Line, _, {EndLine, _}, _} = element(2, Token),
    Blank = blank_before(Cursor1, Line, symbol(Token)),
    Cursor2 = Cursor1#cursor{index = Cursor1#cursor.index + 1, last_line = EndLine,
                             previous = symbol(Token), force_blank = false},
    {Trailing, Cursor3} = trailing(Cursor2, Code, EndLine),
    {[Lead, Blank, element(Cursor#cursor.index, Code#code.texts), Trailing], Cursor3}.

lead_trivia(#cursor{trivia = [{Kind, Line, Column, EndLine, Text} | Rest]} = Cursor, Code) ->
    {NextLine, NextColumn, _, _} = element(2, element(Cursor#cursor.index, Code#code.tokens)),
    case {Line, Column} < {NextLine, NextColumn} of
        true ->
            %% comments directly under a declaration, with a blank line after
            %% them, are the declaration's, and the blank line between two
            %% declarations comes after them
            Stays = Cursor#cursor.force_blank
                andalso ends_before_gap(Cursor#cursor.last_line, Cursor#cursor.trivia,
                                        {NextLine, NextColumn}, true),
            Blank = case Stays of
                        true -> [];
                        false -> blank_before(Cursor, Line, none)
                    end,
            Cursor1 = Cursor#cursor{trivia = Rest, last_line = EndLine, previous = Kind,
                                    force_blank = Stays},
            {More, Cursor2} = lead_trivia(Cursor1, Code),
            {[hardline, Blank, trivium_layout(Kind, Text), hardline, More], Cursor2};
        false -> {[], Cursor}
    end;
lead_trivia(Cursor, _Code) ->
    {[], Cursor}.

%% Whether the comments before Next begin on the line after Last, each on
%% the line after the one before, and a blank line follows them.
ends_before_gap(Last, [{_, Line, Column, EndLine, _} | Rest], Next, IsFirst)
  when {Line, Column} < Next ->
    case Line - Last =< 1 of
        true -> ends_before_gap(EndLine, Rest, Next, false);
        false -> not IsFirst
    end;
ends_before_gap(Last, _, {NextLine, _}, IsFirst) ->
    not IsFirst andalso NextLine - Last >= 2.

%% Comments that begin on the line a token ended on, before the next
%% token: a line comment ends the line, a block comment need not, and is
%% kept apart by a space from a token after it on its line but a closing
%% bracket or a separator, and from the token before it but an opening
%% bracket.
trailing(#cursor{trivia = [{Kind, Line, Column, EndLine, Text} | Rest]} = Cursor, Code, TokenLine)
  when Line =:= TokenLine, Kind =/= doc ->
    Next = element(Cursor#cursor.index, Code#code.tokens),
    {NextLine, NextColumn, _, _} = element(2, Next),
    case {Line, Column} < {NextLine, NextColumn} of
        true ->
            Apart = NextLine =:= EndLine
                andalso not lists:member(element(1, Next), [')', ']', '}', '>>', ',', ';']),
            Opened = lists:member(Cursor#cursor.previous, ['(', '[', '{', '#(', '<<']),
            %% the space after a block comment is one with a space the
            %% layout puts there (ern_pretty)
            Before = case Opened of
                         true -> [];
                         false -> [space()]
                     end,
            Comment = case {Kind, Apart} of
                          {line, _} -> {suffix, <<" ", Text/binary>>};
                          {block, true} -> [Before, Text, space()];
                          {block, false} -> [Before, Text]
                      end,
            {More, Cursor1} = trailing(Cursor#cursor{trivia = Rest, last_line = EndLine,
                                                     previous = Kind}, Code, EndLine),
            {[Comment, More], Cursor1};
        false -> {[], Cursor}
    end;
trailing(Cursor, _Code, _TokenLine) ->
    {[], Cursor}.

trivium_layout(doc, Lines) -> lists:join(hardline, Lines);
trivium_layout(_, Text) -> Text.

blank_before(#cursor{force_blank = true}, _Line, _Symbol) ->
    blank;
blank_before(#cursor{last_line = Last, previous = Previous}, Line, Symbol) ->
    Opener = lists:member(Previous, ['(', '#(', '[', '{', '<<']),
    Closer = lists:member(Symbol, [')', ']', '}', '>>']),
    case Last > 0 andalso Line - Last >= 2 andalso not Opener andalso not Closer of
        true -> blank;
        false -> []
    end.
