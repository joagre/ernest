%% The harness of the tests that run real nodes, shells and programs: each
%% node an `ern run --config-dir` of its own, started as a person starts
%% one, its lines read from its standard error and its standard output by a
%% watcher registered under its directory (report §8.7, §11.2, §12.5); the
%% configuration directories and their peers (report Appendix C); the
%% steps a test counts, each wait the harness runs taking one as it runs
%% (step/1), and the harness's time for one wait, which bounds a step
%% (wait_ms/0). The tests of nodes (ern_nodes_tests), of the deployment
%% guide, the tour, the guide, the integration, the shell, the terminal and
%% the machines run through it.
-module(ern_harness).

-include_lib("stdlib/include/assert.hrl").

-export([nodes_test/2, counted_test/2, counted_test/3, step/1, step/2, counting/0, free_port/0,
         made/3, address/1, edit/2, configuration/1, public/1, lists/2, peer/3, name/1, digest/1,
         program/1, built/1, wait_ms_declaration/0, wait_ms_text/0, client/0, client/7, client/8,
         key_files/1, forged/2, host/1, start/3, started/3, shell_started/2, shell_started/3,
         bare_started/2, bound_port/1, launched/2, ended/2, says/2, says/3, prints/2, prints/3,
         prints/4, seen/5, stop/2, terminated/1, fault_line/3, written/2, said/1, wait_ms/0,
         detector_ms/0, has/2, connected/2, accepted/1, received/2, unread_writer/1,
         read_to_its_end/1, run_signaled/2, collected/2, closed/1]).

%% What waits for a node's end: its status, or `timeout` where it has not
%% ended within the harness's time for one wait.
-type wait() :: fun(() -> integer() | timeout).

-define(ERN, filename:absname("../bin/ern")).
%% The block free_port/0 takes from, ending where Linux's default ephemeral
%% range begins, whose macOS counterpart begins higher.
-define(FIRST_PORT, 16384).
-define(PORTS, 16384).
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
%% Report §12.6: the detector finds a silent peer at most 75 seconds after
%% its last traffic.
-define(DETECTOR_MS, 75000).

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

%% The count of the test the calling process runs, {Count, Taken}, or
%% undefined where it runs none, a test's that ended among them.
-spec counting() -> {pos_integer(), non_neg_integer()} | undefined.
counting() ->
    get(?STEPS).

%% Report §8.6, a node detecting no deadlock: each node whose ernest.pid is
%% still in a directory under Base killed, a stopped one among them. A test
%% that passed has stopped its nodes, and the file of one a test killed is
%% gone with it (report §12.5).
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

%% The node's public key, as `ern config` prints it for a directory that
%% exists.
-spec public(file:filename()) -> binary().
public(Dir) ->
    ern_node:create(Dir, none).

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
-spec digest(file:filename()) -> string().
digest(Dir) ->
    [{_, Der, _}] = public_key:pem_decode(public(Dir)),
    binary_to_list(binary:encode_hex(crypto:hash(sha256, Der), lowercase)).

%% The test program, built in Root: it dials a peer, sends it a frame its
%% gateway cannot read, sends it a spawn of the function whose hash it is
%% given with a site that is not UTF-8, sends it a find whose alias is of
%% another node, asks how busy a peer is, or waits, as its arguments say.
-spec program(file:filename()) -> file:filename().
program(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "node.ern"), [<<"
foreign fn connect(node : Foreign.Term) : Bool = \"net_kernel:connect_node/1\"
foreign fn frame(node : Foreign.Term) : Unit = \"ern_nodes_frame:send/1\"
foreign fn site(node : Foreign.Term, hash : String) : Unit = \"ern_nodes_frame:site/2\"
foreign fn elsewhere(node : Foreign.Term) : Unit = \"ern_nodes_frame:elsewhere/1\"

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
      | [\"elsewhere\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Foreign.atom(peer))));
            elsewhere(Foreign.atom(peer));
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
-export([send/1, site/2, elsewhere/1]).
send(Node) ->
    erlang:send({ern_gateway, Node}, unreadable),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), unreadable}),
    'Unit'.
site(Node, Hash) ->
    Spawned = {function, binary:decode_hex(Hash)},
    %% the site alone out of shape, the spawner waiting nothing
    Frame = {spawn, make_ref(), Spawned, <<255>>, false, 0},
    erlang:send({ern_gateway, Node}, {ern_frame, self(), Frame}),
    'Unit'.
elsewhere(Node) ->
    %% the alias alone out of shape, a reference of a node no peer lists
    Alias = binary_to_term(<<131, 90, 1:16, 119, 13, \"other@node.er\", 1:32, 1:32>>),
    Frame = {find, <<\"sink\">>, <<0:256>>, Alias},
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
-spec wait_ms_declaration() -> iolist().
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
-spec client(file:filename(), string(), {file:filename(), file:filename()}, string(),
             inet:port_number(), string(), boolean()) ->
          {port(), fun(() -> {integer(), binary()})}.
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
-spec forged(file:filename(), string()) -> {file:filename(), file:filename()}.
forged(Dir, Host) ->
    File = Dir ++ ".forged.pem",
    ok = file:write_file(File, public_key:pem_encode([{'Certificate',
                                                        ern_helpers:forged_certificate(Dir, Host),
                                                        not_encrypted}])),
    {File, filename:join(Dir, "private-key.pem")}.

%% A node's key's host on the carrier.
-spec host(file:filename()) -> string().
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
-spec started(file:filename(), file:filename(), [string()]) -> {port(), wait()}.
started(Dir, Program, Arguments) ->
    launched(Dir, [?ERN, " run --config-dir ", Dir, " ", Program,
                   [[" ", Argument] || Argument <- Arguments]]).

%% A shell that is a node, its source root SourceRoot, reading its inputs
%% from the port's writes, in line mode; its HOME a directory of its own,
%% so that no person's startup file runs. Its load path is LoadPath's
%% directories, a build among them, which a node reads whole at its start.
-spec shell_started(file:filename(), file:filename()) -> {port(), wait()}.
shell_started(Dir, SourceRoot) ->
    shell_started(Dir, SourceRoot, []).

-spec shell_started(file:filename(), file:filename(), [file:filename()]) ->
          {port(), wait()}.
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
-spec ended(port(), timeout()) -> integer() | timeout.
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
    list_to_atom("ern_harness " ++ Dir).

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

-spec prints(file:filename(), string(), timeout()) -> ok.
prints(Dir, Part, Ms) ->
    prints(Dir, Part, 1, Ms).

-spec prints(file:filename(), string(), pos_integer(), timeout()) -> ok.
prints(Dir, Part, Count, Ms) ->
    seen(Dir, out, Part, Count, Ms).

%% One step, the wait for a line.
-spec seen(file:filename(), out | err, string(), pos_integer(), timeout()) -> ok.
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
-spec terminated(file:filename()) -> ok.
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
-spec fault_line(port(), file:filename(), string()) -> ok.
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
%% step. The helper that holds a node's lock keeps the node's standard error
%% until it has removed the node's ernest.pid and ended (report §12.5), so
%% that a node's file is gone once said/1 returns, and once finished/1 does
%% for a command that sends the node's standard error to its output.
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

%% Whether Text holds Part; a failure names the part it missed and the
%% text it read.
-spec has(string(), string()) -> ok.
has(Text, Part) ->
    case string:find(Text, Part) of
        nomatch -> erlang:error({not_held, Part, Text});
        _ -> ok
    end.

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

%% Report Appendix E.18: a program that listens on the port of the loopback
%% interface the system gives it, which it prints as `listening on
%% 127.0.0.1:port`, takes one connection, waits for a line, writes the
%% megabytes its argument gives to the socket, says what the write
%% answered, and ends with the connection open, built in Root: one step.
%% Answers its compiled form.
-spec unread_writer(file:filename()) -> file:filename().
unread_writer(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "unread_writer.ern"), [<<"
// Report Appendix E.18: a program that writes the megabytes it is given to
// the one connection it takes, once a line comes, and ends with the
// connection open.

export fn main() : Unit =
    match Os.arguments {
        [megabytes] ->
            Io.println(\"served: \"
                           <> Io.show(served(Optional.withDefault(String.toInt(megabytes), 0))))
      | _ ->
            Unit
    }

fn served(megabytes : Int) : Either(Io.Error, Unit) = {
    let listener <- Tcp.listen(\"127.0.0.1\", 0);
    let port <- Tcp.port(listener);
    Io.println(\"listening on 127.0.0.1:\" <> Int.toString(port));
    let socket <- Tcp.accept(listener, waitMs());
    Io.println(\"accepted\");
    let _ = Io.readLine();
    let _ <- Tcp.write(socket, Bytes.repeat(<<120>>, megabytes * 1048576), waitMs());
    Right(Unit)
}
"/utf8>>, wait_ms_declaration()]),
    0 = built([Root]),
    filename:join(Root, "unread_writer.erc").

%% What a passive socket takes until its connection ends, read as it comes,
%% each read given the harness's time for one wait: the count of its bytes
%% and the reason the reads ended. One step.
-spec read_to_its_end(gen_tcp:socket()) -> {non_neg_integer(), term()}.
read_to_its_end(Socket) ->
    step({read_to_its_end, Socket}),
    read_to_its_end(Socket, 0).

read_to_its_end(Socket, Taken) ->
    case gen_tcp:recv(Socket, 0, ?WAIT_MS) of
        {ok, Bytes} -> read_to_its_end(Socket, Taken + byte_size(Bytes));
        {error, Reason} -> {Taken, Reason}
    end.

%% Whether the signal Name was sent to the run its port started, which is
%% the port's own process; none is sent to a run whose port has ended.
-spec run_signaled(port(), string()) -> boolean().
run_signaled(Run, Name) ->
    case erlang:port_info(Run, os_pid) of
        {os_pid, Number} -> os:cmd("kill -" ++ Name ++ " " ++ integer_to_list(Number)) =:= "";
        undefined -> false
    end.

%% A port's output to its end, and its exit status, within Steps steps,
%% each given the harness's time for one wait: one, or a run's own steps,
%% which the harness cannot see. The port is opened with `binary` and
%% `exit_status`; one that has not ended by then is closed with what it
%% started (closed/1) and fails the test, naming what it wrote.
-spec collected(port(), pos_integer()) -> {integer(), binary()}.
collected(Port, Steps) ->
    step({collected, Port}, Steps),
    collected(Port, <<>>, erlang:monotonic_time(millisecond) + Steps * ?WAIT_MS).

collected(Port, Acc, Deadline) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, <<Acc/binary, Bytes/binary>>, Deadline);
        {Port, {exit_status, Status}} -> {Status, Acc}
    after max(Deadline - erlang:monotonic_time(millisecond), 0) ->
        closed(Port),
        erlang:error({still_running, Port, Acc})
    end.

%% A port the test opened closed, its process killed first with each process
%% of its group, which the host makes for that process alone: closing the
%% port alone leaves a command that does not read its input running past
%% its test and the run. The kill can close the port first, as its process
%% ends. A node leaves the group, and is the test's cleanup's (killed/1).
-spec closed(port()) -> ok.
closed(Port) ->
    case erlang:port_info(Port, os_pid) of
        {os_pid, Number} -> _ = os:cmd("kill -KILL -" ++ integer_to_list(Number));
        undefined -> ok
    end,
    try port_close(Port) catch error:badarg -> true end,
    ok.
