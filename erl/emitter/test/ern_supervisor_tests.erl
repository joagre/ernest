%% Report §6.9 and Appendix E.22: a supervisor's group, in programs run as
%% the runner runs them (ern_emitter_tests:run/3).
-module(ern_supervisor_tests).

-include_lib("eunit/include/eunit.hrl").

-define(LIMIT, "RestartLimit(restarts = 3, within = 5000)").

%% A program whose children are each a counter that a restart sets back
%% to 0, and that faults on Boom. `faulted` waits for a fault's report, to
%% which main subscribes; a call to a child after its fault is answered by
%% the group restarted whole (Appendix E.22), and one a restart ends,
%% which empties the child's mailbox (report §6.9), is made again by
%% `askUntil`, so nothing else is waited for. A count is read by `Peek`,
%% which changes nothing, so that a call made again after its time ran out
%% under load, and answered all the same, reads what one call would.
%% `delivered` waits for every delivery the runtime has started to the
%% process, so that a report already started is in its mailbox.
supervised(Strategy, Limit, Names, Main) ->
    ern_emitter_tests:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom\n"
         "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.",
         Strategy, ", ", Limit, "))\n",
         [["let ", Name, " : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"]
          || Name <- Names],
         "fn count(n : Int) : Unit with Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn askUntil(c : Address(Msg)) : Int with m =\n"
         "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> askUntil(c)\n"
         "    }\n"
         "fn peekUntil(c : Address(Msg)) : Int with m =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn show(c : Address(Msg)) : String with m = Int.toString(peekUntil(c))\n"
         "fn faulted() : Unit with Process.FaultReport = receive { _ -> Unit }\n"
         "foreign fn delivered(process : Process) : Foreign.Term with m =\n"
         "    \"ern_waits:delivered/1\"\n",
         Main]).

%% report §6.9, Appendix E.22: under OneForAll a fault restarts every
%% sibling in place, at its next wait, its address kept
one_for_all_restarts_siblings_test() ->
    {ok, Output} = supervised("OneForAll", ?LIMIT, ["a", "b"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 0\n">>, Output).

%% Appendix E.22: under OneForOne a fault restarts only the child that
%% faulted
one_for_one_restarts_the_child_alone_test() ->
    {ok, Output} = supervised("OneForOne", ?LIMIT, ["a", "b"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 1\n">>, Output).

%% Appendix E.22: under RestForOne a fault restarts the children spawned
%% after the one that faulted, and not those before it
rest_for_one_restarts_later_children_test() ->
    {ok, Output} = supervised("RestForOne", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(b, Boom);\n"
        "    faulted();\n"
        "    Io.println(show(a) <> \" \" <> show(b) <> \" \" <> show(c))\n"
        "}\n"),
    ?assertEqual(<<"1 0 0\n">>, Output).

%% Appendix E.22: RestForOne reads the order the children were spawned in,
%% whatever order they joined in: `a`, spawned first, joins last, once main
%% has had `b` and `c` answer, and its fault still restarts `b` and `c`. A
%% regression test: the order read was the order of joins, which the
%% scheduler decides, and a race of it failed examples/services.ern
rest_for_one_reads_the_order_of_spawns_test() ->
    {ok, Output} = ern_emitter_tests:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom | Go\n"
         "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group("
         "Supervisor.RestForOne, ", ?LIMIT, "))\n"
         "let a : Address(Msg) = spawn(fn() : Unit with Msg = {\n"
         "    receive { Go -> Unit };\n"
         "    Supervisor.child(sup, fn() = count(0))()\n"
         "})\n"
         "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
         "let c : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
         "fn count(n : Int) : Unit with Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn ask(c : Address(Msg)) : Int with m ="
         " Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn peekUntil(c : Address(Msg)) : Int with m =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn show(c : Address(Msg)) : String with m = Int.toString(peekUntil(c))\n"
         "export fn main() : Unit with Process.FaultReport = {\n"
         "    let _ = ask(b); let _ = ask(c);\n"
         "    send(a, Go);\n"
         "    let _ = ask(a);\n"
         "    Process.faults(fn(f) = f);\n"
         "    send(a, Boom);\n"
         "    receive { _ -> Unit };\n"
         "    Io.println(show(a) <> \" \" <> show(b) <> \" \" <> show(c))\n"
         "}\n"]),
    ?assertEqual(<<"0 0 0\n">>, Output).

%% report §6.9: a restart asked for is no fault, and no fault is reported
%% for it; only the child that faulted is. The reports are counted once the
%% siblings have restarted and every delivery started to main has ended; a
%% report the runtime had not yet started then is not seen
restart_asked_for_is_no_fault_test() ->
    {ok, Output} = supervised("OneForAll", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    let _ = askUntil(a); let _ = askUntil(b); let _ = askUntil(c);\n"
        "    let _ = delivered(Process.fromAddress(self()));\n"
        "    Io.println(Int.toString(reports(1)))\n"
        "}\n"
        "fn reports(n : Int) : Int with Process.FaultReport ="
        " receive { _ -> reports(n + 1) | after 0 -> n }\n"),
    ?assertEqual(<<"1\n">>, Output).

%% report §6.6, §6.9: a call waiting on a child when its supervisor
%% restarts it ends, and callForever faults with the cause that says so;
%% the child restarts at the wait inside its handling of the request,
%% where it tells the trigger to make its sibling fault
call_ends_at_asked_restart_test() ->
    {Result, _} = ern_emitter_tests:run(
             "type Msg = Slow(reply : Reply(Int), trigger : Address(Unit)) | Boom\n"
        "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = serve()))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = serve()))\n"
        "fn serve() : Unit with Msg = receive {\n"
        "    Slow(reply = r, trigger = trigger) -> {\n"
        "        send(trigger, Unit);\n"
        "        receive { Boom -> Unit };\n"
        "        answer(r, 1);\n"
        "        serve()\n"
        "    }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let trigger = spawn(fn() : Unit with Unit = receive { _ -> send(a, Boom) });\n"
        "    let _ = Address.callForever(b, fn(r) = Slow(reply = r, trigger = trigger));\n"
        "    Io.println(\"answered\")\n"
        "}\n"),
    ?assertEqual({fault, <<"callee was restarted">>}, Result).

%% Appendix E.22: past its limit a group faults; at the root it dies, and
%% its watcher kills its children
limit_ends_the_group_test() ->
    {ok, Output} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)", ["a"],
        "type Seen = Died(Down) | Faulted(Process.FaultReport)\n"
        "export fn main() : Unit with Seen = {\n"
        "    monitor(Process.fromAddress(a), Died);\n"
        "    Process.faults(Faulted);\n"
        "    send(a, Boom);\n"
        "    receive { Faulted(_) -> Unit };\n"
        "    let _ = askUntil(a);\n"
        "    send(a, Boom);\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"killed\n">>, Output).

%% Appendix E.22: kill(sup) stops the group, the children killed in the
%% reverse of the order they joined, each once the one before has ended
kill_stops_in_reverse_order_test() ->
    {ok, Output} = supervised("OneForOne", ?LIMIT, ["a", "b", "c"],
        "type Seen = Died(String)\n"
        "export fn main() : Unit with Seen = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitor(Process.fromAddress(a), fn(_) = Died(\"a\"));\n"
        "    monitor(Process.fromAddress(b), fn(_) = Died(\"b\"));\n"
        "    monitor(Process.fromAddress(c), fn(_) = Died(\"c\"));\n"
        "    kill(sup);\n"
        "    Io.println(String.join([next(), next(), next()], \" \"))\n"
        "}\n"
        "fn next() : String with Seen = receive { Died(n) -> n }\n"),
    ?assertEqual(<<"c b a\n">>, Output).

%% Appendix E.22: a supervisor that is a child restarts in place past its
%% limit, its children restarted with it, their addresses kept
nested_group_restarts_in_place_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    // the child's fault, and the nested group's at its limit\n"
        "    receive { _ -> Unit };\n"
        "    receive { _ -> Unit };\n"
        "    Io.println(Int.toString(peekUntil(a)) <> \" \" <> Int.toString(peekUntil(b)))\n"
        "}\n"
        "fn peekUntil(c : Address(Msg)) : Int with m =\n"
        "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> peekUntil(c)\n"
        "    }\n"),
    ?assertEqual(<<"0 0\n">>, Output).

%% Appendix E.22: a supervisor restarted in place counts its limit afresh,
%% and a fault it counted before the restart does not expire from the new
%% count. A regression test for alarms of an earlier run lowering the
%% count. The times are the limit's window, which the test is about: the
%% third fault comes half a window after the first, and the fourth a
%% quarter window after the first fault's alarm, a quarter before the
%% third's; every other wait is for a fault's report
count_survives_restart_in_place_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 1, within = 1000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "fn reported() : Unit with Process.FaultReport = receive { _ -> Unit }\n"
        "fn waitUntil(time : Int) : Unit with m =\n"
        "    receive { after Int.max(0, time - Clock.monotonic()) -> Unit }\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let within = 1000;\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    reported();\n"
        "    let first = Clock.monotonic();\n"
        "    // the child runs again before each next fault: its restart empties\n"
        "    // its mailbox (report §6.9)\n"
        "    let _ = askUntil(a);\n"
        "    send(a, Boom);\n"
        "    // the child's fault, and the nested group's at its limit\n"
        "    reported();\n"
        "    reported();\n"
        "    let _ = askUntil(b); let _ = askUntil(b);\n"
        "    let _ = askUntil(a);\n"
        "    waitUntil(first + within / 2);\n"
        "    send(a, Boom);\n"
        "    reported();\n"
        "    let _ = askUntil(a);\n"
        "    waitUntil(first + within + within / 4);\n"
        "    send(a, Boom);\n"
        "    reported();\n"
        "    // answered once the group has restarted whole\n"
        "    let _ = askUntil(a);\n"
        "    Io.println(Int.toString(peekUntil(b)))\n"
        "}\n"
        "fn askUntil(c : Address(Msg)) : Int with m =\n"
        "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> askUntil(c)\n"
        "    }\n"
        "fn peekUntil(c : Address(Msg)) : Int with m =\n"
        "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> peekUntil(c)\n"
        "    }\n"),
    ?assertEqual(<<"0\n">>, Output).

%% Appendix E.22: a child that starts after its supervisor has ended
%% faults once with a cause that says so, and does not restart. A
%% regression test for a child that joined inside its restart loop and
%% restarted without end
child_of_ended_supervisor_test() ->
    {Result, _} = ern_emitter_tests:run(
             "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "type Seen = Ended(Down)\n"
        "export fn main() : Unit with Seen = {\n"
        "    monitor(Process.fromAddress(sup), Ended);\n"
        "    kill(sup);\n"
        "    receive { Ended(_) -> Unit };\n"
        "    let c = Supervisor.child(sup, fn() : Unit with Seen = Unit);\n"
        "    c()\n"
        "}\n"),
    ?assertEqual({fault, <<"the supervisor has ended">>}, Result).

%% report §6.9, Appendix E.22: a root group past its limit faults, and its
%% children are killed; none reports a fault it did not have. A regression
%% test for children that, asked to restart, rejoined the dead supervisor
%% and reported that as their own fault. The reports are read once the
%% children have ended and every delivery started to main has ended; a
%% report the runtime had not yet started then is not seen
limit_reports_only_real_faults_test() ->
    {ok, Output} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)",
        ["a", "b", "c"],
        "type Seen = Report(Process.FaultReport) | Ended(Down)\n"
        "export fn main() : Unit with Seen = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitor(Process.fromAddress(sup), Ended);\n"
        "    List.foreach([a, b, c], fn(child) = monitor(Process.fromAddress(child), Ended));\n"
        "    Process.faults(Report);\n"
        "    send(a, Boom);\n"
        "    receive { Report(_) -> Unit };\n"
        "    let _ = askUntil(a);\n"
        "    send(a, Boom);\n"
        "    let _ = List.map([1, 2, 3, 4], fn(_) = receive { Ended(_) -> Unit });\n"
        "    let _ = delivered(Process.fromAddress(self()));\n"
        "    Io.println(String.join([\"division by zero\"] <> causes([]), \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) with Seen = receive {\n"
        "    Report(f) -> causes(seen <> [f.cause])\n"
        "  | after 0 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero; supervisor restart limit reached\n">>,
                 Output).

%% Appendix E.22: one process runs a group's function, and a second that
%% runs it faults, since the process that keeps the group's children is
%% the function's. Written with the rule (report §6.9's emptied mailbox)
group_runs_in_one_process_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type MainMsg = Died(Down)\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let g = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let _ = spawnMonitored(g, Died);\n"
        "    let _ = spawnMonitored(g, Died);\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"Fault(\"a group runs in one process\")\n">>, Output).

%% Appendix E.22: a group's first supervisor is the one, and a process that
%% runs the group after it has ended faults as a second does while it
%% runs. A regression test: the second was told the watcher had returned
%% without answering
group_runs_once_after_its_end_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type MainMsg = Died(Down)\n"
        "foreign fn waiting(process : Process) : Foreign.Term with m = \"ern_waits:waiting/1\"\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let g = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let first = spawn(g);\n"
        "    // it runs the group, and waits in it\n"
        "    let _ = waiting(Process.fromAddress(first));\n"
        "    monitor(Process.fromAddress(first), Died);\n"
        "    kill(first);\n"
        "    receive { Died(_) -> Unit };\n"
        "    let _ = spawnMonitored(g, Died);\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"Fault(\"a group runs in one process\")\n">>, Output).

%% A group whose children count, fault on Boom, and on Crunch compute for a
%% while without waiting, so that a restart asked of one then waits; on
%% Crash they compute so and then fault. `running` waits until a child
%% computes, `reportOf` for a child's fault's report, and `askUntil` asks
%% again where a restart ended the call, as `peekUntil` reads a count.
crunching(Main) ->
    ern_emitter_tests:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom | Crunch | Crash\n",
         Main,
         "fn count(n : Int) : Unit with Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "  | Crunch -> { let _ = spin(50000000); count(n) }\n"
         "  | Crash -> { let z = spin(50000000); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn spin(k : Int) : Int = if k == 0 then 0 else spin(k - 1)\n"
         "fn ask(c : Address(Msg)) : Int with m = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn askUntil(c : Address(Msg)) : Int with m =\n"
         "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> askUntil(c)\n"
         "    }\n"
         "fn peekUntil(c : Address(Msg)) : Int with m =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn reportOf(c : Address(Msg)) : Unit with Process.FaultReport = {\n"
         "    let child = Process.fromAddress(c);\n"
         "    receive { Process.FaultReport(process = p, site = _, cause = _, restarted = _,\n"
         "                                  trace = _) when p == child -> Unit }\n"
         "}\n"
         "foreign fn running(process : Process) : Foreign.Term with m = \"ern_waits:running/1\"\n"
         "foreign fn delivered(process : Process) : Foreign.Term with m =\n"
         "    \"ern_waits:delivered/1\"\n"]).

%% Appendix E.22: a sibling asked to restart that faults of its own before
%% it takes the restart has restarted by its fault, and the child that
%% waited for it runs again. RestForOne, so that the sibling's fault asks
%% nothing of the child. A regression test: the sibling's fault emptied
%% the ask with its mailbox, and the child waited for ever
sibling_faulting_first_counts_as_restarted_test() ->
    {ok, Output} = crunching(
        "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.RestForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(b, Crash);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    reportOf(a);\n"
        "    Io.println(Int.toString(peekUntil(a)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Output).

%% Appendix E.22: a child that waits for its fault to be counted when its
%% supervisor restarts in place is restarted as asked, and reports no fault
%% of its own. A regression test: its call to the supervisor ended as the
%% supervisor restarted, and it faulted with `callee was restarted`. The
%% reports are read once every child has answered and every delivery
%% started to main has ended; a report the runtime had not yet started then
%% is not seen
child_waits_through_its_supervisors_restart_test() ->
    {ok, Output} = crunching(
        "let top : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 5, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(x);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(b, Crunch);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    reportOf(a);\n"
        "    send(x, Boom);\n"
        "    reportOf(x);\n"
        "    let _ = askUntil(b); let _ = askUntil(a); let _ = askUntil(x);\n"
        "    let _ = delivered(Process.fromAddress(self()));\n"
        "    let faults = [\"division by zero\", \"division by zero\"] <> causes([]);\n"
        "    Io.println(String.join(faults, \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) with Process.FaultReport = receive {\n"
        "    f -> causes(seen <> [f.cause])\n"
        "  | after 0 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero\n">>, Output).

%% Appendix E.22: a child at whose fault a nested group gave up runs its
%% function once when the group, restarted in place, restarts it. A
%% regression test: the watcher let it go on before the supervisor asked
%% it to restart, and it ran its function twice. The starts are counted
%% once the child answers; one sent to the log and not yet taken then is
%% not seen
held_child_runs_once_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Count(reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0))\n"
        "fn logging(n : Int) : Unit with LogMsg = receive {\n"
        "    Started -> logging(n + 1)\n"
        "  | Count(reply = r) -> { answer(r, n); logging(n) }\n"
        "}\n"
        "let top : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = {\n"
        "    send(log, Started);\n"
        "    count(0)\n"
        "}))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn askUntil(c : Address(Msg)) : Int with m =\n"
        "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> askUntil(c)\n"
        "    }\n"
        "export fn main() : Unit with Process.FaultReport = {\n"
        "    let _ = askUntil(a);\n"
        "    Process.faults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    // the child's fault, and the nested group's at its limit\n"
        "    receive { _ -> Unit };\n"
        "    receive { _ -> Unit };\n"
        "    let _ = askUntil(a);\n"
        "    Io.println(Int.toString(Address.callForever(log, fn(r) = Count(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Output).

%% Appendix E.22: a supervisor that its parent restarts asks its own
%% children to restart, so a subtree restarts with its root. A regression
%% test for a supervisor restarted in place that left its children
%% running. The log tells main of each start of the child, and a child
%% never restarted leaves main in a deadlock
parent_restarts_subtree_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.Msg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 5, within = 5000))))\n"
        "type LogMsg = Started | Watch(watcher : Address(Unit), reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0, None))\n"
        "fn logging(n : Int, watcher : Optional(Address(Unit))) : Unit with LogMsg = receive {\n"
        "    Started -> {\n"
        "        match watcher { Some(w) -> send(w, Unit) | None -> Unit };\n"
        "        logging(n + 1, watcher)\n"
        "    }\n"
        "  | Watch(watcher = w, reply = r) -> { answer(r, n); logging(n, Some(w)) }\n"
        "}\n"
        "fn starts(seen : Int, least : Int) : Int with Unit =\n"
        "    if seen >= least then seen else receive { _ -> starts(seen + 1, least) }\n"
        "fn watched() : Int with Unit = {\n"
        "    let me = self();\n"
        "    Address.callForever(log, fn(r) = Watch(watcher = me, reply = r))\n"
        "}\n"
        "let c : Address(Msg) = spawn(Supervisor.child(sub, fn() = {\n"
        "    send(log, Started);\n"
        "    count(0)\n"
        "}))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(a : Address(Msg)) : Int with m = Address.callForever(a, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit with Unit = {\n"
        "    let _ = ask(c); let _ = ask(c);\n"
        "    let seen = watched();\n"
        "    send(x, Boom);\n"
        "    let _ = starts(seen, seen + 1);\n"
        "    Io.println(Int.toString(ask(c)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Output).

%% report §6.9: a restart asked for runs the child's own function again,
%% even where that function runs a restarting function of its own. A
%% regression test for the inner function taking the restart. The fault
%% is sent once the log has told main of the child's first start, since a
%% child that has not begun when its sibling faults is not asked, and
%% starts fresh; a child whose outer function never runs again leaves main
%% in a deadlock
restart_reaches_the_outer_function_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Watch(watcher : Address(Unit), reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0, None))\n"
        "fn logging(n : Int, watcher : Optional(Address(Unit))) : Unit with LogMsg = receive {\n"
        "    Started -> {\n"
        "        match watcher { Some(w) -> send(w, Unit) | None -> Unit };\n"
        "        logging(n + 1, watcher)\n"
        "    }\n"
        "  | Watch(watcher = w, reply = r) -> { answer(r, n); logging(n, Some(w)) }\n"
        "}\n"
        "fn starts(seen : Int, least : Int) : Int with Unit =\n"
        "    if seen >= least then seen else receive { _ -> starts(seen + 1, least) }\n"
        "fn watched() : Int with Unit = {\n"
        "    let me = self();\n"
        "    Address.callForever(log, fn(r) = Watch(watcher = me, reply = r))\n"
        "}\n"
        "let sup : Address(Supervisor.Msg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = {\n"
        "    send(log, Started);\n"
        "    restarting(RestartLimit(restarts = 5, within = 5000), fn() = count(0))()\n"
        "}))\n"
        "fn count(n : Int) : Unit with Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "export fn main() : Unit with Unit = {\n"
        "    let first = starts(watched(), 1);\n"
        "    send(a, Boom);\n"
        "    Io.println(Int.toString(starts(first, 2)))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Output).

%% Appendix E.22, report §6.9: a child's fault is counted by its supervisor
%% before the child runs again, so a limit of two restarts lets the child
%% run three times; and under `Unlimited` the supervisor never gives up. A
%% regression test: the child restarted itself and told the supervisor
%% after, running about two hundred times under a limit of two, and a time
%% of 0, which set no limit then, still gave up
supervisor_counts_before_the_restart_test_() ->
    {timeout, 60, fun supervisor_counts_before_the_restart/0}.

supervisor_counts_before_the_restart() ->
    Program = fun(Limit) ->
        "type CounterMsg = Next(reply : Reply(Int))\n"
        "type MainMsg = SupDied(Down) | ChildEnded(Down)\n"
        "fn counter(n : Int) : Unit with CounterMsg =\n"
        "    receive { Next(reply = r) -> { answer(r, n); counter(n + 1) } }\n"
        "fn crash(c : Address(CounterMsg)) : Unit with Int = {\n"
        "    let n = Address.callForever(c, fn(r) = Next(reply = r));\n"
        "    Io.println(\"run \" <> Int.toString(n));\n"
        "    if n < 6 then fault(\"boom\") else Unit\n"
        "}\n"
        "export fn main() : Unit with MainMsg = {\n"
        "    let c = spawn(fn() = counter(1));\n"
        "    let limit = " ++ Limit ++ ";\n"
        "    let sup = spawnMonitored(Supervisor.group(Supervisor.OneForOne, limit),\n"
        "                             SupDied);\n"
        "    let _ = spawnMonitored(Supervisor.child(sup, fn() = crash(c)), ChildEnded);\n"
        "    receive {\n"
        "        SupDied(Down(reason = Fault(cause), site = _)) -> Io.println(cause)\n"
        "      | SupDied(_) -> Io.println(\"supervisor ended\")\n"
        "      | ChildEnded(_) -> Io.println(\"kept\")\n"
        "    }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nsupervisor restart limit reached\n">>},
                 ern_emitter_tests:run(Program("RestartLimit(restarts = 2, within = 60000)"))),
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nrun 4\nrun 5\nrun 6\nkept\n">>},
                 ern_emitter_tests:run(Program("Unlimited"))).

%% Appendix E.22: the child whose fault restarts its siblings runs again
%% once each of them has restarted, so that a call to it after its fault is
%% answered by the group restarted whole. The sibling computes when the
%% fault comes, until the faulted child is held for its restart, and takes
%% its restart at its next wait. A regression test: the
%% faulted child ran again at once, and a call to the sibling made after it
%% had answered was still waiting when the sibling restarted, and ended
supervisor_restarts_whole_test_() ->
    {timeout, 30, fun supervisor_restarts_whole/0}.

supervisor_restarts_whole() ->
    {ok, Output} = ern_emitter_tests:run(
        "type AMsg = Crash | Ping(reply : Reply(Int))\n"
        "type BMsg = Inc | Busy(Process) | Count(reply : Reply(Int))\n"
        "fn a() : Unit with AMsg =\n"
        "    receive { Crash -> fault(\"crash\") | Ping(reply = r) -> { answer(r, 1); a() } }\n"
        "fn b(n : Int) : Unit with BMsg =\n"
        "    receive {\n"
        "        Inc -> b(n + 1)\n"
        "      | Busy(faulted) -> { spin(faulted); b(n) }\n"
        "      | Count(reply = r) -> { answer(r, n); b(n) }\n"
        "    }\n"
        "fn spin(faulted : Process) : Unit with m = match Process.info(faulted) {\n"
        "    Some(Process.Info(site = _, queued = _, activity = Process.Calling)) -> Unit\n"
        "  | _ -> spin(faulted)\n"
        "}\n"
        "fn ping(x : Address(AMsg)) : Int with m =\n"
        "    match Address.call(x, fn(r) = Ping(reply = r), 1000) {\n"
        "        Some(v) -> v\n"
        "      | None -> ping(x)\n"
        "    }\n"
        "export fn main() : Unit with Never = {\n"
        "    let limit = RestartLimit(restarts = 3, within = 60000);\n"
        "    let sup = spawn(Supervisor.group(Supervisor.OneForAll, limit));\n"
        "    let x = spawn(Supervisor.child(sup, a));\n"
        "    let y = spawn(Supervisor.child(sup, fn() = b(0)));\n"
        "    send(y, Inc);\n"
        "    let _ = Address.callForever(y, fn(r) = Count(reply = r));\n"
        "    let _ = ping(x);\n"
        "    send(y, Busy(Process.fromAddress(x)));\n"
        "    send(x, Crash);\n"
        "    let _ = ping(x);\n"
        "    Io.println(Io.show(Address.call(y, fn(r) = Count(reply = r), 2000)))\n"
        "}\n"),
    ?assertEqual(<<"Some(0)\n">>, Output).
