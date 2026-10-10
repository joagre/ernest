%% `make bench`'s third part (docs/development.md), the costs the peer
%% proposal's section 9 left to measure, between two nodes on this machine:
%% the desk of test/peers/ times, against the store, the host's own round
%% trip, its ping, over TLS; a call to a process there, five of the host's
%% signals, beside a call to one here; and a round trip to the store's
%% echo, the message sent straight and through the adapted address made on
%% the store, whose difference is the gateway's step; a find of the store's
%% counter; and a spawn on the store of a process that ends at once. Two
%% plain nodes of the host's time its ping over TCP, which TLS is set
%% beside. It measures and asserts nothing, so it is not part of `make
%% test`.
-module(ern_node_costs).

-export([main/1]).

-define(ERN, filename:absname("../bin/ern")).
-define(LIBRARIES, [filename:absname("../build/libs/" ++ Library)
                    || Library <- ["balancer", "json", "load"]]).

%% Prints the table, the nodes' directories under Dir, and halts.
-spec main([string()]) -> no_return().
main([Dir]) ->
    _ = file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Root = filename:absname(filename:join(Dir, "build")),
    0 = ern_cli:ern(["build", "--build-root", Root] ++ load_path() ++ ["peers"],
                    group_leader()),
    {ok, _} = compile:file("peers/ern_peers_host.erl", [{outdir, Root}]),
    {Store, Desk} = configured(filename:absname(Dir)),
    Stopped = started(Store, filename:join(Root, "store.erc")),
    Costs = desk_costs(Desk, filename:join(Root, "desk.erc")),
    Stopped(),
    Tcp = tcp_ping(),
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
            {"  beside the host's ping", maps:get("spawn", Costs) / Ping, ratio}],
    io:format("~-48s ~12s~n", ["between two nodes on this machine", "µs or ratio"]),
    lists:foreach(fun({Name, Value, none}) -> io:format("~-48ts ~12.1f~n", [Name, Value]);
                     ({Name, Value, ratio}) -> io:format("~-48ts ~11.1fx~n", [Name, Value])
                  end, Rows),
    halt(0).

load_path() ->
    lists:append([["--load-path", Library] || Library <- ?LIBRARIES]).

%% The store, which listens, and the desk, which lists it, each a directory
%% `ern config` made, the desk's services naming the store for each it
%% times.
configured(Dir) ->
    Store = filename:join(Dir, "store"),
    Desk = filename:join(Dir, "desk"),
    _ = ern_node:create(Store),
    _ = ern_node:create(Desk),
    Port = free_port(),
    edit(Store, fun(Conf) ->
                    Conf#{<<"listen">> => address(Port),
                          <<"peers">> => [#{<<"name">> => <<"desk">>,
                                            <<"public-key">> => public(Desk)}]}
                end),
    Services = [<<"counter">>, <<"brittle">>, <<"echo">>, <<"echo-adapted">>],
    edit(Desk, fun(Conf) ->
                   (maps:remove(<<"listen">>, Conf))#{
                       <<"peers">> => [#{<<"name">> => <<"store">>,
                                         <<"public-key">> => public(Store),
                                         <<"network-address">> => address(Port)}],
                       <<"services">> => maps:from_list([{Name, [<<"store">>]}
                                                         || Name <- Services])}
               end),
    {Store, Desk}.

free_port() ->
    {ok, Socket} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Socket),
    ok = gen_tcp:close(Socket),
    Port.

address(Port) ->
    list_to_binary("127.0.0.1:" ++ integer_to_list(Port)).

edit(Dir, Change) ->
    File = filename:join(Dir, "ernest.conf"),
    {ok, Text} = file:read_file(File),
    ok = file:write_file(File, json:encode(Change(json:decode(Text)))).

public(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    maps:get(<<"public-key">>, json:decode(Text)).

%% The store running, once it has made its offers; answers what ends it.
started(Store, Program) ->
    Command = lists:flatten([?ERN, " run --config-dir ", Store,
                             [[" ", Word] || Word <- load_path()], " ", Program,
                             " 2> ", Store, ".err"]),
    Port = open_port({spawn_executable, "/bin/sh"}, [{args, ["-c", Command]}, exit_status, binary]),
    offered(Port, <<>>),
    fun() ->
        {ok, Pid} = file:read_file(filename:join(Store, "ernest.pid")),
        _ = os:cmd("kill -TERM " ++ string:trim(binary_to_list(Pid))),
        receive {Port, {exit_status, _}} -> ok end
    end.

%% Until the store says on its standard output, which the port reads, that
%% it has made its offers.
offered(Port, Said) ->
    case binary:match(Said, <<"offered">>) of
        nomatch ->
            receive {Port, {data, Bytes}} -> offered(Port, <<Said/binary, Bytes/binary>>) end;
        _ -> ok
    end.

%% The desk's lines, `key microseconds`, as a map.
desk_costs(Desk, Program) ->
    Said = os:cmd(lists:flatten([?ERN, " run --config-dir ", Desk,
                                 [[" ", Word] || Word <- load_path()], " ", Program,
                                 " costs 2>/dev/null"])),
    maps:from_list([{Key, list_to_float(Value)}
                    || Line <- string:lexemes(Said, "\n"),
                       [Key, Value] <- [string:lexemes(Line, " ")]]).

%% The microseconds of the host's ping between two plain nodes of its own,
%% over TCP, the second started first and ended by the first once it has
%% timed it.
tcp_ping() ->
    Cookie = "ern_node_costs",
    %% the second says so once its distribution has started
    Second = open_port({spawn_executable, os:find_executable("erl")},
                       [{args, ["-sname", "ern_costs_b", "-setcookie", Cookie, "-noinput",
                                "-eval", "io:format(\"up~n\")"]},
                        exit_status, binary]),
    receive {Second, {data, <<"up", _/binary>>}} -> ok end,
    Timing = "[_, Host] = string:split(atom_to_list(node()), \"@\"),"
             " Other = list_to_atom(\"ern_costs_b@\" ++ Host),"
             " pong = net_adm:ping(Other),"
             " Started = erlang:monotonic_time(microsecond),"
             " [pong = net_adm:ping(Other) || _ <- lists:seq(1, 5000)],"
             " io:format(\"~p~n\", [(erlang:monotonic_time(microsecond) - Started) / 5000]),"
             " rpc:call(Other, erlang, halt, []), halt().",
    Said = os:cmd(lists:flatten(["erl -sname ern_costs_a -setcookie ", Cookie,
                                 " -noinput -eval '", Timing, "'"])),
    receive {Second, {exit_status, _}} -> ok end,
    list_to_float(string:trim(Said)).
