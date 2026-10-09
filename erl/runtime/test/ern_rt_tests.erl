%% Report §6, §7, §8: the runtime, ern_rt, as the runner runs a program's
%% main: processes, calls and replies, monitors, the system processes, the
%% boundary's proxies, and the end of a program.
-module(ern_rt_tests).

-export([queued_input/2]).

-include_lib("eunit/include/eunit.hrl").

%% report §8.2: the terminal is read as lines or as keys; a claim the same
%% way stands, and one the other way is refused with the cause
own_terminal_test() ->
    ets:new(ern_launch, [named_table, public, set]),
    Owned = [ern_rt:own_terminal(keys), ern_rt:own_terminal(keys), ern_rt:own_terminal(lines)],
    ets:delete(ern_launch),
    ?assertEqual([ok, ok, {taken, <<"the terminal is already read as keys">>}], Owned).

%% report §8.2: readers of the terminal asking at once, some for lines and
%% some for keys, are one reading and refusals. A regression test: the
%% check and the claim were two steps, and both sides could pass the
%% check. The claims are made here against the table a run would have. A
%% race can be won by luck, so a pass confirms the order rather than
%% proving it
own_terminal_race_test() ->
    ets:new(ern_launch, [named_table, public, set]),
    Self = self(),
    Kinds = [case Number rem 2 of 0 -> keys; 1 -> lines end || Number <- lists:seq(1, 64)],
    Askers = [spawn(fun() ->
                        receive go -> ok end,
                        Self ! {owned, Kind, ern_rt:own_terminal(Kind)}
                    end) || Kind <- Kinds],
    [Asker ! go || Asker <- Askers],
    Owned = [receive {owned, Kind, Result} -> {Kind, Result} after 1000 -> timeout end
             || _ <- Kinds],
    ets:delete(ern_launch),
    [Winner] = lists:usort([Kind || {Kind, ok} <- Owned]),
    Cause = <<"the terminal is already read as ", (atom_to_binary(Winner))/binary>>,
    ?assertEqual([], [Result || {_, Result} <- Owned, Result =/= ok, Result =/= {taken, Cause}]).

%% report §8.2, §7.3: a read of the standard input that fails is a failure
%% of the runtime, which ends the program with a fault that names it, and an
%% empty line is the empty string. A regression test: each crashed the
%% process behind Io's stdin, and the caller waited for ever
stdin_failure_test() ->
    Ask = fun() ->
              Stdin = ern_rt:system_process(stdin),
              ern_rt:call_forever(Stdin, fun(Reply) -> {'ReadLine', Reply} end)
          end,
    Self = self(),
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual({fault, <<"the standard input could not be read: eio">>},
                 ern_rt:run_main(Ask, <<"main">>, Quiet#{stdin => fun() -> {error, eio} end})),
    ?assertEqual(ok, ern_rt:run_main(fun() -> Self ! {line, Ask()} end, <<"main">>,
                                     Quiet#{stdin => fun() -> "\n" end})),
    ?assertEqual({'Some', <<>>}, wait(line)).

%% report §8.2, §7.4: lines and bytes are one stream, each request taking
%% up where the one before it stopped; a line loses its line feed and one
%% carriage return before it, and a last line needs none; a line that is
%% not UTF-8 faults the process that asked, and the next line is read
stdin_stream_test() ->
    Next = queued_input([<<"ab\r\ncd">>, <<"\nrest\n">>, <<"ok\n", 255, "\nnext">>],
                        fun() -> eof end),
    Line = fun() ->
               ern_rt:call_forever(ern_rt:system_process(stdin), fun(Reply) ->
                                                                     {'ReadLine', Reply}
                                                                 end)
           end,
    Bytes = fun() ->
                ern_rt:call_forever(ern_rt:system_process(stdin), fun(Reply) -> {'Read', Reply} end)
            end,
    Self = self(),
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {got, [Line(), Bytes(), Line(), Line(), Line()]},
                           Asker = ern_rt:spawn(fun() -> Line() end, <<"asker">>),
                           ern_rt:monitor(Asker, fun(Down) -> {down, Down} end),
                           receive {down, Down} -> Self ! {down, Down} end,
                           Self ! {after_fault, [Line(), Line(), Bytes()]}
                       end, <<"main">>, #{stdout => fun(_) -> ok end, stdin => Next})),
    ?assertEqual([{'Some', <<"ab">>}, {'Some', <<"cd">>}, {'Some', <<>>}, {'Some', <<"rest">>},
                  {'Some', <<"ok">>}], wait(got)),
    ?assertMatch({'Down', _, {'Fault', <<"the standard input is not UTF-8">>}, _}, wait(down)),
    ?assertEqual([{'Some', <<"next">>}, 'None', 'None'], wait(after_fault)).

%% report §8.2: one carriage return before a line feed is dropped, and a
%% last line without a line feed keeps its own. A regression test: the last
%% line lost it too
stdin_last_line_test() ->
    Next = queued_input([<<"a\r\nb\r">>], fun() -> eof end),
    Line = fun() ->
               ern_rt:call_forever(ern_rt:system_process(stdin), fun(Reply) ->
                                                                     {'ReadLine', Reply}
                                                                 end)
           end,
    Self = self(),
    ?assertEqual(ok, ern_rt:run_main(fun() -> Self ! {got, [Line(), Line(), Line()]} end,
                                     <<"main">>, #{stdout => fun(_) -> ok end, stdin => Next})),
    ?assertEqual([{'Some', <<"a">>}, {'Some', <<"b\r">>}, 'None'], wait(got)).

%% report Appendix E.21: a snapshot says what a live process is doing, a
%% wait in a receive told from a wait for a call's answer, and nothing of
%% one that has ended; the live processes are those the runtime started
process_info_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Quiet = ern_rt:spawn(fun() -> receive stop -> ok end end, <<"M.quiet:1">>),
               Server = ern_rt:spawn(fun() -> receive never -> ok end end, <<"M.s:2">>),
               Calling = fun() -> ern_rt:call_forever(Server, fun(Reply) -> Reply end) end,
               Caller = ern_rt:spawn(Calling, <<"M.caller:3">>),
               ern_rt:send(Quiet, first),
               %% the snapshot reads each blocked in its wait, which this
               %% one counts as timed so that it is no deadlock (§8.6)
               ern_rt:timed(),
               ok = ern_waits:waiting(ern_rt:process_of(Quiet)),
               ok = ern_waits:waiting(ern_rt:process_of(Caller)),
               ern_rt:untimed(),
               Self ! {infos,
                       [ern_rt:info(ern_rt:process_of(Address)) || Address <- [Quiet, Caller]]},
               Self ! {live, lists:sort(ern_rt:processes())
                                 =:= lists:sort([self(), Quiet, Server, Caller])},
               QuietRef = erlang:monitor(process, ern_rt:process_of(Quiet)),
               ern_rt:kill(Quiet),
               ern_rt:timed(),
               receive {'DOWN', QuietRef, process, _, _} -> ern_rt:untimed() end,
               Self ! {gone, ern_rt:info(Quiet)},
               ern_rt:kill(Caller),
               ern_rt:kill(Server)
           end, <<"M.main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual([{'Some', {'Info', <<"M.quiet:1">>, 1, 'Receiving'}},
                  {'Some', {'Info', <<"M.caller:3">>, 0, 'Calling'}}], wait(infos)),
    ?assertEqual(true, wait(live)),
    ?assertEqual('None', wait(gone)).

%% report §8.6: a program's end ends every process the runtime started,
%% one spawned as the program ends among them. A regression test: a spawn
%% the reaper handled after the end had read its rows lived on, 176 of them
%% over five runs
end_takes_late_spawns_test_() ->
    {timeout, 60, fun end_takes_late_spawns/0}.

end_takes_late_spawns() ->
    Quiet = #{stdout => fun(_) -> ok end},
    Spawner = fun Spawn() ->
                  _ = ern_rt:spawn(fun() -> receive never -> ok end end, <<"w">>),
                  Spawn()
              end,
    %% main returns once every spawner has begun, so that they spawn on as
    %% the program ends
    RunProgram = fun() ->
                     ok = ern_rt:run_main(fun() ->
                                              Main = erlang:self(),
                                              [ern_rt:spawn(fun() ->
                                                                Main ! spawning,
                                                                Spawner()
                                                            end, <<"s">>)
                                               || _ <- lists:seq(1, 8)],
                                              [receive spawning -> ok end
                                               || _ <- lists:seq(1, 8)]
                                          end, <<"main">>, Quiet)
                 end,
    %% the first run starts what the host starts once
    RunProgram(),
    %% the next runs' processes are told apart by a group leader of their
    %% own, which every process the runtime starts inherits, and each must
    %% end; the leader passes on what it is asked to the test's own
    Previous = group_leader(),
    Leader = spawn(fun Pass() -> receive Request -> Previous ! Request, Pass() end end),
    group_leader(Leader, self()),
    [RunProgram() || _ <- lists:seq(1, 5)],
    group_leader(Previous, self()),
    Started = [Pid || Pid <- erlang:processes(), Pid =/= Leader,
                      erlang:process_info(Pid, group_leader) =:= {group_leader, Leader}],
    Alive = lists:filter(fun(Pid) ->
                             MonitorRef = erlang:monitor(process, Pid),
                             receive {'DOWN', MonitorRef, process, Pid, _} -> false
                             after 5000 -> true
                             end
                         end, Started),
    exit(Leader, kill),
    ?assertEqual([], Alive).

%% report Appendix E.21, §11.2: every fault reaches each subscriber as a
%% FaultReport, a restart among them, and the runtime's reporter as it
%% happens; a second subscription replaces the first; a kill is no fault
fault_reports_test() ->
    Self = self(),
    Reporter = fun(Report) -> Self ! {reported, Report} end,
    ok = ern_rt:run_main(
           fun() ->
               ern_rt:faults(ern_rt:via(ern_rt:self(), fun(Report) -> {first, Report} end)),
               ern_rt:faults(ern_rt:via(ern_rt:self(), fun(Report) -> {report, Report} end)),
               Limit = {'RestartLimit', 1, 60000},
               Twice = ern_rt:restarting(Limit, fun() -> 1 div zero() end),
               %% monitored from its start: the reaper starts a fault's
               %% deliveries before the Down of the process that ended
               _ = ern_rt:spawn_monitored(Twice, fun(Down) -> {twice, Down} end,
                                          <<"M.twice:4">>),
               Killed = ern_rt:spawn(fun() -> receive never -> ok end end, <<"M.k:5">>),
               ern_rt:kill(Killed),
               Reports = [receive {report, First} -> First end,
                          receive {report, Second} -> Second end],
               Self ! {reports, lists:sort([{Site, Cause, Restarted}
                                            || {'FaultReport', _, Site, Cause, Restarted, <<>>}
                                                   <- Reports])},
               %% every report started is delivered, so one to the first
               %% subscription would be in the mailbox
               ern_rt:timed(),
               receive {twice, _} -> ok end,
               ern_waits:delivered(erlang:self()),
               ern_rt:untimed(),
               Self ! {first, receive {first, _} -> true after 0 -> false end}
           end, <<"M.main">>, #{stdout => fun(_) -> ok end, faults => Reporter}),
    ?assertEqual([{<<"M.twice:4">>, <<"division by zero">>, false},
                  {<<"M.twice:4">>, <<"division by zero">>, true}], wait(reports)),
    ?assertEqual(false, wait(first)),
    Reported = [Report || {reported, Report} <- flush()],
    ?assertEqual(2, length(Reported)).

flush() ->
    receive Message -> [Message | flush()] after 0 -> [] end.

%% report §6.6, §6.9: a call ends with the row, the monitor and the alias
%% it made, and the timed wait it counted, however it ends: its message's
%% function faulting, or its callee answering with a fault, as a system
%% process does. A regression test: in a process restarted in place they
%% were left behind
call_leaves_nothing_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = ern_rt:self(),
               Refusing = fun() ->
                              receive {ask, Reply} -> Reply ! {Reply, fault, <<"no">>} end,
                              receive never -> ok end
                          end,
               Faulting = ern_rt:spawn(Refusing, <<"M.faulting:1">>),
               Worker = fun() ->
                            case get(runs) of
                                undefined ->
                                    put(runs, 1),
                                    ern_rt:call(Faulting, fun(_) -> 1 div zero() end, 1000);
                                1 ->
                                    put(runs, 2),
                                    ern_rt:call(Faulting, fun(Reply) -> {ask, Reply} end, 1000);
                                2 ->
                                    [{_, _, Timers, _, _}] = ets:lookup(ern_processes, self()),
                                    {monitors, Monitors} = process_info(self(), monitors),
                                    Self ! {left, {ets:lookup(ern_calls, self()),
                                                   Monitors, Timers}},
                                    ern_rt:send(EntryProcess, done)
                            end
                        end,
               _ = ern_rt:spawn(ern_rt:restarting({'RestartLimit', 2, 60000}, Worker),
                                <<"M.worker:2">>),
               receive done -> ok end
           end, <<"M.main">>, #{stdout => fun(_) -> ok end, faults => fun(_) -> ok end}),
    ?assertEqual({[], [], 0}, wait(left)).

%% report §8.6: a system process that has died can deliver nothing, so it
%% does not keep a deadlock from being found. A regression test: the
%% detector read a dead one as busy, and the program waited for ever
dead_system_process_test() ->
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() ->
                                     exit(ern_rt:system_process(clock), kill),
                                     receive never -> ok end
                                 end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §8.6: an idle program that waits on something pending is answered
%% by the deadlock check from the counts of pending work, not by reading
%% every process. Written after the code, to hold its cost: the reaper's
%% work at each look, between two looks it is traced making, is held below
%% what reading every process once costs here, which the order that read
%% every process twice before anything cheaper exceeds.
idle_check_is_cheap_test() ->
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Pids = [ern_rt:process_of(
                                     ern_rt:spawn(fun() -> receive never -> ok end end, <<"w">>))
                                   || _ <- lists:seq(1, 2000)],
                           {reductions, Unread} = erlang:process_info(erlang:self(), reductions),
                           _ = [erlang:process_info(Pid, [status, reductions]) || Pid <- Pids],
                           {reductions, Read} = erlang:process_info(erlang:self(), reductions),
                           ern_rt:source_begin(),
                           Reaper = persistent_term:get({ern_rt, reaper}),
                           ern_rt:in_foreign(fun() -> ern_waits:looked(1) end),
                           {reductions, Before} = erlang:process_info(Reaper, reductions),
                           ern_rt:in_foreign(fun() -> ern_waits:looked(2) end),
                           {reductions, After} = erlang:process_info(Reaper, reductions),
                           ern_rt:source_end(),
                           ?assert((After - Before) div 2 < Read - Unread)
                       end, <<"main">>, Quiet)).

%% report §8.5, §8.6: an initializer of the standard library that faults
%% ends the program with that fault, and the program is ended as one that
%% ran, so the next one starts. A regression test: such an initializer
%% raised out of run_main, and left the process table and the system
%% processes behind, so the next run failed to make its table
failed_start_test() ->
    %% the standard library is what a `stdlib` directory on the path holds
    Dir = filename:join([filename:basedir(user_cache, "ern_rt_tests"), "failed_start", "stdlib"]),
    ok = filelib:ensure_path(Dir),
    ErlangModule = 'ern@zz_failed_start',
    Forms = [{attribute, 1, module, ErlangModule}, {attribute, 1, export, [{'$init', 0}]},
             {function, 1, '$init', 0,
              [{clause, 1, [], [], [{call, 1, {atom, 1, error}, [{atom, 1, boom}]}]}]}],
    {ok, ErlangModule, Beam} = compile:forms(Forms),
    ok = file:write_file(filename:join(Dir, atom_to_list(ErlangModule) ++ ".beam"), Beam),
    true = code:add_patha(Dir),
    Quiet = #{stdout => fun(_) -> ok end},
    try
        %% the fault of a failure in the runtime carries the host's stack
        ?assertMatch({fault, _, _}, ern_rt:run_main(fun() -> ok end, <<"main">>, Quiet))
    after
        code:del_path(Dir),
        code:purge(ErlangModule),
        code:delete(ErlangModule),
        file:delete(filename:join(Dir, atom_to_list(ErlangModule) ++ ".beam"))
    end,
    ?assertEqual(ok, ern_rt:run_main(fun() -> ok end, <<"main">>, Quiet)).

%% Compile a hand-written target module from forms, as the compiler will
%% compile its own output, and run its main as the runner does, collecting
%% what reaches stdout.
run_target(File) ->
    Path = "../../../test/target/" ++ File,
    {ok, Forms} = epp:parse_file(Path, []),
    {ok, ErlangModule, Beam} = compile:forms(Forms, [return_errors]),
    {module, ErlangModule} = code:load_binary(ErlangModule, Path, Beam),
    Self = self(),
    Result = ern_rt:run_main(fun() -> ErlangModule:main() end, <<"main">>,
                             #{stdout => fun(Bytes) -> Self ! {out, Bytes} end}),
    {Result, collect([])}.

collect(Acc) ->
    receive
        {out, Bytes} -> collect([Bytes | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

%% report §8.1, §8.6, Appendix B
hello_target_test() ->
    ?assertEqual({ok, <<"hello, world\n">>}, run_target("hello.erl")).

%% report §6.2, §6.3, §6.6, Appendix B
counter_target_test() ->
    ?assertEqual({ok, <<"count is 8\n">>}, run_target("counter.erl")).

%% report §6.6: an unanswered call times out, a late answer is dropped
call_timeout_test() ->
    Self = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Silent = ern_rt:spawn(fun() -> receive _ -> ok end end, <<"s">>),
                   Self ! {result, ern_rt:call(Silent, fun(Reply) -> {ask, Reply} end, 20)}
               end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(ok, Result),
    receive {result, Answer} -> ?assertEqual('None', Answer) after 1000 -> ?assert(false) end.

%% report §6.6: the clock of a call starts at the call, so a request whose
%% delivery takes longer than the call's time is answered None, though the
%% callee answers soon after it. A regression test: the deadline was taken
%% after the delivery, and the call waited its whole time again
call_clock_starts_at_the_call_test() ->
    Self = self(),
    Time = 100,
    ok = ern_rt:run_main(
           fun() ->
               Caller = erlang:self(),
               %% the callee answers once the caller waits, or has gone on
               Callee = ern_rt:spawn(fun() ->
                                         receive
                                             {ask, Reply} ->
                                                 _ = ern_waits:waiting(Caller),
                                                 ern_rt:answer(Reply, done)
                                         end
                                     end, <<"callee">>),
               %% the adapting function runs in the caller, within the call,
               %% and takes the call's whole time, the deadline the call states
               Slow = ern_rt:via(Callee, fun(Message) -> timed_wait(Time), Message end),
               Self ! {result, ern_rt:call(Slow, fun(Reply) -> {ask, Reply} end, Time)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    receive {result, Answer} -> ?assertEqual('None', Answer) after 2000 -> ?assert(false) end.

%% report §6.6: the time of a call bounds the wait for the answer and
%% nothing before it: a request whose making outlasts the time is made in
%% the caller, uninterrupted, and sent all the same, and the wait that
%% begins after the time has passed ends at once. Written after the code,
%% a regression test of what §6.6 came to state
call_time_bounds_the_wait_alone_test() ->
    Self = self(),
    Time = 500,
    ok = ern_rt:run_main(
           fun() ->
               Callee = ern_rt:spawn(fun() ->
                                         receive {ask, _Reply} -> Self ! request_arrived end,
                                         receive after infinity -> ok end
                                     end, <<"callee">>),
               Caller = self(),
               %% the making takes the call's whole time, from within the
               %% call, whose clock has started
               Answer = ern_rt:call(Callee, fun(Reply) ->
                                                timed_wait(Time),
                                                Self ! {made, self() =:= Caller,
                                                        erlang:monotonic_time(millisecond)},
                                                {ask, Reply}
                                            end, Time),
               Self ! {result, Answer, erlang:monotonic_time(millisecond)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Made = receive
               {made, InCaller, At} -> ?assert(InCaller), At
           after 5000 -> ?assert(false)
           end,
    receive request_arrived -> ok after 5000 -> ?assert(false) end,
    receive
        {result, Answer, Returned} ->
            ?assertEqual('None', Answer),
            %% no second wait of the call's time after the making
            ?assert(Returned - Made < Time)
    after 5000 -> ?assert(false)
    end.

%% report §8.6: a deadlock is found soon where nothing could deliver from
%% the start, and within about a second of the end of the last thing that
%% could, a timed wait here: while something can deliver, the reaper looks
%% once a second, since a program at rest pays for each look. A regression
%% test, written after the code; it does not measure what the program at
%% rest pays, which the log's *The Reaper's Look at Rest* does
deadlock_after_a_wait_test_() ->
    {timeout, 30, fun deadlock_after_a_wait/0}.

deadlock_after_a_wait() ->
    Quiet = #{stdout => fun(_) -> ok end},
    Elapsed = fun(Entry) ->
                  Start = erlang:monotonic_time(millisecond),
                  ?assertEqual({fault, <<"deadlock">>}, ern_rt:run_main(Entry, <<"main">>, Quiet)),
                  erlang:monotonic_time(millisecond) - Start
              end,
    AtOnce = Elapsed(fun() -> receive never -> ok end end),
    ?assert(AtOnce < 600),
    Waited = Elapsed(fun() ->
                         ern_rt:timed(),
                         receive never -> ok after 300 -> ok end,
                         ern_rt:untimed(),
                         receive never -> ok end
                     end),
    ?assert(Waited >= 300),
    ?assert(Waited < 2500).

%% report §8.6: every live process blocked in an untimed receive, with no
%% timed receive, clock alarm, or foreign call pending, is a deadlock, the
%% entry process's fault `deadlock` (§7.4); each
%% of those is a source that can still deliver, so the detector, looking
%% while one is pending, finds no deadlock
deadlock_test() ->
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() -> receive never -> ok end end, <<"main">>, Quiet)),
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() ->
                                     _ = ern_rt:spawn(fun() -> receive x -> ok end end,
                                                      <<"s">>),
                                     receive y -> ok end
                                 end, <<"main">>, Quiet)),
    %% each pending while the detector looks, the program waiting for the
    %% look in a receive the detector does not count
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         ern_rt:timed(),
                                         ern_waits:looked(1),
                                         ern_rt:untimed()
                                     end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         Clock = ern_rt:system_process(clock),
                                         alarm(Clock, 10000000000000, ern_rt:self()),
                                         ern_waits:looked(1)
                                     end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         ern_rt:in_foreign(fun() -> ern_waits:looked(1) end)
                                     end, <<"main">>, Quiet)).

%% report §8.6: a process waiting for the host to load a module is not
%% waiting in a receive, so it is no deadlock. A regression test: the
%% detector read a process waiting on the code server as blocked, and a
%% program whose main loaded a module of the runtime at its first call, as
%% Io.debug loads ern_show after a timed call, ended with a false deadlock
%% whenever the detector looked during the load. Here the code server is
%% held until the detector has looked twice, so the test failed every time
%% before the fix. It covers a load made by a call, the only
%% way an Ernest process loads, and not code:ensure_loaded called directly
loading_is_not_deadlock_test() ->
    Dir = filename:join(filename:basedir(user_cache, "ern_rt_tests"), "loading"),
    ok = filelib:ensure_path(Dir),
    ErlangModule = ern_zz_loading,
    Forms = [{attribute, 1, module, ErlangModule}, {attribute, 1, export, [{f, 0}]},
             {function, 1, f, 0, [{clause, 1, [], [], [{atom, 1, loaded}]}]}],
    {ok, ErlangModule, Binary} = compile:forms(Forms),
    BeamFile = filename:join(Dir, atom_to_list(ErlangModule) ++ ".beam"),
    ok = file:write_file(BeamFile, Binary),
    true = code:add_patha(Dir),
    CodeServer = whereis(code_server),
    Holder = spawn(fun() ->
                       receive {hold, From} -> ok end,
                       erlang:suspend_process(CodeServer),
                       From ! held,
                       ern_waits:looked(2),
                       erlang:resume_process(CodeServer)
                   end),
    Self = self(),
    EntryPoint = fun() ->
                     %% counted as a timed wait while the holder takes the server
                     ern_rt:timed(),
                     Holder ! {hold, erlang:self()},
                     receive held -> ern_rt:untimed() end,
                     Self ! {loaded, ErlangModule:f()}
                 end,
    try
        ?assertEqual(ok, ern_rt:run_main(EntryPoint, <<"main">>, #{stdout => fun(_) -> ok end})),
        ?assertEqual(loaded, wait(loaded))
    after
        code:del_path(Dir),
        code:purge(ErlangModule),
        code:delete(ErlangModule),
        file:delete(BeamFile)
    end.

%% report §6.6, Appendix E.0 rule 8: a time has no upper bound; a call
%% given more than the host's longest wait, 2^32 - 1 ms, is answered as any
%% other. A regression test: the host's receive refused such a time, and
%% the call faulted with timeout_value. It does not cover a wait that
%% actually outlasts one slice of 2^32 - 1 ms
call_long_time_test() ->
    Self = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Caller = erlang:self(),
                   %% answered once the caller waits, with the long time
                   Server = ern_rt:spawn(fun() ->
                                             receive {ask, Reply} -> ok end,
                                             ok = ern_waits:waiting(Caller),
                                             ern_rt:answer(Reply, 7)
                                         end, <<"s">>),
                   Self ! {result, ern_rt:call(Server, fun(Reply) -> {ask, Reply} end, 5000000000)}
               end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(ok, Result),
    ?assertEqual({'Some', 7}, wait(result)).

%% Appendix E.0 rule 8, E.15: an alarm has no upper bound either, though
%% the host's timers have one near 2^63 microseconds; the clock sets such an
%% alarm again in slices, and goes on serving. A regression test: the host
%% refused the time, the clock died, and every later alarm was lost. It
%% does not cover an alarm that actually outlasts one slice
clock_long_time_test() ->
    Quiet = #{stdout => fun(_) -> ok end},
    Self = self(),
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Clock = ern_rt:system_process(clock),
                           alarm(Clock, 10000000000000, ern_rt:self()),
                           alarm(Clock, 0, ern_rt:self()),
                           receive Time when is_integer(Time) -> ok end,
                           Self ! {alive, erlang:is_process_alive(Clock)}
                       end, <<"main">>, Quiet)),
    ?assertEqual(true, wait(alive)).

%% report §8.6: a process is in the table before it runs, so a timed
%% receive it enters first is counted. A regression test for a lost count
%% that made such a wait a deadlock, first seen at the shell's first input.
%% Two thousand processes each look for their row first; before the fix
%% some did not find it. A race can be won by luck, so a pass confirms the
%% order rather than proving it
spawned_row_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               [ern_rt:spawn(fun() -> Self ! {row, ets:lookup(ern_processes, erlang:self())} end,
                             <<"s">>)
                || _ <- lists:seq(1, 2000)]
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Rows = [wait(row) || _ <- lists:seq(1, 2000)],
    ?assertEqual([], [Row || Row <- Rows, Row =:= []]).

%% report §11.2: while a shell holds the terminal no deadlock is detected;
%% here a message the runtime cannot see coming arrives after the detector
%% has looked three times. A regression test: in line mode nothing else
%% kept the detector away
shell_holds_no_deadlock_test() ->
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           ern_rt:hold_terminal(ern_rt:self()),
                           Self = ern_rt:self(),
                           erlang:spawn(fun() -> ern_waits:looked(3), Self ! late end),
                           receive late -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §6.9: Down carries the process, the reason and the spawn site,
%% for a monitor made while the process runs
monitor_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Worker = ern_rt:spawn(gated(fun() -> ok end), <<"Main.main:3">>),
               ern_rt:monitor(Worker, fun(Down) -> {down, Down} end),
               Worker ! go,
               receive {down, WorkerDown} -> Self ! {d1, WorkerDown} end,
               Zero = zero(),
               Faulty = ern_rt:spawn(gated(fun() -> 1 div Zero end), <<"Main.main:5">>),
               ern_rt:monitor(Faulty, fun(Down) -> {down, Down} end),
               Faulty ! go,
               receive {down, FaultyDown} -> Self ! {d2, FaultyDown} end,
               Victim = ern_rt:spawn(fun() -> receive never -> ok end end,
                                     <<"Main.main:7">>),
               ern_rt:monitor(Victim, fun(Down) -> {down, Down} end),
               ern_rt:kill(Victim),
               receive {down, VictimDown} -> Self ! {d3, VictimDown} end,
               Self ! {pids, [Worker, Faulty, Victim]}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    [Worker, Faulty, Victim] = wait(pids),
    ?assertEqual({'Down', Worker, 'Returned', <<"Main.main:3">>}, wait(d1)),
    ?assertEqual({'Down', Faulty, {'Fault', <<"division by zero">>}, <<"Main.main:5">>},
                 wait(d2)),
    ?assertEqual({'Down', Victim, 'Killed', <<"Main.main:7">>}, wait(d3)).

%% report §6.9, §8.6: the runtime keeps nothing of a process that has
%% ended, so a monitor made after its end answers Unknown with no spawn
%% site. A regression test: the runtime kept a row for every process that
%% had ever ended, which a server spawning a process per request grew
%% without bound, and the idle deadlock check once copied them all.
ended_rows_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Pids = [ern_rt:spawn(fun() -> 1 div Zero end, <<"Main.main:2">>)
                       || _ <- lists:seq(1, 50)],
               [ern_rt:monitor(Pid, fun(Down) -> {ended, Down} end) || Pid <- Pids],
               [receive {ended, _} -> ok end || _ <- Pids],
               Self ! {row, ets:lookup(ern_processes, lists:last(Pids))},
               ern_rt:monitor(lists:last(Pids), fun(Down) -> {down, Down} end),
               receive {down, Down} -> Self ! {late, {lists:last(Pids), Down}} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual([], wait(row)),
    {Last, Late} = wait(late),
    ?assertEqual({'Down', Last, 'Unknown', <<>>}, Late).

%% A process body that starts once it is told to, so that a monitor can be
%% made while it runs.
gated(Function) ->
    fun() -> receive go -> Function() end end.

%% report §7.3, §6.9, §11.2: a failure of the runtime is the host's class
%% and reason, the entry process's fault carries the host's stack beside
%% it, and a monitor's Down carries the text alone. A regression test: the
%% stack was dropped.
runtime_failure_test() ->
    Self = self(),
    Bad = fun() -> binary_to_integer(atom_to_binary(zero_text())) end,
    ?assertMatch({fault, <<"error:badarg">>, <<"    erlang:binary_to_integer/1", _/binary>>},
                 ern_rt:run_main(Bad, <<"main">>, #{stdout => fun(_) -> ok end})),
    ok = ern_rt:run_main(
           fun() ->
               Pid = ern_rt:spawn(gated(Bad), <<"Main.main:2">>),
               ern_rt:monitor(Pid, fun(Down) -> {down, Down} end),
               Pid ! go,
               receive {down, Down} -> Self ! {down, Down} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertMatch({'Down', _, {'Fault', <<"error:badarg">>}, <<"Main.main:2">>}, wait(down)).

%% report §6.9, §6.5: a monitor's wrap that faults is the fault of the
%% process it delivers to, and the runtime goes on. A regression test: the
%% wrap ran in the runtime's reaper, whose death left every later spawn
%% waiting for ever.
faulting_wrap_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Watcher = ern_rt:spawn_monitored(
                           fun() ->
                               _ = ern_rt:spawn_monitored(fun() -> ok end,
                                                          fun(_) -> 1 div Zero end, <<"w">>),
                               receive never -> ok end
                           end, fun(Down) -> {watcher, Down} end, <<"Main.main:3">>),
               receive {watcher, WatcherDown} -> Self ! {d1, WatcherDown} end,
               _ = ern_rt:spawn_monitored(fun() -> ok end, fun(Down) -> {later, Down} end,
                                          <<"Main.main:5">>),
               receive {later, LaterDown} -> Self ! {d2, LaterDown} end,
               Watcher
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertMatch({'Down', _, {'Fault', <<"division by zero">>}, <<"Main.main:3">>}, wait(d1)),
    ?assertMatch({'Down', _, 'Returned', <<"Main.main:5">>}, wait(d2)).

%% report §6.5, E.15: an alarm's function that never finishes holds up no
%% other alarm. A regression test: the clock applied it itself, and froze
%% for every process.
endless_alarm_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:system_process(clock),
               Endless = fun Endless(Argument) -> Endless(Argument) end,
               alarm(Clock, 10, ern_rt:via(ern_rt:self(), Endless)),
               alarm(Clock, 50, ern_rt:via(ern_rt:self(), fun(_) -> tick end)),
               receive tick -> Self ! ticked end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(ticked, wait_atom(ticked)).

%% An atom whose text is no integer, which the compiler cannot see through.
zero_text() -> list_to_atom("zero").

%% report §6.5: via adapts a message on its way to the target
via_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Adapted = ern_rt:via(ern_rt:self(), fun(Number) -> {tick, Number} end),
               ern_rt:send(Adapted, 7),
               receive {tick, 7} -> Self ! via_ok end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(via_ok, wait_atom(via_ok)).

%% report §8.6: main's fault is reported; other processes get ProgramEnd
main_fault_test() ->
    ?assertEqual({fault, <<"division by zero">>},
                 ern_rt:run_main(fun() -> 1 div zero() end, <<"main">>,
                                 #{stdout => fun(_) -> ok end})).

%% report §8.2, Appendix E.15: the clock fires an alarm, carrying the time
%% it fired, which Clock.now reads
clock_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:system_process(clock),
               Now = ern_rt:now(),
               alarm(Clock, 5, ern_rt:self()),
               %% Appendix E.15: the alarm carries the time it fired
               receive Fired when is_integer(Fired) -> Self ! {clock_ok, Fired >= Now} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(true, wait(clock_ok)).

%% report Appendix E.15: Clock.now reads the host's clock and sends no
%% message, so it answers while the clock's process cannot (MVP 2.99d's
%% item 13). A regression test: `now` asked the clock's process.
clock_now_reads_the_host_test_() ->
    {timeout, 10, fun clock_now_reads_the_host/0}.

clock_now_reads_the_host() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:system_process(clock),
               true = erlang:suspend_process(Clock),
               Answer = 'ern@clock':now(),
               true = erlang:resume_process(Clock),
               Self ! {now, Answer}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Now = wait(now),
    ?assert(is_integer(Now) andalso abs(Now - erlang:system_time(millisecond)) < 1000).

%% report §8.4: a process's end is a host term, since foreign code may
%% observe it: normal, {ern, fault, Text}, {ern, fault, Text, Trace} for a
%% failure of the runtime, {ern, killed}, {ern, program_end}; a socket's
%% {ern, closed} is ern_tcp_tests'
host_exit_reason_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Good = ern_rt:spawn(fun() -> receive go -> ok end end, <<"Main.main:3">>),
               erlang:monitor(process, Good),
               Good ! go,
               receive {'DOWN', _, process, Good, GoodReason} -> Self ! {r1, GoodReason} end,
               Bad = ern_rt:spawn(fun() -> receive go -> 1 div Zero end end,
                                  <<"Main.main:5">>),
               erlang:monitor(process, Bad),
               Bad ! go,
               receive {'DOWN', _, process, Bad, BadReason} -> Self ! {r2, BadReason} end,
               Victim = ern_rt:spawn(fun() -> receive never -> ok end end,
                                     <<"Main.main:7">>),
               erlang:monitor(process, Victim),
               ern_rt:kill(Victim),
               receive {'DOWN', _, process, Victim, VictimReason} -> Self ! {r3, VictimReason} end,
               Failed = ern_rt:spawn(fun() -> receive go -> erlang:error(boom) end end,
                                     <<"Main.main:9">>),
               erlang:monitor(process, Failed),
               Failed ! go,
               receive {'DOWN', _, process, Failed, FailedReason} -> Self ! {r4, FailedReason} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(normal, wait(r1)),
    ?assertEqual({ern, fault, <<"division by zero">>}, wait(r2)),
    ?assertEqual({ern, killed}, wait(r3)),
    ?assertMatch({ern, fault, <<"error:boom">>, Trace} when is_binary(Trace), wait(r4)),
    %% a process still alive when main returns ends with the program
    spawn(fun() ->
              ern_rt:run_main(
                fun() ->
                    Waiter = ern_rt:spawn(fun() -> receive never -> ok end end,
                                          <<"Main.main:9">>),
                    Self ! {waiter, {Waiter, erlang:self()}},
                    %% the program ends once the test monitors the process
                    ern_rt:timed(),
                    receive monitored -> ern_rt:untimed() end
                end, <<"main">>, #{stdout => fun(_) -> ok end})
          end),
    {Waiter, EntryProcess} = wait(waiter),
    MonitorRef = erlang:monitor(process, Waiter),
    EntryProcess ! monitored,
    receive
        {'DOWN', MonitorRef, process, Waiter, ExitReason} ->
            ?assertEqual({ern, program_end}, ExitReason)
    after 2000 -> error(no_program_end)
    end.

%% report §6.9: a process the host ends otherwise, here killed by foreign
%% code, has the reason Fault(text), the host's term as the host writes it.
%% A regression test of the sentence, written after the code
host_ended_process_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Victim = ern_rt:spawn(fun() -> receive never -> ok end end, <<"Main.main:3">>),
               ern_rt:monitor(Victim, fun(Down) -> {down, Down} end),
               erlang:exit(Victim, kill),
               receive {down, Down} -> Self ! {d, Down} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertMatch({'Down', _, {'Fault', <<"killed">>}, <<"Main.main:3">>}, wait(d)).

%% report §8.6: a subscription and a read in progress are sources that can
%% still deliver, so a program waiting on one is not deadlocked
sources_test() ->
    %% a key that arrives after the detector has looked twice
    Key = fun() -> ern_waits:looked(2), "x" end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           %% report §8.2: the subscription is answered once the mode is set
                           subscribe(ern_rt:system_process(terminal)),
                           receive _ -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end, keys => Key})),
    %% a line that takes as long to arrive
    Slow = fun() -> ern_waits:looked(2), "hello\n" end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Stdin = ern_rt:system_process(stdin),
                           {'Some', {'Some', <<"hello">>}} =
                               ern_rt:call(Stdin, fun(Reply) -> {'ReadLine', Reply} end, 5000),
                           ok
                       end, <<"main">>, #{stdout => fun(_) -> ok end, stdin => Slow})).

%% report §8.6, §6.5: a message an alarm delivers through `via` is in
%% flight until its delivery process ends, `via` making no process of its
%% own, so the program that waits for it is not deadlocked; here the
%% adapting function, which the delivery runs, waits for the detector to
%% look twice
via_in_flight_test() ->
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Clock = ern_rt:system_process(clock),
                           Slow = fun(_) -> ern_waits:looked(2), tick end,
                           alarm(Clock, 0, ern_rt:via(ern_rt:self(), Slow)),
                           receive tick -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §6.5: an address seen through a function is the target and the
%% function, not a process, so adapting costs nothing that accumulates. An
%% alarm's delivery is a process of its own until it has delivered (§6.9),
%% so the live processes are counted once those have ended; they were
%% counted at once, and the count failed when one had delivered and not yet
%% ended
via_is_not_a_process_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Before = alive(),
               Clock = ern_rt:system_process(clock),
               Mine = ern_rt:self(),
               lists:foreach(fun(_) ->
                                 alarm(Clock, 0, ern_rt:via(Mine, fun(_) -> tick end))
                             end, lists:seq(1, 100)),
               lists:foreach(fun(_) -> receive tick -> ok end end, lists:seq(1, 100)),
               ern_rt:timed(),
               ern_waits:delivered(erlang:self()),
               ern_rt:untimed(),
               Self ! {counts, Before, alive()}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Before, After} = wait_counts(),
    ?assertEqual(Before, After).

%% The processes alive, not those that have ended and are being removed,
%% which the host's count of processes still holds.
alive() ->
    length([Pid || Pid <- erlang:processes(), erlang:is_process_alive(Pid)]).

%% report §8.4, §6.5: an address handed to a foreign function arrives as
%% the checking proxy, and the proxy names the process behind it, so what
%% the runtime holds of a process, its terminal (§11.2) among it, is the
%% process and not the proxy
proxy_names_its_process_test() ->
    Self = self(),
    Descriptor = {address, string, <<"a String">>},
    ok = ern_rt:run_main(
           fun() ->
               Mine = ern_rt:self(),
               [Proxy] = ern_boundary:expose({list, Descriptor}, [Mine]),
               Self ! {proxy, {Proxy, ern_rt:process_of(Proxy), Mine}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Proxy, Behind, Mine} = wait(proxy),
    ?assertNotEqual(Mine, Proxy),
    ?assertEqual(Mine, Behind).

%% report §8.4: an address that crossed into foreign code comes back as the
%% program's own at the type it crossed at, as it does inside an answer
%% Ernest code gave to a Reply foreign code relayed, every address of which
%% crossed; a process of the program's whose address foreign code was never
%% given is a bad value. A regression test: the second was the program's
%% own at whatever type foreign code named
never_given_address_test() ->
    Self = self(),
    Descriptor = {address, string, <<"a String">>},
    ok = ern_rt:run_main(
           fun() ->
               Mine = ern_rt:self(),
               [Proxy] = ern_boundary:expose({list, Descriptor}, [Mine]),
               Given = ern_boundary:value(Descriptor, Proxy, <<"bad return">>),
               Found = try ern_boundary:value(Descriptor, Mine, <<"bad return">>)
                       catch throw:Thrown -> Thrown
                       end,
               Self ! {held, {Mine, Given, Found}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Mine, Given, Found} = wait(held),
    ?assertEqual(Mine, Given),
    ?assertEqual({ern, fault, <<"bad return">>}, Found).

%% report §6.5, §7.4: a fault in the function is the target's, and the
%% process that sent the message goes on
via_fault_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Victim = ern_rt:spawn(fun() -> receive never -> ok end end,
                                     <<"Main.main:3">>),
               ern_rt:monitor(Victim, fun(Down) -> {down, Down} end),
               ern_rt:send(ern_rt:via(Victim, fun(_) -> 1 div Zero end), 1),
               receive {down, Down} -> Self ! {d, Down} end,
               Self ! {sender, alive}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertMatch({'Down', _, {'Fault', <<"division by zero">>}, <<"Main.main:3">>}, wait(d)),
    ?assertEqual(alive, wait(sender)).

%% report §6.9: a monitor is the reaper's whoever started the process, so
%% watching one the runtime did not start costs no process either
monitor_foreign_process_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               %% it ends once the monitors are made and counted
               Other = erlang:spawn(fun() -> receive go -> ok end end),
               Before = erlang:system_info(process_count),
               lists:foreach(fun(_) -> ern_rt:monitor(Other, fun(Down) -> {down, Down} end) end,
                             lists:seq(1, 20)),
               Self ! {counts, Before, erlang:system_info(process_count)},
               Other ! go,
               receive {down, Down} -> Self ! {d, Down} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Before, After} = wait_counts(),
    ?assertEqual(Before, After),
    ?assertMatch({'Down', _, 'Returned', <<>>}, wait(d)).

wait(Tag) ->
    receive {Tag, Value} -> Value after 1000 -> timeout end.

%% An input that gives each of Chunks in turn, to whichever process reads
%% it, the standard input's or the terminal's, and then what Last gives,
%% `eof` for an input that ends.
-spec queued_input(list(), fun(() -> term())) -> fun(() -> term()).
queued_input(Chunks, Last) ->
    Table = ets:new(chunks, [public]),
    ets:insert(Table, {queue, Chunks}),
    fun() ->
        case ets:lookup(Table, queue) of
            [{_, [Chunk | Rest]}] -> ets:insert(Table, {queue, Rest}), Chunk;
            _ -> Last()
        end
    end.

%% The process counts a test sent, before and after.
wait_counts() ->
    receive {counts, Before, After} -> {Before, After} after 2000 -> timeout end.

wait_atom(Atom) ->
    receive Atom -> Atom after 1000 -> timeout end.

%% a zero the compiler cannot see through
zero() ->
    list_to_integer("0").

%% Report §8.2: `Subscribe` carries a reply, answered once the terminal is
%% in the mode the keys need.
subscribe(Tty) ->
    Self = ern_rt:self(),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Self, Reply} end, 5000).

%% report §6.9, Appendix E.22: a process that is not restarting is never
%% asked, nor is one that has ended; a restarting one restarts at its wait,
%% the cause of its new start `Asked`, and the time it restarted is not
%% counted against its limit. Two asks made before it takes either restart
%% it once, the second emptied with its mailbox, and an ask after that
%% restarts it again. A regression test, written after the code; it does
%% not cover a process that computes without waiting, which is never
%% restarted and so shows nothing to wait for
ask_restart_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = erlang:self(),
               Plain = ern_rt:spawn(fun() -> receive never -> ok end end, <<"M.p:1">>),
               Once = ern_rt:restarting({'RestartLimit', 0, 5000},
                                        fun() ->
                                            EntryProcess ! {started, ern_rt:start_cause()},
                                            %% the clause the emitter gives every receive
                                            receive
                                                '$ern_restart' -> ern_rt:restart_now();
                                                never -> ok
                                            end
                                        end),
               Child = ern_rt:spawn(Once, <<"M.c:2">>),
               ChildPid = ern_rt:process_of(Child),
               %% the host's monitor orders the child's messages before its
               %% end; the runtime's gives its Down once its row has gone
               HostRef = erlang:monitor(process, ChildPid),
               ern_rt:monitor(Child, fun(Down) -> {down, Down} end),
               First = started(),
               Asked = [ern_rt:ask_restart(ern_rt:process_of(Plain)),
                        ern_rt:ask_restart(ChildPid),
                        ern_rt:ask_restart(ChildPid)],
               Second = started(),
               ern_rt:ask_restart(ChildPid),
               Third = started(),
               Self ! {plain, ern_rt:info(ern_rt:process_of(Plain)) =/= 'None'},
               ern_rt:kill(Child),
               ern_rt:timed(),
               receive {down, _} -> ok end,
               receive {'DOWN', HostRef, process, _, _} -> ern_rt:untimed() end,
               Self ! {starts, [First, Second, Third],
                       [More || {started, More} <- flush()]},
               Self ! {asked, Asked},
               Self ! {ended, ern_rt:ask_restart(ChildPid)},
               ern_rt:kill(Plain)
           end, <<"main">>, #{}),
    ?assertEqual({['First', 'Asked', 'Asked'], []},
                 receive {starts, Starts, Later} -> {Starts, Later} after 1000 -> timeout end),
    ?assertEqual(true, receive {plain, IsPlainAlive} -> IsPlainAlive after 1000 -> timeout end),
    %% the answer says whether the process was asked, which the supervisor
    %% counts on (Appendix E.22)
    ?assertEqual([false, true, true], receive {asked, Asked} -> Asked after 1000 -> timeout end),
    ?assertEqual(false, receive {ended, Ended} -> Ended after 1000 -> timeout end).

%% The cause of the child's next start, counted as a timed wait so that it
%% is no deadlock (§8.6).
started() ->
    ern_rt:timed(),
    receive {started, Cause} -> ern_rt:untimed(), Cause end.

%% report §6.9: a restart asks the system processes that hold what the
%% process asked for at once, and one that has died holds up no restart. A
%% regression test: a restart waited on each in turn, with no monitor, and
%% a dead clock held every restart for ever
restart_outlives_a_dead_system_process_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:system_process(clock),
               MonitorRef = erlang:monitor(process, Clock),
               exit(Clock, kill),
               receive {'DOWN', MonitorRef, process, _, _} -> ok end,
               Twice = ern_rt:restarting({'RestartLimit', 1, 5000},
                                         fun() ->
                                             Self ! {started, ern_rt:start_cause()},
                                             case ern_rt:start_cause() of
                                                 'First' -> error(once);
                                                 _ -> ok
                                             end
                                         end),
               Child = ern_rt:spawn(Twice, <<"M.c:1">>),
               ern_rt:monitor(Child, fun(Down) -> {down, Down} end),
               receive {down, _} -> ok end
           end, <<"main">>, #{stderr => fun(_) -> ok end}),
    ?assertEqual(['First', 'AfterFault'],
                 [receive {started, Start} -> Start after 2000 -> timeout end || _ <- [1, 2]]).

%% Report §6.6, §8.6: a wait of a call's time, the deadline the report
%% states, made within the call, whose clock has started, so that the time
%% has passed when it ends; counted as timed so that it is no deadlock.
timed_wait(Ms) ->
    ern_rt:timed(),
    receive after Ms -> ok end,
    ern_rt:untimed().

%% Report Appendix E.15: an alarm as `Clock.alarm` sets one, Alarm(ms,
%% address, reply) in declared field order, answered once the clock holds
%% it.
alarm(Clock, Ms, Address) ->
    'Unit' = ern_rt:call_forever(Clock, fun(Reply) -> {'Alarm', Ms, Address, Reply} end).

%% report Appendix E.15: an alarm at a time fires when the clock reaches
%% the time, though the clock is set before it fires: a clock set past the
%% time fires it once the host reports the change, and a clock set back
%% delays it; an alarm after milliseconds is not moved. The test's clock
%% stands in for the host's, and the test delivers the host's notice of a
%% change. A regression test, written after the code: an alarm at a time
%% fixed its deadline when it was set. It does not cover the host's own
%% notice, which only a clock set under the host gives.
alarm_at_follows_the_clock_test_() ->
    {timeout, 30, fun alarm_at_follows_the_clock/0}.

alarm_at_follows_the_clock() ->
    Self = self(),
    Ahead = atomics:new(1, []),
    Time = fun() -> erlang:system_time(millisecond) + atomics:get(Ahead, 1) end,
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:system_process(clock),
               Me = ern_rt:self(),
               Set = fun(Ms) ->
                         atomics:put(Ahead, 1, Ms),
                         Clock ! {'CHANGE', make_ref(), time_offset, clock_service, 0}
                     end,
               AlarmAt = fun(At, Tag) ->
                             Address = ern_rt:via(Me, fun(Fired) -> {Tag, Fired} end),
                             'Unit' = ern_rt:call_forever(
                                        Clock, fun(Reply) -> {'AlarmAt', At, Address, Reply} end)
                         end,
               Start = Time(),
               AlarmAt(Start + 60000, minute),
               alarm(Clock, 2000, ern_rt:via(Me, fun(Fired) -> {after_ms, Fired} end)),
               Before = receive {minute, _} -> fired after 100 -> waiting end,
               Set(61000),
               Minute = receive {minute, Fired} -> Fired - Start after 1000 -> late end,
               Unmoved = receive {after_ms, _} -> fired after 0 -> waiting end,
               AlarmAt(Time() + 200, soon),
               Set(51000),
               SetBack = receive {soon, _} -> fired after 600 -> waiting end,
               Set(61000),
               SetAgain = receive {soon, _} -> fired after 1000 -> late end,
               AfterMs = receive {after_ms, _} -> fired after 4000 -> late end,
               Self ! {ended, {Before, Minute >= 60000, Unmoved, SetBack, SetAgain, AfterMs}}
           end, <<"main">>, #{time => Time, stdout => fun(_) -> ok end}),
    ?assertEqual({waiting, true, waiting, waiting, fired, fired}, wait(ended)).
