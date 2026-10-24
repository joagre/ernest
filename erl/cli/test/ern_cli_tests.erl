%% The command line, report §11: every job of `ern`, build, doc, format,
%% run, test, shell and config, run in this node as the launcher runs it,
%% with what each refuses, writes and reports.
-module(ern_cli_tests).

%% EUnit's captured output, asked of the test's group leader, which is
%% EUnit's. EUnit's own ?capturedOutput first asks whether it is by the
%% function it is running, which under load it can sample while that
%% process runs another module's code, and then answers "" (MVP 2.95's
%% intermittent failure of the diagnostics' examples).
-define(capturedOutput, captured_output()).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("checker/include/ern_canonical.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("cli/include/ern_build.hrl").

%%
%% Helpers: a fresh directory per test, sources written into it
%%

%% Unique to this host and this run, under the run's own directory, which
%% `make` removes when the run ends (erl/app.mk), or the host's for a run
%% of a test by itself.
tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_cli_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% report §11.1: the standard library's own build takes its namespaces from
%% its .erc files and not from an installed copy, so a copy that cannot be
%% read, as one a build of ern in another chunk format wrote, does not stop
%% the build that replaces it, and the copy's directory is the library's
%% again after. A regression test: such a copy stopped `make` until
%% build/stdlib was removed by hand. Not covered: a copy read while another
%% root builds, which is the library's and must be readable. A build of the
%% whole library, about a second and a half alone, runs beside every other
%% suite under `make test-full`, past eunit's five seconds once
stdlib_build_sets_its_copy_aside_test_() ->
    {timeout, 60, fun stdlib_build_sets_its_copy_aside/0}.

stdlib_build_sets_its_copy_aside() ->
    Installed = filename:join(tmp(), "stdlib"),
    ok = filelib:ensure_path(Installed),
    ok = file:write_file(filename:join(Installed, "unreadable.erc"), <<"not a module">>),
    Library = ern_prelude:set_stdlib_directory(Installed),
    try
        ?assertEqual(0, ern_build:compile("ern build", [{build_root, Installed}],
                                          "../../../src/stdlib", standard_error)),
        ?assertEqual(Installed, ern_prelude:stdlib_directory())
    after
        ern_prelude:set_stdlib_directory(Library)
    end.

%% report §11.1: the standard library's own build checks each module after
%% those it depends on and emits it once every module of the library its
%% forms name is checked, its code calling each by the position that
%% module's interface gives, so that a module named by a prelude name or an
%% operator alone, `Int.compare` through a requirement, which is no
%% dependency of §11.1's, is called rightly whatever order the build
%% checks the library in: the library compiled in the order a build takes
%% and in the latest its dependencies allow, each module as late as the
%% modules that use it let it come, gives the same units. A regression test
%% for a defect MVP 3.2's item 4 found, which the order a build took met by
%% chance; the library names, today, no module it does not depend on, so
%% the test holds the order's not mattering, not a module reached by name
%% alone
stdlib_order_test_() ->
    {timeout, 120, fun stdlib_order/0}.

stdlib_order() ->
    SourceRoot = ern_build:absolute("../../../src/stdlib"),
    BuildRoot = ern_build:absolute("../../../build/stdlib"),
    Modules = [ern_build:module_of(ern_build:absolute(File), SourceRoot)
               || File <- ern_build:sources(SourceRoot)],
    Taken = ern_build:compile_order(Modules, SourceRoot, []),
    Latest = latest(Taken, []),
    ?assertNotEqual(Taken, Latest),
    Units = fun(Order) ->
                    {[], Compiled} = ern_build:compiled_in_order(Order, SourceRoot, BuildRoot),
                    maps:map(fun(_, Beam) -> {ok, {_, Md5}} = beam_lib:md5(Beam), Md5 end,
                             Compiled)
            end,
    ?assertEqual(Units(Taken), Units(Latest)).

%% Modules in an order in which each comes after those it depends on and as
%% late as those that depend on it let it, chosen from the end, the first
%% of Taken that may come last taking each place.
latest([], Placed) ->
    Placed;
latest(Remaining, Placed) ->
    [Last | _] = [Module || #build_module{namespace = Namespace} = Module <- Remaining,
                            not lists:any(fun(#build_module{dependencies = Dependencies}) ->
                                              lists:member(Namespace, Dependencies)
                                          end, Remaining)],
    latest(lists:delete(Last, Remaining), [Last | Placed]).

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

%% report §11.6: --check names a module whose clauses start their bodies in
%% two places, as the layout before the clauses of a construct were laid
%% out alike had them, and ern format lays every body of the construct on
%% the line after its arrow, a block's brace kept on its own
format_check_clauses_test() ->
    Dir = tmp(),
    Before = "fn f(x) =\n    match x {\n        Some(y) -> {\n            let z = y;\n"
             "            z\n        }\n      | None -> 0\n    }\n",
    Module = write(Dir, "clauses.ern", Before),
    ?assertEqual(1, ern_err(["format", "--check", Module])),
    ?assertEqual(Module ++ "\n", binary_to_list(iolist_to_binary(?capturedOutput))),
    ?assertEqual({ok, list_to_binary(Before)}, file:read_file(Module)),
    ?assertEqual(0, ern_err(["format", Module])),
    ?assertEqual({ok, <<"fn f(x) =\n    match x {\n        Some(y) -> {\n            let z = y;\n"
                        "            z\n        }\n      | None ->\n            0\n    }\n">>},
                 file:read_file(Module)),
    ?assertEqual(0, ern_err(["format", "--check", Module])).

%% report §11.6: a module already in the layout is not written back, named
%% alone or under a directory: its file is the one it was, so that a
%% layout of every source writes none it leaves as it was. A regression
%% test, written after the code; a module that does not parse, which is
%% left as it is, is format_test's
format_leaves_a_module_in_the_layout_test() ->
    Dir = tmp(),
    Neat = write(Dir, "neat.ern", "fn g(y) =\n    y\n"),
    {ok, #file_info{inode = Inode}} = file:read_file_info(Neat),
    ?assertEqual(0, ern_err(["format", Neat])),
    ?assertEqual(0, ern_err(["format", Dir])),
    ?assertMatch({ok, #file_info{inode = Inode}}, file:read_file_info(Neat)),
    ?assertEqual({ok, <<"fn g(y) =\n    y\n">>}, file:read_file(Neat)).

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

%% report §11.1: a module whose Erlang name, `ern@` and its path, passes
%% the host's 255 characters is refused at its file. A regression test:
%% the checker refused it at the source's first character, and the
%% emitter had crashed making the name before
module_name_the_host_cannot_hold_test() ->
    Dir = tmp(),
    Relative = lists:duplicate(130, $a) ++ "/" ++ lists:duplicate(130, $b) ++ ".ern",
    File = write(Dir, Relative, "export fn main() : Unit = Unit\n"),
    ?assertEqual(1, ern_err(["build", "--source-root", Dir, File])),
    ?assertMatch({_, _},
                 binary:match(unicode:characters_to_binary(?capturedOutput),
                              list_to_binary(Relative ++ ": the module's Erlang name, `ern@` and"
                                             " its path, is 265 characters long, and the"
                                             " host's names are at most 255"))).

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
                  end, ["build", "doc", "format", "run", "test", "shell", "config", "reload",
                        "stop"]).

%% report §11.6: a file named alone is a module when its name ends in
%% `.ern` and is otherwise one word, and those under a directory are found
%% as `ern build` finds them (§11.1); a file that is none is refused and
%% left as it is. A regression test: `ern format` laid out any file named
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
    %% component
    Refused([Upper], <<"Bad.ern: path component `Bad` must be lowercase">>),
    Refused([Dir ++ "/src"], <<"Sub/ok.ern: path component `Sub` must be lowercase">>),
    [?assertEqual({ok, list_to_binary(Text)}, file:read_file(File))
     || File <- [Notes, Upper, Under]],
    %% a file outside the source root is refused with the option that names
    %% another; a regression test too, the refusal having named no fix
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
    ?assertEqual(1, ern_err(["config", "--config-dir", BuildRoot ++ "/.ernest"])),
    Said(<<"out/.ernest: permission denied">>),
    ok = file:change_mode(BuildRoot, 8#755).

%% report §11, §11.5: a file written whole is written by a rename beside
%% it, so a directory that takes no new file is the refusal's, named with
%% the file, and not the file, which may be writable. A regression test
%% (T6), written after the code: `ern format` named a writable file, and
%% `ern build` a `.erc` that did not exist; it assumes a user the
%% directory's mode binds, which root is not
read_only_directory_test() ->
    Dir = tmp(),
    Closed = filename:join(Dir, "closed"),
    Module = write(Closed, "m.ern", "export fn one() : Int = { 1 }\n"),
    ok = file:change_mode(Closed, 8#555),
    try
        in_directory(Dir, fun() ->
                              ?assertEqual(1, ern_err(["format", "closed/m.ern"])),
                              ?assertEqual(1, build_err(["--source-root", "closed",
                                                         "closed/m.ern"]))
                          end)
    after
        ok = file:change_mode(Closed, 8#755)
    end,
    {ok, <<"export fn one() : Int = { 1 }\n">>} = file:read_file(Module),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, Line))
     || Line <- [<<"ern format: closed: permission denied, and m.ern is written whole by a rename"
                   " there\n">>,
                 <<"ern build: closed: permission denied, and m.erc is written whole by a rename"
                   " there\n">>]].

%% report §11, §11.7: a missing file is refused in one form, `path: no such
%% file`, and an option that names a directory refuses a file, `path: not a
%% directory`. A regression test (T28), written after the code: `ern
%% format` and `ern build` wrote `no such file or directory`, `ern run` `no
%% such file path`, and a file given to --load-path was refused as no
%% directory
missing_paths_test() ->
    Dir = tmp(),
    File = write(Dir, "a.erc", "not a module"),
    ?assertEqual(1, ern_err(["build", Dir ++ "/none.ern"])),
    ?assertEqual(1, ern_err(["format", Dir ++ "/none.ern"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/none.erc"])),
    ?assertEqual(1, ern_err(["doc", Dir ++ "/none.erc"])),
    ?assertEqual(1, ern_err(["run", "--load-path", File, Dir ++ "/none.erc"])),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, list_to_binary(Line)))
     || Line <- ["ern build: " ++ Dir ++ "/none.ern: no such file\n",
                 "ern format: " ++ Dir ++ "/none.ern: no such file\n",
                 "ern run: " ++ Dir ++ "/none.erc: no such file\n",
                 "ern doc: " ++ Dir ++ "/none.erc: no such file\n",
                 "ern run: " ++ File ++ ": not a directory, which --load-path names\n"]].

%% report §11.1, §4.1: a single file's build that uses a module not yet
%% compiled whose source uses it back reports the cycle, as a directory's
%% build does, and not a module to compile first. A regression test (T9),
%% written after the code: each file's build said to compile the other
%% first
single_file_cycle_test() ->
    Dir = tmp(),
    write(Dir, "src/a.ern", "export fn one() : Int = B.two() - 1\n"),
    write(Dir, "src/b.ern", "export fn two() : Int = A.one() + 1\n"),
    ?assertEqual(1, build_err(["--source-root", Dir ++ "/src", Dir ++ "/src/a.ern"])),
    ?assertEqual(1, build_err(["--source-root", Dir ++ "/src", Dir ++ "/src/b.ern"])),
    Said = unicode:characters_to_binary(?capturedOutput),
    ?assertEqual(2, length(binary:matches(Said, <<"ern build: module cycle: A, B\n">>))),
    ?assertEqual(nomatch, binary:match(Said, <<"first">>)).

%% report §11.1, §11.5: a single file's build given no source root, whose
%% module therefore takes the working directory's, helps an unknown
%% qualified name with the source root nearer the file under which its
%% module's source is; given one, it does not. A regression test (T22),
%% written after the code: the error had no help, and only --verbose said
%% the source root
nearer_source_root_test() ->
    Dir = pair(tmp()),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, build_err(["src/main.ern"])),
                          ?assertEqual(1, build_err(["--source-root", ".", "src/main.ern"]))
                      end),
    Said = unicode:characters_to_binary(?capturedOutput),
    Help = <<"this module is Src.Main; --source-root src makes it Main">>,
    ?assertEqual(1, length(binary:matches(Said, Help))),
    ?assertEqual(2, length(binary:matches(Said, <<"unknown name Net.Http.parse">>))).

%% report §11.2: a `.erc` opened as a module keeps §11.1's path shape, which
%% is checked before its path is held to its namespace, and refused as
%% `ern build` refuses a source's. A regression test (T14), written after
%% the code: `ern run Hello.erc` said the file was not at the path of its
%% namespace
run_path_shape_test() ->
    Dir = tmp(),
    write(Dir, "hello.ern", "export fn main() : Unit = Io.println(\"hello\")\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Dir ++ "/hello.ern"])),
    ok = file:rename(Dir ++ "/hello.erc", Dir ++ "/Hello.erc"),
    in_directory(Dir, fun() -> ?assertEqual(1, ern_err(["run", "Hello.erc"])) end),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"ern run: Hello.erc: path component `Hello` must be"
                                        " lowercase\n">>)).

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
    "export fn main() : Unit = Io.println(\"hello, world\")\n".

%% The two-module program of the guide, as sources.
pair(Dir) ->
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = match Net.Http.parse(\"GET /\") {\n"
          "    Some(Net.Http.Request(method = m, path = p)) -> Io.println(m <> \" \" <> p)\n"
          "  | None -> Io.println(\"bad request\")\n"
          "}\n"),
    Dir.

%% A file's last modification, in the host's seconds, and the same set.
modified(File) ->
    {ok, #file_info{mtime = Time}} = file:read_file_info(File, [{time, posix}]),
    Time.

set_modified(File, Time) ->
    ok = file:write_file_info(File, #file_info{mtime = Time, atime = Time}, [{time, posix}]).

%% Run run with libs/markdown's code loaded from a copy in Dir whose time
%% is Time, and then from its build again, so that the code `ern doc --man`
%% lays a page out with has a time of the test's and the tree's file is not
%% touched.
with_markdown_modified(Time, Dir, Run) ->
    {ok, Tree} = ern_code:own_file('ern@markdown'),
    Copy = filename:join(Dir, "markdown.erc"),
    {ok, _} = file:copy(Tree, Copy),
    set_modified(Copy, Time),
    loaded_from(Copy),
    try Run() after loaded_from(Tree) end.

loaded_from(File) ->
    _ = code:purge('ern@markdown'),
    {ok, Beam} = file:read_file(File),
    {module, 'ern@markdown'} = code:load_binary('ern@markdown', File, Beam).

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

%% report §11.1, §8.4, §4.2, §11.5, Appendix E.1: a dependent describes an
%% exported abstract type whose fields name a private type, to print it or
%% check it, through the private types the interface carries, and naming
%% one is refused as private.
%% A regression test: printing an address of `Supervisor.Msg`, whose `Join`
%% names the private `WatcherMsg`, stopped `ern build` with an internal
%% error, and binding one stopped the shell; it does not cover a foreign
%% value checked against such a type, which takes the same descriptor
abstract_private_fields_test() ->
    Dir = tmp(),
    write(Dir, "box.ern", "type Secret = Secret(Int)\n\n"
                          "export abstract type Box = Box(Secret)\n\n"
                          "export fn box(count : Int) : Box = Box(Secret(count))\n"),
    write(Dir, "main.ern",
          "export fn main() : Unit = {\n"
          "    Io.println(Io.show(Box.box(3)));\n"
          "    let group = spawn(Supervisor.group(Supervisor.OneForOne,\n"
          "                                       RestartLimit(restarts = 3, within = 5000)));\n"
          "    Io.println(Io.show(String.startsWith(Io.show(group), \"<address\")))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Dir])),
    ?assertEqual(0, ern_cli:ern(["run", filename:join(Dir, "main.erc")])),
    ?assertEqual(<<"<abstract>\ntrue\n">>, iolist_to_binary(?capturedOutput)),
    Peek = write(Dir, "peek.ern", "export fn peek(secret : Box.Secret) : Int = 0\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, Peek])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"Box.Secret is a type Box keeps private">>)).

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
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(WordCount.size() + Net.HttpClient.port()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(filename:join(Dir, "build/word_count.erc"))),
    ?assert(filelib:is_regular(filename:join(Dir, "build/net/http_client.erc"))),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"82\n">>)),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", Dir ++ "/pages", Dir ++ "/src"])),
    ?assert(filelib:is_regular(filename:join(Dir, "pages/word_count.md"))),
    ?assert(filelib:is_regular(filename:join(Dir, "pages/net/http_client.md"))),
    ?assertEqual("word_count", ern_namespace:module_path(['WordCount'])),
    ?assertEqual('ern@net@http_client', ern_namespace:erlang_module(['Net', 'HttpClient'])).

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
          "export fn main() : Unit =\n"
          "    Io.println(Bool.toString(Maker.make() == Maker.make()))\n"),
    BuildCommand = ["build", "--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(1, ern_err(BuildCommand)),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"`==` is not defined on Boxes.Box">>)),
    write(Dir, "src/main.ern",
          "export fn main() : Unit =\n"
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
    ?assertEqual({ok, "Http"}, ern_namespace:segment("http")),
    ?assertEqual({ok, "V2"}, ern_namespace:segment("v2")),
    ?assertEqual({ok, "HttpServer"}, ern_namespace:segment("http_server")),
    ?assertEqual(error, ern_namespace:segment("Net")),
    ?assertEqual(error, ern_namespace:segment("9x")),
    ?assertEqual(error, ern_namespace:segment("http_2")),
    ?assertEqual({'Some', <<"Http">>}, ern_shell:segment(<<"http">>)),
    ?assertEqual({'Some', <<"OrderedSet">>}, ern_shell:segment(<<"ordered_set">>)),
    ?assertEqual('None', ern_shell:segment(<<"Bad">>)).

%% report §11.1, §11.4: the build's sweep passes over a name under the
%% build root that is not UTF-8, and the host says nothing of it. A
%% regression test: the host printed its own WARNING REPORT during `ern
%% build` and `ern doc`
sweep_passes_over_a_name_not_utf8_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export let u : Int = 1\n"),
    ok = filelib:ensure_path(Dir ++ "/build"),
    ok = file:write_file(<<(list_to_binary(Dir))/binary, "/build/caf", 16#e9, ".erc">>, <<>>),
    Output = os:cmd("../../../bin/ern build --source-root " ++ Dir ++ "/src --build-root "
                    ++ Dir ++ "/build " ++ Dir ++ "/src 2>&1; echo status $?"),
    ?assertEqual("status 0\n", Output).

%% report §11.1: in a directory build, a module whose dependency is
%% refused fails alone, and every other module is compiled and its errors
%% reported. A regression test: a stale `util.erc` that `a.ern` used
%% stopped the build before `y.ern`'s type error was reported
refused_dependency_fails_its_module_alone_test() ->
    Dir = tmp(),
    Util = write(Dir, "src/util.ern", "export let u : Int = 1\n"),
    Build = ["build", "--source-root", Dir ++ "/src", "--build-root", Dir ++ "/build",
             Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(Build)),
    ok = file:delete(Util),
    write(Dir, "src/a.ern", "export let a : Int = Util.u\n"),
    write(Dir, "src/y.ern", "export let y : Int = \"no\"\n"),
    ?assertEqual(1, ern_err(Build)),
    Output = unicode:characters_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"y.ern:1:22: the value does not have the declared"
                                                " type">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern build: no module Util: ">>)).

%% report §11.1, §11.6: in a directory build or format a path that breaks
%% the path shape fails its file alone, named from the working directory,
%% and the other modules are built or laid out. A regression test: the
%% first such path stopped the job, and nothing was compiled or laid out
misnamed_path_fails_its_file_alone_test() ->
    Dir = tmp(),
    write(Dir, "src/Sub/ok.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/Bad.ern", "export fn h() : Int = 3\n"),
    write(Dir, "src/good.ern", "export fn g() : Int = 2\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(Dir ++ "/build/good.erc")),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"src/Bad.ern: path component `Bad`">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"src/Sub/ok.ern: path component `Sub`">>)),
    write(Dir, "loose/Bad.ern", "fn h() = 3\n"),
    Loose = write(Dir, "loose/good.ern", "fn g( x) = x\n"),
    ?assertEqual(1, ern_err(["format", Dir ++ "/loose"])),
    ?assertEqual({ok, <<"fn g(x) =\n    x\n">>}, file:read_file(Loose)).

%% report §11.7: a `--load-path`, `--source-root` or `--config-dir` that
%% names no directory is refused, naming it, and `ern config`'s
%% `--config-dir` names the one it makes. A regression test: each was
%% taken without a word
missing_directory_refused_test() ->
    Dir = tmp(),
    Source = write(Dir, "main.ern", "export fn main() : Unit = Unit\n"),
    Missing = filename:join(Dir, "nowhere"),
    [begin
         ?assertEqual(1, ern_err(Job ++ [Option, Missing] ++ Rest)),
         ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                           list_to_binary(Missing ++ ": no such directory, which "
                                                          ++ Option ++ " names")))
     end || {Job, Option, Rest} <- [{["build"], "--load-path", [Source]},
                                    {["build"], "--source-root", [Source]},
                                    {["run"], "--config-dir", [Source]}]],
    ?assertEqual(0, ern_err(["config", "--config-dir", Missing])),
    ?assert(filelib:is_dir(Missing)).

%% report §11.1: a module left uncompiled because a module it uses failed
%% is said in a line of its own. A regression test: it was passed over in
%% silence, and only the dependency's error was shown
uncompiled_dependent_is_said_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export fn f() : Int = \"x\"\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Util.f()))\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"Main is not compiled, since it uses Util, which"
                                        " failed">>)).

%% report §11: each job's `--help` begins with its synopsis as §11 writes
%% it, and no line of it ends in a space. A regression test: getopt's
%% showed the options' keys as metavariables, `<source_root>`, hid
%% --load-path's repetition, and left a space where it wrapped a line
synopses_are_the_reports_test_() ->
    {ok, Report} = file:read_file("../../../report/toolchain.md"),
    [{Job, fun() ->
                   {Help, 0} = help_of(Job),
                   ?assertEqual([], [Line || Line <- string:split(Help, "\n", all),
                                             lists:suffix(" ", Line)]),
                   [Synopsis | _] = string:split(Help, "\n\n"),
                   "Usage: " ++ Shown = lists:flatten(lists:join(" ", string:lexemes(Synopsis,
                                                                                      " \n"))),
                   ?assertMatch({_, _},
                                binary:match(Report, unicode:characters_to_binary(
                                                       ["`", Shown, "`"])))
           end}
     || Job <- ["build", "doc", "format", "run", "test", "shell", "config", "reload", "stop"]].

%% report §11.1, §11.2, §11.4: `--help` says the source root's default, the
%% working directory or the directory given for `ern build` and `ern doc`,
%% and the working directory for `ern shell`. A regression test, written
%% after the code: the build's and the doc's said none. It does not cover
%% the default itself, which §11.1's tests hold
source_root_default_said_test_() ->
    Root = "the directory whose layout yields namespaces;"
        " default: the working directory, or src-dir",
    [{Job, fun() ->
                   {Help, 0} = help_of(Job),
                   Words = lists:flatten(lists:join(" ", string:lexemes(Help, " \n"))),
                   ?assertNotEqual(nomatch, string:find(Words, "--source-root " ++ Said))
           end}
     || {Job, Said} <- [{"build", Root}, {"doc", Root},
                        {"shell", "where the shell finds a module's source;"
                                  " default: the working directory"}]].

%% A job's help as it prints it, and its status.
help_of(Job) ->
    Self = self(),
    Leader = spawn(fun() -> capture(Self, []) end),
    Previous = group_leader(),
    group_leader(Leader, self()),
    Status = try ern_cli:ern([Job, "--help"]) after group_leader(Previous, self()) end,
    Leader ! {done, self()},
    receive {captured, Text} -> {Text, Status} end.

capture(Owner, Acc) ->
    receive
        {io_request, From, ReplyAs, {put_chars, Encoding, Chars}} ->
            From ! {io_reply, ReplyAs, ok},
            capture(Owner, [unicode:characters_to_list(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, {put_chars, Encoding, Module, Function, Args}} ->
            From ! {io_reply, ReplyAs, ok},
            Chars = apply(Module, Function, Args),
            capture(Owner, [unicode:characters_to_list(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, request}},
            capture(Owner, Acc);
        {done, Owner} ->
            Owner ! {captured, lists:flatten(lists:reverse(Acc))}
    end.

%% report §11.1, §11.2: `ern run` checks a module against the installed
%% standard library whatever the working directory, the library's own
%% source root among them. A regression test: run from `src/stdlib/`, every
%% program was refused as compiled against another standard library
run_in_the_stdlib_root_test() ->
    Dir = tmp(),
    File = write(Dir, "hello.ern", hello()),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd("../../../src/stdlib"),
    try
        ?assertEqual(0, ern_err(["run", filename:join(Dir, "hello.erc")]))
    after
        file:set_cwd(Cwd)
    end,
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"hello, world">>)).

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

%% report §11.2: `ern run` given a module's source says to build it first,
%% and given any other file that is no `.erc` says only that. A regression
%% test: the source was refused without the step that was missing
run_a_source_test() ->
    Dir = tmp(),
    Source = write(Dir, "greet.ern", hello()),
    Notes = write(Dir, "notes.txt", "x\n"),
    ?assertEqual(1, ern_err(["run", Source])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      iolist_to_binary([" does not end in .erc; build it first:"
                                                        " ern build ", Source]))),
    ?assertEqual(1, ern_err(["run", Notes])),
    ?assertEqual(nomatch, binary:match(unicode:characters_to_binary(?capturedOutput),
                                       <<"notes.txt does not end in .erc; build">>)).

%% report §11.1: in single-file mode without --source-root a file's
%% namespace is its path from the current directory; a directory of it
%% that breaks the path shape is refused with the source root that leaves
%% it out of the namespace, the deepest such, by `ern build` and `ern doc`
%% alike, and the file's own name with none. A regression test: the
%% refusal named no root
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
          "export fn main() : Unit = Io.println(Int.toString(twice(21)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--load-path", Dir ++ "/beams", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2, §8.4: `--libs-dir dir` adds the `ebin` directory of each
%% application under `dir`, one named `name-version` and one `name`, so
%% that a `foreign fn` finds its module there, under `ern run` and under
%% `ern test`; a directory with no `ebin` and a file beside them add
%% nothing. Each job is given a directory of its own, since the jobs here
%% share one host's code path. The shell's is ern_shell_tests'
%% libs_dir_in_the_shell. Written after the code, so a regression test.
%% Not covered: a node's `--libs-dir`, a bare node's among them, which
%% takes the load path a program's run takes
libs_dir_test() ->
    Dir = tmp(),
    Libs = Dir ++ "/lib",
    compiled_erlang(Libs ++ "/helper-1.0/ebin", "ern_cli_libs_helper", "twice/1",
                    "twice(N) -> 2 * N."),
    compiled_erlang(Libs ++ "/other/ebin", "ern_cli_libs_other", "three/0", "three() -> 3."),
    ok = filelib:ensure_path(Libs ++ "/notes"),
    write(Libs, "README", "no application\n"),
    write(Dir, "src/main.ern",
          "foreign fn twice(n : Int) : Int = \"ern_cli_libs_helper:twice/1\"\n"
          "foreign fn three() : Int = \"ern_cli_libs_other:three/0\"\n"
          "export fn main() : Unit = Io.println(Int.toString(twice(three() * 7)))\n"),
    Tested = Dir ++ "/tested",
    compiled_erlang(Tested ++ "/checks-0.2.1/ebin", "ern_cli_libs_checks", "four/0",
                    "four() -> 4."),
    write(Dir, "src/checked.ern",
          "foreign fn four() : Int = \"ern_cli_libs_checks:four/0\"\n\n"
          "let found : Test.Case(Never) =\n"
          "    Test.Case(name = \"found\", run = fn() = Test.equal(four(), 4))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["run", "--libs-dir", Libs, Dir ++ "/build/main.erc"])),
    ?assertEqual(0, ern_err(["test", "--libs-dir", Tested, Dir ++ "/build/checked.erc"])),
    ?assertEqual(<<"42\nfound: passed\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual([Libs ++ "/helper-1.0/ebin", Libs ++ "/other/ebin" | ern_tree:libraries()],
                 ern_build:load_path([{libs_dir, Libs}])).

%% report §11.1, §11.2, Appendix G: the build of each library of the
%% toolchain's own ends the load path, so that a program using
%% `Markdown`, which uses `Ansi`, is built, run and tested with no
%% `--load-path`, and `--verbose` says where each was read from, as from
%% any root. Written after the code, so a regression test; the shell's is
%% ern_shell_tests' libraries_in_the_shell, and a bare node's load path is
%% not covered, which is the same function's
libraries_on_load_path_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(List.size(Markdown.parse(\"# Title\\n\\nText.\\n\"))))\n"),
    write(Dir, "src/checked.ern",
          "let parsed : Test.Case(Never) =\n"
          "    Test.Case(name = \"parsed\",\n"
          "              run = fn() = Test.equal(List.size(Markdown.parse(\"# Title\\n\")), 1))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(0, ern_err(["test", Dir ++ "/build/checked.erc"])),
    ?assertEqual(<<"2\nparsed: passed\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(0, build_err(["--verbose", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, list_to_binary(["read ", Name, " from ",
                                                              ern_build:shown(File), "\n"])))
     || {Name, File} <- [{"Markdown", ern_tree:build("libs/markdown/markdown.erc")},
                         {"Ansi", ern_tree:build("libs/ansi/ansi.erc")}]].

%% report §11.1, §11.2: a program's own module of a library's name, at its
%% root, is found before the toolchain's library, whose build ends the load
%% path: `Json.parse` is the program's, which answers an `Int`, and not
%% the library's, which answers an `Either`. Written after the code, so a
%% regression test
own_module_before_library_test() ->
    Dir = tmp(),
    write(Dir, "src/json.ern", "export fn parse(text : String) : Int = String.size(text)\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Json.parse(\"seven\")))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"5\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: two directories of one application's name under a
%% `--libs-dir` are refused, naming them, and nothing runs: `foo-1.0`
%% beside `foo-1.1`, and `foo` beside `foo-1.0`, a directory without a
%% version being of the name it has; `foo-bar` beside `foo` is two
%% applications, since `bar` is no version. Three of one name are named
%% all, and an application's name that is not UTF-8 is refused as a
%% module's is. Written after the code, so a regression test
libs_dir_one_of_each_name_test() ->
    Dir = tmp(),
    Main = write(Dir, "main.ern", "export fn main() : Unit = Io.println(\"ran\")\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Main])),
    Run = fun(Applications) ->
                  Libs = tmp(),
                  [ok = filelib:ensure_path(filename:join([Libs, Application, "ebin"]))
                   || Application <- Applications],
                  {ern_err(["run", "--libs-dir", Libs, Dir ++ "/main.erc"]), Libs}
          end,
    {1, Versions} = Run(["foo-1.1", "foo-1.0"]),
    {1, Bare} = Run(["foo-1.0", "foo"]),
    {1, Three} = Run(["foo-2", "foo", "foo-1.0.3"]),
    {1, Undecoded} = Run([<<"f", 16#FF, "o">>]),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, list_to_binary(
                                                Versions ++ " holds more than one directory of the"
                                                " application foo, foo-1.0 and foo-1.1, which"
                                                " --libs-dir names\n"))),
    ?assertMatch({_, _}, binary:match(Output, list_to_binary(
                                                Bare ++ " holds more than one directory of the"
                                                " application foo, foo and foo-1.0, which"
                                                " --libs-dir names\n"))),
    ?assertMatch({_, _}, binary:match(Output, list_to_binary(
                                                Three ++ " holds more than one directory of the"
                                                " application foo, foo, foo-1.0.3 and foo-2,"
                                                " which --libs-dir names\n"))),
    ?assertMatch({_, _}, binary:match(Output, list_to_binary(
                                                "a name that is not UTF-8: " ++ Undecoded
                                                ++ "/f\\xFFo\n"))),
    ?assertEqual(nomatch, binary:match(Output, <<"ran\n">>)),
    ?assertMatch({0, _}, Run(["foo", "foo-bar"])),
    ?assertEqual(1, length(binary:matches(iolist_to_binary(?capturedOutput), <<"ran\n">>))).

%% report §11.2: the directories `--load-path` and `--libs-dir` add stand in
%% the load path in the order the options are given, so that of two
%% modules of the host's of one name, the first option's is called.
%% Written after the code, so a regression test
libs_dir_in_order_test() ->
    Dir = tmp(),
    [begin
         compiled_erlang(Dir ++ "/" ++ Module ++ "/beams", Module, "which/0", "which() -> 1."),
         compiled_erlang(Dir ++ "/" ++ Module ++ "/lib/" ++ Module ++ "/ebin", Module, "which/0",
                         "which() -> 2."),
         write(Dir, "src/" ++ Module ++ ".ern",
               ["foreign fn which() : Int = \"", Module, ":which/0\"\n"
                "export fn main() : Unit = Io.println(Int.toString(which()))\n"])
     end || Module <- ["ern_cli_first", "ern_cli_second"]],
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--load-path", Dir ++ "/ern_cli_first/beams",
                                 "--libs-dir", Dir ++ "/ern_cli_first/lib",
                                 Dir ++ "/build/ern_cli_first.erc"])),
    ?assertEqual(0, ern_cli:ern(["run", "--libs-dir", Dir ++ "/ern_cli_second/lib",
                                 "--load-path", Dir ++ "/ern_cli_second/beams",
                                 Dir ++ "/build/ern_cli_second.erc"])),
    ?assertEqual(<<"1\n2\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.7: `--libs-dir` names a directory that is there, is given
%% once, and is an option of `ern run`, `ern test` and `ern shell` alone.
%% Written after the code, so a regression test
libs_dir_refused_test() ->
    Dir = tmp(),
    Missing = filename:join(Dir, "nowhere"),
    Refused = [{["run", "--libs-dir", Missing, "x.erc"],
                list_to_binary("ern run: " ++ Missing ++ ": no such directory, which --libs-dir"
                               " names")},
               {["test", "--libs-dir", Dir, "--libs-dir", Dir, "x.erc"],
                <<"ern test: --libs-dir is given more than once">>},
               {["build", "--libs-dir", Dir, "src"],
                <<"ern build: --libs-dir is not an option of ern build; ern run, ern test and"
                  " ern shell take it">>},
               {["doc", "--libs-dir", Dir, "src"],
                <<"ern doc: --libs-dir is not an option of ern doc; ern run, ern test and ern"
                  " shell take it">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% A module of the host's, its one function exported and given as its
%% text, compiled into the directory Ebin.
compiled_erlang(Ebin, Module, Export, Function) ->
    Source = write(tmp(), Module ++ ".erl",
                   ["-module(", Module, ").\n-export([", Export, "]).\n", Function, "\n"]),
    ok = filelib:ensure_path(Ebin),
    {ok, _} = compile:file(Source, [{outdir, Ebin}]),
    ok.

%% report §11.1: without the root that holds a module's dependency, the
%% dependency is an unknown name: a module of no library's name, since the
%% build of each library of the toolchain's own ends the load path
load_path_needed_test() ->
    Dir = tmp(),
    write(Dir, "lib/tally.ern", "export fn one() : Int = 1\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Tally.one()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build/lib", Dir ++ "/lib"])),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build/src", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"unknown name Tally.one">>)).

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
          "export fn main() : Unit = {\n"
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
          "export fn main() : Unit = {\n"
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
          "export fn main() : Unit = Io.println(Io.show(Lib.Stack.one))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"<abstract>\n">>, iolist_to_binary(?capturedOutput)),
    Refused = tmp(),
    write(Refused, "src/lib/stack.ern", Stack),
    write(Refused, "src/main.ern",
          "fn shown(x : a) : String = Io.show(x)\n\n"
          "export fn main() : Unit = Io.println(shown(Lib.Stack.one))\n"),
    ?assertEqual(1, build_err(["--build-root", Refused ++ "/build", Refused ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "Io.show needs a.show, which shown does not declare")).

%% report Appendix E.1, §3.8: a value of a foreign type is shown as
%% `<foreign>`, `Foreign.Term` and a type a module declares alike, inside
%% another value too. A regression test: it was shown by its representation
%% after the rule of 2026-10-01 had said otherwise
foreign_shown_as_foreign_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "foreign type Handle\n\n"
          "foreign fn handle() : Handle = \"erlang:self/0\"\n\n"
          "export fn main() : Unit =\n"
          "    Io.println(Io.show(#(Foreign.term(1), [Foreign.atom(\"a\")], handle())))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"#(<foreign>, [<foreign>], <foreign>)\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §4.2: `T.name` is the module's own member where its type `T`
%% declares one of that name, and the module T's `name` otherwise. A
%% regression test: the build left module T out wherever the module
%% declared a type T, and `Stack.other` was an unknown name
type_name_shares_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/stack.ern", "export fn other() : Int = 7\n"),
    write(Dir, "src/main.ern",
          "type Stack = Stack(List(Int))\n\n"
          "fn Stack.negate(s : Stack) : Int = match s { Stack(xs) -> List.size(xs) }\n\n"
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(Stack.other() + Stack.negate(Stack([1]))))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"8\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2, §11.1: a module may not take a prelude namespace, and the
%% file that does fails alone: main.ern, which names the standard
%% library's `Io`, is built
prelude_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/io.ern", "export fn println(s : String) : Unit = Unit\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertNot(filelib:is_regular(Dir ++ "/build/io.erc")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    %% nor the name of the prelude itself, which `Prelude.X` reaches
    PreludeDir = tmp(),
    write(PreludeDir, "src/prelude.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(1, build_err(["--build-root", PreludeDir ++ "/build", PreludeDir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"takes the prelude namespace Prelude">>)).

%% report §4.2, Appendix E.27: the refusal names whose namespace a file at
%% the source root takes: `Address`, a prelude type with members, is the
%% prelude's, `Io`, `Test` and `Peer` the standard library's. A
%% regression test, written after the code; it does not cover a namespace
%% that both take, such as `Int`, which is named as the prelude's.
taken_namespace_names_owner_test() ->
    lists:foreach(
      fun(File) ->
          Dir = tmp(),
          write(Dir, "src/" ++ File, "export fn f() : Int = 1\n"),
          ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"]))
      end, ["address.ern", "io.ern", "test.ern", "peer.ern"]),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _},
                 binary:match(Output, <<"address.ern takes the prelude namespace Address">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"io.ern takes the standard library namespace Io">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"test.ern takes the standard library namespace Test">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"peer.ern takes the standard library namespace Peer">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"prelude namespace Io">>)),
    %% report §9.7: the prelude binds no system reference, so `Sys` is free
    Dir = tmp(),
    write(Dir, "src/sys.ern", "export fn f() : Int = 1\n"),
    ?assertEqual(0, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: a module may not stand under a taken namespace, the
%% standard library's or the prelude's, and the file that does fails alone;
%% a prelude type without members takes no namespace, so a module may stand
%% under it, `down/x.ern`, and a third module reaches it. A regression test,
%% written after the code: `fs/entry.ern` built as `Fs.Entry`, which no
%% module reached; it does not cover the shell's load of such a file, which
%% reads its namespace by the same function
module_under_taken_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/fs/entry.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/int/parse.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/down/x.ern", "export fn f() : Int = 42\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Down.X.f()))\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"fs/entry.ern stands under the standard library"
                                                " namespace Fs\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"int/parse.ern stands under the prelude"
                                                " namespace Int\n">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/fs/entry.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/int/parse.erc")),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"\n42\n">>)),
    %% a file built alone is refused the same way
    ?assertEqual(1, build_err(["--source-root", Dir ++ "/src", "--build-root", Dir ++ "/alone",
                               Dir ++ "/src/fs/entry.ern"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"fs/entry.ern stands under the standard library"
                                        " namespace Fs\n">>)).

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
          "export fn main() : Unit = {\n"
          "    let me = Process.current();\n"
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
          "export fn main() : Unit receiving String = {\n"
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

%% The parent of the tests below: `main.ern` exports `Stack`, whose member
%% `Stack.compare` its namespace shares with the module `main/stack.ern`.
stack_parent() ->
    "export type Stack = Stack(items : List(Int))\n"
    "\n"
    "export fn Stack.compare(left : Stack, right : Stack) : Ordering =\n"
    "    Int.compare(List.size(left.items), List.size(right.items))\n"
    "\n"
    "export fn empty() : Stack = Stack(items = [])\n".

%% report §4.2, §11.5: the module of a type's name shares the type's
%% namespace, and a third module reaches the member and the module's
%% functions by one prefix, `Main.Stack.compare` the member and
%% `Main.Stack.push` the module's. A regression test, written after the
%% code: the checker took `Main.Stack.push` for a member, which worked by
%% accident; it does not cover a member of a private type
shared_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", stack_parent()),
    write(Dir, "src/main/stack.ern",
          "export fn push(stack : Main.Stack, item : Int) : Main.Stack =\n"
          "    Main.Stack(items = item :: stack.items)\n"
          "\n"
          "export fn size(stack : Main.Stack) : Int = List.size(stack.items)\n"),
    write(Dir, "src/user.ern",
          "export fn main() : Unit = {\n"
          "    let one = Main.Stack.push(Main.empty(), 1);\n"
          "    let two = Main.Stack.push(one, 2);\n"
          "    Io.println(Io.show(Main.Stack.compare(one, two)));\n"
          "    Io.println(Io.show(two));\n"
          "    Io.println(Int.toString(Main.Stack.size(two)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/user.erc"])),
    ?assertEqual(<<"Less\nStack(items = [2, 1])\n2\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §4.2, §11.1: a module that names a member of a type through the
%% type's namespace depends on the module that declares the type, though
%% the module of the type's name exists and uses nothing of it. A
%% regression test, written after the code: the build took the module of
%% the name for the dependency, and the member was unknown
member_reached_through_its_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", stack_parent()),
    write(Dir, "src/main/stack.ern", "export fn one() : Int = 1\n"),
    write(Dir, "src/user.ern",
          "export fn main() : Unit = {\n"
          "    let compare = Main.Stack.compare;\n"
          "    let _ = compare;\n"
          "    Io.println(Int.toString(Main.Stack.one()))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/user.erc"])),
    ?assertEqual(<<"1\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module calls the module of its own type's name by the
%% qualified name the two share, `Epx.Window.open` in `epx.ern` beside its
%% private type `Window`, which has no member `open`. A regression test,
%% written after the code: the checker took the function for the type's
%% member, and the compiler crashed
parent_calls_its_child_test() ->
    Dir = tmp(),
    write(Dir, "src/epx.ern",
          "type Window = Window(id : Int)\n"
          "\n"
          "export fn main() : Unit = {\n"
          "    let window = Window(id = Epx.Window.open());\n"
          "    Io.println(Io.show(window))\n"
          "}\n"),
    write(Dir, "src/epx/window.ern", "export fn open() : Int = 42\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/epx.erc"])),
    ?assertEqual(<<"Window(id = 42)\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2, §11.5: a value the module of a type's name exports under
%% the name of a member of the exported type, a function or a top-level
%% `let`, is an error at the value's declaration, naming the type and its
%% module, in directory mode, where the parent is the build's, and in
%% single-file mode, the parent compiled from another source root and on
%% the load path; the parent is built. A regression test, written after the
%% code: the `let` built, and `Main.Stack.compare` was the member, and the
%% single-file build was refused for its parent's source, moved away, while
%% the test found the message the directory's build had printed; it does
%% not cover a `foreign fn`
member_clash_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", stack_parent()),
    Child = "export fn push(stack : Main.Stack, item : Int) : Main.Stack =\n"
            "    Main.Stack(items = item :: stack.items)\n"
            "\n",
    Function = Child ++ "export fn compare(left : Int, right : Int) : Ordering =\n"
                        "    Int.compare(left, right)\n",
    write(Dir, "src/main/stack.ern", Function),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Message = <<"main/stack.ern:4:8: Main.Stack.compare is a member of the type Stack in the"
                " module Main\n">>,
    ?assertMatch([_], binary:matches(iolist_to_binary(?capturedOutput), Message)),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    Alone = tmp(),
    write(Alone, "src/main/stack.ern", Function),
    ?assertEqual(1, build_err(["--source-root", Alone ++ "/src", "--build-root", Alone ++ "/build",
                               "--load-path", Dir ++ "/build", Alone ++ "/src/main/stack.ern"])),
    ?assertMatch([_, _], binary:matches(iolist_to_binary(?capturedOutput), Message)),
    write(Dir, "src/main/stack.ern", Child ++ "export let compare = 5\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch([_, _, _], binary:matches(Output, Message)),
    ?assertMatch({_, _}, binary:match(Output, <<"4 | export let compare = 5\n">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main/stack.erc")).

%% report §4.9, §11.5: a call of a function of the module of a type's name
%% whose requirement the caller does not declare names the function as a
%% module's is named, `least`, and not as the type's member. A regression
%% test, written after the code: the checker took it for a member, and
%% would have named it `Stack.least`
shared_namespace_requirement_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", stack_parent()),
    write(Dir, "src/main/stack.ern",
          "export fn least(left : a, right : a) : a needs a.compare =\n"
          "    if left < right then left else right\n"),
    write(Dir, "src/user.ern",
          "fn f(left : b, right : b) : b = Main.Stack.least(left, right)\n" ++ hello()),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"user.ern:1:33: least needs b.compare, which f does not"
                                        " declare\n">>)).

%% report §4.2: a module under the parent's namespace is reached from the
%% parent by its whole qualified name, its functions, its types, and its
%% constructors alike
nested_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main/stack.ern",
          "export type Item = Item(Int)\n"
          "export fn push(i : Item) : Int = match i { Item(n) -> n + 1 }\n"),
    write(Dir, "src/main.ern",
          "fn count(i : Main.Stack.Item) : Int = Main.Stack.push(i)\n"
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(count(Main.Stack.Item(1))))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"2\n">>, iolist_to_binary(?capturedOutput)).

%% report §8.6, §7.4, §11.2: ern reports a deadlock as the entry process's
%% fault and exits 1
deadlock_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "type Msg = Ping\nexport fn main() : Unit receiving Msg = receive { Ping -> Unit }\n"),
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
          "export fn main() : Unit = Io.println(Int.toString(\n"
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
                               "export fn main() : Unit ="
                               " Io.println(Int.toString(f()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: the standard library's own source root may take prelude
%% namespaces, and no other root may. A build of the whole library, so the
%% time stdlib_build_sets_its_copy_aside_test_ has
stdlib_root_test_() ->
    {timeout, 60, fun stdlib_root/0}.

stdlib_root() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", "../../../src/stdlib"])),
    ?assert(filelib:is_regular(Dir ++ "/build/bool.erc")),
    write(Dir, "src/bool.ern", "export fn not(b : Bool) : Bool = b\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/b2", Dir ++ "/src"])).

%% report §4.2, §11.1: a file under the standard library's source root is
%% compiled with that root, the default for it; another root is an error
stdlib_file_takes_its_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir,
                                 "../../../src/stdlib/optional.ern"])),
    %% report §11.1: and builds into build/stdlib, where its dependencies are
    ?assertEqual(0, ern_cli:ern(["doc", "../../../src/stdlib/float.ern"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "# Ernest module Float")),
    ?assert(filelib:is_regular(Dir ++ "/optional.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", "../../..", "--build-root", Dir,
                                 "../../../src/stdlib/optional.ern"])).

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

%% report §8.6, §11.2, Appendix E.23: under `ern test` a program is told of
%% its end as one `ern run` runs is: a subscriber a test spawned is told
%% once the tests have run, and the run ends once it has answered. Written
%% after the code (MVP 3.1's item 6)
test_told_of_the_end_test() ->
    Dir = tmp(),
    File = write(Dir, "told.ern",
                 "type Msg = Terminating(Reply(Unit))\n"
                 "fn keeper() : Unit receiving Msg = {\n"
                 "    Os.termination(Terminating);\n"
                 "    receive {\n"
                 "        Terminating(reply) -> { Io.println(\"told\"); answer(reply, Unit) }\n"
                 "    }\n"
                 "}\n"
                 "let started = Test.Case(name = \"started\", run = fn() = {\n"
                 "    let _ = spawn(keeper);\n"
                 "    Test.Passed\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    %% standard error is the test's too, where the end's lines go
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "told.erc")], group_leader())),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Line))
     || Line <- [<<"started: passed\n">>, <<"told\n">>,
                 <<"the end waits for 1 subscriber: Told.started:9\n">>,
                 <<"the subscriber Told.started:9 answered\n">>]].

%% report Appendix E.24, §11.2: a test runs in a process whose mailbox type
%% is its own, so one may receive what a process it spawned sends it.
%% Written after the code
test_receives_test() ->
    Dir = tmp(),
    File = write(Dir, "waits.ern",
                 "type Go = Go\n"
                 "let waits = Test.Case(name = \"waits\", run = fn() = {\n"
                 "    let me = self();\n"
                 "    let _ = spawn(fn() = send(me, Go));\n"
                 "    receive { Go -> Test.Passed }\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "waits.erc")])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({match, _}, re:run(Output, "waits: passed\n")).

%% report Appendix E.24, §11.2: ern test runs every top-level let of type Test.Case,
%% exported or not, each in its own process, reports each, and exits 1
%% unless every one passed; a test's own fault is its line, its trace
%% beneath it, four spaces in, the test's lambda's frame by its
%% definition's name and its line (Appendix E.21), a regression test of
%% the trace, written after the code, where the line came alone
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
    ?assertMatch({match, _}, re:run(Output, "divides: faulted: division by zero\n"
                                            "    erlang:'div'/2\n    Checks.divides:7\n")),
    write(Dir, "src2/ok.ern",
          "let fine = Test.Case(name = \"fine\", run = fn() = Test.Passed)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build2", Dir ++ "/src2"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build2/ok.erc"])).

%% report §11.2, Appendix E.0 shape rule 6: `ern test` runs the module's
%% doc examples after its tests, each a case named by the declaration it
%% documents and its number among that declaration's, the module's own by
%% the module's name: one whose `// => v` holds passes, one whose value
%% shows otherwise fails with `expected v, got w`, and one that does not
%% compile fails with the diagnostic's message; the status is 1. A module
%% whose examples all hold passes, status 0. A regression test, written
%% after the code; it does not cover an example of a constructor or a
%% field, which counts as its type's, nor a run on a node
doc_examples_run_test() ->
    Dir = tmp(),
    Documented = fun(Shown) ->
                     "/// Adds one.\n"
                     "///\n"
                     "/// ```ernest\n"
                     "/// Adds.f(1)\n"
                     "/// // => 2\n"
                     "/// ```\n"
                     "\n"
                     "/// One more than `n`.\n"
                     "///\n"
                     "/// ```ernest\n"
                     "/// Adds.f(3)\n"
                     "/// // => " ++ Shown ++ "\n"
                     "/// ```\n"
                     "///\n"
                     "/// ```ernest\n"
                     "/// Adds.twice(3)\n"
                     "/// ```\n"
                     "export fn f(n : Int) : Int = n + 1\n"
                 end,
    write(Dir, "src/adds.ern",
          Documented("3") ++
          "\n"
          "let one = Test.Case(name = \"one\", run = fn() = Test.equal(f(0), 1))\n"
          "\n"
          "let two = Test.Case(name = \"two\", run = fn() = Test.equal(f(1), 2))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/adds.erc"])),
    ?assertEqual(<<"one: passed\n"
                   "two: passed\n"
                   "Adds example 1: passed\n"
                   "Adds.f example 1: failed: expected 3, got 4\n"
                   "Adds.f example 2: failed: unknown name Adds.twice\n">>,
                 iolist_to_binary(?capturedOutput)),
    write(Dir, "held/adds.ern",
          [lists:flatten(string:replace(Documented("4"), "Adds.twice(3)", "Adds.f(3) + 1"))]),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/held_build", Dir ++ "/held"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/held_build/adds.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"Adds.f example 2: compiled\n">>)).

%% report §11.2: over a directory, each module's examples run after its
%% tests under the module's name, a module with examples and no test among
%% them, and a module with neither is passed over. A regression test,
%% written after the code
doc_examples_of_a_directory_test() ->
    Dir = tmp(),
    write(Dir, "src/a.ern",
          "/// One.\n"
          "///\n"
          "/// ```ernest\n"
          "/// A.one()\n"
          "/// // => 1\n"
          "/// ```\n"
          "export fn one() : Int = 1\n"
          "\n"
          "let ones = Test.Case(name = \"ones\", run = fn() = Test.equal(one(), 1))\n"),
    write(Dir, "src/b.ern",
          "/// Two.\n"
          "///\n"
          "/// ```ernest\n"
          "/// B.two()\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn two() : Int = 2\n"),
    write(Dir, "src/c.ern", "export fn three() : Int = 3\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build"])),
    ?assertEqual(<<"A\nones: passed\nA.one example 1: passed\nB\nB.two example 1: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2: each doc example runs in an empty directory of its own,
%% made for it under the directory for temporary files and removed after
%% it, whether it passed, failed or faulted, and the module's tests run in
%% the working directory: an example that makes a file passes again on a
%% second run in the same directory, a second example does not find the
%% first's file, the working directory holds no example's file after the
%% runs, and the directory for temporary files holds none of theirs. A
%% regression test, written after the code; it does not cover a run on a
%% node
doc_example_directory_test() ->
    Dir = tmp(),
    write(Dir, "src/notes.ern",
          "/// Makes `note.txt` where it runs, which holds nothing before it.\n"
          "///\n"
          "/// ```ernest\n"
          "/// #(Fs.list(Path(\".\"), 5000), Notes.note())\n"
          "/// // => #(Right([]), Right(Unit))\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Fs.stat(Path(\"note.txt\"), 5000)\n"
          "/// // => Left(NotFound)\n"
          "/// ```\n"
          "export fn note() : Either(Io.Error, Unit) =\n"
          "    Fs.makeFile(Path(\"note.txt\"), String.toUtf8(\"note\"), 5000)\n"
          "\n"
          "let here = Test.Case(name = \"here\", run = fn() =\n"
          "    Test.equal(Fs.read(Path(\"marker.txt\"), 5000), Right(String.toUtf8(\"here\"))))\n"),
    write(Dir, "src/faulty.ern",
          "/// Makes `left.txt` where it runs.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Faulty.leave()\n"
          "/// // => Left(Exists)\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// let _ = Faulty.leave();\n"
          "/// Faulty.divide(1, 0)\n"
          "/// // => 0\n"
          "/// ```\n"
          "export fn leave() : Either(Io.Error, Unit) =\n"
          "    Fs.makeFile(Path(\"left.txt\"), String.toUtf8(\"left\"), 5000)\n"
          "\n"
          "/// `n` over `d`.\n"
          "export fn divide(n : Int, d : Int) : Int = n / d\n"),
    write(Dir, "marker.txt", "here"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Temporary = filename:join(Dir, "temporary"),
    ok = file:make_dir(Temporary),
    Given = os:getenv("TMPDIR"),
    true = os:putenv("TMPDIR", Temporary),
    try
        in_directory(Dir, fun() ->
                              ?assertEqual(0, ern_cli:ern(["test", "build/notes.erc"])),
                              ?assertEqual(0, ern_cli:ern(["test", "build/notes.erc"])),
                              ?assertEqual(1, ern_cli:ern(["test", "build/faulty.erc"]))
                          end)
    after
        case Given of
            false -> os:unsetenv("TMPDIR");
            _ -> os:putenv("TMPDIR", Given)
        end
    end,
    Output = iolist_to_binary(?capturedOutput),
    Notes = <<"here: passed\nNotes.note example 1: passed\nNotes.note example 2: passed\n">>,
    ?assertMatch([_, _], binary:matches(Output, Notes)),
    ?assertMatch({_, _}, binary:match(Output, <<"Faulty.leave example 1: failed: expected"
                                                " Left(Exists), got Right(Unit)\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Faulty.leave example 2: faulted: division by"
                                                " zero\n">>)),
    {ok, Left} = file:list_dir(Dir),
    ?assertEqual(["build", "marker.txt", "src", "temporary"], lists:sort(Left)),
    ?assertEqual({ok, []}, file:list_dir(Temporary)).

%% report §11.2: each doc example's directory, made under the directory for
%% temporary files, which other users share, is its owner's alone, mode
%% 0700, whatever the umask, as the configuration directory `ern config`
%% makes is, so that no other user can put a link where the example writes.
%% A regression test, written after the code: the directory took the
%% umask's mode; it does not cover a directory another user writes to as
%% it is made, which a test cannot time, and assumes a umask that leaves
%% the group or others some right, as 002 and 022 do
doc_example_directory_mode_test() ->
    Temporary = filename:join(tmp(), "temporary"),
    ok = file:make_dir(Temporary),
    Given = os:getenv("TMPDIR"),
    Example = #example{test_case = {'Case', <<"Modes example 1">>, fun() -> 'Passed' end},
                       frames = fun(Trace) -> Trace end},
    ModeOf = fun(_) ->
                 {ok, Working} = file:get_cwd(),
                 {ok, #file_info{mode = Mode}} = file:read_file_info(Working),
                 {Working, Mode band 8#777}
             end,
    try
        true = os:putenv("TMPDIR", Temporary),
        {Working, Mode} = ern_examples:in_directory(Example, ModeOf, standard_error),
        ?assertEqual(8#700, Mode),
        ?assertEqual(Temporary, filename:dirname(Working)),
        ?assertEqual({ok, []}, file:list_dir(Temporary))
    after
        case Given of
            false -> os:unsetenv("TMPDIR");
            _ -> os:putenv("TMPDIR", Given)
        end
    end.

%% report §11.2: a private declaration's doc example is compiled inside its
%% module, where it names the module's private function and type plain,
%% and an exported declaration's in a module of its own, where a private
%% name is unknown; inside, the module's source is the one its `.erc` was
%% compiled from, and an example whose source has changed since, or is gone,
%% fails saying so; the units it was compiled in go with the run. A
%% regression test, written after the code: a private declaration's example
%% failed with `unknown name`; it does not cover a private member's or a
%% field's example, and a module whose initializers act is
%% doc_example_initializers_test's
private_doc_example_test() ->
    Dir = tmp(),
    Source = "/// A number held.\n"
             "///\n"
             "/// ```ernest\n"
             "/// Box(twice(3))\n"
             "/// // => Box(6)\n"
             "/// ```\n"
             "type Box = Box(Int)\n"
             "\n"
             "/// Twice `n`.\n"
             "///\n"
             "/// ```ernest\n"
             "/// twice(2)\n"
             "/// // => 4\n"
             "/// ```\n"
             "fn twice(n : Int) : Int = n * 2\n"
             "\n"
             "/// Four times `n`.\n"
             "///\n"
             "/// ```ernest\n"
             "/// Doubles.quadruple(1)\n"
             "/// // => 4\n"
             "/// ```\n"
             "///\n"
             "/// ```ernest\n"
             "/// twice(1)\n"
             "/// // => 2\n"
             "/// ```\n"
             "export fn quadruple(n : Int) : Int = twice(twice(n))\n"
             "\n"
             "let quadrupled = Test.Case(name = \"quadrupled\", run = fn() =\n"
             "    Test.equal(quadruple(2), 8))\n",
    write(Dir, "src/doubles.ern", Source),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/doubles.erc"])),
    ?assertEqual(<<"quadrupled: passed\n"
                   "Doubles.Box example 1: passed\n"
                   "Doubles.twice example 1: passed\n"
                   "Doubles.quadruple example 1: passed\n"
                   "Doubles.quadruple example 2: failed: unknown name twice\n">>,
                 iolist_to_binary(?capturedOutput)),
    %% the units the private examples were compiled in go with the run
    ?assertNot(erlang:module_loaded('ern@doubles$2')),
    write(Dir, "src/doubles.ern", Source ++ "\n// changed\n"),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/doubles.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"/src/doubles.ern, which has changed since\n">>)),
    ok = file:delete(Dir ++ "/src/doubles.ern"),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/doubles.erc"])),
    Gone = iolist_to_binary(["Doubles.twice example 1: failed: ", Dir,
                             "/build/doubles.erc was compiled from ", Dir,
                             "/src/doubles.ern, which no longer exists\n"]),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), Gone)).

%% report §11.2, §4.2: a private declaration's doc example in Io itself is
%% compiled inside Io with `Io.show` written plain, as Io writes its own
%% declaration where no binding hides it, and checks there. A regression
%% test, written after the code, for what ern_doc_tests wrote and `ern
%% test` did not: the example's module named `Io.show` qualified, which Io
%% refuses. It does not cover the example's run, since a module of a
%% standard library namespace is built in the library's source root alone,
%% which holds no private declaration with an example
private_io_example_test() ->
    {ok, Source} = file:read_file("../../../src/stdlib/io.ern"),
    {Text, <<"\"1\"">>} = ern_examples:module_text(['Io'], <<Source/binary, "\n">>,
                                                     <<"show(1)\n// => \"1\"">>),
    {ok, Declarations} = ern_parser:parse_string(iolist_to_binary(Text)),
    ?assertMatch({ok, _, _, _}, ern_typecheck:check(['Io'], Declarations, [])),
    {Outside, _} = ern_examples:module_text(['$Example1'], <<>>, <<"1\n// => 1">>),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(Outside), <<"= Io.show({ 1\n})">>)).

%% report §11.2, §4.4, §11.4: an abstract type's constructors' and fields'
%% doc examples run, compiled inside the module, where the constructor is
%% visible, after the type's own, which is compiled outside it; the page
%% `ern doc` writes names no constructor of the type, as before. A
%% regression test, written after the code: the documentation chunk held
%% no constructor of an abstract type, so `ern test` ran none of their
%% examples; it does not cover the shell's `:doc`, which renders the
%% type's entry as the page does
abstract_constructor_examples_test() ->
    Dir = tmp(),
    write(Dir, "src/stacks.ern",
          "/// A stack of numbers.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Stacks.size(Stacks.empty)\n"
          "/// // => 0\n"
          "/// ```\n"
          "export abstract type Stack =\n"
          "    /// A stack holding its items, the top first.\n"
          "    ///\n"
          "    /// ```ernest\n"
          "    /// size(Stack(items = [1, 2]))\n"
          "    /// // => 2\n"
          "    /// ```\n"
          "    Stack(\n"
          "        /// The items, the top first.\n"
          "        ///\n"
          "        /// ```ernest\n"
          "        /// Stack(items = [3]).items\n"
          "        /// // => [4]\n"
          "        /// ```\n"
          "        items : List(Int))\n"
          "\n"
          "/// The stack with nothing on it.\n"
          "export let empty : Stack = Stack(items = [])\n"
          "\n"
          "/// How many items the stack holds.\n"
          "export fn size(stack : Stack) : Int = List.size(stack.items)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/stacks.erc"])),
    Lines = <<"Stacks.Stack example 1: passed\n"
              "Stacks.Stack example 2: passed\n"
              "Stacks.Stack example 3: failed: expected [4], got [3]\n">>,
    ?assertEqual(Lines, iolist_to_binary(?capturedOutput)),
    ?assertEqual(0, ern_cli:ern(["doc", Dir ++ "/build/stacks.erc"])),
    <<Lines:(byte_size(Lines))/binary, Page/binary>> = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Page, <<"abstract type Stack\n">>)),
    ?assertEqual(nomatch, binary:match(Page, <<"holding its items">>)),
    ?assertEqual(nomatch, binary:match(Page, <<"the top first">>)).

%% report §11.2, Appendix E.23: each doc example runs as a program of its
%% own in its empty directory, which `Os.workingDirectory` names and a
%% relative path is read under, so that an example that writes under
%% `Os.workingDirectory` leaves nothing in the run's directory and passes
%% on a second run; where its directory cannot be made, the example fails
%% saying so. A regression test, written after the code: the examples ran
%% in the tests' launch, where `Os.workingDirectory` named the run's
%% directory and the file was left there; it does not cover a directory
%% that cannot be removed, nor a run on a node
doc_example_working_directory_test() ->
    Dir = tmp(),
    write(Dir, "src/places.ern",
          "/// Makes `x.txt` under the working directory, which is empty before it.\n"
          "///\n"
          "/// ```ernest\n"
          "/// #(Fs.list(Os.workingDirectory, 5000), Places.make())\n"
          "/// // => #(Right([]), Right(Unit))\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// let _ = Places.make();\n"
          "/// Fs.read(Path(\"x.txt\"), 5000) == Right(String.toUtf8(\"x\"))\n"
          "/// // => true\n"
          "/// ```\n"
          "export fn make() : Either(Io.Error, Unit) =\n"
          "    Fs.makeFile(Os.workingDirectory <> Path(\"x.txt\"), String.toUtf8(\"x\"), 5000)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Temporary = filename:join(Dir, "temporary"),
    ok = file:make_dir(Temporary),
    Given = os:getenv("TMPDIR"),
    try
        true = os:putenv("TMPDIR", Temporary),
        in_directory(Dir, fun() ->
                              ?assertEqual(0, ern_cli:ern(["test", "build/places.erc"])),
                              ?assertEqual(0, ern_cli:ern(["test", "build/places.erc"]))
                          end),
        Passed = <<"Places.make example 1: passed\nPlaces.make example 2: passed\n">>,
        ?assertEqual(<<Passed/binary, Passed/binary>>, iolist_to_binary(?capturedOutput)),
        {ok, Left} = file:list_dir(Dir),
        ?assertEqual(["build", "src", "temporary"], lists:sort(Left)),
        ?assertEqual({ok, []}, file:list_dir(Temporary)),
        None = filename:join(Dir, "none"),
        true = os:putenv("TMPDIR", None),
        ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/places.erc"]))
    after
        case Given of
            false -> os:unsetenv("TMPDIR");
            _ -> os:putenv("TMPDIR", Given)
        end
    end,
    Unmade = iolist_to_binary(["Places.make example 1: failed: its directory cannot be made under ",
                               Dir, "/none: no such file or directory\n"]),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), Unmade)).

%% report §11.2: a doc example whose directory cannot be removed after its
%% launch has ended is said on the job's standard error, here an example
%% that leaves a file in its directory and the directory read-only, so
%% that the file cannot be deleted. A regression test, written after the
%% code: the line was sent to the ended launch's standard error process,
%% and lost. It assumes a user the directory's mode binds, which root is
%% not.
doc_example_kept_directory_test() ->
    Dir = tmp(),
    write(Dir, "src/kept.ern",
          "/// Leaves a file in a directory it makes read-only.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Kept.keep()\n"
          "/// // => Right(Unit)\n"
          "/// ```\n"
          "export fn keep() : Either(Io.Error, Unit) = {\n"
          "    let _ <- Fs.makeFile(Path(\"kept.txt\"), String.toUtf8(\"kept\"), 5000);\n"
          "    Fs.setMode(Os.workingDirectory, 0o555, 5000)\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Temporary = filename:join(Dir, "temporary"),
    ok = file:make_dir(Temporary),
    Given = os:getenv("TMPDIR"),
    try
        true = os:putenv("TMPDIR", Temporary),
        {Said, Status} = standard_error_of(["test", Dir ++ "/build/kept.erc"]),
        ?assertEqual(0, Status),
        ?assertEqual(<<"Kept.keep example 1: passed\n">>, iolist_to_binary(?capturedOutput)),
        {ok, [Kept]} = file:list_dir(Temporary),
        Line = iolist_to_binary(["ern test: the directory of Kept.keep example 1, ",
                                 filename:join(Temporary, Kept), ", cannot be removed: "]),
        ?assertMatch({0, _}, binary:match(unicode:characters_to_binary(Said), Line))
    after
        case Given of
            false -> os:unsetenv("TMPDIR");
            _ -> os:putenv("TMPDIR", Given)
        end,
        [ok = file:change_mode(filename:join(Temporary, Left), 8#700)
         || {ok, Names} <- [file:list_dir(Temporary)], Left <- Names],
        ok = file:del_dir_r(Temporary)
    end.

%% report §8.7, §11.2: a line a node says while no launch is in progress,
%% between two launches of `ern test` over a directory, before the first
%% and after the last, is written on the job's own standard error, the
%% device the job was given, and one said in a launch goes through the
%% launch's standard error as before. A regression test, written after the
%% code: the line was sent to the ended launch's standard error process,
%% and lost. It says the line from the test after the job's launch has
%% ended; a node's own line between two launches, whose time a test cannot
%% hold, is not covered.
said_outside_a_launch_test() ->
    Dir = tmp(),
    write(Dir, "src/a.ern",
          "let ones = Test.Case(name = \"ones\", run = fn() = Test.equal(1, 1))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Self = self(),
    Device = spawn(fun() -> capture(Self, []) end),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build"], Device)),
    ok = ern_carrier:say("the peer store connected"),
    Device ! {done, self()},
    Said = receive {captured, Text} -> unicode:characters_to_binary(Text) end,
    ?assertEqual(<<"the peer store connected\n">>, Said),
    ?assertEqual(<<"A\nones: passed\n">>, iolist_to_binary(?capturedOutput)),
    Inside = ern_rt:run_main(fun() -> ern_carrier:say("said in a launch") end, <<"main">>,
                             #{stderr => fun(Bytes) -> Self ! {stderr, Bytes} end}),
    ?assertEqual(ok, Inside),
    ?assertEqual(<<"said in a launch\n">>, receive {stderr, Bytes} -> Bytes end).

%% report §11.2, §8.5: the module's initializers run once for its tests and
%% once for each doc example that runs, in the example's program, after the
%% tests' lines; a private declaration's example, compiled inside the module
%% in a unit of its own, evaluates the module's bindings once, in that unit,
%% and an example that does not run initializes nothing. A regression test,
%% written after the code: a private declaration's example evaluated the
%% module's initializers again in the tests' launch; an initializer that
%% faults in an example's directory is doc_example_program_ends_test's
doc_example_initializers_test() ->
    Dir = tmp(),
    write(Dir, "src/inits.ern",
          "let greeted : Unit = Io.println(\"initialized\")\n"
          "\n"
          "/// Twice `n`.\n"
          "///\n"
          "/// ```ernest\n"
          "/// twice(2)\n"
          "/// // => 4\n"
          "/// ```\n"
          "fn twice(n : Int) : Int = n * 2\n"
          "\n"
          "/// Four times `n`.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Inits.quadruple(1)\n"
          "/// // => 4\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Inits.quadruple(2)\n"
          "/// ```\n"
          "export fn quadruple(n : Int) : Int = twice(twice(n))\n"
          "\n"
          "let quadrupled = Test.Case(name = \"quadrupled\", run = fn() =\n"
          "    Test.equal(quadruple(2), 8))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build/inits.erc"])),
    ?assertEqual(<<"initialized\n"
                   "quadrupled: passed\n"
                   "initialized\n"
                   "Inits.twice example 1: passed\n"
                   "initialized\n"
                   "Inits.quadruple example 1: passed\n"
                   "Inits.quadruple example 2: compiled\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, §8.5: a doc example whose program ends before the example
%% returns fails with `faulted` and the cause, as a test's line is, the
%% fault's trace beneath it, and the next example runs: an initializer that
%% faults in the example's empty directory, where the tests' launch found
%% its file, and one that kills the entry process there; the fault is not
%% reported on standard error too. An example that itself faults keeps its
%% line, and the next runs after it. The status is 1 for each module. A
%% regression test, written after the code: the initializer's fault was
%% reported on standard error as `ern run` reports it and ended the
%% module's run, with no line for the example and none after it, and the
%% kill printed `killed`; it does not cover a signal or a stream that can
%% no longer be written during an example's launch, which end the module's
%% run, nor a run on a node
doc_example_program_ends_test() ->
    Dir = tmp(),
    write(Dir, "src/configs.ern",
          "let config : Bytes = match Fs.read(Path(\"config.txt\"), 5000) {\n"
          "    Right(bytes) -> bytes\n"
          "  | Left(error) -> fault(\"config.txt cannot be read: \" <> Io.show(error))\n"
          "}\n"
          "\n"
          "/// The size of `config.txt` where the module is initialized.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Configs.size()\n"
          "/// // => 2\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Configs.size() + 1\n"
          "/// ```\n"
          "export fn size() : Int = Bytes.size(config)\n"
          "\n"
          "let sized = Test.Case(name = \"sized\", run = fn() = Test.equal(size(), 2))\n"),
    write(Dir, "src/kills.ern",
          "let initializing : Address(Never) = self()\n"
          "\n"
          "let checked : Unit = match Fs.stat(Path(\"config.txt\"), 5000) {\n"
          "    Right(_) -> Unit\n"
          "  | Left(_) -> kill(initializing)\n"
          "}\n"
          "\n"
          "/// Nothing, where `config.txt` is.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Kills.nothing()\n"
          "/// // => Unit\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Kills.nothing()\n"
          "/// ```\n"
          "export fn nothing() : Unit = checked\n"),
    write(Dir, "src/divides.ern",
          "/// `n` over `d`.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Divides.divide(1, 0)\n"
          "/// // => 0\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Divides.divide(4, 2)\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn divide(n : Int, d : Int) : Int = n / d\n"),
    write(Dir, "config.txt", "ab"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Errors = in_directory(Dir, fun() ->
                                   [standard_error_of(["test", "build/" ++ Module ++ ".erc"])
                                    || Module <- ["configs", "kills", "divides"]]
                               end),
    ?assertEqual([{"", 1}, {"", 1}, {"", 1}], Errors),
    Output = iolist_to_binary(?capturedOutput),
    ?assertEqual(<<"sized: passed\n"
                   "Configs.size example 1: faulted: config.txt cannot be read: NotFound\n"
                   "Configs.size example 2: compiled\n"
                   "Kills.nothing example 1: killed\n"
                   "Kills.nothing example 2: compiled\n"
                   "Divides.divide example 1: faulted: division by zero\n"
                   "Divides.divide example 2: passed\n">>,
                 untraced(Output)),
    ?assertMatch({_, _}, binary:match(Output, <<"NotFound\n    Configs.config:3\n"
                                                "Configs.size example 2">>)),
    %% report §11.2, Appendix E.21: the example's frame names its case and
    %% the line of the source its code stands on, and no frame of the
    %% function that shows its value is left
    ?assertMatch({_, _}, binary:match(Output, <<"zero\n    erlang:'div'/2\n    Divides.divide:12\n"
                                                "    Divides.divide example 1:4\n"
                                                "Divides.divide example 2: passed\n">>)).

%% report §2.2, §11.2: the examples `ern test` runs are a doc block's fenced
%% `ernest` blocks as CommonMark finds them: a fence of tildes, a fence of
%% four backticks closed by four, an info string with spaces after its
%% word, and a fence indented in a list item, whose content loses the
%% fence's indentation, each run, and one example's closing fence does not
%% end at the next's. A regression test, written after the code: `ern test`
%% found the examples by a pattern that ran only three backticks and
%% `ernest` at a line's start, so the first three never ran and the list
%% item's ran on into the next fence; it does not cover a fence in a block
%% quote, whose markers the reader does not take off
doc_example_fences_test() ->
    Dir = tmp(),
    write(Dir, "src/tilde.ern",
          "/// Tildes.\n"
          "///\n"
          "/// ~~~ernest\n"
          "/// Tilde.twice(3)\n"
          "/// // => 7\n"
          "/// ~~~\n"
          "///\n"
          "/// ````ernest\n"
          "/// Tilde.twice(3)\n"
          "/// // => 8\n"
          "/// ````\n"
          "///\n"
          "/// ```ernest  \n"
          "/// Tilde.twice(3)\n"
          "/// // => 9\n"
          "/// ```\n"
          "\n"
          "/// Twice.\n"
          "export fn twice(x : Int) : Int =\n"
          "    x * 2\n"),
    write(Dir, "src/fence.ern",
          "/// Fences.\n"
          "///\n"
          "/// - an item:\n"
          "///\n"
          "///   ```ernest\n"
          "///   Fence.twice(2)\n"
          "///   // => 5\n"
          "///   ```\n"
          "///\n"
          "/// ~~~ernest\n"
          "/// Fence.twice(3)\n"
          "/// // => 7\n"
          "/// ~~~\n"
          "///\n"
          "/// ```ernest\n"
          "/// Fence.twice(1)\n"
          "/// // => 2\n"
          "/// ```\n"
          "\n"
          "/// Twice.\n"
          "export fn twice(x : Int) : Int =\n"
          "    x * 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build"])),
    ?assertEqual(<<"Fence\n"
                   "Fence example 1: failed: expected 5, got 4\n"
                   "Fence example 2: failed: expected 7, got 6\n"
                   "Fence example 3: passed\n"
                   "Tilde\n"
                   "Tilde example 1: failed: expected 7, got 6\n"
                   "Tilde example 2: failed: expected 8, got 6\n"
                   "Tilde example 3: failed: expected 9, got 6\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, Appendix E.21: the trace of a doc example's fault names
%% the example by its case and each of its frames by the line of the
%% module's source its code stands on, a function the example declares
%% among them, and a private declaration's example, compiled inside the
%% module, alike; no frame names the functions the example is compiled
%% in. Report §11.2: the example's declarations are the longest run of its
%% first paragraphs that parses as declarations, so an expression with a
%% blank line in it follows a declared type. A regression test, written
%% after the code: the frames named `$Example1.docShown:5`, and an
%% expression with a blank line was read whole, the type in it; it does not
%% cover a source that changed since the build, whose frames name the case
%% without a line
doc_example_frames_test() ->
    Dir = tmp(),
    write(Dir, "src/frames.ern",
          "/// Divides.\n"
          "///\n"
          "/// ```ernest\n"
          "/// fn half(n : Int) : Int = n / 0\n"
          "///\n"
          "/// let h = half(4);\n"
          "/// h + 1\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn one() : Int = 1\n"
          "\n"
          "/// Twice.\n"
          "///\n"
          "/// ```ernest\n"
          "/// twice(1) / 0\n"
          "/// // => 0\n"
          "/// ```\n"
          "fn twice(n : Int) : Int = n * 2\n"
          "\n"
          "/// A pair.\n"
          "///\n"
          "/// ```ernest\n"
          "/// type Two = Two(first : Int, second : Int)\n"
          "///\n"
          "/// let two = {\n"
          "///     let a = Frames.one();\n"
          "///\n"
          "///     Two(first = a, second = 2)\n"
          "/// };\n"
          "/// two.second - two.first\n"
          "/// // => 1\n"
          "/// ```\n"
          "export fn pair() : Int = twice(1)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/frames.erc"])),
    ?assertEqual(<<"Frames.one example 1: faulted: division by zero\n"
                   "    erlang:'div'/2\n"
                   "    Frames.one example 1:4\n"
                   "    Frames.one example 1:6\n"
                   "Frames.twice example 1: faulted: division by zero\n"
                   "    erlang:'div'/2\n"
                   "    Frames.twice example 1:15\n"
                   "Frames.pair example 1: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2: nothing a doc example leaves reaches the next, since each
%% runs as a program of its own: a process the first left holding an offer
%% has ended with its program, so the second's offer of the same service
%% is taken. A regression test, written after the code: the second example
%% was answered `Left(holder)`, the first's process; it does not cover a
%% run on a node, whose connections the examples' launches share
doc_example_leaves_nothing_test() ->
    Dir = tmp(),
    write(Dir, "src/holds.ern",
          "/// Offers `squares` at a process that waits.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Holds.hold()\n"
          "/// // => Right(Unit)\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Holds.hold()\n"
          "/// // => Right(Unit)\n"
          "/// ```\n"
          "export fn hold() : Either(Process, Unit) =\n"
          "    Peer.offer(Peer.service(\"squares\"), spawn(fn() : Unit receiving Int = receive {\n"
          "        _ -> Unit\n"
          "    }))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build/holds.erc"])),
    ?assertEqual(<<"Holds.hold example 1: passed\nHolds.hold example 2: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, §11.1: a doc example's module may name any module the
%% build root holds, as a module may, one its documented module does not
%% use among them, and the example's program initializes it: a parent's
%% example names its child, and the child's names its parent, which its
%% own code does not use, under `ern test` of each file and of the
%% directory; a module whose code uses the parent names it in its example,
%% as it could before. A regression test, written after the code: the
%% parent's and the child's examples failed with `unknown name`, the
%% example being checked against the documented module and those it uses
%% alone; it does not cover a run on a node
doc_example_names_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern",
          "/// One.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.Child.twice(Top.one())\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn one() : Int = 1\n"),
    write(Dir, "src/top/child.ern",
          "let said : Unit = Io.println(\"Child initialized\")\n"
          "\n"
          "/// Twice `n`.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.Child.twice(Top.one())\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn twice(n : Int) : Int = n * 2\n"),
    write(Dir, "src/top/user.ern",
          "/// Three.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.User.three() - Top.one()\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn three() : Int = Top.one() + 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build/top.erc"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build/top/child.erc"])),
    ?assertEqual(<<"Child initialized\n"
                   "Top.one example 1: passed\n"
                   "Child initialized\n"
                   "Child initialized\n"
                   "Top.Child.twice example 1: passed\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"Top\n"
                                        "Child initialized\n"
                                        "Top.one example 1: passed\n"
                                        "Top.Child\n"
                                        "Child initialized\n"
                                        "Child initialized\n"
                                        "Top.Child.twice example 1: passed\n"
                                        "Top.User\n"
                                        "Top.User.three example 1: passed\n">>)).

%% report §11.2, §11.1: a module a doc example names is found on the load
%% path as a module the documented one uses is: with the child under a
%% `--load-path` root alone and the parent alone in the directory, the
%% parent's example passes under `ern test` of the file and of the
%% directory, and without the root it fails with `unknown name`. A
%% regression test, written after the code: the example failed with
%% `unknown name` with the root given; it does not cover `--libs-dir`,
%% whose roots are the load path's as `--load-path`'s are
doc_example_names_a_module_on_the_load_path_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern",
          "/// One.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.Child.twice(Top.one())\n"
          "/// // => 2\n"
          "/// ```\n"
          "export fn one() : Int = 1\n"),
    write(Dir, "lib/top/child.ern", "export fn twice(n : Int) : Int = n * 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/libs", Dir ++ "/lib"])),
    LoadPath = ["--load-path", Dir ++ "/libs"],
    ?assertEqual(0, ern_cli:ern(["test" | LoadPath] ++ [Dir ++ "/build/top.erc"])),
    ?assertEqual(0, ern_cli:ern(["test" | LoadPath] ++ [Dir ++ "/build"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/top.erc"])),
    ?assertEqual(<<"Top.one example 1: passed\n"
                   "Top\n"
                   "Top.one example 1: passed\n"
                   "Top.one example 1: failed: unknown name Top.Child.twice\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2: a qualified name in a doc example that no module of the
%% build root or the load path holds fails the example with `unknown name`,
%% and the next example runs. A regression test, written after the code
doc_example_names_no_module_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern",
          "/// One.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Nowhere.thing()\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.Nowhere.thing()\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.one()\n"
          "/// // => 1\n"
          "/// ```\n"
          "export fn one() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/top.erc"])),
    ?assertEqual(<<"Top.one example 1: failed: unknown name Nowhere.thing\n"
                   "Top.one example 2: failed: unknown name Top.Nowhere.thing\n"
                   "Top.one example 3: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, §4.1: a private declaration's doc example, compiled inside
%% its module, may name a module as an exported declaration's may, and its
%% program initializes it; one that names a module that uses the
%% documented module fails as a cycle, since the example's module is the
%% documented one. A regression test, written after the code: the first
%% example failed with `unknown name`; it does not cover a cycle through a
%% module between the two
private_doc_example_names_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern",
          "/// Three.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.Child.twice(three())\n"
          "/// // => 6\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Top.User.four()\n"
          "/// ```\n"
          "fn three() : Int = 3\n"
          "\n"
          "export fn one() : Int = 1\n"),
    write(Dir, "src/top/child.ern",
          "let said : Unit = Io.println(\"Child initialized\")\n"
          "\n"
          "export fn twice(n : Int) : Int = n * 2\n"),
    write(Dir, "src/top/user.ern", "export fn four() : Int = Top.one() + 3\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/top.erc"])),
    ?assertEqual(<<"Child initialized\n"
                   "Top.three example 1: passed\n"
                   "Top.three example 2: failed: module cycle: Top, Top.User\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report Appendix E.24, §4.9: `Test.equal` passes where the actual value
%% equals the expected one and otherwise fails naming both as `Io.show`
%% writes them, the expected first, at a type the program declares and
%% through a function that names `a.show` alike. Written with the function
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

%% report Appendix E.24, §11.2: `Test.faults` passes where the call faults
%% with the cause given, and otherwise fails naming what came instead,
%% another cause, a return or the reason; `ern test` reports no fault of a
%% process `Test.faults` started, and a fault outside it, of a worker a
%% test spawned, on standard error as before, its trace beneath it. A
%% regression test, written after the code; the faults a `Test.faults`
%% run's own spawns meet are the worker's case, their sites the program's
test_faults_test() ->
    Dir = tmp(),
    File = write(Dir, "faults.ern",
                 "type Ended = Ended(Down)\n"
                 "let divides = Test.Case(name = \"divides\", run = fn() =\n"
                 "    Test.faults(fn() = 1 / 0, \"division by zero\"))\n"
                 "let wrong = Test.Case(name = \"wrong\", run = fn() =\n"
                 "    Test.faults(fn() = 1.0 / 0.0, \"division by zero\"))\n"
                 "let returns = Test.Case(name = \"returns\", run = fn() =\n"
                 "    Test.faults(fn() = 1 + 1, \"division by zero\"))\n"
                 "let killed = Test.Case(name = \"killed\", run = fn() =\n"
                 "    Test.faults(fn() = kill(self()), \"division by zero\"))\n"
                 "let worker = Test.Case(name = \"worker\", run = fn() = {\n"
                 "    let _ = spawnMonitored(fn() = Io.println(Int.toString(1 / 0)), Ended);\n"
                 "    receive { Ended(_) -> Test.Passed }\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Errors, Status} = standard_error_of(["test", filename:join(Dir, "faults.erc")]),
    ?assertEqual(1, Status),
    ?assertEqual(<<"divides: passed\n"
                   "wrong: failed: expected the fault division by zero,"
                   " got the fault float arithmetic error\n"
                   "returns: failed: expected the fault division by zero, got a return\n"
                   "killed: failed: expected the fault division by zero, got Killed\n"
                   "worker: passed\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertEqual(<<"Faults.worker:11 faulted: division by zero\n">>, untraced(Errors)),
    ?assertMatch([<<"Faults.worker:11 faulted: division by zero">>, <<"    ", _/binary>> | _],
                 binary:split(unicode:characters_to_binary(Errors), <<"\n">>, [global])),
    ?assertEqual(nomatch, binary:match(unicode:characters_to_binary(Errors), <<"Test.faults">>)).

%% report Appendix E.24, §6.9, §8.6: where the caller of `Test.faults` ends
%% before the call's process, here faulted by the deadlock its wait makes,
%% the call's process is killed and the process that judged it ends, so
%% that the next test finds each process `Test.faults` started ending. The
%% second test monitors each it finds and waits for their ends, which a
%% process left waiting would turn into that test's own deadlock. A
%% regression test (E2), written after the code: both processes outlived
%% the caller. It does not cover a caller the interrupt ends in the shell.
test_faults_caller_ends_first_test() ->
    Dir = tmp(),
    File = write(Dir, "outlived.ern",
                 "type Ended = Ended(Down)\n"
                 "type Waits = Waits\n"
                 "fn waitsForever() : Unit receiving Waits = receive { Waits -> Unit }\n"
                 "let first = Test.Case(name = \"first\", run = fn() =\n"
                 "    Test.faults(waitsForever, \"division by zero\"))\n"
                 "let second = Test.Case(name = \"second\", run = fn() = {\n"
                 "    let started = List.filter(Process.live(), fn(process) =\n"
                 "        match Process.status(process) {\n"
                 "            Some(status) -> String.startsWith(status.site, \"Test.faults\")\n"
                 "          | None -> false\n"
                 "        });\n"
                 "    List.forEach(started, fn(process) = monitor(process, Ended));\n"
                 "    ended(List.size(started))\n"
                 "})\n"
                 "fn ended(count : Int) : Test.Result receiving Ended =\n"
                 "    if count == 0 then Test.Passed\n"
                 "    else receive { Ended(_) -> ended(count - 1) }\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {_Errors, Status} = standard_error_of(["test", filename:join(Dir, "outlived.erc")]),
    ?assertEqual(1, Status),
    ?assertEqual(<<"first: faulted: deadlock\nsecond: passed\n">>,
                 untraced(?capturedOutput)).

%% report §11.2, Appendix E.24: no job reports a fault `Test.faults`
%% expects: under `ern run` a `main` whose call of it passes prints
%% `Passed` and writes nothing on standard error, as `ern test` writes
%% nothing. A regression test, written after the code; the shell's is
%% test/ern_shell_tests.erl's
run_reports_no_expected_fault_test() ->
    Dir = tmp(),
    File = write(Dir, "expects.ern",
                 "export fn main() : Unit =\n"
                 "    Io.println(Io.show(Test.faults(fn() = 1 / 0, \"division by zero\")))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual({"", 0}, standard_error_of(["run", filename:join(Dir, "expects.erc")])),
    ?assertEqual(<<"Passed\n">>, iolist_to_binary(?capturedOutput)).

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
          "fn waiter() : Unit receiving Msg = receive { Go -> Unit }\n"
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
                 untraced(?capturedOutput)).

%% report §8.6, §11.2: while the end waits, a process that waits with
%% nothing in flight is no deadlock. Under `ern test` a deadlock while a
%% test runs is that test's fault, which shows it: a termination comes
%% while a test waits, and the subscriber it started, told, keeps its reply
%% unanswered; the test is not faulted, and a second termination ends the
%% run. The second comes once the reaper has looked for a deadlock twice
%% while the end waits, which ern_waits shows, the wait being for an
%% absence that nothing else shows. A regression test, written after the
%% code: the test that stood here passed with nothing keeping the look from
%% finding a deadlock while the end waits, since only under `ern test` is a
%% deadlock then anyone's fault.
no_deadlock_while_the_end_waits_test_() ->
    {timeout, 60, fun no_deadlock_while_the_end_waits/0}.

no_deadlock_while_the_end_waits() ->
    Dir = tmp(),
    write(Dir, "src/ending.ern",
          "type Msg = Terminating(Reply(Unit)) | Go\n"
          "foreign fn send(name : Foreign.Term, word : Foreign.Term) : Foreign.Term"
          " = \"erlang:send/2\"\n"
          "fn said(word : String) : Unit = {\n"
          "    let _ = send(Foreign.term(Foreign.atom(\"ern_cli_tests_ending\")),\n"
          "                 Foreign.term(Foreign.atom(word)));\n"
          "    Unit\n"
          "}\n"
          "fn held(reply : Reply(Unit)) : Unit receiving Msg = receive {\n"
          "    Terminating(other) -> { answer(other, Unit); held(reply) }\n"
          "  | Go -> held(reply)\n"
          "}\n"
          "fn keeper() : Unit receiving Msg = {\n"
          "    Os.termination(Terminating);\n"
          "    said(\"subscribed\");\n"
          "    receive {\n"
          "        Terminating(reply) -> { said(\"told\"); held(reply) }\n"
          "      | Go -> Unit\n"
          "    }\n"
          "}\n"
          "let waits : Test.Case(Msg) = Test.Case(name = \"waits\", run = fn() = {\n"
          "    let _ = spawn(keeper);\n"
          "    receive { Go -> Test.Passed }\n"
          "})\n"),
    Ending = spawn(fun() ->
                       receive subscribed -> ok end,
                       ok = ern_rt:signal(sigterm),
                       receive told -> ok end,
                       ern_waits:looked(2),
                       ok = ern_rt:signal(sigterm)
                   end),
    register(ern_cli_tests_ending, Ending),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(143, ern_err(["test", Dir ++ "/build/ending.erc"])),
    ?assertEqual(nomatch, binary:match(iolist_to_binary(?capturedOutput), <<"deadlock">>)).

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
                 untraced(?capturedOutput)).

%% report §11: a link where `ern build` writes a `.erc` is replaced by the
%% module, and what the link named is left as it was. A regression test:
%% the build wrote through a link planted in the build tree
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
%% terminal as it was
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
          "export fn main() : Unit = {\n"
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

%% report §11, §11.2: `--` ends a job's options, and after `ern run`'s
%% file a `--` is the program's as every word there is. A regression test,
%% written after the code
double_dash_test() ->
    Dir = tmp(),
    write(Dir, "src/args.ern",
          "export fn main() : Unit = {\n"
          "    Io.println(Io.show(Os.arguments));\n"
          "    Os.exit(List.size(Os.arguments))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", "--",
                                 Dir ++ "/src"])),
    ?assertEqual(2, ern_cli:ern(["run", "--", Dir ++ "/build/args.erc", "--", "--main"])),
    ?assertEqual(<<"[\"--\", \"--main\"]\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a namespace of a standard library
%% module written in Ernest
stdlib_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/foreign.ern", "export fn atom(s : String) : String = s\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2, Appendix E.19: `Erl` went into `Foreign`, and its namespace
%% is no longer taken, so `erl.ern` at a source root is a program's own. A
%% regression test of the principles review's P49 (2026-10-09)
erl_namespace_free_test() ->
    Dir = tmp(),
    write(Dir, "src/erl.ern", "export fn atom(s : String) : String = s\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

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

%% Three roots: lib holds B, src holds A, which uses B, built into build,
%% and earlier holds an A that uses nothing. B is compiled first alone, and
%% A against it.
load_path_cycle_roots(Dir) ->
    [Library, Source, Build, Earlier] =
        [filename:join(Dir, Leaf) || Leaf <- ["lib", "src", "build", "earlier"]],
    write(Library, "b.ern", "export fn twice(x : Int) : Int = x * 2\n"),
    ?assertEqual(0, build_err(["--source-root", Library, Library])),
    write(Source, "a.ern", "export fn main() : Unit = Io.println(Int.toString(B.twice(2)))\n"),
    ?assertEqual(0, build_err(["--source-root", Source, "--build-root", Build, "--load-path",
                               Library, Source])),
    write(Earlier, "a.ern", "export fn main() : Unit = Io.println(\"earlier\")\n"),
    ?assertEqual(0, build_err(["--source-root", Earlier, Earlier])),
    write(Library, "b.ern", "export fn twice(x : Int) : Int = x * 2\n\n"
                            "export fn run() : Unit = A.main()\n"),
    {Library, Source, Build, Earlier}.

%% report §11.1, §4.1: a cycle through the load path's modules is refused
%% as one among the sources is, naming its modules, and no build holds one:
%% B, which uses A, is refused against the A of build, which uses B, and A
%% is refused against that B once B is compiled against an A that does
%% not. A regression test, written after the fix: both builds were made,
%% the build reading no dependency a load-path module records
load_path_cycle_refused_test() ->
    {Library, Source, Build, Earlier} = load_path_cycle_roots(tmp()),
    ?assertEqual(1, build_err(["--source-root", Library, "--load-path", Build, Library])),
    ?assertEqual(0, build_err(["--source-root", Library, "--load-path", Earlier, Library])),
    ?assertEqual(1, build_err(["--source-root", Source, "--build-root", Build, "--load-path",
                               Library, Source])),
    ?assertEqual(<<"ern build: module cycle: A, B\nern build: module cycle: A, B\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.1, §11.2, §4.1: `ern run` of a module whose files hold a cycle,
%% each compiled against another form of the other, which no build saw
%% whole, refuses it as `ern build` does before anything runs. A regression
%% test, written after the fix: the run loaded the modules for ever, one
%% using the other, and never ended; eunit's time bounds the test
run_of_a_load_path_cycle_refused_test() ->
    {Library, _Source, Build, Earlier} = load_path_cycle_roots(tmp()),
    ?assertEqual(0, build_err(["--source-root", Library, "--load-path", Earlier, Library])),
    ?assertEqual(1, ern_err(["run", "--load-path", Library, filename:join(Build, "a.erc")])),
    ?assertEqual(<<"ern run: module cycle: A, B\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: a module is recompiled when its source, a dependency's
%% interface, the hash of a definition its forms reference, the standard
%% library's interfaces, or the compiler changed, and not when a
%% dependency's bodies changed only where its forms reference nothing
recompile_rule_test() ->
    Dir = pair(tmp()),
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
          "export fn version() : Int = 1\n"),
    Args = ["--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, Main1} = file:read_file(Dir ++ "/build/main.erc"),
    {ok, Http1} = file:read_file(Dir ++ "/build/net/http.erc"),
    %% nothing changed: nothing rewritten
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% a body change in the dependency that the dependent's forms do not
    %% name: it is rebuilt, its dependent is not
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
          "export fn version() : Int = 2\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, Http2} = file:read_file(Dir ++ "/build/net/http.erc"),
    ?assertNotEqual(Http1, Http2),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% a body change to what the dependent's forms name changes its hash:
    %% the dependent is rebuilt, its forms naming the new hash (Appendix H)
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\"))\n"
          "    else if s == \"\" then None else None\n"
          "export fn version() : Int = 2\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, Main2} = file:read_file(Dir ++ "/build/main.erc"),
    ?assertNotEqual(Main1, Main2),
    {ok, Http3} = file:read_file(Dir ++ "/build/net/http.erc"),
    {ok, #recorded{definitions = HttpDefinitions}} = ern_canonical:read(Http3),
    {ok, #{references := References}} = ern_interface:read(Main2),
    ?assertEqual(lists:sort([{QualifiedName, Hash}
                             || #definition{qualified_name = QualifiedName, hash = Hash}
                                    <- HttpDefinitions,
                                lists:member(lists:last(QualifiedName), [parse, 'Request'])]),
                 References),
    {ok, #recorded{definitions = MainDefinitions}} = ern_canonical:read(Main2),
    ?assertMatch([#definition{qualified_name = ['Main', main]}], MainDefinitions),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Main2}, file:read_file(Dir ++ "/build/main.erc")),
    %% an interface change in the dependency: the dependent is rebuilt
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) : Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\"))\n"
          "    else if s == \"\" then None else None\n"
          "export fn version() : String = \"2\"\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertNotEqual({ok, Main2}, file:read_file(Dir ++ "/build/main.erc")),
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

%% report §8.7: a run holds every definition of its build in the code
%% table, each found by its identity in the unit and the function that hold
%% it, as the unit's chunk of canonical forms names it, and the standard
%% library's with them; a foreign declaration's module is found by its
%% qualified name in the units the code of the unit that names it calls,
%% the module's own and those it calls, a unit of the standard library
%% calling none the walk follows. A regression test, written after the
%% code; the spawn by identity that reads the table is ern_peer_tests' and
%% ern_nodes_tests'.
code_table_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/shape.ern",
          "export type Shape = Square(Int) | Rect(w : Int, h : Int)\n"
          "export fn area(shape : Shape) : Int = match shape {\n"
          "    Square(side) -> side * side\n"
          "  | Rect(w = w, h = h) -> w * h\n"
          "}\n"
          "fn even(n : Int) : Bool = if n == 0 then true else odd(n - 1)\n"
          "fn odd(n : Int) : Bool = if n == 0 then false else even(n - 1)\n"
          "export fn isEven(n : Int) : Bool = even(n)\n"
          "export let unit : Shape = Square(1)\n"
          "export foreign fn sum(list : List(Int)) : Int = \"lists:sum/1\"\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit =\n"
          "    Io.println(Io.show(Geo.Shape.area(Geo.Shape.unit)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    Held = fun(Unit, File) ->
                   {ok, Beam} = file:read_file(Dir ++ "/build/" ++ File),
                   {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
                   [{Definition, Unit} || Definition <- Definitions]
           end,
    Definitions = Held('ern@geo@shape', "geo/shape.erc") ++ Held('ern@main', "main.erc"),
    ?assertEqual(7, length(Definitions)),
    [Main] = [Hash
              || {#definition{qualified_name = ['Main', main], hash = Hash}, _} <- Definitions],
    %% report §11.1: the unit names its functions by their number
    {MainFunction, 0} = ern_code:function('ern@main', ['Main', main]),
    {'ern@main', MainFunction, 0, {MainBindings, []}} = ern_code:spawnable({hash, Main}),
    lists:foreach(
      fun({#definition{kind = function, hash = Hash}, Unit}) ->
              {Unit, Function, Arity, _} = ern_code:spawnable({hash, Hash}),
              ?assert(lists:member({Function, Arity}, Unit:module_info(functions)));
         %% the binding main reads, by its identity, in main's reach
         ({#definition{qualified_name = QualifiedName, kind = binding, hash = Hash}, _}) ->
              ?assertEqual([{QualifiedName, Hash}], MainBindings);
         ({#definition{kind = type, hash = Hash}, _}) ->
              ?assertEqual(none, ern_code:spawnable({hash, Hash}))
      end, Definitions),
    Called = ern_code:called('ern@main'),
    ?assertMatch(#{'ern@main' := true, 'ern@geo@shape' := true}, Called),
    ?assertMatch([{_, lists, sum}], ern_code:foreign(Called, ['Geo', 'Shape', sum])),
    %% the standard library's definitions, which its units hold as a
    %% program's do
    {ok, ListBeam} = file:read_file(filename:join(ern_prelude:stdlib_directory(), "list.erc")),
    {ok, #recorded{definitions = ListDefinitions}} = ern_canonical:read(ListBeam),
    [Map] = [Hash || #definition{qualified_name = ['List', map], hash = Hash} <- ListDefinitions],
    {MapFunction, 2} = ern_code:function('ern@list', ['List', map]),
    ?assertMatch({'ern@list', MapFunction, 2, _}, ern_code:spawnable({hash, Map})).

%% report §8.7, §11.1, Appendix H: a library under its own root is hashed as
%% a program's code is, and a program built against it with --load-path
%% names its definitions by the hashes its `.erc` holds; so do the
%% libraries the repository builds, `Markdown` naming `Ansi`'s
library_hashed_test() ->
    Dir = tmp(),
    write(Dir, "lib/util.ern", "export fn twice(n : Int) : Int = n * 2\n"),
    write(Dir, "app/main.ern", "export fn main() : Unit = "
                               "Io.println(Io.show(Util.twice(21)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/lib-build", Dir ++ "/lib"])),
    ?assertEqual(0, ern_cli:ern(["build", "--load-path", Dir ++ "/lib-build", "--build-root",
                                 Dir ++ "/app-build", Dir ++ "/app"])),
    {ok, Util} = file:read_file(Dir ++ "/lib-build/util.erc"),
    {ok, Main} = file:read_file(Dir ++ "/app-build/main.erc"),
    {ok, #recorded{definitions = [#definition{qualified_name = ['Util', twice], hash = Twice}]}} =
        ern_canonical:read(Util),
    {ok, #recorded{definitions = [#definition{form = Form}]}} = ern_canonical:read(Main),
    <<131, Named/binary>> = term_to_binary({hash, Twice}),
    ?assertMatch({_, _}, binary:match(term_to_binary(Form), Named)),
    {ok, #{references := [{['Util', twice], Twice}]}} = ern_interface:read(Main),
    Read = fun(ErlangModule) ->
                   {ok, File} = ern_code:own_file(ErlangModule),
                   {ok, Bytes} = file:read_file(File),
                   Bytes
           end,
    {ok, #recorded{definitions = AnsiDefinitions}} = ern_canonical:read(Read('ern@ansi')),
    {ok, #{references := References}} = ern_interface:read(Read('ern@markdown')),
    Ansi = [Reference || {['Ansi' | _], _} = Reference <- References],
    ?assertNotEqual([], Ansi),
    ?assertEqual([], Ansi -- [{QualifiedName, Hash}
                              || #definition{qualified_name = QualifiedName, hash = Hash}
                                     <- AnsiDefinitions]).

%% report §11.2, Appendix H: a module the shell compiles from its source, as
%% `:load` does, holds its forms and hashes as a built one does, a module
%% it uses named by the hash the session holds
shell_load_hashed_test() ->
    Dir = tmp(),
    write(Dir, "geo.ern", "export fn area(w : Int, h : Int) : Int = w * h\n"),
    write(Dir, "room.ern", "export fn floor() : Int = Geo.area(3, 4)\n"),
    {ok, ['Geo'], Geo, _} = ern_build:compile_source(Dir ++ "/geo.ern", Dir, [Dir], #{}, #{}),
    {ok, #{interface := GeoInterface}} = ern_interface:read(Geo),
    {ok, ['Room'], Room, _} = ern_build:compile_source(Dir ++ "/room.ern", Dir, [Dir],
                                                         #{['Geo'] => GeoInterface}, #{}),
    {ok, #recorded{definitions = [#definition{hash = Area}]}} = ern_canonical:read(Geo),
    ?assertEqual(Area, maps:get(['Geo', area], GeoInterface#interface.identities)),
    {ok, #{references := [{['Geo', area], Area}]}} = ern_interface:read(Room),
    {ok, #recorded{definitions = [#definition{qualified_name = ['Room', floor]}]}} =
        ern_canonical:read(Room).

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

%% report §11.1: the build of the compiler a .erc records is one, whether
%% the job that wrote it had loaded the compiler's code or found every
%% module current and loaded none of it: a module's file digests as its
%% loaded code does. A regression test, written when a build that compiles
%% nothing came to digest the files of the modules it does not load
compiler_digest_of_its_files_test() ->
    ?assertEqual([], [Module || Module <- ern_build:compiler_modules(),
                                {ok, {_, Digest}} <- [beam_lib:md5(code:which(Module))],
                                Digest =/= Module:module_info(md5)]).

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
    write(Dir, "src/main.ern", "export fn main() : Unit =\n"
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
    %% a load path names a directory that is there (§11.7)
    ok = filelib:ensure_path(BuildRoot),
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
    %% report §11.5: its first line names the source as a path from the
    %% working directory; a regression test (T38) of the name alone
    Header = iolist_to_binary(["%% Generated by ern build from ",
                               ern_build:shown(Dir ++ "/src/net/http.ern"), "\n"]),
    ?assertMatch({0, _}, binary:match(Source, Header)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--emit", "asm", Dir ++ "/src"])).

%% report §11.1, §8.5: a top-level binding whose initializer is a ground
%% term, a literal, a negated number literal, a constructor applied to
%% ground terms or a list of tuples of them, is compiled to its value where
%% it is read, in its own module and in a dependent, through the interface;
%% one computed, `1024 * 1024`, and one that holds a lambda are read
%% through their getters, which every binding keeps; the program runs as it
%% did; and a dependent is compiled again where such a value has changed.
%% Written after the code, so a regression test; what the host keeps in
%% its literal area is the bench's to measure, not this test's
ground_binding_test() ->
    Dir = tmp(),
    Consts = fun(Limit) ->
                     ["export type Point = Point(x : Int, y : Int)\n\n"
                      "export let limit = ", Limit, "\n\n"
                      "export let prompt = \"> \"\n\n"
                      "export let origin = Point(x = 0, y = 0)\n\n"
                      "export let pairs = [#(1, \"a\")]\n\n"
                      "export let below = -0.0\n\n"
                      "export let size = 1024 * 1024\n\n"
                      "export let same = fn(x) = x\n\n"
                      "export fn doubled() : Int = limit + size\n"]
             end,
    write(Dir, "src/consts.ern", Consts("16777216")),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = {\n"
          "    Io.println(Io.show(Consts.limit));\n"
          "    Io.println(Consts.prompt);\n"
          "    Io.println(Io.show(Consts.origin));\n"
          "    Io.println(Io.show(Consts.pairs));\n"
          "    Io.println(Io.show(Consts.below));\n"
          "    Io.println(Io.show(Consts.size));\n"
          "    Io.println(Io.show(Consts.same(7)));\n"
          "    Io.println(Io.show(Consts.doubled()))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--build-root", Dir ++ "/erl",
                                 Dir ++ "/src"])),
    {ok, Emitted} = file:read_file(Dir ++ "/erl/consts.erl"),
    {ok, Main} = file:read_file(Dir ++ "/erl/main.erl"),
    %% limit is '$2', size '$7' and same '$8', by their positions (§11.1)
    ?assertMatch({_, _}, binary:match(Emitted, <<"'$9'() -> 16777216 + '$7'().">>)),
    ?assertMatch({_, _}, binary:match(Emitted,
                                      <<"'$2'() -> ern_rt:binding({ern@consts, '$2'}).">>)),
    [?assertMatch({_, _}, binary:match(Main, Read))
     || Read <- [<<"ern_io:show(16777216, int)">>, <<"(<<\"> \">>)">>, <<"{'Point', 0, 0}">>,
                 <<"[{1, <<\"a\">>}]">>, <<"ern_io:show(0.0, float)">>, <<"ern@consts:'$7'()">>,
                 <<"ern@consts:'$8'()">>]],
    [?assertEqual(nomatch, binary:match(Main, <<"ern@consts:'$", Getter, "'()">>))
     || Getter <- "23456"],
    Build = ["build", "--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(Build)),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    write(Dir, "src/consts.ern", Consts("5")),
    ?assertEqual(0, ern_cli:ern(Build)),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    Rest = <<"> \nPoint(x = 0, y = 0)\n[#(1, \"a\")]\n0.0\n1048576\n7\n">>,
    ?assertEqual(<<"16777216\n", Rest/binary, "17825792\n5\n", Rest/binary, "1048581\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.1: --emit-erl writes a module whose strings hold characters
%% beyond Latin-1, as Erlang's source is, in UTF-8. A regression test: the
%% source was written as a list of characters, which fails beyond 255.
emit_erl_unicode_test() ->
    Dir = tmp(),
    File = write(Dir, "dots.ern", "export fn dot() : String = \"\\u{2022}\"\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--emit-erl", "--source-root", Dir, File])),
    {ok, Source} = file:read_file(filename:join(Dir, "dots.erl")),
    ?assertMatch({_, _}, binary:match(Source, <<"\x{2022}"/utf8>>)).

%% report §11.1: `ern build --verbose` says on standard error, a line each
%% as it decides it, the source root and the build root it took, each
%% module outside the source root it read, once though two modules use it,
%% each module it compiled, and each stale .erc it removed, every path from
%% the working directory (§11.5); a module found current is not named, so
%% a build with nothing to compile says the roots and the module it read.
%% Standard output holds nothing. Written after the code, so a regression
%% test. Not covered: a module read from the build root in single-file
%% mode, which the same line names
verbose_build_test() ->
    Dir = verbose_tree(tmp()),
    in_directory(Dir, fun() ->
        Build = ["build", "--verbose", "--build-root", "build", "--load-path", "lib", "src"],
        Roots = ["source root src", "build root build", "read Store from lib/store.erc"],
        ?assertEqual({lines(Roots ++ ["compiled Checked from src/checked.ern to"
                                      " build/checked.erc",
                                      "compiled Net.Http from src/net/http.ern to"
                                      " build/net/http.erc",
                                      "compiled Main from src/main.ern to build/main.erc"]), 0},
                     standard_error_of(Build)),
        ?assertEqual({lines(Roots), 0}, standard_error_of(Build)),
        ok = file:delete("src/net/http.ern"),
        write(".", "src/main.ern",
              "export fn main() : Unit = Io.println(Int.toString(Store.size()))\n"),
        ?assertEqual({lines(Roots ++ ["compiled Main from src/main.ern to build/main.erc",
                                      "removed build/net/http.erc"]), 0},
                     standard_error_of(Build))
    end),
    ?assertEqual(<<>>, iolist_to_binary(?capturedOutput)).

%% report §11.1: a build compiles each module after the modules it uses
%% and otherwise in the order of their paths, whatever atoms the host made
%% before it, so that `--verbose` names them so: four modules of names new
%% to the host, the first using the last, in each of eight builds. A
%% regression test, written after the code: the order followed the host's
%% atom table, through the tables of the build's graph, and
%% verbose_build_test failed once the tests before it had made more atoms;
%% it does not cover the order of the shell's load
build_order_test() ->
    lists:foreach(fun(_) -> build_order() end, lists:seq(1, 8)).

build_order() ->
    Dir = tmp(),
    Unique = integer_to_list(erlang:unique_integer([positive])),
    [A, B, C, D] = [Letter ++ Unique || Letter <- ["a", "b", "c", "d"]],
    write(Dir, "src/" ++ A ++ ".ern",
          "export fn f() : Int = " ++ string:titlecase(D) ++ ".f()\n"),
    [write(Dir, "src/" ++ Name ++ ".ern", "export fn f() : Int = 1\n") || Name <- [B, C, D]],
    {Said, 0} = standard_error_of(["build", "--verbose", "--build-root", Dir ++ "/build",
                                   Dir ++ "/src"]),
    Compiled = [Namespace || Line <- string:split(Said, "\n", all),
                             ["compiled", Namespace | _] <- [string:split(Line, " ", all)]],
    ?assertEqual([string:titlecase(Name) || Name <- [D, A, B, C]], Compiled).

%% report §11.1: under --emit-erl, --verbose names the `.erl` written.
%% Written after the code, so a regression test
verbose_emit_erl_test() ->
    Dir = pair(tmp()),
    in_directory(Dir, fun() ->
        ?assertEqual({lines(["source root src", "build root build",
                             "compiled Net.Http from src/net/http.ern to build/net/http.erl",
                             "compiled Main from src/main.ern to build/main.erl"]), 0},
                     standard_error_of(["build", "--verbose", "--emit-erl", "--build-root",
                                        "build", "src"]))
    end).

%% report §11.1, §11.2: without --verbose a build, a run and a test say
%% nothing on standard error, and standard output is the program's.
%% Written after the code, so a regression test
verbose_not_asked_test() ->
    Dir = verbose_tree(tmp()),
    in_directory(Dir, fun() ->
        ?assertEqual({"", 0}, standard_error_of(["build", "--build-root", "build",
                                                 "--load-path", "lib", "src"])),
        ?assertEqual({"", 0}, standard_error_of(["run", "--load-path", "lib",
                                                 "build/main.erc"])),
        ?assertEqual({"", 0}, standard_error_of(["test", "--load-path", "lib",
                                                 "build/checked.erc"]))
    end),
    ?assertEqual(<<"/33\ncounted: passed\n">>, iolist_to_binary(?capturedOutput)).

%% A library under lib/, built there, and under src/ a program whose two
%% modules use it and a module of tests that uses it.
verbose_tree(Dir) ->
    write(Dir, "lib/store.ern", "export fn size() : Int = 3\n"),
    write(Dir, "src/net/http.ern",
          "export fn path() : String = \"/\" <> Int.toString(Store.size())\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Net.Http.path() <> Int.toString(Store.size()))\n"),
    write(Dir, "src/checked.ern",
          "let counted : Test.Case(Never) =\n"
          "    Test.Case(name = \"counted\", run = fn() = Test.equal(Store.size(), 3))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/lib"])),
    Dir.

%% Run Run with Dir the working directory, which is put back after.
in_directory(Dir, Run) ->
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try Run() after file:set_cwd(Cwd) end.

%% A job run with its standard error captured apart from its standard
%% output, which EUnit captures: what it wrote there, and its status.
standard_error_of(Args) ->
    Self = self(),
    Device = spawn(fun() -> capture(Self, []) end),
    Status = ern_cli:ern(Args, Device),
    Device ! {done, self()},
    receive {captured, Text} -> {Text, Status} end.

%% Lines as a stream holds them, each ended.
lines(Lines) ->
    lists:append([Line ++ "\n" || Line <- Lines]).

%% report §11.1, §11.5: an error is file:line:column: text, status 1
compile_error_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:38: the argument does not fit Io.println:"
                   " expected String, found Int\n"
                   "1 | export fn main() : Unit = Io.println(1)\n"
                   "  |                           ---------- Io.println : (String) -> Unit\n"
                   "  |                                      ^\n\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertNot(filelib:is_regular(filename:join(Dir, "bad.erc"))).

%% report §11.5: --short-errors is the first line alone
errors_short_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--short-errors", "--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:38: the argument does not fit Io.println:"
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
    write(Dir, "bad.ern", "export fn main() : Unit = Io.println(1)\n"),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(1, build_err(["--short-errors", "bad.ern"])),
        ?assertMatch(<<"bad.ern:1:38: ", _/binary>>, iolist_to_binary(?capturedOutput))
    after
        file:set_cwd(Cwd)
    end.

%% report §8.6, §7.4: a fault in main is reported on stderr with its
%% cause, status 1; report §7.3, §11.2, Appendix E.21: beneath the line its
%% trace, a frame a line indented by four spaces, the innermost first, the
%% host's division and then main's frame by its name and its line, the
%% outermost of the program's, with which the trace ends. A regression
%% test of the trace, written after the code, where a cause of §7.4 had
%% none
fault_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() : Unit = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "boom.erc")])),
    ?assertMatch([<<"Boom.main faulted: division by zero">>, <<"    erlang:'div'/2">>,
                  <<"    Boom.main:3">>, <<>>],
                 binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global])).

%% What was written, without the trace beneath each fault's line, its
%% frames each indented by four spaces (report §11.2), which fault_test
%% reads.
untraced(Written) ->
    Lines = binary:split(iolist_to_binary(Written), <<"\n">>, [global]),
    iolist_to_binary(lists:join(<<"\n">>, [Line || Line <- Lines, not is_frame(Line)])).

is_frame(<<"    ", _/binary>>) -> true;
is_frame(_) -> false.

%% report §11.2, §6.9: `ern run` reports every fault of every process on
%% standard error as it happens, a worker's and a restart's among them,
%% and the program goes on; the entry process's return is status 0. A
%% regression test for B4; it does not cover a system process's fault,
%% which no program can bring about
worker_faults_test() ->
    Dir = tmp(),
    File = write(Dir, "workers.ern",
                 "type Msg = Died(Down)\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    let limit = RestartLimit(restarts = 1, within = 60000);\n"
                 "    let _ = spawnMonitored(restarting(limit, fn() =\n"
                 "        Io.println(Int.toString(1 / List.size([])))), Died);\n"
                 "    receive { Died(_) -> Io.println(\"done\") }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_err(["run", filename:join(Dir, "workers.erc")])),
    %% standard error's lines and standard output's are two processes'
    %% writes, which nothing orders between them
    ?assertEqual(lists:sort([<<"Workers.main:4 faulted, restarted: division by zero">>,
                             <<"Workers.main:4 faulted: division by zero">>, <<"done">>]),
                 lists:sort(binary:split(untraced(?capturedOutput), <<"\n">>,
                                         [global, trim]))).

%% report §11.2, §7.3, §7.4: beneath a foreign function's raise the fault
%% line has its trace, as every fault's has, naming first the function
%% that raised, as the host names it. A regression test: the stack was
%% dropped, and a failure of the runtime named no module and no line.
fault_stack_test() ->
    Dir = tmp(),
    File = write(Dir, "raise.ern",
                 "foreign fn pick(i : Int, t : Int) : Int = \"erlang:element/2\"\n"
                 "export fn main() : Unit = Io.println(Int.toString(pick(5, 3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "raise.erc")])),
    [First, Second | _] = binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global]),
    ?assertEqual(<<"Raise.main faulted: foreign function erlang:element/2 raised error:badarg">>,
                 First),
    ?assertEqual(<<"    erlang:element/2">>, Second).

%% report §7.4, §11.2, Appendix E.21: a foreign function's return that does
%% not match its declared type faults with a cause that names the host's
%% function as a raise's cause does, and the trace is as for any fault the
%% runtime raises: the function has returned when its return is checked,
%% so no frame of it is in the trace, the runtime's frame that raises is
%% left out, and the trace is main's frame. A regression test, written
%% after the code, its runtime's frame taken out 2026-10-23 with the rule;
%% it does not cover a return checked in place, a word's, whose trace
%% raise_has_line_test reads
foreign_return_cause_test() ->
    Dir = tmp(),
    File = write(Dir, "abs.ern",
                 "foreign fn abs(n : Int) : String = \"erlang:abs/1\"\n"
                 "export fn main() : Unit = Io.println(abs(-3))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "abs.erc")])),
    ?assertMatch([<<"Abs.main faulted: the return of foreign function erlang:abs/1 does not match"
                    " String">>,
                  <<"    Abs.main:2">>],
                 binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global, trim])).

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
    %% report §11.4: a function shows its declaration, a parameter written
    %% as a pattern with its type alone
    Expect(<<"## Shapes.put\n\n```ernest\nShapes.put(x : a, Box(a)) : Box(a)\n```\n\n"
             "Put x in the box.\n">>),
    %% report §4.2: a member is shown under its type
    Expect(<<"## Shapes.Box.compare\n\n```ernest\n"
             "Shapes.Box.compare(Box(a), Box(a)) : Ordering\n```\n\nBy size.\n">>),
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

%% report §11.4: a file that is neither a source nor a compiled module is
%% refused for both. A regression test: the refusal named .ern alone
doc_neither_test() ->
    Dir = tmp(),
    Notes = write(Dir, "notes.txt", "notes\n"),
    ?assertEqual(1, ern_err(["doc", Notes])),
    ?assertEqual(<<"ern doc: ", (list_to_binary(ern_build:shown(Notes)))/binary,
                   " ends in neither .ern nor .erc\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.4: `ern doc --man` writes the page as a manual page: the
%% page's last line a comment at the head of the source, the header, the
%% NAME line of the module's first sentence without its `since` line, the
%% page after its title under DESCRIPTION, and a declaration a subsection.
%% Written after the code, a regression test; how roff lays out each block
%% is libs/markdown's to test, and that man renders the pages is
%% ern_manual_tests's.
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

%% report §11.4, Appendix G.2: a table in a doc block is on its module's
%% page, as written in CommonMark and laid out in columns in a manual page.
%% `ern doc --man` lays it out with libs/markdown, whose layout reads
%% Terminal.width's table, a top-level binding, which has its value only
%% where the library runs as a program runs it. Written before the fix: the
%% manual page faulted, the binding having no value under `ern doc`
doc_table_test() ->
    Dir = tmp(),
    File = write(Dir, "sizes.ern",
                 "/// Sizes, in a table.\n"
                 "///\n"
                 "/// | Name | Count |\n"
                 "/// | :--- | ----: |\n"
                 "/// | one | 1 |\n"
                 "///\n"
                 "/// since 0.1.0\n"
                 "\n"
                 "/// One.\n"
                 "export fn one() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", Dir, File])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"| Name | Count |\n| :--- | ----: |\n| one | 1 |\n">>)),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--source-root", Dir, File])),
    Rows = <<".nf\n\\fBName\\fR │ \\fBCount\\fR\n─────┼──────\none  │     1\n.fi\n"/utf8>>,
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput), Rows)).

%% report §11.1, §11.4: a compiled module may come from anywhere, so what
%% its chunks say is read as data: a source's path with a line feed in it
%% is written on the manual page's comment line with the line feed as an
%% escape, and a chunk that holds a function is no chunk of the compiler's.
%% A regression test: the name ended the comment and its next line was a
%% request of the page's, and the host decoded whatever a chunk held
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
    Rewritten("ErnI", fun(Chunk) ->
                          (binary_to_term(Chunk))#{source_path => <<"shapes.ern\n.so /etc/passwd">>}
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
%% kept. A regression test: the page stayed, out of the index; and the
%% manual page of a module at the root stayed, its place compared as
%% `./Ernest.Top.3ern`
doc_sweeps_pages_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Extra = write(Dir, "src/net/extra.ern", "export fn two() : Int =\n    2\n"),
    Top = write(Dir, "src/top.ern", "/// A module at the root.\n///\n/// since 0.1.0\n\n"
                                     "export fn three() : Int =\n    3\n"),
    Document = fun(Args) ->
                   ?assertEqual(0, ern_cli:ern(["doc" | Args]
                                               ++ ["--build-root", BuildRoot, SourceRoot]))
               end,
    Document([]),
    Document(["--man"]),
    %% report §11.4: `ern doc` writes pages and nothing else; a regression
    %% test, a directory's pages wrote and swept the build's .erc
    ?assertEqual([], filelib:wildcard(filename:join(BuildRoot, "**/*.erc"))),
    Notes = write(BuildRoot, "net/notes.md", "# Ernest module Net.Gone\n"),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/extra.md"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "Ernest.Top.3ern"))),
    ok = file:delete(Extra),
    ok = file:delete(Top),
    Document([]),
    Document(["--man"]),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "Ernest.Top.3ern"))),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "top.md"))),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/extra.md"))),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Extra.3ern"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/http.md"))),
    ?assert(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Http.3ern"))),
    ?assert(filelib:is_regular(Notes)),
    {ok, Index} = file:read_file(filename:join(BuildRoot, "index.md")),
    ?assertEqual(nomatch, binary:match(Index, <<"Extra">>)).

%% report §11.4: a run of `ern doc` removes the documents and the pages
%% of a module whose source is gone whichever kind it writes, a run of
%% `--man` rewrites index.md where it is there so that it lists no module
%% gone, and `--verbose` says each module compiled or read and each
%% document or page written or removed. A regression test (T8, T20),
%% written after the code: each run swept its own kind alone, the index
%% kept the module, and `ern doc` took no --verbose
doc_sweeps_both_kinds_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Extra = write(Dir, "src/net/extra.ern", "export fn two() : Int =\n    2\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", BuildRoot, SourceRoot])),
    ok = file:delete(Extra),
    {Said, 0} = in_directory(Dir, fun() ->
                                      standard_error_of(["doc", "--verbose", "--build-root",
                                                         "build", "src"])
                                  end),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/Ernest.Net.Extra.3ern"))),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/extra.md"))),
    Lines = unicode:characters_to_binary(Said),
    [?assertMatch({_, _}, binary:match(Lines, Line))
     || Line <- [<<"removed build/net/extra.md\n">>,
                 <<"removed build/net/Ernest.Net.Extra.3ern\n">>]],
    %% a module whose source is gone since the last CommonMark run, swept
    %% by a run of --man, leaves the index too
    Gone = write(Dir, "src/net/gone.ern", "export fn three() : Int =\n    3\n"),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
    {ok, Before} = file:read_file(filename:join(BuildRoot, "index.md")),
    ?assertMatch({_, _}, binary:match(Before, <<"Net.Gone">>)),
    ok = file:delete(Gone),
    ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", BuildRoot, SourceRoot])),
    ?assertNot(filelib:is_regular(filename:join(BuildRoot, "net/gone.md"))),
    {ok, After} = file:read_file(filename:join(BuildRoot, "index.md")),
    ?assertEqual(nomatch, binary:match(After, <<"Net.Gone">>)),
    ?assertMatch({_, _}, binary:match(After, <<"Net.Http">>)),
    %% a run that writes and compiles says so, of a source newer than its
    %% page, as make compares times, to the second
    Http = filename:join(SourceRoot, "net/http.ern"),
    {ok, Text} = file:read_file(Http),
    ok = file:write_file(Http, [Text, "\nexport fn four() : Int =\n    4\n"]),
    ok = file:write_file_info(Http, #file_info{mtime = erlang:system_time(second) + 2},
                              [{time, posix}]),
    {Written, 0} = in_directory(Dir, fun() ->
                                         standard_error_of(["doc", "--verbose", "--build-root",
                                                            "build", "src"])
                                     end),
    [?assertMatch({_, _}, binary:match(unicode:characters_to_binary(Written), Line))
     || Line <- [<<"compiled Net.Http from src/net/http.ern\n">>,
                 <<"wrote build/net/http.md\n">>]].

%% report §11.4: `ern doc src-dir`, with --man or without, writes a
%% module's page only where none is there or the one there is older than
%% the module's source or its .erc in build-root, and index.md only where
%% its text would differ. A page is given a time ahead of all it is made
%% from to be current; one left alone keeps that time, and a manual page
%% left alone was laid out by no runtime.
doc_writes_outdated_pages_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Document = fun() ->
                   ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
                   ?assertEqual(0, ern_cli:ern(["doc", "--man", "--build-root", BuildRoot,
                                                SourceRoot]))
               end,
    Http = [filename:join(BuildRoot, "net/http.md"),
            filename:join(BuildRoot, "net/Ernest.Net.Http.3ern")],
    Main = [filename:join(BuildRoot, "main.md"), filename:join(BuildRoot, "Ernest.Main.3ern")],
    Index = filename:join(BuildRoot, "index.md"),
    Ahead = os:system_time(second) + 3600,
    Document(),
    [set_modified(File, Ahead) || File <- [Index | Http ++ Main]],
    Document(),
    ?assertEqual([Ahead, Ahead, Ahead, Ahead], [modified(File) || File <- Http ++ Main]),
    %% the index's text is the same, so it is left as it is; this line
    %% written 2026-10-16, after the code, a regression test
    ?assertEqual(Ahead, modified(Index)),
    %% the module's source newer than its pages
    set_modified(filename:join(SourceRoot, "net/http.ern"), Ahead + 1),
    Document(),
    ?assert(lists:all(fun(File) -> modified(File) < Ahead end, Http)),
    ?assertEqual([Ahead, Ahead], [modified(File) || File <- Main]),
    %% the module's .erc, which `ern build` wrote in build-root, newer
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, SourceRoot])),
    set_modified(filename:join(BuildRoot, "main.erc"), Ahead + 1),
    [set_modified(File, Ahead + 1) || File <- Http],
    Document(),
    ?assert(lists:all(fun(File) -> modified(File) < Ahead end, Main)),
    ?assertEqual([Ahead + 1, Ahead + 1], [modified(File) || File <- Http]).

%% report §11.4: index.md is written where its text would differ from the
%% one there: a module added changes it, and a link at its place is no
%% index and is replaced. A regression test, written 2026-10-16, after the
%% code; not covered: an index its owner may not write, which is refused
%% as a page is
doc_writes_index_where_it_differs_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Index = filename:join(BuildRoot, "index.md"),
    Document = fun() ->
                   ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot]))
               end,
    Document(),
    Ahead = os:system_time(second) + 3600,
    set_modified(Index, Ahead),
    write(Dir, "src/util.ern", "export fn one() : Int =\n    1\n"),
    Document(),
    ?assert(modified(Index) < Ahead),
    {ok, Text} = file:read_file(Index),
    ?assertMatch({_, _}, binary:match(Text, <<"- [Util](util.md)\n">>)),
    Other = write(Dir, "other.md", Text),
    ok = file:delete(Index),
    ok = file:make_symlink(Other, Index),
    Document(),
    ?assertMatch({ok, #file_info{type = regular}}, file:read_link_info(Index)),
    ?assertEqual({ok, Text}, file:read_file(Index)).

%% report §11.4: a module whose .erc in build-root is as new as its source
%% is read from the .erc and not compiled again, and one whose source is
%% newer is compiled. The source is changed under a .erc given a later
%% time, so that a page made from the .erc and one made from the source
%% differ. A regression test, written 2026-10-16, after the code; a
%% manual page is read from the .erc by the same code, and is not covered
doc_reads_current_erc_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, SourceRoot])),
    Source = filename:join(SourceRoot, "net/http.ern"),
    {ok, Old} = file:read_file(Source),
    ok = file:write_file(Source, ["/// Requests, as the source says now.\n\n", Old]),
    Now = os:system_time(second),
    set_modified(Source, Now - 10),
    set_modified(filename:join(BuildRoot, "net/http.erc"), Now - 5),
    Page = filename:join(BuildRoot, "net/http.md"),
    Said = fun() ->
                   ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
                   {ok, Text} = file:read_file(Page),
                   binary:match(Text, <<"as the source says now">>) =/= nomatch
           end,
    ?assertNot(Said()),
    set_modified(Source, Now + 3600),
    ?assert(Said()).

%% report §11.4: where every document or page is as new as what it is made
%% from, nothing is compiled: a source that no longer parses, older than
%% its page and its .erc, is not read, and the job succeeds with every
%% page left as it is. Once its page is older than it, it is compiled and
%% the job fails. A regression test, written 2026-10-16, after the code
doc_compiles_nothing_where_current_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", BuildRoot, SourceRoot])),
    Document = fun(Args) ->
                   ern_err(["doc" | Args] ++ ["--build-root", BuildRoot, SourceRoot])
               end,
    ?assertEqual(0, Document([])),
    ?assertEqual(0, Document(["--man"])),
    Source = filename:join(SourceRoot, "main.ern"),
    ok = file:write_file(Source, "export fn main( : Unit = ()\n"),
    Past = os:system_time(second) - 3600,
    set_modified(Source, Past),
    Pages = [filename:join(BuildRoot, Name) || Name <- ["main.md", "Ernest.Main.3ern"]],
    Written = [modified(File) || File <- Pages],
    ?assertEqual(0, Document([])),
    ?assertEqual(0, Document(["--man"])),
    ?assertEqual(Written, [modified(File) || File <- Pages]),
    set_modified(Source, os:system_time(second) + 3600),
    ?assertEqual(1, Document([])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"main.ern:1:">>)).

%% report §11.4, §11.1: a .erc at a module's place that is not the module's,
%% compiled from another source or holding another module, is not read
%% for its page, which is made from the module compiled. A regression
%% test, written 2026-10-16, after the code; it covers a .erc compiled from
%% another source, and not one holding another module or one this
%% toolchain does not read, which the same check refuses
doc_reads_only_the_modules_erc_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Elsewhere = write(Dir, "elsewhere/main.ern",
                      "/// Another Main, compiled from elsewhere.\n\n"
                      "export fn two() : Int =\n    2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", filename:dirname(Elsewhere),
                                 "--build-root", BuildRoot, Elsewhere])),
    set_modified(filename:join(SourceRoot, "main.ern"), os:system_time(second) - 3600),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
    {ok, Page} = file:read_file(filename:join(BuildRoot, "main.md")),
    ?assertEqual(nomatch, binary:match(Page, <<"compiled from elsewhere">>)),
    ?assertMatch({_, _}, binary:match(Page, <<"## Main.main">>)).

%% report §11.4: a page older than any file of the toolchain's own code is
%% written again, though its module's source is older than it and no .erc
%% is there; the code the job runs, ern_cli's, is one such file
doc_writes_pages_older_than_toolchain_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Page = filename:join(BuildRoot, "main.md"),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
    Toolchain = modified(code:which(ern_cli)),
    set_modified(filename:join(SourceRoot, "main.ern"), Toolchain - 2),
    set_modified(Page, Toolchain - 1),
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", BuildRoot, SourceRoot])),
    ?assert(modified(Page) > Toolchain - 1).

%% report §11.4: a manual page older than libs/markdown's compiled code,
%% which lays it out, is written again, and a document in CommonMark, which
%% it does not lay out, is not. The code is given a time ahead of the
%% pages' by loading a copy of it, so that the tree's is not touched.
doc_writes_pages_older_than_markdown_test() ->
    Dir = pair(tmp()),
    SourceRoot = filename:join(Dir, "src"),
    BuildRoot = filename:join(Dir, "build"),
    Document = fun(Args) ->
                   ?assertEqual(0, ern_cli:ern(["doc" | Args]
                                               ++ ["--build-root", BuildRoot, SourceRoot]))
               end,
    Page = filename:join(BuildRoot, "Ernest.Main.3ern"),
    Markdown = filename:join(BuildRoot, "main.md"),
    Document([]),
    Document(["--man"]),
    Ahead = os:system_time(second) + 3600,
    set_modified(Page, Ahead),
    set_modified(Markdown, Ahead),
    with_markdown_modified(Ahead + 1, Dir, fun() -> Document([]), Document(["--man"]) end),
    ?assert(modified(Page) < Ahead),
    ?assertEqual(Ahead, modified(Markdown)).

%% report §9, §11.4: the prelude's page, which no source of the directory
%% makes, is written where it is older than the toolchain's code, or, as a
%% manual page, than libs/markdown's, and is otherwise left alone. A file
%% at its place stands for a page, given its time.
prelude_pages_follow_code_test_() ->
    {timeout, 120, fun prelude_pages_follow_code/0}.

prelude_pages_follow_code() ->
    BuildRoot = tmp(),
    Document = fun(Args) ->
                   ?assertEqual(0, ern_cli:ern(["doc" | Args]
                                               ++ ["--build-root", BuildRoot,
                                                   "../../../src/stdlib"]))
               end,
    Ahead = os:system_time(second) + 3600,
    Prelude = write(BuildRoot, "prelude.md", "kept\n"),
    set_modified(Prelude, Ahead),
    Document([]),
    ?assertEqual({ok, <<"kept\n">>}, file:read_file(Prelude)),
    set_modified(Prelude, modified(code:which(ern_cli)) - 1),
    Document([]),
    ?assertMatch({ok, <<"# Ernest prelude\n", _/binary>>}, file:read_file(Prelude)),
    Manual = write(BuildRoot, "Ernest.Prelude.3ern", "kept\n"),
    set_modified(Manual, Ahead),
    with_markdown_modified(Ahead + 1, tmp(), fun() -> Document(["--man"]) end),
    ?assertMatch({ok, <<".\\\" Generated by ern ", _/binary>>}, file:read_file(Manual)).

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
                                      "../../../src/stdlib"])),
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
    %% Erlang's own documentation reader finds it, in a copy of the module
    %% under its Erlang name on the code path
    ErlangModule = ern_namespace:erlang_module(['Shapes']),
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
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", Dir, "../../../src/stdlib"])),
    {ok, Index} = file:read_file(filename:join(Dir, "index.md")),
    ?assertMatch(<<"# Modules\n\n- [Prelude](prelude.md)\n", _/binary>>, Index),
    {ok, Page} = file:read_file(filename:join(Dir, "prelude.md")),
    ?assertMatch(<<"# Ernest prelude\n\n*Since 0.1.0.*", _/binary>>, Page),
    [?assertMatch({_, _}, binary:match(Page, <<"\n## ", Name/binary, "\n">>))
     || Name <- [<<"send">>, <<"Address.call">>, <<"Optional">>, <<"restarting">>, <<"Int">>]],
    ?assertMatch({_, _}, binary:match(Page, <<"from the prelude, report §9."/utf8>>)).

%% report §11.4, Appendix E.0 shape rule 6: docs/module_doc_template.md is what
%% `ern doc` renders for test/fixtures/programs/template.ern under its own
%% source root, after its marker line
doc_template_test() ->
    Source = "../../../test/fixtures/programs/template.ern",
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", filename:dirname(Source), Source])),
    Output = iolist_to_binary(?capturedOutput),
    {ok, Template} = file:read_file("../../../docs/module_doc_template.md"),
    Marker = <<"<!-- generated: ern doc --source-root test/fixtures/programs"
               " test/fixtures/programs/template.ern -->\n">>,
    [_, Generated] = binary:split(Template, Marker),
    %% the last line names the compiler's version, which is compared to itself
    ?assertEqual(without_footer(Generated), without_footer(Output)),
    %% the module and every exported declaration say since which version, E.0 shape rule 6
    {match, Sinces} = re:run(Output, "\\*Since 0\\.1\\.0\\.\\*", [global]),
    %% the module states its since, and the three declarations 0.2.0 renamed
    %% their own
    ?assertEqual(1, length(Sinces)),
    {match, Renamed} = re:run(Output, "\\*Since 0\\.2\\.0\\.\\*", [global]),
    ?assertEqual(3, length(Renamed)),
    %% every exported type has an Examples section, and the one function no
    %% module example calls, E.0 shape rule 6
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
    %% report §11.4: the last line names `ern`'s version text and the
    %% source from the working directory
    Footer = iolist_to_binary(["\n---\n\nGenerated by ern ", ern_release:version_text(), " from ",
                               ern_build:shown(Source), ".\n"]),
    ?assertEqual(Footer, binary:part(Output, byte_size(Output), -byte_size(Footer))).

without_footer(Doc) ->
    hd(binary:split(Doc, <<"\n---\n\nGenerated by ern ">>)).

%% docs/development.md, "What the toolchain accepts": every text in
%% erl/*/src or in the shell's own Ernest source that names an MVP, an
%% error's or an option's help, appears in that document's table, by its
%% first forty characters, so the table cannot drift from what the code
%% refuses. A regression test: only "in MVP n" was found, and
%% `--config-dir`'s "read from MVP 3.0" passed
mvp_refusals_listed_test() ->
    {ok, Listed} = file:read_file("../../../docs/development.md"),
    Pattern = "\"([^\"\n]*\\bMVP [0-9][^\"\n]*)\"",
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
    Sources = filelib:wildcard("../../*/src/*.erl") ++ filelib:wildcard("../../../src/shell/*.ern")
        ++ filelib:wildcard("../../../src/shell/shell/*.ern"),
    %% a name the wildcard matches may not be a readable file: an editor's
    %% lock is a dangling symlink beside the file it locks, and a person
    %% with a source open should not see a red suite
    Texts = lists:usort(lists:append([Find(Text) || Path <- Sources,
                                                    {ok, Text} <- [file:read_file(Path)]])),
    Missing = [Refusal || Refusal <- Texts,
                          binary:match(Listed, binary:part(Refusal, 0, min(40, byte_size(Refusal))))
                              =:= nomatch],
    ?assertEqual([], Missing).

%% report §11, §8.7: --version prints the version text, the top-level
%% VERSION file's content, and in the repository's build, which is no
%% release, the mark after it; the release archive's is VERSION's alone,
%% which ern_install_tests' release test holds
version_test() ->
    {ok, Version} = file:read_file("../../../VERSION"),
    ?assertEqual(0, ern_cli:ern(["--version"])),
    ?assertEqual(<<"ern ", (string:trim(Version))/binary, "-dev\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11: options are long; --help and --version stop with status 0,
%% and a job's --help lists its options
options_test() ->
    ?assertEqual(1, ern_cli:ern(["build", "-o", "x", example("hello.ern")])),
    ?assertEqual(1, build_err([])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "^ern build: a file or a directory is required\n"
                                    "Usage: ern build ")),
    ?assertEqual(0, ern_cli:ern(["--version"])),
    ?assertEqual(0, ern_cli:ern(["--help"])),
    [?assertEqual(0, ern_cli:ern([Job, "--help"]))
     || Job <- ["build", "doc", "format", "run", "test", "shell", "config", "reload", "stop"]].

%% report §11: a job's `--help` stands alone, as `ern --help` does; the
%% option parser's refusals are written in the usage's words, an option
%% given no value with its metavariable, one the job does not take with
%% the jobs that take it, and words the job does not take counted. A
%% regression test (T26, T27), written after the code: `ern build --help
%% x.ern` printed the help, and the refusals were the vendored parser's
%% own, `missing option argument: --build-root <build_root>`
job_words_test() ->
    Alone = <<"ern build: --help stands alone: ern build --help\n">>,
    Refused = [{["build", "--help", "x.ern"], Alone},
               {["build", "x.ern", "--help"], Alone},
               {["build", "--build-root"],
                <<"ern build: --build-root takes a value: --build-root build-root\n">>},
               {["build", "--check", "x.ern"],
                <<"ern build: --check is not an option of ern build; ern format takes it\n">>},
               {["build", "a.ern", "b.ern"],
                <<"ern build: one file or directory is taken, and 2 were given\n">>},
               {["test", "a.erc", "b.erc"],
                <<"ern test: one .erc or directory is taken, and 2 were given\n">>},
               {["shell", "a.erc", "b.erc"],
                <<"ern shell: one .erc or none is taken, and 2 were given\n">>},
               {["run"], <<"ern run: a .erc is required, or --config-dir for a bare node\n">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% report §11: the first word is the job, and none is refused with the jobs
%% named; an empty first word is none. A regression test of the empty
%% word, which was refused as `no job ;`
job_first_test() ->
    ?assertEqual(1, ern_err([])),
    ?assertEqual(1, ern_err(["", "x.erc"])),
    ?assertEqual(1, ern_err(["compile", "x.ern"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertEqual(2, length(binary:matches(Output, <<"ern: a job is required\nUsage: ern <job>">>))),
    ?assertEqual(nomatch, binary:match(Output, <<"no job ;">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern: no job compile; the jobs are build, doc,"
                                                " format, run, test, shell, config, reload and"
                                                " stop">>)).

%% report §11: a compiled module given first is refused with the job that
%% runs it, an option before the job with where it goes, and a spelling of
%% an earlier toolchain as any word that is no job or no option of the job
%% is. A regression test of the last: an earlier spelling was refused with
%% the one that replaced it, which the log's *A Release Carries No
%% History* took out
first_words_test() ->
    File = example("hello.ern"),
    Refused = [{["x.erc"], <<"ern: the job comes first: ern run x.erc">>},
               {["--load-path", "d", "x.erc"], <<"ern: --load-path comes after the job">>},
               {["--shell"], <<"ern: no job --shell; the jobs are">>},
               {["build", "--out-dir", "b", File],
                <<"ern build: --out-dir is not an option of ern build\n">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused],
    ?assertEqual(nomatch, binary:match(Output, <<"is now">>)).

%% report §11.2: a module without tests says so, and one two of whose tests
%% have one name is refused before any runs. A regression test: the first
%% printed nothing, and the second two lines no reader could tell apart
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
shell_main_without_file_test() ->
    ?assertEqual(1, ern_err(["shell", "--main", "Foo.bar"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"ern shell: --main names the function to spawn from"
                                        " the file the shell loads, and no file is given">>)).

%% report §11: an option is matched by its whole name, a flag takes no
%% value, and `--version` and `--help` stand alone. A regression test:
%% `--emit-erl=x` was taken for `--emit`
option_words_test() ->
    Refused = [{["run", "--errors", "short", "a.erc"],
                <<"ern run: --errors is not an option of ern run\n">>},
               {["build", "--emit-erl=x", "a.ern"], <<"--emit-erl=x: --emit-erl takes no value">>},
               {["--version", "--help"], <<"ern: --version stands alone: ern --version">>},
               {["-v"], <<"ern: no job -v; the jobs are">>},
               {["--load-path=d", "x.erc"],
                <<"ern: --load-path comes after the job: ern <job> --load-path">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% report §11.1, §11.5: a directory build compiles every module but one that
%% uses a module that failed, and reports every failure, a module that
%% does not parse among them. A regression test: it stopped at the first
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
%% the test runner's internal name stood. A regression test; the shell's
%% start is ern_shell_tests' faulting_binding_named
faulting_binding_named_test() ->
    Dir = tmp(),
    File = write(Dir, "init.ern", "fn zero() : Int = List.size([])\n\n"
                                  "let bad : Int = 1 / zero()\n\n"
                                  "export fn main() : Unit ="
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
    ?assertEqual(nomatch, binary:match(Output, <<"$tests">>)),
    %% a binding the host's own names collide with is named as written: a
    %% regression test, `record_info` was named `record_info$`
    Host = tmp(),
    HostFile = write(Host, "init.ern", "fn zero() : Int = List.size([])\n\n"
                                       "let record_info : Int = 1 / zero()\n\n"
                                       "export fn main() : Unit ="
                                       " Io.println(Int.toString(record_info))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Host, HostFile])),
    ?assertEqual(1, ern_err(["run", filename:join(Host, "init.erc")])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"Init.record_info:3 faulted: division by zero">>)).

%% report §11: an option is given once, a `-path` one excepted, with its
%% value as the next word, and never an empty one. A regression test: a
%% repeat took its first value, and `--name=value` and an empty value were
%% accepted
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
    write(Dir, "app/main.ern", "export fn main() : Unit ="
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
    write(Dir, "src/main.ern", "export fn main() : Unit ="
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
%% not write over a .erc of another namespace, naming --source-root where
%% the build was given none and the file's removal where it was; a build
%% that uses a module whose .erc holds another names that, and not the
%% source the other was compiled from; and `ern run` refuses a file that
%% holds another module than its path names. A regression test (T4): the
%% build replaced it, and the run failed in the host's loader; and (T5,
%% after the code) the build named a source of the other module's as gone,
%% and named --source-root where it was given
other_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/shape.ern", "export fn area(n : Int) : Int = n * n\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit ="
                               " Io.println(Int.toString(Geo.Shape.area(3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    ?assertEqual(1, build_err(["--source-root", Dir, Dir ++ "/src/geo/shape.ern"])),
    in_directory(Dir, fun() -> ?assertEqual(1, build_err(["src/geo/shape.ern"])) end),
    ok = file:delete(Dir ++ "/src/geo/shape.erc"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Dir ++ "/src/geo/shape.ern"])),
    ?assertEqual(1, build_err(["--source-root", Dir ++ "/src", Dir ++ "/src/main.ern"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/src/main.erc"])),
    Output = iolist_to_binary(?capturedOutput),
    Shape = list_to_binary(Dir ++ "/src/geo/shape.erc"),
    [?assertMatch({_, _}, binary:match(Output, Line))
     || Line <- [<<Shape/binary, " holds Geo.Shape, not Src.Geo.Shape, and a build writes over no"
                   " other module's file; remove it to build Src.Geo.Shape there\n">>,
                 <<"ern build: src/geo/shape.erc holds Geo.Shape, not Src.Geo.Shape; name"
                   " Src.Geo.Shape's source root with --source-root\n">>,
                 <<Shape/binary, " holds Src.Geo.Shape, not Geo.Shape; remove it, and build"
                   " Geo.Shape from its source root\n">>]],
    ?assertEqual(nomatch, binary:match(Output, <<"no longer exists">>)).

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

%% report §11.2: `ern run --verbose` and `ern test --verbose` say on
%% standard error each module they read, as they read it, with its file
%% from the working directory (§11.5), the file given among them, and the
%% standard library's aside, which the program uses and which a test of
%% one of its modules reads; `ern test` over a directory names each module
%% as each file's run reads it, a module two files use once for each.
%% Standard output stays the program's. Written after the code, so a
%% regression test. A node's start, which reads every module of its load
%% path through the same load, is ern_nodes_tests' verbose_node_start
verbose_run_test() ->
    Dir = verbose_tree(tmp()),
    in_directory(Dir, fun() ->
        ?assertEqual(0, ern_cli:ern(["build", "--build-root", "build", "--load-path", "lib",
                                     "src"])),
        ?assertEqual({lines(["read Main from build/main.erc",
                             "read Net.Http from build/net/http.erc",
                             "read Store from lib/store.erc"]), 0},
                     standard_error_of(["run", "--verbose", "--load-path", "lib",
                                        "build/main.erc"])),
        ?assertEqual({lines(["read Checked from build/checked.erc",
                             "read Store from lib/store.erc"]), 0},
                     standard_error_of(["test", "--verbose", "--load-path", "lib",
                                        "build/checked.erc"])),
        ?assertEqual({lines(["read Checked from build/checked.erc",
                             "read Store from lib/store.erc",
                             "read Main from build/main.erc",
                             "read Net.Http from build/net/http.erc",
                             "read Store from lib/store.erc",
                             "read Net.Http from build/net/http.erc",
                             "read Store from lib/store.erc"]), 0},
                     standard_error_of(["test", "--verbose", "--load-path", "lib", "build"]))
    end),
    Bool = filename:join(ern_prelude:stdlib_directory(), "bool.erc"),
    ?assertEqual({"", 0}, standard_error_of(["test", "--verbose", Bool])),
    %% the library's module has no tests, and its doc examples run
    ?assertMatch(<<"/33\ncounted: passed\nChecked\ncounted: passed\nBool example 1: passed\n",
                   _/binary>>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2: --main picks another exported entry point of the module
%% given, and one of another module is refused with both; one that takes
%% arguments is refused (§8.1)
main_option_test() ->
    Dir = pair(tmp()),
    write(Dir, "src/tools.ern",
          "export fn check() : Unit = Io.println(\"checked\")\n"
          "export fn twice(n : Int) : Int = 2 * n\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", "--main", "Tools.check", Dir ++ "/build/tools.erc"])),
    ?assertEqual(<<"checked\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(1, ern_cli:ern(["run", "--main", "Tools.twice", Dir ++ "/build/tools.erc"])),
    ?assertEqual(1, ern_cli:ern(["run", "--main", "check", Dir ++ "/build/tools.erc"])),
    ?assertEqual(1, ern_err(["run", "--main", "Tools.check", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"checked\nern run: --main Tools.check names a function of Tools, and the"
                   " file given is the module Main\n">>,
                 iolist_to_binary(?capturedOutput)).

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
%% `() -> Unit`, receiving or not; a function of another shape
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
    ?assertEqual(1, Launch("export let main = fn() = Io.println(\"x\")\n",
                           [])),
    ?assertEqual(1, Launch("export fn main() : Unit = Unit\n"
                           "export fn other() : Int = 3\n", ["--main", "Main.other"])),
    ?assertEqual(1, Launch("fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit = Unit\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit = Io.println(\"m\")\n", [])),
    ?assertEqual(0, Launch("export fn main() : Unit = Unit\n"
                           "export fn other() : Unit = Io.println(\"o\")\n",
                           ["--main", "Main.other"])),
    Output = iolist_to_binary(?capturedOutput),
    Refusals = [<<"Main.main is not an entry point: its type is () -> Int">>,
                <<"Main.main is not an entry point: it is a let of type () -> Unit">>,
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
          "export fn main() : Unit = Io.println(Int.toString(total))\n"),
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
          "export fn main() : Unit = Io.println(Lib.Words.shout(\"hi\"))\n"),
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
          "export fn main() : Unit = Io.println(Int.toString(Lib.Boom.zero))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"hello, world\nLib.Boom.boom:2 faulted: division by zero\n">>,
                 untraced(?capturedOutput)).

%% report §7.3, §8.6, §11.2: a faulting main is status 1
fault_status_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() : Unit = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_cli:ern(["run", filename:join(Dir, "boom.erc")])).

%% report §8.6, §11.2: the program ends when its entry process is killed,
%% printing `killed` after its site, as a fault's line names it, with
%% status 1. A regression test: it printed `fault: 'Killed'`, since only a
%% return and a fault had their own lines, and then `killed` alone, with
%% no site and, in a log, no time.
killed_entry_test() ->
    Dir = tmp(),
    File = write(Dir, "main.ern",
                 "export fn main() : Unit receiving Never = {\n"
                 "    let me = self();\n"
                 "    let _ = spawn(fn() = kill(me));\n"
                 "    receive { after 5000 -> Io.println(\"not killed\") }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "main.erc")])),
    ?assertEqual(<<"Main.main killed\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: the file must lie at the path of its namespace
misplaced_module_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/build/http.erc"),
    ?assertEqual(1, ern_cli:ern(["run", Dir ++ "/build/http.erc"])),
    ?assertEqual(1, ern_cli:ern(["run", Dir ++ "/build/nothing.erc"])).

%% report §8.7, §11.2: a run given `--config-dir` is a node, whose host the
%% launcher boots with the carrier's flags; a host booted otherwise, as a
%% test runs `ern` within its own, is refused, and so is a directory whose
%% `ernest.conf` is refused, before anything runs. A run as a node is
%% test/ern_nodes_tests.erl's
node_run_test() ->
    Dir = tmp(),
    ConfigDir = Dir ++ "/node",
    ?assertEqual(0, ern_err(["config", "--config-dir", ConfigDir])),
    write(Dir, "src/hello.ern", hello()),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Program = Dir ++ "/build/hello.erc",
    _ = ?capturedOutput,
    ?assertEqual(1, ern_err(["run", "--config-dir", ConfigDir, Program])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"ern run: the host was not started as a node, which ern"
                                        " does where the command line holds --config-dir">>)),
    ?assertNot(filelib:is_file(ConfigDir ++ "/ernest.pid")),
    ok = file:write_file(ConfigDir ++ "/ernest.conf", "{"),
    ?assertEqual(1, ern_err(["run", "--config-dir", ConfigDir, Program])),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"node/ernest.conf: is not JSON">>)).

%% report §11.3: `ern config` requires --config-dir, as `ern reload` and
%% `ern stop` do, with `--peer-dir` and without, and makes nothing without
%% it; and it creates the one directory it names, refusing a parent that
%% is not there. A regression test (T3, T13, K18), written after the code:
%% it created ./.ernest, wrote into it with `--peer-dir`, and created every
%% missing parent
config_dir_required_test() ->
    Dir = tmp(),
    Peer = filename:join(tmp(), "foo"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Peer])),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, ern_err(["config"])),
                          ?assertEqual(1, ern_err(["config", "--peer-dir", Peer])),
                          ?assertEqual(1, ern_err(["config", "--config-dir", "no/such/parent"]))
                      end),
    ?assertEqual({ok, []}, file:list_dir(Dir)),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, Part))
     || Part <- [<<"ern config: --config-dir is required: it names the configuration"
                   " directory\nUsage: ern config --config-dir dir">>,
                 <<"ern config: no/such: no such directory\n">>]],
    ?assertEqual(2, length(binary:matches(Said, <<"--config-dir is required">>))).

%% report §11.3, Appendix C: the configuration directory with no peer and
%% no service, a private key readable only by its owner and a certificate,
%% created where --config-dir names it, its public key printed; a second
%% creation fails
create_config_dir_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    {ok, Conf} = file:read_file(Dir ++ "/ernest.conf"),
    #{<<"peers">> := [], <<"services">> := #{}, <<"listen">> := <<"0.0.0.0:8654">>,
      <<"public-key">> := <<"-----BEGIN PUBLIC KEY-----", _/binary>> = Public} = json:decode(Conf),
    ?assertEqual(Public, unicode:characters_to_binary(?capturedOutput)),
    %% laid out as Appendix C shows it, a key a line in its order; a
    %% regression test, it was one line with its keys sorted
    ?assertMatch([<<"{">>, <<"  \"listen\": \"0.0.0.0:8654\",">>,
                  <<"  \"public-key\": \"-----BEGIN PUBLIC KEY-----", _/binary>>,
                  <<"  \"peers\": [],">>, <<"  \"services\": {}">>, <<"}">>, <<>>],
                 binary:split(Conf, <<"\n">>, [global])),
    ?assert(filelib:is_regular(Dir ++ "/certificate.pem")),
    {ok, #file_info{mode = Mode}} = file:read_file_info(Dir ++ "/private-key.pem"),
    ?assertEqual(8#600, Mode band 8#777),
    {ok, Pem} = file:read_file(Dir ++ "/private-key.pem"),
    ?assertMatch([{'PrivateKeyInfo', _, not_encrypted}], public_key:pem_decode(Pem)),
    ?assertEqual(1, ern_cli:ern(["config", "--config-dir", Dir])).

%% report §11.2, §8.7, §8.1: `ern run --config-dir dir` with no `.erc` is a
%% bare node, refused before it starts where its `ernest.conf` has no
%% `listen`, and given `--main`, which names a function of the file, while
%% a run with no `--config-dir` requires the file, `--main` or not. A
%% regression test, written after the code; a bare node that starts, and
%% one the launcher refuses, are test/ern_nodes_tests.erl's bare_node_test_
%% and bare_node_refused_test_
bare_node_refusals_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    Conf = filename:join(Dir, "ernest.conf"),
    {ok, Text} = file:read_file(Conf),
    ok = file:write_file(Conf, json:encode(maps:remove(<<"listen">>, json:decode(Text)))),
    ?assertEqual(1, ern_err(["run", "--config-dir", Dir])),
    ?assertEqual(1, ern_err(["run", "--config-dir", Dir, "--main", "Foo.bar"])),
    ?assertEqual(1, ern_err(["run", "--main", "Foo.bar"])),
    ?assertEqual(1, ern_err(["run"])),
    Output = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Part))
     || Part <- [<<"ern run: a bare node listens: ", (list_to_binary(Conf))/binary,
                   " has no listen\n">>,
                 <<"ern run: --main names the entry point of the file run, and no file is"
                   " given; a bare node has none\n">>]],
    ?assertEqual(2, length(binary:matches(Output, <<"ern run: a .erc is required, or --config-dir"
                                                    " for a bare node\n">>))),
    ?assertNot(filelib:is_file(filename:join(Dir, "ernest.pid"))).

%% report §11.2, §8.7: `ern reload` and `ern stop` require --config-dir,
%% and fail where its ernest.pid is not there or no node holds it, a file
%% that names a process that has ended among them, saying so; their
%% synopsis shows the option they require; `ern reload` refuses a
%% directory the node would refuse before it signals. A regression test,
%% written after the code (T15 after its fix); real nodes reload and stop
%% in test/ern_nodes_tests.erl, and a file that names a living process no
%% node holds is ern_node_tests' signaled_test's
signal_jobs_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    ?assertEqual(1, ern_err(["reload"])),
    ?assertEqual(1, ern_err(["stop", "--config-dir", Dir])),
    Ended = string:trim(os:cmd("sh -c 'echo $$'")),
    ok = file:write_file(Dir ++ "/ernest.pid", Ended ++ "\n"),
    ?assertEqual(1, ern_err(["reload", "--config-dir", Dir])),
    %% report §11.2: `ern reload` reads the directory as the node would, and
    %% refuses one the node would refuse before it signals
    ok = file:write_file(Dir ++ "/ernest.conf", "{ not json"),
    ?assertEqual(1, ern_err(["reload", "--config-dir", Dir])),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, Part))
     || Part <- [<<"ern reload: --config-dir is required: it names the configuration directory">>,
                 <<"Usage: ern reload --config-dir dir">>,
                 <<"ernest.pid: no such file: no node runs from the directory">>,
                 <<"ernest.pid: no node holds it: no node runs from the directory">>,
                 <<"ern reload: ", (list_to_binary(Dir))/binary, "/ernest.conf: is not JSON\n">>]].

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

%% report §11.3, Appendix C: two directories of one machine list each other
%% by `--listen` and `--peer-dir` alone, the four commands of the tour: each
%% peer named by its directory, its key the one its certificate certifies,
%% which its `ern config` printed, and its address its `listen`, the
%% loopback address for every interface's; `--peer-dir` prints nothing, writes
%% the peer as Appendix C lays one out, and leaves a file a node reads
config_peer_test() ->
    Dir = tmp(),
    [A, Foo] = [filename:join(Dir, Name) || Name <- ["a", "foo"]],
    [?assertEqual(0, ern_err(["config", "--config-dir" | Words]))
     || Words <- [[A], [Foo, "--listen", "127.0.0.1:8655"], [A, "--peer-dir", Foo],
                  [Foo, "--peer-dir", A]]],
    #{<<"listen">> := <<"0.0.0.0:8654">>, <<"public-key">> := KeyA, <<"services">> := #{},
      <<"peers">> := [ListedFoo]} = conf_of(A),
    #{<<"listen">> := <<"127.0.0.1:8655">>, <<"public-key">> := KeyFoo, <<"services">> := #{},
      <<"peers">> := [ListedA]} = conf_of(Foo),
    ?assertEqual(#{<<"name">> => <<"foo">>, <<"network-address">> => <<"127.0.0.1:8655">>,
                   <<"public-key">> => KeyFoo}, ListedFoo),
    ?assertEqual(#{<<"name">> => <<"a">>, <<"network-address">> => <<"127.0.0.1:8654">>,
                   <<"public-key">> => KeyA}, ListedA),
    ?assertEqual(<<KeyA/binary, KeyFoo/binary>>, unicode:characters_to_binary(?capturedOutput)),
    {ok, Text} = file:read_file(filename:join(A, "ernest.conf")),
    ?assertMatch([<<"{">>, <<"  \"listen\": \"0.0.0.0:8654\",">>,
                  <<"  \"public-key\": ", _/binary>>, <<"  \"peers\": [">>, <<"    {">>,
                  <<"      \"name\": \"foo\",">>,
                  <<"      \"network-address\": \"127.0.0.1:8655\",">>,
                  <<"      \"public-key\": ", _/binary>>, <<"    }">>, <<"  ],">>,
                  <<"  \"services\": {}">>, <<"}">>, <<>>],
                 binary:split(Text, <<"\n">>, [global])),
    [?assertMatch({configuration, _, _, _, [{peer, _, _, {{127, 0, 0, 1}, _}}], _, _, _, _},
                  ern_node:read(Node)) || Node <- [A, Foo]].

%% report §11.3, §11.7: `--listen` gives the directory's `listen`, any a
%% node takes, port 0 among them; one a node refuses is refused before
%% the directory is made, and so is a directory that exists
config_listen_test() ->
    Dir = tmp(),
    Six = filename:join(Dir, "six"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Six, "--listen", "[::]:0"])),
    ?assertMatch(#{<<"listen">> := <<"[::]:0">>}, conf_of(Six)),
    ?assertEqual(1, ern_err(["config", "--config-dir", Six, "--listen", "127.0.0.1:8655"])),
    Refused = [{"localhost:8655", "--listen names no address: localhost:8655"},
               {"8655", "--listen is not address:port: 8655"}],
    [begin
         Made = filename:join(Dir, "refused"),
         ?assertEqual(1, ern_err(["config", "--config-dir", Made, "--listen", Listen])),
         ?assertNot(filelib:is_file(Made))
     end || {Listen, _} <- Refused],
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, list_to_binary("ern config: " ++ Line ++ "\n")))
     || Line <- [Six ++ " exists" | [Line || {_, Line} <- Refused]]].

%% report §11.3: a peer's name is its directory's, the last segment of the
%% directory's absolute path, a path ending in `/` or holding `..` among
%% them; its address its `listen`, the loopback address for every
%% interface's, IPv6's in brackets, an address of one interface as it is,
%% and none where it has no `listen`, each listed last in `peers`
config_peer_address_test() ->
    Dir = tmp(),
    [A, All, One, Silent] = [filename:join(Dir, Name) || Name <- ["a", "all", "one", "silent"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", Made, "--listen", Listen]))
     || {Made, Listen} <- [{A, "[::1]:8654"}, {All, "[::]:8660"}, {One, "[fe80::1]:8661"}]],
    ?assertEqual(0, ern_err(["config", "--config-dir", Silent])),
    ok = file:write_file(filename:join(Silent, "ernest.conf"),
                         json:encode(maps:remove(<<"listen">>, conf_of(Silent)))),
    [?assertEqual(0, ern_err(["config", "--config-dir", A, "--peer-dir", Dir ++ "/" ++ Given]))
     || Given <- ["all/", "all/../one", "silent"]],
    #{<<"peers">> := Listed} = conf_of(A),
    ?assertEqual([{<<"all">>, <<"[::1]:8660">>}, {<<"one">>, <<"[fe80::1]:8661">>},
                  {<<"silent">>, none}],
                 [{Name, maps:get(<<"network-address">>, Peer, none)}
                  || #{<<"name">> := Name} = Peer <- Listed]),
    ?assertMatch({configuration, _, _, _, [_, _, {peer, <<"silent">>, _, none}], _, _, _, _},
                 ern_node:read(A)).

%% report §11.3: `--peer-dir` writes `ernest.conf` again with every other field
%% as it was, in its order, the peers listed before it kept, and the peer
%% listed last; a link to the file is followed, and stays a link
config_peer_keeps_fields_test() ->
    Dir = tmp(),
    [A, B, C] = [filename:join(Dir, Name) || Name <- ["a", "b", "c"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", Made, "--listen", Listen]))
     || {Made, Listen} <- [{A, "127.0.0.1:8654"}, {B, "127.0.0.1:8655"},
                           {C, "127.0.0.1:8656"}]],
    #{<<"public-key">> := KeyA} = conf_of(A),
    #{<<"public-key">> := KeyB} = conf_of(B),
    Elsewhere = filename:join(Dir, "a.conf"),
    ok = file:write_file(Elsewhere,
                         ["{\"utilization-interval\": 2000, \"public-key\": ", json:encode(KeyA),
                          ", \"peers\": [{\"public-key\": ", json:encode(KeyB),
                          ", \"name\": \"b\"}], \"services\": {\"counter\": [\"b\"]},"
                          " \"listen\": \"127.0.0.1:8654\", \"measures\": {\"cpu\": {}}}"]),
    Conf = filename:join(A, "ernest.conf"),
    ok = file:delete(Conf),
    ok = file:make_symlink(Elsewhere, Conf),
    ?assertEqual(0, ern_err(["config", "--config-dir", A, "--peer-dir", C])),
    ?assertMatch({ok, #file_info{type = symlink}}, file:read_link_info(Conf)),
    {ok, Text} = file:read_file(Elsewhere),
    InOrder = fun(Acc, Outer) -> {lists:reverse(Acc), Outer} end,
    {Value, ok, <<>>} = json:decode(Text, ok, #{object_finish => InOrder}),
    ?assertEqual([<<"utilization-interval">>, <<"public-key">>, <<"peers">>, <<"services">>,
                  <<"listen">>, <<"measures">>], [Name || {Name, _} <- Value]),
    ?assertMatch([{<<"utilization-interval">>, 2000}, _,
                  {<<"peers">>, [[{<<"name">>, <<"b">>}, {<<"public-key">>, KeyB}],
                                 [{<<"name">>, <<"c">>},
                                  {<<"network-address">>, <<"127.0.0.1:8656">>}, _]]},
                  {<<"services">>, [{<<"counter">>, [<<"b">>]}]}, _,
                  {<<"measures">>, [{<<"cpu">>, []}]}], Value).

%% report §11.3: `--peer-dir` is refused where `--listen` is given with it,
%% where the peer's directory holds this node's own key, the directory
%% itself among them, where a peer of its name is listed, where a listed
%% peer has its key, where its `listen` names port 0, and where its entry
%% breaks a rule of the node's, an address of the other family; each names
%% why, and the file stays as it was
config_peer_refusals_test() ->
    Dir = tmp(),
    [A, Foo, Zero, Six] = [filename:join(Dir, Name) || Name <- ["a", "foo", "zero", "six"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", Made, "--listen", Listen]))
     || {Made, Listen} <- [{A, "0.0.0.0:8654"}, {Foo, "127.0.0.1:8655"},
                           {Zero, "127.0.0.1:0"}, {Six, "[::1]:8656"}]],
    ?assertEqual(0, ern_err(["config", "--config-dir", A, "--peer-dir", Foo])),
    Copy = filename:join(Dir, "copy"),
    [] = os:cmd("cp -rp " ++ Foo ++ " " ++ Copy),
    {ok, Before} = file:read_file(filename:join(A, "ernest.conf")),
    {ok, BeforeSix} = file:read_file(filename:join(Six, "ernest.conf")),
    _ = ?capturedOutput,
    [?assertEqual(1, ern_err(["config", "--config-dir", Into | Words]))
     || {Into, Words} <- [{A, ["--peer-dir", Foo, "--listen", "127.0.0.1:8657"]},
                          {A, ["--peer-dir", A]}, {A, ["--peer-dir", Foo]},
                          {A, ["--peer-dir", Copy]}, {A, ["--peer-dir", Zero]},
                          {Six, ["--peer-dir", Foo]}]],
    ?assertEqual({ok, Before}, file:read_file(filename:join(A, "ernest.conf"))),
    ?assertEqual({ok, BeforeSix}, file:read_file(filename:join(Six, "ernest.conf"))),
    Said = unicode:characters_to_binary(?capturedOutput),
    Conf = fun(Made) -> ern_build:shown(filename:join(Made, "ernest.conf")) end,
    [?assertMatch({_, _}, binary:match(Said, list_to_binary("ern config: " ++ Line ++ "\n")))
     || Line <- ["--listen and --peer-dir are not given together: --peer-dir creates no directory",
                 ern_build:shown(A) ++ " has this node's own key, and a node is no peer of itself",
                 Conf(A) ++ ": a peer is named \"foo\" already",
                 Conf(A) ++ ": the peer \"foo\" has the key of " ++ ern_build:shown(Copy)
                 ++ " already",
                 Conf(Zero) ++ ": listen names port 0, which the host picks as the node starts,"
                 " so no network-address can name it",
                 Conf(Six) ++ ": peer \"foo\"'s network-address \"127.0.0.1:8655\" is IPv4, and"
                 " this node runs over IPv6, its listener's family"]],
    ?assertMatch({_, _}, binary:match(Said, <<"Usage: ern config --config-dir dir">>)).

%% report §11.7: given `--peer-dir`, `ern config`'s `--config-dir` names a
%% directory that is there, and `--peer-dir` a configuration directory, which
%% holds `ernest.conf` and a certificate; one that names none is refused
%% with the directory and the option, and nothing is made
config_peer_directories_test() ->
    Dir = tmp(),
    [A, Foo] = [filename:join(Dir, Name) || Name <- ["a", "foo"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", Made])) || Made <- [A, Foo]],
    Missing = filename:join(Dir, "missing"),
    Uncertified = filename:join(Dir, "uncertified"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Uncertified])),
    ok = file:delete(filename:join(Uncertified, "certificate.pem")),
    Plain = filename:join(Dir, "plain"),
    ok = file:make_dir(Plain),
    _ = ?capturedOutput,
    [?assertEqual(1, ern_err(["config", "--config-dir", Into, "--peer-dir", Peer]))
     || {Into, Peer} <- [{Missing, Foo}, {A, Missing}, {A, Uncertified}, {A, Plain}]],
    ?assertNot(filelib:is_file(Missing)),
    ?assertMatch(#{<<"peers">> := []}, conf_of(A)),
    Said = unicode:characters_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Said, list_to_binary("ern config: " ++ Line ++ "\n")))
     || Line <- [Missing ++ ": no such directory, which --config-dir names"
                 | [Peer ++ ": no configuration directory, which --peer-dir names"
                    || Peer <- [Missing, Uncertified, Plain]]]].

%% report §11.3, §8.7: the peer's directory, its `ernest.conf` and its
%% certificate are read as a node reads its own: a file anyone may write,
%% a file that is not JSON and a certificate that is none are refused,
%% each naming the peer's file, and nothing is written
config_peer_read_as_a_node_test() ->
    Dir = tmp(),
    [A, Open, Broken, Uncertified] = [filename:join(Dir, Name)
                                      || Name <- ["a", "open", "broken", "uncertified"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", Made]))
     || Made <- [A, Open, Broken, Uncertified]],
    ok = file:change_mode(filename:join(Open, "ernest.conf"), 8#666),
    ok = file:write_file(filename:join(Broken, "ernest.conf"), "{"),
    ok = file:write_file(filename:join(Uncertified, "certificate.pem"), "none"),
    {ok, Before} = file:read_file(filename:join(A, "ernest.conf")),
    _ = ?capturedOutput,
    [?assertEqual(1, ern_err(["config", "--config-dir", A, "--peer-dir", Peer]))
     || Peer <- [Open, Broken, Uncertified]],
    ?assertEqual({ok, Before}, file:read_file(filename:join(A, "ernest.conf"))),
    Said = unicode:characters_to_binary(?capturedOutput),
    Shown = fun(Made, File) -> ern_build:shown(filename:join(Made, File)) end,
    [?assertMatch({_, _}, binary:match(Said, list_to_binary("ern config: " ++ Line ++ "\n")))
     || Line <- [Shown(Open, "ernest.conf") ++ " may be written by anyone beyond its owner and"
                 " group",
                 Shown(Broken, "ernest.conf") ++ ": is not JSON",
                 Shown(Uncertified, "certificate.pem") ++ ": is not one certificate in PEM"]].

%% report §11.3: `--peer-dir` lists the peer in the directory a relative
%% `--config-dir` names from the working directory
config_peer_relative_dir_test() ->
    Dir = tmp(),
    Foo = filename:join(Dir, "foo"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Foo, "--listen", "127.0.0.1:8655"])),
    %% the job run once from here, since the code path is relative to this
    %% directory, and a module the job loads after the move is not found
    Here = filename:join(Dir, "here"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Here])),
    ?assertEqual(0, ern_err(["config", "--config-dir", Here, "--peer-dir", Foo])),
    in_directory(Dir, fun() ->
                          ?assertEqual(0, ern_err(["config", "--config-dir", "a"])),
                          ?assertEqual(0, ern_err(["config", "--config-dir", "a",
                                                   "--peer-dir", "foo"]))
                      end),
    ?assertMatch(#{<<"peers">> := [#{<<"name">> := <<"foo">>,
                                     <<"network-address">> := <<"127.0.0.1:8655">>}]},
                 conf_of(filename:join(Dir, "a"))).

%% A configuration directory's `ernest.conf`, decoded.
conf_of(ConfigDir) ->
    {ok, Text} = file:read_file(filename:join(ConfigDir, "ernest.conf")),
    json:decode(Text).

captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> Output end.
