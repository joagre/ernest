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

tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_nodes_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

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

export fn main() : Unit with Never =
    match Os.arguments {
        [\"connect\", peer] -> Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))))
      | [\"frame\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))));
            frame(Erl.atom(peer));
            wait(2000)
        }
      | [\"hold\", peer] -> {
            Io.println(\"connect: \" <> Io.show(connect(Erl.atom(peer))));
            wait(60000)
        }
      | _ -> wait(60000)
    }

fn wait(ms : Int) : Unit with Never = receive { after ms -> Unit }
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

%% A node started in the background, its standard output and standard error
%% in files beside its directory; answers what waits for its end.
start(Dir, Program, Arguments) ->
    Out = Dir ++ ".out",
    Err = Dir ++ ".err",
    Command = lists:flatten([?ERN, " run --config-dir ", Dir, " ", Program,
                             [[" ", Argument] || Argument <- Arguments],
                             " > ", Out, " 2> ", Err]),
    Port = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status]),
    fun() ->
        receive {Port, {exit_status, Status}} -> Status after 30000 -> timeout end
    end.

%% Until the loopback's port answers, as a node's listener does once its
%% bindings have their values.
listening(Port) ->
    listening(Port, inet, 200).

listening(Port, Family, Tries) ->
    Address = case Family of inet -> {127, 0, 0, 1}; inet6 -> {0, 0, 0, 0, 0, 0, 0, 1} end,
    case gen_tcp:connect(Address, Port, [Family], 100) of
        {ok, Socket} -> gen_tcp:close(Socket);
        {error, _} when Tries > 0 -> timer:sleep(100), listening(Port, Family, Tries - 1)
    end.

%% Until the node's standard error holds Part.
says(Dir, Part) ->
    says(Dir, Part, 200).

says(Dir, Part, Tries) ->
    case file:read_file(Dir ++ ".err") of
        {ok, Err} when Tries > 0 ->
            case string:find(Err, Part) of
                nomatch -> timer:sleep(100), says(Dir, Part, Tries - 1);
                _ -> ok
            end;
        _ when Tries > 0 ->
            timer:sleep(100), says(Dir, Part, Tries - 1)
    end.

%% Until the node's standard output holds Part.
prints(Dir, Part) ->
    prints(Dir, Part, 300).

prints(Dir, Part, Tries) ->
    Out = case file:read_file(Dir ++ ".out") of
              {ok, Bytes} -> Bytes;
              {error, _} -> <<>>
          end,
    case string:find(Out, Part) of
        nomatch when Tries > 0 -> timer:sleep(100), prints(Dir, Part, Tries - 1);
        _ -> ok
    end.

%% Until the node has written its ernest.pid, which it does as it starts.
running(Dir, Tries) ->
    case filelib:is_file(filename:join(Dir, "ernest.pid")) of
        true -> ok;
        false when Tries > 0 -> timer:sleep(100), running(Dir, Tries - 1)
    end.

%% A waiting node ended by termination, which ends it with 128 and the
%% signal's number (report §11.2).
stop(Dir, Wait) ->
    {ok, Pid} = file:read_file(filename:join(Dir, "ernest.pid")),
    _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
    ?assertEqual(143, Wait()).

said(Dir) ->
    {ok, Out} = file:read_file(Dir ++ ".out"),
    {ok, Err} = file:read_file(Dir ++ ".err"),
    {binary_to_list(Out), binary_to_list(Err)}.

has(Text, Part) ->
    ?assertNotEqual(nomatch, string:find(Text, Part)).

%% report §8.7: two nodes that list each other connect over TLS with a
%% certificate on each side, by the first operation that needs it, and each
%% says so naming the other; a node that ends is lost to the other, which
%% says it closed; and the host's own reports of its nodes are not written
connect_test_() ->
    {timeout, 60, fun connect/0}.

connect() ->
    Base = tmp(),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    listening(PortB),
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
    {timeout, 60, fun unlisted/0}.

unlisted() ->
    Base = tmp(),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    listening(PortB),
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
    {timeout, 60, fun other_build/0}.

other_build() ->
    Base = tmp(),
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
    listening(PortB),
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
    {timeout, 60, fun replaced/0}.

replaced() ->
    Base = tmp(),
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
    listening(PortB),
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
    {timeout, 60, fun listening/0}.

listening() ->
    Base = tmp(),
    PortB = free_port(),
    A = made(Base, "a", none),
    B = made(Base, "b", PortB),
    Z = made(Base, "z", 0),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, none}]),
    Program = program(filename:join(Base, "build")),
    WaitZ = start(Z, Program, []),
    WaitB = start(B, Program, []),
    listening(PortB),
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
    {timeout, 60, fun faulty_frame/0}.

faulty_frame() ->
    Base = tmp(),
    {PortA, PortB} = {free_port(), free_port()},
    A = made(Base, "a", PortA),
    B = made(Base, "b", PortB),
    lists(A, [{"b", B, PortB}]),
    lists(B, [{"a", A, PortA}]),
    Program = program(filename:join(Base, "build")),
    WaitB = start(B, Program, []),
    listening(PortB),
    WaitA = start(A, Program, ["frame", name(B)]),
    ?assertEqual(0, WaitA()),
    says(B, "its connection was ended"),
    stop(B, WaitB),
    {_, ErrA} = said(A),
    {_, ErrB} = said(B),
    has(ErrB, "a frame that names no peer's process came to the gateway, and was dropped"),
    has(ErrB, "the peer a sent a frame this node cannot read, and its connection was ended"),
    has(ErrA, "the peer b was lost: it closed").

%% report §8.7: a node runs over its listener's family of addresses, IPv6
%% where `listen` names an address of it, its peers' addresses of the same
ipv6_test_() ->
    {timeout, 60, fun ipv6/0}.

ipv6() ->
    Base = tmp(),
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
    listening(PortB, inet6, 200),
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
    {timeout, 60, fun os_exit/0}.

os_exit() ->
    Base = tmp(),
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
refused_configuration_test() ->
    Base = tmp(),
    A = made(Base, "a", none),
    edit(A, fun(Conf) -> Conf#{<<"peers">> => #{}} end),
    Program = program(filename:join(Base, "build")),
    Said = os:cmd(?ERN ++ " run --config-dir " ++ A ++ " " ++ Program ++ " 2>&1; echo status $?"),
    has(Said, "ern run: " ++ filename:join(A, "ernest.conf") ++ ": peers is not a JSON array"),
    has(Said, "status 1").

%% report §8.6: a node detects no deadlock, since it can be reached from
%% outside: a node that waits for a message that never comes waits, where
%% the same program run as no node faults; termination ends it. That the
%% node does not fault is shown by its waiting three times as long as the
%% program took to fault as no node, the one wait here a time, since an
%% absence shows itself by nothing else
no_deadlock_test_() ->
    {timeout, 60, fun no_deadlock/0}.

no_deadlock() ->
    Base = tmp(),
    A = made(Base, "a", none),
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "waits.ern"),
                         "export fn main() : Unit with Int = receive { n -> Unit }\n"),
    0 = ern_cli:ern(["build", Root], group_leader()),
    Program = filename:join(Root, "waits.erc"),
    {Micros, Plain} = timer:tc(fun() -> os:cmd(?ERN ++ " run " ++ Program ++ " 2>&1") end),
    has(Plain, "deadlock"),
    Wait = start(A, Program, []),
    running(A, 200),
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

%% The programs of test/peers/, one build: the store's and the desk's.
peers(Base) ->
    Root = filename:join(Base, "build"),
    0 = ern_cli:ern(["build", "--build-root", Root, "peers"], group_leader()),
    {filename:join(Root, "store.erc"), filename:join(Root, "desk.erc")}.

%% A store that listens, a desk that dials it, and a peer the desk lists,
%% gone, whose port nothing holds; the desk's keys, each a name's peers in
%% the order a find asks them.
store_and_desk(Base) ->
    {PortStore, PortGone} = {free_port(), free_port()},
    Store = made(Base, "store", PortStore),
    Desk = made(Base, "desk", none),
    Gone = made(Base, "gone", none),
    lists(Store, [{"desk", Desk, none}]),
    lists(Desk, [{"store", Store, PortStore}, {"gone", Gone, PortGone}]),
    edit(Desk, fun(Conf) ->
                   Conf#{<<"keys">> => #{<<"counter">> => [<<"gone">>, <<"store">>],
                                         <<"adder">> => [<<"store">>],
                                         <<"victim">> => [<<"store">>],
                                         <<"nothing">> => [<<"store">>],
                                         <<"lost">> => [<<"gone">>]}}
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
    {timeout, 90, fun find/0}.

find() ->
    Base = tmp(),
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
    has(StoreOut, "the store's peers: [\"desk\"]"),
    [has(Out, Line)
     || Line <- ["early: Left(Unreachable)", "nodes: [\"store\", \"gone\"]", "info: None",
                 "unlisted: Left(NotListed)", "other type: Left(OtherType)",
                 "not offered: Left(NotOffered)", "unreachable: Left(Unreachable)",
                 "timeout: Left(Timeout)", "through the via: 7", "killed: Killed \"\"",
                 "another node's: Fault(\"a node offers only its own processes\")",
                 "twice: Fault(\"twice is offered by a living process\")",
                 "lost: Unreachable \"\"", "after the loss: Left(Unreachable)",
                 "call forever: Fault(\"callee is unreachable\")"]].

%% report §8.7, Appendix E.27, §8.2: a function of a module the store has
%% whole spawns there with what it captured, writing to the store's
%% standard output; a name that is no peer's is NotListed; a function of a
%% module whose binding has no value on the store is NotLoaded, and so is
%% one of a module that depends on such a module, the rule being by module;
%% a top-level binding in spawned code is the peer's; a monitored spawn is
%% monitored from its start; a spawn given no time answers Timeout
spawn_test_() ->
    {timeout, 90, fun spawn_on_peer/0}.

spawn_on_peer() ->
    Base = tmp(),
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
                 "late: Timeout"]],
    has(StoreOut, "the store squares 49"),
    has(StoreOut, "the peers here: [\"desk\"]"),
    ?assertEqual(nomatch, string:find(StoreOut, "never initialized")).
