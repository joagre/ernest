%% `make bench`'s part `burst` (docs/development.md), beside
%% ern_spawn_costs and ern_restarting_costs: what each element of a burst
%% costs against the burst's size (report §6.9, §10, Appendix E.15; plan,
%% MVP 3.27 item 3). What the runtime adds to an operation grows with
%% nothing but the operation's own input (§10), so an element of a burst
%% costs what it costs alone, however many stand beside it: an end reads
%% the monitors of the process that ended, and a caller's end its own,
%% each by its key (ern_rt's monitored/6, down/3); a delivery is noted by
%% its recipient (counted_link/2); and the clock forgets an alarm that
%% fired by its timer alone (fired/2). The reaper's and the clock's
%% bookkeeping grew with the burst until MVP 3.27 item 3 (the log's *The
%% Rows That Grew*), and nothing had measured a burst against its size.
%%
%% Measured, in burst.txt, each burst at three sizes, in nanoseconds an
%% element, beside the smallest size's as a ratio, so that a cost that
%% grows faster than the burst shows as a ratio that rises with the size:
%% one process's monitors of processes that then end, until it has
%% received every Down; callers that each monitor one process and then
%% end, until the reaper has let every monitor go; deliveries of Downs in
%% flight to one process, each wrap waiting for a word, started until
%% every wrap waits, then delivered once each is given its word, until
%% every Down is received; and one process's alarms at one time, which
%% fire as the clock is set to it, until every alarm has fired. Each row
%% is the median of seven runs, with their range, each run measuring every
%% burst at every size once, in turn, so that what drifts over the runs
%% falls on all, as ern_costs measures a table's rows. It measures and
%% asserts nothing, so it is not part of `make test-full`.
-module(ern_burst_costs).

-export([main/1]).

%% The runs of each row, and the sizes of each burst.
-define(RUNS, 7).
-define(COUNTS, [1000, 5000, 25000]).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Burst.costs:1">>).
%% The farthest the clock arms a host's timer for at once, in milliseconds
%% (ern_rt's SLICE): the alarms are at this time while the clock reads 0,
%% so that no timer of theirs fires before the clock is set to it.
-define(FARTHEST, 16#FFFFFFFF).

%% Prints the tables, writes them to burst.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Bursts = bursts(),
    Runs = [run(Bursts) || _ <- lists:seq(1, ?RUNS)],
    Text = unicode:characters_to_binary(
             [ern_costs:table(Title,
                              [{row(Count, Elements),
                                [maps:get({Title, Count}, Run) || Run <- Runs]}
                               || Count <- ?COUNTS],
                              ratio)
              || {Titles, Elements, _} <- Bursts, Title <- Titles]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "burst.txt"), Text),
    halt(0).

%% Each burst: the title of each of its times, what it counts, and its
%% measure in a launch, which gives each time and the count it is of.
bursts() ->
    [{["one process monitoring processes that end, ns a process"],
      "processes", ern_costs:launched(fun monitored_ends/1)},
     {["callers of one process that end, ns a caller"],
      "callers", ern_costs:launched(fun callers_ending/1)},
     {["deliveries in flight to one process, started, ns a delivery",
       "deliveries in flight to one process, delivered, ns a delivery"],
      "deliveries", ern_costs:launched(fun deliveries/1)},
     {["one process's alarms firing at once, ns an alarm"],
      "alarms", fun alarms/1}].

%% One run: every burst at each size, in turn, each of its times in
%% nanoseconds an element, by its title and size.
run(Bursts) ->
    maps:from_list([{{Title, Count}, Nanoseconds / Count}
                    || {Titles, _, Measure} <- Bursts, Count <- ?COUNTS,
                       {Title, {Nanoseconds, _}} <- lists:zip(Titles, Measure(Count))]).

row(Count, Elements) ->
    io_lib:format("~B ~s", [Count, Elements]).

%%
%% The bursts, each in a launch
%%

%% Each burst counts its process in a timed receive while it runs
%% (ern_rt:timed/0), so that the runtime's look for a deadlock (report
%% §8.6) finds none while every process waits for a word of the burst's.

%% Report §6.9: one process's monitors of Count processes the runtime
%% started, which then end: from their word to return until the process
%% has received every Down.
monitored_ends(Count) ->
    ern_rt:timed(),
    Pids = returning(Count),
    [ern_rt:monitor(Pid, fun(_) -> ended end) || Pid <- Pids],
    Measured = ern_costs:timed(Count, fun(_) ->
                                          [Pid ! return || Pid <- Pids],
                                          received(ended, Count)
                                      end),
    ern_rt:untimed(),
    [Measured].

%% Report §6.9: Count callers, processes the runtime started, that each
%% monitor one process and then end: from their word to return until the
%% reaper has let every monitor go. Its answer to a spawn asked once every
%% caller's end is seen shows it: it takes its messages in the order they
%% came, so it answers once it has handled every end before it.
callers_ending(Count) ->
    ern_rt:timed(),
    Main = self(),
    [Monitored] = returning(1),
    Callers = [ern_rt:spawn(fun() ->
                                ern_rt:monitor(Monitored, fun(_) -> ended end),
                                Main ! monitoring,
                                receive return -> 'Unit' end
                            end, ?SITE)
               || _ <- lists:seq(1, Count)],
    received(monitoring, Count),
    [erlang:monitor(process, Caller) || Caller <- Callers],
    Measured = ern_costs:timed(Count, fun(_) ->
                                          [Caller ! return || Caller <- Callers],
                                          ern_costs:downs(Count),
                                          _ = ern_rt:spawn(fun() -> 'Unit' end, ?SITE),
                                          ok
                                      end),
    Monitored ! return,
    ern_rt:untimed(),
    [Measured].

%% Report §6.9, §10: Count deliveries in flight to one process, each a
%% Down's, whose wrap, applied in the delivery's own process, waits for a
%% word: from the monitored processes' word to return until every wrap
%% waits, and from the wraps' words until the process has received every
%% Down.
deliveries(Count) ->
    ern_rt:timed(),
    Main = self(),
    Wrap = fun(_) ->
               Main ! {in_flight, self()},
               receive released -> ended end
           end,
    Pids = returning(Count),
    [ern_rt:monitor(Pid, Wrap) || Pid <- Pids],
    Started = erlang:monotonic_time(nanosecond),
    [Pid ! return || Pid <- Pids],
    Deliveries = [receive {in_flight, Delivery} -> Delivery end || _ <- Pids],
    InFlight = erlang:monotonic_time(nanosecond),
    [Delivery ! released || Delivery <- Deliveries],
    received(ended, Count),
    Delivered = erlang:monotonic_time(nanosecond),
    ern_rt:untimed(),
    [{InFlight - Started, Count}, {Delivered - InFlight, Count}].

%% Appendix E.15: one process's Count alarms at one time, each set as
%% Clock.alarmAt's code sets it while the launch's clock, a test's
%% (ern_rt:run_main/3), reads 0; then the clock set to the time, and the
%% host's report of the change, which the clock waits for to fire an
%% alarm at a time the clock was set past, given to it in the host's
%% place: from the report, at which the clock sets each alarm again, now
%% due, until every alarm has fired. An alarm after milliseconds would
%% fire at a moment chosen to come after the last is set; the clock set to
%% the alarms' time fires them all at once, with nothing chosen.
alarms(Count) ->
    Time = atomics:new(1, []),
    Measure = ern_costs:launched(fun(_) -> alarms_firing(Time, Count) end,
                                 #{time => fun() -> atomics:get(Time, 1) end}),
    Measure(Count).

alarms_firing(Time, Count) ->
    ern_rt:timed(),
    Clock = ern_rt:system_process(clock),
    Wrap = fun(_) -> fired end,
    [ern_rt:call_forever(Clock, fun(Reply) ->
                                    {'AlarmAt', ?FARTHEST, ern_rt:adapted(ern_rt:self(), Wrap),
                                     Reply}
                                end)
     || _ <- lists:seq(1, Count)],
    atomics:put(Time, 1, ?FARTHEST),
    Measured = ern_costs:timed(Count, fun(_) ->
                                          Clock ! {'CHANGE', make_ref(), time_offset,
                                                   clock_service, 0},
                                          received(fired, Count)
                                      end),
    ern_rt:untimed(),
    [Measured].

%% Count processes the runtime started, each waiting for its word to
%% return.
returning(Count) ->
    [ern_rt:spawn(fun() -> receive return -> 'Unit' end end, ?SITE) || _ <- lists:seq(1, Count)].

%% Message received Count times.
received(_, 0) ->
    ok;
received(Message, Left) ->
    receive Message -> received(Message, Left - 1) end.
