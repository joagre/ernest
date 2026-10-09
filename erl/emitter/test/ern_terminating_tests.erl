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
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber\n">>)),
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

%% report §8.6: a second termination ends the program at once, past a
%% subscriber that has not answered
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
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"the subscriber M.main:">>)).

%% report §8.6: an Os.exit while the end waits ends the program at once,
%% with its status, a subscriber that exits there among the ways
exit_while_the_end_waits_test() ->
    {Result, _} = kept("Os.exit(7)",
                       "export fn main() : Unit with Never = {\n"
                       "    let _ = spawn(keeper);\n"
                       "    Unit\n"
                       "}\n"),
    ?assertEqual({exit, 7}, Result).

%% report §8.6: a subscriber that faults while it is told is reported, and
%% the end goes on without it; one that restarts is no answer either
faulting_subscriber_is_reported_test() ->
    Self = self(),
    Faults = fun({'FaultReport', _, Site, Cause, _, _}) -> Self ! {fault, Site, Cause} end,
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

restarting_subscriber_test() ->
    {Result, Output} = kept("{ let _ = 1 / List.size([]); answer(reply, Unit) }",
                            "export fn main() : Unit with Never = {\n"
                            "    let limit = RestartLimit(restarts = 1, within = 5000);\n"
                            "    let _ = spawn(restarting(limit, keeper));\n"
                            "    Unit\n"
                            "}\n"),
    ?assertEqual(ok, Result),
    ?assertMatch({_, _}, binary:match(Output, <<"the subscriber M.main:14 restarted without"
                                                " answering\n">>)).

%% report §8.6, Appendix E.23: a subscription made while the end waits is
%% told at once, and the end waits for it too: the first subscriber, told,
%% starts a second and answers once the second has subscribed. One whose
%% process ended before the end is gone with it and holds nothing up
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
    ?assertMatch({_, _}, binary:match(Output, <<"the end waits for 1 subscriber\n">>)),
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

%% report §8.6: while the end waits, every process may wait with nothing in
%% flight and no deadlock is found: the subscriber waits for a word that
%% only a termination from outside brings. The termination comes once the
%% reaper has had the time it takes to look for a deadlock twice, its look
%% coming after 100 ms in which nothing happened (ern_rt's LOOK_SOON); the
%% wait is for an absence, which nothing else shows. The first termination
%% counts as one, since the entry process's end began the end, and the
%% second ends the program at once
no_deadlock_while_the_end_waits_test() ->
    Looks = 2 * 100,
    Waiter = spawn(fun() ->
                       receive waiting -> ok end,
                       receive after Looks -> ok end,
                       ok = ern_rt:signal(sigterm),
                       ok = ern_rt:signal(sigterm)
                   end),
    register(ern_terminating_tests_waiter, Waiter),
    %% the name goes with the helper, which ends once it has sent the
    %% terminations
    {Result, Output} =
        kept("{ let _ = waiting(Foreign.from(Foreign.atom(\"ern_terminating_tests_waiter\")),"
             " Foreign.from(Foreign.atom(\"waiting\"))); held(reply) }",
             "fn held(reply : Reply(Unit)) : Unit with Msg = receive {\n"
             "    Terminating(other) -> { answer(other, Unit); held(reply) }\n"
             "  | Add(_) -> held(reply)\n"
             "}\n"
             "foreign fn waiting(name : Foreign.Term, word : Foreign.Term) : Foreign.Term"
             " with m = \"erlang:send/2\"\n"
             "export fn main() : Unit with Never = {\n"
             "    let _ = spawn(keeper);\n"
             "    Unit\n"
             "}\n"),
    ?assertEqual(ok, Result),
    ?assertEqual(nomatch, binary:match(Output, <<"deadlock">>)).
