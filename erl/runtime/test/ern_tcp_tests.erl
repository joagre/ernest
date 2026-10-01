%% Report Appendix E.18: the processes behind a listener and a socket.
-module(ern_tcp_tests).

-include_lib("eunit/include/eunit.hrl").

%% Appendix E.18, report §6.6: a read that timed out leaves the socket
%% delivering to the reads after it. A regression test: the socket asked
%% for one packet per read that found nothing waiting, and the packet went
%% to the read that had timed out, so the next read was never answered
read_after_timeout_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Me = self(),
    Peer = spawn(fun() ->
                     {ok, Conn} = gen_tcp:accept(Listen),
                     receive go -> ok end,
                     ok = gen_tcp:send(Conn, <<"a">>),
                     timer:sleep(100),
                     ok = gen_tcp:send(Conn, <<"b">>),
                     receive done -> gen_tcp:close(Conn) end
                 end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               {'Left', 'Timeout'} = read(Socket, 20),
               Peer ! go,
               Me ! {read, read(Socket, 2000)},
               Me ! {read, read(Socket, 2000)},
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
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               {'Right', Port} = port(Listener),
               Me ! {port, Port},
               Me ! {first, accept(Listener, 300)},
               %% a foreign call, which the deadlock detector counts
               {ok, Conn} = ern_rt:in_foreign(fun() ->
                                                  gen_tcp:connect("127.0.0.1", Port,
                                                                  [binary, {active, false}])
                                              end),
               Me ! {second, element(1, accept(Listener, 2000))},
               gen_tcp:close(Conn)
           end, <<"main">>, quiet()),
    ?assert(wait(port) > 0),
    ?assertEqual({'Left', 'Timeout'}, wait(first)),
    ?assertEqual('Right', wait(second)).

%% Appendix E.18 (L3): a socket lives until it is closed: after the far end
%% closes, what came before is read, then each read, `peer` and `local`
%% answer `Left(Closed)`; a read after `Tcp.close` faults the reader, as a
%% callForever on an ended process does: `callee was closed` where the
%% close ends the socket while the read waits, and `callee had ended` where
%% it had ended before (§6.6). The first is a regression test of the rule of
%% 2026-10-01, before which it said the callee returned; the socket is held
%% still until both the close and the read wait in its mailbox
socket_lives_until_closed_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    spawn(fun() ->
              {ok, Conn} = gen_tcp:accept(Listen),
              ok = gen_tcp:send(Conn, <<"x">>),
              gen_tcp:close(Conn)
          end),
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               {'Right', {'Endpoint', <<"127.0.0.1">>, Port}} = peer(Socket),
               {'Right', {'Endpoint', <<"127.0.0.1">>, _}} = local(Socket),
               sleep(100),
               Me ! {reads, [read(Socket, 1000), read(Socket, 1000), read(Socket, 1000),
                             peer(Socket), local(Socket)]},
               Pid = ern_rt:process_of(Socket),
               erlang:suspend_process(Pid),
               ern_rt:send(Socket, 'Close'),
               %% monitored from its start: a reader that faulted before a
               %% monitor was made would be `Unknown`, as the test once saw
               %% under load
               _ = ern_rt:spawn_monitored('Local', fun() -> read(Socket, 1000) end,
                                         fun(D) -> {down, D} end, <<"reader">>),
               ern_rt:in_foreign(fun() -> queued(Pid, 2) end),
               erlang:resume_process(Pid),
               receive {down, D} -> Me ! {down, D} end,
               _ = ern_rt:spawn_monitored('Local', fun() -> read(Socket, 1000) end,
                                         fun(L) -> {later, L} end, <<"reader">>),
               receive {later, L} -> Me ! {later, L} end
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    ?assertEqual([{'Right', <<"x">>}, {'Left', 'Closed'}, {'Left', 'Closed'},
                  {'Left', 'Closed'}, {'Left', 'Closed'}], wait(reads)),
    ?assertMatch({'Down', {'Fault', <<"callee was closed">>}, _}, wait(down)),
    ?assertMatch({'Down', {'Fault', <<"callee had ended">>}, _}, wait(later)).

%% Appendix E.18: closing a listener answers an accept waiting on it with
%% `Left(Closed)`, and the listener's process ends. Under load the close
%% could come before the accept's worker began, and the host's `einval`
%% was answered `Other("invalid argument")`; that race is not forced here
close_listener_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               Main = self(),
               %% the accept is at the listener before the close is sent, since
               %% it is sent before `sent`; a spawned accept and a pause before
               %% the close raced it, and the close could come first
               _ = erlang:spawn(fun() ->
                                    Alias = erlang:alias(),
                                    Pid ! {'Accept', 5000, self(), Alias},
                                    Main ! sent,
                                    Me ! {accepted, receive {Alias, answered, V} -> V
                                                    after 5000 -> timeout end}
                                end),
               %% foreign calls, which the deadlock detector counts
               ern_rt:in_foreign(fun() -> receive sent -> ok end end),
               Down = erlang:monitor(process, Pid),
               ern_rt:send(Listener, 'CloseListener'),
               ern_rt:in_foreign(fun() -> receive {'DOWN', Down, _, _, _} -> ok end end),
               Me ! {alive, erlang:is_process_alive(Pid)}
           end, <<"main">>, quiet()),
    ?assertEqual({'Left', 'Closed'}, wait(accepted)),
    ?assertEqual(false, wait(alive)).

%% report §6.6, Appendix E.18: an accept that waits as the listener's close
%% ends it faults with `callee was closed`. A regression test of the rule
%% of 2026-10-01; the listener is held still until both the close and the
%% accept wait in its mailbox
accept_meets_the_close_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(0),
               Pid = ern_rt:process_of(Listener),
               erlang:suspend_process(Pid),
               ern_rt:send(Listener, 'CloseListener'),
               _ = ern_rt:spawn_monitored('Local', fun() -> accept(Listener, 1000) end,
                                         fun(D) -> {down, D} end, <<"acceptor">>),
               ern_rt:in_foreign(fun() -> queued(Pid, 2) end),
               erlang:resume_process(Pid),
               receive {down, D} -> Me ! {down, D} end
           end, <<"main">>, quiet()),
    ?assertMatch({'Down', {'Fault', <<"callee was closed">>}, _}, wait(down)).

%% report §8.6: a socket killed while a read waits on it holds no source,
%% so the deadlock of what is left is still found. A regression test for
%% the count of sources, which a killed holder could leave up for good
killed_socket_test() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    spawn(fun() -> {ok, _} = gen_tcp:accept(Listen), receive after 5000 -> ok end end),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Socket} = connect(Port, 2000),
                   Reader = ern_rt:spawn('Local', fun() -> read(Socket, 100000) end,
                                         <<"reader">>),
                   ern_rt:monitor(Reader, fun(D) -> {down, D} end),
                   sleep(100),
                   ern_rt:kill(Socket),
                   receive {down, _} -> ok end,
                   receive never -> ok end
               end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    ?assertEqual({fault, <<"deadlock">>}, Result).

%% Appendix E.18, report §8.6: a port out of range is answered as an error,
%% `Invalid`, by `listen` and `connect` alike, and the program is still found
%% deadlocked after. A regression test: the host raised, the request was
%% never answered, and a connect left its wait counted for good, so no
%% deadlock was found again
port_out_of_range_test() ->
    Me = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Me ! {listened, listen(70000)},
                   Me ! {connected, connect(70000, 1000)},
                   receive never -> ok end
               end, <<"main">>, quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, wait(listened)),
    ?assertEqual(Refused, wait(connected)),
    ?assertEqual({fault, <<"deadlock">>}, Result).

%% Appendix E.18: a host that holds U+0000 names none, `Invalid`, by
%% `listen` and `connect` alike, and the program is still found deadlocked
%% after. A
%% regression test: the host raised an exit the worker did not catch, the
%% caller waited for good, and no deadlock was found (findings.md's C1-1)
host_with_nul_test() ->
    Me = self(),
    Result = ern_rt:run_main(
               fun() ->
                   Me ! {listened, listen(<<"127.0.0.1", 0, "evil">>, 0)},
                   Me ! {connected, connect(<<"127.0.0.1", 0, "evil">>, 1, 1000)},
                   receive never -> ok end
               end, <<"main">>, quiet()),
    Refused = {'Left', 'Invalid'},
    ?assertEqual(Refused, wait(listened)),
    ?assertEqual(Refused, wait(connected)),
    ?assertEqual({fault, <<"deadlock">>}, Result).

%% Appendix E.18: `connect` reaches the address its host names, IPv6's
%% too. A regression test: the host's name went to the host without its
%% family, and `::1` was answered `Other("non-existing domain")`
%% (findings.md's C1-24)
connect_ipv6_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(<<"::1">>, 0),
               {'Right', Port} = port(Listener),
               Me ! {connected, element(1, connect(<<"::1">>, Port, 2000))}
           end, <<"main">>, quiet()),
    ?assertEqual('Right', wait(connected)).

%% Appendix E.1, E.18: a reason of the host's that no constructor of
%% Io.Error names is answered in the host's words, a port already in use
%% "address already in use". A regression test: `Other` held the code,
%% "eaddrinuse"; it does not cover a reason the host has no words for,
%% which keeps its printed form
port_in_use_test() ->
    {ok, Taken} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Taken),
    Me = self(),
    ok = ern_rt:run_main(fun() -> Me ! {listened, listen(Port)} end, <<"main">>, quiet()),
    gen_tcp:close(Taken),
    ?assertEqual({'Left', {'Other', <<"address already in use">>}}, wait(listened)).

%% Appendix E.18: a listener listens on the interface its host names, the
%% loopback alone for "127.0.0.1". A regression test: `listen` took the
%% port alone and listened on every interface, 127.0.0.2's among them
listen_on_the_named_interface_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Listener} = listen(<<"127.0.0.1">>, 0),
               {'Right', Port} = port(Listener),
               %% foreign calls, which the deadlock detector counts
               Me ! {loopback, ern_rt:in_foreign(fun() -> reach("127.0.0.1", Port) end)},
               Me ! {other, ern_rt:in_foreign(fun() -> reach("127.0.0.2", Port) end)}
           end, <<"main">>, quiet()),
    ?assertEqual(ok, wait(loopback)),
    ?assertMatch({error, _}, wait(other)).

reach(Host, Port) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}], 1000) of
        {ok, Socket} -> gen_tcp:close(Socket);
        Error -> Error
    end.

%% Appendix E.18: a write the far end holds back holds up no read of the
%% socket, and the read's time limit holds. A regression test: the
%% socket's process wrote itself, and a read behind a write that waited
%% waited with it, past its limit
write_holds_up_no_read_test_() ->
    {timeout, 60, fun write_holds_up_no_read/0}.

write_holds_up_no_read() ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}]),
    {ok, Port} = inet:port(Listen),
    Me = self(),
    %% the far end accepts and never reads
    Peer = spawn(fun() ->
                     {ok, Conn} = gen_tcp:accept(Listen),
                     receive done -> gen_tcp:close(Conn) end
                 end),
    ok = ern_rt:run_main(
           fun() ->
               {'Right', Socket} = connect(Port, 2000),
               %% the host queues one write whole and holds the next back
               Chunk = binary:copy(<<0>>, 1024 * 1024),
               _ = ern_rt:spawn('Local', fun() ->
                                             [write(Socket, Chunk) || _ <- lists:seq(1, 64)]
                                         end, <<"flood">>),
               sleep(200),
               Before = erlang:monotonic_time(millisecond),
               Read = read(Socket, 300),
               Me ! {read, Read, erlang:monotonic_time(millisecond) - Before}
           end, <<"main">>, quiet()),
    Peer ! done,
    gen_tcp:close(Listen),
    {read, Read, Took} = receive {read, _, _} = M -> M after 10000 -> timeout end,
    ?assertEqual({'Left', 'Timeout'}, Read),
    ?assert(Took < 2000).

%% report §6.9, Appendix E.18: a listener is owned by the process that
%% opened it and is killed when that process dies. A regression test of the
%% rule of 2026-10-01, before which a listener belonged to no one and lived
%% until the program ended
listener_ends_with_its_owner_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Main = self(),
               _ = erlang:spawn(fun() -> Main ! {opened, listen(0)} end),
               {'Right', Listener} = ern_rt:in_foreign(fun() -> receive {opened, L} -> L end end),
               Down = erlang:monitor(process, ern_rt:process_of(Listener)),
               Me ! {ended, ern_rt:in_foreign(fun() ->
                                                  receive {'DOWN', Down, _, _, R} -> R
                                                  after 5000 -> alive
                                                  end
                                              end)}
           end, <<"main">>, quiet()),
    ?assertEqual({ern, killed}, wait(ended)).

quiet() ->
    #{stdout => fun(_) -> ok end}.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
%% Until the process holds at least Count messages.
queued(Pid, Count) ->
    case erlang:process_info(Pid, message_queue_len) of
        {message_queue_len, N} when N >= Count -> ok;
        _ -> timer:sleep(5), queued(Pid, Count)
    end.

sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

listen(Port) ->
    listen(<<"127.0.0.1">>, Port).

listen(Host, Port) ->
    %% report §6.9, Appendix E.18: the caller owns the listener
    Owner = self(),
    ern_rt:call_forever(ern_rt:sys(tcp), fun(R) -> {'Listen', Host, Owner, Port, R} end).

connect(Port, Ms) ->
    connect(<<"127.0.0.1">>, Port, Ms).

connect(Host, Port, Ms) ->
    %% report Appendix E.18: the caller owns the socket
    Owner = self(),
    ern_rt:call_forever(ern_rt:sys(tcp), fun(R) -> {'Connect', Host, Ms, Owner, Port, R} end).

port(Listener) ->
    ern_rt:call_forever(Listener, fun(R) -> {'Port', R} end).

accept(Listener, Ms) ->
    Owner = self(),
    ern_rt:call_forever(Listener, fun(R) -> {'Accept', Ms, Owner, R} end).

write(Socket, Bytes) ->
    ern_rt:call_forever(Socket, fun(R) -> {'Send', Bytes, 60000, R} end).

read(Socket, Ms) ->
    ern_rt:call_forever(Socket, fun(R) -> {'Recv', Ms, R} end).

peer(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'FarEnd', R} end).

local(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'NearEnd', R} end).

wait(Tag) ->
    receive {Tag, V} -> V after 5000 -> timeout end.
