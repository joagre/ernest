%% Report §8.7: a node's gateway, the one registered process that takes
%% every frame of the runtime's from every peer, from the node's start, so
%% that the frame which opens a connection finds it; each frame is handed to
%% a worker for the sender's node, which ends with that node's connection.
%% Through it go what needs a process on the receiving node: a spawn and its
%% answer, a find, and a message to an adapted address, each read by
%% ern_peer:frame/2; a frame it cannot read is faulty, and the node ends
%% that peer's connection. A frame is {ern_frame, From, Body}, From the
%% process on the peer that sent it, whose node is the frame's peer; a
%% message to the gateway that names no process of another node names no
%% connection to end, and is dropped, which the node says.
-module(ern_gateway).

-export([start/0]).

-define(NAME, ern_gateway).

%% The gateway registered and running, before the node listens.
-spec start() -> ok.
start() ->
    Self = self(),
    Gateway = spawn(fun() ->
                        true = register(?NAME, self()),
                        ok = ern_peer:tables(),
                        ok = net_kernel:monitor_nodes(true, [{node_type, all}]),
                        Self ! {self(), started},
                        gateway(#{})
                    end),
    receive {Gateway, started} -> ok end.

%% Workers holds a worker for each peer a frame has come from, while its
%% connection lasts.
gateway(Workers) ->
    receive
        {ern_frame, From, _Body} = Frame when is_pid(From), node(From) =/= node() ->
            Node = node(From),
            {Worker, Workers1} = worker(Node, Workers),
            Worker ! Frame,
            gateway(Workers1);
        {nodedown, Node, _} ->
            case Workers of
                #{Node := Worker} -> exit(Worker, kill);
                _ -> ok
            end,
            gateway(maps:remove(Node, Workers));
        {nodeup, _, _} ->
            gateway(Workers);
        _ ->
            ern_carrier:say("a frame that names no peer's process came to the gateway, and was"
                            " dropped"),
            gateway(Workers)
    end.

worker(Node, Workers) ->
    case Workers of
        #{Node := Worker} -> {Worker, Workers};
        _ ->
            Worker = spawn(fun() -> work(Node) end),
            {Worker, Workers#{Node => Worker}}
    end.

%% Report §8.7: a peer's frames, read in the order they came; one it cannot
%% read ends the peer's connection, and the node says so.
work(Node) ->
    receive
        {ern_frame, From, Body} ->
            case ern_peer:frame(From, Body) of
                ok ->
                    ok;
                unreadable ->
                    ern_carrier:say([ern_carrier:named(Node), " sent a frame this node cannot"
                                     " read, and its connection was ended"]),
                    _ = erlang:disconnect_node(Node)
            end,
            work(Node)
    end.
