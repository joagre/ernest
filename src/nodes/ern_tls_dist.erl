%% Report §12.5: the carrier's distribution module, the host's over TLS,
%% `inet_tls_dist`, with an acceptor of the node's own, which `-proto_dist
%% ern_tls` names (ern_carrier:boot_flags/1), the host naming such a module
%% by its protocol and `_dist`. The host's acceptor ends at a connection a
%% full table of processes leaves no room for, and spins at the limit of
%% open files (docs/otp_bugs.md, 12 and 14); this one closes such a
%% connection and says so, and waits at the limit. Everything else is the
%% host's, over the node's family of addresses (family/0).
%%
%% A connection the acceptor takes needs room for its own process, the
%% host's TLS, the host's handshake and that handshake's timer, and then the
%% gateway's worker (ern_gateway). Each is made in turn, and the first that
%% finds no room closes the connection, the node saying so: by the address
%% it came from before the TLS handshake gives its key, and by the peer
%% after. The host's check of a peer's address, `check_ip`, and its kernel
%% TLS, `ktls`, are not made, since the carrier sets neither.
-module(ern_tls_dist).

-export([childspecs/0, select/1, address/0, is_node_name/1, listen/2, setup/5, close/1,
         accept/1, accept_connection/5]).

-include_lib("nodes/include/ern_node.hrl").

-receives({own_process, [accepted/5, settled_one/1, given/3, handed/4, watched/2]}).

%% Report §12.5: the host's handshake answers a full table as a DTLS upgrade
%% it does not support, a reason its specification leaves out
%% (docs/otp_bugs.md, 15), which Dialyzer would report.
-dialyzer({no_match, no_room/1}).

%% The protocol of a TLS connection as the host names it, which its
%% `accept` message and its listener's address carry.
-define(PROTOCOL, tls).

-spec childspecs() -> {ok, [supervisor:child_spec()]}.
childspecs() ->
    inet_tls_dist:childspecs().

-spec select(node()) -> boolean().
select(Node) ->
    inet_tls_dist:fam_select(family(), Node).

-spec address() -> term().
address() ->
    inet_tls_dist:fam_address(family()).

%% The host's takes the name as a string, though `net_kernel` names a node
%% by an atom; nothing in the host calls it.
-spec is_node_name(string()) -> boolean().
is_node_name(Node) ->
    inet_tls_dist:is_node_name(Node).

-spec listen(atom(), string()) -> {ok, {term(), term(), pos_integer()}} | {error, term()}.
listen(Name, Host) ->
    inet_tls_dist:fam_listen(family(), Name, Host).

%% Report §12.5: a dial is the host's own.
-spec setup(node(), term(), node(), longnames | shortnames, pos_integer()) -> pid().
setup(Node, Type, MyNode, LongOrShortNames, SetupTime) ->
    inet_tls_dist:fam_setup(family(), Node, Type, MyNode, LongOrShortNames, SetupTime).

-spec close(term()) -> ok.
close(Socket) ->
    inet_tls_dist:close(Socket).

%% Report §12.5: the node runs over its listener's family of addresses, or
%% IPv4 where it has none, which its configuration, listed before the
%% carrier starts, gives.
family() ->
    #configuration{listen = Listen} = ern_carrier:configuration(),
    ern_node:family(Listen).

%%
%% The acceptor
%%

%% Report §12.5: the acceptor, started by the host's `net_kernel` as it
%% listens, linked to it and run as the host runs its own; it lives as long
%% as the listener.
-spec accept(term()) -> pid().
accept(Listener) ->
    Kernel = self(),
    Family = family(),
    spawn_opt(fun() -> accepting(Listener, Kernel, Family, #{}) end,
              dist_util:net_ticker_spawn_options()).

%% Report §12.5: each connection taken in turn and given a process of its
%% own, which shakes hands with the peer, at most as many at once as the
%% host has schedulers online, as the host's acceptor holds its handshakes.
%% Pending holds each such process until it hands its connection to the
%% host, or ends.
accepting(Listener, Kernel, Family, Pending) ->
    case map_size(Pending) < erlang:system_info(schedulers_online) of
        true -> accepted(Listener, Kernel, Family, settled(Pending), unsaid);
        false -> accepting(Listener, Kernel, Family, settled_one(Pending))
    end.

%% Report §12.5: a connection whose process the full table leaves no room
%% for is closed as it opens, and the node says so by the address it came
%% from; one the full table of ports keeps from being taken the host closes,
%% and the node says so. At the limit of open files the connection waits
%% unaccepted, and the acceptor tries again once the dial's time has
%% passed: the host signals no file freed, and a dial waits that long for
%% its answer (ern_carrier:dial_ms/0), so that the node accepts again
%% within a dial's time of a file freed. It says so once, until it takes a
%% connection.
accepted(Listener, Kernel, Family, Pending, Said) ->
    case gen_tcp:accept(Listener) of
        {ok, Socket} ->
            accepting(Listener, Kernel, Family, opened(Socket, Kernel, Family, Pending));
        {error, Limit} when Limit =:= emfile; Limit =:= enfile ->
            Said =:= said
                orelse ern_carrier:say_later(["a connection waits: ", inet:format_error(Limit)]),
            receive after ern_carrier:dial_ms() -> ok end,
            accepted(Listener, Kernel, Family, Pending, said);
        {error, system_limit} ->
            ern_carrier:say_later("a connection was refused: this node's table of ports is full"),
            accepting(Listener, Kernel, Family, Pending);
        %% the listener's own end, or an error of it, ends the acceptor,
        %% which the host's `net_kernel` makes again while it listens, as it
        %% makes its own
        {error, _} = Error ->
            exit(Error)
    end.

%% The process a connection taken shakes hands in, given the socket, or
%% the connection closed where the table leaves no room for it.
opened(Socket, Kernel, Family, Pending) ->
    Acceptor = self(),
    try spawn_monitor(fun() -> given(Acceptor, Kernel, Family) end) of
        {Process, MonitorRef} ->
            _ = gen_tcp:controlling_process(Socket, Process),
            Process ! {given, Socket},
            Pending#{Process => MonitorRef}
    catch
        error:system_limit ->
            From = case inet:peername(Socket) of
                       {ok, Peer} -> [" from ", ern_node:listen_text(Peer)];
                       {error, _} -> []
                   end,
            _ = gen_tcp:close(Socket),
            ern_carrier:table_full(["a connection" | From]),
            Pending
    end.

%% Pending without each process that has handed its connection on or
%% ended, as far as the acceptor has heard (settled/1); and the same once
%% one has, where it holds as many as it may (settled_one/1).
settled(Pending) ->
    receive
        {handed, Process} -> settled(unpended(Process, Pending));
        {'DOWN', _, process, Process, _} -> settled(maps:remove(Process, Pending))
    after 0 ->
        Pending
    end.

settled_one(Pending) ->
    receive
        {handed, Process} -> unpended(Process, Pending);
        {'DOWN', _, process, Process, _} -> maps:remove(Process, Pending)
    end.

unpended(Process, Pending) ->
    case Pending of
        #{Process := MonitorRef} ->
            erlang:demonitor(MonitorRef, [flush]),
            maps:remove(Process, Pending);
        #{} ->
            Pending
    end.

%%
%% A connection's handshake
%%

%% Report §12.5: a connection's process, once the acceptor has given it the
%% socket: the TLS handshake within the host's time for a connection's
%% setup, by the host's options for a server, which check the peer by the
%% rule (ern_carrier:verify/3), then the connection handed to the host's
%% `net_kernel` for its own handshake. One that fails closes the
%% connection: the rule says why where it refused the peer, and the node
%% says so where the host's TLS found no room for its processes.
given(Acceptor, Kernel, Family) ->
    receive {given, Socket} -> ok end,
    case inet:peername(Socket) of
        {ok, {Address, _} = Peer} ->
            Options = inet_tls_dist:get_ssl_server_options(Address),
            case ssl:handshake(Socket, [{active, false}, {packet, 4} | Options],
                               net_kernel:connecttime()) of
                {ok, TlsSocket} ->
                    certified(Acceptor, Kernel, Family, TlsSocket);
                {error, Reason} ->
                    _ = gen_tcp:close(Socket),
                    no_room(Reason) andalso
                        ern_carrier:table_full(["a connection from ",
                                                ern_node:listen_text(Peer)])
            end;
        {error, _} ->
            gen_tcp:close(Socket)
    end.

%% Whether the host's TLS failed for want of room for its processes, which
%% it answers as a DTLS upgrade it does not support: the answer its
%% handshake gives where the start of a connection's processes fails, which
%% in a running carrier only a full table fails, the session's tracker
%% being none over TLS 1.3 (docs/otp_bugs.md, 15).
no_room({dtls_upgrade, notsup}) -> true;
no_room(_) -> false.

%% The connection handed to the host's `net_kernel`, the peer its
%% certificate names read first, as a line names it, for the line its
%% refusal would be said by; a connection that has closed since has no
%% certificate, and nothing to hand.
certified(Acceptor, Kernel, Family, TlsSocket) ->
    case ssl:peercert(TlsSocket) of
        {ok, Der} ->
            Kernel ! {accept, self(), TlsSocket, Family, ?PROTOCOL},
            handed(Acceptor, Kernel, TlsSocket, ern_carrier:certified(Der));
        {error, _} ->
            ssl:close(TlsSocket)
    end.

%% Report §12.5: the connection handed to the host's handshake, a process
%% `net_kernel` makes for it (accept_connection/5), or closed where the
%% full table leaves no room for that process, the node saying so by the
%% peer its certificate names.
handed(Acceptor, Kernel, TlsSocket, Peer) ->
    receive
        {Kernel, controller, Handshake} when is_pid(Handshake) ->
            MonitorRef = erlang:monitor(process, Handshake),
            case ssl:controlling_process(TlsSocket, Handshake) of
                ok ->
                    Handshake ! {self(), controller},
                    Acceptor ! {handed, self()},
                    watched(MonitorRef, Peer);
                {error, _} ->
                    erlang:demonitor(MonitorRef, [flush]),
                    Handshake ! {self(), exit}
            end;
        {Kernel, controller, limited} ->
            _ = ssl:close(TlsSocket),
            ern_carrier:table_full(Peer);
        {Kernel, unsupported_protocol} ->
            ssl:close(TlsSocket)
    end.

%% Report §12.5: the host's handshake, monitored before it is told to go,
%% which first makes its timer; where the full table leaves no room for it,
%% the handshake ends, the host's TLS closing the connection, and the node
%% says so. The wait is the host's time for a connection's setup, which the
%% timer ends the handshake by: after it the handshake has ended or lives
%% as the connection.
watched(MonitorRef, Peer) ->
    receive
        {'DOWN', MonitorRef, process, _, {system_limit, _}} -> ern_carrier:table_full(Peer);
        {'DOWN', MonitorRef, process, _, _} -> ok
    after net_kernel:connecttime() ->
        erlang:demonitor(MonitorRef, [flush])
    end.

%% Report §12.5: the host's handshake for a connection the acceptor took,
%% a process the host makes here, in its `net_kernel`, for the connection's
%% process, Connection; `limited` where the full table leaves no room for
%% it, which that process reads (handed/4).
-spec accept_connection(pid(), term(), node(), [node()], pos_integer()) -> pid() | limited.
accept_connection(Connection, TlsSocket, MyNode, Allowed, SetupTime) ->
    try inet_tls_dist:fam_accept_connection(family(), Connection, TlsSocket, MyNode, Allowed,
                                            SetupTime)
    catch
        error:system_limit -> limited
    end.
