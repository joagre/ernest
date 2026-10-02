%% Report §8.2, Appendix E.18: the process behind Tcp's reference, and the
%% processes behind a listener and a socket. A socket is a process: it owns
%% the host's socket and lives until Close, answering each read
%% `Left(Closed)` once its connection has closed, and its address can be
%% monitored, killed, and adapted like any other. Each request that waits carries its milliseconds,
%% and the process that owns the stream decides whether time ran out, so
%% that a request that timed out has taken nothing. A request waiting is a
%% source (report §8.6), counted from its arrival until its answer.
-module(ern_tcp).

-export([loop/0]).

%% Report Appendix E.18: a listener's and a socket's loops end only in the
%% exit that tells a waiting call the socket was closed or its owner died,
%% so the fun `opened` spawns never returns, which Dialyzer would report.
-dialyzer({nowarn_function, opened/3}).

%% A socket's process: the host's socket, the writer that writes to it,
%% the owner's monitor, the reads with no bytes yet, oldest first, the
%% bytes no read has taken, and whether the connection is open or closed.
%% The host's socket is asked for bytes only while a read waits, so a
%% program that stops reading holds the far end back.
-record(connection, {socket, writer, monitor_ref, waiting = [], buffer = <<>>, state = open}).

%% A read waiting: its reference, its reply, its deadline and its timer.
-record(read, {ref, reply, deadline, timer}).

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
        {'Listen', Host, Port, Owner, Reply} ->
            erlang:spawn(fun() -> listen(Tcp, Host, Owner, Port, Reply) end),
            serve(Tcp);
        {'Connect', Host, Port, Ms, Owner, Reply} ->
            counted(fun() -> connect(Tcp, Host, Port, ern_rt:deadline(Ms), Owner, Reply) end),
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
listen(Tcp, Host, Owner, Port, Reply) ->
    Answer = case {in_range(Port), ip_address(Host)} of
                 {false, _} ->
                     {'Left', 'Invalid'};
                 {true, {error, Error}} ->
                     {'Left', io_error(Error)};
                 {true, invalid} ->
                     {'Left', 'Invalid'};
                 {true, {ok, IpAddress}} ->
                     Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw},
                                {ip, IpAddress} | family(IpAddress)],
                     case guarded(fun() -> gen_tcp:listen(Port, Options) end) of
                         {ok, Socket} ->
                             %% report §6.9, Appendix E.18: owned by the
                             %% process that opened it, with which it ends
                             Loop = fun() ->
                                        MonitorRef = erlang:monitor(process, Owner),
                                        listener_loop(Tcp, Socket, MonitorRef)
                                    end,
                             Listener = opened(Tcp, Loop, <<"Tcp.listen">>),
                             gen_tcp:controlling_process(Socket, Listener),
                             {'Right', Listener};
                         {error, Error} ->
                             {'Left', io_error(Error)}
                     end
             end,
    ern_rt:answer(Reply, Answer).

in_range(Port) ->
    Port >= 0 andalso Port =< 65535.

%% The IP address the host's name or address stands for, IPv4's first.
%% Report Appendix E.18: a host that holds U+0000 names none.
ip_address(Host) ->
    case binary:match(Host, <<0>>) of
        nomatch -> named(unicode:characters_to_list(Host));
        _ -> invalid
    end.

named(Name) ->
    case inet:parse_address(Name) of
        {ok, IpAddress} ->
            {ok, IpAddress};
        {error, _} ->
            case guarded(fun() -> inet:getaddr(Name, inet) end) of
                {ok, IpAddress} -> {ok, IpAddress};
                {error, _} -> guarded(fun() -> inet:getaddr(Name, inet6) end)
            end
    end.

family({_, _, _, _, _, _, _, _}) -> [inet6];
family(_) -> [].

%% What the host raises for an input it refuses, as the error it would be,
%% whatever the class it raises: a worker that dies of one answers nothing.
guarded(Call) ->
    try Call()
    catch _:Error -> {error, Error}
    end.

%% Report Appendix E.18: a connect that times out takes no connection, since
%% the host closes one it completes after its own time limit. A limit past
%% the host's longest timer is waited in slices, each a new attempt.
connect(Tcp, Host, Port, Deadline, Owner, Reply) ->
    Options = [binary, {active, false}, {packet, raw}],
    Try = fun() ->
              case {in_range(Port), ip_address(Host)} of
                  {false, _} ->
                      invalid;
                  {true, {ok, IpAddress}} ->
                      %% report Appendix E.18: the address the host names, of
                      %% its own family, IPv6's included
                      guarded(fun() ->
                                  gen_tcp:connect(IpAddress, Port, Options ++ family(IpAddress),
                                                  ern_rt:remaining(Deadline))
                              end);
                  {true, Other} ->
                      Other
              end
          end,
    attempt(Tcp, Try, Deadline, Owner, Reply, <<"Tcp.connect">>).

%% Report Appendix E.18: a connect or an accept, tried again after the
%% host's timeout until the deadline has passed, and its answer given: the
%% socket's process, owned by the process that asked, Timeout, or why it
%% failed.
attempt(Tcp, Try, Deadline, Owner, Reply, Site) ->
    Answer = case Try() of
                 {ok, Socket} ->
                     {'Right', socket_process(Tcp, Socket, Owner, Site)};
                 {error, timeout} ->
                     case ern_rt:remaining(Deadline) of
                         0 -> {'Left', 'Timeout'};
                         _ -> again
                     end;
                 {error, Error} ->
                     {'Left', io_error(Error)};
                 invalid ->
                     {'Left', 'Invalid'}
             end,
    case Answer of
        again ->
            attempt(Tcp, Try, Deadline, Owner, Reply, Site);
        _ ->
            ern_rt:answer(Reply, Answer),
            ern_rt:source_end()
    end.

%% A listener answers each Accept by a worker of its own, so that a slow
%% accept does not hold up the next request, and ends at CloseListener,
%% whose close of the socket answers each accept still waiting.
listener_loop(Tcp, Socket, MonitorRef) ->
    receive
        {'Accept', Ms, Owner, Reply} ->
            counted(fun() -> accept(Tcp, Socket, ern_rt:deadline(Ms), Owner, Reply) end),
            listener_loop(Tcp, Socket, MonitorRef);
        {'Port', Reply} ->
            ern_rt:answer(Reply, case inet:port(Socket) of
                                     {ok, Port} -> {'Right', Port};
                                     {error, Error} -> {'Left', io_error(Error)}
                                 end),
            listener_loop(Tcp, Socket, MonitorRef);
        %% report Appendix E.18: its owner has died, and it is killed
        {'DOWN', MonitorRef, process, _, _} ->
            gen_tcp:close(Socket),
            exit({ern, killed});
        'CloseListener' ->
            gen_tcp:close(Socket),
            %% report Appendix E.18: a call after the close faults its caller
            exit({ern, closed})
    end.

%% The worker owns what it accepts, and hands it to the socket process,
%% which is the only legal chain: only an owner may pass a socket on. An
%% accept that times out has taken no connection.
accept(Tcp, Socket, Deadline, Owner, Reply) ->
    attempt(Tcp, fun() -> accepted(gen_tcp:accept(Socket, ern_rt:remaining(Deadline))) end,
            Deadline, Owner, Reply, <<"Tcp.accept">>).

%% Report Appendix E.18: an accept the listener's close answers is
%% `Closed`. The host answers `closed` to an accept waiting when the close
%% comes, and `einval` to one that meets the close under way; the socket
%% listens from its start until the listener closes it, so `einval` is
%% that close.
accepted({error, einval}) ->
    {error, closed};
accepted(Result) ->
    Result.

%% Report Appendix E.18: a socket is its owner's, the process that opened
%% it until one is given it, and is killed when its owner dies; a monitor of
%% an owner that has already ended fires at once.
socket_process(Tcp, Socket, Owner, Site) ->
    Pid = opened(Tcp, fun() ->
                          Self = erlang:self(),
                          Writer = erlang:spawn_link(fun() -> writer(Socket, Self) end),
                          MonitorRef = erlang:monitor(process, Owner),
                          socket_loop(#connection{socket = Socket, writer = Writer,
                                                  monitor_ref = MonitorRef})
                      end, Site),
    gen_tcp:controlling_process(Socket, Pid),
    Pid.

%% Report Appendix E.18: a socket's writes, one after another in the order
%% they came, in a process of their own, so that a write the far end holds
%% back holds up no read and no read's time limit. A write is counted as a
%% source by the socket, which the writer tells when it has answered, and
%% whether the connection had gone. Report Appendix E.18: the answer says
%% whether the socket took the bytes, and why not.
writer(Socket, SocketProcess) ->
    receive
        {'Send', Bytes, Reply} ->
            Sent = gen_tcp:send(Socket, Bytes),
            ern_rt:answer(Reply, case Sent of
                                     ok -> {'Right', 'Unit'};
                                     {error, Error} -> {'Left', io_error(Error)}
                                 end),
            SocketProcess ! {written, Sent},
            writer(Socket, SocketProcess);
        stop ->
            ok
    end.

socket_loop(#connection{socket = Socket, writer = Writer, monitor_ref = MonitorRef,
                        state = State} = Connection) ->
    receive
        {'Recv', Ms, Reply} ->
            socket_loop(read(Ms, Reply, Connection));
        %% report Appendix E.18: a write after the connection has closed
        {'Send', _, _, Reply} when State =:= closed ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            socket_loop(Connection);
        {'Send', Bytes, Ms, Reply} ->
            send(Writer, Bytes, Ms, Reply),
            socket_loop(Connection);
        {write_timeout, Reply, Deadline} ->
            write_timed_out(Reply, Deadline),
            socket_loop(Connection);
        {written, Sent} ->
            ern_rt:source_end(),
            case Sent of
                {error, _} -> socket_loop(closed(Connection));
                ok -> socket_loop(Connection)
            end;
        %% report Appendix E.18: another process owns the socket from now on
        {'Give', Owner} ->
            erlang:demonitor(MonitorRef, [flush]),
            socket_loop(Connection#connection{monitor_ref = erlang:monitor(process, Owner)});
        %% report Appendix E.18: its owner has died, and it is killed
        {'DOWN', MonitorRef, process, _, _} ->
            gen_tcp:close(Socket),
            exit({ern, killed});
        'Close' ->
            _ = closed(Connection),
            gen_tcp:close(Socket),
            Writer ! stop,
            %% report Appendix E.18: a call after the close faults its caller
            exit({ern, closed});
        {'FarEnd', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> inet:peername(Socket) end)),
            socket_loop(Connection);
        {'NearEnd', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> inet:sockname(Socket) end)),
            socket_loop(Connection);
        {read_timeout, Ref} ->
            socket_loop(read_timed_out(Ref, Connection));
        {tcp, Socket, Bytes} ->
            socket_loop(arrived(Bytes, Connection));
        {tcp_closed, Socket} ->
            socket_loop(closed(Connection));
        {tcp_error, Socket, _} ->
            socket_loop(closed(Connection))
    end.

%% Report Appendix E.18: a write is answered once the socket has taken the
%% bytes, by the writer, which gen_tcp holds while the connection is
%% behind, or `Left(Timeout)` when the milliseconds pass first, which does
%% not undo the write: the writer's later answer is dropped as a second
%% answer is (E.0 shape rule 8).
send(Writer, Bytes, Ms, Reply) ->
    ern_rt:source_begin(),
    Writer ! {'Send', Bytes, Reply},
    write_limit(Reply, ern_rt:deadline(Ms)).

write_timed_out(Reply, Deadline) ->
    case ern_rt:remaining(Deadline) of
        0 -> ern_rt:answer(Reply, {'Left', 'Timeout'});
        _ -> write_limit(Reply, Deadline)
    end.

%% Report Appendix E.18: a read is answered the bytes no read has taken, or
%% `Left(Closed)` once the connection has closed, or else waits, counted as
%% a source, the host's socket asked for bytes when it is the first to wait.
read(Ms, Reply, #connection{socket = Socket, waiting = Waiting, buffer = Buffer,
                            state = State} = Connection) ->
    case {Buffer, State} of
        {<<>>, open} ->
            ern_rt:source_begin(),
            Ref = make_ref(),
            Deadline = ern_rt:deadline(Ms),
            Waiting =/= [] orelse inet:setopts(Socket, [{active, once}]),
            Read = #read{ref = Ref, reply = Reply, deadline = Deadline,
                         timer = arm(Ref, Deadline)},
            Connection#connection{waiting = Waiting ++ [Read]};
        {<<>>, closed} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            Connection;
        _ ->
            ern_rt:answer(Reply, {'Right', Buffer}),
            Connection#connection{buffer = <<>>}
    end.

%% A read's time has passed: answered `Left(Timeout)`, or armed again where
%% the deadline is past the host's longest timer; one answered as it came
%% is gone.
read_timed_out(Ref, #connection{waiting = Waiting} = Connection) ->
    case lists:keytake(Ref, #read.ref, Waiting) of
        {value, #read{reply = Reply, deadline = Deadline} = Read, Rest} ->
            case ern_rt:remaining(Deadline) of
                0 ->
                    ern_rt:answer(Reply, {'Left', 'Timeout'}),
                    ern_rt:source_end(),
                    Connection#connection{waiting = Rest};
                _ ->
                    Again = Read#read{timer = arm(Ref, Deadline)},
                    Connection#connection{waiting = lists:keystore(Ref, #read.ref, Waiting, Again)}
            end;
        false ->
            Connection
    end.

%% Bytes that came: the oldest read waiting answered them, the host's
%% socket asked again while another waits; where none waits, its read timed out as they
%% came, and they wait for the next.
arrived(Bytes, #connection{socket = Socket, waiting = Waiting, buffer = Buffer} = Connection) ->
    case Waiting of
        [#read{reply = Reply, timer = Timer} | Rest] ->
            erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
            ern_rt:answer(Reply, {'Right', Bytes}),
            ern_rt:source_end(),
            Rest =/= [] andalso inet:setopts(Socket, [{active, once}]),
            Connection#connection{waiting = Rest};
        [] ->
            Connection#connection{buffer = <<Buffer/binary, Bytes/binary>>}
    end.

arm(Ref, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {read_timeout, Ref}).

%% A write's limit, armed again until it has passed (report §6.3).
write_limit(Reply, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(),
                      {write_timeout, Reply, Deadline}).

%% Report Appendix E.18: once the connection has closed, each read waiting
%% answers `Left(Closed)`, and so does each read after, the socket living on
%% until Close.
closed(#connection{waiting = Waiting} = Connection) ->
    lists:foreach(fun(#read{reply = Reply, timer = Timer}) ->
                      erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
                      ern_rt:answer(Reply, {'Left', 'Closed'}),
                      ern_rt:source_end()
                  end, Waiting),
    Connection#connection{waiting = [], state = closed}.

endpoint(closed, _) ->
    {'Left', 'Closed'};
endpoint(open, Ask) ->
    case Ask() of
        {ok, {IpAddress, Port}} ->
            {'Right', {'Endpoint', unicode:characters_to_binary(inet:ntoa(IpAddress)), Port}};
        {error, _} ->
            {'Left', 'Closed'}
    end.

io_error(enoent) -> 'NotFound';
io_error(eacces) -> 'Denied';
io_error(eperm) -> 'Denied';
io_error(econnrefused) -> 'Refused';
io_error(closed) -> 'Closed';
io_error(etimedout) -> 'Timeout';
io_error(Error) -> ern_io:other(Error, fun inet:format_error/1).
