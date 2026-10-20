%% `make bench`'s fifth part (docs/development.md): what each piece of
%% Ernest's spawn, spawnMonitored and monitor adds to the host's (report
%% §6.9, §10; plan, MVP 3.27 items 2 and 3). A spawn asks the reaper, which
%% starts the process with a monitor of its own, writes its row and
%% answers, and at the process's end takes the host's `'DOWN'` and lets go
%% of what the process held (ern_rt's spawn_with_monitors/4, spawned/7 and
%% down/3). A monitor asks the reaper too, which monitors the process with
%% the host's monitor and answers (monitored/5). At the end of a process a
%% monitor stands of, a spawnMonitored's among them, the reaper delivers
%% each monitor's `wrap(Down)` through a process of its own, linked to it,
%% which applies the wrap as an adapted address's function is applied and
%% acts for its recipient, and takes that process's end in turn
%% (wrapped/3, counted_link/2, held_ended/3).
%%
%% Measured, a file for each operation, spawn.txt, spawn_monitored.txt and
%% monitor.txt, each with its tables: the host's operation and Ernest's,
%% through the runtime in a launch, as the bench's row measures them; the
%% same on one scheduler, where nothing waits for another scheduler to
%% wake; there, a model of the reaper, a process that does what the
%% reaper does a piece at a time, each row adding one piece to the row
%% before, so that the runtime's multiple of the host's operation is
%% accounted for piece by piece; and, for the spawn and the monitor, each
%% operation of the reaper's and of the delivery's on their tables, alone
%% in a loop of its own, on tables of the runtime's kinds as empty as the
%% bench leaves them, spawnMonitored's being the spawn's and the
%% delivery's. The spawn's table holds Ernest's spawn of a process
%% that waits too, so that no end comes between the spawns. Each row is
%% the median of seven runs, in nanoseconds an iteration, the loop's own
%% cost included, with their range; each run measures every row of its
%% table once, in turn, so that what drifts over the runs falls on all. It
%% measures and asserts nothing, so it is not part of `make test-full`.
-module(ern_spawn_costs).

-export([main/1, measured/2, timed/2, launched/1, table/3]).

%% Each spawn and monitor loop's iterations, an operation loop's, the runs
%% of each row, and the processes that wait at once for the spawn alone.
-define(COUNT, 50000).
-define(OPERATIONS, 1000000).
-define(RUNS, 7).
-define(BATCH, 10000).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Spawn.costs:1">>).
%% The process dictionary's key of a process that acts for another, which
%% the spawner reads for the root its process takes (ern_rt's parent/0).
-define(ACTING, '$ern_acting').
%% How long the reaper waits without a message before it looks for a
%% deadlock, in milliseconds (ern_rt's LOOK_SOON).
-define(LOOK, 100).

%% The pieces of the spawn's model, in the order they are added: the
%% monitor and the 'DOWN' taken at the end; the start, the process waiting
%% for the reaper's word; run/1, the error handler and the try; the row at
%% the spawn as MVP 3.1 wrote it, and its root read, which came after; the
%% end's handling as MVP 3.1 made it, and the deliveries let go, which came
%% after; and the reaper's wait with a time, for its look.
-define(SPAWN, [monitor, start, run, row, root, ending, deliveries, look]).
%% The pieces of a Down's delivery, added to the spawn's model whole for
%% spawnMonitored and to a round trip and the host's monitor for monitor:
%% the wrap applied in a process of its own, as §10 states; that process
%% linked to the reaper, as MVP 3.1 had it, and the reaper trapping its
%% exit and taking its 'EXIT', which came after; its start on the reaper's
%% word; its row and its source; the wrap applied through an adapted
%% address; and, which came after, the delivery acting for its recipient,
%% and its end held, the deliveries to it read, its call taken and its
%% monitors canceled.
-define(DELIVERY, [delivery, linked, trapped, go, delivery_rows, adapted, acting, held]).
%% spawnMonitored's: the spawn's whole but its look, then the delivery's,
%% then the look.
-define(SPAWN_MONITORED, lists:droplast(?SPAWN) ++ ?DELIVERY ++ [look]).
%% A monitor's: the first four of the delivery's; the reaper's rows at the
%% monitor and the end's handling, as MVP 3.1 had them; the rest of the
%% delivery's, the deliveries to the ended process let go among them,
%% which came after; and the look.
-define(MONITOR, [delivery, linked, trapped, go, rows, ending, delivery_rows, adapted, acting,
                  deliveries, held, look]).

%% The reaper's state in the model: which pieces are on, the tables, and
%% the monitors, as ern_rt's #reaper{} holds them.
-record(model, {on, tables, monitors = #{}, monitoring = #{}, monitor_refs = #{}}).

%% Prints the tables, writes each operation's to its file in Directory,
%% and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Schedulers = erlang:system_flag(schedulers_online, 1),
    Single = try
                 [{Operation, measured(Rows ++ models(Operation), ?COUNT)}
                  || {Operation, Rows} <- measures()]
             after
                 erlang:system_flag(schedulers_online, Schedulers)
             end,
    All = [{Operation, measured(Rows, ?COUNT)} || {Operation, Rows} <- measures()],
    Operations = [{spawn, measured(operations(), ?OPERATIONS)},
                  {monitor, measured(monitor_operations(), ?OPERATIONS)}],
    lists:foreach(fun({Operation, Rows}) ->
                      {_, Measured} = lists:keyfind(Operation, 1, All),
                      {_, One} = lists:keyfind(Operation, 1, Single),
                      Text = unicode:characters_to_binary(
                               [table(io_lib:format("~s, on the host's ~B schedulers, "
                                                    "ns an iteration",
                                                    [title(Operation), Schedulers]),
                                      Measured, ratio),
                                table("on one scheduler, ns an iteration",
                                      lists:sublist(One, length(Rows)), ratio),
                                table("a model of the reaper on one scheduler, "
                                      "a piece added on each row",
                                      lists:nthtail(length(Rows), One), added),
                                case lists:keyfind(Operation, 1, Operations) of
                                    {_, Alone} -> table(alone(Operation), Alone, none);
                                    false -> []
                                end]),
                      io:format("~ts", [Text]),
                      ok = file:write_file(filename:join(Directory, file(Operation)), Text)
                  end, measures()),
    halt(0).

title(spawn) -> "the spawn";
title(spawn_monitored) -> "spawnMonitored";
title(monitor) -> "a monitor of an ended process".

alone(spawn) -> "the reaper's operations, each alone, ns an operation";
alone(monitor) -> "the reaper's and the delivery's operations, each alone, ns an operation".

file(Operation) -> atom_to_list(Operation) ++ ".txt".

%% Each operation's rows: the host's, then Ernest's through the runtime.
measures() ->
    [{spawn, [{"the host's spawn of a process that returns", fun host_spawns/1},
              {"Ernest's spawn of a process that returns, through the reaper",
               launched(fun ernest_spawns/1)},
              {"  the same of a process that waits, no end between",
               launched(fun spawns_alone/1)}]},
     {spawn_monitored, [{"the host's spawn_monitor, its 'DOWN' received",
                         fun host_spawns_monitored/1},
                        {"Ernest's spawnMonitored, its Down received",
                         launched(fun ernest_spawns_monitored/1)},
                        {"  Ernest's spawn of a process that returns",
                         launched(fun ernest_spawns/1)}]},
     {monitor, [{"the host's monitor of an ended process, its 'DOWN' received",
                 fun host_monitors/1},
                {"Ernest's monitor of an ended process, its Down received",
                 launched(fun ernest_monitors/1)}]}].

%% The model's rows of an operation: none of its pieces, or for
%% spawnMonitored the spawn's whole, then each added in turn.
models(Operation) ->
    {Base, Pieces} = case Operation of
                         spawn -> {0, ?SPAWN};
                         spawn_monitored -> {length(?SPAWN) - 1, ?SPAWN_MONITORED};
                         monitor -> {0, ?MONITOR}
                     end,
    [{named(Operation, lists:sublist(Pieces, Count)),
      fun(Iterations) -> modeled(Operation, lists:sublist(Pieces, Count), Iterations) end}
     || Count <- lists:seq(Base, length(Pieces))].

%% Each row's runs, the rows taking turns within a run: its name and the
%% nanoseconds an iteration of each run.
-spec measured([{string(), fun((pos_integer()) -> {integer(), pos_integer()})}],
               pos_integer()) -> [{string(), [float()]}].
measured(Rows, Count) ->
    Runs = [[{Name, per_iteration(Measure(Count))} || {Name, Measure} <- Rows]
            || _ <- lists:seq(1, ?RUNS)],
    [{Name, [Value || Run <- Runs, {Named, Value} <- Run, Named =:= Name]}
     || {Name, _} <- Rows].

per_iteration({Nanoseconds, Count}) ->
    Nanoseconds / Count.

%% The nanoseconds Count iterations of Loop take, and Count.
-spec timed(pos_integer(), fun((pos_integer()) -> ok)) -> {integer(), pos_integer()}.
timed(Count, Loop) ->
    Started = erlang:monotonic_time(nanosecond),
    ok = Loop(Count),
    {erlang:monotonic_time(nanosecond) - Started, Count}.

%%
%% The host's, and the runtime's in a launch
%%

%% The host's spawn of a process that returns, as the bench's Erlang row.
host_spawns(Count) ->
    timed(Count, fun Loop(0) -> ok;
                     Loop(Left) -> _ = spawn(fun() -> ok end), Loop(Left - 1)
                 end).

%% The host's spawn_monitor and its 'DOWN', as the bench's Erlang row.
host_spawns_monitored(Count) ->
    timed(Count, fun Loop(0) -> ok;
                     Loop(Left) ->
                         {_, MonitorRef} = spawn_monitor(fun() -> ok end),
                         receive {'DOWN', MonitorRef, _, _, _} -> Loop(Left - 1) end
                 end).

%% The host's monitor of a process that has ended and its 'DOWN', as the
%% bench's Erlang row.
host_monitors(Count) ->
    {Ended, EndedRef} = spawn_monitor(fun() -> ok end),
    receive {'DOWN', EndedRef, _, _, _} -> ok end,
    timed(Count, fun Loop(0) -> ok;
                     Loop(Left) ->
                         MonitorRef = erlang:monitor(process, Ended),
                         receive {'DOWN', MonitorRef, _, _, _} -> Loop(Left - 1) end
                 end).

%% A run of Measure in the entry process of a launch of the runtime, as `ern
%% run` starts one (report §11.2), its output dropped. The host's rows are
%% measured outside a launch: a wait for a host's 'DOWN' in one would be a
%% deadlock to the runtime, which counts no host monitor as a source.
-spec launched(fun((pos_integer()) -> {integer(), pos_integer()})) ->
          fun((pos_integer()) -> {integer(), pos_integer()}).
launched(Measure) ->
    fun(Count) ->
        Self = self(),
        ok = ern_rt:run_main(fun() -> Self ! {measured, Measure(Count)}, 'Unit' end,
                             <<"Spawn.main">>, #{stdout => fun(_) -> ok end}),
        receive {measured, Measured} -> Measured end
    end.

%% Report §6.9: Ernest's spawn of a process that returns, the code the
%% compiler writes for `spawn(fn() = Unit)`.
ernest_spawns(Count) ->
    timed(Count, fun Loop(0) -> ok;
                     Loop(Left) -> _ = ern_rt:spawn(fun() -> 'Unit' end, ?SITE), Loop(Left - 1)
                 end).

%% Report §6.2, §6.9: Ernest's spawnMonitored of a process that returns
%% and its Down received, as the bench's row writes them.
ernest_spawns_monitored(Count) ->
    timed(Count, fun Loop(0) -> ok;
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
    timed(Count, fun Loop(0) -> ok;
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
    downs(length(Pids)),
    _ = ern_rt:spawn(fun() -> 'Unit' end, ?SITE),
    ok.

downs(0) -> ok;
downs(Left) -> receive {'DOWN', _, process, _, _} -> downs(Left - 1) end.

%%
%% The model
%%

%% A run of the model of Operation with Pieces on: a process standing for
%% the reaper, asked as the runtime asks the reaper, its tables made for
%% the run, the spawner's row among them, as the entry process has one,
%% and for a monitor a process that has ended.
modeled(Operation, Pieces, Count) ->
    Tables = tables(),
    #{processes := Processes} = Tables,
    ets:insert(Processes, row(self())),
    Model = spawn(fun() -> model(Pieces, Tables) end),
    persistent_term:put({?MODULE, model}, Model),
    Measured = case Operation of
                   spawn -> timed(Count, fun(Left) -> asking(Left, Pieces, false) end);
                   spawn_monitored -> timed(Count, fun(Left) -> asking(Left, Pieces, true) end);
                   monitor -> timed(Count, fun(Left) -> watching(Left, Pieces, ended()) end)
               end,
    MonitorRef = erlang:monitor(process, Model),
    exit(Model, kill),
    receive {'DOWN', MonitorRef, process, Model, _} -> ok end,
    deleted(Tables),
    Measured.

%% A process that has ended.
ended() ->
    {Pid, MonitorRef} = spawn_monitor(fun() -> ok end),
    receive {'DOWN', MonitorRef, _, _, _} -> Pid end.

%% The spawner's side, as ern_rt's spawn_with_monitors/4 asks: the root
%% read from the spawner where the row's root is on, the reaper found, the
%% request sent, the answer waited for; and for spawnMonitored the
%% monitor's Down received.
asking(0, _, _) ->
    ok;
asking(Left, Pieces, IsMonitored) ->
    Chain = case lists:member(root, Pieces) of
                true -> {chained, parent()};
                false -> chained
            end,
    Ref = make_ref(),
    Monitors = [{self(), fun(_) -> {'Ping', Left} end} || IsMonitored],
    persistent_term:get({?MODULE, model})
        ! {spawn, self(), Ref, fun() -> 'Unit' end, ?SITE, Monitors, Chain},
    receive {Ref, _Pid} -> ok end,
    [receive {'Ping', Left} -> ok end || IsMonitored],
    asking(Left - 1, Pieces, IsMonitored).

%% The caller's side of a monitor, as ern_rt's monitor/2 asks: the
%% checker in front of the process read where the reaper's rows are on,
%% the reaper found, the request sent, the answer waited for, and the Down
%% received.
watching(0, _, _) ->
    ok;
watching(Left, Pieces, Ended) ->
    Ref = make_ref(),
    Process = case lists:member(rows, Pieces) of
                  true -> behind(ern_spawn_costs_checkers, Ended);
                  false -> Ended
              end,
    persistent_term:get({?MODULE, model})
        ! {monitor, Process, self(), fun(_) -> {'Ping', Left} end, Ref},
    receive {Ref, monitored} -> ok end,
    receive {'Ping', Left} -> ok end,
    watching(Left - 1, Pieces, Ended).

parent() ->
    case erlang:get(?ACTING) of
        undefined -> self();
        Acting -> Acting
    end.

%% ern_rt's behind/1, the process behind the checker in front of it.
behind(Checkers, Pid) ->
    case ets:lookup(Checkers, {behind, Pid}) of
        [{_, Real, _, _}] -> Real;
        _ -> Pid
    end.

%% The runtime's tables a spawn, a monitor and an end read, named and of
%% the runtime's kinds (ern_rt's table_kind/1).
tables() ->
    maps:from_list([{Name, ets:new(list_to_atom("ern_spawn_costs_" ++ atom_to_list(Name)),
                                   [named_table, public, Kind])}
                    || {Name, Kind} <- [{processes, set}, {calls, set}, {callees, ordered_set},
                                        {faults, set}, {terminating, set}, {restarts, set},
                                        {held, set}, {deliveries, ordered_set},
                                        {checkers, set}, {offered, bag}]]).

deleted(Tables) ->
    [ets:delete(Table) || Table <- maps:values(Tables)],
    ok.

model(Pieces, Tables) ->
    On = maps:from_list([{Piece, true} || Piece <- Pieces]),
    erlang:process_flag(trap_exit, is_map_key(trapped, On)),
    serving(#model{on = On, tables = Tables}).

%% The reaper's receive, without a time and with it.
serving(#model{on = #{look := true}} = Model) ->
    receive
        Message -> serving(served(Message, Model))
    after ?LOOK ->
        serving(Model)
    end;
serving(Model) ->
    receive
        Message -> serving(served(Message, Model))
    end.

served({spawn, From, Ref, Function, Site, Monitors, Chain}, Model) ->
    started(Model, From, Ref, Function, Site, Monitors, Chain);
served({monitor, Pid, Caller, Wrap, Ref}, Model) ->
    monitored(Model, Pid, Caller, Wrap, Ref);
served({'DOWN', _MonitorRef, process, Pid, ExitReason}, Model) ->
    down(Model, Pid, ExitReason);
served({'EXIT', Pid, ExitReason}, Model) ->
    held_ended(Model, Pid, ExitReason).

%% ern_rt's spawned/7, piece by piece, the monitors made with the spawn
%% kept as the reaper keeps them.
started(#model{on = On, tables = Tables} = Model, From, Ref, Function, Site, Monitors,
        Chain) ->
    Body = case On of
               #{run := true} -> fun() -> run(Function) end;
               _ -> Function
           end,
    Started = case On of
                  #{start := true} -> fun() -> receive Ref -> Body() end end;
                  _ -> Body
              end,
    Pid = case On of
              #{monitor := true} -> element(1, erlang:spawn_monitor(Started));
              _ -> erlang:spawn(Started)
          end,
    case On of
        #{row := true} -> rowed(On, Tables, Pid, Site, Chain);
        _ -> ok
    end,
    case On of
        #{start := true} -> Pid ! Ref;
        _ -> ok
    end,
    From ! {Ref, Pid},
    case Monitors of
        [] -> Model;
        _ -> kept(Model, Pid, Monitors)
    end.

%% The row: MVP 3.1's {Pid, Site, Timers, Foreign, SpawnOrder}, and since,
%% the root read from the spawner's row and the peer beside it.
rowed(#{root := true}, #{processes := Processes}, Pid, Site, {chained, Parent}) ->
    ets:insert(Processes, {Pid, Site, 0, 0, erlang:unique_integer([monotonic, positive]),
                           root(Processes, Parent, Pid), none});
rowed(_, #{processes := Processes}, Pid, Site, _) ->
    ets:insert(Processes, {Pid, Site, 0, 0, erlang:unique_integer([monotonic, positive])}).

root(Processes, Parent, Pid) ->
    case ets:lookup(Processes, Parent) of
        [{_, _, _, _, _, Root, _}] -> Root;
        [] -> Pid
    end.

%% The monitors of Pid kept by their callers, and each caller's
%% monitoring of it, as ern_rt's monitor_kept/4 and added/3 keep them.
kept(#model{monitors = Monitors, monitoring = Monitoring} = Model, Pid, Kept) ->
    Model#model{monitors = lists:foldl(fun({Caller, Wrap}, Acc) ->
                                           monitor_kept(Pid, Caller, Wrap, Acc)
                                       end, Monitors, Kept),
                monitoring = lists:foldl(fun({Caller, _}, Acc) -> added(Caller, Pid, Acc) end,
                                         Monitoring, Kept)}.

%% ern_rt's added/3: Value put in Key's set.
added(Key, Value, Sets) ->
    case Sets of
        #{Key := Set} -> Sets#{Key := Set#{Value => true}};
        #{} -> Sets#{Key => #{Value => true}}
    end.

%% ern_rt's monitor_kept/4.
monitor_kept(Pid, Caller, Wrap, Monitors) ->
    case Monitors of
        #{Pid := #{Caller := Wraps} = ByCaller} ->
            Monitors#{Pid := ByCaller#{Caller := [Wrap | Wraps]}};
        #{Pid := ByCaller} ->
            Monitors#{Pid := ByCaller#{Caller => [Wrap]}};
        #{} ->
            Monitors#{Pid => #{Caller => [Wrap]}}
    end.

%% ern_rt's run/1.
run(Function) ->
    erlang:process_flag(error_handler, ern_rt),
    try
        Function()
    catch
        Class:Error:Stack -> exit(ern_rt:fault_exit_reason(Class, Error, Stack))
    end.

%% ern_rt's monitored/5, piece by piece: the host's monitor, the monitor
%% kept and the caller's answer; with the reaper's rows, as MVP 3.1 had
%% them, the process's row looked for first, and a monitor of a process
%% the runtime did not start counted as a source and kept by its
%% reference, the host's monitor made once for it.
monitored(#model{on = #{rows := true}, tables = Tables, monitor_refs = MonitorRefs} = Model,
          Pid, Caller, Wrap, Ref) ->
    #{processes := Processes, held := Held} = Tables,
    MonitorRefs1 = case ets:lookup(Processes, Pid) of
                       [] when not is_map_key(Pid, MonitorRefs) ->
                           counted(Held, self(), 1),
                           MonitorRefs#{Pid => erlang:monitor(process, Pid)};
                       _ ->
                           MonitorRefs
                   end,
    Caller ! {Ref, monitored},
    kept(Model#model{monitor_refs = MonitorRefs1}, Pid, [{Caller, Wrap}]);
monitored(Model, Pid, Caller, Wrap, Ref) ->
    _ = erlang:monitor(process, Pid),
    Caller ! {Ref, monitored},
    kept(Model, Pid, [{Caller, Wrap}]).

%% ern_rt's source_begin/1 and source_end/0 on the model's table.
counted(Held, Holder, 1) ->
    ets:update_counter(Held, {source, Holder}, {2, 1}, {{source, Holder}, 0});
counted(Held, Holder, -1) ->
    case ets:update_counter(Held, {source, Holder}, {2, -1}) of
        0 -> ets:delete_object(Held, {{source, Holder}, 0});
        _ -> true
    end.

%% ern_rt's down/3, piece by piece: each monitor of the process told, and
%% the monitors of it, and its own, forgotten; with the end's handling as
%% MVP 3.1 made it, its offers taken, the notes of its callers read, its
%% row taken, and with a row its call and its subscriptions, its site in
%% the Down; with the reaper's rows, the source of a monitor of a process
%% the runtime did not start let go; and since, the deliveries to it let
%% go.
down(#model{on = On, tables = Tables, monitors = Monitors, monitor_refs = MonitorRefs} = Model,
     Pid, ExitReason) ->
    Site = case On of
               #{ending := true} -> ending(Tables, Pid);
               _ -> <<>>
           end,
    told(Model, [{Caller, Wrap} || Caller := Wraps <- maps:get(Pid, Monitors, #{}), Wrap <- Wraps],
         {'Down', Pid, ern_rt:reason(ExitReason), Site}),
    case On of
        #{rows := true} when is_map_key(Pid, MonitorRefs) ->
            #{held := Held} = Tables,
            counted(Held, self(), -1);
        _ ->
            ok
    end,
    case On of
        #{deliveries := true} ->
            #{deliveries := Deliveries} = Tables,
            lists:foreach(fun(_) -> ok end, abandoned(Deliveries, Pid));
        _ ->
            ok
    end,
    forgotten(Model, Pid).

%% ern_rt's down/3's handling of a process's end as MVP 3.1 made it, and
%% the site its row held, or none.
ending(Tables, Pid) ->
    #{processes := Processes, calls := Calls, callees := Callees, faults := Faults,
      terminating := Terminating, restarts := Restarts, offered := Offered} = Tables,
    lists:foreach(fun(_) -> ok end, ets:take(Offered, Pid)),
    lists:foreach(fun(_) -> ok end, ets:select(Callees, notes(Pid))),
    case ets:take(Processes, Pid) of
        [Row] ->
            _ = ets:take(Calls, Pid),
            ets:delete(Faults, Pid),
            ets:delete(Terminating, Pid),
            ets:delete(Restarts, Pid),
            element(2, Row);
        [] ->
            <<>>
    end.

%% The monitors of Pid, and its own, gone, as ern_rt's down/3 forgets them.
forgotten(#model{monitors = Monitors, monitoring = Monitoring,
                 monitor_refs = MonitorRefs} = Model, Pid) ->
    Monitoring1 = lists:foldl(fun(Caller, Acc) -> without(Caller, Pid, Acc) end,
                              maps:remove(Pid, Monitoring),
                              maps:keys(maps:get(Pid, Monitors, #{}))),
    Model#model{monitors = maps:remove(Pid, Monitors), monitoring = Monitoring1,
                monitor_refs = maps:remove(Pid, MonitorRefs)}.

%% ern_rt's forgotten/3: Gone taken from Key's set.
without(Key, Gone, Sets) ->
    case Sets of
        #{Key := #{Gone := _} = Set} when map_size(Set) =:= 1 -> maps:remove(Key, Sets);
        #{Key := Set} -> Sets#{Key := maps:remove(Gone, Set)};
        #{} -> Sets
    end.

%% ern_rt's drop_callee_notes/2's read of the rows of a process's callers.
notes(Pid) ->
    [{{{Pid, '$1'}, '$2'}, [], [{{'$1', '$2'}}]}].

%% ern_rt's abandoned/1's read: the deliveries in flight to a process, by
%% their key's prefix.
abandoned(Deliveries, Pid) ->
    try ets:select(Deliveries, [{{{Pid, '_', '_'}}, [], [{element, 1, '$_'}]}])
    catch _:_ -> []
    end.

%% Each monitor's wrap(Down) delivered: by the reaper itself, or by a
%% process of its own where the delivery is on (wrapped/4).
told(#model{on = #{delivery := true}} = Model, Kept, Down) ->
    lists:foreach(fun({Caller, Wrap}) -> wrapped(Model, Caller, Wrap, Down) end, Kept);
told(_, Kept, Down) ->
    lists:foreach(fun({Caller, Wrap}) -> Caller ! Wrap(Down) end, Kept).

%% ern_rt's wrapped/3 and counted_link/2, piece by piece: the process that
%% applies the wrap, linked or not, started at the reaper's word after
%% its recipient's liveness is read, its recipient read through the
%% checker, its row written and its source counted first; the wrap
%% applied through an adapted address, as ern_rt's send/2 applies it, or
%% straight; the process acting for its recipient; and its row taken and
%% its source let go at its end.
wrapped(#model{on = On, tables = Tables}, Caller, Wrap, Down) ->
    Starter = self(),
    Work = case On of
               #{adapted := true} -> fun() -> ern_rt:send(ern_rt:adapted(Caller, Wrap), Down) end;
               _ -> fun() -> Caller ! Wrap(Down) end
           end,
    Body = fun() ->
               _ = [ern_rt:acting_for(Caller) || is_map_key(acting, On)],
               Work(),
               [delivered(Tables, Caller, Starter) || is_map_key(delivery_rows, On)]
           end,
    Started = case On of
                  #{go := true} -> fun() -> receive go -> Body() end end;
                  _ -> Body
              end,
    Pid = case On of
              #{linked := true} -> erlang:spawn_link(Started);
              _ -> erlang:spawn(Started)
          end,
    case On of
        #{delivery_rows := true} ->
            #{deliveries := Deliveries, held := Held, checkers := Checkers} = Tables,
            ets:insert(Deliveries, {{behind(Checkers, Caller), Starter, Pid}}),
            counted(Held, Pid, 1);
        _ ->
            ok
    end,
    case On of
        #{go := true} ->
            case erlang:is_process_alive(Caller) of
                true -> Pid ! go;
                false -> ok
            end;
        _ ->
            ok
    end.

%% ern_rt's delivered/2: the delivery's row taken, its source let go.
delivered(#{deliveries := Deliveries, held := Held}, Recipient, Starter) ->
    ets:delete(Deliveries, {Recipient, Starter, self()}),
    counted(Held, self(), -1).

%% ern_rt's held_ended/3 of a delivery that returned, where its end is
%% held: what it delivered nothing of, none for one that returned; the
%% deliveries to it; its call; its monitors. Without, its 'EXIT' is taken
%% and nothing more.
held_ended(#model{on = #{held := true}, tables = Tables, monitoring = Monitoring} = Model, Pid,
           normal) ->
    #{deliveries := Deliveries, calls := Calls} = Tables,
    lists:foreach(fun(_) -> ok end, abandoned(Deliveries, Pid)),
    _ = ets:take(Calls, Pid),
    Model#model{monitoring = maps:remove(Pid, Monitoring)};
held_ended(Model, _, _) ->
    Model.

%%
%% The reaper's operations, each alone
%%

%% Each operation of the spawner's and the reaper's on their tables at a
%% spawn and at an end, alone in a loop, on tables made for its run, of the
%% process that runs it: at a spawn, the root read from the process
%% dictionary, the reaper found, the root read from the spawner's row, the
%% spawn's order and the row written; at an end, the offers taken, the
%% notes read, the row written and taken again, the call taken, the
%% reason, the three subscriptions deleted and the deliveries read; and
%% the loop alone.
operations() ->
    [{Name, fun(Count) -> operated(Operation, Count) end}
     || {Name, Operation} <-
            [{"the loop alone", fun(_, _) -> ok end},
             {"at a spawn, the root read from the process dictionary",
              fun(_, _) -> parent() end},
             {"  the reaper found",
              fun(_, _) -> persistent_term:get({ern_rt, reaper}, none) end},
             {"  the root read from the spawner's row",
              fun(#{processes := Processes}, Pid) -> root(Processes, Pid, Pid) end},
             {"  the spawn's order",
              fun(_, _) -> erlang:unique_integer([monotonic, positive]) end},
             {"  the row written",
              fun(#{processes := Processes}, Pid) -> ets:insert(Processes, row(Pid)) end},
             {"at an end, the offers taken",
              fun(#{offered := Offered}, Pid) -> ets:take(Offered, Pid) end},
             {"  the notes of its callers read",
              fun(#{callees := Callees}, Pid) -> ets:select(Callees, notes(Pid)) end},
             {"  the row written and taken again",
              fun(#{processes := Processes}, Pid) ->
                  ets:insert(Processes, row(Pid)),
                  ets:take(Processes, Pid)
              end},
             {"  its call taken", fun(#{calls := Calls}, Pid) -> ets:take(Calls, Pid) end},
             {"  its reason", fun(_, _) -> ern_rt:reason(normal) end},
             {"  its three subscriptions deleted",
              fun(#{faults := Faults, terminating := Terminating, restarts := Restarts}, Pid) ->
                  ets:delete(Faults, Pid),
                  ets:delete(Terminating, Pid),
                  ets:delete(Restarts, Pid)
              end},
             {"  the deliveries to it read",
              fun(#{deliveries := Deliveries}, Pid) -> abandoned(Deliveries, Pid) end}]].

%% A process's row, its own root.
row(Pid) ->
    {Pid, ?SITE, 0, 0, 0, Pid, none}.

%% Each operation of the caller's, the reaper's and the delivery's at a
%% monitor of a process that has ended, alone in a loop, on tables made
%% for its run, of the process that runs it, where the spawn's table has
%% none of its own: at the caller, the reference made and the checker
%% read; at the monitor, the row looked for, the source counted and let go
%% again, and the monitors kept and forgotten; at the 'DOWN', the reason;
%% the delivery's process, spawned and linked to a process that traps
%% exits, its 'EXIT' taken; its row written and taken again, its
%% recipient's liveness read; in it, acting for its recipient, the adapted
%% address made, and the wrap applied and its message received, beside
%% the same through the adapted address; and at its 'EXIT', the
%% deliveries to it read, its call taken, its monitors canceled.
monitor_operations() ->
    Wrap = fun(_) -> {'Ping', 0} end,
    [{Name, fun(Count) -> operated(Operation, Count) end}
     || {Name, Operation} <-
            [{"the loop alone", fun(_, _) -> ok end},
             {"at the caller, a reference made", fun(_, _) -> make_ref() end},
             {"  the checker in front of the process read",
              fun(#{checkers := Checkers}, Pid) -> behind(Checkers, Pid) end},
             {"at the monitor, the process's row looked for",
              fun(#{processes := Processes}, Pid) -> ets:lookup(Processes, Pid) end},
             {"  the source counted and let go again",
              fun(#{held := Held}, Pid) -> counted(Held, Pid, 1), counted(Held, Pid, -1) end},
             {"  the monitor kept and forgotten",
              fun(_, Pid) -> forgotten(kept(#model{}, Pid, [{Pid, Wrap}]), Pid) end},
             {"at the 'DOWN', its reason", fun(_, _) -> ern_rt:reason(noproc) end},
             {"the delivery's process, spawned, linked, its 'EXIT' taken",
              fun(_, _) -> linked() end},
             {"  its row written and taken again",
              fun(#{deliveries := Deliveries}, Pid) ->
                  ets:insert(Deliveries, {{Pid, Pid, Pid}}),
                  ets:delete(Deliveries, {Pid, Pid, Pid})
              end},
             {"  its recipient's liveness read", fun(_, Pid) -> erlang:is_process_alive(Pid) end},
             {"in it, acting for its recipient", fun(_, Pid) -> ern_rt:acting_for(Pid) end},
             {"  the adapted address made", fun(_, Pid) -> ern_rt:adapted(Pid, Wrap) end},
             {"  the wrap applied and its message received",
              fun(_, Pid) ->
                  Pid ! Wrap({'Down', Pid, 'Unknown', <<>>}),
                  receive {'Ping', 0} -> ok end
              end},
             {"  the same through the adapted address",
              fun(_, Pid) ->
                  ern_rt:send(ern_rt:adapted(Pid, Wrap), {'Down', Pid, 'Unknown', <<>>}),
                  receive {'Ping', 0} -> ok end
              end},
             {"at its 'EXIT', the deliveries to it read",
              fun(#{deliveries := Deliveries}, Pid) -> abandoned(Deliveries, Pid) end},
             {"  its call taken", fun(#{calls := Calls}, Pid) -> ets:take(Calls, Pid) end},
             {"  its monitors canceled",
              fun(_, Pid) -> maps:remove(Pid, (#model{})#model.monitoring) end}]].

%% A process spawned and linked to the caller, which traps exits, and its
%% 'EXIT' taken.
linked() ->
    Pid = erlang:spawn_link(fun() -> ok end),
    receive {'EXIT', Pid, normal} -> ok end.

%% Count iterations of Operation over tables made for the run, the
%% spawner's row among them, in a process of its own, which traps exits
%% and acts for no other.
operated(Operation, Count) ->
    Caller = self(),
    Pid = spawn(fun() ->
                    erlang:process_flag(trap_exit, true),
                    Tables = tables(),
                    #{processes := Processes} = Tables,
                    ets:insert(Processes, row(self())),
                    Measured = timed(Count, fun Loop(0) -> ok;
                                                Loop(Left) ->
                                                    _ = Operation(Tables, self()),
                                                    Loop(Left - 1)
                                            end),
                    deleted(Tables),
                    Caller ! {self(), Measured}
                end),
    receive {Pid, Measured} -> Measured end.

%%
%% The tables
%%

%% A table: its title, then each row's median and range, beside the first
%% row's median as a ratio, or with what it added to the row before; the
%% names as wide as the widest, the title's among them.
-spec table(iodata(), [{string(), [float()]}], ratio | added | none) -> iolist().
table(Title, [{_, First} | _] = Rows, Beside) ->
    {Base, _, _} = median_range(First),
    Width = lists:max([string:length(Title) | [string:length(Name) || {Name, _} <- Rows]]),
    {_, Lines} = lists:foldl(
                   fun({Name, Values}, {Before, Acc}) ->
                       {Median, Low, High} = median_range(Values),
                       Column = case Beside of
                                    ratio -> io_lib:format(" ~6.1fx", [Median / Base]);
                                    added when Before =:= none -> "";
                                    added -> io_lib:format(" ~s~.1f", [[$+ || Median >= Before],
                                                                       Median - Before]);
                                    none -> ""
                                end,
                       Line = io_lib:format("~ts ~8.1f ~8.1f to ~8.1f~s~n",
                                            [string:pad(Name, Width), Median, Low, High, Column]),
                       {Median, [Acc, Line]}
                   end, {none, []}, Rows),
    [io_lib:format("~ts ~8s ~20s~n", [string:pad(Title, Width), "median", "range"]), Lines, "\n"].

named(spawn, []) ->
    "a round trip to a process that spawns, the host's spawn";
named(spawn_monitored, Pieces) when length(Pieces) =:= length(?SPAWN) - 1 ->
    "the spawn's model whole, the Down sent by the reaper itself";
named(monitor, []) ->
    "a round trip to a process that monitors, the host's monitor";
named(_, Pieces) ->
    "+ " ++ piece(lists:last(Pieces)).

piece(monitor) -> "the reaper's monitor, and the 'DOWN' it takes at the end";
piece(start) -> "the start: the process waits for the reaper's word";
piece(run) -> "run/1: the error handler set, and the try";
piece(row) -> "the row at the spawn, as MVP 3.1 wrote it";
piece(root) -> "its root, read from the spawner's row since";
piece(ending) -> "the end's handling as MVP 3.1 made it";
piece(deliveries) -> "the deliveries to the process let go, since";
piece(look) -> "the reaper's wait with a time, for its look for a deadlock";
piece(delivery) -> "the wrap applied in a process of its own (§10)";
piece(linked) -> "that process linked to the reaper, as MVP 3.1 had it";
piece(trapped) -> "the reaper trapping exits, the delivery's 'EXIT' taken, since";
piece(go) -> "the delivery's start on the reaper's word";
piece(delivery_rows) -> "the delivery's recipient read, its row and its source";
piece(adapted) -> "the wrap applied through an adapted address";
piece(acting) -> "the delivery acting for its recipient, since";
piece(held) -> "the delivery's end held: deliveries to it, call, monitors, since";
piece(rows) -> "the reaper's rows at the monitor, as MVP 3.1 wrote them".

median_range(Values) ->
    Sorted = lists:sort(Values),
    {lists:nth(length(Sorted) div 2 + 1, Sorted), hd(Sorted), lists:last(Sorted)}.
