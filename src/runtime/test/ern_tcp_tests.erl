%% Report Appendix E.18: the processes behind a listener and a socket.
-module(ern_tcp_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").

-export([pki/0]).

%% Report Appendix E.18: the window in which a socket that has ended may
%% send what the far end has not taken with nothing taken, and the time
%% the host's ssl takes to close a connection, in two waits of 5 seconds
%% of its own.
-define(LINGER_IDLE, 5000).
-define(TLS_CLOSE, 10000).

%% Appendix E.18, E.0 shape rule 8: a read given no time, 0 or below, has
%% run out as it begins and answers `Left(Timeout)`, whatever has arrived,
%% and takes nothing: the far end's bytes go to the read with time after it,
%% and its close to the next, and once the connection has closed a read
%% given no time answers `Left(Timeout)` still. A regression test: before
%% the rule, a read given no time answered the bytes that had arrived
read_given_no_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    Peer = spawn(fun() ->
                     {ok, Accepted} = gen_tcp:accept(Listen),
                     ok = gen_tcp:send(Accepted, <<"x">>),
                     receive close -> gen_tcp:close(Accepted) end
                 end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               Before = [read(Socket, 0), read(Socket, -5)],
               Bytes = read(Socket, 5000),
               Peer ! close,
               Closed = read(Socket, 5000),
               Self ! {reads, {Before, Bytes, Closed, read(Socket, 0)}}
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout], {'Right', <<"x">>}, {'Left', 'Closed'}, Timeout},
                 wait(reads)).

%% Appendix E.18, E.0 shape rule 8: a write given no time, 0 or below, has
%% run out as it begins, answers `Left(Timeout)` and gives the host nothing:
%% the far end reads the one write that had time, and nothing before it. A
%% regression test: before the rule, the bytes went to the host and the
%% write answered whichever came first, its time or the host's taking them
write_given_no_time_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
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
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual([Timeout, Timeout, {'Right', 'Unit'}], wait(writes)),
    ?assertEqual({ok, <<"z">>}, wait(far_end)).

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
               Self ! {accepts, {Before, side(accept(Listener, 5000))}},
               gen_tcp:close(Client)
           end, <<"main">>, quiet()),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout], 'Right'}, wait(accepts)).

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
               Self ! {connects, {NoTime, side(connect(Port, 2000))}}
           end),
    gen_tcp:close(Listen),
    Timeout = {'Left', 'Timeout'},
    ?assertEqual({[Timeout, Timeout, Timeout, Timeout], 'Right'}, wait(connects)).

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

%% Appendix E.18: a socket lives until it is closed: after the far end
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

%% Appendix E.18, report §8.6: a read whose caller has ended before it is
%% answered is dropped as one that times out is, the bytes that arrive after
%% it the next read's, and its count as a source ends with it, so that the
%% program is found deadlocked after. A regression test: before the rule,
%% the read took the bytes for its ended caller; a read that waits for a
%% handshake, dropped the same way, and a caller that ends while the bytes
%% are on their way, before the socket has its `DOWN`, are not covered
read_of_an_ended_caller_dropped_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Self = self(),
    Peer = spawn(fun() ->
                     {ok, Connection} = gen_tcp:accept(Listen),
                     receive go -> ok end,
                     ok = gen_tcp:send(Connection, <<"x">>),
                     receive done -> gen_tcp:close(Connection) end
                 end),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Socket} = connect(Port, 2000),
                   Reader = ern_rt:spawn_monitored(fun() -> read(Socket, 60000) end,
                                                   fun(Down) -> {reader, Down} end,
                                                   <<"reader">>),
                   Pid = ern_rt:process_of(Reader),
                   ok = ern_waits:watching(Socket, Pid),
                   ern_rt:kill(Reader),
                   receive {reader, _} -> ok end,
                   %% so that its `DOWN` comes before the bytes
                   ok = ern_waits:unwatched(Socket, Pid),
                   Peer ! go,
                   Self ! {read, read(Socket, 2000)},
                   ern_waits:forever()
               end, <<"main">>, quiet()),
    Peer ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Right', <<"x">>}, wait(read)),
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
           end, <<"main">>, quiet()),
    Peer ! done,
    gen_tcp:close(Listen),
    ?assertEqual({'Right', <<"x">>}, wait(read)).

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
%% end refuses, answers `Refused`. A regression test, written after the code
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

%% Appendix E.18: a listener takes connections of its address's family
%% alone, so one on "::" and one on "0.0.0.0" stand on one port together,
%% whichever opens first, and each socket's `remote` reads an address of
%% its connection's family. A regression test: "::" took IPv4 connections
%% too, as ::ffff:127.0.0.1, and "0.0.0.0" beside it was answered
%% `Other("address already in use")`. It does not cover an interface other
%% than the loopback's, nor a machine without IPv6, where it says so
listen_of_one_family_test() ->
    with_ipv6_loopback(
      fun() ->
          Self = self(),
          ok = ern_rt:run_main(
                 fun() ->
                     {'Right', Six} = listen(<<"::">>, 0),
                     {'Right', Port} = port(Six),
                     {'Right', Four} = listen(<<"0.0.0.0">>, Port),
                     {'Right', _} = connect(<<"127.0.0.1">>, Port, 2000),
                     {'Right', FromFour} = accept(Four, 2000),
                     {'Right', _} = connect(<<"::1">>, Port, 2000),
                     {'Right', FromSix} = accept(Six, 2000),
                     {'Right', FourFirst} = listen(<<"0.0.0.0">>, 0),
                     {'Right', Other} = port(FourFirst),
                     Self ! {remotes, {remote(FromFour), remote(FromSix)}},
                     Self ! {six_second, side(listen(<<"::">>, Other))}
                 end, <<"main">>, quiet()),
          ?assertMatch({{'Right', {'Endpoint', <<"127.0.0.1">>, _}},
                        {'Right', {'Endpoint', <<"::1">>, _}}}, wait(remotes)),
          ?assertEqual('Right', wait(six_second))
      end).

%% Appendix E.18: an IPv4 address written as IPv6's, ::ffff:127.0.0.1, is
%% one a listener of IPv6's family alone takes no connection at, which the
%% host refuses, `Invalid`. Written after the code, a regression test of
%% the place E.18 is silent on
listen_on_a_mapped_address_test() ->
    with_ipv6_loopback(
      fun() ->
          Self = self(),
          ok = ern_rt:run_main(fun() -> Self ! {listened, listen(<<"::ffff:127.0.0.1">>, 0)} end,
                               <<"main">>, quiet()),
          ?assertEqual({'Left', 'Invalid'}, wait(listened))
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
%% its bytes, for as long as the far end took nothing, and a write held at
%% the close had whatever answer the writer gave before the exit took it.
%% The 3 minutes' bound is not reached here
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
    %% its host socket to, made with the socket, has looked twice and found
    %% nothing taken
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

%% report Appendix E.21, E.18: a socket's memory counts its writer's, which
%% holds the bytes it wrote until it runs again, where the socket's own
%% process has let them go and no line of `:processes` would show them
%% otherwise, and its closer's, which is there before the socket closes,
%% so that a close at a full table needs no room (§12.5). A regression
%% test, written after the code; the closer's presence is one of the fix,
%% which spawned it at the close. It does not cover a socket over TLS,
%% whose writer is the same process.
socket_memory_counts_its_own_processes_test() ->
    Size = 1 bsl 20,
    Self = self(),
    ok = ern_waits:with_room(fun() ->
         quietly(
           fun() ->
               Main = self(),
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               Peer = spawn(fun() ->
                                {ok, Connected} = gen_tcp:connect("127.0.0.1", Port,
                                                                  [binary, {active, false}]),
                                {ok, _} = gen_tcp:recv(Connected, Size),
                                Main ! taken,
                                receive close -> gen_tcp:close(Connected) end
                            end),
               {'Right', Socket} = accept(Listener, 5000),
               _ = ern_rt:spawn(fun() ->
                                    write(Socket, binary:copy(<<0>>, Size)),
                                    Main ! written
                                end, <<"M.write:1">>),
               receive written -> ok end,
               receive taken -> ok after 5000 -> error(not_taken) end,
               Process = ern_rt:process_of(Socket),
               erlang:garbage_collect(Process),
               {binary, Own} = erlang:process_info(Process, binary),
               {memory, Closer} = erlang:process_info(closer_of(Process), memory),
               {'Some', {'Status', _, _, _, Memory}} = ern_rt:status(Process),
               Self ! {counted, {Own, Memory >= Size + Closer}},
               Peer ! close
           end)
         end),
    ?assertEqual({[], true}, wait(counted)).

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
               Main = self(),
               {'Right', Listener} = listen_tls(0, Server),
               {'Right', Port} = port(Listener),
               Peer = spawn(fun() ->
                                {ok, Connected} = ssl:connect("127.0.0.1", Port,
                                                              [binary, {active, false},
                                                               {verify, verify_none}]),
                                all_taken(Connected, Size),
                                erlang:garbage_collect(),
                                Main ! taken,
                                receive close -> ssl:close(Connected) end
                            end),
               {'Right', Socket} = accept(Listener, 5000),
               _ = ern_rt:spawn(fun() ->
                                    write(Socket, binary:copy(<<0>>, Size)),
                                    Main ! written
                                end, <<"M.write:1">>),
               receive written -> ok end,
               receive taken -> ok after 5000 -> error(not_taken) end,
               ern_rt:timed(),
               Freed = [ern_waits:freed(Holder, Size)
                        || Holder <- hosts_holders(Size, [Peer | Before])],
               Self ! {left, {[Answer || Answer <- Freed, Answer =/= ok, Answer =/= ended],
                              hosts_holders(Size, [Peer | Before])}},
               ern_rt:untimed(),
               Peer ! close
           end)
         end),
    ?assertEqual({[], []}, wait(left)).

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
               Self ! {server_ends, {remote(Accepted), local(Accepted)}},
               Self ! {server_wrote, write(Accepted, <<"pong">>)},
               receive closed -> ok end,
               Self ! {after_close, read(Accepted, 5000)},
               Self ! {ends_after_close, {remote(Accepted), local(Accepted)}},
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
    ?assertEqual({{'Left', 'Closed'}, {'Left', 'Closed'}}, wait(ends_after_close)),
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
               Main = self(),
               _ = spawn(fun() ->
                             Self ! {client, connect_tls(<<"localhost">>, Port,
                                                         verified(OtherCa), 5000)},
                             Main ! client_answered
                         end),
               {'Right', Accepted} = accept(Listener, 5000),
               Read = read(Accepted, 5000),
               Self ! {reads, [Read, read(Accepted, 5000)]},
               receive client_answered -> ok end
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
                 wait(listened)).

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
    ?assertEqual({'Left', 'Refused'}, wait(refused)),
    ?assertEqual({'Left', 'Timeout'}, wait(timeout)),
    ?assertEqual({'Left', 'Invalid'}, wait(invalid)),
    Refused = [{'Left', {'Other', list_to_binary([File, ": ", What])}}
               || {File, What} <- [{Missing, "NotFound"}, {Dir, "NotAFile"},
                                   {NoCertificate, "no certificate"}]],
    ?assertEqual(Refused ++ Refused, wait(files)).

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
               Self ! {held, side(connected(SelfSigned, <<"localhost">>, verified(Held)))},
               Self ! {by_address, side(connected(SelfSigned, <<"127.0.0.1">>, verified(Held)))},
               Self ! {leaf, side(connected(Leaf, <<"localhost">>, verified(HeldLeaf)))},
               Self ! {not_held, connected(SelfSigned, <<"localhost">>, verified(Ca))},
               Self ! {elsewhere, connected(SelfElsewhere, <<"localhost">>, verified(Elsewhere))}
           end),
    ?assertEqual('Right', wait(held)),
    ?assertEqual('Right', wait(by_address)),
    ?assertEqual('Right', wait(leaf)),
    ?assertMatch({'Left', {'Other', _}}, wait(not_held)),
    ?assertMatch({'Left', {'Other', _}}, wait(elsewhere)).

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
%% A regression test, written after the code (C1-2): the host refused each
%% before it looked in the file, and a far end was taken by its own
%% certificate only where it was self-signed. A chain of more than one
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
               Self ! {taken, [side(connected(ServerAlone, <<"localhost">>, verified(Alone)))
                               | [side(connected(Sent, <<"localhost">>, verified(File)))
                                  || Sent <- [Server, Rooted], File <- [Leaf, Intermediate]]]
                              ++ [side(connected(Rooted, <<"localhost">>, verified(Ca)))]},
               Self ! {refused, [connected(ElsewhereAlone, <<"localhost">>,
                                           verified(ElsewhereLone))
                                 | [connected(Sent, <<"localhost">>, verified(ElsewhereLeaf))
                                    || Sent <- [Elsewhere, ElsewhereRooted]]]}
           end),
    ?assertEqual(lists:duplicate(6, 'Right'), wait(taken)),
    ?assertMatch([{'Left', {'Other', _}}, {'Left', {'Other', _}}, {'Left', {'Other', _}}],
                 wait(refused)).

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
    %% its host socket to, made with the socket, has looked twice and found
    %% nothing taken
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
               Closer = closer_of(SocketPid),
               SocketRef = erlang:monitor(process, SocketPid),
               ern_rt:send(Socket, 'Close'),
               ern_rt:timed(),
               receive {'DOWN', SocketRef, process, _, _} -> ern_rt:untimed() end,
               FarEnd ! {go, Closer}
           end),
    ?assertEqual({'Right', 'Unit'}, wait(written)),
    HostSockets = wait(host_sockets),
    ?assertEqual({Size, {error, closed}}, receive {taken, Taken} -> Taken after 20000 -> none end),
    %% the host's socket goes once ssl's close has run, which begins as the
    %% closer, looking a fifth of the idle window apart, finds the bytes
    %% taken, and lasts up to TLS_CLOSE; the idle window again bounds a
    %% failure on a loaded host
    Bound = ?LINGER_IDLE div 5 + ?TLS_CLOSE + ?LINGER_IDLE,
    ?assertEqual(HostSockets, gone(HostSockets, Bound)).

%% The closer a socket's process made as it began, which watches it and
%% waits for its host socket (ern_tcp:closer/1).
closer_of(SocketPid) ->
    {monitored_by, Watching} = erlang:process_info(SocketPid, monitored_by),
    [Closer] = [Pid || Pid <- Watching, is_pid(Pid),
                       erlang:process_info(Pid, current_function)
                           =:= {current_function, {ern_tcp, closer, 1}}],
    Closer.

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
    write(Socket, Bytes, 60000).

write(Socket, Bytes, Ms) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Write', Bytes, Ms, Reply} end).

read(Socket, Ms) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Read', Ms, Reply} end).

remote(Socket) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Remote', Reply} end).

local(Socket) ->
    ern_rt:call_forever(Socket, fun(Reply) -> {'Local', Reply} end).

wait(Tag) ->
    receive {Tag, Value} -> Value after 5000 -> timeout end.
