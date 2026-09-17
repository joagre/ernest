%% Plan 3.2: the MVP 1 programs compiled with bin/ernc and run with bin/ern
%% as a user would, output compared as a multiset of lines with
%% expected/<name>.out, since prints from different processes interleave
%% by scheduling. Run from this directory by its Makefile.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROGRAMS, ["hello", "counter", "counter_upgrade", "ping_pong", "stack", "patterns",
                   "kv_parser", "remote"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (ping_pong),
%% §6.6 (counter), §6.7 (remote), §6.10 (counter_upgrade), §5.10 (patterns),
%% §5.5 (kv_parser), §4.4 (stack)
programs_test_() ->
    [{Name, fun() -> program(Name) end} || Name <- ?PROGRAMS].

program(Name) ->
    {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/" ++ Name
                ++ ".ern"),
    {0, Out} = sh("../bin/ern build/" ++ Name ++ ".erc"),
    ?assertEqual(expected(Name), lines(Out)).

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test() ->
    {0, _} = sh("../bin/ernc --out-dir build/modules ../examples/modules"),
    {0, Out} = sh("../bin/ern build/modules/main.erc"),
    ?assertEqual(expected("modules"), lines(Out)).

expected(Name) ->
    {ok, Bin} = file:read_file("expected/" ++ Name ++ ".out"),
    lines(Bin).

lines(Bin) ->
    lists:sort(binary:split(Bin, <<"\n">>, [global, trim])).

sh(Cmd) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
