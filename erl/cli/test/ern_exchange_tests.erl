%% Report §8.7, The exchange: a node's exchange, both its parts, in one
%% host, the test standing in for the gateway, which the exchange sends
%% every frame to, and for the peer, whose frames it sends the exchange as
%% a gateway hands them on. Each runs in a program, whose standard error
%% takes the node's lines. Real nodes are test/ern_nodes_tests.erl's.
%% Regression tests, written after the code (MVP 3.2's item 3).
-module(ern_exchange_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_canonical.hrl").

-define(NOT_COMPILED,
        <<"this node compiles no received code yet: it arrives in MVP 3.2's item 4">>).

-define(REACHED,
        "export type Shape = Square(Int) | Circle(Int)\n"
        "let side : Int = 3\n"
        "fn area(shape : Shape) : Int =\n"
        "    match shape { Square(s) -> s * s | Circle(r) -> 3 * r * r }\n"
        "fn isEven(n : Int) : Bool = if n == 0 then true else isOdd(n - 1)\n"
        "fn isOdd(n : Int) : Bool = if n == 0 then false else isEven(n - 1)\n"
        "foreign fn now() : Int with m = \"erlang:monotonic_time/0\"\n"
        "export fn work() : Unit with Never =\n"
        "    { let _ = area(Square(side)); let _ = isEven(4); Unit }\n"
        "export fn timed() : Int with m = now()\n"
        "export fn later(n : Int) : Either(Io.Error, Address(Never)) with m =\n"
        "    Peer.spawn(\"p\", fn() : Unit with Never = { let _ = isOdd(n); Unit }, 100)\n").

%% report §8.7, Appendix H: the spawner's node answers a request for a
%% function's reach, a function's and a lambda's, from the code table and
%% the forms the unit's `.erc` holds: the hashes of the definitions it
%% reaches from the definition it is or is in, code and types, a group's
%% members among them, the bindings its reach names and its foreign
%% declarations with the host's module and function; and the lacks with a
%% code frame for each, a group in one, dependencies first, each the bytes
%% its hashes are taken of, with the hashes its forms reference. A function
%% or a definition it holds nowhere is a reach of none
reach_test() ->
    {Unit, Beam, Defined} = compiled(['Exreach'], ?REACHED),
    File = filename:join(scratch_dir(), "exreach.erc"),
    ok = file:write_file(File, Beam),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, File, Beam),
    ok = ern_code:loaded(Unit),
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
                                          {function, <<1:256>>}]],
               Lacks = [Asked({lacks, ref, Hashes})
                        || Hashes <- [[Hash(work), Hash(area), Hash(isEven), Hash(isOdd),
                                       Hash('Shape')],
                                      [Hash(isOdd)], [<<2:256>>]]],
               Self ! {asked, Reaches, Lacks}
           end,
    try
        ?assertEqual(ok, run(Main, quiet())),
        {asked, Reaches, Lacks} = receive {asked, _, _} = Got -> Got end,
        Work = lists:usort([Hash(Name) || Name <- [work, area, isEven, isOdd, 'Shape']]),
        Later = lists:usort([Hash(Name) || Name <- [later, isEven, isOdd]]),
        ?assertMatch([[{reach, _, Work, [{[<<"Exreach">>, <<"side">>], _}], []}],
                      [{reach, _, [_], [], [{[<<"Exreach">>, <<"now">>], <<"erlang">>,
                                             <<"monotonic_time">>}]}],
                      [{reach, _, Later, [], []}],
                      [{reach, _, none}]], Reaches),
        [[{reach, _, Work, [{_, SideHash}], []}], [{reach, _, [Timed], _, _}] | _] = Reaches,
        ?assertEqual(Hash(side), SideHash),
        ?assertEqual(Hash(timed), Timed),
        [Frames, [Group], [None]] = Lacks,
        ?assertEqual({reach, none}, {element(1, None), element(3, None)}),
        %% the group crosses whole, its members in source order, wherever it
        %% is lacked
        ?assertMatch({code_frame, _, [_, _], _, _}, Group),
        ?assertEqual([Hash(isEven), Hash(isOdd)], element(3, Group)),
        Named = [Hashes || {code_frame, _, Hashes, _, _} <- Frames],
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
             ?assertEqual(referenced(Forms), References)
         end || {code_frame, _, Hashes, Bytes, References} <- [Group | Frames]],
        [{code_frame, _, _, _, WorkReferences}] = [Frame || {code_frame, _, [Of], _, _} = Frame
                                                                <- Frames, Of =:= Hash(work)],
        ?assert(lists:member(Hash(side), WorkReferences))
    after
        unloaded(Unit)
    end.

-define(WHOLE,
        "export type Shape = Square(Int) | Circle(Int)\n"
        "fn area(shape : Shape) : Int = match shape { Square(s) -> s * s * 2 | Circle(r) -> r }\n"
        "fn isEven(n : Int) : Bool = if n == 0 then true else isOdd(n - 2)\n"
        "fn isOdd(n : Int) : Bool = if n == 0 then false else isEven(n - 2)\n"
        "export fn work() : Unit with Never =\n"
        "    { let _ = area(Circle(5)); let _ = isOdd(5); Unit }\n").

-define(HELD, "export fn held() : Int = 41 + 1\n").

-define(BOUND, "export let base : Int = 40\n").

-define(FAULTY, "export fn held() : Int = 40 + 3\n").

%% report §8.7, §11.2: the node a spawn was asked of, lacking its function,
%% asks the spawner's node for the reach once, though two spawns and a
%% compute wait on it, which share the exchange; answers the identities it
%% lacks, pinning meanwhile the unit that holds the one it holds and the
%% unit whose binding of the reach has its value here; verifies
%% each code frame and holds it apart, nothing of the reach in the code
%% table, until every lacked identity has arrived; and then answers each
%% that waits, the spawns through the spawner's gateway and the compute
%% through its alias, with Other naming the item that compiles what a node
%% receives, which it says of each
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
               ok = ern_exchange:lacking(self(), {compute, Alias, Work, <<"M.f:3">>}, Work),
               [] = ern_exchange:pinned(),
               AskedAgain = waiting(),
               Identities = [Hash(Name) || Name <- [work, area, 'Shape', isEven, isOdd]] ++ [Held],
               Bindings = [{[<<"Exbound">>, <<"base">>], Base}],
               Exchange ! {ern_frame, self(), {reach, Ref, Identities, Bindings, []}},
               Lacks = receive {ern_frame, _, {lacks, Ref, L}} -> L end,
               Pinned = ern_exchange:pinned(),
               Frames = [code_frame(Ref, [Definition(Name)]) || Name <- ['Shape', area, work]]
                   ++ [code_frame(Ref, [Definition(isEven), Definition(isOdd)])],
               {Early, [Last]} = lists:split(length(Frames) - 1, Frames),
               [Exchange ! {ern_frame, self(), Frame} || Frame <- Early],
               _ = ern_exchange:pinned(),
               Apart = {waiting(), [Unit || {code_frame, _, Hashes, _, _} <- Early,
                                            Of <- Hashes, Unit <- ern_code:holders({hash, Of})]},
               Exchange ! {ern_frame, self(), Last},
               After = ern_exchange:pinned(),
               Answers = [receive {ern_frame, _, {answer, AnswerRef, Answer}} -> Answer end
                          || AnswerRef <- [SpawnRef, JoinedRef]],
               Computed = receive {Alias, failed, Failure} -> Failure end,
               Self ! {received, Asked, AskedAgain, Lacks, Pinned, Apart, After, Answers, Computed}
           end,
    try
        {Said, Options} = said(),
        ?assertEqual(ok, run(Main, Options)),
        {received, Asked, AskedAgain, Lacks, Pinned, Apart, After, Answers, Computed} =
            receive {received, _, _, _, _, _, _, _, _} = Got -> Got end,
        ?assertEqual(Work, Asked),
        ?assertEqual([], AskedAgain),
        ?assertEqual([Hash(Name) || Name <- [work, area, 'Shape', isEven, isOdd]], Lacks),
        ?assertEqual(lists:sort([HeldUnit, BoundUnit]), Pinned),
        ?assertEqual({[], []}, Apart),
        ?assertEqual([], After),
        ?assertEqual([{failed, {'Other', ?NOT_COMPILED}}, {failed, {'Other', ?NOT_COMPILED}}],
                     Answers),
        ?assertEqual({'Other', ?NOT_COMPILED}, Computed),
        Lines = Said(),
        [?assert(lists:member(<<"the node nohost's ", Kind/binary, " at ", Site/binary,
                                " was not loaded: ", ?NOT_COMPILED/binary, "\n">>, Lines))
         || {Kind, Site} <- [{<<"spawn">>, <<"M.f:1">>}, {<<"compute">>, <<"M.f:3">>}]],
        ?assertEqual(3, length(Lines))
    after
        unloaded(HeldUnit),
        unloaded(BoundUnit)
    end.

%% report §8.7: where the node lacks the module a foreign declaration of the
%% reach calls, or the value of a binding it names, the spawn is answered
%% NotLoaded before any code crosses, no lacks asked, and the node says
%% what it lacked, the names the peer's text
not_loaded_from_reach_test() ->
    Work = {function, <<3:256>>},
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
                              _ = ern_exchange:pinned(),
                              {Answer, waiting()}
                          end
                          || {Bindings, Foreigns}
                                 <- [{[{[<<"Exabsent">>, <<"note">>], <<5:256>>}], []},
                                     {[], [{[<<"Exabsent">>, <<"only">>],
                                            <<"ern_exchange_tests_absent">>, <<"f">>}]}]],
               Self ! {answered, Answers}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    ?assertEqual({answered, [{{failed, 'NotLoaded'}, []}, {{failed, 'NotLoaded'}, []}]},
                 receive {answered, _} = Got -> Got end),
    ?assertEqual([<<"the node nohost's spawn at M.f:1 was not loaded: the binding Exabsent.note"
                    " has no value here\n">>,
                  <<"the node nohost's spawn at M.f:1 was not loaded: the module"
                    " ern_exchange_tests_absent, which Exabsent.only calls, is not here\n">>],
                 Said()),
    ?assertError(badarg, binary_to_existing_atom(<<"Exabsent">>)).

%% report §8.7: a frame the exchange cannot read is faulty, and the node
%% ends the peer's connection and says so: a code frame whose bytes are not
%% those the hash it names is taken of, one that names a hash that was not
%% lacked, one whose references are not those its forms name, a reach of
%% another shape, and a request for a reach of no identity. The exchange
%% asked of the peer goes with its forms, a later frame of it passed over,
%% and the spawn the peer asked for with it, none waiting on it now
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
               Faults = [fun(Ref) -> {code_frame, Ref, [Hash], <<Bytes/binary, 0>>, []} end,
                         fun(Ref) -> {code_frame, Ref, [<<6:256>>], Bytes, []} end,
                         fun(Ref) -> {code_frame, Ref, [Hash], Bytes, [<<7:256>>]} end],
               Late = [begin
                           {Exchange, Ref} = Lacking(),
                           Exchange ! {ern_frame, self(), Fault(Ref)},
                           Exchange ! {ern_frame, self(), {code_frame, Ref, [Hash], Bytes, []}},
                           _ = ern_exchange:pinned(),
                           waiting()
                       end || Fault <- Faults],
               {Exchange, Ref} = Asking(),
               Exchange ! {ern_frame, self(), {reach, Ref, [short], [], []}},
               Exchange ! {ern_frame, self(), {reach_request, make_ref(), {function, <<"s">>}}},
               _ = ern_exchange:pinned(),
               Self ! {faulty, Late, waiting()}
           end,
    {Said, Options} = said(),
    ?assertEqual(ok, run(Main, Options)),
    ?assertEqual({faulty, [[], [], []], []}, receive {faulty, _, _} = Got -> Got end),
    ?assertEqual(lists:duplicate(5, <<"the node nohost sent a frame this node cannot read, and its"
                                      " connection was ended\n">>),
                 Said()).

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
               _ = ern_exchange:pinned(),
               First = waiting(),
               ok = ern_exchange:lost(node(Elsewhere)),
               {Exchange, Ref} = receive {ern_frame, From, {reach_request, R, Work}} ->
                                         {From, R}
                                 end,
               ok = ern_exchange:lost(node()),
               Exchange ! {ern_frame, self(), {reach, Ref, [<<9:256>>], [], []}},
               _ = ern_exchange:pinned(),
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
    {ok, Definitions} = ern_canonical:read(Beam),
    {Unit, Beam, maps:from_list([{QualifiedName, Definition}
                                 || #definition{qualified_name = QualifiedName} = Definition
                                        <- Definitions])}.

%% The unit loaded and in the code table, its forms kept beside its code as
%% a shell keeps a unit's that no file holds.
loaded(Unit, Beam) ->
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, atom_to_list(Unit), Beam),
    {ok, Forms} = ern_canonical:read(Beam),
    ok = ern_code:loaded(Unit, Forms).

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

spawned(Ref, {function, Hash}) ->
    {spawn, Ref, {function, Hash}, <<"M.f:1">>, false}.

%% A code frame for a definition alone or a group's members in order.
code_frame(Ref, Members) ->
    Forms = [Form || #definition{form = Form} <- Members],
    {code_frame, Ref, [Hash || #definition{hash = Hash} <- Members],
     ern_canonical:bytes(ern_canonical:hashed(Forms)), referenced(Forms)}.

referenced(Forms) ->
    lists:usort([case Reference of
                     {hash, Hash} -> Hash;
                     {binding, _, Hash} -> Hash
                 end || Reference <- ern_canonical:references(Forms)]).

%% The frames the exchange has sent the stand-in gateway for Ref, once it
%% has read every frame sent it before: pinned/0's answer comes after them.
frames(Ref) ->
    _ = ern_exchange:pinned(),
    collected(Ref, []).

collected(Ref, Acc) ->
    receive
        {ern_frame, _, Body} when element(2, Body) =:= Ref -> collected(Ref, [Body | Acc])
    after 0 ->
        lists:reverse(Acc)
    end.

%% The frames the stand-in gateway holds now, every one the exchange sent
%% having come before pinned/0's answer.
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
