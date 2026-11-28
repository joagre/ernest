%% Nodes on one machine (report §8.7): each node an `ern run --config-dir`
%% of its own, started as a person starts one, its lines read from its
%% standard error, through the harness of test/ern_harness.erl. The
%% carrier's tests dial through a `foreign fn` of the host's, which reaches
%% the carrier and nothing of a program's; the frame a gateway cannot read
%% is sent by a host module on the program's load path; a host that holds a
%% peer's key and names itself as it likes is a bare `erl` with the host's
%% TLS distribution and the key's files.
%%
%% `Peer`'s tests run the programs of `test/fixtures/peers/`, one build
%% whose store and desk are two nodes; the tests of two builds write a
%% program and build it twice, one function and one type changed. A test
%% that provokes a line the deployment guide quotes holds it to the guide's
%% (ern_deployment_tests:cataloged/4).
-module(ern_nodes_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("public_key/include/public_key.hrl").
-include_lib("checker/include/ern_canonical.hrl").

-define(ERN, filename:absname("../bin/ern")).
%% The harness's time for one wait, and the detector's latest (report
%% §12.6), which a test that waits for the detector is given beside it.
-define(WAIT_MS, ern_harness:wait_ms()).
-define(DETECTOR_MS, ern_harness:detector_ms()).
%% Report §11.2: what a shell prints of a spawn on a peer that started, the
%% process's address the screen writes before it.
-define(SPAWNED, ") : Either(Io.Error, Address(Never))").
%% Report §8.7: the host gives up a dial that nothing answers after 7
%% seconds.
-define(DIAL_MS, 7000).
%% Report §11.2: the time before a line a node writes where its stream is
%% no terminal.
-define(STAMP, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z ").

%% report §12.5, §12.6: two nodes that list each other connect over TLS with a
%% certificate on each side, by the first operation that needs it, and each
%% says so naming the other; a node whose program ends tells the other,
%% which says it ended and not that it was lost; and the host's own reports
%% of its nodes are not written
connect_test_() ->
    ern_harness:nodes_test({waits, 7}, fun connect/1).

connect(Base) ->
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(B, "the peer a ended"),
    ern_harness:stop(B, WaitB),
    {OutA, ErrA} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(OutA, "connect: true"),
    ern_harness:has(ErrA, "the peer b connected"),
    ern_harness:has(ErrB, "the peer a connected"),
    ern_harness:has(ErrB, "the peer a ended"),
    ?assertEqual(nomatch, string:find(ErrB, "was lost")),
    ?assertEqual(nomatch, string:find(ErrB, "**")),
    %% a node's ernest.pid is there while it runs and gone at its end
    ?assertNot(filelib:is_file(filename:join(B, "ernest.pid"))).

%% report §8.7, §12.5: a node accepts a peer whose public key its configuration
%% lists, and no other: the dialer is told nothing but that it could not
%% connect, and the node that refused says so, naming the key's digest
unlisted_test_() ->
    ern_harness:nodes_test({waits, 7}, fun unlisted/1).

unlisted(Base) ->
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(B, "was refused: no peer has its key"),
    ern_harness:stop(B, WaitB),
    {OutA, ErrA} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(OutA, "connect: false"),
    %% the dialer says only that it listens
    [Listening] = string:split(string:trim(ErrA, trailing, "\n"), "\n", all),
    ern_harness:has(Listening, "listening on 127.0.0.1:" ++ integer_to_list(PortA)),
    ern_harness:has(ErrB, "a node with the key " ++ digest(A)
                          ++ " was refused: no peer has its key"),
    ?assertEqual(nomatch, string:find(ErrB, "TLS")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "no peer has its key",
                                   [{"b", digest(A)}]).

%% report §8.7, §12.5: a node accepts a connection from a peer whose key it lists
%% only under the name that key gives it: a host that holds the key of the
%% peer b and names itself otherwise is refused, and so is one that
%% presents b's key in a certificate naming the host of c's, another peer
%% listed; each refusal the node says. Under its own name the holder of b's
%% key connects and its calls run, and once a reload removes b its
%% connection ends and a call no longer runs. A regression test: a holder of
%% a listed key connected under a name of its choosing, which a reload that
%% removed the peer did not end, and over which a call still ran
bound_test_() ->
    ern_harness:nodes_test({waits, 12}, fun bound/1).

bound(Base) ->
    PortA = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    C = ern_harness:made(Base, "c", none),
    ern_harness:lists(A, [{"b", B, none}, {"c", C, none}]),
    Root = filename:join(Base, "build"),
    Program = ern_harness:program(Root),
    Cookie = ern_carrier:cookie(),
    WaitA = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    Target = ern_harness:name(A),
    {_, Ghost} = ern_harness:client(Root, "ghost@node.ernest", ern_harness:key_files(B), Cookie,
                                    PortA, Target, false),
    {0, GhostOut} = Ghost(),
    ern_harness:has(GhostOut, "connect: false"),
    ern_harness:says(A, "a node named ghost@node.ernest was refused: its key gives another name"),
    {_, Forged} = ern_harness:client(Root, ern_harness:name(C),
                                     forged(B, host(C)), Cookie, PortA,
                                     Target, false),
    {0, ForgedOut} = Forged(),
    ern_harness:has(ForgedOut, "connect: false"),
    ern_harness:says(A, "the peer b was refused: its certificate names another host than its key"
                        " gives"),
    {Own, Owned} = ern_harness:client(Root, ern_harness:name(B), ern_harness:key_files(B), Cookie,
                                      PortA, Target, true),
    ern_harness:says(A, "the peer b connected"),
    ern_harness:lists(A, [{"c", C, none}]),
    ?assertMatch({0, _}, signaled("reload", A)),
    ern_harness:says(A, "the peer b was removed"),
    true = port_command(Own, "go\n"),
    {0, OwnOut} = Owned(),
    ern_harness:stop(A, WaitA),
    ern_harness:has(OwnOut, "connect: true"),
    ern_harness:has(OwnOut, "call: ran"),
    ?assertEqual(nomatch, string:find(OwnOut, "after: ran")),
    ern_harness:has(OwnOut, "after: "),
    {_, ErrA} = ern_harness:said(A),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "gives another name", []),
    ern_deployment_tests:cataloged(ErrA, "7", "certificate names another host", [{"b", "b"}]).

%% A node's key's digest, as a refusal names an unlisted key.
digest(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(ern_harness:public(Dir)),
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Der), lowercase)).

%% A certificate signed with the key of a configuration directory that names
%% the host given, written beside the directory: the key is one node's, the
%% host another's.
forged(Dir, Host) ->
    File = Dir ++ ".forged.pem",
    ok = file:write_file(File, public_key:pem_encode([{'Certificate',
                                                        ern_helpers:forged_certificate(Dir, Host),
                                                        not_encrypted}])),
    {File, filename:join(Dir, "private-key.pem")}.

%% A node's key's host on the carrier.
host(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(ern_harness:public(Dir)),
    ern_carrier:host(Der).

%% report §12.5: a node it dials must answer under the name it dialed: the
%% address a lists for the peer b is the port of c, another peer it lists,
%% which answers under its own name, and the dial fails, neither node
%% connected; a refuses c's key for the dial of b and says so
answered_test_() ->
    ern_harness:nodes_test({waits, 6}, fun answered/1).

answered(Base) ->
    PortC = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", none),
    C = ern_harness:made(Base, "c", PortC),
    ern_harness:lists(A, [{"b", B, PortC}, {"c", C, none}]),
    ern_harness:lists(C, [{"a", A, none}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitC = ern_harness:start(C, Program, []),
    ern_harness:prints(C, "waiting"),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:stop(C, WaitC),
    {OutA, ErrA} = ern_harness:said(A),
    {_, ErrC} = ern_harness:said(C),
    ern_harness:has(OutA, "connect: false"),
    ern_harness:has(ErrA, "the peer c was refused: it answered the dial of the peer b"),
    ?assertEqual(nomatch, string:find(ErrA, "connected")),
    ?assertEqual(nomatch, string:find(ErrC, "connected")).

%% report §12.5: a node it dials must answer under the name it dialed, and a
%% key is taken only under the name that key gives it: the address a lists
%% for the peer b is held by a bare `erl` with the key of c, another peer a
%% lists, which names itself b, and the dial fails as a refused one does,
%% the program answered `Unreachable`, the node saying why. Written
%% before its fix, it failed: a took the holder of c's key for b, the
%% certificate bound to no host dialed
answered_by_another_key_test_() ->
    ern_harness:nodes_test({waits, 5}, fun answered_by_another_key/1).

answered_by_another_key(Base) ->
    PortB = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", none),
    C = ern_harness:made(Base, "c", none),
    ern_harness:lists(A, [{"b", B, PortB}, {"c", C, none}]),
    Root = filename:join(Base, "build"),
    Program = ern_harness:program(Root),
    {Holder, Held} = answering(Root, ern_harness:name(B), ern_harness:key_files(C),
                               ern_carrier:cookie(), PortB),
    WaitA = ern_harness:start(A, Program, ["utilization", "b"]),
    ?assertEqual(0, WaitA()),
    true = port_command(Holder, "go\n"),
    {0, _} = Held(),
    {OutA, ErrA} = ern_harness:said(A),
    ern_harness:has(OutA, "utilization: Left(Io.Unreachable)"),
    ern_harness:has(ErrA, "the peer c was refused: it answered the dial of the peer b"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "answered the dial", [{"c", "c"}, {"b", "b"}]),
    ?assertEqual(nomatch, string:find(ErrA, "connected")).

%% report §8.7, §12.6: a node that ends tells each peer connected when it
%% begins to stop so, and then its connections close, telling none how
%% busy it is after its word: a holder
%% of b's key, a bare `erl`, that says it ends and then tells a how busy it
%% is, its connection lasting, has not ended, and a says it was lost when
%% it closes, not that it ended. A regression test, written after the fix
%% (the release review found a peer's word that it ends kept
%% while its connection lasted); it does not cover a peer that says it
%% ends and stays connected telling nothing, whose word stands until its
%% connection's end
told_after_its_end_test_() ->
    ern_harness:nodes_test({waits, 6}, fun told_after_its_end/1).

told_after_its_end(Base) ->
    PortA = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, none}]),
    Root = filename:join(Base, "build"),
    Program = ern_harness:program(Root),
    Source = filename:join(Root, "ern_nodes_ender.erl"),
    ok = file:write_file(Source, <<"
-module(ern_nodes_ender).
-export([main/0]).
main() ->
    {ok, [[Target]]} = init:get_argument(ern_harness_target),
    Node = list_to_atom(Target),
    true = net_kernel:connect_node(Node),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), node_ends}),
    %% a telling, its utilization and interval any
    erlang:send({ern_gateway, Node}, {ern_frame, self(), {telling, 0.5, 5000}}),
    %% a call over the connection, whose answer comes once the frames before
    %% it have arrived, given the harness's time for one wait
    {ok, [[Ms]]} = init:get_argument(ern_harness_ms),
    Node = erpc:call(Node, erlang, node, [], list_to_integer(Ms)),
    halt().
">>),
    {ok, _} = compile:file(Source, [{outdir, Root}]),
    WaitA = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    {_, Ender} = ern_harness:client(Root, ern_harness:name(B), ern_harness:key_files(B),
                                    ern_carrier:cookie(), PortA, ern_harness:name(A), [],
                                    "ern_nodes_ender"),
    ?assertMatch({0, _}, Ender()),
    ern_harness:says(A, "the peer b was lost: it closed"),
    ern_harness:stop(A, WaitA),
    {_, ErrA} = ern_harness:said(A),
    ern_harness:has(ErrA, "the peer b connected"),
    ?assertEqual(nomatch, string:find(ErrA, "the peer b ended")).

%% A bare `erl` that listens on Port as Name, presenting the certificate and
%% key given and asking for none, with the cookie given, until a line comes
%% on its standard input; answered once it listens, with the port whose
%% writes are its standard input and the function that waits for its end.
answering(Root, Name, {Certificate, Key}, Cookie, Port) ->
    Source = filename:join(Root, "ern_nodes_answering.erl"),
    ok = file:write_file(Source, <<"
-module(ern_nodes_answering).
-export([main/0]).
main() ->
    io:format(\"listening~n\"),
    _ = io:get_line(\"\"),
    halt().
">>),
    {ok, _} = compile:file(Source, [{outdir, Root}]),
    Tls = lists:append([["server_" ++ Option, Value]
                        || {Option, Value} <- [{"certfile", Certificate}, {"keyfile", Key},
                                               {"verify", "verify_none"},
                                               {"versions", "tlsv1.3"}]]),
    Digits = integer_to_list(Port),
    Arguments = ["-noshell", "-pa", Root, "-name", Name, "-proto_dist", "inet_tls",
                 "-ssl_dist_opt" | Tls]
        ++ ["-epmd_module", "ern_harness_client", "-start_epmd", "false", "-connect_all", "false",
            "-setcookie", Cookie, "-kernel", "inet_dist_listen_min", Digits,
            "-kernel", "inet_dist_listen_max", Digits, "-ern_harness_port", Digits,
            "-s", "ern_nodes_answering", "main"],
    Holder = open_port({spawn_executable, os:find_executable("erl")},
                       [{args, Arguments}, exit_status, binary, stderr_to_stdout]),
    ern_harness:step({listening, Name}),
    listening(Holder, <<>>),
    {Holder, fun() -> ern_harness:collected(Holder, 1) end}.

listening(Holder, Acc) ->
    case binary:match(Acc, <<"listening">>) of
        nomatch ->
            receive
                {Holder, {data, Bytes}} -> listening(Holder, <<Acc/binary, Bytes/binary>>);
                {Holder, {exit_status, Status}} -> erlang:error({ended, Status, Acc})
            after ?WAIT_MS ->
                erlang:error({not_listening, Acc})
            end;
        _ ->
            ok
    end.

%% report §12.5: two nodes of different builds connect, the cookie being
%% the floor's digest and holding nothing of the build. A regression test:
%% a fingerprint once refused them
other_build_test_() ->
    ern_harness:nodes_test({waits, 7}, fun other_build/1).

other_build(Base) ->
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    Other = filename:join(Base, "other"),
    ok = filelib:ensure_path(Other),
    ok = file:write_file(filename:join(Other, "extra.ern"), "export fn f() : Int = 1\n"),
    Changed = ern_harness:program(Other),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Changed, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:stop(B, WaitB),
    {OutA, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(OutA, "connect: true"),
    ern_harness:has(ErrB, "the peer a connected"),
    ?assertEqual(nomatch, string:find(ErrB, "refused")).

%% report §12.5: a node that stands on another floor fails the handshake with
%% nothing sent, its cookie another's, and the node that refused it says so
%% in its own words; here a bare `erl` that holds a listed peer's key and
%% names itself as that key gives, with another cookie
other_floor_test_() ->
    ern_harness:nodes_test({waits, 6}, fun other_floor/1).

other_floor(Base) ->
    PortA = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, none}]),
    Root = filename:join(Base, "build"),
    Program = ern_harness:program(Root),
    WaitA = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    {_, Other} = ern_harness:client(Root, ern_harness:name(B), ern_harness:key_files(B),
                                    "another-floor", PortA, ern_harness:name(A), false),
    {0, OtherOut} = Other(),
    ern_harness:has(OtherOut, "connect: false"),
    ern_harness:says(A, "the peer b was refused: it stands on another floor, another release or"
                        " build of ern or another major release of OTP"),
    ern_harness:stop(A, WaitA),
    {_, ErrA} = ern_harness:said(A),
    ?assertEqual(nomatch, string:find(ErrA, "**")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "another floor", [{"b", "b"}]).

%% report §8.7: two nodes started from copies of
%% one directory are one node to their peers; the second's dial ends the
%% first's connection, which the peer says each time. Its limit is the sum
%% of its eight steps, its program's build, a line of b's, of a's and of
%% b's again, three nodes' ends and what b said, each bounded by the
%% harness's time for one wait: written after its limit of 60 s, a number
%% of its own, ran out under the full run's load; its builds are counted,
%% and its host modules' compiles, which are no step, are not
replaced_test_() ->
    ern_harness:nodes_test({waits, 8}, fun replaced/1).

replaced(Base) ->
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    Copy = filename:join(Base, "copy"),
    ok = file:make_dir(Copy),
    [{ok, _} = file:copy(filename:join(A, File), filename:join(Copy, File))
     || File <- ["ernest.conf", "certificate.pem", "private-key.pem"]],
    %% report §12.5: the directory and `ernest.conf` written by none but
    %% their owner, and the key read and written by none but its owner,
    %% which a copy made under the mask is not
    [ok = file:change_mode(Path, Mode)
     || {Path, Mode} <- [{Copy, 8#700}, {filename:join(Copy, "ernest.conf"), 8#644},
                         {filename:join(Copy, "private-key.pem"), 8#600}]],
    ern_harness:edit(Copy, fun(Conf) -> maps:remove(<<"listen">>, Conf) end),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["hold", ern_harness:name(B)]),
    ern_harness:says(A, "the peer b connected"),
    WaitCopy = ern_harness:start(Copy, Program, ["hold", ern_harness:name(B)]),
    ern_harness:says(B, "the peer a's connection was replaced by another from the same node"),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{A, WaitA}, {Copy, WaitCopy}, {B, WaitB}]],
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(ErrB, "the peer a's connection was replaced by another from the same node"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "was replaced by another", [{"b", "a"}]).

%% report §12.5: a node says the address and the port it listens on, once
%% at every start: one whose `listen` names port 0 the port the host picks,
%% and one whose `listen` names a port that port, which a peer waits on
%% before it dials (the log's *The Review's Decisions*, written with the
%% line); a node without `listen` does not listen, says nothing of it, and
%% dials
listening_test_() ->
    ern_harness:nodes_test({waits, 10}, fun listening/1).

listening(Base) ->
    PortB = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", PortB),
    Z = ern_harness:made(Base, "z", 0),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, none}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitZ = ern_harness:start(Z, Program, []),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:says(B, "listening on 127.0.0.1:" ++ integer_to_list(PortB) ++ "\n"),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(Z, "listening on "),
    ern_harness:says(B, "the peer a connected"),
    ern_harness:stop(B, WaitB),
    ern_harness:stop(Z, WaitZ),
    {OutA, ErrA} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    {_, ErrZ} = ern_harness:said(Z),
    ern_harness:has(OutA, "connect: true"),
    ern_harness:has(ErrB, "the peer a connected"),
    {match, [Bound]} = re:run(ErrZ, "listening on 127\\.0\\.0\\.1:([0-9]+)\n",
                              [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Bound) > 0),
    ?assertEqual(1, length(string:split(ErrB, "listening on", all)) - 1),
    ?assertEqual(nomatch, string:find(ErrA, "listening")).

%% report §12.6: a frame the gateway cannot read is faulty, and the node ends
%% the connection, saying so; the sender's node is told of the loss; a
%% message that names no peer's process names no connection, and is
%% dropped, which the node says
faulty_frame_test_() ->
    ern_harness:nodes_test({waits, 8}, fun faulty_frame/1).

faulty_frame(Base) ->
    {A, ErrB} = unread_by_b(Base, fun(_, B) -> ["frame", B] end),
    {_, ErrA} = ern_harness:said(A),
    ern_harness:has(ErrB,
                    "a frame that names no peer's process came to the gateway, and was dropped"),
    ern_harness:has(ErrA, "the peer b was lost: it closed"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "it closed", [{"b", "b"}]).

%% Two nodes, a and b, listing each other and running the nodes' program,
%% a with the arguments Arguments(Program, Name) gives for b's name: a
%% sends b a frame b cannot read, b ends the connection, saying so, and a
%% is told of the loss. Answered once both have ended and b's standard
%% error holds the line that says so: a's directory and b's standard
%% error.
unread_by_b(Base, Arguments) ->
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    {InputA, WaitA} = ern_harness:started(A, Program, Arguments(Program, ern_harness:name(B))),
    ern_harness:says(B, "this node ends its connection"),
    ern_harness:says(A, "the peer b was lost: it closed"),
    true = port_command(InputA, "ended\n"),
    ?assertEqual(0, WaitA()),
    ern_harness:stop(B, WaitB),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(ErrB, "the peer a sent a frame this node cannot read, and this node ends its"
                          " connection"),
    {A, ErrB}.

%% report §12.6: a spawn frame whose site is not UTF-8 is a frame the node
%% cannot read, though the node holds the function it names: the node ends
%% the connection, saying so, and the sender's node is told of the loss. A
%% regression test, written after the fix: the site was read only where the
%% node lacked the function, and a node that held it started the process
%% under the site as it came
unreadable_site_test_() ->
    ern_harness:nodes_test({waits, 7}, fun unreadable_site/1).

unreadable_site(Base) ->
    unread_by_b(Base, fun(Program, B) -> ["site", B, held_hash(Program)] end).

%% The hash of the program's Node.held, as a frame names it.
held_hash(Program) ->
    {ok, Beam} = file:read_file(Program),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    [Held] = [binary_to_list(binary:encode_hex(Hash))
              || #definition{qualified_name = ['Node', held], hash = Hash} <- Definitions],
    Held.

%% report §12.6, §8.7: a find frame whose alias is of another node than its
%% sender's is a frame the node cannot read, as a compute's is, since a
%% find is answered through the asker's alias: the node ends the
%% connection, saying so, and the sender's node is told of the loss. A
%% regression test, written before the fix: the node answered through the
%% alias wherever it was, so that a full buffer for the alias's node would
%% have held the sender's frames behind the answer (the log's *What a
%% Peer's Worker Waits On*)
unreadable_find_alias_test_() ->
    ern_harness:nodes_test({waits, 7}, fun unreadable_find_alias/1).

unreadable_find_alias(Base) ->
    unread_by_b(Base, fun(_, B) -> ["elsewhere", B] end).

%% report §8.7, §11.2: a node reads every module of its load path at its
%% start, and is refused where one of them needs a module the path lacks,
%% the refusal naming the module and the one that needs it and, after a
%% semicolon, the rule, a bare node's among them; the same program run as
%% no node loads only what it uses, and runs; and where the program's own
%% reach lacks the module, its load comes first, and the refusal is `ern
%% run`'s alone, a node's or not. A regression test, written after the fix:
%% the refusal named neither the module that needed it nor the rule; the
%% program's own text written before the code, which gave it the rule
missing_module_test_() ->
    ern_harness:nodes_test({waits, 6}, fun missing_module/1).

missing_module(Base) ->
    Lone = ern_harness:made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    [ok = file:write_file(filename:join(Source, File), Text)
     || {File, Text} <- [{"main.ern", "export fn main() : Unit = Io.println(\"ran\")\n"},
                         {"user.ern", "export fn twice(n : Int) : Int = Extra.double(n)\n"},
                         {"old.ern", "export fn main() : Unit ="
                                     " Io.println(Int.toString(User.twice(1)))\n"},
                         {"extra.ern", "export fn double(n : Int) : Int = n * 2\n"}]],
    0 = ern_harness:built(["--build-root", Build, Source]),
    ok = file:delete(filename:join(Build, "extra.erc")),
    Main = filename:join(Build, "main.erc"),
    Old = filename:join(Build, "old.erc"),
    Run = fun(Words) -> finished([?ERN, " run ", Words, " 2>&1"]) end,
    Missing = "ern run: no module Extra, which User uses, on the load path",
    Rule = "; a node reads every module of its load path",
    ?assertEqual({0, "ran\n"}, Run(Main)),
    ?assertEqual({1, Missing ++ Rule ++ "\n"}, Run(["--config-dir ", Lone, " ", Main])),
    Bare = ern_harness:made(Base, "bare", 0),
    ?assertEqual({1, Missing ++ Rule ++ "\n"},
                 Run(["--config-dir ", Bare, " --load-path ", Build])),
    ?assertEqual({1, Missing ++ "\n"}, Run(Old)),
    ?assertEqual({1, Missing ++ "\n"}, Run(["--config-dir ", Lone, " ", Old])),
    [?assertNot(filelib:is_regular(filename:join(Node, "ernest.pid"))) || Node <- [Lone, Bare]].

%% report §11.2, §8.7: a file at a module's path that holds another module
%% is refused before anything runs, and a node, which reads every module of
%% its load path, names the file and the module it holds, not the module
%% missing at the path of the one it holds, with a node's advice: a build
%% root under the program's root where the file's path ends in the
%% segments of the module it holds, as guide/deployment.md's section 1.3
%% quotes it, and the removal alone where it does not; the same program run
%% as no node does not read the file, and runs. A regression test, written
%% after the fix (the release review found the node saying the
%% module the file holds was not on the load path)
misplaced_module_test_() ->
    ern_harness:nodes_test({waits, 5}, fun misplaced_module/1).

misplaced_module(Base) ->
    Lone = ern_harness:made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join(Source, "extra.ern"),
                         "export fn double(n : Int) : Int = n * 2\n"),
    0 = ern_harness:built(["--build-root", Build, Source]),
    Moved = filename:join(Build, "moved.erc"),
    ok = file:rename(filename:join(Build, "extra.erc"), Moved),
    Main = filename:join(Build, "main.erc"),
    Run = fun(Words) -> finished([?ERN, " run ", Words, " 2>&1"]) end,
    ?assertEqual({0, "ran\n"}, Run(Main)),
    Refusal = "ern run: " ++ ern_build:shown(Moved) ++ " holds Extra, not Moved; remove it\n",
    ?assertEqual({1, Refusal}, Run(["--config-dir ", Lone, " ", Main])),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))),
    ok = file:delete(Moved),
    %% the guide's own program: a counter whose old build stands under old/
    %% beneath the program's root, the node run from the base
    ok = file:write_file(filename:join(Source, "counter.ern"),
                         "export fn next(n : Int) : Int = n + 1\n"),
    0 = ern_harness:built(["--build-root", Build, Source]),
    ok = filelib:ensure_path(filename:join(Build, "old")),
    {ok, _} = file:copy(filename:join(Build, "counter.erc"),
                        filename:join([Build, "old", "counter.erc"])),
    {ok, Guide} = file:read_file("../guide/deployment.md"),
    {match, [Quoted]} = re:run(Guide, "`(ern run: old/counter\\.erc holds [^`]*)`",
                               [{capture, all_but_first, list}]),
    ?assertEqual({1, Quoted ++ "\n"},
                 finished(["cd ", Build, " && ", ?ERN, " run --config-dir ", filename:absname(Lone),
                           " main.erc 2>&1"])).

%% report §11.2, §11.1, §8.7: a node, which reads every module of its load
%% path, refuses a `.erc` whose path from its root breaks §11.1's shape by
%% the component that breaks it, before anything runs: a directory that is
%% not lowercase, which would otherwise read as the namespace the file
%% holds, and one that is no words joined by `_`. A regression test,
%% written after the fix (the full review found the first
%% refused as a module missing at its own path and the second as a file
%% holding another module); it does not cover a file's own name, which
%% the program's own load refuses the same way.
misshapen_load_path_test_() ->
    ern_harness:nodes_test({waits, 3}, fun misshapen_load_path/1).

misshapen_load_path(Base) ->
    Lone = ern_harness:made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(filename:join(Source, "net")),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join([Source, "net", "http.ern"]),
                         "export fn double(n : Int) : Int = n * 2\n"),
    Build = filename:join(Base, "build"),
    0 = ern_harness:built(["--build-root", Build, Source]),
    Main = filename:join(Build, "main.erc"),
    Http = filename:join([Build, "net", "http.erc"]),
    Upper = filename:join([Base, "upper", "Net", "http.erc"]),
    Dashed = filename:join([Base, "dashed", "bad-dir", "x.erc"]),
    [begin
         ok = filelib:ensure_dir(File),
         {ok, _} = file:copy(Http, File)
     end || File <- [Upper, Dashed]],
    Run = fun(Root) ->
              finished([?ERN, " run --config-dir ", Lone, " --load-path ",
                        filename:join(Base, Root), " ", Main, " 2>&1"])
          end,
    ?assertEqual({1, "ern run: " ++ ern_build:shown(Upper)
                     ++ ": path component `Net` must be lowercase\n"},
                 Run("upper")),
    ?assertEqual({1, "ern run: " ++ ern_build:shown(Dashed)
                     ++ ": path component `bad-dir` must be words joined by `_`, each a lowercase"
                        " letter, then lowercase letters and digits; a module of several words is"
                        " `word_count.ern`\n"},
                 Run("dashed")),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §11, §11.2, §8.7: a node, which reads every module of its load
%% path at its start, is refused where it cannot read one, with the host's
%% reason, and so where one reaches a named pipe, which it does not open,
%% `is no regular file`; a directory named as a `.erc` is walked, and the
%% program runs. It assumes a user the file's mode binds, which root is
%% not, and does not cover a device, a socket, or a pipe under a named
%% package's build
unopened_load_path_test_() ->
    ern_harness:nodes_test({waits, 4}, fun unopened_load_path/1).

unopened_load_path(Base) ->
    Lone = ern_harness:made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    Build = filename:join(Base, "build"),
    0 = ern_harness:built(["--build-root", Build, Source]),
    Pipes = filename:join(Base, "pipes"),
    ok = filelib:ensure_path(filename:join(Pipes, "walked.erc")),
    Run = fun() ->
              finished([?ERN, " run --config-dir ", Lone, " --load-path ", Pipes, " ",
                        filename:join(Build, "main.erc"), " 2>&1"])
          end,
    ?assertEqual({0, "ran\n"}, Run()),
    Closed = filename:join(Pipes, "closed.erc"),
    {ok, _} = file:copy(filename:join(Build, "main.erc"), Closed),
    ok = file:change_mode(Closed, 8#000),
    ?assertEqual({1, "ern run: " ++ ern_build:shown(Closed) ++ ": permission denied\n"}, Run()),
    ok = file:delete(Closed),
    Pipe = filename:join(Pipes, "x.erc"),
    "" = os:cmd("mkfifo " ++ Pipe),
    ?assertEqual({1, "ern run: " ++ ern_build:shown(Pipe) ++ ": is no regular file\n"}, Run()),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §11.2, §8.7: a node, which reads every module of its load path,
%% refuses before anything runs a program whose root holds a current
%% compiled form of a program's Time, which hides the library Time that the
%% library Http uses, though the program uses no library, naming the form
%% found; so does a bare node whose `--load-path` root holds it. The same
%% program run as no node does not read the form, and runs. A regression
%% test, written after the code; it does not cover a form a node finds
%% under `--libs-dir`, nor `ern test` or `ern shell` given `--config-dir`
hiding_a_library_test_() ->
    ern_harness:nodes_test({waits, 4}, fun hiding_a_library/1).

hiding_a_library(Base) ->
    Lone = ern_harness:made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    0 = ern_harness:built(["--build-root", Build, Source]),
    Time = current_time(Build),
    Main = filename:join(Build, "main.erc"),
    Run = fun(Words) -> finished([?ERN, " run ", Words, " 2>&1"]) end,
    ?assertEqual({0, "ran\n"}, Run(Main)),
    Refusal = "ern run: " ++ ern_build:shown(Time) ++ ": Time hides the library Time, which the"
        " library Http uses; give time another name\n",
    ?assertEqual({1, Refusal}, Run(["--config-dir ", Lone, " ", Main])),
    Bare = ern_harness:made(Base, "bare", ern_harness:free_port()),
    ?assertEqual({1, Refusal}, Run(["--config-dir ", Bare, " --load-path ", Build])),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))),
    ?assertNot(filelib:is_regular(filename:join(Bare, "ernest.pid"))).

%% A program's compiled form of Time under Root, beside its source, written
%% as a build of the toolchain that held no module to the refusal of one
%% that hides a library's would have left it, and found current: compiled
%% in memory as `ern build` compiles a module (ern_build:compiled_in_order/3),
%% the refusal being the job's and no part of the compile.
current_time(Root) ->
    Source = filename:join(Root, "time.ern"),
    ok = file:write_file(Source, "export fn mine() : String = \"mine\"\n"),
    SourceRoot = ern_build:absolute(Root),
    Order = ern_build:compile_order([ern_build:module_of(ern_build:absolute(Source), SourceRoot)],
                                    SourceRoot, ern_build:load_path_of([SourceRoot])),
    {[], #{['Time'] := Beam}} = ern_build:compiled_in_order(Order, SourceRoot, SourceRoot),
    Erc = filename:join(Root, "time.erc"),
    ok = file:write_file(Erc, Beam),
    Erc.

%% report §8.7, §11.2, §11.3: a node started by `ern test` with a relative
%% `--config-dir` reads its configuration from that directory as it was
%% named from where the job started, so that `ern reload --config-dir`
%% from there, sent while a doc example runs in a directory of its own, is
%% read and not refused. The example waits on a line of standard input,
%% which the test writes once the reload has been said. A regression test,
%% written after the fix (the full review found the node
%% reading the example's directory); it does not cover a test's case,
%% which runs where the job started.
reload_in_example_test_() ->
    ern_harness:nodes_test({waits, 6}, fun reload_in_example/1).

reload_in_example(Base) ->
    Node = ern_harness:made(Base, "node", none),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "slow.ern"),
                         ["/// What the test types, once it has reloaded the node.\n"
                          "///\n"
                          "/// ```ernest\n"
                          "/// let _ = Io.println(\"waiting\");\n"
                          "/// Slow.typed()\n"
                          "/// // => Some(\"go\")\n"
                          "/// ```\n"
                          "export fn typed() : Optional(String) = Io.readLine()\n"]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    {Input, Wait} = ern_harness:launched(Node, ["cd ", Base, " && ", ?ERN,
                                                " test --config-dir node build/slow.erc"]),
    ern_harness:prints(Node, "waiting"),
    ?assertEqual({0, ""}, finished(["cd ", Base, " && ", ?ERN, " reload --config-dir node 2>&1"])),
    ern_harness:says(Node, "ernest.conf was read again"),
    true = port_command(Input, "go\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_harness:said(Node),
    ern_harness:has(Out, "Slow.typed example 1: passed"),
    ?assertEqual(nomatch, string:find(Err, "refused")).

%% report §12.5, Appendix C: a node holds the limits `limits` names, each
%% the least power of two at or above the number given, as its host boots;
%% a reload of a changed `limits` is not refused, changes nothing and says
%% that the change holds from the node's next start, and that start holds
%% the new limits; with the section left out the node holds the host's
%% own, a bare `erl`'s; and a number out of range refuses the start,
%% naming the file and the rule. The
%% program answers each line of its standard input with the host's limits,
%% read through a `foreign fn` of the host's, and ends at `end`. A
%% regression test, written after the code; it does not cover `ern test`
%% and `ern shell`, whose first start answers the same flags
%% (ern_cli_tests' node_limit_flags_test), nor a spawn or a port beyond a
%% limit
limits_test_() ->
    ern_harness:nodes_test({waits, 14}, fun limits/1).

limits(Base) ->
    Node = ern_harness:made(Base, "node", none),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "limits.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// Each line of standard input answered with the host's limits, until `end`.
export fn main() : Unit =
    match Io.readLine() {
        Some(\"end\") -> Unit
      | Some(_) -> {
            Io.println(Io.show(#(systemInfo(Foreign.atom(\"process_limit\")),
                                 systemInfo(Foreign.atom(\"port_limit\")))));
            main()
        }
      | None -> Unit
    }
">>),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    Program = filename:join([Base, "build", "limits.erc"]),
    Limits = fun(Given) -> ern_harness:edit(Node,
                                            fun(Conf) -> Conf#{<<"limits">> => Given} end) end,
    Limits(#{<<"processes">> => 50000, <<"ports">> => 4097}),
    {Input, Wait} = ern_harness:started(Node, Program, []),
    true = port_command(Input, "limits\n"),
    ern_harness:prints(Node, "#(65536, 8192)\n"),
    Limits(#{<<"processes">> => 2000, <<"ports">> => 2000}),
    ?assertMatch({0, _}, signaled("reload", Node)),
    ern_harness:says(Node, "ernest.conf was read again"),
    ern_harness:says(Node, "the change to limits holds from the node's next start"),
    true = port_command(Input, "limits\nend\n"),
    ern_harness:prints(Node, "#(65536, 8192)\n", 2, ?WAIT_MS),
    ?assertEqual(0, Wait()),
    {_, Err} = ern_harness:said(Node),
    ?assertEqual(nomatch, string:find(Err, "refused")),
    {Again, WaitAgain} = ern_harness:started(Node, Program, []),
    true = port_command(Again, "limits\nend\n"),
    ern_harness:prints(Node, "#(2048, 2048)\n"),
    ?assertEqual(0, WaitAgain()),
    ern_harness:edit(Node, fun(Conf) -> maps:remove(<<"limits">>, Conf) end),
    {0, Own} = finished("env -u ERL_AFLAGS -u ERL_FLAGS -u ERL_ZFLAGS erl -noshell -eval"
                        " 'io:format(\"#(~B, ~B)~n\", [erlang:system_info(process_limit),"
                        " erlang:system_info(port_limit)]), halt().'"),
    {Unlimited, WaitUnlimited} = ern_harness:started(Node, Program, []),
    true = port_command(Unlimited, "limits\nend\n"),
    ern_harness:prints(Node, Own),
    ?assertEqual(0, WaitUnlimited()),
    Limits(#{<<"processes">> => 1000}),
    ?assertEqual({1, "ern run: " ++ ern_build:shown(filename:join(Node, "ernest.conf"))
                     ++ ": limits' processes is not a whole number from 1024 to 67108864\n"},
                 finished([?ERN, " run --config-dir ", Node, " ", Program, " 2>&1"])).

%% report §12.5, Appendix E.23, E.18: at a full table of ports, which a
%% node's `limits` makes small, `Tcp.listen` answers the host's refusal,
%% and `Tcp.connect`, `Tcp.accept`, `Os.start`, `Os.startTerminal` and
%% `Os.run` answer it in the same words, `Left(Other("a system limit was
%% hit, probably not enough ports"))`; listeners closed and ended give
%% their ports back, and the next connect, accept and run open theirs.
%% A regression test, written after the fix: `Os.start` took the host's
%% refusal for its helper's failure, and faulted; `Tcp.connect` and
%% `Tcp.accept` written after the code. It does not cover a read of
%% standard input there, nor the terminal's subscription
full_port_table_test_() ->
    ern_harness:nodes_test({waits, 4}, fun full_port_table/1).

full_port_table(Base) ->
    Node = ern_harness:made(Base, "node", none),
    ern_harness:edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"ports">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "full.ern"), [<<"
// Listeners opened until the host refuses one, which is said, each kept, so
// that the node's table of ports stays full.
fn filled(listeners : List(Address(Tcp.ListenerMsg))) : List(Address(Tcp.ListenerMsg)) =
    match Tcp.listen(\"127.0.0.1\", 0) {
        Right(listener) -> filled(listener :: listeners)
      | Left(error) -> {
            Io.println(\"listen: \" <> Io.show(error));
            listeners
        }
    }

// What a start answered, its program's process left out.
fn started(answer : Either(Io.Error, Address(Os.ProgramMsg))) : Either(Io.Error, Unit) =
    Either.map(answer, fn(_) = Unit)

// What a run answered, its program's status alone.
fn ran(answer : Either(Io.Error, Os.Finished)) : Either(Io.Error, Int) =
    Either.map(answer, fn(finished) = finished.status)

// The listener closed and its end waited for, which gives its port back.
fn closed(listener : Address(Tcp.ListenerMsg)) : Unit receiving Down = {
    monitor(Process.fromAddress(listener), fn(down) = down);
    Tcp.closeListener(listener);
    receive { _ -> Unit }
}

// What an open answered, its socket left out.
fn opened(answer : Either(Io.Error, Address(Tcp.SocketMsg))) : Either(Io.Error, Unit) =
    Either.map(answer, fn(_) = Unit)

// A connection to the door, which waits there to be accepted, made before
// the table is full, and then the requests at the full table.
fn knocked(door : Address(Tcp.ListenerMsg), port : Int) : Unit receiving Down = {
    Io.println(\"client: \" <> Io.show(opened(Tcp.connect(\"127.0.0.1\", port, waitMs()))));
    let listeners = filled([]);
    Io.println(\"connect: \" <> Io.show(opened(Tcp.connect(\"127.0.0.1\", port, waitMs()))));
    Io.println(\"accept: \" <> Io.show(opened(Tcp.accept(door, waitMs()))));
    let command = Os.command(\"true\", []);
    Io.println(\"start: \" <> Io.show(started(Os.start(command))));
    let size = Terminal.Size(rows = 24, columns = 80);
    Io.println(\"startTerminal: \" <> Io.show(started(Os.startTerminal(command, size))));
    Io.println(\"run: \" <> Io.show(ran(Os.run(command, waitMs()))));
    match listeners {
        first :: second :: third :: _ -> {
            closed(first);
            closed(second);
            closed(third);
            Io.println(\"after a close: \"
                       <> Io.show(opened(Tcp.connect(\"127.0.0.1\", port, waitMs()))));
            Io.println(\"after a close: \" <> Io.show(opened(Tcp.accept(door, waitMs()))));
            Io.println(\"after a close: \" <> Io.show(ran(Os.run(command, waitMs()))))
        }
      | _ -> Unit
    }
}

export fn main() : Unit receiving Down =
    match Tcp.listen(\"127.0.0.1\", 0) {
        Right(door) -> match Tcp.port(door) {
            Right(port) -> knocked(door, port)
          | Left(error) -> Io.println(Io.show(error))
        }
      | Left(error) -> Io.println(Io.show(error))
    }
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    Wait = ern_harness:start(Node, filename:join([Base, "build", "full.erc"]), []),
    ern_harness:prints(Node, "after a close: Right(0)\n"),
    ?assertEqual(0, Wait()),
    {Out, _} = ern_harness:said(Node),
    Refused = "Io.Other(\"a system limit was hit, probably not enough ports\")",
    ?assertEqual(["client: Right(Unit)", "listen: " ++ Refused,
                  "connect: Left(" ++ Refused ++ ")", "accept: Left(" ++ Refused ++ ")",
                  "start: Left(" ++ Refused ++ ")", "startTerminal: Left(" ++ Refused ++ ")",
                  "run: Left(" ++ Refused ++ ")", "after a close: Right(Unit)",
                  "after a close: Right(Unit)", "after a close: Right(0)", ""],
                 string:split(Out, "\n", all)).

%% report §7.4, §12.1, §12.5: at a full table of ports, a read of standard
%% input, which opens the input for the read alone, faults its reader with
%% `Fault("error:system_limit")`, and standard input lives on: once a
%% listener is closed and ended, giving its port back, the next read takes
%% the line the first could not. A regression test, written after the fix:
%% the standard input's process died of the host's `system_limit`. It does
%% not cover a read of bytes, which opens the input as a line's does, nor
%% the keys, the terminal's tests'
full_port_table_input_test_() ->
    ern_harness:nodes_test({waits, 3}, fun full_port_table_input/1).

full_port_table_input(Base) ->
    Node = ern_harness:made(Base, "node", none),
    ern_harness:edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"ports">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "input.ern"), <<"
// Listeners opened until the host refuses one, each kept, so that the
// node's table of ports stays full.
fn filled(listeners : List(Address(Tcp.ListenerMsg))) : List(Address(Tcp.ListenerMsg)) =
    match Tcp.listen(\"127.0.0.1\", 0) {
        Right(listener) -> filled(listener :: listeners)
      | Left(_) -> listeners
    }

// The listener closed and its end waited for, which gives its port back.
fn closed(listener : Address(Tcp.ListenerMsg)) : Unit receiving Down = {
    monitor(Process.fromAddress(listener), fn(down) = down);
    Tcp.closeListener(listener);
    receive { _ -> Unit }
}

// A line of standard input read and said.
fn read() : Unit = Io.println(\"read: \" <> Io.show(Io.readLine()))

export fn main() : Unit receiving Down = {
    let listeners = filled([]);
    let _ = spawnMonitored(fn() = read(), fn(down) = down);
    receive {
        Down(process = _, =reason, site = _) -> Io.println(\"reader: \" <> Io.show(reason))
    };
    match listeners {
        listener :: _ -> {
            closed(listener);
            read()
        }
      | [] -> Unit
    }
}
">>),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    {Input, Wait} = ern_harness:started(Node, filename:join([Base, "build", "input.erc"]), []),
    true = port_command(Input, "first\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_harness:said(Node),
    ?assertEqual(["reader: Fault(\"error:system_limit\")", "read: Some(\"first\")", ""],
                 string:split(Out, "\n", all)),
    ern_harness:has(Err, "the process of Input.main:22 faulted: error:system_limit").

%% report §7.4, §12.5, §7.3: at a full table of processes, which a node's
%% `limits` makes small, the process that took a request lives on: the
%% reaper's spawn, and the clock's delivery of an alarm, whose recipient
%% faults at its wait, fault with `Fault("error:system_limit")`, and the
%% per-request processes of `Fs`, `Tcp` and `Os` answer
%% `Left(Other("error:system_limit"))`. A probe takes each step at the
%% full table, asking the entry process for it, and where it faults
%% `restarting` runs it again in the same process, so that the table stays
%% full; each kind is asked twice, the process that took it answering
%% again. Report §10, §12.9: a `kill` is a message to a process of the
%% runtime's own, there from the run's start, and needs no room, so a kill
%% at the full table makes room, and once the killed process has ended,
%% which a call on it shows, a spawn takes its place.
%%
%% Report §8.6, §11.2: a program that fills its table and faults ends with
%% its fault reported, its end telling its subscriber of
%% `Os.subscribeTermination` by a delivery that cannot be made, so that the
%% subscriber faults and is waited for no longer. Report §12.1: the host's
%% own report of each spawn refused is not written, the fault's line saying
%% it. Report §8.4, §7.4: an address given to foreign code at the full
%% table, whose checker cannot be made, faults the process that gives it
%% with the host's class and reason, the foreign function not having run.
%%
%% A regression test, written after the fix: the reaper and the system
%% processes died of the host's `system_limit`, and the node hung; a kill
%% faulted where the table was full; and the checker's refusal was said as
%% the foreign function's raise. The answers of `Fs`, `Tcp` and `Os` are
%% a regression test too, written after the code, which faulted. It does
%% not cover a listener's accept, whose worker is made as a connect's is, a
%% process kept for an adapted address, which needs a peer, the terminal's
%% subscription, or a deadlock at a full table, which a node does not look
%% for
full_process_table_test_() ->
    ern_harness:nodes_test({waits, 5}, fun full_process_table/1).

full_process_table(Base) ->
    Node = ern_harness:made(Base, "node", none),
    ern_harness:edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "full.ern"), [<<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// What the probe asks the entry process: the step its run is to take.
type StepMsg = Next(Reply(Int))

// What a held process takes, a call it never answers.
type HeldMsg = Hold(Reply(Unit))

// The steps the probe takes at the full table, each kind of request twice
// and then a kill.
let steps : Int = 13

// The table filled once the probe waits for its first step, and each step
// answered in turn.
export fn main() : Unit receiving StepMsg = {
    let entry = self();
    let held = spawn(fn() = holding());
    let _ = spawn(restarting(Unlimited, fn() = probed(entry, held)));
    filled(systemInfo(Foreign.atom(\"process_limit\"))
           - systemInfo(Foreign.atom(\"process_count\")));
    stepped(0)
}

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// A process that answers no call, until it is killed.
fn holding() : Unit receiving HeldMsg = receive { Hold(_) -> holding() }

// Each step the probe asks for answered in turn, the last past the steps,
// which ends the probe.
fn stepped(next : Int) : Unit receiving StepMsg =
    receive {
        Next(reply) -> {
            answer(reply, next);
            if next < steps then stepped(next + 1) else Unit
        }
    }

// A run of the probe: each step the entry process names, said and taken.
fn probed(entry : Address(StepMsg), held : Address(HeldMsg)) : Unit receiving Int =
    match Address.call(entry, Next, waitMs()) {
        Some(step) ->
            if step < steps then {
                Io.println(\"step \" <> Int.toString(step));
                requested(step, held);
                probed(entry, held)
            } else
                Unit
      | None -> Io.println(\"no step\")
    }

// A step's request, each needing a process the runtime makes, but the
// kill; its answer printed where it does not fault.
fn requested(step : Int, held : Address(HeldMsg)) : Unit receiving Int =
    match step / 2 {
        0 -> Io.println(Io.show(spawn(fn() = Unit)))
      | 1 -> Io.println(Io.show(Fs.read(Path(\"full.txt\"), waitMs())))
      | 2 -> Io.println(Io.show(Tcp.connect(\"127.0.0.1\", 1, waitMs())))
      | 3 -> Io.println(Io.show(Tcp.listen(\"127.0.0.1\", 0)))
      | 4 -> Io.println(Io.show(Os.start(Os.command(\"true\", []))))
      | 5 -> {
            let _ = Clock.alarm(0, fn(time) = time);
            receive { time -> Io.println(Int.toString(time)) }
        }
      | _ -> {
            kill(Process.fromAddress(held));
            Io.println(\"after the kill: \" <> Io.show(Address.call(held, Hold, waitMs())));
            let _ = spawn(fn() = waited());
            Io.println(\"spawned\")
        }
    }
">>, ern_harness:wait_ms_declaration()]),
    ok = file:write_file(filename:join(Source, "ending.ern"), <<"
// The subscriber of the program's end, which answers once told.
fn subscribed() : Unit receiving Reply(Unit) = {
    Os.subscribeTermination(fn(reply) = reply);
    receive { reply -> answer(reply, Unit) }
}

// Processes spawned until the host refuses one, each waiting, which faults
// the entry process.
fn filled() : Unit = {
    let _ = spawn(fn() = waited());
    filled()
}

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

export fn main() : Unit = {
    let _ = spawn(fn() = subscribed());
    filled()
}
">>),
    ok = file:write_file(filename:join(Source, "checker.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"
foreign fn isPid(address : Address(Int)) : Bool = \"erlang:is_pid/1\"

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// An address given to foreign code once the table is full.
export fn main() : Unit = {
    let target = spawn(fn() = waited());
    filled(systemInfo(Foreign.atom(\"process_limit\"))
           - systemInfo(Foreign.atom(\"process_count\")));
    Io.println(Io.show(isPid(target)))
}
">>),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    ?assertEqual(0, (ern_harness:start(Node, filename:join([Base, "build", "full.erc"]), []))()),
    {Out, Err} = ern_harness:said(Node),
    Limited = "Left(Io.Other(\"error:system_limit\"))",
    ?assertEqual(lists:append([["step " ++ integer_to_list(Step)]
                               ++ [Limited || Step >= 2, Step =< 9]
                               || Step <- lists:seq(0, 12)])
                 ++ ["after the kill: None", "spawned", ""],
                 string:split(Out, "\n", all)),
    Faults = [Line || Line <- string:split(Err, "\n", all),
                      string:find(Line, "faulted") =/= nomatch],
    ?assertEqual(lists:duplicate(4, "Full.main:19 faulted, restarted: error:system_limit"),
                 [string:find(Line, "Full.") || Line <- Faults]),
    ?assertEqual(nomatch, string:find(Err, "Too many processes")),
    ?assertEqual({1, ["Ending.main faulted: error:system_limit",
                      "the end waits for 1 subscriber: Ending.main:19",
                      "the process of Ending.main:19 faulted: error:system_limit",
                      "the subscriber Ending.main:19 ended without answering"]},
                 lines_said(finished([?ERN, " run --config-dir ", Node, " ",
                                      filename:join([Base, "build", "ending.erc"]), " 2>&1"]))),
    ?assertEqual({1, ["Checker.main faulted: error:system_limit"]},
                 lines_said(finished([?ERN, " run --config-dir ", Node, " ",
                                      filename:join([Base, "build", "checker.erc"]), " 2>&1"]))).

%% report Appendix E.18, §7.4, §12.5: a socket closed at a table of
%% processes its program filled lingers over what it has not sent, its
%% closer made once its writer has ended, in the writer's room, so that a
%% far end that reads takes every byte and then the close.
%%
%% A regression test, written after the code, of the close at a full table.
%% It does not cover the reset where another process takes the writer's
%% room before the closer is made, which no program can time, nor the
%% linger's bounds at a full table, which ern_tcp_tests holds with room.
%% The far end is told to read before the close, which answers once the
%% bytes are sent; a run in which it took every byte before the close
%% holds only that the close answers
full_table_close_lingers_test_() ->
    ern_harness:nodes_test({waits, 2}, fun full_table_close_lingers/1).

full_table_close_lingers(Base) ->
    Node = ern_harness:made(Base, "node", none),
    ern_harness:edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "closer.ern"), [<<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// What the reader is told: to read what came.
type ReaderMsg = Go

// The bytes the server writes before it closes.
let size : Int = 4000000

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// The bytes read until the connection ends, and how it ended.
fn counted(socket : Address(Tcp.SocketMsg), taken : Int) : #(Int, Io.Error) =
    match Tcp.read(socket, waitMs()) {
        Right(bytes) -> counted(socket, taken + Bytes.size(bytes))
      | Left(error) -> #(taken, error)
    }

// The far end, which reads once told, and says what it took.
fn reader(port : Int) : Unit receiving ReaderMsg =
    match Tcp.connect(\"127.0.0.1\", port, waitMs()) {
        Right(socket) -> receive {
            Go -> {
                let #(taken, error) = counted(socket, 0);
                Io.println(\"taken \" <> Int.toString(taken) <> \", then \" <> Io.show(error))
            }
        }
      | Left(error) -> Io.println(\"connect: \" <> Io.show(error))
    }

// The server writes more than the far end's buffers hold, fills the
// table, tells the far end to read, and closes.
// The close returns once the bytes are sent, so the far end is told first.
export fn main() : Unit receiving Down =
    match Tcp.listen(\"127.0.0.1\", 0) {
        Right(door) -> match Tcp.port(door) {
            Right(port) -> {
                let far = spawn(fn() = reader(port));
                monitor(Process.fromAddress(far), fn(down) = down);
                match Tcp.accept(door, waitMs()) {
                    Right(socket) -> {
                        let _ = Tcp.write(socket, Bytes.repeat(<<65>>, size), waitMs());
                        filled(systemInfo(Foreign.atom(\"process_limit\"))
                               - systemInfo(Foreign.atom(\"process_count\")));
                        send(far, Go);
                        Tcp.close(socket);
                        receive { _ -> Unit }
                    }
                  | Left(error) -> Io.println(\"accept: \" <> Io.show(error))
                }
            }
          | Left(error) -> Io.println(Io.show(error))
        }
      | Left(error) -> Io.println(Io.show(error))
    }
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    ?assertEqual({0, ["taken 4000000, then Io.Closed"]},
                 lines_said(finished([?ERN, " run --config-dir ", Node, " ",
                                      filename:join([Base, "build", "closer.erc"]), " 2>&1"]))).

%% report §7.4, §12.5, Appendix E.18: a request over TLS at a full table of
%% processes, which leaves room for its own worker but not for the host's
%% TLS, answers `Left(Other("error:system_limit"))`, the host's own
%% reports not written: a `connectTls`, whose connection's processes
%% the host's TLS cannot start, an `accept` on a listener over TLS, which
%% starts them as it takes the connection, and a `listenTls` after the
%% first, whose listener's trackers it cannot start. Each run leaves one,
%% two or three processes free, which reach the host's start in turn.
%%
%% A regression test, written after the fix: each such request waited for
%% ever, its worker ended by the host's raise unanswered; the answer is a
%% regression test too, written after the code, which faulted. It does not cover
%% a run's first request over TLS at a full table, which starts the host's
%% TLS there (docs/otp_bugs.md, 17), nor a handshake, which over TLS 1.2 and 1.3
%% makes no process once the connection's are made
tls_at_a_full_table_test_() ->
    ern_harness:nodes_test({waits, 9}, fun tls_at_a_full_table/1).

tls_at_a_full_table(Base) ->
    #{server := {Certificate, Key}} = ern_tcp_tests:pki(),
    {Server, ServerPort} = tls_server(Certificate, Key),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "full_tls.ern"), [<<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// The run's argument at the index as a number, 0 where it is none.
fn number(index : Int) : Int =
    Optional.withDefault(Optional.andThen(List.get(Os.arguments, index), String.toInt), 0)

// The run's argument at the index as a path.
fn path(index : Int) : Path = Path(Optional.withDefault(List.get(Os.arguments, index), \"\"))

// A listener over TLS, which starts the host's TLS, then the request the
// first argument names at the full table.
export fn main() : Unit =
    match Tcp.listenTls(\"127.0.0.1\", 0, path(3), path(4)) {
        Right(door) -> match Tcp.port(door) {
            Right(port) -> requested(door, port)
          | Left(error) -> Io.println(\"port: \" <> Io.show(error))
        }
      | Left(error) -> Io.println(\"listenTls: \" <> Io.show(error))
    }

// A connection to the door made, then the table filled but for the
// second argument's count, then the request: a connect to the port the
// third argument names, the accept of that connection, or a listen. What
// it answers is said where it does not fault.
fn requested(door : Address(Tcp.ListenerMsg), port : Int) : Unit = {
    let _ = Tcp.connect(\"127.0.0.1\", port, waitMs());
    filled(room() - number(1));
    match List.get(Os.arguments, 0) {
        Some(\"connect\") ->
            Io.println(Io.show(Tcp.connectTls(\"127.0.0.1\", number(2), Tcp.Unverified, waitMs())))
      | Some(\"accept\") -> Io.println(Io.show(Tcp.accept(door, waitMs())))
      | _ -> Io.println(Io.show(Tcp.listenTls(\"127.0.0.1\", 0, path(3), path(4))))
    }
}
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    Program = filename:join([Base, "build", "full_tls.erc"]),
    Cases = [{Request, Free} || Request <- ["connect", "accept"], Free <- [1, 2, 3]]
        ++ [{"listen", Free} || Free <- [1, 2]],
    Runs = [begin
                Node = ern_harness:made(Base, Request ++ integer_to_list(Free), none),
                ern_harness:edit(Node, fun(Conf) ->
                                           Conf#{<<"limits">> => #{<<"processes">> => 1024}}
                                       end),
                {Request, Free,
                 begun([?ERN, " run --config-dir ", Node, " ", Program, " ", Request, " ",
                        integer_to_list(Free), " ", integer_to_list(ServerPort), " ",
                        Certificate, " ", Key, " 2>&1"])}
            end || {Request, Free} <- Cases],
    try
        [?assertEqual({Request, Free, {0, ["Left(Io.Other(\"error:system_limit\"))"]}},
                      {Request, Free, lines_said(Run())})
         || {Request, Free, Run} <- Runs]
    after
        exit(Server, kill)
    end.

%% report §7.4, §12.5, Appendix E.23: a start at a table of processes with
%% room for the program's process but not for its writer answers
%% `Left(Other("error:system_limit"))`, as a start whose process cannot be
%% made does (full_process_table_test_), and with room for both it starts.
%% A regression test, written with the code: the code before made no
%% writer, and a start with room for one process started
start_at_a_full_table_test_() ->
    ern_harness:nodes_test({waits, 3}, fun start_at_a_full_table/1).

start_at_a_full_table(Base) ->
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "full_start.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// The table filled but for the run's argument's count, then a start.
export fn main() : Unit = {
    filled(room() - Optional.withDefault(Optional.andThen(List.get(Os.arguments, 0),
                                                          String.toInt), 0));
    match Os.start(Os.command(\"true\", [])) {
        Right(_) -> Io.println(\"started\")
      | Left(error) -> Io.println(Io.show(error))
    }
}
">>),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    Program = filename:join([Base, "build", "full_start.erc"]),
    Runs = [begin
                Node = ern_harness:made(Base, "free" ++ integer_to_list(Free), none),
                ern_harness:edit(Node, fun(Conf) ->
                                           Conf#{<<"limits">> => #{<<"processes">> => 1024}}
                                       end),
                {Free, begun([?ERN, " run --config-dir ", Node, " ", Program, " ",
                              integer_to_list(Free), " 2>&1"])}
            end || Free <- [1, 2]],
    ?assertEqual([{1, {0, ["Io.Other(\"error:system_limit\")"]}}, {2, {0, ["started"]}}],
                 [{Free, lines_said(Run())} || {Free, Run} <- Runs]).

%% report Appendix E.21, §10, §12.5: a subscriber to faults is given each
%% report at a full table of processes, through its subscription's courier,
%% made with the subscription: a process under `restarting` that fills the
%% table and faults past it, keeping the table full as it restarts, is
%% reported twice as restarted and once as ended, each in turn.
%%
%% A regression test, written after the code, whose delivery of each report
%% was a process of its own, which the full table refused, faulting the
%% subscriber at its wait. It does not cover a wrap that does not finish,
%% which delays its subscriber's reports alone
fault_reports_at_a_full_table_test_() ->
    ern_harness:nodes_test({waits, 2}, fun fault_reports_at_a_full_table/1).

fault_reports_at_a_full_table(Base) ->
    Node = ern_harness:made(Base, "node", none),
    ern_harness:edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "reports.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// The table filled, then one spawn past it, which faults.
fn overfilled() : Unit = {
    filled(room());
    let _ = spawn(fn() = waited());
    Unit
}

// Each report said as it comes, until the one that ended the process.
fn said() : Unit receiving Process.FaultReport =
    receive {
        report -> {
            Io.println(report.cause <> \", restarted \" <> Io.show(report.restarted));
            if report.restarted then said() else Unit
        }
    }

export fn main() : Unit receiving Process.FaultReport = {
    Process.subscribeFaults(fn(report) = report);
    let _ = spawn(restarting(RestartLimit(restarts = 2, within = 60000), fn() = overfilled()));
    said()
}
">>),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    {0, Lines} = lines_said(finished([?ERN, " run --config-dir ", Node, " ",
                                      filename:join([Base, "build", "reports.erc"]),
                                      " 2> /dev/null"])),
    ?assertEqual(["error:system_limit, restarted true", "error:system_limit, restarted true",
                  "error:system_limit, restarted false"], Lines).

%% report §12.5, §11.8: a node whose table of processes is full ends when
%% it dials a peer: `c`, a node of 1024 processes connected to `a`, fills
%% its table and asks `b` how busy it is, and ends with status 1, the
%% host's line written to standard error after the node's own lines. Its
%% program may answer the dial as at a loss and the node may say that it
%% lost `a` before the end, and `a` says that it lost `c`.
%%
%% A regression test, written after the code, which wrote the host's
%% reports of the refused spawn and of the host's end to standard output,
%% and said that the node lost itself; under load the job's own end then
%% raced the host's, and ended with 0, or with 70 or an error on standard
%% output at a process of the host's already gone. It does not cover a
%% dial with room to begin and none to serve its connection, which
%% ern_tls_dist closes (*What it says*).
dial_from_a_full_table_test_() ->
    ern_harness:nodes_test({waits, 7}, fun dial_from_a_full_table/1).

dial_from_a_full_table(Base) ->
    A = ern_harness:made(Base, "a", 0),
    B = ern_harness:made(Base, "b", 0),
    C = ern_harness:made(Base, "c", none),
    ern_harness:lists(A, [{"c", C, none}]),
    ern_harness:lists(B, [{"c", C, none}]),
    WaitA = ern_harness:bare_started(A, []),
    WaitB = ern_harness:bare_started(B, []),
    ern_harness:lists(C,
                      [{"a", A, ern_harness:bound_port(A)}, {"b", B, ern_harness:bound_port(B)}]),
    ern_harness:edit(C, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "dial.ern"), [<<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// Count processes spawned, each waiting for ever.
fn filled(count : Int) : Unit =
    if count > 0 then {
        let _ = spawn(fn() = waited());
        filled(count - 1)
    } else
        Unit

// A process that waits for nothing that comes.
fn waited() : Unit receiving Int = receive { _ -> Unit }

// Whether the peer answered how busy it is.
fn asked(peer : String) : String =
    match Peer.utilization(peer, waitMs()) {
        Right(_) -> peer <> \" answered\"
      | Left(error) -> peer <> \": \" <> Io.show(error)
    }

export fn main() : Unit = {
    Io.println(asked(\"a\"));
    filled(room());
    Io.println(\"full\");
    Io.println(asked(\"b\"))
}
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    {Status, Said} = finished([?ERN, " run --config-dir ", C, " ",
                               filename:join([Base, "build", "dial.erc"]),
                               " 2> ", C, ".err"]),
    {ok, Err} = file:read_file(C ++ ".err"),
    ?assertEqual(1, Status),
    ?assert(lists:member(Said, ["a answered\nfull\n", "a answered\nfull\nb: Io.Unreachable\n"])),
    Host = "Kernel pid terminated (application_controller)"
           " (\"{application_terminated,kernel,shutdown}\")",
    Lines = string:trim(unstamped(binary_to_list(Err)), trailing),
    [Connected | Rest] = string:split(Lines, "\n", all),
    ?assertEqual("the peer a connected", Connected),
    ?assert(lists:member(Rest, [[Host], ["the peer a was lost: it closed", Host]])),
    ern_harness:says(A, "the peer c was lost"),
    ern_harness:stop(A, WaitA),
    ern_harness:stop(B, WaitB).

%% A server over TLS in the test's own host, at the port it answers, which
%% shakes hands with each connection in a process of its own, so that no
%% client holds up another, and closes it once the handshake ends.
tls_server(Certificate, Key) ->
    {ok, _} = application:ensure_all_started(ssl),
    {ok, Listener} = ssl:listen(0, [{certfile, Certificate}, {keyfile, Key}, {reuseaddr, true}]),
    {ok, {_, Port}} = ssl:sockname(Listener),
    Server = spawn(fun() -> receive go -> served(Listener) end end),
    ok = ssl:controlling_process(Listener, Server),
    Server ! go,
    {Server, Port}.

served(Listener) ->
    {ok, Socket} = ssl:transport_accept(Listener),
    Handshake = spawn(fun() ->
                          receive go -> ok end,
                          _ = ssl:handshake(Socket, infinity),
                          ssl:close(Socket)
                      end),
    ok = ssl:controlling_process(Socket, Handshake),
    Handshake ! go,
    served(Listener).

%% report §7.4, §12.5, Appendix E.27: a node whose table of processes is
%% full serves the peer connected before it filled: a spawn of a function
%% the node holds, which its reaper cannot start, and one of a function it
%% lacks, whose arrival the host's compiler cannot be started for, each
%% answers `Left(Other("error:system_limit"))`, and once room is made each
%% starts, the gateway, its worker for the peer and the exchange living
%% on. The host's own reports of the refused spawns are not written.
%%
%% A regression test, written after the fix: the exchange ended with the
%% host's term as it compiled an arrival, and no later spawn of a function
%% the store lacked was answered. It does not cover the worker for a peer,
%% made as its connection opens, at a connection that opens at a full
%% table, which the host's acceptor does not survive (docs/otp_bugs.md,
%% 12), nor the frames of a restart of a peer's process, whose wait needs
%% no process (ern_gateway_tests)
full_table_with_a_peer_test_() ->
    ern_harness:nodes_test({waits, 6}, fun full_table_with_a_peer/1).

full_table_with_a_peer(Base) ->
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    ern_harness:edit(Store, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "store.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// What the filler takes: the ask to fill the table, and the ask to free it.
export type FillMsg = Fill(Reply(Unit)) | Free(Reply(Unit))

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// A process that waits until it is told to end.
export fn waited() : Unit receiving Int = receive { _ -> Unit }

// Count processes spawned, each waiting, after those held.
fn filled(count : Int, held : List(Address(Int))) : List(Address(Int)) =
    if count > 0 then filled(count - 1, spawn(fn() = waited()) :: held) else held

// The filler: the table filled when asked, and the processes it filled it
// with ended when asked.
export fn filling(held : List(Address(Int))) : Unit receiving FillMsg =
    receive {
        Fill(reply) -> {
            let full = filled(room(), held);
            answer(reply, Unit);
            filling(full)
        }
      | Free(reply) -> {
            List.forEach(held, fn(process) = send(process, 0));
            answer(reply, Unit);
            filling([])
        }
    }

// The store waits until it is stopped.
export fn main() : Unit receiving Int = {
    Io.println(\"ready\");
    waited()
}
">>),
    ok = file:write_file(filename:join(Source, "desk.ern"), [<<"
// A spawn's answer, its address left out.
fn started(spawned : Either(Io.Error, Address(m))) : String =
    match spawned {
        Right(_) -> \"Right\"
      | Left(error) -> Io.show(error)
    }

// The spawns at the store's full table, one of a function the store holds
// and one of a function only the desk holds, and the same once the filler
// has made room.
export fn main() : Unit =
    match Peer.spawn(\"store\", fn() = Store.filling([]), waitMs()) {
        Right(filler) -> {
            Address.callForever(filler, Store.Fill);
            Io.println(\"held: \" <> started(Peer.spawn(\"store\", Store.waited, waitMs())));
            Io.println(\"lacked: \" <> started(Peer.spawn(\"store\", fn() = Unit, waitMs())));
            Address.callForever(filler, Store.Free);
            Io.println(\"held after: \" <> started(Peer.spawn(\"store\", Store.waited, waitMs())));
            Io.println(\"lacked after: \" <> started(Peer.spawn(\"store\", fn() = Unit, waitMs())))
        }
      | Left(error) -> Io.println(\"no filler: \" <> Io.show(error))
    }
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    WaitStore = ern_harness:start(Store, filename:join([Base, "build", "store.erc"]), []),
    ern_harness:prints(Store, "ready"),
    ?assertEqual(0, (ern_harness:start(Desk, filename:join([Base, "build", "desk.erc"]), []))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    ?assertEqual(["held: Io.Other(\"error:system_limit\")",
                  "lacked: Io.Other(\"error:system_limit\")",
                  "held after: Right", "lacked after: Right", ""],
                 string:split(Out, "\n", all)),
    ?assertEqual(nomatch, string:find(StoreErr, "Too many processes")),
    ?assertEqual(nomatch, string:find(StoreErr, "REPORT")).

%% report §12.5: a connection a peer opens while the node's table of
%% processes is full is closed as it opens, the node saying so, and the node
%% accepts the next once room is made: the keeper, connected, fills the
%% store's table, the desk's dial fails, and once the keeper frees it the
%% desk's next spawn starts. A regression test, written after the code. The
%% table filled whole leaves no room for the acceptor's own process.
accept_at_a_full_table_test_() ->
    ern_harness:nodes_test({waits, 11}, fun accept_at_a_full_table/1).

accept_at_a_full_table(Base) ->
    accept_at(Base, 0, from_address).

%% The same with two processes left free, which the acceptor's own process
%% and the host's TLS take before the TLS handshake gives the peer's key,
%% so that the refusal holds the host's answer to a full table
%% (docs/otp_bugs.md, 15). A regression test, written after the code.
accept_at_the_hosts_tls_test_() ->
    ern_harness:nodes_test({waits, 11}, fun accept_at_the_hosts_tls/1).

accept_at_the_hosts_tls(Base) ->
    accept_at(Base, 2, from_address).

%% The same with four left free, which leave no room for the host's
%% handshake after its TLS has given the peer's key. A regression test,
%% written after the code.
accept_at_the_handshake_test_() ->
    ern_harness:nodes_test({waits, 11}, fun accept_at_the_handshake/1).

accept_at_the_handshake(Base) ->
    accept_at(Base, 4, by_peer).

%% The same with five left free, which leave no room for the handshake's
%% timer. A regression test, written after the code.
accept_at_the_handshake_timer_test_() ->
    ern_harness:nodes_test({waits, 11}, fun accept_at_the_handshake_timer/1).

accept_at_the_handshake_timer(Base) ->
    accept_at(Base, 5, by_peer).

%% The store's table filled but for Left processes, the desk's dial refused
%% at the step they leave no room for, the line naming the connection by
%% the address it came from or by its peer, and the desk's next spawn
%% started once the keeper frees the table.
accept_at(Base, Left, Named) ->
    {Store, Keeper, Desk} = accepting_nodes(Base, <<"processes">>),
    WaitStore = ern_harness:start(Store, filename:join([Base, "build", "store.erc"]), []),
    ern_harness:prints(Store, "ready"),
    {Keep, WaitKeeper} = ern_harness:started(Keeper, filename:join([Base, "build", "keeper.erc"]),
                                             ["processes", integer_to_list(Left)]),
    ern_harness:prints(Keeper, "filled"),
    {Dial, WaitDesk} = ern_harness:started(Desk, filename:join([Base, "build", "desk.erc"]), []),
    ern_harness:prints(Desk, "full: "),
    ern_harness:says(Store, "was refused: this node's table of processes is full"),
    true = port_command(Keep, "free\n"),
    ern_harness:prints(Keeper, "freed"),
    true = port_command(Dial, "again\n"),
    ?assertEqual(0, WaitDesk()),
    true = port_command(Keep, "end\n"),
    ?assertEqual(0, WaitKeeper()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {StoreOut, StoreErr} = ern_harness:said(Store),
    ?assertEqual(["full: Io.Unreachable", "after: Right", ""], string:split(Out, "\n", all)),
    {_, Lines} = lines_said({0, StoreErr}),
    Refused = " was refused: this node's table of processes is full",
    case [Line || Line <- Lines, string:find(Line, Refused) =/= nomatch] of
        ["a connection from 127.0.0.1:" ++ Port] when Named =:= from_address ->
            ?assertEqual(Refused, string:find(Port, " "));
        Said ->
            ?assertEqual(["the peer desk" ++ Refused], Said),
            %% the line as the deployment guide quotes it
            ern_deployment_tests:cataloged(StoreErr, "7", "was refused: this node's table of"
                                           " processes is full", [{"b", "desk"}])
    end,
    %% The host's reports of a refused spawn, which the runner drops by
    %% their form, each name `system_limit`, which no line of the node's does.
    [?assertEqual(nomatch, string:find(Text, Part))
     || Text <- [StoreOut, StoreErr],
        Part <- ["Too many processes", "REPORT", "Error in", "system_limit"]].

%% report §12.5: a connection a peer opens while the node's table of ports
%% is full is closed as the acceptor would take it, the node saying so in a
%% line that names no peer, and the node accepts the next once room is
%% made: the keeper, connected, fills the store's ports with listeners, the
%% desk's dial fails, and once the keeper closes them the desk's next spawn
%% starts. The store may hold twice as many files as ports, so that its
%% table of ports is what fills. A regression test, written after the code;
%% it does not cover a full table of ports met after the connection is
%% taken, which no later step of the connection's opens a port for.
accept_at_a_full_port_table_test_() ->
    ern_harness:nodes_test({waits, 11}, fun accept_at_a_full_port_table/1).

accept_at_a_full_port_table(Base) ->
    {Store, Keeper, Desk} = accepting_nodes(Base, <<"ports">>),
    {_, WaitStore} = ern_harness:launched(Store,
                                          ["ulimit -n 2048; exec ", ?ERN, " run --config-dir ",
                                           Store, " ",
                                           filename:join([Base, "build", "store.erc"])]),
    ern_harness:prints(Store, "ready"),
    {Keep, WaitKeeper} = ern_harness:started(Keeper, filename:join([Base, "build", "keeper.erc"]),
                                             ["files"]),
    ern_harness:prints(Keeper, "filled"),
    {Dial, WaitDesk} = ern_harness:started(Desk, filename:join([Base, "build", "desk.erc"]), []),
    ern_harness:prints(Desk, "full: "),
    Refused = "a connection was refused: this node's table of ports is full",
    ern_harness:says(Store, Refused),
    true = port_command(Keep, "free\n"),
    ern_harness:prints(Keeper, "freed"),
    true = port_command(Dial, "again\n"),
    ?assertEqual(0, WaitDesk()),
    true = port_command(Keep, "end\n"),
    ?assertEqual(0, WaitKeeper()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {StoreOut, StoreErr} = ern_harness:said(Store),
    ?assertEqual(["full: Io.Unreachable", "after: Right", ""], string:split(Out, "\n", all)),
    {_, Lines} = lines_said({0, StoreErr}),
    ?assertEqual([Refused], [Line || Line <- Lines, string:find(Line, "refused") =/= nomatch]),
    [?assertEqual(nomatch, string:find(Text, Part))
     || Text <- [StoreOut, StoreErr], Part <- ["REPORT", "Error in", "system_limit"]].

%% report §12, §12.5: a connection a peer opens while the node holds as many
%% files as the operating system lets it waits unaccepted, the node saying
%% so once and spending under a tenth of the wait on a processor, where the
%% host's own acceptor spun a scheduler (docs/otp_bugs.md, 14); the dial
%% fails, and once the keeper closes its listeners the node accepts again
%% within a dial's time, so that the desk's second dial after them starts
%% its spawn. A regression test, written after the code; the limit of the
%% system's table of files, `enfile`, is not reached.
accept_at_the_file_limit_test_() ->
    ern_harness:nodes_test({waits, 11, 3 * ?DIAL_MS}, fun accept_at_the_file_limit/1).

accept_at_the_file_limit(Base) ->
    {Store, Keeper, Desk} = accepting_nodes(Base, none),
    {_, WaitStore} = ern_harness:launched(Store,
                                          ["ulimit -n 64; exec ", ?ERN, " run --config-dir ", Store,
                                           " ", filename:join([Base, "build", "store.erc"])]),
    ern_harness:prints(Store, "ready"),
    {Keep, WaitKeeper} = ern_harness:started(Keeper, filename:join([Base, "build", "keeper.erc"]),
                                             ["files"]),
    ern_harness:prints(Keeper, "filled"),
    Before = {erlang:monotonic_time(millisecond), processor_ticks(Store)},
    {Dial, WaitDesk} = ern_harness:started(Desk, filename:join([Base, "build", "desk.erc"]), []),
    ern_harness:prints(Desk, "full: ", 2 * ?DIAL_MS + ?WAIT_MS),
    {Start, Ticks} = Before,
    Waited = erlang:monotonic_time(millisecond) - Start,
    %% a tick is a hundredth of a second, Linux's USER_HZ
    ?assert((processor_ticks(Store) - Ticks) * 10 < Waited div 10),
    ern_harness:says(Store, "a connection waits: too many open files"),
    true = port_command(Keep, "free\n"),
    ern_harness:prints(Keeper, "freed"),
    true = port_command(Dial, "again\n"),
    ?assertEqual(0, WaitDesk()),
    true = port_command(Keep, "end\n"),
    ?assertEqual(0, WaitKeeper()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    ?assertEqual(["full: Io.Unreachable", "after: Right", ""], string:split(Out, "\n", all)),
    ?assertEqual(1, length(string:split(StoreErr, "a connection waits", all)) - 1),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(StoreErr, "7", "a connection waits: too many open files", []).

%% The processor time the node of Dir has spent, in ticks, as Linux counts
%% a process's user and system time.
processor_ticks(Dir) ->
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    {ok, Stat} = file:read_file(filename:join(["/proc", string:trim(Pid), "stat"])),
    %% the fields after the command's name, which closes with the last `)`
    [_, After] = string:split(binary_to_list(Stat), ")", trailing),
    Fields = string:lexemes(After, " "),
    list_to_integer(lists:nth(12, Fields)) + list_to_integer(lists:nth(13, Fields)).

%% The store, listening, the table Limit names, of processes or of ports,
%% held at the least limit, and the keeper and the desk, which each dial
%% it, their programs built: the store's fillers of processes and of files,
%% the second's listeners holding ports too; the keeper, which fills the
%% store's processes or its files as its argument says, then frees them at
%% its first line of input and ends at its second;
%% and the desk, which spawns on the store, then, at its line of input,
%% once more, or twice where the first dial fails.
accepting_nodes(Base, Limit) ->
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Keeper = ern_harness:made(Base, "keeper", none),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"keeper", Keeper, none}, {"desk", Desk, none}]),
    ern_harness:lists(Keeper, [{"store", Store, PortStore}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    Limit =:= none
        orelse ern_harness:edit(Store, fun(Conf) -> Conf#{<<"limits">> => #{Limit => 1024}} end),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "store.ern"), <<"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

// What a filler takes: the ask to fill, leaving room for `left`, and the
// ask to free.
export type FillMsg = Fill(left : Int, reply : Reply(Unit)) | Free(Reply(Unit))

// The processes the table has room for.
fn room() : Int =
    systemInfo(Foreign.atom(\"process_limit\")) - systemInfo(Foreign.atom(\"process_count\"))

// A process that waits until it is told to end.
export fn waited() : Unit receiving Int = receive { _ -> Unit }

// Count processes spawned, each waiting, after those held.
fn filled(count : Int, held : List(Address(Int))) : List(Address(Int)) =
    if count > 0 then filled(count - 1, spawn(fn() = waited()) :: held) else held

// The filler of processes: the table filled when asked, and the processes
// it filled it with ended when asked.
export fn filling(held : List(Address(Int))) : Unit receiving FillMsg =
    receive {
        Fill(=left, =reply) -> {
            let full = filled(room() - left, held);
            answer(reply, Unit);
            filling(full)
        }
      | Free(reply) -> {
            List.forEach(held, fn(process) = send(process, 0));
            answer(reply, Unit);
            filling([])
        }
    }

// Listeners opened until the host refuses one, after those held.
fn listened(held : List(Address(Tcp.ListenerMsg))) : List(Address(Tcp.ListenerMsg)) =
    match Tcp.listen(\"127.0.0.1\", 0) {
        Right(listener) -> listened(listener :: held)
      | Left(_) -> held
    }

// The filler of files: the node's files filled with listeners when asked,
// and the listeners closed when asked.
export fn filing(held : List(Address(Tcp.ListenerMsg))) : Unit receiving FillMsg =
    receive {
        Fill(=left, =reply) -> {
            let full = listened(held);
            List.forEach(List.take(full, left), Tcp.closeListener);
            answer(reply, Unit);
            filing(List.drop(full, left))
        }
      | Free(reply) -> {
            List.forEach(held, Tcp.closeListener);
            answer(reply, Unit);
            filing([])
        }
    }

// The store waits until it is stopped.
export fn main() : Unit receiving Int = {
    Io.println(\"ready\");
    waited()
}
">>),
    ok = file:write_file(filename:join(Source, "keeper.ern"), [<<"
// The store's filler its first argument names.
fn filler() : Either(Io.Error, Address(Store.FillMsg)) =
    match Os.arguments {
        \"files\" :: _ -> Peer.spawn(\"store\", fn() = Store.filing([]), waitMs())
      | _ -> Peer.spawn(\"store\", fn() = Store.filling([]), waitMs())
    }

// The room the filler leaves, its second argument, or none.
fn left() : Int =
    match Os.arguments {
        [_, count] -> Optional.withDefault(String.toInt(count), 0)
      | _ -> 0
    }

// The store filled, freed at the first line of input, the keeper ending at
// the second.
export fn main() : Unit =
    match filler() {
        Right(filler) -> {
            Address.callForever(filler, fn(reply) = Store.Fill(left = left(), =reply));
            Io.println(\"filled\");
            let _ = Io.readLine();
            Address.callForever(filler, Store.Free);
            Io.println(\"freed\");
            let _ = Io.readLine();
            Unit
        }
      | Left(error) -> Io.println(\"no filler: \" <> Io.show(error))
    }
">>, ern_harness:wait_ms_declaration()]),
    ok = file:write_file(filename:join(Source, "desk.ern"), [<<"
// A spawn's answer, its address left out.
fn started(spawned : Either(Io.Error, Address(m))) : String =
    match spawned {
        Right(_) -> \"Right\"
      | Left(error) -> Io.show(error)
    }

// A spawn on the store, once more where the dial fails.
fn spawned(tries : Int) : Either(Io.Error, Address(Int)) =
    match Peer.spawn(\"store\", Store.waited, waitMs()) {
        Left(Io.Unreachable) when tries > 1 -> spawned(tries - 1)
      | answer -> answer
    }

// The spawn at the store's full table, and the one once the keeper has
// freed it.
export fn main() : Unit = {
    Io.println(\"full: \" <> started(Peer.spawn(\"store\", Store.waited, waitMs())));
    let _ = Io.readLine();
    Io.println(\"after: \" <> started(spawned(2)))
}
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built(["--build-root", filename:join(Base, "build"), Source]),
    {Store, Keeper, Desk}.

%% A finished command's status, and the lines of its output that are no
%% trace's, each from where its time ends, a node's lines being stamped.
lines_said({Status, Output}) ->
    {Status, [case string:split(Line, "Z ") of
                  [_, Said] -> Said;
                  [Said] -> Said
              end || Line <- string:split(Output, "\n", all), Line =/= "",
                     not lists:prefix("    ", Line)]}.

%% report §12.5: a node runs over its listener's family of addresses, IPv6
%% where `listen` names an address of it, its peers' addresses of the same
ipv6_test_() ->
    ern_harness:nodes_test({waits, 8}, fun ipv6/1).

%% Each node listens on a port the host picks, `b`'s read once it listens,
%% and `b` lists `a`, which dials it, without an address.
ipv6(Base) ->
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", none),
    ern_harness:edit(B, fun(Conf) ->
                            Conf#{<<"listen">> => ipv6_loopback(0),
                                  <<"peers">> => [ern_harness:peer("a", A, none)]}
                        end),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    PortB = ern_harness:bound_port(B),
    ern_harness:edit(A, fun(Conf) ->
                            Conf#{<<"listen">> => ipv6_loopback(0),
                                  <<"peers">> => [(ern_harness:peer("b", B, none))#{
                                                       <<"network-address">> =>
                                                           ipv6_loopback(PortB)}]}
                        end),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(B, "the peer a connected"),
    ern_harness:stop(B, WaitB),
    {OutA, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(OutA, "connect: true"),
    ern_harness:has(ErrB, "the peer a connected").

%% report §12.5, Appendix E.18: a node's listener on `::` takes connections
%% of IPv6's family alone, so a listener on `0.0.0.0` stands beside it on
%% its port and is the one an IPv4 connection to the port reaches. A
%% regression test: the node on `::` took IPv4 connections too, and beside
%% a listener on `0.0.0.0` its carrier did not start, its listen address
%% in use. It does not cover an interface other than the loopback's
ipv6_beside_ipv4_test_() ->
    ern_harness:nodes_test({waits, 7}, fun ipv6_beside_ipv4/1).

ipv6_beside_ipv4(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {0, 0, 0, 0}}, {active, false}]),
    {ok, PortB} = inet:port(Held),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", none),
    %% `a` listens on a port the host picks, and `b` lists it, as the node
    %% that dials, without an address
    ern_harness:edit(A, fun(Conf) ->
                            Conf#{<<"listen">> => ipv6_loopback(0),
                                  <<"peers">> => [(ern_harness:peer("b", B, none))#{
                                                       <<"network-address">> =>
                                                           ipv6_loopback(PortB)}]}
                        end),
    ern_harness:edit(B, fun(Conf) ->
                            Conf#{<<"listen">> => list_to_binary("[::]:" ++ integer_to_list(PortB)),
                                  <<"peers">> => [ern_harness:peer("a", A, none)]}
                        end),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["connect", ern_harness:name(B)]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(B, "the peer a connected"),
    ern_harness:step(ipv4_accepted),
    {ok, Client} = gen_tcp:connect({127, 0, 0, 1}, PortB, [{active, false}], ?WAIT_MS),
    Accepted = gen_tcp:accept(Held, ?WAIT_MS),
    ok = gen_tcp:close(Client),
    ok = gen_tcp:close(Held),
    ern_harness:stop(B, WaitB),
    ?assertMatch({ok, _}, Accepted),
    {OutA, _} = ern_harness:said(A),
    ern_harness:has(OutA, "connect: true").

%% Report Appendix C: the `listen` or the `network-address` of a node at
%% Port of IPv6's loopback.
ipv6_loopback(Port) ->
    list_to_binary("[::1]:" ++ integer_to_list(Port)).

%% report §8.6, §12.5, Appendix E.23: a node whose program ends by `Os.exit`
%% exits with its status, and its ernest.pid, there while it runs, is gone
os_exit_test_() ->
    ern_harness:nodes_test({waits, 3}, fun os_exit/1).

os_exit(Base) ->
    A = ern_harness:made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    %% the list given the harness's time for one wait, the step it is of
    ok = file:write_file(filename:join(Root, "exits.ern"),
                         ["export fn main() : Unit = {\n"
                          "    let listed = Fs.list(Path(\"", A, "\"), ",
                          ern_harness:wait_ms_text(), ");\n"
                          "    Io.println(Io.show(Either.map(listed,\n"
                          "                                  fn(entries) = List.size(entries))));\n"
                          "    Os.exit(3)\n"
                          "}\n"]),
    0 = ern_harness:built([Root]),
    ?assertEqual(3, (ern_harness:start(A, filename:join(Root, "exits.erc"), []))()),
    {Out, _} = ern_harness:said(A),
    ern_harness:has(Out, "Right(4)"),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §12.5, §11.2: a node whose `ernest.conf` is refused is refused with
%% the file and the rule, as the launcher's second start says it, the first
%% having given the host no flags: peers that are no array, and a
%% `utilization`, which the file does not know. A regression test: the
%% refusal said the host had not been started as a node; the
%% utilization's was written after the code
refused_configuration_test_() ->
    ern_harness:nodes_test({waits, 3}, fun refused_configuration/1).

refused_configuration(Base) ->
    A = ern_harness:made(Base, "a", none),
    ern_harness:edit(A, fun(Conf) -> Conf#{<<"peers">> => #{}} end),
    Program = ern_harness:program(filename:join(Base, "build")),
    Run = ?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1",
    {1, Said} = finished(Run),
    ern_harness:has(Said,
                    "ern run: " ++ filename:join(A,
                                                 "ernest.conf") ++ ": peers is not a JSON array"),
    ern_harness:edit(A,
                     fun(Conf) -> Conf#{<<"peers">> => [],
                                        <<"utilization">> => <<"run-queue">>} end),
    {1, Measured} = finished(Run),
    ern_harness:has(Measured,
                    "ern run: " ++ filename:join(A, "ernest.conf") ++ ": the file has the unknown"
                    " field utilization").

%% report §12.5, §11.2: a node refused once its start has begun, by a module
%% on its load path the program never uses whose dependency the path lacks,
%% removes the ernest.pid it wrote, as it does however it ends. A
%% regression test: the file was left naming the process that had ended
refused_after_start_test_() ->
    ern_harness:nodes_test({waits, 2}, fun refused_after_start/1).

refused_after_start(Base) ->
    A = ern_harness:made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join(Root, "uses.ern"), "export fn f() : Int = Used.g()\n"),
    ok = file:write_file(filename:join(Root, "used.ern"), "export fn g() : Int = 1\n"),
    0 = ern_harness:built([Root]),
    ok = file:delete(filename:join(Root, "used.erc")),
    {1, Said} = finished(?ERN ++ " run --config-dir " ++ A ++ " " ++ filename:join(Root, "prog.erc")
                         ++ " 2>&1"),
    ern_harness:has(Said, "Used"),
    ?assertEqual(nomatch, string:find(Said, "ran")),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §12.5, §11.8, §8.7: a node whose carrier cannot start, its port
%% taken, ends before `main` runs as a job that cannot start, with status 1
%% and the line §12.5 states, which names the listen address in use, `ern
%% run:` for a program's node and `ern shell:` for a shell's own, with no
%% fault's line and nothing of the host's reports on its standard output. A
%% regression test (the log's *The Principles Review of 2026-10-09*,
%% which stated the cause in §7.4): the fault was reported under the last
%% initializer's site, `Terminal.widths`, and the host's crash report of its
%% distribution was written on standard output; and (the log's *The Shell's
%% Own Node*) the node's end was its entry process's fault, a shell's
%% status 70
carrier_not_started_test_() ->
    ern_harness:nodes_test({waits, 3}, fun carrier_not_started/1).

carrier_not_started(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    A = ern_harness:made(Base, "a", Port),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    0 = ern_harness:built([Root]),
    Program = filename:join(Root, "prog.erc"),
    Out = filename:join(Base, "out"),
    {1, Said} = finished(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1 >" ++ Out),
    Line = "the node's carrier did not start: its listen address 127.0.0.1:"
        ++ integer_to_list(Port) ++ " is in use\n",
    ?assertEqual("ern run: " ++ Line, unstamped(Said)),
    ?assertEqual({ok, <<>>}, file:read_file(Out)),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(Said, "7", "carrier did not start", []),
    %% a shell's own node so
    {1, Shell} = finished("HOME=" ++ Base ++ " " ++ ?ERN ++ " shell --config-dir " ++ A
                          ++ " < /dev/null 2>&1"),
    ok = gen_tcp:close(Held),
    ?assertEqual("ern shell: " ++ Line, unstamped(Shell)),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §8.6, §12.5, Appendix E.23: a node whose carrier cannot start ends
%% as any program ends, so the subscriber of `Os.subscribeTermination` its
%% initializers started is told, and the end waits for its answer, which the
%% runtime says, before the job's line. A regression test, written after the
%% report named the end in §8.6 (the log's *The Release Review Before
%% 0.7.0*, *The round*): the code already told it
carrier_not_started_tells_test_() ->
    ern_harness:nodes_test({waits, 2}, fun carrier_not_started_tells/1).

carrier_not_started_tells(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    A = ern_harness:made(Base, "a", Port),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "type Msg = Ending(Reply(Unit)) | Ready(Reply(Unit))\n\n"
                         "fn told() : Unit receiving Msg = {\n"
                         "    Os.subscribeTermination(Ending);\n"
                         "    waiting()\n"
                         "}\n\n"
                         "fn waiting() : Unit receiving Msg =\n"
                         "    receive {\n"
                         "        Ready(reply) -> {\n"
                         "            answer(reply, Unit);\n"
                         "            waiting()\n"
                         "        }\n"
                         "      | Ending(reply) -> {\n"
                         "            Io.println(\"told at the end\");\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "    }\n\n"
                         "let teller : Address(Msg) = {\n"
                         "    let address = spawn(told);\n"
                         "    Address.callForever(address, Ready);\n"
                         "    address\n"
                         "}\n\n"
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    0 = ern_harness:built([Root]),
    Out = filename:join(Base, "out"),
    {1, Said} = finished(?ERN ++ " run --config-dir " ++ A ++ " "
                         ++ filename:join(Root, "prog.erc") ++ " 2>&1 >" ++ Out),
    ok = gen_tcp:close(Held),
    ?assertEqual({ok, <<"told at the end\n">>}, file:read_file(Out)),
    ?assertEqual("the end waits for 1 subscriber: Prog.teller:21\n"
                 "the subscriber Prog.teller:21 answered\n"
                 "ern run: the node's carrier did not start: its listen address 127.0.0.1:"
                 ++ integer_to_list(Port) ++ " is in use\n", unstamped(Said)).

%% report §8.6: a node detects no deadlock, since it can be reached from
%% outside: a node that waits for a message that never comes waits, where
%% the same program run as no node faults; termination ends it. That the
%% node does not fault is shown by its not ending, as a deadlock's fault
%% would end it, within three times what the program took to fault as no
%% node (the log's *The Carrier*), the one wait here a time, since an
%% absence shows itself by nothing else
no_deadlock_test_() ->
    ern_harness:nodes_test({waits, 6}, fun no_deadlock/1).

no_deadlock(Base) ->
    A = ern_harness:made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "waits.ern"),
                         "export fn main() : Unit receiving Int = {\n"
                         "    Io.println(\"waiting\");\n"
                         "    receive { n -> Unit }\n"
                         "}\n"),
    0 = ern_harness:built([Root]),
    Program = filename:join(Root, "waits.erc"),
    {Micros, {1, Plain}} = timer:tc(fun() -> finished(?ERN ++ " run " ++ Program ++ " 2>&1") end),
    ern_harness:has(Plain, "deadlock"),
    {Port, Wait} = ern_harness:started(A, Program, []),
    ern_harness:prints(A, "waiting"),
    %% an absence: no end within three times what the plain run took to
    %% find its deadlock
    ?assertEqual(timeout, ern_harness:ended(Port, 3 * Micros div 1000)),
    {ok, Pid} = file:read_file(filename:join(A, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(143, Wait()),
    {_, Err} = ern_harness:said(A),
    ?assertEqual(nomatch, string:find(Err, "deadlock")),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%%
%% Peer (report §8.7, Appendix E.27)
%%

%% The programs of test/fixtures/peers/, one build: the store's and the desk's, with
%% the third node's beside them, and the host module they ask of the host,
%% on the load path, so that every node runs one build.
peers(Base) ->
    Root = filename:join(Base, "build"),
    0 = ern_harness:built(["--build-root", Root, "fixtures/peers"]),
    {ok, _} = compile:file("fixtures/peers/ern_peers_host.erl", [{outdir, Root}]),
    {filename:join(Root, "store.erc"), filename:join(Root, "desk.erc")}.

%% test/fixtures/peers/harness.ern: the programs of test/fixtures/peers/ give
%% each wait the harness's time for one wait, and wait by the dial's and
%% the detector's times the report states, which the module writes as
%% numbers of its own. The two later times, written after the programs
%% wrote them in place, are a regression test; and report §8.7: the dial's
%% time the carrier gives the host, which the shell asks it, is the
%% report's (ern_carrier:dial_ms/0), a regression test of the one place
%% the toolchain states it
fixtures_times_test() ->
    ?assertEqual(?DIAL_MS, ern_carrier:dial_ms()),
    {ok, Text} = file:read_file("fixtures/peers/harness.ern"),
    ?assertEqual([integer_to_binary(Ms) || Ms <- [?WAIT_MS, ?DIAL_MS, ?DETECTOR_MS]],
                 [case re:run(Text, ["fn ", Name, "\\(\\) : Int =\\s+([0-9]+)"],
                              [{capture, all_but_first, binary}]) of
                      {match, [Ms]} -> Ms;
                      nomatch -> Name
                  end || Name <- ["waitMs", "dialMs", "detectorMs"]]).

%% A store that listens, a desk that dials it, and a peer the desk lists,
%% gone, whose port nothing holds; the desk's services, each a name's
%% peers in the order a find asks them.
store_and_desk(Base) ->
    {PortStore, PortGone} = {ern_harness:free_port(), ern_harness:free_port()},
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    Gone = ern_harness:made(Base, "gone", none),
    Third = ern_harness:made(Base, "third", none),
    ern_harness:lists(Store, [{"desk", Desk, none}, {"third", Third, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}, {"gone", Gone, PortGone}]),
    ern_harness:lists(Third, [{"store", Store, PortStore}]),
    Stored = [<<"adder">>, <<"victim">>, <<"nothing">>, <<"census">>, <<"counter-slot">>,
              <<"echo-slot">>, <<"fragile">>, <<"strict">>, <<"brittle">>, <<"sleeper">>,
              <<"doomed">>, <<"adapter">>, <<"watcher">>, <<"gated">>, <<"opener">>,
              <<"herald">>, <<"herald-watcher">>],
    ern_harness:edit(Desk, fun(Conf) ->
                               Conf#{<<"services">> => maps:merge(
                                                          maps:from_list([{Name, [<<"store">>]}
                                                                          || Name <- Stored]),
                                                          #{<<"counter">> => [<<"gone">>,
                                                                              <<"store">>],
                                                            <<"lost">> => [<<"gone">>]})}
                           end),
    ern_harness:edit(Third, fun(Conf) ->
                                Conf#{<<"services">> => #{<<"counter-slot">> => [<<"store">>],
                                                          <<"echo-slot">> => [<<"store">>]}}
                            end),
    {Store, Desk}.

%% A site of test/fixtures/peers/desk.ern as a node writes it: the
%% definition's name, and the number of the first line that holds Part.
desk_site(Definition, Part) ->
    {ok, Source} = file:read_file("fixtures/peers/desk.ern"),
    Line = line_of(unicode:characters_to_list(Source), Part),
    "Desk." ++ Definition ++ ":" ++ integer_to_list(Line).

%% report §8.7, Appendix E.27, §6.5, §6.9, §6.6, E.21: a find in a node's
%% initializer answers Unreachable, the node not yet dialing. A find over a
%% service's peers in order passes over one that cannot be reached and
%% answers the next's address, a service not listed NotListed, a name
%% offered at another type OtherType, a name not offered NotOffered, a
%% service of an unreachable peer alone Unreachable, no time Timeout.
%%
%% A message to an adapted address made on the store reaches its target
%% through the store. Kill crosses, and a Down from another node's process
%% has an empty site. Process.status answers None for another node's
%% process. An offer of another node's process faults, and one of a service
%% a living process holds answers that process. A lost connection gives a
%% monitor Unreachable with an empty site, a find after it Unreachable, and
%% a callForever on its process faults with the callee unreachable; and a
%% node killed outright, which tells its peers nothing, is said as lost,
%% its connection closed
find_test_() ->
    ern_harness:nodes_test({waits, 7}, fun find/1).

find(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    WaitDesk = ern_harness:start(Desk, DeskProgram, ["find"]),
    ern_harness:prints(Desk, "now end the store"),
    {ok, Pid} = file:read_file(filename:join(Store, "ernest.pid")),
    _ = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(137, WaitStore()),
    ?assertEqual(0, WaitDesk()),
    {Out, Err} = ern_harness:said(Desk),
    {StoreOut, _} = ern_harness:said(Store),
    ern_harness:has(Err, "the peer store was lost: it closed"),
    ?assertEqual(nomatch, string:find(Err, "the peer store ended")),
    ern_harness:has(StoreOut, "the store's peers: [\"desk\", \"third\"]"),
    [ern_harness:has(Out, Line)
     || Line <- ["early: Left(Io.Unreachable)", "peers: [\"store\", \"gone\"]", "status: None",
                 "unlisted: Left(Io.NotListed)", "other type: Left(Io.OtherType)",
                 "not offered: Left(Io.NotOffered)", "unreachable: Left(Io.Unreachable)",
                 "timeout: Left(Io.Timeout)", "no upper bound: Right",
                 "through the adapted address: 7",
                 "killed: Killed \"\"",
                 "another node's: Fault(\"a node offers only its own processes\")",
                 "twice, first: Right(Unit)", "twice, again held by itself: true",
                 "twice: Returned",
                 "lost: Unreachable \"\"", "after the loss: Left(Io.Unreachable)",
                 "call forever: Fault(\"callee is unreachable\")"]].

%% report §8.7, Appendix E.27: a service handed over on a node: the
%% server's first process takes the service, Right(Unit), and a newcomer's
%% offer of it answers the holder, Left(holder), which the newcomer
%% monitors; the client finds the first process, calls it and kills it
%% across nodes; at the holder's Down the newcomer offers again and takes
%% the service, and the client's next find reaches the newcomer. A regression test, written
%% after the code, which faulted the newcomer's offer
handover_test_() ->
    ern_harness:nodes_test({waits, 8}, fun handover/1).

handover(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "server.ern"), <<"
// Report §8.7, Appendix E.27: a service handed over: the first process
// takes it, and a newcomer finds it held, monitors the holder and takes
// the service at the holder's end.

export type Msg = Which(Reply(String))

export let service : Peer.Service(Msg) = Peer.service(\"handover\")

type Newcomer = Asked(Msg) | Ended(Down)

export fn main() : Unit receiving Unit = {
    let first = spawn(fn() = serve());
    Io.println(\"taken: \" <> Io.show(Peer.offer(service, first)));
    let _ = spawn(fn() = newcomer(Process.fromAddress(first)));
    held()
}

fn serve() : Unit receiving Msg =
    receive {
        Which(reply) -> {
            answer(reply, \"first\");
            serve()
        }
    }

fn newcomer(first : Process) : Unit receiving Newcomer = {
    let address = adapted(self(), Asked);
    match Peer.offer(service, address) {
        Left(holder) -> {
            Io.println(\"held by the first: \" <> Io.show(holder == first));
            monitor(holder, Ended);
            receive {
                Ended(_) -> Io.println(\"then taken: \" <> Io.show(Peer.offer(service, address)))
            }
        }
      | Right(_) -> Io.println(\"taken at once\")
    };
    serving()
}

fn serving() : Unit receiving Newcomer =
    receive {
        Asked(Which(reply)) -> {
            answer(reply, \"newcomer\");
            serving()
        }
      | Ended(_) -> serving()
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit receiving Unit = receive { _ -> held() }
"/utf8>>),
    ok = file:write_file(filename:join(Root, "client.ern"), [<<"
// Report §8.7, Appendix E.27: the client finds the server's service, calls
// it and kills it, and once the test says the service is taken finds it
// again.

export fn main() : Unit =
    match Peer.find(Server.service, waitMs()) {
        Right(first) -> {
            Io.println(\"first: \" <> asked(first));
            kill(Process.fromAddress(first));
            Io.println(\"killed\");
            // until the test, which has seen the service taken, says so
            let _ = Io.readLine();
            match Peer.find(Server.service, waitMs()) {
                Right(newcomer) -> Io.println(\"then: \" <> asked(newcomer))
              | Left(failure) -> Io.println(\"then: \" <> Io.show(failure))
            }
        }
      | Left(failure) -> Io.println(\"first: \" <> Io.show(failure))
    }

fn asked(service : Address(Server.Msg)) : String =
    Io.show(Address.call(service, fn(reply) = Server.Which(reply), waitMs()))
"/utf8>>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    PortServer = ern_harness:free_port(),
    Server = ern_harness:made(Base, "server", PortServer),
    Client = ern_harness:made(Base, "client", none),
    ern_harness:lists(Server, [{"client", Client, none}]),
    ern_harness:lists(Client, [{"server", Server, PortServer}]),
    ern_harness:edit(Client,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"handover">> => [<<"server">>]}} end),
    WaitServer = ern_harness:start(Server, filename:join(Root, "server.erc"), []),
    ern_harness:prints(Server, "held by the first: true"),
    {Input, WaitClient} = ern_harness:started(Client, filename:join(Root, "client.erc"), []),
    ern_harness:prints(Client, "killed"),
    ern_harness:prints(Server, "then taken: Right(Unit)"),
    true = port_command(Input, "taken\n"),
    ?assertEqual(0, WaitClient()),
    ern_harness:stop(Server, WaitServer),
    {Out, _} = ern_harness:said(Client),
    {ServerOut, _} = ern_harness:said(Server),
    ern_harness:has(ServerOut, "taken: Right(Unit)"),
    ern_harness:has(Out, "first: Some(\"first\")"),
    ern_harness:has(Out, "then: Some(\"newcomer\")").

%% report §8.7, §6.6: a reply crosses with a spawned function's captures,
%% and the spawned process answers it: a process on a calls a service on
%% a, which hands the call's reply to a lambda it spawns on b, and the
%% lambda answers it there, the caller reading Some(49); and a process a
%% spawned on b calls the same service, its call noted on a, and is
%% answered from a third process, on b, reading Some(64). A node ended by
%% termination tells its peer that it ends, which says so. A regression
%% test, written after the code, which refused the lambda; that a's note
%% is let go by the call's end is read from the code and not seen here
reply_crosses_test_() ->
    ern_harness:nodes_test({waits, 8}, fun reply_crosses/1).

reply_crosses(Base) ->
    {Program, A, B} = squares(Base),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["ask", "b"]),
    ern_harness:prints(B, "answered there: "),
    ern_harness:stop(A, WaitA),
    ern_harness:says(B, "the peer a ended"),
    ern_harness:stop(B, WaitB),
    {OutA, _} = ern_harness:said(A),
    {OutB, ErrB} = ern_harness:said(B),
    ern_harness:has(OutA, "answered here: Some(49)"),
    ern_harness:has(OutA, "spawned there: true"),
    ern_harness:has(OutB, "answered there: Some(64)"),
    ?assertEqual(nomatch, string:find(ErrB, "the peer a was lost")).

%% report §11.2, §8.7: a process a peer spawned that faults is reported on
%% the node it runs on with the spawner's site and, after the cause, the
%% peer that spawned it, as it restarts and as it ends; a process it spawns
%% there is reported without it, its site this node's. A regression test,
%% written after the code, whose line named the spawner's site alone
peer_fault_test_() ->
    ern_harness:nodes_test({waits, 8}, fun peer_fault/1).

peer_fault(Base) ->
    {Program, A, B} = squares(Base),
    WaitB = ern_harness:start(B, Program, []),
    ern_harness:prints(B, "waiting"),
    WaitA = ern_harness:start(A, Program, ["fault", "b"]),
    ern_harness:prints(A, "faulting there: true"),
    ern_harness:says(B, "the process of Squares.main:20 faulted: division by zero, spawned by the"
                        " peer a"),
    ern_harness:says(B, "the process of Squares.spawning:46 faulted: division by zero\n"),
    ern_harness:stop(A, WaitA),
    ern_harness:stop(B, WaitB),
    {_, ErrB} = ern_harness:said(B),
    ern_harness:has(ErrB, "the process of Squares.main:20 faulted, restarted: division by zero,"
                          " spawned by the peer a\n"),
    ?assertEqual(nomatch, string:find(ErrB, "Squares.spawning:46 faulted: division by zero,")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "spawned by the peer",
                                   [{"Counter.moving:106", "Squares.main:20"}, {"a", "a"}]).

%% The program of two nodes, a and b, each listing the other, a dialing b:
%% a service on a whose answer is given on b, by a lambda it spawns there
%% with the request's reply among its captures, and a function a spawns on
%% b that faults, restarting once, after it spawns one there that faults;
%% the restart's window, a minute, is the scenario's and no bound, which
%% both its runs' faults fall in, since each faults at once.
squares(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "squares.ern"), [<<"
// Report §8.7, §6.6, §11.2: a service whose answer is given on a peer, by
// a lambda it spawns there with the request's reply among its captures,
// and a function spawned on a peer that faults there.

type Msg = Square(n : Int, reply : Reply(Int))

export fn main() : Unit receiving Unit =
    match Os.arguments {
        [\"ask\", peer] -> {
            let service = spawn(fn() = serve(peer));
            Io.println(\"answered here: \" <> asked(service, 7));
            let there = Peer.spawn(peer, fn() =
                Io.println(\"answered there: \" <> asked(service, 8)), waitMs());
            Io.println(\"spawned there: \" <> Io.show(Either.isRight(there)));
            held()
        }
      | [\"fault\", peer] -> {
            let once = RestartLimit(restarts = 1, within = 60000);
            let faulting = Peer.spawn(peer, restarting(once, spawning), waitMs());
            Io.println(\"faulting there: \" <> Io.show(Either.isRight(faulting)));
            held()
        }
      | _ -> {
            Io.println(\"waiting\");
            held()
        }
    }

fn serve(peer : String) : Unit receiving Msg =
    receive {
        Square(=n, =reply) -> {
            match Peer.spawn(peer, fn() = answer(reply, n * n), waitMs()) {
                Right(_) -> Unit
              | Left(failure) -> Io.println(\"no spawn: \" <> Io.show(failure))
            };
            serve(peer)
        }
    }

fn asked(service : Address(Msg), n : Int) : String =
    Io.show(Address.call(service, fn(reply) = Square(=n, =reply), waitMs()))

// A process that faults, spawned here, and then a fault of its own.
fn spawning() : Unit = {
    let _ = spawn(fn() = divided());
    divided()
}

fn divided() : Unit = {
    let _ = 1 / List.size([]);
    Unit
}

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit receiving Unit = receive { _ -> held() }
"/utf8>>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    PortB = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, none}]),
    {filename:join(Root, "squares.erc"), A, B}.

%% report §8.7, §6.7, Appendix E.27, §8.2: work on a peer is a process
%% spawned at the node the program names, whose spawn answers its address or
%% a failure within the time. A function the store holds spawns there with
%% what it captured, writing to the store's standard output; a name that is
%% no peer's is NotListed. A function that names a binding with no value on
%% the store is NotLoaded, carrying what the store says (Appendix E.1),
%% which the store says, and nothing is initialized
%% for it; a function that names no binding spawns though its module's
%% binding has no value there.
%%
%% A top-level binding in spawned code is the peer's. A monitored spawn is
%% monitored from its start. A spawn given no time answers Timeout. A find
%% and a spawn given a time past the longest wait the host takes at once
%% wait, a regression: each failed with the host's error
spawn_test_() ->
    ern_harness:nodes_test({waits, 7}, fun spawn_on_peer/1).

spawn_on_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["spawn"]))()),
    ern_harness:prints(Store, "the peers here"),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {StoreOut, StoreErr} = ern_harness:said(Store),
    [ern_harness:has(Out, Line)
     || Line <- ["spawn: Right", "not listed: Io.NotListed",
                 "not loaded: Io.NotLoaded(\"the binding Lonely.greeting has no value here\")\n",
                 "names no binding: Right", "bindings: Right", "monitored: Returned",
                 "late: Io.Timeout", "no upper bound: Right"]],
    Spawned = desk_site("spawns", "spawn(\"store\", Lonely.speak"),
    ern_harness:has(StoreErr,
                    "the peer desk's spawn at " ++ Spawned ++ " was not loaded: the binding"
                    " Lonely.greeting has no value here"),
    ern_harness:has(StoreOut, "the store squares 49"),
    ern_harness:has(StoreOut, "the store squares 64"),
    ern_harness:has(StoreOut, "the peers here: [\"desk\", \"third\"]"),
    ?assertEqual(nomatch, string:find(StoreOut, "never initialized")).

%% report §8.7, §6.7, Appendix E.27, §11.2, E.21: work on a peer is a
%% function run there for its value, answered within the time or a failure.
%% A value comes back; a name that is no peer's answers NotListed; a
%% function whose binding has no value on the store answers NotLoaded, which
%% the store says, and the answer carries (Appendix E.1). A fault in the
%% function is the caller's, with the
%% function's cause, which the caller's node reports once, with the caller's
%% site and `, on the peer store` after the cause, its subscriber of faults
%% told of it with the peer, the trace that crossed with it beneath, then
%% the caller's frame, a cause stated with its rule (§7.4) as a raise's
%% (§7.3, a regression test), and the store reports nothing, its
%% subscriber told nothing.
%%
%% A process killed before it answers answers Other with its Reason. A
%% process whose caller ends while it waits, one whose function kills its
%% caller from the store, a kill the desk carries out as its own, which
%% reads the caller's call and sends its second note (§6.9), and one whose
%% time runs out, are killed on the store, whose watcher, monitoring each,
%% says so; and a process that ends with the store's program answers Other
%% with ProgramEnd. A regression test, written after the code, the kill
%% from the store's after the kill frame's; it reads no row of
%% either node's, which ern_rt_tests and ern_peer_tests read; it does not
%% cover a second note that comes before the compute's process could start,
%% which the store's gateway reads first, nor a loss while the caller
%% waits, which reconnect_test_'s is
compute_test_() ->
    ern_harness:nodes_test({waits, 10}, fun compute_on_peer/1).

compute_on_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    WaitDesk = ern_harness:start(Desk, DeskProgram, ["compute"]),
    ern_harness:prints(Store, "the abandoned compute's process ended: Killed"),
    ern_harness:prints(Store, "the killing compute's process ended: Killed"),
    ern_harness:prints(Store, "the timed-out compute's process ended: Killed"),
    ern_harness:prints(Desk, "now stop the store"),
    ern_harness:stop(Store, WaitStore),
    ?assertEqual(0, WaitDesk()),
    {Out, Err} = ern_harness:said(Desk),
    {StoreOut, StoreErr} = ern_harness:said(Store),
    Faulted = desk_site("faulted", "spawnMonitored(f, Died)"),
    RaisedCause = " foreign function erlang:binary_to_integer/1 raised error:badarg",
    Raised = RaisedCause ++ ", on the peer store",
    [ern_harness:has(Out, Line)
     || Line <- ["value: Right(42)", "not listed: Left(Io.NotListed)",
                 "not loaded: Left(Io.NotLoaded(\"the binding Lonely.greeting has no value"
                 " here\"))",
                 "divided: Fault(\"division by zero\")",
                 "reported here: " ++ Faulted ++ " division by zero Some(\"store\") true",
                 "raised: Fault(\"foreign function erlang:binary_to_integer/1 raised"
                 " error:badarg\")",
                 "reported here: " ++ Faulted ++ RaisedCause ++ " Some(\"store\") true",
                 "killed: Left(Io.Other(\"Killed\"))", "its caller killed from the store: Killed",
                 "timed out: Left(Io.Timeout)",
                 "with the store's end: Left(Io.Other(\"ProgramEnd\"))"]],
    Divided = "the process of " ++ Faulted ++ " faulted: division by zero, on the peer store\n",
    ?assertEqual(1, length(string:split(Err, Divided, all)) - 1),
    %% the function's frame on the store, then the caller's, which stand at
    %% one line here
    Division = desk_site("computes", "fn() = 1 / List.size([])"),
    ern_harness:has(Err, Divided ++ "    erlang:'div'/2\n    " ++ Division ++ "\n    " ++ Division
                         ++ "\n"),
    %% Appendix E.21: what the host says of the raise crosses with the
    %% trace, on its first line
    ern_harness:has(Err, "the process of " ++ Faulted ++ " faulted:" ++ Raised
                         ++ "\n    erlang:binary_to_integer/1, argument 1: not a textual"
                            " representation of an integer\n"),
    Computed = desk_site("computes", "compute(\"store\", Lonely.speak"),
    ern_harness:has(StoreErr,
                    "the peer desk's compute at " ++ Computed ++ " was not loaded: the binding"
                    " Lonely.greeting has no value here"),
    [?assertEqual(nomatch, string:find(Text, Part))
     || {Text, Part} <- [{StoreErr, "division by zero"}, {StoreErr, "badarg"},
                         {StoreOut, "the store's subscriber: division by zero"},
                         {StoreOut, "the store's subscriber: foreign function"}]].

%% report §8.7, §12.5, §12.8, Appendix E.27, Appendix C: how busy a peer is, on
%% one scale. A name that is no peer's answers NotListed. The store answers
%% the run queue's measure, 0.0 or more, and the host keeps no schedulers'
%% time there. An `ernest.conf` that names a `utilization` is refused as a
%% field the file does not know, by `ern reload` before it signals and by
%% the node at a hangup `kill -HUP` sends, the run queue measuring still.
%%
%% A regression test, written after the code; that the measure is the run
%% queue over the schedulers is read from the code, since an idle node
%% answers 0.0 or more
utilization_test_() ->
    ern_harness:nodes_test({waits, 11}, fun utilization_of_peer/1).

utilization_of_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["utilization"]),
    ern_harness:prints(Store, "the store keeps the schedulers' time at the start: false"),
    ern_harness:prints(Desk, "now refuse a reload"),
    ern_harness:edit(Store, fun(Conf) -> Conf#{<<"utilization">> => <<"run-queue">>} end),
    ?assertEqual({1, refused_reload(Store, "the file has the unknown field utilization")},
                 signaled("reload", Store)),
    hungup(Store),
    ern_harness:says(Store, "the reload was refused"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Store, "the store keeps the schedulers' time after the refusal: false"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    [ern_harness:has(Out, Line) || Line <- ["not listed: Left(Io.NotListed)", "run queue: true",
                                            "after the refusal: true"]],
    ern_harness:has(StoreErr, "the reload was refused, and the configuration stays as it was: "),
    ern_harness:has(StoreErr, "ernest.conf: the file has the unknown field utilization").

%% report §8.7, §6.5, §6.9, §12.2, §3.11: a correct program's messages make
%% no new atom on the node that receives them, a value of many shapes and
%% one of 8 MB among them. An address is as good on a third node, which
%% took it from the store and sends to it. An address of a node not listed
%% takes no send and gives a monitor Unreachable. A fault in an adapted
%% address's function is its target's.
%%
%% A monitor does not outlive a loss, a service monitor told of it as a
%% monitor is (§9.5), and the address does: a send after it reaches the
%% same process. With its node ended and its port taking the dial and
%% answering nothing, a send returns before the host gives the dial up, and
%% a monitor gives Unreachable. Once the node starts again, the address of
%% its earlier start is dead, a call through it ending before its time runs
%% out, a send to it dropped, a monitor giving Unknown, and an adapted
%% address it made dropping what is sent through it, its function not
%% applied.
%%
%% A regression test: the runtime hands each to the host, and this holds
%% that it does; and the new start applied the function of an adapted
%% address its earlier start made. The silent port is a regression test too:
%% the closed port refused the dial at once, so a send that waited behind
%% the dial passed unseen, and the send's bound was a chosen 1000 ms, which
%% failed under load. Not covered: a value crossing in pieces with other
%% senders' messages between them, a send that waits at a full buffer, and a
%% silence, which the detector finds in a minute
across_test_() ->
    ern_harness:nodes_test({waits, 12, ?DIAL_MS}, fun across/1).

across(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    ThirdProgram = filename:join(filename:dirname(DeskProgram), "third.erc"),
    {Store, Desk} = store_and_desk(Base),
    Third = filename:join(Base, "third"),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    WaitThird = ern_harness:start(Third, ThirdProgram, []),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["across"]),
    ern_harness:prints(Desk, "now kill the store"),
    {ok, Pid} = file:read_file(filename:join(Store, "ernest.pid")),
    _ = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(137, WaitStore()),
    ern_harness:prints(Desk, "now silence the store's port"),
    {_, Silent} = nothing_answered(listened(Store)),
    true = port_command(DeskPort, "go\n"),
    %% the desk's monitor of the counter gives its Down once the host has
    %% given up the dial the silent port takes (report §8.7)
    ern_harness:prints(Desk, "now restart the store", ?WAIT_MS + ?DIAL_MS),
    stop_holding(Silent),
    %% the first start's lines kept, since the second writes its own there
    ok = file:rename(Store ++ ".out", Store ++ ".first.out"),
    ok = file:rename(Store ++ ".err", Store ++ ".first.err"),
    WaitAgain = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitAgain),
    ern_harness:stop(Third, WaitThird),
    {Out, _} = ern_harness:said(Desk),
    {ThirdOut, _} = ern_harness:said(Third),
    [ern_harness:has(Out, Line)
     || Line <- ["new atoms: 0", "through the third node: 10", "not listed: Unreachable \"\"",
                 "adapted: Fault(\"negative\") \"\"", "severed: Unreachable \"\"",
                 "severed service: Unreachable \"\"",
                 "after the loss: 15", "killed: Unreachable \"\"", "send at once: true",
                 "out of reach: Unreachable \"\"", "old call: None true",
                 "old monitor: Unknown \"\"", "same process: false", "fresh total: 0",
                 "old adapted: 2"]],
    {ok, FirstErr} = file:read_file(Store ++ ".first.err"),
    ern_harness:has(binary_to_list(FirstErr), "the peer desk sent a frame this node cannot read"),
    ern_harness:has(ThirdOut, "sent through the third node"),
    ?assertEqual(nomatch, string:find(ThirdOut, "the echo got")).

%% report §8.7, §12.6, §6.6, §6.9: a call to a process of another node leaves a
%% note on that node while it waits, which goes however the call ends: a
%% request that faults its callee ends the call at once, through a restart
%% that reads the note, and a callForever faults with the callee's cause;
%% the callee's end drops it; a call whose time runs out, and one answered
%% from the caller's own node, send the second note; a loss drops every
%% note of the peer, and the call ends. A regression test, written after the
%% code: a request that faults its callee before the store's gateway has
%% the note is the race the note's order is there for, which a run may or
%% may not meet; and a sender waiting at a full buffer is not covered
calls_test_() ->
    ern_harness:nodes_test({waits, 5}, fun calls/1).

calls(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["calls"]))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["restarted: None true", "restarted forever: Fault(\"crashed\")",
                 "echo: Some(7)", "while it waits: 1", "its callee killed: Returned",
                 "after the callee's end: 0", "timed out: None 0", "answered here: Some(42) 0",
                 "waits again: 1", "its connection lost: Returned", "after the loss: 0"]].

%% report §6.9, §8.7: a restart of a process of another node is told to a
%% service monitor here: the store's herald, which a watcher on the desk
%% service-monitors and faults once, tells the watcher Restarted, its site
%% empty, before anything its new run sends; and a restart that a service
%% monitor's wrap on the desk holds up, waiting on a gate that never
%% answers, is held until the desk ends the connection by a frame the
%% store's gateway cannot read, the loss ending the store's wait, so that
%% the new run answers the desk's call after the loss.
%%
%% Report §6.9: "Where `p` dies while its restart waits, each delivery of
%% `Restarted` not yet placed ends with it, so no `Restarted` follows the
%% `Down` of `p`'s death": a third restart, which a wrap on the desk holds
%% up, and the herald killed from the desk while it waits, which its node
%% carries out as its own kill. The wrap's monitor is told Killed, and
%% once the wrap is let go and the process it ran in has ended, no
%% Restarted has come.
%%
%% The test's limit is the sum of its six waits, each bounded by the
%% harness's time for one wait: the build, the store's offer, the desk's
%% run, the store's end, and what each printed. A regression test, written
%% after the code, of the decision's program, on which 0.5.0 told the
%% watcher nothing and its next message was taken by the new run (the log's
%% *A Restart Told Across Nodes*). The kill's part is written with its fix:
%% under the code before it, the wrap's delivery placed Restarted after
%% Killed. It does not cover a restart of a process that another node only
%% monitors or calls, answered at once, which no program can tell from a
%% restart that tells no node, nor a telling whose watch dials a connection
%% lost since the host listed the monitor, which no test can place there
restart_told_test_() ->
    ern_harness:nodes_test({waits, 6}, fun restart_told/1).

restart_told(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["restart"]))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    [ern_harness:has(Out, Line)
     || Line <- ["the first run: a run began", "first after the crash: told Restarted \"\"",
                 "then: a run began", "the watcher: Returned", "the wrap holds the restart",
                 "severed: Unreachable \"\"", "the holding wrap: Unreachable \"\"",
                 "after the loss: Some(Unit)", "killed: Killed \"\"", "after the kill: nothing"]],
    ern_harness:has(StoreErr, "faulted, restarted: crashed").

%% report §8.7: a loss ends each wait on the peer that began before the
%% node ran it: the desk ends its connection to the store by a frame the
%% store's gateway cannot read while a call waits on a process of the
%% store's and a compute's process waits there, and the call ends with None
%% and the compute with Unreachable, each before its time, each node saying
%% it lost the other.
%%
%% Told then that both have run the loss, the desk's next call opens the
%% connection again, which each node says, and the waits that begin on it
%% are answered: the counter's address reaches the same process, its total
%% kept, and a compute, a spawn, a find and a utilization answer. A
%% regression test, written after the code; it does not cover a spawn's, a
%% find's or a utilization's wait at a loss, which no program can hold
%% open, a spawn's being ern_peer_tests' spawn_after_a_loss_test's, nor a
%% wait that begins in the gap before the node runs the loss, which the
%% loss ends as §8.7 says and no test can place there
reconnect_test_() ->
    ern_harness:nodes_test({waits, 10}, fun reconnect/1).

reconnect(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["reconnect"]),
    ern_harness:prints(Desk, "now open the connection again"),
    ern_harness:says(Desk, "the peer store was lost: it closed"),
    ern_harness:says(Store, "the peer desk was lost: it closed"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:prints(Store, "the store squares 36"),
    ern_harness:stop(Store, WaitStore),
    {Out, DeskErr} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    [ern_harness:has(Out, Line)
     || Line <- ["the call: None true", "the compute: Left(Io.Unreachable)",
                 "its caller: Returned", "its computer: Returned",
                 "the same process: Some(3)", "computed after: Right(42)",
                 "spawned after: Right", "found after: Right", "measured after: true"]],
    ern_harness:has(StoreErr,
                    "the peer desk sent a frame this node cannot read, and this node ends its"
                    " connection"),
    [?assertEqual(2, length(string:split(Err, Line, all)) - 1)
     || {Err, Line} <- [{DeskErr, "the peer store connected"},
                        {StoreErr, "the peer desk connected"}]].

%% report §8.4, §8.7: a check stands through a loss of its target's node,
%% since "that check lasts until the process the address names ends" and a
%% loss ends no address. Foreign code on the desk is given the address of a
%% taker the desk spawns on the store, and sends it 1, which the store takes.
%% The desk ends the connection as reconnect_test's does, and, told that
%% both nodes have run the loss, opens it again by a find. The process
%% foreign code was given lives; the address given again is given as the
%% same process, one check for each distinct address; and what foreign code
%% sends through it reaches the taker.
%%
%% Report §10, §12.9: no lookout, the check's second process while its
%% target's node is out of reach, which tells the check of that node's
%% connection, is left once the nodes have connected. The taker's end,
%% the connection open, then ends the check through the monitor it made
%% again, and no lookout is left.
%%
%% Written before its code, and red there: the check ended at the loss,
%% with the host's monitor of its target, the address given again was given
%% as another process, and what foreign code sent through the first was
%% lost. It does not cover a check made while the target's node is out of
%% reach, whose first monitor's dial is given up and which then takes the
%% loss's path, nor a node that never connects again, whose check stands
%% until the program ends
check_through_a_loss_test_() ->
    ern_harness:nodes_test({waits, 11}, fun check_through_a_loss/1).

check_through_a_loss(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["check-loss"]),
    ern_harness:prints(Store, "the taker took 1"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Desk, "now open the connection again"),
    ern_harness:says(Desk, "the peer store was lost: it closed"),
    ern_harness:says(Store, "the peer desk was lost: it closed"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Store, "the taker took 2"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:prints(Store, "the taker ends"),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["lost: Unreachable", "alive after the loss: true", "found after: Right",
                 "the same process: true", "lookouts once connected: 0", "its end: ended",
                 "lookouts at its end: 0"]].

%% report §8.4, §8.7: a check of a target that ends while its node is out
%% of reach stands until the nodes have connected again, and ends then. The
%% taker the desk spawns on the store ends at its Down of the desk's process,
%% which the loss gives there; told that both nodes have run the loss and
%% that the taker has ended, the desk opens the connection again by a find.
%% The process foreign code was given lived until then, and ends after.
%% Report §10, §12.9: no lookout is left at the check's end.
%%
%% Written before its code, and red there: the check ended at the loss, and
%% the process foreign code was given was dead before the nodes connected
%% again. It does not cover a node that started anew meanwhile, whose
%% process the check's monitor made again finds no more, as it finds no
%% more a process that ended
check_of_an_end_out_of_reach_test_() ->
    ern_harness:nodes_test({waits, 10}, fun check_of_an_end_out_of_reach/1).

check_of_an_end_out_of_reach(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["check-unreached"]),
    ern_harness:prints(Store, "the taker took 1"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Desk, "now open the connection again"),
    ern_harness:says(Desk, "the peer store was lost: it closed"),
    ern_harness:says(Store, "the peer desk was lost: it closed"),
    ern_harness:prints(Store, "the taker ends"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["lost: Unreachable", "alive after the loss: true", "found after: Right",
                 "its end: ended", "lookouts at its end: 0"]].

%% report §8.4: a check ends at the end of its target on another node, the
%% connection open: the taker the desk spawns on the store is sent 1
%% through the process foreign code was given, which the store takes, and
%% then ends, and that process ends. Report §10, §12.9: no lookout is
%% made, the target's node in reach.
%%
%% Written before its code, and green there, since the check ended at any
%% end of the host's monitor of its target; it holds that a check whose
%% target's node is never lost still ends as it did. It does not cover a
%% target that ends as the connection is lost, which the host's monitor
%% tells as the loss
check_ends_with_its_target_test_() ->
    ern_harness:nodes_test({waits, 7}, fun check_ends_with_its_target/1).

check_ends_with_its_target(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["check-end"]),
    ern_harness:prints(Store, "the taker took 1"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:prints(Store, "the taker ends"),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line) || Line <- ["its end: ended", "lookouts at its end: 0"]].

%% report §8.4, Appendix E.21, §6.9: an address of the program's that
%% foreign code gives back at another type than it crossed at is foreign,
%% and names the process behind the check in front of it on every node.
%% Foreign code on the desk gives back so the address of P, a process of
%% the desk's, and the address crosses to the store in a compute's captures
%% and a spawn's. There `Process.fromAddress` of it is P; a kill of that
%% ends P; and a monitor of it is told P's end, Killed, its site empty as
%% any process of another node's is.
%%
%% Report §6.5, §8.4: a fault in the function of an adapted address made
%% there over it is P's, `division by zero`, and so is a bad message
%% foreign code there sends to such an address, at that address's type,
%% Bool. Report §6.6: a callForever there through it ends with P's cause
%% where P faults, and with `callee was killed` where P is killed, and a
%% call there ends at once at P's restart.
%%
%% Written before its code, and red there: on the store the address named
%% the check, which only the desk can take to P. `fromAddress` answered the
%% check, a kill of it ended nothing, and a monitor of it was told the
%% check's end, Returned. The fault in the function and the bad message
%% reached the check as messages, which it found no AskedMsg, so P faulted
%% with the check's cause. Each callForever ended with `callee returned
%% without answering`, and the call waited its whole time
retyped_address_on_another_node_test_() ->
    ern_harness:nodes_test({waits, 5}, fun retyped_address_on_another_node/1).

retyped_address_on_another_node(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["retyped"]))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["there, the process behind it is P: Right(true)",
                 "the monitor there: true Killed \"\"",
                 "a fault in f there: Fault(\"division by zero\")",
                 "a bad message there: Fault(\"message does not match Bool\")",
                 "callForever there, its callee faulted: Right(Left(Fault(\"crashed\")))",
                 "callForever there, its callee killed: Left(Fault(\"callee was killed\"))",
                 "killed there: Killed",
                 "a call there, its callee restarted: Right(\"None true\")"]].

%% report §8.4, §6.4, §8.7, Appendix E.21: an address of the program's that
%% foreign code gives back at the type it crossed at is the program's own,
%% the process behind it on another node too. Foreign code on the desk gives
%% back so the address of Q, a process the desk spawns on the store. Notes
%% one process of the desk's sends in turn through it and through Q's own
%% address come in the order sent; each, sent to Q through the other, names
%% Q there; and a call through it that Q answers with its own address
%% answers Q on the desk. What held before still holds: given to foreign
%% code again, it is given as the same process, one check for each distinct
%% address, and a term of no type foreign code sends through that faults Q
%% with Q's type.
%%
%% Written before its code, and red there: the address was held foreign,
%% since Q has no row on the desk, so what the desk sent through it crossed
%% into foreign code and was checked again. The notes came out of order;
%% each address sent through the other reached Q as a check, which Q did
%% not name; and Q's answer reached the desk as a check on the store
given_back_from_another_node_test_() ->
    ern_harness:nodes_test({waits, 5}, fun given_back_from_another_node/1).

given_back_from_another_node(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["given-back"]))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["in turn through both, in order: true", "q through the address given back: true",
                 "the address given back through q: true", "answered through it: Some(true)",
                 "given again, the same process: true",
                 "a term of no type through it:"
                 " Fault(\"message does not match Desk.RecorderMsg\")"]].

%% report §6.5, §8.7: the function of an adapted address made on the store,
%% sent to from the desk, runs on the store in the process the store keeps
%% for the address and the desk, so that one that calls a process there,
%% which answers only once it is opened, holds the desk's messages to that
%% address and nothing else: a find passes it, and so does a message to a
%% second adapted address made there, which opens the gate, and the answer
%% comes back to the desk through the first. A regression test, written
%% after the code: the store's gateway applied the function in its worker
%% for the desk, which then read nothing more from the desk; a function
%% that never finishes, which ends with the program, is
%% src/runtime/test/ern_rt_tests.erl's, and the order of one address's
%% messages and the worker's count src/nodes/test/ern_gateway_tests.erl's
adapted_calls_test_() ->
    ern_harness:nodes_test({waits, 5}, fun adapted_calls/1).

adapted_calls(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["gated"]))()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["found meanwhile: Right", "through the gate: 50", "gated: Returned"]].

%% `ern <job> --config-dir Dir` run as a person runs it: its status, and
%% what it said.
signaled(Job, Dir) ->
    finished(?ERN ++ " " ++ Job ++ " --config-dir " ++ Dir ++ " 2>&1").

%% Report §11.2: what `ern reload` says of a file in Dir the node would
%% refuse, Refusal, refused before it signals.
refused_reload(Dir, Refusal) ->
    "ern reload: " ++ ern_build:shown(filename:join(Dir, "ernest.conf")) ++ ": " ++ Refusal
        ++ "\n".

%% Report §12.5: a node sent hangup by the process its ernest.pid names, as
%% `kill -HUP` sends it, which reads no configuration before the node does.
hungup(Dir) ->
    [] = os:cmd("kill -HUP " ++ pid(Dir)),
    ok.

%% report §8.6, §8.7, §12.5, §11.2: `ern stop` sends the node its directory names
%% termination, saying only that it was delivered; the node stops in order,
%% so that a monitor made on its process before gives ProgramEnd, and one
%% made once it has stopped gives Unreachable; the node ends by the signal
%% and its ernest.pid goes. A regression test, written after the code; it
%% does not cover a peer that falls silent while the node stops
stop_test_() ->
    ern_harness:nodes_test({waits, 8}, fun stop_in_order/1).

stop_in_order(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["ending"]),
    ern_harness:prints(Desk, "watching"),
    ?assertMatch({0, _}, signaled("stop", Store)),
    ?assertEqual(143, WaitStore()),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    {Out, _} = ern_harness:said(Desk),
    ern_harness:has(Out, "ended: ProgramEnd \"\""),
    ern_harness:has(Out, "after: Unreachable \"\""),
    ?assertNot(filelib:is_file(filename:join(Store, "ernest.pid"))),
    {Status, Said} = signaled("stop", Store),
    ?assertEqual(1, Status),
    ern_harness:has(Said, "ernest.pid: no such file or directory: no node runs from the directory").

%% report §12.5, §11.2: a node holds ernest.pid locked until its process
%% has ended, however it ends, and the file is removed then: a node killed
%% leaves no file. A file no node holds, as one a node whose machine stopped
%% leaves, made here by hand, is taken by the next start from the
%% directory, saying nothing of a refusal, the file holding the new node's
%% number; a running node refuses a second start, naming its number; and
%% where the file names a living process that is no node, `ern stop` and
%% `ern reload` fail, saying that no node holds it, and the process is sent
%% nothing.
%%
%% A regression test, written after the code (the log's *MVP 3.1 Read*): a
%% start was refused by a file whose number a living process held, and the
%% jobs signaled that process; and a node killed left its file
pid_lock_test_() ->
    ern_harness:nodes_test({waits, 12}, fun pid_lock/1).

pid_lock(Base) ->
    A = ern_harness:made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Program = ern_harness:program(filename:join(Base, "build")),
    WaitKilled = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    {ok, Killed} = file:read_file(PidFile),
    [] = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Killed))),
    ?assertEqual(137, WaitKilled()),
    _ = ern_harness:said(A),
    ?assertNot(filelib:is_file(PidFile)),
    ok = file:write_file(PidFile, Killed),
    WaitA = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    {ok, Number} = file:read_file(PidFile),
    ?assertNotEqual(Killed, Number),
    {1, Again} = finished(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1"),
    ern_harness:has(Again, " is the configuration directory of the running node "
                           ++ string:trim(binary_to_list(Number)) ++ ", which ernest.pid names"),
    ern_harness:stop(A, WaitA),
    {_, Err} = ern_harness:said(A),
    ?assertEqual(nomatch, string:find(Err, "configuration directory")),
    %% a living process that is no node, which reads its input and echoes it,
    %% named once it has echoed: until it first runs, the process the host
    %% forks ignores the termination, and one sent it then would not show
    %% (docs/otp_bugs.md, 22)
    Living = open_port({spawn_executable, os:find_executable("cat")}, [binary]),
    true = port_command(Living, <<"running">>),
    ?assertEqual(<<"running">>, output(Living)),
    {os_pid, LivingNumber} = erlang:port_info(Living, os_pid),
    ok = file:write_file(PidFile, integer_to_list(LivingNumber) ++ "\n"),
    [begin
         {Status, Said} = signaled(Job, A),
         ?assertEqual(1, Status),
         ern_harness:has(Said, "ernest.pid: no node holds it: no node runs from the directory")
     end || Job <- ["stop", "reload"]],
    true = port_command(Living, <<"alive">>),
    ?assertEqual(<<"alive">>, output(Living)),
    port_close(Living).

%% report §11.2, §8.6, §12.5: `ern stop` returns once the node has ended,
%% which it waits for on the lock the node holds on ernest.pid, with status
%% 0: a node whose end waits for a subscriber is still running, its file
%% there, until the subscriber answers, and the job returns with the node
%% gone, its file removed, and the next `ern run` from the directory
%% accepted at once; a second `ern stop` while the first waits is a second
%% termination, which ends the node at once, and both return. A regression
%% test, written after the code (the log's *MVP 3.1 Read*): the job returned
%% once the signal was sent, and a script's next start was refused by the
%% node still ending
stop_waits_test_() ->
    ern_harness:nodes_test({waits, 12}, fun stop_waits/1).

stop_waits(Base) ->
    A = ern_harness:made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Program = stopping(Base),
    %% a stop begun, and what waits for what it said once it has returned
    Stopping = fun() -> begun(?ERN ++ " stop --config-dir " ++ A ++ " 2>&1") end,
    {Port, Wait} = ern_harness:started(A, Program, []),
    ern_harness:prints(A, "subscribed"),
    Stopped = Stopping(),
    ern_harness:prints(A, "told"),
    ?assert(filelib:is_file(PidFile)),
    true = port_command(Port, "go\n"),
    ?assertMatch({0, _}, Stopped()),
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, Wait()),
    {_, Err} = ern_harness:said(A),
    ern_harness:has(Err, "the subscriber Stopping.main answered"),
    %% the next start, and two stops
    {_Port, WaitAgain} = ern_harness:started(A, Program, []),
    ern_harness:prints(A, "subscribed"),
    First = Stopping(),
    ern_harness:prints(A, "told"),
    Second = Stopping(),
    [?assertMatch({0, _}, Stop()) || Stop <- [First, Second]],
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, WaitAgain()),
    {_, ErrAgain} = ern_harness:said(A),
    ern_harness:has(ErrAgain, "the end was cut short, 1 subscriber unanswered: Stopping.main").

%% Report §8.6: a program whose subscriber of the end answers once a line
%% comes, built under Base: one step. Answers its compiled form.
stopping(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "stopping.ern"), <<"
// Report §8.6: a subscriber of the end that answers once a line comes.

type Msg = Terminating(Reply(Unit))

export fn main() : Unit receiving Msg = {
    Os.subscribeTermination(Terminating);
    Io.println(\"subscribed\");
    receive {
        Terminating(reply) -> {
            Io.println(\"told\");
            let _ = Io.readLine();
            answer(reply, Unit)
        }
    }
}
"/utf8>>),
    0 = ern_harness:built([Root]),
    filename:join(Root, "stopping.erc").

%% report §12.5, §11.2, §8.6: a node killed while `ern stop` waits for its
%% end, which a subscriber holds, ends the wait: the stop returns with
%% status 0 once the node's process has ended, its ernest.pid removed
%% before the lock was let go. A regression test, written after the code:
%% the file stayed after a kill. It does not cover a kill that takes the
%% lock's helper with the node, a whole group's or a service manager's,
%% which leaves the file for the next start
killed_while_stopped_test_() ->
    ern_harness:nodes_test({waits, 5}, fun killed_while_stopped/1).

killed_while_stopped(Base) ->
    A = ern_harness:made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Wait = ern_harness:start(A, stopping(Base), []),
    ern_harness:prints(A, "subscribed"),
    Stopped = begun(?ERN ++ " stop --config-dir " ++ A ++ " 2>&1"),
    %% told once the stop has sent the termination, after which it waits
    %% on the lock
    ern_harness:prints(A, "told"),
    {ok, Number} = file:read_file(PidFile),
    [] = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Number))),
    ?assertMatch({0, _}, Stopped()),
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(137, Wait()).

%% report §12.5, §11.2, §8.6, Appendix E.18: a node whose program ends
%% with more written to a socket than its client has taken ends with status
%% 0 once the program has said its last line, while the client has read
%% nothing; its process has ended and its ernest.pid is gone. The client
%% then takes fewer bytes than were written, the socket's being sent only
%% until the runtime stops, and meets the connection's end.
%%
%% A regression test, written after the code: the job's halt ran the
%% host's flush, which waited without a limit for the socket's port to
%% write what it held, so that the node was held until the client read. It
%% does not cover a socket over TLS, a client that reads slowly, nor a node
%% ended by a termination or by `ern stop`, and it does not count the bytes
%% the kernel's buffers took, which no rule states. A plain run's end is
%% ern_integration_tests's run_ends_over_an_unread_socket_test_.
node_ends_over_an_unread_socket_test_() ->
    ern_harness:nodes_test({waits, 8}, fun node_ends_over_an_unread_socket/1).

node_ends_over_an_unread_socket(Base) ->
    A = ern_harness:made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Megabytes = 32,
    {Input, Wait} = ern_harness:started(A, ern_harness:unread_writer(filename:join(Base, "build")),
                                        [integer_to_list(Megabytes)]),
    ern_harness:prints(A, "listening on "),
    {match, [Port]} = re:run(ern_harness:written(A, out), "listening on 127\\.0\\.0\\.1:([0-9]+)\n",
                             [{capture, all_but_first, list}]),
    Client = ern_harness:connected(list_to_integer(Port), []),
    ern_harness:prints(A, "accepted"),
    {ok, Text} = file:read_file(PidFile),
    Number = list_to_integer(string:trim(binary_to_list(Text))),
    true = port_command(Input, "go\n"),
    ern_harness:prints(A, "served: Right(Unit)"),
    ?assertEqual(0, Wait()),
    _ = ern_harness:said(A),
    ?assertEqual(none, ern_os:signal(0, Number)),
    ?assertNot(filelib:is_file(PidFile)),
    {Taken, End} = ern_harness:read_to_its_end(Client),
    ?assert(Taken < Megabytes * 1048576),
    ?assert(lists:member(End, [closed, econnreset])),
    ok = gen_tcp:close(Client).

%% report §8.6, §12.5, §11.2: a termination once the end has begun ends
%% the node at once, with the status of what began the end, where the end
%% waits for a stream whose reader takes nothing to be written out. Here
%% main's return began it, and the stream is standard output; the node
%% ends with status 0. While the end waits, the node's ernest.pid is there
%% and locked; once `ern stop` has returned, the node has ended and the
%% file is gone. The program's end shows as the connection its process
%% held closed, which the end closes with the program's processes.
termination_ends_a_stalled_flush_test_() ->
    ern_harness:nodes_test({waits, 5}, fun termination_ends_a_stalled_flush/1).

termination_ends_a_stalled_flush(Base) ->
    {A, Node, Socket, Holder} = stalled(Base, out, "return"),
    try
        ?assertEqual({error, closed}, ern_harness:received(Socket, 0)),
        PidFile = filename:join(A, "ernest.pid"),
        ?assertEqual(sent, ern_os:node_signaled(PidFile, 0, false)),
        Stopped = begun(?ERN ++ " stop --config-dir " ++ A ++ " 2>&1"),
        ?assertMatch({0, _}, Stopped()),
        ?assertMatch({0, _}, ern_harness:collected(Node, 1)),
        ?assertNot(filelib:is_file(PidFile))
    after
        ern_harness:closed(Holder)
    end.

%% report §8.6, §12.5, §11.2: the same where a first `ern stop` began the
%% end, the stream standard error: the second `ern stop` is a second
%% termination, which ends the node at once with the signal's status, 143,
%% and each stop returns once the node has ended. The program says on the
%% connection that its write was taken before the first stop is sent.
second_stop_ends_a_stalled_flush_test_() ->
    ern_harness:nodes_test({waits, 7}, fun second_stop_ends_a_stalled_flush/1).

second_stop_ends_a_stalled_flush(Base) ->
    {A, Node, Socket, Holder} = stalled(Base, err, "wait"),
    try
        ?assertEqual({ok, <<"written\n">>}, ern_harness:received(Socket, 8)),
        Stop = ?ERN ++ " stop --config-dir " ++ A ++ " 2>&1",
        First = begun(Stop),
        ?assertEqual({error, closed}, ern_harness:received(Socket, 0)),
        PidFile = filename:join(A, "ernest.pid"),
        ?assertEqual(sent, ern_os:node_signaled(PidFile, 0, false)),
        Second = begun(Stop),
        ?assertMatch({0, _}, Second()),
        ?assertMatch({0, _}, First()),
        ?assertMatch({143, _}, ern_harness:collected(Node, 1)),
        ?assertNot(filelib:is_file(PidFile))
    after
        ern_harness:closed(Holder)
    end.

%% A node of Base's directory a running held_writer/1, given Stream and
%% Ending (held_run/5), with no subscriber: the directory, the port that
%% started it, the program's connection and the holder of its stalled
%% stream's reading end. Two steps.
stalled(Base, Stream, Ending) ->
    A = ern_harness:made(Base, "a", none),
    Program = held_writer(filename:join(Base, "build")),
    {Node, Socket, Holder} = held_run(A, [" --config-dir ", A], Program, Stream, Ending),
    {A, Node, Socket, Holder}.

%% Program run by `ern run` with Options before it, given the port of a
%% listener of the test's, Stream and Arguments, the program's arguments
%% after them; its Stream, out or err, the pipe Dir names with `.pipe`
%% after it, whose reading end is held open and not read, its other
%% stream the port's: the port that started the run, whose writes are its
%% standard input, the program's connection, which the test has taken, and
%% the holder of the reading end, which holds it until its input ends, or
%% until a line comes, when it reads the pipe to its end and writes what it
%% read. The run is the port's own process, so that no shell between them
%% writes of a signal's end to the pipe and waits there. The program is
%% sent the line that has it write. One step.
held_run(Dir, Options, Program, Stream, Arguments) ->
    {Run, [Socket], Holder} = held_run(Dir, Options, Program, Stream, Arguments, 1),
    {Run, Socket, Holder}.

%% The same, the program's Count connections taken in the order they came:
%% Count steps.
held_run(Dir, Options, Program, Stream, Arguments, Count) ->
    {ok, Listener} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listener),
    Pipe = Dir ++ ".pipe",
    [] = os:cmd("mkfifo " ++ Pipe),
    Redirected = case Stream of
                     out -> " 2>&1 > " ++ Pipe;
                     err -> " 2> " ++ Pipe
                 end,
    Command = lists:flatten(["exec ", ?ERN, " run", Options, " ", Program, " ",
                             integer_to_list(Port), " ", atom_to_list(Stream), " ", Arguments,
                             Redirected]),
    Run = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status, binary]),
    Holder = open_port({spawn_executable, "/bin/sh"},
                       [{args, ["-c", "exec 3< " ++ Pipe ++ "; read line && exec cat <&3"]},
                        exit_status, binary]),
    Sockets = [ern_harness:accepted(Listener) || _ <- lists:seq(1, Count)],
    ok = gen_tcp:close(Listener),
    true = port_command(Run, "go\n"),
    {Run, Sockets, Holder}.

%% Report §8.6: a program whose process of its own holds a connection to
%% the port of the loopback interface its first argument names until the
%% program's end, and that, once a line comes, writes a megabyte to the
%% stream its second argument names, `out` or `err`; then, where its third
%% is `return`, it returns, and where it is `wait`, the holder says
%% `written` on the connection and the program waits for another line.
%% Where a fourth, `subscribed`, follows, its end waits for a subscriber
%% that never answers: once the end tells it, the holder says `told`, and
%% where the third is `exit` calls Os.exit(7). Built in Root: one step.
%% Answers its compiled form.
-spec held_writer(file:filename()) -> file:filename().
held_writer(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "held_writer.ern"), [<<"
// Report §8.6: a program whose process of its own holds a connection
// until the program's end, and that writes a megabyte to the stream it is
// given once a line comes, then returns or waits for another line. Where
// it is asked to, its end waits for a subscriber that never answers; once
// the end tells it, the holder says so, and calls Os.exit where asked to.

type MainMsg = Subscribed

type HoldMsg = Written | Told

type SubscriberMsg = Terminating(Reply(Unit))

export fn main() : Unit receiving MainMsg =
    match Os.arguments {
        [port, stream, ending] -> started(port, stream, ending, false)
      | [port, stream, ending, \"subscribed\"] -> started(port, stream, ending, true)
      | _ -> Io.printlnError(\"usage: port out|err return|wait|exit [subscribed]\")
    }

fn started(port : String,
           stream : String,
           ending : String,
           subscribed : Bool) : Unit receiving MainMsg =
    match String.toInt(port) {
        Some(number) -> writeMegabyte(number, stream, ending, subscribed)
      | None -> Io.printlnError(\"not a port: \" <> port)
    }

fn writeMegabyte(port : Int,
                 stream : String,
                 ending : String,
                 subscribed : Bool) : Unit receiving MainMsg = {
    let holder = spawn(fn() = hold(port, ending));
    if subscribed then subscribe(holder) else Unit;
    let _ = Io.readLine();
    let megabyte = Bytes.repeat(<<120>>, 1048576);
    match stream {
        \"err\" -> Io.writeError(megabyte)
      | _ -> Io.write(megabyte)
    };
    match ending {
        \"wait\" -> {
            send(holder, Written);
            let _ = Io.readLine();
            Unit
        }
      | _ ->
            Unit
    }
}

fn subscribe(holder : Address(HoldMsg)) : Unit receiving MainMsg = {
    let me = self();
    let _ = spawn(fn() = subscriber(holder, me));
    receive {
        Subscribed -> Unit
    }
}

fn subscriber(holder : Address(HoldMsg), main : Address(MainMsg)) : Unit receiving SubscriberMsg = {
    Os.subscribeTermination(Terminating);
    send(main, Subscribed);
    receive {
        Terminating(_) -> {
            send(holder, Told);
            unanswered()
        }
    }
}

fn unanswered() : Unit receiving SubscriberMsg =
    receive {
        Terminating(_) -> unanswered()
    }

fn hold(port : Int, ending : String) : Unit receiving HoldMsg =
    match Tcp.connect(\"127.0.0.1\", port, waitMs()) {
        Right(socket) -> holding(socket, ending)
      | Left(error) -> Io.printlnError(\"not connected: \" <> Io.show(error))
    }

fn holding(socket : Address(Tcp.SocketMsg), ending : String) : Unit receiving HoldMsg =
    receive {
        Written -> {
            said(socket, \"written\");
            holding(socket, ending)
        }
      | Told -> {
            said(socket, \"told\");
            match ending {
                \"exit\" -> Os.exit(7)
              | _ -> holding(socket, ending)
            }
        }
    }

fn said(socket : Address(Tcp.SocketMsg), text : String) : Unit = {
    let _ = Tcp.write(socket, String.toUtf8(text <> \"\\n\"), waitMs());
    Unit
}
"/utf8>>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    filename:join(Root, "held_writer.erc").

%% report §8.6, §11.2: the runner says each line of the end's wait without
%% waiting for standard error to take it, so a stream whose reader takes
%% nothing holds the runner at no line of the wait, and the runner reads
%% every word. Here
%% main's return begins the end, whose one subscriber never answers. The
%% subscriber is told, which it says on the connection, also where standard
%% error is the stalled stream. A termination cuts the wait, also where
%% standard output is the stalled stream and standard error, which says
%% that the wait was cut short, waits behind it.
%%
%% The end's flush then lasts, the program's processes ended, which closes
%% the connection, and a second termination ends the run with the return's
%% status, 0. A plain run and a node, each stream stalled. That the run
%% stays in its flush is read at one moment, once the connection has
%% closed, by a signal 0 that reaches the run's process.
termination_cuts_a_stalled_wait_test_() ->
    ern_harness:nodes_test({waits, 17}, fun termination_cuts_a_stalled_wait/1).

termination_cuts_a_stalled_wait(Base) ->
    Program = held_writer(filename:join(Base, "build")),
    lists:foreach(fun({Kind, Stream}) ->
                      waited_run(Base, Kind, Program, Stream, "return",
                                 fun(Run, Socket) ->
                                     ?assertEqual({ok, <<"told\n">>},
                                                  ern_harness:received(Socket, 5)),
                                     cut_and_ended(Run, Socket, 0)
                                 end)
                  end, stalled_runs()).

%% report §8.6, §11.2: the same where a first termination began the end,
%% once the program has said on the connection that its write was taken:
%% the subscriber is told, a second termination cuts the wait, and a third
%% ends the run with the signal's status, 143.
second_termination_cuts_a_stalled_wait_test_() ->
    ern_harness:nodes_test({waits, 21}, fun second_termination_cuts_a_stalled_wait/1).

second_termination_cuts_a_stalled_wait(Base) ->
    Program = held_writer(filename:join(Base, "build")),
    lists:foreach(fun({Kind, Stream}) ->
                      waited_run(Base, Kind, Program, Stream, "wait",
                                 fun(Run, Socket) ->
                                     ?assertEqual({ok, <<"written\n">>},
                                                  ern_harness:received(Socket, 8)),
                                     true = ern_harness:run_signaled(Run, "TERM"),
                                     ?assertEqual({ok, <<"told\n">>},
                                                  ern_harness:received(Socket, 5)),
                                     cut_and_ended(Run, Socket, 143)
                                 end)
                  end, stalled_runs()).

%% report §8.6, §11.2, Appendix E.23: an Os.exit while the end waits is
%% read at once, the stalled stream holding the wait's first line. Main's
%% return begins the end; once the subscriber is told, the program's process
%% that holds the connection says so and calls Os.exit(7). The wait is cut,
%% the end's flush lasts, and a termination ends the run with the exit's
%% status, which stands.
exit_cuts_a_stalled_wait_test_() ->
    ern_harness:nodes_test({waits, 17}, fun exit_cuts_a_stalled_wait/1).

exit_cuts_a_stalled_wait(Base) ->
    Program = held_writer(filename:join(Base, "build")),
    lists:foreach(fun({Kind, Stream}) ->
                      waited_run(Base, Kind, Program, Stream, "exit",
                                 fun(Run, Socket) ->
                                     ?assertEqual({ok, <<"told\n">>},
                                                  ern_harness:received(Socket, 5)),
                                     flushed_and_ended(Run, Socket, 7)
                                 end)
                  end, stalled_runs()).

%% report §8.6, §6.5, §12.6: an Os.exit once the end's wait is over ends
%% the node with its status, and the end's flush goes on. A node's main
%% writes a megabyte to the stream that stalls and returns, its end waiting
%% for no subscriber. Once the end has ended the program's processes, which
%% closes the program's connection, a peer sends 7 to an adapted address the
%% node made, and the node's process kept for the address applies its
%% function, which tells the peer's process and calls Os.exit(7); the
%% peer's process says so on its own connection. The other stream cannot
%% carry the word, since the host writes both through one thread, which the
%% stalled one holds. The node is still in its flush; once the stalled
%% stream's reader reads, the megabyte comes out whole and the node ends
%% with the exit's status, 7. Each stream stalled.
exit_after_the_wait_test_() ->
    ern_harness:nodes_test({waits, 16}, fun exit_after_the_wait/1).

exit_after_the_wait(Base) ->
    kept_exits(Base, fun(Run, Holder) ->
                         true = port_command(Holder, "read\n"),
                         ?assertMatch({7, _}, ern_harness:collected(Run, 1)),
                         {0, Read} = ern_harness:collected(Holder, 1),
                         ?assertNotEqual(nomatch,
                                         binary:match(Read, binary:copy(<<"x">>, 1048576)))
                     end).

%% report §8.6, §12.4, §11.8: the same, a termination ending the stalled
%% flush in place of the reader: the node ends with the exit's status, 7,
%% which stands through the termination, and not with the return's 0.
termination_after_a_late_exit_test_() ->
    ern_harness:nodes_test({waits, 14}, fun termination_after_a_late_exit/1).

termination_after_a_late_exit(Base) ->
    kept_exits(Base, fun(Run, _Holder) ->
                         true = ern_harness:run_signaled(Run, "TERM"),
                         ?assertMatch({7, _}, ern_harness:collected(Run, 1))
                     end).

%% Check run on a node of kept_exiter/1's program from a directory of its
%% own under Base, first with standard error stalled and then with standard
%% output, beside one bare node, b, which lists both and is stopped after
%% (kept_exit/4). Four steps beside each run's.
kept_exits(Base, Check) ->
    Program = kept_exiter(filename:join(Base, "build")),
    Nodes = [{Stream, ern_harness:made(Base, "a_" ++ atom_to_list(Stream), none)}
             || Stream <- [err, out]],
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{filename:basename(A), A, none} || {_, A} <- Nodes]),
    WaitB = ern_harness:bare_started(B, []),
    PortB = ern_harness:bound_port(B),
    lists:foreach(fun({Stream, A}) ->
                      ern_harness:lists(A, [{"b", B, PortB}]),
                      kept_exit(A, Program, Stream, Check)
                  end, Nodes),
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()).

%% Check run on the node of A's directory, Program given Stream and the
%% peer b (held_run/6), once its end's wait is over and its process kept
%% for the address b sends to has told b's process that it calls Os.exit,
%% which b's process says on its connection, the node still running; given
%% the run's port and the holder of the stalled stream's reading end, both
%% closed after, however Check ended. Four steps beside Check's.
kept_exit(A, Program, Stream, Check) ->
    {Run, [Held, Firer], Holder} = held_run(A, [" --config-dir ", A], Program, Stream, "b", 2),
    try
        ?assertEqual({error, closed}, ern_harness:received(Held, 0)),
        ok = gen_tcp:send(Firer, <<"fire\n">>),
        ?assertEqual({ok, <<"exiting\n">>}, ern_harness:received(Firer, 8)),
        ?assert(ern_harness:run_signaled(Run, "0")),
        Check(Run, Holder)
    after
        ern_harness:closed(Holder),
        ern_harness:closed(Run)
    end.

%% Report §8.6, §6.5: a program whose process of its own holds a connection
%% to the port of the loopback interface its first argument names until the
%% program's end, and that then spawns on the peer its third names a process
%% that connects to the port too and, once a line comes on its connection,
%% sends an adapted address of this node's 7 and its own address. The
%% address's function tells the peer's process, which says `exiting` on its
%% connection, and calls Os.exit with the status it is sent. Once a line
%% comes on standard input, the program writes a megabyte to the stream its
%% second argument names, `out` or `err`, and returns. Built in Root: one
%% step. Answers its compiled form.
-spec kept_exiter(file:filename()) -> file:filename().
kept_exiter(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "kept_exiter.ern"), [<<"
// Report §8.6, §6.5: a program whose process of its own holds a connection
// until the program's end, and that spawns on a peer a process that sends
// an adapted address of this node's a status, whose function tells the
// peer's process and calls Os.exit with the status. Once a line comes, the
// program writes a megabyte to the stream it is given and returns.

type MainMsg = Connected

type ExitMsg = Exit(firer : Address(Unit), status : Int)

export fn main() : Unit receiving MainMsg =
    match Os.arguments {
        [port, stream, peer] -> started(port, stream, peer)
      | _ -> Io.printlnError(\"usage: port out|err peer\")
    }

fn started(port : String, stream : String, peer : String) : Unit receiving MainMsg =
    match String.toInt(port) {
        Some(number) -> writeMegabyte(number, stream, peer)
      | None -> Io.printlnError(\"not a port: \" <> port)
    }

fn writeMegabyte(port : Int, stream : String, peer : String) : Unit receiving MainMsg = {
    let me = self();
    let _ = spawn(fn() = hold(port, me));
    receive {
        Connected -> Unit
    };
    let exiter = adapted(me, exiting);
    match Peer.spawn(peer, fn() = fire(exiter, port), waitMs()) {
        Right(_) -> Unit
      | Left(error) -> Io.printlnError(\"not spawned: \" <> Io.show(error))
    };
    let _ = Io.readLine();
    let megabyte = Bytes.repeat(<<120>>, 1048576);
    match stream {
        \"err\" -> Io.writeError(megabyte)
      | _ -> Io.write(megabyte)
    }
}

// Report §8.6: tells the peer's process that it calls Os.exit, and calls
// it with the status it is sent.
fn exiting(message : ExitMsg) : MainMsg =
    match message {
        Exit(firer = firer, status = status) -> {
            send(firer, Unit);
            Os.exit(status)
        }
    }

// Report §8.6: the connection held until the program's end ends this
// process, which closes it.
fn hold(port : Int, main : Address(MainMsg)) : Unit receiving Unit =
    match Tcp.connect(\"127.0.0.1\", port, waitMs()) {
        Right(_) -> {
            send(main, Connected);
            held()
        }
      | Left(error) -> Io.printlnError(\"not connected: \" <> Io.show(error))
    }

fn held() : Unit receiving Unit =
    receive {
        _ -> held()
    }

// Report §6.5, §8.7: on the peer, a process that connects, and once a line
// comes sends the address 7 and its own address, which the node that made
// the address applies; once told, it says so on its connection.
fn fire(exiter : Address(ExitMsg), port : Int) : Unit receiving Unit =
    match Tcp.connect(\"127.0.0.1\", port, waitMs()) {
        Right(socket) -> {
            let _ = Tcp.read(socket, waitMs());
            send(exiter, Exit(firer = self(), status = 7));
            receive {
                Unit -> {
                    let _ = Tcp.write(socket, String.toUtf8(\"exiting\\n\"), waitMs());
                    Unit
                }
            }
        }
      | Left(_) -> Unit
    }
"/utf8>>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    filename:join(Root, "kept_exiter.erc").

%% report §8.6, §11.2: the lines of the end's wait keep their place among
%% what the subscribers write on standard error where nothing stalls. The
%% first subscriber, told, writes a line and makes a late subscriber, which
%% is told, writes a line and answers, and then the first answers. Which of
%% the two answers is said first is a matter of scheduling, which the test
%% does not fix, and it runs three times of each kind. A regression test,
%% written after the code that keeps the order: it does not cover standard
%% output, a run under `ern test` or the shell, nor a stream that stalls.
wait_lines_in_order_test_() ->
    ern_harness:nodes_test({waits, 7}, fun wait_lines_in_order/1).

wait_lines_in_order(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "told_in_order.ern"), <<"
// Report §8.6, §11.2: a program whose end tells a subscriber that writes a
// line on standard error and makes a late subscriber, which writes a line
// too and answers; then the first answers.

type Msg = Terminating(Reply(Unit)) | Ready | Answered

export fn main() : Unit receiving Msg = {
    let me = self();
    let _ = spawn(fn() : Unit receiving Msg = early(me));
    receive {
        Ready -> Unit
    }
}

fn early(main : Address(Msg)) : Unit receiving Msg = {
    Os.subscribeTermination(Terminating);
    send(main, Ready);
    receive {
        Terminating(reply) -> {
            Io.printlnError(\"early told\");
            let me = self();
            let _ = spawn(fn() : Unit receiving Msg = late(me));
            receive {
                Answered -> answer(reply, Unit)
            }
        }
    }
}

fn late(earlier : Address(Msg)) : Unit receiving Msg = {
    Os.subscribeTermination(Terminating);
    receive {
        Terminating(reply) -> {
            Io.printlnError(\"late told\");
            answer(reply, Unit);
            send(earlier, Answered)
        }
    }
}
"/utf8>>),
    0 = ern_harness:built([Root]),
    Program = filename:join(Root, "told_in_order.erc"),
    A = ern_harness:made(Base, "a", none),
    lists:foreach(fun(Options) ->
                      {0, Said} = finished([?ERN, " run", Options, " ", Program, " 2>&1"]),
                      [Waits, EarlyTold, Too, LateTold | Answers] =
                          string:split(string:trim(unstamped(Said), trailing), "\n", all),
                      ?assertEqual({"the end waits for 1 subscriber: ToldInOrder.main:10",
                                    "early told",
                                    "the end waits for ToldInOrder.early:23 too",
                                    "late told"},
                                   {Waits, EarlyTold, Too, LateTold}),
                      ?assertEqual(["the subscriber ToldInOrder.early:23 answered",
                                    "the subscriber ToldInOrder.main:10 answered"],
                                   lists:sort(Answers))
                  end, lists:append(lists:duplicate(3, ["", [" --config-dir ", A]]))).

%% A plain run and a node, each with standard error stalled and then
%% standard output.
stalled_runs() ->
    [{Kind, Stream} || Kind <- [plain, node], Stream <- [err, out]].

%% Check run on a run of held_writer/1, Program, given Stream and Ending
%% (held_run/5), whose end waits for its subscriber, plain or a node as
%% Kind says, from a directory of its own under Base, given the run's port
%% and the program's connection; the holder of the stalled stream and the
%% run closed after, however Check ended. One step beside Check's.
waited_run(Base, Kind, Program, Stream, Ending, Check) ->
    Dir = filename:join(Base, atom_to_list(Kind) ++ "_" ++ atom_to_list(Stream)),
    Options = case Kind of
                  plain -> "";
                  node -> [" --config-dir ", ern_harness:made(Base, filename:basename(Dir), none)]
              end,
    {Run, Socket, Holder} = held_run(Dir, Options, Program, Stream, Ending ++ " subscribed"),
    try
        Check(Run, Socket)
    after
        ern_harness:closed(Holder),
        ern_harness:closed(Run)
    end.

%% Report §8.6: a termination cuts the end's wait, and the run is ended from
%% its flush (flushed_and_ended/3). Two steps.
cut_and_ended(Run, Socket, Status) ->
    true = ern_harness:run_signaled(Run, "TERM"),
    flushed_and_ended(Run, Socket, Status).

%% Report §8.6: the end's wait is over, the program's processes ended,
%% which closes the program's connection, and the run is still there in the
%% end's flush, whose stream takes nothing; a termination ends it, with
%% Status. Two steps.
flushed_and_ended(Run, Socket, Status) ->
    ?assertEqual({error, closed}, ern_harness:received(Socket, 0)),
    ?assert(ern_harness:run_signaled(Run, "0")),
    true = ern_harness:run_signaled(Run, "TERM"),
    ?assertMatch({Status, _}, ern_harness:collected(Run, 1)).

%% report §11.8, §11: `ern test` ends by a termination that cut short the
%% end of a launch, and runs no later launch. Here the first of two modules
%% leaves a subscriber of Os.subscribeTermination that never answers, so
%% that its tests' launch's end waits; once standard error says so, a
%% termination cuts the wait, and the job ends by it, 143, the second
%% module's name and lines never written.
test_ends_at_a_cut_wait_test_() ->
    ern_harness:nodes_test({waits, 4}, fun test_ends_at_a_cut_wait/1).

test_ends_at_a_cut_wait(Base) ->
    Root = two_modules(filename:join(Base, "build"), <<"
// Report §8.6, §11.2: a test that leaves a subscriber of Os.subscribeTermination
// that never answers, so that the end of its launch waits for it.

type Msg = Subscribed

type SubscriberMsg = Terminating(Reply(Unit))

let waits : Test.Case(Msg) = Test.Case(name = \"waits\", run = fn() = {
    let me = self();
    let _ = spawn(fn() = subscriber(me));
    receive {
        Subscribed -> Test.Passed
    }
})

fn subscriber(test : Address(Msg)) : Unit receiving SubscriberMsg = {
    Os.subscribeTermination(Terminating);
    send(test, Subscribed);
    unanswered()
}

fn unanswered() : Unit receiving SubscriberMsg =
    receive {
        Terminating(_) -> unanswered()
    }
"/utf8>>),
    Dir = filename:join(Base, "job"),
    {Job, Wait} = ern_harness:launched(Dir, ["exec ", ?ERN, " test ", Root]),
    try
        ern_harness:says(Dir, "the end waits for "),
        true = ern_harness:run_signaled(Job, "TERM"),
        ?assertEqual(143, Wait()),
        {Out, Err} = ern_harness:said(Dir),
        ern_harness:has(Out, "First\n"),
        ?assertEqual({nomatch, nomatch}, {string:find(Out, "Second"), string:find(Err, "Second")})
    after
        ern_harness:closed(Job)
    end.

%% report §11.8, §11: the same where the first module's test writes a
%% megabyte to a standard output whose reader takes nothing, and passes, so
%% that its launch's end stalls in its flush: one termination ends the
%% flush at once, and the job ends by it, 143, while the reader has read
%% nothing. The end shows as the connection the test's process of its own
%% held closed. The second module's test, which would connect too, never
%% does.
test_ends_at_an_ended_flush_test_() ->
    ern_harness:nodes_test({waits, 4}, fun test_ends_at_an_ended_flush/1).

test_ends_at_an_ended_flush(Base) ->
    Root = two_modules(filename:join(Base, "build"), [<<"
// Report §8.6, §11.2: a test whose process of its own holds a connection to
// the port ERN_HOLD_PORT names until its launch's end, and that writes a
// megabyte to standard output and passes.

type Msg = Connected

let writes : Test.Case(Msg) = Test.Case(name = \"writes\", run = fn() = {
    let me = self();
    let _ = spawn(fn() = hold(me));
    receive {
        Connected -> Unit
    };
    Io.write(Bytes.repeat(<<120>>, 1048576));
    Test.Passed
})

fn hold(test : Address(Msg)) : Unit receiving Msg =
    match Optional.andThen(Os.environment(\"ERN_HOLD_PORT\"), String.toInt) {
        Some(port) -> held(Tcp.connect(\"127.0.0.1\", port, waitMs()), test)
      | None -> Io.printlnError(\"no port in ERN_HOLD_PORT\")
    }

// Once connected, waits for a message that never comes, until the end of
// its launch ends it and closes the connection.
fn held(connected : Either(Io.Error, Address(Tcp.SocketMsg)),
        test : Address(Msg)) : Unit receiving Msg =
    match connected {
        Right(_) -> {
            send(test, Connected);
            receive {
                Connected -> Unit
            }
        }
      | Left(error) ->
            Io.printlnError(\"not connected: \" <> Io.show(error))
    }
"/utf8>>, ern_harness:wait_ms_declaration()]),
    {ok, Listener} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listener),
    Pipe = filename:join(Base, "stdout.pipe"),
    [] = os:cmd("mkfifo " ++ Pipe),
    Command = lists:flatten(["ERN_HOLD_PORT=", integer_to_list(Port), " exec ", ?ERN, " test ",
                             Root, " 2>&1 > ", Pipe]),
    Job = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status, binary]),
    Holder = open_port({spawn_executable, "/bin/sh"},
                       [{args, ["-c", "exec 3< " ++ Pipe ++ "; read line"]}, exit_status, binary]),
    try
        Socket = ern_harness:accepted(Listener),
        ?assertEqual({error, closed}, ern_harness:received(Socket, 0)),
        true = ern_harness:run_signaled(Job, "TERM"),
        ?assertMatch({143, _}, ern_harness:collected(Job, 1)),
        ?assertEqual({error, timeout}, gen_tcp:accept(Listener, 0))
    after
        ern_harness:closed(Holder),
        ern_harness:closed(Job),
        ok = gen_tcp:close(Listener)
    end.

%% A directory Root of two modules built, first.ern of First's source and
%% second.ern, whose one test passes once it has connected to the port
%% ERN_HOLD_PORT names, where one is named: one step. Answers Root.
two_modules(Root, First) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "first.ern"), First),
    ok = file:write_file(filename:join(Root, "second.ern"), [<<"
// Report §11.2: a module whose one test passes, once it has connected to
// the port ERN_HOLD_PORT names, where one is named.

let follows = Test.Case(name = \"follows\", run = fn() = {
    match Optional.andThen(Os.environment(\"ERN_HOLD_PORT\"), String.toInt) {
        Some(port) -> {
            let _ = Tcp.connect(\"127.0.0.1\", port, waitMs());
            Unit
        }
      | None ->
            Unit
    };
    Test.Passed
})
"/utf8>>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    Root.

%% report §12.5: on a Linux without pidfd_open, one before 5.3, a node
%% refuses to start, making no file, naming the system and its release as
%% uname gives them. The kernel's answer, ENOSYS, is given by a library
%% the node's command alone loads before the C library, which answers that
%% call so and passes every other on. A regression test, written after the
%% code; it does not run a kernel older than 5.3, nor a host the helper's
%% watch has no code for, whose frame is the same
unwatched_host_test_() ->
    ern_harness:nodes_test({waits, 2}, fun unwatched_host/1).

unwatched_host(Base) ->
    A = ern_harness:made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "ran.ern"),
                         <<"export fn main() : Unit = Io.println(\"ran\")\n">>),
    0 = ern_harness:built([Root]),
    Shim = filename:join(Base, "no_pidfd_open.so"),
    ok = file:write_file(Shim ++ ".c", no_pidfd_open()),
    "" = os:cmd(lists:flatten(["cc -shared -fPIC -o ", Shim, " ", Shim, ".c -ldl"])),
    {1, Said} = finished(["LD_PRELOAD=", Shim, " ", ?ERN, " run --config-dir ", A, " ",
                          filename:join(Root, "ran.erc"), " 2>&1"]),
    Host = string:trim(os:cmd("uname -s")) ++ " " ++ string:trim(os:cmd("uname -r")),
    ?assertEqual("ern run: a node needs pidfd_open, of Linux 5.3 and later, which this host, "
                 ++ Host ++ ", does not have\n", Said),
    ern_deployment_tests:cataloged(Said, "7", "needs pidfd_open",
                                   [{"Linux 4.15.0-213-generic", Host}]),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% A library for LD_PRELOAD, as C: syscall(2) answers pidfd_open with
%% ENOSYS, as a kernel without the call does, and passes every other call
%% to the C library's, the host's own futexes among them.
no_pidfd_open() ->
    <<"#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/syscall.h>
#include <unistd.h>
#ifndef SYS_pidfd_open
#define SYS_pidfd_open 434
#endif

long syscall(long number, ...)
{
    static long (*host)(long, ...);
    va_list given;
    long arguments[6];
    int index;
    if (number == SYS_pidfd_open) {
        errno = ENOSYS;
        return -1;
    }
    if (host == NULL)
        *(void **)&host = dlsym(RTLD_NEXT, \"syscall\");
    va_start(given, number);
    for (index = 0; index < 6; index++)
        arguments[index] = va_arg(given, long);
    va_end(given);
    return host(number, arguments[0], arguments[1], arguments[2], arguments[3], arguments[4],
                arguments[5]);
}
">>.

%% report §12.5, §11.2: `ern reload` sends the node hangup, which reads
%% ernest.conf again: a peer removed has its connection ended and is
%% refused after, a peer listed again under another name is accepted, a
%% peer renamed keeps its connection, and a file that changes `listen` is
%% refused, the configuration kept; the node says what each did, each line
%% with its time. A peer's key that does not decode is refused by `ern
%% reload` before it signals, and by the node at a hangup `kill -HUP`
%% sends. A regression test, written after the code; it does not
%% cover `measures` changed, nor a peer whose address changed. Regressions:
%% a peer's public key that does not decode failed the signal handler,
%% after which the node took no signal and ran on past `ern stop`; and the
%% host warned on standard output at each reload of a message the handler
%% did not take
reload_test_() ->
    ern_harness:nodes_test({waits, 20}, fun reload/1).

reload(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    Third = filename:join(Base, "third"),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["reload"]),
    ern_harness:prints(Desk, "watching"),
    ern_harness:lists(Store, [{"third", Third, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    ern_harness:says(Store, "the peer desk was removed"),
    ern_harness:prints(Desk, "now list the desk again"),
    ern_harness:lists(Store, [{"third", Third, none}, {"front", Desk, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    ern_harness:says(Store, "the peer front was added"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Desk, "now rename the desk"),
    ern_harness:lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    ern_harness:says(Store, "the peer front is now named window"),
    true = port_command(DeskPort, "go\n"),
    ern_harness:prints(Desk, "now refuse a reload"),
    ern_harness:edit(Store, fun(#{<<"peers">> := Peers} = Conf) ->
                                Broken = #{<<"name">> => <<"broken">>,
                                           <<"public-key">> =>
                                               undecodable(ern_harness:public(Desk))},
                                Conf#{<<"peers">> := Peers ++ [Broken]}
                            end),
    ?assertEqual({1, refused_reload(Store, "peer \"broken\"'s public-key is not one public key"
                                           " in PEM")},
                 signaled("reload", Store)),
    hungup(Store),
    ern_harness:says(Store, "is not one public key in PEM"),
    ern_harness:lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    ern_harness:edit(Store, fun(Conf) ->
                                Conf#{<<"listen">> => ern_harness:address(ern_harness:free_port())}
                            end),
    ?assertMatch({0, _}, signaled("reload", Store)),
    ern_harness:says(Store, "the reload was refused"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {StoreOut, Err} = ern_harness:said(Store),
    [ern_harness:has(Out, Line)
     || Line <- ["removed: Unreachable \"\"", "unlisted: Left(Io.Unreachable)",
                 "listed again: true",
                 "renamed: Some(0)", "refused: Some(0)"]],
    [?assertMatch({match, _}, re:run(Err, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z " ++ Line ++ "$",
                                     [multiline]))
     || Line <- ["ernest.conf was read again", "the peer desk was removed",
                 "the peer front was added", "the peer front is now named window"]],
    ern_harness:has(Err, "the reload was refused, and the configuration stays as it was: "),
    ern_harness:has(Err, "peer \"broken\"'s public-key is not one public key in PEM"),
    ern_harness:has(Err, "listen cannot change while the node runs"),
    ?assertEqual(nomatch, string:find(Err, "the peer front was lost")),
    %% report §12.5: no reload here changed `limits`, and none says so
    ?assertEqual(nomatch, string:find(Err, "the change to limits")),
    ?assertEqual(nomatch, string:find(StoreOut, "WARNING REPORT")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(Err, "7", "was removed", []),
    ern_deployment_tests:cataloged(Err, "7", "is now named", [{"c", "window"}]).

%% A public key in PEM whose body the host's decoder cannot read: its first
%% bytes, the key's algorithm, made another DER's.
undecodable(Pem) ->
    [Head, Body] = binary:split(Pem, <<"\n">>),
    <<Head/binary, "\nAAAAAAAAAAAA", (binary:part(Body, 12, byte_size(Body) - 12))/binary>>.

%% report §12.5, §11.2: a node reads its configuration directory at a
%% reload as its start reads it. Where the directory holds no
%% `certificate.pem` the node makes it from its key before its host boots,
%% and at a reload, and `ern reload`'s own reading makes none. An
%% `ernest.conf` any but its owner may write refuses the reload, by `ern
%% reload` before it signals and by the node at a hangup, with the cause
%% and then the fix; a `private-key.pem` that holds another key than the
%% running node's refuses it, as a changed `listen` does, and makes no
%% certificate for that key
reload_reads_directory_test_() ->
    ern_harness:nodes_test({waits, 13}, fun reload_reads_directory/1).

reload_reads_directory(Base) ->
    A = ern_harness:made(Base, "a", none),
    Certificate = filename:join(A, "certificate.pem"),
    Conf = filename:join(A, "ernest.conf"),
    Key = filename:join(A, "private-key.pem"),
    Program = ern_harness:program(filename:join(Base, "build")),
    ok = file:delete(Certificate),
    %% `ern reload` reads before it signals, and makes none
    {1, NoNode} = signaled("reload", A),
    ern_harness:has(NoNode, "no node runs from the directory"),
    ?assertNot(filelib:is_file(Certificate)),
    Wait = ern_harness:start(A, Program, []),
    ern_harness:prints(A, "waiting"),
    {ok, #file_info{mode = Mode}} = file:read_file_info(Certificate),
    ?assertEqual(8#644, Mode band 8#777),
    ok = file:delete(Certificate),
    ?assertEqual({0, ""}, signaled("reload", A)),
    ern_harness:says(A, "ernest.conf was read again"),
    ?assert(filelib:is_regular(Certificate)),
    %% a mode that lets others write ernest.conf
    ok = file:change_mode(Conf, 8#664),
    Open = ern_build:shown(Conf) ++ " may be written by others than its owner; chmod go-w "
        ++ ern_build:shown(Conf),
    ?assertEqual({1, "ern reload: " ++ Open ++ "\n"}, signaled("reload", A)),
    hungup(A),
    ern_harness:says(A, "the reload was refused, and the configuration stays as it was: " ++ Open),
    ok = file:change_mode(Conf, 8#644),
    %% another node's key, the certificate gone with it
    {ok, Own} = file:read_file(Key),
    {ok,
     Other} = file:read_file(filename:join(ern_harness:made(Base, "b", none), "private-key.pem")),
    ok = file:write_file(Key, Other),
    ok = file:delete(Certificate),
    ?assertEqual({0, ""}, signaled("reload", A)),
    ern_harness:says(A, "the reload was refused, and the configuration stays as it was: "
                        ++ ern_build:shown(Key)
                        ++ ": the node's key cannot change while the node runs"),
    ?assertNot(filelib:is_file(Certificate)),
    ok = file:write_file(Key, Own),
    ?assertEqual({0, ""}, signaled("reload", A)),
    ern_harness:seen(A, err, "ernest.conf was read again", 2, ?WAIT_MS),
    ?assert(filelib:is_regular(Certificate)),
    ern_harness:stop(A, Wait),
    {_, Err} = ern_harness:said(A),
    ?assertEqual(nomatch, string:find(Err, "certifies another key")).

%%
%% Two builds (report §8.7)
%%

%% A program of four modules, written in Dir and built there, as one build
%% or as another, Changed, in which one function's body and one type's
%% constructors differ: Twin's types, services and functions; Aside,
%% whose binding the server's program never runs; the server, which offers
%% a process as each service; and the asker, which finds and spawns on the
%% server. A host module the asker's build holds and the server's lacks is
%% what Twin's foreign declaration calls. Answers the asker's and the
%% server's programs. The restarting function the asker spawns returns and
%% never faults, so its window is the scenario's and reached by none.
twins(Dir, Changed) ->
    ok = filelib:ensure_path(Dir),
    {Shape, Said} = case Changed of
                        false -> {"Square(Int)", "the first build"};
                        true -> {"Square(Int) | Circle(Int)", "the second build"}
                    end,
    Twin = ["// Report §8.7: what the two builds share, and the two things they do not:\n"
            "// changed's body and Shape's constructors.\n"
            "\n"
            "export type Msg = Ping(Reply(Int))\n"
            "\n"
            "export type Shape = ", Shape, "\n"
            "\n"
            "export let stable : Peer.Service(Msg) = Peer.service(\"stable\")\n"
            "\n"
            "export let shape : Peer.Service(Shape) = Peer.service(\"shape\")\n"
            "\n"
            "export fn same() : Unit = Io.println(\"same ran\")\n"
            "\n"
            "export fn changed() : Unit = Io.println(\"", Said, "\")\n"
            "\n"
            "export fn worked() : Unit = Io.println(\"restarting ran\")\n"
            "\n"
            "foreign fn absent() : Unit = \"ern_twins_host:absent/0\"\n"
            "\n"
            "export fn callsAbsent() : Unit = absent()\n"],
    Aside = "// Report §8.7: a binding the server's program never runs, computed,\n"
            "// since a constant has its value wherever its code is (§11.1), beside a\n"
            "// function that names no binding.\n"
            "\n"
            "let note : String = \"never run\" <> \" on the server\"\n"
            "\n"
            "export fn tell() : Unit = Io.println(note)\n"
            "\n"
            "export fn quiet() : Unit = Io.println(\"quiet ran\")\n",
    Server = "// Report §8.7: a process as each of Twin's services, until the node ends.\n"
             "\n"
             "export fn main() : Unit receiving Unit = {\n"
             "    let pinged = spawn(fn() : Unit receiving Twin.Msg = answered());\n"
             "    let _ = Peer.offer(Twin.stable, pinged);\n"
             "    let shaped = spawn(fn() : Unit receiving Twin.Shape = held());\n"
             "    let _ = Peer.offer(Twin.shape, shaped);\n"
             "    Io.println(\"offered\");\n"
             "    held()\n"
             "}\n"
             "\n"
             "fn answered() : Unit receiving Twin.Msg = receive {\n"
             "    Twin.Ping(reply) -> {\n"
             "        answer(reply, 42);\n"
             "        answered()\n"
             "    }\n"
             "}\n"
             "\n"
             "// Until the node is stopped: a node waiting for ever is no deadlock.\n"
             "fn held() : Unit receiving m = receive { _ -> held() }\n",
    Asker = "// Report §8.7: the finds and the spawns on the server, each answer a line.\n"
            "\n"
            "export fn main() : Unit =\n"
            "    match Os.arguments {\n"
            "        [server] -> {\n"
            "            found(server);\n"
            "            spawned(server);\n"
            "            captured(server)\n"
            "        }\n"
            "      | _ -> Unit\n"
            "    }\n"
            "\n"
            "fn found(server : String) : Unit = {\n"
            "    let stable = match Peer.find(Twin.stable, waitMs()) {\n"
            "        Right(address) ->\n"
            "            Io.show(Address.call(address, fn(reply) = Twin.Ping(reply), waitMs()))\n"
            "      | Left(failure) -> Io.show(failure)\n"
            "    };\n"
            "    Io.println(\"stable: \" <> stable);\n"
            "    Io.println(\"shape: \" <> started(Peer.find(Twin.shape, waitMs())))\n"
            "}\n"
            "\n"
            "fn spawned(server : String) : Unit = {\n"
            "    Io.println(\"same: \" <> started(Peer.spawn(server, Twin.same, waitMs())));\n"
            "    Io.println(\"changed: \" <> started(Peer.spawn(server, Twin.changed,"
            " waitMs())));\n"
            "    Io.println(\"binding: \" <> started(Peer.spawn(server, Aside.tell, waitMs())));\n"
            "    Io.println(\"module: \" <> started(Peer.spawn(server, Twin.callsAbsent,"
            " waitMs())));\n"
            "    let quiet = Peer.spawn(server, Aside.quiet, waitMs());\n"
            "    Io.println(\"names no binding: \" <> started(quiet))\n"
            "}\n"
            "\n"
            "// The same in both builds, so that its lambdas and local fns have one\n"
            "// identity on both nodes.\n"
            "fn captured(server : String) : Unit = {\n"
            "    let n = 6;\n"
            "    let lambda = Peer.spawn(server,\n"
            "                            fn() =\n"
            "                                Io.println(\"lambda ran \" <> Int.toString(n * 7)),\n"
            "                            waitMs());\n"
            "    Io.println(\"lambda: \" <> started(lambda));\n"
            "    fn local() : Unit =\n"
            "        Io.println(\"local ran \" <> Int.toString(n + 37));\n"
            "    Io.println(\"local: \" <> started(Peer.spawn(server, local, waitMs())));\n"
            "    let once = RestartLimit(restarts = 1, within = 1000);\n"
            "    let restarted = Peer.spawn(server, restarting(once, Twin.worked), waitMs());\n"
            "    Io.println(\"restarting: \" <> started(restarted))\n"
            "}\n"
            "\n"
            "fn started(answer : Either(Io.Error, Address(m))) : String =\n"
            "    match answer {\n"
            "        Right(_) -> \"Right\"\n"
            "      | Left(failure) -> Io.show(failure)\n"
            "    }\n",
    [ok = file:write_file(filename:join(Dir, File), unicode:characters_to_binary(Text))
     || {File, Text} <- [{"twin.ern", Twin}, {"aside.ern", Aside}, {"server.ern", Server},
                         {"asker.ern", [Asker, ern_harness:wait_ms_declaration()]}]],
    0 = ern_harness:built([Dir]),
    Changed orelse begin
                       ok = file:write_file(filename:join(Dir, "ern_twins_host.erl"),
                                            <<"-module(ern_twins_host).\n"
                                              "-export([absent/0]).\n"
                                              "absent() -> 'Unit'.\n">>),
                       {ok, _} = compile:file(filename:join(Dir, "ern_twins_host.erl"),
                                              [{outdir, Dir}])
                   end,
    {filename:join(Dir, "asker.erc"), filename:join(Dir, "server.erc")}.

%% report §8.7, Appendix H, §3.11, §6.9: two nodes of different builds of
%% one program connect. A find answers the address where the service's type
%% is one in both builds, and a call through it is answered, and
%% `OtherType` where the type's constructors differ, its hash another. A
%% spawn of a function both builds hold runs on the server, and one of a
%% function whose body differs crosses with its spawn, the server compiling
%% it and running the asker's body.
%%
%% A function that names a binding the server's program never ran answers
%% NotLoaded, and so does one whose reach calls a host module the server
%% lacks, the server saying which, and the answer carrying it (Appendix
%% E.1). A function that names no binding of a
%% module whose binding the server never ran spawns. A lambda and a local fn
%% spawn by identity with what they captured, and `restarting(limit, f)`
%% spawns. Written with the code, after it: a regression test
two_builds_test_() ->
    ern_harness:nodes_test({waits, 8}, fun two_builds/1).

two_builds(Base) ->
    {AskerProgram, _} = twins(filename:join(Base, "first"), false),
    {_, ServerProgram} = twins(filename:join(Base, "second"), true),
    PortServer = ern_harness:free_port(),
    Asker = ern_harness:made(Base, "asker", none),
    Server = ern_harness:made(Base, "server", PortServer),
    ern_harness:lists(Asker, [{"server", Server, PortServer}]),
    ern_harness:lists(Server, [{"asker", Asker, none}]),
    ern_harness:edit(Asker, fun(Conf) ->
                                Conf#{<<"services">> => #{<<"stable">> => [<<"server">>],
                                                          <<"shape">> => [<<"server">>]}}
                            end),
    WaitServer = ern_harness:start(Server, ServerProgram, []),
    ern_harness:prints(Server, "offered"),
    ?assertEqual(0, (ern_harness:start(Asker, AskerProgram, ["server"]))()),
    ern_harness:prints(Server, "restarting ran"),
    ern_harness:stop(Server, WaitServer),
    {Out, _} = ern_harness:said(Asker),
    {ServerOut, ServerErr} = ern_harness:said(Server),
    [ern_harness:has(Out, Line)
     || Line <- ["stable: Some(42)", "shape: Io.OtherType", "same: Right",
                 "changed: Right",
                 "binding: Io.NotLoaded(\"the binding Aside.note has no value here\")\n",
                 "module: Io.NotLoaded(\"the module ern_twins_host, which Twin.absent calls, is"
                 " not here\")\n",
                 "names no binding: Right", "lambda: Right", "local: Right", "restarting: Right"]],
    [ern_harness:has(ServerOut, Line)
     || Line <- ["same ran", "quiet ran", "lambda ran 42", "local ran 43", "restarting ran",
                 "the first build"]],
    ?assertEqual(nomatch, string:find(ServerOut, "the second build")),
    ?assertEqual(nomatch, string:find(ServerOut, "never run on the server")),
    ?assertEqual(nomatch, string:find(ServerErr, "Asker.spawned:25")),
    [ern_harness:has(ServerErr, Line)
     || Line <- ["the peer asker connected",
                 "the peer asker's spawn at Asker.spawned:26 was not loaded: the binding"
                 " Aside.note has no value here",
                 "the peer asker's spawn at Asker.spawned:27 was not loaded: the module"
                 " ern_twins_host, which Twin.absent calls, is not here"]].

%% Two builds of which the receiver's lacks the sender's every module: the
%% receiver, which waits, and the sender, whose `Lacked` holds a type, a
%% binding, a foreign declaration over a host module the receiver lacks
%% too, a function that calls a foreign function the host raises from, one
%% that spawns a process of its own there and reads its site, and two
%% foreign functions spawned and computed by their names, one whose host
%% function answers a value of another type than declared; and whose
%% program spawns and computes them on the receiver and calls servers whose
%% spawns hold the calls' replies, each answer a line. Answers the sender's
%% and the receiver's programs.
exchanged(Base) ->
    [SenderDir, ReceiverDir] = [filename:join([Base, "builds", Dir])
                                || Dir <- ["sender", "receiver"]],
    [ok = filelib:ensure_path(Dir) || Dir <- [SenderDir, ReceiverDir]],
    Lacked = "// Report §8.7: what the receiver's build lacks.\n"
             "\n"
             "export type Count = Count(Int)\n"
             "\n"
             %% computed, since a constant has its value wherever its code is (§11.1)
             "let note : String = \"never run\" <> \" on the receiver\"\n"
             "\n"
             "export fn told() : Unit = Io.println(note)\n"
             "\n"
             "export foreign fn only() : Unit = \"ern_sender_host:only/0\"\n"
             "\n"
             "export fn callsOnly() : Unit = only()\n"
             "\n"
             "export fn plain() : Unit = Io.println(Io.show(Count(1)))\n"
             "\n"
             "export fn counted() : Count = Count(2)\n"
             "\n"
             "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
             "\n"
             "export fn raises() : Unit = Io.println(Int.toString(parsed(\"x\")))\n"
             "\n"
             "export fn spawner() : Unit = {\n"
             "    let child = spawn(fn() : Unit receiving Int =\n"
             "        receive { _ -> fault(\"the child\") });\n"
             "    let site = match Process.status(Process.fromAddress(child)) {\n"
             "        Some(status) -> status.site\n"
             "      | None -> \"none\"\n"
             "    };\n"
             "    Io.println(\"child at \" <> site);\n"
             "    send(child, 1)\n"
             "}\n"
             "\n"
             "export foreign fn yielded() : Unit = \"erlang:yield/0\"\n"
             "\n"
             "export foreign fn collected() : Bool = \"erlang:garbage_collect/0\"\n"
             "\n"
             "foreign fn miscounted() : Count = \"erlang:yield/0\"\n"
             "\n"
             "export fn counts() : Unit = { let _ = miscounted(); Unit }\n"
             "\n"
             "export foreign fn absent() : Unit = \"lists:ern_absent_function/0\"\n",
    Sender = "// Report §8.7, §6.6, Appendix E.27: spawns and a compute of functions the receiver\n"
             "// lacks, and calls whose replies a failed spawn captured, each answer a line.\n"
             "\n"
             "type Ask = Ask(Reply(Either(Io.Error, Int)))\n"
             "\n"
             "export fn main() : Unit receiving Down =\n"
             "    match Os.arguments {\n"
             "        [receiver, _] -> {\n"
             "            let plain = Peer.spawn(receiver, Lacked.plain, waitMs());\n"
             "            Io.println(\"plain: \" <> outcome(plain));\n"
             "            let counted = Peer.compute(receiver, Lacked.counted, waitMs());\n"
             "            Io.println(\"counted: \" <> Io.show(counted));\n"
             "            let told = Peer.spawn(receiver, Lacked.told, waitMs());\n"
             "            Io.println(\"told: \" <> outcome(told));\n"
             "            let only = Peer.spawn(receiver, Lacked.callsOnly, waitMs());\n"
             "            Io.println(\"calls only: \" <> outcome(only));\n"
             "            ended(receiver);\n"
             "            ended(\"nobody\");\n"
             "            received(receiver)\n"
             "        }\n"
             "      | _ -> Unit\n"
             "    }\n"
             "\n"
             "// Spawns and computes of what the receiver lacks that run there.\n"
             "fn received(receiver : String) : Unit receiving Down = {\n"
             "    Io.println(\"raises: \" <> outcome(Peer.spawn(receiver, Lacked.raises,"
             " waitMs())));\n"
             "    let spawner = Peer.spawn(receiver, Lacked.spawner, waitMs());\n"
             "    Io.println(\"spawner: \" <> outcome(spawner));\n"
             "    let yielded = Peer.spawn(receiver, Lacked.yielded, waitMs());\n"
             "    Io.println(\"yielded: \" <> outcome(yielded));\n"
             "    let collected = Peer.compute(receiver, Lacked.collected, waitMs());\n"
             "    Io.println(\"collected: \" <> Io.show(collected));\n"
             "    let named = Peer.spawn(receiver, Lacked.only, waitMs());\n"
             "    Io.println(\"only by name: \" <> outcome(named));\n"
             "    Io.println(\"counts: \" <> outcome(Peer.spawn(receiver, Lacked.counts,"
             " waitMs())));\n"
             "    let absent = Peer.spawn(receiver, Lacked.absent, waitMs());\n"
             "    Io.println(\"absent function: \" <> outcome(absent))\n"
             "}\n"
             "\n"
             "// A call whose reply a failed spawn on peer captured is answered by the\n"
             "// server, which keeps its copy of the reply: the failure.\n"
             "fn ended(peer : String) : Unit = {\n"
             "    let server = spawn(fn() : Unit receiving Ask = serve(peer));\n"
             "    let called = Address.call(server, fn(reply) = Ask(reply), waitMs());\n"
             "    Io.println(\"call \" <> peer <> \": \" <> Io.show(called))\n"
             "}\n"
             "\n"
             "fn serve(peer : String) : Unit receiving Ask = receive {\n"
             "    Ask(reply) -> {\n"
             "        let spawned = Peer.spawn(peer, fn() = {\n"
             "            Lacked.told();\n"
             "            answer(reply, Right(1))\n"
             "        }, waitMs());\n"
             "        Io.println(\"server \" <> peer <> \": \" <> outcome(spawned));\n"
             "        match spawned {\n"
             "            Left(failure) -> answer(reply, Left(failure))\n"
             "          | Right(_) -> Unit\n"
             "        };\n"
             "        serve(peer)\n"
             "    }\n"
             "}\n"
             "\n"
             "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
             "    match spawned {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n"
             "\n"
             "// The milliseconds each spawn, compute and call here waits: the test's\n"
             "// wait for this program, its second argument, which began before any of\n"
             "// them, so that none answers by its time running out before the test\n"
             "// has given the program up.\n"
             "fn waitMs() : Int =\n"
             "    match Os.arguments {\n"
             "        [_, wait] -> Optional.withDefault(String.toInt(wait), 0)\n"
             "      | _ -> 0\n"
             "    }\n",
    Receiver = "// Report §8.7: a node that waits, its build holding nothing of the\n"
               "// sender's.\n"
               "\n"
               "export fn main() : Unit receiving Unit = {\n"
               "    Io.println(\"ready\");\n"
               "    held()\n"
               "}\n"
               "\n"
               "fn held() : Unit receiving m = receive { _ -> held() }\n",
    [ok = file:write_file(filename:join(Dir, File), unicode:characters_to_binary(Text))
     || {Dir, File, Text} <- [{SenderDir, "lacked.ern", Lacked}, {SenderDir, "sender.ern", Sender},
                              {ReceiverDir, "receiver.ern", Receiver}]],
    [0 = ern_harness:built([Dir]) || Dir <- [SenderDir, ReceiverDir]],
    Host = filename:join(SenderDir, "ern_sender_host.erl"),
    ok = file:write_file(Host, <<"-module(ern_sender_host).\n-export([only/0]).\n"
                                 "only() -> 'Unit'.\n">>),
    {ok, _} = compile:file(Host, [{outdir, SenderDir}]),
    {filename:join(SenderDir, "sender.erc"), filename:join(ReceiverDir, "receiver.erc")}.

%% report §8.7, §12.7, §6.6, §12.3, §6.9, §11.2, Appendix E.27: a spawn or a
%% compute of a function the receiver lacks runs the exchange, whose shape
%% is docs/design/code.md's, and the receiver runs the spawn and the
%% compute, the compute's value at the sender's type. A fault in a received
%% function is reported on the receiver at the spawn's site, the sender's,
%% with the peer that spawned it, and its trace names the sender's
%% definitions. A process a received function spawns there has the
%% sender's site, its definition's name and line, which `Process.status`
%% reads and its fault's line writes.
%%
%% A foreign function spawned or computed by its name crosses as its
%% declaration and runs through the check at its declared type, which a
%% host function that answers another type fails, its cause naming the type
%% whole from the root, `Lacked.Count`, and what the host returned, while
%% one whose module the receiver lacks, or whose function its module lacks,
%% is NotLoaded. A function whose reach names a binding the receiver never
%% ran, or a foreign declaration whose module it lacks, answers NotLoaded
%% from the reach, before any code crosses, the receiver saying what it
%% lacked, which the answer carries (Appendix E.1). A call whose reply a
%% function captured whose spawn failed is answered by the spawner, which
%% keeps its copy, with the failure, NotLoaded or NotListed alike. A
%% regression test, written after the code; that no code frame moves
%% before NotLoaded is ern_exchange_tests', since no line marks it here.
%%
%% Each spawn, compute and call of the sender waits as long as the test
%% waits for the sender, and the test's limit is the sum of its eighteen
%% steps, the two builds, a line of the receiver's, the sender's end, ten
%% lines and one more of the receiver's, its end and what each node said,
%% each bounded by the harness's time for one wait: written after a
%% spawn's 5000 ms, a number of its own, ran out under the full run's load
%% and its answer's line was missing; its builds are counted, and its host
%% module's compile, which is no step, is not
exchange_test_() ->
    ern_harness:nodes_test({waits, 18}, fun exchange/1).

exchange(Base) ->
    {SenderProgram, ReceiverProgram} = exchanged(Base),
    PortReceiver = ern_harness:free_port(),
    Sender = ern_harness:made(Base, "sender", none),
    Receiver = ern_harness:made(Base, "receiver", PortReceiver),
    ern_harness:lists(Sender, [{"receiver", Receiver, PortReceiver}]),
    ern_harness:lists(Receiver, [{"sender", Sender, none}]),
    WaitReceiver = ern_harness:start(Receiver, ReceiverProgram, []),
    ern_harness:prints(Receiver, "ready"),
    ?assertEqual(0,
                 (ern_harness:start(Sender, SenderProgram,
                                    ["receiver", integer_to_list(?WAIT_MS)]))()),
    Served = "the peer sender's spawn at Sender.serve:50 was not loaded: the binding Lacked.note"
             " has no value here",
    Lines = ["the peer sender's spawn at Sender.main:13 was not loaded: the binding Lacked.note"
             " has no value here",
             "the peer sender's spawn at Sender.main:15 was not loaded: the module"
             " ern_sender_host, which Lacked.only calls, is not here",
             Served,
             "the process of Sender.received:26 faulted: foreign function"
             " erlang:binary_to_integer/1 raised error:badarg, spawned by the peer sender",
             "\n    Lacked.raises:19\n",
             "the process of Lacked.spawner:22 faulted: the child",
             "the process of Sender.received:29 faulted: the return of foreign function"
             " erlang:yield/0 does not match Unit: is true, spawned by the peer sender",
             "the peer sender's spawn at Sender.received:33 was not loaded: the module"
             " ern_sender_host, which Lacked.only calls, is not here",
             "the process of Sender.received:35 faulted: the return of foreign function"
             " erlang:yield/0 does not match Lacked.Count: is true, spawned by the peer sender",
             "the peer sender's spawn at Sender.received:36 was not loaded: the module lists,"
             " which Lacked.absent calls, has no function ern_absent_function/0 here"],
    [ern_harness:says(Receiver, Line) || Line <- Lines],
    ern_harness:prints(Receiver, "child at Lacked.spawner:22"),
    ern_harness:stop(Receiver, WaitReceiver),
    {Out, _} = ern_harness:said(Sender),
    {ReceiverOut, ReceiverErr} = ern_harness:said(Receiver),
    Note = "Io.NotLoaded(\"the binding Lacked.note has no value here\")",
    Only = "Io.NotLoaded(\"the module ern_sender_host, which Lacked.only calls, is not here\")",
    [ern_harness:has(Out, Line)
     || Line <- ["plain: Right", "counted: Right(Lacked.Count(2))",
                 "told: " ++ Note ++ "\n", "calls only: " ++ Only ++ "\n",
                 "server receiver: " ++ Note ++ "\n", "server nobody: Io.NotListed",
                 "call receiver: Some(Left(" ++ Note ++ "))",
                 "call nobody: Some(Left(Io.NotListed))",
                 "raises: Right", "spawner: Right", "yielded: Right", "collected: Right(true)",
                 "only by name: " ++ Only ++ "\n", "counts: Right",
                 "absent function: Io.NotLoaded(\"the module lists, which Lacked.absent calls, has"
                 " no function ern_absent_function/0 here\")\n"]],
    ern_harness:has(ReceiverOut, "Count(1)"),
    ?assertEqual(1, length(string:split(ReceiverErr, Served, all)) - 1),
    ?assertEqual(nomatch, string:find(ReceiverErr, "Lacked.spawner:22 faulted: the child,")),
    ?assertEqual(nomatch, string:find(Out, "never run on the receiver")),
    %% the lines as the deployment guide quotes them, in its catalog
    Peer = {"a", "sender"},
    ern_deployment_tests:cataloged(ReceiverErr, "7", "has no value here",
                                   [Peer, {"Site", "Sender.main:13"}, {"Q", "Lacked.note"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "7", "is not here",
                                   [Peer, {"Site", "Sender.main:15"}, {"M", "ern_sender_host"},
                                    {"Q", "Lacked.only"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "7", "has no function",
                                   [{"f/0", "ern_absent_function/0"}]).

%% A library whose binding prints as it is evaluated, and a program that
%% places work on a bare node and ends it, built in Base: the library's
%% root, and the program's `.erc` and source.
bare_build(Base) ->
    SharedDir = filename:join(Base, "shared"),
    ProgramDir = filename:join(Base, "program"),
    [ok = filelib:ensure_path(Dir) || Dir <- [SharedDir, ProgramDir]],
    Shared = "// Report §8.5: a library's binding, which a bare node that holds its\n"
             "// module does not evaluate.\n"
             "\n"
             "let greeting : String = {\n"
             "    Io.println(\"Shared.greeting evaluated\");\n"
             "    \"hello\"\n"
             "}\n"
             "\n"
             "export fn greet() : Unit = Io.println(greeting)\n"
             "\n"
             "// Report §4.6, §11.1: a constant, compiled to its value, which a bare\n"
             "// node that holds its module does not evaluate and has the value of.\n"
             "let farewell : String = \"bye\"\n"
             "\n"
             "export fn bid() : Unit = Io.println(farewell)\n",
    Source = "// Report §8.7: work placed on a bare node, which holds no definition of\n"
             "// this program's until a spawn or a compute brings it there.\n"
             "\n"
             "type Note = Offered\n"
             "\n"
             "export fn main() : Unit receiving Note =\n"
             "    match Os.arguments {\n"
             "        [bare, \"exit\"] -> exits(bare)\n"
             "      | [bare, interval] -> placed(bare, Optional.withDefault(String.toInt(interval),"
             " 0))\n"
             "      | _ -> Unit\n"
             "    }\n"
             "\n"
             "// Spawns, computes, a find, a utilization and a pick, each answer a line;\n"
             "// the bare node tells its utilization every interval.\n"
             "fn placed(bare : String, interval : Int) : Unit receiving Note = {\n"
             "    let counter = Peer.spawn(bare, fn() : Unit receiving Int = counts(0),"
             " waitMs());\n"
             "    Io.println(\"spawn: \" <> outcome(counter));\n"
             "    match counter {\n"
             "        Right(address) -> send(address, 1)\n"
             "      | Left(_) -> Unit\n"
             "    };\n"
             "    Io.println(\"compute: \" <> Io.show(Peer.compute(bare, answer, waitMs())));\n"
             "    Io.println(\"entry shown: \" <> Io.show(Peer.compute(bare, entryShown,"
             " waitMs())));\n"
             "    let told = self();\n"
             "    let offering = Peer.spawn(bare, fn() : Unit receiving Int = offers(told),"
             " waitMs());\n"
             "    Io.println(\"offering: \" <> outcome(offering));\n"
             "    match offering {\n"
             "        Right(_) -> receive {\n"
             "            Offered -> Unit\n"
             "        }\n"
             "      | Left(_) -> Unit\n"
             "    };\n"
             "    let service : Peer.Service(Int) = Peer.service(\"counter\");\n"
             "    match Peer.find(service, waitMs()) {\n"
             "        Right(address) -> {\n"
             "            send(address, 7);\n"
             "            Io.println(\"found: Right\")\n"
             "        }\n"
             "      | Left(failure) -> Io.println(\"found: \" <> Io.show(failure))\n"
             "    };\n"
             "    let utilization = match Peer.utilization(bare, waitMs()) {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    };\n"
             "    Io.println(\"utilization: \" <> utilization);\n"
             "    heard(bare, interval);\n"
             "    Io.println(\"picked: \" <> Io.show(Peer.computeAnywhere(answer, waitMs())));\n"
             "    Io.println(\"binding: \" <> outcome(Peer.spawn(bare, Shared.greet, waitMs())));\n"
             "    Io.println(\"ground: \" <> outcome(Peer.spawn(bare, Shared.bid, waitMs())));\n"
             "    Io.println(\"divides: \" <> outcome(Peer.spawn(bare, divides, waitMs())));\n"
             "    Io.println(\"raises: \" <> outcome(Peer.spawn(bare, raises, waitMs())));\n"
             "    Io.println(\"raises again: \" <> outcome(Peer.spawn(bare, raises, waitMs())))\n"
             "}\n"
             "\n"
             "// Report §8.6: the bare node ended by a process spawned on it, once it\n"
             "// is sent the status.\n"
             "fn exits(bare : String) : Unit receiving Note =\n"
             "    match Peer.spawn(bare, exiting, waitMs()) {\n"
             "        Right(address) -> {\n"
             "            send(address, 3);\n"
             "            Io.println(\"exit: Right\")\n"
             "        }\n"
             "      | Left(failure) -> Io.println(\"exit: \" <> Io.show(failure))\n"
             "    }\n"
             "\n"
             "fn exiting() : Unit receiving Int = receive {\n"
             "    status -> Os.exit(status)\n"
             "}\n"
             "\n"
             "fn counts(total : Int) : Unit receiving Int = receive {\n"
             "    n -> {\n"
             "        Io.println(\"counted \" <> Int.toString(total + n));\n"
             "        counts(total + n)\n"
             "    }\n"
             "}\n"
             "\n"
             "fn answer() : Int = 6 * 7\n"
             "\n"
             "// Report Appendix E.27: until the node holds the bare node's utilization, read\n"
             "// again at each of its intervals, at which alone the table changes.\n"
             "fn heard(bare : String, interval : Int) : Unit =\n"
             "    if List.any(Peer.utilizations(), fn(#(peer, _, _)) = peer == bare) then\n"
             "        Unit\n"
             "    else {\n"
             "        Clock.sleep(interval);\n"
             "        heard(bare, interval)\n"
             "    }\n"
             "\n"
             "// Whether the bare node's entry process is among its live processes, by\n"
             "// its site.\n"
             "fn entryShown() : Bool = {\n"
             "    let sites = List.filterMap(Process.live(), fn(process) =\n"
             "        Optional.map(Process.status(process), fn(status) = status.site));\n"
             "    List.contains(sites, \"bare node\")\n"
             "}\n"
             "\n"
             "fn offers(told : Address(Note)) : Unit receiving Int = {\n"
             "    let service : Peer.Service(Int) = Peer.service(\"counter\");\n"
             "    match Peer.offer(service, self()) {\n"
             "        Right(_) -> send(told, Offered)\n"
             "      | Left(_) -> Io.println(\"held already\")\n"
             "    };\n"
             "    counts(0)\n"
             "}\n"
             "\n"
             "fn divides() : Unit = {\n"
             "    let _ = 1 / List.size([]);\n"
             "    Unit\n"
             "}\n"
             "\n"
             "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
             "\n"
             "fn raises() : Unit = Io.println(Int.toString(parsed(\"x\")))\n"
             "\n"
             "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
             "    match spawned {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n",
    [ok = file:write_file(filename:join(Dir, File), unicode:characters_to_binary(Text))
     || {Dir, File, Text} <- [{SharedDir, "shared.ern", Shared},
                              {ProgramDir, "bare.ern",
                               [Source, ern_harness:wait_ms_declaration()]}]],
    0 = ern_harness:built([SharedDir]),
    0 = ern_harness:built(["--load-path", SharedDir, ProgramDir]),
    {SharedDir, filename:join(ProgramDir, "bare.erc"), Source}.

%% The number of the first line of Text that holds Part.
line_of(Text, Part) ->
    Lines = string:split(Text, "\n", all),
    length(lists:takewhile(fun(Line) -> string:find(Line, Part) =:= nomatch end, Lines)) + 1.

%% report §8.7, §8.1, §8.5, §8.6, §11.2, §11.8, Appendix E.21, E.27: a
%% bare node, `ern run --config-dir` with no `.erc`, listening on the port
%% the host picks, holds none of the program's definitions. A peer's spawn
%% of the program's function runs there with its code crossed, and takes
%% the peer's messages; a compute answers its value; a process spawned
%% there offers a service, which the peer finds and sends to. The bare
%% node's utilization answers, and it tells it as any node does, so that a
%% compute that names no peer runs there once it has.
%%
%% A library on its load path is loaded and its binding not evaluated, so a
%% spawn whose reach names the binding is NotLoaded, the node saying so, a
%% regression test written after the code, but a constant, which has its
%% value wherever its form is (§4.6, the log's *The Review's Decisions*). A
%% fault in received code is reported there at the spawn's site, the
%% sender's, with the peer that spawned it. A function that crossed with the
%% first lambda's enclosing definition is spawned twice and faults twice,
%% the traces of both its faults naming its frame by its name and the
%% sender's line (Appendix E.21), which names no unit, so that it shipped
%% nothing at its own spawns is ern_exchange_tests' alone.
%%
%% The entry process is among its live processes, under the site `bare
%% node`; `ern stop` ends it by termination, with nothing said of its entry
%% process and its ernest.pid gone; and started again, a process spawned
%% there that calls `Os.exit(3)` ends it with status 3. The lambdas are
%% written in the definition that spawns everything else, whose references
%% cross with them, a function that calls a foreign function among them.
%% Written after the code
bare_node_test_() ->
    ern_harness:nodes_test({waits, 20}, fun bare_node/1).

bare_node(Base) ->
    {SharedDir, Program, Source} = bare_build(Base),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    %% how often the bare node tells its utilization, which the program
    %% waits one of before its pick: the scenario's, and no bound
    Interval = 200,
    ern_harness:edit(B, fun(Conf) -> Conf#{<<"utilization-interval">> => Interval} end),
    ern_harness:edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"b">>]}} end),
    WaitB = ern_harness:bare_started(B, [SharedDir]),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    Placing = [?ERN, " run --config-dir ", A, " --load-path ", SharedDir, " ", Program, " b"],
    {_, WaitA} = ern_harness:launched(A, [Placing, " ", integer_to_list(Interval)]),
    ?assertEqual(0, WaitA()),
    Site = fun(Part) -> "Bare.placed:" ++ integer_to_list(line_of(Source, Part)) end,
    Process = fun(Part) -> "the process of " ++ Site(Part) end,
    Raised = " faulted: foreign function erlang:binary_to_integer/1 raised error:badarg, spawned"
             " by the peer a\n",
    [ern_harness:says(B, Line)
     || Line <- ["the peer a's spawn at " ++ Site("Shared.greet") ++ " was not loaded: the"
                 " binding Shared.greeting has no value here",
                 Process("\"divides: \"") ++ " faulted: division by zero, spawned by the peer a\n",
                 Process("\"raises: \"") ++ Raised, Process("\"raises again: \"") ++ Raised]],
    [ern_harness:prints(B, Line) || Line <- ["counted 1", "counted 7", "bye"]],
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = ern_harness:said(A),
    {OutB, ErrB} = ern_harness:said(B),
    [ern_harness:has(Out, Line)
     || Line <- ["spawn: Right", "compute: Right(42)", "entry shown: Right(true)",
                 "offering: Right", "found: Right", "utilization: Right",
                 "picked: Right(42)", "binding: Io.NotLoaded", "ground: Right",
                 "divides: Right",
                 "raises: Right", "raises again: Right", "Shared.greeting evaluated"]],
    ?assertEqual(nomatch, string:find(OutB, "Shared.greeting evaluated")),
    Raises = "\n    Bare.raises:" ++ integer_to_list(line_of(Source, "fn raises()")) ++ "\n",
    ?assertEqual(2, length(string:split(ErrB, Raises, all)) - 1),
    [?assertEqual(nomatch, string:find(ErrB, Part)) || Part <- ["killed", "bare node"]],
    ?assertNot(filelib:is_file(filename:join(B, "ernest.pid"))),
    %% started again, ended by a process spawned there
    WaitExit = ern_harness:bare_started(B, [SharedDir]),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    {_, WaitExiting} = ern_harness:launched(A, [Placing, " exit"]),
    ?assertEqual(0, WaitExiting()),
    ?assertEqual(3, WaitExit()),
    {OutExiting, _} = ern_harness:said(A),
    {_, ErrExit} = ern_harness:said(B),
    ern_harness:has(OutExiting, "exit: Right"),
    ?assertEqual(nomatch, string:find(ErrExit, "faulted")),
    ?assertNot(filelib:is_file(filename:join(B, "ernest.pid"))).

%% report §4.6, §8.7, §11.1: a constant a function's reach names has its
%% value wherever its form is, made from the form and evaluated nowhere:
%% a compute on a bare node, which holds none of the program's definitions,
%% reads a literal binding, a constructed one and a list of tuples, their
%% forms crossing with the function's, and a binding whose initializer is
%% computed is still NotLoaded there, the node saying so. A program of the
%% full review's, written with the rule (the log's *The Review's
%% Decisions*)
constant_crosses_test_() ->
    ern_harness:nodes_test({waits, 7}, fun constant_crosses/1).

constant_crosses(Base) ->
    ProgramDir = filename:join(Base, "program"),
    ok = filelib:ensure_path(ProgramDir),
    ok = file:write_file(
           filename:join(ProgramDir, "main.ern"),
           ["type Point = Point(x : Int, y : Int)\n"
            "let limit = 10\n"
            "let origin = Point(x = 1, y = 2)\n"
            "let tags = [#(\"a\", 1), #(\"b\", -2)]\n"
            "let computed = List.size([1, 2])\n"
            "export fn main() : Unit = {\n"
            "    let added = Peer.compute(\"b\", fn() = limit + 1, waitMs());\n"
            "    Io.println(\"limit: \" <> Io.show(added));\n"
            "    let summed = Peer.compute(\"b\", fn() = origin.x + origin.y, waitMs());\n"
            "    Io.println(\"origin: \" <> Io.show(summed));\n"
            "    Io.println(\"tags: \" <> Io.show(Peer.compute(\"b\", fn() = tags, waitMs())));\n"
            "    let read = Peer.compute(\"b\", fn() = computed, waitMs());\n"
            "    Io.println(\"computed: \" <> Io.show(read))\n"
            "}\n",
            ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([ProgramDir]),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    WaitB = ern_harness:bare_started(B, []),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    {_, WaitA} = ern_harness:launched(A, [?ERN, " run --config-dir ", A, " ",
                                          filename:join(ProgramDir, "main.erc")]),
    ?assertEqual(0, WaitA()),
    ern_harness:says(B, "the binding Main.computed has no value here"),
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = ern_harness:said(A),
    [ern_harness:has(Out, Line)
     || Line <- ["limit: Right(11)", "origin: Right(3)",
                 "tags: Right([#(\"a\", 1), #(\"b\", -2)])",
                 "computed: Left(Io.NotLoaded(\"the binding Main.computed has no value here\"))"]].

%% A program of its own, File its name and Text its text, the declaration
%% of waitMs() after it, built in Base's program/ and run to its end on a
%% node, a, with the argument `b`, the name of a bare node that listens on
%% a port of its choosing and lists a. Both nodes' directories and the
%% bare node's wait.
ran_beside_bare(Base, File, Text) ->
    ProgramDir = filename:join(Base, "program"),
    ok = filelib:ensure_path(ProgramDir),
    ok = file:write_file(filename:join(ProgramDir, File ++ ".ern"),
                         unicode:characters_to_binary([Text,
                                                       ern_harness:wait_ms_declaration()])),
    0 = ern_harness:built([ProgramDir]),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    WaitB = ern_harness:bare_started(B, []),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    {_, WaitA} = ern_harness:launched(A, [?ERN, " run --config-dir ", A, " ",
                                          filename:join(ProgramDir, File ++ ".erc"), " b"]),
    ?assertEqual(0, WaitA()),
    {A, B, WaitB}.

%% report §4.6, §8.7, §12.7: libs/ansi's bindings are constants, so a
%% program's lambda that names one has its value on a bare node, the form
%% crossing with the code and evaluated nowhere: a spawn whose reach names
%% Ansi.clearScreen, which brings its enclosing definition, a compute of
%% another definition's lambda that names it, and a spawn of a lambda the
%% node then holds, which names Ansi.clearBelow, each run with the
%% library's values and none said to be not loaded. A binding of the
%% program's own whose initializer computes has no value there,
%% constant_crosses/1's
lambda_reach_on_a_bare_node_test_() ->
    ern_harness:nodes_test({waits, 9}, fun lambda_reach_on_a_bare_node/1).

lambda_reach_on_a_bare_node(Base) ->
    Program = ["// Report §8.7, §12.7: lambdas whose reach names a binding of libs/ansi's,\n"
               "// spawned and computed on a bare node.\n"
               "\n"
               "export fn main() : Unit =\n"
               "    match Os.arguments {\n"
               "        [bare] -> placed(bare)\n"
               "      | _ -> Unit\n"
               "    }\n"
               "\n"
               "// The first spawn brings this definition, so the node holds the last\n"
               "// spawn's lambda when it comes.\n"
               "fn placed(bare : String) : Unit = {\n"
               "    let cleared = Peer.spawn(bare, fn() = Io.println(Io.show(Ansi.clearScreen)),"
               " waitMs());\n"
               "    Io.println(\"spawned: \" <> outcome(cleared));\n"
               "    computed(bare);\n"
               "    let below = Peer.spawn(bare, fn() = Io.println(Io.show(Ansi.clearBelow)),"
               " waitMs());\n"
               "    Io.println(\"held: \" <> outcome(below))\n"
               "}\n"
               "\n"
               "fn computed(bare : String) : Unit =\n"
               "    Io.println(\"computed: \" <> Io.show(Peer.compute(bare,"
               " fn() = Ansi.clearScreen, waitMs())))\n"
               "\n"
               "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
               "    match spawned {\n"
               "        Right(_) -> \"Right\"\n"
               "      | Left(failure) -> Io.show(failure)\n"
               "    }\n"],
    {A, B, WaitB} = ran_beside_bare(Base, "reach", Program),
    [ern_harness:prints(B, Line) || Line <- ["\"\\u{1B}[2J\\u{1B}[H\"", "\"\\u{1B}[J\""]],
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    [ern_harness:has(Out, Line) || Line <- ["spawned: Right",
                                            "computed: Right(\"\\u{1B}[2J\\u{1B}[H\")",
                                            "held: Right"]],
    ?assertEqual(nomatch, string:find(ErrB, "was not loaded")).

%% report §12.7, §8.7, Appendix E.28: a binding an arrival's code reads
%% beyond the spawned function's reach, which the node holds without its
%% value, is linked to the unit that holds it. A bare node holds `Config`
%% from its load path, unevaluated, and a lambda spawned there brings its
%% enclosing definition, whose code calls `Config.shout` and reads
%% `Config.greeting` in two other lambdas. A spawn of the one and a compute
%% of the other, which the node then holds, are NotLoaded, the node naming
%% the binding; once a compute's `Code.load` has evaluated the module
%% there, both run and read its value, and nothing faults.
%%
%% Written before its code, a regression test of the order the log's *A
%% Top-Level Binding Stays the Node's* names: the binding was linked to a
%% fault, and once the load had given it its value the held spawn passed
%% the check and faulted on the link. Where the node holds the binding in
%% no unit the link is a fault still, beyond_reach/1's
binding_linked_to_its_holder_test_() ->
    ern_harness:nodes_test({waits, 12}, fun binding_linked_to_its_holder/1).

binding_linked_to_its_holder(Base) ->
    SharedDir = filename:join(Base, "shared"),
    ProgramDir = filename:join(Base, "program"),
    [ok = filelib:ensure_path(Dir) || Dir <- [SharedDir, ProgramDir]],
    ok = file:write_file(
           filename:join(SharedDir, "config.ern"),
           unicode:characters_to_binary(
             ["// Report §8.5, §8.7: a module a bare node holds from its load path, whose\n"
              "// binding has no value there until a load evaluates it.\n"
              "\n"
              "export let greeting = String.toUpper(\"held\")\n"
              "\n"
              "export fn shout(text : String) : String =\n"
              "    String.toUpper(text)\n"])),
    Source = "// Report §8.7, §12.7: lambdas of one definition spawned on a bare node\n"
             "// that holds Config, before and after a load gives its binding a value.\n"
             "\n"
             "export fn main() : Unit =\n"
             "    match Os.arguments {\n"
             "        [bare, path] -> {\n"
             "            placed(bare, false);\n"
             "            placed(bare, true);\n"
             "            let loaded = Peer.compute(bare, fn() = Code.load(Path(path)),"
             " waitMs());\n"
             "            Io.println(\"loaded: \" <> Io.show(loaded));\n"
             "            placed(bare, true)\n"
             "        }\n"
             "      | _ -> Unit\n"
             "    }\n"
             "\n"
             "// The first call's spawn brings this definition whole, its code calling\n"
             "// Config.shout, so the node holds the later calls' lambdas when they come.\n"
             "fn placed(bare : String, read : Bool) : Unit =\n"
             "    if read then {\n"
             "        let greeted = Peer.spawn(bare, fn() = Io.println(Config.greeting),"
             " waitMs());\n"
             "        Io.println(\"greeted: \" <> outcome(greeted));\n"
             "        let computed = Peer.compute(bare, fn() = Config.greeting, waitMs());\n"
             "        Io.println(\"computed: \" <> Io.show(computed))\n"
             "    } else {\n"
             "        let shouted = Peer.spawn(bare, fn() = Io.println(Config.shout(\"plain\")),"
             " waitMs());\n"
             "        Io.println(\"shouted: \" <> outcome(shouted))\n"
             "    }\n"
             "\n"
             "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
             "    match spawned {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n",
    ok = file:write_file(filename:join(ProgramDir, "held.ern"),
                         unicode:characters_to_binary([Source, ern_harness:wait_ms_declaration()])),
    0 = ern_harness:built([SharedDir]),
    0 = ern_harness:built(["--load-path", SharedDir, ProgramDir]),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    WaitB = ern_harness:bare_started(B, [SharedDir]),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    {_, WaitA} = ern_harness:launched(A,
                                      [?ERN, " run --config-dir ", A, " --load-path ", SharedDir,
                                       " ",
                                       filename:join(ProgramDir, "held.erc"), " b ",
                                       filename:join(SharedDir, "config.erc")]),
    ?assertEqual(0, WaitA()),
    [ern_harness:prints(B, Line) || Line <- ["PLAIN", "HELD"]],
    Site = fun(Part) -> "Held.placed:" ++ integer_to_list(line_of(Source, Part)) end,
    [ern_harness:says(B, Line)
     || Line <- ["the peer a's spawn at " ++ Site("let greeted") ++ " was not loaded:"
                 " the binding Config.greeting has no value here",
                 "the peer a's compute at " ++ Site("let computed") ++ " was not loaded:"
                 " the binding Config.greeting has no value here"]],
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    Lacked = "Io.NotLoaded(\"the binding Config.greeting has no value here\")",
    ?assertEqual(["shouted: Right", "greeted: " ++ Lacked, "computed: Left(" ++ Lacked ++ ")",
                  "loaded: Right(Right(Unit))", "greeted: Right", "computed: Right(\"HELD\")",
                  ""],
                 string:split(Out, "\n", all)),
    ?assertEqual(nomatch, string:find(ErrB, "faulted")).

%% report §12.7, §8.4, Appendix H: a program's foreign type, which no peer
%% declares, crosses by its name in the code that names it. Three lambdas,
%% each in a definition of its own, are computed on a bare node: the first
%% calls foreign functions whose types name `Token`, the second one whose
%% result names `Boxed`, a type of the program's with a field of `Token`,
%% which arrives with it, and the third the same function where the node
%% then holds `Boxed`. Each answers, and the node says nothing of a load.
%%
%% Written before its code: the shell's foreign types made its attach
%% fail, the node's back end finding no unit for `Session`, and no test
%% crossed a program's foreign type before
foreign_type_crosses_test_() ->
    ern_harness:nodes_test({waits, 7}, fun foreign_type_crosses/1).

foreign_type_crosses(Base) ->
    Program = ["// Report §12.7: lambdas whose definitions name a foreign type of the\n"
               "// program's own, computed on a bare node.\n"
               "\n"
               "foreign type Token\n"
               "\n"
               "type Boxed = Boxed(Token)\n"
               "\n"
               "foreign fn token() : Token =\n"
               "    \"erlang:make_ref/0\"\n"
               "\n"
               "foreign fn isToken(token : Token) : Bool =\n"
               "    \"erlang:is_reference/1\"\n"
               "\n"
               "foreign fn unboxed(counts : List(Int)) : List(Boxed) =\n"
               "    \"lists:reverse/1\"\n"
               "\n"
               "export fn main() : Unit =\n"
               "    match Os.arguments {\n"
               "        [bare] -> {\n"
               "            Io.println(\"tokened: \" <> Io.show(tokened(bare)));\n"
               "            Io.println(\"reversed: \" <> Io.show(reversed(bare)));\n"
               "            Io.println(\"emptied: \" <> Io.show(emptied(bare)))\n"
               "        }\n"
               "      | _ -> Unit\n"
               "    }\n"
               "\n"
               "fn tokened(bare : String) : Either(Io.Error, Bool) =\n"
               "    Peer.compute(bare, fn() = isToken(token()), waitMs())\n"
               "\n"
               "fn reversed(bare : String) : Either(Io.Error, Bool) =\n"
               "    Peer.compute(bare, fn() = List.isEmpty(List.reverse(unboxed([]))),"
               " waitMs())\n"
               "\n"
               "fn emptied(bare : String) : Either(Io.Error, Bool) =\n"
               "    Peer.compute(bare, fn() = List.isEmpty(unboxed([])), waitMs())\n"],
    {A, B, WaitB} = ran_beside_bare(Base, "handle", Program),
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    ?assertEqual(["tokened: Right(true)", "reversed: Right(true)", "emptied: Right(true)", ""],
                 string:split(Out, "\n", all)),
    ?assertEqual(nomatch, string:find(ErrB, "was not loaded")).

%% report §11.2 *The attached shell*, §12.7: an attach to a bare node whose
%% `HOME` is not UTF-8 runs, and `:quit` ends it with status 0, the shell
%% saying nothing of its own on standard error and the node no fault: the
%% bindings of the shell's that read `HOME`, `Ernest.Shell.History`'s, are
%% the local half's, which no spawn's reach names. A regression test,
%% written after the code: the node evaluated every binding of the shell's
%% units as it loaded them from its own tree, `History.directory` faulted,
%% and the attach was refused as `could not load the shell`
attach_unreadable_home_test_() ->
    ern_harness:nodes_test({waits, 5}, fun attach_unreadable_home/1).

attach_unreadable_home(Base) ->
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node,
                                         ["HOME=\"$(printf '\\377')\" ", ?ERN, " run --config-dir ",
                                          Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {Input, WaitShell} = ern_harness:launched(Ops,
                                              ["HOME=", Home, " ", ?ERN, " shell --config-dir ",
                                               Ops,
                                               " --attach node"]),
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    {_, Err} = ern_harness:said(Ops),
    ?assertEqual(nomatch, string:find(Err, "ern shell:")),
    ?assertMatch({0, _}, signaled("stop", Node)),
    ?assertEqual(143, WaitNode()),
    ?assertEqual(nomatch, string:find(ern_harness:written(Node, err), "faulted")).

%% report §11.2 *The attached shell*, §8.7, Appendix E.1: a node that lacks
%% a module the shell's definitions call answers the attach's spawn
%% `NotLoaded(text)`, and the shell says `ern shell: the node node could not
%% load the shell: text`, `text` what the node says after `was not loaded:`,
%% and exits with status 1. The shell and the node run from two releases of
%% this tree's version made under Base, which stand on one floor (§12.5),
%% the node's without `ern_shell`, the host module the shell's definitions
%% call.
attach_not_loaded_test_() ->
    ern_harness:nodes_test({waits, 6}, fun attach_not_loaded/1).

attach_not_loaded(Base) ->
    {ok, Text} = file:read_file(filename:join(ern_tree:tree(), "VERSION")),
    Version = string:trim(binary_to_list(Text)),
    [Whole, Lacking] = [released(filename:join(Base, Dir), ern_tree:build("shell"), Version)
                        || Dir <- ["whole", "lacking"]],
    ok = file:delete(filename:join([Base, "lacking", "build", "shell", "ebin", "ern_shell.beam"])),
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [Lacking, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {_, WaitShell} = ern_harness:launched(Ops,
                                          ["HOME=", Home, " ", Whole, " shell --config-dir ", Ops,
                                           " --attach node"]),
    ?assertEqual(1, WaitShell()),
    {_, Err} = ern_harness:said(Ops),
    Refused = "ern shell: the node node could not load the shell: the module ern_shell, which"
              " Ernest\\.Shell\\.",
    ?assertMatch({match, _}, re:run(Err, ["^", Refused, "[A-Za-z.]+ calls, is not here\n$"])),
    [_, Lacked] = string:split(Err, "could not load the shell: "),
    ern_harness:says(Node, "was not loaded: " ++ Lacked),
    ?assertMatch({0, _}, signaled("stop", Node)),
    ?assertEqual(143, WaitNode()).

%% report §8.7, §11.2 *The attached shell*, *What a node holds*: a node
%% holds the shell of its own build of `ern` from its start, so a shell of
%% that build attaches with an exchange that ships nothing, and the node
%% makes no unit for it. The node's program counts the units its exchanges
%% made through a host module, from the first name of their pool the host
%% holds no unit of (ern_arrival:name/1), so that the count follows the
%% pool's names.
attach_ships_nothing_test_() ->
    ern_harness:nodes_test({waits, 6}, fun attach_ships_nothing/1).

attach_ships_nothing(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "probe.ern"),
                         ["// A node's program that counts the units its node's exchanges made,\n"
                          "// and waits.\n"
                          "export foreign fn arrivals() : Int = \"ern_nodes_arrivals:counted/0\"\n"
                          "\n"
                          "export fn main() : Unit receiving Unit = {\n"
                          "    Io.println(\"ready\");\n"
                          "    receive {\n"
                          "        _ -> Unit\n"
                          "    }\n"
                          "}\n"]),
    Arrivals = filename:join(Root, "ern_nodes_arrivals.erl"),
    ok = file:write_file(Arrivals,
                         <<"-module(ern_nodes_arrivals).\n"
                           "-export([counted/0]).\n"
                           "counted() ->\n"
                           "    {_, Next} = ern_arrival:name(1),\n"
                           "    Next - 2.\n">>),
    {ok, _} = compile:file(Arrivals, [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    WaitNode = ern_harness:start(Node, filename:join(Root, "probe.erc"), []),
    ern_harness:prints(Node, "ready"),
    {Input, WaitShell} = attached(Ops, "node", Base),
    entered(Input, Ops, ["Probe.arrivals()"], "> 0 : Int\n"),
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    ern_harness:stop(Node, WaitNode),
    {_, Err} = ern_harness:said(Ops),
    ?assertEqual(nomatch, string:find(Err, "ern shell:")).

%% report §8.7, §11.2: a node of a tree whose shell is not built is refused
%% at its start, as `ern shell` is in that tree, and leaves no ernest.pid.
%% The tree is a release made from this one under Base with no unit of the
%% shell's in its build.
node_without_shell_test_() ->
    ern_harness:nodes_test({waits, 1}, fun node_without_shell/1).

node_without_shell(Base) ->
    {ok, Text} = file:read_file(filename:join(ern_tree:tree(), "VERSION")),
    NoShell = filename:join(Base, "no-shell"),
    ok = filelib:ensure_path(NoShell),
    Ern = released(filename:join(Base, "tree"), NoShell, string:trim(binary_to_list(Text))),
    Node = ern_harness:made(Base, "node", 0),
    ?assertEqual({1, "ern run: the shell is not built; run make\n"},
                 finished([Ern, " run --config-dir ", Node, " 2>&1"])),
    ?assertNot(filelib:is_regular(filename:join(Node, "ernest.pid"))).

%% report §4.2, §11.2 *The attached shell*, §12.7: a shell attaches to a
%% node whose program has a module `Shell` of its own, the shell's units
%% standing under `Ernest`, which no program's module takes: an input reads
%% the program's `Shell.greeting`, and `:quit` ends the shell with status
%% 0. A regression test, written after the code: the shell was `Shell`,
%% the node held the program's unit of that name where its load of the
%% toolchain's own units looked for the shell's, the link failed, and the
%% shell said the node ran another build of `ern`. It does not cover a
%% plain shell beside such a program, whose units the same names keep apart
attach_beside_a_program_shell_test_() ->
    ern_harness:nodes_test({waits, 7}, fun attach_beside_a_program_shell/1).

attach_beside_a_program_shell(Base) ->
    Root = filename:join(Base, "program"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    ok = file:write_file(filename:join(Root, "shell.ern"),
                         ["// A node's program whose module is named Shell, which waits.\n"
                          "export let greeting = \"the program's own Shell\"\n"
                          "\n"
                          "export fn main() : Unit receiving Unit = {\n"
                          "    Io.println(\"ready\");\n"
                          "    receive {\n"
                          "        _ -> Unit\n"
                          "    }\n"
                          "}\n"]),
    0 = ern_harness:built([Root]),
    PortNode = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", PortNode),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, PortNode}]),
    WaitNode = ern_harness:start(Node, filename:join(Root, "shell.erc"), []),
    ern_harness:prints(Node, "ready"),
    {Input, WaitShell} = attached(Ops, "node", Source),
    ern_harness:prints(Ops, ". :help for help."),
    entered(Input, Ops, ["Shell.greeting"], "\"the program's own Shell\" : String"),
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    ern_harness:stop(Node, WaitNode),
    {_, Err} = ern_harness:said(Ops),
    ?assertEqual(nomatch, string:find(Err, "ern shell:")).

%% report §11.2 *The attached shell*, §12.1 *A session's screen*, §11.8: a
%% shell attached in line mode to a node whose program reads lines, from a
%% node of its own that the node lists without an address. An input runs on
%% the node, and what it writes reaches the shell's own standard output,
%% while what the node's program writes stays on the node's; `:detach` is
%% no command and the greeting names `:quit`; `:load` compiles a module of
%% the shell's source root, which the shell's own node reads; the process of
%% a `let` lives while its name is in scope, and `:forget` ends it; and
%% `:processes` lists the node's program and what an input spawned, each
%% by its site.
%%
%% `:quit` ends the shell with status 0 and leaves that process running on
%% the node, which a second session lists. Written after the code, a
%% regression test of the attach; the tests after it hold the rest of an
%% attached session.
attached_shell_test_() ->
    ern_harness:nodes_test({waits, 17}, fun attached_shell/1).

attached_shell(Base) ->
    Root = filename:join(Base, "program"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    ok = file:write_file(filename:join(Root, "echo.ern"),
                         ["// A node's program, which writes a line of its own for each line\n"
                          "// it reads.\n"
                          "export fn main() : Unit = {\n"
                          "    Io.println(\"ready\");\n"
                          "    echoed()\n"
                          "}\n"
                          "\n"
                          "fn echoed() : Unit =\n"
                          "    match Io.readLine() {\n"
                          "        Some(line) -> {\n"
                          "            Io.println(\"the node's own: \" <> line);\n"
                          "            echoed()\n"
                          "        }\n"
                          "      | None -> Unit\n"
                          "    }\n"]),
    ok = file:write_file(filename:join(Source, "greet.ern"),
                         "export fn hello() : Unit = Io.println(\"hello from the operator\")\n"),
    0 = ern_harness:built([Root]),
    PortNode = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", PortNode),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, PortNode}]),
    {NodeInput, WaitNode} = ern_harness:started(Node, filename:join(Root, "echo.erc"), []),
    ern_harness:prints(Node, "ready"),
    {ShellInput, WaitShell} = attached(Ops, "node", Source),
    ern_harness:prints(Ops, ". :help for help."),
    true = port_command(ShellInput, "Io.println(\"written at the prompt\")\n"),
    ern_harness:prints(Ops, "written at the prompt"),
    true = port_command(NodeInput, "go\n"),
    ern_harness:prints(Node, "the node's own: go"),
    true = port_command(ShellInput, ":detach\n"),
    ern_harness:prints(Ops, "no command :detach; :help lists them"),
    true = port_command(ShellInput, ":load Greet\nGreet.hello()\n"),
    ern_harness:prints(Ops, "hello from the operator"),
    true = port_command(ShellInput, ["let p = Process.current()\n", "let q = p\n",
                                     "Optional.isSome(Process.status(q))\n"]),
    ern_harness:prints(Ops, "true : Bool"),
    true = port_command(ShellInput, [":forget p\n",
                                     "{ monitor(q, fn(down) = down); receive { _ -> Unit } }\n",
                                     "Optional.isSome(Process.status(q))\n"]),
    ern_harness:prints(Ops, "false : Bool"),
    true = port_command(ShellInput, ["let w : Address(Int) = spawn(fn() = receive { _ -> Unit })\n",
                                     ":processes\n"]),
    ern_harness:prints(Ops, "$Session1.input 11:1 "),
    ern_harness:prints(Ops, "Echo.main "),
    true = port_command(ShellInput, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    {Out, _} = ern_harness:said(Ops),
    ern_harness:has(Out,
                    "Greet, compiled from " ++ ern_build:shown(filename:join(Source, "greet.ern"))),
    ?assertEqual(nomatch, string:find(Out, "the node's own")),
    ?assertEqual(nomatch, string:find(Out, "Ernest.Shell.")),
    %% report §11.2: what the session started stays the node's
    {SecondInput, WaitSecond} = attached(Ops, "node", Source),
    true = port_command(SecondInput, ":processes\n:quit\n"),
    ern_harness:prints(Ops, "$Session1.input 11:1 "),
    ?assertEqual(0, WaitSecond()),
    ern_harness:stop(Node, WaitNode),
    {NodeOut, _} = ern_harness:said(Node),
    ern_harness:has(NodeOut, "the node's own: go"),
    ?assertEqual(nomatch, string:find(NodeOut, "written at the prompt")).

%% report §11.2 *The attached shell*, §11.8: where the node an attached
%% session runs on ends, the shell says `the node node ended` and exits
%% with status 0, and where it is lost, `the node node is lost` and status
%% 1; in line mode the prompt the screen last wrote is ended first, so that
%% the line stands on a row of its own, as a detach leaves it. Standard
%% error holds that line alone: the shell's own node says nothing of its
%% session's node's end or loss. Written before the fixes, which the line
%% sharing the prompt's row failed, and the shell's own node's `the peer
%% node ended` before it, in one run of sixteen. Each line is held to the
%% deployment guide's section 5, which quotes it.
attached_shell_ends_test_() ->
    ern_harness:nodes_test({waits, 10}, fun attached_shell_ends/1).

attached_shell_ends(Base) ->
    Ops = ern_harness:made(Base, "ops", none),
    [Ended, Lost] =
        lists:map(
          fun({Name, End, Status, Line}) ->
              Node = ern_harness:made(Base, Name, 0),
              ern_harness:lists(Node, [{"ops", Ops, none}]),
              {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
              ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
              {_, WaitShell} = attached(Ops, "node", Base),
              ern_harness:prints(Ops, ":help for help.\n> "),
              End(Node, WaitNode),
              ?assertEqual(Status, WaitShell()),
              {Out, Err} = ern_harness:said(Ops),
              ?assertMatch({true, _}, {lists:suffix(":help for help.\n> \n", Out), Out}),
              ?assertEqual(Line, Err),
              Err
          end, [{"ended", fun ern_harness:stop/2, 0, "the node node ended\n"},
                {"lost", fun lost/2, 1, "the node node is lost\n"}]),
    %% the lines as the deployment guide's section 5 quotes them
    ern_deployment_tests:cataloged(Ended, "5", "ended", [{"b", "node"}]),
    ern_deployment_tests:cataloged(Lost, "5", "is lost", [{"b", "node"}]).

%% report §11.2 *The attached shell*, Appendix E.27: the shell's own node
%% tells no peer how busy it is, so at the prompt of the node it attaches
%% to, which lists no other peer, `Peer.utilizations()` holds no row for it
%% and a compute that names no node answers `Left(Unreachable)` and runs on
%% it never; a compute that names it runs there, answering the shell's own
%% node's peers. Written before the fix, which the row for `ops` and the
%% compute that ran on it failed.
attached_utilization_test_() ->
    ern_harness:nodes_test({waits, 6}, fun attached_utilization/1).

attached_utilization(Base) ->
    Ops = ern_harness:made(Base, "ops", none),
    Node = ern_harness:made(Base, "node", 0),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    {Shell, WaitShell} = attached(Ops, "node", Base),
    ern_harness:prints(Ops, ":help for help.\n> "),
    Ms = ern_harness:wait_ms_text(),
    true = port_command(Shell, ["Peer.compute(\"ops\", fn() = Peer.peers(), ", Ms, ")\n"]),
    ern_harness:prints(Ops, "Right([\"node\"]) : Either(Io.Error, List(String))\n"),
    true = port_command(Shell, ["Peer.utilizations()\n",
                                "Peer.computeAnywhere(fn() = Peer.peers(), ", Ms, ")\n",
                                ":quit\n"]),
    ?assertEqual(0, WaitShell()),
    {Out, _} = ern_harness:said(Ops),
    ern_harness:has(Out, "> [] : List(#(String, Float, Int))\n"),
    ern_harness:has(Out, "> Left(Io.Unreachable) : Either(Io.Error, List(String))\n"),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, §11.8, §8.6, §12.5: a shell whose
%% node is lost ends with `the node node is lost` and status 1 within a
%% dial's time of the loss, though a dial of that node would wait the
%% whole of it: the shell's own node reads its configuration again with
%% the node's address moved to a port that takes a connection and never
%% answers, and the node is then ended outright. The end's drain asks
%% nothing of the screen, which went with the session, so that the host
%% dials no lost node to reach it. Written before the fix, the shell
%% ending a dial late.
attached_lost_unanswered_test_() ->
    ern_harness:nodes_test({waits, 7, ?DIAL_MS}, fun attached_lost_unanswered/1).

attached_lost_unanswered(Base) ->
    Ops = ern_harness:made(Base, "ops", none),
    Node = ern_harness:made(Base, "node", 0),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    {_, WaitShell} = attached(Ops, "node", Base),
    ern_harness:prints(Ops, ":help for help.\n> "),
    {ok, Hole} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, HolePort} = inet:port(Hole),
    ern_harness:lists(Ops, [{"node", Node, HolePort}]),
    ?assertEqual({0, ""}, finished([?ERN, " reload --config-dir ", Ops, " 2>&1"])),
    ern_harness:prints(Ops, "ernest.conf was read again"),
    Began = erlang:monotonic_time(millisecond),
    lost(Node, WaitNode),
    ?assertEqual(1, WaitShell()),
    Taken = erlang:monotonic_time(millisecond) - Began,
    ok = gen_tcp:close(Hole),
    ?assert(Taken < ern_carrier:dial_ms()),
    {_, Err} = ern_harness:said(Ops),
    ern_harness:has(Err, "the node node is lost\n").

%% report §11.2 *The attached shell*, *Editing*, §11.8: the same at a
%% terminal, through the pseudo-terminal's harness: the region is taken away
%% where the screen last painted it, what was typed after the prompt with
%% it, and the line stands on a row of its own under the prompt. The node's
%% program ends its node once the test opens a named pipe it reads, by
%% returning, or, told `lost`, by ending its own host outright, so that the
%% end comes while the shell waits at its prompt. No row holds the shell's
%% own node's line of its peer's end or loss, which the shell's line says.
%% Written before the fixes, the second red in eight runs of eight with
%% `the peer node ended` on a row of the screen.
attached_terminal_ends_test_() ->
    ern_harness:nodes_test({waits, 13}, fun attached_terminal_ends/1).

attached_terminal_ends(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "ender.ern"), ender()),
    0 = ern_harness:built([Root]),
    Ops = ern_harness:made(Base, "ops", none),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    lists:foreach(
      fun({Name, NodeStatus, Status, Line}) ->
          Port = ern_harness:free_port(),
          Node = ern_harness:made(Base, Name, Port),
          Pipe = filename:join(Base, Name ++ ".pipe"),
          [] = os:cmd("mkfifo " ++ Pipe),
          ern_harness:lists(Node, [{"ops", Ops, none}]),
          ern_harness:lists(Ops, [{"node", Node, Port}]),
          {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "ender.erc"),
                                              [Pipe, Name, filename:join(Node, "ernest.pid")]),
          ern_harness:prints(Node, "ready"),
          {Status, Screen} = ern_pty:run(Shell, [{expect, ":help for help."},
                                                 {expect, "> "},
                                                 {send, hex("abc")},
                                                 {expect, "abc"},
                                                 {put, Pipe}],
                                         [screen]),
          ?assertEqual(NodeStatus, WaitNode()),
          Rows = [string:trim(Row, trailing)
                  || Row <- string:split(binary_to_list(Screen), "\n", all)],
          Under = lists:dropwhile(fun(Row) -> Row =/= ">" end, Rows),
          ?assertMatch({[">" | _], _}, {Under, Rows}),
          ?assert(lists:member(Line, Under)),
          ?assertEqual([Line], [Row || Row <- Rows, string:find(Row, Line) =/= nomatch]),
          ?assertEqual([], [Row || Row <- Rows, Said <- ["the peer node ended",
                                                         "the peer node was lost"],
                                   string:find(Row, Said) =/= nomatch]),
          ?assertEqual(nomatch, string:find(Screen, "abc"))
      end, [{"ended", 0, 0, "the node node ended"},
            {"lost", 137, 1, "the node node is lost"}]).

%% A node's program that ends its node once the named pipe it is given has
%% been opened and closed: by returning, or, told `lost`, by ending its
%% host outright, whose process its pid file names, each run waiting the
%% harness's time for one step.
ender() ->
    ["export fn main() : Unit =\n"
    "    match Os.arguments {\n"
    "        [pipe, how, pidFile] -> {\n"
    "            Io.println(\"ready\");\n"
    "            let _ = Os.run(Os.command(\"cat\", [pipe]), waitMs());\n"
    "            if how == \"lost\" then {\n"
    "                let kill = \"kill -KILL $(cat \" <> pidFile <> \")\";\n"
    "                let _ = Os.run(Os.command(\"sh\", [\"-c\", kill]), waitMs());\n"
    "                Unit\n"
    "            } else\n"
    "                Unit\n"
    "        }\n"
    "      | _ -> Unit\n"
    "    }\n",
     ern_harness:wait_ms_declaration()].

%% Text as the pseudo-terminal's harness sends it, its bytes in hex.
hex(Text) ->
    lists:flatten([io_lib:format("~2.16.0b", [Char]) || Char <- Text]).

%% A node ended outright, which tells its peers nothing, so that each loses
%% its connection to it.
lost(Dir, Wait) ->
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    _ = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(137, Wait()).

%% report §11.2 *The attached shell*, §11.8: an attach that fails is the
%% job's refusal, naming the spawn's `Io.Error`, with status 1: one that no
%% node answers says that the peer is unreachable, at once where nothing
%% takes the connection and at the dial's end where a port takes it and
%% nothing answers over it, since the attach waits twice a dial's time; and
%% one to a peer the shell's own node does not list that it is not listed,
%% each line as the deployment guide's section 5 quotes it. Written after
%% the code, a regression test of the refusal, and of the dial that waits
%% (the log's *The Shell's Own Node*), whose answer was a race between the
%% two
attach_refused_test_() ->
    ern_harness:nodes_test({waits, 6, ?DIAL_MS}, fun attach_refused/1).

attach_refused(Base) ->
    [Absent, Unanswering,
     Ops] = [ern_harness:made(Base, Name, none) || Name <- ["absent", "hole", "ops"]],
    {ok, Hole} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, HolePort} = inet:port(Hole),
    ern_harness:lists(Ops,
                      [{"absent", Absent, ern_harness:free_port()},
                       {"hole", Unanswering, HolePort}]),
    Refused = fun(Name) ->
                  {_, Wait} = attached(Ops, Name, Base),
                  ?assertEqual(1, Wait()),
                  {Out, Err} = ern_harness:said(Ops),
                  ?assertEqual("", Out),
                  Err
              end,
    ern_deployment_tests:cataloged(Refused("absent"), "5", "is unreachable", [{"b", "absent"}]),
    Began = erlang:monotonic_time(millisecond),
    ern_deployment_tests:cataloged(Refused("hole"), "5", "is unreachable", [{"b", "hole"}]),
    ?assert(erlang:monotonic_time(millisecond) - Began < 2 * ern_carrier:dial_ms()),
    ok = gen_tcp:close(Hole),
    ern_deployment_tests:cataloged(Refused("nowhere"), "5", "is not listed", [{"b", "nowhere"}]).

%% report §11.2 *The attached shell*, §11.8, §12.6: an attach to a node
%% that takes the connection and answers nothing over it is refused once
%% twice a dial's time has passed, saying that the peer did not answer in
%% time,
%% with status 1, its standard output in line mode the shell's own node's
%% line of the connection alone (§11.2 *The shell*), the line as the
%% deployment guide's section 5 quotes it. The node's program
%% suspends its gateway, the process that answers a peer's frames, a
%% spawn's among them, so that the connection stands and the spawn waits.
%% Written after the code, a regression test
attach_unanswered_test_() ->
    ern_harness:nodes_test({waits, 5, 2 * ?DIAL_MS}, fun attach_unanswered/1).

attach_unanswered(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "stall.ern"), stall()),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "stall.erc"), []),
    ern_harness:prints(Node, "suspended: true"),
    {_, Wait} = attached(Ops, "node", Base),
    ?assertEqual(1, Wait()),
    {Out, Err} = ern_harness:said(Ops),
    ?assertEqual("the peer node connected\n", unstamped(Out)),
    ern_deployment_tests:cataloged(Err, "5", "did not answer in time", [{"b", "node"}]),
    ern_harness:stop(Node, WaitNode).

%% report §11.2, Appendix E.21, E.27, §8.3: on a shell that is a node,
%% `Process.peer` answers None for a process of the node and the peer's name
%% for one a spawn placed on that peer; a call without limit to that process
%% is listed by `:processes` with its callee as a process of the peer, and a
%% wait for a peer's utilization, a spawn's and a find's, the peer's gateway
%% suspended so that no answer comes, each with no callee and its limit. The
%% listing is asked twice, since the first may meet the host's work in each
%% process as the input before it is let go (ern_shell_tests' listed/3).
%%
%% Report Appendix E.1, §8.3: the address of the process on the peer, and
%% that process, print the peer's name before the number, and the shell's
%% own process its number alone. A regression test, written after the code
%% but for its printed values, which were written before
processes_on_peers_test_() ->
    ern_harness:nodes_test({waits, 12}, fun processes_on_peers/1).

processes_on_peers(Base) ->
    Root = filename:join(Base, "program"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    ok = file:write_file(filename:join(Root, "stall.ern"), stall()),
    0 = ern_harness:built([Root]),
    [PortA, PortB] = [ern_harness:free_port(), ern_harness:free_port()],
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    S = ern_harness:made(Base, "s", none),
    ern_harness:lists(A, [{"s", S, none}]),
    ern_harness:lists(B, [{"s", S, none}]),
    ern_harness:lists(S, [{"a", A, PortA}, {"b", B, PortB}]),
    ern_harness:edit(S, fun(Conf) -> Conf#{<<"services">> => #{<<"stalled">> => [<<"b">>]}} end),
    WaitA = ern_harness:bare_started(A, []),
    {_, WaitB} = ern_harness:started(B, filename:join(Root, "stall.erc"), []),
    ern_harness:prints(B, "suspended: true"),
    {Input, WaitS} = ern_harness:shell_started(S, Source),
    true = port_command(Input,
                        ["fn calling(process : Process) : Unit = match Process.status(process) {\n"
                         "    Some(Process.Status(activity = Process.Calling())) -> Unit\n"
                         "  | _ -> calling(process)\n"
                         "}\n",
                         "fn kept() : Unit receiving Reply(Int) = receive { _ -> kept() }\n",
                         "let served = match Peer.spawn(\"a\", kept, ", ern_harness:wait_ms_text(),
                         ") {\n"
                         "    Right(address) -> address\n"
                         "  | Left(failure) -> fault(Io.show(failure))\n"
                         "}\n",
                         "Process.peer(Process.current())\n",
                         "Process.peer(Process.fromAddress(served))\n",
                         "let caller : Address(Never) = spawn(fn() = {\n"
                         "    let _ : Int = Address.callForever(served, fn(reply) = reply);\n"
                         "    Unit\n"
                         "})\n",
                         "let asker : Address(Never) = spawn(fn() = {\n"
                         "    let _ = Peer.utilization(\"b\", 600000);\n"
                         "    Unit\n"
                         "})\n",
                         "let spawner : Address(Never) = spawn(fn() = {\n"
                         "    let _ = Peer.spawn(\"b\", kept, 600000);\n"
                         "    Unit\n"
                         "})\n",
                         "let finder : Address(Never) = spawn(fn() = {\n"
                         "    let stalled : Peer.Service(Int) = Peer.service(\"stalled\");\n"
                         "    let _ = Peer.find(stalled, 600000);\n"
                         "    Unit\n"
                         "})\n",
                         "calling(Process.fromAddress(caller))\n",
                         "calling(Process.fromAddress(asker))\n",
                         "calling(Process.fromAddress(spawner))\n",
                         "calling(Process.fromAddress(finder))\n",
                         "served\n",
                         "Process.current()\n",
                         "Process.fromAddress(served)\n",
                         ":processes\n:processes\n"]),
    ern_harness:prints(S, "None : Optional(String)"),
    ern_harness:prints(S, "Some(\"a\") : Optional(String)"),
    ern_harness:prints(S, "$Session1.input 6:1 calling a process of the peer a without limit for "),
    ern_harness:prints(S, "$Session1.input 7:1 calling for "),
    ern_harness:prints(S, "$Session1.input 8:1 calling for "),
    ern_harness:prints(S, "$Session1.input 9:1 calling for "),
    ern_harness:prints(S, " : Process\n", 2, ?WAIT_MS),
    Printed = ern_harness:written(S, out),
    [?assertMatch({match, _}, re:run(Printed, Line))
     || Line <- ["<address\\.a\\.[0-9]+> : Address\\(Reply\\(Int\\)\\)\n",
                 "<process\\.[0-9]+> : Process\n", "<process\\.a\\.[0-9]+> : Process\n"]],
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, WaitS()),
    ern_harness:stop(B, WaitB),
    ern_harness:stop(A, WaitA).

%% A node's program that suspends its node's gateway, which answers its
%% peers' frames (report §12.6), and then waits.
stall() ->
    "// The gateway suspended: the node takes a connection and answers\n"
    "// nothing over it.\n"
    "foreign fn whereis(name : Foreign.Term) : Foreign.Term = \"erlang:whereis/1\"\n"
    "foreign fn suspended(process : Foreign.Term) : Bool = \"erlang:suspend_process/1\"\n"
    "\n"
    "export fn main() : Unit receiving Unit = {\n"
    "    let gateway = whereis(Foreign.atom(\"ern_gateway\"));\n"
    "    Io.println(\"suspended: \" <> Io.show(suspended(gateway)));\n"
    "    receive { _ -> Unit }\n"
    "}\n".

%% report §11.2 *The attached shell*, *Startup and history*, §8.7, §12.5,
%% §12.7: a shell of another release of `ern` than its node's, on the
%% node's floor, attaches, its definitions crossing to the node by the
%% exchange as any program's do, and its start line names the node's
%% release beside its own; a shell of the node's own release then attaches
%% with the plain start line. Each leaves by `:quit` with status 0 and says
%% nothing of its own on standard error.
%%
%% The builds are releases made from this tree under Base, each on the
%% floor of the release VERSION names: the node's of that version, and the
%% other a patch release after it, its shell compiled from the shell's
%% source with one function's form changed, `isAttaching`'s clauses in the
%% other order, so that the local half, whose reach names it, hashes
%% otherwise than the node's own release's.
%%
%% A regression test, written after the code: a shell of another build was
%% refused, the node saying that its tree held none of the definition the
%% spawn named (the log's *The Shell Attaches as a Program Spawns*)
attach_other_build_test_() ->
    ern_harness:nodes_test({waits, 7}, fun attach_other_build/1).

attach_other_build(Base) ->
    {ok, Text} = file:read_file(filename:join(ern_tree:tree(), "VERSION")),
    Version = string:trim(binary_to_list(Text)),
    [Major, Minor, Patch] = string:split(Version, ".", all),
    Later = lists:flatten(lists:join(".", [Major, Minor,
                                           integer_to_list(list_to_integer(Patch) + 1)])),
    Own = released(filename:join(Base, "one"), ern_tree:build("shell"), Version),
    Other = changed_release(filename:join(Base, "two"),
                            <<"        Attaching(_) -> true\n      | Beside(_) -> false\n">>,
                            <<"        Beside(_) -> false\n      | Attaching(_) -> true\n">>,
                            Later),
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [Own, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Attached = fun(Ern, Line) ->
                   {Input, Wait} = ern_harness:launched(Ops,
                                                        ["HOME=", Home, " ", Ern,
                                                         " shell --config-dir ",
                                                         Ops, " --attach node"]),
                   true = port_command(Input, ":quit\n"),
                   ?assertEqual(0, Wait()),
                   {Out, Err} = ern_harness:said(Ops),
                   ern_harness:has(Out, Line),
                   ?assertEqual(nomatch, string:find(Err, "ern shell:"))
               end,
    Attached(Other, "Ernest " ++ Later ++ ", session 1 on ern " ++ Version
             ++ ". :help for help.\n"),
    Attached(Own, "Ernest " ++ Version ++ ", session 2. :help for help.\n"),
    ern_harness:stop(Node, WaitNode).

%% A release of `ern` of Version made in Dir as released/3 makes one, and
%% its launcher, whose shell is compiled from the shell's source with Old
%% replaced by New in `ernest/shell.ern`: the source copied into the
%% release's own tree and built there by the release's `ern`, since a
%% module of `Ernest` is built in the shell's own source root alone (report
%% §4.2), the tree's of the `ern` that builds it. The build is one of the
%% test's steps.
changed_release(Dir, Old, New, Version) ->
    Ern = released(Dir, ern_tree:build("shell"), Version),
    Tree = ern_tree:tree(),
    Source = filename:join([Dir, "src", "shell"]),
    [begin
         File = filename:join(Source, Relative),
         ok = filelib:ensure_dir(File),
         {ok, _} = file:copy(filename:join([Tree, "src", "shell", Relative]), File)
     end || Relative <- filelib:wildcard("**/*.ern", filename:join([Tree, "src", "shell"]))],
    Main = filename:join([Source, "ernest", "shell.ern"]),
    {ok, Text} = file:read_file(Main),
    [Before, After] = binary:split(Text, Old),
    ok = file:write_file(Main, [Before, New, After]),
    ?assertMatch({0, _}, finished([Ern, " build --build-root ",
                                   filename:join([Dir, "build", "shell"]), " ", Source])),
    Ern.

%% Report §12.5, §12.7: a release of `ern` of Version made in Dir from
%% this tree, and its launcher: the tree's code, the runtime's helper, the
%% standard library and the libraries copied as they stand, the shell's
%% build from Shell, and `ern_release` compiled again with Version and an
%% empty mark in place of `-dev`, as the release archive compiles it at the
%% release's tag (tools/install.sh), so that its version text is Version
%% alone and it stands on a release's floor.
released(Dir, Shell, Version) ->
    Tree = ern_tree:tree(),
    Copies = [{filename:join(Tree, File), filename:join(Dir, File)}
              || Pattern <- ["bin/ern", "build/toolchain/*/ebin/*", "build/shared/ebin/*",
                             "build/nodes/ebin/*", "build/runtime/ebin/*",
                             "build/runtime/priv/ern_exec", "build/shell/ebin/*",
                             "build/stdlib/*.erc", "build/libs/*/*.erc", "build/libs/*/*.beam"],
                 File <- filelib:wildcard(Pattern, Tree)]
        ++ [{filename:join(Shell, File), filename:join([Dir, "build", "shell", File])}
            || File <- filelib:wildcard("**/*.erc", Shell)],
    lists:foreach(fun({From, To}) ->
                      ok = filelib:ensure_dir(To),
                      {ok, _} = file:copy(From, To)
                  end, Copies),
    [ok = file:change_mode(filename:join(Dir, File), 8#755)
     || File <- ["bin/ern", "build/runtime/priv/ern_exec"]],
    {ok, ern_release} = compile:file(filename:join(Tree, "src/toolchain/builder/ern_release"),
                                     [{d, 'VERSION', Version},
                                      {d, 'MARK', ""},
                                      {outdir, filename:join(Dir, "build/toolchain/builder/ebin")},
                                      report]),
    filename:join([Dir, "bin", "ern"]).

%% report §11.2 *The attached shell*, *Faults*, *Loading and reloading*,
%% *Scope*, Appendix H, E.21, E.27: two shells attached at once to one bare
%% node, each from a directory of its own. Each session's names are its
%% own: `f()` answers 1 at the first prompt and 2 at the second. A type
%% each declares in one text is two types, its qualified name standing
%% under its session's namespace, which carries the session's number: each
%% session's offer of the service `ping` at its own `Ping` is taken, where a
%% second offer at one session's type answers its holder.
%%
%% A `:load` at the first prompt is in the second session's scope at its
%% next input. A `:reload` at the first names the first's own binding at
%% the first prompt, and is said at the second's, `Greet compiled again by
%% session 1`, naming the second's binding of the module's type moved to
%% its previous version, `Greet$1.Msg`. A fault of a process the first
%% session started is said at both prompts and on the node's standard
%% error, its site under the first session's namespace, `$Session1.input
%% 9:1`, and `Process.live()` at either prompt leaves out both sessions' own
%% processes and every evaluator: the bare node's entry process and the
%% three that the sessions' inputs spawned and still run are all it holds.
%%
%% The first detaches, and a third session from its directory takes a
%% number no session had, which its start line says, as each session's
%% does, the first attached to a node `ern run` started being its 1: its
%% offer of `ping` at its own `Ping` is taken beside the first session's,
%% whose process runs on, and `:processes` lists no evaluator of the first
%% session's load and reload, each having ended with its work.
%%
%% The shells run in Base, their source root `src` there, and the node
%% elsewhere, so that the load names the file from the operator's working
%% directory, where its local half reads it; on one machine the test cannot
%% show that the node never opens the file itself. Written after the code,
%% a regression test; the sites, the start line, the reload said and the
%% evaluators' end a regression test (the log's *Sites, Sessions and Their
%% Names*)
attached_sessions_test_() ->
    ern_harness:nodes_test({waits, 22}, fun attached_sessions/1).

attached_sessions(Base) ->
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    Greet = filename:join(Source, "greet.ern"),
    ok = file:write_file(Greet, greet("first", "")),
    Node = ern_harness:made(Base, "node", 0),
    [One, Two] = [ern_harness:made(Base, Name, none) || Name <- ["one", "two"]],
    ern_harness:lists(Node, [{"one", One, none}, {"two", Two, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    Port = ern_harness:bound_port(Node),
    [ern_harness:lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    Offered = "> Right(Unit) : Either(Process, Unit)\n",
    Waiting = ": Address(Ping) = spawn(fn() = receive { _ -> Unit })",
    {First, _} = Attached = sessioned(Base, One),
    ern_harness:prints(One,
                       "Ernest " ++ ern_release:version_text() ++ ", session 1. :help for help.\n"),
    entered(First, One, ["fn f() : Int = 1", "type Ping = Ping(Int)", "let p" ++ Waiting,
                         "Peer.offer(Peer.service(\"ping\"), p)", "f()"], "> 1 : Int\n"),
    ern_harness:has(ern_harness:written(One, out), Offered),
    {Second, WaitSecond} = sessioned(Base, Two),
    ern_harness:prints(Two, ", session 2. :help"),
    entered(Second, Two, ["fn f() : Int = 2", "type Ping = Ping(Int)", "let q" ++ Waiting,
                          "Peer.offer(Peer.service(\"ping\"), q)", "let r" ++ Waiting,
                          "Either.isRight(Peer.offer(Peer.service(\"ping\"), r))", "f()"],
            "> 2 : Int\n"),
    ern_harness:has(ern_harness:written(Two, out),
                    Offered ++ "> r : Address(Ping)\n> false : Bool\n"),
    %% report §11.2: a load and a reload are the node's
    entered(First, One, [":load Greet", "let n = Greet.Bye"], "> n : Greet.Msg\n"),
    ern_harness:has(ern_harness:written(One, out), "> Greet, compiled from src/greet.ern\n"),
    entered(Second, Two, ["Greet.hello()", "let m = Greet.Hello"], "> m : Greet.Msg\n"),
    ern_harness:has(ern_harness:written(Two, out), "> \"hello, first\" : String\n"),
    ok = file:write_file(Greet, greet("second", " | Again")),
    entered(First, One, [":reload"],
            "Greet.Msg changed: the binding n is of its previous version, Greet$1.Msg\n"),
    ern_harness:has(ern_harness:written(One, out), "> Greet, compiled again\n"),
    entered(Second, Two, ["m", "Greet.hello()"], "> \"hello, second\" : String\n"),
    ern_harness:has(ern_harness:written(Two, out),
                    "Greet compiled again by session 1\nGreet.Msg changed: the binding m"
                    " is of its previous version, Greet$1.Msg\n"),
    ern_harness:has(ern_harness:written(Two, out), "Hello : Greet$1.Msg\n"),
    %% report §11.2 *Faults*: the first session's tenth input faults the
    %% process its ninth spawned
    true = port_command(First, ["let w : Address(Int) = spawn(fn() = receive { n -> ",
                                "Io.println(Int.toString(10 / n)) })\n", "send(w, 0)\n"]),
    Faulted = "the process of $Session1.input 9:1 faulted: division by zero\n",
    [ern_harness:fault_line(Input, Ops, Faulted) || {Input, Ops} <- [{First, One}, {Second, Two}]],
    ern_harness:says(Node, Faulted),
    %% report Appendix E.21: no session's own process is live at a prompt
    [entered(Input, Ops, ["List.size(Process.live())"], "> 4 : Int\n")
     || {Input, Ops} <- [{First, One}, {Second, Two}]],
    {Out, _} = detached(Attached, One),
    ?assertEqual(nomatch, string:find(Out, "Ernest.Shell.")),
    {Third, WaitThird} = sessioned(Base, One),
    entered(Third, One, ["type Ping = Ping(Int)", "let s" ++ Waiting,
                         "Peer.offer(Peer.service(\"ping\"), s)", ":processes",
                         "List.size(Process.live())"],
            "> 5 : Int\n"),
    ThirdOut = string:find(ern_harness:written(One, out), ", session 3. :help"),
    ern_harness:has(ThirdOut, Offered),
    ern_harness:has(ThirdOut, "$Session1.input 3:1 "),
    ?assertEqual(nomatch, string:find(ThirdOut, "Greet")),
    _ = detached({Third, WaitThird}, One),
    {SecondOut, _} = detached({Second, WaitSecond}, Two),
    ?assertEqual(nomatch, string:find(SecondOut, "compiled again by session 2")),
    ern_harness:stop(Node, WaitNode).

%% The module the sessions load: its type, Hello, Bye and the constructors
%% More adds, its function, which says hello to Whom, and a binding a load
%% evaluates, which opens nothing.
greet(Whom, More) ->
    ["export type Msg = Hello | Bye", More, "\n\nexport fn hello() : String = \"hello, ", Whom,
     "\"\n\nlet started : Int = Clock.monotonic()\n"].

%% A shell attached from the node of Ops to its listed peer `node`, in line
%% mode, run in Base, its source root `src` there, relative, and its HOME a
%% directory of its own: its input's port, and what waits for its end.
sessioned(Base, Ops) ->
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    ern_harness:launched(Ops,
                         ["cd ", Base, " && HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                          " --attach node --source-root src"]).

%% Inputs typed in line mode at the shell of Ops through Port, a line each,
%% until its standard output holds Part, which the last of them prints:
%% one step.
entered(Port, Ops, Inputs, Part) ->
    true = port_command(Port, [[Input, "\n"] || Input <- Inputs]),
    ern_harness:prints(Ops, Part).

%% A shell in line mode detached, which ends it with status 0 and leaves
%% the cursor on a line of its own, and what it wrote, nothing on its
%% standard error: two steps.
detached({Port, Wait}, Ops) ->
    true = port_command(Port, ":quit\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_harness:said(Ops),
    ?assertEqual("", Err),
    ?assertMatch({true, _}, {lists:suffix("> \n", Out), Out}),
    {Out, Err}.

%% report §11.2 *The attached shell*, *What a node holds*, §12.1 *A
%% session's screen*: a detach leaves a server running. At the prompt of a
%% program's node a session declares a server's loop, `counting`, which
%% calls a function another of its inputs declares, starts the server with
%% a `let`, hands its address to the program's service `Serve.holder`, and
%% calls it, what the server prints standing on the session's screen. The
%% session detaches, and the node keeps the session's units that declare
%% the server's functions: a second session finds the server through the
%% service and calls it, and it answers from the count it kept, printing on
%% the node's standard output now and not on the second session's screen.
%%
%% A process that holds a function of a detached session's unit, and runs
%% none of its code, is attached_functions'. Written after the code, a
%% regression test
attached_service_test_() ->
    ern_harness:nodes_test({waits, 9}, fun attached_service/1).

attached_service(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "serve.ern"), serve()),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    [One, Two] = [ern_harness:made(Base, Name, none) || Name <- ["one", "two"]],
    ern_harness:lists(Node, [{"one", One, none}, {"two", Two, none}]),
    [ern_harness:lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "serve.erc"), []),
    ern_harness:prints(Node, "ready"),
    Ms = ern_harness:wait_ms_text(),
    Asked = fun(Number) ->
                ["Address.call(c, fn(reply) = Serve.Ask(number = ", Number,
                 ", =reply), ", Ms, ")"]
            end,
    {First, _} = Attached = attached(One, "node", Base),
    true = port_command(First, [[Input, "\n"]
                                || Input <- ["fn halved(n : Int) : Int = n / 2",
                                             counting(),
                                             "let c = spawn(fn() = counting(0))",
                                             "send(Serve.holder, Serve.Hold(c))",
                                             Asked("4")]]),
    {Out, _} = detached(Attached, One),
    ern_harness:has(Out, "> counted 4\nSome(2) : Optional(Int)\n"),
    {Second, _} = Again = attached(Two, "node", Base),
    true = port_command(Second, [[Input, "\n"]
                                 || Input <- [["let held <- Address.call(Serve.holder, ",
                                               "fn(reply) = Serve.Held(=reply), ", Ms,
                                               ")"],
                                              "let c <- held", Asked("6")]]),
    {SecondOut, _} = detached(Again, Two),
    ern_harness:has(SecondOut, "> c : Address(Serve.ServerMsg)\n> Some(5) : Optional(Int)\n"),
    ?assertEqual(nomatch, string:find(SecondOut, "counted")),
    ern_harness:prints(Node, "counted 10\n"),
    ern_harness:stop(Node, WaitNode),
    {NodeOut, NodeErr} = ern_harness:said(Node),
    ?assertEqual("ready\ncounted 10\n", NodeOut),
    ?assertEqual(nomatch, string:find(NodeErr, "faulted")).

%% The server's loop a session declares, one input: it adds each number
%% it is asked to its count, prints the count, and answers half of it.
counting() ->
    "fn counting(total : Int) : Unit receiving Serve.ServerMsg = receive {"
    " Serve.Ask(=number, =reply) -> {"
    " Io.println(\"counted \" <> Int.toString(total + number));"
    " answer(reply, halved(total + number)); counting(total + number) } }".

%% A node's program whose service `holder` keeps the address of a server
%% a session hands it, for a later session to find, its entry process
%% waiting.
serve() ->
    "export type ServerMsg = Ask(number : Int, reply : Reply(Int))\n"
    "\n"
    "export type HolderMsg =\n"
    "    Hold(Address(ServerMsg))\n"
    "  | Held(reply : Reply(Optional(Address(ServerMsg))))\n"
    "\n"
    "export let holder : Address(HolderMsg) = spawn(fn() = holding(None))\n"
    "\n"
    "export fn main() : Unit receiving Unit = {\n"
    "    Io.println(\"ready\");\n"
    "    receive { _ -> Unit }\n"
    "}\n"
    "\n"
    "fn holding(held : Optional(Address(ServerMsg))) : Unit receiving HolderMsg =\n"
    "    receive {\n"
    "        Hold(address) -> holding(Some(address))\n"
    "      | Held(=reply) -> {\n"
    "            answer(reply, held);\n"
    "            holding(held)\n"
    "        }\n"
    "    }\n".

%% report §11.2 *The attached shell*, *Inputs*, §6.9: a detach keeps for
%% the node's life each of the session's units that declares a function
%% or builds a function value, with the units it needs, since the host
%% cannot tell which process holds a function of one.
%%
%% At the prompt of a program's node a session declares the types `Pair`
%% and `Unused`, a type that derives `compare`, a `foreign fn`, and
%% `tripled`, whose body alone names `Pair`. It starts with a `let` a
%% process of the program's loop holding a lambda that computes `tripled`
%% on a bare peer, and with another a `restarting` service whose function
%% is a lambda; hands the function and both addresses to the program's
%% `Keep.holder`, and calls the service. It binds `let x = 1`, types
%% `x + 1`, lists the session units the node holds, and detaches.
%%
%% A second session calls each through the process that holds it: the
%% holder applies `tripled`; the process its lambda, the node shipping the
%% forms of `tripled` and of `Pair` to the peer, which held none; and the
%% service, made to fault, restarts with its function, now writing on the
%% node's standard output, and answers. Nothing on the node's standard
%% error is an `undef`.
%%
%% Of the first session's ten input units and three holders, the six
%% inputs that declare a function or build a function value stay, with
%% `Pair`'s, whose type `tripled`'s form names, and the holder of `s`,
%% which the call of the service reads; `Unused`'s, the holders of `p` and
%% `x`, the unit of `x + 1`, which holds `it`, and the input that listed
%% them are let go, as §11.2 *Inputs* lets one go. The input that hands
%% `tripled` builds no function value of its own, and went when the
%% call's answer took `it`. Written before the code
attached_functions_test_() ->
    ern_harness:nodes_test({waits, 12}, fun attached_functions/1).

attached_functions(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    [Port, PeerPort] = [ern_harness:free_port(), ern_harness:free_port()],
    Node = ern_harness:made(Base, "node", Port),
    Peer = ern_harness:made(Base, "peer", PeerPort),
    [One, Two] = [ern_harness:made(Base, Name, none) || Name <- ["one", "two"]],
    ern_harness:lists(Node, [{"one", One, none}, {"two", Two, none}, {"peer", Peer, PeerPort}]),
    [ern_harness:lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two, Peer]],
    {_, WaitPeer} = ern_harness:launched(Peer, [?ERN, " run --config-dir ", Peer]),
    ern_harness:says(Peer, "listening on "),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "keep.erc"), []),
    ern_harness:prints(Node, "ready"),
    Ms = ern_harness:wait_ms_text(),
    Asked = fun(Address, Message) ->
                ["Address.call(", Address, ", fn(reply) = Keep.", Message, "=reply), ", Ms,
                 ")"]
            end,
    {First, _} = Attached = attached(One, "node", Base),
    true = port_command(First, [[Input, "\n"]
                                || Input <- ["type Pair = Pair(left : Int, right : Int)",
                                             "type Unused = Unused",
                                             "type Ordered = Ordered(Int) derives compare",
                                             "foreign fn yielded() : Bool = \"erlang:yield/0\"",
                                             ["fn tripled(n : Int) : Int = {",
                                              " let pair = Pair(left = 3, right = n);",
                                              " pair.left * pair.right }"],
                                             ["let p = spawn(fn() = Keep.applying(fn(n) =",
                                              " match Peer.compute(\"peer\", fn() = tripled(n), ",
                                              Ms, ") { Right(v) -> v | Left(_) -> 0 }))"],
                                             ["let s = spawn(restarting(RestartLimit(restarts = 3,",
                                              " within = 60000), fn() = {",
                                              " Io.println(\"serving squares\");",
                                              " Keep.applying(fn(n) = n * n) }))"],
                                             ["send(Keep.holder, Keep.Hold(applied = tripled,",
                                              " applying = p, service = s))"],
                                             Asked("s", "Ask(number = 3, "),
                                             "let x = 1", "x + 1",
                                             "let _ = Keep.printUnits()"]]),
    {Out, _} = detached(Attached, One),
    ern_harness:has(Out, "serving squares\n"),
    ern_harness:has(Out, "> Some(9) : Optional(Int)\n"),
    ern_harness:has(Out, "> 2 : Int\n"),
    {Second, _} = Again = attached(Two, "node", Base),
    entered(Second, Two, [Asked("Keep.holder", "Apply(number = 5, "),
                          ["let #(p, s) <- ", Asked("Keep.holder", "Servers(")],
                          Asked("p", "Ask(number = 5, "), "send(s, Keep.Crash)"],
            "s : Address(Keep.Ask)\n> Some(15) : Optional(Int)\n"),
    ern_harness:prints(Node, "serving squares\n"),
    true = port_command(Second, [Asked("s", "Ask(number = 5, "), "\n",
                                 "let _ = Keep.printUnits()\n"]),
    {SecondOut, _} = detached(Again, Two),
    ern_harness:has(SecondOut, "> Some(15) : Optional(Int)\n> p : "),
    %% the service's fault is said above its answer
    ern_harness:has(SecondOut, "Some(25) : Optional(Int)\n"),
    ern_harness:stop(Node, WaitNode),
    ern_harness:stop(Peer, WaitPeer),
    {NodeOut, NodeErr} = ern_harness:said(Node),
    ?assertEqual("ready\nserving squares\n", NodeOut),
    ern_harness:has(NodeErr,
                    "the process of $Session1.input 7:1 faulted, restarted: asked to crash"),
    ?assertEqual(nomatch, string:find(NodeErr, "undef")),
    %% report §11.2: the first session's units, before its detach and after
    Before = session_units(Out),
    [Number] = lists:usort([Session || {_, Session} <- Before]),
    After = [Unit || {_, Session} = Unit <- session_units(SecondOut), Session =:= Number],
    ?assertEqual({10, 3}, kinds(Before)),
    ?assertEqual({7, 1}, kinds(After)),
    ?assertEqual([], After -- Before),
    %% the first four inputs, `Pair`'s, `Unused`'s, `Ordered`'s and the
    %% foreign function's, took the first four numbers, none having been
    %% given again
    [?assertEqual(Kept, lists:member({"ern@$input" ++ Number ++ "_" ++ Input, Number}, After))
     || {Input, Kept} <- [{"1", true}, {"2", false}, {"3", true}, {"4", true}]].

%% report §11.2 *The attached shell*, §8.7: an input is checked against the
%% interfaces of the code the node runs, as its runner loaded it at its
%% start, and not as the files on its load path hold them now: the node's
%% program is built again under it with `App.g` answering a `String` in
%% place of an `Int`, and `App.g(1)` at an attached prompt is the `Int` the
%% running code answers. Written before the fix, the first session having
%% read the rebuilt files, the value typed `String`, which faulted the
%% session as it printed it.
attached_checks_the_loaded_code_test_() ->
    ern_harness:nodes_test({waits, 7}, fun attached_checks_the_loaded_code/1).

attached_checks_the_loaded_code(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    App = filename:join(Root, "app.ern"),
    ok = file:write_file(App, ["export fn g(n : Int) : Int = n * 100\n\n",
                               "export fn main() : Unit receiving Unit = {\n",
                               "    Io.println(\"ready\");\n",
                               "    receive { _ -> Unit }\n",
                               "}\n"]),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "app.erc"), []),
    ern_harness:prints(Node, "ready"),
    ok = file:write_file(App, ["export fn g(n : Int) : String = \"a string\"\n\n",
                               "export fn main() : Unit receiving Unit = {\n",
                               "    Io.println(\"ready\");\n",
                               "    receive { _ -> Unit }\n",
                               "}\n"]),
    0 = ern_harness:built([Root]),
    {Shell, _} = Attached = attached(Ops, "node", Base),
    entered(Shell, Ops, ["App.g(1)"], "> 100 : Int\n"),
    _ = detached(Attached, Ops),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Startup and history*, §11.5: a
%% startup input's diagnostic quotes the file the shell's own node read it
%% from, its local half reading it again, and not a file of the node's: the
%% configuration directory's startup file, named from the operator's
%% working directory, `ops/startup`, its second input refused, which the
%% node, run from another directory, finds no file at. Written before the
%% fix, the diagnostic quoting no line of the file.
attached_startup_diagnostic_test_() ->
    ern_harness:nodes_test({waits, 5}, fun attached_startup_diagnostic/1).

attached_startup_diagnostic(Base) ->
    Ops = ern_harness:made(Base, "ops", none),
    Node = ern_harness:made(Base, "node", 0),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    Startup = filename:join(Ops, "startup"),
    ok = file:write_file(Startup, "let a = 1\nlet b : Int = \"not an Int\"\n"),
    %% its owner's alone to write, whatever the umask, so that it runs
    ok = file:change_mode(Startup, 8#644),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {Shell, _} = Attached = ern_harness:launched(Ops, ["cd ", Base, " && HOME=", Home, " ", ?ERN,
                                                       " shell --config-dir ops --attach node"]),
    ern_harness:prints(Ops, ":help for help.\n"),
    true = port_command(Shell, "a\n"),
    {Out, _} = detached(Attached, Ops),
    ern_harness:has(Out, "ops/startup:2:"),
    ern_harness:has(Out, "2 | let b : Int = \"not an Int\"\n"),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, §12.1 *A session's screen*, Appendix
%% E.28, E.21: a `Code.load` at an attached prompt evaluates in an
%% evaluator the session's input started, which writes to the session's
%% screen, and so does what the evaluation starts; `:processes` lists what
%% it started and not the evaluator, the runtime's own. Once the session
%% detaches they are the node's and write to the node's standard output:
%% the binding's process, subscribed to the program's end, says so as the
%% node ends. Written with the code, the evaluator's row of the screen
%% taken from the input's chain and dropped with the session's
%% (ern_rt:evaluate/3, drop_screens/1)
attached_code_load_test_() ->
    ern_harness:nodes_test({waits, 10}, fun attached_code_load/1).

attached_code_load(Base) ->
    Root = filename:join(Base, "program"),
    Lib = filename:join(Base, "lib"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Lib]],
    ok = file:write_file(filename:join(Root, "idle.ern"),
                         "export fn main() : Unit receiving Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    receive { _ -> Unit }\n"
                         "}\n"),
    ok = file:write_file(filename:join(Lib, "told.ern"),
                         "type Msg = Ending(Reply(Unit))\n"
                         "\n"
                         "let evaluated : Unit = Io.println(\"evaluated at the prompt\")\n"
                         "\n"
                         "fn told() : Unit receiving Msg = {\n"
                         "    Os.subscribeTermination(Ending);\n"
                         "    receive {\n"
                         "        Ending(reply) -> {\n"
                         "            Io.println(\"told at the end\");\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "    }\n"
                         "}\n"
                         "\n"
                         "let teller : Address(Msg) = spawn(told)\n"),
    0 = ern_harness:built([Root]),
    0 = ern_harness:built([Lib]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "idle.erc"), []),
    ern_harness:prints(Node, "ready"),
    {Shell, _} = Attached = attached(Ops, "node", Base),
    ern_harness:prints(Ops, ":help for help.\n"),
    entered(Shell, Ops, ["Code.load(Path(\"" ++ filename:join(Lib, "told.erc") ++ "\"))"],
            "Right(Unit)"),
    entered(Shell, Ops, [":processes"], "Told.teller:15 "),
    {Out, _} = detached(Attached, Ops),
    ern_harness:has(Out, "evaluated at the prompt\n"),
    ?assertEqual(2, length(string:split(Out, "Told.teller:15", all))),
    ern_harness:stop(Node, WaitNode),
    {NodeOut, _} = ern_harness:said(Node),
    ern_harness:has(NodeOut, "told at the end\n"),
    ?assertEqual(nomatch, string:find(NodeOut, "evaluated at the prompt")),
    ?assertEqual(nomatch, string:find(Out, "told at the end")).

%% report §11.2 *The attached shell*: the shell's own node reads for its
%% session the files of the source root, the startup files it ran and the
%% path `:output` names, and no other: a process of the session's node that
%% asks the local half itself, through a foreign function that finds its
%% address, is answered a file of the source root, refused one outside it,
%% refused an append anywhere but to the path `:output` took, and answered
%% one there. Written before the fix, the local half answering for any
%% path, a hardening within the trust model, a listed peer being trusted
%% whole.
attached_local_files_test_() ->
    ern_harness:nodes_test({waits, 6}, fun attached_local_files/1).

attached_local_files(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    Inside = filename:join(Source, "inside.ern"),
    ok = file:write_file(Inside, "export let x : Int = 1\n"),
    Outside = filename:join(Base, "outside.txt"),
    ok = file:write_file(Outside, "the operator's own\n"),
    Output = filename:join(Base, "output.txt"),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "keep.erc"), []),
    ern_harness:prints(Node, "ready"),
    {Shell, _} = Attached = attached(Ops, "node", Source),
    Asked = fun(Kind, Path) -> ["Keep.asked(\"", Kind, "\", \"", Path, "\")"] end,
    entered(Shell, Ops, [Asked("read", Inside), Asked("read", Outside),
                         Asked("append", Outside), ":output " ++ Output,
                         Asked("append", Output), ":output -"],
            "output goes to standard output\n"),
    {Out, _} = detached(Attached, Ops),
    ern_harness:has(Out, "> \"taken\" : String\n> \"refused\" : String\n> \"refused\" : String\n"
                         "> output goes to " ++ Output ++ "\n> \"taken\" : String\n"),
    ?assertEqual({ok, <<"the operator's own\n">>}, file:read_file(Outside)),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Loading and reloading*, §11.1: an
%% attached `:load` of a compiled form on the node's load path, which the
%% node has not loaded, loads each module the form uses that the session
%% has not loaded, its source at the operator's source root first: Greeter's
%% form uses Helper, which has a source there alone, and the load answers a
%% line for the source and one for the form. The form comes to the load
%% path after the node's start, since a node reads every module of its load
%% path at its start (§8.7).
%%
%% A regression test, written after the code and run against the code
%% before it, where it failed: Helper was looked for on the node's load path
%% alone. It does not cover a reload through a form in an attached session.
%% Nor does it cover a source that hides a library's module, reached
%% through a form: the node holds every library from its start, so the walk
%% reaches none of their modules.
attached_load_a_forms_source_test_() ->
    ern_harness:nodes_test({waits, 7}, fun attached_load_a_forms_source/1).

attached_load_a_forms_source(Base) ->
    [Built, Lib, Source] = [filename:join(Base, Leaf) || Leaf <- ["built", "lib", "src"]],
    [ok = filelib:ensure_path(Dir) || Dir <- [Built, Lib, Source]],
    Helper = "export fn name() : String = \"the operator's helper\"\n",
    ok = file:write_file(filename:join(Built, "helper.ern"), Helper),
    ok = file:write_file(filename:join(Built, "greeter.ern"),
                         "export fn greet() : String = Helper.name()\n"),
    0 = ern_harness:built([Built]),
    ok = file:write_file(filename:join(Source, "helper.ern"), Helper),
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    WaitNode = ern_harness:bare_started(Node, [Lib]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    {ok, _} = file:copy(filename:join(Built, "greeter.erc"), filename:join(Lib, "greeter.erc")),
    {Shell, _} = Attached = attached(Ops, "node", Source),
    ern_harness:prints(Ops, ":help for help.\n"),
    entered(Shell, Ops, [":load Greeter", "Greeter.greet()"], "\"the operator's helper\""),
    {Out, _} = detached(Attached, Ops),
    ern_harness:has(Out,
                    "> Helper, compiled from " ++ ern_build:shown(filename:join(Source,
                                                                                "helper.ern"))
                    ++ "\nGreeter, from " ++ ern_build:shown(filename:join(Lib, "greeter.erc"))
                    ++ "\n> \"the operator's helper\" : String\n"),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Loading and reloading*: an attached
%% `:load` of a module that uses one that fails names it in a line of its
%% own, as a plain shell's does: Top uses Dep, whose source at the
%% operator's source root fails its check. Written before the code and run
%% against the code before it, where it failed: the line said that Dep does
%% not compile. It does not cover a reload in an attached session
attached_load_names_a_user_of_a_failed_module_test_() ->
    ern_harness:nodes_test({waits, 6}, fun attached_load_names_a_user_of_a_failed_module/1).

attached_load_names_a_user_of_a_failed_module(Base) ->
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "top.ern"), "export fn g() : Int = Dep.f()\n"),
    ok = file:write_file(filename:join(Source, "dep.ern"), "export fn f() : Int = \"x\"\n"),
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    WaitNode = ern_harness:bare_started(Node, []),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    {Shell, _} = Attached = attached(Ops, "node", Source),
    ern_harness:prints(Ops, ":help for help.\n"),
    entered(Shell, Ops, [":load Top", "1"], "1 : Int"),
    {Out, _} = detached(Attached, Ops),
    ern_harness:has(Out, "expected Int, found String"),
    ern_harness:has(Out, "\nTop is not loaded, since it uses Dep, which failed\n> 1 : Int\n"),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Inputs*, §11.8: a session that ends
%% by a fault detaches as one that leaves does. At the prompt of a
%% program's node a session binds `x`, types `x + 1`, which holds `it`, and
%% lists the session units the node holds; it then ends its own screen
%% through a foreign function, which faults the session, a failure of the
%% shell's own: status 70 and the session's fault on standard error. A
%% second session lists the units again, and none of the first session's
%% is there, since none declares a function or builds a function value.
%% Written before the fix: a session that faulted failed, leaving its
%% units, its rows and its processes for the node's life.
attached_fault_detaches_test_() ->
    ern_harness:nodes_test({waits, 9}, fun attached_fault_detaches/1).

attached_fault_detaches(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    [One, Two] = [ern_harness:made(Base, Name, none) || Name <- ["one", "two"]],
    ern_harness:lists(Node, [{"one", One, none}, {"two", Two, none}]),
    [ern_harness:lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "keep.erc"), []),
    ern_harness:prints(Node, "ready"),
    {First, WaitFirst} = attached(One, "node", Base),
    entered(First, One, ["let x = 1", "x + 1", "let _ = Keep.printUnits()"], "> 2 : Int\n"),
    ern_harness:prints(One, "ern@$bindings"),
    true = port_command(First, "Keep.endScreen()\n"),
    ?assertEqual(70, WaitFirst()),
    {Out, Err} = ern_harness:said(One),
    ern_harness:has(Err, "fault: the session on the node node: the shell's screen ended"),
    Before = session_units(Out),
    [Number] = lists:usort([Session || {_, Session} <- Before]),
    {Second, _} = Again = attached(Two, "node", Base),
    true = port_command(Second, "let _ = Keep.printUnits()\n"),
    {SecondOut, _} = detached(Again, Two),
    ern_harness:stop(Node, WaitNode),
    ?assertEqual({2, 1}, kinds(Before)),
    ?assertEqual([], [Unit || {_, Session} = Unit <- session_units_or_none(SecondOut),
                              Session =:= Number]).

%% The session units a session's output lists, as session_units/1 reads
%% them, or none where it lists none.
session_units_or_none(Text) ->
    case re:run(Text, "ern@\\$(?:input|bindings)", [{capture, none}]) of
        match -> session_units(Text);
        nomatch -> []
    end.

%% The session units a session's output lists, each its Erlang name and
%% the number of its session (report §11.2, Appendix H).
session_units(Text) ->
    {match, Matched} = re:run(Text, "ern@\\$(?:input|bindings)([0-9]+)_[0-9]+\n",
                              [global, {capture, all, list}]),
    lists:usort([{string:trim(Name), Session} || [Name, Session] <- Matched]).

%% How many of Units are inputs' and how many holders'.
kinds(Units) ->
    Inputs = [Unit || {"ern@$input" ++ _, _} = Unit <- Units],
    {length(Inputs), length(Units) - length(Inputs)}.

%% A node's program whose holder keeps a function and two servers a
%% session hands it, for a later session to call through it; its loop a
%% server a session may start, which answers each number it is asked with
%% a function's value of it until it is asked to crash; the session units
%% the node holds, by their names, printed a line each; the end of the
%% calling session's screen; and a read or an append asked of its local
%% half.
keep() ->
    "export type Ask = Ask(number : Int, reply : Reply(Int)) | Crash\n"
    "\n"
    "export type HolderMsg =\n"
    "    Hold(applied : (Int) -> Int, applying : Address(Ask), service : Address(Ask))\n"
    "  | Apply(number : Int, reply : Reply(Int))\n"
    "  | Servers(reply : Reply(#(Address(Ask), Address(Ask))))\n"
    "\n"
    "export let holder : Address(HolderMsg) = spawn(fn() = holding())\n"
    "\n"
    "export fn main() : Unit receiving Unit = {\n"
    "    Io.println(\"ready\");\n"
    "    receive { _ -> Unit }\n"
    "}\n"
    "\n"
    "export fn applying(f : (Int) -> Int) : Unit receiving Ask =\n"
    "    receive {\n"
    "        Ask(=number, =reply) -> {\n"
    "            answer(reply, f(number));\n"
    "            applying(f)\n"
    "        }\n"
    "      | Crash -> fault(\"asked to crash\")\n"
    "    }\n"
    "\n"
    "export foreign fn units() : List(String) = \"ern_nodes_units:loaded/0\"\n"
    "\n"
    "export fn printUnits() : Unit = List.forEach(units(), Io.println)\n"
    "\n"
    "export foreign fn endScreen() : Unit = \"ern_nodes_units:end_screen/0\"\n"
    "\n"
    "export foreign fn asked(kind : String, path : String) : String =\n"
    "    \"ern_nodes_units:asked/2\"\n"
    "\n"
    "fn holding() : Unit receiving HolderMsg =\n"
    "    receive {\n"
    "        Hold(=applied, =applying, =service) ->\n"
    "            held(applied, #(applying, service))\n"
    "      | _ -> holding()\n"
    "    }\n"
    "\n"
    "fn held(applied : (Int) -> Int, servers : #(Address(Ask), Address(Ask))) : Unit\n"
    "    receiving HolderMsg =\n"
    "    receive {\n"
    "        Hold(applied = again, =applying, =service) ->\n"
    "            held(again, #(applying, service))\n"
    "      | Apply(=number, =reply) -> {\n"
    "            answer(reply, applied(number));\n"
    "            held(applied, servers)\n"
    "        }\n"
    "      | Servers(=reply) -> {\n"
    "            answer(reply, servers);\n"
    "            held(applied, servers)\n"
    "        }\n"
    "    }\n".

%% The host module behind `Keep.units`: the units of shell sessions the
%% node holds loaded, an input's and a holder's, their names sorted; and
%% behind `Keep.endScreen`, the calling session's screen ended outright,
%% as the front end's table holds it under the session's root; and behind
%% `Keep.asked`, a read or an append asked of the calling session's local
%% half, its address the one pid the session's row holds, the process in
%% front of it that checks what is sent (report §8.4), and whether it was
%% taken.
units_module() ->
    <<"
-module(ern_nodes_units).
-export([loaded/0, end_screen/0, asked/2]).
end_screen() ->
    [{_, Screen}] = ets:lookup(ern_shell, {ern_rt:root_of(self()), screen}),
    exit(Screen, kill),
    'Unit'.
asked(Kind, Path) ->
    [{_, Session}] = ets:lookup(ern_shell, {ern_rt:root_of(self()), session}),
    [Local] = [Pid || Pid <- tuple_to_list(Session), is_pid(Pid)],
    Request = case Kind of
                  <<\"read\">> -> fun(Reply) -> {'Read', {'Path', Path}, Reply} end;
                  <<\"append\">> -> fun(Reply) -> {'Append', {'Path', Path}, <<\"x\">>, Reply} end
              end,
    case ern_rt:call(Local, Request, 5000) of
        {'Some', {'Right', _}} -> <<\"taken\">>;
        {'Some', {'Left', _}} -> <<\"refused\">>;
        'None' -> <<\"no answer\">>
    end.
loaded() ->
    lists:sort([atom_to_binary(Module) || {Module, _} <- code:all_loaded(),
                                          is_session(atom_to_list(Module))]).
is_session(\"ern@$input\" ++ _) -> true;
is_session(\"ern@$bindings\" ++ _) -> true;
is_session(_) -> false.
">>.

%% report §11.2 *The attached shell*, *Inputs*, *Commands*, *Loading and
%% reloading*, Appendix E.23: the session golden test over an attached
%% session, as ern_shell_tests' session_test is over a plain one. The
%% inputs of fixtures/session/attached.in, typed in line mode at a shell
%% attached to a bare node, its source root fixtures/session, against
%% fixtures/session/attached.out: the start line naming `:quit`, an
%% expression, what an input prints, `:detach` no command, a qualified name
%% answered with the `:load` that puts it in scope, `:load` compiling the
%% operator's source and refusing a module loaded already, a `let`, a
%% send and a call to the process it bound, an input's fault, `Os.exit`
%% faulting the input that calls it, `:bindings`, `:processes` with each
%% process's activity, `:forget` and the name forgotten, `:browse` of the
%% module loaded, and `:quit`, which leaves the cursor on a line of its
%% own.
%%
%% The shell's own node's line of the connection stands out of the file,
%% since nothing orders it against the start line; it is held to stand
%% once, without the time its stream stamps (§11.2), and the file holds no
%% process's memory, a count that differs from run to run (E.21). A process at
%% `:processes` is spawned some inputs before, so that it waits by then.
%% Written after the code, a regression test
attached_session_test_() ->
    ern_harness:nodes_test({waits, 4}, fun attached_session/1).

attached_session(Base) ->
    Node = ern_harness:made(Base, "node", 0),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:lists(Ops, [{"node", Node, ern_harness:bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {_, Wait} = ern_harness:launched(Ops, ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                                           " --attach node --source-root fixtures/session"
                                           " < fixtures/session/attached.in"]),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_harness:said(Ops),
    ?assertEqual("", Err),
    Unstamped = unstamped(Out),
    Connected = "the peer node connected\n",
    ?assertEqual(2, length(string:split(Unstamped, Connected, all))),
    {ok, Expected} = file:read_file("fixtures/session/attached.out"),
    Listed = re:replace(string:replace(Unstamped, Connected, "", all), " [0-9]+ bytes$", "",
                        [global, multiline, {return, list}]),
    ?assertEqual(binary_to_list(Expected), lists:flatten(Listed)),
    ern_harness:stop(Node, WaitNode).

%% Report §11.2: Text without the time its lines begin with where the
%% stream is no terminal, which only a line of the runtime's has.
unstamped(Text) ->
    re:replace(Text, ?STAMP, "", [global, multiline, {return, list}]).

%% report §11.2 *The attached shell*, *Faults*, *Editing*, §11.8: an
%% attached session at a terminal, through the pseudo-terminal's harness.
%% An input typed in part waits while a process of the node's program
%% faults, once the test opens a named pipe the process reads; the fault's
%% line and trace are said above the prompt, on rows of their own, and the
%% prompt is drawn again under them with the part typed, which the rest of
%% the input finishes and runs. `:quit` ends the shell with status 0 and
%% leaves the node running, its own report of the fault on its standard
%% error. Written after the code, a regression test
attached_terminal_test_() ->
    ern_harness:nodes_test({waits, 11}, fun attached_terminal/1).

attached_terminal(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "faulter.ern"), faulter()),
    0 = ern_harness:built([Root]),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    Pipe = filename:join(Base, "fault.pipe"),
    [] = os:cmd("mkfifo " ++ Pipe),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = ern_harness:started(Node, filename:join(Root, "faulter.erc"), [Pipe]),
    ern_harness:prints(Node, "ready"),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    {0, Screen} = ern_pty:run(Shell, [{expect, ":help for help."}, {expect, "> "},
                                      {send, hex("1 + ")}, {expect, "1 + "},
                                      {put, Pipe},
                                      {expect, "faulted: division by zero"},
                                      {expect, "1 + "},
                                      {send, hex("2\r")}, {expect, "3 : Int"},
                                      {send, hex(":quit\r")}],
                              [screen]),
    Fault = "the process of Faulter.main:5 faulted: division by zero",
    ern_harness:says(Node, Fault),
    Rows = [string:trim(Row, trailing)
            || Row <- string:split(binary_to_list(Screen), "\n", all)],
    ?assertEqual([Fault], [Row || Row <- Rows, string:find(Row, "faulted") =/= nomatch]),
    [Fault | Under] = lists:dropwhile(fun(Row) -> Row =/= Fault end, Rows),
    Trace = lists:takewhile(fun(Row) -> lists:prefix("    ", Row) end, Under),
    ?assertNotEqual([], Trace),
    ?assertMatch({["> 1 + 2", "3 : Int", "> :quit" | _], _},
                 {lists:nthtail(length(Trace), Under), Rows}),
    ?assertEqual(["> 1 + 2"], [Row || Row <- Rows, lists:prefix("> 1 +", Row)]),
    ern_harness:stop(Node, WaitNode).

%% report §11.2 *The attached shell*, Appendix E.16: `Terminal.size` in a
%% session reads its node's standard output. A session at a terminal of 24
%% rows, attached to a node whose standard output is a file, answers
%% `Left(NotATerminal)`; a session in line mode, attached to the same node
%% started under a terminal of 30 rows and 100 columns, answers that size.
%% A regression test, written after the report said it (the log's *Sites,
%% Sessions and Their Names*): the code read the node's standard output
%% already
attached_terminal_size_test_() ->
    ern_harness:nodes_test({waits, 8}, fun attached_terminal_size/1).

attached_terminal_size(Base) ->
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:says(Node, "listening on "),
    {0, Screen} = ern_pty:run(Shell, [{expect, ":help for help."}, {expect, "> "},
                                      {send, hex("Terminal.size()\r")},
                                      {expect, "Io.NotATerminal"},
                                      {send, hex(":quit\r")}],
                              [screen]),
    ern_harness:has(binary_to_list(Screen),
                    "Left(Io.NotATerminal) : Either(Io.Error, Terminal.Size)"),
    ern_harness:stop(Node, WaitNode),
    Pipe = filename:join(Base, "attach.pipe"),
    [] = os:cmd("mkfifo " ++ Pipe),
    Input = filename:join(Base, "size.in"),
    Output = filename:join(Base, "size.out"),
    ok = file:write_file(Input, "Terminal.size()\n:quit\n"),
    Script = lists:flatten([?ERN, " run --config-dir ", Node, " & cat ", Pipe, " > /dev/null; ",
                            Shell, " < ", Input, " > ", Output, " 2>&1; ",
                            ?ERN, " stop --config-dir ", Node, "; wait"]),
    {0, _} = ern_pty:run(Script, [{expect, "listening on "}, {put, Pipe}], [{size, 30, 100}]),
    {ok, Answered} = file:read_file(Output),
    ern_harness:has(binary_to_list(Answered), "Right(Terminal.Size(rows = 30, columns = 100))"
                                              " : Either(Io.Error, Terminal.Size)").

%% report §11.2 *The attached shell*, *Loading and reloading*: in a shell
%% attached at a terminal, the interrupt kills the evaluator of a running
%% `:load`, on the node, as in a plain shell: the load answers with the
%% binding's site and `was killed`, and the session goes on, one prompt
%% after the answer. The binding says when it waits, and the interrupt is
%% sent then. Written with the code: before it the load held the session
%% for ever
attached_load_interrupted_test_() ->
    ern_harness:nodes_test({waits, 8}, fun attached_load_interrupted/1).

attached_load_interrupted(Base) ->
    ok = file:write_file(filename:join(Base, "hang.ern"),
                         "export let waited : Unit = {\n"
                         "    Io.println(\"waiting\");\n"
                         "    Clock.sleep(3600000)\n"
                         "}\n"),
    Port = ern_harness:free_port(),
    Node = ern_harness:made(Base, "node", Port),
    Ops = ern_harness:made(Base, "ops", none),
    ern_harness:lists(Node, [{"ops", Ops, none}]),
    ern_harness:lists(Ops, [{"node", Node, Port}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    {_, WaitNode} = ern_harness:launched(Node, [?ERN, " run --config-dir ", Node]),
    ern_harness:says(Node, "listening on "),
    Killed = "Hang.waited:1 was killed; nothing was loaded",
    {0, Screen} = ern_pty:run(Shell, [{expect, ":help for help."}, {expect, "> "},
                                      {send, hex(":load Hang\r")}, {expect, "waiting"},
                                      {send, "03"}, {expect, Killed},
                                      {send, hex("1 + 1\r")}, {expect, "2 : Int"},
                                      {send, hex(":quit\r")}],
                              [screen]),
    Rows = [string:trim(Row, trailing)
            || Row <- string:split(binary_to_list(Screen), "\n", all)],
    ?assertMatch({["> :load Hang", "waiting", Killed, "> 1 + 1", "2 : Int" | _], _},
                 {lists:dropwhile(fun(Row) -> Row =/= "> :load Hang" end, Rows), Rows}),
    ern_harness:stop(Node, WaitNode).

%% A node's program whose worker faults once the named pipe it is given
%% has been opened and closed, each run of `cat` waiting the harness's time
%% for one step, while its entry process waits.
faulter() ->
    ["export fn main() : Unit receiving Unit =\n"
     "    match Os.arguments {\n"
     "        [pipe] -> {\n"
     "            Io.println(\"ready\");\n"
     "            let _ = spawn(fn() = divided(pipe));\n"
     "            receive { _ -> Unit }\n"
     "        }\n"
     "      | _ -> Unit\n"
     "    }\n"
     "\n"
     "fn divided(pipe : String) : Unit = {\n"
     "    let _ = Os.run(Os.command(\"cat\", [pipe]), waitMs());\n"
     "    Io.println(Int.toString(1 / (List.size(Os.arguments) - 1)))\n"
     "}\n",
     ern_harness:wait_ms_declaration()].

%% A shell attached from the node of Ops to its listed peer Name, in line
%% mode, its source root SourceRoot and its HOME a directory of its own, so
%% that no person's startup file runs.
attached(Ops, Name, SourceRoot) ->
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    ern_harness:launched(Ops,
                         ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops, " --attach ", Name,
                          " --source-root ", SourceRoot]).

%% report §8.7, §11.2, §12.5, §11.8: a bare node whose `ernest.conf` has no
%% `listen` is refused at its start, as the launcher's second start says
%% it, and writes no ernest.pid; and one whose carrier cannot start, its
%% port taken, ends as a job that cannot start, its line naming the listen
%% address in use, with status 1. Written after the code, the address with
%% the line that names it, and the job's line form with the log's *The
%% Shell's Own Node*
bare_node_refused_test_() ->
    ern_harness:nodes_test({waits, 2}, fun bare_node_refused/1).

bare_node_refused(Base) ->
    C = ern_harness:made(Base, "c", none),
    {1, Refused} = finished(?ERN ++ " run --config-dir " ++ C ++ " 2>&1"),
    ?assert(lists:suffix("ern run: a bare node listens: " ++ filename:join(C, "ernest.conf")
                         ++ " has no listen\n", Refused)),
    ?assertNot(filelib:is_file(filename:join(C, "ernest.pid"))),
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    D = ern_harness:made(Base, "d", Port),
    {1, Taken} = finished(?ERN ++ " run --config-dir " ++ D ++ " 2>&1"),
    ok = gen_tcp:close(Held),
    ern_harness:has(Taken,
                    "ern run: the node's carrier did not start: its listen address 127.0.0.1:"
                    ++ integer_to_list(Port) ++ " is in use\n"),
    ?assertEqual(nomatch, string:find(Taken, "faulted")),
    ?assertNot(filelib:is_file(filename:join(D, "ernest.pid"))).

%% report §11.3, §8.7: two directories made and listed by `ern config`'s
%% `--listen` and `--peer-dir` alone, as the language guide's §8.1 makes them,
%% one listening on every interface and one on the loopback, connect both
%% ways: a bare node from either takes the other's spawn by the name
%% `--peer-dir` gave it, and its process sends back what it computed. Its
%% limit is the sum of its fifteen waits, each bounded by the harness's
%% time for one wait: four jobs and a build, two nodes that say they
%% listen, two runs, what they printed and the line of the node each dialed, and two
%% nodes' ends
peer_option_test_() ->
    ern_harness:nodes_test({waits, 15}, fun peer_option/1).

peer_option(Base) ->
    Program = spawner(filename:join(Base, "program")),
    {PortA, PortFoo} = {ern_harness:free_port(), ern_harness:free_port()},
    [A, Foo] = [filename:join(Base, Name) || Name <- ["a", "foo"]],
    Listen = fun(Port, Host) -> Host ++ ":" ++ integer_to_list(Port) end,
    [?assertMatch({0, _}, finished([?ERN, " config --config-dir ", Words]))
     || Words <- [[A, " --listen ", Listen(PortA, "0.0.0.0")],
                  [Foo, " --listen ", Listen(PortFoo, "127.0.0.1")],
                  [A, " --peer-dir ", Foo], [Foo, " --peer-dir ", A]]],
    lists:foreach(fun({Node, Address, Dialer}) ->
                      Wait = ern_harness:bare_started(Node, []),
                      ern_harness:says(Node, "listening on " ++ Address ++ "\n"),
                      Name = filename:basename(Node),
                      {_, Ran} = ern_harness:launched(Dialer,
                                                      [?ERN, " run --config-dir ", Dialer, " ",
                                                       Program, " ", Name]),
                      ?assertEqual(0, Ran()),
                      {Out, _} = ern_harness:said(Dialer),
                      ern_harness:has(Out, Name ++ " computed 42"),
                      ern_harness:says(Node,
                                       "the peer " ++ filename:basename(Dialer) ++ " connected"),
                      ern_harness:stop(Node, Wait)
                  end, [{Foo, Listen(PortFoo, "127.0.0.1"), A},
                        {A, Listen(PortA, "0.0.0.0"), Foo}]).

%% The program peer_option/1 runs, built in Root: a spawn on the peer its
%% argument names, whose process sends back what it computed.
spawner(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "spawner.ern"), [<<"
type Msg = Computed(Int)

export fn main() : Unit receiving Msg =
    match Os.arguments {
        [name] -> {
            let me = self();
            match Peer.spawn(name, fn() = send(me, Computed(6 * 7)), waitMs()) {
                Right(_) ->
                    receive {
                        Computed(value) -> Io.println(name <> \" computed \" <> Int.toString(value))
                    }
              | Left(failure) ->
                    Io.println(\"no \" <> name <> \": \" <> Io.show(failure))
            }
        }
      | _ ->
            Unit
    }
">>, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    filename:join(Root, "spawner.erc").

%% report §11.2, §8.7: `ern run --verbose` of a node names each module the
%% program reads, and then each other module of its load path, which a
%% node's start reads, the toolchain's libraries last, on standard error,
%% each once, and standard output holds the program's alone, from a
%% directory whose name is beyond Latin-1. It names no unit of the shell's,
%% which the node's start reads too, as it names none of the standard
%% library's, since the lines are held to those modules alone. A
%% regression test: the launcher's first start, which writes what the job
%% says to nothing, raised at such a line, and the node was given no flags
verbose_node_start_test_() ->
    ern_harness:nodes_test({waits, 2}, fun verbose_node_start/1).

verbose_node_start(Base) ->
    E = ern_harness:made(Base, "e", none),
    Root = filename:join(Base, "r\x{2022}ot"),
    ok = filelib:ensure_path(filename:join(Root, "shelf")),
    [ok = file:write_file(filename:join(Root, File), Source)
     || {File, Source} <- [{"main.ern", "export fn main() : Unit = Io.println(Store.label)\n"},
                           {"store.ern", "export let label : String = \"ran\"\n"},
                           {"shelf/box.ern", "export fn size() : Int = 3\n"}]],
    0 = ern_harness:built([Root]),
    Main = filename:join(Root, "main.erc"),
    Err = E ++ ".err",
    ?assertEqual({0, "ran\n"},
                 finished([?ERN, " run --verbose --config-dir ", E, " ", Main, " 2> ", Err])),
    {ok, Said} = file:read_file(Err),
    Program = unicode:characters_to_binary(
                ["read Main from ", Main, "\nread Store from ", Root, "/store.erc\n"
                 "read Shelf.Box from ", Root, "/shelf/box.erc\n"]),
    Size = byte_size(Program),
    <<Program:Size/binary, Read/binary>> = Said,
    %% report §11.2: once the end has ended the program's processes, how
    %% many, none here
    Ended = <<"the end ended 0 processes\n">>,
    EndedSize = byte_size(Ended),
    LibrariesSize = byte_size(Read) - EndedSize,
    <<Libraries:LibrariesSize/binary, Ended:EndedSize/binary>> = Read,
    %% Every library's compiled module is read, each once; a library a
    %% module needs, Time under Http, is read as it is needed, so the lines'
    %% order is the need's and not the directories', and the sets are held.
    ?assertEqual(lists:sort([unicode:characters_to_binary(ern_build:shown(File))
                             || Library <- ern_tree:libraries(),
                                File <- ern_build:compiled_under(Library)]),
                 lists:sort([lists:last(string:split(Line, " from "))
                             || Line <- string:split(Libraries, "\n", all), Line =/= <<>>])).

%% report §11.9, §11.2, §8.7: a node started in a root package finds a
%% named package's namespace under that package's build alone, the
%% program's and its start's reads alike: a module at it under the loaded
%% module's root is passed over, and so is a module at another namespace in
%% the package's build, which provides none
package_node_start_test_() ->
    ern_harness:nodes_test({waits, 5}, fun package_node_start/1).

package_node_start(Base) ->
    E = ern_harness:made(Base, "e", none),
    [Pkg, Root, Elsewhere] = [filename:join(Base, Leaf) || Leaf <- ["pkg", "root", "elsewhere"]],
    Package = filename:join(Pkg, "lib/ns_leaf"),
    [Src, Build] = [filename:join(Package, Sub) || Sub <- ["src", "build"]],
    Write = fun(Dir, File, Source) ->
                Path = filename:join(Dir, File),
                ok = filelib:ensure_dir(Path),
                ok = file:write_file(Path, Source),
                Path
            end,
    Write(Src, "ns_leaf.ern", "export let word : String = \"package\"\n"),
    0 = ern_harness:built(["--source-root", Src, "--build-root", Build, Src]),
    Write(Pkg, "package.conf",
          "{\"ernest\": \"0.11.0\",\n"
          " \"packages\": [{\"name\": \"ns_leaf\", \"version\": \"1.0.0\"}]}\n"),
    Other = Write(Elsewhere, "ns_other.ern", "export let word : String = \"other\"\n"),
    Decoy = Write(Elsewhere, "ns_leaf.ern", "export let word : String = \"decoy\"\n"),
    [0 = ern_harness:built(["--source-root", Elsewhere, File]) || File <- [Other, Decoy]],
    {ok, _} = file:copy(filename:join(Elsewhere, "ns_other.erc"),
                        filename:join(Build, "ns_other.erc")),
    Main = Write(Root, "main.ern", "export fn main() : Unit = Io.println(NsLeaf.word)\n"),
    0 = ern_harness:built(["--source-root", Root, "--load-path", Build, Main]),
    {ok, _} = file:copy(filename:join(Elsewhere, "ns_leaf.erc"),
                        filename:join(Root, "ns_leaf.erc")),
    Err = E ++ ".err",
    ?assertEqual({0, "package\n"},
                 finished([?ERN, " run --verbose --config-dir ", E, " --package-dir ", Pkg, " ",
                           filename:join(Root, "main.erc"), " 2> ", Err])),
    {ok, Said} = file:read_file(Err),
    Read = unicode:characters_to_binary(["read NsLeaf from ", Build, "/ns_leaf.erc\n"]),
    ?assertMatch({_, _}, binary:match(Said, Read)),
    ?assertEqual(nomatch, binary:match(Said, <<"NsOther">>)),
    ?assertEqual(nomatch, binary:match(Said, unicode:characters_to_binary(
                                               ["NsLeaf from ", Root]))).

%% report §8.7, §12.7, §8.4, Appendix E.27: a lambda crosses as the definition
%% that encloses it, and what that definition names beyond the lambda's
%% reach and the bare node lacks is linked there to a fault that names it:
%% a lambda written beside a program binding and a foreign function over a
%% module the bare node has, and one beside a foreign function over a
%% module it lacks, each spawns there and runs; and a spawn of either
%% enclosing definition, which the node then holds, is NotLoaded, the node
%% naming the binding and the module, the second by the declaration the
%% unit recorded as the code arrived.
%%
%% A regression test, written with the fix: each such lambda's spawn
%% answered `Other`, the binding refused and the foreign function
%% undeclared, and then the held definition's line naming the foreign
%% function and not its module. The test does not cover a module that is
%% here without the function, which ern_exchange_tests'
%% not_loaded_from_reach_test covers before code crosses
beyond_reach_test_() ->
    ern_harness:nodes_test({waits, 10}, fun beyond_reach/1).

beyond_reach(Base) ->
    Root = filename:join(Base, "probe"),
    ok = filelib:ensure_path(Root),
    Source = "// Report §12.7: lambdas spawned on a bare node from definitions that name\n"
             "// what the bare node lacks and the lambdas do not.\n"
             "\n"
             %% computed, since a constant has its value wherever its code is (§11.1)
             "let config : Int = 2 + 3\n"
             "\n"
             "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
             "\n"
             "foreign fn only() : Unit = \"ern_probe_host:only/0\"\n"
             "\n"
             "export fn main() : Unit = {\n"
             "    valued();\n"
             "    Io.println(\"valued itself: \" <> outcome(Peer.spawn(\"b\", valued,"
             " waitMs())));\n"
             "    beside();\n"
             "    Io.println(\"beside itself: \" <> outcome(Peer.spawn(\"b\", beside, waitMs())))\n"
             "}\n"
             "\n"
             "// A lambda that uses neither the binding nor the foreign function\n"
             "// its definition names.\n"
             "fn valued() : Unit = {\n"
             "    Io.println(\"config: \" <> Int.toString(config + parsed(\"1\")));\n"
             "    let lambda = fn() = Io.println(\"the lambda ran\");\n"
             "    Io.println(\"valued: \" <> outcome(Peer.spawn(\"b\", lambda, waitMs())))\n"
             "}\n"
             "\n"
             "// A lambda beside a foreign function whose module the bare node lacks.\n"
             "fn beside() : Unit = {\n"
             "    only();\n"
             "    let lambda = fn() = Io.println(\"the other lambda ran\");\n"
             "    Io.println(\"beside: \" <> outcome(Peer.spawn(\"b\", lambda, waitMs())))\n"
             "}\n"
             "\n"
             "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
             "    match spawned {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n",
    ok = file:write_file(filename:join(Root, "probe.ern"),
                         unicode:characters_to_binary([Source, ern_harness:wait_ms_declaration()])),
    Host = filename:join(Root, "ern_probe_host.erl"),
    ok = file:write_file(Host, <<"-module(ern_probe_host).\n-export([only/0]).\n"
                                 "only() -> 'Unit'.\n">>),
    {ok, _} = compile:file(Host, [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    WaitB = ern_harness:bare_started(B, []),
    ern_harness:lists(A, [{"b", B, ern_harness:bound_port(B)}]),
    ?assertEqual(0, (ern_harness:start(A, filename:join(Root, "probe.erc"), []))()),
    [ern_harness:prints(B, Line) || Line <- ["the lambda ran", "the other lambda ran"]],
    Site = fun(Part) -> "Probe.main:" ++ integer_to_list(line_of(Source, Part)) end,
    [ern_harness:says(B, Line)
     || Line <- ["the peer a's spawn at " ++ Site("\"valued itself: \"") ++ " was not loaded:"
                 " the binding Probe.config has no value here",
                 "the peer a's spawn at " ++ Site("\"beside itself: \"") ++ " was not loaded:"
                 " the module ern_probe_host, which Probe.only calls, is not here"]],
    ern_harness:stop(B, WaitB),
    {Out, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    [ern_harness:has(Out, Line)
     || Line <- ["config: 6", "valued: Right", "valued itself: Io.NotLoaded", "beside: Right",
                 "beside itself: Io.NotLoaded"]],
    [?assertEqual(nomatch, string:find(ErrB, Part))
     || Part <- ["could not take", "this node does not have"]].

%% report §12.7, §11.2, §8.4: a node ships onward as its own what it
%% received, a definition linked to a fault for a foreign function it
%% lacks among it: a lambda spawned on the bare node b, which lacks the
%% module of a foreign function its enclosing definition reaches, spawns
%% two lambdas of that definition on the bare nodes c1, which has the
%% module, and c2, which lacks it, and each runs there, the definition and
%% its references crossing from b in code frames b makes of what it holds,
%% the declaration from what b recorded as the code arrived.
%%
%% Then a spawn from a of the function that calls the foreign function,
%% which each node holds by then, runs on c1, through the function c1 made
%% of b's declaration, and is NotLoaded on b and on c2, each naming the
%% module. A regression test, written with the fix; it does not cover a
%% group relayed whole, nor a node asked for the reach of a lacked foreign
%% function spawned by its name, which it answers none as it holds nothing
%% it could run
relay_test_() ->
    ern_harness:nodes_test({waits, 17}, fun relay/1).

relay(Base) ->
    Root = filename:join(Base, "relay"),
    HostDir = filename:join(Base, "relayhost"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, HostDir]],
    Source = "// Report §12.7: code relayed from a bare node to two more.\n"
             "\n"
             "type Note = Relayed\n"
             "\n"
             "foreign fn only() : Unit = \"ern_relay_host:only/0\"\n"
             "\n"
             "export fn main() : Unit receiving Note = {\n"
             "    let told = self();\n"
             "    let relay = fn() = {\n"
             "        let first = fn() = Io.println(\"relayed to c1\");\n"
             "        Io.println(\"c1: \" <> outcome(Peer.spawn(\"c1\", first, waitMs())));\n"
             "        let second = fn() = Io.println(\"relayed to c2\");\n"
             "        Io.println(\"c2: \" <> outcome(Peer.spawn(\"c2\", second, waitMs())));\n"
             "        send(told, Relayed)\n"
             "    };\n"
             "    match Peer.spawn(\"b\", relay, waitMs()) {\n"
             "        Right(_) -> receive {\n"
             "            Relayed -> Io.println(\"b: Right\")\n"
             "        }\n"
             "      | Left(failure) -> Io.println(\"b: \" <> Io.show(failure))\n"
             "    };\n"
             "    Io.println(\"held on b: \" <> outcome(Peer.spawn(\"b\", usesOnly, waitMs())));\n"
             "    Io.println(\"held on c1: \" <> outcome(Peer.spawn(\"c1\", usesOnly,"
             " waitMs())));\n"
             "    Io.println(\"held on c2: \" <> outcome(Peer.spawn(\"c2\", usesOnly, waitMs())))\n"
             "}\n"
             "\n"
             "// A function that calls a foreign function whose module a and c1 hold.\n"
             "fn usesOnly() : Unit = {\n"
             "    only();\n"
             "    Io.println(\"only ran\")\n"
             "}\n"
             "\n"
             "fn outcome(spawned : Either(Io.Error, Address(m))) : String =\n"
             "    match spawned {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n",
    ok = file:write_file(filename:join(Root, "relay.ern"),
                         unicode:characters_to_binary([Source, ern_harness:wait_ms_declaration()])),
    Host = filename:join(HostDir, "ern_relay_host.erl"),
    ok = file:write_file(Host, <<"-module(ern_relay_host).\n-export([only/0]).\n"
                                 "only() -> 'Unit'.\n">>),
    {ok, _} = compile:file(Host, [{outdir, HostDir}]),
    0 = ern_harness:built([Root]),
    A = ern_harness:made(Base, "a", none),
    [B, C1, C2] = [ern_harness:made(Base, Name, 0) || Name <- ["b", "c1", "c2"]],
    [ern_harness:lists(C, [{"a", A, none}, {"b", B, none}]) || C <- [C1, C2]],
    {WaitC1, WaitC2} = {ern_harness:bare_started(C1, [HostDir]), ern_harness:bare_started(C2, [])},
    {PortC1, PortC2} = {ern_harness:bound_port(C1), ern_harness:bound_port(C2)},
    ern_harness:lists(B, [{"a", A, none}, {"c1", C1, PortC1}, {"c2", C2, PortC2}]),
    WaitB = ern_harness:bare_started(B, []),
    ern_harness:lists(A,
                      [{"b", B, ern_harness:bound_port(B)}, {"c1", C1, PortC1},
                       {"c2", C2, PortC2}]),
    {_, WaitA} = ern_harness:launched(A,
                                      [?ERN, " run --config-dir ", A, " --load-path ", HostDir, " ",
                                       filename:join(Root, "relay.erc")]),
    ?assertEqual(0, WaitA()),
    [ern_harness:prints(C, Line) || {C, Line} <- [{C1, "relayed to c1"}, {C2, "relayed to c2"},
                                                  {C1, "only ran"}]],
    Lacked = fun(Part) ->
                 "the peer a's spawn at Relay.main:" ++ integer_to_list(line_of(Source, Part))
                     ++ " was not loaded: the module ern_relay_host, which Relay.only calls, is"
                        " not here"
             end,
    ern_harness:says(B, Lacked("\"held on b: \"")),
    ern_harness:says(C2, Lacked("\"held on c2: \"")),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{B, WaitB}, {C1, WaitC1}, {C2, WaitC2}]],
    {Out, _} = ern_harness:said(A),
    {OutB, ErrB} = ern_harness:said(B),
    [{_, ErrC1}, {_, ErrC2}] = [ern_harness:said(C) || C <- [C1, C2]],
    [ern_harness:has(Out, Line)
     || Line <- ["b: Right", "held on b: Io.NotLoaded", "held on c1: Right",
                 "held on c2: Io.NotLoaded"]],
    [ern_harness:has(OutB, Line) || Line <- ["c1: Right", "c2: Right"]],
    [?assertEqual(nomatch, string:find(Err, Part))
     || Err <- [ErrB, ErrC1, ErrC2], Part <- ["could not take", "this node does not have",
                                               "no longer holds"]].

%% report §8.7, §11.2, §6.10, §10: a fix from a shell that is a node over
%% the old build. The shell loads the module with its leaf changed, and
%% spawns on a node of the old build the last of the leaf's callers: the
%% spawn crosses the leaf and the callers whose hashes changed with it,
%% which the node compiles into one unit of its own, and nothing the node
%% holds. The fixed leaf raises there, and its fault's trace shows each
%% changed definition's frame by its name and the sender's line, the
%% lambda's by its definition's, and the frame of the function no fix
%% changed, which the node held, by its build's line (Appendix E.21,
%% §11.2). A regression test, written after the code; which definitions
%% cross exactly is ern_exchange_tests' received_whole_test's, and the
%% costs of a fix's callers ern_code_costs' (make bench)
fix_from_shell_test_() ->
    ern_harness:nodes_test({waits, 8}, fun fix_from_shell/1).

fix_from_shell(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    Fix = fun(Leaf) ->
              ["// Report §8.7, §6.10: a leaf, its callers, and what no fix changes.\n"
               "\n"
               "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
               "\n",
               Leaf,
               "\n"
               "fn middle(x : Int) : Int = aside(fn() = leaf(x)) + 1\n"
               "\n"
               "export fn top() : Unit = Io.println(Int.toString(middle(1)))\n"
               "\n"
               "// What no fix changes, beneath whose frame the fix runs.\n"
               "export fn aside(f : () -> Int) : Int = f() + 0\n"
               "\n"
               "// The old build's node, which waits for what is spawned on it.\n"
               "export fn main() : Unit receiving Unit = {\n"
               "    Io.println(\"serving\");\n"
               "    held()\n"
               "}\n"
               "\n"
               "fn held() : Unit receiving Unit = receive { _ -> held() }\n"]
          end,
    ok = file:write_file(filename:join(Root, "fix.ern"),
                         unicode:characters_to_binary(Fix("fn leaf(x : Int) : Int = x * 2\n"))),
    ok = file:write_file(filename:join(Source, "fix.ern"),
                         unicode:characters_to_binary(
                           Fix("// The fix, which raises, so that its trace shows each frame.\n"
                               "fn leaf(x : Int) : Int = parsed(\"fixed\") + x\n"))),
    0 = ern_harness:built([Root]),
    PortB = ern_harness:free_port(),
    B = ern_harness:made(Base, "b", PortB),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(B, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"b", B, PortB}]),
    WaitB = ern_harness:start(B, filename:join(Root, "fix.erc"), []),
    ern_harness:prints(B, "serving"),
    {DeskInput, WaitDesk} = ern_harness:shell_started(Desk, Source, [Root]),
    true = port_command(DeskInput, ":load Fix\n"),
    ern_harness:prints(Desk,
                       "Fix, compiled from " ++ ern_build:shown(filename:join(Source, "fix.ern"))),
    true = port_command(DeskInput,
                        ["Peer.spawn(\"b\", Fix.top, ", ern_harness:wait_ms_text(), ")\n"]),
    ern_harness:prints(Desk, ?SPAWNED),
    ern_harness:says(B, " faulted: foreign function erlang:binary_to_integer/1 raised error:badarg,"
                        " spawned by the peer desk"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(B, WaitB),
    {_, ErrB} = ern_harness:said(B),
    %% the fix's file has a line more above its leaf than the build's
    [ern_harness:has(ErrB, Frame) || Frame <- ["\n    Fix.leaf:6\n", "\n    Fix.middle:8\n",
                                               "\n    Fix.aside:12\n"]],
    [?assertEqual(nomatch, string:find(ErrB, Part))
     || Part <- ["Fix.aside:13", "ern$", "was not loaded", "could not take"]].

%% Two builds of a program, the second of which the test's own spawner
%% plays through a bare `erl`: a function that waits for a number and then
%% raises, and a definition beside it whose code frame the spawner sends;
%% answers the program's `.erc` and source.
lost_build(Root) ->
    ok = filelib:ensure_path(Root),
    Source = "// Report §12.7: a function spawned onto a bare node, the first time with a\n"
             "// time its exchange outlasts.\n"
             "\n"
             "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
             "\n"
             "export fn main() : Unit =\n"
             "    match Os.arguments {\n"
             "        [bare] -> late(bare)\n"
             "      | _ -> Unit\n"
             "    }\n"
             "\n"
             "fn late(bare : String) : Unit = {\n"
             "    Io.println(\"dialed: \" <> outcome(Peer.utilization(bare, waitMs())));\n"
             "    Io.println(\"late: \" <> outcome(Peer.spawn(bare, waits, 1)));\n"
             "    // until the test, which has seen the bare node drop the exchange, says so\n"
             "    let _ = Io.readLine();\n"
             "    let again = Peer.spawn(bare, waits, waitMs());\n"
             "    Io.println(\"again: \" <> outcome(again));\n"
             "    match again {\n"
             "        Right(address) -> send(address, 1)\n"
             "      | Left(_) -> Unit\n"
             "    }\n"
             "}\n"
             "\n"
             "// A process that raises once it is sent a number.\n"
             "fn waits() : Unit receiving Int = receive {\n"
             "    n -> Io.println(Int.toString(parsed(\"x\") + n))\n"
             "}\n"
             "\n"
             "// The definition whose code frame the test's spawner sends.\n"
             "fn other(x : Int) : Int = x + 1\n"
             "\n"
             "fn outcome(answer : Either(Io.Error, a)) : String =\n"
             "    match answer {\n"
             "        Right(_) -> \"Right\"\n"
             "      | Left(failure) -> Io.show(failure)\n"
             "    }\n",
    ok = file:write_file(filename:join(Root, "lost.ern"),
                         unicode:characters_to_binary([Source, ern_harness:wait_ms_declaration()])),
    ok = file:write_file(filename:join(Root, "ern_harness_client.erl"), ern_harness:client()),
    ok = file:write_file(filename:join(Root, "ern_nodes_spawner.erl"), spawner()),
    [{ok, _} = compile:file(filename:join(Root, File), [{outdir, Root}])
     || File <- ["ern_harness_client.erl", "ern_nodes_spawner.erl"]],
    0 = ern_harness:built([Root]),
    {filename:join(Root, "lost.erc"), Source}.

%% A spawner of the test's own, run in a bare `erl` that holds a peer's key,
%% which plays the spawner's node's part of the exchange as a script: it
%% spawns on the node its command line names the function whose hash it
%% is given, answers the request for its reach with that hash and the
%% other's, and sends the other's code frame, read from the file it is
%% given, or a frame its bytes do not match; its gateway is its own
%% process, which the node sends its frames to (report §12.6), and each of
%% its spawns waits the milliseconds its command line gives, the harness's
%% time for one wait. Each step it sees, a line.
spawner() ->
    <<"
-module(ern_nodes_spawner).
-export([main/0]).
main() ->
    Node = list_to_atom(argument(ern_harness_target)),
    Hash = binary:decode_hex(list_to_binary(argument(ern_nodes_hash))),
    {Other, Bytes, Sources} = binary_to_term(read(argument(ern_nodes_frame))),
    Frame = fun(Exchange, Of) -> {code_frame, Exchange, [Other], Of, Sources} end,
    true = register(ern_gateway, self()),
    connected(Node),
    %% the reach answered as one this node no longer holds: the spawn is
    %% answered Other, and a code frame of the exchange that ended is
    %% dropped, the connection kept
    First = spawned(Node, Hash),
    Ended = requested(),
    sent(Node, {reach, Ended, none}),
    io:format(\"no longer held: ~s~n\", [answered(First)]),
    sent(Node, Frame(Ended, Bytes)),
    %% a code frame whose bytes are not its hash's ends the connection
    _ = spawned(Node, Hash),
    Faulty = requested(),
    io:format(\"late frame: the connection lives~n\"),
    sent(Node, {reach, Faulty, [Hash, Other], [], []}),
    Lacks = lacks(Faulty),
    io:format(\"lacks: ~B~n\", [length(Lacks)]),
    sent(Node, Frame(Faulty, <<Bytes/binary, 0>>)),
    receive {nodedown, Node} -> io:format(\"faulty: ended~n\") end,
    %% a code frame verified and held apart, read by the node before this
    %% node asks it a reach of its own, and the connection then closed
    connected(Node),
    _ = spawned(Node, Hash),
    Broken = requested(),
    sent(Node, {reach, Broken, [Hash, Other], [], []}),
    Lacks = lacks(Broken),
    sent(Node, Frame(Broken, Bytes)),
    caught_up(Node),
    true = erlang:disconnect_node(Node),
    receive {nodedown, Node} -> io:format(\"broken: closed~n\") end,
    %% a new exchange lacks both again
    connected(Node),
    _ = spawned(Node, Hash),
    Again = requested(),
    sent(Node, {reach, Again, [Hash, Other], [], []}),
    io:format(\"lacked again: ~p~n\", [lacks(Again) =:= Lacks]),
    halt().
argument(Name) ->
    {ok, [[Value]]} = init:get_argument(Name),
    Value.
read(File) ->
    {ok, Bytes} = file:read_file(File),
    Bytes.
connected(Node) ->
    true = net_kernel:connect_node(Node),
    true = erlang:monitor_node(Node, true).
sent(Node, Body) ->
    erlang:send({ern_gateway, Node}, {ern_frame, self(), Body}).
spawned(Node, Hash) ->
    Ref = make_ref(),
    sent(Node, {spawn, Ref, {function, Hash}, <<\"Lost.z:1\">>, false,
                list_to_integer(argument(ern_harness_ms))}),
    Ref.
requested() ->
    receive {ern_frame, _, {reach_request, Exchange, _}} -> Exchange end.
lacks(Exchange) ->
    receive {ern_frame, _, {lacks, Exchange, Hashes}} -> Hashes end.
answered(Ref) ->
    receive {ern_frame, _, {answer, Ref, {failed, {'Other', _}}}} -> \"Other\" end.
caught_up(Node) ->
    Ref = make_ref(),
    sent(Node, {reach_request, Ref, {function, <<0:256>>}}),
    receive {ern_frame, _, {reach, Ref, none}} -> ok end.
">>.

%% report §12.7: the exchange on a bare node, with a spawner of the test's
%% own that plays the spawner's node's part. A reach answered as one the
%% spawner's node no longer holds answers the spawn `Other`, which the node
%% says, and a code frame of that exchange, which has ended, is dropped,
%% the connection kept. A code frame whose bytes are not the hash it names
%% is faulty, and the node ends the connection, saying so. A code frame
%% verified and held apart enters nothing, so that, its connection closed
%% before the reach was whole, a new exchange lacks it again, as it lacked
%% it before.
%%
%% Then a peer of the program's, whose first spawn gives up before its
%% exchange ends, its time a millisecond, less than the exchange's two
%% round trips take, which the node then drops at that time, saying so,
%% spawns the function again once the test has seen the drop, and it runs,
%% its fault's trace naming its frame by its name and the sender's line
%% (Appendix E.21): the exchanges that broke or ran out of time made
%% nothing that runs, and the next made it whole. A second spawn that came
%% before the drop would join the first's exchange and lengthen its time
%% (report §12.7), so that neither spawn was late.
%%
%% A regression test, written after the code, and again after the flake
%% the join made (the log's *The Flake of `broken_exchange_test_`*); that
%% the node made one unit, which a trace once named and names no more, is
%% not observed, the exchange's state after a loss is ern_exchange_tests'
%% loss_test's, and a first spawn whose exchange ends within its time after
%% its spawner gave up, its process killed as its answer comes, is not
%% observed
broken_exchange_test_() ->
    ern_harness:nodes_test({waits, 10}, fun broken_exchange/1).

broken_exchange(Base) ->
    Root = filename:join(Base, "build"),
    {Program, Source} = lost_build(Root),
    {ok, Beam} = file:read_file(Program),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    Defined = fun(Name) -> hd([Definition || #definition{qualified_name = ['Lost', Named]}
                                                 = Definition <- Definitions, Named =:= Name])
              end,
    #definition{hash = Waits} = Defined(waits),
    #definition{qualified_name = OtherName, hash = Other, form = Form, sourced = Sourced} =
        Defined(other),
    Frame = filename:join(Base, "frame"),
    ok = file:write_file(Frame, term_to_binary(
                                  {Other, ern_canonical:bytes(ern_canonical:hashed([Form])),
                                   term_to_binary([{[atom_to_binary(Segment)
                                                     || Segment <- OtherName],
                                                    Sourced, []}])})),
    A = ern_harness:made(Base, "a", none),
    Z = ern_harness:made(Base, "z", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}, {"z", Z, none}]),
    WaitB = ern_harness:bare_started(B, []),
    PortB = ern_harness:bound_port(B),
    {_, Spawner} = ern_harness:client(Root, ern_harness:name(Z), ern_harness:key_files(Z),
                                      ern_carrier:cookie(), PortB, ern_harness:name(B),
                                      ["-ern_nodes_hash", binary_to_list(binary:encode_hex(Waits)),
                                       "-ern_nodes_frame", Frame],
                                      "ern_nodes_spawner"),
    {0, SpawnerOut} = Spawner(),
    [ern_harness:has(SpawnerOut, Line) || Line <- ["no longer held: Other",
                                                   "late frame: the connection lives",
                                                   "lacks: 2", "faulty: ended", "broken: closed",
                                                   "lacked again: true"]],
    ern_harness:seen(B, err, "the peer z was lost", 2, ?WAIT_MS),
    ern_harness:lists(A, [{"b", B, PortB}]),
    {InputA, WaitA} = ern_harness:started(A, Program, ["b"]),
    ern_harness:says(B,
                     "the peer a's spawn at Lost.late:" ++ integer_to_list(line_of(Source,
                                                                                   "late: "))
                     ++ " was not loaded: its time ran out before the function's reach arrived"),
    true = port_command(InputA, "dropped\n"),
    ?assertEqual(0, WaitA()),
    Site = "Lost.late:" ++ integer_to_list(line_of(Source, "let again")),
    ern_harness:says(B, "the process of " ++ Site ++ " faulted: foreign function"
                        " erlang:binary_to_integer/1 raised error:badarg, spawned by the peer a"),
    ern_harness:stop(B, WaitB),
    {Out, _} = ern_harness:said(A),
    {_, ErrB} = ern_harness:said(B),
    [ern_harness:has(Out, Line) || Line <- ["dialed: Right", "late: Io.Timeout", "again: Right"]],
    [ern_harness:has(ErrB, Line)
     || Line <- ["the peer z's spawn at Lost.z:1 was not loaded: the spawner's node no longer"
                 " holds the function's reach",
                 "the peer z sent a frame this node cannot read, and this node ends its connection",
                 "\n    Lost.waits:" ++ integer_to_list(line_of(Source, "parsed(\"x\") + n"))
                 ++ "\n"]],
    [?assertEqual(nomatch, string:find(ErrB, Part)) || Part <- ["ern$", "could not take"]],
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "no longer holds the function's reach",
                                   [{"a", "z"}, {"Site", "Lost.z:1"}]).

%% report §11.2, §8.7, Appendix H: a service names its type by its hash, as
%% any service does, a type the session declares among them, which is the
%% session's whatever input declares it, and the session's namespace in
%% its form carries the node's key. Two shells that are nodes each declare
%% `T` at the prompt, the first at its first input and the second at its
%% second, after a declaration of its own, and each offers a process as the
%% service `p` at it: the two `T`s are two types, so each finds the other's
%% `Left(OtherType)`. Each loads a module both load, as a program that wants
%% two nodes to agree does, and offers a process as `t` at its type: each
%% finds the other's and sends to it.
%%
%% A regression test, written after the code: the shell's test asserted the
%% printed types alone. Then written again after the fix (the log's *MVP
%% 3.1 Read*, for both): the type was hashed under its input's namespace, so
%% the two shells held two types and a find answered `OtherType` where two
%% sessions of one node's were meant. Then again for the node's key (the
%% log's *Sites, Sessions and Their Names*): the two nodes' `T` were one
%% type, the two sessions' namespaces one
shell_service_test_() ->
    ern_harness:nodes_test({waits, 9}, fun shell_service/1).

shell_service(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "shared.ern"), "export type T = T(Int)\n"),
    [PortA, PortB] = [ern_harness:free_port(), ern_harness:free_port()],
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    [ern_harness:edit(Dir,
                      fun(Conf) -> Conf#{<<"services">> => #{<<"t">> => [Peer],
                                                             <<"p">> => [Peer]}} end)
     || {Dir, Peer} <- [{A, <<"b">>}, {B, <<"a">>}]],
    Declared = ["type T = T(Int)\n",
                "let prompt : Peer.Service(T) = Peer.service(\"p\")\n",
                "let waiting : Address(T) = spawn(fn() = receive { _ -> Unit })\n",
                "Peer.offer(prompt, waiting)\n",
                ":load Shared\n",
                "let service : Peer.Service(Shared.T) = Peer.service(\"t\")\n"],
    Offered = fun(Node) ->
                  ["let server : Address(Shared.T) = spawn(fn() : Unit receiving Shared.T =\n"
                   "    receive {\n"
                   "        Shared.T(n) -> Io.println(\"", Node, " got \" <> Int.toString(n))\n"
                   "    })\n"
                   "Peer.offer(service, server)\n"
                   "Io.println(\"offered\")\n"]
              end,
    Found = fun(Count) ->
                ["Io.println(Io.show(Peer.find(prompt, ", ern_harness:wait_ms_text(), ")))\n",
                 "match Peer.find(service, ", ern_harness:wait_ms_text(), ") {\n"
                 "    Right(server) -> {\n"
                 "        send(server, Shared.T(", Count, "));\n"
                 "        Io.println(\"found\")\n"
                 "    }\n"
                 "  | Left(failure) -> Io.println(Io.show(failure))\n"
                 "}\n"]
            end,
    {InputA, WaitA} = ern_harness:shell_started(A, Root),
    true = port_command(InputA, [Declared, Offered("a")]),
    ern_harness:prints(A, "offered"),
    {InputB, WaitB} = ern_harness:shell_started(B, Root),
    true = port_command(InputB, ["type U = U\n", Declared, Offered("b"), Found("5")]),
    ern_harness:prints(B, "found"),
    ern_harness:prints(A, "a got 5"),
    true = port_command(InputA, Found("7")),
    ern_harness:prints(A, "found"),
    ern_harness:prints(B, "b got 7"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    [ern_harness:has(Out, "Left(Io.OtherType)\n") || {Out, _} <- [ern_harness:said(A),
                                                                  ern_harness:said(B)]].

%% report Appendix H, §11.2 *Inputs*, *The attached shell*, §8.7, §3.11:
%% the form of a session's namespace carries its node's public key, so that
%% two nodes' sessions of one number declare two names. `let below =
%% Clock.now()` and a function over it, typed at the prompts of two shells
%% that are nodes, each its node's session 1, are two bindings and two
%% functions. A name a prompt `let` binds is its node's binding, read where
%% the code that names it runs: a compute from b on a of a lambda that
%% reads `below`, and one of b's function, answer `Left(NotLoaded(text))`,
%% b's binding having no value on a, and a names it without the key,
%% `$Session1.below`, on its screen, where a plain shell's node writes its
%% lines, and in b's answer (Appendix E.1); a local the lambda captures
%% crosses with it, and b's own function runs on b over b's value.
%%
%% A regression test, written after the code (the log's *Sites, Sessions and
%% Their Names*): a's value was read, the two sessions' declarations being
%% one identity. The test it replaces, written for the holder of what a
%% `let` binds counted as evaluated so that a peer's spawn found it
%% (the log's *MVP 3.1 Read*), named a binding of another node's session,
%% which no peer can now. The captured local's compute was added with the
%% log's *The Input's Process*, which states the rule the code kept.
shell_binding_spawned_test_() ->
    ern_harness:nodes_test({waits, 7}, fun shell_binding_spawned/1).

shell_binding_spawned(Base) ->
    Typed = "let below = Clock.now()\nfn later() : Int = below + 1\n",
    {{A, InputA, WaitA}, {B, InputB, WaitB}} = typed_shells(Base, {"a", "b"}, Typed),
    Limit = ern_harness:wait_ms_text(),
    true = port_command(InputB, [Typed, "Peer.compute(\"a\", fn() = below + 1, ", Limit, ")\n",
                                 "Peer.compute(\"a\", later, ", Limit, ")\n",
                                 "{ let n = below; Peer.compute(\"a\", fn() = n + 1, ", Limit,
                                 ") == Right(below + 1) }\n",
                                 "later() == below + 1\n"]),
    ern_harness:prints(B, "Left(Io.NotLoaded(\"the binding $Session1.below has no value here\")) :"
                          " Either(Io.Error, Int)", 2, ?WAIT_MS),
    ern_harness:prints(B, "true : Bool", 2, ?WAIT_MS),
    ern_harness:prints(A, "the binding $Session1.below has no value here"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    {OutA, ErrA} = ern_harness:said(A),
    ?assertEqual(nomatch, string:find(OutA ++ ErrA, "$Session1@")).

%% Two shells that are nodes over Base's src/, the first named First,
%% listening and listing the second, named Second, which lists it by its
%% port. The first's session has taken the inputs Typed, and printed
%% `typed` after them, before the second starts. Each shell's directory,
%% input and wait.
typed_shells(Base, {First, Second}, Typed) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    Port = ern_harness:free_port(),
    One = ern_harness:made(Base, First, Port),
    Two = ern_harness:made(Base, Second, none),
    ern_harness:lists(One, [{Second, Two, none}]),
    ern_harness:lists(Two, [{First, One, Port}]),
    {InputOne, WaitOne} = ern_harness:shell_started(One, Root),
    true = port_command(InputOne, [Typed, "Io.println(\"typed\")\n"]),
    ern_harness:prints(One, "typed"),
    {InputTwo, WaitTwo} = ern_harness:shell_started(Two, Root),
    {{One, InputOne, WaitOne}, {Two, InputTwo, WaitTwo}}.

%% report §11.2, §8.7, Appendix E.27: a shell that is a node computes on a
%% peer as a program does: a function declared at its prompt has a hash,
%% which the peer, a shell whose session declared a function of the same
%% text, does not hold, since the form of each session's namespace carries
%% its node's key (Appendix H), so it crosses with the compute; so do a
%% lambda typed at the prompt and a function declared at the desk's prompt
%% alone, the desk answering the reach from the forms it keeps beside the
%% input's code and sending them, and the peer, having verified them,
%% compiles and runs them, answering their values, which the shell prints
%% at their type.
%%
%% A type the desk declares crosses with a function spawned on the worker,
%% whose check's cause names it whole from the root, as its trace names the
%% desk's function (§12.3), and the fault's site and the type's name carry
%% the desk's session, its key left out. A regression test, written after
%% the code
shell_compute_test_() ->
    ern_harness:nodes_test({waits, 9}, fun shell_compute/1).

shell_compute(Base) ->
    Declared = "fn answer() : Int = 6 * 7\n",
    {{Worker, InputWorker, WaitWorker}, {Desk, InputDesk, WaitDesk}} =
        typed_shells(Base, {"worker", "desk"}, Declared),
    Limit = ern_harness:wait_ms_text(),
    true = port_command(InputDesk, [Declared, "Peer.compute(\"worker\", answer, ", Limit, ")\n",
                                    "Peer.compute(\"worker\", fn() = 6 * 7, ", Limit, ")\n",
                                    "fn alone() : Int = 6 * 9\n",
                                    "Peer.compute(\"worker\", alone, ", Limit, ")\n",
                                    "type Count = Count(Int)\n",
                                    "foreign fn wrong() : Count = \"erlang:yield/0\"\n",
                                    "fn counts() : Unit = {\n"
                                    "    Io.println(\"counting\");\n"
                                    "    let _ = wrong();\n"
                                    "    Unit\n"
                                    "}\n",
                                    "Peer.spawn(\"worker\", counts, ", Limit, ")\n"]),
    ern_harness:prints(Desk, "Right(42) : Either(Io.Error, Int)", 2, ?WAIT_MS),
    ern_harness:prints(Desk, "Right(54) : Either(Io.Error, Int)"),
    ern_harness:prints(Desk, ?SPAWNED),
    ern_harness:prints(Worker, "counting"),
    ern_harness:fault_line(InputWorker, Worker,
                           "the process of $Session1.input 9:1 faulted: the return of foreign"
                           " function erlang:yield/0 does not match $Session1.Count: is true,"
                           " spawned by the peer desk\n    $Session1.counts:3\n"),
    true = port_command(InputDesk, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    true = port_command(InputWorker, ":quit\n"),
    ?assertEqual(0, WaitWorker()),
    {OutWorker, _} = ern_harness:said(Worker),
    ?assertEqual(nomatch, string:find(OutWorker, "was not loaded")),
    ?assertEqual(nomatch, string:find(OutWorker, "$Session1@")).

%% report §11.2, §6.5, §8.7: an input that builds a function value keeps its
%% code while the session runs, since the function may be held anywhere: a
%% shell that is a node offers as a service an adapted address made at the
%% prompt, whose function the input built and the runtime's offers hold, and
%% a peer's message, of a type of a module both load, reaches the service
%% through it after many inputs more. A regression test, written after the
%% fix (the log's *MVP 3.1 Read*): the input's module was let go once its
%% answer was in, and the message's delivery faulted with the host's
%% `undef`; the type a module's since two nodes' sessions declare two (the
%% log's *Sites, Sessions and Their Names*)
shell_offered_adapted_test_() ->
    ern_harness:nodes_test({waits, 6}, fun shell_offered_adapted/1).

shell_offered_adapted(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "shared.ern"), "export type T = T(Int)\n"),
    PortA = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, none}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    ern_harness:edit(B, fun(Conf) -> Conf#{<<"services">> => #{<<"t">> => [<<"a">>]}} end),
    Declared = ":load Shared\nlet service : Peer.Service(Shared.T) = Peer.service(\"t\")\n",
    {InputA, WaitA} = ern_harness:shell_started(A, Root),
    true = port_command(InputA,
                        [Declared,
                         "let store : Address(Int) = spawn(fn() : Unit receiving Int =\n"
                         "    receive { n -> Io.println(\"a got \" <> Int.toString(n)) })\n",
                         "Peer.offer(service,"
                         " adapted(store, fn(t) = match t { Shared.T(n) -> n }))\n",
                         [["1 + ", integer_to_list(Index), "\n"] || Index <- lists:seq(1, 30)],
                         "Io.println(\"offered\")\n"]),
    ern_harness:prints(A, "offered"),
    {InputB, WaitB} = ern_harness:shell_started(B, Root),
    true = port_command(InputB, [Declared,
                                 "match Peer.find(service, ", ern_harness:wait_ms_text(), ") {\n"
                                 "    Right(server) -> {\n"
                                 "        send(server, Shared.T(5));\n"
                                 "        Io.println(\"found\")\n"
                                 "    }\n"
                                 "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                 "}\n"]),
    ern_harness:prints(B, "found"),
    ern_harness:prints(A, "a got 5"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    {OutA, ErrA} = ern_harness:said(A),
    [?assertEqual(nomatch, string:find(Text, "undef")) || Text <- [OutA, ErrA]].

%% report §11.2, §8.7, Appendix E.21: a shell that is a node writes a
%% fault's line as `ern run` writes one, the peer whose spawn started the
%% process after the cause, which the FaultReport's `spawnedBy` names. A
%% regression test, written after the code (the log's *MVP 3.1 Read*): the
%% shell's line named the spawner's site alone. A shell in line mode reports
%% a fault before its next prompt, so the shell that faulted is given inputs
%% until the line comes (fault_line/3). A local fault's report, which names
%% no peer, is ern_rt_tests' fault_reports_test's
shell_peer_fault_test_() ->
    ern_harness:nodes_test({waits, 6}, fun shell_peer_fault/1).

shell_peer_fault(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = ern_harness:free_port(),
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, none}]),
    ern_harness:lists(B, [{"a", A, PortA}]),
    Typed = "fn divided() : Unit = {\n"
            "    Io.println(\"dividing\");\n"
            "    let _ = 1 / List.size([]);\n"
            "    Unit\n"
            "}\n",
    {InputA, WaitA} = ern_harness:shell_started(A, Root),
    true = port_command(InputA, [Typed, "Io.println(\"typed\")\n"]),
    ern_harness:prints(A, "typed"),
    {InputB, WaitB} = ern_harness:shell_started(B, Root),
    true = port_command(InputB,
                        [Typed, "match Peer.spawn(\"a\", divided, ", ern_harness:wait_ms_text(),
                         ") {\n"
                                "    Right(_) -> Io.println(\"spawned\")\n"
                                "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                "}\n"]),
    ern_harness:prints(B, "spawned"),
    ern_harness:prints(A, "dividing"),
    ern_harness:fault_line(InputA, A, " faulted: division by zero, spawned by the peer b\n"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()).

%% A node, the store, running Root's store.erc and listing the desk, and a
%% shell over Source that is the desk, Root on its load path, listing the
%% store by its port. The store has printed `ready`, and the desk has
%% spawned a lambda on it, which the store did not hold and was sent. Each
%% node's directory, input and wait.
store_and_desk_shell(Base, Root, Source) ->
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = ern_harness:started(Store, filename:join(Root, "store.erc"), []),
    ern_harness:prints(Store, "ready"),
    {DeskInput, WaitDesk} = ern_harness:shell_started(Desk, Source, [Root]),
    %% the desk dials the store, which does not hold the lambda, and is sent
    %% its form, which it compiles and starts
    true = port_command(DeskInput,
                        ["Peer.spawn(\"store\", fn() = Unit, ", ern_harness:wait_ms_text(), ")\n"]),
    ern_harness:prints(Desk, ?SPAWNED),
    {{Store, StoreInput, WaitStore}, {Desk, DeskInput, WaitDesk}}.

%% report §11.2, §8.7: a shell that is a node loads a module, and a peer
%% of the build that holds the module spawns a function of it there by its
%% hash, the value of the binding its reach names found, as on a node that
%% runs a program; a function typed at the shell has a hash and no peer
%% holds it, so a spawn of it carries its form to the peer, which compiles
%% it and starts it. Written after the code: a peer found no value of a
%% binding the shell's load had evaluated
shell_node_test_() ->
    ern_harness:nodes_test({waits, 9}, fun shell_node/1).

shell_node(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "greet.ern"),
                         %% computed, since a constant has its value wherever its code is
                         %% (§11.1)
                         "let greeting : String = \"hello from\" <> \" the shell's load\"\n\n"
                         "export fn hello() : Unit = Io.println(greeting)\n"),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node once a line comes.\n"
                         "\n"
                         "export fn main() : Unit receiving Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    let _ = Io.readLine();\n"
                         "    let spawned = match Peer.spawn(\"desk\", Greet.hello, waitMs()) {\n"
                         "        Right(_) -> \"Right\"\n"
                         "      | Left(failure) -> Io.show(failure)\n"
                         "    };\n"
                         "    Io.println(\"spawned: \" <> spawned);\n"
                         "    held()\n"
                         "}\n"
                         "\n"
                         "fn held() : Unit receiving m = receive { _ -> held() }\n"
                         ++ ern_harness:wait_ms_declaration()),
    0 = ern_harness:built([Root]),
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = ern_harness:started(Store, filename:join(Root, "store.erc"), []),
    ern_harness:prints(Store, "ready"),
    {DeskInput, WaitDesk} = ern_harness:shell_started(Desk, Root),
    true = port_command(DeskInput, [":load Greet\n"
                                    "Peer.spawn(\"store\", fn() = Unit, ",
                                    ern_harness:wait_ms_text(), ")\n"]),
    ern_harness:prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "go\n"),
    ern_harness:prints(Store, "spawned: Right"),
    ern_harness:prints(Desk, "hello from the shell's load"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {DeskOut, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    %% report §11.2: greet.erc stands beside its source and is as new as it,
    %% so the load takes it and compiles nothing
    ern_harness:has(DeskOut, "Greet, from " ++ ern_build:shown(filename:join(Root, "greet.erc"))),
    ?assertEqual(nomatch, string:find(StoreErr, "was not loaded")).

%% report §8.7, §11.2: a shell that is a node over a build answers a peer
%% from the latest unit whose bindings have their values, as the session
%% uses it. Before anything is loaded the build's unit, read at the node's
%% start and never evaluated, answers no peer whose function's reach names a
%% binding: the spawn is NotLoaded and the node says the binding has no
%% value here, which is true. After `:load` of the module's source, changed
%% in another function, the same spawn runs in the session's unit, its
%% service the session's. After a `:reload` that leaves the service binding
%% unchanged, evaluated again and so a service of its own, a peer's spawn
%% sends to the new version's service, which the session sends to next.
%%
%% A regression test, written after the fix (the log's *MVP 3.1 Read*): the
%% table answered the first unit loaded, so the spawn after the `:load` was
%% refused with that line, then false, and the one after the `:reload`
%% reached the previous version's service
shell_node_versions_test_() ->
    ern_harness:nodes_test({waits, 15}, fun shell_node_versions/1).

shell_node_versions(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    Greet = fun(Other) ->
                ["// A greeter whose service is a binding, and what a peer spawns.\n"
                 "\n"
                 "export type Msg = Greet(String)\n"
                 "\n"
                 "let greeter : Address(Msg) = spawn(fn() : Unit receiving Msg = greeted(0))\n"
                 "\n"
                 "fn greeted(count : Int) : Unit receiving Msg =\n"
                 "    receive {\n"
                 "        Greet(who) -> {\n"
                 "            Io.println(who <> \" greeted \" <> Int.toString(count));\n"
                 "            greeted(count + 1)\n"
                 "        }\n"
                 "    }\n"
                 "\n"
                 "export fn greet(who : String) : Unit = send(greeter, Greet(who))\n"
                 "\n"
                 "export fn hello() : Unit = greet(\"hello\")\n"
                 "\n"
                 "export fn wave() : Unit = greet(\"wave\")\n",
                 Other]
            end,
    ok = file:write_file(filename:join(Root, "greet.ern"), Greet("")),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of the function each line names.\n"
                         "\n"
                         "export fn main() : Unit receiving Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit =\n"
                         "    match Io.readLine() {\n"
                         "        Some(\"wave\") -> told(\"wave\", Peer.spawn(\"desk\", Greet.wave,"
                         " waitMs()))\n"
                         "      | Some(name) -> told(name, Peer.spawn(\"desk\", Greet.hello,"
                         " waitMs()))\n"
                         "      | None -> Unit\n"
                         "    }\n"
                         "\n"
                         "fn told(name : String, spawned : Either(Io.Error, Address(Never)))"
                         " : Unit = {\n"
                         "    let answer = match spawned {\n"
                         "        Right(_) -> \"Right\"\n"
                         "      | Left(failure) -> Io.show(failure)\n"
                         "    };\n"
                         "    Io.println(name <> \": \" <> answer);\n"
                         "    spawning()\n"
                         "}\n" ++ ern_harness:wait_ms_declaration()),
    0 = ern_harness:built([Root]),
    Changed = fun(Text) ->
                  ok = file:write_file(filename:join(Source, "greet.ern"),
                                       Greet(["\nexport fn other() : Unit ="
                                              " Io.println(\"", Text, "\")\n"]))
              end,
    Changed("another function"),
    {{Store, StoreInput, WaitStore}, {Desk, DeskInput, WaitDesk}} =
        store_and_desk_shell(Base, Root, Source),
    true = port_command(StoreInput, "first\n"),
    ern_harness:prints(Store, "first: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Greet\n"),
    ern_harness:prints(Desk,
                       "Greet, compiled from " ++ ern_build:shown(filename:join(Source,
                                                                                "greet.ern"))),
    true = port_command(StoreInput, "loaded\n"),
    ern_harness:prints(Store, "loaded: Right"),
    ern_harness:prints(Desk, "hello greeted 0"),
    true = port_command(DeskInput, "Greet.greet(\"prompt\")\n"),
    ern_harness:prints(Desk, "prompt greeted 1"),
    Changed("another function changed"),
    true = port_command(DeskInput, ":reload\n"),
    ern_harness:prints(Desk, "Greet, compiled again"),
    true = port_command(StoreInput, "wave\n"),
    ern_harness:prints(Store, "wave: Right"),
    ern_harness:prints(Desk, "wave greeted 0"),
    true = port_command(DeskInput, "Greet.greet(\"again\")\n"),
    ern_harness:prints(Desk, "again greeted 1"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {DeskOut, DeskErr} = ern_harness:said(Desk),
    ?assertEqual(nomatch, string:find(DeskOut, "wave greeted 2")),
    %% the shell writes the node's lines on its screen
    ern_harness:has(DeskOut,
                    "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
                    " Greet.greeter has no value here"),
    ?assertEqual(1, length(string:split(DeskOut ++ DeskErr, "has no value here", all)) - 1).

%% report §8.7, §11.2: a shell that is a node over a build answers a peer's
%% spawn of a build function only where every binding its reach names has
%% its value as its code reads it. The build's caller calls the build's
%% greeter, which the session never evaluated, though it loaded a changed
%% greeter from source, which holds the binding under one identity: the
%% spawn is NotLoaded, the node saying the binding has no value here, true
%% of the code that would run. Once the session has loaded the caller from
%% source too, compiled against its greeter, the spawn runs there. A
%% regression test, written after the fix, found on reading back a fix of
%% the log's *MVP 3.1 Read*: the binding was found by its identity in the
%% session's greeter, the build's caller ran, and its process faulted, the
%% binding read in the build's greeter having no value
shell_node_reach_test_() ->
    ern_harness:nodes_test({waits, 11}, fun shell_node_reach/1).

shell_node_reach(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    %% the binding computed, since a constant has its value wherever its code
    %% is (§11.1)
    Greet = "let greeting : String = \"hello from\" <> \" the greeter\"\n"
            "\n"
            "export fn hello() : Unit = Io.println(greeting)\n",
    Caller = "export fn call() : Unit = Greet.hello()\n",
    ok = file:write_file(filename:join(Root, "greet.ern"), Greet),
    ok = file:write_file(filename:join(Root, "caller.ern"), Caller),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of Caller.call at each line.\n"
                         "\n"
                         "export fn main() : Unit receiving Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit =\n"
                         "    match Io.readLine() {\n"
                         "        Some(name) -> {\n"
                         "            let spawned = Peer.spawn(\"desk\", Caller.call, waitMs());\n"
                         "            let answer = match spawned {\n"
                         "                Right(_) -> \"Right\"\n"
                         "              | Left(failure) -> Io.show(failure)\n"
                         "            };\n"
                         "            Io.println(name <> \": \" <> answer);\n"
                         "            spawning()\n"
                         "        }\n"
                         "      | None -> Unit\n"
                         "    }\n" ++ ern_harness:wait_ms_declaration()),
    0 = ern_harness:built([Root]),
    Other = "\nexport fn other() : Unit = Io.println(\"other\")\n",
    ok = file:write_file(filename:join(Source, "greet.ern"), [Greet, Other]),
    ok = file:write_file(filename:join(Source, "caller.ern"), Caller),
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = ern_harness:started(Store, filename:join(Root, "store.erc"), []),
    ern_harness:prints(Store, "ready"),
    {DeskInput, WaitDesk} = ern_harness:shell_started(Desk, Source, [Root]),
    true = port_command(DeskInput, ":load Greet\n"),
    ern_harness:prints(Desk,
                       "Greet, compiled from " ++ ern_build:shown(filename:join(Source,
                                                                                "greet.ern"))),
    %% the desk dials the store, which does not hold the lambda, and is sent
    %% its form, which it compiles and starts
    true = port_command(DeskInput,
                        ["Peer.spawn(\"store\", fn() = Unit, ", ern_harness:wait_ms_text(), ")\n"]),
    ern_harness:prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "first\n"),
    ern_harness:prints(Store, "first: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Caller\n"),
    ern_harness:prints(Desk,
                       "Caller, compiled from " ++ ern_build:shown(filename:join(Source,
                                                                                 "caller.ern"))),
    true = port_command(StoreInput, "second\n"),
    ern_harness:prints(Store, "second: Right"),
    ern_harness:prints(Desk, "hello from the greeter"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {DeskOut, DeskErr} = ern_harness:said(Desk),
    %% the shell writes the node's lines on its screen
    ern_harness:has(DeskOut,
                    "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
                    " Greet.greeting has no value here"),
    [?assertEqual(nomatch, string:find(Text, "fault")) || Text <- [DeskOut, DeskErr]].

%% report §11.2, §6.9, §8.7: on a shell that is a node over a build, a
%% refused `:load` that evaluated a unit of the build, which the node held
%% and the session had not evaluated, kills the process that unit's binding
%% spawned and names it, and leaves the unit as it was before the load: a
%% peer's spawn of its function is NotLoaded, its binding without its value
%% here, before the load and after it alike. A regression test, written
%% after the fix (the log's *MVP 3.1 Read*): the process ran on unnamed,
%% since it ran no code the load brought, while the load erased the unit's
%% values
refused_build_load_test_() ->
    ern_harness:nodes_test({waits, 11}, fun refused_build_load/1).

refused_build_load(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    ok = file:write_file(filename:join(Root, "greet.ern"),
                         "// A greeter whose service is a binding, and what a peer spawns.\n"
                         "\n"
                         "export type Msg = Greet(String)\n"
                         "\n"
                         "let greeter : Address(Msg) = spawn(fn() : Unit receiving Msg ="
                         " greeted(0))\n"
                         "\n"
                         "fn greeted(count : Int) : Unit receiving Msg =\n"
                         "    receive {\n"
                         "        Greet(who) -> {\n"
                         "            Io.println(who <> \" greeted \" <> Int.toString(count));\n"
                         "            greeted(count + 1)\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "export fn hello() : Unit = send(greeter, Greet(\"hello\"))\n"),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of Greet.hello at each line.\n"
                         "\n"
                         "export fn main() : Unit receiving Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit =\n"
                         "    match Io.readLine() {\n"
                         "        Some(name) -> {\n"
                         "            let spawned = Peer.spawn(\"desk\", Greet.hello, waitMs());\n"
                         "            let answer = match spawned {\n"
                         "                Right(_) -> \"Right\"\n"
                         "              | Left(failure) -> Io.show(failure)\n"
                         "            };\n"
                         "            Io.println(name <> \": \" <> answer);\n"
                         "            spawning()\n"
                         "        }\n"
                         "      | None -> Unit\n"
                         "    }\n" ++ ern_harness:wait_ms_declaration()),
    0 = ern_harness:built([Root]),
    ok = file:write_file(filename:join(Source, "bad.ern"),
                         "export let greeted : Unit = Greet.hello()\n"
                         "\n"
                         "export let broken : Int = 1 / List.size([])\n"),
    {{Store, StoreInput, WaitStore}, {Desk, DeskInput, WaitDesk}} =
        store_and_desk_shell(Base, Root, Source),
    true = port_command(StoreInput, "before\n"),
    ern_harness:prints(Store, "before: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Bad\n"),
    ern_harness:prints(Desk,
                       "Bad.broken:3 faulted: division by zero; nothing was loaded, and the process"
                       " spawned at Greet.greeter:5 was killed"),
    true = port_command(DeskInput, ":processes\n"),
    ern_harness:prints(Desk, "no process of the session's is running"),
    true = port_command(StoreInput, "after\n"),
    ern_harness:prints(Store, "after: Io.NotLoaded"),
    %% the shell writes the node's lines on its screen, this one after the
    %% desk's worker has answered the store, so it is waited for before the
    %% session is ended
    NotLoaded = "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
                " Greet.greeter has no value here",
    ern_harness:prints(Desk, NotLoaded, 2, ?WAIT_MS),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {DeskOut, DeskErr} = ern_harness:said(Desk),
    ?assertEqual(2, length(string:split(DeskOut, NotLoaded, all)) - 1),
    ?assertEqual(nomatch, string:find(DeskErr, "fault")).

%% report §6.5, §8.4, §6.9, §8.7: a fault in an adapted address's function,
%% applied where the address was made as a message from another node
%% arrives, takes the message's place in the target's mailbox: the
%% restarting target faults at its wait, is reported restarted with the
%% cause, and its new run takes the next message; the sender goes on, its
%% target's three restarts within a minute the scenario's and no bound. A
%% regression test, written after the fix (the log's *MVP 3.1 Read*): the
%% fault killed the target by an exit signal, so it ended without a restart,
%% and the next message was lost
adapted_fault_test_() ->
    ern_harness:nodes_test({waits, 11}, fun adapted_fault/1).

adapted_fault(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "adapted.ern"),
                         "// A restarting worker behind an adapted address whose function\n"
                         "// divides by what is sent, offered on one node and sent to from\n"
                         "// the other a line at a time.\n"
                         "\n"
                         "type Msg = Work(Int)\n"
                         "\n"
                         "let service : Peer.Service(Int) = Peer.service(\"work\")\n"
                         "\n"
                         "export fn main() : Unit receiving Unit =\n"
                         "    match Os.arguments {\n"
                         "        [\"make\"] -> make()\n"
                         "      | _ -> sending()\n"
                         "    }\n"
                         "\n"
                         "fn make() : Unit receiving Unit = {\n"
                         "    let maker = self();\n"
                         "    let worker = spawn(restarting(RestartLimit(restarts = 3,"
                         " within = 60000),\n"
                         "                                  fn() : Unit receiving Msg = {\n"
                         "                                      send(maker, Unit);\n"
                         "                                      work()\n"
                         "                                  }));\n"
                         "    let _ = Peer.offer(service, adapted(worker, fn(n) ="
                         " Work(100 / n)));\n"
                         "    runs(1)\n"
                         "}\n"
                         "\n"
                         "fn runs(count : Int) : Unit receiving Unit =\n"
                         "    receive {\n"
                         "        _ -> {\n"
                         "            Io.println(\"run \" <> Int.toString(count));\n"
                         "            runs(count + 1)\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "fn work() : Unit receiving Msg =\n"
                         "    receive {\n"
                         "        Work(n) -> {\n"
                         "            Io.println(\"took \" <> Int.toString(n));\n"
                         "            work()\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "fn sending() : Unit receiving Unit =\n"
                         "    match Peer.find(service, waitMs()) {\n"
                         "        Right(work) -> {\n"
                         "            Io.println(\"found\");\n"
                         "            sent(work)\n"
                         "        }\n"
                         "      | Left(failure) -> Io.println(Io.show(failure))\n"
                         "    }\n"
                         "\n"
                         "fn sent(work : Address(Int)) : Unit receiving Unit =\n"
                         "    match Io.readLine() {\n"
                         "        Some(\"zero\") -> {\n"
                         "            send(work, 0);\n"
                         "            Io.println(\"sent 0\");\n"
                         "            sent(work)\n"
                         "        }\n"
                         "      | Some(_) -> {\n"
                         "            send(work, 5);\n"
                         "            Io.println(\"sent 5\");\n"
                         "            sent(work)\n"
                         "        }\n"
                         "      | None -> Unit\n"
                         "    }\n" ++ ern_harness:wait_ms_declaration()),
    0 = ern_harness:built([Root]),
    Program = filename:join(Root, "adapted.erc"),
    PortMaker = ern_harness:free_port(),
    Maker = ern_harness:made(Base, "maker", PortMaker),
    Sender = ern_harness:made(Base, "sender", none),
    ern_harness:lists(Maker, [{"sender", Sender, none}]),
    ern_harness:lists(Sender, [{"maker", Maker, PortMaker}]),
    ern_harness:edit(Sender,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"work">> => [<<"maker">>]}} end),
    WaitMaker = ern_harness:start(Maker, Program, ["make"]),
    ern_harness:prints(Maker, "run 1"),
    {SenderInput, WaitSender} = ern_harness:started(Sender, Program, []),
    ern_harness:prints(Sender, "found"),
    true = port_command(SenderInput, "zero\n"),
    ern_harness:prints(Sender, "sent 0"),
    ern_harness:says(Maker, "faulted, restarted: division by zero"),
    %% the new run has begun, its mailbox emptied of the old (§6.9)
    ern_harness:prints(Maker, "run 2"),
    true = port_command(SenderInput, "five\n"),
    ern_harness:prints(Sender, "sent 5"),
    ern_harness:prints(Maker, "took 20"),
    ern_harness:stop(Sender, WaitSender),
    ern_harness:stop(Maker, WaitMaker),
    {_, SenderErr} = ern_harness:said(Sender),
    ?assertEqual(nomatch, string:find(SenderErr, "fault")).

%% report §6.5: an adapted address held on another node keeps nothing alive
%% on the node that made it. Two holders on the maker each make a cell the
%% host holds, an `atomics` array behind a foreign type, and an address
%% whose function reads it, answer the address to the sender and end. Where
%% the function alone held the cell, a message sent through the address
%% once its holder has ended faults the target with the host function's
%% raise, as a fault in the function, and the sender goes on; where the
%% target holds the cell too, the message arrives. A regression test,
%% written after the code; it does not cover a captured process or
%% resource that has ended, nor a cell the host lets go while the function
%% is applied
capture_gone_test_() ->
    ern_harness:nodes_test({waits, 12}, fun capture_gone/1).

capture_gone(Base) ->
    {Program, Source} = capture_build(Base),
    PortMaker = ern_harness:free_port(),
    Maker = ern_harness:made(Base, "maker", PortMaker),
    Sender = ern_harness:made(Base, "sender", none),
    ern_harness:lists(Maker, [{"sender", Sender, none}]),
    ern_harness:lists(Sender, [{"maker", Maker, PortMaker}]),
    ern_harness:edit(Sender, fun(Conf) ->
                                 Conf#{<<"services">> => #{<<"alone">> => [<<"maker">>],
                                                           <<"shared">> => [<<"maker">>]}}
                             end),
    WaitMaker = ern_harness:start(Maker, Program, ["make"]),
    ern_harness:prints(Maker, "offered"),
    {SenderInput, WaitSender} = ern_harness:started(Sender, Program, []),
    ern_harness:prints(Sender, "given"),
    %% the cell the alone holder made is held by nothing of the maker's now
    ern_harness:prints(Maker, "the alone holder ended"),
    ern_harness:prints(Maker, "the shared holder ended"),
    true = port_command(SenderInput, "alone\n"),
    ern_harness:prints(Sender, "sent to the alone address"),
    %% the target's site, where the holder spawned it, and the function's
    %% frame in the trace
    [Target, Function] = ["Capture.holdingAlone:" ++ integer_to_list(line_of(Source, Part))
                          || Part <- ["spawn(fn() = seeing())", "answer(reply, adapted("]],
    ern_harness:says(Maker, "the process of " ++ Target
                            ++ " faulted: foreign function atomics:get/2 raised error:badarg"),
    true = port_command(SenderInput, "shared\n"),
    ern_harness:prints(Maker, "the shared target saw 47 beside 42"),
    ?assertEqual(0, WaitSender()),
    ern_harness:stop(Maker, WaitMaker),
    {SenderOut, SenderErr} = ern_harness:said(Sender),
    {MakerOut, MakerErr} = ern_harness:said(Maker),
    ?assertEqual(["given", "sent to the alone address", "sent to the shared address", ""],
                 string:split(SenderOut, "\n", all)),
    ?assertEqual(nomatch, string:find(SenderErr, "fault")),
    ern_harness:has(MakerErr, "\n    " ++ Function ++ "\n"),
    ?assertEqual(nomatch, string:find(MakerOut, "the alone target saw")).

%% The program of capture_gone/1, built in Base: the maker's two holders and
%% their targets, and the sender; answers its `.erc` and its source.
capture_build(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    Source = <<"
// Report §6.5: adapted addresses made on the maker and sent through from
// the sender, whose function captures a cell the host holds, an `atomics`
// array behind a foreign type. One holder makes a target that holds nothing
// and an address whose function alone holds the cell; the other a target
// that holds the cell too. Each answers its address and ends.

foreign type Cell

foreign fn cell(size : Int, options : List(Foreign.Term)) : Cell =
    \"atomics:new/2\"

foreign fn put(cell : Cell, index : Int, value : Int) : Unit =
    \"atomics:put/3\"

foreign fn get(cell : Cell, index : Int) : Int =
    \"atomics:get/2\"

type TargetMsg = Seen(Int)

type HolderMsg = Give(Reply(Address(Int)))

type MakerMsg = Ended(String)

let alone : Peer.Service(HolderMsg) = Peer.service(\"alone\")

let shared : Peer.Service(HolderMsg) = Peer.service(\"shared\")

export fn main() : Unit receiving MakerMsg =
    match Os.arguments {
        [\"make\"] -> {
            offered(alone, \"alone\", spawn(fn() = holdingAlone()));
            offered(shared, \"shared\", spawn(fn() = holdingShared()));
            Io.println(\"offered\");
            ended()
        }
      | _ ->
            sending()
    }

fn offered(service : Peer.Service(HolderMsg),
           name : String,
           holder : Address(HolderMsg)) : Unit receiving MakerMsg = {
    monitor(Process.fromAddress(holder), fn(_) = Ended(name));
    let _ = Peer.offer(service, holder);
    Unit
}

// Each holder's end, said, until the node is stopped.
fn ended() : Unit receiving MakerMsg =
    receive {
        Ended(name) -> {
            Io.println(\"the \" <> name <> \" holder ended\");
            ended()
        }
    }

fn counted() : Cell = {
    let made = cell(1, []);
    put(made, 1, 42);
    made
}

// The cell held by the address's function alone once this process ends.
fn holdingAlone() : Unit receiving HolderMsg =
    receive {
        Give(reply) -> {
            let held = counted();
            let target = spawn(fn() = seeing());
            answer(reply, adapted(target, fn(n) = Seen(get(held, 1) + n)))
        }
    }

// The cell held by the target too.
fn holdingShared() : Unit receiving HolderMsg =
    receive {
        Give(reply) -> {
            let held = counted();
            let target = spawn(fn() = seeingBeside(held));
            answer(reply, adapted(target, fn(n) = Seen(get(held, 1) + n)))
        }
    }

fn seeing() : Unit receiving TargetMsg =
    receive {
        Seen(n) -> {
            Io.println(\"the alone target saw \" <> Int.toString(n));
            seeing()
        }
    }

fn seeingBeside(held : Cell) : Unit receiving TargetMsg =
    receive {
        Seen(n) -> {
            Io.println(\"the shared target saw \"
                           <> Int.toString(n)
                           <> \" beside \"
                           <> Int.toString(get(held, 1)));
            seeingBeside(held)
        }
    }

// Report §6.5: each address sent to once the test has seen its holder end;
// the sender goes on after each send.
fn sending() : Unit receiving MakerMsg = {
    let fromAlone = given(alone);
    let fromShared = given(shared);
    Io.println(\"given\");
    let _ = Io.readLine();
    send(fromAlone, 5);
    Io.println(\"sent to the alone address\");
    let _ = Io.readLine();
    send(fromShared, 5);
    Io.println(\"sent to the shared address\")
}

fn given(service : Peer.Service(HolderMsg)) : Address(Int) =
    match Peer.find(service, waitMs()) {
        Right(holder) ->
            match Address.call(holder, Give, waitMs()) {
                Some(address) -> address
              | None -> fault(\"no address given\")
            }
      | Left(failure) ->
            fault(Io.show(failure))
    }
"/utf8>>,
    ok = file:write_file(filename:join(Root, "capture.ern"),
                         [Source, ern_harness:wait_ms_declaration()]),
    0 = ern_harness:built([Root]),
    {filename:join(Root, "capture.erc"), unicode:characters_to_list(Source)}.

%%
%% The end told, and the proxy (report §8.6, Appendix E.23, G.7)
%%

%% The directory test/fixtures/peers/'s programs are built in (peers/1), the
%% counter's keeper, its asker and the proxy's client among them.
peers_built(Base) ->
    {Program, _} = peers(Base),
    filename:dirname(Program).

%% report §8.6, §8.7, Appendix E.23: termination, here `ern stop`'s, tells
%% the node's subscriber, which the node says it waits for; while it
%% waits, a peer finds the node's service and calls it; the node ends once
%% the subscriber has answered, by the signal, and says the answer. Written
%% after the code
end_told_on_a_node_test_() ->
    ern_harness:nodes_test({waits, 8}, fun end_told_on_a_node/1).

end_told_on_a_node(Base) ->
    Root = peers_built(Base),
    PortStore = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}]),
    ern_harness:edit(Desk,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"store">>]}} end),
    {StoreInput, WaitStore} = ern_harness:started(Store, filename:join(Root, "keeper.erc"),
                                                  ["wait"]),
    ern_harness:prints(Store, "offered"),
    ern_harness:terminated(Store),
    ern_harness:prints(Store, "told"),
    ern_harness:says(Store, "the end waits for 1 subscriber: Keeper.main"),
    ?assertEqual(0, (ern_harness:start(Desk, filename:join(Root, "asker.erc"), []))()),
    true = port_command(StoreInput, "go\n"),
    ?assertEqual(143, WaitStore()),
    {DeskOut, _} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    ern_harness:has(DeskOut, "asked: Some(3)"),
    %% the lines as the deployment guide quotes them
    ern_deployment_tests:cataloged(StoreErr, "7", "the end waits for", []),
    ern_deployment_tests:cataloged(StoreErr, "7", "subscriber Keeper.main answered", []).

%% report §8.6, §11.2: a second termination ends the node at once, past a
%% subscriber that does not answer, which the node says. Written after the
%% code, the line after that
second_termination_test_() ->
    ern_harness:nodes_test({waits, 5}, fun second_termination/1).

second_termination(Base) ->
    Root = peers_built(Base),
    Store = ern_harness:made(Base, "store", none),
    WaitStore = ern_harness:start(Store, filename:join(Root, "keeper.erc"), ["hold"]),
    ern_harness:prints(Store, "offered"),
    ern_harness:terminated(Store),
    ern_harness:says(Store, "the end waits for 1 subscriber: Keeper.main"),
    ern_harness:terminated(Store),
    ?assertEqual(143, WaitStore()),
    {_, Err} = ern_harness:said(Store),
    ern_harness:has(Err, "the end was cut short, 1 subscriber unanswered: Keeper.main"),
    ?assertEqual(nomatch, string:find(Err, "the subscriber Keeper.main")).

%% Appendix G.7, report §8.7: a proxy reaches the counter, a
%% call through it answers None while the counter's node is stopped, it
%% reaches the counter again when its node starts again, and on another
%% node that offers it once the first is stopped. An add sent through it
%% while the node is stopped is dropped, and not delivered once the node is
%% back: the counter started again counts from 0, and answers 0. Written
%% after the code, the add a regression test written after that
proxy_finds_again_test_() ->
    ern_harness:nodes_test({waits, 13}, fun proxy_finds_again/1).

proxy_finds_again(Base) ->
    Root = peers_built(Base),
    {PortStore, PortOther} = {ern_harness:free_port(), ern_harness:free_port()},
    Store = ern_harness:made(Base, "store", PortStore),
    Other = ern_harness:made(Base, "other", PortOther),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Other, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, PortStore}, {"other", Other, PortOther}]),
    ern_harness:edit(Desk, fun(Conf) ->
                               Conf#{<<"services">> => #{<<"counter">> => [<<"store">>,
                                                                           <<"other">>]}}
                           end),
    Keeper = filename:join(Root, "keeper.erc"),
    WaitStore = ern_harness:start(Store, Keeper, []),
    ern_harness:prints(Store, "offered"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, filename:join(Root, "client.erc"), []),
    ern_harness:prints(Desk, "proxy started"),
    Ask = fun(Line) -> true = port_command(DeskInput, "go\n"), ern_harness:prints(Desk, Line) end,
    Ask("first: Some(0)"),
    ern_harness:stop(Store, WaitStore),
    Ask("away: None"),
    WaitStoreAgain = ern_harness:start(Store, Keeper, []),
    ern_harness:prints(Store, "offered"),
    Ask("back: Some(0)"),
    ern_harness:stop(Store, WaitStoreAgain),
    WaitOther = ern_harness:start(Other, Keeper, []),
    ern_harness:prints(Other, "offered"),
    Ask("other: Some(0)"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Other, WaitOther).

%% report §8.7, §6.6, Appendix E.27: examples/remote_counter.ern as
%% two nodes, as its first comment runs them: b runs serve, which offers
%% the counter as its service, and a runs main, which finds the counter on
%% b and calls it across the nodes. A regression test, written with the
%% example; a find at another type is program_test_'s
remote_counter_test_() ->
    ern_harness:nodes_test({waits, 5}, fun remote_counter/1).

remote_counter(Base) ->
    BuildRoot = filename:join(Base, "build"),
    0 = ern_harness:built(["--source-root", "../examples", "--build-root", BuildRoot,
                           "../examples/remote_counter.ern"]),
    Program = filename:join(BuildRoot, "remote_counter.erc"),
    PortB = ern_harness:free_port(),
    ConfigDirA = ern_harness:made(Base, "a", none),
    ConfigDirB = ern_harness:made(Base, "b", PortB),
    ern_harness:lists(ConfigDirA, [{"b", ConfigDirB, PortB}]),
    ern_harness:lists(ConfigDirB, [{"a", ConfigDirA, none}]),
    ern_harness:edit(ConfigDirA,
                     fun(Configuration) ->
                         Configuration#{<<"services">> => #{<<"counter">> => [<<"b">>]}}
                     end),
    {_, WaitB} = ern_harness:launched(ConfigDirB, [?ERN, " run --config-dir ", ConfigDirB,
                                                   " --main serve ", Program]),
    ern_harness:prints(ConfigDirB, "offered"),
    ?assertEqual(0, (ern_harness:start(ConfigDirA, Program, []))()),
    ern_harness:stop(ConfigDirB, WaitB),
    {OutA, _} = ern_harness:said(ConfigDirA),
    ern_harness:has(OutA, "total on b: Some(5)").

%% report §6.6, §6.9, §8.7, Appendix E.27: examples/lease_broker.ern as two
%% nodes, as its first comment runs them. b runs serve, which offers the
%% broker as its service and says where it listens, the port the host
%% picked, at which a lists it once it has said so. a runs visit, whose two
%% clients borrow from b's broker; bob restarts, which visit's service
%% monitor on bob's node is told of and so is the broker's on b, which
%% takes his lease back, Restarted, before his new run sends anything, so
%% that the ledger a reads once his new run has answered lists ann's lease
%% alone, and the broker takes ann's back as a's program ends, ProgramEnd
%% (the log's *A Restart Told Across Nodes*).
%%
%% Each node prints the lines its console block shows, a without its
%% listening line, since it does not listen here, and b at its port. A
%% regression test, written with the example; a loss, which the comment
%% says a service monitor is told of, is across/1's
lease_broker_test_() ->
    ern_harness:nodes_test({waits, 9}, fun lease_broker/1).

lease_broker(Base) ->
    BuildRoot = filename:join(Base, "build"),
    0 = ern_harness:built(["--source-root", "../examples", "--build-root", BuildRoot,
                           "../examples/lease_broker.ern"]),
    Program = filename:join(BuildRoot, "lease_broker.erc"),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    ern_harness:lists(B, [{"a", A, none}]),
    {_, WaitB} = ern_harness:launched(B, [?ERN, " run --config-dir ", B, " --main serve ",
                                          Program]),
    PortB = ern_harness:bound_port(B),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"leases">> => [<<"b">>]}} end),
    ern_harness:prints(B, "offered"),
    {_, WaitA} = ern_harness:launched(A, [?ERN, " run --config-dir ", A, " --main visit ",
                                          Program]),
    ?assertEqual(0, WaitA()),
    ern_harness:prints(B, "the broker took back 2 from bob: Restarted"),
    ern_harness:prints(B, "the broker took back 1 from ann: ProgramEnd"),
    ern_harness:stop(B, WaitB),
    {OutA, ErrA} = ern_harness:said(A),
    {OutB, ErrB} = ern_harness:said(B),
    Shown = fun(Command) -> ern_integration_tests:shown("lease_broker.ern", Command) end,
    ?assertEqual(Shown("ern run --config-dir a --main visit lease_broker.erc")
                     -- [<<"listening on 0.0.0.0:8654">>],
                 ern_integration_tests:printed([OutA, ErrA])),
    %% the last line of b's standard error, `Terminated`, is the line the
    %% shell launched/2 runs the node under writes of its end by the signal
    ?assertEqual(lists:sort([<<"listening on 127.0.0.1:", (integer_to_binary(PortB))/binary>>,
                             <<"Terminated">>
                             | Shown("ern run --config-dir b --main serve"
                                     " lease_broker.erc")
                               -- [<<"listening on 127.0.0.1:8655">>]]),
                 ern_integration_tests:printed([OutB, ErrB])).

%% report §8.7, Appendix E.27, C, G.4: a compute on a peer the desk picks,
%% the store and the desk telling every `utilization-interval` of their
%% configurations, of the desk's two peers the store alone reached. Before
%% any connection, the desk holding no utilization, the compute answers
%% Unreachable. Once the spawn of the readings' check has connected them
%% and the store has told its utilization, it runs on the store, its value
%% the store's peers, the desk and the third node, and the store is the one
%% peer the desk holds a utilization of, the peer gone left out.
%%
%% Utilization answers the host's services' readings on the store, whose
%% measures run them, and none on the desk, whose do not. A regression
%% test, written after the code; the pick's rules over two peers and more
%% are pick_test_'s and ern_peer_tests', and the desk waits for the telling
%% by reading its utilizations at each interval, so that the telling's
%% coming within one interval is held by no time here
placed_test_() ->
    ern_harness:nodes_test({waits, 7}, fun placed/1).

placed(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    %% how often the store and the desk tell their utilizations, which the
    %% desk waits one of before its pick: the scenario's, and no bound
    Interval = 200,
    [ern_harness:edit(Dir, fun(Conf) -> Conf#{<<"utilization-interval">> => Interval} end)
     || Dir <- [Store, Desk]],
    ern_harness:edit(Store, fun(Conf) ->
                                Conf#{<<"measures">> => #{<<"cpu">> => #{}, <<"memory">> => #{},
                                                          <<"disk">> => #{}}}
                            end),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    ?assertEqual(0, (ern_harness:start(Desk, DeskProgram, ["place", integer_to_list(Interval)]))()),
    ern_harness:prints(Store, "readings there"),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    {StoreOut, StoreErr} = ern_harness:said(Store),
    %% report §12.5: the host's own reports are not written; a regression:
    %% the program the host runs for the cpu measure said, as the host
    %% ended, that the host had closed
    ?assertEqual(nomatch, string:find(StoreErr, "Erlang has closed")),
    [ern_harness:has(Out, Line)
     || Line <- ["before a telling: Left(Io.Unreachable)", "readings: Right",
                 "computed: Right([\"desk\", \"third\"])", "held: [\"store\"]",
                 "readings here: #(false, false, false)"]],
    ern_harness:has(StoreOut, "readings there: #(true, true, true)").

%% The program of three nodes of one build, each started with its name, and
%% of a node that lists no peer, built in Base: the `.erc`.
pick_build(Base) ->
    Dir = filename:join(Base, "pick"),
    ok = filelib:ensure_path(Dir),
    Source = "// Report §8.7, Appendix E.27: the spawner, which lists p1 and p2,\n"
             "// computes on the one it picks by the utilizations they told it; p1 and\n"
             "// p2, which list it, wait;\n"
             "// and a node that lists no peer picks none.\n"
             "\n"
             "export fn main() : Unit receiving Unit =\n"
             "    match Os.arguments {\n"
             "        [\"s\", interval] -> picks(Optional.withDefault(String.toInt(interval), 0))\n"
             "      | [\"alone\"] -> alone()\n"
             "      | _ -> {\n"
             "            Io.println(\"waiting\");\n"
             "            waits()\n"
             "        }\n"
             "    }\n"
             "\n"
             "// Where a compute ran: the node's arguments, which name it.\n"
             "fn ran() : List(String) = Os.arguments\n"
             "\n"
             "fn picks(interval : Int) : Unit receiving Unit = {\n"
             "    Io.println(\"before a telling: \" <> Io.show(Peer.computeAnywhere(ran,"
             " waitMs())));\n"
             "    let set1 = Peer.compute(\"p1\", fn() = Peer.setUtilization(0.9), waitMs());\n"
             "    Io.println(\"p1 set: \" <> Io.show(set1));\n"
             "    let set2 = Peer.compute(\"p2\", fn() = Peer.setUtilization(0.1), waitMs());\n"
             "    Io.println(\"p2 set: \" <> Io.show(set2));\n"
             "    heard(\"p1\", 0.9, interval);\n"
             "    heard(\"p2\", 0.1, interval);\n"
             "    let told = List.map(Peer.utilizations(), fn(#(name, utilization, _)) ="
             " #(name, utilization));\n"
             "    Io.println(\"utilizations: \" <> Io.show(told));\n"
             "    Io.println(\"utilization of p1: \" <> Io.show(Peer.utilization(\"p1\","
             " waitMs())));\n"
             "    let computed = List.map(List.range(1, 20), fn(_) = Peer.computeAnywhere(ran,"
             " waitMs()));\n"
             "    Io.println(\"computed: \" <> Io.show(List.unique(computed)));\n"
             "    Io.println(\"named: \" <> Io.show(Peer.compute(\"p1\", ran, waitMs())));\n"
             "    Io.println(\"now stop p2\");\n"
             "    let _ = Io.readLine();\n"
             "    let left = List.map(Peer.utilizations(), fn(#(name, _, _)) = name);\n"
             "    Io.println(\"after the loss: \" <> Io.show(left));\n"
             "    Io.println(\"computed alone: \" <> Io.show(Peer.computeAnywhere(ran,"
             " waitMs())))\n"
             "}\n"
             "\n"
             "// Report Appendix E.27: until the node holds the utilization given of the peer\n"
             "// named, read again every interval, the time between the peer's\n"
             "// tellings, at which alone the table changes.\n"
             "fn heard(name : String, utilization : Float, interval : Int) : Unit =\n"
             "    if List.any(Peer.utilizations(), fn(#(peer, held, _)) ="
             " peer == name && held == utilization) then\n"
             "        Unit\n"
             "    else {\n"
             "        Clock.sleep(interval);\n"
             "        heard(name, utilization, interval)\n"
             "    }\n"
             "\n"
             "fn alone() : Unit receiving Unit = {\n"
             "    Io.println(\"no peer: \" <> Io.show(Peer.computeAnywhere(ran, waitMs())));\n"
             "    Io.println(\"no utilization: \" <> Io.show(Peer.utilizations()))\n"
             "}\n"
             "\n"
             "// Until the node is stopped: a node waiting for ever is no deadlock.\n"
             "fn waits() : Unit receiving Unit =\n"
             "    receive {\n"
             "        _ -> waits()\n"
             "    }\n",
    ok = file:write_file(filename:join(Dir, "pick.ern"),
                         unicode:characters_to_binary([Source, ern_harness:wait_ms_declaration()])),
    0 = ern_harness:built([Dir]),
    filename:join(Dir, "pick.erc").

%% report §8.7, Appendix E.27, C: three nodes telling each other every
%% `utilization-interval`, the spawner far more often than p1 and p2, each
%% started with its name, which a compute of the node's arguments answers.
%% The spawner, listing p1 and p2 and heard from by neither before its
%% first operation, answers a compute that names no peer Unreachable. With
%% p1's utilization set high and p2's low by a compute on each,
%% `Peer.setUtilization` in the process it starts, the spawner's
%% utilizations show both, in the configuration's order, and p1's
%% utilization asked answers the number its program set.
%%
%% Every compute that names no peer runs on p2, the less busy of the two
%% the draw takes, each utilization aged by its teller's interval and not
%% the spawner's, by which it would mostly be too old, and `Peer.compute`
%% runs on the peer named, p1. With p2 stopped, its utilization is dropped
%% at the loss, which the spawner says, and a compute runs on p1, the one
%% peer left, taken as it is; and a node that lists no peer answers
%% NotListed and holds no utilization. A regression test, written after the
%% code; the spawner waits for each telling by reading its utilizations at
%% each interval, so that a telling's coming within one interval is held by
%% no time here, and the draw among more than two peers and the age of a
%% utilization are ern_peer_tests'
pick_test_() ->
    ern_harness:nodes_test({waits, 11}, fun pick/1).

pick(Base) ->
    Program = pick_build(Base),
    {Port1, Port2} = {ern_harness:free_port(), ern_harness:free_port()},
    S = ern_harness:made(Base, "s", none),
    P1 = ern_harness:made(Base, "p1", Port1),
    P2 = ern_harness:made(Base, "p2", Port2),
    Alone = ern_harness:made(Base, "alone", none),
    %% how often p1 and p2 tell, which the spawner waits one of for each,
    %% and how often the spawner does, by which their utilizations would be
    %% too old: the scenario's, and no bound
    {Interval, SpawnersInterval} = {200, 20},
    ern_harness:lists(S, [{"p1", P1, Port1}, {"p2", P2, Port2}]),
    [ern_harness:lists(Dir, [{"s", S, none}]) || Dir <- [P1, P2]],
    [ern_harness:edit(Dir, fun(Conf) -> Conf#{<<"utilization-interval">> => Ms} end)
     || {Dir, Ms} <- [{S, SpawnersInterval}, {P1, Interval}, {P2, Interval}]],
    Wait1 = ern_harness:start(P1, Program, ["p1"]),
    Wait2 = ern_harness:start(P2, Program, ["p2"]),
    [ern_harness:prints(Dir, "waiting") || Dir <- [P1, P2]],
    {SPort, WaitS} = ern_harness:started(S, Program, ["s", integer_to_list(Interval)]),
    ern_harness:prints(S, "now stop p2"),
    ern_harness:stop(P2, Wait2),
    ern_harness:says(S, "the peer p2 ended"),
    true = port_command(SPort, "go\n"),
    ?assertEqual(0, WaitS()),
    ern_harness:stop(P1, Wait1),
    ?assertEqual(0, (ern_harness:start(Alone, Program, ["alone"]))()),
    {Out, _} = ern_harness:said(S),
    [ern_harness:has(Out, Line)
     || Line <- ["before a telling: Left(Io.Unreachable)", "p1 set: Right(Unit)",
                 "p2 set: Right(Unit)", "utilizations: [#(\"p1\", 0.9), #(\"p2\", 0.1)]",
                 "utilization of p1: Right(0.9)", "computed: [Right([\"p2\"])]",
                 "named: Right([\"p1\"])", "after the loss: [\"p1\"]",
                 "computed alone: Right([\"p1\"])"]],
    {AloneOut, _} = ern_harness:said(Alone),
    [ern_harness:has(AloneOut, Line) || Line <- ["no peer: Left(Io.NotListed)",
                                                 "no utilization: []"]].

%% report §8.7, §11.2, Appendix E.23, Appendix G.6, G.7: a program's own test
%% of two nodes, `ern test --config-dir a` as a node. The harness makes two
%% directories as `ern config` makes them, `a` listening and listing `b`
%% under the service `pair`, and says in `pair.json` the port `b` listens on
%% and the load path `a` runs with; the test, in Ernest, writes `b`'s
%% `ernest.conf` listing `a`, starts `b` with `Os` on the same build, finds
%% and calls what it offers, and ends it with `ern stop`.
%%
%% A second test starts `b` with `Os` on a second build, whose `Msg` has
%% another constructor (second_build/1), and finds `OtherType` at its
%% service, the type it offers at having another hash. A third holds a
%% proxy for the service against the second build, whose process faults at
%% the first message, the fault reported as every fault is, and counted
%% against no case, the proxy being one its case started while it runs
%% (§11.8). A regression test, written after the code; it does not cover a
%% reload, whose end a program cannot see (§12.5: the signal carries
%% nothing back)
program_test_() ->
    ern_harness:nodes_test({waits, 30}, fun pair_program/1).

pair_program(Base) ->
    _ = peers(Base),
    second_build(Base),
    {PortA, PortB} = {ern_harness:free_port(), ern_harness:free_port()},
    A = ern_harness:made(Base, "a", PortA),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, PortB}]),
    ern_harness:edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"pair">> => [<<"b">>]}} end),
    Settings = #{<<"port">> => PortB,
                 <<"build">> => <<"build/pair.erc">>,
                 <<"second-build">> => <<"second-build/pair.erc">>},
    ok = file:write_file(filename:join(Base, "pair.json"), json:encode(Settings)),
    Command = lists:flatten([?ERN, " test --config-dir a build/pair.erc 2>&1"]),
    %% `ern` on the path, as the test starts it by its name (Appendix E.23)
    Path = filename:dirname(?ERN) ++ ":" ++ os:getenv("PATH"),
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", Command]}, {cd, Base}, {env, [{"PATH", Path}]},
                      exit_status, binary, stderr_to_stdout]),
    %% `ern test`'s steps, each given the harness's time for one wait
    %% (test/fixtures/peers/harness.ern): its node's start, and in each of
    %% its three tests the second node's start, the two files read, the key
    %% `ern config` prints and the file written before it, its stop and its
    %% end; a find and a call in the first, a find in the second, and in the
    %% third two calls through the proxy and the wait for the proxy's end
    {Status, Output} = ern_harness:collected(Port, 28),
    %% no case failed, and the job's count of its cases says so (report §11.2)
    ?assertEqual({0, nomatch}, {Status, binary:match(Output, <<": failed">>)}),
    ern_harness:has(binary_to_list(Output), "3 cases, 0 failed\n"),
    ern_harness:has(binary_to_list(Output),
                    "a second node made, started with Os, found, called and stopped:"
                    " passed"),
    ern_harness:has(binary_to_list(Output),
                    "a second node of another build, started with Os, offers at another"
                    " type: passed"),
    ern_harness:has(binary_to_list(Output),
                    "a proxy for a service offered at another type faults, and is"
                    " dead: passed"),
    ?assertMatch({match, _}, re:run(Output, "the process of Proxy\\.start:[0-9]+ faulted: the"
                                            " service pair is offered at another type")),
    ?assertNot(filelib:is_regular(filename:join(B, "ernest.pid"))).

%% Report §8.7: a second build of test/fixtures/peers/pair.ern, its `Msg` given
%% another constructor, so that its service's type has another hash, built in
%% Base/second-build with the harness's module it uses.
second_build(Base) ->
    {ok, Source} = file:read_file("fixtures/peers/pair.ern"),
    Declared = <<"export type Msg = Double(n : Int, reply : Reply(Int))">>,
    Changed = binary:replace(Source, Declared, <<Declared/binary, " | Halve(Int)">>),
    ?assertNotEqual(Source, Changed),
    Root = filename:join(Base, "second"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "pair.ern"), Changed),
    {ok, _} = file:copy("fixtures/peers/harness.ern", filename:join(Root, "harness.ern")),
    0 = ern_harness:built(["--source-root", Root, "--build-root",
                           filename:join(Base, "second-build"),
                           Root]).

%% A command run by /bin/sh to its end, as a person runs it: its status,
%% and what it wrote on its standard output, its standard error among it
%% where the command sends it there. The harness's time for one wait bounds
%% a failure, as ern_deployment_tests:job/2 bounds a job's. A host's `kill`,
%% `ps` or `mkfifo` is run by os:cmd, since it returns once its one call to
%% the system has, and waits on nothing a test runs.
finished(Command) ->
    (begun(Command))().

%% The same command started, and what waits for its end and answers what
%% finished/1 answers: one step.
begun(Command) ->
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", lists:flatten(Command)]}, exit_status, binary]),
    fun() ->
        {Status, Said} = ern_harness:collected(Port, 1),
        {Status, binary_to_list(Said)}
    end.

%% What a port the test opened writes next, or none where it writes nothing
%% within the harness's time for one wait: one step.
output(Port) ->
    ern_harness:step({output, Port}),
    receive {Port, {data, Data}} -> Data after ?WAIT_MS -> none end.

%% The process number in a node's ernest.pid.
pid(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.pid")),
    string:trim(binary_to_list(Text)).

%% report §8.7, §10, §12.6: a peer stopped stands
%% for a silent one. Before the silence ten thousand messages arrive, none
%% lost and none twice; the detector gives the peer up within 45 to 75
%% seconds of its last word, the monitor on its process giving one Down,
%% Unreachable with an empty site, a call waiting on it ending with None and
%% a callForever faulting, and the desk's own process untouched; the stopped
%% node, run again, learns of the loss too; and the address reaches its
%% process again. A regression test, written after the code; the one wait
%% here that is a time is the detector's own, which the test reads and
%% does not choose
silence_test_() ->
    ern_harness:nodes_test({waits, 8, ?DETECTOR_MS}, fun silence/1).

silence(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["silence"]),
    ern_harness:prints(Desk, "now stop the store"),
    _ = os:cmd("kill -STOP " ++ pid(Store)),
    true = port_command(DeskPort, "go\n"),
    %% the desk's word comes once the detector has given the store up
    ern_harness:prints(Desk, "now let the store run", ?WAIT_MS + ?DETECTOR_MS),
    _ = os:cmd("kill -CONT " ++ pid(Store)),
    ern_harness:says(Store, "the peer desk was lost"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {Out, _} = ern_harness:said(Desk),
    [ern_harness:has(Out, Line)
     || Line <- ["counted: Some(10000)", "silent: Unreachable \"\"", "the call: None",
                 "its caller: Returned", "its forever caller: Fault(\"callee is unreachable\")",
                 "own process: Some(0)", "again: Some(10000)"]],
    given_up_within_the_detectors_time(Out).

%% A proxy on the loopback in front of a node's listener at Target, which
%% relays what passes both ways and drops what passes the ways it is told:
%% `{drop, ToTarget, FromTarget}`, each a Boolean, and `heal`. It answers
%% its own port.
proxy(Target) ->
    {ok, Listener} = gen_tcp:listen(0, [binary, {ip, {127, 0, 0, 1}}, {active, false},
                                       {reuseaddr, true}]),
    {ok, Port} = inet:port(Listener),
    Proxy = spawn(fun() -> proxied(Listener, Target, {false, false}, []) end),
    ok = gen_tcp:controlling_process(Listener, Proxy),
    Proxy ! accept,
    {Port, Proxy}.

proxied(Listener, Target, Drops, Relays) ->
    receive
        accept ->
            Self = self(),
            spawn(fun() ->
                      case gen_tcp:accept(Listener) of
                          {ok, Socket} ->
                              ok = gen_tcp:controlling_process(Socket, Self),
                              Self ! {accepted, Socket};
                          {error, _} ->
                              ok
                      end
                  end),
            proxied(Listener, Target, Drops, Relays);
        {accepted, Near} ->
            {ok, Far} = gen_tcp:connect({127, 0, 0, 1}, Target, [binary, {active, false}]),
            {ToTarget, FromTarget} = Drops,
            Out = relay(Near, Far, ToTarget),
            In = relay(Far, Near, FromTarget),
            self() ! accept,
            proxied(Listener, Target, Drops, [{Out, to}, {In, from} | Relays]);
        {drop, ToTarget, FromTarget} ->
            [Relay ! {drop, case Way of to -> ToTarget; from -> FromTarget end}
             || {Relay, Way} <- Relays],
            proxied(Listener, Target, {ToTarget, FromTarget}, Relays);
        heal ->
            [Relay ! {drop, false} || {Relay, _} <- Relays],
            proxied(Listener, Target, {false, false}, Relays)
    end.

%% A relay of one way, which passes or drops what it reads, its close among
%% it, since a parted network carries nothing; it ends with its socket.
relay(From, To, Dropping) ->
    Relay = spawn(fun() -> receive go -> relayed(From, To, Dropping) end end),
    ok = gen_tcp:controlling_process(From, Relay),
    Relay ! go,
    Relay.

relayed(From, To, Dropping) ->
    case inet:setopts(From, [{active, once}]) of
        ok ->
            receive
                {tcp, From, Data} ->
                    Dropping orelse gen_tcp:send(To, Data),
                    relayed(From, To, Dropping);
                {tcp_closed, From} ->
                    Dropping orelse gen_tcp:close(To);
                {drop, Drop} ->
                    relayed(From, To, Drop)
            end;
        {error, _} ->
            ok
    end.

%% The port a node's `listen` names.
listen_port(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    [_, Port] = string:split(maps:get(<<"listen">>, json:decode(Text)), ":", trailing),
    binary_to_integer(Port).

%% Dir dials the peer of that name at the loopback's port.
readdressed(Dir, Name, Port) ->
    ern_harness:edit(Dir, fun(#{<<"peers">> := Peers} = Conf) ->
                              Conf#{<<"peers">> := [case Peer of
                                                        #{<<"name">> := Name} ->
                                                            Peer#{<<"network-address">> =>
                                                                      ern_harness:address(Port)};
                                                        _ ->
                                                            Peer
                                                    end || Peer <- Peers]}
                          end).

%% A listener on the loopback that takes connections and answers nothing.
answers_nothing() ->
    {Port, _} = nothing_answered(0),
    Port.

%% The same on Port, or on a port the host picks where it is 0, which a
%% node's ended start may have left in its kernel's wait: the port, and the
%% process that holds the listener and what it took, whose end closes them.
nothing_answered(Port) ->
    {ok, Listener} = gen_tcp:listen(Port, [binary, {ip, {127, 0, 0, 1}}, {active, false},
                                           {reuseaddr, true}]),
    {ok, Bound} = inet:port(Listener),
    Holder = spawn(fun() -> receive go -> held(Listener, []) end end),
    ok = gen_tcp:controlling_process(Listener, Holder),
    Holder ! go,
    {Bound, Holder}.

held(Listener, Sockets) ->
    {ok, Socket} = gen_tcp:accept(Listener),
    held(Listener, [Socket | Sockets]).

%% The listener and what it took closed, once their holder has ended.
stop_holding(Holder) ->
    MonitorRef = erlang:monitor(process, Holder),
    exit(Holder, kill),
    receive {'DOWN', MonitorRef, process, _, _} -> ok end.

%% The port a node's `listen` names.
listened(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    [_, Port] = string:split(maps:get(<<"listen">>, json:decode(Text)), <<":">>, trailing),
    binary_to_integer(Port).

%% report §8.7, §12.6: a network parted through
%% a proxy that drops what passes from the desk to the store: the store,
%% hearing nothing, gives the desk up within the detector's time and closes
%% the connection, so that the desk learns of the loss too, and what the
%% silence test holds of a loss holds; the proxy healed, the address reaches
%% its process again. A regression test, written after the code
parted_one_way_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:parted_one_way_test_", {waits, 8, ?DETECTOR_MS},
                           fun(Base) -> parted(Base, true, false, "closed") end).

%% report §8.7, §12.6: the same, the proxy
%% dropping what passes both ways, so that each node gives the other up by
%% its own detector. A regression test, written after the code
parted_both_ways_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:parted_both_ways_test_", {waits, 8, ?DETECTOR_MS},
                           fun(Base) -> parted(Base, true, true, "fell silent") end).

parted(Base, ToStore, FromStore, DeskSays) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    {ProxyPort, Proxy} = proxy(listen_port(Store)),
    readdressed(Desk, <<"store">>, ProxyPort),
    WaitStore = ern_harness:start(Store, StoreProgram, []),
    ern_harness:prints(Store, "offered"),
    {DeskPort, WaitDesk} = ern_harness:started(Desk, DeskProgram, ["silence"]),
    ern_harness:prints(Desk, "now stop the store"),
    Proxy ! {drop, ToStore, FromStore},
    true = port_command(DeskPort, "go\n"),
    %% the desk's word comes once a detector has given a node up
    ern_harness:prints(Desk, "now let the store run", ?WAIT_MS + ?DETECTOR_MS),
    Proxy ! heal,
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    ern_harness:stop(Store, WaitStore),
    {Out, Err} = ern_harness:said(Desk),
    {_, StoreErr} = ern_harness:said(Store),
    [ern_harness:has(Out, Line)
     || Line <- ["counted: Some(10000)", "silent: Unreachable \"\"", "the call: None",
                 "its forever caller: Fault(\"callee is unreachable\")", "own process: Some(0)",
                 "again: Some(10000)"]],
    ern_harness:has(StoreErr, "the peer desk was lost: it fell silent"),
    ern_harness:has(Err, "the peer store was lost: it " ++ DeskSays),
    given_up_within_the_detectors_time(Out).

%% report §8.7: a dial that nothing answers, to a
%% listener that takes the connection and says nothing, is given up after
%% the host's 7 seconds, and a find on that peer answers Unreachable, not
%% Timeout, though its time is longer. A regression test, written after the
%% code
dial_test_() ->
    ern_harness:nodes_test({waits, 3, ?DIAL_MS}, fun dial/1).

dial(Base) ->
    {_, DeskProgram} = peers(Base),
    {_, Desk} = store_and_desk(Base),
    readdressed(Desk, <<"store">>, answers_nothing()),
    %% the desk ends once the host has given its dial up
    {Port, _} = ern_harness:started(Desk, DeskProgram, ["dial"]),
    ?assertEqual(0, ern_harness:ended(Port, ?WAIT_MS + ?DIAL_MS)),
    {Out, _} = ern_harness:said(Desk),
    {match, [Seconds]} = re:run(Out, "dialed: Left\\(Io\\.Unreachable\\) after ([0-9]+)",
                                [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Seconds) >= 6),
    ?assert(list_to_integer(Seconds) =< 9).

%% The seconds the desk says the detector took, held to the detector's 45 to
%% 75 (report §12.6): no fewer than 44, the desk counting whole
%% seconds from just after the silence began, and no more than 80, the 75
%% and the test's own steps around it, the desk's read of its standard input
%% and the three Downs it waits for.
given_up_within_the_detectors_time(Out) ->
    {match, [Seconds]} = re:run(Out, "given up after: ([0-9]+)", [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Seconds) >= 44),
    ?assert(list_to_integer(Seconds) =< 80).

%% report §8.7, §6.2: a message above the host's buffer for a peer, sixteen
%% megabytes, sent to a process of a running peer: its send waits, the host
%% reporting the sender suspended, and returns; the message arrives whole,
%% and the next its sender sends arrives after it. A regression test,
%% written after the code; it does not show whether the host places the
%% message in its buffer whole or a part at a time, which the sender's wait
%% does not tell apart, nor a message larger than the peer's host can take
above_the_buffer_test_() ->
    ern_harness:nodes_test({waits, 8}, fun above_the_buffer/1).

above_the_buffer(Base) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    WaitDesk = ern_harness:start(Desk, Program, ["above"]),
    ern_harness:prints(Desk, "the host says the send waited"),
    ern_harness:prints(Store, "took the next"),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Store, WaitStore),
    {DeskOut, _} = ern_harness:said(Desk),
    {StoreOut, _} = ern_harness:said(Store),
    ?assertEqual(["sent 16777216 bytes", "sent the next", "the host says the send waited", ""],
                 string:split(DeskOut, "\n", all)),
    ?assertEqual(["offered", "took 16777216 bytes, whole: true", "took the next", ""],
                 string:split(StoreOut, "\n", all)).

%% report §8.7, §12.6: what waits for a peer that stands still. The store
%% stopped, a sender of the desk's sends it a quarter of a megabyte at a
%% time: the sends that return carry more than the buffer's 1 MB, since what
%% the connection took counts no longer, and the send after them waits, the
%% host reporting the sender suspended. Asked something each time the host
%% so reports, the sender serves it only after its send. The wait lasts
%% until the store is lost, no sooner than the detector's 45 seconds after
%% the stop, and the loss ends it: the sender goes on, and the desk says
%% the store was lost. The desk's program then ends, and the desk ends with
%% it while the store still stands still, the connection having let go at
%% its close of what the store never took.
%%
%% A regression test, written after the code; the one wait here that is a
%% time is the detector's own, which the test reads and does not choose. It
%% does not cover how late the loss may come where the buffer cannot drain,
%% a time the host decides; nor the end, while its peer stands still, of
%% the node that was dialed, the store here, nor an end by termination
%% meanwhile; nor a wait the peer ends by running again, a call, a find or
%% a spawn that waits so, nor a system process of the desk's that sends to
%% the store meanwhile
wait_ended_by_a_loss_test_() ->
    ern_harness:nodes_test({waits, 8, ?DETECTOR_MS}, fun wait_ended_by_a_loss/1).

wait_ended_by_a_loss(Base) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["wait"]),
    ern_harness:prints(Desk, "found"),
    StoreNumber = pid(Store),
    _ = os:cmd("kill -STOP " ++ StoreNumber),
    try
        true = port_command(DeskInput, "go\n"),
        ern_harness:prints(Desk, "the host says the sender waits in a send"),
        %% the desk's word comes once the loss has ended the wait, its
        %% numbers the summary's last line
        ern_harness:prints(Desk, "given up after: ", ?WAIT_MS + ?DETECTOR_MS),
        ern_harness:says(Desk, "the peer store was lost: it fell silent"),
        Out = ern_harness:written(Desk, out),
        [Returned, During] = [list_to_integer(Count)
                              || Part <- ["returned before the wait", "served after it"],
                                 {match, [Count]} <- [re:run(Out, Part ++ ": ([0-9]+)",
                                                             [{capture, all_but_first, list}])]],
        ?assert(Returned * 262144 > 1048576),
        ern_harness:has(Out, "the sender went on after send " ++ integer_to_list(Returned + 1)),
        ?assert(During >= 1),
        {match, [Seconds]} = re:run(Out, "given up after: ([0-9]+)",
                                    [{capture, all_but_first, list}]),
        %% no fewer than 44, as given_up_within_the_detectors_time/1 counts
        ?assert(list_to_integer(Seconds) >= 44),
        %% the desk's program has ended, and the desk ends with it while the
        %% store still stands still
        ?assertEqual(0, WaitDesk())
    after
        os:cmd("kill -CONT " ++ StoreNumber)
    end,
    ern_harness:stop(Store, WaitStore).

%% report Appendix E.27, §8.7: where more waits to be sent to the peer than
%% §8.7 states, a spawn waits as a send waits, before its wait for the peer
%% begins and after that wait has ended, and answers only once it waits so
%% no longer. The store stopped and a sender of the desk's waiting in a
%% send to it, as wait_ended_by_a_loss/1 has it, a second process of the
%% desk's spawns on the store, given a second. Its monitor of the store's
%% gateway, its frame, or its demonitor once its time has run out, waits in
%% the host's send until the loss, so that its answer, `Timeout` or
%% `Unreachable` by which one waited, comes later than its time and the
%% runtime's step, and no sooner than the detector's 45 seconds after the
%% stop.
%%
%% A regression test, written after the code; the one wait here that is a
%% time is the detector's own, which the test reads and does not choose. It
%% does not cover a find, a compute or a utilization, which send the same
%% way, nor a spawn whose wait the peer ends by running again.
spawn_waits_in_its_send_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:spawn_waits_in_its_send_test_",
                           {waits, 7, ?DETECTOR_MS},
                           fun(Base) -> waited_in_its_send(Base, "spawn") end).

%% report §6.6, §8.7: where more waits to be sent to the callee's node than
%% §8.7 states, a call waits as a send waits there, before its wait for the
%% answer begins and after that wait has ended, and returns only once it
%% waits so no longer. The store stopped and a sender of the desk's waiting
%% in a send to it, as wait_ended_by_a_loss/1 has it, a second process of
%% the desk's calls the store's sink, given a second. Its monitor of the
%% sink, its first note, or its second note once its time has run out,
%% waits in the host's send until the loss, so that it returns `None` later
%% than its time, and no sooner than the detector's 45 seconds after the
%% stop.
%%
%% A regression test, written after the code; the one wait here that is a
%% time is the detector's own, which the test reads and does not choose. It
%% does not cover `Address.callForever`, whose wait has no time of its own
%% and so ends at the loss whether or not a send of its waited, nor a call
%% whose wait the callee's node ends by running again.
call_waits_in_its_send_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:call_waits_in_its_send_test_", {waits, 7, ?DETECTOR_MS},
                           fun(Base) -> waited_in_its_send(Base, "call") end).

%% The store stopped and the desk's sender waiting, the desk's ask of the
%% store, Ask a spawn or a call given a second, which says what it answered
%% and when, once the loss has ended its wait.
waited_in_its_send(Base, Ask) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, [Ask]),
    ern_harness:prints(Desk, "found"),
    StoreNumber = pid(Store),
    _ = os:cmd("kill -STOP " ++ StoreNumber),
    try
        true = port_command(DeskInput, "go\n"),
        %% the desk's word comes once the loss has ended the ask's wait
        ern_harness:prints(Desk, "the " ++ Ask ++ " took: ", ?WAIT_MS + ?DETECTOR_MS),
        ern_harness:says(Desk, "the peer store was lost: it fell silent"),
        Out = ern_harness:written(Desk, out),
        %% a spawn's `Timeout` or `Unreachable`, by which signal waited, and
        %% a call's `None`
        ern_harness:has(Out, "the " ++ Ask ++ " answered: " ++ answered_in_the_wait(Ask)),
        [Began, Took] = [list_to_integer(Ms)
                         || Part <- [" began after", " took"],
                            {match, [Ms]} <- [re:run(Out, "the " ++ Ask ++ Part ++ ": ([0-9]+) ms",
                                                     [{capture, all_but_first, list}])]],
        %% later than its time and the runtime's step, which ends at the
        %% latest with a dial's 7 seconds: it waited as a send waits
        ?assert(Took > 1000 + ?DIAL_MS),
        %% only once it waits so no longer, at the loss: no sooner than 44
        %% seconds after the stop, as given_up_within_the_detectors_time/1
        %% counts
        ?assert(Began + Took >= 44000),
        ?assertEqual(0, WaitDesk())
    after
        os:cmd("kill -CONT " ++ StoreNumber)
    end,
    ern_harness:stop(Store, WaitStore).

answered_in_the_wait("spawn") -> "Left(Io.";
answered_in_the_wait("call") -> "None".

%% report Appendix E.27, §8.7: a telling and a utilization's answer never
%% wait as a send waits; where more already waits for the peer than §8.7
%% states, neither is sent. The store stopped and a sender of the desk's
%% waiting in a send to it, as wait_ended_by_a_loss/1 has it, the desk's
%% gateway passes its next telling, which the third node reads in its
%% utilizations, and goes on serving the third node: its find and its
%% utilization of the desk answer, and so does the desk's spawn on it,
%% whose answer comes through the desk's gateway.
%%
%% A regression test, written after the code. It does not cover a
%% utilization's answer that is not sent, whose asker waits to its time,
%% nor a telling or an answer behind a dial, nor the runtime's other
%% processes that serve more than one peer.
gateway_waits_on_no_peer_test_() ->
    ern_harness:nodes_test({waits, 10}, fun gateway_waits_on_no_peer/1).

gateway_waits_on_no_peer(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = buffer_nodes_and_third(Base),
    %% how often the desk tells its peers how busy it is, which the third
    %% node waits one of between its reads of its utilizations: the
    %% scenario's, and no bound
    Interval = 200,
    ern_harness:edit(Desk, fun(Conf) -> Conf#{<<"utilization-interval">> => Interval} end),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    {ThirdInput, WaitThird} = ern_harness:started(Third, Program,
                                                  ["third", integer_to_list(Interval)]),
    ern_harness:prints(Third, "ready"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["gateway"]),
    ern_harness:prints(Desk, "found"),
    StoreNumber = pid(Store),
    _ = os:cmd("kill -STOP " ++ StoreNumber),
    try
        true = port_command(DeskInput, "go\n"),
        ern_harness:prints(Desk, "the host says the sender waits in a send"),
        true = port_command(ThirdInput, "go\n"),
        ern_harness:prints(Third, "utilization: "),
        true = port_command(DeskInput, "go\n"),
        ern_harness:prints(Desk, "spawned on the third: "),
        ThirdOut = ern_harness:written(Third, out),
        [ern_harness:has(ThirdOut, Line)
         || Line <- ["the desk told after its sender waited", "found: Right(",
                     "utilization: Right("]],
        ern_harness:has(ern_harness:written(Desk, out), "spawned on the third: Right(")
    after
        os:cmd("kill -CONT " ++ StoreNumber)
    end,
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report §6.9, §8.7: a kill waits on no peer. The desk's connection to the
%% store held back, so that nothing leaves the host's buffer for the store
%% as nothing leaves it for a stopped peer once the kernel's buffers are
%% full, and a sender of the desk's waiting in a send to it, a process of
%% the desk's that waits in a call of the store's sink, whose request the
%% store took first, is killed, and then an idle process of the desk's:
%% each ends while the connection is held back, the call's note that it is
%% over placed for the store without a wait. A regression test, written
%% after the code: it does not cover a peer's kill, which comes as a frame,
%% nor the kill of a compute's process, whose note goes the same way, nor a
%% peer that is stopped, whose wait the kernel's buffers put off.
%%
%% Report §12.9: the kill is a message to the launch's killer, which reads
%% the caller's call before it ends the caller, and so places the note.
killer_waits_on_no_peer_test_() ->
    ern_harness:nodes_test({waits, 9}, fun killer_waits_on_no_peer/1).

killer_waits_on_no_peer(Base) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["kill"]),
    ern_harness:prints(Desk, "found"),
    ern_harness:prints(Store, "holds a call"),
    true = port_command(DeskInput, "go\n"),
    ern_harness:prints(Desk, "the host says the sender waits in a send"),
    ern_harness:prints(Desk, "the caller ended: "),
    ern_harness:prints(Desk, "the idle process ended: "),
    Out = ern_harness:written(Desk, out),
    [ern_harness:has(Out, Line) || Line <- ["the caller ended: Killed",
                                            "the idle process ended: Killed"]],
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Store, WaitStore).

%% report §6.9, §8.7: the reaper waits on no peer. The desk's connection to
%% the store held back and a sender of the desk's waiting in a send to it,
%% as killer_waits_on_no_peer/1 has them, a process of the desk's asks for
%% a monitor of the store's sink, which the reaper makes with the host;
%% once the reaper has taken the ask, the desk spawns a process monitored
%% with its spawn, which returns, and its Down comes while the connection
%% is held back. A regression test, written after the code: it does not
%% cover the reaper's second note of a call, which it sends for a caller
%% the host ended, nor its answer to a compute's caller.
reaper_waits_on_no_peer_in_a_monitor_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:reaper_waits_on_no_peer_in_a_monitor_test_",
                           {waits, 7}, fun(Base) -> reaper_waited(Base, "monitor") end).

%% report §6.9, §8.7: the same, the ask the end of a monitor of the store's
%% sink that the process made while the connection ran. A regression test,
%% with what the monitor's does not cover.
reaper_waits_on_no_peer_in_a_demonitor_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:reaper_waits_on_no_peer_in_a_demonitor_test_",
                           {waits, 7}, fun(Base) -> reaper_waited(Base, "demonitor") end).

%% The desk's ask of the reaper, Ask a monitor or a demonitor of the store's
%% sink, and the Down of the process the desk spawns once the reaper has
%% taken it.
reaper_waited(Base, Ask) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    WaitDesk = ern_harness:start(Desk, Program, [Ask]),
    ern_harness:prints(Desk, "found"),
    ern_harness:prints(Desk, "the host says the sender waits in a send"),
    ern_harness:prints(Desk, "the local process ended: "),
    ern_harness:has(ern_harness:written(Desk, out), "the local process ended: Returned"),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Store, WaitStore).

%% report §12.7, §8.7: the exchange waits on no peer. The store and the
%% third node bare, the desk spawns the store's sink there, its code
%% carried by the exchange, and holds its own exchange back while the store
%% asks it for the reach of a function the store lacks. The desk's
%% connection to the store then held back and a sender of the desk's
%% waiting in a send to it, as killer_waits_on_no_peer/1 has them, the desk
%% lets its exchange go, which answers the store; and the desk's spawn on
%% the third node of a function the third node lacks, whose exchange the
%% desk's exchange answers, starts while the connection is held back. A
%% regression test, written after the code: it does not cover the
%% exchange's other frames, the lacks and a code frame, nor a spawn's
%% answer the exchange gives, which wait the same way.
exchange_waits_on_no_peer_test_() ->
    ern_harness:nodes_test({waits, 9}, fun exchange_waits_on_no_peer/1).

exchange_waits_on_no_peer(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = buffer_nodes_and_third(Base),
    WaitStore = ern_harness:bare_started(Store, []),
    ern_harness:says(Store, "listening on "),
    WaitThird = ern_harness:bare_started(Third, []),
    ern_harness:says(Third, "listening on "),
    WaitDesk = ern_harness:start(Desk, Program, ["exchange"]),
    ern_harness:prints(Desk, "the store asked"),
    ern_harness:prints(Desk, "the host says the sender waits in a send"),
    ern_harness:prints(Desk, "spawned on the third: "),
    ern_harness:has(ern_harness:written(Desk, out), "spawned on the third: Right("),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report Appendix E.21, §8.7: a process the host holds in a send to
%% another node that takes no more is Suspended. The desk's connection to
%% the store held back and a sender of the desk's waiting in a send to it,
%% as killer_waits_on_no_peer/1 has them, the desk reads the sender's
%% status: nothing leaves the host's buffer for the store until the desk
%% lets the connection go, so the sender is held while the desk reads it.
%%
%% It does not cover a call, a find, a spawn, a compute or a utilization
%% that waits as a send waits, which the host holds alike, nor a peer that
%% is stopped, whose wait the kernel's buffers put off, nor the sender once
%% the connection is let go.
sender_held_in_its_send_test_() ->
    ern_harness:nodes_test({waits, 7}, fun sender_held_in_its_send/1).

sender_held_in_its_send(Base) ->
    Program = buffer_build(Base),
    {Store, Desk} = buffer_nodes(Base),
    WaitStore = ern_harness:start(Store, Program, ["sink"]),
    ern_harness:prints(Store, "offered"),
    WaitDesk = ern_harness:start(Desk, Program, ["status"]),
    ern_harness:prints(Desk, "found"),
    ern_harness:prints(Desk, "the host says the sender waits in a send"),
    ern_harness:prints(Desk, "the sender's activity: "),
    ern_harness:has(ern_harness:written(Desk, out),
                    "the sender's activity: Some(Process.Suspended)"),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Store, WaitStore).

%% report §6.9, §6.6, §8.7, §12.2: the answer to a call is not overtaken by
%% the callee's Down. A caller of the store's waits on the desk's callee.
%% Once the callee holds the question, the desk's connection to the store is
%% held back, so that nothing leaves the host's buffer for the store, and the
%% callee answers behind a megabyte that already waits there, its small
%% answer placed not at all. The desk kills the callee, its own monitor told
%% Killed while the connection is held back, and then lets the connection
%% go: the caller gets the answer, whole.
%%
%% The answer and the caller's Down cross one connection. Where a death's
%% reason is no immediate term of the host's, as a kill's `{ern, killed}` is
%% not, the host sends the Down for another node only once the dying
%% process's send is placed whole. Where it is one, an atom among them, the
%% host places the Down at once, before the answer's rest, and the caller
%% gets None: this test fails the day a kill's reason is an immediate term.
%%
%% A regression test, written after the code. It does not cover a peer that
%% is stopped, whose wait the kernel's buffers put off, nor callForever,
%% which reads the same Down, nor a callee that faults or ends with its
%% program while its answer waits.
answer_behind_the_buffer_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:answer_behind_the_buffer_test_", {waits, 6},
                           fun(Base) -> answered_and_killed(Base, "small",
                                                            "Some(8 bytes, whole: true)") end).

%% report §6.9, §6.6, §8.7, §12.2: the same, the callee's answer above the
%% buffer and placed in part when the callee is killed. A regression test,
%% with what the first does not cover.
answer_above_the_buffer_test_() ->
    ern_harness:nodes_test("ern_nodes_tests:answer_above_the_buffer_test_", {waits, 6},
                           fun(Base) ->
                               answered_and_killed(Base, "large",
                                                   "Some(16777216 bytes, whole: true)")
                           end).

%% The desk's callee killed while its answer, Answer, waits, and what the
%% store's caller got, Got.
answered_and_killed(Base, Answer, Got) ->
    Program = buffer_build(Base),
    {Store, Desk, _} = watched_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    WaitDesk = ern_harness:start(Desk, Program, ["answered", Answer]),
    ern_harness:prints(Desk, "the callee ended: "),
    ern_harness:prints(Store, "the store's caller got: "),
    DeskOut = ern_harness:written(Desk, out),
    [ern_harness:has(DeskOut, Line)
     || Line <- ["the host says the callee waits in a send", "the callee ended: Killed"]],
    ern_harness:has(ern_harness:written(Store, out),
                    "the store's caller got: " ++ Got ++ " after "),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Store, WaitStore).

%% report §8.7, §6.9: a process that dies while what it sends waits to be
%% placed has sent it, here one that dies with Killed, and the Downs its
%% death gives watchers on other nodes are sent only once it is placed
%% whole. The desk's connection
%% to the store held back, so that nothing leaves the host's buffer for the
%% store, a sender of the desk's waits in its send of a message above the
%% buffer, part of it placed, and a second in its send of a small one, none
%% of it placed. Each is killed, and then an idle process, the desk's own
%% monitors told Killed while the connection is held back.
%%
%% The third node's watcher monitors the three, and is told the idle
%% process's Down while it has none of the senders'. Once the connection
%% goes, the store takes each message whole, and the third's watcher is told
%% each sender's Down, Killed.
%%
%% The evidence for "only once": the idle process, killed after the senders
%% and monitored from no node whose buffer is full, has its Down said at the
%% third node while the senders' are not. Under the code their absence is no
%% race, since nothing of theirs is sent while the connection is held back,
%% so the test cannot fail on a time. Its power to see a Down sent at once
%% rests on the third node's deliveries of the Downs, which run side by
%% side: a sender's Down sent at once, before the idle process's, could
%% still be said after it, and the test would not see it.
%%
%% A regression test, written after the code. It does not cover a peer that
%% is stopped, nor a peer's kill, which comes as a frame, nor a death other
%% than a kill; a node's end waits for no send, which end_waits_for_no_send
%% holds (§8.6).
killed_sender_has_sent_test_() ->
    ern_harness:nodes_test({waits, 12}, fun killed_sender_has_sent/1).

killed_sender_has_sent(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    WaitThird = offering(Third, Program, "watcher"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["sent"]),
    ern_harness:prints(Desk, "the idle process ended: "),
    ern_harness:prints(Third, "the third saw the idle process: "),
    ThirdOut = ern_harness:written(Third, out),
    [?assertEqual(nomatch, string:find(ThirdOut, "the third saw the " ++ Sender))
     || Sender <- ["large sender", "small sender"]],
    ern_harness:has(ThirdOut, "the third saw the idle process: Killed"),
    DeskOut = ern_harness:written(Desk, out),
    [ern_harness:has(DeskOut, Line)
     || Line <- ["the host says the large sender waits in a send",
                 "the host says the small sender waits in a send",
                 "the large sender ended: Killed", "the small sender ended: Killed",
                 "the idle process ended: Killed"]],
    true = port_command(DeskInput, "go\n"),
    ern_harness:prints(Store, "took 16777216 bytes, whole: true"),
    ern_harness:prints(Store, "took the next"),
    ern_harness:prints(Third, "the third saw the large sender: Killed"),
    ern_harness:prints(Third, "the third saw the small sender: Killed"),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report §8.7, §6.9: a Down that a death gives a watcher on another node
%% may wait in the buffer for that node, and those of the same death for
%% other nodes behind it, until the connection has taken enough; a Down to a
%% watcher on the dead process's own node waits on no peer.
%%
%% A process of the desk's in no send, monitored by the store's watcher,
%% then the third node's, then the desk itself, faults while the desk's
%% connection to the store is held back and a megabyte waits for the store.
%% The desk's monitor is told the Fault and its cause while the connection
%% is held back, and once it goes, the store's watcher and the third's are
%% told too. The sentence says "may", so the test holds the bound and not
%% the wait: the third's watcher is told at the latest once the store takes
%% again.
%%
%% A regression test, written after the code. It does not show the third's
%% Down waiting, which turns on the host's tree of the process's monitors
%% (the log's *A Down Follows the Send*), nor a loss in place of the take.
fault_down_behind_the_buffer_test_() ->
    ern_harness:nodes_test({waits, 9}, fun fault_down_behind_the_buffer/1).

fault_down_behind_the_buffer(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    WaitThird = offering(Third, Program, "watcher"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["faulted"]),
    Faulted = "Fault(\"the faulting process faulted\")",
    ern_harness:prints(Desk, "the faulting process ended: "),
    ern_harness:has(ern_harness:written(Desk, out), "the faulting process ended: " ++ Faulted),
    true = port_command(DeskInput, "go\n"),
    ern_harness:prints(Third, "the third saw the faulting process: "),
    ern_harness:prints(Store, "the store saw the faulting process: "),
    ern_harness:has(ern_harness:written(Third, out),
                    "the third saw the faulting process: " ++ Faulted),
    ern_harness:has(ern_harness:written(Store, out),
                    "the store saw the faulting process: " ++ Faulted),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report §8.7: the Downs that a death gives watchers on other nodes are
%% sent once a loss has dropped what the dead process had not placed. The
%% desk's connection to the store held back, a sender of the desk's waits in
%% its send of a message above the buffer, part of it placed, and is killed.
%% The desk then loses the connection, by ending the process of the host's
%% that writes it, which the host's supervisor of the connection reports on
%% the desk's standard error: both nodes say the loss, the third node's
%% watcher is told the sender's Down, Killed, and the sink, asked over a
%% connection the ask opens again, has taken nothing.
%%
%% The ask goes once the third's watcher has the Down, which the host sends
%% only after the sender's exit has ended its send, so nothing of the
%% message can follow the ask; and the sink takes in order what reached it
%% before the loss and the ask after it.
%%
%% A regression test, written after the code. It does not cover a loss the
%% detector finds, which ends the wait the same way, only later, nor a peer
%% that is stopped.
lost_sender_down_test_() ->
    ern_harness:nodes_test({waits, 11}, fun lost_sender_down/1).

lost_sender_down(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    WaitThird = offering(Third, Program, "watcher"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["lost"]),
    ern_harness:prints(Desk, "the large sender ended: "),
    ern_harness:says(Desk, "the peer store was lost: it closed"),
    ern_harness:says(Store, "the peer desk was lost: it closed"),
    ern_harness:prints(Third, "the third saw the large sender: "),
    ern_harness:has(ern_harness:written(Third, out), "the third saw the large sender: Killed"),
    ern_harness:has(ern_harness:written(Desk, out), "the large sender ended: Killed"),
    true = port_command(DeskInput, "go\n"),
    ern_harness:prints(Desk, "the sink has taken: "),
    ern_harness:has(ern_harness:written(Desk, out), "the sink has taken: Some(0)"),
    ?assertEqual(nomatch, string:find(ern_harness:written(Store, out), "took ")),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report §6.6, §8.7: where the callee is on another node, its death ends a
%% call's wait when a Down to the caller would be sent, which may wait on a
%% third node; where it is on the caller's own node, the wait ends at once.
%% A caller of the third node's and one of the desk's wait on the desk's
%% callee. The desk's connection to the store held back, the callee sends
%% the store a message above the buffer, waits in its send, and is killed:
%% the desk's caller gets None while the connection is held back, and once
%% the connection goes, the third's caller gets None, at the latest then.
%%
%% A regression test, written after the code. It does not show the third's
%% wait lasting while the connection is held back, an absence only a time
%% would show, nor callForever, nor a loss.
call_from_a_third_node_test_() ->
    ern_harness:nodes_test({waits, 9}, fun call_from_a_third_node/1).

call_from_a_third_node(Base) ->
    Program = buffer_build(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    WaitThird = offering(Third, Program, "watcher"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["called"]),
    ern_harness:prints(Desk, "the callee ended: "),
    ern_harness:prints(Desk, "the desk's caller got: "),
    DeskOut = ern_harness:written(Desk, out),
    [ern_harness:has(DeskOut, Line)
     || Line <- ["the host says the callee waits in a send", "the callee ended: Killed",
                 "the desk's caller got: None after "]],
    true = port_command(DeskInput, "go\n"),
    ern_harness:prints(Third, "the third's caller got: "),
    ern_harness:has(ern_harness:written(Third, out), "the third's caller got: None after "),
    ern_harness:stop(Desk, WaitDesk),
    ern_harness:stop(Third, WaitThird),
    ern_harness:stop(Store, WaitStore).

%% report §8.6, §8.7, §12.6, §6.9: a node's end waits for no send. The
%% desk's connection to the store held back by a process of the host's, a
%% sender of the desk's waits in its send of 28 MB to the store's sink,
%% watched from the store and the third node, and the desk's program
%% returns. The connection is let go once the third's watcher is told that
%% an idle process of the desk's died, so once the desk's processes have.
%%
%% The store takes the message whole or none of it, and its watcher is told
%% the sender's ProgramEnd exactly where it takes it, and else Unreachable;
%% the third's watcher is told the sender's Down once, ProgramEnd or
%% Unreachable, and the idle process's ProgramEnd. Both peers say the desk
%% ended, and the desk exits 0. Which side comes is the host's race, not
%% asserted: the store took nothing in 9 of the test's first 11 runs, and
%% the third's watcher was told Unreachable in 8; in 35 of 37 runs at 28 MB
%% before the test was written, the store took nothing.
%%
%% Report §6.6: two callers of the third's wait on the sender. The call
%% given the harness's time for one wait returns None before it, and the
%% one given none faults as the third's watcher was told, `callee ended
%% with its program` for ProgramEnd and `callee is unreachable` for
%% Unreachable.
%%
%% A regression test, written after the report said it. It does not cover
%% a peer that falls silent during the end, an `Os.exit` or a termination,
%% nor what waits for several peers at once.
end_waits_for_no_send_test_() ->
    ern_harness:nodes_test({waits, 19}, fun end_waits_for_no_send/1).

end_waits_for_no_send(Base) ->
    Program = ending_build(Base),
    Pipe = held_pipe(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    {StoreInput, WaitStore} = ern_harness:started(Store, Program, ["store"]),
    ern_harness:prints(Store, "offered"),
    WaitThird = offering(Third, Program, "third"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program,
                                                ["desk", "ended", sent_bytes(), Pipe]),
    ern_harness:prints(Desk, "the host says the sender waits in a send"),
    true = port_command(DeskInput, "end\n"),
    ern_harness:prints(Third, "the third saw the idle process: "),
    let_go(Pipe),
    ?assertEqual(0, WaitDesk()),
    [ern_harness:says(Dir, "the peer desk ended") || Dir <- [Store, Third]],
    ern_harness:prints(Store, "the store saw the sender: "),
    [ern_harness:prints(Third, Part) || Part <- ["the third saw the sender: ",
                                                 "the third saw the forever caller: ",
                                                 "the third's caller got: "]],
    true = port_command(StoreInput, "count\n"),
    ern_harness:prints(Store, "the sink has taken: "),
    ern_harness:stop(Store, WaitStore),
    ern_harness:stop(Third, WaitThird),
    [{StoreOut, _}, {ThirdOut, _}, _] = [ern_harness:said(Dir) || Dir <- [Store, Third, Desk]],
    taken_where_told(StoreOut, "the sender", "ProgramEnd"),
    ?assertEqual(["ProgramEnd"], said_after(ThirdOut, "the third saw the idle process: ")),
    [Reason] = said_after(ThirdOut, "the third saw the sender: "),
    ?assertEqual([forever_fault(Reason)],
                 said_after(ThirdOut, "the third saw the forever caller: ")),
    [Got] = said_after(ThirdOut, "the third's caller got: "),
    {match, [Ms]} = re:run(Got, "^None after ([0-9]+) ms$", [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Ms) < ?WAIT_MS).

%% Report §6.6: the fault of a call with no time on a process of another
%% node that ended with that node's program, its monitor told Reason.
forever_fault("ProgramEnd") ->
    "Fault(\"callee ended with its program\")";
forever_fault("Unreachable") ->
    "Fault(\"callee is unreachable\")".

%% report §8.6, §8.7, §12.1, §6.9: a node's end waits for no send where a
%% fault the runtime finds ends the program. Under a terminal, the desk's
%% connection to the store held back, its entry process waits in its send
%% of 28 MB to the store's sink, watched from the store and the third node,
%% and is given keys that are not UTF-8. The connection is let go once the
%% third's watcher is told that an idle process of the desk's died.
%%
%% The store takes the message whole or none of it, and its watcher is told
%% the fault with its cause exactly where it takes it, and else
%% Unreachable; the third's watcher is told the fault or Unreachable, once,
%% never ProgramEnd, and the idle process's ProgramEnd. Both peers say the
%% desk ended, and the desk reports the fault and exits 1. The store took
%% nothing in 9 of the test's first 11 runs, and the third's watcher was
%% told Unreachable in 8.
%%
%% A regression test, written after the report said it. It does not cover
%% a fault the entry process raises itself, nor a fault in another process.
faulted_end_waits_for_no_send_test_() ->
    ern_harness:nodes_test({waits, 16}, fun faulted_end_waits_for_no_send/1).

faulted_end_waits_for_no_send(Base) ->
    Program = ending_build(Base),
    Pipe = held_pipe(Base),
    {Store, Desk, Third} = watched_nodes(Base),
    {StoreInput, WaitStore} = ern_harness:started(Store, Program, ["store"]),
    ern_harness:prints(Store, "offered"),
    WaitThird = offering(Third, Program, "third"),
    WaitDesk = under_a_terminal(["exec ", ?ERN, " run --config-dir ", Desk, " ", Program,
                                 " desk faulted ", sent_bytes(), " ", Pipe],
                                [{expect, "the host says the entry process waits in a send"},
                                 {send, "ff"}]),
    ern_harness:prints(Third, "the third saw the idle process: "),
    let_go(Pipe),
    {Status, Data, Unmet} = WaitDesk(),
    ?assertEqual({1, []}, {Status, Unmet}),
    Cause = "the standard input is not UTF-8",
    ern_harness:has(binary_to_list(Data), "Ending.main faulted: " ++ Cause),
    [ern_harness:says(Dir, "the peer desk ended") || Dir <- [Store, Third]],
    ern_harness:prints(Store, "the store saw the entry process: "),
    ern_harness:prints(Third, "the third saw the entry process: "),
    true = port_command(StoreInput, "count\n"),
    ern_harness:prints(Store, "the sink has taken: "),
    ern_harness:stop(Store, WaitStore),
    ern_harness:stop(Third, WaitThird),
    [{StoreOut, _}, {ThirdOut, _}] = [ern_harness:said(Dir) || Dir <- [Store, Third]],
    Faulted = "Fault(\"" ++ Cause ++ "\")",
    taken_where_told(StoreOut, "the entry process", Faulted),
    ?assertEqual(["ProgramEnd"], said_after(ThirdOut, "the third saw the idle process: ")),
    [Reason] = said_after(ThirdOut, "the third saw the entry process: "),
    ?assert(lists:member(Reason, [Faulted, "Unreachable"])).

%% report §8.7, §12.6, §6.6, Appendix E.27: a peer that connects while the
%% node stops. The desk's connection to the store held back, so that its
%% end waits for the store, the desk hands the third node an echo it offers
%% and an idle process, which the third's watcher monitors, and a late node
%% fetches them there. The desk's program returns.
%%
%% The third, connected all along, asks the desk to find its echo, and is
%% told Unreachable, an answer that comes once the desk's run has ended, so
%% once the desk stops. Only then does the late node dial the desk, which
%% opens a connection, over which the desk tells it nothing, so it holds no
%% utilization of the desk's: how busy the desk is, a find, a spawn and a
%% compute answer Unreachable, a call of the echo None, and a monitor of the
%% idle process gives Unknown. Once the late node has asked, the third asks
%% how busy the desk is, and is told Unreachable.
%%
%% Once the connection to the store is let go and the desk has stopped, the
%% late node says it lost the desk, the store and the third that the desk
%% ended, and a monitor the late node makes then gives Unreachable.
%%
%% A regression test, written after the report said it. It does not cover
%% a call of the late node's waiting from before the end, nor a peer that
%% dials, or a utilization asked, between the processes' deaths and the
%% flush's end.
connected_while_stopping_test_() ->
    ern_harness:nodes_test({waits, 24}, fun connected_while_stopping/1).

connected_while_stopping(Base) ->
    Program = ending_build(Base),
    Pipe = held_pipe(Base),
    {Store, Desk, Third, Late} = window_nodes(Base),
    WaitStore = offering(Store, Program, "store"),
    {ThirdInput, WaitThird} = ern_harness:started(Third, Program, ["third"]),
    ern_harness:prints(Third, "offered"),
    {LateInput, WaitLate} = ern_harness:started(Late, Program, ["late"]),
    ern_harness:prints(Late, "ready"),
    {DeskInput, WaitDesk} = ern_harness:started(Desk, Program, ["desk", "window", Pipe]),
    ern_harness:prints(Desk, "held"),
    true = port_command(LateInput, "fetch\n"),
    ern_harness:prints(Late, "fetched"),
    true = port_command(DeskInput, "end\n"),
    ern_harness:prints(Third, "the third saw the idle process: "),
    true = port_command(ThirdInput, "find\n"),
    ern_harness:prints(Third, "found: "),
    true = port_command(LateInput, "ask\n"),
    ern_harness:prints(Late, "asked in the window"),
    ern_harness:says(Late, "the peer desk connected"),
    true = port_command(ThirdInput, "utilization\n"),
    ern_harness:prints(Third, "utilization: "),
    let_go(Pipe),
    ?assertEqual(0, WaitDesk()),
    ern_harness:says(Late, "the peer desk was lost: it closed"),
    [ern_harness:says(Dir, "the peer desk ended") || Dir <- [Store, Third]],
    true = port_command(LateInput, "again\n"),
    ern_harness:prints(Late, "the late node saw the idle process, after the end: "),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{Late, WaitLate}, {Third, WaitThird},
                                                   {Store, WaitStore}]],
    [{LateOut, _}, {ThirdOut, _}, _,
     _] = [ern_harness:said(Dir) || Dir <- [Late, Third, Store, Desk]],
    Unreachable = "Left(Io.Unreachable)",
    [?assertEqual([Answer], said_after(ThirdOut, Prefix))
     || {Prefix, Answer} <- [{"found: ", Unreachable}, {"utilization: ", Unreachable},
                             {"the third saw the idle process: ", "ProgramEnd"}]],
    [?assertEqual([Answer], said_after(LateOut, Prefix))
     || {Prefix, Answer} <- [{"utilization: ", Unreachable}, {"told by the desk: ", "false"},
                             {"found: ", Unreachable}, {"called: ", "None"},
                             {"the late node saw the idle process, in the window: ", "Unknown"},
                             {"spawned: ", Unreachable}, {"computed: ", Unreachable},
                             {"the late node saw the idle process, after the end: ",
                              "Unreachable"}]].

%% report §12.5, §12.6, §8.7: a reload waits on no connection. The maker's
%% connection to the third held back, as killer_waits_on_no_peer/1 holds
%% one, a reload removes the third, and "a peer removed ... has its
%% connection ended: both nodes run the loss". The maker says the reload
%% while the connection is held, and goes on: the asker sends it a frame
%% it cannot read, and "the node ends the connection", the asker running
%% the loss; the asker's find of the maker's probe after it answers. Once
%% the connection is let go, the maker and the third run the loss.
%%
%% A regression test, written before the fix: the host's disconnect waited
%% for the held connection's process to take its exit, holding the reload,
%% the asker's worker and each disconnect after them (the log's *What a
%% Peer's Worker Waits On*; docs/otp_bugs.md, report 26). It does not cover
%% a peer whose key changed, which a reload ends alike, nor a frame the
%% exchange cannot read.
reload_waits_on_no_connection_test_() ->
    ern_harness:nodes_test({waits, 18}, fun reload_waits_on_no_connection/1).

reload_waits_on_no_connection(Base) ->
    Program = disconnect_build(Base),
    {Asker, Maker, Third} = disconnect_nodes(Base),
    WaitThird = offering(Third, Program, "third"),
    {MakerInput, WaitMaker} = ern_harness:started(Maker, Program, ["held"]),
    ern_harness:prints(Maker, "found"),
    {AskerInput, WaitAsker} = ern_harness:started(Asker, Program,
                                                  ["asker", ern_harness:name(Maker)]),
    ern_harness:prints(Asker, "found: "),
    true = port_command(MakerInput, "hold\n"),
    ern_harness:prints(Maker, "held back"),
    reloaded_without_the_third(Maker, MakerInput),
    ern_harness:says(Maker, "the peer third was removed"),
    true = port_command(AskerInput, "frame\n"),
    ern_harness:says(Asker, "the peer maker was lost: it closed"),
    true = port_command(AskerInput, "find\n"),
    ern_harness:prints(Asker, "found again: "),
    true = port_command(MakerInput, "free\n"),
    ern_harness:says(Maker, "the node " ++ digest(Third) ++ " was lost: it closed"),
    ern_harness:says(Third, "the peer maker was lost: it closed"),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{Asker, WaitAsker}, {Maker, WaitMaker},
                                                   {Third, WaitThird}]],
    [{AskerOut, _}, {_, MakerErr}, _] = [ern_harness:said(Dir) || Dir <- [Asker, Maker, Third]],
    [ern_harness:has(AskerOut, Line) || Line <- ["found: Right(", "found again: Right("]],
    ern_harness:has(MakerErr,
                    "the peer asker sent a frame this node cannot read, and this node ends its"
                    " connection").

%% report §8.6, §8.7, §12.5: a reload holds no termination. The maker's
%% connection to the third held back and a reload removing the third, as
%% reload_waits_on_no_connection/1 has them, the maker is sent termination
%% once the host has been asked to end the connection: "for a node,
%% termination ends it the same way", so its subscriber of the end is told
%% while the connection is still held, and the maker ends with the signal's
%% status, its processes' end letting the connection go.
%%
%% A regression test, written before the fix: the termination waited in the
%% host's signal server behind the reload's disconnect, which waited for the
%% held connection (the log's *What a Peer's Worker Waits On*). It does not
%% cover a hangup or an interrupt then, nor the end of a node whose
%% connection to the removed peer stays held past its processes' end.
reload_holds_no_termination_test_() ->
    ern_harness:nodes_test({waits, 9}, fun reload_holds_no_termination/1).

reload_holds_no_termination(Base) ->
    Program = disconnect_build(Base),
    {_, Maker, Third} = disconnect_nodes(Base),
    WaitThird = offering(Third, Program, "third"),
    {MakerInput, WaitMaker} = ern_harness:started(Maker, Program, ["held"]),
    ern_harness:prints(Maker, "found"),
    true = port_command(MakerInput, "hold\n"),
    ern_harness:prints(Maker, "held back"),
    reloaded_without_the_third(Maker, MakerInput),
    ern_harness:terminated(Maker),
    ern_harness:prints(Maker, "told of the end"),
    ?assertEqual(143, WaitMaker()),
    ?assertEqual(nomatch, string:find(ern_harness:written(Maker, out), "let go")),
    ern_harness:stop(Third, WaitThird).

%% report §12.5, §8.7, §12.6: a reload waits on no peer that stands still.
%% The third stopped, the maker sends it more than its connection takes,
%% until the host holds the sender in its send, and a reload removes the
%% third, whose connection the host can close only "later than it finds the
%% silence"; the maker goes on meanwhile. It says the reload; the asker's
%% frame it cannot read ends the asker's connection, the asker running the
%% loss; the asker's find after it answers; and the asker's termination
%% ends it, its end asking the maker's host as it tells each peer that it
%% ends. The third's connection stands until the third runs again, and the
%% maker and the third then run the loss.
%%
%% A regression test, written before the fix: the reload's disconnect held
%% the host's process of the node's connections while the third stood
%% still, so the maker passed no tick and found no loss, and the asker's
%% end waited (the log's *What a Peer's Worker Waits On*). It does not wait
%% for the loss while the third stands still, which comes in the host's
%% time.
reload_waits_on_no_stopped_peer_test_() ->
    ern_harness:nodes_test({waits, 17}, fun reload_waits_on_no_stopped_peer/1).

reload_waits_on_no_stopped_peer(Base) ->
    Program = disconnect_build(Base),
    {Asker, Maker, Third} = disconnect_nodes(Base),
    WaitThird = offering(Third, Program, "third"),
    {MakerInput, WaitMaker} = ern_harness:started(Maker, Program, ["stopped"]),
    ern_harness:prints(Maker, "found"),
    {AskerInput, WaitAsker} = ern_harness:started(Asker, Program,
                                                  ["asker", ern_harness:name(Maker)]),
    ern_harness:prints(Asker, "found: "),
    ThirdNumber = pid(Third),
    _ = os:cmd("kill -STOP " ++ ThirdNumber),
    try
        true = port_command(MakerInput, "flood\n"),
        ern_harness:prints(Maker, "the host holds the flooder in its send to the third"),
        reloaded_without_the_third(Maker, MakerInput),
        ern_harness:says(Maker, "the peer third was removed"),
        true = port_command(AskerInput, "frame\n"),
        ern_harness:says(Asker, "the peer maker was lost: it closed"),
        true = port_command(AskerInput, "find\n"),
        ern_harness:prints(Asker, "found again: "),
        ern_harness:stop(Asker, WaitAsker)
    after
        os:cmd("kill -CONT " ++ ThirdNumber)
    end,
    Loss = "the node " ++ digest(Third) ++ " was lost",
    ern_harness:says(Maker, Loss),
    ern_harness:says(Third, "the peer maker was lost"),
    ern_harness:stop(Maker, WaitMaker),
    ern_harness:stop(Third, WaitThird),
    [{AskerOut, _}, {_, MakerErr}] = [ern_harness:said(Dir) || Dir <- [Asker, Maker]],
    [ern_harness:has(AskerOut, Line) || Line <- ["found: Right(", "found again: Right("]],
    %% the third's connection stood until the third ran again, after the
    %% asker's end: the maker's sends had filled it
    {_, MakerLines} = lines_said({0, MakerErr}),
    ?assertMatch(["the peer asker ended", _],
                 [Line || Line <- MakerLines,
                          Line =:= "the peer asker ended" orelse lists:prefix(Loss, Line)]).

%% report §12.5, §12.6, the nodes' note's *The gateway and its workers*: the
%% gateway's refusal at a full table of processes waits on no connection.
%% The maker holds its gateway back while the dialer connects, then holds
%% its connection to the dialer back, fills its table and lets the gateway
%% go: "a connection to a peer ... that the table leaves no room to serve
%% is closed as it opens, and the node says so", and the gateway answers
%% the asker's utilization while that connection is held. Once it is let
%% go, the dialer runs the loss.
%%
%% A regression test, written before the fix: the gateway's disconnect
%% waited for the held connection's process, and so did every frame of
%% every peer. It does not cover a refusal whose connection's process
%% cannot take its exit otherwise than held, which a dial a large message
%% waits behind meets.
refusal_waits_on_no_connection_test_() ->
    ern_harness:nodes_test({waits, 15}, fun refusal_waits_on_no_connection/1).

refusal_waits_on_no_connection(Base) ->
    Program = disconnect_build(Base),
    [PortAsker, PortMaker] = [ern_harness:free_port() || _ <- [asker, maker]],
    Asker = ern_harness:made(Base, "asker", PortAsker),
    Maker = ern_harness:made(Base, "maker", PortMaker),
    Dialer = ern_harness:made(Base, "dialer", none),
    ern_harness:lists(Asker, [{"maker", Maker, PortMaker}]),
    ern_harness:lists(Maker, [{"asker", Asker, PortAsker}, {"dialer", Dialer, none}]),
    ern_harness:lists(Dialer, [{"maker", Maker, PortMaker}]),
    ern_harness:edit(Asker,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"probe">> => [<<"maker">>]}} end),
    ern_harness:edit(Maker, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    {MakerInput, WaitMaker} = ern_harness:started(Maker, Program, ["refusing"]),
    ern_harness:prints(Maker, "offered"),
    {AskerInput, WaitAsker} = ern_harness:started(Asker, Program,
                                                  ["asker", ern_harness:name(Maker)]),
    ern_harness:prints(Asker, "found: "),
    true = port_command(MakerInput, "hold\n"),
    ern_harness:prints(Maker, "the gateway held back"),
    {_, WaitDialer} = ern_harness:started(Dialer, Program, ["dialer", ern_harness:name(Maker)]),
    ern_harness:prints(Dialer, "connect: "),
    true = port_command(MakerInput, ern_harness:name(Dialer) ++ "\n"),
    ern_harness:prints(Maker, "the table filled, and the gateway let go"),
    ern_harness:says(Maker, "the peer dialer was refused: this node's table of processes is full"),
    true = port_command(AskerInput, "utilization\n"),
    ern_harness:prints(Asker, "utilization: "),
    true = port_command(MakerInput, "free\n"),
    ern_harness:says(Dialer, "the peer maker was lost: it closed"),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{Asker, WaitAsker}, {Dialer, WaitDialer},
                                                   {Maker, WaitMaker}]],
    [{AskerOut, _}, {DialerOut, _}, _] = [ern_harness:said(Dir) || Dir <- [Asker, Dialer, Maker]],
    [ern_harness:has(AskerOut, Line) || Line <- ["found: Right(", "utilization: Right("]],
    ern_harness:has(DialerOut, "connect: true").

%% report §6.5, §7.4, §8.7, §12.5: a peer's worker waits on no third node.
%% The maker's holder gives the asker an address adapted over the third's
%% sink, which the maker applies "in a process the node keeps for the
%% address and the sending node". Its connection to the third held back, as
%% killer_waits_on_no_peer/1 holds one, more than 1 MB waiting for the
%% third and its table of processes full, the asker sends to the address:
%% "a message ... the runtime has no room to make, through an adapted
%% address ... faults the process it is for", the third's sink, and the
%% asker's find of the maker's probe after it is answered while the
%% connection is held. Once it is let go, the sink faults with
%% `error:system_limit`.
%%
%% A regression test, written after the code and before its fix: the
%% worker's send of the fault waited in the host's buffer for the third,
%% and every frame of the asker's behind it (the log's *What a Peer's
%% Worker Waits On*). It does not cover a third node that is stopped, nor
%% the fault dropped at the third's loss.
worker_waits_on_no_third_node_test_() ->
    ern_harness:nodes_test({waits, 13}, fun worker_waits_on_no_third_node/1).

worker_waits_on_no_third_node(Base) ->
    Program = disconnect_build(Base),
    {Asker, Maker, Third} = disconnect_nodes(Base),
    ern_harness:edit(Maker, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
    WaitThird = offering(Third, Program, "third"),
    {MakerInput, WaitMaker} = ern_harness:started(Maker, Program, ["kept"]),
    ern_harness:prints(Maker, "found"),
    {AskerInput, WaitAsker} = ern_harness:started(Asker, Program, ["sender"]),
    ern_harness:prints(Asker, "found: "),
    true = port_command(MakerInput, "hold\n"),
    ern_harness:prints(Maker, "held back, and the table filled"),
    true = port_command(AskerInput, "send\n"),
    ern_harness:prints(Asker, "found while held: "),
    true = port_command(MakerInput, "free\n"),
    ern_harness:says(Third, "faulted: error:system_limit"),
    [ern_harness:stop(Dir, Wait) || {Dir, Wait} <- [{Asker, WaitAsker}, {Maker, WaitMaker},
                                                   {Third, WaitThird}]],
    [{AskerOut, _}, _, _] = [ern_harness:said(Dir) || Dir <- [Asker, Maker, Third]],
    [ern_harness:has(AskerOut, Line) || Line <- ["found: Right(", "found while held: Right("]].

%% The disconnect's three nodes, each listening: the asker, which finds the
%% maker's probe and its holder, the maker, which finds the third's sink and
%% bulk, and the third.
disconnect_nodes(Base) ->
    [PortAsker, PortMaker, PortThird] = [ern_harness:free_port() || _ <- [asker, maker, third]],
    Asker = ern_harness:made(Base, "asker", PortAsker),
    Maker = ern_harness:made(Base, "maker", PortMaker),
    Third = ern_harness:made(Base, "third", PortThird),
    ern_harness:lists(Asker, [{"maker", Maker, PortMaker}]),
    ern_harness:lists(Maker, [{"asker", Asker, PortAsker}, {"third", Third, PortThird}]),
    ern_harness:lists(Third, [{"maker", Maker, PortMaker}]),
    ern_harness:edit(Asker, fun(Conf) ->
                                Conf#{<<"services">> => #{<<"probe">> => [<<"maker">>],
                                                          <<"holder">> => [<<"maker">>]}}
                            end),
    ern_harness:edit(Maker, fun(Conf) ->
                                Conf#{<<"services">> => #{<<"sink">> => [<<"third">>],
                                                          <<"bulk">> => [<<"third">>]}}
                            end),
    {Asker, Maker, Third}.

%% Report §12.5: the maker's ernest.conf with the third and its services
%% removed and the node reloaded, as an operator removes a peer; then
%% until the maker says the host was asked to end its connection to the
%% third, which it watches for once its connection is held or full.
reloaded_without_the_third(Maker, MakerInput) ->
    ern_harness:edit(Maker, fun(#{<<"peers">> := Peers} = Conf) ->
                                Conf#{<<"peers">> := [Peer || #{<<"name">> := Name} = Peer <- Peers,
                                                              Name =/= <<"third">>],
                                      <<"services">> := #{}}
                            end),
    ?assertMatch({0, _}, signaled("reload", Maker)),
    true = port_command(MakerInput, "asked\n"),
    ern_harness:prints(Maker, "the host was asked to end the connection to the third").

%% The disconnect's tests' program, built in Base beside the host modules
%% it asks of the host, the buffer's (buffer_host/0) and its own
%% (disconnect_host/0); answers its `.erc`.
disconnect_build(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "disconnect.ern"), [<<"
// Report §12.5, §12.6, §8.6, §8.7: a disconnect waits on no connection. The
// third offers a sink and a bulk, which the maker finds. The maker holds its
// connection to the third back, or sends the bulk more than the connection
// takes once the test has stopped the third, and says once the host has been
// asked to end that connection, which a reload without the third asks. The
// asker finds the maker's probe, and then sends the maker a frame it cannot
// read, finds the probe again or asks how busy the maker is, as each line
// says. The maker's subscriber of the end says when it is told.
//
// Or the maker refuses the dialer at its full table of processes: its
// gateway held back while the dialer connects, its connection to the dialer
// held back and its table filled, and then its gateway let go.
//
// Or the maker's worker for the asker waits on no third node: the maker's
// holder gives the asker an address adapted over the third's sink, and the
// maker holds its connection to the third back, with the bulk sent more than
// the buffer holds and its table filled, while the asker sends to the address
// and finds the probe; then it empties its table and lets the connection go.

// The process of the host's that writes what waits for the process's node to
// the connection, and the one for a node by its name on the carrier.
foreign fn connectionTo(process : Process) : Foreign.Term =
    \"ern_nodes_buffer:connection_to/1\"

foreign fn connectionOf(node : Foreign.Term) : Foreign.Term =
    \"ern_nodes_disconnect:connection_of/1\"

// The host's report of each time the process is suspended in a send to
// another node, its count sent to the address.
foreign fn watch(process : Process, to : Address(Int)) : Unit =
    \"ern_nodes_buffer:watch/2\"

// From now on, each ask of the host's to end a connection watched; and until
// it has been asked to end the one to the process's node.
foreign fn disconnectsWatched() : Unit = \"ern_nodes_disconnect:watched/0\"

foreign fn askedToEnd(process : Process) : Unit = \"ern_nodes_disconnect:asked/1\"

// A frame the gateway of the node cannot read.
foreign fn unreadable(node : Foreign.Term) : Unit = \"ern_nodes_disconnect:unreadable/1\"

foreign fn connect(node : Foreign.Term) : Bool = \"net_kernel:connect_node/1\"
foreign fn whereis(name : Foreign.Term) : Foreign.Term = \"erlang:whereis/1\"
foreign fn suspended(process : Foreign.Term) : Bool = \"erlang:suspend_process/1\"
foreign fn resumed(process : Foreign.Term) : Bool = \"erlang:resume_process/1\"
foreign fn systemInfo(item : Foreign.Term) : Int = \"erlang:system_info/1\"

type MakerMsg = Subscribed | Suspended(Int)

type FloodMsg = Flood

// What the maker's holder of the address it adapted is asked.
type HolderMsg = Get(Reply(Address(Int)))

let sink : Peer.Service(Int) = Peer.service(\"sink\")

let bulk : Peer.Service(Bytes) = Peer.service(\"bulk\")

let probe : Peer.Service(Int) = Peer.service(\"probe\")

let holder : Peer.Service(HolderMsg) = Peer.service(\"holder\")

export fn main() : Unit receiving MakerMsg =
    match Os.arguments {
        [\"third\"] -> {
            let _ = Peer.offer(sink, spawn(fn() : Unit receiving Int = held()));
            let _ = Peer.offer(bulk, spawn(fn() : Unit receiving Bytes = held()));
            Io.println(\"offered\");
            held()
        }
      | [\"held\"] ->
            heldBack()
      | [\"stopped\"] ->
            flooded()
      | [\"refusing\"] ->
            refusing()
      | [\"kept\"] ->
            kept()
      | [\"asker\", maker] -> {
            Io.println(\"found: \" <> Io.show(Peer.find(probe, waitMs())));
            asked(maker)
        }
      | [\"sender\"] ->
            sending()
      | [\"dialer\", maker] -> {
            Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(maker))));
            held()
        }
      | _ ->
            Unit
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit receiving m =
    receive {
        _ -> held()
    }

fn found(service : Peer.Service(m)) : Address(m) =
    match Peer.find(service, waitMs()) {
        Right(address) -> address
      | Left(failure) -> fault(Io.show(failure))
    }

// The probe the asker finds, and a subscriber of the end, once it has
// subscribed.
fn offered() : Unit receiving MakerMsg = {
    let me = self();
    let _ = Peer.offer(probe, spawn(fn() : Unit receiving Int = held()));
    let _ = spawn(fn() = subscribed(me));
    receive {
        Subscribed -> Unit
    }
}

fn subscribed(maker : Address(MakerMsg)) : Unit receiving Reply(Unit) = {
    Os.subscribeTermination(fn(reply) = reply);
    send(maker, Subscribed);
    receive {
        reply -> {
            Io.println(\"told of the end\");
            answer(reply, Unit)
        }
    }
}

// The maker whose connection to the third is held back, and let go once the
// test says so.
fn heldBack() : Unit receiving MakerMsg = {
    let third = Process.fromAddress(found(sink));
    offered();
    Io.println(\"found\");
    let _ = Io.readLine();
    let connection = connectionTo(third);
    let _ = suspended(connection);
    disconnectsWatched();
    Io.println(\"held back\");
    toldOfTheAsk(third);
    let _ = Io.readLine();
    let _ = resumed(connection);
    Io.println(\"let go\");
    held()
}

// Once the test says so, until the host has been asked to end the
// connection to the third.
fn toldOfTheAsk(third : Process) : Unit = {
    let _ = Io.readLine();
    askedToEnd(third);
    Io.println(\"the host was asked to end the connection to the third\")
}

// The maker that sends the bulk more than its connection takes once the test
// has stopped the third, until the host holds the flooder in its send.
fn flooded() : Unit receiving MakerMsg = {
    let me = self();
    let third = Process.fromAddress(found(sink));
    let target = found(bulk);
    let flooder = spawn(fn() : Unit receiving FloodMsg = flooding(target));
    watch(Process.fromAddress(flooder), adapted(me, Suspended));
    offered();
    Io.println(\"found\");
    let _ = Io.readLine();
    disconnectsWatched();
    send(flooder, Flood);
    receive {
        Suspended(_) -> Io.println(\"the host holds the flooder in its send to the third\")
    };
    toldOfTheAsk(third);
    held()
}

// A quarter of a megabyte at a time, 32 megabytes in all, so that what waits
// for the connection is never taken whole before the connection is full, as
// one message's rest may be while the host holds its sender.
fn flooding(target : Address(Bytes)) : Unit receiving FloodMsg =
    receive {
        Flood -> quarters(target, 128)
    }

fn quarters(target : Address(Bytes), left : Int) : Unit =
    if left > 0 then {
        send(target, Bytes.repeat(<<0>>, 262144));
        quarters(target, left - 1)
    } else
        Unit

// The maker that refuses the dialer at its full table of processes, the
// dialer's name on the carrier typed once it has connected.
fn refusing() : Unit receiving MakerMsg = {
    offered();
    Io.println(\"offered\");
    let _ = Io.readLine();
    let gateway = whereis(Foreign.atom(\"ern_gateway\"));
    let _ = suspended(gateway);
    Io.println(\"the gateway held back\");
    match Io.readLine() {
        Some(dialer) -> {
            let connection = connectionOf(Foreign.atom(dialer));
            let _ = suspended(connection);
            let fillers = filled(systemInfo(Foreign.atom(\"process_limit\"))
                                     - systemInfo(Foreign.atom(\"process_count\")),
                                 []);
            let _ = resumed(gateway);
            Io.println(\"the table filled, and the gateway let go\");
            let _ = Io.readLine();
            List.forEach(fillers, fn(filler) = send(filler, 0));
            let _ = resumed(connection);
            Io.println(\"let go\")
        }
      | None ->
            Unit
    };
    held()
}

// Count processes spawned, each waiting until it is sent a number, after
// those held.
fn filled(count : Int, fillers : List(Address(Int))) : List(Address(Int)) =
    if count > 0 then
        filled(count - 1, spawn(fn() : Unit receiving Int = receive { _ -> Unit }) :: fillers)
    else
        fillers

// The maker whose worker for the asker can keep no process for the address
// its holder gives, adapted over the third's sink: once the test says so,
// its connection to the third held back, the bulk sent more than the buffer
// holds until the host holds the flooder in its send, and its table of
// processes filled; once the test says so again, the table emptied and the
// connection let go.
fn kept() : Unit receiving MakerMsg = {
    let me = self();
    let target = found(sink);
    let floodTarget = found(bulk);
    let flooder = spawn(fn() : Unit receiving FloodMsg = flooding(floodTarget));
    watch(Process.fromAddress(flooder), adapted(me, Suspended));
    let address = adapted(target, fn(count) = count);
    let _ = Peer.offer(holder, spawn(fn() : Unit receiving HolderMsg = holding(address)));
    offered();
    Io.println(\"found\");
    let _ = Io.readLine();
    let connection = connectionTo(Process.fromAddress(target));
    let _ = suspended(connection);
    send(flooder, Flood);
    receive {
        Suspended(_) -> Unit
    };
    let fillers = filled(systemInfo(Foreign.atom(\"process_limit\"))
                             - systemInfo(Foreign.atom(\"process_count\")),
                         []);
    Io.println(\"held back, and the table filled\");
    let _ = Io.readLine();
    List.forEach(fillers, fn(filler) = send(filler, 0));
    let _ = resumed(connection);
    Io.println(\"let go\");
    held()
}

fn holding(address : Address(Int)) : Unit receiving HolderMsg =
    receive {
        Get(reply) -> {
            answer(reply, address);
            holding(address)
        }
    }

// The asker, doing what each line says until its input ends.
fn asked(maker : String) : Unit receiving MakerMsg =
    match Io.readLine() {
        Some(\"frame\") -> {
            unreadable(Foreign.atom(maker));
            Io.println(\"sent a frame the maker cannot read\");
            asked(maker)
        }
      | Some(\"find\") -> {
            Io.println(\"found again: \" <> Io.show(Peer.find(probe, waitMs())));
            asked(maker)
        }
      | Some(\"utilization\") -> {
            Io.println(\"utilization: \" <> Io.show(Peer.utilization(\"maker\", waitMs())));
            asked(maker)
        }
      | _ ->
            held()
    }

// The asker that sends to the maker's adapted address once the test says so,
// and then finds the probe, which the maker's worker for it answers.
fn sending() : Unit receiving MakerMsg = {
    let address = match Address.call(found(holder), Get, waitMs()) {
        Some(address) -> address
      | None -> fault(\"the holder gave no address\")
    };
    Io.println(\"found: \" <> Io.show(Peer.find(probe, waitMs())));
    let _ = Io.readLine();
    send(address, 1);
    Io.println(\"found while held: \" <> Io.show(Peer.find(probe, waitMs())));
    held()
}
"/utf8>>, ern_harness:wait_ms_declaration()]),
    [begin
         Source = filename:join(Root, Module ++ ".erl"),
         ok = file:write_file(Source, Text),
         {ok, _} = compile:file(Source, [{outdir, Root}])
     end || {Module, Text} <- [{"ern_nodes_buffer", buffer_host()},
                               {"ern_nodes_disconnect", disconnect_host()}]],
    0 = ern_harness:built([Root]),
    filename:join(Root, "disconnect.erc").

%% A host module for the disconnect's program. It answers the process of the
%% host's that writes a connection, by the node's name on the carrier, and
%% sends a node's gateway a frame it cannot read. It watches, by a process
%% of its own that traces what the host's process of the node's connections
%% takes, each ask to end a connection, whether a call or a cast, and
%% answers a process once the host has been asked to end the connection to
%% a node.
disconnect_host() ->
    <<"
-module(ern_nodes_disconnect).
-export([connection_of/1, watched/0, asked/1, unreadable/1]).
connection_of(Node) ->
    {_, Controller} = lists:keyfind(Node, 1, erlang:system_info(dist_ctrl)),
    Controller.
watched() ->
    Caller = self(),
    Kernel = whereis(net_kernel),
    Watcher = spawn(fun() ->
                        true = register(ern_nodes_disconnects, self()),
                        1 = erlang:trace(Kernel, true, ['receive']),
                        Caller ! {ern_nodes_watching, self()},
                        disconnects(#{}, [])
                    end),
    receive {ern_nodes_watching, Watcher} -> 'Unit' end.
disconnects(Asked, Waiting) ->
    receive
        {trace, _, 'receive', {'$gen_call', _, {disconnect, Node}}} ->
            told(Asked#{Node => true}, Waiting);
        {trace, _, 'receive', {'$gen_cast', {async_disconnect, Node}}} ->
            told(Asked#{Node => true}, Waiting);
        {trace, _, 'receive', _} ->
            disconnects(Asked, Waiting);
        {asked, Node, From} ->
            told(Asked, [{Node, From} | Waiting])
    end.
told(Asked, Waiting) ->
    disconnects(Asked, [Wait || {Node, From} = Wait <- Waiting,
                                not answered(maps:is_key(Node, Asked), Node, From)]).
answered(true, Node, From) ->
    From ! {ern_nodes_asked, Node},
    true;
answered(false, _, _) ->
    false.
asked(Pid) ->
    Node = node(Pid),
    ern_nodes_disconnects ! {asked, Node, self()},
    receive {ern_nodes_asked, Node} -> 'Unit' end.
unreadable(Node) ->
    erlang:send({ern_gateway, Node}, {ern_frame, self(), unreadable}),
    'Unit'.
">>.

%% A node of the buffer's program started in Mode, once it has offered its
%% services; answers what waits for its end.
offering(Dir, Program, Mode) ->
    Wait = ern_harness:start(Dir, Program, [Mode]),
    ern_harness:prints(Dir, "offered"),
    Wait.

%% A store that listens and a desk that dials it, the desk finding the
%% store's sink there.
buffer_nodes(Base) ->
    Port = ern_harness:free_port(),
    Store = ern_harness:made(Base, "store", Port),
    Desk = ern_harness:made(Base, "desk", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Desk, [{"store", Store, Port}]),
    ern_harness:edit(Desk,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"sink">> => [<<"store">>]}} end),
    {Store, Desk}.

%% The same, and a third node that listens, which the desk dials too, and
%% which finds the desk's own sink at the desk.
buffer_nodes_and_third(Base) ->
    {PortStore, PortThird} = {ern_harness:free_port(), ern_harness:free_port()},
    Store = ern_harness:made(Base, "store", PortStore),
    Desk = ern_harness:made(Base, "desk", none),
    Third = ern_harness:made(Base, "third", PortThird),
    [ern_harness:lists(Dir, [{"desk", Desk, none}]) || Dir <- [Store, Third]],
    ern_harness:lists(Desk, [{"store", Store, PortStore}, {"third", Third, PortThird}]),
    ern_harness:edit(Desk,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"sink">> => [<<"store">>]}} end),
    ern_harness:edit(Third,
                     fun(Conf) -> Conf#{<<"services">> => #{<<"desk-sink">> => [<<"desk">>]}} end),
    {Store, Desk, Third}.

%% The same, the desk finding the store's watcher at the store and the
%% third node's at the third node.
watched_nodes(Base) ->
    {Store, Desk, Third} = buffer_nodes_and_third(Base),
    ern_harness:edit(Desk, fun(#{<<"services">> := Services} = Conf) ->
                               Conf#{<<"services">> := Services#{<<"store-watch">> => [<<"store">>],
                                                                <<"third-watch">> => [<<"third">>]}}
                           end),
    {Store, Desk, Third}.

%% The buffer's tests' program, built in Base beside the host module it
%% asks of the host (buffer_host/0); answers its `.erc`.
buffer_build(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "buffer.ern"), [<<"
// Report §8.7: what waits for a peer in the host's buffer. The store's sink
// takes what the desk sends it. The desk sends it a message above the buffer
// and one after it; or, the store stopped, a sender sends until a send waits,
// and the desk says what ended the wait, or what a spawn on the store or a
// call of its sink answered meanwhile, or what a third node's asks of the
// desk and the desk's spawn on it answered.
//
// Or, the desk's connection to the store held back, the desk says whether
// its own processes that serve the whole node, its killer, its reaper and
// its exchange, still serve it, and what `Process.status` says of a sender
// held in its send.
//
// Or, the connection held back too, watchers on the store and on a third
// node say when the Down of a process of the desk's reaches them: a sender
// killed in its send, a callee killed while its answer waits, a process that
// faults while the buffer for the store is full, and a sender killed before
// the connection is lost; and callers on the store, the third node and the
// desk say what their calls of a callee killed so answered, and when.

// The host's report of each time the process is suspended in a send to
// another node, its count sent to the address.
foreign fn watch(process : Process, to : Address(Int)) : Unit =
    \"ern_nodes_buffer:watch/2\"

// Whether the host holds a connection to the node the process is on.
foreign fn isConnected(process : Process) : Bool =
    \"ern_nodes_buffer:is_connected/1\"

// Once the process of the host's takes a message that names a process of
// the peer's node, 1 sent to the address.
foreign fn taken(process : Foreign.Term, peer : Process, to : Address(Int)) : Unit =
    \"ern_nodes_buffer:taken/3\"

// Once the process of the host's sends the other a message that names a
// process of the peer's node, as the node's gateway hands its exchange a
// frame of the peer's, 1 sent to the address.
foreign fn handedOn(process : Foreign.Term,
                    to : Foreign.Term,
                    peer : Process,
                    address : Address(Int)) : Unit =
    \"ern_nodes_buffer:handed_on/4\"

// The node's reaper, which spawns the node's processes and gives their Downs.
foreign fn reaper() : Foreign.Term = \"ern_rt:launch_reaper/0\"

// The process of the host's that takes what waits in its buffer for the
// process's node and writes it to the connection.
foreign fn connectionTo(process : Process) : Foreign.Term = \"ern_nodes_buffer:connection_to/1\"

// The node's exchange, which the host holds back from its work and lets go
// again, as it does the connection.
foreign fn whereis(name : Foreign.Term) : Foreign.Term = \"erlang:whereis/1\"
foreign fn suspended(process : Foreign.Term) : Bool = \"erlang:suspend_process/1\"
foreign fn resumed(process : Foreign.Term) : Bool = \"erlang:resume_process/1\"

// The host's exit signal sent to the process, by which the desk ends the
// process of the host's that writes a connection, and so the connection.
foreign fn exited(process : Foreign.Term, reason : Foreign.Term) : Bool = \"erlang:exit/2\"

// What the sink takes; a Ping answers how many of the others it has taken.
type SinkMsg = Whole(Bytes) | Next | Chunk(Bytes) | Ping(Reply(Int)) | Hold(Reply(Int))

type DeskMsg =
    Suspended(Int)
  | Returned(Waited)
  | Answered(answer : String, began : Int, ended : Int)
  | Ended(name : String, down : Down)
  | Taken(Int)
  | Ready
  | Held(String)
  | Watching
  | Questioned

type SenderMsg = Go | Asked(Int)

type AskerMsg = Ask | SinkEnded(Down)

// The send that waited: its number, the moments it began and ended, and
// the moments of what it was asked, which it served after it.
type Waited = Waited(index : Int, began : Int, ended : Int, asked : List(Int))

// What a watcher of the store's or the third node's is asked: to monitor a
// process of the desk's under a name, telling the desk once the monitor
// stands, or to call the desk's callee; and each Down its monitors give it.
type WatchMsg =
    Watch(name : String, process : Process, to : Address(DeskMsg))
  | Call(Address(CalleeMsg))
  | Saw(name : String, down : Down)

// What the desk's callee is asked: a question, which it holds; the answer
// it gives every question it holds; or a message above the buffer to send
// the sink, after which it answers none.
type CalleeMsg = Question(Reply(Bytes)) | AnswerWith(Bytes) | SendTo(Address(SinkMsg))

let sink : Peer.Service(SinkMsg) = Peer.service(\"sink\")

let deskSink : Peer.Service(SinkMsg) = Peer.service(\"desk-sink\")

let storeWatch : Peer.Service(WatchMsg) = Peer.service(\"store-watch\")

let thirdWatch : Peer.Service(WatchMsg) = Peer.service(\"third-watch\")

export fn main() : Unit receiving DeskMsg =
    match Os.arguments {
        [\"sink\"] -> {
            let _ = Peer.offer(sink, spawn(fn() = sinking()));
            Io.println(\"offered\");
            held()
        }
      | [\"store\"] -> {
            let _ = Peer.offer(sink, spawn(fn() = sinking()));
            let _ = Peer.offer(storeWatch, spawn(fn() = watching(\"the store\")));
            Io.println(\"offered\");
            held()
        }
      | [\"watcher\"] -> {
            let _ = Peer.offer(thirdWatch, spawn(fn() = watching(\"the third\")));
            Io.println(\"offered\");
            held()
        }
      | [\"above\"] ->
            above(found(sink))
      | [\"wait\"] ->
            waits(found(sink))
      | [\"spawn\"] ->
            askedInTheWait(found(sink),
                           \"spawn\",
                           fn(_) = Io.show(Peer.spawn(\"store\", fn() = Unit, 1000)))
      | [\"call\"] ->
            askedInTheWait(found(sink),
                           \"call\",
                           fn(address) = Io.show(Address.call(address, Ping, 1000)))
      | [\"gateway\"] ->
            serves(found(sink))
      | [\"third\", interval] ->
            asks(Optional.withDefault(String.toInt(interval), 0))
      | [\"kill\"] ->
            kills(found(sink))
      | [\"monitor\"] ->
            reaps(found(sink), fn(_) = Unit, fn(sink) = monitor(sink, SinkEnded))
      | [\"demonitor\"] ->
            reaps(found(sink), fn(sink) = monitor(sink, SinkEnded), fn(sink) = demonitor(sink))
      | [\"exchange\"] ->
            exchanges()
      | [\"status\"] ->
            reads(found(sink))
      | [\"answered\", \"small\"] -> {
            let address = found(sink);
            answeredWhileHeld(pattern(1), fn() = flooded(address, flooder(address)))
        }
      | [\"answered\", \"large\"] -> {
            let address = found(sink);
            answeredWhileHeld(whole(), fn() = heldBack(address))
        }
      | [\"sent\"] ->
            sentWhileHeld(found(sink))
      | [\"faulted\"] ->
            faultedWhileHeld(found(sink))
      | [\"lost\"] ->
            lostWhileHeld(found(sink))
      | [\"called\"] ->
            calledWhileHeld(found(sink))
      | _ ->
            Unit
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit receiving DeskMsg =
    receive {
        _ -> held()
    }

fn found(service : Peer.Service(m)) : Address(m) =
    match Peer.find(service, waitMs()) {
        Right(address) -> address
      | Left(failure) -> fault(Io.show(failure))
    }

// The message above the buffer, sixteen times its megabyte, which the sink
// makes again to compare.
fn whole() : Bytes =
    pattern(2097152)

// Eight bytes count times over, from which a taker tells a message whole.
fn pattern(count : Int) : Bytes =
    Bytes.repeat(<<1, 2, 3, 4, 5, 6, 7, 8>>, count)

fn sinking() : Unit receiving SinkMsg =
    taking(0)

// The sink, count the messages it has taken, a Ping and a Hold not among
// them.
fn taking(count : Int) : Unit receiving SinkMsg =
    receive {
        Whole(bytes) -> {
            Io.println(\"took \"
                           <> Int.toString(Bytes.size(bytes))
                           <> \" bytes, whole: \"
                           <> Io.show(bytes == whole()));
            taking(count + 1)
        }
      | Next -> {
            Io.println(\"took the next\");
            taking(count + 1)
        }
      | Chunk(_) ->
            taking(count + 1)
      | Ping(reply) -> {
            answer(reply, count);
            taking(count)
        }
      | Hold(_) -> {
            Io.println(\"holds a call\");
            taking(count)
        }
    }

// Report §8.7: a message above the buffer, its send waiting with what it
// has not placed, and the next behind it.
fn above(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let bytes = whole();
    watch(Process.current(), adapted(self(), Suspended));
    send(address, Whole(bytes));
    Io.println(\"sent \" <> Int.toString(Bytes.size(bytes)) <> \" bytes\");
    send(address, Next);
    Io.println(\"sent the next\");
    // the host's report of the wait, which comes after it
    receive {
        Suspended(_) -> Io.println(\"the host says the send waited\")
    };
    held()
}

// Report §8.7: the store stopped, a sender sends a quarter of a megabyte at
// a time until a send waits, and only the loss ends the wait. Each time the
// host says the sender is suspended, this process asks it something, which
// it serves only between its sends.
fn waits(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let me = self();
    let sender = spawn(fn() : Unit receiving SenderMsg = starting(me, address));
    watch(Process.fromAddress(sender), adapted(me, Suspended));
    Io.println(\"found\");
    // until the test, which has stopped the store, says so
    let _ = Io.readLine();
    let stopped = Clock.monotonic();
    send(sender, Go);
    told(sender, stopped)
}

fn told(sender : Address(SenderMsg), stopped : Int) : Unit receiving DeskMsg =
    receive {
        Suspended(count) -> {
            Io.println(\"the host says the sender waits in a send: \" <> Int.toString(count));
            send(sender, Asked(Clock.monotonic()));
            told(sender, stopped)
        }
      | Returned(waited) ->
            summed(waited, stopped)
    }

// What the wait was: the sends that returned before it, when it began and
// when it ended after the stop, and what the sender was asked during it,
// which it served after it.
fn summed(waited : Waited, stopped : Int) : Unit = {
    Io.println(\"returned before the wait: \" <> Int.toString(waited.index - 1));
    Io.println(\"began after: \" <> Int.toString(waited.began - stopped) <> \" ms\");
    let during = List.filter(waited.asked, fn(moment) = moment >= waited.began);
    Io.println(\"asked during the wait, served after it: \" <> Int.toString(List.size(during)));
    Io.println(\"given up after: \" <> Int.toString((waited.ended - stopped) / 1000))
}

// Report Appendix E.27, §6.6, §8.7: the store stopped and the sender
// waiting in a send to it, an ask of the store given a second, a spawn on
// it or a call of its sink: what the ask sends the store waits as the
// sender's send does, and it answers once the loss ends that wait. The ask
// is named in what the desk says of it.
fn askedInTheWait(address : Address(SinkMsg),
                  name : String,
                  ask : (Address(SinkMsg)) -> String) : Unit receiving DeskMsg = {
    let me = self();
    let sender = spawn(fn() : Unit receiving SenderMsg = starting(me, address));
    watch(Process.fromAddress(sender), adapted(me, Suspended));
    Io.println(\"found\");
    // until the test, which has stopped the store, says so
    let _ = Io.readLine();
    let stopped = Clock.monotonic();
    send(sender, Go);
    receive {
        Suspended(_) -> Unit
    };
    let _ = spawn(fn() = asking(me, address, ask));
    receive {
        Answered(=answer, =began, =ended) -> {
            Io.println(\"the \" <> name <> \" answered: \" <> answer);
            Io.println(\"the \"
                           <> name
                           <> \" began after: \"
                           <> Int.toString(began - stopped)
                           <> \" ms\");
            Io.println(\"the \" <> name <> \" took: \" <> Int.toString(ended - began) <> \" ms\")
        }
    }
}

// The ask, its answer and its moments.
fn asking(desk : Address(DeskMsg),
          address : Address(SinkMsg),
          ask : (Address(SinkMsg)) -> String) : Unit = {
    let began = Clock.monotonic();
    let answer = ask(address);
    send(desk, Answered(=answer, =began, ended = Clock.monotonic()))
}

// Report Appendix E.27: the store stopped and the sender waiting in a send
// to it, the desk's gateway goes on serving the third node, since it sends
// no telling and no utilization's answer that would wait as a send waits:
// the desk's spawn on the third node answers, through the gateway. The desk
// offers its own sink, and dials the third node, which lists it without an
// address, so that the third node can ask it.
fn serves(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let me = self();
    let _ = Peer.offer(deskSink, spawn(fn() = sinking()));
    let _ = Peer.utilization(\"third\", waitMs());
    let sender = spawn(fn() : Unit receiving SenderMsg = starting(me, address));
    watch(Process.fromAddress(sender), adapted(me, Suspended));
    Io.println(\"found\");
    // until the test, which has stopped the store, says so
    let _ = Io.readLine();
    send(sender, Go);
    receive {
        Suspended(_) -> Io.println(\"the host says the sender waits in a send\")
    };
    // until the test, once the third node has asked, says so
    let _ = Io.readLine();
    Io.println(\"spawned on the third: \" <> Io.show(Peer.spawn(\"third\", fn() = Unit, waitMs())));
    held()
}

// Report Appendix E.27: the third node, once the test says the desk's sender
// waits in a send, waits for the desk's next telling, and then asks the
// desk for its sink and how busy it is.
fn asks(interval : Int) : Unit receiving DeskMsg = {
    Io.println(\"ready\");
    // until the test, once the desk's sender waits, says so
    let _ = Io.readLine();
    toldSince(Clock.monotonic(), interval);
    Io.println(\"the desk told after its sender waited\");
    Io.println(\"found: \" <> Io.show(Peer.find(deskSink, waitMs())));
    Io.println(\"utilization: \" <> Io.show(Peer.utilization(\"desk\", waitMs())));
    held()
}

// Report Appendix E.27: until the desk's last telling came after the
// moment, the utilizations read again every interval, the time between the
// desk's tellings, at which alone the table changes; a wait no message can
// show, since a telling is the runtime's frame and no program's.
fn toldSince(moment : Int, interval : Int) : Unit =
    if List.any(Peer.utilizations(),
                fn(#(peer, _, since)) = peer == \"desk\" && Clock.monotonic() - since > moment) then
        Unit
    else {
        Clock.sleep(interval);
        toldSince(moment, interval)
    }

// Report §8.7: the desk's connection to the store held back, so that
// nothing that waits for the store leaves the host's buffer, as nothing
// leaves it for a stopped peer once the kernel's buffers are full; and a
// process of the desk's that then sends the store a message above the
// buffer, which the host places until more than 1 MB waits, and whose
// send then waits until the connection is let go. Each time the host
// suspends it in its send is said to the desk.
fn flooder(address : Address(SinkMsg)) : Address(SenderMsg) receiving DeskMsg =
    sender(address, Chunk(whole()), Suspended)

// A process of the desk's that sends the sink the message once told to go;
// each time the host suspends it in its send, the desk is sent what told
// makes of the count so far.
fn sender(address : Address(SinkMsg),
          message : SinkMsg,
          told : (Int) -> DeskMsg) : Address(SenderMsg) receiving DeskMsg = {
    let spawned = spawn(fn() : Unit receiving SenderMsg = sendingOnGo(address, message));
    watch(Process.fromAddress(spawned), adapted(self(), told));
    spawned
}

fn sendingOnGo(address : Address(SinkMsg), message : SinkMsg) : Unit receiving SenderMsg =
    receive {
        Go -> send(address, message)
    }

// The connection to the store held back, the flooder told to go, and its
// first suspension said; the connection, to be let go.
fn flooded(address : Address(SinkMsg),
           sender : Address(SenderMsg)) : Foreign.Term receiving DeskMsg = {
    let connection = heldBack(address);
    send(sender, Go);
    receive {
        Suspended(_) -> Io.println(\"the host says the sender waits in a send\")
    };
    connection
}

// The desk's connection to the store held back, so that nothing that waits
// for the store leaves the host's buffer; the connection, to be let go.
fn heldBack(address : Address(SinkMsg)) : Foreign.Term = {
    let connection = connectionTo(Process.fromAddress(address));
    let _ = suspended(connection);
    connection
}

// Report §6.9, §8.7: the desk's connection to the store held back and the
// flooder waiting in a send to it, a process of the desk's that waits in a
// call of the store's sink, its request taken while the connection ran, is
// killed, and then an idle process of the desk's: the node's killer
// carries out both, and the desk says each one's Down.
fn kills(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let sender = flooder(address);
    let caller = Process.fromAddress(spawn(fn() = {
        let _ : Int = Address.callForever(address, Hold);
        Unit
    }));
    let idle = Process.fromAddress(spawn(fn() = held()));
    Io.println(\"found\");
    // until the test, which has seen the store hold the call, says so
    let _ = Io.readLine();
    let connection = flooded(address, sender);
    monitor(caller, fn(down) = Ended(name = \"the caller\", =down));
    monitor(idle, fn(down) = Ended(name = \"the idle process\", =down));
    kill(caller);
    kill(idle);
    endedSaid();
    endedSaid();
    let _ = resumed(connection);
    held()
}

// Report §6.9, §8.7: the desk's connection to the store held back and the
// flooder waiting in a send to it, a process of the desk's asks for a
// monitor of the store's sink, or for the end of one it made while the
// connection ran, which the node's reaper carries out; once the reaper has
// taken the ask, a process of the desk's is spawned and monitored with its
// spawn, and the desk says its Down.
fn reaps(address : Address(SinkMsg),
         before : (Process) -> Unit receiving AskerMsg,
         asked : (Process) -> Unit receiving AskerMsg) : Unit receiving DeskMsg = {
    let me = self();
    let sink = Process.fromAddress(address);
    let sender = flooder(address);
    let asker = spawn(fn() : Unit receiving AskerMsg =
                          askingTheReaper(me, sink, before, asked));
    receive {
        Ready -> Io.println(\"found\")
    };
    let connection = flooded(address, sender);
    taken(reaper(), sink, adapted(me, Taken));
    send(asker, Ask);
    receive {
        Taken(_) -> Unit
    };
    let _ = spawnMonitored(fn() = Unit, fn(down) = Ended(name = \"the local process\", =down));
    endedSaid();
    let _ = resumed(connection);
    held()
}

// What the desk's asker of the reaper does before the connection is held
// back, and what it asks once the desk says so; it then waits.
fn askingTheReaper(desk : Address(DeskMsg),
                   sink : Process,
                   before : (Process) -> Unit receiving AskerMsg,
                   asked : (Process) -> Unit receiving AskerMsg) : Unit receiving AskerMsg = {
    before(sink);
    send(desk, Ready);
    receive {
        Ask -> asked(sink)
    };
    receive {
        SinkEnded(_) -> Unit
    }
}

// Report Appendix E.21, §8.7: the desk's connection to the store held back
// and the flooder waiting in a send to it, the desk says what
// `Process.status` answers of the flooder, and then lets the connection go.
fn reads(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let sender = flooder(address);
    Io.println(\"found\");
    let connection = flooded(address, sender);
    let activity =
        Optional.map(Process.status(Process.fromAddress(sender)), fn(status) = status.activity);
    Io.println(\"the sender's activity: \" <> Io.show(activity));
    let _ = resumed(connection);
    held()
}

// The next Down a monitor of the desk's gives, said.
fn endedSaid() : Unit receiving DeskMsg =
    receive {
        Ended(=name, =down) -> Io.println(name <> \" ended: \" <> Io.show(down.reason))
    }

// Report §6.6, §6.9, §8.7: a caller of the store's waits on the desk's
// callee. Once the callee holds the question, the desk's connection to the
// store is held back as holding holds it, and the callee answers with the
// bytes, its answer waiting to be placed: a small one behind the flooder's
// megabyte, placed not at all, or one above the buffer, placed in part. The
// desk kills the callee and then lets the connection go.
fn answeredWhileHeld(bytes : Bytes,
                     holding : () -> Foreign.Term receiving DeskMsg) : Unit receiving DeskMsg = {
    let callee = calleeWatched();
    send(found(storeWatch), Call(callee));
    questioned();
    let connection = holding();
    send(callee, AnswerWith(bytes));
    heldSaid(\"the callee\");
    killedSaid(Process.fromAddress(callee));
    let _ = resumed(connection);
    held()
}

// Report §8.7: the desk's connection to the store held back, a sender of a
// message above the buffer waits in its send with part of it placed, and a
// sender of a small one with none of it placed. Each is killed, and then an
// idle process, each monitored here and by the third node's watcher, which
// monitors no other. Once the test says so, the desk lets the connection go.
fn sentWhileHeld(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let third = found(thirdWatch);
    let largeSender = sender(address, Whole(whole()), fn(_) = Held(\"the large sender\"));
    let smallSender = sender(address, Next, fn(_) = Held(\"the small sender\"));
    let idle = Process.fromAddress(spawn(fn() = held()));
    watched([third], \"the large sender\", Process.fromAddress(largeSender));
    watched([third], \"the small sender\", Process.fromAddress(smallSender));
    watched([third], \"the idle process\", idle);
    let connection = heldBack(address);
    wentAndHeld(largeSender, \"the large sender\");
    wentAndHeld(smallSender, \"the small sender\");
    killedSaid(Process.fromAddress(largeSender));
    killedSaid(Process.fromAddress(smallSender));
    killedSaid(idle);
    // the test has read the third node's lines first
    letGoWhenTold(connection)
}

// Report §6.9, §8.7: a process of the desk's in no send, monitored by the
// store's watcher, the third node's and here, faults while the flooder
// waits in its send to the store, the connection held back. Once the test
// says so, the desk lets the connection go.
fn faultedWhileHeld(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let faulting = spawn(fn() : Unit receiving SenderMsg = faultingOnGo());
    watched([found(storeWatch), found(thirdWatch)],
            \"the faulting process\",
            Process.fromAddress(faulting));
    let connection = flooded(address, flooder(address));
    send(faulting, Go);
    endedSaid();
    // the test has read the desk's line first
    letGoWhenTold(connection)
}

fn faultingOnGo() : Unit receiving SenderMsg =
    receive {
        Go -> fault(\"the faulting process faulted\")
    }

// Report §8.7: the desk's connection to the store held back, a sender of a
// message above the buffer, monitored here and by the third node's
// watcher, is killed while its send waits. The desk then loses the
// connection, by ending the process of the host's that writes it. Once the
// test says both nodes have run the loss, the desk asks the sink how many
// messages it has taken, over a connection that the call opens again.
fn lostWhileHeld(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let largeSender = sender(address, Whole(whole()), fn(_) = Held(\"the large sender\"));
    watched([found(thirdWatch)], \"the large sender\", Process.fromAddress(largeSender));
    let connection = heldBack(address);
    wentAndHeld(largeSender, \"the large sender\");
    killedSaid(Process.fromAddress(largeSender));
    let _ = exited(connection, Foreign.atom(\"kill\"));
    // until the test, which has seen both nodes say the loss, says so
    let _ = Io.readLine();
    Io.println(\"the sink has taken: \" <> Io.show(Address.call(address, Ping, waitMs())));
    held()
}

// Report §6.6, §6.9, §8.7: a caller of the third node's and one of the
// desk's wait on the desk's callee. Once the callee holds both questions,
// the desk's connection to the store held back, the callee sends the sink a
// message above the buffer, waits in its send, and is killed. Once the test
// says so, the desk lets the connection go.
fn calledWhileHeld(address : Address(SinkMsg)) : Unit receiving DeskMsg = {
    let callee = calleeWatched();
    send(found(thirdWatch), Call(callee));
    questioned();
    let _ = spawn(fn() = calling(\"the desk\", callee));
    questioned();
    let connection = heldBack(address);
    send(callee, SendTo(address));
    heldSaid(\"the callee\");
    killedSaid(Process.fromAddress(callee));
    // the test has seen the desk's caller end first
    letGoWhenTold(connection)
}

// The desk's callee, monitored here, each time the host suspends it in its
// send told to the desk.
fn calleeWatched() : Address(CalleeMsg) receiving DeskMsg = {
    let me = self();
    let callee = spawn(fn() : Unit receiving CalleeMsg = serving(me, []));
    watch(Process.fromAddress(callee), adapted(me, fn(_) = Held(\"the callee\")));
    watched([], \"the callee\", Process.fromAddress(callee));
    callee
}

// Report §6.6: the desk's callee, which tells the desk of each question it
// holds; it answers each it holds with the bytes it is given, or sends the
// sink a message above the buffer and answers none.
fn serving(desk : Address(DeskMsg), replies : List(Reply(Bytes))) : Unit receiving CalleeMsg =
    receive {
        Question(reply) -> {
            send(desk, Questioned);
            serving(desk, reply :: replies)
        }
      | AnswerWith(bytes) ->
            List.forEach(replies, fn(reply) = answer(reply, bytes))
      | SendTo(address) ->
            send(address, Chunk(whole()))
    }

// Until the callee says it holds a question.
fn questioned() : Unit receiving DeskMsg =
    receive {
        Questioned -> Unit
    }

// Report §6.9: a watcher of the store's or the third node's, at its place,
// which monitors each process it is asked to, says each Down its monitors
// give it, and calls the desk's callee where it is asked to.
fn watching(place : String) : Unit receiving WatchMsg =
    receive {
        Watch(=name, =process, =to) -> {
            monitor(process, fn(down) = Saw(=name, =down));
            send(to, Watching);
            watching(place)
        }
      | Call(callee) -> {
            let _ = spawn(fn() = calling(place, callee));
            watching(place)
        }
      | Saw(=name, =down) -> {
            Io.println(place <> \" saw \" <> name <> \": \" <> Io.show(down.reason));
            watching(place)
        }
    }

// Report §6.6: a call of the desk's callee, what it answered said, an
// answer by its size and whether it is the pattern whole, and how long the
// call took.
fn calling(place : String, callee : Address(CalleeMsg)) : Unit = {
    let began = Clock.monotonic();
    let answered = match Address.call(callee, Question, waitMs()) {
        Some(bytes) ->
            \"Some(\"
                <> Int.toString(Bytes.size(bytes))
                <> \" bytes, whole: \"
                <> Io.show(bytes == pattern(Bytes.size(bytes) / 8))
                <> \")\"
      | None ->
            \"None\"
    };
    let took = Int.toString(Clock.monotonic() - began);
    Io.println(place <> \"'s caller got: \" <> answered <> \" after \" <> took <> \" ms\")
}

// The process monitored by each watcher in turn under the name, once each
// says it is, and here.
fn watched(watchers : List(Address(WatchMsg)),
           name : String,
           process : Process) : Unit receiving DeskMsg = {
    List.forEach(watchers, fn(watcher) = {
        send(watcher, Watch(=name, =process, to = self()));
        receive {
            Watching -> Unit
        }
    });
    monitor(process, fn(down) = Ended(=name, =down))
}

// Until the host says the named process waits in a send, which is said.
fn heldSaid(name : String) : Unit receiving DeskMsg =
    receive {
        Held(which) when which == name ->
            Io.println(\"the host says \" <> name <> \" waits in a send\")
    }

// The process killed, and its Down said.
fn killedSaid(process : Process) : Unit receiving DeskMsg = {
    kill(process);
    endedSaid()
}

// The sender told to go, until the host says it waits in its send.
fn wentAndHeld(sender : Address(SenderMsg), name : String) : Unit receiving DeskMsg = {
    send(sender, Go);
    heldSaid(name)
}

// Once the test says so, the connection let go; then until the node is
// stopped.
fn letGoWhenTold(connection : Foreign.Term) : Unit receiving DeskMsg = {
    let _ = Io.readLine();
    let _ = resumed(connection);
    held()
}

// Report §12.7, §8.7: the store and the third node bare, each spawn of the
// desk's there carrying its code through the exchange. The desk holds its
// exchange back while the store asks it for the reach of a function the
// store lacks, and lets it go once the connection to the store is held
// back and the flooder waits in a send to it: the exchange answers the
// store, and an exchange with the third node then completes, the desk's
// spawn there starting.
fn exchanges() : Unit receiving DeskMsg = {
    let me = self();
    let address = match Peer.spawn(\"store\", sinking, waitMs()) {
        Right(address) -> address
      | Left(failure) -> fault(Io.show(failure))
    };
    let sender = flooder(address);
    let exchange = whereis(Foreign.atom(\"ern_exchange\"));
    let _ = suspended(exchange);
    handedOn(whereis(Foreign.atom(\"ern_gateway\")),
             exchange,
             Process.fromAddress(address),
             adapted(me, Taken));
    let _ = spawn(fn() = {
        let _ = Peer.spawn(\"store\", held, waitMs());
        Unit
    });
    receive {
        Taken(_) -> Io.println(\"the store asked\")
    };
    let connection = flooded(address, sender);
    let _ = resumed(exchange);
    Io.println(\"spawned on the third: \" <> Io.show(Peer.spawn(\"third\", held, waitMs())));
    let _ = resumed(connection);
    held()
}

fn starting(desk : Address(DeskMsg), address : Address(SinkMsg)) : Unit receiving SenderMsg =
    receive {
        Go -> sending(desk, address, Bytes.repeat(<<0>>, 262144), 1)
    }

// A send, then what was asked meanwhile served, until a send the loss ended.
fn sending(desk : Address(DeskMsg),
           address : Address(SinkMsg),
           chunk : Bytes,
           index : Int) : Unit receiving SenderMsg = {
    let began = Clock.monotonic();
    send(address, Chunk(chunk));
    let ended = Clock.monotonic();
    let asked = served([]);
    if isConnected(Process.fromAddress(address)) then
        sending(desk, address, chunk, index + 1)
    else {
        Io.println(\"the sender went on after send \" <> Int.toString(index));
        send(desk, Returned(Waited(=index, =began, =ended, =asked)))
    }
}

// The moments of what this process was asked, as it serves each in turn.
fn served(acc : List(Int)) : List(Int) receiving SenderMsg =
    receive {
        Asked(moment) -> served(moment :: acc)
      | after 0 -> acc
    }
"/utf8>>, ern_harness:wait_ms_declaration()]),
    ok = file:write_file(filename:join(Root, "ern_nodes_buffer.erl"), buffer_host()),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_buffer.erl"), [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    filename:join(Root, "buffer.erc").

%% A host module for the buffer's program. It gives the host's report of
%% each time a process is suspended in a send to another node,
%% `erlang:system_monitor`'s `busy_dist_port`, each report's count sent to
%% an address. One process of its own, made before the program sends, holds
%% every watch of the node's, since the host has one system monitor; one
%% process of the program's asks for a watch at a time.
%%
%% It answers whether the host holds a connection to a process's node, and
%% the process of the host's that writes what waits for that node to the
%% connection; and the moment a process takes a message, or sends another
%% process one, that names among its elements a process or a reference of a
%% peer's node, which the host traces to a process of its own made before
%% the program asks. The host traces what a process takes only as the
%% process runs, so a suspended process's mailbox is watched through what
%% is sent to it.
%%
%% It holds back the connection to a process's node by a process of its
%% own, which outlives the program's processes, since a suspension ends
%% with the process that made it, until a named pipe it reads is opened and
%% closed (hold/2), which the ending's program asks of it (ending_build/1).
buffer_host() ->
    <<"
-module(ern_nodes_buffer).
-export([watch/2, is_connected/1, taken/3, handed_on/4, connection_to/1, hold/2]).
watch(Pid, To) ->
    Watcher = case whereis(ern_nodes_watcher) of
                  undefined -> started_watcher();
                  Running -> Running
              end,
    Watcher ! {watch, Pid, To, self()},
    receive {ern_nodes_watching, Pid} -> 'Unit' end.
started_watcher() ->
    Caller = self(),
    Watcher = spawn(fun() ->
                        true = register(ern_nodes_watcher, self()),
                        _ = erlang:system_monitor(self(), [busy_dist_port]),
                        Caller ! {ern_nodes_started, self()},
                        watched(#{})
                    end),
    receive {ern_nodes_started, Watcher} -> Watcher end.
watched(Watches) ->
    receive
        {watch, Pid, To, From} ->
            From ! {ern_nodes_watching, Pid},
            watched(Watches#{Pid => {To, 0}});
        {monitor, Pid, busy_dist_port, _} ->
            case Watches of
                #{Pid := {To, Count}} ->
                    To ! Count + 1,
                    watched(Watches#{Pid := {To, Count + 1}});
                #{} ->
                    watched(Watches)
            end
    end.
is_connected(Pid) ->
    lists:member(node(Pid), nodes(connected)).
connection_to(Pid) ->
    {_, Controller} = lists:keyfind(node(Pid), 1, erlang:system_info(dist_ctrl)),
    Controller.
taken(Pid, Peer, To) ->
    traced(Pid, ['receive'], fun() -> took(Pid, node(Peer), To) end).
took(Pid, Node, To) ->
    receive
        {trace, Pid, 'receive', Message} ->
            case names(Message, Node) of
                true -> _ = erlang:trace(Pid, false, ['receive']), To ! 1;
                false -> took(Pid, Node, To)
            end
    end.
handed_on(Pid, Other, Peer, To) ->
    traced(Pid, [send], fun() -> handed(Pid, Other, node(Peer), To) end).
handed(Pid, Other, Node, To) ->
    receive
        {trace, Pid, send, Message, Other} ->
            case names(Message, Node) of
                true -> _ = erlang:trace(Pid, false, [send]), To ! 1;
                false -> handed(Pid, Other, Node, To)
            end;
        {trace, Pid, send, _, _} ->
            handed(Pid, Other, Node, To)
    end.
traced(Pid, Flags, Trace) ->
    Caller = self(),
    Tracer = spawn(fun() ->
                       _ = erlang:trace(Pid, true, Flags),
                       Caller ! {ern_nodes_tracing, self()},
                       Trace()
                   end),
    receive {ern_nodes_tracing, Tracer} -> 'Unit' end.
names(Message, Node) when is_tuple(Message) ->
    lists:any(fun(Named) ->
                  (is_pid(Named) orelse is_reference(Named)) andalso node(Named) =:= Node
              end,
              tuple_to_list(Message));
names(_, _) ->
    false.
hold(Pid, Pipe) ->
    Caller = self(),
    Controller = connection_to(Pid),
    Holder = spawn(fun() ->
                       true = erlang:suspend_process(Controller),
                       Caller ! {ern_nodes_held, self()},
                       Reader = open_port({spawn_executable, \"/bin/cat\"},
                                          [{args, [Pipe]}, exit_status]),
                       receive {Reader, {exit_status, _}} -> ok end,
                       true = erlang:resume_process(Controller)
                   end),
    receive {ern_nodes_held, Holder} -> 'Unit' end.
">>.

%% The ending's tests' program, built in Base beside the host module it asks
%% of the host, the buffer's (buffer_host/0); answers its `.erc`.
ending_build(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "ending.ern"), [<<"
// Report §8.6, §8.7, §12.6: a node's end while what its processes send
// waits for a peer. The store offers a sink and a watcher, and the third
// node a watcher. The desk finds them and holds its connection to the store
// back by a process of the host's, which outlives the program's processes,
// until the test lets it go; and then the desk's program ends.
//
// Ended: a sender of the desk's waits in its send of a message above the
// buffer to the sink, watched from the store and the third node, two
// callers of the third's waiting on it, and the third's watcher monitors an
// idle process of the desk's too. Faulted: under a terminal, the entry
// process is the sender, and keys that are not UTF-8 end the program with
// its fault. Window: the desk hands the third node its idle process and an
// echo, which a late node fetches there; the late node dials the desk only
// once the desk stops, and asks it, as the third node does.

// The host's report of each time the process is suspended in a send to
// another node, its count sent to the address.
foreign fn watch(process : Process, to : Address(Int)) : Unit =
    \"ern_nodes_buffer:watch/2\"

// The connection to the process's node held back by a process of the
// host's, until the named pipe is opened and closed.
foreign fn hold(process : Process, pipe : String) : Unit =
    \"ern_nodes_buffer:hold/2\"

// What the sink takes: a message, or a request for how many it has taken.
type SinkMsg = Whole(Bytes) | Count(Reply(Int))

type DeskMsg = Held | Watching | Called | Subscribed

// What the sender is asked: to send, or a caller's request, which it takes
// and never answers.
type SenderMsg = Go | Ask(Reply(Unit))

type ConductorMsg = Pressed(Terminal.Event) | Told

type EchoMsg = Echo(Reply(String))

// What the desk hands the third node for the late node.
type Handed = Handed(echo : Address(EchoMsg), idle : Process)

// What a watcher is asked: to monitor a process under a name, telling the
// asker once the monitor stands, or to call a sender; each Down its
// monitors give it; and what the desk hands it, and the late node fetches.
type WatchMsg =
    Watch(name : String, process : Process, to : Address(DeskMsg))
  | Call(Address(SenderMsg))
  | Saw(name : String, down : Down)
  | Hand(Handed)
  | Fetch(Reply(Handed))

let sink : Peer.Service(SinkMsg) = Peer.service(\"sink\")

let storeWatch : Peer.Service(WatchMsg) = Peer.service(\"store-watch\")

let thirdWatch : Peer.Service(WatchMsg) = Peer.service(\"third-watch\")

let deskEcho : Peer.Service(EchoMsg) = Peer.service(\"desk-echo\")

export fn main() : Unit receiving DeskMsg =
    match Os.arguments {
        [\"store\"] ->
            stored()
      | [\"third\"] -> {
            let _ = Peer.offer(thirdWatch, spawn(fn() = watching(\"the third\", None)));
            Io.println(\"offered\");
            askedWhenTold()
        }
      | [\"desk\", \"ended\", size, pipe] ->
            ended(sized(size), pipe)
      | [\"desk\", \"faulted\", size, pipe] ->
            faulted(sized(size), pipe)
      | [\"desk\", \"window\", pipe] ->
            windowed(pipe)
      | [\"late\"] ->
            late()
      | _ ->
            Unit
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit receiving DeskMsg =
    receive {
        _ -> held()
    }

fn found(service : Peer.Service(m)) : Address(m) =
    match Peer.find(service, waitMs()) {
        Right(address) -> address
      | Left(failure) -> fault(Io.show(failure))
    }

fn sized(text : String) : Int =
    Optional.withDefault(String.toInt(text), 0)

// Eight bytes count times over, from which the sink tells a message whole.
fn pattern(count : Int) : Bytes =
    Bytes.repeat(<<1, 2, 3, 4, 5, 6, 7, 8>>, count)

// The store's sink and watcher offered; then, each time the test says so,
// how many messages the sink has taken, said.
fn stored() : Unit receiving DeskMsg = {
    let sinking = spawn(fn() = taking(0));
    let _ = Peer.offer(sink, sinking);
    let _ = Peer.offer(storeWatch, spawn(fn() = watching(\"the store\", None)));
    Io.println(\"offered\");
    countedWhenTold(sinking)
}

fn countedWhenTold(sinking : Address(SinkMsg)) : Unit receiving DeskMsg =
    match Io.readLine() {
        Some(_) -> {
            Io.println(\"the sink has taken: \" <> Io.show(Address.call(sinking, Count, waitMs())));
            countedWhenTold(sinking)
        }
      | None ->
            held()
    }

// The sink, count the messages it has taken, each said with whether it
// came whole.
fn taking(count : Int) : Unit receiving SinkMsg =
    receive {
        Whole(bytes) -> {
            Io.println(\"took \"
                           <> Int.toString(Bytes.size(bytes))
                           <> \" bytes, whole: \"
                           <> Io.show(bytes == pattern(Bytes.size(bytes) / 8)));
            taking(count + 1)
        }
      | Count(reply) -> {
            answer(reply, count);
            taking(count)
        }
    }

// Report §8.7, Appendix E.27: what the test's line names asked of the
// desk and said, a find of its echo or how busy it is.
fn askedWhenTold() : Unit receiving DeskMsg =
    match Io.readLine() {
        Some(\"find\") -> {
            Io.println(\"found: \" <> Io.show(Peer.find(deskEcho, waitMs())));
            askedWhenTold()
        }
      | Some(\"utilization\") -> {
            Io.println(\"utilization: \" <> Io.show(Peer.utilization(\"desk\", waitMs())));
            askedWhenTold()
        }
      | Some(_) ->
            askedWhenTold()
      | None ->
            held()
    }

// Report §6.9, §6.6: a watcher at its place, which monitors each process it
// is asked to and says each Down its monitors give it, calls a sender from
// two callers of its own, and keeps what the desk hands it.
fn watching(place : String, handed : Optional(Handed)) : Unit receiving WatchMsg =
    receive {
        Watch(=name, =process, =to) -> {
            monitor(process, fn(down) = Saw(=name, =down));
            send(to, Watching);
            watching(place, handed)
        }
      | Call(sender) -> {
            let _ = spawn(fn() = calling(place, sender));
            let _ =
                spawnMonitored(fn() = callingForever(sender),
                               fn(down) = Saw(name = \"the forever caller\", =down));
            watching(place, handed)
        }
      | Saw(=name, =down) -> {
            Io.println(place <> \" saw \" <> name <> \": \" <> Io.show(down.reason));
            watching(place, handed)
        }
      | Hand(given) ->
            watching(place, Some(given))
      | Fetch(reply) -> {
            match handed {
                Some(given) -> answer(reply, given)
              | None -> Unit
            };
            watching(place, handed)
        }
    }

// Report §6.6: a call of the sender given the harness's time for one wait,
// what it answered said, and how long it took.
fn calling(place : String, sender : Address(SenderMsg)) : Unit = {
    let began = Clock.monotonic();
    let got = Address.call(sender, Ask, waitMs());
    Io.println(place
                   <> \"'s caller got: \"
                   <> Io.show(got)
                   <> \" after \"
                   <> Int.toString(Clock.monotonic() - began)
                   <> \" ms\")
}

// Report §6.6: a call of the sender with no time, whose fault the watcher's
// monitor says.
fn callingForever(sender : Address(SenderMsg)) : Unit =
    Address.callForever(sender, Ask)

// The process monitored by each watcher in turn under the name, once each
// says it is.
fn watched(watchers : List(Address(WatchMsg)),
           name : String,
           process : Process) : Unit receiving DeskMsg =
    List.forEach(watchers, fn(watcher) = {
        send(watcher, Watch(=name, =process, to = self()));
        receive {
            Watching -> Unit
        }
    })

// A sender of the desk's that sends the sink the message once told to go;
// the host's report that it waits in its send said to the desk as Held.
fn sender(address : Address(SinkMsg), message : SinkMsg) : Address(SenderMsg) receiving DeskMsg = {
    let me = self();
    let spawned = spawn(fn() : Unit receiving SenderMsg = takingCalls(me, address, message));
    watch(Process.fromAddress(spawned), adapted(me, fn(_) = Held));
    spawned
}

// Until it is told to go, the sender takes each caller's request, answering
// none, and tells the desk.
fn takingCalls(desk : Address(DeskMsg),
               address : Address(SinkMsg),
               message : SinkMsg) : Unit receiving SenderMsg =
    receive {
        Ask(_) -> {
            send(desk, Called);
            takingCalls(desk, address, message)
        }
      | Go ->
            send(address, message)
    }

// Report §8.6, §8.7: the connection to the store held back, the sender
// waits in its send of a message of the size given, watched from the store
// and the third node, the third's two callers waiting on it; and an idle
// process watched from the third. Once the test says so, the entry process
// returns.
fn ended(size : Int, pipe : String) : Unit receiving DeskMsg = {
    let address = found(sink);
    let third = found(thirdWatch);
    let large = sender(address, Whole(pattern(size / 8)));
    let idle = Process.fromAddress(spawn(fn() = held()));
    watched([found(storeWatch), third], \"the sender\", Process.fromAddress(large));
    watched([third], \"the idle process\", idle);
    send(third, Call(large));
    receive {
        Called -> Unit
    };
    receive {
        Called -> Unit
    };
    hold(Process.fromAddress(address), pipe);
    send(large, Go);
    receive {
        Held -> Io.println(\"the host says the sender waits in a send\")
    };
    // until the test says the program ends
    let _ = Io.readLine();
    Unit
}

// Report §8.6, §8.7, §12.1: under a terminal, the connection to the store
// held back, the entry process waits in its send of a message of the size
// given, watched from the store and the third node, and an idle process
// watched from the third. A conductor subscribes to keys and says when the
// host holds the entry process in its send; keys that are not UTF-8 then
// end the program with the entry process's fault.
fn faulted(size : Int, pipe : String) : Unit receiving DeskMsg = {
    let me = self();
    let address = found(sink);
    let third = found(thirdWatch);
    let entry = Process.current();
    let idle = Process.fromAddress(spawn(fn() = held()));
    watched([found(storeWatch), third], \"the entry process\", entry);
    watched([third], \"the idle process\", idle);
    hold(Process.fromAddress(address), pipe);
    let _ = spawn(fn() : Unit receiving ConductorMsg = conducting(me, entry));
    receive {
        Subscribed -> Unit
    };
    send(address, Whole(pattern(size / 8)))
}

fn conducting(desk : Address(DeskMsg), entry : Process) : Unit receiving ConductorMsg = {
    watch(entry, adapted(self(), fn(_) = Told));
    match Terminal.subscribe(Pressed) {
        Right(_) -> send(desk, Subscribed)
      | Left(failure) -> fault(Io.show(failure))
    };
    conducted()
}

fn conducted() : Unit receiving ConductorMsg =
    receive {
        Told -> {
            Io.println(\"the host says the entry process waits in a send\");
            conducted()
        }
      | Pressed(_) ->
            conducted()
    }

// Report §8.7: the connection to the store held back, so that the desk's
// end waits for the store; an idle process watched from the third node and
// an echo offered, both handed to the third first. Once the test says so,
// the entry process returns.
fn windowed(pipe : String) : Unit receiving DeskMsg = {
    let address = found(sink);
    let third = found(thirdWatch);
    let idle = Process.fromAddress(spawn(fn() = held()));
    let echo = spawn(fn() = echoing());
    let _ = Peer.offer(deskEcho, echo);
    // the watcher keeps what is handed before it monitors
    send(third, Hand(Handed(=echo, =idle)));
    watched([third], \"the idle process\", idle);
    hold(Process.fromAddress(address), pipe);
    Io.println(\"held\");
    // until the test says the program ends
    let _ = Io.readLine();
    Unit
}

fn echoing() : Unit receiving EchoMsg =
    receive {
        Echo(reply) -> {
            answer(reply, \"echo\");
            echoing()
        }
    }

// Report §8.7: the late node fetches from the third what the desk handed
// it. Once the test says so, while the desk stops, it asks how busy the desk
// is, which dials it, and then the rest in turn, each answer said, its
// monitors' Downs said by a watcher of its own; and once the test says so
// again, it monitors the idle process anew.
fn late() : Unit receiving DeskMsg = {
    let watcher = spawn(fn() = watching(\"the late node\", None));
    Io.println(\"ready\");
    let _ = Io.readLine();
    match Address.call(found(thirdWatch), Fetch, waitMs()) {
        Some(Handed(=echo, =idle)) -> {
            Io.println(\"fetched\");
            let _ = Io.readLine();
            askedInTheWindow(watcher, echo, idle);
            let _ = Io.readLine();
            watched([watcher], \"the idle process, after the end\", idle)
        }
      | None ->
            Io.println(\"fetched nothing\")
    };
    held()
}

fn askedInTheWindow(watcher : Address(WatchMsg),
                    echo : Address(EchoMsg),
                    idle : Process) : Unit receiving DeskMsg = {
    Io.println(\"utilization: \" <> Io.show(Peer.utilization(\"desk\", waitMs())));
    let told = List.any(Peer.utilizations(), fn(#(peer, _, _)) = peer == \"desk\");
    Io.println(\"told by the desk: \" <> Io.show(told));
    Io.println(\"found: \" <> Io.show(Peer.find(deskEcho, waitMs())));
    Io.println(\"called: \" <> Io.show(Address.call(echo, Echo, waitMs())));
    watched([watcher], \"the idle process, in the window\", idle);
    Io.println(\"spawned: \" <> Io.show(Peer.spawn(\"desk\", fn() = Unit, waitMs())));
    Io.println(\"computed: \" <> Io.show(Peer.compute(\"desk\", fn() = 42, waitMs())));
    Io.println(\"asked in the window\")
}
"/utf8>>, ern_harness:wait_ms_declaration()]),
    ok = file:write_file(filename:join(Root, "ern_nodes_buffer.erl"), buffer_host()),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_buffer.erl"), [{outdir, Root}]),
    0 = ern_harness:built([Root]),
    filename:join(Root, "ending.erc").

%% The size of the message the desk's sender waits to send in the ending's
%% tests, in bytes: 28 MB, many times the host's buffer for a peer (report
%% §8.7, *Messages*), so that its rest is rarely placed before the end.
sent_bytes() ->
    "28000000".

%% The window's nodes: the ending's three of watched_nodes/1, the desk
%% listening too, and a late node that listens nowhere and dials the third
%% and the desk, which list it with no address. The late node finds the
%% third's watcher at the third and the desk's echo at the desk, and so does
%% the third the desk's echo.
window_nodes(Base) ->
    [PortStore, PortThird, PortDesk] = [ern_harness:free_port() || _ <- [1, 2, 3]],
    Store = ern_harness:made(Base, "store", PortStore),
    Third = ern_harness:made(Base, "third", PortThird),
    Desk = ern_harness:made(Base, "desk", PortDesk),
    Late = ern_harness:made(Base, "late", none),
    ern_harness:lists(Store, [{"desk", Desk, none}]),
    ern_harness:lists(Third, [{"desk", Desk, none}, {"late", Late, none}]),
    ern_harness:lists(Desk,
                      [{"store", Store, PortStore}, {"third", Third, PortThird},
                       {"late", Late, none}]),
    ern_harness:lists(Late, [{"third", Third, PortThird}, {"desk", Desk, PortDesk}]),
    [ern_harness:edit(Dir, fun(Conf) -> Conf#{<<"services">> => Services} end)
     || {Dir, Services} <- [{Desk, #{<<"sink">> => [<<"store">>],
                                    <<"third-watch">> => [<<"third">>]}},
                            {Third, #{<<"desk-echo">> => [<<"desk">>]}},
                            {Late, #{<<"third-watch">> => [<<"third">>],
                                     <<"desk-echo">> => [<<"desk">>]}}]],
    {Store, Desk, Third, Late}.

%% The named pipe in Base that the desk's holder of its connection to the
%% store reads (ern_nodes_buffer:hold/2).
held_pipe(Base) ->
    Pipe = filename:join(Base, "held.pipe"),
    [] = os:cmd("mkfifo " ++ Pipe),
    Pipe.

%% The desk's connection to the store let go: its holder's named pipe opened
%% and closed, which waits until the holder reads it: one step.
let_go(Pipe) ->
    ?assertEqual({0, ""}, finished([": > ", Pipe])).

%% What each line of Out that begins with Prefix says after it.
said_after(Out, Prefix) ->
    [lists:nthtail(length(Prefix), Line)
     || Line <- string:split(Out, "\n", all), lists:prefix(Prefix, Line)].

%% Report §8.7: the store took the message of the sender, Name, whole or
%% none of it, as its sink says when asked after the end, and its watcher
%% was told the death's own Reason exactly where it took it, and else
%% Unreachable, once.
taken_where_told(StoreOut, Name, Reason) ->
    Took = said_after(StoreOut, "took "),
    case said_after(StoreOut, "the store saw " ++ Name ++ ": ") of
        [Reason] ->
            ?assertEqual([sent_bytes() ++ " bytes, whole: true"], Took),
            ern_harness:has(StoreOut, "the sink has taken: Some(1)");
        ["Unreachable"] ->
            ?assertEqual([], Took),
            ern_harness:has(StoreOut, "the sink has taken: Some(0)")
    end.

%% Words run under a terminal of their own through the pseudo-terminal's
%% harness, with its Steps (ern_pty:tried/3), in a process of its own, so
%% that the test waits on other nodes meanwhile. Answers what waits for the
%% harness's end and answers what tried/3 answers, counting the harness's
%% waits as the test's steps, each expect's and the run's end's.
under_a_terminal(Words, Steps) ->
    Test = self(),
    Command = lists:flatten(Words),
    Runner = spawn_link(fun() -> Test ! {self(), ern_pty:tried(Command, Steps, [])} end),
    Waits = length([Text || {expect, Text} <- Steps]) + 1,
    fun() ->
        ern_harness:step({under_a_terminal, Command}, Waits),
        receive
            {Runner, Ran} -> Ran
        after (Waits + 1) * ?WAIT_MS ->
            erlang:error({still_running, Command})
        end
    end.

%% Report §6.10, §8.7, Appendix E.28: a counter's two builds, built in
%% Base: the first, whose node runs counters on `count`, and the second,
%% which keeps `count` as the first wrote it beside the new `countAloud`, with
%% a binding a bare node evaluates only once Code.load loads the module,
%% and the tool that moves a node's counters and loads a module on a bare
%% node. The first build's `.erc`, the second's counter, and the tool's.
upgraded_builds(Base) ->
    [One, Two] = [filename:join([Base, "builds", Dir]) || Dir <- ["one", "two"]],
    [ok = filelib:ensure_path(Dir) || Dir <- [One, Two]],
    Count = "export type CounterMsg =\n"
            "    Inc(Int)\n"
            "  | Get(reply : Reply(Int))\n"
            "  | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit receiving CounterMsg)\n"
            "\n"
            "export fn count(total : Int) : Unit receiving CounterMsg =\n"
            "    receive {\n"
            "        Inc(amount) -> count(total + amount)\n"
            "      | Get(=reply) -> {\n"
            "            answer(reply, total);\n"
            "            count(total)\n"
            "        }\n"
            "      | Upgrade(=migrate, =next) -> next(migrate(total))\n"
            "    }\n"
            "\n"
            "// Report §6.10: what the counter's clients send, a type without\n"
            "// Upgrade, by which it is offered to other nodes.\n"
            "export type Public = Add(Int) | Total(reply : Reply(Int))\n"
            "\n"
            "export let public : Peer.Service(Public) = Peer.service(\"counter\")\n"
            "\n"
            "// Two counters spawned, and the entry process a third, offered through\n"
            "// an adapted address of its own.\n"
            "export fn serve() : Unit receiving CounterMsg = {\n"
            "    let _ = spawn(fn() = count(10));\n"
            "    let _ = spawn(fn() = count(20));\n"
            "    let _ = Peer.offer(public, adapted(self(), fn(message) = match message {\n"
            "        Add(amount) -> Inc(amount)\n"
            "      | Total(=reply) -> Get(=reply)\n"
            "    }));\n"
            "    Io.println(\"serving\");\n"
            "    count(0)\n"
            "}\n",
    CountAloud = "\n"
                 "// The second build's loop, which says each total it reaches.\n"
                 "export fn countAloud(total : Int) : Unit receiving CounterMsg =\n"
                 "    receive {\n"
                 "        Inc(amount) -> {\n"
                 "            Io.println(\"countAloud \" <> Int.toString(total + amount));\n"
                 "            countAloud(total + amount)\n"
                 "        }\n"
                 "      | Get(=reply) -> {\n"
                 "            answer(reply, total);\n"
                 "            countAloud(total)\n"
                 "        }\n"
                 "      | Upgrade(=migrate, =next) -> next(migrate(total))\n"
                 "    }\n"
                 "\n"
                 "// Report §8.5, §11.1: a computed binding, which a bare node evaluates\n"
                 "// when Code.load loads the module there.\n"
                 "export let start : Int = 99 + 1\n"
                 "\n"
                 "export fn fromStart() : Unit receiving Int =\n"
                 "    receive {\n"
                 "        n -> Io.println(\"from start \" <> Int.toString(start + n))\n"
                 "    }\n",
    Tool = "type Report = Moved(count : Int, left : Int)\n"
           "\n"
           "export fn main() : Unit receiving Report =\n"
           "    match Os.arguments {\n"
           "        [node, bare, path] -> {\n"
           "            served(\"before\");\n"
           "            moved(node);\n"
           "            served(\"after\");\n"
           "            loaded(bare, path)\n"
           "        }\n"
           "      | _ -> Unit\n"
           "    }\n"
           "\n"
           "// Report §6.10, §6.5: the counter found as the service it offers, at a\n"
           "// type without Upgrade, added to through its adapted address and asked\n"
           "// its total, before its upgrade and after it.\n"
           "fn served(moment : String) : Unit =\n"
           "    match Peer.find(Counter.public, waitMs()) {\n"
           "        Right(counter) -> {\n"
           "            send(counter, Counter.Add(4));\n"
           "            let asked = fn(reply) = Counter.Total(=reply);\n"
           "            let total = Address.call(counter, asked, waitMs());\n"
           "            Io.println(moment <> \": \" <> Io.show(total))\n"
           "        }\n"
           "      | Left(failure) -> Io.println(moment <> \": \" <> Io.show(failure))\n"
           "    }\n"
           "\n"
           "// Report §6.10: every process on the peer that runs count moved to\n"
           "// countAloud and asked for its total, which countAloud answers, and then how\n"
           "// many still run count.\n"
           "fn moved(node : String) : Unit receiving Report = {\n"
           "    let tool = self();\n"
           "    match Peer.spawn(node, fn() = upgrade(tool), waitMs()) {\n"
           "        Right(_) -> receive {\n"
           "            Moved(=count, =left) ->\n"
           "                Io.println(\"moved \" <> Int.toString(count) <> \", left \"\n"
           "                           <> Int.toString(left))\n"
           "        }\n"
           "      | Left(failure) -> Io.println(\"moved: \" <> Io.show(failure))\n"
           "    }\n"
           "}\n"
           "\n"
           "fn upgrade(tool : Address(Report)) : Unit = {\n"
           "    let old = Code.running(Counter.count);\n"
           "    List.forEach(old, fn(process) =\n"
           "        send(process,\n"
           "             Counter.Upgrade(migrate = fn(n) = n, next = Counter.countAloud)));\n"
           "    List.forEach(old, fn(process) = send(process, Counter.Inc(1)));\n"
           "    let _ = List.map(old, fn(process) =\n"
           "        Address.call(process, fn(reply) = Counter.Get(=reply), waitMs()));\n"
           "    let left = Code.running(Counter.count);\n"
           "    send(tool, Moved(count = List.size(old), left = List.size(left)))\n"
           "}\n"
           "\n"
           "// Appendix E.28: a function whose reach names a binding the bare node\n"
           "// never ran, refused before Code.load loads its module there and run\n"
           "// after.\n"
           "fn loaded(bare : String, path : String) : Unit = {\n"
           "    Io.println(\"before load: \" <> started(bare));\n"
           "    let loading = Peer.compute(bare, fn() = Code.load(Path(path)), waitMs());\n"
           "    Io.println(\"load: \" <> Io.show(loading));\n"
           "    Io.println(\"after load: \" <> started(bare))\n"
           "}\n"
           "\n"
           "fn started(bare : String) : String =\n"
           "    match Peer.spawn(bare, Counter.fromStart, waitMs()) {\n"
           "        Right(_) -> \"Right\"\n"
           "      | Left(failure) -> Io.show(failure)\n"
           "    }\n",
    [ok = file:write_file(filename:join(Dir, File), unicode:characters_to_binary(Text))
     || {Dir, File, Text} <- [{One, "counter.ern", Count},
                              {Two, "counter.ern", Count ++ CountAloud},
                              {Two, "tool.ern", [Tool, ern_harness:wait_ms_declaration()]}]],
    0 = ern_harness:built([One]),
    0 = ern_harness:built([Two]),
    {filename:join(One, "counter.erc"), filename:join(Two, "counter.erc"),
     filename:join(Two, "tool.erc")}.

%% report §6.10, §8.7, §3.11, §6.5, Appendix E.28: an upgrade tool. A node
%% runs the first build's counters on `count`,
%% the entry process's offered through an adapted address of a type without
%% Upgrade; the tool, of the second build, finds it, adds to it and asks its
%% total, and spawns on the node a process that lists them by Code.running,
%% the code the node lacks, `countAloud` among it, crossing with the spawn, and
%% moves each to `countAloud` by its own Upgrade, its total kept, so that
%% `count` then lists none; the service, its address unchanged, then adds
%% and answers from `countAloud`.
%%
%% On a bare node, which holds no program, a spawn whose reach names a
%% binding is NotLoaded until a compute there runs Code.load of the module
%% with its reach from the load path, which evaluates the binding, and the
%% same spawn then runs.
%%
%% Written after the code; the service through the adapted address a
%% regression test, written after the code, and the tool's add and then its
%% call through that one address, from another node, answering the total
%% after the add, another (§6.4, §6.5): the counter's node applied each
%% message in a process of its own, and the call passed the add
code_upgrade_test_() ->
    ern_harness:nodes_test({waits, 13}, fun code_upgrade/1).

code_upgrade(Base) ->
    {CounterOne, CounterTwo, Tool} = upgraded_builds(Base),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", 0),
    C = ern_harness:made(Base, "c", 0),
    [ern_harness:lists(Dir, [{"a", A, none}]) || Dir <- [B, C]],
    {_, WaitB} = ern_harness:launched(B, [?ERN, " run --config-dir ", B, " --main serve ",
                                          CounterOne]),
    ern_harness:prints(B, "serving"),
    PortB = ern_harness:bound_port(B),
    WaitC = ern_harness:bare_started(C, []),
    ern_harness:lists(A, [{"b", B, PortB}, {"c", C, ern_harness:bound_port(C)}]),
    ern_harness:edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"b">>]}} end),
    {_, WaitA} = ern_harness:launched(A,
                                      [?ERN, " run --config-dir ", A, " ", Tool, " b c ",
                                       CounterTwo]),
    ?assertEqual(0, WaitA()),
    [ern_harness:prints(B, Line) || Line <- ["countAloud 5", "countAloud 11", "countAloud 21",
                                             "countAloud 9"]],
    ern_harness:stop(B, WaitB),
    ern_harness:stop(C, WaitC),
    {Out, _} = ern_harness:said(A),
    [ern_harness:has(Out, Line) || Line <- ["before: Some(4)", "moved 3, left 0", "after: Some(9)",
                                            "before load: Io.NotLoaded", "load: Right(Right(Unit))",
                                            "after load: Right"]].
