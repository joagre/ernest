%% Report §12.5: a node's carrier, Erlang's own distribution over TLS with
%% what hurts in it turned off. The flags the host boots with, which the
%% launcher asks for before it starts the host (boot_flags/2); the node's
%% name on the carrier, a constant at its key's digest (name/1, host/1);
%% the floor's digest, which is the host's cookie (cookie/0); the rule
%% that accepts a peer by its listed key, under the name that key gives
%% and, on a dial, under the name dialed (verify/3, which the host's TLS
%% calls, and dialing/1, which the port map calls); the listener started
%% once the bindings have their values (start/2); a reload, which hangup
%% asks for (reload/0); the end in order, told to the peers (depart/0); and
%% the lines a node says of its peers, one each on its standard error.
-module(ern_carrier).

-export([boot_flags/1, name/1, host/1, cookie/0, cookie/2, start/1, list/1, booted/0,
         configuration/0, is_node/0, reload/0, depart/0, peer/1, verify/3, dialing/1, listed/1,
         names_own_host/1, say/1, say_later/1, named/1, said/1, filter/2]).

-include_lib("public_key/include/public_key.hrl").
-include("ern_node.hrl").

%% Report §12.5: the protocol's version, in the cookie, so that two nodes of
%% different protocols never connect: 4 since MVP 3.95, whose two frames
%% tell a restart to the nodes that monitor the restarting process and
%% answer that their watchers have been told (§6.9).
-define(PROTOCOL, 4).

%% The constant before the host of a node's name on the carrier, whose host
%% is its key's digest and names no network address: a peer's address is
%% the configuration's (ern_epmd).
-define(NAME, "ernest").

%% Report §8.7, §12.6, §7: the detector's time, a tick every quarter of it, and a
%% dial nothing answers given up after 7 seconds; what may wait to be sent
%% to a peer before a sender waits, in kilobytes; each the same on every
%% node, and none set in `ernest.conf`.
-define(TICK_TIME, "60").
-define(SETUP_TIME, "7").
-define(BUFFER, "1024").

%% Report §12.5: the key under which the process that dials a peer holds the
%% host it dials (dialing/1).
-define(DIALED, {?MODULE, dialed}).

%%
%% The host's boot
%%

%% Report §12.5: the flags a node's host boots with, since the host takes its
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

%% Report §12.5: the TLS options of one side: the node's own certificate as
%% the one the host trusts, so that a peer's is checked by the rule alone,
%% which is told the side it checks for.
tls(Side, Certificate, Key) ->
    [{"certfile", Certificate}, {"keyfile", Key}, {"cacertfile", Certificate},
     {"verify", "verify_peer"}, {"versions", "tlsv1.3"},
     {"verify_fun", "{ern_carrier,verify," ++ Side ++ "}"}]
        ++ [{"fail_if_no_peer_cert", "true"} || Side =:= "server"].

interface({{0, 0, 0, 0}, _}) -> [];
interface({{0, 0, 0, 0, 0, 0, 0, 0}, _}) -> [];
interface({Address, _}) ->
    ["-kernel", "inet_dist_use_interface", lists:flatten(io_lib:format("~w", [Address]))];
interface(none) -> [].

%% Report §12.5: a node's name on the carrier, a constant at the host its
%% public key gives, holding no network address.
-spec name(binary()) -> atom().
name(PublicKey) ->
    list_to_atom(?NAME ++ "@" ++ host(PublicKey)).

%% Report §12.5: the host a public key gives, the SHA-256 digest of the key
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

%% Report §12.5: the cookie, the digest of the floor this build of `ern`
%% stands on (cookie/2), which ern_release gives, taken as the node's host
%% first starts (boot_flags/1).
-spec cookie() -> string().
cookie() ->
    cookie(ern_release:release(), fun code_digest/0).

%% Report §12.5, Appendix H: the cookie of a build that stands on Release:
%% for a release, the digest of the protocol's version, the form's version,
%% `ern`'s major and minor, which stand for the runtime's functions and the
%% standard library, a patch adding nothing, and OTP's major release, within
%% which the host keeps its term format, its distribution and its compiled
%% modules; for a build that is no release, development, the digest of its
%% own code, which CodeDigest gives. Nothing of a program's build is in it,
%% so that nodes of different builds connect, and the hashes tell what they
%% share.
-spec cookie(development | {non_neg_integer(), non_neg_integer(), non_neg_integer()},
             fun(() -> binary())) -> string().
cookie(Release, CodeDigest) ->
    Floor = case Release of
                development ->
                    CodeDigest();
                {Major, Minor, _Patch} ->
                    {?PROTOCOL, ern_canonical:form_version(), Major, Minor,
                     erlang:system_info(otp_release)}
            end,
    binary_to_list(binary:encode_hex(crypto:hash(sha256, term_to_binary(Floor, [deterministic])),
                                     lowercase)).

%% Report §12.5: the digest of a development build's own code: each module
%% of the toolchain's, its applications', the standard library's, the
%% shell's and the two libraries the shell is compiled against, every
%% module compiled from an application's tests aside, by the digest of its
%% code, which the host's module_info(md5) answers too, in the order of
%% their names. Read from the files, loading none of them, at a node's
%% first start, which alone asks.
code_digest() ->
    Applications = [File || File <- filelib:wildcard(filename:join(ern_tree:tree(),
                                                                   "erl/*/ebin/*.beam")),
                            not is_test(File)],
    Built = lists:append([filelib:wildcard(filename:join(ern_tree:build(Build), Pattern))
                          || {Build, Pattern} <- [{"stdlib", "*.erc"}, {"shell", "**/*.erc"},
                                                  {"libs/ansi", "*.erc"},
                                                  {"libs/markdown", "*.erc"}]]),
    %% read first: beam_lib adds `.beam` to a file's name that lacks it
    Digests = lists:sort([Digest || File <- Applications ++ Built,
                                    {ok, Beam} <- [file:read_file(File)],
                                    {ok, Digest} <- [beam_lib:md5(Beam)]]),
    crypto:hash(sha256, term_to_binary(Digests, [deterministic])).

%% Whether a module was compiled from its application's test/ directory,
%% a test or a test's helper, which app.mk compiles into the application's
%% ebin/ beside its own.
is_test(File) ->
    Application = filename:dirname(filename:dirname(File)),
    filelib:is_regular(filename:join([Application, "test", filename:basename(File, ".beam")
                                                           ++ ".erl"])).

%%
%% The node's start
%%

%% Report §8.7, §12.5: the carrier started once the bindings have their values,
%% in the entry process, the node's peers listed (list/1): the host's own
%% reports of its nodes turned off, the gateway, which watches the node's
%% connections, and the host's distribution under the node's name,
%% listening where `listen` names an interface, its listed peers' names
%% allowed (allow/1). A carrier that cannot start ends the node as an
%% initializer that faults ends a program (§8.5), the cause saying why
%% (not_started/2).
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
            ern_rt:fault(iolist_to_binary(["the node's carrier did not start: ",
                                           not_started(Listen, Reason)]))
    end.

%% Report §12.3: why the carrier did not start: its listen address in use,
%% which the host's reason does not name, the host saying it only in a
%% report of its own (filter/2), and which a listen on the address, made
%% once the host has failed, finds, so that a start that succeeds pays
%% nothing for it; else the host's reason, as the host writes it. A port
%% the host picks is never in use.
not_started({Address, Port} = Listen, Reason) when Port =/= 0 ->
    case gen_tcp:listen(Port, [ern_node:family(Listen), {ip, Address}, {reuseaddr, true}]) of
        {error, eaddrinuse} ->
            ["its listen address ", listen_text(Listen), " is in use"];
        {ok, Socket} ->
            ok = gen_tcp:close(Socket),
            io_lib:format("~0p", [Reason]);
        {error, _} ->
            io_lib:format("~0p", [Reason])
    end;
not_started(_, Reason) ->
    io_lib:format("~0p", [Reason]).

%% Report §12.5: a listen address as `listen` writes it, an IPv6 address in
%% brackets.
listen_text({{_, _, _, _} = Address, Port}) ->
    [inet:ntoa(Address), ":", integer_to_list(Port)];
listen_text({Address, Port}) ->
    ["[", inet:ntoa(Address), "]:", integer_to_list(Port)].

%% Report §12.5: the configuration the node runs by, and its peer table,
%% which the rule, the port map and the lines read, each peer by the host
%% its key gives, listed as the node starts, before its initializers run.
-spec list(#configuration{}) -> ok.
list(#configuration{peers = Peers, services = Services} = Configuration) ->
    persistent_term:put({?MODULE, configuration}, Configuration),
    persistent_term:put({?MODULE, peers},
                        maps:from_list([{host(Key), Peer}
                                        || #peer{public_key = Key} = Peer <- Peers])),
    ern_peer:configure([{Name, name(Key)} || #peer{name = Name, public_key = Key} <- Peers],
                       Services).

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

%% Report §12.5: hangup is a reload: `ernest.conf` read and checked again as
%% at the start, the node's own key and `listen` unchanged, or the file
%% refused and the configuration kept; then the names the host allows gain
%% the new peers', the peer table the rule and the dial read, the services,
%% the measures, the utilization and its interval are the new file's, the
%% utilization holding from the next ask and the interval from the next
%% telling (ern_gateway:reloaded/0), and a peer removed, or listed under
%% another key, has its connection ended, both nodes running the loss.
%%
%% The node says that it read the file, and each peer added, removed or
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
        Lines -> lists:foreach(fun say_later/1, ["ernest.conf was read again" | Lines])
    catch
        throw:{cli_error, Refusal} -> refuse(Refusal);
        throw:{ern, fault, Cause} -> refuse(Cause);
        _:Reason -> refuse(io_lib:format("~0tp", [Reason]))
    end.

refuse(Refusal) ->
    say_later(["the reload was refused, and the configuration stays as it was: ", Refusal]).

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
    ok = ern_gateway:reloaded(),
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

%% Report §8.7, §12.6: a node stops in order, so that every Down already on its
%% way crosses before its connections close, and tells each peer still
%% connected that it ends, which the peer's gateway reads before the
%% connection's end: the runtime's end has waited for the deaths its peers
%% may watch, the frame goes after their Downs on the connection, and the
%% host's own question, whether the peer is there, after the frame, so that
%% its answer comes once they have arrived; a peer that fell silent is given
%% up by the detector, which answers it, and one lost while another was
%% waited for has ended with its loss, so the question is not put to it,
%% which would dial. The gateway tells no peer how busy
%% the node is once the frame has gone (ern_gateway:departing/0), since a
%% peer takes a telling after it for a node that goes on.
-spec depart() -> ok.
depart() ->
    ok = ern_gateway:departing(),
    lists:foreach(fun(Node) ->
                      erlang:send({ern_gateway, Node}, {ern_frame, self(), node_ends}),
                      _ = lists:member(Node, nodes(connected)) andalso net_adm:ping(Node)
                  end, nodes(connected)).

%% Report §12.5: the host takes a peer's connection only under a name it
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

%% Report §12.5: the rule that accepts a peer whose public key this node
%% lists, and no other, and only under the name that key gives: its
%% certificate names the host its key gives, and no other, which the host
%% binds to the name the peer gives in the handshake (allow/1). A
%% certificate's dates mean nothing to it, and its issuer is itself, so the
%% host's checks of them, which come as a bad certificate, are answered by
%% the key; an extension is the host's. A key not listed, and a
%% certificate that names another host than its key gives, are refused, and
%% the node says so.
%%
%% A node this node dials must answer under the name dialed: the host's
%% handshake checks only the name the answering node gives, which a node
%% may give falsely, and checks no dialed name against a certificate that
%% signs itself, so on the client's side the rule takes a key only where it
%% gives the host dialed (dialed/0), and the node says which peer answered
%% the dial of which.
-spec verify(#'OTPCertificate'{}, term(), client | server) ->
          {valid, client | server} | {unknown, client | server} | {fail, term()}.
verify(_Certificate, {extension, _}, Side) ->
    {unknown, Side};
verify(_Certificate, valid, Side) ->
    {valid, Side};
verify(Certificate, _Event, Side) ->
    case {listed(Certificate), names_own_host(Certificate)} of
        {{listed, Peer}, true} ->
            answered(Side, Peer);
        {{listed, #peer{name = Name}}, false} ->
            say_later(["the peer ", Name, " was refused: its certificate names another host"
                                          " than its key gives"]),
            {fail, other_host};
        {{unlisted, Digest}, _} ->
            say_later(["a node with the key ", Digest, " was refused: no peer has its key"]),
            {fail, not_listed}
    end.

%% A listed key whose certificate names its own host: taken on the server's
%% side, and on the client's where it gives the host dialed; refused, the
%% node saying why, where it gives another, or where the dial it answers is
%% not known, which fails the dial with no failure of the host's.
answered(server, #peer{public_key = Key}) ->
    ok = allow([Key]),
    {valid, server};
answered(client, #peer{name = Name, public_key = Key}) ->
    Host = host(Key),
    case dialed() of
        {dialed, Host} ->
            ok = allow([Key]),
            {valid, client};
        {dialed, Dialed} ->
            say_later(["the peer ", Name, " was refused: it answered the dial of ",
                       host_named(Dialed)]),
            {fail, not_dialed};
        unknown ->
            say_later(["the peer ", Name, " was refused: the dial it answered is not known"]),
            {fail, not_dialed}
    end.

%% Report §12.5: the host the process that dials a peer dials, recorded in
%% its dictionary as the port map answers the peer's address
%% (ern_epmd:address_please/3), where it stays for the connection's life,
%% the process's: so that the rule binds the certificate that answers the
%% dial to the host dialed (dialed/0).
-spec dialing(string()) -> ok.
dialing(Host) ->
    _ = put(?DIALED, Host),
    ok.

%% The host dialed for the connection whose certificate the rule checks on
%% the client's side, or unknown where no process, or more than one, holds
%% one. The host's TLS gives the check nothing of its connection but the
%% certificate, and runs it in the connection's own process, which monitors
%% the process that dialed, its user, the one process it monitors that
%% holds a host dialed (dialing/1). That monitor is ssl's own and
%% undocumented, read from OTP 29's ssl 11.7, its connection's
%% `user_application` monitor (ssl_gen_statem), where the host's
%% distribution dials and connects in one process (inet_tls_dist's
%% do_setup/7); a release that drops it leaves every dial unknown, and so
%% refused, saying so.
dialed() ->
    {monitors, Monitored} = process_info(self(), monitors),
    case [Host || {process, Pid} <- Monitored, is_pid(Pid),
                  {_, Host} <- [process_info(Pid, {dictionary, ?DIALED})],
                  Host =/= undefined] of
        [Host] -> {dialed, Host};
        _ -> unknown
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

%% Report §12.5: whether a certificate names the host its own key gives, and
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

%% Report §12.5: a line on the node's standard error, through standard
%% error's process as a fault's line goes, and written as `ern run` writes
%% one, its time first where standard error is neither a terminal nor a
%% journal (§11.2), from the node's start, a reload during its initializers
%% among it; where no launch is in progress, before a node's first, between
%% two launches of `ern test` over a directory and after its last, on the
%% job's own standard error (ern_rt:say/2).
-spec say(iodata()) -> ok.
say(Text) ->
    ern_rt:say(line(Text), fun ern_cli:error_line/1).

%% Report §12.5: a line on the node's standard error as say/1 writes it, said
%% for a process that must not wait for standard error to take it: the
%% gateway and its workers, which route every frame, the check of a
%% certificate, inside the host's TLS, the port map's dial and the host's
%% log filter, inside its distribution, and a reload, in the host's signal
%% handler (ern_rt:say_later/2). Its time is the moment it was said.
-spec say_later(iodata()) -> ok.
say_later(Text) ->
    ern_rt:say_later(line(Text), fun ern_cli:error_line/1).

line(Text) ->
    iolist_to_binary([ern_cli:stamp(ern_cli:is_stamped()), Text, "\n"]).

%% A peer as a line names it: by its name in `ernest.conf`, or by its key's
%% digest where it is not listed.
-spec named(atom()) -> iodata().
named(Node) ->
    host_named(lists:last(string:split(atom_to_list(Node), "@"))).

%% A peer as a line names it by the host of its name on the carrier; one
%% not listed by that name as the node gave it, which may be any text where
%% its handshake was refused, its control characters escaped (§11.2).
host_named(Host) ->
    case peer(Host) of
        #peer{name = Name} -> ["the peer ", Name];
        none -> ["the node ", controls([Char || Char <- Host, Char =/= $.])]
    end.

%% Report §12.5: the line a change of a connection is said by, which the
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

%% Report §12.5: the host's own reports of its nodes are turned off, but the
%% handshake's refusal of a peer for its floor, by the cookie, and of a
%% name its key does not give, which the node says in its own words. Its
%% reports of a distribution that could not start, the crash of
%% `net_kernel` and the start error of `net_sup`, are among them: the
%% carrier's fault says it (§12.3).
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
    say_later(["a node named ", controls(io_lib:format("~ts", [Node])),
               " was refused: its key gives another name"]),
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
            say_later([named(Node), " was refused: it stands on another floor, another release"
                                     " or build of ern or another major release of OTP"]),
            stop;
        _ ->
            stop
    end;
host_message(_, _) ->
    ignore.

%% Report §12.5, §11.2: a name a node gave in its handshake, which a line
%% writes with each control character escaped, as a cause's are.
controls(Name) ->
    ern_show:controls(unicode:characters_to_binary(Name), line).
