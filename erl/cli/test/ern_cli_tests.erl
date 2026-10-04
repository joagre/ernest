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
-include_lib("kernel/include/file.hrl").

%%
%% Helpers: a fresh directory per test, sources written into it
%%

%% Unique within this VM; a leftover from an earlier run is removed first.
tmp() ->
    Dir = filename:join(["/tmp", "ern_cli_" ++ integer_to_list(erlang:unique_integer([positive]))]),
    file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

%% report §11.1: the standard library's own build takes its namespaces from
%% its .erc files and not from an installed copy, so a copy that cannot be
%% read, as one a build of ern in another chunk format wrote, does not stop
%% the build that replaces it, and the copy's directory returns to the code
%% path after. A regression test: such a copy stopped `make` until
%% build/stdlib was removed by hand. Not covered: a copy read while another
%% root builds, which is the library's and must be readable. A build of the
%% whole library, about a second and a half alone, runs beside every other
%% suite under `make test`, past eunit's five seconds once
stdlib_build_sets_its_copy_aside_test_() ->
    {timeout, 60, fun stdlib_build_sets_its_copy_aside/0}.

stdlib_build_sets_its_copy_aside() ->
    Installed = filename:join(tmp(), "stdlib"),
    ok = filelib:ensure_path(Installed),
    ok = file:write_file(filename:join(Installed, "ern@unreadable.beam"), <<"not a module">>),
    true = code:add_pathz(Installed),
    try
        ?assertEqual(0, ern_build:compile([{build_root, Installed}], "../../../stdlib",
                                          standard_error)),
        ?assert(lists:member(Installed, code:get_path()))
    after
        code:del_path(Installed)
    end.

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

%% report §11.6: a directory named is no source root, so a module under it
%% whose name would take a prelude namespace from there is laid out as any
%% other, and a path component that breaks the shape is still refused. A
%% regression test: `util/list.ern` named as `util` was refused as taking
%% the prelude namespace List
format_directory_is_no_root_test() ->
    Dir = tmp(),
    List = write(Dir, "util/list.ern", "fn f(x) = x+1\n"),
    ?assertEqual(0, ern_err(["format", Dir ++ "/util"])),
    ?assertEqual({ok, <<"fn f(x) =\n    x + 1\n">>}, file:read_file(List)),
    write(Dir, "util/Bad/x.ern", "fn f(x) = x\n"),
    ?assertEqual(1, ern_err(["format", Dir ++ "/util"])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"path component `Bad` must be lowercase">>)).

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
    {ok, #file_info{mode = Mode}} = file:read_file_info(Target),
    ?assertEqual(8#640, Mode band 8#777),
    {ok, Names} = file:list_dir(Dir),
    ?assertEqual(["link.ern", "target.ern"], lists:sort(Names)).

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
    lists:foreach(fun(Count) ->
                      %% a changed source, so that every build writes
                      write(Dir, "twice.ern", "export fn f() : Int = " ++ integer_to_list(Count)
                                              ++ "\n"),
                      [spawn(Build) || _ <- lists:seq(1, 8)],
                      ?assertEqual(lists:duplicate(8, 0),
                                   [receive {built, Status} -> Status end || _ <- lists:seq(1, 8)])
                  end, lists:seq(1, 5)),
    {ok, Names} = file:list_dir(Dir),
    ?assertEqual(["twice.erc", "twice.ern"], lists:sort(Names)).

%% report §11: `ern test` runs a module of more tests than the host holds
%% values live at once. A regression test: the list of a module's tests was
%% one expression, which the host refused past about a thousand, and
%% `ern build` failed with status 70
many_tests_test_() ->
    {timeout, 60, fun many_tests/0}.

many_tests() ->
    Dir = tmp(),
    File = write(Dir, "many.ern",
                 [["let t", integer_to_list(Index), " : Test.Case(Never) =\n",
                   "    Test.Case(name = \"t", integer_to_list(Index),
                   "\", run = fn() = Test.Passed)\n"] || Index <- lists:seq(1, 1100)]),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "many.erc")])).

%% report §11: a `.erc` that is no compiled module is refused by `ern doc`,
%% `ern run` and `ern test` alike, by its name, and so is a module the host
%% compiled from Erlang. A regression test: `ern doc` failed with status
%% 70, and a run's refusal quoted the file's bytes; the release review found
%% the second quoting the host module's bytes
not_a_compiled_module_test() ->
    Dir = tmp(),
    Junk = write(Dir, "junk.erc", "garbage\n"),
    {ok, Host} = file:read_file(code:which(lists)),
    Beam = write(Dir, "lists.erc", Host),
    lists:foreach(fun({Job, Erc}) ->
                      ?assertEqual(1, ern_err([Job, Erc])),
                      Said = unicode:characters_to_binary(?capturedOutput),
                      Line = iolist_to_binary(["ern ", Job, ": ", Erc,
                                               " is not a compiled module\n"]),
                      ?assertMatch({Job, Erc, {_, _}}, {Job, Erc, binary:match(Said, Line)})
                  end, [{Job, Erc} || Job <- ["doc", "run", "test"], Erc <- [Junk, Beam]]).

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
    %% the refusal names the file; a regression test, it named only the
    %% component (findings.md's T30)
    Refused([Upper], <<"Bad.ern: path component `Bad` must be lowercase">>),
    Refused([Dir ++ "/src"], <<"Sub/ok.ern: path component `Sub` must be lowercase">>),
    [?assertEqual({ok, list_to_binary(Text)}, file:read_file(File))
     || File <- [Notes, Upper, Under]],
    %% a file outside the source root is refused with the option that names
    %% another; a regression test for T30 too
    ?assertEqual(1, ern_err(["build", "--source-root", Dir ++ "/src", Upper])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"; --source-root names another">>)).

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

%% report §11.8: a file a job cannot read, and a directory it cannot make,
%% are refused with the host's reason and status 1: a source `ern build`
%% and `ern format` read, a module's directory under the build root, and
%% the directory the configuration's is made in. A regression test: each
%% ended as a failure of ern itself, status 70
cannot_read_or_make_test() ->
    Dir = tmp(),
    Said = fun(Text) ->
               ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(
                                                   ?capturedOutput), Text))
           end,
    Source = write(Dir, "closed.ern", "export let x : Int = 1\n"),
    ok = file:change_mode(Source, 8#000),
    ?assertEqual(1, build_err(["--source-root", Dir, Source])),
    Said(<<"closed.ern: permission denied">>),
    ?assertEqual(1, ern_err(["format", Source])),
    ok = file:change_mode(Source, 8#644),
    write(Dir, "src/deep/m.ern", "export let x : Int = 1\n"),
    BuildRoot = filename:join(Dir, "out"),
    ok = file:make_dir(BuildRoot),
    ok = file:change_mode(BuildRoot, 8#555),
    ?assertEqual(1, build_err(["--build-root", BuildRoot, Dir ++ "/src"])),
    Said(<<"out/deep: permission denied">>),
    ?assertEqual(1, ern_err(["config", "--config-dir", BuildRoot ++ "/sub/.ernest"])),
    Said(<<"out/sub: permission denied">>),
    ok = file:change_mode(BuildRoot, 8#755).

%% report §11.3: `--config-dir dir/` names the directory dir. A regression
%% test: the directory was made, then refused as one that exists
config_dir_slash_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_err(["config", "--config-dir", Dir ++ "/"])),
    ?assert(filelib:is_regular(Dir ++ "/ernest.conf")).

%% report §11.1: a name that is not UTF-8 is named, bytes and all, where a
%% directory's name holding it is not UTF-8 either. A regression test: the
%% name's text was made from the directory's as though that were UTF-8,
%% and the build ended as a failure of ern itself
nested_name_not_utf8_test() ->
    Dir = tmp(),
    Inner = filename:join(Dir, <<"b", 16#FF>>),
    ok = file:make_dir(Inner),
    ok = file:write_file(filename:join(Inner, <<"d", 16#FE, ".ern">>), <<>>),
    ?assertEqual(1, build_err([Dir])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"/b\\xFF/d\\xFE.ern">>)).

%% report §11.1: a path component outside Latin-1 is refused by the shape
%% rule, as any other that is not words. A regression test: the rule's
%% test could not read such a component, and the build ended as a failure
%% of ern itself
component_outside_latin1_test() ->
    Dir = tmp(),
    File = write(Dir, "\x{3b1}\x{3b2}.ern", "export let x : Int = 1\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"must be words joined by `_`">>)),
    Upper = write(Dir, "sub/\x{3b1}B.ern", "export let x : Int = 1\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, Upper])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"must be lowercase">>)).

%% report §11.8, §11.5: a source that is not UTF-8 is refused where its
%% first such byte stands, its line shown, status 1. A regression test: the
%% line could not be shown, and the build ended as a failure of ern itself
source_not_utf8_test() ->
    Dir = tmp(),
    Source = write(Dir, "bad.ern", <<"fn main() : Unit = ", 16#FF, "\n">>),
    ?assertEqual(1, build_err(["--source-root", Dir, Source])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"bad.ern:1:20: input is not valid UTF-8">>)).

%% A tool run with the captured output as its error device, so a test
%% reads what the user sees on stderr.
build_err(Args) -> ern_cli:ern(["build" | Args], group_leader()).
ern_err(Args) -> ern_cli:ern(Args, group_leader()).

write(Dir, Relative, Text) ->
    Path = filename:join(Dir, Relative),
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

%% report §11.1: path components below the root are words joined by single
%% `_`, each a lowercase letter then lowercase letters and digits
path_shape_test() ->
    Dir = tmp(),
    File = write(Dir, "Net/http.ern", hello()),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertNot(filelib:is_regular(filename:join(Dir, "Net/http.erc"))),
    DigitDir = tmp(),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", DigitDir,
                                 write(DigitDir, "9x.ern", hello())])),
    WordsDir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", WordsDir,
                                 write(WordsDir, "http_server.ern", hello())])),
    ?assert(filelib:is_regular(filename:join(WordsDir, "http_server.erc"))),
    %% a word begins with a letter, and a `_` stands between two words
    lists:foreach(fun(Name) ->
                      WrongDir = tmp(),
                      ?assertEqual(1, ern_err(["build", "--source-root", WrongDir,
                                               write(WrongDir, Name ++ ".ern", hello())])),
                      ?assertMatch({_, _},
                                   binary:match(unicode:characters_to_binary(?capturedOutput),
                                                <<"must be words joined by `_`">>)),
                      ?assertNot(filelib:is_regular(filename:join(WrongDir, Name ++ ".erc")))
                  end, ["http_2", "_http", "http_", "ordered__set"]).

%% report §4.2, §11.2: `word_count.ern` provides `WordCount`, which another
%% module names, `ern run` finds by its namespace, and `ern doc` writes at
%% its path; the compiled module is `ern@word_count`, the path with `@`.
%% `ordered_set.ern` was the example until the standard library took
%% `OrderedSet` (Appendix E.25)
words_name_a_segment_test() ->
    Dir = tmp(),
    write(Dir, "src/word_count.ern", "export fn size() : Int = 2\n"),
    write(Dir, "src/net/http_client.ern", "export fn port() : Int = 80\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never =\n"
          "    Io.println(Int.toString(WordCount.size() + Net.HttpClient.port()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(filename:join(Dir, "build/word_count.erc"))),
    ?assert(filelib:is_regular(filename:join(Dir, "build/net/http_client.erc"))),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"82\n">>)),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", Dir ++ "/pages", Dir ++ "/src"])),
    ?assert(filelib:is_regular(filename:join(Dir, "pages/word_count.md"))),
    ?assert(filelib:is_regular(filename:join(Dir, "pages/net/http_client.md"))),
    ?assertEqual("word_count", ern_build:module_path(['WordCount'])),
    ?assertEqual('ern@net@http_client', ern_emitter:erlang_module(['Net', 'HttpClient'])).

%% report §11.1, §3.10: a module depends on each module that declares a type
%% the interface of a module it depends on names, so a type reached through
%% another module's function is declared where it is used: `==` on a value
%% holding a function is refused, a field of it selects, the `.erc` records
%% the declaring module, and a change to that module's interface compiles
%% the dependent again. A regression test: the checker was given the
%% interfaces of the modules a source named alone, read a type it had no
%% declaration for as a built-in one, and let `==` through (the log's *A
%% Type Reached Through Another Module's Interface*)
reached_interface_test() ->
    Dir = tmp(),
    write(Dir, "src/boxes.ern", "export type Box = Box(f : (Int) -> Int)\n"),
    write(Dir, "src/maker.ern", "export fn make() : Boxes.Box = Boxes.Box(f = fn(n) = n + 1)\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never =\n"
          "    Io.println(Bool.toString(Maker.make() == Maker.make()))\n"),
    BuildCommand = ["build", "--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(1, ern_err(BuildCommand)),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"`==` is not defined on Boxes.Box">>)),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never =\n"
          "    Io.println(Int.toString(Maker.make().f(1)))\n"),
    ?assertEqual(0, ern_cli:ern(BuildCommand)),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"2\n">>)),
    {ok, Beam} = file:read_file(filename:join(Dir, "build/main.erc")),
    {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
    ?assertEqual([['Boxes'], ['Maker']],
                 lists:sort([Dependency || {Dependency, _} <- DependencyHashes])),
    write(Dir, "src/boxes.ern", "export type Box = Box(f : Int)\n"),
    write(Dir, "src/maker.ern", "export fn make() : Boxes.Box = Boxes.Box(f = 1)\n"),
    ?assertEqual(1, ern_err(BuildCommand)),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"main.ern:2:">>)).

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
    ?assertEqual({ok, "Http"}, ern_build:segment("http")),
    ?assertEqual({ok, "V2"}, ern_build:segment("v2")),
    ?assertEqual({ok, "HttpServer"}, ern_build:segment("http_server")),
    ?assertEqual(error, ern_build:segment("Net")),
    ?assertEqual(error, ern_build:segment("9x")),
    ?assertEqual(error, ern_build:segment("http_2")),
    ?assertEqual({'Some', <<"Http">>}, ern_shell:segment(<<"http">>)),
    ?assertEqual({'Some', <<"OrderedSet">>}, ern_shell:segment(<<"ordered_set">>)),
    ?assertEqual('None', ern_shell:segment(<<"Bad">>)).

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

%% report §11.1: in single-file mode without --source-root a file's
%% namespace is its path from the current directory; a directory of it
%% that breaks the path shape is refused with the source root that leaves
%% it out of the namespace, the deepest such, by `ern build` and `ern doc`
%% alike, and the file's own name with none. A regression test: the
%% refusal named no root (findings.md's K21)
single_file_root_test() ->
    Dir = tmp(),
    write(Dir, "app/net/http.ern", "export let port : Int = 80\n"),
    write(Dir, "tA/main.ern", hello()),
    write(Dir, "a/Bc/De/main.ern", hello()),
    write(Dir, "ok/Main.ern", hello()),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    Refused = fun(Args, Said) ->
                  ?assertEqual(1, ern_cli:ern(Args, group_leader())),
                  ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(
                                                      ?capturedOutput), Said))
              end,
    try
        ?assertEqual(0, ern_cli:ern(["build", "app/net/http.ern"])),
        {ok, Beam} = file:read_file("app/net/http.erc"),
        ?assertMatch({ok, #{interface := #interface{namespace = ['App', 'Net', 'Http']}}},
                     ern_interface:read(Beam)),
        Refused(["build", "tA/main.ern"],
                <<"tA/main.ern: path component `tA` must be lowercase; --source-root tA"
                  " leaves it out of the namespace">>),
        Refused(["doc", "tA/main.ern"], <<"; --source-root tA leaves it out">>),
        Refused(["build", "a/Bc/De/main.ern"],
                <<"path component `De` must be lowercase; --source-root a/Bc/De leaves">>),
        Refused(["build", "ok/Main.ern"], <<"path component `Main` must be lowercase\n">>)
    after
        file:set_cwd(Cwd)
    end.

%% report §11.1, §11.5: a parse error in directory mode is its position,
%% its message, and the source under it with the span marked, status 1
parse_error_test() ->
    Dir = tmp(),
    File = write(Dir, "a.ern", "export fn f() : Int = \n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertEqual(<<(list_to_binary(File))/binary, ":2:1: expected an expression instead of"
                   " end of input\n1 | export fn f() : Int = \n2 | \n  | ^\n\n">>,
                 Output).

%% report Appendix D, §11.1, §11.2, §4.7: the foreign library Appendix D
%% writes out is compiled as a root of its own, a program is compiled
%% against its interface with --load-path and run with it, and prints what
%% the appendix's main says
appendix_d_library_test() ->
    Dir = tmp(),
    [Library, Main | _] = appendix_d_blocks(),
    write(Dir, "lib/ets.ern", Library),
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
    ErlangFile = write(Dir, "erl/ern_cli_helper.erl",
                       "-module(ern_cli_helper).\n-export([twice/1]).\ntwice(N) -> 2 * N.\n"),
    ok = filelib:ensure_path(Dir ++ "/beams"),
    {ok, ern_cli_helper} = compile:file(ErlangFile, [{outdir, Dir ++ "/beams"}]),
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
    [Library, Main | _] = appendix_d_blocks(),
    write(Dir, "lib/ets.ern", Library),
    write(Dir, "src/main.ern", Main),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build/src", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"unknown name Ets.new">>)).

%% The fenced code blocks of Appendix D, in order.
appendix_d_blocks() ->
    {ok, Report} = file:read_file("../../../report/library.md"),
    [_, AfterD] = binary:split(Report, <<"## Appendix D.">>),
    [AppendixD | _] = binary:split(AfterD, <<"## Appendix E.">>),
    Parts = binary:split(AppendixD, <<"```">>, [global]),
    [strip_fence_line(Part) || {Index, Part} <- lists:zip(lists:seq(1, length(Parts)), Parts),
                               Index rem 2 =:= 0].

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

%% report §3.10, §4.2, §11.2: a type member of another module is called by
%% its module path, type, and member, and loads from the module that owns
%% it; `<` on the type reaches it there
type_member_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/stack.ern",
          "export abstract type Stack(a) = Stack(List(a))\n"
          "export let empty : Stack(a) = Stack([])\n"
          "export fn push(x : a, Stack(xs) : Stack(a)) : Stack(a) = Stack(x :: xs)\n"
          "export fn Stack.compare(Stack(xs) : Stack(a), Stack(ys) : Stack(a)) : Ordering =\n"
          "    Int.compare(List.size(xs), List.size(ys))\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = {\n"
          "    let s = Lib.Stack.push(1, Lib.Stack.empty);\n"
          "    let t = Lib.Stack.push(2, s);\n"
          "    Io.println(Io.show(Lib.Stack.Stack.compare(t, s)));\n"
          "    Io.println(Io.show(s < t));\n"
          "    Io.println(Io.show(#(s, 2)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    %% report Appendix E.1: an abstract value outside its module
    ?assertEqual(<<"Greater\ntrue\n#(<abstract>, 2)\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.4, Appendix E.1, §4.9: outside its module an abstract value is
%% shown as `<abstract>`, and no generic function shows it by its
%% representation, `Io.show` at a type variable no requirement names being a
%% type error. A regression test of the rule of 2026-10-01: through a type
%% variable its constructor was shown
abstract_shown_outside_its_module_test() ->
    Dir = tmp(),
    Stack = "export abstract type Stack(a) = Stack(List(a))\n"
            "export let one : Stack(Int) = Stack([1])\n",
    write(Dir, "src/lib/stack.ern", Stack),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = Io.println(Io.show(Lib.Stack.one))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"<abstract>\n">>, iolist_to_binary(?capturedOutput)),
    Refused = tmp(),
    write(Refused, "src/lib/stack.ern", Stack),
    write(Refused, "src/main.ern",
          "fn shown(x : a) : String = Io.show(x)\n\n"
          "export fn main() : Unit with Never = Io.println(shown(Lib.Stack.one))\n"),
    ?assertEqual(1, build_err(["--build-root", Refused ++ "/build", Refused ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "Io.show needs a.show, which shown does not declare; add"
                                    " needs a.show")).

%% report Appendix E.1, §3.8: a value of a foreign type is shown as
%% `<foreign>`, `Foreign.Term` and a type a module declares alike, inside
%% another value too. A regression test: it was shown by its representation
%% after the rule of 2026-10-01 had said otherwise
foreign_shown_as_foreign_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "foreign type Handle\n\n"
          "foreign fn handle() : Handle = \"erlang:self/0\"\n\n"
          "export fn main() : Unit with Never =\n"
          "    Io.println(Io.show(#(Foreign.from(1), [Erl.atom(\"a\")], handle())))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"#(<foreign>, [<foreign>], <foreign>)\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §4.2: `T.name` is the module's own member where its type `T`
%% declares one of that name, and the module T's `name` otherwise. A
%% regression test: the build left module T out wherever the module
%% declared a type T, and `Stack.other` was an unknown name (R-3)
type_name_shares_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/stack.ern", "export fn other() : Int = 7\n"),
    write(Dir, "src/main.ern",
          "type Stack = Stack(List(Int))\n\n"
          "fn Stack.negate(s : Stack) : Int = match s { Stack(xs) -> List.size(xs) }\n\n"
          "export fn main() : Unit with Never =\n"
          "    Io.println(Int.toString(Stack.other() + Stack.negate(Stack([1]))))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"8\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a prelude namespace
prelude_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/io.ern", "export fn println(s : String) : Unit with m = Unit\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    %% nor the name of the prelude itself, which `Prelude.X` reaches
    PreludeDir = tmp(),
    write(PreludeDir, "src/prelude.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(1, build_err(["--build-root", PreludeDir ++ "/build", PreludeDir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"takes the prelude namespace Prelude">>)).

%% report §4.2: the refusal names whose namespace a file at the source root
%% takes: `Address`, a prelude type with members, is the prelude's, `Io` and
%% `Test` the standard library's. A regression test, written after the code; it does
%% not cover a namespace that both take, such as `Int`, which is named as
%% the prelude's.
taken_namespace_names_owner_test() ->
    lists:foreach(
      fun(File) ->
          Dir = tmp(),
          write(Dir, "src/" ++ File, "export fn f() : Int = 1\n"),
          ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"]))
      end, ["address.ern", "io.ern", "test.ern"]),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _},
                 binary:match(Output, <<"address.ern takes the prelude namespace Address">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"io.ern takes the standard library namespace Io">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"test.ern takes the standard library namespace Test">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"prelude namespace Io">>)),
    %% report §9.7: the prelude binds no system reference, so `Sys` is free
    Dir = tmp(),
    write(Dir, "src/sys.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(0, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: a prelude type without members takes no namespace, so a
%% program's modules may be named after it: `Down.describe` is the module's
%% function, and `Down(...)` still builds the prelude's type. `never.ern`'s
%% `compare` is its own, not a member of the built-in type. A regression
%% test: `down.ern`, `reason.ern` and `never.ern` were refused
prelude_type_without_members_is_no_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/down.ern", "export fn describe(d : Down) : String = d.site\n"),
    write(Dir, "src/reason.ern", "export let answer : Int = 42\n"),
    write(Dir, "src/never.ern", "export fn compare(a : Int, b : Int) : Int = a - b\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit with Never = {\n"
          "    let me = Process.fromAddress(self());\n"
          "    let down = Down(process = me, reason = Killed, site = \"here\");\n"
          "    Io.println(Down.describe(down));\n"
          "    Io.println(Int.toString(Reason.answer + Never.compare(3, 1)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"here\n44\n">>, iolist_to_binary(?capturedOutput)).

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
          "export let empty = Stack([])\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn f() : Main.Stack(Int) = Main.Stack([])\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Stack is the constructor of an abstract type and is not visible"
                        " outside its module")).

%% report §4.2: type names that differ only in case are distinct, and a
%% type whose name differs only in case from a child module's segment does
%% not take that module's namespace: `STACK` in main.ern beside
%% main/stack.ern compiles, `STACK.negate` is main's own member, written
%% plain within main (§4.2), and `Main.Stack.one` is the child module's. A
%% regression test, written after the code; single-file mode is not covered.
case_distinct_names_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export type STACK = STACK(Int)\n"
          "export type Stack2 = A\n"
          "export type STACK2 = B\n"
          "export fn STACK.negate(s : STACK) : Int = match s { STACK(n) -> n }\n"
          "export fn main() : Unit with m = Io.println(Int.toString(\n"
          "    STACK.negate(STACK(3)) * 100 + STACK.negate(STACK(4)) * 10\n"
          "    + Main.Stack.one()))\n"),
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
          "export let one = Box(n = 1)\n"
          "export fn inside(b : Box) : Int = b.n\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn g() : Int = Main.one.n\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Box is abstract, and its fields are its module's alone")).

%% report §4.2: a module that names itself qualified, past a binding that
%% hides the plain name, is not a module cycle
self_qualified_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "export fn g() : Int = 1\n"
                               "export fn f() : Int = { let g = 0; Main.g() + g }\n"
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
          <<"let dash = Test.Case(name = \"dash\", run = fn() =\n"
            "    Test.Failed(\"a — b\"))\n"/utf8>>),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/checks.erc"])),
    Output = unicode:characters_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"dash: failed: a — b\n"/utf8>>)).

%% report Appendix E.24, §11.2: a test runs in a process whose mailbox type
%% is its own, so one may receive what a process it spawned sends it.
%% Written after the code
test_receives_test() ->
    Dir = tmp(),
    File = write(Dir, "waits.ern",
                 "type Go = Go\n"
                 "let waits = Test.Case(name = \"waits\", run = fn() = {\n"
                 "    let me = self();\n"
                 "    let _ = spawn(fn() : Unit with Never = send(me, Go));\n"
                 "    receive { Go -> Test.Passed }\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "waits.erc")])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Output, "waits: passed\n")).

%% report Appendix E.24, §11.2: ern test runs every top-level let of type Test.Case,
%% exported or not, each in its own process, reports each, and exits 1
%% unless every one passed
test_runner_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "fn add(a : Int, b : Int) : Int = a + b\n"
          "let addsTwo = Test.Case(name = \"adds two\", run = fn() =\n"
          "    if add(1, 1) == 2 then Test.Passed else Test.Failed(\"not two\"))\n"
          "export let wrong = Test.Case(name = \"wrong\", run = fn() =\n"
          "    Test.Failed(\"expected 3\"))\n"
          "let divides = Test.Case(name = \"divides\", run = fn() =\n"
          "    if 1 / (add(1, 1) - 2) == 0 then Test.Passed else Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/checks.erc"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Output, "adds two: passed\n")),
    ?assertMatch({match, _}, re:run(Output, "wrong: failed: expected 3\n")),
    ?assertMatch({match, _}, re:run(Output, "divides: faulted: division by zero\n")),
    write(Dir, "src2/ok.ern",
          "let fine = Test.Case(name = \"fine\", run = fn() = Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build2", Dir ++ "/src2"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build2/ok.erc"])).

%% report Appendix E.24, §4.9: `Test.equal` passes where the actual value
%% equals the expected one and otherwise fails naming both as `Io.show`
%% writes them, the expected first, at a type the program declares and
%% through a function that names `a.show` alike. Written with the function
%% (findings.md's E108)
test_equal_test() ->
    Dir = tmp(),
    File = write(Dir, "equals.ern",
                 "type Point = Point(x : Int, y : Int)\n"
                 "fn same(value : a) : Test.Result needs a.show = Test.equal(value, value)\n"
                 "let sums = Test.Case(name = \"sums\", run = fn() = Test.equal(1 + 1, 3))\n"
                 "let points = Test.Case(name = \"points\", run = fn() =\n"
                 "    Test.equal(Point(x = 1, y = 2), Point(x = 1, y = 3)))\n"
                 "let itself = Test.Case(name = \"itself\", run = fn() = same([Some(1)]))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_cli:ern(["test", filename:join(Dir, "equals.erc")])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"sums: failed: expected 3, got 2\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"points: failed: expected Point(x = 1, y = 3),"
                                                " got Point(x = 1, y = 2)\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"itself: passed\n">>)).

%% report §11.2, §11.8: given a directory, `ern test` runs the tests of every
%% `.erc` under it in the order of their paths, a name that begins with a
%% dot and a link to a directory passed over; each module's name stands on
%% a line before its tests' lines; a module without tests is passed over
%% and not run, so its initializer writes nothing; a module's own
%% initializers run before its tests; the status is 1 where a test failed
%% and 0 where every one passed; and a directory without a test prints `no
%% tests`. A regression test, written after the code. It does not show
%% that each module has a runtime of its own beyond its initializers
%% running again
test_directory_test() ->
    Dir = tmp(),
    write(Dir, "src/stack.ern",
          "export let base = { Io.println(\"stack begins\"); 2 }\n"
          "export fn double(n : Int) : Int = n * base\n"
          "let doubles = Test.Case(name = \"doubles\", run = fn() =\n"
          "    if double(2) == 4 then Test.Passed else Test.Failed(\"not 4\"))\n"),
    write(Dir, "src/plain.ern",
          "export let loud = { Io.println(\"plain begins\"); 1 }\n"),
    write(Dir, "src/net/http.ern",
          "let wrong = Test.Case(name = \"wrong\", run = fn() = Test.Failed(\"expected 3\"))\n"
          "let fine = Test.Case(name = \"fine\", run = fn() =\n"
          "    if Stack.double(1) == 2 then Test.Passed else Test.Failed(\"not 2\"))\n"),
    Build = Dir ++ "/build",
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Build, Dir ++ "/src"])),
    %% what the walk passes over: a name that begins with a dot, and a link
    %% to a directory, each holding a module whose test would fail
    {ok, _} = file:copy(Build ++ "/net/http.erc", write(Dir, "build/.hidden/net/http.erc", "")),
    ok = file:make_symlink("net", Build ++ "/linked"),
    ?assertEqual(1, ern_cli:ern(["test", Build])),
    ?assertEqual(<<"Net.Http\n"
                   "stack begins\n"
                   "wrong: failed: expected 3\n"
                   "fine: passed\n"
                   "Stack\n"
                   "stack begins\n"
                   "doubles: passed\n">>,
                 iolist_to_binary(?capturedOutput)),
    ok = file:delete(Build ++ "/net/http.erc"),
    ok = file:delete(Build ++ "/linked"),
    ?assertEqual(0, ern_cli:ern(["test", Build])),
    Empty = filename:join(Dir, "empty"),
    ok = file:make_dir(Empty),
    ?assertEqual(0, ern_cli:ern(["test", Empty])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Output, "doubles: passed\nno tests\n$")).

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
          "let first = Test.Case(name = \"first\", run = fn() = {\n"
          "    Io.println(\"inside first\");\n"
          "    Test.Passed\n"
          "})\n"
          "let stuck = Test.Case(name = \"stuck\", run = fn() = {\n"
          "    let w = spawn(waiter);\n"
          "    if Address.callForever(w, fn(r) = Ask(reply = r)) == 0 then\n"
          "        Test.Passed\n"
          "    else\n"
          "        Test.Passed\n"
          "})\n"
          "let last = Test.Case(name = \"last\", run = fn() = Test.Passed)\n"),
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
          "let none = Test.Case(name = \"none\", run = fn() =\n"
          "    if Os.arguments == [] then Test.Passed else Test.Failed(\"arguments\"))\n"
          "let exits = Test.Case(name = \"exits\", run = fn() = Os.exit(2))\n"
          "let later = Test.Case(name = \"later\", run = fn() = Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["test", Dir ++ "/build/checks.erc"])),
    ?assertEqual(<<"none: passed\nexits: faulted: exited with status 2\nlater: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11: a link where `ern build` writes a `.erc` is replaced by the
%% module, and what the link named is left as it was. A regression test:
%% the build wrote through a link planted in the build tree
%% (findings.md's C3-25)
build_replaces_a_link_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export fn one() : Int = 1\n"),
    write(Dir, "victim/notes.txt", "mine\n"),
    ok = file:make_symlink("../victim/notes.txt", filename:join(Dir, "src/util.erc")),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    ?assertEqual({ok, <<"mine\n">>}, file:read_file(filename:join(Dir, "victim/notes.txt"))),
    ?assertMatch({ok, #file_info{type = regular}},
                 file:read_link_info(filename:join(Dir, "src/util.erc"))).

%% report §11.2: `ern test` writes a test's name as it writes a cause, its
%% control characters escaped. A regression test: the name reached the
%% terminal as it was (findings.md's C3-17)
test_name_escaped_test() ->
    Dir = tmp(),
    write(Dir, "src/names.ern",
          "let t = Test.Case(name = \"red\\u{1b}[31mX\\nsecond\",\n"
          "             run = fn() = Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["test", Dir ++ "/build/names.erc"])),
    ?assertEqual(<<"red\\u{1B}[31mX\\nsecond: passed\n">>, iolist_to_binary(?capturedOutput)).

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
                         forge(Main3, fun(Chunk) -> Chunk#{stdlib => <<"another">>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")),
    %% a module built by another version of ern is rebuilt
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(Chunk) -> Chunk#{compiler => <<"0.0.0">>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")),
    %% and one built by another build of this version, whose code changed: a
    %% regression test, since the version alone was compared and a changed
    %% compiler kept what it had built before
    ok = file:write_file(Dir ++ "/build/main.erc",
                         forge(Main3, fun(Chunk) -> Chunk#{compiler => <<?VERSION>>} end)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main3}, file:read_file(Dir ++ "/build/main.erc")).

%% report §11.1: a module is recompiled when the code of the compiler that
%% built it changed, so the modules hashed are every module of the toolchain
%% that the compiling modules call. A regression test: six were left out,
%% and a change to one of them, `ern_docs` among them, left every .erc
%% current. The build is a module of its own, `ern_build`, whose calls are
%% followed too; `ern_cli`'s other jobs, which call the runtime and the
%% shell, are not hashed, so a change to them recompiles nothing
compiler_modules_closed_test() ->
    Modules = ern_build:compiler_modules(),
    ?assertNot(lists:member(ern_cli, Modules)),
    Called = lists:usort([Callee || Module <- Modules, Callee <- calls(Module)]),
    ?assertEqual([], Called -- Modules).

%% The modules of the toolchain that Module calls, from its imports.
calls(Module) ->
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(code:which(Module), [imports]),
    lists:usort([Callee || {Callee, _, _} <- Imports, lists:prefix("ern_", atom_to_list(Callee))]).

%% A compiled module with its interface chunk changed by Change.
forge(Beam, Change) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    Rewritten = [case Id of
                     "ErnI" -> {Id, term_to_binary(Change(binary_to_term(Chunk)))};
                     _ -> {Id, Chunk}
                 end || {Id, Chunk} <- Chunks],
    {ok, Forged} = beam_lib:build_module(Rewritten),
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
    BuildRoot = Dir ++ "/build",
    write(Dir, "lib/util.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit with Never =\n"
                               "    Io.println(Int.toString(Util.f()))\n"),
    write(Dir, "build/old.erc", "not a module\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, "--load-path", BuildRoot,
                                 Dir ++ "/src"])),
    ?assert(filelib:is_regular(BuildRoot ++ "/util.erc")),
    ?assert(filelib:is_regular(BuildRoot ++ "/old.erc")),
    %% built in place, the build tree is the source tree
    ok = filelib:ensure_path(Dir ++ "/src/empty"),
    ok = filelib:ensure_path(Dir ++ "/src/.git/refs/tags"),
    ?assertEqual(0, ern_cli:ern(["build", "--load-path", BuildRoot, Dir ++ "/src"])),
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
    {ok, #{interface := #interface{namespace = Namespace}}} = ern_interface:read(Beam),
    ?assertEqual(['Util'], Namespace).

%% report §11.1: a stale .erc is no module, and a module that uses it is an
%% error. A regression test: the build compiled against it, then swept it,
%% and the program it had built could not load
stale_erc_is_no_module_test() ->
    Dir = pair(tmp()),
    BuildRoot = Dir ++ "/build",
    Args = ["--build-root", BuildRoot, "--load-path", BuildRoot, Dir ++ "/src"],
    ?assertEqual(0, build_err(Args)),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(1, build_err(Args)),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      list_to_binary("no module Net.Http: " ++ BuildRoot
                                                     ++ "/net/http.erc was compiled from "
                                                     ++ Dir ++ "/src/net/http.ern,"
                                                     " which no longer exists"))),
    ?assert(filelib:is_regular(BuildRoot ++ "/net/http.erc")).

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
    {ok, #{source_path := Path}} = ern_interface:read(After),
    ?assertEqual(<<"../moved/main.ern">>, Path).

%% report §11.1: --emit-erl writes the Erlang source and no .erc
emit_erl_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--build-root", Dir ++ "/build",
                                 Dir ++ "/src"])),
    {ok, Source} = file:read_file(Dir ++ "/build/net/http.erl"),
    ?assertMatch({_, _}, binary:match(Source, <<"-module(ern@net@http).">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--emit", "asm", Dir ++ "/src"])).

%% report §11.1: --emit-erl writes a module whose strings hold characters
%% beyond Latin-1, as Erlang's source is, in UTF-8. A regression test: the
%% source was written as a list of characters, which fails beyond 255.
emit_erl_unicode_test() ->
    Dir = tmp(),
    File = write(Dir, "dots.ern", "export fn dot() : String = \"\\u{2022}\"\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--source-root", Dir, File])),
    {ok, Source} = file:read_file(filename:join(Dir, "dots.erl")),
    ?assertMatch({_, _}, binary:match(Source, <<"\x{2022}"/utf8>>)).

%% report §11.1, §11.5: an error is file:line:column: text, status 1
compile_error_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:49: the argument does not fit Io.println:"
                   " expected String, found Int\n"
                   "1 | export fn main() : Unit with Never = Io.println(1)\n"
                   "  |                                      ---------- Io.println : (String) ->"
                   " Unit with e+\n"
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
    Output = unicode:characters_to_binary(?capturedOutput),
    Line = <<"1 | fn twice(n) = n + n  // Int — or Float\n"/utf8>>,
    ?assertMatch({_, _}, binary:match(Output, Line)).

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
                 "    let _ = spawnMonitored(restarting(limit, fn() : Unit with Never =\n"
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
                 "export let empty : Box(a) = Box([])\n"
                 "/// Put x in the box.\n"
                 "export fn put(x : a, Box(xs) : Box(a)) : Box(a) = Box(x :: xs)\n"
                 "/// By size.\n"
                 "export fn Box.compare(Box(xs) : Box(a), Box(ys) : Box(a)) : Ordering =\n"
                 "    Int.compare(List.size(xs), List.size(ys))\n"
                 "export fn same(a, b) = a == b\n"
                 "/// Documented but private.\n"
                 "fn twice(n : Int) : Int = 2 * n\n"
                 "fn hidden(n : Int) : Int = n\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", Dir, File])),
    Output = iolist_to_binary(?capturedOutput),
    Expect = fun(Text) -> ?assertMatch({_, _}, binary:match(Output, Text)) end,
    Expect(<<"# Ernest module Shapes\n\n## Shapes.Shape\n\n```ernest\n"
             "type Shape = Dot | At(x : Int, y : Int)\n```\n\nA shape.\n">>),
    Expect(<<"## Shapes.Box\n\n```ernest\nabstract type Box(a)\n```\n">>),
    Expect(<<"## Shapes.empty\n\n```ernest\nShapes.empty : Box(a)\n```\n">>),
    %% report §3.9, §6.6: put places its element in a list once, so it takes a reply
    %% report §11.4: a function shows its declaration, a parameter written
    %% as a pattern with its type alone
    Expect(<<"## Shapes.put\n\n```ernest\nShapes.put(x : a, Box(a)) : Box(a)\n```\n\n"
             "Put x in the box.\n">>),
    %% report §4.2: a member is shown under its type; §3.9: it drops its
    %% boxes' elements, and `Box` is no type the restriction looks through
    Expect(<<"## Shapes.Box.compare\n\n```ernest\n"
             "Shapes.Box.compare(Box(a!), Box(a!)) : Ordering\n```\n\nBy size.\n">>),
    Expect(<<"## Shapes.same\n\n```ernest\nShapes.same(a : a=, b : a=) : Bool\n```\n">>),
    %% report §11.4: a private declaration is marked
    Expect(<<"## Shapes.twice\n\n```ernest\nShapes.twice(n : Int) : Int\n```\n\n"
             "*Private to the module.*\n\nDocumented but private.\n">>),
    ?assertEqual(nomatch, binary:match(Output, <<"hidden">>)),
    %% a type error is reported as for a compilation
    ?assertEqual(1, ern_cli:ern(["doc", "--source-root", Dir,
                                 write(Dir, "bad.ern", "export fn f() : Int = \"s\"\n")])).

%% report §11.1, §11.4: the documentation comes from the compiled module,
%% so `ern doc` on a .erc writes what it writes on its source, and asking a
%% source for its page writes nothing
doc_from_compiled_test() ->
    Dir = tmp(),
    Source = write(Dir, "shapes.ern",
                   "/// A shape.\n"
                   "export type Shape = Dot | At(x : Int, y : Int)\n"
                   "/// Twice n.\n"
                   "export fn twice(n : Int) : Int = 2 * n\n"),
    BuildRoot = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", Dir, "--build-root", BuildRoot, Source])),
    FromSource = iolist_to_binary(?capturedOutput),
    ?assertEqual(false, filelib:is_regular(filename:join(BuildRoot, "shapes.erc"))),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--build-root", BuildRoot,
                                 Source])),
    ?assertEqual(0, ern_cli:ern(["doc", filename:join(BuildRoot, "shapes.erc")])),
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

%% report §11.1, §11.4: a compiled module may come from anywhere, so what
%% its chunks say is read as data: a source's name with a line feed in it
%% is written on the manual page's comment line with the line feed as an
%% escape, and a chunk that holds a function is no chunk of the compiler's.
%% A regression test: the name ended the comment and its next line was a
%% request of the page's, and the host decoded whatever a chunk held
%% (findings.md's C3-29)
crafted_module_test() ->
    Dir = tmp(),
    File = write(Dir, "shapes.ern", "export fn one() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    Erc = filename:join(Dir, "shapes.erc"),
    {ok, Built} = file:read_file(Erc),
    {ok, _, Chunks} = beam_lib:all_chunks(Built),
    Rewritten = fun(Name, Rewrite) ->
                    {Name, Chunk} = lists:keyfind(Name, 1, Chunks),
                    {ok, Beam} = beam_lib:build_module(
                                   lists:keystore(Name, 1, Chunks,
                                                  {Name, term_to_binary(Rewrite(Chunk))})),
                    ok = file:write_file(Erc, Beam)
                end,
    Rewritten("Docs", fun(Chunk) ->
                          Docs = binary_to_term(Chunk),
                          setelement(6, Docs, #{source => <<"shapes.ern\n.so /etc/passwd">>})
                      end),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", Erc])),
    [Comment, Next | _] = binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global]),
    ?assertMatch({_, _}, binary:match(Comment, <<"shapes.ern\\n.so /etc/passwd.">>)),
    ?assertMatch(<<".TH ", _/binary>>, Next),
    Rewritten("ErnI", fun(Chunk) -> (binary_to_term(Chunk))#{compiler => fun erlang:halt/0} end),
    ?assertEqual(1, ern_err(["doc", Erc])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"of another compiler version">>)).

%% report §11.4: `ern doc --man src-dir` writes each page beside its
%% module's .erc, in a file named as `man` finds it, and no index
doc_man_dir_test() ->
    Dir = pair(tmp()),
    BuildRoot = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", BuildRoot,
                                 filename:join(Dir, "src")])),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Http.3ern"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "Ernest.Main.3ern"))),
    ?assertEqual([], filelib:wildcard(filename:join(BuildRoot, "*.md"))),
    {ok, Page} = file:read_file(filename:join(BuildRoot, "net/Ernest.Net.Http.3ern")),
    ?assertMatch({_, _}, binary:match(Page, <<".TH \"Ernest.Net.Http\" \"3ern\"">>)).

%% report §11.4: a page `ern doc` wrote of a module whose source is gone is
%% removed, as the build removes its .erc, and a file it did not write is
%% kept. A regression test: the page stayed, out of the index
%% (findings.md's T17)
doc_sweeps_pages_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Extra = write(Dir, "src/net/extra.ern", "export fn two() : Int =\n    2\n"),
    Document = fun(Args) ->
                   ?assertEqual(0, ern_cli:ern(["doc" | Args]
                                               ++ ["--build-root", BuildRoot, SourceRoot]))
               end,
    Document([]),
    Document(["--man"]),
    Notes = write(BuildRoot, "net/notes.md", "# Ernest module Net.Gone\n"),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/extra.md"))),
    ok = file:delete(Extra),
    Document([]),
    Document(["--man"]),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/extra.md"))),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Extra.3ern"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/http.md"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Http.3ern"))),
    ?assert(filelib:is_regular(Notes)),
    {ok, Index} = file:read_file(filename:join(BuildRoot, "index.md")),
    ?assertEqual(nomatch, binary:match(Index, <<"Extra">>)).

%% report §11.4, §11.8: a page whose title names no module at its place
%% is kept, however long the title, and one the sweep cannot read is
%% refused with the host's reason and status 1. A regression test: the
%% sweep made an atom of each title, and a long one, or a page it could not
%% read, ended it as a failure of ern itself
doc_sweep_reads_titles_as_text_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Notes = write(BuildRoot, "notes.md", "# Ernest module " ++ lists:duplicate(300, $A) ++ "\n"),
    ?assertEqual(0, ern_err(["doc", "--build-root", BuildRoot, SourceRoot])),
    ?assert(filelib:is_regular(Notes)),
    ok = file:change_mode(Notes, 8#000),
    ?assertEqual(1, ern_err(["doc", "--build-root", BuildRoot, SourceRoot])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"notes.md: permission denied">>)),
    ok = file:change_mode(Notes, 8#644).

%% report §11.4: a manual page is UTF-8 text. A regression test: the
%% prelude's wrote its `§` as one byte of Latin-1
doc_man_utf8_test_() ->
    {timeout, 120,
     fun() ->
         BuildRoot = filename:join(tmp(), "build"),
         ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", BuildRoot,
                                      "../../../stdlib"])),
         Pages = filelib:wildcard(filename:join(BuildRoot, "**/*.3ern")),
         ?assert(lists:member(filename:join(BuildRoot, "Ernest.Prelude.3ern"), Pages)),
         [?assertMatch({Page, true}, {Page, is_list(unicode:characters_to_list(Bytes))})
          || Page <- Pages, {ok, Bytes} <- [file:read_file(Page)]]
     end}.

%% report §11.1: the compiled module carries its documentation as EEP 48's
%% Docs chunk, so the host's own tools read an Ernest module
docs_chunk_test() ->
    Dir = tmp(),
    Source = write(Dir, "shapes.ern",
                   "/// A shape.\n"
                   "/// since 0.2.0\n"
                   "export type Shape = Dot | At(x : Int, y : Int)\n"
                   "/// Twice n.\n"
                   "export fn twice(n : Int) : Int = 2 * n\n"),
    BuildRoot = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--build-root", BuildRoot,
                                 Source])),
    {ok, Beam} = file:read_file(filename:join(BuildRoot, "shapes.erc")),
    {ok, Docs} = ern_docs:read(Beam),
    {docs_v1, _, ernest, <<"text/markdown">>, none, Meta, Entries} = Docs,
    ?assertEqual(<<"shapes.ern">>, maps:get(source, Meta)),
    %% the parameter list as written, for the shell's completion
    ?assertMatch([{{type, 'Shape', 0}, _, [<<"type Shape = Dot | At(x : Int, y : Int)">>],
                   #{<<"en">> := <<"A shape.\nsince 0.2.0">>}, #{items := _}},
                  {{function, twice, 1}, _, [<<"Shapes.twice(n : Int) : Int">>],
                   #{<<"en">> := <<"Twice n.">>}, #{params := [n]}}],
                 Entries),
    %% Erlang's own documentation reader finds it, as it finds the standard
    %% library's modules installed under build/stdlib
    ErlangModule = ern_emitter:erlang_module(['Shapes']),
    ok = file:write_file(filename:join(BuildRoot, atom_to_list(ErlangModule) ++ ".beam"), Beam),
    true = code:add_patha(BuildRoot),
    {module, ErlangModule} = code:ensure_loaded(ErlangModule),
    ?assertMatch({ok, {docs_v1, _, ernest, _, _, _, _}}, code:get_doc(ErlangModule)),
    true = code:delete(ErlangModule),
    true = code:del_path(BuildRoot).

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
    [?assertMatch({_, _}, binary:match(Page, <<"\n## ", Name/binary, "\n">>))
     || Name <- [<<"send">>, <<"Address.call">>, <<"Optional">>, <<"restarting">>, <<"Int">>]],
    ?assertMatch({_, _}, binary:match(Page, <<"from the prelude, report §9."/utf8>>)).

%% report §11.4, Appendix E.0 rule 6: docs/module_doc_template.md is what
%% `ern doc` renders for examples/template.ern, after its marker line
doc_template_test() ->
    Source = example("template.ern"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", filename:dirname(Source), Source])),
    Output = iolist_to_binary(?capturedOutput),
    {ok, Template} = file:read_file("../../../docs/module_doc_template.md"),
    Marker = <<"<!-- generated: ern doc examples/template.ern -->\n">>,
    [_, Generated] = binary:split(Template, Marker),
    %% the last line names the compiler's version, which is compared to itself
    ?assertEqual(without_footer(Generated), without_footer(Output)),
    %% the module and every exported declaration say since which version, E.0 rule 6
    {match, Sinces} = re:run(Output, "\\*Since 0\\.1\\.0\\.\\*", [global]),
    %% the module states its since; no declaration differs from it
    ?assertEqual(1, length(Sinces)),
    %% every exported type has an Examples section, and the one function no
    %% module example calls, E.0 rule 6
    Sections = tl(binary:split(Output, <<"\n## ">>, [global])),
    Named = fun(Name) ->
                Head = <<Name/binary, "\n">>,
                hd([Section || Section <- Sections,
                               binary:match(Section, Head) =:= {0, byte_size(Head)}])
            end,
    lists:foreach(fun(Name) ->
                      ?assertMatch({_, _}, binary:match(Named(Name), <<"### Examples">>))
                  end,
                  [<<"Template.Point">>, <<"Template.Shape">>, <<"Template.Stack">>,
                   <<"Template.radius">>]),
    ?assertMatch({match, _},
                 re:run(Output, "\n---\n\nGenerated by ern [0-9.]+ from template.ern.\n$")).

without_footer(Doc) ->
    hd(binary:split(Doc, <<"\n---\n\nGenerated by ern ">>)).

%% docs/development.md, "What the toolchain accepts": every error text in
%% erl/*/src or in the shell's own Ernest source that names an MVP appears
%% in that document's table, by its first forty characters, so the table
%% cannot drift from what the code refuses
mvp_refusals_listed_test() ->
    {ok, Listed} = file:read_file("../../../docs/development.md"),
    Pattern = "\"([^\"\n]*\\bin MVP [0-9][^\"\n]*)\"",
    Find = fun(Text) ->
               case re:run(Text, Pattern, [global, {capture, all_but_first, binary}]) of
                   {match, Matches} -> [Match || [Match] <- Matches];
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
    Texts = lists:usort(lists:append([Find(Text) || Path <- Sources,
                                                    {ok, Text} <- [file:read_file(Path)]])),
    Missing = [Refusal || Refusal <- Texts,
                          binary:match(Listed, binary:part(Refusal, 0, min(40, byte_size(Refusal))))
                              =:= nomatch],
    ?assertEqual([], Missing).

%% report §11: --version prints the top-level VERSION file's content
version_test() ->
    {ok, Version} = file:read_file("../../../VERSION"),
    ?assertEqual(0, ern_cli:ern(["--version"])),
    ?assertEqual(<<"ern ", (string:trim(Version))/binary, "\n">>,
                 iolist_to_binary(?capturedOutput)).

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
     || Job <- ["build", "doc", "format", "run", "test", "shell", "config"]].

%% report §11: the first word is the job, and none is refused with the jobs
%% named
job_first_test() ->
    ?assertEqual(1, ern_err([])),
    ?assertEqual(1, ern_err(["compile", "x.ern"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"ern: a job is required\nUsage: ern <job>">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern: no job compile; the jobs are build, doc,"
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
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% report §11.2: a module without tests says so, and one two of whose tests
%% have one name is refused before any runs. A regression test: the first
%% printed nothing, and the second two lines no reader could tell apart
%% (findings.md's T24)
test_names_test() ->
    Dir = tmp(),
    None = write(Dir, "none.ern", "export fn two() : Int =\n    2\n"),
    Twice = write(Dir, "twice.ern",
                  "let a =\n"
                  "    Test.Case(name = \"adds two\", run = fn() = Test.Passed)\n\n"
                  "let b =\n"
                  "    Test.Case(name = \"adds two\", run = fn() = Test.Failed(\"no\"))\n"),
    Build = fun(File) ->
                ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
                filename:rootname(File) ++ ".erc"
            end,
    ?assertEqual(0, ern_cli:ern(["test", Build(None)])),
    ?assertEqual(1, ern_err(["test", Build(Twice)])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"no tests\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern test: two tests are named \"adds two\"">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"failed">>)).

%% report §11.2: `--main` without a file is refused, as it names a function
%% of the file; a regression test, the option having been ignored
%% (findings.md's T9)
shell_main_without_file_test() ->
    ?assertEqual(1, ern_err(["shell", "--main", "Foo.bar"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"ern shell: --main names the function to spawn from"
                                        " the file the shell loads, and no file is given">>)).

%% report §11: an old spelling names its replacement only to a job that
%% takes it, matched by its whole name; `--version` and `--help` stand
%% alone. A regression test: every job recommended what it then refused,
%% and `--emit-erl=x` was taken for `--emit` (findings.md's T7)
old_spellings_per_job_test() ->
    Refused = [{["run", "--out-dir", "x", "a.erc"], <<"ern run: invalid option: --out-dir">>},
               {["run", "--errors", "short", "a.erc"], <<"ern run: invalid option: --errors">>},
               {["run", "--emit", "erl", "a.erc"], <<"ern run: invalid option: --emit">>},
               {["build", "--emit-erl=x", "a.ern"], <<"--emit-erl=x: --emit-erl takes no value">>},
               {["--version", "--help"], <<"ern: --version stands alone: ern --version">>},
               {["-v"], <<"ern: no job -v; the jobs are">>},
               {["--load-path=d", "x.erc"],
                <<"ern: --load-path comes after the job: ern <job> --load-path">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused],
    ?assertEqual(nomatch, binary:match(Output, <<"is now">>)).

%% report §11.1, §11.5: a directory build compiles every module but one that
%% uses a module that failed, and reports every failure, a module that
%% does not parse among them. A regression test: it stopped at the first
%% (findings.md's T10)
every_failure_reported_test() ->
    Dir = tmp(),
    write(Dir, "src/c.ern", "export fn c() : Int = \"x\"\n"),
    write(Dir, "src/e.ern", "export fn e() : Int = \"y\"\n"),
    write(Dir, "src/p.ern", "export fn p( : Int = 1\n"),
    write(Dir, "src/d.ern", "export fn d() : Int = C.c()\n"),
    write(Dir, "src/fine.ern", "export fn ok() : Int = 1\n"),
    ?assertEqual(1, build_err(["--short-errors", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text))
     || Text <- [<<"c.ern:1:23:">>, <<"e.ern:1:23:">>, <<"p.ern:1:14:">>]],
    ?assertEqual(nomatch, binary:match(Output, <<"d.ern">>)),
    ?assert(filelib:is_regular(Dir ++ "/src/fine.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/src/d.erc")).

%% report §8.5, §11.2: a top-level binding that faults is reported under
%% its name and line by `ern run` and `ern test`, where `main`'s site and
%% the test runner's internal name stood. A regression test (findings.md's
%% T14); the shell's start is ern_shell_tests' faulting_binding_named
faulting_binding_named_test() ->
    Dir = tmp(),
    File = write(Dir, "init.ern", "fn zero() : Int = List.size([])\n\n"
                                  "let bad : Int = 1 / zero()\n\n"
                                  "export fn main() : Unit with Never ="
                                  " Io.println(Int.toString(bad))\n\n"
                                  "let t : Test.Case(Never) =\n"
                                  "    Test.Case(name = \"one\", run = fn() = Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    Erc = filename:join(Dir, "init.erc"),
    ?assertEqual(1, ern_err(["run", Erc])),
    ?assertEqual(1, ern_err(["test", Erc])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertEqual(2, length(binary:matches(Output, <<"Init.bad:3 faulted: division by zero">>))),
    ?assertEqual(nomatch, binary:match(Output, <<"Init.main">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"$tests">>)).

%% report §11: an option is given once, a `-path` one excepted, with its
%% value as the next word, and never an empty one. A regression test: a
%% repeat took its first value, and `--name=value` and an empty value were
%% accepted (findings.md's T8)
option_spellings_test() ->
    Refused = [{["build", "--build-root", "a", "--build-root", "b", "x.ern"],
                <<"ern build: --build-root is given more than once">>},
               {["run", "--main", "A.b", "--main", "A.c", "x.erc"],
                <<"ern run: --main is given more than once">>},
               {["build", "--short-errors", "--short-errors", "x.ern"],
                <<"ern build: --short-errors is given more than once">>},
               {["build", "--build-root=b", "x.ern"],
                <<"--build-root=b: an option's value is the next word, --build-root value">>},
               {["build", "--build-root", "", "x.ern"],
                <<"ern build: --build-root is given an empty value">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% report §11.1: a module outside the source root is read from its .erc
%% under build-root, and the sweep keeps it. A regression test: only the
%% --load-path roots were searched, and the use was an unknown name (T2)
module_under_build_root_test() ->
    Dir = tmp(),
    write(Dir, "lib/util/math.ern", "export fn twice(n : Int) : Int = n * 2\n"),
    write(Dir, "app/main.ern", "export fn main() : Unit with Never ="
                               " Io.println(Int.toString(Util.Math.twice(21)))\n"),
    BuildRoot = Dir ++ "/build",
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/lib", "--build-root", BuildRoot,
                                 Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, Dir ++ "/app"])),
    ?assert(filelib:is_regular(BuildRoot ++ "/util/math.erc")),
    ?assertEqual(0, ern_cli:ern(["run", BuildRoot ++ "/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: `ern run` refuses a module compiled against another
%% interface of a module it uses, where it had run and faulted where the two
%% differ. A regression test (T3); it does not cover the standard library's
%% hash, which only another build of `ern` changes
stale_dependent_refused_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/shape.ern", "export fn area(n : Int) : Int = n * n\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit with Never ="
                               " Io.println(Int.toString(Geo.Shape.area(3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    write(Dir, "src/geo/shape.ern", "export fn area(n : Int) : String = \"big\"\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir ++ "/src",
                                 Dir ++ "/src/geo/shape.ern"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/src/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"Main was compiled against another Geo.Shape;"
                                        " build Main again">>)).

%% report §11.1, §11.2: a single-file build from another source root does
%% not write over a .erc of another namespace, and `ern run` refuses a file
%% that holds another module than its path names. A regression test (T4):
%% the build replaced it, and the run failed in the host's loader
other_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/shape.ern", "export fn area(n : Int) : Int = n * n\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit with Never ="
                               " Io.println(Int.toString(Geo.Shape.area(3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    ?assertEqual(1, build_err(["--source-root", Dir, Dir ++ "/src/geo/shape.ern"])),
    ok = file:delete(Dir ++ "/src/geo/shape.erc"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Dir ++ "/src/geo/shape.ern"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/src/main.erc"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"holds Geo.Shape, and this build names the module"
                                                " Src.Geo.Shape">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"holds Src.Geo.Shape, not Geo.Shape">>)).

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

%% report §11.2, Appendix A: --main is a qualified name, typenames and then
%% an ident, and anything else is refused as a usage error before any
%% module is looked for. A regression test: a segment past the host's
%% limit on a name ended the job as a failure of ern itself, and a path or
%% an empty segment was looked for on the load path
main_option_checked_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    lists:foreach(fun(Main) ->
                      ?assertEqual({Main, 1},
                                   {Main, ern_err(["run", "--main", Main,
                                                   Dir ++ "/build/main.erc"])}),
                      ?assertMatch({_, _},
                                   binary:match(unicode:characters_to_binary(?capturedOutput),
                                                <<"--main takes a qualified name">>))
                  end, [lists:duplicate(300, $A) ++ ".main", "../../etc.main", "A..b",
                        "Main.main ", "Main. main", "Main.if", "Main.Other", "main.main",
                        "Main.main//x"]).

%% report §8.1, §11.2: an entry point is an exported fn of type
%% `() -> Unit`, with a mailbox type or pure; a function of another shape
%% and a top-level `let` are refused by name and type, as `main` and as
%% `--main`, and a function that is not exported is not found
entry_point_shape_test() ->
    Launch = fun(Source, Args) ->
                 Dir = tmp(),
                 File = write(Dir, "main.ern", Source),
                 ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
                 ern_err(["run" | Args] ++ [filename:join(Dir, "main.erc")])
             end,
    ?assertEqual(1, Launch("export fn main() : Int = 3\n", [])),
    ?assertEqual(1, Launch("export let main = fn() : Unit with Never = Io.println(\"x\")\n",
                           [])),
    ?assertEqual(1, Launch("export fn main() : Unit = Unit\n"
                           "export fn other() : Int = 3\n", ["--main", "Main.other"])),
    ?assertEqual(1, Launch("fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit with m = Io.println(\"m\")\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit = Unit\n"
                           "export fn other() : Unit with Never = Io.println(\"o\")\n",
                           ["--main", "Main.other"])),
    Output = iolist_to_binary(?capturedOutput),
    Refusals = [<<"Main.main is not an entry point: its type is () -> Int">>,
                <<"Main.main is not an entry point: it is a let of type"
                  " () -> Unit with Never">>,
                <<"Main.other is not an entry point: its type is () -> Int">>,
                <<"no exported function Main.main">>,
                <<"m\no\n">>],
    [?assertMatch({_, _}, binary:match(Output, Refusal)) || Refusal <- Refusals],
    %% the refused entry points were not run
    ?assertEqual(nomatch, binary:match(Output, <<"x\n">>)).

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

%% report §8.5: a module's bindings are evaluated after those of every
%% module it depends on, though none of its bindings depends on theirs. A
%% regression test, written after the report said what the runtime did
init_after_dependencies_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/words.ern",
          "let said = Io.println(\"words\")\n"
          "export fn shout(s : String) : String = String.toUpper(s)\n"),
    write(Dir, "src/main.ern",
          "let said = Io.println(\"main\")\n"
          "export fn main() : Unit with Never = Io.println(Lib.Words.shout(\"hi\"))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"words\nmain\nHI\n">>, iolist_to_binary(?capturedOutput)).

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
    ?assertEqual(<<"hello, world\nLib.Boom.boom:2 faulted: division by zero\n">>,
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
                 "    let _ = spawn(fn() : Unit with Never = kill(me));\n"
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
    %% laid out as Appendix C shows it, a key a line in its order; a
    %% regression test, it was one line with its keys sorted (T33)
    ?assertMatch([<<"{">>, <<"  \"network-address\": \"127.0.0.1:8654\",">>,
                  <<"  \"public-key\": \"-----BEGIN PUBLIC KEY-----", _/binary>>,
                  <<"  \"peers\": []">>, <<"}">>, <<>>],
                 binary:split(Conf, <<"\n">>, [global])),
    {ok, #file_info{mode = Mode}} = file:read_file_info(Dir ++ "/private-key.pem"),
    ?assertEqual(8#600, Mode band 8#777),
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
    {ok, #file_info{mode = Mode}} = file:read_file_info(Dir),
    ?assertEqual(8#700, Mode band 8#777),
    Made = tmp() ++ "/made",
    ok = file:make_dir(Made),
    ?assertEqual(1, ern_err(["config", "--config-dir", Made])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"made exists">>)),
    ?assertEqual({ok, []}, file:list_dir(Made)).

captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> Output end.
