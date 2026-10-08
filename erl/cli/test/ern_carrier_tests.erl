%% A node's carrier (report §8.7): its name on the carrier, the build's
%% fingerprint, the flags its host boots with, the rule that accepts a peer
%% by its key, and the lines it says. Real nodes on one machine are
%% test/ern_nodes_tests.erl's.
-module(ern_carrier_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").
-include("../include/ern_node.hrl").

tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_carrier_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% A configuration directory `ern config` made, read.
configured() ->
    Dir = filename:join(tmp(), "node"),
    _ = ern_node:create(Dir),
    ern_node:read(Dir).

certificate(#configuration{dir = Dir}) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "certificate.pem")),
    [{'Certificate', Der, not_encrypted}] = public_key:pem_decode(Pem),
    public_key:pkix_decode_cert(Der, otp).

digest(Key) ->
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Key), lowercase)).

%% report §8.7: a node's name on the carrier is its key's SHA-256 digest
%% with a constant after it, holding no network address
name_test() ->
    #configuration{public_key = Key} = configured(),
    ?assertEqual(list_to_atom(digest(Key) ++ "@node.ernest"), ern_carrier:name(Key)),
    ?assertEqual(64, length(digest(Key))).

%% report §8.7: the build's fingerprint covers every compiled module on the
%% load path, a host module a `foreign fn` loads from one of its
%% directories among them, by the host's digest of its code; a module more,
%% or one changed, changes it, and a file that is no compiled module is
%% refused
fingerprint_test() ->
    Dir = tmp(),
    ok = file:write_file(filename:join(Dir, "one.ern"), "export fn f() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir], group_leader())),
    One = ern_carrier:fingerprint([Dir]),
    ?assertEqual(One, ern_carrier:fingerprint([Dir])),
    ?assertEqual(64, length(One)),
    ?assertNotEqual(One, ern_carrier:fingerprint([])),
    ok = file:write_file(filename:join(Dir, "two.ern"), "export fn g() : Int = 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir], group_leader())),
    Two = ern_carrier:fingerprint([Dir]),
    ?assertNotEqual(One, Two),
    ok = file:write_file(filename:join(Dir, "two.ern"), "export fn g() : Int = 3\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir], group_leader())),
    ?assertNotEqual(Two, ern_carrier:fingerprint([Dir])),
    {ok, Beam} = file:read_file(code:which(ern_carrier)),
    ok = file:write_file(filename:join(Dir, "helper.beam"), Beam),
    ?assertNotEqual(ern_carrier:fingerprint([Dir]), Two),
    ok = file:write_file(filename:join(Dir, "broken.erc"), <<"not a module">>),
    ?assertThrow({cli_error, _}, ern_carrier:fingerprint([Dir])).

%% report §8.7: a node's host boots with TLS 1.3 over the listener's family
%% of addresses, the node's certificate and key on each side, the rule as
%% the verification, no port-mapper daemon, no mesh, the detector's times,
%% the buffer, and the build's fingerprint as the cookie; the listener's
%% interface is the kernel's to bind where it is one
boot_flags_test() ->
    Configuration = configured(),
    Dir = filename:absname(Configuration#configuration.dir),
    Flags = ern_carrier:boot_flags(Configuration#configuration{listen = {{127, 0, 0, 1}, 0}}, []),
    Cookie = ern_carrier:fingerprint([]),
    ?assertMatch(["-proto_dist", "inet_tls", "-ssl_dist_opt" | _], Flags),
    lists:foreach(fun(Pair) -> ?assert(contains(Flags, Pair)) end,
                  [["server_certfile", filename:join(Dir, "certificate.pem")],
                   ["server_keyfile", filename:join(Dir, "private-key.pem")],
                   ["server_cacertfile", filename:join(Dir, "certificate.pem")],
                   ["server_verify", "verify_peer"], ["server_versions", "tlsv1.3"],
                   ["server_verify_fun", "{ern_carrier,verify,[]}"],
                   ["server_fail_if_no_peer_cert", "true"],
                   ["client_verify", "verify_peer"], ["client_versions", "tlsv1.3"],
                   ["-epmd_module", "ern_epmd"], ["-start_epmd", "false"],
                   ["-connect_all", "false"], ["-kernel", "net_ticktime", "60"],
                   ["-kernel", "net_setuptime", "7"], ["+zdbbl", "1024"],
                   ["-setcookie", Cookie],
                   ["-kernel", "inet_dist_use_interface", "{127,0,0,1}"]]),
    ?assertNot(contains(Flags, ["client_fail_if_no_peer_cert", "true"])),
    All = ern_carrier:boot_flags(Configuration#configuration{listen = {{0, 0, 0, 0, 0, 0, 0, 0},
                                                                         8654}}, []),
    ?assertMatch(["-proto_dist", "inet6_tls" | _], All),
    ?assertNot(lists:member("inet_dist_use_interface", All)),
    Dialling = ern_carrier:boot_flags(Configuration#configuration{listen = none}, []),
    ?assertMatch(["-proto_dist", "inet_tls" | _], Dialling),
    ?assertNot(lists:member("inet_dist_use_interface", Dialling)).

contains(List, Part) ->
    lists:prefix(Part, List) orelse (List =/= [] andalso contains(tl(List), Part)).

%% report §8.7: the rule accepts a node whose key the configuration lists,
%% by the key alone, and refuses any other, the node's own among them
listed_test() ->
    Own = configured(),
    Peer = configured(),
    Stranger = configured(),
    ok = ern_carrier:list(Own#configuration{
                            peers = [#peer{name = <<"store">>,
                                           public_key = Peer#configuration.public_key}]}),
    ?assertMatch({listed, #peer{name = <<"store">>}}, ern_carrier:listed(certificate(Peer))),
    Unlisted = digest(Stranger#configuration.public_key),
    ?assertEqual({unlisted, Unlisted}, ern_carrier:listed(certificate(Stranger))),
    ?assertEqual({unlisted, digest(Own#configuration.public_key)},
                 ern_carrier:listed(certificate(Own))),
    ?assertEqual({unknown, state}, ern_carrier:verify(certificate(Peer), {extension, x}, state)),
    ?assertEqual({valid, state},
                 ern_carrier:verify(certificate(Peer), {bad_cert, selfsigned_peer}, state)).

%% report §8.7: the lines a node says of its connections: a peer connected,
%% by its name, or by its key's digest where it is not listed; a peer lost,
%% fallen silent or closed; a living connection replaced by another from the
%% same node; nothing for the node's own start
said_test() ->
    Own = configured(),
    Peer = configured(),
    ok = ern_carrier:list(Own#configuration{
                            peers = [#peer{name = <<"store">>,
                                           public_key = Peer#configuration.public_key}]}),
    Store = ern_carrier:name(Peer#configuration.public_key),
    Other = list_to_atom(lists:duplicate(64, $a) ++ "@node.ernest"),
    Said = fun(Event) -> iolist_to_binary(ern_carrier:said(Event)) end,
    ?assertEqual(<<"the peer store connected">>, Said({nodeup, Store, []})),
    ?assertEqual(<<"the node ", (list_to_binary(lists:duplicate(64, $a)))/binary, " connected">>,
                 Said({nodeup, Other, []})),
    ?assertEqual(<<"the peer store was lost: it fell silent">>,
                 Said({nodedown, Store, [{nodedown_reason, net_tick_timeout}]})),
    ?assertEqual(<<"the peer store was lost: it closed">>,
                 Said({nodedown, Store, [{nodedown_reason, connection_closed}]})),
    ?assertEqual(<<"the peer store's connection was replaced by another from the same node">>,
                 Said({nodedown, Store, [{nodedown_reason, wait_pending}]})),
    ?assertEqual(none, ern_carrier:said({nodeup, node(), []})).
