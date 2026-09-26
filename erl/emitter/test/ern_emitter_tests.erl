-module(ern_emitter_tests).

-export([write_golden/0, pair/0, opt/1, funs/0, remember/1, junk/1, good/1, tell/1,
         junk_server/0]).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diag.hrl").
-include_lib("typer/include/ern_types.hrl").

%%
%% Helpers
%%

%% Type-check, compile, load, initialize, and run a program's main under
%% the launcher, with an empty standard input, collecting what reaches
%% stdout.
run(Text) ->
    run(['M'], Text).

run(Ns, Text) ->
    run(Ns, Text, #{}).

%% The same with keys that can come, as at a terminal, of which none does.
run_at_terminal(Text) ->
    run(['M'], Text, #{keys => fun() -> receive after infinity -> eof end end}).

run(Ns, Text, Opts) ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Text),
    {ok, Mod, Bin} = ern_emitter:compile(Ns, Typed, Iface, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    Result = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                             Opts#{init => fun() -> init(Mod) end,
                                   stdout => fun(B) -> Me ! {out, B} end,
                                   stdin => fun() -> eof end}),
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
    normalize(ern_emitter:forms(Ns, Typed, Env)).

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
%% Golden files: the Erlang source of every MVP 1 example, as --emit-erl
%% writes it, kept under test/golden and regenerated with make golden
%%

-define(GOLDEN, "../../../test/golden/").

golden_names() ->
    ["hello", "counter", "upgrade", "pingpong", "stack", "patterns", "kvparser",
     "remote", "modules/net/http", "modules/main"].

%% report §4.6, §8.5, §11.1: a `let` is a value whatever its type, so one
%% that holds a function is reached through its getter and called by
%% applying what the getter answers, in its own module and in another; a
%% `fn` of the same type is called directly. The interface says which of
%% the two a name is.
let_of_function_type_test() ->
    {_, Out} = run("let g = fn() = 1\n"
                   "let h = fn(x : Int) = x + 1\n"
                   "fn twice(f : (Int) -> Int, n : Int) -> Int = f(f(n))\n"
                   "export fn main() -> Unit with m = {\n"
                   "    Io.println(Int.toString(g()));\n"
                   "    Io.println(Int.toString(h(2)));\n"
                   "    Io.println(Int.toString(twice(h, 0)))\n"
                   "}\n"),
    ?assertEqual(<<"1\n3\n2\n">>, Out).

%% report §4.6, §11.1: the same across modules, where the interface is all
%% the emitter has to tell a `let` from a `fn`
let_of_function_type_remote_test() ->
    {ok, MTyped, MIface, MEnv} =
        ern_typecheck:check_string(['M'], "export let g = fn() = 1\n"
                                          "export let h = fn(x : Int) = x + 1\n"
                                          "export fn f(x : Int) -> Int = x * 2\n"),
    {ok, MMod, MBin} = ern_emitter:compile(['M'], MTyped, MIface, MEnv),
    {module, MMod} = code:load_binary(MMod, "test", MBin),
    %% the interface the dependent is checked against is the compiled one
    {ok, #{iface := Iface}} = ern_iface:read(MBin),
    ?assertEqual([['M', g], ['M', h]], lists:sort(Iface#iface.lets)),
    {ok, Decls} = ern_parser:parse_string(
                    "export fn main() -> Unit with m = {\n"
                    "    Io.println(Int.toString(M.g()));\n"
                    "    Io.println(Int.toString(M.h(2)));\n"
                    "    Io.println(Int.toString(twice(M.h, 0)));\n"
                    "    Io.println(Int.toString(M.f(3)))\n"
                    "}\n"
                    "fn twice(f : (Int) -> Int, n : Int) -> Int = f(f(n))\n"),
    {ok, Typed, Iface2, Env} = ern_typecheck:check(['Main'], Decls, [Iface]),
    {ok, Mod, Bin} = ern_emitter:compile(['Main'], Typed, Iface2, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                    #{init => fun() -> init(MMod), init(Mod) end,
                      stdout => fun(B) -> Me ! {out, B} end}),
    ?assertEqual(<<"1\n3\n2\n6\n">>, collect([])).

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
    unicode:characters_to_binary(ern_emitter:erl_source(Ns, Typed, Env)).

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
                {"patterns", <<"minus one\nzero\nother\na 2\nnothing\n-3\n3\n4\n">>},
                {"kvparser", <<"a 12\nbad key: =1\nexpected =: a\nbad number: a=x\n">>},
                {"remote", <<"no remote peer configured\n">>}],
    [{Base, fun() ->
                 {Ns, Bin} = example(Base),
                 ?assertEqual({ok, Out}, run(Ns, Bin))
             end} || {Base, Out} <- Expected].

%% report §11.1: the documentation travels in the BEAM chunk Docs, EEP 48's,
%% and a type's parts are structured in its entry rather than rendered
docs_chunk_test() ->
    Ns = ['Shapes'],
    Src = <<"/// The module.\n\n"
            "/// A shape.\n"
            "export type Shape = Dot\n"
            "    /// somewhere\n"
            "    | At(/// across\n"
            "         x : Int, y : Int)\n"
            "export fn area(shape : Shape) -> Int = 0\n">>,
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Src),
    Build = #{source_hash => <<>>, deps => [], source => <<"shapes.ern">>},
    {ok, 'ern@shapes', Beam} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
    {ok, {docs_v1, _, ernest, <<"text/markdown">>, ModDoc, Meta, Entries}} =
        ern_docs:read(Beam),
    ?assertEqual(#{<<"en">> => <<"The module.">>}, ModDoc),
    ?assertEqual(<<"shapes.ern">>, maps:get(source, Meta)),
    [{{type, 'Shape', 0}, _, Signature, Doc, TypeMeta},
     {{function, area, 1}, _, _, _, FnMeta}] = Entries,
    ?assertEqual([<<"type Shape = Dot | At(x : Int, y : Int)">>], Signature),
    ?assertEqual(#{<<"en">> => <<"A shape.">>}, Doc),
    ?assertEqual([#{kind => constructor, name => 'Dot', doc => none, fields => []},
                  #{kind => constructor, name => 'At', doc => <<"somewhere">>,
                    fields => [#{name => x, type => <<"Int">>, doc => <<"across">>},
                               #{name => y, type => <<"Int">>, doc => none}]}],
                 maps:get(items, TypeMeta)),
    ?assertEqual([shape], maps:get(params, FnMeta)),
    %% the interface chunk keeps its own shape, the source name being the
    %% documentation's
    {ok, Read} = ern_iface:read(Beam),
    ?assertEqual(false, is_map_key(source, Read)).

%% report §11.1, plan 2.4: the interface travels in the BEAM chunk ErnI
%% with the source hash and the dependencies' interface hashes, and its
%% hash does not depend on the numbering of type variables
iface_chunk_test() ->
    {Ns, Bin} = example("stack"),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Bin),
    Build = #{source_hash => <<"s">>, deps => [{['Net', 'Http'], <<"h">>}]},
    {ok, 'ern@stack', Beam} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
    {ok, #{iface := Read, source_hash := <<"s">>, deps := [{['Net', 'Http'], <<"h">>}]}} =
        ern_iface:read(Beam),
    ?assertEqual(['Stack'], Read#iface.namespace),
    ?assert(is_map_key(['Stack', 'Stack', push], Read#iface.values)),
    ?assertEqual(ern_iface:hash(Iface), ern_iface:hash(Read)),
    {ok, _, Iface2, _} = ern_typecheck:check_string(Ns, <<"fn f(x) = x\n", Bin/binary>>),
    ?assertEqual(ern_iface:hash(Iface), ern_iface:hash(Iface2)).

%% report §11.1: a chunk of another compiler version reads as an error,
%% so the module counts as stale; and the interface hash ignores the names
%% of type variables
stale_chunk_test() ->
    {Ns, Bin} = example("stack"),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Bin),
    {ok, _, Beam} = ern_emitter:compile(Ns, Typed, Iface, Env),
    {ok, {_, [{"ErnI", Chunk}]}} = beam_lib:chunks(Beam, ["ErnI"]),
    Old = term_to_binary((binary_to_term(Chunk))#{format => 0}),
    {ok, _, Stale} = compile:forms([{attribute, 1, module, x}],
                                   [binary, {extra_chunks, [{<<"ErnI">>, Old}]}]),
    ?assertMatch({error, _}, ern_iface:read(Stale)),
    {ok, _, IfaceA, _} = ern_typecheck:check_string(['M'], "export fn id(x : a) -> a = x\n"),
    {ok, _, IfaceT, _} = ern_typecheck:check_string(['M'], "export fn id(x : t) -> t = x\n"),
    ?assertEqual(ern_iface:hash(IfaceA), ern_iface:hash(IfaceT)).

%% report §11.1: --emit-erl gives the module as Erlang source
erl_source_test() ->
    {Ns, Bin} = example("hello"),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Ns, Bin),
    Src = unicode:characters_to_binary(ern_emitter:erl_source(Ns, Typed, Env)),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ern@hello).">>)).

%% plan 2.4: the module atom is ern@ and the path with @ for /
module_atom_test() ->
    ?assertEqual('ern@counter', ern_emitter:module_atom(['Counter'])),
    ?assertEqual('ern@net@http', ern_emitter:module_atom(['Net', 'Http'])).

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

%% report §5.9: a guard that faults faults the process; it never becomes a
%% silent `false` as an Erlang guard would, since only comparisons that
%% cannot fault are emitted as Erlang guards and every other guard runs as
%% an expression that falls through on `false` alone
match_guard_faults_test() ->
    {R, _} = run(
        "fn name(n : Int) -> String = match n {\n"
        "    k when k == 7 -> \"seven\"\n"
        "  | k when 10 / k == 5 -> \"half\"\n"
        "  | _ -> \"other\"\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(name(7));\n"
        "    Io.println(name(2));\n"
        "    Io.println(name(0))\n"
        "}\n"),
    ?assertEqual({fault, <<"division by zero">>}, R).

%% report §5.9: a clause with alternatives runs one body for whichever
%% alternative matched, with that alternative's variables; a guard applies to
%% every alternative, as an Erlang guard or as an expression; a faulting guard
%% still faults
or_pattern_test() ->
    Shape = "type Shape = Circle(Int) | Square(Int) | Dot\n",
    Kind = "fn kind(s : Shape) -> String = match s {\n"
           "    Circle(n) or Square(n) when 10 / n > 0 -> \"sized\"\n"
           "  | _ -> \"dot\"\n"
           "}\n",
    {ok, Out} = run(Shape ++ Kind ++
        "fn area(s : Shape) -> Int = match s {\n"
        "    Circle(n) or Square(n) when n > 1 -> n * 10\n"
        "  | Circle(n) or Square(n) -> n\n"
        "  | Dot -> 0\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Int.toString(area(Circle(1))));\n"
        "    Io.println(Int.toString(area(Square(2))));\n"
        "    Io.println(Int.toString(area(Dot)));\n"
        "    Io.println(kind(Square(5)));\n"
        "    Io.println(kind(Dot))\n"
        "}\n"),
    ?assertEqual(<<"1\n20\n0\nsized\ndot\n">>, Out),
    {R, _} = run(Shape ++ Kind ++
        "export fn main() -> Unit with Never = Io.println(kind(Circle(0)))\n"),
    ?assertEqual({fault, <<"division by zero">>}, R).

%% report Appendix E.1: Io.debug prints a value as Ernest writes it, by the
%% argument's type at the call, and returns it; with a type variable there,
%% by the runtime's representation
io_debug_test() ->
    {ok, Out} = run(
        "type Shape = Circle(Int) | Dot\n"
        "type Snap = Snap(seen : Int, dir : String)\n"
        "type State = Ready | Busy\n"
        "fn generic(x) = Io.debug(x)\n"
        "export fn main() -> Unit with Never = {\n"
        "    let n = Io.debug(4) + 1;\n"
        "    let _ = Io.debug(n);\n"
        "    let _ = Io.debug([Circle(-3), Dot]);\n"
        "    let _ = Io.debug(#(1.5, \"a\\nb\", true, Unit));\n"
        "    let _ = Io.debug(Snap(dir = \"x\", seen = 2));\n"
        "    let _ = Io.debug(Map.put(Map.empty, \"k\", [1]));\n"
        "    let _ = Io.debug(Set.fromList([2, 1]));\n"
        "    let _ = Io.debug(fn(x) = x);\n"
        "    let _ = Io.debug(#(true, false));\n"
        "    let _ = Io.debug(\"é中\");\n"
        "    let _ = Io.debug(#('a', '\\'', Some('\\n')));\n"
        "    let _ = Io.debug(#(Ready, 1));\n"
        "    let _ = Io.debug(<<104, 105>>);\n"
        "    let _ = List.map(['x'], Io.debug);\n"
        "    let _ = generic('a');\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"4\n5\n[Circle(-3), Dot]\n#(1.5, \"a\\nb\", true, Unit)\n"
                   "Snap(dir = \"x\", seen = 2)\n"
                   "Map.fromList([#(\"k\", [1])])\nSet.fromList([1, 2])\n<function>\n"
                   "#(true, false)\n\"é中\"\n#('a', '\\'', Some('\\n'))\n#(Ready, 1)\n"
                   "<<104, 105>>\n'x'\n97\n"/utf8>>, Out).

%% report Appendix E.1: Io.show writes a value by its type at the call, as
%% a function value too, and pure, and by the runtime's representation
%% inside a generic function
show_test() ->
    {ok, Out} = run(
        "type Snap = Snap(seen : Int, dir : String)\n"
        "fn generic(x : a) -> String = Io.show(x)\n"
        "fn pure(c : Char) -> String = Io.show(Some(c))\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Io.show(Snap(dir = \"x\", seen = 2)));\n"
        "    Io.println(pure('a'));\n"
        "    Io.println(String.join(List.map([<<1>>, <<2, 3>>], Io.show), \" \"));\n"
        "    Io.println(generic('a'))\n"
        "}\n"),
    ?assertEqual(<<"Snap(dir = \"x\", seen = 2)\nSome('a')\n<<1>> <<2, 3>>\n97\n">>, Out).

%% report Appendix E.1: Io.debug writes a String as a literal, with `"`,
%% `\\`, a line feed and a tab escaped by name, another control character
%% by its code point, and every other character as itself. A regression
%% test, written after the code; it does not cover a character outside
%% the Basic Multilingual Plane
io_debug_escapes_test() ->
    {ok, Out} = run("export fn main() -> Unit with Never = {\n"
                    "    let _ = Io.debug(\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\");\n"
                    "    Unit\n"
                    "}\n"),
    ?assertEqual(<<"\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\"\n"/utf8>>, Out).

%% report §8.2: keys and lines are the same terminal, so a program that
%% does both ends with a fault naming the side that holds it
terminal_is_lines_or_keys_test() ->
    {R1, _} = run_at_terminal("type Msg = Pressed(Terminal.Event)\n"
                  "export fn main() -> Unit with Msg = {\n"
                  "    let _ = Io.readLine();\n"
                  "    let _ = Terminal.subscribe(Pressed);\n"
                  "    receive { Pressed(_) -> Unit }\n"
                  "}\n"),
    ?assertEqual({fault, <<"the terminal is already read as lines">>}, R1).

%% report §8.6, §7.4: a program whose every process waits forever ends
%% with the entry process's fault, `deadlock`; a timed receive is a source
%% and ends by itself
deadlock_test() ->
    {R1, _} = run("type Msg = Ping\n"
                  "export fn main() -> Unit with Msg = receive { Ping -> Unit }\n"),
    ?assertEqual({fault, <<"deadlock">>}, R1),
    {R2, Out} = run("type Msg = Ping\n"
                    "export fn main() -> Unit with Msg = receive {\n"
                    "    Ping -> Unit\n"
                    "  | after 100 -> Io.println(\"timeout\")\n"
                    "}\n"),
    ?assertEqual({ok, <<"timeout\n">>}, {R2, Out}).

%% report §6.3, §6.6, Appendix E.0 rule 8: a time below 0 is 0, in `after`,
%% in `Address.call`, and in `Clock.alarm`. A regression test: the first two
%% faulted with the host's `timeout_value`, and the alarm crashed the clock,
%% which left the program waiting for ever
negative_time_test() ->
    {ok, Out} = run("type M = M | Get(reply : Reply(Int))
"
                    "export fn main() -> Unit with M = {\n"
                    "    receive { Get(reply = r) -> answer(r, 1) | after 0 - 5 ->"
                    " Io.println(\"after\") };\n"
                    "    let quiet = spawn(Local, fn() -> Unit with M = receive { M -> Unit });\n"
                    "    let asked = Address.call(quiet, fn(r) = Get(reply = r), 0 - 1);\n"
                    "    Io.println(match asked { Some(_) -> \"some\" | None -> \"none\" });\n"
                    "    Clock.alarm(0 - 10, fn(_) = M);\n"
                    "    receive { M -> Io.println(\"alarm\") | Get(reply = r) -> answer(r, 0) }\n"
                    "}\n"),
    ?assertEqual(<<"after\nnone\nalarm\n">>, Out).

%% report §6.3, §6.6, Appendix E.0 rule 8: a time has no upper bound, so a
%% time beyond the host's longest wait, 2^32 - 1 ms, waits as any other: a
%% message that comes after 50 ms is received, a call is answered, and a
%% file is read. A regression test: each faulted with the host's
%% timeout_value. It does not cover a wait that outlasts one slice of
%% 2^32 - 1 ms, nor an alarm, which ern_rt_tests covers
long_time_test() ->
    {ok, Out} = run(
        "type Msg = Ping | Get(reply : Reply(Int))\n"
        "fn later(to : Address(Msg)) -> Unit with Never = {\n"
        "    receive { after 50 -> Unit };\n"
        "    send(to, Ping)\n"
        "}\n"
        "fn server() -> Unit with Msg = receive {\n"
        "    Get(reply = r) -> { receive { after 50 -> Unit }; answer(r, 7) }\n"
        "  | Ping -> Unit\n"
        "}\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let me = self();\n"
        "    let _ = spawn(Local, fn() = later(me));\n"
        "    receive {\n"
        "        Ping -> Io.println(\"ping\")\n"
        "      | after 5000000000 -> Io.println(\"after\")\n"
        "    };\n"
        "    let a = spawn(Local, server);\n"
        "    let _ = Io.debug(Address.call(a, fn(r) = Get(reply = r), 5000000000));\n"
        "    match Fs.read(Path(\"../../../VERSION\"), 5000000000) {\n"
        "        Right(_) -> Io.println(\"read\")\n"
        "      | Left(_) -> Io.println(\"not read\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"ping\nSome(7)\nread\n">>, Out).

%% report §8.6: a process blocked in Address.callForever waits without a
%% limit, as an untimed receive does, so a call to a server that waits in
%% an untimed receive for something else is a deadlock. A regression test,
%% written after the code; a callForever to a process that has ended is
%% call_ends_with_callee_test_'s
call_forever_deadlock_test() ->
    {R, _} = run("type Req = Get(reply : Reply(Int)) | Other\n"
                 "fn server() -> Unit with Req = receive { Other -> Unit }\n"
                 "export fn main() -> Unit with m = {\n"
                 "    let a = spawn(Local, server);\n"
                 "    let _ = Io.debug(Address.callForever(a, fn(r) = Get(reply = r)));\n"
                 "    Unit\n"
                 "}\n"),
    ?assertEqual({fault, <<"deadlock">>}, R).

%% report §6.9, §9.5: a process whose function is `restarting`'s runs it
%% again after a fault, keeping its address and its mailbox, the message
%% being handled lost and the state its function starts from. The call is
%% made once the crash has been handled, since a call pending at a restart
%% ends with it (call_ends_with_callee_test_)
restart_keeps_address_test() ->
    {ok, Out} = run(
        "type Msg = Bump | Crash | Get(reply : Reply(Int))\n"
        "fn loop(n : Int) -> Unit with Msg = receive {\n"
        "    Bump -> loop(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Get(reply = r) -> { answer(r, n); loop(n) }\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(Local, restarting(limit, fn() -> Unit with Msg = loop(0)));\n"
        "    send(s, Bump);\n"
        "    send(s, Crash);\n"
        "    receive { after 100 -> Unit };\n"
        "    send(s, Bump);\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"1\n">>, Out).

%% report §6.9: past the limit the next fault ends the process with its
%% cause, which is its one death a monitor is told of; a restart is none,
%% and a limit of no restarts ends it at the first fault
restart_limit_test() ->
    Program = fun(Restarts) ->
        "type Msg = Crash\n"
        "type MainMsg = Died(Down)\n"
        "fn loop(n : Int) -> Unit with Msg = receive { Crash -> fault(Int.toString(n)) }\n"
        "fn count() -> Unit with Msg = loop(1)\n"
        "export fn main() -> Unit with MainMsg = {\n"
        "    let limit = RestartLimit(restarts = " ++ Restarts ++ ", within = 60000);\n"
        "    let s = spawnMonitored(Local, restarting(limit, count), Died);\n"
        "    send(s, Crash);\n"
        "    send(s, Crash);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(c), site = _)) -> Io.println(\"ended \" <> c)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    };\n"
        "    receive { Died(_) -> Io.println(\"twice\") | after 100 -> Unit }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"ended 1\n">>}, run(Program("1"))),
    ?assertEqual({ok, <<"ended 1\n">>}, run(Program("0"))),
    ?assertEqual({ok, <<"ended 1\n">>}, run(Program("-2"))).

%% report §6.9: returning and a kill end a restarting process as they end
%% any; only a fault restarts
restart_only_on_fault_test() ->
    {ok, Out} = run(
        "type Msg = Stop\n"
        "type MainMsg = Died(Down)\n"
        "fn waits() -> Unit with Msg = receive { Stop -> Unit }\n"
        "export fn main() -> Unit with MainMsg = {\n"
        "    let limit = RestartLimit(restarts = 5, within = 60000);\n"
        "    let a = spawnMonitored(Local, restarting(limit, waits), Died);\n"
        "    send(a, Stop);\n"
        "    receive { Died(Down(reason = r, site = _)) -> { let _ = Io.debug(r); Unit } };\n"
        "    let b = spawnMonitored(Local, restarting(limit, waits), Died);\n"
        "    kill(b);\n"
        "    receive { Died(Down(reason = r, site = _)) -> { let _ = Io.debug(r); Unit } };\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"Returned\nKilled\n">>, Out).

%% report §6.6, §7.4: a call ends at once when its callee faults, is
%% killed, returns, or had ended, before it answers: Address.call answers
%% None, and callForever faults the caller with the callee's cause or says
%% how it ended; a restart ends the calls waiting on the process the same
%% way. A regression test of the rule's first build: a callForever to a
%% dead callee waited for a deadlock, and a call for its time
call_ends_with_callee_test_() ->
    {timeout, 30, fun call_ends_with_callee/0}.

call_ends_with_callee() ->
    Types = "type Msg = Ask(reply : Reply(Int)) | Stop\n"
            "type MainMsg = Died(Down)\n",
    Faulty = "fn faulty() -> Unit with Msg = receive {\n"
             "    Ask(reply = r) -> { fault(\"bad request\"); answer(r, 1) }\n"
             "  | Stop -> Unit\n"
             "}\n",
    Ask = "fn(r) = Ask(reply = r)",
    Forever = fun(Setup) ->
        Types ++ Faulty ++
        "fn waits() -> Unit with Msg = receive { Stop -> Unit }\n"
        "fn quiet() -> Unit with Msg = receive { Ask(reply = r) -> "
        "receive { after 60000 -> answer(r, 1) } | Stop -> Unit }\n"
        "export fn main() -> Unit with MainMsg = {\n" ++ Setup ++
        "    Io.println(Int.toString(Address.callForever(s, " ++ Ask ++ ")))\n"
        "}\n"
    end,
    ?assertMatch({{fault, <<"bad request">>}, _},
                 run(Forever("    let s = spawn(Local, faulty);\n"))),
    ?assertMatch({{fault, <<"callee was killed">>}, _},
                 run(Forever("    let s = spawn(Local, quiet);\n"
                             "    let _ = spawn(Local, fn() -> Unit with Never =\n"
                             "        receive { after 50 -> kill(s) });\n"))),
    ?assertMatch({{fault, <<"callee returned without answering">>}, _},
                 run(Forever("    let s = spawn(Local, waits);\n"
                             "    let _ = spawn(Local, fn() -> Unit with Never =\n"
                             "        receive { after 50 -> send(s, Stop) });\n"))),
    ?assertMatch({{fault, <<"callee had ended">>}, _},
                 run(Forever("    let s = spawnMonitored(Local, fn() -> Unit with Msg = Unit,\n"
                             "        Died);\n"
                             "    receive { Died(_) -> Unit };\n"))),
    ?assertMatch({{fault, <<"bad request">>}, _},
                 run(Forever("    let limit = RestartLimit(restarts = 5, within = 60000);\n"
                             "    let s = spawn(Local, restarting(limit, faulty));\n"))),
    {ok, Out} = run(Types ++ Faulty ++
                    "export fn main() -> Unit with MainMsg = {\n"
                    "    let limit = RestartLimit(restarts = 5, within = 60000);\n"
                    "    let s = spawn(Local, restarting(limit, faulty));\n"
                    "    let t = spawn(Local, faulty);\n"
                    "    let _ = Io.debug(Address.call(s, " ++ Ask ++ ", 60000));\n"
                    "    let _ = Io.debug(Address.call(t, " ++ Ask ++ ", 60000));\n"
                    "    Unit\n"
                    "}\n"),
    ?assertEqual(<<"None\nNone\n">>, Out).

%% report §4.6, §6.5, §8.5: a service is a top-level binding whose
%% initializer spawns the process, before main, in the entry process;
%% functions reach it by its name, and a restarting one keeps its address
service_binding_test() ->
    {ok, Out} = run(
        "export type LogMsg = Log(String) | Crash | Count(reply : Reply(Int))\n"
        "fn logger(n : Int) -> Unit with LogMsg = receive {\n"
        "    Log(_) -> logger(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Count(reply = r) -> { answer(r, n); logger(n) }\n"
        "}\n"
        "export let log : Address(LogMsg) = spawn(Local,\n"
        "    restarting(RestartLimit(restarts = 3, within = 60000),\n"
        "        fn() -> Unit with LogMsg = logger(0)))\n"
        "let started = Io.println(\"started\")\n"
        "fn note(s : String) -> Unit with m = send(log, Log(s))\n"
        "export fn main() -> Unit with Never = {\n"
        "    note(\"a\");\n"
        "    send(log, Crash);\n"
        "    receive { after 100 -> Unit };\n"
        "    note(\"b\");\n"
        "    Io.println(Int.toString(Address.callForever(log, fn(r) = Count(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"started\n1\n">>, Out).

%% report §6.9, §8.5: a process a top-level initializer spawns names that
%% binding's declaration as its spawn site
service_site_test() ->
    {ok, Out} = run(
        "type MainMsg = Died(Down)\n"
        "export let quick : Address(Int) =\n"
        "    spawn(Local, fn() -> Unit with Int = receive { _ -> fault(\"x\") })\n"
        "export fn main() -> Unit with MainMsg = {\n"
        "    monitor(quick, Died);\n"
        "    send(quick, 1);\n"
        "    receive { Died(Down(reason = _, site = s)) -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"M.quick:3\n">>, Out).

%% Appendix E.15, §5.6: an alarm carries the time it fired, so a
%% single-positional constructor passes as its wrap, as `Died` does to
%% `monitor`
alarm_time_test() ->
    {ok, Out} = run("type Msg = Tick(Int)\n"
                    "export fn main() -> Unit with Msg = {\n"
                    "    let before = Clock.now();\n"
                    "    Clock.alarm(5, Tick);\n"
                    "    receive { Tick(at) -> Io.println(Bool.toString(at >= before)) }\n"
                    "}\n"),
    ?assertEqual(<<"true\n">>, Out).

%% report §5.9, §6.3: alternatives in a receive clause select either message
receive_or_pattern_test() ->
    {ok, Out} = run(
        "type Msg = Inc(Int) | Dec(Int) | Stop\n"
        "fn loop(n : Int) -> Int with Msg = receive {\n"
        "    Inc(k) or Dec(k) -> loop(n + k)\n"
        "  | Stop -> n\n"
        "}\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let me = self();\n"
        "    send(me, Inc(2));\n"
        "    send(me, Dec(3));\n"
        "    send(me, Stop);\n"
        "    Io.println(Int.toString(loop(0)))\n"
        "}\n"),
    ?assertEqual(<<"5\n">>, Out).

%% report §6.3: a receive guard is a guard expression, emitted as an Erlang
%% guard, tested while the message stays in the mailbox
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

%% report §6.3: a compound guard expression; a message the guard rejects
%% stays in the mailbox
receive_guard_compound_test() ->
    {ok, Out} = run(
        "type Msg = N(Int) | Stop\n"
        "fn loop(limit : Int) -> Unit with Msg = receive {\n"
        "    N(k) when k > limit && k != 7 -> { Io.println(Int.toString(k)); loop(limit) }\n"
        "  | Stop -> Unit\n"
        "}\n"
        "export fn main() -> Unit with Msg = {\n"
        "    send(self(), N(1));\n"
        "    send(self(), N(9));\n"
        "    send(self(), N(7));\n"
        "    send(self(), Stop);\n"
        "    loop(5)\n"
        "}\n"),
    ?assertEqual(<<"9\n">>, Out).

%% report §6.3: `!` before a guard expression and a negative literal in a
%% receive guard, emitted as an Erlang guard; the messages the guard
%% rejects stay in the mailbox
receive_guard_not_test() ->
    {ok, Out} = run(
        "type Msg = N(Int) | Stop\n"
        "fn take(flag : Bool) -> Int with Msg = receive {\n"
        "    N(k) when !flag && !(k > 5) && k > -3 -> k\n"
        "  | Stop -> 100\n"
        "}\n"
        "fn negative() -> Int with Msg = receive { N(k) when k < -1 -> k }\n"
        "export fn main() -> Unit with Msg = {\n"
        "    send(self(), N(9));\n"
        "    send(self(), N(-4));\n"
        "    send(self(), N(2));\n"
        "    send(self(), Stop);\n"
        "    Io.println(Int.toString(take(false)));\n"
        "    Io.println(Int.toString(take(true)));\n"
        "    Io.println(Int.toString(negative()))\n"
        "}\n"),
    ?assertEqual(<<"2\n100\n-4\n">>, Out).

%% report §5.9, §4.6: a match guard may read a top-level `let`, which is
%% read through its getter, so the guard is not compiled as an Erlang guard
match_guard_top_level_let_test() ->
    {ok, Out} = run(
        "let limit = 5\n"
        "fn size(n : Int) -> String = match n { m when m > limit -> \"big\" | _ -> \"small\" }\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(size(9));\n"
        "    Io.println(size(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Out).

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
    ?assertEqual({fault, <<"float arithmetic error">>}, R3),
    %% an Int zero divisor inside a Float operand keeps its own cause
    {R4, _} = run("fn n() -> Int = List.size([])\n"
                  "export fn main() -> Unit with Never = "
                  "Io.println(Float.toString(Int.toFloat(1 / n()) + 1.0))\n"),
    ?assertEqual({fault, <<"division by zero">>}, R4),
    %% Float.+ taken as a value faults the same way
    {R5, _} = run("export fn main() -> Unit with Never = "
                  "Io.println(Float.toString(List.foldLeft([1.0e308, 1.0e308], 0.0, Float.+)))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R5).

%% report §3.1: there is no negative zero; an operation, a negation, a
%% float segment, parsed text, and a foreign value give 0.0
no_negative_zero_test() ->
    {ok, Out} = run(
        "foreign fn parse(s : String) -> Float = \"erlang:binary_to_float/1\"\n"
        "fn tiny() -> Float = 1.0e-300\n"
        "export fn main() -> Unit with Never = {\n"
        "    let z = 0.0;\n"
        "    let _ = Io.debug(#(z * -1.0, -z, z / -2.0, -tiny() * tiny()));\n"
        "    let _ = Io.debug(z * -1.0 == 0.0);\n"
        "    let _ = Io.debug(Map.size(Map.fromList([#(z, 1), #(-z, 2)])));\n"
        "    let b = <<128, 0, 0, 0, 0, 0, 0, 0>>;\n"
        "    let _ = match b { <<x:size(64)-float>> -> Io.debug(x) | _ -> 1.0 };\n"
        "    let _ = match b { <<0.0:size(64)-float>> -> Io.debug(\"zero\") | _ -> \"other\" };\n"
        "    let _ = Io.debug(String.toFloat(\"-0.0\"));\n"
        "    let _ = Io.debug(parse(\"-0.0\"));\n"
        "    let _ = match b { <<x:size(64)-float>> when x == 0.0 -> Io.debug(\"guard\")"
        " | _ -> \"no\" };\n"
        "    let _ = match b { <<x:size(64)-float>> -> { fn g() -> Float = x; Io.debug(g()) }"
        " | _ -> 1.0 };\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(0.0, 0.0, 0.0, 0.0)\ntrue\n1\n0.0\n\"zero\"\nSome(0.0)\n0.0\n"
                   "\"guard\"\n0.0\n">>, Out).

%% report §5.1: a callee is evaluated before its arguments; in `x |> e`,
%% x is evaluated before e, whether e is a call or a parenthesized value
evaluation_order_test() ->
    {ok, Out} = run(
        "fn show(s : String, n : Int) -> Int with Never = { Io.println(s); n }\n"
        "fn f(a : Int) -> ((Int, Int) -> Int) with Never = {\n"
        "    Io.println(\"f(a)\");\n"
        "    fn(x, y) = x + y + a\n"
        "}\n"
        "fn g(a : Int) -> ((Int) -> Int) with Never = { Io.println(\"g(1)\"); fn(x) = x + a }\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Int.toString(show(\"x\", 1) |> f(show(\"a\", 2))(show(\"b\", 3))));\n"
        "    Io.println(Int.toString(g(1)(show(\"h()\", 4))));\n"
        "    Io.println(Int.toString(show(\"y\", 5) |> (g(1))))\n"
        "}\n"),
    ?assertEqual(<<"x\na\nf(a)\nb\n6\ng(1)\nh()\n5\ny\ng(1)\n6\n">>, Out).

%% report §4.8: `!` negates a Bool, in an expression and in a guard
not_operator_test() ->
    {ok, Out} = run(
        "fn small(n : Int) -> String = match n { m when !(m > 5) -> \"small\" | _ -> \"big\" }\n"
        "export fn main() -> Unit with Never = {\n"
        "    let _ = Io.debug(!true);\n"
        "    let _ = Io.debug(List.filter([1, 2, 3, 4], fn(n) = !(n % 2 == 1)));\n"
        "    let _ = Io.debug(small(3));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"false\n[2, 4]\n\"small\"\n">>, Out).

%% report §4.8, §3.10, §5.1: a user type's operator is its member, its
%% ordering goes through its compare, prefix - through its negate; in a receive guard
%% the ordering is a call, a type error by §5.9
user_operators_test() ->
    Vec = "export type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) -> Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(b, a)\n"
          "export fn Vec.negate(Vec(a)) -> Vec = Vec(-a)\n"
          "fn show(Vec(n)) -> String = Int.toString(n)\n",
    {ok, Out} = run(Vec ++
        "export fn main() -> Unit with Never = {\n"
        "    let a = Vec(1);\n"
        "    let b = Vec(2);\n"
        "    Io.println(show(-(a + b)));\n"
        "    Io.println(Float.toString((a * b) + 0.5));\n"
        "    Io.println(Bool.toString(a < b));\n"
        "    Io.println(Bool.toString(a >= b && b <= a && a > b))\n"
        "}\n"),
    ?assertEqual(<<"-3\n2.5\nfalse\ntrue\n">>, Out).

%% report §8.5: a top-level let evaluated through an operator's member
%% comes after the lets that member reads
let_order_through_operator_test() ->
    {ok, Out} = run(
        "export type Vec = Vec(Int)\n"
        "let sum = Vec(1) + Vec(2)\n"
        "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec((a + b) * scale)\n"
        "let scale = 10\n"
        "fn show(Vec(n)) -> String = Int.toString(n)\n"
        "export fn main() -> Unit with Never = Io.println(show(sum))\n"),
    ?assertEqual(<<"30\n">>, Out).

%% report §8.5: a top-level let is evaluated after the lets it depends
%% on, and otherwise in the order the module declares it. A regression
%% test: the order of independent lets was the digraph's, which moved with
%% unrelated changes, and `:reload` kept an unpredictable set of values
let_order_declared_test() ->
    {ok, Out} = run(
        "let a = { Io.println(\"a\"); 1 }\n"
        "let c = { Io.println(\"c\"); b + 1 }\n"
        "let b = { Io.println(\"b\"); 2 }\n"
        "let d = { Io.println(\"d\"); 4 }\n"
        "export fn main() -> Unit with Never = Io.println(Int.toString(a + c + d))\n"),
    ?assertEqual(<<"a\nb\nc\nd\n8\n">>, Out).

%% report §4.7, §8.4: a foreign fn calls its implementation with the
%% arguments as the ABI maps them, and a foreign type's values pass through
%% unchecked
foreign_fn_test() ->
    {ok, Out} = run(
        "foreign type Table\n"
        "foreign fn size(s : String) -> Int = \"erlang:byte_size/1\"\n"
        "foreign fn atom(s : String) -> Foreign = \"erlang:binary_to_atom/1\"\n"
        "foreign fn newTable(n : Foreign, o : List(Foreign)) -> Table with m = \"ets:new/2\"\n"
        "foreign fn insert(t : Table, row : #(Int, String)) -> Bool with m = \"ets:insert/2\"\n"
        "foreign fn lookup(t : Table, k : Int) -> List(#(Int, String)) with m = \"ets:lookup/2\"\n"
        "foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) -> Foreign with m"
        " = \"lists:foreach/2\"\n"
        "export fn main() -> Unit with Never = {\n"
        "    let t = newTable(atom(\"t\"), [atom(\"set\")]);\n"
        "    let _ = insert(t, #(1, \"one\"));\n"
        "    match lookup(t, 1) { [#(_, v)] -> Io.println(v) | _ -> Io.println(\"none\") };\n"
        "    Io.println(Int.toString(size(\"abc\")));\n"
        "    let _ = each(fn(n : Int) -> Unit with Never = Io.println(Int.toString(n)), [1, 2]);\n"
        "    let f = size;\n"
        "    Io.println(Int.toString(List.foldLeft(List.map([\"a\", \"bb\"], f), 0, Int.+)))\n"
        "}\n"),
    ?assertEqual(<<"one\n3\n1\n2\n3\n">>, Out).

%% report §4.7, §8.4: a foreign return whose type holds the same user type
%% twice, side by side, is checked; each is described in full
foreign_sibling_types_test() ->
    {ok, Out} = run(
        "foreign fn pair(xs : List(Optional(Int))) -> #(Optional(Int), Optional(Int))"
        " = \"erlang:list_to_tuple/1\"\n"
        "export fn main() -> Unit with Never = {\n"
        "    let _ = Io.debug(pair([Some(1), None]));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(Some(1), None)\n">>, Out).

%% report §4.7, §7.4, §8.4: a return of another shape faults on first
%% observation, naming the declared type; a nested breach is found; an
%% exception is a fault naming the implementation; an Ernest fault raised
%% inside foreign code passes through as itself
foreign_faults_test() ->
    Main = "export fn main() -> Unit with Never = ",
    {R1, _} = run("foreign fn bad() -> Int = \"erlang:node/0\"\n"
                  ++ Main ++ "Io.println(Int.toString(bad()))\n"),
    ?assertEqual({fault, <<"foreign return does not match Int">>}, R1),
    {R2, _} = run("foreign fn pair() -> #(Int, String) = \"ern_emitter_tests:pair/0\"\n"
                  ++ Main ++ "{ let #(_, s) = pair(); Io.println(s) }\n"),
    ?assertEqual({fault, <<"foreign return does not match #(Int, String)">>}, R2),
    {R3, _} = run("foreign fn opt(k : Int) -> Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                  ++ Main ++ "match opt(1) { Some(n) -> Io.println(Int.toString(n))"
                  " | None -> Io.println(\"none\") }\n"),
    ?assertEqual({fault, <<"foreign return does not match Optional(Int)">>}, R3),
    {ok, Out} = run("foreign fn opt(k : Int) -> Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                    ++ Main ++ "match opt(0) { Some(n) -> Io.println(Int.toString(n))"
                    " | None -> Io.println(\"none\") }\n"),
    ?assertEqual(<<"3\n">>, Out),
    {R4, _} = run("foreign fn boom(x : Int) -> Int = \"erlang:error/1\"\n"
                  ++ Main ++ "Io.println(Int.toString(boom(7)))\n"),
    %% report §11.2: the raise carries the host's stack beside its cause
    ?assertMatch({fault, <<"foreign function erlang:error/1 raised error:7">>, <<_/binary>>}, R4),
    {R5, _} = run("foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) -> Unit with m"
                  " = \"lists:foreach/2\"\n"
                  ++ Main ++ "each(fn(n : Int) -> Unit with Never = fault(\"later\"), [1])\n"),
    ?assertEqual({fault, <<"later">>}, R5).

%% report §7.4: a function value foreign code returns is checked when it is
%% called, its result against its declared result type, in the caller, and
%% one that keeps to it runs. A regression test: such a function's result
%% was never checked, so an ill-typed one reached Ernest code unchecked.
foreign_function_value_test() ->
    Source = "foreign fn funs() -> List((Int) -> Int) = \"ern_emitter_tests:funs/0\"\n"
             "export fn main() -> Unit with Never = match funs() {\n"
             "    [good, bad] -> {\n"
             "        Io.println(Int.toString(good(1)));\n"
             "        Io.println(Int.toString(bad(1)))\n"
             "    }\n"
             "  | _ -> Unit\n"
             "}\n",
    ?assertEqual({{fault, <<"foreign return does not match Int">>}, <<"2\n">>}, run(Source)).

%% report §8.4: the proxy in front of an exposed address is one per address
%% and mailbox type, so exposing the same address twice gives the same one
foreign_proxy_is_one_test() ->
    persistent_term:erase({?MODULE, proxy_seen}),
    {ok, Out} = run("type Msg = Go(Int)\n"
                    "foreign fn remember(a : Address(Msg)) -> Bool with m ="
                    " \"ern_emitter_tests:remember/1\"\n"
                    "export fn main() -> Unit with Msg = {\n"
                    "    let _ = remember(self());\n"
                    "    let again = remember(self());\n"
                    "    Io.println(if again then \"same\" else \"another\")\n"
                    "}\n"),
    ?assertEqual(<<"same\n">>, Out),
    persistent_term:erase({?MODULE, proxy_seen}).

%% report §3.10, §3.8: a foreign value's equality is the host's, of the
%% terms: a reference equals itself and not another, two values that are
%% the same term are equal, and so are two Foreign values made from the
%% same value. A regression test, written after the code; it does not
%% cover a foreign value that holds a function
foreign_equality_test() ->
    {ok, Out} = run(
        "foreign type Ref\n"
        "foreign fn makeRef() -> Ref with m = \"erlang:make_ref/0\"\n"
        "foreign fn same(x : Int) -> Ref = \"erlang:abs/1\"\n"
        "export fn main() -> Unit with m = {\n"
        "    let a = makeRef();\n"
        "    let b = makeRef();\n"
        "    let _ = Io.debug(#(a == a, a == b, same(1) == same(-1), same(1) == same(2)));\n"
        "    let _ = Io.debug(Foreign.from(1) == Foreign.from(1));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(true, false, true, false)\ntrue\n">>, Out).

%% report §8.4, §7.4: an address given to foreign code is a proxy that
%% checks each message on delivery, a bad one faulting the target even
%% when no clause would bind it; a good one arrives, also from inside a
%% list; a reply is checked by the call that observes it
foreign_messages_test() ->
    Junk = "foreign fn junk(a : Address(Msg)) -> Unit with m = \"ern_emitter_tests:junk/1\"\n",
    {R1, _} = run("type Msg = Go(Int)\n" ++ Junk ++
                  "export fn main() -> Unit with Msg = {\n"
                  "    junk(self());\n"
                  "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                  "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, R1),
    {R0, _} = run("type Msg = Go(Int) | Stop\n" ++ Junk ++
                  "export fn main() -> Unit with Msg = {\n"
                  "    junk(self());\n"
                  "    receive { Stop -> Unit }\n"
                  "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, R0),
    {ok, Out} = run("type Msg = Go(Int)\n"
                    "foreign fn good(a : Address(Msg)) -> Unit with m ="
                    " \"ern_emitter_tests:good/1\"\n"
                    "foreign fn tell(targets : List(Address(Msg))) -> Unit with m"
                    " = \"ern_emitter_tests:tell/1\"\n"
                    "export fn main() -> Unit with Msg = {\n"
                    "    good(self());\n"
                    "    receive { Go(n) -> Io.println(Int.toString(n)) };\n"
                    "    tell([self()]);\n"
                    "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                    "}\n"),
    ?assertEqual(<<"1\n2\n">>, Out),
    %% report §6.5, §8.4: an adapted address reaches foreign code through
    %% the same proxy, and the wrap is applied on the way back
    {ok, Wrapped} = run("type Msg = Wrapped(Int)\n"
                        "type Inner = Go(Int)\n"
                        "foreign fn good(a : Address(Inner)) -> Unit with m ="
                        " \"ern_emitter_tests:good/1\"\n"
                        "export fn main() -> Unit with Msg = {\n"
                        "    good(via(fn(Go(n) : Inner) = Wrapped(n), self()));\n"
                        "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                        "}\n"),
    ?assertEqual(<<"1\n">>, Wrapped),
    {R2, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                  "foreign fn server() -> Address(Ask) with m ="
                  " \"ern_emitter_tests:junk_server/0\"\n"
                  "export fn main() -> Unit with Never = {\n"
                  "    let n = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
                  "    Io.println(Int.toString(n))\n"
                  "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, R2).

%% The foreign side of the tests above.
pair() -> {1, 2}.
funs() -> [fun(X) -> X + 1 end, fun(_) -> not_an_int end].
opt(0) -> {'Some', 3};
opt(_) -> {'Some', <<"x">>}.
%% report §8.4: remembers the first address it is given and says whether
%% the next is the same one
remember(Pid) ->
    case persistent_term:get({?MODULE, proxy_seen}, undefined) of
        undefined -> persistent_term:put({?MODULE, proxy_seen}, Pid), false;
        Pid -> true;
        _ -> false
    end.

junk(Pid) -> Pid ! {'Go', <<"x">>}, 'Unit'.
good(Pid) -> Pid ! {'Go', 1}, 'Unit'.
tell(Pids) -> [P ! {'Go', 2} || P <- Pids], 'Unit'.
junk_server() ->
    spawn(fun() -> receive {'Ask', Ref} -> Ref ! {Ref, <<"x">>} end end).

%% report §4.5, plan 2.4: an Ernest function named like an auto-imported
%% Erlang BIF, `size`, `max`, is called by its own name
bif_names_test() ->
    {ok, Out} = run(
        "fn max(a : Int, b : Int) -> Int = if a > b then a else b\n"
        "fn size(xs : List(Int)) -> Int = List.size(xs) * 10\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    Io.println(Int.toString(size([1])))\n"
        "}\n"),
    ?assertEqual(<<"2\n10\n">>, Out).

%% report §4.2, §4.6, §8.5: a module names its own declarations qualified
%% as well, a private function, a `let`, and a type's member, called and
%% taken as values, and a `let` so named is still ordered after the one it
%% reads. A regression test: each was a remote call, undefined for a
%% private function, and the `let` was not seen as a dependency
qualified_own_name_test() ->
    {ok, Out} = run(
        "let total = M.base * 2\n"
        "let base = 3\n"
        "fn two() -> Int = 2\n"
        "type Box = Box(Int)\n"
        "fn Box.open(b : Box) -> Int = match b { Box(n) -> n }\n"
        "export fn main() -> Unit with Never = {\n"
        "    let f = M.two;\n"
        "    let g = M.Box.open;\n"
        "    Io.println(Int.toString(M.two() + f() + M.Box.open(Box(4)) + g(Box(1))));\n"
        "    Io.println(Int.toString(M.total))\n"
        "}\n"),
    ?assertEqual(<<"9\n6\n">>, Out).

%% report §6.3, §4.5: a timed receive's time below 0 is 0 whatever the
%% module calls `max`. A regression test: the emitted `max(0, t)` called
%% the module's own `max/2`, here a difference, which gave a negative time
qualified_max_test() ->
    {ok, Out} = run(
        "fn max(a : Int, b : Int) -> Int = a - b\n"
        "type Msg = Ping\n"
        "export fn main() -> Unit with Msg = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    receive { Ping -> Unit | after 10 -> Io.println(\"after\") }\n"
        "}\n"),
    ?assertEqual(<<"-1\nafter\n">>, Out).

%% report §6.6, §8.4: `Address.call` and `Address.callForever` taken as
%% values check the reply as the calls do. A regression test: as values
%% they were the runtime's functions, and the reply went unchecked
call_as_value_test() ->
    {ok, Out} = run(
        "type Msg = Get(reply : Reply(Int))\n"
        "fn serve() -> Unit with Msg = receive { Get(reply = r) -> answer(r, 7) }\n"
        "export fn main() -> Unit with Never = {\n"
        "    let c : (Address(Msg), (Reply(Int)) -> Msg, Int) -> Optional(Int) with Never =\n"
        "        Address.call;\n"
        "    let w : (Address(Msg), (Reply(Int)) -> Msg) -> Int with Never =\n"
        "        Address.callForever;\n"
        "    let asked = c(spawn(Local, serve), fn(r) = Get(reply = r), 1000);\n"
        "    let n = Optional.withDefault(asked, 0);\n"
        "    Io.println(Int.toString(n + w(spawn(Local, serve), fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"14\n">>, Out),
    {ok, Typed, _, Env} = ern_typecheck:check_string(
        ['M'], <<"type Msg = Get(reply : Reply(Int))\n"
                 "export fn main() -> Unit with Never = {\n"
                 "    let c : (Address(Msg), (Reply(Int)) -> Msg, Int) -> Optional(Int) with Never"
                 " =\n"
                 "        Address.call;\n"
                 "    Unit\n"
                 "}\n">>),
    Src = unicode:characters_to_binary(ern_emitter:erl_source(['M'], Typed, Env)),
    ?assertMatch({_, _}, binary:match(Src, <<"reply does not match Optional(Int)">>)).

%% report §5.11: the report's frame round trip, sub-octet fields, utf8,
%% float and signed and little segments, a dynamic size in a pattern, and
%% an unaligned rest that fails the match
bitstrings_test() ->
    {ok, Out} = run(
        "fn frame(len : Int, body : Bytes) -> Bytes = <<len:size(16)-big, body:bytes>>\n"
        "fn parseFrame(bytes : Bytes) -> Optional(#(Int, Bytes, Bytes)) = match bytes {\n"
        "    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))\n"
        "  | _ -> None\n"
        "}\n"
        "fn show(b : Bytes) -> String = match b {\n"
        "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn nibbles(b : Bytes) -> String = match b {\n"
        "    <<hi:size(4), lo:size(4), rest:bytes>> ->"
        " Int.toString(hi) <> \":\" <> Int.toString(lo) <> \" \" <> nibbles(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) -> String = match b {\n"
        "    <<_:size(n)-bytes-unit(1), rest:bytes>> -> show(rest)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "export fn main() -> Unit with Never = {\n"
        "    let f = frame(1, <<65, 66>>);\n"
        "    Io.println(show(f));\n"
        "    match parseFrame(f) {\n"
        "        Some(#(len, body, rest)) ->"
        " Io.println(Int.toString(len) <> \": \" <> show(body) <> \"| \" <> show(rest))\n"
        "      | None -> Io.println(\"none\")\n"
        "    };\n"
        "    match parseFrame(<<0>>) {"
        " Some(_) -> Io.println(\"some\") | None -> Io.println(\"none\") };\n"
        "    match <<'é':utf8, 0>> { <<c:utf8, _:bytes>> -> Io.println(String.fromList([c]))"
        " | _ -> Io.println(\"?\") };\n"
        "    Io.println(nibbles(<<31, 42>>));\n"
        "    Io.println(show(<<1.5:size(32)-float, -1:size(8)-signed, 258:size(16)-little>>));\n"
        "    Io.println(tail(8, <<1, 2>>));\n"
        "    Io.println(tail(4, <<1, 2>>));\n"
        "    Io.println(show(<<(String.toUtf8(\"hi\")):bytes, 3:size(4), 4:size(4)>>))\n"
        "}\n"),
    ?assertEqual(<<"0 1 65 66 \n1: 65 | 66 \nnone\né\n1:15 2:10 \n63 192 0 0 255 2 1 \n2 \nno\n"
                   "104 105 52 \n"/utf8>>, Out).

%% report §7.4, §5.11: a value that does not fit its width faults with
%% segment overflow, an Int, a Float, a Bytes of another size; a dynamic
%% size that leaves the count unaligned faults at construction
bitstring_faults_test() ->
    Main = "export fn main() -> Unit with Never = ",
    Three = "fn three() -> Int = List.size([1, 2, 3])\n",
    Faults = [{"<<300:size(8)>>", <<"segment overflow">>},
              {"<<(0 - 129):size(8)-signed>>", <<"segment overflow">>},
              {"<<1.0e300:size(32)-float>>", <<"segment overflow">>},
              {"<<(<<1, 2, 3>>):size(2)-bytes>>", <<"segment overflow">>},
              {"<<7:size(three())>>", <<"bitstring not byte-aligned">>},
              {"<<(<<1>>):size(three())-bytes-unit(1)>>", <<"bitstring not byte-aligned">>}],
    lists:foreach(fun({Bits, Cause}) ->
                      {R, _} = run(Three ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({fault, Cause}, R)
                  end, Faults).

%% report §5.11: a bare segment is an unsigned big-endian int of size 8;
%% a sized int is big-endian; `signed` alone is 8 bits. A regression test,
%% written after the code; it does not cover `little` or a pattern with a
%% signed segment
bitstring_defaults_test() ->
    Show = "fn show(b : Bytes) -> String = match b {\n"
           "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
           "  | _ -> \"\"\n"
           "}\n",
    {ok, Out} = run(Show ++
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(show(<<258:size(16)>>));\n"
        "    Io.println(match <<255>> { <<x>> -> Int.toString(x) | _ -> \"no\" });\n"
        "    Io.println(show(<<-1:signed>>))\n"
        "}\n"),
    ?assertEqual(<<"1 2 \n255\n255 \n">>, Out),
    {R, _} = run("export fn main() -> Unit with Never = { let _ = <<-1>>; Unit }\n"),
    ?assertEqual({fault, <<"segment overflow">>}, R).

%% report §8.5: top-level lets run in the order the checker found, a let
%% after every let it reaches through the functions it names, whatever the
%% order they are declared in. A regression test for the order the emitter
%% now reads rather than computing again; the order it had was the same.
initialization_order_test() ->
    {ok, Out} = run("let total = twice() + 1\n"
                    "fn twice() -> Int = base * 2\n"
                    "let base = 10\n"
                    "export fn main() -> Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"21\n">>, Out).

%% report §4.2: a name shadowed at each step of the lookup order compiles
%% to the declaration the checker resolved it to, which the emitter reads
%% from the name's `ref` rather than resolving again: a type's member, the
%% module's own function over the prelude's `self`, the module named
%% qualified, `Prelude.self`, and a local binding over them all. A
%% regression test for the single decision; the order it had was the same.
lookup_order_test() ->
    {ok, Out} = run("type Box = Box(Int)\n"
                    "fn Box.value(b : Box) -> Int = match b { Box(n) -> n }\n"
                    "fn value(b : Box) -> Int = 100\n"
                    "fn self() -> Int = 5\n"
                    "export fn main() -> Unit with Never = {\n"
                    "    let me = Prelude.self();\n"
                    "    let first = Box.value(Box(1)) + value(Box(1)) + self() + M.self();\n"
                    "    let value = fn(b : Box) -> Int = 1000;\n"
                    "    Io.println(Int.toString(first + value(Box(1))))\n}\n"),
    ?assertEqual(<<"1111\n">>, Out).

%% A function may be named `module_info` or `record_info`, which the host
%% gives every module: the emitter compiles them under names no Ernest name
%% can spell. A regression test: the compiler refused them with Erlang's "function
%% module_info/0 already defined", and the shell faulted. Not covered here:
%% a call from another module, which the shell test reaches.
host_reserved_names_test() ->
    {ok, Out} = run("export fn module_info() -> Int = 7\n"
                    "fn record_info(x : Int) -> Int = x + 1\n"
                    "export let total = module_info() + record_info(1)\n"
                    "export fn main() -> Unit with Never = {\n"
                    "    Io.println(Int.toString(total));\n"
                    "    Io.println(Int.toString(List.foldLeft(List.map([1, 2], record_info), 0,"
                    " fn(a, b) = a + b)))\n}\n"),
    ?assertEqual(<<"9\n5\n">>, Out).

%% report §5.11, §5.4: a variable a bitstring pattern binds is the
%% pattern's own, not a use of an outer name. A regression test: a local
%% fn whose pattern bound `y` was read as depending on the later `let y`,
%% and the compiler crashed with an Erlang exception; used after the `let`,
%% it captured the outer `y` it never read.
bitstring_pattern_binds_test() ->
    Local = "    fn first(b : Bytes) -> Int = match b { <<y, _:bytes>> -> y | _ -> 0 };\n",
    {ok, Before} = run("export fn main() -> Unit with Never = {\n" ++ Local ++
                       "    let n = first(<<5, 6>>);\n    let y = 10;\n"
                       "    Io.println(Int.toString(n + y))\n}\n"),
    ?assertEqual(<<"15\n">>, Before),
    {ok, After} = run("export fn main() -> Unit with Never = {\n    let y = 10;\n" ++ Local ++
                      "    Io.println(Int.toString(first(<<5, 6>>) + y))\n}\n"),
    ?assertEqual(<<"15\n">>, After).

%% report §5.11, §7.4, §3.1: a Bytes shorter than its size and a negative
%% size fault at construction; a Float narrowed to 16 bits rounds to the
%% nearest, one too small becomes 0.0, one above the largest 16-bit float
%% faults; a float pattern does not match the bytes of an infinity or a
%% NaN; a rest that a dynamic size leaves unaligned does not match. A
%% regression test, written after the code; it does not cover a 32-bit
%% float's rounding, nor a negative size in a pattern
bitstring_edges_test() ->
    Neg = "fn neg() -> Int = 0 - List.size([1, 2, 3, 4, 5, 6, 7, 8])\n",
    Main = "export fn main() -> Unit with Never = ",
    Faults = ["<<(<<1>>):size(2)-bytes>>", "<<1:size(neg())>>", "<<(<<1>>):size(neg())-bytes>>",
              "<<65519.0:size(16)-float>>"],
    lists:foreach(fun(Bits) ->
                      {R, _} = run(Neg ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({Bits, {fault, <<"segment overflow">>}}, {Bits, R})
                  end, Faults),
    {ok, Out} = run(
        "fn half(b : Bytes) -> String = match b {\n"
        "    <<f:size(16)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn single(b : Bytes) -> String = match b {\n"
        "    <<f:size(32)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) -> String = match b {\n"
        "    <<_:size(n), rest:bytes>> -> Int.toString(Bytes.size(rest))\n"
        "  | _ -> \"no\"\n"
        "}\n"
        ++ Main ++ "{\n"
        "    Io.println(half(<<3.14159:size(16)-float>>));\n"
        "    Io.println(half(<<1.0e-10:size(16)-float>>));\n"
        "    Io.println(half(<<65504.0:size(16)-float>>));\n"
        "    Io.println(single(<<127, 128, 0, 0>>));\n"
        "    Io.println(single(<<255, 128, 0, 0>>));\n"
        "    Io.println(single(<<127, 192, 0, 0>>));\n"
        "    Io.println(half(<<124, 0>>));\n"
        "    Io.println(tail(8, <<1, 2>>));\n"
        "    Io.println(tail(4, <<1, 2>>))\n"
        "}\n"),
    ?assertEqual(<<"3.140625\n0.0\n65504.0\nno\nno\nno\nno\n1\nno\n">>, Out).

%% report §7.4: a zero divisor faults main with its cause
division_fault_test() ->
    {Result, _} = run("export fn main() -> Unit with Never = {\n"
                      "    let z = List.size([]);\n"
                      "    Io.println(Int.toString(1 / z))\n"
                      "}\n"),
    ?assertEqual({fault, <<"division by zero">>}, Result).

%% report §7.4, §9.6: fault compiles at any type and faults with its cause
fault_test() ->
    {Result, _} = run("fn later() -> Int = fault(\"later\")\n"
                      "export fn main() -> Unit with Never = Io.println(Int.toString(later()))\n"),
    ?assertEqual({fault, <<"later">>}, Result).

%% report §9.6: `todo` is no longer the prelude's, `fault` taking its place
todo_is_unknown_test() ->
    ?assertMatch({error, _}, ern_typecheck:check_string(['M'],
                                                         "fn later() -> Int = todo(\"x\")\n")).

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

%% report §3.5, §8.4: a selected field, one element of the tuple where every
%% constructor holds it at one place and a case on the tag where the places
%% differ, its operand evaluated once
field_selection_test() ->
    {ok, Out} = run(
        "type Pair = Left(a : Int, name : String) | Right(name : String, z : Int)\n"
        "type Point = Point(x : Int, y : Int)\n"
        "fn v(p : Pair) -> Pair with Never = { Io.println(\"once\"); p }\n"
        "export fn main() -> Unit with Never = {\n"
        "    Io.println(v(Left(a = 1, name = \"l\")).name <> Right(name = \"r\", z = 2).name);\n"
        "    Io.println(Int.toString(Point(x = 3, y = 4).y))\n"
        "}\n"),
    ?assertEqual(<<"once\nlr\n4\n">>, Out).

%% report §3.5, §5.1: named fields are stored in canonical order and
%% evaluated in the order written, in a construction and in an update from
%% a base value, whose base is evaluated first. A regression test: the
%% fields were evaluated in canonical order. It does not cover a positional
%% constructor, whose one field has no order
field_order_test() ->
    {ok, Out} = run(
        "type Snap = Snap(z : Int, a : Int, m : Int)\n"
        "fn v(s : String, n : Int) -> Int with Never = { Io.println(s); n }\n"
        "export fn main() -> Unit with Never = {\n"
        "    let s = Snap(z = v(\"z\", 1), a = v(\"a\", 2), m = v(\"m\", 3));\n"
        "    let t = Snap(..{ Io.println(\"base\"); s }, m = v(\"m\", 4), a = v(\"a\", 5));\n"
        "    let _ = Io.debug(#(s, t));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"z\na\nm\nbase\nm\na\n"
                   "#(Snap(a = 2, m = 3, z = 1), Snap(a = 5, m = 4, z = 1))\n">>, Out).

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

%% report §6.2, §6.9: a process monitored from its start that faults
%% reports its spawn site and its cause, however soon it faults
monitor_site_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down)\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(Local, fn() -> Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(site = f, reason = Fault(msg))) -> Io.println(f <> \" \" <> msg)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"M.main:4 division by zero\n">>, Out).

%% report §6.9: a Down's function is the top-level declaration the spawn
%% is written in: one inside a local fn or a lambda counts as written in
%% the enclosing declaration, and `spawn` taken as a value counts where
%% its name is written. A regression test, written after the code; it does
%% not cover a spawn in a top-level `let`'s initializer
down_site_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down)\n"
        "fn idle() -> Unit with Never = receive { after 100 -> Unit }\n"
        "fn report() -> Unit with Msg = receive {\n"
        "    Died(Down(site = f, reason = _)) -> Io.println(f)\n"
        "}\n"
        "fn outer() -> Unit with Msg = {\n"
        "    fn inner() -> Address(Never) with Msg = spawn(Local, idle);\n"
        "    monitor(inner(), Died);\n"
        "    report();\n"
        "    let viaLambda = fn() = spawn(Local, idle);\n"
        "    monitor(viaLambda(), Died);\n"
        "    report();\n"
        "    let s = spawn;\n"
        "    monitor(s(Local, idle), Died);\n"
        "    report()\n"
        "}\n"
        "export fn main() -> Unit with Msg = outer()\n"),
    ?assertEqual(<<"M.outer:7\nM.outer:10\nM.outer:13\n">>, Out).

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

%% report §8.5, §8.2: a system module's reference is bound before the
%% program's own top-level lets are evaluated, so an initializer may print
system_reference_in_let_test() ->
    {ok, Out} = run("let greeting = Io.println(\"from a let\")\n"
                    "export fn main() -> Unit with Never = Io.println(\"from main\")\n"),
    ?assertEqual(<<"from a let\nfrom main\n">>, Out).

%% report §9, Appendix E; plan 2.1 table two: every prelude value the
%% checker knows is emitted as a call to a function that exists, with the
%% arity of its type, so no accepted name can reach the runtime as undef
prelude_targets_test() ->
    Missing = [Q || {Q, Text, _} <- ern_prelude:values(),
                    {M, F, A} <- [prelude_target(Q, Text)],
                    code:ensure_loaded(M) =/= {module, M} orelse
                        not erlang:function_exported(M, F, A)],
    ?assertEqual([], Missing).

%% The emission of a prelude name, as ern_emitter makes it; inline
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
        [spawnMonitored] -> {ern_rt, spawn_monitored, 4};
        [via] -> {ern_rt, via, 2};
        [answer] -> {ern_rt, answer, 2};
        [monitor] -> {ern_rt, monitor, 2};
        [kill] -> {ern_rt, kill, 1};
        [remote] -> {ern_rt, remote, 1};
        [restarting] -> {ern_rt, restarting, 2};
        [fault] -> {ern_rt, fault, 1};
        ['Address', call] -> {ern_rt, call, 3};
        ['Address', callForever] -> {ern_rt, call_forever, 2};
        ['Sys', _] -> {ern_rt, sys, 1};
        [_, Op] when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/'; Op =:= '%'; Op =:= '<>';
                     Op =:= negate -> {erlang, is_atom, 1};
        [Ns, F] -> {ern_emitter:module_atom([Ns]), F, Arity}
    end.

%% report §6.5, §6.9, §7.3, §9.5: kill is a Down with Killed, a fault a
%% Down with its cause, via adapts a message, remote answers
%% Left(NoRemotePeer) with no peer, all through compiled code
process_functions_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down) | Tick\n"
        "fn idle() -> Unit with Never = receive { after 10000 -> Unit }\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let w = spawn(Local, fn() = idle());\n"
        "    monitor(w, Died);\n"
        "    kill(w);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(Local, fn() -> Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(m), site = _)) -> Io.println(m)\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    send(via(fn(u : Unit) = Tick, self()), Unit);\n"
        "    receive { Tick -> Io.println(\"tick\") | _ -> Io.println(\"other\") };\n"
        "    Io.println(match remote(fn() = 1) {\n"
        "        Left(NoRemotePeer) -> \"no peer\"\n"
        "      | Left(PeerLost) -> \"lost\"\n"
        "      | Right(_) -> \"answered\"\n"
        "    })\n"
        "}\n"),
    ?assertEqual(<<"killed\ndivision by zero\ntick\nno peer\n">>, Out).

%% report §6.9: kill on a process that has already ended has no effect,
%% and a monitor placed after the end answers Unknown, with no spawn site,
%% since the runtime keeps nothing of an ended process. A regression test,
%% written after the code; it does not cover kill on a system process
kill_dead_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down)\n"
        "export fn main() -> Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let w = spawn(Local, fn() -> Unit with Never = { let _ = 1 / z; Unit });\n"
        "    monitor(w, Died);\n"
        "    receive { Died(_) -> Unit };\n"
        "    kill(w);\n"
        "    monitor(w, Died);\n"
        "    receive { Died(d) -> { let _ = Io.debug(d); Unit } }\n"
        "}\n"),
    ?assertEqual(<<"Down(reason = Unknown, site = \"\")\n">>, Out).

%% report §8.2, §9.7: a system reference is private to its module, and
%% the prelude binds none, so a program names neither `Io.stdout` nor
%% `Sys.stdout`, and a system module's message is not a program's to make
system_reference_private_test() ->
    Refused = fun(Main) ->
                      ern_typecheck:check_string(['M'],
                                                 "export fn main() -> Unit with Never = "
                                                 ++ Main ++ "\n")
              end,
    ?assertMatch({error, _}, Refused("send(Io.stdout, String.toUtf8(\"hi\"))")),
    ?assertMatch({error, _}, Refused("send(Sys.stdout, \"hi\")")),
    ?assertMatch({error, _}, Refused("{ let _ = Clock.Now; Unit }")).


%% report §8.5: a compiled module declares the modules it depends on, as
%% `'$deps'/0`, so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file; a module that
%% depends on none declares none
deps_test() ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'], "export let one = 1\n"),
    Build = #{source_hash => <<>>, deps => [{['Net', 'Http'], <<"hash">>}]},
    {ok, Mod, Bin} = ern_emitter:compile(['M'], Typed, Iface, Env, Build),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    ?assert(erlang:function_exported(Mod, '$deps', 0)),
    ?assertEqual(['ern@net@http'], Mod:'$deps'()),
    {ok, Typed2, Iface2, Env2} = ern_typecheck:check_string(['N'], "export let one = 1\n"),
    {ok, Mod2, Bin2} = ern_emitter:compile(['N'], Typed2, Iface2, Env2),
    {module, Mod2} = code:load_binary(Mod2, "test", Bin2),
    ?assertNot(erlang:function_exported(Mod2, '$deps', 0)).

%% report §8.5: the emitter orders the top-level lets by what they
%% reference, and a name bound inside a function body is not one of
%% them; before that, a program like this crashed the emitter, since its
%% graph held a cycle the checker had not seen
shadowed_name_in_init_order_test() ->
    ?assertEqual({ok, <<"3\n">>},
                 run("let three = pick([3])\n"
                     "fn pick(xs : List(Int)) -> Int = match xs { [three] -> three | _ -> 0 }\n"
                     "export fn main() -> Unit with m = Io.println(Int.toString(three))\n")).
