%% Report §6.5, §8.7: a node's gateway's worker for a peer, as the gateway
%% starts it, the test standing in for the gateway, which hands the worker
%% each of the peer's frames and losses and answers its ask to end, and for
%% the peer, whose frames are messages to an adapted address this node
%% made: the process the worker keeps for each such address. Each runs in a
%% program, whose reaper the processes kept are linked to. Real nodes are
%% test/ern_nodes_tests.erl's. Regression tests, written after the code
%% (MVP 3.26's item 2b, and the worker across a loss before the tag).
-module(ern_gateway_tests).

-include_lib("eunit/include/eunit.hrl").

%% The peer whose frames the worker reads, a node no host holds.
-define(PEER, 'peer@nowhere.ernest').

%% report §6.5, §6.4, §8.7: a peer's messages to one adapted address are
%% applied in the order their frames came, in one process the worker keeps
%% for the address, which a message handed while another waits keeps, so
%% that a function that waits holds the messages after it; once none waits
%% the process ends, and the next message starts another
adapted_in_order_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Main = erlang:self(),
               Worker = spawn(fun() -> ern_gateway:work(?PEER, Main) end),
               Applying = fun({held, N}) ->
                                  Main ! {applying, erlang:self(), N},
                                  receive go -> {got, N} end;
                             (N) ->
                                  Main ! {applying, erlang:self(), N},
                                  {got, N}
                          end,
               Address = ern_rt:adapted(Main, Applying),
               %% the waits count as timed, so that they are no deadlock
               ern_rt:timed(),
               Worker ! frame(Address, {held, 1}),
               First = applying(1),
               MonitorRef = erlang:monitor(process, First),
               Worker ! frame(Address, 2),
               Worker ! frame(Address, 3),
               First ! go,
               Applied = [applying(N) || N <- [2, 3]],
               Got = [got() || _ <- [1, 2, 3]],
               Ended = ended(MonitorRef),
               Worker ! frame(Address, 4),
               Next = applying(4),
               4 = got(),
               ern_rt:untimed(),
               exit(Worker, kill),
               Self ! {kept, {First, Applied, Got, Ended, Next}}
           end, <<"main">>, quiet()),
    {First, Applied, Got, Ended, Next} = wait(kept),
    ?assertEqual({[First, First], [1, 2, 3], normal}, {Applied, Got, Ended}),
    ?assertNotEqual(First, Next).

%% report §6.5, §8.7, §11.2: a process the worker keeps that ends otherwise
%% than told, as each ends with the run it was started in, is forgotten,
%% and a message to its address in the next run, in one host, as `ern
%% test` runs a directory's tests, starts another, which applies it
adapted_forgotten_test() ->
    Self = self(),
    Worker = spawn(fun() -> ern_gateway:work(?PEER, Self) end),
    Applying = fun({held, Main}) ->
                       Main ! {applying, erlang:self(), held},
                       receive never -> held end;
                  ({applied, Main}) ->
                       Main ! {applying, erlang:self(), applied},
                       {got, erlang:self()}
               end,
    Address = ern_rt:adapted(Self, Applying),
    %% a run's entry point: a message handed, which names the run's entry
    %% process, and the process kept for it named; where the message is
    %% applied, the run waits for the process's end, which the worker asks
    %% for once it has applied, so that the run's end does not kill it
    Handed = fun(Kind) ->
                 fun() ->
                     ern_rt:timed(),
                     Worker ! frame(Address, {Kind, erlang:self()}),
                     Kept = applying(Kind),
                     case Kind of
                         held -> ok;
                         applied -> _ = ended(erlang:monitor(process, Kept))
                     end,
                     ern_rt:untimed(),
                     Self ! {kept, Kept}
                 end
             end,
    ok = ern_rt:run_main(Handed(held), <<"main">>, quiet()),
    First = wait(kept),
    _ = ended(erlang:monitor(process, First)),
    %% the worker has taken the process's end once it no longer monitors it
    ok = ern_waits:until(Worker, fun() -> not is_monitored(Worker, First) end),
    ok = ern_rt:run_main(Handed(applied), <<"main">>, quiet()),
    Second = wait(kept),
    exit(Worker, kill),
    ?assertNotEqual(First, Second),
    ?assertEqual(Second, got()).

%% report §6.5, §6.4, §8.7: a loss of the peer's connection while the
%% process the worker keeps for an address holds a message ends nothing:
%% the worker runs the loss and reads the frames that come after the
%% connection is opened again, handing the reconnected peer's message to
%% the same process, which applies it after the one it held, and ends once
%% none waits; the worker, holding nothing, asks the gateway to end it with
%% how many of its messages it has taken, and goes on where the gateway has
%% handed it more since, its next message to the address starting another
%% process, until it asks again and the gateway ends it. A regression test,
%% written after the code: at the loss the worker told each process it kept
%% to stop and ended, and the gateway handed the frames after the loss to
%% another worker, whose process for the address applied the later message
%% before the held one
adapted_across_a_loss_test() ->
    Self = self(),
    ok = ern_peer:tables(),
    try
        ok = ern_rt:run_main(
               fun() ->
                   Main = erlang:self(),
                   Worker = spawn(fun() -> ern_gateway:work(?PEER, Main) end),
                   WorkerRef = erlang:monitor(process, Worker),
                   Applying = fun({held, N}) ->
                                      Main ! {applying, erlang:self(), N},
                                      receive go -> {got, N} end;
                                 (N) ->
                                      Main ! {applying, erlang:self(), N},
                                      {got, N}
                              end,
                   Address = ern_rt:adapted(Main, Applying),
                   ern_rt:timed(),
                   Worker ! frame(Address, {held, 1}),
                   Kept = applying(1),
                   KeptRef = erlang:monitor(process, Kept),
                   Worker ! {lost, erlang:unique_integer([monotonic])},
                   Worker ! frame(Address, 2),
                   Kept ! go,
                   Again = applying(2),
                   Got = [got() || _ <- [1, 2]],
                   KeptEnded = ended(KeptRef),
                   Asked = idle(Worker),
                   %% handed more since it asked, it goes on
                   Worker ! frame(Address, 3),
                   Next = applying(3),
                   3 = got(),
                   AskedAgain = idle(Worker),
                   Worker ! stop,
                   WorkerEnded = ended(WorkerRef),
                   ern_rt:untimed(),
                   Self ! {lost, {Again =:= Kept, Next =/= Kept, Got, KeptEnded,
                                  [Asked, AskedAgain], WorkerEnded}}
               end, <<"main">>, quiet()),
        ?assertEqual({true, true, [1, 2], normal, [3, 4], normal}, wait(lost))
    after
        ets:delete(ern_spawns),
        ets:delete(ern_utilizations)
    end.

%% The worker's ask to end, with how many of the gateway's messages it has
%% taken.
idle(Worker) ->
    receive {idle, ?PEER, Worker, Taken} -> Taken end.

%% A peer's frame to an adapted address, as the gateway hands it to the
%% worker.
frame(Address, Message) ->
    {ern_frame, self(), {adapted, Address, Message}}.

%% The process kept for an address, as the function applied to Message
%% names it.
applying(Message) ->
    receive {applying, Pid, Message} -> Pid end.

%% What the function's message to its target carried.
got() ->
    receive {got, Got} -> Got end.

%% How a monitored process ended.
ended(MonitorRef) ->
    receive {'DOWN', MonitorRef, process, _, ExitReason} -> ExitReason end.

%% Whether Pid monitors Watched.
is_monitored(Pid, Watched) ->
    {monitors, Monitors} = erlang:process_info(Pid, monitors),
    lists:member({process, Watched}, Monitors).

wait(Tag) ->
    receive {Tag, Value} -> Value end.

quiet() ->
    #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end}.
