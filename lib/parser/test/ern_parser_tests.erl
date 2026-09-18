-module(ern_parser_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("lexer/include/ern_diag.hrl").

e(Text) ->
    {ok, E} = ern_parser:parse_expr(Text),
    E.

d(Text) ->
    {ok, [D]} = ern_parser:parse_string(Text),
    D.

ds(Text) ->
    {ok, Ds} = ern_parser:parse_string(Text),
    Ds.

err(Text) ->
    {error, #diag{message = Msg}} = ern_parser:parse_string(Text),
    Msg.

err_expr(Text) ->
    {error, #diag{message = Msg}} = ern_parser:parse_expr(Text),
    Msg.

help(Text) ->
    {error, #diag{help = Help}} = ern_parser:parse_string(Text),
    Help.

help_expr(Text) ->
    {error, #diag{help = Help}} = ern_parser:parse_expr(Text),
    Help.

%%
%% Expressions
%%

%% report §2.5
literals_test() ->
    ?assertMatch(#e_lit{kind = int, value = 42}, e("42")),
    ?assertMatch(#e_lit{kind = float, value = 1.5}, e("1.5")),
    ?assertMatch(#e_lit{kind = char, value = $a}, e("'a'")),
    ?assertMatch(#e_lit{kind = string, value = <<"hi">>}, e("\"hi\"")),
    ?assertMatch(#e_lit{kind = bool, value = true}, e("true")).

%% report §2.3, §4.2
names_test() ->
    ?assertMatch(#e_var{path = [], name = x}, e("x")),
    ?assertMatch(#e_var{path = ['Net', 'Http'], name = parse}, e("Net.Http.parse")),
    ?assertMatch(#e_var{path = ['Int'], name = '+'}, e("Int.+")),
    ?assertMatch(#e_con{path = [], name = 'None', args = none}, e("None")),
    ?assertMatch(#e_con{path = ['Net', 'Http'], name = 'Request', args = {positional, _}},
                 e("Net.Http.Request(x)")).

%% report §2.6
precedence_test() ->
    ?assertMatch(#e_binop{op = '+', left = #e_lit{value = 1},
                          right = #e_binop{op = '*', left = #e_lit{value = 2},
                                           right = #e_lit{value = 3}}},
                 e("1 + 2 * 3")),
    ?assertMatch(#e_binop{op = '-', left = #e_binop{op = '-', left = #e_var{name = a},
                                                    right = #e_var{name = b}},
                          right = #e_var{name = c}},
                 e("a - b - c")),
    ?assertMatch(#e_binop{op = '::', left = #e_var{name = a},
                          right = #e_binop{op = '::', left = #e_var{name = b},
                                           right = #e_var{name = c}}},
                 e("a :: b :: c")),
    ?assertMatch(#e_binop{op = '||', left = #e_binop{op = '&&',
                                                     left = #e_binop{op = '=='},
                                                     right = #e_var{name = c}},
                          right = #e_var{name = d}},
                 e("a == b && c || d")),
    ?assertMatch(#e_binop{op = '::', left = #e_binop{op = '+'}, right = #e_var{name = xs}},
                 e("1 + 2 :: xs")),
    ?assertMatch(#e_binop{op = '<>', left = #e_lit{}, right = #e_call{}},
                 e("\"a\" <> Int.toString(n)")).

%% report §2.6, §5.1
unary_minus_test() ->
    ?assertMatch(#e_neg{expr = #e_lit{value = 1}}, e("-1")),
    ?assertMatch(#e_neg{expr = #e_call{callee = #e_var{name = f}}}, e("-f(x)")),
    ?assertMatch(#e_binop{op = '*', left = #e_neg{}, right = #e_lit{value = 3}}, e("-2 * 3")),
    ?assertMatch(#e_binop{op = '-', left = #e_var{name = a}, right = #e_neg{}}, e("a - -b")).

%% report §5.2
calls_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = []}, e("f()")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}, #e_lit{}]},
                 e("f(x, 1)")),
    ?assertMatch(#e_call{callee = #e_call{callee = #e_var{name = f}, args = [_]}, args = [_]},
                 e("f(a)(b)")),
    ?assertMatch(#e_call{callee = #e_var{path = ['Address'], name = call}},
                 e("Address.call(c, fn(r) = Get(reply = r), 1000)")).

%% report §5.7: the pipe binds loosest, below ||, and takes a
%% parenthesized lambda
pipe_precedence_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{op = '+'}]}, e("a + b |> f")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{op = '||'}]},
                 e("a || b |> f")),
    ?assertMatch(#e_call{callee = #e_lambda{}, args = [#e_var{name = x}]},
                 e("x |> (fn(y) = y + 1)")).

%% report §5.7
pipe_rewrite_test() ->
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}]}, e("x |> f")),
    ?assertMatch(#e_call{callee = #e_var{name = f},
                         args = [#e_var{name = x}, #e_var{name = a}, #e_var{name = b}]},
                 e("x |> f(a, b)")),
    ?assertMatch(#e_call{callee = #e_call{callee = #e_var{name = f}, args = [#e_var{name = a}]},
                         args = [#e_var{name = x}, #e_var{name = b}]},
                 e("x |> f(a)(b)")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_var{name = x}, #e_var{name = a}]},
                 e("x |> (f(a))")),
    ?assertMatch(#e_call{callee = #e_var{name = c},
                         args = [#e_call{callee = #e_var{name = b}, args = [#e_var{name = a}]}]},
                 e("a |> b |> c")),
    ?assertMatch(#e_call{callee = #e_var{name = f}, args = [#e_binop{op = '+'}]},
                 e("a + b |> f")),
    ?assertMatch(#e_call{callee = #e_lambda{}, args = [#e_var{name = x}]},
                 e("x |> (fn(y) = y + 1)")).

%% report §5.6
constructors_test() ->
    ?assertMatch(#e_con{name = 'Some', args = {positional, #e_lit{value = 5}}}, e("Some(5)")),
    ?assertMatch(#e_con{name = 'Person', args = {named, undefined,
                                                 [#field_set{name = name, expr = #e_lit{}},
                                                  #field_set{name = age, expr = #e_lit{}}]}},
                 e("Person(name = \"A\", age = 30)")),
    ?assertMatch(#e_con{name = 'Person', args = {named, #e_var{name = p},
                                                 [#field_set{name = age}]}},
                 e("Person(..p, age = 31)")),
    ?assertMatch(#e_con{name = 'Some', args = {positional, #e_var{name = x}}}, e("Some(x)")).

%% report §3.2, §3.3
tuples_lists_test() ->
    ?assertMatch(#e_tuple{elems = [#e_lit{}, #e_lit{}]}, e("#(1, 2)")),
    ?assertMatch(#e_tuple{elems = [#e_lit{}]}, e("#(1)")),
    ?assertMatch(#e_list{elems = []}, e("[]")),
    ?assertMatch(#e_list{elems = [#e_lit{}, #e_lit{}, #e_lit{}]}, e("[1, 2, 3]")).

%% report Appendix A
parens_produce_no_node_test() ->
    ?assertMatch(#e_binop{op = '*', left = #e_binop{op = '+'}, right = #e_lit{}},
                 e("(1 + 2) * 3")),
    ?assertMatch(#e_var{name = x}, e("((x))")).

%% report §5.4
block_test() ->
    ?assertMatch(#e_block{stmts = [#binding{pattern = #p_var{name = x}, op = '=',
                                            expr = #e_lit{value = 5}},
                                   #binding{pattern = #p_tuple{}, op = '<-', ann = undefined},
                                   #binding{pattern = #p_var{name = m},
                                            ann = #t_con{name = 'Map'}},
                                   #fn_decl{name = helper, params = [_]},
                                   #e_call{}]},
                 e("{ let x = 5; let #(a, b) <- f(x); let m : Map(String, Int) = Map.empty;"
                   " fn helper(y) = y; helper(x) }")),
    ?assertMatch(#e_block{stmts = [#e_lambda{}, #e_var{}]}, e("{ fn(x) = x; y }")).

%% report §5.3
lambda_test() ->
    ?assertMatch(#e_lambda{params = [#param{pattern = #p_var{name = x}, type = undefined}],
                           ret = undefined, effect = undefined,
                           body = #e_binop{op = '+'}},
                 e("fn(x) = x + 1")),
    ?assertMatch(#e_lambda{params = [], ret = #t_con{name = 'Unit'},
                           effect = #t_con{name = 'Never'}, body = #e_con{name = 'Unit'}},
                 e("fn() -> Unit with Never = Unit")),
    %% the body extends to the enclosing delimiter
    ?assertMatch(#e_call{args = [#e_var{}, #e_lambda{body = #e_binop{op = '+'}}]},
                 e("List.map(xs, fn(x) = x + 1)")),
    ?assertMatch(#e_call{args = [#e_var{}, #e_lambda{body = #e_call{}}, #e_lit{}]},
                 e("f(a, fn(r) = g(r), 1)")).

%% report §5.8
if_test() ->
    ?assertMatch(#e_if{condition = #e_binop{op = '=='}, then_branch = #e_lit{},
                       else_branch = #e_binop{op = '+'}},
                 e("if n == 0 then 1 else n + 1")),
    ?assertMatch(#e_if{else_branch = #e_block{}}, e("if c then a else { b }")).

%% report §5.9
match_test() ->
    ?assertMatch(#e_match{scrutinee = #e_var{name = xs},
                          clauses = [#clause{pattern = #p_list{elems = []}, guard = undefined,
                                             body = #e_lit{}},
                                     #clause{pattern = #p_cons{}, guard = #e_binop{op = '>'},
                                             body = #e_var{}},
                                     #clause{pattern = #p_wild{}}]},
                 e("match xs { [] -> 0 | h :: _ when h > 0 -> h | _ -> 1 }")),
    ?assertMatch(#e_match{clauses = [#clause{body = #e_match{}}, #clause{}]},
                 e("match a { Some(b) -> match b { 1 -> x | _ -> y } | None -> z }")).

%% report §6.3
receive_test() ->
    ?assertMatch(#e_receive{clauses = [#clause{pattern = #p_con{name = 'Inc'}},
                                       #clause{pattern = #p_con{name = 'Get'}}],
                            'after' = undefined},
                 e("receive { Inc(k) -> counter(n + k) | Get(reply = r) -> counter(n) }")),
    ?assertMatch(#e_receive{clauses = [#clause{}],
                            'after' = #after_clause{timeout = #e_lit{value = 1000},
                                                    body = #e_con{name = 'None'}}},
                 e("receive { Data(n) -> Some(n) | after 1000 -> None }")),
    ?assertMatch(#e_receive{clauses = [], 'after' = #after_clause{timeout = #e_lit{value = 0}}},
                 e("receive { after 0 -> world }")).

%% report §5.11
bitstring_expr_test() ->
    ?assertMatch(#e_bits{segments = []}, e("<<>>")),
    ?assertMatch(#e_bits{segments = [#bit_seg{value = #e_lit{value = 0}, specs = []},
                                     #bit_seg{value = #e_lit{value = 1}}]},
                 e("<<0, 1>>")),
    ?assertMatch(#e_bits{segments = [#bit_seg{value = #e_var{name = len},
                                              specs = [{size, #e_lit{value = 16}}, big]},
                                     #bit_seg{value = #e_var{name = body}, specs = [bytes]}]},
                 e("<<len:size(16)-big, body:bytes>>")),
    ?assertMatch(#e_bits{segments = [#bit_seg{specs = [{unit, 8}, {size, #e_var{}}, little,
                                                       signed]}]},
                 e("<<x:unit(8)-size(n)-little-signed>>")).

%%
%% Patterns
%%

%% report §5.10
patterns_test() ->
    Pat = fun(Text) -> #e_match{clauses = [#clause{pattern = P}]} = e("match x { " ++ Text
                                                                      ++ " -> 0 }"), P end,
    ?assertMatch(#p_wild{}, Pat("_")),
    ?assertMatch(#p_var{name = '_x'}, Pat("_x")),
    ?assertMatch(#p_var{name = y}, Pat("y")),
    ?assertMatch(#p_lit{kind = int, value = 1}, Pat("1")),
    ?assertMatch(#p_lit{kind = int, value = -1}, Pat("-1")),
    ?assertMatch(#p_lit{kind = float, value = -2.5}, Pat("-2.5")),
    ?assertMatch(#p_lit{kind = string, value = <<"let">>}, Pat("\"let\"")),
    ?assertMatch(#p_lit{kind = char, value = $-}, Pat("'-'")),
    ?assertMatch(#p_lit{kind = bool, value = false}, Pat("false")),
    ?assertMatch(#p_con{name = 'None', args = none}, Pat("None")),
    ?assertMatch(#p_con{name = 'Some', args = {positional, #p_var{name = v}}}, Pat("Some(v)")),
    ?assertMatch(#p_con{name = 'Get', args = {named, [#field_pat{name = reply,
                                                                 pattern = #p_var{name = r}}]}},
                 Pat("Get(reply = r)")),
    ?assertMatch(#p_con{name = 'Get', args = {named, []}}, Pat("Get()")),
    ?assertMatch(#p_con{name = 'Player', args = {named, [#field_pat{pattern = #p_lit{}}]}},
                 Pat("Player(alive = false)")),
    ?assertMatch(#p_con{path = ['Net', 'Http'], name = 'Request', args = {named, [_, _]}},
                 Pat("Net.Http.Request(method = m, path = p)")),
    ?assertMatch(#p_tuple{elems = [#p_var{}, #p_con{}]}, Pat("#(x, Some(y))")),
    ?assertMatch(#p_list{elems = []}, Pat("[]")),
    ?assertMatch(#p_list{elems = [#p_tuple{elems = [#p_wild{}, #p_var{}]}]}, Pat("[#(_, v)]")),
    ?assertMatch(#p_cons{head = #p_var{name = h}, tail = #p_var{name = t}}, Pat("h :: t")),
    ?assertMatch(#p_cons{head = #p_lit{value = $-}, tail = #p_cons{head = #p_lit{value = $>}}},
                 Pat("'-' :: '>' :: r")),
    ?assertMatch(#p_as{pattern = #p_cons{}, name = all}, Pat("x :: rest as all")),
    ?assertMatch(#p_con{args = {positional, #p_as{pattern = #p_con{name = 'Snapshot'},
                                                  name = snap}}},
                 Pat("Some(Snapshot(dir = d) as snap)")),
    ?assertMatch(#p_bits{segments = [#bit_seg{value = #p_var{name = len},
                                              specs = [{size, #e_lit{}}, big]},
                                     #bit_seg{value = #p_var{name = body},
                                              specs = [{size, #e_var{name = len}}, bytes]},
                                     #bit_seg{value = #p_var{name = rest}, specs = [bytes]}]},
                 Pat("<<len:size(16)-big, body:size(len)-bytes, rest:bytes>>")).

%%
%% Types
%%

%% report §3, §3.4
types_test() ->
    T = fun(Text) -> #let_decl{ann = A} = d("let x : " ++ Text ++ " = y"), A end,
    ?assertMatch(#t_con{path = [], name = 'Int', args = []}, T("Int")),
    ?assertMatch(#t_var{name = a}, T("a")),
    ?assertMatch(#t_con{name = 'Map', args = [#t_con{name = 'String'}, #t_var{name = v}]},
                 T("Map(String, v)")),
    ?assertMatch(#t_con{path = ['Ets'], name = 'Table', args = [_, _]}, T("Ets.Table(k, v)")),
    ?assertMatch(#t_tuple{elems = [#t_con{name = 'Int'}, #t_con{name = 'Bool'}]},
                 T("#(Int, Bool)")),
    ?assertMatch(#t_fn{params = [], ret = #t_con{name = 'Unit'}, effect = undefined},
                 T("() -> Unit")),
    ?assertMatch(#t_fn{params = [#t_con{name = 'A'}, #t_con{name = 'B'}],
                       ret = #t_con{name = 'C'}, effect = #t_con{name = 'M'}},
                 T("(A, B) -> C with M")),
    ?assertMatch(#t_con{name = 'Int'}, T("(Int)")),
    %% with binds to the nearest arrow
    ?assertMatch(#t_fn{ret = #t_fn{effect = #t_con{name = 'M'}}, effect = undefined},
                 T("(A) -> (B) -> C with M")),
    ?assertMatch(#t_fn{ret = #t_fn{effect = undefined}, effect = #t_con{name = 'M'}},
                 T("(A) -> ((B) -> C) with M")),
    ?assertMatch(#t_fn{params = [#t_fn{params = [#t_var{name = a}], ret = #t_var{name = b},
                                       effect = #t_var{name = e}}, #t_var{name = a}]},
                 T("((a) -> b with e, a) -> b with e")).

%%
%% Declarations
%%

%% report §3.5, §4.3
type_decl_test() ->
    ?assertMatch(#type_decl{export = false, name = 'Direction', params = [],
                            constructors = [#constructor{name = 'North', fields = none},
                                            #constructor{name = 'South'}]},
                 d("type Direction = North | South")),
    ?assertMatch(#type_decl{export = true, name = 'Optional', params = [a],
                            constructors = [#constructor{name = 'None'},
                                            #constructor{name = 'Some',
                                                         fields = {positional, #t_var{name = a}}}]},
                 d("export type Optional(a) = None | Some(a)")),
    ?assertMatch(#type_decl{constructors = [#constructor{
                                                name = 'Snapshot',
                                                fields = {named, [#field{name = dir,
                                                                         type = #t_con{}},
                                                                  #field{name = seen}]}}]},
                 d("type Snapshot = Snapshot(dir : Path, seen : Map(Path, Mtime))")),
    ?assertMatch(#type_decl{constructors = [#constructor{
                                                name = 'Upgrade',
                                                fields = {named,
                                                          [#field{type = #t_fn{}},
                                                           #field{type = #t_fn{effect =
                                                                                   #t_con{}}}]}}]},
                 d("type M = Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with M)")).

%% report §4.4
abstract_decl_test() ->
    ?assertMatch(#abstract_decl{export = true,
                                type = #type_decl{name = 'Stack', params = [a],
                                                  constructors = [#constructor{name = 'Stack'}]},
                                signatures = [#signature{name = empty, type = #t_con{}},
                                              #signature{name = push, type = #t_fn{}},
                                              #signature{name = '+', type = #t_fn{}}]},
                 d("export abstract type Stack(a) = Stack(List(a)) with {\n"
                   "    empty : Stack(a);\n    push : (a, Stack(a)) -> Stack(a);\n"
                   "    + : (Stack(a), Stack(a)) -> Stack(a)\n}")).

%% report §4.5
fn_decl_test() ->
    ?assertMatch(#fn_decl{export = true, owner = undefined, name = main, params = [],
                          ret = #t_con{name = 'Unit'}, effect = #t_con{name = 'Never'},
                          body = #e_call{}, doc = undefined},
                 d("export fn main() -> Unit with Never = Io.println(\"hi\")")),
    ?assertMatch(#fn_decl{name = double, params = [#param{pattern = #p_var{name = n},
                                                          type = #t_con{name = 'Int'}}],
                          ret = #t_con{name = 'Int'}, effect = undefined},
                 d("fn double(n : Int) -> Int = n * 2")),
    ?assertMatch(#fn_decl{name = twice, params = [#param{type = undefined}], ret = undefined},
                 d("fn twice(n) = n + n")),
    ?assertMatch(#fn_decl{owner = 'Stack', name = push,
                          params = [#param{pattern = #p_var{}},
                                    #param{pattern = #p_con{name = 'Stack'},
                                           type = #t_con{name = 'Stack'}}]},
                 d("fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)")),
    ?assertMatch(#fn_decl{owner = 'Distance', name = '+'},
                 d("fn Distance.+(Distance(a), Distance(b)) -> Distance = Distance(a + b)")),
    ?assertMatch(#fn_decl{params = [#param{pattern = #p_con{name = 'Snapshot'}}]},
                 d("fn seenCount(Snapshot(seen = entries) : Snapshot) -> Int ="
                   " Map.size(entries)")).

%% report §4.6
let_decl_test() ->
    ?assertMatch(#let_decl{export = false, owner = undefined, name = pi,
                           ann = #t_con{name = 'Float'}, body = #e_lit{kind = float}},
                 d("let pi : Float = 3.14")),
    ?assertMatch(#let_decl{export = true, owner = 'Stack', name = empty, ann = #t_con{},
                           body = #e_con{name = 'Stack'}},
                 d("export let Stack.empty : Stack(a) = Stack([])")),
    ?assertMatch(#let_decl{name = x, ann = undefined}, d("let x = 1")).

%% report §4.7
foreign_decl_test() ->
    ?assertMatch(#foreign_type_decl{export = true, name = 'Table', params = [k, v]},
                 d("export foreign type Table(k, v)")),
    ?assertMatch(#foreign_type_decl{export = false, name = 'Handle', params = []},
                 d("foreign type Handle")),
    ?assertMatch(#foreign_fn_decl{export = true, name = member,
                                  params = [#param{pattern = #p_var{name = t}, type = #t_con{}},
                                            #param{pattern = #p_var{name = key},
                                                   type = #t_var{name = k}}],
                                  ret = #t_con{name = 'Bool'}, effect = #t_var{name = m},
                                  impl = <<"ets:member/2">>},
                 d("export foreign fn member(t : Table(k, v), key : k) -> Bool with m"
                   " = \"ets:member/2\"")),
    ?assertMatch(#foreign_fn_decl{name = atom, effect = undefined},
                 d("foreign fn atom(name : String) -> Foreign = \"erlang:binary_to_atom/1\"")).

%% report §2.2
doc_comments_test() ->
    ?assertMatch([#fn_decl{doc = <<"Adds one.\nReally.">>}],
                 ds("/// Adds one.\n/// Really.\nfn inc(n) = n + 1")),
    ?assertMatch([#type_decl{doc = <<"A table">>}],
                 ds("/// A table\nexport type T = T")),
    %% a blank line breaks the attachment; the block is then a comment
    ?assertMatch([#fn_decl{doc = undefined}], ds("/// lost\n\nfn inc(n) = n + 1")),
    %% a doc comment inside an expression is a comment
    ?assertMatch([#fn_decl{doc = undefined, body = #e_block{}}],
                 ds("fn f() = {\n    /// not a doc\n    1\n}")),
    ?assertMatch([#fn_decl{body = #e_block{stmts = [#fn_decl{doc = <<"local">>}, _]}}],
                 ds("fn f() = {\n    /// local\n    fn g() = 1;\n    g()\n}")).

%% report Appendix B
several_declarations_test() ->
    ?assertMatch([#type_decl{}, #fn_decl{name = main}, #fn_decl{name = counter}],
                 ds("type CounterMsg = Inc(Int) | Get(reply : Reply(Int))\n"
                    "export fn main() -> Unit with m = { let c = spawn(Local, fn() = counter(0));"
                    " send(c, Inc(5)) }\n"
                    "fn counter(n : Int) -> Unit with CounterMsg = receive {\n"
                    "    Inc(k) -> counter(n + k)\n"
                    "  | Get(reply = r) -> { answer(r, n); counter(n) }\n}")).

%%
%% Errors, including the mandated diagnostics
%%

%% report §4.5, plan 1.1
two_clause_function_test() ->
    ?assertEqual("a function has one clause", err("fn f(0) = 1\nfn f(n) = n")),
    ?assertEqual("a function has one clause", err_expr("{ fn f(0) = 1; fn f(n) = n; f(1) }")),
    ?assertEqual("write one clause whose body is a `match`", help("fn f(0) = 1\nfn f(n) = n")).

%% report §5.2, plan 1.1
juxtaposition_test() ->
    ?assertEqual("unexpected identifier `x` after an expression", err("fn g() = f x")),
    ?assertEqual("a call is written f(x), and statements are separated by `;`",
                 help("fn g() = f x")),
    ?assertEqual("unexpected integer 1 after an expression", err_expr("{ let a = f 1; a }")).

%% report §5.4
trailing_semicolon_test() ->
    ?assertEqual("a block ends with an expression", err_expr("{ let x = 1; x; }")),
    ?assertEqual("remove the trailing `;`", help_expr("{ let x = 1; x; }")),
    ?assertEqual("a block ends with an expression, not a `let`", err_expr("{ let x = 1 }")),
    ?assertEqual("a block needs at least one expression", err_expr("{}")).

%% report §5.8
if_without_else_test() ->
    ?assertEqual("`if` needs an `else`", err_expr("if c then a")),
    ?assertEqual("every `if` is an expression; give the other branch a value",
                 help_expr("if c then a")).

%% report §4.6
toplevel_bind_arrow_test() ->
    ?assertEqual("`<-` is a block form", err("let x <- f()")),
    ?assertEqual("a top-level `let` uses `=`", help("let x <- f()")).

%% report §5
non_operand_forms_test() ->
    ?assertEqual("`if` is not an operand", err_expr("1 + if c then a else b")),
    ?assertEqual("parenthesize it", help_expr("1 + if c then a else b")),
    ?assertEqual("`fn` is not an operand", err_expr("x |> fn(y) = y")),
    ?assertEqual("`match` is not an operand", err_expr("-match x { _ -> 1 }")),
    ?assertMatch(#e_binop{op = '+', right = #e_if{}}, e("1 + (if c then a else b)")).

%% report §2.6, §4.8
operator_grammar_test() ->
    ?assertEqual("expected an expression instead of `+`", err_expr("f(+)")),
    ?assertEqual("expected a name instead of `+`", err("fn +(a, b) = a")),
    ?assertEqual("expected a name after `.` instead of `|>`", err_expr("Int.|>")),
    ?assertEqual("expected a name after `.` instead of `==`", err_expr("Int.==")),
    ?assertEqual("expected a signature name instead of `|>`",
                 err("abstract type T = T with { |> : (T) -> T }")).

%% report Appendix A
misc_errors_test() ->
    ?assertEqual("`_` is a pattern, not an expression", err_expr("_ + 1")),
    ?assertEqual("a constructor's fields are listed inside the parentheses", err_expr("None()")),
    ?assertEqual("expected a name; a type member is written `Stack.name`",
                 err("fn Stack(x) = x")),
    ?assertEqual("a foreign function declares its return type",
                 err("foreign fn f(x : Int) = \"m:f/1\"")),
    ?assertEqual("expected `)` instead of `;`", err_expr("f(a;")),
    ?assertEqual("expected an expression instead of end of input", err_expr("1 +")),
    ?assertEqual("expected a declaration (type, abstract, fn, let, foreign) instead of `}`",
                 err("}")),
    ?assertEqual("expected `->` after a parameter list instead of `=`",
                 err("let f : (A, B) = x")),
    ?assertEqual("unknown bitstring specifier `bogus`", err_expr("<<x:bogus>>")),
    ?assertEqual("expected a number after `-` in a pattern instead of identifier `x`",
                 err_expr("match y { -x -> 1 }")),
    ?assertEqual("expected a type name; a qualified type ends in an uppercase name",
                 err("let x : Int.foo = 1")),
    ?assertEqual("expected end of input instead of `)`", err_expr("1)")).

%% report §11.1
lexer_errors_pass_through_test() ->
    ?assertMatch({error, #diag{span = {1, 10, _}, message = "unterminated string literal"}},
                 ern_parser:parse_string("fn f() = \"abc")).

%% report §11.5: a node's pos is its span, first token to the end of its
%% last, so a call includes its closing paren, an operator expression its
%% right operand, a block its closing brace, and a declaration its body
spans_test() ->
    {ok, #e_call{pos = {1, 1, {1, 8}}}} = ern_parser:parse_expr("f(x, y)"),
    {ok, #e_binop{pos = {1, 1, {1, 9}}, left = #e_var{pos = {1, 1, {1, 2}}}}} =
        ern_parser:parse_expr("a + g(b)"),
    {ok, #e_block{pos = {1, 1, {2, 6}}}} = ern_parser:parse_expr("{ x;\n  y }"),
    {ok, [#fn_decl{pos = {1, 1, {1, 14}}, body = #e_lit{pos = {1, 11, {1, 14}}}}]} =
        ern_parser:parse_string("fn f(x) = 123\n"),
    {ok, #e_lit{pos = {1, 1, {1, 5}}}} = ern_parser:parse_expr("\"ab\"\n"),
    ok.

%% report §11.5: a parse error's span is the offending token
error_span_test() ->
    ?assertMatch({error, #diag{span = {1, 8, {1, 9}}}}, ern_parser:parse_string("fn f() ; x\n")),
    ?assertMatch({error, #diag{span = {1, 6, {1, 11}}}}, ern_parser:parse_expr("f(x) hello")).

%%
%% The example programs
%%

%% report Appendix A, plan 2.1: the examples exercise every AST record the
%% emitter must handle; bitstrings are MVP 2
ast_coverage_test() ->
    {ok, Hrl} = file:read_file("../include/ern_ast.hrl"),
    {match, M} = re:run(Hrl, "-record\\(([a-z_]+),", [global, {capture, all_but_first, list}]),
    Declared = lists:usort([list_to_atom(N) || [N] <- M]),
    Files = [F || F <- filelib:wildcard("../../../examples/**/*.ern"),
                  hd(filename:basename(F)) =/= $.], % editor artifacts, report §11.1
    Used = lists:usort(lists:foldl(fun(F, Acc) ->
                                       {ok, Bin} = file:read_file(F),
                                       {ok, Ds} = ern_parser:parse_string(Bin),
                                       tags(Ds, Acc)
                                   end, [], Files)),
    ?assertEqual([bit_seg, e_bits, p_bits], Declared -- Used).

tags(T, Acc) when is_tuple(T), is_atom(element(1, T)) ->
    lists:foldl(fun tags/2, [element(1, T) | Acc], tl(tuple_to_list(T)));
tags(L, Acc) when is_list(L) ->
    lists:foldl(fun tags/2, Acc, L);
tags(_, Acc) ->
    Acc.

%% report Appendix B, examples/
examples_parse_test_() ->
    Files = [F || F <- filelib:wildcard("../../../examples/**/*.ern"),
                  hd(filename:basename(F)) =/= $.], % editor artifacts, report §11.1
    ?assert(length(Files) >= 12),
    [{F, fun() ->
              {ok, Bin} = file:read_file(F),
              ?assertMatch({ok, [_ | _]}, ern_parser:parse_string(Bin))
          end} || F <- Files].

%% report §1, Appendix A: the grammar fragments in the sections are Appendix
%% A's rules; Appendix A is the truth and this test keeps the fragments equal
%% to it
grammar_fragments_test() ->
    {ok, Bin} = file:read_file("../../../ernest_report.md"),
    Text = unicode:characters_to_list(Bin),
    [Body, Appendix0] = string:split(Text, "## Appendix A. Grammar"),
    [Appendix | _] = string:split(Appendix0, "## Appendix B"),
    All = fun(Subject, Re, Opts) ->
              case re:run(Subject, Re, [global, unicode, {capture, all_but_first, list} | Opts]) of
                  {match, Ms} -> Ms;
                  nomatch -> []
              end
          end,
    Rules = fun(T) ->
                maps:from_list(
                  [{N, re:replace(R, "\\s+", " ", [global, unicode, {return, list}])}
                   || [B] <- All(T, "```\n([\\s\\S]*?)```", []),
                      [R, N] <- All(B, "^((\\w+)\\s*=[\\s\\S]*?\\s\\.)$", [multiline])])
            end,
    InAppendix = Rules(Appendix),
    InSections = Rules(Body),
    ?assert(map_size(InAppendix) > 40),
    ?assertEqual([], [N || N := R <- InAppendix, maps:get(N, InSections, undefined) =/= R]).
