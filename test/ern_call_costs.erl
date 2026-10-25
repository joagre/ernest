%% `make bench`'s part `call` (docs/development.md; plan, MVP 3.29):
%% what each piece of `Address.call` adds to the host's call of the same
%% shape (report §6.6, §6.9, §8.6), with one caller and one callee, with
%% eight callers over eight callees at once, and with eight callers over
%% one callee. The host's call is gen:do_call/4's: a monitor that is the
%% reply's alias, the request sent, a receive with an `after`, the monitor
%% dropped.
%%
%% ern_rt's call/4 reads the callee through the address and sends the
%% request by its way (line_guard/1, process_of/1, adapted_way/2), so that
%% a checker or an adapted function is honored. It keeps the call's two
%% records, the callee's row in the callees table so that its restart ends
%% the call (§6.9), and the caller's CALL key in its dictionary, which the
%% look reads for a request in flight (§8.6) and a kill before it kills
%% (§6.9), and drops them as the call ends (pending/2, uncalled/0), each a
%% piece of its own.
%%
%% While it waits, call/4 marks the caller as in a timed receive, a key in
%% its dictionary (timed/0, untimed/0, §8.6). It takes the answer among
%% the forms a wait takes, a restart and a fault's among them, the answer
%% of foreign code checked (waited_answer/3, §8.4), where an Ernest
%% callee's answer is not. It waits against a deadline in slices of the
%% host's longest wait, in a try that takes the mark away and one that
%% settles (?SLICE, remaining/1).
%%
%% Measured, in call.txt: for each of the three, the host's call, the
%% model of `Address.call` a piece added on each row until it is call/4's
%% code, then `Address.call` and `Address.callForever` of an Ernest
%% counter, the code the compiler writes, its callee too; first the three
%% beside the host's call, then each model; and each of the call's writes
%% alone, the callee's row on the runtime's table and the two keys in the
%% process's dictionary, by one process and by eight at once.
%%
%% Every row runs in a launch of its own, its callers and callees processes the
%% runtime spawns, each with its row as a program's has, started at once
%% and timed until every caller has made its calls (ern_costs:at_once/2),
%% in nanoseconds a call over all callers, the loop's own cost included.
%% Each row is the median of seven runs, with their range, as ern_costs
%% measures them. The part measures and asserts nothing, so it is not part
%% of `make test-full`.
-module(ern_call_costs).

-export([main/1]).

%% Each caller's calls in a run of a row, each process's operations in a
%% run of an operation's row, and how many processes run one at once.
-define(COUNT, 40000).
-define(OPERATIONS, 50000).
-define(AT_ONCE, 8).
%% The call's time, which no call here reaches.
-define(MS, 10000).
%% A spawn site, as the compiler supplies one (report §6.9).
-define(SITE, <<"Call.costs:1">>).
%% The runtime's table of calls by callee, and the caller's key (ern_rt's
%% ?CALLEES and ?CALL).
-define(CALLEES, ern_callees).
-define(CALL, '$ern_call').
%% The module the counter is compiled into.
-define(NAMESPACE, ['CallCosts']).

%% The callers over the callees, and how each table names them.
-define(SHAPES, [{1, 1, "one caller and one callee"},
                 {8, 8, "eight callers over eight callees, eight pairs"},
                 {8, 1, "eight callers over one callee"}]).

%% Prints the tables, writes them to call.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Unit = ern_costs:compiled(?NAMESPACE, source()),
    Measured = [{Name, ern_costs:measured(rows(Unit, Callers, Callees), ?COUNT)}
                || {Callers, Callees, Name} <- ?SHAPES],
    Text = unicode:characters_to_binary(
             [[ern_costs:table(["the call, ", Name, ", ns a call over all callers"],
                               [hd(Rows) | lists:nthtail(length(Rows) - 2, Rows)], ratio)
               || {Name, Rows} <- Measured],
              [ern_costs:table(["a model of Address.call, ", Name,
                                ", a piece added on each row"],
                               lists:sublist(Rows, length(Rows) - 1), added)
               || {Name, Rows} <- Measured],
              ern_costs:table("the call's writes, each alone, one process against eight "
                              "at once, ns an operation over all processes",
                              ern_costs:measured(operations(), ?OPERATIONS), none)]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "call.txt"), Text),
    halt(0).

%% The counter and its callers, as a program writes them, its call's time
%% ?MS.
source() ->
    iolist_to_binary(
      ["export type CounterMsg = Get(Reply(Int))\n"
       "export fn count(total : Int) : Unit receiving CounterMsg =\n"
       "    receive {\n"
       "        Get(reply) -> {\n"
       "            answer(reply, total);\n"
       "            count(total + 1)\n"
       "        }\n"
       "    }\n"
       "export fn get(counter : Address(CounterMsg)) : Int =\n"
       "    Optional.withDefault(Address.call(counter, Get, ", integer_to_list(?MS), "), 0)\n"
       "export fn getForever(counter : Address(CounterMsg)) : Int =\n"
       "    Address.callForever(counter, Get)\n"]).

%% Each row's calls, Callers callers over Callees callees: the host's
%% call, the model a piece at a time, and the program's calls.
rows(Unit, Callers, Callees) ->
    [Count, Get, GetForever] = [function(Unit, Name) || Name <- [count, get, getForever]],
    Host = fun() -> host_serve(0) end,
    Ernest = fun() -> ernest_serve(0) end,
    Counter = fun() -> Count(0) end,
    [{Name, ern_costs:launched(
              fun(Calls) -> calls(Callers, Callees, Serve, Call, Calls) end)}
     || {Name, Serve, Call} <-
            [{"the host's call", Host, fun host_call/2},
             {"+ the callee read through the address, the request sent by its way", Host,
              fun addressed/2},
             {"+ the callee's row, so that its restart ends the call", Host, fun restartable/2},
             {"+ the caller's CALL key, which the look and a kill read", Host, fun keyed/2},
             {"+ the caller marked as in a timed receive", Host, fun marked/2},
             {"+ the reply the alias and the caller, answered by answer/2, among the forms a wait"
              " takes", Ernest,
              fun answered/2},
             {"+ the wait against a deadline, sliced, in tries, as call/4's", Ernest,
              fun waited/2},
             {"Address.call of an Ernest counter", Counter,
              fun(Callee, _) -> Get(Callee) end},
             {"Address.callForever of it", Counter,
              fun(Callee, _) -> GetForever(Callee) end}]].

%% The unit's function by its Ernest name, as a fun.
function(Unit, Name) ->
    {Function, Arity} = ern_code:function(Unit, ?NAMESPACE ++ [Name]),
    erlang:make_fun(Unit, Function, Arity).

%% Callers callers over Callees callees served by Serve, each making Calls
%% calls of its callee by Call, timed together.
calls(Callers, Callees, Serve, Call, Calls) ->
    Served = list_to_tuple([ern_rt:spawn(Serve, ?SITE) || _ <- lists:seq(1, Callees)]),
    Request = fun(Reply) -> {'Get', Reply} end,
    ern_costs:at_once(Calls, [fun(Left) ->
                                  called(Call, Request,
                                         element((Index - 1) rem Callees + 1, Served), Left)
                              end || Index <- lists:seq(1, Callers)]).

called(_, _, _, 0) ->
    ok;
called(Call, Request, Callee, Left) ->
    _ = Call(Callee, Request),
    called(Call, Request, Callee, Left - 1).

%% Each write of the call's, alone in a loop, by one process and by
%% ?AT_ONCE at once, each a process the runtime spawns, with its row, each
%% writing its own key: the callee's row written and deleted on the
%% runtime's table, and the call's key and the timed key put and erased in
%% the process's dictionary.
operations() ->
    Callee = self(),
    [{Name ++ Processes,
      ern_costs:launched(
        fun(Count) ->
            ern_costs:at_once(Count, lists:duplicate(Many, ern_costs:looped(Operation)))
        end)}
     || {Name, Operation} <-
            [{"the callee's row written and deleted",
              fun(_) ->
                  ets:insert(?CALLEES, {{Callee, self()}, Callee}),
                  ets:delete(?CALLEES, {Callee, self()})
              end},
             {"the call's key put and erased",
              fun(_) ->
                  _ = put(?CALL, {Callee, Callee}),
                  erase(?CALL)
              end},
             {"the timed key put and taken, timed/0 and untimed/0",
              fun(_) -> ern_rt:timed(), ern_rt:untimed() end}],
        {Many, Processes} <- [{1, ", one process"}, {?AT_ONCE, ", eight at once"}]].

%%
%% The callees
%%

%% The host's counter, which answers to the alias.
host_serve(Total) ->
    receive
        {'Get', Alias} ->
            Alias ! {Alias, Total},
            host_serve(Total + 1)
    end.

%% The counter as the compiler writes its receive, answering by answer/2.
ernest_serve(Total) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault} -> erlang:throw(Fault);
        {'Get', Reply} ->
            ern_rt:answer(Reply, Total),
            ernest_serve(Total + 1)
    end.

%%
%% The model, each row a function of its own, call/4 a piece at a time
%%

%% The host's call, as gen:do_call/4 makes one with a limit.
host_call(Callee, _) ->
    MonitorRef = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Callee ! {'Get', MonitorRef},
    receive
        {MonitorRef, Value} ->
            erlang:demonitor(MonitorRef, [flush]),
            Value;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            exit(ExitReason)
    after ?MS ->
        erlang:demonitor(MonitorRef, [flush]),
        0
    end.

%% + call/4's way to the callee: the line guard, the process behind the
%% address, the request made by its function and sent by ern_rt:send/2,
%% which takes it the address's way, and late answers flushed with the
%% monitor.
addressed(Address, Request) ->
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    ern_rt:send(Address, Request(Reply)),
    Answer = receive
                 {Reply, Value} -> Value;
                 {'DOWN', Reply, _, _, ExitReason} -> exit(ExitReason)
             after ?MS -> 0
             end,
    flushed(Reply),
    Answer.

%% + the callee's row in the callees table, written once the request is
%% made and deleted as the call ends, which the reaper reads at the
%% callee's restart to end the call (§6.9).
restartable(Address, Request) ->
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Message = Request(Reply),
    ets:insert(?CALLEES, {{Callee, self()}, Reply}),
    ern_rt:send(Address, Message),
    Answer = receive
                 {Reply, Value} -> Value;
                 {'DOWN', Reply, _, _, ExitReason} -> exit(ExitReason)
             after ?MS -> 0
             end,
    ets:delete(?CALLEES, {Callee, self()}),
    flushed(Reply),
    Answer.

%% + the caller's CALL key in its dictionary beside it, which the look
%% reads for a request in flight to a system process (§8.6) and a kill
%% before it kills (§6.9): pending/2 and uncalled/0 whole.
keyed(Address, Request) ->
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Message = Request(Reply),
    pending(Callee, Reply),
    ern_rt:send(Address, Message),
    Answer = receive
                 {Reply, Value} -> Value;
                 {'DOWN', Reply, _, _, ExitReason} -> exit(ExitReason)
             after ?MS -> 0
             end,
    uncalled(),
    flushed(Reply),
    Answer.

%% + the caller marked as in a timed receive while it waits.
marked(Address, Request) ->
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Message = Request(Reply),
    pending(Callee, Reply),
    ern_rt:send(Address, Message),
    ern_rt:timed(),
    Answer = receive
                 {Reply, Value} -> Value;
                 {'DOWN', Reply, _, _, ExitReason} -> exit(ExitReason)
             after ?MS -> 0
             end,
    ern_rt:untimed(),
    uncalled(),
    flushed(Reply),
    Answer.

%% + the answer as answer/2 gives it, to a reply that is the alias with
%% the caller's process beside it, taken among every form a call's wait
%% takes, and made Some: the callee is the compiled counter's form.
answered(Address, Request) ->
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Message = Request({Reply, self()}),
    pending(Callee, Reply),
    ern_rt:send(Address, Message),
    ern_rt:timed(),
    Answer = receive
                 {Reply, answered, Value} -> {'Some', Value};
                 {Reply, unnoted, Value} -> {'Some', Value};
                 {Reply, Value} -> {'Some', Value};
                 {Reply, restarted, _} -> 'None';
                 {Reply, fault, Cause} -> ern_rt:fault(Cause);
                 {'DOWN', Reply, process, _, _} -> 'None';
                 '$ern_restart' -> '$ern_restart';
                 {'$ern_fault', Fault} -> throw(Fault)
             after ?MS -> 'None'
             end,
    ern_rt:untimed(),
    uncalled(),
    flushed(Reply),
    valued(Answer).

%% + the wait as waited_answer/3 makes it: against a deadline taken as
%% the call begins, in slices of at most the host's longest wait, the mark
%% taken away in a try's after and the call settled in another's, the
%% restart asked for taken: call/4 whole.
waited(Address, Request) ->
    Deadline = ern_rt:deadline(?MS),
    guarded(),
    Callee = ern_rt:process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    Answer = try
                 Message = Request({Reply, self()}),
                 pending(Callee, Reply),
                 ern_rt:send(Address, Message),
                 ern_rt:timed(),
                 try waited_answer(Reply, Deadline) after ern_rt:untimed() end
             after
                 uncalled(),
                 flushed(Reply)
             end,
    case Answer of
        '$ern_restart' -> ern_rt:restart_now();
        _ -> valued(Answer)
    end.

waited_answer(Reply, Deadline) ->
    receive
        {Reply, answered, Value} -> {'Some', Value};
        {Reply, unnoted, Value} -> {'Some', Value};
        {Reply, Value} -> {'Some', Value};
        {Reply, restarted, _} -> 'None';
        {Reply, fault, Cause} -> ern_rt:fault(Cause);
        {'DOWN', Reply, process, _, _} -> 'None';
        '$ern_restart' -> '$ern_restart';
        {'$ern_fault', Fault} -> throw(Fault)
    after ern_rt:remaining(Deadline) ->
        case ern_rt:remaining(Deadline) of
            0 -> 'None';
            _ -> waited_answer(Reply, Deadline)
        end
    end.

%% Optional.withDefault(answer, 0), as the program's caller writes it.
valued({'Some', Value}) -> Value;
valued('None') -> 0.

%% ern_rt's line_guard/1, where no shell holds the terminal.
guarded() ->
    case ern_rt:terminal_holder() of
        undefined -> ok
    end.

%% ern_rt's pending/2 for a callee of this node.
pending(Callee, Reply) ->
    _ = put(?CALL, {Callee, Reply}),
    node(Callee) =:= node() orelse error(other_node),
    ets:insert(?CALLEES, {{Callee, self()}, Reply}).

%% ern_rt's uncalled/0 for a callee of this node.
uncalled() ->
    case get(?CALL) of
        undefined ->
            true;
        {Callee, _} ->
            ets:delete(?CALLEES, {Callee, self()}),
            erase(?CALL)
    end.

%% ern_rt's settled/1 but its rows: the monitor and the alias gone, and the
%% answers that came before them.
flushed(Reply) ->
    erlang:demonitor(Reply, [flush]),
    flushed_answers(Reply).

flushed_answers(Reply) ->
    receive
        {Reply, _} -> flushed_answers(Reply);
        {Reply, _, _} -> flushed_answers(Reply)
    after 0 ->
        ok
    end.
