%% Report Appendix E.23: the process behind a program Os.start starts.
-module(ern_os_tests).

-include_lib("eunit/include/eunit.hrl").

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
               Program ! {'Write', <<"x">>, 5000, WriteReply},
               ReadReply = alias(),
               Program ! {'Read', 5000, ReadReply},
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               closed(Helper),
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
    Helper = helper(["sleep", "2"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    %% more than a pipe holds, which `sleep` never reads
    true = port_command(Helper, <<"i", (binary:copy(<<"x">>, 200000))/binary>>),
    true = port_command(Helper, <<"e">>),
    true = port_command(Helper, <<"i", "y">>),
    ?assertEqual(none, receive
                           {Helper, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d -> answered
                       after 300 -> none
                       end),
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
%% program took. The program closes its input and is given time to, so
%% that the bytes do not reach the pipe before it is closed
helper_says_input_was_dropped_test() ->
    Helper = helper(["sh", "-c", "exec 0<&-; sleep 2"]),
    receive {Helper, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    receive after 300 -> ok end,
    true = port_command(Helper, <<"i", "x">>),
    ?assertEqual(<<"d">>, receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    port_close(Helper).

%% Appendix E.23: a program the host cannot start, here for want of a file
%% descriptor for its pipes, is answered with the host's reason. A
%% regression test: the helper ended without a word, and `start` answered
%% only that the helper failed. Under `make sanitize`
%% the leak checker, which needs descriptors of its own as the helper
%% ends, is off for this run alone; the release review found it starved,
%% and the helper hung as it failed
helper_gives_the_hosts_reason_test() ->
    Helper = open_port({spawn, "sh -c \"ulimit -n 7; ASAN_OPTIONS=$ASAN_OPTIONS:detect_leaks=0"
                        " exec " ++ helper_path() ++ " run\""},
                       [{packet, 4}, binary, exit_status]),
    true = port_command(Helper, command(["true"])),
    ?assertEqual(<<"femfile">>,
                 receive {Helper, {data, Frame}} -> Frame after 5000 -> none end),
    ?assertEqual(0, receive {Helper, {exit_status, Status}} -> Status after 5000 -> none end).

%% report §8.6, Appendix E.23: a program whose helper ended waits for a read
%% to fault, and holds nothing the check for a deadlock would read as work.
%% A regression test of the run's time limit the program once had, whose
%% message came later and stayed, so the process never read as waiting
lost_program_holds_no_timer_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>]),
               {links, Links} = process_info(Program, links),
               [Helper] = [Link || Link <- Links, is_port(Link)],
               {os_pid, OsPid} = erlang:port_info(Helper, os_pid),
               _ = os:cmd("kill -9 " ++ integer_to_list(OsPid)),
               closed(Helper),
               sleep(500),
               Self ! {queued, process_info(Program, message_queue_len)},
               ReadReply = alias(),
               Program ! {'Read', 5000, ReadReply},
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
               Self ! {answers, {write(Program, <<"x">>, 300), read(Program, 300)}},
               sleep(800),
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
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = self(),
               Keeper = erlang:spawn(fun() -> receive stop -> ok end end),
               _ = erlang:spawn(fun() ->
                                    {'Right', Started} = start(<<"sleep">>, [<<"5">>]),
                                    Started ! {'Give', Keeper},
                                    EntryProcess ! {program, Started}
                                end),
               Program = ern_rt:in_foreign(fun() -> receive {program, Started} -> Started end end),
               sleep(200),
               Self ! {alive, erlang:is_process_alive(Program)},
               MonitorRef = erlang:monitor(process, Program),
               Keeper ! stop,
               Ended = fun() ->
                           receive {'DOWN', MonitorRef, _, _, ExitReason} -> ExitReason
                           after 5000 -> alive
                           end
                       end,
               Self ! {ended, ern_rt:in_foreign(Ended)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(true, wait(alive)),
    ?assertEqual({ern, killed}, wait(ended)).

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
    receive {Helper, {exit_status, _}} -> ok after 5000 -> erlang:error(no_end) end,
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

read(Program, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Read', Ms, Reply} end).

write(Program, Bytes, Ms) ->
    ern_rt:call_forever(Program, fun(Reply) -> {'Write', Bytes, Ms, Reply} end).

%% The port closes once the host has seen the helper end.
closed(Helper) ->
    case erlang:port_info(Helper) of
        undefined -> ok;
        _ -> sleep(10), closed(Helper)
    end.

%% The answer the runtime's process gives, in Ernest's form (report §8.4).
answer(Reply) ->
    ern_rt:timed(),
    receive
        {Reply, answered, Value} -> ern_rt:untimed(), Value;
        {Reply, fault, Cause} -> ern_rt:untimed(), {fault, Cause}
    after 5000 -> ern_rt:untimed(), timeout
    end.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

wait(Tag) ->
    receive {Tag, Value} -> Value after 5000 -> timeout end.

%% report §8.7: the helper sends a process a signal and says how it went,
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
