%% `make bench-pick` (docs/development.md): the push's experiment (the
%% log's *The Numbers Across Machines*) across the machines of
%% test/machines/machines.txt (plan, MVP 3.27 item 2). From a measuring
%% node, a burst of a hundred computes of a hundred milliseconds' work, sent
%% as fast as the node can, then a steady stream, one every fifty
%% milliseconds for a minute; how they fall over the peers under
%% `Peer.compute`'s pick, two drawn at random and the less busy taken
%% (report §8.7), and under the least busy of them all, a rule of the
%% program's own over `Peer.utilizations()` (the guide's §8.1); and beside
%% them, the packets each of the measuring node's connections carried a
%% second, the time each node's schedulers were busy, and the time each
%% machine's processors were idle, over the stream and at rest.
%%
%% The measuring program is test/fixtures/bench/pick.ern, its probe
%% test/fixtures/bench/ern_pick_probe.erl, on each node's load path. The
%% work is the program's loop, its steps calibrated first, so that it
%% takes a hundred milliseconds alone on the median peer machine. By
%% default the measuring node runs here and the peers are bare nodes on
%% the other machines, in two arrangements: (a) one on each, two or three
%% peers, where a draw of two leaves the least busy of three out one time in
%% three (the log's *The Placement Proposals Swept*), and (b) as many on
%% each as it has processors, the stream run again in (b) at
%% `utilization-interval` 1000 and 500, where its knee is (the log's *The
%% Numbers Across Machines*). Each run of each rule is a median over its
%% runs with their range: seven bursts and three streams by default.
%%
%% Each option is given as a word, an empty one taking the default: the
%% machine the measuring node runs on, by its name; the peers, as
%% `machine:count,...`, one arrangement of that many bare nodes on each
%% machine in that order, at 5000 alone; the intervals the stream runs at
%% again in the last arrangement, `1000,500` by default where no peers are
%% given; the runs, `bursts,streams`; and how every node measures its
%% utilization, `run-queue` or `schedulers` as Appendix C spells them, the
%% configuration's default where it is empty, the key being left out. It
%% prints the table, keeps each run's lines under Dir's name with `-raw`
%% after it, and halts. It measures and asserts nothing, so it is not part
%% of `make test-full`.
-module(ern_pick_costs).

-export([main/1]).

%% A compute's work, in microseconds.
-define(WORK, 100000).
%% The calibration: the steps of a compute that times the loop, and its
%% runs on each machine.
-define(CALIBRATION_STEPS, 1000000).
-define(CALIBRATION_RUNS, 5).
%% Report §8.7, Appendix C: `utilization-interval`'s default, and the
%% intervals of the knee the experiment looked for.
-define(INTERVAL, 5000).
-define(KNEE, [1000, 500]).
%% Each rule's bursts and streams at an arrangement's first interval;
%% a stream lasts a minute, and three are enough (plan, MVP 3.27 item 2).
-define(BURSTS, 7).
-define(STREAMS, 3).
%% A burst's computes.
-define(BURST, 100).

%% An arrangement of the peers over the machines: its label, the peers'
%% names with their machines in the configuration's order, and the
%% intervals it runs at, the bursts and the streams at the first and the
%% streams alone at the rest.
-record(arrangement, {label :: string(),
                      peers :: [{string(), ern_machine:machine()}],
                      intervals :: [pos_integer()]}).

-spec main([string()]) -> no_return().
main([Dir, File, Measuring, Peers, Intervals, Runs, Utilization]) ->
    ern_machines:reported(
      fun() ->
          Machines = ern_machines:ready(File),
          try
              Planned = planned(File, Machines, Measuring, Peers, Intervals),
              measured(Dir, Planned, runs(Runs), measure(Utilization))
          after
              [ern_machine_node:cleared(Machine, ern_machine:directory(Machine, Dir))
               || Machine <- Machines],
              ern_machines:closed(Machines)
          end
      end),
    halt(0).

%%
%% The plan
%%

%% The measuring machine and the arrangements, by default or as the
%% options give them.
planned(File, Machines, MeasuringName, PeersText, IntervalsText) ->
    Measuring = case MeasuringName of
                    "" -> ern_machines:local(Machines);
                    _ -> named(File, Machines, MeasuringName)
                end,
    Knee = case IntervalsText of
               "" -> ?KNEE;
               _ -> [number(Word, "an interval") || Word <- string:lexemes(IntervalsText, ",")]
           end,
    Arrangements =
        case PeersText of
            "" ->
                Others = [Machine || Machine <- Machines, Machine =/= Measuring],
                Others =/= []
                    orelse ern_machine:fail(File ++ " names no machine but the measuring one"),
                [arrangement("(a)", [{Machine, 1} || Machine <- Others], [?INTERVAL]),
                 arrangement("(b)", [{Machine, processors(Machine)} || Machine <- Others],
                             [?INTERVAL | Knee])];
            _ ->
                Counts = [counted(File, Machines, Word) || Word <- string:lexemes(PeersText, ",")],
                Intervals = case IntervalsText of
                                "" -> [];
                                _ -> Knee
                            end,
                [arrangement("given", Counts, [?INTERVAL | Intervals])]
        end,
    {Measuring, Arrangements}.

%% The peers of each machine, named for it and numbered from 1.
arrangement(Label, Counts, Intervals) ->
    #arrangement{label = Label,
                 peers = [{ern_machine:name(Machine) ++ integer_to_list(Index), Machine}
                          || {Machine, Count} <- Counts, Index <- lists:seq(1, Count)],
                 intervals = Intervals}.

named(File, Machines, Name) ->
    case [Machine || Machine <- Machines, ern_machine:name(Machine) =:= Name] of
        [Machine] -> Machine;
        [] -> ern_machine:fail(File ++ " names no machine " ++ Name)
    end.

counted(File, Machines, Word) ->
    case string:split(Word, ":") of
        [Name, Count] -> {named(File, Machines, Name), number(Count, "a count of peers")};
        _ -> ern_machine:fail("the peers are machine:count,..., not " ++ Word)
    end.

runs("") ->
    {?BURSTS, ?STREAMS};
runs(Text) ->
    case [number(Word, "a count of runs") || Word <- string:lexemes(Text, ",")] of
        [Bursts, Streams] -> {Bursts, Streams};
        _ -> ern_machine:fail("the runs are bursts,streams, not " ++ Text)
    end.

number(Text, What) ->
    try list_to_integer(Text) of
        Number when Number > 0 -> Number;
        _ -> ern_machine:fail(What ++ " is a whole number above 0, not " ++ Text)
    catch error:badarg ->
        ern_machine:fail(What ++ " is a whole number above 0, not " ++ Text)
    end.

processors(Machine) ->
    {_, Processors} = ern_machine:load_average(Machine),
    list_to_integer(Processors).

%% Report §8.7, Appendix C: the `utilization` written in every node's
%% `ernest.conf`, or none, where the key is left out and the node measures
%% by the configuration's default, the run queue.
measure("") ->
    none;
measure(Text) when Text =:= "run-queue"; Text =:= "schedulers" ->
    list_to_binary(Text);
measure(Text) ->
    ern_machine:fail("the utilization is run-queue or schedulers, not " ++ Text).

%%
%% The runs
%%

%% The program built and copied with the probe to each machine, the work
%% calibrated on the first arrangement's peers, and each arrangement
%% measured at each of its intervals, its tables printed.
measured(Dir, {Measuring, [First | Rest]}, Runs, Utilization) ->
    Involved = lists:uniq([Measuring | [Machine || #arrangement{peers = Peers} <- [First | Rest],
                                                   {_, Machine} <- Peers]]),
    [ern_machine_node:cleared(Machine, ern_machine:directory(Machine, Dir))
     || Machine <- Involved],
    Raw = Dir ++ "-raw",
    _ = file:del_dir_r(Raw),
    ok = filelib:ensure_path(Raw),
    ok = filelib:ensure_path(Dir),
    Root = filename:absname(filename:join(Dir, "build")),
    0 = ern_cli:ern(["build", "--source-root", "fixtures/bench", "--build-root", Root,
                     "fixtures/bench/pick.ern"], group_leader()),
    Probe = filename:absname("build/bench/probe"),
    Copied = [{Machine, #{program => ern_machine:copied(Machine, Root, Dir),
                          probe => ern_machine:copied(Machine, Probe, Dir)}}
              || Machine <- Involved],
    io:format("the push's experiment, measured from ~s~n",
              [ern_machine:name(Measuring)]),
    io:format("each node's utilization: ~s~n",
              [case Utilization of
                   none -> "\"run-queue\", the configuration's default";
                   _ -> ["\"", Utilization, "\""]
               end]),
    Nodes = made(Dir, Measuring, First, Utilization),
    Steps = calibrated(Raw, Copied, Nodes, First),
    arranged(Raw, Copied, Steps, Runs, Nodes, First),
    lists:foreach(fun(Arrangement) ->
                      arranged(Raw, Copied, Steps, Runs,
                               made(Dir, Measuring, Arrangement, Utilization), Arrangement)
                  end, Rest).

%% The arrangement's nodes made on their machines, each measuring its
%% utilization as given, and each peer listing the measuring node, a,
%% which dials them and is dialed by none.
made(Dir, Measuring, #arrangement{label = Label, peers = Peers}, Utilization) ->
    Nodes = fun(Machine) ->
                filename:join([ern_machine:directory(Machine, Dir), "nodes", named_label(Label)])
            end,
    A = ern_machine_node:configured(Measuring, Nodes(Measuring), "a", none),
    Made = [{Name, ern_machine_node:configured(Machine, Nodes(Machine), Name, 0)}
            || {Name, Machine} <- Peers],
    [ern_machine_node:edited(Node, fun(Configuration) ->
                                       Configuration#{<<"utilization">> => Utilization}
                                   end)
     || Utilization =/= none, Node <- [A | [Node || {_, Node} <- Made]]],
    [ern_machine_node:listed(Node, [{A, none}]) || {_, Node} <- Made],
    {A, Made}.

named_label(Label) ->
    string:trim(Label, both, "()").

%% The work's steps, from the runs of the calibration on the first peer of
%% each machine: scaled to ?WORK on the median machine, and said with each
%% machine's median.
calibrated(Raw, Copied, {A, Made}, #arrangement{peers = Peers}) ->
    Firsts = first_on_each(Peers),
    progress("calibrating the work on ~s", [lists:join(", ", [Name || {Name, _} <- Firsts])]),
    Lines = ran({A, Made}, Copied, ?INTERVAL,
                ["calibrate", integer_to_list(?CALIBRATION_STEPS),
                 integer_to_list(?CALIBRATION_RUNS) | [Name || {Name, _} <- Firsts]]),
    kept(Raw, "calibration", Lines),
    Medians = [{ern_machine:name(Machine),
                element(1, ern_costs:median_range([list_to_integer(Micros)
                                                   || ["calibration", Named, Micros] <- Lines,
                                                      Named =:= Name]))}
               || {Name, Machine} <- Firsts],
    {Middle, _, _} = ern_costs:median_range([Micros || {_, Micros} <- Medians]),
    Steps = round(?CALIBRATION_STEPS * ?WORK / Middle),
    io:format("the work: ~B steps of the loop, ~B ms alone on the median peer machine, as ~B"
              " steps took on each, the median of ~B runs alone on an idle node: ~s~n",
              [Steps, ?WORK div 1000, ?CALIBRATION_STEPS, ?CALIBRATION_RUNS,
               lists:join(", ", [io_lib:format("~s ~.1f ms", [Name, Micros / 1000])
                                 || {Name, Micros} <- Medians])]),
    Steps.

%% The first of each machine's, in the order given.
first_on_each(Named) ->
    lists:foldl(fun({_, Machine} = One, Firsts) ->
                    case lists:keymember(Machine, 2, Firsts) of
                        true -> Firsts;
                        false -> Firsts ++ [One]
                    end
                end, [], Named).

%% The arrangement at each of its intervals, the bursts and the streams at
%% the first and the streams alone at the rest, its tables printed.
arranged(Raw, Copied, Steps, {Bursts, Streams}, {A, _} = Nodes,
         #arrangement{label = Label, peers = Peers, intervals = [First | _] = Intervals}) ->
    Measuring = ern_machine_node:machine(A),
    io:format("~n~s ~s: ~s~n", [Label, lists:join(", ", [Name || {Name, _} <- Peers]),
                                described(Peers)]),
    io:format("the load averages before: ~s~n",
              [lists:join(", ", [io_lib:format("~s ~s on ~s processors",
                                               [ern_machine:name(Machine), LoadAverage,
                                                Processors])
                                 || Machine <- lists:uniq([Measuring | [Machine || {_, Machine}
                                                                                <- Peers]]),
                                    {LoadAverage, Processors}
                                        <- [ern_machine:load_average(Machine)]])]),
    lists:foreach(
      fun(Interval) ->
          Counts = case Interval of
                       First -> {Bursts, Streams};
                       _ -> {0, Streams}
                   end,
          progress("~s at ~B ms: ~B bursts and ~B streams of each rule, about ~B minutes",
                   [Label, Interval, element(1, Counts), element(2, Counts),
                    minutes(Counts, Interval)]),
          Lines = ran(Nodes, Copied, Interval,
                      ["measure", integer_to_list(Steps)]
                      ++ [integer_to_list(Count) || Count <- tuple_to_list(Counts)]
                      ++ [integer_to_list(Interval) | [Name || {Name, _} <- Peers]]),
          kept(Raw, io_lib:format("~s-~B", [named_label(Label), Interval]), Lines),
          tables(Lines, Measuring, Peers, Interval, Counts)
      end, Intervals).

%% The arrangement, by its peers' count on each machine.
described(Peers) ->
    Counts = [{Machine, length([Peer || {Peer, Of} <- Peers, Of =:= Machine])}
              || {_, Machine} <- first_on_each(Peers)],
    io_lib:format("bare nodes, ~s, each listing the measuring node",
                  [lists:join(", ", [io_lib:format("~B on ~s", [Count, ern_machine:name(Machine)])
                                     || {Machine, Count} <- Counts])]).

%% About how long the runs take: each burst's work and its wait for the
%% tellings, each stream's minute and its wait, and the rest at the end.
minutes({Bursts, Streams}, Interval) ->
    round((2 * Bursts * (10000 + Interval) + 2 * Streams * (65000 + Interval) + 5 * Interval)
          / 60000).

progress(Format, Arguments) ->
    io:format(standard_error, "pick: " ++ Format ++ "~n", Arguments).

%% A run's lines, kept as the program printed them.
kept(Raw, Name, Lines) ->
    ok = file:write_file(filename:join(Raw, lists:flatten(Name) ++ ".txt"),
                         [[lists:join(" ", Line), "\n"] || Line <- Lines]).

%% The interval written in every node's `ernest.conf` (Appendix C), the
%% peers started as bare nodes listening on ports the host picks, the
%% measuring node listing each at its port, the measuring program run on
%% it with Words, and the peers stopped after: the program's lines.
ran({A, Made}, Copied, Interval, Words) ->
    Change = fun(Configuration) -> Configuration#{<<"utilization-interval">> => Interval} end,
    [ern_machine_node:edited(Node, Change) || Node <- [A | [Node || {_, Node} <- Made]]],
    Running = [{Node, ern_machine_node:started(Node, ["--load-path", where(Node, Copied, probe)])}
               || {_, Node} <- Made],
    Ported = [{Node, ern_machine_node:port_bound(Reader), Reader} || {Node, Reader} <- Running],
    ern_machine_node:listed(A, [{Node, ern_machine_node:address(Node, Port)}
                                || {Node, Port, _} <- Ported]),
    try
        program(A, Copied, Words)
    after
        [begin
             ern_machine_node:stopped(Node),
             _ = ern_machine:ended(Reader)
         end || {Node, _, Reader} <- Ported]
    end.

where(Node, Copied, Kind) ->
    {_, Paths} = lists:keyfind(ern_machine_node:machine(Node), 1, Copied),
    maps:get(Kind, Paths).

%% The measuring program run on its node with Words, the probe on its load
%% path: its lines, each split into its words, or a failure with what it
%% wrote on standard error.
program(A, Copied, Words) ->
    Machine = ern_machine_node:machine(A),
    Errors = ern_machine_node:config_dir(A) ++ ".err",
    Command = lists:flatten([ern_machine:quoted(ern_machine:ern(Machine)), " run --config-dir ",
                             ern_machine:quoted(ern_machine_node:config_dir(A)),
                             " --load-path ", ern_machine:quoted(where(A, Copied, probe)), " ",
                             ern_machine:quoted(filename:join(where(A, Copied, program),
                                                              "pick.erc")),
                             [[" ", ern_machine:quoted(Word)] || Word <- Words],
                             " 2> ", ern_machine:quoted(Errors)]),
    %% the measuring program's run, which lasts as long as its work does
    case ern_machine:run(Machine, Command, infinity) of
        {0, Said} ->
            [string:lexemes(Line, " ") || Line <- string:lexemes(Said, "\n")];
        {Status, Said} ->
            ern_machine:fail(io_lib:format("the measuring program ended with status ~B: ~ts~ts",
                                           [Status, Said,
                                            ern_machine:ran(Machine, "cat "
                                                            ++ ern_machine:quoted(Errors))]))
    end.

%%
%% The tables
%%

%% The burst's table and the stream's, a column for each rule, and the
%% table of the nodes at rest.
tables(Lines, Measuring, Peers, Interval, {Bursts, Streams}) ->
    io:format("~nutilization-interval ~B ms~n", [Interval]),
    Bursts > 0 andalso
        computes_rows("burst", Lines, Peers,
                      io_lib:format("a burst of ~B computes, runs: ~B", [?BURST, Bursts]),
                      {"the burst's wall time, ms", 1000}),
    Streams > 0 andalso
        begin
            computes_rows("stream", Lines, Peers,
                          io_lib:format("a stream, a compute every 50 ms for 60 s, runs: ~B",
                                        [Streams]),
                          {"the stream's wall time, s", 1000000}),
            window_rows("stream", ["two", "least"], Lines, Measuring, Peers)
        end,
    io:format("~n~ts ~s~n", [padded(io_lib:format("at rest, over four intervals, ~B ms",
                                                  [4 * Interval])), "one run"]),
    window_rows("idle", ["rest"], Lines, Measuring, Peers).

%% Each rule's computes: how many each peer took, how many failed, the
%% wall time from the start to the last answer, a compute's round trip and
%% where its slowest tenth begins, and the work's time on each machine,
%% which grows where its processors are shared.
computes_rows(Kind, Lines, Peers, Title, {WallName, Scale}) ->
    io:format("~n~ts ~-24s ~-24s~n", [padded(Title), "two choices", "the least busy"]),
    Columns = [runs_of(Kind, Rule, Lines) || Rule <- ["two", "least"]],
    [row("  computes on " ++ Name,
         [[length([Peer || {_, _, {Peer, _}} <- Run, Peer =:= Name]) || Run <- Runs]
          || Runs <- Columns])
     || {Name, _} <- Peers],
    row("  failed", [[length([Error || {_, _, {failed, Error}} <- Run]) || Run <- Runs]
                     || Runs <- Columns]),
    row("  " ++ WallName, [[lists:max([Answered || {_, Answered, _} <- Run]) / Scale
                            || Run <- Runs]
                           || Runs <- Columns]),
    RoundTrips = [[(Answered - Sent) / 1000 || Run <- Runs, {Sent, Answered, _} <- Run]
                  || Runs <- Columns],
    row("  a compute's round trip, ms", RoundTrips),
    row("  its slowest tenth from, ms", [[tenth(Values) || Values =/= []] || Values <- RoundTrips]),
    [row("  the work's time on " ++ ern_machine:name(Machine) ++ ", ms",
         [[Micros / 1000 || Run <- Runs, {_, _, {Peer, Micros}} <- Run, is_integer(Micros),
                            lists:member({Peer, Machine}, Peers)]
          || Runs <- Columns])
     || {_, Machine} <- first_on_each(Peers)],
    true.

%% The runs of Kind under Rule, each a list of its computes: the
%% microseconds from the run's start to its sending and to its answer, and
%% the peer it ran on with the work's microseconds there, or the failure it
%% answered.
runs_of(Kind, Rule, Lines) ->
    Computes = [{Run, {list_to_integer(Sent), list_to_integer(Answered), ran_on(Rest)}}
                || [Named, Ruled, Run, _Index, Sent, Answered | Rest] <- Lines,
                   Named =:= Kind, Ruled =:= Rule],
    [[Compute || {Number, Compute} <- Computes, Number =:= Run]
     || Run <- lists:usort([Run || {Run, _} <- Computes])].

ran_on(["failed" | Error]) -> {failed, lists:join(" ", Error)};
ran_on([Peer, Micros]) -> {Peer, list_to_integer(Micros)}.

%% Over each window of Kind under each rule: the packets a second between
%% the measuring node and each peer, both ways, as the host counts them on
%% the measuring node; the time each node's schedulers were busy; and the
%% time each machine's processors were idle, read on its first node.
window_rows(Kind, Rules, Lines, Measuring, Peers) ->
    Columns = [windows(Kind, Rule, Lines) || Rule <- Rules],
    Carriers = [{Name, Carrier} || ["peer", Name, Carrier] <- Lines],
    [row("  packets a second, a and " ++ Name ++ ", both ways",
         [[packets(Window, Carrier) || Window <- Windows] || Windows <- Columns])
     || {Name, _} <- Peers, {Named, Carrier} <- Carriers, Named =:= Name],
    [row("  schedulers busy, " ++ Node ++ ", %",
         [[busy(Window, Node) || Window <- Windows] || Windows <- Columns])
     || Node <- ["a" | [Name || {Name, _} <- Peers]]],
    [row("  processors idle, " ++ ern_machine:name(Machine) ++ ", %",
         [[idle(Window, Node) || Window <- Windows] || Windows <- Columns])
     || {Node, Machine} <- first_on_each([{"a", Measuring} | Peers])],
    true.

%% Each run's window of Kind under Rule: each node's sample at its opening
%% and at its closing, by the node's name.
windows(Kind, Rule, Lines) ->
    Samples = [{Phase, Run, Node, Rest}
               || [Phase, Named, Ruled, Run, Node | Rest] <- Lines,
                  Phase =:= "open" orelse Phase =:= "close", Named =:= Kind, Ruled =:= Rule],
    [maps:from_list([{Node, {sampled([Rest || {"open", Of, At, Rest} <- Samples,
                                               Of =:= Run, At =:= Node]),
                             sampled([Rest || {"close", Of, At, Rest} <- Samples,
                                              Of =:= Run, At =:= Node])}}
                     || Node <- lists:usort([Node || {_, Of, Node, _} <- Samples, Of =:= Run])])
     || Run <- lists:usort([Run || {_, Run, _, _} <- Samples])].

sampled(Lines) ->
    lists:foldl(fun(["time", Time], Acc) ->
                        Acc#{time => list_to_integer(Time)};
                   (["packets", Carrier, In, Out], Acc) ->
                        Acc#{{packets, Carrier} => list_to_integer(In) + list_to_integer(Out)};
                   (["schedulers", Busy, Counted], Acc) ->
                        Acc#{schedulers => {list_to_integer(Busy), list_to_integer(Counted)}};
                   (["processors", Idle, Whole], Acc) ->
                        Acc#{processors => {list_to_integer(Idle), list_to_integer(Whole)}}
                end, #{}, Lines).

packets(Window, Carrier) ->
    {Opened, Closed} = maps:get("a", Window),
    Key = {packets, Carrier},
    (maps:get(Key, Closed) - maps:get(Key, Opened, 0)) * 1.0e6
        / (maps:get(time, Closed) - maps:get(time, Opened)).

busy(Window, Node) ->
    {Opened, Closed} = maps:get(Node, Window),
    {Busy, Counted} = maps:get(schedulers, Opened),
    {Busy1, Counted1} = maps:get(schedulers, Closed),
    100 * (Busy1 - Busy) / (Counted1 - Counted).

idle(Window, Node) ->
    {Opened, Closed} = maps:get(Node, Window),
    {Idle, Whole} = maps:get(processors, Opened),
    {Idle1, Whole1} = maps:get(processors, Closed),
    100 * (Idle1 - Idle) / (Whole1 - Whole).

%% A row: its name, then each column's values as their median and range.
row(Name, Columns) ->
    io:format("~ts~s~n", [padded(Name), [[" ", cell(Values)] || Values <- Columns]]).

%% A row's name padded to its column, never cut.
padded(Text) ->
    string:pad(lists:flatten(Text), 46).

cell([]) ->
    io_lib:format("~-24s", ["none"]);
cell(Values) ->
    {Median, Low, High} = ern_costs:median_range(Values),
    io_lib:format("~-24s", [lists:flatten(io_lib:format("~s  (~s to ~s)",
                                                        [shown(Median), shown(Low),
                                                         shown(High)]))]).

shown(Value) when is_integer(Value) -> integer_to_list(Value);
shown(Value) when abs(Value) >= 100 -> integer_to_list(round(Value));
shown(Value) -> float_to_list(Value, [{decimals, 1}]).

%% Where the slowest tenth of Values begins.
tenth(Values) ->
    lists:nth(max(1, ceil(0.9 * length(Values))), lists:sort(Values)).
