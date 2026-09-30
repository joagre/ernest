%% Report Appendix E.23: the process behind a program Os.start starts.
-module(ern_os_tests).

-include_lib("eunit/include/eunit.hrl").

%% Appendix E.23: a write and a read that wait while the helper ends are
%% answered with why the runtime lost the program. A regression test: the
%% process gave them to the port the helper's end had closed, and crashed
%% with badarg (findings C9)
helper_ends_under_a_write_and_a_read_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>]),
               [Port] = [P || P <- element(2, process_info(Program, links)), is_port(P)],
               {os_pid, Helper} = erlang:port_info(Port, os_pid),
               erlang:suspend_process(Program),
               Written = alias(),
               Program ! {'Write', <<"x">>, Written},
               Read = alias(),
               Program ! {'Read', Read},
               _ = os:cmd("kill -9 " ++ integer_to_list(Helper)),
               closed(Port),
               erlang:resume_process(Program),
               Me ! {write, answer(Written)},
               Me ! {read, answer(Read)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertMatch({'Left', {'Other', _}}, wait(write)),
    ?assertMatch({'Left', {'Other', _}}, wait(read)).

%% Appendix E.23: the helper answers each 'i' in order, one taken after the
%% input's end among them, so that a write returns only once the program
%% has taken the bytes before it. A regression test: an 'i' after 'e' was
%% answered at once, ahead of one the program had not taken, which let its
%% writer go (findings.md's C8)
helper_answers_input_in_order_test() ->
    Port = helper(["sleep", "2"]),
    receive {Port, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    %% more than a pipe holds, which `sleep` never reads
    true = port_command(Port, <<"i", (binary:copy(<<"x">>, 200000))/binary>>),
    true = port_command(Port, <<"e">>),
    true = port_command(Port, <<"i", "y">>),
    ?assertEqual(none, receive
                           {Port, {data, <<T>>}} when T =:= $a; T =:= $d -> answered
                       after 300 -> none
                       end),
    port_close(Port).

%% Appendix E.23: an input larger than a pipe holds reaches the program
%% whole and in order, taken by the program a part at a time. A regression
%% test of the helper's buffer, which moved what was left to its front
%% after each part the program took, a cost that grew as the square of the
%% input: 128 MB took 16 s and takes 3 s now. It checks the bytes, not the
%% time, which the measure in the log's entry shows
helper_gives_a_large_input_whole_test() ->
    Port = helper(["cat"]),
    receive {Port, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    Input = << <<(N rem 251)>> || N <- lists:seq(1, 4000000) >>,
    true = port_command(Port, <<"i", Input/binary>>),
    true = port_command(Port, <<"i", "more">>),
    true = port_command(Port, <<"e">>),
    true = port_command(Port, <<"n">>),
    ?assert(<<Input/binary, "more">> =:= output(Port, <<>>)).

%% What the program wrote to its standard output, read a piece at a time,
%% until the helper's exit status.
output(Port, Read) ->
    receive
        {Port, {data, <<"o", Bytes/binary>>}} ->
            true = port_command(Port, <<"n">>),
            output(Port, <<Read/binary, Bytes/binary>>);
        {Port, {data, <<"x", _/binary>>}} -> Read;
        {Port, {data, _}} -> output(Port, Read)
    after 20000 -> timeout
    end.

%% Appendix E.23: bytes given once the program has closed its input are
%% dropped, and the helper says so with `d`, where it says `a` of bytes the
%% program took. The program closes its input and is given time to, so
%% that the bytes do not reach the pipe before it is closed
helper_says_input_was_dropped_test() ->
    Port = helper(["sh", "-c", "exec 0<&-; sleep 2"]),
    receive {Port, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    receive after 300 -> ok end,
    true = port_command(Port, <<"i", "x">>),
    ?assertEqual(<<"d">>, receive {Port, {data, D}} -> D after 5000 -> none end),
    port_close(Port).

%% Appendix E.23: a program the host cannot start, here for want of a file
%% descriptor for its pipes, is answered with the host's reason. A
%% regression test: the helper ended without a word, and `start` answered
%% only that the helper failed (findings.md's C19). Under `make sanitize`
%% the leak checker, which needs descriptors of its own as the helper
%% ends, is off for this run alone; the release review found it starved,
%% and the helper hung as it failed
helper_gives_the_hosts_reason_test() ->
    Port = open_port({spawn, "sh -c \"ulimit -n 7; ASAN_OPTIONS=$ASAN_OPTIONS:detect_leaks=0"
                      " exec " ++ helper_path() ++ " run\""},
                     [{packet, 4}, binary, exit_status]),
    true = port_command(Port, command(["true"])),
    ?assertEqual(<<"fToo many open files">>,
                 receive {Port, {data, D}} -> D after 5000 -> none end),
    ?assertEqual(0, receive {Port, {exit_status, S}} -> S after 5000 -> none end).

%% report §8.6, Appendix E.23: a program whose helper ended waits for a read
%% to answer why, and holds nothing the check for a deadlock would read as
%% work, its time limit gone with the helper. A regression test: the time
%% limit's message came later and stayed, so the process never read as
%% waiting
lost_program_holds_no_timer_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Program} = start(<<"sleep">>, [<<"3">>], 300),
               [Port] = [P || P <- element(2, process_info(Program, links)), is_port(P)],
               {os_pid, Helper} = erlang:port_info(Port, os_pid),
               _ = os:cmd("kill -9 " ++ integer_to_list(Helper)),
               closed(Port),
               sleep(500),
               Me ! {queued, process_info(Program, message_queue_len)},
               Read = alias(),
               Program ! {'Read', Read},
               Me ! {read, answer(Read)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({message_queue_len, 0}, wait(queued)),
    ?assertMatch({'Left', {'Other', _}}, wait(read)).

%% Appendix E.23: an argument longer than the host takes is the program's
%% failure to start, with the host's reason. A regression test: the
%% arguments were the helper's own, which the host would not start, and
%% `start` answered that the helper failed
argument_too_long_test() ->
    Me = self(),
    Long = binary:copy(<<"x">>, 200000),
    ok = ern_rt:run_main(fun() -> Me ! {started, start(<<"echo">>, [Long])} end,
                         <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Left', {'Other', <<"Argument list too long">>}}, wait(started)).

%% Appendix E.23: a time that passes before the program has started makes
%% `start` answer `Left(Timeout)`. A regression test, written as the report
%% came to say so (findings.md's C18)
start_timeout_test() ->
    Me = self(),
    ok = ern_rt:run_main(fun() -> Me ! {started, start(<<"sleep">>, [<<"1">>], 0)} end,
                         <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Left', 'Timeout'}, wait(started)).

%% The helper run on a command, as ern_os runs it: the command comes as the
%% first frame.
helper(Command) ->
    Port = open_port({spawn_executable, helper_path()},
                     [{args, ["run"]}, {packet, 4}, binary, exit_status]),
    true = port_command(Port, command(Command)),
    Port.

helper_path() ->
    filename:join([filename:dirname(code:which(ern_os)), "..", "priv", "ern_exec"]).

command(Parts) ->
    iolist_to_binary(["c" | [[Part, 0] || Part <- Parts]]).

start(Program, Arguments) ->
    start(Program, Arguments, 5000).

start(Program, Arguments, Ms) ->
    Self = self(),
    Command = {'Command', Arguments, <<>>, Program},
    ern_rt:call_forever(ern_rt:sys(os), fun(R) -> {'Start', Command, Ms, Self, R} end).

%% The port closes once the host has seen the helper end.
closed(Port) ->
    case erlang:port_info(Port) of
        undefined -> ok;
        _ -> sleep(10), closed(Port)
    end.

%% The answer the runtime's process gives, in Ernest's form (report §8.4).
answer(Alias) ->
    ern_rt:timed(),
    receive
        {Alias, answered, V} -> ern_rt:untimed(), V
    after 5000 -> ern_rt:untimed(), timeout
    end.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

wait(Tag) ->
    receive {Tag, V} -> V after 5000 -> timeout end.
