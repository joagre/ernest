%% Report §6.9: a restarting function, in programs run as the runner runs
%% them (ern_emitter_tests:run/3).
-module(ern_restart_tests).

-include_lib("eunit/include/eunit.hrl").

%% A program's `up(s)`: true once the restarting process `s` answers, its
%% new run begun, and false once it has ended. A message sent before a
%% restart is lost with the mailbox (report §6.9), so a test that restarts
%% a process sends it the next message only after this.
-define(UP,
        "fn up(s : Address(Msg)) : Bool =\n"
        "    match Address.call(s, fn(r) = Ping(reply = r), 1000) {\n"
        "        Some(_) -> true\n"
        "      | None -> Process.status(Process.fromAddress(s)) != None && up(s)\n"
        "    }\n").

%% report §6.9, §9.5: a process whose function is `restarting`'s runs it
%% again after a fault, keeping its address; its mailbox is emptied, the
%% message being handled lost with the rest, and the new run starts from
%% its function's own state. The next message is sent once a ping is
%% answered by the new run, since a call pending at a restart ends with it
%% (call_ends_with_callee_test_)
restart_keeps_address_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Bump | Crash | Get(reply : Reply(Int)) | Ping(reply : Reply(Unit))\n"
        "fn loop(n : Int) : Unit receiving Msg = receive {\n"
        "    Bump -> loop(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Get(reply = r) -> { answer(r, n); loop(n) }\n"
        "  | Ping(reply = r) -> { answer(r, Unit); loop(n) }\n"
        "}\n"
        ++ ?UP ++
        "export fn main() : Unit = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(restarting(limit, fn() : Unit receiving Msg = loop(0)));\n"
        "    send(s, Bump);\n"
        "    send(s, Crash);\n"
        "    let _ = up(s);\n"
        "    send(s, Bump);\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"1\n">>, Output).

%% report §6.9: past the limit the next fault ends the process with its
%% cause, which is its one death a monitor is told of; a restart is none,
%% and a limit of no restarts ends it at the first fault. Each start says
%% so, so that a limit of one restart is told from a limit of none, which
%% the test could not do before. A second Down is looked for once every
%% delivery started to main has ended; one the runtime had not yet started
%% then is not seen
restart_limit_test() ->
    Program = fun(Restarts) ->
        "type Msg = Crash | Ping(reply : Reply(Unit))\n"
        "type MainMsg = Died(Down)\n"
        "fn loop(n : Int) : Unit receiving Msg =\n"
        "    receive {\n"
        "        Crash -> fault(Int.toString(n))\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop(n) }\n"
        "    }\n"
        "fn count() : Unit receiving Msg = {\n"
        "    Io.println(\"start\");\n"
        "    loop(1)\n"
        "}\n"
        "foreign fn delivered(process : Process) : Foreign.Term =\n"
        "    \"ern_waits:delivered/1\"\n"
        ++ ?UP ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let limit = RestartLimit(restarts = " ++ Restarts ++ ", within = 60000);\n"
        "    let s = spawnMonitored(restarting(limit, count), Died);\n"
        "    let _ = up(s);\n"
        "    send(s, Crash);\n"
        "    if up(s) then send(s, Crash) else Unit;\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(c), site = _)) -> Io.println(\"ended \" <> c)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    };\n"
        "    let _ = delivered(Process.fromAddress(self()));\n"
        "    receive { Died(_) -> Io.println(\"twice\") | after 0 -> Unit }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"start\nstart\nended 1\n">>}, ern_emitter_tests:run(Program("1"))),
    ?assertEqual({ok, <<"start\nended 1\n">>}, ern_emitter_tests:run(Program("0"))),
    ?assertEqual({ok, <<"start\nended 1\n">>}, ern_emitter_tests:run(Program("-2"))).

%% report §6.9, §9.5: a service monitor, `monitorService` called and taken
%% as a value, is told of a restart with the reason `Restarted` and the
%% process's spawn site, and stands until the process ends, which it is
%% told as a monitor is; a `monitor` beside it is told of the end alone,
%% so the restart gives two messages and the kill three
service_monitor_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Crash\n"
        "type MainMsg = Told(Down)\n"
        "fn loop() : Unit receiving Msg =\n"
        "    receive {\n"
        "        Crash -> fault(\"crash\")\n"
        "    }\n"
        "fn told() : Unit receiving MainMsg =\n"
        "    receive {\n"
        "        Told(Down(reason = Restarted, site = site)) ->\n"
        "            Io.println(\"restarted \" <> site)\n"
        "      | Told(Down(reason = reason)) -> Io.println(Io.show(reason))\n"
        "    }\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let s = spawn(restarting(Unlimited, loop));\n"
        "    let watch = monitorService;\n"
        "    watch(Process.fromAddress(s), Told);\n"
        "    monitorService(Process.fromAddress(s), Told);\n"
        "    monitor(Process.fromAddress(s), Told);\n"
        "    send(s, Crash);\n"
        "    told();\n"
        "    told();\n"
        "    kill(s);\n"
        "    told();\n"
        "    told();\n"
        "    told()\n"
        "}\n"),
    ?assertEqual(<<"restarted M.main:14\nrestarted M.main:14\nKilled\nKilled\nKilled\n">>,
                 Output).

%% report §6.9: a service monitor's Restarted reaches its watcher before
%% anything the new run sends, the restarting process waiting after its
%% emptying until the wrap has placed it: a holder that takes a lock at the
%% start of each run, restarted fifty times, is seen by its guard as
%% Restarted then Take each time. Written with the ordering, after the
%% service monitor's first build, whose Take overtook the Restarted
service_monitor_told_before_the_new_run_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type HolderMsg = Crash\n"
        "type GuardMsg = Take | Told(Down)\n"
        "fn holder(guard : Address(GuardMsg)) : Unit receiving HolderMsg = {\n"
        "    send(guard, Take);\n"
        "    receive {\n"
        "        Crash -> fault(\"crash\")\n"
        "    }\n"
        "}\n"
        "fn next() : String receiving GuardMsg =\n"
        "    receive {\n"
        "        Take -> \"take\"\n"
        "      | Told(Down(reason = reason)) -> Io.show(reason)\n"
        "    }\n"
        "fn crashes(h : Address(HolderMsg), count : Int, wrong : Int) : Int receiving GuardMsg =\n"
        "    if count == 0 then\n"
        "        wrong\n"
        "    else {\n"
        "        send(h, Crash);\n"
        "        let first = next();\n"
        "        let second = next();\n"
        "        let right = first == \"Restarted\" && second == \"take\";\n"
        "        crashes(h, count - 1, if right then wrong else wrong + 1)\n"
        "    }\n"
        "export fn main() : Unit receiving GuardMsg = {\n"
        "    let me = self();\n"
        "    let h = spawn(restarting(Unlimited, fn() = holder(me)));\n"
        "    receive {\n"
        "        Take -> Unit\n"
        "    };\n"
        "    monitorService(Process.fromAddress(h), Told);\n"
        "    Io.println(Int.toString(crashes(h, 50, 0)) <> \" out of order\");\n"
        "    kill(h)\n"
        "}\n"),
    ?assertEqual(<<"0 out of order\n">>, Output).

%% report §6.9: a watcher told Restarted that sends the restarted process a
%% request at once reaches the new run: the restarting process empties its
%% mailbox and ends the calls waiting on it before its service monitors'
%% wraps place their Restarted, and runs its function again after, so the
%% watcher's call, made on each Restarted, is answered by the new run, each
%% run counting from one, fifty restarts in a row. A regression test,
%% written after the code: the Restarted was placed before the emptying, and
%% a request sent on it could be emptied with the old run's mailbox or its
%% call ended with the old run's (feedback 163). It does not cover a
%% service monitor of another node's process, which no restart reaches
%% (§8.7)
restarted_watcher_reaches_the_new_run_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type HolderMsg = Crash | Count(Reply(Int))\n"
        "type WatcherMsg = Told(Down)\n"
        "fn holder(count : Int) : Unit receiving HolderMsg =\n"
        "    receive {\n"
        "        Crash -> fault(\"crash\")\n"
        "      | Count(r) -> { answer(r, count); holder(count + 1) }\n"
        "    }\n"
        "fn crashes(h : Address(HolderMsg), left : Int, wrong : Int) : Int receiving WatcherMsg =\n"
        "    if left == 0 then\n"
        "        wrong\n"
        "    else {\n"
        "        send(h, Crash);\n"
        "        let counted = receive {\n"
        "            Told(Down(reason = Restarted)) -> Address.callForever(h, Count)\n"
        "          | Told(_) -> 0\n"
        "        };\n"
        "        crashes(h, left - 1, if counted == 1 then wrong else wrong + 1)\n"
        "    }\n"
        "export fn main() : Unit receiving WatcherMsg = {\n"
        "    let h = spawn(restarting(Unlimited, fn() = holder(1)));\n"
        "    monitorService(Process.fromAddress(h), Told);\n"
        "    Io.println(Int.toString(crashes(h, 50, 0)) <> \" not answered by the new run\");\n"
        "    kill(h)\n"
        "}\n"),
    ?assertEqual(<<"0 not answered by the new run\n">>, Output).

%% report §6.9: `Unlimited` runs the function again after every fault, and a
%% time of 0 is a window of one millisecond, which a loop that faults at
%% once passes. A regression test: a time of 0 set no limit, and the loop
%% ran for good
restart_unlimited_test_() ->
    {timeout, 30, fun restart_unlimited/0}.

restart_unlimited() ->
    Program = fun(Limit, Body, Crashes) ->
        "type Msg = Crash | Stop | Ping(reply : Reply(Unit))\n"
        "type MainMsg = Died(Down)\n"
        "fn loop() : Unit receiving Msg =\n"
        "    receive {\n"
        "        Crash -> fault(\"crash\")\n"
        "      | Stop -> Unit\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop() }\n"
        "    }\n"
        "fn boom() : Unit receiving Msg = fault(\"boom\")\n"
        ++ ?UP ++
        "fn crash(s : Address(Msg), left : Int) : Unit =\n"
        "    if left == 0 || !up(s) then Unit else { send(s, Crash); crash(s, left - 1) }\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let s = spawnMonitored(restarting(" ++ Limit ++ ", " ++ Body ++ "), Died);\n"
        "    crash(s, " ++ Crashes ++ ");\n"
        "    if up(s) then send(s, Stop) else Unit;\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"Returned\n">>}, ern_emitter_tests:run(Program("Unlimited", "loop", "50"))),
    ?assertEqual({ok, <<"Fault(\"boom\")\n">>},
                 ern_emitter_tests:run(
                     Program("RestartLimit(restarts = 3, within = 0)", "boom", "0"))).

%% report §6.9, §6.6: a restart empties the mailbox, so a plain send and
%% the request of a call the restart ended, both waiting there as the
%% process faulted, are not taken by the new run: the ended call was not
%% done. A regression test: the new run took both, and the total was 6
restart_empties_the_mailbox_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Add(n : Int, reply : Reply(Int)) | Total(reply : Reply(Int)) | Plain(Int)"
        " | Busy\n"
        "fn count(total : Int) : Unit receiving Msg =\n"
        "    receive {\n"
        "        Add(n = n, reply = r) -> { answer(r, total + n); count(total + n) }\n"
        "      | Total(reply = r) -> { answer(r, total); count(total) }\n"
        "      | Plain(n) -> count(total + n)\n"
        "      | Busy -> { spin(Clock.monotonic() + 200); fault(\"busy\") }\n"
        "    }\n"
        "fn spin(until : Int) : Unit =\n"
        "    if Clock.monotonic() >= until then Unit else spin(until)\n"
        "export fn main() : Unit = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(restarting(limit, fn() = count(0)));\n"
        "    send(s, Busy);\n"
        "    send(s, Plain(5));\n"
        "    Io.println(Io.show(Address.call(s, fn(r) = Add(n = 1, reply = r), 2000)));\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Total(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"None\n0\n">>, Output).

%% report §6.9, Appendix E.15, E.21: a restart cancels the process's alarm,
%% its monitor and its subscription to faults, so the new run hears nothing
%% of what the old one asked for. A regression test: the alarm, the Down
%% and the fault reached the new run. The new run is asked once main has
%% seen the Down or the fault itself, and every delivery started to the
%% process has ended; the alarm, which nothing else shows, is waited for
%% twice its time, since the host's timers may fire late
restart_cancels_what_it_asked_for_test_() ->
    {timeout, 30, fun restart_cancels_what_it_asked_for/0}.

restart_cancels_what_it_asked_for() ->
    Program = fun(Ask, After) ->
        "type Msg = Heard | Ask(Address(Int)) | Crash | Ping(reply : Reply(Unit))"
        " | Count(reply : Reply(Int))\n"
        "type MainMsg = Gone(Down) | Report(Process.FaultReport)\n"
        "foreign fn delivered(process : Process) : Foreign.Term =\n"
        "    \"ern_waits:delivered/1\"\n"
        "fn loop(n : Int) : Unit receiving Msg =\n"
        "    receive {\n"
        "        Heard -> loop(n + 1)\n"
        "      | Ask(other) -> { " ++ Ask ++ "; loop(n) }\n"
        "      | Crash -> fault(\"crash\")\n"
        "      | Ping(reply = r) -> { answer(r, Unit); loop(n) }\n"
        "      | Count(reply = r) -> { answer(r, n); loop(n) }\n"
        "    }\n"
        ++ ?UP ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let s = spawn(restarting(limit, fn() = loop(0)));\n"
        "    let other = spawn(fn() : Unit receiving Int = receive { _ -> Unit });\n"
        "    send(s, Ask(other));\n"
        "    send(s, Crash);\n"
        "    let _ = up(s);\n"
        "    " ++ After ++ ";\n"
        "    let _ = delivered(Process.fromAddress(s));\n"
        "    Io.println(Int.toString(Address.callForever(s, fn(r) = Count(reply = r))))\n"
        "}\n"
    end,
    %% an alarm set by the old run, its time passed twice over
    ?assertEqual({ok, <<"0\n">>}, ern_emitter_tests:run(
        Program("Clock.alarm(100, fn(_) = Heard)", "receive { after 2 * 100 -> Unit }"))),
    %% a monitor made by the old run, of a process killed after the restart
    ?assertEqual({ok, <<"0\n">>},
                 ern_emitter_tests:run(
                     Program("monitor(Process.fromAddress(other), fn(_) = Heard)",
                             "monitor(Process.fromAddress(other), Gone); kill(other);"
                             " receive { Gone(_) -> Unit }"))),
    %% a subscription to faults, and a fault after the restart
    ?assertEqual({ok, <<"0\n">>},
                 ern_emitter_tests:run(
                     Program("Process.faults(fn(_) = Heard)",
                             "Process.faults(Report);"
                             " let _ = spawn(fn() = fault(\"other\"));"
                             " receive { Report(_) -> Unit }"))).

%% report §6.9: returning and a kill end a restarting process as they end
%% any; only a fault restarts
restart_only_on_fault_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Stop\n"
        "type MainMsg = Died(Down)\n"
        "fn waits() : Unit receiving Msg = receive { Stop -> Unit }\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let limit = RestartLimit(restarts = 5, within = 60000);\n"
        "    let a = spawnMonitored(restarting(limit, waits), Died);\n"
        "    send(a, Stop);\n"
        "    receive { Died(Down(reason = r, site = _)) -> { let _ = Io.debug(r); Unit } };\n"
        "    let b = spawnMonitored(restarting(limit, waits), Died);\n"
        "    kill(b);\n"
        "    receive { Died(Down(reason = r, site = _)) -> { let _ = Io.debug(r); Unit } };\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"Returned\nKilled\n">>, Output).

%% report §6.9: where restarting functions are nested, a fault restarts the
%% innermost, which counts it against its own limit; one whose limit is
%% spent gives the fault to the one around it, whose restart enters the
%% inner afresh, and the process dies where none is left. A regression
%% test, written after the code; it does not cover a
%% restart a supervisor asks for, which §6.9 gives to the outer function
nested_restarting_test() ->
    {Result, Output} = ern_emitter_tests:run(
        "export fn main() : Unit =\n"
        "    restarting(RestartLimit(restarts = 1, within = 60000), fn() = {\n"
        "        Io.println(\"outer\");\n"
        "        restarting(RestartLimit(restarts = 1, within = 60000), fn() = {\n"
        "            Io.println(\"inner\");\n"
        "            fault(\"boom\")\n"
        "        })()\n"
        "    })()\n"),
    ?assertMatch({fault, <<"boom">>, _}, Result),
    ?assertEqual(<<"outer\ninner\ninner\nouter\ninner\ninner\n">>, Output).
