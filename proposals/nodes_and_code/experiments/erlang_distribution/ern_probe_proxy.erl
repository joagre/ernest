%% A TCP proxy between a node and its peer's port, which can drop what passes
%% in one direction or both, as a parted network does. A close is dropped too
%% where its direction is cut, since no FIN crosses a parted network.
-module(ern_probe_proxy).

-export([start/2, cut/2, heal/1]).

-type direction() :: to_peer | from_peer | both.
-type proxy() :: {ets:table(), pid()}.

-spec start(inet:port_number(), inet:port_number()) -> {ok, proxy()}.
start(ListenPort, PeerPort) ->
    Table = ets:new(proxy, [public, set]),
    ets:insert(Table, {cut, none}),
    {ok, Listener} = gen_tcp:listen(ListenPort, [binary, {active, false}, {reuseaddr, true},
                                                 {ip, {127, 0, 0, 1}}]),
    Acceptor = spawn_link(fun() -> accepting(Listener, PeerPort, Table) end),
    {ok, {Table, Acceptor}}.

-spec cut(proxy(), direction()) -> ok.
cut({Table, _}, Direction) ->
    ets:insert(Table, {cut, Direction}),
    ok.

-spec heal(proxy()) -> ok.
heal({Table, _}) ->
    ets:insert(Table, {cut, none}),
    ok.

accepting(Listener, PeerPort, Table) ->
    {ok, Client} = gen_tcp:accept(Listener),
    {ok, Peer} = gen_tcp:connect({127, 0, 0, 1}, PeerPort, [binary, {active, false}]),
    ToPeer = spawn(fun() -> forwarding(Client, Peer, to_peer, Table) end),
    FromPeer = spawn(fun() -> forwarding(Peer, Client, from_peer, Table) end),
    ok = gen_tcp:controlling_process(Client, ToPeer),
    ok = gen_tcp:controlling_process(Peer, FromPeer),
    accepting(Listener, PeerPort, Table).

forwarding(From, To, Direction, Table) ->
    case gen_tcp:recv(From, 0) of
        {ok, Data} ->
            case is_cut(Direction, Table) of
                true -> ok;
                false -> ok = gen_tcp:send(To, Data)
            end,
            forwarding(From, To, Direction, Table);
        {error, _} ->
            case is_cut(Direction, Table) of
                true -> ok;
                false -> gen_tcp:close(To)
            end
    end.

is_cut(Direction, Table) ->
    case ets:lookup(Table, cut) of
        [{cut, Cut}] -> Cut =:= Direction orelse Cut =:= both;
        [] -> false
    end.
