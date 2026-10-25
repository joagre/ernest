%% Report §12.6: a node's gateway, the one registered process that takes
%% every frame of the runtime's from every peer, from the node's start. A
%% frame is {ern_frame, From, Body}, From the process on the peer that sent
%% it, whose node is the frame's peer.
%%
%% Each frame that needs a process on the receiving node is handed to the
%% worker for the sender's node, which reads it by ern_peer:frame/2. The
%% worker hands a spawn or a compute of a function the node lacks on to the
%% node's exchange (ern_exchange), which it tells of the loss too, and a
%% message to an adapted address to the process it keeps for the address
%% (§6.5, ern_rt:kept/1). The exchange's four frames the gateway hands to
%% the exchange as they come, and records nothing of them.
%%
%% A call's two notes the gateway records itself, in the order they came,
%% and so it does a peer's word that it ends (§6.9). A compute's frame is
%% its call's first note, which the gateway records before its worker reads
%% the frame, so that the second note, which may come before the compute's
%% process starts, finds it.
%%
%% A utilization the gateway answers itself, or with the utilization the
%% program set (ern_rt:program_utilization/0), and it tells each connected
%% peer the same number every `utilization-interval` while the node lists
%% peers, holding a peer's telling as it comes
%% (ern_peer:hold_utilization/3). It says each change of a connection
%% (ern_carrier:said/1).
%%
%% The shape is docs/design/nodes.md's.
-module(ern_gateway).

-export([start/0, reloaded/0, departing/0, work/2, outcome/2]).

-include("ern_node.hrl").

%% Report §8.6: each receive that can wait, by its kind (docs/style.md).
-receives({answered_at_once, [start/0, asked/1]}).
-receives({own_process, [gateway/5, work/1]}).

-define(NAME, ern_gateway).

%% Report §6.5, §12.6: the process the worker for a peer keeps for an
%% adapted address the peer sends to (ern_rt:kept/1), the worker's monitor
%% of it, and how many messages it has been handed and has not applied.
-record(kept, {pid, monitor_ref, handed}).

%% Report §12.6: the state of the worker for a peer: the peer's node, the
%% gateway that hands it the peer's frames and losses, a #kept{} for each
%% adapted address the peer has sent to while messages to it wait, by the
%% address, each kept process's address by its pid, how many of the
%% gateway's messages it has taken, and whether it has run a loss, after
%% which it ends once it holds nothing (idled/1).
-record(worker, {node, gateway, kept = #{}, addresses = #{}, taken = 0, lost = false}).

%% The gateway registered and running, watching the node's connections to
%% every kind of node, before the node listens, measuring the node as its
%% configuration says at the start and telling its peers so; the exchange
%% it hands frames to running before it.
-spec start() -> ok.
start() ->
    ok = ern_exchange:start(),
    Self = self(),
    Gateway = spawn(fun() ->
                        true = register(?NAME, self()),
                        ok = ern_peer:tables(),
                        ok = net_kernel:monitor_nodes(true, [nodedown_reason, {node_type, all}]),
                        #configuration{utilization = Utilization} = ern_carrier:configuration(),
                        Self ! {self(), started},
                        gateway(#{}, #{}, measured(Utilization, run_queue), armed(none, false),
                                false)
                    end),
    receive {Gateway, started} -> ok end.

%% Report §12.5: a reload's measure of how busy the node is and the interval
%% of its tellings, which the gateway takes from the configuration the
%% reload listed: the measure holds from the next ask, and the interval
%% from the next telling, the first set now where the node lists peers and
%% none was. Where the gateway has not started, as a reload during the
%% node's initializers, it reads both from the configuration as it starts.
-spec reloaded() -> ok.
reloaded() ->
    asked(reloaded).

%% Report §8.7, §12.6: a node that ends tells its peers so (ern_carrier:depart/0)
%% once its gateway tells none of them how busy it is any more, so that a
%% telling that comes after a peer's word that it ends says the peer goes
%% on. Where the gateway has not started, there is none to stop.
-spec departing() -> ok.
departing() ->
    asked(departing).

%% The gateway asked Request and answered once it has done it, or at its
%% end; nothing where it has not started (ern_rt:gateway/0).
asked(Request) ->
    case ern_rt:gateway() of
        [] ->
            ok;
        [Gateway] ->
            MonitorRef = erlang:monitor(process, Gateway),
            Gateway ! {Request, self(), MonitorRef},
            receive
                {MonitorRef, Request} -> erlang:demonitor(MonitorRef, [flush]), ok;
                {'DOWN', MonitorRef, process, _, _} -> ok
            end
    end.

%% Workers holds a worker for each peer a frame or a loss has come from,
%% with how many of them it has been handed, until it holds nothing after a
%% loss (idled/1), Ended each peer that told this node it ends, until its
%% connection's end or its next telling, Measured the node's measure of how
%% busy it is, with what the measure keeps (measured/2), Deadline the
%% moment of the next telling, none while the node lists no peer or once it
%% ends (armed/2), and Departed whether it has ended (departing/0).
gateway(Workers, Ended, Measured, Deadline, Departed) ->
    receive
        {ern_frame, From, {call_waits, Callee, Reply}} when is_pid(From), node(From) =/= node(),
                                                           is_pid(Callee),
                                                           is_reference(Reply) ->
            noted(fun() -> ern_rt:note_call(Callee, From, Reply) end),
            gateway(Workers, Ended, Measured, Deadline, Departed);
        {ern_frame, From, {call_over, Reply}} when is_pid(From), node(From) =/= node(),
                                                    is_reference(Reply) ->
            noted(fun() -> ern_rt:drop_note(Reply) end),
            gateway(Workers, Ended, Measured, Deadline, Departed);
        %% report §12.6: a compute's frame is its call's first note, recorded
        %% here before the worker for its peer starts its process
        {ern_frame, From, {compute, Alias, _, _, _}} = Frame
          when is_pid(From), node(From) =/= node(), is_reference(Alias),
               node(Alias) =:= node(From) ->
            noted(fun() -> ern_rt:note_compute(From, Alias) end),
            gateway(hand(node(From), Frame, Workers), Ended, Measured, Deadline, Departed);
        %% report §12.6, §11.2: how busy the node is, answered through the
        %% asker's alias as a find is answered, `Unreachable` between two
        %% launches of `ern test` over a directory, in one host
        {ern_frame, From, {utilization, Alias}}
          when is_pid(From), node(From) =/= node(), is_reference(Alias),
               node(Alias) =:= node(From) ->
            {Answer, Measured1} = case ern_rt:is_launched() of
                                      true -> utilization(Measured);
                                      false -> {'Unreachable', Measured}
                                  end,
            Alias ! {Alias, Answer},
            gateway(Workers, Ended, Measured1, Deadline, Departed);
        %% report §8.7, Appendix E.27: a peer's telling of how busy it is
        %% and of its interval, held as it comes; a node that ends tells
        %% each peer so and then its connections close, telling none how
        %% busy it is after its word (departing/0), so that a peer that
        %% tells after it said it ends has not ended, and its word is
        %% dropped: the connection's end that comes later is said as a loss
        {ern_frame, From, {telling, Utilization, Interval}}
          when is_pid(From), node(From) =/= node(), is_float(Utilization), Utilization >= 0.0,
               is_integer(Interval), Interval >= 1 ->
            ok = ern_peer:hold_utilization(node(From), Utilization, Interval),
            gateway(Workers, maps:remove(node(From), Ended), Measured, Deadline, Departed);
        %% report §12.6: a peer that ends says so before its connection
        %% closes, so that its end is said as an end and not as a loss
        {ern_frame, From, node_ends} when is_pid(From), node(From) =/= node() ->
            gateway(Workers, Ended#{node(From) => true}, Measured, Deadline, Departed);
        {departing, From, MonitorRef} when is_pid(From), node(From) =:= node() ->
            From ! {MonitorRef, departing},
            gateway(Workers, Ended, Measured, none, true);
        {new_run, Pid, MonitorRef} when is_pid(Pid) ->
            Pid ! {MonitorRef, fresh},
            gateway(Workers, Ended, Measured, Deadline, Departed);
        {reloaded, From, MonitorRef} when is_pid(From), node(From) =:= node() ->
            #configuration{utilization = Utilization} = ern_carrier:configuration(),
            Measured1 = measured(Utilization, Measured),
            From ! {MonitorRef, reloaded},
            gateway(Workers, Ended, Measured1, armed(Deadline, Departed), Departed);
        %% report §8.7, Appendix E.27: every interval, each connected peer
        %% told how busy the node is, until the node ends; the host's timer
        %% takes a slice of a long interval at a time, and is set again
        %% until the moment comes, and one set before the node ended comes
        %% to nothing
        {deadline, Deadline} when not Departed ->
            case ern_rt:remaining(Deadline) of
                0 -> gateway(Workers, Ended, told(connected_peers(), Measured),
                             armed(none, Departed), Departed);
                _ -> gateway(Workers, Ended, Measured, sliced(Deadline), Departed)
            end;
        {deadline, _} ->
            gateway(Workers, Ended, Measured, Deadline, Departed);
        %% report §12.7: the exchange's four, handed on as they come
        {ern_frame, From, Body} = Frame
          when is_pid(From), node(From) =/= node(), is_tuple(Body), tuple_size(Body) > 0,
               element(1, Body) =:= reach_request orelse element(1, Body) =:= reach
               orelse element(1, Body) =:= lacks orelse element(1, Body) =:= code_frame ->
            ern_exchange:handed(Frame),
            gateway(Workers, Ended, Measured, Deadline, Departed);
        {ern_frame, From, _Body} = Frame when is_pid(From), node(From) =/= node() ->
            gateway(hand(node(From), Frame, Workers), Ended, Measured, Deadline, Departed);
        {nodedown, Node, _} = Event ->
            %% report §8.7: the worker reads the frames before the loss, a
            %% spawn's answer it is handing over among them, and then lets
            %% go of the spawns that waited on the peer before the gateway
            %% learned of the loss, by its place in the order of the node's
            %% moments (ern_peer:lost/2); it reads the frames that come
            %% after it too, the worker of the connection opened again
            Loss = {lost, erlang:unique_integer([monotonic])},
            noted(fun() -> ern_rt:drop_notes(Node) end),
            ok = ern_peer:drop_utilization(Node),
            said(case Ended of
                     #{Node := true} -> {ended, Node};
                     _ -> Event
                 end),
            gateway(hand(Node, Loss, Workers), maps:remove(Node, Ended), Measured, Deadline,
                    Departed);
        %% report §8.7: a worker that has run a loss and holds nothing ends
        %% where it has taken every message it was handed, and is the
        %% node's worker no longer; one handed more since asks again
        {idle, Node, Worker, Taken} when is_pid(Worker), node(Worker) =:= node() ->
            case Workers of
                #{Node := {Worker, Taken}} ->
                    Worker ! stop,
                    gateway(maps:remove(Node, Workers), Ended, Measured, Deadline, Departed);
                #{} ->
                    gateway(Workers, Ended, Measured, Deadline, Departed)
            end;
        %% report §8.7, Appendix E.27: a peer that connects is told at once,
        %% so that it holds this node's utilization before an interval has
        %% passed, but where the node ends
        {nodeup, Node, _} = Event ->
            said(Event),
            Told = told([Node || is_peer(Node), not Departed], Measured),
            gateway(Workers, Ended, Told, Deadline, Departed);
        _ ->
            ern_carrier:say_later("a frame that names no peer's process came to the gateway,"
                                  " and was dropped"),
            gateway(Workers, Ended, Measured, Deadline, Departed)
    end.

%% Report §8.7, Appendix E.27: the moment of the next telling, Deadline
%% where one is set, none once the node has ended, and else one
%% `utilization-interval` from now where the node lists peers, or none where
%% it lists none and tells no one.
armed(_Deadline, true) ->
    none;
armed(none, false) ->
    case ern_peer:peers() of
        [] ->
            none;
        _ ->
            #configuration{utilization_interval = Interval} = ern_carrier:configuration(),
            sliced(ern_rt:deadline(Interval))
    end;
armed(Deadline, false) ->
    Deadline.

%% The host's timer towards the telling's moment, a slice at a time
%% (ern_rt:remaining/1).
sliced(Deadline) ->
    _ = erlang:send_after(ern_rt:remaining(Deadline), self(), {deadline, Deadline}),
    Deadline.

%% Report §8.7, Appendix E.27: the peers listed whose connection stands,
%% which a telling goes to; a telling opens no connection.
connected_peers() ->
    [Node || Node <- nodes(connected), is_peer(Node)].

is_peer(Node) ->
    ern_peer:name(Node) =/= 'None'.

%% Report Appendix E.27: each of Nodes told how busy the node is, the number
%% an ask answers (utilization/1), with the interval of its tellings, by
%% which the peer ages it, over its connection and without opening one; and
%% what the measure keeps for the next reading; nothing read where there is
%% no one to tell.
told([], Measured) ->
    Measured;
told(Nodes, Measured) ->
    {Utilization, Measured1} = utilization(Measured),
    #configuration{utilization_interval = Interval} = ern_carrier:configuration(),
    Telling = {ern_frame, self(), {telling, Utilization, Interval}},
    lists:foreach(fun(Node) -> _ = erlang:send({?NAME, Node}, Telling, [noconnect]) end, Nodes),
    Measured1.

%% Report Appendix E.27: how busy the node is, as it tells and answers its
%% peers: the utilization its program set with `Peer.setUtilization`, which
%% keeps the measure as it was, and else its measure.
utilization(Measured) ->
    case ern_rt:program_utilization() of
        none -> measure(Measured);
        Set -> {Set, Measured}
    end.

%% Report §12.8: the node's measure of how busy it is, as its configuration
%% says, from the one it had: `run_queue`, which keeps nothing, or
%% `{schedulers, Last}`, the schedulers' time when the node last read it,
%% at an ask or a telling, or took the entry, for which the host keeps the
%% schedulers' time while
%% this process, which turned it on, lives, and until it turns it off. A
%% measure that stays keeps what it kept.
measured(schedulers, {schedulers, _} = Kept) ->
    Kept;
measured(schedulers, run_queue) ->
    _ = erlang:system_flag(scheduler_wall_time, true),
    {schedulers, wall_time()};
measured(run_queue, {schedulers, _}) ->
    _ = erlang:system_flag(scheduler_wall_time, false),
    run_queue;
measured(run_queue, run_queue) ->
    run_queue.

%% Report §12.8: how busy the node is by its measure, on one scale, 1.0
%% every scheduler busy, and what the measure keeps for the next reading.
%% The run queue is the
%% host's total_active_tasks, the processes running or ready to run, which
%% reads each queue's count without stopping the schedulers, where
%% `statistics(run_queue)` takes them all at one instant by holding every
%% queue, a wait the report's measure does not make (§12.8, "no window and
%% no wait"); this process, running as it reads, is left out, and the count
%% is over the schedulers online, the ones that run processes. The
%% schedulers' time is the fraction of it spent running processes since the
%% last reading, which never passes 1.0; two readings at one instant of the
%% host's clock, which counts far finer than an ask can come, would divide
%% by nothing, and are taken as no time busy.
measure(run_queue) ->
    {(erlang:statistics(total_active_tasks) - 1) / erlang:system_info(schedulers_online),
     run_queue};
measure({schedulers, {Active, Total}}) ->
    {NowActive, NowTotal} = Now = wall_time(),
    {(NowActive - Active) / max(NowTotal - Total, 1), {schedulers, Now}}.

%% The time the schedulers online have run processes, and run in all, since
%% the host began to keep it.
wall_time() ->
    Online = erlang:system_info(schedulers_online),
    lists:foldl(fun({Scheduler, Active, Total}, {AllActive, AllTotal}) when Scheduler =< Online ->
                        {AllActive + Active, AllTotal + Total};
                   (_, Acc) ->
                        Acc
                end, {0, 0}, erlang:statistics(scheduler_wall_time)).

%% Report §12.5: a change of a connection, said where it is one the node
%% says.
said(Event) ->
    case ern_carrier:said(Event) of
        none -> ok;
        Line -> ern_carrier:say_later(Line)
    end.

%% A call's notes are rows of a run's tables; between two runs of `ern test`
%% over a directory, in one host, there are none, and nothing waits.
noted(Write) ->
    try Write() catch error:badarg -> ok end.

%% Report §12.6: a frame or a loss of Node's handed to the node's worker,
%% one started where it has none, and counted, so that the worker ends only
%% once it has taken every message it was handed (idled/1).
hand(Node, Message, Workers) ->
    {Worker, Handed} = case Workers of
                           #{Node := Counted} -> Counted;
                           #{} -> {started(Node), 0}
                       end,
    Worker ! Message,
    Workers#{Node => {Worker, Handed + 1}}.

%% The worker for Node, started by this process, its gateway.
started(Node) ->
    Gateway = self(),
    spawn(fun() -> work(Node, Gateway) end).

%% Report §12.6: the worker for the peer of Node, which Gateway starts for
%% each peer a frame or a loss comes from, and its tests alone: the peer's
%% frames, read in the order they came, a spawn or a compute of a function
%% this node lacks handed to the exchange, which asks the peer for its
%% reach while the worker goes on with the next frame, and a message to an
%% adapted address handed to the process kept for the address (§6.5,
%% handed/4).
%%
%% At a loss, the frames before it read, the spawns that waited on the peer
%% before it are let go, and then the exchanges asked of it, the frames the
%% worker handed it having come before; each process kept goes on with what
%% it was handed, since nothing else ends at a loss, and the worker reads
%% the frames of the connection opened again after the loss, so that a
%% message sent after the loss is applied after one sent before it to the
%% same address (§6.4). Once it holds no kept process the worker asks the
%% gateway to end it (idled/1), and ends at the gateway's `stop`.
-spec work(node(), pid()) -> ok.
work(Node, Gateway) ->
    work(#worker{node = Node, gateway = Gateway}).

work(#worker{node = Node, taken = Taken} = State) ->
    receive
        {ern_frame, From, Body} ->
            work(idled(framed(From, Body, State#worker{taken = Taken + 1})));
        {applied, Pid} ->
            work(idled(applied(Pid, State)));
        %% report §6.5: a process kept that ended otherwise than told, with
        %% the run it was started in, is forgotten, and the next message to
        %% its address starts another
        {'DOWN', _, process, Pid, _} ->
            work(idled(forgotten(Pid, State)));
        {lost, Order} ->
            ern_peer:lost(Node, Order),
            ern_exchange:lost(Node),
            work(idled(State#worker{taken = Taken + 1, lost = true}));
        stop ->
            ok
    end.

%% A peer's frame read: a message to an adapted address handed to the
%% process kept for it, a spawn or a compute of a function this node lacks
%% to the exchange, and any other frame's outcome said and done.
framed(From, Body, #worker{node = Node, kept = Kept, addresses = Addresses} = State) ->
    Read = try ern_peer:frame(From, Body)
           catch _:_ -> unreadable
           end,
    case Read of
        {adapted, Address, Message} ->
            {Kept1, Addresses1} = handed(Address, Message, Kept, Addresses),
            State#worker{kept = Kept1, addresses = Addresses1};
        {exchange, Identity} ->
            ern_exchange:lacking(From, Body, Identity),
            State;
        _ ->
            outcome(Node, Read),
            State
    end.

%% Report §8.7: a worker that has run a loss and holds no kept process asks
%% the gateway to end it, with how many of its messages it has taken, since
%% the gateway alone knows whether it has handed it more.
idled(#worker{lost = true, kept = Kept, node = Node, gateway = Gateway, taken = Taken} = State)
  when map_size(Kept) =:= 0 ->
    Gateway ! {idle, Node, self(), Taken},
    State;
idled(State) ->
    State.

%% A process kept that ended otherwise than told forgotten with its
%% address.
forgotten(Pid, #worker{kept = Kept, addresses = Addresses} = State) ->
    {Address, Addresses1} = maps:take(Pid, Addresses),
    State#worker{kept = maps:remove(Address, Kept), addresses = Addresses1}.

%% Report §6.5, §12.6: a message to an adapted address handed to the process
%% kept for the address, after every message handed to it before, and
%% counted; where none is kept, to one started now, which the worker
%% monitors; and to none where no run is in progress, the message dropped
%% (ern_rt:kept/1).
handed(Address, Message, Kept, Addresses) ->
    case Kept of
        #{Address := #kept{pid = Pid, monitor_ref = MonitorRef, handed = Handed}} ->
            Pid ! {apply, Message},
            {Kept#{Address := #kept{pid = Pid, monitor_ref = MonitorRef, handed = Handed + 1}},
             Addresses};
        _ ->
            case ern_rt:kept(Address) of
                none ->
                    {Kept, Addresses};
                Pid ->
                    MonitorRef = erlang:monitor(process, Pid),
                    Pid ! {apply, Message},
                    {Kept#{Address => #kept{pid = Pid, monitor_ref = MonitorRef, handed = 1}},
                     Addresses#{Pid => Address}}
            end
    end.

%% Report §6.5, §12.6: a message the process kept for its address has
%% applied, counted off; once none handed is left to apply, the process is
%% told to stop and forgotten, so that it ends having applied every message it was handed,
%% and the next message to the address starts another.
applied(Pid, #worker{kept = Kept, addresses = Addresses} = State) ->
    #{Pid := Address} = Addresses,
    case Kept of
        #{Address := #kept{monitor_ref = MonitorRef, handed = 1}} ->
            erlang:demonitor(MonitorRef, [flush]),
            Pid ! stop,
            State#worker{kept = maps:remove(Address, Kept),
                         addresses = maps:remove(Pid, Addresses)};
        #{Address := #kept{pid = Pid, monitor_ref = MonitorRef, handed = Handed}} ->
            State#worker{kept = Kept#{Address := #kept{pid = Pid, monitor_ref = MonitorRef,
                                                       handed = Handed - 1}}}
    end.

%% Report §12.5, §12.6: what a frame's reading tells the node to say and do, here
%% and in the exchange: a spawn or a compute this node did not start, which
%% it says, naming what it lacked, the site in the caller's words; or a
%% frame it cannot read, a frame whose reading fails among them, which ends
%% the peer's connection, the node saying so.
-spec outcome(node(), ok | unreadable | {not_loaded, spawn | compute, binary(), iodata()}) ->
          ok.
outcome(_Node, ok) ->
    ok;
outcome(Node, {not_loaded, Kind, Site, Lacked}) ->
    ern_carrier:say_later([ern_carrier:named(Node), "'s ", atom_to_list(Kind), " at ",
                           ern_show:controls(Site, line), " was not loaded: ", Lacked]);
outcome(Node, unreadable) ->
    ern_carrier:say_later([ern_carrier:named(Node), " sent a frame this node cannot read, and"
                                                    " its connection was ended"]),
    _ = erlang:disconnect_node(Node),
    ok.
