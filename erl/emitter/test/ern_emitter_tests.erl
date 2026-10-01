-module(ern_emitter_tests).

-export([write_golden/0, pair/0, opt/1, funs/0, improper/1, remember/1, junk/1, good/1,
         tell/1, junk_server/0, hello_junk/0, hello_good/0, relay_junk/1, relay_good/1, same/1,
         ask_junk/1, ask_good/1, call_nested_bad/1, call_nested_good/1, reaper_words/0]).

-include_lib("eunit/include/eunit.hrl").

%% A program's `up(s)`: true once the restarting process `s` answers, its
%% new run begun, and false once it has ended. A message sent before a
%% restart is lost with the mailbox (report §6.9), so a test that restarts
%% a process sends it the next message only after this.
-define(UP,
        "fn up(s : Address(Msg)) : Bool with m =\n"
        "    match Address.call(s, fn(r) = Ping(reply = r), 1000) {\n"
        "        Some(_) -> true\n"
        "      | None -> Process.info(Process.fromAddress(s)) != None && up(s)\n"
        "    }\n").
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

%% `standard => true` compiles the module as the standard library's own.
run(Ns, Text, Opts) ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Text),
    Build = #{source_hash => <<>>, deps => [], standard => maps:get(standard, Opts, false)},
    {ok, Mod, Bin} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    Result = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                             (maps:remove(standard, Opts))#{init => fun() -> init(Mod) end,
                                   stdout => fun(B) -> Me ! {out, B} end,
                                   stdin => fun() -> eof end}),
    {Result, collect([])}.

%% report §11: a declaration the checker would not have passed is a defect
%% of the toolchain, which the emitter raises as one, for `ern` to report
%% as its own failure, and never answers as a program's diagnostic. The
%% typed tree is the checker's with a block's last expression taken away,
%% as no program can write it. A regression test: the emitter answered a
%% diagnostic, which `make untested` found no test ever reached.
emitter_defect_test() ->
    {ok, Typed, Iface, Env} =
        ern_typecheck:check_string(['M'], "fn f() : Int = {\n    let x = 1;\n    x\n}\n"),
    Broken = without_last_statement(Typed),
    ?assertError({emitter_defect, _, "a block ends with a `let`"},
                 ern_emitter:compile(['M'], Broken, Iface, Env)).

without_last_statement(#e_block{stmts = Stmts} = B) ->
    B#e_block{stmts = lists:droplast(Stmts)};
without_last_statement(T) when is_tuple(T) ->
    list_to_tuple([without_last_statement(E) || E <- tuple_to_list(T)]);
without_last_statement(L) when is_list(L) ->
    [without_last_statement(E) || E <- L];
without_last_statement(X) ->
    X.

%% The launcher's job (report §8.5): top-level lets before main.
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

%% report §8.1, §8.4, Appendix B
hello_golden_test() ->
    ?assertEqual(target_forms("hello.erl"), example_forms("hello")).

%% report §6.2, §6.3, §6.6, §8.4, Appendix B
counter_golden_test() ->
    ?assertEqual(target_forms("counter.erl"), example_forms("counter")).

%%
%% Golden files: the Erlang source of every MVP 1 example, as --emit-erl
%% writes it, kept under test/golden and regenerated with make golden
%%

-define(GOLDEN, "../../../test/golden/").

golden_names() ->
    ["hello", "counter", "upgrade", "pingpong", "stack", "patterns", "kvparser", "services",
     "modules/net/http", "modules/main"].

%% report §4.6, §8.5, §11.1: a `let` is a value whatever its type, so one
%% that holds a function is reached through its getter and called by
%% applying what the getter answers, in its own module and in another; a
%% `fn` of the same type is called directly. The interface says which of
%% the two a name is.
let_of_function_type_test() ->
    {_, Out} = run("let g = fn() = 1\n"
                   "let h = fn(x : Int) = x + 1\n"
                   "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"
                   "export fn main() : Unit with m = {\n"
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
                                          "export fn f(x : Int) : Int = x * 2\n"),
    {ok, MMod, MBin} = ern_emitter:compile(['M'], MTyped, MIface, MEnv),
    {module, MMod} = code:load_binary(MMod, "test", MBin),
    %% the interface the dependent is checked against is the compiled one
    {ok, #{iface := Iface}} = ern_iface:read(MBin),
    ?assertEqual([['M', g], ['M', h]], lists:sort(Iface#iface.lets)),
    {ok, Decls} = ern_parser:parse_string(
                    "export fn main() : Unit with m = {\n"
                    "    Io.println(Int.toString(M.g()));\n"
                    "    Io.println(Int.toString(M.h(2)));\n"
                    "    Io.println(Int.toString(twice(M.h, 0)));\n"
                    "    Io.println(Int.toString(M.f(3)))\n"
                    "}\n"
                    "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"),
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

%% report §11.1: the emitted source of every example is what the
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

%% report Appendix B
examples_test_() ->
    Expected = [{"hello", <<"hello, world\n">>},
                {"counter", <<"count is 8\n">>},
                {"upgrade", <<"before upgrade: 8\nafter upgrade: 10\n">>},
                {"pingpong", <<"ping 3\npong 3\nping 2\npong 2\nping 1\npong 1\n">>},
                {"stack", <<"top is 2\n">>},
                {"patterns", <<"minus one\nzero\nother\na 2\nnothing\n-3\n3\n4\n">>},
                {"kvparser", <<"a 12\nbad key: =1\nexpected =: a\nbad number: a=x\n">>},
                {"services", <<"before: apples 3, next id 3, audit [1: put apples; 2: put pears]\n"
                               "after the restart: apples none, next id 1, audit []\n">>}],
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
            "    | At(\n"
            "        /// across\n"
            "        x : Int,\n"
            "        y : Int)\n"
            "export fn area(shape : Shape) : Int = 0\n">>,
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

%% report §11.1: the interface travels in the BEAM chunk ErnI
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
    {ok, _, IfaceA, _} = ern_typecheck:check_string(['M'], "export fn id(x : a) : a = x\n"),
    {ok, _, IfaceT, _} = ern_typecheck:check_string(['M'], "export fn id(x : t) : t = x\n"),
    ?assertEqual(ern_iface:hash(IfaceA), ern_iface:hash(IfaceT)).

%% report §11.1: --emit-erl gives the module as Erlang source
erl_source_test() ->
    {Ns, Bin} = example("hello"),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Ns, Bin),
    Src = unicode:characters_to_binary(ern_emitter:erl_source(Ns, Typed, Env)),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ern@hello).">>)).

%% report §4.2: the module atom is ern@ and the path with @ for /
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
        "export fn main() : Unit with Never = {\n"
        "    let base = 10;\n"
        "    fn add(x : Int) : Int = base + x;\n"
        "    fn count(n : Int) : Int = if n == 0 then 0 else 1 + count(n - 1);\n"
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
        "export fn main() : Unit with Never = {\n"
        "    let x = 1;\n"
        "    fn f() : Int = x;\n"
        "    let x = 2;\n"
        "    Io.println(Int.toString(f() * 10 + x));\n"
        "    let a = 1;\n"
        "    fn g() : Int = h();\n"
        "    let a = 2;\n"
        "    fn h() : Int = a;\n"
        "    Io.println(Int.toString(g()));\n"
        "    let b = 5;\n"
        "    let early = k();\n"
        "    fn k() : Int = b + 1;\n"
        "    Io.println(Int.toString(early));\n"
        "    let k2 = 10;\n"
        "    fn add(n : Int) : Int = n + k2;\n"
        "    let r = { fn twice(n : Int) : Int = add(add(n)); twice(1) };\n"
        "    Io.println(Int.toString(r))\n"
        "}\n"),
    ?assertEqual(<<"12\n2\n6\n21\n">>, Out).

%% report §4.6: shadowing rebinds; each binding is its own variable
shadowing_test() ->
    {ok, Out} = run(
        "export fn main() : Unit with Never = {\n"
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
        "fn half(n : Int) : Either(String, Int) =\n"
        "    if n % 2 == 0 then Right(n / 2) else Left(\"odd\")\n"
        "fn quarter(n : Int) : Either(String, Int) = {\n"
        "    let h <- half(n);\n"
        "    let q <- half(h);\n"
        "    Right(q)\n"
        "}\n"
        "fn both(a : Optional(Int), b : Optional(Int)) : Optional(Int) = {\n"
        "    let x <- a;\n"
        "    let y <- b;\n"
        "    Some(x + y)\n"
        "}\n"
        "fn show(e : Either(String, Int)) : String = match e {\n"
        "    Right(n) -> Int.toString(n)\n"
        "  | Left(s) -> s\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn count() : Int = List.size(items)\n"
        "let items = [1, 2, 3]\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"6\n">>, Out).

%%
%% Expressions
%%

%% report §5.9, §5.10: a guard that is not an Erlang guard falls through
%% to the next clause
match_general_guard_test() ->
    {ok, Out} = run(
        "fn small(n : Int) : Bool = n < 3\n"
        "fn name(n : Int) : String = match n {\n"
        "    k when small(k) -> \"small\"\n"
        "  | k when k % 2 == 0 -> \"even\"\n"
        "  | _ -> \"odd\"\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn name(n : Int) : String = match n {\n"
        "    k when k == 7 -> \"seven\"\n"
        "  | k when 10 / k == 5 -> \"half\"\n"
        "  | _ -> \"other\"\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
    Kind = "fn kind(s : Shape) : String = match s {\n"
           "    Circle(n) or Square(n) when 10 / n > 0 -> \"sized\"\n"
           "  | _ -> \"dot\"\n"
           "}\n",
    {ok, Out} = run(Shape ++ Kind ++
        "fn area(s : Shape) : Int = match s {\n"
        "    Circle(n) or Square(n) when n > 1 -> n * 10\n"
        "  | Circle(n) or Square(n) -> n\n"
        "  | Dot -> 0\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(area(Circle(1))));\n"
        "    Io.println(Int.toString(area(Square(2))));\n"
        "    Io.println(Int.toString(area(Dot)));\n"
        "    Io.println(kind(Square(5)));\n"
        "    Io.println(kind(Dot))\n"
        "}\n"),
    ?assertEqual(<<"1\n20\n0\nsized\ndot\n">>, Out),
    {R, _} = run(Shape ++ Kind ++
        "export fn main() : Unit with Never = Io.println(kind(Circle(0)))\n"),
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
        "export fn main() : Unit with Never = {\n"
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
        "fn generic(x : a) : String = Io.show(x)\n"
        "fn pure(c : Char) : String = Io.show(Some(c))\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Io.show(Snap(dir = \"x\", seen = 2)));\n"
        "    Io.println(pure('a'));\n"
        "    Io.println(String.join(List.map([<<1>>, <<2, 3>>], Io.show), \" \"));\n"
        "    Io.println(generic('a'))\n"
        "}\n"),
    ?assertEqual(<<"Snap(dir = \"x\", seen = 2)\nSome('a')\n<<1>> <<2, 3>>\n97\n">>, Out).

%% report §4.2, Appendix E.1: a module's own type named Io may have members
%% show and debug, and a call of them, and each as a value, is the
%% module's. A regression test: the emitter read the written path, and
%% called the library's in their place
own_io_show_test() ->
    {ok, Out} = run(
        "type Io = Io(n : Int)\n"
        "fn Io.show(x : Io) : String = \"mine \" <> Int.toString(x.n)\n"
        "fn Io.debug(x : Io) : Io = x\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Io.show(Io(n = 1)));\n"
        "    let f = Io.show;\n"
        "    Io.println(f(Io.debug(Io(n = 2))))\n"
        "}\n"),
    ?assertEqual(<<"mine 1\nmine 2\n">>, Out).

%% report Appendix E.1: Io.debug writes a String as a literal, with `"`,
%% `\\`, a line feed and a tab escaped by name, another control character
%% by its code point, and every other character as itself. A regression
%% test, written after the code; it does not cover a character outside
%% the Basic Multilingual Plane
io_debug_escapes_test() ->
    {ok, Out} = run("export fn main() : Unit with Never = {\n"
                    "    let _ = Io.debug(\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\");\n"
                    "    Unit\n"
                    "}\n"),
    ?assertEqual(<<"\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\"\n"/utf8>>, Out).

%% report §8.2: keys and lines are the same terminal, so the process that
%% claims it the other way faults, naming the side that holds it
terminal_is_lines_or_keys_test() ->
    {R1, _} = run_at_terminal("type Msg = Pressed(Terminal.Event)\n"
                  "export fn main() : Unit with Msg = {\n"
                  "    let _ = Io.readLine();\n"
                  "    let _ = Terminal.subscribe(Pressed);\n"
                  "    receive { Pressed(_) -> Unit }\n"
                  "}\n"),
    ?assertEqual({fault, <<"the terminal is already read as lines">>}, R1).

%% report §8.2, §7.4: a claim of the terminal the other way faults the
%% process that makes it, and the first claim stands: a worker that
%% subscribes after main read a line faults, and main reads on. A
%% regression test: the entry process faulted, whoever asked
terminal_claim_faults_its_caller_test() ->
    ?assertEqual({ok, <<"the terminal is already read as lines\nread on\n">>},
                 run_at_terminal("type Msg = Pressed(Terminal.Event)\n"
                                 "type MainMsg = Ended(Down)\n"
                                 "fn watch() : Unit with Msg = {\n"
                                 "    let _ = Terminal.subscribe(Pressed);\n"
                                 "    Unit\n"
                                 "}\n"
                                 "export fn main() : Unit with MainMsg = {\n"
                                 "    let _ = Io.readLine();\n"
                                 "    let _ = spawnMonitored(Local, watch, Ended);\n"
                                 "    receive {\n"
                                 "        Ended(Down(reason = Fault(c), site = _)) ->\n"
                                 "            Io.println(c)\n"
                                 "      | Ended(_) -> Io.println(\"ended\")\n"
                                 "    };\n"
                                 "    let _ = Io.readLine();\n"
                                 "    Io.println(\"read on\")\n"
                                 "}\n")).

%% report §8.6, §7.4: a program whose every process waits forever ends
%% with the entry process's fault, `deadlock`; a timed receive is a source
%% and ends by itself
deadlock_test() ->
    {R1, _} = run("type Msg = Ping\n"
                  "export fn main() : Unit with Msg = receive { Ping -> Unit }\n"),
    ?assertEqual({fault, <<"deadlock">>}, R1),
    {R2, Out} = run("type Msg = Ping\n"
                    "export fn main() : Unit with Msg = receive {\n"
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
                    "export fn main() : Unit with M = {\n"
                    "    receive { Get(reply = r) -> answer(r, 1) | after 0 - 5 ->"
                    " Io.println(\"after\") };\n"
                    "    let quiet = spawn(Local, fn() : Unit with M = receive { M -> Unit });\n"
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
        "fn later(to : Address(Msg)) : Unit with Never = {\n"
        "    receive { after 50 -> Unit };\n"
        "    send(to, Ping)\n"
        "}\n"
        "fn server() : Unit with Msg = receive {\n"
        "    Get(reply = r) -> { receive { after 50 -> Unit }; answer(r, 7) }\n"
        "  | Ping -> Unit\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
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
                 "fn server() : Unit with Req = receive { Other -> Unit }\n"
                 "export fn main() : Unit with m = {\n"
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
        "fn loop(n : Int) : Unit with Msg = receive {\n"
        "    Bump -> loop(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Get(reply = r) -> { answer(r, n); loop(n) }\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(Local, restarting(limit, fn() : Unit with Msg = loop(0)));\n"
        "    send(s, Bump);\n"
        "    send(s, Crash);\n"
        "    receive { after 100 -> Unit };\n"
        "    send(s, Bump);\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"1\n">>, Out).

%% report §6.9: past the limit the next fault ends the process with its
%% cause, which is its one death a monitor is told of; a restart is none,
%% and a limit of no restarts ends it at the first fault. Each start says
%% so, so that a limit of one restart is told from a limit of none, which
%% the test could not do before (findings.md's C38)
restart_limit_test() ->
    Program = fun(Restarts) ->
        "type Msg = Crash | Ping(reply : Reply(Unit))\n"
        "type MainMsg = Died(Down)\n"
        "fn loop(n : Int) : Unit with Msg =\n"
        "    receive {\n"
        "        Crash -> fault(Int.toString(n))\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop(n) }\n"
        "    }\n"
        "fn count() : Unit with Msg = {\n"
        "    Io.println(\"start\");\n"
        "    loop(1)\n"
        "}\n"
        ++ ?UP ++
        "export fn main() : Unit with MainMsg = {\n"
        "    let limit = RestartLimit(restarts = " ++ Restarts ++ ", within = 60000);\n"
        "    let s = spawnMonitored(Local, restarting(limit, count), Died);\n"
        "    let _ = up(s);\n"
        "    send(s, Crash);\n"
        "    if up(s) then send(s, Crash) else Unit;\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(c), site = _)) -> Io.println(\"ended \" <> c)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    };\n"
        "    receive { Died(_) -> Io.println(\"twice\") | after 100 -> Unit }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"start\nstart\nended 1\n">>}, run(Program("1"))),
    ?assertEqual({ok, <<"start\nended 1\n">>}, run(Program("0"))),
    ?assertEqual({ok, <<"start\nended 1\n">>}, run(Program("-2"))).

%% report §6.9: `Unlimited` runs the function again after every fault, and a
%% time of 0 is a window of one millisecond, which a loop that faults at
%% once passes. A regression test: a time of 0 set no limit, and the loop
%% ran for good
restart_unlimited_test_() ->
    {timeout, 30, fun restart_unlimited/0}.

restart_unlimited() ->
    Program = fun(Limit, Body, Crashes) ->
        "type Msg = Crash | Stop | Ping(reply : Reply(Unit))\n"
        "type MainMsg = Died(Down)\n"
        "fn loop() : Unit with Msg =\n"
        "    receive {\n"
        "        Crash -> fault(\"crash\")\n"
        "      | Stop -> Unit\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop() }\n"
        "    }\n"
        "fn boom() : Unit with Msg = fault(\"boom\")\n"
        ++ ?UP ++
        "fn crash(s : Address(Msg), left : Int) : Unit with m =\n"
        "    if left == 0 || !up(s) then Unit else { send(s, Crash); crash(s, left - 1) }\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let s = spawnMonitored(Local, restarting(" ++ Limit ++ ", " ++ Body ++ "), Died);\n"
        "    crash(s, " ++ Crashes ++ ");\n"
        "    if up(s) then send(s, Stop) else Unit;\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"Returned\n">>}, run(Program("Unlimited", "loop", "50"))),
    ?assertEqual({ok, <<"Fault(\"boom\")\n">>},
                 run(Program("RestartLimit(restarts = 3, within = 0)", "boom", "0"))).

%% report §6.9, §6.6: a restart empties the mailbox, so a plain send and
%% the request of a call the restart ended, both waiting there as the
%% process faulted, are not taken by the new run: the ended call was not
%% done. A regression test: the new run took both, and the total was 6
restart_empties_the_mailbox_test() ->
    {ok, Out} = run(
        "type Msg = Add(n : Int, reply : Reply(Int)) | Total(reply : Reply(Int)) | Plain(Int)"
        " | Busy\n"
        "fn count(total : Int) : Unit with Msg =\n"
        "    receive {\n"
        "        Add(n = n, reply = r) -> { answer(r, total + n); count(total + n) }\n"
        "      | Total(reply = r) -> { answer(r, total); count(total) }\n"
        "      | Plain(n) -> count(total + n)\n"
        "      | Busy -> { spin(Clock.monotonic() + 200); fault(\"busy\") }\n"
        "    }\n"
        "fn spin(until : Int) : Unit with m =\n"
        "    if Clock.monotonic() >= until then Unit else spin(until)\n"
        "export fn main() : Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(Local, restarting(limit, fn() = count(0)));\n"
        "    send(s, Busy);\n"
        "    send(s, Plain(5));\n"
        "    Io.println(Io.show(Address.call(s, fn(r) = Add(n = 1, reply = r), 2000)));\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Total(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"None\n0\n">>, Out).

%% report §6.9, Appendix E.15, E.21: a restart cancels the process's alarm,
%% its monitor and its subscription to faults, so the new run hears nothing
%% of what the old one asked for. A regression test: the alarm, the Down
%% and the fault reached the new run
restart_cancels_what_it_asked_for_test_() ->
    {timeout, 30, fun restart_cancels_what_it_asked_for/0}.

restart_cancels_what_it_asked_for() ->
    Program = fun(Ask, After) ->
        "type Msg = Heard | Ask(Address(Int)) | Crash | Ping(reply : Reply(Unit))"
        " | Count(reply : Reply(Int))\n"
        "fn loop(n : Int) : Unit with Msg =\n"
        "    receive {\n"
        "        Heard -> loop(n + 1)\n"
        "      | Ask(other) -> { " ++ Ask ++ "; loop(n) }\n"
        "      | Crash -> fault(\"crash\")\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop(n) }\n"
        "      | Count(reply = r) -> { answer(r, n); loop(n) }\n"
        "    }\n"
        ++ ?UP ++
        "export fn main() : Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(Local, restarting(limit, fn() = loop(0)));\n"
        "    let other = spawn(Local, fn() : Unit with Int = receive { _ -> Unit });\n"
        "    send(s, Ask(other));\n"
        "    send(s, Crash);\n"
        "    let _ = up(s);\n"
        "    " ++ After ++ ";\n"
        "    receive { after 300 -> Unit };\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Count(reply = r))))\n"
        "}\n"
    end,
    %% an alarm set by the old run
    ?assertEqual({ok, <<"0\n">>}, run(Program("Clock.alarm(100, fn(_) = Heard)", "Unit"))),
    %% a monitor made by the old run, of a process killed after the restart
    ?assertEqual({ok, <<"0\n">>}, run(Program("monitor(other, fn(_) = Heard)", "kill(other)"))),
    %% a subscription to faults, and a fault after the restart
    ?assertEqual({ok, <<"0\n">>},
                 run(Program("Process.faults(fn(_) = Heard)",
                             "let _ = spawn(Local, fn() : Unit with Never = fault(\"other\"))"))).

%% Appendix E.22, report §6.9: a child's fault is counted by its supervisor
%% before the child runs again, so a limit of two restarts lets the child
%% run three times; and under `Unlimited` the supervisor never gives up. A
%% regression test: the child restarted itself and told the supervisor
%% after, running about two hundred times under a limit of two, and a time
%% of 0, which set no limit then, still gave up
supervisor_counts_before_the_restart_test_() ->
    {timeout, 60, fun supervisor_counts_before_the_restart/0}.

supervisor_counts_before_the_restart() ->
    Program = fun(Limit) ->
        "type CounterMsg = Next(reply : Reply(Int))\n"
        "type MainMsg = SupDied(Down) | ChildEnded(Down)\n"
        "fn counter(n : Int) : Unit with CounterMsg =\n"
        "    receive { Next(reply = r) -> { answer(r, n); counter(n + 1) } }\n"
        "fn crash(c : Address(CounterMsg)) : Unit with Int = {\n"
        "    let n = Address.callForever(c, fn(r) = Next(reply = r));\n"
        "    Io.println(\"run \" <> Int.toString(n));\n"
        "    if n < 6 then fault(\"boom\") else Unit\n"
        "}\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let c = spawn(Local, fn() = counter(1));\n"
        "    let limit = " ++ Limit ++ ";\n"
        "    let sup = spawnMonitored(Local, Supervisor.group(Supervisor.OneForOne, limit),\n"
        "                             SupDied);\n"
        "    let _ = spawnMonitored(Local, Supervisor.child(sup, fn() = crash(c)), ChildEnded);\n"
        "    receive {\n"
        "        SupDied(Down(reason = Fault(cause), site = _)) -> Io.println(cause)\n"
        "      | SupDied(_) -> Io.println(\"supervisor ended\")\n"
        "      | ChildEnded(_) -> Io.println(\"kept\")\n"
        "    }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nsupervisor restart limit reached\n">>},
                 run(Program("RestartLimit(restarts = 2, within = 60000)"))),
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nrun 4\nrun 5\nrun 6\nkept\n">>},
                 run(Program("Unlimited"))).

%% Appendix E.22: the child whose fault restarts its siblings runs again
%% once each of them has restarted, so that a call to it after its fault is
%% answered by the group restarted whole. The sibling spins when the fault
%% comes and takes its restart at its next wait. A regression test: the
%% faulted child ran again at once, and a call to the sibling made after it
%% had answered was still waiting when the sibling restarted, and ended
supervisor_restarts_whole_test_() ->
    {timeout, 30, fun supervisor_restarts_whole/0}.

supervisor_restarts_whole() ->
    {ok, Out} = run(
        "type AMsg = Crash | Ping(reply : Reply(Int))\n"
        "type BMsg = Inc | Busy | Count(reply : Reply(Int))\n"
        "fn a() : Unit with AMsg =\n"
        "    receive { Crash -> fault(\"crash\") | Ping(reply = r) -> { answer(r, 1); a() } }\n"
        "fn b(n : Int) : Unit with BMsg =\n"
        "    receive {\n"
        "        Inc -> b(n + 1)\n"
        "      | Busy -> { spin(Clock.monotonic() + 300); b(n) }\n"
        "      | Count(reply = r) -> { answer(r, n); b(n) }\n"
        "    }\n"
        "fn spin(until : Int) : Unit with m =\n"
        "    if Clock.monotonic() >= until then Unit else spin(until)\n"
        "fn ping(x : Address(AMsg)) : Int with m =\n"
        "    match Address.call(x, fn(r) = Ping(reply = r), 1000) {\n"
        "        Some(v) -> v\n"
        "      | None -> ping(x)\n"
        "    }\n"
        "export fn main() : Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let sup = spawn(Local, Supervisor.group(Supervisor.OneForAll, limit));\n"
        "    let x = spawn(Local, Supervisor.child(sup, a));\n"
        "    let y = spawn(Local, Supervisor.child(sup, fn() = b(0)));\n"
        "    send(y, Inc);\n"
        "    let _ = Address.callForever(y, fn(r) = Count(reply = r));\n"
        "    let _ = ping(x);\n"
        "    send(y, Busy);\n"
        "    send(x, Crash);\n"
        "    let _ = ping(x);\n"
        "    Io.println(Io.show(Address.call(y, fn(r) = Count(reply = r), 2000)))\n"
        "}\n"),
    ?assertEqual(<<"Some(0)\n">>, Out).

%% report §6.9: returning and a kill end a restarting process as they end
%% any; only a fault restarts
restart_only_on_fault_test() ->
    {ok, Out} = run(
        "type Msg = Stop\n"
        "type MainMsg = Died(Down)\n"
        "fn waits() : Unit with Msg = receive { Stop -> Unit }\n"
        "export fn main() : Unit with MainMsg = {\n"
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
    Faulty = "fn faulty() : Unit with Msg = receive {\n"
             "    Ask(reply = r) -> { fault(\"bad request\"); answer(r, 1) }\n"
             "  | Stop -> Unit\n"
             "}\n",
    Ask = "fn(r) = Ask(reply = r)",
    Forever = fun(Setup) ->
        Types ++ Faulty ++
        "fn waits() : Unit with Msg = receive { Stop -> Unit }\n"
        "fn quiet() : Unit with Msg = receive { Ask(reply = r) -> "
        "receive { after 60000 -> answer(r, 1) } | Stop -> Unit }\n"
        "export fn main() : Unit with MainMsg = {\n" ++ Setup ++
        "    Io.println(Int.toString(Address.callForever(s, " ++ Ask ++ ")))\n"
        "}\n"
    end,
    ?assertMatch({{fault, <<"bad request">>}, _},
                 run(Forever("    let s = spawn(Local, faulty);\n"))),
    ?assertMatch({{fault, <<"callee was killed">>}, _},
                 run(Forever("    let s = spawn(Local, quiet);\n"
                             "    let _ = spawn(Local, fn() : Unit with Never =\n"
                             "        receive { after 50 -> kill(s) });\n"))),
    ?assertMatch({{fault, <<"callee returned without answering">>}, _},
                 run(Forever("    let s = spawn(Local, waits);\n"
                             "    let _ = spawn(Local, fn() : Unit with Never =\n"
                             "        receive { after 50 -> send(s, Stop) });\n"))),
    ?assertMatch({{fault, <<"callee had ended">>}, _},
                 run(Forever("    let s = spawnMonitored(Local, fn() : Unit with Msg = Unit,\n"
                             "        Died);\n"
                             "    receive { Died(_) -> Unit };\n"))),
    ?assertMatch({{fault, <<"bad request">>}, _},
                 run(Forever("    let limit = RestartLimit(restarts = 5, within = 60000);\n"
                             "    let s = spawn(Local, restarting(limit, faulty));\n"))),
    {ok, Out} = run(Types ++ Faulty ++
                    "export fn main() : Unit with MainMsg = {\n"
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
        "fn logger(n : Int) : Unit with LogMsg = receive {\n"
        "    Log(_) -> logger(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Count(reply = r) -> { answer(r, n); logger(n) }\n"
        "}\n"
        "export let log : Address(LogMsg) = spawn(Local,\n"
        "    restarting(RestartLimit(restarts = 3, within = 60000),\n"
        "        fn() : Unit with LogMsg = logger(0)))\n"
        "let started = Io.println(\"started\")\n"
        "fn note(s : String) : Unit with m = send(log, Log(s))\n"
        "export fn main() : Unit with Never = {\n"
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
        "    spawn(Local, fn() : Unit with Int = receive { _ -> fault(\"x\") })\n"
        "export fn main() : Unit with MainMsg = {\n"
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
                    "export fn main() : Unit with Msg = {\n"
                    "    let before = Clock.now();\n"
                    "    Clock.alarm(5, Tick);\n"
                    "    receive { Tick(at) -> Io.println(Bool.toString(at >= before)) }\n"
                    "}\n"),
    ?assertEqual(<<"true\n">>, Out).

%% report §5.9, §6.3: alternatives in a receive clause select either message
receive_or_pattern_test() ->
    {ok, Out} = run(
        "type Msg = Inc(Int) | Dec(Int) | Stop\n"
        "fn loop(n : Int) : Int with Msg = receive {\n"
        "    Inc(k) or Dec(k) -> loop(n + k)\n"
        "  | Stop -> n\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
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
        "fn loop(acc : Int) : Unit with Msg = receive {\n"
        "    N(k) when k > 0 -> loop(acc + k)\n"
        "  | N(_) -> Io.println(Int.toString(acc))\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn loop(limit : Int) : Unit with Msg = receive {\n"
        "    N(k) when k > limit && k != 7 -> { Io.println(Int.toString(k)); loop(limit) }\n"
        "  | Stop -> Unit\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
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
        "fn take(flag : Bool) : Int with Msg = receive {\n"
        "    N(k) when !flag && !(k > 5) && k > -3 -> k\n"
        "  | Stop -> 100\n"
        "}\n"
        "fn negative() : Int with Msg = receive { N(k) when k < -1 -> k }\n"
        "export fn main() : Unit with Msg = {\n"
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
        "fn size(n : Int) : String = match n { m when m > limit -> \"big\" | _ -> \"small\" }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(size(9));\n"
        "    Io.println(size(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Out).

%% report §3.1, §4.8, §9.6: Int arithmetic, comparison, and the Boolean
%% operators
operators_test() ->
    {ok, Out} = run(
        "export fn main() : Unit with Never = {\n"
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
        "export fn main() : Unit with Never = {\n"
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
    Zero = "fn zero() : Float = Int.toFloat(List.size([]))\n",
    {R1, _} = run(Zero ++ "export fn main() : Unit with Never = "
                  "Io.println(Float.toString(1.0 / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R1),
    {R2, _} = run(Zero ++ "export fn main() : Unit with Never = "
                  "Io.println(Float.toString((zero() + 1.0e308) * 10.0))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R2),
    {R3, _} = run(Zero ++ "export fn main() : Unit with Never = "
                  "Io.println(Float.toString(zero() / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R3),
    %% an Int zero divisor inside a Float operand keeps its own cause
    {R4, _} = run("fn n() : Int = List.size([])\n"
                  "export fn main() : Unit with Never = "
                  "Io.println(Float.toString(Int.toFloat(1 / n()) + 1.0))\n"),
    ?assertEqual({fault, <<"division by zero">>}, R4),
    %% Float.+ taken as a value faults the same way
    {R5, _} = run("export fn main() : Unit with Never = "
                  "Io.println(Float.toString(List.foldLeft([1.0e308, 1.0e308], 0.0, Float.+)))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, R5).

%% report §3.1: there is no negative zero; an operation, a negation, a
%% float segment, parsed text, and a foreign value give 0.0
no_negative_zero_test() ->
    {ok, Out} = run(
        "foreign fn parse(s : String) : Float = \"erlang:binary_to_float/1\"\n"
        "fn tiny() : Float = 1.0e-300\n"
        "export fn main() : Unit with Never = {\n"
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
        "    let _ = match b { <<x:size(64)-float>> -> { fn g() : Float = x; Io.debug(g()) }"
        " | _ -> 1.0 };\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(0.0, 0.0, 0.0, 0.0)\ntrue\n1\n0.0\n\"zero\"\nSome(0.0)\n0.0\n"
                   "\"guard\"\n0.0\n">>, Out).

%% report §5.1: a callee is evaluated before its arguments; in `x |> e`,
%% x is evaluated before e, whether e is a call or a parenthesized value
evaluation_order_test() ->
    {ok, Out} = run(
        "fn show(s : String, n : Int) : Int with Never = { Io.println(s); n }\n"
        "fn f(a : Int) : ((Int, Int) -> Int) with Never = {\n"
        "    Io.println(\"f(a)\");\n"
        "    fn(x, y) = x + y + a\n"
        "}\n"
        "fn g(a : Int) : ((Int) -> Int) with Never = { Io.println(\"g(1)\"); fn(x) = x + a }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(show(\"x\", 1) |> f(show(\"a\", 2))(show(\"b\", 3))));\n"
        "    Io.println(Int.toString(g(1)(show(\"h()\", 4))));\n"
        "    Io.println(Int.toString(show(\"y\", 5) |> (g(1))))\n"
        "}\n"),
    ?assertEqual(<<"x\na\nf(a)\nb\n6\ng(1)\nh()\n5\ny\ng(1)\n6\n">>, Out).

%% report §4.8: `!` negates a Bool, in an expression and in a guard
not_operator_test() ->
    {ok, Out} = run(
        "fn small(n : Int) : String = match n { m when !(m > 5) -> \"small\" | _ -> \"big\" }\n"
        "export fn main() : Unit with Never = {\n"
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
          "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) : Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = Int.compare(b, a)\n"
          "export fn Vec.negate(Vec(a)) : Vec = Vec(-a)\n"
          "fn show(Vec(n)) : String = Int.toString(n)\n",
    {ok, Out} = run(Vec ++
        "export fn main() : Unit with Never = {\n"
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
        "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec((a + b) * scale)\n"
        "let scale = 10\n"
        "fn show(Vec(n)) : String = Int.toString(n)\n"
        "export fn main() : Unit with Never = Io.println(show(sum))\n"),
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
        "export fn main() : Unit with Never = Io.println(Int.toString(a + c + d))\n"),
    ?assertEqual(<<"a\nb\nc\nd\n8\n">>, Out).

%% report §4.7, §8.4: a foreign fn calls its implementation with the
%% arguments as the ABI maps them, and a foreign type's values pass through
%% unchecked
foreign_fn_test() ->
    {ok, Out} = run(
        "foreign type Table\n"
        "foreign fn size(s : String) : Int = \"erlang:byte_size/1\"\n"
        "foreign fn atom(s : String) : Foreign = \"erlang:binary_to_atom/1\"\n"
        "foreign fn newTable(n : Foreign, o : List(Foreign)) : Table with m = \"ets:new/2\"\n"
        "foreign fn insert(t : Table, row : #(Int, String)) : Bool with m = \"ets:insert/2\"\n"
        "foreign fn lookup(t : Table, k : Int) : List(#(Int, String)) with m = \"ets:lookup/2\"\n"
        "foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) : Foreign with m"
        " = \"lists:foreach/2\"\n"
        "export fn main() : Unit with Never = {\n"
        "    let t = newTable(atom(\"t\"), [atom(\"set\")]);\n"
        "    let _ = insert(t, #(1, \"one\"));\n"
        "    match lookup(t, 1) { [#(_, v)] -> Io.println(v) | _ -> Io.println(\"none\") };\n"
        "    Io.println(Int.toString(size(\"abc\")));\n"
        "    let _ = each(fn(n : Int) : Unit with Never = Io.println(Int.toString(n)), [1, 2]);\n"
        "    let f = size;\n"
        "    Io.println(Int.toString(List.foldLeft(List.map([\"a\", \"bb\"], f), 0, Int.+)))\n"
        "}\n"),
    ?assertEqual(<<"one\n3\n1\n2\n3\n">>, Out).

%% report §4.7, §8.4: a foreign return whose type holds the same user type
%% twice, side by side, is checked; each is described in full
foreign_sibling_types_test() ->
    {ok, Out} = run(
        "foreign fn pair(xs : List(Optional(Int))) : #(Optional(Int), Optional(Int))"
        " = \"erlang:list_to_tuple/1\"\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = Io.debug(pair([Some(1), None]));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(Some(1), None)\n">>, Out).

%% report §4.7, §7.4, §8.4: a return of another shape faults on first
%% observation, naming the declared type; a nested breach is found; an
%% exception is a fault naming the implementation; an Ernest fault raised
%% inside foreign code passes through as itself
foreign_faults_test() ->
    Main = "export fn main() : Unit with Never = ",
    {R1, _} = run("foreign fn bad() : Int = \"erlang:node/0\"\n"
                  ++ Main ++ "Io.println(Int.toString(bad()))\n"),
    ?assertEqual({fault, <<"foreign return does not match Int">>}, R1),
    {R2, _} = run("foreign fn pair() : #(Int, String) = \"ern_emitter_tests:pair/0\"\n"
                  ++ Main ++ "{ let #(_, s) = pair(); Io.println(s) }\n"),
    ?assertEqual({fault, <<"foreign return does not match #(Int, String)">>}, R2),
    {R3, _} = run("foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                  ++ Main ++ "match opt(1) { Some(n) -> Io.println(Int.toString(n))"
                  " | None -> Io.println(\"none\") }\n"),
    ?assertEqual({fault, <<"foreign return does not match Optional(Int)">>}, R3),
    {ok, Out} = run("foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                    ++ Main ++ "match opt(0) { Some(n) -> Io.println(Int.toString(n))"
                    " | None -> Io.println(\"none\") }\n"),
    ?assertEqual(<<"3\n">>, Out),
    {R4, _} = run("foreign fn boom(x : Int) : Int = \"erlang:error/1\"\n"
                  ++ Main ++ "Io.println(Int.toString(boom(7)))\n"),
    %% report §11.2: the raise carries the host's stack beside its cause
    ?assertMatch({fault, <<"foreign function erlang:error/1 raised error:7">>, <<_/binary>>}, R4),
    {R5, _} = run("foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) : Unit with m"
                  " = \"lists:foreach/2\"\n"
                  ++ Main ++ "each(fn(n : Int) : Unit with Never = fault(\"later\"), [1])\n"),
    ?assertEqual({fault, <<"later">>}, R5).

%% report §6.5, §8.4: an address `via` made, given to foreign code and given
%% back, is the address that went out, its function kept. A regression
%% test: the program got the process behind it, and a message sent to it
%% arrived without the function applied, not of the mailbox type
via_address_round_trip_test() ->
    {ok, Out} = run("type Msg = Wrapped(Int)\n"
                    "foreign fn first(xs : List(Address(Int))) : Address(Int) = \"erlang:hd/1\"\n"
                    "export fn main() : Unit with Msg = {\n"
                    "    let back = first([via(Wrapped, self())]);\n"
                    "    send(back, 7);\n"
                    "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                    "}\n"),
    ?assertEqual(<<"7\n">>, Out).

%% report §7.4, §8.4: a fault of the program's own function where foreign
%% code calls it passes through as the fault it would be anywhere, with no
%% foreign function named. A regression test: it took the foreign
%% function's cause, `foreign function lists:foreach/2 raised
%% error:badarith`
callback_fault_passes_through_test() ->
    {R, Out} = run("foreign fn each(f : (a) -> Unit with m, xs : List(a)) : Unit with m ="
                   " \"lists:foreach/2\"\n"
                   "export fn main() : Unit with Never =\n"
                   "    each(fn(n : Int) : Unit with Never = Io.println(Int.toString(10 / n)),"
                   " [2, 0])\n"),
    ?assertEqual({{fault, <<"division by zero">>}, <<"5\n">>}, {R, Out}).

%% report §6.9, §8.4: a restart asked for while foreign code calls the
%% program's function is a restart, the cause of the new start `Asked`. A
%% regression test: it was a fault of the foreign function, and the process
%% restarted after a fault
callback_restart_passes_through_test() ->
    {ok, Out} = run(
        "type Start = First | Asked | AfterFault\n"
        "foreign fn startCause() : Start with m = \"ern_rt:start_cause/0\"\n"
        "foreign fn askRestart(child : Process) : Bool with m = \"ern_rt:ask_restart/1\"\n"
        "foreign fn each(f : (a) -> Unit with m, xs : List(a)) : Unit with m ="
        " \"lists:foreach/2\"\n"
        "export fn main() : Unit with String = {\n"
        "    let me = self();\n"
        "    let body = fn() : Unit with Never = {\n"
        "        let cause = startCause();\n"
        "        send(me, Io.show(cause));\n"
        "        match cause {\n"
        "            First -> each(fn(_ : Int) : Unit with Never = {\n"
        "                let _ = askRestart(Process.fromAddress(self()));\n"
        "                receive { after 5000 -> Unit }\n"
        "            }, [1])\n"
        "          | _ -> Unit\n"
        "        }\n"
        "    };\n"
        "    let _ = spawn(Local, restarting(Unlimited, body));\n"
        "    receive { s -> Io.println(s) };\n"
        "    receive { s -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"First\nAsked\n">>, Out).

%% report §3.1, §5.10: there is no negative zero, so the pattern `-0.0`
%% matches the zero, however it was made. A regression test: the pattern
%% was the host's negative zero, which no value matched
negative_zero_pattern_test() ->
    {ok, Out} = run("fn kind(x : Float) : String = match x {\n"
                    "    -0.0 -> \"zero\"\n"
                    "  | _ -> \"other\"\n"
                    "}\n"
                    "export fn main() : Unit with Never = {\n"
                    "    Io.println(kind(0.0));\n"
                    "    Io.println(kind(-0.0));\n"
                    "    Io.println(kind(0.0 * -1.0))\n"
                    "}\n"),
    ?assertEqual(<<"zero\nzero\nzero\n">>, Out).

%% report §8.4: a type variable a parameter names may stand in the result
%% more than once. A regression test: only its first place was taken as
%% named, the second was checked as matching no value, and every return
%% faulted
foreign_result_names_a_variable_twice_test() ->
    {ok, Out} = run("foreign fn pair(n : Int, x : a) : #(a, a) = \"erlang:make_tuple/2\"\n"
                    "export fn main() : Unit with Never = {\n"
                    "    let _ = Io.debug(pair(2, \"x\"));\n"
                    "    Unit\n"
                    "}\n"),
    ?assertEqual(<<"#(\"x\", \"x\")\n">>, Out).

%% report §7.4, §8.4: a List is a proper list, so an improper one a foreign
%% function returns faults naming the declared type, whether its elements
%% are checked or a parameter's type variable names them. A regression test:
%% the check raised function_clause instead. It does not cover what a check
%% costs, which make bench shows.
foreign_improper_list_test() ->
    Main = "export fn main() : Unit with Never = ",
    {R1, _} = run("foreign fn improper(x : Int) : List(Int) = \"ern_emitter_tests:improper/1\"\n"
                  ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual({fault, <<"foreign return does not match List(Int)">>}, R1),
    {R2, _} = run("foreign fn improper(x : a) : List(a) = \"ern_emitter_tests:improper/1\"\n"
                  ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual({fault, <<"foreign return does not match List(a)">>}, R2).

%% report §7.4: a function value foreign code returns is checked when it is
%% called, its result against its declared result type, in the caller, and
%% one that keeps to it runs. A regression test: such a function's result
%% was never checked, so an ill-typed one reached Ernest code unchecked.
foreign_function_value_test() ->
    Source = "foreign fn funs() : List((Int) -> Int) = \"ern_emitter_tests:funs/0\"\n"
             "export fn main() : Unit with Never = match funs() {\n"
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
                    "foreign fn remember(a : Address(Msg)) : Bool with m ="
                    " \"ern_emitter_tests:remember/1\"\n"
                    "export fn main() : Unit with Msg = {\n"
                    "    let _ = remember(self());\n"
                    "    let again = remember(self());\n"
                    "    Io.println(if again then \"same\" else \"another\")\n"
                    "}\n"),
    ?assertEqual(<<"same\n">>, Out),
    persistent_term:erase({?MODULE, proxy_seen}).

%% report §3.10, §3.8: a foreign type's equality is the host's, of the
%% terms: a reference equals itself and not another, and two values that
%% are the same term are equal. `Foreign` has none, which the checker's
%% tests hold. A regression test, written after the code; it does not
%% cover a foreign value that holds a function
foreign_equality_test() ->
    {ok, Out} = run(
        "foreign type Ref\n"
        "foreign fn makeRef() : Ref with m = \"erlang:make_ref/0\"\n"
        "foreign fn same(x : Int) : Ref = \"erlang:abs/1\"\n"
        "export fn main() : Unit with m = {\n"
        "    let a = makeRef();\n"
        "    let b = makeRef();\n"
        "    let _ = Io.debug(#(a == a, a == b, same(1) == same(-1), same(1) == same(2)));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(true, false, true, false)\n">>, Out).

%% report §6.3: a receive guard reads a top-level `let`, in a receive with
%% and without an `after`, the value read before the receive waits. A
%% regression test, written with the rule
receive_guard_reads_top_level_test() ->
    {ok, Out} = run(
        "type Msg = Tick(Int)\n"
        "let limit = 10\n"
        "fn first() : Int with Msg = receive { Tick(k) when k > limit -> k }\n"
        "fn timed() : Int with Msg =\n"
        "    receive {\n"
        "        Tick(k) when k > limit -> k\n"
        "      | after 1000 -> 0\n"
        "    }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let me = self();\n"
        "    send(me, Tick(3));\n"
        "    send(me, Tick(20));\n"
        "    send(me, Tick(30));\n"
        "    let _ = Io.debug(#(first(), timed()));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(20, 30)\n">>, Out).

%% report §8.4, §7.4: an address given to foreign code is a proxy that
%% checks each message on delivery, a bad one faulting the target even
%% when no clause would bind it; a good one arrives, also from inside a
%% list; a reply is checked by the call that observes it
foreign_messages_test() ->
    Junk = "foreign fn junk(a : Address(Msg)) : Unit with m = \"ern_emitter_tests:junk/1\"\n",
    {R1, _} = run("type Msg = Go(Int)\n" ++ Junk ++
                  "export fn main() : Unit with Msg = {\n"
                  "    junk(self());\n"
                  "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                  "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, R1),
    {R0, _} = run("type Msg = Go(Int) | Stop\n" ++ Junk ++
                  "export fn main() : Unit with Msg = {\n"
                  "    junk(self());\n"
                  "    receive { Stop -> Unit }\n"
                  "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, R0),
    {ok, Out} = run("type Msg = Go(Int)\n"
                    "foreign fn good(a : Address(Msg)) : Unit with m ="
                    " \"ern_emitter_tests:good/1\"\n"
                    "foreign fn tell(targets : List(Address(Msg))) : Unit with m"
                    " = \"ern_emitter_tests:tell/1\"\n"
                    "export fn main() : Unit with Msg = {\n"
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
                        "foreign fn good(a : Address(Inner)) : Unit with m ="
                        " \"ern_emitter_tests:good/1\"\n"
                        "export fn main() : Unit with Msg = {\n"
                        "    good(via(fn(Go(n) : Inner) = Wrapped(n), self()));\n"
                        "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                        "}\n"),
    ?assertEqual(<<"1\n">>, Wrapped),
    {R2, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                  "foreign fn server() : Address(Ask) with m ="
                  " \"ern_emitter_tests:junk_server/0\"\n"
                  "export fn main() : Unit with Never = {\n"
                  "    let n = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
                  "    Io.println(Int.toString(n))\n"
                  "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, R2).

%% report §8.4: a function that stands inside a foreign function's argument
%% crosses as one given alone does, each argument foreign code calls it with
%% checked. A regression test: only a parameter that was itself a function
%% was wrapped, and the bad argument faulted inside the function
%% (findings.md's C2-7)
nested_function_checked_test() ->
    Source = fun(Name) ->
                 "foreign fn call(p : #(Int, (Int) -> Int)) : Int with m = \"ern_emitter_tests:"
                 ++ Name ++ "/1\"\n"
                 "export fn main() : Unit with Never =\n"
                 "    Io.println(Int.toString(call(#(4, fn(n) = n * 2))))\n"
             end,
    ?assertEqual({fault, <<"foreign argument does not match Int">>},
                 element(1, run(Source("call_nested_bad")))),
    ?assertEqual({ok, <<"8\n">>}, run(Source("call_nested_good"))).

%% report §8.4: an address sent in a message to a foreign address crosses
%% into foreign code, so a bad message foreign code sends it back faults the
%% receiver on delivery, and a good one arrives. A regression test: only a
%% foreign function's arguments crossed, and the bad message was delivered
%% unchecked, its binary bound where an Int was declared
foreign_address_message_test() ->
    Source = fun(Server) ->
                 "type Msg = Go(Int)\n"
                 "type Out = Hello(Address(Msg))\n"
                 "foreign fn start() : Address(Out) with m = \"ern_emitter_tests:" ++ Server
                 ++ "/0\"\n"
                 "export fn main() : Unit with Msg = {\n"
                 "    send(start(), Hello(self()));\n"
                 "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                 "}\n"
             end,
    ?assertEqual({fault, <<"message does not match Msg">>}, element(1, run(Source("hello_junk")))),
    ?assertEqual({ok, <<"1\n">>}, run(Source("hello_good"))).

%% report §8.4: foreign code answers a Reply an Ernest process hands on to it
%% in foreign code's form, which the caller checks; a good answer arrives
reply_handed_on_test() ->
    Source = fun(Relay) ->
                 "type Ask = Ask(reply : Reply(Int))\n"
                 "foreign fn relay(r : Reply(Int)) : Unit with m = \"ern_emitter_tests:" ++ Relay
                 ++ "/1\"\n"
                 "fn serve() : Unit with Ask = receive { Ask(reply = r) -> relay(r) }\n"
                 "export fn main() : Unit with Never = {\n"
                 "    let n = Address.callForever(spawn(Local, serve), fn(r) = Ask(reply = r));\n"
                 "    Io.println(Int.toString(n))\n"
                 "}\n"
             end,
    ?assertEqual({fault, <<"reply does not match Int">>}, element(1, run(Source("relay_junk")))),
    ?assertEqual({ok, <<"5\n">>}, run(Source("relay_good"))).

%% report §8.4: a Reply foreign code gives back is held as foreign, so an
%% answer an Ernest process gives it is checked, as foreign code's is: a
%% Reply handed back with another type declared cannot carry an answer of
%% that type to a caller that waits for its own
reply_given_back_test() ->
    {R, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                 "foreign fn same(r : Reply(Int)) : Reply(String) with m ="
                 " \"ern_emitter_tests:same/1\"\n"
                 "fn serve() : Unit with Ask =\n"
                 "    receive { Ask(reply = r) -> answer(same(r), \"x\") }\n"
                 "export fn main() : Unit with Never = {\n"
                 "    let n = Address.callForever(spawn(Local, serve), fn(r) = Ask(reply = r));\n"
                 "    Io.println(Int.toString(n))\n"
                 "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, R).

%% report §8.4: an answer given to a Reply foreign code gave crosses into
%% foreign code, so an address in it reaches foreign code through the
%% proxy, and a bad message foreign code sends there faults its process; a
%% good one arrives. A regression test: the answer went out as it was, and
%% the bad message was delivered unchecked. It does not cover a function
%% in the answer, which crosses as one in a message does
answer_to_foreign_reply_test() ->
    Source = fun(Asker) ->
                 "type Msg = Go(Int)\n"
                 "type Ask = Ask(reply : Reply(Address(Msg)))\n"
                 "foreign fn ask(server : Address(Ask)) : Unit with m = \"ern_emitter_tests:"
                 ++ Asker ++ "/1\"\n"
                 "fn serve(me : Address(Msg)) : Unit with Ask =\n"
                 "    receive { Ask(reply = r) -> answer(r, me) }\n"
                 "export fn main() : Unit with Msg = {\n"
                 "    let me = self();\n"
                 "    ask(spawn(Local, fn() = serve(me)));\n"
                 "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                 "}\n"
             end,
    ?assertEqual({fault, <<"message does not match Msg">>}, element(1, run(Source("ask_junk")))),
    ?assertEqual({ok, <<"1\n">>}, run(Source("ask_good"))).

%% report §8.4: the standard library is the runtime's own, so the return of
%% one of its foreign functions and the reply to a call it makes are not
%% checked; the same declarations in a program's module fault
%% (foreign_faults_test, foreign_messages_test)
standard_library_unchecked_test() ->
    Text = "type Ask = Ask(reply : Reply(Int))\n"
           "foreign fn bad() : Int = \"erlang:node/0\"\n"
           "foreign fn server() : Address(Ask) with m = \"ern_emitter_tests:junk_server/0\"\n"
           "export fn main() : Unit with Never = {\n"
           "    let _ = bad();\n"
           "    let _ = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
           "    Io.println(\"unchecked\")\n"
           "}\n",
    ?assertEqual({ok, <<"unchecked\n">>}, run(['M'], Text, #{standard => true})),
    ?assertEqual({fault, <<"foreign return does not match Int">>}, element(1, run(Text))).

%% The foreign side of the tests above.
pair() -> {1, 2}.
funs() -> [fun(X) -> X + 1 end, fun(_) -> not_an_int end].
opt(0) -> {'Some', 3};
opt(_) -> {'Some', <<"x">>}.
improper(X) -> [X | X].
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
    spawn(fun() -> receive {'Ask', Alias} -> Alias ! {Alias, <<"x">>} end end).
%% report §8.4: a foreign process that answers a Hello with a message to the
%% address it holds, of another type or of the declared one
hello_junk() ->
    spawn(fun() -> receive {'Hello', P} -> P ! {'Go', <<"x">>} end end).
hello_good() ->
    spawn(fun() -> receive {'Hello', P} -> P ! {'Go', 1} end end).
%% report §8.4: foreign code given a Reply answers it as the ABI says
relay_junk(Alias) -> Alias ! {Alias, <<"x">>}, 'Unit'.
relay_good(Alias) -> Alias ! {Alias, 5}, 'Unit'.
%% report §8.4: a Reply handed back as it was given, its type declared anew
same(R) -> R.
%% report §8.4: foreign code that calls the function inside its argument
%% with a value of another type, or of the declared one
call_nested_bad({_, F}) -> F(<<"bad">>).
call_nested_good({N, F}) -> F(N).
%% report §8.4: foreign code that asks an Ernest server with a Reply of its
%% own, and sends the address it is answered a message of another type or
%% of the declared one
ask_junk(Server) -> ask(Server, <<"x">>).
ask_good(Server) -> ask(Server, 1).
ask(Server, N) ->
    spawn(fun() ->
              Alias = erlang:alias(),
              Server ! {'Ask', Alias},
              receive {Alias, P} -> P ! {'Go', N} end
          end),
    'Unit'.

%% report §4.5: an Ernest function named like an auto-imported
%% Erlang BIF, `size`, `max`, is called by its own name
bif_names_test() ->
    {ok, Out} = run(
        "fn max(a : Int, b : Int) : Int = if a > b then a else b\n"
        "fn size(xs : List(Int)) : Int = List.size(xs) * 10\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn two() : Int = 2\n"
        "type Box = Box(Int)\n"
        "fn Box.open(b : Box) : Int = match b { Box(n) -> n }\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn max(a : Int, b : Int) : Int = a - b\n"
        "type Msg = Ping\n"
        "export fn main() : Unit with Msg = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    receive { Ping -> Unit | after 10 -> Io.println(\"after\") }\n"
        "}\n"),
    ?assertEqual(<<"-1\nafter\n">>, Out).

%% report §6.6, §8.4: `Address.call` and `Address.callForever` taken as
%% values answer as the calls do, and check a reply whose Reply crossed into
%% foreign code as the calls do. A regression test: as values they once
%% left the reply unchecked
call_as_value_test() ->
    {ok, Out} = run(
        "type Msg = Get(reply : Reply(Int))\n"
        "fn serve() : Unit with Msg = receive { Get(reply = r) -> answer(r, 7) }\n"
        "export fn main() : Unit with Never = {\n"
        "    let c : (Address(Msg), (Reply(Int)) -> Msg, Int) -> Optional(Int) with Never =\n"
        "        Address.call;\n"
        "    let w : (Address(Msg), (Reply(Int)) -> Msg) -> Int with Never =\n"
        "        Address.callForever;\n"
        "    let asked = c(spawn(Local, serve), fn(r) = Get(reply = r), 1000);\n"
        "    let n = Optional.withDefault(asked, 0);\n"
        "    Io.println(Int.toString(n + w(spawn(Local, serve), fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"14\n">>, Out),
    {R, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                 "foreign fn server() : Address(Ask) with m = \"ern_emitter_tests:junk_server/0\"\n"
                 "export fn main() : Unit with Never = {\n"
                 "    let w : (Address(Ask), (Reply(Int)) -> Ask) -> Int with Never =\n"
                 "        Address.callForever;\n"
                 "    Io.println(Int.toString(w(server(), fn(r) = Ask(reply = r))))\n"
                 "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, R).

%% report §5.11, §6.3: a pattern's size names a top-level `let`, which the
%% `match` or the `receive` reads before it begins. A regression test: the
%% checker refused it, the host's pattern showing through
bitstring_size_reads_a_top_level_let_test() ->
    {ok, Out} = run(
        "type Msg = Packet(Bytes)\n"
        "let headerSize = 2\n"
        "fn header(b : Bytes) : Optional(Bytes) = match b {\n"
        "    <<h:size(headerSize)-bytes, _:bytes>> -> Some(h)\n"
        "  | _ -> None\n"
        "}\n"
        "fn take() : Optional(Bytes) with Msg = receive {\n"
        "    Packet(<<h:size(headerSize * 2)-bytes, _:bytes>>) -> Some(h)\n"
        "  | Packet(_) -> None\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
        "    Io.println(Io.show(#(header(<<1, 2, 3>>), header(<<1>>))));\n"
        "    send(self(), Packet(<<1, 2, 3, 4, 5>>));\n"
        "    Io.println(Io.show(take()))\n"
        "}\n"),
    ?assertEqual(<<"#(Some(<<1, 2>>), None)\nSome(<<1, 2, 3, 4>>)\n">>, Out).

%% report §5.1, §5.11: a match evaluates its scrutinee before it reads a
%% top-level `let` a pattern's size names. The module runs without its
%% initializers, so the read faults, and what the scrutinee printed shows
%% that it came first. A regression test: the read came before the
%% scrutinee, against §5.1's left to right
size_read_after_scrutinee_test() ->
    Text = "let width = 1\n"
           "fn first(b : Bytes) : Bytes with Never = match Io.debug(b) {\n"
           "    <<h:size(width)-bytes, _:bytes>> -> h\n"
           "  | _ -> b\n"
           "}\n"
           "export fn main() : Unit with Never = {\n"
           "    let _ = first(<<7, 8>>);\n"
           "    Unit\n"
           "}\n",
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'], Text),
    Build = #{source_hash => <<>>, deps => [], standard => false},
    {ok, Mod, Bin} = ern_emitter:compile(['M'], Typed, Iface, Env, Build),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    Result = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                             #{init => fun() -> ok end, stdout => fun(B) -> Me ! {out, B} end,
                               stdin => fun() -> eof end}),
    ?assertNotEqual(ok, Result),
    ?assertEqual(<<"<<7, 8>>\n">>, collect([])).

%% report §5.11: the report's frame round trip, sub-octet fields, utf8,
%% float and signed and little segments, a dynamic size in a pattern, and
%% an unaligned rest that fails the match
bitstrings_test() ->
    {ok, Out} = run(
        "fn frame(len : Int, body : Bytes) : Bytes = <<len:size(16)-big, body:bytes>>\n"
        "fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) = match bytes {\n"
        "    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))\n"
        "  | _ -> None\n"
        "}\n"
        "fn show(b : Bytes) : String = match b {\n"
        "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn nibbles(b : Bytes) : String = match b {\n"
        "    <<hi:size(4), lo:size(4), rest:bytes>> ->"
        " Int.toString(hi) <> \":\" <> Int.toString(lo) <> \" \" <> nibbles(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) : String = match b {\n"
        "    <<_:size(n)-bytes, rest:bytes>> -> show(rest)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
        "    Io.println(tail(1, <<1, 2>>));\n"
        "    Io.println(tail(3, <<1, 2>>));\n"
        "    Io.println(show(<<(String.toUtf8(\"hi\")):bytes, 3:size(4), 4:size(4)>>))\n"
        "}\n"),
    ?assertEqual(<<"0 1 65 66 \n1: 65 | 66 \nnone\né\n1:15 2:10 \n63 192 0 0 255 2 1 \n2 \nno\n"
                   "104 105 52 \n"/utf8>>, Out).

%% report §7.4, §5.11: a computed value that does not fit its width faults
%% with segment overflow, an Int, a Float, a Bytes of another size; a
%% dynamic size that leaves the count unaligned faults at construction
bitstring_faults_test() ->
    Main = "export fn main() : Unit with Never = ",
    Three = "fn three() : Int = List.size([1, 2, 3])\n",
    Faults = [{"<<(299 + 1):size(8)>>", <<"segment overflow">>},
              {"<<(0 - 129):size(8)-signed>>", <<"segment overflow">>},
              {"<<(1.0e300 * 1.0):size(32)-float>>", <<"segment overflow">>},
              {"<<(<<1, 2, 3>>):size(2)-bytes>>", <<"segment overflow">>},
              {"<<7:size(three())>>", <<"bitstring not byte-aligned">>}],
    lists:foreach(fun({Bits, Cause}) ->
                      {R, _} = run(Three ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({fault, Cause}, R)
                  end, Faults).

%% report §5.11: a bare segment is an unsigned big-endian int of size 8;
%% a sized int is big-endian; `signed` alone is 8 bits. A regression test,
%% written after the code; it does not cover `little` or a pattern with a
%% signed segment
bitstring_defaults_test() ->
    Show = "fn show(b : Bytes) : String = match b {\n"
           "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
           "  | _ -> \"\"\n"
           "}\n",
    {ok, Out} = run(Show ++
        "export fn main() : Unit with Never = {\n"
        "    Io.println(show(<<258:size(16)>>));\n"
        "    Io.println(match <<255>> { <<x>> -> Int.toString(x) | _ -> \"no\" });\n"
        "    Io.println(show(<<-1:signed>>))\n"
        "}\n"),
    ?assertEqual(<<"1 2 \n255\n255 \n">>, Out),
    {R, _} = run("export fn main() : Unit with Never = { let n = 0 - 1; let _ = <<n>>; Unit }\n"),
    ?assertEqual({fault, <<"segment overflow">>}, R).

%% report §8.5: top-level lets run in the order the checker found, a let
%% after every let it reaches through the functions it names, whatever the
%% order they are declared in. A regression test for the order the emitter
%% now reads rather than computing again; the order it had was the same.
initialization_order_test() ->
    {ok, Out} = run("let total = twice() + 1\n"
                    "fn twice() : Int = base * 2\n"
                    "let base = 10\n"
                    "export fn main() : Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"21\n">>, Out).

%% report §4.2: a name shadowed at each step of the lookup order compiles
%% to the declaration the checker resolved it to, which the emitter reads
%% from the name's `ref` rather than resolving again: a type's member, the
%% module's own function over the prelude's `self`, the module named
%% qualified, `Prelude.self`, and a local binding over them all. A
%% regression test for the single decision; the order it had was the same.
lookup_order_test() ->
    {ok, Out} = run("type Box = Box(Int)\n"
                    "fn Box.value(b : Box) : Int = match b { Box(n) -> n }\n"
                    "fn value(b : Box) : Int = 100\n"
                    "fn self() : Int = 5\n"
                    "export fn main() : Unit with Never = {\n"
                    "    let me = Prelude.self();\n"
                    "    let first = Box.value(Box(1)) + value(Box(1)) + self() + M.self();\n"
                    "    let value = fn(b : Box) : Int = 1000;\n"
                    "    Io.println(Int.toString(first + value(Box(1))))\n}\n"),
    ?assertEqual(<<"1111\n">>, Out).

%% A function may be named `module_info` or `record_info`, which the host
%% gives every module: the emitter compiles them under names no Ernest name
%% can spell. A regression test: the compiler refused them with Erlang's "function
%% module_info/0 already defined", and the shell faulted. Not covered here:
%% a call from another module, which the shell test reaches.
host_reserved_names_test() ->
    {ok, Out} = run("export fn module_info() : Int = 7\n"
                    "fn record_info(x : Int) : Int = x + 1\n"
                    "export let total = module_info() + record_info(1)\n"
                    "export fn main() : Unit with Never = {\n"
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
    Local = "    fn first(b : Bytes) : Int = match b { <<y, _:bytes>> -> y | _ -> 0 };\n",
    {ok, Before} = run("export fn main() : Unit with Never = {\n" ++ Local ++
                       "    let n = first(<<5, 6>>);\n    let y = 10;\n"
                       "    Io.println(Int.toString(n + y))\n}\n"),
    ?assertEqual(<<"15\n">>, Before),
    {ok, After} = run("export fn main() : Unit with Never = {\n    let y = 10;\n" ++ Local ++
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
    Neg = "fn neg() : Int = 0 - List.size([1, 2, 3, 4, 5, 6, 7, 8])\n",
    Main = "export fn main() : Unit with Never = ",
    Faults = ["<<(<<1>>):size(2)-bytes>>", "<<1:size(neg())>>", "<<(<<1>>):size(neg())-bytes>>",
              "<<(65519.0 * 1.0):size(16)-float>>"],
    lists:foreach(fun(Bits) ->
                      {R, _} = run(Neg ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({Bits, {fault, <<"segment overflow">>}}, {Bits, R})
                  end, Faults),
    {ok, Out} = run(
        "fn half(b : Bytes) : String = match b {\n"
        "    <<f:size(16)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn single(b : Bytes) : String = match b {\n"
        "    <<f:size(32)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) : String = match b {\n"
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
    {Result, _} = run("export fn main() : Unit with Never = {\n"
                      "    let z = List.size([]);\n"
                      "    Io.println(Int.toString(1 / z))\n"
                      "}\n"),
    ?assertEqual({fault, <<"division by zero">>}, Result).

%% report §7.4, §9.6: fault compiles at any type and faults with its cause
fault_test() ->
    {Result, _} = run("fn later() : Int = fault(\"later\")\n"
                      "export fn main() : Unit with Never = Io.println(Int.toString(later()))\n"),
    ?assertEqual({fault, <<"later">>}, Result).

%% report §9.6: `todo` is no longer the prelude's, `fault` taking its place
todo_is_unknown_test() ->
    ?assertMatch({error, [#diag{message = "unknown name todo"} | _]},
                 ern_typecheck:check_string(['M'], "fn later() : Int = todo(\"x\")\n")).

%% report §5.6, §8.4: named fields in canonical order, and update from a
%% base value
constructors_test() ->
    {ok, Out} = run(
        "type Point = Point(y : Int, x : Int)\n"
        "type Shape = Dot | At(Point)\n"
        "fn show(s : Shape) : String = match s {\n"
        "    Dot -> \"dot\"\n"
        "  | At(Point(x = x, y = y)) -> Int.toString(x) <> \",\" <> Int.toString(y)\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn v(p : Pair) : Pair with Never = { Io.println(\"once\"); p }\n"
        "export fn main() : Unit with Never = {\n"
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
        "fn v(s : String, n : Int) : Int with Never = { Io.println(s); n }\n"
        "export fn main() : Unit with Never = {\n"
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
        "export fn main() : Unit with Never = {\n"
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
        "export fn main() : Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(Local, fn() : Unit with Never = { let _ = 1 / z; Unit },"
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
        "fn idle() : Unit with Never = receive { after 100 -> Unit }\n"
        "fn report() : Unit with Msg = receive {\n"
        "    Died(Down(site = f, reason = _)) -> Io.println(f)\n"
        "}\n"
        "fn outer() : Unit with Msg = {\n"
        "    fn inner() : Address(Never) with Msg = spawn(Local, idle);\n"
        "    monitor(inner(), Died);\n"
        "    report();\n"
        "    let viaLambda = fn() = spawn(Local, idle);\n"
        "    monitor(viaLambda(), Died);\n"
        "    report();\n"
        "    let s = spawn;\n"
        "    monitor(s(Local, idle), Died);\n"
        "    report()\n"
        "}\n"
        "export fn main() : Unit with Msg = outer()\n"),
    ?assertEqual(<<"M.outer:7\nM.outer:10\nM.outer:13\n">>, Out).

%% report §9.4, §9.6: spawn, the Int operators, and <> are functions and
%% may be passed as values
prelude_values_test() ->
    {ok, Out} = run(
        "fn apply2(f : (Int, Int) -> Int, a : Int, b : Int) : Int = f(a, b)\n"
        "fn twice(f : (Int) -> Int, a : Int) : Int = f(f(a))\n"
        "fn join(f : (String, String) -> String) : String = f(\"a\", \"b\")\n"
        "fn start(s : (Where, () -> Unit with Never) -> Address(Never) with Never)\n"
        "        : Address(Never) with Never = s(Local, fn() = Unit)\n"
        "export fn main() : Unit with Never = {\n"
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
        " a : Address(m), mk : (Reply(Int)) -> m) : Optional(Int) with n = f(a, mk, 100)\n"
        "type Msg = Ask(Reply(Int))\n"
        "fn answerer() : Unit with Msg = receive { Ask(r) -> answer(r, 7) }\n"
        "export fn main() : Unit with Never = {\n"
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
        "export fn main() : Unit with Never = {\n"
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
        "fn draw(s : Random.Seed, n : Int) : List(Int) = if n == 0 then [] else {\n"
        "    let #(x, s1) = Random.next(s, 5);\n"
        "    x :: draw(s1, n - 1)\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let xs = draw(Random.seed(42), 50);\n"
        "    Io.println(Bool.toString(List.all(xs, fn(x) = x >= 0 && x <= 5)))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Out).

%% report Appendix E.15, E.14, §9.3: Clock.alarm delivers the wrapped Unit to
%% the caller, Clock.now is a time, Path is the prelude's
clock_path_test() ->
    {ok, Out} = run(
        "type Msg = Tick\n"
        "export fn main() : Unit with Msg = {\n"
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
                    "export fn main() : Unit with Never = Io.println(\"from main\")\n"),
    ?assertEqual(<<"from a let\nfrom main\n">>, Out).

%% report §9, Appendix E: every prelude value the
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
        [restarting] -> {ern_rt, restarting, 2};
        [fault] -> {ern_rt, fault, 1};
        ['Address', call] -> {ern_rt, call, 3};
        ['Address', callForever] -> {ern_rt, call_forever, 2};
        [_, Op] when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/'; Op =:= '%'; Op =:= '<>';
                     Op =:= negate -> {erlang, is_atom, 1};
        [Ns, F] -> {ern_emitter:module_atom([Ns]), F, Arity}
    end.

%% report §6.5, §6.9, §7.3, §9.5: kill is a Down with Killed, a fault a
%% Down with its cause, and via adapts a message, all through compiled code
process_functions_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down) | Tick\n"
        "fn idle() : Unit with Never = receive { after 10000 -> Unit }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let w = spawn(Local, fn() = idle());\n"
        "    monitor(w, Died);\n"
        "    kill(w);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(Local, fn() : Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(m), site = _)) -> Io.println(m)\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    send(via(fn(u : Unit) = Tick, self()), Unit);\n"
        "    receive { Tick -> Io.println(\"tick\") | _ -> Io.println(\"other\") }\n"
        "}\n"),
    ?assertEqual(<<"killed\ndivision by zero\ntick\n">>, Out).

%%
%% Report §6.9 and Appendix E.22: a supervisor's group. Each child is a
%% counter that a restart sets back to 0, and that faults on Boom.
%%

supervised(Strategy, Limit, Names, Main) ->
    run(["type Msg = Ask(reply : Reply(Int)) | Boom\n"
         "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.",
         Strategy, ", ", Limit, "))\n",
         [["let ", N, " : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"]
          || N <- Names],
         "fn count(n : Int) : Unit with Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn show(c : Address(Msg)) : String with m = Int.toString(ask(c))\n"
         "fn pause() : Unit with m = receive { after 100 -> Unit }\n",
         Main]).

-define(LIMIT, "RestartLimit(restarts = 3, within = 5000)").

%% report §6.9, Appendix E.22: under OneForAll a fault restarts every
%% sibling in place, at its next wait, its address kept
one_for_all_restarts_siblings_test() ->
    {ok, Out} = supervised("OneForAll", ?LIMIT, ["a", "b"],
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    send(a, Boom);\n"
        "    pause();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 0\n">>, Out).

%% Appendix E.22: under OneForOne a fault restarts only the child that
%% faulted
one_for_one_restarts_the_child_alone_test() ->
    {ok, Out} = supervised("OneForOne", ?LIMIT, ["a", "b"],
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    send(a, Boom);\n"
        "    pause();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 1\n">>, Out).

%% Appendix E.22: under RestForOne a fault restarts the children spawned
%% after the one that faulted, and not those before it
rest_for_one_restarts_later_children_test() ->
    {ok, Out} = supervised("RestForOne", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    send(b, Boom);\n"
        "    pause();\n"
        "    Io.println(show(a) <> \" \" <> show(b) <> \" \" <> show(c))\n"
        "}\n"),
    ?assertEqual(<<"1 0 0\n">>, Out).

%% Appendix E.22: RestForOne reads the order the children were spawned in,
%% whatever order they joined in: `a`, spawned first, joins last, and its
%% fault still restarts `b` and `c`. A regression test: the order read was
%% the order of joins, which the scheduler decides, and a race of it failed
%% examples/services.ern
rest_for_one_reads_the_order_of_spawns_test() ->
    {ok, Out} = run(["type Msg = Ask(reply : Reply(Int)) | Boom\n"
                     "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group("
                     "Supervisor.RestForOne, ", ?LIMIT, "))\n"
                     "let a : Address(Msg) = spawn(Local, fn() : Unit with Msg = {\n"
                     "    receive { after 100 -> Unit };\n"
                     "    Supervisor.child(sup, fn() = count(0))()\n"
                     "})\n"
                     "let b : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"
                     "let c : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"
                     "fn count(n : Int) : Unit with Msg = receive {\n"
                     "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
                     "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
                     "}\n"
                     "fn ask(c : Address(Msg)) : Int with m ="
                     " Address.callForever(c, fn(r) = Ask(reply = r))\n"
                     "fn show(c : Address(Msg)) : String with m = Int.toString(ask(c))\n"
                     "fn pause() : Unit with m = receive { after 100 -> Unit }\n"
                     "export fn main() : Unit with Never = {\n"
                     "    pause(); pause();\n"
                     "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
                     "    send(a, Boom);\n"
                     "    pause();\n"
                     "    Io.println(show(a) <> \" \" <> show(b) <> \" \" <> show(c))\n"
                     "}\n"]),
    ?assertEqual(<<"0 0 0\n">>, Out).

%% report §6.9: a restart asked for is no fault, and no fault is reported
%% for it; only the child that faulted is
restart_asked_for_is_no_fault_test() ->
    {ok, Out} = supervised("OneForAll", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    pause();\n"
        "    let _ = ask(b);\n"
        "    Io.println(Int.toString(reports(0)))\n"
        "}\n"
        "fn reports(n : Int) : Int with Process.FaultReport ="
        " receive { _ -> reports(n + 1) | after 100 -> n }\n"),
    ?assertEqual(<<"1\n">>, Out).

%% report §6.6, §6.9: a call waiting on a child when its supervisor
%% restarts it ends, and callForever faults with the cause that says so;
%% the child restarts at the wait inside its handling of the request
call_ends_at_asked_restart_test() ->
    {R, _} = run(
        "type Msg = Slow(reply : Reply(Int)) | Boom\n"
        "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = serve()))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = serve()))\n"
        "fn serve() : Unit with Msg = receive {\n"
        "    Slow(reply = r) -> { receive { after 500 -> Unit }; answer(r, 1); serve() }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = spawn(Local, fn() : Unit with Never = {\n"
        "        receive { after 50 -> Unit };\n"
        "        send(a, Boom)\n"
        "    });\n"
        "    let _ = Address.callForever(b, fn(r) = Slow(reply = r));\n"
        "    Io.println(\"answered\")\n"
        "}\n"),
    ?assertEqual({fault, <<"callee was restarted">>}, R).

%% Appendix E.22: past its limit a group faults; at the root it dies, and
%% its watcher kills its children
limit_ends_the_group_test() ->
    {ok, Out} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)", ["a"],
        "type Seen = Died(Down)\n"
        "export fn main() : Unit with Seen = {\n"
        "    monitor(a, Died);\n"
        "    send(a, Boom);\n"
        "    pause();\n"
        "    send(a, Boom);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"killed\n">>, Out).

%% Appendix E.22: kill(sup) stops the group, the children killed in the
%% reverse of the order they joined, each once the one before has ended
kill_stops_in_reverse_order_test() ->
    {ok, Out} = supervised("OneForOne", ?LIMIT, ["a", "b", "c"],
        "type Seen = Died(String)\n"
        "export fn main() : Unit with Seen = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitor(a, fn(_) = Died(\"a\"));\n"
        "    monitor(b, fn(_) = Died(\"b\"));\n"
        "    monitor(c, fn(_) = Died(\"c\"));\n"
        "    kill(sup);\n"
        "    Io.println(String.join([next(), next(), next()], \" \"))\n"
        "}\n"
        "fn next() : String with Seen = receive { Died(n) -> n }\n"),
    ?assertEqual(<<"c b a\n">>, Out).

%% Appendix E.22: a supervisor that is a child restarts in place past its
%% limit, its children restarted with it, their addresses kept
nested_group_restarts_in_place_test() ->
    {ok, Out} = run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Local, Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    send(a, Boom);\n"
        "    receive { after 100 -> Unit };\n"
        "    Io.println(Int.toString(ask(a)) <> \" \" <> Int.toString(ask(b)))\n"
        "}\n"),
    ?assertEqual(<<"0 0\n">>, Out).

%% Appendix E.22: a supervisor restarted in place counts its limit afresh,
%% and a fault it counted before the restart does not expire from the new
%% count. A regression test for alarms of an earlier run lowering the
%% count; the gaps around the old alarm, at 1000 ms, are 150 ms and more
count_survives_restart_in_place_test() ->
    {ok, Out} = run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Local, Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 1, within = 1000))))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "fn wait(ms : Int) : Unit with m = receive { after ms -> Unit }\n"
        "export fn main() : Unit with Never = {\n"
        "    send(a, Boom);\n"
        "    wait(50);\n"
        "    send(a, Boom);\n"
        "    wait(250);\n"
        "    let _ = ask(b); let _ = ask(b);\n"
        "    send(a, Boom);\n"
        "    wait(850);\n"
        "    send(a, Boom);\n"
        "    wait(100);\n"
        "    Io.println(Int.toString(ask(b)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Out).

%% Appendix E.22: a child that starts after its supervisor has ended
%% faults once with a cause that says so, and does not restart. A
%% regression test for a child that joined inside its restart loop and
%% restarted without end
child_of_ended_supervisor_test() ->
    {R, _} = run(
        "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "export fn main() : Unit with Never = {\n"
        "    kill(sup);\n"
        "    receive { after 50 -> Unit };\n"
        "    let c = Supervisor.child(sup, fn() : Unit with Never = Unit);\n"
        "    c()\n"
        "}\n"),
    ?assertEqual({fault, <<"the supervisor has ended">>}, R).

%% report §6.9, Appendix E.22: a root group past its limit faults, and its
%% children are killed; none reports a fault it did not have. A regression
%% test for children that, asked to restart, rejoined the dead supervisor
%% and reported that as their own fault
limit_reports_only_real_faults_test() ->
    {ok, Out} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)",
        ["a", "b", "c"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    pause();\n"
        "    send(a, Boom);\n"
        "    Io.println(String.join(causes([]), \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) with Process.FaultReport = receive {\n"
        "    f -> causes(seen <> [f.cause])\n"
        "  | after 300 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero; supervisor restart limit reached\n">>,
                 Out).

%% Appendix E.22: one process runs a group's function, and a second that
%% runs it faults, since the process that keeps the group's children is
%% the function's. Written with the rule (report §6.9's emptied mailbox)
group_runs_in_one_process_test() ->
    {ok, Out} = run(
        "type MainMsg = Died(Down)\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let g = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let _ = spawnMonitored(Local, g, Died);\n"
        "    let _ = spawnMonitored(Local, g, Died);\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"Fault(\"a group runs in one process\")\n">>, Out).

%% Appendix E.22: a group's first supervisor is the one, and a process that
%% runs the group after it has ended faults as a second does while it
%% runs. A regression test: the second was told the watcher had returned
%% without answering
group_runs_once_after_its_end_test() ->
    {ok, Out} = run(
        "type MainMsg = Died(Down)\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let g = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let first = spawn(Local, g);\n"
        "    receive { after 50 -> Unit };\n"
        "    kill(first);\n"
        "    receive { after 50 -> Unit };\n"
        "    let _ = spawnMonitored(Local, g, Died);\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"Fault(\"a group runs in one process\")\n">>, Out).

%% A group whose children count, fault on Boom, and on Crunch compute for a
%% while without waiting, so that a restart asked of one then waits; on
%% Crash they compute so and then fault.
crunching(Main) ->
    run(["type Msg = Ask(reply : Reply(Int)) | Boom | Crunch | Crash\n", Main,
         "fn count(n : Int) : Unit with Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "  | Crunch -> { let _ = spin(50000000); count(n) }\n"
         "  | Crash -> { let z = spin(50000000); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn spin(k : Int) : Int = if k == 0 then 0 else spin(k - 1)\n"
         "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn wait(ms : Int) : Unit with m = receive { after ms -> Unit }\n"]).

%% Appendix E.22: a sibling asked to restart that faults of its own before
%% it takes the restart has restarted by its fault, and the child that
%% waited for it runs again. RestForOne, so that the sibling's fault asks
%% nothing of the child. A regression test: the sibling's fault emptied
%% the ask with its mailbox, and the child waited for ever
sibling_faulting_first_counts_as_restarted_test() ->
    {ok, Out} = crunching(
        "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.RestForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    send(b, Crash);\n"
        "    wait(20);\n"
        "    send(a, Boom);\n"
        "    wait(1000);\n"
        "    Io.println(Int.toString(ask(a)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Out).

%% Appendix E.22: a child that waits for its fault to be counted when its
%% supervisor restarts in place is restarted as asked, and reports no fault
%% of its own. A regression test: its call to the supervisor ended as the
%% supervisor restarted, and it faulted with `callee was restarted`
child_waits_through_its_supervisors_restart_test() ->
    {ok, Out} = crunching(
        "let top : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Local, Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Local, Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 5, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(x);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(b, Crunch);\n"
        "    wait(20);\n"
        "    send(a, Boom);\n"
        "    wait(20);\n"
        "    send(x, Boom);\n"
        "    Io.println(String.join(causes([]), \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) with Process.FaultReport = receive {\n"
        "    f -> causes(seen <> [f.cause])\n"
        "  | after 1000 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero\n">>, Out).

%% Appendix E.22: a child at whose fault a nested group gave up runs its
%% function once when the group, restarted in place, restarts it. A
%% regression test: the watcher let it go on before the supervisor asked
%% it to restart, and it ran its function twice
held_child_runs_once_test() ->
    {ok, Out} = run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Count(reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(Local, fn() = logging(0))\n"
        "fn logging(n : Int) : Unit with LogMsg = receive {\n"
        "    Started -> logging(n + 1)\n"
        "  | Count(reply = r) -> { answer(r, n); logging(n) }\n"
        "}\n"
        "let top : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Local, Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = {\n"
        "    send(log, Started);\n"
        "    count(0)\n"
        "}))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(a);\n"
        "    send(a, Boom);\n"
        "    receive { after 300 -> Unit };\n"
        "    let _ = ask(a);\n"
        "    Io.println(Int.toString(Address.callForever(log, fn(r) = Count(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Out).

%% Appendix E.22: a supervisor that its parent restarts asks its own
%% children to restart, so a subtree restarts with its root. A regression
%% test for a supervisor restarted in place that left its children running
parent_restarts_subtree_test() ->
    {ok, Out} = run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Local, Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Local, Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 5, within = 5000))))\n"
        "let c : Address(Msg) = spawn(Local, Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(a : Address(Msg)) : Int with m = Address.callForever(a, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = ask(c); let _ = ask(c);\n"
        "    send(x, Boom);\n"
        "    receive { after 100 -> Unit };\n"
        "    Io.println(Int.toString(ask(c)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Out).

%% report §6.9: a restart asked for runs the child's own function again,
%% even where that function runs a restarting function of its own. A
%% regression test for the inner function taking the restart. The fault
%% is sent once the child has started, and the log asked until it has
%% seen the second start, each wait at most ten seconds: a child that has
%% not begun when its sibling faults is not asked, and starts fresh, and
%% how soon either happens is the host's. Sent at once, with a wait of
%% 100 ms, the fault came first under the host's modified timing
restart_reaches_the_outer_function_test() ->
    {ok, Out} = run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Count(reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(Local, fn() = logging(0))\n"
        "fn logging(n : Int) : Unit with LogMsg = receive {\n"
        "    Started -> logging(n + 1)\n"
        "  | Count(reply = r) -> { answer(r, n); logging(n) }\n"
        "}\n"
        "let sup : Address(Supervisor.Msg) = spawn(Local, Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Local, Supervisor.child(sup, fn() = {\n"
        "    send(log, Started);\n"
        "    restarting(RestartLimit(restarts = 5, within = 5000), fn() = count(0))()\n"
        "}))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn starts(least : Int, tries : Int) : Int with Never = {\n"
        "    let n = Address.callForever(log, fn(r) = Count(reply = r));\n"
        "    if n >= least || tries == 0 then n else {\n"
        "        receive { after 10 -> Unit };\n"
        "        starts(least, tries - 1)\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = starts(1, 1000);\n"
        "    send(a, Boom);\n"
        "    Io.println(Int.toString(starts(2, 1000)))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Out).

%%
%% Report Appendix E.23: Os.run, each program run through ern_exec.
%%

%% A program that prints what Os.run answered for one command.
os_run(Program, Arguments, Input, Ms) ->
    run(["fn show(r : Either(Io.Error, Os.Finished)) : String = match r {\n"
         "    Right(f) -> Int.toString(f.status) <> \"|\" <> Io.show(String.fromUtf8(f.stdout))\n"
         "        <> \"|\" <> Io.show(String.fromUtf8(f.stderr))\n"
         "  | Left(e) -> Io.show(e)\n"
         "}\n"
         "export fn main() : Unit with Never = Io.println(show(Os.run(Os.Command(program = ",
         Program, ", arguments = ", Arguments, ", input = ", Input, "), ", Ms, ")))\n"]).

%% A directory of the test's own, for a program to leave a mark in; one an
%% earlier run left under the same name is removed first.
scratch() ->
    Dir = filename:join(os:getenv("TMPDIR", "/tmp"),
                        "ern_os_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

%% Appendix E.23: the exit status, the output and the standard error, apart
os_run_status_and_streams_test() ->
    {ok, Out} = os_run("\"sh\"", "[\"-c\", \"echo out; echo err >&2; exit 2\"]", "<<>>", "5000"),
    ?assertEqual(<<"2|Some(\"out\\n\")|Some(\"err\\n\")\n">>, Out).

%% Appendix E.23: the program reads its input and then the end of it, so
%% one that reads to the end, as sort does, ends
os_run_input_then_end_test() ->
    {ok, Out} = os_run("\"sort\"", "[]", "String.toUtf8(\"b\\na\\n\")", "5000"),
    ?assertEqual(<<"0|Some(\"a\\nb\\n\")|Some(\"\")\n">>, Out).

%% Appendix E.23: each argument reaches the program as it is, no shell
%% between, so a space or a `;` is part of the argument
os_run_arguments_as_they_are_test() ->
    {ok, Out} = os_run("\"printf\"", "[\"%s|\", \"a b\", \"c;d\", \"$HOME\"]", "<<>>", "5000"),
    ?assertEqual(<<"0|Some(\"a b|c;d|$HOME|\")|Some(\"\")\n">>, Out).

%% Appendix E.23: a program a signal ended has 128 and the signal's number
os_run_signal_status_test() ->
    {ok, Out} = os_run("\"sh\"", "[\"-c\", \"kill -TERM $$\"]", "<<>>", "5000"),
    ?assertEqual(<<"143|Some(\"\")|Some(\"\")\n">>, Out).

%% Appendix E.23: NotFound for a program not found, Denied for one that may
%% not be run, and a named cause for an argument no program could be given
os_run_refusals_test() ->
    ?assertEqual({ok, <<"NotFound\n">>}, os_run("\"no-such-program-ern\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Denied\n">>}, os_run("\"/dev/null\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Other(\"an argument holds U+0000\")\n">>},
                 os_run("\"echo\"", "[\"a\\u{0}b\"]", "<<>>", "5000")).

%% Appendix E.23: Timeout when the time runs out first, and the program,
%% still running, killed, so the mark it would leave is never made
os_run_timeout_kills_test() ->
    Mark = filename:join(scratch(), "mark"),
    {ok, Out} = os_run("\"sh\"", "[\"-c\", \"sleep 1; touch " ++ Mark ++ "\"]", "<<>>", "200"),
    ?assertEqual(<<"Timeout\n">>, Out),
    timer:sleep(1500),
    ?assertNot(filelib:is_file(Mark)).

%% Appendix E.23: a program whose caller dies is killed with it
os_run_dies_with_its_caller_test() ->
    Mark = filename:join(scratch(), "mark"),
    {ok, _} = run(
        "export fn main() : Unit with Never = {\n"
        "    let w = spawn(Local, fn() : Unit with Never = {\n"
        "        let _ = Os.run(Os.Command(program = \"sh\", arguments = [\"-c\",\n"
        "            \"sleep 1; touch " ++ Mark ++ "\"], input = <<>>), 5000);\n"
        "        Unit\n"
        "    });\n"
        "    receive { after 200 -> Unit };\n"
        "    kill(w)\n"
        "}\n"),
    timer:sleep(1500),
    ?assertNot(filelib:is_file(Mark)).

%% Appendix E.17: a path that holds U+0000 names no file, and says so. A
%% regression test for the host's own term, badarg, answered as the cause
fs_path_with_nul_test() ->
    {ok, Out} = run("export fn main() : Unit with Never =\n"
                    "    Io.println(Io.show(Fs.read(Path(\"a\\u{0}b\"), 1000)))\n"),
    ?assertEqual(<<"Left(Other(\"a path holds U+0000\"))\n">>, Out).

%% report §8.6, Appendix E.23: a program running is a source, so a caller
%% that only waits for it is in no deadlock
os_run_is_a_source_test() ->
    ?assertEqual({ok, <<"0|Some(\"\")|Some(\"\")\n">>},
                 os_run("\"sleep\"", "[\"0.5\"]", "<<>>", "5000")).

%%
%% Report Appendix E.23: a running program is a process, Os.start's
%% address, read and fed piece by piece. Regression tests, written after
%% the code; the host's output order within one stream is its own, and a
%% name the host gives twice in the environment is not covered here.
%%

%% What a program wrote, a line a piece, until its exit status or why not.
drain() ->
    "fn text(b : Bytes) : String = Optional.withDefault(String.fromUtf8(b), \"?\")\n"
    "fn drain(p : Address(Os.ProgramMsg)) : Unit with m = match Os.read(p) {\n"
    "    Right(Os.Stdout(b)) -> { Io.print(\"out \" <> text(b)); drain(p) }\n"
    "  | Right(Os.Stderr(b)) -> { Io.print(\"err \" <> text(b)); drain(p) }\n"
    "  | Right(Os.Exited(s)) -> Io.println(\"exit \" <> Int.toString(s))\n"
    "  | Left(e) -> Io.println(Io.show(e))\n"
    "}\n".

%% Appendix E.23: each read answers the next piece from either stream, in
%% the order the host delivered them, and last the exit status
os_start_reads_in_order_test() ->
    {ok, Out} = run([drain(),
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"echo a; sleep 0.1; echo b >&2; sleep 0.1; echo c; exit 4\"],\n"
        "    input = <<>>), 5000) {\n"
        "    Right(p) -> drain(p)\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"out a\nerr b\nout c\nexit 4\n">>, Out).

%% Appendix E.23: the host takes the program's output only while a read
%% waits, so a program that writes more than a pipe holds, and that no one
%% reads, waits on its output and has not gone on to leave its mark
os_start_output_waits_for_a_read_test() ->
    Mark = filename:join(scratch(), "mark"),
    {ok, Out} = run([
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int with m = match Os.read(p) {\n"
        "    Right(Os.Exited(_)) -> n\n"
        "  | Right(_) -> drain(p, n + 1)\n"
        "  | Left(_) -> -1\n"
        "}\n"
        "fn marked() : Bool with m = Either.isRight(Fs.stat(Path(\"", Mark, "\"), 1000))\n"
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"head -c 1000000 /dev/zero; touch ", Mark, "\"],\n"
        "    input = <<>>), 5000) {\n"
        "    Right(p) -> {\n"
        "        receive { after 300 -> Unit };\n"
        "        let before = marked();\n"
        "        let pieces = drain(p, 0);\n"
        "        Io.println(Io.show(#(before, pieces > 0, marked())))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(false, true, true)\n">>, Out).

%% Appendix E.23: the program reads `input`, then what write gives it,
%% until closeInput; what is written after that is dropped, and the write
%% answers Left(Closed)
os_start_write_then_close_test() ->
    {ok, Out} = run([
        "fn collect(p : Address(Os.ProgramMsg), got : Bytes) : Bytes with m = match Os.read(p) {\n"
        "    Right(Os.Stdout(b)) -> collect(p, got <> b)\n"
        "  | _ -> got\n"
        "}\n"
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"cat\",\n"
        "    arguments = [], input = String.toUtf8(\"a\")), 5000) {\n"
        "    Right(p) -> {\n"
        "        let taken = Os.write(p, String.toUtf8(\"b\"));\n"
        "        Os.closeInput(p);\n"
        "        let dropped = Os.write(p, String.toUtf8(\"c\"));\n"
        "        Io.println(Io.show(#(taken, dropped, String.fromUtf8(collect(p, <<>>)))))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Left(Closed), Some(\"ab\"))\n">>, Out).

%% Appendix E.23, report §6.9: a running program is a process, which
%% `monitor` watches and `kill` stops, the program and its process group
%% with it; one that has answered its exit status has returned
os_program_is_a_process_test() ->
    Dir = scratch(),
    Pids = filename:join(Dir, "pids"),
    {ok, Out} = run([
        "type Msg = Ended(Down)\n"
        "fn started(script : String) : Address(Os.ProgramMsg) with Msg =\n"
        "    match Os.start(Os.Command(program = \"sh\", arguments = [\"-c\", script],\n"
        "        input = <<>>), 5000) {\n"
        "        Right(p) -> p\n"
        "      | Left(_) -> fault(\"not started\")\n"
        "    }\n"
        "fn reason() : String with Msg =\n"
        "    receive { Ended(Down(reason = r, site = _)) -> Io.show(r) }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let sleeper = started(\"sleep 10 & echo $$ $! > ", Pids, "; wait\");\n"
        "    receive { after 300 -> Unit };\n"
        "    monitor(sleeper, Ended);\n"
        "    kill(sleeper);\n"
        "    Io.println(reason());\n"
        "    let quick = started(\"exit 0\");\n"
        "    monitor(quick, Ended);\n"
        "    let _ = Os.read(quick);\n"
        "    Io.println(reason())\n"
        "}\n"]),
    ?assertEqual(<<"Killed\nReturned\n">>, Out),
    timer:sleep(200),
    {ok, Written} = file:read_file(Pids),
    [begin
         {Status, _} = sh("kill -0 " ++ binary_to_list(Pid)),
         ?assertNotEqual(0, Status)
     end || Pid <- binary:split(Written, [<<" ">>, <<"\n">>], [global, trim_all])].

%% Appendix E.23: after the program's time, a read answers Timeout and the
%% program's process ends, so the read after it faults as a call to an
%% ended process does (report §6.6)
os_start_time_limit_test() ->
    {Result, Out} = run(
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"sleep\",\n"
        "    arguments = [\"10\"], input = <<>>), 100) {\n"
        "    Right(p) -> {\n"
        "        Io.println(Io.show(Os.read(p)));\n"
        "        receive { after 100 -> Unit };\n"
        "        Io.println(Io.show(Os.read(p)))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertEqual(<<"Left(Timeout)\n">>, Out),
    ?assertEqual({fault, <<"callee had ended">>}, Result).

%% Appendix E.23, report §8.6: Os.exit ends the program with its status,
%% from any process, the output written before it flushed; a status
%% outside 0 to 255 faults the caller (§7.4)
os_exit_test() ->
    ?assertEqual({{exit, 3}, <<"bye\n">>},
                 run("export fn main() : Unit with Never = {\n"
                     "    Io.println(\"bye\");\n"
                     "    Os.exit(3)\n"
                     "}\n")),
    ?assertEqual({{exit, 5}, <<>>},
                 run("export fn main() : Unit with Never = {\n"
                     "    let _ = spawn(Local, fn() : Unit with Never = Os.exit(5));\n"
                     "    receive { after 5000 -> Unit }\n"
                     "}\n")),
    ?assertEqual({{fault, <<"an exit status is from 0 to 255">>}, <<>>},
                 run("export fn main() : Unit with Never = Os.exit(256)\n")).

%% report §11.2: where Os.exit faults its caller, as in the shell and under
%% `ern test`, it ends only the process that calls it
os_exit_faults_where_asked_test() ->
    ?assertEqual({{fault, <<"exited with status 2">>}, <<>>},
                 run(['M'], "export fn main() : Unit with Never = Os.exit(2)\n",
                     #{exit => fault})).

%% Appendix E.23, report §11.2: Os.arguments is what the launcher was
%% given, and the empty list where it was given none
os_arguments_test() ->
    Main = "export fn main() : Unit with Never = Io.println(Io.show(Os.arguments))\n",
    ?assertEqual({ok, <<"[\"a\", \"b c\", \"--x\"]\n">>},
                 run(['M'], Main, #{arguments => [<<"a">>, <<"b c">>, <<"--x">>]})),
    ?assertEqual({ok, <<"[]\n">>}, run(Main)).

%% Appendix E.17: a name in a directory that is not UTF-8 is left out of
%% Fs.list; a regression test for the host's warning printed in its place
fs_list_leaves_out_names_not_utf8_test() ->
    Dir = scratch(),
    ok = file:write_file(<<(list_to_binary(Dir))/binary, "/caf", 16#e9>>, <<>>),
    ok = file:write_file(filename:join(Dir, "ok"), <<>>),
    {ok, Out} = run(["export fn main() : Unit with Never = match Fs.list(Path(\"", Dir,
                     "\"), 1000) {\n"
                     "    Right(entries) -> Io.println(Io.show(List.map(entries,\n"
                     "        fn(e) = Path.name(e.path))))\n"
                     "  | Left(e) -> Io.println(Io.show(e))\n"
                     "}\n"]),
    ?assertEqual(<<"[\"ok\"]\n">>, Out).

%% report §6.9: a wait on a process is kept while its waiter lives: a
%% watcher that ends takes its waits with it, and a process that ends
%% leaves nothing behind in what its waiter watches. A regression test,
%% written after the code: the runtime kept both for as long as the other
%% process lived, so a long-lived service watched by short-lived clients,
%% or a long-lived process watching short-lived workers, grew it with every
%% monitor. The runtime's memory for waits is read after 100 of each and
%% after 1,100.
monitors_let_go_test() ->
    {ok, Out} = run(
        "type Msg = Ended(Down) | Go\n"
        "foreign fn waits() : Int with m = \"ern_emitter_tests:reaper_words/0\"\n"
        "fn rounds(keeper : Address(Msg), n : Int) : Unit with Msg =\n"
        "    if n == 0 then Unit\n"
        "    else {\n"
        "        let _ = spawnMonitored(Local, fn() : Unit with Msg = monitor(keeper, Ended),\n"
        "            Ended);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        let w = spawn(Local, fn() : Unit with Msg = receive { Go -> Unit });\n"
        "        monitor(w, Ended);\n"
        "        send(w, Go);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        rounds(keeper, n - 1)\n"
        "    }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let keeper = spawn(Local, fn() : Unit with Msg = receive { Go -> Unit });\n"
        "    rounds(keeper, 100);\n"
        "    let before = waits();\n"
        "    rounds(keeper, 1000);\n"
        "    Io.println(Io.show(waits() == before))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Out).

%% The words of the runtime's reaper, which holds every wait, after the
%% deliveries in flight have ended and its garbage is collected.
reaper_words() ->
    timer:sleep(100),
    Reaper = persistent_term:get({ern_rt, reaper}),
    erlang:garbage_collect(Reaper),
    element(2, erlang:process_info(Reaper, total_heap_size)).

%% report §8.6: a program waiting only on alarms it has set is in no
%% deadlock, however its waits and the clock's work interleave. A
%% regression test, written after the code: the check read its counts
%% before its snapshots, and could not see an alarm still in transit to the
%% clock, so a loop like this one faulted with `deadlock` about one run in
%% three at twenty thousand alarms. At five thousand it catches the race
%% only sometimes; `make load`'s `alarms` catches it more often.
alarms_are_no_deadlock_test_() ->
    {timeout, 120, fun() ->
        ?assertEqual({ok, <<"done\n">>}, run(
            "type Msg = Tick(Int)\n"
            "fn loop(n : Int) : Unit with Msg =\n"
            "    if n == 0 then Unit\n"
            "    else {\n"
            "        Clock.alarmAt(Clock.now(), Tick);\n"
            "        receive { Tick(_) -> Unit };\n"
            "        loop(n - 1)\n"
            "    }\n"
            "export fn main() : Unit with Msg = { loop(5000); Io.println(\"done\") }\n"))
    end}.

%% report §8.4, §7.4: a function value inside a recursive type that comes
%% back from foreign code has its result checked against the type at each
%% call, the recursive type's own among them. A regression test: the check
%% met the type's reference back to itself with nothing to look it up in,
%% and the call faulted with badkey
recursive_function_value_test() ->
    ?assertEqual({ok, <<"3\n">>}, run(
        "type Chain = Chain(n : Int, next : () -> Chain)\n"
        "foreign fn first(chains : List(Chain)) : Chain = \"erlang:hd/1\"\n"
        "fn from(n : Int) : Chain = Chain(n = n, next = fn() = from(n + 1))\n"
        "export fn main() : Unit with Never = {\n"
        "    let c = first([from(1)]);\n"
        "    Io.println(Int.toString(c.next().next().n))\n"
        "}\n")).

%% Appendix E.19: a text longer than 255 characters makes no atom, and
%% `Erl.atom` faults as a foreign function that raises does (report §7.4)
erl_atom_too_long_test() ->
    {Result, _} = run("export fn main() : Unit with Never = {\n"
                      "    let _ = Erl.atom(String.padStart(\"\", 256, 'a'));\n"
                      "    Unit\n"
                      "}\n"),
    ?assertMatch({fault, <<"foreign function erlang:binary_to_atom/1 raised error:system_limit">>,
                  _}, Result).

%% Plan, MVP 2.7, "Atoms, counted": a program's work makes no atoms, since
%% the host never frees one; the same work done again, processes and calls,
%% a socket, a host program, a file and an alarm, leaves the count as it
%% was. Written after the reading that found none; `make load` measures the
%% same at length (docs/memory.md).
work_makes_no_atoms_test_() ->
    {timeout, 60, fun() ->
        Dir = scratch(),
        {ok, Out} = run([
            "type Msg = Tick(Int) | Ended(Down)\n"
            "foreign fn info(k : Foreign) : Int with m = \"erlang:system_info/1\"\n"
            "fn work() : Unit with Msg = {\n"
            "    let w = spawn(Local, fn() : Unit with Int = receive { _ -> Unit });\n"
            "    monitor(w, Ended);\n"
            "    kill(w);\n"
            "    receive { Ended(_) -> Unit };\n"
            "    Clock.alarm(1, Tick);\n"
            "    receive { Tick(_) -> Unit };\n"
            "    let _ = Os.run(Os.Command(program = \"true\", arguments = [], input = <<>>),\n"
            "        5000);\n"
            "    let _ = Fs.write(Path(\"", Dir, "/f\"), <<1>>, 1000);\n"
            "    let _ = Fs.read(Path(\"", Dir, "/f\"), 1000);\n"
            "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
            "        Right(l) -> Tcp.closeListener(l)\n"
            "      | Left(_) -> Unit\n"
            "    }\n"
            "}\n"
            "export fn main() : Unit with Msg = {\n"
            "    work();\n"
            "    let before = info(Erl.atom(\"atom_count\"));\n"
            "    work();\n"
            "    work();\n"
            "    Io.println(Io.show(info(Erl.atom(\"atom_count\")) - before))\n"
            "}\n"]),
        ?assertEqual(<<"0\n">>, Out)
    end}.

%%
%% report §8.2, Appendix E.18, E.23: a write returns once its stream has
%% taken the bytes, and waits while the stream is behind. Regression
%% tests, written after the code: each write returned at once, and what the
%% reader had not taken was held in the node.
%%

%% A writer of four megabytes, and whether it has finished after half a
%% second in which nothing reads, then after everything is read.
paced(Setup) ->
    run(["type Msg = Done | Ended(Down)\n",
         Setup,
         "fn chunk() : Bytes = String.toUtf8(String.repeat(\"x\", 65536))\n"
         "fn writes(write : (Bytes) -> Either(Io.Error, Unit) with Never, n : Int)"
         " : Unit with Never =\n"
         "    if n == 0 then Unit else { let _ = write(chunk()); writes(write, n - 1) }\n"
         "fn done() : Bool with Msg =\n"
         "    receive { Done -> true | after 0 -> false }\n"]).

%% Appendix E.23: a program that stops reading its input, since no one
%% reads its output, holds its writer, and a write after its end faults
os_write_waits_test() ->
    {ok, Out} = paced(
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int with Msg = match Os.read(p) {\n"
        "    Right(Os.Stdout(b)) -> drain(p, n + Bytes.size(b))\n"
        "  | _ -> n\n"
        "}\n"
        "export fn main() : Unit with Msg = match Os.start(Os.Command(program = \"cat\",\n"
        "    arguments = [], input = <<>>), 30000) {\n"
        "    Right(p) -> {\n"
        "        let me = self();\n"
        "        let _ = spawn(Local, fn() : Unit with Never = {\n"
        "            writes(fn(b) = Os.write(p, b), 64);\n"
        "            Os.closeInput(p);\n"
        "            send(me, Done)\n"
        "        });\n"
        "        receive { after 500 -> Unit };\n"
        "        let early = done();\n"
        "        let n = drain(p, 0);\n"
        "        receive { Done -> Unit };\n"
        "        Io.println(Io.show(#(early, n)));\n"
        "        let late = fn() : Unit with Never = {\n"
        "            let _ = Os.write(p, <<1>>);\n"
        "            Unit\n"
        "        };\n"
        "        let _ = spawnMonitored(Local, late, Ended);\n"
        "        receive { Ended(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertMatch({match, _}, re:run(Out, "^#\\(false, 4194304\\)\nFault\\(\"callee (had ended|"
                                         "returned without answering)\"\\)\n$")).

%% Appendix E.18: a socket whose far end does not read holds its writer,
%% and a write to a socket that has been closed faults
tcp_write_waits_test() ->
    {ok, Out} = paced(
        "fn drain(s : Address(Tcp.SockMsg), n : Int) : Int with Msg =\n"
        "    if n >= 4194304 then n\n"
        "    else match Tcp.read(s, 5000) {\n"
        "        Right(b) -> drain(s, n + Bytes.size(b))\n"
        "      | Left(_) -> n\n"
        "    }\n"
        "export fn main() : Unit with Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let me = self();\n"
        "            let _ = spawn(Local, fn() : Unit with Never = match\n"
        "                Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "                    Right(c) -> { writes(fn(b) = Tcp.write(c, b), 64); send(me, Done) }\n"
        "                  | Left(_) -> Unit\n"
        "                });\n"
        "            match Tcp.accept(l, 5000) {\n"
        "                Right(s) -> {\n"
        "                    receive { after 500 -> Unit };\n"
        "                    let early = done();\n"
        "                    let n = drain(s, 0);\n"
        "                    receive { Done -> Unit };\n"
        "                    Tcp.close(s);\n"
        "                    receive { after 50 -> Unit };\n"
        "                    Io.println(Io.show(#(early, n)));\n"
        "                    let late = fn() : Unit with Never = {\n"
        "                        let _ = Tcp.write(s, <<1>>);\n"
        "                        Unit\n"
        "                    };\n"
        "                    let _ = spawnMonitored(Local, late, Ended);\n"
        "                    receive {\n"
        "                        Ended(Down(reason = r, site = _)) -> Io.println(Io.show(r))\n"
        "                    }\n"
        "                }\n"
        "              | Left(e) -> Io.println(Io.show(e))\n"
        "            }\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertEqual(<<"#(false, 4194304)\nFault(\"callee had ended\")\n">>, Out).

%% report §8.4, §7.4: a type variable of a foreign function's result that no
%% parameter names matches no value, so a return that holds one faults, and
%% an empty list of it passes, as does a value of a foreign type over it,
%% which the check does not look into; a function given to foreign code has
%% the arguments it is called with checked. A regression test: the first was
%% an unchecked cast, and the second let any value in (findings.md's S-H);
%% the foreign type's case was written after the code (findings.md's K-8)
foreign_casts_and_callbacks_test() ->
    Run = fun(Decl, Body) ->
                  {R, _} = run(Decl ++ "export fn main() : Unit with Never = {\n"
                               "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                  R
          end,
    ?assertEqual({fault, <<"foreign return does not match a">>},
                 Run("foreign fn cast(n : Int) : a =\n    \"erlang:abs/1\"\n", "cast(1) + 1")),
    ?assertEqual(ok, Run("foreign fn none(xs : List(Int)) : List(a) =\n    \"erlang:tl/1\"\n",
                         "List.size(none([1]))")),
    ?assertEqual(ok, Run("foreign type Handle(a)\n"
                         "foreign fn handle() : Handle(a) =\n    \"erlang:make_ref/0\"\n",
                         "handle()")),
    ?assertEqual({fault, <<"foreign argument does not match Int">>},
                 Run("foreign fn each(f : (Int) -> Int, xs : List(String)) : List(Int) =\n"
                     "    \"lists:map/2\"\n", "each(fn(n) = n + 1, [\"x\"])")).

%% report §8.4: a type variable a parameter's type names matches any value at
%% the boundary, in a foreign function's result and in an argument foreign
%% code calls a function with, until a foreign function takes its caller's
%% description of the type (MVP 2.99b's item 13). A regression test of what
%% the report states
foreign_type_variables_unchecked_test() ->
    Run = fun(Decl, Body) ->
                  {R, _} = run(Decl ++ "export fn main() : Unit with Never = {\n"
                               "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                  R
          end,
    ?assertEqual(ok, Run("foreign fn weird(x : a) : a =\n    \"erlang:length/1\"\n",
                         "weird([1, 2])")),
    ?assertEqual(ok, Run("foreign fn each(f : (a) -> Int, x : a) : List(Int) =\n"
                         "    \"lists:map/2\"\n", "each(fn(_) = 1, [[\"x\"]])")).

%% report Appendix E.18: a socket is owned by the process that opened it and
%% killed when its owner dies; `give` makes another its owner, and a socket
%% given to a process that has ended is killed at once. A regression test:
%% a socket outlived a handler that faulted, one leaked connection each
%% (findings.md's C1-2)
socket_owner_test() ->
    {ok, Out} = run(
        "type Msg = Opened(Address(Tcp.SockMsg)) | Ended(Down)\n"
        "fn opener(port : Int, to : Address(Msg)) : Unit with Never =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> send(to, Opened(s))\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn keeper() : Unit with Int = receive { _ -> Unit }\n"
        "fn giver(port : Int, keep : Process, to : Address(Msg)) : Unit with Never =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> {\n"
        "            Tcp.give(s, keep);\n"
        "            send(to, Opened(s))\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn opened() : Address(Tcp.SockMsg) with Msg = receive { Opened(s) -> s }\n"
        "fn ends(s : Address(Tcp.SockMsg), ms : Int) : String with Msg = {\n"
        "    monitor(s, Ended);\n"
        "    receive { Ended(_) -> \"ended\" | after ms -> \"alive\" }\n"
        "}\n"
        "fn check(port : Int) : Unit with Msg = {\n"
        "    let me = self();\n"
        "    let first = spawnMonitored(Local, fn() = opener(port, me), Ended);\n"
        "    let orphan = opened();\n"
        "    receive { Ended(_) -> Unit };\n"
        "    Io.println(\"opener's: \" <> ends(orphan, 2000));\n"
        "    let keep = spawn(Local, keeper);\n"
        "    let _ = spawnMonitored(Local,\n"
        "                           fn() = giver(port, Process.fromAddress(keep), me),\n"
        "                           Ended);\n"
        "    let given = opened();\n"
        "    receive { Ended(_) -> Unit };\n"
        "    Io.println(\"given, giver gone: \" <> ends(given, 300));\n"
        "    send(keep, 1);\n"
        "    Io.println(\"given, keeper gone: \" <> ends(given, 2000));\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> {\n"
        "            Tcp.give(s, Process.fromAddress(first));\n"
        "            Io.println(\"given to the dead: \" <> ends(s, 2000))\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit with Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(listener) -> {\n"
        "        let _ = Either.map(Tcp.port(listener), check);\n"
        "        Tcp.closeListener(listener)\n"
        "    }\n"
        "  | Left(_) -> Unit\n"
        "}\n"),
    ?assertEqual(<<"opener's: ended\ngiven, giver gone: alive\ngiven, keeper gone: ended\n"
                   "given to the dead: ended\n">>, Out).

%% report §6.9, §6.6: a callee's own answer to a call is not overtaken by
%% its end, so a worker that answers and returns at once is answered, every
%% time. A regression test of what the report states (findings.md's N-B5);
%% the order of a `Down` and the ended process's own messages is not
%% promised, and so not tested
answer_before_end_test() ->
    {ok, Out} = run(
        "fn worker() : Unit with Reply(Int) = receive { r -> answer(r, 7) }\n"
        "fn rounds(n : Int, sum : Int) : Int with m =\n"
        "    if n == 0 then sum\n"
        "    else rounds(n - 1, sum + Address.callForever(spawn(Local, worker), fn(r) = r))\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(rounds(200, 0)))\n"),
    ?assertEqual(<<"1400\n">>, Out).

%% report §8.4: an address foreign code gives back is the program's own at
%% the type it went out at, and foreign at another, so that what is sent
%% through it is checked against the process's own type. A regression test:
%% the proxy was undone whatever the type it came back at, and a String
%% reached a process of Int (findings.md's C1-6)
retyped_address_test() ->
    {ok, Out} = run(
        "type Msg = Ended(Down)\n"
        "fn target() : Unit with Int = receive { n -> Io.println(\"got \" <> Int.toString(n)) }\n"
        "foreign fn retyped(addresses : List(Address(Int))) : Address(String) =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn same(addresses : List(Address(Int))) : Address(Int) =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit with Msg = {\n"
        "    let kept = spawn(Local, target);\n"
        "    send(same([kept]), 5);\n"
        "    let wronged = spawnMonitored(Local, target, Ended);\n"
        "    send(retyped([wronged]), \"x\");\n"
        "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"got 5\nFault(\"message does not match Int\")\n">>, Out).

%% report §8.4, Appendix E.12: an address given to foreign code in an
%% argument of its type crosses behind a proxy, which faults its process on
%% a message of another type; given as `Foreign.from` makes it, it crosses
%% as the runtime holds it, unchecked, until `Foreign.from` takes its
%% caller's description of the type (MVP 2.99b's item 13). A regression
%% test of what the report states (findings.md's C1-4)
foreign_from_crosses_unchecked_test() ->
    Main = "export fn main() : Unit with Int = {\n    let _ = ~s;\n"
           "    receive { _ -> Unit | after 200 -> Unit }\n}\n",
    Typed = "foreign fn rawSend(to : Address(Int), message : String) : String =\n"
            "    \"erlang:send/2\"\n",
    Untyped = "foreign fn rawSend(to : Foreign, message : String) : String =\n"
              "    \"erlang:send/2\"\n",
    Program = fun(Decl, Call) -> Decl ++ lists:flatten(io_lib:format(Main, [Call])) end,
    {Checked, _} = run(Program(Typed, "rawSend(self(), \"x\")")),
    ?assertMatch({fault, _}, Checked),
    {Unchecked, _} = run(Program(Untyped, "rawSend(Foreign.from(self()), \"x\")")),
    ?assertEqual(ok, Unchecked).

%% Appendix E.18, E.21, E.23: a listener, a socket and a running program are
%% processes of the program's: Process.live lists them, and Process.info
%% gives the function that opened each as its site. A regression test: the
%% runtime did not know them (findings.md's C10)
opened_processes_are_live_test() ->
    {ok, Out} = run([
        "fn site(p : Process) : String with m = match Process.info(p) {\n"
        "    Some(Process.Info(site = s, queued = _, activity = _)) -> s\n"
        "  | None -> \"none\"\n"
        "}\n"
        "fn listed(p : Process) : Bool with m = List.any(Process.live(), fn(q) = q == p)\n"
        "export fn main() : Unit with Never = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "            Right(c) -> {\n"
        "                let pl = Process.fromAddress(l);\n"
        "                let pc = Process.fromAddress(c);\n"
        "                Io.println(Io.show(#(site(pl), site(pc), listed(pl), listed(pc))));\n"
        "                match Os.start(Os.Command(program = \"cat\", arguments = [],"
        " input = <<>>), 5000) {\n"
        "                    Right(p) -> Io.println(site(Process.fromAddress(p)))\n"
        "                  | Left(e) -> Io.println(Io.show(e))\n"
        "                }\n"
        "            }\n"
        "          | Left(e) -> Io.println(Io.show(e))\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(\"Tcp.listen\", \"Tcp.connect\", true, true)\nOs.start\n">>, Out).

%% Appendix E.18: a write answers Right(Unit) once the socket has taken the
%% bytes, and Left(Closed) once the connection has closed; the far end's
%% close is learned here by a read, so that the answer does not depend on
%% when the host reports it
tcp_write_answers_closed_test() ->
    {ok, Out} = run([
        "export fn main() : Unit with Never = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let _ = spawn(Local, fn() : Unit with Never = match Tcp.accept(l, 5000) {\n"
        "                Right(s) -> {\n"
        "                    let _ = Tcp.read(s, 5000);\n"
        "                    Tcp.close(s)\n"
        "                }\n"
        "              | Left(_) -> Unit\n"
        "            });\n"
        "            match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "                Right(c) -> {\n"
        "                    let taken = Tcp.write(c, <<1>>);\n"
        "                    let ended = Tcp.read(c, 5000);\n"
        "                    Io.println(Io.show(#(taken, ended, Tcp.write(c, <<2>>))))\n"
        "                }\n"
        "              | Left(e) -> Io.println(Io.show(e))\n"
        "            }\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Left(Closed), Left(Closed))\n">>, Out).

%% report §8.2: a write to standard output returns once the stream has taken
%% it, so a program writing to a slow stream goes at its pace
io_write_waits_test() ->
    Me = self(),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'],
        "export fn main() : Unit with Never = {\n"
        "    let before = Clock.now();\n"
        "    List.foreach(List.range(1, 10), fn(n) = Io.println(Int.toString(n)));\n"
        "    Io.printlnError(Int.toString(Clock.now() - before))\n"
        "}\n"),
    {ok, Mod, Bin} = ern_emitter:compile(['M'], Typed, Iface, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    ok = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                         #{stdout => fun(_) -> timer:sleep(50) end,
                           stderr => fun(B) -> Me ! {err, B} end}),
    Elapsed = receive {err, B} -> binary_to_integer(string:trim(B)) after 5000 -> none end,
    ?assert(Elapsed >= 450).

%% report §8.5: a module the program does not depend on is not initialized,
%% though it is on the code path; a regression test for the shell's modules,
%% which every run initialized, before the standard library's
unrelated_module_not_initialized_test() ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['Aside'],
        "let noisy = Io.debug(\"initialized\")\n"),
    {ok, Mod, Bin} = ern_emitter:compile(['Aside'], Typed, Iface, Env),
    Dir = scratch(),
    ok = file:write_file(filename:join(Dir, atom_to_list(Mod) ++ ".beam"), Bin),
    true = code:add_patha(Dir),
    try
        ?assertEqual({ok, <<"ran\n">>},
                     run("export fn main() : Unit with Never = Io.println(\"ran\")\n"))
    after
        code:del_path(Dir),
        code:purge(Mod),
        code:delete(Mod)
    end.

sh(Cmd) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    sh_collect(Port, []).

sh_collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> sh_collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.

%% report §10: a tail call takes constant stack space, through the branches
%% of an `if`, the clauses of a `match`, and the last expression of a block:
%% ten million calls run in a process whose heap, its stack counted, may not
%% pass a hundred thousand words
tail_calls_constant_stack_test() ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'],
        "export fn count(n : Int, acc : Int) : Int =\n"
        "    if n == 0 then acc\n"
        "    else match n % 2 {\n"
        "        0 -> { let next = acc + 1; count(n - 1, next) }\n"
        "      | _ -> count(n - 1, acc + 1)\n"
        "    }\n"),
    {ok, Mod, Bin} = ern_emitter:compile(['M'], Typed, Iface, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    {_, Ref} = spawn_opt(fun() -> Me ! {counted, Mod:count(10000000, 0)} end,
                         [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                      error_logger => false}}]),
    Result = receive {counted, N} -> N; {'DOWN', Ref, process, _, Why} -> {died, Why} end,
    ?assertEqual(10000000, Result).

%% report §10: the right operand of `&&` and `||`, and the call a pipe
%% makes, are in tail position where their expression is, and take constant
%% stack space as the test above measures it. A regression test, written
%% after the report stated it: the emitter gave these the host's own tail
%% calls from the start
tail_calls_through_operators_test() ->
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(['M'],
        "export fn all(n : Int) : Bool =\n"
        "    n == 0 || (n > 0 && all(n - 1))\n"
        "export fn down(n : Int) : Int =\n"
        "    if n == 0 then 0 else n - 1 |> down\n"),
    {ok, Mod, Bin} = ern_emitter:compile(['M'], Typed, Iface, Env),
    {module, Mod} = code:load_binary(Mod, "test", Bin),
    Me = self(),
    Run = fun(F) ->
                  {_, Ref} = spawn_opt(fun() -> Me ! {ran, F()} end,
                                       [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                                    error_logger => false}}]),
                  receive {ran, V} -> V; {'DOWN', Ref, process, _, Why} -> {died, Why} end
          end,
    ?assertEqual(true, Run(fun() -> Mod:all(10000000) end)),
    ?assertEqual(0, Run(fun() -> Mod:down(10000000) end)).

%% report §10: processes are scheduled preemptively, so one that computes
%% for ever does not keep another from running; and Int has arbitrary
%% precision
preemption_and_precision_test() ->
    {ok, Out} = run(
        "fn spin(n : Int) : Int = spin(n + 1)\n"
        "fn power(b : Int, e : Int) : Int = if e == 0 then 1 else b * power(b, e - 1)\n"
        "export fn main() : Unit with Never = {\n"
        "    let w = spawn(Local, fn() : Unit with Never = { let _ = spin(0); Unit });\n"
        "    receive { after 50 -> Unit };\n"
        "    Io.println(Int.toString(power(2, 100)));\n"
        "    kill(w)\n"
        "}\n"),
    ?assertEqual(<<"1267650600228229401496703205376\n">>, Out).

%% report §6.2, §6.7: work on a peer is a process spawned there, and a peer
%% the node cannot reach faults the caller. A regression test, written
%% after the code; one node runs until MVP 3.0, so it does not cover a
%% peer that is reached
peer_unreachable_test() ->
    {R, _} = run(
        "export fn main() : Unit with Never = {\n"
        "    let _ = spawn(Peer(\"foo\"), fn() : Unit with Never = Unit);\n"
        "    Io.println(\"spawned\")\n"
        "}\n"),
    ?assertEqual({fault, <<"peer unreachable">>}, R).

%% report §6.9: kill on a process that has already ended has no effect,
%% and a monitor placed after the end answers Unknown, with no spawn site,
%% since the runtime keeps nothing of an ended process. A regression test,
%% written after the code; it does not cover kill on a system process
kill_dead_test() ->
    {ok, Out} = run(
        "type Msg = Died(Down)\n"
        "export fn main() : Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let w = spawn(Local, fn() : Unit with Never = { let _ = 1 / z; Unit });\n"
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
                                                 "export fn main() : Unit with Never = "
                                                 ++ Main ++ "\n")
              end,
    %% each refused for the reason the test names, not another; a
    %% regression test of the test, which took any error (findings.md's C39)
    ?assertMatch({error, [#diag{message = "unknown name Io.stdout"} | _]},
                 Refused("send(Io.stdout, String.toUtf8(\"hi\"))")),
    ?assertMatch({error, [#diag{message = "unknown name Sys.stdout"} | _]},
                 Refused("send(Sys.stdout, \"hi\")")),
    ?assertMatch({error, [#diag{message = "unknown constructor Clock.Now"} | _]},
                 Refused("{ let _ = Clock.Now; Unit }")).


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
                     "fn pick(xs : List(Int)) : Int = match xs { [three] -> three | _ -> 0 }\n"
                     "export fn main() : Unit with m = Io.println(Int.toString(three))\n")).
