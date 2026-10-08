%% The terminal path of report §8.2, through the pseudo-terminal harness
%% `ern_pty.py`: keys as they are pressed, nothing echoed, `Escape`
%% delivered once no sequence can follow it, and line mode with echo
%% restored when the program ends. Erlang cannot open a pseudo-terminal, so
%% these tests drive one from outside. Plan, MVP 2.6.
-module(ern_terminal_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CLEAR, <<"\e[2J\e[H">>).

%% report §8.2, Appendix E.16: every key pressed reaches the subscriber, a character
%% as itself, an arrow whole rather than as Escape and two characters, and
%% an Escape that stands alone as the key; nothing is echoed. The terminal
%% answers its size, and a window that changes arrives as `Resized`. A
%% paste arrives as one `Pasted` with its line endings as line feeds, not
%% as the keys of its characters.
keys_test_() ->
    {timeout, 60, fun keys/0}.

keys() ->
    ok = build("terminal/probe.ern", "terminal"),
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
    %% report Appendix E.16: the size the program was given, its keys, and the new
    %% size when the window changed; nothing was echoed, since an echoed key
    %% would stand in a line of its own or before the line the program
    %% printed, and these are all the lines
    ?assertEqual([<<"ready 24x80">>, <<"char x">>, <<"up">>, <<"down">>,
                  <<"resized 30x100">>, <<"pasted a|b">>, <<"escape">>], Lines),
    %% an arrow is not split: no Escape arrived before the one that was sent
    ?assertEqual(1, ern_pty:count(Screen, <<"escape">>)).

%% report §8.2: a paste whose end the terminal does not send ends when no
%% more of it arrives, and the keys after it are keys; an end that comes
%% later is nothing, which a key after it, shown, marks. A regression test:
%% the paste took in every key after it
unended_paste_test_() ->
    {timeout, 60, fun unended_paste/0}.

unended_paste() ->
    ok = build("terminal/probe.ern", "terminal"),
    {0, Screen} = pty("../bin/ern run build/terminal/probe.erc",
                      [{expect, "ready"},
                       {send, "1b5b3230307e6869"},    % a paste's start, and `hi`
                       {expect, "pasted hi"},
                       {send, "78"},                  % x
                       {expect, "char x"},
                       {send, "1b5b3230317e"},        % the paste's end, too late
                       {send, "79"},                  % y
                       {expect, "char y"},
                       {send, "1b"}],
                      15),
    ?assertEqual([<<"ready 24x80">>, <<"pasted hi">>, <<"char x">>, <<"char y">>,
                  <<"escape">>],
                 lines(Screen)).

%% report §8.2, Appendix E.16: where standard input is not a terminal a
%% subscription is refused, and the program goes on to say so; where
%% standard output is not one, the size is `Left(NotATerminal)`, a
%% regression test of the rule of 2026-10-01, before which it was `None`
not_a_terminal_test_() ->
    {timeout, 60, fun not_a_terminal/0}.

not_a_terminal() ->
    ok = build("terminal/probe.ern", "terminal"),
    ?assertEqual({0, <<"no terminal, no size\n">>},
                 ern_pty:sh("echo x | ../bin/ern run build/terminal/probe.erc")).

%% report §8.2, Appendix E.16: with standard input a terminal, the size is
%% `Left(NotATerminal)` where standard output is a pipe, and where the
%% terminal has no rows or no columns, though keys are read in both. A
%% regression test: the host answered the terminal's size through a pipe,
%% so the shell painted its region into it
no_size_test_() ->
    {timeout, 60, fun no_size/0}.

no_size() ->
    ok = build("terminal/probe.ern", "terminal"),
    Steps = [{expect, "ready"}, {send, "1b"}, {expect, "escape"}],
    {0, Piped} = pty("../bin/ern run build/terminal/probe.erc | cat", Steps, 30),
    ?assertEqual([<<"ready no size">>, <<"escape">>], lines(Piped)),
    {0, Sizeless} = ern_pty:run("../bin/ern run build/terminal/probe.erc", Steps, 30,
                                " --size 0x0"),
    ?assertEqual([<<"ready no size">>, <<"escape">>], lines(Sizeless)).

%% report §11.2: at a terminal a fault line is as the reader watches it
%% happen, without the time it begins with in a file. Written with the code.
unstamped_at_a_terminal_test_() ->
    {timeout, 60, fun unstamped_at_a_terminal/0}.

unstamped_at_a_terminal() ->
    ok = build("terminal/faulty.ern", "terminal"),
    {1, Screen} = pty("../bin/ern run build/terminal/faulty.erc",
                      [{expect, "division by zero"}], 30),
    ?assertMatch({match, _}, re:run(Screen, "^Faulty\\.main faulted: division by zero",
                                    [multiline])).

%% report §8.2: a key is read as UTF-8 whatever the host's locale, and the
%% terminal's interrupt arrives as `Interrupt` to a program that reads
%% keys. A regression test: the interrupt's signal was turned back on for
%% all but the shell, and ended such a program, where §8.2 delivers it
utf8_key_interrupt_test_() ->
    {timeout, 60, fun utf8_key_interrupt/0}.

utf8_key_interrupt() ->
    ok = build("terminal/probe.ern", "terminal"),
    {Status, Screen} = pty("LANG=C ../bin/ern run build/terminal/probe.erc",
                           [{expect, "ready"},
                            {send, "c3a9"},     % é, two bytes
                            {expect, "char"},
                            {send, "03"},       % the interrupt
                            {expect, "interrupt"},
                            {send, "1b"}],      % Escape ends the probe
                           15),
    ?assertMatch({_, _}, binary:match(Screen, <<"char ", 16#e9/utf8>>)),
    ?assertEqual(0, Status).

%% report §8.2: the runtime restores line mode with echo when the program
%% ends, so the terminal is the one the program found
terminal_restored_test_() ->
    {timeout, 60, fun terminal_restored/0}.

terminal_restored() ->
    ok = build("terminal/probe.ern", "terminal"),
    {_, Screen} = pty("stty -a; ../bin/ern run build/terminal/probe.erc; stty -a",
                      [{expect, "ready"}, {send, "1b"}], 15),
    %% the terminal is described before and after, and is never left without
    %% echo; `-echoe` and its like are not `-echo`
    ?assert(ern_pty:count(
        Screen, <<"ready">>) =:= 1 andalso ern_pty:count(Screen, <<"escape">>) =:= 1),
    ?assertEqual(nomatch, re:run(Screen, "(^|[ \t])-echo([ \t;\r\n]|$)", [{capture, none}])),
    ?assert(ern_pty:count(Screen, <<"speed">>) >= 2).

%% report §8.6: the terminal's settings a program found are the ones it
%% leaves, not stty's defaults. A regression test: the end ran `stty sane`,
%% which turned off the user's `tostop` among others. The
%% program's output goes through a pipe, since the host puts back the
%% terminal it found as it halts where its own output is the terminal
settings_kept_test_() ->
    {timeout, 60, fun settings_kept/0}.

settings_kept() ->
    ok = build("terminal/probe.ern", "terminal"),
    {_, Screen} = pty("stty tostop; ../bin/ern run build/terminal/probe.erc | cat; stty -a",
                      [{expect, "ready"}, {send, "1b"}], 15),
    ?assertMatch({match, _}, re:run(Screen, "(^|[ \t])tostop([ \t;\r\n]|$)")),
    ?assertEqual(nomatch, re:run(Screen, "-tostop", [{capture, none}])).

%% report §8.2, Appendix E.16, and MVP 2.5's manual check: the game is
%% played by the arrows, `Escape` leaves, and the board's rows each start at
%% the left, which full raw mode would have broken
snake_test_() ->
    {timeout, 60, fun snake/0}.

snake() ->
    ok = build("../examples/snake.ern", "../examples"),
    %% the board is drawn before the first key, and a move is given fifteen
    %% of the game's ticks to show, which its status line counts.
    %% It runs the program compiled here, not one another suite left in
    %% build/, which a run of this area alone does not have
    {0, Screen} = pty("../bin/ern run --load-path ../build/libs/ansi build/examples/snake.erc",
                      [{expect, "tick "},
                       {send, "1b5b42"},    % ArrowDown
                       {expect, "tick 15 "},
                       {send, "1b5b44"},    % ArrowLeft
                       {expect, "tick 30 "},
                       {send, "1b"}],       % Escape
                      15),
    %% the frames that show the board, however many the game drew between
    %% the keys: under the host's modified timing, fewer
    Boards = [Frame || Frame <- binary:split(Screen, ?CLEAR, [global]),
                       binary:match(Frame, <<"@">>) =/= nomatch],
    ?assertMatch({_, _}, binary:match(hd(Boards), <<"\r\n">>)),
    ?assertMatch({_, _}, binary:match(hd(Boards), <<"tick ">>)),
    %% down first, then left: the head's row changes, and after that its
    %% column shrinks
    Heads = [head(Board) || Board <- Boards],
    {_, StartRow} = hd(Heads),
    {_, [{Turned, _} | After]} = lists:splitwith(fun({_, RowIndex}) ->
                                                     RowIndex =:= StartRow
                                                 end, Heads),
    ?assert(lists:any(fun({Column, _}) -> Column < Turned end, After)).

%% report §8.2: C-c, which the terminal delivers as `Interrupt` while a
%% subscriber claims it, leaves the game as `Escape` does. A regression
%% test: the game ignored it
snake_interrupt_test_() ->
    {timeout, 60, fun snake_interrupt/0}.

snake_interrupt() ->
    ok = build("../examples/snake.ern", "../examples"),
    {0, _} = pty("../bin/ern run --load-path ../build/libs/ansi build/examples/snake.erc",
                 [{expect, "tick "}, {send, "03"}],
                 15).

%% The head's column and row in a frame.
head(Frame) ->
    Rows = binary:split(Frame, <<"\r\n">>, [global]),
    hd([{Column, RowIndex} || {RowIndex, Row} <- lists:zip(lists:seq(0, length(Rows) - 1), Rows),
                              {Column, _} <- [binary:match(Row, <<"@">>)]]).

build(Source, SourceRoot) ->
    {0, _} = ern_pty:sh(
        "../bin/ern build --source-root " ++ SourceRoot ++ " --load-path ../build/libs/ansi"
        ++ " --build-root build/"
        ++ filename:basename(SourceRoot) ++ " " ++ Source),
    ok.

%% A command with a terminal of its own: {exit status, the screen}.
pty(Command, Steps, Seconds) ->
    ern_pty:run(Command, Steps, Seconds, "").

lines(Screen) ->
    [Line || Line <- binary:split(modeless(Screen), <<"\r\n">>, [global]), Line =/= <<>>].

%% Report §8.2: what the runtime says to the terminal itself, the
%% bracketed-paste mode, which a terminal takes and shows nothing of.
modeless(Screen) ->
    re:replace(Screen, "\e\\[\\?[0-9]+[hl]", "", [global, {return, binary}]).

