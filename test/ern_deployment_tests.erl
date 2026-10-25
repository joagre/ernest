%% The deployment guide, guide/deployment.md, run as its reader runs it
%% (plan, MVP 3.2's item 9): its section 8, a deployment end to end, on
%% real nodes, each command as its consoles write it, run from the
%% directory their paths are relative to; the commands of its sections
%% 1.1, 1.3 and 5.3, the harness's paths in place of the guide's; section
%% 1.4's statuses; and the lines its sections 7 and 4.3 quote, each held to
%% the line a node writes where a test provokes it, here or in
%% ern_nodes_tests, by cataloged/4, which catalog_test sees every quoted
%% line has. The nodes are started by ern_nodes_tests' harness, which reads
%% each node's streams through a watcher of its own and kills every node
%% still running when a test ends. Regression tests, written after the
%% guide and the code; each says what it does not cover.
-module(ern_deployment_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

-export([cataloged/4, job/2, keyed/1, listens/2]).

-define(ERN, filename:absname("../bin/ern")).
-define(GUIDE, "../guide/deployment.md").
%% The program the guide's sections 1.3, 5.3 and 8 build and run, its two
%% builds, `v1` and `v2`, one module.
-define(EXAMPLE, "../examples/upgrade").
%% The modules whose tests provoke the lines the guide quotes.
-define(PROVOKING, ["ern_deployment_tests.erl", "ern_nodes_tests.erl"]).

%%
%% Section 8, a deployment end to end
%%

%% guide/deployment.md, section 8; report §8.7, §11.2, §11.3, §11.8: three
%% directories made, each printing its key; the counters of the example's
%% first build built and started on b and c, which say nothing until a peer
%% connects; a shell beside them, from ops, whose compute lists b's
%% processes, the counter's among them with its site in Counter.serve, b
%% saying that ops connected; b reloaded with a peer added, which it says;
%% the second build built and its tool run on a, which prints the lines the
%% console shows, the peers' in the order they answer, each moved though it
%% lacked the new loop, ends with status 0, and connects to b and c, each
%% saying so and saying that a ended; and b and c stopped, each saying nothing of a wait, ending
%% with status 143, and the shell saying that b ended. The guide's
%% directories are relative, and the test runs the commands from the
%% directory that holds them, the ports the harness's. It does not cover
%% the counters' totals after the move, nor a shell's monitor at b's stop.
%% Its limit is the sum of its twenty-eight waits, each bounded by the
%% harness's time for one wait: ten jobs, two ports that answer, nine
%% lines, four ends, the tool's, the two nodes' and the shell's, and what
%% three nodes said
runbook_test_() ->
    ern_nodes_tests:nodes_test({waits, 28}, fun runbook/1).

runbook(Base) ->
    [Directories, Started, Reloaded, Moved, Stopped] = consoles("## 8."),
    [Inputs] = [[Input || "> " ++ Input <- Lines] || {"## 8." ++ _, "", Lines} <- blocks()],
    ok = copied(Base),
    %% the shell's directory is made as the others are, which the step says
    %% and its console does not show
    [] = ran(Base, Directories ++ [{"config --config-dir ops", []}]),
    [A, B, C, Ops] = [filename:join(Base, Name) || Name <- ["a", "b", "c", "ops"]],
    [PortA, PortB, PortC] = [ern_nodes_tests:free_port() || _ <- [a, b, c]],
    [listening(Dir, Port) || {Dir, Port} <- [{A, PortA}, {B, PortB}, {C, PortC}]],
    %% a shell need not listen, and one machine's nodes cannot share a port
    ern_nodes_tests:edit(Ops, fun(Conf) -> maps:remove(<<"listen">>, Conf) end),
    ern_nodes_tests:lists(A, [{"b", B, PortB}, {"c", C, PortC}]),
    [ern_nodes_tests:lists(Dir, [{"a", A, none}, {"ops", Ops, none}]) || Dir <- [B, C]],
    ern_nodes_tests:lists(Ops, [{"b", B, PortB}, {"c", C, PortC}]),
    [{B, WaitB}, {C, WaitC}] = ran(Base, Started),
    [listens(Dir, Port) || {Dir, Port} <- [{B, PortB}, {C, PortC}]],
    %% the check from a shell, its file none, since a file's main would run
    Home = Ops ++ ".home",
    ok = filelib:ensure_path(Home),
    {Shell, WaitShell} = ern_nodes_tests:launched(Ops, ["cd ", Base, " && HOME=", Home, " ",
                                                        ?ERN, " shell --config-dir ops"]),
    true = port_command(Shell, [[Input, "\n"] || Input <- Inputs]),
    ern_nodes_tests:prints(Ops, ") : Either(Io.Error, List(Process))"),
    ern_nodes_tests:has(ern_nodes_tests:written(Ops, out), "Right([<process "),
    ern_nodes_tests:says(B, "the peer ops connected"),
    %% the compute given the harness's time for one wait, the step it is of
    true = port_command(Shell, ["Peer.computeAt(\"b\", fn() = List.map(Process.live(),"
                                " Process.status), ",
                                integer_to_list(ern_nodes_tests:wait_ms()), ")\n"]),
    ern_nodes_tests:prints(Ops, "Some(Status(site = \"Counter.serve\""),
    %% a peer added to b's file, and the reload
    [] = ran(Base, [{"config --config-dir d", []}]),
    ern_nodes_tests:lists(B, [{"a", A, none}, {"ops", Ops, none},
                              {"d", filename:join(Base, "d"), none}]),
    [] = ran(Base, Reloaded),
    ern_nodes_tests:says(B, "the peer d was added"),
    Reload = ern_nodes_tests:written(B, err),
    ern_nodes_tests:has(Reload, "ernest.conf was read again"),
    ?assertEqual(nomatch, string:find(Reload, "the peer d connected")),
    %% the counters moved by the tool on a, which ends with status 0
    [] = ran(Base, Moved),
    [ern_nodes_tests:says(Dir, Line)
     || Dir <- [B, C], Line <- ["the peer a connected", "the peer a ended"]],
    %% the stop in order
    [] = ran(Base, Stopped),
    ?assertEqual(143, WaitB()),
    ?assertEqual(143, WaitC()),
    ern_nodes_tests:prints(Ops, "the peer b ended"),
    true = port_command(Shell, ":quit\n"),
    ?assertEqual(0, WaitShell()),
    {_, ErrB} = ern_nodes_tests:said(B),
    {_, ErrC} = ern_nodes_tests:said(C),
    [?assertEqual(nomatch, string:find(Err, "the end waits for")) || Err <- [ErrB, ErrC]],
    [?assertNot(filelib:is_file(filename:join(Dir, "ernest.pid"))) || Dir <- [B, C]],
    %% each said where it listens, then nothing before a peer connected
    ?assertMatch({match, _}, re:run(ErrB, "\\A[^\n]* listening on [^\n]*\n"
                                          "[^\n]* the peer ops connected\n")),
    ?assertMatch({match, _}, re:run(ErrC, "\\A[^\n]* listening on [^\n]*\n"
                                          "[^\n]* the peer a connected\n")),
    %% the lines as the guide's section 7 quotes them
    cataloged(ErrB, "7", "connected", [{"b", "ops"}]),
    cataloged(ErrB, "7", "ended", [{"b", "a"}]),
    cataloged(Reload, "7", "was read again", []),
    cataloged(Reload, "7", "was added", [{"b", "d"}]).

%%
%% Section 1, one node
%%

%% guide/deployment.md, sections 1.1 and 1.3; report §8.7, §11.2, §11.3:
%% `ern config` makes the directory, its owner's alone, its key readable by
%% its owner alone, a certificate and an `ernest.conf` that listens on
%% 0.0.0.0:8654 and lists no peer and no service, and prints the key as the
%% console shows it; it fails where the directory exists, empty or not; a
%% node that lists its own key as a peer's is refused; the node starts as
%% the console starts it, and a second start from its directory is
%% refused; `ern reload` reads the file again, a peer added and a changed
%% `listen` refused, the configuration kept; `ern stop` returns once the
%% node has ended by termination; and `ern stop` and `ern reload` fail
%% where no node runs, the file gone or held by none. The guide's paths
%% are the harness's, and its counter the example's first build. It does
%% not cover `kill -HUP`, a second `ern stop` while the first waits, which
%% ern_nodes_tests' stop_waits covers, nor a directory another user owns
%% or may write. Its limit is the sum of its twenty waits, each bounded by
%% the harness's time for one wait: thirteen jobs, two ports that answer,
%% two lines, two nodes' ends and what the first said; written on
%% 2026-10-16, after its limit of 120 s, a number of its own, ran out under
%% the full run's load on 2026-10-13.
one_node_test_() ->
    ern_nodes_tests:nodes_test({waits, 20}, fun one_node/1).

one_node(Base) ->
    [[{Config, Key}]] = consoles("### 1.1"),
    [[{Run, []}]] = consoles("### 1.3"),
    Dir = filename:join(Base, "b"),
    PidFile = filename:join(Dir, "ernest.pid"),
    ok = copied(Base),
    ?assertEqual({0, "", ""}, job(Base, "build upgrade/v1")),
    Paths = [{"/etc/counter/b", Dir},
             {"/srv/counter/build/counter.erc", filename:join(Base, "upgrade/v1/counter.erc")}],
    %% the directory
    [] = ran(Base, [{mapped(Config, Paths), Key}]),
    ?assertEqual(8#700, mode(Dir)),
    ?assertEqual(8#600, mode(filename:join(Dir, "private-key.pem"))),
    ?assert(filelib:is_regular(filename:join(Dir, "certificate.pem"))),
    #{<<"listen">> := Listen, <<"peers">> := Peers, <<"services">> := Services} =
        ern_nodes_tests:configuration(Dir),
    ?assertEqual({<<"0.0.0.0:8654">>, [], #{}}, {Listen, Peers, Services}),
    Empty = filename:join(Base, "empty"),
    ok = file:make_dir(Empty),
    [begin
         {1, "", Exists} = job(Base, mapped(Config, [{"/etc/counter/b", Existing}])),
         ern_nodes_tests:has(Exists, Existing ++ " exists")
     end || Existing <- [Dir, Empty]],
    %% its own key as a peer's
    Port = ern_nodes_tests:free_port(),
    ern_nodes_tests:edit(Dir, fun(#{<<"public-key">> := Own} = Conf) ->
                                  Conf#{<<"listen">> := ern_nodes_tests:address(Port),
                                        <<"peers">> := [#{<<"name">> => <<"self">>,
                                                          <<"public-key">> => Own}]}
                              end),
    {1, "", OwnKey} = job(Base, mapped(Run, Paths)),
    ern_nodes_tests:edit(Dir, fun(Conf) -> Conf#{<<"peers">> := []} end),
    %% the start, and a second start from the directory
    {_, Wait} = node(Base, mapped(Run, Paths)),
    listens(Dir, Port),
    {ok, Number} = file:read_file(PidFile),
    {1, "", Held} = job(Base, mapped(Run, Paths)),
    %% a reload with a peer added, and one that changes `listen`
    Peer = ern_nodes_tests:made(Base, "p", none),
    ern_nodes_tests:lists(Dir, [{"p", Peer, none}]),
    ?assertEqual({0, "", ""}, job(Base, "reload --config-dir " ++ Dir)),
    ern_nodes_tests:says(Dir, "the peer p was added"),
    listening(Dir, ern_nodes_tests:free_port()),
    ?assertEqual({0, "", ""}, job(Base, "reload --config-dir " ++ Dir)),
    ern_nodes_tests:says(Dir, "the reload was refused"),
    listening(Dir, Port),
    %% the stop, and the jobs with no node
    ?assertEqual({0, "", ""}, job(Base, "stop --config-dir " ++ Dir)),
    ?assertEqual(143, Wait()),
    ?assertNot(filelib:is_file(PidFile)),
    {_, Err} = ern_nodes_tests:said(Dir),
    ern_nodes_tests:has(Err, "ernest.conf was read again"),
    Gone = [no_node(Base, Job, Dir) || Job <- ["stop", "reload"]],
    {_, Killed} = node(Base, mapped(Run, Paths)),
    listens(Dir, Port),
    {ok, Last} = file:read_file(PidFile),
    "" = os:cmd("kill -KILL " ++ string:trim(binary_to_list(Last))),
    ?assertEqual(137, Killed()),
    ?assert(filelib:is_file(PidFile)),
    [Stale, _] = [no_node(Base, Job, Dir) || Job <- ["stop", "reload"]],
    [ern_nodes_tests:has(Said, "no node runs from the directory") || Said <- Gone],
    %% the lines as the guide quotes them, the refusal of its own key in
    %% section 1.1 and the rest in the catalog, which section 1.3 quotes
    %% again; a job names the directory from its working directory
    ern_nodes_tests:has(OwnKey, "a peer has this node's own key, and a node is no peer"),
    cataloged(Err, "7", "the reload was refused", []),
    cataloged(Stale, "7", "no node runs from the directory", [{"dir", "b"}]),
    cataloged(Held, "7", "configuration directory of",
              [{"dir", "b"}, {"N", string:trim(binary_to_list(Number))}]).

%% What `ern Job --config-dir Dir` says where no node runs from the
%% directory, which fails it.
no_node(Base, Job, Dir) ->
    {1, "", Said} = job(Base, Job ++ " --config-dir " ++ Dir),
    Said.

%% guide/deployment.md, section 1.4; report §8.6, §11.2, §11.8: a node
%% exits with status 0 when its entry point returns, with the status
%% `Os.exit` gives, and with 1 when its entry process faults, the fault's
%% line on standard error, a pipe here, beginning with its time; status
%% 143 by `ern stop` is the runbook's. It does not cover status 141 nor a
%% killed entry process. Its limit is the sum of its seven waits, each
%% bounded by the harness's time for one wait: the build, and each of the
%% three nodes' end and what it said
statuses_test_() ->
    ern_nodes_tests:nodes_test({waits, 7}, fun statuses/1).

statuses(Base) ->
    ok = file:write_file(filename:join(Base, "statuses.ern"),
                         "// guide/deployment.md, section 1.4: a node's exit statuses.\n"
                         "\n"
                         "export fn main() : Unit =\n"
                         "    match Os.arguments {\n"
                         "        [\"exit\"] -> Os.exit(3)\n"
                         "      | [\"fault\"] -> Io.println(Int.toString(10 / ratio()))\n"
                         "      | _ -> Unit\n"
                         "    }\n"
                         "\n"
                         "fn ratio() : Int = List.size(Os.arguments) - 1\n"),
    ?assertEqual({0, "", ""}, job(Base, "build statuses.ern")),
    Dir = ern_nodes_tests:made(Base, "s", none),
    Run = fun(Arguments) ->
              {_, Wait} = node(Base, "run --config-dir s statuses.erc" ++ Arguments),
              Status = Wait(),
              {_, Err} = ern_nodes_tests:said(Dir),
              {Status, Err}
          end,
    ?assertEqual({0, ""}, Run("")),
    ?assertEqual({3, ""}, Run(" exit")),
    {1, Faulted} = Run(" fault"),
    %% the line as the guide's `Counter.serve:14 faulted: division by zero`,
    %% its time first as `2026-10-13T14:22:11.836Z the peer a connected`
    Stamped = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z \\QStatuses.main"
              " faulted: division by zero\\E$",
    ?assertMatch({match, _}, re:run(Faulted, Stamped, [multiline])).

%%
%% Section 5.3, a service moved to new code
%%

%% guide/deployment.md, section 5.3; report §6.10, §8.7, §11.1, Appendix
%% E.28: a counter of the example's first build on b, as section 8 starts
%% it, and the console's build of the second and its tool run on a, which
%% prints the lines it shows, b's counter moved though b lacked the new
%% loop; and the tool run again with a peer listed that nothing answers,
%% which is a line with the failure. It does not cover a build loaded with
%% `Code.load`. Its limit is the sum of its eight waits, each bounded by
%% the harness's time for one wait: two builds, a port that answers, the
%% ends of the tool's two runs and of b, and what the tool's two runs said
upgrade_test_() ->
    ern_nodes_tests:nodes_test({waits, 8}, fun upgrade/1).

upgrade(Base) ->
    [[Build, {Tool, _} = Moved]] = consoles("### 5.3"),
    ok = copied(Base),
    PortB = ern_nodes_tests:free_port(),
    A = ern_nodes_tests:made(Base, "a", none),
    B = ern_nodes_tests:made(Base, "b", PortB),
    C = ern_nodes_tests:made(Base, "c", none),
    ern_nodes_tests:lists(A, [{"b", B, PortB}]),
    ern_nodes_tests:lists(B, [{"a", A, none}]),
    ?assertEqual({0, "", ""}, job(Base, "build upgrade/v1")),
    {_, WaitB} = node(Base, "run --config-dir b --main Counter.serve upgrade/v1/counter.erc"),
    listens(B, PortB),
    [] = ran(Base, [Build, Moved]),
    ern_nodes_tests:lists(A, [{"b", B, PortB}, {"c", C, ern_nodes_tests:free_port()}]),
    {_, Again} = node(Base, Tool),
    ?assertEqual(0, Again()),
    {Out, _} = ern_nodes_tests:said(A),
    ern_nodes_tests:has(Out, "\nc: Unreachable\n"),
    ern_nodes_tests:stop(B, WaitB).

%%
%% The lines a node writes, sections 7 and 4.3
%%

%% guide/deployment.md, section 7; report §8.7: a peer silent past the
%% detector's intervals, here stopped by the host's signal, is lost, and
%% the node says it fell silent. The one test here that waits as long as
%% the detector does, about a minute. Its limit is the sum of its seven
%% waits, each bounded by the harness's time for one wait, and the
%% detector's time beside the one that waits for it: the test program's
%% build, three lines, two nodes' ends and what a said
fell_silent_test_() ->
    ern_nodes_tests:nodes_test({waits, 7, ern_nodes_tests:detector_ms()}, fun fell_silent/1).

fell_silent(Base) ->
    PortB = ern_nodes_tests:free_port(),
    A = ern_nodes_tests:made(Base, "a", none),
    B = ern_nodes_tests:made(Base, "b", PortB),
    ern_nodes_tests:lists(A, [{"b", B, PortB}]),
    ern_nodes_tests:lists(B, [{"a", A, none}]),
    Program = ern_nodes_tests:program(filename:join(Base, "build")),
    WaitB = ern_nodes_tests:start(B, Program, []),
    ern_nodes_tests:prints(B, "waiting"),
    WaitA = ern_nodes_tests:start(A, Program, ["hold", ern_nodes_tests:name(B)]),
    ern_nodes_tests:prints(A, "connect: true"),
    {ok, Number} = file:read_file(filename:join(B, "ernest.pid")),
    Frozen = string:trim(binary_to_list(Number)),
    "" = os:cmd("kill -STOP " ++ Frozen),
    %% the guide's latest, 75 seconds after the last traffic, beside the
    %% step's own time
    ern_nodes_tests:says(A, "the peer b was lost: it fell silent",
                         ern_nodes_tests:wait_ms() + ern_nodes_tests:detector_ms()),
    "" = os:cmd("kill -CONT " ++ Frozen),
    ern_nodes_tests:stop(A, WaitA),
    ern_nodes_tests:stop(B, WaitB),
    {_, ErrA} = ern_nodes_tests:said(A),
    cataloged(ErrA, "7", "fell silent", [{"b", "b"}]).

%% guide/deployment.md, sections 4.3 and 7, and 1.2; report §8.7: a bare
%% node whose `listen` names port 0 says the port it bound; and code that
%% arrives which it cannot take, a definition that references one no node
%% holds, sent by a peer of the test's own that plays the spawner's part
%% of the exchange, is not loaded, the spawn answered Other and the node
%% saying why, naming the peer and the site. It does not cover a count of
%% the host's passed, the other reason the guide names. Its limit is the
%% sum of its five waits, each bounded by the harness's time for one wait:
%% two lines, the peer's run, the node's end and what it said; the two host
%% modules it compiles are no step
refused_code_test_() ->
    ern_nodes_tests:nodes_test({waits, 5}, fun refused_code/1).

refused_code(Base) ->
    Root = filename:join(Base, "build"),
    ok = filelib:ensure_path(Root),
    [ok = file:write_file(filename:join(Root, Module ++ ".erl"), Source)
     || {Module, Source} <- [{"ern_nodes_client", ern_nodes_tests:client()},
                             {"ern_deployment_taker", taker()}]],
    [{ok, _} = compile:file(filename:join(Root, Module), [{outdir, Root}])
     || Module <- ["ern_nodes_client", "ern_deployment_taker"]],
    %% a function whose form references a definition by a hash no node holds
    Form = {function, {scheme, [], {arrow, [], none, {applied, {named, ['Int']}, []}}, []}, [],
            {var, {hash, <<77:256>>}, []}},
    Bytes = ern_canonical:bytes(ern_canonical:hashed([Form])),
    Frame = filename:join(Base, "frame"),
    ok = file:write_file(Frame, term_to_binary(
                                  {crypto:hash(sha256, Bytes), Bytes,
                                   term_to_binary([{[<<"Crafted">>, <<"bad">>], Form, {[], []},
                                                    []}])})),
    Z = ern_nodes_tests:made(Base, "z", none),
    B = ern_nodes_tests:made(Base, "b", 0),
    ern_nodes_tests:lists(B, [{"z", Z, none}]),
    WaitB = ern_nodes_tests:bare_started(B, []),
    PortB = ern_nodes_tests:bound_port(B),
    {_, Taker} = ern_nodes_tests:client(Root, ern_nodes_tests:name(Z),
                                        ern_nodes_tests:key_files(Z), ern_carrier:cookie(),
                                        PortB, ern_nodes_tests:name(B),
                                        ["-ern_deployment_frame", Frame, "-ern_deployment_ms",
                                         integer_to_list(ern_nodes_tests:wait_ms())],
                                        "ern_deployment_taker"),
    {0, Answer} = Taker(),
    ern_nodes_tests:has(binary_to_list(Answer), "answer: {failed,{'Other',<<\"this node could"
                                                " not take the code it received: "),
    ern_nodes_tests:says(B, "could not take the code it received"),
    ern_nodes_tests:stop(B, WaitB),
    {_, ErrB} = ern_nodes_tests:said(B),
    cataloged(ErrB, "7", "listening on", [{"51204", integer_to_list(PortB)}]),
    cataloged(ErrB, "7", "could not take the code", [{"a", "z"}, {"Site", "Taker.main:1"}]),
    cataloged(ErrB, "4.3", "could not take the code",
              [{"a", "z"}, {"Counter.main:17", "Taker.main:1"}]).

%% A peer of the test's own, run in a bare `erl` that holds a peer's key: it
%% spawns on the node its command line names the function of the frame it
%% is given, answers the request for its reach with that function alone,
%% sends its code frame where the node lacks it, and prints the spawn's
%% answer; its gateway is its own process, to which the node sends its
%% frames (report §8.7), and its spawn waits the milliseconds its command
%% line gives, the harness's time for one wait.
taker() ->
    <<"
-module(ern_deployment_taker).
-export([main/0]).
main() ->
    Node = list_to_atom(argument(ern_nodes_target)),
    {Hash, Bytes, Sources} = binary_to_term(read(argument(ern_deployment_frame))),
    true = register(ern_gateway, self()),
    true = net_kernel:connect_node(Node),
    Spawn = make_ref(),
    sent(Node, {spawn, Spawn, {function, Hash}, <<\"Taker.main:1\">>, false,
                list_to_integer(argument(ern_deployment_ms))}),
    Exchange = receive {ern_frame, _, {reach_request, Asked, _}} -> Asked end,
    sent(Node, {reach, Exchange, [Hash], [], []}),
    [Hash] = receive {ern_frame, _, {lacks, Exchange, Lacks}} -> Lacks end,
    sent(Node, {code_frame, Exchange, [Hash], Bytes, Sources}),
    receive {ern_frame, _, {answer, Spawn, Answer}} -> io:format(\"answer: ~0p~n\", [Answer]) end,
    halt().
argument(Name) ->
    {ok, [[Value]]} = init:get_argument(Name),
    Value.
read(File) ->
    {ok, Bytes} = file:read_file(File),
    Bytes.
sent(Node, Body) ->
    erlang:send({ern_gateway, Node}, {ern_frame, self(), Body}).
">>.

%% guide/deployment.md, sections 4.2 and 7; report §11.2: at four fifths
%% of a limit of the host's the runtime says the line the guide quotes,
%% given the counts a load would read, in a host of its own, whose counts
%% no other test's loads then change. It does not cover a node that loads
%% its way there, which would take hours. Its limit is its one wait, the
%% host's run, bounded by the harness's time for one wait
four_fifths_test_() ->
    ern_nodes_tests:counted_test({waits, 1}, fun four_fifths/0).

four_fifths() ->
    Counts = "[{module_names, 52429, 65536}, {exports, 1, 524288}, {lambdas, 1, 524288},"
             " {atoms, 1, 1048576}]",
    Host = open_port({spawn_executable, os:find_executable("erl")},
                     [{args, ["-noshell", "-pa" | filelib:wildcard("../erl/*/ebin")]
                       ++ ["-eval", "io:put_chars([[Line, $\\n] || Line <- ern_code:nearing("
                                    ++ Counts ++ ")]), halt()."]},
                      exit_status, binary]),
    {0, Said} = collected(Host),
    ?assertEqual(<<"the host has used 52429 of its 65536 module names, which it never gives"
                   " back\n">>, Said),
    cataloged(binary_to_list(Said), "7", "never gives back", [{"N", "52429"}, {"M", "65536"}]).

%% guide/deployment.md, sections 7 and 4.3: every line the guide quotes
%% there is held to a node's by a check that names it, beside the test
%% that provokes the line, in this module or in ern_nodes_tests, and each
%% check names one line
catalog_test() ->
    Quoted = quoted(),
    ?assert(length(Quoted) >= 26),
    Checks = lists:usort(lists:append([checks(File) || File <- ?PROVOKING])),
    Named = fun(Section, Fragment) ->
                [Line || {In, Line, _} <- Quoted, In =:= Section,
                         string:find(Line, Fragment) =/= nomatch]
            end,
    Checked = [{Section, Line} || {Section, Fragment} <- Checks,
                                  Line <- Named(Section, Fragment)],
    ?assertEqual([], [{Section, Line} || {Section, Line, _} <- Quoted,
                                         not lists:member({Section, Line}, Checked)]),
    ?assertEqual([], [Check || {Section, Fragment} = Check <- Checks,
                               length(Named(Section, Fragment)) =/= 1]).

%% Each check a module's tests make, {Section, Fragment}, read from its
%% source, every form of which is read: a call of cataloged/4, whose
%% section and fragment are text.
checks(File) ->
    {ok, Forms} = epp_dodger:parse_file(File),
    ?assertEqual([], [Error || {error, _} = Error <- Forms]),
    erl_syntax_lib:fold(fun(Node, Acc) -> check(Node) ++ Acc end, [],
                        erl_syntax:form_list(Forms)).

check(Node) ->
    Called = case erl_syntax:type(Node) of
                 application ->
                     try erl_syntax_lib:analyze_application(Node)
                     catch throw:syntax_error -> none
                     end;
                 _ ->
                     none
             end,
    case lists:member(Called, [{cataloged, 4}, {?MODULE, {cataloged, 4}}]) of
        true ->
            [_, Section, Fragment, _] = erl_syntax:application_arguments(Node),
            [{erl_syntax:string_value(Section), erl_syntax:string_value(Fragment)}];
        false ->
            []
    end.

%% guide/deployment.md, sections 7 and 4.3: the line Section quotes that
%% holds Fragment is a line of Err, a node's standard error, after its
%% time, with each of the guide's names in it that Names gives the
%% harness's in its place, and `...` any text. A line quoted after another
%% in one cell or one item, `the peer b was added` / `was removed`, is the
%% end of a line.
-spec cataloged(string(), string(), string(), [{string(), string()}]) -> ok.
cataloged(Err, Section, Fragment, Names) ->
    case [{Line, Whole} || {In, Line, Whole} <- quoted(), In =:= Section,
                           string:find(Line, Fragment) =/= nomatch] of
        [{Line, Whole}] ->
            case re:run(Err, pattern(Line, Whole, Names), [multiline, {capture, none}]) of
                match ->
                    ok;
                nomatch ->
                    Said = [Written || Written <- string:split(Err, "\n", all),
                                       string:find(Written, Fragment) =/= nomatch],
                    erlang:error({not_as_quoted, Section, Line, {written, Said}})
            end;
        Lines ->
            erlang:error({not_one_line, Section, Fragment, Lines})
    end.

%% A line the guide quotes as a pattern of the line written, whole or its
%% end, its time before it where the stream is neither a terminal nor a
%% journal (report §11.2).
pattern(Line, Whole, Names) ->
    Words = ["\\.\\.\\." | ["\\b\\Q" ++ Word ++ "\\E\\b" || {Word, _} <- Names]],
    Parts = re:split(Line, ["(", lists:join("|", Words), ")"], [{return, list}]),
    ["^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z )?",
     [".*" || not Whole], [part(Part, Names) || Part <- Parts], "$"].

part("...", _) -> ".*";
part(Part, Names) -> ["\\Q", proplists:get_value(Part, Names, Part), "\\E"].

%% The lines sections 7 and 4.3 quote, {Section, Line, Whole}: each code
%% span of the catalog's first column, and each of an item's before its
%% colon, a span after the first in its cell or its item continuing the
%% one before it.
quoted() ->
    Lines = guide_lines(),
    [{"7", Span, Whole}
     || "| `" ++ _ = Row <- section(Lines, "## 7."),
        {Span, Whole} <- spans(hd(string:split(Row, " | ")))]
        ++ [{"4.3", Span, Whole}
            || "- `" ++ _ = Item <- section(Lines, "### 4.3"),
               {Span, Whole} <- spans(hd(string:split(Item, "`: ")) ++ "`")].

spans(Text) ->
    {match, Spans} = re:run(Text, "`([^`]*)`", [global, {capture, all_but_first, list}]),
    lists:zip([Span || [Span] <- Spans], [true | [false || _ <- tl(Spans)]]).

%% The lines under the heading that begins with Heading, to the next.
section(Lines, Heading) ->
    [_ | Rest] = lists:dropwhile(fun(Line) -> not lists:prefix(Heading, Line) end, Lines),
    lists:takewhile(fun(Line) -> not lists:prefix("#", Line) end, Rest).

%%
%% The guide read, and its consoles run
%%

%% The example's two builds copied under Base, where the guide's commands,
%% run from `examples/`, find them.
copied(Base) ->
    lists:foreach(fun(Build) ->
                      Source = filename:join([Base, "upgrade", Build, "counter.ern"]),
                      ok = filelib:ensure_dir(Source),
                      {ok, _} = file:copy(filename:join([?EXAMPLE, Build, "counter.ern"]), Source)
                  end, ["v1", "v2"]).

guide_lines() ->
    {ok, Text} = file:read_file(?GUIDE),
    string:split(unicode:characters_to_list(Text), "\n", all).

%% The guide's fenced blocks, {Heading, Info, Lines}: the heading each stands
%% under, the word after its fence, and its lines.
blocks() ->
    blocks(guide_lines(), "", []).

blocks([], _, Blocks) ->
    lists:reverse(Blocks);
blocks(["```" ++ Info | Lines], Heading, Blocks) ->
    {Code, ["```" | Rest]} = lists:splitwith(fun(Line) -> Line =/= "```" end, Lines),
    blocks(Rest, Heading, [{Heading, Info, Code} | Blocks]);
blocks(["#" ++ _ = Heading | Lines], _, Blocks) ->
    blocks(Lines, Heading, Blocks);
blocks([_ | Lines], Heading, Blocks) ->
    blocks(Lines, Heading, Blocks).

%% The consoles under the heading that begins with Heading, each its
%% commands, {Words, Shown}: a `$ ern` line's words after `ern`, and the
%% lines the console shows it print.
consoles(Heading) ->
    [commands(Lines) || {Under, "console", Lines} <- blocks(), lists:prefix(Heading, Under)].

commands([]) ->
    [];
commands(["$ ern " ++ Words | Lines]) ->
    {Shown, Rest} = lists:splitwith(fun(Line) -> not lists:prefix("$ ", Line) end, Lines),
    [{Words, Shown} | commands(Rest)].

%% A console's commands run from Base in order: a node the console starts
%% with `&` left running; a node run in the foreground waited for, its
%% status 0 and its standard output the lines the console shows, in any
%% order, since what its processes print interleaves; and any other job
%% waited for, its status 0, nothing on its standard error, and its
%% standard output what the console shows, `ern config`'s key where the
%% console leaves it out. Answers each node left running, {Dir, Wait}.
ran(Base, Commands) ->
    lists:append([command(Base, Command) || Command <- Commands]).

command(Base, {Words, Shown}) ->
    case {lists:prefix("run ", Words), lists:suffix(" &", Words)} of
        {true, true} ->
            [node(Base, lists:sublist(Words, length(Words) - 2))];
        {true, false} ->
            {Dir, Wait} = node(Base, Words),
            ?assertEqual(0, Wait()),
            {Out, _} = ern_nodes_tests:said(Dir),
            ?assertEqual(lists:sort(Shown), lists:sort(lines(Out))),
            [];
        {false, _} ->
            {0, Out, ""} = job(Base, Words),
            case {Words, Shown} of
                {"config " ++ _, []} -> keyed(Out);
                _ -> printed(Shown, Out)
            end,
            []
    end.

%% A node started from Base by its words after `ern`, its streams read by
%% the watcher of the directory its `--config-dir` names: that directory,
%% and what waits for the node's end.
node(Base, Words) ->
    {match, [Name]} = re:run(Words, "--config-dir ([^ ]+)", [{capture, all_but_first, list}]),
    Dir = filename:join(Base, Name),
    {_, Wait} = ern_nodes_tests:launched(Dir, ["cd ", Base, " && ", ?ERN, " ", Words]),
    {Dir, Wait}.

%% A job run from Base by its words after `ern`, as a person runs it: its
%% status, its standard output and its standard error. One step of the
%% harness's, its time for one wait bounding a failure, as it bounds a
%% node's end.
-spec job(file:filename(), string()) -> {integer(), string(), string()}.
job(Base, Words) ->
    Err = filename:join(Base, "job.err"),
    Command = lists:flatten(["cd ", Base, " && ", ?ERN, " ", Words, " 2> ", Err]),
    Job = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status, binary]),
    {Status, Out} = collected(Job),
    {ok, Said} = file:read_file(Err),
    {Status, binary_to_list(Out), binary_to_list(Said)}.

%% What the command the port runs wrote, to its end, and its status: one
%% step, within the harness's time for one wait.
collected(Port) ->
    ern_nodes_tests:step({collected, Port}),
    collected(Port, <<>>, erlang:monotonic_time(millisecond) + ern_nodes_tests:wait_ms()).

collected(Port, Acc, Deadline) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, <<Acc/binary, Bytes/binary>>, Deadline);
        {Port, {exit_status, Status}} -> {Status, Acc}
    after max(Deadline - erlang:monotonic_time(millisecond), 0) ->
        erlang:error({still_running, Port, Acc})
    end.

%% Whether Out is the lines a console shows, a line that ends in `...` the
%% start of its line.
printed(Shown, Out) ->
    Lines = lines(Out),
    ?assertEqual(length(Shown), length(Lines)),
    [case string:split(Line, "...", trailing) of
         [Start, ""] -> ?assert(lists:prefix(Start, Written));
         _ -> ?assertEqual(Line, Written)
     end || {Line, Written} <- lists:zip(Shown, Lines)].

%% Report §11.3: `ern config` prints the node's public key in PEM.
-spec keyed(string()) -> ok.
keyed(Out) ->
    ?assertMatch({match, _}, re:run(Out, "\\A-----BEGIN PUBLIC KEY-----\n[A-Za-z0-9+/]+=*\n"
                                         "-----END PUBLIC KEY-----\n\\z")).

lines(Text) ->
    string:lexemes(Text, "\n").

%% Words with each of the guide's paths and names that Paths gives the
%% harness's in its place.
mapped(Words, Paths) ->
    lists:flatten(lists:foldl(fun({Guide, Harness}, Acc) ->
                                      string:replace(Acc, Guide, Harness, all)
                              end, Words, Paths)).

%% Report §8.7: once the node of Dir listens at Port of the loopback
%% interface, which it says once at every start; the harness's time for
%% one wait bounds a failure. A regression test (the log's *The Review's
%% Decisions*): a node with a fixed port said nothing, and the tests dialed
%% it until a dial succeeded.
-spec listens(file:filename(), inet:port_number()) -> ok.
listens(Dir, Port) ->
    ern_nodes_tests:says(Dir, "listening on 127.0.0.1:" ++ integer_to_list(Port) ++ "\n").

listening(Dir, Port) ->
    ern_nodes_tests:edit(Dir, fun(Conf) ->
                                  Conf#{<<"listen">> => ern_nodes_tests:address(Port)}
                              end).

mode(File) ->
    {ok, #file_info{mode = Mode}} = file:read_file_info(File),
    Mode band 8#777.
