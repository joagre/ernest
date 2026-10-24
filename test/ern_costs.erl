%% The harness `make bench`'s parts share (docs/development.md): a table's
%% rows measured over seven runs, each run measuring every row once, in
%% turn, so that what drifts over the runs falls on all; a loop timed; a
%% measure run in a launch of the runtime, as `ern run` starts one; loops
%% run at once, each in a process the runtime spawns; a program's module
%% compiled from source and loaded; and the tables printed, each row's
%% median of its runs with their range, beside the first row's or a twin's
%% as a ratio.
-module(ern_costs).

-export([measured/2, timed/2, looped/1, launched/1, launched/2, at_once/2, compiled/2,
         downs/1, table/3, twin_table/2, median_range/1]).

%% The runs of each row.
-define(RUNS, 7).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Costs.at_once:1">>).

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

%% A loop of Operation, given the iterations left, its answer dropped.
-spec looped(fun((pos_integer()) -> term())) -> fun((non_neg_integer()) -> ok).
looped(Operation) ->
    fun Loop(0) -> ok;
        Loop(Left) -> _ = Operation(Left), Loop(Left - 1)
    end.

%% A run of Measure in the entry process of a launch of the runtime, as `ern
%% run` starts one (report §11.2), its output dropped. A host's row is
%% measured outside a launch where it waits for a host's 'DOWN', which the
%% runtime counts as no source and would take for a deadlock.
-spec launched(fun((pos_integer()) -> Measured)) -> fun((pos_integer()) -> Measured).
launched(Measure) ->
    launched(Measure, #{}).

%% The same in a launch given Options beside, a test's clock among them
%% (ern_rt:run_main/3).
-spec launched(fun((pos_integer()) -> Measured), map()) -> fun((pos_integer()) -> Measured).
launched(Measure, Options) ->
    fun(Count) ->
        Self = self(),
        ok = ern_rt:run_main(fun() -> Self ! {measured, Measure(Count)}, 'Unit' end,
                             <<"Costs.main">>, Options#{stdout => fun(_) -> ok end}),
        receive {measured, Measured} -> Measured end
    end.

%% Each of Loops run Count times in a process the runtime spawns in the
%% launch in progress, so that each has its row, as a program's process
%% has (report §6.9): the processes started, then told at once to begin,
%% and timed from then until each has run its loop; the nanoseconds and the
%% iterations over all processes.
-spec at_once(pos_integer(), [fun((pos_integer()) -> ok)]) -> {integer(), pos_integer()}.
at_once(Count, Loops) ->
    Self = self(),
    Pids = [ern_rt:spawn(fun() ->
                             Self ! {ready, self()},
                             receive begin_loop -> ok end,
                             ok = Loop(Count),
                             Self ! {looped, self()}
                         end, ?SITE)
            || Loop <- Loops],
    [receive {ready, Pid} -> ok end || Pid <- Pids],
    Started = erlang:monotonic_time(nanosecond),
    [Pid ! begin_loop || Pid <- Pids],
    [receive {looped, Pid} -> ok end || Pid <- Pids],
    {erlang:monotonic_time(nanosecond) - Started, Count * length(Loops)}.

%% A program's module of Source compiled into Namespace and loaded, as
%% `ern build` and `ern run` would make and load it (report §11.1, §11.2):
%% its unit.
-spec compiled([atom()], binary()) -> module().
compiled(Namespace, Source) ->
    {ok, Declarations} = ern_parser:parse_string(Source),
    {ok, Typed, Interface, Env} = ern_typecheck:check(Namespace, Declarations, []),
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env),
    {module, Unit} = code:load_binary(Unit, "bench", Beam),
    {ok, Recorded} = ern_canonical:read(Beam),
    ok = ern_code:loaded(Unit, Beam, Recorded),
    Unit.

%% Count of the host's 'DOWN' received.
-spec downs(non_neg_integer()) -> ok.
downs(0) -> ok;
downs(Left) -> receive {'DOWN', _, process, _, _} -> downs(Left - 1) end.

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
                                    ratio -> io_lib:format(" ~6.2fx", [Median / Base]);
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

%% A table of rows each measured twice, the twin's in Erlang and Ernest's,
%% each run a pair: each row's two medians, the ratio of Ernest's over the
%% twin's, and the two ranges.
-spec twin_table(string(), [{string(), [{float(), float()}]}]) -> iolist().
twin_table(Title, Measured) ->
    Width = lists:max([string:length(Title) | [string:length(Name) || {Name, _} <- Measured]]),
    Lines = [begin
                 {Twin, TwinLow, TwinHigh} = median_range([Value || {Value, _} <- Runs]),
                 {Ernest, ErnestLow, ErnestHigh} = median_range([Value || {_, Value} <- Runs]),
                 io_lib:format("~ts ~8.1f ~8.1f ~6.2fx   ~.1f to ~.1f, ~.1f to ~.1f~n",
                               [string:pad(Name, Width), Twin, Ernest, Ernest / Twin,
                                TwinLow, TwinHigh, ErnestLow, ErnestHigh])
             end || {Name, Runs} <- Measured],
    [io_lib:format("~ts ~8s ~8s ~7s   ~s~n",
                   [string:pad(Title, Width), "Erlang", "Ernest", "ratio", "ranges"]),
     Lines, "\n"].

%% The median of Values, the mean of the two middle ones where they are
%% even in number, the lowest and the highest.
-spec median_range([number(), ...]) -> {number(), number(), number()}.
median_range(Values) ->
    Sorted = lists:sort(Values),
    Count = length(Sorted),
    Median = case Count rem 2 of
                 1 -> lists:nth(Count div 2 + 1, Sorted);
                 0 -> (lists:nth(Count div 2, Sorted) + lists:nth(Count div 2 + 1, Sorted)) / 2
             end,
    {Median, hd(Sorted), lists:last(Sorted)}.
