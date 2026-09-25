-module(ern_rt_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §8.2: the terminal is read as lines or as keys, and the second
%% side to ask is told it is taken, whichever asks first
own_terminal_test() ->
    Result = ern_rt:run_main(fun() ->
                                 Me = ern_rt:self(),
                                 Me ! {owned, ern_rt:own_terminal(keys)},
                                 Me ! {owned, ern_rt:own_terminal(keys)},
                                 Me ! {owned, ern_rt:own_terminal(lines)},
                                 receive after 50 -> ok end
                             end, <<"own_terminal_test">>, #{}),
    ?assertEqual({fault, <<"the terminal is already read as keys">>}, Result).

%% report §8.2: readers of the terminal asking at once, some for lines and
%% some for keys, are one reading and refusals. A regression test: the
%% check and the claim were two steps, and both sides could pass the
%% check. The launcher ends a run at the first refusal, so the claims are
%% made here against the table a run would have. A race can be won by
%% luck, so a pass confirms the order rather than proving it
own_terminal_race_test() ->
    ets:new(ern_processes, [named_table, public, set]),
    Run = make_ref(),
    persistent_term:put({ern_rt, launcher}, {self(), Run}),
    Me = self(),
    Kinds = [case I rem 2 of 0 -> keys; 1 -> lines end || I <- lists:seq(1, 64)],
    Askers = [spawn(fun() ->
                        receive go -> ok end,
                        Me ! {owned, K, ern_rt:own_terminal(K)}
                    end) || K <- Kinds],
    [A ! go || A <- Askers],
    Owned = [receive {owned, K, R} -> {K, R} after 1000 -> timeout end || _ <- Kinds],
    Refused = [receive {fault, Run, Text} -> Text after 1000 -> timeout end
               || {_, taken} <- Owned],
    ets:delete(ern_processes),
    persistent_term:erase({ern_rt, launcher}),
    ?assertEqual(1, length(lists:usort([K || {K, ok} <- Owned]))),
    ?assertEqual(64, length([R || {_, R} <- Owned, R =:= ok orelse R =:= taken])),
    ?assertEqual([], [T || T <- Refused, not is_binary(T)]).

%% report §8.2, §7.3: a read of the standard input that fails is a failure
%% of the runtime, which ends the program with a fault that names it, and an
%% empty line is the empty string. A regression test: each crashed the
%% process behind Sys.stdin, and the caller waited for ever
stdin_failure_test() ->
    Ask = fun() ->
              Stdin = ern_rt:sys(stdin),
              ern_rt:call_forever(Stdin, fun(R) -> {'ReadLine', R} end)
          end,
    Me = self(),
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual({fault, <<"the standard input could not be read: eio">>},
                 ern_rt:run_main(Ask, <<"main">>, Quiet#{stdin => fun() -> {error, eio} end})),
    ?assertEqual(ok, ern_rt:run_main(fun() -> Me ! {line, Ask()} end, <<"main">>,
                                     Quiet#{stdin => fun() -> "" end})),
    ?assertEqual({'Some', <<>>}, wait(line)).

%% report §8.6: a system process that has died can deliver nothing, so it
%% does not keep a deadlock from being found. A regression test: the
%% detector read a dead one as busy, and the program waited for ever
dead_system_process_test() ->
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() ->
                                     exit(ern_rt:sys(clock), kill),
                                     receive never -> ok end
                                 end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §8.5, §8.6: a program that fails to start is ended as one that
%% ran, so the next one starts. A regression test: an initializer of the
%% standard library that raised left the process table and the system
%% processes behind, and the next run failed to make its table
failed_start_test() ->
    Dir = filename:join(filename:basedir(user_cache, "ern_rt_tests"), "failed_start"),
    ok = filelib:ensure_path(Dir),
    Mod = 'ern@zz_failed_start',
    Forms = [{attribute, 1, module, Mod}, {attribute, 1, export, [{'$init', 0}]},
             {function, 1, '$init', 0,
              [{clause, 1, [], [], [{call, 1, {atom, 1, error}, [{atom, 1, boom}]}]}]}],
    {ok, Mod, Bin} = compile:forms(Forms),
    ok = file:write_file(filename:join(Dir, atom_to_list(Mod) ++ ".beam"), Bin),
    true = code:add_patha(Dir),
    Quiet = #{stdout => fun(_) -> ok end},
    try
        ?assertError(boom, ern_rt:run_main(fun() -> ok end, <<"main">>, Quiet))
    after
        code:del_path(Dir),
        code:purge(Mod),
        code:delete(Mod),
        file:delete(filename:join(Dir, atom_to_list(Mod) ++ ".beam"))
    end,
    ?assertEqual(ok, ern_rt:run_main(fun() -> ok end, <<"main">>, Quiet)).

%% Compile a hand-written target module from forms, as the compiler will
%% compile its own output, and run its main under the launcher, collecting
%% what reaches stdout.
run_target(File) ->
    Path = "../../../test/target/" ++ File,
    {ok, Forms} = epp:parse_file(Path, []),
    {ok, Mod, Bin} = compile:forms(Forms, [return_errors]),
    {module, Mod} = code:load_binary(Mod, Path, Bin),
    Me = self(),
    Result = ern_rt:run_main(fun() -> Mod:main() end, <<"main">>,
                             #{stdout => fun(B) -> Me ! {out, B} end}),
    {Result, collect([])}.

collect(Acc) ->
    receive
        {out, B} -> collect([B | Acc])
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
    Me = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Silent = ern_rt:spawn('Local', fun() -> receive _ -> ok end end, <<"s">>),
                   Me ! {result, ern_rt:call(Silent, fun(R) -> {ask, R} end, 20)}
               end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(ok, Result),
    receive {result, R} -> ?assertEqual('None', R) after 1000 -> ?assert(false) end.

%% report §8.6: every live process blocked in an untimed receive, with no
%% timed receive, clock alarm, or foreign call pending, is a deadlock, the
%% entry process's fault `deadlock` (§7.4); each
%% of those is a source that can still deliver, and the program then ends
%% by itself
deadlock_test() ->
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() -> receive never -> ok end end, <<"main">>, Quiet)),
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() ->
                                     _ = ern_rt:spawn('Local', fun() -> receive x -> ok end end,
                                                      <<"s">>),
                                     receive y -> ok end
                                 end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         ern_rt:timed(),
                                         receive never -> ern_rt:untimed(), ok
                                         after 250 -> ern_rt:untimed(), ok
                                         end
                                     end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         Clock = ern_rt:sys(clock),
                                         ern_rt:send(Clock, {'After', 250, ern_rt:self()}),
                                         receive At when is_integer(At) -> ok end
                                     end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         ern_rt:in_foreign(fun() -> receive after 250 -> ok end end)
                                     end, <<"main">>, Quiet)).

%% report §8.6: a process is in the table before it runs, so a timed
%% receive it enters first is counted. A regression test for a lost count
%% that made such a wait a deadlock, first seen at the shell's first input.
%% Two thousand processes each look for their row first; before the fix
%% some did not find it. A race can be won by luck, so a pass confirms the
%% order rather than proving it
spawned_row_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               [ern_rt:spawn('Local',
                             fun() -> Me ! {row, ets:lookup(ern_processes, erlang:self())} end,
                             <<"s">>)
                || _ <- lists:seq(1, 2000)]
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Rows = [wait(row) || _ <- lists:seq(1, 2000)],
    ?assertEqual([], [R || R <- Rows, R =:= []]).

%% report §11.2: while a shell holds the terminal no deadlock is detected;
%% here a message the runtime cannot see coming arrives after the detector
%% has looked several times. A regression test: in line mode nothing else
%% kept the detector away
shell_holds_no_deadlock_test() ->
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           ern_rt:hold_terminal(ern_rt:self()),
                           Me = ern_rt:self(),
                           erlang:spawn(fun() -> timer:sleep(500), Me ! late end),
                           receive late -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §6.9: Down carries the reason and the spawn site
monitor_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Worker = ern_rt:spawn('Local', fun() -> ok end, <<"Main.main:3">>),
               ern_rt:monitor(Worker, fun(D) -> {down, D} end),
               receive {down, D1} -> Me ! {d1, D1} end,
               Zero = zero(),
               Faulty = ern_rt:spawn('Local', fun() -> 1 div Zero end, <<"Main.main:5">>),
               ern_rt:monitor(Faulty, fun(D) -> {down, D} end),
               receive {down, D2} -> Me ! {d2, D2} end,
               Victim = ern_rt:spawn('Local', fun() -> receive never -> ok end end,
                                     <<"Main.main:7">>),
               ern_rt:monitor(Victim, fun(D) -> {down, D} end),
               ern_rt:kill(Victim),
               receive {down, D3} -> Me ! {d3, D3} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Down', <<"Main.main:3">>, 'Returned'}, wait(d1)),
    ?assertEqual({'Down', <<"Main.main:5">>, {'Fault', <<"division by zero">>}}, wait(d2)),
    ?assertEqual({'Down', <<"Main.main:7">>, 'Killed'}, wait(d3)).

%% report §7.3, §7.4, §11.2: a process whose code the shell unloads dies
%% with the fault that says so; the shell ends it as `exit/2` does here
unloaded_code_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Old = ern_rt:spawn('Local', fun() -> receive never -> ok end end,
                                  <<"Main.main:3">>),
               ern_rt:monitor(Old, fun(D) -> {down, D} end),
               exit(Old, {ern, code_unloaded}),
               receive {down, D} -> Me ! {d, D} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Down', <<"Main.main:3">>, {'Fault', <<"its code was unloaded">>}}, wait(d)).

%% report §6.5: via adapts a message on its way to the target
via_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Adapted = ern_rt:via(fun(N) -> {tick, N} end, ern_rt:self()),
               ern_rt:send(Adapted, 7),
               receive {tick, 7} -> Me ! via_ok end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(via_ok, wait_atom(via_ok)).

%% report §8.6: main's fault is reported; other processes get ProgramEnd
main_fault_test() ->
    ?assertEqual({fault, <<"division by zero">>},
                 ern_rt:run_main(fun() -> 1 div zero() end, <<"main">>,
                                 #{stdout => fun(_) -> ok end})).

%% report §9.3, §9.7: the clock answers Now and fires After
clock_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Clock = ern_rt:sys(clock),
               {'Some', T} = ern_rt:call(Clock, fun(R) -> {'Now', R} end, 1000),
               ern_rt:send(Clock, {'After', 5, ern_rt:self()}),
               %% Appendix E.15: the alarm carries the time it fired
               receive Fired when is_integer(Fired) -> Me ! {clock_ok, Fired >= T} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(true, wait(clock_ok)).

%% report §8.4: a process's end is a host term, since foreign code may
%% observe it: normal, {ern, fault, Text}, {ern, killed}, {ern, program_end}
host_exit_reason_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Good = ern_rt:spawn('Local', fun() -> receive go -> ok end end, <<"Main.main:3">>),
               erlang:monitor(process, Good),
               Good ! go,
               receive {'DOWN', _, process, Good, R1} -> Me ! {r1, R1} end,
               Bad = ern_rt:spawn('Local', fun() -> receive go -> 1 div Zero end end,
                                  <<"Main.main:5">>),
               erlang:monitor(process, Bad),
               Bad ! go,
               receive {'DOWN', _, process, Bad, R2} -> Me ! {r2, R2} end,
               Victim = ern_rt:spawn('Local', fun() -> receive never -> ok end end,
                                     <<"Main.main:7">>),
               erlang:monitor(process, Victim),
               ern_rt:kill(Victim),
               receive {'DOWN', _, process, Victim, R3} -> Me ! {r3, R3} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual(normal, wait(r1)),
    ?assertEqual({ern, fault, <<"division by zero">>}, wait(r2)),
    ?assertEqual({ern, killed}, wait(r3)),
    %% a process still alive when main returns ends with the program
    spawn(fun() ->
              ern_rt:run_main(
                fun() ->
                    Me ! {waiter, ern_rt:spawn('Local', fun() -> receive never -> ok end end,
                                               <<"Main.main:9">>)},
                    receive after 200 -> ok end
                end, <<"main">>, #{stdout => fun(_) -> ok end})
          end),
    Waiter = wait(waiter),
    Ref = erlang:monitor(process, Waiter),
    receive {'DOWN', Ref, process, Waiter, R4} -> ?assertEqual({ern, program_end}, R4)
    after 2000 -> error(no_program_end)
    end.

%% report §8.6: a subscription and a read in progress are sources that can
%% still deliver, so a program waiting on one is not deadlocked
sources_test() ->
    %% a key that arrives long after the detector has looked several times
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Tty = ern_rt:sys(terminal),
                           %% report §8.2: the subscription is answered once the mode is set
                           subscribe(Tty),
                           erlang:spawn(fun() -> timer:sleep(500), Tty ! {chars, "x"} end),
                           receive _ -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end})),
    %% a line that takes as long to arrive
    Slow = fun() -> timer:sleep(500), "hello\n" end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Stdin = ern_rt:sys(stdin),
                           {'Some', {'Some', <<"hello">>}} =
                               ern_rt:call(Stdin, fun(R) -> {'ReadLine', R} end, 5000),
                           ok
                       end, <<"main">>, #{stdout => fun(_) -> ok end, stdin => Slow})).

%% report §8.6: a message on its way through a via proxy is in flight, so
%% the program that waits for it is not deadlocked
via_in_flight_test() ->
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Clock = ern_rt:sys(clock),
                           ern_rt:send(Clock, {'After', 400,
                                               ern_rt:via(fun(_) -> tick end, ern_rt:self())}),
                           receive tick -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end})).

%% report §6.5: an address seen through a function is the target and the
%% function, not a process, so adapting costs nothing that accumulates
via_is_not_a_process_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Before = erlang:system_info(process_count),
               Clock = ern_rt:sys(clock),
               Mine = ern_rt:self(),
               lists:foreach(fun(_) ->
                                 ern_rt:send(Clock, {'After', 1,
                                                     ern_rt:via(fun(_) -> tick end, Mine)})
                             end, lists:seq(1, 100)),
               lists:foreach(fun(_) -> receive tick -> ok end end, lists:seq(1, 100)),
               Me ! {counts, Before, erlang:system_info(process_count)}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Before, After} = wait(counts2),
    ?assertEqual(Before, After).

%% report §8.4, §6.3: an address handed to a foreign function arrives as
%% the checking proxy, and the proxy names the process behind it, so what
%% the runtime holds of a process, its terminal (§11.2) among it, is the
%% process and not the proxy
proxy_names_its_process_test() ->
    Me = self(),
    Desc = {pid, string, <<"a String">>},
    ok = ern_rt:run_main(
           fun() ->
               Mine = ern_rt:self(),
               Proxy = ern_boundary:foreign(erlang, hd, [[Mine]], [{list, Desc}], Desc,
                                            <<"a String">>),
               Me ! {proxy, {Proxy, ern_rt:process_of(Proxy), Mine}}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Proxy, Behind, Mine} = wait(proxy),
    ?assertNotEqual(Mine, Proxy),
    ?assertEqual(Mine, Behind).

%% report §6.5, §7.4: a fault in the function is the target's, and the
%% process that sent the message goes on
via_fault_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Zero = zero(),
               Victim = ern_rt:spawn('Local', fun() -> receive never -> ok end end,
                                     <<"Main.main:3">>),
               ern_rt:monitor(Victim, fun(D) -> {down, D} end),
               ern_rt:send(ern_rt:via(fun(_) -> 1 div Zero end, Victim), 1),
               receive {down, D} -> Me ! {d, D} end,
               Me ! {sender, alive}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({'Down', <<"Main.main:3">>, {'Fault', <<"division by zero">>}}, wait(d)),
    ?assertEqual(alive, wait(sender)).

%% report §6.9: a monitor is the reaper's whoever started the process, so
%% watching one the runtime did not start costs no process either
monitor_foreign_process_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               %% it outlives the monitors, which are asked for asynchronously
               Other = erlang:spawn(fun() -> timer:sleep(300) end),
               Before = erlang:system_info(process_count),
               lists:foreach(fun(_) -> ern_rt:monitor(Other, fun(D) -> {down, D} end) end,
                             lists:seq(1, 20)),
               Me ! {counts, Before, erlang:system_info(process_count)},
               receive {down, D} -> Me ! {d, D} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    {Before, After} = wait(counts2),
    ?assertEqual(Before, After),
    ?assertEqual({'Down', <<"unknown">>, 'Returned'}, wait(d)).

wait(counts2) ->
    receive {counts, B, A} -> {B, A} after 2000 -> timeout end;
wait(Tag) ->
    receive {Tag, V} -> V after 1000 -> timeout end.

wait_atom(Atom) ->
    receive Atom -> Atom after 1000 -> timeout end.

%% a zero the compiler cannot see through
zero() ->
    list_to_integer("0").

%% Report §8.2: `Subscribe` carries a reply, answered once the terminal is
%% in the mode the keys need.
subscribe(Tty) ->
    Me = ern_rt:self(),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Reply, Me} end, 5000).
