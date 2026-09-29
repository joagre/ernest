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
%% callForever on an ended process does (§6.6)
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
               ern_rt:send(Socket, 'Close'),
               Reader = ern_rt:spawn('Local', fun() -> read(Socket, 1000) end, <<"reader">>),
               ern_rt:monitor(Reader, fun(D) -> {down, D} end),
               receive {down, D} -> Me ! {down, D} end
           end, <<"main">>, quiet()),
    gen_tcp:close(Listen),
    ?assertEqual([{'Right', <<"x">>}, {'Left', 'Closed'}, {'Left', 'Closed'},
                  {'Left', 'Closed'}, {'Left', 'Closed'}], wait(reads)),
    ?assertMatch({'Down', {'Fault', _}, _}, wait(down)).

%% Appendix E.18: closing a listener answers an accept waiting on it with
%% `Left(Closed)`, and the listener's process ends
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
                                    Pid ! {'Accept', 5000, Alias},
                                    Main ! sent,
                                    Me ! {accepted, receive {Alias, V} -> V
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
%% by `listen` and `connect` alike, and the program is still found
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
    Refused = {'Left', {'Other', <<"port out of range">>}},
    ?assertEqual(Refused, wait(listened)),
    ?assertEqual(Refused, wait(connected)),
    ?assertEqual({fault, <<"deadlock">>}, Result).

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

quiet() ->
    #{stdout => fun(_) -> ok end}.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

listen(Port) ->
    listen(<<"127.0.0.1">>, Port).

listen(Host, Port) ->
    ern_rt:call_forever(ern_rt:sys(tcp), fun(R) -> {'Listen', Host, Port, R} end).

connect(Port, Ms) ->
    ern_rt:call_forever(ern_rt:sys(tcp),
                        fun(R) -> {'Connect', <<"127.0.0.1">>, Ms, Port, R} end).

port(Listener) ->
    ern_rt:call_forever(Listener, fun(R) -> {'Port', R} end).

accept(Listener, Ms) ->
    ern_rt:call_forever(Listener, fun(R) -> {'Accept', Ms, R} end).

write(Socket, Bytes) ->
    ern_rt:call_forever(Socket, fun(R) -> {'Send', Bytes, R} end).

read(Socket, Ms) ->
    ern_rt:call_forever(Socket, fun(R) -> {'Recv', Ms, R} end).

peer(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'FarEnd', R} end).

local(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'NearEnd', R} end).

wait(Tag) ->
    receive {Tag, V} -> V after 5000 -> timeout end.
