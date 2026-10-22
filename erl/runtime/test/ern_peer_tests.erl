%% Report §8.7, Appendix E.27, E.22, G.7: what a node's gateway does with a
%% spawn's answer and a spawn from a peer, a supervisor's child on another
%% node, and a proxy's finds, each where a run of real nodes
%% cannot show it whenever it runs. Real nodes are test/ern_nodes_tests.erl's.
%% Regression tests, written after the code, the spawn by identity's (MVP
%% 3.1's item 4) among them; the proxy's was written before.
-module(ern_peer_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("checker/include/ern_canonical.hrl").

%% Report §8.7: the milliseconds a spawn's or a compute's frame says its
%% sender waits, here a stand-in's; eunit's time for one test, which no
%% test here outlasts.
-define(MS, 5000).

%% report §8.7: a spawn's answer goes to the process that waits for it, and
%% one that comes after the spawner stopped waiting ends the process it
%% names
answer_test() ->
    ok = ern_peer:tables(),
    try
        Ref = make_ref(),
        true = ets:insert(ern_spawns, written(node(), Ref, self())),
        Started = spawn(fun() -> receive after infinity -> ok end end),
        ok = ern_peer:frame(self(), {answer, Ref, {spawned, Started}}),
        ?assertEqual({Ref, {spawned, Started}}, receive {Ref, _} = Got -> Got end),
        ?assertEqual([], ets:lookup(ern_spawns, {node(), Ref})),
        Late = spawn(fun() -> receive after infinity -> ok end end),
        MonitorRef = erlang:monitor(process, Late),
        ok = ern_peer:frame(self(), {answer, make_ref(), {spawned, Late}}),
        ?assertEqual({ern, killed}, receive {'DOWN', MonitorRef, process, Late, Why} -> Why end),
        exit(Started, kill)
    after
        untabled()
    end.

%% report §8.7: the answer for a spawner that died while it waited ends the
%% process it names, and its row goes; a peer's loss lets go of every row
%% of that peer, its living waiter answered Unreachable and a dead one's row
%% gone, and of no other peer's. A regression test: the answer went to the
%% dead spawner, the process on the peer running on unowned, and a row whose
%% answer never came was kept for good
dead_spawner_test() ->
    ok = ern_peer:tables(),
    try
        Dead = spawn(fun() -> ok end),
        DeadRef = erlang:monitor(process, Dead),
        receive {'DOWN', DeadRef, process, Dead, _} -> ok end,
        Ref = make_ref(),
        true = ets:insert(ern_spawns, written(node(), Ref, Dead)),
        Started = spawn(fun() -> receive after infinity -> ok end end),
        MonitorRef = erlang:monitor(process, Started),
        ok = ern_peer:frame(self(), {answer, Ref, {spawned, Started}}),
        ?assertEqual({ern, killed}, receive {'DOWN', MonitorRef, process, Started, Why} -> Why end),
        ?assertEqual([], ets:tab2list(ern_spawns)),
        Lost = 'lost@node.ernest',
        [Living, Gone, Other] = [make_ref() || _ <- [1, 2, 3]],
        OtherRow = written('other@node.ernest', Other, self()),
        true = ets:insert(ern_spawns, [written(Lost, Living, self()), written(Lost, Gone, Dead),
                                       OtherRow]),
        ok = ern_peer:lost(Lost, erlang:unique_integer([monotonic])),
        ?assertEqual({Living, {failed, 'Unreachable'}}, receive {Living, _} = Got -> Got end),
        ?assertEqual([OtherRow], ets:tab2list(ern_spawns))
    after
        untabled()
    end.

%% report §8.7: a loss lets go of the spawns that waited on the peer when
%% the gateway learned of it, and of none written after, a spawn whose wait
%% began on the connection opened again: its answer, which the worker reads
%% after the loss, goes to its waiter, and its process runs on. A
%% regression test, written after the code: the loss took every row of the
%% peer, so a spawn made after the reconnection was answered Unreachable,
%% and its process ended as its answer arrived
spawn_after_a_loss_test() ->
    ok = ern_peer:tables(),
    try
        [Before, After] = [make_ref(), make_ref()],
        true = ets:insert(ern_spawns, written(node(), Before, self())),
        Loss = erlang:unique_integer([monotonic]),
        true = ets:insert(ern_spawns, written(node(), After, self())),
        ok = ern_peer:lost(node(), Loss),
        ?assertEqual({Before, {failed, 'Unreachable'}}, receive {Before, _} = Got -> Got end),
        Started = spawn(fun() -> receive after infinity -> ok end end),
        ok = ern_peer:frame(self(), {answer, After, {spawned, Started}}),
        ?assertEqual({After, {spawned, Started}}, receive {After, _} = Answer -> Answer end),
        ?assertEqual([], ets:tab2list(ern_spawns)),
        ?assert(erlang:is_process_alive(Started)),
        exit(Started, kill)
    after
        untabled()
    end.

%% A spawn's row in the gateway's table, as the spawn writes it now: the
%% peer's node, the spawn's reference, the waiting process and the row's
%% place in the order of the node's moments.
written(Node, Ref, Waiting) ->
    {{Node, Ref}, Waiting, erlang:unique_integer([monotonic])}.

%% The node's peers, {Name, Node} in the configuration's order, listed for
%% Test, and the tables held, as the carrier lists them and the gateway
%% holds them; none listed after it.
listing(Peers, Test) ->
    ok = ern_peer:configure(Peers, #{}),
    ok = ern_peer:tables(),
    try
        Test()
    after
        untabled(),
        ok = ern_peer:configure([], #{})
    end.

%% The gateway's tables, which ern_peer:tables/0 made, gone.
untabled() ->
    ets:delete(ern_spawns),
    ets:delete(ern_utilizations).

%% A peer's utilization as its telling, Age ms ago, the peer telling every
%% Interval ms, would have left it.
told(Node, Utilization, Age, Interval) ->
    At = erlang:monotonic_time(millisecond) - Age,
    true = ets:insert(ern_utilizations, {Node, Utilization, At, Interval}).

%% The nodes Count picks named, each once, in order.
picks(Count) ->
    lists:usort([Node || _ <- lists:seq(1, Count), {picked, Node} <- [ern_peer:picked()]]).

%% report §8.7, Appendix E.27: a node that lists no peer holds no
%% utilization and picks none, `NotListed`; one whose peers it has not
%% heard from holds none and picks none, `Unreachable`; a telling held is
%% answered by `utilizations`, the peer's name, its utilization and its
%% age, and picked, a later telling in its place, and a loss drops it. A
%% regression test, written after the code
utilizations_test() ->
    listing([], fun() ->
                    ?assertEqual('NotListed', ern_peer:picked()),
                    ?assertEqual([], ern_peer:utilizations())
                end),
    listing([{<<"a">>, 'a@node.ernest'}, {<<"b">>, 'b@node.ernest'}],
            fun() ->
                ?assertEqual('Unreachable', ern_peer:picked()),
                ?assertEqual([], ern_peer:utilizations()),
                ok = ern_peer:hold_utilization('b@node.ernest', 0.75, 5000),
                ?assertMatch([{<<"b">>, 0.75, Age}] when Age >= 0, ern_peer:utilizations()),
                ?assertEqual({picked, 'b@node.ernest'}, ern_peer:picked()),
                ok = ern_peer:hold_utilization('b@node.ernest', 0.25, 5000),
                ?assertMatch([{<<"b">>, 0.25, _}], ern_peer:utilizations()),
                ok = ern_peer:drop_utilization('b@node.ernest'),
                ?assertEqual([], ern_peer:utilizations()),
                ?assertEqual('Unreachable', ern_peer:picked())
            end).

%% report §8.7: the pick's rules over the utilizations a node holds, the
%% configuration's order a, b, c, d, e: a single usable peer is taken as it
%% is, however busy; a utilization older than two of its teller's intervals
%% is not used, and `utilizations` answers it as it is, with its age, while
%% one as old from a peer that tells seldom enough is used; of two peers
%% the less busy is taken at every draw, and of two equally busy the first
%% drawn, so that each is taken across draws; the draw among more than two
%% stays within the usable ones, never takes the busiest, which is no less
%% busy than any it is drawn with, and takes each other one, two being
%% drawn at random; and of five equally busy each is taken, the last in the
%% configuration's order among them. A regression test, written after the
%% code; the first drawn's two assertions before its change of 2026-10-20,
%% which they failed. That the draw is uniform is the host's generator's,
%% and is not measured
pick_test() ->
    [A, B, C, D, E] = Nodes = ['a@node.ernest', 'b@node.ernest', 'c@node.ernest',
                               'd@node.ernest', 'e@node.ernest'],
    Peers = lists:zip([<<"a">>, <<"b">>, <<"c">>, <<"d">>, <<"e">>], Nodes),
    Interval = 1000,
    Old = 2 * Interval + 1000,
    listing(Peers,
            fun() ->
                told(C, 0.9, 0, Interval),
                ?assertEqual([C], picks(50)),
                %% older than two of its teller's intervals, and less busy:
                %% not used
                told(B, 0.1, Old, Interval),
                ?assertEqual([C], picks(50)),
                ?assertMatch([{<<"b">>, 0.1, Age}, {<<"c">>, 0.9, _}] when Age > 2 * Interval,
                             ern_peer:utilizations()),
                %% as old, its teller telling seldom: used, and less busy
                told(B, 0.1, Old, Old),
                ?assertEqual([B], picks(50)),
                told(B, 0.1, Old, Interval),
                %% a less busy peer is taken at every draw
                told(D, 0.1, 0, Interval),
                ?assertEqual([D], picks(50)),
                %% two equally busy: the first drawn, each across draws
                told(C, 0.1, 0, Interval),
                ?assertEqual([C, D], picks(50)),
                %% more than two: within the usable ones, never the busiest,
                %% a not heard from and b too old
                told(C, 0.9, 0, Interval),
                told(E, 0.5, 0, Interval),
                ?assertEqual([D, E], picks(300)),
                ?assertNot(lists:member(A, picks(300))),
                %% every one equally busy: each taken, e, listed last, too
                [told(Node, 0.0, 0, Interval) || Node <- Nodes],
                ?assertEqual(Nodes, picks(300))
            end).

%% report §8.7, Appendix E.27, §7.4: `Peer.setUtilization` sets the
%% utilization the node tells and answers, at or above 0.0, 1.0 and work
%% waiting above it among them, a later one in its place; a number below
%% 0.0 faults the caller and sets nothing. The launch's table, which a
%% launch makes, stands in for one here. A regression test, written after
%% the code; the numbers above 1.0 since the release review before 0.4.0,
%% which found them refused
set_utilization_test() ->
    undefined = ets:whereis(ern_launch),
    ern_launch = ets:new(ern_launch, [named_table, public]),
    try
        ?assertEqual(none, ern_rt:program_utilization()),
        [begin
             ?assertEqual('Unit', ern_peer:set_utilization(Utilization)),
             ?assertEqual(Utilization, ern_rt:program_utilization())
         end || Utilization <- [0.0, 1.0, 1.5, 0.25]],
        [?assertThrow({ern, fault, <<"a utilization is 0.0 or above">>},
                      ern_peer:set_utilization(Utilization))
         || Utilization <- [-0.25, -1.0e-9]],
        ?assertEqual(0.25, ern_rt:program_utilization())
    after
        ets:delete(ern_launch)
    end,
    %% no launch in progress: none set, the node telling its measure
    ?assertEqual(none, ern_rt:program_utilization()).

%% report §8.7: a frame whose fields are not those of its kind is one the
%% gateway cannot read: an answer that names no spawn's outcome, or a
%% process of another node than the peer's, a find whose name is no text,
%% a message to an adapted address another node made, and a telling whose
%% utilization is no float of 0.0 or more or whose interval is no whole
%% number of at least 1, which the gateway does not hold. A regression
%% test: each frame was read by its tag alone, and one that raised killed
%% the gateway's worker, every later frame from the peer lost; the
%% tellings' cases written after the code
faulty_fields_test() ->
    ok = ern_peer:tables(),
    try
        Elsewhere = binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>),
        Here = self(),
        Wrap = fun(Message) -> Message end,
        [?assertEqual(unreadable, ern_peer:frame(self(), Body))
         || Body <- [{answer, make_ref(), garbage}, {answer, make_ref(), {failed, 'Other'}},
                     {answer, make_ref(), {spawned, Elsewhere}}, {answer, nothing, {spawned, Here}},
                     {find, 1, <<"Int">>, make_ref()},
                     {adapted, {adapted, Wrap, Here, Elsewhere, make_ref()}, 1},
                     {adapted, not_an_address, 1},
                     {spawn, make_ref(), not_a_function, <<"s">>, false, ?MS},
                     {spawn, make_ref(), {function, <<"short">>}, <<"s">>, false, ?MS},
                     {spawn, make_ref(), {lambda, <<0:256>>, 0, []}, <<"s">>, false, ?MS},
                     {spawn, make_ref(), {foreign, []}, <<"s">>, false, ?MS},
                     {spawn, make_ref(), {foreign, [peer, tests]}, <<"s">>, false, ?MS},
                     {spawn, make_ref(), {restarting, 'Unlimited',
                                          {restarting, 'Unlimited', {function, <<0:256>>}}},
                      <<"s">>, false, ?MS},
                     {spawn, make_ref(), {restarting, forever, {function, <<0:256>>}}, <<"s">>,
                      false, ?MS},
                     %% a spawn whose milliseconds are not a whole number
                     {spawn, make_ref(), {function, <<0:256>>}, <<"s">>, false, 1.5},
                     %% a telling the gateway does not hold, its utilization
                     %% or its interval out of shape, which it leaves to the
                     %% worker
                     {telling, 0.5}, {telling, 0.5, 0}, {telling, 0.5, 2.5e3},
                     {telling, -0.5, 5000}, {telling, 1, 5000}]]
    after
        untabled()
    end.

%% report §8.7: a find or a spawn that comes while no run is in progress, as
%% between two runs of `ern test` over a directory in one host, answers
%% Unreachable, which the run's reaper, ended or never begun, cannot answer.
%% A regression test: each raised as it read a run's table that was gone,
%% which killed the gateway's worker, and then each caught any failure of
%% the host's as no run in progress
no_run_test() ->
    Unit = 'ern@peerquiet',
    Hashes = loaded(['Peerquiet'], "export fn quiet() : Unit = Unit\n"),
    true = register(ern_gateway, self()),
    try
        Alias = erlang:alias(),
        ok = ern_peer:frame(self(), {find, <<"k">>, <<0:256>>, Alias}),
        ?assertEqual({Alias, 'Unreachable'}, receive {Alias, _} = Found -> Found end),
        Ref = make_ref(),
        Quiet = {function, maps:get(['Peerquiet', quiet], Hashes)},
        ok = ern_peer:frame(self(), {spawn, Ref, Quiet, <<"M.f:1">>, false, ?MS}),
        ?assertEqual({answer, Ref, {failed, 'Unreachable'}},
                     receive {ern_frame, _, Body} -> Body end),
        %% the reaper of a run that has ended answers nothing
        ?assertEqual(none, ern_rt:asked_of_run({spawn, fun() -> ok end, Unit, [], <<"M.f:1">>,
                                                node()})),
        ?assertEqual(none, ern_rt:asked_of_run({offered, <<"k">>, <<0:256>>}))
    after
        unregister(ern_gateway),
        unloaded(Unit)
    end.

-define(REACHING,
        "let greeting : String = \"hello\"\n"
        "export fn speak() : Unit = Io.println(greeting)\n"
        "export fn quiet() : Unit = Unit\n"
        "export fn twice() : Unit = speak()\n"
        "foreign fn missing() : Unit = \"ern_peer_tests_absent:f/0\"\n"
        "export fn calls() : Unit = missing()\n"
        "export fn later(n : Int) : Either(Io.Error, Address(Never)) =\n"
        "    Peer.spawn(\"p\", fn() = { let _ = n + 1; Unit }, 100)\n").

%% report §8.7: a spawn from a peer starts a function this node holds by its
%% identity, a top-level function by its hash, a lambda by its definition's
%% hash and its position with as many captured values as its entry takes,
%% and `restarting` over one of these, where every binding its reach names
%% has its value in the run, and every module a foreign declaration of its
%% reach calls is here; a function that names no binding starts in a run
%% that never initialized its module, where MVP 3.0's rule by module
%% refused it. Otherwise it answers NotLoaded, and the frame's reading
%% answers what this node lacked, which the gateway says: a binding with no
%% value, which a function it calls names, and a foreign declaration's
%% module. A function it does not hold, by its hash, a lambda by its
%% definition's hash and position, `restarting` over one, and a foreign
%% function it does not have, by its name as text, whose names make no
%% atom here, the frame's reading hands to the exchange by the identity
%% this node lacks, and answers nothing itself (MVP 3.2's items 3 and 4).
%% Nothing is initialized because a peer asked
spawn_by_identity_test() ->
    Unit = 'ern@peerreach',
    Hashes = loaded(['Peerreach'], ?REACHING),
    [Lambda] = [{Hash, Position, Arity}
                || {_, {lambda, Hash, Position, _, Arity, _}} <- Unit:'$code'()],
    Identity = fun(Name) -> {function, maps:get(['Peerreach', Name], Hashes)} end,
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               Spawn = fun(Spawned) ->
                           Ref = make_ref(),
                           Read = ern_peer:frame(self(), {spawn, Ref, Spawned, <<"M.f:1">>,
                                                          false, ?MS}),
                           receive {ern_frame, _, {answer, Ref, Answer}} -> {Answer, Read} end
                       end,
               {LambdaHash, Position, 1} = Lambda,
               Before = [Spawn(Identity(quiet)), Spawn(Identity(speak)), Spawn(Identity(twice)),
                         Spawn(Identity(calls)),
                         Spawn({lambda, LambdaHash, Position, [41]}),
                         Spawn({restarting, {'RestartLimit', 1, 1000}, Identity(quiet)}),
                         Spawn({foreign, [<<"Peerreach">>, <<"missing">>]})],
               Wrong = ern_peer:frame(self(), {spawn, make_ref(),
                                               {lambda, LambdaHash, Position, []},
                                               <<"M.f:1">>, false, ?MS}),
               Lacking = [ern_peer:frame(self(), {spawn, make_ref(), Lacked, <<"M.f:1">>, false,
                                                  ?MS})
                          || Lacked <- [{function, <<7:256>>}, {lambda, <<8:256>>, 2, [1]},
                                        {restarting, 'Unlimited', {function, <<9:256>>}},
                                        {foreign, [<<"Peernone">>, <<"never">>]}]],
               ern_rt:init_modules([Unit]),
               After = Spawn(Identity(twice)),
               Self ! {spawned, Before, Wrong, Lacking, After}
           end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
        {spawned, Before, Wrong, Lacking, After} =
            receive {spawned, _, _, _, _} = Got -> Got end,
        Absent = "the module ern_peer_tests_absent, which Peerreach.missing calls, is not here",
        ?assertMatch([{{spawned, _}, ok}, _, _, _, {{spawned, _}, ok}, {{spawned, _}, ok}, _],
                     Before),
        ?assertEqual([{{failed, 'NotLoaded'}, {not_loaded, spawn, <<"M.f:1">>, Lacked}}
                      || Lacked <- ["the binding Peerreach.greeting has no value here",
                                    "the binding Peerreach.greeting has no value here",
                                    Absent, Absent]],
                     [{Answer, {not_loaded, spawn, Site,
                                lists:flatten(io_lib:format("~ts", [Lacked]))}}
                      || {Answer, {not_loaded, spawn, Site, Lacked}}
                             <- [lists:nth(Index, Before) || Index <- [2, 3, 4, 7]]]),
        ?assertError(badarg, binary_to_existing_atom(<<"Peernone">>)),
        ?assertEqual(unreadable, Wrong),
        ?assertEqual([{exchange, {function, <<7:256>>}}, {exchange, {lambda, <<8:256>>, 2}},
                      {exchange, {function, <<9:256>>}},
                      {exchange, {foreign, [<<"Peernone">>, <<"never">>]}}], Lacking),
        ?assertMatch({{spawned, _}, ok}, After)
    after
        unloaded(Unit)
    end.

-define(HELD,
        "export type Ask = Ask(Reply(Either(Io.Error, Int)))\n"
        "export fn dropping(peer : String) : Unit receiving Ask = receive {\n"
        "    Ask(reply) -> {\n"
        "        let _ = Peer.spawn(peer, fn() = answer(reply, Right(1)), 1000);\n"
        "        dropping(peer)\n"
        "    }\n"
        "}\n"
        "export type Watched = Request(Ask) | Ended(Down)\n"
        "export fn answering(peer : String) : Unit receiving Watched = receive {\n"
        "    Request(ask) -> {\n"
        "        let spawned = Peer.spawnMonitored(peer, fn() =\n"
        "                                              match ask {\n"
        "                                                  Ask(reply) -> answer(reply, Right(2))\n"
        "                                              },\n"
        "                                          fn(down) = Ended(down), 1000);\n"
        "        match spawned {\n"
        "            Left(failure) -> match ask { Ask(reply) -> answer(reply, Left(failure)) }\n"
        "          | Right(_) -> Unit\n"
        "        };\n"
        "        answering(peer)\n"
        "    }\n"
        "  | Ended(_) -> answering(peer)\n"
        "}\n").

%% report §6.6, §8.7: a reply a function spawned on a peer captured crosses
%% as any value does, and the spawner keeps its copy, so a spawn that fails
%% ends no call: the caller waits as on any reply no process has answered.
%% `Address.call` answers None at its deadline, `Address.callForever` waits
%% while the spawner lives and ends as its death ends it, and a spawner
%% that answers through its copy gives the caller the failure; a reply
%% captured alone and one inside a captured value, through Peer.spawn and
%% Peer.spawnMonitored. Here the spawn names no peer, NotListed, in a
%% program that is no node. A regression test, written after the code
%% (MVP 3.26's item 2a); a spawn that fails on a node, and an answer from
%% another node, are the nodes' (test/ern_nodes_tests.erl)
failed_spawn_ends_no_call_test() ->
    Unit = 'ern@peerheld',
    _ = loaded(['Peerheld'], ?HELD),
    Self = self(),
    %% the call's time: an answer that does not come is an absence, which
    %% only a time shows, and any time shows it; the spawn's failure comes
    %% at once, so that a call it ended would answer before the time
    Time = 100,
    Main = fun() ->
               DroppingFunction = ern_named:function(Unit, dropping),
               AnsweringFunction = ern_named:function(Unit, answering),
               Dropping = ern_rt:spawn(fun() -> DroppingFunction(<<"nobody">>) end, <<"M.f:1">>),
               Answering = ern_rt:spawn(fun() -> AnsweringFunction(<<"nobody">>) end,
                                        <<"M.f:2">>),
               Ask = fun(Reply) -> {'Ask', Reply} end,
               Before = erlang:monotonic_time(millisecond),
               Called = ern_rt:call(Dropping, Ask, Time),
               TimeRanOut = erlang:monotonic_time(millisecond) - Before >= Time,
               %% the waits below count as timed, so that they are no
               %% deadlock (§8.6): until the server has taken the first
               %% ask and waits again, until its spawn for a second
               %% caller's ask has failed, and for that caller's end once
               %% the server is killed
               ern_rt:timed(),
               ok = ern_waits:until(Dropping,
                                    fun() ->
                                        erlang:process_info(Dropping, [message_queue_len, status])
                                            =:= [{message_queue_len, 0}, {status, waiting}]
                                    end),
               Caller = self(),
               Forever = fun() ->
                             Caller ! {forever, try ern_rt:call_forever(Dropping, Ask)
                                                catch throw:{ern, fault, Cause} -> {faulted, Cause}
                                                end}
                         end,
               ok = ern_waits:returned(Dropping, {ern_peer, spawn, ['_', '_', '_', '_']},
                                       fun() -> ern_rt:spawn(Forever, <<"M.f:3">>) end),
               ern_rt:kill(Dropping),
               Ended = receive {forever, Faulted} -> Faulted end,
               ern_rt:untimed(),
               Answered = ern_rt:call(Answering, fun(Reply) -> {'Request', {'Ask', Reply}} end,
                                      600000),
               Self ! {ended, Called, TimeRanOut, Ended, Answered, ets:tab2list(ern_callees)},
               ern_rt:kill(Answering)
           end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
        ?assertEqual({ended, 'None', true, {faulted, <<"callee was killed">>},
                      {'Some', {'Left', 'NotListed'}}, []},
                     receive {ended, _, _, _, _, _} = Got -> Got end)
    after
        unloaded(Unit)
    end.

-define(COMPUTED,
        "let greeting : String = \"hello\"\n"
        "export fn answer() : Int = 42\n"
        "export fn divided() : Int = 1 / List.size([])\n"
        "export fn waits() : Int receiving Int = receive { n -> n }\n"
        "export fn greet() : String = greeting\n").

%% report §8.7, §11.2, Appendix E.21: a compute from a peer, its frame noted
%% as the gateway notes it, runs the function in a process of its own, as a
%% spawn would start it, and answers through the caller's alias: the
%% value; a fault in it, its cause and its trace, which this node reports
%% nothing of; NotLoaded where a binding its reach names has no value here,
%% with what this node lacked, which the gateway says of the compute; and a
%% process that ends before it answers its Reason. The call's second note
%% kills the process where it still runs, which then tells no one, and one
%% that came before the process could start leaves it never run, the
%% compute answered Unreachable, which its caller, no longer waiting, drops.
%% A regression test, written after the code; Appendix E.21: the trace that
%% crosses names the definition's frame by its name and its line, a
%% regression test written after the code, where a division's was empty
computed_here_test() ->
    Unit = 'ern@peercomputed',
    Hashes = loaded(['Peercomputed'], ?COMPUTED),
    Identity = fun(Name) -> {function, maps:get(['Peercomputed', Name], Hashes)} end,
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               Compute = fun(Name, Before) ->
                             Alias = erlang:alias([reply]),
                             ok = ern_rt:note_compute(self(), Alias),
                             Before(Alias),
                             Read = ern_peer:frame(self(), {compute, Alias, Identity(Name),
                                                            <<"M.f:1">>, ?MS}),
                             {Read, Alias}
                         end,
               Plain = fun(_) -> ok end,
               Answer = fun(Alias) ->
                            receive
                                {Alias, _, _} = Answered -> Answered;
                                {Alias, _, _, _} = Answered -> Answered
                            end
                        end,
               Running = fun(Alias) ->
                             [{_, Pid, _}] = ets:lookup(ern_notes, {node(), Alias}),
                             Pid
                         end,
               {ok, Valued} = Compute(answer, Plain),
               {ok, Divided} = Compute(divided, Plain),
               {NotLoaded, Greeted} = Compute(greet, Plain),
               {ok, Over} = Compute(waits, fun ern_rt:drop_note/1),
               {ok, Killed} = Compute(waits, Plain),
               KilledPid = Running(Killed),
               exit(KilledPid, {ern, killed}),
               {ok, Late} = Compute(waits, Plain),
               LatePid = Running(Late),
               MonitorRef = erlang:monitor(process, LatePid),
               Reaper = persistent_term:get({ern_rt, reaper}),
               ok = ern_waits:returned(Reaper, {ern_rt, drop_callee_notes, [LatePid, '_']},
                                       fun() -> ern_rt:drop_note(Late) end),
               LateEnd = receive {'DOWN', MonitorRef, process, LatePid, Why} -> Why end,
               Told = receive {Late, _, _} = Message -> Message after 0 -> none end,
               Self ! {computed, [Answer(Valued), Answer(Divided), Answer(Greeted), Answer(Over),
                                  Answer(Killed)],
                       NotLoaded, LateEnd, Told}
           end,
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    try
        %% report §8.6: a node detects no deadlock, and a compute comes to
        %% none other
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end,
                                                             faults => Reporter,
                                                             node => fun() -> ok end})),
        {computed, Answers, NotLoaded, LateEnd, Told} =
            receive {computed, _, _, _, _} = Got -> Got end,
        ?assertMatch([{_, computed, 42},
                      {_, faulted, <<"division by zero">>,
                       <<"erlang:'div'/2\nPeercomputed.divided:3\n", _/binary>>},
                      {_, failed, 'NotLoaded'}, {_, failed, 'Unreachable'},
                      {_, ended, 'Killed'}], Answers),
        {not_loaded, compute, <<"M.f:1">>, Lacked} = NotLoaded,
        ?assertEqual("the binding Peercomputed.greeting has no value here",
                     lists:flatten(io_lib:format("~ts", [Lacked]))),
        ?assertEqual({ern, killed}, LateEnd),
        ?assertEqual(none, Told),
        ?assertEqual(none, receive {reported, Report} -> Report after 0 -> none end)
    after
        unloaded(Unit)
    end.

-define(RESTARTED,
        "type Start = First | AfterFault | Asked\n"
        "foreign fn cause() : Start = \"ern_rt:start_cause/0\"\n"
        "export fn flaky() : Int = match cause() { First -> fault(\"first\")"
        " | _ -> 42 }\n"
        "export fn divided() : Int = 1 / List.size([])\n").

%% report §8.7, §6.9: a compute whose function is `restarting` over one: a
%% restart does not end the compute, the fault it restarts is this node's,
%% reported here as a restarted fault, and the caller is answered by the run
%% that answers; the fault past the limit is carried to the caller, and
%% reported nowhere here. A regression test, written after the code
computed_restarting_test() ->
    Unit = 'ern@peerrestarted',
    Hashes = loaded(['Peerrestarted'], ?RESTARTED),
    Identity = fun(Name) -> {function, maps:get(['Peerrestarted', Name], Hashes)} end,
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               %% the restart asks the gateway, which this process stands in
               %% for, for the notes before it (ern_rt:fresh_run/0), and is
               %% answered as the gateway answers
               Answer = fun Answer(Alias) ->
                            receive
                                {Alias, _, _} = Answered -> Answered;
                                {Alias, _, _, _} = Answered -> Answered;
                                {new_run, Pid, MonitorRef} ->
                                    Pid ! {MonitorRef, fresh},
                                    Answer(Alias)
                            end
                        end,
               Compute = fun(Spawned) ->
                             Alias = erlang:alias([reply]),
                             ok = ern_rt:note_compute(self(), Alias),
                             ok = ern_peer:frame(self(),
                                                 {compute, Alias, Spawned, <<"M.f:1">>, ?MS}),
                             Answer(Alias)
                         end,
               Restarted = Compute({restarting, {'RestartLimit', 1, 60000}, Identity(flaky)}),
               PastLimit = Compute({restarting, {'RestartLimit', 0, 60000}, Identity(divided)}),
               Self ! {computed, Restarted, PastLimit}
           end,
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end,
                                                             faults => Reporter,
                                                             node => fun() -> ok end})),
        ?assertMatch({computed, {_, computed, 42},
                      {_, faulted, <<"division by zero">>,
                       <<"erlang:'div'/2\nPeerrestarted.divided:4\n", _/binary>>}},
                     receive {computed, _, _} = Got -> Got end),
        ?assertMatch({reported, {'FaultReport', _, <<"M.f:1">>, <<"first">>, true, _, _}},
                     receive {reported, _} = Reported -> Reported end),
        ?assertEqual(none, receive {reported, Report} -> Report after 0 -> none end)
    after
        unloaded(Unit)
    end.

%% report §8.7, §6.6, §11.2: a compute's caller waits as a call's caller
%% does, on one host its peer's gateway a process that records each frame:
%% the frame names the caller's alias, through which the value, a failure,
%% a fault with the stack that crossed, which faults the caller and which
%% its report prints, and the Reason of a process that ended before it
%% answered come, each letting the caller's CALL key go with no second
%% note; where the time runs out, or the caller is killed while it waits,
%% the second note follows; and where the gateway is gone the wait ends
%% Unreachable, the key gone with each. A regression test, written after
%% the code
compute_caller_test() ->
    Self = self(),
    Frame = fun(Alias) -> {compute, Alias, {function, <<0:256>>}, <<"M.f:1">>, ?MS} end,
    Gateway = fun Gateway(Told, Answers) ->
                  receive
                      {ern_frame, From, {compute, Alias, _, _, _}} ->
                          Told ! {noted, From},
                          case Answers of
                              [Answer | Rest] ->
                                  Alias ! list_to_tuple([Alias | Answer]),
                                  Gateway(Told, Rest);
                              [] ->
                                  Gateway(Told, [])
                          end;
                      {ern_frame, From, {call_over, _}} ->
                          Told ! {over, From},
                          Gateway(Told, Answers);
                      stop ->
                          ok
                  end
              end,
    Main = fun() ->
               Told = self(),
               Recorder = spawn(fun() ->
                                    true = register(ern_gateway, self()),
                                    Told ! registered,
                                    Gateway(Told, [[computed, 7], [failed, 'NotLoaded'],
                                                   [ended, 'ProgramEnd'],
                                                   [faulted, <<"x">>, <<"M.f:4\n">>]])
                                end),
               receive registered -> ok end,
               Compute = fun(Ms) -> ern_rt:compute(node(), Frame, ern_rt:deadline(Ms)) end,
               Answered = [Compute(600000), Compute(600000), Compute(600000)],
               Faulting = ern_rt:spawn_monitored(fun() -> Compute(600000) end,
                                                 fun(Down) -> Down end, <<"M.f:2">>),
               Faulted = receive {'Down', Faulting, Reason, _} -> Reason end,
               TimedOut = Compute(0),
               %% the gateway told of each frame in the order they came: a
               %% second note follows the time run out alone
               Frames = [receive {Kind, From} when Kind =:= noted; Kind =:= over -> {Kind, From} end
                         || _ <- lists:seq(1, 6)],
               Waiting = ern_rt:spawn(fun() -> Compute(600000) end, <<"M.f:3">>),
               receive {noted, Waiting} -> ern_rt:kill(Waiting) end,
               WaitingOver = receive {over, WaitingCaller} -> WaitingCaller end,
               MonitorRef = erlang:monitor(process, Recorder),
               Recorder ! stop,
               receive {'DOWN', MonitorRef, process, Recorder, _} -> ok end,
               Lost = Compute(600000),
               Me = self(),
               Self ! {caller, Answered, Faulted, TimedOut,
                       Frames =:= [{noted, Me}, {noted, Me}, {noted, Me}, {noted, Faulting},
                                   {noted, Me}, {over, Me}],
                       WaitingOver =:= Waiting, {Lost, get('$ern_call')}}
           end,
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end,
                                                         faults => Reporter,
                                                         node => fun() -> ok end})),
    ?assertEqual({caller, [{'Right', 7}, {'Left', 'NotLoaded'},
                           {'Left', {'Other', <<"ProgramEnd">>}}],
                  {'Fault', <<"x">>}, {'Left', 'Timeout'}, true, true,
                  {{'Left', 'Unreachable'}, undefined}},
                 receive {caller, _, _, _, _, _, _} = Got -> Got end),
    ?assertMatch({reported, {'FaultReport', _, <<"M.f:2">>, <<"x">>, false, <<"M.f:4\n">>,
                             'None'}},
                 receive {reported, _} = Reported -> Reported end).

%% report §8.7, §6.9: a peer's kill frame, the fifteenth frame, ends a
%% process of this node as this node's own kill does: a caller waiting in
%% a compute on a peer is killed and its call's second note follows, as a
%% caller killed here sends it (compute_caller_test); a kill of a process
%% that has ended does nothing; and a frame naming a process of another
%% node is one this node cannot read. Here a gateway of this host's stands
%% in for the peer's, and the frame is read as the gateway's worker reads
%% it. A regression test, written after the code; a frame between real
%% nodes is test/ern_nodes_tests.erl's, which reads no row of a node
kill_frame_test() ->
    Self = self(),
    Frame = fun(Alias) -> {compute, Alias, {function, <<0:256>>}, <<"M.f:1">>, ?MS} end,
    Main = fun() ->
               Told = self(),
               Gateway = spawn(fun Gateway() ->
                                   receive
                                       {ern_frame, From, {compute, _, _, _, _}} ->
                                           Told ! {noted, From}, Gateway();
                                       {ern_frame, From, {call_over, _}} ->
                                           Told ! {over, From}, Gateway();
                                       stop -> ok
                                   end
                               end),
               true = register(ern_gateway, Gateway),
               Waiting = ern_rt:spawn(fun() ->
                                          ern_rt:compute(node(), Frame, ern_rt:deadline(600000))
                                      end, <<"M.f:2">>),
               MonitorRef = erlang:monitor(process, Waiting),
               ern_rt:timed(),
               receive {noted, Waiting} -> ok end,
               Killed = ern_peer:frame(self(), {kill, Waiting}),
               Over = receive {over, From} -> From end,
               Reason = receive {'DOWN', MonitorRef, process, Waiting, Why} -> Why end,
               Again = ern_peer:frame(self(), {kill, Waiting}),
               Far = binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>),
               Unreadable = ern_peer:frame(self(), {kill, Far}),
               ern_rt:untimed(),
               GatewayRef = erlang:monitor(process, Gateway),
               Gateway ! stop,
               receive {'DOWN', GatewayRef, process, Gateway, _} -> ok end,
               Self ! {killed, {Killed, Over =:= Waiting, Reason, Again, Unreadable}}
           end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
    ?assertEqual({killed, {ok, true, {ern, killed}, ok, unreadable}},
                 receive {killed, _} = Got -> Got end).

%% report §8.7, Appendix E.27: a program that is no node has no peers, so
%% a compute on a peer named or picked and a utilization answer NotListed,
%% as a find and a spawn do, and it holds no utilization. A regression test,
%% written after the code
no_node_test() ->
    ?assertEqual({'Left', 'NotListed'},
                 ern_peer:compute_at(<<"worker">>, {function, <<0:256>>}, 1000, <<"M.f:1">>)),
    ?assertEqual({'Left', 'NotListed'},
                 ern_peer:compute({function, <<0:256>>}, 1000, <<"M.f:1">>)),
    ?assertEqual({'Left', 'NotListed'}, ern_peer:utilization(<<"worker">>, 1000)),
    ?assertEqual([], ern_peer:utilizations()).

%% report §8.7: a function whose reach names a binding through a group, a
%% type whose compare reads a binding of its module, starts nothing where
%% that binding has no value: the spawn answers NotLoaded, naming it, as
%% for any binding of a reach. A regression test, written after the fix: a
%% group's binding was in no reach, and the function started, to fault
%% reading the binding
group_binding_test() ->
    Unit = 'ern@peergroup',
    Hashes = loaded(['Peergroup'],
                    "type T = T(Int)\n"
                    "let zero : T = T(0)\n"
                    "fn T.compare(a : T, b : T) : Ordering = if a == zero then Less else Equal\n"
                    "export fn ordered() : Unit = { let _ = T(1) < T(2); Unit }\n"),
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               Ref = make_ref(),
               Spawned = {function, maps:get(['Peergroup', ordered], Hashes)},
               Read = ern_peer:frame(self(), {spawn, Ref, Spawned, <<"M.f:1">>, false, ?MS}),
               receive {ern_frame, _, {answer, Ref, Answer}} -> Self ! {spawned, Answer, Read} end
           end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
        {spawned, Answer, {not_loaded, spawn, Site, Lacked}} =
            receive {spawned, _, _} = Got -> Got end,
        ?assertEqual({{failed, 'NotLoaded'}, <<"M.f:1">>,
                      "the binding Peergroup.zero has no value here"},
                     {Answer, Site, lists:flatten(io_lib:format("~ts", [Lacked]))})
    after
        unloaded(Unit)
    end.

%% report §8.7, §11.1: a spawn on a peer names a lambda or a local fn by
%% its identity with the values it captured, in the order its body first
%% names them, whatever order they were bound in: the frame the compiled
%% spawn sends, read from the module's forms, each capture known by the
%% value its `let` bound. A regression test, written after the code
spawn_captures_in_order_test() ->
    Text = "export fn start(peer : String) : Unit = {\n"
           "    let b = \"B\";\n"
           "    let a = \"A\";\n"
           "    let n = 6;\n"
           "    let _ = Peer.spawn(peer, fn() =\n"
           "                                 Io.println(a <> b <> Int.toString(n)), 100);\n"
           "    fn local() : Unit = Io.println(b <> a);\n"
           "    let _ = Peer.spawn(peer, local, 100);\n"
           "    Unit\n"
           "}\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['Captures'], Text),
    Forms = ern_compile:forms(['Captures'], Typed, Env),
    Bound = maps:from_list(
              found(fun({match, _, {var, _, Variable}, {Kind, _, _} = Value})
                          when Kind =:= bin; Kind =:= integer ->
                            {Variable, erl_parse:normalise(Value)};
                       (_) ->
                            false
                    end, Forms)),
    Frames = found(fun({call, _, {remote, _, {atom, _, ern_peer}, {atom, _, spawn}},
                        [_, {tuple, _, [{atom, _, lambda}, _, {integer, _, Position}, Captures]}
                         | _]}) ->
                           Variables = [Variable || {var, _, Variable}
                                                        <- erl_syntax:list_elements(Captures)],
                           {Position, [maps:get(Variable, Bound) || Variable <- Variables]};
                      (_) ->
                           false
                   end, Forms),
    ?assertEqual([{1, [<<"A">>, <<"B">>, 6]}, {2, [<<"B">>, <<"A">>]}], Frames).

%% What Test finds in Term and in every term within it, outermost first.
found(Test, Term) ->
    Here = case Test(Term) of
               false -> [];
               Found -> [Found]
           end,
    Within = if
                 is_tuple(Term) -> tuple_to_list(Term);
                 is_list(Term) -> Term;
                 true -> []
             end,
    Here ++ lists:append([found(Test, Part) || Part <- Within]).

%% A module compiled as the build compiles it, loaded and in the code table
%% as the runner puts a unit there; its definitions' hashes by their
%% qualified names.
loaded(Namespace, Text) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => []},
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    ok = ern_code:loaded(Unit, Beam),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    maps:from_list([{QualifiedName, Hash}
                    || #definition{qualified_name = QualifiedName, hash = Hash} <- Definitions]).

unloaded(Unit) ->
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit),
    code:purge(Unit).

%% Appendix E.22: a child whose supervisor runs on another node faults
%% before it joins
supervisor_on_another_node_test() ->
    Elsewhere = binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>),
    ?assertEqual(false, ern_rt:on_this_node(Elsewhere)),
    ?assert(ern_rt:on_this_node(self())),
    Child = (ern_named:function('ern@supervisor', child))(Elsewhere, fun() -> 'Unit' end),
    ?assertThrow({ern, fault, <<"a child runs on its supervisor's node">>}, Child()).

%% report §8.7: an offer lasts as long as its process lives, a process the
%% runtime did not start among them, a foreign one, whose rows go with it.
%% A regression test: such a process's offer outlived it, the reaper
%% watching only the processes the runtime started or opened
foreign_offer_test() ->
    Self = self(),
    Main = fun() ->
               Foreign = spawn(fun() -> receive stop -> ok end end),
               ern_peer:offer({'Service', <<"foreign">>, <<0:256>>}, Foreign),
               Self ! {offered, ern_rt:offered(<<"foreign">>, <<0:256>>)},
               %% the reaper takes the offer away as it learns of the end
               Reaper = persistent_term:get({ern_rt, reaper}),
               ok = ern_waits:returned(Reaper, {ern_rt, unoffered, [Foreign]},
                                       fun() -> Foreign ! stop end),
               Self ! {ended, ern_rt:offered(<<"foreign">>, <<0:256>>)}
           end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
    ?assertMatch({offered, {found, _}}, receive {offered, _} = Offered -> Offered end),
    ?assertEqual({ended, 'NotOffered'}, receive {ended, _} = Ended -> Ended end).

%% report §8.7, Appendix E.27: an offer answers Right(Unit) where it took
%% the service, and Left(holder) where a living process's address is
%% offered as it, the holder's Process, the same whoever offers; the caller
%% monitors the holder, which is killed, and at its Down offers again and
%% takes the service, which a find on this node then answers. A regression
%% test, written after the code, which named the holder in a fault before;
%% two offers racing for a dead holder's service are not covered
held_service_test() ->
    Self = self(),
    Main = fun() ->
               Service = {'Service', <<"held">>, <<0:256>>},
               Holder = ern_rt:spawn(fun() -> receive stop -> ok end end, <<"M.holder">>),
               Newcomer = ern_rt:spawn(fun() -> receive stop -> ok end end, <<"M.newcomer">>),
               Taken = ern_peer:offer(Service, Holder),
               Held = ern_peer:offer(Service, Newcomer),
               Again = ern_peer:offer(Service, ern_rt:adapted(Holder, fun(Message) -> Message end)),
               ern_rt:monitor(Holder, fun(Down) -> {ended, Down} end),
               ern_rt:kill(Holder),
               Down = receive {ended, Ended} -> Ended end,
               Self ! {offers, Holder, Newcomer, [Taken, Held, Again], Down,
                       ern_peer:offer(Service, Newcomer), ern_rt:offered(<<"held">>, <<0:256>>)}
           end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
    {offers, Holder, Newcomer, Answers, Down, Taken, Found} =
        receive {offers, _, _, _, _, _, _} = Offers -> Offers end,
    ?assertEqual([{'Right', 'Unit'}, {'Left', Holder}, {'Left', Holder}], Answers),
    ?assertEqual({'Down', Holder, 'Killed', <<"M.holder">>}, Down),
    ?assertEqual({'Right', 'Unit'}, Taken),
    ?assertEqual({found, Newcomer}, Found).

%% report §8.7, §6.6: a call's note on a process the runtime did not start,
%% a foreign one whose address of an unbound type crossed, goes with its
%% row of the callees when that process ends without answering. A
%% regression test: the reaper did not watch such a callee, so its notes
%% were never let go
foreign_callee_test() ->
    Self = self(),
    Main = fun() ->
               Foreign = spawn(fun() -> receive stop -> ok end end),
               Caller = binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>),
               Reply = make_ref(),
               ok = ern_rt:note_call(Foreign, Caller, Reply),
               Self ! {noted, ets:tab2list(ern_notes), ets:tab2list(ern_callees)},
               Reaper = persistent_term:get({ern_rt, reaper}),
               ok = ern_waits:returned(Reaper, {ern_rt, drop_callee_notes, [Foreign, '_']},
                                       fun() -> Foreign ! stop end),
               Self ! {ended, ets:tab2list(ern_notes), ets:tab2list(ern_callees)}
           end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
    ?assertMatch({noted, [_], [_]}, receive {noted, _, _} = Noted -> Noted end),
    ?assertEqual({ended, [], []}, receive {ended, _, _} = Ended -> Ended end).

%% report §8.7, §6.9: a restart on a node asks its gateway, as it asks the
%% reaper, before it reads the calls waiting on the process, so that it
%% reads every note the gateway took before it. Here a stand-in gateway
%% records the note only when the restart asks it, so the caller is told
%% only if the restart asked. A regression test: on real nodes the note came
%% first whether or not the restart asked, so they could not show it
restart_asks_gateway_test() ->
    Self = self(),
    Main = fun() ->
               Entry = self(),
               Callee = ern_rt:spawn(ern_rt:restarting('Unlimited', fun crashes/0), <<"M.f:1">>),
               Caller = spawn(fun() ->
                                  Reply = erlang:alias(),
                                  Entry ! {reply, Reply},
                                  receive {Reply, restarted, Cause} -> Entry ! {told, Cause} end
                              end),
               Reply = receive {reply, Made} -> Made end,
               Gateway = spawn(fun() ->
                                   receive
                                       {new_run, Pid, MonitorRef} ->
                                           ern_rt:note_call(Callee, Caller, Reply),
                                           Pid ! {MonitorRef, fresh}
                                   end
                               end),
               true = register(ern_gateway, Gateway),
               Callee ! crash,
               Self ! receive {told, _} = Told -> Told end
           end,
    Quiet = #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end},
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, Quiet)),
    ?assertEqual({told, <<"crashed">>}, receive {told, _} = Told -> Told end).

crashes() ->
    receive crash -> ern_rt:fault(<<"crashed">>) end.

%% Appendix G.7: a proxy makes one find at a time. Two messages
%% that come while a find is under way wait for it and share its outcome:
%% where it fails, both go to the last address held, the process that
%% stands where no address has been found, and neither starts a find of its
%% own; a message that comes after the failure starts one. In a run that is
%% no node a find answers NotListed at once, so the host holds the proxy's
%% process still while the two come, as a find under way holds it, and its
%% finds and its sends are read by tracing it; each unit's function by its
%% number (report §11.1)
proxy_one_find_test() ->
    Proxy = library("proxy"),
    Start = ern_named:function(Proxy, start),
    {Find, 2} = ern_code:function('ern@peer', ['Peer', find]),
    Self = self(),
    Main = fun() ->
               ern_rt:init_modules([Proxy]),
               Service = {'Service', <<"probe">>, <<0:256>>},
               {adapted, _, Forwarder, _, _} = Address = Start(Service, 1000),
               %% the first find made, the process waits for a message
               ok = ern_waits:until(Forwarder, fun() -> holds(Proxy, Forwarder) end),
               1 = erlang:trace_pattern({'ern@peer', Find, 2}, true, [local]),
               erlang:trace(Forwarder, true, [call, send]),
               true = erlang:suspend_process(Forwarder),
               ern_rt:send(Address, 1),
               ern_rt:send(Address, 2),
               true = erlang:resume_process(Forwarder),
               During = traced(Forwarder, Find, 2),
               ern_rt:send(Address, 3),
               After = traced(Forwarder, Find, 3),
               erlang:trace(Forwarder, false, [call, send]),
               erlang:trace_pattern({'ern@peer', Find, 2}, false, [local]),
               Self ! {traced, During, After}
           end,
    Quiet = #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end},
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, Quiet)),
    {traced, During, After} = receive {traced, _, _} = Traced -> Traced end,
    [_, {sent, 1, Nowhere} | _] = During,
    ?assertEqual([find, {sent, 1, Nowhere}, {sent, 2, Nowhere}], During),
    ?assertEqual([find, {sent, 3, Nowhere}], After),
    ?assertNot(is_process_alive(Nowhere)).

%% A library's module, compiled under build/libs, loaded.
library(Name) ->
    Erc = filename:join(["../../../build/libs", Name, Name ++ ".erc"]),
    {ok, Bytes} = file:read_file(Erc),
    Unit = list_to_atom("ern@" ++ Name),
    {module, Unit} = code:load_binary(Unit, Erc, Bytes),
    Unit.

%% Whether the proxy's process waits for its next message, in its function
%% `held`.
holds(Proxy, Forwarder) ->
    {Held, 4} = ern_code:function(Proxy, ['Proxy', held]),
    erlang:process_info(Forwarder, [status, current_function])
        =:= [{status, waiting}, {current_function, {Proxy, Held, 4}}].

%% What the traced process did, a find, a call of Peer.find's function
%% Find, or a message sent and to whom, up to the message Last sent.
traced(Pid, Find, Last) ->
    receive
        {trace, Pid, call, {'ern@peer', Find, _}} ->
            [find | traced(Pid, Find, Last)];
        {trace, Pid, Sent, Message, To} when Sent =:= send;
                                            Sent =:= send_to_non_existing_process ->
            case Message of
                Last -> [{sent, Message, To}];
                _ -> [{sent, Message, To} | traced(Pid, Find, Last)]
            end
    end.
