%% Plan, MVP 2.7, "Memory, read for what only grows": the load programs
%% under load/, each run by `ern run` in a node of its own, as `make load`
%% does, and the shell under a long session. A load does the same work
%% round after round and calls `mark(round)` after each, which collects
%% every process's garbage and samples the node. After the warm-up rounds
%% nothing may grow: not the atoms, the processes, the ports, the rows of
%% the runtime's tables or the persistent terms, which only a defect keeps,
%% and not the memory beyond the noise below. `make load` runs it (docs/release_review.md).
-module(ern_load).

-export([main/1, mark/1]).

%% The rounds before the first sample compared, in which caches and
%% process heaps settle.
-define(WARM, 6).

%% The noise within which memory counts as flat, between the mean of the
%% three samples after the warm-up and the mean of the last three:
%% measured at about 15 KB either way on loads that leak nothing, and
%% small enough that a load of a few thousand operations after its warm-up
%% shows a leak of a hundred bytes an operation.
-define(NOISE_BYTES, 128 * 1024).

%% Runs one load, `Name` a program under load/ or `shell`, and halts with
%% status 0 if nothing grew and 1 otherwise, after printing its samples.
%% `inputs File` writes the shell's session, which `make load` gives it as
%% its standard input.
-spec main([string()]) -> no_return().
main(["inputs", File]) ->
    ok = file:write_file(File, inputs()),
    halt(0);
main([Name]) ->
    ets:new(ern_load_samples, [named_table, public, ordered_set]),
    Status = run(Name),
    Samples = [Sample || {_, Sample} <- ets:tab2list(ern_load_samples)],
    Verdict = case {Status, verdict(Samples)} of
                  {0, []} -> [Name, ": flat\n"];
                  {_, Grown} -> io_lib:format("~s: status ~p, grew: ~p~n", [Name, Status, Grown])
              end,
    %% the shell's session writes to standard output too, so the table is
    %% also a file of its own
    Report = [table(Name, Samples), Verdict],
    ok = file:write_file("build/load/" ++ Name ++ ".txt", Report),
    io:put_chars(Report),
    halt(case Verdict of [Name, _] -> 0; _ -> 1 end).

run("shell") ->
    ern_cli:ern(["shell"]);
run(Name) ->
    ern_cli:ern(["run", "build/load/" ++ Name ++ ".erc"]).

%% The shell's session: fourteen rounds of a hundred inputs, the same each
%% round, expressions, bindings and functions declared again, a program's
%% output, a process spawned, and the commands that read the session and
%% the documentation, each round ending in a mark.
inputs() ->
    ["foreign fn mark(round : Int) : Unit with m = \"ern_load:mark/1\"\n",
     [[[[[Input, "\n"] || Input <- round_inputs(integer_to_list(Step))]
        || Step <- lists:seq(1, 12)],
       ":type f\n:bindings\n:doc List.map\n:faults\n",
       "mark(", integer_to_list(Round), ")\n"]
      || Round <- lists:seq(1, 14)]].

round_inputs(Step) ->
    ["1 + " ++ Step,
     "let x = [" ++ Step ++ ", " ++ Step ++ " + 1]",
     "fn f(n : Int) : Int = n * " ++ Step,
     "List.map(x, f)",
     "type Shape = Circle(Int) | Square(Int)",
     "Circle(" ++ Step ++ ")",
     "Io.println(\"line " ++ Step ++ "\")",
     "let _ = spawn(fn() : Unit with Never = Io.println(\"spawned\"))"].

%% Called by a load after each round, through a `foreign fn`. What the
%% round set ending, a killed process or a delivery of its `Down`, is given
%% a moment to end before the node is sampled. The caller then waits while
%% a process of the harness's own samples the node: sampled by itself, the
%% caller would be mid-work.
-spec mark(integer()) -> 'Unit'.
mark(Round) ->
    timer:sleep(200),
    Caller = self(),
    Sampler = spawn(fun() -> Caller ! {self(), sample(Round)} end),
    receive
        {Sampler, Sample} -> ets:insert(ern_load_samples, {Round, Sample})
    end,
    'Unit'.

%% The node, every process but the sampler collected first, and the host
%% given a moment to count the heaps the collections freed. The memory is
%% what is in use: it leaves out the structures the host keeps for
%% processes to come, which it trims when it likes, the samples' own table,
%% the sampler, and the words of every heap that hold nothing.
sample(Round) ->
    Sampler = self(),
    Others = [Pid || Pid <- erlang:processes(), Pid =/= Sampler],
    [erlang:garbage_collect(Pid) || Pid <- Others],
    timer:sleep(100),
    Reaper = reaper_memory(),
    Unused = lists:sum([unused(Pid) || Pid <- Others]),
    Own = ets:info(ern_load_samples, memory) * erlang:system_info(wordsize)
          + element(2, erlang:process_info(Sampler, memory)),
    [{processes_used, Processes}, {system, System}] = erlang:memory([processes_used, system]),
    #{round => Round,
      memory => Processes + System - Own - Unused,
      code => erlang:memory(code),
      reaper => Reaper,
      atoms => erlang:system_info(atom_count),
      processes => erlang:system_info(process_count),
      ports => erlang:system_info(port_count),
      rows => rows(ern_processes) + rows(ern_calls) + rows(ern_faults) + rows(ern_held),
      terms => maps:get(count, persistent_term:info())}.

%% The bytes of a process's heaps that hold nothing. The host sizes a heap
%% by what the process held before its collection, garbage included, and
%% grows it a size at the next when what lives fills most of it, so the
%% same data sits in a heap of one size at one sample and of the next at
%% another, a step of over a hundred kilobytes in the shell's own process.
unused(Pid) ->
    case erlang:process_info(Pid, garbage_collection_info) of
        undefined ->
            0;
        {garbage_collection_info, Info} ->
            #{heap_block_size := Heap, heap_size := Used, stack_size := Stack,
              old_heap_block_size := Old, old_heap_size := OldUsed} = maps:from_list(Info),
            (Heap - Used - Stack + Old - OldUsed) * erlang:system_info(wordsize)
    end.

%% The memory the runtime's reaper holds, which holds every wait on a
%% process (report §6.9). It is collected again just before it is read: a
%% message it took after the collection of every process leaves words in
%% its heap that the next collection frees.
reaper_memory() ->
    case persistent_term:get({ern_rt, reaper}, none) of
        none ->
            0;
        Pid ->
            erlang:garbage_collect(Pid),
            element(2, erlang:process_info(Pid, memory)) - unused(Pid)
    end.

rows(Table) ->
    case ets:info(Table, size) of
        undefined -> 0;
        Size -> Size
    end.

%% What grew between the samples after the warm-up and the last ones:
%% a count, exactly, and the memory beyond the noise.
verdict(Samples) when length(Samples) < ?WARM + 6 ->
    [too_few_rounds];
verdict(Samples) ->
    Settled = lists:nthtail(?WARM, Samples),
    First = hd(Settled),
    Last = lists:last(Samples),
    Counts = [{Key, maps:get(Key, Last) - maps:get(Key, First)}
              || Key <- [code, atoms, processes, ports, rows, terms, reaper],
                 maps:get(Key, Last) > maps:get(Key, First)],
    Grown = mean(lists:nthtail(length(Settled) - 3, Settled)) - mean(lists:sublist(Settled, 3)),
    Counts ++ [{memory, Grown} || Grown > ?NOISE_BYTES].

mean(Samples) ->
    lists:sum([Memory || #{memory := Memory} <- Samples]) div length(Samples).

table(Name, Samples) ->
    [io_lib:format("~s~n~6s ~10s ~10s ~7s ~7s ~6s ~5s ~5s ~6s~n",
                   [Name, "round", "memory", "code", "reaper", "atoms", "procs", "ports", "rows",
                    "terms"])
     | [io_lib:format("~6B ~10B ~10B ~7B ~7B ~6B ~5B ~5B ~6B~n",
                      [Round, Memory, Code, Reaper, Atoms, Processes, Ports, Rows, Terms])
        || #{round := Round, memory := Memory, code := Code, reaper := Reaper, atoms := Atoms,
             processes := Processes, ports := Ports, rows := Rows, terms := Terms} <- Samples]].
