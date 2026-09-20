%% The shell (report §11.2), through a session: a file of inputs in line
%% mode against a file of expected output, which is what the design note
%% calls a session golden test. Checkpoint 0 is expressions only.
-module(ern_shell_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.2, §11.5: an expression prints its value and its type, one of
%% type Unit prints nothing, an input that does not check shows the error
%% ernc shows, and a fault is reported without ending the session
session_test_() ->
    {timeout, 60, fun session/0}.

session() ->
    {0, Out} = sh("../bin/ern --shell < session/basic.in"),
    {ok, Expected} = file:read_file("session/basic.out"),
    ?assertEqual(Expected, Out).

sh(Cmd) ->
    Port = open_port({spawn, "sh -c '" ++ Cmd ++ "'"}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
