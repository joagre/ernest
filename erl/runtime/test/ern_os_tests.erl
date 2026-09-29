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
    Helper = filename:join([filename:dirname(code:which(ern_os)), "..", "priv", "ern_exec"]),
    Port = open_port({spawn_executable, Helper},
                     [{args, ["sleep", "2"]}, {packet, 4}, binary, exit_status]),
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

%% Appendix E.23: bytes given once the program has closed its input are
%% dropped, and the helper says so with `d`, where it says `a` of bytes the
%% program took. The program closes its input and is given time to, so
%% that the bytes do not reach the pipe before it is closed
helper_says_input_was_dropped_test() ->
    Helper = filename:join([filename:dirname(code:which(ern_os)), "..", "priv", "ern_exec"]),
    Port = open_port({spawn_executable, Helper},
                     [{args, ["sh", "-c", "exec 0<&-; sleep 2"]}, {packet, 4}, binary,
                      exit_status]),
    receive {Port, {data, <<"s">>}} -> ok after 5000 -> erlang:error(no_start) end,
    receive after 300 -> ok end,
    true = port_command(Port, <<"i", "x">>),
    ?assertEqual(<<"d">>, receive {Port, {data, D}} -> D after 5000 -> none end),
    port_close(Port).

%% Appendix E.23: a program the host cannot start, here for want of a file
%% descriptor for its pipes, is answered with the host's reason. A
%% regression test: the helper ended without a word, and `start` answered
%% only that the helper failed (findings.md's C19)
helper_gives_the_hosts_reason_test() ->
    Helper = filename:join([filename:dirname(code:which(ern_os)), "..", "priv", "ern_exec"]),
    Port = open_port({spawn, "sh -c \"ulimit -n 7; exec " ++ Helper ++ " true\""},
                     [{packet, 4}, binary, exit_status]),
    ?assertEqual(<<"fToo many open files">>,
                 receive {Port, {data, D}} -> D after 5000 -> none end),
    ?assertEqual(0, receive {Port, {exit_status, S}} -> S after 5000 -> none end).

%% Appendix E.23: a time that passes before the program has started makes
%% `start` answer `Left(Timeout)`. A regression test, written as the report
%% came to say so (findings.md's C18)
start_timeout_test() ->
    Me = self(),
    ok = ern_rt:run_main(fun() -> Me ! {started, start(<<"sleep">>, [<<"1">>], 0)} end,
                         <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Left', 'Timeout'}, wait(started)).

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
