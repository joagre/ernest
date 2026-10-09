%% Nodes on one machine (report §8.7, MVP 3.0): each node an `ern run
%% --config-dir` of its own, started as a person starts one, its lines read
%% from its standard error. The carrier's tests dial through a `foreign fn`
%% of the host's, which reaches the carrier and nothing of a program's; the
%% frame a gateway cannot read is sent by a host module on the program's
%% load path. `Peer`'s tests run the programs of `test/peers/`, one build
%% whose store and desk are two nodes.
-module(ern_nodes_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ERN, filename:absname("../bin/ern")).
%% The libraries `test/peers/`'s programs use, on every node's load path, so
%% that every node runs one build.
-define(LIBRARIES, [filename:absname("../build/libs/" ++ Library)
                    || Library <- ["balancer", "json", "load"]]).

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

digest(Dir) ->
    hd(string:split(name(Dir), "@")).

%% The test program, built in Root: it dials a peer, sends it a frame its
%% gateway cannot read, or waits, as its arguments say.
program(Root) ->
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "node.ern"), <<"
foreign fn connect(node : Foreign.Term) : Bool with m = \"net_kernel:connect_node/1\"
foreign fn frame(node : Foreign.Term) : Unit with m = \"ern_nodes_frame:send/1\"

export fn main() : Unit with Unit =
    match Os.arguments {
        [\"connect\", peer] -> Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))))
      | [\"frame\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))));
            frame(Erl.atom(peer));
            // until the test, which has seen the connection end, says so
            let _ = Io.readLine();
            Unit
        }
      | [\"hold\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))));
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
-export([send/1]).
send(Node) ->
    erlang:send({ern_gateway, Node}, unreadable),
    erlang:send({ern_gateway, Node}, {ern_frame, self(), unreadable}),
    'Unit'.
">>),
    {ok, _} = compile:file(filename:join(Root, "ern_nodes_frame.erl"), [{outdir, Root}]),
    0 = ern_cli:ern(["build", Root], group_leader()),
    filename:join(Root, "node.erc").

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
    Watcher = watcher(Dir),
    [Out, Err] = [piped(Watcher, Stream, Dir ++ Suffix)
                  || {Stream, Suffix} <- [{out, ".out"}, {err, ".err"}]],
    Command = lists:flatten([?ERN, " run --config-dir ", Dir,
                             [[" --load-path ", Library] || Library <- ?LIBRARIES], " ", Program,
                             [[" ", Argument] || Argument <- Arguments],
                             " > ", Out, " 2> ", Err]),
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
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(143, Wait()).

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
%% says so naming the other; a node that ends is lost to the other, which
%% says it closed; and the host's own reports of its nodes are not written
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
    says(B, "the peer a was lost: it closed"),
    stop(B, WaitB),
    {OutA, ErrA} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: true"),
    has(ErrA, "the peer b connected"),
    has(ErrB, "the peer a connected"),
    has(ErrB, "the peer a was lost: it closed"),
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

%% report §8.7: two nodes of different builds fail the handshake with
%% nothing sent, the build's fingerprint being the host's cookie, and the
%% node that refused says so in its own words
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
    says(B, "it runs another build"),
    stop(B, WaitB),
    {OutA, _} = said(A),
    {_, ErrB} = said(B),
    has(OutA, "connect: false"),
    has(ErrB, "the peer a was refused: it runs another build"),
    ?assertEqual(nomatch, string:find(ErrB, "**")).

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
              <<"doomed">>],
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
%% another node's process and an offer under a key a living process holds
%% fault; a lost connection gives a monitor Unreachable with an empty site,
%% a find after it Unreachable, and a callForever on its process faults
%% with the callee unreachable
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
    {Out, _} = said(Desk),
    {StoreOut, _} = said(Store),
    has(StoreOut, "the store's peers: [\"desk\", \"third\"]"),
    [has(Out, Line)
     || Line <- ["early: Left(Unreachable)", "nodes: [\"store\", \"gone\"]", "info: None",
                 "unlisted: Left(NotListed)", "other type: Left(OtherType)",
                 "not offered: Left(NotOffered)", "unreachable: Left(Unreachable)",
                 "timeout: Left(Timeout)", "no upper bound: Right", "through the via: 7",
                 "killed: Killed \"\"",
                 "another node's: Fault(\"a node offers only its own processes\")",
                 "twice: Fault(\"twice is offered by a living process\")",
                 "lost: Unreachable \"\"", "after the loss: Left(Unreachable)",
                 "call forever: Fault(\"callee is unreachable\")"]].

%% report §8.7, §6.7, Appendix E.27, §8.2: work on a peer is a process
%% spawned at the node the program names, whose spawn answers its address or
%% a failure within the time; a function of a module the store has
%% whole spawns there with what it captured, writing to the store's
%% standard output; a name that is no peer's is NotListed; a function of a
%% module whose binding has no value on the store is NotLoaded, and so is
%% one of a module that depends on such a module, the rule being by module;
%% a top-level binding in spawned code is the peer's; a monitored spawn is
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
    {StoreOut, _} = said(Store),
    [has(Out, Line)
     || Line <- ["spawn: Right", "not listed: NotListed", "not loaded: NotLoaded",
                 "by module: NotLoaded", "bindings: Right", "monitored: Returned",
                 "late: Timeout", "no upper bound: Right"]],
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
%% Unknown. A regression test: the runtime hands each to the host, and
%% this holds that it does. Not covered: a value crossing in pieces with
%% other senders' messages between them, a send that waits at a full
%% buffer, and a silence, which the detector finds in a minute
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
                 "old monitor: Unknown \"\"", "same process: false", "fresh total: 0"]],
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

%% report §8.7, §11.2, Appendix E.23, G.6: a program's own test of two
%% nodes, `ern test --config-dir a` as a node. The harness makes two
%% directories as `ern config` makes them, `a` listening and listing `b`
%% under the key `pair`, and says in `pair.json` the port `b` listens on and
%% the load path `a` runs with; the test, in Ernest, writes `b`'s
%% `ernest.conf` listing `a`, starts `b` with `Os` on the same build, finds
%% and calls what it offers, and ends it with `ern stop`. A regression test,
%% written after the code; it does not cover a reload, whose end a program
%% cannot see (§8.7: the signal carries nothing back)
program_test_() ->
    nodes_test(90, fun pair_program/1).

pair_program(Base) ->
    _ = peers(Base),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", none),
    lists(A, [{"b", B, PortB}]),
    edit(A, fun(Conf) -> Conf#{<<"keys">> => #{<<"pair">> => [<<"b">>]}} end),
    Settings = #{<<"port">> => PortB,
                 <<"load-path">> => [list_to_binary(Library) || Library <- ?LIBRARIES]},
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
    ?assertNot(filelib:is_regular(filename:join(B, "ernest.pid"))).

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
