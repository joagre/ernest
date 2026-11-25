%% Report §6.9 and Appendix E.22: a supervisor's group, in programs run as
%% the runner runs them (ern_program:run/3).
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
%%
%% `delivered` waits until every delivery the runtime has started to main
%% has ended and every fault report the runtime has made has reached main.
%% A report comes through the subscription's own process, apart from the
%% deliveries (Appendix E.21), so a wait on the deliveries alone would not
%% find a report that is still on its way.
supervised(Strategy, Limit, Names, Main) ->
    ern_program:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom\n"
         "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.",
         Strategy, ", ", Limit, "))\n",
         [["let ", Name, " : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"]
          || Name <- Names],
         "fn count(n : Int) : Unit receiving Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn ask(c : Address(Msg)) : Int = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn askUntil(c : Address(Msg)) : Int =\n"
         "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> askUntil(c)\n"
         "    }\n"
         "fn peekUntil(c : Address(Msg)) : Int =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn show(c : Address(Msg)) : String = Int.toString(peekUntil(c))\n"
         "fn faulted() : Unit receiving Process.FaultReport = receive { _ -> Unit }\n"
         "foreign fn delivered() : Foreign.Term = \"ern_rt:wait_for_deliveries/0\"\n",
         Main]).

%% report §6.9, Appendix E.22: under OneForAll a fault restarts every
%% sibling in place, at its next wait, its address kept
one_for_all_restarts_siblings_test() ->
    {ok, Output} = supervised("OneForAll", ?LIMIT, ["a", "b"],
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 0\n">>, Output).

%% Appendix E.22: under OneForOne a fault restarts only the child that
%% faulted
one_for_one_restarts_the_child_alone_test() ->
    {ok, Output} = supervised("OneForOne", ?LIMIT, ["a", "b"],
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    Io.println(show(a) <> \" \" <> show(b))\n"
        "}\n"),
    ?assertEqual(<<"0 1\n">>, Output).

%% Appendix E.22: under RestForOne a fault restarts the children spawned
%% after the one that faulted, and not those before it
rest_for_one_restarts_later_children_test() ->
    {ok, Output} = supervised("RestForOne", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
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
    {ok, Output} = ern_program:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom | Go\n"
         "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group("
         "Supervisor.RestForOne, ", ?LIMIT, "))\n"
         "let a : Address(Msg) = spawn(fn() : Unit receiving Msg = {\n"
         "    receive { Go -> Unit };\n"
         "    Supervisor.child(sup, fn() = count(0))()\n"
         "})\n"
         "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
         "let c : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
         "fn count(n : Int) : Unit receiving Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn ask(c : Address(Msg)) : Int ="
         " Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn peekUntil(c : Address(Msg)) : Int =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn show(c : Address(Msg)) : String = Int.toString(peekUntil(c))\n"
         "export fn main() : Unit receiving Process.FaultReport = {\n"
         "    let _ = ask(b); let _ = ask(c);\n"
         "    send(a, Go);\n"
         "    let _ = ask(a);\n"
         "    Process.subscribeFaults(fn(f) = f);\n"
         "    send(a, Boom);\n"
         "    receive { _ -> Unit };\n"
         "    Io.println(show(a) <> \" \" <> show(b) <> \" \" <> show(c))\n"
         "}\n"]),
    ?assertEqual(<<"0 0 0\n">>, Output).

%% report §6.9, Appendix E.22: a restart asked for is no fault, and no
%% fault is reported for it; only the child that faulted is. The reports
%% are counted once the siblings have restarted and every report the
%% runtime has made by then has reached main; a report the runtime had not
%% yet made then is not seen
restart_asked_for_is_no_fault_test() ->
    {ok, Output} = supervised("OneForAll", ?LIMIT, ["a", "b", "c"],
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    faulted();\n"
        "    let _ = askUntil(a); let _ = askUntil(b); let _ = askUntil(c);\n"
        "    let _ = delivered();\n"
        "    Io.println(Int.toString(reports(1)))\n"
        "}\n"
        "fn reports(n : Int) : Int receiving Process.FaultReport ="
        " receive { _ -> reports(n + 1) | after 0 -> n }\n"),
    ?assertEqual(<<"1\n">>, Output).

%% report §6.6, §6.9, Appendix E.22: a call waiting on a child when its
%% supervisor restarts it ends, and callForever faults with the cause that
%% says so; the child restarts at the wait inside its handling of the
%% request, where it tells the trigger to make its sibling fault
call_ends_at_asked_restart_test() ->
    {Result, _} = ern_program:run(
             "type Msg = Slow(reply : Reply(Int), trigger : Address(Unit)) | Boom\n"
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = serve()))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = serve()))\n"
        "fn serve() : Unit receiving Msg = receive {\n"
        "    Slow(reply = r, =trigger) -> {\n"
        "        send(trigger, Unit);\n"
        "        receive { Boom -> Unit };\n"
        "        answer(r, 1);\n"
        "        serve()\n"
        "    }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    let trigger = spawn(fn() : Unit receiving Unit = receive { _ -> send(a, Boom) });\n"
        "    let _ = Address.callForever(b, fn(r) = Slow(reply = r, =trigger));\n"
        "    Io.println(\"answered\")\n"
        "}\n"),
    ?assertMatch({fault, <<"callee was restarted">>, _}, Result).

%% Appendix E.22: past its limit a group faults; at the root it dies, and
%% its watcher kills its children
limit_ends_the_group_test() ->
    {ok, Output} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)", ["a"],
        "type Seen = Died(Down) | Faulted(Process.FaultReport)\n"
        "export fn main() : Unit receiving Seen = {\n"
        "    monitor(Process.fromAddress(a), Died);\n"
        "    Process.subscribeFaults(Faulted);\n"
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

%% Appendix E.22: kill(Process.fromAddress(sup)) stops the group, the
%% children killed in the reverse of the order they were spawned, each once
%% the one before has ended. So at a child's Down each child spawned after
%% it has ended, which the test reads at each of the three; the Downs
%% themselves come in no order (report §6.9)
kill_stops_in_reverse_order_test() ->
    {ok, Output} = supervised("OneForOne", ?LIMIT, ["a", "b", "c"],
        "type Seen = Died(String)\n"
        "export fn main() : Unit receiving Seen = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitor(Process.fromAddress(a), fn(_) = Died(\"a\"));\n"
        "    monitor(Process.fromAddress(b), fn(_) = Died(\"b\"));\n"
        "    monitor(Process.fromAddress(c), fn(_) = Died(\"c\"));\n"
        "    kill(Process.fromAddress(sup));\n"
        "    Io.println(String.join(List.sort([next(), next(), next()]), \" \"))\n"
        "}\n"
        "fn next() : String receiving Seen =\n"
        "    receive {\n"
        "        Died(name) -> name <> \":\" <> Io.show(List.all(spawnedAfter(name), ended))\n"
        "    }\n"
        "fn spawnedAfter(name : String) : List(Address(Msg)) =\n"
        "    if name == \"a\" then [b, c] else if name == \"b\" then [c] else []\n"
        "fn ended(child : Address(Msg)) : Bool =\n"
        "    Optional.isNone(Process.status(Process.fromAddress(child)))\n"),
    ?assertEqual(<<"a:true b:true c:true\n">>, Output).

%% Appendix E.22, §6.9: a supervisor that is a child restarts in place past
%% its limit, its children restarted with it, their addresses kept. `a`,
%% at whose fault the group gave up, restarts once, after its fault, and is
%% not asked again; `b` restarts once, as the nested group asks. A service
%% monitor is told of each restart before anything the new run takes, so
%% `a`'s Restarted is heard before `a` is called, and the call reaches its
%% new run. `a` runs again only once `b` has restarted, so once both have
%% answered every Restarted there is to hear is in main's mailbox, and a
%% third, of `a` asked again, would be read there
nested_group_restarts_in_place_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit receiving Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(c : Address(Msg)) : Int = Address.callForever(c, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit receiving Down = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    monitorService(Process.fromAddress(a), fn(d) = d);\n"
        "    monitorService(Process.fromAddress(b), fn(d) = d);\n"
        "    send(a, Boom);\n"
        "    // a's restart after its fault\n"
        "    let first = heard();\n"
        "    let counts = Int.toString(peek(a)) <> \" \" <> Int.toString(peek(b));\n"
        "    Io.println(Io.show(first :: heardSince([])) <> \" \" <> counts)\n"
        "}\n"
        "fn heard() : Reason receiving Down = receive { Down(=reason) -> reason }\n"
        "fn heardSince(seen : List(Reason)) : List(Reason) receiving Down = receive {\n"
        "    Down(=reason) -> heardSince(seen <> [reason])\n"
        "  | after 0 -> seen\n"
        "}\n"
        "fn peek(c : Address(Msg)) : Int = Address.callForever(c, fn(r) = Peek(reply = r))\n"),
    ?assertEqual(<<"[Restarted, Restarted] 0 0\n">>, Output).

%% Appendix E.22: a supervisor restarted in place counts its limit afresh,
%% and a fault it counted before the restart does not expire from the new
%% count. A regression test for alarms of an earlier run lowering the
%% count.
%%
%% The nested group counts the child's first fault and gives up at its
%% second. Once the alarm its earlier run set for the first is due,
%% twice over, the new run counts two faults one straight after the other,
%% and gives up at the second, which its own report says. An earlier run's
%% alarm that lowered the count would leave the second under the limit,
%% and the run would end in a deadlock (report §8.6). The one time the test
%% reads is the limit's window, which the test is about; every other wait
%% is for a fault's report or the child's answer.
%%
%% The new run must not give up at the first of the two, as a run that kept
%% the earlier count would. The child runs again only once the group has
%% counted its fault, and where the group gave up, only once the group has
%% restarted in place after its own fault (Appendix E.22). So once the child
%% has answered and every report the runtime has made has reached main, a
%% report of the group's is there if it gave up, and main says so instead.
%% Each report is read by the process that made it, so that the child's
%% cannot be taken for the group's.
%%
%% The test has one child and reads the group's report. That the group
%% restarted in place restarts its other children before the child runs
%% again is nested_group_restarts_in_place_test's and
%% held_child_waits_for_its_siblings_test's.
count_survives_restart_in_place_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 1, within = 1000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "fn count(n : Int) : Unit receiving Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn reportOf(process : Process) : Process.FaultReport receiving Process.FaultReport =\n"
        "    receive { f when f.process == process -> f }\n"
        "fn reportedBy(process : Process) : Bool receiving Process.FaultReport = receive {\n"
        "    f when f.process == process -> true\n"
        "  | after 0 -> false\n"
        "}\n"
        "foreign fn delivered() : Foreign.Term = \"ern_rt:wait_for_deliveries/0\"\n"
        "fn waitUntil(time : Int) : Unit =\n"
        "    Clock.sleep(Int.max(0, time - Clock.monotonic()))\n"
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let within = 1000;\n"
        "    let child = Process.fromAddress(a);\n"
        "    let nested = Process.fromAddress(sub);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(a, Boom);\n"
        "    let _ = reportOf(child);\n"
        "    // the child runs again once the group has counted its fault and\n"
        "    // set the alarm that expires it, and before each next fault, since\n"
        "    // its restart empties its mailbox (report §6.9)\n"
        "    let _ = askUntil(a);\n"
        "    let counted = Clock.monotonic();\n"
        "    send(a, Boom);\n"
        "    // the child's fault, and the group's at its limit\n"
        "    let _ = reportOf(child);\n"
        "    let _ = reportOf(nested);\n"
        "    let _ = askUntil(a);\n"
        "    // the earlier run's alarm for the first fault\n"
        "    waitUntil(counted + 2 * within);\n"
        "    send(a, Boom);\n"
        "    let _ = reportOf(child);\n"
        "    let _ = askUntil(a);\n"
        "    let _ = delivered();\n"
        "    if reportedBy(nested) then\n"
        "        Io.println(\"the group gave up at the first fault of its new run\")\n"
        "    else {\n"
        "        send(a, Boom);\n"
        "        Io.println(reportOf(nested).cause)\n"
        "    }\n"
        "}\n"
        "fn askUntil(c : Address(Msg)) : Int =\n"
        "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> askUntil(c)\n"
        "    }\n"),
    ?assertEqual(<<"supervisor restart limit reached\n">>, Output).

%% Appendix E.22: a child that starts after its supervisor has ended
%% faults once with a cause that says so, and does not restart. A
%% regression test for a child that joined inside its restart loop and
%% restarted without end
child_of_ended_supervisor_test() ->
    {Result, _} = ern_program:run(
             "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 3, within = 5000)))\n"
        "type Seen = Ended(Down)\n"
        "export fn main() : Unit receiving Seen = {\n"
        "    monitor(Process.fromAddress(sup), Ended);\n"
        "    kill(Process.fromAddress(sup));\n"
        "    receive { Ended(_) -> Unit };\n"
        "    let c = Supervisor.child(sup, fn() : Unit receiving Seen = Unit);\n"
        "    c()\n"
        "}\n"),
    ?assertMatch({fault, <<"the supervisor has ended">>, _}, Result).

%% Appendix E.22: a child's function run where a restarting function already
%% runs in its process faults, inside another child's as inside a plain
%% `restarting`, since it would read that function's start cause in place of
%% its own. Regression tests, written after the code: the inner function
%% read the outer's cause, and its group counted a fault that had not
%% happened, or none that had
child_inside_a_child_faults_test() ->
    ?assertEqual(<<"a child's function runs in no restarting function\n">>,
                 first_fault_cause("Supervisor.child(sup, fn() ="
                                   " Supervisor.child(sup, fn() = Unit)())")).

child_inside_restarting_faults_test() ->
    ?assertEqual(<<"a child's function runs in no restarting function\n">>,
                 first_fault_cause("restarting(RestartLimit(restarts = 1, within = 5000),"
                                   " Supervisor.child(sup, fn() = Unit))")).

%% The cause of the first fault of a program that spawns Spawned, a function
%% of no message, beside a group of its own.
first_fault_cause(Spawned) ->
    {ok, Output} = ern_program:run(
        ["let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne, ",
         ?LIMIT, "))\n"
         "export fn main() : Unit receiving Process.FaultReport = {\n"
         "    Process.subscribeFaults(fn(report) = report);\n"
         "    let _ = spawn(", Spawned, ");\n"
         "    receive { report -> Io.println(report.cause) }\n"
         "}\n"]),
    Output.

%% report §6.9, Appendix E.22: a root group past its limit faults, and its
%% children are killed; none reports a fault it did not have. A regression
%% test for children that, asked to restart, rejoined the dead supervisor
%% and reported that as their own fault. The reports are read once the
%% children have ended and every report the runtime has made by then has
%% reached main, since the reports come through the subscription's own
%% process and their `Down`s from the runtime, with no order between them
%% (report §6.4, §6.9, Appendix E.21); a report the runtime had not yet
%% made then is not seen
limit_reports_only_real_faults_test() ->
    {ok, Output} = supervised("OneForOne", "RestartLimit(restarts = 1, within = 5000)",
        ["a", "b", "c"],
        "type Seen = Report(Process.FaultReport) | Ended(Down)\n"
        "export fn main() : Unit receiving Seen = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitor(Process.fromAddress(sup), Ended);\n"
        "    List.forEach([a, b, c], fn(child) = monitor(Process.fromAddress(child), Ended));\n"
        "    Process.subscribeFaults(Report);\n"
        "    send(a, Boom);\n"
        "    receive { Report(_) -> Unit };\n"
        "    let _ = askUntil(a);\n"
        "    send(a, Boom);\n"
        "    let _ = List.map([1, 2, 3, 4], fn(_) = receive { Ended(_) -> Unit });\n"
        "    let _ = delivered();\n"
        "    Io.println(String.join([\"division by zero\"] <> causes([]), \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) receiving Seen = receive {\n"
        "    Report(f) -> causes(seen <> [f.cause])\n"
        "  | after 0 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero; supervisor restart limit reached\n">>,
                 Output).

%% Appendix E.22: one process runs a group's function, and a second that
%% runs it faults, since the process that keeps the group's children is
%% the function's. Written with the rule (report §6.9's emptied mailbox)
group_runs_in_one_process_test() ->
    {ok, Output} = ern_program:run(
        "type MainMsg = Died(Down)\n"
        "export fn main() : Unit receiving MainMsg = {\n"
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
    {ok, Output} = ern_program:run(
        "type MainMsg = Died(Down)\n"
        "foreign fn waiting(process : Process) : Foreign.Term = \"ern_waits:waiting/1\"\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let g = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let first = spawn(g);\n"
        "    // it runs the group, and waits in it\n"
        "    let _ = waiting(Process.fromAddress(first));\n"
        "    monitor(Process.fromAddress(first), Died);\n"
        "    kill(Process.fromAddress(first));\n"
        "    receive { Died(_) -> Unit };\n"
        "    let _ = spawnMonitored(g, Died);\n"
        "    receive { Died(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"Fault(\"a group runs in one process\")\n">>, Output).

%% Appendix E.22: where no process runs the function `group` answers, the
%% process that keeps the group's children waits, `Process.live` listing
%% it, and the program ends while it waits. Written with the sentence,
%% after the code
group_no_process_runs_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn waiting(process : Process) : Foreign.Term = \"ern_waits:waiting/1\"\n"
        "export fn main() : Unit = {\n"
        "    let before = Process.live();\n"
        "    let _ = Supervisor.group(Supervisor.OneForOne, Unlimited);\n"
        "    let kept =\n"
        "        List.filter(Process.live(), fn(process) = !List.contains(before, process));\n"
        "    let _ = List.map(kept, waiting);\n"
        "    let described = List.map(kept, fn(process) = Optional.map(Process.status(process),\n"
        "        fn(status) = #(String.startsWith(status.site, \"Supervisor.group:\"),\n"
        "                       status.activity)));\n"
        "    Io.println(Io.show(described))\n"
        "}\n"),
    ?assertEqual(<<"[Some(#(true, Process.Receiving))]\n">>, Output).

%% A group whose children count, fault on Boom, and on Crunch compute for a
%% while without waiting, so that a restart asked of one then waits; on
%% Crash they compute a fifth as long and then fault. `running` waits until
%% a child computes, `calling` until it waits for a call's answer,
%% `reportOf` for a child's fault's report, and `askUntil` asks again where
%% a restart ended the call, as `peekUntil` reads a count. `delivered`
%% waits as supervised/4's does. `restartSeen` reads, without waiting, the
%% Restarted of a child main watches with a service monitor, which is
%% placed before the child's new run begins (report §6.9).
%%
%% `suspend` and `resume` hold a process and let it go, by the host's
%% suspension, which runs it no more until it is resumed and keeps what is
%% sent to it in its mailbox; `queued` waits until a process's mailbox
%% holds a count of messages, a suspended one's among them.
crunching(Main) ->
    ern_program:run(
        ["type Msg = Ask(reply : Reply(Int)) | Peek(reply : Reply(Int)) | Boom | Crunch | Crash\n",
         Main,
         "fn count(n : Int) : Unit receiving Msg = receive {\n"
         "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
         "  | Peek(reply = r) -> { answer(r, n); count(n) }\n"
         "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
         "  | Crunch -> { let _ = spin(50000000); count(n) }\n"
         "  | Crash -> { let z = spin(10000000); let _ = 1 / z; Unit }\n"
         "}\n"
         "fn spin(k : Int) : Int = if k == 0 then 0 else spin(k - 1)\n"
         "fn ask(c : Address(Msg)) : Int = Address.callForever(c, fn(r) = Ask(reply = r))\n"
         "fn askUntil(c : Address(Msg)) : Int =\n"
         "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> askUntil(c)\n"
         "    }\n"
         "fn peekUntil(c : Address(Msg)) : Int =\n"
         "    match Address.call(c, fn(r) = Peek(reply = r), 1000) {\n"
         "        Some(n) -> n\n"
         "      | None -> peekUntil(c)\n"
         "    }\n"
         "fn reportOf(c : Address(Msg)) : Unit receiving Process.FaultReport = {\n"
         "    let child = Process.fromAddress(c);\n"
         "    receive { Process.FaultReport(process = p, site = _, cause = _, restarted = _,\n"
         "                                  trace = _, spawnedBy = _) when p == child -> Unit }\n"
         "}\n"
         "fn restartSeen() : String receiving Down =\n"
         "    receive { Down(=reason) -> Io.show(reason) | after 0 -> \"not restarted\" }\n"
         "foreign fn running(process : Process) : Foreign.Term = \"ern_waits:running/1\"\n"
         "foreign fn calling(process : Process) : Foreign.Term = \"ern_waits:calling/1\"\n"
         "foreign fn queued(process : Process, count : Int) : Foreign.Term ="
         " \"ern_waits:queued/2\"\n"
         "foreign fn suspend(process : Process) : Foreign.Term = \"erlang:suspend_process/1\"\n"
         "foreign fn resume(process : Process) : Foreign.Term = \"erlang:resume_process/1\"\n"
         "foreign fn delivered() : Foreign.Term = \"ern_rt:wait_for_deliveries/0\"\n"]).

%% Appendix E.22: a sibling asked to restart that faults of its own before
%% it takes the restart has restarted by its fault, and the child that
%% waited for it runs again. RestForOne, so that the sibling's fault
%% restarts no other child; it would not ask the child under another
%% strategy either, since the child waits to run again
%% (child_waits_through_a_siblings_fault_test). A regression test: the
%% sibling's fault emptied the ask with its mailbox, and the child waited
%% for ever
sibling_faulting_first_counts_as_restarted_test() ->
    {ok, Output} = crunching(
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.RestForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(b, Crash);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    reportOf(a);\n"
        "    Io.println(Int.toString(peekUntil(a)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Output).

%% Appendix E.22: a child that waits to run again when its supervisor
%% restarts in place waits on through the restart, and reports no fault of
%% its own. A regression test: its call to the supervisor ended as the
%% supervisor restarted, and it faulted with `callee was restarted`. The
%% reports are read once every child has answered and every report the
%% runtime has made by then has reached main; a report the runtime had not
%% yet made then is not seen
child_waits_through_its_supervisors_restart_test() ->
    {ok, Output} = crunching(
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 5, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(x);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
        "    send(b, Crunch);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    reportOf(a);\n"
        "    send(x, Boom);\n"
        "    reportOf(x);\n"
        "    let _ = askUntil(b); let _ = askUntil(a); let _ = askUntil(x);\n"
        "    let _ = delivered();\n"
        "    let faults = [\"division by zero\", \"division by zero\"] <> causes([]);\n"
        "    Io.println(String.join(faults, \"; \"))\n"
        "}\n"
        "fn causes(seen : List(String)) : List(String) receiving Process.FaultReport = receive {\n"
        "    f -> causes(seen <> [f.cause])\n"
        "  | after 0 -> seen\n"
        "}\n"),
    ?assertEqual(<<"division by zero; division by zero\n">>, Output).

%% Appendix E.22: a child at whose fault a nested group gave up runs again,
%% once the group is restarted in place, only once each other child has
%% restarted or ended. Its sibling computes as the group gives up, and takes
%% its restart at its next wait (report §6.9). Main watches the sibling with
%% a service monitor, whose Restarted is placed before the sibling's new run
%% begins, so it is in main's mailbox by the time the child answers. Written
%% before the code: the group restarted in place let the child go as it
%% asked the others, and the child answered while its sibling's old run
%% computed
held_child_waits_for_its_siblings_test() ->
    {ok, Output} = crunching(
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "export fn main() : Unit receiving Down = {\n"
        "    let _ = ask(a); let _ = ask(b);\n"
        "    monitorService(Process.fromAddress(b), fn(d) = d);\n"
        "    send(b, Crunch);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    Io.println(Int.toString(peekUntil(a)) <> \" \" <> restartSeen())\n"
        "}\n"),
    ?assertEqual(<<"0 Restarted\n">>, Output).

%% Appendix E.22: a child that waits for a computing sibling waits on
%% through the fault of another sibling, which faults before it takes the
%% restart its fault asked of it. That sibling's fault does not ask the
%% child, which waits, and the child runs again only once the computing
%% sibling has restarted, which main reads as the test before does. Written
%% before the code: the second fault asked the waiting child, which took
%% the restart at its wait and ran again at once
child_waits_through_a_siblings_fault_test() ->
    {ok, Output} = crunching(
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let c : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "export fn main() : Unit receiving Down = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitorService(Process.fromAddress(c), fn(d) = d);\n"
        "    send(c, Crunch);\n"
        "    let _ = running(Process.fromAddress(c));\n"
        "    send(b, Crash);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    Io.println(Int.toString(peekUntil(a)) <> \" \" <> restartSeen())\n"
        "}\n"),
    ?assertEqual(<<"0 Restarted\n">>, Output).

%% Appendix E.22: a child asked to restart before its supervisor has
%% counted its own fault takes the restart, and waits as it would have.
%% Main holds the supervisor by the host's suspension while b and then a
%% fault, each waiting for its word, and lets it go once both questions
%% are in its mailbox. The watcher passes on b's before a faults, so the
%% supervisor takes b's fault first and asks a, whose fault it has not yet
%% counted. a runs again only once c, which computes, has restarted, which
%% main reads as the tests before do.
%%
%% A regression test, written after the code. Not covered: the second
%% Restarted a's service monitor would get, a call to a that the asked
%% restart ends, and the strategies but OneForAll
child_asked_before_its_fault_is_counted_waits_test() ->
    {ok, Output} = crunching(
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let c : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "export fn main() : Unit receiving Down = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(c);\n"
        "    monitorService(Process.fromAddress(c), fn(d) = d);\n"
        "    send(c, Crunch);\n"
        "    let _ = running(Process.fromAddress(c));\n"
        "    let supervisor = Process.fromAddress(sup);\n"
        "    let _ = suspend(supervisor);\n"
        "    send(b, Boom);\n"
        "    let _ = calling(Process.fromAddress(b));\n"
        "    let _ = queued(supervisor, 1);\n"
        "    send(a, Boom);\n"
        "    let _ = calling(Process.fromAddress(a));\n"
        "    let _ = queued(supervisor, 2);\n"
        "    let _ = resume(supervisor);\n"
        "    Io.println(Int.toString(peekUntil(a)) <> \" \" <> restartSeen())\n"
        "}\n"),
    ?assertEqual(<<"0 Restarted\n">>, Output).

%% Appendix E.22: a child that waits for a computing sibling waits on
%% through its supervisor's restart in place at its parent's ask, and runs
%% again only once the sibling has restarted, which main reads as the tests
%% before do. The parent asks as another of its children faults, once the
%% child waits for its supervisor's word. Written before the code: the
%% supervisor's new run asked the waiting child, which took the restart at
%% its wait and ran again at once
child_waits_through_its_supervisors_restart_at_its_parents_ask_test() ->
    {ok, Output} = crunching(
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 5, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sub, fn() = count(0)))\n"
        "export fn main() : Unit receiving Down = {\n"
        "    let _ = ask(a); let _ = ask(b); let _ = ask(x);\n"
        "    monitorService(Process.fromAddress(b), fn(d) = d);\n"
        "    send(b, Crunch);\n"
        "    let _ = running(Process.fromAddress(b));\n"
        "    send(a, Boom);\n"
        "    let _ = calling(Process.fromAddress(a));\n"
        "    send(x, Boom);\n"
        "    Io.println(Int.toString(peekUntil(a)) <> \" \" <> restartSeen())\n"
        "}\n"),
    ?assertEqual(<<"0 Restarted\n">>, Output).

%% Appendix E.22: a child at whose fault a nested group gave up runs its
%% function once more when the group restarts in place, which lets it go
%% and does not ask it to restart. A regression test: the watcher let it go
%% on before the supervisor asked it to restart, and it ran its function
%% twice. The starts are counted once the child answers; one sent to the
%% log and not yet taken then is not seen
held_child_runs_once_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Count(reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0))\n"
        "fn logging(n : Int) : Unit receiving LogMsg = receive {\n"
        "    Started -> logging(n + 1)\n"
        "  | Count(reply = r) -> { answer(r, n); logging(n) }\n"
        "}\n"
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForOne,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 0, within = 5000))))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sub, fn() = {\n"
        "    send(log, Started);\n"
        "    count(0)\n"
        "}))\n"
        "fn count(n : Int) : Unit receiving Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn askUntil(c : Address(Msg)) : Int =\n"
        "    match Address.call(c, fn(r) = Ask(reply = r), 1000) {\n"
        "        Some(n) -> n\n"
        "      | None -> askUntil(c)\n"
        "    }\n"
        "export fn main() : Unit receiving Process.FaultReport = {\n"
        "    let _ = askUntil(a);\n"
        "    Process.subscribeFaults(fn(f) = f);\n"
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
    {ok, Output} = ern_program:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "let top : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let x : Address(Msg) = spawn(Supervisor.child(top, fn() = count(0)))\n"
        "let sub : Address(Supervisor.GroupMsg) = spawn(Supervisor.child(top,"
        " Supervisor.group(Supervisor.OneForOne, RestartLimit(restarts = 5, within = 5000))))\n"
        "type LogMsg = Started | Watch(watcher : Address(Unit), reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0, None))\n"
        "fn logging(n : Int, watcher : Optional(Address(Unit))) : Unit receiving LogMsg ="
        " receive {\n"
        "    Started -> {\n"
        "        match watcher { Some(w) -> send(w, Unit) | None -> Unit };\n"
        "        logging(n + 1, watcher)\n"
        "    }\n"
        "  | Watch(watcher = w, reply = r) -> { answer(r, n); logging(n, Some(w)) }\n"
        "}\n"
        "fn starts(seen : Int, least : Int) : Int receiving Unit =\n"
        "    if seen >= least then seen else receive { _ -> starts(seen + 1, least) }\n"
        "fn watched() : Int receiving Unit = {\n"
        "    let me = self();\n"
        "    Address.callForever(log, fn(r) = Watch(watcher = me, reply = r))\n"
        "}\n"
        "let c : Address(Msg) = spawn(Supervisor.child(sub, fn() = {\n"
        "    send(log, Started);\n"
        "    count(0)\n"
        "}))\n"
        "fn count(n : Int) : Unit receiving Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "fn ask(a : Address(Msg)) : Int = Address.callForever(a, fn(r) = Ask(reply = r))\n"
        "export fn main() : Unit receiving Unit = {\n"
        "    let _ = ask(c); let _ = ask(c);\n"
        "    let seen = watched();\n"
        "    send(x, Boom);\n"
        "    let _ = starts(seen, seen + 1);\n"
        "    Io.println(Int.toString(ask(c)))\n"
        "}\n"),
    ?assertEqual(<<"0\n">>, Output).

%% report §6.9, Appendix E.22: a restart asked for runs the child's own
%% function again, even where that function runs a restarting function of
%% its own. A regression test for the inner function taking the restart.
%% The fault is sent once the log has told main of the child's first start,
%% since a child that has not begun when its sibling faults is not asked,
%% and starts fresh; a child whose outer function never runs again leaves
%% main in a deadlock
restart_reaches_the_outer_function_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ask(reply : Reply(Int)) | Boom\n"
        "type LogMsg = Started | Watch(watcher : Address(Unit), reply : Reply(Int))\n"
        "let log : Address(LogMsg) = spawn(fn() = logging(0, None))\n"
        "fn logging(n : Int, watcher : Optional(Address(Unit))) : Unit receiving LogMsg ="
        " receive {\n"
        "    Started -> {\n"
        "        match watcher { Some(w) -> send(w, Unit) | None -> Unit };\n"
        "        logging(n + 1, watcher)\n"
        "    }\n"
        "  | Watch(watcher = w, reply = r) -> { answer(r, n); logging(n, Some(w)) }\n"
        "}\n"
        "fn starts(seen : Int, least : Int) : Int receiving Unit =\n"
        "    if seen >= least then seen else receive { _ -> starts(seen + 1, least) }\n"
        "fn watched() : Int receiving Unit = {\n"
        "    let me = self();\n"
        "    Address.callForever(log, fn(r) = Watch(watcher = me, reply = r))\n"
        "}\n"
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,"
        " RestartLimit(restarts = 5, within = 5000)))\n"
        "let a : Address(Msg) = spawn(Supervisor.child(sup, fn() = count(0)))\n"
        "let b : Address(Msg) = spawn(Supervisor.child(sup, fn() = {\n"
        "    send(log, Started);\n"
        "    restarting(RestartLimit(restarts = 5, within = 5000), fn() = count(0))()\n"
        "}))\n"
        "fn count(n : Int) : Unit receiving Msg = receive {\n"
        "    Ask(reply = r) -> { answer(r, n); count(n + 1) }\n"
        "  | Boom -> { let z = List.size([]); let _ = 1 / z; Unit }\n"
        "}\n"
        "export fn main() : Unit receiving Unit = {\n"
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
%% of 0, which set no limit then, still gave up.
%%
%% Where the group gives up, its watcher kills the child, and the `Down`s
%% of two processes have no order (report §6.9), so main takes the child's
%% only where the child returned, as it does under `Unlimited`. A child that
%% ends otherwise leaves main waiting, and the run ends in a deadlock
%% (report §8.6) rather than with `kept`.
supervisor_counts_before_the_restart_test_() ->
    {timeout, 60, fun supervisor_counts_before_the_restart/0}.

supervisor_counts_before_the_restart() ->
    Program = fun(Limit) ->
        "type CounterMsg = Next(reply : Reply(Int))\n"
        "type MainMsg = SupDied(Down) | ChildEnded(Down)\n"
        "fn counter(n : Int) : Unit receiving CounterMsg =\n"
        "    receive { Next(reply = r) -> { answer(r, n); counter(n + 1) } }\n"
        "fn crash(c : Address(CounterMsg)) : Unit receiving Int = {\n"
        "    let n = Address.callForever(c, fn(r) = Next(reply = r));\n"
        "    Io.println(\"run \" <> Int.toString(n));\n"
        "    if n < 6 then fault(\"boom\") else Unit\n"
        "}\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let c = spawn(fn() = counter(1));\n"
        "    let limit = " ++ Limit ++ ";\n"
        "    let sup = spawnMonitored(Supervisor.group(Supervisor.OneForOne, limit),\n"
        "                             SupDied);\n"
        "    let _ = spawnMonitored(Supervisor.child(sup, fn() = crash(c)), ChildEnded);\n"
        "    receive {\n"
        "        SupDied(Down(reason = Fault(cause), site = _)) -> Io.println(cause)\n"
        "      | SupDied(_) -> Io.println(\"supervisor ended\")\n"
        "      | ChildEnded(Down(reason = Returned, site = _)) -> Io.println(\"kept\")\n"
        "    }\n"
        "}\n"
    end,
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nsupervisor restart limit reached\n">>},
                 ern_program:run(Program("RestartLimit(restarts = 2, within = 60000)"))),
    ?assertEqual({ok, <<"run 1\nrun 2\nrun 3\nrun 4\nrun 5\nrun 6\nkept\n">>},
                 ern_program:run(Program("Unlimited"))).

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
    {ok, Output} = ern_program:run(
        "type AMsg = Crash | Ping(reply : Reply(Int))\n"
        "type BMsg = Inc | Busy(Process) | Count(reply : Reply(Int))\n"
        "fn a() : Unit receiving AMsg =\n"
        "    receive { Crash -> fault(\"crash\") | Ping(reply = r) -> { answer(r, 1); a() } }\n"
        "fn b(n : Int) : Unit receiving BMsg =\n"
        "    receive {\n"
        "        Inc -> b(n + 1)\n"
        "      | Busy(faulted) -> { spin(faulted); b(n) }\n"
        "      | Count(reply = r) -> { answer(r, n); b(n) }\n"
        "    }\n"
        "fn spin(faulted : Process) : Unit = match Process.status(faulted) {\n"
        "    Some(Process.Status(site = _, queued = _, activity = Process.Calling())) -> Unit\n"
        "  | _ -> spin(faulted)\n"
        "}\n"
        "fn ping(x : Address(AMsg)) : Int =\n"
        "    match Address.call(x, fn(r) = Ping(reply = r), 1000) {\n"
        "        Some(v) -> v\n"
        "      | None -> ping(x)\n"
        "    }\n"
        "export fn main() : Unit = {\n"
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
