%% The toolchain as a user runs it, through bin/ern: the examples and the
%% test programs built and run, their output compared as a multiset of lines with
%% fixtures/expected/<name>.out, since prints from different processes interleave
%% by scheduling; the launcher, the signals and the streams; `Os`; the
%% libraries' tests; and docs/proposals/operations/programs/. Run from this
%% directory by its Makefile. The helpers that run a command and build are
%% exported for ern_manual_tests and ern_install_tests, the manual pages'
%% tests and the installation's, which run as parts of their own.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

-export([del/1, build/1, sh/1, sh/2, succeed/1, succeed/2]).

%% Report §11.1: an example compiled into test/build.
%% libs/ansi, which snake writes with (report Appendix G.3)
-define(BUILD, "--source-root ../examples --load-path ../build/libs/ansi --build-root build ").

%% A program kept for the tests, compiled into test/build.
-define(BUILD_PROGRAM, "--source-root fixtures/programs --build-root build ").

%% The examples that end of themselves given nothing, and the programs kept
%% for the tests. Every other example is built and run, or connected to, by
%% a test of its own below, snake but played by ern_terminal_tests.
-define(EXAMPLES, ["hello", "typed_channels_nodes"]).
-define(PROGRAMS, ["counter", "upgrade", "pingpong", "stack", "patterns", "kv_parser"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (pingpong),
%% §6.6 (counter), §6.10 (upgrade), §5.10 (patterns), §5.5 (kv_parser),
%% §4.4 (stack), §8.7 (typed_channels_nodes, run alone, which is no node,
%% its find answering NotListed); typed_channels_nodes is a regression
%% test written with it
%% Each program is compiled and run apart from the others, so they run in
%% parallel (plan, MVP 2.6).
programs_test_() ->
    {inparallel,
     [{Name, {timeout, 60, fun() -> program(?BUILD ++ "../examples/", Name) end}}
      || Name <- ?EXAMPLES]
     ++ [{Name, {timeout, 60,
                 fun() -> program(?BUILD_PROGRAM ++ "fixtures/programs/", Name) end}}
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
     ++ [{"echo", {timeout, 60,
                   fun() -> compiles(?BUILD_PROGRAM ++ "fixtures/programs/", "echo") end}}]}.

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
    ?assertEqual({0, <<"2 5 24 fixtures/input/two_lines.txt\n2 5 24 total\n">>},
                 sh("../bin/ern run build/tally.erc fixtures/input/two_lines.txt")),
    ?assertEqual({1, <<"tally: fixtures/input/absent.txt: no such file\n"
                       "2 5 24 fixtures/input/two_lines.txt\n2 5 24 total\n">>},
                 sh("../bin/ern run build/tally.erc fixtures/input/absent.txt"
                    " fixtures/input/two_lines.txt")),
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

%% report §6.5, §6.6, §6.9, Appendix E.22: services reads a command a line
%% from standard input and ends at its end; a take of more than the store
%% holds faults the store, the call waiting on it answering nothing, and
%% RestForOne restarts it with the two services spawned after it, each
%% reached by its name and answering from its first state, the restart's
%% line on standard error naming the store's declaration; a line that is no
%% command is answered with the commands. A regression test, written with
%% the example. After the fault the input asks the store first, which
%% answers once its group has restarted whole (Appendix E.22); a command
%% that asks the audit before the restart is done is not covered
services_test_() ->
    {timeout, 60, fun services/0}.

services() ->
    0 = build(?BUILD ++ "../examples/services.ern"),
    {0, Output} = sh("../bin/ern run build/services.erc < fixtures/input/services.in"),
    ?assertEqual(expected("services"), untraced(unstamped(lines(Output)))).

%% report §3.5, §4.9, §5.6, Appendix E.3, E.26: word_count counts the words
%% of the file its command line names in both maps, the ordered map's
%% alphabetically and the hash map's in an order E.3 leaves unspecified,
%% so the two lines are compared as sets of counts; with no file it says
%% how it is called, status 2, and a file it cannot read is named on
%% standard error, status 1. A regression test, written with the example
word_count_test_() ->
    {timeout, 60, fun word_count/0}.

word_count() ->
    0 = build(?BUILD ++ "../examples/word_count.ern"),
    {0, Output} = sh("../bin/ern run build/word_count.erc fixtures/input/words.txt"),
    [<<"by hash: ", Hashed/binary>>, <<"in order: ", Ordered/binary>>, Frequent] =
        binary:split(Output, <<"\n">>, [global, trim]),
    ?assertEqual(<<"and 1, cat 1, dog 1, log 1, mat 1, on 2, sat 2, the 4">>, Ordered),
    ?assertEqual(lists:sort(binary:split(Ordered, <<", ">>, [global])),
                 lists:sort(binary:split(Hashed, <<", ">>, [global]))),
    ?assertEqual(<<"most frequent: the, sat">>, Frequent),
    ?assertEqual({2, <<"usage: word_count file\n">>}, sh("../bin/ern run build/word_count.erc")),
    ?assertEqual({1, <<"word_count: fixtures/input/absent.txt: NotFound\n">>},
                 sh("../bin/ern run build/word_count.erc fixtures/input/absent.txt")).

%% report §6.10, §8.7, §11.1, Appendix E.28: the upgrade example's two
%% builds of one module, each built as a directory, as its first comment
%% builds it; the second, run alone, which is no node, moves a counter of
%% its own and has no peer. The first is a node's counter, which
%% ern_deployment_tests runs beside the second's tool. A regression test,
%% written with the example
upgrade_example_test_() ->
    {timeout, 60, fun upgrade_example/0}.

upgrade_example() ->
    [0 = build("--build-root build/upgrade/" ++ Build ++ " ../examples/upgrade/" ++ Build)
     || Build <- ["v1", "v2"]],
    ?assert(filelib:is_regular("build/upgrade/v1/counter.erc")),
    {0, Output} = sh("../bin/ern run build/upgrade/v2/counter.erc"),
    ?assertEqual(lists:sort([<<"here: 1 moved">>, <<"inc 3">>, <<"total: Some(5)">>]),
                 unstamped(lines(Output))).

%% Paper program 4 (plan, MVP 2.5): the REPL reads stdin and ends at
%% end of input, so its run is bounded by its input. The last two lines are
%% the point of the program: an expression that does not terminate is killed
%% after two seconds, and the next expression still works.
%% report §6.9 (monitor), §8.2 (Io's stdin), Appendix E.1 (Io.readLine)
repl_test_() ->
    {timeout, 60, fun repl/0}.

repl() ->
    0 = build(?BUILD ++ "../examples/repl.ern"),
    {0, Output} = sh("../bin/ern run build/repl.erc < fixtures/input/repl.in"),
    ?assertEqual(expected("repl"), lines(Output)).

%% Paper program 2 (plan, MVP 2.5): the syncer runs until it is
%% stopped, so the harness gives it two prepared directories, lets it run,
%% stops it, and reads the directories back. One file on each side crosses,
%% and the pair that differs leaves a conflict beside the newer copy.
%% report §8.2 (Fs's reference), §6.6 (Address.call), Appendix E.17 (Fs.list)
%% Its steps: the build, its own tests' run, run_for/4's wait and the end.
file_sync_test_() ->
    {timeout, waits(4), fun file_sync/0}.

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
    Mtime = fun(Relative) ->
                {ok, #file_info{mtime = Seconds}} = file:read_file_info(Dir ++ Relative,
                                                                        [{time, posix}]),
                Seconds
            end,
    %% stopped once both directories are as the checks below read them,
    %% since how long a pass takes is the host's: a file stored is asked
    %% for with its time, since the end stops a writer that has not yet
    %% set it
    Synced = fun() ->
                 has_printed(Dir, <<"conflict: notes.txt">>)
                     andalso file:read_file(Dir ++ "/b/greeting.txt") =:= {ok, <<"hello from a\n">>}
                     andalso file:read_file(Dir ++ "/a/other.txt") =:= {ok, <<"only in b\n">>}
                     andalso file:read_file(Dir ++ "/a/notes.txt") =:= {ok, <<"new note\n">>}
                     andalso filelib:is_regular(Dir ++ "/b/notes.txt.conflict")
                     andalso Mtime("/a/greeting.txt") =:= Mtime("/b/greeting.txt")
                     andalso Mtime("/b/other.txt") =:= Mtime("/a/other.txt")
             end,
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
    ?assertEqual(Mtime("/a/greeting.txt"), Mtime("/b/greeting.txt")),
    ?assertEqual(Mtime("/b/other.txt"), Mtime("/a/other.txt")).

%% file_sync: a file from the peer is checked against the file here as it
%% stands when the file arrives, before the first listing too. A regression
%% test, written after the fix (plan, MVP 2.99b's item 1): b's listing,
%% slowed by fifty files more, came after a's older notes.txt, which then
%% replaced b's newer copy with no conflict. It does not reach a file
%% changed here between two listings, which the same reading covers. Its
%% steps: the build, run_for/4's wait and the end.
file_sync_first_listing_test_() ->
    {timeout, waits(3), fun file_sync_first_listing/0}.

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
    Synced = fun() ->
                 has_printed(Dir, <<"conflict: notes.txt">>)
                     andalso file:read_file(Dir ++ "/b/notes.txt.conflict")
                             =:= {ok, <<"old note\n">>}
                     andalso file:read_file(Dir ++ "/a/notes.txt") =:= {ok, <<"new note\n">>}
             end,
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

%% A directory removed whole, each directory under it made writable first,
%% since a test that ended early, its time run out, may leave one
%% read-only, and nothing in one can be removed: the install test's
%% `closed`, so left, stopped the next run's cleanup with `eexist`.
del(Dir) ->
    opened(Dir),
    case file:del_dir_r(Dir) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% Each directory under Path, Path among them, made writable and readable by
%% its owner, a link left as it is.
opened(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = directory, mode = Mode}} ->
            ok = file:change_mode(Path, Mode bor 8#700),
            {ok, Names} = file:list_dir_all(Path),
            lists:foreach(fun(Name) -> opened(filename:join(Path, Name)) end, Names);
        _ ->
            ok
    end.

%% del/1 removes a tree that holds a read-only directory with a file in it,
%% as a test that ran out of time leaves one. A regression test, written on
%% 2026-10-16 after the install test's `closed` stopped the next run's
%% cleanup with `eexist`; a directory another user owns is not covered.
del_read_only_test() ->
    Dir = filename:absname("build/del_read_only"),
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/closed/x"),
    ok = file:write_file(Dir ++ "/closed/x/file", <<"held\n">>),
    ok = file:change_mode(Dir ++ "/closed", 8#555),
    ok = del(Dir),
    ?assertNot(filelib:is_dir(Dir)).

%% A program that runs until it is stopped: started in Dir, its standard
%% output and standard error written to run.out there, and stopped with the
%% signal named once Until() holds. Until is asked again at each change of
%% the files under Dir, a line the program writes among them, so that a
%% test can wait for a file the program writes without a word. Where it
%% does not hold within one step of the harness's
%% (ern_nodes_tests:wait_ms/0), the signal is sent then, and the test's
%% checks say what did not come. Its status and its output are returned.
run_for(Dir, Command, Until, Signal) ->
    Out = filename:join(Dir, "run.out"),
    %% an earlier run's output goes first, since Until may read it before
    %% the program has written anything
    _ = file:delete(Out),
    Changes = changes(Dir),
    Program = open_port({spawn, Command ++ " > run.out 2>&1"}, [exit_status, {cd, Dir}]),
    Deadline = erlang:monotonic_time(millisecond) + ern_nodes_tests:wait_ms(),
    Waited = waited(Changes, Program, Until, Deadline),
    port_close(Changes),
    Status = case Waited of
                 {ended, Ended} ->
                     Ended;
                 due ->
                     {os_pid, ProcessNumber} = erlang:port_info(Program, os_pid),
                     _ = sh("kill -" ++ Signal ++ " " ++ integer_to_list(ProcessNumber)),
                     ended(Program, ProcessNumber)
             end,
    {ok, Output} = file:read_file(Out),
    {Status, lines(Output)}.

%% The status of the program the port Program runs, once it has ended
%% after its signal, or once it is killed one step of the harness's later,
%% 137, so that a program that does not end at its signal fails the test
%% and is not left running.
ended(Program, ProcessNumber) ->
    receive
        {Program, {exit_status, Status}} -> Status
    after ern_nodes_tests:wait_ms() ->
        _ = sh("kill -KILL " ++ integer_to_list(ProcessNumber)),
        receive {Program, {exit_status, Status}} -> Status end
    end.

%% The signal due once Until() holds, asked again at each change the port
%% Changes says, or once the deadline has come; ended where the program the
%% port Program runs has ended first.
waited(Changes, Program, Until, Deadline) ->
    case Until() of
        true ->
            due;
        false ->
            receive
                {Changes, {data, {eol, <<"changed">>}}} ->
                    waited(Changes, Program, Until, Deadline);
                {Program, {exit_status, Status}} ->
                    {ended, Status}
            after max(0, Deadline - erlang:monotonic_time(millisecond)) ->
                due
            end
    end.

%% A port that says `changed` at each change of the files under Dir, once
%% it watches them (ern_changes.py).
changes(Dir) ->
    Changes = open_port({spawn, "./ern_changes.py " ++ Dir}, [{line, 16}, binary, exit_status]),
    receive
        {Changes, {data, {eol, <<"ready">>}}} -> Changes;
        {Changes, {exit_status, Status}} -> erlang:error({not_watched, Dir, Status})
    end.

%% Whether the program run_for/4 runs in Dir has printed Line whole.
has_printed(Dir, Line) ->
    case file:read_file(filename:join(Dir, "run.out")) of
        {ok, Output} -> lists:member(Line, lines(Output));
        {error, enoent} -> false
    end.

%% report §8.6, §11.2: the host's hangup ends a program as its termination
%% does, printing nothing, with status 128 plus the signal's number. A
%% regression test: the hangup was ignored, and the program ran on. The
%% hangup is sent once the program has said it runs, as signal_end's are.
%% Its steps: the build, run_for/4's wait and the end.
hangup_test_() ->
    {timeout, waits(3), fun hangup/0}.

hangup() ->
    Dir = "build/hangup",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() : Unit receiving Never = {\n"
                         "    Io.println(\"running\");\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    ?assertEqual({129, [<<"running">>]},
                 run_for(Dir, "../../../bin/ern run waits.erc",
                         fun() -> has_printed(Dir, <<"running">>) end, "HUP")).

%% report §10, §11.8: a program that exhausts the host's memory ends at
%% once, the process that monitored the one that grew never told, with
%% status 1 and the host's message, and no crash dump is left in the
%% working directory. The limit is the shell's on the virtual memory, which
%% the host meets within a second. A regression test of the full review's
%% U1 (2026-10-04): the guide called it a fault of one process, and the host
%% wrote its dump where the program ran. Under `make sanitize` the helper is
%% built with the address sanitizer, whose shadow memory no limit on the
%% virtual memory admits, so the helper itself fails at start; the test
%% runs where the helper is the plain build, in `make test-full`
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
                         "export fn main() : Unit receiving Msg = {\n"
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
                         "export fn main() : Unit = {\n"
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

%% report Appendix E.18, §8.6: shout listens on the port the system gives
%% it, which it prints, answers each line a client sends in capitals, a
%% connection's lines one after another, and serves until it is stopped. A
%% regression test, written when the example became a server; it does not
%% cover a line that arrives in parts, a line that is no UTF-8 text, nor a
%% connection silent past the server's minute
shout_test_() ->
    {timeout, 60, fun shout/0}.

shout() ->
    0 = build(?BUILD ++ "../examples/shout.ern"),
    Server = open_port({spawn, "../bin/ern run build/shout.erc"},
                       [exit_status, stderr_to_stdout, binary]),
    {os_pid, OsPid} = erlang:port_info(Server, os_pid),
    try
        Port = listening_port(Server, <<>>),
        {ok, Socket} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false},
                                                           {packet, line}], 5000),
        ok = gen_tcp:send(Socket, <<"hello\n">>),
        ?assertEqual({ok, <<"HELLO\n">>}, gen_tcp:recv(Socket, 0, 5000)),
        ok = gen_tcp:send(Socket, <<"ernest\n">>),
        ?assertEqual({ok, <<"ERNEST\n">>}, gen_tcp:recv(Socket, 0, 5000)),
        gen_tcp:close(Socket)
    after
        os:cmd("kill " ++ integer_to_list(OsPid)),
        try port_close(Server) catch _:_ -> true end
    end.

%% The port a server the port runs says it listens on, once its line has
%% arrived whole; 30 seconds bound a failure, as said_line/3's do.
listening_port(Server, Said) ->
    case re:run(Said, "listening on 127\\.0\\.0\\.1:([0-9]+)\n",
                [{capture, all_but_first, list}]) of
        {match, [Digits]} ->
            list_to_integer(Digits);
        nomatch ->
            receive {Server, {data, Bytes}} -> listening_port(Server, <<Said/binary, Bytes/binary>>)
            after 30000 -> erlang:error({not_said, Said})
            end
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

%% report §9.3, §11.2, Appendix G.2, G.4, G.6, G.7, Appendix G.5, plan MVP
%% 3.2: every library's own tests, run by `ern test` over the directory
%% their compiled modules are under, as the shell's are: the Markdown
%% library's read and lay out what G.2 says, the Utilization library's
%% measure as G.4 says, the JSON library's read and write what G.6 says,
%% and the proxy's wait for its service as G.7 says, and no module of the
%% placement library, which G.5 says is removed; every library's doc
%% examples after its tests (report §11.2, Appendix E.0 shape rule 6); no
%% test's process faults. A
%% regression test too: the modules were run by one command joined with
%% `&&`, which the host runs by `exec`, so only the first module's tests
%% ran, and it has none
libs_test_() ->
    {timeout, 60, fun libs/0}.

libs() ->
    {Status, Output} = sh("../bin/ern test --load-path ../build/libs/ansi ../build/libs"),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    Passed = [Line || Line <- Lines, binary:match(Line, <<": passed">>) =/= nomatch],
    ?assertEqual([], [Line || Line <- Lines, binary:match(Line, <<" faulted: ">>) =/= nomatch]),
    %% a module with tests or examples is named before them, and one with
    %% neither is passed over (report §11.2)
    ?assertEqual([<<"Ansi">>, <<"Ets">>, <<"Json">>, <<"Markdown">>, <<"Proxy">>,
                  <<"Utilization">>],
                 Lines -- Passed),
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
                         "export fn main() : Unit = {\n"
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
                         "export fn main() : Unit = {\n"
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
%% faults; lines and bytes are one stream, and bytes go out as they are.
%% Its steps: three builds and four runs.
stdin_test_() ->
    {timeout, waits(7), fun stdin/0}.

stdin() ->
    [0 = build("--source-root fixtures/stdin --build-root build/stdin fixtures/stdin/"
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
                 untraced(unstamped(lines(Said)))),
    ?assertEqual({0, <<"head\n", 255, 16#e9/utf8, "tail\nbytes 8\n">>},
                 Launch("head\\n\\377\\303\\251tail\\n", "stream")),
    %% a read does not wait for more than has arrived: the second byte is
    %% written once the program's line that it read the first is read from
    %% the FIFO its output goes to, so that how long the host takes to
    %% start, about as long as the one second the writer had paused, plays
    %% no part (it had failed when the start took longer); the status is the
    %% program's. Its run is one step of the harness's (wait_seconds/0), so
    %% that a read that waits for more, which never says its line, is
    %% killed and fails the test, and is not left running
    {In, Out} = {fifo("build/stdin/in"), fifo("build/stdin/out")},
    ?assertEqual({0, <<"1\n1\nend\n">>},
                 sh("sh -c 'timeout -s KILL " ++ integer_to_list(wait_seconds())
                    ++ " ../bin/ern run build/stdin/chunks.erc < " ++ In ++ " > " ++ Out
                    ++ " & p=$!; exec 3> " ++ In ++ " 4< " ++ Out ++ "; printf a >&3; "
                    "read first <&4; printf b >&3; exec 3>&-; echo \"$first\"; cat <&4; "
                    "wait $p'")).

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
                         "export fn main() : Unit = {\n"
                         "    Io.println(Io.show(Os.arguments));\n"
                         "    Os.exit(List.size(Os.arguments))\n"
                         "}\n"),
    ok = file:write_file(SourceRoot ++ "/env.ern",
                         "export fn main() : Unit = {\n"
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
           ["export fn main() : Unit = {\n"
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
                         "export fn main() : Unit =\n"
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
                         "export fn main() : Unit = Io.println(Int.toString(stub()))\n"),
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
                         "export fn main() : Unit = {\n"
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

%% report §11, docs/design/install.md: the launcher needs `iconv` to read the
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
                         "fn loop(n : Int) : Unit =\n"
                         "    if n == 0 then Io.printlnError(\"finished\")\n"
                         "    else { Io.println(\"line\"); loop(n - 1) }\n"
                         "export fn main() : Unit = loop(100000000)\n"),
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
%% ended with status 0, ten with 141, and three did not end. The reader
%% closes its end of the pipe and then says so through a FIFO, which the
%% program's side waits on before the program starts. Each run is one step
%% of the harness's (wait_seconds/0), after which a program that has not
%% ended is killed, its status 137 then among the others'. Its steps:
%% three builds and nine runs. It does not cover a device that fails,
%% which only some hosts have one of, nor a reader that goes while the
%% program writes, which drained_output_test_ holds.
stream_lost_at_end_test_() ->
    {timeout, waits(12), fun stream_lost_at_end/0}.

stream_lost_at_end() ->
    Dir = "build/lost",
    ok = filelib:ensure_path(Dir),
    Programs = [{"out", "Io.println(\"written\")", ""},
                {"err", "Io.printlnError(\"written\")", "2>&1 "},
                {"exit", "{ Io.println(\"written\"); Os.exit(3) }", ""}],
    [begin
         ok = file:write_file(Dir ++ "/" ++ Name ++ ".ern",
                              "export fn main() : Unit = " ++ Body ++ "\n"),
         0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/" ++ Name ++ ".ern")
     end || {Name, Body, _} <- Programs],
    %% the reader has gone before the program writes: it closes the pipe's
    %% one read end, then writes to the FIFO the program's side reads first
    Gone = fifo(Dir ++ "/gone"),
    Statuses = [begin
                    {0, <<>>} = sh("sh -c '{ read gone < " ++ Gone ++ "; timeout -s KILL "
                                   ++ integer_to_list(wait_seconds()) ++ " ../bin/ern run "
                                   ++ Dir ++ "/" ++ Name ++ ".erc " ++ Redirect
                                   ++ "; echo $? > " ++ Dir ++ "/status; } | { exec <&-; echo > "
                                   ++ Gone ++ "; }'"),
                    {ok, Status} = file:read_file(Dir ++ "/status"),
                    ok = file:delete(Dir ++ "/status"),
                    {Name, Status}
                end || {Name, _, Redirect} <- Programs, _ <- [1, 2, 3]],
    ?assertEqual([{Name, <<"141\n">>} || {Name, _, _} <- Programs, _ <- [1, 2, 3]], Statuses).

%% report §8.2, §8.6, §11.8: the end of a program waits until its stream's
%% port has written what the program wrote, its reader taking a byte at a
%% time, slower than the program writes, so that the port still holds most
%% of it as the program returns: all of it is read and the run's status is
%% 0; and where the reader goes while the end waits, the stream that could
%% not be written ends the program with status 141, on standard output and
%% on standard error. A regression test, written after the code: the end
%% polled the port's queue every millisecond (the log's *The Sitting on
%% §8.6's Bookkeeping*); an end that did not wait gave status 0, since the
%% host's halt writes what a port holds. It does not cover a device that
%% fails, which only some hosts have one of.
drained_output_test_() ->
    {timeout, 60, fun drained_output/0}.

drained_output() ->
    Dir = "build/drained",
    ok = del(Dir),
    ok = filelib:ensure_path(Dir),
    Count = 200000,
    Programs = [{"out", "Io.println", ""}, {"err", "Io.printlnError", "2>&1 >/dev/null "}],
    [begin
         ok = file:write_file(Dir ++ "/" ++ Name ++ ".ern",
                              ["export fn main() : Unit = ", Print, "(String.repeat(\"a\", ",
                               integer_to_list(Count), "))\n"]),
         0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/" ++ Name ++ ".ern"),
         Run = "{ ../bin/ern run " ++ Dir ++ "/" ++ Name ++ ".erc " ++ Redirect ++ "; echo $? > "
               ++ Dir ++ "/status; } | dd bs=1 ",
         ?assertEqual({0, iolist_to_binary([binary:copy(<<"a">>, Count), "\n"])},
                      sh("sh -c '" ++ Run ++ "status=none'")),
         ?assertEqual({Name, {ok, <<"0\n">>}}, {Name, file:read_file(Dir ++ "/status")}),
         %% the reader goes after 70,000 bytes, leaving more than the pipe
         %% holds unwritten
         {0, <<>>} = sh("sh -c '" ++ Run ++ "count=70000 of=/dev/null status=none'"),
         ?assertEqual({Name, {ok, <<"141\n">>}}, {Name, file:read_file(Dir ++ "/status")})
     end || {Name, Print, Redirect} <- Programs].

%% report §11, §11.8: a job ends once what it wrote is written, its reader
%% taking a byte at a time: `ern format -` writes a module of more than a
%% pipe holds, read whole with status 0, and where the reader goes while
%% the job's end waits, the job ends with status 141. A regression test,
%% written after the code: the job's end polled its port's queue every
%% millisecond (the log's *The Sitting on §8.6's Bookkeeping*); an end that
%% did not wait gave status 0.
job_output_drained_test_() ->
    {timeout, 60, fun job_output_drained/0}.

job_output_drained() ->
    Dir = "build/job_drained",
    ok = del(Dir),
    ok = filelib:ensure_path(Dir),
    Source = [["fn f", integer_to_list(N), "(x : Int) : Int = x + ", integer_to_list(N), "\n\n"]
              || N <- lists:seq(1, 7000)],
    ok = file:write_file(Dir ++ "/many.ern", Source),
    Run = "{ ../bin/ern format - < " ++ Dir ++ "/many.ern; echo $? > " ++ Dir
          ++ "/status; } | dd bs=1 ",
    {0, Formatted} = sh("sh -c '" ++ Run ++ "status=none'"),
    ?assertEqual({ok, <<"0\n">>}, file:read_file(Dir ++ "/status")),
    ?assert(byte_size(Formatted) > 70000 + 65536),
    %% the reader goes after 70,000 bytes, leaving more than the pipe holds
    %% unwritten
    {0, <<>>} = sh("sh -c '" ++ Run ++ "count=70000 of=/dev/null status=none'"),
    ?assertEqual({ok, <<"141\n">>}, file:read_file(Dir ++ "/status")).

%% report §8.2: a program writing faster than its reader reads is held to
%% the reader's pace, so what it has written and the reader has not taken
%% is not held in the node. A regression test, written after the code: two
%% million lines to a pipe read late held about 650 MB, where the node
%% itself takes under 100. The reader takes a twentieth of the program's
%% lines a byte at a time, then stops and says so, holding the pipe open;
%% the node's memory is read at that word, and the reader then goes, which
%% ends the program with status 141. A byte at a time, the reader takes
%% about a twenty-fourth of what a program not held to its pace writes, so
%% such a program has written all its lines by the reader's word: made so,
%% its print a send to a stream that queued, the node held 683 MB there,
%% and held to its pace 84. It does not cover a reader that takes nothing,
%% nor standard error.
paced_output_test_() ->
    {timeout, 60, fun paced_output/0}.

paced_output() ->
    Dir = "build/paced",
    ok = del(Dir),
    ok = filelib:ensure_path(Dir),
    Lines = 2000000,
    ok = file:write_file(Dir ++ "/flood.ern",
                         ["fn loop(n : Int) : Unit =\n"
                          "    if n == 0 then Unit\n"
                          "    else { Io.println(\"a line of output a slow reader takes late\");\n"
                          "        loop(n - 1) }\n"
                          "export fn main() : Unit = loop(", integer_to_list(Lines), ")\n"]),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/flood.ern"),
    Line = byte_size(<<"a line of output a slow reader takes late\n">>),
    {Taken, Go} = {fifo(Dir ++ "/taken"), fifo(Dir ++ "/go")},
    Reader = "{ dd bs=1 count=" ++ integer_to_list(Lines div 20 * Line) ++ " of=/dev/null "
             "status=none; echo > " ++ Taken ++ "; read go < " ++ Go ++ "; }",
    {0, Output} = sh("sh -c '{ ../bin/ern run " ++ Dir ++ "/flood.erc; echo $? > " ++ Dir
                     ++ "/status; } | " ++ Reader ++ " & read taken < " ++ Taken ++ "; "
                     "ps -eo rss,comm,args | grep \"beam.smp.*[f]lood.erc\" | head -1; "
                     "echo > " ++ Go ++ "; wait'"),
    [Rss | _] = string:lexemes(binary_to_list(Output), " \n"),
    ?assert(list_to_integer(Rss) < 250000),
    ?assertEqual({ok, <<"141\n">>}, file:read_file(Dir ++ "/status")).

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
                         "export fn main() : Unit = Io.println(Int.toString(n()))\n"),
    {0, _} = sh(Ern ++ " build --source-root " ++ Dir ++ "/prog " ++ Dir ++ "/prog/which.ern"),
    ?assertEqual({0, <<"1\n">>}, sh(Ern ++ " run ../prog/which.erc", [{cd, Dir ++ "/work"}])).

%% report §11: a job whose standard output or standard error has no reader
%% any more ends at once with status 141, and leaves no crash dump. A
%% regression test: every job but a program's run halted the host, which
%% wrote erl_crash.dump into the working directory; the release review
%% found the shell in line mode ending with status 0 and the host's report
%% of the failed write. The reader closes its end of the pipe and then says
%% so through a FIFO, which the job's side waits on before the job starts.
%% It does not cover a reader that goes while the job writes, nor one
%% stream gone and the other read
closed_pipe_test_() ->
    {timeout, 60, fun closed_pipe/0}.

closed_pipe() ->
    Dir = filename:absname("build/closed_pipe"),
    ok = del(Dir),
    ok = filelib:ensure_path(Dir),
    Ern = filename:absname("../bin/ern"),
    Gone = fifo(Dir ++ "/gone"),
    Closed = "{ exec <&-; echo > " ++ Gone ++ "; }",
    StatusOf = fun(Job) ->
                   {0, _} = sh("sh -c 'cd " ++ Dir ++ " && ( read gone < " ++ Gone ++ "; " ++ Ern
                               ++ " " ++ Job ++ " 2>&1; echo $? > status ) | " ++ Closed ++ "'"),
                   {ok, Text} = file:read_file(Dir ++ "/status"),
                   string:trim(Text)
               end,
    [?assertEqual({Job, <<"141">>}, {Job, StatusOf(Job)})
     || Job <- ["--version", "--help", "build missing.ern", "run missing.erc", "test --help",
                "doc " ++ filename:absname("../src/stdlib/list.ern"), "shell < /dev/null"]],
    ?assertNot(filelib:is_file(Dir ++ "/erl_crash.dump")),
    {0, _} = sh("sh -c 'cd " ++ Dir ++ " && ( read gone < " ++ Gone ++ "; echo 1 | " ++ Ern
                ++ " shell 2> err; echo $? > status ) | " ++ Closed ++ "'"),
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
%% its escape, so that a fault is one line, its trace beneath it. A
%% regression test: a cause's line feed wrote a second line, which forged
%% another fault, and its escape reached the terminal as itself
fault_line_escaped_test_() ->
    {timeout, 60, fun fault_line_escaped/0}.

fault_line_escaped() ->
    Dir = "build/escaped",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/forged.ern",
                         "export fn main() : Unit =\n"
                         "    fault(\"a\\u{1b}[31m\\nX.main faulted: forged\")\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/forged.ern"),
    ErrorFile = Dir ++ "/err",
    {1, _} = sh("../bin/ern run " ++ Dir ++ "/forged.erc 2> " ++ ErrorFile),
    {ok, Text} = file:read_file(ErrorFile),
    ?assertMatch({_, _}, binary:match(Text, <<"Forged.main faulted: a\\u{1B}[31m\\nX.main"
                                              " faulted: forged\n">>)),
    ?assertEqual(1, length(untraced(binary:split(Text, <<"\n">>, [global, trim])))).

%% report §11.2: where standard error is a file, a fault line begins with
%% the time, in UTC as RFC 3339 writes it; where it is a service manager's
%% journal, as JOURNAL_STREAM names it, it does not, and a terminal's is
%% ern_terminal_tests' to show. Written with the code. Report §7.3, §11.2:
%% beneath the line its trace, a frame a line, indented by four spaces and
%% not stamped, a regression test written after the code, where a cause of
%% §7.4 had none
stamped_test_() ->
    {timeout, 60, fun stamped/0}.

stamped() ->
    Dir = "build/stamped",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/faulty.ern",
                         "export fn main() : Unit = {\n"
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
                                             "division by zero\n    erlang:'div'/2\n"
                                             "    Faulty\\.main:3\n(    [^\n]*\n)*$")),
    ok = file:write_file(ErrorFile, <<>>),
    {ok, #file_info{major_device = Device, inode = Inode}} = file:read_file_info(ErrorFile),
    {1, _} = sh("env JOURNAL_STREAM=" ++ integer_to_list(Device) ++ ":" ++ integer_to_list(Inode)
                ++ " ../bin/ern run " ++ Dir ++ "/faulty.erc 2> " ++ ErrorFile),
    ?assertMatch({ok, <<"Faulty.main faulted: division by zero\n    erlang:'div'/2\n"
                        "    Faulty.main:3\n", _/binary>>}, file:read_file(ErrorFile)).

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
                         "export fn main() : Unit receiving Never = {\n"
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
                         "export fn main() : Unit receiving Msg =\n"
                         "    match Os.arguments {\n"
                         "        [how, began] -> {\n"
                         "            let me = self();\n"
                         "            let _ = spawn(fn() : Unit receiving Msg = subscriber(how,"
                         " me));\n"
                         "            receive {\n"
                         "                Ready -> ended(began)\n"
                         "              | Terminating(reply) -> answer(reply, Unit)\n"
                         "            }\n"
                         "        }\n"
                         "      | _ -> Unit\n"
                         "    }\n"
                         "fn ended(began : String) : Unit receiving Msg =\n"
                         "    match began {\n"
                         "        \"termination\" -> {\n"
                         "            Io.println(\"running\");\n"
                         "            receive { Ready -> Unit }\n"
                         "        }\n"
                         "      | \"exit\" -> Os.exit(3)\n"
                         "      | _ -> Unit\n"
                         "    }\n"
                         "fn subscriber(how : String, main : Address(Msg)) : Unit receiving Msg"
                         " = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> told(how, reply)\n"
                         "      | Ready -> Unit\n"
                         "    }\n"
                         "}\n"
                         "fn told(how : String, reply : Reply(Unit)) : Unit receiving Msg = {\n"
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
                         "fn held(reply : Reply(Unit)) : Unit receiving Msg =\n"
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
                         "fn keeper(main : Address(Msg)) : Unit receiving Msg = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> {\n"
                         "            let _ = 1 / List.size([]);\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "    }\n"
                         "}\n"
                         "export fn main() : Unit receiving Msg = {\n"
                         "    let me = self();\n"
                         "    let _ = spawn(fn() : Unit receiving Msg = keeper(me));\n"
                         "    receive { Ready -> Unit }\n"
                         "}\n"),
    0 = build("--source-root " ++ Dir ++ " " ++ Dir ++ "/faulty.ern"),
    lists:foreach(
      fun(_) ->
          {0, Output} = sh("../bin/ern run " ++ Dir ++ "/faulty.erc"),
          ?assertEqual([<<"the end waits for 1 subscriber: Faulty.main:14">>,
                        <<"Faulty.main:14 faulted: division by zero">>,
                        <<"the subscriber Faulty.main:14 ended without answering">>],
                       untraced(unstamped_lines(Output)))
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
                         "fn hold(main : Address(Msg)) : Unit receiving Msg = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    receive {\n"
                         "        Terminating(reply) -> receive { Done -> answer(reply, Unit) }\n"
                         "    }\n"
                         "}\n"
                         "fn keeper(holder : Address(Msg), main : Address(Msg)) : Unit receiving"
                         " Msg"
                         " = {\n"
                         "    Os.termination(Terminating);\n"
                         "    send(main, Ready);\n"
                         "    count(holder, 0)\n"
                         "}\n"
                         "fn count(holder : Address(Msg), n : Int) : Unit receiving Msg ="
                         " receive {\n"
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
                         "export fn main() : Unit receiving Msg = {\n"
                         "    let me = self();\n"
                         "    let holder = spawn(fn() : Unit receiving Msg = hold(me));\n"
                         "    let limit = RestartLimit(restarts = 1, within = 5000);\n"
                         "    let k = spawn(restarting(limit, fn() : Unit receiving Msg"
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
    [Waits, Faulted, Restarted, Too | Answers] = untraced(unstamped_lines(Said)),
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
                 untraced(unstamped_lines(Said))).

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
    [Waits | Lines] = untraced(unstamped_lines(Said)),
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
                         "export fn main() : Unit receiving Msg =\n"
                         "    match Os.arguments {\n"
                         "        [\"termination\"] -> {\n"
                         "            Os.termination(Terminating);\n"
                         "            started();\n"
                         "            Io.println(\"running\");\n"
                         "            receive { Terminating(reply) -> answer(reply, Unit) }\n"
                         "        }\n"
                         "      | _ -> started()\n"
                         "    }\n"
                         "fn started() : Unit receiving Msg = {\n"
                         "    let me = self();\n"
                         "    let worker = spawn(fails);\n"
                         "    let _ = spawn(fn() : Unit receiving Msg = keeper(me, worker));\n"
                         "    receive { Ready -> Unit }\n"
                         "}\n"
                         "fn fails() : Unit receiving Order =\n"
                         "    receive {\n"
                         "        Fail -> {\n"
                         "            let _ = 1 / List.size([]);\n"
                         "            Unit\n"
                         "        }\n"
                         "    }\n"
                         "fn keeper(main : Address(Msg), worker : Address(Order)) : Unit"
                         " receiving Msg"
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
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
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
%% its first module is written, which the build's --verbose line says
%% (report §11.1), read as it is written; standard error holds no line
%% but the build's own. The build's end after the signal is one step of
%% the harness's (wait_seconds/0), after which it is killed, so that one
%% that does not end fails the test and is not left running. It does not
%% cover a signal that comes as the host itself starts, which the host
%% drops (docs/otp_bugs.md, report 2). Its steps: the build to its first
%% module and its end.
job_signal_end_test_() ->
    {timeout, waits(2), fun job_signal_end/0}.

job_signal_end() ->
    Dir = "build/job_signal_end",
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/tree"),
    [ok = file:write_file(Dir ++ "/tree/m" ++ integer_to_list(Number) ++ ".ern",
                          "export fn f(n : Int) : Int = n + " ++ integer_to_list(Number) ++ "\n")
     || Number <- lists:seq(1, 100)],
    %% unbuffered, so that a line is read as it comes and none after it is
    %% read ahead of the signal
    Python = "import subprocess, signal\n"
             "p = subprocess.Popen(['../bin/ern', 'build', '--verbose', '--build-root', '"
             ++ Dir ++ "/out', '" ++ Dir ++ "/tree'], stderr=subprocess.PIPE, bufsize=0)\n"
             "said = []\n"
             "for line in p.stderr:\n"
             "    said.append(line)\n"
             "    if line.startswith(b'compiled '):\n"
             "        break\n"
             "p.send_signal(signal.SIGTERM)\n"
             "try:\n"
             "    said += p.communicate(timeout=" ++ integer_to_list(wait_seconds()) ++ ")[1]"
             ".splitlines(True)\n"
             "except subprocess.TimeoutExpired:\n"
             "    p.kill()\n"
             "    said += p.communicate()[1].splitlines(True)\n"
             "own = (b'source root ', b'build root ', b'compiled ', b'read ', b'removed ')\n"
             "print(p.returncode, b''.join(line for line in said"
             " if not line.startswith(own)).decode())\n",
    ok = file:write_file(Dir ++ "/job.py", Python),
    ?assertEqual({0, <<"-15 \n">>}, sh("python3 " ++ Dir ++ "/job.py")).

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test_() ->
    {timeout, 60, fun modules/0}.

modules() ->
    {0, _} = sh("../bin/ern build --build-root build/modules fixtures/programs/modules"),
    {0, Output} = sh("../bin/ern run build/modules/main.erc"),
    ?assertEqual(expected("modules"), lines(Output)).

%% report §4.2, §11.1, Appendix E.1: a program shows an address of a
%% mailbox type another module keeps private, which its build describes
%% from the interface that carries the type. A regression test: the build
%% ended with an internal error, its link holding no such type
private_mailbox_shown_test_() ->
    {timeout, 60, fun private_mailbox_shown/0}.

private_mailbox_shown() ->
    {0, Output} = private_mailbox_printed("shown"),
    ?assertMatch({match, _}, re:run(Output, "^<address [0-9]+>\n$")).

%% report §4.2, §8.4, §11.1: an address of a mailbox type another module
%% keeps private, exposed to foreign code, keeps the check of each message
%% foreign code sends it: one of the type reaches the process, and one of
%% no constructor of it faults the process, the cause naming the type. A
%% regression test: the build ended with an internal error, as the shown
%% program's did
private_mailbox_exposed_test_() ->
    {timeout, 60, fun private_mailbox_exposed/0}.

private_mailbox_exposed() ->
    {0, Output} = private_mailbox_printed("exposed"),
    ?assertEqual(lists:sort([<<"added 5">>,
                             <<"Exposed.main:12 faulted: message does not match Plain.Msg">>,
                             <<"Fault(\"message does not match Plain.Msg\")">>]),
                 untraced(unstamped(lines(Output)))).

%% report §3.11, §4.2, §8.7: `Peer.spawn` of a function whose mailbox type
%% another module keeps private compiles, the type known whole; the program
%% run alone lists no peer. A regression test: the bound check ended the
%% build with an internal error, finding no declaration of the type; it
%% does not cover a spawn that reaches a peer, which was run by hand on a
%% bare node and has no test
private_mailbox_spawned_test_() ->
    {timeout, 60, fun private_mailbox_spawned/0}.

private_mailbox_spawned() ->
    ?assertEqual({0, <<"NotListed\n">>}, private_mailbox_printed("spawned")).

%% What a program of fixtures/programs/private_mailbox printed, and its
%% status, the directory built under a root of the program's own, so that
%% each test's build is its own.
private_mailbox_printed(Name) ->
    Build = "build/private_mailbox/" ++ Name,
    0 = build("--build-root " ++ Build ++ " fixtures/programs/private_mailbox"),
    sh("../bin/ern run " ++ Build ++ "/" ++ Name ++ ".erc").

%% report §4.9, §3.5, §5.6, Appendix E.25, E.26, docs/proposals/operations/operations.md: the
%% note's three programs, its directory built as a source root over the
%% standard library's ordered set and map, each print what the note says, in
%% order. Written after the code, which they were built against first.
-define(OPERATIONS, ["usage", "numeric", "num"]).

operations_test_() ->
    {timeout, 120, fun operations/0}.

operations() ->
    {0, _} = sh("../bin/ern build --build-root build/operations"
                " ../docs/proposals/operations/programs"),
    lists:foreach(fun(Name) ->
                      {0, Output} = sh("../bin/ern run build/operations/" ++ Name ++ ".erc"),
                      {ok, Expected} = file:read_file("fixtures/expected/operations/" ++ Name
                                                      ++ ".out"),
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

%% report §11.5: `ern build`, run as a command, prints a diagnostic as the
%% catalog of docs/diagnostics.md shows it, standard output and standard
%% error together, byte for byte as the catalog lays its console out
%% (ern_guide_tests:printed/1): the catalog's first example, whose message
%% quotes a character outside ASCII, `§`, whose source line holds it, and
%% whose caret stands under it. The catalog's own test builds its examples
%% in its host, so this one holds the command's printing, its device and
%% its encoding, to the catalog. A regression test, written after the code;
%% it holds one example, and the catalog's others stay its own test's
diagnostic_as_cataloged_test_() ->
    {timeout, 60, fun diagnostic_as_cataloged/0}.

diagnostic_as_cataloged() ->
    {Code, Console} = catalog_example(<<"### A character outside the language (">>),
    Dir = filename:join(ern_pty:run_dir(), "ern_cataloged_" ++ os:getpid() ++ "_"
                                           ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    File = filename:join(Dir, "example.ern"),
    ok = file:write_file(File, Code),
    {1, Output} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ File),
    Printed = binary:replace(Output, list_to_binary(Dir ++ "/"), <<>>, [global]),
    ?assertEqual(Console, iolist_to_binary(["$ ern build example.ern\n",
                                            string:trim(Printed, trailing)])),
    ok = file:del_dir_r(Dir).

%% The program of the catalog's example under the heading that begins with
%% Heading, each line ended, and its console, the lines between its fences.
catalog_example(Heading) ->
    {ok, Text} = file:read_file("../docs/diagnostics.md"),
    Lines = binary:split(Text, <<"\n">>, [global]),
    [_ | Section] = lists:dropwhile(fun(Line) -> string:prefix(Line, Heading) =:= nomatch end,
                                    Lines),
    [_ | Rest] = lists:dropwhile(fun(Line) -> Line =/= <<"```ernest-rejected">> end, Section),
    {Code, [_ | After]} = lists:splitwith(fun(Line) -> Line =/= <<"```">> end, Rest),
    [_ | Shown] = lists:dropwhile(fun(Line) -> Line =/= <<"```console">> end, After),
    {Console, _} = lists:splitwith(fun(Line) -> Line =/= <<"```">> end, Shown),
    {iolist_to_binary([[Line, <<"\n">>] || Line <- Code]),
     iolist_to_binary(lists:join(<<"\n">>, Console))}.

expected(Name) ->
    {ok, Bytes} = file:read_file("fixtures/expected/" ++ Name ++ ".out"),
    lines(Bytes).

lines(Bytes) ->
    lists:sort(binary:split(Bytes, <<"\n">>, [global, trim])).

%% Report §11.2: standard error's lines without the trace beneath each
%% fault's line, its frames each indented by four spaces, whose frames
%% above the program's name the host's and the runtime's lines;
%% stamped_test_ reads the trace itself.
untraced(Lines) ->
    [Line || Line <- Lines, not is_frame(Line)].

is_frame(<<"    ", _/binary>>) -> true;
is_frame(_) -> false.

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

%% The harness's time for one wait in seconds, as `timeout` and python3
%% take it: ern_nodes_tests:wait_ms/0, which bounds one step of a test's
%% here as in the nodes tests, a wait for a line or for a program's end.
wait_seconds() ->
    ern_nodes_tests:wait_ms() div 1000.

%% A test's limit in seconds: its Count steps, a build, a run or a wait,
%% each given the harness's time for one wait, as a nodes test's are
%% counted (ern_nodes_tests:nodes_test/2), so that a step that hangs is
%% told by its own bound before the test's limit runs out.
waits(Count) ->
    Count * wait_seconds().

%% A FIFO at Path, made anew: two sides of a test's command line meet at
%% it, the one that reads it waiting until the other has written its line.
fifo(Path) ->
    _ = file:delete(Path),
    {0, <<>>} = sh("mkfifo " ++ Path),
    Path.

%% The output of a command that must succeed. Where it does not, its whole
%% output is printed before the test fails, since EUnit shows a value that
%% does not match cut short, and a failure that comes under load alone may
%% not come again.
succeed(Command) ->
    succeed(Command, []).

succeed(Command, Options) ->
    case sh(Command, Options) of
        {0, Output} ->
            Output;
        {Status, Output} ->
            io:format(user, "~n~ts ended with status ~B:~n~ts~n", [Command, Status, Output]),
            ?assertEqual(0, Status)
    end.

collect(Program, Acc) ->
    receive
        {Program, {data, Data}} -> collect(Program, [Data | Acc]);
        {Program, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.
