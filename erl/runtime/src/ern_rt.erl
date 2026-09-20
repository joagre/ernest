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
         todo/1, timed/0, untimed/0, in_foreign/1, init_stdlib/0, own_terminal/1]).

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
    Addr ! Msg,
    ?UNIT.

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
    erlang:spawn(fun() ->
                     Ref = erlang:monitor(process, Target),
                     via_loop(F, Target, Ref)
                 end).

via_loop(F, Target, Ref) ->
    receive
        {'DOWN', Ref, process, Target, _} -> ok;
        Msg ->
            Target ! F(Msg),
            via_loop(F, Target, Ref)
    end.

%%
%% Report §6.6
%%

-spec call(address(), fun((reply()) -> term()), integer()) -> 'None' | {'Some', term()}.
call(Addr, Mk, Ms) ->
    Alias = erlang:alias([reply]),
    Addr ! Mk(Alias),
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
    Addr ! Mk(Alias),
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

%% A process the runtime started is watched by the reaper, which delivers
%% the recorded cause, at once if it is already dead. Any other pid (a via
%% proxy, a system process) gets a proxy with a monitor of its own.
-spec monitor(address(), fun((term()) -> term())) -> 'Unit'.
monitor(Addr, Wrap) ->
    Me = erlang:self(),
    case ets:member(?PROCESSES, Addr) of
        true ->
            persistent_term:get({?MODULE, reaper}) ! {await, Addr, Me, Wrap};
        false ->
            erlang:spawn(fun() ->
                             Ref = erlang:monitor(process, Addr),
                             receive
                                 {'DOWN', Ref, process, Addr, Reason} ->
                                     Me ! Wrap({'Down', <<"unknown">>, reason(Reason)})
                             end
                         end)
    end,
    ?UNIT.

-spec kill(address()) -> 'Unit'.
kill(Addr) ->
    exit(Addr, {ernest, killed}),
    ?UNIT.

reason(normal) -> 'Returned';
reason({ernest, killed}) -> 'Killed';
reason({ernest, program_end}) -> 'ProgramEnd';
reason({ernest, fault, Msg}) -> {'Fault', Msg};
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
                _ ->
                    reaper_loop(maps:update_with(Pid, fun(L) -> [{To, Wrap} | L] end,
                                                 [{To, Wrap}], Waiters))
            end;
        {'DOWN', _MRef, process, Pid, Reason} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, alive, _, _}] ->
                    ets:insert(?PROCESSES, {Pid, Site, Reason, 0, 0}),
                    lists:foreach(fun({To, Wrap}) -> To ! Wrap({'Down', Site, reason(Reason)}) end,
                                  maps:get(Pid, Waiters, []));
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

%% Report §8.6. Two snapshots of every live process's status and reduction
%% count, equal, with every status waiting, prove that nothing ran between
%% them and so no message is in flight; a timed receive, a foreign call in
%% progress, or a pending clock alarm is a source that can still deliver.
deadlocked() ->
    Rows = [{Pid, T, F} || {Pid, _, alive, T, F} <- ets:tab2list(?PROCESSES)],
    Rows =/= []
        andalso lists:all(fun({_, T, F}) -> T =:= 0 andalso F =:= 0 end, Rows)
        andalso clock_pending() =:= 0
        andalso begin
                    Pids = [Pid || {Pid, _, _} <- Rows],
                    First = snapshot(Pids),
                    lists:all(fun({_, S}) -> S =:= waiting end, [{P, St} || {P, St, _} <- First])
                        andalso snapshot(Pids) =:= First
                end.

snapshot(Pids) ->
    [case erlang:process_info(Pid, [status, reductions]) of
         [{status, S}, {reductions, R}] -> {Pid, S, R};
         undefined -> {Pid, dead, 0}
     end || Pid <- Pids].

clock_pending() ->
    Ref = make_ref(),
    persistent_term:get({?MODULE, clock}) ! {pending, erlang:self(), Ref},
    receive
        {Ref, N} -> N
    after 1000 ->
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
        error:badarith -> exit({ernest, fault, <<"division by zero">>});
        throw:{ernest, fault, Msg} -> exit({ernest, fault, Msg});
        Class:Reason -> exit({ernest, fault, format("~p:~p", [Class, Reason])})
    end.

-spec fault(binary()) -> no_return().
fault(Msg) ->
    throw({ernest, fault, Msg}).

%%
%% Report §8.2, §9.7: system references
%%

-spec sys(stdout | stderr | stdin | clock | fs | keys | tcp) -> address().
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
-spec own_terminal(lines | keys) -> ok | taken.
own_terminal(Kind) ->
    case persistent_term:get({?MODULE, terminal}, undefined) of
        undefined ->
            persistent_term:put({?MODULE, terminal}, Kind),
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
            answer(Reply, case Line() of
                              eof -> 'None';
                              Text -> {'Some', chomp(Text)}
                          end),
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
            erlang:send_after(Ms, erlang:self(), {fire, To}),
            clock_loop(Pending + 1);
        {'At', At, To} ->
            erlang:send_after(max(0, At - erlang:system_time(millisecond)), erlang:self(),
                              {fire, To}),
            clock_loop(Pending + 1);
        {fire, To} ->
            To ! ?UNIT,
            clock_loop(Pending - 1);
        {'Now', Reply} ->
            answer(Reply, erlang:system_time(millisecond)),
            clock_loop(Pending);
        {pending, From, Ref} ->
            From ! {Ref, Pending},
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
    persistent_term:erase({?MODULE, terminal}),
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
    Keys = erlang:spawn(fun ern_keys:loop/0),
    Tcp = erlang:spawn(fun ern_tcp:loop/0),
    Clock = erlang:spawn(fun() -> clock_loop(0) end),
    persistent_term:put({?MODULE, stdout}, Stdout),
    persistent_term:put({?MODULE, stderr}, Stderr),
    persistent_term:put({?MODULE, stdin}, Stdin),
    persistent_term:put({?MODULE, fs}, Fs),
    persistent_term:put({?MODULE, keys}, Keys),
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
    lists:foreach(fun({Pid, _, alive, _, _}) -> exit(Pid, {ernest, program_end});
                     (_) -> ok
                  end, ets:tab2list(?PROCESSES)),
    lists:foreach(fun(Sink) ->
                      FlushRef = make_ref(),
                      Sink ! {flush, erlang:self(), FlushRef},
                      receive {FlushRef, flushed} -> ok end
                  end, [Stdout, Stderr]),
    %% each ended before the table goes, which the reaper reads
    lists:foreach(fun stop/1, [Stdout, Stderr, Stdin, Fs, Keys, Tcp, Clock, Reaper]),
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
