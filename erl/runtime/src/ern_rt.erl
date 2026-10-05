%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the runner.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(process, reason, site) is
%% {'Down', Pid, Reason, Site} in declared field order.
%%
%% An Address is a pid, or {via, Function, Target} for an address seen
%% through a function (report §6.5), which send/2 applies in the sender, or
%% {foreign, Pid, Descriptor, Bound} for an address foreign code gave
%% (report §8.4), whose messages cross into foreign code. A Reply(a) is the
%% alias of the call's monitor of its callee, as gen_server's call makes
%% one: it deactivates when the call is over, which drops a late answer
%% (report §6.6). Ernest answers {Reply, answered, Value} and foreign code
%% {Reply, Value}, so that a call checks the second only, as §8.4 says; a
%% Reply foreign code gave back is {foreign_reply, Reply, Descriptor,
%% Bound}, answered in the second form with the answer exposed.
%% Every process body runs under run/1, which turns an exception into an
%% exit reason that Down reports as a Fault. All spawns go through the
%% reaper process, which spawn_monitors each process; a monitor placed
%% after the death reports Unknown (report §6.9), and every monitor is the
%% reaper's. The reaper also detects deadlock (report §8.6): every live
%% process blocked in an untimed receive or in a wait for a call's answer,
%% no timed receive or clock alarm pending, no process inside foreign code,
%% and no source held that can still deliver.
%%
%% Nine tables hold a launch's state, each described where it is defined.
%% `ern_processes` has a row {Pid, Site, Timers, Foreign, SpawnOrder} per
%% process the runtime started or adopted, where Timers counts the timed
%% receives the process is in, Foreign its foreign calls, and SpawnOrder
%% its place in the order of spawns. `ern_calls` and `ern_callees` hold the
%% pending calls, `ern_faults` the subscriptions to faults, `ern_held` the
%% sources and the processes the system modules opened, `ern_deliveries`
%% the deliveries in flight, `ern_restarts` the restarts a process may be
%% asked, `ern_proxies` the checking proxies of §8.4, and `ern_launch` the
%% way the terminal is read and the process a deadlock faults.
-module(ern_rt).

-export([send/2, process_of/1, held/3, is_never_given/1, is_address/1, spawn/2, spawn_monitored/3,
         self/0, via/2, call/3, call/4, call_forever/2, call_forever/3, answer/2, refuse/2,
         monitor/2, kill/1, reason/1, live/0, processes/0, info/1, faults/1, proxy_for/3,
         proxy_forget/2, source_begin/0, source_begin/1, source_end/0, opened/2, forget_opened/1,
         timed/0, untimed/0, deadline/1, remaining/1, monotonic/0, in_foreign/1,
         undefined_function/3, undefined_lambda/3, fault_exit_reason/3, fault/1, fault/2, trace/1,
         system_process/1, hold_terminal/1, terminal_holder/0, shell_holds/0, own_terminal/1,
         input_not_utf8/0, by_input/1, read_input/1, run_main/3, tables/0, arguments/0,
         exit_program/1, deadlock_victim/1, signal/1, initializing/1, site/0, binding/1,
         restarting/2, restart_now/0, ask_restart/1, start_cause/0, spawn_order/1, init_stdlib/0,
         init_modules/1, ordered/1]).

-export_type([address/0]).

-compile({no_auto_import, [spawn/2, self/0, monitor/2]}).

-define(UNIT, 'Unit').
-define(PROCESSES, ern_processes).
%% report §6.6, §6.9: each pending call, {Caller, Callee, Reply}, so that a
%% callee that restarts ends the calls waiting on it; a process makes one
%% call at a time, since a message's function and via's are pure, so its
%% row is found and removed by its own pid
-define(CALLS, ern_calls).
%% the same calls by callee, {{Callee, Caller}, Reply}, ordered, so that a
%% restart reads its own callers and no other process's calls
-define(CALLEES, ern_callees).
%% Appendix E.21: each subscription to faults, {Subscriber, Address}, in a table
%% of its own, so that a fault reads the subscriptions and not every
%% process's row
-define(FAULTS, ern_faults).
%% report §8.6: what a system process, a listener, a socket or a running
%% program holds that can still deliver, {{source, Holder}, Count}, and the
%% processes the system modules opened, {{opened, Pid}}: few rows, so that
%% the deadlock check reads them without reading every process's
-define(HELD, ern_held).
%% report §6.9: each delivery a process started to a recipient,
%% {{Recipient, Starter, Pid}}, ordered, so that a restart of the recipient
%% reads its own deliveries and no other process's
-define(DELIVERIES, ern_deliveries).
%% report §6.9: the alias of each restart a process may be asked,
%% {Pid, Alias}
-define(RESTARTS, ern_restarts).
%% report §8.4: each checking proxy, {{proxy, Key}, Proxy}, and what it
%% stands in front of, {{behind, Proxy}, Pid, Address, Key}
-define(PROXIES, ern_proxies).
%% report §8.2, §8.6: the way the terminal is read, {reading, Kind}, and
%% the process a deadlock faults, {deadlock_victim, Pid}
-define(LAUNCH, ern_launch).
%% The longest wait the host's `receive ... after` takes, in milliseconds.
-define(SLICE, 16#FFFFFFFF).
%% How long the reaper waits without a message before it looks for a
%% deadlock, in milliseconds (report §8.6): soon after a message and while
%% nothing can deliver but a process still runs, which may be about to
%% wait; later while something can still deliver, since a deadlock can
%% begin only once that has ended. A program at rest pays for each look
%% with a wake-up of the host, so there the look comes seldom.
-define(LOOK_SOON, 100).
-define(LOOK_LATER, 1000).

-type address() :: pid() | {via, fun((term()) -> term()), address()}
                 | {foreign, pid(), term(), map()}.
%% Report §8.2: the system processes, by the names the runtime keeps them
%% under.
-type system() :: stdout | stderr | stdin | clock | fs | terminal | tcp | os.
-type reply() :: reference() | {foreign_reply, reference(), term(), map()}.
%% What a program's answer from foreign code is checked by: its descriptor
%% and the fault's cause, or none for the runtime's own calls.
-type check() :: none | {term(), binary()}.

%% The reaper's state. monitors: #{Pid => [{Caller, Wrap}]}, the monitors
%% of each process and the process that made each; Wrap(Down) is sent to
%% Caller, or for the runner, whose monitor is made with the spawn so that
%% no race can take the entry process's cause, {raw, Tag}: {Tag, Site,
%% ExitReason}. monitoring: #{Caller => [Pid]}, the processes each caller
%% monitors, so that a caller's death takes its monitors with it: nothing
%% is left to deliver them to. monitor_refs: #{Pid => MonitorRef}, a
%% process the runtime did not start, monitored here only while a monitor
%% of it stands.
-record(reaper, {monitors = #{}, monitoring = #{}, monitor_refs = #{}}).

%%
%% Report §6.2, §9.4
%%

-spec send(address(), term()) -> 'Unit'.
send(Address, Message) ->
    deliver(Address, Message),
    ?UNIT.

%% Report §6.5: an address seen through a function is the target and the
%% function, not a process of its own, so sending applies the function here
%% and the message goes straight into the target's mailbox. A fault in the
%% function is the target's, since the function is part of the protocol the
%% target's own via(self(), wrap) built.
deliver({via, Function, Target}, Message) ->
    try Function(Message) of
        Adapted -> deliver(Target, Adapted)
    catch
        Class:Error:Stack -> exit(process_of(Target), fault_exit_reason(Class, Error, Stack))
    end;
%% report §8.4: a message to a foreign address crosses into foreign code
deliver({foreign, Pid, Descriptor, Bound}, Message) ->
    Pid ! ern_boundary:expose(Descriptor, Message, Bound);
deliver(Pid, Message) ->
    Pid ! Message.

%% The process an address names, through any number of adaptations and
%% through the checking proxy of §8.4: an address that has crossed into
%% foreign code comes back as the proxy in front of it, and what the
%% runtime holds of a process, its terminal, its monitors, its death,
%% must be the process itself.
-spec process_of(address()) -> pid().
process_of({via, _, Target}) -> process_of(Target);
process_of({foreign, Pid, _, _}) -> Pid;
process_of(Pid) -> behind(Pid).

behind(Pid) ->
    case ets_lookup(?PROXIES, {behind, Pid}) of
        [{_, Real, _, _}] -> Real;
        _ -> Pid
    end.

%% Report §8.4: an address foreign code gave, whose messages Descriptor
%% describes inside the mu bindings Bound, as the program holds it: where
%% it is the proxy in front of one of the program's processes, the address
%% that went out, the proxy undone and a function `via` made kept (§6.5),
%% and otherwise foreign. A proxy comes back as the address that went out
%% only at the type it went out at; at another it stays foreign, so that
%% what is sent through it is checked against the process's own type. A
%% process of the program's with no proxy in front of it reaches here only
%% as an `Address(Never)`, the check refusing it at any other type
%% (is_never_given/1), and is held foreign, nothing passing through it.
-spec held(pid(), term(), map()) -> address().
held(Pid, Descriptor, Bound) ->
    case ets_lookup(?PROXIES, {behind, Pid}) of
        [{_, Real, Exposed, {_, Descriptor, Bound}}] ->
            case ets_lookup(?PROCESSES, Real) of
                [_] -> Exposed;
                [] -> {foreign, Pid, Descriptor, Bound}
            end;
        _ ->
            {foreign, Pid, Descriptor, Bound}
    end.

%% Report §8.4: whether foreign code gives as an address a process of the
%% program's whose address it was never given: one the program runs, with
%% no proxy, which every address that crossed into foreign code has.
-spec is_never_given(term()) -> boolean().
is_never_given(Pid) when is_pid(Pid) ->
    ets_lookup(?PROXIES, {behind, Pid}) =:= [] andalso ets_lookup(?PROCESSES, Pid) =/= [];
is_never_given(_) ->
    false.

%% Whether a term is an address in one of the forms the runtime holds.
-spec is_address(term()) -> boolean().
is_address(Pid) when is_pid(Pid) -> true;
is_address({via, Function, Target}) when is_function(Function, 1) -> is_address(Target);
is_address({foreign, Pid, _, _}) -> is_pid(Pid);
is_address(_) -> false.

%% Site names the spawning function for Down (report §6.9); the compiler
%% supplies it, so this is spawn/2 where the report's spawn takes one.
-spec spawn(fun(() -> term()), binary()) -> address().
spawn(Function, Site) ->
    spawn_with_monitors(Function, Site, []).

%% Report §6.2, §6.9: a process monitored by the caller from its start, the
%% wait made with the spawn, so that no end comes before it.
-spec spawn_monitored(fun(() -> term()), fun((term()) -> term()), binary()) -> pid().
spawn_monitored(Function, Wrap, Site) ->
    spawn_with_monitors(Function, Site, [{erlang:self(), Wrap}]).

spawn_with_monitors(Function, Site, Monitors) ->
    Ref = make_ref(),
    persistent_term:get({?MODULE, reaper}) ! {spawn, erlang:self(), Ref, Function, Site, Monitors},
    receive
        {Ref, Pid} -> Pid
    end.

-spec self() -> address().
self() ->
    erlang:self().

%%
%% Report §6.5, §9.5
%%

-spec via(address(), fun((term()) -> term())) -> address().
via(Target, Function) ->
    {via, Function, Target}.

%%
%% Report §6.6
%%

%% Report §6.6: the runtime's own call, whose answer is not checked (§8.4).
-spec call(address(), fun((reply()) -> term()), integer()) -> 'None' | {'Some', term()}.
call(Address, Request, Ms) ->
    call(Address, Request, Ms, none).

%% Report §6.6, §8.4: a program's call, whose answer from foreign code is
%% checked by Check.
-spec call(address(), fun((reply()) -> term()), integer(), check()) ->
          'None' | {'Some', term()}.
call(Address, Request, Ms, Check) ->
    %% report §6.6: the clock starts at the call, before the request is
    %% made and delivered
    Deadline = deadline(Ms),
    line_guard(Address),
    Reply = pending(Address),
    %% settled however the call ends, a fault of the message's function or
    %% of the callee among the ways, which a process restarted in place
    %% outlives (§6.9)
    Answer = try
                 deliver(Address, Request(Reply)),
                 timed(),
                 try waited_answer(Reply, Deadline, Check) after untimed() end
             after
                 settled(Reply)
             end,
    case Answer of
        %% report §6.9: a restart asked for is taken at a call's wait
        '$ern_restart' -> restart_now();
        _ -> Answer
    end.

%% Report §6.6: the answer, or None after the deadline, or at once when the
%% callee ends or restarts before it answers.
waited_answer(Reply, Deadline, Check) ->
    receive
        {Reply, answered, Value} -> {'Some', Value};
        {Reply, Value} -> {'Some', foreign_answer(Check, Value)};
        {Reply, restarted, _} -> 'None';
        {Reply, fault, Cause} -> fault(Cause);
        {'DOWN', Reply, process, _, _} -> 'None';
        '$ern_restart' -> '$ern_restart';
        %% report §8.4: a foreign message's fault, taken at a call's wait
        {'$ern_fault', Cause} -> fault(Cause)
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 -> 'None';
            _ -> waited_answer(Reply, Deadline, Check)
        end
    end.

%% Report §6.6: the runtime's own callForever (§8.4).
-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Address, Request) ->
    call_forever(Address, Request, none).

%% Report §6.6, §8.4: a program's callForever, whose answer from foreign
%% code is checked by Check.
-spec call_forever(address(), fun((reply()) -> term()), check()) -> term().
call_forever(Address, Request, Check) ->
    line_guard(Address),
    Reply = pending(Address),
    %% settled however the call ends, as call/4's is
    Answer = try
                 deliver(Address, Request(Reply)),
                 receive
                     {Reply, answered, Value} -> {answered, Value};
                     {Reply, Value} -> {answered, foreign_answer(Check, Value)};
                     {Reply, restarted, CalleeCause} -> {fault, CalleeCause};
                     %% report §8.2: a system process faults the caller it
                     %% answers
                     {Reply, fault, SystemCause} -> {fault, SystemCause};
                     {'DOWN', Reply, process, _, CalleeExitReason} -> {ended, CalleeExitReason};
                     %% report §6.9: a restart asked for is taken at a call's
                     %% wait
                     '$ern_restart' -> restart;
                     %% report §8.4: a foreign message's fault, taken there too
                     {'$ern_fault', ForeignCause} -> {fault, ForeignCause}
                 end
             after
                 settled(Reply)
             end,
    case Answer of
        {answered, Answered} -> Answered;
        {fault, Cause} -> fault(Cause);
        %% report §6.6, Appendix E.18: a socket or a listener the program
        %% closed ended as a function returns, and its caller learns why
        {ended, {ern, closed}} -> fault(<<"callee was closed">>);
        {ended, ExitReason} -> ended(reason(ExitReason));
        restart -> restart_now()
    end.

%% Report §8.4: an answer foreign code gave, checked against the reply's
%% type as a foreign function's return is.
foreign_answer(none, Value) -> Value;
foreign_answer({Descriptor, Cause}, Value) -> ern_boundary:value(Descriptor, Value, Cause).

%% Report §6.6, §7.4: a callForever whose callee ended faults the caller with
%% the callee's cause, or says how it ended; with the program the caller
%% ends too.
-spec ended(term()) -> no_return().
ended({'Fault', Cause}) -> fault(Cause);
ended('Killed') -> fault(<<"callee was killed">>);
ended('Returned') -> fault(<<"callee returned without answering">>);
ended('Unknown') -> fault(<<"callee had ended">>);
ended('ProgramEnd') ->
    %% a signal, not an exception, which run/1 would take for a fault
    exit(erlang:self(), {ern, program_end}),
    receive after infinity -> ok end.

%% A call's monitor of the process behind the address, whose alias is the
%% reply's, and the call noted against that process, so that its restart
%% ends the call.
pending(Address) ->
    Callee = process_of(Address),
    Reply = erlang:monitor(process, Callee, [{alias, demonitor}]),
    ets:insert(?CALLS, {erlang:self(), Callee, Reply}),
    ets:insert(?CALLEES, {{Callee, erlang:self()}, Reply}),
    Reply.

%% The call is over: its rows go, its monitor and with it the alias go, and
%% every answer that came before them, after a restart's word, say, is not
%% left in the caller's mailbox.
settled(Reply) ->
    uncalled(erlang:self()),
    erlang:demonitor(Reply, [flush]),
    flushed(Reply).

%% The pending call of Caller, gone from both tables.
uncalled(Caller) ->
    case ets:take(?CALLS, Caller) of
        [{_, Callee, _}] -> ets:delete(?CALLEES, {Callee, Caller});
        [] -> true
    end.

flushed(Reply) ->
    receive
        {Reply, _} -> flushed(Reply);
        {Reply, _, _} -> flushed(Reply)
    after 0 ->
        ok
    end.

%% Report §6.6, §8.4: an answer in Ernest's form, or in foreign code's for a
%% Reply foreign code gave back, which the caller checks and which crosses
%% into foreign code.
-spec answer(reply(), term()) -> 'Unit'.
answer({foreign_reply, Reply, Descriptor, Bound}, Value) ->
    Reply ! {Reply, ern_boundary:expose(Descriptor, Value, Bound)},
    ?UNIT;
answer(Reply, Value) ->
    Reply ! {Reply, answered, Value},
    ?UNIT.

%% Report §8.2, §7.4: a system process faults the caller it answers.
-spec refuse(reply(), binary()) -> 'Unit'.
refuse({foreign_reply, Reply, _, _}, Cause) ->
    refuse(Reply, Cause);
refuse(Reply, Cause) ->
    Reply ! {Reply, fault, Cause},
    ?UNIT.

%%
%% Report §6.9
%%

%% Every monitor is the reaper's: it holds the wrap and delivers the cause,
%% at once if the process is already dead. A process the runtime did not
%% start, a system process, a socket or a running program, is monitored from
%% there too, so a monitor costs no process of its own (report §6.9). The
%% monitor is made when the reaper says so, so that a process killed just
%% after it is seen to die rather than found already ended.
-spec monitor(pid(), fun((term()) -> term())) -> 'Unit'.
monitor(Process, Wrap) ->
    Ref = make_ref(),
    Reaper = persistent_term:get({?MODULE, reaper}),
    %% a Process foreign code gave back may be the proxy before the process
    Reaper ! {monitor, process_of(Process), erlang:self(), Wrap, Ref},
    receive {Ref, monitored} -> ?UNIT end.

-spec kill(address()) -> 'Unit'.
kill(Address) ->
    %% report §8.2: no program can name a system process, whose reference is
    %% private to its module, so any address given here is a program's
    exit(process_of(Address), {ern, killed}),
    ?UNIT.

-spec reason(term()) -> term().
reason(normal) -> 'Returned';
%% report §6.9, Appendix E.18: a socket or a listener the program closed
%% returned, for a monitor; its caller faults with its own cause
reason({ern, closed}) -> 'Returned';
reason({ern, killed}) -> 'Killed';
reason({ern, program_end}) -> 'ProgramEnd';
%% report §7.3, §11.2: a process still in a version of a module the shell
%% has replaced twice
reason({ern, code_unloaded}) -> {'Fault', <<"its code was unloaded">>};
reason({ern, fault, Cause}) -> {'Fault', Cause};
%% report §6.9, §11.2: the host's stack is the report's, never the cause's
reason({ern, fault, Cause, _Trace}) -> {'Fault', Cause};
%% report §6.9: a monitor made after the end cannot say how it ended
reason(noproc) -> 'Unknown';
reason(Other) -> {'Fault', format("~p", [Other])}.

%% The reaper: spawns on request with a monitor of its own, keeps each live
%% process's row, and tells each process that monitors another how it
%% ended. Report §6.9: of a process that has ended it keeps nothing, so a
%% monitor made after the end answers Unknown.
reaper_loop(Reaper) ->
    reaper_loop(Reaper, ?LOOK_SOON).

reaper_loop(Reaper, Wait) ->
    receive
        {spawn, From, Ref, Function, Site, SpawnMonitors} ->
            reaper_loop(spawned(From, Ref, Function, Site, SpawnMonitors, Reaper));
        {adopt, Pid, Site, From, Ref} ->
            adopted(Pid, Site, From, Ref),
            reaper_loop(Reaper);
        {monitor, Pid, Caller, Wrap, Ref} ->
            reaper_loop(monitored(Pid, Caller, Wrap, Ref, Reaper));
        {report, Pid, Site, Fault} ->
            report(Pid, Site, Fault, true),
            reaper_loop(Reaper);
        {new_run, Pid, Ref} ->
            reaper_loop(new_run(Pid, Ref, Reaper));
        {end_program, From, Ref} ->
            ended_program(From, Ref);
        {'DOWN', _MonitorRef, process, Pid, ExitReason} ->
            reaper_loop(down(Pid, ExitReason, Reaper))
    after Wait ->
        case look() of
            deadlock ->
                deadlock(),
                reaper_loop(Reaper);
            running ->
                reaper_loop(Reaper);
            delivering ->
                reaper_loop(Reaper, ?LOOK_LATER)
        end
    end.

%% A process spawned on request, which starts once its row is in the
%% table, since a timed receive it enters first counts itself there
%% (§8.6). A monitor made with the spawn, spawnMonitored's, stands as
%% monitor's does.
spawned(From, Ref, Function, Site, SpawnMonitors,
        #reaper{monitors = Monitors, monitoring = Monitoring} = Reaper) ->
    Started = fun() -> receive Ref -> run(Function) end end,
    {Pid, _MonitorRef} = erlang:spawn_monitor(Started),
    ets:insert(?PROCESSES, {Pid, Site, 0, 0, next_spawn_order()}),
    Pid ! Ref,
    From ! {Ref, Pid},
    Monitoring1 = lists:foldl(fun({Caller, _}, Acc) -> added(Caller, Pid, Acc) end,
                              Monitoring, SpawnMonitors),
    Monitors1 = case SpawnMonitors of
                    [] -> Monitors;
                    _ -> Monitors#{Pid => SpawnMonitors}
                end,
    Reaper#reaper{monitors = Monitors1, monitoring = Monitoring1}.

%% Report Appendix E.18, E.23: a listener, a socket or a running program,
%% which its system process starts, is a process of the program's as one
%% spawned is, monitored here and listed.
adopted(Pid, Site, From, Ref) ->
    _ = erlang:monitor(process, Pid),
    ets:insert(?PROCESSES, {Pid, Site, 0, 0, next_spawn_order()}),
    From ! {Ref, adopted}.

%% A monitor of Pid that Caller made. A process the runtime did not start
%% is monitored from here; report §8.6: its death would deliver a message,
%% which is a source while a monitor of it stands.
monitored(Pid, Caller, Wrap, Ref,
          #reaper{monitors = Monitors, monitoring = Monitoring,
                  monitor_refs = MonitorRefs} = Reaper) ->
    MonitorRefs1 = case ets:lookup(?PROCESSES, Pid) of
                       [] when not is_map_key(Pid, MonitorRefs) ->
                           source_begin(),
                           MonitorRefs#{Pid => erlang:monitor(process, Pid)};
                       _ ->
                           MonitorRefs
                   end,
    Caller ! {Ref, monitored},
    Reaper#reaper{monitors = added(Pid, {Caller, Wrap}, Monitors),
                  monitoring = added(Caller, Pid, Monitoring), monitor_refs = MonitorRefs1}.

%% Report §6.9: a restarted process's monitors and its subscription to
%% faults are cancelled, with what is on its way to it; the monitors of it
%% stand, since a restart is not a death.
new_run(Pid, Ref, #reaper{monitors = Monitors, monitoring = Monitoring,
                          monitor_refs = MonitorRefs}) ->
    ets:delete(?FAULTS, Pid),
    {Monitors1, MonitorRefs1} = unmonitored(Pid, maps:get(Pid, Monitoring, []), Monitors,
                                            MonitorRefs),
    cancelled(Pid),
    Pid ! {Ref, fresh},
    #reaper{monitors = Monitors1, monitoring = maps:remove(Pid, Monitoring),
            monitor_refs = MonitorRefs1}.

%% A process that ended: each monitor of it told, and the monitors of it,
%% and its own, gone.
down(Pid, ExitReason, #reaper{monitors = Monitors, monitoring = Monitoring,
                              monitor_refs = MonitorRefs} = Reaper) ->
    delivered_down(Pid, ExitReason, Reaper),
    case is_map_key(Pid, Monitors) orelse is_map_key(Pid, Monitoring)
        orelse is_map_key(Pid, MonitorRefs) of
        false ->
            %% nothing monitored it, and it monitored nothing
            Reaper;
        true ->
            Monitoring1 = lists:foldl(fun({Caller, _}, Acc) -> forgotten(Caller, Pid, Acc) end,
                                      maps:remove(Pid, Monitoring), maps:get(Pid, Monitors, [])),
            {Monitors1, MonitorRefs1} = unmonitored(Pid, maps:get(Pid, Monitoring, []),
                                                    maps:remove(Pid, Monitors),
                                                    maps:remove(Pid, MonitorRefs)),
            #reaper{monitors = Monitors1, monitoring = Monitoring1, monitor_refs = MonitorRefs1}
    end.

%% Each monitor of a process that ended told how. A process the runtime
%% started leaves its pending call, which one killed while it waited
%% leaves; a caller learns of a callee's end by its own monitor, and
%% removes its own. Report §6.9: the spawn site of a process the runtime
%% did not start, or of one that had ended, is not known.
delivered_down(Pid, ExitReason, #reaper{monitors = Monitors, monitor_refs = MonitorRefs}) ->
    case ets:take(?PROCESSES, Pid) of
        [{_, Site, _, _, _}] ->
            uncalled(Pid),
            died(Pid, Site, ExitReason),
            Down = {'Down', Pid, reason(ExitReason), Site},
            lists:foreach(fun({Caller, {raw, Tag}}) -> Caller ! {Tag, Site, ExitReason};
                             ({Caller, Wrap}) -> wrapped(Caller, Wrap, Down)
                          end, maps:get(Pid, Monitors, []));
        [] ->
            Down = {'Down', Pid, reason(ExitReason), <<>>},
            lists:foreach(fun({Caller, Wrap}) -> wrapped(Caller, Wrap, Down) end,
                          maps:get(Pid, Monitors, [])),
            is_map_key(Pid, MonitorRefs) andalso source_end()
    end.

%% Report §8.6, §11.2: a deadlock is the entry process's fault, or under
%% `ern test` the fault of the test that runs.
deadlock() ->
    case ets:take(?LAUNCH, deadlock_victim) of
        [{_, Victim}] ->
            exit(Victim, {ern, fault, <<"deadlock">>});
        [] ->
            {Runner, Launch} = persistent_term:get({?MODULE, runner}),
            Runner ! {deadlock, Launch}
    end.

%% Appendix E.22: the spawn order of the next process the reaper starts or
%% adopts, which grows with each, so that processes are in the order they
%% were spawned.
next_spawn_order() ->
    erlang:unique_integer([monotonic, positive]).

%% Report §8.6: the program's end ends every process the runtime started.
%% The reaper spawns each, so it ends them: every one it has spawned, and
%% none after, since a spawn it is asked for then was asked by a process
%% that is itself ending. It answers nothing more until it is stopped.
ended_program(From, Ref) ->
    lists:foreach(fun({Pid, _, _, _, _}) -> exit(Pid, {ern, program_end}) end, live_rows()),
    From ! {Ref, ended},
    ended_program().

ended_program() ->
    receive _ -> ended_program() end.

%% Lists, a map to lists, with Value added to Key's list.
added(Key, Value, Lists) ->
    maps:update_with(Key, fun(Values) -> [Value | Values] end, [Value], Lists).

%% Lists, a map to lists, with Gone taken from Key's list, and Key gone with
%% the list's last: a process that ended, from the processes its caller
%% monitors; the clock's timer that fired, from its recipient's.
forgotten(Key, Gone, Lists) ->
    case maps:get(Key, Lists, []) -- [Gone] of
        [] -> maps:remove(Key, Lists);
        Left -> Lists#{Key => Left}
    end.

%% The monitors of a caller that died, taken from the processes it
%% monitored. A process the runtime did not start that no monitor stands of
%% any longer is no longer monitored, and no longer a source (report
%% §8.6).
unmonitored(_Caller, [], Monitors, MonitorRefs) ->
    {Monitors, MonitorRefs};
unmonitored(Caller, [Pid | Rest], Monitors, MonitorRefs) ->
    case [Monitor || {OtherCaller, _} = Monitor <- maps:get(Pid, Monitors, []),
                     OtherCaller =/= Caller] of
        [] when is_map_key(Pid, MonitorRefs) ->
            erlang:demonitor(maps:get(Pid, MonitorRefs), [flush]),
            source_end(),
            unmonitored(Caller, Rest, maps:remove(Pid, Monitors), maps:remove(Pid, MonitorRefs));
        [] ->
            unmonitored(Caller, Rest, maps:remove(Pid, Monitors), MonitorRefs);
        Left ->
            unmonitored(Caller, Rest, Monitors#{Pid => Left}, MonitorRefs)
    end.

%% Report §6.9, §6.5: a monitor's wrap is applied as `via`'s function is, a
%% fault in it being the fault of the process it delivers to, and in a
%% process of its own, so that a wrap that does not finish holds up no
%% other delivery. The message counts as a source until it is delivered
%% (§8.6). Linked, so that one that never finishes ends with the program.
wrapped(Caller, Wrap, Down) ->
    counted_link(Caller, fun() -> deliver({via, Wrap, Caller}, Down) end).

%% Report §8.6: a process that will deliver a message to the process behind
%% Address, counted as a source from before it starts until its work is done,
%% and linked, so that one that never finishes ends with the process that
%% started it. Report §6.9: it is noted against its recipient and the
%% process that started it, which ends it when the recipient restarts
%% (cancelled/1).
counted_link(Address, Work) ->
    Recipient = process_of(Address),
    Starter = erlang:self(),
    Pid = erlang:spawn_link(fun() ->
                                receive go -> Work(), delivered(Recipient, Starter) end
                            end),
    try ets:insert(?DELIVERIES, {{Recipient, Starter, Pid}}) catch _:_ -> true end,
    source_begin(Pid),
    Pid ! go.

delivered(Recipient, Starter) ->
    try ets:delete(?DELIVERIES, {Recipient, Starter, erlang:self()}) catch _:_ -> true end,
    source_end().

%% Report §6.9: the deliveries this process started to Recipient, ended
%% when Recipient restarts, each waited for, so that none reaches the new
%% run.
cancelled(Recipient) ->
    Starter = erlang:self(),
    Mine = try ets:select(?DELIVERIES, [{{{Recipient, Starter, '$1'}}, [], ['$1']}])
           catch _:_ -> []
           end,
    lists:foreach(fun(Pid) ->
                      MonitorRef = erlang:monitor(process, Pid),
                      erlang:unlink(Pid),
                      exit(Pid, kill),
                      receive {'DOWN', MonitorRef, process, Pid, _} -> ok end,
                      ets:delete(?DELIVERIES, {Recipient, Starter, Pid}),
                      ets:delete(?HELD, {source, Pid})
                  end, Mine).

%% The live processes the runtime started with their spawn sites, which
%% the shell's :reload reads to find what still runs a module.
-spec live() -> [{pid(), binary()}].
live() ->
    try [{Pid, Site} || {Pid, Site, _, _, _} <- live_rows()]
    catch _:_ -> []
    end.

%% Appendix E.21: Process.live, the live processes the runtime started or
%% adopted, the system processes excepted, which are the runtime's.
-spec processes() -> [pid()].
processes() ->
    [Pid || {Pid, _} <- live()].

%% Appendix E.21: Process.info, a snapshot of a live process, None once it
%% has ended and for a process on another node. A process waiting for a
%% call's answer is Calling, which the host's status does not tell from a
%% receive: its pending call is in the table of calls (§6.6).
-spec info(pid()) -> 'None' | {'Some', {'Info', binary(), non_neg_integer(), atom()}}.
info(Pid) when node(Pid) =:= node() ->
    case {ets_lookup(?PROCESSES, Pid),
          erlang:process_info(Pid, [status, message_queue_len])} of
        {[{_, Site, _, _, _}], [{status, Status}, {message_queue_len, Queued}]} ->
            Activity = case Status of
                           waiting ->
                               case ets_lookup(?CALLS, Pid) of
                                   [] -> 'Receiving';
                                   _ -> 'Calling'
                               end;
                           _ -> 'Running'
                       end,
            {'Some', {'Info', Site, Queued, Activity}};
        _ ->
            'None'
    end;
info(_) ->
    'None'.

ets_lookup(Table, Key) ->
    try ets:lookup(Table, Key) catch _:_ -> [] end.

%% The rows of Table that match Pattern, none where the table has gone.
matching_rows(Table, Pattern) ->
    try ets:match_object(Table, Pattern) catch _:_ -> [] end.

%% Appendix E.21: Process.faults, the caller subscribed to every fault of
%% every process the runtime started, Address being the caller seen through its
%% wrap. A process holds one subscription, the latest, which ends when it
%% dies (the reaper's DOWN).
-spec faults(address()) -> 'Unit'.
faults(Address) ->
    try ets:insert(?FAULTS, {process_of(Address), Address}) catch _:_ -> true end,
    ?UNIT.

%% Report §11.2, Appendix E.21: a fault, which each subscriber is sent as a
%% FaultReport, each delivery a process of its own as a monitor's is, and
%% which `ern run`'s reporter, the runtime's own subscriber, is given as it
%% happens, before the process's end reaches anyone who waits on it. The
%% fields are in declared order: process, site, cause, restarted, trace.
%% The reaper reports, so that a delivery is linked to a process that lives
%% as long as the run; a process that restarts sends it its fault.
report(Pid, Site, Fault, Restarted) ->
    {Cause, Trace} = case Fault of
                         {ern, fault, FaultCause, FaultTrace} -> {FaultCause, FaultTrace};
                         {ern, fault, FaultCause} -> {FaultCause, <<>>};
                         _ -> {'Fault', Described} = reason(Fault), {Described, <<>>}
                     end,
    Report = {'FaultReport', Pid, Site, Cause, Restarted, Trace},
    case persistent_term:get({?MODULE, reporter}, undefined) of
        undefined -> ok;
        Reporter -> Reporter(Report)
    end,
    Subscribers = [Address || {_, Address} <- matching_rows(?FAULTS, '_')],
    lists:foreach(fun(Address) ->
                      counted_link(Address, fun() -> deliver(Address, Report) end)
                  end, Subscribers).

%% The live processes' rows, each its pid, its spawn site, the counts of its
%% timed waits and of its foreign calls in progress, and its spawn order.
live_rows() ->
    ets:tab2list(?PROCESSES).

%% Report §6.9, §11.2: a process that ended faulting is reported, and a
%% subscription to faults it held ends with it.
died(Pid, Site, ExitReason) ->
    ets:delete(?FAULTS, Pid),
    ets:delete(?RESTARTS, Pid),
    case reason(ExitReason) of
        {'Fault', _} -> report(Pid, Site, ExitReason, false);
        _ -> ok
    end.

%% Report §8.6. Two snapshots of every live process's status and reduction
%% count, equal, with every status waiting, prove that nothing ran between
%% them; what is counted is read between them, so that it is what held
%% while nothing ran, and not what held before a process ran on. A timed
%% receive, a foreign call in progress, a source held by a system process,
%% and a call waiting on one are what can still deliver.
%%
%% The check runs when the reaper has been idle a while, and what can still
%% deliver is read first, the cheapest first: an idle program that waits on
%% something, a socket or an alarm, is answered from a few rows, and only a
%% program in which nothing can deliver has its processes read, twice.
%%
%% A system process is not in the table, so its mailbox and status are read
%% as well: between taking a message out and counting the source it holds,
%% it is running rather than waiting, and the check sees that. A request a
%% program sends to it is counted by the sender before it is sent, as a call
%% (calling_the_system/0), since a request still in transit is not seen at
%% its receiver. The reaper is the process making the check, so its own
%% mailbox is what is read of it. §8.6 leaves a foreign process that can
%% deliver to the runtime. Report §11.2: nothing is a deadlock while a
%% shell holds the terminal.
%% What the look finds: `delivering`, where something can still deliver or
%% a shell holds the terminal, so that no deadlock can begin before that
%% ends; `running`, where nothing can and a process is not waiting, or
%% none is left; `deadlock`, where nothing can and every process waits.
look() ->
    case terminal_holder() =:= undefined andalso nothing_delivers() of
        false ->
            delivering;
        true ->
            Pids = [Pid || {Pid, _, _, _, _} <- live_rows()],
            First = snapshot(Pids),
            Waits = Pids =/= []
                andalso lists:all(fun({_, Status, _}) -> Status =:= waiting end, First)
                andalso nothing_delivers()
                andalso snapshot(Pids) =:= First,
            case Waits of
                true -> deadlock;
                false -> running
            end
    end.

nothing_delivers() ->
    sources() =:= 0
        andalso not calling_the_system()
        andalso quiet_system()
        andalso not counted().

%% Whether a process is in a timed receive or a foreign call, found at the
%% first such row.
counted() ->
    ets:select(?PROCESSES, [{{'_', '_', '$1', '$2', '_'},
                             [{'orelse', {'>', '$1', 0}, {'>', '$2', 0}}], [true]}], 1)
        =/= '$end_of_table'.

%% A call waiting on a system process, a listener, a socket or a running
%% program is a pending I/O from before its request is sent, as the call's
%% row is (pending/1): signals from two senders are not ordered, so a
%% request still in transit is not seen at its receiver.
calling_the_system() ->
    Held = system_pids() ++ opened(),
    lists:any(fun({_, Callee, _}) -> lists:member(Callee, Held) end, matching_rows(?CALLS, '_')).

quiet_system() ->
    erlang:process_info(erlang:self(), message_queue_len) =:= {message_queue_len, 0}
        andalso lists:all(fun quiet/1, system_pids() ++ opened()).

%% Report §8.2: the run's system processes that have been started.
system_pids() ->
    [Pid || Name <- [stdout, stderr, stdin, clock, fs, terminal, tcp, os],
            Pid <- [persistent_term:get({?MODULE, Name}, undefined)], Pid =/= undefined].

%% A system process that has died can deliver nothing.
quiet(Pid) ->
    case erlang:process_info(Pid, [status, message_queue_len]) of
        [{status, waiting}, {message_queue_len, 0}] -> true;
        undefined -> true;
        _ -> false
    end.

snapshot(Pids) ->
    [case erlang:process_info(Pid, [status, reductions]) of
         [{status, Status}, {reductions, Reductions}] -> {Pid, Status, Reductions};
         undefined -> {Pid, dead, 0}
     end || Pid <- Pids].

%% Report §8.4: the checking proxy in front of an address exposed to
%% foreign code is one per address and mailbox type, not one per call: two
%% proxies checking the same messages for the same process are two of the
%% same thing. The loser of a race is killed and the winner used.
-spec proxy_for(term(), address(), fun(() -> pid())) -> pid().
proxy_for(Key, Behind, Start) ->
    case ets:lookup(?PROXIES, {proxy, Key}) of
        [{_, Pid}] ->
            Pid;
        [] ->
            Pid = Start(),
            case ets:insert_new(?PROXIES, {{proxy, Key}, Pid}) of
                true ->
                    %% what the proxy stands before, and the key, which
                    %% holds the type it checks (ern_boundary:proxy/4)
                    ets:insert(?PROXIES, {{behind, Pid}, process_of(Behind), Behind, Key}),
                    Pid;
                false ->
                    exit(Pid, kill),
                    [{_, Winner}] = ets:lookup(?PROXIES, {proxy, Key}),
                    Winner
            end
    end.

-spec proxy_forget(term(), pid()) -> ok.
proxy_forget(Key, Proxy) ->
    %% the table is gone once the program has ended (report §8.6)
    try
        ets:delete(?PROXIES, {proxy, Key}),
        ets:delete(?PROXIES, {behind, Proxy})
    catch _:_ -> true
    end,
    ok.

%% Report §8.6: what a system process, a listener, or a socket holds that
%% can still deliver, a timer, a subscription, or a request in progress.
%% Each is counted while it is held, since a process that is inside a read
%% cannot answer a question, and counted against its holder, whose row goes
%% when its count is 0 or when it is forgotten (forget_opened/1). A holder
%% may be counted by the process that starts it, before it runs, so that
%% no answer comes before its count.
-spec source_begin() -> ok.
source_begin() ->
    source_begin(erlang:self()).

-spec source_begin(pid()) -> ok.
source_begin(Holder) ->
    Key = {source, Holder},
    try ets:update_counter(?HELD, Key, {2, 1}, {Key, 0}) catch _:_ -> 0 end,
    ok.

-spec source_end() -> ok.
source_end() ->
    Key = {source, erlang:self()},
    try ets:update_counter(?HELD, Key, {2, -1}) of
        0 -> ets:delete_object(?HELD, {Key, 0});
        _ -> true
    catch _:_ ->
        true
    end,
    ok.

sources() ->
    try
        lists:sum([Count || [Count] <- ets:match(?HELD, {{source, '_'}, '$1'})])
    catch _:_ ->
        1
    end.

%% Report §8.6, Appendix E.18, E.23: a listener, a socket or a running
%% program, which a system module's functions open, is checked as a system
%% process is, a request in its mailbox being a message in flight. It is
%% recorded by the process that starts it, before its address is given out,
%% and forgotten with its sources when it ends, which the process it is
%% linked to learns. Report Appendix E.21: it is a process of the program's
%% too, listed by Process.live, known to Process.info and reported by
%% Process.faults, under Site, the function that opened it.
-spec opened(pid(), binary()) -> ok.
opened(Pid, Site) ->
    try ets:insert(?HELD, {{opened, Pid}}) catch _:_ -> true end,
    case persistent_term:get({?MODULE, reaper}, none) of
        none ->
            ok;
        Reaper ->
            Ref = make_ref(),
            Reaper ! {adopt, Pid, Site, erlang:self(), Ref},
            receive {Ref, adopted} -> ok end
    end.

-spec forget_opened(pid()) -> ok.
forget_opened(Pid) ->
    try
        ets:delete(?HELD, {opened, Pid}),
        ets:delete(?HELD, {source, Pid})
    catch _:_ ->
        true
    end,
    ok.

opened() ->
    try [Pid || [Pid] <- ets:match(?HELD, {{opened, '$1'}})] catch _:_ -> [] end.

%% A timed receive counts itself in before and out first in every body,
%% so tail position holds; the compiler emits the calls (report §8.6).
-spec timed() -> ok.
timed() ->
    count(3, 1).

-spec untimed() -> ok.
untimed() ->
    count(3, -1).

%% Report §6.3, §6.6, Appendix E.0 rule 8: a time has no upper bound, and a
%% time below 0 is 0. The host waits at most ?SLICE at once, so a wait is
%% made against the moment its time ends, on the monotonic clock, in waits
%% of at most ?SLICE each; the compiler emits the same loop for `after`.
-spec deadline(integer()) -> integer().
deadline(Ms) ->
    erlang:monotonic_time(millisecond) + max(0, Ms).

%% The next wait towards the deadline; 0 once it has passed.
-spec remaining(integer()) -> 0..?SLICE.
remaining(Deadline) ->
    min(?SLICE, max(0, Deadline - erlang:monotonic_time(millisecond))).

%% Appendix E.15: Clock.monotonic, milliseconds since a moment the runtime
%% chose, which never go back.
-spec monotonic() -> integer().
monotonic() ->
    erlang:monotonic_time(millisecond).

%% Report §8.4, §8.6: a process inside foreign code is not waiting.
-spec in_foreign(fun(() -> term())) -> term().
in_foreign(Function) ->
    count(4, 1),
    try Function() after count(4, -1) end.

%% Report §8.6: the host loads a module at the first call into it, and the
%% caller waits on the code server meanwhile, which is the host's work and
%% not a receive of the caller's. Every process the runtime starts has this
%% module as its error handler (run/1), which counts the load as a foreign
%% call is counted and leaves the call itself to the host's handler.
-spec undefined_function(module(), atom(), [term()]) -> term().
undefined_function(ErlangModule, Function, Args) ->
    load(ErlangModule),
    error_handler:undefined_function(ErlangModule, Function, Args).

-spec undefined_lambda(module(), fun(), [term()]) -> term().
undefined_lambda(ErlangModule, Function, Args) ->
    load(ErlangModule),
    error_handler:undefined_lambda(ErlangModule, Function, Args).

load(ErlangModule) ->
    in_foreign(fun() -> code:ensure_loaded(ErlangModule) end).

count(Field, Increment) ->
    try ets:update_counter(?PROCESSES, erlang:self(), {Field, Increment}) of
        _ -> ok
    catch
        error:badarg -> ok
    end.

%%
%% Report §7: a process body; an exception is a fault
%%

run(Function) ->
    erlang:process_flag(error_handler, ?MODULE),
    try
        Function()
    catch
        Class:Error:Stack -> exit(fault_exit_reason(Class, Error, Stack))
    end.

%% Report §7.3, §7.4: what a host error is as an Ernest fault. A failure of
%% the runtime is the host's class and reason, and carries the host's stack
%% beside it for the report a person reads (§11.2).
-spec fault_exit_reason(error | exit | throw, term(), list()) -> tuple().
fault_exit_reason(error, badarith, _) -> {ern, fault, <<"division by zero">>};
fault_exit_reason(throw, {ern, fault, Cause}, _) -> {ern, fault, Cause};
fault_exit_reason(throw, {ern, fault, Cause, Trace}, _) -> {ern, fault, Cause, Trace};
fault_exit_reason(Class, Error, Stack) ->
    {ern, fault, format("~p:~p", [Class, Error]), trace(Stack)}.

%% Report §7.4, §9.6: a fault with the cause given, the prelude's `fault`
%% and every fault the runtime raises.
-spec fault(binary()) -> no_return().
fault(Cause) ->
    throw({ern, fault, Cause}).

%% A fault with the host's stack beside its cause, a foreign function's
%% raise (§7.4).
-spec fault(binary(), binary()) -> no_return().
fault(Cause, Trace) ->
    throw({ern, fault, Cause, Trace}).

%% Report §11.2: the host's stack as lines to print beneath a fault, the
%% innermost first, each a function and where in its source it was.
-spec trace([tuple()]) -> binary().
trace(Stack) ->
    unicode:characters_to_binary(
      [io_lib:format("    ~p:~p/~p~ts~n", [ErlangModule, Function, arity(Arguments), place(Info)])
       || {ErlangModule, Function, Arguments, Info} <- lists:sublist(Stack, 12)]).

arity(Arguments) when is_list(Arguments) -> length(Arguments);
arity(Arguments) -> Arguments.

place(Info) ->
    case {proplists:get_value(file, Info), proplists:get_value(line, Info)} of
        {undefined, _} -> "";
        {File, undefined} -> io_lib:format(" (~ts)", [File]);
        {File, Line} -> io_lib:format(" (~ts:~B)", [File, Line])
    end.

%%
%% Report §8.2, §9.7: system references
%%

-spec system_process(system()) -> address().
system_process(Name) ->
    persistent_term:get({?MODULE, Name}).

%% Report §8.2: stdout and stderr each write what they receive, as bytes,
%% through the function a run was given, or to a file descriptor through a
%% port of their own, which says when the stream can no longer be written:
%% the program then ends (§8.6), and the stream's process with it. A
%% program's write, Io.OutMsg's Write(bytes, reply), is answered once the
%% bytes are taken, the port holding this process while it is busy, so that
%% the writer waits while the stream is behind; the runtime's own lines, a
%% fault's report and a test's, are bytes alone.
stream({fd, Fd}, Name) ->
    process_flag(trap_exit, true),
    stream_loop(erlang:open_port({fd, 0, Fd}, [out, binary]), Name);
stream(Write, _Name) ->
    write_loop(Write).

write_loop(Write) ->
    receive
        {flush, From, Ref} ->
            From ! {Ref, flushed},
            write_loop(Write);
        {'Write', Bytes, Reply} ->
            Write(Bytes),
            answer(Reply, ?UNIT),
            write_loop(Write);
        Bytes when is_binary(Bytes) ->
            Write(Bytes),
            write_loop(Write)
    end.

stream_loop(Stream, Name) ->
    receive
        {flush, From, Ref} ->
            case drained(Stream) of
                ok ->
                    From ! {Ref, flushed},
                    stream_loop(Stream, Name);
                gone ->
                    %% report §8.6: the flush is told, so that it neither
                    %% waits nor takes what was lost for written
                    From ! {Ref, gone},
                    gone(Name)
            end;
        {'Write', Bytes, Reply} ->
            case written(Stream, Bytes) of
                ok -> answer(Reply, ?UNIT), stream_loop(Stream, Name);
                gone -> gone(Name)
            end;
        Bytes when is_binary(Bytes) ->
            case written(Stream, Bytes) of
                ok -> stream_loop(Stream, Name);
                gone -> gone(Name)
            end;
        {'EXIT', Stream, _} ->
            gone(Name)
    end.

written(Stream, Bytes) ->
    try erlang:port_command(Stream, Bytes) of
        true -> ok
    catch
        error:badarg -> gone
    end.

%% What the port was given is written, or the stream has gone.
drained(Stream) ->
    case erlang:port_info(Stream, queue_size) of
        {queue_size, 0} -> ok;
        {queue_size, _} -> receive {'EXIT', Stream, _} -> gone after 1 -> drained(Stream) end;
        undefined -> gone
    end.

gone(Name) ->
    {Runner, Launch} = persistent_term:get({?MODULE, runner}),
    Runner ! {gone, Launch, Name},
    dropping().

%% Report §11: a stream that has gone writes nothing more, and the program
%% ends at once. Until it has, what is written to the stream is dropped and
%% its writer goes on, so that no writer faults for a stream that ended.
dropping() ->
    receive
        {flush, From, Ref} -> From ! {Ref, gone};
        {'Write', _, Reply} -> answer(Reply, ?UNIT);
        _ -> ok
    end,
    dropping().

%% Report §8.2: keys and lines are the same terminal, so a program does one
%% or the other; doing both ends the program with a fault, as Deadlock ends
%% it, since neither side can answer for the other.
%% Report §11.2: the terminal is the shell's, and the process that reads it
%% for the shell is recorded as its holder; §8.2's case then faults anything
%% else that asks for keys. The shell claims it before it runs any input.
-spec hold_terminal(address()) -> 'Unit'.
hold_terminal(Address) ->
    persistent_term:put({?MODULE, holder}, process_of(Address)),
    ?UNIT.

-spec terminal_holder() -> pid() | undefined.
terminal_holder() ->
    persistent_term:get({?MODULE, holder}, undefined).

%% Report §7.4, §11.2: the cause of a process that asks for the terminal
%% while a shell holds it, a subscriber or a reader of lines alike.
-spec shell_holds() -> binary().
shell_holds() ->
    <<"the shell holds the terminal; run the program with ern run to give it the keyboard">>.

%% Report §11.2: while a shell holds the terminal, a line is read by the
%% holder alone. Anything else that asks faults, in its own process, before
%% the request reaches stdin, where it would take the shell's next line.
line_guard(Address) ->
    case terminal_holder() of
        undefined -> ok;
        Holder ->
            Stdin = persistent_term:get({?MODULE, stdin}, undefined),
            case process_of(Address) =:= Stdin andalso erlang:self() =/= Holder of
                true -> fault(shell_holds());
                false -> ok
            end
    end.

%% Report §8.2: which way the terminal is being read, keys or lines; a
%% program does one or the other, and the second to ask faults, with the
%% cause returned here. The first to ask claims it in one step, so two that
%% ask at once are one claim.
-spec own_terminal(lines | keys) -> ok | {taken, binary()}.
own_terminal(Kind) ->
    case ets:insert_new(?LAUNCH, {reading, Kind}) of
        true ->
            ok;
        false ->
            case ets:lookup(?LAUNCH, reading) of
                [{reading, Kind}] ->
                    ok;
                [{reading, Other}] ->
                    {taken, format("the terminal is already read as ~s", [Other])}
            end
    end.

%% Report §7.3, §8.2: a system process ends the program with a fault of
%% the entry process, the runner's to report.
end_with_fault(Cause) ->
    {Runner, Launch} = persistent_term:get({?MODULE, runner}),
    Runner ! {fault, Launch, Cause},
    ok.

%% Report §8.2: standard input, read as UTF-8 whatever the host's locale,
%% as lines and as bytes from one stream, each request taking up where the
%% one before it stopped. Open is the input (open_input/0, or fed/1 in a
%% test), opened for a request and closed once it is answered, so that no
%% more is read than a request needs and a program slower than what writes
%% to it holds the writer back. Report §7.3: a read that fails is a failure
%% of the runtime, and ends the program with a fault that names it.
stdin_loop(Open) ->
    erlang:process_flag(trap_exit, true),
    stdin_loop(Open, <<>>).

stdin_loop(Open, Buffer) ->
    receive
        %% report §8.2: a claim the terminal refuses faults the process that
        %% asked, and nothing is read for it
        {'ReadLine', Reply} ->
            case own_terminal(lines) of
                ok -> stdin_loop(Open, read_line(Reply, Open, Buffer));
                {taken, Cause} -> refuse(Reply, Cause), stdin_loop(Open, Buffer)
            end;
        {'Read', Reply} ->
            case own_terminal(lines) of
                ok -> stdin_loop(Open, read_bytes(Reply, Open, Buffer));
                {taken, Cause} -> refuse(Reply, Cause), stdin_loop(Open, Buffer)
            end;
        {'EXIT', _, _} ->
            %% an input closed after its answer came
            stdin_loop(Open, Buffer)
    end.

%% Report §8.2: the next line answered, a source while it is read, and
%% what is left after it.
read_line(Reply, Open, Buffer) ->
    source_begin(),
    Rest = case line(Open, Buffer, 0) of
               {eof, Left} -> answer(Reply, 'None'), Left;
               {{line, Line}, Left} -> answer_line(Reply, without_return(Line)), Left;
               {{last, Line}, Left} -> answer_line(Reply, Line), Left;
               {{error, Error}, Left} -> unreadable(Error), Left
           end,
    source_end(),
    Rest.

%% Report §8.2: the bytes that have arrived answered, a source while they
%% are read; none is left.
read_bytes(Reply, Open, Buffer) ->
    source_begin(),
    case Buffer of
        <<>> -> bytes(Reply, read_input(Open));
        _ -> answer(Reply, {'Some', Buffer})
    end,
    source_end(),
    <<>>.

%% The next line and the bytes after it: the bytes before the first line
%% feed at or after Offset, reading more while there is none. A last line
%% without a line feed is a line, `last`.
line(Open, Buffer, Offset) ->
    case binary:match(Buffer, <<"\n">>, [{scope, {Offset, byte_size(Buffer) - Offset}}]) of
        {Index, 1} ->
            <<Line:Index/binary, $\n, Rest/binary>> = Buffer,
            {{line, Line}, Rest};
        nomatch ->
            case read_input(Open) of
                {data, Bytes} -> line(Open, <<Buffer/binary, Bytes/binary>>, byte_size(Buffer));
                eof when Buffer =:= <<>> -> {eof, <<>>};
                eof -> {{last, Buffer}, <<>>};
                {error, Error} -> {{error, Error}, Buffer}
            end
    end.

%% Report §8.2: a line that a line feed ended, without one carriage return
%% before the line feed; a last line keeps its own.
without_return(Line) ->
    case Line of
        <<Head:(byte_size(Line) - 1)/binary, $\r>> -> Head;
        _ -> Line
    end.

%% Report §8.2, §7.4: the line, or the fault of the process that asked,
%% when it is not UTF-8.
answer_line(Reply, Text) ->
    case unicode:characters_to_binary(Text, utf8, utf8) of
        Text -> answer(Reply, {'Some', Text});
        _ -> refuse(Reply, not_utf8())
    end.

%% Report §8.2: what has arrived, at least one byte, or None at the end.
bytes(Reply, {data, Bytes}) -> answer(Reply, {'Some', Bytes});
bytes(Reply, eof) -> answer(Reply, 'None');
bytes(_, {error, Error}) -> unreadable(Error).

unreadable(Error) ->
    end_with_fault(<<(unreadable())/binary, (format("~p", [Error]))/binary>>).

unreadable() ->
    <<"the standard input could not be read: ">>.

not_utf8() ->
    <<"the standard input is not UTF-8">>.

%% Report §8.2, §7.4: keys that are not UTF-8 end the program with the
%% fault of its entry process, since no process asked for them.
-spec input_not_utf8() -> ok.
input_not_utf8() ->
    end_with_fault(not_utf8()).

%% Report §8.2, §11.8: whether a fault's cause is one of standard input's,
%% which ends a shell as it ends a run, by its input and not by a defect.
-spec by_input(binary()) -> boolean().
by_input(Cause) ->
    Prefix = unreadable(),
    case Cause of
        <<Prefix:(byte_size(Prefix))/binary, _/binary>> -> true;
        _ -> Cause =:= not_utf8()
    end.

%% The input as it arrives, for one request: at least one byte, eof, or
%% {error, Error}. The input is open from the request to its first answer,
%% and what arrived with that answer is taken with it. An exit from a link
%% other than the input's own is the end of the process that reads.
-spec read_input(fun(() -> port() | pid())) -> {data, binary()} | eof | {error, term()}.
read_input(Open) ->
    Input = Open(),
    First = receive
                {Input, {data, Bytes}} -> {data, Bytes};
                {Input, eof} -> eof;
                {Input, {error, Error}} -> {error, Error};
                {'EXIT', Input, Error} -> {error, Error};
                {'EXIT', _, ExitReason} -> close_input(Input), exit(ExitReason)
            end,
    close_input(Input),
    case First of
        {data, Head} -> {data, arrived(Input, Head)};
        _ -> First
    end.

arrived(Input, Acc) ->
    receive
        {Input, {data, Bytes}} -> arrived(Input, <<Acc/binary, Bytes/binary>>)
    after 0 ->
        Acc
    end.

close_input(Input) when is_port(Input) ->
    erlang:unlink(Input),
    try erlang:port_close(Input) catch error:badarg -> true end,
    flush_exit(Input);
close_input(Input) ->
    erlang:unlink(Input),
    exit(Input, kill),
    flush_exit(Input).

flush_exit(Input) ->
    receive {'EXIT', Input, _} -> ok after 0 -> ok end.

%% The host's standard input, a port on its descriptor. `bin/ern` starts
%% the host with -noinput, so that the descriptor is the runtime's alone.
open_input() ->
    erlang:open_port({fd, 0, 1}, [in, binary, eof, stream]).

%% A test's input: Next is called once for each opening and answers what
%% arrives then, characters, bytes as they are, eof, or {error, Error}.
fed(Next) ->
    fun() ->
        Owner = erlang:self(),
        erlang:spawn_link(fun() -> Owner ! {erlang:self(), fed_message(Next())} end)
    end.

fed_message(eof) -> eof;
fed_message({error, Error}) -> {error, Error};
fed_message(Bytes) when is_binary(Bytes) -> {data, Bytes};
fed_message(Chars) -> {data, unicode:characters_to_binary(Chars)}.

%% Clock's messages, clock.ern's (report Appendix E.15): Alarm(ms,
%% address, reply), AlarmAt(time, address, reply), and Now(reply). Alarms
%% are delivered through the clock itself, so each is counted as a source
%% while it is pending (report §8.6). The clock holds each pending alarm by
%% its timer, with its moment, where it goes and the process behind that,
%% and each process's timers, so that a restart of that process cancels its
%% own and reads no other's (report §6.9). An alarm after milliseconds is
%% held by its deadline on the monotonic clock, `{monotonic, Deadline}`,
%% which a clock that is set does not move; one at a time by the time,
%% `{time, Time}`, which the host's clock is read against. The host's
%% timers count monotonic time, so the clock asks the host to be told of
%% each change of its time offset, and sets every alarm at a time again
%% then. `read_time` reads the host's clock, or a test's.
-record(clock, {alarms = #{}, by_recipient = #{}, read_time}).

clock(ReadTime) ->
    _ = erlang:monitor(time_offset, clock_service),
    clock_loop(#clock{read_time = ReadTime}).

clock_loop(#clock{read_time = ReadTime} = Clock) ->
    receive
        {'Alarm', Ms, Address, Reply} ->
            clock_loop(alarm({monotonic, deadline(Ms)}, Address, Reply, Clock));
        {'AlarmAt', At, Address, Reply} ->
            clock_loop(alarm({time, At}, Address, Reply, Clock));
        {timeout, Timer, fire} ->
            clock_loop(fired(Timer, Clock));
        {'CHANGE', _, time_offset, clock_service, _} ->
            clock_loop(set_again(Clock));
        {'Now', Reply} ->
            answer(Reply, ReadTime()),
            clock_loop(Clock);
        {new_run, Pid, Ref} ->
            Clock1 = alarms_cancelled(Pid, Clock),
            Pid ! {Ref, fresh},
            clock_loop(Clock1)
    end.

%% An alarm, answered once it is counted, so that the caller goes on
%% waiting only on what is counted (report §8.6).
alarm(Moment, Address, Reply, Clock) ->
    source_begin(),
    Armed = armed(Moment, Address, Clock),
    answer(Reply, ?UNIT),
    Armed.

%% A timer that fired: its alarm delivered once its moment has come, and
%% set again before; one a restart cancelled as it fired, or a change of
%% the clock set again, is gone.
%% Report §6.5, E.15: the alarm's address may be an address seen through a
%% function, and it is sent the time it fired, from a process of its own,
%% so that a function that does not finish holds up no other alarm; the
%% alarm is a source until it is delivered.
fired(Timer, #clock{alarms = Alarms, read_time = ReadTime} = Clock) ->
    case Alarms of
        #{Timer := {Moment, Address, Recipient}} ->
            Left = without_alarm(Timer, Recipient, Clock),
            case wait(Moment, ReadTime) of
                0 ->
                    Now = ReadTime(),
                    counted_link(Address, fun() -> deliver(Address, Now) end),
                    source_end(),
                    Left;
                _ ->
                    armed(Moment, Address, Left)
            end;
        #{} ->
            Clock
    end.

%% Appendix E.15: the host's clock was set. An alarm at a time is set again
%% against the clock as it now reads: one whose time has come fires at
%% once, and one whose time is further off waits the longer.
set_again(#clock{alarms = Alarms} = Clock) ->
    maps:fold(fun(Timer, {{time, _} = Moment, Address, Recipient}, Acc) ->
                      erlang:cancel_timer(Timer),
                      armed(Moment, Address, without_alarm(Timer, Recipient, Acc));
                 (_Timer, {{monotonic, _}, _, _}, Acc) ->
                      Acc
              end, Clock, Alarms).

%% Report §6.9: a restart cancels the process's alarms, and those on their
%% way to it.
alarms_cancelled(Pid, #clock{alarms = Alarms, by_recipient = ByRecipient} = Clock) ->
    {Timers, ByRecipient1} = case maps:take(Pid, ByRecipient) of
                                 {Own, Others} -> {Own, Others};
                                 error -> {[], ByRecipient}
                             end,
    lists:foreach(fun(Timer) -> erlang:cancel_timer(Timer), source_end() end, Timers),
    cancelled(Pid),
    Clock#clock{alarms = maps:without(Timers, Alarms), by_recipient = ByRecipient1}.

%% Appendix E.0 rule 8: a time has no upper bound, and the host's timers
%% have one, so an alarm is set again until its moment has come.
armed(Moment, Address,
      #clock{alarms = Alarms, by_recipient = ByRecipient, read_time = ReadTime} = Clock) ->
    Timer = erlang:start_timer(wait(Moment, ReadTime), erlang:self(), fire),
    Recipient = process_of(Address),
    Clock#clock{alarms = Alarms#{Timer => {Moment, Address, Recipient}},
                by_recipient = added(Recipient, Timer, ByRecipient)}.

without_alarm(Timer, Recipient, #clock{alarms = Alarms, by_recipient = ByRecipient} = Clock) ->
    Clock#clock{alarms = maps:remove(Timer, Alarms),
                by_recipient = forgotten(Recipient, Timer, ByRecipient)}.

%% The next wait towards an alarm's moment, at most ?SLICE; 0 once it has
%% come.
wait({monotonic, Deadline}, _Time) -> remaining(Deadline);
wait({time, At}, ReadTime) -> min(?SLICE, max(0, At - ReadTime())).

%%
%% Report §8.1, §8.6: the runner
%%

-type outcome() :: ok | killed | {fault, binary()} | {fault, binary(), binary()}
                 | {initializer_fault, binary(), binary()}
                 | {initializer_fault, binary(), binary(), binary()}
                 | {exit, 0..255} | {gone, stdout | stderr} | {signal, sigterm | sighup}.

%% Runs EntryPoint as the entry process. It returns ok, killed if the entry
%% process was killed, {fault, Cause} if it faulted, a deadlock among the
%% faults (report §8.6: the entry process faults with `Fault("deadlock")`),
%% and {fault, Cause, Trace} where the fault was a failure of the runtime
%% or a foreign function's raise, the host's stack beneath it;
%% {initializer_fault, Site, Cause} if a top-level binding faulted before
%% EntryPoint ran, Site naming the binding (report §8.5), and the host's
%% stack after them where it faulted so; {exit, Status} if a process
%% called Os.exit, {gone, Stream} if standard output or standard error
%% could no longer be written, or {signal, Signal} if the host's
%% termination or hangup ended the program. Every local process is then
%% ended with ProgramEnd, and standard output and standard error are
%% flushed, however the run ended.
%%
%% Options: init => a function run in the entry process before EntryPoint,
%% after the system references are bound and the standard library's lets
%% evaluated, for the program's own top-level lets (report §8.5);
%% arguments => the program's arguments, Os.arguments, none by default;
%% exit => fault, where Os.exit faults its caller rather than ending the
%% program, as in the shell and under `ern test` (report §11.2); faults =>
%% fun((FaultReport) -> any()), given every fault as it happens (report
%% §11.2); stdout, stderr => fun((binary()) -> any()), or {fd, N} to write
%% to the file descriptor through a port, which learns when the stream has
%% gone (§8.2); stdin => fun(() -> eof | {error, term()} |
%% unicode:chardata()), called for each read, and keys => the same for the
%% terminal's keys, for tests (fed/1); time => fun(() -> integer()), the
%% clock the Clock process reads in place of the host's, for tests;
%% remove_tree => fun((binary()) -> term()), what the file system process
%% removes a tree with in place of the runtime's helper, for a test that
%% must remove nothing (Appendix E.17). Report
%% §8.2: the standard streams carry bytes for the run, whatever the host's
%% locale.
-spec run_main(fun(() -> term()), binary(), map()) -> outcome().
run_main(EntryPoint, Site, Options) ->
    make_tables(),
    Launch = launched(Options),
    Reaper = erlang:spawn(fun() -> reaper_loop(#reaper{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Encodings = bytes_out(),
    System = started_system(Options),
    Ended = try
                {ended, entry_outcome(EntryPoint, Site, Options, Launch)}
            catch
                Class:Error:Stack -> {raised, Class, Error, Stack}
            end,
    try end_program(Launch, Reaper, System) of
        Gone -> outcome_flushed(Ended, Gone)
    after
        persistent_term:erase({?MODULE, reporter}),
        restore_encodings(Encodings)
    end.

%% Report §8.6: a stream that could not be written as the program's output
%% was flushed is what ended the program, in place of what ended it.
outcome_flushed({raised, Class, Error, Stack}, _Gone) -> erlang:raise(Class, Error, Stack);
outcome_flushed({ended, Outcome}, []) -> Outcome;
outcome_flushed({ended, _}, [Stream | _]) -> {gone, Stream}.

%% The run's tables, which the module's header describes.
%% The tables that hold a launch's state, which `make load` counts the rows
%% of (docs/memory.md).
-spec tables() -> [atom()].
tables() ->
    [?PROCESSES, ?CALLS, ?CALLEES, ?FAULTS, ?HELD, ?DELIVERIES, ?RESTARTS, ?PROXIES, ?LAUNCH].

make_tables() ->
    lists:foreach(fun(Table) -> ets:new(Table, [named_table, public, table_kind(Table)]) end,
                  tables()).

%% The callees' and the deliveries' rows are ordered, so that a process
%% reads its own by their key's prefix.
table_kind(?CALLEES) -> ordered_set;
table_kind(?DELIVERIES) -> ordered_set;
table_kind(_) -> set.

%% The reference that tags this launch, under which the runner is known,
%% and what the options give the run. Report §11.2: `ern run` reports
%% every fault, the runtime's own subscriber, given here as a function.
launched(Options) ->
    persistent_term:erase({?MODULE, holder}),
    case Options of
        #{faults := Reporter} -> persistent_term:put({?MODULE, reporter}, Reporter);
        _ -> persistent_term:erase({?MODULE, reporter})
    end,
    Launch = make_ref(),
    persistent_term:put({?MODULE, runner}, {erlang:self(), Launch}),
    persistent_term:put({?MODULE, arguments}, maps:get(arguments, Options, [])),
    persistent_term:put({?MODULE, exit}, maps:get(exit, Options, program)),
    Launch.

%% Report §8.2: the system processes, each bound under its name. Keys come
%% where standard input is a terminal, and from a test's keys.
started_system(Options) ->
    Stdout = maps:get(stdout, Options, fun(Bytes) -> file:write(standard_io, Bytes) end),
    Stderr = maps:get(stderr, Options, fun(Bytes) -> file:write(standard_error, Bytes) end),
    OpenStdin = input(stdin, Options),
    OpenKeys = input(keys, Options),
    KeysCome = maps:is_key(keys, Options) orelse ern_tty:is_terminal(stdin),
    ReadTime = maps:get(time, Options, fun() -> erlang:system_time(millisecond) end),
    RemoveTree = maps:get(remove_tree, Options, fun ern_fs:removed_by_helper/1),
    System = [{stdout, erlang:spawn(fun() -> stream(Stdout, stdout) end)},
              {stderr, erlang:spawn(fun() -> stream(Stderr, stderr) end)},
              {stdin, erlang:spawn(fun() -> stdin_loop(OpenStdin) end)},
              {fs, erlang:spawn(fun() -> ern_fs:loop(RemoveTree) end)},
              {terminal, erlang:spawn(fun() -> ern_tty:loop(OpenKeys, KeysCome) end)},
              {tcp, erlang:spawn(fun ern_tcp:loop/0)},
              {os, erlang:spawn(fun ern_os:loop/0)},
              {clock, erlang:spawn(fun() -> clock(ReadTime) end)}],
    lists:foreach(fun({Name, Pid}) -> persistent_term:put({?MODULE, Name}, Pid) end, System),
    System.

%% The entry process's outcome. Report §8.5: the initializers, the
%% standard library's first, run in main's process, so one that faults is
%% the program's fault; its modules are loaded here, where their order is
%% read from them. Report §6.9: the runner's monitor is made with the
%% spawn, so the entry process's cause, and the host's stack beside a
%% failure of the runtime (§11.2), reach it however soon the process ends.
%% Report §8.5, §11.2: an initializer's fault is reported under its
%% binding, and main's under main's site again once they have run.
entry_outcome(EntryPoint, Site, Options, Launch) ->
    Stdlib = stdlib_modules(),
    Init = maps:get(init, Options, fun() -> ok end),
    Entry = fun() ->
                run_inits(Stdlib),
                Init(),
                initializing(Site),
                EntryPoint()
            end,
    EntryProcess = spawn_with_monitors(Entry, Site,
                                       [{erlang:self(), {raw, {entry_down, Launch}}}]),
    case entry_end(EntryProcess, Launch) of
        {{fault, Cause}, FaultSite} when FaultSite =/= Site ->
            {initializer_fault, FaultSite, Cause};
        {{fault, Cause, Trace}, FaultSite} when FaultSite =/= Site ->
            {initializer_fault, FaultSite, Cause, Trace};
        {Outcome, _} ->
            Outcome
    end.

%% The entry process's end, and its site then. Report §8.6, §8.2: a
%% deadlock, and a fault the runtime finds in a system process's work, fault
%% the entry process, whose end then comes as any process's does, reported
%% as every fault is (§11.2).
entry_end(EntryProcess, Launch) ->
    receive
        {{entry_down, Launch}, Site, ExitReason} ->
            {case {reason(ExitReason), ExitReason} of
                 {'Returned', _} -> ok;
                 {'Killed', _} -> killed;
                 {{'Fault', Cause}, {ern, fault, _, Trace}} -> {fault, Cause, Trace};
                 {{'Fault', Cause}, _} -> {fault, Cause};
                 {Other, _} -> {fault, format("~p", [Other])}
             end, Site};
        {deadlock, Launch} ->
            exit(EntryProcess, {ern, fault, <<"deadlock">>}),
            entry_end(EntryProcess, Launch);
        {fault, Launch, Cause} ->
            exit(EntryProcess, {ern, fault, Cause}),
            entry_end(EntryProcess, Launch);
        {exit, Launch, Status} ->
            {{exit, Status}, none};
        {gone, Launch, Stream} ->
            {{gone, Stream}, none};
        {signal, Launch, Signal} ->
            {{signal, Signal}, none}
    end.

%% Report Appendix E.23: the words after the module on `ern run`'s command
%% line, which the runner was given; none in the shell and under `ern
%% test` (§11.2).
-spec arguments() -> [binary()].
arguments() ->
    persistent_term:get({?MODULE, arguments}, []).

%% Report §8.6, Appendix E.23: Os.exit ends the program with its status,
%% the runner ending every process as it does at the entry process's end;
%% the caller waits for its own end there. In the shell and under `ern test`
%% it faults the caller instead (§11.2).
-spec exit_program(integer()) -> no_return().
exit_program(Status) ->
    case Status >= 0 andalso Status =< 255 of
        true -> ok;
        false -> fault(<<"an exit status is from 0 to 255">>)
    end,
    case persistent_term:get({?MODULE, exit}, program) of
        fault ->
            fault(format("exited with status ~B", [Status]));
        program ->
            {Runner, Launch} = persistent_term:get({?MODULE, runner}),
            Runner ! {exit, Launch, Status},
            receive after infinity -> ok end
    end.

input(Key, Options) ->
    case maps:find(Key, Options) of
        {ok, Next} -> fed(Next);
        error -> fun open_input/0
    end.

%% Report §8.2: standard output and standard error are written as the
%% bytes a program sends, UTF-8 text among them, so the host's streams take
%% bytes as they are for the run; what they took before is put back after.
bytes_out() ->
    lists:foldr(fun(Device, Taken) ->
                    case encoding(Device) of
                        none -> Taken;
                        Encoding ->
                            case io:setopts(Device, [{encoding, latin1}]) of
                                ok -> [{Device, Encoding} | Taken];
                                _ -> Taken
                            end
                    end
                end, [], [standard_io, standard_error]).

encoding(Device) ->
    try proplists:get_value(encoding, io:getopts(Device), none)
    catch _:_ -> none
    end.

restore_encodings(Encodings) ->
    lists:foreach(fun({Device, Encoding}) -> io:setopts(Device, [{encoding, Encoding}]) end,
                  Encodings).

%% Report §11.2: under `ern test` a deadlock is the fault of the test that
%% runs, not of the entry process; none after the test has ended.
-spec deadlock_victim(pid() | none) -> ok.
deadlock_victim(none) ->
    ets:delete(?LAUNCH, deadlock_victim),
    ok;
deadlock_victim(Pid) ->
    ets:insert(?LAUNCH, {deadlock_victim, Pid}),
    ok.

%% Report §8.6: the host's termination or hangup ends the run in progress
%% as the end of its entry process does; none when no run is in progress.
-spec signal(sigterm | sighup) -> ok | none.
signal(Signal) ->
    case persistent_term:get({?MODULE, runner}, none) of
        {Runner, Launch} ->
            case erlang:is_process_alive(Runner) of
                true -> Runner ! {signal, Launch, Signal}, ok;
                false -> none
            end;
        none ->
            none
    end.

%% Report §8.5, §11.2: the binding the calling process evaluates now, whose
%% site a fault while it does is reported under, as a spawn's is; a process
%% the runtime did not start has no site to change.
-spec initializing(binary()) -> 'Unit'.
initializing(Site) ->
    try ets:update_element(?PROCESSES, erlang:self(), {2, Site}) of
        _ -> ?UNIT
    catch
        error:badarg -> ?UNIT
    end.

%% The calling process's site, empty for one the runtime did not start.
-spec site() -> binary().
site() ->
    case ets_lookup(?PROCESSES, erlang:self()) of
        [{_, Site, _, _, _}] -> Site;
        _ -> <<>>
    end.

%% Report §8.5, §11.2: a top-level binding's value, which '$init'/0 put.
%% One that has none, since a binding before it faulted when the shell
%% loaded its module, faults its reader (§7.4).
-spec binding(term()) -> term().
binding(Key) ->
    case persistent_term:get(Key, '$unevaluated') of
        '$unevaluated' -> fault(<<"the binding has no value, since one before it faulted">>);
        Value -> Value
    end.

%% Report §6.9: a function that runs F, and on a fault runs it again in the
%% same process, until the limit's restarts within its milliseconds have
%% happened, when the next fault ends the process with its cause, or after
%% every fault where the limit is Unlimited. Only a fault restarts, or a
%% restart asked for (restartable/0): a kill and the program's end are exit
%% signals, which no try catches, and F returning ends it as any process
%% ends.
-spec restarting({'RestartLimit', integer(), integer()} | 'Unlimited', fun(() -> term())) ->
          fun(() -> term()).
restarting(Limit, F) ->
    Allowed = case Limit of
                  'Unlimited' -> unlimited;
                  {'RestartLimit', Restarts, Within} -> {max(Restarts, 0), max(Within, 1)}
              end,
    fun() ->
        Level = restartable(),
        try
            restarts(F, Allowed, [], Level)
        after
            Level =:= outer andalso unrestartable()
        end
    end.

%% Report §6.9, Appendix E.22: a restarting process can be asked to restart,
%% by a priority message to an alias of its own that the runtime keeps
%% beside it, taken before its other messages at its next wait. The
%% outermost restarting function of the process is the one asked, and the
%% one whose start start_cause/0 tells; one nested in it is neither.
restartable() ->
    case ets_lookup(?RESTARTS, erlang:self()) of
        [_] ->
            inner;
        [] ->
            ets:insert(?RESTARTS, {erlang:self(), erlang:alias([priority])}),
            put('$ern_start', 'First'),
            outer
    end.

%% The outermost restarting function has ended: the process is no longer
%% asked to restart.
unrestartable() ->
    [{_, Alias}] = ets_lookup(?RESTARTS, erlang:self()),
    erlang:unalias(Alias),
    ets:delete(?RESTARTS, erlang:self()),
    erase('$ern_start'),
    %% a request that came as the function returned is not taken later
    receive '$ern_restart' -> ok after 0 -> ok end.

%% Report §6.9: the clause every wait has for a restart asked for.
-spec restart_now() -> no_return().
restart_now() ->
    throw('$ern_restart').

%% Appendix E.22: the supervisor's request that a child restart, and
%% whether it was made; a process that has ended, or has not yet begun to
%% run what restarts, is not asked, and the supervisor waits for none such.
-spec ask_restart(pid()) -> boolean().
ask_restart(Pid) ->
    case ets_lookup(?RESTARTS, Pid) of
        [{_, Alias}] ->
            erlang:send(Alias, '$ern_restart', [priority]),
            true;
        [] ->
            false
    end.

%% Appendix E.22: why the restarting function the caller runs in began:
%% the first time, after a fault, or because it was asked.
-spec start_cause() -> 'First' | 'AfterFault' | 'Asked'.
start_cause() ->
    case get('$ern_start') of
        undefined -> 'First';
        Cause -> Cause
    end.

%% Appendix E.22: where a process stands in the order the runtime spawned
%% its processes, 0 for one it did not start, which stands first.
-spec spawn_order(pid()) -> non_neg_integer().
spawn_order(Pid) ->
    case ets_lookup(?PROCESSES, Pid) of
        [{_, _, _, _, SpawnOrder}] -> SpawnOrder;
        _ -> 0
    end.

restarts(F, Allowed, Times, Level) ->
    try
        F()
    catch
        throw:'$ern_restart' when Level =:= outer ->
            %% report §6.9: a restart asked for is no fault, counts against
            %% no limit, and is not reported; the calls waiting on the
            %% process end as at a fault
            put('$ern_start', 'Asked'),
            fresh_run(),
            restarted(<<"callee was restarted">>),
            restarts(F, Allowed, Times, Level);
        throw:'$ern_restart' ->
            throw('$ern_restart');
        Class:Error:Stack ->
            Fault = fault_exit_reason(Class, Error, Stack),
            case within_limit(Allowed, Times) of
                {true, Recent} ->
                    %% report §11.2: a fault after which the process
                    %% restarts is reported as one
                    persistent_term:get({?MODULE, reaper}) ! {report, erlang:self(), site(), Fault},
                    fresh_run(),
                    restarted(fault_cause(Fault)),
                    Level =:= outer andalso put('$ern_start', 'AfterFault'),
                    restarts(F, Allowed, Recent, Level);
                false ->
                    %% raised again as the fault it is, for run/1 to end the
                    %% process with, its stack beside it where it had one
                    throw(Fault)
            end
    end.

%% A fault's cause, with or without the host's stack beside it.
fault_cause({ern, fault, Cause}) -> Cause;
fault_cause({ern, fault, Cause, _Trace}) -> Cause.

%% Report §6.9: a restart begins a new run with nothing of the old. What
%% the process asked the runtime for is cancelled, with what is on its way
%% to it: its monitors and its subscription to faults by the reaper, its
%% alarms by the clock, its keys by the terminal; then its mailbox is
%% emptied, before the calls waiting on it are told they have ended, so
%% that the request of an ended call is not taken by the new run.
%% The three are asked at once, and each is monitored, so that one that has
%% died holds up no restart.
fresh_run() ->
    Self = erlang:self(),
    Asked = [begin
                 MonitorRef = erlang:monitor(process, Pid),
                 Pid ! {new_run, Self, MonitorRef},
                 MonitorRef
             end || Pid <- [persistent_term:get({?MODULE, reaper}), system_process(clock),
                            system_process(terminal)]],
    lists:foreach(fun(MonitorRef) ->
                      receive
                          {MonitorRef, fresh} -> erlang:demonitor(MonitorRef, [flush]);
                          {'DOWN', MonitorRef, process, _, _} -> ok
                      end
                  end, Asked),
    emptied().

emptied() ->
    receive
        _ -> emptied()
    after 0 -> ok
    end.

%% Report §6.9: whether a fault now is restarted, and the times of the
%% restarts within the window then; Unlimited keeps no time.
within_limit(unlimited, _) ->
    {true, []};
within_limit({Restarts, Within}, Times) ->
    Now = erlang:monotonic_time(millisecond),
    Recent = [Time || Time <- Times, Now - Time < Within],
    case length(Recent) < Restarts of
        true -> {true, [Now | Recent]};
        false -> false
    end.

%% Report §6.6, §6.9: a restart ends every call waiting on the process, each
%% caller told the cause, which a callForever faults with.
restarted(Cause) ->
    Self = erlang:self(),
    Callers = try ets:select(?CALLEES, [{{{Self, '$1'}, '$2'}, [], [{{'$1', '$2'}}]}])
              catch _:_ -> []
              end,
    lists:foreach(fun({Caller, Reply}) ->
                      ets:delete(?CALLEES, {Self, Caller}),
                      ets:delete_object(?CALLS, {Caller, Self, Reply}),
                      Reply ! {Reply, restarted, Cause}
                  end, Callers).

%% Report §8.6: every local process ends with ProgramEnd, the sinks' output
%% is flushed, the system processes and the reaper are stopped, and the
%% terminal goes back as the program found it (§8.2). The answer is the
%% streams that could not be flushed, standard output's first.
end_program(Launch, Reaper, System) ->
    Ref = make_ref(),
    MonitorRef = erlang:monitor(process, Reaper),
    Reaper ! {end_program, erlang:self(), Ref},
    receive
        {Ref, ended} ->
            ok;
        {'DOWN', MonitorRef, process, _, _} ->
            lists:foreach(fun({Pid, _, _, _, _}) -> exit(Pid, {ern, program_end}) end, live_rows())
    end,
    erlang:demonitor(MonitorRef, [flush]),
    Gone = [Name || Name <- [stdout, stderr],
                    sink_flushed(proplists:get_value(Name, System)) =:= gone],
    %% each ended before the table goes, which the reaper reads
    lists:foreach(fun stop/1, [Pid || {_, Pid} <- System] ++ [Reaper]),
    case ets:lookup(?LAUNCH, reading) of
        [{reading, keys}] -> ern_tty:restore();
        _ -> ok
    end,
    lists:foreach(fun ets:delete/1, tables()),
    %% a signal after the run has nothing to end (signal/1)
    persistent_term:erase({?MODULE, runner}),
    flush_launch(Launch),
    Gone.

%% A sink's pending output written, or the stream gone (stream/2).
sink_flushed(Sink) ->
    Ref = make_ref(),
    MonitorRef = erlang:monitor(process, Sink),
    Sink ! {flush, erlang:self(), Ref},
    %% a sink that died has nothing left to flush, and waiting for it would
    %% hold the program open
    Flushed = receive
                  {Ref, Answer} -> Answer;
                  {'DOWN', MonitorRef, process, _, _} -> flushed
              end,
    erlang:demonitor(MonitorRef, [flush]),
    Flushed.

%% Report §8.5: a standard library module's top-level lets, `Map.empty`
%% among them, are evaluated once at program start like any other module's;
%% the runner initializes the program's own modules, the runtime these,
%% which are build output on the code path rather than modules of the load
%% path.
-spec init_stdlib() -> ok.
init_stdlib() ->
    run_inits(stdlib_modules()).

%% The standard library's modules, loaded, in the order their initializers
%% run: every ern@ module in a `stdlib` directory on the code path, as the
%% checker finds them (ern_prelude:stdlib_interfaces/0). The shell's modules
%% are on the same path and are not the standard library's; the shell
%% initializes them as a program's own (init_modules/1).
stdlib_modules() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(Dir, "ern@*.beam"))
                                      || Dir <- code:get_path(),
                                         filename:basename(Dir) =:= "stdlib"])),
    ErlangModules = [list_to_atom(filename:basename(File, ".beam")) || File <- Files],
    lists:foreach(fun(ErlangModule) -> code:ensure_loaded(ErlangModule) end, ErlangModules),
    ordered(ErlangModules).

%% Report §8.5: the top-level lets of the modules given and of the modules
%% they depend on through `'$deps'/0`, dependencies first, each module once;
%% the order of the list is kept where no dependency decides it.
-spec init_modules([module()]) -> ok.
init_modules(ErlangModules) ->
    {Order, _} = lists:foldl(fun(ErlangModule, Acc) ->
                                 visit(ErlangModule, all, Acc)
                             end, {[], #{}}, ErlangModules),
    run_inits(lists:reverse(Order)).

run_inits(ErlangModules) ->
    lists:foreach(fun(ErlangModule) ->
                      case erlang:function_exported(ErlangModule, '$init', 0) of
                          true -> ErlangModule:'$init'();
                          false -> ok
                      end
                  end, ErlangModules).

%% Report §8.5: dependency order, which each compiled module declares as
%% `'$deps'/0`; the order within an independent set is unspecified, and
%% is the alphabetical one the code path gives.
-spec ordered([module()]) -> [module()].
ordered(ErlangModules) ->
    {Order, _} = lists:foldl(fun(ErlangModule, Acc) ->
                                 visit(ErlangModule, ErlangModules, Acc)
                             end, {[], #{}}, ErlangModules),
    lists:reverse(Order).

visit(ErlangModule, ErlangModules, {Order, Seen}) ->
    case Seen of
        #{ErlangModule := _} ->
            {Order, Seen};
        _ ->
            Dependencies = [Dependency || Dependency <- dependencies_of(ErlangModule),
                                          ErlangModules =:= all
                                              orelse lists:member(Dependency, ErlangModules)],
            {Order1, Seen1} = lists:foldl(fun(Dependency, Acc) ->
                                              visit(Dependency, ErlangModules, Acc)
                                          end,
                                          {Order, Seen#{ErlangModule => true}}, Dependencies),
            {[ErlangModule | Order1], Seen1}
    end.

%% A module is loaded as the error handler loads one, counted as a foreign
%% call, since init_modules/1 runs in the entry process (report §8.6).
dependencies_of(ErlangModule) ->
    load(ErlangModule),
    case erlang:function_exported(ErlangModule, '$deps', 0) of
        true -> ErlangModule:'$deps'();
        false -> []
    end.

stop(Pid) ->
    MonitorRef = erlang:monitor(process, Pid),
    exit(Pid, kill),
    receive {'DOWN', MonitorRef, process, Pid, _} -> ok end.

%% What the reaper, the system processes and a signal may still send about
%% this run after it ended.
flush_launch(Launch) ->
    receive
        {{entry_down, Launch}, _, _} -> flush_launch(Launch);
        {deadlock, Launch} -> flush_launch(Launch);
        {fault, Launch, _} -> flush_launch(Launch);
        {exit, Launch, _} -> flush_launch(Launch);
        {gone, Launch, _} -> flush_launch(Launch);
        {signal, Launch, _} -> flush_launch(Launch)
    after 0 ->
        ok
    end.

format(Format, Args) ->
    unicode:characters_to_binary(io_lib:format(Format, Args)).
