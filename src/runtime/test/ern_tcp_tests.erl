%% Report Appendix E.18: the processes behind a listener and a socket.
-module(ern_tcp_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").

-export([at_the_file_limit/0, tls_connection_of/1, tls_taken/2, pki/0]).

%% Report Appendix E.18: the window in which a socket that has ended may
%% send what the far end has not taken with nothing taken, and the time
%% the host's ssl takes to close a connection, in two waits of 5 seconds
%% of its own.
-define(LINGER_IDLE, 5000).
-define(TLS_CLOSE, 10000).

%% Report Appendix E.18: the most one read answers over TCP, the host's
%% buffer for the socket; the most a TLS record holds; and what a read over
%% TLS answers fewer than, a record and a piece of TCP's.
-define(TCP_PIECE, 9216).
-define(TLS_RECORD, 16384).
-define(TLS_PIECE, 25600).

%% Report Appendix E.18: the milliseconds a write is given where a test
%% waits for its socket to be held. A write the host takes on the loopback
%% answers within a millisecond, so one not taken in a hundred waits on
%% full buffers, unless the host is too loaded to run the writer so long.
-define(HELD, 100).

%% Report Appendix E.18: the rounds of a close followed at once by a listen
%% on its port and a `port` of the listener, over TCP and over TLS, and of
%% an accept held by a listener that is killed or whose owner dies.
-define(CLOSE_ROUNDS, 2000).
-define(TLS_CLOSE_ROUNDS, 500).
-define(KILL_ROUNDS, 10).

%% Appendix E.18, E.0 shape rule 8: a read given no time, 0 or below, has
%% run out as it begins and answers `Left(Timeout)`, whatever has arrived,
%% and takes nothing: the far end's bytes go to the read with time after it,
%% and its close to the next, and once the connection has closed a read
%% given no time answers `Left(Timeout)` still. A regression test: before
%% the rule, a read given no time answered the bytes that had arrived
read_given_no_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Accepted} = gen_tcp:accept(Listen),
                       ok = gen_tcp:send(Accepted, <<"x">>),
                       receive close -> gen_tcp:close(Accepted) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               Before = [read(Socket, 0), read(Socket, -5)],
               Bytes = read(Socket, 5000),
               FarEnd ! close,
               Closed = read(Socket, 5000),
               Self ! {reads, {Before, Bytes, Closed, read(Socket, 0)}}
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout], {'Right', <<"x">>}, {'Left', 'Closed'}, Timeout},
                 ern_waits:wait(reads)).

%% Appendix E.18, E.0 shape rule 8: a write given no time, 0 or below, has
%% run out as it begins, answers `Left(Timeout)` and gives the host nothing:
%% the far end reads the one write that had time, and nothing before it. A
%% regression test: before the rule, the bytes went to the host and the
%% write answered whichever came first, its time or the host's taking them.
%% It does not cover a socket over TLS
write_given_no_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    _ = spawn(fun() ->
                  {ok, Accepted} = gen_tcp:accept(Listen),
                  Self ! {far_end, gen_tcp:recv(Accepted, 0, 5000)},
                  gen_tcp:close(Accepted)
              end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               Self ! {writes, [write(Socket, <<"x">>, 0), write(Socket, <<"y">>, -1),
                                write(Socket, <<"z">>, 5000)]}
           end, <<"main">>, ern_helpers:quiet()),
    Writes = ern_waits:wait(writes),
    Read = ern_waits:wait(far_end),
    %% the listener closes once the far end has answered: a close before the
    %% far end's accept had ended refused the accept, and no answer came
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual([Timeout, Timeout, {'Right', 'Unit'}], Writes),
    ?assertEqual({ok, <<"z">>}, Read).

%% Appendix E.18, E.0 shape rule 8: an accept given no time has run out as
%% it begins, answers `Left(Timeout)` and takes nothing, a connection the
%% host holds among it: the accept with time after it takes that connection.
%% A regression test: before the rule, the host's own accept given no time
%% took a connection it held
accept_given_no_time_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               %% the host holds the connection once its connect returns,
               %% a wait in the host's code, the look's foreign code
               {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               Before = [accept(Listener, 0), accept(Listener, -1)],
               Self ! {accepts, {Before, ern_helpers:side(accept(Listener, 5000))}},
               gen_tcp:close(Client)
           end, <<"main">>, ern_helpers:quiet()),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout], 'Right'}, ern_waits:wait(accepts)).

%% Appendix E.18, E.0 shape rule 8: a connect given no time, over TCP and
%% over TLS, has run out as it begins and answers `Left(Timeout)`, to a port
%% where a listener waits; one with time then connects. Written with the
%% rule: before it the host was given the connect with no time, and answered
%% `Timeout` here as well, so the test holds the answer and not that the
%% host is asked nothing
connect_given_no_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    ok = quietly(
           fun() ->
               NoTime = [connect(Port, 0), connect(Port, -1),
                         connect_tls(<<"127.0.0.1">>, Port, 'Unverified', 0),
                         connect_tls(<<"127.0.0.1">>, Port, 'Unverified', -1)],
               Self ! {connects, {NoTime, ern_helpers:side(connect(Port, 2000))}}
           end),
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout, Timeout, Timeout], 'Right'}, ern_waits:wait(connects)).

%% Appendix E.18, report §6.6: a read that timed out has taken nothing: the
%% host still takes the next piece to arrive, which waits in the socket's
%% process for the next read, and the socket goes on delivering to the
%% reads after it. A regression test: the socket asked for one packet per
%% read that found nothing waiting, and the packet went to the read that
%% had timed out, so the next read was never answered. The piece's wait in
%% the socket's process, while no read waits, was added after the code
read_after_timeout_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive go -> ok end,
                       ok = gen_tcp:send(Connection, <<"a">>),
                       %% the second once the first is read, so that each
                       %% read takes one
                       receive next -> ok end,
                       ok = gen_tcp:send(Connection, <<"b">>),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               {'Left', 'Timeout'} = read(Socket, 20),
               Pid = ern_rt:process_of(Socket),
               erlang:trace(Pid, true, ['receive']),
               FarEnd ! go,
               %% the host has handed the piece to the socket's process, and
               %% the next read is sent after it; a wait in a test's code,
               %% the host's to the deadlock detector
               receive {trace, Pid, 'receive', {tcp, _, <<"a">>}} -> ok end,
               erlang:trace(Pid, false, ['receive']),
               Self ! {read, read(Socket, 2000)},
               FarEnd ! next,
               Self ! {read, read(Socket, 2000)},
               FarEnd ! done
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    %% each read after the one that timed out is answered with what arrives
    %% while it waits
    ?assertEqual({'Right', <<"a">>}, ern_waits:wait(read)),
    ?assertEqual({'Right', <<"b">>}, ern_waits:wait(read)).

%% Appendix E.18, report §8.6: an accept that times out has taken nothing,
%% so the connection made after it is the next accept's; a program waiting
%% in an accept is not deadlocked; `port` tells the port `listen(0)` found
accept_timeout_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               Self ! {port, Port},
               Self ! {first, accept(Listener, 300)},
               %% a wait in the host's code, the deadlock detector's foreign code
               {ok, Connection} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               Self ! {second, ern_helpers:side(accept(Listener, 2000))},
               gen_tcp:close(Connection)
           end, <<"main">>, ern_helpers:quiet()),
    ?assert(ern_waits:wait(port) > 0),
    ?assertEqual({'Left', 'Timeout'}, ern_waits:wait(first)),
    ?assertEqual('Right', ern_waits:wait(second)).

%% report §12.2, Appendix E.18: a listener the program closed exits
%% `{ern, closed}`, the host term foreign code sees, which a monitor reads
%% as `Returned`. A regression test of the report's list, written after
%% the code
closed_listener_exit_term_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               MonitorRef = erlang:monitor(process, Listener),
               'Unit' = close_listener(Listener),
               receive {'DOWN', MonitorRef, process, _, ExitReason} -> Self ! {ended, ExitReason}
               end
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({ern, closed}, ern_waits:wait(ended)).

%% Appendix E.18: a socket lives until it is closed: after the far end
%% closes, what came before is read, then each read, `remote` and `local`
%% answer `Left(Closed)`; so does a read whose socket the close ends while
%% it waits in the mailbox, and a read, a write, `remote` and `local` after
%% the close has ended it. The socket is held still until both the close
%% and the read wait in its mailbox. A regression test of the rule, before
%% which a read the close met faulted with `callee was closed` and one
%% after with `callee had ended`, as a callForever does (§6.6)
socket_lives_until_closed_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       ok = gen_tcp:send(Connection, <<"x">>),
                       gen_tcp:close(Connection)
                   end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               {'Right', {'Endpoint', <<"127.0.0.1">>, Port}} = remote(Socket),
               {'Right', {'Endpoint', <<"127.0.0.1">>, _}} = local(Socket),
               %% the far end has written and closed
               FarEndRef = erlang:monitor(process, FarEnd),
               ern_rt:timed(),
               receive {'DOWN', FarEndRef, process, _, _} -> ern_rt:untimed() end,
               Self ! {reads, [read(Socket, 1000), read(Socket, 1000), read(Socket, 1000),
                               remote(Socket), local(Socket)]},
               Pid = ern_rt:process_of(Socket),
               erlang:suspend_process(Pid),
               ok = socket_close_sent(Socket),
               EntryProcess = self(),
               Reader = ern_rt:spawn(fun() -> EntryProcess ! {met, read(Socket, 1000)} end,
                                     <<"reader">>),
               %% the reader waits once it has sent its read
               ok = ern_waits:waiting(ern_rt:process_of(Reader)),
               erlang:resume_process(Pid),
               Self ! {met, receive {met, Met} -> Met end},
               Self ! {later, [read(Socket, 1000), write(Socket, <<"y">>, 1000), remote(Socket),
                               local(Socket)]}
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    ?assertEqual([{'Right', <<"x">>}, {'Left', 'Closed'}, {'Left', 'Closed'},
                  {'Left', 'Closed'}, {'Left', 'Closed'}], ern_waits:wait(reads)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(met)),
    ?assertEqual(lists:duplicate(4, {'Left', 'Closed'}), ern_waits:wait(later)).

%% Appendix E.18: closing a listener answers an accept waiting on it with
%% `Left(Closed)`, and the listener's process ends. Under load the close
%% could come before the accept's worker began, and the host's `einval`
%% was answered `Other("invalid argument")`; that race is not forced here
close_listener_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               EntryProcess = self(),
               %% the accept is at the listener before the close is sent, since
               %% it is sent before `sent`; a spawned accept and a pause before
               %% the close raced it, and the close could come first
               _ = erlang:spawn(fun() ->
                                    Reply = erlang:alias(),
                                    Pid ! {'Accept', 5000, self(), {Reply, self()}},
                                    EntryProcess ! sent,
                                    Self ! {accepted, receive {Reply, answered, Value} -> Value
                                                      after 5000 -> timeout end}
                                end),
               %% waits in a test's code, the host's to the deadlock detector
               receive sent -> ok end,
               'Unit' = close_listener(Listener),
               Self ! {alive, erlang:is_process_alive(Pid)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(accepted)),
    ?assertEqual(false, ern_waits:wait(alive)).

%% Appendix E.18: `closeListener` answers once the listener has ended and
%% its host socket has closed, so that a listen on its port straight after
%% is not refused for the port being held, and a `port` straight after
%% answers `Left(Closed)`, each first in every other round. Written first:
%% the close that was a send lost 1,001 rounds of 2,000, the listen refused
%% `address already in use` 3 times and the port faulting `callee was
%% closed` 1,000 times
close_listener_frees_the_port_test_() ->
    {timeout, 60,
     fun() ->
         ?assertEqual(#{{listened, {'Left', 'Closed'}} => ?CLOSE_ROUNDS},
                      closed_rounds(none, ?CLOSE_ROUNDS))
     end}.

%% The same over TLS. Written first: the close that was a send lost 250
%% rounds of 500, the port faulting `callee was closed`, and no listen was
%% refused
close_listener_frees_the_port_over_tls_test_() ->
    {timeout, 60,
     fun() ->
         ?assertEqual(#{{listened, {'Left', 'Closed'}} => ?TLS_CLOSE_ROUNDS},
                      closed_rounds(pki(), ?TLS_CLOSE_ROUNDS))
     end}.

%% What a listen on the port and a `port` straight after a close give,
%% over Rounds, counted.
closed_rounds(Keys, Rounds) ->
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {rounds, closed_rounds(Keys, Rounds, #{})} end,
                         <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(rounds).

closed_rounds(_, 0, Counts) ->
    Counts;
closed_rounds(Keys, Left, Counts) ->
    {'Right', Listener} = listening(Keys, 0),
    {'Right', Port} = port(Listener),
    'Unit' = close_listener(Listener),
    Key = straight_after(Keys, Port, Listener, Left rem 2),
    closed_rounds(Keys, Left - 1, maps:update_with(Key, fun(Count) -> Count + 1 end, 1, Counts)).

%% A listen on Port and a `port` of Listener, the listen first or second.
straight_after(Keys, Port, Listener, 0) ->
    Again = listened(listening(Keys, Port)),
    {Again, port(Listener)};
straight_after(Keys, Port, Listener, 1) ->
    Asked = port(Listener),
    {listened(listening(Keys, Port)), Asked}.

listened({'Right', Listener}) ->
    'Unit' = close_listener(Listener),
    listened;
listened({'Left', Error}) ->
    Error.

listening(none, Port) -> listen(Port);
listening(#{server := Keys}, Port) -> listen_tls(Port, Keys).

%% Appendix E.18: `closeListener` answers `Unit` at once on a listener that
%% has ended already, by an earlier `closeListener`, by a kill or by its
%% owner's death, and does not fault. Written first, a regression test: the
%% close that was a send did nothing there either
close_listener_on_an_ended_listener_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Closed} = listen(0),
               'Unit' = close_listener(Closed),
               {'Right', Killed} = listen(0),
               ok = ended_by(Killed, fun() -> ern_rt:kill(ern_rt:process_of(Killed)) end),
               EntryProcess = self(),
               _ = erlang:spawn(fun() -> EntryProcess ! {orphaned, listen(0)} end),
               {'Right', Orphaned} = receive {orphaned, Answer} -> Answer end,
               ok = ended_by(Orphaned, fun() -> ok end),
               Self ! {closes, [close_listener(Ended) || Ended <- [Closed, Killed, Orphaned]]}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(['Unit', 'Unit', 'Unit'], ern_waits:wait(closes)).

%% Until Listener has ended, once End has run.
ended_by(Listener, End) ->
    MonitorRef = erlang:monitor(process, ern_rt:process_of(Listener)),
    End(),
    receive {'DOWN', MonitorRef, process, _, _} -> ok end.

%% Appendix E.18, E.21: `closeListener` answers an accept the listener has
%% taken and holds waiting with `Left(Closed)`, and returns only once the
%% accept is answered and its worker has ended; meanwhile `Process.status`
%% shows the close as a call on the listener without a limit. The
%% accept's worker is held in the host's accept until the close waits.
%% Written first: the close that was a send returned at once, before it
%% could be seen waiting
close_listener_waits_for_a_held_accept_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               EntryProcess = self(),
               {_, Worker} = held_accept(Listener, EntryProcess),
               true = erlang:suspend_process(Worker),
               Closer = ern_rt:spawn(fun() ->
                                         Closed = close_listener(Listener),
                                         Alive = erlang:is_process_alive(Worker),
                                         EntryProcess ! {closed, {Closed, Alive}}
                                     end, <<"closer">>),
               Calling = ern_waits:calling(ern_rt:process_of(Closer)),
               Status = ern_rt:status(ern_rt:process_of(Closer)),
               true = erlang:resume_process(Worker),
               Closed = receive {closed, C} -> C end,
               Self ! {held, {Pid, Calling, Status, Closed, accepted()}}
           end, <<"main">>, ern_helpers:quiet()),
    {Pid, Calling, Status, Closed, Accepted} = ern_waits:wait(held),
    ?assertEqual(ok, Calling),
    ?assertMatch({'Some', {'Status', _, _, {'Calling', {'Some', Pid}, false, _}, _}}, Status),
    ?assertEqual({'Left', 'Closed'}, Accepted),
    ?assertEqual({'Unit', false}, Closed).

%% What the accept held_accept/2 started answered, or the cause it faulted
%% with: its end is told after its answer.
accepted() ->
    receive
        {acceptor, {'Down', _, {'Fault', Cause}, _}} -> {fault, Cause};
        {acceptor, {'Down', _, _, _}} -> receive {accepted, Answer} -> Answer end
    end.

%% Appendix E.18: an accept whose worker has taken a connection as
%% `closeListener` comes answers that connection's socket, which its caller
%% owns and reads, and is answered once; the close returns once the worker
%% has ended. The worker is held as the socket it opens is adopted, the
%% reaper held, until the close waits on the listener. Written first: the
%% close that was a send ended the listener at once, and the accept
%% faulted with `callee was closed` while its worker opened the socket
close_listener_answers_a_taken_connection_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               Pid = ern_rt:process_of(Listener),
               {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               ok = gen_tcp:send(Client, <<"x">>),
               Acceptor = ern_rt:spawn_monitored(
                            fun() ->
                                receive go -> ok end,
                                Accepted = accept_forever(Listener),
                                Self ! {accepted, ern_helpers:side(Accepted)},
                                {'Right', Socket} = Accepted,
                                Self ! {read, read(Socket, 2000)}
                            end, fun(Down) -> {acceptor, Down} end, <<"acceptor">>),
               EntryProcess = self(),
               Closer = ern_rt:spawn(fun() ->
                                         receive go -> ok end,
                                         EntryProcess ! {closed, close_listener(Listener)}
                                     end, <<"closer">>),
               Reaper = ern_rt:launch_reaper(),
               erlang:trace(Pid, true, [procs]),
               true = erlang:suspend_process(Reaper),
               Acceptor ! go,
               Worker = spawned(Pid),
               %% the worker has taken the connection, and waits as the reaper
               %% adopts the socket it opens
               ok = waiting_in(Worker, ern_rt),
               ern_rt:process_of(Closer) ! go,
               Calling = ern_waits:calling(ern_rt:process_of(Closer)),
               WorkerHeld = erlang:is_process_alive(Worker),
               true = erlang:resume_process(Reaper),
               {acceptor, {'Down', _, Reason, _}} = receive {acceptor, _} = Down -> Down end,
               Closed = receive {closed, C} -> C end,
               Self ! {held, {Calling, WorkerHeld, Reason, Closed}},
               gen_tcp:close(Client)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({ok, true, 'Returned', 'Unit'}, ern_waits:wait(held)),
    ?assertEqual('Right', ern_waits:wait(accepted)),
    ?assertEqual({'Right', <<"x">>}, ern_waits:wait(read)).

%% Appendix E.18, report §6.6: an `acceptForever` a killed listener holds
%% waiting faults with `callee was killed`, as a call does whose callee is
%% killed, and is never answered `Left(Closed)` by its worker. Each listener is killed once the
%% accept's worker waits in the host's accept. Written first: the listener
%% closed its host socket before it ended, and the worker answered
%% `Left(Closed)` in 10 rounds of 10
killed_listener_faults_a_held_accept_test_() ->
    {timeout, 60,
     fun() ->
         ?assertEqual(#{{fault, <<"callee was killed">>} => ?KILL_ROUNDS},
                      held_rounds(kill, ?KILL_ROUNDS))
     end}.

%% Appendix E.18, report §6.6, §6.9: the same of a listener whose owner
%% dies, which kills it. Written first: the worker answered `Left(Closed)`
%% in 10 rounds of 10
orphaned_listener_faults_a_held_accept_test_() ->
    {timeout, 60,
     fun() ->
         ?assertEqual(#{{fault, <<"callee was killed">>} => ?KILL_ROUNDS},
                      held_rounds(owner, ?KILL_ROUNDS))
     end}.

%% The kill over TLS, whose worker waits in the host's accept as one over
%% TCP does. Written after the code: on the listener that closed its host
%% socket before it ended, the worker answered `Left(Closed)` in 10 rounds
%% of 10
killed_tls_listener_faults_a_held_accept_test_() ->
    {timeout, 60,
     fun() ->
         ?assertEqual(#{{fault, <<"callee was killed">>} => ?KILL_ROUNDS},
                      held_rounds(kill, pki(), ?KILL_ROUNDS))
     end}.

%% Appendix E.18, report §6.9, §6.6: a listener the host ends by an exit no
%% process traps, as foreign code may, ends with its host socket open,
%% which the host closes as it dies, and the host's accept of each worker
%% then answers `closed`. The worker answers nothing, since the listener's
%% end has begun, and the accept's caller faults with the host's term of
%% the end, `killed`. Two accepts are held: one by a process of the run's,
%% whose fault is read, and one by a host process outside the run, which
%% watches its worker and reads, once the worker has ended, whether it was
%% answered, the answer and the worker's end coming from one sender, so in
%% order. Written after the code: on the listener that closed its host
%% socket before it ended, the second worker answered `Left(Closed)`
untrappable_kill_faults_a_held_accept_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               EntryProcess = self(),
               _ = held_accept(Listener, EntryProcess),
               _ = held_accept_watched(Listener, EntryProcess),
               ok = ended_by(Listener, fun() -> exit(ern_rt:process_of(Listener), kill) end),
               Answered = receive {answered, A} -> A end,
               Self ! {killed, {accepted(), Answered}}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{fault, <<"killed">>}, none}, ern_waits:wait(killed)).

%% An `acceptForever` on Listener by a process of the host's, outside the
%% run, which watches the worker the listener answers it by, once the worker
%% waits in the host's accept, and tells Tell, once the worker has ended,
%% what the worker answered, or `none`.
held_accept_watched(Listener, Tell) ->
    Pid = ern_rt:process_of(Listener),
    Accept = fun() ->
                 Reply = erlang:alias(),
                 Pid ! {'AcceptForever', self(), {Reply, self()}},
                 WorkerRef = erlang:monitor(process, receive {worker, W} -> W end),
                 Tell ! watching,
                 receive {'DOWN', WorkerRef, process, _, _} -> ok end,
                 Tell ! {answered, receive {Reply, answered, Value} -> Value after 0 -> none end}
             end,
    {Acceptor, Worker} = held_by_a_worker(Listener, fun() -> erlang:spawn(Accept) end),
    Acceptor ! {worker, Worker},
    receive watching -> ok end.

%% How each accept of Rounds ends, counted, a listener holding it as the
%% listener is ended How, killed or with its owner, the listener over TCP
%% or over TLS with Keys, a new one each round.
held_rounds(How, Rounds) ->
    held_rounds(How, none, Rounds).

held_rounds(How, Keys, Rounds) ->
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {rounds, held_rounds(How, Keys, Rounds, #{})} end,
                         <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(rounds).

held_rounds(_, _, 0, Counts) ->
    Counts;
held_rounds(How, Keys, Left, Counts) ->
    {Listener, End} = owned_listener(How, Keys),
    EntryProcess = self(),
    _ = held_accept(Listener, EntryProcess),
    End(),
    Key = accepted(),
    held_rounds(How, Keys, Left - 1,
                maps:update_with(Key, fun(Count) -> Count + 1 end, 1, Counts)).

%% A listener and what ends it: a kill, or its owner's end, the owner a
%% process of its own that listens and waits for its end; over TCP, or
%% over TLS with Keys.
owned_listener(How) ->
    owned_listener(How, none).

owned_listener(kill, Keys) ->
    {'Right', Listener} = listening(Keys, 0),
    {Listener, fun() -> ern_rt:kill(ern_rt:process_of(Listener)) end};
owned_listener(owner, Keys) ->
    EntryProcess = self(),
    Owner = erlang:spawn(fun() ->
                             EntryProcess ! {owned, listening(Keys, 0)},
                             receive done -> ok end
                         end),
    {'Right', Listener} = receive {owned, Answer} -> Answer end,
    {Listener, fun() -> Owner ! done end}.

%% Appendix E.18: a kill of a listener whose close waits for an accept it
%% holds, or its owner's death then, ends it at once, and the close
%% answers then, the accept's worker still held; the accept's caller faults
%% with `callee was killed`, its worker let go only once the listener has
%% ended. Written with the code, a test of a place E.18 is silent on; the
%% close that was a send returned before it could be seen waiting
ended_while_closing_test() ->
    [?assertEqual({{'Unit', true}, {fault, <<"callee was killed">>}}, ended_while_closing(How))
     || How <- [kill, owner]].

ended_while_closing(How) ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {Listener, End} = owned_listener(How),
               Pid = ern_rt:process_of(Listener),
               EntryProcess = self(),
               {_, Worker} = held_accept(Listener, EntryProcess),
               true = erlang:suspend_process(Worker),
               Closer = ern_rt:spawn(fun() ->
                                         Closed = close_listener(Listener),
                                         Alive = erlang:is_process_alive(Worker),
                                         EntryProcess ! {closed, {Closed, Alive}}
                                     end, <<"closer">>),
               ok = ern_waits:calling(ern_rt:process_of(Closer)),
               ok = ern_waits:waiting(Pid),
               End(),
               Closed = receive {closed, C} -> C end,
               true = erlang:resume_process(Worker),
               Self ! {ended, {Closed, accepted()}}
           end, <<"main">>, ern_helpers:quiet()),
    ern_waits:wait(ended).

%% Report Appendix E.18, §8.6: a program whose last act is `closeListener`
%% ends, and the runtime, which looks for a deadlock twice while the close
%% waits on an accept the listener holds, finds none, and the accept
%% answers `Left(Closed)`. Written first, a regression test: the close that
%% was a send ended the program too; the accept's answer was asked with the
%% code
close_listener_is_no_deadlock_test() ->
    Self = self(),
    Outcome = ern_rt:run_main(
                fun() ->
                    {'Right', Listener} = listen(0),
                    %% the accept's answer is told after the run's end
                    {_, Worker} = held_accept_outside(Listener, Self),
                    %% the process that holds the worker still lets it go
                    EntryProcess = self(),
                    _ = erlang:spawn(fun() ->
                                         true = erlang:suspend_process(Worker),
                                         EntryProcess ! held,
                                         ok = ern_waits:looked(2),
                                         erlang:resume_process(Worker)
                                     end),
                    receive held -> ok end,
                    close_listener(Listener)
                end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(ok, Outcome),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(accepted)).

%% Report §6.9, Appendix E.18, E.22: a restart asked of a process that waits
%% in `closeListener` is taken at that wait, as at a call's: the process
%% restarts, the cause of its new start `Asked`, and its call is noted on
%% the listener no longer; the listener, asked to close, still closes, and
%% the accept it holds answers `Left(Closed)`. The accept's worker is held
%% in the host's accept, so that the close waits. Written after the code, a
%% test of a path call_until_ended/2 takes from callForever's
close_listener_takes_a_restart_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               EntryProcess = self(),
               {_, Worker} = held_accept(Listener, EntryProcess),
               true = erlang:suspend_process(Worker),
               Closing = ern_rt:restarting(
                           'Unlimited',
                           fun() ->
                               case ern_rt:start_cause() of
                                   'First' ->
                                       EntryProcess ! {closed, close_listener(Listener)};
                                   Cause ->
                                       Noted = ets:member(ern_callees, {Pid, erlang:self()}),
                                       EntryProcess ! {restarted, {Cause, Noted}}
                                   end
                           end),
               Closer = ern_rt:spawn(Closing, <<"closer">>),
               ok = ern_waits:calling(ern_rt:process_of(Closer)),
               true = ern_rt:ask_restart(ern_rt:process_of(Closer)),
               Restarted = receive
                               {restarted, Started} -> Started;
                               {closed, _} = Closed -> Closed
                           end,
               true = erlang:resume_process(Worker),
               ok = ended_by(Listener, fun() -> ok end),
               Self ! {restarted, {Restarted, accepted()}}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Asked', false}, {'Left', 'Closed'}}, ern_waits:wait(restarted)).

%% Report §8.4, §6.5, Appendix E.18: a bad message foreign code sends
%% through a check to a process that waits in `closeListener` faults it at
%% that wait, as at a call's; the listener, asked to close, still closes,
%% and the accept it holds answers `Left(Closed)`. The accept's worker is
%% held in the host's accept, so that the close waits and cannot end the
%% wait first. Written after the code, a test of a path call_until_ended/2
%% takes from callForever's
close_listener_takes_a_foreign_fault_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               EntryProcess = self(),
               {_, Worker} = held_accept(Listener, EntryProcess),
               true = erlang:suspend_process(Worker),
               Closer = ern_rt:spawn_monitored(fun() -> close_listener(Listener) end,
                                               fun(Down) -> {closer, Down} end, <<"closer">>),
               ok = ern_waits:calling(ern_rt:process_of(Closer)),
               Int = {address, int, <<"message does not match Int">>, <<"the hash of Int">>},
               ern_boundary:expose(Int, Closer) ! <<"no Int">>,
               Faulted = receive {closer, {'Down', _, Reason, _}} -> Reason end,
               true = erlang:resume_process(Worker),
               ok = ended_by(Listener, fun() -> ok end),
               Self ! {faulted, {Faulted, accepted()}}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{'Fault', <<"message does not match Int">>}, {'Left', 'Closed'}},
                 ern_waits:wait(faulted)).

%% An `acceptForever` on Listener by a process of the run's, whose answer it
%% tells Tell as `accepted` and whose end it tells as `acceptor`, and the
%% worker the listener answers it by, once the worker waits in the host's
%% accept: the listener has taken the accept. The worker is found as the
%% listener spawns it, which the host traces.
held_accept(Listener, Tell) ->
    Accept = fun() -> Tell ! {accepted, accept_forever(Listener)} end,
    Start = fun() ->
                ern_rt:spawn_monitored(Accept, fun(Down) -> {acceptor, Down} end, <<"acceptor">>)
            end,
    held_by_a_worker(Listener, Start).

%% The same by a process of the host's, outside the run, which tells Tell
%% its answer whether or not the run has ended by then.
held_accept_outside(Listener, Tell) ->
    Pid = ern_rt:process_of(Listener),
    Accept = fun() ->
                 Reply = erlang:alias(),
                 Pid ! {'AcceptForever', self(), {Reply, self()}},
                 Tell ! {accepted, receive {Reply, answered, Value} -> Value end}
             end,
    held_by_a_worker(Listener, fun() -> erlang:spawn(Accept) end).

%% The acceptor Start starts on Listener, and the worker the listener
%% answers it by, once the worker waits in the host's accept.
held_by_a_worker(Listener, Start) ->
    Pid = ern_rt:process_of(Listener),
    erlang:trace(Pid, true, [procs]),
    Acceptor = Start(),
    Worker = spawned(Pid),
    ok = waiting_in(Worker, prim_inet),
    {Acceptor, Worker}.

%% Until Pid waits in a function of Module, or has ended.
waiting_in(Pid, Module) ->
    ern_waits:until(Pid, fun() ->
                             case erlang:process_info(Pid, [status, current_function]) of
                                 [{status, waiting}, {current_function, {Module, _, _}}] -> true;
                                 _ -> false
                             end
                         end).

%% The next process Pid spawns, which the host traces, and Pid's tracing
%% then off, its trace messages taken out.
spawned(Pid) ->
    Worker = receive {trace, Pid, spawn, Spawned, _} -> Spawned end,
    _ = erlang:trace(Pid, false, [procs]),
    ern_waits:flushed(Pid),
    Worker.

%% Appendix E.18, report §12: at the operating system's limit of open
%% files an accept with no connection waiting answers the host's refusal,
%% `Left(Other("too many open files"))`, at once, since the host takes the
%% descriptor before it waits for a connection, and so does an
%% `acceptForever`, which waits without a limit; and a connection that comes
%% meanwhile waits in the listener's backlog for a later accept, which
%% takes it once closed listeners have freed files. The program runs in a
%% host of its own under `ulimit -n`, at_the_file_limit/0, and this host is
%% its client. A regression test, written after the sentence, whose probe
%% found the host answering so, its `acceptForever` written with the
%% function; it does not cover a listener over TLS, nor the system's own
%% limit of files, `enfile`
accept_at_the_file_limit_test_() ->
    {timeout, 60, fun accept_at_the_file_limit/0}.

accept_at_the_file_limit() ->
    %% the repository's code, which the tests run from its root, after the
    %% host's own, as a run puts it (report §11.2, ern_cli:host_path/1)
    Build = filename:absname("build") ++ "/",
    Paths = [" -pz " ++ Dir || Dir <- code:get_path(), lists:prefix(Build, filename:absname(Dir))],
    Erl = open_port({spawn, "sh -c 'ulimit -n 64; exec erl -noshell" ++ lists:append(Paths) ++
                         " -eval \"ern_tcp_tests:at_the_file_limit(), erlang:halt(0)\"'"},
                    [binary, exit_status, stderr_to_stdout, {line, 200}]),
    true = port_command(Erl, "go\n"),
    <<"port: ", PortText/binary>> = next_line(Erl, <<"port: ">>),
    _ = next_line(Erl, <<"filled">>),
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, binary_to_integer(PortText),
                                   [binary, {active, false}], 5000),
    ok = gen_tcp:send(Socket, <<"x">>),
    true = port_command(Erl, "connected\n"),
    _ = next_line(Erl, <<"accept: {'Left',{'Other',<<\"too many open files\">>}}">>),
    _ = next_line(Erl, <<"forever: {'Left',{'Other',<<\"too many open files\">>}}">>),
    <<"took: ", Took/binary>> = next_line(Erl, <<"took: ">>),
    _ = next_line(Erl, <<"later: {'Right',<<\"x\">>}">>),
    Status = receive {Erl, {exit_status, Exit}} -> Exit after 20000 -> none end,
    gen_tcp:close(Socket),
    ?assertEqual(0, Status),
    %% a host that waited the accept's time out would take all of it, and
    %% half tells the two apart under any load
    ?assert(binary_to_integer(Took) < 1000).

%% The next line the host under the limit writes, which begins as Expected
%% says; where it does not, or the host falls silent, the test fails with
%% every line the host wrote from there.
next_line(Erl, Expected) ->
    receive
        {Erl, {data, {eol, Line}}} ->
            case binary:longest_common_prefix([Line, Expected]) =:= byte_size(Expected) of
                true -> Line;
                false -> erlang:error({next_line, [Line | rest(Erl)]})
            end
    after 20000 -> erlang:error({silent, Expected})
    end.

rest(Erl) ->
    receive
        {Erl, {data, {eol, Line}}} -> [Line | rest(Erl)];
        {Erl, {exit_status, _}} -> []
    after 20000 -> []
    end.

%% The program of accept_at_the_file_limit/0, in the host under the limit:
%% a door's port said; its listeners opened until one is refused; an accept
%% at the door, with 2000 ms and nobody connecting, timed, and one without
%% a time after it; and once the client has connected, three listeners
%% closed and ended, and the door's next accept taking the connection and
%% reading its byte. The host loads what the run's side calls first, as
%% `ern run` does (report §12), since the limit refuses the file a module
%% is loaded from; the lines of what was answered are written after the
%% closes for the same reason.
-spec at_the_file_limit() -> ok.
at_the_file_limit() ->
    ok = ern_code:load_runtime(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Door} = listen(0),
               {'Right', Port} = port(Door),
               io:format("port: ~p~n", [Port]),
               "go\n" = io:get_line(""),
               Listeners = filled([]),
               Start = erlang:monotonic_time(millisecond),
               Refused = accept(Door, 2000),
               Took = erlang:monotonic_time(millisecond) - Start,
               Forever = accept_forever(Door),
               io:format("filled~n"),
               "connected\n" = io:get_line(""),
               [First, Second, Third | _] = Listeners,
               lists:foreach(fun closed/1, [First, Second, Third]),
               {'Right', Socket} = accept(Door, 5000),
               io:format("accept: ~0p~nforever: ~0p~ntook: ~p~nlater: ~0p~n",
                         [Refused, Forever, Took, read(Socket, 5000)])
           end, <<"main">>, ern_helpers:quiet()).

%% Listeners opened until the host refuses one, each kept, so that the
%% host's files stay at the operating system's limit.
filled(Listeners) ->
    case listen(0) of
        {'Right', Listener} -> filled([Listener | Listeners]);
        {'Left', {'Other', <<"too many open files">>}} -> Listeners
    end.

%% A listener closed and ended, its file given back.
closed(Listener) ->
    'Unit' = close_listener(Listener).

%% Appendix E.18: an accept that waits in the mailbox as the listener's
%% close ends it answers `Left(Closed)`, as an accept after the close does.
%% The listener is held still until both the close and the accept wait in
%% its mailbox. A regression test of the rule, before which the first
%% faulted with `callee was closed`, as a callForever does (§6.6), and the
%% second with `callee had ended`
accept_meets_the_close_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               erlang:suspend_process(Pid),
               ok = close_sent(Listener),
               EntryProcess = self(),
               Acceptor = ern_rt:spawn(fun() -> EntryProcess ! {met, accept(Listener, 1000)} end,
                                       <<"acceptor">>),
               %% the acceptor waits once it has sent its accept
               ok = ern_waits:waiting(ern_rt:process_of(Acceptor)),
               erlang:resume_process(Pid),
               Met = receive {met, Accepted} -> Accepted end,
               Self ! {accepts, [Met, accept(Listener, 1000), port(Listener)]}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(lists:duplicate(3, {'Left', 'Closed'}), ern_waits:wait(accepts)).

%% Appendix E.18: `acceptForever` and `readForever` are `accept` and `read`
%% without a time. An accept that waits answers the connection made after
%% it began, and a read that waits the bytes written after it began; once
%% the far end has closed, each read answers `Left(Closed)`. The far end is
%% this host's, outside the run, and acts once the run's process waits: on
%% the listener once it calls, and on the socket once the socket watches it.
%% Written with the requests
forever_waits_answer_what_comes_later_test() ->
    Self = self(),
    FarEnd = spawn(fun() ->
                       receive {accepting, EntryProcess, Port} -> ok end,
                       ok = ern_waits:calling(EntryProcess),
                       {ok, Connection} = gen_tcp:connect("127.0.0.1", Port,
                                                          [binary, {active, false}]),
                       receive {reading, Socket} -> ok end,
                       ok = ern_waits:watching(ern_rt:process_of(Socket), EntryProcess),
                       ok = gen_tcp:send(Connection, <<"x">>),
                       receive close -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               FarEnd ! {accepting, self(), Port},
               {'Right', Socket} = accept_forever(Listener),
               FarEnd ! {reading, Socket},
               Bytes = read_forever(Socket),
               FarEnd ! close,
               Self ! {reads, [Bytes, read_forever(Socket), read_forever(Socket)]}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual([{'Right', <<"x">>}, {'Left', 'Closed'}, {'Left', 'Closed'}],
                 ern_waits:wait(reads)).

%% Appendix E.18: `closeListener` answers an `acceptForever` waiting on the
%% listener with `Left(Closed)`, and `close` a `readForever` waiting on the
%% socket, as they answer `accept` and `read`. The close is sent once the
%% accept's caller calls, and once the socket watches the read's. Written
%% with the requests
close_answers_the_waits_without_a_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, FarPort} = inet:port(Listen),
    FarEnd = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Acceptor = ern_rt:spawn_monitored(fun() -> Self ! {accept, accept_forever(Listener)}
                                                 end, fun(Down) -> {ended, Down} end,
                                                 <<"acceptor">>),
               ok = ern_waits:calling(ern_rt:process_of(Acceptor)),
               'Unit' = close_listener(Listener),
               {'Right', Socket} = connect(FarPort, 2000),
               Reader = ern_rt:spawn_monitored(fun() -> Self ! {read, read_forever(Socket)} end,
                                               fun(Down) -> {ended, Down} end, <<"reader">>),
               ok = ern_waits:watching(ern_rt:process_of(Socket), ern_rt:process_of(Reader)),
               'Unit' = close(Socket),
               [receive {ended, _} -> ok end || _ <- [Acceptor, Reader]]
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(accept)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(read)).

%% Appendix E.18, report §6.6: a `readForever` waiting on a socket that is
%% killed faults with `callee was killed`, as a call does whose callee is
%% killed. The kill comes once the socket watches the read's caller.
%% Written after the code
killed_socket_faults_a_waiting_read_forever_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, FarPort} = inet:port(Listen),
    FarEnd = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(FarPort, 2000),
               Reader = ern_rt:spawn_monitored(fun() -> read_forever(Socket) end,
                                               fun(Down) -> {ended, Down} end, <<"reader">>),
               ok = ern_waits:watching(ern_rt:process_of(Socket), ern_rt:process_of(Reader)),
               ern_rt:kill(ern_rt:process_of(Socket)),
               Self ! {ended, receive {ended, {'Down', _, Reason, _}} -> Reason end}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Fault', <<"callee was killed">>}, ern_waits:wait(ended)).

%% report §6.5, §6.6, §7.3, Appendix E.18: a fault in an adapted address's
%% function over a listener ends the listener, which has no wait of
%% Ernest's, as a kill ends it, with the reason `Fault(cause)`: its monitor
%% is told so with its site, the fault is reported with the trace of where
%% it was met, an `acceptForever` waiting on it faults with the fault's
%% cause, the listener's site beside it, and a later call answers
%% `Left(Closed)`. The accept is made through an address adapted over the
%% listener whose function sends the fault first, so that the accept waits
%% in the listener's mailbox behind the fault, the call's monitor made
%% before either. Written before the fix, on which it failed (the log's *A
%% Resource Ends at a Fault*): the listener's loop did not read the fault,
%% and the listener lived on
fault_ends_a_listener_test() ->
    Self = self(),
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    {ok, Output} = ern_program:run(['M'],
        "type Msg = Ended(Down) | Waiter(Down)\n"
        "fn boom(n : Int) : Tcp.ListenerMsg = fault(\"boom \" <> Int.toString(n))\n"
        "fn faultFirst(listener : Address(Tcp.ListenerMsg)) :"
        " (Tcp.ListenerMsg) -> Tcp.ListenerMsg =\n"
        "    fn(request) = {\n"
        "        send(adapted(listener, boom), 1);\n"
        "        request\n"
        "    }\n"
        "fn said(answer : Either(Io.Error, a)) : String =\n"
        "    match answer {\n"
        "        Left(error) -> \"Left(\" <> Io.show(error) <> \")\"\n"
        "      | Right(_) -> \"Right\"\n"
        "    }\n"
        "export fn main() : Unit receiving Msg =\n"
        "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "        Left(error) -> Io.println(Io.show(error))\n"
        "      | Right(listener) -> {\n"
        "            monitor(Process.fromAddress(listener), Ended);\n"
        "            let front = adapted(listener, faultFirst(listener));\n"
        "            let _ = spawnMonitored(fn() = {\n"
        "                let _ = Tcp.acceptForever(front);\n"
        "                Unit\n"
        "            }, Waiter);\n"
        "            receive {\n"
        "                Ended(Down(=reason, =site)) ->\n"
        "                    Io.println(Io.show(reason) <> \" \" <> site)\n"
        "            };\n"
        "            receive {\n"
        "                Waiter(Down(=reason)) -> Io.println(Io.show(reason))\n"
        "            };\n"
        "            Io.println(said(Tcp.port(listener)));\n"
        "            Io.println(said(Tcp.accept(listener, 1000)))\n"
        "        }\n"
        "    }\n", #{faults => Reporter}),
    ?assertEqual(<<"Fault(\"boom 1\") Tcp.listen\nFault(\"boom 1\")\n"
                   "Left(Io.Closed)\nLeft(Io.Closed)\n">>, Output),
    Reports = reported([]),
    [{'FaultReport', _, <<"Tcp.listen">>, <<"boom 1">>, false, Trace, _, 'None', 'None', _}] =
        [Report || {'FaultReport', _, <<"Tcp.listen">>, _, _, _, _, _, _, _} = Report <- Reports],
    ?assertEqual(<<"M.boom:2\nM.faultFirst:5\nM.main:20\n">>, Trace),
    ?assertMatch([{'FaultReport', _, <<"M.main:19">>, <<"boom 1">>, false, <<"M.main:20\n">>, _,
                   {'Some', {'Faulted', <<"Tcp.listen">>}}, 'None', _}],
                 [Report || {'FaultReport', _, <<"M.", _/binary>>, _, _, _, _, _, _, _} = Report
                                <- Reports]).

%% report §6.5, §7.3, Appendix E.18: a fault in an adapted address's
%% function over a socket ends the socket as a kill ends it, with the reason
%% `Fault(cause)`: its monitor is told so with its site, the fault is
%% reported with the trace of where it was met, a later read answers
%% `Left(Closed)`, and the far end reads the connection's close. Written
%% before the fix, on which it failed (the log's *A Resource Ends at a
%% Fault*): the socket's loop did not read the fault, and the socket lived on
fault_ends_a_socket_test() ->
    Self = self(),
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    {ok, Output} = ern_program:run(['M'],
        "type Msg = Ended(Down)\n"
        "fn boom(n : Int) : Tcp.SocketMsg = fault(\"boom \" <> Int.toString(n))\n"
        "fn said(answer : Either(Io.Error, a)) : String =\n"
        "    match answer {\n"
        "        Left(error) -> \"Left(\" <> Io.show(error) <> \")\"\n"
        "      | Right(_) -> \"Right\"\n"
        "    }\n"
        "fn faulted() : Either(Io.Error, Unit) receiving Msg = {\n"
        "    let listener <- Tcp.listen(\"127.0.0.1\", 0);\n"
        "    let port <- Tcp.port(listener);\n"
        "    let client <- Tcp.connect(\"127.0.0.1\", port, 1000);\n"
        "    let server <- Tcp.accept(listener, 1000);\n"
        "    monitor(Process.fromAddress(server), Ended);\n"
        "    send(adapted(server, boom), 1);\n"
        "    receive {\n"
        "        Ended(Down(=reason, =site)) -> Io.println(Io.show(reason) <> \" \" <> site)\n"
        "    };\n"
        "    Io.println(said(Tcp.read(server, 1000)));\n"
        "    Io.println(said(Tcp.read(client, 1000)));\n"
        "    Tcp.close(client);\n"
        "    Right(Tcp.closeListener(listener))\n"
        "}\n"
        "export fn main() : Unit receiving Msg =\n"
        "    match faulted() {\n"
        "        Left(error) -> Io.println(Io.show(error))\n"
        "      | Right(_) -> Unit\n"
        "    }\n", #{faults => Reporter}),
    ?assertEqual(<<"Fault(\"boom 1\") Tcp.accept\nLeft(Io.Closed)\nLeft(Io.Closed)\n">>, Output),
    ?assertMatch([{'FaultReport', _, <<"Tcp.accept">>, <<"boom 1">>, false,
                   <<"M.boom:2\nM.faulted:14\n", _/binary>>, _, 'None', 'None', _}],
                 reported([])).

%% report §8.4, §6.5, Appendix E.18: a bad message foreign code sends
%% through the check in front of a listener ends the listener, which has no
%% wait of Ernest's, as a fault in an adapted address's function does, with
%% the reason `Fault("message does not match Tcp.ListenerMsg")`: its monitor
%% is told so, the fault is reported with an empty trace, since it was met
%% in no code of the program's, and a later call answers `Left(Closed)`.
%% Written before the fix, on which it failed (the log's *A Resource Ends at
%% a Fault*): the listener's loop did not read the fault, and the listener
%% lived on
bad_message_ends_a_listener_test() ->
    Self = self(),
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    {ok, Output} = ern_program:run(['M'],
        "foreign fn sent(listener : Address(Tcp.ListenerMsg), message : Foreign.Term) :"
        " Foreign.Term = \"erlang:send/2\"\n"
        "type Msg = Ended(Down)\n"
        "fn said(answer : Either(Io.Error, a)) : String =\n"
        "    match answer {\n"
        "        Left(error) -> \"Left(\" <> Io.show(error) <> \")\"\n"
        "      | Right(_) -> \"Right\"\n"
        "    }\n"
        "export fn main() : Unit receiving Msg =\n"
        "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "        Left(error) -> Io.println(Io.show(error))\n"
        "      | Right(listener) -> {\n"
        "            monitor(Process.fromAddress(listener), Ended);\n"
        "            let _ = sent(listener, Foreign.term(1));\n"
        "            receive {\n"
        "                Ended(Down(=reason, =site)) ->\n"
        "                    Io.println(Io.show(reason) <> \" \" <> site)\n"
        "            };\n"
        "            Io.println(said(Tcp.port(listener)))\n"
        "        }\n"
        "    }\n", #{faults => Reporter}),
    ?assertEqual(<<"Fault(\"message does not match Tcp.ListenerMsg\") Tcp.listen\n"
                   "Left(Io.Closed)\n">>, Output),
    ?assertMatch([{'FaultReport', _, <<"Tcp.listen">>, <<"message does not match Tcp.ListenerMsg">>,
                   false, <<>>, _, 'None', 'None', _}],
                 reported([])).

%% report §6.6, Appendix E.18: an `acceptForever` and a `readForever` fault
%% as `accept` and `read` do on a listener or a socket that has ended: with
%% `callee was closed` where the close ends it while the call waits in its
%% mailbox, and with `callee had ended` where it had ended before. Each is
%% held still until both the close and the call wait in its mailbox.
%% Written with the requests
waits_without_a_time_meet_the_close_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, FarPort} = inet:port(Listen),
    FarEnd = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Self ! {listener, met_the_close(Listener, fun close_sent/1, fun accept_forever/1)},
               {'Right', Socket} = connect(FarPort, 2000),
               Self ! {socket, met_the_close(Socket, fun socket_close_sent/1, fun read_forever/1)}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    [?assertMatch({{'Down', _, {'Fault', <<"callee was closed">>}, _},
                   {'Down', _, {'Fault', <<"callee had ended">>}, _}}, ern_waits:wait(Tag))
     || Tag <- [listener, socket]].

%% How a caller of Call on Address ends where the close Close sends ends it
%% while the call waits in its mailbox, and how a caller after it ends.
met_the_close(Address, Close, Call) ->
    Pid = ern_rt:process_of(Address),
    erlang:suspend_process(Pid),
    Close(Address),
    Caller = ern_rt:spawn_monitored(fun() -> Call(Address) end, fun(Down) -> {down, Down} end,
                                    <<"caller">>),
    ok = ern_waits:calling(ern_rt:process_of(Caller)),
    erlang:resume_process(Pid),
    First = receive {down, Down} -> Down end,
    _ = ern_rt:spawn_monitored(fun() -> Call(Address) end, fun(Later) -> {later, Later} end,
                               <<"caller">>),
    {First, receive {later, Later} -> Later end}.

%% Appendix E.18: an `acceptForever` whose caller has ended takes its
%% connection, whose socket is killed at once, as an `accept`'s is: the
%% client finds its connection closed, and the next accept takes the next
%% connection. The caller is killed once it calls. Written with the
%% requests; an `accept` with a time, which takes the same way, is not
%% covered
accept_forever_of_an_ended_caller_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               Acceptor = ern_rt:spawn_monitored(fun() -> accept_forever(Listener) end,
                                                 fun(Down) -> {acceptor, Down} end,
                                                 <<"acceptor">>),
               ok = ern_waits:calling(ern_rt:process_of(Acceptor)),
               ern_rt:kill(Acceptor),
               receive {acceptor, _} -> ok end,
               %% waits in the host's code, the look's foreign code
               {ok, First} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               Taken = gen_tcp:recv(First, 0, 5000),
               {ok, Second} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               ok = gen_tcp:send(Second, <<"x">>),
               {'Right', Socket} = accept_forever(Listener),
               Self ! {accepts, {Taken, read_forever(Socket)}},
               gen_tcp:close(First),
               gen_tcp:close(Second)
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({{error, closed}, {'Right', <<"x">>}}, ern_waits:wait(accepts)).

%% Appendix E.18, report §8.6: a `readForever` whose caller has ended before
%% it is answered is dropped as a `read` is, the bytes that arrive after it
%% the next read's, and its count as a source ends with it, so that the
%% program is found deadlocked after. Written with the requests, as
%% read_of_an_ended_caller_dropped_test is
read_forever_of_an_ended_caller_dropped_test() ->
    dropped_read(fun read_forever/1, fun read_forever/1).

%% report §8.6: a socket killed while a read waits on it holds no source,
%% so the deadlock of what is left is still found. A regression test for
%% the count of sources, which a killed holder could leave up for good
killed_socket_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    FarEnd = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Socket} = connect(Port, 2000),
                   Reader = ern_rt:spawn(fun() -> read(Socket, 100000) end,
                                         <<"reader">>),
                   ern_rt:monitor(Reader, fun(Down) -> {down, Down} end),
                   %% the socket has taken the read, and counts it, as it is
                   %% killed
                   ok = ern_waits:watching(Socket, ern_rt:process_of(Reader)),
                   ern_rt:kill(Socket),
                   receive {down, _} -> ok end,
                   ern_waits:forever()
               end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% Appendix E.18, report §8.6: a read whose caller has ended before it is
%% answered is dropped as one that times out is, the bytes that arrive after
%% it the next read's, and its count as a source ends with it, so that the
%% program is found deadlocked after. A regression test: before the rule,
%% the read took the bytes for its ended caller; a read that waits for a
%% handshake, dropped the same way, and a caller that ends while the bytes
%% are on their way, before the socket has its `DOWN`, are not covered
read_of_an_ended_caller_dropped_test() ->
    dropped_read(fun(Socket) -> read(Socket, 60000) end, fun(Socket) -> read(Socket, 2000) end).

%% A reader killed in its Read of a socket, which the socket watches, and
%% once the socket no longer does, Next, which reads the bytes the far end
%% sends after the end; the program is found deadlocked after.
dropped_read(Read, Next) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive go -> ok end,
                       ok = gen_tcp:send(Connection, <<"x">>),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Socket} = connect(Port, 2000),
                   Reader = ern_rt:spawn_monitored(fun() -> Read(Socket) end,
                                                   fun(Down) -> {reader, Down} end,
                                                   <<"reader">>),
                   Pid = ern_rt:process_of(Reader),
                   ok = ern_waits:watching(Socket, Pid),
                   ern_rt:kill(Reader),
                   receive {reader, _} -> ok end,
                   %% so that its `DOWN` comes before the bytes
                   ok = ern_waits:unwatched(Socket, Pid),
                   FarEnd ! go,
                   Self ! {read, Next(Socket)},
                   ern_waits:forever()
               end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Right', <<"x">>}, ern_waits:wait(read)),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% Appendix E.18: bytes that come for a read whose caller has ended, before
%% the socket's process has the caller's `DOWN`, wait for the next read, the
%% host asked whether the caller lives before they are answered. The window
%% is made here: the socket's process is held still while the test gives it
%% the message the host's socket would send, and the reader is killed, so
%% that the bytes come before the `DOWN`. A regression test: before the
%% rule, the bytes went to the ended reader and the next read timed out; a
%% caller that ends with its answer in its mailbox is every call's, and not
%% covered
bytes_ahead_of_the_down_kept_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               HostSocket = host_socket(Socket),
               Pid = ern_rt:process_of(Socket),
               Reader = ern_rt:spawn_monitored(fun() -> read(Socket, 60000) end,
                                               fun(Down) -> {reader, Down} end, <<"reader">>),
               ok = ern_waits:watching(Pid, ern_rt:process_of(Reader)),
               erlang:suspend_process(Pid),
               Pid ! {tcp, HostSocket, <<"x">>},
               ern_rt:kill(Reader),
               receive {reader, _} -> ok end,
               erlang:resume_process(Pid),
               Self ! {read, read(Socket, 1000)}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Right', <<"x">>}, ern_waits:wait(read)).

%% Appendix E.18, report §8.6: a port out of range is answered as an error,
%% `Invalid`, by `listen` and `connect` alike, and the program is still found
%% deadlocked after. A regression test: the host raised, the request was
%% never answered, and a connect left its wait counted for good, so no
%% deadlock was found again
port_out_of_range_test() ->
    Self = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Self ! {listened, listen(70000)},
                   Self ! {connected, connect(70000, 1000)},
                   ern_waits:forever()
               end, <<"main">>, ern_helpers:quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, ern_waits:wait(listened)),
    ?assertEqual(Refused, ern_waits:wait(connected)),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% Appendix E.18: a connect to a port where nothing listens, which the far
%% end refuses, answers `Refused`. A regression test, written after the code
connect_refused_test() ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    ok = gen_tcp:close(Held),
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {connected, connect(Port, 2000)} end,
                         <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Left', 'Refused'}, ern_waits:wait(connected)).

%% Appendix E.18: a host that holds U+0000 names none, `Invalid`, by
%% `listen` and `connect` alike, and the program is still found deadlocked
%% after. A regression test: the host raised an exit the worker did not
%% catch, the caller waited for good, and no deadlock was found
host_with_nul_test() ->
    Self = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Self ! {listened, listen(<<"127.0.0.1", 0, "evil">>, 0)},
                   Self ! {connected, connect(<<"127.0.0.1", 0, "evil">>, 1, 1000)},
                   ern_waits:forever()
               end, <<"main">>, ern_helpers:quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, ern_waits:wait(listened)),
    ?assertEqual(Refused, ern_waits:wait(connected)),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% Appendix E.18: `connect` reaches the address its host names, IPv6's
%% too. A regression test: the host's name went to the host without its
%% family, and `::1` was answered `Other("non-existing domain")`
connect_ipv6_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(<<"::1">>, 0),
               {'Right', Port} = port(Listener),
               Self ! {connected, ern_helpers:side(connect(<<"::1">>, Port, 2000))}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual('Right', ern_waits:wait(connected)).

%% Appendix E.18: a listener takes connections of its address's family
%% alone, so one on "::" and one on "0.0.0.0" stand on one port together,
%% whichever opens first, and each socket's `remote` reads an address of
%% its connection's family. A regression test: "::" took IPv4 connections
%% too, as ::ffff:127.0.0.1, and "0.0.0.0" beside it was answered
%% `Other("address already in use")`. It does not cover an interface other
%% than the loopback's, nor a machine without IPv6, where it says so.
%%
%% Another socket of the machine, a connection's in TIME-WAIT among them,
%% can hold in the other family the port the host gives the first listener
%% of a pair, and the second is then refused as the regression refused it.
%% So a refusal is read again: under the regression a listener on "::"
%% takes an IPv4 connection, and the refusal fails the test; where none
%% takes one, the port was another socket's, and the test takes a new pair
%% of ports.
%%
%% The retries end at the first pair that stands or at a refusal the
%% regression made; where every port the host gives is held, the test's
%% time limit ends them. A refusal of another cause, which no listener's
%% taking the other family explains, is read as another socket's: one that
%% meets every pair cancels the test at its time limit in place of failing
%% it with the refusal, and one that meets some pairs alone is not covered
listen_of_one_family_test() ->
    with_ipv6_loopback(
      fun() ->
          Self = self(),
          ok = ern_rt:run_main(
                 fun() ->
                     {'Right', {Six, Four, Port}} = beside(<<"::">>, <<"0.0.0.0">>),
                     {'Right', _} = connect(<<"127.0.0.1">>, Port, 2000),
                     {'Right', FromFour} = accept(Four, 2000),
                     {'Right', _} = connect(<<"::1">>, Port, 2000),
                     {'Right', FromSix} = accept(Six, 2000),
                     Self ! {remotes, {remote(FromFour), remote(FromSix)}},
                     Self ! {six_second, ern_helpers:side(beside(<<"0.0.0.0">>, <<"::">>))}
                 end, <<"main">>, ern_helpers:quiet()),
          ?assertMatch({{'Right', {'Endpoint', <<"127.0.0.1">>, _}},
                        {'Right', {'Endpoint', <<"::1">>, _}}}, ern_waits:wait(remotes)),
          ?assertEqual('Right', ern_waits:wait(six_second))
      end).

%% Appendix E.18: `remote` writes its host as the host writes an address,
%% however it was dialed: an IPv6 address in lower case with its longest
%% run of zero groups as `::`, and an IPv4-mapped one's last 32 bits
%% dotted. Written after the code. The loopback's addresses alone are
%% dialed, so a run of zero groups shorter than another, and a zone, which
%% a link-local address alone carries, are not covered, nor a machine
%% without IPv6, where it says so
remote_writes_the_hosts_address_test() ->
    with_ipv6_loopback(
      fun() ->
          Self = self(),
          ok = ern_rt:run_main(
                 fun() ->
                     Self ! {remotes,
                             [remote_dialed(Listening, Dialed)
                              || {Listening, Dialed} <- [{<<"::1">>, <<"0:0:0:0:0:0:0:1">>},
                                                         {<<"::1">>, <<"0000::0001">>},
                                                         {<<"127.0.0.1">>,
                                                          <<"0:0:0:0:0:FFFF:7F00:1">>},
                                                         {<<"127.0.0.1">>,
                                                          <<"::FFFF:127.0.0.1">>}]]}
                 end, <<"main">>, ern_helpers:quiet()),
          ?assertEqual([<<"::1">>, <<"::1">>, <<"::ffff:127.0.0.1">>, <<"::ffff:127.0.0.1">>],
                       ern_waits:wait(remotes))
      end).

%% The host `remote` reads of a connection to a listener on Listening,
%% dialed as Dialed.
remote_dialed(Listening, Dialed) ->
    {'Right', Listener} = listen(Listening, 0),
    {'Right', Port} = port(Listener),
    {'Right', Client} = connect(Dialed, Port, 2000),
    {'Right', Server} = accept(Listener, 2000),
    {'Right', {'Endpoint', Host, Port}} = remote(Client),
    [close(Socket) || Socket <- [Client, Server]],
    close_listener(Listener),
    Host.

%% Appendix E.18: a listener on First at the port the host gives it and
%% one on Second at that port, with the port; or the refusal of the second
%% where a listener on "::" takes an IPv4 connection. A port in use where
%% none takes one was held by another socket of the machine, and a new pair
%% is taken in place of this one, which is closed.
beside(First, Second) ->
    {'Right', Listener} = listen(First, 0),
    {'Right', Port} = port(Listener),
    case listen(Second, Port) of
        {'Right', Beside} ->
            {'Right', {Listener, Beside, Port}};
        {'Left', {'Other', <<"address already in use">>}} = Refused ->
            'Unit' = close_listener(Listener),
            case takes_ipv4() of
                true -> Refused;
                false -> beside(First, Second)
            end;
        Refused ->
            Refused
    end.

%% Appendix E.18: whether a new listener on "::" takes an IPv4 connection,
%% which one of IPv6's family alone never does: the connect to its port is
%% refused, or reaches another socket that holds the port in IPv4's family,
%% and the listener's accept answers `Timeout` in the time the test gives
%% each accept, where a listener that takes it answers at once.
takes_ipv4() ->
    {'Right', Six} = listen(<<"::">>, 0),
    {'Right', Port} = port(Six),
    Taken = case connect(<<"127.0.0.1">>, Port, 2000) of
                {'Right', Socket} ->
                    Accepted = ern_helpers:side(accept(Six, 2000)),
                    'Unit' = close(Socket),
                    Accepted =:= 'Right';
                {'Left', _} ->
                    false
            end,
    'Unit' = close_listener(Six),
    Taken.

%% Appendix E.18: an IPv4 address written as IPv6's, ::ffff:127.0.0.1, is
%% one a listener of IPv6's family alone takes no connection at, which the
%% host refuses, `Invalid`. Written after the code, a regression test of
%% the place E.18 is silent on
listen_on_a_mapped_address_test() ->
    with_ipv6_loopback(
      fun() ->
          Self = self(),
          ok = ern_rt:run_main(fun() -> Self ! {listened, listen(<<"::ffff:127.0.0.1">>, 0)} end,
                               <<"main">>, ern_helpers:quiet()),
          ?assertEqual({'Left', 'Invalid'}, ern_waits:wait(listened))
      end).

%% Runs Test where the machine has IPv6's loopback, and says it did not
%% where it has none.
with_ipv6_loopback(Test) ->
    case gen_tcp:listen(0, [inet6, {ip, {0, 0, 0, 0, 0, 0, 0, 1}}]) of
        {ok, Socket} ->
            ok = gen_tcp:close(Socket),
            Test();
        {error, _} ->
            io:format(user, "  no IPv6 loopback; a listener's family was not checked.~n", [])
    end.

%% Appendix E.18: a listener reuses its address, so a server that closed
%% its side of a connection first, which leaves the port's connection
%% closing, listens on the port again at once. Written after the code, a
%% test of what E.18 now states
listen_again_while_closing_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               EntryProcess = self(),
               %% the client holds its side open until the port is listened
               %% on again, so that the server's side closes first
               Client = spawn(fun() ->
                                  EntryProcess ! {client, connect(Port, 2000)},
                                  receive done -> ok end
                              end),
               {'Right', Socket} = accept(Listener, 2000),
               receive {client, {'Right', _}} -> ok end,
               MonitorRef = erlang:monitor(process, ern_rt:process_of(Socket)),
               'Unit' = close(Socket),
               'Unit' = close_listener(Listener),
               ern_rt:timed(),
               receive {'DOWN', MonitorRef, process, _, _} -> ok end,
               ern_rt:untimed(),
               Self ! {again, ern_helpers:side(listen(Port))},
               Client ! done
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual('Right', ern_waits:wait(again)).

%% Appendix E.1, E.18: a reason of the host's that no constructor of
%% Io.Error names is answered in the host's words, a port already in use
%% "address already in use". A regression test: `Other` held the code,
%% "eaddrinuse"; it does not cover a reason the host has no words for,
%% which keeps its printed form
port_in_use_test() ->
    {ok, Taken} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Taken),
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {listened, listen(Port)} end, <<"main">>,
                         ern_helpers:quiet()),
    gen_tcp:close(Taken),
    ?assertEqual({'Left', {'Other', <<"address already in use">>}}, ern_waits:wait(listened)).

%% Appendix E.18: a listener listens on the interface its host names, the
%% loopback alone for "127.0.0.1". A regression test: `listen` took the
%% port alone and listened on every interface, 127.0.0.2's among them
listen_on_the_named_interface_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(<<"127.0.0.1">>, 0),
               {'Right', Port} = port(Listener),
               %% waits in a test's code, the host's to the deadlock detector
               Self ! {loopback, reach("127.0.0.1", Port)},
               Self ! {other, reach("127.0.0.2", Port)}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual(ok, ern_waits:wait(loopback)),
    ?assertMatch({error, _}, ern_waits:wait(other)).

reach(Host, Port) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}], 1000) of
        {ok, Socket} -> gen_tcp:close(Socket);
        Error -> Error
    end.

%% report Appendix E.18: a write answered holds no timer: one the socket
%% took before its milliseconds pass cancels the timer it armed, which the
%% socket does once its writer has told it, after the answer. A regression
%% test: the timer stayed armed and answered `Left(Timeout)` to a reply
%% already answered
answered_write_holds_no_timer_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               Pid = ern_rt:process_of(Socket),
               Write = fun() -> write(Socket, <<"x">>, 600000) end,
               %% the writer has told the socket once it waits again, and
               %% the socket has taken that once it waits with nothing left
               Told = fun() ->
                          ok = ern_waits:waiting(writer(Socket)),
                          ern_waits:until(Pid, fun() ->
                                                   erlang:process_info(
                                                     Pid, [status, message_queue_len])
                                                       =:= [{status, waiting},
                                                            {message_queue_len, 0}]
                                               end)
                      end,
               Self ! {timers, ern_waits:timers(Pid, Write, Told)}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    {Written, Armed, Canceled} = ern_waits:wait(timers),
    ?assertEqual({'Right', 'Unit'}, Written),
    ?assertEqual({1, Armed}, {length(Armed), Canceled}).

%% Appendix E.18: a write the far end holds back holds up no read of the
%% socket, and the read's time limit holds. A regression test: the
%% socket's process wrote itself, and a read behind a write that waited
%% waited with it, past its limit
write_holds_up_no_read_test_() ->
    {timeout, 60, fun write_holds_up_no_read/0}.

write_holds_up_no_read() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts and never reads
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               %% the host queues one write whole and holds the next back
               Chunk = binary:copy(<<0>>, 1024 * 1024),
               EntryProcess = erlang:self(),
               Flood = fun() ->
                           [begin write(Socket, Chunk), EntryProcess ! wrote end
                            || _ <- lists:seq(1, 64)]
                       end,
               Flooding = ern_rt:spawn(Flood, <<"flood">>),
               %% the first write is taken whole, and the flood then waits on
               %% the next, which the host holds back
               ern_rt:timed(),
               receive wrote -> ok end,
               ok = ern_waits:waiting(ern_rt:process_of(Flooding)),
               ern_rt:untimed(),
               Before = erlang:monotonic_time(millisecond),
               Read = read(Socket, 300),
               Self ! {read, Read, erlang:monotonic_time(millisecond) - Before}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    {read, Read, Took} = receive {read, _, _} = Message -> Message after 10000 -> timeout end,
    ?assertEqual({'Left', 'Timeout'}, Read),
    ?assert(Took < 2000).

%% Appendix E.18: the socket takes a write whole, whatever its size, and a
%% write behind one the host holds back waits, at most its milliseconds. A
%% regression test, written with the sentence: the 8 MB pass the kernel's
%% buffer for the socket, so the host holds the rest and the byte waits
write_taken_whole_test_() ->
    {timeout, 60, fun write_taken_whole/0}.

write_taken_whole() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts and never reads
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive done -> gen_tcp:close(Connection) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               Whole = write(Socket, binary:copy(<<0>>, 8 * 1024 * 1024)),
               Before = erlang:monotonic_time(millisecond),
               Behind = ern_rt:call_forever(Socket, fun(Reply) -> {'Write', <<1>>, 300, Reply} end),
               Self ! {written, Whole, Behind, erlang:monotonic_time(millisecond) - Before}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    {written, Whole, Behind, Took} =
        receive {written, _, _, _} = Message -> Message after 10000 -> timeout end,
    ?assertEqual({'Right', 'Unit'}, Whole),
    ?assertEqual({'Left', 'Timeout'}, Behind),
    ?assert(Took < 2000).

%% Appendix E.18: a read over TCP answers one piece, at most 9216 bytes,
%% the host's buffer for the socket, though more has arrived, and all that
%% was written is read, in order. The far end has written half a megabyte,
%% many pieces, before the first read. A regression test, written after the
%% sentence, whose probe found the host so; it does not cover a buffer of
%% another size, which nothing in Ernest sets
read_answers_a_piece_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Written = rand:bytes(512 * 1024),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = self(),
               FarEnd = spawn(fun() ->
                                  {ok, Accepted} = gen_tcp:accept(Listen),
                                  ok = gen_tcp:send(Accepted, Written),
                                  EntryProcess ! written,
                                  receive done -> gen_tcp:close(Accepted) end
                              end),
               {'Right', Socket} = connect(Port, 2000),
               %% a wait in a test's code, the host's to the deadlock detector
               receive written -> ok end,
               Self ! {pieces, pieces(Socket, byte_size(Written))},
               FarEnd ! done
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    Pieces = ern_waits:wait(pieces),
    ?assertEqual({true, ?TCP_PIECE},
                 {iolist_to_binary(Pieces) =:= Written, lists:max(sizes(Pieces))}).

%% Appendix E.18: what had arrived before the far end closed is read before
%% a read answers `Left(Closed)`. The far end writes 20000 bytes, more than
%% two pieces, which its kernel takes whole, closes, and ends, and the reads
%% begin once it has. A regression test, written after the sentence, whose
%% probe found the host so; socket_lives_until_closed holds a byte that came
%% before the close, and this the close behind more than one piece
read_before_the_close_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Written = rand:bytes(20000),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               %% watched before it accepts, so that its end is seen
               {FarEnd, FarRef} =
                   spawn_monitor(fun() ->
                                     {ok, Accepted} = gen_tcp:accept(Listen),
                                     ok = gen_tcp:send(Accepted, Written),
                                     %% nothing is left for the host to send,
                                     %% so the close goes out behind the
                                     %% bytes at once
                                     {ok, [{send_pend, 0}]} =
                                         inet:getstat(Accepted, [send_pend]),
                                     ok = gen_tcp:close(Accepted)
                                 end),
               {'Right', Socket} = connect(Port, 2000),
               %% a wait in a test's code, the host's to the deadlock detector
               receive {'DOWN', FarRef, process, FarEnd, Ended} -> Self ! {far_end, Ended} end,
               Self ! {reads, reads(Socket)}
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    ?assertEqual(normal, ern_waits:wait(far_end)),
    {Pieces, Last} = ern_waits:wait(reads),
    ?assertEqual({true, {'Left', 'Closed'}}, {iolist_to_binary(Pieces) =:= Written, Last}).

%% Appendix E.18: a connection the far end closes has closed once the host
%% learns of it, which on a socket nothing reads is as a write fails: the
%% first write after the far end's close answers `Right(Unit)`, its byte
%% lost, and once the far end's kernel has refused what came, a write
%% answers `Left(Closed)`, and so does a read. The writes are made one after
%% another until one answers otherwise, which the refusal ends. A regression
%% test, written after the sentence, whose probe found the host so; it does
%% not cover a socket over TLS, whose host takes the handshake and a piece
%% ahead of the reads
write_after_the_far_ends_close_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               %% watched before it accepts, so that its end is seen
               {FarEnd, FarRef} = spawn_monitor(fun() ->
                                                    {ok, Accepted} = gen_tcp:accept(Listen),
                                                    ok = gen_tcp:close(Accepted)
                                                end),
               {'Right', Socket} = connect(Port, 2000),
               %% a wait in a test's code, the host's to the deadlock detector
               receive {'DOWN', FarRef, process, FarEnd, Ended} -> Self ! {far_end, Ended} end,
               Writes = written_until_refused(Socket),
               Self ! {after_close, {Writes, read(Socket, 1000)}}
           end, <<"main">>, ern_helpers:quiet()),
    gen_tcp:close(Listen),
    ?assertEqual(normal, ern_waits:wait(far_end)),
    {[First | _] = Writes, Read} = ern_waits:wait(after_close),
    ?assertEqual({{'Right', 'Unit'}, {'Left', 'Closed'}, {'Left', 'Closed'}},
                 {First, lists:last(Writes), Read}).

%% The answers of one-byte writes to Socket, one after another, until one is
%% not `Right(Unit)`, which is the last.
written_until_refused(Socket) ->
    case write(Socket, <<"x">>, 1000) of
        {'Right', 'Unit'} = Taken -> [Taken | written_until_refused(Socket)];
        Answer -> [Answer]
    end.

%% Appendix E.18: a socket nobody reads holds the far end, over TCP and over
%% TLS: once the kernel's buffers at both ends are full, the far end's write
%% answers `Left(Timeout)` at its milliseconds, though no read is made, the
%% writes before it taken. A regression test, written after the sentence,
%% whose probe found the host so; it does not cover how much the buffers
%% hold, which the kernel grows
unread_socket_holds_the_far_end_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               Held = [begin
                           {Answers, _, FarEnd} = unread(Kind, Server),
                           FarEnd ! done,
                           Answers
                       end || Kind <- [plain, tls]],
               Self ! {held, Held}
           end),
    [{TakenPlain, Plain}, {TakenTls, Tls}] = ern_waits:wait(held),
    ?assertEqual({'Left', 'Timeout'}, Plain),
    ?assertEqual({'Left', 'Timeout'}, Tls),
    ?assert(TakenPlain > 0 andalso TakenTls > 0).

%% A connection over Kind whose accepted end nobody reads, and its far end, a
%% process that connects and writes until a write is not taken in HELD
%% milliseconds: the bytes the far end's writes took before it and its
%% answer, the accepted socket, and the far end, which keeps its socket until
%% told `done`.
unread(Kind, Server) ->
    {'Right', Listener} = case Kind of
                              plain -> listen(0);
                              tls -> listen_tls(0, Server)
                          end,
    {'Right', Port} = port(Listener),
    EntryProcess = self(),
    FarEnd = spawn(fun() ->
                       {'Right', Socket} =
                           case Kind of
                               plain -> connect(Port, 5000);
                               tls -> connect_tls(<<"127.0.0.1">>, Port, 'Unverified', 5000)
                           end,
                       EntryProcess ! {held, filled(Socket, binary:copy(<<0>>, 65536), 0)},
                       receive done -> ok end
                   end),
    {'Right', Accepted} = accept(Listener, 5000),
    %% a wait in a test's code, the host's to the deadlock detector
    receive {held, Answers} -> {Answers, Accepted, FarEnd} end.

%% Writes Chunk to Socket until a write is not taken in HELD milliseconds:
%% the bytes the writes before it took, counted from Taken, and its answer.
filled(Socket, Chunk, Taken) ->
    case write(Socket, Chunk, ?HELD) of
        {'Right', 'Unit'} -> filled(Socket, Chunk, Taken + byte_size(Chunk));
        Answer -> {Taken, Answer}
    end.

%% The pieces the reads of Socket answer until Count bytes are read, in order.
pieces(Socket, Count) ->
    pieces(Socket, Count, []).

pieces(_, Count, Pieces) when Count =< 0 ->
    lists:reverse(Pieces);
pieces(Socket, Count, Pieces) ->
    {'Right', Piece} = read(Socket, 5000),
    pieces(Socket, Count - byte_size(Piece), [Piece | Pieces]).

%% The pieces the reads of Socket answer until one answers a Left, in order,
%% and that Left.
reads(Socket) ->
    reads(Socket, []).

reads(Socket, Pieces) ->
    case read(Socket, 5000) of
        {'Right', Piece} -> reads(Socket, [Piece | Pieces]);
        Left -> {lists:reverse(Pieces), Left}
    end.

sizes(Pieces) ->
    [byte_size(Piece) || Piece <- Pieces].

%% report §6.9, Appendix E.18: a listener is owned by the process that
%% opened it and is killed when that process dies. A regression test of the
%% rule, before which a listener belonged to no one and lived until the
%% program ended. The owner ends once the listener is monitored:
%% ended before, it let the kill come first and the monitor read `noproc`
listener_ends_with_its_owner_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = self(),
               Owner = erlang:spawn(fun() ->
                                        EntryProcess ! {opened, listen(0)},
                                        receive stop -> ok end
                                    end),
               {'Right', Listener} = receive {opened, L} -> L end,
               MonitorRef = erlang:monitor(process, ern_rt:process_of(Listener)),
               Owner ! stop,
               Ended = fun() ->
                           receive {'DOWN', MonitorRef, _, _, ExitReason} -> ExitReason
                           after 5000 -> alive
                           end
                       end,
               Self ! {ended, Ended()}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({ern, killed}, ern_waits:wait(ended)).

%% Appendix E.18: on a socket and a listener killed with their owner, a
%% function that answers an `Either` answers `Left(Closed)`, a read, a
%% write, `remote` and `local` of the socket and `port` and an accept of
%% the listener, and a read, a write and an accept given no time answer
%% `Left(Timeout)`, as they do before the end (E.0 shape rule 8);
%% `readForever` and `acceptForever` fault with `callee had ended`, as
%% `Address.callForever` does (§6.6). A regression test of the rule, before
%% which each faulted so
ended_with_their_owner_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, FarPort} = inet:port(Listen),
    FarEnd = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               EntryProcess = self(),
               Owner = erlang:spawn(fun() ->
                                        EntryProcess ! {opened, listen(0), connect(FarPort, 2000)},
                                        receive stop -> ok end
                                    end),
               {{'Right', Listener}, {'Right', Socket}} = receive {opened, L, S} -> {L, S} end,
               MonitorRefs = [erlang:monitor(process, ern_rt:process_of(Address))
                              || Address <- [Listener, Socket]],
               Owner ! stop,
               ern_rt:timed(),
               [receive {'DOWN', MonitorRef, process, _, _} -> ok end
                || MonitorRef <- MonitorRefs],
               ern_rt:untimed(),
               Answers = [read(Socket, 1000), write(Socket, <<"x">>, 1000), remote(Socket),
                          local(Socket), port(Listener), accept(Listener, 1000)],
               GivenNoTime = [read(Socket, 0), write(Socket, <<"x">>, 0), accept(Listener, 0)],
               Downs = [begin
                            _ = ern_rt:spawn_monitored(Wait, fun(Down) -> {forever, Down} end,
                                                       <<"forever">>),
                            receive {forever, Down} -> Down end
                        end || Wait <- [fun() -> read_forever(Socket) end,
                                        fun() -> accept_forever(Listener) end]],
               Self ! {ended, {Answers, GivenNoTime, Downs}}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    {Answers, GivenNoTime, Downs} = ern_waits:wait(ended),
    ?assertEqual(lists:duplicate(6, {'Left', 'Closed'}), Answers),
    ?assertEqual(lists:duplicate(3, {'Left', 'Timeout'}), GivenNoTime),
    ?assertMatch([{'Down', _, {'Fault', <<"callee had ended">>}, _},
                  {'Down', _, {'Fault', <<"callee had ended">>}, _}], Downs).

%% report Appendix E.18: a socket closed or killed while the far end takes
%% nothing lets go of its host's socket once 5 seconds pass with nothing
%% taken, and a write it holds at its close or its kill answers
%% `Left(Closed)`. A regression test: the host's socket stayed open, with
%% its descriptor and its bytes, for as long as the far end took nothing,
%% and a write held at the close had whatever answer the writer gave before
%% the exit took it; the write the kill met faulted its caller, as a
%% callForever does (§6.6), before the rule that answers it. The 3 minutes'
%% bound is not reached here
lingering_socket_closes_test_() ->
    {timeout, 60, fun lingering_socket_closes/0}.

lingering_socket_closes() ->
    %% the far end's buffer is small, as the near end's are below, so that
    %% the hosts take far less than a megabyte and a write queued behind
    %% another is held for good: a write the host finished as the socket
    %% closed would hold nothing, and the flood's next write would fault
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {recbuf, 4096}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts twice and never reads
    FarEnd = spawn(fun() ->
                       {ok, First} = gen_tcp:accept(Listen),
                       {ok, Second} = gen_tcp:accept(Listen),
                       receive done -> gen_tcp:close(First), gen_tcp:close(Second) end
                   end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Closed} = connect(Port, 2000),
               {'Right', Killed} = connect(Port, 2000),
               HostSockets = [host_socket(Closed), host_socket(Killed)],
               [ok = inet:setopts(HostSocket, [{sndbuf, 4096}]) || HostSocket <- HostSockets],
               EntryProcess = self(),
               Chunk = binary:copy(<<0>>, 1024 * 1024),
               _ = ern_rt:spawn(fun() -> EntryProcess ! {closed_write, flooded(Closed, Chunk)} end,
                                <<"flood">>),
               _ = ern_rt:spawn(fun() -> EntryProcess ! {killed_write, flooded(Killed, Chunk)} end,
                                <<"flood">>),
               %% a write is held once the writer waits on the busy host socket
               held(Closed, byte_size(Chunk)),
               held(Killed, byte_size(Chunk)),
               Self ! {host_sockets, HostSockets},
               ok = socket_close_sent(Closed),
               ern_rt:kill(Killed),
               %% the program's end kills every process (report §8.6), so main
               %% returns only once both floods have their answers
               receive
                   {closed_write, Written} -> Self ! {closed_write, Written}
               after 5000 ->
                   Self ! {closed_write, timeout}
               end,
               receive {killed_write, Answer} -> Self ! {killed_write, Answer} end
           end, <<"main">>, ern_helpers:quiet()),
    HostSockets = ern_waits:wait(host_sockets),
    ?assertEqual(2, length(HostSockets)),
    %% the write each socket held as it ended, answered by the close and
    %% by the kill
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(closed_write)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(killed_write)),
    Gone = gone(HostSockets, 9000),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual(HostSockets, Gone).

%% Writes until one is not taken, and its answer.
flooded(Socket, Chunk) ->
    case write(Socket, Chunk) of
        {'Right', 'Unit'} -> flooded(Socket, Chunk);
        Answer -> Answer
    end.

%% report Appendix E.18: the bytes a socket has taken when it is closed
%% reach a far end that takes them late, and the connection then closes.
%% The host's own close did so too; this holds that the bound of
%% lingering_socket_closes cuts nothing off a far end that takes its bytes
closed_socket_sends_what_it_took_test_() ->
    {timeout, 60, fun closed_socket_sends_what_it_took/0}.

closed_socket_sends_what_it_took() ->
    %% small buffers at both ends, as lingering_socket_closes has them, so
    %% that the host holds bytes back at the close and a closer takes it
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {recbuf, 4096}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end takes the bytes late: once the closer the socket hands
    %% its host socket to, made as it ends, has looked twice and found
    %% nothing taken
    FarEnd = spawn(fun() ->
                       {ok, Connection} = gen_tcp:accept(Listen),
                       receive {go, Closer} -> ok end,
                       ok = ern_waits:called(Closer, {ern_tcp, lingering, 6}, 2),
                       Self ! {taken, taken(Connection, 0)}
                   end),
    Size = 4 * 1024 * 1024,
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               HostSocket = host_socket(Socket),
               ok = inet:setopts(HostSocket, [{sndbuf, 4096}]),
               Self ! {written, write(Socket, binary:copy(<<1>>, Size))},
               Self ! {host_sockets, [HostSocket]},
               SocketRef = erlang:monitor(process, ern_rt:process_of(Socket)),
               ok = socket_close_sent(Socket),
               ern_rt:timed(),
               receive {'DOWN', SocketRef, process, _, _} -> ern_rt:untimed() end,
               {connected, Closer} = erlang:port_info(HostSocket, connected),
               FarEnd ! {go, Closer}
           end, <<"main">>, ern_helpers:quiet()),
    ?assertEqual({'Right', 'Unit'}, ern_waits:wait(written)),
    HostSockets = ern_waits:wait(host_sockets),
    ?assertEqual({Size, {error, closed}}, receive {taken, Taken} -> Taken after 20000 -> none end),
    ?assertEqual(HostSockets, gone(HostSockets, 3000)),
    gen_tcp:close(Listen).

%% Every byte the far end reads, and how the connection then ends.
taken(Connection, Count) ->
    case gen_tcp:recv(Connection, 0, 10000) of
        {ok, Bytes} -> taken(Connection, Count + byte_size(Bytes));
        Ended -> {Count, Ended}
    end.

%% report Appendix E.18: however a socket over TCP ends while the host holds
%% bytes the far end has not taken, by `close`, by `kill`, by its owner's
%% death or by the program's end, a far end that takes every byte reads the
%% connection's close straight after the last of them. The closer the
%% socket made as it ended is held from before the far end reads until the
%% far end has read the close, so that nothing the closer does gives the
%% close; let go, it closes the host's socket and ends.
%%
%% Written first, a regression test: the close came as the closer looked
%% again at what the host held, a second after the last byte, so with the
%% closer held each read of the close ran out its 10 seconds
socket_closes_after_its_last_byte_test_() ->
    {timeout, 60, fun closes_after_its_last_byte/0}.

%% The four ends of a socket over TCP, each while the host holds bytes, and
%% what each gave.
closes_after_its_last_byte() ->
    Size = 4 * 1024 * 1024,
    Ends = [close, kill, owner, ending],
    ?assertEqual([{End, {Size, {error, closed}}, normal, gone} || End <- Ends],
                 [ended_while_held(End, Size) || End <- Ends]).

%% A socket over TCP, written Size bytes that the host holds, ended End:
%% what the far end then took and how its last read ended, read once the
%% closer the socket made as it ended is held; how the closer ended once let
%% go; and the host's socket, `gone` once it has closed.
ended_while_held(End, Size) ->
    Self = self(),
    {FarEnd, FarPort} =
        tcp_far_end(fun(Accepted) -> receive go -> Self ! {taken, taken(Accepted, 0)} end end),
    ok = quietly(fun() ->
                     Self ! {held, ended(End, fun() -> held_socket(none, FarPort, Size) end)}
                 end),
    {SocketPid, HostSocket} = ern_waits:wait(held),
    ok = ern_waits:ended([SocketPid]),
    Closer = closer_of(SocketPid),
    true = erlang:suspend_process(Closer),
    FarEnd ! go,
    Taken = receive {taken, FarTaken} -> FarTaken end,
    CloserRef = erlang:monitor(process, Closer),
    HostSocketRef = erlang:monitor(port, HostSocket),
    true = erlang:resume_process(Closer),
    receive {'DOWN', CloserRef, process, Closer, ExitReason} -> ok end,
    receive {'DOWN', HostSocketRef, port, HostSocket, _} -> {End, Taken, ExitReason, gone} end.

%% Main's part: the socket Held makes, by its process, and its host's
%% socket, ended End before main returns, or, for `ending`, left open, so
%% that it ends with the program, whose end main's return begins. A socket
%% ended with its owner is made by a process of its own, which ends once it
%% has the socket.
ended(ending, Held) ->
    {Socket, HostSocket} = Held(),
    {ern_rt:process_of(Socket), HostSocket};
ended(owner, Held) ->
    EntryProcess = self(),
    _ = erlang:spawn(fun() -> EntryProcess ! {owned, Held()} end),
    {Socket, HostSocket} = receive {owned, Owned} -> Owned end,
    ok = ended_by(Socket, fun() -> ok end),
    {ern_rt:process_of(Socket), HostSocket};
ended(close, Held) ->
    {Socket, HostSocket} = Held(),
    ok = ended_by(Socket, fun() -> socket_close_sent(Socket) end),
    {ern_rt:process_of(Socket), HostSocket};
ended(kill, Held) ->
    {Socket, HostSocket} = Held(),
    ok = ended_by(Socket, fun() -> ern_rt:kill(Socket) end),
    {ern_rt:process_of(Socket), HostSocket}.

%% A socket to the far end on FarPort, over TCP or over TLS with Keys, and
%% its host's socket, given a send buffer as small as the far end's receive
%% buffer, so that the hosts take far less than a megabyte, and written Size
%% bytes, which the host takes whole and holds.
held_socket(none, FarPort, Size) ->
    {'Right', Socket} = connect(FarPort, 2000),
    written(Socket, host_socket(Socket), Size);
held_socket(_, FarPort, Size) ->
    {'Right', Socket} = connect_tls(<<"127.0.0.1">>, FarPort, 'Unverified', 5000),
    written(Socket, tls_host_socket(FarPort), Size).

written(Socket, HostSocket, Size) ->
    ok = inet:setopts(HostSocket, [{sndbuf, 4096}]),
    {'Right', 'Unit'} = write(Socket, binary:copy(<<1>>, Size)),
    {Socket, HostSocket}.

%% Until the socket's writer waits inside the host's send with more than a
%% write's bytes before it in the host's queue, which the host never takes:
%% a send the host finishes at once waits in the same function, so the
%% queue is what says that this one is held. Both change only as the
%% writer runs, so they are read each time it is scheduled out.
held(Socket, Size) ->
    Writer = writer(Socket),
    HostSocket = host_socket(Socket),
    ok = ern_waits:until(Writer,
                         fun() ->
                             {ok, [{send_pend, Pending}]} = inet:getstat(HostSocket, [send_pend]),
                             case erlang:process_info(Writer, [status, current_function]) of
                                 [{status, waiting}, {current_function, Function}] ->
                                     Function =/= {ern_tcp, writing, 3} andalso Pending > Size;
                                 _ ->
                                     false
                             end
                         end).

%% The process that writes a socket's bytes (ern_tcp:writer/4), linked to
%% the socket's process, as TCP's process is.
writer(Socket) ->
    Pid = ern_rt:process_of(Socket),
    {links, Links} = erlang:process_info(Pid, links),
    [Writer] = [Linked || Linked <- Links, is_pid(Linked),
                          Linked =/= ern_rt:system_process(tcp)],
    Writer.

%% The host's socket a socket's process owns.
host_socket(Socket) ->
    Pid = ern_rt:process_of(Socket),
    [HostSocket] = [Port || Port <- erlang:ports(),
                            erlang:port_info(Port, connected) =:= {connected, Pid}],
    HostSocket.

%% The host's sockets that have closed within Ms, each watched by a
%% monitor of its port; Ms bounds a failure.
gone(HostSockets, Ms) ->
    Watched = [{HostSocket, erlang:monitor(port, HostSocket)} || HostSocket <- HostSockets],
    Deadline = erlang:monotonic_time(millisecond) + Ms,
    [HostSocket || {HostSocket, MonitorRef} <- Watched,
                   receive
                       {'DOWN', MonitorRef, port, _, _} -> true
                   after max(0, Deadline - erlang:monotonic_time(millisecond)) -> false
                   end].

%% report Appendix E.21, E.18: a socket's memory counts its writer's, which
%% holds the bytes it wrote until it runs again, where the socket's own
%% process has let them go and no line of `:processes` would show them
%% otherwise; and the socket holds no closer before it ends, which it makes
%% as it ends. A regression test, written after the code; the closer's
%% absence after the code too, which made it with the socket. It does not
%% cover a socket over TLS, whose writer is the same process.
socket_memory_counts_its_writer_test() ->
    Size = 1 bsl 20,
    Self = self(),
    ok = ern_waits:with_room(fun() ->
         quietly(
           fun() ->
               EntryProcess = self(),
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               FarEnd = spawn(fun() ->
                                  {ok, Connected} = gen_tcp:connect("127.0.0.1", Port,
                                                                    [binary, {active, false}]),
                                  {ok, _} = gen_tcp:recv(Connected, Size),
                                  EntryProcess ! taken,
                                  receive close -> gen_tcp:close(Connected) end
                              end),
               {'Right', Socket} = accept(Listener, 5000),
               _ = ern_rt:spawn(fun() ->
                                    write(Socket, binary:copy(<<0>>, Size)),
                                    EntryProcess ! written
                                end, <<"M.write:1">>),
               receive written -> ok end,
               receive taken -> ok after 5000 -> error(not_taken) end,
               Process = ern_rt:process_of(Socket),
               erlang:garbage_collect(Process),
               {binary, Own} = erlang:process_info(Process, binary),
               {monitored_by, Watching} = erlang:process_info(Process, monitored_by),
               Closers = [Pid || Pid <- Watching, is_pid(Pid),
                                 erlang:process_info(Pid, current_function)
                                     =:= {current_function, {ern_tcp, closer, 1}}],
               {'Some', {'Status', _, _, _, Memory}} = ern_rt:status(Process),
               Self ! {counted, {Own, Closers, Memory >= Size}},
               FarEnd ! close
           end)
         end),
    ?assertEqual({[], [], true}, ern_waits:wait(counted)).

%% report Appendix E.18, §10: the host's process of a connection over TLS
%% hibernates after a millisecond's wait, and so holds no bytes a write
%% brought. The socket's process and its writer are the runtime's, and hold
%% them until they run again. A regression test, written after the code; it
%% does not cover a client's connection, which `connectTls` opens with the
%% same option.
tls_connection_hibernates_test() ->
    #{server := Server} = pki(),
    Size = 1 bsl 20,
    Self = self(),
    Before = erlang:processes(),
    ok = ern_waits:with_room(fun() ->
         quietly(
           fun() ->
               EntryProcess = self(),
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               FarEnd = spawn(fun() ->
                                  {ok, Connected} = ssl:connect("127.0.0.1", Port,
                                                                [binary, {active, false},
                                                                 {verify, verify_none}]),
                                  all_taken(Connected, Size),
                                  erlang:garbage_collect(),
                                  EntryProcess ! taken,
                                  receive close -> ssl:close(Connected) end
                              end),
               {'Right', Socket} = accept(Listener, 5000),
               _ = ern_rt:spawn(fun() ->
                                    write(Socket, binary:copy(<<0>>, Size)),
                                    EntryProcess ! written
                                end, <<"M.write:1">>),
               receive written -> ok end,
               receive taken -> ok after 5000 -> error(not_taken) end,
               ern_rt:timed(),
               Freed = [ern_waits:freed(Holder, Size)
                        || Holder <- hosts_holders(Size, [FarEnd | Before])],
               Self ! {left, {[Answer || Answer <- Freed, Answer =/= ok, Answer =/= ended],
                              hosts_holders(Size, [FarEnd | Before])}},
               ern_rt:untimed(),
               FarEnd ! close
           end)
         end),
    ?assertEqual({[], []}, ern_waits:wait(left)).

%% Appendix E.18: a read over TLS answers what the records hold that one
%% piece of the connection completes: fewer than 25600 bytes, and more than
%% a record's 16384 where a piece completes a record and holds another
%% whole.
%%
%% The far end has written it all before the first read, in 32
%% pairs of a full record and one of 125 bytes, so that the host's pieces
%% are full ones. A piece that completes the full record holds the short
%% one whole unless the record ends within the short one's size on the
%% connection, some 150 bytes, of the piece's end, so nearly every pair
%% reaches it: the runs found 30 of the 32 or more.
%%
%% A regression test, written after the sentence, whose probe found the
%% host so. It does not cover the bound at its worst, 25574 bytes, which a
%% full record and one of 9190 reach only where a piece begins within 4
%% bytes of the full record's end, about once in sixty megabytes.
tls_read_answers_a_piece_test() ->
    #{server := Server} = pki(),
    Short = 125,
    Written = rand:bytes(32 * (?TLS_RECORD + Short)),
    Self = self(),
    ok = quietly(
           fun() ->
               EntryProcess = self(),
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               FarEnd = spawn(fun() ->
                                  {ok, Connected} = ssl:connect("127.0.0.1", Port,
                                                                [binary, {active, false},
                                                                 {verify, verify_none}]),
                                  %% each send is a record of its own
                                  [ok = ssl:send(Connected, Part)
                                   || Part <- parts(Written, [?TLS_RECORD, Short])],
                                  EntryProcess ! written,
                                  receive done -> ssl:close(Connected) end
                              end),
               {'Right', Socket} = accept(Listener, 5000),
               %% a wait in a test's code, the host's to the deadlock detector
               receive written -> ok end,
               Self ! {pieces, pieces(Socket, byte_size(Written))},
               FarEnd ! done
           end),
    Pieces = ern_waits:wait(pieces),
    Most = lists:max(sizes(Pieces)),
    ?assertEqual({true, true, true}, {iolist_to_binary(Pieces) =:= Written,
                                      Most < ?TLS_PIECE, Most > ?TLS_RECORD}).

%% Bytes cut into parts of the sizes given, in turn, over and over.
parts(<<>>, _) ->
    [];
parts(Bytes, [Size | Sizes]) ->
    <<Part:Size/binary, Rest/binary>> = Bytes,
    [Part | parts(Rest, Sizes ++ [Size])].

%% Appendix E.18: over TLS, what had arrived before the far end closed is
%% read before a read answers `Left(Closed)`. The far end writes 20000
%% bytes, more than two pieces, and shuts the connection, which writes the
%% close alert behind them and then the connection's end, and the reads
%% begin once the shutdown has returned; the host's close would first wait
%% for this end's answer (docs/otp_bugs.md, 10). A regression test, written
%% after the sentence, whose probe found the host so; it does not cover a
%% connection that ends with no alert
tls_read_before_the_close_test() ->
    #{server := Server} = pki(),
    Written = rand:bytes(20000),
    Self = self(),
    ok = quietly(
           fun() ->
               EntryProcess = self(),
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               FarEnd = spawn(fun() ->
                                  {ok, Connected} = ssl:connect("127.0.0.1", Port,
                                                                [binary, {active, false},
                                                                 {verify, verify_none}]),
                                  ok = ssl:send(Connected, Written),
                                  EntryProcess ! {closed, ssl:shutdown(Connected, read_write)},
                                  receive done -> ok end
                              end),
               {'Right', Socket} = accept(Listener, 5000),
               %% a wait in a test's code, the host's to the deadlock detector
               receive {closed, Closed} -> Self ! {far_end, Closed} end,
               Self ! {reads, reads(Socket)},
               FarEnd ! done
           end),
    ?assertEqual(ok, ern_waits:wait(far_end)),
    {Pieces, Last} = ern_waits:wait(reads),
    ?assertEqual({true, {'Left', 'Closed'}}, {iolist_to_binary(Pieces) =:= Written, Last}).

%% Appendix E.18: a renegotiation that a client asks for over TLS 1.2 is
%% refused, and the connection goes on as its handshake made it: the
%% host's own client over TLS 1.2 that asks, once a piece has passed, is
%% answered `renegotiation_rejected`, the listener's warning that it will
%% not renegotiate, and bytes pass both ways after it. The socket's read
%% waits as the client asks, since the host's process of the connection
%% takes what arrives for a read alone (`internal_active_n`, the known
%% issues' line). Written before the listener's option, without which the
%% host renegotiated
tls_renegotiation_refused_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               EntryProcess = self(),
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               FarEnd = spawn(fun() ->
                                  {ok, Connected} = ssl:connect("127.0.0.1", Port,
                                                                [binary, {active, false},
                                                                 {verify, verify_none},
                                                                 {versions, ['tlsv1.2']}]),
                                  ok = ssl:send(Connected, <<"before">>),
                                  receive renegotiate -> ok end,
                                  Renegotiated = ssl:renegotiate(Connected),
                                  ok = ssl:send(Connected, <<"after">>),
                                  EntryProcess ! {renegotiated, Renegotiated},
                                  EntryProcess ! {back, ssl:recv(Connected, 0, 5000)},
                                  receive done -> ssl:close(Connected) end
                              end),
               {'Right', Socket} = accept(Listener, 5000),
               Before = read(Socket, 5000),
               FarEnd ! renegotiate,
               After = read(Socket, 5000),
               Wrote = write(Socket, <<"back">>),
               %% waits in a test's code, the host's to the deadlock detector
               Renegotiated = receive {renegotiated, Answer} -> Answer end,
               Back = receive {back, Taken} -> Taken end,
               Self ! {renegotiation, {Before, Renegotiated, After, Wrote, Back}},
               FarEnd ! done
           end),
    ?assertEqual({{'Right', <<"before">>}, {error, renegotiation_rejected}, {'Right', <<"after">>},
                  {'Right', 'Unit'}, {ok, <<"back">>}},
                 ern_waits:wait(renegotiation)).

%% Appendix E.18: over TLS the host takes one piece ahead of the reads,
%% which its process of the connection holds, and no more: of a connection
%% nobody reads, once the far end is held, that process holds one piece,
%% where the host's own ssl takes a hundred ahead. A regression test,
%% written with the runtime's setting of the host's, without which it
%% fails at some 900000 bytes; it does not cover a connection a
%% `connectTls` opened, which the setting reaches alike
tls_unread_connection_holds_one_piece_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {{_, Answer}, Accepted, FarEnd} = unread(tls, Server),
               Connection = tls_connection_of(ern_rt:process_of(Accepted)),
               %% what the process holds, and not what it let go
               erlang:garbage_collect(Connection),
               Self ! {held, {Answer, bytes_held(Connection)}},
               FarEnd ! done
           end),
    %% one piece is fewer than 25600 bytes of the records' content, beside
    %% the 9216 of the connection it came in, which may begin the next
    %% record; twice the two leaves room for what the handshake left, the
    %% certificates and the keys, and a hundred pieces ahead are up to
    %% 921600 bytes of the connection
    Bound = 2 * (?TLS_PIECE + ?TCP_PIECE),
    ?assertMatch({{'Left', 'Timeout'}, Held} when Held < Bound, ern_waits:wait(held)).

%% The host's ssl process of the connection whose socket Owner owns to the
%% host, which watches its owner.
-spec tls_connection_of(pid()) -> pid().
tls_connection_of(Owner) ->
    {monitored_by, Watching} = erlang:process_info(Owner, monitored_by),
    [Connection] = [Pid || Pid <- Watching, is_pid(Pid),
                           {ssl_gen_statem, init, _} <- [proc_lib:initial_call(Pid)]],
    Connection.

%% The bytes of the binaries Pid references, each counted once.
bytes_held(Pid) ->
    {binary, Binaries} = erlang:process_info(Pid, binary),
    lists:sum([Size || {_, Size, _} <- lists:ukeysort(1, Binaries)]).

all_taken(_, Left) when Left =< 0 ->
    ok;
all_taken(Socket, Left) ->
    {ok, Bytes} = ssl:recv(Socket, 0),
    all_taken(Socket, Left - byte_size(Bytes)).

%% The processes the host started since Before, as OTP starts one, that
%% reference a binary of Size bytes or more.
hosts_holders(Size, Before) ->
    [Pid || Pid <- erlang:processes() -- Before,
            erlang:process_info(Pid, initial_call) =:= {initial_call, {proc_lib, init_p, 5}},
            ern_waits:references(Pid, Size) =:= true].

%% report §8.6: a process that faults once the entry process has died,
%% where no subscriber waits, at what the program's end ended, dies with
%% the reason ProgramEnd as every live process does, and no fault of it is
%% reported (§11.2). A regression test: an accept waiting on a listener
%% its owner, the entry process, took with it as it returned, faulted with
%% `callee had ended` and was reported before the program's end stopped
%% it, as examples/shout.ern showed now and then. A hundred acceptors, in
%% five runs, widen the old window until it is met; a fault the program's
%% end did not cause, come in the same instant, is not covered
fault_at_the_programs_end_not_reported_test_() ->
    {timeout, 60, fun fault_at_the_programs_end_not_reported/0}.

fault_at_the_programs_end_not_reported() ->
    [program_ended_under_accepts() || _ <- lists:seq(1, 5)],
    ?assertEqual([], reported([])).

%% A program whose entry process returns while a hundred processes wait in
%% an accept on its listeners.
program_ended_under_accepts() ->
    Self = self(),
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    ok = ern_rt:run_main(
           fun() ->
               Acceptors = [begin
                                {'Right', Listener} = listen(0),
                                ern_rt:spawn(fun() -> accept(Listener, 60000) end,
                                             <<"acceptor">>)
                            end || _ <- lists:seq(1, 100)],
               %% each acceptor waits in its accept before main returns
               [ok = ern_waits:waiting(ern_rt:process_of(Acceptor)) || Acceptor <- Acceptors]
           end, <<"main">>, #{faults => Reporter}).

%% report §8.6, §6.9: a restarting process that faults once the entry
%% process has died, where no subscriber waits, does not restart: it dies
%% with the reason ProgramEnd as every live process does, and no fault of
%% it is reported (§11.2). A regression test, written after the code: an
%% accept under `restarting` on a listener its owner, the entry process,
%% took with it as it returned, faulted, was reported as `faulted,
%% restarted` and ran again, faulting and restarting until the program's
%% end stopped it. A hundred acceptors in five runs, as above; each run of
%% an acceptor's function is counted, so that a restart shows though its
%% report did not reach the reporter
restarting_at_the_programs_end_not_restarted_test_() ->
    {timeout, 60, fun restarting_at_the_programs_end_not_restarted/0}.

restarting_at_the_programs_end_not_restarted() ->
    [program_ended_under_restarting_accepts() || _ <- lists:seq(1, 5)],
    ?assertEqual([], reported([])),
    ?assertEqual(5 * 100, runs(0)).

%% A program whose entry process returns while a hundred processes, each
%% under `restarting(Unlimited, ...)`, wait in an accept on its listeners;
%% each run of an acceptor's function sends `ran`.
program_ended_under_restarting_accepts() ->
    Self = self(),
    Reporter = fun(Report, _Peer) -> Self ! {reported, Report} end,
    ok = ern_rt:run_main(
           fun() ->
               Acceptors = [begin
                                {'Right', Listener} = listen(0),
                                Accept = fun() ->
                                             Self ! ran,
                                             accept(Listener, 60000)
                                         end,
                                ern_rt:spawn(ern_rt:restarting('Unlimited', Accept),
                                             <<"acceptor">>)
                            end || _ <- lists:seq(1, 100)],
               %% each acceptor waits in its accept before main returns
               [ok = ern_waits:waiting(ern_rt:process_of(Acceptor)) || Acceptor <- Acceptors]
           end, <<"main">>, #{faults => Reporter}).

%% The runs the acceptors' functions began, counted from Count.
runs(Count) ->
    receive ran -> runs(Count + 1) after 0 -> Count end.

%% The fault reports a run gave, in order.
reported(Acc) ->
    receive {reported, Report} -> reported([Report | Acc]) after 0 -> lists:reverse(Acc) end.

%% report Appendix E.18: a listener and a socket over TLS take what a
%% listener and a socket over TCP take, `accept`, `port`, `read`, `write`,
%% `remote`, `local` and `close`, the far end's certificate checked against
%% the authority's file and for naming the host connected to, by its name
%% and by its address, the chain after the server's certificate in its
%% file; a read, `remote` and `local` after the far end's close answer
%% `Left(Closed)`. The server names its ends before it writes, since the
%% client closes once it has read, and the ends of a closed connection are
%% asserted after the close. Written after the code, a regression test; it
%% does not cover a chain of more than one intermediate
tls_both_ways_test() ->
    #{ca := Ca, server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               Self ! {port, Port},
               EntryProcess = self(),
               Client = spawn(fun() ->
                                  {'Right', Socket} = connect_tls(<<"localhost">>, Port,
                                                                  verified(Ca), 5000),
                                  Self ! {client_wrote, write(Socket, <<"ping">>)},
                                  Self ! {client_read, read(Socket, 5000)},
                                  Self ! {client_ends, {remote(Socket), local(Socket)}},
                                  'Unit' = close(Socket),
                                  EntryProcess ! closed,
                                  receive done -> ok end
                              end),
               {'Right', Accepted} = accept(Listener, 5000),
               Self ! {server_read, read(Accepted, 5000)},
               Self ! {server_ends, {remote(Accepted), local(Accepted)}},
               Self ! {server_wrote, write(Accepted, <<"pong">>)},
               receive closed -> ok end,
               Self ! {after_close, read(Accepted, 5000)},
               Self ! {ends_after_close, {remote(Accepted), local(Accepted)}},
               %% by its address, which the certificate names too
               ByAddress = spawn(fun() ->
                                     Connected = connect_tls(<<"127.0.0.1">>, Port, verified(Ca),
                                                             5000),
                                     EntryProcess ! {by_address, ern_helpers:side(Connected)},
                                     receive done -> ok end
                                 end),
               {'Right', _} = accept(Listener, 5000),
               receive {by_address, _} = Connected -> Self ! Connected end,
               [Connector ! done || Connector <- [Client, ByAddress]]
           end),
    Port = ern_waits:wait(port),
    ?assertEqual({'Right', 'Unit'}, ern_waits:wait(client_wrote)),
    ?assertEqual({'Right', <<"ping">>}, ern_waits:wait(server_read)),
    ?assertEqual({'Right', 'Unit'}, ern_waits:wait(server_wrote)),
    ?assertEqual({'Right', <<"pong">>}, ern_waits:wait(client_read)),
    {{'Right', {'Endpoint', <<"127.0.0.1">>, Port}},
     {'Right', {'Endpoint', <<"127.0.0.1">>, ClientPort}}} = ern_waits:wait(client_ends),
    ?assertMatch({{'Right', {'Endpoint', <<"127.0.0.1">>, ClientPort}},
                  {'Right', {'Endpoint', <<"127.0.0.1">>, Port}}}, ern_waits:wait(server_ends)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(after_close)),
    ?assertEqual({{'Left', 'Closed'}, {'Left', 'Closed'}}, ern_waits:wait(ends_after_close)),
    ?assertEqual('Right', ern_waits:wait(by_address)).

%% report Appendix E.18: with `Unverified` the far end's certificate is not
%% checked, so a certificate no authority of the client's signed, naming
%% another host, is taken; once the far end has closed, a read answers what
%% came before and then `Left(Closed)`, and a write `Left(Closed)`. Written
%% after the code, a regression test
tls_unverified_test() ->
    #{elsewhere := Elsewhere} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Elsewhere),
               {'Right', Port} = port(Listener),
               EntryProcess = self(),
               _ = spawn(fun() ->
                             {'Right', Socket} = connect_tls(<<"localhost">>, Port,
                                                             'Unverified', 5000),
                             EntryProcess ! connected,
                             Read = read(Socket, 5000),
                             Self ! {reads, [Read, read(Socket, 5000)]},
                             Self ! {wrote, write(Socket, <<"late">>)},
                             EntryProcess ! done
                         end),
               {'Right', Accepted} = accept(Listener, 5000),
               receive connected -> ok end,
               {'Right', 'Unit'} = write(Accepted, <<"bye">>),
               'Unit' = close(Accepted),
               receive done -> ok end
           end),
    ?assertEqual([{'Right', <<"bye">>}, {'Left', 'Closed'}], ern_waits:wait(reads)),
    ?assertEqual({'Left', 'Closed'}, ern_waits:wait(wrote)).

%% report Appendix E.18: `Verified` refuses a far end whose certificate
%% does not name the host connected to, by its name or by its address,
%% with `Left(Other(text))`, the host's reason, as the handshake fails;
%% `Unverified` takes it. Written after the code, a regression test
tls_verified_checks_the_name_test() ->
    #{ca := Ca, elsewhere := Elsewhere} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Elsewhere),
               {'Right', Port} = port(Listener),
               Acceptor = spawn(fun() -> accepting(Listener, 3) end),
               Self ! {by_name, connect_tls(<<"localhost">>, Port, verified(Ca), 5000)},
               Self ! {by_address, connect_tls(<<"127.0.0.1">>, Port, verified(Ca), 5000)},
               Self ! {unverified,
                       ern_helpers:side(connect_tls(<<"localhost">>, Port, 'Unverified', 5000))},
               Acceptor ! done
           end),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(by_name)),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(by_address)),
    ?assertEqual('Right', ern_waits:wait(unverified)).

%% report Appendix E.18: `Verified` takes a certificate that names the host
%% through a wildcard, `*.example.test` for `www.example.test`, as a
%% browser does, and refuses it for a host outside it, `other.test`. Both
%% names stand for the loopback in the host's own table while the test
%% runs. Written after the code, a regression test; it does not cover the
%% forms of wildcard the host's match for HTTPS refuses
tls_verified_takes_a_wildcard_test() ->
    #{ca := Ca, wildcard := Wildcard} = pki(),
    Lookup = inet_db:res_option(lookup),
    ok = inet_db:add_host({127, 0, 0, 1}, ["www.example.test", "other.test"]),
    ok = inet_db:set_lookup([file, native]),
    Self = self(),
    try
        ok = quietly(
               fun() ->
                   {'Right', Listener} = listen_tls(0, Wildcard),
                   {'Right', Port} = port(Listener),
                   Acceptor = spawn(fun() -> accepting(Listener, 2) end),
                   Self ! {named, ern_helpers:side(connect_tls(<<"www.example.test">>, Port,
                                                               verified(Ca), 5000))},
                   Self ! {outside, connect_tls(<<"other.test">>, Port, verified(Ca), 5000)},
                   Acceptor ! done
               end)
    after
        inet_db:del_host({127, 0, 0, 1}),
        inet_db:set_lookup(Lookup)
    end,
    ?assertEqual('Right', ern_waits:wait(named)),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(outside)).

%% report Appendix E.18: a client whose authority did not sign the server's
%% certificate fails its handshake, `connectTls` answering
%% `Left(Other(text))`; the server's socket, which `accept` answered before
%% its handshake, answers its first read with the handshake's failure,
%% `Left(Other(text))`, and the next `Left(Closed)`. Each text is the
%% host's without the line feed that ends ssl's. The entry process waits
%% for the client's answer before it returns, since the run's end kills
%% the client's socket, and a connect still under way would fault with
%% that instead. Written after the code, a regression test
tls_unknown_authority_test() ->
    #{other_ca := OtherCa, server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               EntryProcess = self(),
               _ = spawn(fun() ->
                             Self ! {client, connect_tls(<<"localhost">>, Port,
                                                         verified(OtherCa), 5000)},
                             EntryProcess ! client_answered
                         end),
               {'Right', Accepted} = accept(Listener, 5000),
               Read = read(Accepted, 5000),
               Self ! {reads, [Read, read(Accepted, 5000)]},
               receive client_answered -> ok end
           end),
    {'Left', {'Other', ClientText}} = ern_waits:wait(client),
    [{'Left', {'Other', ServerText}}, {'Left', 'Closed'}] = ern_waits:wait(reads),
    ?assertEqual([false, false], [lists:member(binary:last(Text), " \t\r\n")
                                  || Text <- [ClientText, ServerText]]).

%% report Appendix E.18: a client that sends a TLS listener what is no TLS
%% fails the handshake of the socket `accept` answered: the read and the
%% write waiting for it answer `Left(Other(text))`, the host's reason, and
%% a read and a write after `Left(Closed)`. The garbage is sent once both
%% wait on the socket. Written after the code, a regression test
tls_handshake_fails_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               %% a wait in the host's code, the deadlock detector's foreign code
               {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               {'Right', Accepted} = accept(Listener, 5000),
               EntryProcess = self(),
               Reader = ern_rt:spawn(fun() -> EntryProcess ! {read, read(Accepted, 5000)} end,
                                     <<"reader">>),
               Writer = ern_rt:spawn(fun() -> EntryProcess ! {wrote, write(Accepted, <<"x">>)} end,
                                     <<"writer">>),
               [ok = ern_waits:waiting(ern_rt:process_of(Caller)) || Caller <- [Reader, Writer]],
               %% the socket has taken both before the handshake fails
               SocketPid = ern_rt:process_of(Accepted),
               ok = ern_waits:until(SocketPid,
                                    fun() ->
                                        erlang:process_info(SocketPid, message_queue_len)
                                            =:= {message_queue_len, 0}
                                    end),
               ok = gen_tcp:send(Client, <<"GET / HTTP/1.0\r\n\r\n">>),
               receive {read, _} = Read -> Self ! Read end,
               receive {wrote, _} = Wrote -> Self ! Wrote end,
               Self ! {later, [read(Accepted, 5000), write(Accepted, <<"y">>)]},
               gen_tcp:close(Client)
           end),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(read)),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(wrote)),
    ?assertEqual([{'Left', 'Closed'}, {'Left', 'Closed'}], ern_waits:wait(later)).

%% report Appendix E.18: a socket over TLS that `accept` answered, closed
%% while its handshake runs, answers the read that waits for the handshake
%% `Left(Closed)`, ends, and lets go of its connection once each process
%% it made has ended: a far end that has sent nothing reads the close, and
%% one paused after the server's hello over TLS 1.2 or over TLS 1.3 is let
%% go after. A regression test, written after the code, which covers TLS 1.3
%% since the socket ends there without asking the host
tls_closed_while_shaking_hands_test_() ->
    {timeout, 60,
     fun() ->
         #{server := Server} = pki(),
         Cases = [waiting, 'tlsv1.2', 'tlsv1.3'],
         ?assertEqual([{Case, {'Left', 'Closed'}, {ern, closed}, gone,
                        case Case of waiting -> {error, closed}; _ -> let_go end}
                       || Case <- Cases],
                      [closed_while_shaking_hands(Server, Case) || Case <- Cases])
     end}.

%% A socket over TLS that a listener with Server's certificate accepted,
%% closed as a read waits for its handshake, which the far end has not
%% begun or has paused after the server's hello over the version Case: the
%% read's answer, the socket's end, its host socket, `gone` once it has
%% closed, waited for once the far end has answered the close and each
%% process the socket made has ended, and the far end's end, read or let
%% go.
closed_while_shaking_hands(Server, Case) ->
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               %% waits in the host's code, the deadlock detector's foreign code
               {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               {'Right', Socket} = accept(Listener, 5000),
               {ok, ClientName} = inet:sockname(Client),
               [HostSocket] = [Q || Q <- erlang:ports(),
                                    erlang:port_info(Q, name) =:= {name, "tcp_inet"},
                                    inet:peername(Q) =:= {ok, ClientName}],
               EntryProcess = self(),
               Reader = ern_rt:spawn(fun() -> EntryProcess ! {read, read(Socket, 20000)} end,
                                     <<"reader">>),
               ok = ern_waits:waiting(ern_rt:process_of(Reader)),
               FarEnd = shaking_hands(Case, Client),
               SocketPid = ern_rt:process_of(Socket),
               %% the socket has taken the read before the close
               ok = ern_waits:until(SocketPid,
                                    fun() ->
                                        erlang:process_info(SocketPid, message_queue_len)
                                            =:= {message_queue_len, 0}
                                    end),
               SocketRef = erlang:monitor(process, SocketPid),
               HostSocketRef = erlang:monitor(port, HostSocket),
               'Unit' = close(Socket),
               Ended = receive {'DOWN', SocketRef, process, _, ExitReason} -> ExitReason end,
               Read = receive {read, Answer} -> Answer end,
               Made = [Pid || Pid <- erlang:processes(),
                              erlang:process_info(Pid, parent) =:= {parent, SocketPid}],
               FarEnded = far_closed(FarEnd),
               ok = ern_waits:ended(Made),
               Gone = receive {'DOWN', HostSocketRef, port, HostSocket, _} -> gone end,
               Self ! {closed, {Case, Read, Ended, Gone, FarEnded}}
           end),
    ern_waits:wait(closed).

%% The far end of a handshake on Client: none begun, or one paused after
%% the server's hello over Version.
shaking_hands(waiting, Client) ->
    Client;
shaking_hands(Version, Client) ->
    {ok, Paused, _} = ssl:connect(Client, [binary, {active, false}, {verify, verify_none},
                                           {versions, [Version]},
                                           {server_name_indication, disable},
                                           {handshake, hello}], 5000),
    Paused.

%% How the far end's connection ended, read and then closed where it began
%% no handshake, and let go where it paused one, by the host's cancel of a
%% paused handshake, since its close waits for the handshake to go on.
far_closed(Client) when is_port(Client) ->
    {_, Ended} = taken(Client, 0),
    ok = gen_tcp:close(Client),
    Ended;
far_closed(Paused) ->
    _ = ssl:handshake_cancel(Paused),
    let_go.

%% report Appendix E.18: the handshake runs in the socket's own process
%% once `accept` has answered, so a client that connects and does not
%% shake hands holds up no other: the next client's handshake completes
%% while the first waits, and a read that times out on the first, waiting
%% for its handshake, leaves the handshake under way, which completes once
%% the client shakes hands. Written after the code, a regression test
tls_slow_handshake_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               %% a wait in the host's code, the deadlock detector's foreign code
               {ok, Slow} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               {'Right', First} = accept(Listener, 5000),
               EntryProcess = self(),
               _ = spawn(fun() ->
                             {'Right', Fast} = connect_tls(<<"localhost">>, Port,
                                                           'Unverified', 5000),
                             {'Right', 'Unit'} = write(Fast, <<"fast">>),
                             EntryProcess ! wrote,
                             receive done -> ok end
                         end),
               {'Right', Second} = accept(Listener, 5000),
               Self ! {second, read(Second, 5000)},
               receive wrote -> ok end,
               Self ! {first, read(First, 50)},
               %% the slow client shakes hands at last, over its connection
               {ok, Upgraded} = ssl:connect(Slow, [binary, {active, false},
                                                   {verify, verify_none}], 5000),
               ok = ssl:send(Upgraded, <<"slow">>),
               Self ! {first_later, read(First, 5000)},
               ssl:close(Upgraded)
           end),
    ?assertEqual({'Right', <<"fast">>}, ern_waits:wait(second)),
    ?assertEqual({'Left', 'Timeout'}, ern_waits:wait(first)),
    ?assertEqual({'Right', <<"slow">>}, ern_waits:wait(first_later)).

%% Appendix E.18: a `readForever` that is the first read of a socket over
%% TLS that `acceptForever` answered waits for the handshake without a
%% limit, and answers what the far end sends once it has shaken hands. The
%% far end connects over TCP, and shakes hands once the socket watches its
%% reader. Written with the requests
tls_read_forever_waits_for_the_handshake_test() ->
    #{server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               %% waits in the host's code, the deadlock detector's foreign code
               {ok, Slow} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               {'Right', Socket} = accept_forever(Listener),
               EntryProcess = self(),
               Reader = ern_rt:spawn(fun() -> EntryProcess ! {read, read_forever(Socket)} end,
                                     <<"reader">>),
               ok = ern_waits:watching(ern_rt:process_of(Socket), ern_rt:process_of(Reader)),
               {ok, Upgraded} = ssl:connect(Slow, [binary, {active, false},
                                                   {verify, verify_none}], 5000),
               ok = ssl:send(Upgraded, <<"slow">>),
               Self ! {read, receive {read, Read} -> Read end},
               ssl:close(Upgraded)
           end),
    ?assertEqual({'Right', <<"slow">>}, ern_waits:wait(read)).

%% report Appendix E.1, E.17, E.18: `listenTls` answers a certificate or
%% key file it cannot read or refuses `Left(Other(text))`, the file's name
%% and what is wrong on one line: for one it cannot read, what `Fs`
%% answers for the path, `NotFound` for one missing, `Denied` for one it
%% may not read and `NotAFile` for a directory; for one the host refuses,
%% `not one key` for a file with no key in it and `no certificate` for one
%% with no certificate; and `Left(Invalid)` for a path that holds U+0000.
%%
%% A regression test: the host's term stood in `Other(text)`, pretty-printed
%% over two lines, and a missing file was not `NotFound`, and a directory
%% was the host's words; and, written after the code, a file it could not
%% read answered `Fs`'s answer bare, as a port refused answers, naming no
%% file. It does not cover a key that does not match its certificate, which
%% the host takes as it listens and refuses at each handshake, nor a key of
%% a kind the host does not take, `not a key`
listen_tls_refused_test() ->
    #{dir := Dir, server := {Certificate, Key}} = pki(),
    Unreadable = filename:join(Dir, "unreadable.key"),
    {ok, _} = file:copy(Key, Unreadable),
    ok = file:change_mode(Unreadable, 8#000),
    Garbage = filename:join(Dir, "garbage.key"),
    ok = file:write_file(Garbage, <<"no key here\n">>),
    Empty = filename:join(Dir, "empty.pem"),
    ok = file:write_file(Empty, <<>>),
    Self = self(),
    ok = quietly(
           fun() ->
               Self ! {listened,
                       [listen_tls(0, {Certificate, Missing})
                        || Missing <- [filename:join(Dir, "missing.key"), Unreadable, Garbage]]
                       ++ [listen_tls(0, {filename:join(Dir, "missing.pem"), Key}),
                           listen_tls(0, {Empty, Key}),
                           listen_tls(0, {Certificate, Key ++ [0]}),
                           listen_tls(0, {Dir, Key}),
                           listen_tls(0, {Certificate, Dir})]}
           end),
    Refused = fun(File, What) -> {'Left', {'Other', list_to_binary([File, ": ", What])}} end,
    ?assertEqual([Refused(filename:join(Dir, "missing.key"), "NotFound"),
                  Refused(Unreadable, "Denied"),
                  Refused(Garbage, "not one key"),
                  Refused(filename:join(Dir, "missing.pem"), "NotFound"),
                  Refused(Empty, "no certificate"),
                  {'Left', 'Invalid'},
                  Refused(Dir, "NotAFile"),
                  Refused(Dir, "NotAFile")],
                 ern_waits:wait(listened)).

%% report Appendix E.17, E.18: `connectTls` to a port where nothing listens
%% answers `Left(Refused)`, as `connect` does; to one whose far end does not
%% shake hands within its milliseconds `Left(Timeout)`; a file of
%% certificates whose path holds U+0000 `Left(Invalid)`; and one that is
%% missing, a directory and one that holds no certificate
%% `Left(Other(text))`, as `listenTls`'s files answer, `NotFound`,
%% `NotAFile` and `no certificate` after the file's name, read before the
%% dial, so that each answers so towards the port where nothing listens too.
%% Written after the code, a regression test; the file read before the dial,
%% its directory, its want of a certificate and its name in the answer,
%% after the code too: the file was the host's to read as it shook hands, so
%% a closed port answered `Refused`
connect_tls_refused_test() ->
    #{ca := Ca, dir := Dir} = pki(),
    NoCertificate = filename:join(Dir, "no_certificate.pem"),
    ok = file:write_file(NoCertificate, <<"no certificate here\n">>),
    Missing = filename:join(Dir, "missing_ca.pem"),
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Closed} = inet:port(Held),
    ok = gen_tcp:close(Held),
    %% a far end that accepts and says nothing
    {ok, Silent} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, SilentPort} = inet:port(Silent),
    Self = self(),
    ok = quietly(
           fun() ->
               Self ! {refused, connect_tls(<<"127.0.0.1">>, Closed, verified(Ca), 2000)},
               Self ! {timeout, connect_tls(<<"127.0.0.1">>, SilentPort, 'Unverified', 100)},
               Self ! {invalid, connect_tls(<<"127.0.0.1">>, SilentPort,
                                            verified(Ca ++ [0]), 2000)},
               Self ! {files, [connect_tls(<<"127.0.0.1">>, Port, verified(File), 2000)
                               || Port <- [SilentPort, Closed],
                                  File <- [Missing, Dir, NoCertificate]]}
           end),
    gen_tcp:close(Silent),
    ?assertEqual({'Left', 'Refused'}, ern_waits:wait(refused)),
    ?assertEqual({'Left', 'Timeout'}, ern_waits:wait(timeout)),
    ?assertEqual({'Left', 'Invalid'}, ern_waits:wait(invalid)),
    Refused = [{'Left', {'Other', list_to_binary([File, ": ", What])}}
               || {File, What} <- [{Missing, "NotFound"}, {Dir, "NotAFile"},
                                   {NoCertificate, "no certificate"}]],
    ?assertEqual(Refused ++ Refused, ern_waits:wait(files)).

%% report Appendix E.18: `Verified` takes a far end whose own certificate
%% the file holds, self-signed, a CA or not, as it takes one whose chain
%% leads to a certificate the file holds; the host alone refuses every
%% self-signed far end before it looks in the file. The name is checked
%% still, and a self-signed certificate the file does not hold is
%% refused. Written with the code, a regression test
tls_verified_takes_a_held_certificate_test() ->
    #{ca := Ca, self_signed := {Held, _} = SelfSigned, self_signed_leaf := {HeldLeaf, _} = Leaf,
      self_signed_elsewhere := {Elsewhere, _} = SelfElsewhere} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               Self ! {held,
                       ern_helpers:side(connected(SelfSigned, <<"localhost">>, verified(Held)))},
               Self ! {by_address,
                       ern_helpers:side(connected(SelfSigned, <<"127.0.0.1">>, verified(Held)))},
               Self ! {leaf,
                       ern_helpers:side(connected(Leaf, <<"localhost">>, verified(HeldLeaf)))},
               Self ! {not_held, connected(SelfSigned, <<"localhost">>, verified(Ca))},
               Self ! {elsewhere, connected(SelfElsewhere, <<"localhost">>, verified(Elsewhere))}
           end),
    ?assertEqual('Right', ern_waits:wait(held)),
    ?assertEqual('Right', ern_waits:wait(by_address)),
    ?assertEqual('Right', ern_waits:wait(leaf)),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(not_held)),
    ?assertMatch({'Left', {'Other', _}}, ern_waits:wait(elsewhere)).

%% report Appendix E.18: `Verified` takes a far end whose own certificate
%% the file holds, as sent, where an authority the file lacks signed it:
%% sent alone, and sent with its chain after it, which the file need not
%% hold, the chain with its authority and without it; and one whose chain
%% leads to a certificate of the file that is no authority, the
%% intermediate the far end sends, with the authority and without it. The
%% file of the authority takes the chain with the authority too. The name
%% is checked still, of a certificate sent alone and of one sent with its
%% chain, with its authority and without it.
%%
%% A regression test, written after the code (the log's *The Release
%% Review Before 0.9.0*): the host refused each before it looked in the
%% file, and a far end was taken by its own certificate only where it was
%% self-signed. A chain of more than one
%% intermediate is not covered.
tls_verified_takes_a_pinned_certificate_test() ->
    #{dir := Dir, ca := Ca, server := {Chain, _} = Server,
      server_alone := {Alone, _} = ServerAlone, elsewhere := {ElsewhereChain, _} = Elsewhere,
      elsewhere_alone := {ElsewhereLone, _} = ElsewhereAlone} = pki(),
    Leaf = certificate(Dir, Chain, 1),
    Intermediate = certificate(Dir, Chain, 2),
    ElsewhereLeaf = certificate(Dir, ElsewhereChain, 1),
    Rooted = with_authority(Dir, Server, Ca),
    ElsewhereRooted = with_authority(Dir, Elsewhere, Ca),
    Self = self(),
    ok = quietly(
           fun() ->
               Self ! {taken,
                       [ern_helpers:side(connected(ServerAlone, <<"localhost">>, verified(Alone)))
                        | [ern_helpers:side(connected(Sent, <<"localhost">>, verified(File)))
                           || Sent <- [Server, Rooted], File <- [Leaf, Intermediate]]]
                       ++ [ern_helpers:side(connected(Rooted, <<"localhost">>, verified(Ca)))]},
               Self ! {refused, [connected(ElsewhereAlone, <<"localhost">>,
                                           verified(ElsewhereLone))
                                 | [connected(Sent, <<"localhost">>, verified(ElsewhereLeaf))
                                    || Sent <- [Elsewhere, ElsewhereRooted]]]}
           end),
    ?assertEqual(lists:duplicate(6, 'Right'), ern_waits:wait(taken)),
    ?assertMatch([{'Left', {'Other', _}}, {'Left', {'Other', _}}, {'Left', {'Other', _}}],
                 ern_waits:wait(refused)).

%% A file of its own holding the Nth certificate of File, in PEM.
certificate(Dir, File, N) ->
    {ok, Pem} = file:read_file(File),
    Name = filename:basename(File, ".pem") ++ "_" ++ integer_to_list(N) ++ ".pem",
    pem_entries(Dir, Name, [lists:nth(N, public_key:pem_decode(Pem))]).

%% A server's files whose chain holds the authority's certificate after its
%% intermediate, which the far end then sends too.
with_authority(Dir, {Chain, Key}, Authority) ->
    {ok, Pem} = file:read_file(Chain),
    {ok, AuthorityPem} = file:read_file(Authority),
    Name = filename:basename(Chain, ".pem") ++ "_with_authority.pem",
    {pem_entries(Dir, Name, public_key:pem_decode(<<Pem/binary, AuthorityPem/binary>>)), Key}.

%% A connectTls to a listener over the server's files, which accepts once,
%% and what it answers.
connected(Server, Host, Verification) ->
    {'Right', Listener} = listen_tls(0, Server),
    {'Right', Port} = port(Listener),
    Acceptor = spawn(fun() -> accepting(Listener, 1) end),
    Answer = connect_tls(Host, Port, Verification, 5000),
    Acceptor ! done,
    Answer.

%% report Appendix E.18: a listener holds the largest backlog the host
%% keeps, 65535, which the kernel lowers to its own limit, Linux's
%% `net.core.somaxconn`, over TCP and over TLS alike. The host does not
%% answer its backlog to `inet:getopts`, so the kernel's table is read,
%% `ss`'s Send-Q of the listening socket, where `ss` is installed. Written
%% after the code, a regression test, first for the host's 5 and now for
%% its largest, the backlog a server such as ernest-httpd asks for; it does
%% not cover how many connections the kernel holds against the backlog,
%% which Linux makes one more, nor a reset past it
listen_backlog_test() ->
    case os:find_executable("ss") of
        false ->
            io:format(user, "  ss not installed; the listeners' backlog was not checked.~n", []);
        Ss ->
            #{server := Server} = pki(),
            Self = self(),
            ok = quietly(
                   fun() ->
                       {'Right', Plain} = listen(0),
                       {'Right', Tls} = listen_tls(0, Server),
                       Self ! {backlogs, [backlog(Ss, Port)
                                          || Listener <- [Plain, Tls],
                                             {'Right', Port} <- [port(Listener)]]}
                   end),
            Largest = min(65535, system_limit()),
            ?assertEqual([Largest, Largest], ern_waits:wait(backlogs))
    end.

%% The system's own limit on a backlog, Linux's, read where the kernel
%% gives it.
system_limit() ->
    {ok, Text} = file:read_file("/proc/sys/net/core/somaxconn"),
    binary_to_integer(string:trim(Text)).

%% The backlog of the listening socket on Port, as the kernel's table
%% holds it, read by Ss.
backlog(Ss, Port) ->
    Line = os:cmd(Ss ++ " -Hltn 'sport = :" ++ integer_to_list(Port) ++ "'"),
    [_State, _Waiting, Backlog | _] = string:lexemes(Line, " \n"),
    list_to_integer(Backlog).

%% report Appendix E.18: the host's ssl is started at a launch's first
%% request over TLS where nothing has started it. Written after the code,
%% a regression test; it does not cover a start that fails
tls_starts_ssl_test() ->
    #{server := Server} = pki(),
    _ = quiet_host(fun() -> application:stop(ssl) end),
    false = lists:keymember(ssl, 1, application:which_applications()),
    Self = self(),
    ok = quietly(fun() -> Self ! {listened, ern_helpers:side(listen_tls(0, Server))} end),
    ?assertEqual('Right', ern_waits:wait(listened)),
    ?assert(lists:keymember(ssl, 1, application:which_applications())).

%% report Appendix E.18: the bytes a socket over TLS has taken when it is
%% closed reach a far end that takes them late, the connection's last
%% record after them, and the connection then closes. Written after the
%% code, a regression test
tls_closed_socket_sends_what_it_took_test_() ->
    {timeout, 60, fun tls_closed_socket_sends_what_it_took/0}.

tls_closed_socket_sends_what_it_took() ->
    #{server := Server} = pki(),
    Self = self(),
    %% the far end takes the bytes late: once the closer the socket hands
    %% its host socket to, made as it ends, has looked twice and found
    %% nothing taken
    {FarEnd, FarPort} = tls_far_end(Server, fun(Accepted) ->
                                           receive {go, Closer} -> ok end,
                                           ok = ern_waits:called(Closer,
                                                                 {ern_tcp, lingering, 6}, 2),
                                           Self ! {taken, tls_taken(Accepted, 0)}
                                       end),
    Size = 4 * 1024 * 1024,
    ok = quietly(
           fun() ->
               {'Right', Socket} = connect_tls(<<"127.0.0.1">>, FarPort, 'Unverified', 5000),
               HostSocket = tls_host_socket(FarPort),
               ok = inet:setopts(HostSocket, [{sndbuf, 4096}]),
               Self ! {written, write(Socket, binary:copy(<<1>>, Size))},
               Self ! {host_sockets, [HostSocket]},
               SocketPid = ern_rt:process_of(Socket),
               SocketRef = erlang:monitor(process, SocketPid),
               ok = socket_close_sent(Socket),
               ern_rt:timed(),
               receive {'DOWN', SocketRef, process, _, _} -> ern_rt:untimed() end,
               FarEnd ! {go, closer_of(SocketPid)}
           end),
    ?assertEqual({'Right', 'Unit'}, ern_waits:wait(written)),
    HostSockets = ern_waits:wait(host_sockets),
    ?assertEqual({Size, {error, closed}}, receive {taken, Taken} -> Taken after 20000 -> none end),
    %% the host's socket goes once ssl's close has run, which begins as the
    %% closer, looking a fifth of the idle window apart, finds the bytes
    %% taken, and lasts up to TLS_CLOSE; the idle window again bounds a
    %% failure on a loaded host
    Bound = ?LINGER_IDLE div 5 + ?TLS_CLOSE + ?LINGER_IDLE,
    ?assertEqual(HostSockets, gone(HostSockets, Bound)).

%% report Appendix E.18: however a socket over TLS ends while the host
%% holds bytes the far end has not taken, by `close`, by `kill`, by its
%% owner's death or by the program's end, a far end that takes every byte
%% then reads the record that ends the connection, which the host's close
%% writes as the closer finds every byte taken. The far end, of the host's
%% own, tells the record by how its process of the connection ends: as the
%% peer's close after the record, and as the transport's close without it.
%%
%% Written first, a regression test: with the host's socket shut for
%% writing as it went to its closer, no record came and each connection
%% ended as the transport's close
tls_socket_ends_with_its_closing_record_test_() ->
    {timeout, 60, fun ends_with_its_closing_record/0}.

%% The four ends of a socket over TLS, each while the host holds bytes, and
%% what each gave.
ends_with_its_closing_record() ->
    Size = 4 * 1024 * 1024,
    Ends = [close, kill, owner, ending],
    ?assertEqual([{End, {Size, {error, closed}}, {shutdown, peer_close}, normal, gone}
                  || End <- Ends],
                 [ended_with_record(End, Size) || End <- Ends]).

%% A socket over TLS, written Size bytes that the host holds, ended End:
%% what the far end, told to go once the socket's process has ended, took
%% and how its last read ended; how the far end's process of the connection
%% ended; how the closer the socket made as it ended ended; and the host's
%% socket, `gone` once the host's process of the connection has closed it.
ended_with_record(End, Size) ->
    Self = self(),
    #{server := Server} = Keys = pki(),
    {FarEnd, FarPort} =
        tls_far_end(Server,
                    fun(Accepted) ->
                        Connection = tls_connection_of(self()),
                        ConnectionRef = erlang:monitor(process, Connection),
                        receive go -> ok end,
                        Taken = tls_taken(Accepted, 0),
                        receive
                            {'DOWN', ConnectionRef, process, Connection, ExitReason} ->
                                Self ! {taken, Taken, ExitReason}
                        end
                    end),
    ok = quietly(fun() ->
                     Self ! {held, ended(End, fun() -> held_socket(Keys, FarPort, Size) end)}
                 end),
    {SocketPid, HostSocket} = ern_waits:wait(held),
    ok = ern_waits:ended([SocketPid]),
    Closer = closer_of(SocketPid),
    CloserRef = erlang:monitor(process, Closer),
    HostSocketRef = erlang:monitor(port, HostSocket),
    FarEnd ! go,
    receive {taken, Taken, ConnectionExitReason} -> ok end,
    receive {'DOWN', CloserRef, process, Closer, CloserExitReason} -> ok end,
    receive {'DOWN', HostSocketRef, port, HostSocket, _} ->
        {End, Taken, ConnectionExitReason, CloserExitReason, gone}
    end.

%% report Appendix E.18: `close` of a socket whose host holds bytes the far
%% end has not taken answers once they and, over TLS, the record that ends
%% the connection are with the kernel: not while the closer the socket made
%% as it ended is
%% held, though the far end has taken every byte, and, once the closer is
%% let go, with the closer ended. Over TCP and over TLS; over TCP the host's
%% socket has gone by then, and over TLS it may close a moment after, the
%% host's process of the connection closing it as it ends.
%%
%% Written first, a regression test: the close that was a send answered
%% before the far end had taken a byte, a program that ended then cutting
%% what the host held
close_answers_once_its_bytes_are_sent_test_() ->
    {timeout, 60,
     fun() ->
         Size = 4 * 1024 * 1024,
         ?assertMatch([{tcp, Size, waiting, 'Unit', false, gone, {error, closed}},
                       {tls, Size, waiting, 'Unit', false, _, {error, closed}}],
                      [close_held(Kind, Size) || Kind <- [tcp, tls]])
     end}.

%% A socket over Kind written Size bytes the host holds, closed by a process
%% of its own: what the far end took, told once it has every byte while the
%% closer is held; whether the close had answered then; its answer once the
%% closer is let go, whether the closer was alive then and the host's
%% socket as it answered; and how the far end's connection then ended.
close_held(Kind, Size) ->
    Self = self(),
    Keys = keys(Kind),
    {FarEnd, FarPort} = counting_far_end(Keys, Size),
    ok = quietly(
           fun() ->
               {Socket, HostSocket} = held_socket(Keys, FarPort, Size),
               SocketPid = ern_rt:process_of(Socket),
               EntryProcess = self(),
               _ = ern_rt:spawn(fun() ->
                                    Answer = close(Socket),
                                    EntryProcess ! {answered, Answer, port_gone(HostSocket)}
                                end, <<"closing">>),
               ok = ern_waits:ended([SocketPid]),
               Closer = closer_of(SocketPid),
               true = erlang:suspend_process(Closer),
               FarEnd ! {go, EntryProcess},
               Taken = receive {taken, Count} -> Count end,
               Early = receive {answered, _, _} = Answered -> Answered after 0 -> waiting end,
               true = erlang:resume_process(Closer),
               {answered, Answer, Gone} = case Early of
                                              waiting -> receive {answered, _, _} = A -> A end;
                                              _ -> Early
                                          end,
               Closed = receive {far_closed, Ended} -> Ended end,
               Held = case Early of
                          waiting -> waiting;
                          _ -> answered
                      end,
               Self ! {closed, {Kind, Taken, Held, Answer, erlang:is_process_alive(Closer), Gone,
                                Closed}}
           end),
    ern_waits:wait(closed).

%% report Appendix E.18: `close` of a socket whose host holds nothing
%% answers once the socket has ended and its host's socket has closed. Over
%% TCP the socket makes no closer, and over TLS one that closes at once.
%% Written first, a regression test: the close that was a send answered
%% with the socket alive
close_of_a_socket_that_holds_nothing_test_() ->
    {timeout, 60, fun close_of_a_socket_that_holds_nothing/0}.

close_of_a_socket_that_holds_nothing() ->
    Self = self(),
    #{server := Server} = pki(),
    {_, TcpPort} = tcp_far_end(fun(Accepted) -> taken(Accepted, 0) end),
    {_, TlsPort} = tls_far_end(Server, fun(Accepted) -> tls_taken(Accepted, 0) end),
    ok = quietly(
           fun() ->
               {'Right', Plain} = connect(TcpPort, 2000),
               {'Right', Tls} = connect_tls(<<"127.0.0.1">>, TlsPort, 'Unverified', 5000),
               Hosts = [host_socket(Plain), tls_host_socket(TlsPort)],
               Answers = [{close(Socket), erlang:is_process_alive(ern_rt:process_of(Socket)),
                           port_gone(HostSocket)}
                          || {Socket, HostSocket} <- lists:zip([Plain, Tls], Hosts)],
               Self ! {answers, Answers}
           end),
    ?assertEqual([{'Unit', false, gone}, {'Unit', false, gone}], ern_waits:wait(answers)).

%% report Appendix E.18: `close` answers `Unit` at once on a socket that
%% has ended already, by a close, by a kill or by its owner's death, and
%% faults nothing; and two closes of one socket from two processes both
%% answer `Unit`, the socket held still until both wait in its mailbox.
%% Written with the code; the close that was a send did the same
close_of_an_ended_socket_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {ip, loopback}]),
    {ok, Port} = inet:port(Listen),
    FarEnd = spawn(fun() -> [{ok, _} = gen_tcp:accept(Listen) || _ <- lists:seq(1, 4)],
                            receive done -> ok end
                   end),
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Closed} = connect(Port, 2000),
               'Unit' = close(Closed),
               {'Right', Killed} = connect(Port, 2000),
               ok = ended_by(Killed, fun() -> ern_rt:kill(Killed) end),
               EntryProcess = self(),
               _ = erlang:spawn(fun() -> EntryProcess ! {orphaned, connect(Port, 2000)} end),
               {'Right', Orphaned} = receive {orphaned, Answer} -> Answer end,
               ok = ended_by(Orphaned, fun() -> ok end),
               Ended = [close(Socket) || Socket <- [Closed, Killed, Orphaned]],
               {'Right', Twice} = connect(Port, 2000),
               Pid = ern_rt:process_of(Twice),
               true = erlang:suspend_process(Pid),
               Closings = [ern_rt:spawn_monitored(fun() -> EntryProcess ! {twice, close(Twice)} end,
                                                  fun(Down) -> {down, Down} end, <<"closing">>)
                           || _ <- [1, 2]],
               [ok = ern_waits:calling(ern_rt:process_of(Closing)) || Closing <- Closings],
               true = erlang:resume_process(Pid),
               Both = [receive {twice, Unit} -> Unit end || _ <- Closings],
               Downs = [receive {down, {'Down', _, Reason, _}} -> Reason end || _ <- Closings],
               Self ! {closes, {Ended, Both, Downs}}
           end, <<"main">>, ern_helpers:quiet()),
    FarEnd ! done,
    gen_tcp:close(Listen),
    ?assertEqual({['Unit', 'Unit', 'Unit'], ['Unit', 'Unit'], ['Returned', 'Returned']},
                 ern_waits:wait(closes)).

%% report Appendix E.18: `close` of a socket whose far end takes nothing
%% answers once the bytes are dropped, 5 seconds after the close, and the
%% far end, which reads only then, reads a reset after what its kernel
%% took. Written first, a regression test: the close that was a send
%% answered at once, and the far end that read then took every byte and an
%% orderly close
close_after_the_bytes_are_dropped_test_() ->
    {timeout, 60, fun close_after_the_bytes_are_dropped/0}.

close_after_the_bytes_are_dropped() ->
    Self = self(),
    Size = 4 * 1024 * 1024,
    {FarEnd, FarPort} = counting_far_end(none, Size),
    ok = quietly(
           fun() ->
               {Socket, _} = held_socket(none, FarPort, Size),
               'Unit' = close(Socket),
               FarEnd ! {go, self()},
               Taken = receive {taken, Count} -> Count end,
               Self ! {dropped, {Taken < Size, receive {far_closed, Ended} -> Ended end}}
           end),
    ?assertEqual({true, {error, econnreset}}, ern_waits:wait(dropped)).

%% report Appendix E.18, §8.6: a program whose only live process waits in
%% `close` is no deadlock: the runtime looks twice while the closer is
%% held, and the close answers once the far end has taken every byte.
%% Written first, a regression test: the close that was a send answered
%% before the runtime looked
close_is_no_deadlock_test_() ->
    {timeout, 60, fun close_is_no_deadlock/0}.

close_is_no_deadlock() ->
    Self = self(),
    Size = 4 * 1024 * 1024,
    {FarEnd, FarPort} = counting_far_end(none, Size),
    Outcome = ern_rt:run_main(
                fun() ->
                    {Socket, _} = held_socket(none, FarPort, Size),
                    SocketPid = ern_rt:process_of(Socket),
                    %% a process of the host's, outside the run, holds the
                    %% closer while the runtime looks
                    _ = erlang:spawn(fun() ->
                                         ok = ern_waits:ended([SocketPid]),
                                         Closer = closer_of(SocketPid),
                                         true = erlang:suspend_process(Closer),
                                         ok = ern_waits:looked(2),
                                         Self ! looked,
                                         FarEnd ! {go, Self},
                                         erlang:resume_process(Closer)
                                     end),
                    'Unit' = close(Socket),
                    Self ! answered
                end, <<"main">>, ern_helpers:quiet()),
    First = receive looked -> looked; answered -> answered end,
    ?assertEqual({ok, looked}, {Outcome, First}),
    ?assertMatch({taken, Size}, receive {taken, _} = Taken -> Taken end).

%% report Appendix E.18, E.21: a process that waits in `close` is `Calling`
%% the socket it closes, without a limit, as one that waits in
%% `closeListener` is the listener, while the closer the socket made as it
%% ended is held. Written first: the close that was a send had returned
close_waits_as_a_call_test_() ->
    {timeout, 60, fun close_waits_as_a_call/0}.

close_waits_as_a_call() ->
    Self = self(),
    Size = 4 * 1024 * 1024,
    {FarEnd, FarPort} = counting_far_end(none, Size),
    ok = quietly(
           fun() ->
               {Socket, _} = held_socket(none, FarPort, Size),
               SocketPid = ern_rt:process_of(Socket),
               EntryProcess = self(),
               Closing = ern_rt:spawn(fun() -> EntryProcess ! {answered, close(Socket)} end,
                                      <<"closing">>),
               ok = ern_waits:ended([SocketPid]),
               Closer = closer_of(SocketPid),
               true = erlang:suspend_process(Closer),
               ok = ern_waits:calling(ern_rt:process_of(Closing)),
               Status = ern_rt:status(ern_rt:process_of(Closing)),
               true = erlang:resume_process(Closer),
               FarEnd ! {go, EntryProcess},
               Answer = receive {answered, A} -> A end,
               Self ! {status, {SocketPid, Status, Answer}}
           end),
    {SocketPid, Status, Answer} = ern_waits:wait(status),
    ?assertMatch({'Some', {'Status', <<"closing">>, _, {'Calling', {'Some', SocketPid}, false, _},
                           _}}, Status),
    ?assertEqual('Unit', Answer).

%% report Appendix E.18, §6.9: a process killed while it waits in `close`
%% ends, and the closer the socket made as it ended goes on: the far end
%% still takes every byte, and then the connection's close. Written first:
%% the close that was a send had returned before the kill
close_of_a_killed_caller_test_() ->
    {timeout, 60, fun close_of_a_killed_caller/0}.

close_of_a_killed_caller() ->
    Self = self(),
    Size = 4 * 1024 * 1024,
    {FarEnd, FarPort} = counting_far_end(none, Size),
    ok = quietly(
           fun() ->
               {Socket, _} = held_socket(none, FarPort, Size),
               SocketPid = ern_rt:process_of(Socket),
               Closing = ern_rt:spawn_monitored(fun() -> close(Socket) end,
                                                fun(Down) -> {down, Down} end, <<"closing">>),
               ok = ern_waits:ended([SocketPid]),
               Closer = closer_of(SocketPid),
               true = erlang:suspend_process(Closer),
               ok = ern_waits:calling(ern_rt:process_of(Closing)),
               ern_rt:kill(Closing),
               receive {down, {'Down', _, Reason, _}} -> ok end,
               true = erlang:resume_process(Closer),
               FarEnd ! {go, self()},
               Taken = receive {taken, Count} -> Count end,
               Self ! {killed, {Reason, Taken, receive {far_closed, Ended} -> Ended end}}
           end),
    ?assertEqual({'Killed', Size, {error, closed}}, ern_waits:wait(killed)).

%% A far end over TCP, or over TLS with Keys, that takes nothing until it
%% is told to go and by whom, and then tells that process how many bytes
%% it has taken once it has Size or its connection has ended, and how its
%% connection ended, a reset over TCP as the host's `econnreset`.
counting_far_end(none, Size) ->
    tcp_far_end(fun(Accepted) ->
                    ok = inet:setopts(Accepted, [{show_econnreset, true}]),
                    counted(gen_tcp, Accepted, Size)
                end);
counting_far_end(#{server := Server}, Size) ->
    tls_far_end(Server, fun(Accepted) -> counted(ssl, Accepted, Size) end).

counted(Transport, Connection, Size) ->
    receive {go, Tell} -> counted(Transport, Connection, Size, 0, Tell) end.

counted(Transport, Connection, Size, Count, Tell) ->
    case Transport:recv(Connection, 0, 10000) of
        {ok, Bytes} ->
            Counted = Count + byte_size(Bytes),
            Count < Size andalso Counted >= Size andalso taken_told(Tell, Counted),
            counted(Transport, Connection, Size, Counted, Tell);
        Ended ->
            Count < Size andalso taken_told(Tell, Count),
            Tell ! {far_closed, Ended}
    end.

taken_told(Tell, Count) ->
    Tell ! {taken, Count},
    true.

keys(tcp) -> none;
keys(tls) -> pki().

%% `gone` where the host's socket has closed, and `open` where it has not.
port_gone(HostSocket) ->
    case erlang:port_info(HostSocket) of
        undefined -> gone;
        _ -> open
    end.

%% report Appendix E.18: `close` of a socket over TLS whose handshake has
%% not ended answers at once, as the socket ends, and waits on no closer
%% and on nothing of the host's: with the host's process of the connection
%% held, the socket ends rather than wait on it, and the process that closes
%% ends with the close's answer while each process the socket made is held,
%% against a far end that has sent nothing and against a handshake paused
%% after the server's hello over TLS 1.2 and over TLS 1.3.
%%
%% Written first, a regression test, in two steps. The close waited for
%% the closer, whose host's close waits 5 seconds for an answer such a far
%% end never sends. Then the socket asked the host's process of the
%% connection as it ended, which over TLS 1.3 answers only once it has
%% ended the connection with an alert and waited 5 seconds of its own for
%% the far end, and the close with it
close_of_a_handshake_not_ended_test_() ->
    {timeout, 60,
     fun() ->
         #{server := Server} = pki(),
         Cases = [waiting, 'tlsv1.2', 'tlsv1.3'],
         ?assertEqual([{Case, ended, ended, 'Unit'} || Case <- Cases],
                      [closed_while_shaking(Server, Case) || Case <- Cases])
     end}.

%% A socket over TLS that a listener with Server's certificate accepted,
%% its handshake not begun by the far end or paused after the server's
%% hello over the version Case, closed by a process of its own while the
%% host's process of the connection is held: whether the socket ended
%% rather than wait on the host; once it has and each process it made is
%% held, whether the process that closes ended rather than wait on one of
%% them; and the close's answer then.
closed_while_shaking(Server, Case) ->
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               %% waits in the host's code, the deadlock detector's foreign code
               {ok, Client} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}]),
               {'Right', Socket} = accept(Listener, 5000),
               FarEnd = shaking_hands(Case, Client),
               SocketPid = ern_rt:process_of(Socket),
               Connection = tls_connection_of(SocketPid),
               true = erlang:suspend_process(Connection),
               EntryProcess = self(),
               Closing = ern_rt:process_of(
                           ern_rt:spawn(fun() -> EntryProcess ! {answered, close(Socket)} end,
                                        <<"closing">>)),
               Ended = ern_waits:until(SocketPid, fun() -> waits_on_the_host(SocketPid) end),
               Made = [Pid || Pid <- erlang:processes(),
                              erlang:process_info(Pid, parent) =:= {parent, SocketPid}],
               lists:foreach(fun erlang:suspend_process/1, Made),
               Waited = case Ended of
                            ended ->
                                Watching = fun() ->
                                               lists:any(fun(Pid) -> watches(Closing, Pid) end,
                                                         Made)
                                           end,
                                ern_waits:until(Closing, Watching);
                            ok ->
                                waited_on_the_host
                        end,
               Answer = receive {answered, Answered} -> Answered after 0 -> waiting end,
               lists:foreach(fun erlang:resume_process/1, Made),
               true = erlang:resume_process(Connection),
               _ = far_closed(FarEnd),
               ok = ern_waits:ended([SocketPid | Made]),
               'Unit' = close_listener(Listener),
               Self ! {closed, {Case, Ended, Waited, Answer}}
           end),
    ern_waits:wait(closed).

%% Whether Pid waits in a receive of code not the runtime's, its module's
%% or ern_rt's, where a socket's end waits for its writer (ern_rt:stop/1),
%% but the host's, as a call to one of the host's processes waits.
waits_on_the_host(Pid) ->
    case erlang:process_info(Pid, [status, current_function]) of
        [{status, waiting}, {current_function, {Module, _, _}}] ->
            not lists:member(Module, [ern_tcp, ern_rt]);
        _ ->
            false
    end.

%% Whether Pid monitors Watched.
watches(Pid, Watched) ->
    case erlang:process_info(Pid, monitors) of
        {monitors, Monitors} -> lists:member({process, Watched}, Monitors);
        undefined -> false
    end.

%% report Appendix E.18: `close` of a socket over TLS whose handshake is
%% done answers once the record that ends the connection is with the
%% kernel, and waits for nothing the far end does. The far end, of the
%% host's own, is held, its process of the connection suspended, so that it
%% reads nothing and stays open; the close answers while it is held, and
%% the closer has had the host write the record by its shutdown of both
%% ways before any close of the host's, which then no longer waits for the
%% far end's answer. Let go, the far end reads what the socket wrote and
%% then the connection's end.
%%
%% That the host's close did not wait only a time tells, and the test reads
%% no clock: it holds the closer's calls, in their order, by the host's
%% trace. Where the host's process of the
%% connection has closed the host's socket after the shutdown, the closer
%% makes no close of its own. A far end of the host's that reads only
%% after the record has come ends as the transport's close, not the
%% peer's, so this one does not tell the record (the test of the four ends
%% does).
%%
%% Written first, a regression test: the closer made the host's close alone,
%% which wrote the record and then waited 5 seconds for the far end's
%% answer, and the close with it
close_without_the_far_ends_answer_test_() ->
    {timeout, 60, fun close_without_the_far_ends_answer/0}.

close_without_the_far_ends_answer() ->
    Self = self(),
    #{server := Server} = pki(),
    Size = 1024,
    {FarEnd, FarPort} =
        tls_far_end(Server,
                    fun(Accepted) ->
                        Connection = tls_connection_of(self()),
                        EntryProcess = receive {main, Sent} -> Sent end,
                        EntryProcess ! {far_connection, Connection},
                        receive go -> ok end,
                        Self ! {taken, tls_taken(Accepted, 0)}
                    end),
    Traced = [{ssl, shutdown, 2}, {ssl, close, 1}],
    [1 = erlang:trace_pattern(MFA, true, [global]) || MFA <- Traced],
    try
        ok = quietly(
               fun() ->
                   {'Right', Socket} = connect_tls(<<"127.0.0.1">>, FarPort, 'Unverified', 5000),
                   {'Right', 'Unit'} = write(Socket, binary:copy(<<1>>, Size)),
                   FarEnd ! {main, self()},
                   FarConnection = receive {far_connection, Connection} -> Connection end,
                   true = erlang:suspend_process(FarConnection),
                   SocketPid = ern_rt:process_of(Socket),
                   1 = erlang:trace(SocketPid, true, [call, set_on_spawn, {tracer, Self}]),
                   Answer = close(Socket),
                   Held = erlang:process_info(FarConnection, status),
                   true = erlang:resume_process(FarConnection),
                   FarEnd ! go,
                   Self ! {closed, {SocketPid, Answer, Held}}
               end),
        {SocketPid, Answer, Held} = ern_waits:wait(closed),
        Delivered = erlang:trace_delivered(all),
        receive {trace_delivered, all, Delivered} -> ok end,
        Shut = case closer_calls(SocketPid) of
                   [{shutdown, read_write}] -> shut_first;
                   [{shutdown, read_write}, close] -> shut_first;
                   Calls -> Calls
               end,
        Taken = receive {taken, FarTaken} -> FarTaken end,
        ?assertEqual({'Unit', {status, suspended}, shut_first, {Size, {error, closed}}},
                     {Answer, Held, Shut, Taken})
    after
        [erlang:trace_pattern(MFA, false, [global]) || MFA <- Traced]
    end.

%% The calls of ssl's shutdown and close the host traced of a process the
%% socket's process made, oldest first, each named with how it shut down.
closer_calls(SocketPid) ->
    receive
        {trace, Pid, call, {ssl, shutdown, [_, How]}} when Pid =/= SocketPid ->
            [{shutdown, How} | closer_calls(SocketPid)];
        {trace, Pid, call, {ssl, close, [_]}} when Pid =/= SocketPid ->
            [close | closer_calls(SocketPid)];
        {trace, SocketPid, call, _} ->
            closer_calls(SocketPid)
    after 0 ->
        []
    end.

%% The closer a socket's process made as it ended, its one child still
%% alive, the writer having ended before it (ern_tcp:close_socket/3).
closer_of(SocketPid) ->
    [Closer] = [Pid || Pid <- erlang:processes(),
                       erlang:process_info(Pid, parent) =:= {parent, SocketPid}],
    Closer.

%% Every byte the far end over TLS reads, and how the connection then ends.
-spec tls_taken(ssl:sslsocket(), non_neg_integer()) -> {non_neg_integer(), term()}.
tls_taken(Connection, Count) ->
    case ssl:recv(Connection, 0, 10000) of
        {ok, Bytes} -> tls_taken(Connection, Count + byte_size(Bytes));
        Ended -> {Count, Ended}
    end.

%% A far end over TLS of the host's own, a process that listens on the
%% loopback with small buffers, so that it takes far less than a megabyte
%% unread, accepts one connection, and runs Serve over it; and its port.
tls_far_end({Certificate, Key}, Serve) ->
    {ok, _} = application:ensure_all_started(ssl),
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Listen} = ssl:listen(0, [binary, {active, false}, {recbuf, 4096},
                                                     {ip, {127, 0, 0, 1}},
                                                     {certfile, Certificate}, {keyfile, Key}]),
                       {ok, {_, Port}} = ssl:sockname(Listen),
                       Self ! {far_port, Port},
                       {ok, Handshaking} = ssl:transport_accept(Listen, 5000),
                       {ok, Accepted} = ssl:handshake(Handshaking, 5000),
                       Serve(Accepted),
                       ssl:close(Listen)
                   end),
    {FarEnd, ern_waits:wait(far_port)}.

%% A far end over TCP of the host's own, as tls_far_end/2's over TLS.
tcp_far_end(Serve) ->
    Self = self(),
    FarEnd = spawn(fun() ->
                       {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {recbuf, 4096},
                                                         {ip, {127, 0, 0, 1}}]),
                       {ok, Port} = inet:port(Listen),
                       Self ! {far_port, Port},
                       {ok, Accepted} = gen_tcp:accept(Listen, 5000),
                       Serve(Accepted),
                       gen_tcp:close(Listen)
                   end),
    {FarEnd, ern_waits:wait(far_port)}.

%% The host's socket of the connection to the far end on FarPort, which a
%% socket over TLS reaches through the host's ssl, whose own process owns
%% it.
tls_host_socket(FarPort) ->
    [HostSocket] = [Port || Port <- erlang:ports(),
                            erlang:port_info(Port, name) =:= {name, "tcp_inet"},
                            inet:peername(Port) =:= {ok, {{127, 0, 0, 1}, FarPort}}],
    HostSocket.

%% A listener's acceptor that accepts Count connections, keeping each, and
%% ends when told.
accepting(Listener, Count) ->
    _ = [accept(Listener, 5000) || _ <- lists:seq(1, Count)],
    receive done -> ok end.

%% Report Appendix E.18: the certificates a test over TLS uses, PEM files of
%% a directory of its own made by the host's test data: an authority's,
%% `ca`, another's, `other_ca`, and three servers' certificates, each its
%% chain of one intermediate after it, with their keys, which `ca` signed:
%% `server`, which names localhost by name and by
%% address, `elsewhere`, which names another host, and `wildcard`, which
%% names the hosts under example.test through a wildcard; `server_alone`
%% and `elsewhere_alone`,
%% which name localhost and another host, each its certificate alone, which
%% `ca` signed with no intermediate; and three self-signed certificates,
%% each a file of its own with its key: `self_signed`, a CA naming
%% localhost by name and by address, `self_signed_leaf`, no CA, naming
%% localhost, and `self_signed_elsewhere`, naming another host.
-spec pki() -> #{atom() => term()}.
pki() ->
    Dir = ern_helpers:tmp("ern_tcp_tls_"),
    Root = public_key:pkix_test_root_cert("Ernest test authority", key_options()),
    Other = public_key:pkix_test_root_cert("Ernest other authority", key_options()),
    #{dir => Dir,
      ca => pem(Dir, "ca.pem", [maps:get(cert, Root)]),
      other_ca => pem(Dir, "other_ca.pem", [maps:get(cert, Other)]),
      server => server(Dir, "server", Root, [{dNSName, "localhost"},
                                             {iPAddress, <<127, 0, 0, 1>>}]),
      server_alone => server(Dir, "server_alone", Root, [], [{dNSName, "localhost"}]),
      elsewhere => server(Dir, "elsewhere", Root, [{dNSName, "elsewhere.example"}]),
      elsewhere_alone => server(Dir, "elsewhere_alone", Root, [],
                                [{dNSName, "elsewhere.example"}]),
      wildcard => server(Dir, "wildcard", Root, [{dNSName, "*.example.test"}]),
      self_signed => self_signed(Dir, "self_signed", true,
                                 [{dNSName, "localhost"}, {iPAddress, <<127, 0, 0, 1>>}]),
      self_signed_leaf => self_signed(Dir, "self_signed_leaf", false, [{dNSName, "localhost"}]),
      self_signed_elsewhere => self_signed(Dir, "self_signed_elsewhere", true,
                                          [{dNSName, "elsewhere.example"}])}.

%% A self-signed certificate's file and its key's, the certificate naming
%% AltNames, a CA where Ca is true and an end entity otherwise.
self_signed(Dir, Name, Ca, AltNames) ->
    Names = #'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                         extnValue = AltNames},
    Constraints = #'Extension'{extnID = ?'id-ce-basicConstraints', critical = true,
                               extnValue = #'BasicConstraints'{cA = Ca}},
    #{cert := Certificate, key := Key} =
        public_key:pkix_test_root_cert(Name, [{extensions, [Names, Constraints]} | key_options()]),
    {pem(Dir, Name ++ ".pem", [Certificate]),
     pem_entries(Dir, Name ++ ".key", [public_key:pem_entry_encode(element(1, Key), Key)])}.

%% A server's certificate file, its intermediate after it, and its key's
%% file, its certificate naming AltNames; or, given no intermediates, its
%% certificate alone, which Root signed. The host's test data gives Root
%% among the chain's authorities, which the far end does not send.
server(Dir, Name, Root, AltNames) ->
    server(Dir, Name, Root, [key_options()], AltNames).

server(Dir, Name, Root, Intermediates, AltNames) ->
    Names = #'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                         extnValue = AltNames},
    Configuration = public_key:pkix_test_data(#{root => Root,
                                                intermediates => Intermediates,
                                                peer => [{extensions, [Names]}
                                                         | key_options()]}),
    Certificate = proplists:get_value(cert, Configuration),
    {KeyType, Key} = proplists:get_value(key, Configuration),
    Chain = [Der || Der <- proplists:get_value(cacerts, Configuration),
                    not public_key:pkix_is_self_signed(Der)],
    {pem(Dir, Name ++ ".pem", [Certificate | Chain]),
     pem_entries(Dir, Name ++ ".key", [{KeyType, Key, not_encrypted}])}.

%% Keys and signatures every TLS version the host speaks takes.
key_options() ->
    [{digest, sha256}, {key, {namedCurve, secp256r1}}].

pem(Dir, Name, Certificates) ->
    pem_entries(Dir, Name, [{'Certificate', Der, not_encrypted} || Der <- Certificates]).

pem_entries(Dir, Name, Entries) ->
    File = filename:join(Dir, Name),
    ok = file:write_file(File, public_key:pem_encode(Entries)),
    File.

%% A run of the program Main whose host reports no notice, the alerts of
%% its ssl among them, which a handshake that fails makes, as `ern run`
%% reports none (ern_cli's quiet_signals/0).
quietly(EntryPoint) ->
    quiet_host(fun() -> ern_rt:run_main(EntryPoint, <<"main">>, ern_helpers:quiet()) end).

quiet_host(Work) ->
    {ok, #{level := Level}} = logger:get_handler_config(default),
    ok = logger:set_handler_config(default, level, warning),
    try
        Work()
    after
        logger:set_handler_config(default, level, Level)
    end.

listen_tls(Port, {Certificate, Key}) ->
    Owner = self(),
    ern_rt:call_forever(ern_rt:system_process(tcp),
                        fun(Reply) ->
                            {'ListenTls', <<"127.0.0.1">>, Port, path(Certificate), path(Key),
                             Owner, Reply}
                        end).

connect_tls(Host, Port, Verification, Ms) ->
    %% report Appendix E.18: the caller owns the socket
    Owner = self(),
    ern_rt:call_forever(ern_rt:system_process(tcp),
                        fun(Reply) ->
                            {'ConnectTls', Host, Port, Verification, Ms, Owner, Reply}
                        end).

verified(File) ->
    {'Verified', path(File)}.

path(File) ->
    {'Path', unicode:characters_to_binary(File)}.

listen(Port) ->
    listen(<<"127.0.0.1">>, Port).

listen(Host, Port) ->
    %% report §6.9, Appendix E.18: the caller owns the listener
    Owner = self(),
    ern_rt:call_forever(ern_rt:system_process(tcp), fun(Reply) ->
                                                        {'Listen', Host, Port, Owner, Reply}
                                                    end).

connect(Port, Ms) ->
    connect(<<"127.0.0.1">>, Port, Ms).

connect(Host, Port, Ms) ->
    %% report Appendix E.18: the caller owns the socket
    Owner = self(),
    ern_rt:call_forever(ern_rt:system_process(tcp), fun(Reply) ->
                                                        {'Connect', Host, Port, Ms, Owner, Reply}
                                                    end).

%% Report Appendix E.18: Tcp's functions over a listener or a socket, as a
%% program calls them, each answering `Left(Closed)` where the listener or
%% the socket has ended; each is found in the library the run has loaded,
%% so that a caller seen waiting waits in its call (ern_named:loaded/2).
port(Listener) ->
    (ern_named:loaded('ern@tcp', port))(Listener).

accept(Listener, Ms) ->
    (ern_named:loaded('ern@tcp', accept))(Listener, Ms).

%% Report Appendix E.18: `Tcp.closeListener`, the call that answers once the
%% listener has ended.
close_listener(Listener) ->
    ern_rt:call_until_ended(Listener, fun(Reply) -> {'CloseListener', Reply} end).

%% A close of Listener under way, its caller a process of the run's that
%% waits in its call, the request in the listener's mailbox.
close_sent(Listener) ->
    Closer = ern_rt:spawn(fun() -> close_listener(Listener) end, <<"closer">>),
    ok = ern_waits:calling(ern_rt:process_of(Closer)).

%% Report Appendix E.18: `Tcp.close` itself, which answers once the socket
%% has ended, and once its closer has ended where it made one.
close(Socket) ->
    (ern_named:function('ern@tcp', close))(Socket).

%% A close of Socket under way, as close_sent/1's of a listener, for a test
%% whose own process goes on while the close waits.
socket_close_sent(Socket) ->
    Closing = ern_rt:spawn(fun() -> close(Socket) end, <<"closing">>),
    ok = ern_waits:calling(ern_rt:process_of(Closing)).

write(Socket, Bytes) ->
    write(Socket, Bytes, 60000).

write(Socket, Bytes, Ms) ->
    (ern_named:loaded('ern@tcp', write))(Socket, Bytes, Ms).

read(Socket, Ms) ->
    (ern_named:loaded('ern@tcp', read))(Socket, Ms).

%% Report Appendix E.18: an accept and a read without a time, as
%% `Tcp.acceptForever` and `Tcp.readForever` ask them.
accept_forever(Listener) ->
    Owner = self(),
    ern_rt:call_forever(Listener, fun(Reply) -> {'AcceptForever', Owner, Reply} end).

read_forever(Socket) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'ReadForever', Reply} end).

remote(Socket) ->
    (ern_named:loaded('ern@tcp', remote))(Socket).

local(Socket) ->
    (ern_named:loaded('ern@tcp', local))(Socket).
