-module(ern_rt_tests).

-include_lib("eunit/include/eunit.hrl").

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

wait(Tag) ->
    receive {Tag, V} -> V after 1000 -> timeout end.

wait_atom(Atom) ->
    receive Atom -> Atom after 1000 -> timeout end.

%% a zero the compiler cannot see through
zero() ->
    list_to_integer("0").
