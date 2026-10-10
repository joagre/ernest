%% Report §8.7: a node's carrier, Erlang's own distribution over TLS with
%% what hurts in it turned off. The flags the host boots with, which the
%% launcher asks for before it starts the host (boot_flags/2); the node's
%% name on the carrier, a constant at its key's digest (name/1, host/1);
%% the floor's digest, which is the host's cookie (cookie/0); the
%% rule that accepts a peer by its listed key, under the name that key gives
%% (verify/3, which the host's TLS calls); the listener started once the
%% bindings have their values (start/2); a reload, which hangup asks for
%% (reload/0); the end in order, told to the peers (depart/0); and the
%% lines a node says of its peers, one each on its standard error.
-module(ern_carrier).

-export([boot_flags/1, name/1, host/1, cookie/0, start/1, list/1, booted/0,
         configuration/0, is_node/0, reload/0, depart/0, peer/1, verify/3, listed/1,
         names_own_host/1, say/1, named/1, said/1, filter/2]).

-include_lib("public_key/include/public_key.hrl").
-include("ern_node.hrl").

%% Report §8.7: the protocol's version, in the cookie, so that two nodes of
%% different protocols never connect: 2 since MVP 3.1, whose key and spawn
%% frames name a type and a function by hash.
-define(PROTOCOL, 2).

%% The constant before the host of a node's name on the carrier, whose host
%% is its key's digest and names no network address: a peer's address is
%% the configuration's (ern_epmd).
-define(NAME, "ernest").

%% Report §8.7, §7: the detector's time, a tick every quarter of it, and a
%% dial nothing answers given up after 7 seconds; what may wait to be sent
%% to a peer before a sender waits, in kilobytes; each the same on every
%% node, and none set in `ernest.conf`.
-define(TICK_TIME, "60").
-define(SETUP_TIME, "7").
-define(BUFFER, "1024").

%%
%% The host's boot
%%

%% Report §8.7: the flags a node's host boots with, since the host takes its
%% carrier only as it boots: TLS 1.3 with the node's certificate and key on
%% each side and the rule as the verification, over the listener's family
%% of addresses; no port-mapper daemon, a module of the runtime's answering
%% from the configuration in its place; no mesh; the detector's times and
%% the buffer; and the floor's digest as the cookie. The listener's
%% interface, where it is one, is the kernel's to bind.
-spec boot_flags(#configuration{}) -> [string()].
boot_flags(#configuration{config_dir = ConfigDir, listen = Listen}) ->
    Certificate = ern_node:file(filename:absname(ConfigDir), certificate),
    Key = ern_node:file(filename:absname(ConfigDir), key),
    Proto = case ern_node:family(Listen) of
                inet -> "inet_tls";
                inet6 -> "inet6_tls"
            end,
    Tls = lists:append([[Side ++ "_" ++ Name, Value]
                        || Side <- ["server", "client"],
                           {Name, Value} <- tls(Side, Certificate, Key)]),
    ["-proto_dist", Proto, "-ssl_dist_opt" | Tls]
        ++ ["-epmd_module", "ern_epmd", "-start_epmd", "false", "-connect_all", "false",
            "-kernel", "net_ticktime", ?TICK_TIME, "-kernel", "net_setuptime", ?SETUP_TIME,
            "+zdbbl", ?BUFFER, "-setcookie", cookie()]
        ++ interface(Listen).

%% Report §8.7: the TLS options of one side: the node's own certificate as
%% the one the host trusts, so that a peer's is checked by the rule alone.
tls(Side, Certificate, Key) ->
    [{"certfile", Certificate}, {"keyfile", Key}, {"cacertfile", Certificate},
     {"verify", "verify_peer"}, {"versions", "tlsv1.3"},
     {"verify_fun", "{ern_carrier,verify,[]}"}]
        ++ [{"fail_if_no_peer_cert", "true"} || Side =:= "server"].

interface({{0, 0, 0, 0}, _}) -> [];
interface({{0, 0, 0, 0, 0, 0, 0, 0}, _}) -> [];
interface({Address, _}) ->
    ["-kernel", "inet_dist_use_interface", lists:flatten(io_lib:format("~w", [Address]))];
interface(none) -> [].

%% Report §8.7: a node's name on the carrier, a constant at the host its
%% public key gives, holding no network address.
-spec name(binary()) -> atom().
name(PublicKey) ->
    list_to_atom(?NAME ++ "@" ++ host(PublicKey)).

%% Report §8.7: the host a public key gives, the SHA-256 digest of the key
%% as two labels of 32 hexadecimal digits, since a label of a host's name
%% holds at most 63 characters (RFC 1035). Its certificate names it, the
%% dialler's TLS sends it as the server's name (SNI), and the host's check
%% of a certificate's name takes it as a DNS name.
-spec host(binary()) -> string().
host(PublicKey) ->
    {First, Second} = lists:split(32, digest(PublicKey)),
    First ++ "." ++ Second.

digest(PublicKey) ->
    binary_to_list(binary:encode_hex(crypto:hash(sha256, PublicKey), lowercase)).

%% Report §8.7: the cookie, the digest of the floor two nodes stand on:
%% the protocol's version, `ern`'s version, which stands for the runtime's
%% functions and the standard library, and OTP's major release, within
%% which the host keeps its term format, its distribution and its compiled
%% modules. Nothing of the build is in it, so that nodes of different
%% builds connect, and the hashes tell what they share.
-spec cookie() -> string().
cookie() ->
    Floor = {?PROTOCOL, ?VERSION, erlang:system_info(otp_release)},
    binary_to_list(binary:encode_hex(crypto:hash(sha256, term_to_binary(Floor, [deterministic])),
                                     lowercase)).

%%
%% The node's start
%%

%% Report §8.7: the carrier started once the bindings have their values,
%% in the entry process, the node's peers listed (list/1): the host's own
%% reports of its nodes turned off, the gateway, which watches the node's
%% connections, and the host's distribution under the node's name,
%% listening where `listen` names an interface, its listed peers' names
%% allowed (allow/1). A carrier that cannot start, its port taken among the
%% reasons, ends the node as an initializer that faults ends a program
%% (§8.5), the cause naming the host's reason.
-spec start(#configuration{}) -> ok.
start(_Configuration) when node() =/= nonode@nohost ->
    %% report §11.2: `ern test` over a directory runs each module in a
    %% runtime of its own, in one host, which is one node
    ok;
start(#configuration{public_key = PublicKey, listen = Listen}) ->
    ok = logger:add_primary_filter(?MODULE, {fun ?MODULE:filter/2, []}),
    ok = ern_gateway:start(),
    case net_kernel:start(name(PublicKey), #{name_domain => longnames,
                                             dist_listen => Listen =/= none}) of
        {ok, _} ->
            allow([Key || #peer{public_key = Key} <- (configuration())#configuration.peers]);
        {error, Reason} ->
            ern_rt:fault(iolist_to_binary(io_lib:format("the node's carrier did not start: ~0p",
                                                        [Reason])))
    end.

%% Report §8.7: the configuration the node runs by, and its peer table,
%% which the rule, the port map and the lines read, each peer by the host
%% its key gives, listed as the node starts, before its initializers run.
-spec list(#configuration{}) -> ok.
list(#configuration{peers = Peers, keys = Keys} = Configuration) ->
    persistent_term:put({?MODULE, configuration}, Configuration),
    persistent_term:put({?MODULE, peers},
                        maps:from_list([{host(Key), Peer}
                                        || #peer{public_key = Key} = Peer <- Peers])),
    ern_peer:configure([{Name, name(Key)} || #peer{name = Name, public_key = Key} <- Peers],
                       Keys).

%% Whether the host was booted with the carrier's flags (boot_flags/2),
%% which a node needs; a host booted otherwise cannot carry one.
-spec booted() -> boolean().
booted() ->
    init:get_argument(proto_dist) =/= error.

%% The configuration the node runs by.
-spec configuration() -> #configuration{}.
configuration() ->
    persistent_term:get({?MODULE, configuration}).

%% Report §8.3: whether this run is a node, which its configuration says.
-spec is_node() -> boolean().
is_node() ->
    persistent_term:get({?MODULE, configuration}, none) =/= none.

%%
%% The node's reload and end
%%

%% Report §8.7: hangup is a reload: `ernest.conf` read and checked again as
%% at the start, the node's own key and `listen` unchanged, or the file
%% refused and the configuration kept; then the names the host allows gain
%% the new peers', the peer table the rule and the dial read, the keys and
%% the measures are the new file's, and a peer removed, or listed under
%% another key, has its connection ended, both nodes running the loss. The
%% node says that it read the file, and each peer added, removed or
%% renamed, or why the file was refused. Whatever fails as the file is read
%% and checked refuses the reload, the host's reason named where it is not
%% a refusal, so that the signal handler, in whose process this runs, never
%% fails and the node takes every later signal; the measures, the one
%% change made before the checks end, are restored where theirs fails
%% (ern_node:measures_changed/3).
-spec reload() -> ok.
reload() ->
    #configuration{config_dir = ConfigDir} = Running = configuration(),
    try changed(Running, ern_node:read(ConfigDir)) of
        Lines -> lists:foreach(fun say/1, ["ernest.conf was read again" | Lines])
    catch
        throw:{cli_error, Refusal} -> refuse(Refusal);
        throw:{ern, fault, Cause} -> refuse(Cause);
        _:Reason -> refuse(io_lib:format("~0tp", [Reason]))
    end.

refuse(Refusal) ->
    say(["the reload was refused, and the configuration stays as it was: ", Refusal]).

changed(#configuration{config_dir = ConfigDir, public_key = Key, listen = Listen, peers = Peers,
                       measures = Measures},
        #configuration{public_key = NewKey, listen = NewListen, peers = NewPeers,
                       measures = NewMeasures} = New) ->
    Conf = ern_build:shown(ern_node:file(ConfigDir, conf)),
    NewKey =:= Key orelse ern_build:fail(Conf ++ ": public-key cannot change while the node runs"),
    NewListen =:= Listen
        orelse ern_build:fail(Conf ++ ": listen cannot change while the node runs"),
    ern_node:measures_changed(ConfigDir, Measures, NewMeasures),
    ok = allow([Added || #peer{public_key = Added} <- NewPeers]),
    ok = list(New),
    Removed = [Peer || #peer{public_key = Old} = Peer <- Peers,
                       not lists:keymember(Old, #peer.public_key, NewPeers)],
    lists:foreach(fun(#peer{public_key = Old}) -> erlang:disconnect_node(name(Old)) end, Removed),
    [["the peer ", Name, " was added"]
     || #peer{name = Name, public_key = Added} <- NewPeers,
        not lists:keymember(Added, #peer.public_key, Peers)]
        ++ [["the peer ", Name, " was removed"] || #peer{name = Name} <- Removed]
        ++ [["the peer ", Name, " is now named ", NewName]
            || #peer{name = Name, public_key = Same} <- Peers,
               #peer{name = NewName, public_key = Same2} <- NewPeers,
               Same =:= Same2, Name =/= NewName].

%% Report §8.7: a node stops in order, so that every Down already on its
%% way crosses before its connections close, and tells each peer still
%% connected that it ends, which the peer's gateway reads before the
%% connection's end: the runtime's end has waited for the deaths its peers
%% may watch, the frame goes after their Downs on the connection, and the
%% host's own question, whether the peer is there, after the frame, so that
%% its answer comes once they have arrived; a peer that fell silent is given
%% up by the detector, which answers it.
-spec depart() -> ok.
depart() ->
    lists:foreach(fun(Node) ->
                      erlang:send({ern_gateway, Node}, {ern_frame, self(), node_ends}),
                      _ = net_adm:ping(Node)
                  end, nodes(connected)).

%% Report §8.7: the host takes a peer's connection only under a name it
%% allows whose host the peer's certificate names (inet_tls_dist), and
%% dials only a name it allows; the node allows each listed peer's name at
%% its start and at each reload, and the rule a key's before it accepts the
%% key, so that a connection that comes as the node starts is bound to its
%% key too. The host only adds to the names it allows, and allows them only
%% once the node is one: a peer removed is refused by the rule.
allow(Keys) ->
    _ = net_kernel:allow([name(Key) || Key <- Keys]),
    ok.

%% The peer listed with the key that gives a host of a name on the carrier,
%% or none where no peer is.
-spec peer(string()) -> #peer{} | none.
peer(Host) ->
    maps:get(Host, persistent_term:get({?MODULE, peers}, #{}), none).

%%
%% The rule
%%

%% Report §8.7: the rule that accepts a peer whose public key this node
%% lists, and no other, and only under the name that key gives: its
%% certificate names the host its key gives, and no other, which the host
%% binds to the name the peer gives in the handshake (allow/1). A
%% certificate's dates mean nothing to it, and its issuer is itself, so the
%% host's checks of them, which come as a bad certificate, are answered by
%% the key; an extension is the host's. A key not listed, and a
%% certificate that names another host than its key gives, are refused, and
%% the node says so. A node this node dials answers under the name dialled,
%% which the host's handshake checks (dist_util).
-spec verify(#'OTPCertificate'{}, term(), term()) ->
          {valid, term()} | {unknown, term()} | {fail, term()}.
verify(_Certificate, {extension, _}, State) ->
    {unknown, State};
verify(_Certificate, valid, State) ->
    {valid, State};
verify(Certificate, _Event, State) ->
    case {listed(Certificate), names_own_host(Certificate)} of
        {{listed, #peer{public_key = Key}}, true} ->
            ok = allow([Key]),
            {valid, State};
        {{listed, #peer{name = Name}}, false} ->
            say(["the peer ", Name, " was refused: its certificate names another host than its"
                                    " key gives"]),
            {fail, other_host};
        {{unlisted, Digest}, _} ->
            say(["a node with the key ", Digest, " was refused: no peer has its key"]),
            {fail, not_listed}
    end.

%% The peer a certificate's key is listed for, or the key's digest where it
%% is listed for none.
-spec listed(#'OTPCertificate'{}) -> {listed, #peer{}} | {unlisted, string()}.
listed(Certificate) ->
    Key = certificate_key(Certificate),
    case peer(host(Key)) of
        #peer{} = Peer -> {listed, Peer};
        none -> {unlisted, digest(Key)}
    end.

%% Report §8.7: whether a certificate names the host its own key gives, and
%% no other, as the one DNS name of its subject's alternative names, which
%% `ern config` writes.
-spec names_own_host(#'OTPCertificate'{}) -> boolean().
names_own_host(#'OTPCertificate'{tbsCertificate = Tbs} = Certificate) ->
    Extensions = case Tbs#'OTPTBSCertificate'.extensions of
                     Listed when is_list(Listed) -> Listed;
                     asn1_NOVALUE -> []
                 end,
    Hosts = case lists:keyfind(?'id-ce-subjectAltName', #'Extension'.extnID, Extensions) of
                #'Extension'{extnValue = Names} -> [Host || {dNSName, Host} <- Names];
                false -> []
            end,
    Hosts =:= [host(certificate_key(Certificate))].

%% The DER of a certificate's SubjectPublicKeyInfo, as the certificate holds
%% it.
certificate_key(Certificate) ->
    Der = public_key:pkix_encode('OTPCertificate', Certificate, otp),
    #'Certificate'{tbsCertificate = Tbs} = public_key:pkix_decode_cert(Der, plain),
    public_key:der_encode('SubjectPublicKeyInfo', Tbs#'TBSCertificate'.subjectPublicKeyInfo).

%%
%% What a node says
%%

%% Report §8.7: a line on the node's standard error, through standard
%% error's process as a fault's line goes, and written as `ern run` writes
%% one, its time first where standard error is neither a terminal nor a
%% journal (§11.2), from the node's start, a reload during its initializers
%% among it.
-spec say(iodata()) -> ok.
say(Text) ->
    ern_rt:send(ern_rt:system_process(stderr),
                iolist_to_binary([ern_cli:stamp(ern_cli:is_stamped()), Text, "\n"])),
    ok.

%% A peer as a line names it: by its name in `ernest.conf`, or by its key's
%% digest where it is not listed.
-spec named(atom()) -> iodata().
named(Node) ->
    Host = lists:last(string:split(atom_to_list(Node), "@")),
    case peer(Host) of
        #peer{name = Name} -> ["the peer ", Name];
        none -> ["the node ", [Char || Char <- Host, Char =/= $.]]
    end.

%% Report §8.7: the line a change of a connection is said by, which the
%% gateway watches, or none: a peer connected; a peer ended, whose
%% connection closed after the peer told this node it ends; a peer lost,
%% and whether it fell silent, which the detector found, or closed; and a
%% living connection replaced by another from the same node, which the host
%% ends with the reason `wait_pending`. The node's own start comes as a
%% connection too, and is none.
-spec said(term()) -> iodata() | none.
said({nodeup, Node, _}) when Node =:= node() ->
    none;
said({nodeup, Node, _}) ->
    [named(Node), " connected"];
said({ended, Node}) ->
    [named(Node), " ended"];
said({nodedown, Node, Info}) ->
    case proplists:get_value(nodedown_reason, Info) of
        net_tick_timeout -> [named(Node), " was lost: it fell silent"];
        wait_pending -> [named(Node), "'s connection was replaced by another from the same node"];
        _ -> [named(Node), " was lost: it closed"]
    end;
said(_) ->
    none.

%% Report §8.7: the host's own reports of its nodes are turned off, but the
%% handshake's refusal of a peer for its floor, by the cookie, and of a
%% name its key does not give, which the node says in its own words. Its
%% reports of a distribution that could not start, the crash of
%% `net_kernel` and the start error of `net_sup`, are among them: the
%% carrier's fault says it (§7.4).
-spec filter(logger:log_event(), term()) -> logger:filter_return().
filter(#{msg := {report, #{label := {error_logger, _}, format := Format, args := Args}}}, _) ->
    host_message(Format, Args);
filter(#{msg := {report, #{label := {proc_lib, crash}, report := [Crash | _]}}}, _) ->
    case proplists:get_value(initial_call, Crash) of
        {net_kernel, init, _} -> stop;
        _ -> ignore
    end;
filter(#{msg := {report, #{label := {supervisor, _}, report := Report}}}, _) ->
    case proplists:get_value(supervisor, Report) of
        {local, net_sup} -> stop;
        _ -> ignore
    end;
filter(#{msg := {Format, Args}}, _) when is_list(Format), is_list(Args) ->
    host_message(Format, Args);
filter(#{meta := #{domain := [otp, ssl | _]}}, _) ->
    stop;
filter(_Event, _) ->
    ignore.

%% A message of the host's of its nodes: the handshake's refusal for the
%% cookie, and for a name the host does not allow under the key that came,
%% said in the node's words, and every other dropped; any other message
%% left to the handlers.
host_message("** Connection attempt from disallowed node ~s" ++ _, [Node]) ->
    say(["a node named ", io_lib:format("~ts", [Node]), " was refused: its key gives another"
                                                        " name"]),
    stop;
host_message(Format, Args) when is_list(Format) ->
    case {string:find(Format, "Invalid challenge"), Args} of
        {nomatch, _} ->
            case lists:any(fun(Prefix) -> string:prefix(Format, Prefix) =/= nomatch end,
                           ["** Connection attempt", "** Node ", "** Distribution",
                            "~n** Cannot get", "** Netkernel", "Net kernel got"]) of
                true -> stop;
                false -> ignore
            end;
        {_, [Node]} when is_atom(Node) ->
            say([named(Node), " was refused: it stands on another floor, another release of"
                               " ern or another major release of OTP"]),
            stop;
        _ ->
            stop
    end;
host_message(_, _) ->
    ignore.
