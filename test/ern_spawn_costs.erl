%% `make bench`'s fifth part (docs/development.md): what each piece of
%% Ernest's spawn adds to the host's (report §6.9, §10; plan, MVP 3.27
%% item 2). A spawn asks the reaper, which starts the process with a
%% monitor of its own, writes its row and answers, and at the process's
%% end takes the host's `'DOWN'` and lets go of what the process held
%% (ern_rt's spawn_with_monitors/4, spawned/7 and down/3).
%%
%% Measured, a table each: the host's spawn and Ernest's, through the
%% runtime in a launch, as the bench's row measures them, and Ernest's of
%% a process that waits, so that no end comes between the spawns; the same
%% on one scheduler, where nothing waits for another scheduler to wake;
%% there, a model of the reaper, a process that does what the reaper does
%% a piece at a time, each row adding one piece to the row before, so that
%% the runtime's multiple of the host's spawn is accounted for piece by
%% piece; and each operation of the reaper's on its tables at a spawn and
%% at an end, alone in a loop of its own, on tables of the runtime's kinds
%% as empty as the bench leaves them. Each row is the median of seven runs,
%% in nanoseconds an iteration, the loop's own cost included, with their
%% range; each run measures every row of its table once, in turn, so that
%% what drifts over the runs falls on all. It measures and asserts
%% nothing, so it is not part of `make test-full`.
-module(ern_spawn_costs).

-export([main/1]).

%% Each spawn loop's iterations, an operation loop's, the runs of each
%% row, and the processes that wait at once for the spawn alone.
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

%% The pieces of the model, in the order they are added: the monitor and
%% the 'DOWN' taken at the end; the start, the process waiting for the
%% reaper's word; run/1, the error handler and the try; the row at the
%% spawn as MVP 3.1 wrote it, and its root read, which came after; the
%% end's handling as MVP 3.1 made it, and the deliveries let go, which came
%% after; and the reaper's wait with a time, for its look.
-define(PIECES, [monitor, start, run, row, root, ending, deliveries, look]).

%% Prints the tables, writes them to File, and halts.
-spec main([string()]) -> no_return().
main([File]) ->
    Spawns = [{"the host's spawn of a process that returns", fun host_spawns/1},
              {"Ernest's spawn of a process that returns, through the reaper",
               launched(fun ernest_spawns/1)},
              {"  the same of a process that waits, no end between",
               launched(fun spawns_alone/1)}],
    Model = [{named(Pieces), fun(Count) -> modeled(Pieces, Count) end} || Pieces <- ladder()],
    All = measured(Spawns, ?COUNT),
    Schedulers = erlang:system_flag(schedulers_online, 1),
    One = try measured(Spawns ++ Model, ?COUNT)
          after erlang:system_flag(schedulers_online, Schedulers)
          end,
    Operations = measured(operations(), ?OPERATIONS),
    Text = iolist_to_binary(
             [table(io_lib:format("the spawn on the host's ~B schedulers, ns an iteration",
                                  [Schedulers]), All, ratio),
              table("on one scheduler, ns an iteration", lists:sublist(One, length(Spawns)),
                    ratio),
              table("a model of the reaper on one scheduler, a piece added on each row",
                    lists:nthtail(length(Spawns), One), added),
              table("the reaper's operations, each alone, ns an operation", Operations,
                    none)]),
    io:format("~ts", [Text]),
    ok = file:write_file(File, Text),
    halt(0).

%% The model's rows: none of the pieces, then each added in turn.
ladder() ->
    [lists:sublist(?PIECES, Count) || Count <- lists:seq(0, length(?PIECES))].

%% Each row's runs, the rows taking turns within a run: its name and the
%% nanoseconds an iteration of each run.
measured(Rows, Count) ->
    Runs = [[{Name, per_iteration(Measure(Count))} || {Name, Measure} <- Rows]
            || _ <- lists:seq(1, ?RUNS)],
    [{Name, [Value || Run <- Runs, {Named, Value} <- Run, Named =:= Name]}
     || {Name, _} <- Rows].

per_iteration({Nanoseconds, Count}) ->
    Nanoseconds / Count.

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

%% A run of Measure in the entry process of a launch of the runtime, as `ern
%% run` starts one (report §11.2), its output dropped.
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

%% A run of the model with Pieces on: a process standing for the reaper,
%% asked as the runtime asks the reaper, its tables made for the run, the
%% spawner's row among them, as the entry process has one.
modeled(Pieces, Count) ->
    Tables = tables(),
    #{processes := Processes} = Tables,
    ets:insert(Processes, {self(), ?SITE, 0, 0, 0, self(), none}),
    Model = spawn(fun() -> model(Pieces, Tables) end),
    persistent_term:put({?MODULE, model}, Model),
    Measured = timed(Count, fun(Left) -> asking(Left, Pieces) end),
    MonitorRef = erlang:monitor(process, Model),
    exit(Model, kill),
    receive {'DOWN', MonitorRef, process, Model, _} -> ok end,
    deleted(Tables),
    Measured.

%% The spawner's side, as ern_rt's spawn_with_monitors/4 asks: the root
%% read from the spawner where the row's root is on, the reaper found, the
%% request sent, the answer waited for.
asking(0, _) ->
    ok;
asking(Left, Pieces) ->
    Chain = case lists:member(root, Pieces) of
                true -> {chained, parent()};
                false -> chained
            end,
    Ref = make_ref(),
    persistent_term:get({?MODULE, model})
        ! {spawn, self(), Ref, fun() -> 'Unit' end, ?SITE, [], Chain},
    receive {Ref, _Pid} -> ok end,
    asking(Left - 1, Pieces).

parent() ->
    case erlang:get(?ACTING) of
        undefined -> self();
        Acting -> Acting
    end.

%% The runtime's tables a spawn and an end read, named and of the
%% runtime's kinds (ern_rt's table_kind/1).
tables() ->
    maps:from_list([{Name, ets:new(list_to_atom("ern_spawn_costs_" ++ atom_to_list(Name)),
                                   [named_table, public, Kind])}
                    || {Name, Kind} <- [{processes, set}, {calls, set}, {callees, ordered_set},
                                        {faults, set}, {terminating, set}, {restarts, set},
                                        {deliveries, ordered_set}, {offered, bag}]]).

deleted(Tables) ->
    [ets:delete(Table) || Table <- maps:values(Tables)],
    ok.

model(Pieces, Tables) ->
    erlang:process_flag(trap_exit, true),
    On = maps:from_list([{Piece, true} || Piece <- Pieces]),
    case On of
        #{look := true} -> looking(On, Tables);
        _ -> waiting(On, Tables)
    end.

%% The reaper's receive, without a time and with it.
waiting(On, Tables) ->
    receive
        {spawn, From, Ref, Function, Site, _Monitors, Chain} ->
            started(On, Tables, From, Ref, Function, Site, Chain),
            waiting(On, Tables);
        {'DOWN', _MonitorRef, process, Pid, ExitReason} ->
            down(On, Tables, Pid, ExitReason),
            waiting(On, Tables)
    end.

looking(On, Tables) ->
    receive
        {spawn, From, Ref, Function, Site, _Monitors, Chain} ->
            started(On, Tables, From, Ref, Function, Site, Chain),
            looking(On, Tables);
        {'DOWN', _MonitorRef, process, Pid, ExitReason} ->
            down(On, Tables, Pid, ExitReason),
            looking(On, Tables)
    after ?LOOK ->
        looking(On, Tables)
    end.

%% ern_rt's spawned/7, piece by piece.
started(On, Tables, From, Ref, Function, Site, Chain) ->
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
    From ! {Ref, Pid}.

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

%% ern_rt's run/1.
run(Function) ->
    erlang:process_flag(error_handler, ern_rt),
    try
        Function()
    catch
        Class:Error:Stack -> exit(ern_rt:fault_exit_reason(Class, Error, Stack))
    end.

%% ern_rt's down/3, piece by piece: MVP 3.1's, its offers, the notes of
%% its callers, its row, its call, its subscriptions and its monitors; and
%% since, the deliveries to it let go.
down(#{ending := true} = On, Tables, Pid, ExitReason) ->
    #{processes := Processes, calls := Calls, callees := Callees, faults := Faults,
      terminating := Terminating, restarts := Restarts, offered := Offered} = Tables,
    lists:foreach(fun(_) -> ok end, ets:take(Offered, Pid)),
    lists:foreach(fun(_) -> ok end, ets:select(Callees, notes(Pid))),
    case ets:take(Processes, Pid) of
        [Row] ->
            _ = ets:take(Calls, Pid),
            Reason = ern_rt:reason(ExitReason),
            ets:delete(Faults, Pid),
            ets:delete(Terminating, Pid),
            ets:delete(Restarts, Pid),
            Down = {'Down', Pid, Reason, element(2, Row)},
            lists:foreach(fun(Caller) -> Caller ! Down end, []);
        [] ->
            ok
    end,
    case On of
        #{deliveries := true} ->
            #{deliveries := Deliveries} = Tables,
            lists:foreach(fun(_) -> ok end, deliveries(Deliveries, Pid));
        _ ->
            ok
    end;
down(_, _, _, _) ->
    ok.

%% ern_rt's drop_callee_notes/2's read of the rows of a process's callers.
notes(Pid) ->
    [{{{Pid, '$1'}, '$2'}, [], [{{'$1', '$2'}}]}].

%% ern_rt's deliveries/1, the deliveries in flight to a process.
deliveries(Deliveries, Pid) ->
    try ets:select(Deliveries, [{{{Pid, '_', '_'}}, [], [{element, 1, '$_'}]}])
    catch _:_ -> []
    end.

%%
%% The reaper's operations, each alone
%%

%% Each operation of the spawner's and the reaper's on their tables, alone
%% in a loop, on tables made for its run: at a spawn, the root read from
%% the process dictionary, the reaper found, the root read from the
%% spawner's row, the spawn's order and the row written; at an end, the
%% offers taken, the notes read, the row written and taken again, the call
%% taken, the reason, the three subscriptions deleted and the deliveries
%% read; and the loop alone.
operations() ->
    Pid = self(),
    Row = {Pid, ?SITE, 0, 0, 0, Pid, none},
    [{Name, fun(Count) -> operated(Operation, Count) end}
     || {Name, Operation} <-
            [{"the loop alone", fun(_) -> ok end},
             {"at a spawn, the root read from the process dictionary", fun(_) -> parent() end},
             {"  the reaper found", fun(_) -> persistent_term:get({ern_rt, reaper}, none) end},
             {"  the root read from the spawner's row",
              fun(#{processes := Processes}) -> root(Processes, Pid, Pid) end},
             {"  the spawn's order", fun(_) -> erlang:unique_integer([monotonic, positive]) end},
             {"  the row written",
              fun(#{processes := Processes}) -> ets:insert(Processes, Row) end},
             {"at an end, the offers taken",
              fun(#{offered := Offered}) -> ets:take(Offered, Pid) end},
             {"  the notes of its callers read",
              fun(#{callees := Callees}) -> ets:select(Callees, notes(Pid)) end},
             {"  the row written and taken again",
              fun(#{processes := Processes}) ->
                  ets:insert(Processes, Row),
                  ets:take(Processes, Pid)
              end},
             {"  its call taken", fun(#{calls := Calls}) -> ets:take(Calls, Pid) end},
             {"  its reason", fun(_) -> ern_rt:reason(normal) end},
             {"  its three subscriptions deleted",
              fun(#{faults := Faults, terminating := Terminating, restarts := Restarts}) ->
                  ets:delete(Faults, Pid),
                  ets:delete(Terminating, Pid),
                  ets:delete(Restarts, Pid)
              end},
             {"  the deliveries to it read",
              fun(#{deliveries := Deliveries}) -> deliveries(Deliveries, Pid) end}]].

%% Count iterations of Operation over tables made for the run, the
%% spawner's row among them.
operated(Operation, Count) ->
    Tables = tables(),
    #{processes := Processes} = Tables,
    ets:insert(Processes, {self(), ?SITE, 0, 0, 0, self(), none}),
    Measured = timed(Count, fun Loop(0) -> ok;
                                Loop(Left) -> _ = Operation(Tables), Loop(Left - 1)
                            end),
    deleted(Tables),
    Measured.

%%
%% The tables
%%

%% A table: its title, then each row's median and range, beside the first
%% row's median as a ratio, or with what it added to the row before.
table(Title, [{_, First} | _] = Rows, Beside) ->
    {Base, _, _} = median_range(First),
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
                                            [string:pad(Name, 62), Median, Low, High, Column]),
                       {Median, [Acc, Line]}
                   end, {none, []}, Rows),
    [io_lib:format("~ts ~8s ~20s~n", [string:pad(Title, 62), "median", "range"]), Lines, "\n"].

named([]) -> "a round trip to a process that spawns, the host's spawn";
named(Pieces) -> "+ " ++ piece(lists:last(Pieces)).

piece(monitor) -> "the reaper's monitor, and the 'DOWN' it takes at the end";
piece(start) -> "the start: the process waits for the reaper's word";
piece(run) -> "run/1: the error handler set, and the try";
piece(row) -> "the row at the spawn, as MVP 3.1 wrote it";
piece(root) -> "its root, read from the spawner's row since";
piece(ending) -> "the end's handling as MVP 3.1 made it";
piece(deliveries) -> "the deliveries to the process let go, since";
piece(look) -> "the reaper's wait with a time, for its look for a deadlock".

median_range(Values) ->
    Sorted = lists:sort(Values),
    {lists:nth(length(Sorted) div 2 + 1, Sorted), hd(Sorted), lists:last(Sorted)}.
