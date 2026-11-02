%% Report Appendix E.18: the processes behind a listener and a socket.
-module(ern_tcp_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").

-export([pki/0]).

%% Appendix E.18, report §6.6: a read that timed out leaves the socket
%% delivering to the reads after it. A regression test: the socket asked
%% for one packet per read that found nothing waiting, and the packet went
%% to the read that had timed out, so the next read was never answered
read_after_timeout_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    Peer = spawn(fun() ->
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
               Peer ! go,
               Self ! {read, read(Socket, 2000)},
               Peer ! next,
               Self ! {read, read(Socket, 2000)},
               Peer ! done
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    %% each read after the one that timed out is answered with what arrives
    %% while it waits
    ?assertEqual({'Right', <<"a">>}, wait(read)),
    ?assertEqual({'Right', <<"b">>}, wait(read)).

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
               Self ! {second, side(accept(Listener, 2000))},
               gen_tcp:close(Connection)
           end, <<"main">>, quiet()),
    ?assert(wait(port) > 0),
    ?assertEqual({'Left', 'Timeout'}, wait(first)),
    ?assertEqual('Right', wait(second)).

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
               Listener ! 'CloseListener',
               receive {'DOWN', MonitorRef, process, _, ExitReason} -> Self ! {ended, ExitReason}
               end
           end, <<"main">>, quiet()),
    ?assertEqual({ern, closed}, wait(ended)).

%% Appendix E.18 (L3): a socket lives until it is closed: after the far end
%% closes, what came before is read, then each read, `remote` and `local`
%% answer `Left(Closed)`; a read after `Tcp.close` faults the reader, as a
%% callForever on an ended process does: `callee was closed` where the
%% close ends the socket while the read waits, and `callee had ended` where
%% it had ended before (§6.6). The first is a regression test of the rule,
%% before which it said the callee returned; the socket is held still until
%% both the close and the read wait in its mailbox
socket_lives_until_closed_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Writer = spawn(fun() ->
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
               WriterRef = erlang:monitor(process, Writer),
               ern_rt:timed(),
               receive {'DOWN', WriterRef, process, _, _} -> ern_rt:untimed() end,
               Self ! {reads, [read(Socket, 1000), read(Socket, 1000), read(Socket, 1000),
                               remote(Socket), local(Socket)]},
               Pid = ern_rt:process_of(Socket),
               erlang:suspend_process(Pid),
               ern_rt:send(Socket, 'Close'),
               %% monitored from its start: a reader that faulted before a
               %% monitor was made would be `Unknown`, as the test once saw
               %% under load
               Reader = ern_rt:spawn_monitored(fun() -> read(Socket, 1000) end,
                                               fun(Down) -> {down, Down} end, <<"reader">>),
               %% the reader waits once it has sent its read
               ok = ern_waits:waiting(ern_rt:process_of(Reader)),
               erlang:resume_process(Pid),
               receive {down, Down} -> Self ! {down, Down} end,
               _ = ern_rt:spawn_monitored(fun() -> read(Socket, 1000) end,
                                         fun(L) -> {later, L} end, <<"reader">>),
               receive {later, L} -> Self ! {later, L} end
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    ?assertEqual([{'Right', <<"x">>}, {'Left', 'Closed'}, {'Left', 'Closed'},
                  {'Left', 'Closed'}, {'Left', 'Closed'}], wait(reads)),
    ?assertMatch({'Down', _, {'Fault', <<"callee was closed">>}, _}, wait(down)),
    ?assertMatch({'Down', _, {'Fault', <<"callee had ended">>}, _}, wait(later)).

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
               MonitorRef = erlang:monitor(process, Pid),
               ern_rt:send(Listener, 'CloseListener'),
               receive {'DOWN', MonitorRef, _, _, _} -> ok end,
               Self ! {alive, erlang:is_process_alive(Pid)}
           end, <<"main">>, quiet()),
    ?assertEqual({'Left', 'Closed'}, wait(accepted)),
    ?assertEqual(false, wait(alive)).

%% report §6.6, Appendix E.18: an accept that waits as the listener's close
%% ends it faults with `callee was closed`. A regression test of the rule;
%% the listener is held still until both the close and the accept wait in
%% its mailbox
accept_meets_the_close_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               erlang:suspend_process(Pid),
               ern_rt:send(Listener, 'CloseListener'),
               Acceptor = ern_rt:spawn_monitored(fun() -> accept(Listener, 1000) end,
                                                 fun(Down) -> {down, Down} end, <<"acceptor">>),
               %% the acceptor waits once it has sent its accept
               ok = ern_waits:waiting(ern_rt:process_of(Acceptor)),
               erlang:resume_process(Pid),
               receive {down, Down} -> Self ! {down, Down} end
           end, <<"main">>, quiet()),
    ?assertMatch({'Down', _, {'Fault', <<"callee was closed">>}, _}, wait(down)).

%% report §8.6: a socket killed while a read waits on it holds no source,
%% so the deadlock of what is left is still found. A regression test for
%% the count of sources, which a killed holder could leave up for good
killed_socket_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Peer = spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive done -> ok end end),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Socket} = connect(Port, 2000),
                   Reader = ern_rt:spawn(fun() -> read(Socket, 100000) end,
                                         <<"reader">>),
                   ern_rt:monitor(Reader, fun(Down) -> {down, Down} end),
                   %% the read waits on the socket as it is killed
                   ok = ern_waits:waiting(ern_rt:process_of(Reader)),
                   ern_rt:kill(Socket),
                   receive {down, _} -> ok end,
                   ern_waits:forever()
               end, <<"main">>, quiet()),
    Peer ! done,
    gen_tcp:close(Listen),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

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
               end, <<"main">>, quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, wait(listened)),
    ?assertEqual(Refused, wait(connected)),
    ?assertMatch({fault, <<"deadlock">>, _}, Result).

%% Appendix E.18: a connect to a port where nothing listens, which the far
%% end refuses, answers `Refused`. A regression test of the principles
%% review's K13 (2026-10-09), which stated the answer at `Tcp.connect`;
%% the code gave it already
connect_refused_test() ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    ok = gen_tcp:close(Held),
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {connected, connect(Port, 2000)} end,
                         <<"main">>, quiet()),
    ?assertEqual({'Left', 'Refused'}, wait(connected)).

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
               end, <<"main">>, quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, wait(listened)),
    ?assertEqual(Refused, wait(connected)),
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
               Self ! {connected, side(connect(<<"::1">>, Port, 2000))}
           end, <<"main">>, quiet()),
    ?assertEqual('Right', wait(connected)).

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
               Me = self(),
               %% the client holds its side open until the port is listened
               %% on again, so that the server's side closes first
               Client = spawn(fun() ->
                                  Me ! {client, connect(Port, 2000)},
                                  receive done -> ok end
                              end),
               {'Right', Socket} = accept(Listener, 2000),
               receive {client, {'Right', _}} -> ok end,
               Closed = [erlang:monitor(process, ern_rt:process_of(Ended))
                         || Ended <- [Socket, Listener]],
               ern_rt:send(Socket, 'Close'),
               ern_rt:send(Listener, 'CloseListener'),
               ern_rt:timed(),
               [receive {'DOWN', MonitorRef, process, _, _} -> ok end || MonitorRef <- Closed],
               ern_rt:untimed(),
               Self ! {again, side(listen(Port))},
               Client ! done
           end, <<"main">>, quiet()),
    ?assertEqual('Right', wait(again)).

%% Appendix E.1, E.18: a reason of the host's that no constructor of
%% Io.Error names is answered in the host's words, a port already in use
%% "address already in use". A regression test: `Other` held the code,
%% "eaddrinuse"; it does not cover a reason the host has no words for,
%% which keeps its printed form
port_in_use_test() ->
    {ok, Taken} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Taken),
    Self = self(),
    ok = ern_rt:run_main(fun() -> Self ! {listened, listen(Port)} end, <<"main">>, quiet()),
    gen_tcp:close(Taken),
    ?assertEqual({'Left', {'Other', <<"address already in use">>}}, wait(listened)).

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
           end, <<"main">>, quiet()),
    ?assertEqual(ok, wait(loopback)),
    ?assertMatch({error, _}, wait(other)).

reach(Host, Port) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}], 1000) of
        {ok, Socket} -> gen_tcp:close(Socket);
        Error -> Error
    end.

%% report Appendix E.18: a write answered holds no timer: one the socket
%% took before its milliseconds pass is sent nothing when they pass. A
%% regression test: the timer stayed armed and answered `Left(Timeout)` to
%% a reply already answered
answered_write_holds_no_timer_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    Peer = spawn(fun() ->
                     {ok, Connection} = gen_tcp:accept(Listen),
                     receive done -> gen_tcp:close(Connection) end
                 end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               erlang:trace(Socket, true, ['receive', {tracer, Self}]),
               Ms = 300,
               Written = ern_rt:call_forever(Socket, fun(Reply) ->
                                                         {'Write', <<"x">>, Ms, Reply}
                                                     end),
               %% an absence: a timer the write left would fire its
               %% milliseconds after it, and the host's timers may fire
               %% late, so twice that
               sleep(2 * Ms),
               Self ! {written, Written}
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    Peer ! done,
    ?assertEqual({'Right', 'Unit'}, receive {written, Answer} -> Answer after 5000 -> none end),
    Timeouts = fun Collect() ->
                   receive
                       {trace, _, 'receive', {deadline, {write, _}} = Timeout} ->
                           [Timeout | Collect()];
                       {trace, _, _, _} -> Collect()
                   after 0 ->
                       []
                   end
               end,
    ?assertEqual([], Timeouts()).

%% Appendix E.18: a write the far end holds back holds up no read of the
%% socket, and the read's time limit holds. A regression test: the
%% socket's process wrote itself, and a read behind a write that waited
%% waited with it, past its limit
write_holds_up_no_read_test_() ->
    {timeout, 60, fun write_holds_up_no_read/0}.

write_holds_up_no_read() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts and never reads
    Peer = spawn(fun() ->
                     {ok, Connection} = gen_tcp:accept(Listen),
                     receive done -> gen_tcp:close(Connection) end
                 end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               %% the host queues one write whole and holds the next back
               Chunk = binary:copy(<<0>>, 1024 * 1024),
               Main = erlang:self(),
               Flood = fun() ->
                           [begin write(Socket, Chunk), Main ! wrote end
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
           end, <<"main">>, quiet()),
    Peer ! done,
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
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts and never reads
    Peer = spawn(fun() ->
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
           end, <<"main">>, quiet()),
    Peer ! done,
    gen_tcp:close(Listen),
    {written, Whole, Behind, Took} =
        receive {written, _, _, _} = Message -> Message after 10000 -> timeout end,
    ?assertEqual({'Right', 'Unit'}, Whole),
    ?assertEqual({'Left', 'Timeout'}, Behind),
    ?assert(Took < 2000).

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
           end, <<"main">>, quiet()),
    ?assertEqual({ern, killed}, wait(ended)).

%% report Appendix E.18: a socket closed or killed while the far end takes
%% nothing lets go of its host's socket once 5 seconds pass with nothing
%% taken, and a write it holds at its close answers `Left(Closed)`. A
%% regression test: the host's socket stayed open, with its descriptor and
%% its bytes, for as long as the far end took nothing,
%% and a write held at the close had whatever answer the writer gave before
%% the exit took it (C108). The 3 minutes' bound is not reached here
lingering_socket_closes_test_() ->
    {timeout, 60, fun lingering_socket_closes/0}.

lingering_socket_closes() ->
    %% the far end's buffer is small, as the near end's are below, so that
    %% the hosts take far less than a megabyte and a write queued behind
    %% another is held for good: a write the host finished as the socket
    %% closed would hold nothing, and the flood's next write would fault
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {recbuf, 4096}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end accepts twice and never reads
    Peer = spawn(fun() ->
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
               Main = self(),
               Chunk = binary:copy(<<0>>, 1024 * 1024),
               _ = ern_rt:spawn(fun() -> Main ! {closed_write, flooded(Closed, Chunk)} end,
                                <<"flood">>),
               _ = ern_rt:spawn_monitored(fun() -> flooded(Killed, Chunk) end,
                                          fun(Down) -> {down, Down} end, <<"flood">>),
               %% a write is held once the writer waits on the busy host socket
               held(Closed, byte_size(Chunk)),
               held(Killed, byte_size(Chunk)),
               Self ! {host_sockets, HostSockets},
               ern_rt:send(Closed, 'Close'),
               ern_rt:kill(Killed),
               %% the program's end kills every process (report §8.6), so main
               %% returns only once both floods have their answers
               receive
                   {closed_write, Written} -> Self ! {closed_write, Written}
               after 5000 ->
                   Self ! {closed_write, timeout}
               end,
               receive {down, Down} -> Self ! {killed_write, Down} end
           end, <<"main">>, quiet()),
    HostSockets = wait(host_sockets),
    ?assertEqual(2, length(HostSockets)),
    %% the write each socket held as it ended: answered by the close, and
    %% its caller faulted by the kill, as §6.6 says
    ?assertEqual({'Left', 'Closed'}, wait(closed_write)),
    ?assertMatch({'Down', _, {'Fault', _}, _}, wait(killed_write)),
    Gone = gone(HostSockets, 9000),
    Peer ! done,
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
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {recbuf, 4096}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    %% the far end takes the bytes late: once the closer the socket hands
    %% its host socket to has looked twice and found nothing taken
    Peer = spawn(fun() ->
                     {ok, Connection} = gen_tcp:accept(Listen),
                     receive {go, Closer} -> ok end,
                     ok = ern_waits:called(Closer, {ern_tcp, lingering, 5}, 2),
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
               ern_rt:send(Socket, 'Close'),
               ern_rt:timed(),
               receive {'DOWN', SocketRef, process, _, _} -> ern_rt:untimed() end,
               {connected, Closer} = erlang:port_info(HostSocket, connected),
               Peer ! {go, Closer}
           end, <<"main">>, quiet()),
    ?assertEqual({'Right', 'Unit'}, wait(written)),
    HostSockets = wait(host_sockets),
    ?assertEqual({Size, {error, closed}}, receive {taken, Taken} -> Taken after 20000 -> none end),
    ?assertEqual(HostSockets, gone(HostSockets, 3000)),
    gen_tcp:close(Listen).

%% Every byte the far end reads, and how the connection then ends.
taken(Connection, Count) ->
    case gen_tcp:recv(Connection, 0, 10000) of
        {ok, Bytes} -> taken(Connection, Count + byte_size(Bytes));
        Ended -> {Count, Ended}
    end.

%% Until the socket's writer waits inside the host's send with more than a
%% write's bytes before it in the host's queue, which the host never takes:
%% a send the host finishes at once waits in the same function, so the
%% queue is what says that this one is held. Both change only as the
%% writer runs, so they are read each time it is scheduled out.
held(Socket, Size) ->
    Pid = ern_rt:process_of(Socket),
    {links, Links} = erlang:process_info(Pid, links),
    [Writer] = [Linked || Linked <- Links, is_pid(Linked),
                          Linked =/= ern_rt:system_process(tcp)],
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

%% Which side of an Either a result is, Left or Right.
side({Side, _}) -> Side.

quiet() ->
    #{stdout => fun(_) -> ok end}.

%% A wait the deadlock detector reads as timed, as the compiler's timed receive is,
%% for an absence, of a time derived from what it waits for.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

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
%% file; a read after the far end's close answers `Left(Closed)`. Written
%% after the code, a regression test; it does not cover a chain of more
%% than one intermediate
tls_both_ways_test() ->
    #{ca := Ca, server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               Self ! {port, Port},
               Main = self(),
               Client = spawn(fun() ->
                                  {'Right', Socket} = connect_tls(<<"localhost">>, Port,
                                                                  verified(Ca), 5000),
                                  Self ! {client_wrote, write(Socket, <<"ping">>)},
                                  Self ! {client_read, read(Socket, 5000)},
                                  Self ! {client_ends, {remote(Socket), local(Socket)}},
                                  ern_rt:send(Socket, 'Close'),
                                  Main ! closed,
                                  receive done -> ok end
                              end),
               {'Right', Accepted} = accept(Listener, 5000),
               Self ! {server_read, read(Accepted, 5000)},
               Self ! {server_wrote, write(Accepted, <<"pong">>)},
               Self ! {server_ends, {remote(Accepted), local(Accepted)}},
               receive closed -> ok end,
               Self ! {after_close, read(Accepted, 5000)},
               %% by its address, which the certificate names too
               ByAddress = spawn(fun() ->
                                     Main ! {by_address, side(connect_tls(<<"127.0.0.1">>, Port,
                                                                          verified(Ca), 5000))},
                                     receive done -> ok end
                                 end),
               {'Right', _} = accept(Listener, 5000),
               receive {by_address, _} = Connected -> Self ! Connected end,
               [Connector ! done || Connector <- [Client, ByAddress]]
           end),
    Port = wait(port),
    ?assertEqual({'Right', 'Unit'}, wait(client_wrote)),
    ?assertEqual({'Right', <<"ping">>}, wait(server_read)),
    ?assertEqual({'Right', 'Unit'}, wait(server_wrote)),
    ?assertEqual({'Right', <<"pong">>}, wait(client_read)),
    {{'Right', {'Endpoint', <<"127.0.0.1">>, Port}},
     {'Right', {'Endpoint', <<"127.0.0.1">>, ClientPort}}} = wait(client_ends),
    ?assertMatch({{'Right', {'Endpoint', <<"127.0.0.1">>, ClientPort}},
                  {'Right', {'Endpoint', <<"127.0.0.1">>, Port}}}, wait(server_ends)),
    ?assertEqual({'Left', 'Closed'}, wait(after_close)),
    ?assertEqual('Right', wait(by_address)).

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
               Main = self(),
               _ = spawn(fun() ->
                             {'Right', Socket} = connect_tls(<<"localhost">>, Port,
                                                             'Unverified', 5000),
                             Main ! connected,
                             Read = read(Socket, 5000),
                             Self ! {reads, [Read, read(Socket, 5000)]},
                             Self ! {wrote, write(Socket, <<"late">>)},
                             Main ! done
                         end),
               {'Right', Accepted} = accept(Listener, 5000),
               receive connected -> ok end,
               {'Right', 'Unit'} = write(Accepted, <<"bye">>),
               ern_rt:send(Accepted, 'Close'),
               receive done -> ok end
           end),
    ?assertEqual([{'Right', <<"bye">>}, {'Left', 'Closed'}], wait(reads)),
    ?assertEqual({'Left', 'Closed'}, wait(wrote)).

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
               Self ! {unverified, side(connect_tls(<<"localhost">>, Port, 'Unverified', 5000))},
               Acceptor ! done
           end),
    ?assertMatch({'Left', {'Other', _}}, wait(by_name)),
    ?assertMatch({'Left', {'Other', _}}, wait(by_address)),
    ?assertEqual('Right', wait(unverified)).

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
                   Self ! {named, side(connect_tls(<<"www.example.test">>, Port,
                                                   verified(Ca), 5000))},
                   Self ! {outside, connect_tls(<<"other.test">>, Port, verified(Ca), 5000)},
                   Acceptor ! done
               end)
    after
        inet_db:del_host({127, 0, 0, 1}),
        inet_db:set_lookup(Lookup)
    end,
    ?assertEqual('Right', wait(named)),
    ?assertMatch({'Left', {'Other', _}}, wait(outside)).

%% report Appendix E.18: a client whose authority did not sign the server's
%% certificate fails its handshake, `connectTls` answering
%% `Left(Other(text))`; the server's socket, which `accept` answered before
%% its handshake, answers its first read with the handshake's failure,
%% `Left(Other(text))`, and the next `Left(Closed)`. Each text is the
%% host's without the line feed that ends ssl's. Written after the code, a
%% regression test
tls_unknown_authority_test() ->
    #{other_ca := OtherCa, server := Server} = pki(),
    Self = self(),
    ok = quietly(
           fun() ->
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               _ = spawn(fun() ->
                             Self ! {client, connect_tls(<<"localhost">>, Port,
                                                         verified(OtherCa), 5000)}
                         end),
               {'Right', Accepted} = accept(Listener, 5000),
               Read = read(Accepted, 5000),
               Self ! {reads, [Read, read(Accepted, 5000)]}
           end),
    {'Left', {'Other', ClientText}} = wait(client),
    [{'Left', {'Other', ServerText}}, {'Left', 'Closed'}] = wait(reads),
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
               Main = self(),
               Reader = ern_rt:spawn(fun() -> Main ! {read, read(Accepted, 5000)} end,
                                     <<"reader">>),
               Writer = ern_rt:spawn(fun() -> Main ! {wrote, write(Accepted, <<"x">>)} end,
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
    ?assertMatch({'Left', {'Other', _}}, wait(read)),
    ?assertMatch({'Left', {'Other', _}}, wait(wrote)),
    ?assertEqual([{'Left', 'Closed'}, {'Left', 'Closed'}], wait(later)).

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
               Main = self(),
               _ = spawn(fun() ->
                             {'Right', Fast} = connect_tls(<<"localhost">>, Port,
                                                           'Unverified', 5000),
                             {'Right', 'Unit'} = write(Fast, <<"fast">>),
                             Main ! wrote,
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
    ?assertEqual({'Right', <<"fast">>}, wait(second)),
    ?assertEqual({'Left', 'Timeout'}, wait(first)),
    ?assertEqual({'Right', <<"slow">>}, wait(first_later)).

%% report Appendix E.1, E.18: `listenTls` answers `Left(Other(text))`, the
%% host's reason, where the host cannot read the certificate or the key,
%% a file missing or one it may not read, or refuses what it reads, and
%% `Left(Invalid)` for a path that holds U+0000. Written after the code, a
%% regression test; it does not cover a key that does not match its
%% certificate, which the host takes as it listens and refuses at each
%% handshake
listen_tls_refused_test() ->
    #{dir := Dir, server := {Certificate, Key}} = pki(),
    Unreadable = filename:join(Dir, "unreadable.key"),
    {ok, _} = file:copy(Key, Unreadable),
    ok = file:change_mode(Unreadable, 8#000),
    Garbage = filename:join(Dir, "garbage.key"),
    ok = file:write_file(Garbage, <<"no key here\n">>),
    Self = self(),
    ok = quietly(
           fun() ->
               Self ! {listened,
                       [side_of(listen_tls(0, {Certificate, Missing}))
                        || Missing <- [filename:join(Dir, "missing.key"), Unreadable, Garbage]]
                       ++ [side_of(listen_tls(0, {filename:join(Dir, "missing.pem"), Key})),
                           listen_tls(0, {Certificate, Key ++ [0]})]}
           end),
    ?assertEqual([other, other, other, other, {'Left', 'Invalid'}], wait(listened)).

%% report Appendix E.18: `connectTls` to a port where nothing listens
%% answers `Left(Refused)`, as `connect` does; to one whose far end does
%% not shake hands within its milliseconds `Left(Timeout)`; and a file of
%% certificates whose path holds U+0000 `Left(Invalid)`. Written after the
%% code, a regression test
connect_tls_refused_test() ->
    #{ca := Ca} = pki(),
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
                                            verified(Ca ++ [0]), 2000)}
           end),
    gen_tcp:close(Silent),
    ?assertEqual({'Left', 'Refused'}, wait(refused)),
    ?assertEqual({'Left', 'Timeout'}, wait(timeout)),
    ?assertEqual({'Left', 'Invalid'}, wait(invalid)).

%% report Appendix E.18: a listener holds the host's backlog, 5, which the
%% host gives a listen that names none, over TCP and over TLS alike. The
%% host does not answer its backlog to `inet:getopts`, so the kernel's
%% table is read, `ss`'s Send-Q of the listening socket, where `ss` is
%% installed. Written after the code, a regression test; it does not cover
%% how many connections the kernel holds against the backlog, which Linux
%% makes one more
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
            ?assertEqual([5, 5], wait(backlogs))
    end.

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
    ok = quietly(fun() -> Self ! {listened, side(listen_tls(0, Server))} end),
    ?assertEqual('Right', wait(listened)),
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
    %% its host socket to has looked twice and found nothing taken
    {FarEnd, FarPort} = tls_far_end(Server, fun(Accepted) ->
                                           receive {go, Closer} -> ok end,
                                           ok = ern_waits:called(Closer,
                                                                 {ern_tcp, lingering, 5}, 2),
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
               erlang:trace(SocketPid, true, [procs, {tracer, self()}]),
               SocketRef = erlang:monitor(process, SocketPid),
               ern_rt:send(Socket, 'Close'),
               ern_rt:timed(),
               Closer = receive {trace, SocketPid, spawn, Spawned, _} -> Spawned end,
               receive {'DOWN', SocketRef, process, _, _} -> ern_rt:untimed() end,
               FarEnd ! {go, Closer}
           end),
    ?assertEqual({'Right', 'Unit'}, wait(written)),
    HostSockets = wait(host_sockets),
    ?assertEqual({Size, {error, closed}}, receive {taken, Taken} -> Taken after 20000 -> none end),
    ?assertEqual(HostSockets, gone(HostSockets, 9000)).

%% Every byte the far end over TLS reads, and how the connection then ends.
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
    {FarEnd, wait(far_port)}.

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
%% `ca`, another's, `other_ca`, and two servers' certificates, each its
%% chain of one intermediate after it, with their keys, which `ca` signed:
%% `server`, which names localhost by name and by address, `elsewhere`,
%% which names another host, and `wildcard`, which names the hosts under
%% example.test through a wildcard.
-spec pki() -> #{atom() => term()}.
pki() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_tcp_tls_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir ++ "/"),
    Root = public_key:pkix_test_root_cert("Ernest test authority", key_options()),
    Other = public_key:pkix_test_root_cert("Ernest other authority", key_options()),
    #{dir => Dir,
      ca => pem(Dir, "ca.pem", [maps:get(cert, Root)]),
      other_ca => pem(Dir, "other_ca.pem", [maps:get(cert, Other)]),
      server => server(Dir, "server", Root, [{dNSName, "localhost"},
                                             {iPAddress, <<127, 0, 0, 1>>}]),
      elsewhere => server(Dir, "elsewhere", Root, [{dNSName, "elsewhere.example"}]),
      wildcard => server(Dir, "wildcard", Root, [{dNSName, "*.example.test"}])}.

%% A server's certificate file, its intermediate after it, and its key's
%% file, its certificate naming AltNames.
server(Dir, Name, Root, AltNames) ->
    Names = #'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                         extnValue = AltNames},
    Configuration = public_key:pkix_test_data(#{root => Root,
                                                intermediates => [key_options()],
                                                peer => [{extensions, [Names]}
                                                         | key_options()]}),
    Certificate = proplists:get_value(cert, Configuration),
    {KeyType, Key} = proplists:get_value(key, Configuration),
    Chain = proplists:get_value(cacerts, Configuration) -- [maps:get(cert, Root)],
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
quietly(Main) ->
    quiet_host(fun() -> ern_rt:run_main(Main, <<"main">>, quiet()) end).

quiet_host(Work) ->
    {ok, #{level := Level}} = logger:get_handler_config(default),
    ok = logger:set_handler_config(default, level, warning),
    try
        Work()
    after
        logger:set_handler_config(default, level, Level)
    end.

%% Which side of an Either a result is, `other` for a Left(Other(_)).
side_of({'Left', {'Other', _}}) -> other;
side_of(Either) -> Either.

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

port(Listener) ->
    ern_rt:call_forever(Listener, fun(Reply) -> {'Port', Reply} end).

accept(Listener, Ms) ->
    Owner = self(),
    ern_rt:call_forever(Listener, fun(Reply) -> {'Accept', Ms, Owner, Reply} end).

write(Socket, Bytes) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Write', Bytes, 60000, Reply} end).

read(Socket, Ms) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Read', Ms, Reply} end).

remote(Socket) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Remote', Reply} end).

local(Socket) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Local', Reply} end).

wait(Tag) ->
    receive {Tag, Value} -> Value after 5000 -> timeout end.
