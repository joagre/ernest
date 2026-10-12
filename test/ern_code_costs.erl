%% `make bench`'s fourth part (docs/development.md), MVP 3.2's costs on
%% nodes of this machine (plan MVP 3.2 item 7): what a spawn and a compute
%% cost whose code crosses to a peer that lacks it, a bare node's first
%% among them, with what that first does in a fresh host, and the share of
%% each of the exchange's steps on both nodes (report §8.7, §10); what a
%% fix's callers cost, crossed with it to a node of the old build; what an
%% arrival, a `Code.load` and a development day's spawns add to the host's
%% four counts, against their limits (§11.2); what a utilisation costs, and
%% a compute on a peer the node picks by the loads its peers told it beside
%% one on a peer named, the pick alone and the read of the loads, and what
%% connected nodes exchange idle, the tellings among it (§8.7, plan MVP
%% 3.2 item 8); and the sizes of the
%% standard library's `.erc` files and of a code frame, and what reading a
%% module's forms costs (§11.1). Every number is a median of seven runs or
%% more, with their range.
%%
%% The measuring program, the reaches it spawns, the builds of the fixed
%% module and the modules `Code.load` loads are written here, built, and
%% run as a person runs them: seven bare nodes listening on ports the host
%% picks, a node of the fixed module's old build, and the measuring node,
%% which lists them all. The nodes show their work through
%% `bench/ern_code_probe.erl`, on each one's load path, whose functions the
%% measuring program runs on a peer by a compute of their names: the host's
%% trace of the exchange's steps, the runtime's reading of the host's
%% counts, and the host's counts of each connection's packets. It measures
%% and asserts nothing, so it is not part of `make test`.
-module(ern_code_costs).

-export([main/1]).

-include_lib("typer/include/ern_canonical.hrl").

-define(ERN, filename:absname("../bin/ern")).
-define(STDLIB, filename:absname("../build/stdlib")).
%% Each measurement's runs, the reaches' and the fixes' sizes in definitions,
%% the definitions of a development day, and the rounds a run of a
%% utilisation's or a compute's measurement times.
-define(RUNS, 7).
-define(SIZES, [1, 5, 20]).
-define(DAY, 200).
-define(ROUNDS, 200).
%% The bare nodes: t times spawns, c computes, p the exchange's steps and
%% the counts, d the day, l `Code.load`, q1 and q2 the picks and the idle
%% connections; each one's first spawn is a bare node's first.
-define(BARE, ["t", "c", "p", "d", "l", "q1", "q2"]).

%% Prints the tables, the nodes' directories and the programs under Dir,
%% and halts.
-spec main([string()]) -> no_return().
main([Dir]) ->
    Load = load(),
    _ = file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Base = filename:absname(Dir),
    {New, Old, Loads, Probe} = built(Base),
    {A, Ported} = Nodes = started(Base, Old, Probe),
    Lines = measured(Base, New, Loads, Probe, Nodes),
    stopped(Nodes),
    OnCarrier = maps:from_list([{"a", carrier_name(A)}
                              | [{Name, carrier_name(NodeDir)}
                                 || {Name, NodeDir, _, _} <- Ported]]),
    io:format("MVP 3.2's costs, on nodes of this machine, the load average before ~s on ~B"
              " processors~n", [Load, erlang:system_info(logical_processors_available)]),
    io:format("each a median of ~B runs, with their range~n", [?RUNS]),
    crossing_table(Lines),
    cold_table(),
    steps_table(Lines, New),
    lists:foreach(fun(Table) -> Table(Lines) end,
                  [fun fix_table/1, fun counts_table/1, fun pick_table/1]),
    idle_table(Lines, OnCarrier),
    sizes_table(Lines, New),
    halt(0).

%% The load average of the last minute, as ern_measure reads it: Linux's,
%% or the BSDs' and macOS's.
load() ->
    case file:read_file("/proc/loadavg") of
        {ok, Text} -> hd(string:lexemes(binary_to_list(Text), " "));
        _ -> hd(string:lexemes(os:cmd("sysctl -n vm.loadavg"), "{ "))
    end.

%%
%% The programs
%%

%% The measuring program and the modules it spawns from, the old build of
%% the fixed modules and the modules `Code.load` loads, each built, and the
%% probe's directory, which `make` compiles it into. A reach is spawned
%% from a module of about thirty definitions, as a program's are, but for
%% one module of four hundred, which shows what the module's size costs
%% the spawner's node.
built(Base) ->
    Probe = filename:absname("build/bench/probe"),
    [New, Old, Loads] = Dirs = [filename:join(Base, Name) || Name <- ["new", "old", "loads"]],
    [ok = filelib:ensure_path(Path) || Path <- Dirs],
    Variants = lists:seq(1, ?RUNS),
    Days = lists:seq(1, ?DAY div 20),
    Files = [{New, "costs", costs()}, {New, "reaches", reaches()},
             {New, "r0", reach_module(0, [{5, 0}])},
             {New, "big", big()}, {New, "days", days()},
             {New, "aside", aside()}, {Old, "aside", aside()},
             {New, "fixes", fixes()}, {Old, "serve", server()}]
        ++ [{New, "r" ++ integer_to_list(Variant),
             reach_module(Variant, [{Size, Variant} || Size <- ?SIZES])}
            || Variant <- Variants]
        ++ [{New, "day" ++ integer_to_list(Day), day(Day)} || Day <- Days]
        ++ [{Root, "fix" ++ integer_to_list(Chain), fix(Build, Chain)}
            || {Root, Build} <- [{New, new}, {Old, old}], Chain <- Variants]
        ++ [{Loads, "load" ++ integer_to_list(Index), loaded(Index)}
            || Index <- lists:seq(0, ?RUNS)],
    [ok = file:write_file(filename:join(Path, File ++ ".ern"), unicode:characters_to_binary(Text))
     || {Path, File, Text} <- Files],
    0 = ern_cli:ern(["build", New], group_leader()),
    0 = ern_cli:ern(["build", Old], group_leader()),
    0 = ern_cli:ern(["build", Loads], group_leader()),
    {New, Old, Loads, Probe}.

%% The measuring program: each scenario in turn, each line it prints a
%% scenario, a label and what it read.
costs() ->
    Runs = integer_to_list(?RUNS),
    ["// make bench's fourth part (test/ern_code_costs.erl): MVP 3.2's costs,\n"
     "// measured from a node that lists the peers its arguments name.\n"
     "\n"
     "foreign fn traced() : Unit with m = \"ern_code_probe:traced/0\"\n"
     "\n"
     "foreign fn steps() : List(String) with m = \"ern_code_probe:read/0\"\n"
     "\n"
     "foreign fn counts() : String with m = \"ern_code_probe:counts/0\"\n"
     "\n"
     "foreign fn window() : Unit with m = \"ern_code_probe:window/0\"\n"
     "\n"
     "foreign fn windowed() : List(String) with m = \"ern_code_probe:windowed/0\"\n"
     "\n"
     "foreign fn picks(count : Int) : Int with m = \"ern_code_probe:picks/1\"\n"
     "\n"
     "export fn main() : Unit with Never =\n"
     "    match Os.arguments {\n"
     "        [t, c, p, d, l, q1, q2, f, loads] -> {\n"
     "            firsts([t, c, p, d, l, q1, q2]);\n"
     "            crossing(\"spawn\", fn(size, variant) = Reaches.spawned(t, size, variant));\n"
     "            crossing(\"compute\", fn(size, variant) = Reaches.computed(c, size, variant));\n"
     "            traced();\n"
     "            probed(\"traced\", p, [1, 5, 20], fn(size, variant) =\n"
     "                Reaches.spawned(p, size, variant));\n"
     "            probed(\"big\", p, [5], fn(_, variant) = Big.spawned(p, variant));\n"
     "            probed(\"fix\", f, [1, 5, 20], fn(size, chain) =\n"
     "                Fixes.spawnTop(f, size, chain));\n"
     "            loading(l, loads);\n"
     "            day(d);\n"
     "            placing(q1);\n"
     "            idle(q1, q2)\n"
     "        }\n"
     "      | _ -> Unit\n"
     "    }\n"
     "\n"
     "// A line of words.\n"
     "fn said(words : List(String)) : Unit with m = Io.println(String.join(words, \" \"))\n"
     "\n"
     "// The microseconds f took, and what it answered.\n"
     "fn timed(f : () -> Either(Io.Error, a) with m) : #(Int, String) with m = {\n"
     "    let started = Clock.monotonicMicros();\n"
     "    let answer = f();\n"
     "    #(Clock.monotonicMicros() - started, outcome(answer))\n"
     "}\n"
     "\n"
     "fn timedSaid(scenario : String, label : String, f : () -> Either(Io.Error, a) with m)"
     " : Unit with m =\n"
     "    match timed(f) {\n"
     "        #(took, answer) -> said([scenario, label, Int.toString(took), answer])\n"
     "    }\n"
     "\n"
     "fn outcome(answer : Either(Io.Error, a)) : String =\n"
     "    match answer {\n"
     "        Right(_) -> \"Right\"\n"
     "      | Left(failure) -> Io.show(failure)\n"
     "    }\n"
     "\n"
     "// Report §8.7: a dial, timed by the first utilisation, and then a bare\n"
     "// node's first spawn, which builds the prelude's environment every\n"
     "// arrival links through, a reach of five, on each node.\n"
     "fn firsts(nodes : List(String)) : Unit with m =\n"
     "    List.forEach(nodes, fn(node) = {\n"
     "        timedSaid(\"dial\", node, fn() = Peer.utilisation(node, 30000));\n"
     "        timedSaid(\"first\", node, fn() = R0.spawned(node, 5))\n"
     "    })\n"
     "\n"
     "// Report §8.7, §10: each reach spawned or computed where the peer lacks\n"
     "// it, and again, where it holds it.\n"
     "fn crossing(scenario : String,\n"
     "            crossed : (Int, Int) -> Either(Io.Error, a) with m) : Unit with m =\n"
     "    List.forEach(List.range(1, ", Runs, "), fn(variant) =\n"
     "        List.forEach([1, 5, 20], fn(size) = {\n"
     "            let label = Int.toString(size);\n"
     "            timedSaid(scenario, \"first_\" <> label, fn() = crossed(size, variant));\n"
     "            timedSaid(scenario, \"held_\" <> label, fn() = crossed(size, variant))\n"
     "        }))\n"
     "\n"
     "// Report §8.7, §11.2: the exchange's steps on both nodes, and the host's\n"
     "// counts on the peer, around each spawn of what the peer lacks; the\n"
     "// probe's own functions cross first, and their steps are dropped.\n"
     "fn probed(scenario : String,\n"
     "          node : String,\n"
     "          sizes : List(Int),\n"
     "          spawned : (Int, Int) -> Either(Io.Error, Address(Never)) with m)"
     " : Unit with m = {\n"
     "    let _ = Peer.computeAt(node, traced, 30000);\n"
     "    let _ = Peer.computeAt(node, counts, 30000);\n"
     "    let _ = Peer.computeAt(node, steps, 30000);\n"
     "    let _ = Peer.computeAt(node, steps, 30000);\n"
     "    let _ = steps();\n"
     "    List.forEach(List.range(1, ", Runs, "), fn(variant) =\n"
     "        List.forEach(sizes, fn(size) = {\n"
     "            let label = Int.toString(size) <> \"_\" <> Int.toString(variant);\n"
     "            countsSaid(scenario <> \"_before\", label, node);\n"
     "            timedSaid(scenario, label, fn() = spawned(size, variant));\n"
     "            countsSaid(scenario <> \"_after\", label, node);\n"
     "            stepsSaid(scenario <> \"_receiver\", label,\n"
     "                      Peer.computeAt(node, steps, 30000));\n"
     "            stepsSaid(scenario <> \"_sender\", label, Right(steps()))\n"
     "        }))\n"
     "}\n"
     "\n"
     "fn countsSaid(scenario : String, label : String, node : String) : Unit with m =\n"
     "    match Peer.computeAt(node, counts, 30000) {\n"
     "        Right(text) -> said([scenario, label, text])\n"
     "      | Left(failure) -> said([scenario, label, \"failed\", Io.show(failure)])\n"
     "    }\n"
     "\n"
     "fn stepsSaid(scenario : String, label : String, read : Either(Io.Error, List(String)))"
     " : Unit with m =\n"
     "    match read {\n"
     "        Right(lines) -> List.forEach(lines, fn(line) = said([scenario, label, line]))\n"
     "      | Left(failure) -> said([scenario, label, \"failed\", Io.show(failure)])\n"
     "    }\n"
     "\n"
     "// Appendix E.28: a module of twenty definitions loaded on a bare node,\n"
     "// which holds its reach, the standard library, timed by the compute that\n"
     "// runs the load, and the host's counts around it; the loader crosses\n"
     "// with a first load, of load0.\n"
     "fn loading(node : String, loads : String) : Unit with m = {\n"
     "    let _ = Peer.computeAt(node, counts, 30000);\n"
     "    let _ = loadedOn(node, loads <> \"/load0.erc\");\n"
     "    List.forEach(List.range(1, ", Runs, "), fn(index) = {\n"
     "        let label = Int.toString(index);\n"
     "        countsSaid(\"load_before\", label, node);\n"
     "        timedSaid(\"load\", label, fn() = loadedOn(node, loads <> \"/load\" <> label"
     " <> \".erc\"));\n"
     "        countsSaid(\"load_after\", label, node)\n"
     "    })\n"
     "}\n"
     "\n"
     "fn loadedOn(node : String, path : String) : Either(Io.Error, Unit) with m =\n"
     "    match Peer.computeAt(node, fn() = Code.load(Path(path)), 30000) {\n"
     "        Right(loaded) -> loaded\n"
     "      | Left(failure) -> Left(failure)\n"
     "    }\n"
     "\n"
     "// Report §11.2: a development day's shape, distinct small definitions\n"
     "// spawned onto one bare node one after another, the host's counts read\n"
     "// before the first and after each.\n"
     "fn day(node : String) : Unit with m = {\n"
     "    let _ = Peer.computeAt(node, counts, 30000);\n"
     "    countsSaid(\"day_counts\", \"0\", node);\n"
     "    List.forEach(List.range(1, ", integer_to_list(?DAY), "), fn(index) = {\n"
     "        let label = Int.toString(index);\n"
     "        timedSaid(\"day\", label, fn() = Days.spawned(node, index));\n"
     "        countsSaid(\"day_counts\", label, node)\n"
     "    })\n"
     "}\n"
     "\n"
     "fn one() : Int = 1\n"
     "\n"
     "// Report §8.7: rounds of a utilisation, of a compute on a peer the node\n"
     "// picks by the loads its peers told it, of one on the peer named, of the\n"
     "// loads read, and of the pick alone, the read and the draw, each peer\n"
     "// holding `one` first, so that no compute carries code.\n"
     "fn placing(q1 : String) : Unit with m = {\n"
     "    List.forEach(Peer.peers(), fn(node) = {\n"
     "        let _ = Peer.computeAt(node, one, 30000);\n"
     "        Unit\n"
     "    });\n"
     "    List.forEach(List.range(1, ", Runs, "), fn(run) = {\n"
     "        let label = Int.toString(run);\n"
     "        rounds(\"utilisation\", label, fn() = {\n"
     "            let _ = Peer.utilisation(q1, 5000);\n"
     "            Unit\n"
     "        });\n"
     "        rounds(\"compute\", label, fn() = {\n"
     "            let _ = Peer.compute(one, 5000);\n"
     "            Unit\n"
     "        });\n"
     "        rounds(\"compute_at\", label, fn() = {\n"
     "            let _ = Peer.computeAt(q1, one, 5000);\n"
     "            Unit\n"
     "        });\n"
     "        rounds(\"loads\", label, fn() = {\n"
     "            let _ = Peer.loads();\n"
     "            Unit\n"
     "        });\n"
     "        said([\"pick\", label, Int.toString(picks(", integer_to_list(?ROUNDS), "))])\n"
     "    })\n"
     "}\n"
     "\n"
     "fn rounds(scenario : String, label : String, f : () -> Unit with m) : Unit with m = {\n"
     "    let started = Clock.monotonicMicros();\n"
     "    List.forEach(List.range(1, ", integer_to_list(?ROUNDS), "), fn(_) = f());\n"
     "    said([scenario, label, Int.toString(Clock.monotonicMicros() - started)])\n"
     "}\n"
     "\n"
     "// Report §8.7: three nodes connected each to the other two, q1 dialling\n"
     "// q2, left idle over a window each opens, this node's last, so that the\n"
     "// computes that open the others' fall outside its own; then what crossed\n"
     "// each connection, read once every window has closed.\n"
     "fn idle(q1 : String, q2 : String) : Unit with m = {\n"
     "    let _ = Peer.computeAt(q1, utilisationOfQ2, 30000);\n"
     "    let _ = Peer.computeAt(q1, window, 30000);\n"
     "    let _ = Peer.computeAt(q2, window, 30000);\n"
     "    window();\n"
     "    List.forEach(windowed(), fn(line) = said([\"idle\", \"a\", line]));\n"
     "    List.forEach([q1, q2], fn(node) =\n"
     "        stepsSaid(\"idle\", node, Peer.computeAt(node, windowed, 30000)))\n"
     "}\n"
     "\n"
     "fn utilisationOfQ2() : Either(Io.Error, Float) with m = Peer.utilisation(\"q2\", 5000)\n"].

%% The module that spawns or computes a reach by its variant, from the
%% module that holds it.
reaches() ->
    ["// make bench's fourth part (test/ern_code_costs.erl): each reach by its\n"
     "// variant.\n"
     "\n",
     [io_lib:format("export fn ~s(peer : String, size : Int, variant : Int)"
                    " : Either(Io.Error, ~s) with m =~n"
                    "    match variant {~n~s"
                    "      | _ -> Left(Io.Invalid)~n"
                    "    }~n~n",
                    [Name, Answer,
                     lists:join("      | ",
                                [io_lib:format("~B -> R~B.~s(peer, size)~n",
                                               [Variant, Variant, Name])
                                 || Variant <- lists:seq(1, ?RUNS)])])
      || {Name, Answer} <- [{"spawned", "Address(Never)"}, {"computed", "Unit"}]]].

%% A module of the reaches of one variant, each a chain whose first
%% definition is the function spawned, with the functions that spawn and
%% compute one by its size, a form naming its function where it is written
%% (report §3.11).
reach_module(Variant, Reaches) ->
    ["// make bench's fourth part (test/ern_code_costs.erl): reaches of one\n"
     "// variant, which the measuring program spawns onto peers that lack them.\n"
     "\n",
     [chain(Size, Variant) || {Size, _} <- Reaches],
     dispatch("spawned", "size", "Address(Never)", "Peer.spawn",
              [{integer_to_list(Size), reach_name(Size, Variant, 1)} || {Size, _} <- Reaches]),
     dispatch("computed", "size", "Unit", "Peer.computeAt",
              [{integer_to_list(Size), reach_name(Size, Variant, 1)} || {Size, _} <- Reaches])].

%% A reach of Size definitions, each named for its size, its variant and
%% its place, distinct from every other by a constant of its own, each
%% calling the next and folding with a lambda.
chain(Size, Variant) ->
    [begin
         Constant = Size * 10000 + Variant * 100 + Place,
         Fold = io_lib:format("List.foldLeft([~s, ~B], 0, fn(acc, y) = acc + y)",
                              [case Place of 1 -> "1"; _ -> "x" end, Constant]),
         Next = case Place < Size of
                    true -> [" + ", reach_name(Size, Variant, Place + 1),
                             case Place of 1 -> "(1)"; _ -> "(x)" end];
                    false -> ""
                end,
         case Place of
             1 -> io_lib:format("fn ~s() : Unit with Never = {~n    let _ = ~s~s;~n    Unit~n}~n~n",
                                [reach_name(Size, Variant, 1), Fold, Next]);
             _ -> io_lib:format("fn ~s(x : Int) : Int =~n    ~s~s~n~n",
                                [reach_name(Size, Variant, Place), Fold, Next])
         end
     end || Place <- lists:seq(1, Size)].

reach_name(Size, Variant, Place) ->
    io_lib:format("r~Bv~Bd~B", [Size, Variant, Place]).

%% A function that spawns or computes, on the peer it is given, the function
%% of the case its argument names.
dispatch(Name, Parameter, Answer, Form, Cases) ->
    [io_lib:format("export fn ~s(peer : String, ~s : Int) : Either(Io.Error, ~s) with m =~n"
                   "    match ~s {~n", [Name, Parameter, Answer, Parameter]),
     lists:join("      | ", [io_lib:format("~s -> ~s(peer, ~s, 30000)~n", [Case, Form, Function])
                             || {Case, Function} <- Cases]),
     "      | _ -> Left(Io.Invalid)\n",
     "    }\n\n"].

%% A module of four hundred definitions beside a reach of five of each
%% variant.
big() ->
    ["// make bench's fourth part (test/ern_code_costs.erl): reaches of five in\n"
     "// a module of four hundred definitions more.\n"
     "\n",
     [io_lib:format("export fn filler~B(x : Int) : Int =~n"
                    "    List.foldLeft([x, ~B], 0, fn(acc, y) = acc + y)~n~n", [Place, Place])
      || Place <- lists:seq(1, 400)],
     [chain(5, 10 + Variant) || Variant <- lists:seq(1, ?RUNS)],
     dispatch("spawned", "variant", "Address(Never)", "Peer.spawn",
              [{integer_to_list(Variant), reach_name(5, 10 + Variant, 1)}
               || Variant <- lists:seq(1, ?RUNS)])].

%% The development day's small definitions, twenty to a module, each with a
%% lambda, and the module that spawns one by its index.
days() ->
    ["// make bench's fourth part (test/ern_code_costs.erl): a day's definitions\n"
     "// by their index.\n"
     "\n"
     "export fn spawned(peer : String, index : Int) : Either(Io.Error, Address(Never)) with m =\n"
     "    match (index - 1) / 20 {\n",
     lists:join("      | ", [io_lib:format("~B -> Day~B.spawned(peer, index)~n", [Day - 1, Day])
                             || Day <- lists:seq(1, ?DAY div 20)]),
     "      | _ -> Left(Io.Invalid)\n"
     "    }\n"].

day(Day) ->
    Indexes = lists:seq(Day * 20 - 19, Day * 20),
    ["// make bench's fourth part (test/ern_code_costs.erl): twenty of a day's\n"
     "// definitions.\n"
     "\n",
     [io_lib:format("fn day~B() : Unit with Never = {~n"
                    "    let _ = List.map([~B], fn(x) = x + ~B);~n"
                    "    Unit~n"
                    "}~n~n", [Index, Index, Index])
      || Index <- Indexes],
     dispatch("spawned", "index", "Address(Never)", "Peer.spawn",
              [{integer_to_list(Index), "day" ++ integer_to_list(Index)} || Index <- Indexes])].

%% What no fix changes, which every caller calls.
aside() ->
    "// make bench's fourth part (test/ern_code_costs.erl): what no fix changes.\n"
    "\n"
    "export fn aside(x : Int) : Int = x * 2\n".

%% A fixed module of the old build or the new: for each size a leaf, which
%% the new build changes, and as many callers as the size, each calling
%% the one before with a lambda over `aside`, which neither build changes;
%% the last caller is the function spawned.
fix(Build, Chain) ->
    Changed = case Build of
                  old -> 0;
                  new -> 1
              end,
    ["// make bench's fourth part (test/ern_code_costs.erl): leaves a fix\n"
     "// changes, and the callers whose hashes change with them.\n"
     "\n",
     [[io_lib:format("fn ~s(x : Int) : Int = x + ~B~n~n",
                     [fix_name(Size, Chain, 0), Size * 1000 + Chain * 10 + Changed]),
       [io_lib:format("fn ~s(x : Int) : Int =~n"
                      "    List.foldLeft([~s(x)], ~B, fn(acc, y) = Aside.aside(acc + y))~n~n",
                      [fix_name(Size, Chain, Place), fix_name(Size, Chain, Place - 1), Place])
        || Place <- lists:seq(1, Size - 1)],
       io_lib:format("fn ~s() : Unit with Never = {~n    let _ = ~s(1);~n    Unit~n}~n~n",
                     [fix_name(Size, Chain, Size), fix_name(Size, Chain, Size - 1)])]
      || Size <- ?SIZES],
     dispatch("spawnTop", "size", "Address(Never)", "Peer.spawn",
              [{integer_to_list(Size), fix_name(Size, Chain, Size)} || Size <- ?SIZES])].

%% Place 0 is the leaf, and the size's place the function spawned.
fix_name(Size, Chain, Place) ->
    io_lib:format("fix~Bc~Bp~B", [Size, Chain, Place]).

%% The module that spawns a fix's last caller by its chain.
fixes() ->
    ["// make bench's fourth part (test/ern_code_costs.erl): each fix by its\n"
     "// chain.\n"
     "\n"
     "export fn spawnTop(peer : String, size : Int, chain : Int)"
     " : Either(Io.Error, Address(Never)) with m =\n"
     "    match chain {\n",
     lists:join("      | ", [io_lib:format("~B -> Fix~B.spawnTop(peer, size)~n", [Chain, Chain])
                             || Chain <- lists:seq(1, ?RUNS)]),
     "      | _ -> Left(Io.Invalid)\n"
     "    }\n"].

%% The old build's node, which holds the old fixed modules and waits for
%% what is spawned on it.
server() ->
    "// make bench's fourth part (test/ern_code_costs.erl): the node of the old\n"
    "// build, which reads the fixed modules from its load path at its start.\n"
    "\n"
    "export fn main() : Unit with Unit = {\n"
    "    Io.println(\"serving\");\n"
    "    held()\n"
    "}\n"
    "\n"
    "fn held() : Unit with Unit = receive { _ -> held() }\n".

%% A module `Code.load` loads: a type, a binding and twenty functions, each
%% with a lambda, distinct from every other module's by its index.
loaded(Index) ->
    ["// make bench's fourth part (test/ern_code_costs.erl): a module Code.load\n"
     "// loads on a bare node.\n"
     "\n",
     io_lib:format("export type Shape = Square(Int) | Circle(Int)~n~n"
                   "let base : Int = ~B~n~n", [Index]),
     [io_lib:format("export fn f~B(x : Int) : Int =~n"
                    "    List.foldLeft([x, ~B], base, fn(acc, y) = acc + y + ~B)~n~n",
                    [Place, Place, Index * 100 + Place])
      || Place <- lists:seq(1, 20)]].

%%
%% The nodes
%%

%% The bare nodes and the old build's node started, each listening on a port
%% the host picks and listing the measuring node, `a`, whose configuration
%% lists them all; q1 and q2 list each other. Answers each node's name,
%% directory, port and process, the measuring node's directory first.
started(Base, Old, Probe) ->
    A = configured(Base, "a", none),
    Bare = [{Name, configured(Base, Name, 0)} || Name <- ?BARE],
    F = configured(Base, "f", 0),
    [listed(Dir, [{"a", A, none}]) || {_, Dir} <- [{"f", F} | Bare]],
    Running = [launched(Name, Dir, [?ERN, " run --config-dir ", Dir, " --load-path ", Probe])
               || {Name, Dir} <- Bare]
        ++ [launched("f", F, [?ERN, " run --config-dir ", F, " --load-path ", Probe, " ",
                              filename:join(Old, "serve.erc")])],
    Ported = [{Name, Dir, port_bound(Reader), Reader} || {Name, Dir, Reader} <- Running],
    Port = fun(Name) -> hd([Bound || {Named, _, Bound, _} <- Ported, Named =:= Name]) end,
    Dir = fun(Name) -> hd([Path || {Named, Path, _, _} <- Ported, Named =:= Name]) end,
    %% q1 and q2 dial each other for the idle window; the listing holds from
    %% their next dial, which a reload reads
    listed(Dir("q1"), [{"a", A, none}, {"q2", Dir("q2"), Port("q2")}]),
    listed(Dir("q2"), [{"a", A, none}, {"q1", Dir("q1"), Port("q1")}]),
    [reloaded(Dir(Name), Reader)
     || {Name, _, _, Reader} <- Ported, lists:member(Name, ["q1", "q2"])],
    listed(A, [{Name, Path, Bound} || {Name, Path, Bound, _} <- Ported]),
    {A, Ported}.

configured(Base, Name, Listen) ->
    Dir = filename:join([Base, "nodes", Name]),
    _ = ern_node:create(Dir),
    edit(Dir, fun(Conf) ->
                  case Listen of
                      none -> maps:remove(<<"listen">>, Conf);
                      Port -> Conf#{<<"listen">> => address(Port)}
                  end
              end),
    Dir.

address(Port) ->
    list_to_binary("127.0.0.1:" ++ integer_to_list(Port)).

edit(Dir, Change) ->
    File = filename:join(Dir, "ernest.conf"),
    {ok, Text} = file:read_file(File),
    ok = file:write_file(File, json:encode(Change(json:decode(Text)))).

public(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    maps:get(<<"public-key">>, json:decode(Text)).

%% A node's name on the carrier, which the host's counts of its connections
%% name it by (report §8.7).
carrier_name(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    atom_to_list(ern_carrier:name(Der)).

%% Dir lists each of Peers, {Name, PeerDir, Port}, a port or none.
listed(Dir, Peers) ->
    edit(Dir, fun(Conf) ->
                  Conf#{<<"peers">> => [peer(Name, PeerDir, Port)
                                        || {Name, PeerDir, Port} <- Peers]}
              end).

peer(Name, Dir, none) ->
    #{<<"name">> => list_to_binary(Name), <<"public-key">> => public(Dir)};
peer(Name, Dir, Port) ->
    (peer(Name, Dir, none))#{<<"network-address">> => address(Port)}.

%% A node started by the command Words, its standard output and standard
%% error read by a process of its own, which keeps them so that the node
%% never waits on a full pipe.
launched(Name, Dir, Words) ->
    Command = lists:flatten(["exec ", Words, " 2>&1"]),
    Self = self(),
    Reader = spawn(fun() ->
                       Port = open_port({spawn_executable, "/bin/sh"},
                                        [{args, ["-c", Command]}, binary, exit_status]),
                       Self ! {self(), opened},
                       read(Port, <<>>, [])
                   end),
    receive {Reader, opened} -> {Name, Dir, Reader} end.

%% The reader keeps what the node said, and who waits for a pattern in it
%% or for its end.
read(Port, Said, Waiting) ->
    receive
        {Port, {data, Bytes}} ->
            Said1 = <<Said/binary, Bytes/binary>>,
            read(Port, Said1, [Wait || Wait <- Waiting, not told(Said1, Wait)]);
        {Port, {exit_status, Status}} ->
            [From ! {self(), ended, Status, Said} || {_, From} <- Waiting],
            ended(Status, Said);
        {waiting, Pattern, From} ->
            case told(Said, {Pattern, From}) of
                true -> read(Port, Said, Waiting);
                false -> read(Port, Said, [{Pattern, From} | Waiting])
            end;
        {ended, From} ->
            read(Port, Said, [{ended, From} | Waiting])
    end.

told(_, {ended, _}) ->
    false;
told(Said, {Pattern, From}) ->
    case re:run(Said, Pattern, [{capture, all_but_first, list}]) of
        {match, Captured} -> From ! {self(), seen, Captured}, true;
        nomatch -> false
    end.

ended(Status, Said) ->
    receive
        {waiting, _, From} -> From ! {self(), ended, Status, Said};
        {ended, From} -> From ! {self(), ended, Status, Said}
    end,
    ended(Status, Said).

%% Until the node's output matches Pattern; answers what it captured, or
%% fails with what the node said where it ended first.
seen(Reader, Pattern) ->
    Reader ! {waiting, Pattern, self()},
    receive
        {Reader, seen, Captured} -> Captured;
        {Reader, ended, Status, Said} -> erlang:error({ended, Status, Said})
    end.

%% Report §8.7: the port a node whose `listen` names port 0 bound, once it
%% says so.
port_bound(Reader) ->
    [Port] = seen(Reader, "listening on port ([0-9]+)"),
    list_to_integer(Port).

%% Report §8.7, §11.2: a node sent hangup reads `ernest.conf` again, and
%% says so.
reloaded(Dir, Reader) ->
    "" = os:cmd(lists:flatten([?ERN, " reload --config-dir ", Dir])),
    _ = seen(Reader, "ernest.conf was read again"),
    ok.

%% Each node ended by termination, once the measuring program has ended.
stopped({_, Ported}) ->
    [begin
         _ = os:cmd(lists:flatten([?ERN, " stop --config-dir ", Dir])),
         Reader ! {ended, self()},
         receive {Reader, ended, _, _} -> ok end
     end || {_, Dir, _, Reader} <- Ported].

%% The measuring program run on its node, `a`, which lists them all: its
%% lines, each split into its words.
measured(Base, New, Loads, Probe, {A, _}) ->
    Names = ?BARE ++ ["f"],
    Command = lists:flatten([?ERN, " run --config-dir ", A,
                             " --load-path ", Probe, " ", filename:join(New, "costs.erc"),
                             [[" ", Name] || Name <- Names], " ", Loads,
                             " 2> ", filename:join(Base, "a.err")]),
    Said = os:cmd(Command),
    [string:lexemes(Line, " ") || Line <- string:lexemes(Said, "\n")].

%%
%% The tables
%%

%% The lines of Scenario, each its label and the rest of its words.
lines(Scenario, Lines) ->
    [{Label, Rest} || [Named, Label | Rest] <- Lines, Named =:= Scenario].

%% The microseconds of the timed lines of Scenario whose label is Label,
%% each of which must have answered Right.
timings(Scenario, Label, Lines) ->
    [checked(Scenario, Label, Micros, Outcome)
     || {Named, [Micros | Outcome]} <- lines(Scenario, Lines), Named =:= Label].

checked(_, _, Micros, ["Right"]) ->
    list_to_integer(Micros);
checked(Scenario, Label, _, Outcome) ->
    erlang:error({failed, Scenario, Label, lists:join(" ", Outcome)}).

%% The median of Values, the lowest and the highest.
median(Values) ->
    Sorted = lists:sort(Values),
    Count = length(Sorted),
    Median = case Count rem 2 of
                 1 -> lists:nth(Count div 2 + 1, Sorted);
                 0 -> (lists:nth(Count div 2, Sorted) + lists:nth(Count div 2 + 1, Sorted)) / 2
             end,
    {Median, hd(Sorted), lists:last(Sorted)}.

row(Name, []) ->
    io:format("~-52ts ~12s~n", [Name, "none"]);
row(Name, Values) ->
    {Median, Low, High} = median(Values),
    io:format("~-52ts ~12s  ~s to ~s~n", [Name, number(Median), number(Low), number(High)]).

number(Value) when is_integer(Value) -> integer_to_list(Value);
number(Value) when Value == round(Value) -> integer_to_list(round(Value));
number(Value) -> float_to_list(Value, [{decimals, 1}]).

heading(Text, Unit) ->
    io:format("~n~-52ts ~12s  range~n", [Text, Unit]).

%% Report §8.7, §10: a spawn and a compute whose reach crosses, against one
%% the peer holds; a bare node's first.
crossing_table(Lines) ->
    heading("a spawn or a compute onto a bare node", "µs"),
    row("a dial, by the first utilisation",
        [checked("dial", Node, Micros, Outcome)
         || {Node, [Micros | Outcome]} <- lines("dial", Lines)]),
    row("a bare node's first spawn, a reach of 5",
        [checked("first", Node, Micros, Outcome)
         || {Node, [Micros | Outcome]} <- lines("first", Lines)]),
    lists:foreach(
      fun(Scenario) ->
          lists:foreach(
            fun(Size) ->
                Text = integer_to_list(Size),
                row(io_lib:format("~s, a reach of ~B, crossing", [Scenario, Size]),
                    timings(Scenario, "first_" ++ Text, Lines)),
                row(io_lib:format("~s, a reach of ~B, held", [Scenario, Size]),
                    timings(Scenario, "held_" ++ Text, Lines))
            end, ?SIZES)
      end, ["spawn", "compute"]).

%% Report §8.7: what a bare node's first arrival does that no later one
%% does, each in a host of its own started as `ern run` starts one: the
%% prelude's environment built, which the exchange keeps for the node's
%% life, and the host's compiler run once, its modules loaded, beside a
%% second run.
cold_table() ->
    Tree = filename:absname(".."),
    Eval = "Forms = fun(Name) -> [{attribute, 1, module, Name}, {attribute, 1, export, [{f, 0}]},"
           " {function, 1, f, 0, [{clause, 1, [], [], [{atom, 1, ok}]}]}] end,"
           " {Prelude, _} = timer:tc(fun ern_typecheck:prelude_env/0),"
           " {Cold, {ok, _, _}} = timer:tc(fun() -> ern_compile:compiled(Forms(cold), []) end),"
           " {Warm, {ok, _, _}} = timer:tc(fun() -> ern_compile:compiled(Forms(warm), []) end),"
           " io:format(\"~B ~B ~B~n\", [Prelude, Cold, Warm]), halt().",
    Command = lists:flatten(["erl +B -boot no_dot_erlang -noshell -noinput -pa ",
                             filename:join(Tree, "erl/*/ebin"), " ", ?STDLIB, " -eval '", Eval,
                             "'"]),
    Runs = [[list_to_integer(Word) || Word <- string:lexemes(os:cmd(Command), " \n")]
            || _ <- lists:seq(1, ?RUNS)],
    heading("a bare node's first arrival, in a fresh host", "µs"),
    row("the prelude's environment built", [Prelude || [Prelude, _, _] <- Runs]),
    row("the host's compiler, its first run", [Cold || [_, Cold, _] <- Runs]),
    row("  its second", [Warm || [_, _, Warm] <- Runs]).

%% Report §8.7: the share of each of the exchange's steps in a spawn whose
%% reach crosses, from the steps the probe saw on both nodes.
steps_table(Lines, New) ->
    heading("the exchange's steps in a spawn that crosses", "µs"),
    lists:foreach(fun(Size) ->
                      steps_rows("traced", Size, Lines,
                                 io_lib:format("a reach of ~B, from a module of ~B definitions",
                                               [Size, definitions(New, "r1.erc")]))
                  end, ?SIZES),
    steps_rows("big", 5, Lines, io_lib:format("a reach of 5, from a module of ~B definitions",
                                              [definitions(New, "big.erc")])).

%% The definitions a module's `.erc` records.
definitions(Root, File) ->
    {ok, Bytes} = file:read_file(filename:join(Root, File)),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Bytes),
    length(Definitions).

steps_rows(Scenario, Size, Lines, Title) ->
    Runs = [shares(Scenario, Label, Lines) || Label <- labels(Scenario, Size, Lines)],
    io:format("~s~n", [Title]),
    [row("  " ++ Name, [maps:get(Key, Run) || Run <- Runs])
     || {Key, Name} <- [{total, "the spawn, as the spawner times it"},
                        {outside, "  the spawn's frame and its answer"},
                        {request, "  the request for the reach and its answer"},
                        {reach_answer, "    the spawner's node answering it"},
                        {lacks, "  the lacks and the code frames' way"},
                        {code_frames, "    the spawner's node making the frames"},
                        {verify, "  the code frames read and verified"},
                        {link, "  the arrival linked"},
                        {emit, "  emitted"},
                        {compile, "  compiled by the host"},
                        {load, "  loaded"},
                        {table, "  in the code table"},
                        {limits, "  the host's limits read"},
                        {start, "  the process started and answered"},
                        {definitions, "definitions that crossed"},
                        {frames, "code frames"},
                        {bytes, "bytes of the code frames"}]].

%% The labels of Scenario's runs of Size, `size_variant`.
labels(Scenario, Size, Lines) ->
    Prefix = integer_to_list(Size) ++ "_",
    lists:usort([Label || {Label, _} <- lines(Scenario, Lines),
                          lists:prefix(Prefix, Label)]).

%% One run's shares, from the receiver's steps, the sender's, and the
%% spawner's time: the spawn's frame and its answer are what the receiver's
%% exchange does not hold, from the spawn to the request; the request and
%% the lacks each a round trip, with the frames' way and the spawner's
%% work; the rest each step's span to the next.
shares(Scenario, Label, Lines) ->
    [Total] = timings(Scenario, Label, Lines),
    Receiver = [step(Words) || {Named, Words} <- lines(Scenario ++ "_receiver", Lines),
                               Named =:= Label],
    Sender = [step(Words) || {Named, Words} <- lines(Scenario ++ "_sender", Lines),
                             Named =:= Label],
    At = fun(Function) ->
             hd([Time || {Time, call, Called, _} <- Receiver, Called =:= Function])
         end,
    Asked = At("ern_exchange:asked/4"),
    Reached = hd([Time || {Time, call, "ern_exchange:frame/3", ["reach"]} <- Receiver]),
    Kept = hd([Time || {Time, call, "ern_exchange:kept/3", _} <- Receiver, Time > Reached]),
    CodeFrames = [{Time, Extra} || {Time, call, "ern_exchange:frame/3", ["code_frame" | _] = Extra}
                                       <- Receiver],
    FirstFrame = element(1, hd(CodeFrames)),
    Completed = At("ern_exchange:completed/3"),
    %% each code frame from its reading to its keeping, or to the reach's
    %% completion
    Ends = [Time || {Time, call, Called, _} <- Receiver,
                    Called =:= "ern_exchange:kept/3" orelse Called =:= "ern_exchange:completed/3",
                    Time >= FirstFrame],
    Verify = lists:sum([hd([End || End <- Ends, End >= Time]) - Time || {Time, _} <- CodeFrames]),
    Outcome = At("ern_gateway:outcome/2"),
    [Received] = [list_to_integer(Count)
                  || {_, call, "ern_arrival:received/5", [Count]} <- Receiver],
    Spans = fun(From, To) -> At(To) - At(From) end,
    #{total => Total,
      outside => Total - (Outcome - Asked),
      request => Reached - Asked,
      reach_answer => returned("ern_exchange:reach_answer/2", Sender),
      lacks => (Completed - Kept) - Verify,
      code_frames => returned("ern_exchange:code_frames/1", Sender),
      verify => Verify,
      link => Spans("ern_arrival:received/5", "ern_emitter:unit/1"),
      emit => Spans("ern_emitter:unit/1", "ern_compile:compiled/2"),
      compile => Spans("ern_compile:compiled/2", "code:atomic_load/1"),
      load => Spans("code:atomic_load/1", "ern_code:loaded/3"),
      table => Spans("ern_code:loaded/3", "ern_cli:say_limits/0"),
      limits => Spans("ern_cli:say_limits/0", "ern_exchange:started/1"),
      start => Outcome - At("ern_exchange:started/1"),
      definitions => Received,
      frames => length(CodeFrames),
      bytes => lists:sum([list_to_integer(Bytes) + list_to_integer(Sources)
                          || {_, ["code_frame", _, Bytes, _, Sources]} <- CodeFrames])}.

step([Time, Kind, Function | Extra]) ->
    {list_to_integer(Time), list_to_atom(Kind), Function, Extra}.

%% The microseconds of the sender's steps of Function, each from its call
%% to its return.
returned(Function, Sender) ->
    Calls = [Time || {Time, call, Called, _} <- Sender, Called =:= Function],
    Returns = [Time || {Time, return, Called, _} <- Sender, Called =:= Function],
    lists:sum(Returns) - lists:sum(Calls).

%% Report §8.7, §10: a fix whose callers' hashes changed with it, spawned
%% onto a node of the old build: the time, and what crossed.
fix_table(Lines) ->
    heading("a fix and its callers, onto a node of the old build", "µs"),
    lists:foreach(
      fun(Size) ->
          Runs = [shares("fix", Label, Lines) || Label <- labels("fix", Size, Lines)],
          row([fixed(Size), ", the spawn"], [maps:get(total, Run) || Run <- Runs]),
          row("  compiled by the host", [maps:get(compile, Run) || Run <- Runs]),
          row("  definitions that crossed", [maps:get(definitions, Run) || Run <- Runs]),
          row("  bytes of the code frames", [maps:get(bytes, Run) || Run <- Runs])
      end, ?SIZES).

%% A fix's row's name, by its callers.
fixed(1) -> "a fix and its caller";
fixed(Size) -> io_lib:format("a fix and its ~B callers", [Size]).

%% Report §11.2: what an arrival, a load and a day's spawns add to the host's
%% four counts, and how many such days a bare node lives before four fifths
%% of the first count it nears.
counts_table(Lines) ->
    Limits = [{atom_to_list(Table), Limit} || {Table, _, Limit} <- ern_code:counts()],
    heading("the host's counts an arrival adds", "entries"),
    lists:foreach(
      fun(Size) ->
          Added = [added("traced", Label, Lines) || Label <- labels("traced", Size, Lines)],
          [row(io_lib:format("a reach of ~B, ~s", [Size, Table]),
               [proplists:get_value(Table, Run) || Run <- Added])
           || {Table, _} <- Limits]
      end, ?SIZES),
    lists:foreach(
      fun(Size) ->
          Added = [added("fix", Label, Lines) || Label <- labels("fix", Size, Lines)],
          [row([fixed(Size), ", ", Table], [proplists:get_value(Table, Run) || Run <- Added])
           || {Table, _} <- Limits]
      end, ?SIZES),
    Loads = [Label || {Label, _} <- lines("load", Lines)],
    row("Code.load of twenty definitions, the compute, µs",
        [Micros || Label <- Loads, Micros <- timings("load", Label, Lines)]),
    [row("Code.load of twenty definitions, " ++ Table,
         [proplists:get_value(Table, added("load", Label, Lines)) || Label <- Loads])
     || {Table, _} <- Limits],
    Day = [counted(Words) || {_, Words} <- lines("day_counts", Lines)],
    Spawns = [Micros || Index <- lists:seq(1, ?DAY),
                        Micros <- timings("day", integer_to_list(Index), Lines)],
    row("a day's spawn of a small definition, µs", Spawns),
    PerSpawn = [[{Table, After - Before} || {{Table, Before}, {_, After}} <- lists:zip(One, Two)]
                || {One, Two} <- lists:zip(lists:droplast(Day), tl(Day))],
    [row("  a day's spawn, " ++ Table, [proplists:get_value(Table, Run) || Run <- PerSpawn])
     || {Table, _} <- Limits],
    First = hd(Day),
    Last = lists:last(Day),
    io:format("~na day of ~B spawns, onto a bare node that used, before the first:~n", [?DAY]),
    [begin
         Used = proplists:get_value(Table, First),
         PerDay = proplists:get_value(Table, Last) - Used,
         Days = case PerDay of
                    0 -> "never";
                    _ -> integer_to_list((Limit * 4 div 5 - Used) div PerDay)
                end,
         io:format("  ~-14s ~9B of ~9B, ~7B a day, days to four fifths: ~s~n",
                   [Table, Used, Limit, PerDay, Days])
     end || {Table, Limit} <- Limits].

%% The counts Scenario's run Label added, table by table.
added(Scenario, Label, Lines) ->
    [Before] = [counted(Words) || {Named, Words} <- lines(Scenario ++ "_before", Lines),
                                  Named =:= Label],
    [After] = [counted(Words) || {Named, Words} <- lines(Scenario ++ "_after", Lines),
                                 Named =:= Label],
    [{Table, Entries - proplists:get_value(Table, Before)} || {Table, Entries} <- After].

counted([Table, Entries | Rest]) ->
    [{Table, list_to_integer(Entries)} | counted(Rest)];
counted([]) ->
    [].

%% Report §8.7: a utilisation, a compute on a peer picked and one on a peer
%% named, the loads read and the pick alone, each a round's microseconds.
pick_table(Lines) ->
    heading("a utilisation and a compute, between nodes", "µs"),
    [row(Name, [list_to_integer(Micros) / ?ROUNDS || {_, [Micros]} <- lines(Scenario, Lines)])
     || {Scenario, Name} <- [{"utilisation", "Peer.utilisation of one peer"},
                             {"compute", "Peer.compute, a peer picked of eight"},
                             {"compute_at", "Peer.computeAt, the peer named"},
                             {"loads", "Peer.loads, eight peers' loads read"},
                             {"pick", "the pick alone, the loads read and the draw"}]].

%% Report §8.7: the packets each connection of three nodes carried idle,
%% each way, as the host counts them, the tellings every interval and the
%% host's ticks where nothing else went, and the gateway's and the exchange's
%% work meanwhile; each connection read at a node whose window held no
%% compute of the measuring program's: a's to q1 and to q2, and q1's to q2.
idle_table(Lines, OnCarrier) ->
    Idle = lines("idle", Lines),
    [Window] = [list_to_integer(Ms) || {"a", ["window", Ms]} <- Idle],
    Connections = [{"a", "q1"}, {"a", "q2"}, {"q1", "q2"}],
    Packets = [list_to_integer(Count)
               || {Node, ["peer", Peer, In, Out]} <- Idle,
                  {At, Other} <- Connections, At =:= Node, Peer =:= maps:get(Other, OnCarrier),
                  Count <- [In, Out]],
    heading(io_lib:format("idle over ~B ms", [Window]), "packets"),
    row("a connection, each way, over the window", Packets),
    %% report §8.7: two nodes hold one connection and three hold three, each
    %% carrying its packets both ways
    PerSecond = [Count * 1000 / Window || Count <- Packets],
    row("  two connected nodes, a second, both ways", [2 * Rate || Rate <- PerSecond]),
    row("  three connected nodes, a second, all ways", [6 * Rate || Rate <- PerSecond]),
    [io:format("  ~s's ~s: ~s reductions~n", [Node, Name, Count])
     || {Node, ["reductions", Name, Count]} <- Idle,
        lists:member(Node, ["a", "q1", "q2"])].

%% Report §11.1: the standard library's `.erc` files, whole and their forms'
%% chunk; and a code frame of one, five and twenty definitions.
sizes_table(Lines, New) ->
    Files = filelib:wildcard(filename:join(?STDLIB, "*.erc")),
    Whole = lists:sum([filelib:file_size(File) || File <- Files]),
    Chunk = binary_to_list(ern_canonical:chunk_name()),
    Forms = lists:sum([byte_size(Bytes) || File <- Files,
                                           {ok, Beam} <- [file:read_file(File)],
                                           {ok, {_, [{_, Bytes}]}}
                                               <- [beam_lib:chunks(Beam, [Chunk])]]),
    io:format("~nthe standard library's ~B .erc files: ~B bytes, their forms' chunks ~B~n",
              [length(Files), Whole, Forms]),
    heading("a module's forms, read as the spawner reads them", "µs"),
    [row(io_lib:format("~s, ~B bytes", [filename:basename(Erc), filelib:file_size(Erc)]),
         [forms_read(Erc) || _ <- lists:seq(1, ?RUNS)])
     || Erc <- [filename:join(New, "r1.erc"), filename:join(New, "big.erc")]],
    heading("a code frame", "bytes"),
    [begin
         Runs = [shares("traced", Label, Lines) || Label <- labels("traced", Size, Lines)],
         row(io_lib:format("the code frames of a reach of ~B", [Size]),
             [maps:get(bytes, Run) || Run <- Runs]),
         row("  one, on average", [maps:get(bytes, Run) / maps:get(frames, Run) || Run <- Runs])
     end || Size <- ?SIZES].

%% Report §11.2: the microseconds of a module's forms read from its `.erc`
%% as ern_code:forms/1 reads a build's unit's, the file read and its forms'
%% chunk decoded.
forms_read(Erc) ->
    {Micros, {ok, _}} = timer:tc(fun() ->
                                     {ok, Bytes} = file:read_file(Erc),
                                     ern_canonical:read(Bytes)
                                 end),
    Micros.
