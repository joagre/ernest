%% Report §8.7: a node's gateway, the one registered process that takes
%% every frame of the runtime's from every peer, from the node's start, so
%% that the frame which opens a connection finds it; each frame is handed to
%% a worker for the sender's node, which ends with that node's connection,
%% once it has read every frame that came before the loss. Through it go
%% what needs a process on the receiving node: a spawn and its answer, a
%% compute, a find, and a message to an adapted address, each read by
%% ern_peer:frame/2; a frame it cannot read is faulty, and the node ends
%% that peer's connection. A call's two notes it records itself, in the
%% order they came, so that a restart, which asks it as it asks the reaper,
%% reads every note that came before it (§6.9), and so it does a peer's
%% word that it ends; a compute's frame is its call's first note, which it
%% records before its worker reads the frame, so that the second note,
%% which may come before the compute's process starts, finds it. A
%% utilisation it answers itself, from the host's counters, keeping the
%% node's measure and its last reading, and turning on the host's keeping
%% of the schedulers' time, which lasts as long as the process that turns it
%% on, where the measure is the schedulers'. It watches the node's
%% connections and says each change of one (ern_carrier:said/1), since a
%% connection's end is said by the frames that came before it: a peer that
%% told this node it ends ended, and one that did not was lost. A frame is
%% {ern_frame, From, Body}, From the process on the peer that sent it, whose
%% node is the frame's peer; nine bodies are the runtime's frames, an
%% adapted address's message, a spawn and its answer, a compute, a find, a
%% utilisation, the call's two notes and a node's end. A message to the
%% gateway that names no process of another node names no connection to
%% end, and is dropped, which the node says.
-module(ern_gateway).

-export([start/0, measure/1]).

-include("ern_node.hrl").

-define(NAME, ern_gateway).

%% The gateway registered and running, watching the node's connections to
%% every kind of node, before the node listens, and measuring the node as
%% its configuration says at the start.
-spec start() -> ok.
start() ->
    Self = self(),
    Gateway = spawn(fun() ->
                        true = register(?NAME, self()),
                        ok = ern_peer:tables(),
                        ok = net_kernel:monitor_nodes(true, [nodedown_reason, {node_type, all}]),
                        #configuration{utilisation = Utilisation} = ern_carrier:configuration(),
                        Self ! {self(), started},
                        gateway(#{}, #{}, measured(Utilisation, run_queue))
                    end),
    receive {Gateway, started} -> ok end.

%% Report §8.7: a reload's measure of how busy the node is, which holds
%% from the next ask. Where the gateway has not started, as a reload during
%% the node's initializers, it reads the measure from the configuration as
%% it starts.
-spec measure(run_queue | schedulers) -> ok.
measure(Utilisation) ->
    case whereis(?NAME) of
        undefined ->
            ok;
        Gateway ->
            MonitorRef = erlang:monitor(process, Gateway),
            Gateway ! {measure, self(), MonitorRef, Utilisation},
            receive
                {MonitorRef, measured} -> erlang:demonitor(MonitorRef, [flush]), ok;
                {'DOWN', MonitorRef, process, _, _} -> ok
            end
    end.

%% Workers holds a worker for each peer a frame has come from, while its
%% connection lasts, Ended each peer that told this node it ends, until its
%% connection's end, and Measured the node's measure of how busy it is,
%% with what the measure keeps (measured/2).
gateway(Workers, Ended, Measured) ->
    receive
        {ern_frame, From, {call_waits, Callee, Reply}} when is_pid(From), node(From) =/= node(),
                                                           is_pid(Callee),
                                                           is_reference(Reply) ->
            noted(fun() -> ern_rt:note_call(Callee, From, Reply) end),
            gateway(Workers, Ended, Measured);
        {ern_frame, From, {call_over, Reply}} when is_pid(From), node(From) =/= node(),
                                                    is_reference(Reply) ->
            noted(fun() -> ern_rt:drop_note(Reply) end),
            gateway(Workers, Ended, Measured);
        %% report §8.7: a compute's frame is its call's first note, recorded
        %% here before the worker for its peer starts its process
        {ern_frame, From, {compute, Alias, _, _}} = Frame
          when is_pid(From), node(From) =/= node(), is_reference(Alias),
               node(Alias) =:= node(From) ->
            noted(fun() -> ern_rt:note_compute(From, Alias) end),
            {Worker, Workers1} = worker(node(From), Workers),
            Worker ! Frame,
            gateway(Workers1, Ended, Measured);
        %% report §8.7, §11.2: how busy the node is, answered through the
        %% asker's alias as a find is answered, `Unreachable` between two
        %% launches of `ern test` over a directory, in one host
        {ern_frame, From, {utilisation, Alias}}
          when is_pid(From), node(From) =/= node(), is_reference(Alias),
               node(Alias) =:= node(From) ->
            {Answer, Measured1} = case ern_rt:is_launched() of
                                      true -> utilisation(Measured);
                                      false -> {'Unreachable', Measured}
                                  end,
            Alias ! {Alias, Answer},
            gateway(Workers, Ended, Measured1);
        %% report §8.7: a peer that ends says so before its connection
        %% closes, so that its end is said as an end and not as a loss
        {ern_frame, From, node_ends} when is_pid(From), node(From) =/= node() ->
            gateway(Workers, Ended#{node(From) => true}, Measured);
        {new_run, Pid, MonitorRef} when is_pid(Pid) ->
            Pid ! {MonitorRef, fresh},
            gateway(Workers, Ended, Measured);
        {measure, From, MonitorRef, Utilisation} when is_pid(From), node(From) =:= node() ->
            Measured1 = measured(Utilisation, Measured),
            From ! {MonitorRef, measured},
            gateway(Workers, Ended, Measured1);
        {ern_frame, From, _Body} = Frame when is_pid(From), node(From) =/= node() ->
            Node = node(From),
            {Worker, Workers1} = worker(Node, Workers),
            Worker ! Frame,
            gateway(Workers1, Ended, Measured);
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
            gateway(maps:remove(Node, Workers), maps:remove(Node, Ended), Measured);
        {nodeup, _, _} = Event ->
            said(Event),
            gateway(Workers, Ended, Measured);
        _ ->
            ern_carrier:say("a frame that names no peer's process came to the gateway, and was"
                            " dropped"),
            gateway(Workers, Ended, Measured)
    end.

%% Report §8.7: the node's measure of how busy it is, as its configuration
%% says, from the one it had: `run_queue`, which keeps nothing, or
%% `{schedulers, Last}`, the schedulers' time when the node was last asked
%% or took the entry, for which the host keeps the schedulers' time while
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

%% Report §8.7: how busy the node is, on one scale, 1.0 every scheduler
%% busy, and what the measure keeps for the next ask. The run queue is the
%% host's total_active_tasks, the processes running or ready to run, which
%% reads each queue's count without stopping the schedulers, where
%% `statistics(run_queue)` takes them all at one instant by holding every
%% queue, a wait the report's measure does not make (§8.7, "no window and
%% no wait"); this process, running as it reads, is left out, and the count
%% is over the schedulers online, the ones that run processes. The
%% schedulers' time is the fraction of it spent running processes since the
%% last reading, which never passes 1.0; two readings at one instant of the
%% host's clock, which counts far finer than an ask can come, would divide
%% by nothing, and are taken as no time busy.
utilisation(run_queue) ->
    {(erlang:statistics(total_active_tasks) - 1) / erlang:system_info(schedulers_online),
     run_queue};
utilisation({schedulers, {Active, Total}}) ->
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
%% and the node says so, the worker going on to the loss; a spawn or a
%% compute this node lacked something for, it says, naming what. At the
%% loss, the spawns that wait on the peer are let go, and the worker ends.
work(Node) ->
    receive
        {ern_frame, From, Body} ->
            Read = try ern_peer:frame(From, Body)
                   catch _:_ -> unreadable
                   end,
            case Read of
                ok ->
                    ok;
                {not_loaded, Kind, Site, Lacked} ->
                    %% report §8.7: what this node lacked for a peer's spawn
                    %% or compute, the site in the caller's words
                    ern_carrier:say([ern_carrier:named(Node), "'s ", atom_to_list(Kind), " at ",
                                     Site, " was not loaded: ", Lacked]);
                unreadable ->
                    ern_carrier:say([ern_carrier:named(Node), " sent a frame this node cannot"
                                     " read, and its connection was ended"]),
                    _ = erlang:disconnect_node(Node)
            end,
            work(Node);
        stop ->
            ern_peer:lost(Node)
    end.
