%% The shell (report §11.2), through a session: a file of inputs in line
%% mode against a file of expected output, which is what the design note
%% calls a session golden test.
-module(ern_shell_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.2, §11.5: an expression prints its value and its type, one of
%% type Unit prints nothing, an input that does not check shows the error
%% ernc shows, and a fault is reported without ending the session; a `let`
%% binds for the inputs after it and `it` is the last value; an input
%% declares what a module may, a later declaration of a name shadowing the
%% one before it, and what it declared is printed a line for each; and
%% report §4.4, an abstract type's constructor is the input's that declared
%% it. The commands are here too: `:type`, `:browse`, `:doc`, `:help`,
%% `:forget`, `:bindings`, `:set` with the depth and the length a value is
%% printed to, and a prefix of any of them
session_test_() ->
    {timeout, 60, fun session/0}.

session() ->
    {0, Out} = sh("../bin/ern --shell < session/basic.in"),
    {ok, Expected} = file:read_file("session/basic.out"),
    ?assertEqual(Expected, Out).

%% report §11.2, §8.1, §6.9: with a file the shell is the entry point and
%% the file's entry point is spawned beside it; the loaded modules are in
%% scope, by their qualified names; every process that faults is reported
%% at the prompt with its spawn site, the program's own and one spawned at
%% the prompt alike, without ending the session; `:processes` lists what is
%% live and leaves the shell's own out, and `:faults` what has faulted
program_test_() ->
    {timeout, 60, fun program/0}.

program() ->
    {0, _} = sh("../bin/ernc --source-root session --out-dir build/session"
                " session/counter.ern"),
    {0, Out} = sh("../bin/ern --shell build/session/counter.erc < session/program.in"),
    {ok, Expected} = file:read_file("session/program.out"),
    ?assertEqual(Expected, Out).

%% report §11.2: on a terminal the shell reads keys, echoes what is typed,
%% takes Backspace and C-d, and reads the interrupt as a key, which kills a
%% running input and leaves the session standing
terminal_test_() ->
    {timeout, 60, fun terminal/0}.

terminal() ->
    Long = "List.foldLeft(List.range(1, 200000000), 0, fn(a, b) = a + b)",
    %% the gaps are wide because each input is checked and compiled before
    %% it runs, and the interrupt must arrive while the long one is running
    Screen = pty("../bin/ern --shell",
                 [{800, hex("1 + 5")},
                  {1200, hex([127]) ++ hex("2\r")},     % Backspace, then 2, Enter
                  {2000, hex(Long ++ "\r")},
                  {4500, "03"},                         % the interrupt
                  {5500, hex("1 + 1\r")},
                  {7000, "04"}],                        % C-d on an empty line
                 11),
    ?assertMatch({_, _}, binary:match(Screen, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Screen, <<"Killed">>)),
    ?assertMatch({_, _}, binary:match(Screen, <<"2 : Int">>)),
    %% the interrupt reached the shell as a key; the session was not ended
    ?assertEqual(1, length(binary:matches(Screen, <<"Ernest ">>))).

hex(Text) ->
    lists:flatten([io_lib:format("~2.16.0b", [C]) || C <- Text]).

pty(Command, Sends, Seconds) ->
    Args = [" --send " ++ integer_to_list(Ms) ++ ":" ++ Hex || {Ms, Hex} <- Sends],
    {0, Out} = sh("./ern_pty.py --timeout " ++ integer_to_list(Seconds) ++ Args
                  ++ " -- " ++ Command),
    [_, <<"data ", Data/binary>>] =
        [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    base64:decode(Data).

sh(Cmd) ->
    Port = open_port({spawn, "sh -c '" ++ Cmd ++ "'"}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
