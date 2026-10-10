%% Report §8.7: a node's gateway, the one registered process that takes
%% every frame of the runtime's from every peer, from the node's start, so
%% that the frame which opens a connection finds it; each frame is handed to
%% a worker for the sender's node, which ends with that node's connection,
%% once it has read every frame that came before the loss. Through it go
%% what needs a process on the receiving node: a spawn and its answer, a
%% find, and a message to an adapted address, each read by
%% ern_peer:frame/2; a frame it cannot read is faulty, and the node ends
%% that peer's connection. A call's two notes it records itself, in the
%% order they came, so that a restart, which asks it as it asks the reaper,
%% reads every note that came before it (§6.9), and so it does a peer's
%% word that it ends. It watches the node's connections and says each
%% change of one (ern_carrier:said/1), since a connection's end is said by
%% the frames that came before it: a peer that told this node it ends
%% ended, and one that did not was lost. A frame is {ern_frame, From,
%% Body}, From the process on the peer that sent it, whose node is the
%% frame's peer; a message to the gateway that names no process of another
%% node names no connection to end, and is dropped, which the node says.
-module(ern_gateway).

-export([start/0]).

-define(NAME, ern_gateway).

%% The gateway registered and running, watching the node's connections to
%% every kind of node, before the node listens.
-spec start() -> ok.
start() ->
    Self = self(),
    Gateway = spawn(fun() ->
                        true = register(?NAME, self()),
                        ok = ern_peer:tables(),
                        ok = net_kernel:monitor_nodes(true, [nodedown_reason, {node_type, all}]),
                        Self ! {self(), started},
                        gateway(#{}, #{})
                    end),
    receive {Gateway, started} -> ok end.

%% Workers holds a worker for each peer a frame has come from, while its
%% connection lasts, and Ended each peer that told this node it ends, until
%% its connection's end.
gateway(Workers, Ended) ->
    receive
        {ern_frame, From, {call_waits, Callee, Reply}} when is_pid(From), node(From) =/= node(),
                                                           is_pid(Callee),
                                                           is_reference(Reply) ->
            noted(fun() -> ern_rt:note_call(Callee, From, Reply) end),
            gateway(Workers, Ended);
        {ern_frame, From, {call_over, Reply}} when is_pid(From), node(From) =/= node(),
                                                    is_reference(Reply) ->
            noted(fun() -> ern_rt:drop_note(Reply) end),
            gateway(Workers, Ended);
        %% report §8.7: a peer that ends says so before its connection
        %% closes, so that its end is said as an end and not as a loss
        {ern_frame, From, node_ends} when is_pid(From), node(From) =/= node() ->
            gateway(Workers, Ended#{node(From) => true});
        {new_run, Pid, MonitorRef} when is_pid(Pid) ->
            Pid ! {MonitorRef, fresh},
            gateway(Workers, Ended);
        {ern_frame, From, _Body} = Frame when is_pid(From), node(From) =/= node() ->
            Node = node(From),
            {Worker, Workers1} = worker(Node, Workers),
            Worker ! Frame,
            gateway(Workers1, Ended);
        {nodedown, Node, _} = Event ->
            %% report §8.7: the worker reads the frames before the loss, a
            %% spawn's answer it is handing over among them, and then lets
            %% go of the spawns waiting on the peer (ern_peer:lost/1)
            {Worker, _} = worker(Node, Workers),
            Worker ! stop,
            noted(fun() -> ern_rt:drop_notes(Node) end),
            said(case Ended of
                     #{Node := true} -> {ended, Node};
                     _ -> Event
                 end),
            gateway(maps:remove(Node, Workers), maps:remove(Node, Ended));
        {nodeup, _, _} = Event ->
            said(Event),
            gateway(Workers, Ended);
        _ ->
            ern_carrier:say("a frame that names no peer's process came to the gateway, and was"
                            " dropped"),
            gateway(Workers, Ended)
    end.

%% Report §8.7: a change of a connection, said where it is one the node
%% says.
said(Event) ->
    case ern_carrier:said(Event) of
        none -> ok;
        Line -> ern_carrier:say(Line)
    end.

%% A call's notes are rows of a run's tables; between two runs of `ern test`
%% over a directory, in one host, there are none, and nothing waits.
noted(Write) ->
    try Write() catch error:badarg -> ok end.

worker(Node, Workers) ->
    case Workers of
        #{Node := Worker} -> {Worker, Workers};
        _ ->
            Worker = spawn(fun() -> work(Node) end),
            {Worker, Workers#{Node => Worker}}
    end.

%% Report §8.7: a peer's frames, read in the order they came; one it cannot
%% read, a frame whose reading fails among them, ends the peer's connection,
%% and the node says so, the worker going on to the loss; a spawn this node
%% lacked something for, it says, naming what. At the loss, the spawns that
%% wait on the peer are let go, and the worker ends.
work(Node) ->
    receive
        {ern_frame, From, Body} ->
            Read = try ern_peer:frame(From, Body)
                   catch _:_ -> unreadable
                   end,
            case Read of
                ok ->
                    ok;
                {not_loaded, Site, Lacked} ->
                    %% report §8.7: what this node lacked for a peer's spawn,
                    %% the site in the spawner's words
                    ern_carrier:say([ern_carrier:named(Node), "'s spawn at ", Site,
                                     " was not loaded: ", Lacked]);
                unreadable ->
                    ern_carrier:say([ern_carrier:named(Node), " sent a frame this node cannot"
                                     " read, and its connection was ended"]),
                    _ = erlang:disconnect_node(Node)
            end,
            work(Node);
        stop ->
            ern_peer:lost(Node)
    end.
