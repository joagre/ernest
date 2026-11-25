%% Report Appendix E.23: the process behind a program Os.start starts.
-module(ern_os_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% The size a terminal of the tests begins with, `Terminal.Size(24, 80)`.
-define(SIZE, {'Size', 24, 80}).

%% A shell under a terminal that ignores the hangup, which its `sleep`
%% inherits, and says `ready` once it has set that.
-define(IGNORING_HANGUP, <<"trap '' HUP; echo ready; exec sleep 1000">>).

%% Appendix E.23, report §7.4: a write, a read, a read without a time, a
%% signal, a resize and a `closeInput` that wait while the helper ends fault
%% their callers, the runtime's own failure, and a resize to a size the host
%% cannot take answers `Left(Invalid)` as it does while the helper runs; a
%% read without a time and a `closeInput` after the failure fault too. A
%% regression test: the process gave them to the port the helper's end had
%% closed, and crashed with badarg; and of the rule, before which they were
%% answered `Left(Other(...))`. The resize's fault is not a regression
%% test: it was written before the resize waited on the helper, which it
%% answered `Right(Unit)` without; nor are the reads without a time,
%% written with the request. The closes were written after the code, the
%% first waiting for a hangup the failed helper never makes
helper_ends_under_a_write_and_a_read_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start_terminal(<<"sleep">>, [<<"3">>], ?SIZE),
               Helper = helper_of(Program),
               {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
               %% the program, which a helper killed so leaves running
               Sleep = child_number(OsPid),
               erlang:suspend_process(Program),
               WriteReply = alias(),
               Program ! {'Write', <<"x">>, 5000, {WriteReply, self()}},
               ReadReply = alias(),
               Program ! {'Read', 5000, {ReadReply, self()}},
               ForeverReply = alias(),
               Program ! {'ReadForever', {ForeverReply, self()}},
               SignalReply = alias(),
               Program ! {'SendSignal', 'Termination', {SignalReply, self()}},
               ResizeReply = alias(),
               Program ! {'Resize', {'Size', 30, 100}, {ResizeReply, self()}},
               InvalidReply = alias(),
               Program ! {'Resize', {'Size', 65536, 80}, {InvalidReply, self()}},
               CloseReply = alias(),
               Program ! {'CloseInput', {CloseReply, self()}},
               PortRef = erlang:monitor(port, Helper),
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               %% the port closes once the host has seen the helper end
               receive {'DOWN', PortRef, port, Helper, _} -> ok end,
               _ = os:cmd("kill -KILL " ++ Sleep),
               erlang:resume_process(Program),
               Self ! {write, answer(WriteReply)},
               Self ! {read, answer(ReadReply)},
               Self ! {read_forever, answer(ForeverReply)},
               Self ! {signal, answer(SignalReply)},
               Self ! {resize, answer(ResizeReply)},
               Self ! {invalid, answer(InvalidReply)},
               Self ! {close, answer(CloseReply)},
               LaterReply = alias(),
               Program ! {'ReadForever', {LaterReply, self()}},
               Self ! {later, answer(LaterReply)},
               LaterCloseReply = alias(),
               Program ! {'CloseInput', {LaterCloseReply, self()}},
               Self ! {later_close, answer(LaterCloseReply)}
           end, <<"main">>, ern_helpers:quiet()),
    Failed = {fault, <<"the runtime's helper ern_exec failed">>},
    ?assertEqual(Failed, ern_waits:wait(write)),
    ?assertEqual(Failed, ern_waits:wait(read)),
    ?assertEqual(Failed, ern_waits:wait(read_forever)),
    ?assertEqual(Failed, ern_waits:wait(later)),
    ?assertEqual(Failed, ern_waits:wait(signal)),
    ?assertEqual(Failed, ern_waits:wait(resize)),
    ?assertEqual({'Left', 'Invalid'}, ern_waits:wait(invalid)),
    ?assertEqual(Failed, ern_waits:wait(close)),
    ?assertEqual(Failed, ern_waits:wait(later_close)).

%% Appendix E.23: the helper answers each 'i' in order, one taken after the
%% input's end among them, so that a write returns only once the program
%% has taken the bytes before it. A regression test: an 'i' after 'e' was
%% answered at once, ahead of one the program had not taken, which let its
%% writer go
helper_answers_input_in_order_test() ->
    Helper = helper(["sh", "-c", "echo ready; exec tail -f /dev/null"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    %% more than a pipe holds, which the program never reads
    true = port_command(Helper, <<"i", (binary:copy(<<"x">>, 200000))/binary>>),
    true = port_command(Helper, <<"e">>),
    true = port_command(Helper, <<"i", "y">>),
    %% the helper takes its commands in order, and answers a request for
    %% output the program has written once it takes it, so an answer to
    %% the last input comes first if it comes at once
    true = port_command(Helper, <<"n">>),
    ?assertMatch(<<"o", _/binary>>, receive {Helper, {data, Frame}} -> Frame end),
    port_close(Helper).

%% Appendix E.23: an input larger than a pipe holds reaches the program
%% whole and in order, taken by the program a part at a time. A regression
%% test of the helper's buffer, which moved what was left to its front
%% after each part the program took, a cost that grew as the square of the
%% input: 128 MB took 16 s and takes 3 s now. It checks the bytes, not the
%% time, which the measure in the log's entry shows
helper_gives_a_large_input_whole_test() ->
    Helper = helper(["cat"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    Input = << <<(N rem 251)>> || N <- lists:seq(1, 4000000) >>,
    true = port_command(Helper, <<"i", Input/binary>>),
    true = port_command(Helper, <<"i", "more">>),
    true = port_command(Helper, <<"e">>),
    true = port_command(Helper, <<"n">>),
    ?assert(<<Input/binary, "more">> =:= output(Helper, <<>>)).

%% What the program wrote to its standard output, read a piece at a time,
%% until the helper's exit status.
output(Helper, Output) ->
    receive
        {Helper, {data, <<"o", Bytes/binary>>}} ->
            true = port_command(Helper, <<"n">>),
            output(Helper, <<Output/binary, Bytes/binary>>);
        {Helper, {data, <<"x", _/binary>>}} -> Output;
        {Helper, {data, _}} -> output(Helper, Output)
    after 20000 -> timeout
    end.

%% Appendix E.23: the program takes its input until it closes it or exits,
%% after its output and its standard error have ended too. The test asks
%% for a piece first, so that the helper watches both and sees them end,
%% and gives the line once the program has said through a named pipe that
%% it has closed them. A regression test, written after the code: the
%% helper closed the program's input once both had ended, and dropped the
%% bytes given after it without an answer
helper_gives_input_after_the_outputs_end_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_os_input_" ++ os:getpid()),
    ok = filelib:ensure_path(Dir),
    Fifo = filename:join(Dir, "fifo"),
    Mark = filename:join(Dir, "mark"),
    [] = os:cmd("mkfifo " ++ Fifo),
    Helper = helper(["sh", "-c", "exec > /dev/null 2>&1; echo closed > \"$0\"; read line;"
                     " echo \"$line\" > \"$1\"", Fifo, Mark]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    true = port_command(Helper, <<"n">>),
    Reader = open_port({spawn_executable, os:find_executable("cat")},
                       [{args, [Fifo]}, binary, exit_status]),
    receive {Reader, {data, <<"closed\n">>}} -> ok after 5000 -> erlang:error(not_closed) end,
    true = port_command(Helper, <<"i", "hi\n">>),
    ?assertEqual(<<"a">>, receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    ?assertMatch(<<"x", 0:32>>, receive {Helper, {data, Exit}} -> Exit after 5000 -> none end),
    port_close(Helper),
    Written = file:read_file(Mark),
    ok = file:del_dir_r(Dir),
    ?assertEqual({ok, <<"hi\n">>}, Written).

%% Appendix E.23: bytes given once the program has closed its input are
%% dropped, and the helper says so with `d`, where it says `a` of bytes the
%% program took. The program closes its input and says so, so that the
%% bytes do not reach the pipe before it is closed
helper_says_input_was_dropped_test() ->
    Helper = helper(["sh", "-c", "exec 0<&-; echo closed; exec tail -f /dev/null"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    true = port_command(Helper, <<"n">>),
    receive {Helper, {data, <<"o", _/binary>>}} -> ok end,
    true = port_command(Helper, <<"i", "x">>),
    ?assertEqual(<<"d">>, receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    port_close(Helper).

%% Appendix E.23: a program the host cannot start, here for want of a file
%% descriptor for its pipes, is answered with the host's reason, the run's
%% last frame, after which the helper waits to be let go. A regression
%% test: the helper ended without a word, and `start` answered only that
%% the helper failed. Under `make sanitize` the leak checker, which needs
%% descriptors of its own as the helper ends, is off for this run alone;
%% the release review found it starved, and the helper hung as it failed
helper_gives_the_hosts_reason_test() ->
    Helper = open_port({spawn, "sh -c \"ulimit -n 7; ASAN_OPTIONS=$ASAN_OPTIONS:detect_leaks=0"
                        " exec " ++ helper_path() ++ " run\""},
                       [{packet, 4}, binary, exit_status]),
    true = port_command(Helper, command(["true"])),
    ?assertEqual(<<"femfile">>,
                 receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    port_close(Helper).

%% report §8.6, Appendix E.23: a program whose helper ended waits for a read
%% to fault, and holds nothing the check for a deadlock would read as work.
%% A regression test of the run's time limit the program once had, whose
%% message came later and stayed, so the process never read as waiting; it
%% reads the program's mailbox once the program waits, and does not cover a
%% timer set for later than that
lost_program_holds_no_timer_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>]),
               Helper = helper_of(Program),
               {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
               PortRef = erlang:monitor(port, Helper),
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               %% the port closes once the host has seen the helper end, and
               %% the program waits once it has taken that: the port's exit,
               %% which ends their link, and the monitor's Down are no signal
               %% of one sender, so the Down may come first
               ern_rt:timed(),
               receive {'DOWN', PortRef, port, Helper, _} -> ok end,
               ok = ern_waits:until(Program,
                                    fun() ->
                                        [{links, Links}, {status, Status}] =
                                            process_info(Program, [links, status]),
                                        Status =:= waiting andalso not lists:member(Helper, Links)
                                    end),
               ern_rt:untimed(),
               Self ! {queued, process_info(Program, message_queue_len)},
               ReadReply = alias(),
               Program ! {'Read', 5000, {ReadReply, self()}},
               Self ! {read, answer(ReadReply)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({message_queue_len, 0}, ern_waits:wait(queued)),
    ?assertEqual({fault, <<"the runtime's helper ern_exec failed">>}, ern_waits:wait(read)).

%% report §8.6, Appendix E.23: a program `Os.start` started counts as a
%% computation whose completion would deliver until a read has answered its
%% exit or it has been killed. Here `true` has exited, as the host shows of
%% it, and no read has asked: the reaper's look answers that something can
%% still deliver while the run's one process waits as Ernest waits, and
%% once the program is killed the same wait is a deadlock. A regression
%% test, written after the code; a program `Os.startTerminal` started is not
%% covered
unread_exit_is_no_deadlock_test_() ->
    {timeout, 30, fun unread_exit_is_no_deadlock/0}.

unread_exit_is_no_deadlock() ->
    Self = self(),
    Observer = spawn(fun() ->
                         receive {started, Main, Program} ->
                             %% killed however the look went, so that the
                             %% run ends
                             try
                                 ok = unread_exited(Program),
                                 ok = ern_waits:calling(Main),
                                 Self ! {looked, next_look()}
                             after
                                 ern_rt:kill(Program)
                             end
                         end
                     end),
    Outcome = ern_rt:run_main(fun() ->
                                  {'Right', Program} = start(<<"true">>, []),
                                  Observer ! {started, self(), Program},
                                  ern_waits:forever()
                              end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(delivering, ern_waits:wait(looked)),
    ?assertMatch({fault, <<"deadlock">>, _}, Outcome).

%% report §8.6, Appendix E.23: once a read has answered a program's exit,
%% it is no computation that could deliver, and a run whose one process
%% then waits as Ernest waits is a deadlock, the program's process living
%% on. A regression test, written after the code
answered_exit_is_a_deadlock_test() ->
    Outcome = ern_rt:run_main(fun() ->
                                  {'Right', Program} = start(<<"true">>, []),
                                  {<<>>, 0} = read_to_end(Program, <<>>),
                                  ern_waits:forever()
                              end, <<"main">>, ern_helpers:quiet()),
    ?assertMatch({fault, <<"deadlock">>, _}, Outcome).

%% report §8.6, Appendix E.18, E.23: a run whose one process waits without
%% a time, in `Tcp.acceptForever`, `Tcp.readForever` or `Os.readForever`,
%% is no deadlock: the reaper's look answers that something can still
%% deliver, and once a connection, a byte or a piece of output comes the
%% wait answers it and the run ends. The far end, the client and the
%% program's input are given from outside the run once the look has
%% answered. Written with the functions, called through their modules
waits_without_a_time_are_no_deadlock_test_() ->
    {timeout, 30, fun waits_without_a_time_are_no_deadlock/0}.

waits_without_a_time_are_no_deadlock() ->
    Tcp = ern_named:functions('ern@tcp'),
    Os = ern_named:functions('ern@os'),
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, FarPort} = inet:port(Listen),
    Accepting = fun(Observer) ->
                    {'Right', Listener} = (Tcp(listen))(<<"127.0.0.1">>, 0),
                    {'Right', Port} = (Tcp(port))(Listener),
                    Observer ! {given, fun() -> connected(Port) end},
                    Answer = (Tcp(acceptForever))(Listener),
                    {'Right', Socket} = Answer,
                    (Tcp(close))(Socket),
                    ern_helpers:side(Answer)
                end,
    Reading = fun(Observer) ->
                  {'Right', Socket} = (Tcp(connect))(<<"127.0.0.1">>, FarPort, 5000),
                  {ok, FarEnd} = gen_tcp:accept(Listen, 5000),
                  Observer ! {given, fun() -> ok = gen_tcp:send(FarEnd, <<"x">>) end},
                  (Tcp(readForever))(Socket)
              end,
    Output = fun(Observer) ->
                 {'Right', Cat} = (Os(start))(inheriting(<<"cat">>, [])),
                 Observer ! {given, fun() -> written(Cat, <<"x">>) end},
                 Answer = (Os(readForever))(Cat),
                 ern_rt:kill(Cat),
                 Answer
             end,
    Outcomes = [looked_while_waiting(Wait) || Wait <- [Accepting, Reading, Output]],
    gen_tcp:close(Listen),
    ?assertEqual([{delivering, 'Right', ok}, {delivering, {'Right', <<"x">>}, ok},
                  {delivering, {'Right', {'Stdout', <<"x">>}}, ok}],
                 Outcomes).

%% What the reaper's look answers while the run's one process waits in
%% Wait, what the wait answers once the observer has given what it waits
%% for, and how the run ends. Wait tells the observer what to give.
looked_while_waiting(Wait) ->
    Self = self(),
    Observer = spawn(fun() ->
                         receive {waiting, Main} -> ok end,
                         receive {given, Give} -> ok end,
                         ok = ern_waits:calling(Main),
                         Self ! {looked, next_look()},
                         Give()
                     end),
    Outcome = ern_rt:run_main(fun() ->
                                  Observer ! {waiting, self()},
                                  Self ! {answered, Wait(Observer)}
                              end, <<"main">>, ern_helpers:quiet()),
    {ern_waits:wait(looked), ern_waits:wait(answered), Outcome}.

%% A client's connection to Port made and closed.
connected(Port) ->
    {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
    gen_tcp:close(Client).

%% Bytes given to a running program, from outside the run, once it has
%% taken them.
written(Program, Bytes) ->
    Reply = alias(),
    Program ! {'Write', Bytes, 5000, {Reply, self()}},
    {'Right', 'Unit'} = answer(Reply),
    ok.

%% Until the program a running program's process started has exited, as
%% the host shows it: a child of the helper whose state is a zombie's,
%% since the helper reaps it only as it reports the exit, which no read has
%% asked for (ern_exec.c). Nothing tells this process of another program's
%% exit, so the host is asked again at once each time, within a bound for a
%% failure.
unread_exited(Program) ->
    Helper = helper_of(Program),
    {os_pid, HelperPid} = erlang:port_info(Helper, os_pid),
    Children = lists:concat(["/proc/", HelperPid, "/task/", HelperPid, "/children"]),
    {ok, Listed} = file:read_file(Children),
    [Child] = string:lexemes(binary_to_list(Listed), " \n"),
    zombie(Child, erlang:monotonic_time(millisecond) + 5000).

zombie(Child, Deadline) ->
    {ok, Stat} = file:read_file("/proc/" ++ Child ++ "/stat"),
    %% the state follows the command's name, which ends at the last `)`
    [_, After] = string:split(binary_to_list(Stat), ")", trailing),
    case string:trim(After, leading) of
        [$Z | _] ->
            ok;
        _ ->
            erlang:monotonic_time(millisecond) < Deadline orelse erlang:error(not_exited),
            zombie(Child, Deadline)
    end.

%% Report §8.6: what the reaper's next look for a deadlock answers,
%% `deadlock`, `running` or `delivering`, which the host shows by tracing
%% the look's return; a look begun before the trace is not traced.
next_look() ->
    Reaper = ern_rt:launch_reaper(),
    MFA = {ern_rt, look, 0},
    1 = erlang:trace_pattern(MFA, [{'_', [], [{return_trace}]}], [local]),
    erlang:trace(Reaper, true, [call]),
    try
        receive {trace, Reaper, return_from, MFA, Answer} -> Answer end
    after
        erlang:trace(Reaper, false, [call]),
        erlang:trace_pattern(MFA, false, [local])
    end.

%% Appendix E.23: an argument longer than the host takes is the program's
%% failure to start, with the host's reason. A regression test: the
%% arguments were the helper's own, which the host would not start, and
%% `start` answered that the helper failed
argument_too_long_test() ->
    Self = self(),
    Long = binary:copy(<<"x">>, 200000),
    ok = ern_rt:run_main(fun() -> Self ! {started, start(<<"echo">>, [Long])} end,
                         <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', {'Other', <<"argument list too long">>}}, ern_waits:wait(started)).

%% Appendix E.23, E.0 shape rule 8: a read answers `Left(Timeout)` when its
%% milliseconds pass, the program running on; the piece asked for it is the
%% next read's, whether it comes before that read or while it waits, and
%% the exit status comes last. A regression test of the rule, before which
%% the program's one time limit killed it
read_times_out_and_the_piece_is_kept_test() ->
    Self = self(),
    Echo = [<<"-c">>, <<"sleep 0.3; echo hi; sleep 0.3; echo there">>],
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, Echo),
               Self ! {reads, [read(Program, 50), read(Program, 5000), read(Program, 5000),
                               read(Program, 5000)]}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual([{'Left', 'Timeout'}, {'Right', {'Stdout', <<"hi\n">>}},
                  {'Right', {'Stdout', <<"there\n">>}}, {'Right', {'Exited', 0}}],
                 ern_waits:wait(reads)).

%% Appendix E.23, E.0 shape rule 8: a read given no time, 0 or below, has
%% run out as it begins and answers `Left(Timeout)`, whatever has arrived,
%% the exit status the runtime holds among it, and takes nothing: the reads
%% with time after each take what came. A regression test: before the rule,
%% a read given no time answered what had arrived; a piece kept for the next
%% read while the program runs is not covered apart, its read taking the
%% same first clause
read_given_no_time_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Echo} = start(<<"echo">>, [<<"hi">>]),
               Running = read(Echo, 0),
               Piece = read(Echo, 5000),
               Exited = read(Echo, 5000),
               Self ! {reads, [Running, Piece, Exited, read(Echo, 0), read(Echo, -5),
                               read(Echo, 5000)]}
           end, <<"main">>, ern_helpers:quiet()),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual([Timeout, {'Right', {'Stdout', <<"hi\n">>}}, {'Right', {'Exited', 0}}, Timeout,
                  Timeout, {'Right', {'Exited', 0}}],
                 ern_waits:wait(reads)).

%% Appendix E.23, E.0 shape rule 8: a write given no time, 0 or below, has
%% run out as it begins, answers `Left(Timeout)` and gives the program
%% nothing: `cat` writes back the one write that had time, and once it has
%% exited a write given no time answers `Left(Timeout)` still, where one
%% with time answers `Left(Closed)`. A regression test: before the rule, the
%% bytes went to the program and the write answered whichever came first,
%% its time or the program's taking them
write_given_no_time_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Writes = [write(Cat, <<"x\n">>, 0), write(Cat, <<"y\n">>, -1),
                         write(Cat, <<"z\n">>, 5000)],
               'Unit' = close_input(Cat),
               Ran = read_to_end(Cat, <<>>),
               Self ! {ran, {Writes, Ran, write(Cat, <<"w">>, 0), write(Cat, <<"w">>, 5000)}}
           end, <<"main">>, ern_helpers:quiet()),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout, {'Right', 'Unit'}], {<<"z\n">>, 0}, Timeout,
                  {'Left', 'Closed'}},
                 ern_waits:wait(ran)).

%% Appendix E.23, E.0 shape rule 8: a write to a program that takes no input
%% answers `Left(Timeout)` when its milliseconds pass, more than a pipe holds
%% being given. A regression test of the rule, before which the write
%% waited without a limit
write_times_out_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>]),
               Self ! {written, write(Program, binary:copy(<<"x">>, 400000), 200)},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', 'Timeout'}, ern_waits:wait(written)).

%% report Appendix E.23: once the program has taken the input it was behind
%% on, its helper holds none of it. The program takes nothing until it is
%% told, and the helper has read the whole write once the signal sent after
%% it is answered; the helper's memory, as the host counts what it holds,
%% is read before the write, then, and once the program has taken it all,
%% which the answer of the write after it shows. The helper held the write,
%% and gives back at least half of what it held. A program that exits
%% instead of reading is exit_lets_input_go_test_'s
drained_input_let_go_test_() ->
    plain_helper(fun() ->
                     Size = 32 bsl 20,
                     {Before, Held, After} =
                         held_and_given_back(<<"exec cat > /dev/null">>,
                                             fun(Program) -> write(Program, <<"x">>, 60000) end,
                                             {'Right', 'Unit'}, Size),
                     ?assert(Held - Before >= Size div 1024),
                     ?assert(After - Before < (Held - Before) div 2)
                 end).

%% report Appendix E.23: once the program has exited, its helper holds none
%% of the input it was behind on, though no read has taken the exit and the
%% helper lives on for one. A write after the exit answers `Left(Closed)`
%% once the helper has dropped the input, and the helper's memory is read
%% as drained_input_let_go_test_ reads it
exit_lets_input_go_test_() ->
    plain_helper(fun() ->
                     Size = 32 bsl 20,
                     {Before, Held, After} =
                         held_and_given_back(<<"exit 3">>,
                                             fun(Program) -> write(Program, <<"x">>, 60000) end,
                                             {'Left', 'Closed'}, Size),
                     ?assert(Held - Before >= Size div 1024),
                     ?assert(After - Before < (Held - Before) div 2)
                 end).

%% A test of the memory the helper gives back, run where the helper is the
%% plain build: under `make sanitize` the address sanitizer's allocator
%% keeps what the helper frees, in its quarantine first, so that the host
%% is given none of it back; `make test` and `make test-full` run it.
plain_helper(Test) ->
    case os:getenv("ASAN_OPTIONS") of
        false -> Test;
        _ -> []
    end.

%% The helper's resident memory, in kilobytes, before a write of Size bytes
%% to a program behind it (behind/1), once the helper has read the write,
%% and once the program, told to run Then, has given After's answer.
held_and_given_back(Then, After, Answer, Size) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, [<<"-c">>, behind(Then)]),
               Number = first_line(Program),
               Helper = helper_number(Program),
               Before = status_kb(Helper, "VmRSS"),
               {'Left', 'Timeout'} = write(Program, binary:copy(<<"x">>, Size), 1),
               {'Right', 'Unit'} = signal(Program, 'Interrupt'),
               Held = status_kb(Helper, "VmRSS"),
               signaled(Number, "USR1"),
               Answer = After(Program),
               Self ! {resident, {Before, Held, status_kb(Helper, "VmRSS")}},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(resident).

%% Appendix E.23: once every input is answered, the helper holds no record
%% of one. A hundred thousand empty inputs wait behind one the program is
%% behind on, each with its record, and are answered once the program takes
%% that one; the helper's memory is read as drained_input_let_go_test_
%% reads it
answered_inputs_let_go_test_() ->
    plain_helper(fun() ->
                     {Before, Held, After} = inputs_held_and_given_back(100000),
                     ?assert(Held > Before),
                     ?assert(After - Before < (Held - Before) div 2)
                 end).

%% The helper's resident memory, in kilobytes, before Count empty inputs
%% wait behind one, once it has read them, and once all are answered.
inputs_held_and_given_back(Count) ->
    Helper = helper(["sh", "-c", behind(<<"exec cat > /dev/null">>)]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    true = port_command(Helper, <<"n">>),
    Number = receive {Helper, {data, <<"o", Line/binary>>}} -> binary_to_integer(string:trim(Line))
             end,
    {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
    Before = status_kb(OsPid, "VmRSS"),
    %% more than a pipe holds, so that every input after it waits
    true = port_command(Helper, <<"i", (binary:copy(<<"x">>, 1 bsl 17))/binary>>),
    lists:foreach(fun(_) -> true = port_command(Helper, <<"i">>) end, lists:seq(1, Count)),
    true = port_command(Helper, <<"k", 2>>),
    ?assertEqual(<<"g">>, receive {Helper, {data, Frame}} -> Frame end),
    Held = status_kb(OsPid, "VmRSS"),
    signaled(Number, "USR1"),
    ok = taken(Helper, Count + 1),
    After = status_kb(OsPid, "VmRSS"),
    port_close(Helper),
    {Before, Held, After}.

%% Until the helper has said of Count inputs that the program took them.
taken(_Helper, 0) ->
    ok;
taken(Helper, Count) ->
    receive {Helper, {data, <<"a">>}} -> taken(Helper, Count - 1) end.

%% report Appendix E.23: a write after `closeInput` answers `Left(Closed)` at
%% once, its bytes dropped, under pipes as under a terminal. Under pipes the
%% program is behind on what was written before, which is still its input:
%% `cat`, told to begin once the input has been closed, takes it and writes
%% it back whole before it exits. Without the mend the write waited behind
%% that input its whole time and answered `Left(Timeout)`. Under a terminal
%% the hangup drops what the program has not taken, and the write was
%% answered so before; that half is a regression test
write_after_close_input_closed_test() ->
    Self = self(),
    Input = << <<(N rem 251)>> || N <- lists:seq(1, 1 bsl 18) >>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"sh">>, [<<"-c">>, behind(<<"exec cat">>)]),
               Number = first_line(Cat),
               {'Left', 'Timeout'} = write(Cat, Input, 1),
               'Unit' = close_input(Cat),
               Late = write(Cat, <<"late">>, 2000),
               signaled(Number, "USR1"),
               Self ! {piped, {Late, read_to_end(Cat, <<>>)}},
               ern_rt:kill(Cat),
               {'Right', Terminal} = start_terminal(<<"cat">>, [], ?SIZE),
               'Unit' = close_input(Terminal),
               Self ! {hung_up, write(Terminal, <<"late">>, 2000)},
               ern_rt:kill(Terminal)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Left', 'Closed'}, {Input, 0}}, ern_waits:wait(piped)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(hung_up)).

%% report Appendix E.23, and CLAUDE.md's *What the user wants of Ernest*: a write's time running
%% out costs the program's process the same however many writes wait
%% beside it, so that writes that run out together are each answered on
%% time. The work is the host's count of the process's reductions, from the
%% moment every write is in its mailbox to the last answer, for a number of
%% writes and for four times as many. Work that grows with the writes that
%% wait grows sixteen times, and work that does not four times and a
%% little more; the bound is eight, between the two
writes_time_out_without_a_scan_test_() ->
    {timeout, 60, fun() ->
                      One = timed_out_reductions(500),
                      ?assert(timed_out_reductions(2000) < 8 * One)
                  end}.

%% The reductions of a program's process as Count writes of a millisecond
%% each, all in its mailbox before it takes the first, wait behind one more
%% than a pipe holds and are answered `Left(Timeout)`.
timed_out_reductions(Count) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sleep} = start(<<"sleep">>, [<<"1000">>]),
               {'Left', 'Timeout'} = write(Sleep, binary:copy(<<"x">>, 1 bsl 17), 1),
               Main = self(),
               erlang:suspend_process(Sleep),
               Writers = [erlang:spawn(fun() -> Main ! {written, write(Sleep, <<"x">>, 1)} end)
                          || _ <- lists:seq(1, Count)],
               lists:foreach(fun(Writer) -> ok = ern_waits:calling(Writer) end, Writers),
               {reductions, Before} = erlang:process_info(Sleep, reductions),
               erlang:resume_process(Sleep),
               lists:foreach(fun(_) -> receive {written, {'Left', 'Timeout'}} -> ok end end,
                             Writers),
               {reductions, After} = erlang:process_info(Sleep, reductions),
               Self ! {reductions, After - Before},
               ern_rt:kill(Sleep)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(reductions).

%% report Appendix E.23, and CLAUDE.md's *What the user wants of Ernest*: a read's time running
%% out, and the end of a read's caller, cost the program's process the same
%% however many reads wait beside it, each counted as the writes' are
%% (writes_time_out_without_a_scan_test_). A regression test, written after
%% the mend and seen to fail without it: the reads were a list rebuilt at
%% each time that ran out and each caller that ended, and counted at each
%% read that came, and a read let go of its caller's monitor by looking
%% through the mailbox for its `DOWN`, which the `DOWN`s of the other
%% callers fill. It does not cover a read whose caller is found ended as
%% a piece comes (given/5), nor the answers that go to every read at once
%% as the program exits or its helper fails
reads_time_out_without_a_scan_test_() ->
    {timeout, 60, fun() ->
                      One = timed_out_read_reductions(500),
                      ?assert(timed_out_read_reductions(2000) < 8 * One)
                  end}.

%% report Appendix E.23: the same, of the callers that end.
reads_dropped_without_a_scan_test_() ->
    {timeout, 60, fun() ->
                      One = dropped_read_reductions(500),
                      ?assert(dropped_read_reductions(2000) < 8 * One)
                  end}.

%% The reductions of a program's process as Count reads of a millisecond
%% each, all in its mailbox before it takes the first, of a program that
%% writes nothing, are answered `Left(Timeout)`.
timed_out_read_reductions(Count) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sleep} = start(<<"sleep">>, [<<"1000">>]),
               Main = self(),
               erlang:suspend_process(Sleep),
               Readers = [erlang:spawn(fun() -> Main ! {read, read(Sleep, 1)} end)
                          || _ <- lists:seq(1, Count)],
               lists:foreach(fun(Reader) -> ok = ern_waits:calling(Reader) end, Readers),
               {reductions, Before} = erlang:process_info(Sleep, reductions),
               erlang:resume_process(Sleep),
               lists:foreach(fun(_) -> receive {read, {'Left', 'Timeout'}} -> ok end end,
                             Readers),
               {reductions, After} = erlang:process_info(Sleep, reductions),
               Self ! {reductions, After - Before},
               ern_rt:kill(Sleep)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(reductions).

%% The reductions of a program's process as the callers of Count reads of a
%% program that writes nothing, all taken, end, from the moment the first is
%% killed to the moment the process has taken every caller's `DOWN`, which
%% the host shows by tracing what the process takes into its mailbox, and
%% answered a read given no time after them.
dropped_read_reductions(Count) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sleep} = start(<<"sleep">>, [<<"1000">>]),
               Readers = [erlang:spawn(fun() -> read(Sleep, 600000) end)
                          || _ <- lists:seq(1, Count)],
               lists:foreach(fun(Reader) -> ok = ern_waits:calling(Reader) end, Readers),
               ok = ern_waits:until(Sleep, fun() ->
                                               erlang:process_info(Sleep, message_queue_len)
                                                   =:= {message_queue_len, 0}
                                           end),
               1 = erlang:trace(Sleep, true, ['receive']),
               {reductions, Before} = erlang:process_info(Sleep, reductions),
               lists:foreach(fun(Reader) -> exit(Reader, kill) end, Readers),
               lists:foreach(fun(_) ->
                                 receive {trace, Sleep, 'receive', {_, _, process, _, _}} -> ok end
                             end, Readers),
               1 = erlang:trace(Sleep, false, ['receive']),
               {'Left', 'Timeout'} = read(Sleep, 0),
               {reductions, After} = erlang:process_info(Sleep, reductions),
               Self ! {reductions, After - Before},
               ern_rt:kill(Sleep)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(reductions).

%% report Appendix E.23, §7.4: a helper that ends while a frame is on its
%% way to it has failed, every time, and the write that meets its end
%% faults with E.23's cause, its program's process living on. The host
%% learns of the end two ways: from the helper's exit status, which the
%% host's forker, erl_child_setup, reports, and from a write to the
%% helper's closed pipe, which ends the port with the host's `epipe`. The
%% forker is held still here while the helper is killed, so that the write
%% comes first; it is signaled through a shell opened before, since an open
%% waits on it. Without the mend the program's process ended with the
%% host's `epipe`, the write unanswered; a failure as the program starts is
%% not covered
helper_ended_under_a_write_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"1000">>]),
               Helper = helper_number(Program),
               %% the program, which a helper killed so leaves running
               Sleep = child_number(Helper),
               Shell = open_port({spawn_executable, os:find_executable("sh")}, [binary]),
               Forker = parent_number(Helper),
               MonitorRef = erlang:monitor(process, Program),
               Met = try
                         said(Shell, ["kill -STOP ", Forker]),
                         said(Shell, ["kill -KILL ", Helper]),
                         ok = zombie(integer_to_list(Helper),
                                     erlang:monotonic_time(millisecond) + 5000),
                         WriteReply = alias(),
                         Program ! {'Write', <<"x">>, 5000, {WriteReply, self()}},
                         receive
                             {WriteReply, fault, Cause} -> {fault, Cause};
                             {'DOWN', MonitorRef, process, _, ExitReason} -> {ended, ExitReason}
                         after 5000 -> timeout
                         end
                     after
                         said(Shell, ["kill -CONT ", Forker]),
                         said(Shell, ["kill -KILL ", Sleep]),
                         port_close(Shell)
                     end,
               Self ! {met, {Met, erlang:is_process_alive(Program)}},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{fault, <<"the runtime's helper ern_exec failed">>}, true}, ern_waits:wait(met)).

%% A command run by the shell Shell opened, once the shell has said so.
said(Shell, Command) ->
    true = port_command(Shell, [lists:concat(Command), "; echo done\n"]),
    receive {Shell, {data, <<"done\n">>}} -> ok end.

%% The number of the process of the operating system's that started the
%% process of Number, from what the host shows of it: the fourth field of
%% its stat, after the command's name, which ends at the last `)`.
parent_number(Number) ->
    {ok, Stat} = file:read_file("/proc/" ++ integer_to_list(Number) ++ "/stat"),
    [_, After] = string:split(binary_to_list(Stat), ")", trailing),
    [_State, Parent | _] = string:lexemes(After, " "),
    Parent.

%% The number of the one process the process of Number started.
child_number(Number) ->
    Task = integer_to_list(Number),
    {ok, Listed} = file:read_file(lists:concat(["/proc/", Task, "/task/", Task, "/children"])),
    [Child] = string:lexemes(binary_to_list(Listed), " \n"),
    Child.

%% report Appendix E.23: a write's bytes are copied once on the node, by the
%% host's port, which queues what the helper has not read, and once in the
%% helper, into the input the program is behind on, the program here not
%% reading. The node's binaries are read as the host's allocator of them
%% counts the most it held since its last reading, and the helper's memory
%% as the host counts the most it held; each grows by less than half again
%% of the write. The host's own copy of a command, which it gives its port
%% and frees as the command returns, is not counted, since it is not a
%% binary
write_copied_once_test() ->
    Size = 32 bsl 20,
    {Node, InHelper} = held_for_a_write(Size),
    ?assert(Node < 3 * Size div 2),
    ?assert(InHelper < 3 * Size div 2).

%% The most bytes the node's binaries and the helper grew by, the write's
%% caller's own bytes not counted, for one write of Size bytes to a program
%% that does not read.
held_for_a_write(Size) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, [<<"-c">>, behind(<<"exec cat > /dev/null">>)]),
               _ = first_line(Program),
               Helper = helper_number(Program),
               Bytes = binary:copy(<<"x">>, Size),
               {Base, _} = binaries_held(),
               HelperBase = status_kb(Helper, "VmHWM"),
               {'Left', 'Timeout'} = write(Program, Bytes, 1),
               {'Right', 'Unit'} = signal(Program, 'Interrupt'),
               {_, Most} = binaries_held(),
               Self ! {held, {Most - Base, 1024 * (status_kb(Helper, "VmHWM") - HelperBase)}},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(held).

%% The bytes the host's allocator of binaries holds, and the most it held
%% since this was last asked, each summed over its instances.
binaries_held() ->
    Sizes = [Size || {instance, _, Info} <- erlang:system_info({allocator, binary_alloc}),
                     {Kind, Carriers} <- Info, Kind =:= mbcs orelse Kind =:= sbcs,
                     {blocks, Blocks} <- [lists:keyfind(blocks, 1, Carriers)],
                     {_, Block} <- Blocks,
                     {size, _, _, _} = Size <- [lists:keyfind(size, 1, Block)]],
    {lists:sum([Now || {size, Now, _, _} <- Sizes]),
     lists:sum([Most || {size, _, Most, _} <- Sizes])}.

%% report Appendix E.23: a write is given the helper in frames of at most a
%% number of bytes, the most a frame of the host's can say for a write and
%% three here, and only the last frame's answer answers the write: the
%% program takes the frames whole and in order, and the helper answers
%% each. A regression test, written after the code, which the host's most
%% for a frame needs; a write of 4 GiB or more, which is cut so, is not run.
%% The test stands as the program's writer, given the frames, which it
%% gives the helper in the order they came
write_split_into_frames_test() ->
    Helper = helper(["cat"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    Writes = ern_os:input(self(), <<"abcdefghij">>, 3, last, queue:new()),
    [true = port_command(Helper, Frame) || Frame <- ern_helpers:taken(frame)],
    true = port_command(Helper, <<"e">>),
    true = port_command(Helper, <<"n">>),
    ?assertEqual({[none, none, none, last], {<<"abcdefghij">>, 4}},
                 {queue:to_list(Writes), taken_and_written(Helper, <<>>, 0)}),
    port_close(Helper).

%% What the program wrote, read a piece at a time, and how many inputs the
%% helper said it took, until the helper's exit status.
taken_and_written(Helper, Output, Taken) ->
    receive
        {Helper, {data, <<"o", Bytes/binary>>}} ->
            true = port_command(Helper, <<"n">>),
            taken_and_written(Helper, <<Output/binary, Bytes/binary>>, Taken);
        {Helper, {data, <<"a">>}} -> taken_and_written(Helper, Output, Taken + 1);
        {Helper, {data, <<"x", _/binary>>}} -> {Output, Taken}
    after 20000 -> timeout
    end.

%% report Appendix E.23: a request answered holds no timer: a write and a
%% read answered before their milliseconds pass are sent nothing when they
%% pass. A regression test: each timer stayed armed until its time, and a
%% write's then answered `Left(Timeout)` to a reply already answered
answered_requests_hold_no_timer_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"cat">>, []),
               erlang:trace(Program, true, ['receive', {tracer, Self}]),
               Ms = 300,
               Self ! {answers, {write(Program, <<"x">>, Ms), read(Program, Ms)}},
               %% an absence: a timer the requests left would fire their
               %% milliseconds after them, and the host's timers may fire
               %% late, so twice that
               ern_waits:sleep(2 * Ms),
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Right', 'Unit'}, {'Right', {'Stdout', <<"x">>}}}, ern_waits:wait(answers)),
    ?assertEqual([], timeouts_traced()).

%% The timeout messages a traced process received.
timeouts_traced() ->
    receive
        {trace, _, 'receive', {timeout, _, _} = Timeout} -> [Timeout | timeouts_traced()];
        {trace, _, _, _} -> timeouts_traced()
    after 0 ->
        []
    end.

%% report §6.9, Appendix E.23: `give` makes another process a program's
%% owner, so that it outlives the process that started it and is killed
%% when its new owner dies. A regression test of the rule, before which a
%% program could not be given
give_test() ->
    given(fun start/2).

%% report Appendix E.23: a program under a terminal is given, and killed
%% with its owner, as one `start` started is
terminal_give_test() ->
    given(fun(Program, Arguments) -> start_terminal(Program, Arguments, ?SIZE) end).

%% Two programs Start starts, one given to a keeper and the other killed
%% with the process that started them, and the given one killed with the
%% keeper.
given(Start) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = self(),
               Keeper = erlang:spawn(fun() -> receive stop -> ok end end),
               %% the starter starts two, gives one, and ends: the other,
               %% killed of that end, shows the end has been told
               Forever = [<<"-f">>, <<"/dev/null">>],
               _ = erlang:spawn(fun() ->
                                    {'Right', Started} = Start(<<"tail">>, Forever),
                                    {'Right', Kept} = Start(<<"tail">>, Forever),
                                    Started ! {'Give', Keeper},
                                    EntryProcess ! {programs, Started, Kept}
                                end),
               {Program, Unkept} = receive {programs, Started, Kept} -> {Started, Kept} end,
               UnkeptRef = erlang:monitor(process, Unkept),
               receive {'DOWN', UnkeptRef, process, _, _} -> ok end,
               ok = ern_waits:waiting(Program),
               Self ! {alive, erlang:is_process_alive(Program)},
               MonitorRef = erlang:monitor(process, Program),
               Keeper ! stop,
               Ended = fun() ->
                           receive {'DOWN', MonitorRef, _, _, ExitReason} -> ExitReason
                           after 5000 -> alive
                           end
                       end,
               Self ! {ended, Ended()}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(true, ern_waits:wait(alive)),
    ?assertEqual({ern, killed}, ern_waits:wait(ended)).

%% report Appendix E.23: a program under a terminal of the size given: a
%% line written to it is echoed and given to the program, its size is the
%% one given, a line feed it writes arrives after a carriage return, the
%% echo comes before what the program writes after taking the line, and
%% its exit status comes last. The program writes after the line it reads,
%% since the echo of a line a program exits on may not arrive; neither
%% that echo nor the echo of a line written while the program writes is
%% tested
terminal_test() ->
    Self = self(),
    Script = <<"stty size; read line; echo \"took $line\"; exit 3">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, Script], ?SIZE),
               Sized = read_until(Sh, <<"24 80\r\n">>, <<>>),
               {'Right', 'Unit'} = write(Sh, <<"typed\n">>, 5000),
               Self ! {ran, {Sized, read_to_end(Sh, <<>>)}}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({<<"24 80\r\n">>, {<<"typed\r\ntook typed\r\n">>, 3}}, ern_waits:wait(ran)).

%% report Appendix E.23: a program's standard output and standard error
%% come merged through its terminal, each piece read as `Stdout`
terminal_merges_streams_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, <<"echo out; echo err 1>&2">>],
                                              ?SIZE),
               Self ! {ran, read_to_end(Sh, <<>>)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({<<"out\r\nerr\r\n">>, 0}, ern_waits:wait(ran)).

%% report Appendix E.23: a resize sets the terminal's size and tells the
%% program's foreground, which reads the new size when told. The program
%% blocks the signal before it says it is ready, and takes it with
%% sigwait, so that a resize that comes before its wait is kept for it.
%%
%% A regression test, changed after the code: the program took the signal
%% in a handler and waited in signal.pause(), and a signal that came after
%% Python's last look for one and before pause(2) left the handler to the
%% next signal, which never came. In 24 hosts at once beside 15 busy loops
%% it hung so in about one run of 500 (the log's *A Signal Before the
%% Pause*). A program that takes the signal through a handler is not
%% covered
resize_test() ->
    Self = self(),
    Told = <<"import fcntl, os, signal, struct, termios\n"
             "signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGWINCH})\n"
             "os.write(1, b'ready\\n')\n"
             "while True:\n"
             "    signal.sigwait({signal.SIGWINCH})\n"
             "    size = fcntl.ioctl(1, termios.TIOCGWINSZ, bytes(8))\n"
             "    os.write(1, b'%d %d\\n' % struct.unpack('HHHH', size)[:2])\n">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Python} = start_terminal(<<"python3">>, [<<"-c">>, Told], ?SIZE),
               _ = read_until(Python, <<"ready\r\n">>, <<>>),
               Resized = resize(Python, {'Size', 30, 100}),
               Self ! {resized, {Resized, read_until(Python, <<"30 100\r\n">>, <<>>)}},
               ern_rt:kill(Python)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Right', 'Unit'}, <<"30 100\r\n">>}, ern_waits:wait(resized)).

%% report Appendix E.23: a program `start` started has no terminal, and a
%% resize of it answers `Left(NotATerminal)`, whatever the size
resize_without_a_terminal_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Self ! {resized, [resize(Cat, ?SIZE), resize(Cat, {'Size', -1, 80})]},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual([{'Left', 'NotATerminal'}, {'Left', 'NotATerminal'}], ern_waits:wait(resized)).

%% report Appendix E.23: a count of rows or columns below 0 or above 65535
%% is one the host cannot take, which `startTerminal` and `resize` answer
%% `Left(Invalid)`; 0 and 65535 are taken
terminal_size_out_of_range_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Started = [start_terminal(<<"true">>, [], Size)
                          || Size <- [{'Size', -1, 80}, {'Size', 24, 65536}]],
               {'Right', Cat} = start_terminal(<<"cat">>, [], ?SIZE),
               Resized = [resize(Cat, Size)
                          || Size <- [{'Size', 65536, 80}, {'Size', 24, -1}, {'Size', 0, 65535}]],
               Self ! {answers, {Started, Resized}},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    Invalid = {'Left', 'Invalid'},
    ?assertEqual({[Invalid, Invalid], [Invalid, Invalid, {'Right', 'Unit'}]},
                 ern_waits:wait(answers)).

%% report Appendix E.23: a resize's answers in their order: a program
%% `start` started answers `Left(NotATerminal)` whatever the size and once
%% it has exited, then a size the host cannot take answers `Left(Invalid)`,
%% then a terminal hung up or a program exited answers `Left(Closed)`, as a
%% write does. The program hung up ignores the hangup, which its `sleep`
%% inherits, so that it runs on after it. A regression test: before the
%% rule, a resize after the hangup or the exit answered `Right(Unit)`; a
%% resize once the helper has failed is not covered
resize_answers_in_order_test() ->
    Self = self(),
    Wrong = {'Size', 65536, 80},
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               'Unit' = close_input(Cat),
               {<<>>, 0} = read_to_end(Cat, <<>>),
               {'Right', Held} = start_terminal(<<"sh">>,
                                                [<<"-c">>, <<"trap '' HUP; echo ready;"
                                                             " exec sleep 1000">>], ?SIZE),
               _ = read_until(Held, <<"ready\r\n">>, <<>>),
               'Unit' = close_input(Held),
               HungUp = [resize(Held, Wrong), resize(Held, ?SIZE)],
               ern_rt:kill(Held),
               {'Right', True} = start_terminal(<<"true">>, [], ?SIZE),
               {<<>>, 0} = read_to_end(True, <<>>),
               Self ! {answers, {[resize(Cat, Wrong), resize(Cat, ?SIZE)], HungUp,
                                 [resize(True, Wrong), resize(True, ?SIZE)]}}
           end, <<"main">>, ern_helpers:quiet()),
    NotATerminal = {'Left', 'NotATerminal'},
    Invalid = {'Left', 'Invalid'},
    Closed = {'Left', 'Closed'},
    ?assertEqual({[NotATerminal, NotATerminal], [Invalid, Closed], [Invalid, Closed]},
                 ern_waits:wait(answers)).

%% report Appendix E.23: `closeInput` hangs the terminal up: the program is
%% sent the hangup, which ends `sleep`, which reads nothing, with 128 and
%% the hangup's number, and nothing more it writes arrives
close_input_hangs_up_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sleep} = start_terminal(<<"sh">>,
                                                 [<<"-c">>, <<"echo ready; exec sleep 1000">>],
                                                 ?SIZE),
               _ = read_until(Sleep, <<"ready\r\n">>, <<>>),
               'Unit' = close_input(Sleep),
               Self ! {ended, read_to_end(Sleep, <<>>)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({<<>>, 129}, ern_waits:wait(ended)).

%% report Appendix E.23: under a terminal `closeInput` answers once the
%% terminal is hung up, so that what its caller does next, by whatever way,
%% comes after the hangup: once it has returned, the helper holds no
%% descriptor of the terminal's master, whose last close is the hangup, as
%% the host shows it. The program ignores the hangup and runs on. Written
%% before the code, under which `closeInput` was a send: the helper still
%% held the master in 6 rounds of 101, and in 20 of 20 where a scratch
%% copy's helper waited 20 ms before each hangup, which the new code passed
close_input_answers_once_hung_up_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, ?IGNORING_HANGUP], ?SIZE),
               _ = read_until(Sh, <<"ready\r\n">>, <<>>),
               Helper = helper_number(Sh),
               Before = masters(Helper),
               'Unit' = close_input(Sh),
               Self ! {masters, {Before > 0, masters(Helper)}},
               ern_rt:kill(Sh)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({true, 0}, ern_waits:wait(masters)).

%% report Appendix E.23: `closeInput` answers at once where the input is
%% closed already or the program has exited. With its helper stopped by the
%% host, a second `closeInput` under a terminal answers, and so does a first
%% under pipes, whose end stands behind what was written before once the
%% program's process has given it to the helper, a write after it answering
%% `Left(Closed)` too; the end reaches `cat` after the byte written before,
%% once the helper goes on. Once the exit is read, `closeInput` answers with
%% no helper left. Written before the code, under which `closeInput` was a
%% send that answered at once always, and passed there
close_input_answers_at_once_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, ?IGNORING_HANGUP], ?SIZE),
               _ = read_until(Sh, <<"ready\r\n">>, <<>>),
               'Unit' = close_input(Sh),
               Again = stopped(Sh, fun() -> close_input(Sh) end),
               ern_rt:kill(Sh),
               {'Right', Cat} = start(<<"cat">>, []),
               {'Right', 'Unit'} = write(Cat, <<"x">>, 5000),
               Piped = stopped(Cat, fun() -> {close_input(Cat), write(Cat, <<"y">>, 5000)} end),
               Ran = read_to_end(Cat, <<>>),
               Self ! {answers, {Again, Piped, Ran, close_input(Cat)}},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Unit', {'Unit', {'Left', 'Closed'}}, {<<"x">>, 0}, 'Unit'},
                 ern_waits:wait(answers)).

%% report Appendix E.23: a `closeInput` that comes while the terminal's
%% hangup is owed waits for that hangup too, the input closed only once it
%% is made, so that each close returns once the terminal is hung up. With
%% the helper stopped by the host, two closers wait in their calls once the
%% program's process has taken both requests, neither answered, and once
%% the helper goes on each answers with no descriptor of the master left.
%% Written after the code, a regression test; under the old code, whose
%% close was a send, the closers had returned, and it failed 50 rounds of 50
close_input_waits_while_the_hangup_is_owed_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, ?IGNORING_HANGUP], ?SIZE),
               _ = read_until(Sh, <<"ready\r\n">>, <<>>),
               Main = self(),
               Helper = helper_number(Sh),
               Closing = fun(Tag) ->
                                 Close = fun() ->
                                                 Main ! {Tag, close_input(Sh), masters(Helper)}
                                         end,
                                 ern_rt:process_of(ern_rt:spawn_monitored(
                                                     Close, fun(Down) -> {Tag, Down} end,
                                                     <<"closer">>))
                         end,
               Unanswered = stopped(Sh, fun() ->
                                            Closers = [Closing(first), Closing(second)],
                                            [ok = ern_waits:calling(Closer) || Closer <- Closers],
                                            ok = ern_waits:waiting(Sh),
                                            [process_info(Closer, message_queue_len)
                                             || Closer <- Closers]
                                        end),
               Answered = [receive {Tag, Answer, Masters} -> {Answer, Masters} end
                           || Tag <- [first, second]],
               Self ! {closes, {Unanswered, Answered}},
               ern_rt:kill(Sh)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({[{message_queue_len, 0}, {message_queue_len, 0}], [{'Unit', 0}, {'Unit', 0}]},
                 ern_waits:wait(closes)).

%% report Appendix E.23, §6.6: `closeInput` on a program whose process has
%% ended faults as a read does, as `Address.callForever` does on an ended
%% process: one that waits for the hangup as the program is killed with
%% `callee was killed`, and one after with `callee had ended`. The helper is
%% stopped by the host, so that the first waits, and the kill comes once the
%% closer waits in its call and the program's process has taken its
%% request. Written before the code, under which `closeInput` was a send
%% and did nothing there, and the test failed 50 rounds of 50
close_input_on_an_ended_program_faults_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, ?IGNORING_HANGUP], ?SIZE),
               _ = read_until(Sh, <<"ready\r\n">>, <<>>),
               Waiting = stopped(Sh, fun() ->
                                         Closer = closer(Sh, waiting),
                                         _ = ern_waits:calling(ern_rt:process_of(Closer)),
                                         ok = ern_waits:waiting(Sh),
                                         ern_rt:kill(Sh),
                                         receive {waiting, Down} -> Down end
                                     end),
               _ = closer(Sh, later),
               Self ! {downs, {Waiting, receive {later, Later} -> Later end}}
           end, <<"main">>, ern_helpers:quiet()),
    {Waiting, Later} = ern_waits:wait(downs),
    ?assertMatch({'Down', _, {'Fault', <<"callee was killed">>}, _}, Waiting),
    ?assertMatch({'Down', _, {'Fault', <<"callee had ended">>}, _}, Later).

%% report §8.6, Appendix E.23: a run whose one process waits in `closeInput`
%% for the terminal's hangup is no deadlock: the reaper's look answers that
%% something can still deliver, the program counting as a computation whose
%% completion would, and once the helper, stopped by the host until the
%% look, goes on, the close answers and the run ends. Written before the
%% code, under which the close was a send that waited for nothing, and the
%% observer found the run ended in 50 rounds of 50
close_input_waiting_is_no_deadlock_test_() ->
    {timeout, 30, fun close_input_waiting_is_no_deadlock/0}.

close_input_waiting_is_no_deadlock() ->
    Self = self(),
    Observer = spawn(fun() ->
                         receive {closing, Main, Number} ->
                             try
                                 ok = ern_waits:calling(Main),
                                 Self ! {looked, next_look()}
                             after
                                 os:cmd("kill -CONT " ++ Number)
                             end
                         end
                     end),
    Outcome = ern_rt:run_main(
                fun() ->
                    {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, ?IGNORING_HANGUP], ?SIZE),
                    _ = read_until(Sh, <<"ready\r\n">>, <<>>),
                    Number = integer_to_list(helper_number(Sh)),
                    [] = os:cmd("kill -STOP " ++ Number),
                    Observer ! {closing, self(), Number},
                    close_input(Sh)
                end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(delivering, ern_waits:wait(looked)),
    ?assertEqual(ok, Outcome).

%% A process that closes Program's input, whose `Down` comes to the caller
%% tagged Tag.
closer(Program, Tag) ->
    ern_rt:spawn_monitored(fun() -> close_input(Program) end, fun(Down) -> {Tag, Down} end,
                           <<"closer">>).

%% What Then answers while the helper of Program is stopped by the host, so
%% that what it answers comes without the helper.
stopped(Program, Then) ->
    Number = integer_to_list(helper_number(Program)),
    [] = os:cmd("kill -STOP " ++ Number),
    try Then() after os:cmd("kill -CONT " ++ Number) end.

%% How many descriptors of a terminal's master the process of Number holds,
%% each named by its link as the host's device of masters.
masters(Number) ->
    Descriptors = "/proc/" ++ integer_to_list(Number) ++ "/fd",
    {ok, Names} = file:list_dir(Descriptors),
    length([Name || Name <- Names,
                    {ok, Link} <- [file:read_link(filename:join(Descriptors, Name))],
                    lists:member(Link, ["/dev/ptmx", "/dev/pts/ptmx"])]).

%% report Appendix E.23: a read the program waits in ends before the hangup
%% is sent, so `sh` waiting on a line ends either way, by the hangup or
%% with 1 on its read's end, which under load it did 5 times in 300 (the
%% log's *The Hangup's Order*); nothing it writes after arrives either way
read_ends_before_the_hangup_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, <<"echo ready; read line">>],
                                              ?SIZE),
               _ = read_until(Sh, <<"ready\r\n">>, <<>>),
               'Unit' = close_input(Sh),
               Self ! {ended, read_to_end(Sh, <<>>)}
           end, <<"main">>, ern_helpers:quiet()),
    {Output, Status} = ern_waits:wait(ended),
    ?assertEqual(<<>>, Output),
    ?assert(lists:member(Status, [1, 129])).

%% Appendix E.23: after a run's last frame, 'x', the helper keeps its input
%% open until the runtime closes it, so that a frame the runtime sends
%% before it has read the last, a read's request or the hangup, is dropped
%% and ends nothing: the helper lives on after the frame, and the port ends
%% at the close alone. A regression test, written after the fix: the helper ended
%% with its last frame, and a frame written after that ended the port, and
%% the program's process with it, with the host's `epipe` (the log's *The
%% Hangup's Order*); it failed five runs of five on the old helper, which
%% had ended before the signal asked after it
helper_waits_to_be_let_go_test() ->
    process_flag(trap_exit, true),
    Helper = helper(["true"]),
    true = port_command(Helper, <<"i">>),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    true = port_command(Helper, <<"e">>),
    ok = exited(Helper),
    {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
    true = port_command(Helper, <<"n">>),
    ?assertEqual(sent, ern_os:signal(0, OsPid)),
    port_close(Helper),
    %% the close's own end of the port, and no other before it
    ?assertEqual(normal, receive {'EXIT', Helper, Reason} -> Reason end).

%% The helper asked for the program's output until it says the program has
%% exited.
exited(Helper) ->
    true = port_command(Helper, <<"n">>),
    receive
        {Helper, {data, <<"x", _/binary>>}} -> ok;
        {Helper, {data, _}} -> exited(Helper)
    end.

%% report Appendix E.23: a program under a terminal is killed with the
%% processes still in its process group. Its `sleep` ignores the hangup,
%% which the terminal's end would send it, so that the kill alone ends it;
%% it writes to a named pipe the test reads, whose end shows that `sleep`
%% has ended, and is then found by its number
terminal_kill_test() ->
    Fifo = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                         "ern_os_kill_" ++ os:getpid()),
    "" = os:cmd("mkfifo " ++ Fifo),
    Reader = open_port({spawn_executable, os:find_executable("cat")},
                       [{args, [Fifo]}, exit_status, binary]),
    {os_pid, ReaderNumber} = erlang:port_info(Reader, os_pid),
    Self = self(),
    %% The shell opens the pipe itself before it prints the number, so that
    %% a writer holds the pipe before the kill can come: a `sleep` that opens
    %% it in the background may not have by then, and the reader would wait
    %% on a pipe no writer ever opens.
    Script = <<"trap '' HUP; exec 3> ", (list_to_binary(Fifo))/binary,
               "; sleep 1000 >&3 & echo $!; wait">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, Script], ?SIZE),
               Number = read_until(Sh, <<"\r\n">>, <<>>),
               ern_rt:kill(Sh),
               Self ! {sleep, binary_to_integer(string:trim(Number))}
           end, <<"main">>, ern_helpers:quiet()),
    Sleep = ern_waits:wait(sleep),
    Ended = receive
                {Reader, {exit_status, Status}} -> Status
            after 5000 ->
                _ = os:cmd("kill -KILL " ++ integer_to_list(ReaderNumber)),
                running
            end,
    ok = file:delete(Fifo),
    ?assertEqual(0, Ended),
    %% gone, or ended and not yet taken by the process that inherited it
    ?assertMatch("Z" ++ _, string:trim(os:cmd("ps -o stat= -p " ++ integer_to_list(Sleep)))
                           ++ "Z").

%% report Appendix E.23: a program that exits by itself is reaped with the
%% processes still in its process group killed, so that `run` leaves no
%% process behind: the shell leaves a `sleep` in the background, its output
%% on a named pipe the test reads and not on the program's, so that the
%% program's outputs end with the shell, and the pipe's end shows that
%% `sleep` has ended once the run has its exit status. A regression test,
%% written after the code (C1-1): the helper reaped the program and left
%% its group running; a member under a terminal that ignores the hangup is
%% terminal_kill_test's at a kill, and group_killed_at_the_exit_test_'s at
%% an exit. The run's own limit stands past the wait's 5 seconds, which
%% bound a failure, so that a `sleep` left running is killed by its number
exited_program_leaves_no_group_test_() ->
    {timeout, 60, fun exited_program_leaves_no_group/0}.

exited_program_leaves_no_group() ->
    Fifo = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                         "ern_os_group_" ++ os:getpid()),
    "" = os:cmd("mkfifo " ++ Fifo),
    Reader = open_port({spawn_executable, os:find_executable("cat")},
                       [{args, [Fifo]}, exit_status, binary]),
    {os_pid, ReaderNumber} = erlang:port_info(Reader, os_pid),
    Self = self(),
    %% the shell opens the pipe itself before it starts `sleep`, as
    %% terminal_kill_test's does, so that a writer holds it from the start
    Script = <<"exec 3> ", (list_to_binary(Fifo))/binary, "; sleep 300 >&3 2>&3 & echo $!">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start(<<"sh">>, [<<"-c">>, Script]),
               {Number, Status} = read_to_end(Sh, <<>>),
               Self ! {sleep, {binary_to_integer(string:trim(Number)), Status}}
           end, <<"main">>, ern_helpers:quiet()),
    {Sleep, 0} = ern_waits:wait(sleep),
    Ended = receive
                {Reader, {exit_status, ReaderStatus}} -> ReaderStatus
            after 5000 ->
                _ = os:cmd("kill -KILL " ++ integer_to_list(Sleep) ++ " "
                           ++ integer_to_list(ReaderNumber)),
                running
            end,
    ok = file:delete(Fifo),
    ?assertEqual(0, Ended).

%% report Appendix E.23: the processes the program started that are still
%% in its process group are killed with it as it exits, whatever holds its
%% outputs. The shell leaves a `sleep` that holds its output, or its
%% terminal, ignoring the hangup the shell's exit sends it, and the shell
%% ends by the termination or by itself. The read answers the exit at once,
%% and the group then holds no process but one ended and not yet taken by
%% the process that inherited it. The helper killed the group once both
%% outputs had ended, so the read waited on `sleep` and answered
%% `Left(Timeout)`.
%%
%% The test's own limit stands past the three reads' 15 seconds, which
%% bound a failure, and the kill after each read ends a `sleep` left
%% running. A process that has left the group, which E.23 does not promise
%% to kill, is not covered
group_killed_at_the_exit_test_() ->
    {timeout, 60, fun group_killed_at_the_exit/0}.

group_killed_at_the_exit() ->
    %% `sleep` is started before the shell says its number, its group's, so
    %% that it holds the output before the shell can end
    Waiting = [<<"-c">>, <<"trap '' HUP; sleep 1000 & echo $$; wait">>],
    Leaving = [<<"-c">>, <<"sleep 1000 & echo $$">>],
    Terminated = {{'Right', {'Exited', 143}}, []},
    ?assertEqual(Terminated,
                 left_at_the_exit(fun() -> start(<<"sh">>, Waiting) end, 'Termination')),
    ?assertEqual(Terminated,
                 left_at_the_exit(fun() -> start_terminal(<<"sh">>, Waiting, ?SIZE) end,
                                  'Termination')),
    ?assertEqual({{'Right', {'Exited', 0}}, []},
                 left_at_the_exit(fun() -> start(<<"sh">>, Leaving) end, none)).

%% The answer of the read that follows the number the shell Start starts
%% says, Signal sent to the shell first where it is one, and the states of
%% the processes still running in its group then.
left_at_the_exit(Start, Signal) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = Start(),
               Group = string:trim(read_until(Sh, <<"\n">>, <<>>)),
               case Signal of
                   none -> ok;
                   _ -> {'Right', 'Unit'} = signal(Sh, Signal)
               end,
               Last = read(Sh, 5000),
               Self ! {left, {Last, running_in(binary_to_list(Group))}},
               ern_rt:kill(Sh)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(left).

%% The states `ps` gives the processes of the process group Group, but
%% those ended and not yet taken by the process that inherited them.
running_in(Group) ->
    [State || Line <- string:split(os:cmd("ps -A -o pgid= -o stat="), "\n", all),
              [Of, State] <- [string:lexemes(Line, " ")], Of =:= Group, hd(State) =/= $Z].

%% report Appendix E.23: `kill` stops a program that has left its process
%% group, here for its parent's, the helper's, which the group's kill
%% misses. A regression test, written after the code: without the kill of
%% the program by its own number it lived on, and the helper and the run
%% waited on it; a program under a terminal, which leads its session and
%% cannot leave its group, is terminal_kill_test's.
%%
%% The program holds a named pipe the test reads, whose end shows that it
%% has ended. The run is a process of its own, since a program the kill
%% missed holds it, and the program and the reader are killed by their
%% numbers once the 5 seconds that bound a failure have passed
kill_reaches_a_program_out_of_its_group_test_() ->
    {timeout, 60, fun kill_reaches_a_program_out_of_its_group/0}.

kill_reaches_a_program_out_of_its_group() ->
    Fifo = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                         "ern_os_moved_" ++ os:getpid()),
    "" = os:cmd("mkfifo " ++ Fifo),
    Reader = open_port({spawn_executable, os:find_executable("cat")},
                       [{args, [Fifo]}, exit_status, binary]),
    {os_pid, ReaderNumber} = erlang:port_info(Reader, os_pid),
    Self = self(),
    %% the program opens the pipe before it says its number, so that a
    %% writer holds the pipe before the kill can come
    Script = <<"import os, sys, time\n"
               "os.setpgid(0, os.getpgid(os.getppid()))\n"
               "held = open(sys.argv[1], 'w')\n"
               "print(os.getpid(), flush=True)\n"
               "time.sleep(1000)\n">>,
    {_, RunRef} = spawn_monitor(
                    fun() ->
                        ok = ern_rt:run_main(
                               fun() ->
                                   {'Right', Python} =
                                       start(<<"python3">>,
                                             [<<"-c">>, Script, list_to_binary(Fifo)]),
                                   Number = read_until(Python, <<"\n">>, <<>>),
                                   Self ! {python, binary_to_integer(string:trim(Number))},
                                   ern_rt:kill(Python)
                               end, <<"main">>, ern_helpers:quiet())
                    end),
    Python = ern_waits:wait(python),
    Ended = receive
                {Reader, {exit_status, Status}} -> Status
            after 5000 ->
                _ = os:cmd("kill -KILL " ++ integer_to_list(Python) ++ " "
                           ++ integer_to_list(ReaderNumber)),
                running
            end,
    RunEnded = receive {'DOWN', RunRef, process, _, ExitReason} -> ExitReason end,
    ok = file:delete(Fifo),
    ?assertEqual({0, normal}, {Ended, RunEnded}).

%% report Appendix E.23: a `workingDirectory` that is empty answers
%% `Left(Invalid)`, as a variable's empty name does, before the helper is
%% opened. A regression test: the empty directory reached the helper, whose
%% `chdir` failed, and the start answered `Left(Other(": NotFound"))`, a
%% line that named no directory; a directory the helper cannot enter, whose
%% answer names it, is not covered
empty_working_directory_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Command = {'Command', <<"true">>, [], <<>>, [], {'Path', <<>>}},
               Self ! {started, started(Command)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', 'Invalid'}, ern_waits:wait(started)).

%% report Appendix E.23: a signal sent once the program has exited answers
%% `Left(Closed)`, and one the program handles is the program's to act on,
%% here a shell's trap that says so and exits with its own status. A
%% regression test, written after the code; a signal sent after the exit
%% and before the program's process has read it, which the helper answers,
%% is not covered
signal_after_the_exit_and_handled_test() ->
    Self = self(),
    Trap = <<"trap 'echo got; exit 7' TERM; echo ready; sleep 1000 > /dev/null 2>&1 & wait">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', True} = start(<<"true">>, []),
               {<<>>, 0} = read_to_end(True, <<>>),
               Self ! {exited, signal(True, 'Termination')},
               ern_rt:kill(True),
               {'Right', Sh} = start(<<"sh">>, [<<"-c">>, Trap]),
               <<"ready\n">> = read_until(Sh, <<"\n">>, <<>>),
               Sent = signal(Sh, 'Termination'),
               Self ! {handled, {Sent, read_to_end(Sh, <<>>)}},
               ern_rt:kill(Sh)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(exited)),
    ?assertEqual({{'Right', 'Unit'}, {<<"got\n">>, 7}}, ern_waits:wait(handled)).

%% report Appendix E.23, §6.6: a program's process lives on after the
%% program has exited: each read after the one that answered `Exited`
%% answers it again, a write `Left(Closed)`, a resize `Left(Closed)` too,
%% and `closeInput` `Unit`; a monitor sees its end only at its kill, after
%% which a resize faults as `Address.callForever` does on an ended process.
%% A regression test: before the rules, the process ended once a read had
%% answered `Exited`, and the resize answered `Right(Unit)`; a give after
%% the exit, and the owner's death then, are not covered
exited_program_lives_on_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', True} = start_terminal(<<"true">>, [], ?SIZE),
               MonitorRef = erlang:monitor(process, ern_rt:process_of(True)),
               {<<>>, 0} = read_to_end(True, <<>>),
               Answers = [read(True, 5000), write(True, <<"x">>, 5000), resize(True, ?SIZE),
                          close_input(True)],
               Self ! {after_the_exit, {Answers, read(True, 5000)}},
               ern_rt:kill(True),
               receive {'DOWN', MonitorRef, process, _, ExitReason} -> Self ! {ended, ExitReason}
               end,
               _ = ern_rt:spawn_monitored(fun() -> resize(True, ?SIZE) end,
                                          fun(Down) -> {later, Down} end, <<"resizer">>),
               receive {later, Down} -> Self ! {later, Down} end
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({[{'Right', {'Exited', 0}}, {'Left', 'Closed'}, {'Left', 'Closed'}, 'Unit'],
                  {'Right', {'Exited', 0}}},
                 ern_waits:wait(after_the_exit)),
    ?assertEqual({ern, killed}, ern_waits:wait(ended)),
    ?assertMatch({'Down', _, {'Fault', <<"callee had ended">>}, _}, ern_waits:wait(later)).

%% report Appendix E.23: a read whose caller has ended before it is answered
%% is dropped, and what it would have taken is the next read's: the piece
%% `cat` writes after a reader was killed in its read, and the exit status
%% after a second was. A regression test: before the rule, the read took the
%% piece for its ended caller, and an `Exited` so taken ended the process; a
%% caller that ends while the piece is on its way, before the process has
%% its `DOWN`, is not covered
read_of_an_ended_caller_dropped_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               killed_in_a_read(Cat),
               {'Right', 'Unit'} = write(Cat, <<"x\n">>, 5000),
               Piece = read(Cat, 5000),
               killed_in_a_read(Cat),
               'Unit' = close_input(Cat),
               Self ! {reads, {Piece, read(Cat, 5000)}},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Right', {'Stdout', <<"x\n">>}}, {'Right', {'Exited', 0}}},
                 ern_waits:wait(reads)).

%% report Appendix E.23: `readForever` is `read` without a time: a read that
%% waits answers the piece the program writes after it began, `cat`'s echo
%% of a write made once the program's process watches the reader, and last
%% the exit status, which each read after it, with a time or without,
%% answers again. Written with the request
read_forever_answers_what_comes_later_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Main = self(),
               Reader = ern_rt:spawn(fun() -> Main ! {piece, read_forever(Cat)} end,
                                     <<"reader">>),
               ok = ern_waits:watching(Cat, ern_rt:process_of(Reader)),
               {'Right', 'Unit'} = write(Cat, <<"x\n">>, 5000),
               Piece = receive {piece, Read} -> Read end,
               'Unit' = close_input(Cat),
               Exited = read_forever(Cat),
               Self ! {reads, [Piece, Exited, read_forever(Cat), read(Cat, 5000)]},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    Exited = {'Right', {'Exited', 0}},
    ?assertEqual([{'Right', {'Stdout', <<"x\n">>}}, Exited, Exited, Exited], ern_waits:wait(reads)).

%% report Appendix E.23, §6.6: a `readForever` faults as `read` does on a
%% program whose process has ended: one that waits as the program is killed
%% with `callee was killed`, and one after with `callee had ended`. The kill
%% comes once the program's process watches the reader. Written with the
%% request
read_forever_on_an_ended_program_faults_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Reader = ern_rt:spawn_monitored(fun() -> read_forever(Cat) end,
                                               fun(Down) -> {reader, Down} end, <<"reader">>),
               ok = ern_waits:watching(Cat, ern_rt:process_of(Reader)),
               ern_rt:kill(Cat),
               receive {reader, Down} -> Self ! {waiting, Down} end,
               _ = ern_rt:spawn_monitored(fun() -> read_forever(Cat) end,
                                         fun(Later) -> {later, Later} end, <<"reader">>),
               receive {later, Later} -> Self ! {later, Later} end
           end, <<"main">>, ern_helpers:quiet()),
    ?assertMatch({'Down', _, {'Fault', <<"callee was killed">>}, _}, ern_waits:wait(waiting)),
    ?assertMatch({'Down', _, {'Fault', <<"callee had ended">>}, _}, ern_waits:wait(later)).

%% report Appendix E.23: a `readForever` whose caller has ended before it is
%% answered is dropped as a `read` is, and what it would have taken is the
%% next read's: the piece `cat` writes after a reader was killed in its
%% read, and the exit status after a second was. Written with the request,
%% as read_of_an_ended_caller_dropped_test is
read_forever_of_an_ended_caller_dropped_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               killed_in_a_read(Cat, fun read_forever/1),
               {'Right', 'Unit'} = write(Cat, <<"x\n">>, 5000),
               Piece = read_forever(Cat),
               killed_in_a_read(Cat, fun read_forever/1),
               'Unit' = close_input(Cat),
               Self ! {reads, {Piece, read_forever(Cat)}},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Right', {'Stdout', <<"x\n">>}}, {'Right', {'Exited', 0}}},
                 ern_waits:wait(reads)).

%% report Appendix E.23: a piece that comes for a read whose caller has
%% ended, before the program's process has the caller's `DOWN`, is kept for
%% the next read, the host asked whether the caller lives before the piece
%% is answered. The window is made here: the program's process is held still
%% while the test gives it the frame the helper would send, `o` and the
%% bytes, and the reader is killed once the frame stands in the process's
%% mailbox, so that the `DOWN`, which the kill causes, comes behind it
%% whatever the senders. A regression test: before the rule, the piece went
%% to the ended reader and the next read timed out; a caller that ends with
%% its answer in its mailbox is every call's, and not covered
piece_ahead_of_the_down_kept_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Helper = helper_of(Cat),
               Reader = ern_rt:spawn_monitored(fun() -> read(Cat, 60000) end,
                                               fun(Down) -> {reader, Down} end, <<"reader">>),
               ok = ern_waits:watching(Cat, ern_rt:process_of(Reader)),
               erlang:suspend_process(Cat),
               Frame = {Helper, {data, <<"ox\n">>}},
               Cat ! Frame,
               {messages, Messages} = erlang:process_info(Cat, messages),
               true = lists:member(Frame, Messages),
               ern_rt:kill(Reader),
               receive {reader, _} -> ok end,
               erlang:resume_process(Cat),
               Self ! {read, read(Cat, 1000)},
               ern_rt:kill(Cat)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Right', {'Stdout', <<"x\n">>}}, ern_waits:wait(read)).

%% report Appendix E.21, E.23: a running program's process is not held at
%% its helper's port when the port takes no more: while a write waits for
%% the port, which the program's writer gives it, the process reads
%% `Receiving`, and once the port takes again it waits as it did before. A
%% regression test, written after the code: the process wrote to the port
%% itself, and read `Suspended`, the host holding it there.
%%
%% The helper is stopped by its signal before anything is written, so that
%% it reads nothing of its port: the first write, more than the port holds,
%% fills it past its limit, and the second waits. The process is read once
%% it has taken both. Continued, the helper gives the program both, which
%% it takes to its end. It does not cover a port of the node's own other
%% than a program's helper's.
held_at_its_port_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, [<<"-c">>, <<"exec cat >/dev/null">>]),
               Number = integer_to_list(helper_number(Program)),
               Bytes = binary:copy(<<"x">>, 1 bsl 20),
               %% the program's process and the writers wait, which this
               %% one counts as timed so that it is no deadlock (§8.6)
               ern_rt:timed(),
               ok = ern_waits:waiting(Program),
               Before = activity_of(Program),
               _ = os:cmd("kill -STOP " ++ Number),
               Held = try
                          writes_taken(Program, Bytes, 600000, 2),
                          activity_of(Program)
                      after
                          os:cmd("kill -CONT " ++ Number)
                      end,
               [receive {written, _} -> ok end || _ <- [first, second]],
               ok = ern_waits:waiting(Program),
               After = activity_of(Program),
               ern_rt:untimed(),
               Self ! {activities, [Before, Held, After]},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(['Receiving', 'Receiving', 'Receiving'], ern_waits:wait(activities)).

%% Count writes of Bytes to Program, each given Ms, from writers of their
%% own, whose ends come to this process as `{written, Down}`; returned once
%% the program's process has taken each, its mailbox empty and the process
%% waiting, or held where the host holds it.
writes_taken(Program, Bytes, Ms, Count) ->
    Writers = [ern_rt:spawn_monitored(fun() -> write(Program, Bytes, Ms) end,
                                      fun(Down) -> {written, Down} end, <<"M.writer:1">>)
               || _ <- lists:seq(1, Count)],
    lists:foreach(fun(Writer) -> ok = ern_waits:calling(ern_rt:process_of(Writer)) end, Writers),
    ok = ern_waits:until(Program,
                         fun() ->
                             [{message_queue_len, Queued}, {status, Status}] =
                                 erlang:process_info(Program, [message_queue_len, status]),
                             Queued =:= 0 andalso lists:member(Status, [waiting, suspended])
                         end).

%% report §6.9, §8.6, Appendix E.23: a program's process ends at once while
%% its helper takes nothing and a write waits for it, by a kill, by its
%% owner's end and by the program's end, its `DOWN` coming while the helper
%% is still stopped, as held_at_its_port_test holds it; continued, the
%% helper and its program are gone. A regression test, written after the
%% code. The process wrote to the port itself before, and the host held it
%% there: its owner's end, which comes to it as a message, waited on the
%% helper, while a kill and the program's end, signals it did not trap,
%% ended it; a process that traps exits and writes to the port itself
%% takes those as messages too. It does not cover the end of a process
%% linked to the program's
killed_held_at_its_port_test_() ->
    [{atom_to_list(End), fun() -> ?assertEqual({ended, gone, gone}, held_and_ended(End)) end}
     || End <- [kill, owner, program_end]].

%% A program held as held_at_its_port_test holds it, ended the way End
%% names; then whether its process ended while the helper was stopped, and
%% whether the helper and its program are gone once it is continued.
held_and_ended(End) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Main = self(),
               {Program, Owner} = owned(End, Main, <<"sh">>,
                                        [<<"-c">>, <<"exec cat >/dev/null">>]),
               Helper = helper_number(Program),
               Cat = child_number(Helper),
               ern_rt:timed(),
               ok = ern_waits:waiting(Program),
               signaled(Helper, "STOP"),
               writes_taken(Program, binary:copy(<<"x">>, 1 bsl 20), 600000, 2),
               MonitorRef = erlang:monitor(process, Program),
               case End of
                   kill -> ern_rt:kill(Program);
                   owner -> Owner ! go;
                   program_end -> ok
               end,
               Self ! {held, {Program, Helper, Cat}},
               case End of
                   program_end -> ok;
                   _ -> receive {'DOWN', MonitorRef, process, Program, _} -> ok end
               end
           end, <<"main">>, ern_helpers:quiet()),
    {Program, Helper, Cat} = ern_waits:wait(held),
    MonitorRef = erlang:monitor(process, Program),
    receive {'DOWN', MonitorRef, process, Program, _} -> ok end,
    signaled(Helper, "CONT"),
    Deadline = erlang:monotonic_time(millisecond) + 5000,
    {ended, ended_number(integer_to_list(Helper), Deadline), ended_number(Cat, Deadline)}.

%% A program of Name and Arguments started, with its owner: the process of
%% Main, or for End `owner` a process of its own, which ends when sent `go`.
owned(owner, Main, Name, Arguments) ->
    Owner = erlang:spawn(fun() ->
                             {'Right', Program} = start(Name, Arguments),
                             Main ! {started, Program},
                             receive go -> ok end
                         end),
    receive {started, Program} -> {Program, Owner} end;
owned(_, Main, Name, Arguments) ->
    {'Right', Program} = start(Name, Arguments),
    {Program, Main}.

%% Until the process of Number has ended, as the host shows it, `gone`: it
%% has no entry, or is a zombie its parent has yet to reap. Nothing tells
%% this process of another process's end, so the host is asked again at
%% once each time, within a bound for a failure.
ended_number(Number, Deadline) ->
    case file:read_file("/proc/" ++ Number ++ "/stat") of
        {error, _} ->
            gone;
        {ok, Stat} ->
            [_, After] = string:split(binary_to_list(Stat), ")", trailing),
            case string:trim(After, leading) of
                [$Z | _] -> gone;
                _ ->
                    case erlang:monotonic_time(millisecond) < Deadline of
                        true -> ended_number(Number, Deadline);
                        false -> running
                    end
            end
    end.

%% report Appendix E.23: a read's and a write's milliseconds hold while the
%% helper takes nothing and a write waits for it: a read given a time, and
%% a write given one that waits behind the first, each answer
%% `Left(Timeout)` once the time has passed. The bound is derived from the
%% time given: an answer cannot come before it, and what comes after it is
%% the host's timer reaching the program's process and the answer's
%% message, which wait on nothing, so each comes before the time has passed
%% again; an answer the write held back would wait for the helper, which is
%% stopped until both have come. A regression test, written after the code:
%% the process wrote to the port itself, the host held it there, and it
%% took neither time. It does not cover a signal or a resize, which wait
%% for the helper's answer however long
times_held_while_a_write_waits_test() ->
    Ms = 300,
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, [<<"-c">>, <<"exec cat >/dev/null">>]),
               Helper = helper_number(Program),
               Bytes = binary:copy(<<"x">>, 1 bsl 20),
               ern_rt:timed(),
               ok = ern_waits:waiting(Program),
               signaled(Helper, "STOP"),
               %% the first write fills the port, which takes no more
               writes_taken(Program, Bytes, 600000, 1),
               Main = self(),
               Asked = [erlang:spawn(fun() ->
                                         Began = erlang:monotonic_time(millisecond),
                                         Answer = Ask(),
                                         Main ! {timed, Answer,
                                                 erlang:monotonic_time(millisecond) - Began}
                                     end)
                        || Ask <- [fun() -> write(Program, Bytes, Ms) end,
                                   fun() -> read(Program, Ms) end]],
               Answers = [receive {timed, Answer, Took} -> {Answer, Took} end || _ <- Asked],
               signaled(Helper, "CONT"),
               ern_rt:untimed(),
               Self ! {answers, Answers},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    Answers = ern_waits:wait(answers),
    ?assertEqual([{'Left', 'Timeout'}, {'Left', 'Timeout'}], [Answer || {Answer, _} <- Answers]),
    ?assertEqual([], [Took || {_, Took} <- Answers, Took < Ms orelse Took >= 2 * Ms]).

%% report Appendix E.21, E.23: a running program's memory counts its
%% writer's, which holds a write that waits for the helper, where the
%% program's own process has let the bytes go. The helper is stopped by its
%% signal before anything is written: the first write fills its port, and
%% the second waits in the writer. The program's process is collected
%% before it is read, so that it holds nothing it has dropped.
program_memory_counts_its_writer_test() ->
    Size = 1 bsl 20,
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sh">>, [<<"-c">>, <<"exec cat >/dev/null">>]),
               Number = integer_to_list(helper_number(Program)),
               %% the program's process and the writers wait, which this
               %% one counts as timed so that it is no deadlock (§8.6)
               ern_rt:timed(),
               ok = ern_waits:waiting(Program),
               _ = os:cmd("kill -STOP " ++ Number),
               Counted = try
                             writes_taken(Program, binary:copy(<<0>>, Size), 600000, 2),
                             erlang:garbage_collect(Program),
                             {binary, Own} = erlang:process_info(Program, binary),
                             {'Some', {'Status', _, _, _, Memory}} = ern_rt:status(Program),
                             {Own, Memory >= Size}
                         after
                             os:cmd("kill -CONT " ++ Number)
                         end,
               [receive {written, _} -> ok end || _ <- [first, second]],
               ern_rt:untimed(),
               Self ! {counted, Counted},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({[], true}, ern_waits:wait(counted)).

%% report Appendix E.23: a running program's writer ends with the program's
%% process, and as the program ends where the process lives on, so that no
%% process of the program's is left past its end but the process that lives
%% on: by its kill, its owner's end, its exit read, the end of its input
%% under a terminal, after which its exit is read, and its helper's
%% failure. The processes made since the program started are counted once
%% the writer has ended. A regression test, written with the code: the
%% code before had no writer, and the test fails there for want of one
writer_ends_with_the_program_test_() ->
    [{atom_to_list(End), fun() -> ?assertEqual([], left_after(End)) end}
     || End <- [kill, owner, exit_read, close_input, helper_failed]].

%% The processes made since the program started that are alive once the
%% program has ended the way End names and its writer has ended, but the
%% program's process.
left_after(End) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Main = self(),
               Before = erlang:processes(),
               {Program, Owner} = case End of
                                      exit_read -> owned(End, Main, <<"true">>, []);
                                      close_input ->
                                          {'Right', Cat} = start_terminal(<<"cat">>, [], ?SIZE),
                                          {Cat, Main};
                                      _ -> owned(End, Main, <<"sleep">>, [<<"1000">>])
                                  end,
               Writer = writer_of(Program),
               WriterRef = erlang:monitor(process, Writer),
               ended_so(End, Program, Owner),
               receive {'DOWN', WriterRef, process, Writer, _} -> ok end,
               Self ! {left, [Pid || Pid <- erlang:processes() -- Before, Pid =/= Program,
                                     erlang:is_process_alive(Pid)]},
               ern_rt:kill(Program)
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(left).

%% Program ended the way End names, its owner Owner: its process's end
%% waited for where it ends, and where it lives on, the answer that comes
%% after the end.
ended_so(End, Program, Owner) when End =:= kill; End =:= owner ->
    MonitorRef = erlang:monitor(process, Program),
    case End of
        kill -> ern_rt:kill(Program);
        owner -> Owner ! go
    end,
    receive {'DOWN', MonitorRef, process, Program, _} -> ok end;
ended_so(exit_read, Program, _) ->
    {<<>>, 0} = read_to_end(Program, <<>>);
ended_so(close_input, Program, _) ->
    'Unit' = close_input(Program),
    {_, _} = read_to_end(Program, <<>>);
ended_so(helper_failed, Program, _) ->
    Helper = helper_number(Program),
    %% the program, which a helper killed so leaves running
    Sleep = child_number(Helper),
    signaled(Helper, "KILL"),
    _ = os:cmd("kill -KILL " ++ Sleep),
    ReadReply = alias(),
    Program ! {'Read', 5000, {ReadReply, self()}},
    {fault, _} = answer(ReadReply).

%% The writer of a running program, the one process linked to the
%% program's process that is not Os's.
writer_of(Program) ->
    {links, Links} = erlang:process_info(Program, links),
    Os = ern_rt:system_process(os),
    [Writer] = [Pid || Pid <- Links, is_pid(Pid), Pid =/= Os],
    Writer.

%% What Process.status says Pid, a live process the runtime started, does.
activity_of(Pid) ->
    {'Some', {'Status', _, _, Activity, _}} = ern_rt:status(Pid),
    Activity.

%% A reader of Program killed while its read waits, once the program's
%% process watches it, and returned from once that process no longer
%% does, so that its `DOWN` comes before what the caller sends after.
killed_in_a_read(Program) ->
    killed_in_a_read(Program, fun(Read) -> read(Read, 60000) end).

%% The same, the reader's read made by Read.
killed_in_a_read(Program, Read) ->
    Reader = ern_rt:spawn_monitored(fun() -> Read(Program) end,
                                    fun(Down) -> {reader, Down} end, <<"reader">>),
    Pid = ern_rt:process_of(Reader),
    ok = ern_waits:watching(Program, Pid),
    ern_rt:kill(Reader),
    receive {reader, _} -> ok end,
    ok = ern_waits:unwatched(Program, Pid).

%% report Appendix E.23: a terminal the host cannot open is the helper's
%% to say, with a 't' frame and the host's reason, where 'f' would say the
%% program did not start: here for want of a file descriptor for the
%% terminal itself; the run's last frame, after which the helper waits to
%% be let go. Under `make sanitize` the leak checker is off for this run
%% alone, as helper_gives_the_hosts_reason_test says
helper_says_the_terminal_could_not_be_opened_test() ->
    Helper = open_port({spawn, "sh -c \"ulimit -n 5; ASAN_OPTIONS=$ASAN_OPTIONS:detect_leaks=0"
                        " exec " ++ helper_path() ++ " terminal 24 80\""},
                       [{packet, 4}, binary, exit_status]),
    true = port_command(Helper, command(["true"])),
    ?assertEqual(<<"temfile">>,
                 receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    port_close(Helper).

%% Appendix E.23: a program's exit is reported as it happens, once its
%% outputs have ended. A regression test: the helper asked for the exit as
%% they ended and, the program not yet gone, slept 50 ms before asking
%% again, so `cat`, which ends a moment after its outputs close, was
%% reported 50 ms late (the log's *MVP 2.99d's First Measurements*). The
%% fastest of five is held under 25 ms, which a timer of 50 cannot give;
%% what a loaded host adds to one wake is not covered
exit_reported_as_it_happens_test() ->
    ?assert(lists:min([exit_reported_after_input_ends() || _ <- lists:seq(1, 5)]) < 25).

%% The milliseconds from the end of `cat`'s input to its exit's frame.
exit_reported_after_input_ends() ->
    Helper = helper(["cat"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    %% a request for output, so that the helper sees the outputs end
    true = port_command(Helper, <<"n">>),
    Start = erlang:monotonic_time(millisecond),
    true = port_command(Helper, <<"e">>),
    receive {Helper, {data, <<"x", _:32>>}} -> ok after 5000 -> erlang:error(no_exit) end,
    Elapsed = erlang:monotonic_time(millisecond) - Start,
    port_close(Helper),
    Elapsed.

%% The helper run on a command, as ern_os runs it: the command comes as the
%% first frame.
helper(Command) ->
    Helper = open_port({spawn_executable, helper_path()},
                       [{args, ["run"]}, {packet, 4}, binary, exit_status]),
    true = port_command(Helper, command(Command)),
    Helper.

helper_path() ->
    filename:join([filename:dirname(code:which(ern_os)), "..", "priv", "ern_exec"]).

command(Parts) ->
    iolist_to_binary(["c" | [[Part, 0] || Part <- Parts]]).

start(Program, Arguments) ->
    started(inheriting(Program, Arguments)).

%% Command started under pipes, or why it could not start.
started(Command) ->
    Self = self(),
    ern_rt:call_forever(ern_rt:system_process(os), fun(Reply) ->
                                                       {'Start', Command, Self, Reply}
                                                   end).

%% Size is `Terminal.Size(rows, columns)`.
start_terminal(Program, Arguments, Size) ->
    Self = self(),
    Command = inheriting(Program, Arguments),
    ern_rt:call_forever(ern_rt:system_process(os), fun(Reply) ->
                                                       {'StartTerminal', Command, Size, Self,
                                                        Reply}
                                                   end).

%% `Os.Command(program, arguments, <<>>, [], Os.workingDirectory)`, which
%% sets no variable and runs where the test runs.
inheriting(Program, Arguments) ->
    {'Command', Program, Arguments, <<>>, [], {'Path', ern_os:working_directory()}}.

read(Program, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Read', Ms, Reply} end).

%% Report Appendix E.23: a read without a time, as `Os.readForever` asks it.
read_forever(Program) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'ReadForever', Reply} end).

write(Program, Bytes, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Write', Bytes, Ms, Reply} end).

signal(Program, Signal) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'SendSignal', Signal, Reply} end).

resize(Program, Size) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Resize', Size, Reply} end).

%% Report Appendix E.23: `Os.closeInput`, as a program calls it.
close_input(Program) ->
    (ern_named:function('ern@os', closeInput))(Program).

%% What the program wrote, read until it holds Text, each piece `Stdout`.
read_until(Program, Text, Output) ->
    case binary:match(Output, Text) of
        nomatch ->
            {'Right', {'Stdout', Bytes}} = read(Program, 5000),
            read_until(Program, Text, <<Output/binary, Bytes/binary>>);
        _ ->
            Output
    end.

%% What the program wrote, each piece `Stdout`, and its exit status, read
%% to its end.
read_to_end(Program, Output) ->
    case read(Program, 5000) of
        {'Right', {'Stdout', Bytes}} -> read_to_end(Program, <<Output/binary, Bytes/binary>>);
        {'Right', {'Exited', Status}} -> {Output, Status}
    end.

%% The answer the runtime's process gives, in Ernest's form (report §12.2).
answer(Reply) ->
    ern_rt:timed(),
    receive
        {Reply, answered, Value} -> ern_rt:untimed(), Value;
        {Reply, fault, Cause} -> ern_rt:untimed(), {fault, Cause}
    after 5000 -> ern_rt:untimed(), timeout
    end.

%% A program that takes no input until it is sent the user's first signal,
%% and then runs Then; its number is the first line it writes, and it
%% ignores the interrupt, which a test sends as a barrier: its answer comes
%% once the helper has read every frame before it. Its `sleep` waits in the
%% background, where the signal ends the shell's wait.
behind(Then) ->
    <<"trap '", Then/binary, "' USR1; trap '' INT; echo $$; sleep 1000 > /dev/null 2>&1 & wait">>.

%% The number of the program a program `behind/1` gives started, the first
%% line it wrote.
first_line(Program) ->
    binary_to_integer(string:trim(read_until(Program, <<"\n">>, <<>>))).

%% The port of the helper of a running program, the one whose output comes
%% to the program's process.
helper_of(Program) ->
    [Helper] = [Port || Port <- erlang:ports(),
                        erlang:port_info(Port, connected) =:= {connected, Program}],
    Helper.

%% The operating system's number for the helper of a running program.
helper_number(Program) ->
    {os_pid, Number} = erlang:port_info(helper_of(Program), os_pid),
    Number.

%% A field of what the host shows of the process of Number, in kilobytes:
%% VmRSS, what it holds resident, or VmHWM, the most it has held.
status_kb(Number, Field) ->
    {ok, Status} = file:read_file("/proc/" ++ integer_to_list(Number) ++ "/status"),
    [Line] = [Line || Line <- string:split(binary_to_list(Status), "\n", all),
                      lists:prefix(Field ++ ":", Line)],
    [_, Kilobytes | _] = string:lexemes(Line, " \t"),
    list_to_integer(Kilobytes).

%% The signal Name sent to the process of Number.
signaled(Number, Name) ->
    [] = os:cmd("kill -" ++ Name ++ " " ++ integer_to_list(Number)),
    ok.

%% report §12.5, §11.2: a node's ernest.pid is made writable by its owner
%% alone, whatever the mask, and never through a link; and a signal to the
%% node that holds it is sent where the file is its user's own, whatever
%% its mode, its group or every user able to write it, and whoever may
%% write its directory: neither is tested. The number is a living
%% process's, which the signal 0 asks after, and whose end lets the lock
%% go.
%%
%% A regression test, written after the code: the file was made 0666
%% under the mask, group-writable under Ubuntu's 002, and a link was
%% followed; then a file its group may write was refused as every user's,
%% and then one every user may write. A file another user owns, the
%% superuser's to another user or another user's to the superuser, which a
%% test run as one user cannot make, is not covered
node_file_test() ->
    Dir = node_dir("ern_os_node_"),
    PidFile = filename:join(Dir, "ernest.pid"),
    {Living, Number} = living(),
    Holder = held(PidFile, Number),
    {ok, #file_info{mode = Mode}} = file:read_file_info(PidFile),
    ?assertEqual(8#644 band bnot ern_os:umask(), Mode band 8#777),
    ?assertEqual(sent, ern_os:node_signaled(PidFile, 0, false)),
    Signaled = fun(Path, Given) ->
                   ok = file:change_mode(Path, Given),
                   ern_os:node_signaled(PidFile, 0, false)
               end,
    ?assertEqual([sent, sent, sent],
                 [Signaled(Path, Given)
                  || {Path, Given} <- [{PidFile, 8#664}, {PidFile, 8#666}, {Dir, 8#777}]]),
    ok = file:change_mode(Dir, 8#700),
    Link = filename:join(Dir, "linked.pid"),
    ok = file:make_symlink(PidFile, Link),
    Followed = {failed, "too many levels of symbolic links"},
    ?assertEqual({Followed, Followed},
                 {ern_os:locked(Link, Number), ern_os:node_signaled(Link, 0, false)}),
    ended_by_termination(PidFile, Living),
    ?assertNot(filelib:is_file(PidFile)),
    released(Holder).

%% report §12.5, §11.2: the helper holds a node's lock until the process
%% it watches has ended, and not until its port closes, which the node's
%% end closes before the process has ended: the holder of the port gone,
%% the lock is still held and the process still signaled as the node; once
%% the process has ended, the file is removed and then the lock let go, so
%% that a wait on the lock returns with the file gone. A regression test,
%% written after the code: the lock went as the port closed. It does not
%% cover a node's own end, which test/ern_nodes_tests.erl's
%% node_ends_over_an_unread_socket_test_ holds
lock_outlives_its_port_test() ->
    PidFile = filename:join(node_dir("ern_os_outlives_"), "ernest.pid"),
    {Living, Number} = living(),
    released(held(PidFile, Number)),
    ?assertEqual(sent, ern_os:node_signaled(PidFile, 0, false)),
    ?assertEqual({ok, list_to_binary(integer_to_list(Number) ++ "\n")}, file:read_file(PidFile)),
    ended_by_termination(PidFile, Living),
    ?assertNot(filelib:is_file(PidFile)).

%% report §12.5: the helper removes only the file it holds: one put at the
%% path in place of it while the node runs stays at the node's end, and so
%% does the one it held, renamed away. A regression test, written after the
%% code; it does not cover a file put in place in the instant between the
%% helper's check of the path and its removal of the file
replaced_file_kept_test() ->
    Dir = node_dir("ern_os_replaced_"),
    PidFile = filename:join(Dir, "ernest.pid"),
    Renamed = filename:join(Dir, "renamed.pid"),
    {Living, Number} = living(),
    Holder = held(PidFile, Number),
    ok = file:rename(PidFile, Renamed),
    ok = file:write_file(PidFile, <<"999999\n">>),
    ended_by_termination(Renamed, Living),
    released(Holder),
    ?assertEqual({{ok, <<"999999\n">>}, {ok, list_to_binary(integer_to_list(Number) ++ "\n")}},
                 {file:read_file(PidFile), file:read_file(Renamed)}).

%% A directory of the test's own for a node's file, named for the test.
node_dir(Prefix) ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        Prefix ++ os:getpid() ++ "_"
                            ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% A living process that is no node, which reads its input and echoes it,
%% and its number, once it has echoed: until it first runs, the process the
%% host forks ignores the termination, and one sent it then would not show
%% (docs/otp_bugs.md, 22).
living() ->
    Living = open_port({spawn_executable, os:find_executable("cat")}, [binary, exit_status]),
    true = port_command(Living, <<"running">>),
    receive {Living, {data, <<"running">>}} -> ok end,
    {os_pid, Number} = erlang:port_info(Living, os_pid),
    {Living, Number}.

%% A process that holds the helper's port of a lock on PidFile for the
%% process Number, until it is told to stop, once the lock is taken.
held(PidFile, Number) ->
    Self = self(),
    Holder = spawn(fun() ->
                       Self ! {locked, ern_os:locked(PidFile, Number)},
                       receive stop -> ok end
                   end),
    ?assertEqual(locked, ern_waits:wait(locked)),
    Holder.

%% Until the holder of a lock's port has ended, the port closed with it.
released(Holder) ->
    MonitorRef = erlang:monitor(process, Holder),
    Holder ! stop,
    receive {'DOWN', MonitorRef, process, Holder, _} -> ok end.

%% report §12.5, §11.2: the process the lock on PidFile watches ended by
%% termination, as `ern stop` ends a node, and the lock waited for, which
%% the wait returns once it has gone.
ended_by_termination(PidFile, Living) ->
    ?assertEqual(sent, ern_os:node_signaled(PidFile, 15, true)),
    ?assertEqual(128 + 15, receive {Living, {exit_status, Status}} -> Status end).

%% report §11, §12.5: a node's ernest.pid whose name reaches no regular
%% file, a named pipe, a socket or a directory, is not opened, neither to
%% lock it nor to signal the node it names, and the helper says so; a job
%% that opened the pipe would not end, which is how the test shows that
%% none does. A device is not covered
unopened_node_file_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_os_unopened_" ++ os:getpid()),
    ok = filelib:ensure_path(Dir),
    PidFile = filename:join(Dir, "ernest.pid"),
    Number = list_to_integer(os:getpid()),
    Answers = fun() ->
                  {ern_os:locked(PidFile, Number), ern_os:node_signaled(PidFile, 0, false),
                   ern_os:node_signaled(PidFile, 15, true)}
              end,
    "" = os:cmd("mkfifo " ++ PidFile),
    Pipe = Answers(),
    ok = file:delete(PidFile),
    {ok, Socket} = gen_udp:open(0, [{ifaddr, {local, PidFile}}]),
    Bound = Answers(),
    ok = gen_udp:close(Socket),
    ok = file:delete(PidFile),
    ok = file:make_dir(PidFile),
    Directory = Answers(),
    ok = file:del_dir(PidFile),
    ok = file:del_dir(Dir),
    ?assertEqual(lists:duplicate(3, {unopened, unopened, unopened}), [Pipe, Bound, Directory]).

%% report §12.5: a node's ernest.pid that an earlier node left, which others
%% may write, as one made under the mask 002 before 0.9.0 is, is made its
%% owner's alone to write once the node holds its lock, its other bits as
%% they were, and is then signaled as the node's. A regression test: before
%% the rule, the node took the file as it found it and `ern stop` refused it
found_node_file_test() ->
    PidFile = filename:join(node_dir("ern_os_found_"), "ernest.pid"),
    ok = file:write_file(PidFile, <<"999999\n">>),
    ok = file:change_mode(PidFile, 8#664),
    {Living, Number} = living(),
    Holder = held(PidFile, Number),
    {ok, #file_info{mode = Mode}} = file:read_file_info(PidFile),
    Signaled = ern_os:node_signaled(PidFile, 0, false),
    ended_by_termination(PidFile, Living),
    released(Holder),
    ?assertEqual({8#644, sent, false}, {Mode band 8#777, Signaled, filelib:is_file(PidFile)}).

%% report §11.9: a second run waits for a job's lock: the second's answer
%% comes only once the first has let it go, its port closed with the
%% process that owns it, and the path then names the file the first held.
%% The wait is shown by order, and no wait is timed: before the first lets
%% go, the second's answer is looked for once without waiting, a weak
%% check, since the second's helper may not yet have asked for the lock.
%% The first's helper lets the lock go only as it exits, so a removal of
%% the file at its end would show.
job_lock_waits_test() ->
    Path = filename:join(node_dir("ern_os_job_lock_"), ".unpack"),
    First = job_held(Path),
    {ok, #file_info{inode = Held}} = file:read_file_info(Path),
    Self = self(),
    Second = spawn(fun() ->
                       Self ! {second, ern_os:job_locked(Path)},
                       receive stop -> ok end
                   end),
    Early = receive {second, Answer} -> {early, Answer} after 0 -> waiting end,
    released(First),
    ?assertEqual({waiting, locked}, {Early, ern_waits:wait(second)}),
    ?assertMatch({ok, #file_info{inode = Held}}, file:read_file_info(Path)),
    released(Second).

%% report §11.9, Appendix E.17: a job's lock makes its file where it is
%% absent, a regular file with the permission bits the mask leaves of 0666.
job_lock_makes_its_file_test() ->
    Path = filename:join(node_dir("ern_os_job_made_"), ".unpack"),
    ?assertNot(filelib:is_file(Path)),
    Holder = job_held(Path),
    {ok, #file_info{type = Type, mode = Mode}} = file:read_file_info(Path),
    released(Holder),
    ?assertEqual({regular, 8#666 band bnot ern_os:umask()}, {Type, Mode band 8#777}).

%% report §11, §11.9: a job's lock is taken only where its name reaches a
%% regular file, a link followed: a link to a regular file is locked, and a
%% directory, a link to one and a named pipe are not opened, and are
%% `unopened`; a job that opened the pipe would not end, which is how the
%% test shows that none does. A device and a socket are not covered.
job_lock_reaches_a_regular_file_test() ->
    Dir = node_dir("ern_os_job_unopened_"),
    Path = filename:join(Dir, ".unpack"),
    Target = filename:join(Dir, "target"),
    ok = file:write_file(Target, <<>>),
    ok = file:make_symlink(Target, Path),
    released(job_held(Path)),
    ok = file:delete(Path),
    ok = file:make_dir(Path),
    Directory = ern_os:job_locked(Path),
    ok = file:del_dir(Path),
    ok = file:make_dir(Target ++ "_dir"),
    ok = file:make_symlink(Target ++ "_dir", Path),
    Linked = ern_os:job_locked(Path),
    ok = file:delete(Path),
    "" = os:cmd("mkfifo " ++ Path),
    Pipe = ern_os:job_locked(Path),
    ?assertEqual({unopened, unopened, unopened}, {Directory, Linked, Pipe}).

%% A process that holds the helper's port of a job's lock on Path, until it
%% is told to stop, once the lock is taken.
job_held(Path) ->
    Self = self(),
    Holder = spawn(fun() ->
                       Self ! {job_locked, ern_os:job_locked(Path)},
                       receive stop -> ok end
                   end),
    ?assertEqual(locked, ern_waits:wait(job_locked)),
    Holder.

%% report §12.5: the helper sends a process a signal and says how it went,
%% the signal 0 asking whether the process lives: this host's process
%% lives, a process number nothing holds names none, and the first process
%% lives and is the superuser's, which a test run as another user is not
%% allowed to signal; a helper that ends without saying, here at a signal
%% number it refuses, answers failed. The last is a regression test,
%% written after the code: the wait took no such end, and waited for ever
signal_test() ->
    ?assertEqual(sent, ern_os:signal(0, list_to_integer(os:getpid()))),
    ?assertEqual(failed, ern_os:signal(1000, list_to_integer(os:getpid()))),
    Port = open_port({spawn_executable, os:find_executable("true")}, [exit_status]),
    {os_pid, Gone} = erlang:port_info(Port, os_pid),
    receive {Port, {exit_status, 0}} -> ok end,
    ?assertEqual(none, ern_os:signal(0, Gone)),
    case os:getenv("USER") of
        "root" -> ok;
        _ -> ?assertEqual(others, ern_os:signal(0, 1))
    end.
