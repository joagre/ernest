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
%% function of the host its declaration calls, its declared type and what
%% prints a type in its check's cause as its module writes it, by which the
%% peer finds what it lacks and calls the host's function; a foreign
%% function spawned by its name, which has no hash, has its declaration
%% alone in its reach. It answers the peer's lacks with a code frame for
%% each definition it lacks, a group's members in one, since a member is
%% hashed with its group, dependencies first, each with its name, the lines
%% of its source, what prints a type in a cause as its module writes it
%% (§11.5), and the foreign declarations its form calls, each with the
%% host's module and function, so that the peer calls those beyond the
%% spawned function's reach as it calls the reach's (§8.4). It keeps
%% nothing of a peer's asking between two frames. Where
%% it no longer holds a function it is asked the reach of, or a definition
%% a peer lacks, the shell having let go of the input that held it once its
%% spawn had given up, it answers a reach of none.
%%
%% As the node a spawn or a compute was asked of, it takes from the
%% gateway's worker each one whose function the node lacks, and asks the
%% spawner's node for the reach; answers `NotLoaded` where the node lacks
%% the module a foreign declaration names, or the function in it, or a
%% binding's value, before any code crosses, and otherwise the identities
%% it lacks, a definition it holds in no unit that exports its function
%% among them (§8.7, §11.1), since no other unit's code can call it
%% (ern_code:linkable/1); verifies each code frame against the hashes it
%% names as it arrives, its forms with their source's lines against the
%% forms, and its foreign declarations against those the forms call, and
%% holds them apart until every lacked identity has arrived; and then
%% makes the whole reach one unit, compiled and loaded
%% (ern_arrival), which the node holds for its life (§11.2), and reads
%% each spawn and compute that waits again as the gateway's worker reads
%% it, which starts it, or answers it `Other` with the reason it could
%% not. Two spawns that wait on
%% one identity share one exchange, and are answered together. An exchange
%% runs within the time of the spawns that wait on it, the milliseconds
%% their frames carry, and is dropped with its forms once the last of them
%% has run out, each spawn said and left unanswered, its spawner having
%% answered itself `Timeout`. A frame it
%% cannot read, a form whose hash is not the one named among them, is
%% faulty, and the node ends the peer's connection, as the gateway's worker
%% does (ern_gateway's outcome/2). A loss drops the exchanges asked of the
%% peer with the spawns that peer asked for, each spawn of another peer
%% that waited on one asking its own peer anew; a spawn whose spawner no
%% longer waits is answered all the same, its answer finding no one.
%%
%% The node's pool of names for the units its exchanges make is the
%% exchange's (ern_arrival:name/1), the only process that makes them; and
%% so is the prelude's environment, by which a unit links what the
%% standard library and the prelude declare, built at the first arrival
%% and kept for the node's life, since neither changes while it runs.
%%
%% The frames, each {ern_frame, From, Body}, From this node's exchange or a
%% peer's: {reach_request, Exchange, Identity}; {reach, Exchange, Identities,
%% Bindings, Foreigns}, or {reach, Exchange, none}; {lacks, Exchange, Hashes};
%% {code_frame, Exchange, Hashes, Bytes, References, Sources}. Exchange is the
%% reference the asking node made for the exchange, an Identity is
%% ern_peer:identity(), a hash the 32 bytes of a SHA-256, a name a list of its
%% segments as text, which makes no atom where a peer sends it; Bindings are
%% {QualifiedName, Hash}, Foreigns {QualifiedName, HostModule, HostFunction,
%% Scheme, Printing}, the scheme as a form writes it (Appendix H), Hashes the
%% definition alone or the group's members in order, Bytes what that
%% definition or group is hashed as (Appendix H), References the hashes its
%% forms name, a binding's among them, which §8.7 has the frame carry and the
%% node it arrives at recomputes from the forms, a frame whose References
%% differ from them being faulty, and uses no further, and Sources the bytes
%% of the host's external term format of a list of {Name, Sourced, Printing,
%% Calls}, one for each of Hashes in order: the definition's name, its form
%% with the lines of its source, the locals' names left out (§11.1), which,
%% stripped of its source, is the form the bytes hold, and holds no atom the
%% form does not, so that it is read once the form is, making none; Printing
%% is {Namespace, Shadows}, the namespace its module's forms write its types
%% under and the prelude names its types shadow, as text, by which a type
%% prints in a cause as the module writes it (§11.5); and Calls the foreign
%% declarations its form calls, in the order of their names, each
%% {QualifiedName, HostModule, HostFunction, Printing}, as text, the scheme
%% being the one the form writes (§8.7).
-module(ern_exchange).

-export([start/0, handed/1, lacking/3, lost/1]).

-include_lib("checker/include/ern_canonical.hrl").

-define(NAME, ern_exchange).

%% Report §8.7: what a spawn fails with when the spawner's node no longer
%% holds what the peer asked it for, the function at the request for the
%% reach or a definition at the lacks.
-define(NO_LONGER_HELD, <<"the spawner's node no longer holds the function's reach">>).

%% Report §8.7: why the node did not start a spawn whose time ran out before
%% the reach of its function arrived.
-define(TIMED_OUT, <<"its time ran out before the function's reach arrived">>).

%% An exchange this node asked a peer for, under the reference its frames
%% carry: the identity it asks the reach of; the node asked, the spawner's
%% of the first spawn that waits; the frames waiting on it, each {From,
%% Body} as the gateway's worker read it, in the order they came; the
%% moment the last of their times runs out, each counted from its frame's
%% coming; the reach once read, {Identities, Bindings, Foreigns}; the
%% hashes still lacked, a map, none before the reach; the code frames
%% verified, the last first, each its members, {#definition{}, Calls},
%% named by the names the frame gave them, with the foreign declarations
%% each calls, held apart from the code table.
-record(exchange, {identity, node, waiting, deadline, reach = none, lacked = none,
                   arrived = []}).

%% The exchanges by their references, and the reference of each by the
%% identity it asks for, which a second spawn joins; the count the pool's
%% next name is taken from (ern_arrival:name/1); and the prelude's
%% environment, none before the first arrival.
-record(state, {exchanges = #{}, asked = #{}, next = 1, env = none}).

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
        {deadline, Ref} ->
            loop(timed(Ref, State))
    end.

%%
%% The node a spawn was asked of
%%

%% Report §8.7: a spawn or a compute this node lacks the function of joins
%% the exchange that asks for its identity, whose time it lengthens to its
%% own where its own ends later, or asks the spawner's node for the reach;
%% its time is the milliseconds its spawner waits, from its frame's coming,
%% so that it never runs out before the spawner's own.
asked(From, Body, Identity, #state{exchanges = Exchanges, asked = Asked} = State) ->
    Deadline = ern_rt:deadline(ern_peer:ms(Body)),
    case Asked of
        #{Identity := Ref} ->
            #{Ref := #exchange{waiting = Waiting, deadline = Latest} = Exchange} = Exchanges,
            Joined = Exchange#exchange{waiting = Waiting ++ [{From, Body}],
                                       deadline = max(Latest, Deadline)},
            State#state{exchanges = Exchanges#{Ref := Joined}};
        _ ->
            ask(Identity, [{From, Body}], Deadline, State)
    end.

%% The request for a reach, of the node of the first of the spawns that
%% wait, and the timer towards the moment its time runs out.
ask(Identity, [{From, _} | _] = Waiting, Deadline,
    #state{exchanges = Exchanges, asked = Asked} = State) ->
    Ref = make_ref(),
    Node = node(From),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), {reach_request, Ref, Identity}}),
    ok = armed(Ref, Deadline),
    State#state{exchanges = Exchanges#{Ref => #exchange{identity = Identity, node = Node,
                                                        waiting = Waiting,
                                                        deadline = Deadline}},
                asked = Asked#{Identity => Ref}}.

%% Report §8.7: an exchange whose time has run out, every spawner that
%% waits on it having given up at its own, `Timeout` its answer, dropped
%% with its forms, each spawn said as one the node did not start and left
%% unanswered, so that no answer of this node's comes before a spawner's
%% own; one whose time a later spawn lengthened waits on; one that has
%% ended is none. The host's timer takes a slice of a long time at once,
%% and is set again until the moment comes (ern_rt:remaining/1).
timed(Ref, #state{exchanges = Exchanges} = State) ->
    case Exchanges of
        #{Ref := #exchange{deadline = Deadline, waiting = Waiting}} ->
            case ern_rt:remaining(Deadline) of
                0 ->
                    [ok = ern_gateway:outcome(node(From), ern_peer:unstarted(Body, ?TIMED_OUT))
                     || {From, Body} <- Waiting],
                    ended(Ref, State);
                _ ->
                    ok = armed(Ref, Deadline),
                    State
            end;
        #{} ->
            State
    end.

armed(Ref, Deadline) ->
    _ = erlang:send_after(ern_rt:remaining(Deadline), self(), {deadline, Ref}),
    ok.

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
            [erlang:send(Gateway, {ern_frame, self(), {code_frame, Ref, Named, Bytes, References,
                                                       Sources}})
             || {Named, Bytes, References, Sources} <- Frames]
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
        andalso lists:all(fun({Name, HostModule, HostFunction, Scheme, Printing}) ->
                              is_name(Name) andalso is_text(HostModule)
                                  andalso is_text(HostFunction) andalso is_scheme(Scheme)
                                  andalso is_printing(Printing)
                          end, Foreigns),
    case exchange(From, Ref, State) of
        late -> State;
        #exchange{reach = none} = Exchange ->
            reached(Ref, Exchange#exchange{reach = {Identities, Bindings, Foreigns}}, State)
    end;
frame(From, {code_frame, Ref, Hashes, Bytes, References, Sources}, State)
  when is_reference(Ref), node(Ref) =:= node(), is_list(Hashes), Hashes =/= [],
       is_binary(Bytes), is_list(References), is_binary(Sources) ->
    true = lists:all(fun is_hash/1, References),
    case exchange(From, Ref, State) of
        late -> State;
        #exchange{lacked = Lacked} = Exchange when is_map(Lacked) ->
            %% a group crosses whole, so a member this node did not name
            %% lacking, a binding of its, comes with those it did
            true = lists:any(fun(Hash) -> is_map_key(Hash, Lacked) end, Hashes),
            {ok, Forms} = ern_canonical:verified(Hashes, Bytes),
            %% the hashes the frame says its forms name, a check on the
            %% frame alone: the arrival reads its references from the
            %% forms themselves (ern_arrival)
            References = referenced(Forms),
            arrived(Ref, Exchange, framed(Hashes, Bytes, Forms, Sources), State)
    end.

%% The exchange Ref names, where the node asked sent the frame; late where
%% this node holds it no more.
exchange(From, Ref, #state{exchanges = Exchanges}) ->
    case Exchanges of
        #{Ref := #exchange{node = Node} = Exchange} when Node =:= node(From) -> Exchange;
        #{} when is_map_key(Ref, Exchanges) -> erlang:error(another_node);
        #{} -> late
    end.

%% Report §8.7: a code frame's members, each a #definition{} named by the
%% name the frame gave it, with its form and its form with the lines of
%% its source, which must be the form the bytes hold once its source is
%% taken out, a group's by its hash and its member's position; and beside
%% it the foreign declarations it calls, which must be those its form calls,
%% by their names, each with the host's module and function as text.
framed(Hashes, Bytes, Forms, Sources) ->
    Group = case Hashes of
                [_] -> fun(_) -> none end;
                _ -> fun(Position) -> {crypto:hash(sha256, Bytes), Position} end
            end,
    [member(Hash, Form, Source, Group(Position))
     || {Position, {Hash, Form, Source}}
            <- lists:enumerate(lists:zip3(Hashes, Forms, binary_to_term(Sources, [safe])))].

member(Hash, Form, {Name, Sourced, Printing, Calls}, Group) ->
    true = is_name(Name) andalso is_printing(Printing) andalso is_list(Calls)
        andalso lists:all(fun is_call/1, Calls),
    Form = ern_canonical:stripped(Sourced),
    true = [Called || {Called, _, _, _} <- Calls] =:= called_names(Form),
    {#definition{qualified_name = Name, kind = kind(Form), hash = Hash, form = Form,
                 group = Group, sourced = Sourced, printing = Printing},
     Calls}.

is_call({Name, HostModule, HostFunction, Printing}) ->
    is_name(Name) andalso is_text(HostModule) andalso is_text(HostFunction)
        andalso is_printing(Printing);
is_call(_) ->
    false.

kind({function, _, _, _, _, _, _}) -> function;
kind({binding, _, _, _}) -> binding;
kind({type, _, _, _, _, _}) -> type.

%% Report §8.7: the reach read: `NotLoaded` for every spawn that waits
%% where this node lacks the module a foreign declaration names, or the
%% function in it, or a binding's value, before any code crosses;
%% otherwise the identities it lacks asked for, or, where it lacks none,
%% the reach received at once. An identity it holds in no unit that
%% exports its function is lacked (§8.7, §11.1), since a unit made of what
%% arrives could not call it (ern_code:linkable/1).
reached(Ref, #exchange{reach = {Identities, Bindings, Foreigns}, node = Node} = Exchange, State) ->
    case ern_peer:reach_lacked(Bindings, Foreigns) of
        none ->
            Lacks = [Hash || Hash <- Identities, ern_code:linkable(Hash) =:= none],
            Exchange1 = Exchange#exchange{lacked = maps:from_keys(Lacks, true)},
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
arrived(Ref, #exchange{lacked = Lacked, arrived = Arrived} = Exchange, Members, State) ->
    Exchange1 = Exchange#exchange{lacked = maps:without([Hash || {#definition{hash = Hash}, _}
                                                                     <- Members], Lacked),
                                  arrived = [Members | Arrived]},
    case map_size(Exchange1#exchange.lacked) of
        0 -> completed(Ref, Exchange1, State);
        _ -> kept(Ref, Exchange1, State)
    end.

%% Report §8.7: the reach complete and verified, received, one unit loaded
%% whole before any of it runs, and every spawn and compute that waits read
%% again as the gateway's worker reads it, which starts it; where the node
%% could not take the reach, each answered `Other` with its reason, which
%% the node says.
completed(Ref, #exchange{identity = Identity, waiting = Waiting, arrived = Arrived,
                         reach = {_, Bindings, Foreigns}}, State) ->
    Members = lists:append(lists:reverse(Arrived)),
    {Received, State1} = received(Identity, [Definition || {Definition, _} <- Members],
                                  lists:append([Calls || {_, Calls} <- Members]),
                                  {Bindings, Foreigns}, State),
    case Received of
        ok -> lists:foreach(fun started/1, Waiting);
        {error, Text} -> answered(Waiting, {'Other', Text}, Text)
    end,
    ended(Ref, State1).

%% Report §8.7, §11.2: the definitions that arrived, dependencies first,
%% with the foreign declarations their code frames say they call, and the
%% spawned function's reach, its bindings and its foreign declarations,
%% made one unit under the pool's next name and loaded (ern_arrival);
%% nothing where none arrived and the node now holds the identity, another
%% exchange having brought it, a foreign function's declaration among them.
received(Identity, Arrived, Declared, Reach, State) ->
    case Arrived =:= [] andalso ern_code:spawnable(key(Identity)) =/= none of
        true -> {ok, State};
        false -> unit_received(Arrived, Declared, Reach, State)
    end.

unit_received(Arrived, Declared, Reach, #state{next = Next, env = Env} = State) ->
    Prelude = case Env of
                  none -> ern_typecheck:prelude_env();
                  _ -> Env
              end,
    {Unit, Taken} = ern_arrival:name(Next),
    case ern_arrival:received(Unit, Arrived, Declared, Reach, Prelude) of
        ok -> {ok, State#state{next = Taken, env = Prelude}};
        {error, _} = Error -> {Error, State#state{env = Prelude}}
    end.

key({function, Hash}) -> {hash, Hash};
key({lambda, Hash, Position}) -> {lambda, Hash, Position};
key({foreign, Names}) -> {foreign, Names}.

%% Report §8.7: a spawn or a compute that waited, read again now its reach
%% is loaded, and what its reading tells the node said, as the gateway's
%% worker says it; one whose function the unit did not bring after all is
%% answered `Other`, saying so.
started({From, Body}) ->
    Read = try ern_peer:frame(From, Body)
           catch _:_ -> unreadable
           end,
    case Read of
        {exchange, _} ->
            Text = <<"the reach that arrived does not hold the function">>,
            answered([{From, Body}], {'Other', Text}, Text);
        _ ->
            ok = ern_gateway:outcome(node(From), Read)
    end.

%% Report §8.7: the spawner's node no longer holds what it was asked for:
%% the spawns it asked for answered so, and those of any other node that
%% waited on the exchange asking their own nodes anew.
no_longer_held(Ref, #exchange{node = Node, identity = Identity, waiting = Waiting,
                               deadline = Deadline}, State) ->
    {Asked, Others} = lists:partition(fun({From, _}) -> node(From) =:= Node end, Waiting),
    answered(Asked, {'Other', ?NO_LONGER_HELD}, ?NO_LONGER_HELD),
    again(Identity, Others, Deadline, ended(Ref, State)).

%% Each frame that waits answered with Error, and said with Lacked.
answered(Waiting, Error, Lacked) ->
    lists:foreach(fun({From, Body}) ->
                      ok = ern_gateway:outcome(node(From), ern_peer:failed(From, Body, Error,
                                                                          Lacked))
                  end, Waiting).

%% Report §8.7: a loss of Node, or a faulty frame from it, whose connection
%% then ends: each exchange asked of it dropped with its forms, its spawns
%% of other nodes asking their own anew within the time the exchange had,
%% and every spawn of Node's dropped, none waiting on it any more.
dropped(Node, #state{exchanges = Exchanges} = State) ->
    maps:fold(fun(Ref, #exchange{node = Asked, identity = Identity, waiting = Waiting,
                                 deadline = Deadline} = Exchange,
                  Acc) ->
                  Others = [Frame || {From, _} = Frame <- Waiting, node(From) =/= Node],
                  case Asked of
                      Node -> again(Identity, Others, Deadline, ended(Ref, Acc));
                      _ when Others =:= [] -> ended(Ref, Acc);
                      _ -> kept(Ref, Exchange#exchange{waiting = Others}, Acc)
                  end
              end, State, Exchanges).

again(_Identity, [], _Deadline, State) ->
    State;
again(Identity, Waiting, Deadline, State) ->
    ask(Identity, Waiting, Deadline, State).

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
%% their modules, functions and declared types; a foreign function's its
%% declaration alone; or none where this node no longer holds it.
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
    reach({lambda, Hash, Position}, Hash);
reach({foreign, Names} = Key) ->
    case ern_code:spawnable(Key) of
        none ->
            %% report §8.7: one this node holds only as a declaration whose
            %% call a unit an exchange made linked to a fault crosses as
            %% that declaration, the peer finding what it lacks itself
            case ern_code:declared(Names) of
                [{Holder, _} | _] -> foreign_reach(Holder, [Names]);
                [] -> none
            end;
        {Unit, _Function, _Arity, {[], Foreigns}} ->
            foreign_reach(Unit, Foreigns)
    end.

foreign_reach(Unit, Foreigns) ->
    case implementations(Unit, Foreigns, #{}) of
        {{ok, Implemented}, _} -> {[], [], Implemented};
        {none, _} -> none
    end.

%% A request reads each unit's forms once, the reach's definitions and its
%% foreign declarations from the same reading (recorded/2).
reach(Key, Hash) ->
    case ern_code:spawnable(Key) of
        none ->
            none;
        {Unit, _Function, _Arity, {Bindings, Foreigns}} ->
            case reached_definitions([Hash], #{}, #{}) of
                {ok, Definitions, Read} ->
                    case implementations(Unit, Foreigns, Read) of
                        {{ok, Implemented}, _} ->
                            {lists:usort([Defined || #definition{hash = Defined, kind = Kind}
                                                         <- Definitions, Kind =/= binding]),
                             [{ern_namespace:text_segments(QualifiedName), BindingHash}
                              || {QualifiedName, BindingHash} <- Bindings],
                             Implemented};
                        {none, _} ->
                            none
                    end;
                none ->
                    none
            end
    end.

%% The definitions Hashes reach, transitively, through the functions and
%% the types their forms reference by hash, each with its group, and Read,
%% the forms of each unit read; none where this node holds one of them
%% nowhere.
reached_definitions([], Found, Read) ->
    {ok, maps:values(Found), Read};
reached_definitions([Hash | Hashes], Found, Read) when is_map_key(Hash, Found) ->
    reached_definitions(Hashes, Found, Read);
reached_definitions([Hash | Hashes], Found, Read) ->
    case members(Hash, Read) of
        none ->
            none;
        {Members, _Unit, Read1} ->
            Found1 = maps:merge(Found, maps:from_list([{Member, Definition}
                                                       || #definition{hash = Member} = Definition
                                                              <- Members])),
            Referenced = [Referenced
                          || {hash, Referenced} <- ern_canonical:references(forms(Members))],
            reached_definitions(Referenced ++ Hashes, Found1, Read1)
    end.

%% The foreign declarations of a function's reach, each with the module and
%% the function of the host its declaration calls, as text, and its
%% declared type, as the units the code of the unit that runs it calls
%% hold it, the type from what the unit that holds it records; or, for one
%% whose call a unit an exchange made linked to a fault, as that unit
%% records it (ern_code:declared/2), so that the node ships it onward as
%% its own; none where one of them is held nowhere. Read is the forms of
%% the units the request has read, and grows by any read here.
implementations(Unit, Foreigns, Read) ->
    Called = ern_code:called(Unit),
    {Found, Read1} = lists:mapfoldl(fun(QualifiedName, Acc) ->
                                        {Implemented, Acc1} =
                                            implementation(Called, QualifiedName, Acc),
                                        Named = ern_namespace:text_segments(QualifiedName),
                                        {{Named, Implemented}, Acc1}
                                    end, Read, Foreigns),
    case lists:keymember(none, 2, Found) of
        false ->
            {{ok, [{Name, HostModule, HostFunction, Scheme, Printing}
                   || {Name, {HostModule, HostFunction, Scheme, Printing}} <- Found]},
             Read1};
        true ->
            {none, Read1}
    end.

implementation(Called, QualifiedName, Read) ->
    case ern_code:foreign(Called, QualifiedName) of
        [{Holder, HostModule, HostFunction} | _] ->
            case declared(Holder, ern_namespace:text_segments(QualifiedName), Read) of
                {{Scheme, Printing}, Read1} ->
                    {{atom_to_binary(HostModule), atom_to_binary(HostFunction), Scheme, Printing},
                     Read1};
                {none, Read1} ->
                    {none, Read1}
            end;
        [] ->
            case ern_code:declared(Called, QualifiedName) of
                [{_, {_, Scheme, HostModule, HostFunction, Printing}} | _] ->
                    {{ern_namespace:text_segment(HostModule),
                      ern_namespace:text_segment(HostFunction), Scheme, Printing}, Read};
                [] ->
                    {none, Read}
            end
    end.

%% The scheme of the foreign declaration Name, and what prints a type in
%% its check's cause, as the unit Holder records them, or none.
declared(Holder, Name, Read) ->
    case recorded(Holder, Read) of
        {#recorded{foreign = Recorded}, Read1} ->
            case [{Scheme, Printing} || {QualifiedName, Scheme, _, _, Printing} <- Recorded,
                                        ern_namespace:text_segments(QualifiedName) =:= Name] of
                [Declared | _] -> {Declared, Read1};
                [] -> {none, Read1}
            end;
        {none, Read1} ->
            {none, Read1}
    end.

%% Report §8.7, Appendix H: a code frame for each definition Hashes names,
%% a group's members in one, dependencies first; none where this node holds
%% one of them nowhere.
code_frames(Hashes) ->
    case grouped(Hashes, [], #{}, #{}) of
        none ->
            none;
        {Keys, Groups, Read} ->
            ByHash = maps:from_list([{Member, Key} || Key := {Members, _} <- Groups,
                                                      #definition{hash = Member} <- Members]),
            {Order, _} = lists:foldl(fun(Key, Acc) -> first_needed(Key, Groups, ByHash, Acc) end,
                                     {[], #{}}, Keys),
            {Frames, _} = lists:mapfoldl(fun(Key, Acc) ->
                                                 code_frame(maps:get(Key, Groups), Acc)
                                         end, Read, lists:reverse(Order)),
            case lists:member(none, Frames) of
                true -> none;
                false -> Frames
            end
    end.

%% Each definition's group, by its group's hash or its own, in the order of
%% Hashes, with the unit whose forms hold it; and Read, the forms of each
%% unit read.
grouped([], Keys, Groups, Read) ->
    {lists:reverse(Keys), Groups, Read};
grouped([Hash | Hashes], Keys, Groups, Read) ->
    case members(Hash, Read) of
        none ->
            none;
        {[#definition{group = Group} | _] = Members, Unit, Read1} ->
            Key = case Group of
                      none -> Hash;
                      {GroupHash, _} -> GroupHash
                  end,
            case Groups of
                #{Key := _} -> grouped(Hashes, Keys, Groups, Read1);
                _ -> grouped(Hashes, [Key | Keys], Groups#{Key => {Members, Unit}}, Read1)
            end
    end.

%% The groups Key's forms reference put before it, and Key, in Order, which
%% is reversed: a definition's dependencies cross before it.
first_needed(Key, _Groups, _ByHash, {_, Seen} = Acc) when is_map_key(Key, Seen) ->
    Acc;
first_needed(Key, Groups, ByHash, {Order, Seen}) ->
    {Members, _} = maps:get(Key, Groups),
    Needed = lists:usort([maps:get(Referenced, ByHash)
                          || {hash, Referenced} <- ern_canonical:references(forms(Members)),
                             is_map_key(Referenced, ByHash)]) -- [Key],
    {Order1, Seen1} = lists:foldl(fun(Dependency, Acc) ->
                                      first_needed(Dependency, Groups, ByHash, Acc)
                                  end, {Order, Seen#{Key => true}}, Needed),
    {[Key | Order1], Seen1}.

%% Report Appendix H, §8.7: a definition alone, or a group's members in
%% order, as a code frame carries it: the hashes, the bytes they are taken
%% of, the hashes its forms reference, and each member's name, its form
%% with the lines of its source, what prints a type in a cause as its
%% module writes it, and the foreign declarations it calls, as the node
%% holds them (§11.2), a form without its source where it holds none, and
%% no module's printing where it holds none; none where a foreign
%% declaration a member calls is held by no unit the code of Unit, which
%% holds the members, calls.
code_frame({Members, Unit}, Read) ->
    Forms = forms(Members),
    {Calls, Read1} = lists:mapfoldl(fun(Form, Acc) -> calls(Unit, Form, Acc) end, Read, Forms),
    {code_frame(Members, Forms, Calls), Read1}.

code_frame(Members, Forms, Calls) ->
    case lists:member(none, Calls) of
        true ->
            none;
        false ->
            Sources = [{case Name of
                            none -> ern_namespace:text_segments(QualifiedName);
                            _ -> Name
                        end,
                        case Sourced of
                            none -> Form;
                            _ -> Sourced
                        end,
                        case Printing of
                            none -> {[], []};
                            _ -> Printing
                        end,
                        Called}
                       || {#definition{qualified_name = QualifiedName, name = Name, form = Form,
                                       sourced = Sourced, printing = Printing}, Called}
                              <- lists:zip(Members, Calls)],
            {[Hash || #definition{hash = Hash} <- Members],
             ern_canonical:bytes(ern_canonical:hashed(Forms)), referenced(Forms),
             term_to_binary(Sources)}
    end.

%% Report §8.7: the foreign declarations a definition's form calls, in the
%% order of their names, each {QualifiedName, HostModule, HostFunction,
%% Printing} as a reach's are found (implementations/2); none where one of
%% them is found nowhere.
calls(Unit, Form, Read) ->
    case called_names(Form) of
        [] ->
            {[], Read};
        Names ->
            case implementations(Unit, Names, Read) of
                {{ok, Implemented}, Read1} ->
                    {[{Name, HostModule, HostFunction, Printing}
                      || {Name, HostModule, HostFunction, _, Printing} <- Implemented],
                     Read1};
                {none, Read1} ->
                    {none, Read1}
            end
    end.

%% The definition of Hash this node holds, alone or with the other members
%% of its group in their order, read from the forms of the latest unit that
%% holds it, with that unit; none where no unit's forms hold it.
members(Hash, Read) ->
    member_of(lists:reverse(ern_code:holders({hash, Hash})), Hash, Read).

member_of([], _Hash, _Read) ->
    none;
member_of([Unit | Units], Hash, Read) ->
    {Definitions, Read1} = case recorded(Unit, Read) of
                               {#recorded{definitions = Held}, Read2} -> {Held, Read2};
                               {none, Read2} -> {[], Read2}
                           end,
    case [Definition || #definition{hash = Defined} = Definition <- Definitions,
                        Defined =:= Hash] of
        [#definition{group = none} = Definition | _] ->
            {[Definition], Unit, Read1};
        [#definition{group = {GroupHash, _}} | _] ->
            Members = [Member || #definition{group = {Of, _}} = Member <- Definitions,
                                 Of =:= GroupHash],
            {lists:sort(fun(#definition{group = {_, A}}, #definition{group = {_, B}}) -> A =< B end,
                        Members),
             Unit, Read1};
        [] ->
            member_of(Units, Hash, Read1)
    end.

%% What a unit's compiled form records, as the code table holds it, read
%% once in a request: from Read, the units read so far, or from the table,
%% Read growing by it; none where the table holds none.
recorded(Unit, Read) ->
    case Read of
        #{Unit := Recorded} ->
            {Recorded, Read};
        #{} ->
            Recorded = case ern_code:forms(Unit) of
                           {ok, Held} -> Held;
                           none -> none
                       end,
            {Recorded, Read#{Unit => Recorded}}
    end.

%%
%% Shared
%%

forms(Members) ->
    [Form || #definition{form = Form} <- Members].

%% Report §8.7: the qualified names of the foreign declarations a form
%% calls, as text, each once, in order, as a code frame names them.
called_names(Form) ->
    lists:usort([ern_namespace:text_segments(QualifiedName)
                 || {foreign, QualifiedName, _} <- ern_compile:references([Form])]).

%% Report §8.7: the hashes forms reference, a binding's among them, as a
%% code frame names them.
referenced(Forms) ->
    lists:usort([case Reference of
                     {hash, Hash} -> Hash;
                     {binding, _, Hash} -> Hash
                 end || Reference <- ern_canonical:references(Forms)]).

is_identity({function, Hash}) -> is_hash(Hash);
is_identity({lambda, Hash, Position}) -> is_hash(Hash) andalso is_integer(Position)
                                             andalso Position > 0;
is_identity({foreign, Names}) -> is_name(Names);
is_identity(_) -> false.

%% A foreign function's scheme as a form writes it (Appendix H), of the
%% shape the back end reads; what is inside it the back end reads too, and
%% a reach it cannot compile is answered `Other`.
is_scheme({scheme, Quantified, {arrow, Params, _, _}, Requirement}) ->
    is_list(Quantified) andalso is_list(Params) andalso is_list(Requirement);
is_scheme(_) ->
    false.

is_hash(Hash) ->
    is_binary(Hash) andalso byte_size(Hash) =:= 32.

is_name(Name) ->
    is_list(Name) andalso Name =/= [] andalso lists:all(fun is_text/1, Name).

%% What prints a type in a cause as a module writes it: its namespace and
%% the prelude names its types shadow, as text.
is_printing({Namespace, Shadows}) ->
    is_list(Namespace) andalso lists:all(fun is_text/1, Namespace)
        andalso is_list(Shadows) andalso lists:all(fun is_text/1, Shadows);
is_printing(_) ->
    false.

is_text(Text) ->
    is_binary(Text) andalso ern_fs:is_utf8(Text).
