%% Report §8.6: a program's end at a deadlock, which the runtime's reaper
%% finds, and the waits the reaper holds, in programs run as the runner
%% runs them (ern_emitter_tests:run/3).
-module(ern_reaper_tests).

-export([reaper_words/0]).

-include_lib("eunit/include/eunit.hrl").

%% report §8.6, §7.4: a program whose every process waits forever ends
%% with the entry process's fault, `deadlock`; a timed receive is a source
%% and ends by itself
deadlock_test() ->
    {Result1, _} = ern_emitter_tests:run(
        "type Msg = Ping\n"
        "export fn main() : Unit with Msg = receive { Ping -> Unit }\n"),
    ?assertEqual({fault, <<"deadlock">>}, Result1),
    {Result2, Output} = ern_emitter_tests:run(
        "type Msg = Ping\n"
        "export fn main() : Unit with Msg = receive {\n"
        "    Ping -> Unit\n"
        "  | after 100 -> Io.println(\"timeout\")\n"
        "}\n"),
    ?assertEqual({ok, <<"timeout\n">>}, {Result2, Output}).

%% report §8.6: a process blocked in Address.callForever waits without a
%% limit, as an untimed receive does, so a call to a server that waits in
%% an untimed receive for something else is a deadlock. A regression test,
%% written after the code; a callForever to a process that has ended is
%% call_ends_with_callee_test_'s
call_forever_deadlock_test() ->
    {Result, _} = ern_emitter_tests:run(
        "type Req = Get(reply : Reply(Int)) | Other\n"
        "fn server() : Unit with Req = receive { Other -> Unit }\n"
        "export fn main() : Unit with m = {\n"
        "    let a = spawn(server);\n"
        "    let _ = Io.debug(Address.callForever(a, fn(r) = Get(reply = r)));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual({fault, <<"deadlock">>}, Result).

%% report §6.9: a wait on a process is kept while its waiter lives: a
%% watcher that ends takes its waits with it, and a process that ends
%% leaves nothing behind in what its waiter watches. A regression test,
%% written after the code: the runtime kept both for as long as the other
%% process lived, so a long-lived service watched by short-lived clients,
%% or a long-lived process watching short-lived workers, grew it with every
%% monitor. The runtime's memory for waits is read after 100 of each and
%% after 1,100.
monitors_let_go_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ended(Down) | Go\n"
        "foreign fn waits() : Int with m = \"ern_reaper_tests:reaper_words/0\"\n"
        "fn rounds(keeper : Address(Msg), n : Int) : Unit with Msg =\n"
        "    if n == 0 then Unit\n"
        "    else {\n"
        "        let _ = spawnMonitored(fn() : Unit with Msg ="
        " monitor(Process.fromAddress(keeper), Ended),\n"
        "            Ended);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        let w = spawn(fn() : Unit with Msg = receive { Go -> Unit });\n"
        "        monitor(Process.fromAddress(w), Ended);\n"
        "        send(w, Go);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        rounds(keeper, n - 1)\n"
        "    }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let keeper = spawn(fn() : Unit with Msg = receive { Go -> Unit });\n"
        "    rounds(keeper, 100);\n"
        "    let before = waits();\n"
        "    rounds(keeper, 1000);\n"
        "    Io.println(Io.show(waits() == before))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Output).

%% The words of the runtime's reaper, which holds every wait, after the
%% deliveries in flight have ended and its garbage is collected.
reaper_words() ->
    timer:sleep(100),
    Reaper = persistent_term:get({ern_rt, reaper}),
    erlang:garbage_collect(Reaper),
    {total_heap_size, Words} = erlang:process_info(Reaper, total_heap_size),
    Words.

%% report §8.6: a program waiting only on alarms it has set is in no
%% deadlock, however its waits and the clock's work interleave. A
%% regression test, written after the code: the check read its counts
%% before its snapshots, and could not see an alarm still in transit to the
%% clock, so a loop like this one faulted with `deadlock` about one run in
%% three at twenty thousand alarms. At five thousand it catches the race
%% only sometimes; `make load`'s `alarms` catches it more often.
alarms_are_no_deadlock_test_() ->
    {timeout, 120, fun alarms_are_no_deadlock/0}.

alarms_are_no_deadlock() ->
    ?assertEqual({ok, <<"done\n">>}, ern_emitter_tests:run(
        "type Msg = Tick(Int)\n"
        "fn loop(n : Int) : Unit with Msg =\n"
        "    if n == 0 then Unit\n"
        "    else {\n"
        "        Clock.alarmAt(Clock.now(), Tick);\n"
        "        receive { Tick(_) -> Unit };\n"
        "        loop(n - 1)\n"
        "    }\n"
        "export fn main() : Unit with Msg = { loop(5000); Io.println(\"done\") }\n")).
