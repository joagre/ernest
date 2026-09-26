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
    %% the bytes that came after the timeout wait for the next read
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
               ern_rt:spawn('Local', fun() -> Me ! {accepted, accept(Listener, 5000)} end,
                            <<"acceptor">>),
               sleep(100),
               ern_rt:send(Listener, 'CloseListener'),
               sleep(200),
               Me ! {alive, erlang:is_process_alive(ern_rt:process_of(Listener))}
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

quiet() ->
    #{stdout => fun(_) -> ok end}.

%% A wait the deadlock detector counts, as the compiler's timed receive is.
sleep(Ms) ->
    ern_rt:timed(),
    timer:sleep(Ms),
    ern_rt:untimed().

listen(Port) ->
    ern_rt:call_forever(ern_rt:sys(tcp), fun(R) -> {'Listen', Port, R} end).

connect(Port, Ms) ->
    ern_rt:call_forever(ern_rt:sys(tcp),
                        fun(R) -> {'Connect', <<"127.0.0.1">>, Ms, Port, R} end).

port(Listener) ->
    ern_rt:call_forever(Listener, fun(R) -> {'Port', R} end).

accept(Listener, Ms) ->
    ern_rt:call_forever(Listener, fun(R) -> {'Accept', Ms, R} end).

read(Socket, Ms) ->
    ern_rt:call_forever(Socket, fun(R) -> {'Recv', Ms, R} end).

peer(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'FarEnd', R} end).

local(Socket) ->
    ern_rt:call_forever(Socket, fun(R) -> {'NearEnd', R} end).

wait(Tag) ->
    receive {Tag, V} -> V after 5000 -> timeout end.
