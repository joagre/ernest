%% Report §8.7, Appendix E.27, E.22, G.7: what a node's gateway does with a
%% spawn's answer and a spawn from a peer, a supervisor's child on another
%% node, and a proxy's finds, each where a run of real nodes
%% cannot show it whenever it runs. Real nodes are test/ern_nodes_tests.erl's.
%% Regression tests, written after the code, the spawn by identity's (MVP
%% 3.1's item 4) among them; the proxy's was written before.
-module(ern_peer_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_canonical.hrl").

%% report §8.7: a spawn's answer goes to the process that waits for it, and
%% one that comes after the spawner stopped waiting ends the process it
%% names
answer_test() ->
    ok = ern_peer:tables(),
    try
        Ref = make_ref(),
        true = ets:insert(ern_spawns, {{node(), Ref}, self()}),
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
        ets:delete(ern_spawns)
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
        true = ets:insert(ern_spawns, {{node(), Ref}, Dead}),
        Started = spawn(fun() -> receive after infinity -> ok end end),
        MonitorRef = erlang:monitor(process, Started),
        ok = ern_peer:frame(self(), {answer, Ref, {spawned, Started}}),
        ?assertEqual({ern, killed}, receive {'DOWN', MonitorRef, process, Started, Why} -> Why end),
        ?assertEqual([], ets:tab2list(ern_spawns)),
        Lost = 'lost@node.ernest',
        [Living, Gone, Other] = [make_ref() || _ <- [1, 2, 3]],
        true = ets:insert(ern_spawns, [{{Lost, Living}, self()}, {{Lost, Gone}, Dead},
                                       {{'other@node.ernest', Other}, self()}]),
        ok = ern_peer:lost(Lost),
        ?assertEqual({Living, {failed, 'Unreachable'}}, receive {Living, _} = Got -> Got end),
        ?assertEqual([{{'other@node.ernest', Other}, self()}], ets:tab2list(ern_spawns))
    after
        ets:delete(ern_spawns)
    end.

%% report §8.7: a frame whose fields are not those of its kind is one the
%% gateway cannot read: an answer that names no spawn's outcome, or a
%% process of another node than the peer's, a find whose name is no text,
%% and a message to an adapted address another node made. A regression
%% test: each frame was read by its tag alone, and one that raised killed
%% the gateway's worker, every later frame from the peer lost
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
                     {adapted, {adapted, Wrap, Here, Elsewhere}, 1},
                     {adapted, not_an_address, 1},
                     {spawn, make_ref(), not_a_function, <<"s">>, false},
                     {spawn, make_ref(), {function, <<"short">>}, <<"s">>, false},
                     {spawn, make_ref(), {lambda, <<0:256>>, 0, []}, <<"s">>, false},
                     {spawn, make_ref(), {foreign, []}, <<"s">>, false},
                     {spawn, make_ref(), {foreign, [peer, tests]}, <<"s">>, false},
                     {spawn, make_ref(), {restarting, 'Unlimited',
                                          {restarting, 'Unlimited', {function, <<0:256>>}}},
                      <<"s">>, false},
                     {spawn, make_ref(), {restarting, forever, {function, <<0:256>>}}, <<"s">>,
                      false}]]
    after
        ets:delete(ern_spawns)
    end.

%% report §8.7: a find or a spawn that comes while no run is in progress, as
%% between two runs of `ern test` over a directory in one host, answers
%% Unreachable, which the run's reaper, ended or never begun, cannot answer.
%% A regression test: each raised as it read a run's table that was gone,
%% which killed the gateway's worker, and then each caught any failure of
%% the host's as no run in progress
no_run_test() ->
    Unit = 'ern@peerquiet',
    Hashes = loaded(['Peerquiet'], "export fn quiet() : Unit with Never = Unit\n"),
    true = register(ern_gateway, self()),
    try
        Alias = erlang:alias(),
        ok = ern_peer:frame(self(), {find, <<"k">>, <<0:256>>, Alias}),
        ?assertEqual({Alias, 'Unreachable'}, receive {Alias, _} = Found -> Found end),
        Ref = make_ref(),
        Quiet = {function, maps:get(['Peerquiet', quiet], Hashes)},
        ok = ern_peer:frame(self(), {spawn, Ref, Quiet, <<"M.f:1">>, false}),
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
        "export fn speak() : Unit with Never = Io.println(greeting)\n"
        "export fn quiet() : Unit with Never = Unit\n"
        "export fn twice() : Unit with Never = speak()\n"
        "foreign fn missing() : Unit with m = \"ern_peer_tests_absent:f/0\"\n"
        "export fn calls() : Unit with Never = missing()\n"
        "export fn later(n : Int) : Either(Io.Error, Address(Never)) with m =\n"
        "    Peer.spawn(\"p\", fn() : Unit with Never = { let _ = n + 1; Unit }, 100)\n").

%% report §8.7: a spawn from a peer starts a function this node holds by its
%% identity, a top-level function by its hash, a lambda by its definition's
%% hash and its position with as many captured values as its entry takes,
%% and `restarting` over one of these, where every binding its reach names
%% has its value in the run, and every module a foreign declaration of its
%% reach calls is here; a function that names no binding starts in a run
%% that never initialized its module, where MVP 3.0's rule by module
%% refused it. Otherwise it answers NotLoaded, and the frame's reading
%% answers what this node lacked, which the gateway says: a function it
%% does not hold, by its hash, a binding with no value, which a function it
%% calls names, and a foreign declaration's module, or a foreign function
%% it does not have, whose names make no atom here. Nothing is initialized
%% because a peer asked
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
                                                          false}),
                           receive {ern_frame, _, {answer, Ref, Answer}} -> {Answer, Read} end
                       end,
               {LambdaHash, Position, 1} = Lambda,
               Before = [Spawn(Identity(quiet)), Spawn(Identity(speak)), Spawn(Identity(twice)),
                         Spawn(Identity(calls)), Spawn({function, <<7:256>>}),
                         Spawn({lambda, LambdaHash, Position, [41]}),
                         Spawn({restarting, {'RestartLimit', 1, 1000}, Identity(quiet)}),
                         Spawn({foreign, [<<"Peerreach">>, <<"missing">>]}),
                         Spawn({foreign, [<<"Peernone">>, <<"never">>]})],
               Wrong = ern_peer:frame(self(), {spawn, make_ref(),
                                               {lambda, LambdaHash, Position, []},
                                               <<"M.f:1">>, false}),
               ern_rt:init_modules([Unit]),
               After = Spawn(Identity(twice)),
               Self ! {spawned, Before, Wrong, After}
           end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
        {spawned, Before, Wrong, After} = receive {spawned, _, _, _} = Got -> Got end,
        Hex = binary_to_list(binary:encode_hex(<<7:256>>, lowercase)),
        Absent = "the module ern_peer_tests_absent, which Peerreach.missing calls, is not here",
        ?assertMatch([{{spawned, _}, ok}, _, _, _, _, {{spawned, _}, ok}, {{spawned, _}, ok}, _,
                      _], Before),
        ?assertEqual([{{failed, 'NotLoaded'}, {not_loaded, <<"M.f:1">>, Lacked}}
                      || Lacked <- ["the binding Peerreach.greeting has no value here",
                                    "the binding Peerreach.greeting has no value here",
                                    Absent, "this node does not have its function, " ++ Hex,
                                    Absent, "this node does not have Peernone.never"]],
                     [{Answer, {not_loaded, Site, lists:flatten(io_lib:format("~ts", [Lacked]))}}
                      || {Answer, {not_loaded, Site, Lacked}}
                             <- [lists:nth(Index, Before) || Index <- [2, 3, 4, 5, 8, 9]]]),
        ?assertError(badarg, binary_to_existing_atom(<<"Peernone">>)),
        ?assertEqual(unreadable, Wrong),
        ?assertMatch({{spawned, _}, ok}, After)
    after
        unloaded(Unit)
    end.

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
                    "export fn ordered() : Unit with Never = { let _ = T(1) < T(2); Unit }\n"),
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               Ref = make_ref(),
               Spawned = {function, maps:get(['Peergroup', ordered], Hashes)},
               Read = ern_peer:frame(self(), {spawn, Ref, Spawned, <<"M.f:1">>, false}),
               receive {ern_frame, _, {answer, Ref, Answer}} -> Self ! {spawned, Answer, Read} end
           end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
        {spawned, Answer, {not_loaded, Site, Lacked}} = receive {spawned, _, _} = Got -> Got end,
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
    Text = "export fn start(peer : String) : Unit with m = {\n"
           "    let b = \"B\";\n"
           "    let a = \"A\";\n"
           "    let n = 6;\n"
           "    let _ = Peer.spawn(peer, fn() : Unit with Never =\n"
           "                                 Io.println(a <> b <> Int.toString(n)), 100);\n"
           "    fn local() : Unit with Never = Io.println(b <> a);\n"
           "    let _ = Peer.spawn(peer, local, 100);\n"
           "    Unit\n"
           "}\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['Captures'], Text),
    Forms = ern_emitter:forms(['Captures'], Typed, Env),
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
    {ok, Unit, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    ok = ern_code:loaded(Unit),
    {ok, Definitions} = ern_canonical:read(Beam),
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
    Child = 'ern@supervisor':child(Elsewhere, fun() -> 'Unit' end),
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
               ok = ern_waits:returned(Reaper, {ern_rt, drop_callee_notes, [Foreign]},
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
%% finds and its sends are read by tracing it
proxy_one_find_test() ->
    Proxy = library("proxy"),
    Self = self(),
    Main = fun() ->
               ern_rt:init_modules([Proxy]),
               Service = {'Service', <<"probe">>, <<0:256>>},
               {adapted, _, Forwarder, _} = Address = Proxy:start(Service, 1000),
               %% the first find made, the process waits for a message
               ok = ern_waits:until(Forwarder, fun() -> holds(Proxy, Forwarder) end),
               1 = erlang:trace_pattern({'ern@peer', find, 2}, true, [local]),
               erlang:trace(Forwarder, true, [call, send]),
               true = erlang:suspend_process(Forwarder),
               ern_rt:send(Address, 1),
               ern_rt:send(Address, 2),
               true = erlang:resume_process(Forwarder),
               During = traced(Forwarder, 2),
               ern_rt:send(Address, 3),
               After = traced(Forwarder, 3),
               erlang:trace(Forwarder, false, [call, send]),
               erlang:trace_pattern({'ern@peer', find, 2}, false, [local]),
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

%% Whether the proxy's process waits for its next message.
holds(Proxy, Forwarder) ->
    erlang:process_info(Forwarder, [status, current_function])
        =:= [{status, waiting}, {current_function, {Proxy, held, 4}}].

%% What the traced process did, a find or a message sent and to whom, up to
%% the message Last sent.
traced(Pid, Last) ->
    receive
        {trace, Pid, call, {'ern@peer', find, _}} ->
            [find | traced(Pid, Last)];
        {trace, Pid, Sent, Message, To} when Sent =:= send;
                                            Sent =:= send_to_non_existing_process ->
            case Message of
                Last -> [{sent, Message, To}];
                _ -> [{sent, Message, To} | traced(Pid, Last)]
            end
    end.
