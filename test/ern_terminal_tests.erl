%% The terminal path of report §8.2, through the pseudo-terminal harness
%% `ern_pty.py`: keys as they are pressed, nothing echoed, `Escape`
%% delivered once no sequence can follow it, and line mode with echo
%% restored when the program ends. Erlang cannot open a pseudo-terminal, so
%% these tests drive one from outside. Plan, MVP 2.6.
-module(ern_terminal_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CLEAR, <<"\e[2J\e[H">>).

%% report §8.2, §9.3: every key pressed reaches the subscriber, a character
%% as itself, an arrow whole rather than as Escape and two characters, and
%% an Escape that stands alone as the key; nothing is echoed. The terminal
%% answers its size, and a window that changes arrives as `Resized`. A
%% paste arrives as one `Pasted` with its line endings as line feeds, not
%% as the keys of its characters.
keys_test_() ->
    {timeout, 60, fun keys/0}.

keys() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {0, Screen} = pty("../bin/ern run build/terminal/probe.erc",
                      [{expect, "ready"},
                       {send, "78"},        % x
                       {expect, "char x"},
                       {send, "1b5b41"},    % ArrowUp, in one burst
                       {expect, "up"},
                       {send, "1b5b42"},    % ArrowDown
                       {expect, "down"},
                       {resize, "30x100"},
                       {expect, "resized"},
                       %% a paste, its two lines separated as a terminal
                       %% sends them, between the brackets §8.2 asks for
                       {send, "1b5b3230307e61" ++ "0d" ++ "621b5b3230317e"},
                       {expect, "pasted"},
                       {send, "1b"}],       % Escape, alone
                      15),
    Lines = lines(Screen),
    %% report §9.3: the size the program was given, its keys, and the new
    %% size when the window changed
    ?assertEqual([<<"ready 24x80">>, <<"char x">>, <<"up">>, <<"down">>,
                  <<"resized 30x100">>, <<"pasted a|b">>, <<"escape">>], Lines),
    %% nothing was echoed: an echoed key would stand in a line of its own
    %% or before the line the program printed, and the lines above are all
    %% of them
    %% an arrow is not split: no Escape arrived before the one that was sent
    ?assertEqual(1, count(Screen, <<"escape">>)).

%% report §8.2: a paste whose end the terminal does not send ends when no
%% more of it arrives, and the keys after it are keys; an end that comes
%% later is nothing. A regression test: the paste took in every key after
%% it (findings C31)
unended_paste_test_() ->
    {timeout, 60, fun unended_paste/0}.

unended_paste() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {0, Screen} = pty("../bin/ern run build/terminal/probe.erc",
                      [{expect, "ready"},
                       {send, "1b5b3230307e6869"},    % a paste's start, and `hi`
                       {expect, "pasted hi"},
                       {send, "78"},                  % x
                       {expect, "char x"},
                       {send, "1b5b3230317e"},        % the paste's end, too late
                       {sleep, 300},
                       {send, "1b"}],
                      15),
    ?assertEqual([<<"ready 24x80">>, <<"pasted hi">>, <<"char x">>, <<"escape">>],
                 lines(Screen)).

%% report §8.2, Appendix E.16: where standard input is not a terminal a
%% subscription is refused, and the program goes on to say so
not_a_terminal_test_() ->
    {timeout, 60, fun not_a_terminal/0}.

not_a_terminal() ->
    ok = compile("terminal/probe.ern", "terminal"),
    ?assertEqual({0, <<"no terminal\n">>},
                 sh("echo x | ../bin/ern run build/terminal/probe.erc")).

%% report §11.2: at a terminal a fault line is as the reader watches it
%% happen, without the time it begins with in a file. Written with the code.
unstamped_at_a_terminal_test_() ->
    {timeout, 60, fun unstamped_at_a_terminal/0}.

unstamped_at_a_terminal() ->
    ok = compile("terminal/faulty.ern", "terminal"),
    {1, Screen} = pty("../bin/ern run build/terminal/faulty.erc",
                      [{expect, "division by zero"}], 30),
    ?assertMatch({match, _}, re:run(Screen, "^Faulty\\.main faulted: division by zero",
                                    [multiline])).

%% report §8.2, §8.6: a key is read as UTF-8 whatever the host's locale,
%% and the terminal's interrupt ends a program that reads keys at once. A
%% regression test for the raw mode set by stty alone, which turns the
%% interrupt off unless it is asked back
utf8_key_interrupt_test_() ->
    {timeout, 60, fun utf8_key_interrupt/0}.

utf8_key_interrupt() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {Status, Screen} = pty("LANG=C ../bin/ern run build/terminal/probe.erc",
                           [{expect, "ready"},
                            {send, "c3a9"},     % é, two bytes
                            {expect, "char"},
                            {send, "03"}],      % the interrupt
                           15),
    ?assertMatch({_, _}, binary:match(Screen, <<"char ", 16#e9/utf8>>)),
    %% the interrupt ended the program rather than arriving as a key, which
    %% the probe would print; the harness interrupts a program that is left
    ?assertEqual(nomatch, binary:match(Screen, <<"interrupt">>)),
    %% the harness gives a program a signal ended as minus its number
    ?assertEqual(-2, Status).

%% report §8.2: the runtime restores line mode with echo when the program
%% ends, so the terminal is the one the program found
terminal_restored_test_() ->
    {timeout, 60, fun terminal_restored/0}.

terminal_restored() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {_, Screen} = pty("stty -a; ../bin/ern run build/terminal/probe.erc; stty -a",
                      [{expect, "ready"}, {send, "1b"}], 15),
    %% the terminal is described before and after, and is never left without
    %% echo; `-echoe` and its like are not `-echo`
    ?assert(count(Screen, <<"ready">>) =:= 1 andalso count(Screen, <<"escape">>) =:= 1),
    ?assertEqual(nomatch, re:run(Screen, "(^|[ \t])-echo([ \t;\r\n]|$)", [{capture, none}])),
    ?assert(count(Screen, <<"speed">>) >= 2).

%% report §8.6: the terminal's settings a program found are the ones it
%% leaves, not stty's defaults. A regression test: the end ran `stty sane`,
%% which turned off the user's `tostop` among others (findings C20). The
%% program's output goes through a pipe, since the host puts back the
%% terminal it found as it halts where its own output is the terminal
settings_kept_test_() ->
    {timeout, 60, fun settings_kept/0}.

settings_kept() ->
    ok = compile("terminal/probe.ern", "terminal"),
    {_, Screen} = pty("stty tostop; ../bin/ern run build/terminal/probe.erc | cat; stty -a",
                      [{expect, "ready"}, {send, "1b"}], 15),
    ?assertMatch({match, _}, re:run(Screen, "(^|[ \t])tostop([ \t;\r\n]|$)")),
    ?assertEqual(nomatch, re:run(Screen, "-tostop", [{capture, none}])).

%% report §8.2, §9.3, and MVP 2.5's manual check: the game is
%% played by the arrows, `Escape` leaves, and the board's rows each start at
%% the left, which full raw mode would have broken
snake_test_() ->
    {timeout, 60, fun snake/0}.

snake() ->
    ok = compile("../examples/snake.ern", "../examples"),
    %% the board is drawn before the first key, and a move is given a few
    %% ticks to show: the game's own clock is what those sleeps wait for.
    %% It runs the program compiled here, not one another suite left in
    %% build/, which a run of this area alone does not have
    {0, Screen} = pty("../bin/ern run build/examples/snake.erc",
                      [{expect, "tick "},
                       {send, "1b5b42"},    % ArrowDown
                       {sleep, 1500},
                       {send, "1b5b44"},    % ArrowLeft
                       {sleep, 1500},
                       {send, "1b"}],       % Escape
                      15),
    %% the frames that show the board, however many the game drew between
    %% the keys: under the host's modified timing, fewer
    Boards = [F || F <- binary:split(Screen, ?CLEAR, [global]),
                   binary:match(F, <<"@">>) =/= nomatch],
    ?assertMatch({_, _}, binary:match(hd(Boards), <<"\r\n">>)),
    ?assertMatch({_, _}, binary:match(hd(Boards), <<"tick ">>)),
    %% down first, then left: the head's row changes, and after that its
    %% column shrinks
    Heads = [head(B) || B <- Boards],
    {_, Y0} = hd(Heads),
    {_, [{Turned, _} | After]} = lists:splitwith(fun({_, Y}) -> Y =:= Y0 end, Heads),
    ?assert(lists:any(fun({X, _}) -> X < Turned end, After)).

%% The head's column and row in a frame.
head(Frame) ->
    Rows = binary:split(Frame, <<"\r\n">>, [global]),
    hd([{X, Y} || {Y, Row} <- lists:zip(lists:seq(0, length(Rows) - 1), Rows),
                  {X, _} <- [binary:match(Row, <<"@">>)]]).

compile(Source, Root) ->
    {0, _} = sh("../bin/ern build --source-root " ++ Root ++ " --build-root build/"
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
step({resize, Size}) -> "resize:" ++ Size;
step({send, Hex}) -> "send:" ++ Hex;
step({sleep, Ms}) -> "sleep:" ++ integer_to_list(Ms).

status(<<"timeout">>) -> timeout;
status(Bin) -> binary_to_integer(Bin).

lines(Screen) ->
    [L || L <- binary:split(modeless(Screen), <<"\r\n">>, [global]), L =/= <<>>].

%% Report §8.2: what the runtime says to the terminal itself, the
%% bracketed-paste mode, which a terminal takes and shows nothing of.
modeless(Screen) ->
    re:replace(Screen, "\e\\[\\?[0-9]+[hl]", "", [global, {return, binary}]).

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
