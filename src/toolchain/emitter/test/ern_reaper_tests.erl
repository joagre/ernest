%% Report §8.6: a program's end at a deadlock, which the runtime's reaper
%% finds, and the waits the reaper holds, in programs run as the runner
%% runs them (ern_emitter_tests:run/3).
-module(ern_reaper_tests).

-export([reaper_words/0, answered_later/0, called_back/1, called_back_in_tail/1, looks/1,
         looking/0, sent_later/2, answering_later/0, ending_later/0]).

-include_lib("eunit/include/eunit.hrl").

%% report §8.6, §7.4: a program whose every process waits forever ends
%% with the entry process's fault, `deadlock`; a timed receive is a source
%% and ends by itself. Report §7.3, Appendix E.21: the deadlock's trace is
%% the entry process's stack where the runtime finds it waiting, `main`'s
%% frame, a regression test written after the code, where it had none
deadlock_test() ->
    {Result1, _} = ern_emitter_tests:run(
        "type Msg = Ping\n"
        "export fn main() : Unit receiving Msg = receive { Ping -> Unit }\n"),
    ?assertEqual({fault, <<"deadlock">>, <<"M.main:2\n">>}, Result1),
    {Result2, Output} = ern_emitter_tests:run(
        "type Msg = Ping\n"
        "export fn main() : Unit receiving Msg = receive {\n"
        "    Ping -> Unit\n"
        "  | after 100 -> Io.println(\"timeout\")\n"
        "}\n"),
    ?assertEqual({ok, <<"timeout\n">>}, {Result2, Output}).

%% report §8.6, §8.4: a process inside foreign code is not waiting, since
%% the foreign side may still deliver to it; here the program's one process
%% waits in a receive of the host's, this module's, which answers once the
%% reaper has looked twice, and the program ends with the answer. A
%% process outside the program stands for what foreign code holds that
%% will deliver, a timer among it, which would need a time chosen. Not
%% covered: a foreign function that waits on a process of the program's
foreign_wait_is_no_deadlock_test() ->
    ?assertEqual({ok, <<"42\n">>}, ern_emitter_tests:run(
        "foreign fn answered() : Int = \"ern_reaper_tests:answered_later/0\"\n"
        "export fn main() : Unit = Io.println(Int.toString(answered()))\n")).

%% report §8.6, §8.4: a function given to foreign code runs inside it, so a
%% receive in it is no deadlock while foreign code holds what will deliver,
%% whether foreign code called it in tail position, which leaves no frame of
%% foreign code on the stack, or not
callback_inside_foreign_is_no_deadlock_test() ->
    Program = fun(Function) ->
                  "foreign fn called(f : () -> Int receiving Int) : Int receiving Int =\n"
                  "    \"ern_reaper_tests:" ++ Function ++ "/1\"\n"
                  "export fn main() : Unit receiving Int =\n"
                  "    Io.println(Int.toString(called(fn() : Int receiving Int = receive {\n"
                  "        n -> n\n"
                  "    })))\n"
              end,
    ?assertEqual({ok, <<"42\n">>}, ern_emitter_tests:run(Program("called_back"))),
    ?assertEqual({ok, <<"42\n">>}, ern_emitter_tests:run(Program("called_back_in_tail"))).

%% report §8.6, Appendix E.0 rule 1: a function the standard library is
%% given runs as Ernest code, so a receive in `Map.map`'s function with
%% nothing in flight is a deadlock, the host's `maps` frames beneath it
map_callback_deadlock_test() ->
    {Result, _} = ern_emitter_tests:run(
        "export fn main() : Unit receiving Int = {\n"
        "    let _ = Map.map(Map.fromList([#(1, 1)]), fn(k : Int, v : Int) : Int receiving Int =\n"
        "        receive { n -> n + k + v });\n"
        "    Unit\n"
        "}\n"),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% The foreign side of the tests above: 42 sent to the caller by a process
%% of its own once the reaper has looked twice, and waited for in a receive
%% of this module's, or in the function given, called in tail position or
%% not.
-spec answered_later() -> integer().
answered_later() ->
    later(),
    receive N when is_integer(N) -> N end.

-spec called_back(fun(() -> integer())) -> integer().
called_back(Function) ->
    later(),
    Function() + 0.

-spec called_back_in_tail(fun(() -> integer())) -> integer().
called_back_in_tail(Function) ->
    later(),
    Function().

later() ->
    Caller = self(),
    _ = spawn(fun() -> ern_waits:looked(2), Caller ! 42 end),
    ok.

%% report §8.6: a process blocked in Address.callForever waits without a
%% limit, as an untimed receive does, so a call to a server that waits in
%% an untimed receive for something else is a deadlock. A regression test,
%% written after the code; a callForever to a process that has ended is
%% call_ends_with_callee_test_'s
call_forever_deadlock_test() ->
    {Result, _} = ern_emitter_tests:run(
        "type Req = Get(reply : Reply(Int)) | Other\n"
        "fn server() : Unit receiving Req = receive { Other -> Unit }\n"
        "export fn main() : Unit = {\n"
        "    let a = spawn(server);\n"
        "    let _ = Io.debug(Address.callForever(a, fn(r) = Get(reply = r)));\n"
        "    Unit\n"
        "}\n"),
    %% Appendix E.21: the runtime's wait above the program's frame is left
    %% out (ern_emitter_tests' trace_leaves_the_runtime_out_test)
    ?assertEqual({fault, <<"deadlock">>, <<"M.main:5\n">>}, Result).

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
        "foreign fn waits() : Int = \"ern_reaper_tests:reaper_words/0\"\n"
        "fn rounds(keeper : Address(Msg), n : Int) : Unit receiving Msg =\n"
        "    if n == 0 then Unit\n"
        "    else {\n"
        "        let _ = spawnMonitored(fn() : Unit receiving Msg ="
        " monitor(Process.fromAddress(keeper), Ended),\n"
        "            Ended);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        let w = spawn(fn() : Unit receiving Msg = receive { Go -> Unit });\n"
        "        monitor(Process.fromAddress(w), Ended);\n"
        "        send(w, Go);\n"
        "        receive { Ended(_) -> Unit };\n"
        "        rounds(keeper, n - 1)\n"
        "    }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let keeper = spawn(fn() : Unit receiving Msg = receive { Go -> Unit });\n"
        "    rounds(keeper, 100);\n"
        "    let before = waits();\n"
        "    rounds(keeper, 1000);\n"
        "    Io.println(Io.show(waits() == before))\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Output).

%% The words of the runtime's reaper, which holds every wait, after the
%% deliveries in flight have ended, each watched by a monitor, and the
%% reaper, which traps exits and is told of each delivery's end by a
%% message after it, has taken every message; then its garbage is
%% collected.
reaper_words() ->
    [begin
         MonitorRef = erlang:monitor(process, Delivery),
         receive {'DOWN', MonitorRef, process, Delivery, _} -> ok end
     end || {{_, _, Delivery}, _} <- ets:tab2list(ern_deliveries)],
    Reaper = ern_rt:launch_reaper(),
    ok = ern_waits:until(Reaper, fun() ->
                                     erlang:process_info(Reaper, message_queue_len)
                                         =:= {message_queue_len, 0}
                                 end),
    settled(Reaper, collected(Reaper), 8).

%% The reaper's heap once collected, read until two readings in a row
%% agree, as test/ern_load.erl reads it: the reaper wakes ten times a
%% second to look for a deadlock (report §8.6), and a look that falls
%% between the collection and the reading leaves its words in the heap,
%% one reading in about twenty; the looks are a tenth of a second apart,
%% and no two of them disturb two readings alike.
settled(Pid, Reading, Tries) ->
    case collected(Pid) of
        Reading -> Reading;
        Other when Tries > 0 -> settled(Pid, Other, Tries - 1);
        Other -> min(Reading, Other)
    end.

collected(Pid) ->
    erlang:garbage_collect(Pid),
    {total_heap_size, Words} = erlang:process_info(Pid, total_heap_size),
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
        "fn loop(n : Int) : Unit receiving Msg =\n"
        "    if n == 0 then Unit\n"
        "    else {\n"
        "        let _ = Clock.alarmAt(Clock.now(), Tick);\n"
        "        receive { Tick(_) -> Unit };\n"
        "        loop(n - 1)\n"
        "    }\n"
        "export fn main() : Unit receiving Msg = { loop(5000); Io.println(\"done\") }\n")).

%% report §8.6: a process that computes is not waiting, however long it
%% computes and whoever waits on it, so a caller waiting on it without a
%% limit is in no deadlock. Here the worker computes until the reaper has
%% looked twice while its caller waits, and then answers. A regression
%% test, written after the code
computing_callee_is_no_deadlock_test() ->
    ?assertEqual({ok, <<"42\n">>}, ern_emitter_tests:run(
        looked_while() ++
        "type WorkerMsg = Compute(Reply(Int))\n"
        "export fn main() : Unit = {\n"
        "    let me = Process.fromAddress(self());\n"
        "    let worker = spawn(fn() = work(me));\n"
        "    Io.println(Int.toString(Address.callForever(worker, Compute)))\n"
        "}\n"
        "fn work(caller : Process) : Unit receiving WorkerMsg = receive {\n"
        "    Compute(reply) -> { let _ = looks([caller]); answer(reply, computed(42)) }\n"
        "}\n")).

%% report §8.6, §6.6: a cycle of calls without a limit is no deadlock while
%% a process can run, and a reply handed on can end it. Main calls the
%% second, the second hands main's reply to a worker and calls main, and
%% the worker computes until the reaper has looked twice while the two
%% stand in their cycle, then answers main, which answers the second. A
%% regression test, written after the code: a fault from the cycle would
%% end a correct program
handed_reply_ends_a_cycle_test() ->
    ?assertEqual({ok, <<"main is answered 41\nthe second is answered 42\nall finished\n">>},
                 ern_emitter_tests:run(
        looked_while() ++
        "type MainMsg = AskBack(Reply(Int)) | Finished\n"
        "type SecondMsg = Ask(Reply(Int))\n"
        "type WorkerMsg = Work(reply : Reply(Int), second : Process)\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let me = self();\n"
        "    let worker = spawn(fn() = work());\n"
        "    let second = spawn(fn() = serve(me, worker));\n"
        "    let value = Address.callForever(second, Ask);\n"
        "    Io.println(\"main is answered \" <> Int.toString(value));\n"
        "    receive { AskBack(reply) -> answer(reply, value + 1) };\n"
        "    receive { Finished -> Io.println(\"all finished\") }\n"
        "}\n"
        "fn serve(first : Address(MainMsg), worker : Address(WorkerMsg)) : Unit\n"
        "        receiving SecondMsg = receive {\n"
        "    Ask(reply) -> {\n"
        "        send(worker, Work(=reply, second = Process.fromAddress(self())));\n"
        "        let value = Address.callForever(first, AskBack);\n"
        "        Io.println(\"the second is answered \" <> Int.toString(value));\n"
        "        send(first, Finished)\n"
        "    }\n"
        "}\n"
        "fn work() : Unit receiving WorkerMsg = receive {\n"
        "    Work(=reply, =second) -> { let _ = looks([second]); answer(reply, computed(41)) }\n"
        "}\n")).

%% report §8.6: a deadlock is of the whole program, so processes stuck in a
%% cycle of calls without a limit are not found while another process can
%% still run, and are found once it waits too. Here two servers call each
%% other and a third process calls the first, while main computes until the
%% reaper has looked twice, and then waits for a message none can send. A
%% regression test, written after the code
stuck_part_is_found_with_the_whole_test() ->
    {Result, Output} = ern_emitter_tests:run(
        looked_while() ++
        "type FirstMsg = Meet(Address(SecondMsg)) | AskFirst(Reply(Int))\n"
        "type SecondMsg = AskSecond(Reply(Int))\n"
        "type MainMsg = Woken\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let first = spawn(fn() = meet());\n"
        "    let second = spawn(fn() = secondLoop(first));\n"
        "    send(first, Meet(second));\n"
        "    let caller = spawn(fn() =\n"
        "        Io.println(Int.toString(Address.callForever(first, AskFirst))));\n"
        "    let _ = looks([Process.fromAddress(first), Process.fromAddress(second),\n"
        "                   Process.fromAddress(caller)]);\n"
        "    let _ = computed(0);\n"
        "    Io.println(\"main waits\");\n"
        "    receive { Woken -> Io.println(\"unreachable\") }\n"
        "}\n"
        "fn meet() : Unit receiving FirstMsg = receive { Meet(second) -> firstLoop(second) }\n"
        "fn firstLoop(second : Address(SecondMsg)) : Unit receiving FirstMsg = receive {\n"
        "    AskFirst(reply) -> {\n"
        "        answer(reply, Address.callForever(second, AskSecond));\n"
        "        firstLoop(second)\n"
        "    }\n"
        "}\n"
        "fn secondLoop(first : Address(FirstMsg)) : Unit receiving SecondMsg = receive {\n"
        "    AskSecond(reply) -> {\n"
        "        answer(reply, Address.callForever(first, AskFirst) + 1);\n"
        "        secondLoop(first)\n"
        "    }\n"
        "}\n"),
    ?assertMatch({fault, <<"deadlock">>, _}, Result),
    ?assertEqual(<<"main waits\n">>, Output).

%% report §8.6: a delivery that foreign code arranges once its call has
%% returned, by a host process no monitor watches or by the host's timer,
%% is not counted, so a program that waits for it alone is read as
%% deadlocked; a monitor of the host process makes it one that may deliver,
%% and the program waits for its message. A regression test, written after
%% the code
delivery_foreign_code_arranges_test() ->
    Sender = "type MainMsg = Done | Ended(Down)\n"
             "foreign fn later(to : Foreign.Term, message : Foreign.Term) : Process =\n"
             "    \"ern_reaper_tests:sent_later/2\"\n",
    Waits = "    receive {\n"
            "        Done -> Io.println(\"done\")\n"
            "      | Ended(_) -> Io.println(\"the sender ended first\")\n"
            "    }\n"
            "}\n",
    {Unwatched, _} = ern_emitter_tests:run(
        Sender ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let _ = later(Foreign.term(self()), Foreign.atom(\"Done\"));\n" ++ Waits),
    ?assertMatch({fault, <<"deadlock">>, _}, Unwatched),
    ?assertEqual({ok, <<"done\n">>}, ern_emitter_tests:run(
        Sender ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    monitor(later(Foreign.term(self()), Foreign.atom(\"Done\")), Ended);\n" ++ Waits)),
    %% the timer ends with its recipient, which the deadlock ends at the
    %% reaper's first look, so its time is only one no look comes after: a day
    {Timed, _} = ern_emitter_tests:run(
        "type MainMsg = Done\n"
        "foreign fn sendAfter(ms : Int, to : Foreign.Term, sent : Foreign.Term) : Foreign.Term =\n"
        "    \"erlang:send_after/3\"\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let _ = sendAfter(86400000, Foreign.term(self()), Foreign.atom(\"Done\"));\n"
        "    receive { Done -> Io.println(\"done\") }\n"
        "}\n"),
    ?assertMatch({fault, <<"deadlock">>, _}, Timed).

%% report §8.6, §6.6: a foreign process the runtime did not start may
%% deliver while a monitor of it stands, and a call that waits on it is
%% such a monitor, so a program whose one process waits in a callForever on
%% a host process's address is no deadlock. Here the host process answers
%% once the reaper has looked twice, and the program prints the answer;
%% then a host process that lives while the reaper looks twice and ends
%% without answering, which faults the caller as a callee's end does. A
%% regression test of the look, found by a reading: the look read such a
%% caller as deadlocked, its callee neither a process of the program nor a
%% system process
foreign_callee_is_no_deadlock_test() ->
    Program = fun(Server) ->
                  "type Ask = Ask(reply : Reply(Int))\n"
                  "foreign fn server() : Address(Ask) = \"ern_reaper_tests:" ++ Server ++ "/0\"\n"
                  "export fn main() : Unit = {\n"
                  "    let n = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
                  "    Io.println(Int.toString(n))\n"
                  "}\n"
              end,
    ?assertEqual({ok, <<"42\n">>}, ern_emitter_tests:run(Program("answering_later"))),
    {Ended, _} = ern_emitter_tests:run(Program("ending_later")),
    ?assertMatch({fault, <<"callee returned without answering">>, _}, Ended).

%% The Ernest side of the tests above of a process that computes while the
%% reaper looks: `looks` once each process given waits in a call, and
%% `computed`, which answers its argument once the reaper has looked twice
%% since, and computes until then.
looked_while() ->
    "foreign fn looks(processes : List(Process)) : Foreign.Term = \"ern_reaper_tests:looks/1\"\n"
    "foreign fn looking() : Bool = \"ern_reaper_tests:looking/0\"\n"
    "fn computed(value : Int) : Int = if looking() then computed(value) else value\n".

%% The host's side of the same: once each of Processes waits in a call, a
%% process of the host's, under a name of its own, that ends once the
%% reaper has looked twice, and whether it still lives, which a process of
%% the program asks as it computes and which waits for nothing.
-spec looks([pid()]) -> ok.
looks(Processes) ->
    [ok = ern_waits:calling(Process) || Process <- Processes],
    true = register(ern_reaper_looks, spawn(fun() -> ern_waits:looked(2) end)),
    ok.

-spec looking() -> boolean().
looking() ->
    whereis(ern_reaper_looks) =/= undefined.

%% The host's side of the tests of a delivery foreign code arranges: a
%% process of the host's that sends Message to To once the reaper has looked
%% twice, or once the reaper has ended, and its pid.
-spec sent_later(pid(), atom()) -> pid().
sent_later(To, Message) ->
    spawn(fun() -> _ = ern_waits:looked(2), To ! Message end).

%% The host's side of the test of a foreign callee: a process of the
%% host's that takes an Ask and, once the reaper has looked twice, answers
%% it with 42, or ends without answering.
-spec answering_later() -> pid().
answering_later() ->
    spawn(fun() -> receive {'Ask', {Reply, _}} -> _ = ern_waits:looked(2), Reply ! {Reply, 42} end
          end).

-spec ending_later() -> pid().
ending_later() ->
    spawn(fun() -> receive {'Ask', _} -> _ = ern_waits:looked(2), ok end end).
