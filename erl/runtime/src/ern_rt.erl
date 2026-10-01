%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the launcher.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(process, reason, site) is
%% {'Down', Pid, Reason, Site} in declared field order.
%%
%% An Address is a pid, or {via, F, Target} for an address seen through a
%% function (report §6.5), which send/2 applies in the sender, or
%% {foreign, Pid, D, B} for an address foreign code gave (report §8.4),
%% whose messages cross into foreign code. A Reply(a) is the alias of the
%% call's monitor of its callee, as gen_server's call makes one: it
%% deactivates when the call is over, which drops a late answer (report
%% §6.6). Ernest answers {Alias, answered, V} and foreign code {Alias, V},
%% so that a call checks the second only, as §8.4 says; a Reply foreign code gave
%% back is {foreign_reply, Alias, D, B}, answered in the second form with
%% the answer exposed.
%% Every process body runs under run/1, which turns an exception into an
%% exit reason that Down reports as a Fault. All spawns go through the
%% reaper process, which spawn_monitors each process; a monitor placed
%% after the death reports Unknown (report §6.9), and every monitor is the
%% reaper's. The reaper also detects deadlock (report §8.6): every live
%% process blocked in an untimed receive or in a wait for a call's answer,
%% no timed receive or clock alarm pending, no process inside foreign code,
%% and no source held that can still deliver.
%%
%% Four tables hold the run's state. `ern_processes` has a row {Pid,
%% Site, Timers, Foreign, Spawned} per process the runtime started or
%% adopted, where Timers counts the timed receives the process is in,
%% Foreign its foreign calls, and Spawned its place in the order of spawns,
%% and beside them the way the terminal is read, `reading`, the process
%% deadlock faults, `deadlock_target`, and a row per restart a process may
%% be asked, and per checking proxy of §8.4 and what it stands for.
%% `ern_calls` holds the pending calls, `ern_faults` the subscriptions to
%% faults, and `ern_held` the sources and the processes the system modules
%% opened, each described where it is defined.
-module(ern_rt).

-export([send/2, process_of/1, held/3, is_address/1, spawn/2, spawn_monitored/3, self/0, via/2,
         call/3, call/4, call_forever/2, call_forever/3, answer/2, refuse/2, monitor/2, kill/1,
         reason/1, live/0, processes/0, info/1, faults/1, proxy_for/3, proxy_forget/2,
         source_begin/0, source_begin/1, source_end/0, opened/2, forget_opened/1, timed/0,
         untimed/0, deadline/1, remaining/1, monotonic/0, in_foreign/1,
         undefined_function/3, undefined_lambda/3, fault_reason/3, fault/1, fault/2, trace/1, sys/1,
         hold_terminal/1, terminal_holder/0, shell_holds/0, own_terminal/1, input_not_utf8/0,
         by_input/1, read_input/1, run_main/3, arguments/0, exit_program/1, deadlock_target/1,
         signal/1, initializing/1, site/0, binding/1, restarting/2, restart_now/0, ask_restart/1,
         start_cause/0, spawn_order/1, init_stdlib/0, init_modules/1, ordered/1]).

-compile({no_auto_import, [spawn/2, self/0, monitor/2]}).

-define(UNIT, 'Unit').
-define(PROCESSES, ern_processes).
%% report §6.6, §6.9: each pending call, {Caller, Callee, Alias}, so that a
%% callee that restarts ends the calls waiting on it; a process makes one
%% call at a time, since a message's function and via's are pure, so its
%% row is found and removed by its own pid
-define(CALLS, ern_calls).
%% the same calls by callee, {{Callee, Caller}, Alias}, ordered, so that a
%% restart reads its own callers and no other process's calls
-define(CALLEES, ern_callees).
%% Appendix E.21: each subscription to faults, {Subscriber, To}, in a table
%% of its own, so that a fault reads the subscriptions and not every
%% process's row
-define(FAULTS, ern_faults).
%% report §8.6: what a system process, a listener, a socket or a running
%% program holds that can still deliver, {{source, Holder}, Count}, and the
%% processes the system modules opened, {{opened, Pid}}: few rows, so that
%% the deadlock check reads them without reading every process's
-define(HELD, ern_held).
%% report §6.9: each delivery a process started to a target, {{Target,
%% Starter, Pid}}, ordered, so that a restart of the target reads its own
%% deliveries and no other process's
-define(DELIVERIES, ern_deliveries).
%% The longest wait the host's `receive ... after` takes, in milliseconds.
-define(SLICE, 16#FFFFFFFF).

-type address() :: pid() | {via, fun((term()) -> term()), address()}
                 | {foreign, pid(), term(), map()}.
%% Report §8.2: the system processes, by the names the runtime keeps them
%% under.
-type system() :: stdout | stderr | stdin | clock | fs | terminal | tcp | os.
-type reply() :: reference() | {foreign_reply, reference(), term(), map()}.
%% What a program's answer from foreign code is checked by: its descriptor
%% and the fault's text, or none for the runtime's own calls.
-type check() :: none | {term(), binary()}.

%%
%% Report §6.2, §9.4
%%

-spec send(address(), term()) -> 'Unit'.
send(Addr, Msg) ->
    deliver(Addr, Msg),
    ?UNIT.

%% Report §6.5: an address seen through a function is the target and the
%% function, not a process of its own, so sending applies the function here
%% and the message goes straight into the target's mailbox. A fault in the
%% function is the target's, since the function is part of the protocol the
%% target's own via(self(), wrap) built.
deliver({via, F, Target}, Msg) ->
    try F(Msg) of
        Adapted -> deliver(Target, Adapted)
    catch
        Class:Reason:Stack -> exit(process_of(Target), fault_reason(Class, Reason, Stack))
    end;
%% report §8.4: a message to a foreign address crosses into foreign code
deliver({foreign, Pid, D, B}, Msg) ->
    Pid ! ern_boundary:expose(D, Msg, B);
deliver(Pid, Msg) ->
    Pid ! Msg.

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
    case ets_lookup(?PROCESSES, {behind, Pid}) of
        [{_, Real, _, _}] -> Real;
        _ -> Pid
    end.

%% Report §8.4: an address foreign code gave, whose messages D describes
%% inside the mu bindings B, as the program holds it: where it names one of
%% the program's processes, the address that went out, the proxy in front
%% of it undone and a function `via` made kept (§6.5), and otherwise
%% foreign. A proxy comes back as the address that went out only at the
%% type it went out at; at another it stays foreign, so that what is sent
%% through it is checked against the process's own type.
-spec held(pid(), term(), map()) -> address().
held(Pid, D, B) ->
    case ets_lookup(?PROCESSES, {behind, Pid}) of
        [{_, Real, Exposed, {_, D, B}}] -> own_or_foreign(Real, Exposed, Pid, D, B);
        [{_, _, _, _}] -> {foreign, Pid, D, B};
        _ -> own_or_foreign(Pid, Pid, Pid, D, B)
    end.

own_or_foreign(Real, Address, Pid, D, B) ->
    case ets_lookup(?PROCESSES, Real) of
        [_] -> Address;
        [] -> {foreign, Pid, D, B}
    end.

%% Whether a term is an address in one of the forms the runtime holds.
-spec is_address(term()) -> boolean().
is_address(Pid) when is_pid(Pid) -> true;
is_address({via, F, Target}) when is_function(F, 1) -> is_address(Target);
is_address({foreign, Pid, _, _}) -> is_pid(Pid);
is_address(_) -> false.

%% Site names the spawning function for Down (report §6.9); the compiler
%% supplies it, so this is spawn/2 where the report's spawn takes one.
-spec spawn(fun(() -> term()), binary()) -> address().
spawn(Fun, Site) ->
    spawn_awaited(Fun, Site, []).

%% Report §6.2, §6.9: a process monitored by the caller from its start, the
%% wait made with the spawn, so that no end comes before it.
-spec spawn_monitored(fun(() -> term()), fun((term()) -> term()), binary()) -> pid().
spawn_monitored(Fun, Wrap, Site) ->
    spawn_awaited(Fun, Site, [{erlang:self(), Wrap}]).

spawn_awaited(Fun, Site, Awaits) ->
    Ref = make_ref(),
    persistent_term:get({?MODULE, reaper}) ! {spawn, erlang:self(), Ref, Fun, Site, Awaits},
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
via(Target, F) ->
    {via, F, Target}.

%%
%% Report §6.6
%%

%% Report §6.6: the runtime's own call, whose answer is not checked (§8.4).
-spec call(address(), fun((reply()) -> term()), integer()) -> 'None' | {'Some', term()}.
call(Addr, Mk, Ms) ->
    call(Addr, Mk, Ms, none).

%% Report §6.6, §8.4: a program's call, whose answer from foreign code is
%% checked by Check.
-spec call(address(), fun((reply()) -> term()), integer(), check()) ->
          'None' | {'Some', term()}.
call(Addr, Mk, Ms, Check) ->
    %% report §6.6: the clock starts at the call, before the request is
    %% made and delivered
    Deadline = deadline(Ms),
    line_guard(Addr),
    Alias = pending(Addr),
    %% settled however the call ends, a fault of the message's function or
    %% of the callee among the ways, which a process restarted in place
    %% outlives (§6.9)
    Answer = try
                 deliver(Addr, Mk(Alias)),
                 timed(),
                 try await(Alias, Deadline, Check) after untimed() end
             after
                 settled(Alias)
             end,
    case Answer of
        %% report §6.9: a restart asked for is taken at a call's wait
        '$ern_restart' -> restart_now();
        _ -> Answer
    end.

%% Report §6.6: the answer, or None after the deadline, or at once when the
%% callee ends or restarts before it answers.
await(Alias, Deadline, Check) ->
    receive
        {Alias, answered, V} -> {'Some', V};
        {Alias, V} -> {'Some', foreign_answer(Check, V)};
        {Alias, restarted, _} -> 'None';
        {Alias, fault, Cause} -> fault(Cause);
        {'DOWN', Alias, process, _, _} -> 'None';
        '$ern_restart' -> '$ern_restart'
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 -> 'None';
            _ -> await(Alias, Deadline, Check)
        end
    end.

%% Report §6.6: the runtime's own callForever (§8.4).
-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Addr, Mk) ->
    call_forever(Addr, Mk, none).

%% Report §6.6, §8.4: a program's callForever, whose answer from foreign
%% code is checked by Check.
-spec call_forever(address(), fun((reply()) -> term()), check()) -> term().
call_forever(Addr, Mk, Check) ->
    line_guard(Addr),
    Alias = pending(Addr),
    %% settled however the call ends, as call/4's is
    Answer = try
                 deliver(Addr, Mk(Alias)),
                 receive
                     {Alias, answered, Value} -> {answered, Value};
                     {Alias, Value} -> {answered, foreign_answer(Check, Value)};
                     {Alias, restarted, Restarted} -> {fault, Restarted};
                     %% report §8.2: a system process faults the caller it
                     %% answers
                     {Alias, fault, Faulted} -> {fault, Faulted};
                     {'DOWN', Alias, process, _, Ended} -> {ended, Ended};
                     %% report §6.9: a restart asked for is taken at a call's
                     %% wait
                     '$ern_restart' -> restart
                 end
             after
                 settled(Alias)
             end,
    case Answer of
        {answered, V} -> V;
        {fault, Cause} -> fault(Cause);
        %% report §6.6, Appendix E.18: a socket or a listener the program
        %% closed ended as a function returns, and its caller learns why
        {ended, {ern, closed}} -> fault(<<"callee was closed">>);
        {ended, How} -> ended(reason(How));
        restart -> restart_now()
    end.

%% Report §8.4: an answer foreign code gave, checked against the reply's
%% type as a foreign function's return is.
foreign_answer(none, V) -> V;
foreign_answer({D, Text}, V) -> ern_boundary:value(D, V, Text).

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
pending(Addr) ->
    Callee = process_of(Addr),
    Alias = erlang:monitor(process, Callee, [{alias, demonitor}]),
    ets:insert(?CALLS, {erlang:self(), Callee, Alias}),
    ets:insert(?CALLEES, {{Callee, erlang:self()}, Alias}),
    Alias.

%% The call is over: its rows go, its monitor and with it the alias go, and
%% every answer that came before them, after a restart's word, say, is not
%% left in the caller's mailbox.
settled(Alias) ->
    uncalled(erlang:self()),
    erlang:demonitor(Alias, [flush]),
    flushed(Alias).

%% The pending call of Caller, gone from both tables.
uncalled(Caller) ->
    case ets:take(?CALLS, Caller) of
        [{_, Callee, _}] -> ets:delete(?CALLEES, {Callee, Caller});
        [] -> true
    end.

flushed(Alias) ->
    receive
        {Alias, _} -> flushed(Alias);
        {Alias, _, _} -> flushed(Alias)
    after 0 ->
        ok
    end.

%% Report §6.6, §8.4: an answer in Ernest's form, or in foreign code's for a
%% Reply foreign code gave back, which the caller checks and which crosses
%% into foreign code.
-spec answer(reply(), term()) -> 'Unit'.
answer({foreign_reply, Alias, D, B}, V) ->
    Alias ! {Alias, ern_boundary:expose(D, V, B)},
    ?UNIT;
answer(Alias, V) ->
    Alias ! {Alias, answered, V},
    ?UNIT.

%% Report §8.2, §7.4: a system process faults the caller it answers.
-spec refuse(reply(), binary()) -> 'Unit'.
refuse({foreign_reply, Alias, _, _}, Cause) ->
    refuse(Alias, Cause);
refuse(Alias, Cause) ->
    Alias ! {Alias, fault, Cause},
    ?UNIT.

%%
%% Report §6.9
%%

%% Every monitor is the reaper's: it holds the wrap and delivers the cause,
%% at once if the process is already dead. A process the runtime did not
%% start, a system process, a socket or a running program, is watched from
%% there too, so a monitor costs no process of its own (report §6.9). The
%% monitor is made when the reaper says so, so that a process killed just
%% after it is seen to die rather than found already ended.
-spec monitor(address(), fun((term()) -> term())) -> 'Unit'.
monitor(Addr, Wrap) ->
    Ref = make_ref(),
    persistent_term:get({?MODULE, reaper}) ! {await, process_of(Addr), erlang:self(), Wrap, Ref},
    receive {Ref, watched} -> ?UNIT end.

-spec kill(address()) -> 'Unit'.
kill(Addr) ->
    %% report §8.2: no program can name a system process, whose reference is
    %% private to its module, so any address given here is a program's
    exit(process_of(Addr), {ern, killed}),
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
reason({ern, fault, Msg}) -> {'Fault', Msg};
%% report §6.9, §11.2: the host's stack is the report's, never the cause's
reason({ern, fault, Msg, _Trace}) -> {'Fault', Msg};
%% report §6.9: a monitor made after the end cannot say how it ended
reason(noproc) -> 'Unknown';
reason(Other) -> {'Fault', format("~p", [Other])}.

%% The reaper: spawns on request with a monitor, keeps each live process's
%% row, and tells whoever awaits a process how it ended. Report §6.9: of a
%% process that has ended it keeps nothing, so a monitor made after the end
%% answers Unknown. Waiters: #{Pid => [{To, Wrap}]}; Wrap(Down) is sent to
%% To, or for the launcher, whose wait is made with the spawn so that no
%% race can take the entry process's cause, {raw, Tag}: {Tag, Site, Reason}.
%% Watching: #{To => [Pid]}, the processes each waiter awaits, so that a
%% waiter's death takes its waits with it: nothing is left to deliver them
%% to. Watched: #{Pid => MRef}, a process the runtime did not start, watched
%% here only while someone awaits it.
reaper_loop(Waiters, Watching, Watched) ->
    receive
        {spawn, From, Ref, Fun, Site, Awaits} ->
            %% the process starts once its row is in the table, since a
            %% timed receive it enters first counts itself there (§8.6)
            {Pid, _MRef} = erlang:spawn_monitor(fun() -> receive Ref -> run(Fun) end end),
            ets:insert(?PROCESSES, {Pid, Site, 0, 0, spawn_number()}),
            Pid ! Ref,
            From ! {Ref, Pid},
            %% a wait made with the spawn, spawnMonitored's, is watched as
            %% monitor's is
            Watching1 = lists:foldl(fun({To, _}, W) ->
                                        maps:update_with(To, fun(L) -> [Pid | L] end, [Pid], W)
                                    end, Watching, Awaits),
            reaper_loop(case Awaits of [] -> Waiters; _ -> Waiters#{Pid => Awaits} end,
                        Watching1, Watched);
        {adopt, Pid, Site, From, Ref} ->
            %% report Appendix E.18, E.23: a listener, a socket or a running
            %% program, which its system process starts, is a process of the
            %% program's as one spawned is, watched here and listed
            _ = erlang:monitor(process, Pid),
            ets:insert(?PROCESSES, {Pid, Site, 0, 0, spawn_number()}),
            From ! {Ref, adopted},
            reaper_loop(Waiters, Watching, Watched);
        {await, Pid, To, Wrap, Ref} ->
            Watched1 = case ets:lookup(?PROCESSES, Pid) of
                           [] when not is_map_key(Pid, Watched) ->
                               %% not one the runtime started, so it is watched
                               %% from here; report §8.6: its death would deliver
                               %% a message, which is a source while it is awaited
                               source_begin(),
                               Watched#{Pid => erlang:monitor(process, Pid)};
                           _ ->
                               Watched
                       end,
            To ! {Ref, watched},
            reaper_loop(maps:update_with(Pid, fun(L) -> [{To, Wrap} | L] end, [{To, Wrap}],
                                         Waiters),
                        maps:update_with(To, fun(L) -> [Pid | L] end, [Pid], Watching),
                        Watched1);
        {report, Pid, Site, Fault} ->
            report(Pid, Site, Fault, true),
            reaper_loop(Waiters, Watching, Watched);
        {new_run, Pid, Ref} ->
            %% report §6.9: a restarted process's waits and its subscription
            %% to faults are cancelled, with what is on its way to it; the
            %% waits on it stand, since a restart is not a death
            ets:delete(?FAULTS, Pid),
            {Waiters1, Watched1} = unwatched(Pid, maps:get(Pid, Watching, []), Waiters, Watched),
            cancelled(Pid),
            Pid ! {Ref, fresh},
            reaper_loop(Waiters1, maps:remove(Pid, Watching), Watched1);
        {end_program, From, Ref} ->
            ended_program(From, Ref);
        {'DOWN', _MRef, process, Pid, Reason} ->
            case ets:take(?PROCESSES, Pid) of
                [{_, Site, _, _, _}] ->
                    %% its pending call, which a process killed while it
                    %% waited leaves; a caller learns of a callee's end by
                    %% its own monitor, and removes its own
                    uncalled(Pid),
                    died(Pid, Site, Reason),
                    lists:foreach(fun({To, {raw, Tag}}) -> To ! {Tag, Site, Reason};
                                     ({To, Wrap}) ->
                                          wrapped(To, Wrap, {'Down', Pid, reason(Reason), Site})
                                  end, maps:get(Pid, Waiters, []));
                [] ->
                    %% report §6.9: the spawn site of a process the runtime
                    %% did not start, or of one that had ended, is not known
                    lists:foreach(fun({To, Wrap}) ->
                                      wrapped(To, Wrap, {'Down', Pid, reason(Reason), <<>>})
                                  end, maps:get(Pid, Waiters, [])),
                    is_map_key(Pid, Watched) andalso source_end()
            end,
            case is_map_key(Pid, Waiters) orelse is_map_key(Pid, Watching)
                orelse is_map_key(Pid, Watched) of
                false ->
                    %% nothing awaited it, and it awaited nothing
                    reaper_loop(Waiters, Watching, Watched);
                true ->
                    %% its waiters no longer await it, and its own waits go
                    Watching1 = lists:foldl(fun({To, _}, W) -> forgotten(To, Pid, W) end,
                                            maps:remove(Pid, Watching),
                                            maps:get(Pid, Waiters, [])),
                    {Waiters1, Watched1} = unwatched(Pid, maps:get(Pid, Watching, []),
                                                     maps:remove(Pid, Waiters),
                                                     maps:remove(Pid, Watched)),
                    reaper_loop(Waiters1, Watching1, Watched1)
            end
    after 100 ->
        case deadlocked() of
            true ->
                %% report §8.6, §11.2: the entry process's fault, or under
                %% `ern test` the fault of the test that runs
                case ets:take(?PROCESSES, deadlock_target) of
                    [{_, Target}] ->
                        exit(Target, {ern, fault, <<"deadlock">>});
                    [] ->
                        {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
                        Launcher ! {deadlock, Run}
                end;
            false -> ok
        end,
        reaper_loop(Waiters, Watching, Watched)
    end.

%% Appendix E.22: a number that grows with each process the reaper starts
%% or adopts, so that processes are in the order they were spawned.
spawn_number() ->
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

%% A process a waiter awaited, taken from what the waiter watches once the
%% process has ended; and the clock's timer that fired, taken from its
%% target's. A key left with none goes.
forgotten(To, Pid, Watching) ->
    case maps:get(To, Watching, []) -- [Pid] of
        [] -> maps:remove(To, Watching);
        Left -> Watching#{To => Left}
    end.

%% The waits of a waiter that died, taken from the processes it awaited. A
%% process the runtime did not start that no one awaits any longer is no
%% longer watched, and no longer a source (report §8.6).
unwatched(_To, [], Waiters, Watched) ->
    {Waiters, Watched};
unwatched(To, [Pid | Rest], Waiters, Watched) ->
    case [W || {By, _} = W <- maps:get(Pid, Waiters, []), By =/= To] of
        [] when is_map_key(Pid, Watched) ->
            erlang:demonitor(maps:get(Pid, Watched), [flush]),
            source_end(),
            unwatched(To, Rest, maps:remove(Pid, Waiters), maps:remove(Pid, Watched));
        [] ->
            unwatched(To, Rest, maps:remove(Pid, Waiters), Watched);
        Left ->
            unwatched(To, Rest, Waiters#{Pid => Left}, Watched)
    end.

%% Report §6.9, §6.5: a monitor's wrap is applied as `via`'s function is, a
%% fault in it being the fault of the process it delivers to, and in a
%% process of its own, so that a wrap that does not finish holds up no
%% other delivery. The message counts as a source until it is delivered
%% (§8.6). Linked, so that one that never finishes ends with the program.
wrapped(To, Wrap, Msg) ->
    counted_link(To, fun() -> deliver({via, Wrap, To}, Msg) end).

%% Report §8.6: a process that will deliver a message to the process behind
%% To, counted as a source from before it starts until its work is done,
%% and linked, so that one that never finishes ends with the process that
%% started it. Report §6.9: it is noted against its target and the process
%% that started it, which ends it when the target restarts (cancelled/1).
counted_link(To, Work) ->
    Target = process_of(To),
    Starter = erlang:self(),
    Pid = erlang:spawn_link(fun() ->
                                receive go -> Work(), delivered(Target, Starter) end
                            end),
    try ets:insert(?DELIVERIES, {{Target, Starter, Pid}}) catch _:_ -> true end,
    source_begin(Pid),
    Pid ! go.

delivered(Target, Starter) ->
    try ets:delete(?DELIVERIES, {Target, Starter, erlang:self()}) catch _:_ -> true end,
    source_end().

%% Report §6.9: the deliveries this process started to Target, ended when
%% Target restarts, each waited for, so that none reaches the new run.
cancelled(Target) ->
    Starter = erlang:self(),
    Mine = try ets:select(?DELIVERIES, [{{{Target, Starter, '$1'}}, [], ['$1']}])
           catch _:_ -> []
           end,
    lists:foreach(fun(Pid) ->
                      MRef = erlang:monitor(process, Pid),
                      erlang:unlink(Pid),
                      exit(Pid, kill),
                      receive {'DOWN', MRef, process, Pid, _} -> ok end,
                      ets:delete(?DELIVERIES, {Target, Starter, Pid}),
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
%% every process the runtime started, To being the caller seen through its
%% wrap. A process holds one subscription, the latest, which ends when it
%% dies (the reaper's DOWN).
-spec faults(address()) -> 'Unit'.
faults(To) ->
    try ets:insert(?FAULTS, {process_of(To), To}) catch _:_ -> true end,
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
                         {ern, fault, Msg, Text} -> {Msg, Text};
                         {ern, fault, Msg} -> {Msg, <<>>};
                         _ -> {element(2, reason(Fault)), <<>>}
                     end,
    Report = {'FaultReport', Pid, Site, Cause, Restarted, Trace},
    case persistent_term:get({?MODULE, reporter}, undefined) of
        undefined -> ok;
        Reporter -> Reporter(Report)
    end,
    Subscribers = [To || {_, To} <- matching_rows(?FAULTS, '_')],
    lists:foreach(fun(To) -> counted_link(To, fun() -> deliver(To, Report) end) end, Subscribers).

%% The live processes' rows, each its pid, its spawn site, the counts of its
%% timed waits and of its foreign calls in progress, and its spawn number.
live_rows() ->
    ets:select(?PROCESSES, [{{'_', '_', '_', '_', '_'}, [], ['$_']}]).

%% Report §6.9, §11.2: a process that ended faulting is reported, and a
%% subscription to faults it held ends with it.
died(Pid, Site, Reason) ->
    ets:delete(?FAULTS, Pid),
    ets:delete(?PROCESSES, {restart, Pid}),
    case reason(Reason) of
        {'Fault', _} -> report(Pid, Site, Reason, false);
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
deadlocked() ->
    terminal_holder() =:= undefined
        andalso nothing_delivers()
        andalso begin
                    Pids = [Pid || {Pid, _, _, _, _} <- live_rows()],
                    First = snapshot(Pids),
                    Pids =/= []
                        andalso lists:all(fun({_, S, _}) -> S =:= waiting end, First)
                        andalso nothing_delivers()
                        andalso snapshot(Pids) =:= First
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
    element(2, erlang:process_info(erlang:self(), message_queue_len)) =:= 0
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
         [{status, S}, {reductions, R}] -> {Pid, S, R};
         undefined -> {Pid, dead, 0}
     end || Pid <- Pids].

%% Report §8.4: the checking proxy in front of an address exposed to
%% foreign code is one per address and mailbox type, not one per call: two
%% proxies checking the same messages for the same process are two of the
%% same thing. The loser of a race is killed and the winner used.
-spec proxy_for(term(), address(), fun(() -> pid())) -> pid().
proxy_for(Key, Behind, Start) ->
    case ets:lookup(?PROCESSES, {proxy, Key}) of
        [{_, Pid}] ->
            Pid;
        [] ->
            Pid = Start(),
            case ets:insert_new(?PROCESSES, {{proxy, Key}, Pid}) of
                true ->
                    %% what the proxy stands before, and the key, which
                    %% holds the type it checks (ern_boundary:proxy/4)
                    ets:insert(?PROCESSES, {{behind, Pid}, process_of(Behind), Behind, Key}),
                    Pid;
                false ->
                    exit(Pid, kill),
                    [{_, Winner}] = ets:lookup(?PROCESSES, {proxy, Key}),
                    Winner
            end
    end.

-spec proxy_forget(term(), pid()) -> ok.
proxy_forget(Key, Proxy) ->
    %% the table is gone once the program has ended (report §8.6)
    try
        ets:delete(?PROCESSES, {proxy, Key}),
        ets:delete(?PROCESSES, {behind, Proxy})
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
        lists:sum([N || [N] <- ets:match(?HELD, {{source, '_'}, '$1'})])
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
in_foreign(Fun) ->
    count(4, 1),
    try Fun() after count(4, -1) end.

%% Report §8.6: the host loads a module at the first call into it, and the
%% caller waits on the code server meanwhile, which is the host's work and
%% not a receive of the caller's. Every process the runtime starts has this
%% module as its error handler (run/1), which counts the load as a foreign
%% call is counted and leaves the call itself to the host's handler.
-spec undefined_function(module(), atom(), [term()]) -> term().
undefined_function(Mod, F, Args) ->
    load(Mod),
    error_handler:undefined_function(Mod, F, Args).

-spec undefined_lambda(module(), fun(), [term()]) -> term().
undefined_lambda(Mod, Fun, Args) ->
    load(Mod),
    error_handler:undefined_lambda(Mod, Fun, Args).

load(Mod) ->
    in_foreign(fun() -> code:ensure_loaded(Mod) end).

count(Pos, D) ->
    try ets:update_counter(?PROCESSES, erlang:self(), {Pos, D}) of
        _ -> ok
    catch
        error:badarg -> ok
    end.

%%
%% Report §7: a process body; an exception is a fault
%%

run(Fun) ->
    erlang:process_flag(error_handler, ?MODULE),
    try
        Fun()
    catch
        Class:Reason:Stack -> exit(fault_reason(Class, Reason, Stack))
    end.

%% Report §7.3, §7.4: what a host error is as an Ernest fault. A failure of
%% the runtime is the host's class and reason, and carries the host's stack
%% beside it for the report a person reads (§11.2).
-spec fault_reason(error | exit | throw, term(), list()) -> tuple().
fault_reason(error, badarith, _) -> {ern, fault, <<"division by zero">>};
fault_reason(throw, {ern, fault, Msg}, _) -> {ern, fault, Msg};
fault_reason(throw, {ern, fault, Msg, Trace}, _) -> {ern, fault, Msg, Trace};
fault_reason(Class, Reason, Stack) ->
    {ern, fault, format("~p:~p", [Class, Reason]), trace(Stack)}.

%% Report §7.4, §9.6: a fault with the cause given, the prelude's `fault`
%% and every fault the runtime raises.
-spec fault(binary()) -> no_return().
fault(Msg) ->
    throw({ern, fault, Msg}).

%% A fault with the host's stack beside its cause, a foreign function's
%% raise (§7.4).
-spec fault(binary(), binary()) -> no_return().
fault(Msg, Trace) ->
    throw({ern, fault, Msg, Trace}).

%% Report §11.2: the host's stack as lines to print beneath a fault, the
%% innermost first, each a function and where in its source it was.
-spec trace([tuple()]) -> binary().
trace(Stack) ->
    unicode:characters_to_binary(
      [io_lib:format("    ~p:~p/~p~ts~n", [M, F, arity(A), place(Info)])
       || {M, F, A, Info} <- lists:sublist(Stack, 12)]).

arity(A) when is_list(A) -> length(A);
arity(A) -> A.

place(Info) ->
    case {proplists:get_value(file, Info), proplists:get_value(line, Info)} of
        {undefined, _} -> "";
        {File, undefined} -> io_lib:format(" (~ts)", [File]);
        {File, Line} -> io_lib:format(" (~ts:~B)", [File, Line])
    end.

%%
%% Report §8.2, §9.7: system references
%%

-spec sys(system()) -> address().
sys(Name) ->
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
    port_loop(erlang:open_port({fd, 0, Fd}, [out, binary]), Name);
stream(Out, _Name) ->
    stdout_loop(Out).

stdout_loop(Out) ->
    receive
        {flush, From, Ref} ->
            From ! {Ref, flushed},
            stdout_loop(Out);
        {'Write', Bin, Reply} ->
            Out(Bin),
            answer(Reply, ?UNIT),
            stdout_loop(Out);
        Bin when is_binary(Bin) ->
            Out(Bin),
            stdout_loop(Out)
    end.

port_loop(Port, Name) ->
    receive
        {flush, From, Ref} ->
            case drained(Port) of
                ok -> From ! {Ref, flushed}, port_loop(Port, Name);
                gone -> gone(Name)
            end;
        {'Write', Bin, Reply} ->
            case written(Port, Bin) of
                ok -> answer(Reply, ?UNIT), port_loop(Port, Name);
                gone -> gone(Name)
            end;
        Bin when is_binary(Bin) ->
            case written(Port, Bin) of
                ok -> port_loop(Port, Name);
                gone -> gone(Name)
            end;
        {'EXIT', Port, _} ->
            gone(Name)
    end.

written(Port, Bin) ->
    try erlang:port_command(Port, Bin) of
        true -> ok
    catch
        error:badarg -> gone
    end.

%% What the port was given is written, or the stream has gone.
drained(Port) ->
    case erlang:port_info(Port, queue_size) of
        {queue_size, 0} -> ok;
        {queue_size, _} -> receive {'EXIT', Port, _} -> gone after 1 -> drained(Port) end;
        undefined -> gone
    end.

gone(Name) ->
    {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
    Launcher ! {gone, Run, Name},
    dropping().

%% Report §11: a stream that has gone writes nothing more, and the program
%% ends at once. Until it has, what is written to the stream is dropped and
%% its writer goes on, so that no writer faults for a stream that ended.
dropping() ->
    receive
        {flush, From, Ref} -> From ! {Ref, flushed};
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
hold_terminal(Addr) ->
    persistent_term:put({?MODULE, holder}, process_of(Addr)),
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
line_guard(Addr) ->
    case terminal_holder() of
        undefined -> ok;
        Holder ->
            Stdin = persistent_term:get({?MODULE, stdin}, undefined),
            case process_of(Addr) =:= Stdin andalso erlang:self() =/= Holder of
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
    case ets:insert_new(?PROCESSES, {reading, Kind}) of
        true ->
            ok;
        false ->
            case ets:lookup(?PROCESSES, reading) of
                [{reading, Kind}] ->
                    ok;
                [{reading, Other}] ->
                    {taken, format("the terminal is already read as ~s", [Other])}
            end
    end.

%% Report §7.3, §8.2: a system process ends the program with a fault of
%% the entry process, the launcher's to report.
end_with_fault(Text) ->
    {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
    Launcher ! {fault, Run, Text},
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
                ok ->
                    source_begin(),
                    Rest = case line(Open, Buffer, 0) of
                               {eof, Left} ->
                                   answer(Reply, 'None'), Left;
                               {{line, Line}, Left} ->
                                   answer_line(Reply, without_return(Line)), Left;
                               {{last, Line}, Left} ->
                                   answer_line(Reply, Line), Left;
                               {{error, Reason}, Left} ->
                                   unreadable(Reason), Left
                           end,
                    source_end(),
                    stdin_loop(Open, Rest);
                {taken, Cause} ->
                    refuse(Reply, Cause),
                    stdin_loop(Open, Buffer)
            end;
        {'Read', Reply} ->
            case own_terminal(lines) of
                ok ->
                    source_begin(),
                    case Buffer of
                        <<>> -> bytes(Reply, read_input(Open));
                        _ -> answer(Reply, {'Some', Buffer})
                    end,
                    source_end(),
                    stdin_loop(Open, <<>>);
                {taken, Cause} ->
                    refuse(Reply, Cause),
                    stdin_loop(Open, Buffer)
            end;
        {'EXIT', _, _} ->
            %% an input closed after its answer came
            stdin_loop(Open, Buffer)
    end.

%% The next line and the bytes after it: the bytes before the first line
%% feed at or after From, reading more while there is none. A last line
%% without a line feed is a line, `last`.
line(Open, Buffer, From) ->
    case binary:match(Buffer, <<"\n">>, [{scope, {From, byte_size(Buffer) - From}}]) of
        {At, 1} ->
            <<Line:At/binary, $\n, Rest/binary>> = Buffer,
            {{line, Line}, Rest};
        nomatch ->
            case read_input(Open) of
                {data, Bin} -> line(Open, <<Buffer/binary, Bin/binary>>, byte_size(Buffer));
                eof when Buffer =:= <<>> -> {eof, <<>>};
                eof -> {{last, Buffer}, <<>>};
                {error, Reason} -> {{error, Reason}, Buffer}
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
bytes(Reply, {data, Bin}) -> answer(Reply, {'Some', Bin});
bytes(Reply, eof) -> answer(Reply, 'None');
bytes(_, {error, Reason}) -> unreadable(Reason).

unreadable(Reason) ->
    end_with_fault(<<(unreadable())/binary, (format("~p", [Reason]))/binary>>).

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
%% {error, Reason}. The input is open from the request to its first answer,
%% and what arrived with that answer is taken with it. An exit from a link
%% other than the input's own is the end of the process that reads.
-spec read_input(fun(() -> port() | pid())) -> {data, binary()} | eof | {error, term()}.
read_input(Open) ->
    Input = Open(),
    First = receive
                {Input, {data, Bin}} -> {data, Bin};
                {Input, eof} -> eof;
                {Input, {error, Reason}} -> {error, Reason};
                {'EXIT', Input, Reason} -> {error, Reason};
                {'EXIT', _, Reason} -> close_input(Input), exit(Reason)
            end,
    close_input(Input),
    case First of
        {data, Head} -> {data, arrived(Input, Head)};
        _ -> First
    end.

arrived(Input, Acc) ->
    receive
        {Input, {data, Bin}} -> arrived(Input, <<Acc/binary, Bin/binary>>)
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
%% arrives then, characters, bytes as they are, eof, or {error, Reason}.
fed(Next) ->
    fun() ->
            Owner = erlang:self(),
            erlang:spawn_link(fun() -> Owner ! {erlang:self(), fed_message(Next())} end)
    end.

fed_message(eof) -> eof;
fed_message({error, Reason}) -> {error, Reason};
fed_message(Bin) when is_binary(Bin) -> {data, Bin};
fed_message(Chars) -> {data, unicode:characters_to_binary(Chars)}.

%% Clock's messages, report Appendix E.15: After(ms, reply, to), At(at,
%% reply, to), and Now(reply). Alarms are delivered through the clock
%% itself, so each is counted as a source while it is pending (report
%% §8.6). Alarms holds each pending alarm by its timer, its deadline, where
%% it goes and the process behind that, and Targets each process's timers,
%% so that a restart of that process cancels its own and reads no other's
%% (report §6.9).
clock_loop(Alarms, Targets) ->
    receive
        %% an alarm is answered once it is counted, so that the caller
        %% goes on waiting only on what is counted (report §8.6)
        {'After', Ms, To, Reply} ->
            source_begin(),
            {Alarms1, Targets1} = armed(deadline(Ms), To, Alarms, Targets),
            answer(Reply, ?UNIT),
            clock_loop(Alarms1, Targets1);
        {'At', At, To, Reply} ->
            source_begin(),
            {Alarms1, Targets1} = armed(deadline(At - erlang:system_time(millisecond)), To,
                                        Alarms, Targets),
            answer(Reply, ?UNIT),
            clock_loop(Alarms1, Targets1);
        {timeout, Timer, fire} ->
            case maps:take(Timer, Alarms) of
                {{Deadline, To, Target}, Rest} ->
                    Left = forgotten(Target, Timer, Targets),
                    case remaining(Deadline) of
                        0 ->
                            %% report §6.5, E.15: the alarm's target may be an
                            %% address seen through a function, and it is sent
                            %% the time it fired, from a process of its own, so
                            %% that a function that does not finish holds up no
                            %% other alarm; the alarm is a source until it is
                            %% delivered
                            Now = erlang:system_time(millisecond),
                            counted_link(To, fun() -> deliver(To, Now) end),
                            source_end(),
                            clock_loop(Rest, Left);
                        _ ->
                            {Alarms1, Targets1} = armed(Deadline, To, Rest, Left),
                            clock_loop(Alarms1, Targets1)
                    end;
                error ->
                    %% cancelled by a restart as it fired
                    clock_loop(Alarms, Targets)
            end;
        {'Now', Reply} ->
            answer(Reply, erlang:system_time(millisecond)),
            clock_loop(Alarms, Targets);
        {new_run, Pid, Ref} ->
            %% report §6.9: a restart cancels the process's alarms, and those
            %% on their way to it
            {Timers, Targets1} = case maps:take(Pid, Targets) of
                                     {Own, Others} -> {Own, Others};
                                     error -> {[], Targets}
                                 end,
            lists:foreach(fun(Timer) -> erlang:cancel_timer(Timer), source_end() end, Timers),
            cancelled(Pid),
            Pid ! {Ref, fresh},
            clock_loop(maps:without(Timers, Alarms), Targets1)
    end.

%% Appendix E.0 rule 8: a time has no upper bound, and the host's timers
%% have one, so an alarm is set again until its deadline has passed.
armed(Deadline, To, Alarms, Targets) ->
    Timer = erlang:start_timer(remaining(Deadline), erlang:self(), fire),
    Target = process_of(To),
    {Alarms#{Timer => {Deadline, To, Target}},
     maps:update_with(Target, fun(Timers) -> [Timer | Timers] end, [Timer], Targets)}.

%%
%% Report §8.1, §8.6: the launcher
%%

-type outcome() :: ok | killed | {fault, binary()} | {fault, binary(), binary()}
                 | {initializer_fault, binary(), binary()}
                 | {initializer_fault, binary(), binary(), binary()}
                 | {exit, 0..255} | {gone, stdout | stderr} | {signal, sigterm | sighup}.

%% Runs Main as the entry process. It returns ok, killed if the entry
%% process was killed, {fault, Message} if it faulted, a deadlock among the
%% faults (report §8.6: the entry process faults with `Fault("deadlock")`),
%% and {fault, Message, Trace} where the fault was a failure of the runtime
%% or a foreign function's raise, the host's stack beneath it;
%% {initializer_fault, Site, Message} if a top-level binding faulted before
%% Main ran, Site naming the binding (report §8.5), and the host's stack
%% after them where it faulted so; {exit,
%% Status} if a process called Os.exit, {gone, Stream} if standard output
%% or standard error could no longer be written, or {signal, Signal} if the
%% host's termination or hangup ended the program. Every local process is
%% then ended with ProgramEnd, and standard output and standard error are
%% flushed, however the run ended.
%%
%% Opts: init => a function run in main's process before Main, after the
%% system references are bound and the standard library's lets evaluated,
%% for the program's own top-level lets (report §8.5); arguments => the
%% program's arguments, Os.arguments, none by default; exit => fault, where
%% Os.exit faults its caller rather than ending the program, as in the
%% shell and under `ern test` (report §11.2); faults => fun((FaultReport)
%% -> any()), given every fault as it happens (report §11.2); stdout,
%% stderr => fun((binary()) -> any()), or {fd, N} to write to the file
%% descriptor through a port, which learns when the stream has gone (§8.2);
%% stdin => fun(() -> eof | {error, term()} | unicode:chardata()), called
%% for each read, and keys => the same for the terminal's keys, for tests
%% (fed/1). Report §8.2: the standard streams carry bytes for the run,
%% whatever the host's locale.
-spec run_main(fun(() -> term()), binary(), map()) -> outcome().
run_main(Main, Site, Opts) ->
    ets:new(?PROCESSES, [named_table, public, set]),
    ets:new(?CALLS, [named_table, public, set]),
    ets:new(?CALLEES, [named_table, public, ordered_set]),
    ets:new(?FAULTS, [named_table, public, set]),
    ets:new(?HELD, [named_table, public, set]),
    ets:new(?DELIVERIES, [named_table, public, ordered_set]),
    persistent_term:erase({?MODULE, holder}),
    %% report §11.2: `ern run` reports every fault, the runtime's own
    %% subscriber, given here as a function
    case Opts of
        #{faults := Reporter} -> persistent_term:put({?MODULE, reporter}, Reporter);
        _ -> persistent_term:erase({?MODULE, reporter})
    end,
    Run = make_ref(),
    persistent_term:put({?MODULE, launcher}, {erlang:self(), Run}),
    persistent_term:put({?MODULE, arguments}, maps:get(arguments, Opts, [])),
    persistent_term:put({?MODULE, exit}, maps:get(exit, Opts, program)),
    Reaper = erlang:spawn(fun() -> reaper_loop(#{}, #{}, #{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Encodings = bytes_out(),
    Out = maps:get(stdout, Opts, fun(Bin) -> file:write(standard_io, Bin) end),
    Err = maps:get(stderr, Opts, fun(Bin) -> file:write(standard_error, Bin) end),
    Input = input(stdin, Opts),
    Keys = input(keys, Opts),
    %% report §8.2: keys come where standard input is a terminal, and from
    %% a test's keys
    KeysCome = maps:is_key(keys, Opts) orelse ern_tty:is_terminal(stdin),
    System = [{stdout, erlang:spawn(fun() -> stream(Out, stdout) end)},
              {stderr, erlang:spawn(fun() -> stream(Err, stderr) end)},
              {stdin, erlang:spawn(fun() -> stdin_loop(Input) end)},
              {fs, erlang:spawn(fun ern_fs:loop/0)},
              {terminal, erlang:spawn(fun() -> ern_tty:loop(Keys, KeysCome) end)},
              {tcp, erlang:spawn(fun ern_tcp:loop/0)},
              {os, erlang:spawn(fun ern_os:loop/0)},
              {clock, erlang:spawn(fun() -> clock_loop(#{}, #{}) end)}],
    lists:foreach(fun({Name, Pid}) -> persistent_term:put({?MODULE, Name}, Pid) end, System),
    try
        %% report §8.5: the initializers, the standard library's first, run
        %% in main's process, so one that faults is the program's fault; its
        %% modules are loaded here, where their order is read from them
        Stdlib = stdlib_modules(),
        Init = maps:get(init, Opts, fun() -> ok end),
        %% report §6.9: the launcher's wait is made with the spawn, so the
        %% entry process's cause, and the host's stack beside a failure of
        %% the runtime (§11.2), reach it however soon the process ends
        %% report §8.5, §11.2: an initializer's fault is reported under its
        %% binding, and main's under main's site again once they have run
        MainPid = spawn_awaited(fun() ->
                                        run_inits(Stdlib),
                                        Init(),
                                        initializing(Site),
                                        Main()
                                end, Site,
                                [{erlang:self(), {raw, {main_down, Run}}}]),
        case await_main(MainPid, Run) of
            {{fault, Msg}, At} when At =/= Site -> {initializer_fault, At, Msg};
            {{fault, Msg, Trace}, At} when At =/= Site -> {initializer_fault, At, Msg, Trace};
            {Outcome, _} -> Outcome
        end
    after
        end_program(Run, Reaper, System),
        persistent_term:erase({?MODULE, reporter}),
        restore_encodings(Encodings)
    end.

%% The entry process's end, and its site then. Report §8.6, §8.2: a
%% deadlock, and a fault the runtime finds in a system process's work, fault
%% the entry process, whose end then comes as any process's does, reported
%% as every fault is (§11.2).
await_main(MainPid, Run) ->
    receive
        {{main_down, Run}, At, Raw} ->
            {case {reason(Raw), Raw} of
                 {'Returned', _} -> ok;
                 {'Killed', _} -> killed;
                 {{'Fault', Msg}, {ern, fault, _, Trace}} -> {fault, Msg, Trace};
                 {{'Fault', Msg}, _} -> {fault, Msg};
                 {Other, _} -> {fault, format("~p", [Other])}
             end, At};
        {deadlock, Run} ->
            exit(MainPid, {ern, fault, <<"deadlock">>}),
            await_main(MainPid, Run);
        {fault, Run, Text} ->
            exit(MainPid, {ern, fault, Text}),
            await_main(MainPid, Run);
        {exit, Run, Status} ->
            {{exit, Status}, none};
        {gone, Run, Stream} ->
            {{gone, Stream}, none};
        {signal, Run, Signal} ->
            {{signal, Signal}, none}
    end.

%% Report Appendix E.23: the words after the module on `ern run`'s command
%% line, which the launcher was given; none in the shell and under `ern
%% test` (§11.2).
-spec arguments() -> [binary()].
arguments() ->
    persistent_term:get({?MODULE, arguments}, []).

%% Report §8.6, Appendix E.23: Os.exit ends the program with its status,
%% the launcher ending every process as it does at the entry process's end;
%% the caller waits for its own end there. In the shell and under `ern test`
%% it faults the caller instead (§11.2).
-spec exit_program(integer()) -> no_return().
exit_program(Status) ->
    Status >= 0 andalso Status =< 255 orelse fault(<<"an exit status is from 0 to 255">>),
    case persistent_term:get({?MODULE, exit}, program) of
        fault ->
            fault(format("exited with status ~B", [Status]));
        program ->
            {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
            Launcher ! {exit, Run, Status},
            receive after infinity -> ok end
    end.

input(Key, Opts) ->
    case maps:find(Key, Opts) of
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
-spec deadlock_target(pid() | none) -> ok.
deadlock_target(none) ->
    ets:delete(?PROCESSES, deadlock_target),
    ok;
deadlock_target(Pid) ->
    ets:insert(?PROCESSES, {deadlock_target, Pid}),
    ok.

%% Report §8.6: the host's termination or hangup ends the run in progress
%% as the end of its entry process does; none when no run is in progress.
-spec signal(sigterm | sighup) -> ok | none.
signal(Signal) ->
    case persistent_term:get({?MODULE, launcher}, none) of
        {Pid, Run} ->
            case erlang:is_process_alive(Pid) of
                true -> Pid ! {signal, Run, Signal}, ok;
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
    Kept = case Limit of
               'Unlimited' -> unlimited;
               {'RestartLimit', Restarts, Within} -> {max(Restarts, 0), max(Within, 1)}
           end,
    fun() ->
        Level = restartable(),
        try
            restarts(F, Kept, [], Level)
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
    case ets_lookup(?PROCESSES, {restart, erlang:self()}) of
        [_] ->
            inner;
        [] ->
            ets:insert(?PROCESSES, {{restart, erlang:self()}, erlang:alias([priority])}),
            put('$ern_start', 'First'),
            outer
    end.

%% The outermost restarting function has ended: the process is no longer
%% asked to restart.
unrestartable() ->
    [{_, Alias}] = ets_lookup(?PROCESSES, {restart, erlang:self()}),
    erlang:unalias(Alias),
    ets:delete(?PROCESSES, {restart, erlang:self()}),
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
    case ets_lookup(?PROCESSES, {restart, Pid}) of
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
        [{_, _, _, _, N}] -> N;
        _ -> 0
    end.

restarts(F, Limit, Times, Level) ->
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
            restarts(F, Limit, Times, Level);
        throw:'$ern_restart' ->
            throw('$ern_restart');
        Class:Reason:Stack ->
            Fault = fault_reason(Class, Reason, Stack),
            case within_limit(Limit, Times) of
                {true, Recent} ->
                    %% report §11.2: a fault after which the process
                    %% restarts is reported as one
                    persistent_term:get({?MODULE, reaper}) ! {report, erlang:self(), site(), Fault},
                    fresh_run(),
                    restarted(element(3, Fault)),
                    Level =:= outer andalso put('$ern_start', 'AfterFault'),
                    restarts(F, Limit, Recent, Level);
                false ->
                    %% raised again as the fault it is, for run/1 to end the
                    %% process with, its stack beside it where it had one
                    throw(Fault)
            end
    end.

%% Report §6.9: a restart begins a new run with nothing of the old. What
%% the process asked the runtime for is cancelled, with what is on its way
%% to it: its waits and its subscription to faults by the reaper, its
%% alarms by the clock, its keys by the terminal; then its mailbox is
%% emptied, before the calls waiting on it are told they have ended, so
%% that the request of an ended call is not taken by the new run.
%% The three are asked at once, and each is watched, so that one that has
%% died holds up no restart.
fresh_run() ->
    Self = erlang:self(),
    Asked = [begin
                 Watch = erlang:monitor(process, Service),
                 Service ! {new_run, Self, Watch},
                 Watch
             end || Service <- [persistent_term:get({?MODULE, reaper}), sys(clock),
                                sys(terminal)]],
    lists:foreach(fun(Watch) ->
                      receive
                          {Watch, fresh} -> erlang:demonitor(Watch, [flush]);
                          {'DOWN', Watch, process, _, _} -> ok
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
    Recent = [T || T <- Times, Now - T < Within],
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
    lists:foreach(fun({Caller, Alias}) ->
                      ets:delete(?CALLEES, {Self, Caller}),
                      ets:delete_object(?CALLS, {Caller, Self, Alias}),
                      Alias ! {Alias, restarted, Cause}
                  end, Callers).

%% Report §8.6: every local process ends with ProgramEnd, the sinks' output
%% is flushed, the system processes and the reaper are stopped, and the
%% terminal goes back as the program found it (§8.2).
end_program(Run, Reaper, System) ->
    Ended = make_ref(),
    Watch = erlang:monitor(process, Reaper),
    Reaper ! {end_program, erlang:self(), Ended},
    receive
        {Ended, ended} ->
            ok;
        {'DOWN', Watch, process, _, _} ->
            lists:foreach(fun({Pid, _, _, _, _}) -> exit(Pid, {ern, program_end}) end, live_rows())
    end,
    erlang:demonitor(Watch, [flush]),
    lists:foreach(fun(Sink) ->
                      FlushRef = make_ref(),
                      Mon = erlang:monitor(process, Sink),
                      Sink ! {flush, erlang:self(), FlushRef},
                      %% a sink that died has nothing left to flush, and
                      %% waiting for it would hold the program open
                      receive
                          {FlushRef, flushed} -> ok;
                          {'DOWN', Mon, process, _, _} -> ok
                      end,
                      erlang:demonitor(Mon, [flush])
                  end, [proplists:get_value(K, System) || K <- [stdout, stderr]]),
    %% each ended before the table goes, which the reaper reads
    lists:foreach(fun stop/1, [Pid || {_, Pid} <- System] ++ [Reaper]),
    case ets:lookup(?PROCESSES, reading) of
        [{reading, keys}] -> ern_tty:restore();
        _ -> ok
    end,
    ets:delete(?PROCESSES),
    ets:delete(?CALLS),
    ets:delete(?CALLEES),
    ets:delete(?FAULTS),
    ets:delete(?HELD),
    ets:delete(?DELIVERIES),
    %% a signal after the run has nothing to end (signal/1)
    persistent_term:erase({?MODULE, launcher}),
    flush_run(Run).

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
%% checker finds them (ern_prelude:stdlib_ifaces/0). The shell's modules
%% are on the same path and are not the standard library's; the shell
%% initializes them as a program's own (init_modules/1).
stdlib_modules() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(D, "ern@*.beam"))
                                      || D <- code:get_path(),
                                         filename:basename(D) =:= "stdlib"])),
    Mods = [list_to_atom(filename:basename(File, ".beam")) || File <- Files],
    lists:foreach(fun(Mod) -> code:ensure_loaded(Mod) end, Mods),
    ordered(Mods).

%% Report §8.5: the top-level lets of the modules given and of the modules
%% they depend on through `'$deps'/0`, dependencies first, each module once;
%% the order of the list is kept where no dependency decides it.
-spec init_modules([module()]) -> ok.
init_modules(Mods) ->
    {Order, _} = lists:foldl(fun(Mod, Acc) -> visit(Mod, all, Acc) end, {[], #{}}, Mods),
    run_inits(lists:reverse(Order)).

run_inits(Mods) ->
    lists:foreach(fun(Mod) ->
                      case erlang:function_exported(Mod, '$init', 0) of
                          true -> Mod:'$init'();
                          false -> ok
                      end
                  end, Mods).

%% Report §8.5: dependency order, which each compiled module declares as
%% `'$deps'/0`; the order within an independent set is unspecified, and
%% is the alphabetical one the code path gives.
-spec ordered([module()]) -> [module()].
ordered(Mods) ->
    {Order, _} = lists:foldl(fun(Mod, Acc) -> visit(Mod, Mods, Acc) end, {[], #{}}, Mods),
    lists:reverse(Order).

visit(Mod, Mods, {Order, Seen}) ->
    case Seen of
        #{Mod := _} ->
            {Order, Seen};
        _ ->
            Deps = [D || D <- deps_of(Mod), Mods =:= all orelse lists:member(D, Mods)],
            {Order1, Seen1} = lists:foldl(fun(D, Acc) -> visit(D, Mods, Acc) end,
                                          {Order, Seen#{Mod => true}}, Deps),
            {[Mod | Order1], Seen1}
    end.

%% A module is loaded as the error handler loads one, counted as a foreign
%% call, since init_modules/1 runs in the entry process (report §8.6).
deps_of(Mod) ->
    load(Mod),
    case erlang:function_exported(Mod, '$deps', 0) of
        true -> Mod:'$deps'();
        false -> []
    end.

stop(Pid) ->
    Ref = erlang:monitor(process, Pid),
    exit(Pid, kill),
    receive {'DOWN', Ref, process, Pid, _} -> ok end.

%% What the reaper, the system processes and a signal may still send about
%% this run after it ended.
flush_run(Run) ->
    receive
        {{main_down, Run}, _, _} -> flush_run(Run);
        {deadlock, Run} -> flush_run(Run);
        {fault, Run, _} -> flush_run(Run);
        {exit, Run, _} -> flush_run(Run);
        {gone, Run, _} -> flush_run(Run);
        {signal, Run, _} -> flush_run(Run)
    after 0 ->
        ok
    end.

format(Fmt, Args) ->
    unicode:characters_to_binary(io_lib:format(Fmt, Args)).
