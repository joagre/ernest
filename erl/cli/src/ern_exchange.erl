%% Report §8.7, The exchange: a node's exchange, the one registered process
%% by which a spawn or a compute carries to a peer the definitions of its
%% function's reach the peer lacks, its four frames passing through the
%% gateways (ern_gateway), which hand them here as they come. It plays both
%% parts, for every peer.
%%
%% As the spawner's node it answers a peer's request for a function's reach
%% from the code table and the forms kept beside the code (ern_code:forms/1,
%% report §11.2): the identities the function's definition references,
%% transitively, code and types, the bindings the function's reach names,
%% and the foreign declarations it names, each with the module and the
%% function of the host its declaration calls, by which the peer finds what
%% it lacks; and the peer's lacks with a code frame for each definition it
%% lacks, a group's members in one, since a member is hashed with its
%% group, dependencies first. It keeps nothing of a peer's asking between
%% two frames. Where it no longer holds a function it is asked the reach of,
%% or a definition a peer lacks, the shell having let go of the input that
%% held it once its spawn had given up, it answers a reach of none.
%%
%% As the node a spawn or a compute was asked of, it takes from the
%% gateway's worker each one whose function the node lacks, and asks the
%% spawner's node for the reach; answers `NotLoaded` where the node lacks a
%% foreign declaration's module or a binding's value, before any code
%% crosses, and otherwise the identities it lacks; verifies each code frame
%% against the hashes it names as it arrives, and holds its forms apart
%% until every lacked identity has arrived, pinning meanwhile the units
%% that hold what it said it holds (pinned/0); and then hands the whole
%% reach on (received/2). Two spawns that wait on one identity share one
%% exchange, and are answered together. A frame it cannot read, a form
%% whose hash is not the one named among them, is faulty, and the node
%% ends the peer's connection, as the gateway's worker does (ern_gateway's
%% outcome/2). A loss drops the exchanges asked of the peer with the spawns
%% that peer asked for, each spawn of another peer that waited on one
%% asking its own peer anew; a spawn whose spawner no longer waits is
%% answered all the same, its answer finding no one.
%%
%% The frames, each {ern_frame, From, Body}, From this node's exchange or a
%% peer's: {reach_request, Exchange, Identity}; {reach, Exchange,
%% Identities, Bindings, Foreigns}, or {reach, Exchange, none}; {lacks,
%% Exchange, Hashes}; {code_frame, Exchange, Hashes, Bytes, References}.
%% Exchange is the reference the asking node made for the exchange, an
%% Identity is ern_peer:identity(), a hash the 32 bytes of a SHA-256, a
%% name a list of its segments as text, which makes no atom where a peer
%% sends it; Bindings are {QualifiedName, Hash}, Foreigns {QualifiedName,
%% HostModule, HostFunction}, Hashes the definition alone or the group's
%% members in order, Bytes what that definition or group is hashed as
%% (Appendix H), and References the hashes its forms name, a binding's
%% among them.
-module(ern_exchange).

-export([start/0, handed/1, lacking/3, lost/1, pinned/0]).

-include_lib("typer/include/ern_canonical.hrl").

-define(NAME, ern_exchange).

%% Report §8.7: a reach arrives whole and verified, and what compiles and
%% loads it is MVP 3.2's item 4; until then a node runs none.
-define(NOT_COMPILED,
        <<"this node compiles no received code yet: it arrives in MVP 3.2's item 4">>).

%% Report §8.7: what a spawn fails with when the spawner's node no longer
%% holds what the peer asked it for, the function at the request for the
%% reach or a definition at the lacks.
-define(NO_LONGER_HELD, <<"the spawner's node no longer holds the function's reach">>).

%% An exchange this node asked a peer for, under the reference its frames
%% carry: the identity it asks the reach of; the node asked, the spawner's
%% of the first spawn that waits; the frames waiting on it, each {From,
%% Body} as the gateway's worker read it, in the order they came; the reach
%% once read, {Identities, Bindings, Foreigns}; the hashes still lacked, a
%% map, none before the reach; the code frames verified, the last first,
%% each {Hashes, Forms, References}, held apart from the code table;
%% and the units that hold what this node said it holds, which no let-go
%% may take before the exchange ends (pinned/0).
-record(exchange, {identity, node, waiting, reach = none, lacked = none, arrived = [],
                   pinned = []}).

%% The exchanges by their references, and the reference of each by the
%% identity it asks for, which a second spawn joins.
-record(state, {exchanges = #{}, asked = #{}}).

%% The exchange registered and running, from the node's start, as the
%% gateway is (ern_gateway:start/0).
-spec start() -> ok.
start() ->
    Self = self(),
    Exchange = spawn(fun() ->
                         true = register(?NAME, self()),
                         Self ! {self(), started},
                         loop(#state{})
                     end),
    receive {Exchange, started} -> ok end.

%% A frame of the exchange's four, as the gateway took it.
-spec handed({ern_frame, pid(), tuple()}) -> ok.
handed(Frame) ->
    told(Frame).

%% Report §8.7: a spawn or a compute frame whose function, by Identity,
%% this node lacks, as the gateway's worker read it.
-spec lacking(pid(), tuple(), ern_peer:identity()) -> ok.
lacking(From, Body, Identity) ->
    told({lacking, From, Body, Identity}).

%% Report §8.7: a loss, told once the gateway's worker has handed on every
%% frame that came before it.
-spec lost(node()) -> ok.
lost(Node) ->
    told({lost, Node}).

%% Report §8.7, §11.2: the units that hold what this node told a peer it
%% holds, in every exchange in progress, which a unit let go must not be.
-spec pinned() -> [module()].
pinned() ->
    case whereis(?NAME) of
        undefined ->
            [];
        Exchange ->
            MonitorRef = erlang:monitor(process, Exchange),
            Exchange ! {pinned, self(), MonitorRef},
            receive
                {MonitorRef, Units} -> erlang:demonitor(MonitorRef, [flush]), Units;
                {'DOWN', MonitorRef, process, _, _} -> []
            end
    end.

told(Message) ->
    case whereis(?NAME) of
        undefined -> ok;
        Exchange -> Exchange ! Message, ok
    end.

loop(State) ->
    receive
        {lacking, From, Body, Identity} ->
            loop(asked(From, Body, Identity, State));
        {ern_frame, From, Body} ->
            Node = node(From),
            Read = try frame(From, Body, State)
                   catch _:_ -> unreadable
                   end,
            case Read of
                unreadable ->
                    ok = ern_gateway:outcome(Node, unreadable),
                    loop(dropped(Node, State));
                #state{} = State1 ->
                    loop(State1)
            end;
        {lost, Node} ->
            loop(dropped(Node, State));
        {pinned, From, MonitorRef} ->
            Pinned = [Units || _ := #exchange{pinned = Units} <- State#state.exchanges],
            From ! {MonitorRef, lists:usort(lists:append(Pinned))},
            loop(State)
    end.

%%
%% The node a spawn was asked of
%%

%% Report §8.7: a spawn or a compute this node lacks the function of joins
%% the exchange that asks for its identity, or asks the spawner's node for
%% the reach.
asked(From, Body, Identity, #state{exchanges = Exchanges, asked = Asked} = State) ->
    case Asked of
        #{Identity := Ref} ->
            #{Ref := #exchange{waiting = Waiting} = Exchange} = Exchanges,
            State#state{exchanges = Exchanges#{Ref := Exchange#exchange{
                                                          waiting = Waiting ++ [{From, Body}]}}};
        _ ->
            ask(Identity, [{From, Body}], State)
    end.

%% The request for a reach, of the node of the first of the spawns that
%% wait.
ask(Identity, [{From, _} | _] = Waiting, #state{exchanges = Exchanges, asked = Asked} = State) ->
    Ref = make_ref(),
    Node = node(From),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), {reach_request, Ref, Identity}}),
    State#state{exchanges = Exchanges#{Ref => #exchange{identity = Identity, node = Node,
                                                        waiting = Waiting}},
                asked = Asked#{Identity => Ref}}.

%% Report §8.7: a frame of the exchange's, each field of it checked, or
%% unreadable. A reach or a code frame of an exchange this node no longer
%% holds is late, its spawns answered or dropped with a loss, and is
%% passed over; one from another node than the exchange asked, or one that
%% comes out of its order, is unreadable. A reach of none answers the
%% request for the reach and the lacks alike.
frame(From, {reach_request, Ref, Identity}, State)
  when is_reference(Ref), node(Ref) =:= node(From) ->
    true = is_identity(Identity),
    erlang:send({ern_gateway, node(From)}, {ern_frame, self(), reach_answer(Ref, Identity)}),
    State;
frame(From, {lacks, Ref, Hashes}, State) when is_reference(Ref), node(Ref) =:= node(From) ->
    true = lists:all(fun is_hash/1, Hashes),
    Gateway = {ern_gateway, node(From)},
    case code_frames(Hashes) of
        none ->
            erlang:send(Gateway, {ern_frame, self(), {reach, Ref, none}});
        Frames ->
            [erlang:send(Gateway, {ern_frame, self(), {code_frame, Ref, Named, Bytes, References}})
             || {Named, Bytes, References} <- Frames]
    end,
    State;
frame(From, {reach, Ref, none}, State) when is_reference(Ref), node(Ref) =:= node() ->
    case exchange(From, Ref, State) of
        late -> State;
        #exchange{} = Exchange -> no_longer_held(Ref, Exchange, State)
    end;
frame(From, {reach, Ref, Identities, Bindings, Foreigns}, State)
  when is_reference(Ref), node(Ref) =:= node() ->
    true = lists:all(fun is_hash/1, Identities)
        andalso lists:all(fun({Name, Hash}) -> is_name(Name) andalso is_hash(Hash) end, Bindings)
        andalso lists:all(fun({Name, HostModule, HostFunction}) ->
                              is_name(Name) andalso is_text(HostModule)
                                  andalso is_text(HostFunction)
                          end, Foreigns),
    case exchange(From, Ref, State) of
        late -> State;
        #exchange{reach = none} = Exchange ->
            reached(Ref, Exchange#exchange{reach = {Identities, Bindings, Foreigns}}, State)
    end;
frame(From, {code_frame, Ref, Hashes, Bytes, References}, State)
  when is_reference(Ref), node(Ref) =:= node(), is_list(Hashes), Hashes =/= [],
       is_binary(Bytes), is_list(References) ->
    true = lists:all(fun is_hash/1, References),
    case exchange(From, Ref, State) of
        late -> State;
        #exchange{lacked = Lacked} = Exchange when is_map(Lacked) ->
            %% a group crosses whole, so a member this node did not name
            %% lacking, a binding of its, comes with those it did
            true = lists:any(fun(Hash) -> is_map_key(Hash, Lacked) end, Hashes),
            {ok, Forms} = ern_canonical:verified(Hashes, Bytes),
            References = referenced(Forms),
            arrived(Ref, Exchange, {Hashes, Forms, References}, State)
    end.

%% The exchange Ref names, where the node asked sent the frame; late where
%% this node holds it no more.
exchange(From, Ref, #state{exchanges = Exchanges}) ->
    case Exchanges of
        #{Ref := #exchange{node = Node} = Exchange} when Node =:= node(From) -> Exchange;
        #{} when is_map_key(Ref, Exchanges) -> erlang:error(another_node);
        #{} -> late
    end.

%% Report §8.7: the reach read: `NotLoaded` for every spawn that waits
%% where this node lacks a foreign declaration's module or a binding's
%% value, before any code crosses; otherwise the identities it lacks asked
%% for, the units that hold the others and the bindings pinned meanwhile,
%% or, where it lacks none, the reach received at once.
reached(Ref, #exchange{reach = {Identities, Bindings, Foreigns}, node = Node} = Exchange, State) ->
    case ern_peer:reach_lacked(Bindings, Foreigns) of
        none ->
            Lacks = [Hash || Hash <- Identities, ern_code:holders({hash, Hash}) =:= []],
            Lacked = maps:from_keys(Lacks, true),
            %% the bindings' holders too, whose values this node said it
            %% has, their names atoms here since they have values
            Holding = [{hash, Hash} || Hash <- Identities, not is_map_key(Hash, Lacked)]
                ++ [{binding, [binary_to_existing_atom(Segment) || Segment <- Name], Hash}
                    || {Name, Hash} <- Bindings],
            Pinned = lists:usort(lists:append([ern_code:holders(Key) || Key <- Holding])),
            Exchange1 = Exchange#exchange{lacked = Lacked, pinned = Pinned},
            case Lacks of
                [] ->
                    completed(Ref, Exchange1, State);
                _ ->
                    erlang:send({ern_gateway, Node}, {ern_frame, self(), {lacks, Ref, Lacks}}),
                    kept(Ref, Exchange1, State)
            end;
        Lacked ->
            answered(Exchange#exchange.waiting, 'NotLoaded', Lacked),
            ended(Ref, State)
    end.

%% Report §8.7: a code frame verified, held apart with the others; the reach
%% received once every lacked identity has arrived.
arrived(Ref, #exchange{lacked = Lacked, arrived = Arrived} = Exchange, {Hashes, _, _} = Frame,
        State) ->
    Exchange1 = Exchange#exchange{lacked = maps:without(Hashes, Lacked),
                                  arrived = [Frame | Arrived]},
    case map_size(Exchange1#exchange.lacked) of
        0 -> completed(Ref, Exchange1, State);
        _ -> kept(Ref, Exchange1, State)
    end.

%% Report §8.7: the reach complete and verified, received, and every spawn
%% that waits answered by it.
completed(Ref, #exchange{waiting = Waiting, arrived = Arrived, reach = Reach}, State) ->
    {error, Text} = received(lists:reverse(Arrived), Reach),
    answered(Waiting, {'Other', Text}, Text),
    ended(Ref, State).

%% Report §8.7: a reach whole and verified, each code frame's forms with the
%% hashes it names and those its forms reference, dependencies first, and
%% the reach as the peer gave it, its bindings and its foreign declarations
%% with their modules: what compiles it into one unit and loads it is MVP
%% 3.2's item 4, until when a node runs nothing it receives.
received(_Arrived, _Reach) ->
    {error, ?NOT_COMPILED}.

%% Report §8.7: the spawner's node no longer holds what it was asked for:
%% the spawns it asked for answered so, and those of any other node that
%% waited on the exchange asking their own nodes anew.
no_longer_held(Ref, #exchange{node = Node, identity = Identity, waiting = Waiting}, State) ->
    {Asked, Others} = lists:partition(fun({From, _}) -> node(From) =:= Node end, Waiting),
    answered(Asked, {'Other', ?NO_LONGER_HELD}, ?NO_LONGER_HELD),
    again(Identity, Others, ended(Ref, State)).

%% Each frame that waits answered with Error, and said with Lacked.
answered(Waiting, Error, Lacked) ->
    lists:foreach(fun({From, Body}) ->
                      ok = ern_gateway:outcome(node(From), ern_peer:failed(From, Body, Error,
                                                                          Lacked))
                  end, Waiting).

%% Report §8.7: a loss of Node, or a faulty frame from it, whose connection
%% then ends: each exchange asked of it dropped with its forms, its spawns
%% of other nodes asking their own anew, and every spawn of Node's dropped,
%% none waiting on it any more.
dropped(Node, #state{exchanges = Exchanges} = State) ->
    maps:fold(fun(Ref, #exchange{node = Asked, identity = Identity, waiting = Waiting} = Exchange,
                  Acc) ->
                  Others = [Frame || {From, _} = Frame <- Waiting, node(From) =/= Node],
                  case Asked of
                      Node -> again(Identity, Others, ended(Ref, Acc));
                      _ when Others =:= [] -> ended(Ref, Acc);
                      _ -> kept(Ref, Exchange#exchange{waiting = Others}, Acc)
                  end
              end, State, Exchanges).

again(_Identity, [], State) ->
    State;
again(Identity, Waiting, State) ->
    ask(Identity, Waiting, State).

kept(Ref, Exchange, #state{exchanges = Exchanges} = State) ->
    State#state{exchanges = Exchanges#{Ref := Exchange}}.

ended(Ref, #state{exchanges = Exchanges, asked = Asked} = State) ->
    #{Ref := #exchange{identity = Identity}} = Exchanges,
    State#state{exchanges = maps:remove(Ref, Exchanges), asked = maps:remove(Identity, Asked)}.

%%
%% The spawner's node
%%

%% Report §8.7: the reach of the function Identity names: the hashes of
%% the definitions it reaches, from the definition it is or is in, code and
%% types, the bindings its reach names, and its foreign declarations with
%% their modules and functions; or none where this node no longer holds it.
reach_answer(Ref, Identity) ->
    case reach(Identity) of
        none ->
            {reach, Ref, none};
        {Identities, Bindings, Foreigns} ->
            {reach, Ref, Identities, Bindings, Foreigns}
    end.

reach({function, Hash}) ->
    reach({hash, Hash}, Hash);
reach({lambda, Hash, Position}) ->
    reach({lambda, Hash, Position}, Hash).

reach(Key, Hash) ->
    case ern_code:spawnable(Key) of
        none ->
            none;
        {Unit, _Function, _Arity, {Bindings, Foreigns}} ->
            case {reached_definitions([Hash], #{}, #{}), implementations(Unit, Foreigns)} of
                {{ok, Definitions}, {ok, Implemented}} ->
                    {lists:usort([Defined || #definition{hash = Defined, kind = Kind}
                                                 <- Definitions, Kind =/= binding]),
                     [{texts(QualifiedName), BindingHash}
                      || {QualifiedName, BindingHash} <- Bindings],
                     Implemented};
                _ ->
                    none
            end
    end.

%% The definitions Hashes reach, transitively, through the functions and
%% the types their forms reference by hash, each with its group; none
%% where this node holds one of them nowhere. Read keeps the forms of each
%% unit read.
reached_definitions([], Found, _Read) ->
    {ok, maps:values(Found)};
reached_definitions([Hash | Hashes], Found, Read) when is_map_key(Hash, Found) ->
    reached_definitions(Hashes, Found, Read);
reached_definitions([Hash | Hashes], Found, Read) ->
    case members(Hash, Read) of
        none ->
            none;
        {Members, Read1} ->
            Found1 = maps:merge(Found, maps:from_list([{Member, Definition}
                                                       || #definition{hash = Member} = Definition
                                                              <- Members])),
            Referenced = [Referenced
                          || {hash, Referenced} <- ern_canonical:references(forms(Members))],
            reached_definitions(Referenced ++ Hashes, Found1, Read1)
    end.

%% The foreign declarations of a function's reach, each with the module and
%% the function of the host its declaration calls, as the units the code of
%% the unit that runs it calls hold it; none where one of them holds none.
implementations(Unit, Foreigns) ->
    Called = ern_code:called(Unit),
    Found = [{QualifiedName, ern_code:foreign(Called, QualifiedName)} || QualifiedName <- Foreigns],
    case [QualifiedName || {QualifiedName, []} <- Found] of
        [] -> {ok, [{texts(QualifiedName), atom_to_binary(HostModule),
                     atom_to_binary(HostFunction)}
                    || {QualifiedName, [{HostModule, HostFunction} | _]} <- Found]};
        _ -> none
    end.

%% Report §8.7, Appendix H: a code frame for each definition Hashes names,
%% a group's members in one, dependencies first; none where this node holds
%% one of them nowhere.
code_frames(Hashes) ->
    case grouped(Hashes, [], #{}, #{}) of
        none ->
            none;
        {Keys, Groups} ->
            ByHash = maps:from_list([{Member, Key} || Key := Members <- Groups,
                                                      #definition{hash = Member} <- Members]),
            {Order, _} = lists:foldl(fun(Key, Acc) -> first_needed(Key, Groups, ByHash, Acc) end,
                                     {[], #{}}, Keys),
            [code_frame(maps:get(Key, Groups)) || Key <- lists:reverse(Order)]
    end.

%% Each definition's group, by its group's hash or its own, in the order of
%% Hashes.
grouped([], Keys, Groups, _Read) ->
    {lists:reverse(Keys), Groups};
grouped([Hash | Hashes], Keys, Groups, Read) ->
    case members(Hash, Read) of
        none ->
            none;
        {[#definition{group = Group} | _] = Members, Read1} ->
            Key = case Group of
                      none -> Hash;
                      {GroupHash, _} -> GroupHash
                  end,
            case Groups of
                #{Key := _} -> grouped(Hashes, Keys, Groups, Read1);
                _ -> grouped(Hashes, [Key | Keys], Groups#{Key => Members}, Read1)
            end
    end.

%% The groups Key's forms reference put before it, and Key, in Order, which
%% is reversed: a definition's dependencies cross before it.
first_needed(Key, _Groups, _ByHash, {_, Seen} = Acc) when is_map_key(Key, Seen) ->
    Acc;
first_needed(Key, Groups, ByHash, {Order, Seen}) ->
    Members = maps:get(Key, Groups),
    Needed = lists:usort([maps:get(Referenced, ByHash)
                          || {hash, Referenced} <- ern_canonical:references(forms(Members)),
                             is_map_key(Referenced, ByHash)]) -- [Key],
    {Order1, Seen1} = lists:foldl(fun(Dependency, Acc) ->
                                      first_needed(Dependency, Groups, ByHash, Acc)
                                  end, {Order, Seen#{Key => true}}, Needed),
    {[Key | Order1], Seen1}.

%% Report Appendix H: a definition alone, or a group's members in order, as
%% a code frame carries it: the hashes, the bytes they are taken of, and
%% the hashes its forms reference.
code_frame(Members) ->
    Forms = forms(Members),
    {[Hash || #definition{hash = Hash} <- Members],
     ern_canonical:bytes(ern_canonical:hashed(Forms)), referenced(Forms)}.

%% The definition of Hash this node holds, alone or with the other members
%% of its group in their order, read from the forms of the latest unit that
%% holds it; none where no unit's forms hold it.
members(Hash, Read) ->
    member_of(lists:reverse(ern_code:holders({hash, Hash})), Hash, Read).

member_of([], _Hash, _Read) ->
    none;
member_of([Unit | Units], Hash, Read) ->
    {Definitions, Read1} = case Read of
                               #{Unit := Kept} ->
                                   {Kept, Read};
                               _ ->
                                   Forms = case ern_code:forms(Unit) of
                                               {ok, Held} -> Held;
                                               none -> []
                                           end,
                                   {Forms, Read#{Unit => Forms}}
                           end,
    case [Definition || #definition{hash = Defined} = Definition <- Definitions,
                        Defined =:= Hash] of
        [#definition{group = none} = Definition | _] ->
            {[Definition], Read1};
        [#definition{group = {GroupHash, _}} | _] ->
            Members = [Member || #definition{group = {Of, _}} = Member <- Definitions,
                                 Of =:= GroupHash],
            {lists:sort(fun(#definition{group = {_, A}}, #definition{group = {_, B}}) -> A =< B end,
                        Members),
             Read1};
        [] ->
            member_of(Units, Hash, Read1)
    end.

%%
%% Shared
%%

forms(Members) ->
    [Form || #definition{form = Form} <- Members].

%% Report §8.7: the hashes forms reference, a binding's among them, as a
%% code frame names them.
referenced(Forms) ->
    lists:usort([case Reference of
                     {hash, Hash} -> Hash;
                     {binding, _, Hash} -> Hash
                 end || Reference <- ern_canonical:references(Forms)]).

texts(QualifiedName) ->
    [atom_to_binary(Segment) || Segment <- QualifiedName].

is_identity({function, Hash}) -> is_hash(Hash);
is_identity({lambda, Hash, Position}) -> is_hash(Hash) andalso is_integer(Position)
                                             andalso Position > 0;
is_identity(_) -> false.

is_hash(Hash) ->
    is_binary(Hash) andalso byte_size(Hash) =:= 32.

is_name(Name) ->
    is_list(Name) andalso Name =/= [] andalso lists:all(fun is_text/1, Name).

is_text(Text) ->
    is_binary(Text) andalso ern_fs:is_utf8(Text).
