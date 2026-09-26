%% The shell (report §11.2): sessions in line mode, a file of inputs against
%% a file of expected output, which is what the design note calls a session
%% golden test, and the keys, the region, completion and documentation
%% driven through the pseudo-terminal harness, `test/ern_pty.py`.
-module(ern_shell_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.2, §11.5: an expression prints its value and its type, one of
%% type Unit prints nothing, an input that does not check shows the error
%% `ern build` shows, and a fault is reported without ending the session; a `let`
%% binds for the inputs after it and `it` is the last value; an input
%% declares what a module may, a later declaration of a name shadowing the
%% one before it, and what it declared is printed a line for each; and
%% report §4.4, an abstract type's constructor is the input's that declared
%% it. The commands are here too: `:type`, `:browse`, `:doc`, `:help`,
%% `:forget`, `:bindings`, `:set` with the depth and the length a value is
%% printed to, a prefix of any of them, a prefix that begins two names
%% refused with both, and `:help` in alphabetical order; `:load` refusing a
%% name that is not a module's and one it cannot find, each on a line of its
%% own, and answering a standard library module as in scope already
session_test_() ->
    {timeout, 60, fun session/0}.

session() ->
    {0, Out} = sh("../bin/ern shell < session/basic.in"),
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

%% The session waits on the events it asserts, not on the clock (plan, MVP
%% 2.6 checkpoint 4, step 5): the program's own fault is awaited on the
%% screen before the first input, since nothing at the prompt holds the
%% entry point's address to monitor it, and each input waits for its
%% answer. It ran on two waits of 400 ms before, and once failed under load.
program() ->
    {0, _} = sh("../bin/ern build --source-root session --build-root build/session"
                " session/counter.ern"),
    Screen = screen(alone("../bin/ern shell build/session/counter.erc"),
                    [{expect, "Counter.main faulted: division by zero"},
                     {send, hex("let c = Counter.start()\r")},
                     {expect, "c : Address(Counter.Msg)"},
                     %% the second is typed while the first may still run,
                     %% and waits for it (report §11.2)
                     {send, hex("send(c, Counter.Add(7))\r")},
                     {send, hex("Address.call(c, fn(r) = Counter.Get(reply = r), 1000)\r")},
                     {expect, "Some(7) : Optional(Int)"},
                     {send, hex(":browse Counter\r")},
                     {expect, "Counter.start : () -> Address(Msg) with m"},
                     {send, hex("spawn(Local, fn() = Counter.boom())\r")},
                     {expect, "input:1 faulted: division by zero"},
                     {send, hex(":processes\r")},
                     {expect, "Counter.start:10"},
                     {send, hex(":faults\r")},
                     {expect, "Counter.main faulted: division by zero"},
                     {expect, "input:1 faulted: division by zero"},
                     {send, "04"}],
                    30, "60x100"),
    %% what the program printed reached the screen
    ?assertMatch({_, _}, binary:match(Screen, <<"worker here">>)),
    %% the program's entry point and a process spawned at the prompt, each
    %% reported once as it faults and once by `:faults`
    ?assertEqual(2, count(Screen, <<"Counter.main faulted: division by zero">>)),
    %% (report §11.2: a site in an input's own expression is `input:1`)
    ?assertEqual(2, count(Screen, <<"input:1 faulted: division by zero">>)),
    %% `:processes` leaves the shell's own out
    ?assertEqual(nomatch, binary:match(Screen, <<"Shell.main">>)).

count(Haystack, Needle) ->
    length(binary:matches(Haystack, Needle)).

%% report §11.2: at start the shell runs the inputs of the person's
%% startup file and then the node's, a line an input, a command among them;
%% a value is not printed, a later file's binding shadows an earlier one's,
%% and an input that fails is reported with the file and the line it came
%% from, and the session goes on
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
    %% the node's file binds the same name, holds a line that does not
    %% parse, and a command, which runs as a typed one does
    ok = file:write_file(filename:join([Node, ".ernest", "startup"]),
                         "let shared = 2\n1 +\n:set depth 1\n"),
    In = filename:join(Node, "session.in"),
    ok = file:write_file(In, "greeting\nshared\n[[1]]\n"),
    {0, Out} = sh("HOME=" ++ Home ++ " ../bin/ern shell --config-dir "
                  ++ filename:join(Node, ".ernest") ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"\"from the user file\" : String">>)),
    %% the node's file ran after the person's, so its binding is the one
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    %% a failing input names its own line of the file, quoted from the file
    %% with the line before it; a regression test for a finding of the
    %% shell's review, where every one said line 1 and `:set` was refused
    ?assertMatch({_, _}, binary:match(Out, <<"startup:2:4: expected an expression">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"1 | let shared = 2\n2 | 1 +">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"[...] : List(List(Int))">>)),
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
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("1 + 1\r")},
                     {expect, "2 : Int"},
                     {send, hex(Print)},
                     {sleep, 800},
                     {send, hex("2 + 2\r")},
                     {expect, "4 : Int"},
                     {send, "04"}],
                    20, "30x60"),
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
%% the history file's escaping, the region's geometry, completion's
%% matching, and the colours, run by `ern test` as the shell is built
editor_test_() ->
    {timeout, 60, fun editor/0}.

editor() ->
    %% every compiled module of the shell, so that a module's tests run
    %% from the day it is written; region's and complete's had not
    Modules = filelib:wildcard("../build/shell/**/*.erc"),
    ?assert(length(Modules) >= 7),
    %% the shell renders documentation with libs/markdown, which a run of
    %% its modules puts on the load path as any program using a library does
    Runs = ["../bin/ern test --load-path ../build/libs/markdown " ++ M || M <- Modules],
    {Status, Out} = sh(lists:flatten(lists:join(" && ", Runs))),
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
    Screen = pty(alone("../bin/ern shell"),
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
    Screen = screen(alone("../bin/ern shell"),
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
    _ = pty("HOME=" ++ Home ++ " ../bin/ern shell",
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
    Screen = pty("HOME=" ++ Home ++ " ../bin/ern shell",
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
    {0, _} = sh("HOME=" ++ Home ++ " ../bin/ern shell < session/basic.in"),
    ?assertEqual([<<"11 + 11">>, <<"33 + 33">>, <<"11 + 11">>], history_lines(File)).

history_lines(File) ->
    {ok, Text} = file:read_file(File),
    [L || L <- binary:split(Text, <<"\n">>, [global]), L =/= <<>>].

%% report §11.2: at a terminal an input may span lines. `Enter` takes
%% another line where the parser cannot finish the input and runs it
%% where it can, `M-Enter` takes one whatever the parser says, and
%% `Enter` on an empty line runs what there is, error and all. The first
%% such input of a session says how it is run, once, above the region.
%% The rows after the first are prompted `... `, `Tab` indents where
%% there is nothing to complete, and a multi-line input comes back from
%% the history whole
multiline_test_() ->
    {timeout, 90, fun multiline/0}.

multiline() ->
    Home = fresh_home(),
    Screen = screen("HOME=" ++ Home ++ " ../bin/ern shell",
                    [{expect, "> "},
                     {send, hex("1 +\r")},                % the parser wants more
                     {expect, "... "},
                     %% nothing before the cursor to complete, so Tab indents
                     {send, "09" ++ hex("2\r")},
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
                     %% C-d leaves only on an empty line: C-c cancels the
                     %% input brought back, so the session ends rather than
                     %% waiting out the harness's timeout
                     {send, "03"},
                     {send, "04"}],
                    30, "30x46"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the hint is above the region and the prompt it was typed under stays
    ?assertEqual(1, count(Text, <<"M-Enter adds a line, Enter runs.">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"> 1 +">>)),
    ?assertMatch({_, _}, binary:match(Text, <<"...     2">>)),
    %% `M-Enter` took a line the parser would have run
    ?assertMatch({_, _}, binary:match(Text, <<"42 : Int">>)),
    %% the blank line ran an input that cannot parse, and its error names
    %% the line the input was typed on
    ?assertMatch({_, _}, binary:match(Text, <<"expected a pattern">>)),
    %% the history brought the multi-line input back whole
    ?assertEqual([<<"1 +\\n    2">>, <<"40 + 2\\n    + 0">>, <<"fn f(\\n">>],
                 history_lines(filename:join([Home, ".ernest", "history"]))),
    %% the screen is rendered without the spaces at a row's end: the input
    %% brought back shows its empty second row as `...` alone
    ?assert(lists:member(<<"...">>, Lines)).

%% report §11.2, §8.2: a paste goes into the line at the cursor and its
%% line feeds add lines, so a pasted two-line input is one input and runs
%% when `Enter` is pressed after it
paste_test_() ->
    {timeout, 90, fun paste/0}.

paste() ->
    Screen = screen(alone("../bin/ern shell"),
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
    Screen = pty(alone("../bin/ern shell"),
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

%% report §11.2: `Tab` completes the word before the cursor to what the
%% names in scope share, matching by prefix and by abbreviation, and a
%% second `Tab` lists the candidates with their types under the line
%% being typed, until the next key; a completed name runs like any other
completion_test_() ->
    {timeout, 90, fun completion/0}.

completion() ->
    Steps = [{expect, "> "},
             {send, hex("List.ma") ++ "09"},          % Tab: one candidate
             {expect, "List.map"},
             {send, hex("([1], fn(n) = n * 2)\r")},
             {expect, "[2] : List(Int)"},
             {send, hex("List.fil") ++ "09"},         % Tab: what they share
             {expect, "> List.filter"},
             {send, "09"},                            % Tab again: the listing
             {expect, "List.filterMap :"},
             {sleep, 300},
             {send, "03"},                            % the next key
             {sleep, 200},
             {send, "04"}],
    Screen = screen(alone("../bin/ern shell"), Steps, 30, "16x74"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the completed name ran
    ?assertMatch({_, _}, binary:match(Text, <<"[2] : List(Int)">>)),
    %% the line being typed is still there, completed to what they share
    ?assert(lists:any(fun(L) -> binary:match(L, <<"> List.filter">>) =/= nomatch end, Lines)),
    %% and the listing went with the next key, leaving the transcript
    %% without it
    ?assertEqual(nomatch, binary:match(Text, <<"List.filterMap :">>)),
    %% it was painted under the line, the candidates with their types
    Bytes = pty(alone("../bin/ern shell"), Steps, 30, " --size 16x74"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.filter\r\nList.filter : (List(a)">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nList.filterMap : (List(a)">>)).

%% report §11.2: a `Tab` that adds nothing to the line lists the
%% candidates at once, as a second `Tab` does. A regression test for a
%% finding of the session of real use: every command begins with `:`, so
%% the first `Tab` after one did nothing that could be seen. What does
%% not fit the screen is counted on the last row
listing_at_once_test_() ->
    {timeout, 60, fun listing_at_once/0}.

listing_at_once() ->
    Bytes = pty(alone("../bin/ern shell"),
                [{expect, "> "},
                 {send, hex(":") ++ "09"},                % one Tab
                 {expect, " more"},
                 {send, "03"},
                 {send, "04"}],
                30, " --size 8x80"),
    %% under the line, cut to the eight rows with the count last
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :\r\n:bindings ">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nand 7 more">>)).

%% report §11.2, Appendix E.0 rule 6: `Shift-Tab` on a name shows its type,
%% its first sentence, and the version it appeared in, and its page when
%% pressed again; inside a call, the callee's signature with the
%% parameters as declared; and a command completes as a word of the
%% shell's own, a `Tab` that adds nothing listing every command. Each is
%% shown under the line and goes at the next key. Each step waits for
%% text only the answer holds, never for what the input echoes, which is
%% how the first test of these keys raced its own output
shift_tab_test_() ->
    {timeout, 90, fun shift_tab/0}.

shift_tab() ->
    ShiftTab = "1b5b5a",
    Bytes = pty(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("List.map") ++ ShiftTab},
                     {expect, "The function applied to each element, in order."},
                     {send, ShiftTab},                        % again: the page
                     {expect, "    List.map : (List(a)"},
                     {send, "03"},
                     {send, hex("List.map([1], ") ++ ShiftTab},
                     {expect, "xs : List(a)"},
                     {send, "03"},
                     %% the whole name the cursor stands in, two to its left
                     {send, hex("List.map") ++ "1b5b441b5b44" ++ ShiftTab},
                     {expect, "The function applied"},
                     {send, "03"},
                     {send, hex(":br") ++ "09"},              % a command completes
                     {expect, ":browse"},
                     {send, "03"},
                     {send, hex(":") ++ "09"},                % every command
                     {expect, ":processes      the live processes"},
                     {send, "03"},
                     {send, "04"}],
                    30, " --size 60x90"),
    %% the brief under the line: the type, the sentence, the version
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.map\r\nList.map : (List(a), (a) -> b with e)"
                                               " -> List(b) with e\r\n"
                                               "The function applied to each element, in order.\r\n"
                                               "Since 0.1.0.">>)),
    %% then the page, under the line in its place, rendered: the heading as
    %% its text and the type's code block without its fences
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.map\r\nList.map\r\n\r\n"
                                               "    List.map : (List(a)">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"```">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.map([1], \r\n"
                                               "List.map(xs : List(a), f : (a) -> b with e)"
                                               " -> List(b) with e">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :browse">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\n:faults         the faults reported since"
                                               " the session began\r\n">>)).

%% report §11.2: a command that takes an argument, completed whole, is
%% followed by a space, and what completes after it is what it takes: a
%% module for `:browse`, listed by its name alone; a setting for `:set`; a
%% module under the source root for `:load`, a directory at a time; and
%% nothing after `:output`, where `Tab` neither lists nor indents. A
%% lone candidate is completed as far as it goes, a setting with the space
%% before its value as a command with its argument, and is listed with its
%% line whenever `Tab` reaches it. A regression test for findings of the session of
%% real use: `:browse` and `Tab` did nothing, `:browse ` and `Tab`
%% indented, `:browse B` listed `module Bool`, and `:bindings` and `Tab`
%% showed nothing
command_argument_test_() ->
    {timeout, 60, fun command_argument/0}.

command_argument() ->
    Root = filename:join("/tmp", "ern_root_" ++ os:getpid() ++ "_"
                         ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(filename:join(Root, "http")),
    ok = file:write_file(filename:join([Root, "http", "parser.ern"]), "export let one = 1\n"),
    ok = file:write_file(filename:join(Root, "demo.ern"), "export let two = 2\n"),
    ok = filelib:ensure_path(filename:join(Root, "Bad")),
    Bytes = pty(alone("../bin/ern shell --source-root " ++ Root),
                [{expect, "> "},
                 {send, hex(":bindings") ++ "09"},        % whole, and takes nothing
                 {expect, "what the session declares"},
                 {send, "03"},
                 {send, hex(":bro") ++ "09"},
                 {expect, ":browse "},
                 {send, hex("B") ++ "09"},
                 {expect, "Bytes"},
                 {send, "03"},
                 {send, hex(":set ") ++ "09"},
                 {expect, "timing on or off"},
                 {send, "03"},
                 {send, hex(":set dep") ++ "09"},          % a lone setting, and its value
                 %% the listing before holds `depth n` too, and a repaint of it
                 %% could meet a wait for that alone: the completed line comes first
                 {expect, ":set depth "},
                 {expect, "depth n"},
                 {send, "03"},
                 {send, hex(":set timing of") ++ "09"},    % timing's value is a word
                 {expect, "timing off"},
                 {send, "03"},
                 {send, hex(":load Http.Parser\r")},
                 {expect, "compiled from"},
                 {send, hex(":browse Ht") ++ "09"},          % a nested module's namespace
                 {expect, "namespace Http"},
                 {send, "03"},
                 {send, hex(":load ") ++ "09"},
                 {expect, "Http."},
                 {send, hex("Http.") ++ "09"},
                 {expect, "Http.Parser"},
                 {send, "03"},
                 {send, hex(":output ") ++ "09"},
                 {sleep, 300},
                 {send, "03"},
                 {send, "04"}],
                30, " --size 30x80"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :bindings\r\n:bindings       what the session"
                                               " declares, with their types">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :browse \r\n:browse Module  the exports">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :set depth \r\ndepth n">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :set timing off\r\noff">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :browse B\r\nBool\r\nBytes">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"module Bool">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\ndepth n\r\nlength n\r\n">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nDemo">>)),
    %% a directory that breaks the path shape is no namespace
    ?assertEqual(nomatch, binary:match(Bytes, <<"Bad">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :load Http.Parser">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> :output ">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"> :output     ">>)).

%% report §11.2: the parameter at the cursor is written in the terminal's
%% cyan, and the colour ends where the parameter does
shift_tab_colour_test_() ->
    {timeout, 60, fun shift_tab_colour/0}.

shift_tab_colour() ->
    Raw = raw(alone("../bin/ern shell"),
              [{expect, "> "},
               {send, hex("List.map([1], ") ++ "1b5b5a"},
               {expect, "xs : List(a)"},
               {send, "03"},
               %% report §11.2: the call is found in a `let`, a declaration's
               %% body, and a command's argument, and a constructor shows its
               %% fields, the one whose value is at the cursor marked. A
               %% regression test for findings of the shell's review
               {send, hex("type Point = Point(x : Int, yval : Int)\r")},
               %% inputs run in order, so `:bindings`' answer comes after the
               %% declaration's; the echo alone may be repainted before it
               {send, hex(":bindings\r")},
               {expect, ":bindings"},
               {expect, "type Point"},
               {send, hex("let s = List.foldLeft(") ++ "1b5b5a"},
               {expect, "acc : b"},
               {send, "03"},
               {send, hex("fn g(n : Int) -> Int = List.foldLeft([n], ") ++ "1b5b5a"},
               {expect, "acc : b"},
               {send, "03"},
               {send, hex(":type List.foldLeft(") ++ "1b5b5a"},
               {expect, "acc : b"},
               {send, "03"},
               {send, hex("Point(x = 1, yval = ") ++ "1b5b5a"},
               {expect, "-> Point"},
               {send, "03"},
               {send, "04"}],
              30),
    ?assertMatch({_, _}, binary:match(Raw, <<"xs : List(a), \e[36mf : (a) -> b with e\e[0m)">>)),
    %% the first argument marked after `let` and `:type`, the second in the
    %% declaration's body; a repaint may write a row twice, so each is looked
    %% for, not counted
    ?assertMatch({_, _}, binary:match(Raw, <<"List.foldLeft(\e[36mxs : List(a)\e[0m, acc : b">>)),
    ?assertMatch({_, _}, binary:match(Raw, <<"List.foldLeft(xs : List(a), \e[36macc : b\e[0m">>)),
    ?assertMatch({_, _}, binary:match(Raw, <<"Point(x : Int, \e[36myval : Int\e[0m) -> Point">>)).

%% report §11.2: `Tab` indents only where spaces alone stand before the
%% cursor on its row; after `(`, with nothing to complete, it lists what may
%% stand there, and with nothing typed that is the session's names, the
%% modules, and the prelude's names but its constructors, alphabetically.
%% A regression test for findings of the session of real use: `List.map(`
%% and `Tab` put four spaces inside the call, and then listed every prelude
%% constructor first
tab_mid_row_test_() ->
    {timeout, 60, fun tab_mid_row/0}.

tab_mid_row() ->
    Bytes = pty(alone("../bin/ern shell"),
                [{expect, "> "},
                 {send, hex("let zeta = 1\r")},
                 {expect, "zeta : Int"},
                 {send, hex("List.map(") ++ "09"},
                 {expect, "module Bool"},
                 {send, hex("[1], fn(n) = n)\r")},
                 {expect, "[1] : List(Int)"},
                 {send, "04"}],
                30, " --size 40x80"),
    ?assertEqual(nomatch, binary:match(Bytes, <<"List.map(    ">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"ArrowDown">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"module Bool\r\nmodule Bytes\r\n">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nzeta : Int">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nspawn : (Where">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.map(\r\n">>)).

%% report §11.2: fields complete in a pattern as in an expression, each
%% with its type, and a lone constructor is listed with its type; a name
%% `:forget` removed no longer completes; an input's module and an operator
%% are not offered. Regression tests for findings of the shell's review
review_completion_test_() ->
    {timeout, 90, fun review_completion/0}.

review_completion() ->
    Bytes = pty(alone("../bin/ern shell"),
                [{expect, "> "},
                 {send, hex("type Point = Point(x : Int, yval : Int)\r")},
                 %% inputs run in order, so `:bindings`' answer comes after the
                 %% declaration's; the echo alone may be repainted before it
                 {send, hex(":bindings\r")},
                 {expect, ":bindings"},
                 {expect, "type Point"},
                 {send, hex("Point(x = 1, y") ++ "09"},
                 {expect, "yval : Int"},
                 {send, "03"},
                 {send, hex("match 1 { Point(x = a, y") ++ "09"},
                 {expect, "Point(x = a, yval"},
                 {send, "03"},
                 {send, hex("match 1 { So") ++ "09"},
                 {expect, "Some : (a) -> Optional(a)"},
                 {send, "03"},
                 {send, hex("let zz = 1\r")},
                 {expect, "zz : Int"},
                 {send, hex(":forget zz\r")},
                 {send, hex(":bindings\r")},
                 {expect, "type Point"},                   % `:forget` has been taken
                 {send, hex("zz") ++ "09"},
                 {sleep, 400},
                 {send, "03"},
                 {send, hex("1 + In") ++ "09"},
                 {expect, "1 + Int"},
                 {send, "03"},
                 {send, hex("String.") ++ "09"},
                 {expect, "String.toUpper"},
                 {send, "03"},
                 {send, "04"}],
                30, " --size 60x100"),
    ?assertEqual(1, count(Bytes, <<"zz : Int">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"Input">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"String.<>">>)).

%% report §11.2: a line wider than the screen wraps onto the rows below it
%% as it is typed, and the cursor follows it there. A regression test for a
%% finding of the shell's review, where the line was cut at the edge and the
%% cursor stood still
wide_input_test_() ->
    {timeout, 60, fun wide_input/0}.

wide_input() ->
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("let longname = \"abcdefghijklmnopqrstuvwxyz0123456789\"")},
                     {expect, "0123456789"},
                     {send, hex("X")},
                     {expect, "789\"X"},
                     {send, "03"},
                     {send, "04"}],
                    30, "12x40"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    ?assert(lists:member(<<"> let longname = \"abcdefghijklmnopqrstuv">>, Lines)).

%% report §11.2: `:load` of a source that does not lex or parse reports its
%% diagnostic and the session goes on. A regression test: the error was
%% raised out of the front end, and the shell ended with it
load_unreadable_test_() ->
    {timeout, 60, fun load_unreadable/0}.

load_unreadable() ->
    Dir = filename:join("/tmp", "ern_bad_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "bad.ern"), "export fn f() -> Int = 1 \\ 2\n"),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, ":load Bad\n1\n"),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"bad.ern:1:26: illegal character">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"1 : Int">>)).

%% report §11.2: `:load` loads the modules a module uses in their compiled
%% form, and refuses one whose dependency is not compiled with a sentence
%% naming it. A regression test of compile_source's refusal, which the
%% shell had told apart from diagnostics by the shape of a list.
load_uncompiled_dependency_test_() ->
    {timeout, 60, fun load_uncompiled_dependency/0}.

load_uncompiled_dependency() ->
    Dir = filename:join("/tmp", "ern_dep_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "top.ern"), "export fn g() -> Int = Dep.f()\n"),
    ok = file:write_file(filename:join(Dir, "dep.ern"), "export fn f() -> Int = 1\n"),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, ":load Top\n1\n"),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"compile Dep first">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"1 : Int">>)).

%% report §11.2: a binding and a function may take the names the host gives
%% every module, and a later input reaches them. A regression test: a
%% `let module_info` faulted inside the shell, and a later input calling
%% `record_info` reached the host's function.
host_reserved_names_test_() ->
    {timeout, 60, fun host_reserved_names/0}.

host_reserved_names() ->
    In = filename:join("/tmp", "ern_reserved_" ++ os:getpid() ++ ".in"),
    ok = file:write_file(In, ["let module_info = 1\n", "fn record_info(x : Int) -> Int = x\n",
                              "module_info + record_info(2)\n", "let f = record_info\n",
                              "f(5)\n"]),
    {0, Out} = sh(alone("../bin/ern shell") ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"5 : Int">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"fault">>)).

%% report §11.2: an input that declares nothing is done with its module once
%% it has its answer: the module is unloaded, unless what the input bound
%% holds one of its functions, and a process the input spawned keeps it
%% until that process ends, and a value holding one of its functions still
%% calls it. A regression test: every input's module stayed loaded for the
%% rest of the session. Not covered: the holder of `it`, which step 10 of
%% MVP 2.65 frees.
input_module_unloaded_test_() ->
    {timeout, 60, fun input_module_unloaded/0}.

input_module_unloaded() ->
    In = filename:join("/tmp", "ern_unload_" ++ os:getpid() ++ ".in"),
    Count = "List.size(loadedModules())\n",
    ok = file:write_file(In, [
        "foreign fn loadedModules() -> List(Foreign) with m = \"code:all_loaded/0\"\n",
        Count, [["1 + ", integer_to_list(I), "\n"] || I <- lists:seq(1, 50)], Count,
        "fn(x : Int) -> Int = x + 1\n",
        "it(41)\n",
        "let _ = spawn(Local, fn() -> Unit with Never = {"
        " let _ = receive { after 300 -> Unit }; Io.println(\"late\") })\n",
        "receive { after 600 -> Unit }\n"]),
    {0, Out} = sh(alone("../bin/ern shell") ++ " < " ++ In),
    [Before, After] = [binary_to_integer(N) || {match, [N]} <-
                           [re:run(L, "^> ([0-9]+) : Int$", [{capture, all_but_first, binary}])
                            || L <- binary:split(Out, <<"\n">>, [global])],
                       binary_to_integer(N) > 100],
    %% each expression leaves its holder of `it` loaded, and its own module
    %% not
    ?assert(After - Before =< 50 + 5),
    ?assertMatch({_, _}, binary:match(Out, <<"> 42 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"late">>)).

%% report §2.3, §11.2: an input whose module was unloaded gives its number,
%% and so its name's atoms, to the next input, so expressions cost no atoms
%% of their own. A regression test: each input took a new number, and the
%% host never collects an atom. Not covered: the two atoms of the holder
%% each expression makes for `it`, which step 10 of MVP 2.65 frees; the
%% bound below allows them and a few the session makes on its own, and an
%% input that took a new number, four atoms, breaks it.
input_numbers_reused_test_() ->
    {timeout, 120, fun input_numbers_reused/0}.

input_numbers_reused() ->
    In = filename:join("/tmp", "ern_atoms_" ++ os:getpid() ++ ".in"),
    Info = "info(Erl.atom(\"atom_count\"))\n",
    ok = file:write_file(In, ["foreign fn info(k : Foreign) -> Int with m ="
                              " \"erlang:system_info/1\"\n", Info,
                              [["1 + ", integer_to_list(I), "\n"] || I <- lists:seq(1, 200)],
                              Info]),
    {0, Out} = sh(alone("../bin/ern shell") ++ " < " ++ In),
    [Before, After] = [binary_to_integer(N) || {match, [N]} <-
                           [re:run(L, "^> ([0-9]{5,}) : Int$", [{capture, all_but_first, binary}])
                            || L <- binary:split(Out, <<"\n">>, [global])]],
    ?assert(After - Before =< 3 * 200).

%% report §11.2: every refusal of a command is red, as a diagnostic's first
%% line is, and an answer is plain. A regression test for a finding of the
%% session of real use: `:load`'s refusal was red and `:set`'s was not, the
%% colour following the code path and not the meaning
refusal_colour_test_() ->
    {timeout, 60, fun refusal_colour/0}.

refusal_colour() ->
    Raw = raw(alone("../bin/ern shell"),
              [{expect, "> "},
               {send, hex(":sreload\r")},
               {expect, "no command"},
               {send, hex(":set depth a\r")},
               {expect, "takes a number"},
               {send, hex(":reload hhhh\r")},
               {expect, "takes no argument"},
               {send, hex(":load hhhh\r")},
               {expect, "not a module name"},
               {send, hex(":bindings\r")},
               {expect, "declares nothing yet"},
               {send, "04"}],
              30),
    Red = fun(Text) -> binary:match(Raw, <<"\e[31m", Text/binary>>) =/= nomatch end,
    ?assert(Red(<<"no command :sreload">>)),
    ?assert(Red(<<":set depth takes a number">>)),
    ?assert(Red(<<":reload takes no argument">>)),
    ?assert(Red(<<"hhhh is not a module name">>)),
    ?assertNot(Red(<<"the session declares nothing yet">>)).

%% report §11.2: what may stand at the cursor decides what completes,
%% and the parser is what knows: after `:` a type, inside a named
%% constructor its fields, and everywhere else the values,
%% constructors and modules in scope
context_test_() ->
    {timeout, 90, fun context/0}.

context() ->
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("type Zebra = Zebra(width : Int, height : Int)\r")},
                     %% the echo of a declaration holds its own name, so
                     %% no text marks that it has run; this is one of the
                     %% moments the harness has to wait out
                     {sleep, 1500},
                     {send, hex("let z : Ze") ++ "09"},          % a type position
                     {expect, "let z : Zebra"},
                     {send, hex(" = Zebra(w") ++ "09"},          % a field position
                     {expect, "Zebra(width"},
                     {send, hex(" = 1, hei") ++ "09"},           % the other field
                     {expect, "height"},
                     {send, hex(" = 2)\r")},
                     {expect, "z : Zebra"},
                     {sleep, 300},
                     {send, "04"}],
                    30, "16x70"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the input the completions built ran and bound
    ?assertMatch({_, _}, binary:match(Text, <<"z : Zebra">>)),
    %% a type position offered the type, not the constructor's value
    ?assertMatch({_, _}, binary:match(Text, <<"let z : Zebra = Zebra(width = 1, height = 2)">>)).

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

%% report §11.2, §6.9: a `let` at the prompt carries its annotation, so
%% a binding whose type its input cannot settle is settled by one; and
%% an input that binds a name whose type is still open is refused with
%% the annotation that would settle it, rather than entering the session
%% and breaking every input after it
open_binding_test_() ->
    {timeout, 60, fun open_binding/0}.

open_binding() ->
    In = filename:join("/tmp", "ern_open_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In,
                         "let p = spawn(Local, fn() = receive { _ -> Unit })\n"
                         "let q : Address(Int) = spawn(Local, fn() = receive { _ -> Unit })\n"
                         "send(q, 1)\n"
                         "kill(q)\n"
                         "1 + 1\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    %% the open binding is refused, and says what would settle it
    ?assertMatch({_, _}, binary:match(Out, <<"the type of p is not determined">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"bind it with an annotation">>)),
    %% the annotated one is taken, and `kill` reaches it
    ?assertMatch({_, _}, binary:match(Out, <<"q : Address(Int)">>)),
    %% and the session goes on, which it did not before: a scheme with a
    %% free variable used to break every input after it
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"badkey">>)).

%% report §11.2, §7.4: the terminal is the shell's, so an input that reads a
%% line faults with the cause §7.4 gives and the shell goes on. A
%% regression test: in line mode the input took the shell's next line, and
%% at a terminal it ended the program, shell and all
%% report §11.2: a later input may declare a member of a type the session
%% declares, and an operator finds it; a type declared again starts with no
%% members. Written with the change, and it does not cover an abstract type,
%% whose constructor stays its own input's (§4.4)
later_member_test_() ->
    {timeout, 60, fun later_member/0}.

later_member() ->
    In = filename:join("/tmp", "ern_member_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, "type Coin = Coin(Int)\n"
                             "fn Coin.+(Coin(a), Coin(b)) = Coin(a + b)\n"
                             "Coin(1) + Coin(2)\n"
                             "fn Coin.compare(Coin(a), Coin(b)) = Int.compare(a, b)\n"
                             "Coin(1) < Coin(2)\n"
                             "Coin.compare(Coin(3), Coin(2))\n"
                             "type Coin = Coin(Float)\n"
                             "Coin(1.0) + Coin(2.0)\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"Coin(3) : Coin">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"true : Bool">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Greater : Ordering">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"`+` is not defined on Coin">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"not a type declared">>)).

input_reads_line_test_() ->
    {timeout, 60, fun input_reads_line/0}.

input_reads_line() ->
    In = filename:join("/tmp", "ern_read_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, "Io.readLine()\n1 + 1\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"the shell holds the terminal">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"Some(\"1 + 1\")">>)),
    Screen = pty(alone("../bin/ern shell"),
                 [{expect, "> "},
                  {send, hex("Io.readLine()\r")},
                  {expect, "shell holds the terminal"},
                  {send, hex("1 + 1\r")},
                  {expect, "2 : Int"},
                  {send, "04"}],
                 20),
    ?assertMatch({_, _}, binary:match(Screen, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Screen, <<"already read as">>)).

%% report §6.6, §11.2: an input's value is printed and dropped, and a `let`
%% at the prompt binds for every later input, so neither may carry a reply.
%% A regression test: the shell printed such a value and dropped the reply.
reply_input_test_() ->
    {timeout, 60, fun reply_input/0}.

reply_input() ->
    In = filename:join("/tmp", "ern_reply_" ++ integer_to_list(erlang:unique_integer([positive]))),
    Take = "receive { Get(reply = r) -> Get(reply = r) | Stop -> Stop | after 0 -> Stop }",
    ok = file:write_file(In, ["type Req = Get(reply : Reply(Int)) | Stop\n",
                              Take, "\n",
                              "let x = ", Take, "\n",
                              "1 + 1\n"]),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    Refused = binary:matches(Out, <<"an input's value cannot carry a reply">>),
    ?assertEqual(2, length(Refused)),
    ?assertEqual(nomatch, binary:match(Out, <<"Stop : Req">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)).

%% report §11.2, §5.4: a `let` at the prompt is a block `let`, so its
%% pattern binds each name it holds, in the order written, `let _ = e`
%% binds none, a refutable pattern is refused as in a block, and `<-` is
%% refused, having no block to end. A regression test: the prompt took a
%% name alone, as a top-level `let` does
pattern_let_test_() ->
    {timeout, 60, fun pattern_let/0}.

pattern_let() ->
    In = filename:join("/tmp", "ern_plet_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, "let #(a, b) = #(1, \"two\")\n"
                             "a + 1\n"
                             "type P = P(name : String, age : Int)\n"
                             "let P(name = n, age = g) as p = P(name = \"Ada\", age = 36)\n"
                             "g\n"
                             "let _ = 5\n"
                             "let Some(y) = Some(1)\n"
                             "let x <- Some(1)\n"
                             "let #(e, f) = #([], [])\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> a : Int\nb : String\n> 2 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"n : String\ng : Int\np : P\n> 36 : Int\n">>)),
    %% `let _ = 5` prints nothing and binds nothing
    ?assertMatch({_, _}, binary:match(Out, <<"36 : Int\n> > ">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"a `let` pattern must be irrefutable">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"a `let` with `<-` at the prompt has no block">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"the types of e, f are not determined">>)).

%% report §11.2, §3.9, §8.6: a `let` at the prompt is a block `let`, so a
%% binding whose effect variable nothing settles is refused, as a block
%% refuses it, and a timed receive is no deadlock in line mode, first
%% input or not. A declared name prints its own scheme after inputs whose
%% type state numbers other variables alike. A regression test for three
%% defects: the effect variable entered the session unbound and crashed
%% the next input's check, the first input's timed wait was a deadlock,
%% and the scheme printed through the later input's substitution
effect_variable_test_() ->
    {timeout, 60, fun effect_variable/0}.

effect_variable() ->
    In = filename:join("/tmp", "ern_eff_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, "receive { after 300 -> 5 }\n"
                             "let h = fn() = Io.println(\"x\")\n"
                             "let f = fn(x : Int) = x + 1\n"
                             "f(2)\n"
                             "fn g() -> Int with e = receive { after 5 -> 5 }\n"
                             ":type g\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> 5 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"the type of h is not determined by this input;"
                                             " it is () -> Unit with e">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> f : (Int) -> Int\n> 3 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> g : () -> Int with e\n"
                                             "> g : () -> Int with e\n">>)).

%% report §11.2: a file without an entry point is loaded by the shell and
%% nothing is spawned, so a library module is put in scope to be tried. A
%% regression test: the shell refused a module without `main`
library_file_test_() ->
    {timeout, 60, fun library_file/0}.

library_file() ->
    Dir = filename:join("/tmp", "ern_lib_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "twice.ern"), "export fn of(n : Int) -> Int = 2 * n\n"),
    ok = file:write_file(filename:join(Dir, "in"), "Twice.of(21)\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " --build-root " ++ Dir ++ " "
                ++ filename:join(Dir, "twice.ern")),
    {0, Out} = sh("HOME=" ++ Dir ++ " ../bin/ern shell " ++ filename:join(Dir, "twice.erc")
                  ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Out, <<"42 : Int">>)).

%% report §11.2, §8.1: a `main` that is not an entry point leaves the file
%% without one, so it is loaded and nothing is spawned; `--main` naming it
%% is refused. Written with the change: the shell spawned any exported
%% `main` that takes no arguments. A `let main` is not covered here, as
%% ern_cli_tests covers its refusal.
non_entry_main_test_() ->
    {timeout, 60, fun non_entry_main/0}.

non_entry_main() ->
    Dir = filename:join("/tmp", "ern_main_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "main.ern"),
                         "export fn main() -> Int with m = { Io.println(\"spawned\"); 3 }\n"),
    ok = file:write_file(filename:join(Dir, "in"), "1 + 1\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " --build-root " ++ Dir ++ " "
                ++ filename:join(Dir, "main.ern")),
    Erc = filename:join(Dir, "main.erc"),
    {0, Out} = sh("HOME=" ++ Dir ++ " ../bin/ern shell " ++ Erc
                  ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"spawned">>)),
    {1, Refused} = sh("HOME=" ++ Dir ++ " ../bin/ern shell --main Main.main " ++ Erc
                      ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Refused, <<"Main.main is not an entry point: its type is"
                                                 " () -> Int with m">>)).

%% report §9, §11.2: `:doc` finds a prelude name's documentation, a
%% function, a type, and a `Sys.*` reference, and still finds an operation
%% in its type's module. A regression test: the prelude had none, and `:doc
%% monitor` said "no documentation"
prelude_doc_test_() ->
    {timeout, 60, fun prelude_doc/0}.

prelude_doc() ->
    In = filename:join("/tmp", "ern_pdoc_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, ":doc monitor\n:doc Down\n:doc Sys.stdout\n:doc Int.compare\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> monitor\n\n    monitor : ">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"type Down = Down(reason : Reason">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Sys.stdout\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Int.compare\n">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"no documentation">>)).

%% report §11.2, §11.5: an input that is one name has its type printed as
%% the declaration writes it, under the declaration's variable names, asked
%% for with `:type` or evaluated; any other expression prints its own type.
%% A regression test: `:type Io.readLine` printed `with e` where `:browse Io`
%% printed `with m`
one_name_type_test_() ->
    {timeout, 60, fun one_name_type/0}.

one_name_type() ->
    In = filename:join("/tmp", "ern_name_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(In, ":type Io.readLine\n:type spawn\nIo.readLine\n"
                             ":type List.map([1], fn(x) = x)\n"),
    {0, Out} = sh("../bin/ern shell < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"Io.readLine : () -> Optional(String) with m\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"spawn : (Where, () -> Unit with n) -> Address(n)"
                                             " with m\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"<function> : () -> Optional(String) with m\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"List.map([1], fn(x) = x) : List(Int)\n">>)).

%% report §11.2, §11.4: every name that completes after `:doc` has
%% documentation. A constructor's is its type's, the prelude's, the
%% session's, and a loaded module's alike; a module's is the head of its
%% page; a name the session declares is shown as the session writes it,
%% never under the input's namespace; and a `let` at the prompt has its
%% name and type. A regression test for findings of the session of real
%% use: `:doc Accept` and `:doc Some` answered no documentation, a session
%% declaration was headed `Input1.sz`, and `:doc` found nothing in a
%% module `:load` had compiled, which is loaded from memory
doc_every_name_test_() ->
    {timeout, 60, fun doc_every_name/0}.

doc_every_name() ->
    Root = filename:join("/tmp", "ern_docroot_" ++ os:getpid() ++ "_"
                         ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Root),
    ok = file:write_file(filename:join(Root, "m.ern"),
                         "/// A little module.\n///\n/// since 0.1.0\n\n"
                         "/// A colour.\nexport type Colour = Red | Green\n"),
    In = filename:join(Root, "session.in"),
    ok = file:write_file(In, ["let zeta = 1\n", "fn sz() -> Int = 1\n",
                              "type Tree = Leaf | Node(left : Tree, right : Tree)\n",
                              ":doc zeta\n", ":doc sz\n", ":doc Leaf\n", ":doc Accept\n",
                              ":doc Some\n", ":doc Fs\n", ":load M\n", ":doc M.Red\n",
                              ":doc M\n", ":doc Sys\n", ":doc List\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Root) ++ " < " ++ In),
    ?assertEqual(nomatch, binary:match(Out, <<"no documentation">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"Input">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> zeta\n\n    zeta : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> sz\n\n    sz : () -> Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Tree\n\n    type Tree = Leaf">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> ListenerMsg\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Optional\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Ernest module Fs\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> M.Colour\n\n    type Colour = Red | Green"
                                             "\n\nA colour.">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> Ernest module M\n\n*Since 0.1.0.*\n\n"
                                             "A little module.">>)),
    %% a namespace lists what it holds, and a type that is a module too
    %% shows both
    ?assertMatch({_, _}, binary:match(Out, <<"> namespace Sys\n\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"`Sys.stdout : Address(String)`">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"    type List(a)">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"\nErnest module List\n">>)).

%% report §11.2, §6.9: a spawn site in the session is written as the
%% session writes names, `input:1` in an input's own expression and
%% `start:1` in a function an input declares, and the input's own wrapper
%% shadows no name the session declares. A regression test for findings
%% of the session of real use: `:processes` showed `Input2.main:1`, a name
%% the session shows only for a shadowed type, and `main()` after `fn main` called the
%% wrapper, which was named `main`, forever
session_names_test_() ->
    {timeout, 60, fun session_names/0}.

session_names() ->
    In = filename:join("/tmp", "ern_names_" ++ integer_to_list(erlang:unique_integer([positive]))),
    Wait = "receive { n -> Io.println(Int.toString(n)) }",
    ok = file:write_file(In, ["fn main() -> Int = 1\n", "main()\n",
                              "fn start() -> Address(Int) with m = spawn(Local, fn() = ", Wait,
                              ")\n", "start()\n", "spawn(Local, fn() = ", Wait, ")\n",
                              ":processes\n"]),
    {0, Out} = sh(alone("../bin/ern shell") ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> 1 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"input:1\nstart:1\n">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"Input">>)).

%% report §11.2, Appendix E.0 rule 6: `Shift-Tab`'s two answers from the
%% front end. Inside a call, the callee's signature with its parameters as
%% declared, in three parts around the one at the cursor, which the shell
%% colours; the prelude's too, without
%% names it does not declare; nothing outside a call. On a name, its page
%% with the version it appeared in, its own or its module's
signature_test() ->
    ?assertEqual({'Some', {<<"List.map(xs : List(a), ">>, <<"f : (a) -> b with e">>,
                           <<") -> List(b) with e">>}},
                 ern_shell:signature(<<"List.map([1], ">>)),
    ?assertEqual({'Some', {<<"send(Address(a), ">>, <<"a">>, <<") -> Unit with m">>}},
                 ern_shell:signature(<<"send(a, ">>)),
    ?assertEqual('None', ern_shell:signature(<<"1 + ">>)),
    %% a callee that is no function has no signature; a regression test,
    %% where `Sys.stdout(` showed `Sys.stdoutAddress(String)`
    ?assertEqual('None', ern_shell:signature(<<"Sys.stdout(">>)),
    ?assertEqual('None', ern_shell:signature(<<"Map.empty(">>)),
    {'Some', Map} = ern_shell:documentation(<<"List.map">>),
    ?assertMatch({_, _}, binary:match(Map, <<"*Since 0.1.0.*">>)),
    {'Some', Send} = ern_shell:documentation(<<"send">>),
    ?assertMatch({_, _}, binary:match(Send, <<"*Since 0.1.0.*">>)).

%% report §11.2: an input entered while another runs waits, and runs after
%% it, in the order entered. A regression test: the session took such an
%% input out of its mailbox while it awaited the first, and dropped it, so
%% the second was echoed and never answered
typing_ahead_test_() ->
    {timeout, 60, fun typing_ahead/0}.

typing_ahead() ->
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("receive { after 500 -> 1 }\r")},
                     {send, hex("2 + 2\r")},             % typed while the first runs
                     {expect, "1 : Int"},
                     {expect, "4 : Int"},
                     {send, "04"}],
                    30, "20x60"),
    Lines = [L || L <- binary:split(Screen, <<"\n">>, [global]), L =/= <<>>],
    Answers = [L || L <- Lines, L =:= <<"1 : Int">> orelse L =:= <<"4 : Int">>],
    ?assertEqual([<<"1 : Int">>, <<"4 : Int">>], Answers).

%% report §11.2, §6.10, §7.4: `:load` compiles a module from its source
%% under the source root and puts it in scope; `:reload` compiles again
%% what has changed, names what is still in the previous version, a process
%% or a binding holding a function of it, which keeps that version, and
%% ends it on the reload that needs that version. The session rewrites the
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
                              "let g = Demo.answer\n",
                              "spawn(Local, fn() = Demo.tick())\n",
                              write_demo(Dir, 2),
                              ":reload\n",
                              "Demo.answer()\n",
                              "g()\n",
                              write_demo(Dir, 3),
                              ":reload\n",
                              "Demo.answer()\n",
                              ":processes\n"]),
    {0, Out} = sh("../bin/ern shell --source-root " ++ Dir ++ " --load-path " ++ Dir
                  ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"Demo, compiled from demo.ern">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"1 : Int">>)),
    %% the first reload names what is still in the version it replaced
    ?assertMatch({_, _}, binary:match(Out, <<"input:1, a process, g, a binding in the previous"
                                             " version; a further reload of it ends them">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int">>)),
    %% a binding holding a function of the module keeps the version it was
    %% taken from, a regression test for a finding of the shell's review,
    %% where it ran the new code: the new answer, then the old one
    ?assertMatch({_, _}, binary:match(Out, <<"2 : Int\n> 1 : Int">>)),
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

write_demo(Dir, N) ->
    write_source(Dir, "demo.ern", demo(N)).

%% An input that writes a module's source, so that the session is what
%% changes it (E.17).
write_source(Dir, File, Source) ->
    Text = lists:flatten(Source),
    Escaped = lists:flatten([case C of $\n -> "\\n"; $" -> "\\\""; _ -> C end || C <- Text]),
    ["Fs.write(Path(\"", filename:join(Dir, File), "\"), String.toUtf8(\"", Escaped,
     "\"), 2000)\n"].

%% report §11.2: a `:reload` in which a changed module does not compile
%% reloads none of them, so the session goes on with every module as it
%% was, and the next `:reload` that compiles them all reloads them all. A
%% regression test: the modules before the one that failed were loaded
%% again while the session kept their previous interfaces, so the session
%% ran code its checker had not seen
reload_all_or_nothing_test_() ->
    {timeout, 60, fun reload_all_or_nothing/0}.

reload_all_or_nothing() ->
    Dir = scratch("ern_reload_all_"),
    ok = file:write_file(filename:join(Dir, "alpha.ern"), answer(1)),
    ok = file:write_file(filename:join(Dir, "beta.ern"), answer(1)),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, [":load Alpha\n", ":load Beta\n",
                              write_source(Dir, "alpha.ern", answer(2)),
                              write_source(Dir, "beta.ern", "export fn answer() -> Int = \"no\"\n"),
                              ":reload\n",
                              "Alpha.answer() + 10\n",
                              write_source(Dir, "beta.ern", answer(3)),
                              ":reload\n",
                              "Alpha.answer() + 20\n",
                              "Beta.answer() + 30\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"beta.ern:1:">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"nothing was reloaded">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 11 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Alpha, compiled again">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Beta, compiled again">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 22 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 33 : Int">>)).

answer(N) ->
    ["export fn answer() -> Int = ", integer_to_list(N), "\n"].

%% report §11.2, §8.5: `:load` evaluates a module's top-level bindings, a
%% service among them, before the module is in scope, and one that faults
%% loads nothing; `:reload` evaluates them again, a service of the new
%% version starting, and one that faults keeps, with those after it, what
%% the previous version gave. A regression test: `:load` evaluated none,
%% so a loaded module's value faulted with `error:badarg` when it was used
load_evaluates_bindings_test_() ->
    {timeout, 60, fun load_evaluates_bindings/0}.

load_evaluates_bindings() ->
    Dir = scratch("ern_load_bindings_"),
    Counter = fun(Start) ->
        ["export type Msg = Get(reply : Reply(Int))\n",
         "fn serve(n : Int) -> Unit with Msg =\n",
         "    receive { Get(reply = r) -> { answer(r, n); serve(n) } }\n",
         "export let service : Address(Msg) =\n",
         "    spawn(Local, fn() -> Unit with Msg = serve(", integer_to_list(Start), "))\n",
         "export let base = ", integer_to_list(Start), " * 10\n"]
    end,
    Ask = "Address.callForever(Counter.service, fn(r) = Counter.Get(reply = r))\n",
    ok = file:write_file(filename:join(Dir, "counter.ern"), Counter(1)),
    ok = file:write_file(filename:join(Dir, "bad.ern"),
                         "export let zero = List.size([])\nexport let boom = 1 / zero\n"),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, [":load Counter\n",
                              "Counter.base\n",
                              Ask,
                              ":load Bad\n",
                              "Bad.zero\n",
                              write_source(Dir, "counter.ern", Counter(2)),
                              ":reload\n",
                              "Counter.base\n",
                              Ask,
                              write_source(Dir, "counter.ern",
                                           [Counter(3), "export let late = 1 / List.size([])\n"]),
                              ":reload\n",
                              "Counter.base\n",
                              "Counter.late\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> 10 : Int\n> 1 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"Bad: a top-level binding faulted: division by zero;"
                                             " nothing was loaded">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"unknown name Bad.zero">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 20 : Int\n> 2 : Int">>)),
    %% the bindings before the one that faults take the new version's values
    ?assertMatch({_, _}, binary:match(Out, <<"Counter: a top-level binding faulted: division by"
                                             " zero; it and the bindings after it keep">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 30 : Int">>)),
    %% one the previous version did not have has no value
    ?assertMatch({_, _}, binary:match(Out, <<"the binding has no value, since one before it"
                                             " faulted">>)).

%% A directory of its own under /tmp, for a test's sources.
scratch(Prefix) ->
    Dir = filename:join("/tmp", Prefix ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% report §11.2: `:load` of a module the session has loaded is refused and
%% names `:reload`, which is what compiles a loaded module again; a process
%% running it goes on. A regression test: a second `:load` loaded the
%% module over itself, and a third purged the version a process ran and
%% killed the process, which nothing reported
load_loaded_test_() ->
    {timeout, 60, fun load_loaded/0}.

load_loaded() ->
    Dir = scratch("ern_load_twice_"),
    ok = file:write_file(filename:join(Dir, "demo.ern"), demo(1)),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, [":load Demo\n", "spawn(Local, fn() = Demo.tick())\n",
                              ":load Demo\n", ":load Demo\n", ":processes\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertEqual(2, count(Out, <<"Demo is loaded already; :reload compiles it again">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"input:1\n">>)),
    ?assertEqual(nomatch, binary:match(Out, <<"no process of the session's is running">>)).

%% report §11.2, §4.2: the module an input becomes, and the one that holds
%% what a `let` binds, have names no program writes, so a module of the
%% same spelling is a module like any other and the session's declarations
%% stand beside it. A regression test: the first input was the module
%% `Input1`, and `:load Input1` put a module in its place, taking the
%% session's `f` with it
input_namespace_test_() ->
    {timeout, 60, fun input_namespace/0}.

input_namespace() ->
    Dir = scratch("ern_inputs_"),
    ok = file:write_file(filename:join(Dir, "input1.ern"), answer(7)),
    ok = file:write_file(filename:join(Dir, "bindings2.ern"), answer(8)),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, ["fn f() -> Int = 1\n", "let x = 2\n", ":load Input1\n",
                              ":load Bindings2\n", "f() + x\n", "Input1.answer()\n",
                              "Bindings2.answer()\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"> 3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 7 : Int">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 8 : Int">>)).

%% report §11.2, §11.1: `:load` finds what the module uses as `ern build`
%% finds it, on every root of the load path. A regression test: the
%% compiler the shell calls read the dependencies' interfaces from the
%% first root alone, and did not look on the load path for a dependency
load_path_dependency_test_() ->
    {timeout, 60, fun load_path_dependency/0}.

load_path_dependency() ->
    Dir = scratch("ern_load_deps_"),
    Lib = filename:join(Dir, "lib"),
    Src = filename:join(Dir, "src"),
    First = filename:join(Dir, "first"),
    Second = filename:join(Dir, "second"),
    [ok = filelib:ensure_path(D) || D <- [Lib, Src, First]],
    ok = file:write_file(filename:join(Lib, "dep.ern"), answer(5)),
    ok = file:write_file(filename:join(Src, "user.ern"),
                         "export fn twice() -> Int = Dep.answer() * 2\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Lib ++ " --build-root " ++ Second ++ " "
                ++ filename:join(Lib, "dep.ern")),
    In = filename:join(Dir, "session.in"),
    ok = file:write_file(In, [":load User\n", "User.twice()\n"]),
    {0, Out} = sh(alone("../bin/ern shell --source-root " ++ Src ++ " --load-path " ++ First
                        ++ " --load-path " ++ Second) ++ " < " ++ In),
    ?assertMatch({_, _}, binary:match(Out, <<"User, compiled from user.ern">>)),
    ?assertMatch({_, _}, binary:match(Out, <<"> 10 : Int">>)).

%% report §11.2: the fields completion offers inside a constructor are
%% those of the constructor written there, found as the checker finds it:
%% a qualified one in its module, in an expression and in a pattern alike.
%% A regression test: the fields were looked up by the constructor's bare
%% name, so a constructor another module also declares offered the fields
%% of whichever module came first
fields_by_module_test() ->
    Dir = scratch("ern_fields_"),
    ok = file:write_file(filename:join(Dir, "circles.ern"),
                         "export type Shape = Round(radius : Int)\n"),
    ok = file:write_file(filename:join(Dir, "discs.ern"),
                         "export type Shape = Round(diameter : Int, hole : Bool)\n"),
    Texts = fun({'Fields', Names}) -> [Text || {'Name', _, _, Text} <- Names];
               (Other) -> Other
            end,
    try
        with_loaded(Dir, [<<"Circles">>, <<"Discs">>]),
        ?assertEqual([<<"diameter">>, <<"hole">>], Texts(ern_shell:context(<<"Discs.Round(">>))),
        ?assertEqual([<<"radius">>], Texts(ern_shell:context(<<"Circles.Round(">>))),
        ?assertEqual([<<"diameter">>, <<"hole">>],
                     Texts(ern_shell:context(<<"Discs.Round(hole = true, ">>))),
        ?assertEqual([<<"diameter">>, <<"hole">>],
                     Texts(ern_shell:context(<<"match s { Discs.Round(">>))),
        ?assertEqual([<<"radius">>], Texts(ern_shell:context(<<"match s { Circles.Round(">>))),
        %% an unqualified `Round` is neither module's, and has no fields
        ?assertEqual('Expression', ern_shell:context(<<"Round(">>))
    after
        forget_session()
    end.

%% report §11.2, §3.9: `:browse` prints a type whose parameter is no value
%% position as the checker does, so a variable found only there is an
%% effect variable. A regression test: the shell printed under the
%% prelude's state alone, which knows no module's types, and the printer
%% named a variable `e` only after `with`, so it was `a`
browse_effect_parameter_test() ->
    Dir = scratch("ern_hooks_"),
    ok = file:write_file(filename:join(Dir, "hooks.ern"),
                         "export type H(e) = H(f : (Int) -> Unit with e)\n"
                         "export fn drop(h) = { let H(f = _) = h; Unit }\n"),
    try
        Env = with_loaded(Dir, [<<"Hooks">>]),
        {'Right', Lines} = ern_shell:browse(Env, <<"Hooks">>),
        ?assert(lists:member(<<"Hooks.drop : (H(e)) -> Unit">>, Lines), Lines)
    after
        forget_session()
    end.

%% report §11.2, §4.2: what a command is given that is not a name is
%% refused as one, and the refusal names what was given; a name longer
%% than any the host can hold among them. A regression test: `:load .`
%% was refused as ` is not a module name`, naming nothing, and a long name
%% raised the host's limit on a name out of the front end
not_a_name_test() ->
    Long = list_to_binary(lists:duplicate(300, $a)),
    try
        ern_shell:loaded(#{}),
        Env = ern_shell:start(),
        ?assertMatch({'Left', <<". is not a module name", _/binary>>},
                     ern_shell:load(Env, <<".">>)),
        ?assertMatch({'Left', <<". is not a module name", _/binary>>},
                     ern_shell:browse(Env, <<".">>)),
        ?assertMatch({'Left', _}, ern_shell:load(Env, <<"A", Long/binary>>)),
        ?assertMatch({'Left', _}, ern_shell:browse(Env, <<"A", Long/binary>>)),
        ?assertMatch({'Left', _}, ern_shell:forget(Env, Long)),
        ?assertMatch({'Left', _}, ern_shell:doc(Env, Long)),
        ?assertMatch({'Left', _}, ern_shell:doc(Env, <<".">>)),
        ?assertEqual('None', ern_shell:documentation(<<".">>)),
        ?assertEqual('None', ern_shell:documentation(Long)),
        ?assertEqual('None', ern_shell:documentation(<<"List.", Long/binary>>))
    after
        forget_session()
    end.

%% A session begun with the modules of Dir loaded by `:load`, one after
%% the other, kept where completion reads it.
with_loaded(Dir, Modules) ->
    ern_shell:loaded(#{source_root => Dir}),
    lists:foldl(fun(M, Env) ->
                        {'Right', {Env1, _}} = ern_shell:load(Env, M),
                        Env1
                end, ern_shell:start(), Modules).

%% The front end keeps the session where completion reads it; a test that
%% set it leaves none behind for the next.
forget_session() ->
    persistent_term:erase({ern_shell, loaded}),
    persistent_term:erase({ern_shell, env}),
    ok.

%% report §11.2: on a terminal the shell reads keys, paints what is typed,
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
    Screen = pty(alone("../bin/ern shell"),
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

%% report §11.2: the start line names the toolchain's version, the one
%% `VERSION` holds, and a session at a terminal without `HOME` says once
%% that it keeps no history. A regression test: the version was written
%% into the shell by hand, and a missing home was passed over in silence
no_home_test_() ->
    {timeout, 60, fun no_home/0}.

no_home() ->
    {ok, Version} = file:read_file("../VERSION"),
    Screen = pty("env -u HOME ../bin/ern shell",
                 [{expect, "HOME is not set"},
                  {send, hex("1 + 1\r")},
                  {expect, "2 : Int"},
                  {send, "04"}],
                 20),
    ?assertMatch({_, _}, binary:match(Screen, <<"Ernest ", (string:trim(Version))/binary, ".">>)),
    ?assertEqual(1, length(binary:matches(Screen, <<"the history is not kept">>))).

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

%% What the terminal was sent, as a reader sees it: the sequences that only
%% colour the text are left out. `raw/3` keeps them, for a test of the
%% colour itself.
pty(Command, Steps, Seconds, Extra) ->
    re:replace(raw(Command, Steps, Seconds, Extra), "\e\\[[0-9;]*m", "",
               [global, {return, binary}]).

raw(Command, Steps, Seconds) ->
    raw(Command, Steps, Seconds, "").

raw(Command, Steps, Seconds, Extra) ->
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
