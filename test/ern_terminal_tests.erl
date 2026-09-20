%% The terminal path of report §8.2, through the pseudo-terminal harness
%% `ern_pty.py`: keys as they are pressed, nothing echoed, `Escape`
%% delivered once no sequence can follow it, and line mode with echo
%% restored when the program ends. Erlang cannot open a pseudo-terminal, so
%% these tests drive one from outside. Plan, MVP 2.6.
-module(ern_terminal_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CLEAR, <<"\e[H\e[2J">>).

%% report §8.2, §9.3: every key pressed reaches the subscriber, a character
%% as itself, an arrow whole rather than as Escape and two characters, and
%% an Escape that stands alone as the key; nothing is echoed
keys_test_() ->
    {timeout, 60, fun keys/0}.

keys() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {0, Screen} = pty("../bin/ern build/terminal/probe.erc",
                      [{expect, "ready"},
                       {send, "78"},        % x
                       {expect, "char x"},
                       {send, "1b5b41"},    % ArrowUp, in one burst
                       {expect, "up"},
                       {send, "1b5b42"},    % ArrowDown
                       {expect, "down"},
                       {send, "1b"}],       % Escape, alone
                      15),
    Lines = lines(Screen),
    ?assertEqual([<<"ready">>, <<"char x">>, <<"up">>, <<"down">>, <<"escape">>], Lines),
    %% not echoed: the only x on the screen is the one the program printed
    ?assertEqual(1, count(Screen, <<"x">>)),
    %% an arrow is not split: no Escape arrived before the one that was sent
    ?assertEqual(1, count(Screen, <<"escape">>)).

%% report §8.2: the runtime restores line mode with echo when the program
%% ends, so the terminal is the one the program found
terminal_restored_test_() ->
    {timeout, 60, fun terminal_restored/0}.

terminal_restored() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {_, Screen} = pty("stty -a; ../bin/ern build/terminal/probe.erc; stty -a",
                      [{expect, "ready"}, {send, "1b"}], 15),
    %% the terminal is described before and after, and is never left without
    %% echo; `-echoe` and its like are not `-echo`
    ?assert(count(Screen, <<"ready">>) =:= 1 andalso count(Screen, <<"escape">>) =:= 1),
    ?assertEqual(nomatch, re:run(Screen, "(^|[ \t])-echo([ \t;\r\n]|$)", [{capture, none}])),
    ?assert(count(Screen, <<"speed">>) >= 2).

%% report §8.2, §9.3, and plan MVP 2.5 step 4's manual check: the game is
%% played by the arrows, `Escape` leaves, and the board's rows each start at
%% the left, which full raw mode would have broken
snake_test_() ->
    {timeout, 60, fun snake/0}.

snake() ->
    ok = compile("../examples/snake.ern", "../examples"),
    %% the board is drawn before the first key, and a move is given a few
    %% ticks to show: the game's own clock is what those sleeps wait for
    {0, Screen} = pty("../bin/ern build/snake.erc",
                      [{expect, "tick "},
                       {send, "1b5b42"},    % ArrowDown
                       {sleep, 1500},
                       {send, "1b5b44"},    % ArrowLeft
                       {sleep, 1500},
                       {send, "1b"}],       % Escape
                      15),
    Frames = binary:split(Screen, ?CLEAR, [global]),
    ?assert(length(Frames) > 20),
    Frame = lists:nth(3, Frames),
    ?assertMatch({_, _}, binary:match(Frame, <<"\r\n">>)),
    ?assertMatch({_, _}, binary:match(Frame, <<"tick ">>)),
    %% down first, then left: the head's row grows, then its column shrinks
    {_, Y1} = head(lists:nth(8, Frames)),
    {X2, Y2} = head(lists:nth(18, Frames)),
    {X3, _} = head(lists:nth(28, Frames)),
    ?assert(Y2 =/= Y1),
    ?assert(X3 < X2).

%% The head's column and row in a frame.
head(Frame) ->
    Rows = binary:split(Frame, <<"\r\n">>, [global]),
    hd([{X, Y} || {Y, Row} <- lists:zip(lists:seq(0, length(Rows) - 1), Rows),
                  {X, _} <- [binary:match(Row, <<"@">>)]]).

compile(Source, Root) ->
    {0, _} = sh("../bin/ernc --source-root " ++ Root ++ " --out-dir build/"
                ++ filename:basename(Root) ++ " " ++ Source),
    ok.

%% A command with a terminal of its own: {exit status, the screen}. The
%% steps are the harness's, `{expect, Text}` before a `{send, Hex}` so
%% that a program slower under load is waited for rather than raced. The
%% command is one word to the shell that starts the harness, since its own
%% `;` and `|` belong to the shell inside the terminal; it may hold no
%% single quote.
pty(Command, Steps, Seconds) ->
    nomatch = binary:match(list_to_binary(Command), <<"'">>),
    File = steps_file(Steps),
    {0, Out} = sh("./ern_pty.py --timeout " ++ integer_to_list(Seconds) ++ " --steps " ++ File
                  ++ " -- '" ++ Command ++ "'"),
    Lines = [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    %% a step the harness could not meet is a failure of the test, not a
    %% screen to assert against
    ?assertEqual([], [L || <<"unmet ", _/binary>> = L <- Lines]),
    [<<"status ", Status/binary>>] = [L || <<"status ", _/binary>> = L <- Lines],
    [<<"data ", Data/binary>>] = [L || <<"data ", _/binary>> = L <- Lines],
    {status(Status), base64:decode(Data)}.

%% The steps go in a file: one holds whatever the program prints, and a
%% shell reading `>` would take it for a redirection.
steps_file(Steps) ->
    File = "build/steps-" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, [[step(S), "\n"] || S <- Steps]),
    File.

step({expect, Text}) -> "expect:" ++ Text;
step({send, Hex}) -> "send:" ++ Hex;
step({sleep, Ms}) -> "sleep:" ++ integer_to_list(Ms).

status(<<"timeout">>) -> timeout;
status(Bin) -> binary_to_integer(Bin).

lines(Screen) ->
    [L || L <- binary:split(Screen, <<"\r\n">>, [global]), L =/= <<>>].

count(Haystack, Needle) ->
    length(binary:matches(Haystack, Needle)).

sh(Cmd) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
