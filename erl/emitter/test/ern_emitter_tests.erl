%% The emitter's tests: the code it makes and the programs it compiles,
%% run as the runner runs them (report §8.5, §11.2) by run/3, which the
%% other tests of programs share.
-module(ern_emitter_tests).

-export([run/1, run/2, run/3, run_at_terminal/1, scratch/0, write_golden/0, pair/0, funs/0, taken/0,
         opt/1, improper/1, remember/1, junk/1, good/1, tell/1, junk_server/0, hello_junk/0,
         hello_good/0, relay_junk/1, relay_good/1, same/1, call_nested_bad/1, call_nested_good/1,
         ask_junk/1, ask_good/1]).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").
-include_lib("typer/include/ern_types.hrl").

%%
%% Helpers
%%

%% Type-check, compile, load, initialize, and run a program's main as the
%% runner does, with an empty standard input, collecting what reaches
%% stdout.
run(Text) ->
    run(['M'], Text).

run(Namespace, Text) ->
    run(Namespace, Text, #{}).

%% The same with keys that can come, as at a terminal, of which none does.
run_at_terminal(Text) ->
    run(['M'], Text, #{keys => fun() -> receive after infinity -> eof end end}).

%% `standard => true` compiles the module as the standard library's own.
run(Namespace, Text, Options) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => [], standard => maps:get(standard, Options, false)},
    {ok, ErlangModule, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    %% standard error is read with standard output, where `Io.debug` writes
    %% (Appendix E.1), unless the test reads it apart
    Collect = fun(Written) -> Self ! {out, Written} end,
    Result = ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                             (maps:merge(#{stderr => Collect}, maps:remove(standard, Options)))
                                 #{init => fun() -> init(ErlangModule) end, stdout => Collect,
                                   stdin => fun() -> eof end}),
    {Result, collect([])}.

%% report §11: a declaration the checker would not have passed is a defect
%% of the toolchain, which the emitter raises as one, for `ern` to report
%% as its own failure, and never answers as a program's diagnostic. The
%% typed tree is the checker's with a block's last expression taken away,
%% as no program can write it. A regression test: the emitter answered a
%% diagnostic, which `make untested` found no test ever reached.
emitter_defect_test() ->
    {ok, Typed, Interface, Env} =
        ern_typecheck:check_string(['M'], "fn f() : Int = {\n    let x = 1;\n    x\n}\n"),
    Broken = without_last_statement(Typed),
    ?assertError({emitter_defect, _, "a block ends with a `let`"},
                 ern_emitter:compile(['M'], Broken, Interface, Env)).

without_last_statement(#e_block{statements = Statements} = Block) ->
    Block#e_block{statements = lists:droplast(Statements)};
without_last_statement(Node) when is_tuple(Node) ->
    list_to_tuple([without_last_statement(Element) || Element <- tuple_to_list(Node)]);
without_last_statement(Nodes) when is_list(Nodes) ->
    [without_last_statement(Element) || Element <- Nodes];
without_last_statement(Other) ->
    Other.

%% The runner's job (report §8.5): top-level lets before main.
init(ErlangModule) ->
    case erlang:function_exported(ErlangModule, '$init', 0) of
        true -> ErlangModule:'$init'();
        false -> ok
    end.

%% What a run ended with, its output left aside.
outcome(Text) ->
    {Result, _} = run(Text),
    Result.

collect(Acc) ->
    receive
        {out, Text} -> collect([Text | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

%% A directory of the test's own, for a program to leave a mark in, named
%% by the run and a count so that no earlier run's is read; the test
%% removes it once it has what it needs.
scratch() ->
    Dir = filename:join(os:getenv("TMPDIR", "/tmp"),
                        "ern_os_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

example(Base) ->
    {ok, Source} = file:read_file(source_file(Base)),
    {[list_to_atom(string:titlecase(Base))], Source}.

%% Two of the programs are examples a reader opens; the others are kept
%% for the tests.
source_file(Base) when Base =:= "hello"; Base =:= "services" ->
    "../../../examples/" ++ Base ++ ".ern";
source_file(Base) ->
    "../../../test/programs/" ++ Base ++ ".ern".

%% The forms of an example and of a target file, made comparable: no
%% annotations, and variables renamed in order of first occurrence, each
%% clause's pattern variables fresh in that clause, so that a hand-written
%% target may reuse a name across clauses where the emitter does not.
example_forms(Base) ->
    {Namespace, Source} = example(Base),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    normalize(ern_emitter:forms(Namespace, Typed, Env)).

target_forms(File) ->
    {ok, Forms} = epp:parse_file("../../../test/target/" ++ File, []),
    normalize([Form || Form <- Forms, not is_eof(Form), not is_file_attribute(Form)]).

is_eof({eof, _}) -> true;
is_eof(_) -> false.

is_file_attribute({attribute, _, file, _}) -> true;
is_file_attribute(_) -> false.

normalize(Forms) ->
    [normalized(Form) || Form <- Forms].

normalized(Form) ->
    {Renamed, _} = rename(Form, {#{}, 0}),
    erl_parse:map_anno(fun(_) -> 0 end, erl_syntax:revert(Renamed)).

%% State: {Name => New, Counter}.
rename(Node, {Names, Counter} = State) ->
    case erl_syntax:type(Node) of
        variable ->
            Name = erl_syntax:variable_name(Node),
            case Names of
                #{Name := New} -> {erl_syntax:variable(New), State};
                _ ->
                    New = list_to_atom("V" ++ integer_to_list(Counter)),
                    {erl_syntax:variable(New), {Names#{Name => New}, Counter + 1}}
            end;
        clause ->
            Patterns = erl_syntax:clause_patterns(Node),
            PatternVariables = lists:append([sets:to_list(erl_syntax_lib:variables(Pattern))
                                             || Pattern <- Patterns]),
            Inner = {maps:without(PatternVariables, Names), Counter},
            {Patterns1, State1} = lists:mapfoldl(fun rename/2, Inner, Patterns),
            {Guard, State2} = case erl_syntax:clause_guard(Node) of
                                  none -> {none, State1};
                                  GuardNode -> rename(GuardNode, State1)
                              end,
            {Body, {_, Next}} = lists:mapfoldl(fun rename/2, State2, erl_syntax:clause_body(Node)),
            {erl_syntax:clause(Patterns1, Guard, Body), {Names, Next}};
        _ ->
            case erl_syntax:subtrees(Node) of
                [] -> {Node, State};
                Groups ->
                    {Groups1, State1} =
                        lists:mapfoldl(fun(Group, Acc) ->
                                           lists:mapfoldl(fun rename/2, Acc, Group)
                                       end, State, Groups),
                    {erl_syntax:update_tree(Node, Groups1), State1}
            end
    end.

%%
%% Golden tests: the emitter reproduces the hand-written targets
%%

%% report §11, and docs/otp_bugs.md's report 3, the compiler's validator
%% refusing what its type pass made through rem: a module the host's own validator refuses,
%% its type pass narrowing a recursive function's parameter to a range the
%% call's argument breaks, is compiled again without that pass, and runs.
%% Written with the workaround; the shape is the one `make test-typed`
%% found (seed 74183997), reduced. It also holds that the host still
%% refuses the module, so that it fails, and says the workaround can go,
%% once an OTP with the fix runs it
validator_refusal_compiled_again_test() ->
    Text = "fn h(xs : List(Int), acc : Int) : Int =\n"
           "    match xs {\n"
           "        [] -> acc\n"
           "      | x :: rest -> h(rest, x % (x - 3))\n"
           "    }\n"
           "\n"
           "export fn main() : Unit with Never = Io.println(Int.toString(h([1000, -79], -62)))\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    Forms = ern_emitter:forms(['M'], Typed, Env),
    ?assertMatch({error, [{_, [{_, beam_validator, _} | _]}], _},
                 compile:noenv_forms(Forms, [return_errors])),
    ?assertEqual({ok, <<"-79\n">>}, run(Text)).

%% report §8.6, Appendix E.0 rule 1: a standard library function whose
%% effect is only a function's it is given is not counted as foreign code
%% while it runs, so that a deadlock in the function it was given is found.
%% Written with the rule that has the library stand on the host (MVP
%% 2.99d's item 12): such a primitive was counted, and a callback waiting
%% for what no one sends hid the deadlock, the program never ending
standard_shim_callback_deadlock_test_() ->
    {timeout, 30, fun standard_shim_callback_deadlock/0}.

standard_shim_callback_deadlock() ->
    Text = "foreign fn applied(f : (Int) -> Int with e, args : List(Int)) : Int with e =\n"
           "    \"erlang:apply/2\"\n"
           "\n"
           "export fn main() : Unit with Int =\n"
           "    Io.println(Int.toString(applied(fn(x : Int) : Int with Int = receive {\n"
           "        n -> n + x\n"
           "    }, [1])))\n",
    ?assertMatch({{fault, <<"deadlock">>}, _}, run(['M'], Text, #{standard => true})).

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
    ["hello", "counter", "upgrade", "pingpong", "stack", "patterns", "kv_parser", "services",
     "modules/net/http", "modules/main"].

%% report §4.6, §8.5, §11.1: a `let` is a value whatever its type, so one
%% that holds a function is reached through its getter and called by
%% applying what the getter answers, in its own module and in another; a
%% `fn` of the same type is called directly. The interface says which of
%% the two a name is.
let_of_function_type_test() ->
    {_, Output} = run("let g = fn() = 1\n"
                      "let h = fn(x : Int) = x + 1\n"
                      "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"
                      "export fn main() : Unit with m = {\n"
                      "    Io.println(Int.toString(g()));\n"
                      "    Io.println(Int.toString(h(2)));\n"
                      "    Io.println(Int.toString(twice(h, 0)))\n"
                      "}\n"),
    ?assertEqual(<<"1\n3\n2\n">>, Output).

%% report §4.6, §11.1: the same across modules, where the interface is all
%% the emitter has to tell a `let` from a `fn`
let_of_function_type_remote_test() ->
    {ok, DependencyTyped, DependencyInterface, DependencyEnv} =
        ern_typecheck:check_string(['M'], "export let g = fn() = 1\n"
                                          "export let h = fn(x : Int) = x + 1\n"
                                          "export fn f(x : Int) : Int = x * 2\n"),
    {ok, DependencyModule, DependencyBeam} = ern_emitter:compile(['M'], DependencyTyped,
                                                                 DependencyInterface,
                                                                 DependencyEnv),
    {module, DependencyModule} = code:load_binary(DependencyModule, "test", DependencyBeam),
    %% the interface the dependent is checked against is the compiled one
    {ok, #{interface := Interface}} = ern_interface:read(DependencyBeam),
    ?assertEqual([['M', g], ['M', h]], lists:sort(Interface#interface.lets)),
    {ok, Declarations} = ern_parser:parse_string(
        "export fn main() : Unit with m = {\n"
        "    Io.println(Int.toString(M.g()));\n"
        "    Io.println(Int.toString(M.h(2)));\n"
        "    Io.println(Int.toString(twice(M.h, 0)));\n"
        "    Io.println(Int.toString(M.f(3)))\n"
        "}\n"
        "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"),
    {ok, Typed, Interface2, Env} = ern_typecheck:check(['Main'], Declarations, [Interface]),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['Main'], Typed, Interface2, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                    #{init => fun() -> init(DependencyModule), init(ErlangModule) end,
                      stdout => fun(Text) -> Self ! {out, Text} end}),
    ?assertEqual(<<"1\n3\n2\n6\n">>, collect([])).

%% The source the compiler emits for an example; the modules pair is
%% checked in dependency order, main against http's interface.
golden_source("modules/" ++ _ = Name) ->
    {ok, HttpSource} = file:read_file("../../../test/programs/modules/net/http.ern"),
    {ok, HttpTyped, Checked, HttpEnv} = ern_typecheck:check_string(['Net', 'Http'], HttpSource),
    %% report §11.1: the interface as compiled, with its definitions' hashes
    Canonical = ern_canonical:module(['Net', 'Http'], HttpTyped, HttpEnv, false),
    HttpInterface = ern_canonical:interface(Checked, Canonical),
    case Name of
        "modules/net/http" ->
            emitted(['Net', 'Http'], HttpTyped, HttpEnv);
        "modules/main" ->
            {ok, MainSource} = file:read_file("../../../test/programs/modules/main.ern"),
            {ok, Declarations} = ern_parser:parse_string(MainSource),
            {ok, Typed, _, Env} = ern_typecheck:check(['Main'], Declarations, [HttpInterface]),
            emitted(['Main'], Typed, Env)
    end;
golden_source(Name) ->
    {Namespace, Source} = example(Name),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    emitted(Namespace, Typed, Env).

emitted(Namespace, Typed, Env) ->
    unicode:characters_to_binary(ern_emitter:erl_source(Namespace, Typed, Env)).

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
%% The test programs, hello and services run and print what their headers
%% promise
%%

%% report Appendix B
examples_test_() ->
    Expected = [{"hello", <<"hello, world\n">>},
                {"counter", <<"count is 8\n">>},
                {"upgrade", <<"before upgrade: 8\nafter upgrade: 10\n">>},
                {"pingpong", <<"ping 3\npong 3\nping 2\npong 2\nping 1\npong 1\n">>},
                {"stack", <<"top is 2\n">>},
                {"patterns", <<"minus one\nzero\nother\na 2\nnothing\n-3\n3\n4\n">>},
                {"kv_parser", <<"a 12\nbad key: =1\nexpected =: a\nbad number: a=x\n">>},
                {"services", <<"before: apples 3, next id 3, audit [1: put apples; 2: put pears]\n"
                               "after the restart: apples none, next id 1, audit []\n">>}],
    [{Base, fun() ->
                {Namespace, Source} = example(Base),
                ?assertEqual({ok, Output}, run(Namespace, Source))
            end} || {Base, Output} <- Expected].

%% report §11.1, §11.4: a compiled module without the Docs chunk reads as
%% an error that names the chunk and quotes no bytes. A regression test:
%% the host's text of the error was given, and it quotes the whole module.
docs_chunk_missing_test() ->
    {ok, _, Beam} = compile:forms([{attribute, 1, module, nodocs}], [binary]),
    ?assertEqual({error, "the module has no documentation chunk"}, ern_docs:read(Beam)).

%% report §11.1: the documentation travels in the BEAM chunk Docs, EEP 48's,
%% and a type's parts are structured in its entry rather than rendered
docs_chunk_test() ->
    Namespace = ['Shapes'],
    Source = <<"/// The module.\n\n"
               "/// A shape.\n"
               "export type Shape = Dot\n"
               "    /// somewhere\n"
               "    | At(\n"
               "        /// across\n"
               "        x : Int,\n"
               "        y : Int)\n"
               "export fn area(shape : Shape) : Int = 0\n">>,
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    Build = #{source_hash => <<>>, deps => [], source => <<"shapes.ern">>},
    {ok, 'ern@shapes', Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    {ok, {docs_v1, _, ernest, <<"text/markdown">>, ModuleDoc, Meta, Entries}} =
        ern_docs:read(Beam),
    ?assertEqual(#{<<"en">> => <<"The module.">>}, ModuleDoc),
    ?assertEqual(<<"shapes.ern">>, maps:get(source, Meta)),
    [{{type, 'Shape', 0}, _, Signature, Doc, TypeMeta},
     {{function, area, 1}, _, _, _, FunctionMeta}] = Entries,
    ?assertEqual([<<"type Shape = Dot | At(x : Int, y : Int)">>], Signature),
    ?assertEqual(#{<<"en">> => <<"A shape.">>}, Doc),
    ?assertEqual([#{kind => constructor, name => 'Dot', doc => none, fields => []},
                  #{kind => constructor, name => 'At', doc => <<"somewhere">>,
                    fields => [#{name => x, type => <<"Int">>, doc => <<"across">>},
                               #{name => y, type => <<"Int">>, doc => none}]}],
                 maps:get(items, TypeMeta)),
    ?assertEqual([shape], maps:get(params, FunctionMeta)),
    %% the interface chunk keeps its own shape, the source name being the
    %% documentation's
    {ok, Read} = ern_interface:read(Beam),
    ?assertEqual(false, is_map_key(source, Read)).

%% report §11.4, §3.4, §4.9: the Docs chunk keys a function by the arity
%% the module exports it at, a requirement's members among it, and writes
%% a function-typed result under an outer `with` in its parentheses. A
%% regression test: `unique/1` was keyed where `unique/2` is exported, and
%% the field's type was printed as another type
docs_chunk_keys_and_types_test() ->
    Namespace = ['Holders'],
    Source = <<"export type Msg = Go\n"
               "export type Holder = Holder(make : (Int) -> ((Int) -> Int) with Msg)\n"
               "export fn unique(list : List(a)) : List(a) needs a.compare =\n"
               "    OrderedSet.toList(OrderedSet.fromList(list))\n">>,
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    {ok, _, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, #{}),
    {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
    Keys = [Key || {Key, _, _, _, _} <- Entries],
    ?assert(lists:member({function, unique, 2}, Keys)),
    [Signature] = [Signature || {{type, 'Holder', 0}, _, Signature, _, _} <- Entries],
    ?assertEqual([<<"type Holder = Holder(make : (Int) -> ((Int) -> Int) with Msg)">>],
                 Signature).

%% report §11.1: the interface travels in the BEAM chunk ErnI
%% with the source hash and the dependencies' interface hashes, and its
%% hash does not depend on the numbering of type variables
interface_chunk_test() ->
    {Namespace, Source} = example("stack"),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    Build = #{source_hash => <<"s">>, deps => [{['Net', 'Http'], <<"h">>}]},
    {ok, 'ern@stack', Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    {ok, #{interface := Read, source_hash := <<"s">>, deps := [{['Net', 'Http'], <<"h">>}]}} =
        ern_interface:read(Beam),
    ?assertEqual(['Stack'], Read#interface.namespace),
    ?assert(is_map_key(['Stack', push], Read#interface.values)),
    ?assertEqual(ern_interface:hash(Interface), ern_interface:hash(Read)),
    {ok, _, Interface2, _} = ern_typecheck:check_string(Namespace,
                                                        <<"fn f(x) = x\n", Source/binary>>),
    ?assertEqual(ern_interface:hash(Interface), ern_interface:hash(Interface2)),
    %% nor on that of a type's parameters: a regression test, a private type
    %% declared before an exported one changed the exported one's numbers
    Shape = <<"export type Shape(a) = Circle(a) | Square(a)\n">>,
    {ok, _, Alone, _} = ern_typecheck:check_string(['Shape'], Shape),
    {ok, _, AfterHidden, _} =
        ern_typecheck:check_string(['Shape'], <<"type Hidden(b) = Hidden(b)\n\n", Shape/binary>>),
    ?assertEqual(ern_interface:hash(Alone), ern_interface:hash(AfterHidden)).

%% report §11.2: the interface chunk says whether the module builds a
%% function value, a function of its own code that may then be held
%% anywhere, by which the shell keeps an input's code: a lambda, a function
%% of the module taken as a value, a constructor taken as one, a member of
%% the module supplied to a requirement, a foreign function's result
%% checked as it crosses; and not a call, another module's function taken
%% as a value, nor a function the emitter makes and calls where it makes
%% it, a timed receive's, a guard's way to the clauses after it, or the
%% body pattern alternatives share. Written with the code
builds_functions_test() ->
    Builds = fun(Source) ->
                 Namespace = ['Builds'],
                 {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
                 {ok, _, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env),
                 {ok, #{builds_functions := Built}} = ern_interface:read(Beam),
                 {Source, Built}
             end,
    [?assertEqual({Source, true}, Builds(Source))
     || Source <- ["fn adder(n : Int) : (Int) -> Int = fn(m) = m + n\n",
                   "fn f(n : Int) : Int = n\nfn g() : (Int) -> Int = f\n",
                   "type Box = Box(Int)\nfn g() : (Int) -> Box = Box\n",
                   "type T = A | B derives compare\n"
                   "fn sorted(ts : List(T)) : List(T) =\n"
                   "    OrderedSet.toList(OrderedSet.fromList(ts))\n",
                   "foreign fn made() : (Int) -> Int = \"erlang:self/0\"\n"]],
    [?assertEqual({Source, false}, Builds(Source))
     || Source <- ["fn f(n : Int) : Int = n + 1\nfn g() : Int = f(2)\n",
                   "fn g() : (List(Int)) -> Int = List.size\n",
                   "fn w() : Unit with Int = receive { _ -> Unit | after 10 -> Unit }\n",
                   "fn h(n : Int) : Int = match n { 1 or 2 -> 0 | _ -> 1 }\n",
                   "fn big(m : Int) : Bool = m > 3\n"
                   "fn s(n : Int) : Int = match n { m when big(m) -> 0 | _ -> 1 }\n"]].

%% report §11.1: a chunk of another compiler version reads as an error,
%% so the module counts as stale; and the interface hash ignores the names
%% of type variables
stale_chunk_test() ->
    {Namespace, Source} = example("stack"),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    {ok, _, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env),
    {ok, {_, [{"ErnI", Chunk}]}} = beam_lib:chunks(Beam, ["ErnI"]),
    Old = term_to_binary((binary_to_term(Chunk))#{format => 0}),
    {ok, _, Stale} = compile:forms([{attribute, 1, module, x}],
                                   [binary, {extra_chunks, [{<<"ErnI">>, Old}]}]),
    ?assertMatch({error, _}, ern_interface:read(Stale)),
    {ok, _, InterfaceA, _} = ern_typecheck:check_string(['M'], "export fn id(x : a) : a = x\n"),
    {ok, _, InterfaceT, _} = ern_typecheck:check_string(['M'], "export fn id(x : t) : t = x\n"),
    ?assertEqual(ern_interface:hash(InterfaceA), ern_interface:hash(InterfaceT)).

%% report §11.1: --emit-erl gives the module as Erlang source
erl_source_test() ->
    {Namespace, Source} = example("hello"),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    Emitted = unicode:characters_to_binary(ern_emitter:erl_source(Namespace, Typed, Env)),
    ?assertMatch({_, _}, binary:match(Emitted, <<"-module(ern@hello).">>)).

%% report §4.2: the module atom is ern@ and the path with @ for /
erlang_module_test() ->
    ?assertEqual('ern@counter', ern_namespace:erlang_module(['Counter'])),
    ?assertEqual('ern@net@http', ern_namespace:erlang_module(['Net', 'Http'])),
    %% a segment of several words is its file's name, joined by `_`
    ?assertEqual('ern@ordered_set', ern_namespace:erlang_module(['OrderedSet'])),
    ?assertEqual('ern@net@http_client', ern_namespace:erlang_module(['Net', 'HttpClient'])).

%%
%% Blocks, bindings, and local functions
%%

%% report §4.6, §5.4: a local fn closes over earlier bindings and calls
%% itself; used as a value it becomes a closure
local_fn_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    let base = 10;\n"
        "    fn add(x : Int) : Int = base + x;\n"
        "    fn count(n : Int) : Int = if n == 0 then 0 else 1 + count(n - 1);\n"
        "    let ys = List.map([1, 2], add);\n"
        "    Io.println(Int.toString(List.foldLeft(ys, 0, fn(a, b) = a + b)));\n"
        "    Io.println(Int.toString(count(3)))\n"
        "}\n"),
    ?assertEqual(<<"23\n3\n">>, Output).

%% report §4.6, §5.4: a local fn sees the bindings in force at its
%% declaration, whatever is rebound after it, and through the local fns it
%% references, theirs; it may be used before its declaration
local_fn_bindings_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"12\n2\n6\n21\n">>, Output).

%% report §5.4, §5.11: a local fn is free in no block of its own, before
%% its declaration as after, and a pattern's size expression reads the
%% names around it, which a local fn captures. A regression test: both
%% crashed the emitter, looking up a name the free names had missed or kept
free_names_test() ->
    {ok, Output} = run(
        "fn width(n : Int, b : Bytes) : Int = {\n"
        "    fn read(x : Bytes) : Int = match x {\n"
        "        <<v:size(n), _:bytes>> -> v\n"
        "      | _ -> 0\n"
        "    };\n"
        "    read(b)\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    fn outer() : Int = {\n"
        "        fn first() : Int = second();\n"
        "        fn second() : Int = 1;\n"
        "        first()\n"
        "    };\n"
        "    let x = outer();\n"
        "    let second = 5;\n"
        "    Io.println(Int.toString(x + second + width(8, <<7, 1>>)))\n"
        "}\n"),
    ?assertEqual(<<"13\n">>, Output).

%% report §4.2, §5.4: a local fn reads the local binding, or calls the
%% local fn, that a top-level declaration's name names in its block. A
%% regression test: both crashed the emitter, which took the name for the
%% top-level one
local_name_over_top_level_test() ->
    {ok, Output} = run(
        "fn helper() : Int = 1\n"
        "export fn main() : Unit with Never = {\n"
        "    let helper = 5;\n"
        "    fn f() : Int = helper;\n"
        "    let base = 10;\n"
        "    fn g() : Int = later() + 1;\n"
        "    fn later() : Int = base;\n"
        "    Io.println(Int.toString(f() + g()))\n"
        "}\n"),
    ?assertEqual(<<"16\n">>, Output).

%% report §5.11: a pattern's size reads the scope before the pattern, not a
%% variable the same pattern binds elsewhere. A regression test: the
%% emitted Erlang read the tuple's own `n`, and did not compile
pattern_size_reads_the_outer_scope_test() ->
    {ok, Output} = run(
        "fn pick(n : Int, pair : #(Int, Bytes)) : Int = match pair {\n"
        "    #(n, <<x:size(n)>>) -> x + n\n"
        "  | _ -> 0\n"
        "}\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(pick(8, #(16, <<5>>))))\n"),
    ?assertEqual(<<"21\n">>, Output).

%% report §5.1, §5.11: a construction evaluates a segment's size once, in
%% order. A regression test: the size stood twice, its width checked and
%% its field built, and its effect happened twice
construction_size_once_test() ->
    {ok, Output} = run(
        "fn width() : Int with m = {\n    Io.println(\"width\");\n    16\n}\n"
        "fn value() : Int with m = {\n    Io.println(\"value\");\n    5\n}\n"
        "export fn main() : Unit with Never = {\n"
        "    let b = <<value():size(width()), 1:size(8)>>;\n"
        "    Io.println(Int.toString(Bytes.size(b)))\n"
        "}\n"),
    ?assertEqual(<<"value\nwidth\n3\n">>, Output).

%% report §2.3, §11.1: a name of §2.3's 255 characters compiles, the
%% emitter cutting the names it makes from it to the host's limit. A
%% regression test: a variable's Erlang name passed it and crashed the
%% emitter
longest_names_test() ->
    Variable = lists:duplicate(255, $a),
    Function = lists:duplicate(255, $b),
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    let " ++ Variable ++ " = 1;\n"
        "    fn " ++ Function ++ "() : Int = " ++ Variable ++ " + 1;\n"
        "    Io.println(Int.toString(" ++ Function ++ "()))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Output).

%% report §5.1: a list literal of more calls than the host keeps live at
%% one, and a long tuple, are built with their elements evaluated first to
%% last. A regression test: the host's compiler refused the module
long_literals_test_() ->
    {timeout, 60, fun long_literals/0}.

long_literals() ->
    Calls = lists:join(", ", ["f(" ++ integer_to_list(N) ++ ")" || N <- lists:seq(1, 1100)]),
    Numbers = lists:join(", ", [integer_to_list(N) || N <- lists:seq(1, 300)]),
    {ok, Output} = run(
        "fn f(n : Int) : Int with m = {\n"
        "    if n == 1 || n == 1100 then Io.println(Int.toString(n)) else Unit;\n"
        "    n\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let calls = [" ++ Calls ++ "];\n"
        "    Io.println(Io.show(#(List.size(calls), List.last(calls))));\n"
        "    Io.println(Io.show(#(" ++ Numbers ++ ")))\n"
        "}\n"),
    ?assertEqual(iolist_to_binary(["1\n1100\n#(1100, Some(1100))\n#(", Numbers, ")\n"]),
                 Output).

%% report §5.1: a call's arguments, a tuple's and a list's elements and an
%% operator's operands are evaluated left to right. Written after the
%% code, which leaves the order to the host's compiler, so that a change of
%% the host's order fails here
order_of_evaluation_test() ->
    {ok, Output} = run(
        "fn say(word : String, n : Int) : Int with m = {\n"
        "    Io.println(word);\n"
        "    n\n"
        "}\n"
        "fn pair(x : Int, y : Int) : Int = x + y\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = pair(say(\"call 1\", 1), say(\"call 2\", 2));\n"
        "    let _ = #(say(\"tuple 1\", 1), say(\"tuple 2\", 2));\n"
        "    let _ = [say(\"list 1\", 1), say(\"list 2\", 2)];\n"
        "    let _ = say(\"operand 1\", 1) + say(\"operand 2\", 2);\n"
        "    let _ = say(\"compared 1\", 1) < say(\"compared 2\", 2);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"call 1\ncall 2\ntuple 1\ntuple 2\nlist 1\nlist 2\noperand 1\n"
                   "operand 2\ncompared 1\ncompared 2\n">>, Output).

%% report §4.6: shadowing rebinds; each binding is its own variable
shadowing_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    let x = 1;\n"
        "    let x = x + 1;\n"
        "    let #(x, y) = #(x * 10, x);\n"
        "    Io.println(Int.toString(x + y))\n"
        "}\n"),
    ?assertEqual(<<"22\n">>, Output).

%% report §5.5, §7.1: a value error is an Either or Optional; `<-` on Either
%% returns the Left, on Optional the None
bind_arrow_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"2\nodd\n3\n-1\n">>, Output).

%% report §4.6, §8.5: top-level lets are evaluated before main, in
%% dependency order whatever their textual order, a dependency through a
%% called function included
top_level_let_test() ->
    {ok, Output} = run(
        "let total = base * 2\n"
        "let base = count()\n"
        "fn count() : Int = List.size(items)\n"
        "let items = [1, 2, 3]\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"6\n">>, Output).

%%
%% Expressions
%%

%% report §5.9, §5.10: a guard that is not an Erlang guard falls through
%% to the next clause
match_general_guard_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"small\neven\nodd\n">>, Output).

%% report §5.9: a guard that faults faults the process; it never becomes a
%% silent `false` as an Erlang guard would, since only comparisons that
%% cannot fault are emitted as Erlang guards and every other guard runs as
%% an expression that falls through on `false` alone
match_guard_faults_test() ->
    {Result, _} = run(
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
    ?assertEqual({fault, <<"division by zero">>}, Result).

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
    {ok, Output} = run(Shape ++ Kind ++
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
    ?assertEqual(<<"1\n20\n0\nsized\ndot\n">>, Output),
    {Result, _} = run(Shape ++ Kind ++
             "export fn main() : Unit with Never = Io.println(kind(Circle(0)))\n"),
    ?assertEqual({fault, <<"division by zero">>}, Result).

%% report Appendix E.1: Io.debug prints a value as Ernest writes it, by the
%% argument's type at the call, known whole there, and returns it; a type
%% variable there is a type error (ern_typecheck_tests)
io_debug_test() ->
    {ok, Output} = run(
        "type Shape = Circle(Int) | Dot\n"
        "type Snap = Snap(seen : Int, dir : String)\n"
        "type State = Ready | Busy\n"
        "export fn main() : Unit with Never = {\n"
        "    let n = Io.debug(4) + 1;\n"
        "    let _ = Io.debug(n);\n"
        "    let _ = Io.debug([Circle(-3), Dot]);\n"
        "    let _ = Io.debug(#(1.5, \"a\\nb\", true, Unit));\n"
        "    let _ = Io.debug(Snap(dir = \"x\", seen = 2));\n"
        "    let _ = Io.debug(Map.put(Map.empty, \"k\", [1]));\n"
        "    let _ = Io.debug(Set.fromList([2, 1]));\n"
        "    let _ = Io.debug(fn(x : Int) = x);\n"
        "    let _ = Io.debug(#(true, false));\n"
        "    let _ = Io.debug(\"é中\");\n"
        "    let _ = Io.debug(#('a', '\\'', Some('\\n')));\n"
        "    let _ = Io.debug(#(Ready, 1));\n"
        "    let _ = Io.debug(<<104, 105>>);\n"
        "    let _ = List.map(['x'], Io.debug);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"4\n5\n[Circle(-3), Dot]\n#(1.5, \"a\\nb\", true, Unit)\n"
                   "Snap(seen = 2, dir = \"x\")\n"
                   "Map.fromList([#(\"k\", [1])])\nSet.fromList([1, 2])\n<function>\n"
                   "#(true, false)\n\"é中\"\n#('a', '\\'', Some('\\n'))\n#(Ready, 1)\n"
                   "<<104, 105>>\n'x'\n"/utf8>>, Output).

%% report Appendix E.1: Io.show writes a value by its type at the call, as
%% a function value too, and pure
show_test() ->
    {ok, Output} = run(
        "type Snap = Snap(seen : Int, dir : String)\n"
        "fn pure(c : Char) : String = Io.show(Some(c))\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Io.show(Snap(dir = \"x\", seen = 2)));\n"
        "    Io.println(pure('a'));\n"
        "    Io.println(String.join(List.map([<<1>>, <<2, 3>>], Io.show), \" \"))\n"
        "}\n"),
    ?assertEqual(<<"Snap(seen = 2, dir = \"x\")\nSome('a')\n<<1>> <<2, 3>>\n">>, Output).

%% report §4.2, §4.5: a module's own type named Float may have members
%% negate and compare, and a call of them, each as a value, and prefix `-`
%% on the type are the module's. A regression test, rewritten when a member
%% became an operator, `compare` or `negate`: it held the same of `Io.show`
%% and `Io.debug`, where the emitter read the written path and called the
%% library's in their place
own_member_over_prelude_test() ->
    {ok, Output} = run(
        "type Float = Float(n : Int)\n"
        "fn Float.negate(x : Float) : String = \"mine \" <> Int.toString(x.n)\n"
        "fn Float.compare(a : Float, b : Float) : Ordering = Less\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Float.negate(Float(n = 1)));\n"
        "    let f = Float.negate;\n"
        "    Io.println(f(Float(n = 2)));\n"
        "    Io.println(-Float(n = 3));\n"
        "    Io.println(Io.show(Float.compare(Float(n = 1), Float(n = 1))))\n"
        "}\n"),
    ?assertEqual(<<"mine 1\nmine 2\nmine 3\nLess\n">>, Output).

%% report Appendix E.1: Io.debug writes a String as a literal, with `"`,
%% `\\`, a line feed and a tab escaped by name, another control character
%% by its code point, and every other character as itself. A regression
%% test, written after the code; it does not cover a character outside
%% the Basic Multilingual Plane
io_debug_escapes_test() ->
    {ok, Output} = run("export fn main() : Unit with Never = {\n"
                       "    let _ = Io.debug(\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\");\n"
                       "    Unit\n"
                       "}\n"),
    ?assertEqual(<<"\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\"\n"/utf8>>, Output).

%% report §6.3, §6.6, Appendix E.0 rule 8: a time below 0 is 0, in `after`,
%% in `Address.call`, and in `Clock.alarm`. A regression test: the first two
%% faulted with the host's `timeout_value`, and the alarm crashed the clock,
%% which left the program waiting for ever
negative_time_test() ->
    {ok, Output} = run("type M = M | Get(reply : Reply(Int))\n"
                       "export fn main() : Unit with M = {\n"
                       "    receive { Get(reply = r) -> answer(r, 1) | after 0 - 5 ->"
                       " Io.println(\"after\") };\n"
                       "    let quiet = spawn(fn() : Unit with M = receive { M -> Unit });\n"
                       "    let asked = Address.call(quiet, fn(r) = Get(reply = r), 0 - 1);\n"
                       "    Io.println(match asked { Some(_) -> \"some\" | None -> \"none\" });\n"
                       "    Clock.alarm(0 - 10, fn(_) = M);\n"
                       "    receive { M -> Io.println(\"alarm\") | Get(reply = r) -> answer(r, 0)"
                       " }\n"
                       "}\n"),
    ?assertEqual(<<"after\nnone\nalarm\n">>, Output).

%% report §6.3, §6.6, Appendix E.0 rule 8: a time has no upper bound, so a
%% time beyond the host's longest wait, 2^32 - 1 ms, waits as any other: a
%% message that comes after 50 ms is received, a call is answered, and a
%% file is read. A regression test: each faulted with the host's
%% timeout_value. The message and the answer come once the waiting side
%% waits, so that each wait is made with its time. It does not cover a wait
%% that outlasts one slice of 2^32 - 1 ms, nor an alarm, which ern_rt_tests
%% covers
long_time_test() ->
    {ok, Output} = run(
        "type Msg = Ping | Go | Get(reply : Reply(Int), caller : Process)\n"
        "foreign fn waiting(process : Process) : Foreign.Term with m = \"ern_waits:waiting/1\"\n"
        "fn later(to : Address(Msg)) : Unit with Msg = {\n"
        "    receive { Go -> Unit };\n"
        "    let _ = waiting(Process.fromAddress(to));\n"
        "    send(to, Ping)\n"
        "}\n"
        "fn server() : Unit with Msg = receive {\n"
        "    Get(reply = r, caller = c) -> { let _ = waiting(c); answer(r, 7) }\n"
        "  | Ping -> Unit\n"
        "  | Go -> Unit\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
        "    let me = self();\n"
        "    let sender = spawn(fn() = later(me));\n"
        "    send(sender, Go);\n"
        "    receive {\n"
        "        Ping -> Io.println(\"ping\")\n"
        "      | after 5000000000 -> Io.println(\"after\")\n"
        "    };\n"
        "    let a = spawn(server);\n"
        "    let caller = Process.fromAddress(me);\n"
        "    let _ = Io.debug(Address.call(a, fn(r) = Get(reply = r, caller = caller),"
        " 5000000000));\n"
        "    match Fs.read(Path(\"../../../VERSION\"), 5000000000) {\n"
        "        Right(_) -> Io.println(\"read\")\n"
        "      | Left(_) -> Io.println(\"not read\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"ping\nSome(7)\nread\n">>, Output).

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
                 run(Forever("    let s = spawn(faulty);\n"))),
    ?assertMatch({{fault, <<"callee was killed">>}, _},
                 run(Forever("    let s = spawn(quiet);\n"
                             "    let _ = spawn(fn() : Unit with Never =\n"
                             "        receive { after 50 -> kill(s) });\n"))),
    ?assertMatch({{fault, <<"callee returned without answering">>}, _},
                 run(Forever("    let s = spawn(waits);\n"
                             "    let _ = spawn(fn() : Unit with Never =\n"
                             "        receive { after 50 -> send(s, Stop) });\n"))),
    ?assertMatch({{fault, <<"callee had ended">>}, _},
                 run(Forever("    let s = spawnMonitored(fn() : Unit with Msg = Unit,\n"
                             "        Died);\n"
                             "    receive { Died(_) -> Unit };\n"))),
    ?assertMatch({{fault, <<"bad request">>}, _},
                 run(Forever("    let limit = RestartLimit(restarts = 5, within = 60000);\n"
                             "    let s = spawn(restarting(limit, faulty));\n"))),
    {ok, Output} = run(Types ++ Faulty ++
                       "export fn main() : Unit with MainMsg = {\n"
                       "    let limit = RestartLimit(restarts = 5, within = 60000);\n"
                       "    let s = spawn(restarting(limit, faulty));\n"
                       "    let t = spawn(faulty);\n"
                       "    let _ = Io.debug(Address.call(s, " ++ Ask ++ ", 60000));\n"
                       "    let _ = Io.debug(Address.call(t, " ++ Ask ++ ", 60000));\n"
                       "    Unit\n"
                       "}\n"),
    ?assertEqual(<<"None\nNone\n">>, Output).

%% report §4.6, §6.5, §8.5: a service is a top-level binding whose
%% initializer spawns the process, before main, in the entry process;
%% functions reach it by its name, and a restarting one keeps its address
service_binding_test() ->
    {ok, Output} = run(
        "export type LogMsg = Log(String) | Crash | Count(reply : Reply(Int))\n"
        "fn logger(n : Int) : Unit with LogMsg = receive {\n"
        "    Log(_) -> logger(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Count(reply = r) -> { answer(r, n); logger(n) }\n"
        "}\n"
        "export let log : Address(LogMsg) =\n"
        "    spawn(restarting(RestartLimit(restarts = 3, within = 60000),\n"
        "                     fn() : Unit with LogMsg = logger(0)))\n"
        "let started = Io.println(\"started\")\n"
        "fn note(s : String) : Unit with m = send(log, Log(s))\n"
        "fn counted() : Int with m = match Address.call(log, fn(r) = Count(reply = r), 1000) {\n"
        "    Some(n) -> n\n"
        "  | None -> counted()\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    note(\"a\");\n"
        "    send(log, Crash);\n"
        "    // answered by the new run, whose start empties the mailbox (§6.9); a\n"
        "    // call the restart ends is made again\n"
        "    let _ = counted();\n"
        "    note(\"b\");\n"
        "    Io.println(Int.toString(counted()))\n"
        "}\n"),
    ?assertEqual(<<"started\n1\n">>, Output).

%% report §6.9, §8.5: a process a top-level initializer spawns names that
%% binding's declaration as its spawn site
service_site_test() ->
    {ok, Output} = run(
        "type MainMsg = Died(Down)\n"
        "export let quick : Address(Int) =\n"
        "    spawn(fn() : Unit with Int = receive { _ -> fault(\"x\") })\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    monitor(Process.fromAddress(quick), Died);\n"
        "    send(quick, 1);\n"
        "    receive { Died(Down(reason = _, site = s)) -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"M.quick:3\n">>, Output).

%% Appendix E.15, §5.6: an alarm carries the time it fired, so a
%% single-positional constructor passes as its wrap, as `Died` does to
%% `monitor`
alarm_time_test() ->
    {ok, Output} = run("type Msg = Tick(Int)\n"
                       "export fn main() : Unit with Msg = {\n"
                       "    let before = Clock.now();\n"
                       "    Clock.alarm(5, Tick);\n"
                       "    receive { Tick(at) -> Io.println(Bool.toString(at >= before)) }\n"
                       "}\n"),
    ?assertEqual(<<"true\n">>, Output).

%% report §5.9, §6.3: alternatives in a receive clause select either message
receive_or_pattern_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"5\n">>, Output).

%% report §6.3: a receive guard is a guard expression, emitted as an Erlang
%% guard, tested while the message stays in the mailbox
receive_guard_test() ->
    {ok, Output} = run(
        "type Msg = N(Int)\n"
        "type Seen = Ended(Down)\n"
        "fn loop(acc : Int) : Unit with Msg = receive {\n"
        "    N(k) when k > 0 -> loop(acc + k)\n"
        "  | N(_) -> Io.println(Int.toString(acc))\n"
        "}\n"
        "export fn main() : Unit with Seen = {\n"
        "    let p = spawn(fn() = loop(0));\n"
        "    monitor(Process.fromAddress(p), Ended);\n"
        "    send(p, N(2));\n"
        "    send(p, N(3));\n"
        "    send(p, N(0));\n"
        "    receive { Ended(_) -> Unit }\n"
        "}\n"),
    ?assertEqual(<<"5\n">>, Output).

%% report §6.3: a compound guard expression; a message the guard rejects
%% stays in the mailbox
receive_guard_compound_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"9\n">>, Output).

%% report §6.3: `!` before a guard expression and a negative literal in a
%% receive guard, emitted as an Erlang guard; the messages the guard
%% rejects stay in the mailbox
receive_guard_not_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"2\n100\n-4\n">>, Output).

%% report §5.9, §4.6: a match guard may read a top-level `let`, which is
%% read through its getter, so the guard is not compiled as an Erlang guard
match_guard_top_level_let_test() ->
    {ok, Output} = run(
        "let limit = 5\n"
        "fn size(n : Int) : String = match n { m when m > limit -> \"big\" | _ -> \"small\" }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(size(9));\n"
        "    Io.println(size(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Output).

%% report §3.1, §4.8, §9.6: Int arithmetic, comparison, and the Boolean
%% operators
operators_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(-7 / 3));\n"
        "    Io.println(Int.toString(-7 % 3));\n"
        "    Io.println(Int.toString(2 + 3 * 4 - 1));\n"
        "    Io.println(Bool.toString(1 < 2 && 2 <= 2 && 3 > 2 && 3 >= 3));\n"
        "    Io.println(Bool.toString(1 == 2 || 1 != 2));\n"
        "    Io.println(Bool.toString(\"a\" < \"b\"));\n"
        "    Io.println(Int.toString(List.size(1 :: [2] <> [3])))\n"
        "}\n"),
    ?assertEqual(<<"-2\n-1\n13\ntrue\ntrue\ntrue\n3\n">>, Output).

%% report §3.1, §5.1, §9.6, Appendix E.9: Float arithmetic, negation, and
%% ordering; the Float functions of E.9
float_operators_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Float.toString(1.5 + 2.25 * 2.0 - 1.0 / 4.0));\n"
        "    Io.println(Float.toString(-(1.0e-9)));\n"
        "    Io.println(Bool.toString(1.5 < 2.0 && 2.0 <= 2.0 && 3.5 > 2.0 && 3.0 >= 3.0));\n"
        "    Io.println(Int.toString(Float.round(2.5) + Float.round(3.5) + Float.floor(-0.5)"
        " + Float.ceil(0.5)));\n"
        "    Io.println(Float.toString(Int.toFloat(3)))\n"
        "}\n"),
    ?assertEqual(<<"5.75\n-1.0e-9\ntrue\n6\n3.0\n">>, Output).

%% report §3.1, §7.4: a Float result outside the finite range faults with
%% its own cause, distinct from the Int zero divisor
float_fault_test() ->
    Zero = "fn zero() : Float = Int.toFloat(List.size([]))\n",
    {Result1, _} = run(Zero ++ "export fn main() : Unit with Never = "
                       "Io.println(Float.toString(1.0 / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, Result1),
    {Result2, _} = run(Zero ++ "export fn main() : Unit with Never = "
                       "Io.println(Float.toString((zero() + 1.0e308) * 10.0))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, Result2),
    {Result3, _} = run(Zero ++ "export fn main() : Unit with Never = "
                       "Io.println(Float.toString(zero() / zero()))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, Result3),
    %% an Int zero divisor inside a Float operand keeps its own cause
    {Result4, _} = run("fn n() : Int = List.size([])\n"
                       "export fn main() : Unit with Never = "
                       "Io.println(Float.toString(Int.toFloat(1 / n()) + 1.0))\n"),
    ?assertEqual({fault, <<"division by zero">>}, Result4),
    %% Float.+ taken as a value faults the same way
    {Result5, _} = run("export fn main() : Unit with Never = "
                       "Io.println(Float.toString(List.foldLeft([1.0e308, 1.0e308], 0.0,"
                       " Float.+)))\n"),
    ?assertEqual({fault, <<"float arithmetic error">>}, Result5).

%% report §3.1: there is no negative zero; an operation, a negation, a
%% float segment, parsed text, and a foreign value give 0.0. A sum or a
%% difference is not normalized, and gives 0.0 all the same
no_negative_zero_test() ->
    {ok, Output} = run(
        "foreign fn parse(s : String) : Float = \"erlang:binary_to_float/1\"\n"
        "fn tiny() : Float = 1.0e-300\n"
        "export fn main() : Unit with Never = {\n"
        "    let z = 0.0;\n"
        "    let _ = Io.debug(#(z * -1.0, -z, z / -2.0, -tiny() * tiny()));\n"
        "    let _ = Io.debug(#(-5.0 + 5.0, 5.0 - 5.0, -z - z, -1.0e-200 * 1.0e-200));\n"
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
    ?assertEqual(<<"#(0.0, 0.0, 0.0, 0.0)\n#(0.0, 0.0, 0.0, 0.0)\ntrue\n1\n0.0\n\"zero\"\n"
                   "Some(0.0)\n0.0\n\"guard\"\n0.0\n">>, Output).

%% report §3.1, §8.4: a negative zero inside a value foreign code returns,
%% or inside a message it sends, is 0.0, as a float returned alone is. A
%% regression test, written after the code: the check rebuilt every value
%% whose type holds a float, a negative zero in it or not, which cost more
%% than the host's work it checked; now a float matches only where it is
%% no negative zero, and a value that fails so is made again. It does not
%% show that a value holding none is walked once
foreign_negative_zero_test() ->
    {ok, Output} = run(
        "foreign fn decoded(bytes : Bytes) : List(#(String, Float)) =\n"
        "    \"erlang:binary_to_term/1\"\n"
        "foreign fn term(bytes : Bytes) : Foreign.Term = \"erlang:binary_to_term/1\"\n"
        "foreign fn send(to : Address(List(Float)), message : Foreign.Term) : Foreign.Term =\n"
        "    \"erlang:send/2\"\n"
        "export fn main() : Unit with List(Float) = {\n"
        "    let pairs = decoded(<<131, 108, 0, 0, 0, 2, 104, 2, 109, 0, 0, 0, 1, 97, 70,"
        " 128, 0, 0, 0, 0, 0, 0, 0, 104, 2, 109, 0, 0, 0, 1, 98, 70, 63, 248, 0, 0, 0, 0, 0,"
        " 0, 106>>);\n"
        "    let _ = Io.debug(pairs == [#(\"a\", 0.0), #(\"b\", 1.5)]);\n"
        "    let _ = send(self(), term(<<131, 108, 0, 0, 0, 2, 70, 128, 0, 0, 0, 0, 0, 0, 0, 70,"
        " 63, 248, 0, 0, 0, 0, 0, 0, 106>>));\n"
        "    receive {\n"
        "        floats -> { let _ = Io.debug(floats == [0.0, 1.5]); Unit }\n"
        "    }\n"
        "}\n"),
    %% `==` is exact, and tells the host's two zeros apart, where `Io.debug`
    %% writes both 0.0
    ?assertEqual(<<"true\ntrue\n">>, Output).

%% report §5.1: a callee is evaluated before its arguments; in `x |> e`,
%% x is evaluated before e, a callee a call computes among it
evaluation_order_test() ->
    {ok, Output} = run(
        "fn show(s : String, n : Int) : Int with Never = { Io.println(s); n }\n"
        "fn f(a : Int) : ((Int, Int) -> Int) with Never = {\n"
        "    Io.println(\"f(a)\");\n"
        "    fn(x, y) = x + y + a\n"
        "}\n"
        "fn g(a : Int) : ((Int) -> Int) with Never = { Io.println(\"g(1)\"); fn(x) = x + a }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(show(\"x\", 1) |> f(show(\"a\", 2))(show(\"b\", 3))));\n"
        "    Io.println(Int.toString(g(1)(show(\"h()\", 4))))\n"
        "}\n"),
    ?assertEqual(<<"x\na\nf(a)\nb\n6\ng(1)\nh()\n5\n">>, Output).

%% report §4.8: `!` negates a Bool, in an expression and in a guard
not_operator_test() ->
    {ok, Output} = run(
        "fn small(n : Int) : String = match n { m when !(m > 5) -> \"small\" | _ -> \"big\" }\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = Io.debug(!true);\n"
        "    let _ = Io.debug(List.filter([1, 2, 3, 4], fn(n) = !(n % 2 == 1)));\n"
        "    let _ = Io.debug(small(3));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"false\n[2, 4]\n\"small\"\n">>, Output).

%% report §4.8, §3.10, §5.1: a user type's operator is its member, its
%% ordering goes through its compare, and prefix - through its negate
user_operators_test() ->
    Vec = "export type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) : Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = Int.compare(b, a)\n"
          "export fn Vec.negate(Vec(a)) : Vec = Vec(-a)\n"
          "fn show(Vec(n)) : String = Int.toString(n)\n",
    {ok, Output} = run(Vec ++
        "export fn main() : Unit with Never = {\n"
        "    let a = Vec(1);\n"
        "    let b = Vec(2);\n"
        "    Io.println(show(-(a + b)));\n"
        "    Io.println(Float.toString((a * b) + 0.5));\n"
        "    Io.println(Bool.toString(a < b));\n"
        "    Io.println(Bool.toString(a >= b && b <= a && a > b))\n"
        "}\n"),
    ?assertEqual(<<"-3\n2.5\nfalse\ntrue\n">>, Output).

%% report §8.5: a top-level let evaluated through an operator's member
%% comes after the lets that member reads
let_order_through_operator_test() ->
    {ok, Output} = run(
        "export type Vec = Vec(Int)\n"
        "let sum = Vec(1) + Vec(2)\n"
        "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec((a + b) * scale)\n"
        "let scale = 10\n"
        "fn show(Vec(n)) : String = Int.toString(n)\n"
        "export fn main() : Unit with Never = Io.println(show(sum))\n"),
    ?assertEqual(<<"30\n">>, Output).

%% report §8.5, §4.9, §5.6, §3.5: a top-level let comes after the lets a
%% member reads that a requirement supplies in its initializer, at a call,
%% in a fill, and through a derived compare. A regression test: only an
%% operator's member was counted, and `sorted` read `scale` before it had a
%% value
let_order_through_supplied_member_test() ->
    {ok, Output} = run(
        "type T = T(Int)\n"
        "type P = P(t : T) derives compare\n"
        "type Ops(a) = Ops(fromList : (List(a)) -> OrderedSet.Set(a))\n"
        "let sorted = OrderedSet.toList(OrderedSet.fromList([T(2), T(1)]))\n"
        "let filled = {\n"
        "    let ops : Ops(T) = Ops(..OrderedSet);\n"
        "    OrderedSet.toList(ops.fromList([T(4), T(3)]))\n"
        "}\n"
        "let derived = OrderedSet.toList(OrderedSet.fromList([P(t = T(6)), P(t = T(5))]))\n"
        "fn T.compare(T(a) : T, T(b) : T) : Ordering = Int.compare(a * scale, b * scale)\n"
        "let scale = 1\n"
        "export fn main() : Unit with Never =\n"
        "    Io.println(Io.show(#(sorted, filled, derived)))\n"),
    ?assertEqual(<<"#([T(1), T(2)], [T(3), T(4)], [P(t = T(5)), P(t = T(6))])\n">>, Output).

%% report §8.5: a top-level let is evaluated after the lets it depends
%% on, and otherwise in the order the module declares it. A regression
%% test: the order of independent lets was the digraph's, which moved with
%% unrelated changes, and `:reload` kept an unpredictable set of values
let_order_declared_test() ->
    {ok, Output} = run(
        "let a = { Io.println(\"a\"); 1 }\n"
        "let c = { Io.println(\"c\"); b + 1 }\n"
        "let b = { Io.println(\"b\"); 2 }\n"
        "let d = { Io.println(\"d\"); 4 }\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(a + c + d))\n"),
    ?assertEqual(<<"a\nb\nc\nd\n8\n">>, Output).

%% report §4.7, §8.4: a foreign fn calls its implementation with the
%% arguments as the ABI maps them, and a foreign type's values pass through
%% unchecked
foreign_fn_test() ->
    {ok, Output} = run(
        "foreign type Table\n"
        "foreign fn size(s : String) : Int = \"erlang:byte_size/1\"\n"
        "foreign fn atom(s : String) : Foreign.Term = \"erlang:binary_to_atom/1\"\n"
        "foreign fn newTable(n : Foreign.Term, o : List(Foreign.Term)) : Table with m =\n"
        "    \"ets:new/2\"\n"
        "foreign fn insert(t : Table, row : #(Int, String)) : Bool with m = \"ets:insert/2\"\n"
        "foreign fn lookup(t : Table, k : Int) : List(#(Int, String)) with m = \"ets:lookup/2\"\n"
        "foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) : Foreign.Term with m"
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
    ?assertEqual(<<"one\n3\n1\n2\n3\n">>, Output).

%% report §4.7, §8.4: a foreign return whose type holds the same user type
%% twice, side by side, is checked; each is described in full
foreign_sibling_types_test() ->
    {ok, Output} = run(
        "foreign fn pair(xs : List(Optional(Int))) : #(Optional(Int), Optional(Int))"
        " = \"erlang:list_to_tuple/1\"\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = Io.debug(pair([Some(1), None]));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(Some(1), None)\n">>, Output).

%% report §4.7, §7.4, §8.4: a return of another shape faults on first
%% observation, naming the declared type; a nested breach is found; an
%% exception is a fault naming the implementation; an Ernest fault raised
%% inside foreign code passes through as itself
foreign_faults_test() ->
    Main = "export fn main() : Unit with Never = ",
    {Result1, _} = run("foreign fn bad() : Int = \"erlang:node/0\"\n"
                       ++ Main ++ "Io.println(Int.toString(bad()))\n"),
    ?assertEqual({fault, <<"foreign return does not match Int">>}, Result1),
    {Result2, _} = run("foreign fn pair() : #(Int, String) = \"ern_emitter_tests:pair/0\"\n"
                       ++ Main ++ "{ let #(_, s) = pair(); Io.println(s) }\n"),
    ?assertEqual({fault, <<"foreign return does not match #(Int, String)">>}, Result2),
    {Result3, _} = run("foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                       ++ Main ++ "match opt(1) { Some(n) -> Io.println(Int.toString(n))"
                       " | None -> Io.println(\"none\") }\n"),
    ?assertEqual({fault, <<"foreign return does not match Optional(Int)">>}, Result3),
    {ok, Output} = run("foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
                       ++ Main ++ "match opt(0) { Some(n) -> Io.println(Int.toString(n))"
                       " | None -> Io.println(\"none\") }\n"),
    ?assertEqual(<<"3\n">>, Output),
    {Result4, _} = run("foreign fn boom(x : Int) : Int = \"erlang:error/1\"\n"
                       ++ Main ++ "Io.println(Int.toString(boom(7)))\n"),
    %% report §11.2: the raise carries the host's stack beside its cause
    ?assertMatch({fault, <<"foreign function erlang:error/1 raised error:7">>, <<_/binary>>},
                 Result4),
    {Result5, _} = run("foreign fn each(f : (Int) -> Unit with m, xs : List(Int)) : Unit with m"
                       " = \"lists:foreach/2\"\n"
                       ++ Main ++ "each(fn(n : Int) : Unit with Never = fault(\"later\"), [1])\n"),
    ?assertEqual({fault, <<"later">>}, Result5).

%% report §6.5, §8.4: an address `via` made, given to foreign code and given
%% back, is the address that went out, its function kept. A regression
%% test: the program got the process behind it, and a message sent to it
%% arrived without the function applied, not of the mailbox type
via_address_round_trip_test() ->
    {ok, Output} = run("type Msg = Wrapped(Int)\n"
                       "foreign fn first(xs : List(Address(Int))) : Address(Int) ="
                       " \"erlang:hd/1\"\n"
                       "export fn main() : Unit with Msg = {\n"
                       "    let back = first([via(self(), Wrapped)]);\n"
                       "    send(back, 7);\n"
                       "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                       "}\n"),
    ?assertEqual(<<"7\n">>, Output).

%% report §7.4, §8.4: a fault of the program's own function where foreign
%% code calls it passes through as the fault it would be anywhere, with no
%% foreign function named. A regression test: it took the foreign
%% function's cause, `foreign function lists:foreach/2 raised
%% error:badarith`
callback_fault_passes_through_test() ->
    {Result, Output} = run("foreign fn each(f : (a) -> Unit with m, xs : List(a)) : Unit with m ="
                           " \"lists:foreach/2\"\n"
                           "export fn main() : Unit with Never =\n"
                           "    each(fn(n : Int) : Unit with Never = Io.println(Int.toString(10 /"
                           " n)),"
                           " [2, 0])\n"),
    ?assertEqual({{fault, <<"division by zero">>}, <<"5\n">>}, {Result, Output}).

%% report §6.9, §8.4: a restart asked for while foreign code calls the
%% program's function is a restart, the cause of the new start `Asked`. A
%% regression test: it was a fault of the foreign function, and the process
%% restarted after a fault. The restart is taken at the callback's wait at
%% once; the wait's time only bounds a failure to take it
callback_restart_passes_through_test() ->
    {ok, Output} = run(
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
        "    let _ = spawn(restarting(Unlimited, body));\n"
        "    receive { s -> Io.println(s) };\n"
        "    receive { s -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"First\nAsked\n">>, Output).

%% report §3.1, §5.10: there is no negative zero, so the pattern `-0.0`
%% matches the zero, however it was made. A regression test: the pattern
%% was the host's negative zero, which no value matched
negative_zero_pattern_test() ->
    {ok, Output} = run("fn kind(x : Float) : String = match x {\n"
                       "    -0.0 -> \"zero\"\n"
                       "  | _ -> \"other\"\n"
                       "}\n"
                       "export fn main() : Unit with Never = {\n"
                       "    Io.println(kind(0.0));\n"
                       "    Io.println(kind(-0.0));\n"
                       "    Io.println(kind(0.0 * -1.0))\n"
                       "}\n"),
    ?assertEqual(<<"zero\nzero\nzero\n">>, Output).

%% report §8.4: a type variable a parameter names may stand in the result
%% more than once. A regression test: only its first place was taken as
%% named, the second was checked as matching no value, and every return
%% faulted
foreign_result_names_a_variable_twice_test() ->
    {ok, Output} = run("foreign fn pair(n : Int, x : a) : #(a, a) = \"erlang:make_tuple/2\"\n"
                       "export fn main() : Unit with Never = {\n"
                       "    let _ = Io.debug(pair(2, \"x\"));\n"
                       "    Unit\n"
                       "}\n"),
    ?assertEqual(<<"#(\"x\", \"x\")\n">>, Output).

%% report §3.8, §3.10: two `Foreign` values are equal where foreign code
%% made them as the same term, the runtime's exact equality. A regression
%% test of the rule of 2026-10-01, which the checker refused
foreign_exact_equality_test() ->
    {ok, Output} = run("export fn main() : Unit with Never = {\n"
                       "    Io.println(Io.show(Foreign.from(1) == Foreign.from(1)));\n"
                       "    Io.println(Io.show(Foreign.from(1) == Foreign.from(1.0)));\n"
                       "    Io.println(Io.show([Foreign.from(\"a\")] != [Foreign.from(\"b\")]))\n"
                       "}\n"),
    ?assertEqual(<<"true\nfalse\ntrue\n">>, Output).

%% report §7.4, §8.4: a List is a proper list, so an improper one a foreign
%% function returns faults naming the declared type, whether its elements
%% are checked or a parameter's type variable names them, that variable
%% printed with its restriction (§4.7, §11.5). A regression test:
%% the check raised function_clause instead. It does not cover what a check
%% costs, which make bench shows.
foreign_improper_list_test() ->
    Main = "export fn main() : Unit with Never = ",
    {Result1, _} = run("foreign fn improper(x : Int) : List(Int) ="
                       " \"ern_emitter_tests:improper/1\"\n"
                       ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual({fault, <<"foreign return does not match List(Int)">>}, Result1),
    {Result2, _} = run("foreign fn improper(x : a) : List(a) = \"ern_emitter_tests:improper/1\"\n"
                       ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual({fault, <<"foreign return does not match List(a!)">>}, Result2).

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
    {ok, Output} = run("type Msg = Go(Int)\n"
                       "foreign fn remember(a : Address(Msg)) : Bool with m ="
                       " \"ern_emitter_tests:remember/1\"\n"
                       "export fn main() : Unit with Msg = {\n"
                       "    let _ = remember(self());\n"
                       "    let again = remember(self());\n"
                       "    Io.println(if again then \"same\" else \"another\")\n"
                       "}\n"),
    ?assertEqual(<<"same\n">>, Output),
    persistent_term:erase({?MODULE, proxy_seen}).

%% report §3.10, §3.8: a foreign type's equality is the host's, of the
%% terms: a reference equals itself and not another, and two values that
%% are the same term are equal. `Foreign` has none, which the checker's
%% tests hold. A regression test, written after the code; it does not
%% cover a foreign value that holds a function
foreign_equality_test() ->
    {ok, Output} = run(
        "foreign type Ref\n"
        "foreign fn makeRef() : Ref with m = \"erlang:make_ref/0\"\n"
        "foreign fn same(x : Int) : Ref = \"erlang:abs/1\"\n"
        "export fn main() : Unit with m = {\n"
        "    let a = makeRef();\n"
        "    let b = makeRef();\n"
        "    let _ = Io.debug(#(a == a, a == b, same(1) == same(-1), same(1) == same(2)));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(true, false, true, false)\n">>, Output).

%% report §6.3: a receive guard reads a top-level `let`, in a receive with
%% and without an `after`, the value read before the receive waits. A
%% regression test, written with the rule
receive_guard_reads_top_level_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"#(20, 30)\n">>, Output).

%% report §8.4, §7.4: an address given to foreign code is a proxy that
%% checks each message on delivery, a bad one faulting the target even
%% when no clause would bind it; a good one arrives, also from inside a
%% list; a reply is checked by the call that observes it
foreign_messages_test() ->
    Junk = "foreign fn junk(a : Address(Msg)) : Unit with m = \"ern_emitter_tests:junk/1\"\n",
    {Result1, _} = run("type Msg = Go(Int)\n" ++ Junk ++
                       "export fn main() : Unit with Msg = {\n"
                       "    junk(self());\n"
                       "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                       "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, Result1),
    {WithStop, _} = run("type Msg = Go(Int) | Stop\n" ++ Junk ++
                        "export fn main() : Unit with Msg = {\n"
                        "    junk(self());\n"
                        "    receive { Stop -> Unit }\n"
                        "}\n"),
    ?assertEqual({fault, <<"message does not match Msg">>}, WithStop),
    {ok, Output} = run("type Msg = Go(Int)\n"
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
    ?assertEqual(<<"1\n2\n">>, Output),
    %% report §6.5, §8.4: an adapted address reaches foreign code through
    %% the same proxy, and the wrap is applied on the way back
    {ok, Wrapped} = run("type Msg = Wrapped(Int)\n"
                        "type Inner = Go(Int)\n"
                        "foreign fn good(a : Address(Inner)) : Unit with m ="
                        " \"ern_emitter_tests:good/1\"\n"
                        "export fn main() : Unit with Msg = {\n"
                        "    good(via(self(), fn(Go(n) : Inner) = Wrapped(n)));\n"
                        "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                        "}\n"),
    ?assertEqual(<<"1\n">>, Wrapped),
    {Result2, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                       "foreign fn server() : Address(Ask) with m ="
                       " \"ern_emitter_tests:junk_server/0\"\n"
                       "export fn main() : Unit with Never = {\n"
                       "    let n = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
                       "    Io.println(Int.toString(n))\n"
                       "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, Result2).

%% report §8.4: a function that stands inside a foreign function's argument
%% crosses as one given alone does, each argument foreign code calls it with
%% checked. A regression test: only a parameter that was itself a function
%% was wrapped, and the bad argument faulted inside the function
nested_function_checked_test() ->
    Source = fun(Name) ->
                 "foreign fn call(p : #(Int, (Int) -> Int)) : Int with m = \"ern_emitter_tests:"
                 ++ Name ++ "/1\"\n"
                 "export fn main() : Unit with Never =\n"
                 "    Io.println(Int.toString(call(#(4, fn(n) = n * 2))))\n"
             end,
    ?assertEqual({fault, <<"foreign argument does not match Int">>},
                 outcome(Source("call_nested_bad"))),
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
    ?assertEqual({fault, <<"message does not match Msg">>}, outcome(Source("hello_junk"))),
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
                 "    let n = Address.callForever(spawn(serve), fn(r) = Ask(reply = r));\n"
                 "    Io.println(Int.toString(n))\n"
                 "}\n"
             end,
    ?assertEqual({fault, <<"reply does not match Int">>}, outcome(Source("relay_junk"))),
    ?assertEqual({ok, <<"5\n">>}, run(Source("relay_good"))).

%% report §8.4: a Reply foreign code gives back is held as foreign, so an
%% answer an Ernest process gives it is checked, as foreign code's is: a
%% Reply handed back with another type declared cannot carry an answer of
%% that type to a caller that waits for its own
reply_given_back_test() ->
    {Result, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                      "foreign fn same(r : Reply(Int)) : Reply(String) with m ="
                      " \"ern_emitter_tests:same/1\"\n"
                      "fn serve() : Unit with Ask =\n"
                      "    receive { Ask(reply = r) -> answer(same(r), \"x\") }\n"
                      "export fn main() : Unit with Never = {\n"
                      "    let n = Address.callForever(spawn(serve), fn(r) = Ask(reply = r));\n"
                      "    Io.println(Int.toString(n))\n"
                      "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, Result).

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
                 "    ask(spawn(fn() = serve(me)));\n"
                 "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                 "}\n"
             end,
    ?assertEqual({fault, <<"message does not match Msg">>}, outcome(Source("ask_junk"))),
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
    ?assertEqual({fault, <<"foreign return does not match Int">>}, outcome(Text)).

%% The foreign side of the tests above.
pair() -> {1, 2}.
funs() -> [fun(X) -> X + 1 end, fun(_) -> not_an_int end].
opt(0) -> {'Some', 3};
opt(_) -> {'Some', <<"x">>}.
improper(Element) -> [Element | Element].
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
    spawn(fun() -> receive {'Ask', Reply} -> Reply ! {Reply, <<"x">>} end end).
%% report §8.4: a foreign process that answers a Hello with a message to the
%% address it holds, of another type or of the declared one
hello_junk() ->
    spawn(fun() -> receive {'Hello', Address} -> Address ! {'Go', <<"x">>} end end).
hello_good() ->
    spawn(fun() -> receive {'Hello', Address} -> Address ! {'Go', 1} end end).
%% report §8.4: foreign code given a Reply answers it as the ABI says
relay_junk(Reply) -> Reply ! {Reply, <<"x">>}, 'Unit'.
relay_good(Reply) -> Reply ! {Reply, 5}, 'Unit'.
%% report §8.4: a Reply handed back as it was given, its type declared anew
same(Reply) -> Reply.
%% report §8.4: foreign code that calls the function inside its argument
%% with a value of another type, or of the declared one
call_nested_bad({_, Function}) -> Function(<<"bad">>).
call_nested_good({Number, Function}) -> Function(Number).
%% report §8.4: foreign code that asks an Ernest server with a Reply of its
%% own, and sends the address it is answered a message of another type or
%% of the declared one
ask_junk(Server) -> ask(Server, <<"x">>).
ask_good(Server) -> ask(Server, 1).
ask(Server, Value) ->
    spawn(fun() ->
              Reply = erlang:alias(),
              Server ! {'Ask', Reply},
              receive {Reply, Address} -> Address ! {'Go', Value} end
          end),
    'Unit'.

%% report §4.5: an Ernest function named like an auto-imported
%% Erlang BIF, `size`, `max`, is called by its own name
bif_names_test() ->
    {ok, Output} = run(
        "fn max(a : Int, b : Int) : Int = if a > b then a else b\n"
        "fn size(xs : List(Int)) : Int = List.size(xs) * 10\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    Io.println(Int.toString(size([1])))\n"
        "}\n"),
    ?assertEqual(<<"2\n10\n">>, Output).

%% report §4.2, §4.6, §8.5: a module names its own declaration qualified
%% where a binding hides the plain name, a private function and a `let`,
%% called and taken as values, and a `let` so named is still ordered after
%% the one it reads; where nothing hides it, and for a type, a constructor
%% or a member, which no binding hides, the qualified name is refused. A
%% regression test: each was a remote call, undefined for a private
%% function, and the `let` was not seen as a dependency; the refusals are
%% the full review's P7 (2026-10-04)
qualified_own_name_test() ->
    {ok, Output} = run(
        "let total = { let base = 0; M.base * 2 + base }\n"
        "let base = 3\n"
        "fn two() : Int = 2\n"
        "export fn main() : Unit with Never = {\n"
        "    let two = fn() : Int = 10;\n"
        "    let f = M.two;\n"
        "    Io.println(Int.toString(M.two() + f() + two()));\n"
        "    Io.println(Int.toString(total))\n"
        "}\n"),
    ?assertEqual(<<"14\n6\n">>, Output),
    Refused = fun(Text) ->
                      {error, [Diagnostic | _]} = ern_typecheck:check_string(['M'], Text),
                      Diagnostic#diagnostic.message
              end,
    ?assertEqual("M.two is written only where a binding hides two",
                 Refused("fn two() : Int = 2\nfn f() : Int = M.two()\n")),
    ?assertEqual("M.Box is the module's own Box, which no binding hides",
                 Refused("type Box = Box(Int)\nfn f() : M.Box = Box(1)\n")),
    ?assertEqual("M.Box is the module's own Box, which no binding hides",
                 Refused("type Box = Box(Int)\nfn f() : Box = M.Box(1)\n")),
    ?assertEqual("M.Box.negate is the module's own Box.negate, which no binding hides",
                 Refused("type Box = Box(Int)\n"
                         "fn Box.negate(b : Box) : Box = b\n"
                         "fn f() : Box = M.Box.negate(Box(1))\n")).

%% report §6.3, §4.5: a timed receive's time below 0 is 0 whatever the
%% module calls `max`. A regression test: the emitted `max(0, t)` called
%% the module's own `max/2`, here a difference, which gave a negative time
qualified_max_test() ->
    {ok, Output} = run(
        "fn max(a : Int, b : Int) : Int = a - b\n"
        "type Msg = Ping\n"
        "export fn main() : Unit with Msg = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    receive { Ping -> Unit | after 10 -> Io.println(\"after\") }\n"
        "}\n"),
    ?assertEqual(<<"-1\nafter\n">>, Output).

%% report §6.6, §8.4: `Address.call` and `Address.callForever` taken as
%% values answer as the calls do, and check a reply whose Reply crossed into
%% foreign code as the calls do. A regression test: as values they once
%% left the reply unchecked
call_as_value_test() ->
    {ok, Output} = run(
        "type Msg = Get(reply : Reply(Int))\n"
        "fn serve() : Unit with Msg = receive { Get(reply = r) -> answer(r, 7) }\n"
        "export fn main() : Unit with Never = {\n"
        "    let c : (Address(Msg), (Reply(Int)) -> Msg, Int) -> Optional(Int) with Never =\n"
        "        Address.call;\n"
        "    let w : (Address(Msg), (Reply(Int)) -> Msg) -> Int with Never =\n"
        "        Address.callForever;\n"
        "    let asked = c(spawn(serve), fn(r) = Get(reply = r), 1000);\n"
        "    let n = Optional.withDefault(asked, 0);\n"
        "    Io.println(Int.toString(n + w(spawn(serve), fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"14\n">>, Output),
    {Result, _} = run("type Ask = Ask(reply : Reply(Int))\n"
                      "foreign fn server() : Address(Ask) with m ="
                      " \"ern_emitter_tests:junk_server/0\"\n"
                      "export fn main() : Unit with Never = {\n"
                      "    let w : (Address(Ask), (Reply(Int)) -> Ask) -> Int with Never =\n"
                      "        Address.callForever;\n"
                      "    Io.println(Int.toString(w(server(), fn(r) = Ask(reply = r))))\n"
                      "}\n"),
    ?assertEqual({fault, <<"reply does not match Int">>}, Result).

%% report §5.11, §6.3: a pattern's size names a top-level `let`, which the
%% `match` or the `receive` reads before it begins. A regression test: the
%% checker refused it, the host's pattern showing through
bitstring_size_reads_a_top_level_let_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"#(Some(<<1, 2>>), None)\nSome(<<1, 2, 3, 4>>)\n">>, Output).

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
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], Text),
    Build = #{source_hash => <<>>, deps => [], standard => false},
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    %% Io.debug writes to standard error (Appendix E.1)
    Result = ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                             #{init => fun() -> ok end,
                               stderr => fun(Written) -> Self ! {out, Written} end,
                               stdin => fun() -> eof end}),
    ?assertNotEqual(ok, Result),
    ?assertEqual(<<"<<7, 8>>\n">>, collect([])).

%% report §5.11: the report's frame round trip, sub-octet fields, utf8,
%% float and signed and little segments, a dynamic size in a pattern, and
%% an unaligned rest that fails the match
bitstrings_test() ->
    {ok, Output} = run(
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
                   "104 105 52 \n"/utf8>>, Output).

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
                      {Result, _} = run(Three ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({fault, Cause}, Result)
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
    {ok, Output} = run(Show ++
        "export fn main() : Unit with Never = {\n"
        "    Io.println(show(<<258:size(16)>>));\n"
        "    Io.println(match <<255>> { <<x>> -> Int.toString(x) | _ -> \"no\" });\n"
        "    Io.println(show(<<-1:signed>>))\n"
        "}\n"),
    ?assertEqual(<<"1 2 \n255\n255 \n">>, Output),
    {Result, _} =
        run("export fn main() : Unit with Never = { let n = 0 - 1; let _ = <<n>>; Unit }\n"),
    ?assertEqual({fault, <<"segment overflow">>}, Result).

%% report §8.5: top-level lets run in the order the checker's let_order/1
%% gives, a let after every let it reaches through the functions it names,
%% whatever the order they are declared in. A regression test, written when
%% the emitter came to read that order in place of computing its own, which
%% was the same.
initialization_order_test() ->
    {ok, Output} = run("let total = twice() + 1\n"
                       "fn twice() : Int = base * 2\n"
                       "let base = 10\n"
                       "export fn main() : Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"21\n">>, Output).

%% report §4.2: a name shadowed at each step of the lookup order compiles
%% to the declaration the checker resolved it to, which the emitter reads
%% from the name's `ref` rather than resolving again: a type's member, the
%% module's own function over the prelude's `self`, the module named
%% qualified past a local binding that hides it, `Prelude.self`, and a
%% local binding over them all. A regression test for the single decision;
%% the order it had was the same.
lookup_order_test() ->
    {ok, Output} = run("type Box = Box(Int)\n"
                       "fn Box.negate(b : Box) : Int = match b { Box(n) -> n }\n"
                       "fn negate(b : Box) : Int = 100\n"
                       "fn self() : Int = 5\n"
                       "export fn main() : Unit with Never = {\n"
                       "    let me = Prelude.self();\n"
                       "    let first = Box.negate(Box(1)) + negate(Box(1)) + self();\n"
                       "    let self = fn() : Int = 10;\n"
                       "    let second = self() + M.self();\n"
                       "    let negate = fn(b : Box) : Int = 1000;\n"
                       "    Io.println(Int.toString(first + second + negate(Box(1))))\n}\n"),
    ?assertEqual(<<"1121\n">>, Output).

%% A function may be named `module_info` or `record_info`, which the host
%% gives every module: the emitter compiles them under names no Ernest name
%% can spell. A regression test: the compiler refused them with Erlang's "function
%% module_info/0 already defined", and the shell faulted. Not covered here:
%% a call from another module, which the shell test reaches.
host_reserved_names_test() ->
    {ok, Output} = run("export fn module_info() : Int = 7\n"
                       "fn record_info(x : Int) : Int = x + 1\n"
                       "export let total = module_info() + record_info(1)\n"
                       "export fn main() : Unit with Never = {\n"
                       "    Io.println(Int.toString(total));\n"
                       "    Io.println(Int.toString(List.foldLeft(List.map([1, 2], record_info), 0,"
                       " fn(a, b) = a + b)))\n}\n"),
    ?assertEqual(<<"9\n5\n">>, Output).

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
                      {Result, _} = run(Neg ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertEqual({Bits, {fault, <<"segment overflow">>}}, {Bits, Result})
                  end, Faults),
    {ok, Output} = run(
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
    ?assertEqual(<<"3.140625\n0.0\n65504.0\nno\nno\nno\nno\n1\nno\n">>, Output).

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
    ?assertMatch({error, [#diagnostic{message = "unknown name todo"} | _]},
                 ern_typecheck:check_string(['M'], "fn later() : Int = todo(\"x\")\n")).

%% report §5.6, §8.4: named fields in canonical order, and update from a
%% base value
constructors_test() ->
    {ok, Output} = run(
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
    ?assertEqual(<<"5,2\ndot\n1\n">>, Output).

%% report §3.5, §8.4: a selected field, one element of the tuple where every
%% constructor holds it at one place and a case on the tag where the places
%% differ, its operand evaluated once
field_selection_test() ->
    {ok, Output} = run(
        "type Pair = Left(a : Int, name : String) | Right(name : String, z : Int)\n"
        "type Point = Point(x : Int, y : Int)\n"
        "fn v(p : Pair) : Pair with Never = { Io.println(\"once\"); p }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(v(Left(a = 1, name = \"l\")).name <> Right(name = \"r\", z = 2).name);\n"
        "    Io.println(Int.toString(Point(x = 3, y = 4).y))\n"
        "}\n"),
    ?assertEqual(<<"once\nlr\n4\n">>, Output).

%% report §3.5, §5.1: named fields are stored and shown in their declared
%% order and evaluated in the order written, in a construction and in an
%% update from a base value, whose base is evaluated first. A regression
%% test: the fields were evaluated in the order of their names, and then
%% stored so. It does not cover a positional constructor, whose one field
%% has no order
field_order_test() ->
    {ok, Output} = run(
        "type Snap = Snap(z : Int, a : Int, m : Int)\n"
        "fn v(s : String, n : Int) : Int with Never = { Io.println(s); n }\n"
        "export fn main() : Unit with Never = {\n"
        "    let s = Snap(m = v(\"m\", 3), z = v(\"z\", 1), a = v(\"a\", 2));\n"
        "    let t = Snap(..{ Io.println(\"base\"); s }, m = v(\"m\", 4), a = v(\"a\", 5));\n"
        "    let _ = Io.debug(#(s, t));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"m\nz\na\nbase\nm\na\n"
                   "#(Snap(z = 1, a = 2, m = 3), Snap(z = 1, a = 5, m = 4))\n">>, Output).

%% report §5.3, §5.8: lambdas capture, if is an expression
lambda_if_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    let k = 3;\n"
        "    let f = fn(x : Int) = if x > k then \"big\" else \"small\";\n"
        "    Io.println(f(5));\n"
        "    Io.println(f(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Output).

%% report §6.2, §6.9: a process monitored from its start that faults
%% reports its spawn site and its cause, however soon it faults
monitor_site_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down)\n"
        "export fn main() : Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() : Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(site = f, reason = Fault(msg))) -> Io.println(f <> \" \" <> msg)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"M.main:4 division by zero\n">>, Output).

%% report §6.9: a spawn site names the declaration by its Ernest name, one
%% the host's own names collide with among them. A regression test: a
%% function named module_info was named `module_info$`
host_named_site_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down)\n"
        "fn module_info() : Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() : Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive { Died(Down(site = f, reason = _)) -> Io.println(f) }\n"
        "}\n"
        "export fn main() : Unit with Msg = module_info()\n"),
    ?assertEqual(<<"M.module_info:4\n">>, Output).

%% report §6.9: a Down's function is the top-level declaration the spawn
%% is written in: one inside a local fn or a lambda counts as written in
%% the enclosing declaration, and `spawn` taken as a value counts where
%% its name is written. A regression test, written after the code; it does
%% not cover a spawn in a top-level `let`'s initializer
down_site_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down)\n"
        "fn idle() : Unit with Unit = receive { _ -> Unit }\n"
        "fn report() : Unit with Msg = receive {\n"
        "    Died(Down(site = f, reason = _)) -> Io.println(f)\n"
        "}\n"
        "fn outer() : Unit with Msg = {\n"
        "    fn inner() : Address(Unit) with Msg = spawn(idle);\n"
        "    watched(inner());\n"
        "    let viaLambda = fn() = spawn(idle);\n"
        "    watched(viaLambda());\n"
        "    let s = spawn;\n"
        "    watched(s(idle))\n"
        "}\n"
        "// monitored while it waits, then killed\n"
        "fn watched(idler : Address(Unit)) : Unit with Msg = {\n"
        "    monitor(Process.fromAddress(idler), Died);\n"
        "    kill(idler);\n"
        "    report()\n"
        "}\n"
        "export fn main() : Unit with Msg = outer()\n"),
    ?assertEqual(<<"M.outer:7\nM.outer:9\nM.outer:11\n">>, Output).

%% report §9.4, §9.6: spawn, the Int operators, and <> are functions and
%% may be passed as values
prelude_values_test() ->
    {ok, Output} = run(
        "fn apply2(f : (Int, Int) -> Int, a : Int, b : Int) : Int = f(a, b)\n"
        "fn twice(f : (Int) -> Int, a : Int) : Int = f(f(a))\n"
        "fn join(f : (String, String) -> String) : String = f(\"a\", \"b\")\n"
        "fn start(s : (() -> Unit with Never) -> Address(Never) with Never)\n"
        "        : Address(Never) with Never = s(fn() = Unit)\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Int.toString(apply2(Int.+, 2, 3)));\n"
        "    Io.println(Int.toString(apply2(Int./, 7, 2)));\n"
        "    Io.println(Int.toString(apply2(Int.%, 7, 2)));\n"
        "    Io.println(Int.toString(twice(Int.negate, 5)));\n"
        "    Io.println(join(String.<>));\n"
        "    let _ = start(spawn);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"5\n3\n1\n5\nab\n">>, Output).

%% report Appendix E, §5.2: a stdlib function and an Address function
%% passed as values
stdlib_values_test() ->
    {ok, Output} = run(
        "fn call(f : (Address(m), (Reply(Int)) -> m, Int) -> Optional(Int) with n,"
        " a : Address(m), mk : (Reply(Int)) -> m) : Optional(Int) with n = f(a, mk, 100)\n"
        "type Msg = Ask(Reply(Int))\n"
        "fn answerer() : Unit with Msg = receive { Ask(r) -> answer(r, 7) }\n"
        "export fn main() : Unit with Never = {\n"
        "    Io.println(Bool.toString(List.all(String.toList(\"123\"), Char.isDigit)));\n"
        "    let a = spawn(fn() = answerer());\n"
        "    match call(Address.call, a, Ask) {\n"
        "        Some(n) -> Io.println(Int.toString(n))\n"
        "      | None -> Io.println(\"none\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"true\n7\n">>, Output).

%% report Appendix E.3, E.4, §3.10: Map and Set end to end, with
%% structural equality
maps_sets_test() ->
    {ok, Output} = run(
        "export fn main() : Unit with Never = {\n"
        "    let m = Map.put(Map.put(Map.empty, \"a\", 1), \"b\", 2);\n"
        "    let s = Set.put(Set.fromList([1, 2]), 3);\n"
        "    Io.println(Int.toString(Optional.withDefault(Map.get(m, \"b\"), 0)));\n"
        "    Io.println(Int.toString(Map.foldLeft(m, 0, fn(acc, _, v) = acc + v)));\n"
        "    Io.println(Bool.toString(Set.contains(s, 3)));\n"
        "    Io.println(Int.toString(Set.size(Set.union(s, Set.fromList([3, 4])))));\n"
        "    Io.println(Bool.toString(Set.fromList([1, 2]) == Set.fromList([2, 1])))\n"
        "}\n"),
    ?assertEqual(<<"2\n3\ntrue\n4\ntrue\n">>, Output).

%% report Appendix E.13, §4.2, §3.8: a standard library foreign type in its
%% namespace, and every draw within its bounds
random_test() ->
    {ok, Output} = run(
        "fn draw(s : Random.Seed, n : Int) : List(Int) = if n == 0 then [] else {\n"
        "    let #(x, s1) = Random.next(s, 5);\n"
        "    x :: draw(s1, n - 1)\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let xs = draw(Random.seed(42), 50);\n"
        "    Io.println(Bool.toString(List.all(xs, fn(x) = x >= 0 && x <= 5)))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Output).

%% report Appendix E.15, E.14, §9.3: Clock.alarm delivers the wrapped Unit to
%% the caller, Clock.now is a time, Path is the prelude's
clock_path_test() ->
    {ok, Output} = run(
        "type Msg = Tick\n"
        "export fn main() : Unit with Msg = {\n"
        "    let t0 = Clock.now();\n"
        "    Clock.alarm(10, fn(_) = Tick);\n"
        "    receive { Tick -> Unit };\n"
        "    Io.println(Bool.toString(Clock.now() >= t0 + 10));\n"
        "    Io.println(Path.toString(Path(\"a\") <> Path(\"b\")))\n"
        "}\n"),
    ?assertEqual(<<"true\na/b\n">>, Output).

%% report §8.5, §8.2: a system module's reference is bound before the
%% program's own top-level lets are evaluated, so an initializer may print
system_reference_in_let_test() ->
    {ok, Output} = run("let greeting = Io.println(\"from a let\")\n"
                       "export fn main() : Unit with Never = Io.println(\"from main\")\n"),
    ?assertEqual(<<"from a let\nfrom main\n">>, Output).

%% report §9, Appendix E: every prelude value the
%% checker knows is emitted as a call to a function that exists, with the
%% arity of its type, so no accepted name can reach the runtime as undef
prelude_targets_test() ->
    Missing = [QualifiedName || {QualifiedName, Text, _} <- ern_prelude:values(),
                                {HostModule, HostFunction, Arity}
                                    <- [prelude_target(QualifiedName, Text)],
                                code:ensure_loaded(HostModule) =/= {module, HostModule} orelse
                                    not erlang:function_exported(HostModule, HostFunction, Arity)],
    ?assertEqual([], Missing).

%% The emission of a prelude name, as ern_emitter makes it: Int's
%% arithmetic and negate, and the `<>` of String and Bytes, are inline and
%% have no target; Float's operators, and the `<>` of List and Path, are
%% their modules' functions (report §4.8).
prelude_target(QualifiedName, Text) ->
    {ok, Syntax} = ern_parser:parse_type(Text),
    Arity = case Syntax of
                #t_fn{params = Params} -> length(Params);
                _ -> 0
            end,
    case QualifiedName of
        [self] -> {ern_rt, self, 0};
        [send] -> {ern_rt, send, 2};
        [spawn] -> {ern_rt, spawn, 2};
        [spawnMonitored] -> {ern_rt, spawn_monitored, 3};
        [via] -> {ern_rt, via, 2};
        [answer] -> {ern_rt, answer, 2};
        [monitor] -> {ern_rt, monitor, 2};
        [kill] -> {ern_rt, kill, 1};
        [restarting] -> {ern_rt, restarting, 2};
        [fault] -> {ern_rt, fault, 1};
        ['Address', call] -> {ern_rt, call, 3};
        ['Address', callForever] -> {ern_rt, call_forever, 2};
        ['Int', Operator]
          when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
               Operator =:= '%'; Operator =:= negate ->
            {erlang, is_atom, 1};
        [TypeName, '<>'] when TypeName =:= 'String'; TypeName =:= 'Bytes' ->
            {erlang, is_atom, 1};
        [Namespace, Function] -> {ern_namespace:erlang_module([Namespace]), Function, Arity}
    end.

%% report §6.5, §6.9, §7.3, §9.5: kill is a Down with Killed, a fault a
%% Down with its cause, and via adapts a message, all through compiled code
process_functions_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down) | Tick\n"
        "fn idle() : Unit with Unit = receive { _ -> Unit }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let w = spawn(fn() = idle());\n"
        "    monitor(Process.fromAddress(w), Died);\n"
        "    kill(w);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() : Unit with Never = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(m), site = _)) -> Io.println(m)\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    send(via(self(), fn(u : Unit) = Tick), Unit);\n"
        "    receive { Tick -> Io.println(\"tick\") | _ -> Io.println(\"other\") }\n"
        "}\n"),
    ?assertEqual(<<"killed\ndivision by zero\ntick\n">>, Output).

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

%% Appendix E.12: a text longer than 255 characters makes no atom, and
%% `Foreign.atom` faults as a foreign function that raises does (report §7.4)
foreign_atom_too_long_test() ->
    {Result, _} = run("export fn main() : Unit with Never = {\n"
                      "    let _ = Foreign.atom(String.padStart(\"\", 256, \"a\"));\n"
                      "    Unit\n"
                      "}\n"),
    ?assertMatch({fault, <<"foreign function erlang:binary_to_atom/1 raised error:system_limit">>,
                  _}, Result).

%% docs/memory.md, *Atoms*: a program's work makes no atoms, since the host
%% never frees one; the same work done again, processes and calls,
%% a socket, a host program, a file and an alarm, leaves the count as it
%% was. Written after the reading that found none; `make load` measures the
%% same at length (docs/memory.md).
work_makes_no_atoms_test_() ->
    {timeout, 60, fun work_makes_no_atoms/0}.

work_makes_no_atoms() ->
    Dir = scratch(),
    {ok, Output} = run([
        "type Msg = Tick(Int) | Ended(Down)\n"
        "foreign fn info(k : Foreign.Term) : Int with m = \"erlang:system_info/1\"\n"
        "fn work() : Unit with Msg = {\n"
        "    let w = spawn(fn() : Unit with Int = receive { _ -> Unit });\n"
        "    monitor(Process.fromAddress(w), Ended);\n"
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
        "    let before = info(Foreign.atom(\"atom_count\"));\n"
        "    work();\n"
        "    work();\n"
        "    Io.println(Io.show(info(Foreign.atom(\"atom_count\")) - before))\n"
        "}\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(<<"0\n">>, Output).

%% report §8.4, §7.4: a type variable of a foreign function's result that no
%% parameter names matches no value, so a return that holds one faults, and
%% an empty list of it passes, as does a value of a foreign type over it,
%% which the check does not look into; a function given to foreign code has
%% the arguments it is called with checked. A regression test: the first was
%% an unchecked cast, and the second let any value in;
%% the foreign type's case was written after the code
foreign_casts_and_callbacks_test() ->
    ResultOf = fun(Declaration, Body) ->
                   {Result, _} = run(Declaration ++ "export fn main() : Unit with Never = {\n"
                                     "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                   Result
               end,
    ?assertEqual({fault, <<"foreign return does not match a">>},
                 ResultOf("foreign fn cast(n : Int) : a =\n    \"erlang:abs/1\"\n", "cast(1) + 1")),
    ?assertEqual(ok, ResultOf("foreign fn none(xs : List(Int)) : List(a) =\n    \"erlang:tl/1\"\n",
                              "List.size(none([1]))")),
    ?assertEqual(ok, ResultOf("foreign type Handle(a)\n"
                              "foreign fn handle() : Handle(a) =\n    \"erlang:make_ref/0\"\n",
                              "handle()")),
    ?assertEqual({fault, <<"foreign argument does not match Int">>},
                 ResultOf("foreign fn each(f : (Int) -> Int, xs : List(String)) : List(Int) =\n"
                          "    \"lists:map/2\"\n", "each(fn(n) = n + 1, [\"x\"])")).

%% report §8.4: a type variable a parameter's type names matches any value at
%% the boundary, in a foreign function's result and in an argument foreign
%% code calls a function with. A regression test of what the report states
foreign_type_variables_unchecked_test() ->
    ResultOf = fun(Declaration, Body) ->
                   {Result, _} = run(Declaration ++ "export fn main() : Unit with Never = {\n"
                                     "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                   Result
               end,
    ?assertEqual(ok, ResultOf("foreign fn weird(x : a) : a =\n    \"erlang:length/1\"\n",
                              "weird([1, 2])")),
    ?assertEqual(ok, ResultOf("foreign fn each(f : (a) -> Int, x : a) : List(Int) =\n"
                              "    \"lists:map/2\"\n", "each(fn(_) = 1, [[\"x\"]])")).

%% report §6.9, §6.6: a callee's own answer to a call is not overtaken by
%% its end, so a worker that answers and returns at once is answered, every
%% time. A regression test of what the report states;
%% the order of a `Down` and the ended process's own messages is not
%% promised, and so not tested
answer_before_end_test() ->
    {ok, Output} = run(
        "fn worker() : Unit with Reply(Int) = receive { r -> answer(r, 7) }\n"
        "fn rounds(n : Int, sum : Int) : Int with m =\n"
        "    if n == 0 then sum\n"
        "    else rounds(n - 1, sum + Address.callForever(spawn(worker), fn(r) = r))\n"
        "export fn main() : Unit with Never = Io.println(Int.toString(rounds(200, 0)))\n"),
    ?assertEqual(<<"1400\n">>, Output).

%% report §8.4: an address foreign code gives back is the program's own at
%% the type it went out at, and foreign at another, so that what is sent
%% through it is checked against the process's own type. A regression test:
%% the proxy was undone whatever the type it came back at, and a String
%% reached a process of Int. The first target's end is
%% waited for, so that its line is written before the program ends
retyped_address_test() ->
    {ok, Output} = run(
        "type Msg = Ended(Down)\n"
        "fn target() : Unit with Int = receive { n -> Io.println(\"got \" <> Int.toString(n)) }\n"
        "foreign fn retyped(addresses : List(Address(Int))) : Address(String) =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn same(addresses : List(Address(Int))) : Address(Int) =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit with Msg = {\n"
        "    let kept = spawnMonitored(target, Ended);\n"
        "    send(same([kept]), 5);\n"
        "    receive { Ended(_) -> Unit };\n"
        "    let wronged = spawnMonitored(target, Ended);\n"
        "    send(retyped([wronged]), \"x\");\n"
        "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"got 5\nFault(\"message does not match Int\")\n">>, Output).

%% report §8.4: a process of the program's whose address foreign code was
%% never given is a bad value where foreign code gives it as an address: its
%% own `self()` in a foreign function, and a `Process` it was given, but as
%% an `Address(Never)`, through which nothing passes; an address that
%% crossed comes back as the program's own at its type. A regression test:
%% each was the program's own at whatever type foreign code named, and a
%% String reached a process of Int
never_given_address_test() ->
    Program = fun(Forged) ->
                  "foreign fn me() : Address(String) =\n"
                  "    \"erlang:self/0\"\n"
                  "foreign fn retyped(processes : List(Process)) : Address(String) =\n"
                  "    \"erlang:hd/1\"\n"
                  "foreign fn same(addresses : List(Address(Int))) : Address(Int) =\n"
                  "    \"erlang:hd/1\"\n"
                  "export fn main() : Unit with Int = {\n"
                  "    send(same([self()]), 5);\n"
                  "    receive { n -> Io.println(Int.toString(n)) };\n"
                  "    send(" ++ Forged ++ ", \"x\")\n"
                  "}\n"
              end,
    Refused = {{fault, <<"foreign return does not match Address(String)">>}, <<"5\n">>},
    ?assertEqual(Refused, run(Program("me()"))),
    ?assertEqual(Refused, run(Program("retyped([Process.fromAddress(self())])"))),
    ?assertEqual({ok, <<"true\n">>},
                 run("foreign fn handle() : Address(Never) =\n"
                     "    \"erlang:self/0\"\n"
                     "export fn main() : Unit with Int =\n"
                     "    Io.println(Bool.toString(Process.fromAddress(handle())\n"
                     "                             == Process.fromAddress(self())))\n")).

%% report §8.4, §6.9: a foreign message that does not match takes its place
%% in the receiver's mailbox as a fault, which lands at the wait that reaches
%% it, in a `receive` or for a call's answer, as a fault of the receiver's
%% own, so that `restarting` restarts it until its limit. A regression test
%% of the full review's C104 (2026-10-04): the fault came as an exit signal,
%% which ended the process whatever wrapped it, at its first run
foreign_fault_restarts_test() ->
    Common = "type Msg = Ended(Down)\n"
             "type Hold = Hold(reply : Reply(Int))\n"
             "foreign fn retyped(addresses : List(Address(Int))) : Address(String) =\n"
             "    \"erlang:hd/1\"\n"
             "fn holder(held : List(Reply(Int))) : Unit with Hold =\n"
             "    receive { Hold(reply = r) -> holder(r :: held) }\n",
    Main = fun(Run) ->
                   "export fn main() : Unit with Msg = {\n"
                   "    let h = spawn(fn() = holder([]));\n"
                   "    let limit = RestartLimit(restarts = 2, within = 60000);\n"
                   "    let _ = spawnMonitored(restarting(limit, fn() = " ++ Run ++ "), Ended);\n"
                   "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
                   "}\n"
           end,
    Expected = <<"run\nrun\nrun\nFault(\"message does not match Int\")\n">>,
    %% at a receive
    ?assertEqual({ok, Expected},
                 run(Common ++
                     "fn wait(h : Address(Hold)) : Unit with Int = {\n"
                     "    Io.println(\"run\");\n"
                     "    send(retyped([self()]), \"x\");\n"
                     "    receive { n -> Io.println(Int.toString(n)) }\n"
                     "}\n" ++ Main("wait(h)"))),
    %% at a call's wait, which nothing else would end
    ?assertEqual({ok, Expected},
                 run(Common ++
                     "fn ask(h : Address(Hold)) : Unit with Int = {\n"
                     "    Io.println(\"run\");\n"
                     "    send(retyped([self()]), \"x\");\n"
                     "    Io.println(Int.toString(Address.callForever(h,"
                     " fn(r) = Hold(reply = r))))\n"
                     "}\n" ++ Main("ask(h)"))).

%% report §8.4, Appendix E.12: `Foreign.from` gives its value as a foreign
%% function's argument of the value's type crosses: an address goes behind
%% the proxy that faults its process on a message of another type, and a
%% function checks what foreign code calls it with, as each does given in
%% an argument of its own type. A value nothing in which crosses is the
%% value itself. A regression test: `Foreign.from` gave the address and the
%% function as the runtime held them, unchecked
foreign_from_crosses_as_an_argument_test() ->
    %% the fault the proxy sends takes the message's place; where none came,
    %% the program would end in a deadlock, which no case expects
    Main = "export fn main() : Unit with Int = {\n    let _ = ~s;\n"
           "    receive { _ -> Unit }\n}\n",
    Typed = "foreign fn rawSend(to : Address(Int), message : String) : String =\n"
            "    \"erlang:send/2\"\n",
    Untyped = "foreign fn rawSend(to : Foreign.Term, message : String) : String =\n"
              "    \"erlang:send/2\"\n",
    Applied = "foreign fn applied(f : Foreign.Term, arguments : List(String)) : Int =\n"
              "    \"erlang:apply/2\"\n",
    Program = fun(Declaration, Call) ->
                  Declaration ++ lists:flatten(io_lib:format(Main, [Call]))
              end,
    Fault = fun(Source) ->
                {{fault, Cause}, _} = run(Source),
                Cause
            end,
    ?assertEqual(<<"message does not match Int">>,
                 Fault(Program(Typed, "rawSend(self(), \"x\")"))),
    ?assertEqual(<<"message does not match Int">>,
                 Fault(Program(Untyped, "rawSend(Foreign.from(self()), \"x\")"))),
    ?assertEqual(<<"foreign argument does not match Int">>,
                 Fault(Program(Applied, "applied(Foreign.from(fn(n : Int) = n + 1), [\"x\"])"))),
    ?assertEqual({ok, <<"Some(42)\n">>},
                 run("export fn main() : Unit with Never =\n"
                     "    Io.println(Io.show(Foreign.toInt(Foreign.from(42))))\n")).

%% report §8.2: a write to standard output returns once the stream has taken
%% it, so a program writing to a slow stream goes at its pace: after each
%% write the stream has taken it and every write before it, which the
%% stream counts and the program reads
io_write_waits_test() ->
    Self = self(),
    Taken = counters:new(1, []),
    persistent_term:put({?MODULE, taken}, Taken),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "foreign fn taken() : Int with m = \"ern_emitter_tests:taken/0\"\n"
        "export fn main() : Unit with Never = {\n"
        "    let kept = List.all(List.range(1, 10), fn(n) = {\n"
        "        Io.println(Int.toString(n));\n"
        "        taken() >= n\n"
        "    });\n"
        "    Io.printlnError(Io.show(kept))\n"
        "}\n"),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    ok = ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                         #{stdout => fun(_) -> counters:add(Taken, 1, 1) end,
                           stderr => fun(Text) -> Self ! {err, Text} end}),
    persistent_term:erase({?MODULE, taken}),
    ?assertEqual(<<"true\n">>, receive {err, Text} -> Text after 5000 -> none end).

%% The writes io_write_waits_test's standard output has taken.
-spec taken() -> non_neg_integer().
taken() ->
    counters:get(persistent_term:get({?MODULE, taken}), 1).

%% report Appendix E.1: Io.writeError writes its bytes to standard error as
%% they are, a byte that is not UTF-8 among them, and nothing to standard
%% output. Written with the code, of 2026-10-01
io_write_error_test() ->
    Self = self(),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "export fn main() : Unit with Never = Io.writeError(<<104, 105, 255>>)\n"),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    ok = ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                         #{stdout => fun(Text) -> Self ! {out, Text} end,
                           stderr => fun(Text) -> Self ! {err, Text} end}),
    ?assertEqual(<<104, 105, 255>>, receive {err, Text} -> Text after 5000 -> none end),
    ?assertEqual(none, receive {out, Written} -> Written after 0 -> none end).

%% report §8.5: a module the program does not depend on is not initialized,
%% though it is on the code path; a regression test for the shell's modules,
%% which every run initialized, before the standard library's
unrelated_module_not_initialized_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Aside'],
        "let noisy = Io.debug(\"initialized\")\n"),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['Aside'], Typed, Interface, Env),
    Dir = scratch(),
    ok = file:write_file(filename:join(Dir, atom_to_list(ErlangModule) ++ ".beam"), Beam),
    true = code:add_patha(Dir),
    try
        ?assertEqual({ok, <<"ran\n">>},
                     run("export fn main() : Unit with Never = Io.println(\"ran\")\n"))
    after
        code:del_path(Dir),
        code:purge(ErlangModule),
        code:delete(ErlangModule),
        file:del_dir_r(Dir)
    end.

%% report §10: a tail call takes constant stack space, through the branches
%% of an `if`, the clauses of a `match`, and the last expression of a block:
%% ten million calls run in a process whose heap, its stack counted, may not
%% pass a hundred thousand words
tail_calls_constant_stack_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "export fn count(n : Int, acc : Int) : Int =\n"
        "    if n == 0 then acc\n"
        "    else match n % 2 {\n"
        "        0 -> { let next = acc + 1; count(n - 1, next) }\n"
        "      | _ -> count(n - 1, acc + 1)\n"
        "    }\n"),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    {_, MonitorRef} = spawn_opt(fun() -> Self ! {counted, ErlangModule:count(10000000, 0)} end,
                                [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                            error_logger => false}}]),
    Result = receive
                 {counted, Count} -> Count;
                 {'DOWN', MonitorRef, process, _, ExitReason} -> {died, ExitReason}
             end,
    ?assertEqual(10000000, Result).

%% report §10: the right operand of `&&` and `||`, and the call a pipe
%% makes, are in tail position where their expression is, and take constant
%% stack space as the test above measures it. A regression test, written
%% after the report stated it: the emitter gave these the host's own tail
%% calls from the start
tail_calls_through_operators_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "export fn all(n : Int) : Bool =\n"
        "    n == 0 || (n > 0 && all(n - 1))\n"
        "export fn down(n : Int) : Int =\n"
        "    if n == 0 then 0 else n - 1 |> down\n"),
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    OutcomeOf = fun(Function) ->
                    {_, MonitorRef} =
                        spawn_opt(fun() -> Self ! {ran, Function()} end,
                                  [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                              error_logger => false}}]),
                    receive
                        {ran, Value} -> Value;
                        {'DOWN', MonitorRef, process, _, ExitReason} -> {died, ExitReason}
                    end
                end,
    ?assertEqual(true, OutcomeOf(fun() -> ErlangModule:all(10000000) end)),
    ?assertEqual(0, OutcomeOf(fun() -> ErlangModule:down(10000000) end)).

%% report §10: processes are scheduled preemptively, so one that computes
%% for ever does not keep another from running; and Int has arbitrary
%% precision
preemption_and_precision_test() ->
    {ok, Output} = run(
        "fn spin(n : Int) : Int = spin(n + 1)\n"
        "fn power(b : Int, e : Int) : Int = if e == 0 then 1 else b * power(b, e - 1)\n"
        "foreign fn running(process : Process) : Foreign.Term with m = \"ern_waits:running/1\"\n"
        "export fn main() : Unit with Never = {\n"
        "    let w = spawn(fn() : Unit with Never = { let _ = spin(0); Unit });\n"
        "    let _ = running(Process.fromAddress(w));\n"
        "    Io.println(Int.toString(power(2, 100)));\n"
        "    kill(w)\n"
        "}\n"),
    ?assertEqual(<<"1267650600228229401496703205376\n">>, Output).

%% report §6.9: kill on a process that has already ended has no effect,
%% and a monitor placed after the end answers Unknown, with no spawn site,
%% since the runtime keeps nothing of an ended process, and names the
%% process still. A regression test, written after the code; it does not
%% cover kill on a system process
kill_dead_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down)\n"
        "export fn main() : Unit with Msg = {\n"
        "    let z = List.size([]);\n"
        "    let w = spawn(fn() : Unit with Never = { let _ = 1 / z; Unit });\n"
        "    monitor(Process.fromAddress(w), Died);\n"
        "    receive { Died(_) -> Unit };\n"
        "    kill(w);\n"
        "    monitor(Process.fromAddress(w), Died);\n"
        "    receive {\n"
        "        Died(Down(process = p, reason = r, site = s)) ->\n"
        "            Io.println(Io.show(#(p == Process.fromAddress(w), r, s)))\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"#(true, Unknown, \"\")\n">>, Output).

%% report §6.9, §9.3: a `Down` names the process behind the address
%% monitored, through a `via`, as `Process.fromAddress` gives it
down_names_its_process_test() ->
    {ok, Output} = run(
        "type Msg = Died(Down) | Go\n"
        "export fn main() : Unit with Msg = {\n"
        "    let w = spawnMonitored(fn() : Unit with Never = Unit, Died);\n"
        "    let first = receive { Died(d) -> d.process == Process.fromAddress(w) };\n"
        "    let v = spawn(fn() : Unit with Msg = receive { Go -> Unit });\n"
        "    monitor(Process.fromAddress(via(v, fn(u : Unit) = Go)), Died);\n"
        "    send(v, Go);\n"
        "    let second = receive { Died(d) -> d.process == Process.fromAddress(v) };\n"
        "    Io.println(Io.show(#(first, second)))\n"
        "}\n"),
    ?assertEqual(<<"#(true, true)\n">>, Output).

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
    %% regression test of the test, which took any error
    ?assertMatch({error, [#diagnostic{message = "unknown name Io.stdout"} | _]},
                 Refused("send(Io.stdout, String.toUtf8(\"hi\"))")),
    ?assertMatch({error, [#diagnostic{message = "unknown name Sys.stdout"} | _]},
                 Refused("send(Sys.stdout, \"hi\")")),
    ?assertMatch({error, [#diagnostic{message = "unknown constructor Clock.Now"} | _]},
                 Refused("{ let _ = Clock.Now; Unit }")).

%% report §8.5: a compiled module declares the modules it depends on, as
%% `'$deps'/0`, so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file; a module that
%% depends on none declares none
deps_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], "export let one = 1\n"),
    Build = #{source_hash => <<>>, deps => [{['Net', 'Http'], <<"hash">>}]},
    {ok, ErlangModule, Beam} = ern_emitter:compile(['M'], Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    ?assert(erlang:function_exported(ErlangModule, '$deps', 0)),
    ?assertEqual(['ern@net@http'], ErlangModule:'$deps'()),
    {ok, Typed2, Interface2, Env2} = ern_typecheck:check_string(['N'], "export let one = 1\n"),
    {ok, ErlangModule2, Beam2} = ern_emitter:compile(['N'], Typed2, Interface2, Env2),
    {module, ErlangModule2} = code:load_binary(ErlangModule2, "test", Beam2),
    ?assertNot(erlang:function_exported(ErlangModule2, '$deps', 0)).

%% report §8.5: the emitter orders the top-level lets by what they
%% reference, and a name bound inside a function body is not one of
%% them; before that, a program like this crashed the emitter, since its
%% graph held a cycle the checker had not seen
shadowed_name_in_init_order_test() ->
    ?assertEqual({ok, <<"3\n">>},
                 run("let three = pick([3])\n"
                     "fn pick(xs : List(Int)) : Int = match xs { [three] -> three | _ -> 0 }\n"
                     "export fn main() : Unit with m = Io.println(Int.toString(three))\n")).

%%
%% Requirements (report §4.9), derived members (§3.5) and the fill (§5.6)
%%

%% report §4.9: a requirement's members are arguments the program does not
%% write: a known type's member supplied at a call, a requirement's passed
%% along, through a block fn that shares it and one with its own, a lambda,
%% a declaration taken as a value, an operator, prefix `-`, and `show`;
%% written after the code
requirement_supplied_test() ->
    {ok, Output} =
        run("type Money = Money(Int)\n"
            "fn Money.+(Money(a) : Money, Money(b) : Money) : Money =\n    Money(a + b)\n"
            "fn Money.negate(Money(a) : Money) : Money =\n    Money(0 - a)\n"
            "fn total(list : List(a), zero : a) : a needs a.+ =\n"
            "    List.foldLeft(list, zero, a.+)\n"
            "fn opposite(x : a) : a needs a.negate =\n    -x\n"
            "fn largest(list : List(a)) : Optional(a) needs a.compare = {\n"
            "    fn larger(x : a, y : a) : a =\n        if x < y then y else x;\n"
            "    match list {\n        [] -> None\n"
            "      | first :: rest -> Some(List.foldLeft(rest, first, larger))\n    }\n}\n"
            "fn sorted(list : List(a)) : List(a) needs a.compare = {\n"
            "    fn into(set : OrderedSet.Set(b), x : b) : OrderedSet.Set(b) needs b.compare =\n"
            "        OrderedSet.put(set, x);\n"
            "    OrderedSet.toList(List.foldLeft(list, OrderedSet.empty, into))\n}\n"
            "fn shown(list : List(a)) : String needs a.show =\n"
            "    String.join(List.map(list, fn(x) = Io.show(x)), \" \")\n"
            "fn putAll(list : List(a)) : OrderedSet.Set(a) needs a.compare =\n"
            "    List.foldLeft(list, OrderedSet.empty, OrderedSet.put)\n"
            "export fn main() : Unit with Never = {\n"
            "    Io.println(Io.show(total([Money(1), Money(2)], Money(0))));\n"
            "    Io.println(Io.show(opposite(Money(3))));\n"
            "    Io.println(Io.show(largest([3, 9, 4])));\n"
            "    Io.println(Io.show(sorted([\"c\", \"a\", \"b\"])));\n"
            "    Io.println(shown([1, 2]));\n"
            "    Io.println(Io.show(OrderedSet.toList(putAll([2, 1, 2]))))\n}\n"),
    ?assertEqual(<<"Money(3)\nMoney(-3)\nSome(9)\n[\"a\", \"b\", \"c\"]\n1 2\n[1, 2]\n">>,
                 Output).

%% report §9.4, §4.9, Appendix E.1: under `needs a.show`, Io.show writes a
%% type built from `a`, its descriptor composed of the one passed in for
%% `a`; a recursive type stands in the place of `a` inside a recursive type,
%% each descriptor's mu binding its own refs. A regression test of the full
%% review's P4 (2026-10-04): a type built from a variable was refused
show_composed_test() ->
    {ok, Output} = run(
        "type Tree(a) = Leaf | Node(left : Tree(a), item : a, right : Tree(a))\n"
        "fn showAll(list : List(a)) : String needs a.show = Io.show(list)\n"
        "fn showOne(x : a) : String needs a.show = Io.show(Some(#(x, 1)))\n"
        "fn showTree(tree : Tree(a)) : String needs a.show = Io.show(tree)\n"
        "fn twice(x : a) : String needs a.show = showAll([x, x])\n"
        "export fn main() : Unit with m = {\n"
        "    Io.println(showAll([1, 2]));\n"
        "    Io.println(showOne(\"hi\"));\n"
        "    let inner = Node(left = Leaf, item = 'c', right = Leaf);\n"
        "    Io.println(showTree(Node(left = Leaf, item = Some(inner), right = Leaf)));\n"
        "    Io.println(twice([Some(1.5)]))\n"
        "}\n"),
    ?assertEqual(<<"[1, 2]\nSome(#(\"hi\", 1))\n"
                   "Node(left = Leaf, item = Some(Node(left = Leaf, item = 'c', right = Leaf)),"
                   " right = Leaf)\n"
                   "[[Some(1.5)], [Some(1.5)]]\n">>, Output).

%% report §2.4, §4.9, §3.5: `needs`, `derives`, `compare`, `negate` and
%% `show` are words only where they stand, and identifiers elsewhere, a
%% field, a binding, a parameter and a function among them, beside a
%% requirement and a derived compare. A regression test of the full
%% review's P17 and N20 (2026-10-04): `needs` and `derives` were reserved,
%% and a task's field `needs` was refused; the last three added with the
%% principles review's K11 (2026-10-09), which named them in §2.4, and
%% passed at once
words_by_position_test() ->
    {ok, Output} = run(
        "type Task = Task(name : String, needs : List(String))\n"
        "type Pair = Pair(left : Int, right : Int) derives compare\n"
        "fn largest(list : List(a)) : Optional(a) needs a.compare =\n"
        "    List.foldLeft(list, None, fn(best, x) = match best {\n"
        "        Some(b) -> if x < b then Some(b) else Some(x)\n"
        "      | None -> Some(x)\n"
        "    })\n"
        "fn count(derives : List(String)) : Int = List.size(derives)\n"
        "fn negate(show : Int) : Int = 0 - show\n"
        "export fn main() : Unit with Never = {\n"
        "    let task = Task(name = \"build\", needs = [\"fetch\", \"unpack\"]);\n"
        "    let needs = task.needs;\n"
        "    let compare = negate(count(needs));\n"
        "    Io.println(Int.toString(compare));\n"
        "    Io.println(Io.show(largest([Pair(left = 1, right = 2), Pair(left = 1, right = 3)])))\n"
        "}\n"),
    ?assertEqual(<<"-2\nSome(Pair(left = 1, right = 3))\n">>, Output).

%% report §3.5, §4.9: a derived compare orders by constructor in declaration
%% order, then field by field from the left, its parameters' members
%% supplied where it is used. Written after the code, it found a defect:
%% the member an operator resolves to supplied its own requirement as the
%% operator's, Int's compare as the runtime's own operation, and so none
derived_compare_test() ->
    {ok, Output} =
        run("type Shape = Dot | Circle(Int) | Rect(w : Int, h : Int) derives compare\n"
            "type Pair(a, b) = Pair(first : a, second : b) derives compare\n"
            "type Tree(a) = Leaf | Node(left : Tree(a), value : a, right : Tree(a))"
            " derives compare\n"
            "export fn main() : Unit with Never = {\n"
            "    let shapes =\n"
            "        [Rect(w = 1, h = 2), Dot, Circle(3), Rect(w = 1, h = 1), Circle(2)];\n"
            "    Io.println(Io.show(OrderedSet.toList(OrderedSet.fromList(shapes))));\n"
            "    let one = Pair(first = 1, second = \"b\");\n"
            "    Io.println(Io.show(one < Pair(first = 1, second = \"c\")));\n"
            "    let leaf = Node(left = Leaf, value = 2, right = Leaf);\n"
            "    Io.println(Io.show(leaf > Node(left = Leaf, value = 1, right = Leaf)));\n"
            "    Io.println(Io.show(Pair.compare(one, one)))\n}\n"),
    ?assertEqual(<<"[Dot, Circle(2), Circle(3), Rect(w = 1, h = 1), Rect(w = 1, h = 2)]\n"
                   "true\ntrue\nEqual\n">>, Output).

%% report §5.6, §4.9: a record filled from a namespace holds its
%% declarations, a requirement's members supplied at the record's type;
%% written after the code
fill_test() ->
    {ok, Output} =
        run("type Ops(s, a) = Ops(fromList : (List(a)) -> s, toList : (s) -> List(a))\n"
            "let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)\n"
            "let hashed : Ops(Set(Int), Int) = Ops(..Set, toList = Set.toList)\n"
            "fn roundTrip(list : List(a), ops : Ops(s, a)) : List(a) =\n"
            "    ops.toList(ops.fromList(list))\n"
            "export fn main() : Unit with Never = {\n"
            "    Io.println(Io.show(roundTrip([3, 1, 3], ordered)));\n"
            "    Io.println(Io.show(List.size(roundTrip([3, 1, 3], hashed))))\n}\n"),
    ?assertEqual(<<"[1, 3]\n2\n">>, Output).

%% report §5.6, §5.1: a path in a record update builds the nested update,
%% two paths sharing a prefix in one, the base and the field expressions
%% evaluated once each, in source order; written after the code
update_path_test() ->
    {ok, Output} =
        run("type Stats = Stats(indexed : Int, hits : Int)\n"
            "type Pool = Pool(name : String, stats : Stats)\n"
            "type Site = Site(pool : Pool, visits : Int)\n"
            "fn counted(pool : Pool) : Pool =\n"
            "    Pool(..pool, stats.indexed = pool.stats.indexed + 1)\n"
            "export fn main() : Unit with Never = {\n"
            "    let pool = Pool(name = \"p\", stats = Stats(indexed = 0, hits = 0));\n"
            "    Io.println(Io.show(counted(pool)));\n"
            "    Io.println(Io.show(Pool(..pool, stats.indexed = 1, name = \"q\","
            " stats.hits = 2)));\n"
            "    let site = Site(pool = pool, visits = 0);\n"
            "    Io.println(Io.show(Site(..site, pool.stats.hits = 5, visits = 1)));\n"
            "    let shown = Pool(..{ Io.println(\"base\"); pool },\n"
            "                     stats.indexed = { Io.println(\"a\"); 1 },\n"
            "                     name = { Io.println(\"b\"); \"r\" },\n"
            "                     stats.hits = { Io.println(\"c\"); 3 });\n"
            "    Io.println(Io.show(shown))\n}\n"),
    ?assertEqual(<<"Pool(name = \"p\", stats = Stats(indexed = 1, hits = 0))\n"
                   "Pool(name = \"q\", stats = Stats(indexed = 1, hits = 2))\n"
                   "Site(pool = Pool(name = \"p\", stats = Stats(indexed = 0, hits = 5)),"
                   " visits = 1)\n"
                   "base\na\nb\nc\n"
                   "Pool(name = \"r\", stats = Stats(indexed = 1, hits = 3))\n">>, Output).

%% report §8.7, Appendix E.27: a key holds the name it was made with, which
%% `Peer.name` answers, and the hash of its message type, which the
%% checker's supply gives it whether `Peer.key` is called or taken as a
%% value, so that two keys of one name at one type are one key. A
%% regression test of the key of a name and a hash, written after the code;
%% a find's comparison of the hash is the nodes' (test/ern_nodes_tests.erl)
peer_key_name_test() ->
    {ok, Output} =
        run("type Msg = Add(Int)\n"
            "fn made(make : (String) -> Peer.Key(Msg), name : String) : Peer.Key(Msg) =\n"
            "    make(name)\n"
            "export fn main() : Unit with Never = {\n"
            "    let counter : Peer.Key(Msg) = Peer.key(\"counter\");\n"
            "    let other = made(Peer.key, \"other\");\n"
            "    Io.println(Peer.name(counter) <> \" \" <> Peer.name(other));\n"
            "    Io.println(Io.show(#(made(Peer.key, \"counter\") == counter, other == counter)))\n"
            "}\n"),
    ?assertEqual(<<"counter other\n#(true, false)\n">>, Output).
