%% A node on a machine (ern_machine), as MVP 3.27's tools make and run one
%% (plan, MVP 3.27 item 1): its configuration directory made there with
%% `ern config`, never copied, since a key is made on its machine (report
%% §8.7, §11.3); its `ernest.conf` read and written there, its `listen` and
%% its peers, each with its key and the address it is dialed at (Appendix
%% C); and the node started there, reloaded and stopped, as an operator
%% does on that machine (§11.2).
-module(ern_machine_node).

-export([configured/4, name/1, machine/1, config_dir/1, carrier_name/1, address/2, listed/2,
         edited/2, started/2, port_bound/1, reloaded/2, stopped/1, cleared/2]).

%% A node's name in its peers' configurations, its machine, its
%% configuration directory there and its public key.
-record(machine_node, {name :: string(),
                       machine :: ern_machine:machine(),
                       config_dir :: string(),
                       public_key :: binary()}).

-opaque machine_node() :: #machine_node{}.
-export_type([machine_node/0]).

%% Report §11.3: the node Name's directory made with `ern config` in Dir on
%% the machine, Dir made first where it is not there, since `ern config`
%% makes no missing parent; its `listen` the machine's interface at Port,
%% or none where it only dials, and its key read from its `ernest.conf`.
-spec configured(ern_machine:machine(), string(), string(), none | non_neg_integer()) ->
          machine_node().
configured(Machine, Dir, Name, Listen) ->
    ConfigDir = filename:join(Dir, Name),
    Conf = filename:join(ConfigDir, "ernest.conf"),
    Text = ern_machine:ran(Machine, lists:flatten(["mkdir -p ", ern_machine:quoted(Dir), " && ",
                                                   ern_machine:quoted(ern_machine:ern(Machine)),
                                                   " config --config-dir ",
                                                   ern_machine:quoted(ConfigDir), " > /dev/null",
                                                   " && cat ", ern_machine:quoted(Conf)])),
    Configuration = decoded(Machine, Conf, Text),
    Node = #machine_node{name = Name, machine = Machine, config_dir = ConfigDir,
                         public_key = maps:get(<<"public-key">>, Configuration)},
    written(Node, case Listen of
                      none -> maps:remove(<<"listen">>, Configuration);
                      Port -> Configuration#{<<"listen">> => listening(Machine, Port)}
                  end),
    Node.

-spec name(machine_node()) -> string().
name(#machine_node{name = Name}) -> Name.

-spec machine(machine_node()) -> ern_machine:machine().
machine(#machine_node{machine = Machine}) -> Machine.

-spec config_dir(machine_node()) -> string().
config_dir(#machine_node{config_dir = ConfigDir}) -> ConfigDir.

%% Report §12.5: the node's name on the carrier, which the host's counts of
%% its connections name it by.
-spec carrier_name(machine_node()) -> string().
carrier_name(#machine_node{public_key = PublicKey}) ->
    [{_, Der, _}] = public_key:pem_decode(PublicKey),
    atom_to_list(ern_carrier:name(Der)).

%% Report §12.5: the `network-address` a peer dials the node at, its
%% machine's host and its port.
-spec address(machine_node(), non_neg_integer()) -> binary().
address(#machine_node{machine = Machine}, Port) ->
    list_to_binary(ern_machine:host(Machine) ++ ":" ++ integer_to_list(Port)).

listening(Machine, Port) ->
    list_to_binary(ern_machine:interface(Machine) ++ ":" ++ integer_to_list(Port)).

%% Report §12.5, Appendix C: the node lists each of Peers, a peer node with
%% the address it is dialed at, or none where this node never dials it.
-spec listed(machine_node(), [{machine_node(), none | binary()}]) -> ok.
listed(Node, Peers) ->
    edited(Node, fun(Configuration) ->
                     Configuration#{<<"peers">> => [peer(Peer, Address)
                                                    || {Peer, Address} <- Peers]}
                 end).

peer(#machine_node{name = Name, public_key = PublicKey}, none) ->
    #{<<"name">> => list_to_binary(Name), <<"public-key">> => PublicKey};
peer(Peer, Address) ->
    (peer(Peer, none))#{<<"network-address">> => Address}.

%% Report Appendix C: the node's `ernest.conf` changed by Change, read and
%% written on its machine.
-spec edited(machine_node(), fun((map()) -> map())) -> ok.
edited(Node, Change) ->
    written(Node, Change(configuration(Node))).

%% The node's `ernest.conf`, read on its machine.
configuration(#machine_node{machine = Machine, config_dir = ConfigDir}) ->
    Conf = filename:join(ConfigDir, "ernest.conf"),
    decoded(Machine, Conf, ern_machine:ran(Machine, "cat " ++ ern_machine:quoted(Conf))).

decoded(Machine, Conf, Text) ->
    try json:decode(unicode:characters_to_binary(Text))
    catch error:_ ->
        ern_machine:fail(io_lib:format("on ~s, ~s is not JSON: ~ts",
                                       [ern_machine:name(Machine), Conf, Text]))
    end.

%% The node's `ernest.conf` written on its machine, over the file, which
%% keeps its mode.
written(#machine_node{machine = Machine, config_dir = ConfigDir}, Configuration) ->
    Text = unicode:characters_to_list(json:encode(Configuration)),
    Conf = filename:join(ConfigDir, "ernest.conf"),
    _ = ern_machine:ran(Machine, lists:flatten(["printf '%s' ", ern_machine:quoted(Text), " > ",
                                                ern_machine:quoted(Conf)])),
    ok.

%% Report §11.2: the node started on its machine, `ern run --config-dir`
%% with the words Words after it, a load path and a program or none, its
%% output read by a reader of its own (ern_machine:launched/2), which
%% answers.
-spec started(machine_node(), [string()]) -> pid().
started(#machine_node{machine = Machine, config_dir = ConfigDir}, Words) ->
    ern_machine:launched(Machine,
                         lists:flatten([ern_machine:quoted(ern_machine:ern(Machine)),
                                        " run --config-dir ", ern_machine:quoted(ConfigDir),
                                        [[" ", ern_machine:quoted(Word)] || Word <- Words]])).

%% Report §12.5: the port a node whose `listen` names port 0 bound, once it
%% says so.
-spec port_bound(pid()) -> non_neg_integer().
port_bound(Reader) ->
    [Port] = ern_machine:seen(Reader, "listening on [^ ]*:([0-9]+)"),
    list_to_integer(Port).

%% Report §12.5, §11.2: a node sent hangup reads `ernest.conf` again, and
%% says so.
-spec reloaded(machine_node(), pid()) -> ok.
reloaded(Node, Reader) ->
    _ = ern_machine:ran(machine(Node), ern(Node, "reload")),
    _ = ern_machine:seen(Reader, "ernest.conf was read again"),
    ok.

%% Report §8.6, §11.2: the node ended by termination, which `ern stop`
%% sends and waits on.
-spec stopped(machine_node()) -> ok.
stopped(Node) ->
    _ = ern_machine:ran(machine(Node), ern(Node, "stop")),
    ok.

ern(#machine_node{machine = Machine, config_dir = ConfigDir}, Job) ->
    lists:flatten([ern_machine:quoted(ern_machine:ern(Machine)), " ", Job, " --config-dir ",
                   ern_machine:quoted(ConfigDir)]).

%% The directory Dir removed on the machine, each node that still runs from
%% a configuration directory under it stopped first, as `make test`'s
%% nodes are (test/Makefile, NODES_RUN): a run that ended before it stopped
%% its nodes, or a node started by hand, leaves none running. Another
%% machine's directory goes with it where nothing else is left in it.
%% Answers the configuration directories whose nodes it stopped.
-spec cleared(ern_machine:machine(), string()) -> [string()].
cleared(Machine, Dir) ->
    Ern = ern_machine:quoted(ern_machine:ern(Machine)),
    Quoted = ern_machine:quoted(Dir),
    Emptied = case ern_machine:directory(Machine) of
                  none -> "";
                  Own -> lists:flatten([" && if test -d ", ern_machine:quoted(Own), "; then find ",
                                        ern_machine:quoted(Own), " -maxdepth 0 -empty",
                                        " -exec rmdir {} \\;; fi"])
              end,
    Stopped = ern_machine:ran(Machine,
                              lists:flatten(["for pid in $(find ", Quoted, " -name ernest.pid",
                                             " 2> /dev/null); do dir=$(dirname \"$pid\");",
                                             " if ", Ern, " stop --config-dir \"$dir\"",
                                             " > /dev/null 2>&1; then echo \"$dir\"; fi;",
                                             " done; rm -rf ", Quoted, Emptied])),
    string:lexemes(Stopped, "\n").
