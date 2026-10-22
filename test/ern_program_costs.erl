%% `make bench`'s part for three programs written twice (docs/development.md;
%% plan, MVP 3.29): the same algorithm in Ernest and in Erlang by hand, each
%% a ratio of the Ernest program's time over the Erlang's. The programs are
%% under test/fixtures/bench/, each Ernest module beside its twin: the ray
%% tracer of ernest-epx's examples, its pure half, raytracer.ern and
%% ern_raytracer_twin.erl, floats and records; the lexer, the parser and
%% the evaluator of examples/repl.ern over a fixed input, parser.ern and
%% ern_parser_twin.erl, strings and matching; and the guide's counter with
%% its callers, counter.ern and ern_counter_twin.erl, processes and calls.
%% An Ernest module is compiled from source as `ern build` compiles it; a
%% twin by erlc, into the bench's twins/ directory, as `make bench` builds
%% them.
%%
%% Measured, in programs.txt: a row for each program, the twin's run and
%% the Ernest program's, each timed in its own process from the call of the
%% function the bench calls to its answer, so that neither host's start nor the
%% program's initializers are in it: the Ernest program in the entry
%% process of a launch, as `ern run` starts one, its module's initializers
%% run first; the twin in a process of the bench's host outside any launch,
%% since the runtime counts no host process among its sources. The two
%% answer the same, or the part fails. Each run runs every program's pair
%% in turn, the twin first, and each row is the median of three runs, in
%% milliseconds a run, with the ratio and the two ranges. It measures and
%% asserts nothing but that, so it is not part of `make test-full`.
-module(ern_program_costs).

-export([main/1]).

-define(RUNS, 3).
%% The parser's input, its lines of expressions and the times it is read.
-define(EXPRESSIONS, 125).
-define(COPIES, 40).
%% The counter's callers and each one's calls.
-define(CALLERS, 8).
-define(CALLS, 10000).

%% Prints the table, writes it to programs.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    true = code:add_patha(filename:join(Directory, "twins")),
    Lines = lists:append(lists:duplicate(?COPIES, lines())),
    Programs =
        [{io_lib:format("the ray tracer, 400 by 300 pixels, two rays a pixel", []),
          {ern_raytracer_twin, render, fun() -> [] end},
          {'Raytracer', render, fun() -> [] end}},
         {io_lib:format("the parser, ~B lines of expressions read ~B times",
                        [length(lines()), ?COPIES]),
          {ern_parser_twin, run, fun() -> [copied(Lines)] end},
          {'Parser', run, fun() -> [copied(Lines)] end}},
         {io_lib:format("the counter, ~B callers of ~B calls each", [?CALLERS, ?CALLS]),
          {ern_counter_twin, run, fun() -> [?CALLERS, ?CALLS] end},
          {'Counter', run, fun() -> [?CALLERS, ?CALLS] end}}],
    Loaded = [{lists:flatten(Name), Twin, compiled(Ernest)} || {Name, Twin, Ernest} <- Programs],
    Runs = [[run(Program) || Program <- Loaded] || _ <- lists:seq(1, ?RUNS)],
    Measured = [{Name, [lists:nth(Index, Run) || Run <- Runs]}
                || {Index, {Name, _, _}} <- lists:enumerate(Loaded)],
    Text = unicode:characters_to_binary(table(Measured)),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "programs.txt"), Text),
    halt(0).

%% The Ernest module of Name compiled from its source under the fixtures,
%% the function the bench calls as a fun, with what makes its arguments.
compiled({Name, Function, Arguments}) ->
    Source = filename:join("fixtures/bench", string:lowercase(atom_to_list(Name)) ++ ".ern"),
    {ok, Text} = file:read_file(Source),
    Unit = ern_foreign_costs:compiled([Name], Text),
    {UnitFunction, Arity} = ern_code:function(Unit, [Name, Function]),
    {Unit, erlang:make_fun(Unit, UnitFunction, Arity), Arguments}.

%% One run of a program: the twin's and then the Ernest program's, each in
%% milliseconds, their answers the same.
run({Name, {Twin, Function, TwinArguments}, Ernest}) ->
    Called = erlang:make_fun(Twin, Function, length(TwinArguments())),
    {TwinMs, TwinAnswer} = twin_run(Called, TwinArguments),
    {ErnestMs, ErnestAnswer} = ernest_run(Ernest),
    TwinAnswer =:= ErnestAnswer
        orelse erlang:error({not_the_same, Name, TwinAnswer, ErnestAnswer}),
    {TwinMs, ErnestMs}.

%% The twin's function called with its arguments in a process of its
%% own, timed there.
twin_run(Called, Arguments) ->
    Self = self(),
    {Pid, MonitorRef} = spawn_monitor(fun() -> Self ! {self(), timed(Called, Arguments())} end),
    receive
        {Pid, Measured} ->
            erlang:demonitor(MonitorRef, [flush]),
            Measured;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            erlang:error({twin_failed, ExitReason})
    end.

%% The Ernest program's function called in a launch's entry process,
%% its module's initializers run first where it has any, timed there.
ernest_run({Unit, Called, Arguments}) ->
    Measure = fun(_) ->
                  _ = erlang:function_exported(Unit, '$init', 0) andalso Unit:'$init'(),
                  timed(Called, Arguments())
              end,
    (ern_spawn_costs:launched(Measure))(1).

timed(Called, Arguments) ->
    Started = erlang:monotonic_time(nanosecond),
    Answer = apply(Called, Arguments),
    {(erlang:monotonic_time(nanosecond) - Started) / 1.0e6, Answer}.

%% The lines copied, so that each run reads binaries of its own.
copied(Lines) ->
    [binary:copy(Line) || Line <- Lines].

%% The parser's input: for each of ?EXPRESSIONS names, a binding, an
%% arithmetic expression over it, a function bound and applied, a function
%% of two applied, a division by zero, an unbound name, and a line that
%% does not parse or does not lex, eight lines a name.
lines() ->
    lists:append([named_lines(Index) || Index <- lists:seq(1, ?EXPRESSIONS)]).

named_lines(Index) ->
    Name = "v" ++ [$a + Digit - $0 || Digit <- integer_to_list(Index)],
    Number = integer_to_list(Index),
    Wrong = case Index rem 2 of
                0 -> "3 + * " ++ Number;
                1 -> Number ++ " # 3"
            end,
    [list_to_binary(Line)
     || Line <- ["let " ++ Name ++ " = " ++ Number ++ " * 3 + 4",
                 "(" ++ Name ++ " - 2) * (" ++ Name ++ " + 7) / 3",
                 "let f" ++ Name ++ " = fun n -> n * n + " ++ Number,
                 "f" ++ Name ++ " (" ++ Name ++ " - 1)",
                 "(fun x -> fun y -> x * y - " ++ Number ++ ") " ++ Name ++ " 5",
                 "100 / (" ++ Name ++ " - " ++ Name ++ ")",
                 "unknown" ++ Name ++ " + 1",
                 Wrong]].

%%
%% The table
%%

%% The table: each program's two medians, their ratio, and their ranges.
table(Measured) ->
    Title = "three programs written twice, ms a run",
    Width = lists:max([string:length(Title) | [string:length(Name) || {Name, _} <- Measured]]),
    Lines = [begin
                 {Twin, TwinLow, TwinHigh} = median_range([T || {T, _} <- Runs]),
                 {Ernest, ErnestLow, ErnestHigh} = median_range([E || {_, E} <- Runs]),
                 io_lib:format("~ts ~8.1f ~8.1f ~6.2fx   ~.1f to ~.1f, ~.1f to ~.1f~n",
                               [string:pad(Name, Width), Twin, Ernest, Ernest / Twin,
                                TwinLow, TwinHigh, ErnestLow, ErnestHigh])
             end || {Name, Runs} <- Measured],
    [io_lib:format("~ts ~8s ~8s ~7s   ~s~n",
                   [string:pad(Title, Width), "Erlang", "Ernest", "ratio", "ranges"]),
     Lines, "\n"].

median_range(Values) ->
    Sorted = lists:sort(Values),
    {lists:nth(length(Sorted) div 2 + 1, Sorted), hd(Sorted), lists:last(Sorted)}.
