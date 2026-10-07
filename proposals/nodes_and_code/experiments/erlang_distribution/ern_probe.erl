%% An experiment: what Erlang's distribution gives a node protocol that rides
%% on it. run/0 starts four nodes on this machine and prints what it finds.
%% README.md says what each step tries.
-module(ern_probe).

-export([run/0, start/0, events/0, ping/1, worker/0]).

%% The origin: starts nodes a, b, c and later d, and drives them over their standard
%% input, so that it is no node of the distribution itself.
-spec run() -> ok.
run() ->
    Dir = filename:absname("."),
    {A, _} = start_node(a, Dir, []),
    {B, NodeB} = start_node(b, Dir, []),
    {C, NodeC} = start_node(c, Dir, []),
    BPid = peer:call(B, os, getpid, []),
    try
        connecting(A, B, C, NodeB, NodeC),
        same_key(A, B, NodeB, Dir),
        say("5  monitor, kill, fault, reply, on a towards b",
            on(A, fun() -> monitors(NodeB) end)),
        Holder = on(A, fun() -> hold(NodeB) end),
        silent_peer(A, B, BPid, Holder),
        refusing_sender(A, B, NodeB, BPid, Holder),
        ok = peer:stop(B),
        {B2, NodeB} = start_node(b, Dir, []),
        say("6  b started again; a pings b's new echo", peer:call(A, ?MODULE, ping, [NodeB])),
        say("6  a monitors the process of b's earlier start", ask(A, Holder, monitor_again)),
        say("6  a pings the process of b's earlier start", ask(A, Holder, ping)),
        one_side_dials(B2, NodeB, Dir),
        peer:stop(B2),
        say("8  b is down; a's sends: us for one, for 1000 more",
            on(A, fun() -> sends(NodeB) end)),
        say("8  e's address is silent: us for each of a's 3 sends",
            peer:call(A, erlang, apply, [fun() -> slow_sends('e@127.0.0.1') end, []], 90000)),
        say("8  ms until a's monitor on e gives up, and why",
            peer:call(A, erlang, apply, [fun() -> given_up('e@127.0.0.1') end, []], 60000))
    after
        os:cmd("kill -CONT " ++ BPid),
        [try peer:stop(Peer) catch _:_ -> ok end || Peer <- [A, C]]
    end,
    ok.

start_node(Name, Dir, Extra) -> start_node(Name, Dir, Extra, []).

start_node(Name, Dir, Extra, Env) ->
    Arguments = ["-proto_dist", "inet_tls",
                 "-ssl_dist_optfile", filename:join(Dir, atom_to_list(Name) ++ ".conf"),
                 "-epmd_module", "ern_probe_epmd",
                 "-start_epmd", "false",
                 "-connect_all", "false",
                 "-kernel", "net_ticktime", "4",
                 "-setcookie", "ernest",
                 "+zdbbl", "1",
                 "-pa", Dir | Extra],
    {ok, Peer, Node} = peer:start_link(#{name => Name, host => "127.0.0.1", longnames => true,
                                         connection => standard_io, args => Arguments,
                                         env => Env}),
    ok = peer:call(Peer, ?MODULE, start, []),
    {Peer, Node}.

%% Steps 1 and 2: TLS with listed keys and no port mapper, and no mesh.
connecting(A, B, C, NodeB, NodeC) ->
    say("1  nodes at start (a, b, c)", {nodes_of(A), nodes_of(B), nodes_of(C)}),
    say("1  a pings b: TLS, listed keys, no port mapper", peer:call(A, ?MODULE, ping, [NodeB])),
    say("1  a's nodes after", nodes_of(A)),
    say("1  a connects to c, which does not list a",
        peer:call(A, net_kernel, connect_node, [NodeC])),
    say("2  b pings c", peer:call(B, ?MODULE, ping, [NodeC])),
    timer:sleep(1500),
    say("2  no mesh: nodes of a, b, c", {nodes_of(A), nodes_of(B), nodes_of(C)}).

%% Step 7: d does not listen, and b has no address for it. Only d can dial.
one_side_dials(B, NodeB, Dir) ->
    {D, NodeD} = start_node(d, Dir, ["-dist_listen", "false"]),
    try
        say("7  b connects to d, which it has no address for",
            peer:call(B, net_kernel, connect_node, [NodeD])),
        say("7  b monitors d's echo with no connection",
            on(B, fun() -> down(monitor(process, {echo, NodeD}), 3000) end)),
        say("7  d pings b", peer:call(D, ?MODULE, ping, [NodeB])),
        say("7  b's nodes, and all it is connected to", {nodes_of(B), connected_of(B)}),
        say("7  b pings d over the connection d opened", peer:call(B, ?MODULE, ping, [NodeD])),
        Holder = on(B, fun() -> hold(NodeD) end),
        say("7  b pings a process it spawned on d", ask(B, Holder, ping)),
        _ = peer:call(B, ?MODULE, events, []),
        _ = peer:call(D, ?MODULE, events, []),
        say("7  b disconnects d", peer:call(B, erlang, disconnect_node, [NodeD])),
        say("7  b's nodedown", wait_event(B, nodedown, 5000)),
        say("7  d's nodedown", wait_event(D, nodedown, 5000)),
        say("7  b's monitor of the process on d", ask(B, Holder, down)),
        say("7  after the loss b pings that process", ask(B, Holder, ping)),
        say("7  all b is connected to", connected_of(B)),
        say("7  d pings b again", peer:call(D, ?MODULE, ping, [NodeB])),
        say("7  b pings the same process on d", ask(B, Holder, ping))
    after
        peer:stop(D)
    end.

%% Step 8, on a: what a send costs its sender where no connection is open.
sends(Node) ->
    {First, _} = timer:tc(fun() -> {echo, Node} ! hello end),
    {More, _} = timer:tc(fun() -> [{echo, Node} ! hello || _ <- lists:seq(1, 1000)] end),
    {First, More}.

slow_sends(Node) ->
    [element(1, timer:tc(fun() -> {echo, Node} ! hello end)) || _ <- [1, 2, 3]].

given_up(Node) ->
    {Micros, Reason} = timer:tc(fun() -> down(monitor(process, {echo, Node}), 40000) end),
    {Micros div 1000, Reason}.

%% Step 9: a second node with a's key and a's name dials b, which is connected
%% to the first a. It does not listen, so that the two can share one machine.
same_key(A, B, NodeB, Dir) ->
    Holder = on(B, fun() -> hold('a@127.0.0.1') end),
    say("9  b pings a process on the first a", ask(B, Holder, ping)),
    _ = peer:call(A, ?MODULE, events, []),
    _ = peer:call(B, ?MODULE, events, []),
    {A2, _} = start_node(a, Dir, ["-dist_listen", "false"]),
    try
        say("9  a second a, with a's key and name, pings b", ping_from(A2, NodeB)),
        say("9  b's nodedown", wait_event(B, nodedown, 5000)),
        say("9  the first a's nodedown", wait_event(A, nodedown, 5000)),
        say("9  b's monitor of the process on the first a", ask(B, Holder, down)),
        say("9  b pings that process now", ask(B, Holder, ping)),
        say("9  the first a pings b again", ping_from(A, NodeB)),
        say("9  the second a pings b again", ping_from(A2, NodeB)),
        say("9  the first a pings b once more", ping_from(A, NodeB))
    after
        peer:stop(A2)
    end,
    say("9  the second a stopped; b's nodedown", wait_event(B, nodedown, 5000)),
    say("9  the first a pings b", ping_from(A, NodeB)),
    other_cookie(A, B, NodeB, Dir),
    parted(B, NodeB, Dir).

%% Step 10: a node with another cookie, standing for another build, dials b.
other_cookie(A, B, NodeB, Dir) ->
    _ = peer:call(B, ?MODULE, events, []),
    {A2, _} = start_node(a, Dir, ["-dist_listen", "false", "-setcookie", "other"]),
    try
        say("10 a node with another cookie connects to b",
            peer:call(A2, net_kernel, connect_node, [NodeB])),
        say("10 its send to b's echo", ping_from(A2, NodeB)),
        say("10 b's events meanwhile", peer:call(B, ?MODULE, events, [])),
        say("10 the first a still pings b", ping_from(A, NodeB))
    after
        peer:stop(A2)
    end.

%% Steps 11 and 12: f reaches b through a proxy, which then drops what passes,
%% both ways and then one way, as a parted network does.
parted(B, NodeB, Dir) ->
    {ok, Proxy} = ern_probe_proxy:start(47106, 47102),
    {F, _} = start_node(f, Dir, [], [{"ERN_PROBE_B_PORT", "47106"}]),
    try
        say("11 f pings b through the proxy", ping_from(F, NodeB)),
        _ = peer:call(B, ?MODULE, events, []),
        _ = peer:call(F, ?MODULE, events, []),
        ern_probe_proxy:cut(Proxy, both),
        say("11 the link drops both ways; f's nodedown, ms and reason", timed_event(F, nodedown)),
        say("11 b's nodedown, ms and reason", timed_event(B, nodedown)),
        ern_probe_proxy:heal(Proxy),
        say("11 the link is back; f pings b", ping_from(F, NodeB)),
        _ = peer:call(B, ?MODULE, events, []),
        _ = peer:call(F, ?MODULE, events, []),
        ern_probe_proxy:cut(Proxy, to_peer),
        say("12 the link drops f to b only; b's nodedown, ms and reason", timed_event(B, nodedown)),
        say("12 f's nodedown, ms and reason", timed_event(F, nodedown)),
        ern_probe_proxy:heal(Proxy),
        say("12 the link is back; f pings b", ping_from(F, NodeB))
    after
        peer:stop(F)
    end.

timed_event(Peer, Kind) ->
    Started = erlang:monotonic_time(millisecond),
    Event = wait_event(Peer, Kind, 15000),
    {erlang:monotonic_time(millisecond) - Started, Event}.

ping_from(Peer, Node) -> peer:call(Peer, ?MODULE, ping, [Node], 10000).

%% Step 4: b's operating system process is stopped, and continued.
silent_peer(A, B, BPid, Holder) ->
    _ = peer:call(A, ?MODULE, events, []),
    _ = peer:call(B, ?MODULE, events, []),
    Stopped = erlang:monotonic_time(millisecond),
    os:cmd("kill -STOP " ++ BPid),
    Down = wait_event(A, nodedown, 12000),
    say("4  b stopped; a's nodedown after ms, and its reason",
        {erlang:monotonic_time(millisecond) - Stopped, Down}),
    say("4  a's monitor of a process on b", ask(A, Holder, down)),
    say("3  a sends without connecting: [noconnect]", ask(A, Holder, noconnect)),
    os:cmd("kill -CONT " ++ BPid),
    Continued = erlang:monotonic_time(millisecond),
    DownB = wait_event(B, nodedown, 12000),
    say("4  b continued; b's nodedown after ms, and its reason",
        {erlang:monotonic_time(millisecond) - Continued, DownB}),
    say("4  the same pid after the loss: a pings the held process", ask(A, Holder, ping)),
    say("4  a's nodes after that ping", nodes_of(A)).

%% Step 3: a sender that does not wait, and a connection a node ends itself.
refusing_sender(A, B, NodeB, BPid, Holder) ->
    os:cmd("kill -STOP " ++ BPid),
    say("3  b stopped; a sends 64 kB values with [nosuspend]", ask(A, Holder, flood)),
    say("3  a disconnects b", peer:call(A, erlang, disconnect_node, [NodeB])),
    say("3  a's nodedown", wait_event(A, nodedown, 5000)),
    os:cmd("kill -CONT " ++ BPid),
    say("3  b continued; b's nodedown", wait_event(B, nodedown, 12000)).

say(What, Value) -> io:format("~-58s ~p~n", [What, Value]).

nodes_of(Peer) -> lists:sort(peer:call(Peer, erlang, nodes, [])).

%% A node that does not listen is hidden, and nodes/0 leaves it out.
connected_of(Peer) -> lists:sort(peer:call(Peer, erlang, nodes, [connected])).

on(Peer, Fun) -> peer:call(Peer, erlang, apply, [Fun, []]).

%% On each node: a log of nodeup and nodedown with the time, and an echo.
-spec start() -> ok.
start() ->
    Parent = self(),
    spawn(fun() ->
                  register(probe_log, self()),
                  ok = net_kernel:monitor_nodes(true, [nodedown_reason, {node_type, all}]),
                  Parent ! started,
                  logging([])
          end),
    receive started -> ok end,
    spawn(fun() -> register(echo, self()), echo() end),
    ok.

logging(Events) ->
    receive
        {events, From} ->
            From ! {events, lists:reverse(Events)},
            logging([]);
        Event ->
            logging([{erlang:monotonic_time(millisecond), Event} | Events])
    end.

%% What the node's log has taken since it was last asked.
-spec events() -> [{integer(), term()}] | timeout.
events() ->
    probe_log ! {events, self()},
    receive {events, Events} -> Events after 2000 -> timeout end.

echo() ->
    receive
        {ping, From} ->
            From ! pong,
            echo();
        {twice, Alias} ->
            Alias ! {Alias, 1},
            Alias ! {Alias, 2},
            echo()
    end.

%% A process another node spawns here, with the ends an Ernest process has.
-spec worker() -> no_return().
worker() ->
    receive
        {ping, From} ->
            From ! pong,
            worker();
        fault ->
            exit({ern, fault, <<"boom">>})
    end.

-spec ping(node()) -> pong | timeout.
ping(Node) ->
    {echo, Node} ! {ping, self()},
    receive pong -> pong after 5000 -> timeout end.

%% Step 5, on a: a kill and a fault seen through a monitor, and a reply that
%% takes one answer.
monitors(NodeB) ->
    Killed = spawn(NodeB, ?MODULE, worker, []),
    KilledRef = monitor(process, Killed),
    exit(Killed, {ern, killed}),
    Faulted = spawn(NodeB, ?MODULE, worker, []),
    FaultedRef = monitor(process, Faulted),
    Faulted ! fault,
    Alias = alias([reply]),
    {echo, NodeB} ! {twice, Alias},
    First = receive {Alias, Value1} -> Value1 after 3000 -> timeout end,
    Second = receive {Alias, Value2} -> Value2 after 700 -> none end,
    [{killed, down(KilledRef, 3000)}, {faulted, down(FaultedRef, 3000)},
     {first_answer, First}, {second_answer, Second}].

down(Ref, Timeout) ->
    receive {'DOWN', Ref, process, _, Reason} -> Reason after Timeout -> timeout end.

%% On a: a process that holds a pid of b's and a monitor on it, and does what
%% the origin asks of it.
hold(NodeB) ->
    spawn(fun() ->
                  Pid = spawn(NodeB, ?MODULE, worker, []),
                  holding(Pid, monitor(process, Pid))
          end).

holding(Pid, Ref) ->
    receive
        {down, From} ->
            From ! down(Ref, 6000),
            holding(Pid, Ref);
        {noconnect, From} ->
            From ! erlang:send(Pid, {ping, self()}, [noconnect]),
            holding(Pid, Ref);
        {ping, From} ->
            Pid ! {ping, self()},
            From ! (receive pong -> pong after 3000 -> timeout end),
            holding(Pid, Ref);
        {flood, From} ->
            From ! flood(Pid, binary:copy(<<0>>, 65536), 0),
            holding(Pid, Ref);
        {monitor_again, From} ->
            Again = monitor(process, Pid),
            From ! down(Again, 4000),
            holding(Pid, Again)
    end.

flood(_Pid, _Value, 20000) -> {never_refused, 20000};
flood(Pid, Value, Count) ->
    case erlang:send(Pid, Value, [nosuspend]) of
        ok -> flood(Pid, Value, Count + 1);
        nosuspend -> {refused_after_sends, Count}
    end.

%% Asks the holder on a peer, from the origin.
ask(Peer, Holder, What) ->
    Asking = fun() ->
                     Holder ! {What, self()},
                     receive Answer -> Answer after 15000 -> timeout end
             end,
    peer:call(Peer, erlang, apply, [Asking, []], 20000).

wait_event(Peer, Kind, Timeout) ->
    wait_event_until(Peer, Kind, erlang:monotonic_time(millisecond) + Timeout).

wait_event_until(Peer, Kind, Deadline) ->
    Events = peer:call(Peer, ?MODULE, events, []),
    case [Event || {_, Event} <- Events, element(1, Event) =:= Kind] of
        [Event | _] ->
            Event;
        [] ->
            case erlang:monotonic_time(millisecond) > Deadline of
                true ->
                    {none, Events};
                false ->
                    timer:sleep(200),
                    wait_event_until(Peer, Kind, Deadline)
            end
    end.
