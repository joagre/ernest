%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the launcher.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(function, reason) is
%% {'Down', Function, Reason} in canonical field order.
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

-export([send/2, process_of/1, spawn/3, self/0, via/2, call/3, call_forever/2, answer/2,
         monitor/2, kill/1, deaths/1, live/0, proxy_for/3, proxy_forget/2, source_begin/0,
         source_end/0, timed/0, untimed/0, deadline/1, remaining/1, in_foreign/1,
         undefined_function/3, undefined_lambda/3, remote/1, todo/1, fault/1, sys/1,
         hold_terminal/1, terminal_holder/0, shell_holds/0, own_terminal/1, run_main/2,
         run_main/3, init_stdlib/0]).

-compile({no_auto_import, [spawn/3, self/0, monitor/2]}).

-define(UNIT, 'Unit').
-define(PROCESSES, ern_processes).
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
        Class:Reason -> exit(process_of(Target), fault_reason(Class, Reason))
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
    Ref = make_ref(),
    persistent_term:get({?MODULE, reaper}) ! {spawn, erlang:self(), Ref, Fun, Site},
    receive
        {Ref, Pid} -> Pid
    end;
spawn({'Peer', _Name}, _Fun, _Site) ->
    fault(<<"peer unreachable">>).

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
    Alias = erlang:alias([reply]),
    deliver(Addr, Mk(Alias)),
    timed(),
    await(Alias, deadline(Ms)).

await(Alias, Deadline) ->
    receive
        {Alias, V} ->
            untimed(),
            {'Some', V}
    after remaining(Deadline) ->
        case remaining(Deadline) of
            0 ->
                untimed(),
                erlang:unalias(Alias),
                %% an answer that came between the timeout and the unalias
                %% is late as well, and is not left in the caller's mailbox
                receive
                    {Alias, _} -> ok
                after 0 ->
                    ok
                end,
                'None';
            _ ->
                await(Alias, Deadline)
        end
    end.

-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Addr, Mk) ->
    line_guard(Addr),
    Alias = erlang:alias([reply]),
    deliver(Addr, Mk(Alias)),
    receive
        {Alias, V} -> V
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
    exit(process_of(Addr), {ern, killed}),
    ?UNIT.

reason(normal) -> 'Returned';
reason({ern, killed}) -> 'Killed';
reason({ern, program_end}) -> 'ProgramEnd';
%% report §7.3, §11.2: a process still in a version of a module the shell
%% has replaced twice
reason({ern, code_unloaded}) -> {'Fault', <<"its code was unloaded">>};
reason({ern, fault, Msg}) -> {'Fault', Msg};
reason(noproc) -> {'Fault', <<"died before monitor">>};
reason(Other) -> {'Fault', format("~p", [Other])}.

%% The reaper: spawns on request with a monitor, records each process's
%% end in the table, and tells whoever awaits a process how it ended.
%% Waiters: #{Pid => [{To, Wrap}]}; Wrap(Down) is sent to To.
reaper_loop(Waiters) ->
    receive
        {spawn, From, Ref, Fun, Site} ->
            %% the process starts once its row is in the table, since a
            %% timed receive it enters first counts itself there (§8.6)
            {Pid, _MRef} = erlang:spawn_monitor(fun() -> receive Ref -> run(Fun) end end),
            ets:insert(?PROCESSES, {Pid, Site, alive, 0, 0}),
            Pid ! Ref,
            From ! {Ref, Pid},
            reaper_loop(Waiters);
        {await, Pid, To, Wrap} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, Reason, _, _}] when Reason =/= alive ->
                    To ! Wrap({'Down', Site, reason(Reason)}),
                    reaper_loop(Waiters);
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
        {'DOWN', _MRef, process, Pid, Reason} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, alive, _, _}] ->
                    ets:insert(?PROCESSES, {Pid, Site, Reason, 0, 0}),
                    died(Pid, Site, Reason),
                    lists:foreach(fun({To, Wrap}) -> To ! Wrap({'Down', Site, reason(Reason)}) end,
                                  maps:get(Pid, Waiters, []));
                [] ->
                    %% report §6.9: the spawn site of a process the runtime
                    %% did not start is not known
                    lists:foreach(fun({To, Wrap}) ->
                                      To ! Wrap({'Down', <<"unknown">>, reason(Reason)})
                                  end, maps:get(Pid, Waiters, [])),
                    is_map_key(Pid, Waiters) andalso source_end();
                _ ->
                    ok
            end,
            reaper_loop(maps:remove(Pid, Waiters))
    after 100 ->
        case deadlocked() of
            true ->
                {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
                Launcher ! {deadlock, Run};
            false -> ok
        end,
        reaper_loop(Waiters)
    end.

%% Report §11.2: the shell reads how every process the runtime started
%% ended (§6.9) and which are alive, and no program does: §6.3 gives a
%% program no registry, and these two are the toolchain's own door. The
%% watcher is told of every death, and decides for itself which are news.
-spec deaths(pid()) -> ok.
deaths(Watcher) ->
    persistent_term:put({?MODULE, deaths}, Watcher),
    ok.

-spec live() -> [{address(), binary()}].
live() ->
    try [{Pid, Site} || {Pid, Site, alive, _, _} <- ets:tab2list(?PROCESSES)]
    catch _:_ -> []
    end.

died(Pid, Site, Reason) ->
    case persistent_term:get({?MODULE, deaths}, undefined) of
        undefined -> ok;
        Watcher -> Watcher ! {death, Pid, Site, reason(Reason)}, ok
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
%% it. §8.6 leaves a foreign process that can deliver to the runtime, and
%% the one the shell registers for deaths (§11.2) is counted here. Report
%% §11.2: nothing is a deadlock while a shell holds the terminal.
deadlocked() ->
    Rows = [{Pid, T, F} || {Pid, _, alive, T, F} <- ets:tab2list(?PROCESSES)],
    terminal_holder() =:= undefined
        andalso Rows =/= []
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
                          end, [stdout, stderr, stdin, fs, terminal, tcp, clock, deaths]).

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

%% Report §8.6: what a system process holds that can still deliver, a
%% timer, a subscription, or a read in progress. Each is counted while it
%% is held, since a process that is inside a read cannot answer a question.
-spec source_begin() -> ok.
source_begin() ->
    try ets:update_counter(?PROCESSES, sources, {2, 1}) catch _:_ -> 0 end,
    ok.

-spec source_end() -> ok.
source_end() ->
    try ets:update_counter(?PROCESSES, sources, {2, -1}) catch _:_ -> 0 end,
    ok.

sources() ->
    try ets:lookup(?PROCESSES, sources) of
        [{sources, N}] -> N;
        _ -> 1
    catch _:_ ->
        1
    end.

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
%% Report §7.4: todo faults if reached
%%

-spec todo(binary()) -> no_return().
todo(Msg) ->
    fault(<<"todo: ", Msg/binary>>).

%%
%% Report §7: a process body; an exception is a fault
%%

run(Fun) ->
    erlang:process_flag(error_handler, ?MODULE),
    try
        Fun()
    catch
        Class:Reason -> exit(fault_reason(Class, Reason))
    end.

%% Report §7.4: what a host error is as an Ernest fault.
fault_reason(error, badarith) -> {ern, fault, <<"division by zero">>};
fault_reason(throw, {ern, fault, Msg}) -> {ern, fault, Msg};
fault_reason(Class, Reason) -> {ern, fault, format("~p:~p", [Class, Reason])}.

-spec fault(binary()) -> no_return().
fault(Msg) ->
    throw({ern, fault, Msg}).

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

%% Report §8.2: stdin answers each ReadLine with the next line without its
%% line feed, None at end of input. Line is the runtime's reader, which a
%% test replaces. Report §7.3: a read that fails is a failure of the
%% runtime, and ends the program with a fault that names it.
stdin_loop(Line) ->
    receive
        {'ReadLine', Reply} ->
            own_terminal(lines),
            source_begin(),
            case Line() of
                eof ->
                    answer(Reply, 'None');
                {error, Reason} ->
                    end_with_fault(format("the standard input could not be read: ~p", [Reason]));
                Text ->
                    answer(Reply, {'Some', chomp(unicode:characters_to_binary(Text))})
            end,
            source_end(),
            stdin_loop(Line)
    end.

chomp(<<>>) ->
    <<>>;
chomp(Bin) ->
    case binary:last(Bin) of
        $\n -> binary:part(Bin, 0, byte_size(Bin) - 1);
        _ -> Bin
    end.

%% ClockMsg, report §9.3: After(ms, to), At(at, to), Now(reply). Alarms are
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
                    %% time it fired
                    deliver(To, erlang:system_time(millisecond)),
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

%% Runs Main as the entry process and returns ok, or {fault, Message} if it
%% faulted, a deadlock among the faults (report §8.6: the entry process
%% faults with `Fault("deadlock")`). Every local process is then ended with
%% ProgramEnd and stdout is flushed, however the run ended. Opts: init => a
%% function run in main's process before Main, after the Sys.* references
%% are bound and the standard library's lets evaluated, for the program's
%% own top-level lets (report §8.5); stdout, stderr =>
%% fun((binary()) -> any()), stdin => fun(() -> eof | {error, term()} |
%% string()) and keys => the same for the terminal's characters, for tests.
-spec run_main(fun(() -> term()), binary()) -> ok | {fault, binary()}.
run_main(Main, Site) ->
    run_main(Main, Site, #{}).

-spec run_main(fun(() -> term()), binary(), map()) -> ok | {fault, binary()}.
run_main(Main, Site, Opts) ->
    ets:new(?PROCESSES, [named_table, public, set]),
    %% report §8.6: the sources a system process holds, counted while held
    ets:insert(?PROCESSES, {sources, 0}),
    persistent_term:erase({?MODULE, holder}),
    persistent_term:erase({?MODULE, deaths}),
    Run = make_ref(),
    persistent_term:put({?MODULE, launcher}, {erlang:self(), Run}),
    Reaper = erlang:spawn(fun() -> reaper_loop(#{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Out = maps:get(stdout, Opts, fun(Bin) -> io:put_chars(Bin) end),
    Err = maps:get(stderr, Opts, fun(Bin) -> io:put_chars(standard_error, Bin) end),
    Line = maps:get(stdin, Opts, fun() -> io:get_line("") end),
    Keys = maps:get(keys, Opts, fun ern_tty:read_char/0),
    System = [{stdout, erlang:spawn(fun() -> stdout_loop(Out) end)},
              {stderr, erlang:spawn(fun() -> stdout_loop(Err) end)},
              {stdin, erlang:spawn(fun() -> stdin_loop(Line) end)},
              {fs, erlang:spawn(fun ern_fs:loop/0)},
              {terminal, erlang:spawn(fun() -> ern_tty:loop(Keys) end)},
              {tcp, erlang:spawn(fun ern_tcp:loop/0)},
              {clock, erlang:spawn(fun clock_loop/0)}],
    lists:foreach(fun({Name, Pid}) -> persistent_term:put({?MODULE, Name}, Pid) end, System),
    try
        %% report §8.5: the initializers, the standard library's first, run
        %% in main's process, so one that faults is the program's fault; its
        %% modules are loaded here, where their order is read from them
        Stdlib = stdlib_modules(),
        Init = maps:get(init, Opts, fun() -> ok end),
        MainPid = spawn('Local', fun() -> run_inits(Stdlib), Init(), Main() end, Site),
        Reaper ! {await, MainPid, erlang:self(), fun(Down) -> {main_down, Run, Down} end},
        receive
            {main_down, Run, {'Down', _, 'Returned'}} -> ok;
            {main_down, Run, {'Down', _, {'Fault', Msg}}} -> {fault, Msg};
            {main_down, Run, {'Down', _, Other}} -> {fault, format("~p", [Other])};
            {deadlock, Run} ->
                exit(MainPid, {ern, fault, <<"deadlock">>}),
                {fault, <<"deadlock">>};
            {fault, Run, Text} -> {fault, Text}
        end
    after
        end_program(Run, Reaper, System)
    end.

%% Report §8.6: every local process ends with ProgramEnd, the sinks' output
%% is flushed, the system processes and the reaper are stopped, and the
%% terminal goes back as the program found it (§8.2).
end_program(Run, Reaper, System) ->
    lists:foreach(fun({Pid, _, alive, _, _}) -> exit(Pid, {ern, program_end});
                     (_) -> ok
                  end, ets:tab2list(?PROCESSES)),
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
        {main_down, Run, _} -> flush_run(Run);
        {deadlock, Run} -> flush_run(Run);
        {fault, Run, _} -> flush_run(Run)
    after 0 ->
        ok
    end.

format(Fmt, Args) ->
    unicode:characters_to_binary(io_lib:format(Fmt, Args)).
