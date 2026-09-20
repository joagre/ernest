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
%% timed receive, clock alarm, or foreign call pending, is Deadlock; each
%% of those is a source that can still deliver, and the program then ends
%% by itself
deadlock_test() ->
    Quiet = #{stdout => fun(_) -> ok end},
    ?assertEqual(deadlock,
                 ern_rt:run_main(fun() -> receive never -> ok end end, <<"main">>, Quiet)),
    ?assertEqual(deadlock,
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
                                         receive 'Unit' -> ok end
                                     end, <<"main">>, Quiet)),
    ?assertEqual(ok, ern_rt:run_main(fun() ->
                                         ern_rt:in_foreign(fun() -> receive after 250 -> ok end end)
                                     end, <<"main">>, Quiet)).

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
               receive 'Unit' -> Me ! {clock_ok, is_integer(T)} end
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
                           Keys = ern_rt:sys(keys),
                           ern_rt:send(Keys, {'Subscribe', ern_rt:self()}),
                           erlang:spawn(fun() -> timer:sleep(500), Keys ! {chars, "x"} end),
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

wait(Tag) ->
    receive {Tag, V} -> V after 1000 -> timeout end.

wait_atom(Atom) ->
    receive Atom -> Atom after 1000 -> timeout end.

%% a zero the compiler cannot see through
zero() ->
    list_to_integer("0").
