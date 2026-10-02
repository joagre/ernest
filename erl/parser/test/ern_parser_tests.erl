-module(ern_parser_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

expression(Text) ->
    {ok, Expr} = ern_parser:parse_expr(Text),
    Expr.

declaration(Text) ->
    {ok, [Declaration]} = ern_parser:parse_string(Text),
    Declaration.

declarations(Text) ->
    {ok, Declarations} = ern_parser:parse_string(Text),
    Declarations.

refusal(Text) ->
    {error, #diagnostic{message = Message}} = ern_parser:parse_string(Text),
    Message.

expression_refusal(Text) ->
    {error, #diagnostic{message = Message}} = ern_parser:parse_expr(Text),
    Message.

help(Text) ->
    {error, #diagnostic{help = Help}} = ern_parser:parse_string(Text),
    Help.

refusal_and_help(Text) ->
    {error, #diagnostic{message = Message, help = Help}} = ern_parser:parse_string(Text),
    {Message, Help}.

expression_help(Text) ->
    {error, #diagnostic{help = Help}} = ern_parser:parse_expr(Text),
    Help.

%% The pattern of a match's one clause.
pattern_of(Text) ->
    #e_match{clauses = [#clause{pattern = Pattern}]} =
        expression("match x { " ++ Text ++ " -> 0 }"),
    Pattern.

%% The type a `let` is annotated with.
type_of(Text) ->
    #let_declaration{annotation = Annotation} = declaration("let x : " ++ Text ++ " = y"),
    Annotation.

is_incomplete_expression(Text) ->
    {error, #diagnostic{incomplete = Incomplete}} = ern_parser:parse_expr(Text),
    Incomplete.

is_incomplete_program(Text) ->
    {error, #diagnostic{incomplete = Incomplete}} = ern_parser:parse_string(Text),
    Incomplete.

%% Where an unfinished expression stopped: the call it stopped within, and
%% what may stand there.
stopped_within(Text) ->
    {error, #diagnostic{incomplete = true, within = Within, expected = Expected}} =
        ern_parser:parse_expr(Text),
    {Within, Expected}.

%%
%% Expressions
%%

%% report §2.5
literals_test() ->
    ?assertMatch(#e_literal{kind = int, value = 42}, expression("42")),
    ?assertMatch(#e_literal{kind = float, value = 1.5}, expression("1.5")),
    ?assertMatch(#e_literal{kind = char, value = $a}, expression("'a'")),
    ?assertMatch(#e_literal{kind = string, value = <<"hi">>}, expression("\"hi\"")),
    ?assertMatch(#e_literal{kind = bool, value = true}, expression("true")).

%% report §2.3, §4.2
names_test() ->
    ?assertMatch(#e_var{path = [], name = x}, expression("x")),
    ?assertMatch(#e_var{path = ['Net', 'Http'], name = parse}, expression("Net.Http.parse")),
    ?assertMatch(#e_var{path = ['Int'], name = '+'}, expression("Int.+")),
    ?assertMatch(#e_constructor{path = [], name = 'None', args = none}, expression("None")),
    ?assertMatch(#e_constructor{path = ['Net', 'Http'], name = 'Request', args = {positional, _}},
                 expression("Net.Http.Request(x)")).

%% report §2.6
precedence_test() ->
    ?assertMatch(#e_binop{operator = '+', left = #e_literal{value = 1},
                          right = #e_binop{operator = '*', left = #e_literal{value = 2},
                                           right = #e_literal{value = 3}}},
                 expression("1 + 2 * 3")),
    ?assertMatch(#e_binop{operator = '-', left = #e_binop{operator = '-', left = #e_var{name = a},
                                                          right = #e_var{name = b}},
                          right = #e_var{name = c}},
                 expression("a - b - c")),
    ?assertMatch(#e_binop{operator = '::', left = #e_var{name = a},
                          right = #e_binop{operator = '::', left = #e_var{name = b},
                                           right = #e_var{name = c}}},
                 expression("a :: b :: c")),
    ?assertMatch(#e_binop{operator = '||', left = #e_binop{operator = '&&',
                                                           left = #e_binop{operator = '=='},
                                                           right = #e_var{name = c}},
                          right = #e_var{name = d}},
                 expression("a == b && c || d")),
    ?assertMatch(#e_binop{operator = '::', left = #e_binop{operator = '+'},
                          right = #e_var{name = xs}},
                 expression("1 + 2 :: xs")),
    ?assertMatch(#e_binop{operator = '<>', left = #e_literal{}, right = #e_call{}},
                 expression("\"a\" <> Int.toString(n)")).

%% report §2.6, §5.1
unary_minus_test() ->
    ?assertMatch(#e_negation{expr = #e_literal{value = 1}}, expression("-1")),
    ?assertMatch(#e_negation{expr = #e_call{callee = #e_var{name = f}}}, expression("-f(x)")),
    ?assertMatch(#e_binop{operator = '*', left = #e_negation{}, right = #e_literal{value = 3}},
                 expression("-2 * 3")),
    ?assertMatch(#e_binop{operator = '-', left = #e_var{name = a}, right = #e_negation{}},
                 expression("a - -b")).

%% report §4.8: `!` is prefix negation, and binds like prefix `-`
unary_not_test() ->
    ?assertMatch(#e_not{expr = #e_literal{value = true}}, expression("!true")),
    ?assertMatch(#e_not{expr = #e_call{callee = #e_var{name = f}}}, expression("!f(x)")),
    ?assertMatch(#e_not{expr = #e_binop{operator = '&&'}}, expression("!(a && b)")),
    ?assertMatch(#e_binop{operator = '&&', left = #e_not{}, right = #e_var{name = b}},
                 expression("!a && b")).

%% report §5.2
calls_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = []}, expression("f()")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}, #e_literal{}]},
                 expression("f(x, 1)")),
    ?assertMatch(#e_call{callee = #e_call{callee = #e_var{name = f}, args = [_]}, args = [_]},
                 expression("f(a)(b)")),
    ?assertMatch(#e_call{callee = #e_var{path = ['Address'], name = call}},
                 expression("Address.call(c, fn(r) = Get(reply = r), 1000)")).

%% report §5.7: the pipe binds loosest, below ||, and takes a
%% parenthesized lambda
pipe_precedence_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{operator = '+'}]},
                 expression("a + b |> f")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{operator = '||'}]},
                 expression("a || b |> f")),
    ?assertMatch(#e_call{callee = #e_lambda{}, args = [#e_var{name = x}]},
                 expression("x |> (fn(y) = y + 1)")).

%% report §5.7
pipe_rewrite_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}]},
                 expression("x |> f")),
    ?assertMatch(#e_call{callee = #e_var{name = f},
                         args = [#e_var{name = x}, #e_var{name = a}, #e_var{name = b}]},
                 expression("x |> f(a, b)")),
    ?assertMatch(#e_call{callee = #e_call{callee = #e_var{name = f}, args = [#e_var{name = a}]},
                         args = [#e_var{name = x}, #e_var{name = b}]},
                 expression("x |> f(a)(b)")),
    %% parentheses change nothing: a parenthesized call is a call the pipe
    %% fills, and a parenthesized callee is the callee (findings.md's P1-7)
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}, #e_var{name = a}]},
                 expression("x |> (f(a))")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}, #e_var{name = a}]},
                 expression("x |> (f)(a)")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}]},
                 expression("x |> (f)")),
    ?assertMatch(#e_call{callee = #e_var{name = c},
                         args = [#e_call{callee = #e_var{name = b}, args = [#e_var{name = a}]}]},
                 expression("a |> b |> c")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{operator = '+'}]},
                 expression("a + b |> f")),
    ?assertMatch(#e_call{callee = #e_lambda{}, args = [#e_var{name = x}]},
                 expression("x |> (fn(y) = y + 1)")).

%% report §5.7: a parenthesized right-hand side is parsed once, and its
%% parentheses change nothing, so each level's call is filled by the one
%% outside it. A regression test: the check parsed it twice at every level,
%% so that nesting took exponential time, two seconds at a depth of 22.
pipe_nesting_test_() ->
    {timeout, 5,
     fun() ->
         Source = lists:duplicate(40, "x |> (") ++ "x" ++ lists:duplicate(40, ")"),
         #e_call{callee = #e_var{name = x}, args = Args} = expression(lists:flatten(Source)),
         ?assertEqual(40, length(Args))
     end}.

%% report §5.1, §5.7: the call a pipe writes is marked, so that x is
%% evaluated before a computed callee; a written call is not
pipe_marks_call_test() ->
    ?assertMatch(#e_call{pipe = true, callee = #e_call{pipe = false}}, expression("x |> f(a)(b)")),
    ?assertMatch(#e_call{pipe = true}, expression("x |> (f(a))")),
    ?assertMatch(#e_call{pipe = true}, expression("x |> f")),
    ?assertMatch(#e_call{pipe = false}, expression("f(x, a)")).

%% report §3.5, Appendix A: `.` and an ident after a primary select a
%% field, chained and after a call; an uppercase first segment still
%% begins a qualified name
field_selection_test() ->
    ?assertMatch(#e_selection{expr = #e_var{name = s}, field = upper}, expression("s.upper")),
    ?assertMatch(#e_selection{expr = #e_selection{expr = #e_var{name = s}, field = at}, field = x},
                 expression("s.at.x")),
    ?assertMatch(#e_selection{expr = #e_call{}, field = y}, expression("f(1).y")),
    ?assertMatch(#e_selection{expr = #e_var{path = ['Stack'], name = empty}, field = items},
                 expression("Stack.empty.items")),
    ?assertMatch(#e_binop{operator = '+', left = #e_selection{}, right = #e_selection{}},
                 expression("p.x + p.y")).

%% report §5.6
constructors_test() ->
    ?assertMatch(#e_constructor{name = 'Some', args = {positional, #e_literal{value = 5}}},
                 expression("Some(5)")),
    ?assertMatch(#e_constructor{name = 'Person', base = undefined,
                                args = {named, [#field_set{name = name, expr = #e_literal{}},
                                                #field_set{name = age, expr = #e_literal{}}]}},
                 expression("Person(name = \"A\", age = 30)")),
    ?assertMatch(#e_constructor{name = 'Person', base = #e_var{name = p},
                                args = {named, [#field_set{name = age}]}},
                 expression("Person(..p, age = 31)")),
    ?assertMatch(#e_constructor{name = 'Some', args = {positional, #e_var{name = x}}},
                 expression("Some(x)")).

%% report §3.2, §3.3
tuples_lists_test() ->
    ?assertMatch(#e_tuple{elements = [#e_literal{}, #e_literal{}]}, expression("#(1, 2)")),
    %% a tuple has two components or more, as a value, a type and a pattern
    %% (findings.md's P1-38)
    ?assertEqual("a tuple has two components or more", expression_refusal("#(1)")),
    ?assertEqual("a tuple has two components or more", refusal("fn f(x : #(Int)) : Int = 1")),
    ?assertEqual("a tuple has two components or more",
                 refusal("fn f(x : Int) : Int = match x { #(y) -> y }")),
    ?assertMatch(#e_list{elements = []}, expression("[]")),
    ?assertMatch(#e_list{elements = [#e_literal{}, #e_literal{}, #e_literal{}]},
                 expression("[1, 2, 3]")).

%% report Appendix A
parens_produce_no_node_test() ->
    ?assertMatch(#e_binop{operator = '*', left = #e_binop{operator = '+'}, right = #e_literal{}},
                 expression("(1 + 2) * 3")),
    ?assertMatch(#e_var{name = x}, expression("((x))")).

%% report §5.4
block_test() ->
    ?assertMatch(#e_block{statements = [#binding{pattern = #p_var{name = x}, operator = '=',
                                                 expr = #e_literal{value = 5}},
                                        #binding{pattern = #p_tuple{}, operator = '<-',
                                                 annotation = undefined},
                                        #binding{pattern = #p_var{name = m},
                                                 annotation = #t_named{name = 'Map'}},
                                        #fn_declaration{name = helper, params = [_]},
                                        #e_call{}]},
                 expression("{ let x = 5; let #(a, b) <- f(x);"
                            " let m : Map(String, Int) = Map.empty;"
                            " fn helper(y) = y; helper(x) }")),
    ?assertMatch(#e_block{statements = [#e_lambda{}, #e_var{}]},
                 expression("{ fn(x) = x; y }")).

%% report §4.5, Appendix A's Return: a result annotation is written `: T`
%% in a declaration, a foreign one and a lambda, and `->` after the
%% parameters is refused with the spelling that replaces it (§11); a
%% function type keeps its arrow, and a `with` after one is the type's
result_annotation_test() ->
    ?assertMatch([#fn_declaration{result_type = #t_named{name = 'Int'}}],
                 declarations("fn f(x : Int) : Int = x")),
    ?assertMatch([#foreign_fn_declaration{result_type = #t_named{name = 'Int'}}],
                 declarations("foreign fn g() : Int = \"m:g/0\"")),
    ?assertMatch(#e_lambda{result_type = #t_named{name = 'Int'}}, expression("fn(x) : Int = x")),
    Said = "a function's result is annotated with `:`, not `->`",
    ?assertEqual(Said, refusal("fn f(x : Int) -> Int = x")),
    ?assertEqual(Said, refusal("foreign fn g() -> Int = \"m:g/0\"")),
    ?assertEqual(Said, expression_refusal("fn(x) -> Int = x")),
    ?assertMatch([#fn_declaration{result_type = #t_fn{effect = #t_named{name = 'M'}},
                                  effect = undefined}],
                 declarations("fn f() : (Int) -> Int with M = g")),
    ?assertMatch([#fn_declaration{result_type = #t_fn{effect = undefined},
                                  effect = #t_named{name = 'M'}}],
                 declarations("fn f() : ((Int) -> Int) with M = g")).

%% report §5.3
lambda_test() ->
    ?assertMatch(#e_lambda{params = [#param{pattern = #p_var{name = x}, annotation = undefined}],
                           result_type = undefined, effect = undefined,
                           body = #e_binop{operator = '+'}},
                 expression("fn(x) = x + 1")),
    ?assertMatch(#e_lambda{params = [], result_type = #t_named{name = 'Unit'},
                           effect = #t_named{name = 'Never'}, body = #e_constructor{name = 'Unit'}},
                 expression("fn() : Unit with Never = Unit")),
    %% the body extends to the enclosing delimiter
    ?assertMatch(#e_call{args = [#e_var{}, #e_lambda{body = #e_binop{operator = '+'}}]},
                 expression("List.map(xs, fn(x) = x + 1)")),
    ?assertMatch(#e_call{args = [#e_var{}, #e_lambda{body = #e_call{}}, #e_literal{}]},
                 expression("f(a, fn(r) = g(r), 1)")).

%% report §5.8
if_test() ->
    ?assertMatch(#e_if{condition = #e_binop{operator = '=='}, then_branch = #e_literal{},
                       else_branch = #e_binop{operator = '+'}},
                 expression("if n == 0 then 1 else n + 1")),
    ?assertMatch(#e_if{else_branch = #e_block{}}, expression("if c then a else { b }")).

%% report §5.9
match_test() ->
    ?assertMatch(#e_match{scrutinee = #e_var{name = xs},
                          clauses = [#clause{pattern = #p_list{elements = []}, guard = undefined,
                                             body = #e_literal{}},
                                     #clause{pattern = #p_cons{}, guard = #e_binop{operator = '>'},
                                             body = #e_var{}},
                                     #clause{pattern = #p_wildcard{}}]},
                 expression("match xs { [] -> 0 | h :: _ when h > 0 -> h | _ -> 1 }")),
    ?assertMatch(#e_match{clauses = [#clause{body = #e_match{}}, #clause{}]},
                 expression("match a { Some(b) -> match b { 1 -> x | _ -> y } | None -> z }")).

%% report §2.2: a doc block attaches to a declaration, to a constructor
%% above it or above its `|`, to a field, or, with a blank line after it,
%% to the module; elsewhere it is a comment
doc_attachment_test() ->
    Source = <<"/// The module.\n\n/// T.\ntype T =\n    /// A.\n    A(\n    /// f.\n"
               "    x : Int)\n    /// B.\n  | B\n/// S.\nabstract type S = S(Int)\n">>,
    {ok, Declarations} = ern_parser:parse_string(Source),
    ?assertMatch([#module_doc{text = <<"The module.">>},
                  #type_declaration{doc = <<"T.">>,
                                    constructors =
                                        [#constructor{doc = <<"A.">>,
                                                      fields = {named, [#field{doc = <<"f.">>}]}},
                                         #constructor{doc = <<"B.">>}]},
                  #abstract_declaration{doc = <<"S.">>}],
                 Declarations),
    ?assertMatch({error, #diagnostic{message = "a doc block documents nothing here"}},
                 ern_parser:parse_string(<<"fn f() = {\n    /// stray\n    1\n}\n">>)).

%% report §5.9: a clause lists one or more patterns separated by `or`
or_pattern_test() ->
    ?assertMatch(#e_match{clauses = [#clause{pattern =
                                                 #p_or{alternatives =
                                                           [#p_constructor{name = 'A'},
                                                            #p_constructor{name = 'B'}]},
                                             body = #e_literal{}},
                                     #clause{pattern = #p_constructor{name = 'C'},
                                             guard = #e_literal{}}]},
                 expression("match x { A or B -> 1 | C when true -> 2 }")),
    ?assertMatch(#e_receive{clauses = [#clause{pattern = #p_or{alternatives = [_, _, _]}}]},
                 expression("receive { A or B or C -> 1 }")).

%% report §6.3
receive_test() ->
    ?assertMatch(#e_receive{clauses = [#clause{pattern = #p_constructor{name = 'Inc'}},
                                       #clause{pattern = #p_constructor{name = 'Get'}}],
                            'after' = undefined},
                 expression("receive { Inc(k) -> counter(n + k) | Get(reply = r) -> counter(n) }")),
    ?assertMatch(#e_receive{clauses = [#clause{}],
                            'after' = #after_clause{timeout = #e_literal{value = 1000},
                                                    body = #e_constructor{name = 'None'}}},
                 expression("receive { Data(n) -> Some(n) | after 1000 -> None }")),
    ?assertMatch(#e_receive{clauses = [], 'after' = #after_clause{timeout = #e_literal{value = 0}}},
                 expression("receive { after 0 -> world }")).

%% report §5.11
bitstring_expr_test() ->
    ?assertMatch(#e_bitstring{segments = []}, expression("<<>>")),
    ?assertMatch(#e_bitstring{segments = [#bit_segment{value = #e_literal{value = 0}, specs = []},
                                          #bit_segment{value = #e_literal{value = 1}}]},
                 expression("<<0, 1>>")),
    ?assertMatch(#e_bitstring{segments = [#bit_segment{value = #e_var{name = len},
                                                       specs = [{size, #e_literal{value = 16}},
                                                                big]},
                                          #bit_segment{value = #e_var{name = body},
                                                       specs = [bytes]}]},
                 expression("<<len:size(16)-big, body:bytes>>")),
    ?assertMatch(#e_bitstring{segments = [#bit_segment{specs = [{size, #e_var{}}, little,
                                                                signed]}]},
                 expression("<<x:size(n)-little-signed>>")).

%% report §5.11: there is no `unit`; a size counts bits, and octets for
%% `bytes`, and the error says to write it so. A regression test: `unit`
%% was a second way to scale a size
no_unit_specifier_test() ->
    ?assertEqual("there is no `unit` specifier", expression_refusal("<<x:size(n)-unit(8)>>")).

%% report §5.11: a specifier's name is an ordinary identifier outside a
%% specifier list, so a segment's value, a size's expression and a pattern's
%% variable may be named `size`, `int` or `little`. A regression test: the
%% parser conformed before it was written; the checker's half is in
%% ern_typecheck_tests.
specifier_names_are_identifiers_test() ->
    ?assertMatch(#e_bitstring{segments = [#bit_segment{value = #e_var{name = size},
                                                       specs = [{size, #e_var{name = int}}, big]}]},
                 expression("<<size:size(int)-big>>")),
    #e_match{clauses = [#clause{pattern = Pattern}]} =
        expression("match b { <<size:size(16), little:bytes>> -> size }"),
    ?assertMatch(#p_bitstring{segments = [#bit_segment{value = #p_var{name = size},
                                                       specs = [{size, #e_literal{value = 16}}]},
                                          #bit_segment{value = #p_var{name = little},
                                                       specs = [bytes]}]}, Pattern).

%%
%% Patterns
%%

%% report §5.10
patterns_test() ->
    ?assertMatch(#p_wildcard{}, pattern_of("_")),
    ?assertMatch(#p_var{name = '_x'}, pattern_of("_x")),
    ?assertMatch(#p_var{name = y}, pattern_of("y")),
    ?assertMatch(#p_literal{kind = int, value = 1}, pattern_of("1")),
    ?assertMatch(#p_literal{kind = int, value = -1}, pattern_of("-1")),
    ?assertMatch(#p_literal{kind = float, value = -2.5}, pattern_of("-2.5")),
    %% report §3.1: no negative zero, so `-0.0` is the zero; a regression
    %% test, it was the host's negative zero, which no value matched
    ?assertMatch(#p_literal{kind = float, value = +0.0}, pattern_of("-0.0")),
    ?assertMatch(#p_literal{kind = string, value = <<"let">>}, pattern_of("\"let\"")),
    ?assertMatch(#p_literal{kind = char, value = $-}, pattern_of("'-'")),
    ?assertMatch(#p_literal{kind = bool, value = false}, pattern_of("false")).

%% report §5.10
constructor_patterns_test() ->
    ?assertMatch(#p_constructor{name = 'None', args = none}, pattern_of("None")),
    ?assertMatch(#p_constructor{name = 'Some', args = {positional, #p_var{name = v}}},
                 pattern_of("Some(v)")),
    ?assertMatch(#p_constructor{name = 'Get',
                                args = {named, [#field_pattern{name = reply,
                                                               pattern = #p_var{name = r}}]}},
                 pattern_of("Get(reply = r)")),
    ?assertMatch(#p_constructor{name = 'Get', args = {named, []}}, pattern_of("Get()")),
    ?assertMatch(#p_constructor{name = 'Player',
                                args = {named, [#field_pattern{pattern = #p_literal{}}]}},
                 pattern_of("Player(alive = false)")),
    ?assertMatch(#p_constructor{path = ['Net', 'Http'], name = 'Request', args = {named, [_, _]}},
                 pattern_of("Net.Http.Request(method = m, path = p)")),
    ?assertMatch(#p_constructor{args = {positional,
                                        #p_as{pattern = #p_constructor{name = 'Snapshot'},
                                              name = snap}}},
                 pattern_of("Some(Snapshot(dir = d) as snap)")).

%% report §5.10
compound_patterns_test() ->
    ?assertMatch(#p_tuple{elements = [#p_var{}, #p_constructor{}]}, pattern_of("#(x, Some(y))")),
    ?assertMatch(#p_list{elements = []}, pattern_of("[]")),
    ?assertMatch(#p_list{elements = [#p_tuple{elements = [#p_wildcard{}, #p_var{}]}]},
                 pattern_of("[#(_, v)]")),
    ?assertMatch(#p_cons{head = #p_var{name = h}, tail = #p_var{name = t}}, pattern_of("h :: t")),
    ?assertMatch(#p_cons{head = #p_literal{value = $-},
                         tail = #p_cons{head = #p_literal{value = $>}}},
                 pattern_of("'-' :: '>' :: r")),
    ?assertMatch(#p_as{pattern = #p_cons{}, name = all}, pattern_of("x :: rest as all")),
    ?assertMatch(#p_bitstring{segments = [#bit_segment{value = #p_var{name = len},
                                                       specs = [{size, #e_literal{}}, big]},
                                          #bit_segment{value = #p_var{name = body},
                                                       specs = [{size, #e_var{name = len}}, bytes]},
                                          #bit_segment{value = #p_var{name = rest},
                                                       specs = [bytes]}]},
                 pattern_of("<<len:size(16)-big, body:size(len)-bytes, rest:bytes>>")).

%%
%% Types
%%

%% report §3, §3.4
types_test() ->
    ?assertMatch(#t_named{path = [], name = 'Int', args = []}, type_of("Int")),
    ?assertMatch(#t_var{name = a}, type_of("a")),
    ?assertMatch(#t_named{name = 'Map', args = [#t_named{name = 'String'}, #t_var{name = v}]},
                 type_of("Map(String, v)")),
    ?assertMatch(#t_named{path = ['Ets'], name = 'Table', args = [_, _]},
                 type_of("Ets.Table(k, v)")),
    ?assertMatch(#t_tuple{elements = [#t_named{name = 'Int'}, #t_named{name = 'Bool'}]},
                 type_of("#(Int, Bool)")),
    ?assertMatch(#t_fn{params = [], result_type = #t_named{name = 'Unit'}, effect = undefined},
                 type_of("() -> Unit")),
    ?assertMatch(#t_fn{params = [#t_named{name = 'A'}, #t_named{name = 'B'}],
                       result_type = #t_named{name = 'C'}, effect = #t_named{name = 'M'}},
                 type_of("(A, B) -> C with M")),
    ?assertMatch(#t_named{name = 'Int'}, type_of("(Int)")),
    %% with binds to the nearest arrow
    ?assertMatch(#t_fn{result_type = #t_fn{effect = #t_named{name = 'M'}}, effect = undefined},
                 type_of("(A) -> (B) -> C with M")),
    ?assertMatch(#t_fn{result_type = #t_fn{effect = undefined}, effect = #t_named{name = 'M'}},
                 type_of("(A) -> ((B) -> C) with M")),
    ?assertMatch(#t_fn{params = [#t_fn{params = [#t_var{name = a}], result_type = #t_var{name = b},
                                       effect = #t_var{name = e}}, #t_var{name = a}]},
                 type_of("((a) -> b with e, a) -> b with e")).

%%
%% Declarations
%%

%% report §3.5, §4.3
type_declaration_test() ->
    ?assertMatch(#type_declaration{export = false, name = 'Direction', params = [],
                                   constructors = [#constructor{name = 'North', fields = none},
                                                   #constructor{name = 'South'}]},
                 declaration("type Direction = North | South")),
    ?assertMatch(#type_declaration{export = true, name = 'Optional', params = [a],
                                   constructors = [#constructor{name = 'None'},
                                                   #constructor{name = 'Some',
                                                                fields = {positional,
                                                                          #t_var{name = a}}}]},
                 declaration("export type Optional(a) = None | Some(a)")),
    ?assertMatch(#type_declaration{constructors = [#constructor{
                                                       name = 'Snapshot',
                                                       fields = {named,
                                                                 [#field{name = dir,
                                                                         annotation = #t_named{}},
                                                                  #field{name = seen}]}}]},
                 declaration("type Snapshot = Snapshot(dir : Path, seen : Map(Path, Int))")),
    #type_declaration{constructors = [#constructor{name = 'Upgrade', fields = {named, Fields}}]} =
        declaration("type M = Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with M)"),
    ?assertMatch([#field{annotation = #t_fn{}}, #field{annotation = #t_fn{effect = #t_named{}}}],
                 Fields).

%% report §4.4: an abstract type is a type declaration marked `abstract`, and
%% has no signature
abstract_declaration_test() ->
    ?assertMatch(#abstract_declaration{export = true,
                                       declaration =
                                           #type_declaration{name = 'Stack', params = [a],
                                                             constructors =
                                                                 [#constructor{name = 'Stack'}]}},
                 declaration("export abstract type Stack(a) = Stack(List(a))")),
    ?assertMatch({error, #diagnostic{message = "an abstract type has no signature: every definition"
                                               " of its module may use its constructors, so leave"
                                               " out `with { ... }`"}},
                 ern_parser:parse_string("abstract type S = S(Int) with {\n    e : S\n}\n")).

%% report §4.5
fn_declaration_test() ->
    ?assertMatch(#fn_declaration{export = true, member_of = undefined, name = main, params = [],
                                 result_type = #t_named{name = 'Unit'},
                                 effect = #t_named{name = 'Never'},
                                 body = #e_call{}, doc = undefined},
                 declaration("export fn main() : Unit with Never = Io.println(\"hi\")")),
    ?assertMatch(#fn_declaration{name = double,
                                 params = [#param{pattern = #p_var{name = n},
                                                  annotation = #t_named{name = 'Int'}}],
                                 result_type = #t_named{name = 'Int'}, effect = undefined},
                 declaration("fn double(n : Int) : Int = n * 2")),
    ?assertMatch(#fn_declaration{name = twice, params = [#param{annotation = undefined}],
                                 result_type = undefined},
                 declaration("fn twice(n) = n + n")),
    ?assertMatch(#fn_declaration{member_of = undefined, name = push,
                                 params = [#param{pattern = #p_var{}},
                                           #param{pattern = #p_constructor{name = 'Stack'},
                                                  annotation = #t_named{name = 'Stack'}}]},
                 declaration("fn push(x : a, Stack(xs) : Stack(a)) : Stack(a) = Stack(x :: xs)")),
    ?assertMatch(#fn_declaration{member_of = 'Stack', name = compare},
                 declaration("fn Stack.compare(a : Stack(Int), b : Stack(Int)) : Ordering ="
                             " Equal")),
    ?assertMatch(#fn_declaration{member_of = 'Distance', name = negate},
                 declaration("fn Distance.negate(Distance(a)) : Distance = Distance(-a)")),
    ?assertMatch(#fn_declaration{member_of = 'Distance', name = '+'},
                 declaration("fn Distance.+(Distance(a), Distance(b)) : Distance ="
                             " Distance(a + b)")),
    ?assertMatch(#fn_declaration{params = [#param{pattern = #p_constructor{name = 'Snapshot'}}]},
                 declaration("fn seenCount(Snapshot(seen = entries) : Snapshot) : Int ="
                             " Map.size(entries)")).

%% report §4.6
let_declaration_test() ->
    ?assertMatch(#let_declaration{export = false, name = pi,
                                  annotation = #t_named{name = 'Float'},
                                  body = #e_literal{kind = float}},
                 declaration("let pi : Float = 3.14")),
    ?assertMatch(#let_declaration{export = true, name = empty, annotation = #t_named{},
                                  body = #e_constructor{name = 'Stack'}},
                 declaration("export let empty : Stack(a) = Stack([])")),
    ?assertMatch(#let_declaration{name = x, annotation = undefined}, declaration("let x = 1")).

%% report §4.7
foreign_declaration_test() ->
    ?assertMatch(#foreign_type_declaration{export = true, name = 'Table', params = [k, v]},
                 declaration("export foreign type Table(k, v)")),
    ?assertMatch(#foreign_type_declaration{export = false, name = 'Handle', params = []},
                 declaration("foreign type Handle")),
    %% a parameter that requires equality, Appendix A's ForeignVar
    ?assertMatch(#foreign_type_declaration{params = [k, v], equality = [k]},
                 declaration("export foreign type Table(k=, v)")),
    ?assertMatch({error, _}, ern_parser:parse_string("type T(a=) = T(a)")),
    ?assertMatch(#foreign_fn_declaration{export = true, name = member,
                                         params = [#param{pattern = #p_var{name = t},
                                                          annotation = #t_named{}},
                                                   #param{pattern = #p_var{name = key},
                                                          annotation = #t_var{name = k}}],
                                         result_type = #t_named{name = 'Bool'},
                                         effect = #t_var{name = m},
                                         implementation = <<"ets:member/2">>},
                 declaration("export foreign fn member(t : Table(k, v), key : k) : Bool with m"
                             " = \"ets:member/2\"")),
    ?assertMatch(#foreign_fn_declaration{name = atom, effect = undefined},
                 declaration("foreign fn atom(name : String) : Foreign.Term ="
                             " \"erlang:binary_to_atom/1\"")).

%% report §2.2
doc_comments_test() ->
    ?assertMatch([#fn_declaration{doc = <<"Adds one.\nReally.">>}],
                 declarations("/// Adds one.\n/// Really.\nfn inc(n) = n + 1")),
    ?assertMatch([#type_declaration{doc = <<"A table">>}],
                 declarations("/// A table\nexport type T = T")),
    %% a blank line breaks the attachment; first in the file, the block is then
    %% the module's documentation, and anywhere else it documents nothing and
    %% is an error: after a blank line, inside an expression, above a `fn` in
    %% a block, or second before the first declaration (findings.md's P1-19,
    %% K-11, K-17)
    ?assertMatch([#module_doc{text = <<"first">>}, #fn_declaration{doc = undefined}],
                 declarations("/// first\n\nfn inc(n) = n + 1")),
    Nothing = "a doc block documents nothing here",
    ?assertEqual(Nothing, refusal("fn a() = 1\n/// lost\n\nfn inc(n) = n + 1")),
    ?assertEqual(Nothing, refusal("fn f() = {\n    /// not a doc\n    1\n}")),
    ?assertEqual(Nothing, refusal("fn f() = {\n    /// not a doc\n    fn g() = 1;\n    g()\n}")),
    ?assertEqual(Nothing, refusal("/// first\n\n/// second\n\nfn inc(n) = n + 1")),
    ?assertEqual(Nothing, refusal("fn inc(n) = n + 1\n/// at the end\n")),
    %% and so is one above a lambda, which `fn` before a bracket opens and
    %% no declaration; it had failed as an expression expected (regression
    %% test)
    ?assertEqual(Nothing, refusal("let f =\n    /// not a doc\n    fn(x) = x")),
    ?assertEqual(Nothing, refusal("fn g() =\n    List.map(xs,\n             /// not a doc\n"
                                  "             fn(x) = x)")).

%% report §2.2: a tuple's `#(` opens a bracket as `(` does, so a
%% declaration after a type that holds a tuple type still ends the type,
%% and a doc block inside the function's body documents nothing, an error,
%% and is not taken for a constructor's. A regression test: `#(` was not
%% counted and `)` was, so the type never ended and the doc block was kept
%% as a doc token the expression could not parse.
doc_after_tuple_type_test() ->
    Nothing = "a doc block documents nothing here",
    ?assertEqual(Nothing, refusal("type T = A(#(Int, Int)) | B\n\n"
                                  "fn g(x : Int) : Int =\n    /// not a doc\n    x\n")),
    ?assertEqual(Nothing, refusal("fn f() = #(1, 2)\ntype T = A\n\n"
                                  "fn g(x : Int) : Int =\n    /// not a doc\n    x\n")).

%% report Appendix B
several_declarations_test() ->
    ?assertMatch([#type_declaration{}, #fn_declaration{name = main},
                  #fn_declaration{name = counter}],
                 declarations("type CounterMsg = Inc(Int) | Get(reply : Reply(Int))\n"
                              "export fn main() : Unit with m = { let c = spawn(fn() = counter(0));"
                              " send(c, Inc(5)) }\n"
                              "fn counter(n : Int) : Unit with CounterMsg = receive {\n"
                              "    Inc(k) -> counter(n + k)\n"
                              "  | Get(reply = r) -> { answer(r, n); counter(n) }\n}")).

%%
%% Errors, including the mandated diagnostics
%%

%% report §4.5
two_clause_function_test() ->
    ?assertEqual("a function has one clause", refusal("fn f(0) = 1\nfn f(n) = n")),
    ?assertEqual("a function has one clause",
                 expression_refusal("{ fn f(0) = 1; fn f(n) = n; f(1) }")),
    ?assertEqual("write one clause whose body is a `match`", help("fn f(0) = 1\nfn f(n) = n")).

%% report §5.2
juxtaposition_test() ->
    ?assertEqual("unexpected identifier `x` after an expression", refusal("fn g() = f x")),
    ?assertEqual("a call is written f(x), and statements are separated by `;`",
                 help("fn g() = f x")),
    ?assertEqual("unexpected integer 1 after an expression",
                 expression_refusal("{ let a = f 1; a }")).

%% report §5.4
trailing_semicolon_test() ->
    ?assertEqual("a block ends with an expression", expression_refusal("{ let x = 1; x; }")),
    ?assertEqual("remove the trailing `;`", expression_help("{ let x = 1; x; }")),
    ?assertEqual("a block ends with an expression, not a `let`",
                 expression_refusal("{ let x = 1 }")),
    ?assertEqual("a block needs at least one expression", expression_refusal("{}")).

%% report §5.8
if_without_else_test() ->
    ?assertEqual("`if` needs an `else`", expression_refusal("if c then a")),
    ?assertEqual("every `if` is an expression; give the other branch a value",
                 expression_help("if c then a")).

%% report §11.5: a help line says what is true of the input whatever the
%% parser cannot know. A regression test: `Io.println` as a type was told
%% `Io(println)`, `_p` was told it began `_p`, and `Circle()` was told it
%% had no fields, which the parser cannot see
help_lines_hold_test() ->
    ?assertEqual("a type's arguments are written in parentheses, as List(a), and a lowercase"
                 " name after `.` names a value", help("fn f(x : Io.println) : Int = 1")),
    ?assertEqual("a type name begins with an uppercase letter: P", help("type _p = A")),
    ?assertEqual("a type name begins with an uppercase letter", help("type _1 = A")),
    ?assertEqual("a constructor without fields is written without parentheses, Circle; one"
                 " with fields has its fields inside them", expression_help("Circle()")).

%% report §4.6
toplevel_bind_arrow_test() ->
    ?assertEqual("`<-` is a block form", refusal("let x <- f()")),
    ?assertEqual("a top-level `let` uses `=`", help("let x <- f()")).

%% report §5, §5.9: `if` and a lambda stand as an operand only in
%% parentheses; a `match` and a `receive`, ending at their own `}`, stand
%% as one as a block does
non_operand_forms_test() ->
    ?assertEqual("`if` is not an operand", expression_refusal("1 + if c then a else b")),
    ?assertEqual("parenthesize it", expression_help("1 + if c then a else b")),
    ?assertEqual("`fn` is not an operand", expression_refusal("x |> fn(y) = y")),
    ?assertMatch(#e_binop{operator = '+', right = #e_if{}}, expression("1 + (if c then a else b)")),
    ?assertMatch(#e_negation{expr = #e_match{}}, expression("-match x { _ -> 1 }")),
    ?assertMatch(#e_binop{operator = '||', left = #e_binop{operator = '&&', right = #e_match{}}},
                 expression("a && match x { _ -> true } || b")),
    ?assertMatch(#e_binop{operator = '+', left = #e_receive{}},
                 expression("receive { after 0 -> 1 } + 2")).

%% report §2.6, §4.8
operator_grammar_test() ->
    ?assertEqual("expected an expression instead of `+`", expression_refusal("f(+)")),
    ?assertEqual("expected a name instead of `+`", refusal("fn +(a, b) = a")),
    ?assertEqual("expected a name after `.` instead of `|>`", expression_refusal("Int.|>")),
    ?assertEqual("expected a name after `.` instead of `==`", expression_refusal("Int.==")),
    ?assertEqual("expected an operator, `compare` or `negate` after `.` instead of `|>`",
                 refusal("fn T.|>(a) = a")).

%% report §4.5, §4.6, Appendix A's DeclName and LetDecl: a member is an
%% operator, `compare` or `negate`, declared with `fn`
member_names_test() ->
    ?assertEqual({"`push` cannot be a member of Stack: a member is an operator, `compare` or"
                  " `negate`",
                  "a type's other operations are functions of its module: write `fn push`"},
                 refusal_and_help("fn Stack.push(s, x) = s")),
    ?assertEqual({"`size` cannot be a member of Stack: a member is an operator, `compare` or"
                  " `negate`",
                  "a type's other operations are functions of its module: write `fn size`"},
                 refusal_and_help("foreign fn Stack.size(s : Stack) : Int = \"m:f/1\"")),
    ?assertEqual({"a `let` declares no member of Stack",
                  "a type's values are named in its module, as its functions are:"
                  " write `let empty`"},
                 refusal_and_help("let Stack.empty = Stack([])")),
    ?assertEqual({"a `let` declares no member of Money",
                  "a member is declared with `fn`: write `fn Money.+(...)`"},
                 refusal_and_help("let Money.+ = 1")),
    ?assertEqual({"a `let` declares no member of Money",
                  "a member is declared with `fn`: write `fn Money.compare(...)`"},
                 refusal_and_help("let Money.compare = 1")),
    ?assertEqual({"expected a name instead of type name `Stack`",
                  "a value's name begins with a lowercase letter"},
                 refusal_and_help("let Stack = 1")).

%% report Appendix A
misc_errors_test() ->
    ?assertEqual("`_` is a pattern, not an expression", expression_refusal("_ + 1")),
    ?assertEqual("empty parentheses after None", expression_refusal("None()")),
    ?assertEqual("expected a name instead of type name `Stack`", refusal("fn Stack(x) = x")),
    ?assertEqual("a foreign function declares its result type",
                 refusal("foreign fn f(x : Int) = \"m:f/1\"")),
    ?assertEqual("expected `)` instead of `;`", expression_refusal("f(a;")),
    ?assertEqual("expected an expression instead of end of input", expression_refusal("1 +")),
    ?assertEqual("expected a declaration (type, abstract, fn, let, foreign) instead of `}`",
                 refusal("}")),
    ?assertEqual("expected `->` after a parameter list instead of `=`",
                 refusal("let f : (A, B) = x")),
    ?assertEqual("unknown bitstring specifier `bogus`", expression_refusal("<<x:bogus>>")),
    %% report §2.6, §11.5: max-munch reads `a<-1` as a binding arrow, and the
    %% error says how to write the comparison
    ?assertEqual("expected `then` instead of `<-`", expression_refusal("if a<-1 then 1 else 2")),
    ?assertEqual("`<-` is one token; write `a < -1` to compare with a negative number",
                 expression_help("if a<-1 then 1 else 2")),
    %% report §5.11: `bits` and `native` are Erlang's, not Ernest's
    ?assertEqual("unknown bitstring specifier `bits`", expression_refusal("<<x:bits>>")),
    ?assertEqual("unknown bitstring specifier `native`",
                 expression_refusal("<<x:size(32)-native>>")),
    ?assertEqual("expected a number after `-` in a pattern instead of identifier `x`",
                 expression_refusal("match y { -x -> 1 }")),
    ?assertEqual("expected a type name; a qualified type ends in an uppercase name",
                 refusal("let x : Int.foo = 1")),
    ?assertEqual("expected end of input instead of `)`", expression_refusal("1)")).

%% report §11.1
lexer_errors_pass_through_test() ->
    ?assertMatch({error, #diagnostic{span = {1, 10, _}, message = "unterminated string literal"}},
                 ern_parser:parse_string("fn f() = \"abc")).

%% report §11.5: a node's span runs from its first token to the end of its
%% last, so a call includes its closing paren, an operator expression its
%% right operand, a block its closing brace, and a declaration its body
spans_test() ->
    {ok, #e_call{span = {1, 1, {1, 8}}}} = ern_parser:parse_expr("f(x, y)"),
    {ok, #e_binop{span = {1, 1, {1, 9}}, left = #e_var{span = {1, 1, {1, 2}}}}} =
        ern_parser:parse_expr("a + g(b)"),
    {ok, #e_block{span = {1, 1, {2, 6}}}} = ern_parser:parse_expr("{ x;\n  y }"),
    {ok, [#fn_declaration{span = {1, 1, {1, 14}}, body = #e_literal{span = {1, 11, {1, 14}}}}]} =
        ern_parser:parse_string("fn f(x) = 123\n"),
    {ok, #e_literal{span = {1, 1, {1, 5}}}} = ern_parser:parse_expr("\"ab\"\n"),
    ok.

%% report §11.5, §5.9: an or-pattern spans its alternatives, from the
%% first to the end of the last. A regression test: its span was the first
%% alternative's alone, so a diagnostic on it underlined too little.
or_pattern_span_test() ->
    {ok, #e_match{clauses = [#clause{pattern = #p_or{span = {1, 11, {1, 23}}}}, _]}} =
        ern_parser:parse_expr("match x { 1 or 2 or 33 -> 0 | _ -> 1 }").

%% report §11.5: a parse error's span is the offending token
error_span_test() ->
    ?assertMatch({error, #diagnostic{span = {1, 8, {1, 9}}}},
                 ern_parser:parse_string("fn f() ; x\n")),
    ?assertMatch({error, #diagnostic{span = {1, 6, {1, 11}}}}, ern_parser:parse_expr("f(x) hello")).

%%
%% The example programs
%%

%% report Appendix A: the examples, the standard library and the
%% libraries exercise every AST record the emitter must handle
ast_coverage_test() ->
    {ok, Header} = file:read_file("../include/ern_ast.hrl"),
    {match, Matches} = re:run(Header, "-record\\(([a-z_]+),",
                              [global, {capture, all_but_first, list}]),
    Declared = lists:usort([list_to_atom(Name) || [Name] <- Matches]),
    Used = lists:usort(lists:foldl(fun(File, Acc) ->
                                       {ok, Source} = file:read_file(File),
                                       {ok, Declarations} = ern_parser:parse_string(Source),
                                       tags(Declarations, Acc)
                                   end, [], ernest_files())),
    %% Bytes, written with the bit syntax since MVP 2.65, gives a bitstring
    %% with segments and a bitstring pattern their first use outside the
    %% parser's own tests
    ?assertEqual([], Declared -- Used).

tags(Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    lists:foldl(fun tags/2, [element(1, Node) | Acc], tl(tuple_to_list(Node)));
tags(Nodes, Acc) when is_list(Nodes) ->
    lists:foldl(fun tags/2, Acc, Nodes);
tags(_, Acc) ->
    Acc.

%% report Appendix B, examples/
examples_parse_test_() ->
    Files = ernest_files(),
    ?assert(length(Files) >= 12),
    [{File, fun() ->
                {ok, Source} = file:read_file(File),
                ?assertMatch({ok, [_ | _]}, ern_parser:parse_string(Source))
            end} || File <- Files].

%% The examples, the standard library and the libraries together: all are
%% Ernest we own, and the libraries are where a foreign type lives. A name
%% that begins with a dot is an editor's artifact and no module (report
%% §11.1).
ernest_files() ->
    Found = filelib:wildcard("../../../examples/**/*.ern")
        ++ filelib:wildcard("../../../stdlib/*.ern") ++ filelib:wildcard("../../../libs/*/*.ern"),
    [File || File <- Found, hd(filename:basename(File)) =/= $.].

%% report §1, Appendix A: the grammar fragments in the sections are Appendix
%% A's rules; Appendix A is the truth and this test keeps the fragments equal
%% to it. The grammar stands in the bare fences; an ```ernest fence is code.
grammar_fragments_test() ->
    {ok, Source} = file:read_file("../../../ernest_report.md"),
    Text = unicode:characters_to_list(Source),
    [Body, FromAppendix] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(FromAppendix, "## Appendix B"),
    All = fun(Subject, Regex, Options) ->
              case re:run(Subject, Regex,
                          [global, unicode, {capture, all_but_first, list} | Options]) of
                  {match, Matches} -> Matches;
                  nomatch -> []
              end
          end,
    Rules = fun(Section) ->
                maps:from_list(
                  [{Name, re:replace(Rule, "\\s+", " ", [global, unicode, {return, list}])}
                   || ["", Block] <- All(Section, "```([\\w-]*)\n([\\s\\S]*?)```", []),
                      [Rule, Name] <- All(Block, "^((\\w+)\\s*=[\\s\\S]*?\\s\\.)$", [multiline])])
            end,
    InAppendix = Rules(Appendix),
    InSections = Rules(Body),
    ?assert(map_size(InAppendix) > 40),
    ?assertEqual([],
                 [Name || Name := Rule <- InAppendix,
                          maps:get(Name, InSections, undefined) =/= Rule]).

%% report §5.11, Appendix A BitExpr, BitPat, BitSpec: segments with
%% dash-separated specifiers, size with an expression, and no `unit`
bitstrings_test() ->
    ?assertMatch(#e_bitstring{segments = []}, expression("<<>>")),
    ?assertMatch(#e_bitstring{segments = [#bit_segment{value = #e_literal{value = 1}, specs = []},
                                          #bit_segment{value = #e_var{name = x},
                                                       specs = [{size, #e_binop{operator = '+'}},
                                                                big,
                                                                signed]},
                                          #bit_segment{value = #e_var{name = b}, specs = [bytes]}]},
                 expression("<<1, x:size(n + 1)-big-signed, b:bytes>>")),
    ?assertMatch(#e_match{clauses = [#clause{pattern = #p_bitstring{segments =
                                                   [#bit_segment{value = #p_var{name = len},
                                                                 specs = [{size, _}, big]},
                                                    #bit_segment{value = #p_var{name = body},
                                                                 specs = [{size,
                                                                           #e_var{name = len}},
                                                                          bytes]},
                                                    #bit_segment{value = #p_wildcard{},
                                                                 specs = [utf8]}]}}
                                     | _]},
                 expression("match b { <<len:size(16)-big, body:size(len)-bytes, _:utf8>> -> len"
                            " | _ -> 0 }")),
    ?assertEqual("unknown bitstring specifier `word`", expression_refusal("<<1:word>>")),
    ?assertEqual("there is no `unit` specifier", expression_refusal("<<1:unit>>")).

%% report §11.2, §2.5: an input the parser cannot finish is marked, so
%% that the shell takes another line for it. It ran out of tokens where
%% more were expected, or the lexer ended inside a raw string or a block
%% comment, both of which may span lines; a string or a char literal may
%% not, so an unfinished one is an error whatever follows.
incomplete_test() ->
    ?assert(is_incomplete_expression("1 + ")),
    ?assert(is_incomplete_expression("{ 1")),
    ?assert(is_incomplete_expression("match x {")),
    ?assert(is_incomplete_expression("`a raw string")),
    ?assertNot(is_incomplete_expression("1 + * 2")),
    ?assertNot(is_incomplete_expression("\"a string")),
    ?assertNot(is_incomplete_expression("'c")),
    ?assert(is_incomplete_program("fn f() =")),
    ?assert(is_incomplete_program("type T = A | ")),
    ?assert(is_incomplete_program("/* a comment")),
    ?assertMatch({ok, _}, ern_parser:parse_string("fn f() = 1")),
    %% an `if` whose `else` is still to come, and a parameter list whose
    %% `->` is; a regression test: the error stood at the `if` or the
    %% bracket, and the input was refused (findings.md's C2-4)
    ?assert(is_incomplete_expression("if c then a")),
    ?assertNot(is_incomplete_expression("if c then a )")),
    ?assert(is_incomplete_program("fn f(g : ()")).

%% report §11.2: an input that stops inside a call says which call and
%% which argument, the innermost call first, for `Shift-Tab`; `expected`
%% still says what may stand there, for completion
within_call_test() ->
    ?assertEqual({#enclosing{path = ['List'], name = map, argument = 1}, expression},
                 stopped_within(<<"List.map(xs, ">>)),
    ?assertEqual({#enclosing{path = ['List'], name = map, argument = 0}, expression},
                 stopped_within(<<"List.map(">>)),
    ?assertEqual({#enclosing{path = [], name = g, argument = 1}, expression},
                 stopped_within(<<"f(g(1, ">>)),
    ?assertMatch({#enclosing{path = [], name = f, argument = 1}, _},
                 stopped_within(<<"f(1, 2">>)),
    ?assertMatch({undefined, _}, stopped_within(<<"1 + ">>)).

%% erl/parser/src/ern_ast.erl: the one walk visits every node in pre-order,
%% into lists and nested records, threading its accumulator. A regression
%% test for the walk the checker, the reply check and the exhaustiveness
%% check had each copied.
ast_walk_test() ->
    Names = ern_ast:walk(fun(#e_var{name = Name}, Acc) -> [Name | Acc]; (_, Acc) -> Acc end,
                         expression("f(a, g(b), [c])"), []),
    ?assertEqual([f, a, g, b, c], lists:reverse(Names)).
