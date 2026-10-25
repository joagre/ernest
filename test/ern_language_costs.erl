%% `make bench`'s part `language`, the language against the host
%% (docs/development.md; plan, MVP 3.29): each construct the compiler writes
%% code for, in the code it writes, beside the plain Erlang a programmer
%% writes for the same thing. test/fixtures/bench/language.ern holds a loop
%% of each construct, compiled from source as `ern build` compiles it, and
%% test/fixtures/bench/ern_language_twin.erl the same loops as Erlang writes
%% them, which `make bench` compiles with erlc into the bench's twins/
%% directory.
%%
%% A `match` is a case on tagged tuples, and one whose guards call
%% functions falls through each by a fun of the clauses after it (report
%% §5.9); a record update rebuilds the tuple; each Float operation runs in
%% a try of its own that makes a result that is not finite a fault, and a
%% product adds 0.0, so that no negative zero is made (§3.1); a derived
%% `compare` calls each field's (§3.5); a requirement's member is a fun the
%% caller passes (§4.9); a slice, a map read and a map write are library
%% functions, each around a foreign call (Appendix E.3, E.5); a send and a
%% receive go through the runtime, the receive with a restart's clause and
%% a fault's (§6.2, §6.3); and `Io.show` writes a value by its type's
%% descriptor (Appendix E.1).
%%
%% Measured, in language.txt: a row for each construct, the twin's loop and
%% Ernest's of the same count over the same operands, made in the process
%% that runs them, or for a Float expression made in the loop from the last
%% result, so that the host knows the operands are floats as it knows a
%% program's; the first row the loop alone, which every row's time holds.
%% Each loop runs in a launch of its own, as `ern run` starts one, so that
%% both sides run in a fresh entry process. Each run measures every row in
%% turn, the twin's loop and then Ernest's, and each row is the median of
%% seven runs, in nanoseconds an iteration, with the ratio of Ernest's over
%% the twin's and the two ranges. It measures and asserts nothing, so it is
%% not part of `make test-full`.
-module(ern_language_costs).

-export([main/1]).

-define(RUNS, 7).
%% The module the constructs are compiled into, its source, and its twin.
-define(NAMESPACE, ['Language']).
-define(SOURCE, "fixtures/bench/language.ern").
-define(TWIN, ern_language_twin).

%% Prints the table, writes it to language.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    true = code:add_patha(filename:join(Directory, "twins")),
    {ok, Source} = file:read_file(?SOURCE),
    Unit = ern_costs:compiled(?NAMESPACE, Source),
    Rows = rows(Unit),
    Runs = [[run(Row) || Row <- Rows] || _ <- lists:seq(1, ?RUNS)],
    Measured = [{Name, [lists:nth(Index, Run) || Run <- Runs]}
                || {Index, {Name, _, _, _}} <- lists:enumerate(Rows)],
    Text = unicode:characters_to_binary(
             ern_costs:twin_table("the language against the host, ns an iteration", Measured)),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "language.txt"), Text),
    halt(0).

%% Each row: its name, its loops' count, and the twin's loop and Ernest's,
%% each a function with the operands it is given after the count.
rows(Unit) ->
    Ernest = fun(Name) -> ernest_function(Unit, Name) end,
    Twin = fun twin_function/1,
    Text = fun(Bytes) -> binary:copy(Bytes) end,
    Row = fun(Name, Count, TwinName, ErnestName, Operands) ->
              {Name, Count, {Twin(TwinName), Operands}, {Ernest(ErnestName), Operands}}
          end,
    Read = fun() -> [maps:from_list([{Key, Key * 10} || Key <- lists:seq(0, 3)]), 0] end,
    Written = fun() ->
                  Map = maps:from_list([{Key, Key} || Key <- lists:seq(0, 7)]),
                  [Map, Map]
              end,
    Successor = Ernest(successor),
    [Row("the loop alone", 20000000, loop_alone, loopAlone, fun() -> [7, 0] end),
     Row("a match over three constructors, a case", 20000000, matched, matched,
         fun() -> [{'Rectangle', 3, 4}, 0] end),
     Row("a match whose guards call functions, nested cases", 10000000, guarded, guarded,
         fun() -> [$x, 0] end),
     Row("a record updated, one field of four", 10000000, updated, updated,
         fun() -> [{'Account', 7, Text(<<"name">>), 100, true}] end),
     Row("a Float addition, +", 10000000, float_added, floatAdded,
         fun() -> [1.5, 2.25, 0.0] end),
     Row("a Float multiplication, *", 10000000, float_multiplied, floatMultiplied,
         fun() -> [1.5, 2.25, 0.0] end),
     Row("a Float expression of five operations, a dot product", 10000000, dotted, dotted,
         fun() -> [3.0] end),
     Row("an Int addition, +", 20000000, int_added, intAdded, fun() -> [3, 4, 0] end),
     Row("a derived compare of two fields, one by hand", 10000000, pair_compared,
         pairCompared, fun() -> [{'Pair', 1, 2}, {'Pair', 1, 3}, 'Equal'] end),
     Row("a requirement's compare at Int, a direct call", 10000000, required, required,
         fun() -> [3, 4, 0] end),
     Row("  compare at Int, with no requirement", 10000000, required, direct,
         fun() -> [3, 4, 0] end),
     Row("a String concatenation, a binary built", 10000000, appended, appended,
         fun() -> [Text(<<"ab">>), Text(<<"cd">>), <<>>] end),
     Row("String.slice, string:slice/3", 1000000, sliced, sliced,
         fun() -> [Text(<<"hello, world">>), <<>>] end),
     Row("  String.slice, binary:part/3, a slice of bytes", 1000000, parted, sliced,
         fun() -> [Text(<<"hello, world">>), <<>>] end),
     Row("Map.get, maps:get/3 with a default", 10000000, map_read, mapRead, Read),
     Row("Map.put, maps:put/3", 5000000, map_written, mapWritten, Written),
     Row("List.map over 100, lists:map/2", 100000, list_mapped, listMapped,
         fun() -> [lists:seq(1, 100), []] end),
     Row("a send to itself and a receive by a pattern", 2000000, messaged, messaged,
         fun() -> [0] end),
     Row("Io.show of a record of two Ints, io_lib:format ~p", 200000, shown, shown,
         fun() -> [{'Point', 1, 2}, <<>>] end),
     {"a function value called, a fun", 20000000,
      {Twin(applied), fun() -> [?TWIN:successor(), 0] end},
      {Ernest(applied), fun() -> [Successor(), 0] end}},
     Row("a lambda made, a fun of two captures", 10000000, made, made,
         fun() -> [5, fun(K) -> K end] end)].

%% The unit's function by its Ernest name, as a fun.
ernest_function(Unit, Name) ->
    {Function, Arity} = ern_code:function(Unit, ?NAMESPACE ++ [Name]),
    erlang:make_fun(Unit, Function, Arity).

%% The twin's function by its name, as a fun.
twin_function(Name) ->
    {Name, Arity} = lists:keyfind(Name, 1, ?TWIN:module_info(exports)),
    erlang:make_fun(?TWIN, Name, Arity).

%% One run of a row: the twin's loop and then Ernest's, each in a launch of
%% its own, in nanoseconds an iteration.
run({_, Count, Twin, Ernest}) ->
    {iterated(Twin, Count), iterated(Ernest, Count)}.

%% A loop of Count iterations of Function, over the operands Operands makes
%% in the launch's entry process, timed there.
iterated({Function, Operands}, Count) ->
    Measure = fun(Iterations) ->
                  Given = Operands(),
                  Started = erlang:monotonic_time(nanosecond),
                  _ = apply(Function, [Iterations | Given]),
                  (erlang:monotonic_time(nanosecond) - Started) / Iterations
              end,
    (ern_costs:launched(Measure))(Count).
