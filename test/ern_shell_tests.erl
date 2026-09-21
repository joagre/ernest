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
    %% not a golden: where a fault report lands among the inputs depends on
    %% when the process faults, and the session is asserted on rather than
    %% compared byte for byte
    ?assertMatch({_, _}, binary:match(Out, <<"c : Address(Counter.Msg)">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Some(7) : Optional(Int)">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Counter.start : () -> Address(Msg) with m">>)),
    %% what the program printed reached the screen
    ?assertMatch({_, _}, binary:match(Out, <<"worker here">>)),
    %% the program's entry point and a process spawned at the prompt, each
    %% reported once as it faults and once by `:faults`
    ?assertEqual(2, count(Out, <<"Counter.main faulted: division by zero">>)),
    ?assertEqual(2, count(Out, <<"main:1 faulted: division by zero">>)),
    %% `:processes` leaves the shell's own out, and the counter is still there
    ?assertMatch({_, _}, binary:match(Out, <<"Counter.start:10">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"Shell.main">>)).

count(Haystack, Needle) ->
    length(binary:matches(Haystack, Needle)).

%% report §11.2: at start the shell runs the inputs of the person's
%% startup file and then the node's, a line an input; a value is not
%% printed, a later file's binding shadows an earlier one's, and an input
%% that fails is reported with the file it came from and the session goes
%% on
startup_test_() ->
    {timeout, 60, fun startup/0}.

startup() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    Home = filename:join("/tmp", "ern_home_" ++ Unique),
    Node = filename:join("/tmp", "ern_node_" ++ Unique),
    ok = filelib:ensure_path(filename:join(Home, ".ernest")),
    ok = filelib:ensure_path(filename:join(Node, ".ernest")),
    ok = file:write_file(filename:join([Home, ".ernest", "startup"]),
                         "let greeting = \"from the user file\"\nlet shared = 1\n"),
    %% the node's file binds the same name, and holds a line that does not
    %% parse
    ok = file:write_file(filename:join([Node, ".ernest", "startup"]),
                         "let shared = 2\n1 +\n"),
    In = filename:join(Node, "session.in"),
    ok = file:write_file(In, "greeting\nshared\n"),
    {0, Out} = sh("HOME=" ++ Home ++ " ../bin/ern --shell --config-dir "
                  ++ filename:join(Node, ".ernest") ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"\"from the user file\" : String">>)),
    %% the node's file ran after the person's, so its binding is the one
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"startup:1:4: expected an expression">>)),
    %% what a startup input answered was not printed
    ?assertEqual(nomatch, binary:match(Out, <<"1 : Int">>)).

%% report §11.2: on a terminal the shell commits its transcript to the
%% terminal and paints only the live region, the tail of what programs
%% write and the line being typed under it. What a program writes is
%% never mixed into the line being typed, and the transcript reads in the
%% order the lines were written
live_region_test_() ->
    {timeout, 60, fun live_region/0}.

live_region() ->
    Print = "spawn(Local, fn() = List.foreach(List.range(1, 12),"
            " fn(n) = Io.println(\"line \" <> Int.toString(n))))\r",
    Screen = screen(alone("../bin/ern --shell"),
                    [{expect, "> "},
                     {send, hex("1 + 1\r")},
                     {expect, "2 : Int"},
                     {send, hex(Print)},
                     {sleep, 800},
                     {send, hex("2 + 2\r")},
                     {expect, "4 : Int"},
                     {send, "04"}],
                    20, "20x60"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% every line the program wrote reached the terminal, and in order
    ?assertMatch({_, _}, binary:match(Text, <<"line 1">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"line 12">>)),
    {At12, _} = binary:match(Text, <<"line 12">>),
    {AtFour, _} = binary:match(Text, <<"4 : Int">>),
    ?assert(At12 < AtFour),
    %% the shell's own is there too, and the region is left as one prompt
    ?assertMatch({_, _}, binary:match(Text, <<"2 : Int">>)),
    ?assertEqual(<<">">>, lists:last(Lines)).

%% report §11.2, §9.3: the pure parts of the shell test themselves, the
%% editor's function from a line and an event to what the reader must do,
%% the history file's escaping, and the region's geometry, run by
%% `ern --test` as the shell is built
editor_test_() ->
    {timeout, 60, fun editor/0}.

editor() ->
    {Status, Out} = sh("../bin/ern --test ../build/shell/shell/editor.erc"
                       " && ../bin/ern --test ../build/shell/shell/history.erc"
                       " && ../bin/ern --test ../build/shell/shell.erc"),
    Lines = [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    ?assertEqual([], [L || L <- Lines, binary:match(L, <<": passed">>) =:= nomatch]),
    ?assert(length(Lines) >= 10),
    ?assertEqual(0, Status).

%% report §11.2: the editor through the terminal, which is the wiring the
%% pure tests cannot reach: `C-w` kills the word before the cursor, `C-a`
%% and `C-e` go to the ends of the line, and what is typed goes in at the
%% cursor rather than at the end
editing_test_() ->
    {timeout, 60, fun editing/0}.

editing() ->
    Screen = pty(alone("../bin/ern --shell"),
                 [{expect, "> "},
                  {send, hex("1 + 22222")},
                  {expect, "22222"},
                  {send, hex([23])},                    % C-w kills the word
                  {send, hex("2\r")},
                  {expect, "3 : Int"},
                  {send, hex("0 + 2")},
                  {expect, "0 + 2"},
                  {send, hex([1]) ++ hex("4")},         % C-a, then a digit
                  {expect, "40 + 2"},
                  {send, hex([5]) ++ hex(" + 0\r")},    % C-e, then the rest
                  {expect, "42 : Int"},
                  {send, "04"}],
                 20),
    ?assertMatch({_, _}, binary:match(Screen, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Screen, <<"42 : Int">>)),
    %% the word was killed rather than the line: `1 + ` stayed
    ?assertEqual(nomatch, binary:match(Screen, <<"1 + 22222\r\n">>)).

%% report §11.2: `C-l` gives a clean screen and keeps the line being
%% typed; what was committed before it is the terminal's scrollback and
%% not on the screen any more
clear_test_() ->
    {timeout, 60, fun clear/0}.

clear() ->
    Screen = screen(alone("../bin/ern --shell"),
                    [{expect, "> "},
                     {send, hex("111 + 111\r")},
                     {expect, "222 : Int"},
                     {send, hex("7 + 7")},
                     {expect, "7 + 7"},
                     {send, "0c"},                      % C-l
                     {sleep, 500},
                     {send, hex("\r")},
                     {expect, "14 : Int"},
                     {send, "04"}],
                    20, "10x40"),
    %% the line being typed survived the clear and ran
    ?assertMatch({_, _}, binary:match(Screen, <<"14 : Int">>)),
    %% what was on the screen before it is gone
    ?assertEqual(nomatch, binary:match(Screen, <<"222 : Int">>)).

%% report §11.2: the inputs of a session are kept in the person's history
%% file, one a line, and the session after it walks them with the arrows
%% and searches them with `C-r`; a blank input and one repeated are not
%% kept, and a session whose input is not a terminal leaves the file alone
history_test_() ->
    {timeout, 90, fun history/0}.

history() ->
    Home = fresh_home(),
    File = filename:join([Home, ".ernest", "history"]),
    _ = pty("HOME=" ++ Home ++ " ../bin/ern --shell",
            [{expect, "> "},
             {send, hex("11 + 11\r")},
             {expect, "22 : Int"},
             {send, hex("33 + 33\r")},
             {expect, "66 : Int"},
             %% a blank input and the same input again are not kept
             {send, hex("\r")},
             {send, hex("33 + 33\r")},
             {expect, "66 : Int"},
             {send, "04"}],
            20),
    ?assertEqual([<<"11 + 11">>, <<"33 + 33">>], history_lines(File)),
    %% the session after it: the arrow recalls the last input, and `C-r`
    %% searches back for an older one
    Screen = pty("HOME=" ++ Home ++ " ../bin/ern --shell",
                 [{expect, "> "},
                  {send, "1b5b41"},                 % ArrowUp
                  {expect, "33 + 33"},
                  {send, hex("\r")},
                  {expect, "66 : Int"},
                  {send, "12"},                     % C-r
                  {send, hex("11")},
                  {expect, "11 + 11"},
                  {send, hex("\r")},
                  {expect, "22 : Int"},
                  {send, "04"}],
                 20),
    ?assertMatch({_, _}, binary:match(Screen, <<"reverse-i-search">>)),
    %% what the second session took is appended, and the input it repeated
    %% is not
    ?assertEqual([<<"11 + 11">>, <<"33 + 33">>, <<"11 + 11">>], history_lines(File)),
    %% a session that is not a terminal neither reads the file nor writes it
    {0, _} = sh("HOME=" ++ Home ++ " ../bin/ern --shell < session/basic.in"),
    ?assertEqual([<<"11 + 11">>, <<"33 + 33">>, <<"11 + 11">>], history_lines(File)).

history_lines(File) ->
    {ok, Text} = file:read_file(File),
    [L || L <- binary:split(Text, <<"\n">>, [global]), L =/= <<>>].

%% report §11.2: at a terminal an input may span lines. `Enter` takes
%% another line where the parser cannot finish the input and runs it
%% where it can, `M-Enter` takes one whatever the parser says, and
%% `Enter` on an empty line runs what there is, error and all. The first
%% such input of a session says how it is run, once, above the region.
%% The rows after the first are prompted `... `, and a multi-line input
%% comes back from the history whole
multiline_test_() ->
    {timeout, 90, fun multiline/0}.

multiline() ->
    Home = fresh_home(),
    Screen = screen("HOME=" ++ Home ++ " ../bin/ern --shell",
                    [{expect, "> "},
                     {send, hex("1 +\r")},                % the parser wants more
                     {expect, "... "},
                     {send, hex("2\r")},
                     {expect, "3 : Int"},
                     {send, hex("40 + 2")},
                     {expect, "40 + 2"},
                     {send, "1b0d"},                      % M-Enter on a complete input
                     {expect, "... "},
                     {send, hex("    + 0\r")},
                     {expect, "42 : Int"},
                     {send, hex("fn f(\r")},              % cannot parse, and unfinished
                     {sleep, 300},
                     {send, hex("\r")},                   % the blank line runs it
                     {expect, "expected a pattern"},
                     {send, "1b5b41"},                    % ArrowUp: the input back, whole
                     {sleep, 400},
                     {send, "04"}],
                    30, "16x46"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the hint is above the region and the prompt it was typed under stays
    ?assertEqual(1, count(Text, <<"M-Enter adds a line, Enter runs.">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"> 1 +">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"... 2">>)),
    %% `M-Enter` took a line the parser would have run
    ?assertMatch({_, _}, binary:match(Text, <<"42 : Int">>)),
    %% the blank line ran an input that cannot parse, and its error names
    %% the line the input was typed on
    ?assertMatch({_, _}, binary:match(Text, <<"expected a pattern">>)),
    %% the history brought the multi-line input back whole
    ?assertEqual([<<"1 +\\n2">>, <<"40 + 2\\n    + 0">>, <<"fn f(\\n">>],
                 history_lines(filename:join([Home, ".ernest", "history"]))),
    %% the screen is rendered without the spaces at a row's end
    ?assertMatch({_, _}, binary:match(lists:last(Lines), <<"...">>)).

%% report §11.2, §8.2: a paste goes into the line at the cursor and its
%% line feeds add lines, so a pasted two-line input is one input and runs
%% when `Enter` is pressed after it
paste_test_() ->
    {timeout, 90, fun paste/0}.

paste() ->
    Screen = screen(alone("../bin/ern --shell"),
                    [{expect, "> "},
                     %% \e[200~ 1 + <CR> 2 \e[201~
                     {send, "1b5b3230307e" ++ hex("1 +") ++ "0d" ++ hex("2") ++ "1b5b3230317e"},
                     {expect, "... 2"},
                     {send, hex("\r")},
                     {expect, "3 : Int"},
                     {sleep, 300},
                     {send, "04"}],
                    30, "12x40"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the paste took a row for its second line rather than running the first
    ?assertMatch({_, _}, binary:match(Text, <<"> 1 +">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"... 2">>)),
    ?assertEqual(1, count(Text, <<"3 : Int">>)),
    %% nothing ran before the paste was whole: `1 +` alone is an error
    ?assertEqual(nomatch, binary:match(Text, <<"expected an expression">>)).

%% report §11.2: a tab is painted as the spaces to the next stop, so
%% that the cursor is placed by the columns the row takes and not by the
%% characters in it; what is committed keeps the tab the person typed
tabs_test_() ->
    {timeout, 90, fun tabs/0}.

tabs() ->
    Screen = pty(alone("../bin/ern --shell"),
                 [{expect, "> "},
                  %% \e[200~ a <TAB> b \e[201~, which no key could send
                  {send, "1b5b3230307e" ++ hex("a\tb") ++ "1b5b3230317e"},
                  {sleep, 500},
                  {send, "03"},                       % abandon the line
                  {sleep, 300},
                  {send, "04"}],
                 30),
    %% "> " is two columns and "a" a third, so the tab paints five spaces
    ?assertMatch({_, _}, binary:match(Screen, <<"> a     b">>)),
    %% the line that joined the transcript holds the tab itself
    ?assertMatch({_, _}, binary:match(Screen, <<"> a\tb">>)).

%% report §11.2: the parser says when more input could finish what was
%% typed, and the shell asks it for each reading it would try
needs_more_test() ->
    ?assert(ern_shell:needs_more(<<"1 +">>)),
    ?assert(ern_shell:needs_more(<<"fn f() =">>)),
    ?assert(ern_shell:needs_more(<<"type Shape = Dot |">>)),
    ?assert(ern_shell:needs_more(<<"`a raw string">>)),
    ?assertNot(ern_shell:needs_more(<<"1 + 2">>)),
    ?assertNot(ern_shell:needs_more(<<"fn f() = 1">>)),
    ?assertNot(ern_shell:needs_more(<<"1 + * 2">>)),
    ?assertNot(ern_shell:needs_more(<<"\"a string">>)).

%% report §11.2, §6.10, §7.3: `:load` compiles a module from its source
%% under the source root and puts it in scope; `:reload` compiles again
%% what has changed, names what is still in the previous version, and ends
%% it on the reload that needs that version. The session rewrites the
%% source itself, with `Fs.write`, so the test needs no second process.
reload_test_() ->
    {timeout, 60, fun reload/0}.

reload() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    Dir = filename:join("/tmp", "ern_reload_" ++ Unique),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "demo.ern"), demo(1)),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, [":load Demo\n",
                              "Demo.answer()\n",
                              "spawn(Local, fn() = Demo.tick())\n",
                              write_demo(Dir, 2),
                              ":reload\n",
                              "Demo.answer()\n",
                              write_demo(Dir, 3),
                              ":reload\n",
                              "Demo.answer()\n",
                              ":processes\n"]),
    {0, Out} = sh("../bin/ern --shell --source-root " ++ Dir ++ " --load-path " ++ Dir
                  ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"Demo, compiled from demo.ern">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"1 : Int">>)),
    %% the first reload names what is still in the version it replaced
    ?assertMatch({_, _}, binary:match(Out, <<"a process in the previous version; a further"
                                             " reload of it ends them">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    %% the second ends it, and says so
    ?assertMatch({_, _}, binary:match(Out, <<"ended ">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"no process of the session's is running">>)).

demo(N) ->
    ["export fn answer() -> Int = ", integer_to_list(N), "\n\n",
     "export fn tick() -> Unit with Unit = {\n",
     "    Clock.alarm(50, fn(_) = Unit);\n",
     "    receive { _ -> Unit };\n",
     "    tick()\n",
     "}\n"].

%% An input that rewrites the module's source, so that the session is what
%% changes it (E.17).
write_demo(Dir, N) ->
    Text = lists:flatten(demo(N)),
    Escaped = lists:flatten([case C of $\n -> "\\n"; $" -> "\\\""; _ -> C end || C <- Text]),
    ["Fs.write(Path(\"", filename:join(Dir, "demo.ern"), "\"), String.toUtf8(\"", Escaped,
     "\"), 2000)\n"].

%% report §11.2: on a terminal the shell reads keys, echoes what is typed,
%% takes Backspace and C-d, and reads the interrupt as a key, which kills a
%% running input and leaves the session standing
terminal_test_() ->
    {timeout, 60, fun terminal/0}.

terminal() ->
    %% it says when it is running, so the interrupt is sent then and not
    %% on a guess at how long the checking took
    Long = "{ Io.println(\"running\"); List.foldLeft(List.range(1, 200000000), 0,"
           " fn(a, b) = a + b) }",
    %% every step waits for what the screen shows, so that a shell slower
    %% under load is waited for rather than raced
    Screen = pty(alone("../bin/ern --shell"),
                 [{expect, "> "},
                  {send, hex("1 + 5")},
                  {expect, "1 + 5"},
                  {send, hex([127]) ++ hex("2\r")},     % Backspace, then 2, Enter
                  {expect, "3 : Int"},
                  {send, hex(Long ++ "\r")},
                  {expect, "running"},
                  {send, "03"},                         % the interrupt
                  {expect, "Killed"},
                  {send, hex("1 + 1\r")},
                  {expect, "2 : Int"},
                  {send, "04"}],                        % C-d on an empty line
                 20),
    ?assertMatch({_, _}, binary:match(Screen, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Screen, <<"Killed">>)),
    ?assertMatch({_, _}, binary:match(Screen, <<"2 : Int">>)),
    %% the interrupt reached the shell as a key; the session was not ended
    ?assertMatch({_, _}, binary:match(Screen, <<"Killed">>)).

%% A terminal session with a home of its own, so that a test neither
%% reads nor writes the person's startup files or history (report §11.2).
alone(Command) ->
    "HOME=" ++ fresh_home() ++ " " ++ Command.

%% The operating system's pid as well as the counter: the counter starts
%% again in every run, so a home named by it alone would hold the history
%% an earlier run left, and a session would read it as its own.
fresh_home() ->
    Home = filename:join("/tmp", "ern_home_" ++ os:getpid() ++ "_"
                         ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Home),
    Home.

hex(Text) ->
    lists:flatten([io_lib:format("~2.16.0b", [C]) || C <- Text]).

pty(Command, Steps, Seconds) ->
    pty(Command, Steps, Seconds, "").

%% The screen as a reader sees it, rather than every write: a shell that
%% paints its panes writes a line many times over.
screen(Command, Steps, Seconds, Size) ->
    pty(Command, Steps, Seconds, " --screen --size " ++ Size).

pty(Command, Steps, Seconds, Extra) ->
    File = steps_file(Steps),
    {0, Out} = sh("./ern_pty.py --timeout " ++ integer_to_list(Seconds) ++ " --steps " ++ File
                  ++ Extra ++ " -- " ++ Command),
    Lines = [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    %% a step the harness could not meet is a failure of the test, not a
    %% screen to assert against
    ?assertEqual([], [L || <<"unmet ", _/binary>> = L <- Lines]),
    [<<"data ", Data/binary>>] = [L || <<"data ", _/binary>> = L <- Lines],
    base64:decode(Data).

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

sh(Cmd) ->
    Port = open_port({spawn, "sh -c '" ++ Cmd ++ "'"}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
