%% Report §8.7, Appendix E.27: the module `Peer`'s shims, and the work its
%% frames give a node's gateway. A key holds a name and its message type's
%% text, which the compiler supplies; an offer is a row of the runtime's,
%% kept while its process lives; a find asks the key's peers in order
%% through their gateways; a spawn sends the function to the peer's gateway,
%% which starts the process through the peer's runtime and answers through
%% the spawner's gateway, which ends a process no one waits for any more. A
%% node's peers and keys are the carrier's to give (configure/2); a program
%% that is no node has none. A wait has no upper bound: it is made against
%% the moment its time ends, in slices the host takes (ern_rt:remaining/1).
-module(ern_peer).

-export([configure/2, tables/0, key/1, key/2, offer/2, find/2, spawn/3, spawn/4,
         spawn_monitored/4, spawn_monitored/5, peers/0, frame/2, lost/1]).

%% Report §8.6: the shims that wait on no process, each a table or a
%% persistent term read, which the emitter does not count as foreign code.
-waits_on_nothing([offer/2, peers/0]).

%% A spawn waiting for its answer, {{Node, Ref}, Waiting}, by the peer's
%% node and the spawn's reference: the waiting process. Ordered, so that a
%% peer's loss reads that peer's rows alone, and an answer is taken only
%% from the peer the spawn went to.
-define(SPAWNS, ern_spawns).

%%
%% What the carrier gives
%%

%% Report §8.7: the peers this node lists, each with its name on the
%% carrier, and their names in the configuration's order, which peers/0
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
    ?SPAWNS = ets:new(?SPAWNS, [named_table, public, ordered_set]),
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
    Deadline = ern_rt:deadline(Ms),
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
    case ern_rt:remaining(Deadline) of
        0 ->
            {'Left', 'Timeout'};
        _ ->
            case asked(Node, Name, Text, Deadline) of
                {found, Address} -> {'Right', Address};
                timeout -> {'Left', 'Timeout'};
                Failure -> found(Nodes, Name, Text, Deadline, Failure)
            end
    end.

%% A peer's answer to a find, through an alias that takes one answer and
%% drops a late one; `Unreachable` where its gateway cannot be reached.
asked(Node, Name, Text, Deadline) ->
    Gateway = {ern_gateway, Node},
    MonitorRef = erlang:monitor(process, Gateway),
    Alias = erlang:alias([reply]),
    erlang:send(Gateway, {ern_frame, erlang:self(), {find, Name, Text, Alias}}),
    find_answer(Alias, MonitorRef, Deadline).

find_answer(Alias, MonitorRef, Deadline) ->
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
                timeout;
            _ ->
                find_answer(Alias, MonitorRef, Deadline)
        end
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
            Deadline = ern_rt:deadline(Ms),
            Ref = make_ref(),
            true = ets:insert(?SPAWNS, {{Node, Ref}, erlang:self()}),
            Gateway = {ern_gateway, Node},
            MonitorRef = erlang:monitor(process, Gateway),
            erlang:send(Gateway, {ern_frame, erlang:self(),
                                  {spawn, Ref, Function, Site, Wrap =/= none}}),
            Answer = spawn_answer({Node, Ref}, MonitorRef, Deadline),
            erlang:demonitor(MonitorRef, [flush]),
            started(Answer, Ref, Wrap)
    end.

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
given_up({_, Ref} = Key, Failure) ->
    case ets:take(?SPAWNS, Key) of
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
-spec peers() -> [binary()].
peers() ->
    persistent_term:get({?MODULE, names}, []).

%%
%% The gateway's work
%%

%% Report §8.7: a frame a peer sent, read by the gateway's worker for that
%% peer, each field of it checked: a find answered at once; a spawn started
%% through this node's runtime, or `NotLoaded`; a spawn's answer handed to
%% the process that waits for it, where it lives, or else its process
%% ended; a message to an adapted address this node made, its function
%% applied here. A find or a spawn is asked of the run in progress, and one
%% that comes while none is answers `Unreachable`: between two runs of `ern
%% test` over a directory, in one host, and as a run ends
%% (ern_rt:asked_of_run/1). Any other frame is one the gateway cannot read.
-spec frame(pid(), term()) -> ok | unreadable.
frame(_From, {find, Name, Text, Alias})
  when is_binary(Name), is_binary(Text), is_reference(Alias) ->
    Answer = case ern_rt:asked_of_run({offered, Name, Text}) of
                 {answered, Offered} -> Offered;
                 none -> 'Unreachable'
             end,
    Alias ! {Alias, Answer},
    ok;
frame(From, {spawn, Ref, Function, Site, Monitored})
  when is_reference(Ref), is_function(Function, 0), is_binary(Site), is_boolean(Monitored) ->
    Answer = case loaded(Function) of
                 true -> started_here(held(Function, Ref, From, Monitored), Site);
                 false -> {failed, 'NotLoaded'};
                 none -> {failed, 'Unreachable'}
             end,
    erlang:send({ern_gateway, node(From)}, {ern_frame, erlang:self(), {answer, Ref, Answer}}),
    ok;
frame(From, {answer, Ref, {spawned, Pid} = Answer})
  when is_reference(Ref), is_pid(Pid), node(Pid) =:= node(From) ->
    answered(From, Ref, Answer);
frame(From, {answer, Ref, {failed, Failure} = Answer})
  when is_reference(Ref), Failure =:= 'NotLoaded' orelse Failure =:= 'Unreachable' ->
    answered(From, Ref, Answer);
frame(_From, {via, {via, Function, _Target, Maker} = Via, Message})
  when is_function(Function, 1), is_pid(Maker), node(Maker) =:= node() ->
    ern_rt:send(Via, Message),
    ok;
frame(_From, _Body) ->
    unreadable.

%% A process a peer's spawn starts here, or `Unreachable` where no run is in
%% progress to start it.
started_here(Function, Site) ->
    case ern_rt:asked_of_run({spawn, Function, Site}) of
        {answered, Pid} -> {spawned, Pid};
        none -> {failed, 'Unreachable'}
    end.

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

%% Report §8.7: a function spawned on this node runs where this node has its
%% module, which the frame names, and every binding of that module and of
%% every module it depends on has its value here, which the run in progress
%% answers, or none where no run is. The comparison of the module's digest
%% with the one the function was compiled in is the host's own loading
%% check, which no node that keeps §8.7 meets: connected nodes run one
%% build, so a module is one version on both. It guards against a peer that
%% breaks §8.7, as §8.4's checks guard against a faulty peer's message, and
%% keeps a module a shell typed its own (§11.2): another shell's of the
%% same name is another module, which this node does not have.
loaded(Function) ->
    {module, Module} = erlang:fun_info(Function, module),
    {new_uniq, Version} = erlang:fun_info(Function, new_uniq),
    case erlang:module_loaded(Module) andalso Module:module_info(md5) =:= Version of
        true ->
            case ern_rt:asked_of_run({initialized, Module}) of
                {answered, Initialized} -> Initialized;
                none -> none
            end;
        false ->
            false
    end.

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
