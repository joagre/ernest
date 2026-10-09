%% Report §8.7, Appendix E.27, E.22: what a node's gateway does with a
%% spawn's answer and a spawn from a peer, and a supervisor's child on
%% another node, each where a run of real nodes cannot show it whenever it
%% runs. Real nodes are test/ern_nodes_tests.erl's. Regression tests,
%% written after the code: they do not cover a spawn that starts, which the
%% real nodes do.
-module(ern_peer_tests).

-include_lib("eunit/include/eunit.hrl").

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
        Via = fun(Message) -> Message end,
        [?assertEqual(unreadable, ern_peer:frame(self(), Body))
         || Body <- [{answer, make_ref(), garbage}, {answer, make_ref(), {failed, 'Other'}},
                     {answer, make_ref(), {spawned, Elsewhere}}, {answer, nothing, {spawned, Here}},
                     {find, 1, <<"Int">>, make_ref()}, {via, {via, Via, Here, Elsewhere}, 1},
                     {via, not_an_address, 1}, {spawn, make_ref(), not_a_function, <<"s">>, false}]]
    after
        ets:delete(ern_spawns)
    end.

%% report §8.7: a find or a spawn that comes while no run is in progress, as
%% between two runs of `ern test` over a directory in one host, answers
%% Unreachable. A regression test: each raised as it read a run's table that
%% was gone, which killed the gateway's worker
no_run_test() ->
    Function = fun() -> ok end,
    true = register(ern_gateway, self()),
    try
        Alias = erlang:alias(),
        ok = ern_peer:frame(self(), {find, <<"k">>, <<"Int">>, Alias}),
        ?assertEqual({Alias, 'Unreachable'}, receive {Alias, _} = Found -> Found end),
        Ref = make_ref(),
        ok = ern_peer:frame(self(), {spawn, Ref, Function, <<"M.f:1">>, false}),
        ?assertEqual({answer, Ref, {failed, 'Unreachable'}},
                     receive {ern_frame, _, Body} -> Body end),
        %% the reaper of a run that has ended starts nothing
        ?assertEqual(none, ern_rt:spawn_for_peer(Function, <<"M.f:1">>))
    after
        unregister(ern_gateway)
    end.

%% report §8.7: a function of a module this node has at another version,
%% as another shell's input of the same name, starts nothing, and the
%% spawner's gateway is answered NotLoaded; a frame of no kind the gateway
%% reads is unreadable
not_loaded_test() ->
    Module = ern_peer_tests_version,
    Function = (loaded_version(Module, 1)):version(),
    _ = loaded_version(Module, 2),
    true = register(ern_gateway, self()),
    try
        Ref = make_ref(),
        ok = ern_peer:frame(self(), {spawn, Ref, Function, <<"M.f:1">>, false}),
        ?assertEqual({answer, Ref, {failed, 'NotLoaded'}},
                     receive {ern_frame, _, Body} -> Body end),
        ?assertEqual(unreadable, ern_peer:frame(self(), {a_kind, it_has_not}))
    after
        unregister(ern_gateway),
        code:purge(Module),
        code:delete(Module),
        code:purge(Module)
    end.

%% A module whose version/0 answers a function written in it, at the
%% version given, loaded.
loaded_version(Module, Version) ->
    Forms = [{attribute, 1, module, Module}, {attribute, 2, export, [{version, 0}]},
             {function, 3, version, 0,
              [{clause, 3, [], [], [{'fun', 3, {clauses, [{clause, 3, [], [],
                                                           [{integer, 3, Version}]}]}}]}]}],
    {ok, Module, Beam} = compile:forms(Forms, []),
    {module, Module} = code:load_binary(Module, "version", Beam),
    Module.

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
               ern_peer:offer({'Key', <<"foreign">>, <<"Int">>}, Foreign),
               Self ! {offered, ern_rt:offered(<<"foreign">>, <<"Int">>)},
               %% the reaper takes the offer away as it learns of the end
               Reaper = persistent_term:get({ern_rt, reaper}),
               ok = ern_waits:returned(Reaper, {ern_rt, unoffered, [Foreign]},
                                       fun() -> Foreign ! stop end),
               Self ! {ended, ern_rt:offered(<<"foreign">>, <<"Int">>)}
           end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})),
    ?assertMatch({offered, {found, _}}, receive {offered, _} = Offered -> Offered end),
    ?assertEqual({ended, 'NotOffered'}, receive {ended, _} = Ended -> Ended end).

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
