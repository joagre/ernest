%% `make bench`'s part for the cost rules (docs/development.md; plan, MVP
%% 3.29; CLAUDE.md's *Design*): a row for each promise the rules make that
%% no other part measures, each against the host's own operation. A
%% top-level `let` whose initializer is a ground term is read as its value,
%% which the host keeps in its literal area, and one computed through
%% ern_rt:binding/1, a persistent term by a tuple key (report §8.5,
%% §11.1). A receive with an `after` takes its time as a deadline,
%% waits in slices of the host's longest wait in a fun entered again, and
%% marks the process as in a timed receive while it waits, a key in its
%% dictionary, so that the look finds no deadlock (§6.3, §8.6;
%% ern_emitter's waiting/4). A message
%% to a system process, `Io.print`, is a call the process answers once the
%% stream has taken the bytes (§8.2). A launch, ern_rt:run_main/3, makes
%% the run's tables, its terms, the reaper and the system processes, runs
%% the library's initializers and then main in the entry process, and at
%% the end stops them all (§8.5, §8.6, §11.2).
%%
%% Measured, in rules.txt: a top-level `let` of a literal read, and one
%% computed, a list of a hundred, each beside the host's function that
%% answers the same term, with the read's operations alone; a receive with
%% an `after` that finds its message waiting, where the host sets no timer,
%% beside the host's and Ernest's receive without one, with a model of the
%% timed receive a piece at a time; a receive with an `after` that waits
%% for an echo's answer, where the host sets its timer and cancels it, the
%% same four; `Io.print` of an empty string beside the host's bare send to
%% a process and its call of a process that takes the bytes and answers;
%% and a bare launch, nothing in main, beside the host's start of a
%% program and its spawn of a function that returns, with the launch's
%% pieces, from timestamps taken where its initializers begin and end,
%% traced, and where main begins and returns, and a persistent term's
%% update alone. A program's rows run its code compiled from source, as
%% `ern build` compiles it, in a launch; the host's run outside one. Each
%% row is the median of seven runs, in nanoseconds an iteration, the
%% loop's own cost included, or in microseconds a launch, with their range,
%% as ern_spawn_costs measures them. It measures and asserts nothing, so
%% it is not part of `make test-full`.
-module(ern_rule_costs).

-export([main/1, literal/1, numbers/0]).

%% Each loop's iterations, the launches a run of the launch's rows makes,
%% the host's starts it makes, and the runs.
-define(COUNT, 1000000).
-define(MESSAGES, 500000).
-define(LAUNCHES, 20).
-define(STARTS, 3).
-define(UPDATES, 50).
-define(RUNS, 7).
%% The time of a receive with an `after`, which no receive here reaches.
-define(MS, 1000).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Rule.costs:1">>).
%% The module the program's code is compiled into.
-define(NAMESPACE, ['RuleCosts']).

-define(SOURCE,
        <<"export type PingMsg = Ping(Int)\n"
          "export type EchoMsg = Echo(to : Address(PingMsg), n : Int)\n"
          "let limit : Int = 1024\n"
          "let numbers : List(Int) = List.range(1, 100)\n"
          "export fn limitRead(n : Int) : Int = limit\n"
          "export fn numbersRead(n : Int) : List(Int) = numbers\n"
          "export fn waiting(n : Int) : Int receiving PingMsg = {\n"
          "    send(self(), Ping(n));\n"
          "    receive {\n"
          "        Ping(value) -> value\n"
          "      | after 1000 -> 0\n"
          "    }\n"
          "}\n"
          "export fn waitingForever(n : Int) : Int receiving PingMsg = {\n"
          "    send(self(), Ping(n));\n"
          "    receive {\n"
          "        Ping(value) -> value\n"
          "    }\n"
          "}\n"
          "export fn echoing() : Unit receiving EchoMsg =\n"
          "    receive {\n"
          "        Echo(to = to, n = n) -> {\n"
          "            send(to, Ping(n));\n"
          "            echoing()\n"
          "        }\n"
          "    }\n"
          "export fn echoed(echo : Address(EchoMsg), n : Int) : Int receiving PingMsg = {\n"
          "    send(echo, Echo(to = self(), n = n));\n"
          "    receive {\n"
          "        Ping(value) -> value\n"
          "      | after 1000 -> 0\n"
          "    }\n"
          "}\n"
          "export fn echoedForever(echo : Address(EchoMsg), n : Int) : Int receiving PingMsg = {\n"
          "    send(echo, Echo(to = self(), n = n));\n"
          "    receive {\n"
          "        Ping(value) -> value\n"
          "    }\n"
          "}\n"
          "export fn printed(n : Int) : Int = {\n"
          "    Io.print(\"\");\n"
          "    n\n"
          "}\n">>).

%% Prints the tables, writes them to rules.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Unit = ern_foreign_costs:compiled(?NAMESPACE, ?SOURCE),
    Text = unicode:characters_to_binary(
             [binding_tables(Unit), receive_tables(Unit), system_table(Unit),
              launch_tables()]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "rules.txt"), Text),
    halt(0).

%% A program's function of Unit by its name, called with the loop's count
%% after what Given gives in the launch, in a loop of Count iterations, in a
%% launch whose program has initialized Unit; called as a fun of the
%% function, as the host's rows call theirs.
ernest(Unit, Name, Given) ->
    {Function, Arity} = ern_code:function(Unit, ?NAMESPACE ++ [Name]),
    Called = erlang:make_fun(Unit, Function, Arity),
    ern_spawn_costs:launched(
      fun(Count) ->
          ok = Unit:'$init'(),
          Operation = case Given of
                          none -> Called;
                          _ -> Argument = Given(), fun(N) -> Called(Argument, N) end
                      end,
          ern_spawn_costs:timed(Count, looped(Operation))
      end).

%% The host's loop of Operation, outside a launch.
host(Operation) ->
    fun(Count) -> ern_spawn_costs:timed(Count, looped(Operation)) end.

looped(Operation) ->
    fun Loop(0) -> ok;
        Loop(Left) -> _ = Operation(Left), Loop(Left - 1)
    end.

%%
%% A top-level let's read
%%

%% Report §8.5, §11.1: a `let` of a literal and a computed one, each read
%% by a function of the unit's, beside the host's function that answers
%% the same term, a literal of its module; and the read's operations alone.
binding_tables(Unit) ->
    Held = held(),
    Literal = [{"the host's function answering a literal", host(fun ?MODULE:literal/1)},
               {"a function reading a let of a literal", ernest(Unit, limitRead, none)}],
    Computed = [{"the host's function answering a list of a hundred",
                 host(erlang:make_fun(Held, numbers, 1))},
                {"a function reading a let computed, List.range(1, 100)",
                 ernest(Unit, numbersRead, none)}],
    persistent_term:put({?MODULE, limit}, 1024),
    persistent_term:put(ern_rule_costs_limit, 1024),
    Operations = [{"the loop alone", host(fun(_) -> ok end)},
                  {"a literal, from a function of its own", host(fun ?MODULE:literal/1)},
                  {"a persistent term by a tuple key", host(fun(_) -> term_by_tuple() end)},
                  {"  by an atom key", host(fun(_) -> term_by_atom() end)},
                  {"ern_rt:binding/1, by a tuple key", host(fun(_) -> bound() end)}],
    [ern_spawn_costs:table("a top-level let of a literal read, ns an iteration",
                           ern_spawn_costs:measured(Literal, ?COUNT), ratio),
     ern_spawn_costs:table("a top-level let computed read, ns an iteration",
                           ern_spawn_costs:measured(Computed, ?COUNT), ratio),
     ern_spawn_costs:table("a read's operations, each alone, ns an operation",
                           ern_spawn_costs:measured(Operations, ?COUNT), none)].

-spec literal(integer()) -> integer().
literal(_) -> 1024.

term_by_tuple() -> persistent_term:get({?MODULE, limit}).

term_by_atom() -> persistent_term:get(ern_rule_costs_limit).

bound() -> ern_rt:binding({?MODULE, limit}).

%% A module whose function answers the list of a hundred as a literal, as a
%% value computed when it was compiled.
held() ->
    Forms = [{attribute, 1, module, ern_rule_costs_held},
             {attribute, 1, export, [{numbers, 1}]},
             {function, 1, numbers, 1,
              [{clause, 1, [{var, 1, '_'}], [], [erl_parse:abstract(numbers())]}]}],
    {ok, Module, Beam} = compile:forms(Forms),
    {module, Module} = code:load_binary(Module, "held", Beam),
    Module.

-spec numbers() -> [integer()].
numbers() -> lists:seq(1, 100).

%%
%% A receive with an after
%%

%% Report §6.3, §8.6: a receive with an `after` that finds its message
%% waiting, the host's beside Ernest's, without and with an `after`; a
%% model of it a piece at a time; and one that waits for an echo's answer,
%% the host's timer set and canceled.
receive_tables(Unit) ->
    Waiting = [{"the host's receive with an after", launched(fun host_waiting/1)},
               {"  without one", launched(fun host_waiting_forever/1)},
               {"Ernest's receive without an after", ernest(Unit, waitingForever, none)},
               {"Ernest's receive with an after", ernest(Unit, waiting, none)}],
    Model = [{"the host's receive with an after", launched(fun host_waiting/1)},
             {"+ the message sent by ern_rt:send/2", launched(fun sent/1)},
             {"+ a restart's clause and a fault's, as every receive has",
              launched(fun clauses/1)},
             {"+ the time a deadline, the wait a fun, entered again by slices",
              launched(fun sliced/1)},
             {"+ the process marked as in a timed receive", launched(fun marked/1)},
             {"Ernest's receive with an after", ernest(Unit, waiting, none)}],
    {Echoing, 0} = ern_code:function(Unit, ?NAMESPACE ++ [echoing]),
    Echo = fun() -> ern_rt:spawn(fun() -> Unit:Echoing() end, ?SITE) end,
    Echoed = [{"the host's receive of an echo's answer without an after",
               echoes(fun host_echoed_forever/2)},
              {"  with one, its timer set and canceled", echoes(fun host_echoed/2)},
              {"Ernest's without an after", ernest(Unit, echoedForever, Echo)},
              {"Ernest's with one", ernest(Unit, echoed, Echo)}],
    [ern_spawn_costs:table("a receive that finds its message waiting, ns an iteration",
                           ern_spawn_costs:measured(Waiting, ?MESSAGES), ratio),
     ern_spawn_costs:table("a model of a receive with an after, a piece added on each row",
                           ern_spawn_costs:measured(Model, ?MESSAGES), added),
     ern_spawn_costs:table("a receive that waits for an echo's answer, ns an iteration",
                           ern_spawn_costs:measured(Echoed, ?MESSAGES), ratio)].

host_waiting(N) ->
    self() ! {'Ping', N},
    receive
        {'Ping', Value} -> Value
    after ?MS -> 0
    end.

host_waiting_forever(N) ->
    self() ! {'Ping', N},
    receive
        {'Ping', Value} -> Value
    end.

%% The model, each row the row before with one piece more, the last the
%% code the emitter writes (ern_emitter's receive_clauses/2, waiting/4).
sent(N) ->
    ern_rt:send(self(), {'Ping', N}),
    receive
        {'Ping', Value} -> Value
    after ?MS -> 0
    end.

clauses(N) ->
    ern_rt:send(self(), {'Ping', N}),
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault} -> erlang:throw(Fault);
        {'Ping', Value} -> Value
    after ?MS -> 0
    end.

sliced(N) ->
    ern_rt:send(self(), {'Ping', N}),
    Deadline = ern_rt:deadline(?MS),
    fun Wait() ->
        receive
            '$ern_restart' -> ern_rt:restart_now();
            {'$ern_fault', Fault} -> erlang:throw(Fault);
            {'Ping', Value} -> Value
        after ern_rt:remaining(Deadline) ->
            case ern_rt:remaining(Deadline) of
                0 -> 0;
                _ -> Wait()
            end
        end
    end().

marked(N) ->
    ern_rt:send(self(), {'Ping', N}),
    Deadline = ern_rt:deadline(?MS),
    ern_rt:timed(),
    fun Wait() ->
        receive
            '$ern_restart' -> ern_rt:untimed(), ern_rt:restart_now();
            {'$ern_fault', Fault} -> ern_rt:untimed(), erlang:throw(Fault);
            {'Ping', Value} -> ern_rt:untimed(), Value
        after ern_rt:remaining(Deadline) ->
            case ern_rt:remaining(Deadline) of
                0 -> ern_rt:untimed(), 0;
                _ -> Wait()
            end
        end
    end().

%% A loop of Operation in a launch's entry process, which has its row, as
%% the program's rows run.
launched(Operation) ->
    ern_spawn_costs:launched(fun(Count) -> ern_spawn_costs:timed(Count, looped(Operation)) end).

%% The host's echo, outside a launch, and the host's receive of its answer.
echoes(Echoed) ->
    fun(Count) ->
        Echo = spawn(fun host_echo/0),
        Measured = ern_spawn_costs:timed(Count, looped(fun(N) -> Echoed(Echo, N) end)),
        exit(Echo, kill),
        Measured
    end.

host_echo() ->
    receive
        {'Echo', To, N} ->
            To ! {'Ping', N},
            host_echo()
    end.

host_echoed(Echo, N) ->
    Echo ! {'Echo', self(), N},
    receive
        {'Ping', Value} -> Value
    after ?MS -> 0
    end.

host_echoed_forever(Echo, N) ->
    Echo ! {'Echo', self(), N},
    receive
        {'Ping', Value} -> Value
    end.

%%
%% A message to a system process
%%

%% Report §8.2: Io.print of an empty string, a call standard output
%% answers once it has taken the bytes, here dropped (launched/1), beside
%% the host's bare send to a process and its call of a process that takes
%% the bytes and answers, as gen:do_call/4 makes one.
system_table(Unit) ->
    Rows = [{"the host's send to a process", sends()},
            {"the host's call of a process that takes the bytes and answers", writes()},
            {"Io.print of an empty string", ernest(Unit, printed, none)}],
    ern_spawn_costs:table("a message to a system process, ns an iteration",
                          ern_spawn_costs:measured(Rows, ?MESSAGES), ratio).

%% The sends alone, the sink's taking them after; it has taken them all
%% before the next run.
sends() ->
    fun(Count) ->
        Sink = spawn(fun sink/0),
        Measured = ern_spawn_costs:timed(Count, looped(fun(_) -> Sink ! <<>> end)),
        Sink ! {taken, self()},
        receive taken -> ok end,
        Measured
    end.

sink() ->
    receive
        {taken, From} -> From ! taken;
        _ -> sink()
    end.

writes() ->
    fun(Count) ->
        Stream = spawn(fun stream/0),
        Measured = ern_spawn_costs:timed(Count, looped(fun(_) -> written(Stream) end)),
        exit(Stream, kill),
        Measured
    end.

stream() ->
    receive
        {'Write', _, Alias} ->
            Alias ! {Alias, ok},
            stream()
    end.

written(Stream) ->
    MonitorRef = erlang:monitor(process, Stream, [{alias, demonitor}]),
    Stream ! {'Write', <<>>, MonitorRef},
    receive
        {MonitorRef, Answer} ->
            erlang:demonitor(MonitorRef, [flush]),
            Answer;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            exit(ExitReason)
    end.

%%
%% A launch
%%

%% Report §8.5, §8.6, §11.2: a bare launch beside the host's start of a
%% program and its spawn of a function that returns, its pieces, and a
%% persistent term's update alone, in microseconds.
launch_tables() ->
    Runs = [run_launch() || _ <- lists:seq(1, ?RUNS)],
    Column = fun(Index) -> [element(Index, Run) || Run <- Runs] end,
    [ern_spawn_costs:table("a bare launch, us a launch",
                           [{"the host's start of a program, erl run by a shell", Column(1)},
                            {"the host's spawn of a function that returns, its 'DOWN' taken",
                             Column(2)},
                            {"a launch, ern_rt:run_main/3, nothing in main", Column(3)}],
                           none),
     ern_spawn_costs:table("the launch's pieces, us a launch",
                           [{"the start, to the library's initializers", Column(4)},
                            {"the library's initializers", Column(5)},
                            {"from them to main's return", Column(6)},
                            {"the end, from main's return", Column(7)}],
                           none),
     ern_spawn_costs:table("a persistent term's update alone, us an operation",
                           [{"a persistent term put under a new key and erased", Column(8)},
                            {"  put again with the value it holds", Column(9)}],
                           none)].

%% One run of each row, the rows taking turns, in microseconds each.
run_launch() ->
    Starts = [started() || _ <- lists:seq(1, ?STARTS)],
    Spawns = micros_each(?COUNT div 100, fun spawned/0),
    Launches = [launch() || _ <- lists:seq(1, ?LAUNCHES)],
    Updates = micros_each(?UPDATES, fun updated/0),
    Again = micros_each(?UPDATES, fun put_again/0),
    Mean = fun(Values) -> lists:sum(Values) / length(Values) end,
    Piece = fun(Index) -> Mean([element(Index, Launch) || Launch <- Launches]) end,
    {Mean(Starts), Spawns, Piece(1), Piece(2), Piece(3), Piece(4), Piece(5), Updates, Again}.

%% The host's start of a program and its halt, as a shell runs it.
started() ->
    Started = erlang:monotonic_time(nanosecond),
    _ = os:cmd("erl -noinput -eval 'halt().'"),
    (erlang:monotonic_time(nanosecond) - Started) / 1000.

spawned() ->
    {_, MonitorRef} = spawn_monitor(fun() -> ok end),
    receive {'DOWN', MonitorRef, _, _, _} -> ok end.

micros_each(Count, Operation) ->
    {Nanoseconds, Count} = ern_spawn_costs:timed(Count, looped(fun(_) -> Operation() end)),
    Nanoseconds / Count / 1000.

updated() ->
    persistent_term:put({?MODULE, update}, 1),
    persistent_term:erase({?MODULE, update}).

put_again() ->
    persistent_term:put({?MODULE, limit}, 1024).

%% A launch with nothing in main, its stdout dropped, and its pieces, in
%% microseconds: the whole; from its start to its library's initializers,
%% which run_inits/1 runs in the entry process, traced as it begins and
%% returns; those; from them to main's return; and the end.
launch() ->
    Self = self(),
    1 = erlang:trace_pattern({ern_rt, run_inits, 1}, [{'_', [], [{return_trace}]}], [local]),
    _ = erlang:trace(new_processes, true, [call, monotonic_timestamp, {tracer, Self}]),
    Main = fun() ->
               Self ! {returned, erlang:monotonic_time()},
               'Unit'
           end,
    Started = erlang:monotonic_time(),
    ok = ern_rt:run_main(Main, <<"Rule.main">>, #{stdout => fun(_) -> ok end}),
    Ended = erlang:monotonic_time(),
    _ = erlang:trace(new_processes, false, [call]),
    1 = erlang:trace_pattern({ern_rt, run_inits, 1}, false, [local]),
    Initializing = receive {trace_ts, _, call, {ern_rt, run_inits, _}, Begun} -> Begun end,
    Initialized = receive {trace_ts, _, return_from, {ern_rt, run_inits, _}, _, Done} -> Done end,
    Returned = receive {returned, At} -> At end,
    Micros = fun(From, To) -> erlang:convert_time_unit(To - From, native, nanosecond) / 1000 end,
    {Micros(Started, Ended), Micros(Started, Initializing), Micros(Initializing, Initialized),
     Micros(Initialized, Returned), Micros(Returned, Ended)}.
