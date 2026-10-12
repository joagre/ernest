%% Report §8.7, Appendix E.27: the module `Peer`'s shims, and the work its
%% frames give a node's gateway. A service holds its name and its message
%% type's hash, which the compiler supplies; an offer is a row of the
%% runtime's, kept while its process lives; a find asks the service's peers
%% in order through their gateways, each comparing the hash; a spawn sends
%% the function's identity and captures to the peer's gateway, which finds
%% the function in the peer's code table and starts the process through the
%% peer's runtime, or answers `NotLoaded`, or, where the peer lacks the
%% function, hands the spawn to the peer's exchange (ern_exchange), and
%% answers through the spawner's gateway, which ends a process no one waits
%% for any more, a failed spawn ending the calls whose replies its function
%% held (not_started/2); a compute sends
%% them so too, its frame the call's first note, and its process answers
%% the function's value, or its fault, through the caller's alias, its call
%% the runtime's (ern_rt:compute/3); a utilisation asks the peer's gateway,
%% which answers it (ern_gateway). A node's peers and services are the
%% carrier's to give (configure/2); a program that is no node has none. A
%% wait has no upper bound: it is made against the moment its time ends,
%% in slices the host takes (ern_rt:remaining/1).
-module(ern_peer).

-export([configure/2, tables/0, name/1, service/1, service/2, offer/2, find/2, spawn/3, spawn/5,
         spawn_monitored/4, spawn_monitored/6, compute/3, compute/4, utilisation/2, peers/0,
         frame/2, failed/4, reach_lacked/2, lost/1]).

-export_type([identity/0]).

%% Report §8.6: the shims that wait on no process, each a table or a
%% persistent term read, which the emitter does not count as foreign code.
-waits_on_nothing([offer/2, peers/0]).

%% A spawn waiting for its answer, {{Node, Ref}, Waiting}, by the peer's
%% node and the spawn's reference: the waiting process. Ordered, so that a
%% peer's loss reads that peer's rows alone, and an answer is taken only
%% from the peer the spawn went to.
-define(SPAWNS, ern_spawns).

%% Report §8.7: the function a spawn frame or a compute frame names, as the
%% compiler writes it (ern_emitter's spawned/2): a declaration by its hash,
%% a foreign one by its qualified name as text, a lambda or a local fn by
%% its definition's hash, its position and its captures, and `restarting`
%% over one of these with its limit.
-type spawned() :: {function, binary()} | {foreign, [binary()]}
                 | {lambda, binary(), pos_integer(), [term()]}
                 | {restarting, term(), spawned()}.

%% Report §8.7: the identity of a function a spawn or a compute names, as
%% the exchange asks for its reach: a declaration's hash, a lambda's or a
%% local fn's definition's hash and its position, or a foreign function's
%% qualified name as text, which has no hash and crosses as its
%% declaration.
-type identity() :: {function, binary()} | {lambda, binary(), pos_integer()}
                  | {foreign, [binary()]}.

%% Report §8.7, §6.6: each value a function captured whose type carries a
%% reply, with the descriptor of its type (ern_descriptor), which the
%% compiler passes beside the function, so that a spawn that fails ends
%% each call whose reply the function held without looking through any
%% other value.
-type held_replies() :: [{term(), term()}].

%%
%% What the carrier gives
%%

%% Report §8.7: the peers this node lists, each with its name on the
%% carrier, and their names in the configuration's order, which peers/0
%% answers, and by their names on the carrier, which name/1 answers; and
%% the services, each with its peers' names in the order a find asks them.
-spec configure([{binary(), node()}], #{binary() => [binary()]}) -> ok.
configure(Peers, Services) ->
    persistent_term:put({?MODULE, names}, [Name || {Name, _} <- Peers]),
    persistent_term:put({?MODULE, nodes}, maps:from_list(Peers)),
    persistent_term:put({?MODULE, named}, maps:from_list([{Node, Name} || {Name, Node} <- Peers])),
    persistent_term:put({?MODULE, services}, Services).

%% The table of spawns waiting, owned by the process that calls this, the
%% gateway, which outlives every run of a node's program.
-spec tables() -> ok.
tables() ->
    ?SPAWNS = ets:new(?SPAWNS, [named_table, public, ordered_set]),
    ok.

%% A peer's name on the carrier, or none where no peer has the name.
node_of(Name) ->
    maps:get(Name, persistent_term:get({?MODULE, nodes}, #{}), none).

%% Appendix E.21, report §8.7: the name the configuration lists the peer
%% of a node on the carrier under, a FaultReport's `spawnedBy`, or `None` for
%% none: no peer's spawn, or a peer a reload has removed since.
-spec name(node() | none) -> {'Some', binary()} | 'None'.
name(Node) ->
    case persistent_term:get({?MODULE, named}, #{}) of
        #{Node := Name} -> {'Some', Name};
        #{} -> 'None'
    end.

%%
%% The shims
%%

%% Report §8.7, Appendix H: a service, its name and its message type's
%% hash, which the compiler supplies at the call; it starts nothing.
%% service/1 is the declaration's, which no call reaches.
-spec service(binary()) -> no_return().
service(_Name) ->
    erlang:error(service_without_type).

-spec service(binary(), binary()) -> {'Service', binary(), binary()}.
service(Name, Hash) ->
    {'Service', Name, Hash}.

%% Report §8.7: an offer under the service's name and its type's hash, for
%% as long as its process lives, a process of this node: `Right(Unit)`
%% where it took the service, and `Left(Holder)` where a living process
%% holds it.
-spec offer({'Service', binary(), binary()}, ern_rt:address()) ->
          {'Right', 'Unit'} | {'Left', pid()}.
offer({'Service', Name, Hash}, Address) ->
    ern_rt:offer({Name, Hash}, Address).

%% Report §8.7: the first address offered under the service's name at its
%% type's hash by a peer `services` lists for it, asked in order, each given
%% the time left; a peer that cannot be reached, offers nothing under the
%% name, or offers it at a type of another hash is passed over, the last
%% such failure answered where no peer offers it, and `Timeout` where the
%% time runs out.
-spec find({'Service', binary(), binary()}, integer()) ->
          {'Right', term()} | {'Left', atom()}.
find({'Service', Name, Hash}, Ms) ->
    Deadline = ern_rt:deadline(Ms),
    Nodes = [node_of(Peer)
             || Peer <- maps:get(Name, persistent_term:get({?MODULE, services}, #{}), [])],
    found(Nodes, Name, Hash, Deadline, 'NotListed').

found([], _Name, _Hash, _Deadline, Last) ->
    {'Left', Last};
%% report §8.7: a node's carrier runs once its bindings have their values,
%% and before that no connection opens
found(_Nodes, _Name, _Hash, _Deadline, _Last) when node() =:= nonode@nohost ->
    {'Left', 'Unreachable'};
found([Node | Nodes], Name, Hash, Deadline, _Last) ->
    case ern_rt:remaining(Deadline) of
        0 ->
            {'Left', 'Timeout'};
        _ ->
            case asked(Node, Name, Hash, Deadline) of
                {found, Address} -> {'Right', Address};
                timeout -> {'Left', 'Timeout'};
                Error -> found(Nodes, Name, Hash, Deadline, Error)
            end
    end.

%% A peer's answer to a find or a utilisation, through an alias that takes
%% one answer and drops a late one; `Unreachable` where its gateway cannot
%% be reached. An answer that came before the alias went at the time's end
%% is taken, so that none is left in the caller's mailbox.
asked(Node, Name, Hash, Deadline) ->
    Gateway = {ern_gateway, Node},
    MonitorRef = erlang:monitor(process, Gateway),
    Alias = erlang:alias([reply]),
    erlang:send(Gateway, {ern_frame, erlang:self(), {find, Name, Hash, Alias}}),
    gateway_answer(Alias, MonitorRef, Deadline).

gateway_answer(Alias, MonitorRef, Deadline) ->
    receive
        {Alias, Answer} ->
            erlang:demonitor(MonitorRef, [flush]),
            Answer;
        {'DOWN', MonitorRef, process, _, _} ->
            erlang:unalias(Alias),
            'Unreachable'
    after ern_rt:remaining(Deadline) ->
        case ern_rt:remaining(Deadline) of
            0 ->
                erlang:unalias(Alias),
                erlang:demonitor(MonitorRef, [flush]),
                receive {Alias, Answer} -> Answer after 0 -> timeout end;
            _ ->
                gateway_answer(Alias, MonitorRef, Deadline)
        end
    end.

%% Report §8.7: a process started on the peer named, running the function
%% the frame names, its address answered, or a failure, within the time;
%% spawn/3 and spawn_monitored/4 are the declarations', which the compiler
%% calls with the function's identity and captures in place of the
%% function (ern_emitter's spawned/2), the spawn's site after them, and
%% last the captures that carry a reply.
-spec spawn(binary(), fun(), integer()) -> no_return().
spawn(_Name, _Function, _Ms) ->
    erlang:error(spawn_without_site).

-spec spawn(binary(), spawned(), integer(), binary(), held_replies()) ->
          {'Right', pid()} | {'Left', term()}.
spawn(Name, Spawned, Ms, Site, Replies) ->
    not_started(spawned(Name, Spawned, none, Ms, Site), Replies).

-spec spawn_monitored(binary(), fun(), fun(), integer()) -> no_return().
spawn_monitored(_Name, _Function, _Wrap, _Ms) ->
    erlang:error(spawn_without_site).

-spec spawn_monitored(binary(), spawned(), fun(), integer(), binary(), held_replies()) ->
          {'Right', pid()} | {'Left', term()}.
spawn_monitored(Name, Spawned, Wrap, Ms, Site, Replies) ->
    not_started(spawned(Name, Spawned, Wrap, Ms, Site), Replies).

%% The spawn: its frame to the peer's gateway, whose answer comes through
%% this node's gateway to the waiting process while it waits; a monitored
%% spawn's process waits on the peer until its monitor is made, so that it
%% is monitored from its start, and a failed one leaves no monitor.
spawned(Name, Spawned, Wrap, Ms, Site) ->
    case node_of(Name) of
        none ->
            {'Left', 'NotListed'};
        _ when node() =:= nonode@nohost ->
            {'Left', 'Unreachable'};
        Node ->
            Deadline = ern_rt:deadline(Ms),
            Ref = make_ref(),
            true = ets:insert(?SPAWNS, {{Node, Ref}, erlang:self()}),
            Gateway = {ern_gateway, Node},
            MonitorRef = erlang:monitor(process, Gateway),
            erlang:send(Gateway, {ern_frame, erlang:self(),
                                  {spawn, Ref, Spawned, Site, Wrap =/= none}}),
            Answer = spawn_answer({Node, Ref}, MonitorRef, Deadline),
            erlang:demonitor(MonitorRef, [flush]),
            started(Answer, Ref, Wrap)
    end.

%% Report §8.7, §6.6: a spawn that failed, whatever its failure, its time
%% run out after the frame went among them, ends every call whose reply its
%% function held, as the callee's death ends it, since no process will
%% answer it here; each reply is found in the captures that carry one, by
%% their types' descriptors. A reply foreign code gave is its caller's to
%% wait on, which waits as foreign code waits.
not_started({'Left', _} = Failed, Replies) ->
    lists:foreach(fun ern_rt:not_started/1,
                  lists:append([replies(Descriptor, Value, #{})
                                || {Value, Descriptor} <- Replies])),
    Failed;
not_started(Started, _Replies) ->
    Started.

%% The replies a value of the type Descriptor describes holds, Bound
%% binding each mu's refs inside it.
replies({reply, _, _}, Reply, _) when is_reference(Reply) ->
    [Reply];
replies({list, Element}, Values, Bound) when is_list(Values) ->
    lists:append([replies(Element, Value, Bound) || Value <- Values]);
replies({tuple, Elements}, Value, Bound) when is_tuple(Value) ->
    lists:append([replies(Element, Item, Bound)
                  || {Element, Item} <- lists:zip(Elements, tuple_to_list(Value))]);
replies({map, _, Element}, Value, Bound) when is_map(Value) ->
    lists:append([replies(Element, Item, Bound) || Item <- maps:values(Value)]);
replies({con, Constructors}, Value, Bound) when is_tuple(Value) ->
    [Tag | Fields] = tuple_to_list(Value),
    case [Elements || Constructor <- Constructors, element(1, Constructor) =:= Tag,
                      Elements <- [element(2, Constructor)]] of
        [Elements] -> lists:append([replies(Element, Item, Bound)
                                    || {Element, Item} <- lists:zip(Elements, Fields)]);
        _ -> []
    end;
replies({abstract, Descriptor}, Value, Bound) ->
    replies(Descriptor, Value, Bound);
replies({mu, Id, Descriptor}, Value, Bound) ->
    replies(Descriptor, Value, Bound#{Id => Descriptor});
replies({ref, Id}, Value, Bound) ->
    replies(maps:get(Id, Bound), Value, Bound);
replies(_, _, _) ->
    [].

spawn_answer({_, Ref} = Key, MonitorRef, Deadline) ->
    receive
        {Ref, Answer} ->
            Answer;
        {'DOWN', MonitorRef, process, _, _} ->
            given_up(Key, 'Unreachable')
    after ern_rt:remaining(Deadline) ->
        case ern_rt:remaining(Deadline) of
            0 -> given_up(Key, 'Timeout');
            _ -> spawn_answer(Key, MonitorRef, Deadline)
        end
    end.

%% The wait given up: where this node's gateway has taken the row, its
%% answer, or the loss's `Unreachable` (lost/1), is on its way here and is
%% taken; otherwise none will come, and a late one ends the process it
%% names.
given_up({_, Ref} = Key, Error) ->
    case ets:take(?SPAWNS, Key) of
        [_] -> {failed, Error};
        [] -> receive {Ref, Answer} -> Answer end
    end.

started({spawned, Pid}, _Ref, none) ->
    {'Right', Pid};
started({spawned, Pid}, Ref, Wrap) ->
    ern_rt:monitor(Pid, Wrap),
    Pid ! {ern_go, Ref},
    {'Right', Pid};
started({failed, Error}, _Ref, _Wrap) ->
    {'Left', Error}.

%% Report §8.7: a function run on the peer named, in a process started
%% there as a spawn starts one, its value answered within the time, or a
%% failure, and a fault in it the caller's; compute/3 is the declaration's,
%% which the compiler calls with the function's identity and captures in
%% place of the function (ern_emitter's spawned/2) and the compute's site
%% after them. The frame is the call's first note, and the wait a call's
%% (ern_rt:compute/3).
-spec compute(binary(), fun(), integer()) -> no_return().
compute(_Name, _Function, _Ms) ->
    erlang:error(compute_without_site).

-spec compute(binary(), spawned(), integer(), binary()) -> {'Right', term()} | {'Left', term()}.
compute(Name, Spawned, Ms, Site) ->
    case node_of(Name) of
        none ->
            {'Left', 'NotListed'};
        _ when node() =:= nonode@nohost ->
            {'Left', 'Unreachable'};
        Node ->
            ern_rt:compute(Node, fun(Alias) -> {compute, Alias, Spawned, Site} end,
                           ern_rt:deadline(Ms))
    end.

%% Report §8.7: how busy the peer named is, the Float its gateway answers
%% through an alias, as a find's is answered, within the time;
%% `Unreachable` where its gateway cannot be reached.
-spec utilisation(binary(), integer()) -> {'Right', float()} | {'Left', atom()}.
utilisation(Name, Ms) ->
    case node_of(Name) of
        none ->
            {'Left', 'NotListed'};
        _ when node() =:= nonode@nohost ->
            {'Left', 'Unreachable'};
        Node ->
            Deadline = ern_rt:deadline(Ms),
            Gateway = {ern_gateway, Node},
            MonitorRef = erlang:monitor(process, Gateway),
            Alias = erlang:alias([reply]),
            erlang:send(Gateway, {ern_frame, erlang:self(), {utilisation, Alias}}),
            case gateway_answer(Alias, MonitorRef, Deadline) of
                Utilisation when is_float(Utilisation) -> {'Right', Utilisation};
                timeout -> {'Left', 'Timeout'};
                Error -> {'Left', Error}
            end
    end.

%% Report §8.7: the peers this node lists, in the configuration's order.
-spec peers() -> [binary()].
peers() ->
    persistent_term:get({?MODULE, names}, []).

%%
%% The gateway's work
%%

%% Report §8.7: a frame a peer sent, read by the gateway's worker for that
%% peer, each field of it checked: a find answered at once; a spawn started
%% through this node's runtime, or `NotLoaded`, with what this node lacked,
%% which the gateway says; a compute so too, its process answering its
%% caller, the gateway having noted it as it came (ern_rt:note_compute/2);
%% a spawn or a compute of a function this node lacks, the identity the
%% exchange asks the peer for (ern_exchange), which answers it; a spawn's
%% answer handed to the process that waits for it, where it lives, or else
%% its process ended; a message to an adapted address this node made, its
%% function applied here. A find, a spawn or a compute is asked of the run
%% in progress, and one that comes while none is answers `Unreachable`:
%% between two runs of `ern test` over a directory, in one host, and as a
%% run ends (ern_rt:asked_of_run/1). Any other frame is one the gateway
%% cannot read; the gateway answers a utilisation itself, and hands the
%% exchange's four to the exchange.
-spec frame(pid(), term()) ->
          ok | unreadable | {not_loaded, spawn | compute, binary(), iodata()}
          | {exchange, identity()}.
frame(_From, {find, Name, Hash, Alias})
  when is_binary(Name), is_binary(Hash), is_reference(Alias) ->
    Answer = case ern_rt:asked_of_run({offered, Name, Hash}) of
                 {answered, Offered} -> Offered;
                 none -> 'Unreachable'
             end,
    Alias ! {Alias, Answer},
    ok;
%% report §8.7: a spawn's site is the spawner's words, read as UTF-8 here,
%% once, as the frame arrives: a site that is not is a frame no compiler
%% writes, which this node cannot read
frame(From, {spawn, Ref, Spawned, Site, Monitored})
  when is_reference(Ref), is_binary(Site), is_boolean(Monitored) ->
    case ern_fs:is_utf8(Site) andalso process_function(Spawned) of
        false ->
            unreadable;
        unreadable ->
            unreadable;
        {lacks, Identity} ->
            {exchange, Identity};
        Found ->
            {Answer, Read} = spawned_here(Found, Ref, From, Monitored, Site),
            erlang:send({ern_gateway, node(From)},
                        {ern_frame, erlang:self(), {answer, Ref, Answer}}),
            Read
    end;
%% report §8.7: a compute's site, read as a spawn's is
frame(From, {compute, Alias, Spawned, Site})
  when is_reference(Alias), node(Alias) =:= node(From), is_binary(Site) ->
    case ern_fs:is_utf8(Site) andalso process_function(Spawned) of
        false ->
            unreadable;
        unreadable ->
            unreadable;
        {lacks, Identity} ->
            {exchange, Identity};
        Found ->
            case computed_here(Found, Alias, From, Site) of
                {started, Read} ->
                    Read;
                {{failed, Error}, Read} ->
                    ern_rt:computed(Alias, Error),
                    Read
            end
    end;
frame(From, {answer, Ref, {spawned, Pid} = Answer})
  when is_reference(Ref), is_pid(Pid), node(Pid) =:= node(From) ->
    answered(From, Ref, Answer);
frame(From, {answer, Ref, {failed, Error} = Answer})
  when is_reference(Ref), Error =:= 'NotLoaded' orelse Error =:= 'Unreachable' ->
    answered(From, Ref, Answer);
%% report §8.7: a peer's reason, its words, read as UTF-8 as a site is
frame(From, {answer, Ref, {failed, {'Other', Text}} = Answer})
  when is_reference(Ref), is_binary(Text) ->
    case ern_fs:is_utf8(Text) of
        true -> answered(From, Ref, Answer);
        false -> unreadable
    end;
frame(_From, {adapted, {adapted, Function, _Target, Maker} = Address, Message})
  when is_function(Function, 1), is_pid(Maker), node(Maker) =:= node() ->
    ern_rt:send(Address, Message),
    ok;
frame(_From, _Body) ->
    unreadable.

%% A process a peer's spawn starts here, where this node holds the function
%% and every module its reach's foreign declarations call, and the run in
%% progress holds the value of every binding its reach names, each as the
%% code of the unit that runs it reads it (ern_code:called/1), its row
%% keeping the peer's node, which its fault's line names (§11.2); else
%% `NotLoaded` and what this node lacked, the first met, or `Unreachable`
%% where no run is in progress to start it.
spawned_here({found, Function, Unit, {Bindings, Foreigns}}, Ref, From, Monitored, Site) ->
    case absent_module(Unit, Foreigns) of
        none ->
            Held = held(Function, Ref, From, Monitored),
            case ern_rt:asked_of_run({spawn, Held, Unit, Bindings, Site, node(From)}) of
                {answered, Pid} when is_pid(Pid) -> {{spawned, Pid}, ok};
                {answered, {absent, Binding}} -> not_loaded(spawn, Site, absent(Binding));
                none -> {{failed, 'Unreachable'}, ok}
            end;
        Lacked ->
            not_loaded(spawn, Site, Lacked)
    end.

%% Report §8.7: a process a peer's compute starts here as a spawn's is
%% started, where this node would start it for a spawn, which runs the
%% function and answers the caller itself; else `NotLoaded` and what this
%% node lacked, or `Unreachable` where no run is in progress to start it,
%% or where the compute's note has gone before its process could start,
%% its caller no longer waiting, or never was written, the compute having
%% come between two runs (ern_rt:asked_of_run/1).
computed_here({found, Function, Unit, {Bindings, Foreigns}}, Alias, From, Site) ->
    case absent_module(Unit, Foreigns) of
        none ->
            Asked = {compute, Function, Unit, Bindings, Site, node(From), From, Alias},
            case ern_rt:asked_of_run(Asked) of
                {answered, Pid} when is_pid(Pid) -> {started, ok};
                {answered, over} -> {{failed, 'Unreachable'}, ok};
                {answered, {absent, Binding}} -> not_loaded(compute, Site, absent(Binding));
                none -> {{failed, 'Unreachable'}, ok}
            end;
        Lacked ->
            not_loaded(compute, Site, Lacked)
    end.

%% Report §8.7, §11.2: `NotLoaded`, and what the gateway says of the spawn
%% or the compute, the site the caller's words as they came, read as UTF-8
%% as the frame arrived (frame/2), and written as they are, as a fault's
%% line and the end's lines write a site.
not_loaded(Kind, Site, Lacked) ->
    {{failed, 'NotLoaded'}, {not_loaded, Kind, Site, Lacked}}.

%% Report §8.7: a spawn or a compute frame, read by frame/2 and handed to
%% the exchange, that this node starts no process for, answered with Error,
%% `NotLoaded` or `Other(text)`, as frame/2 answers one; and what the node
%% says of it, Lacked being what it lacked or why it did not start it.
-spec failed(pid(), tuple(), 'NotLoaded' | {'Other', binary()}, iodata()) ->
          {not_loaded, spawn | compute, binary(), iodata()}.
failed(From, {spawn, Ref, _Spawned, Site, _Monitored}, Error, Lacked) ->
    erlang:send({ern_gateway, node(From)},
                {ern_frame, erlang:self(), {answer, Ref, {failed, Error}}}),
    {not_loaded, spawn, Site, Lacked};
failed(_From, {compute, Alias, _Spawned, Site}, Error, Lacked) ->
    ern_rt:computed(Alias, Error),
    {not_loaded, compute, Site, Lacked}.

%% Report §8.7: what this node lacks of a reach a peer gave, before any of
%% its code crosses, or none: the first foreign declaration whose module is
%% not here, or whose function is not in it, each `{QualifiedName,
%% HostModule, HostFunction, Scheme, Printing}`, then the first binding
%% without its value here, each `{QualifiedName, Hash}`. The names are a
%% peer's text, which makes no atom here where none is, and is written with
%% its controls shown, as a foreign function's name a spawn gives is.
-spec reach_lacked([{[binary()], binary()}],
                   [{[binary()], binary(), binary(), term(), term()}]) -> iodata() | none.
reach_lacked(Bindings, Foreigns) ->
    case [Lacked || Foreign <- Foreigns, Lacked <- [foreign_lacked(Foreign)], Lacked =/= none] of
        [Lacked | _] ->
            Lacked;
        [] ->
            case [QualifiedName || {QualifiedName, Hash} <- Bindings,
                                   not has_value(QualifiedName, Hash)] of
                [] -> none;
                [QualifiedName | _] -> ["the binding ", named_text(QualifiedName),
                                        " has no value here"]
            end
    end.

%% Report §8.7: what this node lacks of a foreign declaration's
%% implementation, its module or the function in it at the declaration's
%% arity, or none; the module is loaded first where it is on the code
%% path, as the declaring module's call would load it, so that its name
%% and its functions' are atoms here once it answers none.
foreign_lacked({QualifiedName, HostModule, HostFunction, Scheme, _}) ->
    Module = ["the module ", ern_show:controls(HostModule, line), ", which ",
              named_text(QualifiedName), " calls, "],
    case is_present(HostModule) andalso code:ensure_loaded(binary_to_atom(HostModule)) of
        {module, Loaded} ->
            Arity = scheme_arity(Scheme),
            Exported = case existing_atoms([HostFunction]) of
                           [Function] -> erlang:function_exported(Loaded, Function, Arity);
                           none -> false
                       end,
            case Exported of
                true -> none;
                false -> [Module | no_function(HostFunction, Arity)]
            end;
        _ ->
            [Module, "is not here"]
    end.

no_function(HostFunction, Arity) ->
    ["has no function ", ern_show:controls(HostFunction, line), "/", integer_to_list(Arity),
     " here"].

%% The arity a foreign declaration's function is called with: its
%% parameters and its requirement's members (report §4.9).
scheme_arity({scheme, _, {arrow, Params, _, _}, Requirement}) ->
    length(Params) + length(Requirement).

named_text(QualifiedName) ->
    ern_show:controls(iolist_to_binary(lists:join(".", QualifiedName)), line).

%% Whether a module a peer names by its text is on this node, loaded or
%% where the host loads it from (ern_code:present/1); one whose name is no
%% atom here is not loaded, and is looked for on the code path by its file.
is_present(HostModule) ->
    case existing_atoms([HostModule]) of
        [Module] -> ern_code:present(Module);
        none -> code:where_is_file(unicode:characters_to_list(HostModule) ++ ".beam")
                    =/= non_existing
    end.

%% Whether a binding a peer names has its value here, in a unit that holds
%% it; one whose names are no atoms here is held nowhere.
has_value(QualifiedName, Hash) ->
    case existing_atoms(QualifiedName) of
        none -> false;
        Names -> ern_code:absent_binding([{Names, Hash}]) =:= none
    end.

%% Report §8.7: the function a spawn or a compute frame names, as this node
%% runs it: the unit the code table answers for its identity, one whose
%% bindings have their values where one holds it (§11.2), runs it over the
%% values it captured ('$spawned'/2), in the process, and `restarting` runs
%% it so; with that unit and the reach it names, or the identity this node
%% lacks, which the exchange asks for, a foreign function's its qualified
%% name as text, whose declaration crosses, or unreadable where the frame
%% names it in no way the compiler writes. A peer's names make no atom
%% here: the code table holds a foreign function by its name as text.
process_function({restarting, 'Unlimited' = Limit, Inner})
  when element(1, Inner) =/= restarting ->
    restarting(Limit, process_function(Inner));
process_function({restarting, {'RestartLimit', Restarts, Within} = Limit, Inner})
  when is_integer(Restarts), is_integer(Within), element(1, Inner) =/= restarting ->
    restarting(Limit, process_function(Inner));
process_function({function, Hash} = Identity) when is_binary(Hash), byte_size(Hash) =:= 32 ->
    unit_function(ern_code:spawnable({hash, Hash}), [], Identity);
process_function({lambda, Hash, Position, Captures})
  when is_binary(Hash), byte_size(Hash) =:= 32, is_integer(Position), Position > 0,
       is_list(Captures) ->
    unit_function(ern_code:spawnable({lambda, Hash, Position}), Captures,
                  {lambda, Hash, Position});
process_function({foreign, Names}) when is_list(Names), Names =/= [] ->
    case lists:all(fun(Name) -> is_binary(Name) andalso ern_fs:is_utf8(Name) end, Names) of
        false -> unreadable;
        true -> unit_function(ern_code:spawnable({foreign, Names}), [], {foreign, Names})
    end;
process_function(_) ->
    unreadable.

restarting(Limit, {found, Function, Unit, Reach}) ->
    {found, ern_rt:restarting(Limit, Function), Unit, Reach};
restarting(_, Other) ->
    Other.

%% The function a unit runs over the captures, where the unit's function
%% takes as many as came; a function of the identity that takes another
%% number is one no compiler writes a frame for.
unit_function({Unit, Function, Arity, Reach}, Captures, _) when length(Captures) =:= Arity ->
    {found, fun() -> Unit:'$spawned'(Function, Captures) end, Unit, Reach};
unit_function({_, _, _, _}, _, _) ->
    unreadable;
unit_function(none, _, Identity) ->
    {lacks, Identity}.

%% A qualified name as a line writes it, its segments atoms or a peer's text.
identity_text(QualifiedName) ->
    ern_show:controls(unicode:characters_to_binary(ern_namespace:text(QualifiedName)), line).

existing_atoms(Names) ->
    try [binary_to_existing_atom(Name) || Name <- Names]
    catch error:badarg -> none
    end.

%% Report §8.7: the first foreign declaration of a reach whose module is not
%% on this node, as what this node lacked, or none: each found in the units
%% the code of Unit, which runs the function, calls (ern_code:called/1).
absent_module(_Unit, []) ->
    none;
absent_module(Unit, QualifiedNames) ->
    Called = ern_code:called(Unit),
    case [Lacked || QualifiedName <- QualifiedNames,
                    Lacked <- [lacked_module(Called, QualifiedName)], Lacked =/= none] of
        [] -> none;
        [First | _] -> First
    end.

lacked_module(Called, QualifiedName) ->
    Named = identity_text(QualifiedName),
    case ern_code:foreign(Called, QualifiedName) of
        [] ->
            ["this node does not have ", Named];
        Implementations ->
            case [HostModule || {_, HostModule, _} <- Implementations,
                                not ern_code:present(HostModule)] of
                [] -> none;
                [HostModule | _] -> ["the module ", atom_to_binary(HostModule), ", which ", Named,
                                     " calls, is not here"]
            end
    end.

%% A binding of the reach without its value here, as what this node lacked.
absent({QualifiedName, _}) ->
    ["the binding ", identity_text(QualifiedName), " has no value here"].

%% A spawn's answer, taken only from the peer the spawn went to: handed to
%% the process that waits for it, where it lives; where it does not, or none
%% waits, the process it names is ended.
answered(From, Ref, Answer) ->
    case ets:take(?SPAWNS, {node(From), Ref}) of
        [{_, Waiting}] ->
            case erlang:is_process_alive(Waiting) of
                true -> Waiting ! {Ref, Answer};
                false -> ended(Answer)
            end;
        [] ->
            ended(Answer)
    end,
    ok.

%% Report §8.7: the spawns waiting on a peer whose connection is lost, once
%% the gateway's worker has read every frame that came before the loss:
%% each row goes, its waiter answered `Unreachable`, as its own watch on the
%% peer's gateway answers it, so that no row outlives a waiter that died.
%% A row its waiter took first is its own.
-spec lost(node()) -> ok.
lost(Node) ->
    lists:foreach(fun({{_, Ref} = Key, Waiting}) ->
                      case ets:take(?SPAWNS, Key) of
                          [_] -> Waiting ! {Ref, {failed, 'Unreachable'}};
                          [] -> ok
                      end
                  end, ets:select(?SPAWNS, [{{{Node, '_'}, '_'}, [], ['$_']}])).

%% Report §8.7: a process the spawner no longer waits for is ended as its
%% answer arrives.
ended({spawned, Pid}) -> ern_rt:kill(Pid);
ended({failed, _}) -> ok.

%% The function a spawned process runs: a monitored spawn's waits until the
%% spawner has made its monitor, and ends where the spawner ends first.
held(Function, _Ref, _Spawner, false) ->
    Function;
held(Function, Ref, Spawner, true) ->
    fun() ->
        MonitorRef = erlang:monitor(process, Spawner),
        receive
            {ern_go, Ref} ->
                erlang:demonitor(MonitorRef, [flush]),
                Function();
            {'DOWN', MonitorRef, process, _, _} ->
                ok
        end
    end.
