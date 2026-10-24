%% `make bench`'s part `spawn` (docs/development.md): what Ernest's spawn,
%% spawnMonitored and monitor cost beside the host's (report §6.9, §10;
%% plan, MVP 3.27 items 2 and 3). A spawn asks the reaper, which starts the
%% process with a monitor of its own, writes its row and answers, and at
%% the process's end takes the host's `'DOWN'` and lets go of what the
%% process held. A monitor asks the reaper too. At the end of a process a
%% monitor stands of, a spawnMonitored's among them, the reaper delivers
%% each monitor's `wrap(Down)` through a process of its own, which acts
%% for its recipient.
%%
%% Measured, a file for each operation, spawn.txt, spawn_monitored.txt and
%% monitor.txt, each with two tables: the host's operation and Ernest's,
%% through the runtime in a launch, as the bench's row measures them, on
%% the host's schedulers and on one, where nothing waits for another
%% scheduler to wake. The spawn's table holds Ernest's spawn of a process
%% that waits too, so that no end comes between the spawns. Each row is the
%% median of seven runs, in nanoseconds an iteration, the loop's own cost
%% included, with their range (ern_costs). It measures and asserts nothing,
%% so it is not part of `make test-full`.
-module(ern_spawn_costs).

-export([main/1]).

%% Each loop's iterations, and the processes that wait at once for the
%% spawn alone.
-define(COUNT, 50000).
-define(BATCH, 10000).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Spawn.costs:1">>).

%% Prints the tables, writes each operation's to its file in Directory,
%% and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Schedulers = erlang:system_flag(schedulers_online, 1),
    Single = try
                 [{Operation, ern_costs:measured(Rows, ?COUNT)}
                  || {Operation, Rows} <- measures()]
             after
                 erlang:system_flag(schedulers_online, Schedulers)
             end,
    All = [{Operation, ern_costs:measured(Rows, ?COUNT)} || {Operation, Rows} <- measures()],
    lists:foreach(fun({Operation, _}) ->
                      {_, Measured} = lists:keyfind(Operation, 1, All),
                      {_, One} = lists:keyfind(Operation, 1, Single),
                      Text = unicode:characters_to_binary(
                               [ern_costs:table(io_lib:format("~s, on the host's ~B schedulers, "
                                                              "ns an iteration",
                                                              [title(Operation), Schedulers]),
                                                Measured, ratio),
                                ern_costs:table("on one scheduler, ns an iteration", One,
                                                ratio)]),
                      io:format("~ts", [Text]),
                      ok = file:write_file(filename:join(Directory, file(Operation)), Text)
                  end, measures()),
    halt(0).

title(spawn) -> "the spawn";
title(spawn_monitored) -> "spawnMonitored";
title(monitor) -> "a monitor of an ended process".

file(Operation) -> atom_to_list(Operation) ++ ".txt".

%% Each operation's rows: the host's, then Ernest's through the runtime.
measures() ->
    [{spawn, [{"the host's spawn of a process that returns", fun host_spawns/1},
              {"Ernest's spawn of a process that returns, through the reaper",
               ern_costs:launched(fun ernest_spawns/1)},
              {"  the same of a process that waits, no end between",
               ern_costs:launched(fun spawns_alone/1)}]},
     {spawn_monitored, [{"the host's spawn_monitor, its 'DOWN' received",
                         fun host_spawns_monitored/1},
                        {"Ernest's spawnMonitored, its Down received",
                         ern_costs:launched(fun ernest_spawns_monitored/1)},
                        {"  Ernest's spawn of a process that returns",
                         ern_costs:launched(fun ernest_spawns/1)}]},
     {monitor, [{"the host's monitor of an ended process, its 'DOWN' received",
                 fun host_monitors/1},
                {"Ernest's monitor of an ended process, its Down received",
                 ern_costs:launched(fun ernest_monitors/1)}]}].

%%
%% The host's, and the runtime's in a launch
%%

%% The host's spawn of a process that returns, as the bench's Erlang row.
host_spawns(Count) ->
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) -> _ = spawn(fun() -> ok end), Loop(Left - 1)
                           end).

%% The host's spawn_monitor and its 'DOWN', as the bench's Erlang row.
host_spawns_monitored(Count) ->
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) ->
                                   {_, MonitorRef} = spawn_monitor(fun() -> ok end),
                                   receive {'DOWN', MonitorRef, _, _, _} -> Loop(Left - 1) end
                           end).

%% The host's monitor of a process that has ended and its 'DOWN', as the
%% bench's Erlang row.
host_monitors(Count) ->
    {Ended, EndedRef} = spawn_monitor(fun() -> ok end),
    receive {'DOWN', EndedRef, _, _, _} -> ok end,
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) ->
                                   MonitorRef = erlang:monitor(process, Ended),
                                   receive {'DOWN', MonitorRef, _, _, _} -> Loop(Left - 1) end
                           end).

%% Report §6.9: Ernest's spawn of a process that returns, the code the
%% compiler writes for `spawn(fn() = Unit)`.
ernest_spawns(Count) ->
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) ->
                                   _ = ern_rt:spawn(fun() -> 'Unit' end, ?SITE),
                                   Loop(Left - 1)
                           end).

%% Report §6.2, §6.9: Ernest's spawnMonitored of a process that returns
%% and its Down received, as the bench's row writes them.
ernest_spawns_monitored(Count) ->
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) ->
                                   _ = ern_rt:spawn_monitored(fun() -> 'Unit' end,
                                                              fun(_) -> {'Ping', Left} end, ?SITE),
                                   receive {'Ping', Left} -> Loop(Left - 1) end
                           end).

%% Report §6.9: Ernest's monitor of a process that has ended and its Down
%% received, as the bench's row writes them, the process ended first as
%% the bench's endedProcess/0 ends it.
ernest_monitors(Count) ->
    Ended = ern_rt:spawn_monitored(fun() -> 'Unit' end, fun(_) -> ended end, ?SITE),
    receive ended -> ok end,
    ern_costs:timed(Count, fun Loop(0) -> ok;
                               Loop(Left) ->
                                   ern_rt:monitor(Ended, fun(_) -> {'Ping', Left} end),
                                   receive {'Ping', Left} -> Loop(Left - 1) end
                           end).

%% The same spawn of a process that waits for a word to return, so that
%% no end comes between the spawns, in batches; the processes of each
%% batch told to return after it, and their ends waited for, outside the
%% time.
spawns_alone(Count) ->
    Batches = Count div ?BATCH,
    Times = [begin
                 Started = erlang:monotonic_time(nanosecond),
                 Pids = [ern_rt:spawn(fun() -> receive return -> 'Unit' end end, ?SITE)
                         || _ <- lists:seq(1, ?BATCH)],
                 Nanoseconds = erlang:monotonic_time(nanosecond) - Started,
                 ended(Pids),
                 Nanoseconds
             end || _ <- lists:seq(1, Batches)],
    {lists:sum(Times), Batches * ?BATCH}.

%% Each process told to return, seen to end, and the reaper's answer to a
%% spawn asked after: it takes its messages in the order they came, so it
%% answers once it has handled every end before it.
ended(Pids) ->
    [erlang:monitor(process, Pid) || Pid <- Pids],
    [Pid ! return || Pid <- Pids],
    ern_costs:downs(length(Pids)),
    _ = ern_rt:spawn(fun() -> 'Unit' end, ?SITE),
    ok.
