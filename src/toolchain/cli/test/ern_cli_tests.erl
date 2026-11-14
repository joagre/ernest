%% The command line, report §11: every job of `ern`, build, doc, format,
%% run, test, shell and config, run in this node as the launcher runs it,
%% with what each refuses, writes and reports.
-module(ern_cli_tests).

%% EUnit's captured output, asked of the test's group leader, which is
%% EUnit's. EUnit's own ?capturedOutput first asks whether it is by the
%% function it is running, which under load it can sample while that process
%% runs another module's code, and then answers "", which failed the
%% diagnostics' examples at times.
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
%% `make` removes when the run ends (RUN_UNIT_TESTS), or the host's for a run
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
                                          "src/stdlib", standard_error)),
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
%% modules that use it let it come, gives the same units.
%%
%% A regression test for a defect the order a build took met by chance; the
%% library names no module it does not depend on, so the test holds the
%% order's not mattering, not a module reached by name alone
stdlib_order_test_() ->
    {timeout, 120, fun stdlib_order/0}.

stdlib_order() ->
    SourceRoot = ern_build:absolute("src/stdlib"),
    BuildRoot = ern_build:absolute("build/stdlib"),
    Modules = [ern_build:module_of(ern_build:absolute(File), SourceRoot)
               || File <- ern_build:sources(SourceRoot)],
    Taken = ern_build:compile_order(Modules, SourceRoot, ern_build:load_path_of([])),
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
%% compiled from Erlang, and one whose atom chunk is empty. A regression
%% test: `ern doc` failed with status 70, and a run's refusal quoted the
%% file's bytes; the release review found the second quoting the host
%% module's bytes, and a later reader the empty atom chunk ending each job
%% with status 70
not_a_compiled_module_test() ->
    Dir = tmp(),
    Junk = write(Dir, "junk.erc", "garbage\n"),
    {ok, Host} = file:read_file(code:which(lists)),
    Beam = write(Dir, "lists.erc", Host),
    Empty = write(Dir, "empty.erc", empty_atoms()),
    lists:foreach(fun({Job, Erc}) ->
                      ?assertEqual(1, ern_err([Job, Erc])),
                      Said = unicode:characters_to_binary(?capturedOutput),
                      Line = iolist_to_binary(["ern ", Job, ": ", Erc,
                                               " is not a compiled module\n"]),
                      ?assertMatch({Job, Erc, {_, _}}, {Job, Erc, binary:match(Said, Line)})
                  end, [{Job, Erc} || Job <- ["doc", "run", "test"], Erc <- [Junk, Beam, Empty]]).

%% report §11.1, §11.2, §11.5: a `.erc` whose atom chunk is empty is no
%% compiled module to a build and to a run: a module's own is compiled
%% again, a dependency's on the load path is refused as the build refuses
%% any file that is no module, and so is a run's dependency, each named
%% from the working directory. A regression test: each job ended with
%% status 70, and a run named a dependency it refused by its absolute path
empty_atoms_build_test() ->
    Dir = tmp(),
    write(Dir, "src/dep.ern", "export fn f() : String = \"one\"\n"),
    write(Dir, "src/top.ern", "export fn main() : Unit = Io.println(Dep.f())\n"),
    write(Dir, "app/top.ern", "export fn main() : Unit = Io.println(Dep.f())\n"),
    in_directory(Dir, fun() ->
                          write(".", "src/dep.erc", empty_atoms()),
                          ?assertEqual(0, build_err(["src"])),
                          {ok, Dep} = file:read_file("src/dep.erc"),
                          ?assertMatch({ok, _}, ern_interface:read(Dep)),
                          write(".", "src/dep.erc", empty_atoms()),
                          ?assertEqual(1, ern_err(["run", "src/top.erc"])),
                          write(".", "lib/dep.erc", empty_atoms()),
                          ?assertEqual(1, build_err(["--load-path", "lib", "app"]))
                      end),
    Said = unicode:characters_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Said, <<"ern run: src/dep.erc: not a compiled module\n">>)),
    ?assertMatch({_, _}, binary:match(Said, <<"ern build: compile Dep first, which Top uses:"
                                              " lib/dep.erc: not a compiled module\n">>)).

%% report §11, §11.2, §11.5: a `.erc` the host refuses to load, one whose
%% code is zeros, is refused as no compiled module and named from the
%% working directory, as the user named it, and the host's own report of
%% the refusal is not written. A regression test: the refusal named it by
%% its absolute path, and then in the host's word, `cannot load top.erc:
%% badfile`
cannot_load_named_test() ->
    Dir = tmp(),
    Source = write(Dir, "top.ern", "export fn main() : Unit = Io.println(\"top\")\n"),
    ?assertEqual(0, build_err(["--source-root", Dir, Source])),
    Erc = filename:join(Dir, "top.erc"),
    {ok, Beam} = file:read_file(Erc),
    ok = file:write_file(Erc, damaged(zeros, Beam)),
    ?assertEqual("ern run: top.erc is not a compiled module\n1\n",
                 os:cmd("cd " ++ Dir ++ " && " ++ filename:absname("bin/ern")
                        ++ " run top.erc 2>&1; echo $?")).

%% report §11, §11.4: a `.erc` whose code the host will not load, its code
%% chunk gone, empty or zeros, is no compiled module to `ern run` and
%% `ern test`, which refuse it by its name, and `ern doc` writes its page,
%% read from its documentation. A regression test: a run and a test
%% refused it in the host's word, `cannot load top.erc: badfile`
code_not_loadable_test() ->
    Dir = tmp(),
    Source = write(Dir, "top.ern", "/// The top.\nexport fn main() : Unit = Io.println(\"top\")\n"),
    ?assertEqual(0, build_err(["--source-root", Dir, Source])),
    Erc = filename:join(Dir, "top.erc"),
    {ok, Beam} = file:read_file(Erc),
    lists:foreach(fun(Damage) ->
                      ok = file:write_file(Erc, damaged(Damage, Beam)),
                      lists:foreach(fun(Job) ->
                                        ?assertEqual({Damage, Job, 1},
                                                     {Damage, Job, ern_err([Job, Erc])}),
                                        Said = unicode:characters_to_binary(?capturedOutput),
                                        Line = iolist_to_binary(["ern ", Job, ": ", Erc,
                                                                 " is not a compiled module\n"]),
                                        ?assertMatch({Damage, Job, {_, _}},
                                                     {Damage, Job, binary:match(Said, Line)})
                                    end, ["run", "test"]),
                      ?assertEqual({Damage, 0}, {Damage, ern_err(["doc", Erc])}),
                      ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(
                                                          ?capturedOutput),
                                                        <<"# Ernest module Top\n">>))
                  end, [gone, empty, zeros]).

%% report §11, §11.1, §11.5: a `.erc` whose code the host will not load is
%% no compiled module to the build of its source, which compiles it again
%% and writes nothing of the host's report of its code; a dependency's on
%% the load path is read for its interface alone, so that the build of a
%% module that uses it stands, and a run refuses it, named from the
%% working directory. A regression test: the build found the module current
code_not_loadable_build_test() ->
    Dir = tmp(),
    write(Dir, "src/dep.ern", "export fn f() : String = \"one\"\n"),
    write(Dir, "lib/dep.ern", "export fn f() : String = \"one\"\n"),
    write(Dir, "app/top.ern", "export fn main() : Unit = Io.println(Dep.f())\n"),
    in_directory(Dir, fun() ->
                          ?assertEqual(0, build_err(["src"])),
                          ?assertEqual(0, build_err(["lib"])),
                          ok = file:delete("lib/dep.ern"),
                          {ok, Beam} = file:read_file("src/dep.erc"),
                          ok = file:write_file("src/dep.erc", damaged(gone, Beam)),
                          ok = file:write_file("lib/dep.erc", damaged(gone, Beam)),
                          ?assertEqual(0, build_err(["--load-path", "lib", "app"])),
                          ?assertEqual(1, ern_err(["run", "--load-path", "lib", "app/top.erc"]))
                      end),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(?capturedOutput),
                                      <<"ern run: lib/dep.erc: not a compiled module\n">>)),
    Said = os:cmd("cd " ++ Dir ++ " && " ++ filename:absname("bin/ern")
                  ++ " build --verbose src 2>&1; echo $?"),
    ?assertEqual("source root src\nbuild root src\n"
                 "compiled Dep from src/dep.ern to src/dep.erc\n0\n", Said),
    {ok, Built} = file:read_file(filename:join(Dir, "src/dep.erc")),
    ?assert(ern_chunk:is_loadable('ern@dep', Built)).

%% A compiled module whose code the host will not load: its code chunk
%% gone, empty, or zeros of its length.
damaged(Damage, Beam) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    {ok, Damaged} = beam_lib:build_module([Chunk || {Id, Code} <- Chunks,
                                                    Chunk <- damaged_chunk(Damage, Id, Code)]),
    Damaged.

damaged_chunk(gone, "Code", _) -> [];
damaged_chunk(empty, "Code", _) -> [{"Code", <<>>}];
damaged_chunk(zeros, "Code", Code) -> [{"Code", binary:copy(<<0>>, byte_size(Code))}];
damaged_chunk(_, Id, Chunk) -> [{Id, Chunk}].

%% A compiled module whose atom chunk is empty: the header, then the
%% chunk's name and a size of no bytes.
empty_atoms() ->
    <<"FOR1", 12:32, "BEAM", "AtU8", 0:32>>.

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
                        "stop", "unpack"]).

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
%% the file, and not the file, which may be writable. A regression test,
%% written after the code: `ern format` named a writable file, and `ern
%% build` a `.erc` that did not exist; it assumes a user the directory's
%% mode binds, which root is not
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
%% directory`. A regression test, written after the code: `ern format` and
%% `ern build` wrote `no such file or directory`, `ern run` `no such file
%% path`, and a file given to --load-path was refused as no directory
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
%% build does, and not a module to compile first. A regression test,
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

%% report §4.2, §11.1: a single file's build given no source root, whose
%% module therefore takes the working directory's, `Src.Main`, resolves
%% `Net.Http` from the module's place to its sibling `Src.Net.Http`, and
%% asks for that module compiled first, as a build given the working
%% directory does. A regression test, written after the code: the name
%% named nothing, with a help naming a nearer source root
nearer_source_root_test() ->
    Dir = pair(tmp()),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, build_err(["src/main.ern"])),
                          ?assertEqual(1, build_err(["--source-root", ".", "src/main.ern"]))
                      end),
    Said = unicode:characters_to_binary(?capturedOutput),
    ?assertEqual(2, length(binary:matches(Said, <<"compile Src.Net.Http first, which Src.Main"
                                                  " uses">>))),
    ?assertEqual(nomatch, binary:match(Said, <<"unknown name">>)).

%% report §11.2: a `.erc` opened as a module keeps §11.1's path shape, which
%% is checked before its path is held to its namespace, and refused as
%% `ern build` refuses a source's. A regression test, written after the
%% code: `ern run Hello.erc` said the file was not at the path of its
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
    "examples/" ++ Base.

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
%% A regression test: printing an address of `Supervisor.GroupMsg`, whose `Join`
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
    ?assertEqual(error, ern_namespace:segment("http_2")).

%% report §11.1, §11.4: the build's sweep passes over a name under the
%% build root that is not UTF-8, and the host says nothing of it. A
%% regression test: the host printed its own WARNING REPORT during `ern
%% build` and `ern doc`
sweep_passes_over_a_name_not_utf8_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export let u : Int = 1\n"),
    ok = filelib:ensure_path(Dir ++ "/build"),
    ok = file:write_file(<<(list_to_binary(Dir))/binary, "/build/caf", 16#e9, ".erc">>, <<>>),
    Output = os:cmd("bin/ern build --source-root " ++ Dir ++ "/src --build-root "
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
    {ok, Report} = file:read_file("report/toolchain.md"),
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
     || Job <- ["build", "doc", "format", "run", "test", "shell", "config", "reload", "stop",
                "unpack"]].

%% report §11.1, §11.2, §11.4, §11.9: `--help` says the source root's
%% default, the working directory, the directory given or the root
%% package's `src` for `ern build` and `ern doc`, and the root package's
%% `src` or the working directory for `ern shell`. A regression test,
%% written after the code: the build's and the doc's said none. It does not
%% cover the default itself, which §11.1's and §11.9's tests hold
source_root_default_said_test_() ->
    Root = "the directory whose layout yields namespaces;"
        " default: the working directory, or src-dir, or the root package's src"
        " for a path under it",
    [{Job, fun() ->
                   {Help, 0} = help_of(Job),
                   Words = lists:flatten(lists:join(" ", string:lexemes(Help, " \n"))),
                   ?assertNotEqual(nomatch, string:find(Words, "--source-root " ++ Said))
           end}
     || {Job, Said} <- [{"build", Root}, {"doc", Root},
                        {"shell", "where the shell finds a module's source;"
                                  " default: the root package's src, or the working"
                                  " directory"}]].

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
    ok = file:set_cwd("src/stdlib"),
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
                   " end of input\n1 | export fn f() : Int =\n2 |\n  | ^\n\n">>,
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

%% report Appendix D, Appendix G.1: the library Appendix D writes out is
%% src/libs/ets/ets.ern line for line, its comments and doc blocks aside,
%% which the appendix writes shorter than the source's. A regression test,
%% written after the round before 0.7.0 left `owned` out of the appendix,
%% and `new` and `contains` as they had been; the doc blocks are not held
appendix_d_is_the_library_test() ->
    [Listed | _] = appendix_d_blocks(),
    {ok, Source} = file:read_file("src/libs/ets/ets.ern"),
    ?assertEqual(code_lines(Source), code_lines(Listed)).

%% A source's lines of code, each blank line, comment and doc block's line
%% left out.
code_lines(Source) ->
    [Line || Line <- binary:split(Source, <<"\n">>, [global]),
             Trimmed <- [string:trim(Line)],
             Trimmed =/= <<>>, string:prefix(Trimmed, <<"//">>) =:= nomatch].

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
                 ern_build:directories(ern_build:load_path([{libs_dir, Libs}]))).

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

%% report §11.2: a library's shim is the toolchain's and the host's own, found
%% before a `.beam` of its name on another root of the load path, though the
%% library's build ends that path for its modules. A regression test, written
%% after the code; the shim moved beside its library, where the program's would
%% have been found first. In a host of its own, where the shim is not loaded yet
own_shim_before_a_program_beam_test() ->
    Dir = tmp(),
    compiled_erlang(Dir ++ "/beams", "ern_json", "format/1", "format(_) -> <<\"the program's\">>."),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.print(Json.format(Json.Integer(1)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual("1\n", os:cmd("bin/ern run --load-path " ++ Dir ++ "/beams " ++ Dir
                               ++ "/build/main.erc")).

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

%% report §4.2: a module is hidden by a module of its namespace alone, and a
%% directory hides nothing: a program's `time/zone.ern` provides `Time.Zone`
%% beside the library's `Time`, so that `Time.Zone.name()` is the program's
%% and `Time.toCivil(0)` the library's, built and run. Written after the
%% code, which found a module by its own path already, so a regression test
module_under_a_library_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/time/zone.ern", "export fn name() : String = \"UTC\"\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = {\n"
          "    let civil = Time.toCivil(0);\n"
          "    Io.println(Time.Zone.name() <> \" \" <> Int.toString(civil.year))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_err(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"UTC 1970\n">>, iolist_to_binary(?capturedOutput)).

%% The refusal of a program's `time.ern`, or of its compiled form, which
%% hides the library Time, which the library Http uses (Appendix G.11).
hides_time(File) ->
    File ++ ": Time hides the library Time, which the library Http uses".

%% A module's compiled form under Root, written as a build of the
%% toolchain that held no module to the refusal of one that hides a
%% library's would have left it, and found current: compiled in memory as
%% `ern build` compiles a module (ern_build:compiled_in_order/3), which
%% refuses nothing, since the refusal is the job's and comes before the
%% compile. Its source stays.
current_form(Root, Relative, Text) ->
    Source = write(Root, Relative, Text),
    SourceRoot = ern_build:absolute(Root),
    [#build_module{namespace = Namespace}] = Order =
        ern_build:compile_order([ern_build:module_of(ern_build:absolute(Source), SourceRoot)],
                                SourceRoot, ern_build:load_path_of([SourceRoot])),
    {[], #{Namespace := Beam}} = ern_build:compiled_in_order(Order, SourceRoot, SourceRoot),
    Erc = filename:rootname(Source) ++ ".erc",
    ok = file:write_file(Erc, Beam),
    Erc.

%% report §11.1, §4.2: `ern build` refuses a module whose namespace is that
%% of a library's module another library depends on, a program's
%% `time.ern` beside the library Http, which uses the library Time: before
%% it is parsed, so that its refusal is its only error, and it alone fails,
%% the module that uses it named as not compiled and the other built. Built
%% again with no `.erc` of it, and with one found current, it is refused
%% the same way, and the build writes over nothing; in single-file mode
%% too. Written before the code, which built it, after which Http never ran
tree_hiding_a_library_refused_test() ->
    Dir = tmp(),
    write(Dir, "time.ern", "export fn mine( = 1\n"),
    write(Dir, "other.ern", "export fn main() : Unit = Io.println(\"other\")\n"),
    write(Dir, "main.ern", "export fn main() : Unit = Io.println(Time.mine())\n"),
    Built = fun(Args) ->
                Before = byte_size(iolist_to_binary(?capturedOutput)),
                ?assertEqual(1, in_directory(Dir, fun() -> build_err(Args) end)),
                Output = iolist_to_binary(?capturedOutput),
                binary:part(Output, Before, byte_size(Output) - Before)
            end,
    Refused = list_to_binary(["ern build: ", hides_time("time.ern"), "\n"]),
    Skipped = <<"ern build: Main is not compiled, since it uses Time, which failed\n">>,
    ?assertEqual(<<Refused/binary, Skipped/binary>>, Built(["."])),
    ?assert(filelib:is_regular(Dir ++ "/other.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/time.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/main.erc")),
    ?assertEqual(<<Refused/binary, Skipped/binary>>, Built(["."])),
    ?assertEqual(Refused, Built(["time.ern"])),
    Erc = current_form(Dir, "time.ern", "export fn mine() : String = \"the program's\"\n"),
    {ok, Form} = file:read_file(Erc),
    ?assertEqual(<<"source root .\nbuild root .\n", Refused/binary, Skipped/binary>>,
                 Built(["--verbose", "."])),
    ?assertEqual({ok, Form}, file:read_file(Erc)),
    ?assertEqual(Refused, Built(["time.ern"])),
    ?assertNot(filelib:is_regular(Dir ++ "/main.erc")).

%% report §11.1: `ern doc` refuses such a module as `ern build` does, of
%% its source given alone and in a directory, and given its `.erc` tests
%% none and writes its page. Written before the code. Whether the
%% directory's other module gets its page is not tested: `ern doc` of a
%% directory writes none where a module fails
doc_of_a_module_hiding_a_library_test() ->
    Dir = tmp(),
    write(Dir, "other.ern", "export fn main() : Unit = Io.println(\"other\")\n"),
    current_form(Dir, "time.ern", "/// The program's own.\nexport fn mine() : String = \"mine\"\n"),
    Refused = list_to_binary(["ern doc: ", hides_time("time.ern"), "\n"]),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, ern_err(["doc", "time.ern"])),
                          ?assertEqual(1, ern_err(["doc", "."])),
                          ?assertEqual(0, ern_err(["doc", "time.erc"]))
                      end),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch(<<Refused:(byte_size(Refused))/binary, Refused:(byte_size(Refused))/binary,
                   "# Ernest module Time\n", _/binary>>, Output).

%% report §11.2: `ern run` and `ern test`, given a program that uses Http,
%% whose root holds a compiled form of a program's Time, refuse it before
%% anything runs, naming the file found as §11.1 names the module that
%% hides the library's, where they said Http was compiled against another
%% Time, which no build of the program can mend. Written before the code.
%% A node's start, which reads every module of its load path, is not
%% covered, nor `ern shell` given a file, which ern_shell_tests holds
run_finding_a_module_hiding_a_library_test() ->
    Dir = tmp(),
    write(Dir, "main.ern", "export fn main() : Unit = Io.println(Http.date(0))\n"),
    write(Dir, "check.ern",
          "let dated : Test.Case(Never) =\n"
          "    Test.Case(name = \"dated\",\n"
          "              run = fn() = Test.equal(String.size(Http.date(0)), 29))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir])),
    ?assertEqual(0, ern_err(["test", Dir ++ "/check.erc"])),
    current_form(Dir, "time.ern", "export fn mine() : String = \"the program's\"\n"),
    Found = ern_build:shown(Dir ++ "/time.erc"),
    ?assertEqual(1, ern_err(["run", Dir ++ "/main.erc"])),
    ?assertEqual(1, ern_err(["test", Dir ++ "/check.erc"])),
    ?assertEqual(list_to_binary(["dated: passed\n",
                                 "ern run: ", hides_time(Found), "\n",
                                 "ern test: ", hides_time(Found), "\n"]),
                 iolist_to_binary(?capturedOutput)).

%% report §11.1, §4.2: a module that hides a library's module no library
%% depends on, `Json`, is built and documented, and so is one under a
%% library's namespace, `time/zone.ern`, which hides nothing; and a
%% library's own module, built from its own source root, is not refused.
%% Written with the code, so a regression test; the build and the run of
%% the first two are own_module_before_library_test's and
%% module_under_a_library_namespace_test's
hiding_allowed_test() ->
    Dir = tmp(),
    write(Dir, "json.ern", "export fn parse(text : String) : Int = String.size(text)\n"),
    write(Dir, "time/zone.ern", "export fn name() : String = \"UTC\"\n"),
    ?assertEqual(0, ern_err(["build", Dir])),
    ?assertEqual(0, ern_err(["doc", Dir])),
    ?assert(filelib:is_regular(Dir ++ "/json.erc")),
    ?assert(filelib:is_regular(Dir ++ "/time/zone.erc")),
    Time = filename:join([ern_tree:tree(), "src", "libs", "time"]),
    Build = Dir ++ "/library",
    ?assertEqual(0, ern_err(["build", "--source-root", Time, "--build-root", Build, Time])),
    ?assertEqual(0, ern_err(["doc", "--source-root", Time, "--build-root", Build, Time])),
    ?assert(filelib:is_regular(Build ++ "/time.erc")),
    ?assert(filelib:is_regular(Build ++ "/time.md")),
    ?assertEqual(<<>>, iolist_to_binary(?capturedOutput)).

%% report §11.1: the refusal names the library of the first module, in the
%% load path's order, that depends on the hidden one, the hidden one's own
%% library among them, and a library's module no module of the libraries
%% depends on is not refused: three libraries built as the toolchain's are,
%% `zed`, whose `Zed.Extra` uses `Zed`, and `alpha` and `beta`, each of
%% which uses `Zed`, given as the load path's libraries. Written with the
%% code, so a regression test
first_dependent_named_test() ->
    Dir = tmp(),
    Libraries = [filename:join([Dir, "build", Name]) || Name <- ["alpha", "beta", "zed"]],
    [Alpha, Beta, Zed] = Libraries,
    write(Dir, "zed/zed.ern", "export fn one() : Int = 1\n"),
    write(Dir, "zed/zed/extra.ern", "export fn two() : Int = Zed.one() + 1\n"),
    write(Dir, "alpha/alpha.ern", "export fn three() : Int = Zed.one() + 2\n"),
    write(Dir, "beta/beta.ern", "export fn four() : Int = Zed.one() + 3\n"),
    Built = fun(Name, Build, LoadPath) ->
                    Source = filename:join(Dir, Name),
                    ?assertEqual(0, ern_err(["build", "--source-root", Source, "--build-root",
                                             Build | LoadPath] ++ [Source]))
            end,
    Built("zed", Zed, []),
    Built("alpha", Alpha, ["--load-path", Zed]),
    Built("beta", Beta, ["--load-path", Zed]),
    Program = Dir ++ "/program/zed.ern",
    Refusal = fun(Dependent) ->
                      ern_build:shown(Program) ++ ": Zed hides the library Zed, which the library "
                          ++ Dependent ++ " uses"
              end,
    Bare = ern_build:load_path_of([]),
    ?assertEqual(Refusal("Alpha"), ern_build:hiding(Program, ['Zed'], Program, Libraries, Bare)),
    ?assertEqual(Refusal("Beta"), ern_build:hiding(Program, ['Zed'], Program, [Beta, Zed], Bare)),
    ?assertEqual(Refusal("Zed"), ern_build:hiding(Program, ['Zed'], Program, [Zed], Bare)),
    ?assertEqual(Refusal("Alpha"), ern_build:hiding(Program, ['Zed'], none, Libraries, Bare)),
    ?assertEqual(none, ern_build:hiding(Program, ['Alpha'], Program, Libraries, Bare)),
    ?assertEqual(none, ern_build:hiding(Program, ['Zed', 'Extra'], Program, Libraries, Bare)),
    ?assertEqual(none, ern_build:hiding(Program, ['Gamma'], Program, Libraries, Bare)).

%% report §4.2: the root is one namespace, which the source root's modules
%% and a load path root's stand in together: the program's `geo/a.ern`
%% beside a `--load-path` root's `geo.erc` and `geo/b.erc` provides
%% `Geo.A`, and all three are found; the program's own `geo.ern` then
%% hides the load path's `Geo` alone, and `Geo.B` stays the load path's.
%% Written after the code, so a regression test
one_namespace_at_the_root_test() ->
    Dir = tmp(),
    write(Dir, "lib/geo.ern", "export fn name() : String = \"the load path's Geo\"\n"),
    write(Dir, "lib/geo/b.ern", "export fn name() : String = \"the load path's Geo.B\"\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/other", Dir ++ "/lib"])),
    write(Dir, "src/geo/a.ern", "export fn name() : String = \"the program's Geo.A\"\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = {\n"
          "    Io.println(Geo.name());\n"
          "    Io.println(Geo.A.name());\n"
          "    Io.println(Geo.B.name())\n"
          "}\n"),
    BuiltAndRun = fun() ->
                          ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build",
                                                       "--load-path", Dir ++ "/other",
                                                       Dir ++ "/src"])),
                          ?assertEqual(0, ern_err(["run", "--load-path", Dir ++ "/other",
                                                   Dir ++ "/build/main.erc"]))
                  end,
    BuiltAndRun(),
    write(Dir, "src/geo.ern", "export fn name() : String = \"the program's Geo\"\n"),
    BuiltAndRun(),
    ?assertEqual(<<"the load path's Geo\nthe program's Geo.A\nthe load path's Geo.B\n"
                   "the program's Geo\nthe program's Geo.A\nthe load path's Geo.B\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.1, §4.2: a module whose source the source root holds is the
%% source root's, compiled or not: a single file's build that uses one the
%% build root holds no `.erc` of refuses, as where no later root holds one,
%% and reads no module of its namespace under a later root, neither the
%% library `Json` nor a `--load-path` root's `Util`, and writes nothing;
%% `ern doc` of the file refuses it so too. Written before the code, which
%% read the later root's; the half of `ern doc` after it, a regression test
source_root_module_not_compiled_test() ->
    Dir = tmp(),
    write(Dir, "json.ern", "export fn parse(text : String) : Int = String.size(text)\n"),
    write(Dir, "main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Json.parse(\"seven\")))\n"),
    write(Dir, "lib/util.ern", "export fn one() : Int = 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/other", Dir ++ "/lib"])),
    write(Dir, "src/util.ern", "export fn one() : Int = 1\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Util.one()))\n"),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, build_err(["main.ern"])),
                          ?assertEqual(1, build_err(["--source-root", "src", "--build-root",
                                                     "build", "--load-path", "other",
                                                     "src/main.ern"])),
                          ?assertEqual(1, ern_err(["doc", "main.ern"]))
                      end),
    ?assertEqual(<<"ern build: compile Json first, which Main uses: json.erc: no such file or"
                   " directory\n"
                   "ern build: compile Util first, which Main uses: build/util.erc: no such file"
                   " or directory\n"
                   "ern doc: compile Json first, which Main uses: json.erc: no such file or"
                   " directory\n">>,
                 unicode:characters_to_binary(?capturedOutput)),
    ?assertNot(filelib:is_regular(Dir ++ "/main.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")).

%% report §11.1: a build of a directory under the source root compiles its
%% sources and no other of the source root's, so that a module of it that
%% uses one outside it that is not compiled fails alone, refused as a
%% single file's build refuses it, though the library `Json` stands on the
%% load path, and the rest are built. Written before the code
directory_under_the_source_root_test() ->
    Dir = tmp(),
    write(Dir, "src/json.ern", "export fn parse(text : String) : Int = String.size(text)\n"),
    write(Dir, "src/app/main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Json.parse(\"seven\")))\n"),
    write(Dir, "src/app/other.ern", "export fn main() : Unit = Io.println(\"other\")\n"),
    in_directory(Dir, fun() ->
                          ?assertEqual(1, build_err(["--source-root", "src", "src/app"]))
                      end),
    ?assertEqual(<<"ern build: compile Json first, which App.Main uses: src/json.erc: no such"
                   " file or directory\n">>,
                 unicode:characters_to_binary(?capturedOutput)),
    ?assert(filelib:is_regular(Dir ++ "/src/app/other.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/src/app/main.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/src/json.erc")).

%% report §11.1: a module of the source root that a build is not given, on
%% which one it is given depends, is read from its `.erc` under the build
%% root as that stands, its source edited since, and the build says nothing
%% of it: `main.ern` built alone after `util.ern` changed its interface
%% compiles against `util.erc` and runs with it. Written after the code, so
%% a regression test
edited_dependency_read_as_it_stands_test() ->
    Dir = tmp(),
    write(Dir, "util.ern", "export fn one() : Int = 1\n"),
    write(Dir, "main.ern", "export fn main() : Unit = Io.println(Int.toString(Util.one()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir])),
    write(Dir, "util.ern", "export fn one() : String = \"one\"\n"),
    write(Dir, "main.ern",
          "export fn main() : Unit = Io.println(Int.toString(Util.one() + 1))\n"),
    ?assertEqual(0, build_err(["--source-root", Dir, Dir ++ "/main.ern"])),
    ?assertEqual(<<>>, unicode:characters_to_binary(?capturedOutput)),
    ?assertEqual(0, ern_err(["run", Dir ++ "/main.erc"])),
    ?assertEqual(<<"2\n">>, unicode:characters_to_binary(?capturedOutput)).

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
    {ok, Report} = file:read_file("report/library.md"),
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
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = compare(a, b)\n"
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
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "bad.ern:1:35: `-` is not defined on Geo.Vec.Vec\n")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/bad.erc")).

%% report §3.10, §4.5, §11.2: a type member of another module is reached
%% by `compare` and `<` on the type, and loads from the module that owns
%% it
type_member_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/stack.ern",
          "export abstract type Stack(a) = Stack(List(a))\n"
          "export let empty : Stack(a) = Stack([])\n"
          "export fn push(x : a, Stack(xs) : Stack(a)) : Stack(a) = Stack(x :: xs)\n"
          "export fn Stack.compare(Stack(xs) : Stack(a), Stack(ys) : Stack(a)) : Ordering =\n"
          "    compare(List.size(xs), List.size(ys))\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = {\n"
          "    let s = Lib.Stack.push(1, Lib.Stack.empty);\n"
          "    let t = Lib.Stack.push(2, s);\n"
          "    Io.println(Io.show(compare(t, s)));\n"
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
%% type error. A regression test: before the rule, through a type variable
%% its constructor was shown
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
%% after the rule had said otherwise
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

%% report §4.2: `T.name` is the module T's `name`, a dotted name's first
%% segment being a namespace, beside the module's own type `T`, whose
%% member prefix `-` reaches (§4.5). A regression test: the build left
%% module T out wherever the module declared a type T, and `Stack.other`
%% was an unknown name
type_name_shares_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/stack.ern", "export fn other() : Int = 7\n"),
    write(Dir, "src/main.ern",
          "type Stack = Stack(List(Int))\n\n"
          "fn Stack.negate(s : Stack) : Int = match s { Stack(xs) -> List.size(xs) }\n\n"
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(Stack.other() + -Stack([1])))\n"),
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
                                      <<"takes the prelude's namespace Prelude">>)).

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
                 binary:match(Output, <<"address.ern takes the prelude's namespace Address">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"io.ern takes the standard library's namespace Io">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"test.ern takes the standard library's namespace Test">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"peer.ern takes the standard library's namespace Peer">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"prelude's namespace Io">>)),
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
    ?assertMatch({_, _}, binary:match(Output, <<"fs/entry.ern stands under the standard library's"
                                                " namespace Fs\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"int/parse.ern stands under the prelude's"
                                                " namespace Int\n">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/fs/entry.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/int/parse.erc")),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"\n42\n">>)),
    %% a file built alone is refused the same way
    ?assertEqual(1, build_err(["--source-root", Dir ++ "/src", "--build-root", Dir ++ "/alone",
                               Dir ++ "/src/fs/entry.ern"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"fs/entry.ern stands under the standard library's"
                                        " namespace Fs\n">>)).

%% report §4.2: no segment of a module namespace, at any depth, is a taken
%% one: `fides/io.ern` takes the standard library's `Io`,
%% `fides/ernest.ern` the toolchain's `Ernest`, and `fides/io/x.ern` stands
%% under `Io`, each refused as `io.ern` is and alone. A regression test,
%% written after the code
taken_at_depth_test() ->
    Dir = tmp(),
    write(Dir, "src/fides/io.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/fides/ernest.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/fides/io/x.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Refusal))
     || Refusal <- [<<"fides/io.ern takes the standard library's namespace Io\n">>,
                    <<"fides/ernest.ern takes the toolchain's namespace Ernest\n">>,
                    <<"fides/io/x.ern stands under the standard library's namespace Io\n">>]],
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")).

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
    "    compare(List.size(left.items), List.size(right.items))\n"
    "\n"
    "export fn empty() : Stack = Stack(items = [])\n".

%% report §4.2, §4.5, §11.5: the module of a type's name shares the type's
%% namespace, and a third module reaches the member by `compare` and the
%% module's functions by the prefix, `Main.Stack.push`. A regression test,
%% written after the code: the checker took `Main.Stack.push` for a
%% member, which worked by accident; it does not cover a member of a
%% private type
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
          "    Io.println(Io.show(compare(one, two)));\n"
          "    Io.println(Io.show(two));\n"
          "    Io.println(Int.toString(Main.Stack.size(two)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/user.erc"])),
    ?assertEqual(<<"Less\nMain.Stack(items = [2, 1])\n2\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §4.2, §4.5, §11.1: a module that names a member of a type
%% through the type's namespace depends on the module that declares the
%% type, though the module of the type's name exists and uses nothing of
%% it, so that the name is refused as the member's it is. A regression
%% test, written after the code: the build took the module of the name for
%% the dependency, and the member was unknown
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
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"user.ern:2:19: `Main.Stack.compare` names a member, which"
                                        " an expression reaches through `compare`\n">>)).

%% report §4.2: a module calls the module of its own type's name by the
%% qualified name the two share, `Window.open` in `epx.ern` beside its
%% private type `Window`, which has no member `open`. A regression test,
%% written after the code: the checker took the function for the type's
%% member, and the compiler crashed
parent_calls_its_child_test() ->
    Dir = tmp(),
    write(Dir, "src/epx.ern",
          "type Window = Window(id : Int)\n"
          "\n"
          "export fn main() : Unit = {\n"
          "    let window = Window(id = Window.open());\n"
          "    Io.println(Io.show(window))\n"
          "}\n"),
    write(Dir, "src/epx/window.ern", "export fn open() : Int = 42\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/epx.erc"])),
    ?assertEqual(<<"Epx.Window(id = 42)\n">>, iolist_to_binary(?capturedOutput)).

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
                        "    if left < right then Less else Equal\n",
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
    %% the help says the value is that name too: a regression test, written
    %% after the code, of the help's text alone
    ?assertMatch({_, _}, binary:match(Output, <<"help: this module's compare is"
                                                " Main.Stack.compare too; rename it\n">>)),
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
%% parent by its last segment, the shortest resolving form, its functions,
%% its types, and its constructors alike
nested_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main/stack.ern",
          "export type Item = Item(Int)\n"
          "export fn push(i : Item) : Int = match i { Item(n) -> n + 1 }\n"),
    write(Dir, "src/main.ern",
          "fn count(i : Stack.Item) : Int = Stack.push(i)\n"
          "export fn main() : Unit =\n"
          "    Io.println(Int.toString(count(Stack.Item(1))))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"2\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a qualified name resolves from the writer's namespace
%% outward, its first segment climbing and the rest descending. In
%% `Top.Shell.Complete`, `Command.parse` is the sibling's function,
%% `Region.Region` the sibling's type, and its constructor in an expression
%% and a pattern, `..Command` a fill from the sibling, `Shell.attach` the
%% parent's function and `Int.toString` the standard library's; `Top`
%% reaches its grandchild by `Shell.Complete.run`. A regression test,
%% written after the code; it does not cover a module of a load path root,
%% which the climb asks of as it asks of a source
relative_lookup_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern", "export fn main() : Unit = Io.println(Shell.Complete.run())\n"),
    write(Dir, "src/top/shell.ern",
          "export fn attach() : String = \"attach\"\n"
          "\n"
          "export fn parsed() : String = Command.parse()\n"),
    write(Dir, "src/top/shell/command.ern", "export fn parse() : String = \"parse\"\n"),
    write(Dir, "src/top/shell/region.ern", "export type Region = Region(Int)\n"),
    write(Dir, "src/top/shell/complete.ern",
          "type Parsing = Parsing(parse : () -> String)\n"
          "\n"
          "fn width(region : Region.Region) : Int = match region { Region.Region(n) -> n }\n"
          "\n"
          "export fn run() : String = {\n"
          "    let filled = Parsing(..Command);\n"
          "    filled.parse() <> \" \" <> Shell.attach() <> \" \" <> Shell.parsed() <> \" \"\n"
          "        <> Int.toString(width(Region.Region(3)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/top.erc"])),
    ?assertEqual(<<"parse attach parse 3\n">>, iolist_to_binary(?capturedOutput)).

%% report §5.6, §11.1: a fill names a module's namespace, `..Net.Http`,
%% and the module is a dependency as any module a qualified name names. A
%% regression test, written after the fix: the build took the namespace
%% before the name for the module's, found none, and the fill lacked every
%% field
fill_from_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/net/http.ern", "export fn parse() : String = \"parse\"\n"),
    write(Dir, "src/main.ern",
          "type Parsing = Parsing(parse : () -> String)\n"
          "\n"
          "export fn main() : Unit = {\n"
          "    let filled = Parsing(..Net.Http);\n"
          "    Io.println(filled.parse())\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"parse\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: where two namespaces hold a first segment, the nearer wins.
%% In `Top.Shell.User`, `Util.name` is `Top.Shell.Util`'s, and `Top.Util`,
%% whose first segment is found at the root, reaches the farther
%% `Top.Util`; the root's `Util`, which `Main` reaches by `Util.name`, no
%% name in `Top.Shell` reaches. A regression test, written after the code
nearer_namespace_wins_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export fn name() : String = \"root\"\n"),
    write(Dir, "src/top/util.ern", "export fn name() : String = \"top\"\n"),
    write(Dir, "src/top/shell/util.ern", "export fn name() : String = \"shell\"\n"),
    write(Dir, "src/top/shell/user.ern",
          "export fn both() : String = Util.name() <> \" \" <> Top.Util.name()\n"),
    write(Dir, "src/main.ern",
          "export fn main() : Unit = Io.println(Util.name() <> \" \" <> Top.Shell.User.both())\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"root shell top\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2, §11.5: a qualified name unknown in the nearer namespace its
%% first segment found, where a module of that segment stands at the root,
%% which is out of reach from the writer, has a help naming the hiding
%% module: `Util.g` in `Top.Shell` is `Top.Shell.Util`'s, and the root's
%% `Util` declares it
hidden_root_module_help_test() ->
    Dir = tmp(),
    write(Dir, "src/util.ern", "export fn g() : Int = 1\n"),
    write(Dir, "src/top/shell/util.ern", "export fn f() : Int = 2\n"),
    write(Dir, "src/top/shell.ern",
          "export fn main() : Unit = Io.println(Int.toString(Util.g()))\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"shell.ern:1:51: unknown name"
                                                " Top.Shell.Util.g\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"help: `Util` here is `Top.Shell.Util`; the root's"
                                                " `Util` is out of reach from `Top.Shell`\n">>)).

%% report §4.2, §11.5: the root holds the libraries of the toolchain's own,
%% each under a root of the load path, and a type's name is helped as a
%% value's: `Json.Value` in `Top.Shell`, beside `top/shell/json/`, which
%% holds a module and so is `Top.Shell.Json`, names the root's `Json` no
%% more
hidden_library_help_test() ->
    Dir = tmp(),
    write(Dir, "src/top/shell/json/pretty.ern", "export fn pretty() : String = \"pretty\"\n"),
    write(Dir, "src/top/shell.ern", "export fn valued(value : Json.Value) : Int = 0\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"shell.ern:1:26: unknown type"
                                                " Top.Shell.Json.Value\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"help: `Json` here is `Top.Shell.Json`; the root's"
                                                " `Json` is out of reach from `Top.Shell`\n">>)).

%% report §4.2, §11.5: where no module of the first segment stands at the
%% root, nothing is out of reach, and the unknown name has no help
hidden_nothing_test() ->
    Dir = tmp(),
    write(Dir, "src/top/shell/util.ern", "export fn f() : Int = 2\n"),
    write(Dir, "src/top/shell.ern",
          "export fn main() : Unit = Io.println(Int.toString(Util.g()))\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"shell.ern:1:51: unknown name"
                                                " Top.Shell.Util.g\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"help:">>)).

%% report §4.2: the climb finds a module namespace and never a type's, and
%% a namespace holds a module at some depth. In `Top.User`, beside `Top`'s
%% type `Stack` with its member `compare`, `Stack.name` is the root module
%% `Stack`'s; `top/util/`, which holds no module, is no namespace, so
%% `Util.name` climbs past it to the root's `Util`; and `top/net/`, which
%% holds `http.ern` alone, is `Top.Net`, which `Net.Http.get` reaches. A
%% regression test, written after the code
climb_finds_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/stack.ern", "export fn name() : String = \"module\"\n"),
    write(Dir, "src/util.ern", "export fn name() : String = \"root\"\n"),
    write(Dir, "src/top.ern",
          "export type Stack = Stack(Int)\n"
          "\n"
          "export fn Stack.compare(left : Stack, right : Stack) : Ordering = Equal\n"),
    write(Dir, "src/top/util/notes.txt", "no module\n"),
    write(Dir, "src/top/net/http.ern", "export fn get() : String = \"http\"\n"),
    write(Dir, "src/top/user.ern",
          "export fn main() : Unit =\n"
          "    Io.println(Stack.name() <> \" \" <> Util.name() <> \" \" <> Net.Http.get())\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/top/user.erc"])),
    ?assertEqual(<<"module root http\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2, §11.5: a name written longer than its shortest resolving
%% form is an error at the name, which names it whole, with a help line
%% that writes the short one: a type's, a constructor's in a pattern, a
%% fill's namespace and a function's alike, `Shell.Region` as
%% `Top.Shell.Region`. A regression test, written after the code
too_long_name_test() ->
    Dir = tmp(),
    write(Dir, "src/top/shell/command.ern", "export fn parse() : String = \"parse\"\n"),
    write(Dir, "src/top/shell/region.ern", "export type Region = Region(Int)\n"),
    write(Dir, "src/top/shell/user.ern",
          "type Parsing = Parsing(parse : () -> String)\n"
          "\n"
          "fn width(region : Shell.Region.Region) : Int =\n"
          "    match region { Top.Shell.Region.Region(n) -> n }\n"
          "\n"
          "export fn run() : String = {\n"
          "    let filled = Parsing(..Top.Shell.Command);\n"
          "    Top.Shell.Command.parse() <> Int.toString(width(Region.Region(3)))\n"
          "}\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    Long = <<" is written longer than its shortest resolving form\n">>,
    [?assertMatch({_, _}, binary:match(Output, <<"user.ern:", Where/binary, ": ", Name/binary,
                                                 Long/binary>>))
     || {Where, Name} <- [{<<"3:19">>, <<"Top.Shell.Region.Region">>},
                          {<<"4:20">>, <<"Top.Shell.Region.Region">>},
                          {<<"7:28">>, <<"Top.Shell.Command">>},
                          {<<"8:5">>, <<"Top.Shell.Command.parse">>}]],
    [?assertMatch({_, _}, binary:match(Output, <<"help: write `", Short/binary, "`\n">>))
     || Short <- [<<"Region.Region">>, <<"Command">>, <<"Command.parse">>]],
    ?assertNot(filelib:is_regular(Dir ++ "/build/top/shell/user.erc")).

%% report §4.2: a module's own value is written qualified only where a
%% binding hides its plain name, and then in its shortest form: in
%% `Top.Shell.User`, `User.name` beside a parameter `name`, and
%% `Top.Shell.User.name` is an error whose help writes `User.name`. A
%% regression test, written after the code
own_value_shortest_test() ->
    Dir = tmp(),
    Shown = "fn name() : String = \"user\"\n"
            "\n"
            "fn shown(name : String) : String = name <> User.name()\n"
            "\n",
    write(Dir, "src/top/shell/user.ern",
          Shown ++ "fn longer(name : String) : String = name <> Top.Shell.User.name()\n"
                   "\n"
                   "export fn main() : Unit = Io.println(shown(\"a\") <> longer(\"b\"))\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _}, binary:match(Output, <<"user.ern:5:45: Top.Shell.User.name is written"
                                                " longer than its shortest resolving form\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"help: write `User.name`\n">>)),
    write(Dir, "src/top/shell/user.ern",
          Shown ++ "export fn main() : Unit = Io.println(shown(\"a\"))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["run", Dir ++ "/build/top/shell/user.erc"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"\nauser\n">>)).

%% report §4.2, §11.5: a help that writes the source's code back writes
%% each name as the source does, in its shortest form: `compare(Util.one,
%% Util.two)` for `Int.compare(Util.one, Util.two)` in `Top.User`. A
%% regression test, written after the fix: the help wrote `Top.Util.one`,
%% which the build refuses as too long
help_writes_names_as_written_test() ->
    Dir = tmp(),
    write(Dir, "src/top/util.ern", "export let one : Int = 1\n\nexport let two : Int = 2\n"),
    write(Dir, "src/top/user.ern",
          "export fn later() : Bool = Int.compare(Util.one, Util.two) == Greater\n"),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"help: write `compare(Util.one, Util.two)`\n">>)).

%% report §11.1, §4.2: a `.erc` records each qualifier its source writes
%% with the namespace it resolves to, and a module is recompiled when one
%% would now resolve to another: `Top.Shell.Util` added beside
%% `Top.Shell.User` takes `Util.name` from `Top.Util`, though neither the
%% source nor `Top.Util` changed. A regression test, written after the code;
%% it does not cover a name that would now resolve to none
recompiled_on_resolution_test() ->
    Dir = tmp(),
    write(Dir, "src/top/util.ern", "export fn name() : String = \"top\"\n"),
    write(Dir, "src/top/shell/user.ern", "export fn main() : Unit = Io.println(Util.name())\n"),
    Args = ["--build-root", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    User = Dir ++ "/build/top/shell/user.erc",
    {ok, Before} = file:read_file(User),
    ?assertMatch({ok, #{resolved := [{['Io'], ['Io']}, {['Util'], ['Top', 'Util']}]}},
                 ern_interface:read(Before)),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    ?assertEqual({ok, Before}, file:read_file(User)),
    write(Dir, "src/top/shell/util.ern", "export fn name() : String = \"shell\"\n"),
    ?assertEqual(0, ern_cli:ern(["build" | Args])),
    {ok, After} = file:read_file(User),
    ?assertMatch({ok, #{resolved := [{['Io'], ['Io']}, {['Util'], ['Top', 'Shell', 'Util']}]}},
                 ern_interface:read(After)),
    ?assertEqual(0, ern_cli:ern(["run", User])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"shell\n">>)).

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

%% report §12.4, §11.2: a deadlock's report lists, beneath the trace, the
%% processes it left waiting but the one it faults, a line for each group
%% of one spawn site, one waiting frame and one callee's site, with their
%% count, in the order of the sites, the frame the first of the program's
%% in the process's stack: two accounts each calling the other, each line
%% naming the other's site, and three workers of one site waiting in one
%% frame, in a receive, which have no callee, under `ern run`, and under
%% `ern test`, where the deadlock is the test's fault. Written with the
%% listing, and with the callee
deadlock_lists_the_waiting_test() ->
    Dir = tmp(),
    Program = "type AccountMsg = Peer(Address(AccountMsg)) | Audit(Reply(Int))\n"
              "type Waits = Waits\n"
              "fn account(balance : Int) : Unit receiving AccountMsg = receive {\n"
              "    Peer(other) -> audited(balance, other)\n"
              "  | Audit(reply) -> { answer(reply, balance); account(balance) }\n"
              "}\n"
              "fn audited(balance : Int, other : Address(AccountMsg)) : Unit\n"
              "        receiving AccountMsg = {\n"
              "    let theirs = Address.callForever(other, Audit);\n"
              "    audited(balance + theirs, other)\n"
              "}\n"
              "fn worker() : Unit receiving Waits = receive { Waits -> Unit }\n"
              "fn locked() : Unit = {\n"
              "    let a = spawn(fn() = account(1));\n"
              "    let b = spawn(fn() = account(2));\n"
              "    send(a, Peer(b));\n"
              "    send(b, Peer(a));\n"
              "    List.forEach([1, 2, 3], fn(_) = { let _ = spawn(worker); Unit })\n"
              "}\n",
    Waiting = <<"    1 process of Locks.locked:14 waits in Locks.audited:9 on Locks.locked:15\n"
                "    1 process of Locks.locked:15 waits in Locks.audited:9 on Locks.locked:14\n"
                "    3 processes of Locks.locked:18 wait in Locks.worker:12\n">>,
    write(Dir, "src/locks.ern",
          Program ++ "export fn main() : Unit receiving Waits = {\n"
                     "    locked();\n"
                     "    receive { Waits -> Unit }\n"
                     "}\n"
                     "let stuck = Test.Case(name = \"stuck\",\n"
                     "    run = fn() : Test.Result receiving Waits = {\n"
                     "    locked();\n"
                     "    receive { Waits -> Test.Passed }\n"
                     "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {Errors, Status} = standard_error_of(["run", Dir ++ "/build/locks.erc"]),
    ?assertEqual(1, Status),
    {match, [Listed]} = re:run(Errors,
                               "^Locks.main faulted: deadlock\n    Locks.main:[0-9]+\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertEqual(Waiting, Listed),
    _ = ?capturedOutput,
    ?assertEqual(1, ern_err(["test", Dir ++ "/build/locks.erc"])),
    {match, [Tested]} = re:run(iolist_to_binary(?capturedOutput),
                               "^stuck: faulted: deadlock\n    Locks\\.[^\n]*\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertEqual(Waiting, Tested).

%% report §12.4: a deadlock's lines are ordered by their sites' lines as
%% numbers, a spawn on line 9 before one on line 10, whose order as text is
%% the reverse. A regression test: the lines were ordered as text
deadlock_lines_by_number_test() ->
    Dir = tmp(),
    write(Dir, "src/pair.ern",
          "type Waits = Waits\n"
          "fn worker() : Unit receiving Waits = receive { Waits -> Unit }\n"
          "// the two spawns below stand on lines 9 and 10\n"
          "//\n"
          "//\n"
          "//\n"
          "//\n"
          "fn pair() : Unit = {\n"
          "    let _ = spawn(worker);\n"
          "    let _ = spawn(worker);\n"
          "    Unit\n"
          "}\n"
          "export fn main() : Unit receiving Waits = {\n"
          "    pair();\n"
          "    receive { Waits -> Unit }\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {Errors, 1} = standard_error_of(["run", Dir ++ "/build/pair.erc"]),
    {match, [Listed]} = re:run(Errors, "^Pair.main faulted: deadlock\n    Pair.main:[0-9]+\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertEqual(<<"    1 process of Pair.pair:9 waits in Pair.worker:2\n"
                   "    1 process of Pair.pair:10 waits in Pair.worker:2\n">>, Listed).

%% report §12.4: a group of a deadlock's lines is split by its callee's
%% site, each line naming its callee by its spawn site and the entry
%% process by its site, the entry point's name with no line: four clients
%% of one site waiting in one frame, two calling one server, one another
%% and one main, the lines ordered by the callees' sites, main's first, as
%% one without a line, and the servers' lines as numbers, 9 before 10.
%% Written with the callee
deadlock_lines_by_callee_test() ->
    Dir = tmp(),
    write(Dir, "src/split.ern",
          "type Req = Get(Reply(Int)) | Other\n"
          "fn server() : Unit receiving Req = receive { Other -> Unit }\n"
          "fn client(server : Address(Req)) : Unit = {\n"
          "    let _ = Address.callForever(server, Get);\n"
          "    Unit\n"
          "}\n"
          "// the two servers below stand on lines 9 and 10\n"
          "fn split(me : Address(Req)) : Unit = {\n"
          "    let a = spawn(server);\n"
          "    let b = spawn(server);\n"
          "    List.forEach([a, b, b, me], fn(s) = { let _ = spawn(fn() = client(s)); Unit })\n"
          "}\n"
          "export fn main() : Unit receiving Req = {\n"
          "    split(self());\n"
          "    receive { Other -> Unit }\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {Errors, 1} = standard_error_of(["run", Dir ++ "/build/split.erc"]),
    {match, [Listed]} = re:run(Errors,
                               "^Split.main faulted: deadlock\n    Split.main:[0-9]+\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertEqual(<<"    1 process of Split.split:9 waits in Split.server:2\n"
                   "    1 process of Split.split:10 waits in Split.server:2\n"
                   "    1 process of Split.split:11 waits in Split.client:4 on Split.main\n"
                   "    1 process of Split.split:11 waits in Split.client:4 on Split.split:9\n"
                   "    2 processes of Split.split:11 wait in Split.client:4 on Split.split:10\n">>,
                 Listed).

%% report §12.4, §8.6, Appendix E.21: a caller waiting in `Process.run` waits in
%% a call on the library's own process, which the line names by its site,
%% the spawn's line in `run`'s body in the library's source; that process
%% waits in the library's frame, and the process that runs `f` has the
%% site where `run` is written. The library's lines are matched as numbers
%% of any value, so that its source may move, the judge's site the same in
%% its own line and in its caller's. Written with the callee
deadlock_line_of_a_run_test() ->
    Dir = tmp(),
    write(Dir, "src/run.ern",
          "type Waits = Waits\n"
          "fn runs() : Unit = {\n"
          "    let _ = Process.run(fn() : Unit receiving Waits = receive { Waits -> Unit });\n"
          "    Unit\n"
          "}\n"
          "export fn main() : Unit receiving Waits = {\n"
          "    let _ = spawn(runs);\n"
          "    receive { Waits -> Unit }\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {Errors, 1} = standard_error_of(["run", Dir ++ "/build/run.erc"]),
    {match, [Listed]} = re:run(Errors, "^Run.main faulted: deadlock\n    Run.main:[0-9]+\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertMatch({match, _},
                 re:run(Listed, "\\A    1 process of Process\\.run:([0-9]+) waits in"
                                " Process\\.judged:[0-9]+\n"
                                "    1 process of Run\\.main:7 waits in Run\\.runs:3"
                                " on Process\\.run:\\1\n"
                                "    1 process of Run\\.runs:3 waits in Run\\.runs:3\n\\z")).

%% report §12.4, Appendix E.18: a listener is among the processes a
%% deadlock lists, its line its count and its site with no frame. A
%% regression test, written after the code; a listener of `Tcp.listenTls`
%% is not covered
deadlock_line_of_a_listener_test() ->
    Lines = deadlock_lines("listening",
                           "    let _ = Tcp.listen(\"127.0.0.1\", 0);\n"
                           "    let _ = Tcp.listen(\"127.0.0.1\", 0);\n"),
    ?assertEqual(<<"    2 processes of Tcp.listen wait\n">>, Lines).

%% report §12.4, Appendix E.18: a socket is among the processes a deadlock
%% lists, its line its count and its site with no frame, the one the
%% connect opened and the one the accept opened told apart by their sites,
%% beside their listener's. A regression test, written after the code; a
%% socket over TLS is not covered
deadlock_line_of_a_socket_test() ->
    Lines = deadlock_lines("connected",
                           "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
                           "        Right(listener) -> match Tcp.port(listener) {\n"
                           "            Right(port) -> {\n"
                           "                let _ = Tcp.connect(\"127.0.0.1\", port, 5000);\n"
                           "                let _ = Tcp.accept(listener, 5000);\n"
                           "                Unit\n"
                           "            }\n"
                           "          | Left(_) -> Unit\n"
                           "        }\n"
                           "      | Left(_) -> Unit\n"
                           "    };\n"),
    ?assertEqual(<<"    1 process of Tcp.accept waits\n"
                   "    1 process of Tcp.connect waits\n"
                   "    1 process of Tcp.listen waits\n">>, Lines).

%% report §12.4, §8.6, Appendix E.23: a running program is among the
%% processes a deadlock lists, its line its count and its site with no
%% frame, once a read has answered its exit, before which it is no
%% deadlock (§8.6). A regression test, written after the code; a program of
%% `Os.startTerminal` is not covered
deadlock_line_of_a_program_test() ->
    Lines = deadlock_lines("started",
                           "    match Os.start(Os.command(\"true\", [])) {\n"
                           "        Right(program) -> exited(program)\n"
                           "      | Left(_) -> Unit\n"
                           "    };\n"),
    ?assertEqual(<<"    1 process of Os.start waits\n">>, Lines).

%% The lines of the deadlock a program's `main` ends in once Opening has
%% run, its entry process waiting in a `receive` for what no one sends,
%% the trace's frame left out.
deadlock_lines(Name, Opening) ->
    Dir = tmp(),
    Module = [string:to_upper(hd(Name)) | tl(Name)],
    write(Dir, "src/" ++ Name ++ ".ern",
          "type Waits = Waits\n"
          "fn exited(program : Address(Os.ProgramMsg)) : Unit = match Os.read(program, 5000) {\n"
          "    Right(Os.Exited(_)) -> Unit\n"
          "  | Right(_) -> exited(program)\n"
          "  | Left(error) -> fault(Io.show(error))\n"
          "}\n"
          "export fn main() : Unit receiving Waits = {\n" ++ Opening ++
          "    receive { Waits -> Unit }\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    {Errors, 1} = standard_error_of(["run", Dir ++ "/build/" ++ Name ++ ".erc"]),
    {match, [Lines]} = re:run(Errors, "^" ++ Module ++ ".main faulted: deadlock\n    "
                                      ++ Module ++ ".main:[0-9]+\n(.*)$",
                              [dotall, {capture, [1], binary}]),
    Lines.

%% report §11.2, §12.4: under `ern test` the test's name alone is its
%% process's spawn site, so a process that calls the test's process names
%% it so: here the test's `run` spawns a client that calls it with
%% `callForever`, and then waits in a `receive` for something else, so that
%% the test faults with a deadlock, the client's line beneath its trace.
%% A regression test, written after the code; it does not cover a doc
%% example's case, which runs as a program of its own
deadlock_line_on_a_test_test() ->
    Dir = tmp(),
    write(Dir, "src/asks.ern",
          "type Req = Get(Reply(Int)) | Other\n"
          "fn client(server : Address(Req)) : Unit = {\n"
          "    let _ = Address.callForever(server, Get);\n"
          "    Unit\n"
          "}\n"
          "let stuck = Test.Case(name = \"stuck\", run = fn() : Test.Result receiving Req = {\n"
          "    let me = self();\n"
          "    let _ = spawn(fn() = client(me));\n"
          "    receive { Other -> Test.Passed }\n"
          "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_err(["test", Dir ++ "/build/asks.erc"])),
    {match, [Listed]} = re:run(iolist_to_binary(?capturedOutput),
                               "^stuck: faulted: deadlock\n    Asks\\.[^\n]*\n(.*)$",
                               [dotall, {capture, [1], binary}]),
    ?assertEqual(<<"    1 process of Asks.stuck:8 waits in Asks.client:3 on stuck\n">>, Listed).

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
%% main/stack.ern compiles, `STACK.negate` is main's own member, which
%% prefix `-` reaches (§4.5), and `Stack.one` is the child module's. A
%% regression test, written after the code; single-file mode is not covered.
case_distinct_names_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export type STACK = STACK(Int)\n"
          "export type Stack2 = A\n"
          "export type STACK2 = B\n"
          "export fn STACK.negate(s : STACK) : Int = match s { STACK(n) -> n }\n"
          "export fn main() : Unit = Io.println(Int.toString(\n"
          "    -STACK(3) * 100 + -STACK(4) * 10\n"
          "    + Stack.one()))\n"),
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
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", "src/stdlib"])),
    ?assert(filelib:is_regular(Dir ++ "/build/bool.erc")),
    write(Dir, "src/bool.ern", "export fn not(b : Bool) : Bool = b\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/b2", Dir ++ "/src"])).

%% report §4.2, §11.1: a file under the standard library's source root is
%% compiled with that root, the default for it; another root is an error
stdlib_file_takes_its_root_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir,
                                 "src/stdlib/optional.ern"])),
    %% report §11.1: and builds into build/stdlib, where its dependencies are
    ?assertEqual(0, ern_cli:ern(["doc", "src/stdlib/float.ern"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "# Ernest module Float")),
    ?assert(filelib:is_regular(Dir ++ "/optional.erc")),
    ?assertEqual(1, ern_cli:ern(["build", "--source-root", ".", "--build-root", Dir,
                                 "src/stdlib/optional.ern"])).

%% report §4.2, §11.1: `Ernest`, the toolchain's namespace, is taken with
%% every namespace under it: `ernest.ern` at a source root and
%% `ernest/shell.ern` under it are refused as `io.ern` is, each naming
%% whose namespace it takes, and the file beside them is built; a file
%% under the shell's own source root is compiled with that root, the
%% default for it, and another root is an error, as for the standard
%% library's. Written with the code
ernest_namespace_taken_test() ->
    Dir = tmp(),
    write(Dir, "src/ernest.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/ernest/shell.ern", "export fn f() : Int = 1\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, build_err(["--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertMatch({_, _},
                 binary:match(Output, <<"ernest.ern takes the toolchain's namespace Ernest">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ernest/shell.ern stands under the toolchain's"
                                                " namespace Ernest">>)),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    ?assertEqual([], filelib:wildcard("**/*.erc", Dir ++ "/build") -- ["main.erc"]),
    Style = "src/shell/ernest/shell/style.ern",
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/shell", Style])),
    ?assert(filelib:is_regular(Dir ++ "/shell/ernest/shell/style.erc")),
    ?assertEqual(1, build_err(["--source-root", "src", "--build-root", Dir ++ "/other",
                               Style])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"style.ern is in the shell's source root;"
                                        " omit --source-root">>)).

%% report §11.1: a path under one of the toolchain's own source roots, with
%% no --source-root, takes that root, and with no --build-root that root's
%% build beside the toolchain, `build/stdlib` for the standard library's and
%% `build/shell` for the shell's; any other root builds into itself, and
%% --build-root names another for every root. Read by the functions the
%% build asks, so that nothing is built into the tree. Written with the code
own_roots_build_roots_test() ->
    Tree = ern_tree:tree(),
    Style = filename:join([Tree, "src", "shell", "ernest", "shell", "style.ern"]),
    List = filename:join([Tree, "src", "stdlib", "list.ern"]),
    Roots = fun(Options, Path) ->
                ern_build:build_root(Options, ern_build:source_root(Options, Path, "."))
            end,
    ?assertEqual(ern_tree:build("shell"), Roots([], Style)),
    ?assertEqual(ern_tree:build("stdlib"), Roots([], List)),
    Dir = tmp(),
    ?assertEqual(ern_build:absolute(Dir), Roots([{source_root, Dir}], Dir ++ "/main.ern")),
    [?assertEqual(ern_build:absolute(Dir ++ "/out"), Roots([{build_root, Dir ++ "/out"}], Path))
     || Path <- [Style, List]].

%% report §4.2: each of the toolchain's own source roots provides its own
%% namespaces alone: the standard library's the prelude's and its own, so
%% that `ernest.ern` and `ernest/shell.ern` under it are refused as under
%% any root, and the shell's `Ernest` alone, so that a file outside
%% `Ernest` under it is refused, a namespace of the standard library's
%% among them. Each is read by its path alone, which names a file that
%% nothing writes into the tree. Written with the code
own_roots_provide_their_namespaces_test() ->
    Stdlib = filename:join([ern_tree:tree(), "src", "stdlib"]),
    Shell = filename:join([ern_tree:tree(), "src", "shell"]),
    Refusal = fun(Root, Relative) ->
                  try ern_build:module_of(filename:join(Root, Relative), Root, file) of
                      _ -> accepted
                  catch
                      throw:{cli_error, Message} -> Message
                  end
              end,
    ?assertEqual("src/stdlib/ernest.ern takes the toolchain's namespace Ernest",
                 Refusal(Stdlib, "ernest.ern")),
    ?assertEqual("src/stdlib/ernest/shell.ern stands under the toolchain's namespace Ernest",
                 Refusal(Stdlib, "ernest/shell.ern")),
    ?assertEqual(accepted, Refusal(Stdlib, "list.ern")),
    ?assertEqual(accepted, Refusal(Stdlib, "int.ern")),
    ?assertEqual("src/shell/io.ern is in the shell's source root, which provides Ernest alone",
                 Refusal(Shell, "io.ern")),
    ?assertEqual("src/shell/tool/main.ern is in the shell's source root, which provides Ernest"
                 " alone",
                 Refusal(Shell, "tool/main.ern")),
    ?assertEqual(accepted, Refusal(Shell, "ernest/shell/style.ern")).

%% report §4.2: a program names nothing under `Ernest`, the toolchain's
%% own: a name there is unknown, the message saying why, though the load
%% path holds a build of the shell's, and no dependency is looked for
%% under it. A regression test: `Ernest.Shell.Style.quiet` built where the
%% load path held the shell's build, and a build without one advised
%% compiling `Ernest` first; it does not cover the shell's prompt, whose
%% inputs the checker reads by the same function
program_names_nothing_under_ernest_test() ->
    Dir = tmp(),
    Style = "src/shell/ernest/shell/style.ern",
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/shell", Style])),
    write(Dir, "src/main.ern", "export fn main() : Unit = Io.println(Ernest.Shell.Style.quiet)\n"),
    [begin
         ?assertEqual(1, build_err(LoadPath ++ ["--build-root", Dir ++ "/build", Dir ++ "/src"])),
         ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                           <<"unknown name Ernest.Shell.Style.quiet: a name under"
                                             " Ernest is the toolchain's own, and no program's">>))
     end || LoadPath <- [[], ["--load-path", Dir ++ "/shell"]]],
    ?assertEqual(nomatch, binary:match(iolist_to_binary(?capturedOutput), <<"compile ">>)).

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
%% after the code
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

%% report §11.2, §11.8, Appendix E.24: under `ern test` a service binding
%% starts its service as under `ern run`, which a test calls; a fault of a
%% process the initializers started, the service's own after it restarts, is
%% reported as `ern run` reports it, and the job exits with status 1 though
%% every case passed, and so does a fault of a process a case started once
%% its case has ended; a fault a process `Test.faults` started meets, or one
%% a case started, directly or through a process it started, while the case
%% runs, fails nothing. A regression test, written after the code (the log's
%% *Reload, Services and Tests*, *Refined at the build*): four faults of a
%% service left the status 0
test_fault_fails_the_run_test() ->
    Dir = tmp(),
    Service = "export type HouseMsg = Ask(Reply(Int)) | Boom\n"
              "fn serve() : Unit receiving HouseMsg =\n"
              "    receive {\n"
              "        Ask(reply) -> { answer(reply, 7); serve() }\n"
              "      | Boom -> fault(\"boom\")\n"
              "    }\n"
              "export let house =\n"
              "    spawn(restarting(RestartLimit(restarts = 3, within = 5000), serve))\n",
    File = write(Dir, "svc.ern",
                 [Service,
                  "let asks = Test.Case(name = \"asks\", run = fn() =\n"
                  "    Test.equal(Address.call(house, Ask, 1000), Some(7)))\n"
                  "let booms = Test.Case(name = \"booms\", run = fn() = {\n"
                  "    send(house, Boom);\n"
                  "    Test.until(fn() = Test.equal(Address.call(house, Ask, 1000), Some(7)),\n"
                  "               5000)\n"
                  "})\n"]),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Errors, Status} = standard_error_of(["test", filename:join(Dir, "svc.erc")]),
    ?assertEqual(1, Status),
    ?assertEqual(<<"asks: passed\nbooms: passed\n">>, iolist_to_binary(?capturedOutput)),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(Errors),
                                      <<"Svc.house:8 faulted, restarted: boom">>)),
    Expected = write(Dir, "expected.ern",
                     "type Msg = Ended(Down)\n"
                     "let expected = Test.Case(name = \"expected\", run = fn() =\n"
                     "    Test.faults(fn() = fault(\"boom\"), \"boom\"))\n"
                     "let provoked = Test.Case(name = \"provoked\", run = fn() = {\n"
                     "    let _ = spawnMonitored(fn() = {\n"
                     "        let _ = spawnMonitored(fn() = fault(\"provoked\"), Ended);\n"
                     "        receive { Ended(_) -> fault(\"provoked\") }\n"
                     "    }, Ended);\n"
                     "    receive { Ended(_) -> Test.Passed }\n"
                     "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, Expected])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "expected.erc")])),
    After = write(Dir, "after.ern",
                  "type Go = Go\n"
                  "let board : Ets.Table(Int, Address(Go)) = Ets.new()\n"
                  "let parks = Test.Case(name = \"parks\", run = fn() = {\n"
                  "    let parked = spawn(fn() = receive { Go -> fault(\"after its case\") });\n"
                  "    Ets.put(board, 1, parked);\n"
                  "    Test.Passed\n"
                  "})\n"
                  "let wakes = Test.Case(name = \"wakes\", run = fn() =\n"
                  "    match Ets.get(board, 1) {\n"
                  "        Some(parked) -> {\n"
                  "            monitor(Process.fromAddress(parked), fn(d : Down) = d);\n"
                  "            send(parked, Go);\n"
                  "            receive { _ -> Test.Passed }\n"
                  "        }\n"
                  "      | None -> Test.Failed(\"none parked\")\n"
                  "    })\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, After])),
    {AfterErrors, AfterStatus} = standard_error_of(["test", filename:join(Dir, "after.erc")]),
    ?assertEqual(1, AfterStatus),
    ?assertMatch({_, _}, binary:match(unicode:characters_to_binary(AfterErrors),
                                      <<"faulted: after its case">>)).

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

%% report §11.2, Appendix E.24: a failed `Test.equal` and a failed doc
%% example say where the two texts part after a beginning they share, the
%% first grapheme that differs or the one past the shorter's end, and say
%% nothing more where the texts differ at once. A regression test, written
%% after the code; it does not cover a grapheme of several code points
failure_says_where_test() ->
    Dir = tmp(),
    write(Dir, "src/marks.ern",
          "/// Texts that part.\n"
          "///\n"
          "/// ```ernest\n"
          "/// \"abcd\"\n"
          "/// // => \"abxd\"\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// 12\n"
          "/// // => 123\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// 3\n"
          "/// // => 4\n"
          "/// ```\n"
          "\n"
          "let lists = Test.Case(name = \"lists\", run = fn() = Test.equal([1, 2, 3], [1, 2, 4]))\n"
          "\n"
          "let texts = Test.Case(name = \"texts\", run = fn() = Test.equal(\"ab\", \"abc\"))\n"
          "\n"
          "let numbers = Test.Case(name = \"numbers\", run = fn() = Test.equal(3, 4))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/marks.erc"])),
    ?assertEqual(<<"lists: failed: expected [1, 2, 4], got [1, 2, 3], differing at character 8\n"
                   "texts: failed: expected \"abc\", got \"ab\", differing at character 4\n"
                   "numbers: failed: expected 4, got 3\n"
                   "Marks example 1: failed: expected \"abxd\", got \"abcd\", "
                   "differing at character 4\n"
                   "Marks example 2: failed: expected 123, got 12, differing at character 3\n"
                   "Marks example 3: failed: expected 4, got 3\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, Appendix E.0 shape rule 6: a doc example that shows a
%% value runs in a process whose mailbox type is that of the function it is
%% compiled into, as a test runs: one that sets an alarm with a wrap and
%% cancels it, and one that receives what the wrap delivers, outside the
%% module and inside it for a private declaration, run and pass. Written
%% with the rule, and run against the wrapper that ran an example at Never,
%% where each failed with `docExample needs mailbox Rings.Ring, and the
%% mailbox here is Never`. It does not cover an example whose mailbox type
%% is process-only, nor a run on a node
doc_example_mailbox_test() ->
    Dir = tmp(),
    write(Dir, "src/rings.ern",
          "/// A ring at the time it rang.\n"
          "export type Ring = Rang(Int)\n"
          "\n"
          "/// Rings in `ms` milliseconds.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Clock.cancel(Rings.ring(60000))\n"
          "/// // => true\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// {\n"
          "///     let _ = Rings.ring(1);\n"
          "///     receive { Rings.Rang(time) -> time > 0 }\n"
          "/// }\n"
          "/// // => true\n"
          "/// ```\n"
          "export fn ring(ms : Int) : Clock.Alarm receiving Ring = Clock.alarm(ms, Rang)\n"
          "\n"
          "/// Rings at once.\n"
          "///\n"
          "/// ```ernest\n"
          "/// {\n"
          "///     let _ = now();\n"
          "///     receive { Rang(_) -> \"rang\" }\n"
          "/// }\n"
          "/// // => \"rang\"\n"
          "/// ```\n"
          "fn now() : Clock.Alarm receiving Ring = ring(0)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["test", Dir ++ "/build/rings.erc"])),
    ?assertEqual(<<"Rings.ring example 1: passed\n"
                   "Rings.ring example 2: passed\n"
                   "Rings.now example 1: passed\n">>,
                 iolist_to_binary(?capturedOutput)).

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
          "/// // => Left(Io.NotFound)\n"
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
             "/// // => Doubles.Box(6)\n"
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

%% report §11.2, §11.5: an exported declaration's doc example, and the
%% module's own, stand outside the module and name its declarations as a
%% caller does, so one that names an exported function plain fails with
%% the help that qualifies it, and one that names a private one plain is
%% given none, since no caller can name it. A regression test: the failure
%% said nothing of the qualified name
example_names_the_module_qualified_test() ->
    Dir = tmp(),
    write(Dir, "src/checks.ern",
          "/// Sums.\n"
          "///\n"
          "/// ```ernest\n"
          "/// add(1, 2)\n"
          "/// // => 3\n"
          "/// ```\n"
          "\n"
          "/// The sum of `a` and `b`.\n"
          "///\n"
          "/// ```ernest\n"
          "/// add(1, 2)\n"
          "/// // => 3\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// Checks.add(1, 2)\n"
          "/// // => 3\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// added(1)\n"
          "/// // => 1\n"
          "/// ```\n"
          "export fn add(a : Int, b : Int) : Int = added(a) + b\n"
          "\n"
          "fn added(a : Int) : Int = a\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(1, ern_cli:ern(["test", Dir ++ "/build/checks.erc"])),
    ?assertEqual(<<"Checks example 1: failed: unknown name add; write `Checks.add`\n"
                   "Checks.add example 1: failed: unknown name add; write `Checks.add`\n"
                   "Checks.add example 2: passed\n"
                   "Checks.add example 3: failed: unknown name added\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §11.2, §4.2: a private declaration's doc example in Io itself is
%% compiled inside Io with `Io.show` written plain, as Io writes its own
%% declaration where no binding hides it, and checks there. A regression
%% test, written after the code, for what ern_doc_tests wrote and `ern
%% test` did not: the example's module named `Io.show` qualified, which Io
%% refuses. It does not cover the example's run, since a module of a
%% standard library namespace is built in the library's source root alone,
%% which holds no private declaration with an example
private_io_example_test() ->
    {ok, Source} = file:read_file("src/stdlib/io.ern"),
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
              "Stacks.Stack example 3: failed: expected [4], got [3], differing at character 2\n">>,
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

%% report §12.5, §11.2: a line a node says while no launch is in progress,
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
%% line, and the next runs after it. The status is 1 for each module.
%%
%% A regression test, written after the code: the initializer's fault was
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
          "  | Left(_) -> kill(Process.fromAddress(initializing))\n"
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
                   "Configs.size example 1: faulted: config.txt cannot be read: Io.NotFound\n"
                   "Configs.size example 2: compiled\n"
                   "Kills.nothing example 1: killed\n"
                   "Kills.nothing example 2: compiled\n"
                   "Divides.divide example 1: faulted: division by zero\n"
                   "Divides.divide example 2: passed\n">>,
                 untraced(Output)),
    ?assertMatch({_, _}, binary:match(Output, <<"Io.NotFound\n    Configs.config:3\n"
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

%% report §11.2, §4.1, §4.2: a private declaration's doc example, compiled
%% inside its module, may name a module as an exported declaration's may,
%% from the module's place, `Child` for `Top.Child`, and its program
%% initializes it; one that names a module that uses the documented module
%% fails as a cycle, since the example's module is the documented one. A
%% regression test, written after the code: the first example failed with
%% `unknown name`; it does not cover a cycle through a module between the
%% two
private_doc_example_names_a_module_test() ->
    Dir = tmp(),
    write(Dir, "src/top.ern",
          "/// Three.\n"
          "///\n"
          "/// ```ernest\n"
          "/// Child.twice(three())\n"
          "/// // => 6\n"
          "/// ```\n"
          "///\n"
          "/// ```ernest\n"
          "/// User.four()\n"
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
    ?assertMatch({_, _}, binary:match(Output, <<"points: failed: expected "
                                                "Equals.Point(x = 1, y = 3), "
                                                "got Equals.Point(x = 1, y = 2), "
                                                "differing at character 25\n">>)),
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
                 "    Test.faults(fn() = kill(Process.fromAddress(self())), \"division by"
                 " zero\"))\n"
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

%% report Appendix E.24, E.21, §6.9, §8.6: where the caller of `Test.faults`
%% ends before the call's process, here faulted by the deadlock its wait
%% makes, the call's process is killed and the process that judged it ends,
%% so that the next test finds each process `Test.faults` started ending:
%% the call's at the site where `Test.faults` calls `Process.run`, and the
%% judge's at `Process.run`'s own. The second test monitors each it finds
%% and waits for their ends, which a process left waiting would turn into
%% that test's own deadlock. A regression test, written after the code: both
%% processes outlived the caller. It does not cover a caller the interrupt
%% ends in the shell.
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
                 "            Some(status) -> String.startsWith(status.site, \"Test.faults\")"
                 " || String.startsWith(status.site, \"Process.run\")\n"
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

%% report Appendix E.24, §6.9: `Test.until` runs its test again until it
%% passes, so that a test waits for what a server did with a `Down` the
%% runtime delivered it, which has no order with the test's own call: the
%% server answers its first count after its monitor is set and before the
%% kill, and the next once it has seen the death. A regression test,
%% written after the code; the same test without `until` failed each of
%% twenty runs, the server answering before it had the `Down`. It does not
%% cover a `Down` from another node
test_until_waits_for_a_down_test() ->
    Dir = tmp(),
    File = write(Dir, "downs.ern",
                 "type CounterMsg = Count(Reply(Int)) | Ended(Down)\n"
                 "type Work = Work\n"
                 "fn counting(count : Int) : Unit receiving CounterMsg =\n"
                 "    receive {\n"
                 "        Count(reply) -> {\n"
                 "            answer(reply, count);\n"
                 "            counting(count)\n"
                 "        }\n"
                 "      | Ended(_) -> counting(count + 1)\n"
                 "    }\n"
                 "let downs = Test.Case(name = \"downs\", run = fn() = {\n"
                 "    let worker = spawn(fn() = receive { Work -> Unit });\n"
                 "    let server = spawn(fn() = {\n"
                 "        monitor(Process.fromAddress(worker), Ended);\n"
                 "        counting(0)\n"
                 "    });\n"
                 "    let monitored = Address.call(server, Count, 1000);\n"
                 "    kill(Process.fromAddress(worker));\n"
                 "    if monitored == Some(0) then\n"
                 "        Test.until(fn() = Test.equal(Address.call(server, Count, 1000), "
                 "Some(1)), 1000)\n"
                 "    else\n"
                 "        Test.Failed(\"the server did not answer\")\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Errors, Status} = standard_error_of(["test", filename:join(Dir, "downs.erc")]),
    ?assertEqual(0, Status),
    ?assertEqual(<<"downs: passed\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(<<>>, unicode:characters_to_binary(Errors)).

%% report Appendix E.24, E.0 shape rule 8: a test `Test.until` runs that
%% never passes answers its last `Failed`, which `ern test` reports as it
%% reports the test's own, and not a timeout; the run lasts the
%% milliseconds given, at least, and ends soon after them. A regression
%% test, written after the code; it bounds the run's time and does not
%% count the runs between, which the next test does where a test passes
test_until_answers_the_last_failure_test() ->
    Dir = tmp(),
    Ms = 200,
    File = write(Dir, "never.ern",
                 "let never = Test.Case(name = \"never\", run = fn() =\n"
                 "    Test.until(fn() = Test.equal(1 + 1, 3), " ++ integer_to_list(Ms) ++ "))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    Started = erlang:monotonic_time(millisecond),
    ?assertEqual(1, ern_cli:ern(["test", filename:join(Dir, "never.erc")])),
    Took = erlang:monotonic_time(millisecond) - Started,
    ?assertEqual(<<"never: failed: expected 3, got 2\n">>, iolist_to_binary(?capturedOutput)),
    ?assert(Took >= Ms),
    %% Ten times the milliseconds the test gives: room for a loaded host
    %% to start the run and end it, which a run that waits between its
    %% tests or misses its deadline would pass by far.
    ?assert(Took < 10 * Ms).

%% report Appendix E.24: `Test.capture` answers its call's value and what
%% the caller's chain wrote to each stream while the call ran, a server the
%% case started before the call among them; the later of two captures takes
%% the chain's writes until it returns; what was captured stands among
%% neither stream's lines, while a line after the capture does; and where
%% the caller faults inside the call, what was captured is written after
%% all. A regression test, written after the code; the page's example meets
%% a shell's live region (ern_site_shell_tests), and no case writes from a
%% process of another chain, a service's.
test_capture_test() ->
    Dir = tmp(),
    File = write(Dir, "cap.ern",
                 ["type EchoMsg = Say(text : String, reply : Reply(Unit))\n"
                  "fn echo() : Unit receiving EchoMsg =\n"
                  "    receive {\n"
                  "        Say(=text, =reply) -> {\n"
                  "            Io.printlnError(\"echo: \" <> text);\n"
                  "            answer(reply, Unit);\n"
                  "            echo()\n"
                  "        }\n"
                  "    }\n"
                  "fn text(bytes : Bytes) : String = String.fromUtf8Lossy(bytes)\n"
                  "let both = Test.Case(name = \"both\", run = fn() = {\n"
                  "    let #(value, captured) = Test.capture(fn() = {\n"
                  "        Io.println(\"out\");\n"
                  "        Io.printlnError(\"err\");\n"
                  "        42\n"
                  "    });\n"
                  "    Test.equal(#(value, text(captured.stdout), text(captured.stderr)),\n"
                  "               #(42, \"out\\n\", \"err\\n\"))\n"
                  "})\n"
                  "let earlier = Test.Case(name = \"earlier\", run = fn() = {\n"
                  "    let server = spawn(echo);\n"
                  "    let #(_, captured) = Test.capture(fn() =\n"
                  "        Address.callForever(server, fn(reply) = Say(text = \"hi\", =reply)));\n"
                  "    Test.equal(text(captured.stderr), \"echo: hi\\n\")\n"
                  "})\n"
                  "let nested = Test.Case(name = \"nested\", run = fn() = {\n"
                  "    let #(inner, outer) = Test.capture(fn() = {\n"
                  "        Io.printlnError(\"a\");\n"
                  "        let #(_, inner) = Test.capture(fn() = Io.printlnError(\"b\"));\n"
                  "        Io.printlnError(\"c\");\n"
                  "        inner\n"
                  "    });\n"
                  "    Test.equal(#(text(inner.stderr), text(outer.stderr)),\n"
                  "               #(\"b\\n\", \"a\\nc\\n\"))\n"
                  "})\n"
                  "let later = Test.Case(name = \"later\", run = fn() = {\n"
                  "    let _ = Test.capture(fn() = Io.printlnError(\"hidden\"));\n"
                  "    Io.printlnError(\"shown\");\n"
                  "    Test.Passed\n"
                  "})\n"
                  "let faulted = Test.Case(name = \"faulted\", run = fn() = {\n"
                  "    let _ = Test.capture(fn() = {\n"
                  "        Io.printlnError(\"written back\");\n"
                  "        fault(\"inside\")\n"
                  "    });\n"
                  "    Test.Passed\n"
                  "})\n"]),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Errors, Status} = standard_error_of(["test", filename:join(Dir, "cap.erc")]),
    ?assertEqual(1, Status),
    ?assertMatch(<<"both: passed\nearlier: passed\nnested: passed\nlater: passed\n"
                   "faulted: faulted: inside\n", _/binary>>,
                 iolist_to_binary(?capturedOutput)),
    ?assertEqual(<<"shown\nwritten back\n">>, unicode:characters_to_binary(Errors)).

%% report Appendix E.24, §8.6: a capture whose caller the program's end
%% ends, its caller waiting inside it as `main` returns, writes what it
%% took to standard error before the run stops its streams, every line in
%% order. A thousand lines take the collector a thousand writes back, so
%% that an end that did not wait for it would stop the streams among them.
%% It does not show the wait for a collector whose caller ended before the
%% end began, which `test_capture_test`'s faulted case meets under load.
capture_at_the_end_test() ->
    Dir = tmp(),
    File = write(Dir, "held.ern",
                 ["type HolderMsg = Hold(Reply(Unit))\n"
                  "fn printLine(number : Int) : Unit =\n"
                  "    Io.printlnError(Int.toString(number))\n"
                  "fn holding() : Unit receiving HolderMsg =\n"
                  "    receive {\n"
                  "        Hold(reply) -> {\n"
                  "            let _ = Test.capture(fn() = {\n"
                  "                List.forEach(List.range(1, 1000), printLine);\n"
                  "                answer(reply, Unit);\n"
                  "                holding()\n"
                  "            });\n"
                  "            Unit\n"
                  "        }\n"
                  "    }\n"
                  "export fn main() : Unit = {\n"
                  "    let holder = spawn(holding);\n"
                  "    Address.callForever(holder, Hold)\n"
                  "}\n"]),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Errors, Status} = standard_error_of(["run", filename:join(Dir, "held.erc")]),
    ?assertEqual(0, Status),
    ?assertEqual(iolist_to_binary([[integer_to_list(N), "\n"] || N <- lists:seq(1, 1000)]),
                 unicode:characters_to_binary(Errors)).

%% report Appendix E.24: `Test.until` runs its test in the caller's
%% process, once where the first run passes and again after each `Failed`
%% until one passes, three runs for a test that passes on its third,
%% counted by a server each run calls. A regression test, written after
%% the code; it does not show that the runs follow at once, which the
%% test before bounds
test_until_runs_until_passed_test() ->
    Dir = tmp(),
    File = write(Dir, "runs.ern",
                 "type CounterMsg = Count(Reply(Int)) | Next(Reply(Int))\n"
                 "fn counting(count : Int) : Unit receiving CounterMsg =\n"
                 "    receive {\n"
                 "        Count(reply) -> {\n"
                 "            answer(reply, count);\n"
                 "            counting(count)\n"
                 "        }\n"
                 "      | Next(reply) -> {\n"
                 "            answer(reply, count + 1);\n"
                 "            counting(count + 1)\n"
                 "        }\n"
                 "    }\n"
                 "let first = Test.Case(name = \"first\", run = fn() = {\n"
                 "    let caller = Process.current();\n"
                 "    let runs = spawn(fn() = counting(0));\n"
                 "    match Test.until(fn() = {\n"
                 "        let _ = Address.call(runs, Next, 1000);\n"
                 "        Test.equal(Process.current(), caller)\n"
                 "    }, 1000) {\n"
                 "        Test.Passed -> Test.equal(Address.call(runs, Count, 1000), Some(1))\n"
                 "      | failed -> failed\n"
                 "    }\n"
                 "})\n"
                 "let third = Test.Case(name = \"third\", run = fn() = {\n"
                 "    let runs = spawn(fn() = counting(0));\n"
                 "    match Test.until(fn() = Test.equal(Address.call(runs, Next, 1000), "
                 "Some(3)), 1000) {\n"
                 "        Test.Passed -> Test.equal(Address.call(runs, Count, 1000), Some(3))\n"
                 "      | failed -> failed\n"
                 "    }\n"
                 "})\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(0, ern_cli:ern(["test", filename:join(Dir, "runs.erc")])),
    ?assertEqual(<<"first: passed\nthird: passed\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2, Appendix E.24: no job reports a fault `Test.faults`
%% expects: under `ern run` a `main` whose call of it passes prints
%% `Test.Passed` and writes nothing on standard error, as `ern test` writes
%% nothing. A regression test, written after the code; the shell's is
%% test/ern_shell_tests.erl's
run_reports_no_expected_fault_test() ->
    Dir = tmp(),
    File = write(Dir, "expects.ern",
                 "export fn main() : Unit =\n"
                 "    Io.println(Io.show(Test.faults(fn() = 1 / 0, \"division by zero\")))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual({"", 0}, standard_error_of(["run", filename:join(Dir, "expects.erc")])),
    ?assertEqual(<<"Test.Passed\n">>, iolist_to_binary(?capturedOutput)).

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

%% report §11.2, §11.8: `ern` ends by the signal itself, and by the status
%% that stands for it where the helper that sends the signal cannot start:
%% a host of its own, its table of ports full, ends by sigterm's 143. A
%% regression test, written after the code: the host's refusal of the
%% helper's port raised, and the host halted with status 1. It does not
%% cover a helper that starts and then fails, whose answer ern_os's tests
%% hold.
died_at_a_full_port_table_test() ->
    Paths = lists:append([["-pa", filename:dirname(code:which(Module))]
                          || Module <- [ern_os, ern_signals]]),
    Ends = "Full = fun F() -> try open_port({fd, 2, 2}, [out]) of _ -> F() "
           "catch error:system_limit -> full end end, "
           "full = Full(), ern_signals:die(sigterm, 143).",
    Host = open_port({spawn_executable, filename:join([code:root_dir(), "bin", "erl"])},
                     [{args, ["-noshell", "+Q", "1024" | Paths] ++ ["-eval", Ends]},
                      {env, [{"ERL_CRASH_DUMP_SECONDS", "0"}]}, exit_status]),
    ?assertEqual(143, receive {Host, {exit_status, Status}} -> Status end).

%% report §11, §12.5: what the host logs as a warning a job writes on
%% standard error, where the job has started no run and the host's table
%% of processes is full too: a host of its own, its streams and its log
%% handler taken as a job takes them (ern_out:take/0), fills its table,
%% logs a warning, frees the table and logs another, and both are written.
%% A regression test, written after the code: the handler's first event
%% started the process that says it, the spawn raised at the full table,
%% and the host's logger, removing the handler, could not start its own
%% process and ended the host. It does not cover the reports a job drops
%% (ern_cli:said_otherwise/2), whose filter this host does not install.
logged_at_a_full_table_test() ->
    Paths = lists:append([["-pa", filename:dirname(code:which(Module))]
                          || Module <- [ern_out, ern_rt, ern_tty, ern_cli]]),
    Logs = "ErrorDevice = ern_out:take(), {module, _} = code:ensure_loaded(ern_cli), "
           "Fill = fun F(Held) -> try spawn(fun() -> receive stop -> ok end end) of "
           "P -> F([P | Held]) catch error:system_limit -> Held end end, "
           "Held = Fill([]), logger:warning(\"at a full table\"), "
           "Refs = [begin R = monitor(process, P), P ! stop, R end || P <- Held], "
           "[receive {'DOWN', R, _, _, _} -> ok end || R <- Refs], "
           "logger:warning(\"after it\"), ok = ern_rt:wait_for_later(), "
           "ok = ern_out:finish(ErrorDevice), halt(0).",
    Host = open_port({spawn_executable, filename:join([code:root_dir(), "bin", "erl"])},
                     [{args, ["-noshell", "-noinput", "+P", "1024" | Paths] ++ ["-eval", Logs]},
                      {env, [{"ERL_CRASH_DUMP_SECONDS", "0"}]}, binary, stderr_to_stdout,
                      exit_status]),
    {Status, Written} = host_written(Host, <<>>),
    ?assertEqual({0, [<<"at a full table">>, <<"after it">>]},
                 {Status, [Line || Line <- binary:split(Written, <<"\n">>, [global]),
                                   lists:member(Line, [<<"at a full table">>, <<"after it">>])]}).

%% What a host of its own wrote on its standard output and its standard
%% error, and the status it ended with.
host_written(Host, Written) ->
    receive
        {Host, {data, Bytes}} -> host_written(Host, <<Written/binary, Bytes/binary>>);
        {Host, {exit_status, Status}} -> {Status, Written}
    end.

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

%% report §12.5, §11.2: a `--config-dir` after `ern run`'s file is the
%% program's word, so the launcher's first start, which answers the flags
%% a node's host boots with, runs no program: parsed as that start parses
%% it, the job is no node and answers none, the program not run; and
%% through the launcher the program runs once, with the standard input it
%% is given. A regression test: the launcher read every word, and the
%% first start ran the program to its end, its effects made and its input
%% read, before the second ran it again with nothing left to read
program_config_dir_test() ->
    Dir = tmp(),
    write(Dir, "src/reads.ern",
          "export fn main() : Unit =\n"
          "    match Io.readLine() {\n"
          "        Some(line) -> Io.println(\"read: \" <> line)\n"
          "      | None -> Io.println(\"nothing to read\")\n"
          "    }\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Erc = Dir ++ "/build/reads.erc",
    persistent_term:put({ern_cli, flags}, true),
    try
        ?assertThrow({node_flags, []}, ern_cli:ern(["run", Erc, "--config-dir", Dir]))
    after
        persistent_term:erase({ern_cli, flags})
    end,
    ?assertEqual(<<>>, iolist_to_binary(?capturedOutput)),
    ?assertEqual("read: secret\n",
                 os:cmd("printf 'secret\\n' | bin/ern run " ++ Erc ++ " --config-dir "
                        ++ Dir)).

%% bin/ern, report §12.5, §11.2: the launcher passes over the value of each
%% option of `ern run` that takes one as it looks for `--config-dir` among
%% the job's own words, so its list is held equal to the options the job's
%% usage gives a value, `--config-dir` aside. Written with the list
launcher_run_options_test() ->
    {Help, 0} = help_of("run"),
    {match, Usage} = re:run(Help, "\\[--([a-z-]+) [^]\\s]+\\]",
                            [global, {capture, all_but_first, list}]),
    {ok, Launcher} = file:read_file("bin/ern"),
    {match, [Line]} = re:run(Launcher, "^ *(--[a-z-]+(?: \\| --[a-z-]+)*)\\) value=1 ;;$",
                             [multiline, {capture, all_but_first, list}]),
    ?assertEqual(lists:sort([Name || [Name] <- Usage, Name =/= "config-dir"]),
                 lists:sort([Name || "--" ++ Name <- string:split(Line, " | ", all)])).

%% bin/ern, report §12.5, §11.2: the launcher's first start, run as the
%% launcher runs it, answers the flags a node's host boots with for each
%% job that makes a node, `ern run`, `ern test` and `ern shell` given
%% `--config-dir`, and the limits `ernest.conf` names are among them, `+P`
%% the processes and `+Q` the ports, each the least power of two at or
%% above the number given. A regression test, written after the code; what
%% the host then holds is ern_nodes_tests' limits/1
node_limit_flags_test() ->
    Dir = tmp(),
    Node = filename:join(Dir, "node"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Node])),
    Conf = filename:join(Node, "ernest.conf"),
    ok = file:write_file(Conf, json:encode((conf_of(Node))#{<<"limits">> =>
                                                                 #{<<"processes">> => 50000,
                                                                   <<"ports">> => 4097}})),
    write(Dir, "src/waits.ern", "export fn main() : Unit = Unit\n"),
    ?assertEqual(0, ern_err(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    Erc = Dir ++ "/build/waits.erc",
    First = fun(Words) ->
                os:cmd("erl +B -boot no_dot_erlang -noshell -noinput"
                       " -pa build/toolchain/*/ebin -pa build/shared/ebin -pa build/nodes/ebin"
                       " -pa build/runtime/ebin -pa build/shell/ebin"
                       " -run ern_cli node_flags -extra " ++ Words ++ " < /dev/null")
            end,
    [begin
         Flags = First(Words),
         ?assertMatch({Words, "ern-node-flags '-proto_dist'" ++ _}, {Words, Flags}),
         ?assertNotEqual({Words, nomatch}, {Words, string:find(Flags, "'+P' '65536'")}),
         ?assertNotEqual({Words, nomatch}, {Words, string:find(Flags, "'+Q' '8192'")})
     end || Words <- ["run --config-dir " ++ Node ++ " " ++ Erc,
                      "test --config-dir " ++ Node ++ " " ++ Erc,
                      "shell --config-dir " ++ Node]].

%% bin/ern, report §12.5, §11: the launcher's first start writes the flags
%% alone on standard output, whatever the host logs as it works: a process
%% beside it logs a warning once the first start has begun its work, which
%% the flag it sets then shows, and standard output holds the flags' one
%% line. A regression test, written after the code: the first start kept
%% the host's own log handler, which writes on standard output, and a
%% warning before the flags made the launcher drop every flag. It does not
%% cover what the host logs as it boots, before the first start begins.
first_start_writes_the_flags_alone_test() ->
    Dir = tmp(),
    Node = filename:join(Dir, "node"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Node])),
    write(Dir, "src/waits.ern", "export fn main() : Unit = Unit\n"),
    ?assertEqual(0, ern_err(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    %% the warning waits on the flag alone, yielding between its reads
    Warns = "spawn(fun() -> Begun = fun B() -> case persistent_term:get({ern_cli, flags}, false)"
            " of true -> ok; false -> erlang:yield(), B() end end, ok = Begun(),"
            " logger:warning(\"a warning\") end)",
    Flags = os:cmd("erl +B -boot no_dot_erlang -noshell -noinput"
                   " -pa build/toolchain/*/ebin -pa build/shared/ebin -pa build/nodes/ebin"
                   " -pa build/runtime/ebin -pa build/shell/ebin"
                   " -eval '" ++ Warns ++ "' -run ern_cli node_flags -extra run --config-dir "
                   ++ Node ++ " " ++ Dir ++ "/build/waits.erc < /dev/null 2> /dev/null"),
    ?assertMatch({"ern-node-flags '-proto_dist'" ++ _, nomatch},
                 {Flags, string:find(Flags, "\n")}).

%% report §4.2: a module may not take a namespace of a standard library
%% module written in Ernest
stdlib_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/foreign.ern", "export fn atom(s : String) : String = s\n"),
    ?assertEqual(1, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])).

%% report §4.2: no standard module is named `Erl`, so `erl.ern` at a source
%% root is a program's own. A regression test
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
          "  | Rect(=w, =h) -> w * h\n"
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
    {ok, ['Geo'], Geo, _} = ern_build:compile_source(Dir ++ "/geo.ern", Dir,
                                                        ern_build:load_path_of([Dir]), #{}, #{}),
    {ok, #{interface := GeoInterface}} = ern_interface:read(Geo),
    {ok, ['Room'], Room, _} = ern_build:compile_source(Dir ++ "/room.ern", Dir,
                                                         ern_build:load_path_of([Dir]),
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
    %% working directory; a regression test of the name alone
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
    Rest = <<"> \nConsts.Point(x = 0, y = 0)\n[#(1, \"a\")]\n0.0\n1048576\n7\n">>,
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

%% report §11.5, §11.7: a diagnostic's first line,
%% `file:line:column: message`, is the one a tool reads, and no line after
%% it begins with the path; the build takes no option for a short form.
%% Written as the option went
error_first_line_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() : Unit = Io.println(1)\n"),
    ?assertEqual(1, build_err(["--source-root", Dir, File])),
    [First | Rest] = binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global]),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:38: the argument does not fit Io.println:"
                   " expected String, found Int">>, First),
    ?assertEqual([], [Line || Line <- Rest, binary:match(Line, list_to_binary(File)) =/= nomatch]),
    [?assertEqual(1, ern_err([Job, "--short-errors", File])) || Job <- ["build", "doc", "format"]].

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
        ?assertEqual(1, build_err(["bad.ern"])),
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

%% report §6.6, §11.2, Appendix E.21, E.24: a caller whose callee faulted
%% faults with the callee's cause unchanged, which `Test.faults` matches,
%% and the line of the caller's fault names the callee's site after the
%% cause, `ern run`'s and `ern test`'s alike, a test's own line among them,
%% the callee's own line its cause alone. A regression test, written after
%% the code, where the cause carried the site; the peer after the cause, a
%% compute's, is ern_nodes_tests'
callee_fault_line_test() ->
    Dir = tmp(),
    File = write(Dir, "calls.ern",
                 "type Msg = Ask(Reply(Int))\n"
                 "fn serve() : Unit receiving Msg =\n"
                 "    receive { Ask(reply) -> answer(reply, 1 / List.size([])) }\n"
                 "fn ask() : Int = Address.callForever(spawn(serve), Ask)\n"
                 "let asks = Test.Case(name = \"asks\", run = fn() =\n"
                 "    Test.faults(ask, \"division by zero\"))\n"
                 "let calls = Test.Case(name = \"calls\", run = fn() = {\n"
                 "    let _ = ask();\n"
                 "    Test.Passed\n"
                 "})\n"
                 "export fn main() : Unit = Io.println(Int.toString(ask()))\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    {Run, 1} = standard_error_of(["run", filename:join(Dir, "calls.erc")]),
    ?assertEqual(<<"Calls.ask:4 faulted: division by zero\n"
                   "Calls.main faulted: division by zero, the fault of the callee Calls.ask:4\n">>,
                 untraced(Run)),
    {Tests, 1} = standard_error_of(["test", filename:join(Dir, "calls.erc")]),
    ?assertEqual(<<"asks: passed\n"
                   "calls: faulted: division by zero, the fault of the callee Calls.ask:4\n">>,
                 untraced(?capturedOutput)),
    ?assertEqual(<<"Calls.ask:4 faulted: division by zero\n"
                   "Calls.ask:4 faulted: division by zero\n">>,
                 untraced(Tests)).

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

%% report §6.9, §7.4, §11.2: a restarting function called in a monitor's
%% wrap, which the runtime applies for the process the wrap delivers to,
%% faults with `Fault("restart in a function the runtime applies")`, the
%% fault of that process, which meets it at its next wait, and whose report
%% shows it with the wrap's line. Written with the code
restart_in_a_wrap_test() ->
    Dir = tmp(),
    File = write(Dir, "wrapped.ern",
                 "type Msg = Ended(Down)\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    let _ = spawnMonitored(fn() = Unit, fn(down) = {\n"
                 "        restarting(Unlimited, fn() = Unit)();\n"
                 "        Ended(down)\n"
                 "    });\n"
                 "    receive { Ended(_) -> Io.println(\"restarted\") }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, File])),
    ?assertEqual(1, ern_err(["run", filename:join(Dir, "wrapped.erc")])),
    ?assertEqual([<<"Wrapped.main faulted: restart in a function the runtime applies">>,
                  <<"    Wrapped.main:4">>],
                 binary:split(iolist_to_binary(?capturedOutput), <<"\n">>, [global, trim])).

%% report §11.2, §7.3, §12.3: beneath a foreign function's raise the fault
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

%% report §12.3, §11.2, Appendix E.21: a foreign function's return that does
%% not match its declared type faults with a cause that names the host's
%% function as a raise's cause does, and the trace is as for any fault the
%% runtime raises: the function has returned when its return is checked, so
%% no frame of it is in the trace, the runtime's frame that raises is left
%% out, and the trace is main's frame. A regression test, written after the
%% code, its runtime's frame taken out with the rule; it does not cover a
%% return checked in place, a word's, whose trace raise_has_line_test reads
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
                 "    compare(List.size(xs), List.size(ys))\n"
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
    %% report §4.2, §11.4: a member is shown in the form a program writes
    %% at its type, a parameter written as a pattern as `_`, after the
    %% module's other declarations
    Expect(<<"## Shapes.Box.compare\n\n```ernest\n"
             "compare(_, _) : Ordering\n```\n\nBy size.\n\n---\n">>),
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
                                      <<"compiled by another build of ern">>)).

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
%% document or page written or removed. A regression test, written after
%% the code: each run swept its own kind alone, the index kept the
%% module, and `ern doc` took no --verbose
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
    %% written after the code, a regression test
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
%% one there: a module added changes it, and a link at its place is no index
%% and is replaced. A regression test, written after the code; not covered:
%% an index its owner may not write, which is refused as a page is
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
%% newer is compiled. The source is changed under a .erc given a later time,
%% so that a page made from the .erc and one made from the source differ. A
%% regression test, written after the code; a manual page is read from the
%% .erc by the same code, and is not covered
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
%% from, nothing is compiled: a source that no longer parses, older than its
%% page and its .erc, is not read, and the job succeeds with every page left
%% as it is. Once its page is older than it, it is compiled and the job
%% fails. A regression test, written after the code
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
%% compiled from another source or holding another module, is not read for
%% its page, which is made from the module compiled. A regression test,
%% written after the code; it covers a .erc compiled from another source,
%% and not one holding another module or one this toolchain does not read,
%% which the same check refuses
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
                                                   "src/stdlib"]))
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
                                      "src/stdlib"])),
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
    ?assertEqual(0, ern_cli:ern(["doc", "--build-root", Dir, "src/stdlib"])),
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
    Source = "test/fixtures/programs/template.ern",
    ?assertEqual(0, ern_cli:ern(["doc", "--source-root", filename:dirname(Source), Source])),
    Output = iolist_to_binary(?capturedOutput),
    {ok, Template} = file:read_file("docs/module_doc_template.md"),
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

%% docs/development.md, "What the toolchain accepts": every text in the
%% toolchain's Erlang or in the shell's own Ernest source that says what
%% it refuses is not implemented, an error's or an option's help, appears
%% in that document's table, by its first forty characters, so the table
%% cannot drift from what the code refuses. A regression test; a refusal
%% worded otherwise escapes it
unimplemented_listed_test() ->
    {ok, Listed} = file:read_file("docs/development.md"),
    Pattern = "\"([^\"\n]*\\bis not implemented\\b[^\"\n]*)\"",
    Find = fun(Text) ->
               case re:run(Text, Pattern, [global, {capture, all_but_first, binary}]) of
                   {match, Matches} -> [Match || [Match] <- Matches];
                   nomatch -> []
               end
           end,
    %% the scan itself, on a sample, since every refusal may be lifted and
    %% a pattern that finds nothing would otherwise pass
    ?assertEqual([<<"x across nodes is not implemented">>],
                 Find("fail(\"x across nodes is not implemented\")")),
    Sources = [Source || Source <- filelib:wildcard("src/**/*.erl"),
                         not lists:member("test", filename:split(Source))]
        ++ filelib:wildcard("src/shell/**/*.ern"),
    ?assertNotEqual([], [Source || Source <- Sources, filename:extension(Source) =:= ".erl"]),
    %% a name the wildcard matches may not be a readable file: an editor's
    %% lock is a dangling symlink beside the file it locks, and a person
    %% with a source open should not see a red suite
    Texts = lists:usort(lists:append([Find(Text) || Path <- Sources,
                                                    {ok, Text} <- [file:read_file(Path)]])),
    Missing = [Refusal || Refusal <- Texts,
                          binary:match(Listed, binary:part(Refusal, 0, min(40, byte_size(Refusal))))
                              =:= nomatch],
    ?assertEqual([], Missing).

%% report §11, §12.5: --version prints the version text, the top-level
%% VERSION file's content, and in the repository's build, which is no
%% release, the mark after it; the release archive's is VERSION's alone,
%% which ern_install_tests' release test holds
version_test() ->
    {ok, Version} = file:read_file("VERSION"),
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
     || Job <- ["build", "doc", "format", "run", "test", "shell", "config", "reload", "stop",
                "unpack"]].

%% report §11: a job's `--help` stands alone, as `ern --help` does; the
%% option parser's refusals are written in the usage's words, an option
%% given no value with its metavariable, one the job does not take with
%% the jobs that take it, and words the job does not take counted. A
%% regression test, written after the code: `ern build --help x.ern`
%% printed the help, and the refusals were the vendored parser's own,
%% `missing option argument: --build-root <build_root>`
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
%% named and `ern --help`, which describes them; an empty first word is
%% none. A regression test of the empty word, which was refused as
%% `no job ;`, and of `ern help`, whose refusal named no `--help`
job_first_test() ->
    ?assertEqual(1, ern_err([])),
    ?assertEqual(1, ern_err(["", "x.erc"])),
    ?assertEqual(1, ern_err(["compile", "x.ern"])),
    ?assertEqual(1, ern_err(["help"])),
    Output = iolist_to_binary(?capturedOutput),
    ?assertEqual(2, length(binary:matches(Output, <<"ern: a job is required\nUsage: ern <job>">>))),
    ?assertEqual(nomatch, binary:match(Output, <<"no job ;">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern: no job compile; the jobs are build, doc,"
                                                " format, run, test, shell, config, reload,"
                                                " stop and unpack; ern --help describes"
                                                " them\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern: no job help; the jobs are build, doc,"
                                                " format, run, test, shell, config, reload,"
                                                " stop and unpack; ern --help describes"
                                                " them\n">>)).

%% report §11: `ern unpack` is refused as not implemented, in one line
%% with status 1 and no usage, and given an argument it is refused as
%% taking none, with its usage. A regression test, written after the code;
%% it does not cover the job's work, which is not built
unpack_not_implemented_test() ->
    ?assertEqual(1, ern_err(["unpack"])),
    ?assertEqual(<<"ern unpack: this job is not implemented\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertEqual(1, ern_err(["unpack", "x"])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput),
                                      <<"ern unpack: unpack takes no argument\n"
                                        "Usage: ern unpack\n">>)).

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

%% report §11.2 *The attached shell*: `--attach` takes no file, `--main`,
%% `--load-path` or `--libs-dir`, each refused naming the option, and needs
%% `--config-dir`, each refused before a node starts. A regression test,
%% written after the code
shell_attach_refused_test() ->
    Dir = tmp(),
    Attach = ["shell", "--config-dir", Dir, "--attach", "b"],
    Refused = [{["shell", "--attach", "b"],
                <<"ern shell: --attach needs --config-dir: the shell attaches from a node of its"
                  " own\n">>},
               {Attach ++ ["a.erc"],
                <<"ern shell: a file is not given with --attach: the node's program runs there,"
                  " and :load loads a module\n">>},
               {Attach ++ ["--main", "A.b"],
                <<"ern shell: --main is not given with --attach: the node's program runs"
                  " there\n">>},
               {Attach ++ ["--load-path", Dir],
                <<"ern shell: --load-path is not given with --attach: the load path is the"
                  " node's\n">>},
               {Attach ++ ["--libs-dir", Dir],
                <<"ern shell: --libs-dir is not given with --attach: the load path is the"
                  " node's\n">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Line)) || {_, Line} <- Refused].

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
    ?assertEqual(1, build_err([Dir ++ "/src"])),
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
               {["build", "--emit-erl", "--emit-erl", "x.ern"],
                <<"ern build: --emit-erl is given more than once">>},
               {["build", "--build-root=b", "x.ern"],
                <<"--build-root=b: an option's value is the next word, --build-root value">>},
               {["build", "--build-root", "", "x.ern"],
                <<"ern build: --build-root is given an empty value">>}],
    lists:foreach(fun({Args, _}) -> ?assertEqual(1, ern_err(Args)) end, Refused),
    Output = iolist_to_binary(?capturedOutput),
    [?assertMatch({_, _}, binary:match(Output, Text)) || {_, Text} <- Refused].

%% report §11.1: a module outside the source root is read from its .erc
%% under build-root, and the sweep keeps it. A regression test: only the
%% --load-path roots were searched, and the use was an unknown name
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
%% differ. A regression test; it does not cover the standard library's
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

%% report §11.2, §11.1: `ern run` and `ern test` refuse a compiled form
%% another build of `ern` wrote, here the same version whose code changed,
%% the file given and a module it uses from the load path alike, naming
%% the file, before anything runs; the forms the build wrote run. Written
%% with the code
another_build_refused_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/shape.ern", "export fn area(n : Int) : Int = n * n\n"),
    write(Dir, "src/main.ern", "export fn main() : Unit ="
                               " Io.println(Int.toString(Geo.Shape.area(3)))\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir ++ "/src"])),
    Main = Dir ++ "/src/main.erc",
    Shape = Dir ++ "/src/geo/shape.erc",
    {ok, MainBeam} = file:read_file(Main),
    {ok, ShapeBeam} = file:read_file(Shape),
    Another = fun(Chunk) -> Chunk#{compiler => <<?VERSION "+another">>} end,
    Refusal = fun(Job, File) ->
                  iolist_to_binary([Job, ": ", ern_build:shown(File),
                                    ": compiled by another build of ern\n"])
              end,
    Refused = fun(Job) ->
                  Before = byte_size(iolist_to_binary(?capturedOutput)),
                  ?assertEqual(1, ern_err([Job, Main])),
                  Output = iolist_to_binary(?capturedOutput),
                  binary:part(Output, Before, byte_size(Output) - Before)
              end,
    ok = file:write_file(Main, forge(MainBeam, Another)),
    ?assertEqual(Refusal("ern run", Main), Refused("run")),
    ?assertEqual(Refusal("ern test", Main), Refused("test")),
    ok = file:write_file(Main, MainBeam),
    ok = file:write_file(Shape, forge(ShapeBeam, Another)),
    ?assertEqual(Refusal("ern run", Shape), Refused("run")),
    ?assertEqual(Refusal("ern test", Shape), Refused("test")),
    ok = file:write_file(Shape, ShapeBeam),
    ?assertEqual(0, ern_err(["run", Main])),
    ?assertMatch({_, _}, binary:match(iolist_to_binary(?capturedOutput), <<"9\n">>)).

%% report §11.1, §11.2: a single-file build from another source root does
%% not write over a .erc of another namespace, naming --source-root where
%% the build was given none and the file's removal where it was; a build
%% that uses a module whose .erc holds another names that, and not the
%% source the other was compiled from; and `ern run` refuses a file that
%% holds another module than its path names. A regression test: the build
%% replaced it, and the run failed in the host's loader; and one written
%% after the code: the build named a source of the other module's as gone,
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
                   " Src.Geo.Shape's source root with --source-root, or remove"
                   " src/geo/shape.erc\n">>,
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
%% no site and, in a log, no time. The entry process waits in a `receive`
%% that nothing answers, until the kill ends it.
killed_entry_test() ->
    Dir = tmp(),
    File = write(Dir, "main.ern",
                 "type MainMsg = Stop\n"
                 "export fn main() : Unit receiving MainMsg = {\n"
                 "    let me = self();\n"
                 "    let _ = spawn(fn() = kill(Process.fromAddress(me)));\n"
                 "    receive { Stop -> Io.println(\"not killed\") }\n"
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

%% report §12.5, §11.2: a run given `--config-dir` is a node, whose host the
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
%% is not there. A regression test, written after the code: it created
%% ./.ernest, wrote into it with `--peer-dir`, and created every missing
%% parent
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

%% report §11.3, Appendix C: the configuration directory with no peer and no
%% service, a private key readable only by its owner and a certificate,
%% created where --config-dir names it, its public key printed, and no
%% `listen` where `--listen` gives none, a node that only dials; a second
%% creation fails. The `listen` left out is a regression test, written after
%% the code (the log's *The Shell's Own Node*): `0.0.0.0:8654` was written
%% for every directory
create_config_dir_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    {ok, Conf} = file:read_file(Dir ++ "/ernest.conf"),
    #{<<"peers">> := [], <<"services">> := #{},
      <<"public-key">> := <<"-----BEGIN PUBLIC KEY-----", _/binary>> = Public} = Decoded
        = json:decode(Conf),
    ?assertNot(is_map_key(<<"listen">>, Decoded)),
    ?assertEqual(Public, unicode:characters_to_binary(?capturedOutput)),
    %% laid out as Appendix C shows it, a key a line in its order; a
    %% regression test, it was one line with its keys sorted
    ?assertMatch([<<"{">>,
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

%% report §11.2, §12.5: `ern reload` and `ern stop` require --config-dir,
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

%% report §11.2, §12.5: `ern stop` refuses an ernest.pid a node holds that
%% every user may write, and one that is a link to such a file, with the
%% host's reason, each in its whole line, and the process the file names is
%% sent nothing. A regression test, written after the code: the line said
%% the file may be written by others than its owner, its group among them.
%% A file its group may write, which is signaled, is ern_os_tests'
%% node_file_test's; a file of another user's, which a test run as one user
%% cannot make, is not covered
stop_refuses_what_every_user_may_write_test() ->
    Dir = tmp() ++ "/.ernest",
    ?assertEqual(0, ern_cli:ern(["config", "--config-dir", Dir])),
    PidFile = Dir ++ "/ernest.pid",
    %% a living process that is no node, which reads its input and echoes it
    Living = open_port({spawn_executable, os:find_executable("cat")}, [binary]),
    {os_pid, Number} = erlang:port_info(Living, os_pid),
    Self = self(),
    Holder = spawn(fun() ->
                       Self ! {locked, ern_os:locked(PidFile, Number)},
                       receive stop -> ok end
                   end),
    receive {locked, Locked} -> ?assertEqual(locked, Locked) end,
    ok = file:change_mode(PidFile, 8#666),
    _ = ?capturedOutput,
    ?assertEqual(1, ern_err(["stop", "--config-dir", Dir])),
    %% the file the node holds renamed, and a link to it in its place
    ok = file:rename(PidFile, Dir ++ "/held.pid"),
    ok = file:make_symlink("held.pid", PidFile),
    ?assertEqual(1, ern_err(["stop", "--config-dir", Dir])),
    Said = unicode:characters_to_binary(?capturedOutput),
    MonitorRef = erlang:monitor(process, Holder),
    Holder ! stop,
    receive {'DOWN', MonitorRef, process, Holder, _} -> ok end,
    true = port_command(Living, <<"alive">>),
    Echoed = receive {Living, {data, Data}} -> Data end,
    port_close(Living),
    ?assertEqual(<<"alive">>, Echoed),
    [?assertMatch({_, _}, binary:match(Said, list_to_binary(["ern stop: ", ern_build:shown(PidFile),
                                                             ": ", Reason, "\n"])))
     || Reason <- ["may be written by every user", "too many levels of symbolic links"]].

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
%% the peer as Appendix C lays one out, and leaves a file a node reads. A
%% third directory, made without `--listen`, is listed with no address
config_peer_test() ->
    Dir = tmp(),
    [A, Foo, Ops] = [filename:join(Dir, Name) || Name <- ["a", "foo", "ops"]],
    [?assertEqual(0, ern_err(["config", "--config-dir" | Words]))
     || Words <- [[A, "--listen", "0.0.0.0:8654"], [Foo, "--listen", "127.0.0.1:8655"],
                  [A, "--peer-dir", Foo], [Foo, "--peer-dir", A]]],
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
    [?assertMatch({configuration, _, _, _, [{peer, _, _, {{127, 0, 0, 1}, _}}], _, _, _, _, _},
                  ern_node:read(Node)) || Node <- [A, Foo]],
    [?assertEqual(0, ern_err(["config", "--config-dir" | Words]))
     || Words <- [[Ops], [A, "--peer-dir", Ops]]],
    #{<<"peers">> := [_, ListedOps]} = conf_of(A),
    ?assertEqual([<<"name">>, <<"public-key">>], lists:sort(maps:keys(ListedOps))).

%% report §11.3, §11.7, §12.5: `--listen` gives the directory's `listen`,
%% any a node takes, port 0 among them; one a node refuses, an IPv4-mapped
%% address among them, is refused before the directory is made, and so is
%% a directory that exists
config_listen_test() ->
    Dir = tmp(),
    Six = filename:join(Dir, "six"),
    ?assertEqual(0, ern_err(["config", "--config-dir", Six, "--listen", "[::]:0"])),
    ?assertMatch(#{<<"listen">> := <<"[::]:0">>}, conf_of(Six)),
    ?assertEqual(1, ern_err(["config", "--config-dir", Six, "--listen", "127.0.0.1:8655"])),
    Refused = [{"localhost:8655", "--listen names no address: localhost:8655"},
               {"8655", "--listen is not address:port: 8655"},
               {"[::ffff:127.0.0.1]:0",
                "--listen names an IPv4-mapped address, [::ffff:127.0.0.1]:0, which no listener"
                " takes"}],
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
    [?assertEqual(0, ern_err(["config", "--config-dir", A, "--peer-dir", Dir ++ "/" ++ Given]))
     || Given <- ["all/", "all/../one", "silent"]],
    #{<<"peers">> := Listed} = conf_of(A),
    ?assertEqual([{<<"all">>, <<"[::1]:8660">>}, {<<"one">>, <<"[fe80::1]:8661">>},
                  {<<"silent">>, none}],
                 [{Name, maps:get(<<"network-address">>, Peer, none)}
                  || #{<<"name">> := Name} = Peer <- Listed]),
    ?assertMatch({configuration, _, _, _, [_, _, {peer, <<"silent">>, _, none}], _, _, _, _, _},
                 ern_node:read(A)).

%% report §11.3: `--peer-dir` writes `ernest.conf` again with every other field
%% as it was, in its order, the peers listed before it kept, and the peer
%% listed last; a link to the file is followed, and stays a link. `limits`
%% among the fields kept, its own in their order, is a regression test,
%% written after the code
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
                          " \"listen\": \"127.0.0.1:8654\", \"measures\": {\"cpu\": {}},"
                          " \"limits\": {\"ports\": 4096, \"processes\": 65536}}"]),
    %% report §12.5: written by none but its owner, whatever the umask
    ok = file:change_mode(Elsewhere, 8#644),
    Conf = filename:join(A, "ernest.conf"),
    ok = file:delete(Conf),
    ok = file:make_symlink(Elsewhere, Conf),
    ?assertEqual(0, ern_err(["config", "--config-dir", A, "--peer-dir", C])),
    ?assertMatch({ok, #file_info{type = symlink}}, file:read_link_info(Conf)),
    {ok, Text} = file:read_file(Elsewhere),
    InOrder = fun(Acc, Outer) -> {lists:reverse(Acc), Outer} end,
    {Value, ok, <<>>} = json:decode(Text, ok, #{object_finish => InOrder}),
    ?assertEqual([<<"utilization-interval">>, <<"public-key">>, <<"peers">>, <<"services">>,
                  <<"listen">>, <<"measures">>, <<"limits">>], [Name || {Name, _} <- Value]),
    ?assertMatch([{<<"utilization-interval">>, 2000}, _,
                  {<<"peers">>, [[{<<"name">>, <<"b">>}, {<<"public-key">>, KeyB}],
                                 [{<<"name">>, <<"c">>},
                                  {<<"network-address">>, <<"127.0.0.1:8656">>}, _]]},
                  {<<"services">>, [{<<"counter">>, [<<"b">>]}]}, _,
                  {<<"measures">>, [{<<"cpu">>, []}]},
                  {<<"limits">>, [{<<"ports">>, 4096}, {<<"processes">>, 65536}]}], Value).

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

%% report §11.3, §12.5: the peer's directory, its `ernest.conf` and its
%% certificate are read as a node reads its own: a file every user may
%% write, a file that is not JSON and a certificate that is none are
%% refused, each naming the peer's file, and nothing is written
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
     || Line <- [Shown(Open, "ernest.conf") ++ " may be written by every user",
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

%%
%% A given path, report §11
%%

%% A directory of its own with a link before `..`, `link` naming
%% `real/sub`, so that `link/../path` is `path` as §11 resolves it and
%% `real/path` as the host would open it; Run run with it the working
%% directory.
linked(Run) ->
    Dir = tmp(),
    ok = filelib:ensure_path(filename:join(Dir, "real/sub")),
    ok = file:make_symlink("real/sub", filename:join(Dir, "link")),
    in_directory(Dir, Run).

%% A job's status and what it wrote on standard output and standard error,
%% as EUnit captured them after what the test captured before.
said(Args) ->
    Before = unicode:characters_to_binary(?capturedOutput),
    Status = ern_err(Args),
    After = unicode:characters_to_binary(?capturedOutput),
    {Status, binary:part(After, byte_size(Before), byte_size(After) - byte_size(Before))}.

%% What a job said and its status where it refused its command line with
%% the one line Line.
refusal(Job, Line) ->
    {1, iolist_to_binary(["ern ", Job, ": ", Line, "\n"])}.

%% Under the directory Under: the program `given.erc`, which says hello;
%% `lib/given_store.erc`, and `given_user.erc`, which uses it; the tests
%% `t/given_checked.erc`; the source `src/given_page.ern`; a directory of
%% the host's applications, `libs`, that holds two of one name; and the
%% configuration directories `cfg` and `peer`.
given_tree(Under) ->
    In = fun(Path) -> filename:join(Under, Path) end,
    write(Under, "given.ern", hello()),
    write(Under, "lib/given_store.ern", "export fn size() : Int = 3\n"),
    write(Under, "given_user.ern",
          "export fn main() : Unit = Io.println(Int.toString(GivenStore.size()))\n"),
    write(Under, "t/given_checked.ern",
          "let counted : Test.Case(Never) =\n"
          "    Test.Case(name = \"counted\", run = fn() = Test.equal(1, 1))\n"),
    write(Under, "src/given_page.ern", hello()),
    ?assertEqual(0, ern_err(["build", "--source-root", Under, In("given.ern")])),
    ?assertEqual(0, ern_err(["build", In("lib")])),
    ?assertEqual(0, ern_err(["build", "--source-root", Under, "--load-path", In("lib"),
                             In("given_user.ern")])),
    ?assertEqual(0, ern_err(["build", In("t")])),
    [ok = filelib:ensure_path(In(Ebin)) || Ebin <- ["libs/app-1.0/ebin", "libs/app-2.0/ebin"]],
    [?assertEqual(0, ern_err(["config", "--config-dir", In(Made)])) || Made <- ["cfg", "peer"]],
    ok.

%% The program `given_other.erc` and the configuration directory `other`,
%% in the working directory, which no link before `..` reaches.
given_other() ->
    write(".", "given_other.ern", hello()),
    ?assertEqual(0, ern_err(["build", "given_other.ern"])),
    ?assertEqual(0, ern_err(["config", "--config-dir", "other"])),
    ok.

%% report §11: `ern build` makes its argument and the value of each option
%% that names a directory absolute from the working directory and resolves
%% `..` without following the link before it: it builds and writes what the
%% path resolved names, where the host would open no file through the link,
%% and refuses a path that names nothing so, naming it as resolved, where
%% the host would open a file through the link; a build root, which the
%% build makes, is made where it is resolved
build_given_paths_test() ->
    linked(fun() ->
                   write(".", "given.ern", hello()),
                   write(".", "src/given_page.ern", hello()),
                   write(".", "lib/given_store.ern", "export fn size() : Int = 3\n"),
                   write(".", "given_user.ern",
                         "export fn main() : Unit =\n"
                         "    Io.println(Int.toString(GivenStore.size()))\n"),
                   ?assertEqual(0, ern_err(["build", "lib"])),
                   ?assertEqual({0, <<>>}, said(["build", "link/../given.ern"])),
                   ?assert(filelib:is_regular("given.erc")),
                   ?assertEqual({0, <<>>}, said(["build", "link/../src"])),
                   ?assert(filelib:is_regular("src/given_page.erc")),
                   ?assertMatch({0, <<"source root src\nbuild root out\n", _/binary>>},
                                said(["build", "--verbose", "--source-root", "link/../src",
                                      "--build-root", "out", "src/given_page.ern"])),
                   ?assertEqual({0, <<>>}, said(["build", "--build-root", "link/../out",
                                                 "given.ern"])),
                   ?assert(filelib:is_regular("out/given.erc")),
                   ?assertEqual({0, <<>>}, said(["build", "--load-path", "link/../lib",
                                                 "given_user.ern"])),
                   ?assertNot(filelib:is_file("real/out"))
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   ok = filelib:ensure_path("real/out"),
                   ?assertEqual(refusal("build", "given.ern: no such file"),
                                said(["build", "link/../given.ern"])),
                   ?assertEqual(refusal("build", "src: no such file"),
                                said(["build", "link/../src"])),
                   ?assertEqual(refusal("build", "src: no such directory, which --source-root"
                                                 " names"),
                                said(["build", "--source-root", "link/../src",
                                      "given_other.ern"])),
                   ?assertEqual(refusal("build", "lib: no such directory, which --load-path"
                                                 " names"),
                                said(["build", "--load-path", "link/../lib", "given_other.ern"])),
                   ?assertEqual({0, <<>>}, said(["build", "--build-root", "link/../out",
                                                 "given_other.ern"])),
                   ?assert(filelib:is_regular("out/given_other.erc")),
                   ?assertEqual({ok, []}, file:list_dir("real/out"))
           end).

%% report §11, §11.4: `ern doc` reads and writes what its argument and the
%% value of each option that names a directory name as §11 resolves them,
%% and refuses one that names nothing so, naming it as resolved, though the
%% host would open a file through the link before `..`
doc_given_paths_test() ->
    linked(fun() ->
                   given_tree("."),
                   {0, Page} = said(["doc", "link/../given.ern"]),
                   ?assertMatch({_, _}, binary:match(Page, <<" from given.ern.\n">>)),
                   {0, Read} = said(["doc", "link/../given.erc"]),
                   ?assertMatch({_, _}, binary:match(Read, <<" from given.ern.\n">>)),
                   ?assertEqual({0, <<>>}, said(["doc", "link/../src"])),
                   ?assert(filelib:is_regular("src/given_page.md")),
                   {0, Rooted} = said(["doc", "--source-root", "link/../src",
                                       "src/given_page.ern"]),
                   ?assertMatch({_, _}, binary:match(Rooted, <<"# Ernest module GivenPage\n">>)),
                   ?assertEqual({0, <<>>}, said(["doc", "--build-root", "link/../docs", "src"])),
                   ?assert(filelib:is_regular("docs/given_page.md")),
                   {0, Used} = said(["doc", "--load-path", "link/../lib", "given_user.ern"]),
                   ?assertMatch({_, _}, binary:match(Used, <<"# Ernest module GivenUser\n">>)),
                   ?assertNot(filelib:is_file("real/docs"))
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   write(".", "other_src/given_other_page.ern", hello()),
                   ok = filelib:ensure_path("real/docs"),
                   [?assertEqual(refusal("doc", Line), said(["doc" | Words]))
                    || {Words, Line} <- [{["link/../given.ern"], "given.ern: no such file"},
                                         {["link/../given.erc"], "given.erc: no such file"},
                                         {["link/../src"], "src: no such file"},
                                         {["--source-root", "link/../src", "given_other.ern"],
                                          "src: no such directory, which --source-root names"},
                                         {["--load-path", "link/../lib", "given_other.ern"],
                                          "lib: no such directory, which --load-path names"}]],
                   ?assertEqual({0, <<>>}, said(["doc", "--build-root", "link/../docs",
                                                 "other_src"])),
                   ?assert(filelib:is_regular("docs/given_other_page.md")),
                   ?assertEqual({ok, []}, file:list_dir("real/docs"))
           end).

%% report §11, §11.6: `ern format` lays out the file and the directory its
%% arguments name as §11 resolves them, and refuses one that names nothing
%% so, naming it as resolved, though the host would open a file through the
%% link before `..`; `./-` is the file `-`, which is no module, and not
%% standard input, which `-` alone names and which stands alone
format_given_paths_test() ->
    Loose = <<"fn f(x) = x+1\n">>,
    linked(fun() ->
                   write(".", "loose/loose.ern", Loose),
                   ?assertEqual({1, <<"loose/loose.ern\n">>},
                                said(["format", "--check", "link/../loose"])),
                   ?assertEqual({1, <<"loose/loose.ern\n">>},
                                said(["format", "--check", "link/../loose/loose.ern"])),
                   ?assertEqual({0, <<>>}, said(["format", "link/../loose/loose.ern"])),
                   ?assertEqual({ok, <<"fn f(x) =\n    x + 1\n">>},
                                file:read_file("loose/loose.ern")),
                   write(".", "-", "fn g(y) =\n    y\n"),
                   ?assertEqual(refusal("format", "- does not end in .ern"),
                                said(["format", "--check", "./-", "loose/loose.ern"]))
           end),
    linked(fun() ->
                   write("real", "loose/loose.ern", Loose),
                   ?assertEqual(refusal("format", "loose: no such file"),
                                said(["format", "link/../loose"])),
                   ?assertEqual(refusal("format", "loose/loose.ern: no such file"),
                                said(["format", "link/../loose/loose.ern"])),
                   ?assertEqual({ok, Loose}, file:read_file("real/loose/loose.ern"))
           end).

%% The lines `ern run`, `ern test` and `ern shell` refuse a node's
%% directory with, read in a host that was not started as a node, and a
%% directory of the host's applications that holds two of one name with.
not_a_node() ->
    "the host was not started as a node, which ern does where the command line holds"
        " --config-dir".

two_apps() ->
    "libs holds more than one directory of the application app, app-1.0 and app-2.0, which"
        " --libs-dir names".

%% report §11, §11.2: `ern run` loads and runs the file its argument names,
%% and reads the directories its options name, as §11 resolves them, and
%% refuses one that names nothing so, naming it as resolved, though the
%% host would open a file through the link before `..`; the words after the
%% file are the program's, given as they are
run_given_paths_test() ->
    linked(fun() ->
                   given_tree("."),
                   write(".", "given_args.ern",
                         "export fn main() : Unit =\n"
                         "    Io.println(String.join(Os.arguments, \" \"))\n"),
                   ?assertEqual(0, ern_err(["build", "given_args.ern"])),
                   ?assertEqual({0, <<"hello, world\n">>}, said(["run", "link/../given.erc"])),
                   ?assertEqual({0, <<"3\n">>},
                                said(["run", "--load-path", "link/../lib", "given_user.erc"])),
                   ?assertEqual(refusal("run", two_apps()),
                                said(["run", "--libs-dir", "link/../libs", "given.erc"])),
                   ?assertEqual(refusal("run", not_a_node()),
                                said(["run", "--config-dir", "link/../cfg", "given.erc"])),
                   ?assertEqual({0, <<"./a link/../b\n">>},
                                said(["run", "given_args.erc", "./a", "link/../b"]))
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   [?assertEqual(refusal("run", Line), said(["run" | Words]))
                    || {Words, Line} <- [{["link/../given.erc"], "given.erc: no such file"}
                                         | missing_directories("given_other.erc")]]
           end).

%% The words that name a directory a run, a test or a shell reads with a
%% link before `..`, each with its refusal where only the host's path names
%% a directory, File given after them.
missing_directories(File) ->
    [{["--load-path", "link/../lib", File], "lib: no such directory, which --load-path names"},
     {["--libs-dir", "link/../libs", File], "libs: no such directory, which --libs-dir names"},
     {["--config-dir", "link/../cfg", File], "cfg: no such directory, which --config-dir names"}].

%% report §11, §11.2: `ern test` runs the tests of the file and of the
%% directory its argument names, and reads the directories its options
%% name, as §11 resolves them, and refuses one that names nothing so,
%% naming it as resolved, though the host would open a file through the
%% link before `..`
test_given_paths_test() ->
    linked(fun() ->
                   given_tree("."),
                   ?assertEqual({0, <<"no tests\n">>}, said(["test", "link/../given.erc"])),
                   ?assertEqual({0, <<"GivenChecked\ncounted: passed\n">>},
                                said(["test", "link/../t"])),
                   ?assertEqual({0, <<"no tests\n">>},
                                said(["test", "--load-path", "link/../lib", "given_user.erc"])),
                   ?assertEqual(refusal("test", two_apps()),
                                said(["test", "--libs-dir", "link/../libs", "given.erc"])),
                   ?assertEqual(refusal("test", not_a_node()),
                                said(["test", "--config-dir", "link/../cfg", "given.erc"]))
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   [?assertEqual(refusal("test", Line), said(["test" | Words]))
                    || {Words, Line} <- [{["link/../given.erc"], "given.erc: no such file"},
                                         {["link/../t"], "t: no such file"}
                                         | missing_directories("given_other.erc")]]
           end).

%% report §11, §11.2: `ern shell` loads the file its argument names, and
%% reads the directories its options name, the source root and the
%% configuration directory's startup file among them, as §11 resolves
%% them, and refuses one that names nothing so, naming it as resolved,
%% though the host would open a file through the link before `..`. The
%% shell itself, which reads a terminal, is not started: each job here is
%% refused before it starts, by `--main` or by a host that is no node
shell_given_paths_test() ->
    Shape = "; an entry point is an exported fn of no parameters whose result is Unit",
    linked(fun() ->
                   given_tree("."),
                   ?assertEqual(refusal("shell", "no exported function Given.none" ++ Shape),
                                said(["shell", "--main", "Given.none", "link/../given.erc"])),
                   ?assertEqual(refusal("shell", "no exported function GivenUser.none" ++ Shape),
                                said(["shell", "--load-path", "link/../lib", "--main",
                                      "GivenUser.none", "given_user.erc"])),
                   ?assertEqual(refusal("shell", two_apps()),
                                said(["shell", "--libs-dir", "link/../libs", "given.erc"])),
                   ?assertEqual(refusal("shell", not_a_node()),
                                said(["shell", "--source-root", "link/../src", "--config-dir",
                                      "link/../cfg"])),
                   ?assertEqual({'Some', <<"cfg/startup">>}, ern_shell:config_startup()),
                   ?assertEqual(list_to_binary(ern_build:absolute("src")),
                                ern_shell:given_source_root())
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   [?assertEqual(refusal("shell", Line), said(["shell" | Words]))
                    || {Words, Line} <- [{["link/../given.erc"], "given.erc: no such file"},
                                         {["--source-root", "link/../src", "given_other.erc"],
                                          "src: no such directory, which --source-root names"}
                                         | missing_directories("given_other.erc")]]
           end).

%% report §11, §11.3: `ern config` makes the directory `--config-dir` names,
%% and writes the one `--peer-dir` lists a peer in, as §11 resolves it,
%% reads the peer's as resolved, and refuses a path that names nothing so,
%% naming it as resolved, though the host would open a directory through
%% the link before `..`
config_given_paths_test() ->
    linked(fun() ->
                   given_tree("."),
                   ?assertMatch({0, _}, said(["config", "--config-dir", "link/../made"])),
                   ?assert(filelib:is_regular("made/ernest.conf")),
                   ?assertEqual({0, <<>>}, said(["config", "--config-dir", "link/../cfg",
                                                 "--peer-dir", "link/../peer"])),
                   ?assertMatch(#{<<"peers">> := [#{<<"name">> := <<"peer">>}]}, conf_of("cfg")),
                   ?assertNot(filelib:is_file("real/made"))
           end),
    linked(fun() ->
                   given_tree("real"),
                   given_other(),
                   [ok = filelib:ensure_path(Made) || Made <- ["real/new", "real/made"]],
                   ?assertEqual(refusal("config", "new: no such directory"),
                                said(["config", "--config-dir", "link/../new/made"])),
                   ?assertEqual({ok, []}, file:list_dir("real/new")),
                   ?assertMatch({0, _}, said(["config", "--config-dir", "link/../made"])),
                   ?assert(filelib:is_regular("made/ernest.conf")),
                   ?assertEqual({ok, []}, file:list_dir("real/made")),
                   ?assertEqual(refusal("config", "cfg: no such directory, which --config-dir"
                                                  " names"),
                                said(["config", "--config-dir", "link/../cfg", "--peer-dir",
                                      "other"])),
                   ?assertEqual(refusal("config", "peer: no configuration directory, which"
                                                  " --peer-dir names"),
                                said(["config", "--config-dir", "other", "--peer-dir",
                                      "link/../peer"]))
           end).

%% report §11, §12.5: `ern reload` and `ern stop` read the configuration
%% directory and its `ernest.pid` that `--config-dir` names as §11 resolves
%% it, and refuse one that names nothing so, naming it as resolved, though
%% the host would open a directory through the link before `..`
signal_given_paths_test() ->
    linked(fun() ->
                   ?assertEqual(0, ern_err(["config", "--config-dir", "cfg"])),
                   [?assertEqual(refusal(Job, "cfg/ernest.pid: no such file: no node runs from"
                                              " the directory"),
                                 said([Job, "--config-dir", "link/../cfg"]))
                    || Job <- ["reload", "stop"]]
           end),
    linked(fun() ->
                   ?assertEqual(0, ern_err(["config", "--config-dir", "real/cfg"])),
                   [?assertEqual(refusal(Job, "cfg: no such directory, which --config-dir names"),
                                 said([Job, "--config-dir", "link/../cfg"]))
                    || Job <- ["reload", "stop"]]
           end).

%% report §11, §11.5: a refusal names a path the command line gives as
%% resolved, from the working directory where it lies under it, `./x.erc`
%% and an absolute path under it among them, and absolute where it lies
%% outside, `../x.erc`
given_path_refusal_names_resolved_test() ->
    Dir = tmp(),
    ok = filelib:ensure_path(filename:join(Dir, "sub")),
    in_directory(filename:join(Dir, "sub"),
                 fun() ->
                     {ok, Cwd} = file:get_cwd(),
                     [?assertEqual(refusal("run", "x.erc: no such file"), said(["run", Given]))
                      || Given <- ["./x.erc", Cwd ++ "/x.erc", "x.erc/", "../sub/./x.erc"]],
                     ?assertEqual(refusal("run", filename:dirname(Cwd) ++ "/x.erc: no such file"),
                                  said(["run", "../x.erc"]))
                 end).

%% report §11: a `..` at the root names the root, in the resolver and in a
%% path a job is given
given_path_root_test() ->
    ?assertEqual("/x.ern", ern_build:absolute("/../x.ern")),
    ?assertEqual("/", ern_build:absolute("/..")),
    ?assertEqual("/x.ern", ern_build:absolute("/../../x.ern")),
    Dir = tmp(),
    write(Dir, "given.ern", hello()),
    ?assertEqual(0, ern_err(["build", "--source-root", Dir, Dir ++ "/given.ern"])),
    ?assertEqual({0, <<"hello, world\n">>}, said(["run", "/.." ++ Dir ++ "/given.erc"])).

%% report §11: a path whose last segment is a link is opened through the
%% link, a file's and a directory's, no `..` after the link asking how it
%% resolves. A regression test, written after the code
given_path_last_link_test() ->
    linked(fun() ->
                   given_tree("real"),
                   ok = file:make_symlink("real/given.erc", "given.erc"),
                   ok = file:make_symlink("real/src", "linked_src"),
                   ?assertEqual({0, <<"hello, world\n">>}, said(["run", "given.erc"])),
                   ?assertEqual({0, <<>>}, said(["build", "linked_src"])),
                   ?assert(filelib:is_regular("real/src/given_page.erc"))
           end).

%% report §11: an empty word names nothing, a job's argument among them, and
%% resolving it does not make it the working directory, which holds a
%% module. A regression test, written after the code; an option's empty
%% value is refused before it is resolved, which option_spellings_test holds
given_path_empty_test() ->
    linked(fun() ->
                   write(".", "given.ern", hello()),
                   [?assertEqual(refusal(Job, ": no such file"), said([Job, ""]))
                    || Job <- ["build", "doc", "format", "run", "test", "shell"]],
                   ?assertNot(filelib:is_file("given.erc"))
           end).

%%
%% Packages, report §11.9
%%

%% A manifest for the running `ern`'s release naming Entries, each a name
%% and a version, in their order.
manifest_of(Entries) ->
    manifest_for(element(1, running_release()), Entries).

%% A manifest for the release Ernest naming Entries.
manifest_for(Ernest, Entries) ->
    ["{\"ernest\": \"", Ernest, "\", \"packages\": [",
     lists:join(", ", [["{\"name\": \"", Name, "\", \"version\": \"", Version, "\"}"]
                       || {Name, Version} <- Entries]),
     "]}\n"].

%% Report §11.7: the running `ern`'s release, the three numbers of its
%% version text, and the text whole.
running_release() ->
    Text = ern_release:version_text(),
    {lists:takewhile(fun(Char) -> Char =/= $- andalso Char =/= $+ end, Text), Text}.

%% The release after the running `ern`'s, which the running `ern` is not of.
later_release() ->
    {Major, Minor, _} = ern_release:release(element(1, running_release())),
    lists:flatten(io_lib:format("~B.~B.0", [Major, Minor + 1])).

%% Under the working directory, the named package Name of their form: its
%% manifest naming Entries, its `VERSION` saying Version, and its source,
%% the module of its name, which is not compiled.
whole_package(Name, Version, Entries) ->
    Package = filename:join("lib", Name),
    write(Package, "package.conf", manifest_of(Entries)),
    write(Package, "VERSION", Version ++ "\n"),
    write(Package, "src/" ++ Name ++ ".ern",
          ["export fn hello() : String =\n    \"", Name, "\"\n"]),
    Package.

%% Every file and directory under the working directory, in order.
listing() ->
    lists:sort(filelib:wildcard("**")).

%% What a job said and its status where it refused what it was given with
%% Lines, a line each.
refused_lines(Job, Lines) ->
    {1, iolist_to_binary([["ern ", Job, ": ", Line, "\n"] || Line <- Lines])}.

%% Path's mode with the bit that lets others write it.
others_write(Path) ->
    {ok, #file_info{mode = Mode}} = file:read_file_info(Path),
    ok = file:change_mode(Path, Mode bor 8#002).

%% Under the root package Root, the named package Name at Version: its
%% manifest, which names no package, its `VERSION`, its source, the module of
%% its name, whose `hello()` gives Text, compiled into its build by a job
%% started in the package, and its ebin.
named_package(Root, Name, Version, Text) ->
    Package = filename:join([Root, "lib", Name]),
    write(Package, "package.conf", manifest_of([])),
    write(Package, "VERSION", Version ++ "\n"),
    write(Package, "src/" ++ Name ++ ".ern",
          ["export fn hello() : String =\n    \"", Text, "\"\n"]),
    in_directory(Package,
                 fun() -> ?assertEqual(0, ern_err(["build", "--build-root", "build", "src"])) end),
    ok = filelib:ensure_path(filename:join(Package, "ebin")),
    Package.

%% report §11.9: a manifest that is not JSON, that gives a field it does
%% not know or one twice, that lacks a field it must give, that gives a
%% field a value not of its form, or that names one package in two
%% entries, is refused before the job does anything else: every fault, a
%% line each, after the manifest's name, in the order of where each stands,
%% an absent field's at the end of the object that lacks it, `ernest`'s
%% before `packages`' and `name`'s before `version`'s. A field given twice
%% keeps its first value. A url is held to its entry's name and version
%% only where both are of their form
package_manifest_form_test() ->
    in_directory(tmp(), fun package_manifest_form/0).

package_manifest_form() ->
    write(".", "given.ern", hello()),
    whole_package("epx", "0.2.1", []),
    Version = "three numbers joined by `.`, none written with a leading zero",
    Name = "words joined by `_`, each a lowercase letter, then lowercase letters and digits",
    Digest = lists:duplicate(64, $a),
    Cases =
        [{"{", ["is not JSON"]},
         {"{} {}", ["holds more than one JSON value"]},
         {"[]", ["the file is not a JSON object"]},
         {"{}", ["names no ernest", "names no packages"]},
         {"{\"packages\": [{\"name\": \"a\"}]}",
          ["the entry for a has no version", "names no ernest"]},
         {"{\"x\": 1, \"ernest\": \"0.11\", \"ernest\": \"1.0.0\"}",
          ["the file has the unknown field x", "ernest is not " ++ Version ++ ": \"0.11\"",
           "the file gives ernest twice", "names no packages"]},
         {"{\"ernest\": 11, \"packages\": {}, \"x\": null}",
          ["ernest is not a string", "packages is not a JSON array",
           "the file has the unknown field x"]},
         {"{\"ernest\": \"0.11.0\", \"packages\": [], \"packages\": 3}",
          ["the file gives packages twice"]},
         {"{\"ernest\": \"0.11.0\", \"packages\": [\n"
          "  3,\n"
          "  {\"version\": \"1.2\", \"name\": \"leaf\"},\n"
          "  {\"name\": \"Leaf\", \"version\": \"1.0.0\", \"color\": \"red\"},\n"
          "  {\"version\": \"1.0.0\"},\n"
          "  {\"name\": 7},\n"
          "  {\"name\": \"epx\", \"version\": \"0.2.1\","
          " \"url\": \"http://example.org/epx-0.2.1.tar.gz\", \"sha256\": \"ABC\"},\n"
          "  {\"name\": \"leaf\", \"version\": \"1.3.0\", \"version\": \"1.4.0\"},\n"
          "  {\"name\": \"mid\"},\n"
          "  {\"name\": \"codec\", \"version\": \"01.0.0\", \"url\": \"unread\", \"sha256\": 5},\n"
          "  {\"name\": \"base\", \"version\": \"1.0.0.1\","
          " \"url\": \"https://example.org/base-1.0.0.tar.gz\"},\n"
          "  {\"name\": \"zip\", \"version\": \"2.0.0\","
          " \"url\": \"https://example.org/zip/zip-2.0.1.tar.gz\", \"sha256\": \"" ++ Digest
          ++ "0\"}\n"
          "]}\n",
          ["an entry is not a JSON object",
           "the entry for leaf's version is not " ++ Version ++ ": \"1.2\"",
           "an entry's name is not " ++ Name ++ ": \"Leaf\"",
           "an entry has the unknown field color",
           "an entry has no name",
           "an entry's name is not a string",
           "an entry has no version",
           "the entry for epx's url is not an https URL whose path's last segment is"
           " epx-0.2.1.tar.gz: \"http://example.org/epx-0.2.1.tar.gz\"",
           "the entry for epx's sha256 is not 64 hexadecimal digits, their letters lowercase:"
           " \"ABC\"",
           "the entry for leaf gives version twice",
           "two entries name leaf",
           "the entry for mid has no version",
           "the entry for codec's version is not " ++ Version ++ ": \"01.0.0\"",
           "the entry for codec's sha256 is not a string",
           "the entry for base's version is not " ++ Version ++ ": \"1.0.0.1\"",
           "the entry for zip's url is not an https URL whose path's last segment is"
           " zip-2.0.0.tar.gz: \"https://example.org/zip/zip-2.0.1.tar.gz\"",
           "the entry for zip's sha256 is not 64 hexadecimal digits, their letters lowercase: \""
           ++ Digest ++ "0\""]}],
    lists:foreach(fun({Text, Lines}) ->
                      write(".", "package.conf", Text),
                      ?assertEqual(refused_lines("build", ["package.conf: " ++ Line
                                                           || Line <- Lines]),
                                   said(["build", "given.ern"]))
                  end, Cases),
    ?assertNot(filelib:is_file("given.erc")),
    %% a manifest of its form, a url and a digest among it
    write(".", "package.conf",
          "{\"packages\": [{\"sha256\": \"" ++ Digest ++ "\", \"name\": \"epx\","
          " \"url\": \"https://example.org/epx/epx-0.2.1.tar.gz\", \"version\": \"0.2.1\"}],"
          " \"ernest\": \"0.11.0\"}\n"),
    ?assertEqual({0, <<>>}, said(["build", "given.ern"])).

%% report §11.9: a directory holds a manifest where it holds the name
%% `package.conf`, whatever the name reaches. A manifest the job cannot read
%% is one fault of its form, and the other groups of refusals are said
%% after it: a name that reaches no regular file, a directory or a FIFO, is
%% refused before it is read, so that a FIFO no one writes ends the job with
%% the refusal; a link to nothing is refused as a path that names nothing
%% is; and a file the job cannot read with the host's reason. A job that
%% cannot tell whether the directory holds the name is refused with the
%% host's reason, and nothing else is said. The shell is given `--main`
%% with no file, which it refuses, so that it never starts where the
%% manifest is not read
package_unreadable_manifest_test() ->
    in_directory(tmp(),
                 fun() ->
                     write(".", "given.ern", hello()),
                     ok = file:make_dir("package.conf"),
                     ?assertEqual(refusal("build", "package.conf: is no regular file"),
                                  said(["build", "given.ern"])),
                     others_write("package.conf"),
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: is no regular file",
                                                 "package.conf: may be written by every user"]),
                                  said(["build", "given.ern"])),
                     ok = file:del_dir("package.conf"),
                     "" = os:cmd("mkfifo package.conf"),
                     ?assertEqual(refusal("run", "package.conf: is no regular file"),
                                  said(["run", "given.erc"])),
                     ok = file:delete("package.conf"),
                     ok = file:make_symlink("nothing", "package.conf"),
                     ?assertEqual(refusal("build", "package.conf: no such file"),
                                  said(["build", "given.ern"])),
                     ok = file:delete("package.conf"),
                     write(".", "package.conf", manifest_of([])),
                     ok = file:change_mode("package.conf", 8#000),
                     ?assertEqual(refusal("doc", "package.conf: permission denied"),
                                  said(["doc", "given.ern"])),
                     ?assertNot(filelib:is_file("given.erc"))
                 end),
    Dir = tmp(),
    in_directory(Dir,
                 fun() ->
                     ok = file:change_mode(Dir, 8#600),
                     try
                         ?assertEqual(refusal("shell", "package.conf: permission denied"),
                                      said(["shell", "--main", "Given.none"]))
                     after
                         ok = file:change_mode(Dir, 8#755)
                     end
                 end).

%% report §11.9, §11.2: a job that reads the manifest refuses it, the root
%% package's directory, its `lib`, and a named package's directory, `src`,
%% `build` and `ebin`, where every user may write it, by its mode, or by the
%% mode of the directory that holds what a link reaches; every path at
%% fault said, the root package's first and then each named package's, in
%% the manifest's order, the root package's directory written `.`. Nothing
%% under those directories is tested, and a named package whose entry is
%% not of its form has no path tested. Not covered: a package another user
%% owns, which a test run by one user cannot make
package_paths_at_fault_test() ->
    Elsewhere = tmp(),
    ok = filelib:ensure_path(filename:join(Elsewhere, "open")),
    in_directory(filename:join(Elsewhere, "open"),
                 fun() -> ok = file:rename(whole_package("leaf", "1.3.0", []), "leaf") end),
    others_write(filename:join(Elsewhere, "open")),
    in_directory(tmp(),
                 fun() ->
                     write(".", "given.ern", hello()),
                     write(".", "package.conf", manifest_of([{"epx", "0.2.1"}, {"leaf", "1.3.0"}])),
                     [ok = filelib:ensure_path("lib/epx/" ++ Sub)
                      || Sub <- ["src", "build", "ebin"]],
                     write(".", "lib/epx/src/epx.ern", hello()),
                     write(".", "lib/epx/VERSION", "0.2.1\n"),
                     write(".", "lib/epx/package.conf", manifest_of([])),
                     ok = file:make_symlink(filename:join(Elsewhere, "open/leaf"), "lib/leaf"),
                     Open = ["package.conf", ".", "lib", "lib/epx", "lib/epx/src", "lib/epx/build",
                             "lib/epx/ebin"],
                     [others_write(Path) || Path <- Open ++ ["lib/epx/src/epx.ern",
                                                             "lib/epx/VERSION"]],
                     ?assertEqual(refused_lines("build",
                                                [Path ++ ": may be written by every user"
                                                 || Path <- Open ++ ["lib/leaf"]]),
                                  said(["build", "given.ern"])),
                     ok = filelib:ensure_path("lib/bad"),
                     others_write("lib/bad"),
                     write(".", "package.conf", manifest_of([{"epx", "0.2.1"}, {"bad", "x"}])),
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: the entry for bad's version is not"
                                                 " three numbers joined by `.`, none written with a"
                                                 " leading zero: \"x\""
                                                 | [Path ++ ": may be written by every user"
                                                    || Path <- Open]]),
                                  said(["build", "given.ern"]))
                 end).

%% report §11.9, §4.2: an entry whose namespace is one §4.2 takes, the
%% prelude's, the standard library's or the toolchain's own, is refused, and
%% so is one whose namespace a library of the toolchain's own provides; a
%% prelude type without members takes no namespace
package_namespaces_test() ->
    in_directory(tmp(),
                 fun() ->
                     write(".", "given.ern", hello()),
                     Names = ["io", "json", "int", "ernest", "prelude", "down", "pixel_map"],
                     [whole_package(Name, "1.0.0", []) || Name <- Names],
                     write(".", "package.conf", manifest_of([{Name, "1.0.0"} || Name <- Names])),
                     Taken = ", which no package may take",
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: the entry for io names Io" ++ Taken,
                                                 "package.conf: the entry for json names Json,"
                                                 " which a library of the toolchain's own provides",
                                                 "package.conf: the entry for int names Int"
                                                 ++ Taken,
                                                 "package.conf: the entry for ernest names Ernest"
                                                 ++ Taken,
                                                 "package.conf: the entry for prelude names"
                                                 " Prelude" ++ Taken]),
                                  said(["build", "given.ern"])),
                     write(".", "package.conf", manifest_of([{"down", "1.0.0"},
                                                             {"pixel_map", "1.0.0"}])),
                     ?assertEqual({0, <<>>}, said(["build", "given.ern"]))
                 end).

%% report §11.9: a named package stands under the root package's `lib` at
%% its name, a directory or a link to one; one that is not there, or is a
%% file or a link to nothing, is refused, a line each in the manifest's
%% order
package_not_under_lib_test() ->
    Elsewhere = tmp(),
    in_directory(Elsewhere, fun() -> whole_package("linked", "1.0.0", []) end),
    in_directory(tmp(),
                 fun() ->
                     write(".", "given.ern", hello()),
                     write(".", "lib/leaf", "a file\n"),
                     ok = file:make_symlink("nothing", "lib/mid"),
                     ok = file:make_symlink(filename:join(Elsewhere, "lib/linked"), "lib/linked"),
                     write(".", "package.conf",
                           manifest_of([{"epx", "0.2.1"}, {"leaf", "1.2.0"}, {"linked", "1.0.0"},
                                        {"mid", "0.4.0"}])),
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: " ++ Package
                                                 ++ " is not under lib; ern unpack puts it there"
                                                 || Package <- ["epx 0.2.1", "leaf 1.2.0",
                                                                "mid 0.4.0"]]),
                                  said(["build", "given.ern"])),
                     write(".", "package.conf", manifest_of([{"linked", "1.0.0"}])),
                     ?assertEqual({0, <<>>}, said(["build", "given.ern"]))
                 end).

%% report §11.9: a job says its refusals in this order, each group whole:
%% the manifest's form, the paths at fault, the entries' namespaces, the
%% named packages not under `lib`, a path given under `lib`, and, in `ern
%% build`, the build's rules, of every entry of its form under `lib`, one
%% whose namespace is refused among them; `ern doc` holds no rule
package_refusal_order_test() ->
    in_directory(tmp(),
                 fun() ->
                     write(".", "package.conf",
                           ["{\"ernest\": \"", element(1, running_release()), "\", \"packages\":"
                            " [{\"name\": \"epx\", \"version\": \"0.2.1\"},"
                            " {\"name\": \"io\", \"version\": \"1.0.0\"},"
                            " {\"name\": \"leaf\", \"version\": \"1.2.0\"}], \"x\": 1}\n"]),
                     ok = filelib:ensure_path("lib/io"),
                     whole_package("leaf", "1.3.0", []),
                     others_write("package.conf"),
                     Before = ["package.conf: the file has the unknown field x",
                               "package.conf: may be written by every user",
                               "package.conf: the entry for io names Io, which no package may take",
                               "package.conf: epx 0.2.1 is not under lib; ern unpack puts it there",
                               "lib/leaf/src/leaf.ern is the package leaf's, which ern build"
                               " builds"],
                     ?assertEqual(refused_lines("build",
                                                Before
                                                ++ ["package.conf: lib/io holds no package.conf",
                                                    "package.conf: lib/io holds no VERSION",
                                                    "package.conf: the entry for leaf says 1.2.0,"
                                                    " and lib/leaf holds 1.3.0; remove it, and ern"
                                                    " unpack puts 1.2.0 there"]),
                                  said(["build", "lib/leaf/src/leaf.ern"])),
                     ?assertEqual(refused_lines("doc", Before),
                                  said(["doc", "lib/leaf/src/leaf.ern"]))
                 end).

%% report §11.9, §11.7, §11.2: `--package-dir dir` of `ern run`, `ern test`
%% and `ern shell` makes `dir` the root package, whose manifest the job
%% reads whatever path it is given, and no other: a refusal writes each
%% path of it as §11.5 writes a path, absolute outside the working
%% directory; a `dir` that holds no manifest is refused, and so are one
%% that names no directory and one that names a file. `--package-dir` is
%% not given with `--attach`, and `ern build` does not take it
package_dir_test() ->
    Chart = tmp(),
    write(Chart, "package.conf", manifest_of([{"epx", "0.2.1"}])),
    others_write(Chart),
    Empty = tmp(),
    Good = tmp(),
    write(Good, "package.conf", manifest_of([])),
    Outside = tmp(),
    write(Outside, "outside.ern", hello()),
    ?assertEqual(0, ern_err(["build", "--source-root", Outside, Outside ++ "/outside.ern"])),
    Jobs = [{"run", ["given.erc"]}, {"test", ["given.erc"]}, {"shell", ["--main", "Given.none"]}],
    in_directory(tmp(),
                 fun() ->
                     write(".", "given.ern", hello()),
                     ?assertEqual(0, ern_err(["build", "given.ern"])),
                     write(".", "package.conf", "{"),
                     write(".", "p", "a file\n"),
                     At = [Chart ++ ": may be written by every user",
                           Chart ++ "/package.conf: epx 0.2.1 is not under " ++ Chart
                           ++ "/lib; ern unpack puts it there"],
                     [?assertEqual(refused_lines(Job, At),
                                   said([Job, "--package-dir", Chart | Rest]))
                      || {Job, Rest} <- Jobs],
                     ?assertEqual(refused_lines("run", At),
                                  said(["run", "--package-dir", Chart, Outside ++ "/outside.erc"])),
                     [?assertEqual(refusal(Job, Empty ++ "/package.conf: no such file"),
                                   said([Job, "--package-dir", Empty | Rest]))
                      || {Job, Rest} <- Jobs],
                     ?assertEqual(refusal("run", "nonexist: no such directory, which --package-dir"
                                                 " names"),
                                  said(["run", "--package-dir", "nonexist", "given.erc"])),
                     ?assertEqual(refusal("run", "p: not a directory, which --package-dir names"),
                                  said(["run", "--package-dir", "p", "given.erc"])),
                     ?assertEqual({0, <<"hello, world\n">>},
                                  said(["run", "--package-dir", Good, "given.erc"])),
                     {1, Attached} = said(["shell", "--package-dir", Good, "--attach", "peer"]),
                     ?assertMatch(<<"ern shell: --package-dir is not given with --attach: the load"
                                    " path is the node's\n", _/binary>>, Attached),
                     {1, Built} = said(["build", "--package-dir", "x", "given.ern"]),
                     ?assertMatch(<<"ern build: --package-dir is not an option of ern build; ern"
                                    " run, ern test and ern shell take it\n", _/binary>>, Built)
                 end).

%% report §11.9: a job given a path reads the manifest only where the path,
%% resolved, begins with the working directory's segments, an absolute path
%% under it among them; no job looks for a manifest in a directory above
%% the one it is started in; a job given no path reads it; and an attached
%% shell reads none, refused here as it is without `--config-dir`
package_given_path_test() ->
    Outside = tmp(),
    write(Outside, "outside.ern", hello()),
    in_directory(tmp(),
                 fun() ->
                     {ok, Cwd} = file:get_cwd(),
                     write(".", "given.ern", hello()),
                     write(".", "sub/sub.ern", hello()),
                     write(".", "package.conf", "{"),
                     Refused = refusal("build", "package.conf: is not JSON"),
                     ?assertEqual(Refused, said(["build", "given.ern"])),
                     ?assertEqual(Refused, said(["build", Cwd ++ "/given.ern"])),
                     ?assertEqual(Refused, said(["build", "--source-root", Outside,
                                                 "sub/../given.ern"])),
                     ?assertEqual({0, <<>>}, said(["build", "--source-root", Outside,
                                                   Outside ++ "/outside.ern"])),
                     ?assertEqual({0, <<>>},
                                  said(["build", "--source-root", Outside,
                                        "../" ++ filename:basename(Outside) ++ "/outside.ern"])),
                     in_directory("sub",
                                  fun() -> ?assertEqual({0, <<>>}, said(["build", "sub.ern"])) end),
                     ?assertEqual(refusal("shell", "package.conf: is not JSON"),
                                  said(["shell", "--main", "Given.none"])),
                     {1, Attached} = said(["shell", "--attach", "peer"]),
                     ?assertMatch(<<"ern shell: --attach needs --config-dir", _/binary>>, Attached)
                 end).

%% report §11.9, §11.1, §11.2, Appendix E.28: the build of each named
%% package stands on the load path in the manifest's order, after the
%% directories the options add and before the toolchain's libraries, under
%% `ern build`, `ern doc`, `ern run` and `ern test`, and its `ebin` beside it
%% under `ern run` and `ern test` alone, where a `foreign fn` finds its
%% module; a build or an `ebin` that is not there adds nothing, and a
%% directory an option names too stands once, at the option's place. The
%% shell's and a bare node's load path are the same function's, and not
%% covered here
package_load_path_test_() ->
    {timeout, 60, fun package_load_path/0}.

package_load_path() ->
    in_directory(tmp(), fun package_load_path_in/0).

package_load_path_in() ->
    {ok, Cwd} = file:get_cwd(),
    In = fun(Path) -> filename:join(Cwd, Path) end,
    named_package(".", "lp_epx", "0.2.1", "epx"),
    compiled_erlang("lib/lp_epx/ebin", "ern_cli_package_native", "n/0", "n() -> 42."),
    named_package(".", "lp_leaf", "1.3.0", "leaf"),
    ok = file:del_dir("lib/lp_leaf/ebin"),
    whole_package("lp_none", "1.0.0", []),
    write(".", "package.conf", manifest_of([{"lp_epx", "0.2.1"}, {"lp_leaf", "1.3.0"},
                                            {"lp_none", "1.0.0"}])),
    write(".", "lp_main.ern",
          "foreign fn native() : Int = \"ern_cli_package_native:n/0\"\n\n"
          "export fn main() : Unit =\n"
          "    Io.println(LpEpx.hello() <> LpLeaf.hello() <> Int.toString(native()))\n"),
    write(".", "lp_checked.ern",
          "let found : Test.Case(Never) =\n"
          "    Test.Case(name = \"found\", run = fn() = Test.equal(LpLeaf.hello(), \"leaf\"))\n"),
    ?assertEqual({0, <<>>}, said(["build", "lp_main.ern"])),
    ?assertEqual({0, <<>>}, said(["build", "lp_checked.ern"])),
    Libraries = ern_tree:libraries(),
    ?assertEqual({0, <<"epxleaf42\n">>}, said(["run", "lp_main.erc"])),
    ?assertEqual([Cwd, In("lib/lp_epx/build"), In("lib/lp_epx/ebin"), In("lib/lp_leaf/build"),
                  In("lib/lp_none/build") | Libraries], ern_build:directories(ern_cli:load_path())),
    ?assertEqual({0, <<"found: passed\n">>}, said(["test", "lp_checked.erc"])),
    {0, Page} = said(["doc", "lp_main.ern"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module LpMain\n">>)),
    ?assertEqual({0, <<"epxleaf42\n">>},
                 said(["run", "--load-path", "lib/lp_leaf/build", "lp_main.erc"])),
    ?assertEqual([Cwd, In("lib/lp_leaf/build"), In("lib/lp_epx/build"), In("lib/lp_epx/ebin"),
                  In("lib/lp_none/build") | Libraries], ern_build:directories(ern_cli:load_path())),
    ?assertEqual({0, <<"epxleaf42\n">>}, said(["run", "--libs-dir", "lib", "lp_main.erc"])),
    ?assertEqual([Cwd, In("lib/lp_epx/ebin"), In("lib/lp_epx/build"), In("lib/lp_leaf/build"),
                  In("lib/lp_none/build") | Libraries], ern_build:directories(ern_cli:load_path())),
    %% the builds alone, where the job runs no code
    Packages = ern_package:packages(ern_package:read(".", "doc", [])),
    ?assertEqual([In("lib/lp_epx/build"), In("lib/lp_leaf/build"), In("lib/lp_none/build")
                  | Libraries],
                 ern_build:directories(ern_build:load_path([{named_package, Package}
                                                            || Package <- Packages]))).

%% report §11.9, §11.1, §11.2, §11.4: `--verbose` of `ern build`, after the
%% build root, and of `ern run`, `ern test` and `ern doc`, before anything
%% else, names the manifest read and each named package put on the load
%% path, with the version its `VERSION` holds, or `no version` where it is
%% not of its form or not there, and, where `lib/<name>` is a link, its
%% target taken from `lib` and written as §11.5 writes a path, absolute
%% outside the working directory
package_verbose_test_() ->
    {timeout, 60, fun package_verbose/0}.

package_verbose() ->
    Elsewhere = tmp(),
    named_package(Elsewhere, "vb_mid", "1.0.0", "mid"),
    in_directory(tmp(), fun() -> package_verbose_in(Elsewhere) end).

package_verbose_in(Elsewhere) ->
    named_package(".", "vb_epx", "0.2.1", "epx"),
    named_package(".", "vb_leaf", "1.3.0", "leaf"),
    ok = file:make_symlink(filename:join(Elsewhere, "lib/vb_mid"), "lib/vb_mid"),
    named_package("rel", "vb_rel", "2.0.0", "rel"),
    ok = file:make_symlink("../rel/lib/vb_rel", "lib/vb_rel"),
    write(".", "package.conf", manifest_of([{"vb_epx", "0.2.1"}, {"vb_leaf", "1.3.0"},
                                            {"vb_mid", "1.0.0"}, {"vb_rel", "2.0.0"}])),
    write(".", "vb_main.ern", "export fn main() : Unit =\n    Io.println(VbEpx.hello())\n"),
    Built = lines(["source root .", "build root .", "manifest package.conf",
                   "package vb_epx 0.2.1", "package vb_leaf 1.3.0",
                   "package vb_mid 1.0.0 at " ++ Elsewhere ++ "/lib/vb_mid",
                   "package vb_rel 2.0.0 at rel/lib/vb_rel"]),
    Prefixed = fun(Prefix, {0, Output}) ->
                   ?assertEqual(unicode:characters_to_binary(Prefix),
                                binary:part(Output, 0, min(byte_size(Output), length(Prefix))))
               end,
    Prefixed(Built, said(["build", "--verbose", "vb_main.ern"])),
    %% `ern build` refuses a `VERSION` not of its form, and the other jobs
    %% read no rule
    write(".", "lib/vb_leaf/VERSION", "1.3\n"),
    ok = file:delete("rel/lib/vb_rel/VERSION"),
    Said = lines(["manifest package.conf", "package vb_epx 0.2.1", "package vb_leaf no version",
                  "package vb_mid 1.0.0 at " ++ Elsewhere ++ "/lib/vb_mid",
                  "package vb_rel no version at rel/lib/vb_rel"]),
    Prefixed(Said, said(["run", "--verbose", "vb_main.erc"])),
    Prefixed(Said, said(["test", "--verbose", "vb_main.erc"])),
    Prefixed(Said, said(["doc", "--verbose", "vb_main.ern"])).

%% report §11.9, §11.1, §11.5: `--verbose` writes a link's target that is
%% not UTF-8 with each byte past ASCII as `\xHH`, and then as a path is
%% written, its `.` and `..` resolved. A regression test, written after the
%% code; not covered: a target that holds a control character
package_verbose_target_not_utf8_test() ->
    in_directory(tmp(), fun package_verbose_target_not_utf8/0).

package_verbose_target_not_utf8() ->
    ok = file:make_dir(<<"b", 16#FF>>),
    ok = file:make_dir(<<"b", 16#FF, "/vb_bytes">>),
    ok = file:write_file(<<"b", 16#FF, "/vb_bytes/package.conf">>, manifest_of([])),
    ok = file:write_file(<<"b", 16#FF, "/vb_bytes/VERSION">>, "1.0.0\n"),
    ok = file:make_dir("lib"),
    ok = file:make_symlink(<<"../b", 16#FF, "/vb_bytes">>, <<"lib/vb_bytes">>),
    write(".", "package.conf", manifest_of([{"vb_bytes", "1.0.0"}])),
    write(".", "vb_bytes_main.ern", "export fn main() : Unit =\n    Io.println(\"b\")\n"),
    {0, Said} = said(["build", "--verbose", "vb_bytes_main.ern"]),
    ?assertNotEqual(nomatch,
                    binary:match(Said, <<"\npackage vb_bytes 1.0.0 at b\\xFF/vb_bytes\n">>)).

%% report §11.9, §11.1, §11.4, §11.6, §11.2: in directory mode a directory
%% named `lib` that stands beside a `package.conf` is passed over by every
%% job that walks a directory: `ern build` compiles nothing under it and its
%% sweep removes nothing there, `ern doc` documents nothing under it and
%% removes no page there, `ern format` lays out nothing there, and `ern
%% test` runs no test there; a `lib` that stands beside no manifest is
%% walked. Not covered: a node's start, which reads every module of its load
%% path by the same walk
package_lib_passed_over_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_lib_passed_over/0) end}.

package_lib_passed_over() ->
    write(".", "top.ern", "export fn main() : Unit =\n    Io.println(\"top\")\n"),
    write(".", "lib/old.ern", "export fn one() : Int =\n    1\n"),
    write(".", "lib/checked.ern",
          "let counted : Test.Case(Never) =\n"
          "    Test.Case(name = \"counted\", run = fn() = Test.equal(1, 1))\n"),
    ?assertEqual({0, <<>>}, said(["build", "."])),
    ?assertEqual({0, <<>>}, said(["doc", "."])),
    ?assert(filelib:is_regular("lib/old.erc")),
    ?assert(filelib:is_regular("lib/old.md")),
    ok = file:delete("lib/old.ern"),
    write(".", "lib/broken.ern", "fn (\n"),
    write(".", "lib/loose.ern", "fn f(x) = x+1\n"),
    write(".", "sub/lib/inner.ern", "export fn two() : Int =\n    2\n"),
    write(".", "package.conf", manifest_of([])),
    ?assertEqual({0, <<>>}, said(["build", "."])),
    ?assert(filelib:is_regular("lib/old.erc")),
    ?assertNot(filelib:is_file("lib/broken.erc")),
    ?assert(filelib:is_regular("sub/lib/inner.erc")),
    ?assertEqual({0, <<>>}, said(["doc", "."])),
    ?assert(filelib:is_regular("lib/old.md")),
    ?assert(filelib:is_regular("sub/lib/inner.md")),
    ?assertEqual({0, <<>>}, said(["format", "--check", "."])),
    {0, Tested} = said(["test", "."]),
    ?assertEqual(nomatch, binary:match(Tested, <<"counted">>)).

%% Under the directory Dir, which names no manifest, the module Name, a file
%% of Dir's own, `name.ern` or `name/inner.ern`, compiled there from Text,
%% and its `.erc` copied to Destination: a module at a namespace that stands
%% elsewhere too.
compiled_elsewhere(Dir, Relative, Text, Destination) ->
    write(Dir, Relative, Text),
    in_directory(Dir, fun() -> ?assertEqual(0, ern_err(["build", Relative])) end),
    Compiled = filename:rootname(Relative) ++ ".erc",
    ok = filelib:ensure_dir(Destination),
    {ok, _} = file:copy(filename:join(Dir, Compiled), Destination),
    ok.

%% report §11.9, §4.2, §11.1, §11.2: a named package's namespace, and every
%% namespace under it, is found under that package's build alone, by `ern
%% build`, `ern doc`, `ern run` and `ern test`: a module at it under the
%% build root, which is also the loaded module's root, or under a
%% `--load-path` root is passed over; and the package's build provides no
%% other namespace, a module at another's path in it being no module
package_namespace_lookup_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_namespace_lookup/0) end}.

package_namespace_lookup() ->
    Elsewhere = tmp(),
    write(".", "lib/nl_leaf/src/nl_leaf/inner.ern", "export fn word() : String =\n    \"inner\"\n"),
    named_package(".", "nl_leaf", "1.0.0", "package"),
    compiled_elsewhere(Elsewhere, "nl_other.ern", "export fn word() : String =\n    \"other\"\n",
                       "lib/nl_leaf/build/nl_other.erc"),
    Decoy = filename:join(Elsewhere, "decoy"),
    compiled_elsewhere(Decoy, "nl_leaf.ern", "export fn hello() : Int =\n    7\n",
                       "nl_leaf.erc"),
    compiled_elsewhere(Decoy, "nl_leaf/inner.ern", "export fn word() : Int =\n    8\n",
                       filename:join(Decoy, "nl_leaf/inner.erc")),
    write(".", "package.conf", manifest_of([{"nl_leaf", "1.0.0"}])),
    write(".", "nl_main.ern",
          "export fn main() : Unit =\n    Io.println(NlLeaf.hello() <> NlLeaf.Inner.word())\n"),
    write(".", "nl_checked.ern",
          "let found : Test.Case(Never) =\n"
          "    Test.Case(name = \"found\",\n"
          "              run = fn() = Test.equal(NlLeaf.hello(), \"package\"))\n"),
    write(".", "nl_other_user.ern", "export fn main() : Unit =\n    Io.println(NlOther.word())\n"),
    ?assertEqual({0, <<>>}, said(["build", "--load-path", Decoy, "nl_main.ern"])),
    ?assertEqual({0, <<>>}, said(["build", "--load-path", Decoy, "nl_checked.ern"])),
    ?assertEqual({0, <<"packageinner\n">>}, said(["run", "--load-path", Decoy, "nl_main.erc"])),
    {0, Read} = said(["run", "--verbose", "--load-path", Decoy, "nl_main.erc"]),
    ?assertNotEqual(nomatch, binary:match(Read, <<"read NlLeaf from lib/nl_leaf/build/nl_leaf.erc\n"
                                                  "read NlLeaf.Inner from"
                                                  " lib/nl_leaf/build/nl_leaf/inner.erc\n">>)),
    ?assertEqual({0, <<"found: passed\n">>},
                 said(["test", "--load-path", Decoy, "nl_checked.erc"])),
    {0, Page} = said(["doc", "--load-path", Decoy, "nl_main.ern"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module NlMain\n">>)),
    {1, Unfound} = said(["build", "nl_other_user.ern"]),
    ?assertMatch({_, _}, binary:match(Unfound, <<"NlOther">>)),
    ?assertNot(filelib:is_file("nl_other_user.erc")).

%% report §11.9, §11.1: a module outside the named packages, its source
%% under no named package's `src`, at a named package's namespace or under
%% it, is refused by `ern build` and `ern doc`, which fail that file alone,
%% as a module that does not compile fails: a module that uses the
%% namespace is compiled against the package's build
package_namespace_refused_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_namespace_refused/0) end}.

package_namespace_refused() ->
    named_package(".", "nr_leaf", "1.0.0", "package"),
    write(".", "package.conf", manifest_of([{"nr_leaf", "1.0.0"}])),
    write(".", "src/nr_leaf.ern", "export fn hello() : String =\n    \"source\"\n"),
    write(".", "src/nr_leaf/util.ern", "export fn one() : Int =\n    1\n"),
    write(".", "src/nr_main.ern", "export fn main() : Unit =\n    Io.println(NrLeaf.hello())\n"),
    %% in the order the build walks the tree, a directory before the file
    %% of its name
    Refused = fun(Job) ->
                  refused_lines(Job, ["src/nr_leaf/util.ern: NrLeaf.Util is the package"
                                      " nr_leaf's, which package.conf names",
                                      "src/nr_leaf.ern: NrLeaf is the package nr_leaf's, which"
                                      " package.conf names"])
              end,
    Tree = ["--source-root", "src", "--build-root", "build", "src"],
    ?assertEqual(Refused("build"), said(["build" | Tree])),
    ?assert(filelib:is_regular("build/nr_main.erc")),
    ?assertNot(filelib:is_file("build/nr_leaf.erc")),
    ?assertNot(filelib:is_file("build/nr_leaf/util.erc")),
    ?assertEqual({0, <<"package\n">>}, said(["run", "build/nr_main.erc"])),
    ?assertEqual(Refused("doc"), said(["doc" | Tree])),
    ?assertNot(filelib:is_file("build/nr_leaf.md")),
    ?assertEqual(refusal("build", "src/nr_leaf.ern: NrLeaf is the package nr_leaf's, which"
                                  " package.conf names"),
                 said(["build", "--source-root", "src", "src/nr_leaf.ern"])),
    ?assertEqual(refusal("doc", "src/nr_leaf.ern: NrLeaf is the package nr_leaf's, which"
                                " package.conf names"),
                 said(["doc", "--source-root", "src", "src/nr_leaf.ern"])).

%% report §11.9, §11.2: `ern run` and `ern test` refuse a file given at a
%% named package's namespace or under it, outside that package's build,
%% before anything runs, and run one given in it
package_namespace_given_file_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_namespace_given_file/0) end}.

package_namespace_given_file() ->
    write(".", "lib/ng_epx/src/ng_epx/tool.ern",
          "export fn main() : Unit =\n    Io.println(NgEpx.hello())\n"),
    named_package(".", "ng_epx", "0.2.1", "epx"),
    write(".", "package.conf", manifest_of([{"ng_epx", "0.2.1"}])),
    ok = filelib:ensure_path("build/ng_epx"),
    {ok, _} = file:copy("lib/ng_epx/build/ng_epx.erc", "build/ng_epx.erc"),
    {ok, _} = file:copy("lib/ng_epx/build/ng_epx/tool.erc", "build/ng_epx/tool.erc"),
    ?assertEqual({0, <<"epx\n">>}, said(["run", "lib/ng_epx/build/ng_epx/tool.erc"])),
    [?assertEqual(refusal(Job, "build/ng_epx/tool.erc holds NgEpx.Tool, the package ng_epx's,"
                               " which package.conf names"),
                  said([Job, "build/ng_epx/tool.erc"]))
     || Job <- ["run", "test"]],
    [?assertEqual(refusal(Job, "build/ng_epx.erc holds NgEpx, the package ng_epx's, which"
                               " package.conf names"),
                  said([Job, "build/ng_epx.erc"]))
     || Job <- ["run", "test"]].

%% report §11.9, §11.2: `ern run`, `ern test`, and `ern shell` given a file,
%% refuse a compiled module given in a named package's build at another
%% namespace than the package's, at the build's top and below it, before
%% anything runs; the shell itself is not started
package_build_other_namespace_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_other_namespace/0) end}.

package_build_other_namespace() ->
    named_package(".", "po_epx", "0.2.1", "epx"),
    write(".", "package.conf", manifest_of([{"po_epx", "0.2.1"}])),
    Elsewhere = tmp(),
    Main = "export fn main() : Unit =\n    Io.println(\"stray\")\n",
    compiled_elsewhere(Elsewhere, "po_tool.ern", Main, "lib/po_epx/build/po_tool.erc"),
    compiled_elsewhere(Elsewhere, "po_deep/tool.ern", Main, "lib/po_epx/build/po_deep/tool.erc"),
    [?assertEqual(refusal(Job, File ++ " holds " ++ Name ++ ", and the package po_epx provides"
                               " PoEpx and what stands under it"),
                  said([Job, File]))
     || Job <- ["run", "test", "shell"],
        {File, Name} <- [{"lib/po_epx/build/po_tool.erc", "PoTool"},
                         {"lib/po_epx/build/po_deep/tool.erc", "PoDeep.Tool"}]].

%% report §11.9, §11.2: `ern test` of a directory that holds a compiled
%% module at a named package's namespace, outside that package's build,
%% ends on that file's refusal, as a module that cannot be loaded ends it:
%% the module after it is not tested. A regression test, written after the
%% code
package_tested_directory_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_tested_directory/0) end}.

package_tested_directory() ->
    named_package(".", "pt_epx", "0.2.1", "epx"),
    write(".", "package.conf", manifest_of([{"pt_epx", "0.2.1"}])),
    ok = filelib:ensure_path("tested"),
    {ok, _} = file:copy("lib/pt_epx/build/pt_epx.erc", "tested/pt_epx.erc"),
    Elsewhere = tmp(),
    compiled_elsewhere(Elsewhere, "zz_checked.ern",
                       "let found : Test.Case(Never) =\n"
                       "    Test.Case(name = \"found\", run = fn() = Test.Passed)\n",
                       "tested/zz_checked.erc"),
    ?assertEqual({0, <<"found: passed\n">>}, said(["test", "tested/zz_checked.erc"])),
    ?assertEqual(refusal("test", "tested/pt_epx.erc holds PtEpx, the package pt_epx's, which"
                                 " package.conf names"),
                 said(["test", "tested"])).

%% report §11.9: the trial's table of a package that loads a package, in the
%% report's words: `app` names `mid` 1.0.0 and `leaf` 1.2.0, `mid` names
%% `leaf` 1.1.0, and the build holds them to each other before it compiles.
%% Where the change leaves the entry for `leaf` saying another version than
%% `lib/leaf` holds, that rule is broken too. A module of `app` at `leaf`'s
%% namespace fails that file alone
package_build_trial_test() ->
    in_directory(tmp(), fun package_build_trial/0).

package_build_trial() ->
    {_, Running} = running_release(),
    Later = later_release(),
    App = fun(Entries) -> write(".", "package.conf", manifest_of(Entries)) end,
    Whole = [{"mid", "1.0.0"}, {"leaf", "1.2.0"}],
    whole_package("mid", "1.0.0", [{"leaf", "1.1.0"}]),
    whole_package("leaf", "1.2.0", []),
    App(Whole),
    write(".", "src/app.ern", "export fn main() : Unit =\n    Io.println(\"app\")\n"),
    Built = fun() -> said(["build", "src"]) end,
    ?assertEqual({0, <<>>}, Built()),
    App([{"mid", "1.0.0"}]),
    ?assertEqual(refusal("build", "package.conf: mid 1.0.0 needs leaf from 1.1.0, and no entry"
                                  " names leaf"),
                 Built()),
    App([{"mid", "1.0.0"}, {"leaf", "1.0.0"}]),
    ?assertEqual(refused_lines("build", ["package.conf: mid 1.0.0 needs leaf from 1.1.0, and the"
                                         " entry for leaf says 1.0.0",
                                         "package.conf: the entry for leaf says 1.0.0, and"
                                         " lib/leaf holds 1.2.0; remove it, and ern unpack puts"
                                         " 1.0.0 there"]),
                 Built()),
    App(Whole),
    write(".", "lib/leaf/VERSION", "1.3.0\n"),
    ?assertEqual(refusal("build", "package.conf: the entry for leaf says 1.2.0, and lib/leaf"
                                  " holds 1.3.0; remove it, and ern unpack puts 1.2.0 there"),
                 Built()),
    write(".", "lib/leaf/VERSION", "1.2.0\n"),
    App(Whole ++ [{"leaf", "1.2.0"}]),
    ?assertEqual(refusal("build", "package.conf: two entries name leaf"), Built()),
    App(Whole),
    write(".", "lib/leaf/package.conf", manifest_of([{"mid", "1.0.0"}])),
    ?assertEqual(refusal("build", "package.conf: a cycle among the packages: mid, leaf"), Built()),
    write(".", "lib/leaf/package.conf", manifest_of([])),
    write(".", "lib/leaf/src/util.ern", "export fn one() : Int =\n    1\n"),
    ?assertEqual(refusal("build", "lib/leaf/src/util.ern: the package leaf provides Leaf and what"
                                  " stands under it"),
                 Built()),
    ok = file:delete("lib/leaf/src/util.ern"),
    write(".", "src/leaf.ern", "export fn hello() : String =\n    \"app\"\n"),
    ?assertEqual(refusal("build", "src/leaf.ern: Leaf is the package leaf's, which package.conf"
                                  " names"),
                 Built()),
    ?assert(filelib:is_regular("build/app.erc")),
    ok = file:delete("src/leaf.ern"),
    write(".", "lib/leaf/package.conf", manifest_for(Later, [])),
    ?assertEqual(refusal("build", "package.conf: leaf 1.2.0 is written for ern from " ++ Later
                                  ++ ", and this is ern " ++ Running),
                 Built()).

%% report §11.9: `ern build` says every rule broken before anything
%% compiles, a line each: the running `ern`'s line first and each cycle's
%% last, and between them each entry's lines in the order of the root
%% package's entries, its manifest's form first, then the rules in the
%% report's order, a module's by its path, and one entry's in the order of
%% its manifest's list. A manifest with a fault of its form is held to the
%% rules in what is of its form. Nothing is compiled and no file is written
package_build_rules_said_test() ->
    in_directory(tmp(), fun package_build_rules_said/0).

package_build_rules_said() ->
    {_, Running} = running_release(),
    Later = later_release(),
    write(".", "package.conf",
          manifest_for(Later, [{"ra", "1.0.0"}, {"rb", "2.0.0"}, {"rc", "1.0.0"}, {"rd", "1.0.0"},
                               {"re", "1.0.0"}])),
    whole_package("ra", "1.1.0", []),
    write(".", "lib/ra/package.conf",
          ["{\"ernest\": \"", Later, "\", \"packages\": [{\"name\": \"zz\", \"version\":"
           " \"1.0.0\"}, {\"name\": \"rb\", \"version\": \"3.0.0\"}], \"x\": 1}\n"]),
    Module = "export fn one() : Int =\n    1\n",
    [write(".", "lib/ra/src/" ++ File, Module)
     || File <- ["stray.ern", "ra/inner.ern", "other/deep.ern"]],
    ok = filelib:ensure_path("lib/rb"),
    whole_package("rc", "1.0.0", [{"rd", "1.0.0"}]),
    whole_package("rd", "1.0.0", [{"rc", "1.0.0"}]),
    whole_package("re", "1.0.0", [{"re", "1.0.0"}]),
    write(".", "src/main.ern", hello()),
    Before = listing(),
    Provides = ": the package ra provides Ra and what stands under it",
    ?assertEqual(refused_lines("build",
                               ["package.conf: written for ern from " ++ Later ++ ", and this is"
                                " ern " ++ Running,
                                "lib/ra/package.conf: the file has the unknown field x",
                                "package.conf: the entry for ra says 1.0.0, and lib/ra holds 1.1.0;"
                                " remove it, and ern unpack puts 1.0.0 there",
                                "package.conf: ra 1.0.0 is written for ern from " ++ Later
                                ++ ", and this is ern " ++ Running,
                                "package.conf: ra 1.0.0 needs zz from 1.0.0, and no entry names zz",
                                "package.conf: ra 1.0.0 needs rb from 3.0.0, and the entry for rb"
                                " says 2.0.0",
                                "lib/ra/src/other/deep.ern" ++ Provides,
                                "lib/ra/src/stray.ern" ++ Provides,
                                "package.conf: lib/rb holds no package.conf",
                                "package.conf: lib/rb holds no VERSION",
                                "package.conf: a cycle among the packages: rc, rd",
                                "package.conf: a cycle among the packages: re"]),
                 said(["build", "src"])),
    ?assertEqual(Before, listing()).

%% report §11.9: where a named package's directory is a link, the version
%% line ends `; ern unpack puts 1.2.0 there`
package_build_linked_version_test() ->
    Elsewhere = tmp(),
    in_directory(Elsewhere, fun() -> whole_package("leaf", "1.3.0", []) end),
    in_directory(tmp(),
                 fun() ->
                     ok = file:make_dir("lib"),
                     ok = file:make_symlink(filename:join(Elsewhere, "lib/leaf"), "lib/leaf"),
                     write(".", "package.conf", manifest_of([{"leaf", "1.2.0"}])),
                     write(".", "main.ern", hello()),
                     ?assertEqual(refusal("build", "package.conf: the entry for leaf says 1.2.0,"
                                                   " and lib/leaf holds 1.3.0; ern unpack puts"
                                                   " 1.2.0 there"),
                                  said(["build", "main.ern"]))
                 end).

%% report §11.9: an entry whose package no module uses is accepted; a named
%% package with no `src` breaks no rule, and no source of a named package is
%% parsed for the rules: a source that does not parse fails where `ern build`
%% builds its package, after the rules are held, and the root package's
%% module compiles
package_build_unused_entry_test() ->
    in_directory(tmp(),
                 fun() ->
                     whole_package("un_leaf", "1.0.0", []),
                     write(".", "lib/un_leaf/src/un_leaf/broken.ern", "fn (\n"),
                     whole_package("un_bare", "2.0.0", []),
                     ok = file:delete("lib/un_bare/src/un_bare.ern"),
                     ok = file:del_dir("lib/un_bare/src"),
                     write(".", "package.conf", manifest_of([{"un_leaf", "1.0.0"},
                                                             {"un_bare", "2.0.0"}])),
                     write(".", "main.ern", hello()),
                     ?assertEqual({1, <<"lib/un_leaf/src/un_leaf/broken.ern:1:4: expected a name"
                                        " instead of `(`\n1 | fn (\n  |    ^\n\n">>},
                                  said(["build", "main.ern"])),
                     ?assert(filelib:is_regular("lib/un_leaf/build/un_leaf.erc")),
                     ?assert(filelib:is_regular("main.erc"))
                 end).

%% report §11.9: a named package holds a manifest of its form, held as the
%% root package's is, each fault naming the named package's file; one that
%% holds no name `package.conf` holds no manifest. A FIFO at the name ends
%% the job with its refusal. The rules are held of what is of its form
package_build_named_manifest_test() ->
    in_directory(tmp(), fun package_build_named_manifest/0).

package_build_named_manifest() ->
    whole_package("leaf", "1.2.0", []),
    write(".", "package.conf", manifest_of([{"leaf", "1.2.0"}])),
    write(".", "main.ern", hello()),
    Refused = fun(Line) -> ?assertEqual(refusal("build", Line), said(["build", "main.ern"])) end,
    Manifest = "lib/leaf/package.conf",
    ok = file:delete(Manifest),
    Refused("package.conf: lib/leaf holds no package.conf"),
    ok = file:make_dir(Manifest),
    Refused("lib/leaf/package.conf: is no regular file"),
    ok = file:del_dir(Manifest),
    "" = os:cmd("mkfifo " ++ Manifest),
    Refused("lib/leaf/package.conf: is no regular file"),
    ok = file:delete(Manifest),
    ok = file:make_symlink("nothing", Manifest),
    Refused("lib/leaf/package.conf: no such file"),
    ok = file:delete(Manifest),
    write(".", Manifest, "{"),
    Refused("lib/leaf/package.conf: is not JSON"),
    write(".", Manifest, manifest_of([])),
    ok = file:change_mode(Manifest, 8#000),
    Refused("lib/leaf/package.conf: permission denied"),
    ok = file:change_mode(Manifest, 8#644),
    write(".", Manifest, manifest_of([{"x", "1.0.0"}, {"x", "1.0.0"}])),
    ?assertEqual(refused_lines("build", ["lib/leaf/package.conf: two entries name x",
                                         "package.conf: leaf 1.2.0 needs x from 1.0.0, and no"
                                         " entry names x"]),
                 said(["build", "main.ern"])).

%% report §11.9: a named package holds a `VERSION` of its form, one line
%% that holds a version and ends in a line feed; one that is not, a
%% directory, a FIFO, a file that cannot be read or a link to nothing among
%% them, is refused, and none is compared with its entry's version. A FIFO
%% ends `ern build` with its refusal, and `ern run --verbose`, which says the
%% package has no version, runs
package_build_version_form_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_version_form/0) end}.

package_build_version_form() ->
    named_package(".", "vf_leaf", "1.2.0", "leaf"),
    write(".", "package.conf", manifest_of([{"vf_leaf", "1.2.0"}])),
    write(".", "vf_main.ern", "export fn main() : Unit =\n    Io.println(VfLeaf.hello())\n"),
    ?assertEqual({0, <<>>}, said(["build", "vf_main.ern"])),
    Version = "lib/vf_leaf/VERSION",
    Refused = fun(Line) ->
                  ?assertEqual(refusal("build", "package.conf: " ++ Line),
                               said(["build", "vf_main.ern"]))
              end,
    Not = "lib/vf_leaf/VERSION is not one line that holds a version",
    [begin write(".", Version, Text), Refused(Not) end
     || Text <- ["1.2\n", "1.2.0", "1.2.0\n\n", "1.2.0\r\n", "v1.2.0\n", ""]],
    ok = file:change_mode(Version, 8#000),
    Refused(Not),
    ok = file:delete(Version),
    Refused("lib/vf_leaf holds no VERSION"),
    ok = file:make_dir(Version),
    Refused(Not),
    ok = file:del_dir(Version),
    ok = file:make_symlink("nothing", Version),
    Refused(Not),
    ok = file:delete(Version),
    "" = os:cmd("mkfifo " ++ Version),
    Refused(Not),
    {0, Said} = said(["run", "--verbose", "vf_main.erc"]),
    ?assertNotEqual(nomatch, binary:match(Said, <<"\npackage vf_leaf no version\n">>)),
    ?assertNotEqual(nomatch, binary:match(Said, <<"\nleaf\n">>)).

%% report §11.9: a named package's entries are held to the root package's
%% by name alone: an entry whose namespace no package may take is not
%% refused for it, and the root package's manifest holds no entry of its
%% name. A named package not under `lib` has its one line and no rule's
package_build_named_entries_test() ->
    in_directory(tmp(),
                 fun() ->
                     whole_package("leaf", "1.2.0", [{"io", "1.0.0"}]),
                     write(".", "package.conf", manifest_of([{"leaf", "1.2.0"},
                                                             {"gone", "1.0.0"}])),
                     write(".", "main.ern", hello()),
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: gone 1.0.0 is not under lib; ern"
                                                 " unpack puts it there",
                                                 "package.conf: leaf 1.2.0 needs io from 1.0.0, and"
                                                 " no entry names io"]),
                                  said(["build", "main.ern"]))
                 end).

%% report §11.9: the named packages hold no cycle, each with the packages
%% its manifest names: a line for each cycle, a package that names itself
%% among them, its packages in the order of the root package's entries,
%% the lines in the order of their first packages; a package outside every
%% cycle, and one not under `lib`, is in none
package_build_cycles_test() ->
    in_directory(tmp(),
                 fun() ->
                     whole_package("cx", "1.0.0", [{"cx", "1.0.0"}]),
                     whole_package("cp", "1.0.0", [{"cq", "1.0.0"}]),
                     whole_package("cq", "1.0.0", [{"cr", "1.0.0"}]),
                     whole_package("cr", "1.0.0", [{"cz", "1.0.0"}, {"cp", "1.0.0"}]),
                     whole_package("cs", "1.0.0", [{"cp", "1.0.0"}]),
                     write(".", "package.conf",
                           manifest_of([{Name, "1.0.0"}
                                        || Name <- ["cs", "cq", "cx", "cp", "cr", "cz"]])),
                     write(".", "main.ern", hello()),
                     ?assertEqual(refused_lines("build",
                                                ["package.conf: cz 1.0.0 is not under lib; ern"
                                                 " unpack puts it there",
                                                 "package.conf: a cycle among the packages: cq, cp,"
                                                 " cr",
                                                 "package.conf: a cycle among the packages: cx"]),
                                  said(["build", "main.ern"]))
                 end).

%% report §11.9, §11: `ern build` refuses a path it is given that is the
%% root package's `lib`, a named package's directory or a path under one,
%% and `ern doc` a source or a directory given there, each compared as it
%% is resolved, by its segments: a path under `lib` and under no named
%% package's directory, or under an entry's that is not of its form, has
%% the text of `lib`; a path given there that names nothing is refused so,
%% the root package being read first. `ern doc` reads a named package's
%% `.erc`
package_build_given_under_lib_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_given_under_lib/0) end}.

package_build_given_under_lib() ->
    {ok, Cwd} = file:get_cwd(),
    named_package(".", "gl_epx", "0.2.1", "epx"),
    write(".", "lib/stray/x.ern", hello()),
    write(".", "package.conf", manifest_of([{"gl_epx", "0.2.1"}, {"bad", "x"}])),
    Bad = "package.conf: the entry for bad's version is not three numbers joined by `.`, none"
        " written with a leading zero: \"x\"",
    Lib = "lib holds the named packages, which ern build builds",
    Epx = fun(Path) -> Path ++ " is the package gl_epx's, which ern build builds" end,
    Sources = [{"lib", Lib}, {"lib/gl_epx", Epx("lib/gl_epx")},
               {"lib/gl_epx/src", Epx("lib/gl_epx/src")},
               {"lib/gl_epx/src/gl_epx.ern", Epx("lib/gl_epx/src/gl_epx.ern")},
               {"lib/gl_epx/src/none.ern", Epx("lib/gl_epx/src/none.ern")},
               {Cwd ++ "/lib/gl_epx/src/gl_epx.ern", Epx("lib/gl_epx/src/gl_epx.ern")},
               {"src/../lib/gl_epx/", Epx("lib/gl_epx")},
               {"lib/stray/x.ern", Lib}, {"lib/none.ern", Lib}, {"lib/bad/x.ern", Lib}],
    [?assertEqual(refused_lines(Job, [Bad, Line]), said([Job, Path]))
     || Job <- ["build", "doc"], {Path, Line} <- Sources],
    ?assertEqual(refused_lines("build", [Bad, Epx("lib/gl_epx/build/gl_epx.erc")]),
                 said(["build", "lib/gl_epx/build/gl_epx.erc"])),
    write(".", "package.conf", manifest_of([{"gl_epx", "0.2.1"}])),
    {0, Page} = said(["doc", "lib/gl_epx/build/gl_epx.erc"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module GlEpx\n">>)),
    ?assertNot(filelib:is_file("lib/stray/x.erc")).

%% report §11.9: `ern build` alone reads the named packages' manifests:
%% `ern run`, `ern test` and `ern doc` in a root package whose named
%% package breaks the build's rules do their work
package_rules_build_alone_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_rules_build_alone/0) end}.

package_rules_build_alone() ->
    named_package(".", "ba_leaf", "1.0.0", "leaf"),
    write(".", "package.conf", manifest_of([{"ba_leaf", "1.0.0"}])),
    write(".", "ba_main.ern", "export fn main() : Unit =\n    Io.println(BaLeaf.hello())\n"),
    write(".", "ba_checked.ern",
          "let found : Test.Case(Never) =\n"
          "    Test.Case(name = \"found\", run = fn() = Test.equal(BaLeaf.hello(), \"leaf\"))\n"),
    ?assertEqual({0, <<>>}, said(["build", "ba_main.ern"])),
    ?assertEqual({0, <<>>}, said(["build", "ba_checked.ern"])),
    ok = file:delete("lib/ba_leaf/VERSION"),
    write(".", "lib/ba_leaf/package.conf", manifest_for(later_release(), [{"gone", "1.0.0"}])),
    {1, _} = said(["build", "ba_main.ern"]),
    ?assertEqual({0, <<"leaf\n">>}, said(["run", "ba_main.erc"])),
    ?assertEqual({0, <<"found: passed\n">>}, said(["test", "ba_checked.erc"])),
    {0, Page} = said(["doc", "ba_main.ern"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module BaMain\n">>)).

%% Under the working directory, the named package Name at 1.0.0 of its
%% form, its manifest naming the packages Used, each at 1.0.0, and its
%% sources, each a path under its `src` and its text.
source_package(Name, Used, Sources) ->
    Package = filename:join("lib", Name),
    write(Package, "package.conf", manifest_of([{Used1, "1.0.0"} || Used1 <- Used])),
    write(Package, "VERSION", "1.0.0\n"),
    [write(Package, filename:join("src", Relative), Text) || {Relative, Text} <- Sources],
    Package.

%% A root package's manifest naming the packages Names, each at 1.0.0.
root_manifest(Names) ->
    write(".", "package.conf", manifest_of([{Name, "1.0.0"} || Name <- Names])).

%% The lines of what `--verbose` said that name a module compiled.
compiled_lines(Said) ->
    [Line || Line <- string:split(binary_to_list(Said), "\n", all),
             lists:prefix("compiled ", Line)].

%% A file's or a directory's mode, its permission bits alone.
mode_of(Path) ->
    {ok, #file_info{mode = Mode}} = file:read_file_info(Path),
    Mode band 8#777.

%% report §11.1, §11.9, §11.4: in a root package, a path under its `src`
%% takes that `src` as its source root where `--source-root` is not given,
%% and the build root is the package's `build` where the source root is its
%% `src`, given or not, in single-file mode and in directory mode; `ern doc`
%% takes the same roots. A path outside `src` takes the roots it would take
%% with no manifest, and so does every path of a root package that has no
%% `src`
package_roots_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_roots/0) end}.

package_roots() ->
    root_manifest([]),
    write(".", "src/ro_main.ern",
          "export fn main() : Unit =\n    Io.println(RoNet.Http.word())\n"),
    write(".", "src/ro_net/http.ern", "export fn word() : String =\n    \"http\"\n"),
    write(".", "ro_top.ern", hello()),
    ?assertEqual({0, <<"source root src\nbuild root build\nmanifest package.conf\n"
                       "compiled RoNet.Http from src/ro_net/http.ern to build/ro_net/http.erc\n">>},
                 said(["build", "--verbose", "src/ro_net/http.ern"])),
    ?assertEqual({0, <<>>}, said(["build", "src/ro_main.ern"])),
    ?assertEqual({0, <<"http\n">>}, said(["run", "build/ro_main.erc"])),
    ?assertEqual({ok, ["ro_main.erc", "ro_net"]}, sorted_listing("build")),
    ok = file:delete("build/ro_main.erc"),
    ?assertEqual({0, <<>>}, said(["build", "--source-root", "src", "src/ro_main.ern"])),
    ?assert(filelib:is_regular("build/ro_main.erc")),
    [ok = file:delete(Erc) || Erc <- ["build/ro_main.erc", "build/ro_net/http.erc"]],
    {0, Tree} = said(["build", "--verbose", "src/ro_net"]),
    ?assertMatch(<<"source root src\nbuild root build\n", _/binary>>, Tree),
    ?assert(filelib:is_regular("build/ro_net/http.erc")),
    ?assertEqual({0, <<>>}, said(["build", "src"])),
    ?assert(filelib:is_regular("build/ro_main.erc")),
    ?assertEqual([], filelib:wildcard("src/**/*.erc")),
    {0, Page} = said(["doc", "src/ro_net/http.ern"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module RoNet.Http\n">>)),
    ?assertEqual({0, <<>>}, said(["doc", "src"])),
    ?assert(filelib:is_regular("build/ro_net/http.md")),
    ?assert(filelib:is_regular("build/index.md")),
    ?assertEqual([], filelib:wildcard("src/**/*.md")),
    %% a path outside `src` takes the roots it takes with no manifest
    {0, Top} = said(["build", "--verbose", "ro_top.ern"]),
    ?assertMatch(<<"source root .\nbuild root .\n", _/binary>>, Top),
    ?assert(filelib:is_regular("ro_top.erc")),
    %% a root package with no `src`
    in_directory(tmp(),
                 fun() ->
                     root_manifest([]),
                     write(".", "ro_bare.ern", hello()),
                     write(".", "sub/ro_sub.ern", hello()),
                     {0, Bare} = said(["build", "--verbose", "ro_bare.ern"]),
                     ?assertMatch(<<"source root .\nbuild root .\n", _/binary>>, Bare),
                     {0, Sub} = said(["build", "--verbose", "sub"]),
                     ?assertMatch(<<"source root sub\nbuild root sub\n", _/binary>>, Sub),
                     ?assert(filelib:is_regular("sub/ro_sub.erc"))
                 end).

%% A directory's names, in order.
sorted_listing(Dir) ->
    case file:list_dir(Dir) of
        {ok, Names} -> {ok, lists:sort(Names)};
        Error -> Error
    end.

%% report §11.9, §11.1, §11.2: `ern build` started in a root package builds
%% each named package before the root package's modules, in single-file
%% mode and in directory mode: each package's `src` into its `build` as a
%% directory is compiled, after the packages its manifest names and
%% otherwise in the root package's order, the entries written out of that
%% order here; a package with no `src` builds nothing. `--verbose` says each
%% package's build as it says the root package's, after the root package's
%% lines. A module found current is not compiled again. Under `--emit-erl`
%% the named packages are built as without it and the root package's
%% modules are written as `.erl`. `ern run` takes the roots it takes
%% elsewhere
package_build_order_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_order/0) end}.

package_build_order() ->
    Hello = fun(Text) -> ["export fn hello() : String =\n    ", Text, "\n"] end,
    source_package("bo_app", ["bo_mid", "bo_leaf"],
                   [{"bo_app.ern", Hello("BoMid.hello() <> \"app\"")}]),
    source_package("bo_bare", [], []),
    source_package("bo_mid", ["bo_leaf"], [{"bo_mid.ern", Hello("BoLeaf.hello() <> \"mid\"")}]),
    source_package("bo_leaf", [], [{"bo_leaf.ern", Hello("\"leaf\"")}]),
    source_package("bo_zed", [], [{"bo_zed.ern", Hello("\"zed\"")}]),
    root_manifest(["bo_app", "bo_bare", "bo_mid", "bo_leaf", "bo_zed"]),
    write(".", "src/bo_main.ern",
          "export fn main() : Unit =\n    Io.println(BoApp.hello() <> BoZed.hello())\n"),
    Package = fun(Name, Read) ->
                  ["source root lib/" ++ Name ++ "/src", "build root lib/" ++ Name ++ "/build"
                   | ["read " ++ Module ++ " from lib/" ++ File ++ ".erc"
                      || {Module, File} <- Read]]
                  ++ ["compiled " ++ ern_namespace:text(ern_namespace:namespace([Name]))
                      ++ " from lib/" ++ Name ++ "/src/" ++ Name ++ ".ern to lib/" ++ Name
                      ++ "/build/" ++ Name ++ ".erc"]
              end,
    Said = ["source root src", "build root build", "manifest package.conf"]
        ++ ["package " ++ Name ++ " 1.0.0" || Name <- ["bo_app", "bo_bare", "bo_mid", "bo_leaf",
                                                        "bo_zed"]]
        ++ Package("bo_leaf", [])
        ++ Package("bo_mid", [{"BoLeaf", "bo_leaf/build/bo_leaf"}])
        ++ Package("bo_app", [{"BoMid", "bo_mid/build/bo_mid"},
                              {"BoLeaf", "bo_leaf/build/bo_leaf"}])
        ++ Package("bo_zed", []),
    {0, Built} = said(["build", "--verbose", "src/bo_main.ern"]),
    ?assertEqual(unicode:characters_to_binary(lines(Said)),
                 binary:part(Built, 0, length(lines(Said)))),
    ?assertMatch({_, _}, binary:match(Built, <<"\ncompiled BoMain from src/bo_main.ern to"
                                               " build/bo_main.erc\n">>)),
    ?assertEqual({0, <<"leafmidappzed\n">>}, said(["run", "build/bo_main.erc"])),
    ?assertNot(filelib:is_file("lib/bo_bare/build")),
    %% found current, in directory mode
    {0, Again} = said(["build", "--verbose", "src"]),
    ?assertEqual([], compiled_lines(Again)),
    ?assertMatch({_, _}, binary:match(Again, <<"\nsource root lib/bo_zed/src\n">>)),
    %% --emit-erl
    ok = file:delete("lib/bo_leaf/build/bo_leaf.erc"),
    {0, Erl} = said(["build", "--emit-erl", "--verbose", "src/bo_main.ern"]),
    ?assertEqual(["compiled BoLeaf from lib/bo_leaf/src/bo_leaf.ern to"
                  " lib/bo_leaf/build/bo_leaf.erc",
                  "compiled BoMain from src/bo_main.ern to build/bo_main.erl"],
                 compiled_lines(Erl)),
    ?assertNot(filelib:is_file("lib/bo_leaf/build/bo_leaf.erl")).

%% report §11.9, §11.1: a named package is built again where a package it
%% names changes, as a directory's module is where a module it uses
%% changes: `mid`'s module, and the root package's, compiled again after
%% `leaf`'s interface changes, and not after a change to a body that
%% neither names
package_rebuilt_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_rebuilt/0) end}.

package_rebuilt() ->
    Leaf = fun(Extra) ->
               source_package("pr_leaf", [],
                              [{"pr_leaf.ern",
                                ["export fn hello() : String =\n    \"leaf\"\n\n"
                                 "export fn other() : Int =\n    ", Extra, "\n"]}])
           end,
    Leaf("1"),
    source_package("pr_mid", ["pr_leaf"],
                   [{"pr_mid.ern",
                     "export fn hello() : String =\n    PrLeaf.hello() <> \"mid\"\n"}]),
    root_manifest(["pr_mid", "pr_leaf"]),
    write(".", "src/pr_main.ern",
          "export fn main() : Unit =\n    Io.println(PrMid.hello() <> PrLeaf.hello())\n"),
    Compiled = fun() ->
                   {0, Said} = said(["build", "--verbose", "src/pr_main.ern"]),
                   [lists:nth(2, string:split(Line, " ", all)) || Line <- compiled_lines(Said)]
               end,
    ?assertEqual(["PrLeaf", "PrMid", "PrMain"], Compiled()),
    ?assertEqual([], Compiled()),
    Leaf("2"),
    ?assertEqual(["PrLeaf"], Compiled()),
    write(".", "lib/pr_leaf/src/pr_leaf.ern",
          "export fn hello() : String =\n    \"leaf\"\n\nexport fn other() : Int =\n    2\n\n"
          "export fn third() : Int =\n    3\n"),
    ?assertEqual(["PrLeaf", "PrMid", "PrMain"], Compiled()),
    ?assertEqual({0, <<"leafmidleaf\n">>}, said(["run", "build/pr_main.erc"])).

%% report §11.9: a named package's build has the load path of the standard
%% library, the builds of the packages its own manifest names, each under
%% the root package's `lib`, and the builds of the toolchain's libraries:
%% a module of a `--load-path` root is not found there, nor is a module of
%% a named package its manifest does not name, which the root package's
%% modules find. What the build says of such a module is shown here
package_load_path_of_a_build_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_load_path_of_a_build/0) end}.

package_load_path_of_a_build() ->
    Decoy = tmp(),
    Extra = filename:join(Decoy, "extra"),
    compiled_elsewhere(Decoy, "lb_extra.ern", "export fn word() : String =\n    \"extra\"\n",
                       filename:join(Extra, "lb_extra.erc")),
    source_package("lb_codec", [],
                   [{"lb_codec.ern", "export fn word() : String =\n    \"codec\"\n"}]),
    source_package("lb_mid", [],
                   [{"lb_mid.ern", "export fn word() : String =\n    \"mid\"\n"},
                    {"lb_mid/coded.ern", "export fn word() : String =\n    LbCodec.word()\n"},
                    {"lb_mid/extra.ern", "export fn word() : String =\n    LbExtra.word()\n"}]),
    root_manifest(["lb_mid", "lb_codec"]),
    write(".", "src/lb_main.ern",
          "export fn main() : Unit =\n"
          "    Io.println(LbMid.word() <> LbCodec.word() <> LbExtra.word())\n"),
    Unknown = fun(File, Name) ->
                  ["lib/lb_mid/src/lb_mid/", File, ".ern:2:5: unknown name ", Name, ".word\n"
                   "1 | export fn word() : String =\n2 |     ", Name, ".word()\n"
                   "  |     ^^^^^^^^^^^^\n\n"]
              end,
    ?assertEqual({1, iolist_to_binary([Unknown("coded", "LbCodec"), Unknown("extra", "LbExtra")])},
                 said(["build", "--load-path", Extra, "src/lb_main.ern"])),
    ?assert(filelib:is_regular("lib/lb_mid/build/lb_mid.erc")),
    ?assertEqual({0, <<"midcodecextra\n">>},
                 said(["run", "--load-path", Extra, "build/lb_main.erc"])).

%% report §11.9: what `ern build` writes under a named package may be
%% written by its owner alone, each file and each directory it makes,
%% whatever the user's mask, a file written again among them; what it
%% writes for the root package takes the mask's mode. The job runs as the
%% launcher runs it, under a mask that lets the group write
package_build_modes_test_() ->
    {timeout, 60, fun package_build_modes/0}.

package_build_modes() ->
    Ern = filename:absname("bin/ern"),
    Dir = tmp(),
    Built = fun() ->
                ?assertEqual("", os:cmd("cd " ++ Dir ++ " && umask 002 && " ++ Ern
                                        ++ " build src/bm_main.ern 2>&1"))
            end,
    in_directory(Dir,
                 fun() ->
                     source_package("bm_leaf", [],
                                    [{"bm_leaf.ern", "export fn one() : Int =\n    1\n"},
                                     {"bm_leaf/deep/inner.ern",
                                      "export fn two() : Int =\n    2\n"}]),
                     root_manifest(["bm_leaf"]),
                     write(".", "src/bm_main.ern",
                           "export fn main() : Unit =\n"
                           "    Io.println(Int.toString(BmLeaf.one()))\n")
                 end),
    Built(),
    In = fun(Path) -> filename:join(Dir, Path) end,
    [?assertEqual(0, mode_of(In(Path)) band 8#022)
     || Path <- ["lib/bm_leaf/build", "lib/bm_leaf/build/bm_leaf", "lib/bm_leaf/build/bm_leaf/deep",
                 "lib/bm_leaf/build/bm_leaf.erc", "lib/bm_leaf/build/bm_leaf/deep/inner.erc"]],
    ?assertEqual(8#020, mode_of(In("build/bm_main.erc")) band 8#020),
    ?assertEqual(8#020, mode_of(In("build")) band 8#020),
    ok = file:change_mode(In("lib/bm_leaf/build/bm_leaf.erc"), 8#666),
    write(Dir, "lib/bm_leaf/src/bm_leaf.ern", "export fn one() : Int =\n    11\n"),
    Built(),
    ?assertEqual(8#644, mode_of(In("lib/bm_leaf/build/bm_leaf.erc"))).

%% report §11.9, §11.1: a named package's build is cleaned up as a
%% directory's is, after a build in which each of its modules compiled: a
%% `.erc` whose source is gone is removed, and the directory that leaves
%% empty; a build of the package in which a module fails removes nothing
package_build_cleanup_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_cleanup/0) end}.

package_build_cleanup() ->
    source_package("bc_leaf", [], [{"bc_leaf.ern", "export fn one() : Int =\n    1\n"},
                                   {"bc_leaf/old.ern", "export fn two() : Int =\n    2\n"},
                                   {"bc_leaf/kept/gone.ern",
                                    "export fn three() : Int =\n    3\n"}]),
    root_manifest(["bc_leaf"]),
    write(".", "bc_main.ern", hello()),
    ?assertEqual({0, <<>>}, said(["build", "bc_main.ern"])),
    ok = file:delete("lib/bc_leaf/src/bc_leaf/kept/gone.ern"),
    write(".", "lib/bc_leaf/src/bc_leaf/broken.ern", "export fn four() : Int =\n    \"x\"\n"),
    {1, _} = said(["build", "bc_main.ern"]),
    ?assert(filelib:is_regular("lib/bc_leaf/build/bc_leaf/kept/gone.erc")),
    ok = file:delete("lib/bc_leaf/src/bc_leaf/broken.ern"),
    ok = file:delete("lib/bc_leaf/src/bc_leaf/old.ern"),
    {0, Said} = said(["build", "--verbose", "bc_main.ern"]),
    ?assertMatch({_, _}, binary:match(Said, <<"\nremoved lib/bc_leaf/build/bc_leaf/kept/gone.erc\n"
                                              "removed lib/bc_leaf/build/bc_leaf/old.erc\n">>)),
    ?assertEqual({ok, ["bc_leaf.erc"]}, sorted_listing("lib/bc_leaf/build")).

%% report §11.9, §11.1: a module of a named package that does not compile
%% fails as §11.1 says: a module that uses it, of a named package or of the
%% root package, is not compiled, and every failure is reported, every
%% other module compiled; so where the package had never been built, and
%% where a `.erc` of the module that fails stands from an earlier build
package_build_failure_passes_on_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_failure_passes_on/0) end}.

package_build_failure_passes_on() ->
    Util = fun(Body) -> write(".", "lib/fp_leaf/src/fp_leaf/util.ern",
                              ["export fn one() : Int =\n    ", Body, "\n"])
           end,
    source_package("fp_leaf", [],
                   [{"fp_leaf.ern", "export fn hello() : String =\n    \"leaf\"\n"}]),
    Util("\"x\""),
    source_package("fp_mid", ["fp_leaf"],
                   [{"fp_mid.ern", "export fn hello() : String =\n    FpLeaf.hello()\n"},
                    {"fp_mid/user.ern", "export fn two() : Int =\n    FpLeaf.Util.one() + 1\n"}]),
    root_manifest(["fp_mid", "fp_leaf"]),
    write(".", "src/fp_main.ern",
          "export fn main() : Unit =\n    Io.println(Int.toString(FpMid.User.two()))\n"),
    write(".", "src/fp_other.ern",
          "export fn main() : Unit =\n    Io.println(FpMid.hello())\n"),
    Failed = fun() ->
                 {1, Said} = said(["build", "src"]),
                 ?assertMatch(<<"lib/fp_leaf/src/fp_leaf/util.ern:2:5: ", _/binary>>, Said),
                 ?assertMatch({_, _},
                              binary:match(Said, <<"\nern build: FpMid.User is not compiled, since"
                                                   " it uses FpLeaf.Util, which failed\n"
                                                   "ern build: FpMain is not compiled, since it"
                                                   " uses FpMid.User, which failed\n">>)),
                 [?assert(filelib:is_regular(Erc))
                  || Erc <- ["lib/fp_leaf/build/fp_leaf.erc", "lib/fp_mid/build/fp_mid.erc",
                             "build/fp_other.erc"]],
                 ?assertNot(filelib:is_file("lib/fp_mid/build/fp_mid/user.erc")),
                 ?assertNot(filelib:is_file("build/fp_main.erc"))
             end,
    Failed(),
    ?assertNot(filelib:is_file("lib/fp_leaf/build/fp_leaf/util.erc")),
    Util("1"),
    ?assertEqual({0, <<>>}, said(["build", "src"])),
    ?assertEqual({0, <<"2\n">>}, said(["run", "build/fp_main.erc"])),
    Util("\"x\""),
    ok = file:delete("build/fp_main.erc"),
    ok = file:delete("lib/fp_mid/build/fp_mid/user.erc"),
    Failed(),
    ?assert(filelib:is_regular("lib/fp_leaf/build/fp_leaf/util.erc")).

%% report §11.9: a named package whose build cannot be written fails its
%% modules with the host's reason, as any file a build cannot write, and a
%% module that uses one is not compiled. Not covered: a build another user
%% owns, which a test run by one user cannot make
package_build_unwritable_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_unwritable/0) end}.

package_build_unwritable() ->
    source_package("bu_leaf", [], [{"bu_leaf.ern", "export fn one() : Int =\n    1\n"}]),
    source_package("bu_mid", ["bu_leaf"],
                   [{"bu_mid.ern", "export fn two() : Int =\n    BuLeaf.one()\n"}]),
    root_manifest(["bu_mid", "bu_leaf"]),
    write(".", "bu_main.ern", hello()),
    ok = file:make_dir("lib/bu_leaf/build"),
    ok = file:change_mode("lib/bu_leaf/build", 8#555),
    try
        ?assertEqual(refused_lines("build", ["lib/bu_leaf/build: permission denied, and"
                                             " bu_leaf.erc is written whole by a rename there",
                                             "BuMid is not compiled, since it uses BuLeaf, which"
                                             " failed"]),
                     said(["build", "bu_main.ern"]))
    after
        ok = file:change_mode("lib/bu_leaf/build", 8#755)
    end,
    ?assert(filelib:is_regular("bu_main.erc")).

%% report §11.9, §11.1: a path under a named package's `src` that breaks
%% §11.1's rule of a path's shape is held to no namespace by the build's
%% rules, and fails that file alone where the package is built, in §11.1's
%% words; the package's other modules are built
package_build_path_shape_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_path_shape/0) end}.

package_build_path_shape() ->
    source_package("ps_leaf", [], [{"ps_leaf.ern", "export fn one() : Int =\n    1\n"},
                                   {"Util.ern", "export fn two() : Int =\n    2\n"}]),
    root_manifest(["ps_leaf"]),
    write(".", "ps_main.ern", hello()),
    ?assertEqual(refusal("build", "lib/ps_leaf/src/Util.ern: path component `Util` must be"
                                  " lowercase"),
                 said(["build", "ps_main.ern"])),
    ?assert(filelib:is_regular("lib/ps_leaf/build/ps_leaf.erc")),
    ?assert(filelib:is_regular("ps_main.erc")).

%% report §11.9, §11.4: `ern doc` builds no named package, and reads their
%% builds as they stand
package_doc_builds_none_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_doc_builds_none/0) end}.

package_doc_builds_none() ->
    source_package("dn_leaf", [], [{"dn_leaf.ern", "export fn one() : Int =\n    1\n"}]),
    root_manifest(["dn_leaf"]),
    write(".", "src/dn_main.ern",
          "export fn main() : Unit =\n    Io.println(Int.toString(DnLeaf.one()))\n"),
    {1, _} = said(["doc", "src/dn_main.ern"]),
    {1, _} = said(["doc", "src"]),
    ?assertNot(filelib:is_file("lib/dn_leaf/build")),
    ?assertEqual({0, <<>>}, said(["build", "src"])),
    {ok, Before} = file:read_file("lib/dn_leaf/build/dn_leaf.erc"),
    write(".", "lib/dn_leaf/src/dn_leaf.ern",
          "export fn one() : Int =\n    1\n\nexport fn two() : Int =\n    2\n"),
    {0, Page} = said(["doc", "src/dn_main.ern"]),
    ?assertMatch({_, _}, binary:match(Page, <<"# Ernest module DnMain\n">>)),
    ?assertEqual({0, <<>>}, said(["doc", "src"])),
    ?assertEqual({ok, Before}, file:read_file("lib/dn_leaf/build/dn_leaf.erc")).

%% report §11.9: `ern build` and `ern doc` refuse a `--build-root` that is
%% the root package's `lib`, a named package's directory or a path under
%% one, as they refuse a path given there, in the same words and in the same
%% group of refusals, the argument's line first; nothing is written
package_build_root_under_lib_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_build_root_under_lib/0) end}.

package_build_root_under_lib() ->
    source_package("ul_leaf", [], [{"ul_leaf.ern", "export fn one() : Int =\n    1\n"}]),
    write(".", "package.conf", manifest_of([{"ul_leaf", "1.0.0"}, {"bad", "x"}])),
    write(".", "src/ul_main.ern", hello()),
    Bad = "package.conf: the entry for bad's version is not three numbers joined by `.`, none"
        " written with a leading zero: \"x\"",
    Leaf = fun(Path) -> Path ++ " is the package ul_leaf's, which ern build builds" end,
    Lib = "lib holds the named packages, which ern build builds",
    [?assertEqual(refused_lines(Job, [Bad, Line]),
                  said([Job, "--source-root", "src", "--build-root", Root, "src/ul_main.ern"]))
     || Job <- ["build", "doc"],
        {Root, Line} <- [{"lib/ul_leaf/build", Leaf("lib/ul_leaf/build")}, {"lib", Lib},
                         {"lib/elsewhere", Lib}, {"lib/ul_leaf/x.erc", Leaf("lib/ul_leaf/x.erc")}]],
    [?assertEqual(refused_lines(Job, [Bad, Leaf("lib/ul_leaf/src/ul_leaf.ern"), Lib]),
                  said([Job, "--build-root", "lib/other", "lib/ul_leaf/src/ul_leaf.ern"]))
     || Job <- ["build", "doc"]],
    write(".", "package.conf", manifest_of([{"ul_leaf", "1.0.0"}])),
    ?assertEqual(refusal("build", Leaf("lib/ul_leaf/build")),
                 said(["build", "--build-root", "lib/ul_leaf/build", "src/ul_main.ern"])),
    ?assertEqual([], filelib:wildcard("lib/**/*.erc")),
    ?assertNot(filelib:is_file("lib/other")).

%% report §11.1, §11.9: a module of the root package at the namespace of a
%% library's module on which a named package's module depends is refused,
%% naming the package; the package's modules are those of its build as the
%% job finds it, which `ern build` builds first, and `ern doc` reads as it
%% stands
package_hiding_dependent_test_() ->
    {timeout, 60, fun() -> in_directory(tmp(), fun package_hiding_dependent/0) end}.

package_hiding_dependent() ->
    source_package("hd_server", [],
                   [{"hd_server.ern",
                     "export fn decoded(text : String) : Optional(Bytes) =\n"
                     "    Base64.decode(text)\n"}]),
    root_manifest(["hd_server"]),
    write(".", "src/base64.ern", "export fn mine() : String =\n    \"mine\"\n"),
    write(".", "src/hd_main.ern", hello()),
    Refused = fun(Job) ->
                  refusal(Job, "src/base64.ern: Base64 hides the library Base64, which the package"
                               " hd_server uses")
              end,
    ?assertEqual(Refused("build"), said(["build", "src"])),
    ?assert(filelib:is_regular("lib/hd_server/build/hd_server.erc")),
    ?assert(filelib:is_regular("build/hd_main.erc")),
    ?assertEqual(Refused("build"), said(["build", "src/base64.ern"])),
    ?assertEqual(Refused("doc"), said(["doc", "src/base64.ern"])),
    ?assertEqual(Refused("doc"), said(["doc", "src"])).

captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> Output end.
