%% Report §9.3, Appendix E.18: the process behind a socket.
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
               Tcp = ern_rt:sys(tcp),
               {'Some', {'Right', Socket}} =
                   ern_rt:call(Tcp, fun(R) -> {'Connect', <<"localhost">>, Port, R} end, 2000),
               Read = fun(Ms) -> ern_rt:call(Socket, fun(R) -> {'Recv', R} end, Ms) end,
               'None' = Read(20),
               Peer ! go,
               Me ! {read, Read(2000)},
               Peer ! done
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    gen_tcp:close(Listen),
    ?assertEqual({'Some', {'Right', <<"b">>}},
                 receive {read, R} -> R after 3000 -> timeout end).
