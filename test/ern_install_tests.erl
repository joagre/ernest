%% The installation and the release archive, each made by make, and the
%% toolchain run where they put it (docs/design/install.md). Run from
%% this directory by its Makefile, never beside ern_manual_tests: make
%% writes the manual pages under ../build/stdlib, which those tests write
%% too. The helpers that run a command are ern_integration_tests'.
-module(ern_install_tests).

-include_lib("eunit/include/eunit.hrl").

%% The paths install.sh installs every tracked file of, as its `documents`
%% names them, a directory with a slash after it.
-define(DOCUMENTS, ["report/", "guide/", "tour/", "examples/", "editors/emacs/README.md"]).

%% A file of examples/ the repository does not track, which install/0
%% writes before the installation and removes after it, whatever its end.
-define(UNTRACKED, "../examples/ern_install_tests_untracked.txt").

%% The installation and the archive, each made by make, one after the other,
%% since two makes at once would each write the built trees. Each make here
%% builds before it installs, and a test that runs beside other areas runs
%% at their load, so no time is known before the first part has run: the
%% first part is timed, and each part after it is given that time for each
%% make it runs and once more for the rest of its work, since none of its
%% makes does more than the first part's, which builds, stages and
%% installs, and none of the parts runs more of the toolchain than the
%% first part runs. Written on 2026-10-16, after the test took 190 to 350 s
%% under the full run's load against its one limit of 300 s.
installation_test_() ->
    {setup, fun timed_install/0, fun(_) -> ok end, fun parts/1}.

%% The first part, install/0, and its time in milliseconds.
timed_install() ->
    Started = erlang:monotonic_time(millisecond),
    Base = install(),
    {Base, erlang:monotonic_time(millisecond) - Started}.

%% The parts after the first, in order, each bounded by the makes it runs:
%% the archive's own make install, which compiles the helper and installs,
%% is counted as a make.
parts({Base, Ms}) ->
    Bound = fun(Makes) -> ceil((Makes + 1) * Ms / 1000) end,
    {inorder, [{timeout, Bound(1), {"staged under a DESTDIR", fun() -> staged(Base) end}},
               {timeout, Bound(2), {"a bin/ern of a person's own", fun() -> own(Base) end}},
               {timeout, Bound(1), {"a prefix that cannot be written",
                                    fun() -> closed(Base) end}},
               {timeout, Bound(2), {"the release archive", fun release/0}}]}.

%% docs/design/install.md: make install writes the tree under a
%% prefix, bin/ern a relative link to its launcher; the prefix moved to
%% another place runs there, `ern`, the shell, a program that runs another
%% through the helper, and `ern doc --man`, and `man` finds ern(1), a
%% module's page and a library's through the path alone. make uninstall
%% removes what was installed and leaves a page of the user's, and refuses
%% where nothing is installed. No installed module carries the host's debug
%% information. Written with the code. The installed documents were not:
%% the README is the release's, every link of a document names a file
%% installed beside it, and the guide's link to an example leads into the
%% repository on main. A regression test, written after the README was
%% found installed with its image and seven of its links naming nothing,
%% and the guide with fourteen; it does not follow a link into the
%% repository. That the directories of the installation's own go with it
%% is a regression test too, written on 2026-10-04 after the report's
%% directory was found left behind, and the documents' with it; and so is
%% that no module compiled from an application's tests is installed,
%% written after the runtime's test helper `ern_waits` was found shipped;
%% and so is that no source of the standard library is installed, written
%% on 2026-10-15 when the log's *The Layout Completed* stopped installing it.
%% So is that every `.md` under report/, guide/ and tour/ is installed where
%% it stands, and nothing else of the checkout's documents but the README's
%% and ACKNOWLEDGMENTS.md, and that the link check reads each document at
%% its depth from its own directory, the deployment guide's among them:
%% written on 2026-10-16, after guide/deployment.md was found not
%% installed, and the check found reading the top directory alone since the
%% report and the guide moved below it. A document of tour/, which the
%% checkout does not hold yet, and one two directories down are not
%% covered. So is that the installed standard library is one file for each
%% of its modules, its `.erc`, and the shell's build one for each of the
%% shell's: written on 2026-10-17, when the copies of each under its
%% Erlang name, which the host's loader read from the code path, went, and
%% `ern` came to load each module from its `.erc`; it does not cover a
%% library's build under build/libs. So is that every file the repository
%% tracks under examples/, and editors/emacs/README.md, is installed where
%% it stands and no file it does not track, one written for the test among
%% them; that each link of the guide's to either stays the one the guide
%% writes and names a file installed, as no link to them into the
%% repository remains; and that the installed examples build with the
%% installed `ern` and its libraries: written on 2026-10-17, after the
%% code that installs them, when the guide was found linking seven programs
%% and the note that turns the Emacs mode on that no installation held. The
%% examples are built as one directory, not each as its first comment
%% builds it, and none is run here; nor is a checkout staged by another
%% user than its owner, root among them, or a tree git does not hold.
%% Answers the directory the parts after it work in.
install() ->
    Version = version(),
    Base = filename:absname("build/install"),
    ok = ern_integration_tests:del(Base),
    ok = filelib:ensure_path(Base ++ "/work"),
    ok = file:write_file(?UNTRACKED, <<>>),
    try ern_integration_tests:succeed("make -s -C .. install PREFIX=" ++ Base ++ "/a")
    after ok = file:delete(?UNTRACKED)
    end,
    ?assertEqual({ok, "../lib/ernest/bin/ern"}, file:read_link(Base ++ "/a/bin/ern")),
    ?assertEqual([], debug_information(Base ++ "/a")),
    ?assertEqual([], forms_missing(Base ++ "/a")),
    ?assertEqual([], test_modules(filelib:wildcard(Base ++ "/a/lib/ernest/erl/*/ebin/*.beam"))),
    ?assertNot(filelib:is_dir(Base ++ "/a/lib/ernest/src")),
    ?assertEqual(compiled("../src/stdlib"), installed(Base ++ "/a/lib/ernest/build/stdlib")),
    ?assertEqual(compiled("../src/shell"), installed(Base ++ "/a/lib/ernest/build/shell")),
    Documents = Base ++ "/a/share/doc/ernest/",
    {ok, Installed} = file:read_file(Documents ++ "README.md"),
    ?assertMatch({_, _}, binary:match(Installed, <<"</picture>\n\n# Ernest ", Version/binary,
                                                    "\n">>)),
    ?assertEqual(lists:sort(["ACKNOWLEDGMENTS.md", "README.md"
                             | [File || File <- tracked(), filename:extension(File) =:= ".md"]]),
                 lists:sort(filelib:wildcard("**/*.md", Documents))),
    ?assertEqual(tracked(), [File || File <- installed(Documents),
                                     lists:any(fun(Path) -> lists:prefix(Path, File) end,
                                               ?DOCUMENTS)]),
    ?assertNot(filelib:is_file(Documents ++ "examples/" ++ filename:basename(?UNTRACKED))),
    ?assertEqual([], dead_links(Documents)),
    kept_links(Documents),
    ?assert(links_to(Documents ++ "guide/language.md", "/blob/main/docs/module_doc_template.md")),
    ok = file:rename(Base ++ "/a", Base ++ "/b"),
    Ern = Base ++ "/b/bin/ern",
    Examples = Base ++ "/b/share/doc/ernest/examples",
    _ = ern_integration_tests:succeed(Ern ++ " build --build-root " ++ Base ++ "/work/examples .",
                                      [{cd, Examples}]),
    ?assertEqual(compiled(Examples), installed(Base ++ "/work/examples")),
    %% report §12.5: an installation of the repository's build is no release,
    %% which its version text marks
    ?assertEqual({0, <<"ern ", Version/binary, "-dev\n">>}, in_work(Base, Ern ++ " --version")),
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    _ = ern_integration_tests:succeed(Ern ++ " build hi.ern", [{cd, Base ++ "/work"}]),
    ?assertEqual({0, <<"hi\n">>}, in_work(Base, Ern ++ " run hi.erc")),
    {0, ShellOutput} = in_work(Base, "printf '1 + 1\\n' | " ++ Ern ++ " shell"),
    ?assertMatch({_, _}, binary:match(ShellOutput, <<"> 2 : Int\n">>)),
    ?assertMatch(<<".\\\" Generated by ern ", _/binary>>,
                 ern_integration_tests:succeed(Ern ++ " doc --man hi.ern",
                                               [{cd, Base ++ "/work"}])),
    case os:find_executable("man") of
        false ->
            io:format(user, "  man not installed; the installed pages were not looked up.~n", []);
        _ ->
            ManPath = Base ++ "/b/share/man/",
            ?assertEqual({0, iolist_to_binary([ManPath, "man1/ern.1\n", ManPath,
                                               "man3/Ernest.List.3ern\n", ManPath,
                                               "man3/Ernest.Markdown.3ern\n"])},
                         ern_integration_tests:sh("env -u MANPATH PATH=" ++ Base
                                                  ++ "/b/bin:/usr/bin:/bin "
                                                  "man -w ern Ernest.List Ernest.Markdown"))
    end,
    ok = file:write_file(Base ++ "/b/share/man/man3/Mine.3", <<"mine\n">>),
    _ = ern_integration_tests:succeed("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b"),
    ?assertEqual([Base ++ "/b/share/man/man3/Mine.3"],
                 [File || File <- filelib:wildcard(Base ++ "/b/**/*"), not filelib:is_dir(File)]),
    %% the directories of the installation's own go with it
    ?assertNot(filelib:is_dir(Base ++ "/b/share/doc/ernest")),
    ?assertMatch({2, _},
                 ern_integration_tests:sh("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b")),
    Base.

%% docs/design/install.md: a DESTDIR stages the same tree, which
%% runs where it is staged, and make uninstall with it removes every file.
%% Written with the code.
staged(Base) ->
    Version = version(),
    Stage = Base ++ "/stage",
    _ = ern_integration_tests:succeed("make -s -C .. install DESTDIR=" ++ Stage
                                      ++ " PREFIX=/opt/ernest"),
    ?assertEqual({0, <<"ern ", Version/binary, "-dev\n">>},
                 in_work(Base, Stage ++ "/opt/ernest/bin/ern --version")),
    _ = ern_integration_tests:succeed("make -s -C .. uninstall DESTDIR=" ++ Stage
                                      ++ " PREFIX=/opt/ernest"),
    ?assertEqual([],
                 [File || File <- filelib:wildcard(Stage ++ "/**/*"), not filelib:is_dir(File)]).

%% docs/design/install.md: a `bin/ern` that is no longer the
%% installation's link is a person's own: install refuses it before it
%% touches the installation there, and uninstall leaves it, a regression
%% test of both, which removed it.
own(Base) ->
    Own = Base ++ "/c",
    _ = ern_integration_tests:succeed("make -s -C .. install PREFIX=" ++ Own),
    ok = file:delete(Own ++ "/bin/ern"),
    ok = file:write_file(Own ++ "/bin/ern", <<"mine\n">>),
    {2, NotOurs} = ern_integration_tests:sh("make -s -C .. install PREFIX=" ++ Own),
    ?assertMatch({_, _}, binary:match(NotOurs, <<"bin/ern is there already and is not Ernest's">>)),
    ?assert(filelib:is_regular(Own ++ "/lib/ernest/installed")),
    _ = ern_integration_tests:succeed("make -s -C .. uninstall PREFIX=" ++ Own),
    ?assertEqual({ok, <<"mine\n">>}, file:read_file(Own ++ "/bin/ern")),
    ?assertNot(filelib:is_dir(Own ++ "/lib/ernest")).

%% docs/design/install.md: a prefix that cannot be written is
%% refused with nothing written. Written with the code.
closed(Base) ->
    case ern_integration_tests:sh("id -u") of
        {0, <<"0\n">>} ->
            io:format(user, "  run as root; a prefix that cannot be written was not tried.~n", []);
        _ ->
            ok = file:make_dir(Base ++ "/closed"),
            ok = file:change_mode(Base ++ "/closed", 8#555),
            {2, Refused} = ern_integration_tests:sh("make -s -C .. install PREFIX=" ++ Base
                                                    ++ "/closed/x"),
            ?assertMatch({_, _}, binary:match(Refused, <<"cannot be written">>)),
            ?assertEqual({ok, []}, file:list_dir(Base ++ "/closed")),
            ok = file:change_mode(Base ++ "/closed", 8#755)
    end.

%% A command run in the work directory under Base: its status and output.
in_work(Base, Command) ->
    ern_integration_tests:sh(Command, [{cd, Base ++ "/work"}]).

%% The checkout's version, as VERSION gives it.
version() ->
    {ok, Text} = file:read_file("../VERSION"),
    string:trim(Text).

%% docs/design/install.md: make release writes the archive, the staged tree
%% with the helper as its C source, a Makefile and a README; its make
%% compiles the helper, and its make install installs under a prefix, where
%% a program that runs another through the helper runs, and its make
%% uninstall removes it. Written with the code. The README it carries is the
%% one it installs, and the installed guide's link to the log leads into the
%% repository at the release's tag, as its links to the examples and the
%% Emacs README stay its own: a regression test, as install/0's is. The logo
%% the README shows stands beside it in the archive, as under the prefix.
%% The installed `ern` is a release, whose version text is VERSION's alone,
%% as the repository's build is not (report §12.5): a regression test,
%% written after the code (the log's *MVP 3.1 Read*). The archive holds no
%% module compiled from an application's tests, as the installation does
%% not.
release() ->
    Base = filename:absname("build/release"),
    ok = ern_integration_tests:del(Base),
    ok = filelib:ensure_path(Base ++ "/work"),
    _ = ern_integration_tests:succeed("make -s -C .. release"),
    {ok, Version} = file:read_file("../VERSION"),
    Name = "ern-" ++ string:trim(binary_to_list(Version)),
    Archive = "../build/release/" ++ Name ++ ".tar.gz",
    {0, Listing} = ern_integration_tests:sh("tar -tzf " ++ Archive),
    Entries = binary:split(Listing, <<"\n">>, [global, trim]),
    [?assert(lists:member(list_to_binary(Name ++ "/" ++ File), Entries))
     || File <- ["Makefile", "README.md", "install.sh", "ern_exec.c", "bin/ern",
                 "lib/ernest/bin/ern", "lib/ernest/installed", "share/man/man1/ern.1"]],
    ?assertNot(lists:member(list_to_binary(Name ++ "/lib/ernest/erl/runtime/priv/ern_exec"),
                            Entries)),
    ?assertEqual([], test_modules([binary_to_list(Entry) || Entry <- Entries])),
    _ = ern_integration_tests:succeed("tar -xzf " ++ filename:absname(Archive), [{cd, Base}]),
    Unpacked = Base ++ "/" ++ Name,
    _ = ern_integration_tests:succeed("make -s install PREFIX=" ++ Base ++ "/p", [{cd, Unpacked}]),
    ?assertEqual([], debug_information(Base ++ "/p")),
    Documents = Base ++ "/p/share/doc/ernest/",
    {ok, Readme} = file:read_file(Unpacked ++ "/README.md"),
    ?assertEqual({ok, Readme}, file:read_file(Documents ++ "README.md")),
    ?assertEqual([], dead_links(Documents)),
    %% the README beside the archive shows the logo it carries there
    ?assertEqual([], dead_links(Unpacked ++ "/")),
    Tag = "v" ++ string:trim(binary_to_list(Version)),
    kept_links(Documents),
    ?assert(links_to(Documents ++ "guide/language.md",
                     "/blob/" ++ Tag ++ "/docs/module_doc_template.md")),
    Ern = Base ++ "/p/bin/ern",
    %% report §12.5: a release's version text is VERSION's alone
    ?assertEqual({0, <<"ern ", (string:trim(Version))/binary, "\n">>},
                 ern_integration_tests:sh(Ern ++ " --version", [{cd, Base ++ "/work"}])),
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    _ = ern_integration_tests:succeed(Ern ++ " build hi.ern", [{cd, Base ++ "/work"}]),
    ?assertEqual({0, <<"hi\n">>},
                 ern_integration_tests:sh(Ern ++ " run hi.erc", [{cd, Base ++ "/work"}])),
    _ = ern_integration_tests:succeed("make -s uninstall PREFIX=" ++ Base ++ "/p",
                                      [{cd, Unpacked}]),
    ?assertEqual([],
                 [File || File <- filelib:wildcard(Base ++ "/p/**/*"), not filelib:is_dir(File)]).

%% The modules of Files, paths ending `erl/<application>/ebin/<module>.beam`,
%% that the checkout compiled from the application's test/ directory.
test_modules(Files) ->
    [File || File <- Files, filename:extension(File) =:= ".beam",
             Ebin <- [filename:dirname(File)], filename:basename(Ebin) =:= "ebin",
             Application <- [filename:basename(filename:dirname(Ebin))],
             filelib:is_regular(filename:join(["..", "erl", Application, "test",
                                               filename:basename(File, ".beam") ++ ".erl"]))].

%% The files the repository tracks under the paths install.sh installs, as
%% it asks git for them, each by its path in the checkout.
tracked() ->
    Paths = lists:append(lists:join(" ", ?DOCUMENTS)),
    lists:sort(string:lexemes(os:cmd("git -C .. ls-files -- " ++ Paths), "\n")).

%% The guide's links to a file of examples/ or editors/, each read from the
%% checkout's guide, are in the installed guide as the checkout's writes
%% them and name a file installed; and no link of the installed guide's
%% leads to either in the repository. The checkout's guide is the
%% documents git tracks there, so that an editor's files beside them, a
%% lock that names no file among them, are not read: a regression test,
%% written on 2026-10-25, when an editor's lock of guide/language.md
%% failed the reading.
kept_links(Documents) ->
    Kept = [{Guide, Target} || Guide <- tracked(), filename:dirname(Guide) =:= "guide",
                               filename:extension(Guide) =:= ".md",
                               Target <- link_targets("../" ++ Guide),
                               lists:prefix("../examples/", Target)
                                   orelse lists:prefix("../editors/", Target)],
    ?assert(lists:member({"guide/language.md", "../editors/emacs/README.md"}, Kept)),
    ?assert(lists:any(fun({_, Target}) -> lists:prefix("../examples/", Target) end, Kept)),
    ?assertEqual([], [Link || {Guide, Target} = Link <- Kept,
                              not lists:member(Target, link_targets(Documents ++ Guide))]),
    ?assertEqual([], [Link || {Guide, Target} = Link <- Kept,
                              not filelib:is_regular(filename:join(
                                                       filename:dirname(Documents ++ Guide),
                                                       Target))]),
    ?assertEqual([], [Guide || Guide <- filelib:wildcard("guide/*.md", Documents),
                               begin
                                   {ok, Text} = file:read_file(Documents ++ Guide),
                                   Pattern = "\\]\\([^)]*/blob/[^/)]+/(examples|editors)/",
                                   re:run(Text, Pattern) =/= nomatch
                               end]).

%% The links of the documents under a directory, at any depth, that name
%% nothing: a link's target and an image's source, a `<picture>`'s `srcset`
%% among them, each read from the document's own directory, an address with
%% a scheme and an anchor of the document's own aside; a target with a
%% slash after it names a directory, and any other a file. Each is given
%% by the document's path under the directory. The `srcset` is read since
%% 2026-10-16, when the logo's files were renamed: a regression test, which
%% reads a `srcset` of one address and no other. A directory is read since
%% 2026-10-17, when the installation came to hold examples/README.md, which
%% links `upgrade/`.
dead_links(Directory) ->
    [{lists:nthtail(length(Directory), Document), Target}
     || Document <- filelib:wildcard(Directory ++ "**/*.md"),
        Target <- link_targets(Document),
        not names(filename:join(filename:dirname(Document), Target), lists:last(Target))].

names(Path, $/) -> filelib:is_dir(Path);
names(Path, _) -> filelib:is_regular(Path).

link_targets(Document) ->
    {ok, Text} = file:read_file(Document),
    Pattern = "\\]\\(([^)#]+)[^)]*\\)|(?:src|srcset)=\"([^\"]+)\"",
    case re:run(Text, Pattern, [global, {capture, all_but_first, list}]) of
        {match, Matches} ->
            [Target || Match <- Matches, Target <- Match,
                       Target =/= [], string:find(Target, "://") =:= nomatch];
        nomatch ->
            []
    end.

%% Whether a document holds a link whose address ends as given.
links_to(Document, AddressEnd) ->
    {ok, Text} = file:read_file(Document),
    binary:match(Text, list_to_binary(AddressEnd ++ ")")) =/= nomatch.

%% A program that runs another through the runtime's helper (Appendix E.23).
runs_echo() ->
    "export fn main() : Unit = match Os.run(Os.Command(\n"
    "    program = \"echo\", arguments = [\"hi\"], input = <<>>), 5000) {\n"
    "    Right(Os.Finished(stdout = out)) -> Io.print(Optional.withDefault(\n"
    "        String.fromUtf8(out), \"\"))\n"
    "  | Left(e) -> Io.println(Io.show(e))\n"
    "}\n".

%% Report §12.7: the compiled Ernest modules under a directory that lack
%% their canonical forms, ErnC, which a node ships to a peer that lacks a
%% definition and which the strip must keep. A regression test, written
%% after the strip dropped them (2026-10-17).
forms_missing(Dir) ->
    [File || File <- filelib:wildcard(Dir ++ "/**/*.erc"),
             begin
                 {ok, Beam} = file:read_file(File),
                 {ok, _, Chunks} = beam_lib:all_chunks(Beam),
                 not lists:keymember("ErnC", 1, Chunks)
             end].

%% The `.erc` each module of a source root compiles to, by its path.
compiled(SourceRoot) ->
    lists:sort([filename:rootname(Source) ++ ".erc"
                || Source <- filelib:wildcard("**/*.ern", SourceRoot)]).

%% Every file under a directory, by its path.
installed(Dir) ->
    lists:sort([File || File <- filelib:wildcard("**/*", Dir),
                        not filelib:is_dir(filename:join(Dir, File))]).

%% The modules under a directory that carry the host's debug information.
debug_information(Dir) ->
    [File || File <- filelib:wildcard(Dir ++ "/**/*.{beam,erc}"),
             begin
                 {ok, Beam} = file:read_file(File),
                 {ok, _, Chunks} = beam_lib:all_chunks(Beam),
                 lists:keymember("Dbgi", 1, Chunks)
             end].
