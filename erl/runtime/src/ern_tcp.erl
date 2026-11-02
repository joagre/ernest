%% Report §8.2, Appendix E.18: the process behind Tcp's reference, and the
%% processes behind a listener and a socket. A socket is a process: it owns
%% the host's socket and lives until Close, answering each read
%% `Left(Closed)` once its connection has closed, and its address can be
%% monitored, killed, and adapted like any other. Each request that waits
%% carries its milliseconds, and the process that owns the stream decides
%% whether time ran out, so that a request that timed out has taken
%% nothing. Such a request, a connect, an accept, a read or a write, is a
%% source (report §8.6), counted from its arrival until its answer. A
%% listen waits on the host alone, and its caller's call to this process,
%% which the reaper reads, covers it.
%%
%% A listener and a socket over TLS are the same processes over the host's
%% ssl, whose functions mirror gen_tcp's and inet's: the host's socket is
%% gen_tcp's or ssl's, and its Transport, `gen_tcp` or `ssl`, names the
%% module that carries it out (docs/design/runtime.md).
-module(ern_tcp).

-export([loop/0]).

%% Report Appendix E.18: a listener's and a socket's loops end only in the
%% exit that tells a waiting call the socket was closed or its owner died,
%% so the fun `opened` spawns never returns, which Dialyzer would report.
-dialyzer({nowarn_function, opened/6}).

%% Report §8.6: each receive that can wait, by its kind (docs/style.md).
-receives({own_process, [serve/2, counted/1, opened/6, listener_loop/4, writing/3,
                         handshake_failed/2, socket_loop/1, stop_writer/1, close_socket/2,
                         lingering/5]}).

%% A socket's process: its transport, the host's socket, the writer that
%% writes to it, the owner's monitor, the reads with no bytes yet, oldest
%% first, the writes the writer holds, oldest first, the bytes no read has
%% taken, and whether the connection is open or closed, or, for a socket
%% over TLS that accept answered, handshaking until its handshake ends.
%% The host's socket is asked for bytes only while a read waits, so a
%% program that stops reading holds the far end back.
-record(connection, {transport, socket, writer, monitor_ref, waiting = [], writes = [],
                     buffer = <<>>, state = open}).

%% A read waiting: its reference, its reply, its deadline and its timer.
-record(read, {ref, reply, deadline, timer}).

%% A write the writer holds, oldest first in the connection: its reply, its
%% deadline, and its timer, `expired` once it has answered `Left(Timeout)`.
-record(write, {reply, deadline, timer}).

%% Report Appendix E.18: how long the host's socket may send what the far
%% end has not taken once the socket has ended: until 5 seconds pass with
%% nothing taken, and 3 minutes in all, looked at once a second.
-define(LINGER_IDLE, 5000).
-define(LINGER_LIMIT, 180000).
-define(LINGER_CHECK, 1000).

%% Report §8.6: every listener and socket is linked to this process, which
%% the runtime kills when the program ends, so none outlives it; this
%% process traps the exits, so that one ending takes nothing else with it,
%% and forgets what the runtime recorded of the one that ended.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self(), unstarted).

%% Tls is whether the host's ssl is started, which the first request over
%% TLS does (tls/3).
serve(Tcp, Tls) ->
    receive
        {'Listen', Host, Port, Owner, Reply} ->
            erlang:spawn(fun() -> listen(Tcp, Host, Port, plain, Owner, Reply) end),
            serve(Tcp, Tls);
        {'ListenTls', Host, Port, Certificate, Key, Owner, Reply} ->
            Kind = {tls, Certificate, Key},
            serve(Tcp, tls(Tls, Reply, fun() ->
                                           erlang:spawn(fun() ->
                                                            listen(Tcp, Host, Port, Kind, Owner,
                                                                   Reply)
                                                        end)
                                       end));
        {'Connect', Host, Port, Ms, Owner, Reply} ->
            counted(fun() ->
                        connect(Tcp, Host, Port, plain, ern_rt:deadline(Ms), Owner, Reply)
                    end),
            serve(Tcp, Tls);
        {'ConnectTls', Host, Port, Verification, Ms, Owner, Reply} ->
            Kind = {tls, Verification},
            serve(Tcp, tls(Tls, Reply, fun() ->
                                           counted(fun() ->
                                                       connect(Tcp, Host, Port, Kind,
                                                               ern_rt:deadline(Ms), Owner, Reply)
                                                   end)
                                       end));
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Tcp, Tls)
    end.

%% Report Appendix E.18: a request over TLS, made once the host's ssl is
%% started, which the first such request of a launch starts where nothing
%% has, a node's carrier among them, whose distribution runs without it.
%% A start that fails answers the request with the host's reason, and the
%% next request tries again.
tls(started, _, Request) ->
    Request(),
    started;
tls(unstarted, Reply, Request) ->
    case application:ensure_all_started(ssl) of
        {ok, _} ->
            tls(started, Reply, Request);
        {error, Error} ->
            ern_rt:answer(Reply, {'Left', ern_io:other(Error, fun ssl:format_error/1)}),
            unstarted
    end.

%% A worker whose request waits, counted as a source before it starts, so
%% that its answer cannot come before its count; it ends the count itself.
counted(Work) ->
    Worker = erlang:spawn(fun() -> receive go -> Work() end end),
    ern_rt:source_begin(Worker),
    Worker ! go.

%% A listener or a socket, linked to the TCP process and recorded as opened
%% before its address is given out (report §8.6), under the function that
%% opened it, and as started by its owner (Appendix E.18), whom it watches
%% from before then too, so that what an owner holds is what watches it
%% (ern_rt:evaluate/2); Loop is given the monitor once the host's socket
%% is the process's. It traps exits from its start, so that however it
%% ends, by a kill, with the program or with the TCP process, it closes
%% its host's socket itself (close_socket/2).
opened(Tcp, Transport, Socket, Loop, Site, Owner) ->
    Opener = erlang:self(),
    Pid = erlang:spawn(fun() ->
                           process_flag(trap_exit, true),
                           link(Tcp),
                           MonitorRef = erlang:monitor(process, Owner),
                           Opener ! {erlang:self(), watching},
                           receive go -> Loop(MonitorRef) end
                       end),
    receive {Pid, watching} -> ok end,
    ern_rt:opened(Pid, Site, Owner),
    _ = Transport:controlling_process(Socket, Pid),
    Pid ! go,
    Pid.

%% Report Appendix E.18: a listener on the interface the host's name or
%% address names, over TCP or over TLS, whose certificate and key the
%% host's ssl reads as it listens. Every request is answered: a port out of
%% range, and what the host refuses by raising, are errors as much as what
%% it answers.
listen(Tcp, Host, Port, Kind, Owner, Reply) ->
    Answer = case {in_range(Port), ip_address(Host), listening(Kind)} of
                 {false, _, _} ->
                     {'Left', 'Invalid'};
                 {true, {error, Error}, _} ->
                     {'Left', io_error(gen_tcp, Error)};
                 {true, invalid, _} ->
                     {'Left', 'Invalid'};
                 {true, _, invalid} ->
                     {'Left', 'Invalid'};
                 {true, {ok, IpAddress}, {Transport, Site, KindOptions}} ->
                     Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw},
                                {ip, IpAddress} | family(IpAddress)] ++ KindOptions,
                     case guarded(fun() -> Transport:listen(Port, Options) end) of
                         {ok, Socket} ->
                             %% report §6.9, Appendix E.18: owned by the
                             %% process that opened it, with which it ends
                             Loop = fun(MonitorRef) ->
                                        listener_loop(Tcp, Transport, Socket, MonitorRef)
                                    end,
                             {'Right', opened(Tcp, Transport, Socket, Loop, Site, Owner)};
                         {error, Error} ->
                             {'Left', io_error(Transport, Error)}
                     end
             end,
    ern_rt:answer(Reply, Answer).

%% Report Appendix E.18: what a listener's kind adds, its transport, its
%% site and, over TLS, the server's certificate, its chain after it, and
%% its key.
listening(plain) ->
    {gen_tcp, <<"Tcp.listen">>, []};
listening({tls, {'Path', Certificate}, {'Path', Key}}) ->
    case {file_name(Certificate), file_name(Key)} of
        {invalid, _} -> invalid;
        {_, invalid} -> invalid;
        {CertificateFile, KeyFile} ->
            {ssl, <<"Tcp.listenTls">>, [{certfile, CertificateFile}, {keyfile, KeyFile}]}
    end.

%% Report Appendix E.1: a path as the host's ssl takes a file's name, or
%% invalid where it holds U+0000, which names no file.
file_name(Path) ->
    case binary:match(Path, <<0>>) of
        nomatch -> unicode:characters_to_list(Path);
        _ -> invalid
    end.

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
%% the host's longest timer is waited in slices, each a new attempt; over
%% TLS, each attempt's limit holds its handshake too.
connect(Tcp, Host, Port, Kind, Deadline, Owner, Reply) ->
    {Transport, Site, KindOptions} = connecting(Kind, Host),
    Options = [binary, {active, false}, {packet, raw}],
    Try = fun() ->
              case {in_range(Port), ip_address(Host), KindOptions} of
                  {false, _, _} ->
                      invalid;
                  {true, _, invalid} ->
                      invalid;
                  {true, {ok, IpAddress}, _} ->
                      %% report Appendix E.18: the address the host names, of
                      %% its own family, IPv6's included
                      guarded(fun() ->
                                  Transport:connect(IpAddress, Port,
                                                    Options ++ family(IpAddress) ++ KindOptions,
                                                    ern_rt:remaining(Deadline))
                              end);
                  {true, Other, _} ->
                      Other
              end
          end,
    Open = fun(Socket) -> socket_process(Tcp, Transport, Socket, open, Owner, Site) end,
    attempt(Transport, Try, Open, Deadline, Reply).

%% Report Appendix E.18: what a connect's kind adds, its transport, its site
%% and, over TLS, the check of the far end's certificate and the host's
%% name the far end is told, or invalid where the file of the check's
%% certificates holds U+0000.
connecting(plain, _) ->
    {gen_tcp, <<"Tcp.connect">>, []};
connecting({tls, Verification}, Host) ->
    Options = case verification(Verification, Host) of
                  invalid -> invalid;
                  Checked -> Checked ++ server_name(Host)
              end,
    {ssl, <<"Tcp.connectTls">>, Options}.

%% Report Appendix E.18: `Verified(caFile)` checks the far end's certificate
%% against the file's certificates, and for naming the host, which the
%% host's ssl checks under verify_peer by the name server_name/1 gives it,
%% or, for a host that is an address, by the address it connects to; a
%% certificate names a host through a wildcard, `*.example.test` naming
%% `www.example.test`, as the host's match for HTTPS reads one, where the
%% host's own match takes a name only as written. `Unverified` checks
%% nothing.
verification({'Verified', {'Path', Certificates}}, Host) ->
    case file_name(Certificates) of
        invalid ->
            invalid;
        CertificatesFile ->
            [{verify, verify_peer}, {cacertfile, CertificatesFile},
             {verify_fun, {fun verify/4, {CertificatesFile, reference(Host)}}},
             {customize_hostname_check, [{match_fun, wildcards()}]}]
    end;
verification('Unverified', _) ->
    [{verify, verify_none}].

%% Report Appendix E.18: the check of each certificate of the far end's
%% chain, the host's own under verify_peer but for a self-signed far end,
%% which the host refuses before it looks in the file, a chain of one
%% being no chain to a certificate there, and whose name the host leaves
%% unchecked once it is taken: one whose certificate the file holds, as
%% sent, and names the host connected to, as the host's own check reads
%% a name, is taken, as a chain that leads to one the file holds is. The
%% file is read here on that path alone, so that the ordinary path costs
%% nothing more.
verify(OtpCert, Der, {bad_cert, selfsigned_peer}, {File, Reference} = State) ->
    case holds(File, Der) of
        true ->
            case public_key:pkix_verify_hostname(OtpCert, Reference, [{match_fun, wildcards()}]) of
                true -> {valid, State};
                false -> {fail, {bad_cert, hostname_check_failed}}
            end;
        false ->
            {fail, {bad_cert, selfsigned_peer}}
    end;
verify(_, _, {bad_cert, _} = Reason, _) ->
    {fail, Reason};
verify(_, _, {extension, _}, State) ->
    {unknown, State};
verify(_, _, valid, State) ->
    {valid, State};
verify(_, _, valid_peer, State) ->
    {valid, State}.

%% The host connected to, as a certificate is checked for naming it: an
%% address as one, and a name as written, its trailing dots left out.
reference(Host) ->
    Name = unicode:characters_to_list(Host),
    case inet:parse_address(Name) of
        {ok, IpAddress} -> [{ip, IpAddress}];
        {error, _} -> [{dns_id, string:trim(Name, trailing, ".")}]
    end.

%% A certificate's wildcard read as the host's match for HTTPS reads one.
wildcards() ->
    public_key:pkix_verify_hostname_match_fun(https).

%% Whether the file of certificates holds the certificate, as sent.
holds(File, Der) ->
    case file:read_file(File) of
        {ok, Pem} -> lists:member({'Certificate', Der, not_encrypted}, public_key:pem_decode(Pem));
        {error, _} -> false
    end.

%% Report Appendix E.18: the host's name the far end is told and its
%% certificate checked for, the name as given, its trailing dots left out,
%% as the host's ssl takes it from a name it connects to; none for an
%% address, since connect/7 connects to the address the name stands for.
server_name(Host) ->
    Name = unicode:characters_to_list(Host),
    case inet:parse_address(Name) of
        {ok, _} -> [];
        {error, _} -> [{server_name_indication, string:trim(Name, trailing, ".")}]
    end.

%% Report Appendix E.18: a connect or an accept, tried again after the
%% host's timeout until the deadline has passed, and its answer given: the
%% socket's process, which Open starts, owned by the process that asked,
%% Timeout, or why it failed.
attempt(Transport, Try, Open, Deadline, Reply) ->
    Answer = case Try() of
                 {ok, Socket} ->
                     {'Right', Open(Socket)};
                 {error, timeout} ->
                     case ern_rt:remaining(Deadline) of
                         0 -> {'Left', 'Timeout'};
                         _ -> again
                     end;
                 {error, Error} ->
                     {'Left', io_error(Transport, Error)};
                 invalid ->
                     {'Left', 'Invalid'}
             end,
    case Answer of
        again ->
            attempt(Transport, Try, Open, Deadline, Reply);
        _ ->
            ern_rt:answer(Reply, Answer),
            ern_rt:source_end()
    end.

%% A listener answers each Accept by a worker of its own, so that a slow
%% accept does not hold up the next request, and ends at CloseListener,
%% whose close of the socket answers each accept still waiting.
listener_loop(Tcp, Transport, Socket, MonitorRef) ->
    receive
        {'Accept', Ms, Owner, Reply} ->
            counted(fun() ->
                        accept(Tcp, Transport, Socket, ern_rt:deadline(Ms), Owner, Reply)
                    end),
            listener_loop(Tcp, Transport, Socket, MonitorRef);
        {'Port', Reply} ->
            ern_rt:answer(Reply, case port(Transport, Socket) of
                                     {ok, Port} -> {'Right', Port};
                                     {error, Error} -> {'Left', io_error(Transport, Error)}
                                 end),
            listener_loop(Tcp, Transport, Socket, MonitorRef);
        %% report Appendix E.18: its owner has died, and it is killed
        {'DOWN', MonitorRef, process, _, _} ->
            Transport:close(Socket),
            exit({ern, killed});
        'CloseListener' ->
            Transport:close(Socket),
            %% report Appendix E.18: a call after the close faults its caller
            exit({ern, closed});
        %% the host's socket's own exit, which ends nothing
        {'EXIT', _, normal} ->
            listener_loop(Tcp, Transport, Socket, MonitorRef);
        %% report Appendix E.18: killed, or ended with the program
        {'EXIT', _, ExitReason} ->
            Transport:close(Socket),
            exit(ExitReason)
    end.

port(gen_tcp, Socket) ->
    inet:port(Socket);
port(ssl, Socket) ->
    case ssl:sockname(Socket) of
        {ok, {_, Port}} -> {ok, Port};
        {error, Error} -> {error, Error}
    end.

%% The worker owns what it accepts, and hands it to the socket process,
%% which is the only legal chain: only an owner may pass a socket on. An
%% accept that times out has taken no connection. Report Appendix E.18:
%% over TLS, the accept is the host's ssl's before the handshake, which
%% the socket runs (writer/4), so that a client slow to shake hands holds
%% up no accept.
accept(Tcp, gen_tcp, Socket, Deadline, Owner, Reply) ->
    Open = fun(Accepted) ->
               socket_process(Tcp, gen_tcp, Accepted, open, Owner, <<"Tcp.accept">>)
           end,
    attempt(gen_tcp, fun() -> accepted(gen_tcp:accept(Socket, ern_rt:remaining(Deadline))) end,
            Open, Deadline, Reply);
accept(Tcp, ssl, Socket, Deadline, Owner, Reply) ->
    Open = fun(Accepted) ->
               socket_process(Tcp, ssl, Accepted, handshaking, Owner, <<"Tcp.accept">>)
           end,
    attempt(ssl, fun() -> accepted(ssl:transport_accept(Socket, ern_rt:remaining(Deadline))) end,
            Open, Deadline, Reply).

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
socket_process(Tcp, Transport, Socket, State, Owner, Site) ->
    Loop = fun(MonitorRef) ->
               Self = erlang:self(),
               Writer = erlang:spawn_link(fun() -> writer(Transport, Socket, Self, State) end),
               socket_loop(#connection{transport = Transport, socket = Socket, writer = Writer,
                                       monitor_ref = MonitorRef, state = State})
           end,
    opened(Tcp, Transport, Socket, Loop, Site, Owner).

%% Report Appendix E.18: a socket's writes, one after another in the order
%% they came, in a process of their own, so that a write the far end holds
%% back holds up no read and no read's time limit. A write is counted as a
%% source by the socket, which the writer tells when it has answered, and
%% whether the connection had gone. Report Appendix E.18: the answer says
%% whether the socket took the bytes, and why not.
%%
%% Report Appendix E.18: a socket over TLS that accept answered shakes
%% hands here first, so that the writes given meanwhile wait for the
%% handshake and the socket's process answers reads, a close and the rest
%% while it runs; the writer tells the socket's process how it ended.
writer(ssl, Socket, SocketProcess, handshaking) ->
    case ssl:handshake(Socket, infinity) of
        {ok, _} ->
            SocketProcess ! {handshaken, ok},
            writing(ssl, Socket, SocketProcess);
        {error, Error} ->
            Failure = io_error(ssl, Error),
            SocketProcess ! {handshaken, Failure},
            handshake_failed(Failure, SocketProcess)
    end;
writer(Transport, Socket, SocketProcess, open) ->
    writing(Transport, Socket, SocketProcess).

writing(Transport, Socket, SocketProcess) ->
    receive
        {write, Bytes, Reply} ->
            Sent = Transport:send(Socket, Bytes),
            ern_rt:answer(Reply, case Sent of
                                     ok -> {'Right', 'Unit'};
                                     {error, Error} -> {'Left', io_error(Transport, Error)}
                                 end),
            SocketProcess ! {written, Sent},
            writing(Transport, Socket, SocketProcess)
    end.

%% Report Appendix E.18: a write given before the socket's process knew that
%% the handshake had failed answers the handshake's failure.
handshake_failed(Failure, SocketProcess) ->
    receive
        {write, _, Reply} ->
            ern_rt:answer(Reply, {'Left', Failure}),
            SocketProcess ! {written, {error, Failure}},
            handshake_failed(Failure, SocketProcess)
    end.

socket_loop(#connection{transport = Transport, socket = Socket, writer = Writer,
                        monitor_ref = MonitorRef, state = State} = Connection) ->
    receive
        {'Read', Ms, Reply} ->
            socket_loop(read(Ms, Reply, Connection));
        %% report Appendix E.18: a write after the connection has closed
        {'Write', _, _, Reply} when State =:= closed ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            socket_loop(Connection);
        {'Write', Bytes, Ms, Reply} ->
            socket_loop(send(Writer, Bytes, Ms, Reply, Connection));
        {deadline, {write, Reply}} ->
            socket_loop(write_timed_out(Reply, Connection));
        {written, Sent} ->
            ern_rt:source_end(),
            Written = written(Connection),
            case Sent of
                {error, _} -> socket_loop(closed('Closed', Written));
                ok -> socket_loop(Written)
            end;
        {handshaken, ok} ->
            socket_loop(handshaken(Connection));
        %% report Appendix E.18: a handshake that fails closes the
        %% connection, and the reads waiting answer its failure
        {handshaken, Failure} ->
            socket_loop(closed(Failure, Connection));
        %% report Appendix E.18: another process owns the socket from now on
        {'Give', Owner} ->
            erlang:demonitor(MonitorRef, [flush]),
            socket_loop(Connection#connection{monitor_ref = erlang:monitor(process, Owner)});
        %% report Appendix E.18: its owner has died, and it is killed
        {'DOWN', MonitorRef, process, _, _} ->
            stop_writer(Writer),
            close_socket(Transport, Socket),
            exit({ern, killed});
        'Close' ->
            #connection{writes = Writes} = closed('Closed', Connection),
            stop_writer(Writer),
            %% report Appendix E.18: each write it holds answers `Left(Closed)`,
            %% and one the writer answered first keeps its answer
            lists:foreach(fun(#write{reply = Reply}) ->
                              ern_rt:answer(Reply, {'Left', 'Closed'})
                          end, Writes),
            close_socket(Transport, Socket),
            %% report Appendix E.18: a call after the close faults its caller
            exit({ern, closed});
        %% the writer's exit, or the host's socket's when the far end has
        %% closed it, which end nothing
        {'EXIT', _, normal} ->
            socket_loop(Connection);
        %% report Appendix E.18: killed, or ended with the program
        {'EXIT', _, ExitReason} ->
            stop_writer(Writer),
            close_socket(Transport, Socket),
            exit(ExitReason);
        {'Remote', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> (inet(Transport)):peername(Socket) end)),
            socket_loop(Connection);
        {'Local', Reply} ->
            ern_rt:answer(Reply, endpoint(State, fun() -> (inet(Transport)):sockname(Socket) end)),
            socket_loop(Connection);
        {deadline, {read, Ref}} ->
            socket_loop(read_timed_out(Ref, Connection));
        {tcp, Socket, Bytes} ->
            socket_loop(arrived(Bytes, Connection));
        {ssl, Socket, Bytes} ->
            socket_loop(arrived(Bytes, Connection));
        {tcp_closed, Socket} ->
            socket_loop(closed('Closed', Connection));
        {ssl_closed, Socket} ->
            socket_loop(closed('Closed', Connection));
        {tcp_error, Socket, _} ->
            socket_loop(closed('Closed', Connection));
        {ssl_error, Socket, _} ->
            socket_loop(closed('Closed', Connection))
    end.

%% The module of a host socket's options, statistics and ends: inet for
%% gen_tcp's, and ssl for its own, whose functions of these mirror inet's.
inet(gen_tcp) -> inet;
inet(ssl) -> ssl.

%% The writer is ended before the host's socket closes, so that it gives
%% the host no more bytes; a write the host was holding back, the
%% connection being behind, has given none.
stop_writer(Writer) ->
    unlink(Writer),
    MonitorRef = erlang:monitor(process, Writer),
    exit(Writer, kill),
    receive {'DOWN', MonitorRef, process, _, _} -> ok end.

%% Report Appendix E.18: the host's socket closed, the bytes the far end has
%% not taken sent while it takes them. The host's own close leaves its
%% socket open, with its descriptor, for as long as the far end takes
%% nothing, and once the socket's owner has ended no process can stop that;
%% so a socket with bytes waiting is handed to a closer of its own first.
%% A socket over TLS always is, since ssl's close writes the record that
%% ends the connection and waits for the far end's answer.
close_socket(Transport, Socket) ->
    Inet = inet(Transport),
    case Inet:getstat(Socket, [send_pend]) of
        {ok, [{send_pend, Pending}]} when Pending > 0; Transport =:= ssl ->
            Ended = erlang:monotonic_time(millisecond),
            Closer = erlang:spawn(fun() ->
                                      receive
                                          go -> lingering(Transport, Socket, Pending, Ended, Ended)
                                      end
                                  end),
            _ = Inet:setopts(Socket, [{active, false}]),
            case Transport:controlling_process(Socket, Closer) of
                ok ->
                    Closer ! go;
                {error, _} ->
                    exit(Closer, kill),
                    Transport:close(Socket)
            end;
        _ ->
            Transport:close(Socket)
    end.

%% Report Appendix E.18: the closer looks at what the host still holds, at
%% once and then once a second. Nothing left closes the socket. Nothing
%% taken for 5 seconds, or 3 minutes since the end, drops the rest and
%% resets the connection, which the host's close does with a linger of no
%% time.
lingering(Transport, Socket, Pending, Moved, Ended) ->
    Inet = inet(Transport),
    Now = erlang:monotonic_time(millisecond),
    InTime = Now - Ended < ?LINGER_LIMIT,
    case Inet:getstat(Socket, [send_pend]) of
        {ok, [{send_pend, 0}]} ->
            Transport:close(Socket);
        {ok, [{send_pend, Left}]} when Left < Pending, InTime ->
            receive after ?LINGER_CHECK -> ok end,
            lingering(Transport, Socket, Left, Now, Ended);
        {ok, _} when Now - Moved < ?LINGER_IDLE, InTime ->
            receive after ?LINGER_CHECK -> ok end,
            lingering(Transport, Socket, Pending, Moved, Ended);
        {ok, _} ->
            _ = Inet:setopts(Socket, [{linger, {true, 0}}]),
            Transport:close(Socket);
        {error, _} ->
            %% the far end has closed the connection, and the host's socket
            %% has closed with it
            ok
    end.

%% Report Appendix E.18: a write is answered once the socket has taken the
%% bytes, by the writer, which gen_tcp holds while the connection is
%% behind, or `Left(Timeout)` when the milliseconds pass first, which does
%% not undo the write: the writer's later answer is dropped as a second
%% answer is (E.0 shape rule 8). A write given while the handshake runs
%% waits for it so.
send(Writer, Bytes, Ms, Reply, #connection{writes = Writes} = Connection) ->
    ern_rt:source_begin(),
    Writer ! {write, Bytes, Reply},
    Deadline = ern_rt:deadline(Ms),
    Write = #write{reply = Reply, deadline = Deadline, timer = write_limit(Reply, Deadline)},
    Connection#connection{writes = Writes ++ [Write]}.

%% A write's time has passed: answered `Left(Timeout)`, its place kept for
%% the writer's word, or armed again where the deadline is past the host's
%% longest timer; one the writer answered as its timer fired is gone.
write_timed_out(Reply, #connection{writes = Writes} = Connection) ->
    case lists:keyfind(Reply, #write.reply, Writes) of
        #write{deadline = Deadline} = Write ->
            Timer = case ern_rt:remaining(Deadline) of
                        0 ->
                            ern_rt:answer(Reply, {'Left', 'Timeout'}),
                            expired;
                        _ ->
                            write_limit(Reply, Deadline)
                    end,
            Later = lists:keystore(Reply, #write.reply, Writes, Write#write{timer = Timer}),
            Connection#connection{writes = Later};
        false ->
            Connection
    end.

%% Report Appendix E.18: the writer has answered its oldest write, which
%% lets go of its timer.
written(#connection{writes = [#write{timer = Timer} | Rest]} = Connection) ->
    Timer =:= expired orelse erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
    Connection#connection{writes = Rest}.

%% Report Appendix E.18: a read is answered the bytes no read has taken, or
%% `Left(Closed)` once the connection has closed, or else waits, counted as
%% a source, the host's socket asked for bytes when it is the first to wait
%% on an open connection; one that waits for a handshake waits within its
%% own milliseconds, and its `Left(Timeout)` leaves the handshake under way.
read(Ms, Reply, #connection{waiting = Waiting, buffer = Buffer,
                            state = State} = Connection) ->
    case {Buffer, State} of
        {<<>>, closed} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            Connection;
        {<<>>, _} ->
            ern_rt:source_begin(),
            Ref = make_ref(),
            Deadline = ern_rt:deadline(Ms),
            Read = #read{ref = Ref, reply = Reply, deadline = Deadline,
                         timer = arm(Ref, Deadline)},
            Waiting =/= [] orelse asked(Connection),
            Connection#connection{waiting = Waiting ++ [Read]};
        _ ->
            ern_rt:answer(Reply, {'Right', Buffer}),
            Connection#connection{buffer = <<>>}
    end.

%% Report Appendix E.18: the handshake is done, and a read that waits for
%% bytes asks the host's socket for them; a connection that closed while it
%% ran stays closed.
handshaken(#connection{state = handshaking, waiting = Waiting} = Connection) ->
    Open = Connection#connection{state = open},
    Waiting =/= [] andalso asked(Open),
    Open;
handshaken(Connection) ->
    Connection.

%% The host's socket asked for bytes once, on an open connection.
asked(#connection{transport = Transport, socket = Socket, state = open} = Connection) ->
    _ = (inet(Transport)):setopts(Socket, [{active, once}]),
    Connection;
asked(Connection) ->
    Connection.

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
%% socket asked again while another waits; where none waits, its read timed
%% out as they came, and they wait for the next.
arrived(Bytes, #connection{waiting = Waiting, buffer = Buffer} = Connection) ->
    case Waiting of
        [#read{reply = Reply, timer = Timer} | Rest] ->
            erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
            ern_rt:answer(Reply, {'Right', Bytes}),
            ern_rt:source_end(),
            Rest =/= [] andalso asked(Connection),
            Connection#connection{waiting = Rest};
        [] ->
            Connection#connection{buffer = <<Buffer/binary, Bytes/binary>>}
    end.

arm(Ref, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {deadline, {read, Ref}}).

%% A write's limit, armed again until it has passed (report §6.3).
write_limit(Reply, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {deadline, {write, Reply}}).

%% Report Appendix E.18: once the connection has closed, each read waiting
%% answers `Left(Closed)`, or a failed handshake's `Left`, and each read
%% after `Left(Closed)`, the socket living on until Close.
closed(Error, #connection{waiting = Waiting} = Connection) ->
    lists:foreach(fun(#read{reply = Reply, timer = Timer}) ->
                      erlang:cancel_timer(Timer, [{async, true}, {info, false}]),
                      ern_rt:answer(Reply, {'Left', Error}),
                      ern_rt:source_end()
                  end, Waiting),
    Connection#connection{waiting = [], state = closed}.

endpoint(closed, _) ->
    {'Left', 'Closed'};
endpoint(_, Ask) ->
    case Ask() of
        {ok, {IpAddress, Port}} ->
            {'Right', {'Endpoint', unicode:characters_to_binary(inet:ntoa(IpAddress)), Port}};
        {error, _} ->
            {'Left', 'Closed'}
    end.

%% Report Appendix E.1, E.18: Io.Error for what the host's sockets answer, a
%% code by its constructor or in the host's words, and for what the host's
%% ssl answers of its own, a file it cannot read, an option it refuses or
%% an alert, in its words. A certificate, a key or a CA file the host
%% cannot read or refuses is read from the option the host names, since
%% its words for it are the term (file_error/2, docs/otp_bugs.md, 9). An
%% alert's
%% words end in a line feed, which ends the host's report of it and no
%% part of the reason, so the white space that ends ssl's text is left
%% out, and the rest kept as the host writes it, its line feeds within.
io_error(_, closed) -> 'Closed';
io_error(_, etimedout) -> 'Timeout';
io_error(gen_tcp, Error) -> ern_io:host_error(Error, fun inet:format_error/1);
io_error(ssl, Error) when is_atom(Error) -> ern_io:host_error(Error, fun inet:format_error/1);
io_error(ssl, {options, {Option, {File, Reason}}})
  when Option =:= certfile; Option =:= keyfile; Option =:= cacertfile ->
    file_error(File, Reason);
io_error(ssl, {options, {Option, File, Reason}})
  when Option =:= certfile; Option =:= keyfile; Option =:= cacertfile ->
    file_error(File, Reason);
io_error(ssl, Error) ->
    {'Other', unicode:characters_to_binary(string:trim(ssl:format_error(Error), trailing))}.

%% Report Appendix E.1, E.18: a certificate's, a key's or a CA file's
%% failure, answered for a file the host cannot read as Fs answers the
%% path, by the host's code, and for one it refuses as Other(text), the
%% file's name and what is wrong on one line: Ernest's words for the
%% reasons the host names, and else the host's reason as it writes it.
file_error(File, {error, Reason}) ->
    file_error(File, Reason);
file_error(File, no_certs) ->
    file_other(File, "no certificate");
file_error(File, {unexpected_content, {missing_single_key, _}}) ->
    file_other(File, "not one key");
file_error(File, {unexpected_content, _}) ->
    file_other(File, "not a key");
file_error(File, Reason) when is_atom(Reason) ->
    case ern_io:host_error(Reason, fun file:format_error/1) of
        {'Other', Text} -> file_other(File, Text);
        Named -> Named
    end;
file_error(File, Reason) ->
    file_other(File, io_lib:format("~0p", [Reason])).

file_other(File, Text) ->
    {'Other', unicode:characters_to_binary([File, ": ", Text])}.
