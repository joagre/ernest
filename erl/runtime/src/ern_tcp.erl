%% Report §8.2, Appendix E.18: the process behind Tcp's reference, and the
%% processes behind a listener and a socket. A socket is a process: it owns
%% the port, it dies with the connection, and its address can be monitored,
%% killed, and adapted like any other. Data arrives as {active, once} so a
%% pending Recv is answered as soon as bytes come, and a Send never waits
%% behind a Recv.
-module(ern_tcp).

-export([loop/0]).

%% Report §8.6: every listener and socket is linked to this process, which
%% the runtime kills when the program ends, so none outlives it; this
%% process traps the exits, so that one ending takes nothing else with it.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self()).

serve(Tcp) ->
    receive
        {'Listen', Port, Reply} ->
            erlang:spawn(fun() -> listen(Tcp, Port, Reply) end),
            serve(Tcp);
        {'Connect', Host, Port, Reply} ->
            erlang:spawn(fun() -> connect(Tcp, Host, Port, Reply) end),
            serve(Tcp);
        {'EXIT', _, _} ->
            serve(Tcp)
    end.

listen(Tcp, Port, Reply) ->
    Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw}],
    case gen_tcp:listen(Port, Options) of
        {ok, Socket} ->
            Listener = erlang:spawn(fun() -> link(Tcp), listener_loop(Tcp, Socket) end),
            gen_tcp:controlling_process(Socket, Listener),
            ern_rt:answer(Reply, {'Right', Listener});
        {error, Reason} ->
            ern_rt:answer(Reply, {'Left', io_error(Reason)})
    end.

connect(Tcp, Host, Port, Reply) ->
    Options = [binary, {active, false}, {packet, raw}],
    case gen_tcp:connect(unicode:characters_to_list(Host), Port, Options) of
        {ok, Socket} -> ern_rt:answer(Reply, {'Right', socket_process(Tcp, Socket)});
        {error, Reason} -> ern_rt:answer(Reply, {'Left', io_error(Reason)})
    end.

%% A listener answers each Accept, one worker per request, so that a slow
%% peer does not hold up the next accept.
listener_loop(Tcp, Socket) ->
    receive
        {'Accept', Reply} ->
            erlang:spawn(fun() -> accept(Tcp, Socket, Reply) end),
            listener_loop(Tcp, Socket)
    end.

%% the worker owns what it accepts, and hands it to the socket process,
%% which is the only legal chain: only an owner may pass a socket on
accept(Tcp, Socket, Reply) ->
    case gen_tcp:accept(Socket) of
        {ok, Connection} ->
            ern_rt:answer(Reply, {'Right', socket_process(Tcp, Connection)});
        {error, Reason} ->
            ern_rt:answer(Reply, {'Left', io_error(Reason)})
    end.

socket_process(Tcp, Socket) ->
    Owner = erlang:spawn(fun() -> link(Tcp), socket_loop(Socket, [], []) end),
    gen_tcp:controlling_process(Socket, Owner),
    Owner.

%% Waiting: replies with no bytes yet. Buffer: bytes with no reply yet.
%% The port delivers one packet each time it is asked, and it is asked
%% again while a reply still waits.
socket_loop(Socket, Waiting, Buffer) ->
    receive
        {'Recv', Reply} ->
            case Buffer of
                [Bytes | Rest] ->
                    ern_rt:answer(Reply, {'Right', Bytes}),
                    socket_loop(Socket, Waiting, Rest);
                [] ->
                    inet:setopts(Socket, [{active, once}]),
                    socket_loop(Socket, Waiting ++ [Reply], [])
            end;
        {'Send', Bytes} ->
            case gen_tcp:send(Socket, Bytes) of
                ok -> socket_loop(Socket, Waiting, Buffer);
                {error, _} -> closed(Socket, Waiting)
            end;
        'Close' ->
            closed(Socket, Waiting);
        {tcp, Socket, Bytes} ->
            case Waiting of
                [Reply | Rest] ->
                    ern_rt:answer(Reply, {'Right', Bytes}),
                    Rest =/= [] andalso inet:setopts(Socket, [{active, once}]),
                    socket_loop(Socket, Rest, Buffer);
                [] ->
                    socket_loop(Socket, [], Buffer ++ [Bytes])
            end;
        {tcp_closed, Socket} ->
            closed(Socket, Waiting);
        {tcp_error, Socket, _} ->
            closed(Socket, Waiting)
    end.

%% Report Appendix E.18: the socket dies with the connection, so whoever
%% monitors it learns; a reply still waiting is answered Left(Closed).
closed(Socket, Waiting) ->
    lists:foreach(fun(Reply) -> ern_rt:answer(Reply, {'Left', 'Closed'}) end, Waiting),
    gen_tcp:close(Socket),
    ok.

io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
io_error(closed) -> 'Closed';
io_error(etimedout) -> 'Timeout';
io_error(Reason) -> {'Other', unicode:characters_to_binary(io_lib:format("~p", [Reason]))}.
