%% The toolchain as a user runs it, through bin/ern: the examples and the
%% test programs built and run, their output compared as a multiset of lines with
%% expected/<name>.out, since prints from different processes interleave
%% by scheduling; the launcher, the signals and the streams; `Os`; the
%% manual pages against §11; the installation and the release archive; the
%% libraries' tests; and proposals/operations/programs/. Run from this
%% directory by its Makefile.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% Report §11.1: an example compiled into test/build.
%% libs/ansi, which snake writes with (report Appendix G.3)
-define(BUILD, "--source-root ../examples --load-path ../build/libs/ansi --build-root build ").

%% A program kept for the tests, compiled into test/build.
-define(BUILD_PROGRAM, "--source-root programs --build-root build ").

%% The examples that end of themselves, and the programs kept for the tests.
-define(EXAMPLES, ["hello", "services", "word_count", "shout", "typed_channels",
                   "typed_channels_nodes"]).
-define(PROGRAMS, ["counter", "upgrade", "pingpong", "stack", "patterns", "kv_parser"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (pingpong),
%% §6.6 (counter), §6.10 (upgrade), §5.10 (patterns),
%% §5.5 (kv_parser), §4.4 (stack), Appendix E.22 (services), §4.9 and §5.6
%% (word_count), Appendix E.18 (shout), §6.1, §6.3, §6.5, §6.6
%% (typed_channels), §8.7 (typed_channels_nodes, run alone, which is no
%% node, its find answering NotListed); the last two are regression tests
%% written with them, which run none of the refused lines their comments
%% quote
%% Each program is compiled and run apart from the others, so they run in
%% parallel (plan, MVP 2.6).
programs_test_() ->
    {inparallel,
     [{Name, {timeout, 60, fun() -> program(?BUILD ++ "../examples/", Name) end}}
      || Name <- ?EXAMPLES]
     ++ [{Name, {timeout, 60, fun() -> program(?BUILD_PROGRAM ++ "programs/", Name) end}}
         || Name <- ?PROGRAMS]}.

program(Build, Name) ->
    0 = build(Build ++ Name ++ ".ern"),
    {0, Output} = sh("../bin/ern run build/" ++ Name ++ ".erc"),
    ?assertEqual(expected(Name), unstamped(lines(Output))).

%% Plan, MVP 2.5: the examples that the doors of step 4 opened. snake
%% waits for a terminal, so it is only compiled here and ern_terminal_tests
%% plays it under a pseudo-terminal; the others run below. The echo
%% measurement, kept for the tests, prints timings, so it is compiled alone.
-define(COMPILES, ["file_sync", "repl", "snake", "web_server"]).

compiles_test_() ->
    {inparallel,
     [{Name, {timeout, 60, fun() -> compiles(?BUILD ++ "../examples/", Name) end}}
      || Name <- ?COMPILES]
     ++ [{"echo", {timeout, 60, fun() -> compiles(?BUILD_PROGRAM ++ "programs/", "echo") end}}]}.

compiles(Build, Name) ->
    0 = build(Build ++ Name ++ ".ern"),
    ?assert(filelib:is_regular("build/" ++ Name ++ ".erc")).

%% report §8.1, §8.6, Appendix E.17, E.23: tally counts the files its
%% command line names, a total last; a file it cannot read is named on
%% standard error and the status is 1; with no file it says how it is
%% called and the status is 2. A regression test, written with the example
tally_test_() ->
    {timeout, 60, fun tally/0}.

tally() ->
    0 = build(?BUILD ++ "../examples/tally.ern"),
    ?assertEqual({0, <<"2 5 24 input/two_lines.txt\n2 5 24 total\n">>},
                 sh("../bin/ern run build/tally.erc input/two_lines.txt")),
    ?assertEqual({1, <<"tally: input/absent.txt: no such file\n"
                       "2 5 24 input/two_lines.txt\n2 5 24 total\n">>},
                 sh("../bin/ern run build/tally.erc input/absent.txt input/two_lines.txt")),
    ?assertEqual({2, <<"usage: tally file...\n">>}, sh("../bin/ern run build/tally.erc")).

%% report §8.2, E.16: without a terminal snake has no keys, so it says so
%% and ends with status 1 before it draws. A regression test: it drew a
%% frame and ended with status 0
snake_without_terminal_test_() ->
    {timeout, 60,
     fun() ->
         0 = build(?BUILD ++ "../examples/snake.ern"),
         ?assertEqual({1, <<"snake needs a terminal, since its keys are the game's input\n">>},
                      sh("../bin/ern run --load-path ../build/libs/ansi build/snake.erc"
                         " < /dev/null"))
     end}.

%% snake's own tests: two turns within a tick do not reverse the last move,
%% and an apple goes on a free cell. Regression tests: two quick keys made
%% a U-turn that killed the snake, and an apple could land on the snake
snake_own_tests_test_() ->
    {timeout, 60,
     fun() ->
         0 = build("--source-root ../examples --load-path ../build/libs/ansi"
                   " --build-root build/snake_own ../examples/snake.ern"),
         {0, Output} = sh("../bin/ern test --load-path ../build/libs/ansi"
                          " build/snake_own/snake.erc"),
         Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
         ?assertEqual(2, length([Line || Line <- Lines,
                                         binary:match(Line, <<": passed">>) =/= nomatch]))
     end}.

%% Paper program 4 (plan, MVP 2.5): the REPL reads stdin and ends at
%% end of input, so its run is bounded by its input. The last two lines are
%% the point of the program: an expression that does not terminate is killed
%% after two seconds, and the next expression still works.
%% report §6.9 (monitor), §8.2 (Io's stdin), Appendix E.1 (Io.readLine)
repl_test_() ->
    {timeout, 60, fun repl/0}.

repl() ->
    0 = build(?BUILD ++ "../examples/repl.ern"),
    {0, Output} = sh("../bin/ern run build/repl.erc < input/repl.in"),
    ?assertEqual(expected("repl"), lines(Output)).

%% Paper program 2 (plan, MVP 2.5): the syncer runs until it is
%% stopped, so the harness gives it two prepared directories, lets it run,
%% stops it, and reads the directories back. One file on each side crosses,
%% and the pair that differs leaves a conflict beside the newer copy.
%% report §8.2 (Fs's reference), §6.6 (Address.call), Appendix E.17 (Fs.list)
file_sync_test_() ->
    {timeout, 60, fun file_sync/0}.

file_sync() ->
    0 = build(?BUILD ++ "../examples/file_sync.ern"),
    %% its own tests: a peer's path is stored only where it names a file in
    %% the directory, a regression test: a peer's `../x` was written outside
    %% it
    ?assertEqual({0, <<"a peer's path is stored only where it names a file here: passed\n">>},
                 sh("../bin/ern test build/file_sync.erc")),
    Dir = "build/file_sync",
    ok = reset(Dir),
    ok = file:write_file(Dir ++ "/a/greeting.txt", <<"hello from a\n">>),
    ok = file:write_file(Dir ++ "/b/other.txt", <<"only in b\n">>),
    ok = file:write_file(Dir ++ "/a/notes.txt", <<"old note\n">>),
    ok = file:write_file(Dir ++ "/b/notes.txt", <<"new note\n">>),
    ok = make_older(Dir ++ "/a/notes.txt"),
    %% stopped once both directories are as the checks below read them,
    %% since how long a pass takes is the host's
    Synced = "grep -q \"conflict: notes.txt\" run.out && [ -f b/greeting.txt ]"
             " && [ -f a/other.txt ] && [ -f b/notes.txt.conflict ]"
             " && grep -q \"new note\" a/notes.txt",
    {Status, Output} = run_for(Dir, "../../../bin/ern run ../../build/file_sync.erc", Synced,
                               "TERM"),
    %% report §8.6, §11.2: the signal ends the program as returning from main
    %% does, so what was written is there and the runtime says nothing of its
    %% own, and the status is 128 plus the signal's number
    ?assertEqual(143, Status),
    ?assert(lists:member(<<"conflict: notes.txt">>, Output)),
    ?assertEqual([],
                 [Line || Line <- Output,
                          binary:match(Line, <<"conflict: notes.txt">>) =:= nomatch]),
    ?assertEqual({ok, <<"hello from a\n">>}, file:read_file(Dir ++ "/b/greeting.txt")),
    ?assertEqual({ok, <<"only in b\n">>}, file:read_file(Dir ++ "/a/other.txt")),
    %% b's copy is the newer one, so a takes it and b keeps its own beside the conflict
    ?assertEqual({ok, <<"new note\n">>}, file:read_file(Dir ++ "/a/notes.txt")),
    ?assert(filelib:is_regular(Dir ++ "/b/notes.txt.conflict")),
    %% a file stored takes its source's time, so that the next pass finds it
    %% as it was recorded and does not send it back; a regression test, the
    %% two sides rewrote each other every pass
    Mtime = fun(Relative) ->
                {ok, #file_info{mtime = Seconds}} = file:read_file_info(Dir ++ Relative,
                                                                        [{time, posix}]),
                Seconds
            end,
    ?assertEqual(Mtime("/a/greeting.txt"), Mtime("/b/greeting.txt")),
    ?assertEqual(Mtime("/b/other.txt"), Mtime("/a/other.txt")).

%% file_sync: a file from the peer is checked against the file here as it
%% stands when the file arrives, before the first listing too. A regression
%% test, written after the fix (plan, MVP 2.99b's item 1): b's listing,
%% slowed by fifty files more, came after a's older notes.txt, which then
%% replaced b's newer copy with no conflict. It does not reach a file
%% changed here between two listings, which the same reading covers.
file_sync_first_listing_test_() ->
    {timeout, 60, fun file_sync_first_listing/0}.

file_sync_first_listing() ->
    %% a build root of its own, since file_sync_test_ builds beside it
    0 = build("--source-root ../examples --build-root build/first ../examples/file_sync.ern"),
    Dir = "build/file_sync_first",
    ok = reset(Dir),
    ok = file:write_file(Dir ++ "/a/notes.txt", <<"old note\n">>),
    ok = file:write_file(Dir ++ "/b/notes.txt", <<"new note\n">>),
    [ok = file:write_file(Dir ++ "/b/" ++ integer_to_list(Number) ++ ".txt", <<"x\n">>)
     || Number <- lists:seq(1, 50)],
    ok = make_older(Dir ++ "/a/notes.txt"),
    Synced = "grep -q \"conflict: notes.txt\" run.out && [ -f b/notes.txt.conflict ]"
             " && grep -q \"new note\" a/notes.txt",
    {Status, Output} = run_for(Dir, "../../../bin/ern run ../first/file_sync.erc", Synced, "TERM"),
    ?assertEqual(143, Status),
    ?assert(lists:member(<<"conflict: notes.txt">>, Output)),
    ?assertEqual({ok, <<"new note\n">>}, file:read_file(Dir ++ "/b/notes.txt")),
    ?assertEqual({ok, <<"old note\n">>}, file:read_file(Dir ++ "/b/notes.txt.conflict")),
    ?assertEqual({ok, <<"new note\n">>}, file:read_file(Dir ++ "/a/notes.txt")).

reset(Dir) ->
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/a"),
    ok = filelib:ensure_path(Dir ++ "/b").

%% The file's modification time set two hours back, so that its copy in the
%% other directory is the newer.
make_older(File) ->
    Older = calendar:gregorian_seconds_to_datetime(
              calendar:datetime_to_gregorian_seconds(calendar:local_time()) - 7200),
    file:change_time(File, Older).

del(Dir) ->
    case file:del_dir_r(Dir) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% A program that runs until it is stopped: started in Dir, and stopped with
%% the signal named once the shell condition Until holds, or after thirty
%% seconds. Its status and its output are returned, standard error with
%% standard output, and not the shell's own report of a job a signal ended.
run_for(Dir, Command, Until, Signal) ->
    %% sh -c, since open_port runs the command with exec and `cd` is a builtin
    %% an earlier run's output goes first, since the command empties the
    %% file only once it has started, and Until may read it before then
    {_, Printed} = sh("sh -c 'cd " ++ Dir ++ " && { rm -f run.out; " ++ Command
                     ++ " > run.out 2>&1 & p=$!; "
                     "i=0; until " ++ Until ++ " || [ $i -ge 300 ]; do sleep 0.1; i=$((i + 1)); "
                     "done; kill -" ++ Signal
                     ++ " $p 2>/dev/null; wait $p; echo status $?; }' 2>/dev/null"),
    <<"status ", Digits/binary>> = string:trim(Printed),
    {ok, Output} = file:read_file(filename:join(Dir, "run.out")),
    {binary_to_integer(Digits), lines(Output)}.

%% report §8.6, §11.2: the host's hangup ends a program as its termination
%% does, printing nothing, with status 128 plus the signal's number. A
%% regression test: the hangup was ignored, and the program ran on. The
%% hangup is sent once the program has said it runs, as signal_end's are.
hangup_test_() ->
    {timeout, 60, fun hangup/0}.

hangup() ->
    Dir = "build/hangup",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(\"running\");\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    ?assertEqual({129, [<<"running">>]},
                 run_for(Dir, "../../../bin/ern run waits.erc", "grep -q running run.out",
                         "HUP")).

%% report §10, §11.8: a program that exhausts the host's memory ends at
%% once, the process that monitored the one that grew never told, with
%% status 1 and the host's message, and no crash dump is left in the
%% working directory. The limit is the shell's on the virtual memory, which
%% the host meets within a second. A regression test of the full review's
%% U1 (2026-10-04): the guide called it a fault of one process, and the host
%% wrote its dump where the program ran. Under `make sanitize` the helper is
%% built with the address sanitizer, whose shadow memory no limit on the
%% virtual memory admits, so the helper itself fails at start; the test
%% runs where the helper is the plain build, in `make test`
out_of_memory_test_() ->
    case os:getenv("ASAN_OPTIONS") of
        false -> {timeout, 60, fun out_of_memory/0};
        _ -> []
    end.

out_of_memory() ->
    Dir = "build/out_of_memory",
    ok = filelib:ensure_path(Dir),
    _ = file:delete(Dir ++ "/erl_crash.dump"),
    ok = file:write_file(Dir ++ "/grows.ern",
                         "type Msg = Ended(Down)\n"
                         "fn grow(list : List(Int)) : Unit = grow(List.range(1, 1000) <> list)\n"
                         "export fn main() : Unit with Msg = {\n"
                         "    let _ = spawnMonitored(fn() = grow([]), Ended);\n"
                         "    receive { Ended(_) -> Io.println(\"main was told\") }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/grows.ern"),
    {Status, Output} = sh("sh -c 'cd " ++ Dir ++ " && ulimit -v 3000000"
                          " && ../../../bin/ern run grows.erc'"),
    ?assertEqual(1, Status),
    ?assertMatch({_, _}, binary:match(Output, <<"Cannot allocate">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"main was told">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/erl_crash.dump")).

%% report §8.6, §11.2: the host's interrupt ends a running program at once,
%% printing nothing of its own, with status 128 plus the signal's number.
%% The run is started from here rather than by a shell, which would start
%% it with the interrupt ignored, and interrupted once the program says that
%% it runs, waiting then on a read of its input, which can still deliver.
%% An interrupt that comes while the host starts a port, as it does twice
%% before `main`, leaves a line of OTP's helper on standard error, a defect
%% of OTP's, docs/otp_bugs.md's report 1, a signal that ends the host while
%% it starts a port, and is not covered here. Written after the code, with
%% the sentence of §11.2 that states the status.
interrupt_test_() ->
    {timeout, 60, fun interrupt/0}.

interrupt() ->
    Dir = "build/interrupt",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(\"running\");\n"
                         "    let _ = Io.readLine();\n"
                         "    Io.println(\"late\")\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    Program = open_port({spawn_executable, filename:absname("../bin/ern")},
                        [{args, ["run", "waits.erc"]}, {cd, Dir}, exit_status, stderr_to_stdout,
                         binary]),
    {os_pid, OsPid} = erlang:port_info(Program, os_pid),
    ok = said_line(Program, <<"running\n">>, <<>>),
    _ = os:cmd("kill -INT " ++ integer_to_list(OsPid)),
    ?assertEqual({130, <<>>}, collect(Program, [])).

%% Paper program 1 (plan, MVP 2.5): the server serves until it is
%% stopped, so the harness starts it, makes two requests over one session,
%% and stops it. The second request carries the cookie the first set, and
%% the visit count proves the session store kept it between connections.
%% report §8.2 (Tcp's reference), Appendix E.18 (Tcp), §6.6 (the store's request-reply)
web_server_test_() ->
    {timeout, 60, fun web_server/0}.

web_server() ->
    0 = build(?BUILD ++ "../examples/web_server.ern"),
    Server = open_port({spawn, "../bin/ern run build/web_server.erc"},
                       [exit_status, stderr_to_stdout, binary]),
    {os_pid, OsPid} = erlang:port_info(Server, os_pid),
    try
        %% the server says so once it listens
        ?assertEqual(ok, said_line(Server, <<"listening on 127.0.0.1:8080">>, <<>>)),
        First = request([]),
        ?assertMatch({_, _}, binary:match(First, <<"HTTP/1.1 200 OK">>)),
        ?assertMatch({_, _}, binary:match(First, <<"set-cookie: sid=">>)),
        ?assertMatch({_, _}, binary:match(First, <<"Visit number 1">>)),
        SessionId = cookie_of(First),
        Second = request([<<"cookie: sid=", SessionId/binary, "\r\n">>]),
        ?assertMatch({_, _}, binary:match(Second, <<"Visit number 2">>))
    after
        os:cmd("kill " ++ integer_to_list(OsPid)),
        try port_close(Server) catch _:_ -> true end
    end.

%% Until the program the port runs has written Line; 30 seconds bound a
%% failure.
said_line(Port, Line, Said) ->
    case binary:match(Said, Line) of
        nomatch ->
            receive {Port, {data, Bytes}} -> said_line(Port, Line, <<Said/binary, Bytes/binary>>)
            after 30000 -> {error, {not_said, Said}}
            end;
        _ ->
            ok
    end.

request(Headers) ->
    {ok, Socket} = gen_tcp:connect("127.0.0.1", 8080, [binary, {active, false}], 1000),
    ok = gen_tcp:send(Socket, [<<"GET / HTTP/1.1\r\nhost: localhost\r\n">>, Headers, <<"\r\n">>]),
    Answer = recv_all(Socket, []),
    gen_tcp:close(Socket),
    Answer.

recv_all(Socket, Acc) ->
    case gen_tcp:recv(Socket, 0, 5000) of
        {ok, Bytes} -> recv_all(Socket, [Bytes | Acc]);
        {error, _} -> iolist_to_binary(lists:reverse(Acc))
    end.

cookie_of(Answer) ->
    [_, After] = binary:split(Answer, <<"set-cookie: sid=">>),
    [SessionId | _] = binary:split(After, <<";">>),
    SessionId.

%% report §11, §11.4: the manual pages `make man` writes. `ern doc --man`
%% writes the prelude's page and each standard library module's beside its
%% .erc; tools/manual.ern writes ern(1), whose NAME line, DESCRIPTION, and
%% subsections are §11's, in the report's order, whose SYNOPSIS holds every
%% job's usage line, whose OPTIONS and EXIT STATUS are §11.7 and §11.8, and
%% whose SEE ALSO names those pages, the prelude's first. Every page renders without a warning:
%% groff checks it where it is installed, with UTF-8 read as man-db reads
%% it, mandoc where groff is not, and a machine with neither says so.
%% Written after the code, a regression test.
manual_pages_test_() ->
    {timeout, 120, fun manual_pages/0}.

manual_pages() ->
    {0, _} = sh("../bin/ern doc --man --build-root ../build/stdlib ../stdlib"),
    Modules = [filename:basename(File, ".ern") || File <- filelib:wildcard("../stdlib/*.ern")],
    Pages = ["../build/stdlib/Ernest." ++ ern_namespace:text(ern_namespace:namespace([Module]))
             ++ ".3ern" || Module <- Modules]
        ++ ["../build/stdlib/Ernest.Prelude.3ern"],
    ?assertEqual([], [Page || Page <- Pages, not filelib:is_regular(Page)]),
    0 = build("--load-path ../build/libs/markdown --load-path ../build/libs/ansi "
              "--build-root build/tools ../tools"),
    {0, Output} = sh("../bin/ern run --load-path ../build/libs/markdown"
                     " --load-path ../build/libs/ansi build/tools/manual.erc "
                     "../report/toolchain.md 9.9.9 ../build/stdlib"),
    ok = file:write_file("build/ern.1", Output),
    Lines = binary:split(Output, <<"\n">>, [global, trim]),
    ?assertMatch([<<".\\\" Generated by tools/manual.ern from ../report/toolchain.md.">>,
                  <<".TH \"ern\" \"1\" \"\" \"Ernest 9.9.9\" \"Ernest Manual\"">>,
                  <<".nh">>, <<".ds AD l">>, <<".ad l">>,
                  <<".SH NAME">>, <<"ern \\- the Ernest toolchain">>,
                  <<".SH">>, <<"SYNOPSIS">>, <<".PP">>, <<"\\fBern \\-\\-help\\fR">> | _], Lines),
    Pairs = lists:zip(lists:droplast(Lines), tl(Lines)),
    %% man-pages(7)'s sections, in its order
    ?assertEqual([<<"SYNOPSIS">>, <<"DESCRIPTION">>, <<"OPTIONS">>, <<"EXIT STATUS">>,
                  <<"SEE ALSO">>],
                 [Section || {<<".SH">>, Section} <- Pairs]),
    [_, Synopsis | _] = binary:split(Output, [<<"SYNOPSIS">>, <<"DESCRIPTION">>], [global]),
    %% each job's usage once: a regression test, `ern build` stood twice
    ?assertEqual([], [Job || Job <- ["build", "run", "test", "shell", "config", "doc", "format"],
                             length(binary:matches(Synopsis,
                                                   iolist_to_binary(["\\fBern ", Job, " ["])))
                                 =/= 1]),
    ?assertMatch({_, _}, binary:match(Output, <<".SH\nDESCRIPTION\n.PP\n"
                                                "The toolchain is one command, \\fBern\\fR, ">>)),
    {ok, Report} = file:read_file("../report/toolchain.md"),
    {match, Sections} = re:run(Report, "^### (11\\.[0-6] .*)$",
                               [multiline, global, {capture, all_but_first, binary}]),
    ?assertEqual([binary:replace(Section, <<"`">>, <<>>, [global]) || [Section] <- Sections],
                 [Section || {<<".SS">>, Section} <- Pairs]),
    ?assertMatch({_, _}, binary:match(Output, <<".SH\nSEE ALSO\n.PP\n\\fBErnest.Prelude\\fR(3ern), "
                                                "\\fBErnest.Bool\\fR(3ern), ">>)),
    SeeAlso = fun(Module) ->
                  iolist_to_binary(["\\fBErnest.",
                                    ern_namespace:text(ern_namespace:namespace([Module])),
                                    "\\fR(3ern)"])
              end,
    ?assertEqual([], [Module || Module <- Modules,
                                binary:match(Output, SeeAlso(Module)) =:= nomatch]),
    rendered(["build/ern.1" | Pages]).

rendered(Pages) ->
    case {os:find_executable("groff"), os:find_executable("mandoc")} of
        {false, false} ->
            io:format(user, "  groff and mandoc not installed; the manual pages' rendering "
                            "was not checked.~n", []);
        {false, _} ->
            ?assertEqual([], [{Page, Result}
                              || Page <- Pages,
                                 {Status, _} = Result <- [sh("mandoc -Tlint -W error " ++ Page)],
                                 Status =/= 0]);
        _ ->
            ?assertEqual([], [{Page, Result}
                              || Page <- Pages,
                                 Result <- [sh("groff -k -man -Tutf8 -ww -z " ++ Page)],
                                 Result =/= {0, <<>>}])
    end.

%% The installation and the archive, each made by make, one after the other,
%% since two makes at once would each write the built trees.
installation_test_() ->
    {inorder, [{timeout, 300, fun install/0}, {timeout, 300, fun release/0}]}.

%% proposals/install/install.md: make install writes the tree under a
%% prefix, bin/ern a relative link to its launcher; the prefix moved to
%% another place runs there, `ern`, the shell, a program that runs another
%% through the helper, and `ern doc --man`, and `man` finds ern(1), a
%% module's page and a library's through the path alone. make uninstall
%% removes what was installed and leaves a page of the user's, and refuses
%% where nothing is installed; a DESTDIR stages the same tree, which runs
%% where it is staged; and a prefix that cannot be written is refused with
%% nothing written. No installed module carries the host's debug
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
%% written after the runtime's test helper `ern_waits` was found shipped.
install() ->
    {ok, VersionText} = file:read_file("../VERSION"),
    Version = string:trim(VersionText),
    Base = filename:absname("build/install"),
    ok = del(Base),
    ok = filelib:ensure_path(Base ++ "/work"),
    {0, _} = sh("make -s -C .. install PREFIX=" ++ Base ++ "/a"),
    ?assertEqual({ok, "../lib/ernest/bin/ern"}, file:read_link(Base ++ "/a/bin/ern")),
    ?assertEqual([], debug_information(Base ++ "/a")),
    ?assertEqual([], test_modules(filelib:wildcard(Base ++ "/a/lib/ernest/erl/*/ebin/*.beam"))),
    Documents = Base ++ "/a/share/doc/ernest/",
    {ok, Installed} = file:read_file(Documents ++ "README.md"),
    ?assertMatch({_, _}, binary:match(Installed, <<"</picture>\n\n# Ernest ", Version/binary,
                                                    "\n">>)),
    ?assertEqual([], dead_links(Documents)),
    ?assert(links_to(Documents ++ "guide/language.md", "/blob/main/examples/repl.ern")),
    ok = file:rename(Base ++ "/a", Base ++ "/b"),
    Ern = Base ++ "/b/bin/ern",
    InWork = fun(Command) -> sh(Command, [{cd, Base ++ "/work"}]) end,
    %% report §8.7: an installation of the repository's build is no release,
    %% which its version text marks
    ?assertEqual({0, <<"ern ", Version/binary, "-dev\n">>}, InWork(Ern ++ " --version")),
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    {0, _} = InWork(Ern ++ " build hi.ern"),
    ?assertEqual({0, <<"hi\n">>}, InWork(Ern ++ " run hi.erc")),
    {0, ShellOutput} = InWork("printf '1 + 1\\n' | " ++ Ern ++ " shell"),
    ?assertMatch({_, _}, binary:match(ShellOutput, <<"> 2 : Int\n">>)),
    ?assertMatch({0, <<".\\\" Generated by ern ", _/binary>>}, InWork(Ern ++ " doc --man hi.ern")),
    case os:find_executable("man") of
        false ->
            io:format(user, "  man not installed; the installed pages were not looked up.~n", []);
        _ ->
            ManPath = Base ++ "/b/share/man/",
            ?assertEqual({0, iolist_to_binary([ManPath, "man1/ern.1\n", ManPath,
                                               "man3/Ernest.List.3ern\n", ManPath,
                                               "man3/Ernest.Markdown.3ern\n"])},
                         sh("env -u MANPATH PATH=" ++ Base ++ "/b/bin:/usr/bin:/bin "
                            "man -w ern Ernest.List Ernest.Markdown"))
    end,
    ok = file:write_file(Base ++ "/b/share/man/man3/Mine.3", <<"mine\n">>),
    {0, _} = sh("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b"),
    ?assertEqual([Base ++ "/b/share/man/man3/Mine.3"],
                 [File || File <- filelib:wildcard(Base ++ "/b/**/*"), not filelib:is_dir(File)]),
    %% the directories of the installation's own go with it
    ?assertNot(filelib:is_dir(Base ++ "/b/share/doc/ernest")),
    ?assertMatch({2, _}, sh("make -s -C .. uninstall PREFIX=" ++ Base ++ "/b")),
    Stage = Base ++ "/stage",
    {0, _} = sh("make -s -C .. install DESTDIR=" ++ Stage ++ " PREFIX=/opt/ernest"),
    ?assertEqual({0, <<"ern ", Version/binary, "-dev\n">>},
                 InWork(Stage ++ "/opt/ernest/bin/ern --version")),
    {0, _} = sh("make -s -C .. uninstall DESTDIR=" ++ Stage ++ " PREFIX=/opt/ernest"),
    ?assertEqual([],
                 [File || File <- filelib:wildcard(Stage ++ "/**/*"), not filelib:is_dir(File)]),
    %% a `bin/ern` that is no longer the installation's link is a person's
    %% own: install refuses it before it touches the installation there,
    %% and uninstall leaves it, a regression test of both, which removed it
    Own = Base ++ "/c",
    {0, _} = sh("make -s -C .. install PREFIX=" ++ Own),
    ok = file:delete(Own ++ "/bin/ern"),
    ok = file:write_file(Own ++ "/bin/ern", <<"mine\n">>),
    {2, NotOurs} = sh("make -s -C .. install PREFIX=" ++ Own),
    ?assertMatch({_, _}, binary:match(NotOurs, <<"bin/ern is there already and is not Ernest's">>)),
    ?assert(filelib:is_regular(Own ++ "/lib/ernest/installed")),
    {0, _} = sh("make -s -C .. uninstall PREFIX=" ++ Own),
    ?assertEqual({ok, <<"mine\n">>}, file:read_file(Own ++ "/bin/ern")),
    ?assertNot(filelib:is_dir(Own ++ "/lib/ernest")),
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

%% proposals/install/install.md: make release writes the archive, the staged tree with
%% the helper as its C source, a Makefile and a README; its make compiles
%% the helper, and its make install installs under a prefix, where a
%% program that runs another through the helper runs, and its make
%% uninstall removes it. Written with the code. The README it carries is
%% the one it installs, and the installed guide's link to an example leads
%% into the repository at the release's tag: a regression test, as
%% install/0's is. The logo the README shows stands beside it in the
%% archive, as under the prefix. The installed `ern` is a release, whose
%% version text is VERSION's alone, as the repository's build is not
%% (report §8.7): a regression test, written after the code (finding N11).
%% The archive holds no module compiled from an application's tests, as
%% the installation does not.
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
    [?assert(lists:member(list_to_binary(Name ++ "/" ++ File), Entries))
     || File <- ["Makefile", "README.md", "install.sh", "ern_exec.c", "bin/ern",
                 "lib/ernest/bin/ern", "lib/ernest/installed", "share/man/man1/ern.1"]],
    ?assertNot(lists:member(list_to_binary(Name ++ "/lib/ernest/erl/runtime/priv/ern_exec"),
                            Entries)),
    ?assertEqual([], test_modules([binary_to_list(Entry) || Entry <- Entries])),
    {0, _} = sh("tar -xzf " ++ filename:absname(Archive), [{cd, Base}]),
    Unpacked = Base ++ "/" ++ Name,
    {0, _} = sh("make -s install PREFIX=" ++ Base ++ "/p", [{cd, Unpacked}]),
    ?assertEqual([], debug_information(Base ++ "/p")),
    Documents = Base ++ "/p/share/doc/ernest/",
    {ok, Readme} = file:read_file(Unpacked ++ "/README.md"),
    ?assertEqual({ok, Readme}, file:read_file(Documents ++ "README.md")),
    ?assertEqual([], dead_links(Documents)),
    %% the README beside the archive shows the logo it carries there
    ?assertEqual([], dead_links(Unpacked ++ "/")),
    Tag = "v" ++ string:trim(binary_to_list(Version)),
    ?assert(links_to(Documents ++ "guide/language.md", "/blob/" ++ Tag ++ "/examples/repl.ern")),
    Ern = Base ++ "/p/bin/ern",
    %% report §8.7: a release's version text is VERSION's alone
    ?assertEqual({0, <<"ern ", (string:trim(Version))/binary, "\n">>},
                 sh(Ern ++ " --version", [{cd, Base ++ "/work"}])),
    ok = file:write_file(Base ++ "/work/hi.ern", runs_echo()),
    {0, _} = sh(Ern ++ " build hi.ern", [{cd, Base ++ "/work"}]),
    ?assertEqual({0, <<"hi\n">>}, sh(Ern ++ " run hi.erc", [{cd, Base ++ "/work"}])),
    {0, _} = sh("make -s uninstall PREFIX=" ++ Base ++ "/p", [{cd, Unpacked}]),
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

%% The links of the documents in a directory that name no file in it: a
%% link's target and an image's source, an address with a scheme and an
%% anchor of the document's own aside.
dead_links(Directory) ->
    [{filename:basename(Document), Target}
     || Document <- filelib:wildcard(Directory ++ "*.md"),
        Target <- link_targets(Document),
        not filelib:is_regular(Directory ++ Target)].

link_targets(Document) ->
    {ok, Text} = file:read_file(Document),
    Pattern = "\\]\\(([^)#]+)[^)]*\\)|src=\"([^\"]+)\"",
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
    "export fn main() : Unit with Never = match Os.run(Os.Command(\n"
    "    program = \"echo\", arguments = [\"hi\"], input = <<>>), 5000) {\n"
    "    Right(Os.Finished(stdout = out)) -> Io.print(Optional.withDefault(\n"
    "        String.fromUtf8(out), \"\"))\n"
    "  | Left(e) -> Io.println(Io.show(e))\n"
    "}\n".

%% The modules under a directory that carry the host's debug information.
debug_information(Dir) ->
    [File || File <- filelib:wildcard(Dir ++ "/**/*.{beam,erc}"),
             begin
                 {ok, Beam} = file:read_file(File),
                 {ok, _, Chunks} = beam_lib:all_chunks(Beam),
                 lists:keymember("Dbgi", 1, Chunks)
             end].

%% report §9.3, §11.2, Appendix G.2, G.4, G.5, G.6, G.7, plan MVP 3.2: every
%% library's own tests, run by `ern test` over the directory their compiled
%% modules are under, as the shell's are: the Markdown library's read and
%% lay out what G.2 says, the Load and Balancer libraries' measure as G.4
%% and G.5 say, the balancer's measuring process faulting as its test
%% expects, which the run reports, the JSON library's read and write
%% what G.6 says, and the proxy's wait for its service as G.7 says. A
%% regression test too: the modules were run by one command joined with
%% `&&`, which the host runs by `exec`, so only the first module's tests
%% ran, and it has none
libs_test_() ->
    {timeout, 60, fun libs/0}.

libs() ->
    {Status, Output} = sh("../bin/ern test --load-path ../build/libs/ansi ../build/libs"),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    Passed = [Line || Line <- Lines, binary:match(Line, <<": passed">>) =/= nomatch],
    Faulted = [Line || Line <- Lines, binary:match(Line, <<" faulted: ">>) =/= nomatch],
    ?assertMatch([_], [Line || Line <- Faulted,
                               binary:match(Line, <<"Balancer.elsewhere:">>) =/= nomatch,
                               binary:match(Line, <<"is no place of this balancer">>) =/= nomatch]),
    %% a module with tests is named before them, and one without is passed
    %% over (report §11.2)
    ?assertEqual([<<"Balancer">>, <<"Json">>, <<"Load">>, <<"Markdown">>, <<"Proxy">>],
                 Lines -- (Passed ++ Faulted)),
    ?assert(length(Passed) >= 40),
    ?assertEqual(0, Status).

%% report Appendix G.1, §7.4: a table replaces a key's entry, a removal of
%% a key that is not there does nothing, `clear` leaves the table, and an
%% operation on a table that has ended faults as a foreign function that
%% raises does, but `size`, which faults with its own cause. A regression
%% test: the library had no test of its own, and its pages no Errors
%% sections; and `size` of an ended table faulted with "foreign return
%% does not match Int"
ets_test_() ->
    {timeout, 60, fun ets/0}.

ets() ->
    Dir = "build/ets",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/tables.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    let t : Ets.Table(String, Int) = Ets.new();\n"
                         "    Ets.put(t, \"a\", 1);\n"
                         "    Ets.put(t, \"a\", 2);\n"
                         "    Ets.remove(t, \"b\");\n"
                         "    let _ = Io.debug(#(Ets.get(t, \"a\"), Ets.size(t),\n"
                         "                       Ets.contains(t, \"b\")));\n"
                         "    Ets.clear(t);\n"
                         "    let _ = Io.debug(Ets.toList(t));\n"
                         "    Ets.close(t);\n"
                         "    Ets.put(t, \"a\", 3)\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " --load-path ../build/libs/ets --build-root "
              ++ Dir ++ " " ++ Dir ++ "/tables.ern"),
    {1, Output} = sh("../bin/ern run --load-path ../build/libs/ets " ++ Dir ++ "/tables.erc"),
    %% what the program prints and the fault's line come on two streams
    Lines = unstamped(binary:split(Output, <<"\n">>, [global, trim])),
    ?assert(lists:member(<<"#(Some(2), 1, false)">>, Lines)),
    ?assert(lists:member(<<"[]">>, Lines)),
    ?assert(lists:member(<<"Tables.main faulted: foreign function ets:insert/2 raised "
                           "error:badarg">>, Lines)),
    ok = file:write_file(Dir ++ "/sized.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    let t : Ets.Table(String, Int) = Ets.new();\n"
                         "    Ets.close(t);\n"
                         "    Io.println(Int.toString(Ets.size(t)))\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " --load-path ../build/libs/ets --build-root "
              ++ Dir ++ " " ++ Dir ++ "/sized.ern"),
    {1, Sized} = sh("../bin/ern run --load-path ../build/libs/ets " ++ Dir ++ "/sized.erc"),
    ?assert(lists:member(<<"Sized.main faulted: the table has ended">>,
                         unstamped(binary:split(Sized, <<"\n">>, [global, trim])))).

%% report §8.2, §7.4, Appendix E.1: standard input is UTF-8 whatever the
%% host's locale, a line without its line feed or the carriage return
%% before it, a last line without a line feed; a line that is not UTF-8
%% faults; lines and bytes are one stream, and bytes go out as they are
stdin_test_() ->
    {timeout, 60, fun stdin/0}.

stdin() ->
    [0 = build("--source-root stdin --build-root build/stdin stdin/"
               ++ Program ++ ".ern") || Program <- ["lines", "stream", "chunks"]],
    Launch = fun(Input, Program) ->
                 sh("printf '" ++ Input ++ "' | LANG=C ../bin/ern run build/stdin/"
                    ++ Program ++ ".erc")
             end,
    ?assertEqual({0, <<"[h", 16#e9/utf8, "] 2\n[zw", 16#4e2d/utf8, "] 3\n[] 0\n[last] 4\nend\n">>},
                 Launch("h\\303\\251\\r\\nzw\\344\\270\\255\\n\\nlast", "lines")),
    %% standard output and standard error are two streams, which nothing
    %% orders against each other, so each is compared alone
    ErrorFile = "build/stdin/stderr",
    ?assertEqual({1, <<"[ok] 2\n">>},
                 sh("printf 'ok\\n\\377\\nnext\\n' | LANG=C ../bin/ern run build/stdin/lines.erc 2>"
                    ++ ErrorFile)),
    {ok, Said} = file:read_file(ErrorFile),
    ?assertEqual([<<"Lines.main faulted: the standard input is not UTF-8">>],
                 unstamped(lines(Said))),
    ?assertEqual({0, <<"head\n", 255, 16#e9/utf8, "tail\nbytes 8\n">>},
                 Launch("head\\n\\377\\303\\251tail\\n", "stream")),
    %% a read does not wait for more than has arrived: the second byte is
    %% written once the program has said it read the first, so that how long
    %% the host takes to start, about as long as the one second the writer
    %% had paused, plays no part (it had failed when the start took longer);
    %% the wait reads the output quietly, since the program's shell may not
    %% yet have made the file, and grep's complaint was taken for its output
    ?assertEqual({0, <<"1\n1\nend\n">>},
                 sh("sh -c 'rm -f build/stdin/in build/stdin/out; mkfifo build/stdin/in; "
                    "../bin/ern run build/stdin/chunks.erc < build/stdin/in > build/stdin/out & "
                    "exec 3> build/stdin/in; printf a >&3; n=0; "
                    "until grep -qs 1 build/stdin/out || [ $n -ge 400 ]; "
                    "do sleep 0.05; n=$((n + 1)); done; "
                    "printf b >&3; exec 3>&-; wait; cat build/stdin/out'")).

%% report §11.2, Appendix E.23, E.17: as the host gives them, under a UTF-8
%% locale and under C, whose names the host takes as bytes: `ern run`
%% refuses an argument that is not UTF-8 by its position, and a job one of
%% its own words that is not UTF-8 by its text (§11), the environment
%% answers a value asked for, None for a name it has not, and faults the
%% asker of a value that is not UTF-8 (a regression test of the rule of
%% 2026-10-01, which left the value out), and ern run exits with the status
%% Os.exit gives. A regression test, written after the code; where the host
%% has no C.UTF-8 locale both runs read bytes, and a name the environment
%% gives twice is not covered, since a shell cannot give one.
os_test_() ->
    {timeout, 60, fun os/0}.

os() ->
    SourceRoot = "build/os/src",
    ok = filelib:ensure_path(SourceRoot),
    ok = file:write_file(SourceRoot ++ "/args.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(Io.show(Os.arguments));\n"
                         "    Os.exit(List.size(Os.arguments))\n"
                         "}\n"),
    ok = file:write_file(SourceRoot ++ "/env.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(Io.show(#(Os.environment(\"ERN_OK\"),\n"
                         "                         Os.environment(\"ERN_NONE\"))));\n"
                         "    Io.println(Io.show(Os.environment(\"ERN_BAD\")))\n"
                         "}\n"),
    0 = build("--source-root build/os/src --build-root build/os build/os/src"),
    lists:foreach(
      fun(Locale) ->
          Launch = "env LC_ALL=" ++ Locale ++ " ../bin/ern run build/os/",
          ?assertEqual({2, <<"[\"a b\", \"--x\"]\n">>}, sh(Launch ++ "args.erc 'a b' --x")),
          ?assertEqual({1, <<"ern run: argument 2 is not UTF-8\n">>},
                       sh(Launch ++ "args.erc ok \"$(printf '\\377')\"")),
          ?assertEqual({1, <<"ern build: a word that is not UTF-8: n\\xFFme.ern\n">>},
                       sh("env LC_ALL=" ++ Locale
                          ++ " ../bin/ern build \"$(printf 'n\\377me.ern')\"")),
          {Status, Output} = sh("env ERN_OK=\"$(printf 'caf\\303\\251')\" "
                                "ERN_BAD=\"$(printf 'caf\\351')\" " ++ Launch ++ "env.erc"),
          ?assertNotEqual(0, Status),
          ?assertMatch({0, _}, binary:match(Output, <<"#(Some(\"caf", 16#e9/utf8,
                                                      "\"), None)\n">>)),
          ?assertMatch({_, _}, binary:match(Output, <<"faulted: the environment variable"
                                                      " ERN_BAD is not UTF-8">>))
      end, ["C.UTF-8", "C"]).

%% report Appendix E.23, §11: a program's environment is the one ern was
%% started in, for Os.environment and for a program it starts: the host's
%% flags the launcher clears and what the host's own start sets or changes
%% reach it as given; and a started program has no signal ignored. A
%% regression test: BINDIR, EMU, PROGNAME and ROOTDIR were the host's, the
%% host's directories led PATH, ERL_LIBS was gone, and SIGFPE was ignored
%%. Written after the code; the crash dump's
%% variable, which the launcher sets for the host alone (report §10), joined
%% it with the full review's U1
given_environment_test_() ->
    {timeout, 60, fun given_environment/0}.

given_environment() ->
    SourceRoot = "build/given/src",
    ok = filelib:ensure_path(SourceRoot),
    Names = "[\"PATH\", \"BINDIR\", \"EMU\", \"ERL_LIBS\", \"ERL_CRASH_DUMP_SECONDS\"]",
    ok = file:write_file(
           SourceRoot ++ "/given.ern",
           ["export fn main() : Unit with Never = {\n"
            "    List.forEach(", Names, ", fn(name) =\n"
            "        Io.println(Optional.withDefault(Os.environment(name), \"unset\")));\n"
            "    let script = \"echo \\\"$PATH\\\"; echo \\\"$BINDIR\\\";"
            " echo \\\"${EMU-unset}\\\"; echo \\\"$ERL_LIBS\\\";"
            " echo \\\"$ERL_CRASH_DUMP_SECONDS\\\";"
            " trap 'echo caught' FPE; kill -FPE $$; echo survived\";\n"
            "    let command = Os.Command(program = \"sh\", arguments = [\"-c\", script],"
            " input = <<>>);\n"
            "    match Os.run(command, 10000) {\n"
            "        Right(finished) ->\n"
            "            Io.print(Optional.withDefault(String.fromUtf8(finished.stdout), \"\"))\n"
            "      | Left(_) -> Io.println(\"not run\")\n"
            "    }\n"
            "}\n"]),
    0 = build("--source-root build/given/src --build-root build/given build/given/src"),
    %% under a shell of its own, since the host runs a command by `exec`
    {0, Output} = sh("sh -c 'echo \"$PATH\"; unset EMU;"
                     " BINDIR=mine ERL_LIBS=/given ERL_CRASH_DUMP_SECONDS=7"
                     " ../bin/ern run build/given/given.erc'"),
    [Path | Lines] = binary:split(Output, <<"\n">>, [global, trim]),
    Given = [Path, <<"mine">>, <<"unset">>, <<"/given">>, <<"7">>],
    ?assertEqual(Given ++ Given ++ [<<"caught">>, <<"survived">>], Lines).

%% report §11, Appendix E.23: `PWD` reaches a program as the launcher's
%% shell leaves it, naming the working directory, where it was given so,
%% unset, or naming another. Written after the code, which the shell
%% decides: the launcher cannot see what the shell replaced
pwd_is_the_shells_test_() ->
    {timeout, 60, fun pwd_is_the_shells/0}.

pwd_is_the_shells() ->
    Dir = "build/pwd",
    ok = filelib:ensure_path(Dir ++ "/src"),
    ok = file:write_file(Dir ++ "/src/pwd.ern",
                         "export fn main() : Unit with Never =\n"
                         "    Io.println(Optional.withDefault(Os.environment(\"PWD\"),"
                         " \"unset\"))\n"),
    0 = build("--source-root " ++ Dir ++ "/src " ++ Dir ++ "/src"),
    Here = list_to_binary(filename:absname(Dir)),
    Run = fun(Setting) ->
              sh("sh -c 'cd " ++ Dir ++ " && " ++ Setting ++ " " ++ filename:absname("../bin/ern")
                 ++ " run src/pwd.erc'")
          end,
    Expected = {0, <<Here/binary, "\n">>},
    ?assertEqual(Expected, Run("env -u PWD")),
    ?assertEqual(Expected, Run("env PWD=/")),
    ?assertEqual(Expected, Run("env PWD=" ++ binary_to_list(Here))),
    file:del_dir_r(Dir).

%% report §11, §11.2, §8.4: the host's compiler takes no options from the
%% environment, and a foreign function's module is the host's own or on
%% the load path, never in the working directory, which is not on the
%% host's code path. A regression test: `ERL_COMPILER_OPTIONS` reached
%% every compile, so a parse transform it named failed the build, and a
%% `.beam` in the working directory answered a foreign function no
%% directory of the load path held
host_takes_nothing_from_where_it_runs_test_() ->
    {timeout, 60, fun host_takes_nothing_from_where_it_runs/0}.

host_takes_nothing_from_where_it_runs() ->
    Dir = "build/hostcwd",
    ok = filelib:ensure_path(Dir ++ "/src"),
    ok = file:write_file(Dir ++ "/src/plain.ern",
                         "foreign fn stub() : Int = \"ern_cwd_stub:value/0\"\n"
                         "export fn main() : Unit with Never = Io.println(Int.toString(stub()))\n"),
    ok = file:write_file(Dir ++ "/ern_cwd_stub.erl",
                         "-module(ern_cwd_stub).\n-export([value/0]).\nvalue() -> 42.\n"),
    {ok, ern_cwd_stub} = compile:file(Dir ++ "/ern_cwd_stub.erl", [{outdir, Dir}]),
    Ern = filename:absname("../bin/ern"),
    {Built, BuildOutput} = sh("sh -c 'cd " ++ Dir ++ " && ERL_COMPILER_OPTIONS="
                              "\"[{parse_transform,ern_no_such_transform}]\" "
                              ++ Ern ++ " build --source-root src src/plain.ern'"),
    ?assertEqual({0, <<>>}, {Built, BuildOutput}),
    {Ran, RunOutput} = sh("sh -c 'cd " ++ Dir ++ " && " ++ Ern ++ " run src/plain.erc'"),
    ?assertEqual(1, Ran),
    ?assertNot(lists:member(<<"42">>, binary:split(RunOutput, <<"\n">>, [global]))),
    file:del_dir_r(Dir).

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
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(Path.toString(Os.workingDirectory));\n"
                         "    match Fs.read(Path(\"notes.txt\"), 1000) {\n"
                         "        Right(bytes) -> Io.println(Io.show(String.fromUtf8(bytes)))\n"
                         "      | Left(_) -> Io.println(\"no notes\")\n"
                         "    }\n"
                         "}\n"),
    0 = build("--source-root build/cwd/src --build-root build/cwd build/cwd/src"),
    Cafe = <<"build/cwd/caf", 16#c3, 16#a9>>,
    [ok = make_dir(Path) || Path <- [Cafe, <<"build/cwd/bad", 16#e9>>]],
    ok = file:write_file(<<Cafe/binary, "/notes.txt">>, <<"buy milk">>),
    Launch = fun(Glob, Locale) ->
                 sh("sh -c 'cd build/cwd/" ++ Glob ++ " && env LC_ALL=" ++ Locale ++ " "
                    ++ filename:absname("../bin/ern") ++ " run "
                    ++ filename:absname("build/cwd/here.erc") ++ "'")
             end,
    Here = <<(list_to_binary(filename:absname("build/cwd")))/binary, "/caf", 16#c3, 16#a9>>,
    [?assertEqual({0, <<Here/binary, "\nSome(\"buy milk\")\n">>}, Launch("caf*", Locale))
     || Locale <- ["C.UTF-8", "C"]],
    [?assertEqual({1, <<"ern: the working directory's name is not UTF-8\n">>},
                  Launch("bad*", Locale))
     || Locale <- ["C.UTF-8", "C"]],
    %% the name other tests' wildcards cannot read, which the host warns of
    ok = file:del_dir(<<"build/cwd/bad", 16#e9>>).

make_dir(Dir) ->
    case file:make_dir(Dir) of
        {error, eexist} -> ok;
        Other -> Other
    end.

%% report §11, proposals/install/install.md: the launcher needs `iconv` to read the
%% working directory's name, and names it where the path has none. A
%% regression test: every working directory was refused as not UTF-8
launcher_names_a_missing_iconv_test() ->
    Bin = filename:absname("build/no_iconv"),
    _ = file:del_dir_r(Bin),
    ok = filelib:ensure_path(Bin),
    [ok = file:make_symlink(os:find_executable(Tool), filename:join(Bin, Tool))
     || Tool <- ["erl", "dirname", "readlink"]],
    ?assertEqual({1, <<"ern: iconv, which tells whether the working directory's name is UTF-8,"
                       " is not on the path\n">>},
                 sh("env PATH=" ++ Bin ++ " " ++ filename:absname("../bin/ern") ++ " --version")),
    ok = file:del_dir_r(Bin).

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
                         "fn loop(n : Int) : Unit with Never =\n"
                         "    if n == 0 then Io.printlnError(\"finished\")\n"
                         "    else { Io.println(\"line\"); loop(n - 1) }\n"
                         "export fn main() : Unit with Never = loop(100000000)\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/chatty.ern"),
    {0, Output} = sh("sh -c '{ ../bin/ern run " ++ Dir ++ "/chatty.erc 2> " ++ Dir
                     ++ "/err; echo $? > " ++ Dir ++ "/status; } | head -1'"),
    ?assertEqual(<<"line\n">>, Output),
    ?assertEqual({ok, <<"141\n">>}, file:read_file(Dir ++ "/status")),
    ?assertEqual({ok, <<>>}, file:read_file(Dir ++ "/err")).

%% report §8.6, §11.8: a stream that can no longer be written when the
%% runtime flushes it ends the program with status 141, in place of what
%% ended it: a program whose one write is lost, whose entry point then
%% returns or calls Os.exit, on standard output and on standard error. A
%% regression test, written after the code: of twenty-four such runs eleven
%% ended with status 0, ten with 141, and three did not end. It does not
%% cover a device that fails, which only some hosts have one of.
stream_lost_at_end_test_() ->
    {timeout, 120, fun stream_lost_at_end/0}.

stream_lost_at_end() ->
    Dir = "build/lost",
    ok = filelib:ensure_path(Dir),
    Programs = [{"out", "Io.println(\"written\")", ""},
                {"err", "Io.printlnError(\"written\")", "2>&1 "},
                {"exit", "{ Io.println(\"written\"); Os.exit(3) }", ""}],
    [begin
         ok = file:write_file(Dir ++ "/" ++ Name ++ ".ern",
                              "export fn main() : Unit with m = " ++ Body ++ "\n"),
         0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/" ++ Name ++ ".ern")
     end || {Name, Body, _} <- Programs],
    %% the reader has gone before the program writes
    Statuses = [begin
                    {0, <<>>} = sh("sh -c '{ sleep 1; timeout -s KILL 20 ../bin/ern run " ++ Dir
                                   ++ "/" ++ Name ++ ".erc " ++ Redirect ++ "; echo $? > " ++ Dir
                                   ++ "/status; } | true'"),
                    {ok, Status} = file:read_file(Dir ++ "/status"),
                    ok = file:delete(Dir ++ "/status"),
                    {Name, Status}
                end || {Name, _, Redirect} <- Programs, _ <- [1, 2, 3]],
    ?assertEqual([{Name, <<"141\n">>} || {Name, _, _} <- Programs, _ <- [1, 2, 3]], Statuses).

%% report §8.2: a program writing faster than its reader reads is held to
%% the reader's pace, so what it has written and the reader has not taken
%% is not held in the node. A regression test, written after the code: two
%% million lines to a pipe read late held about 650 MB, where the node
%% itself takes under 100. The reader closes the pipe after its first byte,
%% which ends the program once its memory has been sampled, rather than
%% taking the two million lines.
paced_output_test_() ->
    {timeout, 60, fun paced_output/0}.

paced_output() ->
    Dir = "build/paced",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/flood.ern",
                         "fn loop(n : Int) : Unit with Never =\n"
                         "    if n == 0 then Unit\n"
                         "    else { Io.println(\"a line of output a slow reader takes late\");\n"
                         "        loop(n - 1) }\n"
                         "export fn main() : Unit with Never = loop(2000000)\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/flood.ern"),
    Reader = "{ sleep 4; head -c 1 > /dev/null; }",
    {0, Output} = sh("sh -c '../bin/ern run " ++ Dir ++ "/flood.erc | " ++ Reader ++ " & "
                     "sleep 3; ps -eo rss,comm,args | grep \"beam.smp.*[f]lood.erc\" | head -1; "
                     "wait'"),
    [Rss | _] = string:lexemes(binary_to_list(Output), " \n"),
    ?assert(list_to_integer(Rss) < 250000).

%% report §11.2: a module a `foreign fn` names is the host's own or one on
%% the load path, and the working directory is neither. A regression test:
%% the host kept the working directory on its code path ahead of the load
%% path, so a module of that name there was the one called. It does not
%% cover `ern test` and `ern shell`, which set the path the same way
foreign_module_test_() ->
    {timeout, 60, fun foreign_module/0}.

foreign_module() ->
    Dir = filename:absname("build/foreign"),
    ok = del(Dir),
    Ern = filename:absname("../bin/ern"),
    Probe = fun(Where, Number) ->
                ok = filelib:ensure_path(Where),
                ok = file:write_file(Where ++ "/ern_probe.erl",
                                     "-module(ern_probe).\n-export([n/0]).\nn() -> "
                                     ++ integer_to_list(Number) ++ ".\n"),
                {0, _} = sh("erlc -o " ++ Where ++ " " ++ Where ++ "/ern_probe.erl")
            end,
    Probe(Dir ++ "/prog", 1),
    Probe(Dir ++ "/work", 2),
    ok = file:write_file(Dir ++ "/prog/which.ern",
                         "foreign fn n() : Int = \"ern_probe:n/0\"\n"
                         "export fn main() : Unit with Never = Io.println(Int.toString(n()))\n"),
    {0, _} = sh(Ern ++ " build --source-root " ++ Dir ++ "/prog " ++ Dir ++ "/prog/which.ern"),
    ?assertEqual({0, <<"1\n">>}, sh(Ern ++ " run ../prog/which.erc", [{cd, Dir ++ "/work"}])).

%% report §11: a job whose standard output or standard error has no reader
%% any more ends at once with status 141, and leaves no crash dump. A
%% regression test: every job but a program's run halted the host, which
%% wrote erl_crash.dump into the working directory; the release review
%% found the shell in line mode ending with status 0 and the host's report
%% of the failed write
closed_pipe_test_() ->
    {timeout, 60, fun closed_pipe/0}.

closed_pipe() ->
    Dir = filename:absname("build/closed_pipe"),
    ok = del(Dir),
    ok = filelib:ensure_path(Dir),
    Ern = filename:absname("../bin/ern"),
    StatusOf = fun(Job) ->
                   {0, _} = sh("sh -c 'cd " ++ Dir ++ " && ( sleep 0.3; " ++ Ern ++ " " ++ Job
                               ++ " 2>&1; echo $? > status ) | true'"),
                   {ok, Text} = file:read_file(Dir ++ "/status"),
                   string:trim(Text)
               end,
    [?assertEqual({Job, <<"141">>}, {Job, StatusOf(Job)})
     || Job <- ["--version", "--help", "build missing.ern", "run missing.erc", "test --help",
                "doc " ++ filename:absname("../stdlib/list.ern"), "shell < /dev/null"]],
    ?assertNot(filelib:is_file(Dir ++ "/erl_crash.dump")),
    {0, _} = sh("sh -c 'cd " ++ Dir ++ " && ( sleep 0.3; echo 1 | " ++ Ern ++ " shell"
                " 2> err; echo $? > status ) | true'"),
    ?assertEqual({ok, <<"141\n">>}, file:read_file(Dir ++ "/status")),
    ?assertEqual({ok, <<>>}, file:read_file(Dir ++ "/err")).

%% report §11, §11.8: a job whose standard output or standard error is
%% closed as it begins ends with status 141 and writes nothing. A
%% regression test: the host opened /dev/null in the stream's place, and
%% the job wrote there and ended with status 0
closed_stream_test_() ->
    {timeout, 60, fun closed_stream/0}.

closed_stream() ->
    Ern = filename:absname("../bin/ern"),
    ?assertEqual({141, <<>>}, sh(Ern ++ " --version >&- 2>/dev/null")),
    ?assertEqual({141, <<>>}, sh(Ern ++ " shell < /dev/null >/dev/null 2>&-")),
    ?assertEqual({0, <<>>}, sh(Ern ++ " --version >/dev/null")).

%% report §11.2: a fault line writes a control character of the cause as
%% its escape, so that a fault is one line. A regression test: a cause's
%% line feed wrote a second line, which forged another fault, and its
%% escape reached the terminal as itself
fault_line_escaped_test_() ->
    {timeout, 60, fun fault_line_escaped/0}.

fault_line_escaped() ->
    Dir = "build/escaped",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/forged.ern",
                         "export fn main() : Unit with Never =\n"
                         "    fault(\"a\\u{1b}[31m\\nX.main faulted: forged\")\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/forged.ern"),
    ErrorFile = Dir ++ "/err",
    {1, _} = sh("../bin/ern run " ++ Dir ++ "/forged.erc 2> " ++ ErrorFile),
    {ok, Text} = file:read_file(ErrorFile),
    ?assertMatch({_, _}, binary:match(Text, <<"Forged.main faulted: a\\u{1B}[31m\\nX.main"
                                              " faulted: forged\n">>)),
    ?assertEqual(1, length(binary:matches(Text, <<"\n">>))).

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
                         "export fn main() : Unit with Never = {\n"
                         "    let z = List.size([]);\n"
                         "    let _ = 1 / z;\n"
                         "    Unit\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/faulty.ern"),
    ErrorFile = Dir ++ "/err",
    {1, _} = sh("../bin/ern run " ++ Dir ++ "/faulty.erc 2> " ++ ErrorFile),
    {ok, Stamped} = file:read_file(ErrorFile),
    ?assertMatch({match, _}, re:run(Stamped, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:"
                                             "[0-9]{2}\\.[0-9]{3}Z Faulty\\.main faulted: "
                                             "division by zero\n$")),
    ok = file:write_file(ErrorFile, <<>>),
    {ok, #file_info{major_device = Device, inode = Inode}} = file:read_file_info(ErrorFile),
    {1, _} = sh("env JOURNAL_STREAM=" ++ integer_to_list(Device) ++ ":" ++ integer_to_list(Inode)
                ++ " ../bin/ern run " ++ Dir ++ "/faulty.erc 2> " ++ ErrorFile),
    ?assertEqual({ok, <<"Faulty.main faulted: division by zero\n">>}, file:read_file(ErrorFile)).

%% report §8.6, §11.2: the host's termination and hangup end `ern run` by the
%% signal itself once its output is flushed, so that the process that started
%% it sees a signal's end, as a service manager counts a stop it asked for.
%% A regression test, written after the code: it exited with 128 plus the
%% signal's number, which a shell reads the same and a service manager as a
%% failure. Each signal is sent once the program has said it runs, since a
%% signal that comes as the host itself starts is dropped (plan, Standing
%% gaps); sent two seconds after the start, it came then under load.
signal_end_test_() ->
    {timeout, 60, fun signal_end/0}.

signal_end() ->
    Dir = "build/signal_end",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(\"running\");\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    Python = "import subprocess, signal\n"
             "for s in (signal.SIGTERM, signal.SIGHUP):\n"
             "    p = subprocess.Popen(['../bin/ern', 'run', '" ++ Dir ++ "/waits.erc'],\n"
             "                         stdout=subprocess.PIPE)\n"
             "    p.stdout.readline()\n"
             "    p.send_signal(s)\n"
             "    print(p.wait(timeout=30))\n",
    ok = file:write_file(Dir ++ "/signals.py", Python),
    ?assertEqual({0, <<"-15\n-1\n">>}, sh("python3 " ++ Dir ++ "/signals.py")).

%% report §8.6, §11.2, §11.8, Appendix E.23: `ern` ends by the signal only
%% where the signal ended the program. A termination that began the end
%% ends `ern` by it once the subscriber has answered; a subscriber's
%% Os.exit while the end waits gives its status, and a stream that could
%% no longer be written while it waited gives 141. Where an Os.exit or
%% main's return began the end, what began it stands: a termination that
%% comes while the end waits counts, and a second cuts the wait short with
%% the status of what began it. Two signals are sent there, a termination
%% and a hangup, which is a termination for a program that is no node,
%% since nothing shows when the first has reached the runner. A wait cut
%% short, by the subscriber's Os.exit or by the second termination, says
%% on standard error whom it left unanswered (§11.2). A regression test,
%% written after the fix: once a termination had come, `ern` ended by it
%% whatever ended the program; the cut-short line, written after the code.
end_status_test_() ->
    {timeout, 60, fun end_status/0}.

end_status() ->
    Dir = "build/end_status",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/told.ern",
                         "type Msg = Terminating(Reply(Unit)) | Ready\n"
                         "export fn main() : Unit with Msg =\n"
                         "    match Os.arguments {\n"
                         "        [how, began] -> {\n"
                         "            let me = self();\n"
                         "            let _ = spawn(fn() : Unit with Msg = subscriber(how, me));\n"
                         "            receive {\n"
                         "                Ready -> ended(began)\n"
                         "              | Terminating(reply) -> answer(reply, Unit)\n"
                         "            }\n"
                         "        }\n"
                         "      | _ -> Unit\n"
                         "    }\n"
                         "fn ended(began : String) : Unit with Msg =\n"
                         "    match began {\n"
                         "        \"termination\" -> {\n"
                         "            Io.println(\"running\");\n"
                         "            receive { Ready -> Unit }\n"
                         "        }\n"
                         "      | \"exit\" -> Os.exit(3)\n"
                         "      | _ -> Unit\n"
                         "    }\n"
                         "fn subscriber(how : String, main : Address(Msg)) : Unit with Msg = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> told(how, reply)\n"
                         "      | Ready -> Unit\n"
                         "    }\n"
                         "}\n"
                         "fn told(how : String, reply : Reply(Unit)) : Unit with Msg = {\n"
                         "    Io.println(\"told\");\n"
                         "    match how {\n"
                         "        \"exit\" -> {\n"
                         "            let _ : Unit = Os.exit(5);\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "      | \"answer\" -> answer(reply, Unit)\n"
                         "      | _ -> held(reply)\n"
                         "    }\n"
                         "}\n"
                         "fn held(reply : Reply(Unit)) : Unit with Msg =\n"
                         "    receive {\n"
                         "        Terminating(other) -> {\n"
                         "            answer(other, Unit);\n"
                         "            held(reply)\n"
                         "        }\n"
                         "      | Ready -> held(reply)\n"
                         "    }\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/told.ern"),
    Python = "import subprocess, signal, re\n"
             "def run(name, how, began, until, signals, close=False):\n"
             "    p = subprocess.Popen(['../bin/ern', 'run', '" ++ Dir ++ "/told.erc', how,"
             " began], stdout=subprocess.PIPE, stderr=subprocess.PIPE)\n"
             "    for line in p.stdout:\n"
             "        if line == until + b'\\n':\n"
             "            break\n"
             "    if close:\n"
             "        p.stdout.close()\n"
             "    for s in signals:\n"
             "        p.send_signal(s)\n"
             "    status = p.wait(timeout=30)\n"
             "    cut = [re.sub(rb'^\\S+Z ', b'', line).decode()\n"
             "           for line in p.stderr.read().splitlines() if b'cut short' in line]\n"
             "    print(name, status, *cut)\n"
             "run('answered', 'answer', 'termination', b'running', [signal.SIGTERM])\n"
             "run('exited', 'exit', 'termination', b'running', [signal.SIGTERM])\n"
             "run('gone', 'answer', 'termination', b'running', [signal.SIGTERM], True)\n"
             "run('exit began', 'hold', 'exit', b'told', [signal.SIGTERM, signal.SIGHUP])\n"
             "run('return began', 'hold', 'return', b'told', [signal.SIGTERM, signal.SIGHUP])\n",
    ok = file:write_file(Dir ++ "/statuses.py", Python),
    Cut = "the end was cut short, 1 subscriber unanswered: Told.main:6",
    ?assertEqual({0, iolist_to_binary(["answered -15\n",
                                       "exited 5 ", Cut, "\n",
                                       "gone 141\n",
                                       "exit began 3 ", Cut, "\n",
                                       "return began 0 ", Cut, "\n"])},
                 sh("python3 " ++ Dir ++ "/statuses.py")).

%% report §8.6, §11.2: a subscriber that faults while it is told has its
%% fault's line written before the line that says it ended without
%% answering, as they happened. A regression test, written after the fix:
%% under `ern run` the second came first in every run, the process that
%% told the subscriber learning of its end before the reaper had reported
%% the fault; it runs the program several times, since the order was one
%% of scheduling. Main returns once the keeper has subscribed, so that the
%% subscription is made before the end looks for it.
fault_before_its_end_test_() ->
    {timeout, 60, fun fault_before_its_end/0}.

fault_before_its_end() ->
    Dir = "build/fault_before_its_end",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/faulty.ern",
                         "type Msg = Terminating(Reply(Unit)) | Ready\n"
                         "fn keeper(main : Address(Msg)) : Unit with Msg = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> {\n"
                         "            let _ = 1 / List.size([]);\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "    }\n"
                         "}\n"
                         "export fn main() : Unit with Msg = {\n"
                         "    let me = self();\n"
                         "    let _ = spawn(fn() : Unit with Msg = keeper(me));\n"
                         "    receive { Ready -> Unit }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/faulty.ern"),
    lists:foreach(
      fun(_) ->
          {0, Output} = sh("../bin/ern run " ++ Dir ++ "/faulty.erc"),
          ?assertEqual([<<"the end waits for 1 subscriber: Faulty.main:14">>,
                        <<"Faulty.main:14 faulted: division by zero">>,
                        <<"the subscriber Faulty.main:14 ended without answering">>],
                       unstamped_lines(Output))
      end, lists:seq(1, 5)).

%% report §8.6, §6.9, §11.2, Appendix E.23: a subscriber that faults when
%% it is told restarts, its fault's line written as a restart's before the
%% line that it restarted without answering; its new run subscribes again,
%% is told, said as it is told, prints and answers, and the end waits for
%% it. A holder, a
%% second subscriber, answers once the new run has been told, so that the
%% end waits for that run whatever order the host schedules it in; which
%% of the two answers is said first is the host's scheduling, and the test
%% does not fix it. A regression test, written after the code: the
%% restarted run's subscription was never told, and the end went on
%% without it.
restarted_subscriber_test_() ->
    {timeout, 60, fun restarted_subscriber/0}.

restarted_subscriber() ->
    Dir = "build/restarted_subscriber",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/restarted.ern",
                         "type Msg = Ready | Done | Add(Int) | Terminating(Reply(Unit))\n"
                         "fn hold(main : Address(Msg)) : Unit with Msg = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> receive { Done -> answer(reply, Unit) }\n"
                         "    }\n"
                         "}\n"
                         "fn keeper(holder : Address(Msg), main : Address(Msg)) : Unit with Msg"
                         " = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    count(holder, 0)\n"
                         "}\n"
                         "fn count(holder : Address(Msg), n : Int) : Unit with Msg = receive {\n"
                         "    Add(k) -> count(holder, n + k)\n"
                         "  | Terminating(reply) -> if n > 0 then {\n"
                         "        let _ = 1 / List.size([]);\n"
                         "        answer(reply, Unit)\n"
                         "    } else {\n"
                         "        Io.println(\"told again\");\n"
                         "        send(holder, Done);\n"
                         "        answer(reply, Unit)\n"
                         "    }\n"
                         "}\n"
                         "export fn main() : Unit with Msg = {\n"
                         "    let me = self();\n"
                         "    let holder = spawn(fn() : Unit with Msg = hold(me));\n"
                         "    let limit = RestartLimit(restarts = 1, within = 5000);\n"
                         "    let k = spawn(restarting(limit, fn() : Unit with Msg"
                         " = keeper(holder, me)));\n"
                         "    send(k, Add(1));\n"
                         "    receive { Ready -> Unit };\n"
                         "    receive { Ready -> Unit }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/restarted.ern"),
    ErrorFile = Dir ++ "/err",
    ?assertEqual({0, <<"told again\n">>},
                 sh("../bin/ern run " ++ Dir ++ "/restarted.erc 2> " ++ ErrorFile)),
    {ok, Said} = file:read_file(ErrorFile),
    [Waits, Faulted, Restarted, Too | Answers] = unstamped_lines(Said),
    ?assertEqual({<<"the end waits for 2 subscribers: Restarted.main:27, Restarted.main:29">>,
                  <<"Restarted.main:29 faulted, restarted: division by zero">>,
                  <<"the subscriber Restarted.main:29 restarted without answering">>,
                  <<"the end waits for Restarted.main:29 too">>},
                 {Waits, Faulted, Restarted, Too}),
    ?assertEqual([<<"the subscriber Restarted.main:27 answered">>,
                  <<"the subscriber Restarted.main:29 answered">>],
                 lists:sort(Answers)).

%% report §8.6, §11.2: while the end waits for its subscribers, a fault is
%% the process's own, its line written as it happens and its monitors
%% reading Fault(cause). Main's return began the end here; the keeper, a
%% subscriber, has the worker fault once it is told and answers once the
%% worker's Down has come. A regression test, written after the code: a
%% fault while the end waited after main's return was read as ProgramEnd,
%% the worker's Down said so, and no line was written.
fault_while_the_end_waits_test_() ->
    {timeout, 60, fun fault_while_the_end_waits/0}.

fault_while_the_end_waits() ->
    Dir = "build/fault_while_the_end_waits",
    waiting_program(Dir),
    ErrorFile = Dir ++ "/err",
    ?assertEqual({0, <<"Fault(\"division by zero\")\n">>},
                 sh("../bin/ern run " ++ Dir ++ "/waited.erc return 2> " ++ ErrorFile)),
    {ok, Said} = file:read_file(ErrorFile),
    ?assertEqual([<<"the end waits for 1 subscriber: Waited.started:16">>,
                  <<"Waited.started:15 faulted: division by zero">>,
                  <<"the subscriber Waited.started:16 answered">>],
                 unstamped_lines(Said)).

%% report §8.6, §11.2: as above where a termination began the end, main a
%% subscriber too, which answers and returns; the keeper has the worker
%% fault once main has ended, and the worker's fault is still its own
%% while the end waits for the keeper. `ern` ends by the signal, -15 as
%% Python reads it. The signal is sent once main has said it runs, both
%% subscriptions made. A regression test, written after the code: the
%% fault, after main's death and of no subscriber, was read as ProgramEnd
%% and not reported. Which of main's answer and the worker's fault is said
%% first is a matter of scheduling, and the test does not fix it.
fault_while_a_termination_waits_test_() ->
    {timeout, 60, fun fault_while_a_termination_waits/0}.

fault_while_a_termination_waits() ->
    Dir = "build/fault_while_a_termination_waits",
    waiting_program(Dir),
    ErrorFile = Dir ++ "/err",
    Python = "import subprocess, signal, sys\n"
             "with open('" ++ ErrorFile ++ "', 'wb') as err:\n"
             "    p = subprocess.Popen(['../bin/ern', 'run', '" ++ Dir ++ "/waited.erc',"
             " 'termination'], stdout=subprocess.PIPE, stderr=err)\n"
             "    running = p.stdout.readline()\n"
             "    p.send_signal(signal.SIGTERM)\n"
             "    rest = p.stdout.read()\n"
             "    sys.stdout.buffer.write(running + rest + b'%d\\n' % p.wait(timeout=30))\n",
    ok = file:write_file(Dir ++ "/terminated.py", Python),
    ?assertEqual({0, <<"running\nFault(\"division by zero\")\n-15\n">>},
                 sh("python3 " ++ Dir ++ "/terminated.py")),
    {ok, Said} = file:read_file(ErrorFile),
    Faulted = <<"Waited.started:15 faulted: division by zero">>,
    KeeperAnswered = <<"the subscriber Waited.started:16 answered">>,
    [Waits | Lines] = unstamped_lines(Said),
    ?assertEqual(<<"the end waits for 2 subscribers: Waited.main, Waited.started:16">>, Waits),
    ?assertEqual(lists:sort([<<"the subscriber Waited.main answered">>, Faulted, KeeperAnswered]),
                 lists:sort(Lines)),
    %% the keeper answers once the worker's Down has come
    {BeforeAnswer, _} = lists:splitwith(fun(Line) -> Line =/= KeeperAnswered end, Lines),
    ?assert(lists:member(Faulted, BeforeAnswer)).

%% A program whose end waits for a keeper, a subscriber of Os.termination
%% that, once it is told and main has ended, has a worker fault, prints the
%% worker's Down's reason, and answers. Its argument says what begins the
%% end: main's return, or, with `termination`, a termination, main then a
%% subscriber that answers and returns.
waiting_program(Dir) ->
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waited.ern",
                         "type Msg = Terminating(Reply(Unit)) | Ready | MainEnded(Down)"
                         " | WorkerEnded(Down)\n"
                         "type Order = Fail\n"
                         "export fn main() : Unit with Msg =\n"
                         "    match Os.arguments {\n"
                         "        [\"termination\"] -> {\n"
                         "            Os.termination(Terminating);\n"
                         "            started();\n"
                         "            Io.println(\"running\");\n"
                         "            receive { Terminating(reply) -> answer(reply, Unit) }\n"
                         "        }\n"
                         "      | _ -> started()\n"
                         "    }\n"
                         "fn started() : Unit with Msg = {\n"
                         "    let me = self();\n"
                         "    let worker = spawn(fails);\n"
                         "    let _ = spawn(fn() : Unit with Msg = keeper(me, worker));\n"
                         "    receive { Ready -> Unit }\n"
                         "}\n"
                         "fn fails() : Unit with Order =\n"
                         "    receive {\n"
                         "        Fail -> {\n"
                         "            let _ = 1 / List.size([]);\n"
                         "            Unit\n"
                         "        }\n"
                         "    }\n"
                         "fn keeper(main : Address(Msg), worker : Address(Order)) : Unit with Msg"
                         " = {\n"
                         "    Os.termination(Terminating);\n"
                         "    monitor(Process.fromAddress(main), MainEnded);\n"
                         "    monitor(Process.fromAddress(worker), WorkerEnded);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> {\n"
                         "            receive { MainEnded(_) -> Unit };\n"
                         "            send(worker, Fail);\n"
                         "            receive {\n"
                         "                WorkerEnded(down) -> {\n"
                         "                    Io.println(Io.show(down.reason));\n"
                         "                    answer(reply, Unit)\n"
                         "                }\n"
                         "            }\n"
                         "        }\n"
                         "    }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/waited.ern").

%% Report §11.2: the lines a run wrote on standard error, in their order,
%% without the time each begins with where it is a file.
unstamped_lines(Text) ->
    [re:replace(Line, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z ", "", [{return, binary}])
     || Line <- binary:split(Text, <<"\n">>, [global, trim])].

%% report §11.2: a runtime whose loads have brought one of the host's
%% limits to four fifths says so on standard error at a run's start, once
%% the units are loaded and the bindings have their values, once, written
%% as a fault's line is, its time first where standard error is a file. The
%% program's binding makes the atoms that bring the host there, as many as
%% the host's own counts say. A regression test, written after the code.
limits_line_test_() ->
    {timeout, 60, fun limits_line/0}.

limits_line() ->
    Dir = "build/limits_line",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/atoms.ern",
                         "foreign fn made(text : String) : Foreign.Term ="
                         " \"erlang:binary_to_atom/1\"\n"
                         "foreign fn host(item : Foreign.Term) : Int = \"erlang:system_info/1\"\n"
                         "fn fill(count : Int) : Unit =\n"
                         "    if count <= 0 then Unit else {\n"
                         "        let _ = made(\"limits_line_\" <> Int.toString(count));\n"
                         "        fill(count - 1)\n"
                         "    }\n"
                         "// the atoms that bring the host's to four fifths of its limit\n"
                         "let filled : Unit =\n"
                         "    fill((4 * host(Foreign.atom(\"atom_limit\")) + 4) / 5\n"
                         "         - host(Foreign.atom(\"atom_count\")))\n"
                         "export fn main() : Unit with Never = Io.println(\"ran\")\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/atoms.ern"),
    {0, Output} = sh("../bin/ern run " ++ Dir ++ "/atoms.erc 2> " ++ Dir ++ "/err.txt"),
    ?assertEqual(<<"ran\n">>, Output),
    {ok, Said} = file:read_file(Dir ++ "/err.txt"),
    ?assertMatch({match, _},
                 re:run(Said, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z the host has used [0-9]+ of"
                              " its [0-9]+ atoms, which it never gives back\n$")).

%% report §11: the host's termination ends a job that runs no program at
%% once, by the signal, and the host prints nothing of its own. A
%% regression test: a build given it stopped where it was, printed the
%% host's report, and ended with status 0 as if it had built everything.
%% The tree is large enough that the signal comes while it builds, once
%% its first module is written. It does not cover a signal that comes as
%% the host itself starts, which the host drops (docs/otp_bugs.md, report 2)
job_signal_end_test_() ->
    {timeout, 60, fun job_signal_end/0}.

job_signal_end() ->
    Dir = "build/job_signal_end",
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/tree"),
    [ok = file:write_file(Dir ++ "/tree/m" ++ integer_to_list(Number) ++ ".ern",
                          "export fn f(n : Int) : Int = n + " ++ integer_to_list(Number) ++ "\n")
     || Number <- lists:seq(1, 100)],
    Python = "import subprocess, signal, os, time\n"
             "out = '" ++ Dir ++ "/out'\n"
             "p = subprocess.Popen(['../bin/ern', 'build', '--build-root', out,"
             " '" ++ Dir ++ "/tree'], stderr=subprocess.PIPE)\n"
             "while not (os.path.isdir(out) and any(f.endswith('.erc')"
             " for f in os.listdir(out))):\n"
             "    time.sleep(0.01)\n"
             "p.send_signal(signal.SIGTERM)\n"
             "_, err = p.communicate(timeout=30)\n"
             "print(p.returncode, err.decode())\n",
    ok = file:write_file(Dir ++ "/job.py", Python),
    ?assertEqual({0, <<"-15 \n">>}, sh("python3 " ++ Dir ++ "/job.py")).

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test_() ->
    {timeout, 60, fun modules/0}.

modules() ->
    {0, _} = sh("../bin/ern build --build-root build/modules programs/modules"),
    {0, Output} = sh("../bin/ern run build/modules/main.erc"),
    ?assertEqual(expected("modules"), lines(Output)).

%% report §4.9, §3.5, §5.6, Appendix E.25, E.26, proposals/operations/operations.md: the
%% note's three programs, its directory built as a source root over the
%% standard library's ordered set and map, each print what the note says, in
%% order. Written after the code, which they were built against first.
-define(OPERATIONS, ["usage", "numeric", "num"]).

operations_test_() ->
    {timeout, 120, fun operations/0}.

operations() ->
    {0, _} = sh("../bin/ern build --build-root build/operations ../proposals/operations/programs"),
    lists:foreach(fun(Name) ->
                      {0, Output} = sh("../bin/ern run build/operations/" ++ Name ++ ".erc"),
                      {ok, Expected} = file:read_file("expected/operations/" ++ Name ++ ".out"),
                      ?assertEqual({Name, in_order(Expected)}, {Name, in_order(Output)})
                  end, ?OPERATIONS).

in_order(Bytes) ->
    binary:split(Bytes, <<"\n">>, [global, trim]).

%% report §11.6: `ern format -` lays out standard input onto standard
%% output; with --check it names `-` if the module is not laid out; a
%% module that does not parse gives its diagnostic under the name `-` on
%% standard error, itself as it came on standard output, and the status 1;
%% and `-` stands alone. A regression test, written after the code, and of
%% the module that did not parse, which wrote nothing to standard output,
%% and of `- x.ern`, which was refused as a missing file `-`.
format_input_test_() ->
    {timeout, 60, fun format_input/0}.

format_input() ->
    Loose = "sh -c 'printf \"fn f(x) = x+1\\n\" | ../bin/ern format ",
    ?assertEqual({0, <<"fn f(x) =\n    x + 1\n">>}, sh(Loose ++ "-'")),
    ?assertEqual({1, <<"-\n">>}, sh(Loose ++ "--check -'")),
    Broken = "sh -c 'printf \"fn h( = 1\\n\" | ../bin/ern format --short-errors -",
    ?assertEqual({1, <<"-:1:7: expected a pattern instead of `=`\n">>},
                 sh(Broken ++ " >/dev/null'")),
    ?assertEqual({1, <<"fn h( = 1\n">>}, sh(Broken ++ " 2>/dev/null'")),
    {_, Alone} = sh("../bin/ern format - ../examples/hello.ern"),
    ?assertMatch({_, _}, binary:match(Alone, <<"- stands alone, for standard input">>)).

%% report §11.6, §11.5: what the toolchain writes is UTF-8 whatever the
%% host's locale. A regression test: under the C locale a laid-out module
%% and a diagnostic's source line came out as Latin-1 and escapes
%%; the ports of MVP 2.95 had fixed it unseen
locale_test_() ->
    {timeout, 60, fun locale/0}.

locale() ->
    Source = <<"let s = \"caf", 16#C3, 16#A9, " ", 16#E2, 16#80, 16#A2, "\"\n">>,
    File = "build/locale.ern",
    ok = file:write_file(File, Source),
    ?assertEqual({0, Source}, sh("sh -c 'LC_ALL=C LANG=C ../bin/ern format - < " ++ File ++ "'")),
    ok = file:write_file(File, <<"let s : Int = \"caf", 16#C3, 16#A9, "\"\n">>),
    {1, Output} = sh("sh -c 'LC_ALL=C LANG=C ../bin/ern build --source-root build " ++ File ++ "'"),
    ?assertMatch({_, _}, binary:match(Output, <<"1 | let s : Int = \"caf", 16#C3, 16#A9, "\"">>)).

expected(Name) ->
    {ok, Bytes} = file:read_file("expected/" ++ Name ++ ".out"),
    lines(Bytes).

lines(Bytes) ->
    lists:sort(binary:split(Bytes, <<"\n">>, [global, trim])).

%% Report §11.2: `ern run`'s fault lines as a terminal shows them, without
%% the time a line begins with where standard error is a file or a pipe,
%% as it is here; stamped_test_ checks the time itself.
unstamped(Lines) ->
    lists:sort([re:replace(Line, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z ", "", [{return, binary}])
                || Line <- Lines]).

%% A build in this node, as `ern build` does it: a launch of `ern` costs
%% the start of a host, which the builds here, which only ready what a test
%% runs through the launcher, need not pay. The launcher's own build is
%% tested where it is the point, a word it refuses and a directory's build.
build(Args) ->
    ern_cli:ern(["build" | string:lexemes(Args, " ")], group_leader()).

sh(Command) ->
    sh(Command, []).

sh(Command, Options) ->
    Shell = open_port({spawn, Command}, [exit_status, stderr_to_stdout, binary | Options]),
    collect(Shell, []).

collect(Program, Acc) ->
    receive
        {Program, {data, Data}} -> collect(Program, [Data | Acc]);
        {Program, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.
