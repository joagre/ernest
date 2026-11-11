%% The waits the tests share, each on what it means rather than on a time
%% (CLAUDE.md, *No fixed sleep*): a process in a state, blocked in a receive
%% or in a call, or watching another or no longer, among them, a process
%% having called a function or returned from it, the runtime's reaper
%% having looked for a deadlock, and the deliveries to a process having
%% ended. All but the last read what the host reports of a process by
%% tracing it, and stop tracing when they return.
-module(ern_waits).

-export([until/2, waiting/1, running/1, calling/1, watching/2, unwatched/2, called/3,
         returned/3, looked/1, delivered/1, forever/0, with_room/1, freed/2, references/2]).

%% What Work answers, every process it starts given a heap with room. The
%% host collects a process when its heap fills, which a new process's small
%% heap does at once, and a test of what a process holds while it waits would
%% pass by that collection, where a process that has lived a while has room
%% and holds on (report §10). The room is less than a megabyte's words.
-spec with_room(fun(() -> Result)) -> Result.
with_room(Work) ->
    Before = erlang:system_flag(min_heap_size, 20000),
    try
        Work()
    after
        erlang:system_flag(min_heap_size, Before)
    end.

%% Until Test, asked of Pid's state, holds, or Pid has ended: Test is asked
%% at first and again each time the host schedules Pid out, which is when
%% what Pid itself does has changed. The trace shows no end, so a monitor
%% beside it does; a process that has ended cannot be traced, nor its
%% trace turned off.
-spec until(pid(), fun(() -> boolean())) -> ok | ended.
until(Pid, Test) ->
    MonitorRef = erlang:monitor(process, Pid),
    try erlang:trace(Pid, true, [running]) of
        _ ->
            try
                held(Pid, MonitorRef, Test)
            after
                untraced(Pid),
                flushed(Pid)
            end
    catch
        error:badarg -> ended
    after
        erlang:demonitor(MonitorRef, [flush])
    end.

held(Pid, MonitorRef, Test) ->
    case erlang:is_process_alive(Pid) andalso Test() of
        true ->
            ok;
        false ->
            receive
                {trace, Pid, out, _} -> held(Pid, MonitorRef, Test);
                {'DOWN', MonitorRef, process, Pid, _} -> ended
            end
    end.

untraced(Pid) ->
    untraced(Pid, [running]).

untraced(Pid, Flags) ->
    try erlang:trace(Pid, false, Flags)
    catch error:badarg -> 0
    end.

%% Report §10: until Pid references no binary of Size bytes or more, or has
%% ended. Its references are read at first and again after each collection of
%% Pid and each hibernation, which the host traces, so that no read waits in a
%% loop.
-spec freed(pid(), non_neg_integer()) -> ok | ended.
freed(Pid, Size) ->
    Flags = [garbage_collection, running],
    MonitorRef = erlang:monitor(process, Pid),
    try erlang:trace(Pid, true, Flags) of
        _ ->
            try
                unreferenced(Pid, Size, MonitorRef)
            after
                untraced(Pid, Flags),
                flushed(Pid)
            end
    catch
        error:badarg -> ended
    after
        erlang:demonitor(MonitorRef, [flush])
    end.

unreferenced(Pid, Size, MonitorRef) ->
    case references(Pid, Size) of
        ended ->
            ended;
        false ->
            ok;
        true ->
            receive
                {trace, Pid, Collection, _} when Collection =:= gc_minor_end;
                                                 Collection =:= gc_major_end ->
                    unreferenced(Pid, Size, MonitorRef);
                {trace, Pid, out, {_, Hibernation, _}} when Hibernation =:= hibernate;
                                                            Hibernation =:= loop_hibernate ->
                    unreferenced(Pid, Size, MonitorRef);
                {'DOWN', MonitorRef, process, Pid, _} -> ended
            end
    end.

%% Whether Pid references a binary of Size bytes or more.
-spec references(pid(), non_neg_integer()) -> boolean() | ended.
references(Pid, Size) ->
    case erlang:process_info(Pid, binary) of
        undefined -> ended;
        {binary, Binaries} -> lists:any(fun({_, Bytes, _}) -> Bytes >= Size end, Binaries)
    end.

%% Until Pid waits in a receive, which the host shows as the status
%% `waiting`, or has ended.
-spec waiting(pid()) -> ok | ended.
waiting(Pid) ->
    until(Pid, fun() -> erlang:process_info(Pid, status) =:= {status, waiting} end).

%% Until Pid runs rather than waits, at work it was given, or has ended.
-spec running(pid()) -> ok | ended.
running(Pid) ->
    until(Pid, fun() -> erlang:process_info(Pid, status) =/= {status, waiting} end).

%% Report §6.6, §8.6: until Pid waits for a call's answer, which the host
%% shows as the status `waiting` with the call under its CALL key, or has
%% ended.
-spec calling(pid()) -> ok | ended.
calling(Pid) ->
    until(Pid, fun() ->
                   case erlang:process_info(Pid, [status, {dictionary, '$ern_call'}]) of
                       [{status, waiting}, {_, Call}] when Call =/= undefined -> true;
                       _ -> false
                   end
               end).

%% Report §6.9: until Pid monitors Watched, or has ended.
-spec watching(pid(), pid()) -> ok | ended.
watching(Pid, Watched) ->
    until(Pid, fun() -> is_watching(Pid, Watched) end).

%% Until Pid no longer monitors Watched, or has ended. Where Watched has
%% ended, the host has then put its `DOWN` in Pid's mailbox, ahead of every
%% message sent to Pid after.
-spec unwatched(pid(), pid()) -> ok | ended.
unwatched(Pid, Watched) ->
    until(Pid, fun() -> not is_watching(Pid, Watched) end).

is_watching(Pid, Watched) ->
    case erlang:process_info(Pid, monitors) of
        {monitors, Monitors} -> lists:member({process, Watched}, Monitors);
        undefined -> false
    end.

%% Until Pid has called Module:Function/Arity Count times from now, which
%% the host shows by tracing its calls, local ones among them, or has ended.
-spec called(pid(), mfa(), pos_integer()) -> ok | ended.
called(Pid, {Module, Function, _} = MFA, Count) ->
    1 = erlang:trace_pattern(MFA, true, [local]),
    MonitorRef = erlang:monitor(process, Pid),
    try erlang:trace(Pid, true, [call]) of
        _ ->
            try
                calls(Pid, Module, Function, Count, MonitorRef)
            after
                untraced(Pid, [call]),
                flushed(Pid)
            end
    catch
        error:badarg -> ended
    after
        erlang:trace_pattern(MFA, false, [local]),
        erlang:demonitor(MonitorRef, [flush])
    end.

calls(_, _, _, 0, _) -> ok;
calls(Pid, Module, Function, Count, MonitorRef) ->
    receive
        {trace, Pid, call, {Module, Function, _}} ->
            calls(Pid, Module, Function, Count - 1, MonitorRef);
        {'DOWN', MonitorRef, process, Pid, _} ->
            ended
    end.

%% Until Pid has returned from Module:Function called with Arguments, a
%% call made after Action, which runs once the call is traced.
-spec returned(pid(), {module(), atom(), list()}, fun(() -> term())) -> ok.
returned(Pid, {Module, Function, Arguments}, Action) ->
    MFA = {Module, Function, length(Arguments)},
    1 = erlang:trace_pattern(MFA, [{Arguments, [], [{return_trace}]}], [local]),
    erlang:trace(Pid, true, [call]),
    try
        _ = Action(),
        receive {trace, Pid, return_from, MFA, _} -> ok end
    after
        erlang:trace(Pid, false, [call]),
        erlang:trace_pattern(MFA, false, [local]),
        flushed(Pid)
    end.

%% Report §8.6: until the runtime's reaper has looked for a deadlock Count
%% times, or has ended with its run. A process of the run that waits here
%% waits in a module of the host's, a test's, which the look reads as
%% foreign code in progress, so it never seems deadlocked.
-spec looked(pos_integer()) -> ok | ended.
looked(Count) ->
    called(ern_rt:launch_reaper(), {ern_rt, look, 0}, Count).

%% Report §6.9: until every delivery the runtime started to Recipient, of a
%% monitor's Down, an alarm or a subscriber's telling, has ended. A delivery sends
%% before it ends, so what it delivered is in Recipient's mailbox then.
-spec delivered(pid()) -> ok.
delivered(Recipient) ->
    Deliveries = [Pid || {{Target, _, Pid}, _} <- ets:tab2list(ern_deliveries),
                         Target =:= Recipient],
    lists:foreach(fun(Pid) ->
                      MonitorRef = erlang:monitor(process, Pid),
                      receive {'DOWN', MonitorRef, process, Pid, _} -> ok end
                  end, Deliveries).

%% Report §8.6, §6.6: waits for ever as an Ernest process waits with
%% nothing in flight, in a callForever nothing answers, its own, which the
%% look reads as a wait of Ernest's. A test's own receive is a wait in a
%% module of the host's, foreign code's to the look, and never a deadlock.
-spec forever() -> no_return().
forever() ->
    ern_rt:call_forever(ern_rt:self(), fun(Reply) -> {forever, Reply} end).

%% The trace messages of Pid still in the mailbox, taken out.
flushed(Pid) ->
    receive
        {trace, Pid, _, _} -> flushed(Pid);
        {trace, Pid, _, _, _} -> flushed(Pid)
    after 0 -> ok
    end.
