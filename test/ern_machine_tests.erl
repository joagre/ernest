%% The machines' tools of test/machines/ (docs/development.md) on this
%% machine, which every checkout has: the tracked list of machines read, a
%% command run in the plain shell and the machine's load read, nodes made,
%% listed, started and stopped there as `make bench-machines` makes and
%% runs them on every machine, and `make bench-pick`'s measuring program
%% run on such nodes. Regression tests, written after the tools. What they
%% leave out runs only by hand, on the user's machines, in `make
%% bench-machines`, `make bench-pick` and test/machines/nodes.sh: ssh and
%% its held connection, scp, another machine's clone and floor, the
%% calibration, the stream, and the bench's tables.
-module(ern_machine_tests).

-include_lib("eunit/include/eunit.hrl").

%% docs/development.md "test/machines/": the tracked machines.txt reads,
%% naming this machine once and another beside it
machines_file_test() ->
    Machines = ern_machines:machines("machines/machines.txt"),
    ?assertMatch([_], [Machine || Machine <- Machines, ern_machine:is_local(Machine)]),
    ?assertNotEqual([], ern_machines:remote(Machines)).

%% docs/development.md "test/machines/": a word the machines' shell reads as
%% the text itself, whatever the text holds
quoted_test() ->
    Text = "it's \"$HOME\" `pwd` \\ ; | & *",
    ?assertEqual(Text, ern_machine:ran(ern_machine:local(),
                                       "printf '%s' " ++ ern_machine:quoted(Text))).

%% docs/development.md "test/machines/": a command that fails fails the
%% tool, naming the machine, the command and what it wrote
failed_test() ->
    ?assertThrow({failed, "on this machine, `echo said; exit 3` ended with status 3: said"},
                 ern_machine:ran(ern_machine:local(), "echo said; exit 3")).

%% docs/development.md "make bench-pick": the machine's load average of
%% the last minute and its processors, which an arrangement of peers counts
%% by
load_test() ->
    {Load, Processors} = ern_machine:load(ern_machine:local()),
    ?assert(is_float(list_to_float(Load))),
    ?assert(list_to_integer(Processors) > 0).

%% report §11.3, §8.7, §11.2, Appendix C: two nodes' directories made with
%% `ern config` on a machine, each listening on a port the host picks; one
%% lists the other without an address and the other lists it with the
%% machine's host and the port it bound, which answers; one stopped by `ern
%% stop` and the other by the directory's removal, each ending by
%% termination, and the directory gone
nodes_test_() ->
    ern_nodes_tests:nodes_test({waits, 6}, fun two_nodes/1).

two_nodes(Base) ->
    Machine = ern_machine:local(),
    A = ern_machine_node:configured(Machine, Base, "a", 0),
    B = ern_machine_node:configured(Machine, Base, "b", 0),
    ern_machine_node:listed(A, [{B, none}]),
    ReaderA = ern_machine_node:started(A, []),
    PortA = ern_machine_node:port_bound(ReaderA),
    ern_machine_node:listed(B, [{A, ern_machine_node:address(A, PortA)}]),
    Address = list_to_binary("127.0.0.1:" ++ integer_to_list(PortA)),
    ?assertMatch(#{<<"listen">> := <<"127.0.0.1:0">>,
                   <<"peers">> := [#{<<"name">> := <<"a">>, <<"network-address">> := Address}]},
                 configuration(B)),
    ?assertMatch(#{<<"peers">> := [#{<<"name">> := <<"b">>} = Listed]}
                   when not is_map_key(<<"network-address">>, Listed),
                 configuration(A)),
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, PortA, []),
    ok = gen_tcp:close(Socket),
    ReaderB = ern_machine_node:started(B, []),
    _ = ern_machine_node:port_bound(ReaderB),
    ern_machine_node:stopped(A),
    %% report §11.8: a node that termination ends exits by its signal
    ?assertMatch({143, _}, ern_machine:ended(ReaderA)),
    ?assertEqual([ern_machine_node:config_dir(B)], ern_machine_node:cleared(Machine, Base)),
    ?assertMatch({143, _}, ern_machine:ended(ReaderB)),
    ?assertNot(filelib:is_dir(Base)).

configuration(Node) ->
    {ok, Text} = file:read_file(filename:join(ern_machine_node:config_dir(Node), "ernest.conf")),
    json:decode(Text).

%% the push's experiment (the log's *The Numbers Across Machines*), report §8.7, Appendix E.27:
%% `make bench-pick`'s measuring program on a node here, two bare nodes
%% beside it as its peers, telling every 200 ms: a burst under each rule,
%% each compute answered by one of the two, a hundred under each, and the
%% host's counts sampled on every node at rest
pick_test_() ->
    ern_nodes_tests:nodes_test({waits, 6}, fun picked/1).

picked(Base) ->
    Machine = ern_machine:local(),
    Built = filename:join(Base, "build"),
    0 = ern_cli:ern(["build", "--source-root", "fixtures/bench", "--build-root", Built,
                     "fixtures/bench/pick.ern"], group_leader()),
    {ok, _} = compile:file("fixtures/bench/ern_pick_probe.erl", [{outdir, Built}]),
    Interval = fun(Configuration) -> Configuration#{<<"utilization-interval">> => 200} end,
    A = ern_machine_node:configured(Machine, Base, "a", none),
    Peers = [ern_machine_node:configured(Machine, Base, Name, 0) || Name <- ["p1", "p2"]],
    [begin
         ern_machine_node:listed(Peer, [{A, none}]),
         ern_machine_node:edited(Peer, Interval)
     end || Peer <- Peers],
    Ported = [{Peer, ern_machine_node:port_bound(Reader), Reader}
              || Peer <- Peers,
                 Reader <- [ern_machine_node:started(Peer, ["--load-path", Built])]],
    ern_machine_node:listed(A, [{Peer, ern_machine_node:address(Peer, Port)}
                                || {Peer, Port, _} <- Ported]),
    ern_machine_node:edited(A, Interval),
    Said = ern_machine:ran(Machine, lists:flatten(
                                      [ern_machine:ern(Machine), " run --config-dir ",
                                       ern_machine_node:config_dir(A), " --load-path ", Built,
                                       " ", filename:join(Built, "pick.erc"),
                                       " measure 10000 1 0 200 p1 p2"])),
    Lines = [string:lexemes(Line, " ") || Line <- string:lexemes(Said, "\n")],
    [begin
         ern_machine_node:stopped(Peer),
         ?assertMatch({143, _}, ern_machine:ended(Reader))
     end || {Peer, _, Reader} <- Ported],
    [?assertEqual({Rule, 100}, {Rule, length([Peer || ["burst", Ruled, "1", _, _, _, Peer, _]
                                                         <- Lines,
                                                     Ruled =:= Rule,
                                                     lists:member(Peer, ["p1", "p2"])])})
     || Rule <- ["two", "least"]],
    ?assertEqual(["a", "p1", "p2"],
                 lists:usort([Node || ["close", "idle", "rest", "1", Node, "schedulers", _, _]
                                          <- Lines])).
