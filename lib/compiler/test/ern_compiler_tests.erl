-module(ern_compiler_tests).

-export([write_golden/0]).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("lexer/include/ern_diag.hrl").
-include_lib("type_system/include/ern_types.hrl").

%%
%% Helpers
%%

%% Type-check, compile, load, initialize, and run a program's main under
%% the launcher, collecting what reaches stdout.
run(Text) ->
    run(['M'], Text).

run(Ns, Text) ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Text),
    {ok, Mod, Bin} = ern_compiler:compile(Ns, Typed, Iface, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    Result = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                             #{init => fun() -> init(Mod) end,
                               stdout => fun(B) -> Me ! {out, B} end}),
    {Result, collect([])}.

%% The launcher's job (report §8.5, plan 2.4): top-level lets before main.
init(Mod) ->
    case erlang:function_exported(Mod, '$init', 0) of
        true -> Mod:'$init'();
        false -> ok
    end.

collect(Acc) ->
    receive
        {out, B} -> collect([B | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

compile_error(Text) ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'], Text),
    {error, [#diag{message = Msg}]} = ern_compiler:compile(['M'], Typed, Iface, Env),
    Msg.

example(Base) ->
    {ok, Bin} = file:read_file("../../../examples/" ++ Base ++ ".ern"),
    {[list_to_atom(string:titlecase(Base))], Bin}.

%% The forms of an example and of a target file, made comparable: no
%% annotations, and variables renamed in order of first occurrence, each
%% clause's pattern variables fresh in that clause, so that a hand-written
%% target may reuse a name across clauses where the emitter does not.
example_forms(Base) ->
    {Ns, Bin} = example(Base),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Ns, Bin),
    normalize(ern_compiler:forms(Ns, Typed, Env)).

target_forms(File) ->
    {ok, Forms} = epp:parse_file("../../../test/target/" ++ File, []),
    normalize([F || F <- Forms, element(1, F) =/= eof, not is_file_attr(F)]).

is_file_attr({attribute, _, file, _}) -> true;
is_file_attr(_) -> false.

normalize(Forms) ->
    [erl_parse:map_anno(fun(_) -> 0 end, erl_syntax:revert(element(1, rename(F, {#{}, 0}))))
     || F <- Forms].

%% State: {Name => New, Counter}.
rename(Node, {Map, N} = St) ->
    case erl_syntax:type(Node) of
        variable ->
            Name = erl_syntax:variable_name(Node),
            case Map of
                #{Name := New} -> {erl_syntax:variable(New), St};
                _ ->
                    New = list_to_atom("V" ++ integer_to_list(N)),
                    {erl_syntax:variable(New), {Map#{Name => New}, N + 1}}
            end;
        clause ->
            Pats = erl_syntax:clause_patterns(Node),
            PatVars = lists:append([sets:to_list(erl_syntax_lib:variables(P)) || P <- Pats]),
            Inner = {maps:without(PatVars, Map), N},
            {Pats1, St1} = lists:mapfoldl(fun rename/2, Inner, Pats),
            {Guard, St2} = case erl_syntax:clause_guard(Node) of
                               none -> {none, St1};
                               G -> rename(G, St1)
                           end,
            {Body, {_, N3}} = lists:mapfoldl(fun rename/2, St2, erl_syntax:clause_body(Node)),
            {erl_syntax:clause(Pats1, Guard, Body), {Map, N3}};
        _ ->
            case erl_syntax:subtrees(Node) of
                [] -> {Node, St};
                Groups ->
                    {Groups1, St1} = lists:mapfoldl(
                                       fun(Group, S) -> lists:mapfoldl(fun rename/2, S, Group) end,
                                       St, Groups),
                    {erl_syntax:update_tree(Node, Groups1), St1}
            end
    end.

%%
%% Golden tests: the emitter reproduces the hand-written targets
%%

%% report §8.1, §8.4, Appendix B; plan 2.1
hello_golden_test() ->
    ?assertEqual(target_forms("hello.erl"), example_forms("hello")).

%% report §6.2, §6.3, §6.6, §8.4, Appendix B; plan 2.1
counter_golden_test() ->
    ?assertEqual(target_forms("counter.erl"), example_forms("counter")).

%%
%% Golden files: the Erlang source of every MVP 1 example, as --emit erl
%% writes it, kept under test/golden and regenerated with make golden
%%

-define(GOLDEN, "../../../test/golden/").

golden_names() ->
    ["hello", "counter", "upgrade", "pingpong", "stack", "patterns", "kvparser",
     "remote", "modules/net/http", "modules/main"].

%% The source the compiler emits for an example; the modules pair is
%% checked in dependency order, main against http's interface.
golden_source("modules/" ++ _ = Name) ->
    {ok, HttpBin} = file:read_file("../../../examples/modules/net/http.ern"),
    {ok, HttpTyped, HttpIface, HttpEnv} = ern_typecheck:check_string(['Net', 'Http'], HttpBin),
    case Name of
        "modules/net/http" ->
            emitted(['Net', 'Http'], HttpTyped, HttpEnv);
        "modules/main" ->
            {ok, MainBin} = file:read_file("../../../examples/modules/main.ern"),
            {ok, Decls} = ern_parser:parse_string(MainBin),
            {ok, Typed, _, Env} = ern_typecheck:check(['Main'], Decls, [HttpIface]),
            emitted(['Main'], Typed, Env)
    end;
golden_source(Name) ->
    {Ns, Bin} = example(Name),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Ns, Bin),
    emitted(Ns, Typed, Env).

emitted(Ns, Typed, Env) ->
    unicode:characters_to_binary(ern_compiler:erl_source(Ns, Typed, Env)).

%% report §11.1, plan 2: the emitted source of every example is what the
%% golden file holds; a difference is written beside it as .new
golden_test_() ->
    [{Name, fun() ->
                 File = ?GOLDEN ++ Name ++ ".erl",
                 Actual = golden_source(Name),
                 case file:read_file(File) of
                     {ok, Actual} ->
                         ok;
                     _ ->
                         ok = file:write_file(File ++ ".new", Actual),
                         ?assert(false, "golden file differs; see " ++ File ++ ".new,"
                                        " or run make golden")
                 end
             end} || Name <- golden_names()].

%% make golden: rewrite the golden files from the current emitter.
write_golden() ->
    lists:foreach(fun(Name) ->
                      File = ?GOLDEN ++ Name ++ ".erl",
                      ok = filelib:ensure_dir(File),
                      ok = file:write_file(File, golden_source(Name)),
                      file:delete(File ++ ".new"),
                      io:format("~s~n", [File])
                  end, golden_names()).

%%
%% The MVP 1 examples run and print what their headers promise
%%

%% report Appendix B; plan 2, step 6
examples_test_() ->
    Expected = [{"hello", <<"hello, world\n">>},
                {"counter", <<"count is 8\n">>},
                {"upgrade", <<"before upgrade: 8\nafter upgrade: 10\n">>},
                {"pingpong", <<"ping 3\npong 3\nping 2\npong 2\nping 1\npong 1\n">>},
                {"stack", <<"top is 2\n">>},
                {"patterns", <<"minus one\nzero\nother\na 2\nnothing\n-3\n3\n">>},
                {"kvparser", <<"a 12\nbad key: =1\nexpected =: a\nbad number: a=x\n">>},
                {"remote", <<"no remote peer configured\n">>}],
    [{Base, fun() ->
                 {Ns, Bin} = example(Base),
                 ?assertEqual({ok, Out}, run(Ns, Bin))
             end} || {Base, Out} <- Expected].

%% report §11.1, plan 2.4: the interface travels in the BEAM chunk ErnI
%% with the source hash and the dependencies' interface hashes, and its
%% hash does not depend on the numbering of type variables
iface_chunk_test() ->
    {Ns, Bin} = example("stack"),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Bin),
    Build = #{source_hash => <<"s">>, deps => [{['Net', 'Http'], <<"h">>}]},
    {ok, 'ernest@stack', Beam} = ern_compiler:compile(Ns, Typed, Iface, Env, Build),
    {ok, #{iface := Read, source_hash := <<"s">>, deps := [{['Net', 'Http'], <<"h">>}]}} =
        ern_compiler:read_interface(Beam),
    ?assertEqual(['Stack'], Read#iface.namespace),
    ?assert(is_map_key(['Stack', 'Stack', push], Read#iface.values)),
    ?assertEqual(ern_compiler:iface_hash(Iface), ern_compiler:iface_hash(Read)),
    {ok, _, Iface2, _} = ern_typecheck:check_string(Ns, <<"fn f(x) = x\n", Bin/binary>>),
    ?assertEqual(ern_compiler:iface_hash(Iface), ern_compiler:iface_hash(Iface2)).

%% report §11.1: a chunk of another compiler version reads as an error,
%% so the module counts as stale; and the interface hash ignores the names
%% of type variables
stale_chunk_test() ->
    {Ns, Bin} = example("stack"),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Bin),
    {ok, _, Beam} = ern_compiler:compile(Ns, Typed, Iface, Env),
    {ok, {_, [{"ErnI", Chunk}]}} = beam_lib:chunks(Beam, ["ErnI"]),
    Old = term_to_binary((binary_to_term(Chunk))#{format => 0}),
    {ok, _, Stale} = compile:forms([{attribute, 1, module, x}],
                                   [binary, {extra_chunks, [{<<"ErnI">>, Old}]}]),
    ?assertMatch({error, _}, ern_compiler:read_interface(Stale)),
    {ok, _, IfaceA, _} = ern_typecheck:check_string(['M'], "export fn id(x : a) -> a = x\n"),
    {ok, _, IfaceT, _} = ern_typecheck:check_string(['M'], "export fn id(x : t) -> t = x\n"),
    ?assertEqual(ern_compiler:iface_hash(IfaceA), ern_compiler:iface_hash(IfaceT)).

%% report §11.1: --emit erl gives the module as Erlang source
erl_source_test() ->
    {Ns, Bin} = example("hello"),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Ns, Bin),
    Src = unicode:characters_to_binary(ern_compiler:erl_source(Ns, Typed, Env)),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ernest@hello).">>)).

%% plan 2.4: the module atom is ernest@ and the path with @ for /
module_atom_test() ->
    ?assertEqual('ernest@counter', ern_compiler:module_atom(['Counter'])),
    ?assertEqual('ernest@net@http', ern_compiler:module_atom(['Net', 'Http'])).

%%
%% Blocks, bindings, and local functions
%%

%% report §4.6, §5.4: a local fn closes over earlier bindings and calls
%% itself; used as a value it becomes a closure
local_fn_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    let base = 10;\n"
        "    fn add(x : Int) -> Int = base + x;\n"
        "    fn count(n : Int) -> Int = if n == 0 then 0 else 1 + count(n - 1);\n"
        "    let ys = List.map([1, 2], add);\n"
        "    Io.println(Int.toString(List.foldLeft(ys, 0, fn(a, b) = a + b)));\n"
        "    Io.println(Int.toString(count(3)))\n"
        "}\n"),
    ?assertEqual(<<"23\n3\n">>, Out).

%% report §4.6, §5.4: a local fn sees the bindings in force at its
%% declaration, whatever is rebound after it, and through the local fns it
%% references, theirs; it may be used before its declaration
local_fn_bindings_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    let x = 1;\n"
        "    fn f() -> Int = x;\n"
        "    let x = 2;\n"
        "    Io.println(Int.toString(f() * 10 + x));\n"
        "    let a = 1;\n"
        "    fn g() -> Int = h();\n"
        "    let a = 2;\n"
        "    fn h() -> Int = a;\n"
        "    Io.println(Int.toString(g()));\n"
        "    let b = 5;\n"
        "    let early = k();\n"
        "    fn k() -> Int = b + 1;\n"
        "    Io.println(Int.toString(early));\n"
        "    let k2 = 10;\n"
        "    fn add(n : Int) -> Int = n + k2;\n"
        "    let r = { fn twice(n : Int) -> Int = add(add(n)); twice(1) };\n"
        "    Io.println(Int.toString(r))\n"
        "}\n"),
    ?assertEqual(<<"12\n2\n6\n21\n">>, Out).

%% report §4.6: shadowing rebinds; each binding is its own variable
shadowing_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    let x = 1;\n"
        "    let x = x + 1;\n"
        "    let #(x, y) = #(x * 10, x);\n"
        "    Io.println(Int.toString(x + y))\n"
        "}\n"),
    ?assertEqual(<<"22\n">>, Out).

%% report §5.5, §7.1: a value error is an Either or Optional; `<-` on Either
%% returns the Left, on Optional the None
bind_arrow_test() ->
    {ok, Out} = run(
        "fn half(n : Int) -> Either(String, Int) =\n"
        "    if n % 2 == 0 then Right(n / 2) else Left(\"odd\")\n"
        "fn quarter(n : Int) -> Either(String, Int) = {\n"
        "    let h <- half(n);\n"
        "    let q <- half(h);\n"
        "    Right(q)\n"
        "}\n"
        "fn both(a : Optional(Int), b : Optional(Int)) -> Optional(Int) = {\n"
        "    let x <- a;\n"
        "    let y <- b;\n"
        "    Some(x + y)\n"
        "}\n"
        "fn show(e : Either(String, Int)) -> String = match e {\n"
        "    Right(n) -> Int.toString(n)\n"
        "  | Left(s) -> s\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(show(quarter(8)));\n"
        "    Io.println(show(quarter(6)));\n"
        "    Io.println(Int.toString(Optional.withDefault(both(Some(1), Some(2)), -1)));\n"
        "    Io.println(Int.toString(Optional.withDefault(both(Some(1), None), -1)))\n"
        "}\n"),
    ?assertEqual(<<"2\nodd\n3\n-1\n">>, Out).

%% report §4.6, §8.5: top-level lets are evaluated before main, in
%% dependency order whatever their textual order, a dependency through a
%% called function included
top_level_let_test() ->
    {ok, Out} = run(
        "let total = base * 2\n"
        "let base = count()\n"
        "fn count() -> Int = List.size(items)\n"
        "let items = [1, 2, 3]\n"
        "export fn main() -> Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"6\n">>, Out).

%%
%% Expressions
%%

%% report §5.9, §5.10: a guard that is not an Erlang guard falls through
%% to the next clause
match_general_guard_test() ->
    {ok, Out} = run(
        "fn small(n : Int) -> Bool = n < 3\n"
        "fn name(n : Int) -> String = match n {\n"
        "    k when small(k) -> \"small\"\n"
        "  | k when k % 2 == 0 -> \"even\"\n"
        "  | _ -> \"odd\"\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(name(1));\n"
        "    Io.println(name(4));\n"
        "    Io.println(name(5))\n"
        "}\n"),
    ?assertEqual(<<"small\neven\nodd\n">>, Out).

%% report §5.9, plan 2.2: a receive guard is an Erlang guard in MVP 1
receive_guard_test() ->
    {ok, Out} = run(
        "type Msg = N(Int)\n"
        "fn loop(acc : Int) -> Unit with Msg = receive {\n"
        "    N(k) when k > 0 -> loop(acc + k)\n"
        "  | N(_) -> Io.println(Int.toString(acc))\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    let p = spawn(Local, fn() = loop(0));\n"
        "    send(p, N(2));\n"
        "    send(p, N(3));\n"
        "    send(p, N(0));\n"
        "    receive { after 100 -> Unit }\n"
        "}\n"),
    ?assertEqual(<<"5\n">>, Out).

%% report §5.9, plan 2.2: a general receive guard is refused in MVP 1
receive_guard_general_test() ->
    Msg = compile_error(
        "type Msg = N(Int)\n"
        "fn big(k : Int) -> Bool = k > 100\n"
        "fn loop() -> Unit with Msg = receive {\n"
        "    N(k) when big(k) -> Unit\n"
        "  | N(_) -> loop()\n"
        "}\n"
        "export fn main() -> Unit with Msg = loop()\n"),
    ?assertMatch("in MVP 1 a receive guard" ++ _, Msg),
    ?assert(string:find(Msg, "§5.9") =/= nomatch).

%% report §3.1, §4.8, §9.6: Int arithmetic, comparison, and the Boolean
%% operators
operators_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Int.toString(-7 / 3));\n"
        "    Io.println(Int.toString(-7 % 3));\n"
        "    Io.println(Int.toString(2 + 3 * 4 - 1));\n"
        "    Io.println(Bool.toString(1 < 2 && 2 <= 2 && 3 > 2 && 3 >= 3));\n"
        "    Io.println(Bool.toString(1 == 2 || 1 != 2));\n"
        "    Io.println(Bool.toString(\"a\" < \"b\"));\n"
        "    Io.println(Int.toString(List.size(1 :: [2] <> [3])))\n"
        "}\n"),
    ?assertEqual(<<"-2\n-1\n13\ntrue\ntrue\ntrue\n3\n">>, Out).

%% report §3.1, §5.1, §9.6, Appendix E.9: Float arithmetic, negation, and
%% ordering; the Float functions of E.9
float_operators_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Float.toString(1.5 + 2.25 * 2.0 - 1.0 / 4.0));\n"
        "    Io.println(Float.toString(-(1.0e-9)));\n"
        "    Io.println(Bool.toString(1.5 < 2.0 && 2.0 <= 2.0 && 3.5 > 2.0 && 3.0 >= 3.0));\n"
        "    Io.println(Int.toString(Float.round(2.5) + Float.round(3.5) + Float.floor(-0.5)"
        " + Float.ceil(0.5)));\n"
        "    Io.println(Float.toString(Int.toFloat(3)))\n"
        "}\n"),
    ?assertEqual(<<"5.75\n-1.0e-9\ntrue\n6\n3.0\n">>, Out).

%% report §3.1, §7.4: a Float result outside the finite range faults with
%% its own cause, distinct from the Int zero divisor
float_fault_test() ->
    Zero = "fn zero() -> Float = Int.toFloat(List.size([]))\n",
    {R1, _} = run(Zero ++ "export fn main() -> Unit with Never = "
                  "Io.println(Float.toString(1.0 / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R1),
    {R2, _} = run(Zero ++ "export fn main() -> Unit with Never = "
                  "Io.println(Float.toString((zero() + 1.0e308) * 10.0))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R2),
    {R3, _} = run(Zero ++ "export fn main() -> Unit with Never = "
                  "Io.println(Float.toString(zero() / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R3).

%% report §4.8, §3.10: a user type's operator is its member, and its
%% ordering goes through its compare; in a receive guard the ordering is a
%% call, so MVP 1's guard rule refuses it
user_operators_test() ->
    Vec = "type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) -> Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(b, a)\n"
          "fn show(Vec(n)) -> String = Int.toString(n)\n",
    {ok, Out} = run(Vec ++
        "export fn main() -> Unit with Never = {\n"
        "    let a = Vec(1);\n"
        "    let b = Vec(2);\n"
        "    Io.println(show(a + b));\n"
        "    Io.println(Float.toString((a * b) + 0.5));\n"
        "    Io.println(Bool.toString(a < b));\n"
        "    Io.println(Bool.toString(a >= b && b <= a && a > b))\n"
        "}\n"),
    ?assertEqual(<<"3\n2.5\nfalse\ntrue\n">>, Out),
    Msg = compile_error(Vec ++
        "type Msg = Go(Vec)\n"
        "fn loop() -> Unit with Msg = receive {\n"
        "    Go(v) when v < Vec(0) -> Unit\n"
        "  | Go(_) -> Unit\n"
        "}\n"
        "export fn main() -> Unit with Msg = loop()\n"),
    ?assertMatch("in MVP 1 a receive guard" ++ _, Msg).

%% report §8.5: a top-level let evaluated through an operator's member
%% comes after the lets that member reads
let_order_through_operator_test() ->
    {ok, Out} = run(
        "type Vec = Vec(Int)\n"
        "let sum = Vec(1) + Vec(2)\n"
        "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec((a + b) * scale)\n"
        "let scale = 10\n"
        "fn show(Vec(n)) -> String = Int.toString(n)\n"
        "export fn main() -> Unit with Never = Io.println(show(sum))\n"),
    ?assertEqual(<<"30\n">>, Out).

%% report §7.4: a zero divisor faults main with its cause
division_fault_test() ->
    {Result, _} = run("export fn main() -> Unit with Never = {\n"
                      "    let z = List.size([]);\n"
                      "    Io.println(Int.toString(1 / z))\n"
                      "}\n"),
    ?assertEqual({fault, <<"division by zero">>}, Result).

%% report §7.4: todo compiles at any type and faults if reached
todo_test() ->
    {Result, _} = run("fn later() -> Int = todo(\"later\")\n"
                      "export fn main() -> Unit with Never = Io.println(Int.toString(later()))\n"),
    ?assertEqual({fault, <<"todo: later">>}, Result).

%% report §5.6, §8.4: named fields in canonical order, and update from a
%% base value
constructors_test() ->
    {ok, Out} = run(
        "type Point = Point(y : Int, x : Int)\n"
        "type Shape = Dot | At(Point)\n"
        "fn show(s : Shape) -> String = match s {\n"
        "    Dot -> \"dot\"\n"
        "  | At(Point(x = x, y = y)) -> Int.toString(x) <> \",\" <> Int.toString(y)\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    let p = Point(x = 1, y = 2);\n"
        "    Io.println(show(At(Point(..p, x = 5))));\n"
        "    Io.println(show(Dot));\n"
        "    let wrapped = List.map([p], At);\n"
        "    Io.println(Int.toString(List.size(wrapped)))\n"
        "}\n"),
    ?assertEqual(<<"5,2\ndot\n1\n">>, Out).

%% report §5.3, §5.8: lambdas capture, if is an expression
lambda_if_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    let k = 3;\n"
        "    let f = fn(x : Int) = if x > k then \"big\" else \"small\";\n"
        "    Io.println(f(5));\n"
        "    Io.println(f(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Out).

%% report §6.9: a monitored process that faults reports its spawn site
monitor_site_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down)\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let w = spawn(Local, fn() -> Unit with Never = { let _ = 1 / z; Unit });\n"
        "    monitor(w, Died);\n"
        "    receive {\n"
        "        Died(Down(function = f, reason = Fault(msg))) -> Io.println(f <> \" \" <> msg)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"M.main:4 division by zero\n">>, Out).

%% report §9.4, §9.6: spawn, the Int operators, and <> are functions and
%% may be passed as values
prelude_values_test() ->
    {ok, Out} = run(
        "fn apply2(f : (Int, Int) -> Int, a : Int, b : Int) -> Int = f(a, b)\n"
        "fn twice(f : (Int) -> Int, a : Int) -> Int = f(f(a))\n"
        "fn join(f : (String, String) -> String) -> String = f(\"a\", \"b\")\n"
        "fn start(s : (Where, () -> Unit with Never) -> Address(Never) with Never)\n"
        "        -> Address(Never) with Never = s(Local, fn() = Unit)\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Int.toString(apply2(Int.+, 2, 3)));\n"
        "    Io.println(Int.toString(apply2(Int./, 7, 2)));\n"
        "    Io.println(Int.toString(apply2(Int.%, 7, 2)));\n"
        "    Io.println(Int.toString(twice(Int.negate, 5)));\n"
        "    Io.println(join(String.<>));\n"
        "    let _ = start(spawn);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"5\n3\n1\n5\nab\n">>, Out).

%% report Appendix E, §5.2: a stdlib function and an Address function
%% passed as values
stdlib_values_test() ->
    {ok, Out} = run(
        "fn call(f : (Address(m), (Reply(Int)) -> m, Int) -> Optional(Int) with n,"
        " a : Address(m), mk : (Reply(Int)) -> m) -> Optional(Int) with n = f(a, mk, 100)\n"
        "type Msg = Ask(Reply(Int))\n"
        "fn answerer() -> Unit with Msg = receive { Ask(r) -> answer(r, 7) }\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Bool.toString(List.all(String.toList(\"123\"), Char.isDigit)));\n"
        "    let a = spawn(Local, fn() = answerer());\n"
        "    match call(Address.call, a, Ask) {\n"
        "        Some(n) -> Io.println(Int.toString(n))\n"
        "      | None -> Io.println(\"none\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"true\n7\n">>, Out).

%% report Appendix E.3, E.4, §3.10: Map and Set end to end, with
%% structural equality
maps_sets_test() ->
    {ok, Out} = run(
        "export fn main() -> Unit with Never = {\n"
        "    let m = Map.put(Map.put(Map.empty, \"a\", 1), \"b\", 2);\n"
        "    let s = Set.put(Set.fromList([1, 2]), 3);\n"
        "    Io.println(Int.toString(Optional.withDefault(Map.get(m, \"b\"), 0)));\n"
        "    Io.println(Int.toString(Map.foldLeft(m, 0, fn(acc, _, v) = acc + v)));\n"
        "    Io.println(Bool.toString(Set.contains(s, 3)));\n"
        "    Io.println(Int.toString(Set.size(Set.union(s, Set.fromList([3, 4])))));\n"
        "    Io.println(Bool.toString(Set.fromList([1, 2]) == Set.fromList([2, 1])))\n"
        "}\n"),
    ?assertEqual(<<"2\n3\ntrue\n4\ntrue\n">>, Out).

%% report Appendix E.13, §4.2, §3.8: a standard library foreign type in its
%% namespace, and every draw within its bounds
random_test() ->
    {ok, Out} = run(
        "fn draw(s : Random.Seed, n : Int) -> List(Int) = if n == 0 then [] else {\n"
        "    let #(x, s1) = Random.next(s, 5);\n"
        "    x :: draw(s1, n - 1)\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    let xs = draw(Random.seed(42), 50);\n"
        "    Io.println(Bool.toString(List.all(xs, fn(x) = x >= 0 && x <= 5)))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Out).

%% report Appendix E.15, E.14, §9.3: Clock.alarm delivers the wrapped Unit to
%% the caller, Clock.now is a time, Path is the prelude's
clock_path_test() ->
    {ok, Out} = run(
        "type Msg = Tick\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let t0 = Clock.now();\n"
        "    Clock.alarm(10, fn(_) = Tick);\n"
        "    receive { Tick -> Unit };\n"
        "    Io.println(Bool.toString(Clock.now() >= t0 + 10));\n"
        "    Io.println(Path.toString(Path.join(Path(\"a\"), Path(\"b\"))))\n"
        "}\n"),
    ?assertEqual(<<"true\na/b\n">>, Out).

%% README, "What MVP 1 accepts": the MVP 2.5 names type-check and the
%% compiler refuses them
refused_names_test() ->
    ?assertEqual("Tcp.listen is not in MVP 1",
                 compile_error("export fn main() -> Unit with Never =\n"
                               "    { let _ = Tcp.listen(1); Unit }\n")),
    ?assertEqual("Sys.fs is not in MVP 1",
                 compile_error("export fn main() -> Unit with Never = { let _ = Sys.fs; Unit }\n")),
    ?assertEqual("Sys.tcp is not in MVP 1",
                 compile_error("export fn main() -> Unit with Never =\n"
                               "    { let _ = Sys.tcp; Unit }\n")).

%% report §8.5, §8.2: the Sys.* references are bound before the top-level
%% lets are evaluated
sys_in_let_test() ->
    {ok, Out} = run("let out = Sys.stdout\n"
                    "export fn main() -> Unit with Never = send(out, \"via let\\n\")\n"),
    ?assertEqual(<<"via let\n">>, Out).

%% report §9, Appendix E; plan 2.1 table two: every prelude value the
%% checker knows is emitted as a call to a function that exists, with the
%% arity of its type, so no accepted name can reach the runtime as undef
prelude_targets_test() ->
    Missing = [Q || {Q, Text} <- ern_prelude:values(),
                    not ern_compiler:refused(Q),
                    {M, F, A} <- [prelude_target(Q, Text)],
                    code:ensure_loaded(M) =/= {module, M} orelse
                        not erlang:function_exported(M, F, A)],
    ?assertEqual([], Missing).

%% The emission of a prelude name, as ern_compiler makes it; inline
%% operators have no target.
prelude_target(Q, Text) ->
    {ok, Syntax} = ern_parser:parse_type(Text),
    Arity = case Syntax of
                #t_fn{params = Ps} -> length(Ps);
                _ -> 0
            end,
    case Q of
        [self] -> {ern_rt, self, 0};
        [send] -> {ern_rt, send, 2};
        [spawn] -> {ern_rt, spawn, 3};
        [via] -> {ern_rt, via, 2};
        [answer] -> {ern_rt, answer, 2};
        [monitor] -> {ern_rt, monitor, 2};
        [kill] -> {ern_rt, kill, 1};
        [remote] -> {ern_rt, remote, 1};
        [parallelRemote] -> {ern_rt, parallel_remote, 1};
        [todo] -> {ern_rt, todo, 1};
        ['Address', call] -> {ern_rt, call, 3};
        ['Address', callForever] -> {ern_rt, call_forever, 2};
        ['Sys', _] -> {ern_rt, sys, 1};
        [_, Op] when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/'; Op =:= '%'; Op =:= '<>';
                     Op =:= negate -> {erlang, is_atom, 1};
        [Ns, F] -> {ern_compiler:module_atom([Ns]), F, Arity}
    end.

%% report §6.5, §6.9, §7.3, §9.5: kill is a Down with Killed, a fault a
%% Down with its cause, via adapts a message, parallelRemote answers
%% Left(NoRemotePeer) per function, all through compiled code
process_functions_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down) | Tick\n"
        "fn idle() -> Unit with Never = receive { after 10000 -> Unit }\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let w = spawn(Local, fn() = idle());\n"
        "    monitor(w, Died);\n"
        "    kill(w);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, function = _)) -> Io.println(\"killed\")\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    let z = List.size([]);\n"
        "    let f = spawn(Local, fn() -> Unit with Never = { let _ = 1 / z; Unit });\n"
        "    monitor(f, Died);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(m), function = _)) -> Io.println(m)\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    send(via(fn(u : Unit) = Tick, self()), Unit);\n"
        "    receive { Tick -> Io.println(\"tick\") | _ -> Io.println(\"other\") };\n"
        "    let rs = parallelRemote([fn() = 1, fn() = 2]);\n"
        "    Io.println(Int.toString(List.size(List.filter(rs, Either.isLeft))))\n"
        "}\n"),
    ?assertEqual(<<"killed\ndivision by zero\ntick\n2\n">>, Out).

%% report §8.2, §9.7: Sys.stdout is a value
sys_stdout_test() ->
    {ok, Out} = run("export fn main() -> Unit with Never = send(Sys.stdout, \"hi\\n\")\n"),
    ?assertEqual(<<"hi\n">>, Out).

