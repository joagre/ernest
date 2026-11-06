%% Nodes on one machine (report §8.7, MVP 3.0): each node an `ern run
%% --config-dir` of its own, started as a person starts one, its lines read
%% from its standard error. The carrier's tests dial through a `foreign fn`
%% of the host's, which reaches the carrier and nothing of a program's; the
%% frame a gateway cannot read is sent by a host module on the program's
%% load path; a host that holds a peer's key and names itself as it likes
%% is a bare `erl` with the host's TLS distribution and the key's files.
%%
%% `Peer`'s tests run the programs of `test/fixtures/peers/`, one build
%% whose store and desk are two nodes; the tests of two builds (MVP 3.1)
%% write a program and build it twice, one function and one type changed. A
%% test that provokes a line the deployment guide quotes holds it to the
%% guide's (ern_deployment_tests:cataloged/4), and the harness is exported
%% for ern_deployment_tests, which runs the guide's commands on nodes.
-module(ern_nodes_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("public_key/include/public_key.hrl").
-include_lib("checker/include/ern_canonical.hrl").

-export([nodes_test/2, counted_test/2, counted_test/3, step/1, step/2, free_port/0, made/3,
         address/1, edit/2, configuration/1, lists/2, peer/3, name/1, program/1, built/1,
         wait_ms_text/0, client/0, client/8, key_files/1, start/3, bare_started/2, bound_port/1,
         launched/2, says/2, says/3, prints/2, prints/4, stop/2, written/2, said/1, wait_ms/0,
         detector_ms/0, has/2, connected/2, accepted/1, received/2, collected/2]).

%% What waits for a node's end: its status, or `timeout` where it has not
%% ended within the harness's time for one wait.
-type wait() :: fun(() -> integer() | timeout).

-define(ERN, filename:absname("../bin/ern")).
%% The block free_port/0 takes from, ending where Linux's default ephemeral
%% range begins, whose macOS counterpart begins higher.
-define(FIRST_PORT, 16384).
-define(PORTS, 16384).
%% Report §11.2: what a shell prints of a spawn on a peer that started, the
%% process's address the screen writes before it.
-define(SPAWNED, ") : Either(Io.Error, Address(Never))").
%% The milliseconds that bound one step of a test's: each wait the harness
%% runs, for a node's line, its end, what it said, a bare `erl`'s run or a
%% command's to its end, a build, or an input typed at a shell, the
%% harness's own functions counting each as they run it (step/1); a step
%% that waits a time the report states beside them, a dial's or the
%% detector's, is given that time too. It is the unit every bound of these
%% tests counts in: a test's limit is its steps' sum (nodes_test/2), and
%% each find, spawn, compute, call and utilization of a program a test runs
%% is given it (wait_ms_declaration/0, test/fixtures/peers/harness.ern),
%% since an answer later than it has failed its step, whichever says so
%% first, the answer's time or the test. A build runs in the test's own
%% process, bounded by the test's limit alone.
-define(WAIT_MS, 30000).
%% The key of the test process's dictionary that holds the steps of the
%% test it runs, {Count, Taken} (counted/2).
-define(STEPS, '$ern_steps').
%% Report §8.7: the host gives up a dial that nothing answers after 7
%% seconds.
-define(DIAL_MS, 7000).
%% Report §12.6: the detector finds a silent peer at most 75 seconds after
%% its last traffic.
-define(DETECTOR_MS, 75000).
%% Report §11.2: the time before a line a node writes where its stream is
%% no terminal.
-define(STAMP, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z ").

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
%% Its time is the sum of its steps' bounds, Count steps each bounded by
%% the harness's time for one wait (waits/1) and the Beyond milliseconds
%% of the report's times its steps wait beside them, so that a step that
%% fails is told by its own bound before the test's runs out; and its
%% steps are counted as it takes them, Count of them (counted/2).
-spec nodes_test({waits, pos_integer()} | {waits, pos_integer(), non_neg_integer()},
                 fun((file:filename()) -> term())) ->
          {setup, fun(() -> file:filename()), fun((file:filename()) -> ok),
           fun((file:filename()) -> tuple())}.
nodes_test({waits, Count}, Test) ->
    nodes_test({waits, Count, 0}, Test);
nodes_test({waits, Count, Beyond}, Test) ->
    {name, Name} = erlang:fun_info(Test, name),
    {setup, fun tmp/0, fun killed/1,
     fun(Base) ->
         {timeout, waits(Count) + Beyond div 1000,
          {atom_to_list(Name), fun() -> counted(Count, fun() -> Test(Base) end) end}}
     end}.

%% A test of the harness's steps that starts no node here, an integration
%% test's, the shell's or the terminal's: its time and its count as a
%% nodes test's, named by its function.
-spec counted_test({waits, pos_integer()}, fun(() -> term())) ->
          {timeout, pos_integer(), {string(), fun(() -> ok)}}.
counted_test({waits, Count}, Test) ->
    {module, Module} = erlang:fun_info(Test, module),
    {name, Name} = erlang:fun_info(Test, name),
    counted_test(lists:concat([Module, ":", Name]), {waits, Count}, Test).

%% The same, named Name, for a test whose function is a closure, one of
%% the many a document's examples make (ern_guide_tests).
-spec counted_test(string(), {waits, pos_integer()}, fun(() -> term())) ->
          {timeout, pos_integer(), {string(), fun(() -> ok)}}.
counted_test(Name, {waits, Count}, Test) ->
    {timeout, waits(Count), {Name, fun() -> counted(Count, Test) end}}.

%% A test's limit in seconds, as EUnit's `timeout` takes it: its Count
%% steps, each bounded by the harness's time for one wait. EUnit's limit is
%% the fallback for a wait that holds up the harness itself, a build's
%% among them.
waits(Count) ->
    Count * ?WAIT_MS div 1000.

%% Test run with its steps counted, Count of them, each a wait of the
%% harness's (step/1): a step past Count fails the test at once, naming the
%% step, and a test that ends having taken fewer fails, naming both
%% numbers, so that a test's count is its steps' and its limit their sum.
counted(Count, Test) ->
    put(?STEPS, {Count, 0}),
    try
        _ = Test(),
        {Count, Taken} = get(?STEPS),
        Taken =:= Count orelse erlang:error({fewer_steps_than_counted, Taken, Count}),
        ok
    after
        erase(?STEPS)
    end.

%% One step of the test the calling process runs taken, What naming it, or
%% Steps of them for a wait the harness cannot see the steps of, a run that
%% gives each of its own waits the harness's time for one wait, a script's
%% or `ern test`'s, whose test gives that number to the harness's function
%% that waits for it. The harness's own functions take the steps as they
%% wait. A process that runs no counted test, a tool's or a test's of
%% another area, counts nothing.
-spec step(term()) -> ok.
step(What) ->
    step(What, 1).

-spec step(term(), pos_integer()) -> ok.
step(What, Steps) ->
    case get(?STEPS) of
        undefined ->
            ok;
        {Count, Taken} when Taken + Steps > Count ->
            erlang:error({steps_past_the_count, Count, What});
        {Count, Taken} ->
            put(?STEPS, {Count, Taken + Steps}),
            ok
    end.

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

%% A port nothing holds now on the loopback interface, for a node to bind
%% later. It comes from below the host's ephemeral range, since until the
%% node binds it nothing holds it for the node, and a connection a test
%% beside this one opens draws its port from that range. The counter keeps
%% two tests of this run apart, and the process number two runs at once.
-spec free_port() -> inet:port_number().
free_port() ->
    Taken = list_to_integer(os:getpid()) + erlang:unique_integer([positive, monotonic]),
    Port = ?FIRST_PORT + Taken rem ?PORTS,
    case gen_tcp:listen(Port, [{ip, {127, 0, 0, 1}}]) of
        {ok, Socket} ->
            ok = gen_tcp:close(Socket),
            Port;
        {error, eaddrinuse} ->
            free_port()
    end.

%% A configuration directory `ern config` made, listening on Listen, a
%% port of the loopback interface, or not at all.
-spec made(file:filename(), string(), none | inet:port_number()) -> file:filename().
made(Base, Name, Listen) ->
    Dir = filename:join(Base, Name),
    _ = ern_node:create(Dir, case Listen of
                                 none -> none;
                                 Port -> binary_to_list(address(Port))
                             end),
    Dir.

%% Report Appendix C: the `listen` or the `network-address` of a node at
%% Port of the loopback interface.
-spec address(inet:port_number()) -> binary().
address(Port) ->
    list_to_binary("127.0.0.1:" ++ integer_to_list(Port)).

%% Report Appendix C: the node's `ernest.conf` changed by Change.
-spec edit(file:filename(), fun((map()) -> map())) -> ok.
edit(Dir, Change) ->
    ok = file:write_file(filename:join(Dir, "ernest.conf"),
                         json:encode(Change(configuration(Dir)))).

%% Report Appendix C: the node's `ernest.conf`, read.
-spec configuration(file:filename()) -> map().
configuration(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    json:decode(Text).

public(Dir) ->
    maps:get(<<"public-key">>, configuration(Dir)).

%% Dir lists each of Peers, {Name, PeerDir, Port}, a port or none.
-spec lists(file:filename(), [{string(), file:filename(), none | inet:port_number()}]) -> ok.
lists(Dir, Peers) ->
    edit(Dir, fun(Conf) ->
                  Conf#{<<"peers">> => [peer(Name, PeerDir, Port)
                                        || {Name, PeerDir, Port} <- Peers]}
              end).

%% Report Appendix C: a peer's entry in a node's `peers`, the node of the
%% directory Dir by Name, dialed at Port of the loopback interface, or never.
-spec peer(string(), file:filename(), none | inet:port_number()) -> map().
peer(Name, Dir, none) ->
    #{<<"name">> => list_to_binary(Name), <<"public-key">> => public(Dir)};
peer(Name, Dir, Port) ->
    (peer(Name, Dir, none))#{<<"network-address">> => address(Port)}.

%% A node's name on the carrier.
-spec name(file:filename()) -> string().
name(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    atom_to_list(ern_carrier:name(Der)).

%% A node's key's digest, as a refusal names an unlisted key.
digest(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Der), lowercase)).

%% The test program, built in Root: it dials a peer, sends it a frame its
%% gateway cannot read, sends it a spawn of the function whose hash it is
%% given with a site that is not UTF-8, asks how busy a peer is, or waits,
%% as its arguments say.
-spec program(file:filename()) -> file:filename().
program(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "node.ern"), [<<"
foreign fn connect(node : Foreign.Term) : Bool = \"net_kernel:connect_node/1\"
foreign fn frame(node : Foreign.Term) : Unit = \"ern_nodes_frame:send/1\"
foreign fn site(node : Foreign.Term, hash : String) : Unit = \"ern_nodes_frame:site/2\"

export fn main() : Unit receiving Unit =
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
      | [\"utilization\", peer] ->
            Io.println(\"utilization: \" <> Io.show(Peer.utilization(peer, waitMs())))
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
fn held() : Unit receiving Unit = receive { _ -> held() }
">>, wait_ms_declaration()]),
    ok = file:write_file(filename:join(Root, "ern_nodes_frame.erl"), <<"
-module(ern_nodes_frame).
-export([send/1, site/2]).
send(Node) ->
    erlang:send({ern_gateway, Node}, unreadable),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), unreadable}),
    'Unit'.
site(Node, Hash) ->
    Spawned = {function, binary:decode_hex(Hash)},
    %% the site alone out of shape, the spawner waiting nothing
    Frame = {spawn, make_ref(), Spawned, false, <<255>>, false, 0},
    erlang:send({ern_gateway, Node}, {ern_frame, self(), Frame}),
    'Unit'.
">>),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_frame.erl"), [{outdir, Root}]),
    ok = file:write_file(filename:join(Root, "ern_nodes_client.erl"), client()),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_client.erl"), [{outdir, Root}]),
    0 = built([Root]),
    filename:join(Root, "node.erc").

%% Report §11.1: `ern build` with the words Words after it, run in the
%% test's own process as the command line runs it, and its status: one
%% step. A host module a test compiles with the host's compiler is no step.
-spec built([string()]) -> integer().
built(Words) ->
    step({built, Words}),
    ern_cli:ern(["build" | Words], group_leader()).

%% The function a program the test writes gives each of its finds, spawns,
%% computes, calls and utilizations, the harness's time for one wait, as
%% the program's last declaration, so that no line above it moves.
wait_ms_declaration() ->
    ["\n"
     "// The milliseconds each find, spawn, compute, call and utilization here\n"
     "// waits: the test's time for one step, which an answer later than it\n"
     "// has failed, whichever says so first.\n"
     "fn waitMs() : Int = ", wait_ms_text(), "\n"].

%% The harness's time for one wait as an input typed at a shell writes it,
%% and a program a test writes gives it to a wait of its own.
-spec wait_ms_text() -> string().
wait_ms_text() ->
    integer_to_list(?WAIT_MS).

%% A host module for a bare `erl` that holds a peer's key: its port map,
%% which answers every name with the loopback port its command line gives,
%% and its run, which connects to the node its command line names, says
%% whether it could, asks the node its name over the connection, and, where
%% its command line says it waits, asks again once a line comes on its
%% standard input, ending at the input's end.
-spec client() -> binary().
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
    {ok, [[Ms]]} = init:get_argument(ern_nodes_ms),
    try erpc:call(Node, erlang, node, [], list_to_integer(Ms)) of
        Node -> ran
    catch
        error:{erpc, Reason} -> Reason
    end.
">>.

%% A bare `erl` that dials the node listening on Port as Name, presenting
%% the certificate and key given, with the cookie given, its module in
%% Root, and waiting for a line on its standard input before it asks again
%% where Wait says so, each ask given the harness's time for one wait;
%% answers the port whose writes are its standard input and whose messages
%% are its standard output, and the function that waits for its end, that
%% time again, and answers what it printed.
client(Root, Name, Keys, Cookie, Port, Target, Wait) ->
    client(Root, Name, Keys, Cookie, Port, Target, [Flag || Flag <- ["-ern_nodes_wait"], Wait],
           "ern_nodes_client").

%% The same, running Module's main/0 with the flags Flags, the epmd module
%% ern_nodes_client's, the harness's time for one wait its `-ern_nodes_ms`.
-spec client(file:filename(), string(), {file:filename(), file:filename()}, string(),
             inet:port_number(), string(), [string()], string()) ->
          {port(), fun(() -> {integer(), binary()})}.
client(Root, Name, {Certificate, Key}, Cookie, Port, Target, Flags, Module) ->
    Tls = lists:append([[Side ++ "_" ++ Option, Value]
                        || Side <- ["client", "server"],
                           {Option, Value} <- [{"certfile", Certificate}, {"keyfile", Key},
                                               {"verify", "verify_none"},
                                               {"versions", "tlsv1.3"}]]),
    Arguments = ["-noshell", "-pa", Root, "-name", Name, "-proto_dist", "inet_tls",
                 "-ssl_dist_opt" | Tls]
        ++ ["-epmd_module", "ern_nodes_client", "-start_epmd", "false", "-dist_listen", "false",
            "-connect_all", "false", "-setcookie", Cookie,
            "-ern_nodes_port", integer_to_list(Port), "-ern_nodes_target", Target,
            "-ern_nodes_ms", integer_to_list(?WAIT_MS)]
        ++ Flags ++ ["-s", Module, "main"],
    Client = open_port({spawn_executable, os:find_executable("erl")},
                       [{args, Arguments}, exit_status, binary, stderr_to_stdout]),
    {Client, fun() -> collected(Client, 1) end}.

%% The files of a node's key in its configuration directory, its
%% certificate and its private key.
-spec key_files(file:filename()) -> {file:filename(), file:filename()}.
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
-spec start(file:filename(), file:filename(), [string()]) -> wait().
start(Dir, Program, Arguments) ->
    {_Port, Wait} = started(Dir, Program, Arguments),
    Wait.

%% The same, with the port whose writes are the node's standard input. Its
%% standard output and standard error each go through a pipe that `tee`
%% reads, which writes the stream to a file beside the node's directory and
%% hands it to the node's watcher, so that a test waits on a line written
%% rather than reading the file again.
started(Dir, Program, Arguments) ->
    launched(Dir, [?ERN, " run --config-dir ", Dir, " ", Program,
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

%% A bare node, `ern run --config-dir` with no `.erc` (report §8.7, §11.2),
%% its load path LoadPath's directories; answers what waits for its end.
-spec bare_started(file:filename(), [file:filename()]) -> wait().
bare_started(Dir, LoadPath) ->
    {_Port, Wait} = launched(Dir, [?ERN, " run --config-dir ", Dir,
                                   [[" --load-path ", Root] || Root <- LoadPath]]),
    Wait.

%% The port a node whose `listen` names port 0 bound, once it says so
%% (report §12.5): the one line a bare node, which runs nothing of its own,
%% writes as it starts to listen.
-spec bound_port(file:filename()) -> inet:port_number().
bound_port(Dir) ->
    says(Dir, "listening on "),
    {match, [Port]} = re:run(written(Dir, err), "listening on [^ ]*:([0-9]+)\n",
                             [{capture, all_but_first, list}]),
    list_to_integer(Port).

%% A node started by the command Words, its standard input the port's
%% writes, and what waits for its end, the harness's time for one wait.
-spec launched(file:filename(), iodata()) -> {port(), wait()}.
launched(Dir, Words) ->
    Watcher = watcher(Dir),
    [Out, Err] = [piped(Watcher, Stream, Dir ++ Suffix)
                  || {Stream, Suffix} <- [{out, ".out"}, {err, ".err"}]],
    Command = lists:flatten([Words, " > ", Out, " 2> ", Err]),
    Port = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status]),
    {Port, fun() -> ended(Port, ?WAIT_MS) end}.

%% The status a node started through Port ended with, or `timeout` where it
%% has not ended within Ms: one step.
ended(Port, Ms) ->
    step({ended, Port}),
    receive {Port, {exit_status, Status}} -> Status after Ms -> timeout end.

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
        {waiting, _, _, _, _} = Wait ->
            told(Streams, [Wait | Waiting]);
        {said, _} = Wait ->
            told(Streams, [Wait | Waiting]);
        {written, Stream, From} ->
            {Text, _} = maps:get(Stream, Streams),
            From ! {written, Stream, Text},
            watching(Streams, Waiting)
    end.

%% The waits answered, the rest kept: a part once its stream holds it as
%% many times as asked, or has ended without, and the whole once both
%% streams have ended.
told(Streams, Waiting) ->
    watching(Streams, [Wait || Wait <- Waiting, not answered(Streams, Wait)]).

answered(Streams, {waiting, Stream, Part, Count, From}) ->
    case maps:get(Stream, Streams) of
        {Text, State} ->
            Held = length(binary:matches(Text, Part)) >= Count,
            case {Held, State} of
                {false, open} -> false;
                {_, _} -> From ! {seen, Stream, Part, Held}, true
            end
    end;
answered(#{out := {Out, ended}, err := {Err, ended}}, {said, From}) ->
    From ! {said, Out, Err},
    true;
answered(_, {said, _}) ->
    false.

%% Until the node's standard error holds Part; the harness's time for one
%% wait, or Ms where a wait outlasts it, bounds a failure.
-spec says(file:filename(), string()) -> ok.
says(Dir, Part) ->
    says(Dir, Part, ?WAIT_MS).

-spec says(file:filename(), string(), timeout()) -> ok.
says(Dir, Part, Ms) ->
    seen(Dir, err, Part, 1, Ms).

%% Until the node's standard output holds Part, or holds it Count times.
-spec prints(file:filename(), string()) -> ok.
prints(Dir, Part) ->
    prints(Dir, Part, ?WAIT_MS).

prints(Dir, Part, Ms) ->
    prints(Dir, Part, 1, Ms).

-spec prints(file:filename(), string(), pos_integer(), timeout()) -> ok.
prints(Dir, Part, Count, Ms) ->
    seen(Dir, out, Part, Count, Ms).

%% One step, the wait for a line.
seen(Dir, Stream, Part, Count, Ms) ->
    step({seen, Dir, Stream, Part}),
    waited(Dir, Stream, Part, Count, Ms).

waited(Dir, Stream, Part, Count, Ms) ->
    Bytes = unicode:characters_to_binary(Part),
    watcher_name(Dir) ! {waiting, Stream, Bytes, Count, self()},
    receive
        {seen, Stream, Bytes, true} -> ok;
        %% the stream ended without the part: what the node said on either
        %% stream is the cause
        {seen, Stream, Bytes, false} ->
            {Out, Err} = both_ended(Dir),
            erlang:error({ended_unsaid, Dir, Part, Out, Err})
    after Ms ->
        erlang:error({not_said, Dir, Part})
    end.

%% A waiting node ended by termination, which ends it with 128 and the
%% signal's number (report §11.2).
-spec stop(file:filename(), wait()) -> ok.
stop(Dir, Wait) ->
    terminated(Dir),
    ?assertEqual(143, Wait()).

%% A node sent termination, by the process its ernest.pid names.
terminated(Dir) ->
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ok.

%% Report §11.2: a fault reported while the shell waits for a line is
%% written before the next prompt, so the line of a fault a peer's spawn
%% made comes with the first input the shell reads once the fault has
%% reached it, which under load is not always the first typed after the
%% test saw what the process printed before it faulted. An input that
%% prints nothing is typed and the prompt it brings waited for, then
%% standard output read for Part, until it holds Part or the harness's
%% time for one wait is out, one step; each round waits on its prompt and
%% none on a time. A prompt is counted as the shell's `> `, which what the
%% inputs here print holds nowhere else.
fault_line(Input, Dir, Part) ->
    step({fault_line, Dir, Part}),
    fault_line(Input, Dir, Part, erlang:monotonic_time(millisecond) + ?WAIT_MS).

fault_line(Input, Dir, Part, Deadline) ->
    Prompts = length(string:split(written(Dir, out), "> ", all)) - 1,
    true = port_command(Input, "Unit\n"),
    Left = Deadline - erlang:monotonic_time(millisecond),
    waited(Dir, out, "> ", Prompts + 1, max(Left, 1)),
    case string:find(written(Dir, out), Part) of
        nomatch when Left > 0 -> fault_line(Input, Dir, Part, Deadline);
        nomatch -> erlang:error({not_said, Dir, Part});
        _ -> ok
    end.

%% What a running node's stream has written so far.
-spec written(file:filename(), out | err) -> string().
written(Dir, Stream) ->
    watcher_name(Dir) ! {written, Stream, self()},
    receive {written, Stream, Text} -> binary_to_list(Text) end.

%% What a node that has ended wrote, once both its streams have ended: one
%% step.
-spec said(file:filename()) -> {string(), string()}.
said(Dir) ->
    step({said, Dir}),
    both_ended(Dir).

both_ended(Dir) ->
    watcher_name(Dir) ! {said, self()},
    receive
        {said, Out, Err} -> {binary_to_list(Out), binary_to_list(Err)}
    after ?WAIT_MS ->
        erlang:error({still_writing, Dir})
    end.

%% The harness's time for one wait, which a test of the deployment guide's
%% waits by too, and test/fixtures/peers/harness.ern writes as a number.
-spec wait_ms() -> pos_integer().
wait_ms() ->
    ?WAIT_MS.

%% The detector's latest, which a test of the deployment guide's that
%% waits for it is given beside its step's own time.
-spec detector_ms() -> pos_integer().
detector_ms() ->
    ?DETECTOR_MS.

%% Whether Text holds Part.
-spec has(string(), string()) -> ok.
has(Text, Part) ->
    ?assertNotEqual(nomatch, string:find(Text, Part)).

%% A connection to what listens at Port of the loopback interface, in
%% binary and passive mode, with Options beside: one step.
-spec connected(inet:port_number(), [gen_tcp:connect_option()]) -> gen_tcp:socket().
connected(Port, Options) ->
    step({connected, Port}),
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port, [binary, {active, false} | Options],
                                   ?WAIT_MS),
    Socket.

%% A connection a listener of the test's takes: one step.
-spec accepted(gen_tcp:socket()) -> gen_tcp:socket().
accepted(Listener) ->
    step({accepted, Listener}),
    {ok, Socket} = gen_tcp:accept(Listener, ?WAIT_MS),
    Socket.

%% What comes next over a passive socket, Length bytes, or what has come
%% where Length is 0: one step.
-spec received(gen_tcp:socket(), non_neg_integer()) -> {ok, binary()} | {error, term()}.
received(Socket, Length) ->
    step({received, Socket}),
    gen_tcp:recv(Socket, Length, ?WAIT_MS).

%% docs/log.md, *The Harness Counts a Test's Steps*: a step past a test's
%% count fails the test at once, naming the step and the count, and a
%% failed test leaves no count behind in its process. A regression test,
%% written after the counter; it does not cover a step taken in another
%% process, which counts nothing.
steps_past_the_count_test() ->
    {timeout, _, {_, Counted}} = counted_test({waits, 1}, fun two_steps/0),
    ?assertError({steps_past_the_count, 1, second}, Counted()),
    ?assertEqual(undefined, get(?STEPS)).

two_steps() ->
    step(first),
    step(second).

%% docs/log.md, *The Harness Counts a Test's Steps*: a test that ends short
%% of its count fails, naming the steps it took and its count. A regression
%% test, written after the counter.
fewer_steps_than_counted_test() ->
    {timeout, _, {_, Counted}} = counted_test({waits, 2}, fun one_step/0),
    ?assertError({fewer_steps_than_counted, 1, 2}, Counted()),
    ?assertEqual(undefined, get(?STEPS)).

one_step() ->
    step(first).

%% report §12.5, §12.6: two nodes that list each other connect over TLS with a
%% certificate on each side, by the first operation that needs it, and each
%% says so naming the other; a node whose program ends tells the other,
%% which says it ended and not that it was lost; and the host's own reports
%% of its nodes are not written
connect_test_() ->
    nodes_test({waits, 7}, fun connect/1).

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

%% report §8.7, §12.5: a node accepts a peer whose public key its configuration
%% lists, and no other: the dialer is told nothing but that it could not
%% connect, and the node that refused says so, naming the key's digest
unlisted_test_() ->
    nodes_test({waits, 7}, fun unlisted/1).

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
    %% the dialer says only that it listens
    [Listening] = string:split(string:trim(ErrA, trailing, "\n"), "\n", all),
    has(Listening, "listening on 127.0.0.1:" ++ integer_to_list(PortA)),
    has(ErrB, "a node with the key " ++ digest(A) ++ " was refused: no peer has its key"),
    ?assertEqual(nomatch, string:find(ErrB, "TLS")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "no peer has its key", [{"b", digest(A)}]).

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
    nodes_test({waits, 12}, fun bound/1).

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
    ?assertMatch({0, _}, signaled("reload", A)),
    says(A, "the peer b was removed"),
    true = port_command(Own, "go\n"),
    {0, OwnOut} = Owned(),
    stop(A, WaitA),
    has(OwnOut, "connect: true"),
    has(OwnOut, "call: ran"),
    ?assertEqual(nomatch, string:find(OwnOut, "after: ran")),
    has(OwnOut, "after: "),
    {_, ErrA} = said(A),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "gives another name", []),
    ern_deployment_tests:cataloged(ErrA, "7", "certificate names another host", [{"b", "b"}]).

%% report §12.5: a node it dials must answer under the name it dialed: the
%% address a lists for the peer b is the port of c, another peer it lists,
%% which answers under its own name, and the dial fails, neither node
%% connected; a refuses c's key for the dial of b and says so
answered_test_() ->
    nodes_test({waits, 6}, fun answered/1).

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
    has(ErrA, "the peer c was refused: it answered the dial of the peer b"),
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
    nodes_test({waits, 5}, fun answered_by_another_key/1).

answered_by_another_key(Base) ->
    PortB = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", none),
    C = made(Base, "c", none),
    lists(A, [{"b", B, PortB}, {"c", C, none}]),
    Root = filename:join(Base, "build"),
    Program = program(Root),
    {Holder, Held} = answering(Root, name(B), key_files(C), ern_carrier:cookie(), PortB),
    WaitA = start(A, Program, ["utilization", "b"]),
    ?assertEqual(0, WaitA()),
    true = port_command(Holder, "go\n"),
    {0, _} = Held(),
    {OutA, ErrA} = said(A),
    has(OutA, "utilization: Left(Io.Unreachable)"),
    has(ErrA, "the peer c was refused: it answered the dial of the peer b"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "answered the dial", [{"c", "c"}, {"b", "b"}]),
    ?assertEqual(nomatch, string:find(ErrA, "connected")).

%% report §8.7, §12.6: a node that ends tells each connected peer so, and then its
%% connections close, telling none how busy it is after its word: a holder
%% of b's key, a bare `erl`, that says it ends and then tells a how busy it
%% is, its connection lasting, has not ended, and a says it was lost when
%% it closes, not that it ended. A regression test, written after the fix
%% (the release review before 0.4.0 found a peer's word that it ends kept
%% while its connection lasted); it does not cover a peer that says it
%% ends and stays connected telling nothing, whose word stands until its
%% connection's end
told_after_its_end_test_() ->
    nodes_test({waits, 6}, fun told_after_its_end/1).

told_after_its_end(Base) ->
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    Root = filename:join(Base, "build"),
    Program = program(Root),
    Source = filename:join(Root, "ern_nodes_ender.erl"),
    ok = file:write_file(Source, <<"
-module(ern_nodes_ender).
-export([main/0]).
main() ->
    {ok, [[Target]]} = init:get_argument(ern_nodes_target),
    Node = list_to_atom(Target),
    true = net_kernel:connect_node(Node),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), node_ends}),
    %% a telling, its utilization and interval any
    erlang:send({ern_gateway, Node}, {ern_frame, self(), {telling, 0.5, 5000}}),
    %% a call over the connection, whose answer comes once the frames before
    %% it have arrived, given the harness's time for one wait
    {ok, [[Ms]]} = init:get_argument(ern_nodes_ms),
    Node = erpc:call(Node, erlang, node, [], list_to_integer(Ms)),
    halt().
">>),
    {ok, _} = compile:file(Source, [{outdir, Root}]),
    WaitA = start(A, Program, []),
    prints(A, "waiting"),
    {_, Ender} = client(Root, name(B), key_files(B), ern_carrier:cookie(), PortA, name(A), [],
                        "ern_nodes_ender"),
    ?assertMatch({0, _}, Ender()),
    says(A, "the peer b was lost: it closed"),
    stop(A, WaitA),
    {_, ErrA} = said(A),
    has(ErrA, "the peer b connected"),
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
        ++ ["-epmd_module", "ern_nodes_client", "-start_epmd", "false", "-connect_all", "false",
            "-setcookie", Cookie, "-kernel", "inet_dist_listen_min", Digits,
            "-kernel", "inet_dist_listen_max", Digits, "-ern_nodes_port", Digits,
            "-s", "ern_nodes_answering", "main"],
    Holder = open_port({spawn_executable, os:find_executable("erl")},
                       [{args, Arguments}, exit_status, binary, stderr_to_stdout]),
    step({listening, Name}),
    listening(Holder, <<>>),
    {Holder, fun() -> collected(Holder, 1) end}.

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
%% the floor's digest and holding nothing of the build. A regression test
%% of MVP 3.0's fingerprint, which refused them
other_build_test_() ->
    nodes_test({waits, 7}, fun other_build/1).

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

%% report §12.5: a node that stands on another floor fails the handshake with
%% nothing sent, its cookie another's, and the node that refused it says so
%% in its own words; here a bare `erl` that holds a listed peer's key and
%% names itself as that key gives, with another cookie
other_floor_test_() ->
    nodes_test({waits, 6}, fun other_floor/1).

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
    ?assertEqual(nomatch, string:find(ErrA, "**")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "another floor", [{"b", "b"}]).

%% report §8.7, limit 14 of the proposal: two nodes started from copies of
%% one directory are one node to their peers; the second's dial ends the
%% first's connection, which the peer says each time. Its limit is the sum
%% of its eight steps, its program's build, a line of b's, of a's and of
%% b's again, three nodes' ends and what b said, each bounded by the
%% harness's time for one wait: written on 2026-10-16, after its limit of
%% 60 s, a number of its own, ran out under the full run's load on
%% 2026-10-13, its builds counted on 2026-10-21, and its host modules'
%% compiles, which are no step, left out on 2026-10-25
replaced_test_() ->
    nodes_test({waits, 8}, fun replaced/1).

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
    [ok = file:change_mode(filename:join(Copy, File), 8#644)
     || File <- ["ernest.conf", "certificate.pem"]],
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
    has(ErrB, "the peer a's connection was replaced by another from the same node"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "was replaced by another", [{"b", "a"}]).

%% report §12.5: a node says the address and the port it listens on, once
%% at every start: one whose `listen` names port 0 the port the host picks,
%% and one whose `listen` names a port that port, which a peer waits on
%% before it dials (the log's *The Review's Decisions*, written with the
%% line); a node without `listen` does not listen, says nothing of it, and
%% dials
listening_test_() ->
    nodes_test({waits, 10}, fun listening/1).

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
    says(B, "listening on 127.0.0.1:" ++ integer_to_list(PortB) ++ "\n"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(Z, "listening on "),
    says(B, "the peer a connected"),
    stop(B, WaitB),
    stop(Z, WaitZ),
    {OutA, ErrA} = said(A),
    {_, ErrB} = said(B),
    {_, ErrZ} = said(Z),
    has(OutA, "connect: true"),
    has(ErrB, "the peer a connected"),
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
    nodes_test({waits, 8}, fun faulty_frame/1).

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
    has(ErrA, "the peer b was lost: it closed"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrA, "7", "it closed", [{"b", "b"}]).

%% report §12.6: a spawn frame whose site is not UTF-8 is a frame the node
%% cannot read, though the node holds the function it names: the node ends
%% the connection, saying so, and the sender's node is told of the loss. A
%% regression test, written after the fix: the site was read only where the
%% node lacked the function, and a node that held it started the process
%% under the site as it came
unreadable_site_test_() ->
    nodes_test({waits, 7}, fun unreadable_site/1).

unreadable_site(Base) ->
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    {ok, Beam} = file:read_file(Program),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
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
    nodes_test({waits, 3}, fun missing_module/1).

missing_module(Base) ->
    Lone = made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    [ok = file:write_file(filename:join(Source, File), Text)
     || {File, Text} <- [{"main.ern", "export fn main() : Unit = Io.println(\"ran\")\n"},
                         {"user.ern", "export fn twice(n : Int) : Int = Extra.double(n)\n"},
                         {"extra.ern", "export fn double(n : Int) : Int = n * 2\n"}]],
    0 = built(["--build-root", Build, Source]),
    ok = file:delete(filename:join(Build, "extra.erc")),
    Main = filename:join(Build, "main.erc"),
    Run = fun(Words) -> finished([?ERN, " run ", Words, " 2>&1"]) end,
    ?assertEqual({0, "ran\n"}, Run(Main)),
    ?assertEqual({1, "ern run: cannot find module Extra (extra.erc), which User needs, on the"
                     " load path: a node reads every module of its load path\n"},
                 Run(["--config-dir ", Lone, " ", Main])),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §11.2, §8.7: a file at a module's path that holds another module
%% is refused before anything runs, and a node, which reads every module of
%% its load path, names the file and the module it holds, not the module
%% missing at the path of the one it holds; the same program run as no
%% node does not read the file, and runs. A regression test, written after
%% the fix (the release review before 0.4.0 found the node saying the
%% module the file holds was not on the load path)
misplaced_module_test_() ->
    nodes_test({waits, 3}, fun misplaced_module/1).

misplaced_module(Base) ->
    Lone = made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    Build = filename:join(Base, "build"),
    ok = filelib:ensure_path(Source),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join(Source, "extra.ern"),
                         "export fn double(n : Int) : Int = n * 2\n"),
    0 = built(["--build-root", Build, Source]),
    Moved = filename:join(Build, "moved.erc"),
    ok = file:rename(filename:join(Build, "extra.erc"), Moved),
    Main = filename:join(Build, "main.erc"),
    Run = fun(Words) -> finished([?ERN, " run ", Words, " 2>&1"]) end,
    ?assertEqual({0, "ran\n"}, Run(Main)),
    Refusal = "ern run: " ++ ern_build:shown(Moved) ++ " holds Extra, not Moved; remove it, and"
        " build Moved from its source root\n",
    ?assertEqual({1, Refusal}, Run(["--config-dir ", Lone, " ", Main])),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §11.2, §11.1, §8.7: a node, which reads every module of its load
%% path, refuses a `.erc` whose path from its root breaks §11.1's shape by
%% the component that breaks it, before anything runs: a directory that is
%% not lowercase, which would otherwise read as the namespace the file
%% holds, and one that is no words joined by `_`. A regression test,
%% written after the fix (the full review before 0.5.0 found the first
%% refused as a module missing at its own path and the second as a file
%% holding another module); it does not cover a file's own name, which
%% the program's own load refuses the same way.
misshapen_load_path_test_() ->
    nodes_test({waits, 3}, fun misshapen_load_path/1).

misshapen_load_path(Base) ->
    Lone = made(Base, "lone", none),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(filename:join(Source, "net")),
    ok = file:write_file(filename:join(Source, "main.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join([Source, "net", "http.ern"]),
                         "export fn double(n : Int) : Int = n * 2\n"),
    Build = filename:join(Base, "build"),
    0 = built(["--build-root", Build, Source]),
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
                        " `ordered_set.ern`\n"},
                 Run("dashed")),
    ?assertNot(filelib:is_regular(filename:join(Lone, "ernest.pid"))).

%% report §8.7, §11.2, §11.3: a node started by `ern test` with a relative
%% `--config-dir` reads its configuration from that directory as it was
%% named from where the job started, so that `ern reload --config-dir`
%% from there, sent while a doc example runs in a directory of its own, is
%% read and not refused. The example waits on a line of standard input,
%% which the test writes once the reload has been said. A regression test,
%% written after the fix (the full review before 0.5.0 found the node
%% reading the example's directory); it does not cover a test's case,
%% which runs where the job started.
reload_in_example_test_() ->
    nodes_test({waits, 6}, fun reload_in_example/1).

reload_in_example(Base) ->
    Node = made(Base, "node", none),
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
    0 = built(["--build-root", filename:join(Base, "build"), Source]),
    {Input, Wait} = launched(Node, ["cd ", Base, " && ", ?ERN,
                                    " test --config-dir node build/slow.erc"]),
    prints(Node, "waiting"),
    ?assertEqual({0, ""}, finished(["cd ", Base, " && ", ?ERN, " reload --config-dir node 2>&1"])),
    says(Node, "ernest.conf was read again"),
    true = port_command(Input, "go\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = said(Node),
    has(Out, "Slow.typed example 1: passed"),
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
    nodes_test({waits, 14}, fun limits/1).

limits(Base) ->
    Node = made(Base, "node", none),
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
    0 = built(["--build-root", filename:join(Base, "build"), Source]),
    Program = filename:join([Base, "build", "limits.erc"]),
    Limits = fun(Given) -> edit(Node, fun(Conf) -> Conf#{<<"limits">> => Given} end) end,
    Limits(#{<<"processes">> => 50000, <<"ports">> => 4097}),
    {Input, Wait} = started(Node, Program, []),
    true = port_command(Input, "limits\n"),
    prints(Node, "#(65536, 8192)\n"),
    Limits(#{<<"processes">> => 2000, <<"ports">> => 2000}),
    ?assertMatch({0, _}, signaled("reload", Node)),
    says(Node, "ernest.conf was read again"),
    says(Node, "the change to limits holds from the node's next start"),
    true = port_command(Input, "limits\nend\n"),
    prints(Node, "#(65536, 8192)\n", 2, ?WAIT_MS),
    ?assertEqual(0, Wait()),
    {_, Err} = said(Node),
    ?assertEqual(nomatch, string:find(Err, "refused")),
    {Again, WaitAgain} = started(Node, Program, []),
    true = port_command(Again, "limits\nend\n"),
    prints(Node, "#(2048, 2048)\n"),
    ?assertEqual(0, WaitAgain()),
    edit(Node, fun(Conf) -> maps:remove(<<"limits">>, Conf) end),
    {0, Own} = finished("env -u ERL_AFLAGS -u ERL_FLAGS -u ERL_ZFLAGS erl -noshell -eval"
                        " 'io:format(\"#(~B, ~B)~n\", [erlang:system_info(process_limit),"
                        " erlang:system_info(port_limit)]), halt().'"),
    {Unlimited, WaitUnlimited} = started(Node, Program, []),
    true = port_command(Unlimited, "limits\nend\n"),
    prints(Node, Own),
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
    nodes_test({waits, 4}, fun full_port_table/1).

full_port_table(Base) ->
    Node = made(Base, "node", none),
    edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"ports">> => 1024}} end),
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
    let command = Os.Command(program = \"true\", arguments = [], input = <<>>);
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
">>, wait_ms_declaration()]),
    0 = built(["--build-root", filename:join(Base, "build"), Source]),
    Wait = start(Node, filename:join([Base, "build", "full.erc"]), []),
    prints(Node, "after a close: Right(0)\n"),
    ?assertEqual(0, Wait()),
    {Out, _} = said(Node),
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
    nodes_test({waits, 3}, fun full_port_table_input/1).

full_port_table_input(Base) ->
    Node = made(Base, "node", none),
    edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"ports">> => 1024}} end),
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
    0 = built(["--build-root", filename:join(Base, "build"), Source]),
    {Input, Wait} = started(Node, filename:join([Base, "build", "input.erc"]), []),
    true = port_command(Input, "first\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = said(Node),
    ?assertEqual(["reader: Fault(\"error:system_limit\")", "read: Some(\"first\")", ""],
                 string:split(Out, "\n", all)),
    has(Err, "Input.main:22 faulted: error:system_limit").

%% report §7.4, §12.5, §7.3: at a full table of processes, which a node's
%% `limits` makes small, every spawn the runtime makes for a request
%% answers its asker with `Fault("error:system_limit")`, the process that
%% took the request living on: the reaper's spawn, the per-request
%% processes of `Fs`, `Tcp` and `Os`, and the clock's delivery of an
%% alarm, whose recipient faults at its wait. A probe takes each step at
%% the full table, asking the entry process for it, and faults, and
%% `restarting` runs it again in the same process, so that the table stays
%% full; each kind is asked twice, the process that took it answering
%% again. Report §10: a `kill` needs no room, so a kill at the full table
%% makes room, and once the killed process has ended, which a call on it
%% shows, a spawn takes its place.
%%
%% Report §8.6, §11.2: a program that fills its table and faults ends with
%% its fault reported, its end telling its subscriber of `Os.termination`
%% by a delivery that cannot be made, so that the subscriber faults and is
%% waited for no longer. Report §12.1: the host's own report of each spawn
%% refused is not written, the fault's line saying it.
%%
%% A regression test, written after the fix: the reaper and the system
%% processes died of the host's `system_limit`, and the node hung; and a
%% kill faulted where the table was full. It does
%% not cover a listener's accept, whose worker is made as a connect's is, a
%% process kept for an adapted address, which needs a peer, the terminal's
%% subscription, or a deadlock at a full table, which a node does not look
%% for
full_process_table_test_() ->
    nodes_test({waits, 4}, fun full_process_table/1).

full_process_table(Base) ->
    Node = made(Base, "node", none),
    edit(Node, fun(Conf) -> Conf#{<<"limits">> => #{<<"processes">> => 1024}} end),
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
      | 4 -> Io.println(Io.show(Os.start(Os.Command(program = \"true\", arguments = [],
                                                    input = <<>>))))
      | 5 -> {
            let _ = Clock.alarm(0, fn(time) = time);
            receive { time -> Io.println(Int.toString(time)) }
        }
      | _ -> {
            kill(held);
            Io.println(\"after the kill: \" <> Io.show(Address.call(held, Hold, waitMs())));
            let _ = spawn(fn() = waited());
            Io.println(\"spawned\")
        }
    }
">>, wait_ms_declaration()]),
    ok = file:write_file(filename:join(Source, "ending.ern"), <<"
// The subscriber of the program's end, which answers once told.
fn subscribed() : Unit receiving Reply(Unit) = {
    Os.termination(fn(reply) = reply);
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
    0 = built(["--build-root", filename:join(Base, "build"), Source]),
    ?assertEqual(0, (start(Node, filename:join([Base, "build", "full.erc"]), []))()),
    {Out, Err} = said(Node),
    ?assertEqual(["step " ++ integer_to_list(Step) || Step <- lists:seq(0, 12)]
                 ++ ["after the kill: None", "spawned", ""],
                 string:split(Out, "\n", all)),
    Faults = [Line || Line <- string:split(Err, "\n", all),
                      string:find(Line, "faulted") =/= nomatch],
    ?assertEqual(lists:duplicate(12, "Full.main:19 faulted, restarted: error:system_limit"),
                 [string:find(Line, "Full.") || Line <- Faults]),
    ?assertEqual(nomatch, string:find(Err, "Too many processes")),
    ?assertEqual({1, ["Ending.main faulted: error:system_limit",
                      "the end waits for 1 subscriber: Ending.main:19",
                      "Ending.main:19 faulted: error:system_limit",
                      "the subscriber Ending.main:19 ended without answering"]},
                 lines_said(finished([?ERN, " run --config-dir ", Node, " ",
                                      filename:join([Base, "build", "ending.erc"]), " 2>&1"]))).

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
    nodes_test({waits, 8}, fun ipv6/1).

%% Each node listens on a port the host picks, `b`'s read once it listens,
%% and `b` lists `a`, which dials it, without an address.
ipv6(Base) ->
    A = made(Base, "a", none),
    B = made(Base, "b", none),
    edit(B, fun(Conf) ->
                Conf#{<<"listen">> => ipv6_loopback(0), <<"peers">> => [peer("a", A, none)]}
            end),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    PortB = bound_port(B),
    edit(A, fun(Conf) ->
                Conf#{<<"listen">> => ipv6_loopback(0),
                      <<"peers">> => [(peer("b", B, none))#{<<"network-address">> =>
                                                                 ipv6_loopback(PortB)}]}
            end),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "the peer a connected"),
    stop(B, WaitB),
    {OutA, _} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: true"),
    has(ErrB, "the peer a connected").

%% report §12.5, Appendix E.18: a node's listener on `::` takes connections
%% of IPv6's family alone, so a listener on `0.0.0.0` stands beside it on
%% its port and is the one an IPv4 connection to the port reaches. A
%% regression test: the node on `::` took IPv4 connections too, and beside
%% a listener on `0.0.0.0` its carrier did not start, its listen address
%% in use. It does not cover an interface other than the loopback's
ipv6_beside_ipv4_test_() ->
    nodes_test({waits, 7}, fun ipv6_beside_ipv4/1).

ipv6_beside_ipv4(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {0, 0, 0, 0}}, {active, false}]),
    {ok, PortB} = inet:port(Held),
    A = made(Base, "a", none),
    B = made(Base, "b", none),
    %% `a` listens on a port the host picks, and `b` lists it, as the node
    %% that dials, without an address
    edit(A, fun(Conf) ->
                Conf#{<<"listen">> => ipv6_loopback(0),
                      <<"peers">> => [(peer("b", B, none))#{<<"network-address">> =>
                                                                 ipv6_loopback(PortB)}]}
            end),
    edit(B, fun(Conf) ->
                Conf#{<<"listen">> => list_to_binary("[::]:" ++ integer_to_list(PortB)),
                      <<"peers">> => [peer("a", A, none)]}
            end),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    prints(B, "waiting"),
    WaitA = start(A, Program, ["connect", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "the peer a connected"),
    step(ipv4_accepted),
    {ok, Client} = gen_tcp:connect({127, 0, 0, 1}, PortB, [{active, false}], ?WAIT_MS),
    Accepted = gen_tcp:accept(Held, ?WAIT_MS),
    ok = gen_tcp:close(Client),
    ok = gen_tcp:close(Held),
    stop(B, WaitB),
    ?assertMatch({ok, _}, Accepted),
    {OutA, _} = said(A),
    has(OutA, "connect: true").

%% Report Appendix C: the `listen` or the `network-address` of a node at
%% Port of IPv6's loopback.
ipv6_loopback(Port) ->
    list_to_binary("[::1]:" ++ integer_to_list(Port)).

%% report §8.6, §12.5, Appendix E.23: a node whose program ends by `Os.exit`
%% exits with its status, and its ernest.pid, there while it runs, is gone
os_exit_test_() ->
    nodes_test({waits, 3}, fun os_exit/1).

os_exit(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    %% the list given the harness's time for one wait, the step it is of
    ok = file:write_file(filename:join(Root, "exits.ern"),
                         ["export fn main() : Unit = {\n"
                          "    let listed = Fs.list(Path(\"", A, "\"), ", wait_ms_text(), ");\n"
                          "    Io.println(Io.show(Either.map(listed,\n"
                          "                                  fn(entries) = List.size(entries))));\n"
                          "    Os.exit(3)\n"
                          "}\n"]),
    0 = built([Root]),
    ?assertEqual(3, (start(A, filename:join(Root, "exits.erc"), []))()),
    {Out, _} = said(A),
    has(Out, "Right(4)"),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §12.5, §11.2: a node whose `ernest.conf` is refused is refused with
%% the file and the rule, as the launcher's second start says it, the first
%% having given the host no flags: peers that are no array, and a
%% `utilization` that names neither measure. A regression test: the refusal
%% said the host had not been started as a node; the utilization's was
%% written after the code
refused_configuration_test_() ->
    nodes_test({waits, 3}, fun refused_configuration/1).

refused_configuration(Base) ->
    A = made(Base, "a", none),
    edit(A, fun(Conf) -> Conf#{<<"peers">> => #{}} end),
    Program = program(filename:join(Base, "build")),
    Run = ?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1",
    {1, Said} = finished(Run),
    has(Said, "ern run: " ++ filename:join(A, "ernest.conf") ++ ": peers is not a JSON array"),
    edit(A, fun(Conf) -> Conf#{<<"peers">> => [], <<"utilization">> => <<"cpu">>} end),
    {1, Measured} = finished(Run),
    has(Measured, "ern run: " ++ filename:join(A, "ernest.conf") ++ ": utilization is \"cpu\","
                  " which is neither \"run-queue\" nor \"schedulers\"").

%% report §12.5, §11.2: a node refused once its start has begun, by a module
%% on its load path the program never uses whose dependency the path lacks,
%% removes the ernest.pid it wrote, as it does however it ends. A
%% regression test: the file was left naming the process that had ended
refused_after_start_test_() ->
    nodes_test({waits, 2}, fun refused_after_start/1).

refused_after_start(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    ok = file:write_file(filename:join(Root, "uses.ern"), "export fn f() : Int = Used.g()\n"),
    ok = file:write_file(filename:join(Root, "used.ern"), "export fn g() : Int = 1\n"),
    0 = built([Root]),
    ok = file:delete(filename:join(Root, "used.erc")),
    {1, Said} = finished(?ERN ++ " run --config-dir " ++ A ++ " " ++ filename:join(Root, "prog.erc")
                         ++ " 2>&1"),
    has(Said, "Used"),
    ?assertEqual(nomatch, string:find(Said, "ran")),
    ?assertNot(filelib:is_file(filename:join(A, "ernest.pid"))).

%% report §12.5, §11.8, §8.7: a node whose carrier cannot start, its port
%% taken, ends before `main` runs as a job that cannot start, with status 1
%% and the line §12.5 states, which names the listen address in use, `ern
%% run:` for a program's node and `ern shell:` for a shell's own, with no
%% fault's line and nothing of the host's reports on its standard output. A
%% regression test of the principles review (the log's *The Principles
%% Review of 2026-10-09*), which stated the cause in §7.4: the fault was
%% reported under the last initializer's site, `Terminal.widths`, and the
%% host's crash report of its distribution was written on standard output;
%% and of the release review's K26 (the log's *The Shell's Own Node*): the
%% node's end was its entry process's fault, a shell's status 70
carrier_not_started_test_() ->
    nodes_test({waits, 3}, fun carrier_not_started/1).

carrier_not_started(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    A = made(Base, "a", Port),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "export fn main() : Unit = Io.println(\"ran\")\n"),
    0 = built([Root]),
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
%% as any program ends, so the subscriber of `Os.termination` its
%% initializers started is told, and the end waits for its answer, which
%% the runtime says, before the job's line. A regression test, written
%% after the report named the end in §8.6 (the log's *The Release Review
%% Before 0.7.0*, *The round*): the code already told it
carrier_not_started_tells_test_() ->
    nodes_test({waits, 2}, fun carrier_not_started_tells/1).

carrier_not_started_tells(Base) ->
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    A = made(Base, "a", Port),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "prog.ern"),
                         "type Msg = Ending(Reply(Unit)) | Ready(Reply(Unit))\n\n"
                         "fn told() : Unit receiving Msg = {\n"
                         "    Os.termination(Ending);\n"
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
    0 = built([Root]),
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
    nodes_test({waits, 6}, fun no_deadlock/1).

no_deadlock(Base) ->
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "waits.ern"),
                         "export fn main() : Unit receiving Int = {\n"
                         "    Io.println(\"waiting\");\n"
                         "    receive { n -> Unit }\n"
                         "}\n"),
    0 = built([Root]),
    Program = filename:join(Root, "waits.erc"),
    {Micros, {1, Plain}} = timer:tc(fun() -> finished(?ERN ++ " run " ++ Program ++ " 2>&1") end),
    has(Plain, "deadlock"),
    {Port, Wait} = started(A, Program, []),
    prints(A, "waiting"),
    %% an absence: no end within three times what the plain run took to
    %% find its deadlock
    ?assertEqual(timeout, ended(Port, 3 * Micros div 1000)),
    {ok, Pid} = file:read_file(filename:join(A, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(143, Wait()),
    {_, Err} = said(A),
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
    0 = built(["--build-root", Root, "fixtures/peers"]),
    {ok, _} = compile:file("fixtures/peers/ern_peers_host.erl", [{outdir, Root}]),
    {filename:join(Root, "store.erc"), filename:join(Root, "desk.erc")}.

%% test/fixtures/peers/harness.ern: the programs of test/fixtures/peers/ give
%% each wait the harness's time for one wait, and wait by the dial's and
%% the detector's times the report states, which the module writes as
%% numbers of its own. The two later times, written after the programs
%% wrote them in place, are a regression test; and report §8.7: the dial's
%% time the carrier gives the host, which the shell asks it, is the
%% report's (ern_carrier:dial_ms/0), a regression test of the one place
%% the toolchain states it, the release review before 0.7.0 (C13)
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
              <<"doomed">>, <<"adapter">>, <<"watcher">>, <<"gated">>, <<"opener">>,
              <<"herald">>, <<"herald-watcher">>],
    edit(Desk, fun(Conf) ->
                   Conf#{<<"services">> => maps:merge(
                                              maps:from_list([{Name, [<<"store">>]}
                                                              || Name <- Stored]),
                                              #{<<"counter">> => [<<"gone">>, <<"store">>],
                                                <<"lost">> => [<<"gone">>]})}
               end),
    edit(Third, fun(Conf) ->
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
    nodes_test({waits, 7}, fun find/1).

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
    nodes_test({waits, 8}, fun handover/1).

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
            kill(first);
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
"/utf8>>, wait_ms_declaration()]),
    0 = built([Root]),
    PortServer = free_port(),
    Server = made(Base, "server", PortServer),
    Client = made(Base, "client", none),
    lists(Server, [{"client", Client, none}]),
    lists(Client, [{"server", Server, PortServer}]),
    edit(Client, fun(Conf) -> Conf#{<<"services">> => #{<<"handover">> => [<<"server">>]}} end),
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
    nodes_test({waits, 8}, fun reply_crosses/1).

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
    nodes_test({waits, 8}, fun peer_fault/1).

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
    ?assertEqual(nomatch, string:find(ErrB, "Squares.spawning:46 faulted: division by zero,")),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "7", "spawned by the peer",
                                   [{"Counter.serve:14", "Squares.main:20"}, {"a", "a"}]).

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
"/utf8>>, wait_ms_declaration()]),
    0 = built([Root]),
    PortB = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, none}]),
    {filename:join(Root, "squares.erc"), A, B}.

%% report §8.7, §6.7, Appendix E.27, §8.2: work on a peer is a process
%% spawned at the node the program names, whose spawn answers its address or
%% a failure within the time. A function the store holds spawns there with
%% what it captured, writing to the store's standard output; a name that is
%% no peer's is NotListed. A function that names a binding with no value on
%% the store is NotLoaded, which the store says, and nothing is initialized
%% for it; a function that names no binding spawns though its module's
%% binding has no value there, MVP 3.1 having lifted the rule by module.
%%
%% A top-level binding in spawned code is the peer's. A monitored spawn is
%% monitored from its start. A spawn given no time answers Timeout. A find
%% and a spawn given a time past the longest wait the host takes at once
%% wait, a regression: each failed with the host's error
spawn_test_() ->
    nodes_test({waits, 7}, fun spawn_on_peer/1).

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
     || Line <- ["spawn: Right", "not listed: Io.NotListed", "not loaded: Io.NotLoaded",
                 "names no binding: Right", "bindings: Right", "monitored: Returned",
                 "late: Io.Timeout", "no upper bound: Right"]],
    Spawned = desk_site("spawns", "spawn(\"store\", Lonely.speak"),
    has(StoreErr, "the peer desk's spawn at " ++ Spawned ++ " was not loaded: the binding"
                  " Lonely.greeting has no value here"),
    has(StoreOut, "the store squares 49"),
    has(StoreOut, "the store squares 64"),
    has(StoreOut, "the peers here: [\"desk\", \"third\"]"),
    ?assertEqual(nomatch, string:find(StoreOut, "never initialized")).

%% report §8.7, §6.7, Appendix E.27, §11.2, E.21: work on a peer is a
%% function run there for its value, answered within the time or a failure.
%% A value comes back; a name that is no peer's answers NotListed; a
%% function whose binding has no value on the store answers NotLoaded,
%% which the store says. A fault in the function is the caller's, with the
%% function's cause, which the caller's node reports once, with the
%% caller's site and `, on the peer store` after the cause, its subscriber
%% of faults told of it with the peer, the trace that crossed with it
%% beneath, then the caller's frame, a cause of §7.4's as a raise's (§7.3,
%% a regression test of 2026-10-20), and the store reports nothing, its
%% subscriber told nothing.
%%
%% A process killed before it answers answers Other with its Reason. A
%% process whose caller ends while it waits, one whose function kills its
%% caller from the store, a kill the desk carries out as its own, which
%% reads the caller's call and sends its second note (§6.9), and one whose
%% time runs out, are killed on the store, whose watcher, monitoring each,
%% says so; and a process that ends with the store's program answers Other
%% with ProgramEnd. A regression test, written after the code, the kill
%% from the store's after the kill frame's (MVP 3.29); it reads no row of
%% either node's, which ern_rt_tests and ern_peer_tests read; it does not
%% cover a second note that comes before the compute's process could start,
%% which the store's gateway reads first, nor a loss while the caller
%% waits, which reconnect_test_'s is
compute_test_() ->
    nodes_test({waits, 10}, fun compute_on_peer/1).

compute_on_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    WaitDesk = start(Desk, DeskProgram, ["compute"]),
    prints(Store, "the abandoned compute's process ended: Killed"),
    prints(Store, "the killing compute's process ended: Killed"),
    prints(Store, "the timed-out compute's process ended: Killed"),
    prints(Desk, "now stop the store"),
    stop(Store, WaitStore),
    ?assertEqual(0, WaitDesk()),
    {Out, Err} = said(Desk),
    {StoreOut, StoreErr} = said(Store),
    Faulted = desk_site("faulted", "spawnMonitored(f, Died)"),
    RaisedCause = " foreign function erlang:binary_to_integer/1 raised error:badarg",
    Raised = RaisedCause ++ ", on the peer store",
    [has(Out, Line)
     || Line <- ["value: Right(42)", "not listed: Left(Io.NotListed)",
                 "not loaded: Left(Io.NotLoaded)",
                 "divided: Fault(\"division by zero\")",
                 "reported here: " ++ Faulted ++ " division by zero Some(\"store\") true",
                 "raised: Fault(\"foreign function erlang:binary_to_integer/1 raised"
                 " error:badarg\")",
                 "reported here: " ++ Faulted ++ RaisedCause ++ " Some(\"store\") true",
                 "killed: Left(Io.Other(\"Killed\"))", "its caller killed from the store: Killed",
                 "timed out: Left(Io.Timeout)",
                 "with the store's end: Left(Io.Other(\"ProgramEnd\"))"]],
    Divided = Faulted ++ " faulted: division by zero, on the peer store\n",
    ?assertEqual(1, length(string:split(Err, Divided, all)) - 1),
    %% the function's frame on the store, then the caller's, which stand at
    %% one line here
    Division = desk_site("computes", "fn() = 1 / List.size([])"),
    has(Err, Divided ++ "    erlang:'div'/2\n    " ++ Division ++ "\n    " ++ Division ++ "\n"),
    has(Err, Faulted ++ " faulted:" ++ Raised ++ "\n    erlang:binary_to_integer/1\n"),
    Computed = desk_site("computes", "computeAt(\"store\", Lonely.speak"),
    has(StoreErr, "the peer desk's compute at " ++ Computed ++ " was not loaded: the binding"
                  " Lonely.greeting has no value here"),
    [?assertEqual(nomatch, string:find(Text, Part))
     || {Text, Part} <- [{StoreErr, "division by zero"}, {StoreErr, "badarg"},
                         {StoreOut, "the store's subscriber: division by zero"},
                         {StoreOut, "the store's subscriber: foreign function"}]].

%% report §8.7, §12.5, §12.8, Appendix E.27, Appendix C: how busy a peer is, on one
%% scale. A name that is no peer's answers NotListed. The store's
%% schedulers' time, as its configuration names it at its start, answers a
%% fraction from 0.0 to 1.0 at each ask, the host keeping the schedulers'
%% time there from the start. A reload that leaves the entry out, the run
%% queue by default, holds from the next ask, which answers 0.0 or more,
%% the host keeping the time no longer. A file that names neither measure
%% is refused with the file and the rule, by `ern reload` before it signals
%% and by the node at a hangup `kill -HUP` sends, the run queue measuring
%% still.
%%
%% A regression test, written after the code; that the run queue's measure
%% is the run queue over the schedulers, and not the schedulers' time, is
%% read from the code, since an idle node answers 0.0 or more under both
utilization_test_() ->
    nodes_test({waits, 14}, fun utilization_of_peer/1).

utilization_of_peer(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    edit(Store, fun(Conf) -> Conf#{<<"utilization">> => <<"schedulers">>} end),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["utilization"]),
    prints(Store, "the store keeps the schedulers' time at the start: true"),
    prints(Desk, "now measure the run queue"),
    edit(Store, fun(Conf) -> maps:remove(<<"utilization">>, Conf) end),
    ?assertMatch({0, _}, signaled("reload", Store)),
    says(Store, "ernest.conf was read again"),
    true = port_command(DeskPort, "go\n"),
    prints(Store, "the store keeps the schedulers' time after the reload: false"),
    prints(Desk, "now refuse a reload"),
    edit(Store, fun(Conf) -> Conf#{<<"utilization">> => <<"cpu">>} end),
    ?assertEqual({1, refused_reload(Store, "utilization is \"cpu\", which is neither"
                                           " \"run-queue\" nor \"schedulers\"")},
                 signaled("reload", Store)),
    hungup(Store),
    says(Store, "the reload was refused"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {_, StoreErr} = said(Store),
    [has(Out, Line) || Line <- ["not listed: Left(Io.NotListed)", "schedulers: #(true, true)",
                                "run queue: true", "after the refusal: true"]],
    has(StoreErr, "the reload was refused, and the configuration stays as it was: "),
    has(StoreErr, "ernest.conf: utilization is \"cpu\", which is neither \"run-queue\" nor"
                  " \"schedulers\"").

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
%% address its earlier start made. The silent port is a regression test
%% too, written on 2026-10-16: the closed port refused the dial at once, so
%% a send that waited behind the dial passed unseen, and the send's bound
%% was a chosen 1000 ms, which failed under load. Not covered: a value
%% crossing in pieces with other senders' messages between them, a send
%% that waits at a full buffer, and a silence, which the detector finds in
%% a minute
across_test_() ->
    nodes_test({waits, 12, ?DIAL_MS}, fun across/1).

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
    prints(Desk, "now silence the store's port"),
    {_, Silent} = nothing_answered(listened(Store)),
    true = port_command(DeskPort, "go\n"),
    %% the desk's monitor of the counter gives its Down once the host has
    %% given up the dial the silent port takes (report §8.7)
    prints(Desk, "now restart the store", ?WAIT_MS + ?DIAL_MS),
    stop_holding(Silent),
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
                 "severed service: Unreachable \"\"",
                 "after the loss: 15", "killed: Unreachable \"\"", "send at once: true",
                 "out of reach: Unreachable \"\"", "old call: None true",
                 "old monitor: Unknown \"\"", "same process: false", "fresh total: 0",
                 "old adapted: 2"]],
    {ok, FirstErr} = file:read_file(Store ++ ".first.err"),
    has(binary_to_list(FirstErr), "the peer desk sent a frame this node cannot read"),
    has(ThirdOut, "sent through the third node"),
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
    nodes_test({waits, 5}, fun calls/1).

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

%% report §6.9, §8.7: a restart of a process of another node is told to a
%% service monitor here: the store's herald, which a watcher on the desk
%% service-monitors and faults once, tells the watcher Restarted, its site
%% empty, before anything its new run sends; and a restart that a service
%% monitor's wrap on the desk holds up, waiting on a gate that never
%% answers, is held until the desk ends the connection by a frame the
%% store's gateway cannot read, the loss ending the store's wait, so that
%% the new run answers the desk's call after the loss.
%%
%% The test's limit is the sum of its six waits, each bounded by the
%% harness's time for one wait: the build, the store's offer, the desk's
%% run, the store's end, and what each printed. A regression test, written
%% after the code, of the decision's program, on which 0.5.0 told the
%% watcher nothing and its next message was taken by the new run (the log's
%% *A Restart Told Across Nodes*). It does not cover a restart of a process
%% that another node only monitors or calls, answered at once, which no
%% program can tell from a restart that tells no node, nor a telling whose
%% watch dials a connection lost since the host listed the monitor, which
%% no test can place there
restart_told_test_() ->
    nodes_test({waits, 6}, fun restart_told/1).

restart_told(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["restart"]))()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {_, StoreErr} = said(Store),
    [has(Out, Line)
     || Line <- ["the first run: a run began", "first after the crash: told Restarted \"\"",
                 "then: a run began", "the watcher: Returned", "the wrap holds the restart",
                 "severed: Unreachable \"\"", "after the loss: Some(Unit)"]],
    has(StoreErr, "faulted, restarted: crashed").

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
    nodes_test({waits, 10}, fun reconnect/1).

reconnect(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["reconnect"]),
    prints(Desk, "now open the connection again"),
    says(Desk, "the peer store was lost: it closed"),
    says(Store, "the peer desk was lost: it closed"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    prints(Store, "the store squares 36"),
    stop(Store, WaitStore),
    {Out, DeskErr} = said(Desk),
    {_, StoreErr} = said(Store),
    [has(Out, Line)
     || Line <- ["the call: None true", "the compute: Left(Io.Unreachable)",
                 "its caller: Returned", "its computer: Returned",
                 "the same process: Some(3)", "computed after: Right(42)",
                 "spawned after: Right", "found after: Right", "measured after: true"]],
    has(StoreErr, "the peer desk sent a frame this node cannot read, and its connection was"
                  " ended"),
    [?assertEqual(2, length(string:split(Err, Line, all)) - 1)
     || {Err, Line} <- [{DeskErr, "the peer store connected"},
                        {StoreErr, "the peer desk connected"}]].

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
    nodes_test({waits, 5}, fun adapted_calls/1).

adapted_calls(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["gated"]))()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    [has(Out, Line)
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
    nodes_test({waits, 8}, fun stop_in_order/1).

stop_in_order(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["ending"]),
    prints(Desk, "watching"),
    ?assertMatch({0, _}, signaled("stop", Store)),
    ?assertEqual(143, WaitStore()),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    {Out, _} = said(Desk),
    has(Out, "ended: ProgramEnd \"\""),
    has(Out, "after: Unreachable \"\""),
    ?assertNot(filelib:is_file(filename:join(Store, "ernest.pid"))),
    {Status, Said} = signaled("stop", Store),
    ?assertEqual(1, Status),
    has(Said, "ernest.pid: no such file: no node runs from the directory").

%% report §12.5, §11.2: a node holds ernest.pid locked for its life, which
%% the host ends with it however it ends: a node killed leaves the file, and
%% the next start from the directory takes it, saying nothing of a refusal,
%% the file holding the new node's number; a running node refuses a second
%% start, naming its number; and where the file names a living process that
%% is no node, `ern stop` and `ern reload` fail, saying that no node holds
%% it, and the process is sent nothing. A regression test, written after the
%% code (the log's *MVP 3.1 Read*): a start was refused by a file whose
%% number a living process held, and the jobs signaled that process
pid_lock_test_() ->
    nodes_test({waits, 10}, fun pid_lock/1).

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
    {1, Again} = finished(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1"),
    has(Again, " is the configuration directory of the running node "
               ++ string:trim(binary_to_list(Number)) ++ ", which ernest.pid names"),
    stop(A, WaitA),
    {_, Err} = said(A),
    ?assertEqual(nomatch, string:find(Err, "configuration directory")),
    %% a living process that is no node, which reads its input and echoes it
    Living = open_port({spawn_executable, os:find_executable("cat")}, [binary]),
    {os_pid, LivingNumber} = erlang:port_info(Living, os_pid),
    ok = file:write_file(PidFile, integer_to_list(LivingNumber) ++ "\n"),
    [begin
         {Status, Said} = signaled(Job, A),
         ?assertEqual(1, Status),
         has(Said, "ernest.pid: no node holds it: no node runs from the directory")
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
    nodes_test({waits, 12}, fun stop_waits/1).

stop_waits(Base) ->
    A = made(Base, "a", none),
    PidFile = filename:join(A, "ernest.pid"),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "stopping.ern"), <<"
// Report §8.6: a subscriber of the end that answers once a line comes.

type Msg = Terminating(Reply(Unit))

export fn main() : Unit receiving Msg = {
    Os.termination(Terminating);
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
    0 = built([Root]),
    Program = filename:join(Root, "stopping.erc"),
    %% a stop begun, and what waits for what it said once it has returned
    Stopping = fun() -> begun(?ERN ++ " stop --config-dir " ++ A ++ " 2>&1") end,
    {Port, Wait} = started(A, Program, []),
    prints(A, "subscribed"),
    Stopped = Stopping(),
    prints(A, "told"),
    ?assert(filelib:is_file(PidFile)),
    true = port_command(Port, "go\n"),
    ?assertMatch({0, _}, Stopped()),
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, Wait()),
    {_, Err} = said(A),
    has(Err, "the subscriber Stopping.main answered"),
    %% the next start, and two stops
    {_Port, WaitAgain} = started(A, Program, []),
    prints(A, "subscribed"),
    First = Stopping(),
    prints(A, "told"),
    Second = Stopping(),
    [?assertMatch({0, _}, Stop()) || Stop <- [First, Second]],
    ?assertNot(filelib:is_file(PidFile)),
    ?assertEqual(143, WaitAgain()),
    {_, ErrAgain} = said(A),
    has(ErrAgain, "the end was cut short, 1 subscriber unanswered: Stopping.main").

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
    nodes_test({waits, 20}, fun reload/1).

reload(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    Third = filename:join(Base, "third"),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["reload"]),
    prints(Desk, "watching"),
    lists(Store, [{"third", Third, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    says(Store, "the peer desk was removed"),
    prints(Desk, "now list the desk again"),
    lists(Store, [{"third", Third, none}, {"front", Desk, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    says(Store, "the peer front was added"),
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now rename the desk"),
    lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    ?assertMatch({0, _}, signaled("reload", Store)),
    says(Store, "the peer front is now named window"),
    true = port_command(DeskPort, "go\n"),
    prints(Desk, "now refuse a reload"),
    edit(Store, fun(#{<<"peers">> := Peers} = Conf) ->
                    Broken = #{<<"name">> => <<"broken">>,
                               <<"public-key">> => undecodable(public(Desk))},
                    Conf#{<<"peers">> := Peers ++ [Broken]}
                end),
    ?assertEqual({1, refused_reload(Store, "peer \"broken\"'s public-key is not one public key"
                                           " in PEM")},
                 signaled("reload", Store)),
    hungup(Store),
    says(Store, "is not one public key in PEM"),
    lists(Store, [{"third", Third, none}, {"window", Desk, none}]),
    edit(Store, fun(Conf) -> Conf#{<<"listen">> => address(free_port())} end),
    ?assertMatch({0, _}, signaled("reload", Store)),
    says(Store, "the reload was refused"),
    true = port_command(DeskPort, "go\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {StoreOut, Err} = said(Store),
    [has(Out, Line)
     || Line <- ["removed: Unreachable \"\"", "unlisted: Left(Io.Unreachable)",
                 "listed again: true",
                 "renamed: Some(0)", "refused: Some(0)"]],
    [?assertMatch({match, _}, re:run(Err, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z " ++ Line ++ "$",
                                     [multiline]))
     || Line <- ["ernest.conf was read again", "the peer desk was removed",
                 "the peer front was added", "the peer front is now named window"]],
    has(Err, "the reload was refused, and the configuration stays as it was: "),
    has(Err, "peer \"broken\"'s public-key is not one public key in PEM"),
    has(Err, "listen cannot change while the node runs"),
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

%%
%% Two builds (report §8.7, MVP 3.1)
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
                         {"asker.ern", [Asker, wait_ms_declaration()]}]],
    0 = built([Dir]),
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
%% it and running the asker's body (MVP 3.2's item 4).
%%
%% A function that names a binding the server's program never ran answers
%% NotLoaded, and so does one whose reach calls a host module the server
%% lacks, the server saying which. A function that names no binding of a
%% module whose binding the server never ran spawns, MVP 3.0's rule by
%% module gone. A lambda and a local fn spawn by identity with what they
%% captured, and `restarting(limit, f)` spawns. Written with the code,
%% after it: a regression test
two_builds_test_() ->
    nodes_test({waits, 8}, fun two_builds/1).

two_builds(Base) ->
    {AskerProgram, _} = twins(filename:join(Base, "first"), false),
    {_, ServerProgram} = twins(filename:join(Base, "second"), true),
    PortServer = free_port(),
    Asker = made(Base, "asker", none),
    Server = made(Base, "server", PortServer),
    lists(Asker, [{"server", Server, PortServer}]),
    lists(Server, [{"asker", Asker, none}]),
    edit(Asker, fun(Conf) ->
                    Conf#{<<"services">> => #{<<"stable">> => [<<"server">>],
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
     || Line <- ["stable: Some(42)", "shape: Io.OtherType", "same: Right",
                 "changed: Right",
                 "binding: Io.NotLoaded", "module: Io.NotLoaded", "names no binding: Right",
                 "lambda: Right", "local: Right", "restarting: Right"]],
    [has(ServerOut, Line)
     || Line <- ["same ran", "quiet ran", "lambda ran 42", "local ran 43", "restarting ran",
                 "the first build"]],
    ?assertEqual(nomatch, string:find(ServerOut, "the second build")),
    ?assertEqual(nomatch, string:find(ServerOut, "never run on the server")),
    ?assertEqual(nomatch, string:find(ServerErr, "Asker.spawned:25")),
    [has(ServerErr, Line)
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
             "            let counted = Peer.computeAt(receiver, Lacked.counted, waitMs());\n"
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
             "    let collected = Peer.computeAt(receiver, Lacked.collected, waitMs());\n"
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
    [0 = built([Dir]) || Dir <- [SenderDir, ReceiverDir]],
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
%% as the sender's module writes it, `Count` and not `Lacked.Count`, while
%% one whose module the receiver lacks, or whose function its module lacks,
%% is NotLoaded. A function whose reach names a binding the receiver never
%% ran, or a foreign declaration whose module it lacks, answers NotLoaded
%% from the reach, before any code crosses, the receiver saying what it
%% lacked. A call whose reply a function captured whose spawn failed is
%% answered by the spawner, which keeps its copy, with the failure,
%% NotLoaded or NotListed alike. A regression test, written after the code;
%% that no code frame moves before NotLoaded is ern_exchange_tests', since
%% no line marks it here.
%%
%% Each spawn, compute and call of the sender waits as long as the test
%% waits for the sender, and the test's limit is the sum of its eighteen
%% steps, the two builds, a line of the receiver's, the sender's end, ten
%% lines and one more of the receiver's, its end and what each node said,
%% each bounded by the harness's time for one wait: written on 2026-10-16,
%% after a spawn's 5000 ms, a number of its own, ran out under the full
%% run's load on 2026-10-13 and its answer's line was missing, its builds
%% counted on 2026-10-21, and its host module's compile, which is no step,
%% left out on 2026-10-25
exchange_test_() ->
    nodes_test({waits, 18}, fun exchange/1).

exchange(Base) ->
    {SenderProgram, ReceiverProgram} = exchanged(Base),
    PortReceiver = free_port(),
    Sender = made(Base, "sender", none),
    Receiver = made(Base, "receiver", PortReceiver),
    lists(Sender, [{"receiver", Receiver, PortReceiver}]),
    lists(Receiver, [{"sender", Sender, none}]),
    WaitReceiver = start(Receiver, ReceiverProgram, []),
    prints(Receiver, "ready"),
    ?assertEqual(0, (start(Sender, SenderProgram, ["receiver", integer_to_list(?WAIT_MS)]))()),
    Served = "the peer sender's spawn at Sender.serve:50 was not loaded: the binding Lacked.note"
             " has no value here",
    Lines = ["the peer sender's spawn at Sender.main:13 was not loaded: the binding Lacked.note"
             " has no value here",
             "the peer sender's spawn at Sender.main:15 was not loaded: the module"
             " ern_sender_host, which Lacked.only calls, is not here",
             Served,
             "Sender.received:26 faulted: foreign function erlang:binary_to_integer/1 raised"
             " error:badarg, spawned by the peer sender",
             "\n    Lacked.raises:19\n",
             "Lacked.spawner:22 faulted: the child",
             "Sender.received:29 faulted: the return of foreign function erlang:yield/0 does not"
             " match Unit, spawned by the peer sender",
             "the peer sender's spawn at Sender.received:33 was not loaded: the module"
             " ern_sender_host, which Lacked.only calls, is not here",
             "Sender.received:35 faulted: the return of foreign function erlang:yield/0 does not"
             " match Count, spawned by the peer sender",
             "the peer sender's spawn at Sender.received:36 was not loaded: the module lists,"
             " which Lacked.absent calls, has no function ern_absent_function/0 here"],
    [says(Receiver, Line) || Line <- Lines],
    prints(Receiver, "child at Lacked.spawner:22"),
    stop(Receiver, WaitReceiver),
    {Out, _} = said(Sender),
    {ReceiverOut, ReceiverErr} = said(Receiver),
    [has(Out, Line)
     || Line <- ["plain: Right", "counted: Right(Lacked.Count(2))",
                 "told: Io.NotLoaded", "calls only: Io.NotLoaded",
                 "server receiver: Io.NotLoaded", "server nobody: Io.NotListed",
                 "call receiver: Some(Left(Io.NotLoaded))", "call nobody: Some(Left(Io.NotListed))",
                 "raises: Right", "spawner: Right", "yielded: Right", "collected: Right(true)",
                 "only by name: Io.NotLoaded", "counts: Right", "absent function: Io.NotLoaded"]],
    has(ReceiverOut, "Count(1)"),
    ?assertEqual(1, length(string:split(ReceiverErr, Served, all)) - 1),
    ?assertEqual(nomatch, string:find(ReceiverErr, "Lacked.spawner:22 faulted: the child,")),
    ?assertEqual(nomatch, string:find(ReceiverErr, "Lacked.Count")),
    ?assertEqual(nomatch, string:find(Out, "never run on the receiver")),
    %% the lines as the deployment guide quotes them, in its catalog and
    %% beside a spawn's
    Peer = {"a", "sender"},
    ern_deployment_tests:cataloged(ReceiverErr, "7", "has no value here",
                                   [Peer, {"Site", "Sender.main:13"}, {"Q", "Lacked.note"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "7", "is not here",
                                   [Peer, {"Site", "Sender.main:15"}, {"M", "ern_sender_host"},
                                    {"Q", "Lacked.only"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "4.3", "has no value here",
                                   [Peer, {"Counter.main:13", "Sender.main:13"},
                                    {"Counter.config", "Lacked.note"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "4.3", "is not here",
                                   [Peer, {"Counter.main:15", "Sender.main:15"},
                                    {"counter_host", "ern_sender_host"},
                                    {"Counter.tick", "Lacked.only"}]),
    ern_deployment_tests:cataloged(ReceiverErr, "4.3", "has no function",
                                   [{"tick/0", "ern_absent_function/0"}]).

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
             "    Io.println(\"compute: \" <> Io.show(Peer.computeAt(bare, answer, waitMs())));\n"
             "    Io.println(\"entry shown: \" <> Io.show(Peer.computeAt(bare, entryShown,"
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
             "    Io.println(\"picked: \" <> Io.show(Peer.compute(answer, waitMs())));\n"
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
                              {ProgramDir, "bare.ern", [Source, wait_ms_declaration()]}]],
    0 = built([SharedDir]),
    0 = built(["--load-path", SharedDir, ProgramDir]),
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
%% sender's, with the peer that spawned it. A function that crossed with
%% the first lambda's enclosing definition is spawned twice and faults
%% twice, the traces of both its faults naming its frame by its name and
%% the sender's line (Appendix E.21), which since 2026-10-20 names no unit,
%% so that it shipped nothing at its own spawns is ern_exchange_tests'
%% alone.
%%
%% The entry process is among its live processes, under the site `bare
%% node`; `ern stop` ends it by termination, with nothing said of its entry
%% process and its ernest.pid gone; and started again, a process spawned
%% there that calls `Os.exit(3)` ends it with status 3. The lambdas are
%% written in the definition that spawns everything else, whose references
%% cross with them, a function that calls a foreign function among them.
%% Written after the code
bare_node_test_() ->
    nodes_test({waits, 20}, fun bare_node/1).

bare_node(Base) ->
    {SharedDir, Program, Source} = bare_build(Base),
    A = made(Base, "a", none),
    B = made(Base, "b", 0),
    lists(B, [{"a", A, none}]),
    %% how often the bare node tells its utilization, which the program
    %% waits one of before its pick: the scenario's, and no bound
    Interval = 200,
    edit(B, fun(Conf) -> Conf#{<<"utilization-interval">> => Interval} end),
    edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"b">>]}} end),
    WaitB = bare_started(B, [SharedDir]),
    lists(A, [{"b", B, bound_port(B)}]),
    Placing = [?ERN, " run --config-dir ", A, " --load-path ", SharedDir, " ", Program, " b"],
    {_, WaitA} = launched(A, [Placing, " ", integer_to_list(Interval)]),
    ?assertEqual(0, WaitA()),
    Site = fun(Part) -> "Bare.placed:" ++ integer_to_list(line_of(Source, Part)) end,
    Raised = " faulted: foreign function erlang:binary_to_integer/1 raised error:badarg, spawned"
             " by the peer a\n",
    [says(B, Line)
     || Line <- ["the peer a's spawn at " ++ Site("Shared.greet") ++ " was not loaded: the"
                 " binding Shared.greeting has no value here",
                 Site("\"divides: \"") ++ " faulted: division by zero, spawned by the peer a\n",
                 Site("\"raises: \"") ++ Raised, Site("\"raises again: \"") ++ Raised]],
    [prints(B, Line) || Line <- ["counted 1", "counted 7", "bye"]],
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = said(A),
    {OutB, ErrB} = said(B),
    [has(Out, Line)
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
    WaitExit = bare_started(B, [SharedDir]),
    lists(A, [{"b", B, bound_port(B)}]),
    {_, WaitExiting} = launched(A, [Placing, " exit"]),
    ?assertEqual(0, WaitExiting()),
    ?assertEqual(3, WaitExit()),
    {OutExiting, _} = said(A),
    {_, ErrExit} = said(B),
    has(OutExiting, "exit: Right"),
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
    nodes_test({waits, 7}, fun constant_crosses/1).

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
            "    let added = Peer.computeAt(\"b\", fn() = limit + 1, waitMs());\n"
            "    Io.println(\"limit: \" <> Io.show(added));\n"
            "    let summed = Peer.computeAt(\"b\", fn() = origin.x + origin.y, waitMs());\n"
            "    Io.println(\"origin: \" <> Io.show(summed));\n"
            "    Io.println(\"tags: \" <> Io.show(Peer.computeAt(\"b\", fn() = tags, waitMs())));\n"
            "    let read = Peer.computeAt(\"b\", fn() = computed, waitMs());\n"
            "    Io.println(\"computed: \" <> Io.show(read))\n"
            "}\n",
            wait_ms_declaration()]),
    0 = built([ProgramDir]),
    A = made(Base, "a", none),
    B = made(Base, "b", 0),
    lists(B, [{"a", A, none}]),
    WaitB = bare_started(B, []),
    lists(A, [{"b", B, bound_port(B)}]),
    {_, WaitA} = launched(A, [?ERN, " run --config-dir ", A, " ",
                              filename:join(ProgramDir, "main.erc")]),
    ?assertEqual(0, WaitA()),
    says(B, "the binding Main.computed has no value here"),
    ?assertMatch({0, _}, signaled("stop", B)),
    ?assertEqual(143, WaitB()),
    {Out, _} = said(A),
    [has(Out, Line) || Line <- ["limit: Right(11)", "origin: Right(3)",
                                "tags: Right([#(\"a\", 1), #(\"b\", -2)])",
                                "computed: Left(Io.NotLoaded)"]].

%% report §11.2 *The attached shell*, §12.7, §8.7: an attach to a node
%% that holds the shell's units and could not load them, a bare node whose
%% `HOME` is not UTF-8, so that `Ernest.Shell.History.directory` faults as
%% their bindings are evaluated, is refused with status 1 and the node's
%% reason as the node answers it, `Other(r)`, which the node says too. A
%% regression test, written after the code: the node answered `NotLoaded`,
%% and the shell said that the node ran another build of `ern`. It does
%% not cover a load the host refuses, whose reason crosses the same way
attach_unloadable_shell_test_() ->
    nodes_test({waits, 6}, fun attach_unloadable_shell/1).

attach_unloadable_shell(Base) ->
    Node = made(Base, "node", 0),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, ["HOME=\"$(printf '\\377')\" ", ?ERN, " run --config-dir ",
                                    Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {_, WaitShell} = launched(Ops, ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                                    " --attach node"]),
    ?assertEqual(1, WaitShell()),
    {_, Err} = said(Ops),
    Loading = "ern shell: the node node could not load the shell: ",
    [Reason] = [string:slice(Found, length(Loading))
                || Line <- string:split(Err, "\n", all), Found <- [string:find(Line, Loading)],
                   Found =/= nomatch],
    has(Reason, "Ernest.Shell.History.directory:"),
    has(Reason, " faulted: the environment variable HOME is not UTF-8"),
    ern_deployment_tests:cataloged(Err, "6", "could not load the shell", [{"b", "node"}]),
    ?assertEqual(nomatch, string:find(Err, "another build")),
    says(Node, "the peer ops's spawn at Ernest.Shell.localHalf:"),
    has(written(Node, err), "was not loaded: " ++ Reason),
    ?assertMatch({0, _}, signaled("stop", Node)),
    ?assertEqual(143, WaitNode()).

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
    nodes_test({waits, 7}, fun attach_beside_a_program_shell/1).

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
    0 = built([Root]),
    PortNode = free_port(),
    Node = made(Base, "node", PortNode),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, PortNode}]),
    WaitNode = start(Node, filename:join(Root, "shell.erc"), []),
    prints(Node, "ready"),
    {Input, WaitShell} = attached(Ops, "node", Source),
    prints(Ops, ". :help for help."),
    entered(Input, Ops, ["Shell.greeting"], "\"the program's own Shell\" : String"),
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    stop(Node, WaitNode),
    {_, Err} = said(Ops),
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
%% with its activity.
%%
%% `:quit` ends the shell with status 0 and leaves that process running on
%% the node, which a second session lists. Written after the code, a
%% regression test of the attach; the tests after it hold the rest of an
%% attached session, written with MVP 4.0's item 5.
attached_shell_test_() ->
    nodes_test({waits, 17}, fun attached_shell/1).

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
    0 = built([Root]),
    PortNode = free_port(),
    Node = made(Base, "node", PortNode),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, PortNode}]),
    {NodeInput, WaitNode} = started(Node, filename:join(Root, "echo.erc"), []),
    prints(Node, "ready"),
    {ShellInput, WaitShell} = attached(Ops, "node", Source),
    prints(Ops, ". :help for help."),
    true = port_command(ShellInput, "Io.println(\"written at the prompt\")\n"),
    prints(Ops, "written at the prompt"),
    true = port_command(NodeInput, "go\n"),
    prints(Node, "the node's own: go"),
    true = port_command(ShellInput, ":detach\n"),
    prints(Ops, "no command :detach; :help lists them"),
    true = port_command(ShellInput, ":load Greet\nGreet.hello()\n"),
    prints(Ops, "hello from the operator"),
    true = port_command(ShellInput, ["let p = Process.current()\n", "let q = p\n",
                                     "Optional.isSome(Process.status(q))\n"]),
    prints(Ops, "true : Bool"),
    true = port_command(ShellInput, [":forget p\n",
                                     "{ monitor(q, fn(down) = down); receive { _ -> Unit } }\n",
                                     "Optional.isSome(Process.status(q))\n"]),
    prints(Ops, "false : Bool"),
    true = port_command(ShellInput, ["let w : Address(Int) = spawn(fn() = receive { _ -> Unit })\n",
                                     ":processes\n"]),
    prints(Ops, "$Session1.input 11:1 receiving"),
    prints(Ops, "Echo.main "),
    true = port_command(ShellInput, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    {Out, _} = said(Ops),
    has(Out, "Greet, compiled from " ++ ern_build:shown(filename:join(Source, "greet.ern"))),
    ?assertEqual(nomatch, string:find(Out, "the node's own")),
    ?assertEqual(nomatch, string:find(Out, "Ernest.Shell.")),
    %% report §11.2: what the session started stays the node's
    {SecondInput, WaitSecond} = attached(Ops, "node", Source),
    true = port_command(SecondInput, ":processes\n:quit\n"),
    prints(Ops, "$Session1.input 11:1 receiving"),
    ?assertEqual(0, WaitSecond()),
    stop(Node, WaitNode),
    {NodeOut, _} = said(Node),
    has(NodeOut, "the node's own: go"),
    ?assertEqual(nomatch, string:find(NodeOut, "written at the prompt")).

%% report §11.2 *The attached shell*, §11.8: where the node an attached
%% session runs on ends, the shell says `the node node ended` and exits
%% with status 0, and where it is lost, `the node node is lost` and status
%% 1; in line mode the prompt the screen last wrote is ended first, so that
%% the line stands on a row of its own, as a detach leaves it. Standard
%% error holds that line alone: the shell's own node says nothing of its
%% session's node's end or loss. Written before the fixes (the plan's MVP
%% 4.0 items 8 and 10), which the line sharing the prompt's row failed, and
%% the shell's own node's `the peer node ended` before it, in one run of
%% sixteen. Each line is held to the deployment guide's section 6, which
%% quotes it, since MVP 4.0's item 5.
attached_shell_ends_test_() ->
    nodes_test({waits, 10}, fun attached_shell_ends/1).

attached_shell_ends(Base) ->
    Ops = made(Base, "ops", none),
    [Ended, Lost] =
        lists:map(
          fun({Name, End, Status, Line}) ->
              Node = made(Base, Name, 0),
              lists(Node, [{"ops", Ops, none}]),
              {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
              lists(Ops, [{"node", Node, bound_port(Node)}]),
              {_, WaitShell} = attached(Ops, "node", Base),
              prints(Ops, ":help for help.\n> "),
              End(Node, WaitNode),
              ?assertEqual(Status, WaitShell()),
              {Out, Err} = said(Ops),
              ?assertMatch({true, _}, {lists:suffix(":help for help.\n> \n", Out), Out}),
              ?assertEqual(Line, Err),
              Err
          end, [{"ended", fun stop/2, 0, "the node node ended\n"},
                {"lost", fun lost/2, 1, "the node node is lost\n"}]),
    %% the lines as the deployment guide's section 6 quotes them
    ern_deployment_tests:cataloged(Ended, "6", "ended", [{"b", "node"}]),
    ern_deployment_tests:cataloged(Lost, "6", "is lost", [{"b", "node"}]).

%% report §11.2 *The attached shell*, Appendix E.27: the shell's own node
%% tells no peer how busy it is, so at the prompt of the node it attaches
%% to, which lists no other peer, `Peer.utilizations()` holds no row for it
%% and a compute that names no node answers `Left(Unreachable)` and runs on
%% it never; a compute that names it runs there, answering the shell's own
%% node's peers. Written before the fix (the plan's MVP 4.0 item 9), which
%% the row for `ops` and the compute that ran on it failed.
attached_utilization_test_() ->
    nodes_test({waits, 6}, fun attached_utilization/1).

attached_utilization(Base) ->
    Ops = made(Base, "ops", none),
    Node = made(Base, "node", 0),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    {Shell, WaitShell} = attached(Ops, "node", Base),
    prints(Ops, ":help for help.\n> "),
    Ms = wait_ms_text(),
    true = port_command(Shell, ["Peer.computeAt(\"ops\", fn() = Peer.peers(), ", Ms, ")\n"]),
    prints(Ops, "Right([\"node\"]) : Either(Io.Error, List(String))\n"),
    true = port_command(Shell, ["Peer.utilizations()\n",
                                "Peer.compute(fn() = Peer.peers(), ", Ms, ")\n", ":quit\n"]),
    ?assertEqual(0, WaitShell()),
    {Out, _} = said(Ops),
    has(Out, "> [] : List(#(String, Float, Int))\n"),
    has(Out, "> Left(Io.Unreachable) : Either(Io.Error, List(String))\n"),
    stop(Node, WaitNode).

%% report §11.2 *The attached shell*, §11.8, §8.6, §12.5: a shell whose
%% node is lost ends with `the node node is lost` and status 1 within a
%% dial's time of the loss, though a dial of that node would wait the
%% whole of it: the shell's own node reads its configuration again with
%% the node's address moved to a port that takes a connection and never
%% answers, and the node is then ended outright. The end's drain asks
%% nothing of the screen, which went with the session, so that the host
%% dials no lost node to reach it. Written before the fix, the release
%% review before 0.7.0 (C5), the shell ending a dial late.
attached_lost_unanswered_test_() ->
    nodes_test({waits, 7, ?DIAL_MS}, fun attached_lost_unanswered/1).

attached_lost_unanswered(Base) ->
    Ops = made(Base, "ops", none),
    Node = made(Base, "node", 0),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    {_, WaitShell} = attached(Ops, "node", Base),
    prints(Ops, ":help for help.\n> "),
    {ok, Hole} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, HolePort} = inet:port(Hole),
    lists(Ops, [{"node", Node, HolePort}]),
    ?assertEqual({0, ""}, finished([?ERN, " reload --config-dir ", Ops, " 2>&1"])),
    prints(Ops, "ernest.conf was read again"),
    Began = erlang:monotonic_time(millisecond),
    lost(Node, WaitNode),
    ?assertEqual(1, WaitShell()),
    Taken = erlang:monotonic_time(millisecond) - Began,
    ok = gen_tcp:close(Hole),
    ?assert(Taken < ern_carrier:dial_ms()),
    {_, Err} = said(Ops),
    has(Err, "the node node is lost\n").

%% report §11.2 *The attached shell*, *Editing*, §11.8: the same at a
%% terminal, through the pseudo-terminal's harness: the region is taken
%% away where the screen last painted it, what was typed after the prompt
%% with it, and the line stands on a row of its own under the prompt. The
%% node's program ends its node once the test opens a named pipe it reads,
%% by returning, or, told `lost`, by ending its own host outright, so that
%% the end comes while the shell waits at its prompt. No row holds the
%% shell's own node's line of its peer's end or loss, which the shell's
%% line says. Written before the fixes (the plan's MVP 4.0 items 8 and 10),
%% the second red in eight runs of eight with `the peer node ended` on a
%% row of the screen.
attached_terminal_ends_test_() ->
    nodes_test({waits, 13}, fun attached_terminal_ends/1).

attached_terminal_ends(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "ender.ern"), ender()),
    0 = built([Root]),
    Ops = made(Base, "ops", none),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    lists:foreach(
      fun({Name, NodeStatus, Status, Line}) ->
          Port = free_port(),
          Node = made(Base, Name, Port),
          Pipe = filename:join(Base, Name ++ ".pipe"),
          [] = os:cmd("mkfifo " ++ Pipe),
          lists(Node, [{"ops", Ops, none}]),
          lists(Ops, [{"node", Node, Port}]),
          {_, WaitNode} = started(Node, filename:join(Root, "ender.erc"),
                                  [Pipe, Name, filename:join(Node, "ernest.pid")]),
          prints(Node, "ready"),
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
    "            let _ = Os.run(Os.Command(program = \"cat\", arguments = [pipe], input = <<>>),\n"
    "                           waitMs());\n"
    "            if how == \"lost\" then {\n"
    "                let kill = \"kill -KILL $(cat \" <> pidFile <> \")\";\n"
    "                let _ = Os.run(Os.Command(program = \"sh\", arguments = [\"-c\", kill],\n"
    "                                          input = <<>>),\n"
    "                               waitMs());\n"
    "                Unit\n"
    "            } else\n"
    "                Unit\n"
    "        }\n"
    "      | _ -> Unit\n"
    "    }\n",
     wait_ms_declaration()].

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
%% each line as the deployment guide's section 6 quotes it. Written after
%% the code, a regression test of the refusal, the dial that waits with the
%% release review's K27 (the log's *The Shell's Own Node*), whose answer
%% was a race between the two
attach_refused_test_() ->
    nodes_test({waits, 6, ?DIAL_MS}, fun attach_refused/1).

attach_refused(Base) ->
    [Absent, Unanswering, Ops] = [made(Base, Name, none) || Name <- ["absent", "hole", "ops"]],
    {ok, Hole} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, HolePort} = inet:port(Hole),
    lists(Ops, [{"absent", Absent, free_port()}, {"hole", Unanswering, HolePort}]),
    Refused = fun(Name) ->
                  {_, Wait} = attached(Ops, Name, Base),
                  ?assertEqual(1, Wait()),
                  {Out, Err} = said(Ops),
                  ?assertEqual("", Out),
                  Err
              end,
    ern_deployment_tests:cataloged(Refused("absent"), "6", "is unreachable", [{"b", "absent"}]),
    Began = erlang:monotonic_time(millisecond),
    ern_deployment_tests:cataloged(Refused("hole"), "6", "is unreachable", [{"b", "hole"}]),
    ?assert(erlang:monotonic_time(millisecond) - Began < 2 * ern_carrier:dial_ms()),
    ok = gen_tcp:close(Hole),
    ern_deployment_tests:cataloged(Refused("nowhere"), "6", "is not listed", [{"b", "nowhere"}]).

%% report §11.2 *The attached shell*, §11.8, §12.6: an attach to a node
%% that takes the connection and answers nothing over it is refused once
%% twice a dial's time has passed, saying that the peer did not answer in
%% time,
%% with status 1, its standard output in line mode the shell's own node's
%% line of the connection alone (§11.2 *The shell*), the line as the
%% deployment guide's section 6 quotes it. The node's program
%% suspends its gateway, the process that answers a peer's frames, a
%% spawn's among them, so that the connection stands and the spawn waits.
%% Written after the code, a regression test: MVP 4.0's item 5
attach_unanswered_test_() ->
    nodes_test({waits, 5, 2 * ?DIAL_MS}, fun attach_unanswered/1).

attach_unanswered(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "stall.ern"), stall()),
    0 = built([Root]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = started(Node, filename:join(Root, "stall.erc"), []),
    prints(Node, "suspended: true"),
    {_, Wait} = attached(Ops, "node", Base),
    ?assertEqual(1, Wait()),
    {Out, Err} = said(Ops),
    ?assertEqual("the peer node connected\n", unstamped(Out)),
    ern_deployment_tests:cataloged(Err, "6", "did not answer in time", [{"b", "node"}]),
    stop(Node, WaitNode).

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

%% report §11.2 *The attached shell*, §11.8, §12.5, §12.6, §12.7: a shell
%% of another build of `ern` than its node's, on the node's floor, is
%% refused, saying that the node runs another build, with status 1, the
%% line as the deployment guide's section 6 quotes it, its standard output
%% the line of the connection alone, as an attach unanswered leaves it; and
%% the node says that the spawn was not loaded, its tree holding none of
%% the toolchain's own definition the spawn's frame names, which it asks
%% the shell's own node nothing of.
%%
%% The builds are releases made from this tree under Base, so that each
%% stands on the floor of the release VERSION names: the second's shell
%% compiled from the shell's source with one binding's form changed,
%% `fileMs`, its value not, and the third's with one function's form
%% changed and no binding's, `isAttaching`'s clauses in the other order, so
%% that the local half, whose reach names both, hashes otherwise and the
%% node's own tree lacks it (the design note on code's *The toolchain's
%% own units*). A shell of the node's own build attaches and leaves between
%% the two, so that the refusal is the shell's units and not the floor, and
%% so that the node's own shell units have run before the third's attach,
%% which an exchange of its code would then have let run.
%%
%% Written after the code, a regression test: MVP 4.0's item 5, and the
%% third build with the release review's F3 (the log's *The Shell's Own
%% Node*), refused only where the reach named a binding without a value
attach_other_build_test_() ->
    nodes_test({waits, 12}, fun attach_other_build/1).

attach_other_build(Base) ->
    Own = released(filename:join(Base, "one"), ern_tree:build("shell")),
    Other = changed_release(filename:join(Base, "two"), <<"\nlet fileMs = 5000\n">>,
                            <<"\nlet fileMs = 5000 + 0\n">>),
    Third = changed_release(filename:join(Base, "three"),
                            <<"        Attaching(_) -> true\n      | Beside(_) -> false\n">>,
                            <<"        Beside(_) -> false\n      | Attaching(_) -> true\n">>),
    Node = made(Base, "node", 0),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, [Own, " run --config-dir ", Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = fun(Ern) -> launched(Ops, ["HOME=", Home, " ", Ern, " shell --config-dir ", Ops,
                                       " --attach node"])
            end,
    Refused = fun(Ern) ->
                  {_, Wait} = Shell(Ern),
                  ?assertEqual(1, Wait()),
                  {RefusedOut, RefusedErr} = said(Ops),
                  ?assertEqual("the peer node connected\n", unstamped(RefusedOut)),
                  ern_deployment_tests:cataloged(RefusedErr, "6", "another build",
                                                 [{"b", "node"}])
              end,
    Refused(Other),
    says(Node, "the peer ops's spawn at Ernest.Shell.localHalf:"),
    NotLoaded = " was not loaded: the toolchain's own definition it names, which this node's"
        " tree holds none of, another build of ern than the spawner's\n",
    has(written(Node, err), NotLoaded),
    {Input, Attached} = Shell(Own),
    true = port_command(Input, ":quit\n"),
    ?assertEqual(0, Attached()),
    {Out, Err} = said(Ops),
    has(Out, ". :help for help.\n"),
    ?assertEqual(nomatch, string:find(Err, "ern shell:")),
    Refused(Third),
    seen(Node, err, NotLoaded, 2, ?WAIT_MS),
    stop(Node, WaitNode).

%% A release of `ern` made in Dir as released/2 makes one, and its
%% launcher, whose shell is compiled from the shell's source with Old
%% replaced by New in `ernest/shell.ern`: the source copied into the
%% release's own tree and built there by the release's `ern`, since a
%% module of `Ernest` is built in the shell's own source root alone (report
%% §4.2), the tree's of the `ern` that builds it. The build is one of the
%% test's steps.
changed_release(Dir, Old, New) ->
    Ern = released(Dir, ern_tree:build("shell")),
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

%% Report §12.5, §12.7: a release of `ern` made in Dir from this tree, and
%% its launcher: the tree's code, the runtime's helper, the standard
%% library and the libraries copied as they stand, the shell's build from
%% Shell, and `ern_release` compiled again with an empty mark in place of
%% `-dev`, as the release archive compiles it at the release's tag
%% (tools/install.sh), so that its version text is VERSION's alone and it
%% stands on a release's floor.
released(Dir, Shell) ->
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
    {ok, Version} = file:read_file(filename:join(Tree, "VERSION")),
    {ok, ern_release} = compile:file(filename:join(Tree, "src/toolchain/cli/ern_release"),
                                     [{d, 'VERSION', string:trim(binary_to_list(Version))},
                                      {d, 'MARK', ""},
                                      {outdir, filename:join(Dir, "build/toolchain/cli/ebin")},
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
%% a regression test: MVP 4.0's item 5; the sites, the start line, the
%% reload said and the evaluators' end a regression test of the release
%% review's P1, P5 and N2 (the log's *Sites, Sessions and Their Names*)
attached_sessions_test_() ->
    nodes_test({waits, 22}, fun attached_sessions/1).

attached_sessions(Base) ->
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    Greet = filename:join(Source, "greet.ern"),
    ok = file:write_file(Greet, greet("first", "")),
    Node = made(Base, "node", 0),
    [One, Two] = [made(Base, Name, none) || Name <- ["one", "two"]],
    lists(Node, [{"one", One, none}, {"two", Two, none}]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    Port = bound_port(Node),
    [lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    Offered = "> Right(Unit) : Either(Process, Unit)\n",
    Waiting = ": Address(Ping) = spawn(fn() = receive { _ -> Unit })",
    {First, _} = Attached = sessioned(Base, One),
    prints(One, "Ernest " ++ ern_release:version_text() ++ ", session 1. :help for help.\n"),
    entered(First, One, ["fn f() : Int = 1", "type Ping = Ping(Int)", "let p" ++ Waiting,
                         "Peer.offer(Peer.service(\"ping\"), p)", "f()"], "> 1 : Int\n"),
    has(written(One, out), Offered),
    {Second, WaitSecond} = sessioned(Base, Two),
    prints(Two, ", session 2. :help"),
    entered(Second, Two, ["fn f() : Int = 2", "type Ping = Ping(Int)", "let q" ++ Waiting,
                          "Peer.offer(Peer.service(\"ping\"), q)", "let r" ++ Waiting,
                          "Either.isRight(Peer.offer(Peer.service(\"ping\"), r))", "f()"],
            "> 2 : Int\n"),
    has(written(Two, out), Offered ++ "> r : Address(Ping)\n> false : Bool\n"),
    %% report §11.2: a load and a reload are the node's
    entered(First, One, [":load Greet", "let n = Greet.Bye"], "> n : Greet.Msg\n"),
    has(written(One, out), "> Greet, compiled from src/greet.ern\n"),
    entered(Second, Two, ["Greet.hello()", "let m = Greet.Hello"], "> m : Greet.Msg\n"),
    has(written(Two, out), "> \"hello, first\" : String\n"),
    ok = file:write_file(Greet, greet("second", " | Again")),
    entered(First, One, [":reload"],
            "Greet.Msg changed: the binding n is of its previous version, Greet$1.Msg\n"),
    has(written(One, out), "> Greet, compiled again\n"),
    entered(Second, Two, ["m", "Greet.hello()"], "> \"hello, second\" : String\n"),
    has(written(Two, out), "Greet compiled again by session 1\nGreet.Msg changed: the binding m"
        " is of its previous version, Greet$1.Msg\n"),
    has(written(Two, out), "Hello : Greet$1.Msg\n"),
    %% report §11.2 *Faults*: the first session's tenth input faults the
    %% process its ninth spawned
    true = port_command(First, ["let w : Address(Int) = spawn(fn() = receive { n -> ",
                                "Io.println(Int.toString(10 / n)) })\n", "send(w, 0)\n"]),
    Faulted = "$Session1.input 9:1 faulted: division by zero\n",
    [fault_line(Input, Ops, Faulted) || {Input, Ops} <- [{First, One}, {Second, Two}]],
    says(Node, Faulted),
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
    ThirdOut = string:find(written(One, out), ", session 3. :help"),
    has(ThirdOut, Offered),
    has(ThirdOut, "$Session1.input 3:1 receiving\n"),
    ?assertEqual(nomatch, string:find(ThirdOut, "Greet")),
    _ = detached({Third, WaitThird}, One),
    {SecondOut, _} = detached({Second, WaitSecond}, Two),
    ?assertEqual(nomatch, string:find(SecondOut, "compiled again by session 2")),
    stop(Node, WaitNode).

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
    launched(Ops, ["cd ", Base, " && HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                   " --attach node --source-root src"]).

%% Inputs typed in line mode at the shell of Ops through Port, a line each,
%% until its standard output holds Part, which the last of them prints:
%% one step.
entered(Port, Ops, Inputs, Part) ->
    true = port_command(Port, [[Input, "\n"] || Input <- Inputs]),
    prints(Ops, Part).

%% A shell in line mode detached, which ends it with status 0 and leaves
%% the cursor on a line of its own, and what it wrote, nothing on its
%% standard error: two steps.
detached({Port, Wait}, Ops) ->
    true = port_command(Port, ":quit\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = said(Ops),
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
%% regression test: MVP 4.0's item 5
attached_service_test_() ->
    nodes_test({waits, 9}, fun attached_service/1).

attached_service(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "serve.ern"), serve()),
    0 = built([Root]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    [One, Two] = [made(Base, Name, none) || Name <- ["one", "two"]],
    lists(Node, [{"one", One, none}, {"two", Two, none}]),
    [lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    {_, WaitNode} = started(Node, filename:join(Root, "serve.erc"), []),
    prints(Node, "ready"),
    Ms = wait_ms_text(),
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
    has(Out, "> counted 4\nSome(2) : Optional(Int)\n"),
    {Second, _} = Again = attached(Two, "node", Base),
    true = port_command(Second, [[Input, "\n"]
                                 || Input <- [["let held <- Address.call(Serve.holder, ",
                                               "fn(reply) = Serve.Held(=reply), ", Ms,
                                               ")"],
                                              "let c <- held", Asked("6")]]),
    {SecondOut, _} = detached(Again, Two),
    has(SecondOut, "> c : Address(Serve.ServerMsg)\n> Some(5) : Optional(Int)\n"),
    ?assertEqual(nomatch, string:find(SecondOut, "counted")),
    prints(Node, "counted 10\n"),
    stop(Node, WaitNode),
    {NodeOut, NodeErr} = said(Node),
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
%% call's answer took `it`. Written before the code: MVP 4.0's item 13
attached_functions_test_() ->
    nodes_test({waits, 12}, fun attached_functions/1).

attached_functions(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = built([Root]),
    [Port, PeerPort] = [free_port(), free_port()],
    Node = made(Base, "node", Port),
    Peer = made(Base, "peer", PeerPort),
    [One, Two] = [made(Base, Name, none) || Name <- ["one", "two"]],
    lists(Node, [{"one", One, none}, {"two", Two, none}, {"peer", Peer, PeerPort}]),
    [lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two, Peer]],
    {_, WaitPeer} = launched(Peer, [?ERN, " run --config-dir ", Peer]),
    says(Peer, "listening on "),
    {_, WaitNode} = started(Node, filename:join(Root, "keep.erc"), []),
    prints(Node, "ready"),
    Ms = wait_ms_text(),
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
                                              " match Peer.computeAt(\"peer\", fn() = tripled(n), ",
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
    has(Out, "serving squares\n"),
    has(Out, "> Some(9) : Optional(Int)\n"),
    has(Out, "> 2 : Int\n"),
    {Second, _} = Again = attached(Two, "node", Base),
    entered(Second, Two, [Asked("Keep.holder", "Apply(number = 5, "),
                          ["let #(p, s) <- ", Asked("Keep.holder", "Servers(")],
                          Asked("p", "Ask(number = 5, "), "send(s, Keep.Crash)"],
            "s : Address(Keep.Ask)\n> Some(15) : Optional(Int)\n"),
    prints(Node, "serving squares\n"),
    true = port_command(Second, [Asked("s", "Ask(number = 5, "), "\n",
                                 "let _ = Keep.printUnits()\n"]),
    {SecondOut, _} = detached(Again, Two),
    has(SecondOut, "> Some(15) : Optional(Int)\n> p : "),
    %% the service's fault is said above its answer
    has(SecondOut, "Some(25) : Optional(Int)\n"),
    stop(Node, WaitNode),
    stop(Peer, WaitPeer),
    {NodeOut, NodeErr} = said(Node),
    ?assertEqual("ready\nserving squares\n", NodeOut),
    has(NodeErr, "$Session1.input 7:1 faulted, restarted: asked to crash"),
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
%% running code answers. Written before the fix, the release review before
%% 0.7.0 (C1), the first session having read the rebuilt files, the value
%% typed `String`, which faulted the session as it printed it.
attached_checks_the_loaded_code_test_() ->
    nodes_test({waits, 7}, fun attached_checks_the_loaded_code/1).

attached_checks_the_loaded_code(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    App = filename:join(Root, "app.ern"),
    ok = file:write_file(App, ["export fn g(n : Int) : Int = n * 100\n\n",
                               "export fn main() : Unit receiving Unit = {\n",
                               "    Io.println(\"ready\");\n",
                               "    receive { _ -> Unit }\n",
                               "}\n"]),
    0 = built([Root]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = started(Node, filename:join(Root, "app.erc"), []),
    prints(Node, "ready"),
    ok = file:write_file(App, ["export fn g(n : Int) : String = \"a string\"\n\n",
                               "export fn main() : Unit receiving Unit = {\n",
                               "    Io.println(\"ready\");\n",
                               "    receive { _ -> Unit }\n",
                               "}\n"]),
    0 = built([Root]),
    {Shell, _} = Attached = attached(Ops, "node", Base),
    entered(Shell, Ops, ["App.g(1)"], "> 100 : Int\n"),
    _ = detached(Attached, Ops),
    stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Startup and history*, §11.5: a
%% startup input's diagnostic quotes the file the shell's own node read it
%% from, its local half reading it again, and not a file of the node's: the
%% configuration directory's startup file, named from the operator's
%% working directory, `ops/startup`, its second input refused, which the
%% node, run from another directory, finds no file at. Written before the
%% fix, the release review before 0.7.0 (C4), the diagnostic quoting no
%% line of the file.
attached_startup_diagnostic_test_() ->
    nodes_test({waits, 5}, fun attached_startup_diagnostic/1).

attached_startup_diagnostic(Base) ->
    Ops = made(Base, "ops", none),
    Node = made(Base, "node", 0),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    Startup = filename:join(Ops, "startup"),
    ok = file:write_file(Startup, "let a = 1\nlet b : Int = \"not an Int\"\n"),
    %% report §11.2: a startup file another user could change is not run
    ok = file:change_mode(Startup, 8#600),
    ok = file:change_mode(Ops, 8#700),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {Shell, _} = Attached = launched(Ops, ["cd ", Base, " && HOME=", Home, " ", ?ERN,
                                           " shell --config-dir ops --attach node"]),
    prints(Ops, ":help for help.\n"),
    true = port_command(Shell, "a\n"),
    {Out, _} = detached(Attached, Ops),
    has(Out, "ops/startup:2:"),
    has(Out, "2 | let b : Int = \"not an Int\"\n"),
    stop(Node, WaitNode).

%% report §11.2 *The attached shell*, §12.1 *A session's screen*, Appendix
%% E.28, E.21: a `Code.load` at an attached prompt evaluates in an
%% evaluator the session's input started, which writes to the session's
%% screen, and so does what the evaluation starts; `:processes` lists what
%% it started and not the evaluator, the runtime's own. Once the session
%% detaches they are the node's and write to the node's standard output:
%% the binding's process, subscribed to the program's end, says so as the
%% node ends. Written with the code, the evaluator's row of the screen
%% taken from the input's chain and dropped with the session's
%% (ern_rt:evaluate/2, drop_screens/1)
attached_code_load_test_() ->
    nodes_test({waits, 10}, fun attached_code_load/1).

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
                         "    Os.termination(Ending);\n"
                         "    receive {\n"
                         "        Ending(reply) -> {\n"
                         "            Io.println(\"told at the end\");\n"
                         "            answer(reply, Unit)\n"
                         "        }\n"
                         "    }\n"
                         "}\n"
                         "\n"
                         "let teller : Address(Msg) = spawn(told)\n"),
    0 = built([Root]),
    0 = built([Lib]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = started(Node, filename:join(Root, "idle.erc"), []),
    prints(Node, "ready"),
    {Shell, _} = Attached = attached(Ops, "node", Base),
    prints(Ops, ":help for help.\n"),
    entered(Shell, Ops, ["Code.load(Path(\"" ++ filename:join(Lib, "told.erc") ++ "\"))"],
            "Right(Unit)"),
    entered(Shell, Ops, [":processes"], "Told.teller:15 receiving"),
    {Out, _} = detached(Attached, Ops),
    has(Out, "evaluated at the prompt\n"),
    ?assertEqual(2, length(string:split(Out, "Told.teller:15", all))),
    stop(Node, WaitNode),
    {NodeOut, _} = said(Node),
    has(NodeOut, "told at the end\n"),
    ?assertEqual(nomatch, string:find(NodeOut, "evaluated at the prompt")),
    ?assertEqual(nomatch, string:find(Out, "told at the end")).

%% report §11.2 *The attached shell*: the shell's own node reads for its
%% session the files of the source root, the startup files it ran and the
%% path `:output` names, and no other: a process of the session's node that
%% asks the local half itself, through a foreign function that finds its
%% address, is answered a file of the source root, refused one outside it,
%% refused an append anywhere but to the path `:output` took, and answered
%% one there. Written before the fix, the release review before 0.7.0 (S1),
%% the local half answering for any path, a hardening within the trust
%% model, a listed peer being trusted whole.
attached_local_files_test_() ->
    nodes_test({waits, 6}, fun attached_local_files/1).

attached_local_files(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = built([Root]),
    Source = filename:join(Base, "src"),
    ok = filelib:ensure_path(Source),
    Inside = filename:join(Source, "inside.ern"),
    ok = file:write_file(Inside, "export let x : Int = 1\n"),
    Outside = filename:join(Base, "outside.txt"),
    ok = file:write_file(Outside, "the operator's own\n"),
    Output = filename:join(Base, "output.txt"),
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = started(Node, filename:join(Root, "keep.erc"), []),
    prints(Node, "ready"),
    {Shell, _} = Attached = attached(Ops, "node", Source),
    Asked = fun(Kind, Path) -> ["Keep.asked(\"", Kind, "\", \"", Path, "\")"] end,
    entered(Shell, Ops, [Asked("read", Inside), Asked("read", Outside),
                         Asked("append", Outside), ":output " ++ Output,
                         Asked("append", Output), ":output -"],
            "output goes to standard output\n"),
    {Out, _} = detached(Attached, Ops),
    has(Out, "> \"taken\" : String\n> \"refused\" : String\n> \"refused\" : String\n"
             "> output goes to " ++ Output ++ "\n> \"taken\" : String\n"),
    ?assertEqual({ok, <<"the operator's own\n">>}, file:read_file(Outside)),
    stop(Node, WaitNode).

%% report §11.2 *The attached shell*, *Inputs*, §11.8: a session that ends
%% by a fault detaches as one that leaves does. At the prompt of a
%% program's node a session binds `x`, types `x + 1`, which holds `it`, and
%% lists the session units the node holds; it then ends its own screen
%% through a foreign function, which faults the session, a failure of the
%% shell's own: status 70 and the session's fault on standard error. A
%% second session lists the units again, and none of the first session's
%% is there, since none declares a function or builds a function value.
%% Written before the fix, the release review before 0.7.0 (C2, E1),
%% which a session that faulted failed, leaving its units, its rows and
%% its processes for the node's life.
attached_fault_detaches_test_() ->
    nodes_test({waits, 9}, fun attached_fault_detaches/1).

attached_fault_detaches(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "keep.ern"), keep()),
    Units = filename:join(Root, "ern_nodes_units.erl"),
    ok = file:write_file(Units, units_module()),
    {ok, _} = compile:file(Units, [{outdir, Root}]),
    0 = built([Root]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    [One, Two] = [made(Base, Name, none) || Name <- ["one", "two"]],
    lists(Node, [{"one", One, none}, {"two", Two, none}]),
    [lists(Ops, [{"node", Node, Port}]) || Ops <- [One, Two]],
    {_, WaitNode} = started(Node, filename:join(Root, "keep.erc"), []),
    prints(Node, "ready"),
    {First, WaitFirst} = attached(One, "node", Base),
    entered(First, One, ["let x = 1", "x + 1", "let _ = Keep.printUnits()"], "> 2 : Int\n"),
    prints(One, "ern@$bindings"),
    true = port_command(First, "Keep.endScreen()\n"),
    ?assertEqual(70, WaitFirst()),
    {Out, Err} = said(One),
    has(Err, "fault: the session on the node node: the shell's screen ended"),
    Before = session_units(Out),
    [Number] = lists:usort([Session || {_, Session} <- Before]),
    {Second, _} = Again = attached(Two, "node", Base),
    true = port_command(Second, "let _ = Keep.printUnits()\n"),
    {SecondOut, _} = detached(Again, Two),
    stop(Node, WaitNode),
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
%% once, without the time its stream stamps (§11.2). A process at
%% `:processes` is spawned some inputs before, so that it waits by then.
%% Written after the code, a regression test: MVP 4.0's item 5
attached_session_test_() ->
    nodes_test({waits, 4}, fun attached_session/1).

attached_session(Base) ->
    Node = made(Base, "node", 0),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    lists(Ops, [{"node", Node, bound_port(Node)}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {_, Wait} = launched(Ops, ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                               " --attach node --source-root fixtures/session"
                               " < fixtures/session/attached.in"]),
    ?assertEqual(0, Wait()),
    {Out, Err} = said(Ops),
    ?assertEqual("", Err),
    Unstamped = unstamped(Out),
    Connected = "the peer node connected\n",
    ?assertEqual(2, length(string:split(Unstamped, Connected, all))),
    {ok, Expected} = file:read_file("fixtures/session/attached.out"),
    ?assertEqual(binary_to_list(Expected),
                 lists:flatten(string:replace(Unstamped, Connected, "", all))),
    stop(Node, WaitNode).

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
%% error. Written after the code, a regression test: MVP 4.0's item 5
attached_terminal_test_() ->
    nodes_test({waits, 11}, fun attached_terminal/1).

attached_terminal(Base) ->
    Root = filename:join(Base, "program"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "faulter.ern"), faulter()),
    0 = built([Root]),
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    Pipe = filename:join(Base, "fault.pipe"),
    [] = os:cmd("mkfifo " ++ Pipe),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    {_, WaitNode} = started(Node, filename:join(Root, "faulter.erc"), [Pipe]),
    prints(Node, "ready"),
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
    Fault = "Faulter.main:5 faulted: division by zero",
    says(Node, Fault),
    Rows = [string:trim(Row, trailing)
            || Row <- string:split(binary_to_list(Screen), "\n", all)],
    ?assertEqual([Fault], [Row || Row <- Rows, string:find(Row, "faulted") =/= nomatch]),
    [Fault | Under] = lists:dropwhile(fun(Row) -> Row =/= Fault end, Rows),
    Trace = lists:takewhile(fun(Row) -> lists:prefix("    ", Row) end, Under),
    ?assertNotEqual([], Trace),
    ?assertMatch({["> 1 + 2", "3 : Int", "> :quit" | _], _},
                 {lists:nthtail(length(Trace), Under), Rows}),
    ?assertEqual(["> 1 + 2"], [Row || Row <- Rows, lists:prefix("> 1 +", Row)]),
    stop(Node, WaitNode).

%% report §11.2 *The attached shell*, Appendix E.16: `Terminal.size` in a
%% session reads its node's standard output. A session at a terminal of 24
%% rows, attached to a node whose standard output is a file, answers
%% `Left(NotATerminal)`; a session in line mode, attached to the same node
%% started under a terminal of 30 rows and 100 columns, answers that size.
%% A regression test of the release review's K8, written after the report
%% said it (the log's *Sites, Sessions and Their Names*): the code read the
%% node's standard output already
attached_terminal_size_test_() ->
    nodes_test({waits, 8}, fun attached_terminal_size/1).

attached_terminal_size(Base) ->
    Port = free_port(),
    Node = made(Base, "node", Port),
    Ops = made(Base, "ops", none),
    lists(Node, [{"ops", Ops, none}]),
    lists(Ops, [{"node", Node, Port}]),
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    Shell = lists:flatten(["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops,
                           " --attach node --source-root ", Base]),
    {_, WaitNode} = launched(Node, [?ERN, " run --config-dir ", Node]),
    says(Node, "listening on "),
    {0, Screen} = ern_pty:run(Shell, [{expect, ":help for help."}, {expect, "> "},
                                      {send, hex("Terminal.size()\r")},
                                      {expect, "Io.NotATerminal"},
                                      {send, hex(":quit\r")}],
                              [screen]),
    has(binary_to_list(Screen), "Left(Io.NotATerminal) : Either(Io.Error, Terminal.Size)"),
    stop(Node, WaitNode),
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
    has(binary_to_list(Answered),
        "Right(Terminal.Size(rows = 30, columns = 100)) : Either(Io.Error, Terminal.Size)").

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
     "    let _ = Os.run(Os.Command(program = \"cat\", arguments = [pipe], input = <<>>),\n"
     "                   waitMs());\n"
     "    Io.println(Int.toString(1 / (List.size(Os.arguments) - 1)))\n"
     "}\n",
     wait_ms_declaration()].

%% A shell attached from the node of Ops to its listed peer Name, in line
%% mode, its source root SourceRoot and its HOME a directory of its own, so
%% that no person's startup file runs.
attached(Ops, Name, SourceRoot) ->
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    launched(Ops, ["HOME=", Home, " ", ?ERN, " shell --config-dir ", Ops, " --attach ", Name,
                   " --source-root ", SourceRoot]).

%% report §8.7, §11.2, §12.5, §11.8: a bare node whose `ernest.conf` has no
%% `listen` is refused at its start, as the launcher's second start says
%% it, and writes no ernest.pid; and one whose carrier cannot start, its
%% port taken, ends as a job that cannot start, its line naming the listen
%% address in use, with status 1. Written after the code, the address with
%% the line that names it, and the job's line form with the log's *The
%% Shell's Own Node*
bare_node_refused_test_() ->
    nodes_test({waits, 2}, fun bare_node_refused/1).

bare_node_refused(Base) ->
    C = made(Base, "c", none),
    {1, Refused} = finished(?ERN ++ " run --config-dir " ++ C ++ " 2>&1"),
    ?assert(lists:suffix("ern run: a bare node listens: " ++ filename:join(C, "ernest.conf")
                         ++ " has no listen\n", Refused)),
    ?assertNot(filelib:is_file(filename:join(C, "ernest.pid"))),
    {ok, Held} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Held),
    D = made(Base, "d", Port),
    {1, Taken} = finished(?ERN ++ " run --config-dir " ++ D ++ " 2>&1"),
    ok = gen_tcp:close(Held),
    has(Taken, "ern run: the node's carrier did not start: its listen address 127.0.0.1:"
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
    nodes_test({waits, 15}, fun peer_option/1).

peer_option(Base) ->
    Program = spawner(filename:join(Base, "program")),
    {PortA, PortFoo} = {free_port(), free_port()},
    [A, Foo] = [filename:join(Base, Name) || Name <- ["a", "foo"]],
    Listen = fun(Port, Host) -> Host ++ ":" ++ integer_to_list(Port) end,
    [?assertMatch({0, _}, finished([?ERN, " config --config-dir ", Words]))
     || Words <- [[A, " --listen ", Listen(PortA, "0.0.0.0")],
                  [Foo, " --listen ", Listen(PortFoo, "127.0.0.1")],
                  [A, " --peer-dir ", Foo], [Foo, " --peer-dir ", A]]],
    lists:foreach(fun({Node, Address, Dialer}) ->
                      Wait = bare_started(Node, []),
                      says(Node, "listening on " ++ Address ++ "\n"),
                      Name = filename:basename(Node),
                      {_, Ran} = launched(Dialer, [?ERN, " run --config-dir ", Dialer, " ",
                                                   Program, " ", Name]),
                      ?assertEqual(0, Ran()),
                      {Out, _} = said(Dialer),
                      has(Out, Name ++ " computed 42"),
                      says(Node, "the peer " ++ filename:basename(Dialer) ++ " connected"),
                      stop(Node, Wait)
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
">>, wait_ms_declaration()]),
    0 = built([Root]),
    filename:join(Root, "spawner.erc").

%% report §11.2, §8.7: `ern run --verbose` of a node names each module the
%% program reads, and then each other module of its load path, which a
%% node's start reads, the toolchain's libraries last, on standard error,
%% each once, and standard output holds the program's alone, from a
%% directory whose name is beyond Latin-1. A regression test: the
%% launcher's first start, which writes what the job says to nothing,
%% raised at such a line, and the node was given no flags
verbose_node_start_test_() ->
    nodes_test({waits, 2}, fun verbose_node_start/1).

verbose_node_start(Base) ->
    E = made(Base, "e", none),
    Root = filename:join(Base, "r\x{2022}ot"),
    ok = filelib:ensure_path(filename:join(Root, "shelf")),
    [ok = file:write_file(filename:join(Root, File), Source)
     || {File, Source} <- [{"main.ern", "export fn main() : Unit = Io.println(Store.label)\n"},
                           {"store.ern", "export let label : String = \"ran\"\n"},
                           {"shelf/box.ern", "export fn size() : Int = 3\n"}]],
    0 = built([Root]),
    Main = filename:join(Root, "main.erc"),
    Err = E ++ ".err",
    ?assertEqual({0, "ran\n"},
                 finished([?ERN, " run --verbose --config-dir ", E, " ", Main, " 2> ", Err])),
    {ok, Said} = file:read_file(Err),
    Program = unicode:characters_to_binary(
                ["read Main from ", Main, "\nread Store from ", Root, "/store.erc\n"
                 "read Shelf.Box from ", Root, "/shelf/box.erc\n"]),
    Size = byte_size(Program),
    <<Program:Size/binary, Libraries/binary>> = Said,
    %% Every library's compiled module is read, each once; a library a
    %% module needs, Time under Http, is read as it is needed, so the lines'
    %% order is the need's and not the directories', and the sets are held.
    ?assertEqual(lists:sort([unicode:characters_to_binary(ern_build:shown(File))
                             || Library <- ern_tree:libraries(),
                                File <- ern_build:compiled_under(Library)]),
                 lists:sort([lists:last(string:split(Line, " from "))
                             || Line <- string:split(Libraries, "\n", all), Line =/= <<>>])).

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
%% A regression test, written with the fix: MVP 3.2's item 5 found each
%% such lambda's spawn answered `Other`, the binding refused and the
%% foreign function undeclared, and then the held definition's line naming
%% the foreign function and not its module. The test does not cover a
%% module that is here without the function, which ern_exchange_tests'
%% not_loaded_from_reach_test covers before code crosses
beyond_reach_test_() ->
    nodes_test({waits, 10}, fun beyond_reach/1).

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
                         unicode:characters_to_binary([Source, wait_ms_declaration()])),
    Host = filename:join(Root, "ern_probe_host.erl"),
    ok = file:write_file(Host, <<"-module(ern_probe_host).\n-export([only/0]).\n"
                                 "only() -> 'Unit'.\n">>),
    {ok, _} = compile:file(Host, [{outdir, Root}]),
    0 = built([Root]),
    A = made(Base, "a", none),
    B = made(Base, "b", 0),
    lists(B, [{"a", A, none}]),
    WaitB = bare_started(B, []),
    lists(A, [{"b", B, bound_port(B)}]),
    ?assertEqual(0, (start(A, filename:join(Root, "probe.erc"), []))()),
    [prints(B, Line) || Line <- ["the lambda ran", "the other lambda ran"]],
    Site = fun(Part) -> "Probe.main:" ++ integer_to_list(line_of(Source, Part)) end,
    [says(B, Line)
     || Line <- ["the peer a's spawn at " ++ Site("\"valued itself: \"") ++ " was not loaded:"
                 " the binding Probe.config has no value here",
                 "the peer a's spawn at " ++ Site("\"beside itself: \"") ++ " was not loaded:"
                 " the module ern_probe_host, which Probe.only calls, is not here"]],
    stop(B, WaitB),
    {Out, _} = said(A),
    {_, ErrB} = said(B),
    [has(Out, Line)
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
%% module. A regression test, written with the fix (MVP 3.2's item 5); it
%% does not cover a group relayed whole, nor a node asked for the reach of
%% a lacked foreign function spawned by its name, which it answers none as
%% it holds nothing it could run
relay_test_() ->
    nodes_test({waits, 17}, fun relay/1).

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
                         unicode:characters_to_binary([Source, wait_ms_declaration()])),
    Host = filename:join(HostDir, "ern_relay_host.erl"),
    ok = file:write_file(Host, <<"-module(ern_relay_host).\n-export([only/0]).\n"
                                 "only() -> 'Unit'.\n">>),
    {ok, _} = compile:file(Host, [{outdir, HostDir}]),
    0 = built([Root]),
    A = made(Base, "a", none),
    [B, C1, C2] = [made(Base, Name, 0) || Name <- ["b", "c1", "c2"]],
    [lists(C, [{"a", A, none}, {"b", B, none}]) || C <- [C1, C2]],
    {WaitC1, WaitC2} = {bare_started(C1, [HostDir]), bare_started(C2, [])},
    {PortC1, PortC2} = {bound_port(C1), bound_port(C2)},
    lists(B, [{"a", A, none}, {"c1", C1, PortC1}, {"c2", C2, PortC2}]),
    WaitB = bare_started(B, []),
    lists(A, [{"b", B, bound_port(B)}, {"c1", C1, PortC1}, {"c2", C2, PortC2}]),
    {_, WaitA} = launched(A, [?ERN, " run --config-dir ", A, " --load-path ", HostDir, " ",
                              filename:join(Root, "relay.erc")]),
    ?assertEqual(0, WaitA()),
    [prints(C, Line) || {C, Line} <- [{C1, "relayed to c1"}, {C2, "relayed to c2"},
                                      {C1, "only ran"}]],
    Lacked = fun(Part) ->
                 "the peer a's spawn at Relay.main:" ++ integer_to_list(line_of(Source, Part))
                     ++ " was not loaded: the module ern_relay_host, which Relay.only calls, is"
                        " not here"
             end,
    says(B, Lacked("\"held on b: \"")),
    says(C2, Lacked("\"held on c2: \"")),
    [stop(Dir, Wait) || {Dir, Wait} <- [{B, WaitB}, {C1, WaitC1}, {C2, WaitC2}]],
    {Out, _} = said(A),
    {OutB, ErrB} = said(B),
    [{_, ErrC1}, {_, ErrC2}] = [said(C) || C <- [C1, C2]],
    [has(Out, Line)
     || Line <- ["b: Right", "held on b: Io.NotLoaded", "held on c1: Right",
                 "held on c2: Io.NotLoaded"]],
    [has(OutB, Line) || Line <- ["c1: Right", "c2: Right"]],
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
    nodes_test({waits, 8}, fun fix_from_shell/1).

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
    0 = built([Root]),
    PortB = free_port(),
    B = made(Base, "b", PortB),
    Desk = made(Base, "desk", none),
    lists(B, [{"desk", Desk, none}]),
    lists(Desk, [{"b", B, PortB}]),
    WaitB = start(B, filename:join(Root, "fix.erc"), []),
    prints(B, "serving"),
    {DeskInput, WaitDesk} = shell_started(Desk, Source, [Root]),
    true = port_command(DeskInput, ":load Fix\n"),
    prints(Desk, "Fix, compiled from " ++ ern_build:shown(filename:join(Source, "fix.ern"))),
    true = port_command(DeskInput, ["Peer.spawn(\"b\", Fix.top, ", wait_ms_text(), ")\n"]),
    prints(Desk, ?SPAWNED),
    says(B, " faulted: foreign function erlang:binary_to_integer/1 raised error:badarg, spawned"
            " by the peer desk"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(B, WaitB),
    {_, ErrB} = said(B),
    %% the fix's file has a line more above its leaf than the build's
    [has(ErrB, Frame) || Frame <- ["\n    Fix.leaf:6\n", "\n    Fix.middle:8\n",
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
                         unicode:characters_to_binary([Source, wait_ms_declaration()])),
    ok = file:write_file(filename:join(Root, "ern_nodes_client.erl"), client()),
    ok = file:write_file(filename:join(Root, "ern_nodes_spawner.erl"), spawner()),
    [{ok, _} = compile:file(filename:join(Root, File), [{outdir, Root}])
     || File <- ["ern_nodes_client.erl", "ern_nodes_spawner.erl"]],
    0 = built([Root]),
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
    Node = list_to_atom(argument(ern_nodes_target)),
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
    sent(Node, {spawn, Ref, {function, Hash}, false, <<\"Lost.z:1\">>, false,
                list_to_integer(argument(ern_nodes_ms))}),
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
%% exchange ends, its time a millisecond, which the node then drops at that
%% time, saying so, spawns the function again and it runs, its fault's
%% trace naming its frame by its name and the sender's line (Appendix
%% E.21): the exchanges that broke or ran out of time made nothing that
%% runs, and the next made it whole. A regression test, written after the
%% code; that the node made one unit, which a trace named until 2026-10-20
%% and names no more, is not observed, the exchange's state after a loss is
%% ern_exchange_tests' loss_test's, and the late spawn's process, killed as
%% its answer arrives, is not observed
broken_exchange_test_() ->
    nodes_test({waits, 9}, fun broken_exchange/1).

broken_exchange(Base) ->
    Root = filename:join(Base, "build"),
    {Program, Source} = lost_build(Root),
    {ok, Beam} = file:read_file(Program),
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
    Defined = fun(Name) -> hd([Definition || #definition{qualified_name = ['Lost', Named]}
                                                 = Definition <- Definitions, Named =:= Name])
              end,
    #definition{hash = Waits} = Defined(waits),
    #definition{qualified_name = OtherName, hash = Other, form = Form, sourced = Sourced,
                printing = Printing} = Defined(other),
    Frame = filename:join(Base, "frame"),
    ok = file:write_file(Frame, term_to_binary(
                                  {Other, ern_canonical:bytes(ern_canonical:hashed([Form])),
                                   term_to_binary([{[atom_to_binary(Segment)
                                                     || Segment <- OtherName],
                                                    Sourced, Printing, []}])})),
    A = made(Base, "a", none),
    Z = made(Base, "z", none),
    B = made(Base, "b", 0),
    lists(B, [{"a", A, none}, {"z", Z, none}]),
    WaitB = bare_started(B, []),
    PortB = bound_port(B),
    {_, Spawner} = client(Root, name(Z), key_files(Z), ern_carrier:cookie(), PortB, name(B),
                          ["-ern_nodes_hash", binary_to_list(binary:encode_hex(Waits)),
                           "-ern_nodes_frame", Frame],
                          "ern_nodes_spawner"),
    {0, SpawnerOut} = Spawner(),
    [has(SpawnerOut, Line) || Line <- ["no longer held: Other", "late frame: the connection lives",
                                       "lacks: 2", "faulty: ended", "broken: closed",
                                       "lacked again: true"]],
    seen(B, err, "the peer z was lost", 2, ?WAIT_MS),
    lists(A, [{"b", B, PortB}]),
    ?assertEqual(0, (start(A, Program, ["b"]))()),
    Site = "Lost.late:" ++ integer_to_list(line_of(Source, "let again")),
    says(B, Site ++ " faulted: foreign function erlang:binary_to_integer/1 raised error:badarg,"
                    " spawned by the peer a"),
    stop(B, WaitB),
    {Out, _} = said(A),
    {_, ErrB} = said(B),
    [has(Out, Line) || Line <- ["dialed: Right", "late: Io.Timeout", "again: Right"]],
    [has(ErrB, Line)
     || Line <- ["the peer z's spawn at Lost.z:1 was not loaded: the spawner's node no longer"
                 " holds the function's reach",
                 "the peer a's spawn at Lost.late:" ++ integer_to_list(line_of(Source, "late: "))
                 ++ " was not loaded: its time ran out before the function's reach arrived",
                 "the peer z sent a frame this node cannot read, and its connection was ended",
                 "\n    Lost.waits:" ++ integer_to_list(line_of(Source, "parsed(\"x\") + n"))
                 ++ "\n"]],
    [?assertEqual(nomatch, string:find(ErrB, Part)) || Part <- ["ern$", "could not take"]],
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(ErrB, "4.3", "no longer holds the function's reach",
                                   [{"a", "z"}, {"Counter.main:19", "Lost.z:1"}]).

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
    nodes_test({waits, 9}, fun shell_service/1).

shell_service(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "shared.ern"), "export type T = T(Int)\n"),
    [PortA, PortB] = [free_port(), free_port()],
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    [edit(Dir, fun(Conf) -> Conf#{<<"services">> => #{<<"t">> => [Peer], <<"p">> => [Peer]}} end)
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
                ["Io.println(Io.show(Peer.find(prompt, ", wait_ms_text(), ")))\n",
                 "match Peer.find(service, ", wait_ms_text(), ") {\n"
                 "    Right(server) -> {\n"
                 "        send(server, Shared.T(", Count, "));\n"
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
    [has(Out, "Left(Io.OtherType)\n") || {Out, _} <- [said(A), said(B)]].

%% report Appendix H, §11.2 *Inputs*, *The attached shell*, §8.7, §3.11:
%% the form of a session's namespace carries its node's public key, so that
%% two nodes' sessions of one number declare two names. `let below =
%% Clock.now()` and a function over it, typed at the prompts of two shells
%% that are nodes, each its node's session 1, are two bindings and two
%% functions. A name a prompt `let` binds is its node's binding, read where
%% the code that names it runs: a compute from b on a of a lambda that
%% reads `below`, and one of b's function, answer `Left(NotLoaded)`, b's
%% binding having no value on a, and a names it without the key,
%% `$Session1.below`, on its screen, where a plain shell's node writes its
%% lines; a local the lambda captures crosses with it, and b's own function
%% runs on b over b's value.
%%
%% A regression test of the release review's C7 and S3, written after the
%% code (the log's *Sites, Sessions and Their Names*): a's value was read,
%% the two sessions' declarations being one identity. The test it replaces,
%% written for the holder of what a `let` binds counted as evaluated so
%% that a peer's spawn found it (the log's *MVP 3.1 Read*), named a binding
%% of another node's session, which no peer can now. The captured local's
%% compute was added with the log's *The Input's Process*, which states
%% the rule the code kept.
shell_binding_spawned_test_() ->
    nodes_test({waits, 7}, fun shell_binding_spawned/1).

shell_binding_spawned(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    Typed = "let below = Clock.now()\nfn later() : Int = below + 1\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA, [Typed, "Io.println(\"typed\")\n"]),
    prints(A, "typed"),
    {InputB, WaitB} = shell_started(B, Root),
    Limit = wait_ms_text(),
    true = port_command(InputB, [Typed, "Peer.computeAt(\"a\", fn() = below + 1, ", Limit, ")\n",
                                 "Peer.computeAt(\"a\", later, ", Limit, ")\n",
                                 "{ let n = below; Peer.computeAt(\"a\", fn() = n + 1, ", Limit,
                                 ") == Right(below + 1) }\n",
                                 "later() == below + 1\n"]),
    prints(B, "Left(Io.NotLoaded) : Either(Io.Error, Int)", 2, ?WAIT_MS),
    prints(B, "true : Bool", 2, ?WAIT_MS),
    prints(A, "the binding $Session1.below has no value here"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()),
    {OutA, ErrA} = said(A),
    ?assertEqual(nomatch, string:find(OutA ++ ErrA, "$Session1@")).

%% report §11.2, §8.7, Appendix E.27: a shell that is a node computes on a
%% peer as a program does: a function declared at its prompt has a hash,
%% which the peer, a shell whose session declared a function of the same
%% text, does not hold, since the form of each session's namespace carries
%% its node's key (Appendix H), so it crosses with the compute; so do a
%% lambda typed at the prompt and a function declared at the desk's prompt
%% alone, the desk answering the reach from the forms it keeps beside the
%% input's code and sending them, and the peer, having verified them,
%% compiles and runs them, answering their values, which the shell prints
%% at their type (MVP 3.2's items 3 and 4).
%%
%% A type the desk declares crosses with a function spawned on the worker,
%% whose check's cause names it as the session writes it, bare (§11.5), and
%% the fault's site carries the desk's session, its key left out. A
%% regression test, written after the code
shell_compute_test_() ->
    nodes_test({waits, 9}, fun shell_compute/1).

shell_compute(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortWorker = free_port(),
    Worker = made(Base, "worker", PortWorker),
    Desk = made(Base, "desk", none),
    lists(Worker, [{"desk", Desk, none}]),
    lists(Desk, [{"worker", Worker, PortWorker}]),
    Declared = "fn answer() : Int = 6 * 7\n",
    {InputWorker, WaitWorker} = shell_started(Worker, Root),
    true = port_command(InputWorker, [Declared, "Io.println(\"declared\")\n"]),
    prints(Worker, "declared"),
    {InputDesk, WaitDesk} = shell_started(Desk, Root),
    Limit = wait_ms_text(),
    true = port_command(InputDesk, [Declared, "Peer.computeAt(\"worker\", answer, ", Limit, ")\n",
                                    "Peer.computeAt(\"worker\", fn() = 6 * 7, ", Limit, ")\n",
                                    "fn alone() : Int = 6 * 9\n",
                                    "Peer.computeAt(\"worker\", alone, ", Limit, ")\n",
                                    "type Count = Count(Int)\n",
                                    "foreign fn wrong() : Count = \"erlang:yield/0\"\n",
                                    "fn counts() : Unit = {\n"
                                    "    Io.println(\"counting\");\n"
                                    "    let _ = wrong();\n"
                                    "    Unit\n"
                                    "}\n",
                                    "Peer.spawn(\"worker\", counts, ", Limit, ")\n"]),
    prints(Desk, "Right(42) : Either(Io.Error, Int)", 2, ?WAIT_MS),
    prints(Desk, "Right(54) : Either(Io.Error, Int)"),
    prints(Desk, ?SPAWNED),
    prints(Worker, "counting"),
    fault_line(InputWorker, Worker,
               "$Session1.input 9:1 faulted: the return of foreign function erlang:yield/0"
               " does not match Count, spawned by the peer desk"),
    true = port_command(InputDesk, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    true = port_command(InputWorker, ":quit\n"),
    ?assertEqual(0, WaitWorker()),
    {OutWorker, _} = said(Worker),
    ?assertEqual(nomatch, string:find(OutWorker, "was not loaded")),
    ?assertEqual(nomatch, string:find(OutWorker, "$Session1.Count")),
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
    nodes_test({waits, 6}, fun shell_offered_adapted/1).

shell_offered_adapted(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "shared.ern"), "export type T = T(Int)\n"),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    edit(B, fun(Conf) -> Conf#{<<"services">> => #{<<"t">> => [<<"a">>]}} end),
    Declared = ":load Shared\nlet service : Peer.Service(Shared.T) = Peer.service(\"t\")\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA,
                        [Declared,
                         "let store : Address(Int) = spawn(fn() : Unit receiving Int =\n"
                         "    receive { n -> Io.println(\"a got \" <> Int.toString(n)) })\n",
                         "Peer.offer(service,"
                         " adapted(store, fn(t) = match t { Shared.T(n) -> n }))\n",
                         [["1 + ", integer_to_list(Index), "\n"] || Index <- lists:seq(1, 30)],
                         "Io.println(\"offered\")\n"]),
    prints(A, "offered"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, [Declared,
                                 "match Peer.find(service, ", wait_ms_text(), ") {\n"
                                 "    Right(server) -> {\n"
                                 "        send(server, Shared.T(5));\n"
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
%% process after the cause, which the FaultReport's `spawnedBy` names. A
%% regression test, written after the code (the log's *MVP 3.1 Read*): the
%% shell's line named the spawner's site alone. A shell in line mode reports
%% a fault before its next prompt, so the shell that faulted is given inputs
%% until the line comes (fault_line/3). A local fault's report, which names
%% no peer, is ern_rt_tests' fault_reports_test's
shell_peer_fault_test_() ->
    nodes_test({waits, 6}, fun shell_peer_fault/1).

shell_peer_fault(Base) ->
    Root = filename:join(Base, "src"),
    ok = filelib:ensure_path(Root),
    PortA = free_port(),
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, none}]),
    lists(B, [{"a", A, PortA}]),
    Typed = "fn divided() : Unit = {\n"
            "    Io.println(\"dividing\");\n"
            "    let _ = 1 / List.size([]);\n"
            "    Unit\n"
            "}\n",
    {InputA, WaitA} = shell_started(A, Root),
    true = port_command(InputA, [Typed, "Io.println(\"typed\")\n"]),
    prints(A, "typed"),
    {InputB, WaitB} = shell_started(B, Root),
    true = port_command(InputB, [Typed, "match Peer.spawn(\"a\", divided, ", wait_ms_text(), ") {\n"
                                        "    Right(_) -> Io.println(\"spawned\")\n"
                                        "  | Left(failure) -> Io.println(Io.show(failure))\n"
                                        "}\n"]),
    prints(B, "spawned"),
    prints(A, "dividing"),
    fault_line(InputA, A, " faulted: division by zero, spawned by the peer b\n"),
    true = port_command(InputB, ":quit\n"),
    ?assertEqual(0, WaitB()),
    true = port_command(InputA, ":quit\n"),
    ?assertEqual(0, WaitA()).

%% report §11.2, §8.7: a shell that is a node loads a module, and a peer
%% of the build that holds the module spawns a function of it there by its
%% hash, the value of the binding its reach names found, as on a node that
%% runs a program; a function typed at the shell has a hash and no peer
%% holds it, so a spawn of it carries its form to the peer, which compiles
%% it and starts it (MVP 3.2's items 3 and 4). Written after the code (MVP
%% 3.1's item 5): a peer found no value of a binding the shell's load had
%% evaluated
shell_node_test_() ->
    nodes_test({waits, 9}, fun shell_node/1).

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
                         ++ wait_ms_declaration()),
    0 = built([Root]),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    {StoreInput, WaitStore} = started(Store, filename:join(Root, "store.erc"), []),
    prints(Store, "ready"),
    {DeskInput, WaitDesk} = shell_started(Desk, Root),
    true = port_command(DeskInput, [":load Greet\n"
                                    "Peer.spawn(\"store\", fn() = Unit, ", wait_ms_text(), ")\n"]),
    prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "go\n"),
    prints(Store, "spawned: Right"),
    prints(Desk, "hello from the shell's load"),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, _} = said(Desk),
    {_, StoreErr} = said(Store),
    %% report §11.2: greet.erc stands beside its source and is as new as it,
    %% so the load takes it and compiles nothing
    has(DeskOut, "Greet, from " ++ ern_build:shown(filename:join(Root, "greet.erc"))),
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
    nodes_test({waits, 15}, fun shell_node_versions/1).

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
                         "}\n" ++ wait_ms_declaration()),
    0 = built([Root]),
    Changed = fun(Text) ->
                  ok = file:write_file(filename:join(Source, "greet.ern"),
                                       Greet(["\nexport fn other() : Unit ="
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
    %% the desk dials the store, which does not hold the lambda, and is sent
    %% its form, which it compiles and starts
    true = port_command(DeskInput,
                        ["Peer.spawn(\"store\", fn() = Unit, ", wait_ms_text(), ")\n"]),
    prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "first\n"),
    prints(Store, "first: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Greet\n"),
    prints(Desk, "Greet, compiled from " ++ ern_build:shown(filename:join(Source, "greet.ern"))),
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
%% regression test, written after the fix, found on reading back a fix of
%% the log's *MVP 3.1 Read*: the binding was found by its identity in the
%% session's greeter, the build's caller ran, and its process faulted, the
%% binding read in the build's greeter having no value
shell_node_reach_test_() ->
    nodes_test({waits, 11}, fun shell_node_reach/1).

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
                         "    }\n" ++ wait_ms_declaration()),
    0 = built([Root]),
    Other = "\nexport fn other() : Unit = Io.println(\"other\")\n",
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
    prints(Desk, "Greet, compiled from " ++ ern_build:shown(filename:join(Source, "greet.ern"))),
    %% the desk dials the store, which does not hold the lambda, and is sent
    %% its form, which it compiles and starts
    true = port_command(DeskInput,
                        ["Peer.spawn(\"store\", fn() = Unit, ", wait_ms_text(), ")\n"]),
    prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "first\n"),
    prints(Store, "first: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Caller\n"),
    prints(Desk, "Caller, compiled from " ++ ern_build:shown(filename:join(Source, "caller.ern"))),
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
%% after the fix (the log's *MVP 3.1 Read*): the process ran on unnamed,
%% since it ran no code the load brought, while the load erased the unit's
%% values
refused_build_load_test_() ->
    nodes_test({waits, 11}, fun refused_build_load/1).

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
                         "    }\n" ++ wait_ms_declaration()),
    0 = built([Root]),
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
    %% the desk dials the store, which does not hold the lambda, and is sent
    %% its form, which it compiles and starts
    true = port_command(DeskInput,
                        ["Peer.spawn(\"store\", fn() = Unit, ", wait_ms_text(), ")\n"]),
    prints(Desk, ?SPAWNED),
    true = port_command(StoreInput, "before\n"),
    prints(Store, "before: Io.NotLoaded"),
    true = port_command(DeskInput, ":load Bad\n"),
    prints(Desk, "Bad.broken:3 faulted: division by zero; nothing was loaded, and the process"
                 " spawned at Greet.greeter:5 was killed"),
    true = port_command(DeskInput, ":processes\n"),
    prints(Desk, "no process of the session's is running"),
    true = port_command(StoreInput, "after\n"),
    prints(Store, "after: Io.NotLoaded"),
    %% the shell writes the node's lines on its screen, this one after the
    %% desk's worker has answered the store, so it is waited for before the
    %% session is ended
    NotLoaded = "the peer store's spawn at Store.spawning:11 was not loaded: the binding"
                " Greet.greeter has no value here",
    prints(Desk, NotLoaded, 2, ?WAIT_MS),
    true = port_command(DeskInput, ":quit\n"),
    ?assertEqual(0, WaitDesk()),
    stop(Store, WaitStore),
    {DeskOut, DeskErr} = said(Desk),
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
    nodes_test({waits, 11}, fun adapted_fault/1).

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
                         "    }\n" ++ wait_ms_declaration()),
    0 = built([Root]),
    Program = filename:join(Root, "adapted.erc"),
    PortMaker = free_port(),
    Maker = made(Base, "maker", PortMaker),
    Sender = made(Base, "sender", none),
    lists(Maker, [{"sender", Sender, none}]),
    lists(Sender, [{"maker", Maker, PortMaker}]),
    edit(Sender, fun(Conf) -> Conf#{<<"services">> => #{<<"work">> => [<<"maker">>]}} end),
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
%% after the code (MVP 3.1's item 8)
end_told_on_a_node_test_() ->
    nodes_test({waits, 8}, fun end_told_on_a_node/1).

end_told_on_a_node(Base) ->
    Root = peers_built(Base),
    PortStore = free_port(),
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}]),
    edit(Desk, fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"store">>]}} end),
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
    has(StoreErr, "the subscriber Keeper.main answered"),
    %% the line as the deployment guide quotes it
    ern_deployment_tests:cataloged(StoreErr, "7", "the end waits for", []).

%% report §8.6, §11.2: a second termination ends the node at once, past a
%% subscriber that does not answer, which the node says. Written after the
%% code (MVP 3.1's item 8), the line after that
second_termination_test_() ->
    nodes_test({waits, 5}, fun second_termination/1).

second_termination(Base) ->
    Root = peers_built(Base),
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

%% Appendix G.7, report §8.7: a proxy reaches the counter, a
%% call through it answers None while the counter's node is stopped, it
%% reaches the counter again when its node starts again, and on another
%% node that offers it once the first is stopped. An add sent through it
%% while the node is stopped is dropped, and not delivered once the node is
%% back: the counter started again counts from 0, and answers 0. Written
%% after the code (MVP 3.1's item 8), the add a regression test written
%% after that
proxy_finds_again_test_() ->
    nodes_test({waits, 13}, fun proxy_finds_again/1).

proxy_finds_again(Base) ->
    Root = peers_built(Base),
    {PortStore, PortOther} = {free_port(), free_port()},
    Store = made(Base, "store", PortStore),
    Other = made(Base, "other", PortOther),
    Desk = made(Base, "desk", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Other, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}, {"other", Other, PortOther}]),
    edit(Desk, fun(Conf) ->
                   Conf#{<<"services">> => #{<<"counter">> => [<<"store">>, <<"other">>]}}
               end),
    Keeper = filename:join(Root, "keeper.erc"),
    WaitStore = start(Store, Keeper, []),
    prints(Store, "offered"),
    {DeskInput, WaitDesk} = started(Desk, filename:join(Root, "client.erc"), []),
    prints(Desk, "proxy started"),
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

%% report §8.7, §6.6, Appendix E.27: examples/typed_channels_nodes.ern as
%% two nodes, as its first comment runs them: b runs serve, which offers
%% the counter as its service, and a runs main, which finds the counter on
%% b and calls it across the nodes. A regression test, written with the
%% example; a find at another type is program_test_'s
typed_channels_test_() ->
    nodes_test({waits, 5}, fun typed_channels/1).

typed_channels(Base) ->
    BuildRoot = filename:join(Base, "build"),
    0 = built(["--source-root", "../examples", "--build-root", BuildRoot,
               "../examples/typed_channels_nodes.ern"]),
    Program = filename:join(BuildRoot, "typed_channels_nodes.erc"),
    PortB = free_port(),
    ConfigDirA = made(Base, "a", none),
    ConfigDirB = made(Base, "b", PortB),
    lists(ConfigDirA, [{"b", ConfigDirB, PortB}]),
    lists(ConfigDirB, [{"a", ConfigDirA, none}]),
    edit(ConfigDirA, fun(Configuration) ->
                             Configuration#{<<"services">> => #{<<"counter">> => [<<"b">>]}}
                     end),
    {_, WaitB} = launched(ConfigDirB, [?ERN, " run --config-dir ", ConfigDirB,
                                       " --main TypedChannelsNodes.serve ", Program]),
    prints(ConfigDirB, "offered"),
    ?assertEqual(0, (start(ConfigDirA, Program, []))()),
    stop(ConfigDirB, WaitB),
    {OutA, _} = said(ConfigDirA),
    has(OutA, "total on b: Some(5)").

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
    nodes_test({waits, 9}, fun lease_broker/1).

lease_broker(Base) ->
    BuildRoot = filename:join(Base, "build"),
    0 = built(["--source-root", "../examples", "--build-root", BuildRoot,
               "../examples/lease_broker.ern"]),
    Program = filename:join(BuildRoot, "lease_broker.erc"),
    A = made(Base, "a", none),
    B = made(Base, "b", 0),
    lists(B, [{"a", A, none}]),
    {_, WaitB} = launched(B, [?ERN, " run --config-dir ", B, " --main LeaseBroker.serve ",
                              Program]),
    PortB = bound_port(B),
    lists(A, [{"b", B, PortB}]),
    edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"leases">> => [<<"b">>]}} end),
    prints(B, "offered"),
    {_, WaitA} = launched(A, [?ERN, " run --config-dir ", A, " --main LeaseBroker.visit ",
                              Program]),
    ?assertEqual(0, WaitA()),
    prints(B, "the broker took back 2 from bob: Restarted"),
    prints(B, "the broker took back 1 from ann: ProgramEnd"),
    stop(B, WaitB),
    {OutA, ErrA} = said(A),
    {OutB, ErrB} = said(B),
    Shown = fun(Command) -> ern_integration_tests:shown("lease_broker.ern", Command) end,
    ?assertEqual(Shown("ern run --config-dir a --main LeaseBroker.visit lease_broker.erc")
                     -- [<<"listening on 0.0.0.0:8654">>],
                 ern_integration_tests:printed([OutA, ErrA])),
    %% the last line of b's standard error, `Terminated`, is the line the
    %% shell launched/2 runs the node under writes of its end by the signal
    ?assertEqual(lists:sort([<<"listening on 127.0.0.1:", (integer_to_binary(PortB))/binary>>,
                             <<"Terminated">>
                             | Shown("ern run --config-dir b --main LeaseBroker.serve"
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
    nodes_test({waits, 7}, fun placed/1).

placed(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    %% how often the store and the desk tell their utilizations, which the
    %% desk waits one of before its pick: the scenario's, and no bound
    Interval = 200,
    [edit(Dir, fun(Conf) -> Conf#{<<"utilization-interval">> => Interval} end)
     || Dir <- [Store, Desk]],
    edit(Store, fun(Conf) ->
                    Conf#{<<"measures">> => #{<<"cpu">> => #{}, <<"memory">> => #{},
                                              <<"disk">> => #{}}}
                end),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    ?assertEqual(0, (start(Desk, DeskProgram, ["place", integer_to_list(Interval)]))()),
    prints(Store, "readings there"),
    stop(Store, WaitStore),
    {Out, _} = said(Desk),
    {StoreOut, StoreErr} = said(Store),
    %% report §12.5: the host's own reports are not written; a regression:
    %% the program the host runs for the cpu measure said, as the host
    %% ended, that the host had closed
    ?assertEqual(nomatch, string:find(StoreErr, "Erlang has closed")),
    [has(Out, Line)
     || Line <- ["before a telling: Left(Io.Unreachable)", "readings: Right",
                 "computed: Right([\"desk\", \"third\"])", "held: [\"store\"]",
                 "readings here: #(false, false, false)"]],
    has(StoreOut, "readings there: #(true, true, true)").

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
             "    Io.println(\"before a telling: \" <> Io.show(Peer.compute(ran, waitMs())));\n"
             "    let set1 = Peer.computeAt(\"p1\", fn() = Peer.setUtilization(0.9), waitMs());\n"
             "    Io.println(\"p1 set: \" <> Io.show(set1));\n"
             "    let set2 = Peer.computeAt(\"p2\", fn() = Peer.setUtilization(0.1), waitMs());\n"
             "    Io.println(\"p2 set: \" <> Io.show(set2));\n"
             "    heard(\"p1\", 0.9, interval);\n"
             "    heard(\"p2\", 0.1, interval);\n"
             "    let told = List.map(Peer.utilizations(), fn(#(name, utilization, _)) ="
             " #(name, utilization));\n"
             "    Io.println(\"utilizations: \" <> Io.show(told));\n"
             "    Io.println(\"utilization of p1: \" <> Io.show(Peer.utilization(\"p1\","
             " waitMs())));\n"
             "    let computed = List.map(List.range(1, 20), fn(_) = Peer.compute(ran,"
             " waitMs()));\n"
             "    Io.println(\"computed: \" <> Io.show(List.unique(computed)));\n"
             "    Io.println(\"named: \" <> Io.show(Peer.computeAt(\"p1\", ran, waitMs())));\n"
             "    Io.println(\"now stop p2\");\n"
             "    let _ = Io.readLine();\n"
             "    let left = List.map(Peer.utilizations(), fn(#(name, _, _)) = name);\n"
             "    Io.println(\"after the loss: \" <> Io.show(left));\n"
             "    Io.println(\"computed alone: \" <> Io.show(Peer.compute(ran, waitMs())))\n"
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
             "    Io.println(\"no peer: \" <> Io.show(Peer.compute(ran, waitMs())));\n"
             "    Io.println(\"no utilization: \" <> Io.show(Peer.utilizations()))\n"
             "}\n"
             "\n"
             "// Until the node is stopped: a node waiting for ever is no deadlock.\n"
             "fn waits() : Unit receiving Unit =\n"
             "    receive {\n"
             "        _ -> waits()\n"
             "    }\n",
    ok = file:write_file(filename:join(Dir, "pick.ern"),
                         unicode:characters_to_binary([Source, wait_ms_declaration()])),
    0 = built([Dir]),
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
%% the spawner's, by which it would mostly be too old, and `Peer.computeAt`
%% runs on the peer named, p1. With p2 stopped, its utilization is dropped
%% at the loss, which the spawner says, and a compute runs on p1, the one
%% peer left, taken as it is; and a node that lists no peer answers
%% NotListed and holds no utilization. A regression test, written after the
%% code; the spawner waits for each telling by reading its utilizations at
%% each interval, so that a telling's coming within one interval is held by
%% no time here, and the draw among more than two peers and the age of a
%% utilization are ern_peer_tests'
pick_test_() ->
    nodes_test({waits, 11}, fun pick/1).

pick(Base) ->
    Program = pick_build(Base),
    {Port1, Port2} = {free_port(), free_port()},
    S = made(Base, "s", none),
    P1 = made(Base, "p1", Port1),
    P2 = made(Base, "p2", Port2),
    Alone = made(Base, "alone", none),
    %% how often p1 and p2 tell, which the spawner waits one of for each,
    %% and how often the spawner does, by which their utilizations would be
    %% too old: the scenario's, and no bound
    {Interval, SpawnersInterval} = {200, 20},
    lists(S, [{"p1", P1, Port1}, {"p2", P2, Port2}]),
    [lists(Dir, [{"s", S, none}]) || Dir <- [P1, P2]],
    [edit(Dir, fun(Conf) -> Conf#{<<"utilization-interval">> => Ms} end)
     || {Dir, Ms} <- [{S, SpawnersInterval}, {P1, Interval}, {P2, Interval}]],
    Wait1 = start(P1, Program, ["p1"]),
    Wait2 = start(P2, Program, ["p2"]),
    [prints(Dir, "waiting") || Dir <- [P1, P2]],
    {SPort, WaitS} = started(S, Program, ["s", integer_to_list(Interval)]),
    prints(S, "now stop p2"),
    stop(P2, Wait2),
    says(S, "the peer p2 ended"),
    true = port_command(SPort, "go\n"),
    ?assertEqual(0, WaitS()),
    stop(P1, Wait1),
    ?assertEqual(0, (start(Alone, Program, ["alone"]))()),
    {Out, _} = said(S),
    [has(Out, Line)
     || Line <- ["before a telling: Left(Io.Unreachable)", "p1 set: Right(Unit)",
                 "p2 set: Right(Unit)", "utilizations: [#(\"p1\", 0.9), #(\"p2\", 0.1)]",
                 "utilization of p1: Right(0.9)", "computed: [Right([\"p2\"])]",
                 "named: Right([\"p1\"])", "after the loss: [\"p1\"]",
                 "computed alone: Right([\"p1\"])"]],
    {AloneOut, _} = said(Alone),
    [has(AloneOut, Line) || Line <- ["no peer: Left(Io.NotListed)", "no utilization: []"]].

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
    nodes_test({waits, 30}, fun pair_program/1).

pair_program(Base) ->
    _ = peers(Base),
    second_build(Base),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, PortB}]),
    edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"pair">> => [<<"b">>]}} end),
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
    %% its three tests the second node's start, the three files read and the
    %% one written before it, its stop and its end; a find and a call in the
    %% first, a find in the second, and in the third two calls through the
    %% proxy and the wait for the proxy's end
    {Status, Output} = collected(Port, 28),
    ?assertEqual({0, nomatch}, {Status, binary:match(Output, <<"failed">>)}),
    has(binary_to_list(Output), "a second node made, started with Os, found, called and stopped:"
                                " passed"),
    has(binary_to_list(Output), "a second node of another build, started with Os, offers at another"
                                " type: passed"),
    has(binary_to_list(Output), "a proxy for a service offered at another type faults, and is"
                                " dead: passed"),
    ?assertMatch({match, _}, re:run(Output, "Proxy\\.start:[0-9]+ faulted: the service pair is"
                                            " offered at another type")),
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
    0 = built(["--source-root", Root, "--build-root", filename:join(Base, "second-build"),
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
        {Status, Said} = collected(Port, 1),
        {Status, binary_to_list(Said)}
    end.

%% What a port the test opened writes next, or none where it writes nothing
%% within the harness's time for one wait: one step.
output(Port) ->
    step({output, Port}),
    receive {Port, {data, Data}} -> Data after ?WAIT_MS -> none end.

%% A port's output to its end, and its exit status, within Steps steps,
%% each given the harness's time for one wait: one, or a run's own steps,
%% which the harness cannot see. The port is opened with `binary` and
%% `exit_status`; one that has not ended by then is closed and fails the
%% test, naming what it wrote.
-spec collected(port(), pos_integer()) -> {integer(), binary()}.
collected(Port, Steps) ->
    step({collected, Port}, Steps),
    collected(Port, <<>>, erlang:monotonic_time(millisecond) + Steps * ?WAIT_MS).

collected(Port, Acc, Deadline) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, <<Acc/binary, Bytes/binary>>, Deadline);
        {Port, {exit_status, Status}} -> {Status, Acc}
    after max(Deadline - erlang:monotonic_time(millisecond), 0) ->
        port_close(Port),
        erlang:error({still_running, Port, Acc})
    end.

%% The process number in a node's ernest.pid.
pid(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.pid")),
    string:trim(binary_to_list(Text)).

%% report §8.7, §12.6, the proposal's sections 4, 7 and 8: a peer stopped stands
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
    nodes_test({waits, 8, ?DETECTOR_MS}, fun silence/1).

silence(Base) ->
    {StoreProgram, DeskProgram} = peers(Base),
    {Store, Desk} = store_and_desk(Base),
    WaitStore = start(Store, StoreProgram, []),
    prints(Store, "offered"),
    {DeskPort, WaitDesk} = started(Desk, DeskProgram, ["silence"]),
    prints(Desk, "now stop the store"),
    _ = os:cmd("kill -STOP " ++ pid(Store)),
    true = port_command(DeskPort, "go\n"),
    %% the desk's word comes once the detector has given the store up
    prints(Desk, "now let the store run", ?WAIT_MS + ?DETECTOR_MS),
    _ = os:cmd("kill -CONT " ++ pid(Store)),
    says(Store, "the peer desk was lost"),
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

%% report §8.7, the proposal's sections 4 and 8: a network parted through
%% a proxy that drops what passes from the desk to the store: the store,
%% hearing nothing, gives the desk up within the detector's time and closes
%% the connection, so that the desk learns of the loss too, and what the
%% silence test holds of a loss holds; the proxy healed, the address reaches
%% its process again. A regression test, written after the code
parted_one_way_test_() ->
    nodes_test({waits, 8, ?DETECTOR_MS}, fun(Base) -> parted(Base, true, false, "closed") end).

%% report §8.7, the proposal's sections 4 and 8: the same, the proxy
%% dropping what passes both ways, so that each node gives the other up by
%% its own detector. A regression test, written after the code
parted_both_ways_test_() ->
    nodes_test({waits, 8, ?DETECTOR_MS},
               fun(Base) -> parted(Base, true, true, "fell silent") end).

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
    %% the desk's word comes once a detector has given a node up
    prints(Desk, "now let the store run", ?WAIT_MS + ?DETECTOR_MS),
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
    nodes_test({waits, 3, ?DIAL_MS}, fun dial/1).

dial(Base) ->
    {_, DeskProgram} = peers(Base),
    {_, Desk} = store_and_desk(Base),
    readdressed(Desk, <<"store">>, answers_nothing()),
    %% the desk ends once the host has given its dial up
    {Port, _} = started(Desk, DeskProgram, ["dial"]),
    ?assertEqual(0, ended(Port, ?WAIT_MS + ?DIAL_MS)),
    {Out, _} = said(Desk),
    {match, [Seconds]} = re:run(Out, "dialed: Left\\(Io\\.Unreachable\\) after ([0-9]+)",
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
           "    let loading = Peer.computeAt(bare, fn() = Code.load(Path(path)), waitMs());\n"
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
                              {Two, "tool.ern", [Tool, wait_ms_declaration()]}]],
    0 = built([One]),
    0 = built([Two]),
    {filename:join(One, "counter.erc"), filename:join(Two, "counter.erc"),
     filename:join(Two, "tool.erc")}.

%% report §6.10, §8.7, §3.11, §6.5, Appendix E.28: the upgrade tool of the
%% proposal's section 3. A node runs the first build's counters on `count`,
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
%% regression test of MVP 3.2's item 7, written after the code, and the
%% tool's add and then its call through that one address, from another
%% node, answering the total after the add, one of MVP 3.26's item 2b
%% (§6.4, §6.5): the counter's node applied each message in a process of
%% its own, and the call passed the add
code_upgrade_test_() ->
    nodes_test({waits, 13}, fun code_upgrade/1).

code_upgrade(Base) ->
    {CounterOne, CounterTwo, Tool} = upgraded_builds(Base),
    A = made(Base, "a", none),
    B = made(Base, "b", 0),
    C = made(Base, "c", 0),
    [lists(Dir, [{"a", A, none}]) || Dir <- [B, C]],
    {_, WaitB} = launched(B, [?ERN, " run --config-dir ", B, " --main Counter.serve ",
                              CounterOne]),
    prints(B, "serving"),
    PortB = bound_port(B),
    WaitC = bare_started(C, []),
    lists(A, [{"b", B, PortB}, {"c", C, bound_port(C)}]),
    edit(A, fun(Conf) -> Conf#{<<"services">> => #{<<"counter">> => [<<"b">>]}} end),
    {_, WaitA} = launched(A, [?ERN, " run --config-dir ", A, " ", Tool, " b c ", CounterTwo]),
    ?assertEqual(0, WaitA()),
    [prints(B, Line) || Line <- ["countAloud 5", "countAloud 11", "countAloud 21", "countAloud 9"]],
    stop(B, WaitB),
    stop(C, WaitC),
    {Out, _} = said(A),
    [has(Out, Line) || Line <- ["before: Some(4)", "moved 3, left 0", "after: Some(9)",
                                "before load: Io.NotLoaded", "load: Right(Right(Unit))",
                                "after load: Right"]].
