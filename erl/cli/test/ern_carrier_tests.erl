%% A node's carrier (report §12.5): its name on the carrier, the floor's
%% cookie, the flags its host boots with, the rule that accepts a peer
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
    _ = ern_node:create(Dir, ern_node:default_listen()),
    ern_node:read(Dir).

certificate(#configuration{config_dir = Dir}) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "certificate.pem")),
    [{'Certificate', Der, not_encrypted}] = public_key:pem_decode(Pem),
    public_key:pkix_decode_cert(Der, otp).

digest(Key) ->
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Key), lowercase)).

%% report §12.5: a node's name on the carrier is a constant at the host its
%% key gives, the key's SHA-256 digest as two labels of 32 hexadecimal
%% digits, holding no network address; its certificate names that host and
%% no other, as the host's check of a name reads it
name_test() ->
    #configuration{public_key = Key} = Configuration = configured(),
    {First, Second} = lists:split(32, digest(Key)),
    ?assertEqual(First ++ "." ++ Second, ern_carrier:host(Key)),
    ?assertEqual(list_to_atom("ernest@" ++ First ++ "." ++ Second), ern_carrier:name(Key)),
    Certificate = certificate(Configuration),
    ?assert(ern_carrier:names_own_host(Certificate)),
    ?assert(public_key:pkix_verify_hostname(Certificate, [{dns_id, ern_carrier:host(Key)}])),
    Other = (configured())#configuration.public_key,
    ?assertNot(public_key:pkix_verify_hostname(Certificate, [{dns_id, ern_carrier:host(Other)}])).

%% report §12.5, Appendix H: the cookie is the digest of the floor: for a
%% release, the protocol's version, 4 since MVP 3.95, the form's version, 2
%% since MVP 3.27, `ern`'s major and minor and OTP's major release, so that
%% two patch levels of one minor stand on one floor and two minors do not;
%% for a build that is no release, development, the digest of its own
%% code, the code of the repository's build, and two codes stand apart; and
%% nothing of a program's build, the same for every load path and not
%% changed by a module built.
%%
%% A regression test of MVP 3.0's fingerprint, which held every compiled
%% module of the load path, and of findings H5, H10 and N11, written after
%% the code: the cookie held `ern`'s whole version and no form's version,
%% and a development build stood on the floor of the release it came
%% after. It does not cover the code digest's change with a module of the
%% toolchain's
cookie_test() ->
    Digest = fun(Floor) ->
                 binary_to_list(binary:encode_hex(
                                  crypto:hash(sha256, term_to_binary(Floor, [deterministic])),
                                  lowercase))
             end,
    Unasked = fun() -> erlang:error(code_digest_asked) end,
    Otp = erlang:system_info(otp_release),
    ?assertEqual(Digest({4, 2, 0, 3, Otp}), ern_carrier:cookie({0, 3, 1}, Unasked)),
    ?assertEqual(ern_carrier:cookie({0, 3, 1}, Unasked), ern_carrier:cookie({0, 3, 7}, Unasked)),
    ?assertNotEqual(ern_carrier:cookie({0, 3, 1}, Unasked), ern_carrier:cookie({0, 4, 0}, Unasked)),
    ?assertNotEqual(ern_carrier:cookie({0, 3, 1}, Unasked), ern_carrier:cookie({1, 3, 1}, Unasked)),
    Code = fun(Bytes) -> fun() -> Bytes end end,
    ?assertEqual(Digest(<<1>>), ern_carrier:cookie(development, Code(<<1>>))),
    ?assertNotEqual(ern_carrier:cookie(development, Code(<<1>>)),
                    ern_carrier:cookie(development, Code(<<2>>))),
    %% report §12.5: a release's version is three whole numbers, each part
    %% its digits alone, which ern_release reads, the carrier parsing
    %% nothing; one of another shape is refused plainly, naming it. A
    %% regression test, written after the fix (the release review before
    %% 0.4.0 found a badmatch; the full review before 0.5.0 found `+0.4.0`
    %% taken)
    ?assertEqual({0, 4, 0}, ern_release:release("0.4.0")),
    ?assertEqual({0, 4, 0}, ern_release:release("00.4.0")),
    [?assertThrow({cli_error, _}, ern_release:release(Text))
     || Text <- ["0.3", "0.3.1.2", "0.x.1", "0.3.1-rc1", "-1.3.1", "+0.4.0", "0.+4.0", "0..1", ""]],
    ?assertThrow({cli_error, "the version 0.3 is not a release's, three whole numbers"},
                 ern_release:release("0.3")),
    %% the repository's build is no release, and stands on its code's digest
    {ok, Version} = file:read_file("../../../VERSION"),
    Release = binary_to_list(string:trim(Version)),
    ?assertEqual(Release ++ "-dev", ern_release:version_text()),
    Cookie = ern_carrier:cookie(),
    ?assertEqual(development, ern_release:release()),
    ?assertNotEqual(ern_carrier:cookie(ern_release:release(Release), Unasked), Cookie),
    Dir = tmp(),
    ok = file:write_file(filename:join(Dir, "one.ern"), "export fn f() : Int = 1\n"),
    ?assertEqual(0, ern_cli:ern(["build", Dir], group_leader())),
    ?assertEqual(Cookie, ern_carrier:cookie()),
    Configuration = configured(),
    ?assert(contains(ern_carrier:boot_flags(Configuration), ["-setcookie", Cookie])).

%% report §12.5, §12.6: a node's host boots with TLS 1.3 over the listener's family
%% of addresses, the node's certificate and key on each side, the rule as
%% the verification, no port-mapper daemon, no mesh, the detector's times,
%% the buffer, and the floor's digest as the cookie; the listener's
%% interface is the kernel's to bind where it is one
boot_flags_test() ->
    Configuration = configured(),
    Dir = filename:absname(Configuration#configuration.config_dir),
    Flags = ern_carrier:boot_flags(Configuration#configuration{listen = {{127, 0, 0, 1}, 0}}),
    Cookie = ern_carrier:cookie(),
    ?assertMatch(["-proto_dist", "inet_tls", "-ssl_dist_opt" | _], Flags),
    lists:foreach(fun(Pair) -> ?assert(contains(Flags, Pair)) end,
                  [["server_certfile", filename:join(Dir, "certificate.pem")],
                   ["server_keyfile", filename:join(Dir, "private-key.pem")],
                   ["server_cacertfile", filename:join(Dir, "certificate.pem")],
                   ["server_verify", "verify_peer"], ["server_versions", "tlsv1.3"],
                   ["server_verify_fun", "{ern_carrier,verify,server}"],
                   ["client_verify_fun", "{ern_carrier,verify,client}"],
                   ["server_fail_if_no_peer_cert", "true"],
                   ["client_verify", "verify_peer"], ["client_versions", "tlsv1.3"],
                   ["-epmd_module", "ern_epmd"], ["-start_epmd", "false"],
                   ["-connect_all", "false"], ["-kernel", "net_ticktime", "60"],
                   ["-kernel", "net_setuptime", "7"], ["+zdbbl", "1024"],
                   ["-setcookie", Cookie],
                   ["-kernel", "inet_dist_use_interface", "{127,0,0,1}"]]),
    ?assertNot(contains(Flags, ["client_fail_if_no_peer_cert", "true"])),
    All = ern_carrier:boot_flags(Configuration#configuration{listen = {{0, 0, 0, 0, 0, 0, 0, 0},
                                                                         8654}}),
    ?assertMatch(["-proto_dist", "inet6_tls" | _], All),
    ?assertNot(lists:member("inet_dist_use_interface", All)),
    Dialing = ern_carrier:boot_flags(Configuration#configuration{listen = none}),
    ?assertMatch(["-proto_dist", "inet_tls" | _], Dialing),
    ?assertNot(lists:member("inet_dist_use_interface", Dialing)).

contains(List, Part) ->
    lists:prefix(Part, List) orelse (List =/= [] andalso contains(tl(List), Part)).

%% report §12.5: the rule accepts a node whose key the configuration lists,
%% and refuses any other, the node's own among them
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
    ?assertEqual({unknown, server},
                 ern_carrier:verify(certificate(Peer), {extension, x}, server)),
    ?assertEqual({valid, server},
                 ern_carrier:verify(certificate(Peer), {bad_cert, selfsigned_peer}, server)).

%% report §12.5: a node it dials must answer under the name it dialed: on
%% the client's side the rule takes a listed key only where it gives the
%% host the process that dialed recorded as it asked the peer's address,
%% the process the connection's own monitors, and refuses another listed
%% key, the node saying which peer answered the dial of which; a check
%% that finds no process that dialed refuses the key, saying so, and fails
%% in nothing of the host's. A regression test, written after the fix (the
%% release review before 0.4.0 found a listed key taken for any peer
%% dialed; the full review before 0.5.0 a badmatch where none had dialed);
%% test/ern_nodes_tests.erl's answered_by_another_key_test_ dials through
%% the host's TLS
dialed_test() ->
    Own = configured(),
    Peer = configured(),
    Other = configured(),
    Self = self(),
    Peers = [#peer{name = <<"store">>, public_key = Peer#configuration.public_key,
                   address = {{127, 0, 0, 1}, 8654}},
             #peer{name = <<"desk">>, public_key = Other#configuration.public_key,
                   address = {{127, 0, 0, 1}, 8655}}],
    ok = ern_carrier:list(Own#configuration{peers = Peers}),
    Dialed = ern_carrier:host(Peer#configuration.public_key),
    %% the process that dials, outside the run, waits until the run ends
    Dialer = spawn(fun() ->
                       {ok, _, 8654, _} = ern_epmd:address_please("ernest", Dialed, inet),
                       Self ! dialing,
                       receive done -> ok end
                   end),
    receive dialing -> ok end,
    Main = fun() ->
                   Checked = fun(Certificate) ->
                                 MonitorRef = erlang:monitor(process, Dialer),
                                 Verified = ern_carrier:verify(Certificate,
                                                               {bad_cert, selfsigned_peer},
                                                               client),
                                 erlang:demonitor(MonitorRef),
                                 Verified
                             end,
                   Self ! {verified, Checked(certificate(Peer)), Checked(certificate(Other))},
                   Self ! {unknown, ern_carrier:verify(certificate(Peer),
                                                       {bad_cert, selfsigned_peer}, client)}
           end,
    Said = fun(Bytes) -> Self ! {said, Bytes} end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => Said, stderr => Said})),
    Dialer ! done,
    ?assertEqual({verified, {valid, client}, {fail, not_dialed}},
                 receive {verified, _, _} = Verified -> Verified end),
    ?assertEqual({said, <<"the peer desk was refused: it answered the dial of the peer store\n">>},
                 receive {said, _} = Line -> Line end),
    ?assertEqual({unknown, {fail, not_dialed}}, receive {unknown, _} = Unknown -> Unknown end),
    ?assertEqual({said, <<"the peer store was refused: the dial it answered is not known\n">>},
                 receive {said, _} = Line -> Line end).

%% report §12.5: the lines a node says of its connections: a peer connected,
%% by its name, or by its key's digest where it is not listed; a peer lost,
%% fallen silent or closed; a peer ended, having told this node it ends; a
%% living connection replaced by another from the same node; nothing for the
%% node's own start
said_test() ->
    Own = configured(),
    Peer = configured(),
    ok = ern_carrier:list(Own#configuration{
                            peers = [#peer{name = <<"store">>,
                                           public_key = Peer#configuration.public_key}]}),
    Store = ern_carrier:name(Peer#configuration.public_key),
    Other = list_to_atom("ernest@" ++ lists:duplicate(32, $a) ++ "." ++ lists:duplicate(32, $a)),
    Said = fun(Event) -> iolist_to_binary(ern_carrier:said(Event)) end,
    ?assertEqual(<<"the peer store connected">>, Said({nodeup, Store, []})),
    ?assertEqual(<<"the node ", (list_to_binary(lists:duplicate(64, $a)))/binary, " connected">>,
                 Said({nodeup, Other, []})),
    ?assertEqual(<<"the peer store was lost: it fell silent">>,
                 Said({nodedown, Store, [{nodedown_reason, net_tick_timeout}]})),
    ?assertEqual(<<"the peer store was lost: it closed">>,
                 Said({nodedown, Store, [{nodedown_reason, connection_closed}]})),
    ?assertEqual(<<"the peer store ended">>, Said({ended, Store})),
    ?assertEqual(<<"the peer store's connection was replaced by another from the same node">>,
                 Said({nodedown, Store, [{nodedown_reason, wait_pending}]})),
    ?assertEqual(none, ern_carrier:said({nodeup, node(), []})).

%% report §12.5, §11.2: a name a connecting node gave in a handshake the
%% host refused is said with its control characters escaped, as a cause's
%% are: the name its key does not give, and on another floor the host of
%% its name, where no peer is listed by it. A regression test: the lines
%% wrote the name as the node gave it, its control characters with it
handshake_name_escaped_test() ->
    persistent_term:put({ern_cli, error_device}, group_leader()),
    try
        ?assertEqual(stop, ern_carrier:filter(
                             #{msg => {"** Connection attempt from disallowed node ~s ** ~n",
                                       ["ghost\e[2J@node"]}}, [])),
        ?assertEqual(stop, ern_carrier:filter(
                             #{msg => {"** Connection attempt from node ~w rejected. Invalid"
                                       " challenge reply. **~n", ['ernest@x\ey.z']}}, [])),
        %% the floor's line is said later, by the runtime's own process
        ern_rt:wait_for_later()
    after
        persistent_term:erase({ern_cli, error_device})
    end,
    ?assertEqual(<<"a node named ghost\\u{1B}[2J@node was refused: its key gives another"
                   " name\n"
                   "the node x\\u{1B}yz was refused: it stands on another floor, another"
                   " release or build of ern or another major release of OTP\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §12.5: a reload whose reading fails with anything but a refusal,
%% as a failure of the runtime's helper would, is refused, the node saying
%% so with the host's reason, and the configuration stays; the signal
%% handler, which runs it, goes on taking signals. A regression test: such
%% a failure removed the handler, and the node took no signal after it,
%% `ern stop` among them. Here a directory no read can take stands for the
%% failure
reload_failure_test() ->
    Running = (configured())#configuration{config_dir = {not_a_directory}},
    Self = self(),
    Main = fun() ->
                   ok = ern_carrier:list(Running),
                   Self ! {handled, ern_signals:handle_event(sighup, [])},
                   Self ! {kept, ern_carrier:configuration() =:= Running}
           end,
    Said = fun(Bytes) -> Self ! {said, Bytes} end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => Said, stderr => Said})),
    ?assertEqual({handled, {ok, []}}, receive {handled, _} = Handled -> Handled end),
    ?assertEqual({kept, true}, receive {kept, _} = Kept -> Kept end),
    {said, Line} = receive {said, _} = Got -> Got end,
    ?assertMatch(<<"the reload was refused, and the configuration stays as it was: ", _/binary>>,
                 Line).

%% A certificate signed with the key in a configuration directory that names
%% the host given, for the rule to refuse: the key is one node's, the host
%% another's.
forged(#configuration{config_dir = Dir}, Host) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "private-key.pem")),
    [Entry] = public_key:pem_decode(Pem),
    {'ECPrivateKey', _, Private, _, _, _} = Key = public_key:pem_entry_decode(Entry),
    {Point, _} = crypto:generate_key(eddsa, ed25519, Private),
    Name = {rdnSequence, [[#'AttributeTypeAndValue'{type = ?'id-at-commonName',
                                                    value = {utf8String, <<"ernest">>}}]]},
    Tbs = #'OTPTBSCertificate'{
             version = v3, serialNumber = 1,
             signature = #'SignatureAlgorithm'{algorithm = ?'id-Ed25519'},
             issuer = Name, subject = Name,
             validity = #'Validity'{notBefore = {utcTime, "700101000000Z"},
                                    notAfter = {generalTime, "99991231235959Z"}},
             subjectPublicKeyInfo = #'OTPSubjectPublicKeyInfo'{
                                       algorithm = #'PublicKeyAlgorithm'{algorithm = ?'id-Ed25519'},
                                       subjectPublicKey = #'ECPoint'{point = Point}},
             extensions = [#'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                                        extnValue = [{dNSName, Host}]}]},
    public_key:pkix_decode_cert(public_key:pkix_sign(Tbs, Key), otp).

%% report §12.5: a certificate that names another host than its key gives is
%% refused, though its key is listed, and the node says so; the rule's
%% refusals are said once a run's standard error is there
other_host_test() ->
    Own = configured(),
    Peer = configured(),
    Other = configured(),
    Forged = forged(Peer, ern_carrier:host(Other#configuration.public_key)),
    ?assertNot(ern_carrier:names_own_host(Forged)),
    Self = self(),
    Peers = [#peer{name = <<"store">>, public_key = Peer#configuration.public_key},
             #peer{name = <<"desk">>, public_key = Other#configuration.public_key}],
    Main = fun() ->
                   ok = ern_carrier:list(Own#configuration{peers = Peers}),
                   Self ! {verified, ern_carrier:verify(Forged, {bad_cert, selfsigned_peer},
                                                        server)}
           end,
    Said = fun(Bytes) -> Self ! {said, Bytes} end,
    ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => Said, stderr => Said})),
    ?assertEqual({verified, {fail, other_host}}, receive {verified, _} = Verified -> Verified end),
    ?assertEqual({said, <<"the peer store was refused: its certificate names another host than"
                          " its key gives\n">>},
                 receive {said, _} = Line -> Line end).

%% report §12.5: a peer's name is resolved at each dial, where its family is
%% checked: a name that resolves only to the other family fails the dial
%% as a refused one does, and the node says why; an address is given as it
%% stands. A regression test, written after the code that moved the check
%% from the reading of the configuration. The host's own table of hosts
%% gives the name, for the test's run alone
dial_family_test() ->
    Own = configured(),
    Peer = configured(),
    Other = configured(),
    Peers = [#peer{name = <<"store">>, public_key = Peer#configuration.public_key,
                   address = {"only6.ernest.invalid", 8654}},
             #peer{name = <<"desk">>, public_key = Other#configuration.public_key,
                   address = {{127, 0, 0, 1}, 8655}}],
    Lookup = inet_db:res_option(lookup),
    ok = inet_db:add_host({0, 0, 0, 0, 0, 0, 0, 1}, ["only6.ernest.invalid"]),
    ok = inet_db:set_lookup([file | Lookup]),
    Self = self(),
    Main = fun() ->
                   ok = ern_carrier:list(Own#configuration{peers = Peers}),
                   %% the host's distribution dials from a process of its own; here
                   %% the entry process waits on the host's resolver, the host's
                   %% work, which the deadlock detector reads on top of its stack
                   %% (report §8.6)
                   Dial = fun(#configuration{public_key = Key}, Family) ->
                                  ern_epmd:address_please("ernest", ern_carrier:host(Key), Family)
                          end,
                   Self ! {dialed, Dial(Peer, inet), Dial(Peer, inet6), Dial(Other, inet)}
           end,
    Said = fun(Bytes) -> Self ! {said, Bytes} end,
    try
        ?assertEqual(ok, ern_rt:run_main(Main, <<"main">>, #{stdout => Said, stderr => Said}))
    after
        ok = inet_db:set_lookup(Lookup),
        ok = inet_db:del_host({0, 0, 0, 0, 0, 0, 0, 1})
    end,
    ?assertMatch({dialed, {error, _}, {ok, {0, 0, 0, 0, 0, 0, 0, 1}, 8654, _},
                  {ok, {127, 0, 0, 1}, 8655, _}},
                 receive {dialed, _, _, _} = Dialed -> Dialed end),
    ?assertEqual({said, <<"the peer store was not dialed: its network-address names"
                          " only6.ernest.invalid, which resolves only to IPv6, and this node runs"
                          " over IPv4\n">>},
                 receive {said, _} = Line -> Line end).
