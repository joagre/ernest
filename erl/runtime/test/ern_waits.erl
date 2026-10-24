%% The waits the tests share, each on what it means rather than on a time
%% (CLAUDE.md, *No fixed sleep*): a process in a state, blocked in a receive
%% or in a call among them, a process having called a function or returned
%% from it, the runtime's reaper having looked for a deadlock, and the
%% deliveries to a process having ended. All but the last read what the
%% host reports of a process by tracing it, and stop tracing when they
%% return.
-module(ern_waits).

-export([until/2, waiting/1, running/1, calling/1, called/3, returned/3, looked/1,
         delivered/1, forever/0]).

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
    try erlang:trace(Pid, false, [running])
    catch error:badarg -> 0
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
                       [{status, waiting}, {_, {_, _}}] -> true;
                       _ -> false
                   end
               end).

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
%% times. A process of the run that waits here waits in a module of the
%% host's, a test's, which the look reads as foreign code in progress, so
%% it never seems deadlocked.
-spec looked(pos_integer()) -> ok.
looked(Count) ->
    called(ern_rt:launch_reaper(), {ern_rt, look, 0}, Count).

%% Report §6.9: until every delivery the runtime started to Recipient, of a
%% monitor's Down, an alarm or a fault report, has ended. A delivery sends
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
