%% Plan, MVP 2.7, "Memory, read for what only grows": the load programs
%% under load/, each run by `ern run` in a node of its own, as `make load`
%% does, and the shell under a long session. A load does the same work
%% round after round and calls `mark(round)` after each, which collects
%% every process's garbage and samples the node. After the warm-up rounds
%% nothing may grow: not the atoms, the processes, the ports, the rows of
%% the runtime's tables or the persistent terms, which only a defect keeps,
%% and not the memory beyond the noise below. `make load` runs it (docs/review.md).
-module(ern_load).

-export([main/1, mark/1]).

%% The rounds before the first sample compared, in which caches and
%% process heaps settle.
-define(WARM, 6).

%% The noise within which memory counts as flat, between the mean of the
%% three samples after the warm-up and the mean of the last three:
%% measured at about 100 KB either way on loads that leak nothing, and
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
    Samples = [S || {_, S} <- ets:tab2list(ern_load_samples)],
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
     [[[[[I, "\n"] || I <- round_inputs(integer_to_list(K))] || K <- lists:seq(1, 12)],
       ":type f\n:bindings\n:doc List.map\n:faults\n",
       "mark(", integer_to_list(R), ")\n"]
      || R <- lists:seq(1, 14)]].

round_inputs(K) ->
    ["1 + " ++ K,
     "let x = [" ++ K ++ ", " ++ K ++ " + 1]",
     "fn f(n : Int) : Int = n * " ++ K,
     "List.map(x, f)",
     "type Shape = Circle(Int) | Square(Int)",
     "Circle(" ++ K ++ ")",
     "Io.println(\"line " ++ K ++ "\")",
     "let _ = spawn(Local, fn() : Unit with Never = Io.println(\"spawned\"))"].

%% Called by a load after each round, through a `foreign fn`. What the
%% round set ending, a killed process or a delivery of its `Down`, is given
%% a moment to end before the node is sampled.
-spec mark(integer()) -> 'Unit'.
mark(Round) ->
    timer:sleep(200),
    [erlang:garbage_collect(P) || P <- erlang:processes()],
    Own = ets:info(ern_load_samples, memory) * erlang:system_info(wordsize),
    ets:insert(ern_load_samples,
               {Round, #{round => Round,
                         memory => erlang:memory(total) - Own,
                         code => erlang:memory(code),
                         reaper => reaper_memory(),
                         atoms => erlang:system_info(atom_count),
                         processes => erlang:system_info(process_count),
                         ports => erlang:system_info(port_count),
                         rows => rows(ern_processes) + rows(ern_calls) + rows(ern_held),
                         terms => maps:get(count, persistent_term:info())}}),
    'Unit'.

%% The memory of the runtime's reaper, which holds every wait on a process
%% (report §6.9), after its garbage is collected. It is collected again just
%% before it is read: a message it took after the collection of every
%% process leaves its heap a size larger at the sample, a step of the
%% host's heap sizes that the next sample does not show.
reaper_memory() ->
    case persistent_term:get({ern_rt, reaper}, none) of
        none ->
            0;
        Pid ->
            erlang:garbage_collect(Pid),
            element(2, erlang:process_info(Pid, memory))
    end.

rows(Table) ->
    case ets:info(Table, size) of
        undefined -> 0;
        N -> N
    end.

%% What grew between the samples after the warm-up and the last ones:
%% a count, exactly, and the memory beyond the noise.
verdict(Samples) when length(Samples) < ?WARM + 6 ->
    [too_few_rounds];
verdict(Samples) ->
    Settled = lists:nthtail(?WARM, Samples),
    First = hd(Settled),
    Last = lists:last(Samples),
    Counts = [{K, maps:get(K, Last) - maps:get(K, First)}
              || K <- [code, atoms, processes, ports, rows, terms, reaper],
                 maps:get(K, Last) > maps:get(K, First)],
    Grown = mean(lists:nthtail(length(Settled) - 3, Settled)) - mean(lists:sublist(Settled, 3)),
    Counts ++ [{memory, Grown} || Grown > ?NOISE_BYTES].

mean(Samples) ->
    lists:sum([M || #{memory := M} <- Samples]) div length(Samples).

table(Name, Samples) ->
    [io_lib:format("~s~n~6s ~10s ~10s ~7s ~7s ~6s ~5s ~5s ~6s~n",
                   [Name, "round", "memory", "code", "reaper", "atoms", "procs", "ports", "rows",
                    "terms"])
     | [io_lib:format("~6B ~10B ~10B ~7B ~7B ~6B ~5B ~5B ~6B~n", [R, M, C, E, A, P, O, W, T])
        || #{round := R, memory := M, code := C, reaper := E, atoms := A, processes := P,
             ports := O, rows := W, terms := T} <- Samples]].
