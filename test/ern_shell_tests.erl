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
    Screen = screen("../bin/ern --shell",
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
    Screen = pty("../bin/ern --shell",
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
