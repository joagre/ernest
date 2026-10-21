%% Report §8.7, The exchange: a node's exchange, both its parts, in one
%% host, the test standing in for the gateway, which the exchange sends
%% every frame to, and for the peer, whose frames it sends the exchange as
%% a gateway hands them on. Each runs in a program, whose standard error
%% takes the node's lines. Real nodes are test/ern_nodes_tests.erl's.
%% Regression tests, written after the code (MVP 3.2's items 3 and 4).
-module(ern_exchange_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("checker/include/ern_canonical.hrl").

%% Report §8.7: the milliseconds a spawn's or a compute's frame says its
%% spawner waits, by which the exchange gives up a reach that does not
%% arrive: eunit's time for one test, which no test here outlasts, so that
%% no exchange's time runs out but where a test gives it none.
-define(MS, 5000).

-define(REACHED,
        "export type Shape = Square(Int) | Circle(Int)\n"
        "let side : Int = 3\n"
        "fn area(shape : Shape) : Int =\n"
        "    match shape { Square(s) -> s * s | Circle(r) -> 3 * r * r }\n"
        "fn isEven(n : Int) : Bool = if n == 0 then true else isOdd(n - 1)\n"
        "fn isOdd(n : Int) : Bool = if n == 0 then false else isEven(n - 1)\n"
        "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
        "export fn work() : Unit =\n"
        "    { let _ = area(Square(side)); let _ = isEven(4); Unit }\n"
        "export fn timed() : Int = now()\n"
        "export fn later(n : Int) : Either(Io.Error, Address(Never)) =\n"
        "    Peer.spawn(\"p\", fn() = { let _ = isOdd(n); Unit }, 100)\n").

%% report §8.7, Appendix H: the spawner's node answers a request for a
%% function's reach, a function's and a lambda's, from the code table and
%% the forms the unit's `.erc` holds: the hashes of the definitions it
%% reaches from the definition it is or is in, code and types, a group's
%% members among them, the bindings its reach names and its foreign
%% declarations with the host's module and function and the declared
%% type; a foreign function's by its name, its declaration alone; and the
%% lacks with a code frame for each, a group in one, dependencies first,
%% each the bytes its hashes are taken of, with the hashes its forms
%% reference and each member's name and form with the lines of its source,
%% the locals' names left out, and the foreign declarations its form calls
%% with the host's module and function. A function or a definition it
%% holds nowhere is a reach of none
reach_test() ->
    {Unit, Beam, Defined} = compiled(['Exreach'], ?REACHED),
    File = filename:join(scratch_dir(), "exreach.erc"),
    ok = file:write_file(File, Beam),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, File, Beam),
    ok = ern_code:loaded(Unit, Beam),
    Hash = fun(Name) -> (maps:get(['Exreach', Name], Defined))#definition.hash end,
    [{LambdaHash, Position}] = [{Of, At} || {_, {lambda, Of, At, _, _, _}} <- Unit:'$code'()],
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               Asked = fun(Body) ->
                           Ref = make_ref(),
                           ern_exchange ! {ern_frame, self(), setelement(2, Body, Ref)},
                           [Frame || Frame <- frames(Ref)]
                       end,
               Reaches = [Asked({reach_request, ref, Identity})
                          || Identity <- [{function, Hash(work)}, {function, Hash(timed)},
                                          {lambda, LambdaHash, Position},
                                          {function, <<1:256>>},
                                          {foreign, [<<"Exreach">>, <<"now">>]}]],
               Lacks = [Asked({lacks, ref, Hashes})
                        || Hashes <- [[Hash(work), Hash(area), Hash(isEven), Hash(isOdd),
                                       Hash('Shape')],
                                      [Hash(isOdd)], [<<2:256>>], [Hash(timed)]]],
               Self ! {asked, Reaches, Lacks}
           end,
    try
        ?assertEqual(ok, run(Main, quiet())),
        {asked, Reaches, Lacks} = receive {asked, _, _} = Got -> Got end,
        Work = lists:usort([Hash(Name) || Name <- [work, area, isEven, isOdd, 'Shape']]),
        Later = lists:usort([Hash(Name) || Name <- [later, isEven, isOdd]]),
        Now = {[<<"Exreach">>, <<"now">>], <<"erlang">>, <<"monotonic_time">>,
               {scheme, [], {arrow, [], none, {applied, {named, ['Int']}, []}}, []},
               {[<<"Exreach">>], []}},
        ?assertMatch([[{reach, _, Work, [{[<<"Exreach">>, <<"side">>], _}], []}],
                      [{reach, _, [_], [], [Now]}],
                      [{reach, _, Later, [], []}],
                      [{reach, _, none}],
                      [{reach, _, [], [], [Now]}]], Reaches),
        [[{reach, _, Work, [{_, SideHash}], []}], [{reach, _, [Timed], _, _}] | _] = Reaches,
        ?assertEqual(Hash(side), SideHash),
        ?assertEqual(Hash(timed), Timed),
        [Frames, [Group], [None], [TimedFrame]] = Lacks,
        ?assertEqual({reach, none}, {element(1, None), element(3, None)}),
        %% the group crosses whole, its members in source order, wherever it
        %% is lacked
        ?assertMatch({code_frame, _, [_, _], _, _, _}, Group),
        ?assertEqual([Hash(isEven), Hash(isOdd)], element(3, Group)),
        Named = [Hashes || {code_frame, _, Hashes, _, _, _} <- Frames],
        ?assertEqual(4, length(Named)),
        ?assertEqual(lists:sort([[Hash('Shape')], [Hash(area)], [Hash(isEven), Hash(isOdd)],
                                 [Hash(work)]]),
                     lists:sort(Named)),
        Place = fun(Hashes) ->
                    length(lists:takewhile(fun(Of) -> Of =/= Hashes end, Named))
                end,
        ?assert(Place([Hash('Shape')]) < Place([Hash(area)])),
        ?assert(Place([Hash(area)]) < Place([Hash(work)])),
        ?assert(Place([Hash(isEven), Hash(isOdd)]) < Place([Hash(work)])),
        [begin
             {ok, Forms} = ern_canonical:verified(Hashes, Bytes),
             ?assertEqual(referenced(Forms), References),
             Sourced = binary_to_term(Sources),
             ?assertEqual(Forms, [ern_canonical:stripped(Source)
                                  || {_, Source, _, _} <- Sourced]),
             ?assertEqual([], [Name || {_, Source, _, _} <- Sourced,
                                       Name <- local_names(Source)]),
             %% report §8.7, §11.5: what prints a type as the module writes it
             ?assertEqual([{[<<"Exreach">>], []}], lists:usort([P || {_, _, P, _} <- Sourced])),
             %% report §8.7: none of them calls a foreign function
             ?assertEqual([[]], lists:usort([Calls || {_, _, _, Calls} <- Sourced]))
         end || {code_frame, _, Hashes, Bytes, References, Sources} <- [Group | Frames]],
        [{code_frame, _, _, _, WorkReferences, WorkSources}] =
            [Frame || {code_frame, _, [Of], _, _, _} = Frame <- Frames, Of =:= Hash(work)],
        ?assert(lists:member(Hash(side), WorkReferences)),
        %% report §8.7: the definition's name as text and its source's lines
        [{WorkName, {'$at', {WorkLine, _, none}, _}, _, _}] = binary_to_term(WorkSources),
        ?assertEqual({[<<"Exreach">>, <<"work">>], 8}, {WorkName, WorkLine}),
        [{'$at', {OddLine, _, none}, _}] =
            [Source || {[<<"Exreach">>, <<"isOdd">>], Source, _, _}
                           <- binary_to_term(element(6, Group))],
        ?assertEqual(6, OddLine),
        %% report §8.7: a definition that calls a foreign function carries
        %% its declaration's host module and function beside its form
        ?assertMatch([{[<<"Exreach">>, <<"timed">>], _, {[<<"Exreach">>], []},
                       [{[<<"Exreach">>, <<"now">>], <<"erlang">>, <<"monotonic_time">>,
                         {[<<"Exreach">>], []}}]}],
                     binary_to_term(element(6, TimedFrame)))
    after
        unloaded(Unit)
    end.

-define(WHOLE,
        "export type Shape = Square(Int) | Circle(Int)\n"
        "fn area(shape : Shape) : Int = match shape { Square(s) -> s * s * 2 | Circle(r) -> r }\n"
        "fn isEven(n : Int) : Bool = if n == 0 then true else isOdd(n - 2)\n"
        "fn isOdd(n : Int) : Bool = if n == 0 then false else isEven(n - 2)\n"
        "export fn work() : Unit =\n"
        "    { let _ = area(Circle(5)); let _ = isOdd(4); Unit }\n").

-define(HELD, "export fn held() : Int = 41 + 1\n").

-define(BOUND, "export let base : Int = 40\n").

-define(FAULTY, "export fn held() : Int = 40 + 3\n").

%% report §8.7, §11.2: the node a spawn was asked of, lacking its function,
%% asks the spawner's node for the reach once, though two spawns and a
%% compute wait on it, which share the exchange; answers the identities it
%% lacks, not the one it holds; verifies each code frame and holds it
%% apart, nothing of the reach in the code table, until every lacked
%% identity has arrived; and then makes the reach,
%% a type, a group and the function that calls them, one unit of the pool's,
%% loaded whole, which the code table holds by the frames' hashes, and
%% starts each that waits, the spawns answered through the spawner's
%% gateway and the compute's value through its alias, saying nothing
received_whole_test() ->
    {_, _, Defined} = compiled(['Exwhole'], ?WHOLE),
    {HeldUnit, HeldBeam, HeldDefined} = compiled(['Exheld'], ?HELD),
    loaded(HeldUnit, HeldBeam),
    {BoundUnit, BoundBeam, BoundDefined} = compiled(['Exbound'], ?BOUND),
    loaded(BoundUnit, BoundBeam),
    Base = (maps:get(['Exbound', base], BoundDefined))#definition.hash,
    Definition = fun(Name) -> maps:get(['Exwhole', Name], Defined) end,
    Hash = fun(Name) -> (Definition(Name))#definition.hash end,
    Held = (maps:get(['Exheld', held], HeldDefined))#definition.hash,
    Work = {function, Hash(work)},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               ok = ern_rt:init_modules([BoundUnit]),
               [SpawnRef, JoinedRef] = [make_ref(), make_ref()],
               ok = ern_exchange:lacking(self(), spawned(SpawnRef, Work), Work),
               {Exchange, Ref, Asked} = receive {ern_frame, From, {reach_request, R, I}} ->
                                                {From, R, I}
                                        end,
               ok = ern_exchange:lacking(self(), spawned(JoinedRef, Work), Work),
               Alias = erlang:alias([reply]),
               ok = ern_rt:note_compute(self(), Alias),
               ok = ern_exchange:lacking(self(), {compute, Alias, Work, <<"M.f:3">>, ?MS}, Work),
               ok = catch_up(),
               AskedAgain = waiting(),
               Identities = [Hash(Name) || Name <- [work, area, 'Shape', isEven, isOdd]] ++ [Held],
               Bindings = [{[<<"Exbound">>, <<"base">>], Base}],
               Exchange ! {ern_frame, self(), {reach, Ref, Identities, Bindings, []}},
               Lacks = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
               Frames = [code_frame(Ref, [Definition(Name)]) || Name <- ['Shape', area, work]]
                   ++ [code_frame(Ref, [Definition(isEven), Definition(isOdd)])],
               {Early, [Last]} = lists:split(length(Frames) - 1, Frames),
               [Exchange ! {ern_frame, self(), Frame} || Frame <- Early],
               ok = catch_up(),
               Apart = {waiting(), [Unit || {code_frame, _, Hashes, _, _, _} <- Early,
                                            Of <- Hashes, Unit <- ern_code:holders({hash, Of})]},
               Exchange ! {ern_frame, self(), Last},
               Answers = [receive {ern_frame, _, {answer, AnswerRef, Answer}} -> Answer end
                          || AnswerRef <- [SpawnRef, JoinedRef]],
               Computed = receive {Alias, computed, Value} -> Value end,
               Spawnable = [ern_code:spawnable({hash, Hash(Name)}) || Name <- [work, area, isOdd]],
               Self ! {received, Asked, AskedAgain, Lacks, Apart, Answers, Computed, Spawnable}
           end,
    try
        {Said, Options} = said(),
        ?assertEqual(ok, run(Main, Options)),
        {received, Asked, AskedAgain, Lacks, Apart, Answers, Computed, Spawnable} =
            receive {received, _, _, _, _, _, _, _} = Got -> Got end,
        ?assertEqual(Work, Asked),
        ?assertEqual([], AskedAgain),
        ?assertEqual([Hash(Name) || Name <- [work, area, 'Shape', isEven, isOdd]], Lacks),
        ?assertEqual({[], []}, Apart),
        ?assertMatch([{spawned, _}, {spawned, _}], Answers),
        ?assertEqual('Unit', Computed),
        [{Unit, _, _, _} | _] = Spawnable,
        ?assertMatch([{Unit, _, 0, _}, {Unit, _, 1, _}, {Unit, _, 1, _}], Spawnable),
        ?assertMatch("ern$" ++ _, atom_to_list(Unit)),
        {ok, #recorded{definitions = Kept}} = ern_code:forms(Unit),
        ?assertEqual(lists:sort([[<<"Exwhole">>, Name]
                                 || Name <- [<<"Shape">>, <<"area">>, <<"work">>,
                                             <<"isEven">>, <<"isOdd">>]]),
                     lists:sort([Name || #definition{qualified_name = Name} <- Kept])),
        ?assertEqual([], Said()),
        unloaded(Unit)
    after
        unloaded(HeldUnit),
        unloaded(BoundUnit)
    end.

-define(LINKED,
        "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
        "export fn linked() : Int = {\n"
        "    let _ = now();\n"
        "    Exheld.held() + Exbound.base\n"
        "}\n").

%% report §8.7, §11.1, §8.4: the unit a reach makes links what its forms
%% reference outside it through the code table: a function of a unit the
%% node holds, by its hash, to that unit's function; a binding, by its
%% identity, to the unit that holds it with its value, through its getter;
%% and a foreign declaration of the reach to a function of the unit's own,
%% which calls the host's function the sender's declaration names through
%% the check at its declared type. A compute of the function the reach
%% brought answers its value, and the code table holds it, the node's
%% pool's unit, which the node ships onward as its own: asked for the reach
%% of the function now, it answers it from that unit's forms, the foreign
%% declaration with its type
received_linked_test() ->
    {HeldUnit, HeldBeam, _} = compiled(['Exheld'], ?HELD),
    loaded(HeldUnit, HeldBeam),
    {BoundUnit, BoundBeam, _} = compiled(['Exbound'], ?BOUND),
    loaded(BoundUnit, BoundBeam),
    Interfaces = [Interface || Beam <- [HeldBeam, BoundBeam],
                               {ok, #{interface := Interface}} <- [ern_interface:read(Beam)]],
    {ok, Parsed} = ern_parser:parse_string(?LINKED),
    {ok, Typed, Interface, Env} = ern_typecheck:check(['Exlinked'], Parsed, Interfaces),
    {ok, _, LinkedBeam} = ern_compile:compile(['Exlinked'], Typed, Interface, Env,
                                              #{source_hash => <<>>, deps => []}),
    {ok, #recorded{definitions = [Linked], foreign = [{_, Scheme, _, _, Printing}] = Foreign}} =
        ern_canonical:read(LinkedBeam),
    Work = {function, Linked#definition.hash},
    Self = self(),
    Main = fun() ->
                   true = register(ern_gateway, self()),
                   ok = ern_exchange:start(),
                   ok = ern_rt:init_modules([BoundUnit]),
                   Alias = erlang:alias([reply]),
                   ok = ern_rt:note_compute(self(), Alias),
                   ok = ern_exchange:lacking(self(), {compute, Alias, Work, <<"M.f:3">>, ?MS},
                                             Work),
                   {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, _}} ->
                                             {From, R}
                                     end,
                   [_, HeldHash] = Identities =
                       [Linked#definition.hash | held_identities(HeldBeam)],
                   Exchange ! {ern_frame, self(),
                               {reach, Ref, Identities,
                                [{[<<"Exbound">>, <<"base">>], bound_hash(BoundBeam)}],
                                [{[<<"Exlinked">>, <<"now">>], <<"erlang">>,
                                  <<"monotonic_time">>, Scheme, Printing}]}},
                   Lacks = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
                   Exchange ! {ern_frame, self(), code_frame(Ref, [Linked], Foreign)},
                   Computed = receive {Alias, computed, Value} -> Value end,
                   {Unit, _, 0, Reach} = ern_code:spawnable({hash, Linked#definition.hash}),
                   Asked = make_ref(),
                   Exchange ! {ern_frame, self(), {reach_request, Asked, Work}},
                   Onward = receive {ern_frame, _, {reach, Asked, _, _, _} = Got} -> Got end,
                   Self ! {received, Lacks, HeldHash, Computed, Unit, Reach, Onward}
           end,
    try
        ?assertEqual(ok, run(Main, quiet())),
        {received, Lacks, HeldHash, Computed, Unit, Reach, Onward} =
            receive {received, _, _, _, _, _, _} = Received -> Received end,
        ?assertEqual([Linked#definition.hash], Lacks),
        ?assertEqual(82, Computed),
        ?assertEqual({[{['Exbound', base], bound_hash(BoundBeam)}], [['Exlinked', now]]}, Reach),
        ?assertMatch({reach, _, _, [{[<<"Exbound">>, <<"base">>], _}],
                      [{[<<"Exlinked">>, <<"now">>], <<"erlang">>, <<"monotonic_time">>, Scheme,
                        {[<<"Exlinked">>], []}}]},
                     Onward),
        ?assertEqual(lists:sort([Linked#definition.hash, HeldHash]),
                     lists:sort(element(3, Onward))),
        unloaded(Unit)
    after
        unloaded(HeldUnit),
        unloaded(BoundUnit)
    end.

-define(BEYOND,
        "foreign fn absent() : Unit = \"ern_exchange_tests_nowhere:f/0\"\n"
        "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
        "let note : Int = 1\n"
        "export fn outer() : Either(Io.Error, Int) = {\n"
        "    absent();\n"
        "    let _ = now() + note;\n"
        "    Peer.computeAt(\"p\", fn() = 6 * 7, 100)\n"
        "}\n").

%% report §8.7, §8.4, §11.2: a lambda crosses as the definition that
%% encloses it, and what that definition names beyond the lambda's reach
%% the node links so that the unit loads: a foreign function its code frame
%% declares whose module is here, to a function of the unit's own through
%% the check, which the code table holds as a declaration of the unit's; a
%% foreign function whose module is not here, and a binding without its
%% value here, each to a function of the unit's own that faults naming
%% what the node lacks. The compute of the lambda answers its value. The
%% unit records every declaration the frame carried, the lacked one with
%% its module and function as text, the node holding no atom of the module,
%% and a code frame the node makes of the definition to ship it onward
%% carries both; asked for the reach of the lacked foreign function by its
%% name, which it cannot run, the node answers its declaration, the module
%% and the function as text, as a foreign function spawned by its name
%% crosses. A regression test, written with the fix (MVP 3.2's item 5
%% found the reach's foreign declarations alone declared, the binding
%% refused, then the lacked declaration recorded nowhere, and then the
%% reach by its name answered none); it does not cover a lacked function's
%% module that is here and lacks the function, which
%% ern_peer:foreign_lacked/1 answers as not_loaded_from_reach_test's third
%% case shows, nor the nodes, a third node's check of what it is sent
%% among them, which test/ern_nodes_tests.erl's relay_test_ covers in part
received_beyond_reach_test() ->
    {_, Beam, Defined} = compiled(['Exbeyond'], ?BEYOND),
    {ok, #recorded{foreign = Compiled}} = ern_canonical:read(Beam),
    %% the frame names for `absent` a module whose name this host, where
    %% the sender's build made its own, holds no atom of
    Foreign = [case QualifiedName of
                   ['Exbeyond', absent] ->
                       {QualifiedName, Scheme, <<"ern_exchange_tests_elsewhere">>, <<"f">>,
                        Printing};
                   _ -> Declaration
               end || {QualifiedName, Scheme, _, _, Printing} = Declaration <- Compiled],
    #definition{hash = Outer} = Definition = maps:get(['Exbeyond', outer], Defined),
    Lambda = {lambda, Outer, 1},
    Self = self(),
    Main = fun() ->
                   true = register(ern_gateway, self()),
                   ok = ern_exchange:start(),
                   Alias = erlang:alias([reply]),
                   ok = ern_rt:note_compute(self(), Alias),
                   ok = ern_exchange:lacking(self(), {compute, Alias, {lambda, Outer, 1, []},
                                                      <<"M.f:3">>, ?MS}, Lambda),
                   {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, Lambda}} ->
                                             {From, R}
                                     end,
                   Exchange ! {ern_frame, self(), {reach, Ref, [Outer], [], []}},
                   [Outer] = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
                   Exchange ! {ern_frame, self(), code_frame(Ref, [Definition], Foreign)},
                   Computed = receive {Alias, computed, Value} -> Value end,
                   {Unit, _, _, _} = ern_code:spawnable({hash, Outer}),
                   Faults = [try Unit:Lacked() catch throw:Fault -> Fault end
                             || Lacked <- ['$lacked_1', '$lacked_2']],
                   Declared = [ern_code:spawnable({foreign, [<<"Exbeyond">>, Name]})
                               || Name <- [<<"now">>, <<"absent">>]],
                   {ok, #recorded{foreign = Recorded}} = ern_code:forms(Unit),
                   Onward = make_ref(),
                   Exchange ! {ern_frame, self(), {lacks, Onward, [Outer]}},
                   [{code_frame, Onward, [Outer], _, _, Sources}] = frames(Onward),
                   ByName = make_ref(),
                   Exchange ! {ern_frame, self(),
                               {reach_request, ByName, {foreign, [<<"Exbeyond">>, <<"absent">>]}}},
                   [Reach] = frames(ByName),
                   Self ! {received, Computed, Unit, Faults, Declared, Recorded,
                           binary_to_term(Sources), Reach}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    {received, Computed, Unit, Faults, Declared, Recorded, Sources, Reach} =
        receive {received, _, _, _, _, _, _, _} = Got -> Got end,
    try
        ?assertMatch({reach, _, [], [], [{[<<"Exbeyond">>, <<"absent">>],
                                          <<"ern_exchange_tests_elsewhere">>, <<"f">>,
                                          {scheme, _, _, _}, {[<<"Exbeyond">>], []}}]},
                     Reach),
        ?assertEqual(42, Computed),
        ?assertMatch([{['Exbeyond', absent], _, <<"ern_exchange_tests_elsewhere">>, f, _},
                      {['Exbeyond', now], _, erlang, monotonic_time, _}],
                     lists:sort(Recorded)),
        ?assertMatch([{_, _, _, [{[<<"Exbeyond">>, <<"absent">>],
                                  <<"ern_exchange_tests_elsewhere">>, <<"f">>, _},
                                 {[<<"Exbeyond">>, <<"now">>], <<"erlang">>,
                                  <<"monotonic_time">>, _}]}],
                     Sources),
        ?assertError(badarg, binary_to_existing_atom(<<"ern_exchange_tests_elsewhere">>)),
        ?assertEqual([{ern, fault, <<"the binding Exbeyond.note has no value here">>},
                      {ern, fault, <<"the module ern_exchange_tests_elsewhere, which"
                                     " Exbeyond.absent calls, is not here">>}],
                     Faults),
        ?assertMatch([{Unit, _, 0, _}, none], Declared),
        ?assertEqual([], Said())
    after
        unloaded(Unit)
    end.

held_identities(Beam) ->
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    [Hash || #definition{hash = Hash} <- Definitions].

bound_hash(Beam) ->
    [Hash] = held_identities(Beam),
    Hash.

%% report §8.7: a reach the node cannot take, a form that references a
%% definition the node holds nowhere and that did not arrive, is answered
%% Other with the node's reason in a line, which the node says, and nothing
%% of it is in the code table
unlinked_reach_test() ->
    Form = {function, {scheme, [], {arrow, [], none, {applied, {named, ['Int']}, []}}, []}, [],
            {var, {hash, <<77:256>>}, []}},
    Hash = crypto:hash(sha256, ern_canonical:bytes(ern_canonical:hashed([Form]))),
    Work = {function, Hash},
    Self = self(),
    Main = fun() ->
                   true = register(ern_gateway, self()),
                   ok = ern_exchange:start(),
                   SpawnRef = make_ref(),
                   ok = ern_exchange:lacking(self(), spawned(SpawnRef, Work), Work),
                   {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, _}} ->
                                             {From, R}
                                     end,
                   Exchange ! {ern_frame, self(), {reach, Ref, [Hash], [], []}},
                   [Hash] = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
                   Exchange ! {ern_frame, self(),
                               {code_frame, Ref, [Hash], ern_canonical:bytes(
                                                           ern_canonical:hashed([Form])),
                                [<<77:256>>], term_to_binary([{[<<"Crafted">>, <<"bad">>],
                                                               Form, {[], []}, []}])}},
                   Answer = receive {ern_frame, _, {answer, SpawnRef, A}} -> A end,
                   %% the node says the line once it has answered
                   ok = catch_up(),
                   Self ! {answered, Answer, ern_code:spawnable({hash, Hash})}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    Text = <<"this node could not take the code it received: it references a definition this"
             " node does not hold, ", (binary:copy(<<"00">>, 31))/binary, "4d">>,
    ?assertEqual({answered, {failed, {'Other', Text}}, none},
                 receive {answered, _, _} = Got -> Got end),
    ?assertEqual([<<"the node nohost's spawn at M.f:1 was not loaded: ", Text/binary, "\n">>],
                 Said()).

%% report §8.7, §11.2: the pool names a unit an exchange makes `ern$` and a
%% count, the first the host holds no unit of from the count given, and the
%% count after it, a name the host holds a unit of passed over
pool_test() ->
    Base = 900000 + erlang:unique_integer([positive]) rem 1000 * 10,
    Name = fun(Count) -> list_to_atom("ern$" ++ integer_to_list(Count)) end,
    First = Name(Base),
    ?assertEqual({First, Base + 1}, ern_arrival:name(Base)),
    {ok, First, Beam} = compile:forms([{attribute, 1, module, First}], [binary]),
    {module, First} = code:load_binary(First, "pool", Beam),
    ?assertEqual({Name(Base + 1), Base + 2}, ern_arrival:name(Base)),
    true = code:delete(First),
    true = code:soft_purge(First).

%% report §8.7: where the node lacks the module a foreign declaration of the
%% reach calls, or the function in it, or the value of a binding it names,
%% the spawn is answered NotLoaded before any code crosses, no lacks
%% asked, and the node says what it lacked, the names the peer's text,
%% which make no atom here
not_loaded_from_reach_test() ->
    Work = {function, <<3:256>>},
    Scheme = {scheme, [], {arrow, [], none, {applied, {named, ['Unit']}, []}}, []},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               Answers = [begin
                              SpawnRef = make_ref(),
                              ok = ern_exchange:lacking(self(), spawned(SpawnRef, Work), Work),
                              {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, _}} ->
                                                        {From, R}
                                                end,
                              Exchange ! {ern_frame, self(), {reach, Ref, [<<4:256>>], Bindings,
                                                              Foreigns}},
                              Answer = receive {ern_frame, _, {answer, SpawnRef, A}} -> A end,
                              ok = catch_up(),
                              {Answer, waiting()}
                          end
                          || {Bindings, Foreigns}
                                 <- [{[{[<<"Exabsent">>, <<"note">>], <<5:256>>}], []},
                                     {[], [{[<<"Exabsent">>, <<"only">>],
                                            <<"ern_exchange_tests_absent">>, <<"f">>,
                                            Scheme, {[], []}}]},
                                     {[], [{[<<"Exabsent">>, <<"sorted">>], <<"lists">>,
                                            <<"ern_exchange_tests_unsorted">>, Scheme,
                                            {[], []}}]}]],
               Self ! {answered, Answers}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    ?assertEqual({answered, lists:duplicate(3, {{failed, 'NotLoaded'}, []})},
                 receive {answered, _} = Got -> Got end),
    ?assertEqual([<<"the node nohost's spawn at M.f:1 was not loaded: the binding Exabsent.note"
                    " has no value here\n">>,
                  <<"the node nohost's spawn at M.f:1 was not loaded: the module"
                    " ern_exchange_tests_absent, which Exabsent.only calls, is not here\n">>,
                  <<"the node nohost's spawn at M.f:1 was not loaded: the module lists, which"
                    " Exabsent.sorted calls, has no function ern_exchange_tests_unsorted/0"
                    " here\n">>],
                 Said()),
    [?assertError(badarg, binary_to_existing_atom(Name))
     || Name <- [<<"Exabsent">>, <<"ern_exchange_tests_unsorted">>]].

%% report §8.7: a frame the exchange cannot read is faulty, and the node
%% ends the peer's connection and says so: a code frame whose bytes are not
%% those the hash it names is taken of, one that names a hash that was not
%% lacked, one whose references are not those its forms name, one whose
%% form with its source's lines is not its form once they are taken out,
%% one whose sources name an atom its form does not, one with a source too
%% few, one that declares a foreign function its form does not call, one
%% whose declaration's host module is not text, a reach of another shape,
%% and a request for a reach of no identity. The exchange asked of the
%% peer goes with its forms, a later frame of it passed over, and the spawn
%% the peer asked for with it, none waiting on it now. The two cases of the
%% declarations are regression tests, written with them (MVP 3.2's item 5)
faulty_frame_test() ->
    {_, _, Defined} = compiled(['Exfaulty'], ?FAULTY),
    #definition{hash = Hash, form = Form} = maps:get(['Exfaulty', held], Defined),
    Work = {function, Hash},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               Asking = fun() ->
                            SpawnRef = make_ref(),
                            ok = ern_exchange:lacking(self(), spawned(SpawnRef, Work), Work),
                            receive {ern_frame, From, {reach_request, R, _}} -> {From, R} end
                        end,
               Lacking = fun() ->
                             {Exchange, Ref} = Asking(),
                             Exchange ! {ern_frame, self(), {reach, Ref, [Hash], [], []}},
                             receive {ern_frame, _, {lacks, Ref, _}} -> {Exchange, Ref} end
                         end,
               Bytes = ern_canonical:bytes(ern_canonical:hashed([Form])),
               Name = [<<"Exfaulty">>, <<"held">>],
               Sources = term_to_binary([{Name, Form, {[<<"Exfaulty">>], []}, []}]),
               Declared = fun(HostModule) ->
                              term_to_binary([{Name, Form, {[<<"Exfaulty">>], []},
                                               [{[<<"Exfaulty">>, <<"now">>], HostModule,
                                                 <<"monotonic_time">>, {[], []}}]}])
                          end,
               Other = setelement(2, Form, {scheme, [], {arrow, [], none, int}, []}),
               Faults = [fun(Ref) ->
                                 {code_frame, Ref, [Hash], <<Bytes/binary, 0>>, [], Sources}
                         end,
                         fun(Ref) -> {code_frame, Ref, [<<6:256>>], Bytes, [], Sources} end,
                         fun(Ref) -> {code_frame, Ref, [Hash], Bytes, [<<7:256>>], Sources} end,
                         fun(Ref) ->
                             {code_frame, Ref, [Hash], Bytes, [],
                              term_to_binary([{Name, {'$at', {1, 1, none}, Other}, {[], []},
                                               []}])}
                         end,
                         fun(Ref) ->
                             {code_frame, Ref, [Hash], Bytes, [],
                              <<131, 108, 1:32, 104, 4, 108, 1:32, 109, 3:32, "abc", 106,
                                119, 12, "ern_unknown1", 104, 2, 106, 106, 106, 106>>}
                         end,
                         fun(Ref) -> {code_frame, Ref, [Hash], Bytes, [], term_to_binary([])} end,
                         fun(Ref) ->
                             {code_frame, Ref, [Hash], Bytes, [], Declared(<<"erlang">>)}
                         end,
                         fun(Ref) -> {code_frame, Ref, [Hash], Bytes, [], Declared(erlang)} end],
               Late = [begin
                           {Exchange, Ref} = Lacking(),
                           Exchange ! {ern_frame, self(), Fault(Ref)},
                           Exchange ! {ern_frame, self(), {code_frame, Ref, [Hash], Bytes, [],
                                                           Sources}},
                           ok = catch_up(),
                           waiting()
                       end || Fault <- Faults],
               {Exchange, Ref} = Asking(),
               Exchange ! {ern_frame, self(), {reach, Ref, [short], [], []}},
               Exchange ! {ern_frame, self(), {reach_request, make_ref(), {function, <<"s">>}}},
               ok = catch_up(),
               Self ! {faulty, Late, waiting()}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    ?assertEqual({faulty, [[], [], [], [], [], [], [], []], []},
                 receive {faulty, _, _} = Got -> Got end),
    ?assertEqual(lists:duplicate(10, <<"the node nohost sent a frame this node cannot read, and its"
                                      " connection was ended\n">>),
                 Said()),
    ?assertError(badarg, binary_to_existing_atom(<<"ern_unknown1">>)).

%% report §8.7: a loss drops the exchanges asked of the lost peer, with
%% their forms: a spawn of another node's that waited on one asks its own
%% node anew, and the spawns the lost peer asked for go, none waiting on
%% them now; an exchange that lost every spawn waiting on it goes too, and a
%% reach of it that comes later is passed over. Another node's process is a
%% pid made for a node this host never connects to, whose frames go nowhere
loss_test() ->
    Elsewhere = binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>),
    Work = {function, <<8:256>>},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               ok = ern_exchange:lacking(Elsewhere, spawned(make_ref(), Work), Work),
               ok = ern_exchange:lacking(self(), spawned(make_ref(), Work), Work),
               ok = catch_up(),
               First = waiting(),
               ok = ern_exchange:lost(node(Elsewhere)),
               {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, Work}} ->
                                         {From, R}
                                 end,
               ok = ern_exchange:lost(node()),
               Exchange ! {ern_frame, self(), {reach, Ref, [<<9:256>>], [], []}},
               ok = catch_up(),
               Self ! {lost, First, waiting()}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    ?assertEqual({lost, [], []}, receive {lost, _, _} = Got -> Got end),
    ?assertEqual([], Said()).

%% report §8.7: a spawner's node that no longer holds what it is asked for,
%% the shell having let go of an input whose spawn gave up, answers a reach
%% of none, at the request for the reach and at the lacks alike, and the
%% spawn it asked for is answered Other, which the node says. The lacks'
%% case is a regression test: the exchange took a reach of none there as a
%% faulty frame
no_longer_held_test() ->
    Work = {function, <<10:256>>},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               Asked = fun(Answer) ->
                           SpawnRef = make_ref(),
                           ok = ern_exchange:lacking(self(), spawned(SpawnRef, Work), Work),
                           {Exchange, Ref} = receive
                                                 {ern_frame, From, {reach_request, R, _}} ->
                                                     {From, R}
                                             end,
                           Answer(Exchange, Ref),
                           receive {ern_frame, _, {answer, SpawnRef, A}} -> A end
                       end,
               None = fun(Exchange, Ref) -> Exchange ! {ern_frame, self(), {reach, Ref, none}} end,
               AtRequest = Asked(None),
               AtLacks = Asked(fun(Exchange, Ref) ->
                                   Reach = {reach, Ref, [<<10:256>>], [], []},
                                   Exchange ! {ern_frame, self(), Reach},
                                   [<<10:256>>] = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
                                   None(Exchange, Ref)
                               end),
               Self ! {answered, AtRequest, AtLacks}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    Text = <<"the spawner's node no longer holds the function's reach">>,
    Failed = {failed, {'Other', Text}},
    ?assertEqual({answered, Failed, Failed}, receive {answered, _, _} = Got -> Got end),
    Line = <<"the node nohost's spawn at M.f:1 was not loaded: ", Text/binary, "\n">>,
    ?assertEqual([Line, Line], Said()).

%% report §8.7: the exchange runs within the spawn's time: one whose spawner
%% waits nothing is dropped with its forms once its time has run out, its
%% spawn said and left unanswered, its spawner answering itself, and a
%% reach of it that comes later is passed over; a spawn that joins an
%% exchange with a shorter time leaves it the longer, which has not run out
%% at its timer's message. A
%% regression test, written after the fix (the release review before 0.4.0
%% found an exchange a peer never completed kept until the connection's
%% loss); it does not cover a compute's exchange, whose time is its frame's
%% as a spawn's is, nor two nodes
timed_out_test() ->
    Work = {function, <<11:256>>},
    Joined = {function, <<12:256>>},
    Self = self(),
    Main = fun() ->
               true = register(ern_gateway, self()),
               ok = ern_exchange:start(),
               ok = ern_exchange:lacking(self(), spawned(make_ref(), Work, 0), Work),
               {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, _}} -> {From, R} end,
               ok = catch_up(),
               Exchange ! {deadline, Ref},
               Exchange ! {ern_frame, self(), {reach, Ref, [<<11:256>>], [], []}},
               ok = catch_up(),
               Late = waiting(),
               ok = ern_exchange:lacking(self(), spawned(make_ref(), Joined), Joined),
               JoinedRef = receive {ern_frame, _, {reach_request, J, _}} -> J end,
               ok = ern_exchange:lacking(self(), spawned(make_ref(), Joined, 0), Joined),
               Exchange ! {deadline, JoinedRef},
               Exchange ! {ern_frame, self(), {reach, JoinedRef, [<<12:256>>], [], []}},
               Lacks = receive {ern_frame, _, {lacks, JoinedRef, L}} -> L end,
               Self ! {timed, Late, Lacks}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    Text = <<"its time ran out before the function's reach arrived">>,
    ?assertEqual({timed, [], [<<12:256>>]}, receive {timed, _, _} = Got -> Got end),
    ?assertEqual([<<"the node nohost's spawn at M.f:1 was not loaded: ", Text/binary, "\n">>],
                 Said()).

%%
%% Helpers
%%

%% Main run as a program, the exchange it starts stopped after, however the
%% run ended.
run(Main, Options) ->
    try
        ern_rt:run_main(Main, <<"main">>, Options)
    after
        case whereis(ern_exchange) of
            undefined ->
                ok;
            Exchange ->
                MonitorRef = erlang:monitor(process, Exchange),
                exit(Exchange, kill),
                receive {'DOWN', MonitorRef, process, Exchange, _} -> ok end
        end
    end.

%% A module compiled as the build compiles it, and its definitions by their
%% qualified names, which no code table holds until it is loaded.
compiled(Namespace, Text) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => []},
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    {Unit, Beam, maps:from_list([{QualifiedName, Definition}
                                 || #definition{qualified_name = QualifiedName} = Definition
                                        <- Definitions])}.

%% The unit loaded and in the code table, its forms kept beside its code as
%% a shell keeps a unit's that no file holds.
loaded(Unit, Beam) ->
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, atom_to_list(Unit), Beam),
    {ok, Recorded} = ern_canonical:read(Beam),
    ok = ern_code:loaded(Unit, Beam, Recorded).

unloaded(Unit) ->
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit),
    code:purge(Unit).

scratch_dir() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_exchange_" ++ os:getpid()),
    ok = filelib:ensure_path(Dir),
    Dir.

spawned(Ref, Function) ->
    spawned(Ref, Function, ?MS).

%% A spawn's frame, as the gateway's worker hands it on, whose spawner
%% waits Ms.
spawned(Ref, {function, Hash}, Ms) ->
    {spawn, Ref, {function, Hash}, <<"M.f:1">>, false, Ms}.

%% A code frame for a definition alone or a group's members in order, each
%% with its name, its form with the lines of its source, and the foreign
%% declarations its form calls, from the declarations Foreign, as a unit
%% records them.
code_frame(Ref, Members) ->
    code_frame(Ref, Members, []).

code_frame(Ref, Members, Foreign) ->
    Forms = [Form || #definition{form = Form} <- Members],
    {code_frame, Ref, [Hash || #definition{hash = Hash} <- Members],
     ern_canonical:bytes(ern_canonical:hashed(Forms)), referenced(Forms),
     term_to_binary([{ern_namespace:text_segments(QualifiedName), Sourced, Printing,
                      calls(Form, Foreign)}
                     || #definition{qualified_name = QualifiedName, form = Form,
                                    sourced = Sourced, printing = Printing} <- Members])}.

%% The foreign declarations a form calls, in the order of their names, as a
%% code frame carries them.
calls(Form, Foreign) ->
    Called = lists:usort([ern_namespace:text_segments(QualifiedName)
                          || {foreign, QualifiedName, _} <- ern_compile:references([Form])]),
    [{Name, ern_namespace:text_segment(HostModule), ern_namespace:text_segment(HostFunction),
      Printing}
     || Name <- Called, {QualifiedName, _, HostModule, HostFunction, Printing} <- Foreign,
        ern_namespace:text_segments(QualifiedName) =:= Name].

%% The names of the locals a form with its source's lines holds.
local_names({'$at', {_, _, Name}, Node}) ->
    [Name || Name =/= none] ++ local_names(Node);
local_names(Term) when is_tuple(Term) ->
    local_names(tuple_to_list(Term));
local_names(Terms) when is_list(Terms) ->
    lists:append([local_names(Term) || Term <- Terms]);
local_names(_) ->
    [].

referenced(Forms) ->
    lists:usort([case Reference of
                     {hash, Hash} -> Hash;
                     {binding, _, Hash} -> Hash
                 end || Reference <- ern_canonical:references(Forms)]).

%% The frames the exchange has sent the stand-in gateway for Ref, once it
%% has read every frame sent it before.
frames(Ref) ->
    ok = catch_up(),
    collected(Ref, []).

%% Waits until the exchange has read every message the stand-in gateway,
%% the caller, sent it before: its answer to a request for a reach of an
%% identity no unit holds comes after them, as a peer's would.
catch_up() ->
    Ref = make_ref(),
    ern_exchange ! {ern_frame, self(), {reach_request, Ref, {function, <<0:256>>}}},
    receive {ern_frame, _, {reach, Ref, none}} -> ok end.

collected(Ref, Acc) ->
    receive
        {ern_frame, _, Body} when element(2, Body) =:= Ref -> collected(Ref, [Body | Acc])
    after 0 ->
        lists:reverse(Acc)
    end.

%% The frames the stand-in gateway holds now, every one the exchange sent
%% having come before catch_up/0's answer.
waiting() ->
    receive
        {ern_frame, _, Body} -> [Body | waiting()]
    after 0 ->
        []
    end.

quiet() ->
    #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end}.

%% A run's options with its standard error taken, and what it has said, a
%% line a write, once the run has ended.
said() ->
    Table = ets:new(said, [public, ordered_set]),
    Write = fun(Bytes) -> ets:insert(Table, {erlang:unique_integer([monotonic]), Bytes}) end,
    {fun() -> [Bytes || {_, Bytes} <- ets:tab2list(Table)] end,
     #{stdout => fun(_) -> ok end, stderr => Write}}.
