%% The Ernest runtime, report sections 6, 7, 8, and 10, for one node. What
%% generated code calls, and the launcher.
%%
%% Values follow the ABI of report §8.4: Unit is 'Unit', a nullary constructor
%% is its quoted name, Some(v) is {'Some', V}, Down(function, reason) is
%% {'Down', Function, Reason} in canonical field order.
%%
%% Every Address is a pid. via/2 and monitor/2 run small proxy processes, so
%% send is `!` and a generated receive never meets a foreign message shape.
%% A Reply(a) is a process alias made with alias([reply]): it deactivates
%% after the first answer, and unalias after a timeout drops late ones
%% (report §6.6). Every process body runs under run/1, which turns an
%% exception into an exit reason the monitor proxy reports as a Fault. All
%% spawns go through the reaper process, which spawn_monitors each process
%% and records how it ended, so a monitor placed after the death still
%% reports the cause (report §6.9). The reaper also detects Deadlock
%% (report §8.6): every live process blocked in an untimed receive, no timed
%% receive or clock alarm pending, no process inside foreign code. A row of
%% the process table is {Pid, Site, State, Timers, Foreign}: Timers counts
%% the timed receives the process is in, Foreign its foreign calls.
-module(ern_rt).

-export([send/2, spawn/3, self/0, via/2, call/3, call_forever/2, answer/2, monitor/2,
         kill/1, sys/1, run_main/2, run_main/3, fault/1, remote/1, parallel_remote/1,
         todo/1, timed/0, untimed/0, in_foreign/1, init_stdlib/0, own_terminal/1,
         source_begin/0, source_end/0, process_of/1, proxy_for/2, proxy_forget/1,
         hold_terminal/1, terminal_holder/0, deaths/1, live/0]).

-compile({no_auto_import, [spawn/3, self/0, monitor/2]}).

-define(UNIT, 'Unit').
-define(PROCESSES, ern_processes).

-type address() :: pid().
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

%% The process an address names, through any number of adaptations.
-spec process_of(address()) -> pid().
process_of({via, _, Target}) -> process_of(Target);
process_of(Pid) -> Pid.

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
    Alias = erlang:alias([reply]),
    deliver(Addr, Mk(Alias)),
    timed(),
    receive
        {Alias, V} ->
            untimed(),
            {'Some', V}
    after Ms ->
        untimed(),
        erlang:unalias(Alias),
        'None'
    end.

-spec call_forever(address(), fun((reply()) -> term())) -> term().
call_forever(Addr, Mk) ->
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
reason({ern, code_replaced}) -> {'Fault', <<"its code was replaced">>};
reason({ern, fault, Msg}) -> {'Fault', Msg};
reason(noproc) -> {'Fault', <<"died before monitor">>};
reason(Other) -> {'Fault', format("~p", [Other])}.

%% The reaper: spawns on request with a monitor, records each process's
%% end in the table, and tells whoever awaits a process how it ended.
%% Waiters: #{Pid => [{To, Wrap}]}; Wrap(Down) is sent to To.
reaper_loop(Waiters) ->
    receive
        {spawn, From, Ref, Fun, Site} ->
            {Pid, _MRef} = erlang:spawn_monitor(fun() -> run(Fun) end),
            ets:insert(?PROCESSES, {Pid, Site, alive, 0, 0}),
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
%% the one the shell registers for deaths (§11.2) is counted here.
deadlocked() ->
    Rows = [{Pid, T, F} || {Pid, _, alive, T, F} <- ets:tab2list(?PROCESSES)],
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
                          end, [stdout, stderr, stdin, fs, terminal, tcp, clock, deaths]).

quiet(Pid) ->
    case erlang:process_info(Pid, [status, message_queue_len]) of
        [{status, waiting}, {message_queue_len, 0}] -> true;
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
-spec proxy_for(term(), fun(() -> pid())) -> pid().
proxy_for(Key, Start) ->
    case ets:lookup(?PROCESSES, {proxy, Key}) of
        [{_, Pid}] ->
            Pid;
        [] ->
            Pid = Start(),
            case ets:insert_new(?PROCESSES, {{proxy, Key}, Pid}) of
                true ->
                    Pid;
                false ->
                    exit(Pid, kill),
                    [{_, Winner}] = ets:lookup(?PROCESSES, {proxy, Key}),
                    Winner
            end
    end.

-spec proxy_forget(term()) -> ok.
proxy_forget(Key) ->
    %% the table is gone once the program has ended (report §8.6)
    try ets:delete(?PROCESSES, {proxy, Key}) catch _:_ -> true end,
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

%% Report §8.4, §8.6: a process inside foreign code is not waiting.
-spec in_foreign(fun(() -> term())) -> term().
in_foreign(Fun) ->
    count(5, 1),
    try Fun() after count(5, -1) end.

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

-spec parallel_remote([fun(() -> term())]) -> [{'Left', 'NoRemotePeer'}].
parallel_remote(Fs) ->
    [remote(F) || F <- Fs].

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

%% Report §8.2: which way the terminal is being read, keys or lines; a
%% program does one or the other, and the second to ask ends it.
-spec own_terminal(lines | keys) -> ok | taken.
own_terminal(Kind) ->
    case persistent_term:get({?MODULE, reading}, undefined) of
        undefined ->
            persistent_term:put({?MODULE, reading}, Kind),
            ok;
        Kind ->
            ok;
        Other ->
            {Launcher, Run} = persistent_term:get({?MODULE, launcher}),
            Launcher ! {terminal, Run, format("the terminal is already read as ~s", [Other])},
            taken
    end.

%% Report §8.2: stdin answers each ReadLine with the next line without its
%% line feed, None at end of input. Line is the runtime's reader, which a
%% test replaces.
stdin_loop(Line) ->
    receive
        {'ReadLine', Reply} ->
            own_terminal(lines),
            source_begin(),
            Read = case Line() of
                       eof -> 'None';
                       Text -> {'Some', chomp(Text)}
                   end,
            answer(Reply, Read),
            source_end(),
            stdin_loop(Line)
    end.

chomp(Text) ->
    Bin = unicode:characters_to_binary(Text),
    case binary:last(Bin) of
        $\n -> binary:part(Bin, 0, byte_size(Bin) - 1);
        _ -> Bin
    end.

%% ClockMsg, report §9.3: After(ms, to), At(at, to), Now(reply). Alarms are
%% delivered through the clock itself, so it knows how many are pending
%% (report §8.6).
clock_loop(Pending) ->
    receive
        {'After', Ms, To} ->
            source_begin(),
            erlang:send_after(Ms, erlang:self(), {fire, To}),
            clock_loop(Pending + 1);
        {'At', At, To} ->
            source_begin(),
            erlang:send_after(max(0, At - erlang:system_time(millisecond)), erlang:self(),
                              {fire, To}),
            clock_loop(Pending + 1);
        {fire, To} ->
            %% report §6.5: the alarm's target may be an address seen
            %% through a function, and it is delivered as any send is
            deliver(To, ?UNIT),
            source_end(),
            clock_loop(Pending - 1);
        {'Now', Reply} ->
            answer(Reply, erlang:system_time(millisecond)),
            clock_loop(Pending)
    end.

%%
%% Report §8.1, §8.6: the launcher
%%

%% Runs Main as the entry process and returns ok, or {fault, Message} if it
%% faulted. Every local process is then ended with ProgramEnd and stdout
%% is flushed. Opts: init => a function run in main's process before Main,
%% after the Sys.* references are bound, for the top-level lets (report
%% §8.5); stdout => fun((binary()) -> any()) for tests.
-spec run_main(fun(() -> term()), binary()) -> ok | {fault, binary()} | deadlock.
run_main(Main, Site) ->
    run_main(Main, Site, #{}).

-spec run_main(fun(() -> term()), binary(), map()) -> ok | {fault, binary()} | deadlock.
run_main(Main, Site, Opts) ->
    ets:new(?PROCESSES, [named_table, public, set]),
    %% report §8.6: the sources a system process holds, counted while held
    ets:insert(?PROCESSES, {sources, 0}),
    persistent_term:erase({?MODULE, reading}),
    persistent_term:erase({?MODULE, holder}),
    persistent_term:erase({?MODULE, deaths}),
    Run = make_ref(),
    persistent_term:put({?MODULE, launcher}, {erlang:self(), Run}),
    Reaper = erlang:spawn(fun() -> reaper_loop(#{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Out = maps:get(stdout, Opts, fun(Bin) -> io:put_chars(Bin) end),
    Err = maps:get(stderr, Opts, fun(Bin) -> io:put_chars(standard_error, Bin) end),
    Stdout = erlang:spawn(fun() -> stdout_loop(Out) end),
    Stderr = erlang:spawn(fun() -> stdout_loop(Err) end),
    Line = maps:get(stdin, Opts, fun() -> io:get_line("") end),
    Stdin = erlang:spawn(fun() -> stdin_loop(Line) end),
    Fs = erlang:spawn(fun ern_fs:loop/0),
    Tty = erlang:spawn(fun ern_tty:loop/0),
    Tcp = erlang:spawn(fun ern_tcp:loop/0),
    Clock = erlang:spawn(fun() -> clock_loop(0) end),
    persistent_term:put({?MODULE, stdout}, Stdout),
    persistent_term:put({?MODULE, stderr}, Stderr),
    persistent_term:put({?MODULE, stdin}, Stdin),
    persistent_term:put({?MODULE, fs}, Fs),
    persistent_term:put({?MODULE, terminal}, Tty),
    persistent_term:put({?MODULE, tcp}, Tcp),
    persistent_term:put({?MODULE, clock}, Clock),
    init_stdlib(),
    Init = maps:get(init, Opts, fun() -> ok end),
    MainPid = spawn('Local', fun() -> Init(), Main() end, Site),
    Reaper ! {await, MainPid, erlang:self(), fun(Down) -> {main_down, Run, Down} end},
    Result = receive
                 {main_down, Run, {'Down', _, Reason}} -> Reason;
                 {deadlock, Run} -> deadlock;
                 {terminal, Run, Text} -> {'Fault', Text}
             end,
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
                  end, [Stdout, Stderr]),
    %% each ended before the table goes, which the reaper reads
    lists:foreach(fun stop/1, [Stdout, Stderr, Stdin, Fs, Tty, Tcp, Clock, Reaper]),
    %% report §8.2: the terminal goes back as the program found it
    case persistent_term:get({?MODULE, reading}, undefined) of
        keys -> ern_tty:restore();
        _ -> ok
    end,
    ets:delete(?PROCESSES),
    flush_run(Run),
    case Result of
        'Returned' -> ok;
        {'Fault', Msg} -> {fault, Msg};
        deadlock -> deadlock;
        Other -> {fault, format("~p", [Other])}
    end.

%% Report §8.5: a standard library module's top-level lets, `Map.empty`
%% among them, are evaluated once at program start like any other module's;
%% the runner initializes the program's own modules, the runtime these,
%% which are build output on the code path rather than modules of the load
%% path.
-spec init_stdlib() -> ok.
init_stdlib() ->
    Files = lists:append([filelib:wildcard(filename:join(D, "ern@*.beam"))
                          || D <- code:get_path()]),
    lists:foreach(fun(File) ->
                      Mod = list_to_atom(filename:basename(File, ".beam")),
                      code:ensure_loaded(Mod),
                      erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'()
                  end, lists:usort(Files)),
    ok.

stop(Pid) ->
    Ref = erlang:monitor(process, Pid),
    exit(Pid, kill),
    receive {'DOWN', Ref, process, Pid, _} -> ok end.

%% What the reaper may still send about this run after it ended.
flush_run(Run) ->
    receive
        {main_down, Run, _} -> flush_run(Run);
        {deadlock, Run} -> flush_run(Run)
    after 0 ->
        ok
    end.

format(Fmt, Args) ->
    unicode:characters_to_binary(io_lib:format(Fmt, Args)).
