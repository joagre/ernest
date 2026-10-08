%% The waits the tests share, each on what it means rather than on a time
%% (CLAUDE.md, *No fixed sleep*): a process in a state, blocked in a receive
%% among them, a process having called a function or returned from it, the
%% runtime's reaper having looked for a deadlock, and the deliveries to a
%% process having ended. All but the last read what the host reports of a
%% process by tracing it, and stop tracing when they return.
-module(ern_waits).

-export([until/2, waiting/1, running/1, called/3, returned/3, looked/1, delivered/1]).

%% Until Test, asked of Pid's state, holds, or Pid has ended: Test is asked
%% at first and again each time the host schedules Pid out, which is when
%% what Pid itself does has changed.
-spec until(pid(), fun(() -> boolean())) -> ok | ended.
until(Pid, Test) ->
    erlang:trace(Pid, true, [running]),
    try
        held(Pid, Test)
    after
        erlang:trace(Pid, false, [running]),
        flushed(Pid)
    end.

held(Pid, Test) ->
    case erlang:is_process_alive(Pid) andalso Test() of
        true -> ok;
        false ->
            case erlang:is_process_alive(Pid) of
                false -> ended;
                true -> receive {trace, Pid, out, _} -> held(Pid, Test) end
            end
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

%% Until Pid has called Module:Function/Arity Count times from now, which
%% the host shows by tracing its calls, local ones among them.
-spec called(pid(), mfa(), pos_integer()) -> ok.
called(Pid, {Module, Function, _} = MFA, Count) ->
    1 = erlang:trace_pattern(MFA, true, [local]),
    erlang:trace(Pid, true, [call]),
    try
        calls(Pid, Module, Function, Count)
    after
        erlang:trace(Pid, false, [call]),
        erlang:trace_pattern(MFA, false, [local]),
        flushed(Pid)
    end.

calls(_, _, _, 0) -> ok;
calls(Pid, Module, Function, Count) ->
    receive
        {trace, Pid, call, {Module, Function, _}} -> calls(Pid, Module, Function, Count - 1)
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
%% times. A process of the run that waits here and must not seem
%% deadlocked counts the wait as timed, as the compiler's timed receive
%% does.
-spec looked(pos_integer()) -> ok.
looked(Count) ->
    called(persistent_term:get({ern_rt, reaper}), {ern_rt, look, 0}, Count).

%% Report §6.9: until every delivery the runtime started to Recipient, of a
%% monitor's Down, an alarm or a fault report, has ended. A delivery sends
%% before it ends, so what it delivered is in Recipient's mailbox then.
-spec delivered(pid()) -> ok.
delivered(Recipient) ->
    Deliveries = [Pid || {{Target, _, Pid}} <- ets:tab2list(ern_deliveries), Target =:= Recipient],
    lists:foreach(fun(Pid) ->
                      MonitorRef = erlang:monitor(process, Pid),
                      receive {'DOWN', MonitorRef, process, Pid, _} -> ok end
                  end, Deliveries).

%% The trace messages of Pid still in the mailbox, taken out.
flushed(Pid) ->
    receive
        {trace, Pid, _, _} -> flushed(Pid);
        {trace, Pid, _, _, _} -> flushed(Pid)
    after 0 -> ok
    end.
