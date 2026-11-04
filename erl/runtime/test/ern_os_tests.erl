%% Report Appendix E.23: the process behind a program Os.start starts.
-module(ern_os_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% The size a terminal of the tests begins with, `Terminal.Size(24, 80)`.
-define(SIZE, {'Size', 24, 80}).

%% Appendix E.23, report §7.4: a write and a read that wait while the helper
%% ends fault their callers, the runtime's own failure. A regression test:
%% the process gave them to the port the helper's end had closed, and
%% crashed with badarg; and of the rule, before which they were answered
%% `Left(Other(...))`
helper_ends_under_a_write_and_a_read_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>]),
               {links, Links} = process_info(Program, links),
               [Helper] = [Link || Link <- Links, is_port(Link)],
               {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
               erlang:suspend_process(Program),
               WriteReply = alias(),
               Program ! {'Write', <<"x">>, 5000, {WriteReply, self()}},
               ReadReply = alias(),
               Program ! {'Read', 5000, {ReadReply, self()}},
               PortRef = erlang:monitor(port, Helper),
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               %% the port closes once the host has seen the helper end
               receive {'DOWN', PortRef, port, Helper, _} -> ok end,
               erlang:resume_process(Program),
               Self ! {write, answer(WriteReply)},
               Self ! {read, answer(ReadReply)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Failed = {fault, <<"the runtime's helper ern_exec failed">>},
    ?assertEqual(Failed, wait(write)),
    ?assertEqual(Failed, wait(read)).

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
               {links, Links} = process_info(Program, links),
               [Helper] = [Link || Link <- Links, is_port(Link)],
               {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
               PortRef = erlang:monitor(port, Helper),
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               %% the port closes once the host has seen the helper end, and
               %% the program waits once it has taken that
               ern_rt:timed(),
               receive {'DOWN', PortRef, port, Helper, _} -> ok end,
               ok = ern_waits:waiting(Program),
               ern_rt:untimed(),
               Self ! {queued, process_info(Program, message_queue_len)},
               ReadReply = alias(),
               Program ! {'Read', 5000, {ReadReply, self()}},
               Self ! {read, answer(ReadReply)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({message_queue_len, 0}, wait(queued)),
    ?assertEqual({fault, <<"the runtime's helper ern_exec failed">>}, wait(read)).

%% Appendix E.23: an argument longer than the host takes is the program's
%% failure to start, with the host's reason. A regression test: the
%% arguments were the helper's own, which the host would not start, and
%% `start` answered that the helper failed
argument_too_long_test() ->
    Self = self(),
    Long = binary:copy(<<"x">>, 200000),
    ok = ern_rt:run_main(fun() -> Self ! {started, start(<<"echo">>, [Long])} end,
                         <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Left', {'Other', <<"argument list too long">>}}, wait(started)).

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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual([{'Left', 'Timeout'}, {'Right', {'Stdout', <<"hi\n">>}},
                  {'Right', {'Stdout', <<"there\n">>}}, {'Right', {'Exited', 0}}],
                 wait(reads)).

%% Appendix E.23, E.0 shape rule 8: a read given no time, 0 or below, has
%% run out as it begins and answers `Left(Timeout)`, whatever has arrived,
%% the exit status the runtime holds among it, and takes nothing: the
%% reads with time after each take what came. A regression test of the
%% rule of 2026-11-03, before which a read given no time answered what had
%% arrived; a piece kept for the next read while the program runs is not
%% covered apart, its read taking the same first clause
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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual([Timeout, {'Right', {'Stdout', <<"hi\n">>}}, {'Right', {'Exited', 0}}, Timeout,
                  Timeout, {'Right', {'Exited', 0}}],
                 wait(reads)).

%% Appendix E.23, E.0 shape rule 8: a write given no time, 0 or below, has
%% run out as it begins, answers `Left(Timeout)` and gives the program
%% nothing: `cat` writes back the one write that had time, and once it has
%% exited a write given no time answers `Left(Timeout)` still, where one
%% with time answers `Left(Closed)`. A regression test of the rule of
%% 2026-11-03, before which the bytes went to the program and the write
%% answered whichever came first, its time or the program's taking them
write_given_no_time_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Writes = [write(Cat, <<"x\n">>, 0), write(Cat, <<"y\n">>, -1),
                         write(Cat, <<"z\n">>, 5000)],
               Cat ! 'CloseInput',
               Ran = read_to_end(Cat, <<>>),
               Self ! {ran, {Writes, Ran, write(Cat, <<"w">>, 0), write(Cat, <<"w">>, 5000)}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout, {'Right', 'Unit'}], {<<"z\n">>, 0}, Timeout,
                  {'Left', 'Closed'}},
                 wait(ran)).

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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Left', 'Timeout'}, wait(written)).

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
               sleep(2 * Ms),
               ern_rt:kill(Program)
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({{'Right', 'Unit'}, {'Right', {'Stdout', <<"x">>}}}, wait(answers)),
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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(true, wait(alive)),
    ?assertEqual({ern, killed}, wait(ended)).

%% report Appendix E.23: a program under a terminal of the size given: what
%% is written to it is echoed, its size is the one given, a line feed it
%% writes arrives after a carriage return, and its exit status comes last.
%% `sh` reads its terminal as a shell does, its prompts among what it writes
terminal_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [], ?SIZE),
               {'Right', 'Unit'} = write(Sh, <<"stty size\n">>, 5000),
               Sized = read_until(Sh, <<"24 80\r\n">>, <<>>),
               {'Right', 'Unit'} = write(Sh, <<"exit 3\n">>, 5000),
               Self ! {ran, {Sized, read_to_end(Sh, <<>>)}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Sized, {Rest, Status}} = wait(ran),
    {Echoed, _} = binary:match(Sized, <<"stty size\r\n">>),
    {Answered, _} = binary:match(Sized, <<"24 80\r\n">>),
    ?assert(Echoed < Answered),
    ?assertMatch({_, _}, binary:match(Rest, <<"exit 3\r\n">>)),
    ?assertEqual(3, Status).

%% report Appendix E.23: a program's standard output and standard error
%% come merged through its terminal, each piece read as `Stdout`
terminal_merges_streams_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Sh} = start_terminal(<<"sh">>, [<<"-c">>, <<"echo out; echo err 1>&2">>],
                                              ?SIZE),
               Self ! {ran, read_to_end(Sh, <<>>)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({<<"out\r\nerr\r\n">>, 0}, wait(ran)).

%% report Appendix E.23: a resize sets the terminal's size and tells the
%% program's foreground, which reads the new size when told. The program
%% says it is ready once it listens, so that the resize comes after
resize_test() ->
    Self = self(),
    Told = <<"import fcntl, os, signal, struct, termios\n"
             "def told(number, frame):\n"
             "    size = fcntl.ioctl(1, termios.TIOCGWINSZ, bytes(8))\n"
             "    os.write(1, b'%d %d\\n' % struct.unpack('HHHH', size)[:2])\n"
             "signal.signal(signal.SIGWINCH, told)\n"
             "os.write(1, b'ready\\n')\n"
             "while True:\n"
             "    signal.pause()\n">>,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Python} = start_terminal(<<"python3">>, [<<"-c">>, Told], ?SIZE),
               _ = read_until(Python, <<"ready\r\n">>, <<>>),
               Resized = resize(Python, {'Size', 30, 100}),
               Self ! {resized, {Resized, read_until(Python, <<"30 100\r\n">>, <<>>)}},
               ern_rt:kill(Python)
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({{'Right', 'Unit'}, <<"30 100\r\n">>}, wait(resized)).

%% report Appendix E.23: a program `start` started has no terminal, and a
%% resize of it answers `Left(NotATerminal)`, whatever the size
resize_without_a_terminal_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Self ! {resized, [resize(Cat, ?SIZE), resize(Cat, {'Size', -1, 80})]},
               ern_rt:kill(Cat)
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual([{'Left', 'NotATerminal'}, {'Left', 'NotATerminal'}], wait(resized)).

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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Invalid = {'Left', 'Invalid'},
    ?assertEqual({[Invalid, Invalid], [Invalid, Invalid, {'Right', 'Unit'}]}, wait(answers)).

%% report Appendix E.23: a resize's answers in their order: a program
%% `start` started answers `Left(NotATerminal)` whatever the size and once
%% it has exited, then a size the host cannot take answers
%% `Left(Invalid)`, then a terminal hung up or a program exited answers
%% `Left(Closed)`, as a write does. The program hung up ignores the
%% hangup, which its `sleep` inherits, so that it runs on after it. A
%% regression test of the rule of 2026-11-03, before which a resize after
%% the hangup or the exit answered `Right(Unit)`; a resize once the helper
%% has failed is not covered
resize_answers_in_order_test() ->
    Self = self(),
    Wrong = {'Size', 65536, 80},
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               Cat ! 'CloseInput',
               {<<>>, 0} = read_to_end(Cat, <<>>),
               {'Right', Held} = start_terminal(<<"sh">>,
                                                [<<"-c">>, <<"trap '' HUP; echo ready;"
                                                             " exec sleep 1000">>], ?SIZE),
               _ = read_until(Held, <<"ready\r\n">>, <<>>),
               Held ! 'CloseInput',
               HungUp = [resize(Held, Wrong), resize(Held, ?SIZE)],
               ern_rt:kill(Held),
               {'Right', True} = start_terminal(<<"true">>, [], ?SIZE),
               {<<>>, 0} = read_to_end(True, <<>>),
               Self ! {answers, {[resize(Cat, Wrong), resize(Cat, ?SIZE)], HungUp,
                                 [resize(True, Wrong), resize(True, ?SIZE)]}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    NotATerminal = {'Left', 'NotATerminal'},
    Invalid = {'Left', 'Invalid'},
    Closed = {'Left', 'Closed'},
    ?assertEqual({[NotATerminal, NotATerminal], [Invalid, Closed], [Invalid, Closed]},
                 wait(answers)).

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
               Sleep ! 'CloseInput',
               Self ! {ended, read_to_end(Sleep, <<>>)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({<<>>, 129}, wait(ended)).

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
               Sh ! 'CloseInput',
               Self ! {ended, read_to_end(Sh, <<>>)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Output, Status} = wait(ended),
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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Sleep = wait(sleep),
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
%% terminal_kill_test's at a kill, and not covered at an exit. The run's
%% own limit stands past the wait's 5 seconds, which bound a failure, so
%% that a `sleep` left running is killed by its number
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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Sleep, 0} = wait(sleep),
    Ended = receive
                {Reader, {exit_status, ReaderStatus}} -> ReaderStatus
            after 5000 ->
                _ = os:cmd("kill -KILL " ++ integer_to_list(Sleep) ++ " "
                           ++ integer_to_list(ReaderNumber)),
                running
            end,
    ok = file:delete(Fifo),
    ?assertEqual(0, Ended).

%% report Appendix E.23, §6.6: a program's process lives on after the
%% program has exited: each read after the one that answered `Exited`
%% answers it again, a write `Left(Closed)`, a resize `Left(Closed)` too,
%% and `closeInput` does nothing; a monitor sees its end only at its kill,
%% after which a resize faults as `Address.callForever` does on an ended
%% process. A regression test of the rule of 2026-11-02, before which the
%% process ended once a read had answered `Exited`, and of 2026-11-03's,
%% before which the resize answered `Right(Unit)`; a give after the exit,
%% and the owner's death then, are not covered
exited_program_lives_on_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', True} = start_terminal(<<"true">>, [], ?SIZE),
               MonitorRef = erlang:monitor(process, ern_rt:process_of(True)),
               {<<>>, 0} = read_to_end(True, <<>>),
               Answers = [read(True, 5000), write(True, <<"x">>, 5000), resize(True, ?SIZE)],
               True ! 'CloseInput',
               Self ! {after_the_exit, {Answers, read(True, 5000)}},
               ern_rt:kill(True),
               receive {'DOWN', MonitorRef, process, _, ExitReason} -> Self ! {ended, ExitReason}
               end,
               _ = ern_rt:spawn_monitored(fun() -> resize(True, ?SIZE) end,
                                          fun(Down) -> {later, Down} end, <<"resizer">>),
               receive {later, Down} -> Self ! {later, Down} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({[{'Right', {'Exited', 0}}, {'Left', 'Closed'}, {'Left', 'Closed'}],
                  {'Right', {'Exited', 0}}},
                 wait(after_the_exit)),
    ?assertEqual({ern, killed}, wait(ended)),
    ?assertMatch({'Down', _, {'Fault', <<"callee had ended">>}, _}, wait(later)).

%% report Appendix E.23: a read whose caller has ended before it is
%% answered is dropped, and what it would have taken is the next read's:
%% the piece `cat` writes after a reader was killed in its read, and the
%% exit status after a second was. A regression test of the rule of
%% 2026-11-02, before which the read took the piece for its ended caller,
%% and an `Exited` so taken ended the process; a caller that ends while
%% the piece is on its way, before the process has its `DOWN`, is not
%% covered
read_of_an_ended_caller_dropped_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               killed_in_a_read(Cat),
               {'Right', 'Unit'} = write(Cat, <<"x\n">>, 5000),
               Piece = read(Cat, 5000),
               killed_in_a_read(Cat),
               Cat ! 'CloseInput',
               Self ! {reads, {Piece, read(Cat, 5000)}},
               ern_rt:kill(Cat)
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({{'Right', {'Stdout', <<"x\n">>}}, {'Right', {'Exited', 0}}}, wait(reads)).

%% report Appendix E.23: a piece that comes for a read whose caller has
%% ended, before the program's process has the caller's `DOWN`, is kept
%% for the next read, the host asked whether the caller lives before the
%% piece is answered. The window is made here: the program's process is
%% held still while the test gives it the frame the helper would send,
%% `o` and the bytes, and the reader is killed once the frame stands in
%% the process's mailbox, so that the `DOWN`, which the kill causes, comes
%% behind it whatever the senders. A regression test of the rule of
%% 2026-11-02, before which the piece went to the ended reader and the
%% next read timed out; a caller that ends with its answer in its mailbox
%% is every call's, and not covered
piece_ahead_of_the_down_kept_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Cat} = start(<<"cat">>, []),
               {links, Links} = process_info(Cat, links),
               [Helper] = [Link || Link <- Links, is_port(Link)],
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
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Right', {'Stdout', <<"x\n">>}}, wait(read)).

%% A reader of Program killed while its read waits, once the program's
%% process watches it, and returned from once that process no longer
%% does, so that its `DOWN` comes before what the caller sends after.
killed_in_a_read(Program) ->
    Reader = ern_rt:spawn_monitored(fun() -> read(Program, 60000) end,
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
    Self = self(),
    Command = {'Command', Program, Arguments, <<>>},
    ern_rt:call_forever(ern_rt:system_process(os), fun(Reply) ->
                                                       {'Start', Command, Self, Reply}
                                                   end).

%% Size is `Terminal.Size(rows, columns)`.
start_terminal(Program, Arguments, Size) ->
    Self = self(),
    Command = {'Command', Program, Arguments, <<>>},
    ern_rt:call_forever(ern_rt:system_process(os), fun(Reply) ->
                                                       {'StartTerminal', Command, Size, Self,
                                                        Reply}
                                                   end).

read(Program, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Read', Ms, Reply} end).

write(Program, Bytes, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Write', Bytes, Ms, Reply} end).

resize(Program, Size) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Resize', Size, Reply} end).

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

%% A wait the deadlock detector reads as timed, as the compiler's timed receive is,
%% for an absence, of a time derived from what it waits for.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

wait(Tag) ->
    receive {Tag, Value} -> Value after 5000 -> timeout end.

%% report §12.5: a node's ernest.pid is made writable by its owner alone,
%% whatever the mask, and never through a link; and a signal to the node
%% that holds it is refused, nothing sent, where others than its owner may
%% write the file, since another could then have written its number. The
%% number is this host's, which the signal 0 asks after. A regression
%% test, written after the code (S1, S3): the file was made 0666 under the
%% mask, group-writable under Ubuntu's 002, and a link was followed; a
%% file another user owns, which a test run as one user cannot make, is
%% not covered
node_file_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_os_node_" ++ os:getpid()),
    ok = filelib:ensure_path(Dir),
    PidFile = filename:join(Dir, "ernest.pid"),
    Number = list_to_integer(os:getpid()),
    Self = self(),
    Holder = spawn(fun() ->
                       Self ! {locked, ern_os:locked(PidFile, Number)},
                       receive stop -> ok end
                   end),
    ?assertEqual(locked, wait(locked)),
    {ok, #file_info{mode = Mode}} = file:read_file_info(PidFile),
    ?assertEqual(8#644 band bnot ern_os:umask(), Mode band 8#777),
    ?assertEqual(sent, ern_os:node_signaled(PidFile, 0, false)),
    ok = file:change_mode(PidFile, 8#664),
    ?assertEqual({failed, "may be written by others than its owner"},
                 ern_os:node_signaled(PidFile, 0, false)),
    MonitorRef = erlang:monitor(process, Holder),
    Holder ! stop,
    receive {'DOWN', MonitorRef, process, Holder, _} -> ok end,
    Link = filename:join(Dir, "linked.pid"),
    ok = file:make_symlink(PidFile, Link),
    Followed = {failed, "too many levels of symbolic links"},
    ?assertEqual({Followed, Followed},
                 {ern_os:locked(Link, Number), ern_os:node_signaled(Link, 0, false)}).

%% report §12.5: a node's ernest.pid that an earlier node left, which others
%% may write, as one made under the mask 002 before 0.9.0 is, is made its
%% owner's alone to write once the node holds its lock, its other bits as
%% they were, and is then signaled as the node's. A regression test of the
%% rule of 2026-11-03, before which the node took the file as it found it
%% and `ern stop` refused it
found_node_file_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_os_found_" ++ os:getpid()),
    ok = filelib:ensure_path(Dir),
    PidFile = filename:join(Dir, "ernest.pid"),
    ok = file:write_file(PidFile, <<"999999\n">>),
    ok = file:change_mode(PidFile, 8#664),
    Self = self(),
    Holder = spawn(fun() ->
                       Self ! {locked, ern_os:locked(PidFile, list_to_integer(os:getpid()))},
                       receive stop -> ok end
                   end),
    ?assertEqual(locked, wait(locked)),
    {ok, #file_info{mode = Mode}} = file:read_file_info(PidFile),
    Signaled = ern_os:node_signaled(PidFile, 0, false),
    MonitorRef = erlang:monitor(process, Holder),
    Holder ! stop,
    receive {'DOWN', MonitorRef, process, Holder, _} -> ok end,
    ?assertEqual({8#644, sent}, {Mode band 8#777, Signaled}).

%% report §12.5: the helper sends a process a signal and says how it went,
%% the signal 0 asking whether the process lives: this host's process
%% lives, a process number nothing holds names none, and the first process
%% lives and is the superuser's, which a test run as another user is not
%% allowed to signal
signal_test() ->
    ?assertEqual(sent, ern_os:signal(0, list_to_integer(os:getpid()))),
    Port = open_port({spawn_executable, os:find_executable("true")}, [exit_status]),
    {os_pid, Gone} = erlang:port_info(Port, os_pid),
    receive {Port, {exit_status, 0}} -> ok end,
    ?assertEqual(none, ern_os:signal(0, Gone)),
    case os:getenv("USER") of
        "root" -> ok;
        _ -> ?assertEqual(others, ern_os:signal(0, 1))
    end.

%% report §12.5: the user `ern` runs as, read alone, which a node's check of
%% its directory reads: the user host/0 reads, and the owner of a file this
%% host makes. A regression test: the node read the whole of what the host
%% says of a program, its environment among it, for the user alone
user_test() ->
    User = ern_os:user(),
    ?assertMatch({'Host', User, _}, ern_os:host()),
    File = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                         "ern_os_user_" ++ os:getpid()),
    ok = file:write_file(File, <<>>),
    {ok, #file_info{uid = Owner}} = file:read_file_info(File),
    ok = file:delete(File),
    ?assertEqual(User, Owner).
