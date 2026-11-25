%% The printer of Appendix E.1, by a type's descriptor and, where there is
%% none, by the runtime's representation (report §12.2).
-module(ern_show_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.1, §2.5: a string shows each control character as its
%% escape, one of U+0080 to U+009F among them. A regression test: those
%% were written as they were, U+009B the start of a terminal's command
controls_shown_test() ->
    ?assertEqual(<<"\"a\\u{1B}\\u{9B}b\\n\"">>,
                 ern_show:show(string, <<"a", 16#1B, 16#9B/utf8, "b\n">>)),
    ?assertEqual(<<"a\\u{9B}\\nb">>, ern_show:controls(<<"a", 16#9B/utf8, "\nb">>, line)),
    ?assertEqual(<<"a\\u{9B}\nb">>, ern_show:controls(<<"a", 16#9B/utf8, "\nb">>, lines)).

%% report Appendix E.1: by the descriptor of the argument's type
by_type_test() ->
    ?assertEqual(<<"'a'">>, ern_show:show(char, $a)),
    %% a negative number with `-` before it; a regression test, written after
    %% the code
    ?assertEqual(<<"#(-1, -2.5)">>, ern_show:show({tuple, [int, float]}, {-1, -2.5})),
    %% an Int alone is written by one conversion, by its descriptor and by
    %% its representation, a negative one and one past a machine word among
    %% them, and so at a depth of 0, since a number is no bracket (report
    %% §11.2); written with the change to the conversion
    ?assertEqual(<<"-12">>, ern_show:show(int, -12)),
    ?assertEqual(<<"-12">>, ern_show:show(any, -12)),
    ?assertEqual(<<"#(-1, [2])">>, ern_show:show(any, {-1, [2]})),
    ?assertEqual(<<"-18446744073709551616">>, ern_show:show(int, -(1 bsl 64))),
    ?assertEqual(<<"7">>, ern_show:show(int, 7, 0, 0)),
    ?assertEqual(<<"[1, -2, ...]">>, ern_show:show({list, int}, [1, -2, 3], 2, 2)),
    ?assertEqual(<<"\"hi\"">>, ern_show:show(string, <<"hi">>)),
    ?assertEqual(<<"<<104, 105>>">>, ern_show:show(bytes, <<"hi">>)),
    ?assertEqual(<<"#(1, true)">>, ern_show:show({tuple, [int, bool]}, {1, true})),
    Snap = {con, <<"Probe">>, [{'Snap', [string, int], [dir, seen]}]},
    ?assertEqual(<<"Probe.Snap(dir = \"x\", seen = 2)">>,
                 ern_show:show(Snap, {'Snap', <<"x">>, 2})),
    ?assertEqual(<<"<abstract>">>,
                 ern_show:show({abstract, {con, <<"Probe">>, []}}, {'Stack', []})),
    ?assertEqual(<<"<foreign>">>, ern_show:show(foreign, 1)).

%% report Appendix E.1: a `Set` of `Bool` prints its elements ascending,
%% `false` before `true`, by its descriptor, and a `Map` with `Bool` keys
%% its pairs so, by the descriptor and by the representation alone; report
%% §12.2: by the representation alone a set is the host's map from each
%% element to []. A regression test, written after the code; the order of
%% the other types the sentence names is not covered here
bool_ascending_test() ->
    Set = ern_set:from_list([true, false]),
    ?assertEqual(<<"Set.fromList([false, true])">>, ern_show:show({set, bool}, Set)),
    ?assertEqual(<<"Map.fromList([#(false, []), #(true, [])])">>, ern_show:show(any, Set)),
    Map = #{true => 1, false => 0},
    ?assertEqual(<<"Map.fromList([#(false, 0), #(true, 1)])">>,
                 ern_show:show({map, bool, int}, Map)),
    ?assertEqual(<<"Map.fromList([#(false, 0), #(true, 1)])">>, ern_show:show(any, Map)).

%% report Appendix E.1: a constructor outside the prelude is written as code
%% outside its module writes it, under its module's namespace, at any
%% depth, and the prelude's by its name alone. A regression test, written
%% after the code: every constructor was its name alone, which `Timeout`
%% cannot be typed back as; it does not cover the descriptors the emitter
%% and the shell's describer make, which their own tests read
qualified_constructor_test() ->
    Error = {con, <<"Io">>, [{'Timeout', []}, {'Other', [string]}]},
    Optional = {con, none, [{'None', []}, {'Some', [Error]}]},
    ?assertEqual(<<"Io.Timeout">>, ern_show:show(Error, 'Timeout')),
    ?assertEqual(<<"Some(Io.Other(\"x\"))">>,
                 ern_show:show(Optional, {'Some', {'Other', <<"x">>}})),
    ?assertEqual(<<"None">>, ern_show:show(Optional, 'None')),
    Nested = {con, <<"Net.Http">>, [{'Pair', [Error, Error], [left, right]}]},
    ?assertEqual(<<"Net.Http.Pair(left = Io.Timeout, right = Io.Timeout)">>,
                 ern_show:show(Nested, {'Pair', 'Timeout', 'Timeout'})).

%% report Appendix E.1, E.21: a process of this node by its number on its
%% node after a dot, and an address as the process behind it, through
%% every adapted address
identity_test() ->
    Pid = list_to_pid("<0.84.0>"),
    ?assertEqual(<<"<process.84>">>, ern_show:show(process, Pid)),
    ?assertEqual(<<"<address.84>">>, ern_show:show({address, any, <<>>, none}, Pid)),
    ?assertEqual(<<"<address.84>">>,
                 ern_show:show({address, any, <<>>, none}, ern_rt:adapted(Pid, fun(X) -> X end))),
    %% and where the type is a variable, by the representation. A
    %% regression test: an adapted address read as a tuple,
    %% `#(adapted, <function>, <address 84>)`
    ?assertEqual(<<"<address.84>">>, ern_show:show(any, ern_rt:adapted(Pid, fun(X) -> X end))).

%% report Appendix E.1, §8.3, §8.4: a process of another node by its peer's
%% name before its number, the name as this node's configuration lists it,
%% and an address as the process behind it does: the peer's process's own,
%% one adapted over it, and one foreign code gave, a check of this node
%% held with the process behind it; each by its descriptor and by the
%% representation
peer_identity_test() ->
    Node = ern_carrier:name(<<"the store's key">>),
    Pid = pid_of(Node, 84),
    Adapted = ern_rt:adapted(Pid, fun(X) -> X end),
    Given = {foreign, list_to_pid("<0.90.0>"), Pid, int, #{}},
    listed([{<<"store">>, Node}],
           fun() ->
               ?assertEqual(<<"<process.store.84>">>, ern_show:show(process, Pid)),
               [?assertEqual(<<"<address.store.84>">>, ern_show:show(Descriptor, Address))
                || Descriptor <- [{address, any, <<>>, none}, any],
                   Address <- [Pid, Adapted, Given]]
           end).

%% report Appendix E.1: a peer's name written as it stands in the
%% configuration, a dot, a space or a letter beyond ASCII in it too
name_as_listed_test() ->
    [Dotted, Spaced, Swedish] = [ern_carrier:name(Key) || Key <- [<<"a">>, <<"b">>, <<"c">>]],
    listed([{<<"eu.store">>, Dotted}, {<<"the store">>, Spaced}, {<<"förråd"/utf8>>, Swedish}],
           fun() ->
               ?assertEqual(<<"<process.eu.store.84>">>,
                            ern_show:show(process, pid_of(Dotted, 84))),
               ?assertEqual(<<"<address.the store.7>">>, ern_show:show(any, pid_of(Spaced, 7))),
               ?assertEqual(<<"<process.förråd.84>"/utf8>>,
                            ern_show:show(process, pid_of(Swedish, 84)))
           end).

%% report Appendix E.1, §12.5: a process of a node this node's
%% configuration does not list, a peer a reload removed among them, by the
%% node's key's digest for the name, as a node's lines name such a node,
%% and an address as the process behind it does
unlisted_identity_test() ->
    Key = <<"a removed peer's key">>,
    Pid = pid_of(ern_carrier:name(Key), 84),
    Adapted = ern_rt:adapted(Pid, fun(X) -> X end),
    Digest = binary:encode_hex(crypto:hash(sha256, Key), lowercase),
    listed([],
           fun() ->
               ?assertEqual(<<"<process.", Digest/binary, ".84>">>, ern_show:show(process, Pid)),
               ?assertEqual(<<"<address.", Digest/binary, ".84>">>,
                            ern_show:show({address, any, <<>>, none}, Adapted))
           end).

%% The process numbered Number on Node, as the external term format writes
%% a process of another node (NEW_PID_EXT), its node's name a UTF-8 atom.
pid_of(Node, Number) ->
    Name = atom_to_binary(Node),
    binary_to_term(<<131, 88, 118, (byte_size(Name)):16, Name/binary, Number:32, 0:32, 1:32>>).

%% Test run with this node listing Peers, {Name, Node}, as the carrier lists
%% them (ern_peer:configure/2), and none listed after it, as a host that is
%% no node lists none.
listed(Peers, Test) ->
    ok = ern_peer:configure(Peers, #{}),
    try
        Test()
    after
        ok = ern_peer:configure([], #{})
    end.

%% report Appendix E.1: a foreign value reads by the representation, and as
%% <foreign> where it reads as none of Ernest's forms; an improper list,
%% which only foreign code can make, is one such
representation_test() ->
    ?assertEqual(<<"97">>, ern_show:show(any, $a)),
    ?assertEqual(<<"[1, 2]">>, ern_show:show(any, [1, 2])),
    ?assertEqual(<<"<foreign>">>, ern_show:show(any, [1 | 2])),
    ?assertEqual(<<"#(ok, 1)">>, ern_show:show(any, {ok, 1})),
    ?assertEqual(<<"Ready(1)">>, ern_show:show(any, {'Ready', 1})),
    ?assertEqual(<<"false">>, ern_show:show(any, false)).
