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

-include_lib("kernel/include/file.hrl").

%% Report Appendix E.18: the host's process of a connection over TLS
%% hibernates after a millisecond's wait, the host's shortest timer.
-define(TLS_WAITS, [{hibernate_after, 1}]).

%% Report Appendix E.18: a listener's and a socket's loops end only in the
%% exit that tells a waiting call the socket was closed or its owner died,
%% so the fun `opened` spawns never returns, which Dialyzer would report.
-dialyzer({nowarn_function, opened/7}).

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({own_process, [serve/2, counted_request/2, opened/7, listener_loop/4, socket_process/6,
                         writing/3, handshake_failed/2, socket_loop/1, stop_writer/1,
                         closer/1, lingering/5]}).

%% A socket's process: its transport, the host's socket, the writer that
%% writes to it, the closer that closes it, its owner and the owner's
%% monitor, the reads with no bytes
%% yet, oldest first, the writes the writer holds, oldest first, the bytes
%% no read has taken, and whether the connection is open or closed, or,
%% for a socket over TLS that accept answered, handshaking until its
%% handshake ends. The host's socket is asked for bytes only while a read
%% waits, so a program that stops reading holds the far end back.
-record(connection, {transport, socket, writer, closer, owner, monitor_ref, waiting = [],
                     writes = [], buffer = <<>>, state = open}).

%% A read waiting: its reply, the reference of its caller's monitor, which
%% names the read to its timer too, its deadline and its timer.
-record(read, {reply, monitor_ref, deadline, timer}).

%% A write the writer holds, oldest first in the connection: its reply, its
%% deadline, and its timer, `expired` once it has answered `Left(Timeout)`.
-record(write, {reply, deadline, timer}).

%% Report Appendix E.18: how long the host's socket may send what the far
%% end has not taken once the socket has ended: until 5 seconds pass with
%% nothing taken, and 3 minutes in all. The closer looks at what the host
%% holds a fifth of the idle window apart, so that what the far end takes
%% is seen within the window's own grain and the idle end comes at most a
%% fifth late; nothing the host documents wakes a process as its queue
%% drains.
-define(LINGER_IDLE, 5000).
-define(LINGER_LIMIT, 180000).
-define(LINGER_CHECK, (?LINGER_IDLE div 5)).

%% Report §8.6: every listener and socket is linked to this process, which
%% the runtime kills when the program ends, so none outlives it; this
%% process traps the exits, so that one ending takes nothing else with it,
%% and forgets what the runtime recorded of the one that ended.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self(), unstarted).

%% Tls is whether the host's ssl is started, which the first request over
%% TLS does (with_ssl/3). E.0 shape rule 8: a connect given no time, 0 or
%% below, has run out as it begins, and the host is asked nothing.
serve(Tcp, Tls) ->
    receive
        {'Connect', _, _, Ms, _, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            serve(Tcp, Tls);
        {'ConnectTls', _, _, _, Ms, _, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            serve(Tcp, Tls);
        {'Listen', Host, Port, Owner, Reply} ->
            requested(fun() -> listen(Tcp, Host, Port, plain, Owner, Reply) end, Reply),
            serve(Tcp, Tls);
        {'ListenTls', Host, Port, Certificate, Key, Owner, Reply} ->
            Kind = {tls, Certificate, Key},
            serve(Tcp, with_ssl(Tls, Reply,
                                fun() ->
                                    requested(fun() -> listen(Tcp, Host, Port, Kind, Owner, Reply)
                                              end, Reply)
                                end));
        {'Connect', Host, Port, Ms, Owner, Reply} ->
            counted_request(fun() ->
                                connect(Tcp, Host, Port, plain, ern_rt:deadline(Ms), Owner, Reply)
                            end, Reply),
            serve(Tcp, Tls);
        {'ConnectTls', Host, Port, Verification, Ms, Owner, Reply} ->
            Kind = {tls, Verification},
            serve(Tcp, with_ssl(Tls, Reply,
                                fun() ->
                                    counted_request(fun() ->
                                                        connect(Tcp, Host, Port, Kind,
                                                                ern_rt:deadline(Ms), Owner, Reply)
                                                    end, Reply)
                                end));
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Tcp, Tls)
    end.

%% Report Appendix E.18, §12: a request over TLS, made once the host's ssl
%% is started and its code loaded whole (tls_loaded/0), which the first
%% such request of a launch does where nothing has, a node's carrier among
%% them, whose distribution runs without it. A start that fails answers
%% the request with the host's reason, a load that fails with the module
%% the host could not load, and the next request tries again.
with_ssl(started, _, Request) ->
    Request(),
    started;
with_ssl(unstarted, Reply, Request) ->
    case application:ensure_all_started(ssl) of
        {ok, _} ->
            case tls_loaded() of
                ok ->
                    with_ssl(started, Reply, Request);
                {error, Module} ->
                    ern_rt:answer(Reply, {'Left', {'Other', <<"the host could not load ",
                                                              Module/binary>>}}),
                    unstarted
            end;
        {error, Error} ->
            ern_rt:answer(Reply, {'Left', ern_io:other(Error, fun ssl:format_error/1)}),
            unstarted
    end.

%% Report §12: the host's TLS loaded whole, ssl's modules and those of the
%% applications it starts with it, as OTP 29 has them, so that a handshake
%% at the limit of open files finds its code. A request over TLS may come
%% near the limit, so the modules are loaded one at a time, each holding
%% one file: the host's loader of a list reads its files at once, and
%% fails with files to spare. The host's loader gives no reason a module
%% could not be loaded (docs/otp_bugs.md, 13).
tls_loaded() ->
    loaded_each(lists:append([Modules || Application <- [crypto, asn1, public_key, ssl],
                                         {ok, Modules} <- [application:get_key(Application,
                                                                               modules)]])).

loaded_each([]) ->
    ok;
loaded_each([Module | Modules]) ->
    case code:ensure_loaded(Module) of
        {module, Module} -> loaded_each(Modules);
        {error, _} -> {error, atom_to_binary(Module)}
    end.

%% A worker of its own for a request, which Work carries out and answers.
%% Report §7.4, §12.5: where the host's table of processes is full, it
%% cannot be made, and the request's caller faults with the host's class
%% and reason, `Fault("error:system_limit")`, the process that took the
%% request living on.
requested(Work, Reply) ->
    try erlang:spawn(Work)
    catch error:system_limit -> answered(Reply, limited())
    end.

%% The same for a request that waits, its worker counted as a source before
%% it starts, so that its answer cannot come before its count; it ends the
%% count itself.
counted_request(Work, Reply) ->
    try erlang:spawn(fun() -> receive go -> Work() end end) of
        Worker ->
            ern_rt:source_begin(Worker),
            Worker ! go
    catch
        error:system_limit -> answered(Reply, limited())
    end.

%% Report §7.4, §12.5: the answer of a request whose process the host's
%% full table of processes keeps from being made.
limited() ->
    {fault, ern_rt:host_cause(error, system_limit)}.

%% An answer, or the caller faulted (limited/0).
answered(Reply, {fault, Cause}) -> ern_rt:refuse(Reply, Cause);
answered(Reply, Answer) -> ern_rt:answer(Reply, Answer).

%% A listener or a socket, linked to the TCP process and recorded as opened
%% before its address is given out (report §8.6), under the function that
%% opened it, and as started by its owner (Appendix E.18), whom it watches
%% from before then too, so that what an owner holds is what watches it
%% (ern_rt:evaluate/2); Loop is given the monitor, and what Made made in
%% the process before its address is given out, a socket's writer, once the
%% host's socket is the process's. It traps exits from its start, so that
%% however it ends, by a kill, with the program or with the TCP process, it
%% closes its host's socket itself (close_socket/3). Report §7.4, §12.5:
%% where the host's table of processes is full, so that the process or what
%% Made makes cannot be made, the host's error is raised here, before the
%% address is given out (held_open/3).
opened(Tcp, Transport, Socket, Made, Loop, Site, Owner) ->
    Opener = erlang:self(),
    Pid = erlang:spawn(fun() ->
                           process_flag(trap_exit, true),
                           link(Tcp),
                           MonitorRef = erlang:monitor(process, Owner),
                           try Made() of
                               Held ->
                                   Opener ! {erlang:self(), watching},
                                   receive go -> Loop(MonitorRef, Held) end
                           catch
                               error:system_limit -> Opener ! {erlang:self(), system_limit}
                           end
                       end),
    receive
        {Pid, watching} -> ok;
        {Pid, system_limit} -> erlang:error(system_limit)
    end,
    ern_rt:opened(Pid, Site, Owner),
    _ = Transport:controlling_process(Socket, Pid),
    Pid ! go,
    Pid.

%% Report Appendix E.18: a listener on the interface the host's name or
%% address names, over TCP or over TLS, whose certificate and key the
%% host's ssl reads as it listens, each found a file first (regular_file/1).
%% Every request is answered: a port out of range, and what the host
%% refuses by raising, are errors as much as what it answers.
listen(Tcp, Host, Port, Kind, Owner, Reply) ->
    Answer = case {in_range(Port), ip_address(Host), listening(Kind)} of
                 {false, _, _} ->
                     {'Left', 'Invalid'};
                 {true, {error, Error}, _} ->
                     {'Left', io_error(gen_tcp, Error)};
                 {true, invalid, _} ->
                     {'Left', 'Invalid'};
                 {true, _, {error, Error}} ->
                     {'Left', Error};
                 {true, {ok, IpAddress}, {Transport, Site, KindOptions}} ->
                     Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw},
                                {ip, IpAddress}]
                         ++ family(IpAddress) ++ family_alone(IpAddress) ++ KindOptions,
                     case guarded(fun() -> Transport:listen(Port, Options) end) of
                         {ok, Socket} ->
                             %% report §6.9, Appendix E.18: owned by the
                             %% process that opened it, with which it ends
                             Loop = fun(MonitorRef, none) ->
                                        listener_loop(Tcp, Transport, Socket, MonitorRef)
                                    end,
                             Open = fun(Listening) ->
                                        opened(Tcp, Transport, Listening, fun() -> none end,
                                               Loop, Site, Owner)
                                    end,
                             held_open(Open, Transport, Socket);
                         {error, Error} ->
                             {'Left', io_error(Transport, Error)}
                     end
             end,
    answered(Reply, Answer).

%% What Open answers with the listener or the socket it opens over the
%% host's Socket. Report §7.4, §12.5: where the host's table of processes
%% is full, so that its process cannot be made (opened/7), the host's
%% socket is closed, and the request's caller faults with the host's class
%% and reason.
held_open(Open, Transport, Socket) ->
    try {'Right', Open(Socket)}
    catch
        error:system_limit ->
            Transport:close(Socket),
            limited()
    end.

%% Report Appendix E.18: what a listener's kind adds, its transport, its
%% site and, over TLS, the server's certificate, its chain after it, and
%% its key.
listening(plain) ->
    {gen_tcp, <<"Tcp.listen">>, []};
listening({tls, {'Path', Certificate}, {'Path', Key}}) ->
    case {regular_file(Certificate), regular_file(Key)} of
        {{error, Error}, _} -> {error, Error};
        {_, {error, Error}} -> {error, Error};
        {{ok, CertificateFile}, {ok, KeyFile}} ->
            {ssl, <<"Tcp.listenTls">>,
             [{certfile, CertificateFile}, {keyfile, KeyFile} | ?TLS_WAITS]}
    end.

%% Report Appendix E.18, E.17: a file of a listener's or a check's, by the
%% name the host's ssl takes, found a regular file as Fs finds the file it
%% reads: `Invalid` where its path holds U+0000, which names no file, and
%% where the host cannot reach it or it is no regular file, what Fs answers
%% for the path with the file's name, `cert.pem: NotAFile` for a directory
%% among them (file_error/2).
regular_file(Path) ->
    case binary:match(Path, <<0>>) of
        nomatch ->
            File = unicode:characters_to_list(Path),
            case file:read_file_info(File, [raw]) of
                {ok, #file_info{type = regular}} -> {ok, File};
                {ok, _} -> {error, file_other(File, atom_to_binary('NotAFile'))};
                {error, Error} -> {error, file_error(File, Error)}
            end;
        _ ->
            {error, 'Invalid'}
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

%% Report Appendix E.18: a listener takes connections of its address's
%% family alone, the host's IPV6_V6ONLY, so that one on "::" takes no IPv4
%% connection as ::ffff:a.b.c.d and one on "0.0.0.0" stands beside it on
%% its port. An IPv4 address written as IPv6's, ::ffff:a.b.c.d, is then
%% one no listener can take a connection at, which the host refuses as
%% invalid.
family_alone({_, _, _, _, _, _, _, _}) -> [{ipv6_v6only, true}];
family_alone(_) -> [].

%% What the host raises for an input it refuses, as the error it would be,
%% whatever the class it raises: a worker that dies of one answers nothing.
guarded(Call) ->
    try Call()
    catch _:Error -> {error, Error}
    end.

%% Report Appendix E.18: a connect that times out takes no connection, since
%% the host closes one it completes after its own time limit. A limit past
%% the host's longest timer is waited in slices, each a new attempt; over
%% TLS, each attempt's limit holds its handshake too. A port out of range
%% is answered first, and over TLS the file of the check's certificates is
%% read before the dial, so that what is wrong with it is answered
%% whatever the far end does.
connect(Tcp, Host, Port, Kind, Deadline, Owner, Reply) ->
    Connecting = case in_range(Port) of
                     true -> connecting(Kind, Host);
                     false -> {error, 'Invalid'}
                 end,
    case Connecting of
        {error, Error} ->
            end_source(Reply, {'Left', Error});
        {Transport, Site, KindOptions} ->
            Options = [binary, {active, false}, {packet, raw} | KindOptions],
            Try = fun() ->
                      case ip_address(Host) of
                          {ok, IpAddress} ->
                              %% report Appendix E.18: the address the host
                              %% names, of its own family, IPv6's included
                              guarded(fun() ->
                                          Transport:connect(IpAddress, Port,
                                                            Options ++ family(IpAddress),
                                                            ern_rt:remaining(Deadline))
                                      end);
                          Failed ->
                              Failed
                      end
                  end,
            Open = fun(Socket) -> socket_process(Tcp, Transport, Socket, open, Owner, Site) end,
            attempt(Transport, Try, Open, Deadline, Reply)
    end.

%% Report Appendix E.18: what a connect's kind adds, its transport, its site
%% and, over TLS, the check of the far end's certificate and the host's
%% name the far end is told, or the error of the file of the check's
%% certificates.
connecting(plain, _) ->
    {gen_tcp, <<"Tcp.connect">>, []};
connecting({tls, Verification}, Host) ->
    Reference = reference(Host),
    case verification(Verification, Reference) of
        {error, Error} -> {error, Error};
        Checked -> {ssl, <<"Tcp.connectTls">>, Checked ++ server_name(Reference) ++ ?TLS_WAITS}
    end.

%% Report Appendix E.18: `Verified(caFile)` checks the far end's certificate
%% against the file's certificates, and for naming the host, which the
%% host's ssl checks under verify_peer by the name server_name/1 gives it,
%% or, for a host that is an address, by the address it connects to; a
%% certificate names a host through a wildcard, `*.example.test` naming
%% `www.example.test`, as the host's match for HTTPS reads one, where the
%% host's own match takes a name only as written. `Unverified` checks
%% nothing. The host's ssl reads the file again as it checks, from its
%% own cache of the file, which costs a handshake nothing once read.
verification({'Verified', {'Path', Certificates}}, Reference) ->
    case authorities(Certificates) of
        {ok, File} ->
            [{verify, verify_peer}, {cacertfile, File},
             {verify_fun, {fun verify/4, {File, Reference, held}}},
             {partial_chain, fun(Chain) -> pinned(Chain, File, Reference) end},
             {customize_hostname_check, [{match_fun, wildcards()}]}];
        Error ->
            Error
    end;
verification('Unverified', _) ->
    [{verify, verify_none}].

%% Report Appendix E.18, E.17: the file of a check's certificates, found a
%% regular file as listenTls's files are, and read: one from which no
%% certificate in PEM decodes is refused, as listenTls refuses a server's
%% file that holds none. The file's first certificate that decodes is
%% enough, so that a check over the host's whole list of authorities reads
%% the list and decodes one of them.
authorities(Path) ->
    case regular_file(Path) of
        {ok, File} ->
            case file:read_file(File, [raw]) of
                {ok, Pem} ->
                    case holds_a_certificate(Pem) of
                        true -> {ok, File};
                        false -> {error, file_other(File, "no certificate")}
                    end;
                {error, Error} ->
                    {error, file_error(File, Error)}
            end;
        Error ->
            Error
    end.

%% Whether text in PEM holds a certificate that decodes: each part that
%% begins and ends as one, read in turn until one decodes. The host's
%% decoder raises for a part that is no base64.
holds_a_certificate(Pem) ->
    Begin = <<"-----BEGIN CERTIFICATE-----">>,
    End = <<"-----END CERTIFICATE-----">>,
    case binary:match(Pem, Begin) of
        nomatch ->
            false;
        {Start, _} ->
            case binary:match(Pem, End, [{scope, {Start, byte_size(Pem) - Start}}]) of
                nomatch ->
                    false;
                {Ending, Length} ->
                    Part = binary:part(Pem, Start, Ending + Length - Start),
                    Rest = binary:part(Pem, Ending + Length, byte_size(Pem) - Ending - Length),
                    is_certificate(Part) orelse holds_a_certificate(Rest)
            end
    end.

is_certificate(Part) ->
    try public_key:pem_decode(Part) of
        [{'Certificate', Der, not_encrypted}] -> is_tuple(public_key:pkix_decode_cert(Der, otp));
        _ -> false
    catch
        error:_ -> false
    end.

%% Report Appendix E.18: the check of each certificate of the far end's
%% chain, the host's own under verify_peer but where the host finds no
%% authority of the file's for the chain and refuses it before it looks
%% in the file for the far end's own certificate or the chain's: a far end
%% that sends one certificate, self-signed or one whose issuer the file
%% lacks, and a chain whose first, self-signed, the file lacks. The file
%% is read here on that path alone, and in pinned/3 on the path that
%% fails otherwise, so that the ordinary path costs nothing more.
%%
%% A far end's own certificate, sent alone, is taken where the file holds
%% it as sent and it names the host connected to, as the host's own check
%% reads a name, which the host leaves unchecked once it is taken. A
%% chain's first that is self-signed is no far end's own: one the file
%% holds is the chain's authority, and one it lacks is taken in its place
%% until the chain meets a certificate the file holds, the host checking
%% the chain beneath it and the far end's name; a chain that meets none is
%% refused at the far end's own. State is the file, the host, and whether
%% the chain has met a certificate the file holds: `held`, or `{unheld,
%% Held}`, the file's certificates, once an authority it lacks is taken.
verify(OtpCert, Der, {bad_cert, Reason}, {File, Reference, held} = State)
  when Reason =:= selfsigned_peer; Reason =:= unknown_ca; Reason =:= invalid_issuer ->
    Held = held(File),
    IsOwn = Reason =:= selfsigned_peer orelse not public_key:pkix_is_self_signed(OtpCert),
    case {lists:member(Der, Held), IsOwn} of
        {true, true} ->
            case names(OtpCert, Reference) of
                true -> {valid, State};
                false -> {fail, {bad_cert, hostname_check_failed}}
            end;
        {true, false} ->
            {valid, State};
        {false, true} ->
            {fail, {bad_cert, Reason}};
        {false, false} ->
            {valid, {File, Reference, {unheld, Held}}}
    end;
verify(_, _, {bad_cert, _} = Reason, _) ->
    {fail, Reason};
verify(_, _, {extension, _}, State) ->
    {unknown, State};
verify(_, Der, valid, {File, Reference, {unheld, Held}} = State) ->
    case lists:member(Der, Held) of
        true -> {valid, {File, Reference, held}};
        false -> {valid, State}
    end;
verify(_, Der, valid_peer, {_, _, {unheld, Held}} = State) ->
    case lists:member(Der, Held) of
        true -> {valid, State};
        false -> {fail, {bad_cert, unknown_ca}}
    end;
verify(_, _, valid, State) ->
    {valid, State};
verify(_, _, valid_peer, State) ->
    {valid, State}.

%% Report Appendix E.18: a chain of more than one certificate, Chain from
%% the one nearest an authority to the far end's own, which the host offers
%% before it checks it, so that the chain leads to a certificate the file
%% holds where it holds one of the chain's, as sent, and not only its
%% authority. Where the chain's first is self-signed, the host has found
%% it in the file or verify/4 reads the file as the host refuses it, so
%% the ordinary path reads no file. Else the host refuses the chain but
%% here: the file's certificate nearest the authority is the chain's
%% anchor, the host checking the rest and the far end's name; where that
%% is the far end's own, the host checks nothing more, so its name is
%% checked here, as verify/4 checks it.
pinned([First | _] = Chain, File, Reference) ->
    case public_key:pkix_is_self_signed(First) of
        true ->
            unknown_ca;
        false ->
            Held = held(File),
            case lists:dropwhile(fun(Der) -> not lists:member(Der, Held) end, Chain) of
                [] ->
                    unknown_ca;
                [Own] ->
                    case names(public_key:pkix_decode_cert(Own, otp), Reference) of
                        true -> {trusted_ca, Own};
                        false -> unknown_ca
                    end;
                [Anchor | _] ->
                    {trusted_ca, Anchor}
            end
    end.

%% Whether a certificate names the host connected to, as the host's own
%% check reads a name, through a wildcard among the ways.
names(OtpCert, Reference) ->
    public_key:pkix_verify_hostname(OtpCert, Reference, [{match_fun, wildcards()}]).

%% Report Appendix E.18: the host connected to, as a certificate is
%% checked for naming it and the far end is told it, the name as given,
%% its trailing dots left out, as the host's ssl takes it from a name it
%% connects to, or the address, which a certificate names as one.
reference(Host) ->
    Name = unicode:characters_to_list(Host),
    case inet:parse_address(Name) of
        {ok, IpAddress} -> [{ip, IpAddress}];
        {error, _} -> [{dns_id, string:trim(Name, trailing, ".")}]
    end.

%% Report Appendix E.18: the host's name the far end is told; none for an
%% address, since connect/7 connects to the address the name stands for.
server_name(Reference) ->
    [{server_name_indication, Name} || {dns_id, Name} <- Reference].

%% A certificate's wildcard read as the host's match for HTTPS reads one.
wildcards() ->
    public_key:pkix_verify_hostname_match_fun(https).

%% The certificates of the file, as sent, none where it can no longer be
%% read or decoded.
held(File) ->
    try file:read_file(File, [raw]) of
        {ok, Pem} -> [Der || {'Certificate', Der, not_encrypted} <- public_key:pem_decode(Pem)];
        {error, _} -> []
    catch
        error:_ -> []
    end.

%% Report Appendix E.18: a connect or an accept, tried again after the
%% host's timeout until the deadline has passed, and its answer given: the
%% socket's process, which Open starts, owned by the process that asked,
%% Timeout, or why it failed.
attempt(Transport, Try, Open, Deadline, Reply) ->
    Answer = case Try() of
                 {ok, Socket} ->
                     held_open(Open, Transport, Socket);
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
        again -> attempt(Transport, Try, Open, Deadline, Reply);
        _ -> end_source(Reply, Answer)
    end.

%% The answer to a request counted as a source, given before its count
%% ends, so that no deadlock is found between the two (report §8.6).
end_source(Reply, Answer) ->
    answered(Reply, Answer),
    ern_rt:source_end().

%% A listener answers each Accept by a worker of its own, so that a slow
%% accept does not hold up the next request, and ends at CloseListener,
%% whose close of the socket answers each accept still waiting. E.0 shape
%% rule 8: an accept given no time has run out as it begins, and takes no
%% connection the host holds.
listener_loop(Tcp, Transport, Socket, MonitorRef) ->
    receive
        {'Accept', Ms, _, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            listener_loop(Tcp, Transport, Socket, MonitorRef);
        {'Accept', Ms, Owner, Reply} ->
            counted_request(fun() ->
                                accept(Tcp, Transport, Socket, ern_rt:deadline(Ms), Owner, Reply)
                            end, Reply),
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
%% an owner that has already ended fires at once. Its closer and its writer
%% are made with it, before its address is given out, so that its end makes
%% no process (closer/1): the closer first, which ends with the socket's
%% process where the writer cannot be made.
socket_process(Tcp, Transport, Socket, State, Owner, Site) ->
    Made = fun() ->
               Self = erlang:self(),
               Closer = erlang:spawn(fun() -> closer(Self) end),
               Writer = erlang:spawn_link(fun() ->
                                              receive go -> writer(Transport, Socket, Self, State)
                                              end
                                          end),
               {Writer, Closer}
           end,
    Loop = fun(MonitorRef, {Writer, Closer}) ->
               ern_rt:socket_processes([Writer, Closer]),
               Writer ! go,
               socket_loop(#connection{transport = Transport, socket = Socket, writer = Writer,
                                       closer = Closer, owner = Owner, monitor_ref = MonitorRef,
                                       state = State})
           end,
    opened(Tcp, Transport, Socket, Made, Loop, Site, Owner).

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

socket_loop(#connection{transport = Transport, socket = Socket, writer = Writer, closer = Closer,
                        monitor_ref = MonitorRef, state = State} = Connection) ->
    receive
        {'Read', Ms, Reply} ->
            socket_loop(read(Ms, Reply, Connection));
        %% E.0 shape rule 8: a write given no time has run out as it
        %% begins, and gives the host nothing
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            socket_loop(Connection);
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
            socket_loop(Connection#connection{owner = Owner,
                                              monitor_ref = erlang:monitor(process, Owner)});
        %% report Appendix E.18: its owner has died, and it is killed
        {'DOWN', MonitorRef, process, _, _} ->
            stop_writer(Writer),
            close_socket(Transport, Socket, Closer),
            exit({ern, killed});
        %% report Appendix E.18: a read whose caller has ended before it
        %% was answered
        {'DOWN', ReadRef, process, _, _} ->
            socket_loop(dropped(ReadRef, Connection));
        'Close' ->
            #connection{writes = Writes} = closed('Closed', Connection),
            stop_writer(Writer),
            %% report Appendix E.18: each write it holds answers `Left(Closed)`,
            %% and one the writer answered first keeps its answer
            lists:foreach(fun(#write{reply = Reply}) ->
                              ern_rt:answer(Reply, {'Left', 'Closed'})
                          end, Writes),
            close_socket(Transport, Socket, Closer),
            %% report Appendix E.18: a call after the close faults its caller
            exit({ern, closed});
        %% the writer's exit, or the host's socket's when the far end has
        %% closed it, which end nothing
        {'EXIT', _, normal} ->
            socket_loop(Connection);
        %% report Appendix E.18: killed, or ended with the program
        {'EXIT', _, ExitReason} ->
            stop_writer(Writer),
            close_socket(Transport, Socket, Closer),
            exit(ExitReason);
        {'Remote', Reply} ->
            Inet = inet_module(Transport),
            ern_rt:answer(Reply, endpoint(State, fun() -> Inet:peername(Socket) end)),
            socket_loop(Connection);
        {'Local', Reply} ->
            Inet = inet_module(Transport),
            ern_rt:answer(Reply, endpoint(State, fun() -> Inet:sockname(Socket) end)),
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
inet_module(gen_tcp) -> inet;
inet_module(ssl) -> ssl.

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
%% so a socket with bytes waiting is handed to its closer first. A socket
%% over TLS is too, since ssl's close writes the record that ends the
%% connection and waits for the far end's answer, in two waits of 5
%% seconds of its own whatever time it is given (docs/otp_bugs.md, 10).
%% Where the host can no longer read the socket's statistics, or give it
%% to the closer, its connection has gone, and it is closed here; the
%% closer then ends with the socket's process (closer/1).
close_socket(Transport, Socket, Closer) ->
    Inet = inet_module(Transport),
    case Inet:getstat(Socket, [send_pend]) of
        {ok, [{send_pend, Pending}]} when Pending > 0; Transport =:= ssl ->
            Ended = erlang:monotonic_time(millisecond),
            _ = Inet:setopts(Socket, [{active, false}]),
            case Transport:controlling_process(Socket, Closer) of
                ok -> Closer ! {close, Transport, Socket, Pending, Ended};
                {error, _} -> Transport:close(Socket)
            end;
        _ ->
            Transport:close(Socket)
    end.

%% Report Appendix E.18: a socket's closer, waiting from the socket's start
%% for the host's socket, which the socket's process gives it at its end
%% with what the host held then (close_socket/3), or for that process's
%% end, after which it holds nothing to close. A full table of the host's
%% so loses no socket's lingering.
closer(SocketProcess) ->
    MonitorRef = erlang:monitor(process, SocketProcess),
    receive
        {close, Transport, Socket, Pending, Ended} ->
            erlang:demonitor(MonitorRef, [flush]),
            lingering(Transport, Socket, Pending, Ended, Ended);
        {'DOWN', MonitorRef, process, _, _} ->
            ok
    end.

%% Report Appendix E.18: the closer looks at what the host still holds, at
%% once and then every LINGER_CHECK. Nothing left closes the socket. Nothing
%% taken for 5 seconds, or 3 minutes since the end, drops the rest and
%% resets the connection, which the host's close does with a linger of no
%% time.
lingering(Transport, Socket, Pending, Moved, Ended) ->
    Inet = inet_module(Transport),
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
    Write = #write{reply = Reply, deadline = Deadline, timer = arm({write, Reply}, Deadline)},
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
                            arm({write, Reply}, Deadline)
                    end,
            Later = lists:keystore(Reply, #write.reply, Writes, Write#write{timer = Timer}),
            Connection#connection{writes = Later};
        false ->
            Connection
    end.

%% Report Appendix E.18: the writer has answered its oldest write, which
%% lets go of its timer.
written(#connection{writes = [#write{timer = Timer} | Rest]} = Connection) ->
    Timer =:= expired orelse let_go(Timer),
    Connection#connection{writes = Rest}.

%% Report Appendix E.18: a read is answered the bytes no read has taken, or
%% `Left(Closed)` once the connection has closed, or else waits, counted as
%% a source, its caller watched, the host's socket asked for bytes when it
%% is the first to wait on an open connection; one that waits for a
%% handshake waits within its own milliseconds, and its `Left(Timeout)`
%% leaves the handshake under way. E.0 shape rule 8: a read given no time
%% has run out as it begins, whatever has arrived, and takes nothing.
read(Ms, Reply, Connection) when Ms =< 0 ->
    ern_rt:answer(Reply, {'Left', 'Timeout'}),
    Connection;
read(Ms, Reply, #connection{waiting = Waiting, buffer = Buffer,
                            state = State} = Connection) ->
    case {Buffer, State} of
        {<<>>, closed} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            Connection;
        {<<>>, _} ->
            ern_rt:source_begin(),
            MonitorRef = erlang:monitor(process, ern_rt:reply_process(Reply)),
            Deadline = ern_rt:deadline(Ms),
            Read = #read{reply = Reply, monitor_ref = MonitorRef, deadline = Deadline,
                         timer = arm({read, MonitorRef}, Deadline)},
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
    _ = (inet_module(Transport)):setopts(Socket, [{active, once}]),
    Connection;
asked(Connection) ->
    Connection.

%% A read's time has passed: answered `Left(Timeout)`, or armed again where
%% the deadline is past the host's longest timer; one answered as it came
%% is gone.
read_timed_out(MonitorRef, #connection{waiting = Waiting} = Connection) ->
    case lists:keytake(MonitorRef, #read.monitor_ref, Waiting) of
        {value, #read{deadline = Deadline} = Read, Rest} ->
            case ern_rt:remaining(Deadline) of
                0 ->
                    answered_read(Read, {'Left', 'Timeout'}),
                    Connection#connection{waiting = Rest};
                _ ->
                    Again = Read#read{timer = arm({read, MonitorRef}, Deadline)},
                    Later = lists:keystore(MonitorRef, #read.monitor_ref, Waiting, Again),
                    Connection#connection{waiting = Later}
            end;
        false ->
            Connection
    end.

%% Bytes that came: the oldest read waiting answered them, the host's
%% socket asked again while another waits; where none waits, its read timed
%% out as they came, and they wait for the next.
%%
%% Report Appendix E.18: the bytes go to a read whose caller lives as it is
%% answered. A caller's `DOWN` comes after its end, ordered with nothing
%% the host's socket sends, so the host is asked first, of a caller of this
%% node, since the socket's address is bound to it (report §3.11); a read
%% whose caller has ended is dropped as its `DOWN` would drop it, and the
%% bytes go to the next.
arrived(Bytes, #connection{waiting = Waiting, buffer = Buffer} = Connection) ->
    case Waiting of
        [#read{reply = Reply, monitor_ref = MonitorRef} = Read | Rest] ->
            case erlang:is_process_alive(ern_rt:reply_process(Reply)) of
                true ->
                    answered_read(Read, {'Right', Bytes}),
                    Rest =/= [] andalso asked(Connection),
                    Connection#connection{waiting = Rest};
                false ->
                    arrived(Bytes, dropped(MonitorRef, Connection))
            end;
        [] ->
            Connection#connection{buffer = <<Buffer/binary, Bytes/binary>>}
    end.

%% A read answered: its timer let go, its caller no longer watched, and its
%% count as a source ended once it has its answer.
answered_read(#read{reply = Reply, monitor_ref = MonitorRef, timer = Timer}, Answer) ->
    let_go(Timer),
    erlang:demonitor(MonitorRef, [flush]),
    end_source(Reply, Answer).

%% Report Appendix E.18: a read whose caller has ended before it was
%% answered is dropped as one that times out is: it has taken nothing, and
%% bytes that arrive later wait for the next read. Its caller is no longer
%% watched, a `DOWN` on its way among it.
dropped(MonitorRef, #connection{waiting = Waiting} = Connection) ->
    {value, #read{timer = Timer}, Rest} = lists:keytake(MonitorRef, #read.monitor_ref, Waiting),
    let_go(Timer),
    erlang:demonitor(MonitorRef, [flush]),
    ern_rt:source_end(),
    Connection#connection{waiting = Rest}.

%% A request's timer, a read's by its caller's monitor and a write's by its
%% reply, armed again until its deadline has passed (report §6.3).
arm(Kind, Deadline) ->
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {deadline, Kind}).

%% Report Appendix E.18: a request answered holds no timer. One that fired
%% as its request was answered finds the request gone, and does nothing.
let_go(Timer) ->
    erlang:cancel_timer(Timer, [{async, true}, {info, false}]).

%% Report Appendix E.18: once the connection has closed, each read waiting
%% answers `Left(Closed)`, or a failed handshake's `Left`, and each read
%% after `Left(Closed)`, the socket living on until Close. Report Appendix
%% E.28: the socket is then spent.
closed(Error, #connection{owner = Owner, waiting = Waiting, state = State} = Connection) ->
    lists:foreach(fun(Read) -> answered_read(Read, {'Left', Error}) end, Waiting),
    State =:= closed orelse ern_rt:spent(Owner),
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
%% alert's words end in a line feed, which ends the host's report of it
%% and no part of the reason, so the white space that ends ssl's text is
%% left out, and the rest kept as the host writes it, its line feeds
%% within.
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
%% failure, Other(text), the file's name and what is wrong on one line: for
%% a file the host cannot read, the answer Fs gives for the path, by the
%% host's code, `cert.pem: Denied`, so that it is told from the port's;
%% for one it refuses, Ernest's words for the reasons the host names, and
%% else the host's reason as it writes it.
file_error(File, {error, Reason}) ->
    file_error(File, Reason);
file_error(File, no_certs) ->
    file_other(File, "no certificate");
file_error(File, {unexpected_content, {missing_single_key, _}}) ->
    file_other(File, "not one key");
file_error(File, {unexpected_content, _}) ->
    file_other(File, "not a key");
file_error(File, Reason) when is_atom(Reason) ->
    ern_io:path_error(File, ern_io:host_error(Reason, fun file:format_error/1));
file_error(File, Reason) ->
    file_other(File, io_lib:format("~0p", [Reason])).

file_other(File, Text) ->
    ern_io:path_error(File, {'Other', Text}).
