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
%% reports the cause (report §6.9).
-module(ern_rt).

-export([send/2, spawn/3, self/0, via/2, call/3, call_forever/2, answer/2, monitor/2,
         kill/1, sys/1, run_main/2, run_main/3, fault/1, remote/1, parallel_remote/1,
         todo/1]).

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
    receive
        {Alias, V} -> {'Some', V}
    after Ms ->
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
            ets:insert(?PROCESSES, {Pid, Site, alive}),
            From ! {Ref, Pid},
            reaper_loop(Waiters);
        {await, Pid, To, Wrap} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, Reason}] when Reason =/= alive ->
                    To ! Wrap({'Down', Site, reason(Reason)}),
                    reaper_loop(Waiters);
                _ ->
                    reaper_loop(maps:update_with(Pid, fun(L) -> [{To, Wrap} | L] end,
                                                 [{To, Wrap}], Waiters))
            end;
        {'DOWN', _MRef, process, Pid, Reason} ->
            case ets:lookup(?PROCESSES, Pid) of
                [{_, Site, alive}] ->
                    ets:insert(?PROCESSES, {Pid, Site, Reason}),
                    lists:foreach(fun({To, Wrap}) -> To ! Wrap({'Down', Site, reason(Reason)}) end,
                                  maps:get(Pid, Waiters, []));
                _ ->
                    ok
            end,
            reaper_loop(maps:remove(Pid, Waiters))
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

-spec sys(stdout | clock) -> address().
sys(Name) ->
    persistent_term:get({?MODULE, Name}).

stdout_loop(Out) ->
    receive
        {flush, From, Ref} ->
            From ! {Ref, flushed},
            stdout_loop(Out);
        Bin when is_binary(Bin) ->
            Out(Bin),
            stdout_loop(Out)
    end.

%% ClockMsg, report §9.3: After(ms, to), At(at, to), Now(reply).
clock_loop() ->
    receive
        {'After', Ms, To} ->
            erlang:send_after(Ms, To, ?UNIT),
            clock_loop();
        {'At', At, To} ->
            erlang:send_after(max(0, At - erlang:system_time(millisecond)), To, ?UNIT),
            clock_loop();
        {'Now', Reply} ->
            answer(Reply, erlang:system_time(millisecond)),
            clock_loop()
    end.

%%
%% Report §8.1, §8.6: the launcher
%%

%% Runs Main as the entry process and returns ok, or {fault, Message} if it
%% faulted. Every local process is then ended with ProgramEnd and stdout
%% is flushed. Opts: #{stdout => fun((binary()) -> any())} for tests.
-spec run_main(fun(() -> term()), binary()) -> ok | {fault, binary()}.
run_main(Main, Site) ->
    run_main(Main, Site, #{}).

-spec run_main(fun(() -> term()), binary(), map()) -> ok | {fault, binary()}.
run_main(Main, Site, Opts) ->
    ets:new(?PROCESSES, [named_table, public, set]),
    Reaper = erlang:spawn(fun() -> reaper_loop(#{}) end),
    persistent_term:put({?MODULE, reaper}, Reaper),
    Out = maps:get(stdout, Opts, fun(Bin) -> io:put_chars(Bin) end),
    Stdout = erlang:spawn(fun() -> stdout_loop(Out) end),
    Clock = erlang:spawn(fun() -> clock_loop() end),
    persistent_term:put({?MODULE, stdout}, Stdout),
    persistent_term:put({?MODULE, clock}, Clock),
    MainPid = spawn('Local', Main, Site),
    Reaper ! {await, MainPid, erlang:self(), fun(Down) -> {main_down, Down} end},
    Result = receive
                 {main_down, {'Down', _, Reason}} -> Reason
             end,
    lists:foreach(fun({Pid, _, alive}) -> exit(Pid, {ernest, program_end});
                     (_) -> ok
                  end, ets:tab2list(?PROCESSES)),
    FlushRef = make_ref(),
    Stdout ! {flush, erlang:self(), FlushRef},
    receive {FlushRef, flushed} -> ok end,
    exit(Stdout, kill),
    exit(Clock, kill),
    exit(Reaper, kill),
    ets:delete(?PROCESSES),
    case Result of
        'Returned' -> ok;
        {'Fault', Msg} -> {fault, Msg};
        Other -> {fault, format("~p", [Other])}
    end.

format(Fmt, Args) ->
    unicode:characters_to_binary(io_lib:format(Fmt, Args)).
