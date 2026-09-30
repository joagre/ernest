%% Report §8.2, Appendix E.18: the process behind Tcp's reference, and the
%% processes behind a listener and a socket. A socket is a process: it owns
%% the port and lives until Close, answering each read `Left(Closed)` once
%% its connection has closed, and its address can be monitored, killed, and
%% adapted like any other. Each request that waits carries its milliseconds,
%% and the process that owns the stream decides whether time ran out, so
%% that a request that timed out has taken nothing. A request waiting is a
%% source (report §8.6), counted from its arrival until its answer.
-module(ern_tcp).

-export([loop/0]).

%% Report §8.6: every listener and socket is linked to this process, which
%% the runtime kills when the program ends, so none outlives it; this
%% process traps the exits, so that one ending takes nothing else with it,
%% and forgets what the runtime recorded of the one that ended.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self()).

serve(Tcp) ->
    receive
        {'Listen', Host, Port, Reply} ->
            erlang:spawn(fun() -> listen(Tcp, Host, Port, Reply) end),
            serve(Tcp);
        {'Connect', Host, Ms, Port, Reply} ->
            counted(fun() -> connect(Tcp, Host, Port, ern_rt:deadline(Ms), Reply) end),
            serve(Tcp);
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Tcp)
    end.

%% A worker whose request waits, counted as a source before it starts, so
%% that its answer cannot come before its count; it ends the count itself.
counted(Work) ->
    Worker = erlang:spawn(fun() -> receive go -> Work() end end),
    ern_rt:source_begin(Worker),
    Worker ! go.

%% A listener or a socket, linked to the TCP process and recorded as opened
%% before its address is given out (report §8.6), under the function that
%% opened it (Appendix E.18).
opened(Tcp, Loop, Site) ->
    Pid = erlang:spawn(fun() -> link(Tcp), receive go -> Loop() end end),
    ern_rt:opened(Pid, Site),
    Pid ! go,
    Pid.

%% Report Appendix E.18: a listener on the interface the host's name or
%% address names. Every request is answered: a port out of range, and what
%% the host refuses by raising, are errors as much as what it answers.
listen(Tcp, Host, Port, Reply) ->
    Answer = case {in_range(Port), address(Host)} of
                 {false, _} ->
                     {'Left', {'Other', <<"port out of range">>}};
                 {true, {error, Reason}} ->
                     {'Left', io_error(Reason)};
                 {true, {refused, Why}} ->
                     {'Left', {'Other', Why}};
                 {true, {ok, Address}} ->
                     Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw},
                                {ip, Address} | family(Address)],
                     case guarded(fun() -> gen_tcp:listen(Port, Options) end) of
                         {ok, Socket} ->
                             Listener = opened(Tcp, fun() -> listener_loop(Tcp, Socket) end,
                                               <<"Tcp.listen">>),
                             gen_tcp:controlling_process(Socket, Listener),
                             {'Right', Listener};
                         {error, Reason} ->
                             {'Left', io_error(Reason)}
                     end
             end,
    ern_rt:answer(Reply, Answer).

in_range(Port) ->
    Port >= 0 andalso Port =< 65535.

%% An address the host's name or address stands for, IPv4's first. Report
%% Appendix E.18: a host that holds U+0000 names none.
address(Host) ->
    case binary:match(Host, <<0>>) of
        nomatch -> named(unicode:characters_to_list(Host));
        _ -> {refused, <<"a host holds U+0000">>}
    end.

named(Name) ->
    case inet:parse_address(Name) of
        {ok, Address} ->
            {ok, Address};
        {error, _} ->
            case guarded(fun() -> inet:getaddr(Name, inet) end) of
                {ok, Address} -> {ok, Address};
                {error, _} -> guarded(fun() -> inet:getaddr(Name, inet6) end)
            end
    end.

family({_, _, _, _, _, _, _, _}) -> [inet6];
family(_) -> [].

%% What the host raises for an input it refuses, as the error it would be,
%% whatever the class it raises: a worker that dies of one answers nothing.
guarded(Call) ->
    try Call()
    catch _:Reason -> {error, Reason}
    end.

%% Report Appendix E.18: a connect that times out takes no connection, since
%% the host closes one it completes after its own time limit. A limit past
%% the host's longest timer is waited in slices, each a new attempt.
connect(Tcp, Host, Port, Deadline, Reply) ->
    Options = [binary, {active, false}, {packet, raw}],
    Try = fun() ->
              case {in_range(Port), address(Host)} of
                  {false, _} ->
                      {refused, <<"port out of range">>};
                  {true, {ok, Address}} ->
                      %% report Appendix E.18: the address the host names, of
                      %% its own family, IPv6's included
                      guarded(fun() ->
                                  gen_tcp:connect(Address, Port, Options ++ family(Address),
                                                  ern_rt:remaining(Deadline))
                              end);
                  {true, Other} ->
                      Other
              end
          end,
    attempt(Tcp, Try, Deadline, Reply, <<"Tcp.connect">>).

%% Report Appendix E.18: a connect or an accept, tried again after the
%% host's timeout until the deadline has passed, and its answer given: the
%% socket's process, Timeout, or why it failed.
attempt(Tcp, Try, Deadline, Reply, Site) ->
    Answer = case Try() of
                 {ok, Socket} ->
                     {'Right', socket_process(Tcp, Socket, Site)};
                 {error, timeout} ->
                     case ern_rt:remaining(Deadline) of
                         0 -> {'Left', 'Timeout'};
                         _ -> again
                     end;
                 {error, Reason} ->
                     {'Left', io_error(Reason)};
                 {refused, Why} ->
                     {'Left', {'Other', Why}}
             end,
    case Answer of
        again ->
            attempt(Tcp, Try, Deadline, Reply, Site);
        _ ->
            ern_rt:answer(Reply, Answer),
            ern_rt:source_end()
    end.

%% A listener answers each Accept by a worker of its own, so that a slow
%% accept does not hold up the next request, and ends at CloseListener,
%% whose close of the socket answers each accept still waiting.
listener_loop(Tcp, Socket) ->
    receive
        {'Accept', Ms, Reply} ->
            counted(fun() -> accept(Tcp, Socket, ern_rt:deadline(Ms), Reply) end),
            listener_loop(Tcp, Socket);
        {'Port', Reply} ->
            ern_rt:answer(Reply, case inet:port(Socket) of
                                     {ok, Port} -> {'Right', Port};
                                     {error, Reason} -> {'Left', io_error(Reason)}
                                 end),
            listener_loop(Tcp, Socket);
        'CloseListener' ->
            gen_tcp:close(Socket)
    end.

%% The worker owns what it accepts, and hands it to the socket process,
%% which is the only legal chain: only an owner may pass a socket on. An
%% accept that times out has taken no connection.
accept(Tcp, Socket, Deadline, Reply) ->
    attempt(Tcp, fun() -> gen_tcp:accept(Socket, ern_rt:remaining(Deadline)) end, Deadline, Reply,
            <<"Tcp.accept">>).

socket_process(Tcp, Socket, Site) ->
    Owner = opened(Tcp, fun() ->
                            Self = erlang:self(),
                            Writer = erlang:spawn_link(fun() -> writer(Socket, Self) end),
                            socket_loop(Socket, Writer, [], <<>>, open)
                        end, Site),
    gen_tcp:controlling_process(Socket, Owner),
    Owner.

%% Report Appendix E.18: a socket's writes, one after another in the order
%% they came, in a process of their own, so that a write the far end holds
%% back holds up no read and no read's time limit. A write is counted as a
%% source by the socket, which the writer tells when it has answered, and
%% whether the connection had gone. Report Appendix E.18: the answer says
%% whether the socket took the bytes, and why not.
writer(Socket, Owner) ->
    receive
        {'Send', Bytes, Reply} ->
            Sent = gen_tcp:send(Socket, Bytes),
            ern_rt:answer(Reply, case Sent of
                                     ok -> {'Right', 'Unit'};
                                     {error, Reason} -> {'Left', io_error(Reason)}
                                 end),
            Owner ! {written, Sent},
            writer(Socket, Owner);
        stop ->
            ok
    end.

%% Waiting: the reads with no bytes yet, oldest first, each {Ref, Reply,
%% Deadline, Timer}. Buffer: the bytes no read has taken. The port is asked for
%% bytes only while a read waits, so a program that stops reading holds the
%% far end back. State: open, or closed once the connection has closed.
socket_loop(Socket, Writer, Waiting, Buffer, State) ->
    receive
        {'Recv', Ms, Reply} ->
            case {Buffer, State} of
                {<<>>, open} ->
                    ern_rt:source_begin(),
                    Ref = make_ref(),
                    Deadline = ern_rt:deadline(Ms),
                    Waiting =/= [] orelse inet:setopts(Socket, [{active, once}]),
                    Read = {Ref, Reply, Deadline, arm(Ref, Deadline)},
                    socket_loop(Socket, Writer, Waiting ++ [Read], <<>>, State);
                {<<>>, closed} ->
                    ern_rt:answer(Reply, {'Left', 'Closed'}),
                    socket_loop(Socket, Writer, Waiting, <<>>, State);
                _ ->
                    ern_rt:answer(Reply, {'Right', Buffer}),
                    socket_loop(Socket, Writer, Waiting, <<>>, State)
            end;
        %% report Appendix E.18: answered once the socket has taken the
        %% bytes, by the writer, which gen_tcp holds while the connection is
        %% behind
        %% report Appendix E.18: a write after the connection has closed
        {'Send', _, Reply} when State =:= closed ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            socket_loop(Socket, Writer, Waiting, Buffer, State);
        {'Send', _, _} = Send ->
            ern_rt:source_begin(),
            Writer ! Send,
            socket_loop(Socket, Writer, Waiting, Buffer, State);
        {written, Sent} ->
            ern_rt:source_end(),
            case Sent of
                {error, _} -> socket_loop(Socket, Writer, closed(Waiting), Buffer, closed);
                ok -> socket_loop(Socket, Writer, Waiting, Buffer, State)
            end;
        'Close' ->
            _ = closed(Waiting),
            gen_tcp:close(Socket),
            Writer ! stop;
        {'FarEnd', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> inet:peername(Socket) end)),
            socket_loop(Socket, Writer, Waiting, Buffer, State);
        {'NearEnd', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> inet:sockname(Socket) end)),
            socket_loop(Socket, Writer, Waiting, Buffer, State);
        {read_timeout, Ref} ->
            case lists:keytake(Ref, 1, Waiting) of
                {value, {Ref, Reply, Deadline, _}, Rest} ->
                    case ern_rt:remaining(Deadline) of
                        0 ->
                            ern_rt:answer(Reply, {'Left', 'Timeout'}),
                            ern_rt:source_end(),
                            socket_loop(Socket, Writer, Rest, Buffer, State);
                        _ ->
                            Again = {Ref, Reply, Deadline, arm(Ref, Deadline)},
                            socket_loop(Socket, Writer, lists:keystore(Ref, 1, Waiting, Again),
                                        Buffer, State)
                    end;
                false ->
                    socket_loop(Socket, Writer, Waiting, Buffer, State)
            end;
        {tcp, Socket, Bytes} ->
            case Waiting of
                [{_, Reply, _, Timer} | Rest] ->
                    erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
                    ern_rt:answer(Reply, {'Right', Bytes}),
                    ern_rt:source_end(),
                    Rest =/= [] andalso inet:setopts(Socket, [{active, once}]),
                    socket_loop(Socket, Writer, Rest, Buffer, State);
                [] ->
                    %% the read it was asked for timed out as it came
                    socket_loop(Socket, Writer, [], <<Buffer/binary, Bytes/binary>>, State)
            end;
        {tcp_closed, Socket} ->
            socket_loop(Socket, Writer, closed(Waiting), Buffer, closed);
        {tcp_error, Socket, _} ->
            socket_loop(Socket, Writer, closed(Waiting), Buffer, closed)
    end.

arm(Ref, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {read_timeout, Ref}).

%% Report Appendix E.18: once the connection has closed, each read waiting
%% answers `Left(Closed)`, and so does each read after, the socket living on
%% until Close.
closed(Waiting) ->
    lists:foreach(fun({_, Reply, _, Timer}) ->
                          erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
                          ern_rt:answer(Reply, {'Left', 'Closed'}),
                          ern_rt:source_end()
                  end, Waiting),
    [].

endpoint(closed, _) ->
    {'Left', 'Closed'};
endpoint(open, Ask) ->
    case Ask() of
        {ok, {Address, Port}} ->
            {'Right', {'Endpoint', unicode:characters_to_binary(inet:ntoa(Address)), Port}};
        {error, _} ->
            {'Left', 'Closed'}
    end.

io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
io_error(closed) -> 'Closed';
io_error(etimedout) -> 'Timeout';
io_error(Reason) -> ern_io:other(Reason, fun inet:format_error/1).
