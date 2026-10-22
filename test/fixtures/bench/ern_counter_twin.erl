%% The counter of test/fixtures/bench/counter.ern as Erlang writes it, for
%% `make bench` (test/ern_program_costs.erl): a counter process with a
%% receive loop, callers that each make their calls of it as gen:do_call/4
%% makes one, a monitor that is the reply's alias and a receive with an
%% `after`, and the total it came to once every caller has ended.
-module(ern_counter_twin).

-export([run/2]).

%% Callers processes, each making Calls calls of one counter, and the total
%% the counter came to.
-spec run(pos_integer(), non_neg_integer()) -> integer().
run(Callers, Calls) ->
    Counter = spawn(fun() -> count(0) end),
    [spawn_monitor(fun() -> call(Counter, Calls) end) || _ <- lists:seq(1, Callers)],
    await_callers(Callers),
    Total = added(Counter, 0, infinity),
    exit(Counter, kill),
    Total.

count(Total) ->
    receive
        {add, Amount, Reply} ->
            Reply ! {Reply, Total + Amount},
            count(Total + Amount)
    end.

call(_, 0) ->
    ok;
call(Counter, Calls) ->
    _ = added(Counter, 1, 1000),
    call(Counter, Calls - 1).

added(Counter, Amount, Timeout) ->
    MonitorRef = erlang:monitor(process, Counter, [{alias, demonitor}]),
    Counter ! {add, Amount, MonitorRef},
    receive
        {MonitorRef, Total} ->
            erlang:demonitor(MonitorRef, [flush]),
            Total;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            exit(ExitReason)
    after Timeout ->
        erlang:demonitor(MonitorRef, [flush]),
        exit(timeout)
    end.

await_callers(0) ->
    ok;
await_callers(Callers) ->
    receive
        {'DOWN', _, process, _, _} -> await_callers(Callers - 1)
    end.
