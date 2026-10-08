%% Report §8.7, Appendix E.27: the module `Peer`'s shims, and the work its
%% frames give a node's gateway. A key holds a name and its message type's
%% text, which the compiler supplies; an offer is a row of the runtime's,
%% kept while its process lives; a find asks the key's peers in order
%% through their gateways; a spawn sends the function to the peer's gateway,
%% which starts the process through the peer's runtime and answers through
%% the spawner's gateway, which ends a process no one waits for any more. A
%% node's peers and keys are the carrier's to give (configure/2); a program
%% that is no node has none.
-module(ern_peer).

-export([configure/2, tables/0, key/1, key/2, offer/2, find/2, spawn/3, spawn/4,
         spawn_monitored/4, spawn_monitored/5, nodes/0, frame/2]).

%% Report §8.6: the shims that wait on no process, each a table or a
%% persistent term read, which the emitter does not count as foreign code.
-waits_on_nothing([offer/2, nodes/0]).

%% A spawn waiting for its answer, by its reference: the waiting process.
-define(SPAWNS, ern_spawns).

%%
%% What the carrier gives
%%

%% Report §8.7: the peers this node lists, each with its name on the
%% carrier, and their names in the configuration's order, which nodes/0
%% answers; and the keys, each with its peers' names in the order a find
%% asks them.
-spec configure([{binary(), node()}], #{binary() => [binary()]}) -> ok.
configure(Peers, Keys) ->
    persistent_term:put({?MODULE, names}, [Name || {Name, _} <- Peers]),
    persistent_term:put({?MODULE, nodes}, maps:from_list(Peers)),
    persistent_term:put({?MODULE, keys}, Keys).

%% The table of spawns waiting, owned by the process that calls this, the
%% gateway, which outlives every run of a node's program.
-spec tables() -> ok.
tables() ->
    ?SPAWNS = ets:new(?SPAWNS, [named_table, public, set]),
    ok.

%% A peer's name on the carrier, or none where no peer has the name.
node_of(Name) ->
    maps:get(Name, persistent_term:get({?MODULE, nodes}, #{}), none).

%%
%% The shims
%%

%% Report §8.7: a key, its name and its message type's text, which the
%% compiler supplies at the call; it starts nothing. key/1 is the
%% declaration's, which no call reaches.
-spec key(binary()) -> no_return().
key(_Name) ->
    erlang:error(key_without_text).

-spec key(binary(), binary()) -> {'Key', binary(), binary()}.
key(Name, Text) ->
    {'Key', Name, Text}.

%% Report §8.7: an offer under the key's name and its type's text, for as
%% long as its process lives, a process of this node; a key a living process
%% holds faults the caller.
-spec offer({'Key', binary(), binary()}, ern_rt:address()) -> 'Unit'.
offer({'Key', Name, Text}, Address) ->
    ern_rt:offer({Name, Text}, Address, Name).

%% Report §8.7: the first address offered under the key's name at its type's
%% text by a peer `keys` lists for it, asked in order, each given the time
%% left; a peer that cannot be reached, offers nothing under the name, or
%% offers it at another type is passed over, the last such failure answered
%% where no peer offers it, and `Timeout` where the time runs out.
-spec find({'Key', binary(), binary()}, integer()) -> {'Right', term()} | {'Left', atom()}.
find({'Key', Name, Text}, Ms) ->
    Deadline = erlang:monotonic_time(millisecond) + max(Ms, 0),
    Nodes = [node_of(Peer) || Peer <- maps:get(Name, persistent_term:get({?MODULE, keys}, #{}),
                                                [])],
    found(Nodes, Name, Text, Deadline, 'NotListed').

found([], _Name, _Text, _Deadline, Last) ->
    {'Left', Last};
%% report §8.7: a node's carrier runs once its bindings have their values,
%% and before that no connection opens
found(_Nodes, _Name, _Text, _Deadline, _Last) when node() =:= nonode@nohost ->
    {'Left', 'Unreachable'};
found([Node | Nodes], Name, Text, Deadline, _Last) ->
    case left(Deadline) of
        0 ->
            {'Left', 'Timeout'};
        Ms ->
            case asked(Node, Name, Text, Ms) of
                {found, Address} -> {'Right', Address};
                timeout -> {'Left', 'Timeout'};
                Failure -> found(Nodes, Name, Text, Deadline, Failure)
            end
    end.

left(Deadline) ->
    max(0, Deadline - erlang:monotonic_time(millisecond)).

%% A peer's answer to a find, through an alias that takes one answer and
%% drops a late one; `Unreachable` where its gateway cannot be reached.
asked(Node, Name, Text, Ms) ->
    Gateway = {ern_gateway, Node},
    Monitor = erlang:monitor(process, Gateway),
    Alias = erlang:alias([reply]),
    erlang:send(Gateway, {ern_frame, erlang:self(), {find, Name, Text, Alias}}),
    receive
        {Alias, Answer} ->
            erlang:demonitor(Monitor, [flush]),
            Answer;
        {'DOWN', Monitor, process, _, _} ->
            erlang:unalias(Alias),
            'Unreachable'
    after Ms ->
        erlang:unalias(Alias),
        erlang:demonitor(Monitor, [flush]),
        timeout
    end.

%% Report §8.7: a process started on the peer named, running the function,
%% its address answered, or a failure, within the time; spawn/3 and
%% spawn_monitored/4 are the declarations', which the compiler calls with
%% the spawn's site after them.
-spec spawn(binary(), fun(), integer()) -> no_return().
spawn(_Name, _Function, _Ms) ->
    erlang:error(spawn_without_site).

-spec spawn(binary(), fun(), integer(), binary()) -> {'Right', pid()} | {'Left', atom()}.
spawn(Name, Function, Ms, Site) ->
    spawned(Name, Function, none, Ms, Site).

-spec spawn_monitored(binary(), fun(), fun(), integer()) -> no_return().
spawn_monitored(_Name, _Function, _Wrap, _Ms) ->
    erlang:error(spawn_without_site).

-spec spawn_monitored(binary(), fun(), fun(), integer(), binary()) ->
          {'Right', pid()} | {'Left', atom()}.
spawn_monitored(Name, Function, Wrap, Ms, Site) ->
    spawned(Name, Function, Wrap, Ms, Site).

%% The spawn: its frame to the peer's gateway, whose answer comes through
%% this node's gateway to the waiting process while it waits; a monitored
%% spawn's process waits on the peer until its monitor is made, so that it
%% is monitored from its start, and a failed one leaves no monitor.
spawned(Name, Function, Wrap, Ms, Site) ->
    case node_of(Name) of
        none ->
            {'Left', 'NotListed'};
        _ when node() =:= nonode@nohost ->
            {'Left', 'Unreachable'};
        Node ->
            Deadline = erlang:monotonic_time(millisecond) + max(Ms, 0),
            Ref = make_ref(),
            true = ets:insert(?SPAWNS, {Ref, erlang:self()}),
            Gateway = {ern_gateway, Node},
            Monitor = erlang:monitor(process, Gateway),
            erlang:send(Gateway, {ern_frame, erlang:self(),
                                  {spawn, Ref, Function, Site, Wrap =/= none}}),
            Answer = spawn_answer(Ref, Monitor, Deadline),
            erlang:demonitor(Monitor, [flush]),
            started(Answer, Ref, Wrap)
    end.

spawn_answer(Ref, Monitor, Deadline) ->
    receive
        {Ref, Answer} ->
            Answer;
        {'DOWN', Monitor, process, _, _} ->
            given_up(Ref, 'Unreachable')
    after left(Deadline) ->
        given_up(Ref, 'Timeout')
    end.

%% The wait given up: where the gateway has taken the row, its answer is on
%% its way here and is taken; otherwise none will come, and a late one ends
%% the process it names.
given_up(Ref, Failure) ->
    case ets:take(?SPAWNS, Ref) of
        [_] -> {failed, Failure};
        [] -> receive {Ref, Answer} -> Answer end
    end.

started({spawned, Pid}, _Ref, none) ->
    {'Right', Pid};
started({spawned, Pid}, Ref, Wrap) ->
    ern_rt:monitor(Pid, Wrap),
    Pid ! {ern_go, Ref},
    {'Right', Pid};
started({failed, Failure}, _Ref, _Wrap) ->
    {'Left', Failure}.

%% Report §8.7: the peers this node lists, in the configuration's order.
-spec nodes() -> [binary()].
nodes() ->
    persistent_term:get({?MODULE, names}, []).

%%
%% The gateway's work
%%

%% Report §8.7: a frame a peer sent, read by the gateway's worker for that
%% peer: a find answered at once; a spawn started through this node's
%% runtime, or `NotLoaded`; a spawn's answer handed to the process that
%% waits for it, or, where none does, its process ended; a message to an
%% adapted address this node made, its function applied here. Any other
%% frame is one the gateway cannot read.
-spec frame(pid(), term()) -> ok | unreadable.
frame(_From, {find, Name, Text, Alias}) ->
    Alias ! {Alias, ern_rt:offered(Name, Text)},
    ok;
frame(From, {spawn, Ref, Function, Site, Monitored}) when is_function(Function, 0) ->
    Answer = case loaded(Function) of
                 true -> {spawned, ern_rt:spawn(held(Function, Ref, From, Monitored), Site)};
                 false -> {failed, 'NotLoaded'}
             end,
    erlang:send({ern_gateway, node(From)}, {ern_frame, erlang:self(), {answer, Ref, Answer}}),
    ok;
frame(_From, {answer, Ref, Answer}) ->
    case ets:take(?SPAWNS, Ref) of
        [{_, Waiting}] -> Waiting ! {Ref, Answer};
        [] -> ended(Answer)
    end,
    ok;
frame(_From, {via, Via, Message}) ->
    ern_rt:send(Via, Message),
    ok;
frame(_From, _Body) ->
    unreadable.

%% Report §8.7: a process the spawner no longer waits for is ended as its
%% answer arrives.
ended({spawned, Pid}) -> ern_rt:kill(Pid);
ended({failed, _}) -> ok.

%% Report §8.7: a function spawned on this node runs where this node has its
%% module, the version the function was compiled in, and every binding of
%% that module and of every module it depends on has its value here. One
%% build has one version of each of its modules; a module a shell typed is
%% the shell's own, and another shell's of the same name is another module.
loaded(Function) ->
    {module, Module} = erlang:fun_info(Function, module),
    {new_uniq, Version} = erlang:fun_info(Function, new_uniq),
    erlang:module_loaded(Module)
        andalso Module:module_info(md5) =:= Version
        andalso ern_rt:initialized(Module).

%% The function a spawned process runs: a monitored spawn's waits until the
%% spawner has made its monitor, and ends where the spawner ends first.
held(Function, _Ref, _Spawner, false) ->
    Function;
held(Function, Ref, Spawner, true) ->
    fun() ->
        Monitor = erlang:monitor(process, Spawner),
        receive
            {ern_go, Ref} ->
                erlang:demonitor(Monitor, [flush]),
                Function();
            {'DOWN', Monitor, process, _, _} ->
                ok
        end
    end.
