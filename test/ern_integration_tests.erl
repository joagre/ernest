%% Plan, MVP 1: the programs compiled with bin/ern build and run with bin/ern
%% as a user would, output compared as a multiset of lines with
%% expected/<name>.out, since prints from different processes interleave
%% by scheduling. Run from this directory by its Makefile.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% Report §11.1: an example compiled into test/build.
-define(BUILD, "../bin/ern build --source-root ../examples --build-root build ").

-define(PROGRAMS, ["hello", "counter", "upgrade", "pingpong", "stack", "patterns",
                   "kvparser", "services"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (pingpong),
%% §6.6 (counter), §6.10 (upgrade), §5.10 (patterns),
%% §5.5 (kvparser), §4.4 (stack), Appendix E.22 (services)
%% Each program is compiled and run apart from the others, so they run in
%% parallel (plan, MVP 2.6).
programs_test_() ->
    {inparallel, [{Name, {timeout, 60, fun() -> program(Name) end}} || Name <- ?PROGRAMS]}.

program(Name) ->
    {0, _} = sh(?BUILD ++ "../examples/" ++ Name
                ++ ".ern"),
    {0, Out} = sh("../bin/ern run build/" ++ Name ++ ".erc"),
    ?assertEqual(expected(Name), unstamped(lines(Out))).

%% Plan, MVP 2.5: the paper programs that the doors of step 4 opened.
%% snake waits for a terminal, so it is only compiled here and ern_terminal_tests
%% plays it under a pseudo-terminal; echo is run by hand; the others run below.
-define(COMPILES, ["filesync", "repl", "snake", "echo", "webserver"]).

compiles_test_() ->
    {inparallel, [{Name, fun() ->
                {0, _} = sh(?BUILD ++ "../examples/"
                            ++ Name ++ ".ern"),
                ?assert(filelib:is_regular("build/" ++ Name ++ ".erc"))
            end} || Name <- ?COMPILES]}.

%% Paper program 4 (plan, MVP 2.5): the REPL reads stdin and ends at
%% end of input, so its run is bounded by its input. The last two lines are
%% the point of the program: an expression that does not terminate is killed
%% after two seconds, and the next expression still works.
%% report §6.9 (monitor), §8.2 (Io's stdin), §9.3 (Io.readLine)
repl_test_() ->
    {timeout, 60, fun repl/0}.

repl() ->
    {0, _} = sh(?BUILD ++ "../examples/repl.ern"),
    {0, Out} = sh("../bin/ern run build/repl.erc < input/repl.in"),
    ?assertEqual(expected("repl"), lines(Out)).

%% Paper program 2 (plan, MVP 2.5): the syncer runs until it is
%% stopped, so the harness gives it two prepared directories, lets it run,
%% stops it, and reads the directories back. One file on each side crosses,
%% and the pair that differs leaves a conflict beside the newer copy.
%% report §8.2 (Fs's reference), §6.6 (Address.call), Appendix E.17 (Fs.list)
filesync_test_() ->
    {timeout, 60, fun filesync/0}.

filesync() ->
    {0, _} = sh(?BUILD ++ "../examples/filesync.ern"),
    Dir = "build/filesync",
    ok = reset(Dir),
    ok = file:write_file(Dir ++ "/a/greeting.txt", <<"hello from a\n">>),
    ok = file:write_file(Dir ++ "/b/other.txt", <<"only in b\n">>),
    ok = file:write_file(Dir ++ "/a/notes.txt", <<"old note\n">>),
    ok = file:write_file(Dir ++ "/b/notes.txt", <<"new note\n">>),
    Older = calendar:gregorian_seconds_to_datetime(
              calendar:datetime_to_gregorian_seconds(calendar:local_time()) - 7200),
    ok = file:change_time(Dir ++ "/a/notes.txt", Older),
    {Status, Out} = run_for(Dir, "../../../bin/ern run ../../build/filesync.erc", 4, "TERM"),
    %% report §8.6, §11.2: the signal ends the program as returning from main
    %% does, so what was written is there and the runtime says nothing of its
    %% own, and the status is 128 plus the signal's number
    ?assertEqual(143, Status),
    ?assert(lists:member(<<"conflict: notes.txt">>, Out)),
    ?assertEqual([], [L || L <- Out, binary:match(L, <<"conflict: notes.txt">>) =:= nomatch]),
    ?assertEqual({ok, <<"hello from a\n">>}, file:read_file(Dir ++ "/b/greeting.txt")),
    ?assertEqual({ok, <<"only in b\n">>}, file:read_file(Dir ++ "/a/other.txt")),
    %% b's copy is the newer one, so a takes it and b keeps its own beside the conflict
    ?assertEqual({ok, <<"new note\n">>}, file:read_file(Dir ++ "/a/notes.txt")),
    ?assert(filelib:is_regular(Dir ++ "/b/notes.txt.conflict")).

reset(Dir) ->
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/a"),
    ok = filelib:ensure_path(Dir ++ "/b").

del(Dir) ->
    case file:del_dir_r(Dir) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% A program that runs until it is stopped: started in Dir, stopped after
%% Seconds with the signal named. Its status and its output are returned,
%% standard error with standard output, and not the shell's own report of
%% a job a signal ended.
run_for(Dir, Cmd, Seconds, Signal) ->
    %% sh -c, since open_port runs the command with exec and `cd` is a builtin
    {_, Status} = sh("sh -c 'cd " ++ Dir ++ " && { " ++ Cmd ++ " > run.out 2>&1 & p=$!; sleep "
                     ++ integer_to_list(Seconds) ++ "; kill -" ++ Signal
                     ++ " $p 2>/dev/null; wait $p; echo status $?; }' 2>/dev/null"),
    <<"status ", S/binary>> = string:trim(Status),
    {ok, Out} = file:read_file(filename:join(Dir, "run.out")),
    {binary_to_integer(S), lines(Out)}.

%% report §8.6, §11.2: the host's hangup ends a program as its termination
%% does, printing nothing, with status 128 plus the signal's number. A
%% regression test: the hangup was ignored, and the program ran on.
hangup_test_() ->
    {timeout, 60, fun hangup/0}.

hangup() ->
    Dir = "build/hangup",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() -> Unit with Never =\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    ?assertEqual({129, []}, run_for(Dir, "../../../bin/ern run waits.erc", 2, "HUP")).

%% report §8.6, §11.2: the host's interrupt ends a program at once, printing
%% nothing, with status 128 plus the signal's number. The run is started
%% from here rather than by a shell, which would start it with the
%% interrupt ignored. Written after the code, with the sentence of §11.2
%% that states the status.
interrupt_test_() ->
    {timeout, 60, fun interrupt/0}.

interrupt() ->
    Dir = "build/interrupt",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() -> Unit with Never =\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    Port = open_port({spawn_executable, "../bin/ern"},
                     [{args, ["run", Dir ++ "/waits.erc"]}, exit_status, stderr_to_stdout,
                      binary]),
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    timer:sleep(2000),
    _ = os:cmd("kill -INT " ++ integer_to_list(Pid)),
    ?assertEqual({130, <<>>}, collect(Port, [])).

%% Paper program 1 (plan, MVP 2.5): the server serves until it is
%% stopped, so the harness starts it, makes two requests over one session,
%% and stops it. The second request carries the cookie the first set, and
%% the visit count proves the session store kept it between connections.
%% report §8.2 (Tcp's reference), Appendix E.18 (Tcp), §6.6 (the store's request-reply)
webserver_test_() ->
    {timeout, 60, fun webserver/0}.

webserver() ->
    {0, _} = sh(?BUILD ++ "../examples/webserver.ern"),
    Port = open_port({spawn, "../bin/ern run build/webserver.erc"},
                     [exit_status, stderr_to_stdout, binary]),
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    try
        ?assertEqual(ok, listening(8080, 100)),
        First = request([]),
        ?assertMatch({_, _}, binary:match(First, <<"HTTP/1.1 200 OK">>)),
        ?assertMatch({_, _}, binary:match(First, <<"set-cookie: sid=">>)),
        ?assertMatch({_, _}, binary:match(First, <<"Visit number 1">>)),
        Sid = cookie_of(First),
        Second = request([<<"cookie: sid=", Sid/binary, "\r\n">>]),
        ?assertMatch({_, _}, binary:match(Second, <<"Visit number 2">>))
    after
        os:cmd("kill " ++ integer_to_list(Pid)),
        try port_close(Port) catch _:_ -> true end
    end.

%% The server needs a moment to bind; a connection that is refused is retried.
listening(_, 0) ->
    {error, not_listening};
listening(TcpPort, Tries) ->
    case gen_tcp:connect("127.0.0.1", TcpPort, [binary, {active, false}], 100) of
        {ok, Sock} -> gen_tcp:close(Sock), ok;
        {error, _} -> timer:sleep(100), listening(TcpPort, Tries - 1)
    end.

request(Headers) ->
    {ok, Sock} = gen_tcp:connect("127.0.0.1", 8080, [binary, {active, false}], 1000),
    ok = gen_tcp:send(Sock, [<<"GET / HTTP/1.1\r\nhost: localhost\r\n">>, Headers, <<"\r\n">>]),
    Answer = recv_all(Sock, []),
    gen_tcp:close(Sock),
    Answer.

recv_all(Sock, Acc) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Bin} -> recv_all(Sock, [Bin | Acc]);
        {error, _} -> iolist_to_binary(lists:reverse(Acc))
    end.

cookie_of(Answer) ->
    [_, After] = binary:split(Answer, <<"set-cookie: sid=">>),
    [Sid | _] = binary:split(After, <<";">>),
    Sid.

%% report §11, §11.4: the manual pages `make man` writes. `ern doc --man`
%% writes the prelude's page and each standard library module's beside its
%% .erc; tools/manual.ern writes ern(1), whose NAME line, DESCRIPTION, and
%% subsections are §11's, in the report's order, and whose SEE ALSO names
%% those pages, the prelude's first. Every page renders without a warning:
%% groff checks it where it is installed, with UTF-8 read as man-db reads
%% it, mandoc where groff is not, and a machine with neither says so.
%% Written after the code, a regression test.
manual_pages_test_() ->
    {timeout, 120, fun manual_pages/0}.

manual_pages() ->
    {0, _} = sh("../bin/ern doc --man --build-root ../build/stdlib ../stdlib"),
    Modules = [filename:basename(F, ".ern") || F <- filelib:wildcard("../stdlib/*.ern")],
    Pages = ["../build/stdlib/Ernest." ++ string:titlecase(M) ++ ".3ern" || M <- Modules]
        ++ ["../build/stdlib/Ernest.Prelude.3ern"],
    ?assertEqual([], [P || P <- Pages, not filelib:is_regular(P)]),
    {0, _} = sh("../bin/ern build --load-path ../build/libs/markdown --build-root build/tools "
                "../tools"),
    {0, Out} = sh("../bin/ern run --load-path ../build/libs/markdown build/tools/manual.erc "
                  "../ernest_report.md 9.9.9 ../build/stdlib"),
    ok = file:write_file("build/ern.1", Out),
    Lines = binary:split(Out, <<"\n">>, [global, trim]),
    ?assertMatch([<<".\\\" Generated by tools/manual.ern from ../ernest_report.md.">>,
                  <<".TH \"ern\" \"1\" \"\" \"Ernest 9.9.9\" \"Ernest Manual\"">>,
                  <<".nh">>, <<".ds AD l">>, <<".ad l">>,
                  <<".SH NAME">>, <<"ern \\- the Ernest toolchain">>,
                  <<".SH DESCRIPTION">>, <<".PP">>,
                  <<"The toolchain is one command, \\fBern\\fR, ", _/binary>> | _], Lines),
    {ok, Report} = file:read_file("../ernest_report.md"),
    {match, Sections} = re:run(Report, "^### (11\\.[0-9]+ .*)$",
                               [multiline, global, {capture, all_but_first, binary}]),
    ?assertEqual([binary:replace(S, <<"`">>, <<>>, [global]) || [S] <- Sections],
                 [S || {<<".SS">>, S} <- lists:zip(lists:droplast(Lines), tl(Lines))]),
    ?assertMatch({_, _}, binary:match(Out, <<".SH\nSEE ALSO\n.PP\n\\fBErnest.Prelude\\fR(3ern), "
                                              "\\fBErnest.Bool\\fR(3ern), ">>)),
    ?assertEqual([], [M || M <- Modules,
                           binary:match(Out, iolist_to_binary(["\\fBErnest.", string:titlecase(M),
                                                               "\\fR(3ern)"])) =:= nomatch]),
    rendered(["build/ern.1" | Pages]).

rendered(Pages) ->
    case {os:find_executable("groff"), os:find_executable("mandoc")} of
        {false, false} ->
            io:format(user, "  groff and mandoc not installed; the manual pages' rendering "
                            "was not checked.~n", []);
        {false, _} ->
            ?assertEqual([], [{P, R} || P <- Pages,
                                        {S, _} = R <- [sh("mandoc -Tlint -W error " ++ P)],
                                        S =/= 0]);
        _ ->
            ?assertEqual([], [{P, R} || P <- Pages,
                                        R <- [sh("groff -k -man -Tutf8 -ww -z " ++ P)],
                                        R =/= {0, <<>>}])
    end.

%% docs/install.md, docs/review.md R5: make install writes the tree under a
%% prefix, bin/ern a relative link to its launcher; the prefix moved to
%% another place runs there, `ern`, the shell, a program that runs another
%% through the helper, and `ern doc --man`, and `man` finds ern(1), a
%% module's page and a library's through the path alone. make uninstall
%% removes what was installed and leaves a page of the user's, and refuses
%% where nothing is installed; a DESTDIR stages the same tree, which runs
%% where it is staged; and a prefix that cannot be written is refused with
%% nothing written. No installed module carries the host's debug
%% information. Written with the code.
install_test_() ->
    {timeout, 300, fun install/0}.

install() ->
    Base = filename:absname("build/install"),
    ok = del(Base),
    ok = filelib:ensure_path(Base ++ "/work"),
    {0, _} = sh("make -s -C .. install PREFIX=" ++ Base ++ "/a"),
    ?assertEqual({ok, "../lib/ernest/bin/ern"}, file:read_link(Base ++ "/a/bin/ern")),
    ?assertEqual([], debug_information(Base ++ "/a")),
    ok = file:rename(Base ++ "/a", Base ++ "/b"),
    Ern = Base ++ "/b/bin/ern",
    In = fun(Cmd) -> sh(Cmd, [{cd, Base ++ "/work"}]) end,
    ?assertEqual({0, <<"ern 0.1.0\n">>}, In(Ern ++ " --version")),
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    {0, _} = In(Ern ++ " build hi.ern"),
    ?assertEqual({0, <<"hi\n">>}, In(Ern ++ " run hi.erc")),
    {0, Shell} = In("printf '1 + 1\\n' | " ++ Ern ++ " shell"),
    ?assertMatch({_, _}, binary:match(Shell, <<"> 2 : Int\n">>)),
    ?assertMatch({0, <<".\\\" Generated by ern ", _/binary>>}, In(Ern ++ " doc --man hi.ern")),
    case os:find_executable("man") of
        false ->
            io:format(user, "  man not installed; the installed pages were not looked up.~n", []);
        _ ->
            Man = Base ++ "/b/share/man/",
            ?assertEqual({0, iolist_to_binary([Man, "man1/ern.1\n", Man,
                                               "man3/Ernest.List.3ern\n", Man,
                                               "man3/Ernest.Markdown.3ern\n"])},
                         sh("env -u MANPATH PATH=" ++ Base ++ "/b/bin:/usr/bin:/bin "
                            "man -w ern Ernest.List Ernest.Markdown"))
    end,
    ok = file:write_file(Base ++ "/b/share/man/man3/Mine.3", <<"mine\n">>),
    {0, _} = sh("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b"),
    ?assertEqual([Base ++ "/b/share/man/man3/Mine.3"],
                 [F || F <- filelib:wildcard(Base ++ "/b/**/*"), not filelib:is_dir(F)]),
    ?assertMatch({2, _}, sh("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b")),
    Stage = Base ++ "/stage",
    {0, _} = sh("make -s -C .. install DESTDIR=" ++ Stage ++ " PREFIX=/opt/ernest"),
    ?assertEqual({0, <<"ern 0.1.0\n">>}, In(Stage ++ "/opt/ernest/bin/ern --version")),
    {0, _} = sh("make -s -C .. uninstall DESTDIR=" ++ Stage ++ " PREFIX=/opt/ernest"),
    ?assertEqual([], [F || F <- filelib:wildcard(Stage ++ "/**/*"), not filelib:is_dir(F)]),
    case sh("id -u") of
        {0, <<"0\n">>} ->
            io:format(user, "  run as root; a prefix that cannot be written was not tried.~n", []);
        _ ->
            ok = file:make_dir(Base ++ "/closed"),
            ok = file:change_mode(Base ++ "/closed", 8#555),
            {2, Refused} = sh("make -s -C .. install PREFIX=" ++ Base ++ "/closed/x"),
            ?assertMatch({_, _}, binary:match(Refused, <<"cannot be written">>)),
            ?assertEqual({ok, []}, file:list_dir(Base ++ "/closed")),
            ok = file:change_mode(Base ++ "/closed", 8#755)
    end.

%% docs/install.md: make release writes the archive, the staged tree with
%% the helper as its C source, a Makefile and a README; its make compiles
%% the helper, and its make install installs under a prefix, where a
%% program that runs another through the helper runs, and its make
%% uninstall removes it. Written with the code.
release_test_() ->
    {timeout, 300, fun release/0}.

release() ->
    Base = filename:absname("build/release"),
    ok = del(Base),
    ok = filelib:ensure_path(Base ++ "/work"),
    {0, _} = sh("make -s -C .. release"),
    {ok, Version} = file:read_file("../VERSION"),
    Name = "ern-" ++ string:trim(binary_to_list(Version)),
    Archive = "../build/release/" ++ Name ++ ".tar.gz",
    {0, Listing} = sh("tar -tzf " ++ Archive),
    Entries = binary:split(Listing, <<"\n">>, [global, trim]),
    [?assert(lists:member(list_to_binary(Name ++ "/" ++ F), Entries))
     || F <- ["Makefile", "README.md", "install.sh", "ern_exec.c", "bin/ern",
              "lib/ernest/bin/ern", "lib/ernest/installed", "share/man/man1/ern.1"]],
    ?assertNot(lists:member(list_to_binary(Name ++ "/lib/ernest/erl/runtime/priv/ern_exec"),
                            Entries)),
    {0, _} = sh("tar -xzf " ++ filename:absname(Archive), [{cd, Base}]),
    Unpacked = Base ++ "/" ++ Name,
    {0, _} = sh("make -s install PREFIX=" ++ Base ++ "/p", [{cd, Unpacked}]),
    ?assertEqual([], debug_information(Base ++ "/p")),
    Ern = Base ++ "/p/bin/ern",
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    {0, _} = sh(Ern ++ " build hi.ern", [{cd, Base ++ "/work"}]),
    ?assertEqual({0, <<"hi\n">>}, sh(Ern ++ " run hi.erc", [{cd, Base ++ "/work"}])),
    {0, _} = sh("make -s uninstall PREFIX=" ++ Base ++ "/p", [{cd, Unpacked}]),
    ?assertEqual([], [F || F <- filelib:wildcard(Base ++ "/p/**/*"), not filelib:is_dir(F)]).

%% A program that runs another through the runtime's helper (Appendix E.23).
runs_echo() ->
    "export fn main() -> Unit with Never = match Os.run(Os.Command(\n"
    "    program = \"echo\", arguments = [\"hi\"], input = <<>>), 5000) {\n"
    "    Right(Os.Finished(stdout = out)) -> Io.print(Optional.withDefault(\n"
    "        String.fromUtf8(out), \"\"))\n"
    "  | Left(e) -> Io.println(Io.show(e))\n"
    "}\n".

%% The modules under a directory that carry the host's debug information.
debug_information(Dir) ->
    [F || F <- filelib:wildcard(Dir ++ "/**/*.{beam,erc}"),
          begin
              {ok, Beam} = file:read_file(F),
              {ok, _, Chunks} = beam_lib:all_chunks(Beam),
              lists:keymember("Dbgi", 1, Chunks)
          end].

%% report §9.3, plan MVP 3.2: every library's own tests, run by `ern test`
%% over its compiled modules, as the shell's are
libs_test_() ->
    {timeout, 60, fun libs/0}.

libs() ->
    Modules = filelib:wildcard("../build/libs/*/**/*.erc"),
    ?assert(lists:any(fun(M) -> filename:basename(M) =:= "markdown.erc" end, Modules)),
    Runs = ["../bin/ern test " ++ M || M <- Modules],
    {Status, Out} = sh(lists:flatten(lists:join(" && ", Runs))),
    Lines = [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    ?assertEqual([], [L || L <- Lines, binary:match(L, <<": passed">>) =:= nomatch]),
    ?assertEqual(0, Status).

%% report §8.2, §7.4, Appendix E.1: standard input is UTF-8 whatever the
%% host's locale, a line without its line feed or the carriage return
%% before it, a last line without a line feed; a line that is not UTF-8
%% faults; lines and bytes are one stream, and bytes go out as they are
stdin_test_() ->
    {timeout, 60, fun stdin/0}.

stdin() ->
    [{0, _} = sh("../bin/ern build --source-root stdin --build-root build/stdin stdin/"
                 ++ P ++ ".ern") || P <- ["lines", "stream", "chunks"]],
    Run = fun(Input, Program) ->
                  sh("printf '" ++ Input ++ "' | LANG=C ../bin/ern run build/stdin/"
                     ++ Program ++ ".erc")
          end,
    ?assertEqual({0, <<"[h", 16#e9/utf8, "] 2\n[zw", 16#4e2d/utf8, "] 3\n[] 0\n[last] 4\nend\n">>},
                 Run("h\\303\\251\\r\\nzw\\344\\270\\255\\n\\nlast", "lines")),
    %% standard output and standard error are two streams, which nothing
    %% orders against each other, so each is compared alone
    Err = "build/stdin/stderr",
    ?assertEqual({1, <<"[ok] 2\n">>},
                 sh("printf 'ok\\n\\377\\nnext\\n' | LANG=C ../bin/ern run build/stdin/lines.erc 2>"
                    ++ Err)),
    {ok, Said} = file:read_file(Err),
    ?assertEqual([<<"Lines.main faulted: the standard input is not UTF-8">>],
                 unstamped(lines(Said))),
    ?assertEqual({0, <<"head\n", 255, 16#e9/utf8, "tail\nbytes 8\n">>},
                 Run("head\\n\\377\\303\\251tail\\n", "stream")),
    %% a read does not wait for more than has arrived: the second byte is
    %% written once the program has said it read the first, so that how long
    %% the host takes to start, about as long as the one second the writer
    %% had paused, plays no part (it had failed when the start took longer)
    ?assertEqual({0, <<"1\n1\nend\n">>},
                 sh("sh -c 'rm -f build/stdin/in build/stdin/out; mkfifo build/stdin/in; "
                    "../bin/ern run build/stdin/chunks.erc < build/stdin/in > build/stdin/out & "
                    "exec 3> build/stdin/in; printf a >&3; n=0; "
                    "until grep -q 1 build/stdin/out || [ $n -ge 400 ]; "
                    "do sleep 0.05; n=$((n + 1)); done; "
                    "printf b >&3; exec 3>&-; wait; cat build/stdin/out'")).

%% report §11.2, Appendix E.23, E.17: as the host gives them, under a UTF-8
%% locale and under C, whose names the host takes as bytes: `ern run`
%% refuses an argument that is not UTF-8 by its position, the environment
%% leaves out a value that is not UTF-8, and ern run exits with the status
%% Os.exit gives. A regression test, written after the code; where the host
%% has no C.UTF-8 locale both runs read bytes, and a name the environment
%% gives twice is not covered, since a shell cannot give one.
os_test_() ->
    {timeout, 60, fun os/0}.

os() ->
    Src = "build/os/src",
    ok = filelib:ensure_path(Src),
    ok = file:write_file(Src ++ "/args.ern",
                         "export fn main() -> Unit with Never = {\n"
                         "    Io.println(Io.show(Os.arguments));\n"
                         "    Os.exit(List.size(Os.arguments))\n"
                         "}\n"),
    ok = file:write_file(Src ++ "/env.ern",
                         "fn get(name : String) -> Optional(String) =\n"
                         "    Map.get(Os.environment, name)\n"
                         "export fn main() -> Unit with Never =\n"
                         "    Io.println(Io.show(#(get(\"ERN_OK\"), get(\"ERN_BAD\"))))\n"),
    {0, _} = sh("../bin/ern build --source-root build/os/src --build-root build/os build/os/src"),
    lists:foreach(
      fun(Locale) ->
              Run = "env LC_ALL=" ++ Locale ++ " ../bin/ern run build/os/",
              ?assertEqual({2, <<"[\"a b\", \"--x\"]\n">>}, sh(Run ++ "args.erc 'a b' --x")),
              ?assertEqual({1, <<"ern run: argument 2 is not UTF-8\n">>},
                           sh(Run ++ "args.erc ok \"$(printf '\\377')\"")),
              ?assertEqual({0, <<"#(Some(\"caf", 16#e9/utf8, "\"), None)\n">>},
                           sh("env ERN_OK=\"$(printf 'caf\\303\\251')\" "
                              "ERN_BAD=\"$(printf 'caf\\351')\" " ++ Run ++ "env.erc"))
      end, ["C.UTF-8", "C"]).

%% report §11, Appendix E.23, E.17: Os.workingDirectory is the absolute
%% path of the directory the program was started in, a relative path
%% given to Fs names a file under it, and ern refuses to start where the
%% directory's name is not UTF-8, in every locale: the launcher refuses
%% before the host starts, which under a UTF-8 locale hung as it booted.
%% Written with the code; a directory removed as the program starts is not
%% covered.
working_directory_test_() ->
    {timeout, 60, fun working_directory/0}.

working_directory() ->
    Dir = "build/cwd",
    ok = filelib:ensure_path(Dir ++ "/src"),
    ok = file:write_file(Dir ++ "/src/here.ern",
                         "export fn main() -> Unit with Never = {\n"
                         "    Io.println(Path.toString(Os.workingDirectory));\n"
                         "    match Fs.read(Path(\"notes.txt\"), 1000) {\n"
                         "        Right(bytes) -> Io.println(Io.show(String.fromUtf8(bytes)))\n"
                         "      | Left(_) -> Io.println(\"no notes\")\n"
                         "    }\n"
                         "}\n"),
    {0, _} = sh("../bin/ern build --source-root build/cwd/src --build-root build/cwd "
                "build/cwd/src"),
    Cafe = <<"build/cwd/caf", 16#c3, 16#a9>>,
    [ok = make_dir(D) || D <- [Cafe, <<"build/cwd/bad", 16#e9>>]],
    ok = file:write_file(<<Cafe/binary, "/notes.txt">>, <<"buy milk">>),
    Run = fun(Glob, Locale) ->
                  sh("sh -c 'cd build/cwd/" ++ Glob ++ " && env LC_ALL=" ++ Locale ++ " "
                     ++ filename:absname("../bin/ern") ++ " run "
                     ++ filename:absname("build/cwd/here.erc") ++ "'")
          end,
    Here = <<(list_to_binary(filename:absname("build/cwd")))/binary, "/caf", 16#c3, 16#a9>>,
    [?assertEqual({0, <<Here/binary, "\nSome(\"buy milk\")\n">>}, Run("caf*", Locale))
     || Locale <- ["C.UTF-8", "C"]],
    [?assertEqual({1, <<"ern: the working directory's name is not UTF-8\n">>}, Run("bad*", Locale))
     || Locale <- ["C.UTF-8", "C"]],
    %% the name other tests' wildcards cannot read, which the host warns of
    ok = file:del_dir(<<"build/cwd/bad", 16#e9>>).

make_dir(Dir) ->
    case file:make_dir(Dir) of
        {error, eexist} -> ok;
        Other -> Other
    end.

%% report §8.2, §8.6, §11.2: a run whose standard output has lost its
%% reader ends at once, with status 141, as a shell reports a broken pipe,
%% and the host says nothing of its own. A regression test, written after
%% the code: the run went on to its end and then hung, and the host printed
%% its report of the failed write among the program's output.
stream_gone_test_() ->
    {timeout, 60, fun stream_gone/0}.

stream_gone() ->
    Dir = "build/gone",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/chatty.ern",
                         "fn loop(n : Int) -> Unit with Never =\n"
                         "    if n == 0 then Io.printlnError(\"finished\")\n"
                         "    else { Io.println(\"line\"); loop(n - 1) }\n"
                         "export fn main() -> Unit with Never = loop(100000000)\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/chatty.ern"),
    {0, Out} = sh("sh -c '{ ../bin/ern run " ++ Dir ++ "/chatty.erc 2> " ++ Dir
                  ++ "/err; echo $? > " ++ Dir ++ "/status; } | head -1'"),
    ?assertEqual(<<"line\n">>, Out),
    ?assertEqual({ok, <<"141\n">>}, file:read_file(Dir ++ "/status")),
    ?assertEqual({ok, <<>>}, file:read_file(Dir ++ "/err")).

%% report §8.2: a program writing faster than its reader reads is held to
%% the reader's pace, so what it has written and the reader has not taken
%% is not held in the node. A regression test, written after the code: two
%% million lines to a pipe read late held about 650 MB, where the node
%% itself takes under 100.
paced_output_test_() ->
    {timeout, 60, fun paced_output/0}.

paced_output() ->
    Dir = "build/paced",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/flood.ern",
                         "fn loop(n : Int) -> Unit with Never =\n"
                         "    if n == 0 then Unit\n"
                         "    else { Io.println(\"a line of output a slow reader takes late\");\n"
                         "        loop(n - 1) }\n"
                         "export fn main() -> Unit with Never = loop(2000000)\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/flood.ern"),
    {0, Out} = sh("sh -c '../bin/ern run " ++ Dir ++ "/flood.erc | { sleep 4; cat > /dev/null; } & "
                  "sleep 3; ps -eo rss,comm,args | grep \"beam.smp.*[f]lood.erc\" | head -1; "
                  "wait'"),
    [Rss | _] = string:lexemes(binary_to_list(Out), " \n"),
    ?assert(list_to_integer(Rss) < 250000).

%% report §11.2: where standard error is a file, a fault line begins with
%% the time, in UTC as RFC 3339 writes it; where it is a service manager's
%% journal, as JOURNAL_STREAM names it, it does not, and a terminal's is
%% ern_terminal_tests' to show. Written with the code.
stamped_test_() ->
    {timeout, 60, fun stamped/0}.

stamped() ->
    Dir = "build/stamped",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/faulty.ern",
                         "export fn main() -> Unit with Never = {\n"
                         "    let z = List.size([]);\n"
                         "    let _ = 1 / z;\n"
                         "    Unit\n"
                         "}\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/faulty.ern"),
    Err = Dir ++ "/err",
    {1, _} = sh("../bin/ern run " ++ Dir ++ "/faulty.erc 2> " ++ Err),
    {ok, Stamped} = file:read_file(Err),
    ?assertMatch({match, _}, re:run(Stamped, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:"
                                              "[0-9]{2}\\.[0-9]{3}Z Faulty\\.main faulted: "
                                              "division by zero\n$")),
    ok = file:write_file(Err, <<>>),
    {ok, #file_info{major_device = Device, inode = Inode}} = file:read_file_info(Err),
    {1, _} = sh("env JOURNAL_STREAM=" ++ integer_to_list(Device) ++ ":" ++ integer_to_list(Inode)
                ++ " ../bin/ern run " ++ Dir ++ "/faulty.erc 2> " ++ Err),
    ?assertEqual({ok, <<"Faulty.main faulted: division by zero\n">>}, file:read_file(Err)).

%% report §8.6, §11.2: the host's termination and hangup end `ern run` by the
%% signal itself once its output is flushed, so that the process that started
%% it sees a signal's end, as a service manager counts a stop it asked for.
%% A regression test, written after the code: it exited with 128 plus the
%% signal's number, which a shell reads the same and a service manager as a
%% failure.
signal_end_test_() ->
    {timeout, 60, fun signal_end/0}.

signal_end() ->
    Dir = "build/hangup",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() -> Unit with Never =\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    Python = "import subprocess, time, signal\n"
             "for s in (signal.SIGTERM, signal.SIGHUP):\n"
             "    p = subprocess.Popen(['../bin/ern', 'run', '" ++ Dir ++ "/waits.erc'])\n"
             "    time.sleep(2)\n"
             "    p.send_signal(s)\n"
             "    print(p.wait(timeout=30))\n",
    ok = file:write_file(Dir ++ "/signals.py", Python),
    ?assertEqual({0, <<"-15\n-1\n">>}, sh("python3 " ++ Dir ++ "/signals.py")).

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test() ->
    {0, _} = sh("../bin/ern build --build-root build/modules ../examples/modules"),
    {0, Out} = sh("../bin/ern run build/modules/main.erc"),
    ?assertEqual(expected("modules"), lines(Out)).

%% report §11.6: `ern format -` lays out standard input onto standard
%% output; with --check it names `-` if the module is not laid out; a
%% module that does not parse gives its diagnostic under the name `-`, the
%% status 1, and nothing else. A regression test, written after the code.
format_input_test() ->
    Loose = "sh -c 'printf \"fn f(x) = x+1\\n\" | ../bin/ern format ",
    ?assertEqual({0, <<"fn f(x) =\n    x + 1\n">>}, sh(Loose ++ "-'")),
    ?assertEqual({1, <<"-\n">>}, sh(Loose ++ "--check -'")),
    ?assertEqual({1, <<"-:1:7: expected a pattern instead of `=`\n">>},
                 sh("sh -c 'printf \"fn h( = 1\\n\" | ../bin/ern format --short-errors -'")).

expected(Name) ->
    {ok, Bin} = file:read_file("expected/" ++ Name ++ ".out"),
    lines(Bin).

lines(Bin) ->
    lists:sort(binary:split(Bin, <<"\n">>, [global, trim])).

%% Report §11.2: `ern run`'s fault lines as a terminal shows them, without
%% the time a line begins with where standard error is a file or a pipe,
%% as it is here; stamped_test_ checks the time itself.
unstamped(Lines) ->
    lists:sort([re:replace(L, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z ", "", [{return, binary}])
                || L <- Lines]).

sh(Cmd) ->
    sh(Cmd, []).

sh(Cmd, Options) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary | Options]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
