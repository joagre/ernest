%% Nodes on one machine (report §8.7, MVP 3.0): each node an `ern run
%% --config-dir` of its own, started as a person starts one, its lines read
%% from its standard error. The carrier's tests dial through a `foreign fn`
%% of the host's, which reaches the carrier and nothing of a program's; the
%% frame a gateway cannot read is sent by a host module on the program's
%% load path; a host that holds a peer's key and names itself as it likes
%% is a bare `erl` with the host's TLS distribution and the key's files.
%% `Peer`'s tests run the programs of `test/peers/`, one build whose store
%% and desk are two nodes; the tests of two builds (MVP 3.1) write a
%% program and build it twice, one function and one type changed.
-module(ern_nodes_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").
-include_lib("typer/include/ern_canonical.hrl").

-define(ERN, filename:absname("../bin/ern")).
%% The libraries `test/peers/`'s programs use, on every node's load path.
-define(LIBRARIES, [filename:absname("../build/libs/" ++ Library)
                    || Library <- ["balancer", "json", "load", "standing"]]).

tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_nodes_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% A test of real nodes, named by its function, given the directory it
%% makes them under, after which every node still running from a directory
%% there is killed, however the test ended, its time running out among the
%% ways: the cleanup is the fixture's, which outlives the test's process.
nodes_test(Seconds, Test) ->
    {name, Name} = erlang:fun_info(Test, name),
    {setup, fun tmp/0, fun killed/1,
     fun(Base) -> {timeout, Seconds, {atom_to_list(Name), fun() -> Test(Base) end}} end}.

%% Report §8.6, a node detecting no deadlock: each node whose ernest.pid is
%% still in a directory under Base killed, a stopped one among them. A test
%% that passed has stopped its nodes, and one a test killed left a file
%% naming a process that has ended.
killed(Base) ->
    lists:foreach(fun node_killed/1, filelib:wildcard(filename:join([Base, "*", "ernest.pid"]))).

%% The process a node's ernest.pid names killed, where it is a node, its
%% command line naming a configuration directory; a file gone meanwhile
%% names none.
node_killed(PidFile) ->
    Read = case file:read_file(PidFile) of
               {ok, Text} -> string:to_integer(string:trim(binary_to_list(Text)));
               {error, _} -> none
           end,
    case Read of
        {ProcessNumber, ""} when ProcessNumber > 0 ->
            Digits = integer_to_list(ProcessNumber),
            string:find(os:cmd("ps -o args= -p " ++ Digits), "--config-dir") =:= nomatch
                orelse os:cmd("kill -KILL " ++ Digits) =:= "";
        _ ->
            false
    end.

%% A port nothing holds now on the loopback interface.
free_port() ->
    {ok, Socket} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Socket),
    ok = gen_tcp:close(Socket),
    Port.

%% A configuration directory `ern config` made, listening on Listen, a
%% port of the loopback interface, or not at all.
made(Base, Name, Listen) ->
    Dir = filename:join(Base, Name),
    _ = ern_node:create(Dir),
    edit(Dir, fun(Conf) ->
                  case Listen of
                      none -> maps:remove(<<"listen">>, Conf);
                      Port -> Conf#{<<"listen">> => address(Port)}
                  end
              end),
    Dir.

address(Port) ->
    list_to_binary("127.0.0.1:" ++ integer_to_list(Port)).

edit(Dir, Change) ->
    File = filename:join(Dir, "ernest.conf"),
    {ok, Text} = file:read_file(File),
    ok = file:write_file(File, json:encode(Change(json:decode(Text)))).

public(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    maps:get(<<"public-key">>, json:decode(Text)).

%% Dir lists each of Peers, {Name, PeerDir, Port}, a port or none.
lists(Dir, Peers) ->
    edit(Dir, fun(Conf) ->
                  Conf#{<<"peers">> => [peer(Name, PeerDir, Port)
                                        || {Name, PeerDir, Port} <- Peers]}
              end).

peer(Name, Dir, none) ->
    #{<<"name">> => list_to_binary(Name), <<"public-key">> => public(Dir)};
peer(Name, Dir, Port) ->
    (peer(Name, Dir, none))#{<<"network-address">> => address(Port)}.

%% A node's name on the carrier.
name(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    atom_to_list(ern_carrier:name(Der)).

%% A node's key's digest, as a refusal names an unlisted key.
digest(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Der), lowercase)).

%% The test program, built in Root: it dials a peer, sends it a frame its
%% gateway cannot read, sends it a spawn of the function whose hash it is
%% given with a site that is not UTF-8, or waits, as its arguments say.
program(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "node.ern"), <<"
foreign fn connect(node : Foreign.Term) : Bool with m = \"net_kernel:connect_node/1\"
foreign fn frame(node : Foreign.Term) : Unit with m = \"ern_nodes_frame:send/1\"
foreign fn site(node : Foreign.Term, hash : String) : Unit with m = \"ern_nodes_frame:site/2\"

export fn main() : Unit with Unit =
    match Os.arguments {
        [\"connect\", peer] -> Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(peer))))
      | [\"frame\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(peer))));
            frame(Foreign.atom(peer));
            // until the test, which has seen the connection end, says so
            let _ = Io.readLine();
            Unit
        }
      | [\"site\", peer, hash] -> {
            Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(peer))));
            site(Foreign.atom(peer), hash);
            let _ = Io.readLine();
            Unit
        }
      | [\"hold\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(peer))));
            held()
        }
      | _ -> {
            Io.println(\"waiting\");
            held()
        }
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit with Unit = receive { _ -> held() }
">>),
    ok = file:write_file(filename:join(Root, "ern_nodes_frame.erl"), <<"
-module(ern_nodes_frame).
-export([send/1, site/2]).
send(Node) ->
    erlang:send({ern_gateway, Node}, unreadable),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), unreadable}),
    'Unit'.
site(Node, Hash) ->
    Spawned = {function, binary:decode_hex(Hash)},
    Frame = {spawn, make_ref(), Spawned, <<255>>, false},
    erlang:send({ern_gateway, Node}, {ern_frame, self(), Frame}),
    'Unit'.
">>),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_frame.erl"), [{outdir, Root}]),
    ok = file:write_file(filename:join(Root, "ern_nodes_client.erl"), client()),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_client.erl"), [{outdir, Root}]),
    0 = ern_cli:ern(["build", Root], group_leader()),
    filename:join(Root, "node.erc").

%% A host module for a bare `erl` that holds a peer's key: its port map,
%% which answers every name with the loopback port its command line gives,
%% and its run, which connects to the node its command line names, says
%% whether it could, asks the node its name over the connection, and, where
%% its command line says it waits, asks again once a line comes on its
%% standard input, ending at the input's end.
client() ->
    <<"
-module(ern_nodes_client).
-export([start_link/0, register_node/2, register_node/3, port_please/2, port_please/3,
         address_please/3, listen_port_please/2, names/1, main/0]).
start_link() -> ignore.
register_node(_, _) -> {ok, 1}.
register_node(_, _, _) -> {ok, 1}.
port_please(_, _) -> {port, port(), 6}.
port_please(_, _, _) -> {port, port(), 6}.
address_please(_, _, _) -> {ok, {127, 0, 0, 1}, port(), 6}.
listen_port_please(_, _) -> {ok, 0}.
names(_) -> {error, address}.
port() ->
    {ok, [[Port]]} = init:get_argument(ern_nodes_port),
    list_to_integer(Port).
main() ->
    {ok, [[Target]]} = init:get_argument(ern_nodes_target),
    Node = list_to_atom(Target),
    io:format(\"connect: ~p~n\", [net_kernel:connect_node(Node)]),
    io:format(\"call: ~p~n\", [called(Node)]),
    case init:get_argument(ern_nodes_wait) of
        {ok, _} ->
            _ = io:get_line(\"\"),
            io:format(\"after: ~p~n\", [called(Node)]);
        error ->
            ok
    end,
    halt().
called(Node) ->
    try erpc:call(Node, erlang, node, [], 10000) of
        Node -> ran
    catch
        error:{erpc, Reason} -> Reason
    end.
">>.

%% A bare `erl` that dials the node listening on Port as Name, presenting
%% the certificate and key given, with the cookie given, its module in
%% Root, and waiting for a line on its standard input before it asks again
%% where Wait says so; answers the port whose writes are its standard
%% input and whose messages are its standard output, and the function that
%% waits for its end and answers what it printed.
client(Root, Name, {Certificate, Key}, Cookie, Port, Target, Wait) ->
    Tls = lists:append([[Side ++ "_" ++ Option, Value]
                        || Side <- ["client", "server"],
                           {Option, Value} <- [{"certfile", Certificate}, {"keyfile", Key},
                                               {"verify", "verify_none"},
                                               {"versions", "tlsv1.3"}]]),
    Arguments = ["-noshell", "-pa", Root, "-name", Name, "-proto_dist", "inet_tls",
                 "-ssl_dist_opt" | Tls]
        ++ ["-epmd_module", "ern_nodes_client", "-start_epmd", "false", "-dist_listen", "false",
            "-connect_all", "false", "-setcookie", Cookie,
            "-ern_nodes_port", integer_to_list(Port), "-ern_nodes_target", Target]
        ++ [Flag || Flag <- ["-ern_nodes_wait"], Wait]
        ++ ["-s", "ern_nodes_client", "main"],
    Client = open_port({spawn_executable, os:find_executable("erl")},
                       [{args, Arguments}, exit_status, binary, stderr_to_stdout]),
    {Client, fun() -> collected(Client, <<>>) end}.

%% The files of a node's key in its configuration directory, its
%% certificate and its private key.
key_files(Dir) ->
    {filename:join(Dir, "certificate.pem"), filename:join(Dir, "private-key.pem")}.

%% A certificate signed with the key of a configuration directory that names
%% the host given, written beside the directory: the key is one node's, the
%% host another's.
forged(Dir, Host) ->
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
    File = Dir ++ ".forged.pem",
    ok = file:write_file(File, public_key:pem_encode([{'Certificate',
                                                        public_key:pkix_sign(Tbs, Key),
                                                        not_encrypted}])),
    {File, filename:join(Dir, "private-key.pem")}.

%% A node's key's host on the carrier.
host(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    ern_carrier:host(Der).

%% A node started in the background; answers what waits for its end.
start(Dir, Program, Arguments) ->
    {_Port, Wait} = started(Dir, Program, Arguments),
    Wait.

%% The same, with the port whose writes are the node's standard input. Its
%% standard output and standard error each go through a pipe that `tee`
%% reads, which writes the stream to a file beside the node's directory and
%% hands it to the node's watcher, so that a test waits on a line written
%% rather than reading the file again.
started(Dir, Program, Arguments) ->
    launched(Dir, [?ERN, " run --config-dir ", Dir,
                   [[" --load-path ", Library] || Library <- ?LIBRARIES], " ", Program,
                   [[" ", Argument] || Argument <- Arguments]]).

%% A shell that is a node, its source root SourceRoot, reading its inputs
%% from the port's writes, in line mode; its HOME a directory of its own,
%% so that no person's startup file runs. Its load path is LoadPath's
%% directories, a build among them, which a node reads whole at its start.
shell_started(Dir, SourceRoot) ->
    shell_started(Dir, SourceRoot, []).

shell_started(Dir, SourceRoot, LoadPath) ->
    Home = Dir ++ ".home",
    ok = filelib:ensure_path(Home),
    launched(Dir, ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Dir, " --source-root ",
                   SourceRoot, [[" --load-path ", Root] || Root <- LoadPath]]).

%% A node started by the command Words, its standard input the port's
%% writes.
launched(Dir, Words) ->
    Watcher = watcher(Dir),
    [Out, Err] = [piped(Watcher, Stream, Dir ++ Suffix)
                  || {Stream, Suffix} <- [{out, ".out"}, {err, ".err"}]],
    Command = lists:flatten([Words, " > ", Out, " 2> ", Err]),
    Port = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status]),
    {Port, fun() ->
               receive {Port, {exit_status, Status}} -> Status after 30000 -> timeout end
           end}.

%% The pipe a stream is written to, and its reader, which writes what comes
%% to File and tells Watcher of it, and of the stream's end.
piped(Watcher, Stream, File) ->
    Pipe = File ++ ".pipe",
    _ = file:delete(Pipe),
    [] = os:cmd("mkfifo " ++ Pipe),
    _ = spawn(fun() ->
                  Reader = open_port({spawn_executable, "/bin/sh"},
                                     [{args, ["-c", "exec tee " ++ File ++ " < " ++ Pipe]},
                                      binary, exit_status]),
                  teed(Reader, Watcher, Stream)
              end),
    Pipe.

teed(Reader, Watcher, Stream) ->
    receive
        {Reader, {data, Bytes}} -> Watcher ! {Stream, Bytes}, teed(Reader, Watcher, Stream);
        {Reader, {exit_status, _}} -> Watcher ! {Stream, ended}
    end.

%% A node's watcher, registered under its directory's name: what each of
%% its streams has said, and whether it has ended, and who waits for what.
%% A node started again from its directory has a watcher of its own.
watcher(Dir) ->
    Name = watcher_name(Dir),
    case whereis(Name) of
        undefined -> ok;
        Earlier -> unregister(Name), exit(Earlier, kill)
    end,
    Watcher = spawn(fun() -> watching(#{out => {<<>>, open}, err => {<<>>, open}}, []) end),
    true = register(Name, Watcher),
    Watcher.

watcher_name(Dir) ->
    list_to_atom("ern_nodes_tests " ++ Dir).

watching(Streams, Waiting) ->
    receive
        {Stream, ended} ->
            {Text, _} = maps:get(Stream, Streams),
            told(Streams#{Stream := {Text, ended}}, Waiting);
        {Stream, Bytes} when is_binary(Bytes) ->
            {Text, State} = maps:get(Stream, Streams),
            told(Streams#{Stream := {<<Text/binary, Bytes/binary>>, State}}, Waiting);
        {waiting, _, _, _} = Wait ->
            told(Streams, [Wait | Waiting]);
        {said, _} = Wait ->
            told(Streams, [Wait | Waiting])
    end.

%% The waits answered, the rest kept: a part once its stream holds it or
%% has ended without it, and the whole once both streams have ended.
told(Streams, Waiting) ->
    watching(Streams, [Wait || Wait <- Waiting, not answered(Streams, Wait)]).

answered(Streams, {waiting, Stream, Part, From}) ->
    case maps:get(Stream, Streams) of
        {Text, State} ->
            case {binary:match(Text, Part), State} of
                {nomatch, open} -> false;
                {Found, _} -> From ! {seen, Stream, Part, Found =/= nomatch}, true
            end
    end;
answered(#{out := {Out, ended}, err := {Err, ended}}, {said, From}) ->
    From ! {said, Out, Err},
    true;
answered(_, {said, _}) ->
    false.

%% Until the node's standard error holds Part; 30 seconds, or Ms where a
%% wait outlasts them, bound a failure.
says(Dir, Part) ->
    says(Dir, Part, 30000).

says(Dir, Part, Ms) ->
    seen(Dir, err, Part, Ms).

%% Until the node's standard output holds Part.
prints(Dir, Part) ->
    prints(Dir, Part, 30000).

prints(Dir, Part, Ms) ->
    seen(Dir, out, Part, Ms).

seen(Dir, Stream, Part, Ms) ->
    Bytes = unicode:characters_to_binary(Part),
    watcher_name(Dir) ! {waiting, Stream, Bytes, self()},
    receive
        {seen, Stream, Bytes, Seen} -> ?assert(Seen)
    after Ms ->
        erlang:error({not_said, Dir, Part})
    end.

%% A waiting node ended by termination, which ends it with 128 and the
%% signal's number (report §11.2).
stop(Dir, Wait) ->
    terminated(Dir),
    ?assertEqual(143, Wait()).

%% A node sent termination, by the process its ernest.pid names.
terminated(Dir) ->
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ok.

%% What a node that has ended wrote, once both its streams have ended.
said(Dir) ->
    watcher_name(Dir) ! {said, self()},
    receive
        {said, Out, Err} -> {binary_to_list(Out), binary_to_list(Err)}
    after 30000 ->
        erlang:error({still_writing, Dir})
    end.

has(Text, Part) ->
    ?assertNotEqual(nomatch, string:find(Text, Part)).

%% report §8.7: two nodes that list each other connect over TLS with a
%% certificate on each side, by the first operation that needs it, and each
%% says so naming the other; a node whose program ends tells the other,
%% which says it ended and not that it was lost; and the host's own reports
%% of its nodes are not written
connect_test_() ->
    nodes_test(60, fun connect/1).

connect(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "the peer a ended"),
    stop(B, WaitB),
    {OutA, ErrA} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: true"),
    has(ErrA, "the peer b connected"),
    has(ErrB, "the peer a connected"),
    has(ErrB, "the peer a ended"),
    ?assertEqual(nomatch, string:find(ErrB, "was lost")),
    ?assertEqual(nomatch, string:find(ErrB, "**")),
    %% a node's ernest.pid is there while it runs and gone at its end
    ?assertNot(filelib:is_file(filename:join(B, "ernest.pid"))).

%% report §8.7: a node accepts a peer whose public key its configuration
%% lists, and no other: the dialer is told nothing but that it could not
%% connect, and the node that refused says so, naming the key's digest
unlisted_test_() ->
    nodes_test(60, fun unlisted/1).

unlisted(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "was refused: no peer has its key"),
    stop(B, WaitB),
    {OutA, ErrA} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: false"),
    ?assertEqual("", ErrA),
    has(ErrB, "a node with the key " ++ digest(A) ++ " was refused: no peer has its key"),
    ?assertEqual(nomatch, string:find(ErrB, "TLS")).

%% report §8.7: a node accepts a connection from a peer whose key it lists
%% only under the name that key gives it: a host that holds the key of the
%% peer b and names itself otherwise is refused, and so is one that
%% presents b's key in a certificate naming the host of c's, another peer
%% listed; each refusal the node says. Under its own name the holder of b's
%% key connects and its calls run, and once a reload removes b its
%% connection ends and a call no longer runs. A regression test: a holder of
%% a listed key connected under a name of its choosing, which a reload that
%% removed the peer did not end, and over which a call still ran
bound_test_() ->
    nodes_test(90, fun bound/1).

bound(Base) ->
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    C = made(Base, "c", none),
    lists(A, [{"b", B, none}, {"c", C, none}]),
    Root = filename:join(Base, "build"),
    Program = program(Root),
    Cookie = ern_carrier:cookie(),
    WaitA = start(A, Program, []),
    prints(A, "waiting"),
    Target = name(A),
    {_, Ghost} = client(Root, "ghost@node.ernest", key_files(B), Cookie, PortA, Target, false),
    {0, GhostOut} = Ghost(),
    has(GhostOut, "connect: false"),
    says(A, "a node named ghost@node.ernest was refused: its key gives another name"),
    {_, Forged} = client(Root, name(C), forged(B, host(C)), Cookie, PortA, Target, false),
    {0, ForgedOut} = Forged(),
    has(ForgedOut, "connect: false"),
    says(A, "the peer b was refused: its certificate names another host than its key gives"),
    {Own, Owned} = client(Root, name(B), key_files(B), Cookie, PortA, Target, true),
    says(A, "the peer b connected"),
    lists(A, [{"c", C, none}]),
    ?assertMatch({0, _}, signalled("reload", A)),
    says(A, "the peer b was removed"),
    true = port_command(Own, "go\n"),
    {0, OwnOut} = Owned(),
    stop(A, WaitA),
    has(OwnOut, "connect: true"),
    has(OwnOut, "call: ran"),
    ?assertEqual(nomatch, string:find(OwnOut, "after: ran")),
    has(OwnOut, "after: ").

%% report §8.7: a node it dials must answer under the name it dialled: the
%% address a lists for the peer b is the port of c, another peer it lists,
%% which answers under its own name, and the dial fails, neither node
%% connected; the host's handshake refuses the answer, and neither says
%% anything of it
answered_test_() ->
    nodes_test(60, fun answered/1).

answered(Base) ->
    PortC = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", none),
    C = made(Base, "c", PortC),
    lists(A, [{"b", B, PortC}, {"c", C, none}]),
    lists(C, [{"a", A, none}]),
    Program = program(filename:join(Base, "build")),
    WaitC = start(C, Program, []),
    prints(C, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    stop(C, WaitC),
    {OutA, ErrA} = said(A),
    {_, ErrC} = said(C),
    has(OutA, "connect: false"),
    ?assertEqual(nomatch, string:find(ErrA, "connected")),
    ?assertEqual(nomatch, string:find(ErrC, "connected")).

%% report §8.7: two nodes of different builds connect, the cookie being
%% the floor's digest and holding nothing of the build. A regression test
%% of MVP 3.0's fingerprint, which refused them
other_build_test_() ->
    nodes_test(60, fun other_build/1).

other_build(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    Other = filename:join(Base, "other"),
    ok = filelib:ensure_path(Other),
    ok = file:write_file(filename:join(Other, "extra.ern"), "export fn f() : Int = 1\n"),
    Changed = program(Other),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Changed, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    stop(B, WaitB),
    {OutA, _} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: true"),
    has(ErrB, "the peer a connected"),
    ?assertEqual(nomatch, string:find(ErrB, "refused")).

%% report §8.7: a node that stands on another floor fails the handshake with
%% nothing sent, its cookie another's, and the node that refused it says so
%% in its own words; here a bare `erl` that holds a listed peer's key and
%% names itself as that key gives, with another cookie
other_floor_test_() ->
    nodes_test(60, fun other_floor/1).

other_floor(Base) ->
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    Root = filename:join(Base, "build"),
    Program = program(Root),
    WaitA = start(A, Program, []),
    prints(A, "waiting"),
    {_, Other} = client(Root, name(B), key_files(B), "another-floor", PortA, name(A), false),
    {0, OtherOut} = Other(),
    has(OtherOut, "connect: false"),
    says(A, "the peer b was refused: it stands on another floor, another release or build of"
            " ern or another major release of OTP"),
    stop(A, WaitA),
    {_, ErrA} = said(A),
    ?assertEqual(nomatch, string:find(ErrA, "**")).

%% report §8.7, limit 14 of the proposal: two nodes started from copies of
%% one directory are one node to their peers; the second's dial ends the
%% first's connection, which the peer says each time
replaced_test_() ->
    nodes_test(60, fun replaced/1).

replaced(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Copy = filename:join(Base, "copy"),
    ok = file:make_dir(Copy),
    ok = file:change_mode(Copy, 8#700),
    [{ok, _} = file:copy(filename:join(A, File), filename:join(Copy, File))
     || File <- ["ernest.conf", "certificate.pem", "private-key.pem"]],
    ok = file:change_mode(filename:join(Copy, "private-key.pem"), 8#600),
    edit(Copy, fun(Conf) -> maps:remove(<<"listen">>, Conf) end),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["hold", name(B)]),
    says(A, "the peer b connected"),
    WaitCopy = start(Copy, Program, ["hold", name(B)]),
    says(B, "the peer a's connection was replaced by another from the same node"),
    [stop(Dir, Wait) || {Dir, Wait} <- [{A, WaitA}, {Copy, WaitCopy}, {B, WaitB}]],
    {_, ErrB} = said(B),
    has(ErrB, "the peer a's connection was replaced by another from the same node").

%% report §8.7: a node whose `listen` names port 0 takes the port the host
%% picks and says which it bound; a node without `listen` does not listen,
%% and dials
listening_test_() ->
    nodes_test(60, fun listening/1).

listening(Base) ->
    PortB = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", PortB),
    Z = made(Base, "z", 0),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, none}]),
    Program = program(filename:join(Base, "build")),
    WaitZ = start(Z, Program, []),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(Z, "listening on port"),
    says(B, "the peer a connected"),
    stop(B, WaitB),
    stop(Z, WaitZ),
    {OutA, _} = said(A),
    {_, ErrB} = said(B),
    {_, ErrZ} = said(Z),
    has(OutA, "connect: true"),
    has(ErrB, "the peer a connected"),
    {match, [Bound]} = re:run(ErrZ, "listening on port ([0-9]+)", [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Bound) > 0),
    ?assertEqual(nomatch, string:find(ErrB, "listening")).

%% report §8.7: a frame the gateway cannot read is faulty, and the node ends
%% the connection, saying so; the sender's node is told of the loss; a
%% message that names no peer's process names no connection, and is
%% dropped, which the node says
faulty_frame_test_() ->
    nodes_test(60, fun faulty_frame/1).

faulty_frame(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    {InputA, WaitA} = started(A, Program, ["frame", name(B)]),
    says(B, "its connection was ended"),
    says(A, "the peer b was lost: it closed"),
    true = port_command(InputA, "ended\n"),
    ?assertEqual(0, WaitA()),
    stop(B, WaitB),
    {_, ErrA} = said(A),
    {_, ErrB} = said(B),
    has(ErrB, "a frame that names no peer's process came to the gateway, and was dropped"),
    has(ErrB, "the peer a sent a frame this node cannot read, and its connection was ended"),
    has(ErrA, "the peer b was lost: it closed").

%% report §8.7: a spawn frame whose site is not UTF-8 is a frame the node
%% cannot read, though the node holds the function it names: the node ends
%% the connection, saying so, and the sender's node is told of the loss. A
%% regression test, written after the fix: the site was read only where the
%% node lacked the function, and a node that held it started the process
%% under the site as it came
unreadable_site_test_() ->
    nodes_test(60, fun unreadable_site/1).

unreadable_site(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    {ok, Beam} = file:read_file(Program),
    {ok, Definitions} = ern_canonical:read(Beam),
    [Held] = [binary_to_list(binary:encode_hex(Hash))
              || #definition{qualified_name = ['Node', held], hash = Hash} <- Definitions],
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    {InputA, WaitA} = started(A, Program, ["site", name(B), Held]),
    says(B, "its connection was ended"),
    says(A, "the peer b was lost: it closed"),
    true = port_command(InputA, "ended\n"),
    ?assertEqual(0, WaitA()),
    stop(B, WaitB),
    {_, ErrB} = said(B),
    has(ErrB, "the peer a sent a frame this node cannot read, and its connection was ended").

%% report §8.7, §11.2: a node reads every module of its load path at its
%% start, and is refused where one of them needs a module the path lacks,
%% the refusal naming the module, the one that needs it and the rule; the
%% same program run as no node loads only what it uses, and runs. A
%% regression test, written after the fix: the refusal named neither the
%% module that needed it nor the rule
missing_module_test_() ->
    nodes_test(60, fun missing_module/1).

missing_module(Base) ->
    Lone = made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    [ok = file:write_file(filename:join(Source, File), Text)
     || {File, Text} <- [{"main.ern", "export fn main() : Unit with Never = Io.println(\"ran\")\n"},
                         {"user.ern", "export fn twice(n : Int) : Int = Extra.double(n)\n"},
                         {"extra.ern", "export fn double(n : Int) : Int = n * 2\n"}]],
    0 = ern_cli:ern(["build", "--build-root", Build, Source], group_leader()),
    ok = file:delete(filename:join(Build, "extra.erc")),
    Main = filename:join(Build, "main.erc"),
    Run = fun(Words) ->
              Port = open_port({spawn_executable, "/bin/sh"},
                               [{args, ["-c", lists:flatten([?ERN, " run ", Words, " 2>&1"])]},
                                exit_status, binary]),
              collected(Port, <<>>)
          end,
    ?assertEqual({0, <<"ran\n">>}, Run(Main)),
    ?assertEqual({1, <<"ern run: cannot find module Extra (extra.erc), which User needs, on the"
                       " load path: a node reads every module of its load path\n">>},
                 Run(["--config-dir ", Lone, " ", Main])),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §8.7: a node runs over its listener's family of addresses, IPv6
%% where `listen` names an address of it, its peers' addresses of the same
ipv6_test_() ->
    nodes_test(60, fun ipv6/1).

ipv6(Base) ->
    Free = fun() ->
               {ok, Socket} = gen_tcp:listen(0, [inet6, {ip, {0, 0, 0, 0, 0, 0, 0, 1}}]),
               {ok, Port} = inet:port(Socket),
               ok = gen_tcp:close(Socket),
               Port
           end,
    Six = fun(Port) -> list_to_binary("[::1]:" ++ integer_to_list(Port)) end,
    {PortA, PortB} = {Free(), Free()},
    A = made(Base, "a", none),
    B = made(Base, "b", none),
    edit(A, fun(Conf) ->
                Conf#{<<"listen">> => Six(PortA),
                      <<"peers">> => [(peer("b", B, none))#{<<"network-address">> => Six(PortB)}]}
            end),
    edit(B, fun(Conf) ->
                Conf#{<<"listen">> => Six(PortB),
                      <<"peers">> => [(peer("a", A, none))#{<<"network-address">> => Six(PortA)}]}
            end),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "the peer a connected"),
    stop(B, WaitB),
    {OutA, _} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: true"),
    has(ErrB, "the peer a connected").

%% report §8.6, §8.7, Appendix E.23: a node whose program ends by `Os.exit`
%% exits with its status, and its ernest.pid, there while it runs, is gone
os_exit_test_() ->
    nodes_test(60, fun os_exit/1).

os_exit(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "exits.ern"),
                         "export fn main() : Unit with Never = {\n"
                         "    Io.println(Io.show(Either.map(Fs.list(Path(\"" ++ A ++ "\"), 1000),\n"
                         "                                  fn(entries) = List.size(entries))));\n"
                         "    Os.exit(3)\n"
                         "}\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    ?assertEqual(3, (start(A, filename:join(Root, "exits.erc"), []))()),
    {Out, _} = said(A),
    has(Out, "Right(4)"),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §8.7, §11.2: a node whose `ernest.conf` is refused is refused with
%% the file and the rule, as the launcher's second start says it, the first
%% having given the host no flags. A regression test: the refusal said the
%% host had not been started as a node
refused_configuration_test_() ->
    nodes_test(60, fun refused_configuration/1).

refused_configuration(Base) ->
    A = made(Base, "a", none),
    edit(A, fun(Conf) -> Conf#{<<"peers">> => #{}} end),
    Program = program(filename:join(Base, "build")),
    Said = os:cmd(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1; echo status $?"),
    has(Said, "ern run: " ++ filename:join(A, "ernest.conf") ++ ": peers is not a JSON array"),
    has(Said, "status 1").

%% report §8.7, §11.2: a node refused once its start has begun, by a module
%% on its load path the program never uses whose dependency the path lacks,
%% removes the ernest.pid it wrote, as it does however it ends. A
%% regression test: the file was left naming the process that had ended
refused_after_start_test_() ->
    nodes_test(60, fun refused_after_start/1).

refused_after_start(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit with Never = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join(Root, "uses.ern"), "export fn f() : Int = Used.g()\n"),
    ok = file:write_file(filename:join(Root, "used.ern"), "export fn g() : Int = 1\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    ok = file:delete(filename:join(Root, "used.erc")),
    Said = os:cmd(?ERN ++ " run --config-dir " ++ A ++ " " ++ filename:join(Root, "prog.erc")
                  ++ " 2>&1; echo status $?"),
    has(Said, "Used"),
    has(Said, "status 1"),
    ?assertEqual(nomatch, string:find(Said, "ran")),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §7.4, §8.7: a node whose carrier cannot start, its port taken,
%% ends before `main` runs, its entry process faulting with the cause §7.4
%% states, under the entry point's site, and with nothing of the host's
%% reports on its standard output. A regression test of the principles
%% review's K14 (2026-10-09), which stated the cause in §7.4: the fault was
%% reported under the last initializer's site, `Terminal.widths`, and the
%% host's crash report of its distribution was written on standard output
carrier_not_started_test_() ->
    nodes_test(60, fun carrier_not_started/1).

carrier_not_started(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    A = made(Base, "a", Port),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit with Never = Io.println(\"ran\")\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Program = filename:join(Root, "prog.erc"),
    Out = filename:join(Base, "out"),
    Said = os:cmd(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1 >" ++ Out
                  ++ "; echo status $?"),
    ok = gen_tcp:close(Held),
    has(Said, "Prog.main faulted: the node's carrier did not start: "),
    has(Said, "status 1"),
    ?assertEqual({ok, <<>>}, file:read_file(Out)),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §8.6: a node detects no deadlock, since it can be reached from
%% outside: a node that waits for a message that never comes waits, where
%% the same program run as no node faults; termination ends it. That the
%% node does not fault is shown by its waiting three times as long as the
%% program took to fault as no node, the one wait here a time, since an
%% absence shows itself by nothing else
no_deadlock_test_() ->
    nodes_test(60, fun no_deadlock/1).

no_deadlock(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "waits.ern"),
                         "export fn main() : Unit with Int = {\n"
                         "    Io.println(\"waiting\");\n"
                         "    receive { n -> Unit }\n"
                         "}\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Program = filename:join(Root, "waits.erc"),
    {Micros, Plain} = timer:tc(fun() -> os:cmd(?ERN ++ " run " ++ Program ++ " 2>&1") end),
    has(Plain, "deadlock"),
    Wait = start(A, Program, []),
    prints(A, "waiting"),
    %% an absence: three times what the plain run took to find its deadlock
    timer:sleep(3 * Micros div 1000),
    {ok, Pid} = file:read_file(filename:join(A, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(143, Wait()),
    {_, Err} = said(A),
    ?assertEqual(nomatch, string:find(Err, "deadlock")),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%%
%% Peer (report §8.7, Appendix E.27)
%%

%% The programs of test/peers/, one build: the store's and the desk's, with
%% the third node's beside them, and the host module they ask of the host,
%% on the load path, so that every node runs one build.
peers(Base) ->
    Root = filename:join(Base, "build"),
    0 = ern_cli:ern(["build", "--build-root", Root]
                    ++ lists:append([["--load-path", Library] || Library <- ?LIBRARIES])
                    ++ ["peers"], group_leader()),
    {ok, _} = compile:file("peers/ern_peers_host.erl", [{outdir, Root}]),
    {filename:join(Root, "store.erc"), filename:join(Root, "desk.erc")}.

%% A store that listens, a desk that dials it, and a peer the desk lists,
%% gone, whose port nothing holds; the desk's keys, each a name's peers in
%% the order a find asks them.
store_and_desk(Base) ->
    {PortStore, PortGone} = {free_port(), free_port()},
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    Gone = made(Base, "gone", none),
    Third = made(Base, "third", none),
    lists(Store, [{"desk", Desk, none}, {"third", Third, none}]),
    lists(Desk, [{"store", Store, PortStore}, {"gone", Gone, PortGone}]),
    lists(Third, [{"store", Store, PortStore}]),
    Stored = [<<"adder">>, <<"victim">>, <<"nothing">>, <<"census">>, <<"counter-slot">>,
              <<"echo-slot">>, <<"fragile">>, <<"strict">>, <<"brittle">>, <<"sleeper">>,
              <<"doomed">>, <<"adapter">>],
    edit(Desk, fun(Conf) ->
                   Conf#{<<"keys">> => maps:merge(
                                          maps:from_list([{Key, [<<"store">>]} || Key <- Stored]),
                                          #{<<"counter">> => [<<"gone">>, <<"store">>],
                                            <<"lost">> => [<<"gone">>]})}
               end),
    edit(Third, fun(Conf) ->
                    Conf#{<<"keys">> => #{<<"counter-slot">> => [<<"store">>],
                                          <<"echo-slot">> => [<<"store">>]}}
                end),
    {Store, Desk}.

%% report §8.7, Appendix E.27, §6.5, §6.9, §6.6, E.21: a find in a node's
%% initializer answers Unreachable, the node not yet dialling; a find over
%% a key's peers in order passes over one that cannot be reached and answers
%% the next's address, a key not listed NotListed, a name offered at
%% another type OtherType, a name not offered NotOffered, a key of an
%% unreachable peer alone Unreachable, no time Timeout; a message to an
%% adapted address made on the store reaches its target through the store;
%% kill crosses, and a Down from another node's process has an empty site;
%% Process.info answers None for another node's process; an offer of
%% another node's process faults, and one under a key a living process
%% holds answers that process; a lost connection gives a monitor
%% Unreachable with an empty site, a find after it Unreachable, and a
%% callForever on its process faults with the callee unreachable; and a
%% node killed outright, which tells its peers nothing, is said as lost,
%% its connection closed
find_test_() ->
    nodes_test(90, fun find/1).

find(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    WaitDesk = start(Desk, DeskProgram, ["find"]),
    prints(Desk, "now end the store"),
    {ok, Pid} = file:read_file(filename:join(Store, "ernest.pid")),
    _ = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(137, WaitStore()),
    ?assertEqual(0, WaitDesk()),
    {Out, Err} = said(Desk),
    {StoreOut, _} = said(Store),
    has(Err, "the peer store was lost: it closed"),
    ?assertEqual(nomatch, string:find(Err, "the peer store ended")),
    has(StoreOut, "the store's peers: [\"desk\", \"third\"]"),
    [has(Out, Line)
     || Line <- ["early: Left(Unreachable)", "peers: [\"store\", \"gone\"]", "info: None",
                 "unlisted: Left(NotListed)", "other type: Left(OtherType)",
                 "not offered: Left(NotOffered)", "unreachable: Left(Unreachable)",
                 "timeout: Left(Timeout)", "no upper bound: Right", "through the via: 7",
                 "killed: Killed \"\"",
                 "another node's: Fault(\"a node offers only its own processes\")",
                 "twice, first: Right(Unit)", "twice, again held by itself: true",
                 "twice: Returned",
                 "lost: Unreachable \"\"", "after the loss: Left(Unreachable)",
                 "call forever: Fault(\"callee is unreachable\")"]].

%% report §8.7, Appendix E.27: a key handed over on a node: the server's
%% first service takes the key, Right(Unit), and a newcomer's offer under it
%% answers the holder, Left(holder), which the newcomer monitors; the
%% client finds the first service, calls it and kills it across nodes; at
%% the holder's Down the newcomer offers again and takes the key, and the
%% client's next find reaches the newcomer. A regression test, written
%% after the code, which faulted the newcomer's offer
handover_test_() ->
    nodes_test(60, fun handover/1).

handover(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "server.ern"), <<"
// Report §8.7, Appendix E.27: a key handed over: the first service takes
// it, and a newcomer finds it held, monitors the holder and takes the key
// at the holder's end.

export type Msg = Which(Reply(String))

export let key : Peer.Key(Msg) = Peer.key(\"handover\")

type Newcomer = Asked(Msg) | Ended(Down)

export fn main() : Unit with Unit = {
    let first = spawn(fn() = serve());
    Io.println(\"taken: \" <> Io.show(Peer.offer(key, first)));
    let _ = spawn(fn() = newcomer(Process.fromAddress(first)));
    held()
}

fn serve() : Unit with Msg =
    receive {
        Which(reply) -> {
            answer(reply, \"first\");
            serve()
        }
    }

fn newcomer(first : Process) : Unit with Newcomer = {
    let service = via(self(), Asked);
    match Peer.offer(key, service) {
        Left(holder) -> {
            Io.println(\"held by the first: \" <> Io.show(holder == first));
            monitor(holder, Ended);
            receive {
                Ended(_) -> Io.println(\"then taken: \" <> Io.show(Peer.offer(key, service)))
            }
        }
      | Right(_) -> Io.println(\"taken at once\")
    };
    serving()
}

fn serving() : Unit with Newcomer =
    receive {
        Asked(Which(reply)) -> {
            answer(reply, \"newcomer\");
            serving()
        }
      | Ended(_) -> serving()
    }

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit with Unit = receive { _ -> held() }
"/utf8>>),
    ok = file:write_file(filename:join(Root, "client.ern"), <<"
// Report §8.7: the client finds the server's service, calls it and kills
// it, and once the test says the key is taken finds it again.

export fn main() : Unit with Never =
    match Peer.find(Server.key, 10000) {
        Right(first) -> {
            Io.println(\"first: \" <> asked(first));
            kill(first);
            Io.println(\"killed\");
            // until the test, which has seen the key taken, says so
            let _ = Io.readLine();
            match Peer.find(Server.key, 10000) {
                Right(newcomer) -> Io.println(\"then: \" <> asked(newcomer))
              | Left(failure) -> Io.println(\"then: \" <> Io.show(failure))
            }
        }
      | Left(failure) -> Io.println(\"first: \" <> Io.show(failure))
    }

fn asked(service : Address(Server.Msg)) : String with m =
    Io.show(Address.call(service, fn(reply) = Server.Which(reply), 10000))
"/utf8>>),
    0 = ern_cli:ern(["build", Root], group_leader()),
    PortServer = free_port(),
    Server = made(Base, "server", PortServer),
    Client = made(Base, "client", none),
    lists(Server, [{"client", Client, none}]),
    lists(Client, [{"server", Server, PortServer}]),
    edit(Client, fun(Conf) -> Conf#{<<"keys">> => #{<<"handover">> => [<<"server">>]}} end),
    WaitServer = start(Server, filename:join(Root, "server.erc"), []),
    prints(Server, "held by the first: true"),
    {Input, WaitClient} = started(Client, filename:join(Root, "client.erc"), []),
    prints(Client, "killed"),
    prints(Server, "then taken: Right(Unit)"),
    true = port_command(Input, "taken\n"),
    ?assertEqual(0, WaitClient()),
    stop(Server, WaitServer),
    {Out, _} = said(Client),
    {ServerOut, _} = said(Server),
    has(ServerOut, "taken: Right(Unit)"),
    has(Out, "first: Some(\"first\")"),
    has(Out, "then: Some(\"newcomer\")").

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
    nodes_test(60, fun reply_crosses/1).

reply_crosses(Base) ->
    {Program, A, B} = squares(Base),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["ask", "b"]),
    prints(B, "answered there: "),
    stop(A, WaitA),
    says(B, "the peer a ended"),
    stop(B, WaitB),
    {OutA, _} = said(A),
    {OutB, ErrB} = said(B),
    has(OutA, "answered here: Some(49)"),
    has(OutA, "spawned there: true"),
    has(OutB, "answered there: Some(64)"),
    ?assertEqual(nomatch, string:find(ErrB, "the peer a was lost")).

%% report §11.2, §8.7: a process a peer spawned that faults is reported on
%% the node it runs on with the spawner's site and, after the cause, the
%% peer that spawned it, as it restarts and as it ends; a process it spawns
%% there is reported without it, its site this node's. A regression test,
%% written after the code, whose line named the spawner's site alone
peer_fault_test_() ->
    nodes_test(60, fun peer_fault/1).

peer_fault(Base) ->
    {Program, A, B} = squares(Base),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["fault", "b"]),
    prints(A, "faulting there: true"),
    says(B, "Squares.main:20 faulted: division by zero, spawned by the peer a"),
    says(B, "Squares.spawning:46 faulted: division by zero\n"),
    stop(A, WaitA),
    stop(B, WaitB),
    {_, ErrB} = said(B),
    has(ErrB, "Squares.main:20 faulted, restarted: division by zero, spawned by the peer a\n"),
    ?assertEqual(nomatch, string:find(ErrB, "Squares.spawning:46 faulted: division by zero,")).

%% The program of two nodes, a and b, each listing the other, a dialling b:
%% a service on a whose answer is given on b, by a lambda it spawns there
%% with the request's reply among its captures, and a function a spawns on
%% b that faults, restarting once, after it spawns one there that faults.
squares(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "squares.ern"), <<"
// Report §8.7, §6.6, §11.2: a service whose answer is given on a peer, by
// a lambda it spawns there with the request's reply among its captures,
// and a function spawned on a peer that faults there.

type Msg = Square(n : Int, reply : Reply(Int))

export fn main() : Unit with Unit =
    match Os.arguments {
        [\"ask\", peer] -> {
            let service = spawn(fn() = serve(peer));
            Io.println(\"answered here: \" <> asked(service, 7));
            let there = Peer.spawn(peer, fn() : Unit with Never =
                Io.println(\"answered there: \" <> asked(service, 8)), 5000);
            Io.println(\"spawned there: \" <> Io.show(Either.isRight(there)));
            held()
        }
      | [\"fault\", peer] -> {
            let limit = RestartLimit(restarts = 1, within = 60000);
            let faulting = Peer.spawn(peer, restarting(limit, spawning), 5000);
            Io.println(\"faulting there: \" <> Io.show(Either.isRight(faulting)));
            held()
        }
      | _ -> {
            Io.println(\"waiting\");
            held()
        }
    }

fn serve(peer : String) : Unit with Msg =
    receive {
        Square(n = n, reply = reply) -> {
            match Peer.spawn(peer, fn() : Unit with Never = answer(reply, n * n), 5000) {
                Right(_) -> Unit
              | Left(failure) -> Io.println(\"no spawn: \" <> Io.show(failure))
            };
            serve(peer)
        }
    }

fn asked(service : Address(Msg), n : Int) : String with m =
    Io.show(Address.call(service, fn(reply) = Square(n = n, reply = reply), 10000))

// A process that faults, spawned here, and then a fault of its own.
fn spawning() : Unit with Never = {
    let _ = spawn(fn() : Unit with Never = divided());
    divided()
}

fn divided() : Unit with Never = {
    let _ = 1 / List.size([]);
    Unit
}

// Until the node is stopped: a node waiting for ever is no deadlock.
fn held() : Unit with Unit = receive { _ -> held() }
"/utf8>>),
    0 = ern_cli:ern(["build", Root], group_leader()),
    PortB = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, none}]),
    {filename:join(Root, "squares.erc"), A, B}.

%% report §8.7, §6.7, Appendix E.27, §8.2: work on a peer is a process
%% spawned at the node the program names, whose spawn answers its address or
%% a failure within the time; a function the store holds spawns there with
%% what it captured, writing to the store's standard output; a name that is
%% no peer's is NotListed; a function that names a binding with no value on
%% the store is NotLoaded, which the store says, and nothing is initialized
%% for it; a function that names no binding spawns though its module's
%% binding has no value there, MVP 3.1 having lifted the rule by module; a
%% top-level binding in spawned code is the peer's; a monitored spawn is
%% monitored from its start; a spawn given no time answers Timeout; a find
%% and a spawn given a time past the longest wait the host takes at once
%% wait, a regression: each failed with the host's error
spawn_test_() ->
    nodes_test(90, fun spawn_on_peer/1).

spawn_on_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["spawn"]))()),
    prints(Store, "the peers here"),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {StoreOut, StoreErr} = said(Store),
    [has(Out, Line)
     || Line <- ["spawn: Right", "not listed: NotListed", "not loaded: NotLoaded",
                 "names no binding: Right", "bindings: Right", "monitored: Returned",
                 "late: Timeout", "no upper bound: Right"]],
    has(StoreErr, "the peer desk's spawn at Desk.spawns:74 was not loaded: the binding"
                  " Lonely.greeting has no value here"),
    has(StoreOut, "the store squares 49"),
    has(StoreOut, "the store squares 64"),
    has(StoreOut, "the peers here: [\"desk\", \"third\"]"),
    ?assertEqual(nomatch, string:find(StoreOut, "never initialized")).

%% report §8.7, §6.5, §6.9, §8.4, §3.11: a correct program's messages make
%% no new atom on the node that receives them, a value of many shapes and
%% one of 8 MB among them; an address is as good on a third node, which
%% took it from the store and sends to it; an address of a node not listed
%% takes no send and gives a monitor Unreachable; a fault in an adapted
%% address's function is its target's; a monitor does not outlive a loss,
%% and the address does: a send after it reaches the same process; with
%% its node ended, a send returns at once, a monitor gives Unreachable; and
%% once the node starts again, the address of its earlier start is dead, a
%% call through it ending at once, a send to it dropped, a monitor giving
%% Unknown, and an adapted address it made dropping what is sent through
%% it, its function not applied. A regression test: the runtime hands each
%% to the host, and this holds that it does; and the new start applied the
%% function of an adapted address its earlier start made. Not covered: a
%% value crossing in pieces with other senders' messages between them, a
%% send that waits at a full buffer, and a silence, which the detector
%% finds in a minute
across_test_() ->
    nodes_test(120, fun across/1).

across(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    ThirdProgram = filename:join(filename:dirname(DeskProgram), "third.erc"),
    {Store, Desk} = store_and_desk(Base),
    Third = filename:join(Base, "third"),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    WaitThird = start(Third, ThirdProgram, []),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["across"]),
    prints(Desk, "now kill the store"),
    {ok, Pid} = file:read_file(filename:join(Store, "ernest.pid")),
    _ = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(137, WaitStore()),
    prints(Desk, "now restart the store"),
    %% the first start's lines kept, since the second writes its own there
    ok = file:rename(Store ++ ".out", Store ++ ".first.out"),
    ok = file:rename(Store ++ ".err", Store ++ ".first.err"),
    WaitAgain = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitAgain),
    stop(Third, WaitThird),
    {Out, _} = said(Desk),
    {ThirdOut, _} = said(Third),
    [has(Out, Line)
     || Line <- ["new atoms: 0", "through the third node: 10", "not listed: Unreachable \"\"",
                 "adapted: Fault(\"negative\") \"\"", "severed: Unreachable \"\"",
                 "after the loss: 15", "killed: Unreachable \"\"", "send at once: true",
                 "out of reach: Unreachable \"\"", "old call: None true",
                 "old monitor: Unknown \"\"", "same process: false", "fresh total: 0",
                 "old adapted: 2"]],
    {ok, FirstErr} = file:read_file(Store ++ ".first.err"),
    has(binary_to_list(FirstErr), "the peer desk sent a frame this node cannot read"),
    has(ThirdOut, "sent through the third node"),
    ?assertEqual(nomatch, string:find(ThirdOut, "the echo got")).

%% report §8.7, §6.6, §6.9: a call to a process of another node leaves a
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
    nodes_test(120, fun calls/1).

calls(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["calls"]))()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    [has(Out, Line)
     || Line <- ["restarted: None true", "restarted forever: Fault(\"crashed\")",
                 "echo: Some(7)", "while it waits: 1", "its callee killed: Returned",
                 "after the callee's end: 0", "timed out: None 0", "answered here: Some(42) 0",
                 "waits again: 1", "its connection lost: Returned", "after the loss: 0"]].

%% `ern <job> --config-dir Dir` run as a person runs it, its status.
signalled(Job, Dir) ->
    Said = os:cmd(?ERN ++ " " ++ Job ++ " --config-dir " ++ Dir ++ " 2>&1; echo status $?"),
    {match, [Status]} = re:run(Said, "status ([0-9]+)", [{capture, all_but_first, list}]),
    {list_to_integer(Status), Said}.

%% report §8.6, §8.7, §11.2: `ern stop` sends the node its directory names
%% termination, saying only that it was delivered; the node stops in order,
%% so that a monitor made on its process before gives ProgramEnd, and one
%% made once it has stopped gives Unreachable; the node ends by the signal
%% and its ernest.pid goes. A regression test, written after the code; it
%% does not cover a peer that falls silent while the node stops
stop_test_() ->
    nodes_test(90, fun stop_in_order/1).

stop_in_order(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["ending"]),
    prints(Desk, "watching"),
    ?assertMatch({0, _}, signalled("stop", Store)),
    ?assertEqual(143, WaitStore()),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    {Out, _} = said(Desk),
    has(Out, "ended: ProgramEnd \"\""),
    has(Out, "after: Unreachable \"\""),
    ?assertNot(filelib:is_file(filename:join(Store, "ernest.pid"))),
    {Status, Said} = signalled("stop", Store),
    ?assertEqual(1, Status),
    has(Said, "ernest.pid: no such file: no node runs from the directory").

%% report §8.7, §11.2: a node holds ernest.pid locked for its life, which
%% the host ends with it however it ends: a node killed leaves the file,
%% and the next start from the directory takes it, saying nothing of a
%% refusal, the file holding the new node's number; a running node refuses
%% a second start, naming its number; and where the file names a living
%% process that is no node, `ern stop` and `ern reload` fail, saying that
%% no node holds it, and the process is sent nothing. A regression test,
%% written after the code (finding E4): a start was refused by a file whose
%% number a living process held, and the jobs signalled that process
pid_lock_test_() ->
    nodes_test(60, fun pid_lock/1).

pid_lock(Base) ->
    A = made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Program = program(filename:join(Base, "build")),
    WaitKilled = start(A, Program, []),
    prints(A, "waiting"),
    {ok, Killed} = file:read_file(PidFile),
    [] = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Killed))),
    ?assertEqual(137, WaitKilled()),
    ?assertEqual({ok, Killed}, file:read_file(PidFile)),
    WaitA = start(A, Program, []),
    prints(A, "waiting"),
    {ok, Number} = file:read_file(PidFile),
    ?assertNotEqual(Killed, Number),
    Again = os:cmd(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1; echo status $?"),
    has(Again, " is the configuration directory of the running node "
               ++ string:trim(binary_to_list(Number)) ++ ", which ernest.pid names"),
    has(Again, "status 1"),
    stop(A, WaitA),
    {_, Err} = said(A),
    ?assertEqual(nomatch, string:find(Err, "configuration directory")),
    %% a living process that is no node, which reads its input and echoes it
    Living = open_port({spawn_executable, os:find_executable("cat")}, [binary]),
    {os_pid, LivingNumber} = erlang:port_info(Living, os_pid),
    ok = file:write_file(PidFile, integer_to_list(LivingNumber) ++ "\n"),
    [begin
         {Status, Said} = signalled(Job, A),
         ?assertEqual(1, Status),
         has(Said, "ernest.pid: no node holds it: no node runs from the directory")
     end || Job <- ["stop", "reload"]],
    true = port_command(Living, <<"alive">>),
    ?assertEqual(<<"alive">>, receive {Living, {data, Echoed}} -> Echoed end),
    port_close(Living).

%% report §11.2, §8.6, §8.7: `ern stop` returns once the node has ended,
%% which it waits for on the lock the node holds on ernest.pid, with status
%% 0: a node whose end waits for a subscriber is still running, its file
%% there, until the subscriber answers, and the job returns with the node
%% gone, its file removed, and the next `ern run` from the directory
%% accepted at once; a second `ern stop` while the first waits is a second
%% termination, which ends the node at once, and both return. A regression
%% test, written after the code (findings W4, E9): the job returned once the
%% signal was sent, and a script's next start was refused by the node still
%% ending
stop_waits_test_() ->
    nodes_test(90, fun stop_waits/1).

stop_waits(Base) ->
    A = made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "stopping.ern"), <<"
// Report §8.6: a subscriber of the end that answers once a line comes.

type Msg = Terminating(Reply(Unit))

export fn main() : Unit with Msg = {
    Os.terminating(Terminating);
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
    0 = ern_cli:ern(["build", Root], group_leader()),
    Program = filename:join(Root, "stopping.erc"),
    Self = self(),
    Stopping = fun() -> spawn_link(fun() -> Self ! {stopped, signalled("stop", A)} end) end,
    {Port, Wait} = started(A, Program, []),
    prints(A, "subscribed"),
    _ = Stopping(),
    prints(A, "told"),
    ?assert(filelib:is_file(PidFile)),
    true = port_command(Port, "go\n"),
    ?assertMatch({stopped, {0, _}}, receive {stopped, _} = Stopped -> Stopped end),
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, Wait()),
    {_, Err} = said(A),
    has(Err, "the subscriber Stopping.main answered"),
    %% the next start, and two stops
    {_Port, WaitAgain} = started(A, Program, []),
    prints(A, "subscribed"),
    _ = Stopping(),
    prints(A, "told"),
    _ = Stopping(),
    [?assertMatch({stopped, {0, _}}, receive {stopped, _} = Stopped -> Stopped end)
     || _ <- [first, second]],
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, WaitAgain()),
    {_, ErrAgain} = said(A),
    has(ErrAgain, "the end was cut short, 1 subscriber unanswered: Stopping.main").

%% report §8.7, §11.2: `ern reload` sends the node hangup, which reads
%% ernest.conf again: a peer removed has its connection ended and is
%% refused after, a peer listed again under another name is accepted, a
%% peer renamed keeps its connection, and a file that changes `listen` is
%% refused, the configuration kept; the node says what each did, each line
%% with its time. A regression test, written after the code; it does not
%% cover `measures` changed, nor a peer whose address changed. Regressions:
%% a peer's public key that does not decode failed the signal handler,
%% after which the node took no signal and ran on past `ern stop`; and the
%% host warned on standard output at each reload of a message the handler
%% did not take
reload_test_() ->
    nodes_test(90, fun reload/1).

reload(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    Third = filename:join(Base, "third"),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["reload"]),
    prints(Desk, "watching"),
    lists(Store, [{"third", Third, none}]),
    ?assertMatch({0, _}, signalled("reload", Store)),
    says(Store, "the peer desk was removed"),
    prints(Desk, "now list the desk again"),
    lists(Store, [{"third", Third, none}, {"front", Desk, none}]),
    ?assertMatch({0, _}, signalled("reload", Store)),
    says(Store, "the peer front was added"),
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now rename the desk"),
    lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    ?assertMatch({0, _}, signalled("reload", Store)),
    says(Store, "the peer front is now named window"),
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now refuse a reload"),
    edit(Store, fun(#{<<"peers">> := Peers} = Conf) ->
                    Broken = #{<<"name">> => <<"broken">>,
                               <<"public-key">> => undecodable(public(Desk))},
                    Conf#{<<"peers">> := Peers ++ [Broken]}
                end),
    ?assertMatch({0, _}, signalled("reload", Store)),
    says(Store, "is not one public key in PEM"),
    lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    edit(Store, fun(Conf) -> Conf#{<<"listen">> => address(free_port())} end),
    ?assertMatch({0, _}, signalled("reload", Store)),
    says(Store, "the reload was refused"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {StoreOut, Err} = said(Store),
    [has(Out, Line)
     || Line <- ["removed: Unreachable \"\"", "unlisted: Left(Unreachable)", "listed again: true",
                 "renamed: Some(0)", "refused: Some(0)"]],
    [?assertMatch({match, _}, re:run(Err, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z " ++ Line ++ "$",
                                     [multiline]))
     || Line <- ["ernest.conf was read again", "the peer desk was removed",
                 "the peer front was added", "the peer front is now named window"]],
    has(Err, "the reload was refused, and the configuration stays as it was: "),
    has(Err, "peer \"broken\"'s public-key is not one public key in PEM"),
    has(Err, "listen cannot change while the node runs"),
    ?assertEqual(nomatch, string:find(Err, "the peer front was lost")),
    ?assertEqual(nomatch, string:find(StoreOut, "WARNING REPORT")).

%% A public key in PEM whose body the host's decoder cannot read: its first
%% bytes, the key's algorithm, made another DER's.
undecodable(Pem) ->
    [Head, Body] = binary:split(Pem, <<"\n">>),
    <<Head/binary, "\nAAAAAAAAAAAA", (binary:part(Body, 12, byte_size(Body) - 12))/binary>>.

%%
%% Two builds (report §8.7, MVP 3.1)
%%

%% A program of four modules, written in Dir and built there, as one build
%% or as another, Changed, in which one function's body and one type's
%% constructors differ: Twin's types, keys and functions; Aside, whose
%% binding the server's program never runs; the server, which offers a
%% service under each key; and the asker, which finds and spawns on the
%% server. A host module the asker's build holds and the server's lacks is
%% what Twin's foreign declaration calls. Answers the asker's and the
%% server's programs.
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
            "export let stableKey : Peer.Key(Msg) = Peer.key(\"stable\")\n"
            "\n"
            "export let shapeKey : Peer.Key(Shape) = Peer.key(\"shape\")\n"
            "\n"
            "export fn same() : Unit with Never = Io.println(\"same ran\")\n"
            "\n"
            "export fn changed() : Unit with Never = Io.println(\"", Said, "\")\n"
            "\n"
            "export fn worked() : Unit with Never = Io.println(\"restarting ran\")\n"
            "\n"
            "foreign fn absent() : Unit with m = \"ern_twins_host:absent/0\"\n"
            "\n"
            "export fn callsAbsent() : Unit with Never = absent()\n"],
    Aside = "// Report §8.7: a binding the server's program never runs, beside a\n"
            "// function that names no binding.\n"
            "\n"
            "let note : String = \"never run on the server\"\n"
            "\n"
            "export fn tell() : Unit with Never = Io.println(note)\n"
            "\n"
            "export fn quiet() : Unit with Never = Io.println(\"quiet ran\")\n",
    Server = "// Report §8.7: a service under each of Twin's keys, until the node ends.\n"
             "\n"
             "export fn main() : Unit with Unit = {\n"
             "    let pinged = spawn(fn() : Unit with Twin.Msg = answered());\n"
             "    let _ = Peer.offer(Twin.stableKey, pinged);\n"
             "    let shaped = spawn(fn() : Unit with Twin.Shape = held());\n"
             "    let _ = Peer.offer(Twin.shapeKey, shaped);\n"
             "    Io.println(\"offered\");\n"
             "    held()\n"
             "}\n"
             "\n"
             "fn answered() : Unit with Twin.Msg = receive {\n"
             "    Twin.Ping(reply) -> {\n"
             "        answer(reply, 42);\n"
             "        answered()\n"
             "    }\n"
             "}\n"
             "\n"
             "// Until the node is stopped: a node waiting for ever is no deadlock.\n"
             "fn held() : Unit with m = receive { _ -> held() }\n",
    Asker = "// Report §8.7: the finds and the spawns on the server, each answer a line.\n"
            "\n"
            "export fn main() : Unit with Never =\n"
            "    match Os.arguments {\n"
            "        [server] -> {\n"
            "            found(server);\n"
            "            spawned(server);\n"
            "            captured(server)\n"
            "        }\n"
            "      | _ -> Unit\n"
            "    }\n"
            "\n"
            "fn found(server : String) : Unit with Never = {\n"
            "    let stable = match Peer.find(Twin.stableKey, 5000) {\n"
            "        Right(address) ->\n"
            "            Io.show(Address.call(address, fn(reply) = Twin.Ping(reply), 5000))\n"
            "      | Left(failure) -> Io.show(failure)\n"
            "    };\n"
            "    Io.println(\"stable: \" <> stable);\n"
            "    Io.println(\"shape: \" <> started(Peer.find(Twin.shapeKey, 5000)))\n"
            "}\n"
            "\n"
            "fn spawned(server : String) : Unit with Never = {\n"
            "    Io.println(\"same: \" <> started(Peer.spawn(server, Twin.same, 5000)));\n"
            "    Io.println(\"changed: \" <> started(Peer.spawn(server, Twin.changed, 5000)));\n"
            "    Io.println(\"binding: \" <> started(Peer.spawn(server, Aside.tell, 5000)));\n"
            "    Io.println(\"module: \" <> started(Peer.spawn(server, Twin.callsAbsent, 5000)));\n"
            "    let quiet = Peer.spawn(server, Aside.quiet, 5000);\n"
            "    Io.println(\"names no binding: \" <> started(quiet))\n"
            "}\n"
            "\n"
            "// The same in both builds, so that its lambdas and local fns have one\n"
            "// identity on both nodes.\n"
            "fn captured(server : String) : Unit with Never = {\n"
            "    let n = 6;\n"
            "    let lambda = Peer.spawn(server,\n"
            "                            fn() : Unit with Never =\n"
            "                                Io.println(\"lambda ran \" <> Int.toString(n * 7)),\n"
            "                            5000);\n"
            "    Io.println(\"lambda: \" <> started(lambda));\n"
            "    fn local() : Unit with Never =\n"
            "        Io.println(\"local ran \" <> Int.toString(n + 37));\n"
            "    Io.println(\"local: \" <> started(Peer.spawn(server, local, 5000)));\n"
            "    let limit = RestartLimit(restarts = 1, within = 1000);\n"
            "    let restarted = Peer.spawn(server, restarting(limit, Twin.worked), 5000);\n"
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
                         {"asker.ern", Asker}]],
    0 = ern_cli:ern(["build", Dir], group_leader()),
    Changed orelse begin
                       ok = file:write_file(filename:join(Dir, "ern_twins_host.erl"),
                                            <<"-module(ern_twins_host).\n"
                                              "-export([absent/0]).\n"
                                              "absent() -> 'Unit'.\n">>),
                       {ok, _} = compile:file(filename:join(Dir, "ern_twins_host.erl"),
                                              [{outdir, Dir}])
                   end,
    {filename:join(Dir, "asker.erc"), filename:join(Dir, "server.erc")}.

%% A definition's hash as the build in Dir holds it, in hexadecimal.
hash_text(Dir, Module, QualifiedName) ->
    {ok, Bytes} = file:read_file(filename:join(Dir, Module ++ ".erc")),
    {ok, Definitions} = ern_canonical:read(Bytes),
    [Hash] = [Hash || {definition, Name, _, Hash, _, _} <- Definitions, Name =:= QualifiedName],
    binary_to_list(binary:encode_hex(Hash, lowercase)).

%% report §8.7, Appendix H, §3.11, §6.9: two nodes of different builds of
%% one program connect; a find answers the address where the key's type is
%% one in both builds, and a call through it is answered, and `OtherType`
%% where the type's constructors differ, its hash another; a spawn of a
%% function both builds hold runs on the server, and one of a function
%% whose body differs answers NotLoaded, the server saying it does not
%% have its hash; a function that names a binding the server's program
%% never ran answers NotLoaded, and so does one whose reach calls a host
%% module the server lacks, the server saying which; a function that names
%% no binding of a module whose binding the server never ran spawns,
%% MVP 3.0's rule by module gone; a lambda and a local fn spawn by identity
%% with what they captured, and `restarting(limit, f)` spawns. Written with
%% the code, after it: a regression test
two_builds_test_() ->
    nodes_test(90, fun two_builds/1).

two_builds(Base) ->
    {AskerProgram, _} = twins(filename:join(Base, "first"), false),
    {_, ServerProgram} = twins(filename:join(Base, "second"), true),
    PortServer = free_port(),
    Asker = made(Base, "asker", none),
    Server = made(Base, "server", PortServer),
    lists(Asker, [{"server", Server, PortServer}]),
    lists(Server, [{"asker", Asker, none}]),
    edit(Asker, fun(Conf) ->
                    Conf#{<<"keys">> => #{<<"stable">> => [<<"server">>],
                                          <<"shape">> => [<<"server">>]}}
                end),
    WaitServer = start(Server, ServerProgram, []),
    prints(Server, "offered"),
    ?assertEqual(0, (start(Asker, AskerProgram, ["server"]))()),
    prints(Server, "restarting ran"),
    stop(Server, WaitServer),
    {Out, _} = said(Asker),
    {ServerOut, ServerErr} = said(Server),
    [has(Out, Line)
     || Line <- ["stable: Some(42)", "shape: OtherType", "same: Right", "changed: NotLoaded",
                 "binding: NotLoaded", "module: NotLoaded", "names no binding: Right",
                 "lambda: Right", "local: Right", "restarting: Right"]],
    [has(ServerOut, Line)
     || Line <- ["same ran", "quiet ran", "lambda ran 42", "local ran 43", "restarting ran"]],
    ?assertEqual(nomatch, string:find(ServerOut, "the first build")),
    ?assertEqual(nomatch, string:find(ServerOut, "never run on the server")),
    Changed = hash_text(filename:join(Base, "first"), "twin", ['Twin', changed]),
    [has(ServerErr, Line)
     || Line <- ["the peer asker connected",
                 "the peer asker's spawn at Asker.spawned:25 was not loaded: this node does not"
                 " have its function, " ++ Changed,
                 "the peer asker's spawn at Asker.spawned:26 was not loaded: the binding"
                 " Aside.note has no value here",
                 "the peer asker's spawn at Asker.spawned:27 was not loaded: the module"
                 " ern_twins_host, which Twin.absent calls, is not here"]].

%% report §11.2, §8.7, Appendix H: a key at a type the session declares
%% names that type by its hash, as any key does, and the hash is the
%% session's whatever input declares the type: two shells that are nodes
%% declare one type at different inputs, the first at its first and the
%% second at its second, after a declaration of its own, whose input keeps
%% its module and so its namespace, and each offers a service under a key
%% at it; each finds the other's and sends to it. A regression test, written after the
%% code: the shell's test asserted the printed types alone (V12). Then
%% written again after the fix (V11): the type was hashed under its input's
%% namespace, so the two shells held two types and a find answered
%% `OtherType`
shell_key_test_() ->
    nodes_test(90, fun shell_key/1).

shell_key(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    [PortA, PortB] = [free_port(), free_port()],
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    edit(A, fun(Conf) -> Conf#{<<"keys">> => #{<<"t">> => [<<"b">>]}} end),
    edit(B, fun(Conf) -> Conf#{<<"keys">> => #{<<"t">> => [<<"a">>]}} end),
    Declared = "type T = T(Int)\nlet k : Peer.Key(T) = Peer.key(\"t\")\n",
    Offered = fun(Node) ->
                  ["let server : Address(T) = spawn(fn() : Unit with T =\n"
                   "    receive {\n"
                   "        T(n) -> Io.println(\"", Node, " got \" <> Int.toString(n))\n"
                   "    })\n"
                   "Peer.offer(k, server)\n"
                   "Io.println(\"offered\")\n"]
              end,
    Found = fun(Count) ->
                ["match Peer.find(k, 5000) {\n"
                 "    Right(server) -> {\n"
                 "        send(server, T(", Count, "));\n"
                 "        Io.println(\"found\")\n"
                 "    }\n"
                 "  | Left(failure) -> Io.println(Io.show(failure))\n"
                 "}\n"]
            end,
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA, [Declared, Offered("a")]),
    prints(A, "offered"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, ["type U = U\n", Declared, Offered("b"), Found("5")]),
    prints(B, "found"),
    prints(A, "a got 5"),
    true = port_command(InputA, Found("7")),
    prints(A, "found"),
    prints(B, "b got 7"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    [?assertEqual(nomatch, string:find(Out, "OtherType")) || {Out, _} <- [said(A), said(B)]].

%% report §11.2, §8.7, Appendix H: what a `let` at the prompt binds has its
%% value in the session, so a function typed at the prompt whose reach
%% names it runs on a shell that is a node where a peer's spawn names it:
%% two shells type one `let` and one function over it, the second after a
%% `let` of its own, so that its binding is held by another of its holders,
%% and the second spawns the function on the first, which runs it with its
%% own value. A regression test, written before the fix: the module that
%% holds what a `let` binds was never counted as evaluated, so the spawn
%% was refused and the node said the binding had no value there, which was
%% false. The `let` of its own a regression test too, written after the
%% fix (finding V11): a form named the binding under its holder, so the two
%% shells held two functions and the spawn answered NotLoaded
shell_binding_spawned_test_() ->
    nodes_test(90, fun shell_binding_spawned/1).

shell_binding_spawned(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    Typed = "let x = 5\nfn f() : Unit with Never = Io.println(\"x is \" <> Int.toString(x))\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA, [Typed, "Io.println(\"typed\")\n"]),
    prints(A, "typed"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, ["let other = 1\n", Typed, "match Peer.spawn(\"a\", f, 5000) {\n"
                                        "    Right(_) -> Io.println(\"spawned\")\n"
                                        "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                        "}\n"]),
    prints(B, "spawned"),
    prints(A, "x is 5"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    {OutA, _} = said(A),
    ?assertEqual(nomatch, string:find(OutA, "has no value here")).

%% report §11.2, §6.5, §8.7: an input that builds a function value keeps its
%% code while the session runs, since the function may be held anywhere: a
%% shell that is a node offers under a key an adapted address made at the
%% prompt, whose function the input built and the runtime's offers hold,
%% and a peer's message reaches the service through it after many inputs
%% more. A regression test, written after the fix (finding W1): the input's
%% module was let go once its answer was in, and the message's delivery
%% faulted with the host's `undef`
shell_offered_via_test_() ->
    nodes_test(90, fun shell_offered_via/1).

shell_offered_via(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    edit(B, fun(Conf) -> Conf#{<<"keys">> => #{<<"t">> => [<<"a">>]}} end),
    Declared = "type T = T(Int)\nlet k : Peer.Key(T) = Peer.key(\"t\")\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA,
                        [Declared,
                         "let store : Address(Int) = spawn(fn() : Unit with Int =\n"
                         "    receive { n -> Io.println(\"a got \" <> Int.toString(n)) })\n",
                         "Peer.offer(k, via(store, fn(t) = match t { T(n) -> n }))\n",
                         [["1 + ", integer_to_list(Index), "\n"] || Index <- lists:seq(1, 30)],
                         "Io.println(\"offered\")\n"]),
    prints(A, "offered"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, [Declared,
                                 "match Peer.find(k, 5000) {\n"
                                 "    Right(server) -> {\n"
                                 "        send(server, T(5));\n"
                                 "        Io.println(\"found\")\n"
                                 "    }\n"
                                 "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                 "}\n"]),
    prints(B, "found"),
    prints(A, "a got 5"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    {OutA, ErrA} = said(A),
    [?assertEqual(nomatch, string:find(Text, "undef")) || Text <- [OutA, ErrA]].

%% report §11.2, §8.7, Appendix E.21: a shell that is a node writes a
%% fault's line as `ern run` writes one, the peer whose spawn started the
%% process after the cause, which the FaultReport's `peer` names. A
%% regression test, written after the code (finding N12): the shell's line
%% named the spawner's site alone. A shell in line mode reports a fault
%% before its next prompt, so the shell that faulted is given two inputs
%% after it. A local fault's report, which names no peer, is
%% ern_rt_tests' fault_reports_test's
shell_peer_fault_test_() ->
    nodes_test(90, fun shell_peer_fault/1).

shell_peer_fault(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    Typed = "fn divided() : Unit with Never = {\n"
            "    Io.println(\"dividing\");\n"
            "    let _ = 1 / List.size([]);\n"
            "    Unit\n"
            "}\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA, [Typed, "Io.println(\"typed\")\n"]),
    prints(A, "typed"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, [Typed, "match Peer.spawn(\"a\", divided, 5000) {\n"
                                        "    Right(_) -> Io.println(\"spawned\")\n"
                                        "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                        "}\n"]),
    prints(B, "spawned"),
    prints(A, "dividing"),
    true = port_command(InputA, ["Io.println(\"next\")\n", "Io.println(\"last\")\n"]),
    prints(A, "last"),
    prints(A, " faulted: division by zero, spawned by the peer b\n"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()).

%% report §11.2, §8.7: a shell that is a node loads a module, and a peer
%% of the build that holds the module spawns a function of it there by its
%% hash, the value of the binding its reach names found, as on a node that
%% runs a program; a function typed at the shell has a hash and no peer
%% holds it, so a spawn of it answers NotLoaded, which the peer says. Written
%% after the code (MVP 3.1's item 5): a peer found no value of a binding the
%% shell's load had evaluated
shell_node_test_() ->
    nodes_test(90, fun shell_node/1).

shell_node(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "greet.ern"),
                         "let greeting : String = \"hello from the shell's load\"\n\n"
                         "export fn hello() : Unit with Never = Io.println(greeting)\n"),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node once a line comes.\n"
                         "\n"
                         "export fn main() : Unit with Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    let _ = Io.readLine();\n"
                         "    let spawned = match Peer.spawn(\"desk\", Greet.hello, 5000) {\n"
                         "        Right(_) -> \"Right\"\n"
                         "      | Left(failure) -> Io.show(failure)\n"
                         "    };\n"
                         "    Io.println(\"spawned: \" <> spawned);\n"
                         "    held()\n"
                         "}\n"
                         "\n"
                         "fn held() : Unit with m = receive { _ -> held() }\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "store.erc"), []),
    prints(Store, "ready"),
    {DeskInput, WaitDesk} = shell_started(Desk, Root),
    true = port_command(DeskInput, ":load Greet\n"
                                   "Peer.spawn(\"store\", fn() : Unit with Never = Unit, 5000)\n"),
    prints(Desk, "Left(NotLoaded) : Either(Io.Error, Address(Never))"),
    true = port_command(StoreInput, "go\n"),
    prints(Store, "spawned: Right"),
    prints(Desk, "hello from the shell's load"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, _} = said(Desk),
    {_, StoreErr} = said(Store),
    has(DeskOut, "Greet, compiled from greet.ern"),
    has(StoreErr, "the peer desk's spawn at input 2:1 was not loaded: this node does not have"
                  " its function").

%% report §8.7, §11.2: a shell that is a node over a build answers a peer
%% from the latest unit whose bindings have their values, as the session
%% uses it. Before anything is loaded the build's unit, read at the node's
%% start and never evaluated, answers no peer whose function's reach names
%% a binding: the spawn is NotLoaded and the node says the binding has no
%% value here, which is true. After `:load` of the module's source, changed
%% in another function, the same spawn runs in the session's unit, its
%% service the session's. After a `:reload` that leaves the service binding
%% unchanged, evaluated again and so a service of its own, a peer's spawn
%% sends to the new version's service, which the session sends to next. A
%% regression test, written after the fix (findings S2, V3, N1, N5): the
%% table answered the first unit loaded, so the spawn after the `:load` was
%% refused with that line, then false, and the one after the `:reload`
%% reached the previous version's service
shell_node_versions_test_() ->
    nodes_test(90, fun shell_node_versions/1).

shell_node_versions(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    Greet = fun(Other) ->
                ["// A greeter whose service is a binding, and what a peer spawns.\n"
                 "\n"
                 "export type Msg = Greet(String)\n"
                 "\n"
                 "let greeter : Address(Msg) = spawn(fn() : Unit with Msg = greeted(0))\n"
                 "\n"
                 "fn greeted(count : Int) : Unit with Msg =\n"
                 "    receive {\n"
                 "        Greet(who) -> {\n"
                 "            Io.println(who <> \" greeted \" <> Int.toString(count));\n"
                 "            greeted(count + 1)\n"
                 "        }\n"
                 "    }\n"
                 "\n"
                 "export fn greet(who : String) : Unit with Never = send(greeter, Greet(who))\n"
                 "\n"
                 "export fn hello() : Unit with Never = greet(\"hello\")\n"
                 "\n"
                 "export fn wave() : Unit with Never = greet(\"wave\")\n",
                 Other]
            end,
    ok = file:write_file(filename:join(Root, "greet.ern"), Greet("")),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of the function each line names.\n"
                         "\n"
                         "export fn main() : Unit with Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit with m =\n"
                         "    match Io.readLine() {\n"
                         "        Some(\"wave\") -> told(\"wave\", Peer.spawn(\"desk\", Greet.wave,"
                         " 5000))\n"
                         "      | Some(name) -> told(name, Peer.spawn(\"desk\", Greet.hello,"
                         " 5000))\n"
                         "      | None -> Unit\n"
                         "    }\n"
                         "\n"
                         "fn told(name : String, spawned : Either(Io.Error, Address(Never)))"
                         " : Unit with m = {\n"
                         "    let answer = match spawned {\n"
                         "        Right(_) -> \"Right\"\n"
                         "      | Left(failure) -> Io.show(failure)\n"
                         "    };\n"
                         "    Io.println(name <> \": \" <> answer);\n"
                         "    spawning()\n"
                         "}\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Changed = fun(Text) ->
                  ok = file:write_file(filename:join(Source, "greet.ern"),
                                       Greet(["\nexport fn other() : Unit with Never ="
                                              " Io.println(\"", Text, "\")\n"]))
              end,
    Changed("another function"),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "store.erc"), []),
    prints(Store, "ready"),
    {DeskInput, WaitDesk} = shell_started(Desk, Source, [Root]),
    %% the desk dials the store, which does not hold the lambda
    true = port_command(DeskInput,
                        "Peer.spawn(\"store\", fn() : Unit with Never = Unit, 5000)\n"),
    prints(Desk, "Left(NotLoaded) : Either(Io.Error, Address(Never))"),
    true = port_command(StoreInput, "first\n"),
    prints(Store, "first: NotLoaded"),
    true = port_command(DeskInput, ":load Greet\n"),
    prints(Desk, "Greet, compiled from greet.ern"),
    true = port_command(StoreInput, "loaded\n"),
    prints(Store, "loaded: Right"),
    prints(Desk, "hello greeted 0"),
    true = port_command(DeskInput, "Greet.greet(\"prompt\")\n"),
    prints(Desk, "prompt greeted 1"),
    Changed("another function changed"),
    true = port_command(DeskInput, ":reload\n"),
    prints(Desk, "Greet, compiled again"),
    true = port_command(StoreInput, "wave\n"),
    prints(Store, "wave: Right"),
    prints(Desk, "wave greeted 0"),
    true = port_command(DeskInput, "Greet.greet(\"again\")\n"),
    prints(Desk, "again greeted 1"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, DeskErr} = said(Desk),
    ?assertEqual(nomatch, string:find(DeskOut, "wave greeted 2")),
    %% the shell writes the node's lines on its screen
    has(DeskOut, "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
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
%% regression test, written after the fix (finding S2's read-back): the
%% binding was found by its identity in the session's greeter, the build's
%% caller ran, and its process faulted, the binding read in the build's
%% greeter having no value
shell_node_reach_test_() ->
    nodes_test(90, fun shell_node_reach/1).

shell_node_reach(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    Greet = "let greeting : String = \"hello from the greeter\"\n"
            "\n"
            "export fn hello() : Unit with Never = Io.println(greeting)\n",
    Caller = "export fn call() : Unit with Never = Greet.hello()\n",
    ok = file:write_file(filename:join(Root, "greet.ern"), Greet),
    ok = file:write_file(filename:join(Root, "caller.ern"), Caller),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of Caller.call at each line.\n"
                         "\n"
                         "export fn main() : Unit with Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit with m =\n"
                         "    match Io.readLine() {\n"
                         "        Some(name) -> {\n"
                         "            let spawned = Peer.spawn(\"desk\", Caller.call, 5000);\n"
                         "            let answer = match spawned {\n"
                         "                Right(_) -> \"Right\"\n"
                         "              | Left(failure) -> Io.show(failure)\n"
                         "            };\n"
                         "            Io.println(name <> \": \" <> answer);\n"
                         "            spawning()\n"
                         "        }\n"
                         "      | None -> Unit\n"
                         "    }\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Other = "\nexport fn other() : Unit with Never = Io.println(\"other\")\n",
    ok = file:write_file(filename:join(Source, "greet.ern"), [Greet, Other]),
    ok = file:write_file(filename:join(Source, "caller.ern"), Caller),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "store.erc"), []),
    prints(Store, "ready"),
    {DeskInput, WaitDesk} = shell_started(Desk, Source, [Root]),
    true = port_command(DeskInput, ":load Greet\n"),
    prints(Desk, "Greet, compiled from greet.ern"),
    %% the desk dials the store, which does not hold the lambda
    true = port_command(DeskInput,
                        "Peer.spawn(\"store\", fn() : Unit with Never = Unit, 5000)\n"),
    prints(Desk, "Left(NotLoaded) : Either(Io.Error, Address(Never))"),
    true = port_command(StoreInput, "first\n"),
    prints(Store, "first: NotLoaded"),
    true = port_command(DeskInput, ":load Caller\n"),
    prints(Desk, "Caller, compiled from caller.ern"),
    true = port_command(StoreInput, "second\n"),
    prints(Store, "second: Right"),
    prints(Desk, "hello from the greeter"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, DeskErr} = said(Desk),
    %% the shell writes the node's lines on its screen
    has(DeskOut, "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
                 " Greet.greeting has no value here"),
    [?assertEqual(nomatch, string:find(Text, "fault")) || Text <- [DeskOut, DeskErr]].

%% report §11.2, §6.9, §8.7: on a shell that is a node over a build, a
%% refused `:load` that evaluated a unit of the build, which the node held
%% and the session had not evaluated, kills the process that unit's binding
%% spawned and names it, and leaves the unit as it was before the load: a
%% peer's spawn of its function is NotLoaded, its binding without its value
%% here, before the load and after it alike. A regression test, written
%% after the fix (findings V4, V1): the process ran on unnamed, since it ran
%% no code the load brought, while the load erased the unit's values
refused_build_load_test_() ->
    nodes_test(90, fun refused_build_load/1).

refused_build_load(Base) ->
    Root = filename:join(Base, "build"),
    Source = filename:join(Base, "src"),
    [ok = filelib:ensure_path(Dir) || Dir <- [Root, Source]],
    ok = file:write_file(filename:join(Root, "greet.ern"),
                         "// A greeter whose service is a binding, and what a peer spawns.\n"
                         "\n"
                         "export type Msg = Greet(String)\n"
                         "\n"
                         "let greeter : Address(Msg) = spawn(fn() : Unit with Msg = greeted(0))\n"
                         "\n"
                         "fn greeted(count : Int) : Unit with Msg =\n"
                         "    receive {\n"
                         "        Greet(who) -> {\n"
                         "            Io.println(who <> \" greeted \" <> Int.toString(count));\n"
                         "            greeted(count + 1)\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "export fn hello() : Unit with Never = send(greeter, Greet(\"hello\"))\n"),
    ok = file:write_file(filename:join(Root, "store.ern"),
                         "// A spawn on the shell's node of Greet.hello at each line.\n"
                         "\n"
                         "export fn main() : Unit with Unit = {\n"
                         "    Io.println(\"ready\");\n"
                         "    spawning()\n"
                         "}\n"
                         "\n"
                         "fn spawning() : Unit with m =\n"
                         "    match Io.readLine() {\n"
                         "        Some(name) -> {\n"
                         "            let spawned = Peer.spawn(\"desk\", Greet.hello, 5000);\n"
                         "            let answer = match spawned {\n"
                         "                Right(_) -> \"Right\"\n"
                         "              | Left(failure) -> Io.show(failure)\n"
                         "            };\n"
                         "            Io.println(name <> \": \" <> answer);\n"
                         "            spawning()\n"
                         "        }\n"
                         "      | None -> Unit\n"
                         "    }\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    ok = file:write_file(filename:join(Source, "bad.ern"),
                         "export let greeted : Unit = Greet.hello()\n"
                         "\n"
                         "export let broken : Int = 1 / List.size([])\n"),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "store.erc"), []),
    prints(Store, "ready"),
    {DeskInput, WaitDesk} = shell_started(Desk, Source, [Root]),
    %% the desk dials the store, which does not hold the lambda
    true = port_command(DeskInput,
                        "Peer.spawn(\"store\", fn() : Unit with Never = Unit, 5000)\n"),
    prints(Desk, "Left(NotLoaded) : Either(Io.Error, Address(Never))"),
    true = port_command(StoreInput, "before\n"),
    prints(Store, "before: NotLoaded"),
    true = port_command(DeskInput, ":load Bad\n"),
    prints(Desk, "Bad.broken:3 faulted: division by zero; nothing was loaded, and the process"
                 " spawned at Greet.greeter:5 was killed"),
    true = port_command(DeskInput, ":processes\n"),
    prints(Desk, "no process of the session's is running"),
    true = port_command(StoreInput, "after\n"),
    prints(Store, "after: NotLoaded"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, DeskErr} = said(Desk),
    %% the shell writes the node's lines on its screen
    ?assertEqual(2, length(string:split(DeskOut, "the peer store's spawn at Store.spawning:11 was"
                                                 " not loaded: the binding Greet.greeter has no"
                                                 " value here", all)) - 1),
    ?assertEqual(nomatch, string:find(DeskErr, "fault")).

%% report §6.5, §8.4, §6.9, §8.7: a fault in an adapted address's function,
%% applied where the address was made as a message from another node
%% arrives, takes the message's place in the target's mailbox: the
%% restarting target faults at its wait, is reported restarted with the
%% cause, and its new run takes the next message; the sender goes on. A
%% regression test, written after the fix (finding W3): the fault killed the
%% target by an exit signal, so it ended without a restart, and the next
%% message was lost
adapted_fault_test_() ->
    nodes_test(90, fun adapted_fault/1).

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
                         "let key : Peer.Key(Int) = Peer.key(\"work\")\n"
                         "\n"
                         "export fn main() : Unit with Unit =\n"
                         "    match Os.arguments {\n"
                         "        [\"make\"] -> make()\n"
                         "      | _ -> sending()\n"
                         "    }\n"
                         "\n"
                         "fn make() : Unit with Unit = {\n"
                         "    let maker = self();\n"
                         "    let worker = spawn(restarting(RestartLimit(restarts = 3,"
                         " within = 60000),\n"
                         "                                  fn() : Unit with Msg = {\n"
                         "                                      send(maker, Unit);\n"
                         "                                      work()\n"
                         "                                  }));\n"
                         "    let _ = Peer.offer(key, via(worker, fn(n) = Work(100 / n)));\n"
                         "    runs(1)\n"
                         "}\n"
                         "\n"
                         "fn runs(count : Int) : Unit with Unit =\n"
                         "    receive {\n"
                         "        _ -> {\n"
                         "            Io.println(\"run \" <> Int.toString(count));\n"
                         "            runs(count + 1)\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "fn work() : Unit with Msg =\n"
                         "    receive {\n"
                         "        Work(n) -> {\n"
                         "            Io.println(\"took \" <> Int.toString(n));\n"
                         "            work()\n"
                         "        }\n"
                         "    }\n"
                         "\n"
                         "fn sending() : Unit with Unit =\n"
                         "    match Peer.find(key, 5000) {\n"
                         "        Right(work) -> {\n"
                         "            Io.println(\"found\");\n"
                         "            sent(work)\n"
                         "        }\n"
                         "      | Left(failure) -> Io.println(Io.show(failure))\n"
                         "    }\n"
                         "\n"
                         "fn sent(work : Address(Int)) : Unit with Unit =\n"
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
                         "    }\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Program = filename:join(Root, "adapted.erc"),
    PortMaker = free_port(),
    Maker = made(Base, "maker", PortMaker),
    Sender = made(Base, "sender", none),
    lists(Maker, [{"sender", Sender, none}]),
    lists(Sender, [{"maker", Maker, PortMaker}]),
    edit(Sender, fun(Conf) -> Conf#{<<"keys">> => #{<<"work">> => [<<"maker">>]}} end),
    WaitMaker = start(Maker, Program, ["make"]),
    prints(Maker, "run 1"),
    {SenderInput, WaitSender} = started(Sender, Program, []),
    prints(Sender, "found"),
    true = port_command(SenderInput, "zero\n"),
    prints(Sender, "sent 0"),
    says(Maker, "faulted, restarted: division by zero"),
    %% the new run has begun, its mailbox emptied of the old (§6.9)
    prints(Maker, "run 2"),
    true = port_command(SenderInput, "five\n"),
    prints(Sender, "sent 5"),
    prints(Maker, "took 20"),
    stop(Sender, WaitSender),
    stop(Maker, WaitMaker),
    {_, SenderErr} = said(Sender),
    ?assertEqual(nomatch, string:find(SenderErr, "fault")).

%%
%% The end told, and the standing address (report §8.6, Appendix E.23, G.7)
%%

%% The directory test/peers/'s programs are built in (peers/1), the
%% counter's keeper, its asker and the standing address's client among
%% them.
built(Base) ->
    {Program, _} = peers(Base),
    filename:dirname(Program).

%% report §8.6, §8.7, Appendix E.23: termination, here `ern stop`'s, tells
%% the node's subscriber, which the node says it waits for; while it
%% waits, a peer finds the node's service and calls it; the node ends once
%% the subscriber has answered, by the signal, and says the answer. Written
%% after the code (MVP 3.1's item 8)
end_told_on_a_node_test_() ->
    nodes_test(90, fun end_told_on_a_node/1).

end_told_on_a_node(Base) ->
    Root = built(Base),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    edit(Desk, fun(Conf) -> Conf#{<<"keys">> => #{<<"counter">> => [<<"store">>]}} end),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "keeper.erc"), ["wait"]),
    prints(Store, "offered"),
    terminated(Store),
    prints(Store, "told"),
    says(Store, "the end waits for 1 subscriber: Keeper.main"),
    ?assertEqual(0, (start(Desk, filename:join(Root, "asker.erc"), []))()),
    true = port_command(StoreInput, "go\n"),
    ?assertEqual(143, WaitStore()),
    {DeskOut, _} = said(Desk),
    {_, StoreErr} = said(Store),
    has(DeskOut, "asked: Some(3)"),
    has(StoreErr, "the subscriber Keeper.main answered").

%% report §8.6, §11.2: a second termination ends the node at once, past a
%% subscriber that does not answer, which the node says. Written after the
%% code (MVP 3.1's item 8), the line after that
second_termination_test_() ->
    nodes_test(60, fun second_termination/1).

second_termination(Base) ->
    Root = built(Base),
    Store = made(Base, "store", none),
    WaitStore = start(Store, filename:join(Root, "keeper.erc"), ["hold"]),
    prints(Store, "offered"),
    terminated(Store),
    says(Store, "the end waits for 1 subscriber: Keeper.main"),
    terminated(Store),
    ?assertEqual(143, WaitStore()),
    {_, Err} = said(Store),
    has(Err, "the end was cut short, 1 subscriber unanswered: Keeper.main"),
    ?assertEqual(nomatch, string:find(Err, "the subscriber Keeper.main")).

%% Appendix G.7, report §8.7: a standing address reaches the counter, a
%% call through it answers None while the counter's node is stopped, it
%% reaches the counter again when its node starts again, and on another
%% node that offers it once the first is stopped. An add sent through it
%% while the node is stopped is dropped, and not delivered once the node is
%% back: the counter started again counts from 0, and answers 0. Written
%% after the code (MVP 3.1's item 8), the add a regression test written
%% after that
standing_test_() ->
    nodes_test(120, fun standing/1).

standing(Base) ->
    Root = built(Base),
    {PortStore, PortOther} = {free_port(), free_port()},
    Store = made(Base, "store", PortStore),
    Other = made(Base, "other", PortOther),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Other, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}, {"other", Other, PortOther}]),
    edit(Desk, fun(Conf) ->
                   Conf#{<<"keys">> => #{<<"counter">> => [<<"store">>, <<"other">>]}}
               end),
    Keeper = filename:join(Root, "keeper.erc"),
    WaitStore = start(Store, Keeper, []),
    prints(Store, "offered"),
    {DeskInput, WaitDesk} = started(Desk, filename:join(Root, "client.erc"), []),
    prints(Desk, "standing"),
    Ask = fun(Line) -> true = port_command(DeskInput, "go\n"), prints(Desk, Line) end,
    Ask("first: Some(0)"),
    stop(Store, WaitStore),
    Ask("away: None"),
    WaitStoreAgain = start(Store, Keeper, []),
    prints(Store, "offered"),
    Ask("back: Some(0)"),
    stop(Store, WaitStoreAgain),
    WaitOther = start(Other, Keeper, []),
    prints(Other, "offered"),
    Ask("other: Some(0)"),
    ?assertEqual(0, WaitDesk()),
    stop(Other, WaitOther).

%% Appendix G.4, G.5, report §8.7: a balancer over this node and the store
%% picks in turn until a place has a measure, and then the lower of the
%% measures installed on each, the store's spawned there with Peer.spawn;
%% the work goes where it picks; Load answers the host's services' loads
%% on the store, whose measures run them, and none on the desk, whose do
%% not. A regression test, written after the code; it does not cover a
%% place out of reach, nor a pick of two among more than two places
balance_test_() ->
    nodes_test(90, fun balance/1).

balance(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    edit(Store, fun(Conf) ->
                    Conf#{<<"measures">> => #{<<"cpu">> => #{}, <<"memory">> => #{},
                                              <<"disk">> => #{}}}
                end),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["balance"]))()),
    prints(Store, "loads there"),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {StoreOut, StoreErr} = said(Store),
    %% report §8.7: the host's own reports are not written; a regression:
    %% the program the host runs for the cpu measure said, as the host
    %% ended, that the host had closed
    ?assertEqual(nomatch, string:find(StoreErr, "Erlang has closed")),
    [has(Out, Line)
     || Line <- ["in turn: #(Some(Here), Some(On(\"store\")))", "measured: Right",
                 "picked: the store three times in a row", "work: Right",
                 "loads here: #(false, false, false)", "loads: Right"]],
    has(StoreOut, "the store squares 36"),
    has(StoreOut, "loads there: #(true, true, true)").

%% report §8.7, §11.2, Appendix E.23, Appendix G.6: a program's own test of two
%% nodes, `ern test --config-dir a` as a node. The harness makes two
%% directories as `ern config` makes them, `a` listening and listing `b`
%% under the key `pair`, and says in `pair.json` the port `b` listens on and
%% the load path `a` runs with; the test, in Ernest, writes `b`'s
%% `ernest.conf` listing `a`, starts `b` with `Os` on the same build, finds
%% and calls what it offers, and ends it with `ern stop`; a second test
%% starts `b` with `Os` on a second build, whose `Msg` has another
%% constructor (second_build/1), and finds `OtherType` at its key, the type
%% it offers at having another hash. A regression test, written after the
%% code; it does not cover a reload, whose end a program cannot see (§8.7:
%% the signal carries nothing back)
program_test_() ->
    nodes_test(90, fun pair_program/1).

pair_program(Base) ->
    _ = peers(Base),
    second_build(Base),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, PortB}]),
    edit(A, fun(Conf) -> Conf#{<<"keys">> => #{<<"pair">> => [<<"b">>]}} end),
    Settings = #{<<"port">> => PortB,
                 <<"load-path">> => [list_to_binary(Library) || Library <- ?LIBRARIES],
                 <<"build">> => <<"build/pair.erc">>,
                 <<"second-build">> => <<"second-build/pair.erc">>},
    ok = file:write_file(filename:join(Base, "pair.json"), json:encode(Settings)),
    Command = lists:flatten([?ERN, " test --config-dir a",
                             [[" --load-path ", Library] || Library <- ?LIBRARIES],
                             " build/pair.erc 2>&1"]),
    %% `ern` on the path, as the test starts it by its name (Appendix E.23)
    Path = filename:dirname(?ERN) ++ ":" ++ os:getenv("PATH"),
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", Command]}, {cd, Base}, {env, [{"PATH", Path}]},
                      exit_status, binary, stderr_to_stdout]),
    {Status, Output} = collected(Port, <<>>),
    ?assertEqual({0, nomatch}, {Status, binary:match(Output, <<"failed">>)}),
    has(binary_to_list(Output), "a second node made, started with Os, found, called and stopped:"
                                " passed"),
    has(binary_to_list(Output), "a second node of another build, started with Os, offers at another"
                                " type: passed"),
    ?assertNot(filelib:is_regular(filename:join(B, "ernest.pid"))).

%% Report §8.7: a second build of test/peers/pair.ern, its `Msg` given
%% another constructor, so that its key's type has another hash, built in
%% Base/second-build.
second_build(Base) ->
    {ok, Source} = file:read_file("peers/pair.ern"),
    Declared = <<"export type Msg = Double(n : Int, reply : Reply(Int))">>,
    Changed = binary:replace(Source, Declared, <<Declared/binary, " | Halve(Int)">>),
    ?assertNotEqual(Source, Changed),
    Root = filename:join(Base, "second"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "pair.ern"), Changed),
    0 = ern_cli:ern(["build", "--source-root", Root, "--build-root",
                     filename:join(Base, "second-build")]
                    ++ lists:append([["--load-path", Library] || Library <- ?LIBRARIES])
                    ++ [filename:join(Root, "pair.ern")], group_leader()).

%% A port's output to its end, and its exit status.
collected(Port, Acc) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, <<Acc/binary, Bytes/binary>>);
        {Port, {exit_status, Status}} -> {Status, Acc}
    end.

%% The process number in a node's ernest.pid.
pid(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.pid")),
    string:trim(binary_to_list(Text)).

%% report §8.7, the proposal's sections 4, 7 and 8: a peer stopped stands
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
    nodes_test(180, fun silence/1).

silence(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["silence"]),
    prints(Desk, "now stop the store"),
    _ = os:cmd("kill -STOP " ++ pid(Store)),
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now let the store run", 100000),
    _ = os:cmd("kill -CONT " ++ pid(Store)),
    says(Store, "the peer desk was lost", 30000),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    [has(Out, Line)
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
    edit(Dir, fun(#{<<"peers">> := Peers} = Conf) ->
                  Conf#{<<"peers">> := [case Peer of
                                            #{<<"name">> := Name} ->
                                                Peer#{<<"network-address">> => address(Port)};
                                            _ ->
                                                Peer
                                        end || Peer <- Peers]}
              end).

%% A listener on the loopback that takes connections and answers nothing.
answers_nothing() ->
    {ok, Listener} = gen_tcp:listen(0, [binary, {ip, {127, 0, 0, 1}}, {active, false}]),
    {ok, Port} = inet:port(Listener),
    Holder = spawn(fun() -> receive go -> held(Listener, []) end end),
    ok = gen_tcp:controlling_process(Listener, Holder),
    Holder ! go,
    Port.

held(Listener, Sockets) ->
    {ok, Socket} = gen_tcp:accept(Listener),
    held(Listener, [Socket | Sockets]).

%% report §8.7, the proposal's sections 4 and 8: a network parted through
%% a proxy that drops what passes from the desk to the store: the store,
%% hearing nothing, gives the desk up within the detector's time and closes
%% the connection, so that the desk learns of the loss too, and what the
%% silence test holds of a loss holds; the proxy healed, the address reaches
%% its process again. A regression test, written after the code
parted_one_way_test_() ->
    nodes_test(180, fun(Base) -> parted(Base, true, false, "closed") end).

%% report §8.7, the proposal's sections 4 and 8: the same, the proxy
%% dropping what passes both ways, so that each node gives the other up by
%% its own detector. A regression test, written after the code
parted_both_ways_test_() ->
    nodes_test(180, fun(Base) -> parted(Base, true, true, "fell silent") end).

parted(Base, ToStore, FromStore, DeskSays) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    {ProxyPort, Proxy} = proxy(listen_port(Store)),
    readdressed(Desk, <<"store">>, ProxyPort),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["silence"]),
    prints(Desk, "now stop the store"),
    Proxy ! {drop, ToStore, FromStore},
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now let the store run", 100000),
    Proxy ! heal,
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {Out, Err} = said(Desk),
    {_, StoreErr} = said(Store),
    [has(Out, Line)
     || Line <- ["counted: Some(10000)", "silent: Unreachable \"\"", "the call: None",
                 "its forever caller: Fault(\"callee is unreachable\")", "own process: Some(0)",
                 "again: Some(10000)"]],
    has(StoreErr, "the peer desk was lost: it fell silent"),
    has(Err, "the peer store was lost: it " ++ DeskSays),
    given_up_within_the_detectors_time(Out).

%% report §8.7, the proposal's section 7: a dial that nothing answers, to a
%% listener that takes the connection and says nothing, is given up after
%% the host's 7 seconds, and a find on that peer answers Unreachable, not
%% Timeout, though its time is longer. A regression test, written after the
%% code
dial_test_() ->
    nodes_test(90, fun dial/1).

dial(Base) ->
    {_, DeskProgram} = peers(Base),
    {_, Desk} = store_and_desk(Base),
    readdressed(Desk, <<"store">>, answers_nothing()),
    ?assertEqual(0, (start(Desk, DeskProgram, ["dial"]))()),
    {Out, _} = said(Desk),
    {match, [Seconds]} = re:run(Out, "dialled: Left\\(Unreachable\\) after ([0-9]+)",
                                [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Seconds) >= 6),
    ?assert(list_to_integer(Seconds) =< 9).

%% The seconds the desk says the detector took, held to the detector's 45 to
%% 75 (the proposal's section 7): no fewer than 44, the desk counting whole
%% seconds from just after the silence began, and no more than 80, the 75
%% and the test's own steps around it, the desk's read of its standard input
%% and the three Downs it waits for.
given_up_within_the_detectors_time(Out) ->
    {match, [Seconds]} = re:run(Out, "given up after: ([0-9]+)", [{capture, all_but_first, list}]),
    ?assert(list_to_integer(Seconds) >= 44),
    ?assert(list_to_integer(Seconds) =< 80).
