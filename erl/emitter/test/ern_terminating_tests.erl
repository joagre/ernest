%% Report §8.6 and Appendix E.23: the program's end told to the subscribers
%% of Os.terminating, in programs run as the runner runs them
%% (ern_emitter_tests:run/3). A termination is the runtime's own word of
%% one, ern_rt:signal/1, which the signal handler calls (ern_signals),
%% asked by the program through a foreign function. Regression tests,
%% written after the code (MVP 3.1's item 6); a node's end, a peer finding
%% and calling a node whose subscribers are being told, and the interrupt,
%% which the host takes, are the real nodes' (test/ern_nodes_tests.erl).
-module(ern_terminating_tests).

-include_lib("eunit/include/eunit.hrl").

%% A program whose keeper counts what it is sent and, told of the end,
%% prints what it kept and answers, or does what Told says; Main follows,
%% from its line 12, which a spawn's site counts from.
kept(Told, Main) ->
    kept(Told, Main, #{}).

kept(Told, Main, Options) ->
    ern_emitter_tests:run(
      ['M'],
      ["type Msg = Add(Int) | Terminating(Reply(Unit))\n"
       "fn count(n : Int) : Unit with Msg = receive {\n"
       "    Add(k) -> count(n + k)\n"
       "  | Terminating(reply) -> ", Told, "\n"
       "}\n"
       "fn keeper() : Unit with Msg = {\n"
       "    Os.terminating(Terminating);\n"
       "    count(0)\n"
       "}\n"
       "foreign fn signal(name : Foreign.Term) : Foreign.Term with m = \"ern_rt:signal/1\"\n"
       "fn terminate() : Unit with m = { let _ = signal(Foreign.from(Foreign.atom(\"sigterm\")));"
       " Unit }\n",
       Main],
      Options).

-define(KEEP, "{ Io.println(\"kept \" <> Int.toString(n)); answer(reply, Unit) }").

%% report §8.6: at the entry process's end the subscriber is told, and the
%% program ends once it has answered: what it prints then is printed, and
%% the runtime says the wait and the answer on standard error
told_at_the_entry_process_end_test() ->
    {Result, Output} = kept(?KEEP,
                            "export fn main() : Unit with Never = {\n"
                            "    let k = spawn(keeper);\n"
                            "    send(k, Add(2));\n"
                            "    send(k, Add(3))\n"
                            "}\n"),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber: M.main:13\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"kept 5\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.main:13 answered\n">>)).

%% report §8.6, Appendix E.23: Os.exit ends the program as §8.6 does, the
%% subscriber told first, with its status
told_at_exit_test() ->
    {Result, Output} = kept(?KEEP,
                            "export fn main() : Unit with Never = {\n"
                            "    let k = spawn(keeper);\n"
                            "    send(k, Add(4));\n"
                            "    Os.exit(3)\n"
                            "}\n"),
    ?assertEqual({exit, 3}, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"kept 4\n">>)).

%% report §8.6: a termination ends the program the same way, the entry
%% process running on while the end waits and ending with the program
told_at_termination_test() ->
    {Result, Output} = kept(?KEEP,
                            "export fn main() : Unit with Unit = {\n"
                            "    let k = spawn(keeper);\n"
                            "    send(k, Add(6));\n"
                            "    terminate();\n"
                            "    receive { _ -> Unit }\n"
                            "}\n"),
    ?assertEqual({signal, sigterm}, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"kept 6\n">>)).

%% report §8.6, §11.2: a second termination ends the program at once, past
%% a subscriber that has not answered, which the runtime says
second_termination_ends_at_once_test() ->
    {Result, Output} = kept("held(reply)",
                            "fn held(reply : Reply(Unit)) : Unit with Msg = receive {\n"
                            "    Terminating(other) -> { answer(other, Unit); held(reply) }\n"
                            "  | Add(_) -> held(reply)\n"
                            "}\n"
                            "export fn main() : Unit with Unit = {\n"
                            "    let _ = spawn(keeper);\n"
                            "    terminate();\n"
                            "    terminate();\n"
                            "    receive { _ -> Unit }\n"
                            "}\n"),
    ?assertEqual({signal, sigterm}, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber: M.main:17\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the end was cut short, 1 subscriber unanswered:"
                                                " M.main:17\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"the subscriber M.main:">>)).

%% report §8.6, §11.2: an Os.exit while the end waits ends the program at
%% once, with its status, a subscriber that exits there among the ways,
%% and the runtime says whom the wait left unanswered
exit_while_the_end_waits_test() ->
    {Result, Output} = kept("Os.exit(7)",
                            "export fn main() : Unit with Never = {\n"
                            "    let _ = spawn(keeper);\n"
                            "    Unit\n"
                            "}\n"),
    ?assertEqual({exit, 7}, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the end was cut short, 1 subscriber unanswered:"
                                                " M.main:13\n">>)).

%% report §8.6: a subscriber that faults while it is told is reported, and
%% the end goes on without it
faulting_subscriber_is_reported_test() ->
    Self = self(),
    Faults = fun({'FaultReport', _, Site, Cause, _, _}, _Peer) -> Self ! {fault, Site, Cause} end,
    {Result, Output} = kept("{ let _ = 1 / List.size([]); answer(reply, Unit) }",
                            "export fn main() : Unit with Never = {\n"
                            "    let _ = spawn(keeper);\n"
                            "    Unit\n"
                            "}\n",
                            #{faults => Faults}),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.main:13 ended without"
                                                " answering\n">>)),
    receive {fault, Site, Cause} -> ?assertEqual({<<"M.main:13">>, <<"division by zero">>},
                                                 {Site, Cause})
    after 0 -> erlang:error(no_fault_reported)
    end.

%% report §8.6, §6.9, §11.2, Appendix E.23: a restart ends the
%% subscription to the end with its run, and a subscription the new run
%% makes is one made while the end waits, told at once, said as it is told,
%% and waited for. The keeper faults when it is told, so it restarts
%% without answering, its fault reported as a restart's; its new run is
%% told, prints and answers. The count line names both subscribers, the
%% holder first, as it was spawned first. A regression test,
%% written after the code: the restarted run's subscription was never told,
%% and the end went on without it. A keeper alone is not tested: its new
%% run's subscription races the runner's last read of the table (told/3),
%% which is the host's scheduling, so here a second subscriber holds the
%% end until the new run has been told.
restarting_subscriber_test() ->
    {Result, Output} = restarted("{ let _ = 1 / List.size([]); answer(reply, Unit) }"),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"told again\n">>)),
    ?assertEqual([<<"the end waits for 2 subscribers: M.main:24, M.main:26">>,
                  <<"the subscriber M.main:26 restarted without answering">>,
                  <<"the end waits for M.main:26 too">>,
                  <<"the subscriber M.main:26 answered">>],
                 naming(Output, <<"M.main:26">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.main:24 answered\n">>)),
    ?assertEqual([{<<"M.main:26">>, <<"division by zero">>, true}], faults([])).

%% report §8.6, §6.9, Appendix E.23: so too where the keeper answered
%% before it restarted: the run it answered for has ended, and its new
%% run's subscription is told, said as it is told, and waited for, the
%% keeper answering twice. A regression test, written after the code: the
%% runner held the keeper as answered, and so never told its new run.
answered_subscriber_restarting_test() ->
    {Result, Output} = restarted("{ answer(reply, Unit); let _ = 1 / List.size([]); Unit }"),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"told again\n">>)),
    ?assertEqual([<<"the end waits for 2 subscribers: M.main:24, M.main:26">>,
                  <<"the subscriber M.main:26 answered">>,
                  <<"the end waits for M.main:26 too">>,
                  <<"the subscriber M.main:26 answered">>],
                 naming(Output, <<"M.main:26">>)),
    ?assertEqual([{<<"M.main:26">>, <<"division by zero">>, true}], faults([])).

%% A program whose keeper, a subscriber of Os.terminating that may restart
%% once, is told at the end with 1 in its count and does what First says,
%% which faults; its new run subscribes again and, told with 0, prints
%% `told again`, lets the holder answer and answers. The holder, a second
%% subscriber, answers once the keeper's new run has been told. Main
%% returns once both have subscribed; the keeper's spawn site is
%% M.main:26, the holder's M.main:24.
restarted(First) ->
    Self = self(),
    Faults = fun({'FaultReport', _, Site, Cause, Restarted, _}, _Peer) ->
                 Self ! {fault, Site, Cause, Restarted}
             end,
    ern_emitter_tests:run(
      ['M'],
      ["type Msg = Ready | Done | Add(Int) | Terminating(Reply(Unit))\n"
       "fn hold(main : Address(Msg)) : Unit with Msg = {\n"
       "    Os.terminating(Terminating);\n"
       "    send(main, Ready);\n"
       "    receive {\n"
       "        Terminating(reply) -> receive { Done -> answer(reply, Unit) }\n"
       "    }\n"
       "}\n"
       "fn keeper(holder : Address(Msg), main : Address(Msg)) : Unit with Msg = {\n"
       "    Os.terminating(Terminating);\n"
       "    send(main, Ready);\n"
       "    count(holder, 0)\n"
       "}\n"
       "fn count(holder : Address(Msg), n : Int) : Unit with Msg = receive {\n"
       "    Add(k) -> count(holder, n + k)\n"
       "  | Terminating(reply) -> if n > 0 then ", First, " else {\n"
       "        Io.println(\"told again\");\n"
       "        send(holder, Done);\n"
       "        answer(reply, Unit)\n"
       "    }\n"
       "}\n"
       "export fn main() : Unit with Msg = {\n"
       "    let me = self();\n"
       "    let holder = spawn(fn() : Unit with Msg = hold(me));\n"
       "    let limit = RestartLimit(restarts = 1, within = 5000);\n"
       "    let k = spawn(restarting(limit, fn() : Unit with Msg = keeper(holder, me)));\n"
       "    send(k, Add(1));\n"
       "    receive { Ready -> Unit };\n"
       "    receive { Ready -> Unit }\n"
       "}\n"],
      #{faults => Faults}).

%% report §6.9, §8.6, docs/memory.md: a teller leaves nothing of its
%% monitor in the reaper once it has its word, so a subscriber that faults
%% at each telling under Unlimited, told by a new teller each time, grows
%% nothing there. The keeper counts its tellings in a process of its own,
%% reads the reaper's words after 100 of them and again after 1,100, as
%% ern_reaper_tests' monitors_let_go_test reads them, and answers; the
%% holder answers once it has. A regression test, written after the fix:
%% each teller's monitor stayed in the reaper until the subscriber died.
tellers_leave_no_monitor_test() ->
    {Result, Output} = ern_emitter_tests:run(
        "type Msg = Ready | Done | Terminating(Reply(Unit))\n"
        "type Count = Next(Reply(Int)) | Keep(Int) | Kept(Reply(Int))\n"
        "foreign fn waits() : Int with m = \"ern_reaper_tests:reaper_words/0\"\n"
        "fn count(n : Int, kept : Int) : Unit with Count = receive {\n"
        "    Next(reply) -> { answer(reply, n); count(n + 1, kept) }\n"
        "  | Keep(words) -> count(n, words)\n"
        "  | Kept(reply) -> { answer(reply, kept); count(n, kept) }\n"
        "}\n"
        "fn hold(main : Address(Msg)) : Unit with Msg = {\n"
        "    Os.terminating(Terminating);\n"
        "    send(main, Ready);\n"
        "    receive {\n"
        "        Terminating(reply) -> receive { Done -> answer(reply, Unit) }\n"
        "    }\n"
        "}\n"
        "fn keeper(counter : Address(Count), holder : Address(Msg), main : Address(Msg))"
        " : Unit with Msg = {\n"
        "    Os.terminating(Terminating);\n"
        "    send(main, Ready);\n"
        "    receive {\n"
        "        Terminating(reply) -> told(counter, holder, reply)\n"
        "    }\n"
        "}\n"
        "fn told(counter : Address(Count), holder : Address(Msg), reply : Reply(Unit))"
        " : Unit with Msg = {\n"
        "    let n = Address.callForever(counter, Next);\n"
        "    if n == 100 then send(counter, Keep(waits())) else Unit;\n"
        "    if n < 1100 then {\n"
        "        let _ = 1 / List.size([]);\n"
        "        answer(reply, Unit)\n"
        "    } else {\n"
        "        Io.println(Io.show(waits() == Address.callForever(counter, Kept)));\n"
        "        send(holder, Done);\n"
        "        answer(reply, Unit)\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit with Msg = {\n"
        "    let me = self();\n"
        "    let counter = spawn(fn() : Unit with Count = count(0, 0));\n"
        "    let holder = spawn(fn() : Unit with Msg = hold(me));\n"
        "    let _ = spawn(restarting(Unlimited, fn() : Unit with Msg ="
        " keeper(counter, holder, me)));\n"
        "    receive { Ready -> Unit };\n"
        "    receive { Ready -> Unit }\n"
        "}\n"),
    ?assertEqual(ok, Result),
    ?assertEqual(1100, length(binary:matches(Output, <<"restarted without answering\n">>))),
    ?assertMatch({_, _}, binary:match(Output, <<"\ntrue\n">>)).

%% The lines of Output that name Site, in their order.
naming(Output, Site) ->
    [Line || Line <- binary:split(Output, <<"\n">>, [global]),
             binary:match(Line, Site) =/= nomatch].

%% The faults reported, in the order they were.
faults(Acc) ->
    receive {fault, Site, Cause, Restarted} -> faults([{Site, Cause, Restarted} | Acc])
    after 0 -> lists:reverse(Acc)
    end.

%% report §8.6, §11.2, Appendix E.23: a subscription made while the end
%% waits is told at once, said as it is told, and the end waits for it too:
%% the first subscriber, told, starts a second and answers once the second
%% has subscribed. One whose process ended before the end is gone with it
%% and holds nothing up
subscribed_while_the_end_waits_test() ->
    {Result, Output} = ern_emitter_tests:run(
        "type Msg = Ready | Terminating(Reply(Unit))\n"
        "fn second(first : Address(Msg)) : Unit with Msg = {\n"
        "    Os.terminating(Terminating);\n"
        "    send(first, Ready);\n"
        "    receive {\n"
        "        Terminating(reply) -> { Io.println(\"second told\"); answer(reply, Unit) }\n"
        "      | Ready -> Unit\n"
        "    }\n"
        "}\n"
        "fn first() : Unit with Msg = {\n"
        "    Os.terminating(Terminating);\n"
        "    receive {\n"
        "        Terminating(reply) -> {\n"
        "            let me = self();\n"
        "            let _ = spawn(fn() : Unit with Msg = second(me));\n"
        "            receive {\n"
        "                Ready -> answer(reply, Unit)\n"
        "              | Terminating(other) -> { answer(other, Unit); answer(reply, Unit) }\n"
        "            }\n"
        "        }\n"
        "      | Ready -> Unit\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit with Never = {\n"
        "    let _ = spawn(fn() : Unit with Msg = Os.terminating(Terminating));\n"
        "    let _ = spawn(first);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber: M.main:26\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for M.first:15 too\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"second told\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.first:15 answered\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.main:26 answered\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"M.main:25">>)).

%% report §8.6: a program with no subscriber ends as before, and says
%% nothing of a wait
no_subscriber_says_nothing_test() ->
    {Result, Output} = kept(?KEEP, "export fn main() : Unit with Never = Io.println(\"done\")\n"),
    ?assertEqual(ok, Result),
    ?assertEqual(<<"done\n">>, Output).

%% report §8.6, Appendix E.23: a subscription to the program's end can
%% still deliver while it stands, since a termination tells it, so a
%% program that is no node whose main subscribes and waits for its
%% termination message is no deadlock. The termination comes once the
%% reaper has looked for a deadlock twice, which ern_waits shows, the wait
%% being for an absence that nothing else shows, and main is told then. A
%% regression test, written after the fix: main was found deadlocked at
%% the reaper's first look. The end's wait, where a running test is the
%% deadlock's victim, is ern_cli_tests' (no_deadlock_while_the_end_waits)
waiting_for_the_end_is_no_deadlock_test() ->
    Waiter = spawn(fun() ->
                       receive waiting -> ok end,
                       ern_waits:looked(2),
                       ok = ern_rt:signal(sigterm)
                   end),
    register(ern_terminating_tests_waiter, Waiter),
    {Result, Output} = ern_emitter_tests:run(
        "type Msg = Terminating(Reply(Unit))\n"
        "foreign fn waiting(name : Foreign.Term, word : Foreign.Term) : Foreign.Term"
        " with m = \"erlang:send/2\"\n"
        "export fn main() : Unit with Msg = {\n"
        "    Os.terminating(Terminating);\n"
        "    let _ = waiting(Foreign.from(Foreign.atom(\"ern_terminating_tests_waiter\")),"
        " Foreign.from(Foreign.atom(\"waiting\")));\n"
        "    receive {\n"
        "        Terminating(reply) -> { Io.println(\"told\"); answer(reply, Unit) }\n"
        "    }\n"
        "}\n"),
    ?assertEqual({signal, sigterm}, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"told\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"deadlock">>)).
