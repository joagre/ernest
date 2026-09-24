-module(ern_cli_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").

%%
%% Helpers: a fresh directory per test, sources written into it
%%

%% Unique within this VM; a leftover from an earlier run is removed first.
tmp() ->
    Dir = filename:join(["/tmp", "ern_cli_" ++ integer_to_list(erlang:unique_integer([positive]))]),
    file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

%% A tool run with the captured output as its error device, so a test
%% reads what the user sees on stderr.
ernc_err(Args) -> ern_cli:ernc(Args, group_leader()).
ern_err(Args) -> ern_cli:ern(Args, group_leader()).

write(Dir, Rel, Text) ->
    Path = filename:join(Dir, Rel),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Text),
    Path.

example(Base) ->
    "../../../examples/" ++ Base.

hello() ->
    "export fn main() -> Unit with Never = Io.println(\"hello, world\")\n".

%% The two-module program of the guide, as sources.
pair(Dir) ->
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = match Net.Http.parse(\"GET /\") {\n"
          "    Some(Net.Http.Request(method = m, path = p)) -> Io.println(m <> \" \" <> p)\n"
          "  | None -> Io.println(\"bad request\")\n"
          "}\n"),
    Dir.

%%
%% ernc, report §11.1
%%

%% report §11.1, §11.2, §8.1: a file compiles to .erc beside it and runs
single_file_test() ->
    Dir = tmp(),
    File = write(Dir, "hello.ern", hello()),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assert(filelib:is_regular(filename:join(Dir, "hello.erc"))),
    ?assertEqual(0, ern_cli:ern([filename:join(Dir, "hello.erc")])),
    ?assertEqual(<<"hello, world\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.1, §4.2, §11.1: a module is one file carrying a namespace;
%% directory mode compiles in dependency order into a
%% mirrored build tree; §11.2 loads the dependency by namespace
directory_mode_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: output mirrors the source root, not the directory argument
source_root_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/net"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/http.erc")).

%% report §11.1: a dependency outside the compiled subtree must have been
%% compiled into the build directory already
dependency_not_built_test() ->
    Dir = pair(tmp()),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/net"])),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])).

%% report §11.1: path components below the root are one lowercase word each
path_shape_test() ->
    Dir = tmp(),
    File = write(Dir, "Net/http.ern", hello()),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertNot(filelib:is_regular(filename:join(Dir, "Net/http.erc"))),
    Dir2 = tmp(),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir2, write(Dir2, "9x.ern", hello())])),
    Dir3 = tmp(),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir3, write(Dir3, "http_server.ern", hello())])),
    ?assertNot(filelib:is_regular(filename:join(Dir3, "http_server.erc"))).

%% report §11.1, §11.5: a parse error in directory mode is reported as
%% file:line:column: text, status 1
%% report §11.1: single-file mode with no --source-root uses the current
%% directory, so `ernc a.ern` in a project's directory works
default_root_test() ->
    Dir = tmp(),
    write(Dir, "hello.ern", hello()),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(0, ern_cli:ernc(["hello.ern"])),
        ?assert(filelib:is_regular(filename:join(Dir, "hello.erc")))
    after
        file:set_cwd(Cwd)
    end.

%% report §11.5: a parse error is its position, its message, and the source
%% under it with the span marked
parse_error_test() ->
    Dir = tmp(),
    File = write(Dir, "a.ern", "export fn f() -> Int = \n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertEqual(<<(list_to_binary(File))/binary, ":2:1: expected an expression instead of"
                   " end of input\n1 | export fn f() -> Int = \n2 | \n  | ^\n\n">>,
                 Out).

%% report Appendix D, §11.1, §11.2, §4.7: the foreign library Appendix D
%% writes out is compiled as a root of its own, a program is compiled
%% against its interface with --load-path and run with it, and prints what
%% the appendix's main says
appendix_d_library_test() ->
    Dir = tmp(),
    [Lib, Main | _] = appendix_d_blocks(),
    write(Dir, "lib/ets.ern", Lib),
    write(Dir, "src/main.ern", Main),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ernc(["--load-path", Dir ++ "/build/lib", "--out-dir",
                                  Dir ++ "/build/src", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["--load-path", Dir ++ "/build/lib",
                                 Dir ++ "/build/src/main.erc"])),
    ?assertEqual(<<"1\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2, §8.4: an Erlang module a `foreign fn` names is found as a
%% `.beam` in a directory of the load path. A regression test: nothing put a
%% user's own Erlang module where the host could find it
foreign_beam_on_load_path_test() ->
    Dir = tmp(),
    Erl = write(Dir, "erl/ern_cli_helper.erl",
                "-module(ern_cli_helper).\n-export([twice/1]).\ntwice(N) -> 2 * N.\n"),
    ok = filelib:ensure_path(Dir ++ "/beams"),
    {ok, ern_cli_helper} = compile:file(Erl, [{outdir, Dir ++ "/beams"}]),
    write(Dir, "src/main.ern",
          "foreign fn twice(n : Int) -> Int = \"ern_cli_helper:twice/1\"\n"
          "export fn main() -> Unit with Never = Io.println(Int.toString(twice(21)))\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["--load-path", Dir ++ "/beams", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: without the root that holds a module's dependency, the
%% dependency is an unknown name
load_path_needed_test() ->
    Dir = tmp(),
    [Lib, Main | _] = appendix_d_blocks(),
    write(Dir, "lib/ets.ern", Lib),
    write(Dir, "src/main.ern", Main),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build/src", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"unknown name Ets.new">>)).

%% The fenced code blocks of Appendix D, in order.
appendix_d_blocks() ->
    {ok, Report} = file:read_file("../../../ernest_report.md"),
    [_, AfterD] = binary:split(Report, <<"## Appendix D.">>),
    [D | _] = binary:split(AfterD, <<"## Appendix E.">>),
    Parts = binary:split(D, <<"```">>, [global]),
    [strip_fence_line(P) || {I, P} <- lists:zip(lists:seq(1, length(Parts)), Parts),
                            I rem 2 =:= 0].

strip_fence_line(Block) ->
    [_Info, Code] = binary:split(Block, <<"\n">>),
    Code.

%% report §4.8, §3.10, §4.2: an operator and an ordering on a type of a
%% compiled module resolve through its interface and call into its module;
%% a member it lacks is an error
operators_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/vec.ern",
          "export type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) -> Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(a, b)\n"
          "export fn show(Vec(n)) -> String = Int.toString(n)\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = {\n"
          "    let a = Geo.Vec.Vec(1);\n"
          "    let b = Geo.Vec.Vec(2);\n"
          "    Io.println(Geo.Vec.show(a + b));\n"
          "    Io.println(Float.toString((a * b) + 0.5));\n"
          "    Io.println(Bool.toString(a < b))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"3\n2.5\ntrue\n">>, iolist_to_binary(?capturedOutput)),
    write(Dir, "src/bad.ern", "export fn f(a : Geo.Vec.Vec, b) = a - b\n"),
    ?assertEqual(1, ernc_err(["--errors", "short", "--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "bad.ern:1:35: `-` is not defined on Geo.Vec.Vec\n$")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/bad.erc")).

%% report §4.2, §11.2: a type member of another module is called by its
%% module path, type, and member, and loads from the module that owns it
type_member_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/stack.ern",
          "export abstract type Stack(a) = Stack(List(a)) with {\n"
          "    empty : Stack(a);\n"
          "    push : (a, Stack(a)) -> Stack(a);\n"
          "    size : (Stack(a)) -> Int\n"
          "}\n"
          "export let Stack.empty : Stack(a) = Stack([])\n"
          "export fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)\n"
          "export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = {\n"
          "    let s = Lib.Stack.Stack.push(1, Lib.Stack.Stack.empty);\n"
          "    Io.println(Int.toString(Lib.Stack.Stack.size(s)));\n"
          "    let _ = Io.debug(#(s, 2));\n"
          "    Unit\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    %% report Appendix E.1: an abstract value outside its module
    ?assertEqual(<<"1\n#(<abstract>, 2)\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a prelude namespace
prelude_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/io.ern", "export fn println(s : String) -> Unit with m = Unit\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    %% nor the name of the prelude itself, which `Prelude.X` reaches
    Dir2 = tmp(),
    write(Dir2, "src/prelude.ern", "export fn f() -> Int = 1\n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir2 ++ "/build", Dir2 ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"takes the prelude namespace Prelude">>)).

%% report §4.2: `Prelude.send` is the prelude's `send` at run time too, past
%% a function of the module's own by that name
prelude_value_runs_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "fn send(n : Int) -> Int = n\n"
          "export fn main() -> Unit with m = {\n"
          "    let say = Prelude.send;\n"
          "    Prelude.send(Sys.stdout, Int.toString(send(1)) <> \"\\n\");\n"
          "    say(Sys.stdout, \"two\\n\")\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"1\ntwo\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module, found from either file and in either mode
namespace_clash_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "type Stack = Stack(Int)\n" ++ hello()),
    write(Dir, "src/main/stack.ern", "export fn push(n : Int) -> Int = n\n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "main/stack.ern and type Stack in main.ern share the namespace"
                        " Main.Stack")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    Single = ["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build"],
    ?assertEqual(1, ernc_err(Single ++ [Dir ++ "/src/main.ern"])),
    ?assertEqual(1, ernc_err(Single ++ [Dir ++ "/src/main/stack.ern"])).

%% report §4.2: where no type of the parent's clashes with it, a module
%% under the parent's namespace is reached from the parent by its whole
%% qualified name, its functions, its types, and its constructors alike
nested_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main/stack.ern",
          "export type Item = Item(Int)\n"
          "export fn push(i : Item) -> Int = match i { Item(n) -> n + 1 }\n"),
    write(Dir, "src/main.ern",
          "fn count(i : Main.Stack.Item) -> Int = Main.Stack.push(i)\n"
          "export fn main() -> Unit with m =\n"
          "    Io.println(Int.toString(count(Main.Stack.Item(1))))\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"2\n">>, iolist_to_binary(?capturedOutput)).

%% report §8.6, §7.4, §11.2: ern reports a deadlock as the entry process's
%% fault and exits 1
deadlock_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "type Msg = Ping\nexport fn main() -> Unit with Msg = receive { Ping -> Unit }\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err([Dir ++ "/build/main.erc"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput), "^fault: deadlock\n")).

%% report §4.4: an abstract type's constructor is not visible outside its module
abstract_constructor_outside_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export abstract type Stack(a) = Stack(List(a)) with { empty : Stack(a) }\n"
          "export let Stack.empty = Stack([])\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn f() -> Main.Stack(Int) = Main.Stack([])\n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Stack is the constructor of an abstract type and is not visible"
                        " outside its module")).

%% report §4.2: a module that names itself qualified is not a module cycle
self_qualified_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "export fn g() -> Int = 1\nexport fn f() -> Int = Main.g()\n"
                               "export fn main() -> Unit with Never ="
                               " Io.println(Int.toString(f()))\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: the standard library's own source root may take prelude
%% namespaces, and no other root may
stdlib_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", "../../../stdlib"])),
    ?assert(filelib:is_regular(Dir ++ "/build/bool.erc")),
    write(Dir, "src/bool.ern", "export fn not(b : Bool) -> Bool = b\n"),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/b2", Dir ++ "/src"])).

%% report §4.2, §11.1: a file under the standard library's source root is
%% compiled with that root, the default for it; another root is an error
stdlib_file_takes_its_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir, "../../../stdlib/optional.ern"])),
    %% report §11.1: and builds into build/stdlib, where its dependencies are
    ?assertEqual(0, ern_cli:ernc(["--doc", "../../../stdlib/float.ern"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "# Ernest module Float")),
    ?assert(filelib:is_regular(Dir ++ "/optional.erc")),
    ?assertEqual(1, ern_cli:ernc(["--source-root", "../../..", "--out-dir", Dir,
                                  "../../../stdlib/optional.ern"])).

%% report §11.2: a failed test's text prints as it was written (a
%% regression test: text outside ASCII printed as its UTF-8 bytes)
test_runner_unicode_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          <<"let dash = Test(name = \"dash\", run = fn() -> TestResult with Never =\n"
            "    Failed(\"a — b\"))\n"/utf8>>),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["--test", Dir ++ "/build/checks.erc"])),
    Out = unicode:characters_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Out, <<"dash: failed: a — b\n"/utf8>>)).

%% report §9.3, §11.2: ern --test runs every top-level let of type Test,
%% exported or not, each in its own process, reports each, and exits 1
%% unless every one passed
test_runner_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "fn add(a : Int, b : Int) -> Int = a + b\n"
          "let addsTwo = Test(name = \"adds two\", run = fn() -> TestResult with Never =\n"
          "    if add(1, 1) == 2 then Passed else Failed(\"not two\"))\n"
          "export let wrong = Test(name = \"wrong\", run = fn() -> TestResult with Never =\n"
          "    Failed(\"expected 3\"))\n"
          "let divides = Test(name = \"divides\", run = fn() -> TestResult with Never =\n"
          "    if 1 / (add(1, 1) - 2) == 0 then Passed else Passed)\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["--test", Dir ++ "/build/checks.erc"])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Out, "adds two: passed\n")),
    ?assertMatch({match, _}, re:run(Out, "wrong: failed: expected 3\n")),
    ?assertMatch({match, _}, re:run(Out, "divides: faulted: division by zero\n")),
    write(Dir, "src2/ok.ern",
          "let fine = Test(name = \"fine\", run = fn() -> TestResult with Never = Passed)\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build2", Dir ++ "/src2"])),
    ?assertEqual(0, ern_cli:ern(["--test", Dir ++ "/build2/ok.erc"])).

%% report §4.2: a module may not take a namespace of a standard library
%% module written in Ernest
stdlib_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/erl.ern", "export fn atom(s : String) -> String = s\n"),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.1, §11.1: a module cycle is an error naming the modules
module_cycle_test() ->
    Dir = tmp(),
    write(Dir, "a.ern", "export fn f() -> Int = B.g()\n"),
    write(Dir, "b.ern", "export fn g() -> Int = A.f()\n"),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir])).

%% report §11.1: a module is recompiled when its source, a dependency's
%% interface, the standard library's interfaces, or the compiler changed, and
%% not when only a dependency's bodies changed
recompile_rule_test() ->
    Dir = pair(tmp()),
    Args = ["--out-dir", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ernc(Args)),
    {ok, Main1} = file:read_file(Dir ++ "/build/main.erc"),
    {ok, Http1} = file:read_file(Dir ++ "/build/net/http.erc"),
    %% nothing changed: nothing rewritten
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% a body change in the dependency: it is rebuilt, its dependent is not
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\"))\n"
          "    else None\n"),
    ?assertEqual(0, ern_cli:ernc(Args)),
    {ok, Http2} = file:read_file(Dir ++ "/build/net/http.erc"),
    ?assertNotEqual(Http1, Http2),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% an interface change in the dependency: the dependent is rebuilt
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
          "export fn version() -> Int = 2\n"),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertNotEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    {ok, Main3} = file:read_file(Dir ++ "/build/main.erc"),
    %% a module built against other standard library interfaces is rebuilt
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(C) -> C#{stdlib => <<"another">>} end)),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")),
    %% a module built by another version of ernc is rebuilt
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(C) -> C#{compiler => <<"0.0.0">>} end)),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")).

%% A compiled module with its interface chunk changed by F.
forge(Beam, F) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    New = [case Id of
               "ErnI" -> {Id, term_to_binary(F(binary_to_term(C)))};
               _ -> {Id, C}
           end || {Id, C} <- Chunks],
    {ok, Forged} = beam_lib:build_module(New),
    Forged.

%% report §11.1: the sweep removes .erc files whose source is gone and
%% directories left empty; --no-clean keeps them; single-file mode does
%% not sweep
sweep_test() ->
    Dir = pair(tmp()),
    Args = ["--out-dir", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ernc(Args)),
    write(Dir, "src/main.ern", hello()),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(0, ern_cli:ernc(["--no-clean" | Args])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertNot(filelib:is_dir(Dir ++ "/build/net")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")).

%% report §11.1: --emit erl writes the Erlang source and no .erc
emit_erl_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--emit", "erl", "--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    {ok, Src} = file:read_file(Dir ++ "/build/net/http.erl"),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ern@net@http).">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(1, ern_cli:ernc(["--emit", "asm", Dir ++ "/src"])).

%% report §11.1, §11.5: an error is file:line:column: text, status 1
compile_error_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() -> Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, ernc_err(["--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:50: the argument does not fit Io.println:"
                   " expected String, found Int\n"
                   "1 | export fn main() -> Unit with Never = Io.println(1)\n"
                   "  |                                       ---------- Io.println : (String) ->"
                   " Unit with e\n"
                   "  |                                                  ^\n\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertNot(filelib:is_regular(filename:join(Dir, "bad.erc"))).

%% report §11.5: --errors short is the first line alone
errors_short_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() -> Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, ernc_err(["--errors", "short", "--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:50: the argument does not fit Io.println:"
                   " expected String, found Int\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.5: an error prints its source line whole, whatever the line
%% holds (a regression test: a character outside Latin-1 crashed ernc)
error_on_unicode_line_test() ->
    Dir = tmp(),
    File = write(Dir, "twice.ern", <<"fn twice(n) = n + n  // Int — or Float\n"/utf8>>),
    ?assertEqual(1, ernc_err(["--source-root", Dir, File])),
    Out = unicode:characters_to_binary(?capturedOutput),
    Line = <<"1 | fn twice(n) = n + n  // Int — or Float\n"/utf8>>,
    ?assertMatch({_, _}, binary:match(Out, Line)).

%% report §11.5: an error names its file by the path from the working
%% directory when the file lies under it
error_names_file_from_cwd_test() ->
    Dir = tmp(),
    write(Dir, "bad.ern", "export fn main() -> Unit with Never = Io.println(1)\n"),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(1, ernc_err(["--errors", "short", "bad.ern"])),
        ?assertMatch(<<"bad.ern:1:50: ", _/binary>>, iolist_to_binary(?capturedOutput))
    after
        file:set_cwd(Cwd)
    end.

%% report §8.6, §7.4: a fault in main is reported on stderr with its
%% cause, status 1
fault_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() -> Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertEqual(1, ern_err([filename:join(Dir, "boom.erc")])),
    ?assertEqual(<<"fault: division by zero\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.4, §11.5: every exported and every documented declaration,
%% with its type and its doc comment, as Markdown
doc_test() ->
    Dir = tmp(),
    File = write(Dir, "shapes.ern",
                 "/// A shape.\n"
                 "export type Shape = Dot | At(x : Int, y : Int)\n"
                 "export abstract type Box(a) = Box(List(a)) with {\n"
                 "    empty : Box(a);\n"
                 "    put : (a, Box(a)) -> Box(a)\n"
                 "}\n"
                 "export let Box.empty : Box(a) = Box([])\n"
                 "/// Put x in the box.\n"
                 "export fn Box.put(x : a, Box(xs) : Box(a)) -> Box(a) = Box(x :: xs)\n"
                 "export fn same(a, b) = a == b\n"
                 "/// Documented but private.\n"
                 "fn twice(n : Int) -> Int = 2 * n\n"
                 "fn hidden(n : Int) -> Int = n\n"),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--source-root", Dir, File])),
    Out = iolist_to_binary(?capturedOutput),
    Expect = fun(Text) -> ?assertMatch({_, _}, binary:match(Out, Text)) end,
    Expect(<<"# Ernest module Shapes\n\n## Shapes.Shape\n\n```ernest\n"
             "type Shape = Dot | At(x : Int, y : Int)\n```\n\nA shape.\n">>),
    Expect(<<"## Shapes.Box\n\n```ernest\nabstract type Box(a) with {\n"
             "    empty : Box(a);\n    put : (a, Box(a)) -> Box(a)\n}\n```\n">>),
    Expect(<<"## Shapes.Box.empty\n\n```ernest\nShapes.Box.empty : Box(a)\n```\n">>),
    Expect(<<"## Shapes.Box.put\n\n```ernest\nShapes.Box.put : (a, Box(a)) -> Box(a)\n```\n\n"
             "Put x in the box.\n">>),
    Expect(<<"## Shapes.same\n\n```ernest\nShapes.same : (a=, a=) -> Bool\n```\n">>),
    Expect(<<"## Shapes.twice\n\n```ernest\nShapes.twice : (Int) -> Int\n```\n\n"
             "Documented but private.\n">>),
    ?assertEqual(nomatch, binary:match(Out, <<"hidden">>)),
    %% a type error is reported as for a compilation
    ?assertEqual(1, ern_cli:ernc(["--doc", "--source-root", Dir,
                                  write(Dir, "bad.ern", "export fn f() -> Int = \"s\"\n")])).

%% report §11.1, §11.4: the documentation comes from the compiled module,
%% so --doc on a .erc writes what --doc on its source writes, and asking a
%% source for its page writes nothing
doc_from_compiled_test() ->
    Dir = tmp(),
    Src = write(Dir, "shapes.ern",
                "/// A shape.\n"
                "export type Shape = Dot | At(x : Int, y : Int)\n"
                "/// Twice n.\n"
                "export fn twice(n : Int) -> Int = 2 * n\n"),
    Out = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--source-root", Dir, "--out-dir", Out, Src])),
    FromSource = iolist_to_binary(?capturedOutput),
    ?assertEqual(false, filelib:is_regular(filename:join(Out, "shapes.erc"))),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, "--out-dir", Out, Src])),
    ?assertEqual(0, ern_cli:ernc(["--doc", filename:join(Out, "shapes.erc")])),
    %% the captured output is everything this test printed, so the page twice
    ?assertEqual(<<FromSource/binary, FromSource/binary>>, iolist_to_binary(?capturedOutput)),
    ?assertMatch({_, _}, binary:match(FromSource, <<"## Shapes.twice">>)).

%% report §11.1: the compiled module carries its documentation as EEP 48's
%% Docs chunk, so the host's own tools read an Ernest module
docs_chunk_test() ->
    Dir = tmp(),
    Src = write(Dir, "shapes.ern",
                "/// A shape.\n"
                "/// since 0.2.0\n"
                "export type Shape = Dot | At(x : Int, y : Int)\n"
                "/// Twice n.\n"
                "export fn twice(n : Int) -> Int = 2 * n\n"),
    Out = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, "--out-dir", Out, Src])),
    {ok, Beam} = file:read_file(filename:join(Out, "shapes.erc")),
    {ok, Docs} = ern_emitter:read_docs(Beam),
    {docs_v1, _, ernest, <<"text/markdown">>, none, Meta, Entries} = Docs,
    ?assertEqual(<<"shapes.ern">>, maps:get(source, Meta)),
    %% the parameter list as written, for the shell's completion
    ?assertMatch([{{type, 'Shape', 0}, _, [<<"type Shape = Dot | At(x : Int, y : Int)">>],
                   #{<<"en">> := <<"A shape.\nsince 0.2.0">>}, #{items := _}},
                  {{function, twice, 1}, _, [<<"Shapes.twice : (Int) -> Int">>],
                   #{<<"en">> := <<"Twice n.">>}, #{params := [n]}}],
                 Entries),
    %% Erlang's own documentation reader finds it, as it finds the standard
    %% library's modules installed under build/stdlib
    Mod = ern_emitter:module_atom(['Shapes']),
    ok = file:write_file(filename:join(Out, atom_to_list(Mod) ++ ".beam"), Beam),
    true = code:add_patha(Out),
    {module, Mod} = code:ensure_loaded(Mod),
    ?assertMatch({ok, {docs_v1, _, ernest, _, _, _, _}}, code:get_doc(Mod)),
    true = code:delete(Mod),
    true = code:del_path(Out).

%% report §9, §11.4: `ernc --doc` of the standard library's own source root
%% writes the prelude's page, first in the index, beside the modules' pages
prelude_page_test_() ->
    {timeout, 120, fun prelude_page/0}.

prelude_page() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--out-dir", Dir, "../../../stdlib"])),
    {ok, Index} = file:read_file(filename:join(Dir, "index.md")),
    ?assertMatch(<<"# Modules\n\n- [Prelude](prelude.md)\n", _/binary>>, Index),
    {ok, Page} = file:read_file(filename:join(Dir, "prelude.md")),
    ?assertMatch(<<"# Ernest prelude\n\n*Since 0.1.0.*", _/binary>>, Page),
    [?assertMatch({_, _}, binary:match(Page, <<"\n## ", N/binary, "\n">>))
     || N <- [<<"send">>, <<"Address.call">>, <<"Optional">>, <<"Sys.tcp">>, <<"Int">>]],
    ?assertMatch({_, _}, binary:match(Page, <<"from the prelude, report §9."/utf8>>)).

%% report §11.4, Appendix E.0 rule 6: docs/module_doc_template.md is what
%% `ernc --doc` renders for examples/template.ern, after its marker line
doc_template_test() ->
    Src = example("template.ern"),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--source-root", filename:dirname(Src), Src])),
    Out = iolist_to_binary(?capturedOutput),
    {ok, File} = file:read_file("../../../docs/module_doc_template.md"),
    Marker = <<"<!-- generated: ernc --doc examples/template.ern -->\n">>,
    [_, Generated] = binary:split(File, Marker),
    %% the last line names the compiler's version, which is compared to itself
    ?assertEqual(without_footer(Generated), without_footer(Out)),
    %% the module and every exported declaration say since which version, E.0 rule 6
    {match, Sinces} = re:run(Out, "\\*Since 0\\.1\\.0\\.\\*", [global]),
    %% the module states its since; no declaration differs from it
    ?assertEqual(1, length(Sinces)),
    %% every exported type has an Examples section, and the one function no
    %% module example calls, E.0 rule 6
    Sections = tl(binary:split(Out, <<"\n## ">>, [global])),
    Named = fun(Name) ->
                    Head = <<Name/binary, "\n">>,
                    hd([S || S <- Sections, binary:match(S, Head) =:= {0, byte_size(Head)}])
            end,
    lists:foreach(fun(Name) ->
                      ?assertMatch({_, _}, binary:match(Named(Name), <<"### Examples">>))
                  end,
                  [<<"Template.Point">>, <<"Template.Shape">>, <<"Template.Stack">>,
                   <<"Template.checked">>]),
    ?assertMatch({match, _},
                 re:run(Out, "\n---\n\nGenerated by ernc [0-9.]+ from template.ern.\n$")).

without_footer(Doc) ->
    hd(binary:split(Doc, <<"\n---\n\nGenerated by ernc">>)).

%% README, "What the toolchain accepts": every error text in erl/*/src or in
%% the shell's own Ernest source that names an MVP appears in the README's
%% table, by its first forty characters, so the table cannot drift from what
%% the code refuses
mvp_refusals_in_readme_test() ->
    {ok, Readme} = file:read_file("../../../README.md"),
    Pattern = "\"([^\"\n]*\\bin MVP [0-9][^\"\n]*)\"",
    Find = fun(Text) ->
               case re:run(Text, Pattern, [global, {capture, all_but_first, binary}]) of
                   {match, Ms} -> [M || [M] <- Ms];
                   nomatch -> []
               end
           end,
    %% the scan itself, on a sample, since every refusal may be lifted and
    %% a pattern that finds nothing would otherwise pass
    ?assertEqual([<<"x is not here yet; it arrives in MVP 9">>],
                 Find("fail(\"x is not here yet; it arrives in MVP 9\")")),
    Sources = filelib:wildcard("../../*/src/*.erl") ++ filelib:wildcard("../../../shell/*.ern"),
    %% a name the wildcard matches may not be a readable file: an editor's
    %% lock is a dangling symlink beside the file it locks, and a person
    %% with a source open should not see a red suite
    Texts = lists:usort(lists:append([Find(Text) || F <- Sources,
                                                    {ok, Text} <- [file:read_file(F)]])),
    Missing = [T || T <- Texts, binary:match(Readme, binary:part(T, 0, min(40, byte_size(T))))
                                =:= nomatch],
    ?assertEqual([], Missing).

%% report §11: --version prints the top-level VERSION file's content
version_test() ->
    {ok, V} = file:read_file("../../../VERSION"),
    ?assertEqual(0, ern_cli:ernc(["--version"])),
    ?assertEqual(<<"ernc ", (string:trim(V))/binary, "\n">>, iolist_to_binary(?capturedOutput)).

%% report §11: options are long; --help and --version stop with status 0
options_test() ->
    ?assertEqual(1, ern_cli:ernc(["-o", "x", example("hello.ern")])),
    ?assertEqual(1, ernc_err([])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "^ernc: one file or directory argument is required\nUsage: ")),
    ?assertEqual(0, ern_cli:ernc(["--version"])),
    ?assertEqual(0, ern_cli:ernc(["--help"])),
    ?assertEqual(0, ern_cli:ern(["--help"])).

%%
%% ern, report §11.2 and §11.3
%%

%% report §11.2: --load-path adds roots searched by namespace
load_path_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ok = filelib:ensure_dir(Dir ++ "/lib/net/http.erc"),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/lib/net/http.erc"),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(0, ern_cli:ern(["--load-path", Dir ++ "/lib", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: --main picks another exported entry point; one that takes
%% arguments is refused (§8.1)
main_option_test() ->
    Dir = pair(tmp()),
    write(Dir, "src/tools.ern",
          "export fn check() -> Unit with Never = Io.println(\"checked\")\n"
          "export fn twice(n : Int) -> Int = 2 * n\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["--main", "Tools.check", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"checked\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(1, ern_cli:ern(["--main", "Tools.twice", Dir ++ "/build/main.erc"])),
    ?assertEqual(1, ern_cli:ern(["--main", "check", Dir ++ "/build/main.erc"])).

%% report §8.5, §8.2, §11.2: top-level lets of every loaded module are
%% evaluated before main, dependencies first, with Sys.* bound
init_order_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/values.ern", "export let base = 40\nexport let out = Sys.stdout\n"),
    write(Dir, "src/main.ern",
          "let total = Lib.Values.base + 2\n"
          "export fn main() -> Unit with Never =\n"
          "    send(Lib.Values.out, Int.toString(total) <> \"\\n\")\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §7.3, §8.6, §11.2: a faulting main is status 1
fault_status_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() -> Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertEqual(1, ern_cli:ern([filename:join(Dir, "boom.erc")])).

%% report §11.2: the file must lie at the path of its namespace
misplaced_module_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/build/http.erc"),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/http.erc"])),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/nothing.erc"])).

%% report §11.2, plan 3.1: the shell is not in this toolchain yet, with or
%% without a file
shell_test() ->
    ?assertEqual(1, ern_cli:ern(["--shell"])),
    ?assertEqual(1, ern_cli:ern(["--shell", "--load-path", ".", example("hello.ern")])).

%% report §11.3, Appendix C: the configuration directory with an empty
%% peer list and a private key readable only by its owner; a second
%% creation fails
create_config_dir_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["--create-config-dir", Dir])),
    {ok, Conf} = file:read_file(Dir ++ "/.ernest/ernest.conf"),
    #{<<"peers">> := [], <<"public-key">> := <<"-----BEGIN PUBLIC KEY-----", _/binary>>,
      <<"network-address">> := _} = json:decode(Conf),
    {ok, Info} = file:read_file_info(Dir ++ "/.ernest/private-key.pem"),
    ?assertEqual(8#600, element(8, Info) band 8#777),
    {ok, Pem} = file:read_file(Dir ++ "/.ernest/private-key.pem"),
    ?assertMatch([{'PrivateKeyInfo', _, not_encrypted}], public_key:pem_decode(Pem)),
    ?assertEqual(1, ern_cli:ern(["--create-config-dir", Dir])).
