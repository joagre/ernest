%% Report §8.7: a node's carrier, Erlang's own distribution over TLS with
%% what hurts in it turned off. The flags the host boots with, which the
%% launcher asks for before it starts the host (boot_flags/2); the node's
%% name on the carrier, its key's digest with a constant (name/1); the
%% build's fingerprint, which is the host's cookie (fingerprint/1); the
%% rule that accepts a peer by its listed key alone (verify/3, which the
%% host's TLS calls); the listener started once the bindings have their
%% values (start/2); and the lines a node says of its peers, one each on its
%% standard error.
-module(ern_carrier).

-export([boot_flags/2, name/1, fingerprint/1, start/2, list/1, booted/0, configuration/0,
         peer/1, verify/3, listed/1, say/1, named/1, said/1, filter/2]).

-include_lib("public_key/include/public_key.hrl").
-include("ern_node.hrl").

%% Report §8.7: the protocol's version, in the cookie, so that two nodes of
%% different protocols never connect.
-define(PROTOCOL, 1).

%% The constant after a node's digest on the carrier, which names no network
%% address: a peer's address is the configuration's (ern_epmd).
-define(HOST, "node.ernest").

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
%% the buffer; and the build's fingerprint as the cookie. The listener's
%% interface, where it is one, is the kernel's to bind.
-spec boot_flags(#configuration{}, [file:filename()]) -> [string()].
boot_flags(#configuration{dir = ConfigDir, listen = Listen}, LoadPath) ->
    Dir = filename:absname(ConfigDir),
    Certificate = filename:join(Dir, "certificate.pem"),
    Key = filename:join(Dir, "private-key.pem"),
    Proto = case family(Listen) of
                inet -> "inet_tls";
                inet6 -> "inet6_tls"
            end,
    Tls = lists:append([[Side ++ "_" ++ Name, Value]
                        || Side <- ["server", "client"],
                           {Name, Value} <- tls(Side, Certificate, Key)]),
    ["-proto_dist", Proto, "-ssl_dist_opt" | Tls]
        ++ ["-epmd_module", "ern_epmd", "-start_epmd", "false", "-connect_all", "false",
            "-kernel", "net_ticktime", ?TICK_TIME, "-kernel", "net_setuptime", ?SETUP_TIME,
            "+zdbbl", ?BUFFER, "-setcookie", fingerprint(LoadPath)]
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

family(none) -> inet;
family({Address, _}) when tuple_size(Address) =:= 4 -> inet;
family({_, _}) -> inet6.

%% Report §8.7: a node's name on the carrier, the SHA-256 digest of its
%% public key with a constant after it, holding no network address.
-spec name(binary()) -> atom().
name(PublicKey) ->
    list_to_atom(digest(PublicKey) ++ "@" ++ ?HOST).

digest(PublicKey) ->
    binary_to_list(binary:encode_hex(crypto:hash(sha256, PublicKey), lowercase)).

%% Report §8.7: the build's fingerprint, the digest of the protocol's
%% version, `ern`'s version, the host's version, and every compiled module
%% on the load path in name order, a host module a `foreign fn` loads from
%% one of its directories among them (§11.2), each as its name and the
%% host's digest of its code, which leaves out documentation, line numbers
%% and attributes; the standard library is not among them, `ern`'s version
%% standing for it.
-spec fingerprint([file:filename()]) -> string().
fingerprint(LoadPath) ->
    Files = lists:append([ern_build:compiled_under(Root)
                          ++ filelib:wildcard(filename:join(Root, "*.beam"))
                          || Root <- LoadPath]),
    Modules = lists:usort([module_digest(File) || File <- Files]),
    Build = {?PROTOCOL, ?VERSION, otp_version(), Modules},
    binary_to_list(binary:encode_hex(crypto:hash(sha256, term_to_binary(Build, [deterministic])),
                                     lowercase)).

%% A compiled module's name and the host's digest of its code, read from its
%% bytes, since the host takes a name not ending in `.beam` for one that
%% lacks it; a file that is no compiled module is refused, as a run refuses
%% one (§11).
module_digest(File) ->
    {ok, Bytes} = file:read_file(File),
    case beam_lib:md5(Bytes) of
        {ok, {Module, Digest}} -> {Module, Digest};
        {error, beam_lib, _} -> ern_build:fail(File ++ " is not a compiled module")
    end.

%% The host's version, as its installation writes it.
otp_version() ->
    Release = erlang:system_info(otp_release),
    {ok, Text} = file:read_file(filename:join([code:root_dir(), "releases", Release,
                                               "OTP_VERSION"])),
    string:trim(Text).

%%
%% The node's start
%%

%% Report §8.7: the carrier started once the bindings have their values,
%% in the entry process: the peer table the rule and the port map read, the
%% host's own reports of its nodes turned off, the gateway, the watch on the
%% node's connections, and the host's distribution under the node's name,
%% listening where `listen` names an interface. A carrier that cannot
%% start, its port taken among the reasons, ends the node as an initializer
%% that faults ends a program (§8.5), the cause naming the host's reason.
-spec start(#configuration{}, boolean()) -> ok.
start(_Configuration, _Stamped) when node() =/= nonode@nohost ->
    %% report §11.2: `ern test` over a directory runs each module in a
    %% runtime of its own, in one host, which is one node
    ok;
start(#configuration{public_key = PublicKey, listen = Listen} = Configuration,
      Stamped) ->
    ok = list(Configuration),
    persistent_term:put({?MODULE, stamped}, Stamped),
    ok = logger:add_primary_filter(?MODULE, {fun ?MODULE:filter/2, []}),
    ok = ern_gateway:start(),
    Self = self(),
    Watcher = spawn(fun() -> watch(Self) end),
    receive {Watcher, watching} -> ok end,
    case net_kernel:start(name(PublicKey), #{name_domain => longnames,
                                             dist_listen => Listen =/= none}) of
        {ok, _} ->
            ok;
        {error, Reason} ->
            ern_rt:fault(iolist_to_binary(io_lib:format("the node's carrier did not start: ~0p",
                                                        [Reason])))
    end.

%% Report §8.7: the configuration the node runs by, and its peer table,
%% which the rule, the port map and the lines read, each peer by its key's
%% digest.
-spec list(#configuration{}) -> ok.
list(#configuration{peers = Peers} = Configuration) ->
    persistent_term:put({?MODULE, configuration}, Configuration),
    persistent_term:put({?MODULE, peers},
                        maps:from_list([{digest(Key), Peer}
                                        || #peer{public_key = Key} = Peer <- Peers])).

%% Whether the host was booted with the carrier's flags (boot_flags/2),
%% which a node needs; a host booted otherwise cannot carry one.
-spec booted() -> boolean().
booted() ->
    init:get_argument(proto_dist) =/= error.

%% The configuration the node started with.
-spec configuration() -> #configuration{}.
configuration() ->
    persistent_term:get({?MODULE, configuration}).

%% The peer of a node's name on the carrier, or none where it is listed by
%% no peer.
-spec peer(atom() | string()) -> #peer{} | none.
peer(Node) ->
    Text = case Node of
               Atom when is_atom(Atom) -> atom_to_list(Atom);
               String -> String
           end,
    Digest = hd(string:split(Text, "@")),
    maps:get(Digest, persistent_term:get({?MODULE, peers}, #{}), none).

%%
%% The rule
%%

%% Report §8.7: the rule that accepts a peer whose public key this node
%% lists, and no other, by the key alone: a certificate's name and dates
%% mean nothing to it, so the host's own checks of them, which come as a bad
%% certificate, are answered by the key; an extension is the host's. A key
%% not listed is refused, and the node says so.
-spec verify(#'OTPCertificate'{}, term(), term()) ->
          {valid, term()} | {unknown, term()} | {fail, term()}.
verify(_Certificate, {extension, _}, State) ->
    {unknown, State};
verify(_Certificate, valid, State) ->
    {valid, State};
verify(Certificate, _Event, State) ->
    case listed(Certificate) of
        {listed, _} ->
            {valid, State};
        {unlisted, Digest} ->
            say(["a node with the key ", Digest, " was refused: no peer has its key"]),
            {fail, not_listed}
    end.

%% The peer a certificate's key is listed for, or the key's digest where it
%% is listed for none.
-spec listed(#'OTPCertificate'{}) -> {listed, #peer{}} | {unlisted, string()}.
listed(Certificate) ->
    Digest = digest(certificate_key(Certificate)),
    case peer(Digest) of
        #peer{} = Peer -> {listed, Peer};
        none -> {unlisted, Digest}
    end.

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
%% error's process as a fault's line goes, with the time before it where
%% standard error is neither a terminal nor a journal (§11.2).
-spec say(iodata()) -> ok.
say(Text) ->
    Time = case persistent_term:get({?MODULE, stamped}, false) of
               true -> [calendar:system_time_to_rfc3339(erlang:system_time(millisecond),
                                                        [{unit, millisecond}, {offset, "Z"}]),
                        " "];
               false -> []
           end,
    ern_rt:send(ern_rt:system_process(stderr), iolist_to_binary([Time, Text, "\n"])),
    ok.

%% A peer as a line names it: by its name in `ernest.conf`, or by its key's
%% digest where it is not listed.
-spec named(atom()) -> iodata().
named(Node) ->
    case peer(Node) of
        #peer{name = Name} -> ["the peer ", Name];
        none -> ["the node ", hd(string:split(atom_to_list(Node), "@"))]
    end.

%% Report §8.7: the node watches its connections, to every kind of node,
%% and says that a peer connected, and that a peer was lost and whether it
%% fell silent or closed; a living connection another from the same node
%% replaced is said so.
watch(Starter) ->
    ok = net_kernel:monitor_nodes(true, [nodedown_reason, {node_type, all}]),
    Starter ! {self(), watching},
    watching().

watching() ->
    receive
        Event ->
            case said(Event) of
                none -> ok;
                Line -> say(Line)
            end
    end,
    watching().

%% Report §8.7: the line a change of a connection is said by, or none: a
%% peer connected; a peer lost, and whether it fell silent, which the
%% detector found, or closed; and a living connection replaced by another
%% from the same node, which the host ends with the reason `wait_pending`.
%% The node's own start comes as a connection too, and is none.
-spec said(term()) -> iodata() | none.
said({nodeup, Node, _}) when Node =:= node() ->
    none;
said({nodeup, Node, _}) ->
    [named(Node), " connected"];
said({nodedown, Node, Info}) ->
    case proplists:get_value(nodedown_reason, Info) of
        net_tick_timeout -> [named(Node), " was lost: it fell silent"];
        wait_pending -> [named(Node), "'s connection was replaced by another from the same node"];
        _ -> [named(Node), " was lost: it closed"]
    end;
said(_) ->
    none.

%% Report §8.7: the host's own reports of its nodes are turned off, but the
%% handshake's refusal of a peer for its build, by the cookie, which the
%% node says in its own words.
-spec filter(logger:log_event(), term()) -> logger:filter_return().
filter(#{msg := {report, #{label := {error_logger, _}, format := Format, args := Args}}}, _) ->
    host_message(Format, Args);
filter(#{msg := {Format, Args}}, _) when is_list(Format), is_list(Args) ->
    host_message(Format, Args);
filter(#{meta := #{domain := [otp, ssl | _]}}, _) ->
    stop;
filter(_Event, _) ->
    ignore.

%% A message of the host's of its nodes: the handshake's refusal for the
%% cookie said in the node's words, and every other dropped; any other
%% message left to the handlers.
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
            say([named(Node), " was refused: it runs another build"]),
            stop;
        _ ->
            stop
    end;
host_message(_, _) ->
    ignore.
