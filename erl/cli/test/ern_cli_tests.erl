-module(ern_cli_tests).

%% EUnit's captured output, asked of the test's group leader, which is
%% EUnit's. EUnit's own ?capturedOutput first asks whether it is by the
%% function it is running, which under load it can sample while that
%% process runs another module's code, and then answers "" (MVP 2.95's
%% intermittent failure of the diagnostics' examples).
-define(capturedOutput, captured_output()).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

%%
%% Helpers: a fresh directory per test, sources written into it
%%

%% Unique within this VM; a leftover from an earlier run is removed first.
tmp() ->
    Dir = filename:join(["/tmp", "ern_cli_" ++ integer_to_list(erlang:unique_integer([positive]))]),
    file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

%% report §11.6: ern format lays out a module in place, every module under
%% a directory, and with --check names each one not laid out, changing
%% none, the status 1; a module that does not parse is left as it is, its
%% diagnostic written. Regression test; the layout is ern_format_tests'.
format_test() ->
    Dir = tmp(),
    Loose = write(Dir, "loose.ern", "fn f(x) = x+1\n"),
    Neat = write(Dir, "neat.ern", "fn g(y) =\n    y\n"),
    ?assertEqual(1, ern_err(["format", "--check", Dir])),
    ?assertEqual(Loose ++ "\n", binary_to_list(iolist_to_binary(?capturedOutput))),
    ?assertEqual({ok, <<"fn f(x) = x+1\n">>}, file:read_file(Loose)),
    ?assertEqual(0, ern_err(["format", "--check", Neat])),
    ?assertEqual(0, ern_err(["format", Loose, Neat])),
    ?assertEqual({ok, <<"fn f(x) =\n    x + 1\n">>}, file:read_file(Loose)),
    ?assertEqual({ok, <<"fn g(y) =\n    y\n">>}, file:read_file(Neat)),
    Broken = write(Dir, "broken.ern", "fn h( = 1\n"),
    ?assertEqual(1, ern_err(["format", Broken])),
    ?assertEqual({ok, <<"fn h( = 1\n">>}, file:read_file(Broken)),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"broken.ern:1:">>)),
    ?assertEqual(1, ern_err(["format"])).

%% report §11: a file a job writes is written whole, beside its place and
%% renamed into it, which keeps what the file was: a module reached by a
%% link is laid out where the link leads and the link stays, a module keeps
%% its mode, and nothing is left beside it. A regression test, written
%% after the code; a job ended between the write and the rename, which
%% leaves the file beside it that no job reads, is not covered
format_writes_whole_test() ->
    Dir = tmp(),
    Target = write(Dir, "target.ern", "fn f(x) = x+1\n"),
    ok = file:change_mode(Target, 8#640),
    Link = filename:join(Dir, "link.ern"),
    ok = file:make_symlink("target.ern", Link),
    ?assertEqual(0, ern_err(["format", Link])),
    ?assertEqual({ok, "target.ern"}, file:read_link(Link)),
    ?assertEqual({ok, <<"fn f(x) =\n    x + 1\n">>}, file:read_file(Target)),
    {ok, Info} = file:read_file_info(Target),
    ?assertEqual(8#640, element(8, Info) band 8#777),
    ?assertEqual(["link.ern", "target.ern"], lists:sort(element(2, file:list_dir(Dir)))).

%% report §11: two jobs writing one file at once each write it whole, and
%% the file is one of theirs. A regression test: they wrote beside it under
%% one name, and the second rename found the first had taken it, status 70
writes_at_once_test_() ->
    {timeout, 60, fun writes_at_once/0}.

writes_at_once() ->
    Dir = tmp(),
    File = write(Dir, "twice.ern", "export fn f() : Int = 1\n"),
    Args = ["build", "--source-root", Dir, File],
    Self = self(),
    Build = fun() -> Self ! {built, ern_cli:ern(Args)} end,
    lists:foreach(fun(N) ->
                      %% a changed source, so that every build writes
                      write(Dir, "twice.ern", "export fn f() : Int = " ++ integer_to_list(N)
                                              ++ "\n"),
                      [spawn(Build) || _ <- lists:seq(1, 8)],
                      ?assertEqual(lists:duplicate(8, 0),
                                   [receive {built, S} -> S end || _ <- lists:seq(1, 8)])
                  end, lists:seq(1, 5)),
    ?assertEqual(["twice.erc", "twice.ern"], lists:sort(element(2, file:list_dir(Dir)))).

%% report §11: `ern test` runs a module of more tests than the host holds
%% values live at once. A regression test: the list of a module's tests was
%% one expression, which the host refused past about a thousand, and
%% `ern build` failed with status 70
many_tests_test_() ->
    {timeout, 60, fun many_tests/0}.

many_tests() ->
    Dir = tmp(),
    File = write(Dir, "many.ern",
                 [["let t", integer_to_list(I), " : Test = Test(name = \"t", integer_to_list(I),
                   "\", run = fn() = Passed)\n"] || I <- lists:seq(1, 1100)]),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "many.erc")])).

%% report §11: a `.erc` that is no compiled module is refused by `ern doc`,
%% `ern run` and `ern test` alike, by its name. A regression test: `ern doc`
%% failed with status 70, and a run's refusal quoted the file's bytes
not_a_compiled_module_test() ->
    Dir = tmp(),
    Erc = write(Dir, "junk.erc", "garbage\n"),
    lists:foreach(fun(Job) ->
                      ?assertEqual(1, ern_err([Job, Erc])),
                      Said = unicode:characters_to_binary(?capturedOutput),
                      ?assertMatch({_, _},
                                   binary:match(Said, <<"junk.erc is not a compiled module">>))
                  end, ["doc", "run", "test"]).

%% report §11.1: a name that is not UTF-8, of a `.ern` or of a directory
%% that holds one, is an error; one of another file is passed over. A
%% regression test: the host left such a name out with a warning of its own
%% on standard output
name_not_utf8_test() ->
    Dir = tmp(),
    write(Dir, "src/ok.ern", "export let x : Int = 1\n"),
    ok = file:write_file(filename:join(Dir, <<"src/notes", 16#FF, ".txt">>), <<>>),
    ?assertEqual(0, build_err([Dir ++ "/src"])),
    ok = file:write_file(filename:join(Dir, <<"src/n", 16#FF, "me.ern">>), <<>>),
    ?assertEqual(1, build_err([Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"a name that is not UTF-8: ">>)),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"src/n\\xFFme.ern">>)).

%% report §11: a word of the command line that is not UTF-8, as the host
%% gives one, is refused before the job begins, each byte past ASCII
%% written `\xHH`. A regression test: every job ended with an internal
%% error and status 70
word_not_utf8_test() ->
    Word = {error, "n", <<16#FF, "me.ern">>},
    ?assertEqual(1, ern_err([Word])),
    ?assertMatch({0, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"ern: a word that is not UTF-8: n\\xFFme.ern\n">>)),
    lists:foreach(fun(Job) ->
                          ?assertEqual(1, ern_err([Job, Word])),
                          Line = iolist_to_binary(["ern ", Job,
                                                   ": a word that is not UTF-8: n\\xFFme.ern\n"]),
                          ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(
                                                              ?capturedOutput), Line))
                  end, ["build", "doc", "format", "run", "test", "shell", "config"]).

%% report §11.6: a file named alone is a module when its name ends in
%% `.ern` and is otherwise one word, and those under a directory are found
%% as `ern build` finds them (§11.1); a file that is none is refused and
%% left as it is. A regression test: `ern format` laid out any file named
%% (findings T11)
format_finds_modules_as_build_test() ->
    Dir = tmp(),
    Text = "fn f(x) = x+1\n",
    Notes = write(Dir, "notes.txt", Text),
    Upper = write(Dir, "Bad.ern", Text),
    Under = write(Dir, "src/Sub/ok.ern", Text),
    Refused = fun(Args, Said) ->
                      ?assertEqual(1, ern_err(["format" | Args])),
                      ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(
                                                          ?capturedOutput), Said))
              end,
    Refused([Notes], <<"notes.txt does not end in .ern">>),
    Refused([Upper], <<"path component `Bad` must be lowercase">>),
    Refused([Dir ++ "/src"], <<"path component `Sub` must be lowercase">>),
    [?assertEqual({ok, list_to_binary(Text)}, file:read_file(F)) || F <- [Notes, Upper, Under]].

%% report §11: a file its owner may not write is refused, and nothing is
%% left beside it; so is one in a directory that cannot be written. A
%% regression test: `ern format` of a read-only file failed with status 70
%% and left its temporary file
read_only_refused_test() ->
    Dir = tmp(),
    File = write(Dir, "ro.ern", "fn f(x) = x+1\n"),
    ok = file:change_mode(File, 8#444),
    ?assertEqual(1, ern_err(["format", File])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"ro.ern: permission denied">>)),
    ?assertEqual({ok, ["ro.ern"]}, file:list_dir(Dir)),
    Closed = filename:join(Dir, "closed"),
    Inside = write(Closed, "c.ern", "fn f(x) = x+1\n"),
    ok = file:change_mode(Closed, 8#555),
    ?assertEqual(1, ern_err(["format", Inside])),
    ?assertEqual({ok, ["c.ern"]}, file:list_dir(Closed)),
    ok = file:change_mode(Closed, 8#755).

%% A tool run with the captured output as its error device, so a test
%% reads what the user sees on stderr.
build_err(Args) -> ern_cli:ern(["build" | Args], group_leader()).
ern_err(Args) -> ern_cli:ern(Args, group_leader()).

write(Dir, Rel, Text) ->
    Path = filename:join(Dir, Rel),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Text),
    Path.

example(Base) ->
    "../../../examples/" ++ Base.

hello() ->
    "export fn main() : Unit with Never = Io.println(\"hello, world\")\n".

%% The two-module program of the guide, as sources.
pair(Dir) ->
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = match Net.Http.parse(\"GET /\") {\n"
          "    Some(Net.Http.Request(method = m, path = p)) -> Io.println(m <> \" \" <> p)\n"
          "  | None -> Io.println(\"bad request\")\n"
          "}\n"),
    Dir.

%%
%% ern build, report §11.1
%%

%% report §11.1, §11.2, §8.1: a file compiles to .erc beside it and runs
single_file_test() ->
    Dir = tmp(),
    File = write(Dir, "hello.ern", hello()),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assert(filelib:is_regular(filename:join(Dir, "hello.erc"))),
    ?assertEqual(0, ern_cli:ern(["run", filename:join(Dir, "hello.erc")])),
    ?assertEqual(<<"hello, world\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.1, §4.2, §11.1: a module is one file carrying a namespace;
%% directory mode compiles in dependency order into a
%% mirrored build tree; §11.2 loads the dependency by namespace
directory_mode_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: output mirrors the source root, not the directory argument
source_root_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 "--build-root", Dir ++ "/build", Dir ++ "/src/net"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/http.erc")).

%% report §11.1: a dependency outside the compiled subtree must have been
%% compiled into the build directory already
dependency_not_built_test() ->
    Dir = pair(tmp()),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 "--build-root", Dir ++ "/build", Dir ++ "/src/main.ern"])),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 "--build-root", Dir ++ "/build", Dir ++ "/src/net"])),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 "--build-root", Dir ++ "/build", Dir ++ "/src/main.ern"])).

%% report §11.1: path components below the root are one lowercase word each
path_shape_test() ->
    Dir = tmp(),
    File = write(Dir, "Net/http.ern", hello()),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertNot(filelib:is_regular(filename:join(Dir, "Net/http.erc"))),
    Dir2 = tmp(),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", Dir2, write(Dir2, "9x.ern", hello())])),
    Dir3 = tmp(),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", Dir3,
                                 write(Dir3, "http_server.ern", hello())])),
    ?assertNot(filelib:is_regular(filename:join(Dir3, "http_server.erc"))).

%% report §11.1: directory mode passes over a file or directory whose name
%% begins with a dot, as Emacs's lock file, a dangling link named `.#` and
%% the file's name. A regression test, written after the fix, of a lock
%% file that stopped `make`; a name beginning with `#` ends in `#` and is
%% no `.ern`, so it is not covered.
dot_names_passed_over_test() ->
    Dir = tmp(),
    write(Dir, "main.ern", hello()),
    ok = file:make_symlink("someone@host.4242", filename:join(Dir, ".#main.ern")),
    write(Dir, ".cache/stale.ern", "not Ernest"),
    ?assertEqual(0, ern_cli:ern(["build", Dir])),
    ?assert(filelib:is_regular(filename:join(Dir, "main.erc"))),
    ?assertNot(filelib:is_regular(filename:join(Dir, ".cache/stale.erc"))).

%% report §11.1, §4.2: the segment a path component names is the one the
%% path check accepts, since the shell's `:load` completion asks for it
%% rather than restating the rule; a regression test of the one owner
segment_test() ->
    ?assertEqual({ok, "Http"}, ern_cli:segment("http")),
    ?assertEqual({ok, "V2"}, ern_cli:segment("v2")),
    ?assertEqual(error, ern_cli:segment("Net")),
    ?assertEqual(error, ern_cli:segment("9x")),
    ?assertEqual(error, ern_cli:segment("http_server")),
    ?assertEqual({'Some', <<"Http">>}, ern_shell:segment(<<"http">>)),
    ?assertEqual('None', ern_shell:segment(<<"Bad">>)).

%% report §11.1, §11.5: a parse error in directory mode is reported as
%% file:line:column: text, status 1
%% report §11.1: single-file mode with no --source-root uses the current
%% directory, so `ern build a.ern` in a project's directory works
default_root_test() ->
    Dir = tmp(),
    write(Dir, "hello.ern", hello()),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(0, ern_cli:ern(["build", "hello.ern"])),
        ?assert(filelib:is_regular(filename:join(Dir, "hello.erc")))
    after
        file:set_cwd(Cwd)
    end.

%% report §11.5: a parse error is its position, its message, and the source
%% under it with the span marked
parse_error_test() ->
    Dir = tmp(),
    File = write(Dir, "a.ern", "export fn f() : Int = \n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertEqual(<<(list_to_binary(File))/binary, ":2:1: expected an expression instead of"
                   " end of input\n1 | export fn f() : Int = \n2 | \n  | ^\n\n">>,
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
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ern(["build", "--load-path", Dir ++ "/build/lib", "--build-root",
                                  Dir ++ "/build/src", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--load-path", Dir ++ "/build/lib",
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
          "foreign fn twice(n : Int) : Int = \"ern_cli_helper:twice/1\"\n"
          "export fn main() : Unit with Never = Io.println(Int.toString(twice(21)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--load-path", Dir ++ "/beams", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: without the root that holds a module's dependency, the
%% dependency is an unknown name
load_path_needed_test() ->
    Dir = tmp(),
    [Lib, Main | _] = appendix_d_blocks(),
    write(Dir, "lib/ets.ern", Lib),
    write(Dir, "src/main.ern", Main),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build/src", Dir ++ "/src"])),
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
          "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) : Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = Int.compare(a, b)\n"
          "export fn show(Vec(n)) : String = Int.toString(n)\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = {\n"
          "    let a = Geo.Vec.Vec(1);\n"
          "    let b = Geo.Vec.Vec(2);\n"
          "    Io.println(Geo.Vec.show(a + b));\n"
          "    Io.println(Float.toString((a * b) + 0.5));\n"
          "    Io.println(Bool.toString(a < b))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"3\n2.5\ntrue\n">>, iolist_to_binary(?capturedOutput)),
    write(Dir, "src/bad.ern", "export fn f(a : Geo.Vec.Vec, b) = a - b\n"),
    ?assertEqual(1, build_err(["--short-errors", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "bad.ern:1:35: `-` is not defined on Geo.Vec.Vec\n$")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/bad.erc")).

%% report §4.2, §11.2: a type member of another module is called by its
%% module path, type, and member, and loads from the module that owns it
type_member_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/stack.ern",
          "export abstract type Stack(a) = Stack(List(a))\n"
          "export let Stack.empty : Stack(a) = Stack([])\n"
          "export fn Stack.push(x : a, Stack(xs) : Stack(a)) : Stack(a) = Stack(x :: xs)\n"
          "export fn Stack.size(Stack(xs) : Stack(a)) : Int = List.size(xs)\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = {\n"
          "    let s = Lib.Stack.Stack.push(1, Lib.Stack.Stack.empty);\n"
          "    Io.println(Int.toString(Lib.Stack.Stack.size(s)));\n"
          "    let _ = Io.debug(#(s, 2));\n"
          "    Unit\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    %% report Appendix E.1: an abstract value outside its module
    ?assertEqual(<<"1\n#(<abstract>, 2)\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a prelude namespace
prelude_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/io.ern", "export fn println(s : String) : Unit with m = Unit\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    %% nor the name of the prelude itself, which `Prelude.X` reaches
    Dir2 = tmp(),
    write(Dir2, "src/prelude.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(1, build_err(["--build-root", Dir2 ++ "/build", Dir2 ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"takes the prelude namespace Prelude">>)).

%% report §4.2: the refusal names whose namespace a file at the source root
%% takes: `Event` and `Sys` are the prelude's, `Io` the standard library's.
%% A regression test, written after the code; it does not cover a namespace
%% that both take, such as `Int`, which is named as the prelude's.
taken_namespace_names_owner_test() ->
    lists:foreach(
      fun(File) ->
              Dir = tmp(),
              write(Dir, "src/" ++ File, "export fn f() : Int = 1\n"),
              ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"]))
      end, ["down.ern", "io.ern"]),
    Out = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Out, <<"down.ern takes the prelude namespace Down">>)),
    ?assertMatch({_, _},
                 binary:match(Out, <<"io.ern takes the standard library namespace Io">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"prelude namespace Io">>)),
    %% report §9.7: the prelude binds no system reference, so `Sys` is free
    Dir = tmp(),
    write(Dir, "src/sys.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(0, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: `Prelude.send` is the prelude's `send` at run time too, past
%% a function of the module's own by that name
prelude_value_runs_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "fn send(n : Int) : Int = n\n"
          "export fn main() : Unit with String = {\n"
          "    let say = Prelude.send;\n"
          "    let me = self();\n"
          "    Prelude.send(me, Int.toString(send(1)));\n"
          "    say(me, \"two\");\n"
          "    receive { s -> Io.println(s) };\n"
          "    receive { s -> Io.println(s) }\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"1\ntwo\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module, found from either file and in either mode
namespace_clash_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "type Stack = Stack(Int)\n" ++ hello()),
    write(Dir, "src/main/stack.ern", "export fn push(n : Int) : Int = n\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "main/stack.ern and type Stack in main.ern share the namespace"
                        " Main.Stack")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    Single = ["--source-root", Dir ++ "/src", "--build-root", Dir ++ "/build"],
    ?assertEqual(1, build_err(Single ++ [Dir ++ "/src/main.ern"])),
    ?assertEqual(1, build_err(Single ++ [Dir ++ "/src/main/stack.ern"])).

%% report §4.2: where no type of the parent's clashes with it, a module
%% under the parent's namespace is reached from the parent by its whole
%% qualified name, its functions, its types, and its constructors alike
nested_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main/stack.ern",
          "export type Item = Item(Int)\n"
          "export fn push(i : Item) : Int = match i { Item(n) -> n + 1 }\n"),
    write(Dir, "src/main.ern",
          "fn count(i : Main.Stack.Item) : Int = Main.Stack.push(i)\n"
          "export fn main() : Unit with m =\n"
          "    Io.println(Int.toString(count(Main.Stack.Item(1))))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"2\n">>, iolist_to_binary(?capturedOutput)).

%% report §8.6, §7.4, §11.2: ern reports a deadlock as the entry process's
%% fault and exits 1
deadlock_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "type Msg = Ping\nexport fn main() : Unit with Msg = receive { Ping -> Unit }\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                        "^Main.main faulted: deadlock\n")).

%% report §4.4: an abstract type's constructor is not visible outside its module
abstract_constructor_outside_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export abstract type Stack(a) = Stack(List(a))\n"
          "export let Stack.empty = Stack([])\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn f() : Main.Stack(Int) = Main.Stack([])\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Stack is the constructor of an abstract type and is not visible"
                        " outside its module")).

%% report §4.2: type names that differ only in case are distinct, and a
%% type whose name differs only in case from a child module's segment does
%% not take that module's namespace: `STACK` in main.ern beside
%% main/stack.ern compiles, `STACK.get` and `Main.STACK.get` are main's own
%% member, and `Main.Stack.one` is the child module's. A regression test,
%% written after the code; single-file mode is not covered.
case_distinct_names_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export type STACK = STACK(Int)\n"
          "export type Stack2 = A\n"
          "export type STACK2 = B\n"
          "export fn STACK.get(s : STACK) : Int = match s { STACK(n) -> n }\n"
          "export fn main() : Unit with m = Io.println(Int.toString(\n"
          "    STACK.get(STACK(3)) * 100 + Main.STACK.get(STACK(4)) * 10 + Main.Stack.one()))\n"),
    write(Dir, "src/main/stack.ern", "export fn one() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"341\n">>, iolist_to_binary(?capturedOutput)).

%% report §3.5, §4.4: an abstract type's fields have no selector outside its
%% module
abstract_field_outside_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export abstract type Box = Box(n : Int)\n"
          "export let Box.one = Box(n = 1)\n"
          "export fn inside(b : Box) : Int = b.n\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn g() : Int = Main.Box.one.n\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Box is abstract, and its fields are its module's alone")).

%% report §4.2: a module that names itself qualified is not a module cycle
self_qualified_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "export fn g() : Int = 1\nexport fn f() : Int = Main.g()\n"
                               "export fn main() : Unit with Never ="
                               " Io.println(Int.toString(f()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: the standard library's own source root may take prelude
%% namespaces, and no other root may
stdlib_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", "../../../stdlib"])),
    ?assert(filelib:is_regular(Dir ++ "/build/bool.erc")),
    write(Dir, "src/bool.ern", "export fn not(b : Bool) : Bool = b\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/b2", Dir ++ "/src"])).

%% report §4.2, §11.1: a file under the standard library's source root is
%% compiled with that root, the default for it; another root is an error
stdlib_file_takes_its_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir, "../../../stdlib/optional.ern"])),
    %% report §11.1: and builds into build/stdlib, where its dependencies are
    ?assertEqual(0, ern_cli:ern(["doc", "../../../stdlib/float.ern"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "# Ernest module Float")),
    ?assert(filelib:is_regular(Dir ++ "/optional.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", "../../..", "--build-root", Dir,
                                  "../../../stdlib/optional.ern"])).

%% report §11.2: a failed test's text prints as it was written (a
%% regression test: text outside ASCII printed as its UTF-8 bytes)
test_runner_unicode_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          <<"let dash = Test(name = \"dash\", run = fn() : TestResult with Never =\n"
            "    Failed(\"a — b\"))\n"/utf8>>),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/checks.erc"])),
    Out = unicode:characters_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Out, <<"dash: failed: a — b\n"/utf8>>)).

%% report §9.3, §11.2: ern test runs every top-level let of type Test,
%% exported or not, each in its own process, reports each, and exits 1
%% unless every one passed
test_runner_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "fn add(a : Int, b : Int) : Int = a + b\n"
          "let addsTwo = Test(name = \"adds two\", run = fn() : TestResult with Never =\n"
          "    if add(1, 1) == 2 then Passed else Failed(\"not two\"))\n"
          "export let wrong = Test(name = \"wrong\", run = fn() : TestResult with Never =\n"
          "    Failed(\"expected 3\"))\n"
          "let divides = Test(name = \"divides\", run = fn() : TestResult with Never =\n"
          "    if 1 / (add(1, 1) - 2) == 0 then Passed else Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/checks.erc"])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Out, "adds two: passed\n")),
    ?assertMatch({match, _}, re:run(Out, "wrong: failed: expected 3\n")),
    ?assertMatch({match, _}, re:run(Out, "divides: faulted: division by zero\n")),
    write(Dir, "src2/ok.ern",
          "let fine = Test(name = \"fine\", run = fn() : TestResult with Never = Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build2", Dir ++ "/src2"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build2/ok.erc"])).

%% report §11.2, §8.6: `ern test` runs its tests one at a time in the order
%% the module declares them, printing each line as the test ends, after
%% what the test wrote; a deadlock while a test runs is that test's fault,
%% and the run goes on with the next. A regression test: the lines were
%% printed after every test had run, and a deadlock ended the whole run.
test_runner_streams_test_() ->
    {timeout, 60, fun test_runner_streams/0}.

test_runner_streams() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "type Msg = Go | Ask(reply : Reply(Int))\n"
          "fn waiter() : Unit with Msg = receive { Go -> Unit }\n"
          "let first = Test(name = \"first\", run = fn() : TestResult with Never = {\n"
          "    Io.println(\"inside first\");\n"
          "    Passed\n"
          "})\n"
          "let stuck = Test(name = \"stuck\", run = fn() : TestResult with Never = {\n"
          "    let w = spawn(Local, waiter);\n"
          "    if Address.callForever(w, fn(r) = Ask(reply = r)) == 0 then Passed else Passed\n"
          "})\n"
          "let last = Test(name = \"last\", run = fn() : TestResult with Never = Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["test", Dir ++ "/build/checks.erc"])),
    ?assertEqual(<<"inside first\nfirst: passed\nstuck: faulted: deadlock\nlast: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, Appendix E.23: under `ern test` Os.arguments is the empty
%% list, and Os.exit faults the test that calls it and the run goes on.
%% Written after the code, it found that a test faulting at once was
%% reported twice, its line and a fault on standard error, since it could
%% fault before the runner knew it as the test that runs.
test_runner_os_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "let none = Test(name = \"none\", run = fn() : TestResult with Never =\n"
          "    if Os.arguments == [] then Passed else Failed(\"arguments\"))\n"
          "let exits = Test(name = \"exits\", run = fn() : TestResult with Never = Os.exit(2))\n"
          "let later = Test(name = \"later\", run = fn() : TestResult with Never = Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["test", Dir ++ "/build/checks.erc"])),
    ?assertEqual(<<"none: passed\nexits: faulted: exited with status 2\nlater: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, Appendix E.23: the words after `ern run`'s file are the
%% program's, whatever they look like, and the job's options come before
%% the file; an argument that is not UTF-8, as the host gives one, is
%% refused by its position before anything runs; and `ern run` exits with
%% the status Os.exit gives. A regression test, written after the code; the
%% host's own forms of an argument are ern_integration_tests' to cover.
run_arguments_test() ->
    Dir = tmp(),
    write(Dir, "src/args.ern",
          "export fn main() : Unit with Never = {\n"
          "    Io.println(Io.show(Os.arguments));\n"
          "    Os.exit(List.size(Os.arguments))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Erc = Dir ++ "/build/args.erc",
    ?assertEqual(3, ern_cli:ern(["run", "--load-path", Dir ++ "/build", Erc,
                                 "--main", "x", "a b"])),
    ?assertEqual(1, ern_err(["run", Erc, "ok", {incomplete, "caf", <<16#e9>>}])),
    ?assertEqual(<<"[\"--main\", \"x\", \"a b\"]\nern run: argument 2 is not UTF-8\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a namespace of a standard library
%% module written in Ernest
stdlib_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/erl.ern", "export fn atom(s : String) : String = s\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.1, §11.1: a module cycle is an error naming the modules
module_cycle_test() ->
    Dir = tmp(),
    write(Dir, "a.ern", "export fn f() : Int = B.g()\n"),
    write(Dir, "b.ern", "export fn g() : Int = A.f()\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir])).

%% report §4.1, §11.1: a module cycle refused leaves nothing behind in the
%% process that compiled. A regression test: the graph the order is found
%% in was left undeleted when the cycle was refused, a table each time,
%% which a shell that compiles on `:load` would keep for the session
module_cycle_leaves_no_table_test() ->
    Dir = tmp(),
    write(Dir, "a.ern", "export fn f() : Int = B.g()\n"),
    write(Dir, "b.ern", "export fn g() : Int = A.f()\n"),
    Args = ["--build-root", Dir ++ "/build", Dir],
    ?assertEqual(1, build_err(Args)),
    Tables = length(ets:all()),
    ?assertEqual(1, build_err(Args)),
    ?assertEqual(Tables, length(ets:all())).

%% report §11.1: a module is recompiled when its source, a dependency's
%% interface, the standard library's interfaces, or the compiler changed, and
%% not when only a dependency's bodies changed
recompile_rule_test() ->
    Dir = pair(tmp()),
    Args = ["--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, Main1} = file:read_file(Dir ++ "/build/main.erc"),
    {ok, Http1} = file:read_file(Dir ++ "/build/net/http.erc"),
    %% nothing changed: nothing rewritten
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% a body change in the dependency: it is rebuilt, its dependent is not
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\"))\n"
          "    else None\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, Http2} = file:read_file(Dir ++ "/build/net/http.erc"),
    ?assertNotEqual(Http1, Http2),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% an interface change in the dependency: the dependent is rebuilt
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
          "export fn version() : Int = 2\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertNotEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    {ok, Main3} = file:read_file(Dir ++ "/build/main.erc"),
    %% a module built against other standard library interfaces is rebuilt
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(C) -> C#{stdlib => <<"another">>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")),
    %% a module built by another version of ern is rebuilt
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(C) -> C#{compiler => <<"0.0.0">>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")),
    %% and one built by another build of this version, whose code changed: a
    %% regression test, since the version alone was compared and a changed
    %% compiler kept what it had built before
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(C) -> C#{compiler => <<?VERSION>>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")).

%% report §11.1: a module is recompiled when the code of the compiler that
%% built it changed, so the modules hashed are every module of the toolchain
%% that the compiling modules call. A regression test: six were left out,
%% and a change to one of them, `ern_docs` among them, left every .erc
%% current; `ern_cli` is hashed and its calls are not followed, since its
%% other jobs call the runtime and the shell
compiler_modules_closed_test() ->
    Modules = ern_cli:compiler_modules(),
    Called = lists:usort([C || M <- Modules -- [ern_cli], C <- calls(M)]),
    ?assertEqual([], Called -- Modules).

%% The modules of the toolchain that M calls, from its imports.
calls(M) ->
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(code:which(M), [imports]),
    lists:usort([C || {C, _, _} <- Imports, lists:prefix("ern_", atom_to_list(C))]).

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
%% directories left empty; single-file mode does not sweep
sweep_test() ->
    Dir = pair(tmp()),
    Args = ["--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    write(Dir, "src/main.ern", hello()),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 "--build-root", Dir ++ "/build", Dir ++ "/src/main.ern"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertNot(filelib:is_dir(Dir ++ "/build/net")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")).

%% report §11.1: the sweep keeps a .erc whose source lies outside the source
%% root, one it cannot read, a directory that was empty before, and what lies
%% under a dot name. A regression test: it removed a library's module the
%% build had just compiled against, every empty directory, and a .git of
%% empty directories; it does not cover a .erc of an earlier build that
%% reads but records no path
sweep_keeps_what_no_build_wrote_test() ->
    Dir = tmp(),
    Build = Dir ++ "/build",
    write(Dir, "lib/util.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit with Never =\n"
                               "    Io.println(Int.toString(Util.f()))\n"),
    write(Dir, "build/old.erc", "not a module\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Build, Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Build, "--load-path", Build,
                                 Dir ++ "/src"])),
    ?assert(filelib:is_regular(Build ++ "/util.erc")),
    ?assert(filelib:is_regular(Build ++ "/old.erc")),
    %% built in place, the build tree is the source tree
    ok = filelib:ensure_path(Dir ++ "/src/empty"),
    ok = filelib:ensure_path(Dir ++ "/src/.git/refs/tags"),
    ?assertEqual(0, ern_cli:ern(["build", "--load-path", Build, Dir ++ "/src"])),
    ?assert(filelib:is_dir(Dir ++ "/src/empty")),
    ?assert(filelib:is_dir(Dir ++ "/src/.git/refs/tags")).

%% report §11.1: the sweep does not follow a symbolic link. A regression
%% test: it deleted through a link to a directory, then exited with status
%% 70 removing the link as a directory
sweep_follows_no_link_test() ->
    Dir = pair(tmp()),
    Args = ["--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ok = file:rename(Dir ++ "/build/net", Dir ++ "/elsewhere"),
    ok = file:make_symlink(Dir ++ "/elsewhere", Dir ++ "/build/net"),
    write(Dir, "src/main.ern", hello()),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assert(filelib:is_regular(Dir ++ "/elsewhere/http.erc")).

%% report §11.1: directory mode passes over a symbolic link to a directory.
%% A regression test: a link to the tree's parent was followed until the
%% host's atom limit, status 70, and each lap overwrote the module's .erc
%% with one of another namespace
sources_follow_no_link_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export fn f() : Int = 1\n"),
    ok = file:make_symlink("..", Dir ++ "/src/loop"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    {ok, Beam} = file:read_file(Dir ++ "/src/util.erc"),
    {ok, #{iface := #iface{namespace = Ns}}} = ern_iface:read(Beam),
    ?assertEqual(['Util'], Ns).

%% report §11.1: a stale .erc is no module, and a module that uses it is an
%% error. A regression test: the build compiled against it, then swept it,
%% and the program it had built could not load
stale_erc_is_no_module_test() ->
    Dir = pair(tmp()),
    Build = Dir ++ "/build",
    Args = ["--build-root", Build, "--load-path", Build, Dir ++ "/src"],
    ?assertEqual(0, build_err(Args)),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(1, build_err(Args)),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      list_to_binary("no module Net.Http: " ++ Build
                                                     ++ "/net/http.erc was compiled from "
                                                     ++ Dir ++ "/src/net/http.ern,"
                                                     " which no longer exists"))),
    ?assert(filelib:is_regular(Build ++ "/net/http.erc")).

%% report §11.1: a module is recompiled when the path from the build root to
%% its source changed, so that a moved source tree's modules record where
%% their sources now are
recompile_on_moved_source_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {ok, Before} = file:read_file(Dir ++ "/build/main.erc"),
    ok = file:rename(Dir ++ "/src", Dir ++ "/moved"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/moved"])),
    {ok, After} = file:read_file(Dir ++ "/build/main.erc"),
    ?assertNotEqual(Before, After),
    {ok, #{source_path := Path}} = ern_iface:read(After),
    ?assertEqual(<<"../moved/main.ern">>, Path).

%% report §11.1: --emit-erl writes the Erlang source and no .erc
emit_erl_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--build-root", Dir ++ "/build",
                                 Dir ++ "/src"])),
    {ok, Src} = file:read_file(Dir ++ "/build/net/http.erl"),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ern@net@http).">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--emit", "asm", Dir ++ "/src"])).

%% report §11.1: --emit-erl writes a module whose strings hold characters
%% beyond Latin-1, as Erlang's source is, in UTF-8. A regression test: the
%% source was written as a list of characters, which fails beyond 255.
emit_erl_unicode_test() ->
    Dir = tmp(),
    File = write(Dir, "dots.ern", "export fn dot() : String = \"\\u{2022}\"\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--source-root", Dir, File])),
    {ok, Src} = file:read_file(filename:join(Dir, "dots.erl")),
    ?assertMatch({_, _}, binary:match(Src, <<"\x{2022}"/utf8>>)).

%% report §11.1, §11.5: an error is file:line:column: text, status 1
compile_error_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:49: the argument does not fit Io.println:"
                   " expected String, found Int\n"
                   "1 | export fn main() : Unit with Never = Io.println(1)\n"
                   "  |                                      ---------- Io.println : (String) ->"
                   " Unit with e\n"
                   "  |                                                 ^\n\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertNot(filelib:is_regular(filename:join(Dir, "bad.erc"))).

%% report §11.5: --short-errors is the first line alone
errors_short_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--short-errors", "--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:49: the argument does not fit Io.println:"
                   " expected String, found Int\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.5: an error prints its source line whole, whatever the line
%% holds (a regression test: a character outside Latin-1 crashed the compiler)
error_on_unicode_line_test() ->
    Dir = tmp(),
    File = write(Dir, "twice.ern", <<"fn twice(n) = n + n  // Int — or Float\n"/utf8>>),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    Out = unicode:characters_to_binary(?capturedOutput),
    Line = <<"1 | fn twice(n) = n + n  // Int — or Float\n"/utf8>>,
    ?assertMatch({_, _}, binary:match(Out, Line)).

%% report §11.5: an error names its file by the path from the working
%% directory when the file lies under it
error_names_file_from_cwd_test() ->
    Dir = tmp(),
    write(Dir, "bad.ern", "export fn main() : Unit with Never = Io.println(1)\n"),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(1, build_err(["--short-errors", "bad.ern"])),
        ?assertMatch(<<"bad.ern:1:49: ", _/binary>>, iolist_to_binary(?capturedOutput))
    after
        file:set_cwd(Cwd)
    end.

%% report §8.6, §7.4: a fault in main is reported on stderr with its
%% cause, status 1
fault_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() : Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "boom.erc")])),
    ?assertEqual(<<"Boom.main faulted: division by zero\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2, §6.9: `ern run` reports every fault of every process on
%% standard error as it happens, a worker's and a restart's among them,
%% and the program goes on; the entry process's return is status 0. A
%% regression test for B4; it does not cover a system process's fault,
%% which no program can bring about
worker_faults_test() ->
    Dir = tmp(),
    File = write(Dir, "workers.ern",
                 "type Msg = Died(Down)\n"
                 "export fn main() : Unit with Msg = {\n"
                 "    let limit = RestartLimit(restarts = 1, within = 60000);\n"
                 "    let _ = spawnMonitored(Local, restarting(limit, fn() : Unit with Never =\n"
                 "        Io.println(Int.toString(1 / List.size([])))), Died);\n"
                 "    receive { Died(_) -> Io.println(\"done\") }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_err(["run", filename:join(Dir, "workers.erc")])),
    %% standard error's lines and standard output's are two processes'
    %% writes, which nothing orders between them
    ?assertEqual(lists:sort([<<"Workers.main:4 faulted, restarted: division by zero">>,
                             <<"Workers.main:4 faulted: division by zero">>, <<"done">>]),
                 lists:sort(binary:split(iolist_to_binary(?capturedOutput), <<"\n">>,
                                         [global, trim]))).

%% report §11.2, §7.3, §7.4: beneath a foreign function's raise the fault
%% line has the host's stack, a function to a line, naming the function
%% that raised; beneath a §7.4 cause, as above, it has nothing. A
%% regression test: the stack was dropped, and a failure of the runtime
%% named no module and no line.
fault_stack_test() ->
    Dir = tmp(),
    File = write(Dir, "raise.ern",
                 "foreign fn pick(i : Int, t : Int) : Int = \"erlang:element/2\"\n"
                 "export fn main() : Unit with Never = Io.println(Int.toString(pick(5, 3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "raise.erc")])),
    [First, Second | _] = binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global]),
    ?assertEqual(<<"Raise.main faulted: foreign function erlang:element/2 raised error:badarg">>,
                 First),
    ?assertEqual(<<"    erlang:element/2">>, Second).

%% report §11.4, §11.5: every exported and every documented declaration,
%% with its type and its doc comment, as Markdown
doc_test() ->
    Dir = tmp(),
    File = write(Dir, "shapes.ern",
                 "/// A shape.\n"
                 "export type Shape = Dot | At(x : Int, y : Int)\n"
                 "export abstract type Box(a) = Box(List(a))\n"
                 "export let Box.empty : Box(a) = Box([])\n"
                 "/// Put x in the box.\n"
                 "export fn Box.put(x : a, Box(xs) : Box(a)) : Box(a) = Box(x :: xs)\n"
                 "export fn same(a, b) = a == b\n"
                 "/// Documented but private.\n"
                 "fn twice(n : Int) : Int = 2 * n\n"
                 "fn hidden(n : Int) : Int = n\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", Dir, File])),
    Out = iolist_to_binary(?capturedOutput),
    Expect = fun(Text) -> ?assertMatch({_, _}, binary:match(Out, Text)) end,
    Expect(<<"# Ernest module Shapes\n\n## Shapes.Shape\n\n```ernest\n"
             "type Shape = Dot | At(x : Int, y : Int)\n```\n\nA shape.\n">>),
    Expect(<<"## Shapes.Box\n\n```ernest\nabstract type Box(a)\n```\n">>),
    Expect(<<"## Shapes.Box.empty\n\n```ernest\nShapes.Box.empty : Box(a)\n```\n">>),
    %% report §3.9: put keeps its element in a List, where a reply may not stand
    Expect(<<"## Shapes.Box.put\n\n```ernest\nShapes.Box.put : (a!, Box(a!)) -> Box(a!)\n```\n\n"
             "Put x in the box.\n">>),
    Expect(<<"## Shapes.same\n\n```ernest\nShapes.same : (a=, a=) -> Bool\n```\n">>),
    Expect(<<"## Shapes.twice\n\n```ernest\nShapes.twice : (Int) -> Int\n```\n\n"
             "Documented but private.\n">>),
    ?assertEqual(nomatch, binary:match(Out, <<"hidden">>)),
    %% a type error is reported as for a compilation
    ?assertEqual(1, ern_cli:ern(["doc", "--source-root", Dir,
                                  write(Dir, "bad.ern", "export fn f() : Int = \"s\"\n")])).

%% report §11.1, §11.4: the documentation comes from the compiled module,
%% so `ern doc` on a .erc writes what it writes on its source, and asking a
%% source for its page writes nothing
doc_from_compiled_test() ->
    Dir = tmp(),
    Src = write(Dir, "shapes.ern",
                "/// A shape.\n"
                "export type Shape = Dot | At(x : Int, y : Int)\n"
                "/// Twice n.\n"
                "export fn twice(n : Int) : Int = 2 * n\n"),
    Out = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", Dir, "--build-root", Out, Src])),
    FromSource = iolist_to_binary(?capturedOutput),
    ?assertEqual(false, filelib:is_regular(filename:join(Out, "shapes.erc"))),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--build-root", Out, Src])),
    ?assertEqual(0, ern_cli:ern(["doc", filename:join(Out, "shapes.erc")])),
    %% the captured output is everything this test printed, so the page twice
    ?assertEqual(<<FromSource/binary, FromSource/binary>>, iolist_to_binary(?capturedOutput)),
    ?assertMatch({_, _}, binary:match(FromSource, <<"## Shapes.twice">>)).

%% report §11.4: `ern doc --man` writes the page as a manual page: the
%% page's last line a comment at the head of the source, the header, the
%% NAME line of the module's first sentence without its `since` line, the
%% page after its title under DESCRIPTION, and a declaration a subsection.
%% Written after the code, a regression test; how roff lays out each block
%% is libs/markdown's to test, and that man renders the pages is
%% ern_integration_tests's.
doc_man_test() ->
    Dir = tmp(),
    File = write(Dir, "shapes.ern",
                 "/// Shapes to draw. Each is a value.\n"
                 "///\n"
                 "/// since 0.1.0\n"
                 "\n"
                 "/// A shape.\n"
                 "export type Shape = Dot | At(x : Int, y : Int)\n"
                 "\n"
                 "/// Twice n.\n"
                 "export fn twice(n : Int) : Int = 2 * n\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--source-root", Dir, File])),
    Lines = binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global, trim]),
    ?assertMatch([<<".\\\" Generated by ern ", _/binary>>,
                  <<".TH \"Ernest.Shapes\" \"3ern\" \"\" \"Ernest ", _/binary>>,
                  <<".nh">>, <<".ds AD l">>, <<".ad l">>,
                  <<".SH NAME">>,
                  <<"Ernest.Shapes \\- Shapes to draw.">>,
                  <<".SH DESCRIPTION">>,
                  <<".PP">>,
                  <<"\\fISince 0.1.0.\\fR">>,
                  <<".PP">>,
                  <<"Shapes to draw. Each is a value.">>
                  | _], Lines),
    Pairs = lists:zip(lists:droplast(Lines), tl(Lines)),
    ?assert(lists:member({<<".SS">>, <<"Shapes.Shape">>}, Pairs)),
    ?assert(lists:member({<<".SS">>, <<"Shapes.twice">>}, Pairs)),
    %% a module whose doc block has no paragraph has its page's title there
    Bare = write(Dir, "bare.ern", "export fn one() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--source-root", Dir, Bare])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<".SH NAME\nErnest.Bare \\- Ernest module Bare\n">>)).

%% report §11.4: `ern doc --man src-dir` writes each page beside its
%% module's .erc, in a file named as `man` finds it, and no index
doc_man_dir_test() ->
    Dir = pair(tmp()),
    Out = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", Out, filename:join(Dir, "src")])),
    ?assert(filelib:is_regular(filename:join(Out, "net/Ernest.Net.Http.3ern"))),
    ?assert(filelib:is_regular(filename:join(Out, "Ernest.Main.3ern"))),
    ?assertEqual([], filelib:wildcard(filename:join(Out, "*.md"))),
    {ok, Page} = file:read_file(filename:join(Out, "net/Ernest.Net.Http.3ern")),
    ?assertMatch({_, _}, binary:match(Page, <<".TH \"Ernest.Net.Http\" \"3ern\"">>)).

%% report §11.1: the compiled module carries its documentation as EEP 48's
%% Docs chunk, so the host's own tools read an Ernest module
docs_chunk_test() ->
    Dir = tmp(),
    Src = write(Dir, "shapes.ern",
                "/// A shape.\n"
                "/// since 0.2.0\n"
                "export type Shape = Dot | At(x : Int, y : Int)\n"
                "/// Twice n.\n"
                "export fn twice(n : Int) : Int = 2 * n\n"),
    Out = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--build-root", Out, Src])),
    {ok, Beam} = file:read_file(filename:join(Out, "shapes.erc")),
    {ok, Docs} = ern_docs:read(Beam),
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

%% report §9, §11.4: `ern doc` of the standard library's own source root
%% writes the prelude's page, first in the index, beside the modules' pages
prelude_page_test_() ->
    {timeout, 120, fun prelude_page/0}.

prelude_page() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", Dir, "../../../stdlib"])),
    {ok, Index} = file:read_file(filename:join(Dir, "index.md")),
    ?assertMatch(<<"# Modules\n\n- [Prelude](prelude.md)\n", _/binary>>, Index),
    {ok, Page} = file:read_file(filename:join(Dir, "prelude.md")),
    ?assertMatch(<<"# Ernest prelude\n\n*Since 0.1.0.*", _/binary>>, Page),
    [?assertMatch({_, _}, binary:match(Page, <<"\n## ", N/binary, "\n">>))
     || N <- [<<"send">>, <<"Address.call">>, <<"Optional">>, <<"restarting">>, <<"Int">>]],
    ?assertMatch({_, _}, binary:match(Page, <<"from the prelude, report §9."/utf8>>)).

%% report §11.4, Appendix E.0 rule 6: docs/module_doc_template.md is what
%% `ern doc` renders for examples/template.ern, after its marker line
doc_template_test() ->
    Src = example("template.ern"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", filename:dirname(Src), Src])),
    Out = iolist_to_binary(?capturedOutput),
    {ok, File} = file:read_file("../../../docs/module_doc_template.md"),
    Marker = <<"<!-- generated: ern doc examples/template.ern -->\n">>,
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
                 re:run(Out, "\n---\n\nGenerated by ern [0-9.]+ from template.ern.\n$")).

without_footer(Doc) ->
    hd(binary:split(Doc, <<"\n---\n\nGenerated by ern ">>)).

%% docs/development.md, "What the toolchain accepts": every error text in
%% erl/*/src or in the shell's own Ernest source that names an MVP appears in
%% that document's table, by its first forty characters, so the table cannot drift from what
%% the code refuses
mvp_refusals_listed_test() ->
    {ok, Listed} = file:read_file("../../../docs/development.md"),
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
    Sources = filelib:wildcard("../../*/src/*.erl") ++ filelib:wildcard("../../../shell/*.ern")
        ++ filelib:wildcard("../../../shell/shell/*.ern"),
    %% a name the wildcard matches may not be a readable file: an editor's
    %% lock is a dangling symlink beside the file it locks, and a person
    %% with a source open should not see a red suite
    Texts = lists:usort(lists:append([Find(Text) || F <- Sources,
                                                    {ok, Text} <- [file:read_file(F)]])),
    Missing = [T || T <- Texts, binary:match(Listed, binary:part(T, 0, min(40, byte_size(T))))
                                =:= nomatch],
    ?assertEqual([], Missing).

%% report §11: --version prints the top-level VERSION file's content
version_test() ->
    {ok, V} = file:read_file("../../../VERSION"),
    ?assertEqual(0, ern_cli:ern(["--version"])),
    ?assertEqual(<<"ern ", (string:trim(V))/binary, "\n">>, iolist_to_binary(?capturedOutput)).

%% report §11: options are long; --help and --version stop with status 0,
%% and a job's --help lists its options
options_test() ->
    ?assertEqual(1, ern_cli:ern(["build", "-o", "x", example("hello.ern")])),
    ?assertEqual(1, build_err([])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "^ern build: one file or directory argument is required\n"
                                    "Usage: ern build ")),
    ?assertEqual(0, ern_cli:ern(["--version"])),
    ?assertEqual(0, ern_cli:ern(["--help"])),
    [?assertEqual(0, ern_cli:ern([Job, "--help"]))
     || Job <- ["build", "doc", "run", "test", "shell", "config"]].

%% report §11: the first word is the job, and none is refused with the jobs
%% named
job_first_test() ->
    ?assertEqual(1, ern_err([])),
    ?assertEqual(1, ern_err(["compile", "x.ern"])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Out, <<"ern: a job is required\nUsage: ern <job>">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"ern: no job compile; the jobs are build, doc,"
                                             " format, run, test, shell and config">>)).

%% report §11: a spelling of the toolchain before its jobs is refused, and
%% the refusal names the spelling that replaces it
old_spellings_test() ->
    File = example("hello.ern"),
    Refused = [{["x.erc"], <<"the job comes first: ern run x.erc">>},
               {["--shell"], <<"--shell is now the job: ern shell">>},
               {["--test", "x.erc"], <<"--test is now the job: ern test">>},
               {["--doc", File], <<"--doc is now the job: ern doc">>},
               {["--create-config-dir", "d"], <<"--create-config-dir is now the job ern config">>},
               {["--load-path", "d", "x.erc"], <<"--load-path comes after the job">>},
               {["build", "--out-dir", "b", File], <<"--out-dir is now --build-root">>},
               {["build", "--no-clean", File], <<"--no-clean is gone">>},
               {["build", "--errors", "short", File], <<"--errors short is now --short-errors">>},
               {["build", "--emit", "erl", File], <<"--emit erl is now --emit-erl">>},
               {["run", "--shell"], <<"--shell is now the job: ern shell">>},
               {["run", "--test", "x.erc"], <<"--test is now the job: ern test">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Out = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Out, Text)) || {_, Text} <- Refused].

%%
%% ern, report §11.2 and §11.3
%%

%% report §11.2: --load-path adds roots searched by namespace
load_path_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ok = filelib:ensure_dir(Dir ++ "/lib/net/http.erc"),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/lib/net/http.erc"),
    ?assertEqual(1, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(0, ern_cli:ern(["run", "--load-path", Dir ++ "/lib", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: --main picks another exported entry point; one that takes
%% arguments is refused (§8.1)
main_option_test() ->
    Dir = pair(tmp()),
    write(Dir, "src/tools.ern",
          "export fn check() : Unit with Never = Io.println(\"checked\")\n"
          "export fn twice(n : Int) : Int = 2 * n\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--main", "Tools.check", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"checked\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(1, ern_cli:ern(["run", "--main", "Tools.twice", Dir ++ "/build/main.erc"])),
    ?assertEqual(1, ern_cli:ern(["run", "--main", "check", Dir ++ "/build/main.erc"])).

%% report §8.1, §11.2: an entry point is an exported fn of type
%% `() -> Unit`, with a mailbox type or pure; a function of another shape
%% and a top-level `let` are refused by name and type, as `main` and as
%% `--main`, and a function that is not exported is not found
entry_point_shape_test() ->
    Run = fun(Source, Args) ->
                  Dir = tmp(),
                  File = write(Dir, "main.ern", Source),
                  ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
                  ern_err(["run" | Args] ++ [filename:join(Dir, "main.erc")])
          end,
    ?assertEqual(1, Run("export fn main() : Int = 3\n", [])),
    ?assertEqual(1, Run("export let main = fn() : Unit with Never = Io.println(\"x\")\n",
                        [])),
    ?assertEqual(1, Run("export fn main() : Unit = Unit\n"
                        "export fn other() : Int = 3\n", ["--main", "Main.other"])),
    ?assertEqual(1, Run("fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Run("export fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Run("export fn main() : Unit with m = Io.println(\"m\")\n", [])),
    ?assertEqual(0, Run("export fn main() : Unit = Unit\n"
                        "export fn other() : Unit with Never = Io.println(\"o\")\n",
                        ["--main", "Main.other"])),
    Out = iolist_to_binary(?capturedOutput),
    Refusals = [<<"Main.main is not an entry point: its type is () -> Int">>,
                <<"Main.main is not an entry point: it is a let of type"
                  " () -> Unit with Never">>,
                <<"Main.other is not an entry point: its type is () -> Int">>,
                <<"no exported function Main.main">>,
                <<"m\no\n">>],
    [?assertMatch({_, _}, binary:match(Out, R)) || R <- Refusals],
    %% the refused entry points were not run
    ?assertEqual(nomatch, binary:match(Out, <<"x\n">>)).

%% report §8.5, §8.2, §11.2: top-level lets of every loaded module are
%% evaluated before main, dependencies first, with the system modules'
%% references bound, so an initializer prints
init_order_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/values.ern",
          "export let base = 40\nlet said = Io.println(\"values\")\n"),
    write(Dir, "src/main.ern",
          "let total = Lib.Values.base + 2\n"
          "export fn main() : Unit with Never = Io.println(Int.toString(total))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"values\n42\n">>, iolist_to_binary(?capturedOutput)).

%% report §8.5, §11.2: a module on the source root that the program does
%% not depend on is not loaded, so its faulting top-level `let` does not
%% stop main; a module it depends on is initialized whole, so a faulting
%% `let` main does not use still faults the program. A regression test,
%% written after the code; a module reached only through `--main` is not
%% covered.
init_only_dependencies_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/boom.ern",
          "export let zero = List.size([])\n"
          "export let boom = 1 / zero\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = Io.println(Int.toString(Lib.Boom.zero))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"hello, world\nMain.main faulted: division by zero\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §7.3, §8.6, §11.2: a faulting main is status 1
fault_status_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() : Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_cli:ern(["run", filename:join(Dir, "boom.erc")])).

%% report §8.6, §11.2: the program ends when its entry process is killed,
%% printing `killed`, with status 1. A regression test: it printed
%% `fault: 'Killed'`, since only a return and a fault had their own lines.
killed_entry_test() ->
    Dir = tmp(),
    File = write(Dir, "main.ern",
                 "export fn main() : Unit with Never = {\n"
                 "    let me = self();\n"
                 "    let _ = spawn(Local, fn() : Unit with Never = kill(me));\n"
                 "    receive { after 5000 -> Io.println(\"not killed\") }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "main.erc")])),
    ?assertEqual(<<"killed\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: the file must lie at the path of its namespace
misplaced_module_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/build/http.erc"),
    ?assertEqual(1, ern_cli:ern(["run", Dir ++ "/build/http.erc"])),
    ?assertEqual(1, ern_cli:ern(["run", Dir ++ "/build/nothing.erc"])).

%% report §11.3: without --config-dir, `ern config` creates ./.ernest
config_default_dir_test() ->
    Dir = tmp(),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(0, ern_cli:ern(["config"]))
    after
        ok = file:set_cwd(Cwd)
    end,
    ?assert(filelib:is_regular(Dir ++ "/.ernest/ernest.conf")).

%% report §11.3, Appendix C: the configuration directory with an empty
%% peer list and a private key readable only by its owner, created where
%% --config-dir names it; a second creation fails
create_config_dir_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    {ok, Conf} = file:read_file(Dir ++ "/ernest.conf"),
    #{<<"peers">> := [], <<"public-key">> := <<"-----BEGIN PUBLIC KEY-----", _/binary>>,
      <<"network-address">> := _} = json:decode(Conf),
    {ok, Info} = file:read_file_info(Dir ++ "/private-key.pem"),
    ?assertEqual(8#600, element(8, Info) band 8#777),
    {ok, Pem} = file:read_file(Dir ++ "/private-key.pem"),
    ?assertMatch([{'PrivateKeyInfo', _, not_encrypted}], public_key:pem_decode(Pem)),
    ?assertEqual(1, ern_cli:ern(["config", "--config-dir", Dir])).

%% report §11.3: the configuration directory is its owner's alone, and one
%% that exists is refused, whoever made it and however empty. A regression
%% test: the directory took the host's default mode, so another could open
%% the key's temporary file before it was its owner's, and one made after
%% the check for it was used; the race itself is not covered
config_dir_is_its_owners_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    {ok, Info} = file:read_file_info(Dir),
    ?assertEqual(8#700, element(8, Info) band 8#777),
    Made = tmp() ++ "/made",
    ok = file:make_dir(Made),
    ?assertEqual(1, ern_err(["config", "--config-dir", Made])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"made exists">>)),
    ?assertEqual({ok, []}, file:list_dir(Made)).

captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> Output end.
