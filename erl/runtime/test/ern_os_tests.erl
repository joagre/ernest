%% Report Appendix E.23: the process behind a program Os.start starts.
-module(ern_os_tests).

-include_lib("eunit/include/eunit.hrl").

%% Appendix E.23: a write and a read that wait while the helper ends are
%% answered, the write as one after the program's end is and the read with
%% why. A regression test: the process gave them to the port the helper's
%% end had closed, and crashed with badarg (findings C9)
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
    ?assertEqual('Unit', wait(write)),
    ?assertMatch({'Left', {'Other', _}}, wait(read)).

start(Program, Arguments) ->
    Self = self(),
    Command = {'Command', Arguments, <<>>, Program},
    ern_rt:call_forever(ern_rt:sys(os), fun(R) -> {'Start', Command, 5000, Self, R} end).

%% The port closes once the host has seen the helper end.
closed(Port) ->
    case erlang:port_info(Port) of
        undefined -> ok;
        _ -> sleep(10), closed(Port)
    end.

answer(Reply) ->
    ern_rt:timed(),
    receive {Reply, V} -> ern_rt:untimed(), V after 5000 -> ern_rt:untimed(), timeout end.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

wait(Tag) ->
    receive {Tag, V} -> V after 5000 -> timeout end.
