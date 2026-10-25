%% `make bench`'s part `nodes` (docs/development.md), the costs between two
%% nodes (report §8.7, §10): the desk of test/fixtures/peers/ times, against
%% the store, the host's own round trip, its ping, over TLS; a call to a
%% process there, five of the host's signals, beside a call to one here; and
%% a round trip to the store's echo, the message sent straight and through
%% the adapted address made on the store, whose difference is the gateway's
%% step; a find of the store's counter; a spawn on the store of a process
%% that ends at once; a compute there of a function that answers at once,
%% which §10 costs at a spawn's and a call's answer; and a utilization of
%% the store, its frame and its answer. Two plain nodes of the host's, on
%% the same two machines, time its ping over TCP, which TLS is set beside.
%% `make bench` starts both nodes on this machine; `make bench-machines` the
%% store on the first machine after this one of test/machines/machines.txt
%% and the desk here (plan, MVP 3.27 item 1). It measures and asserts
%% nothing, so it is not part of `make test-full`.
-module(ern_nodes_costs).

-export([main/1]).

-define(SERVICES, [<<"counter">>, <<"brittle">>, <<"echo">>, <<"echo-adapted">>]).

%% Prints the table and halts, the nodes' directories under Dir: both
%% nodes on this machine, or, given the machines' file, the store on the
%% first machine after this one. The store's directory goes at the end,
%% however the run ended, the node that still runs from it stopped first,
%% and on this machine the desk's with it.
-spec main([string()]) -> no_return().
main([Dir]) ->
    Local = ern_machine:local(),
    try measured(Dir, Local, Local, "between two nodes on this machine")
    after ern_machine_node:cleared(Local, ern_machine:directory(Local, Dir))
    end,
    halt(0);
main([Dir, File]) ->
    ern_machines:reported(
      fun() ->
          Machines = ern_machines:ready(File),
          Local = ern_machines:local(Machines),
          try ern_machines:remote(Machines) of
              [Other | _] ->
                  try measured(Dir, Other, Local,
                               io_lib:format("between ~s and ~s", [ern_machine:name(Local),
                                                                   ern_machine:name(Other)]))
                  after ern_machine_node:cleared(Other, ern_machine:directory(Other, Dir))
                  end;
              [] ->
                  ern_machine:fail(File ++ " names no machine but this one")
          after ern_machines:closed(Machines)
          end
      end),
    halt(0).

%% The table between the store on Store's machine and the desk on Desk's.
measured(Dir, StoreMachine, DeskMachine, Heading) ->
    [ern_machine_node:cleared(Machine, ern_machine:directory(Machine, Dir))
     || Machine <- lists:uniq([StoreMachine, DeskMachine])],
    ok = filelib:ensure_path(Dir),
    Root = filename:absname(filename:join(Dir, "build")),
    0 = ern_cli:ern(["build", "--build-root", Root, "fixtures/peers"], group_leader()),
    {ok, _} = compile:file("fixtures/peers/ern_peers_host.erl", [{outdir, Root}]),
    StoreRoot = ern_machine:copied(StoreMachine, Root, Dir),
    Store = ern_machine_node:configured(StoreMachine, ern_machine:directory(StoreMachine, Dir),
                                        "store", 0),
    Desk = ern_machine_node:configured(DeskMachine, ern_machine:directory(DeskMachine, Dir),
                                       "desk", none),
    ern_machine_node:listed(Store, [{Desk, none}]),
    Reader = ern_machine_node:started(Store, [filename:join(StoreRoot, "store.erc")]),
    Port = ern_machine_node:port_bound(Reader),
    %% the store says on its standard output that it has made its offers
    _ = ern_machine:seen(Reader, "offered"),
    ern_machine_node:listed(Desk, [{Store, ern_machine_node:address(Store, Port)}]),
    ern_machine_node:edited(Desk, fun(Conf) ->
                                      Conf#{<<"services">> =>
                                                maps:from_list([{Name, [<<"store">>]}
                                                                || Name <- ?SERVICES])}
                                  end),
    Costs = desk_costs(Desk, filename:join(Root, "desk.erc")),
    ern_machine_node:stopped(Store),
    _ = ern_machine:ended(Reader),
    Tcp = tcp_ping(StoreMachine, DeskMachine),
    table(Heading, Costs, Tcp).

table(Heading, Costs, Tcp) ->
    Ping = maps:get("ping", Costs),
    Rows = [{"the host's ping, over TLS", Ping, none},
            {"the host's ping, over TCP", Tcp, none},
            {"  TLS beside TCP", Ping / Tcp, ratio},
            {"a call to the other node's process", maps:get("remote-call", Costs), none},
            {"  beside the host's ping", maps:get("remote-call", Costs) / Ping, ratio},
            {"a call to this node's process", maps:get("local-call", Costs), none},
            {"a message to the other node's process and back", maps:get("straight", Costs),
             none},
            {"  the same through its adapted address there", maps:get("adapted", Costs), none},
            {"  the gateway's step", maps:get("adapted", Costs) - maps:get("straight", Costs),
             none},
            {"a find of the other node's service", maps:get("find", Costs), none},
            {"  beside the host's ping", maps:get("find", Costs) / Ping, ratio},
            {"a spawn on the other node", maps:get("spawn", Costs), none},
            {"  beside the host's ping", maps:get("spawn", Costs) / Ping, ratio},
            {"a compute on the other node", maps:get("compute", Costs), none},
            {"  beside the host's ping", maps:get("compute", Costs) / Ping, ratio},
            {"a utilization of the other node", maps:get("utilization", Costs), none},
            {"  beside the host's ping", maps:get("utilization", Costs) / Ping, ratio}],
    io:format("~-48ts ~12s~n", [Heading, "µs or ratio"]),
    lists:foreach(fun({Name, Value, none}) -> io:format("~-48ts ~12.1f~n", [Name, Value]);
                     ({Name, Value, ratio}) -> io:format("~-48ts ~11.2fx~n", [Name, Value])
                  end, Rows).

%% The desk's lines, `key microseconds`, as a map; its standard error,
%% where it fails, beside them.
desk_costs(Desk, Program) ->
    Machine = ern_machine_node:machine(Desk),
    Errors = ern_machine_node:config_dir(Desk) ++ ".err",
    Command = lists:flatten([ern_machine:quoted(ern_machine:ern(Machine)), " run --config-dir ",
                             ern_machine:quoted(ern_machine_node:config_dir(Desk)),
                             " ", ern_machine:quoted(Program), " costs 2> ",
                             ern_machine:quoted(Errors)]),
    %% the desk's measuring run, which lasts as long as its work does
    case ern_machine:run(Machine, Command, infinity) of
        {0, Said} ->
            maps:from_list([{Key, list_to_float(Value)}
                            || Line <- string:lexemes(Said, "\n"),
                               [Key, Value] <- [string:lexemes(Line, " ")]]);
        {Status, Said} ->
            ern_machine:fail(io_lib:format("the desk ended with status ~B: ~ts~ts",
                                           [Status, Said,
                                            ern_machine:ran(Machine, "cat "
                                                            ++ ern_machine:quoted(Errors))]))
    end.

%% The microseconds of the host's ping between two plain nodes of its own,
%% over TCP, with no port mapper, which would outlive them: the second on
%% Second's machine, listening on a port it picks and says, the first on
%% First's, which only dials it at that port, times the ping and ends it.
tcp_ping(Second, First) ->
    Cookie = "ern_nodes_costs",
    Listening = "{ok, Socket} = gen_tcp:listen(0, []), {ok, Port} = inet:port(Socket),"
                " ok = gen_tcp:close(Socket),"
                " ok = application:set_env(kernel, erl_epmd_node_listen_port, Port),"
                " {ok, _} = net_kernel:start(list_to_atom(\"ern_costs_b@"
                ++ ern_machine:host(Second) ++ "\"), #{name_domain => longnames}),"
                " io:format(\"up ~B~n\", [Port]).",
    Reader = ern_machine:launched(Second, lists:flatten(["erl -noinput -start_epmd false",
                                                         " -setcookie ", Cookie, " -eval ",
                                                         ern_machine:quoted(Listening)])),
    [Port] = ern_machine:seen(Reader, "up ([0-9]+)"),
    Timing = "ok = application:set_env(kernel, erl_epmd_node_listen_port, " ++ Port ++ "),"
             " {ok, _} = net_kernel:start(list_to_atom(\"ern_costs_a@"
             ++ ern_machine:host(First) ++ "\"), #{name_domain => longnames}),"
             " Other = list_to_atom(\"ern_costs_b@" ++ ern_machine:host(Second) ++ "\"),"
             " pong = net_adm:ping(Other),"
             " Started = erlang:monotonic_time(microsecond),"
             " [pong = net_adm:ping(Other) || _ <- lists:seq(1, 5000)],"
             " io:format(\"~p~n\", [(erlang:monotonic_time(microsecond) - Started) / 5000]),"
             " rpc:call(Other, erlang, halt, []), halt().",
    Said = ern_machine:ran(First, lists:flatten(["erl -noinput -start_epmd false",
                                                 " -dist_listen false -setcookie ", Cookie,
                                                 " -eval ", ern_machine:quoted(Timing)])),
    _ = ern_machine:ended(Reader),
    list_to_float(string:trim(Said)).
