%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the launcher.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(reason, site) is
%% {'Down', Reason, Site} in canonical field order.
%%
%% An Address is a pid, or {via, F, Target} for an address seen through a
%% function (report §6.5), which send/2 applies in the sender. A Reply(a)
%% is a process alias made with alias([reply]): it deactivates after the
%% first answer, and unalias after a timeout drops late ones (report §6.6).
%% Every process body runs under run/1, which turns an exception into an
%% exit reason that Down reports as a Fault. All spawns go through the
%% reaper process, which spawn_monitors each process and records how it
%% ended, so a monitor placed after the death still reports the cause
%% (report §6.9); every monitor is the reaper's. The reaper also detects
%% Deadlock (report §8.6): every live process blocked in an untimed
%% receive, no timed receive or clock alarm pending, no process inside
%% foreign code. The process table holds a row {Pid, Site, State, Timers,
%% Foreign} per process the runtime started, where Timers counts the timed
%% receives the process is in and Foreign its foreign calls, and beside
%% them the count of sources, the way the terminal is read, and the
%% checking proxies of §8.4.
-module(ern_rt).

-export([send/2, process_of/1, spawn/3, spawn_monitored/4, self/0, via/2, call/3,
         call_forever/2, answer/2, monitor/2, kill/1, live/0, processes/0, info/1, faults/1,
         proxy_for/3,
         proxy_forget/2, source_begin/0, source_begin/1, source_end/0, opened/1,
         forget_opened/1, timed/0, untimed/0, deadline/1, remaining/1, in_foreign/1,
         undefined_function/3, undefined_lambda/3, remote/1, fault/1, fault/2,
         trace/1, sys/1, hold_terminal/1, terminal_holder/0, shell_holds/0, own_terminal/1,
         binding/1, run_main/2, run_main/3, signal/1, deadlock_target/1, restarting/2,
         init_stdlib/0, read_input/1, input_not_utf8/0, reason/1]).

-compile({no_auto_import, [spawn/3, self/0, monitor/2]}).

-define(UNIT, 'Unit').
-define(PROCESSES, ern_processes).
%% report §6.6, §6.9: each pending call, {Callee, Caller, Alias}, so that a
%% callee that restarts ends the calls waiting on it
-define(CALLS, ern_calls).
%% The longest wait the host's `receive ... after` takes, in milliseconds.
-define(SLICE, 16#FFFFFFFF).

-type address() :: pid() | {via, fun((term()) -> term()), address()}.
-type reply() :: reference().

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
%% target's own via(wrap, self()) built.
deliver({via, F, Target}, Msg) ->
    try F(Msg) of
        Adapted -> deliver(Target, Adapted)
    catch
        Class:Reason:Stack -> exit(process_of(Target), fault_reason(Class, Reason, Stack))
    end;
deliver(Pid, Msg) ->
    Pid ! Msg.

%% The process an address names, through any number of adaptations and
%% through the checking proxy of §8.4: an address that has crossed into
%% foreign code comes back as the proxy in front of it, and what the
%% runtime holds of a process, its terminal, its monitors, its death,
%% must be the process itself.
-spec process_of(address()) -> pid().
process_of({via, _, Target}) -> process_of(Target);
process_of(Pid) -> behind(Pid).

behind(Pid) ->
    try ets:lookup(?PROCESSES, {behind, Pid}) of
        [{_, Real}] -> Real;
        _ -> Pid
    catch _:_ -> Pid
    end.

%% Site names the spawning function for Down (report §6.9); the compiler
%% supplies it, so this is spawn/3 where the report's spawn takes two.
-spec spawn('Local' | {'Peer', binary()}, fun(() -> term()), binary()) -> address().
spawn('Local', Fun, Site) ->
    spawn_awaited(Fun, Site, []);
spawn({'Peer', _Name}, _Fun, _Site) ->
    fault(<<"peer unreachable">>).

%% Report §6.2, §6.9: a process monitored by the caller from its start, the
%% wait made with the spawn, so that no end comes before it.
-spec spawn_monitored(term(), fun(() -> term()), fun((term()) -> term()), binary()) -> pid().
spawn_monitored('Local', Fun, Wrap, Site) ->
    spawn_awaited(Fun, Site, [{erlang:self(), Wrap}]);
spawn_monitored({'Peer', _Name}, _Fun, _Wrap, _Site) ->
    fault(<<"peer unreachable">>).

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

-spec via(fun((term()) -> term()), address()) -> address().
via(F, Target) ->
    {via, F, Target}.

%%
%% Report §6.6
%%

-spec call(address(), fun((reply()) -> term()), integer()) -> 'None' | {'Some', term()}.
call(Addr, Mk, Ms) ->
    line_guard(Addr),
    {Alias, Mon, Row} = pending(Addr),
    deliver(Addr, Mk(Alias)),
    timed(),
    Answer = await(Alias, Mon, deadline(Ms)),
    untimed(),
    settled(Alias, Mon, Row),
    Answer.

%% Report §6.6: the answer, or None after the deadline, or at once when the
%% callee ends or restarts before it answers.
await(Alias, Mon, Deadline) ->
    receive
        {Alias, V} -> {'Some', V};
        {Alias, restarted, _} -> 'None';
        {Alias, fault, Cause} -> fault(Cause);
        {'DOWN', Mon, process, _, _} -> 'None'
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 -> 'None';
            _ -> await(Alias, Mon, Deadline)
        end
    end.

-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Addr, Mk) ->
    line_guard(Addr),
    {Alias, Mon, Row} = pending(Addr),
    deliver(Addr, Mk(Alias)),
    receive
        {Alias, V} ->
            settled(Alias, Mon, Row),
            V;
        {Alias, restarted, Cause} ->
            settled(Alias, Mon, Row),
            fault(Cause);
        {Alias, fault, Cause} ->
            %% report §8.2: a system process faults the caller it answers
            settled(Alias, Mon, Row),
            fault(Cause);
        {'DOWN', Mon, process, _, Reason} ->
            settled(Alias, Mon, Row),
            ended(reason(Reason))
    end.

%% Report §6.6, §7.4: a callForever whose callee ended faults the caller with
%% the callee's cause, or says how it ended; with the program the caller
%% ends too.
ended({'Fault', Cause}) -> fault(Cause);
ended('Killed') -> fault(<<"callee was killed">>);
ended('Returned') -> fault(<<"callee returned without answering">>);
ended('Unknown') -> fault(<<"callee had ended">>);
ended('ProgramEnd') ->
    %% a signal, not an exception, which run/1 would take for a fault
    exit(erlang:self(), {ern, program_end}),
    receive after infinity -> ok end.

%% A call's reply alias, a monitor of the process behind the address, and
%% the call noted against that process, so that its restart ends the call.
pending(Addr) ->
    Callee = process_of(Addr),
    Alias = erlang:alias([reply]),
    Mon = erlang:monitor(process, Callee),
    Row = {Callee, erlang:self(), Alias},
    ets:insert(?CALLS, Row),
    {Alias, Mon, Row}.

%% The call is over: its row goes, its monitor goes, and an answer that
%% came late is not left in the caller's mailbox.
settled(Alias, Mon, Row) ->
    ets:delete_object(?CALLS, Row),
    erlang:demonitor(Mon, [flush]),
    erlang:unalias(Alias),
    receive
        {Alias, _} -> ok;
        {Alias, restarted, _} -> ok;
        {Alias, fault, _} -> ok
    after 0 ->
        ok
    end.

-spec answer(reply(), term()) -> 'Unit'.
answer(Reply, V) ->
    Reply ! {Reply, V},
    ?UNIT.

%%
%% Report §6.9
%%

%% Every monitor is the reaper's: it holds the wrap and delivers the cause,
%% at once if the process is already dead. A process the runtime did not
%% start, a system process or a socket, is watched from there too, so a
%% monitor costs no process of its own (report §6.9).
-spec monitor(address(), fun((term()) -> term())) -> 'Unit'.
monitor(Addr, Wrap) ->
    persistent_term:get({?MODULE, reaper}) ! {await, process_of(Addr), erlang:self(), Wrap},
    ?UNIT.

-spec kill(address()) -> 'Unit'.
kill(Addr) ->
    %% report §8.2: no program can name a system process, whose reference is
    %% private to its module, so any address given here is a program's
    exit(process_of(Addr), {ern, killed}),
    ?UNIT.

-spec reason(term()) -> term().
reason(normal) -> 'Returned';
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
reaper_loop(Waiters) ->
    receive
        {spawn, From, Ref, Fun, Site, Awaits} ->
            %% the process starts once its row is in the table, since a
            %% timed receive it enters first counts itself there (§8.6)
            {Pid, _MRef} = erlang:spawn_monitor(fun() -> receive Ref -> run(Fun) end end),
            ets:insert(?PROCESSES, {Pid, Site, alive, 0, 0}),
            Pid ! Ref,
            From ! {Ref, Pid},
            reaper_loop(case Awaits of [] -> Waiters; _ -> Waiters#{Pid => Awaits} end);
        {await, Pid, To, Wrap} ->
            case ets:lookup(?PROCESSES, Pid) of
                [] when not is_map_key(Pid, Waiters) ->
                    %% not one the runtime started, so it is watched from
                    %% here; report §8.6: its death would deliver a message,
                    %% which is a source while it is awaited
                    erlang:monitor(process, Pid),
                    source_begin(),
                    reaper_loop(Waiters#{Pid => [{To, Wrap}]});
                _ ->
                    reaper_loop(maps:update_with(Pid, fun(L) -> [{To, Wrap} | L] end,
                                                 [{To, Wrap}], Waiters))
            end;
        {report, Pid, Site, Fault} ->
            report(Pid, Site, Fault, true),
            reaper_loop(Waiters);
        {'DOWN', _MRef, process, Pid, Reason} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, alive, _, _}] ->
                    ets:delete(?PROCESSES, Pid),
                    %% its pending calls, as the one called and as the caller;
                    %% a caller learns of a callee's end by its own monitor
                    ets:delete(?CALLS, Pid),
                    ets:match_delete(?CALLS, {'_', Pid, '_'}),
                    died(Pid, Site, Reason),
                    Down = {'Down', reason(Reason), Site},
                    lists:foreach(fun({To, {raw, Tag}}) -> To ! {Tag, Site, Reason};
                                     ({To, Wrap}) -> wrapped(To, Wrap, Down)
                                  end, maps:get(Pid, Waiters, []));
                [] ->
                    %% report §6.9: the spawn site of a process the runtime
                    %% did not start, or of one that had ended, is not known
                    lists:foreach(fun({To, Wrap}) ->
                                      wrapped(To, Wrap, {'Down', reason(Reason), <<>>})
                                  end, maps:get(Pid, Waiters, [])),
                    is_map_key(Pid, Waiters) andalso source_end();
                _ ->
                    ok
            end,
            reaper_loop(maps:remove(Pid, Waiters))
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
        reaper_loop(Waiters)
    end.

%% Report §6.9, §6.5: a monitor's wrap is applied as `via`'s function is, a
%% fault in it being the fault of the process it delivers to, and in a
%% process of its own, so that a wrap that does not finish holds up no
%% other delivery. The message counts as a source until it is delivered
%% (§8.6). Linked, so that one that never finishes ends with the program.
wrapped(To, Wrap, Msg) ->
    counted_link(fun() -> deliver({via, Wrap, To}, Msg) end).

%% Report §8.6: a process that will deliver a message, counted as a source
%% from before it starts until its work is done, and linked, so that one
%% that never finishes ends with the process that started it.
counted_link(Work) ->
    Pid = erlang:spawn_link(fun() -> receive go -> Work(), source_end() end end),
    source_begin(Pid),
    Pid ! go.

%% The live processes the runtime started with their spawn sites, which
%% the shell's :reload reads to find what still runs a module.
-spec live() -> [{pid(), binary()}].
live() ->
    try [{Pid, Site} || {Pid, Site, _, _} <- live_rows()]
    catch _:_ -> []
    end.

%% Appendix E.21: Process.live, the live processes the runtime started, the
%% system processes excepted, which it does not start as it starts these.
-spec processes() -> [pid()].
processes() ->
    [Pid || {Pid, _} <- live()].

%% Appendix E.21: Process.info, a snapshot of a live process, None once it
%% has ended and for a process on another node. A process waiting for a
%% call's answer is Calling, which the host's status does not tell from a
%% receive: its pending call is in the table of calls (§6.6).
-spec info(pid()) -> 'None' | {'Some', {'Info', atom(), non_neg_integer(), binary()}}.
info(Pid) when node(Pid) =:= node() ->
    case {ets_lookup(?PROCESSES, Pid),
          erlang:process_info(Pid, [status, message_queue_len])} of
        {[{_, Site, alive, _, _}], [{status, Status}, {message_queue_len, Queued}]} ->
            Activity = case Status of
                           waiting ->
                               case ets_match(?CALLS, {'_', Pid, '_'}) of
                                   [] -> 'Receiving';
                                   _ -> 'Calling'
                               end;
                           _ -> 'Running'
                       end,
            {'Some', {'Info', Activity, Queued, Site}};
        _ ->
            'None'
    end;
info(_) ->
    'None'.

ets_lookup(Table, Key) ->
    try ets:lookup(Table, Key) catch _:_ -> [] end.

ets_match(Table, Pattern) ->
    try ets:match_object(Table, Pattern) catch _:_ -> [] end.

%% Appendix E.21: Process.faults, the caller subscribed to every fault of
%% every process the runtime started, To being the caller seen through its
%% wrap. A process holds one subscription, the latest, which ends when it
%% dies (the reaper's DOWN).
-spec faults(address()) -> 'Unit'.
faults(To) ->
    try ets:insert(?PROCESSES, {{faults, process_of(To)}, To}) catch _:_ -> true end,
    ?UNIT.

%% Report §11.2, Appendix E.21: a fault, which each subscriber is sent as a
%% FaultReport, each delivery a process of its own as a monitor's is, and
%% which `ern run`'s reporter, the runtime's own subscriber, is given as it
%% happens, before the process's end reaches anyone who waits on it. The
%% fields are in canonical order: cause, process, restarted, site, trace.
%% The reaper reports, so that a delivery is linked to a process that lives
%% as long as the run; a process that restarts sends it its fault.
report(Pid, Site, Fault, Restarted) ->
    {Cause, Trace} = case Fault of
                         {ern, fault, Msg, Stack} -> {Msg, Stack};
                         {ern, fault, Msg} -> {Msg, <<>>};
                         _ -> {element(2, reason(Fault)), <<>>}
                     end,
    Report = {'FaultReport', Cause, Pid, Restarted, Site, Trace},
    case persistent_term:get({?MODULE, reporter}, undefined) of
        undefined -> ok;
        Reporter -> Reporter(Report)
    end,
    Subscribers = try ets:match(?PROCESSES, {{faults, '_'}, '$1'}) catch _:_ -> [] end,
    lists:foreach(fun([To]) -> counted_link(fun() -> deliver(To, Report) end) end,
                  Subscribers).

%% The live processes' rows, each its pid, its spawn site, and the counts
%% of its timed waits and of its foreign calls in progress.
live_rows() ->
    ets:select(?PROCESSES, [{{'$1', '$2', alive, '$3', '$4'}, [], [{{'$1', '$2', '$3', '$4'}}]}]).

%% Report §6.9, §11.2: a process that ended faulting is reported, and a
%% subscription to faults it held ends with it.
died(Pid, Site, Reason) ->
    ets:delete(?PROCESSES, {faults, Pid}),
    case reason(Reason) of
        {'Fault', _} -> report(Pid, Site, Reason, false);
        _ -> ok
    end.

%% Report §8.6. Two snapshots of every live process's status and reduction
%% count, equal, with every status waiting, prove that nothing ran between
%% them; a timed receive, a foreign call in progress, and a source held by
%% a system process are what can still deliver.
%%
%% A message in flight to a system process would deliver too, and a system
%% process is not in the table, so each one's mailbox and status are read
%% as well: between taking a message out and counting the source it holds,
%% it is running rather than waiting, and the check sees that. The reaper
%% is the process making the check, so its own mailbox is what is read of
%% it. §8.6 leaves a foreign process that can deliver to the runtime. Report
%% §11.2: nothing is a deadlock while a shell holds the terminal.
deadlocked() ->
    terminal_holder() =:= undefined
        andalso deadlocked([{Pid, T, F} || {Pid, _, T, F} <- live_rows()]).

deadlocked(Rows) ->
    Rows =/= []
        andalso lists:all(fun({_, T, F}) -> T =:= 0 andalso F =:= 0 end, Rows)
        andalso sources() =:= 0
        andalso quiet_system()
        andalso begin
                    Pids = [Pid || {Pid, _, _} <- Rows],
                    First = snapshot(Pids),
                    lists:all(fun({_, S}) -> S =:= waiting end, [{P, St} || {P, St, _} <- First])
                        andalso snapshot(Pids) =:= First
                        andalso quiet_system()
                end.

quiet_system() ->
    element(2, erlang:process_info(erlang:self(), message_queue_len)) =:= 0
        andalso lists:all(fun(Key) ->
                              case persistent_term:get({?MODULE, Key}, undefined) of
                                  undefined -> true;
                                  Pid -> quiet(Pid)
                              end
                          end, [stdout, stderr, stdin, fs, terminal, tcp, clock])
        andalso lists:all(fun quiet/1, opened()).

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
-spec proxy_for(term(), pid(), fun(() -> pid())) -> pid().
proxy_for(Key, Behind, Start) ->
    case ets:lookup(?PROCESSES, {proxy, Key}) of
        [{_, Pid}] ->
            Pid;
        [] ->
            Pid = Start(),
            case ets:insert_new(?PROCESSES, {{proxy, Key}, Pid}) of
                true ->
                    ets:insert(?PROCESSES, {{behind, Pid}, Behind}),
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
    try ets:update_counter(?PROCESSES, Key, {2, 1}, {Key, 0}) catch _:_ -> 0 end,
    ok.

-spec source_end() -> ok.
source_end() ->
    Key = {source, erlang:self()},
    try ets:update_counter(?PROCESSES, Key, {2, -1}) of
        0 -> ets:delete_object(?PROCESSES, {Key, 0});
        _ -> true
    catch _:_ ->
        true
    end,
    ok.

sources() ->
    try
        lists:sum([N || [N] <- ets:match(?PROCESSES, {{source, '_'}, '$1'})])
    catch _:_ ->
        1
    end.

%% Report §8.6, Appendix E.18: a listener or a socket, which a system
%% module's functions open, is checked as a system process is, a request
%% in its mailbox being a message in flight. It is recorded by the process
%% that starts it, before its address is given out, and forgotten with its
%% sources when it ends, which the process it is linked to learns.
-spec opened(pid()) -> ok.
opened(Pid) ->
    try ets:insert(?PROCESSES, {{opened, Pid}}) catch _:_ -> true end,
    ok.

-spec forget_opened(pid()) -> ok.
forget_opened(Pid) ->
    try
        ets:delete(?PROCESSES, {opened, Pid}),
        ets:delete(?PROCESSES, {source, Pid})
    catch _:_ ->
        true
    end,
    ok.

opened() ->
    try [Pid || [Pid] <- ets:match(?PROCESSES, {{opened, '$1'}})] catch _:_ -> [] end.

%% A timed receive counts itself in before and out first in every body,
%% so tail position holds; the compiler emits the calls (report §8.6).
-spec timed() -> ok.
timed() ->
    count(4, 1).

-spec untimed() -> ok.
untimed() ->
    count(4, -1).

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

%% Report §8.4, §8.6: a process inside foreign code is not waiting.
-spec in_foreign(fun(() -> term())) -> term().
in_foreign(Fun) ->
    count(5, 1),
    try Fun() after count(5, -1) end.

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
%% Report §6.7: no peer is configured in MVP 1
%%

-spec remote(fun(() -> term())) -> {'Left', 'NoRemotePeer'}.
remote(_F) ->
    {'Left', 'NoRemotePeer'}.

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

-spec sys(stdout | stderr | stdin | clock | fs | terminal | tcp) -> address().
sys(Name) ->
    persistent_term:get({?MODULE, Name}).

%% Report §8.2: stdout and stderr each write what they receive, as bytes.
stdout_loop(Out) ->
    receive
        {flush, From, Ref} ->
            From ! {Ref, flushed},
            stdout_loop(Out);
        Bin when is_binary(Bin) ->
            Out(Bin),
            stdout_loop(Out)
    end.

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
    <<"the shell holds the terminal; run the program with ern to give it the keyboard">>.

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
%% program does one or the other, and the second to ask ends it. The first
%% to ask claims it in one step, so two that ask at once are one claim.
-spec own_terminal(lines | keys) -> ok | taken.
own_terminal(Kind) ->
    case ets:insert_new(?PROCESSES, {reading, Kind}) of
        true ->
            ok;
        false ->
            case ets:lookup(?PROCESSES, reading) of
                [{reading, Kind}] ->
                    ok;
                [{reading, Other}] ->
                    end_with_fault(format("the terminal is already read as ~s", [Other])),
                    taken
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
        {'ReadLine', Reply} ->
            own_terminal(lines),
            source_begin(),
            Rest = case line(Open, Buffer, 0) of
                       {eof, Left} -> answer(Reply, 'None'), Left;
                       {{line, Line}, Left} -> answer_line(Reply, Line), Left;
                       {{error, Reason}, Left} -> unreadable(Reason), Left
                   end,
            source_end(),
            stdin_loop(Open, Rest);
        {'Read', Reply} ->
            own_terminal(lines),
            source_begin(),
            case Buffer of
                <<>> -> bytes(Reply, read_input(Open));
                _ -> answer(Reply, {'Some', Buffer})
            end,
            source_end(),
            stdin_loop(Open, <<>>);
        {'EXIT', _, _} ->
            %% an input closed after its answer came
            stdin_loop(Open, Buffer)
    end.

%% The next line and the bytes after it: the bytes before the first line
%% feed at or after From, reading more while there is none. A last line
%% without a line feed is a line.
line(Open, Buffer, From) ->
    case binary:match(Buffer, <<"\n">>, [{scope, {From, byte_size(Buffer) - From}}]) of
        {At, 1} ->
            <<Line:At/binary, $\n, Rest/binary>> = Buffer,
            {{line, Line}, Rest};
        nomatch ->
            case read_input(Open) of
                {data, Bin} -> line(Open, <<Buffer/binary, Bin/binary>>, byte_size(Buffer));
                eof when Buffer =:= <<>> -> {eof, <<>>};
                eof -> {{line, Buffer}, <<>>};
                {error, Reason} -> {{error, Reason}, Buffer}
            end
    end.

%% Report §8.2, §7.4: a line without one carriage return before its line
%% feed, or the fault of the process that asked, when it is not UTF-8.
answer_line(Reply, Line) ->
    Text = case Line of
               <<Head:(byte_size(Line) - 1)/binary, $\r>> -> Head;
               _ -> Line
           end,
    case unicode:characters_to_binary(Text, utf8, utf8) of
        Text -> answer(Reply, {'Some', Text});
        _ -> Reply ! {Reply, fault, not_utf8()}
    end.

%% Report §8.2: what has arrived, at least one byte, or None at the end.
bytes(Reply, {data, Bin}) -> answer(Reply, {'Some', Bin});
bytes(Reply, eof) -> answer(Reply, 'None');
bytes(_, {error, Reason}) -> unreadable(Reason).

unreadable(Reason) ->
    end_with_fault(format("the standard input could not be read: ~p", [Reason])).

not_utf8() ->
    <<"the standard input is not UTF-8">>.

%% Report §8.2, §7.4: keys that are not UTF-8 end the program with the
%% fault of its entry process, since no process asked for them.
-spec input_not_utf8() -> ok.
input_not_utf8() ->
    end_with_fault(not_utf8()).

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

%% Clock's message, report Appendix E.15: After(ms, to), At(at, to), Now(reply). Alarms are
%% delivered through the clock itself, so each is counted as a source while
%% it is pending (report §8.6).
clock_loop() ->
    receive
        {'After', Ms, To} ->
            source_begin(),
            arm(deadline(Ms), To),
            clock_loop();
        {'At', At, To} ->
            source_begin(),
            arm(deadline(At - erlang:system_time(millisecond)), To),
            clock_loop();
        {fire, Deadline, To} ->
            case remaining(Deadline) of
                0 ->
                    %% report §6.5, E.15: the alarm's target may be an
                    %% address seen through a function, and it is sent the
                    %% time it fired, from a process of its own, so that a
                    %% function that does not finish holds up no other
                    %% alarm; the alarm is a source until it is delivered
                    Now = erlang:system_time(millisecond),
                    counted_link(fun() -> deliver(To, Now) end),
                    source_end();
                _ ->
                    arm(Deadline, To)
            end,
            clock_loop();
        {'Now', Reply} ->
            answer(Reply, erlang:system_time(millisecond)),
            clock_loop()
    end.

%% Appendix E.0 rule 8: a time has no upper bound, and the host's timers
%% have one, so an alarm is set again until its deadline has passed.
arm(Deadline, To) ->
    erlang:send_after(remaining(Deadline), erlang:self(), {fire, Deadline, To}).

%%
%% Report §8.1, §8.6: the launcher
%%

%% Runs Main as the entry process and returns ok, killed if it was killed,
%% {fault, Message} if it faulted, a deadlock among the faults (report §8.6:
%% the entry process faults with `Fault("deadlock")`), or {signal, Signal}
%% if the host's termination or hangup ended the program. Every local process is then ended with
%% ProgramEnd and stdout is flushed, however the run ended. Opts: init => a
%% function run in main's process before Main, after the system references
%% are bound and the standard library's lets evaluated, for the program's
%% own top-level lets (report §8.5); faults => fun((FaultReport) -> any()),
%% given every fault as it happens (report §11.2); stdout, stderr =>
%% fun((binary()) -> any()), stdin => fun(() -> eof | {error, term()} |
%% unicode:chardata()), called for each read, and keys => the same for the
%% terminal's keys, for tests (fed/1). Report §8.2: the standard streams
%% carry bytes for the run, whatever the host's locale.
-type outcome() :: ok | killed | {fault, binary()} | {fault, binary(), binary()}
                 | {signal, sigterm | sighup}.

-spec run_main(fun(() -> term()), binary()) -> outcome().
run_main(Main, Site) ->
    run_main(Main, Site, #{}).

-spec run_main(fun(() -> term()), binary(), map()) -> outcome().
run_main(Main, Site, Opts) ->
    ets:new(?PROCESSES, [named_table, public, set]),
    ets:new(?CALLS, [named_table, public, bag]),
    persistent_term:erase({?MODULE, holder}),
    %% report §11.2: `ern run` reports every fault, the runtime's own
    %% subscriber, given here as a function
    case Opts of
        #{faults := Reporter} -> persistent_term:put({?MODULE, reporter}, Reporter);
        _ -> persistent_term:erase({?MODULE, reporter})
    end,
    Run = make_ref(),
    persistent_term:put({?MODULE, launcher}, {erlang:self(), Run}),
    Reaper = erlang:spawn(fun() -> reaper_loop(#{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Encodings = bytes_out(),
    Out = maps:get(stdout, Opts, fun(Bin) -> file:write(standard_io, Bin) end),
    Err = maps:get(stderr, Opts, fun(Bin) -> file:write(standard_error, Bin) end),
    Input = input(stdin, Opts),
    Keys = input(keys, Opts),
    %% report §8.2: keys come where standard input is a terminal, and from
    %% a test's keys
    KeysCome = maps:is_key(keys, Opts) orelse ern_tty:is_terminal(stdin),
    System = [{stdout, erlang:spawn(fun() -> stdout_loop(Out) end)},
              {stderr, erlang:spawn(fun() -> stdout_loop(Err) end)},
              {stdin, erlang:spawn(fun() -> stdin_loop(Input) end)},
              {fs, erlang:spawn(fun ern_fs:loop/0)},
              {terminal, erlang:spawn(fun() -> ern_tty:loop(Keys, KeysCome) end)},
              {tcp, erlang:spawn(fun ern_tcp:loop/0)},
              {clock, erlang:spawn(fun clock_loop/0)}],
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
        MainPid = spawn_awaited(fun() -> run_inits(Stdlib), Init(), Main() end, Site,
                                [{erlang:self(), {raw, {main_down, Run}}}]),
        await_main(MainPid, Run)
    after
        end_program(Run, Reaper, System),
        persistent_term:erase({?MODULE, reporter}),
        restore_encodings(Encodings)
    end.

%% The entry process's end. Report §8.6, §8.2: a deadlock, and a fault the
%% runtime finds in a system process's work, fault the entry process, whose
%% end then comes as any process's does, reported as every fault is (§11.2).
await_main(MainPid, Run) ->
    receive
        {{main_down, Run}, _, Raw} ->
            case {reason(Raw), Raw} of
                {'Returned', _} -> ok;
                {'Killed', _} -> killed;
                {{'Fault', Msg}, {ern, fault, _, Trace}} -> {fault, Msg, Trace};
                {{'Fault', Msg}, _} -> {fault, Msg};
                {Other, _} -> {fault, format("~p", [Other])}
            end;
        {deadlock, Run} ->
            exit(MainPid, {ern, fault, <<"deadlock">>}),
            await_main(MainPid, Run);
        {fault, Run, Text} ->
            exit(MainPid, {ern, fault, Text}),
            await_main(MainPid, Run);
        {signal, Run, Signal} ->
            {signal, Signal}
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
    [{Device, Encoding} || Device <- [standard_io, standard_error],
                           Encoding <- [encoding(Device)], Encoding =/= none,
                           ok =:= io:setopts(Device, [{encoding, latin1}])].

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
%% happened, when the next fault ends the process with its cause. Only a
%% fault restarts: a kill and the program's end are exit signals, which no
%% try catches, and F returning ends it as any process ends.
-spec restarting({'RestartLimit', integer(), integer()}, fun(() -> term())) -> fun(() -> term()).
restarting({'RestartLimit', Restarts, Within}, F) ->
    fun() -> restarts(F, max(Restarts, 0), max(Within, 0), []) end.

restarts(F, Restarts, Within, Times) ->
    try
        F()
    catch
        Class:Reason:Stack ->
            Fault = fault_reason(Class, Reason, Stack),
            Now = erlang:monotonic_time(millisecond),
            Recent = [T || T <- Times, Now - T < Within],
            case length(Recent) < Restarts of
                true ->
                    %% report §11.2: a fault after which the process
                    %% restarts is reported as one
                    Site = case ets_lookup(?PROCESSES, erlang:self()) of
                               [{_, S, alive, _, _}] -> S;
                               _ -> <<>>
                           end,
                    persistent_term:get({?MODULE, reaper}) ! {report, erlang:self(), Site, Fault},
                    restarted(element(3, Fault)),
                    restarts(F, Restarts, Within, [Now | Recent]);
                false ->
                    %% raised again as the fault it is, for run/1 to end the
                    %% process with, its stack beside it where it had one
                    throw(Fault)
            end
    end.

%% Report §6.6, §6.9: a restart ends every call waiting on the process, each
%% caller told the cause, which a callForever faults with.
restarted(Cause) ->
    lists:foreach(fun({_, _, Alias}) -> Alias ! {Alias, restarted, Cause} end,
                  ets:take(?CALLS, erlang:self())).

%% Report §8.6: every local process ends with ProgramEnd, the sinks' output
%% is flushed, the system processes and the reaper are stopped, and the
%% terminal goes back as the program found it (§8.2).
end_program(Run, Reaper, System) ->
    lists:foreach(fun({Pid, _, _, _}) -> exit(Pid, {ern, program_end}) end, live_rows()),
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

%% The installed modules, loaded, in the order their initializers run.
stdlib_modules() ->
    Files = lists:usort(lists:append([filelib:wildcard(filename:join(D, "ern@*.beam"))
                                      || D <- code:get_path()])),
    Mods = [list_to_atom(filename:basename(File, ".beam")) || File <- Files],
    lists:foreach(fun(Mod) -> code:ensure_loaded(Mod) end, Mods),
    ordered(Mods).

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
ordered(Mods) ->
    {Order, _} = lists:foldl(fun(Mod, Acc) -> visit(Mod, Mods, Acc) end, {[], #{}}, Mods),
    lists:reverse(Order).

visit(Mod, Mods, {Order, Seen}) ->
    case Seen of
        #{Mod := _} ->
            {Order, Seen};
        _ ->
            Deps = [D || D <- deps_of(Mod), lists:member(D, Mods)],
            {Order1, Seen1} = lists:foldl(fun(D, Acc) -> visit(D, Mods, Acc) end,
                                          {Order, Seen#{Mod => true}}, Deps),
            {[Mod | Order1], Seen1}
    end.

deps_of(Mod) ->
    case erlang:function_exported(Mod, '$deps', 0) of
        true -> Mod:'$deps'();
        false -> []
    end.

stop(Pid) ->
    Ref = erlang:monitor(process, Pid),
    exit(Pid, kill),
    receive {'DOWN', Ref, process, Pid, _} -> ok end.

%% What the reaper and the system processes may still send about this run
%% after it ended.
flush_run(Run) ->
    receive
        {{main_down, Run}, _, _} -> flush_run(Run);
        {deadlock, Run} -> flush_run(Run);
        {fault, Run, _} -> flush_run(Run)
    after 0 ->
        ok
    end.

format(Fmt, Args) ->
    unicode:characters_to_binary(io_lib:format(Fmt, Args)).
