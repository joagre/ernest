%% The shell (report §11.2): sessions in line mode, a file of inputs against
%% a file of expected output, which is what the design note calls a session
%% golden test, and the keys, the region, completion and documentation
%% driven through the pseudo-terminal harness, `test/ern_pty.py`.
-module(ern_shell_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("cli/include/ern_build.hrl").

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
    {0, Output} = sh("../bin/ern shell < session/basic.in"),
    {ok, Expected} = file:read_file("session/basic.out"),
    ?assertEqual(Expected, Output).

%% report §11.2: `:type` shows an expression's type and refuses a `let` and a
%% declaration, whatever the `let` binds. A regression test: `:type let _ =
%% 1`, which declares no name, was answered as an expression
type_refuses_a_let_test_() ->
    {timeout, 60, fun type_refuses_a_let/0}.

type_refuses_a_let() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile,
                         ":type let _ = 1\n:type let x = 1\n:type type T = T\n:type 1\n"),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertEqual(3, count(Output, <<":type takes an expression, and a `let` or a declaration"
                                    " is not one">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>)).

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
                     {expect, "Counter.start : () -> Address(Counter.Msg) with m"},
                     {send, hex("spawn(fn() = Counter.boom())\r")},
                     {expect, "input 5:1 faulted: division by zero"},
                     {send, hex(":processes\r")},
                     {expect, "Counter.start:11"},
                     {send, hex(":faults\r")},
                     {expect, "Counter.main faulted: division by zero"},
                     {expect, "input 5:1 faulted: division by zero"},
                     {send, "04"}],
                    30, "60x100"),
    %% what the program printed reached the screen
    ?assertMatch({_, _}, binary:match(Screen, <<"worker here">>)),
    %% the program's entry point and a process spawned at the prompt, each
    %% reported once as it faults and once by `:faults`
    ?assertEqual(2, count(Screen, <<"Counter.main faulted: division by zero">>)),
    %% (report §11.2: a site in an input's own expression is the input,
    %% named by its count, `input 5:1`, the fifth thing entered)
    ?assertEqual(2, count(Screen, <<"input 5:1 faulted: division by zero">>)),
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
    Home = scratch("ern_home_"),
    Node = scratch("ern_node_"),
    ok = filelib:ensure_path(filename:join(Home, ".ernest")),
    ok = filelib:ensure_path(filename:join(Node, ".ernest")),
    ok = file:write_file(filename:join([Home, ".ernest", "startup"]),
                         "let greeting = \"from the user file\"\nlet shared = 1\n"),
    %% the node's file binds the same name, holds a line that does not
    %% parse, which a blank line ends as it would at a terminal, and a
    %% command, which runs as a typed one does
    ok = file:write_file(filename:join([Node, ".ernest", "startup"]),
                         "let shared = 2\n1 +\n\n:set depth 1\n"),
    InputFile = filename:join(Node, "session.in"),
    ok = file:write_file(InputFile, "greeting\nshared\n[[1]]\n"),
    {0, Output} = sh("HOME=" ++ Home ++ " ../bin/ern shell --config-dir "
                     ++ filename:join(Node, ".ernest") ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"\"from the user file\" : String">>)),
    %% the node's file ran after the person's, so its binding is the one
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    %% a failing input names its own line of the file, quoted from the file
    %% with the line before it; a regression test for a finding of the
    %% shell's review, where every one said line 1 and `:set` was refused
    ?assertMatch({_, _}, binary:match(Output, <<"startup:2:4: expected an expression">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 | let shared = 2\n2 | 1 +">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"[...] : List(List(Int))">>)),
    %% what a startup input answered was not printed
    ?assertEqual(nomatch, binary:match(Output, <<"1 : Int">>)).

%% report §11.2: a startup input's refusal and fault are named by its file
%% and line, as its diagnostic is, and a file that is not UTF-8 is said and
%% not run. A regression test: each was printed bare, and the file was read
%% as empty (findings.md's T15); the release review found `:type`'s
%% diagnostic named as though typed at the prompt, and `:load`'s refusal
%% bare, and `:type`'s excerpt now places its argument after the command
startup_failures_named_test_() ->
    {timeout, 60, fun startup_failures_named/0}.

startup_failures_named() ->
    ConfigDir = filename:join(fresh_home(), ".ernest"),
    ok = filelib:ensure_path(ConfigDir),
    Startup = filename:join(ConfigDir, "startup"),
    ok = file:write_file(Startup, ":set depth x\n:bogus\n1 / 0\nlet k = 2\n:type  1 + \"a\"\n"
                         ":load Nope\n"),
    InputFile = filename:join(ConfigDir, "session.in"),
    ok = file:write_file(InputFile, "k\n"),
    Command = "HOME=" ++ fresh_home() ++ " ../bin/ern shell --config-dir " ++ ConfigDir
        ++ " < " ++ InputFile,
    {0, Output} = sh(Command),
    [?assertMatch({_, _}, binary:match(Output, list_to_binary(Startup ++ Line)))
     || Line <- [":1: :set depth takes a number", ":2: no command :bogus",
                 ":3: fault: division by zero", ":5:12: both operands of `+`",
                 ":6: no module Nope"]],
    ?assertMatch({_, _}, binary:match(Output, <<"5 | :type  1 + \"a\"\n  |        -">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    ok = file:write_file(Startup, <<255, 254, "\n">>),
    {0, Bad} = sh(Command),
    ?assertMatch({_, _},
                 binary:match(Bad, list_to_binary(Startup ++ " is not UTF-8, and is not run"))).

%% report §11.2, §11.5: `:reload` names a loaded module whose source the
%% source root does not hold, and a module's diagnostic names its file from
%% the working directory. A regression test: `:reload` said only that no
%% source had changed, and the file was named by its absolute path
%% (findings.md's T13, T16)
reload_sources_named_test_() ->
    {timeout, 60, fun reload_sources_named/0}.

reload_sources_named() ->
    Dir = fresh_home(),
    ok = file:write_file(filename:join(Dir, "main.ern"),
                         "export fn main() : Unit with Never =\n    Io.println(\"hi\")\n"),
    ok = file:write_file(filename:join(Dir, "bad.ern"), "export fn two() : Int =\n    \"x\"\n"),
    Ern = filename:absname("../bin/ern"),
    {0, _} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " build --build-root build main.ern"),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ":reload\n"),
    {0, Output} = sh("cd " ++ Dir ++ "/build && " ++ Ern ++ " shell main.erc < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"no source has changed\nthe source root . holds no"
                                                " source of Main">>)),
    ok = file:write_file(InputFile, ":load Bad\n"),
    {0, Load} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " shell build/main.erc < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Load, <<"bad.ern:2:5: the body">>)),
    ?assertEqual(nomatch, binary:match(Load, list_to_binary(Dir))).

%% report §11: `ern` starts the host without the flags and the code path the
%% environment would give it. A regression test: ERL_AFLAGS could run code
%% with -eval before any job (findings.md's S-H)
host_flags_cleared_test_() ->
    {timeout, 60, fun host_flags_cleared/0}.

host_flags_cleared() ->
    {0, Output} = sh("ERL_AFLAGS=\"-eval io:format(leaked)\" ERL_FLAGS=\"-eval x\""
                     " ../bin/ern --version"),
    ?assertEqual(nomatch, binary:match(Output, <<"leaked">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"ern ">>)).

%% report §11.2: a startup file another user could change is said and not
%% run: one that anyone may write, and one in a directory that anyone may
%% write. A regression test: each was run (findings.md's C3-28); a file of
%% another user's is not covered, since a test cannot make one. Written
%% after the code
startup_of_anothers_test_() ->
    {timeout, 60, fun startup_of_anothers/0}.

startup_of_anothers() ->
    Refused = fun(Change) ->
                  Home = fresh_home(),
                  Dir = filename:join(Home, ".ernest"),
                  File = filename:join(Dir, "startup"),
                  ok = filelib:ensure_path(Dir),
                  ok = file:write_file(File, "Io.println(\"planted\")\n"),
                  ok = Change(Dir, File),
                  {0, Output} = sh("echo 1 | HOME=" ++ Home ++ " ../bin/ern shell"),
                  ?assertEqual(nomatch, binary:match(Output, <<"planted">>)),
                  ?assertMatch({_, _},
                               binary:match(Output, <<"startup could be changed by another user,"
                                                      " and is not run">>)),
                  ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>))
              end,
    Refused(fun(_Dir, File) -> file:change_mode(File, 8#666) end),
    Refused(fun(Dir, _File) -> file:change_mode(Dir, 8#777) end).

%% report §11.2: a HOME that is no absolute path names no startup file and
%% no history, since each would be under wherever the shell was started. A
%% regression test: `HOME=.` ran a startup file the working directory held
%% (findings.md's S-H)
relative_home_test_() ->
    {timeout, 60, fun relative_home/0}.

relative_home() ->
    Dir = fresh_home(),
    ok = filelib:ensure_path(filename:join(Dir, ".ernest")),
    ok = file:write_file(filename:join(Dir, ".ernest/startup"), "Io.println(\"planted\")\n"),
    Ern = filename:absname("../bin/ern"),
    {0, Output} = sh("cd " ++ Dir ++ " && echo 1 | HOME=. " ++ Ern ++ " shell"),
    ?assertEqual(nomatch, binary:match(Output, <<"planted">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>)),
    ?assertNot(filelib:is_regular(filename:join(Dir, ".ernest/history"))).

%% report §11.2, §4.2: `:browse Prelude` lists the prelude's types and
%% values, `:doc Prelude` shows its page, and `:doc Prelude.name` the
%% prelude's name, one its type's module documents among them. A
%% regression test: no module Prelude was in scope (findings.md's T19)
prelude_shown_test_() ->
    {timeout, 60, fun prelude_shown/0}.

prelude_shown() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ":browse Prelude\n:doc Prelude\n:doc Prelude.spawn\n"
                                    ":doc Prelude.List.size\n"),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [?assertMatch({_, _}, binary:match(Output, Text))
     || Text <- [<<"type Reason\n">>, <<"spawn : (() -> Unit with n) -> Address(n) with m+">>,
                 <<"Ernest prelude">>, <<"Starts a process on this node that runs">>,
                 <<"List.size : (List(a!)) -> Int">>]],
    ?assertEqual(nomatch, binary:match(Output, <<"type Fs.Entry">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"no module Prelude">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"no documentation">>)).

%% report §8.5, §11.2: a file whose top-level binding faults does not start
%% the shell, and the binding is named with its line. A regression test:
%% the shell printed a bare `fault:` (findings.md's T14)
faulting_binding_named_test_() ->
    {timeout, 60, fun faulting_binding_named/0}.

faulting_binding_named() ->
    Dir = fresh_home(),
    ok = file:write_file(filename:join(Dir, "init.ern"),
                         "fn zero() : Int = List.size([])\n\nlet bad : Int = 1 / zero()\n"),
    Ern = filename:absname("../bin/ern"),
    {0, _} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " build init.ern"),
    {1, Output} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " shell init.erc < /dev/null"),
    ?assertMatch({_, _}, binary:match(Output, <<"Init.bad:3 faulted: division by zero">>)),
    %% a foreign function's raise, its stack beneath; a regression test, it
    %% was reported as the shell's own fault
    ok = file:write_file(filename:join(Dir, "raise.ern"),
                         "foreign fn boom(x : Int) : Int = \"erlang:error/1\"\n\n"
                         "let bad : Int = boom(7)\n"),
    {0, _} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " build raise.ern"),
    {1, Raised} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " shell raise.erc < /dev/null"),
    ?assertMatch({_, _}, binary:match(Raised, <<"Raise.bad:3 faulted: foreign function"
                                                " erlang:error/1 raised error:7\n    ">>)).

%% report §11.2: `:load` compiles from its source a module the loaded one
%% uses that the session has not loaded, and compiles it against the
%% session's modules; `:reload` compiles again, with a changed module, each
%% loaded module that uses it where its interface changed, and a type error
%% there reloads nothing. A regression test: `:load Main` sought
%% `geo/shape.erc`, and a reload left `Main` running against the previous
%% interface, to fault (findings.md's T12, T3)
load_and_reload_dependents_test_() ->
    {timeout, 60, fun load_and_reload_dependents/0}.

load_and_reload_dependents() ->
    Dir = fresh_home(),
    ok = filelib:ensure_path(filename:join(Dir, "src/geo")),
    ok = file:write_file(filename:join(Dir, "src/geo/shape.ern"),
                         "export fn area(n : Int) : Int = n * n\n"),
    ok = file:write_file(filename:join(Dir, "src/main.ern"),
                         "export fn main() : Unit with Never =\n"
                         "    Io.println(Int.toString(Geo.Shape.area(3)))\n"),
    Write = fun(Text) ->
                ["let _ = Fs.write(Path(\"src/geo/shape.ern\"), String.toUtf8(\"", Text,
                 "\\n\"), 1000)\n"]
            end,
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Main\nMain.main()\n",
                                     Write("export fn area(n : Int) : String = \\\"big\\\""),
                                     ":reload\n",
                                     Write("export fn area(n : Int) : Int = n * 10"),
                                     ":reload\nMain.main()\n"]),
    Ern = filename:absname("../bin/ern"),
    {0, Output} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " shell --source-root src < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"Geo.Shape, compiled from geo/shape.ern\n"
                                                "Main, compiled from main.ern\n> 9\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the argument does not fit Int.toString">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"nothing was reloaded">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Geo.Shape, compiled again\n> 30\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"Main, compiled again">>)).

%% report §11.2: in line mode, as at a terminal, an input the parser cannot
%% finish takes the next line, and a blank line or the end of input runs
%% what there is; a startup file's inputs are taken so too, each named by
%% the line it begins on. A regression test: a line was an input, so code
%% in `ern format`'s layout could not be piped in (findings.md's T29)
line_mode_continues_test_() ->
    {timeout, 60, fun line_mode_continues/0}.

line_mode_continues() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, "fn f(x : Int) : Int =\n    x + 1\nf(2)\n1 +\n\ny\n1 +\n"),
    ConfigDir = filename:join(Dir, "conf"),
    ok = filelib:ensure_path(ConfigDir),
    ok = file:write_file(filename:join(ConfigDir, "startup"),
                         "fn g(x : Int) : Int =\n    x * 2\n\nlet y =\n    g(4)\n2 *\n"),
    {0, Output} = sh("HOME=" ++ fresh_home() ++ " ../bin/ern shell --config-dir " ++ ConfigDir
                     ++ " < " ++ InputFile),
    [?assertMatch({_, _}, binary:match(Output, Said))
     || Said <- [<<"... f : (Int) -> Int">>, <<"3 : Int">>, <<"8 : Int">>,
                 <<"input 3:1:4: expected an expression instead of end of input">>,
                 <<"input 5:1:4: expected an expression instead of end of input">>,
                 <<"startup:6:4: expected an expression instead of end of input">>]].

%% report §11.2: in line mode the shell exits with status 0 when its input
%% ends, whatever its inputs did, and what programs write to standard error
%% goes to standard output with the rest; one that cannot start exits with
%% status 1. A regression test, written as the report came to say so
line_mode_status_and_streams_test_() ->
    {timeout, 60, fun line_mode_status_and_streams/0}.

line_mode_status_and_streams() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, "Io.printlnError(\"to standard error\")\n1 / 0\nnope\n"),
    Command = "HOME=" ++ fresh_home() ++ " ../bin/ern shell < " ++ InputFile,
    {0, Output} = sh(Command ++ " 2>/dev/null"),
    [?assertMatch({_, _}, binary:match(Output, Said))
     || Said <- [<<"to standard error">>, <<"fault: division by zero">>,
                 <<"unknown name nope">>]],
    ok = file:write_file(filename:join(Dir, "init.ern"),
                         "let bad : Int = 1 / 0\n\nexport fn main() : Unit with Never =\n"
                         "    Io.println(\"hi\")\n"),
    Ern = filename:absname("../bin/ern"),
    {0, _} = sh("cd " ++ Dir ++ " && " ++ Ern ++ " build init.ern"),
    ?assertMatch({1, _}, sh("cd " ++ Dir ++ " && " ++ Ern ++ " shell init.erc < " ++ InputFile)).

%% report §11.2: without `--config-dir` the working directory's
%% `.ernest/startup` is not run, and a file both paths name runs once. A
%% regression test: a cloned tree's startup ran as the shell started in it,
%% and started in `$HOME` the person's file ran twice; it does not cover two
%% paths that reach one file through a link
startup_of_the_working_directory_test_() ->
    {timeout, 60, fun startup_of_the_working_directory/0}.

startup_of_the_working_directory() ->
    Ern = filename:absname("../bin/ern"),
    Tree = fresh_home(),
    ok = filelib:ensure_path(filename:join(Tree, ".ernest")),
    ok = file:write_file(filename:join([Tree, ".ernest", "startup"]),
                         "let planted = \"ran\"\n"),
    InputFile = filename:join(Tree, "session.in"),
    ok = file:write_file(InputFile, "planted\n"),
    {0, Planted} = sh("cd " ++ Tree ++ " && HOME=" ++ fresh_home() ++ " " ++ Ern
                      ++ " shell < " ++ InputFile),
    ?assertEqual(nomatch, binary:match(Planted, <<"\"ran\" : String">>)),
    %% started in `$HOME`, and with `$HOME/.ernest` named, the person's file
    %% runs once: its failing line is reported once
    Home = fresh_home(),
    ok = filelib:ensure_path(filename:join(Home, ".ernest")),
    ok = file:write_file(filename:join([Home, ".ernest", "startup"]), "1 +\n"),
    Empty = filename:join(Home, "session.in"),
    ok = file:write_file(Empty, ""),
    lists:foreach(fun(Option) ->
                      {0, Output} = sh("cd " ++ Home ++ " && HOME=" ++ Home ++ " " ++ Ern
                                       ++ " shell" ++ Option ++ " < " ++ Empty),
                      ?assertEqual(1, count(Output, <<"startup:1:4: expected an expression">>))
                  end, ["", " --config-dir " ++ filename:join(Home, ".ernest")]).

%% report §11.2: the shell writes a fault's cause as `ern run` does, each
%% control character as its escape, a spawned process's and an input's own
%% alike. A regression test: the cause reached the terminal as it was, an
%% escape and a line feed among it, and an input's own did until the
%% release review (findings.md's C3-1)
fault_line_escaped_test_() ->
    {timeout, 60, fun fault_line_escaped/0}.

fault_line_escaped() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, "spawn(fn() = fault(\"a\\u{1b}b\\nforged\"))\n:faults\n"
                                    "fault(\"c\\u{1b}d\")\n"),
    {0, Output} = sh("HOME=" ++ Dir ++ " ../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"input 1:1 faulted: a\\u{1B}b\\nforged">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"fault: c\\u{1B}d">>)),
    ?assertEqual(nomatch, binary:match(Output, <<27>>)).

%% report §11.2, Appendix E.17: the history's directory is its owner's
%% alone, made so before the history is written, and one an earlier
%% version left open to others is closed before the history is read, even
%% where the history cannot be read. A regression test: the directory and
%% the file took the host's default mode, and others could read what was
%% typed; and the directory was closed only after a read that succeeded
history_is_private_test_() ->
    {timeout, 60, fun history_is_private/0}.

history_is_private() ->
    Home = fresh_home(),
    Dir = filename:join(Home, ".ernest"),
    _ = pty("HOME=" ++ Home ++ " ../bin/ern shell",
            [{expect, "> "}, {send, hex("1 + 1\r")}, {expect, "2 : Int"}, {send, "04"}], 20),
    {ok, #file_info{mode = Made}} = file:read_file_info(Dir),
    ?assertEqual(0, Made band 8#077),
    ok = file:change_mode(Dir, 8#755),
    _ = pty("HOME=" ++ Home ++ " ../bin/ern shell", [{expect, "> "}, {send, "04"}], 20),
    {ok, #file_info{mode = Read}} = file:read_file_info(Dir),
    ?assertEqual(0, Read band 8#077),
    ok = file:change_mode(Dir, 8#755),
    ok = file:change_mode(filename:join(Dir, "history"), 8#000),
    _ = pty("HOME=" ++ Home ++ " ../bin/ern shell", [{expect, "> "}, {send, "04"}], 20),
    {ok, #file_info{mode = Unreadable}} = file:read_file_info(Dir),
    ?assertEqual(0, Unreadable band 8#077).

%% report §11.2: on a terminal the shell commits its transcript to the
%% terminal and paints only the live region, the tail of what programs
%% write and the line being typed under it. What a program writes is
%% never mixed into the line being typed, and the transcript reads in the
%% order the lines were written
live_region_test_() ->
    {timeout, 60, fun live_region/0}.

live_region() ->
    Print = "spawn(fn() = List.foreach(List.range(1, 12),"
            " fn(n) = Io.println(\"line \" <> Int.toString(n))))\r",
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("1 + 1\r")},
                     {expect, "2 : Int"},
                     {send, hex(Print)},
                     {expect, "line 12"},
                     {send, hex("2 + 2\r")},
                     {expect, "4 : Int"},
                     {send, "04"}],
                    20, "30x60"),
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
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
%% matching, and the colours, run by `ern test` over the directory the
%% shell is built into, so that a module's tests run from the day it is
%% written
editor_test_() ->
    {timeout, 60, fun editor/0}.

editor() ->
    %% the shell renders documentation with libs/markdown and styles it with
    %% libs/ansi, which a run of its modules puts on the load path as any
    %% program using a library does
    {Status, Output} = sh("../bin/ern test --load-path ../build/libs/markdown"
                          " --load-path ../build/libs/ansi ../build/shell"),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    Passed = [Line || Line <- Lines, binary:match(Line, <<": passed">>) =/= nomatch],
    %% a module with tests is named before them, and one without is passed
    %% over (report §11.2)
    ?assertEqual([<<"Shell.Command">>, <<"Shell.Complete">>, <<"Shell.Editor">>,
                  <<"Shell.History">>, <<"Shell.Region">>, <<"Shell.Style">>],
                 Lines -- Passed),
    ?assert(length(Passed) >= 100),
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
                     {expect, "7 + 7"},                 % the line painted again
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

%% report §11.2, §11: the history file is trimmed at start to the last
%% thousand inputs, written whole under a name of the session's own and
%% renamed over the history, so that a file another session was writing,
%% or one a killed session left, is not written over and does not stop the
%% trim. A regression test: every session wrote `history.new`, two at once
%% into one file
history_trimmed_beside_test_() ->
    {timeout, 60, fun history_trimmed_beside/0}.

history_trimmed_beside() ->
    Home = fresh_home(),
    Dir = filename:join(Home, ".ernest"),
    ok = filelib:ensure_path(Dir),
    ok = file:change_mode(Dir, 8#700),
    File = filename:join(Dir, "history"),
    ok = file:write_file(File, [[integer_to_list(Number), "\n"] || Number <- lists:seq(1, 1005)]),
    ok = file:change_mode(File, 8#600),
    Left = filename:join(Dir, "history.new1"),
    ok = file:write_file(Left, <<"a session's own\n">>),
    _ = pty("HOME=" ++ Home ++ " ../bin/ern shell",
            [{expect, "> "}, {send, "04"}],
            20),
    Lines = history_lines(File),
    ?assertEqual({1000, <<"6">>, <<"1005">>}, {length(Lines), hd(Lines), lists:last(Lines)}),
    ?assertEqual({ok, <<"a session's own\n">>}, file:read_file(Left)),
    ?assertEqual({ok, ["history", "history.new1"]},
                 case file:list_dir(Dir) of
                     {ok, Names} -> {ok, lists:sort(Names)};
                     Error -> Error
                 end).

%% report §11.2: a history file that cannot be read is reported once, and
%% the session goes on without one. A regression test: a second report came
%% at the first input, as the session tried to write it (findings.md's T18)
history_unreadable_test_() ->
    {timeout, 60, fun history_unreadable/0}.

history_unreadable() ->
    Home = fresh_home(),
    File = filename:join([Home, ".ernest", "history"]),
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, "11 + 11\n"),
    ok = file:change_mode(File, 8#000),
    Screen = pty("HOME=" ++ Home ++ " ../bin/ern shell",
                 [{expect, "> "},
                  {send, hex("1 + 1\r")},
                  {expect, "2 : Int"},
                  {send, hex("2 + 2\r")},
                  {expect, "4 : Int"},
                  {send, "04"}],
                 20),
    ok = file:change_mode(File, 8#600),
    ?assertEqual(1, count(Screen, <<"the history is not kept">>)),
    ?assertMatch({_, _},
                 binary:match(Screen, <<"since it could not be read: permission was denied">>)).

history_lines(File) ->
    {ok, Text} = file:read_file(File),
    [Line || Line <- binary:split(Text, <<"\n">>, [global]), Line =/= <<>>].

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
                     {expect, "... "},
                     {send, hex("\r")},                   % the blank line runs it
                     {expect, "expected a pattern"},
                     {send, "1b5b41"},                    % ArrowUp: the input back, whole
                     {expect, "fn f("},
                     %% C-d leaves only on an empty line: C-c cancels the
                     %% input brought back, so the session ends rather than
                     %% waiting out the harness's timeout
                     {send, "03"},
                     {send, "04"}],
                    30, "30x46"),
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
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

%% report §11.2: a line `C-c` abandons runs nothing and is kept in the
%% history, where `C-p` recalls it. A regression test of what the shell
%% did and the report came to say (findings.md's C3-23)
abandoned_line_kept_test_() ->
    {timeout, 90, fun abandoned_line_kept/0}.

abandoned_line_kept() ->
    Home = fresh_home(),
    Screen = screen("HOME=" ++ Home ++ " ../bin/ern shell",
                    [{expect, "> "},
                     {send, hex("40 + 1")},
                     {expect, "40 + 1"},
                     {send, "03"},                        % C-c abandons it
                     {expect, "> "},
                     {send, "10"},                        % C-p recalls it
                     {send, hex("\r")},
                     {expect, "41 : Int"},
                     {send, "04"}],
                    30, "30x46"),
    ?assertMatch({_, _}, binary:match(Screen, <<"41 : Int">>)),
    ?assertEqual(1, count(Screen, <<"41 : Int">>)),
    ?assertEqual([<<"40 + 1">>], history_lines(filename:join([Home, ".ernest", "history"]))).

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
                     {expect, "> "},
                     {send, "04"}],
                    30, "12x40"),
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
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
                  {expect, "a     b"},
                  {send, "03"},                       % abandon the line
                  {expect, "> "},
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
             {send, "03"},                            % the next key
             {expect, "> "},
             {send, "04"}],
    Screen = screen(alone("../bin/ern shell"), Steps, 30, "16x74"),
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
    Text = iolist_to_binary(Lines),
    %% the completed name ran
    ?assertMatch({_, _}, binary:match(Text, <<"[2] : List(Int)">>)),
    %% the line being typed is still there, completed to what they share
    ?assert(lists:any(fun(Line) -> binary:match(Line, <<"> List.filter">>) =/= nomatch end, Lines)),
    %% and the listing went with the next key, leaving the transcript
    %% without it
    ?assertEqual(nomatch, binary:match(Text, <<"List.filterMap :">>)),
    %% it was painted under the line, the candidates with their types
    Bytes = pty(alone("../bin/ern shell"), Steps, 30, " --size 16x74"),
    %% report §3.9: filter gives each element to `keep` and to its result
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.filter\r\nList.filter : (List(a!)">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nList.filterMap : (List(a)">>)).

%% report §11.2, §3.5: a field that two constructors give two types is no
%% selector, and `.` completes to no field of it; the session goes on. A
%% regression test: the completion crashed the shell (findings C15)
field_of_two_types_test_() ->
    {timeout, 90, fun field_of_two_types/0}.

field_of_two_types() ->
    Steps = [{expect, "> "},
             {send, hex("type T = A(x : Int, n : Int) | B(x : String, n : Int)\r")},
             {expect, "type T"},
             {send, hex("let t = A(x = 1, n = 2)\r")},
             {expect, "t : T"},
             {send, hex("t.") ++ "09" ++ "09"},
             {expect, "t.n"},
             {send, "15"},
             {send, hex("40 + 2\r")},
             {expect, "42 : Int"},
             {expect, "> "},
             {send, "04"}],
    Bytes = pty(alone("../bin/ern shell"), Steps, 30, " --size 16x74"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"t.n">>)),
    ?assertEqual(nomatch, binary:match(Bytes, <<"t.x">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"42 : Int">>)).

%% report §11.2, §3.5: after a name the session binds and a `.`, `Tab`
%% completes the fields its type selects, along a chain, and lists them
%% with their types. A regression test for item 54; it does not cover a
%% module's exported value
field_completion_test_() ->
    {timeout, 90, fun field_completion/0}.

field_completion() ->
    Steps = [{expect, "> "},
             {send, hex("type P = P(count : Int, name : String)\r")},
             {expect, "type P"},
             {send, hex("type Q = Q(p : P)\r")},
             {expect, "type Q"},
             {send, hex("let q = Q(p = P(count = 2, name = \"a\"))\r")},
             {expect, "q : Q"},
             {send, hex("q.p.na") ++ "09"},            % Tab: along the chain
             {expect, "q.p.name"},
             {send, hex("\r")},
             {expect, "\"a\" : String"},
             {send, hex("q.p.") ++ "09" ++ "09"},      % Tab twice: the listing
             {expect, "q.p.count : Int"},
             {send, "03"},
             {expect, "> "},
             {send, "04"}],
    Bytes = pty(alone("../bin/ern shell"), Steps, 30, " --size 16x74"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\"a\" : String">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"q.p.count : Int">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"q.p.name : String">>)).

%% report §5.6, §11.2: after the `.` of a path in a record update, `Tab`
%% lists the fields of the type the path has reached; written after the code
path_completion_test_() ->
    {timeout, 60, fun path_completion/0}.

path_completion() ->
    Steps = [{expect, "> "},
             {send, hex("type Stats = Stats(indexed : Int, hits : Int)\r")},
             {expect, "type Stats"},
             {send, hex("type Pool = Pool(name : String, stats : Stats)\r")},
             {expect, "type Pool"},
             {send, hex("let pool = Pool(name = \"p\", stats = Stats(indexed = 0, hits = 0))\r")},
             {expect, "pool : Pool"},
             {send, hex("Pool(..pool, stats.") ++ "09" ++ "09"},   % Tab twice: the listing
             {expect, "indexed : Int"},
             {send, "03"},
             {expect, "> "},
             {send, "04"}],
    Bytes = pty(alone("../bin/ern shell"), Steps, 30, " --size 16x74"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"indexed : Int">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"hits : Int">>)).

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
                 {expect, "list : List(a)"},
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
                                               "List.map(list : List(a), f : (a) -> b with e)"
                                               " : List(b) with e">>)),
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
    SourceRoot = scratch("ern_root_"),
    ok = filelib:ensure_path(filename:join(SourceRoot, "http")),
    ok = file:write_file(filename:join([SourceRoot, "http", "parser.ern"]), "export let one = 1\n"),
    ok = file:write_file(filename:join(SourceRoot, "demo.ern"), "export let two = 2\n"),
    ok = filelib:ensure_path(filename:join(SourceRoot, "Bad")),
    Bytes = pty(alone("../bin/ern shell --source-root " ++ SourceRoot),
                [{expect, "> "},
                 {send, hex(":bindings") ++ "09"},        % whole, and takes nothing
                 {expect, "what the session declares"},
                 {send, "03"},
                 {send, hex(":bro") ++ "09"},
                 %% the listing, which is painted after the completed line
                 {expect, ":browse Module"},
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
                 {send, hex(":output ") ++ "09"},          % lists nothing, indents nothing
                 %% nothing marks that the Tab did nothing, and the screen paints
                 %% only its latest state, so a wrong indent would go unseen if
                 %% the next key came at once; the wait is the harness's to make
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
               {expect, "list : List(a)"},
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
               {send, hex("fn g(n : Int) : Int = List.foldLeft([n], ") ++ "1b5b5a"},
               {expect, "acc : b"},
               {send, "03"},
               {send, hex(":type List.foldLeft(") ++ "1b5b5a"},
               {expect, "acc : b"},
               {send, "03"},
               {send, hex("Point(x = 1, yval = ") ++ "1b5b5a"},
               {expect, ": Point"},
               {send, "03"},
               {send, "04"}],
              30),
    ?assertMatch({_, _}, binary:match(Raw, <<"list : List(a), \e[36mf : (a) -> b with e\e[39m)">>)),
    %% the first argument marked after `let` and `:type`, the second in the
    %% declaration's body; a repaint may write a row twice, so each is looked
    %% for, not counted
    ?assertMatch({_, _},
                 binary:match(Raw, <<"List.foldLeft(\e[36mlist : List(a)\e[39m, acc : b">>)),
    ?assertMatch({_, _},
                 binary:match(Raw, <<"List.foldLeft(list : List(a), \e[36macc : b\e[39m">>)),
    ?assertMatch({_, _}, binary:match(Raw, <<"Point(x : Int, \e[36myval : Int\e[39m) : Point">>)).

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
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nspawn : (() -> Unit">>)),
    ?assertMatch({_, _}, binary:match(Bytes, <<"> List.map(\r\n">>)).

%% report §11.2: with nothing typed, the candidates are the names the
%% session declares, its constructors among them. A regression test, found
%% by a read of the front end in MVP 2.99b's item 7: the session's
%% constructors were read under a key it does not have, and left out
session_constructors_listed_test_() ->
    {timeout, 60, fun session_constructors_listed/0}.

session_constructors_listed() ->
    Bytes = pty(alone("../bin/ern shell"),
                [{expect, "> "},
                 {send, hex("type Coin = Heads | Tails\r")},
                 %% the declaration's answer is its own echo, so the next
                 %% input's answer says that it was made
                 {send, hex("1\r")},
                 {expect, "1 : Int"},
                 {send, hex("List.map(") ++ "09"},
                 {expect, "module Bool"},
                 {send, "03"},
                 {send, "04"}],
                30, " --size 40x80"),
    ?assertMatch({_, _}, binary:match(Bytes, <<"\r\nHeads : Coin">>)).

%% report §11.2: after `:forget`, what completes is a name the session
%% declares. A regression test: make untested found that no test reached
%% the session's names for it.
forget_completion_test_() ->
    {timeout, 60, fun forget_completion/0}.

forget_completion() ->
    Bytes = pty(alone("../bin/ern shell"),
                [{expect, "> "},
                 {send, hex("let zebra = 1\r")},
                 {expect, "zebra : Int"},
                 {send, hex(":forget ze") ++ "09"},
                 {expect, "bra"},
                 {send, "03"},
                 {send, "04"}],
                30, " --size 60x100"),
    ?assertEqual(2, count(Bytes, <<"zebra : Int">>)).

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
                 %% nothing marks that the Tab offered nothing, as with :output
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
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
    ?assert(lists:member(<<"> let longname = \"abcdefghijklmnopqrstuv">>, Lines)).

%% report §11.2: `:load` of a source that does not lex or parse reports its
%% diagnostic and the session goes on, and so does `:load` of a source that
%% is not UTF-8 or cannot be read (§11.8). A regression test: the error was
%% raised out of the front end, and the shell ended with it; the release
%% review found the same of the last two
load_unreadable_test_() ->
    {timeout, 60, fun load_unreadable/0}.

load_unreadable() ->
    Dir = scratch("ern_bad_"),
    ok = file:write_file(filename:join(Dir, "bad.ern"), "export fn f() : Int = 1 \\ 2\n"),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(filename:join(Dir, "garbled.ern"), <<"export let x : Int = ", 16#FF>>),
    Closed = filename:join(Dir, "closed.ern"),
    ok = file:write_file(Closed, "export let y : Int = 1\n"),
    ok = file:change_mode(Closed, 8#000),
    ok = file:write_file(InputFile, ":load Bad\n:load Garbled\n:load Closed\n1\n"),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ok = file:change_mode(Closed, 8#600),
    ?assertMatch({_, _}, binary:match(Output, <<"bad.ern:1:25: illegal character">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"garbled.ern:1:22: input is not valid UTF-8">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"closed.ern: permission denied">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>)).

%% report §11.8, §8.2: a line of standard input that is not UTF-8 faults
%% the shell, which reads it, and the shell ends with status 1, as a run
%% does whose entry process faults. A regression test of the status, the
%% shell's own faults now being failures of ern: that a fault by a defect
%% exits with status 70 is not covered, since no input gives the shell one
input_fault_status_test_() ->
    {timeout, 60, fun input_fault_status/0}.

input_fault_status() ->
    {1, Output} = sh("printf \"1 + 1\\n\\377\\n2 + 2\\n\" | ../bin/ern shell"),
    ?assertMatch({_, _}, binary:match(Output, <<"fault: the standard input is not UTF-8">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"4 : Int">>)).

%% report §11.2: `:load` refuses a module whose dependency has no source
%% and a compiled form it cannot read, with a sentence naming it. A
%% regression test of compile_source's refusal, which the shell had told
%% apart from diagnostics by the shape of a list, and, since the release
%% review, of the refusal's text, which quoted the file's bytes
load_unreadable_dependency_test_() ->
    {timeout, 60, fun load_unreadable_dependency/0}.

load_unreadable_dependency() ->
    Dir = scratch("ern_dep_"),
    ok = file:write_file(filename:join(Dir, "top.ern"), "export fn g() : Int = Dep.f()\n"),
    ok = file:write_file(filename:join(Dir, "dep.erc"), "not a module\n"),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ":load Top\n1\n"),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"compile Dep first: ">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"dep.erc: not a compiled module">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>)).

%% report §11.2: a binding and a function may take the names the host gives
%% every module, and a later input reaches them. A regression test: a
%% `let module_info` faulted inside the shell, and a later input calling
%% `record_info` reached the host's function.
host_reserved_names_test_() ->
    {timeout, 60, fun host_reserved_names/0}.

host_reserved_names() ->
    InputFile = scratch_file("ern_reserved_"),
    ok = file:write_file(InputFile, ["let module_info = 1\n", "fn record_info(x : Int) : Int = x\n",
                                     "module_info + record_info(2)\n", "let f = record_info\n",
                                     "f(5)\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"5 : Int">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"fault">>)).

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
    InputFile = scratch_file("ern_unload_"),
    CountLoaded = "List.size(loadedModules())\n",
    ok = file:write_file(InputFile, [
        "foreign fn loadedModules() : List(Foreign.Term) with m = \"code:all_loaded/0\"\n",
        CountLoaded, [["1 + ", integer_to_list(Index), "\n"] || Index <- lists:seq(1, 50)],
        CountLoaded,
        "fn(x : Int) : Int = x + 1\n",
        "it(41)\n",
        "let _ = spawn(fn() : Unit with Never = {"
        " let _ = receive { after 300 -> Unit }; Io.println(\"late\") })\n",
        "receive { after 600 -> Unit }\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [Before, After] = [Answer || Answer <- answers(Output, 1), Answer > 100],
    %% each expression leaves its holder of `it` loaded, and its own module
    %% not
    ?assert(After - Before =< 50 + 5),
    ?assertMatch({_, _}, binary:match(Output, <<"> 42 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"late">>)).

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
    InputFile = scratch_file("ern_atoms_"),
    Info = "info(Erl.atom(\"atom_count\"))\n",
    ok = file:write_file(InputFile, ["foreign fn info(k : Foreign.Term) : Int with m ="
                                     " \"erlang:system_info/1\"\n", Info,
                                     [["1 + ", integer_to_list(Index), "\n"]
                                      || Index <- lists:seq(1, 200)],
                                     Info]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [Before, After] = answers(Output, 5),
    ?assert(After - Before =< 3 * 200).

%% report §2.3, §11.2: a declaration made again, and an input whose value is
%% a function once nothing holds it, give their modules and numbers back,
%% so they cost no atoms of their own. A regression test, written after the
%% code: every declaration kept its module for the rest of the session.
%% The bound allows what the session makes on its own; the count begins
%% after one round, since the first of each kind of input loads the code
%% that compiles it, the formatter's among it, which `ern doc`'s layout of a
%% type declaration uses (report §11.4).
declarations_let_go_test_() ->
    {timeout, 120, fun declarations_let_go/0}.

declarations_let_go() ->
    InputFile = scratch_file("ern_decls_"),
    Info = "info(Erl.atom(\"atom_count\"))\n",
    Round = fun(Index) ->
                ["fn f(n : Int) : Int = n * ", integer_to_list(Index), "\n",
                 "type Shape = Circle(Int) | Square(Int)\n",
                 "fn(n : Int) : Int = n + ", integer_to_list(Index), "\n"]
            end,
    ok = file:write_file(InputFile, ["foreign fn info(k : Foreign.Term) : Int with m ="
                                     " \"erlang:system_info/1\"\n", Round(0), Info,
                                     [Round(Index) || Index <- lists:seq(1, 100)],
                                     Info]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [Before, After] = answers(Output, 5),
    ?assert(After - Before =< 60).

%% report §2.3, §11.2: an expression at the prompt leaves no code behind,
%% however many distinct ones there are. A regression test, written after
%% the code: each input's module answered its entry function as a value,
%% and the host keeps an entry for every such function of every version of
%% a module it loads, 176 bytes each for as long as the node lives.
expressions_leave_no_code_test_() ->
    {timeout, 120, fun expressions_leave_no_code/0}.

expressions_leave_no_code() ->
    InputFile = scratch_file("ern_code_"),
    Code = "memory(Erl.atom(\"code\"))\n",
    ok = file:write_file(InputFile, ["foreign fn memory(k : Foreign.Term) : Int with m ="
                                     " \"erlang:memory/1\"\n",
                                     [["1 + ", integer_to_list(Index), "\n"]
                                      || Index <- lists:seq(1, 50)],
                                     Code,
                                     [["1 + ", integer_to_list(Index), "\n"]
                                      || Index <- lists:seq(51, 250)],
                                     Code]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [Before, After] = answers(Output, 7),
    ?assert(After - Before < 2000).

%% report §11.2, §4.4: an `abstract type` at the prompt keeps its
%% constructors to the input that declares it, each input being a module
%% of its own. A regression test, written after the report said so
abstract_at_the_prompt_test_() ->
    {timeout, 60, fun abstract_at_the_prompt/0}.

abstract_at_the_prompt() ->
    InputFile = scratch_file("ern_abstract_"),
    ok = file:write_file(InputFile, ["abstract type T = T(Int)\n", "T(1)\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({_, _},
                 binary:match(Output, <<"T is the constructor of an abstract type and is not"
                                        " visible outside the input that declared it">>)).

%% report §6.9, §11.2: an input typed again, with a lambda and a spawn,
%% leaves no code behind, though its spawn site names it by its count. A
%% regression test, written after the code: the site's `input N` was
%% compiled into the input's module, so each count made a version of its
%% own, and the host's entry for its lambda, which `make load` found. The
%% first three hundred are the warm-up, in which an input whose module a
%% spawned process still runs leaves the next one a number of its own, and
%% the reading of the memory, typed again, takes a version for each number
%% it lands on
expressions_again_leave_no_code_test_() ->
    {timeout, 120, fun expressions_again_leave_no_code/0}.

expressions_again_leave_no_code() ->
    InputFile = scratch_file("ern_again_"),
    Code = "memory(Erl.atom(\"code\"))\n",
    Spawn = "spawn(fn() = Unit)\n",
    ok = file:write_file(InputFile, ["foreign fn memory(k : Foreign.Term) : Int with m ="
                                     " \"erlang:memory/1\"\n",
                                     [[lists:duplicate(100, Spawn), Code] || _ <- lists:seq(1, 3)],
                                     lists:duplicate(200, Spawn), Code]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    [_, _, Before, After] = answers(Output, 7),
    ?assert(After - Before < 2000).

%% report §11.2, §6.10: a declaration made again is let go only when
%% nothing reaches it: a function declared after it still calls it, a
%% binding holding its function or a value of its type keeps it, and a
%% process running its code runs on. Written with the code that lets it go.
declarations_kept_while_reached_test_() ->
    {timeout, 120, fun declarations_kept_while_reached/0}.

declarations_kept_while_reached() ->
    InputFile = scratch_file("ern_reached_"),
    ok = file:write_file(InputFile, ["fn f(n : Int) : Int = n\n",
                                     "fn g(n : Int) : Int = f(n) + 1\n",
                                     "let h = f\n",
                                     "type T = A(Int) | B\n",
                                     "let a = A(7)\n",
                                     "fn later() : Unit with Never = {"
                                     " receive { after 400 -> Unit };"
                                     " Io.println(\"old code ran\") }\n",
                                     "let _ = spawn(later)\n",
                                     "fn f(n : Int) : Int = n * 100\n",
                                     "type T = C\n",
                                     "fn later() : Unit with Never = Unit\n",
                                     [["1 + ", integer_to_list(Index), "\n"]
                                      || Index <- lists:seq(1, 30)],
                                     "g(1)\n", "h(3)\n", "a\n", "f(1)\n",
                                     "receive { after 600 -> Unit }\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 2 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 3 : Int">>)),
    ?assertMatch({match, _}, re:run(Output, "A\\(7\\) : \\$Input[0-9]+\\.T")),
    ?assertMatch({_, _}, binary:match(Output, <<"> 100 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"old code ran">>)).

%% report §11.2: a module the session reaches by a constructor alone is
%% kept, the constructors of a type declared again staying in scope for the
%% earlier type. A regression test, found by a read of the front end in
%% MVP 2.99b's item 7: the collection read the session's constructors under
%% a key it does not have, let the earlier input's module go, and the
%% checker failed on the constructor's next use
shadowed_constructor_kept_test_() ->
    {timeout, 60, fun shadowed_constructor_kept/0}.

shadowed_constructor_kept() ->
    Dir = fresh_home(),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, "type A = X | Y\ntype A = Z\nX\n"),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({match, _}, re:run(Output, "> X : \\$Input1\\.A\n")),
    ?assertEqual(nomatch, binary:match(Output, <<"fault">>)).

%% report §11.2: every refusal of a command is red, as a diagnostic's first
%% line is, and an answer is plain. A regression test for a finding of the
%% session of real use: `:load`'s refusal was red and `:set`'s was not, the
%% colour following the code path and not the meaning; the release review
%% found `:load` of a standard library module answered as a success
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
               {send, hex(":load List\r")},
               {expect, "in scope from the start"},
               {send, hex(":bindings\r")},
               {expect, "declares nothing yet"},
               {send, "04"}],
              30),
    Red = fun(Text) -> binary:match(Raw, <<"\e[31m", Text/binary>>) =/= nomatch end,
    ?assert(Red(<<"no command :sreload">>)),
    ?assert(Red(<<":set depth takes a number">>)),
    ?assert(Red(<<":reload takes no argument">>)),
    ?assert(Red(<<"hhhh is not a module name">>)),
    ?assert(Red(<<"List is the standard library's">>)),
    ?assertNot(Red(<<"the session declares nothing yet">>)).

%% report §11.2: what may stand at the cursor decides what completes,
%% and the parser is what knows: after `:` a type, inside a named
%% constructor its fields, and everywhere else the values,
%% constructors and modules in scope
slot_test_() ->
    {timeout, 90, fun slot/0}.

slot() ->
    Screen = screen(alone("../bin/ern shell"),
                    [{expect, "> "},
                     {send, hex("type Zebra = Zebra(width : Int, height : Int)\r")},
                     %% the echo of a declaration holds its own name, so an
                     %% input after it marks that it has run, the session
                     %% taking its inputs in order
                     {send, hex("0\r")},
                     {expect, "0 : Int"},
                     {send, hex("let z : Ze") ++ "09"},          % a type position
                     {expect, "let z : Zebra"},
                     {send, hex(" = Zebra(w") ++ "09"},          % a field position
                     {expect, "Zebra(width"},
                     {send, hex(" = 1, hei") ++ "09"},           % the other field
                     {expect, "height"},
                     {send, hex(" = 2)\r")},
                     {expect, "z : Zebra"},
                     {expect, "> "},
                     {send, "04"}],
                    30, "16x70"),
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
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
    InputFile = scratch_file("ern_open_"),
    ok = file:write_file(InputFile,
                         "let p = spawn(fn() = receive { _ -> Unit })\n"
                         "let q : Address(Int) = spawn(fn() = receive { _ -> Unit })\n"
                         "send(q, 1)\n"
                         "kill(q)\n"
                         "1 + 1\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    %% the open binding is refused, and says what would settle it
    ?assertMatch({_, _}, binary:match(Output, <<"the type of p is not determined">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"bind it with an annotation">>)),
    %% the annotated one is taken, and `kill` reaches it
    ?assertMatch({_, _}, binary:match(Output, <<"q : Address(Int)">>)),
    %% and the session goes on, which it did not before: a scheme with a
    %% free variable used to break every input after it
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"badkey">>)).

%% report §11.2, §11.5: a `let` at the prompt binds as a `let` in a block
%% does, so a value that is not of its annotation's type is told so as a
%% block's `let` is. A regression test: it was told of a declared return
%% type, since the annotation was the input's result
annotated_let_test_() ->
    {timeout, 60, fun annotated_let/0}.

annotated_let() ->
    InputFile = scratch_file("ern_let_"),
    ok = file:write_file(InputFile, "let w : Int = \"x\"\nlet n : Int = 2\nn + 1\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"the value does not have the declared type:"
                                                " expected Int, found String">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"declared Int here">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"return type">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"3 : Int">>)).

%% report §11.2: a later input may declare a member of a type the session
%% declares, and an operator finds it; a type declared again starts with no
%% members. Written with the change, and it does not cover an abstract type,
%% whose constructor stays its own input's (§4.4)
later_member_test_() ->
    {timeout, 60, fun later_member/0}.

later_member() ->
    InputFile = scratch_file("ern_member_"),
    ok = file:write_file(InputFile, "type Coin = Coin(Int)\n"
                                    "fn Coin.+(Coin(a), Coin(b)) = Coin(a + b)\n"
                                    "Coin(1) + Coin(2)\n"
                                    "fn Coin.compare(Coin(a), Coin(b)) = Int.compare(a, b)\n"
                                    "Coin(1) < Coin(2)\n"
                                    "Coin.compare(Coin(3), Coin(2))\n"
                                    "type Coin = Coin(Float)\n"
                                    "Coin(1.0) + Coin(2.0)\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"Coin(3) : Coin">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"true : Bool">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Greater : Ordering">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"`+` is not defined on Coin">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"not a type declared">>)).

%% report §11.2, §7.4: the terminal is the shell's, so an input that reads a
%% line faults with the cause §7.4 gives and the shell goes on. A
%% regression test: in line mode the input took the shell's next line, and
%% at a terminal it ended the program, shell and all
input_reads_line_test_() ->
    {timeout, 60, fun input_reads_line/0}.

input_reads_line() ->
    InputFile = scratch_file("ern_read_"),
    ok = file:write_file(InputFile, "Io.readLine()\n1 + 1\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"the shell holds the terminal; run the program with"
                                                " ern run to give it the keyboard">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"Some(\"1 + 1\")">>)),
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
    InputFile = scratch_file("ern_reply_"),
    Take = "receive { Get(reply = r) -> Get(reply = r) | Stop -> Stop | after 0 -> Stop }",
    ok = file:write_file(InputFile, ["type Req = Get(reply : Reply(Int)) | Stop\n",
                                     Take, "\n",
                                     "let x = ", Take, "\n",
                                     "1 + 1\n"]),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    Refused = binary:matches(Output, <<"an input's value cannot carry a reply">>),
    ?assertEqual(2, length(Refused)),
    ?assertEqual(nomatch, binary:match(Output, <<"Stop : Req">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)).

%% report §11.2, §5.4: a `let` at the prompt is a block `let`, so its
%% pattern binds each name it holds, in the order written, `let _ = e`
%% binds none, a refutable pattern is refused as in a block, and `<-` is
%% refused, having no block to end. A regression test: the prompt took a
%% name alone, as a top-level `let` does
pattern_let_test_() ->
    {timeout, 60, fun pattern_let/0}.

pattern_let() ->
    InputFile = scratch_file("ern_plet_"),
    ok = file:write_file(InputFile, "let #(a, b) = #(1, \"two\")\n"
                                    "a + 1\n"
                                    "type P = P(name : String, age : Int)\n"
                                    "let P(name = n, age = g) as p = P(name = \"Ada\", age = 36)\n"
                                    "g\n"
                                    "let _ = 5\n"
                                    "let Some(y) = Some(1)\n"
                                    "let x <- Some(1)\n"
                                    "let #(e, f) = #([], [])\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> a : Int\nb : String\n> 2 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"n : String\ng : Int\np : P\n> 36 : Int\n">>)),
    %% `let _ = 5` prints nothing and binds nothing
    ?assertMatch({_, _}, binary:match(Output, <<"36 : Int\n> > ">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"a `let` pattern must be irrefutable">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"a `let` with `<-` at the prompt has no block">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"the types of e, f are not determined">>)).

%% report §11.2, §3.9, §4.6, §8.6: a `let` at the prompt is a block `let`, so
%% a lambda it binds is generalized, its effect variable with it, and runs,
%% and a timed receive is no deadlock in line mode, first input or not. A
%% declared name prints its own scheme after inputs whose type state numbers
%% other variables alike. A regression test for three defects: the effect
%% variable entered the session unbound and crashed the next input's check,
%% the first input's timed wait was a deadlock, and the scheme printed
%% through the later input's substitution
effect_variable_test_() ->
    {timeout, 60, fun effect_variable/0}.

effect_variable() ->
    InputFile = scratch_file("ern_eff_"),
    ok = file:write_file(InputFile, "receive { after 300 -> 5 }\n"
                                    "let h = fn() = Io.println(\"x\")\n"
                                    "h()\n"
                                    "let f = fn(x : Int) = x + 1\n"
                                    "f(2)\n"
                                    "fn g() : Int with e = receive { after 5 -> 5 }\n"
                                    ":type g\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 5 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> h : () -> Unit with e+\n> x\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> f : (Int) -> Int\n> 3 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> g : () -> Int with e+\n"
                                                "> g : () -> Int with e+\n">>)).

%% report §4.6, §11.2: a lambda bound by `let` at the prompt is generalized
%% as in a block, its restrictions with it, and another value bound by `let`
%% is not, so an open variable in its type is refused. A regression test of
%% the rule of 2026-10-01: the shell refused the lambda as undetermined
lambda_let_test_() ->
    {timeout, 60, fun lambda_let/0}.

lambda_let() ->
    InputFile = scratch_file("ern_lam_"),
    ok = file:write_file(InputFile, "let id = fn(x) = x\n"
                                    "#(id(1), id(\"a\"))\n"
                                    "let same = fn(a, b) = a == b\n"
                                    "same(1, 1)\n"
                                    "same(fn() = 1, fn() = 2)\n"
                                    "let xs = []\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    [?assertMatch({_, _}, binary:match(Output, Text))
     || Text <- [<<"> id : (a) -> a\n> #(1, \"a\") : #(Int, String)\n">>,
                 <<"> same : (a=, a=) -> Bool\n> true : Bool\n">>,
                 <<"does not support equality">>,
                 <<"the type of xs is not determined by this input; it is List(a)">>]].

%% report §11.2: a file without an entry point is loaded by the shell and
%% nothing is spawned, so a library module is put in scope to be tried. A
%% regression test: the shell refused a module without `main`
library_file_test_() ->
    {timeout, 60, fun library_file/0}.

library_file() ->
    Dir = scratch("ern_lib_"),
    ok = file:write_file(filename:join(Dir, "twice.ern"), "export fn of(n : Int) : Int = 2 * n\n"),
    ok = file:write_file(filename:join(Dir, "in"), "Twice.of(21)\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " --build-root " ++ Dir ++ " "
                ++ filename:join(Dir, "twice.ern")),
    {0, Output} = sh("HOME=" ++ Dir ++ " ../bin/ern shell " ++ filename:join(Dir, "twice.erc")
                     ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Output, <<"42 : Int">>)).

%% report §11.2, Appendix E.23: in the shell Os.arguments is the empty list,
%% and Os.exit faults the input that calls it and ends neither the input
%% after it nor the shell; its environment is the host's. A regression
%% test, written after the code.
shell_os_test_() ->
    {timeout, 60, fun shell_os/0}.

shell_os() ->
    Dir = scratch("ern_os_"),
    ok = file:write_file(filename:join(Dir, "in"),
                         "Os.arguments\nOs.exit(2)\nOs.environment(\"ERN_SEEN\")\n"),
    {0, Output} = sh("HOME=" ++ Dir ++ " ERN_SEEN=yes ../bin/ern shell < "
                     ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Output, <<"[] : List(String)">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"fault: exited with status 2">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Some(\"yes\") : Optional(String)">>)).

%% report §11.2, §8.1: a `main` that is not an entry point leaves the file
%% without one, so it is loaded and nothing is spawned; `--main` naming it
%% is refused. Written with the change: the shell spawned any exported
%% `main` that takes no arguments. A `let main` is not covered here, as
%% ern_cli_tests covers its refusal.
non_entry_main_test_() ->
    {timeout, 60, fun non_entry_main/0}.

non_entry_main() ->
    Dir = scratch("ern_main_"),
    ok = file:write_file(filename:join(Dir, "main.ern"),
                         "export fn main() : Int with m = { Io.println(\"spawned\"); 3 }\n"),
    ok = file:write_file(filename:join(Dir, "in"), "1 + 1\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " --build-root " ++ Dir ++ " "
                ++ filename:join(Dir, "main.ern")),
    Erc = filename:join(Dir, "main.erc"),
    {0, Output} = sh("HOME=" ++ Dir ++ " ../bin/ern shell " ++ Erc
                     ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"spawned">>)),
    {1, Refused} = sh("HOME=" ++ Dir ++ " ../bin/ern shell --main Main.main " ++ Erc
                      ++ " < " ++ filename:join(Dir, "in")),
    ?assertMatch({_, _}, binary:match(Refused, <<"Main.main is not an entry point: its type is"
                                                 " () -> Int with m+">>)).

%% report §11.2: a holder of what an input bound is freed once nothing
%% reads it, and kept while a declared function reads it; the names it
%% held go on meaning what they meant. A regression test for the holders
%% of `it`, which the session kept for ever; the memory it saves is
%% measured by hand (the log's *The Closing of Step 10*), not here
holders_freed_test_() ->
    {timeout, 60, fun holders_freed/0}.

holders_freed() ->
    InputFile = scratch_file("ern_holders_"),
    ok = file:write_file(InputFile, ["40 + 2\n", "fn f() : Int = it + 1\n", "let x = 7\n",
                                     [[integer_to_list(Index), "\n"] || Index <- lists:seq(1, 30)],
                                     "f()\n", "x\n", "it\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 43 : Int\n> 7 : Int\n> 7 : Int">>)).

%% report §11.2, §7.4: a further reload of a module ends the processes of
%% its previous version, which the reload names, and each one's fault,
%% `its code was unloaded`, is reported as every fault is. A regression test
%% for the move to Process.faults, which quiets no process `:reload` ends.
%% The release review found the purge made before the process had taken
%% its end, which kills it `Killed`; the reload now waits, and this test
%% does not force that race
reload_ends_test_() ->
    {timeout, 60, fun reload_ends/0}.

reload_ends() ->
    Dir = scratch("ern_reload_ends_"),
    Counter = fun(Start) ->
                  ["export type Msg = Get(reply : Reply(Int))\n",
                   "fn serve(n : Int) : Unit with Msg =\n",
                   "    receive { Get(reply = r) -> { answer(r, n); serve(n) } }\n",
                   "export let service : Address(Msg) =\n",
                   "    spawn(fn() : Unit with Msg = serve(", integer_to_list(Start), "))\n"]
              end,
    ok = file:write_file(filename:join(Dir, "counter.ern"), Counter(1)),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Counter\n",
                                     write_source(Dir, "counter.ern", Counter(2)), ":reload\n",
                                     write_source(Dir, "counter.ern", Counter(3)), ":reload\n",
                                     "1 + 1\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"Counter: ended Counter.service:5, a process in the"
                                                " previous version">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"Counter.service:5 faulted: its code was unloaded">>)).

%% report §11.2: the commands the report's paragraph lists are the shell's
%% own list, `Shell.Command.commands`, each once; a mirror, a list that lives
%% in the code and in the report (CLAUDE.md)
commands_mirror_test() ->
    {ok, Report} = file:read_file("../report/toolchain.md"),
    [_, Rest] = binary:split(Report, <<"**Commands.**">>),
    [Paragraph | _] = binary:split(Rest, <<"\n\n**">>),
    {match, Listed} = re:run(Paragraph, "^- `:([a-z]+)", [multiline, global,
                                                         {capture, all_but_first, binary}]),
    {ok, Source} = file:read_file("../shell/shell/command.ern"),
    [_, AfterList] = binary:split(Source, <<"export let commands =">>),
    [List | _] = binary:split(AfterList, <<")]\n">>),
    {match, Named} = re:run(List, "Command\\(name = \"([a-z]+)\"",
                            [global, {capture, all_but_first, binary}]),
    ?assertEqual(lists:sort(lists:append(Named)), lists:sort(lists:append(Listed))).

%% report §11.2, Appendix E.21: the shell is a subscriber of Process.faults.
%% An input a signal ends with a fault answers with it rather than waiting
%% for a `Done` that never comes; a restart is reported as one, and the
%% end after it; `:faults` keeps both; a binding `:load` evaluates is
%% reported by `:load` alone. A regression test for the move off the front
%% end's watcher; it does not cover a process `:reload` ends. The input
%% that spawns the restarting process waits for its end, so that `:faults`
%% comes after both faults: sent at once, it came first under the host's
%% modified timing
fault_subscriber_test_() ->
    {timeout, 60, fun fault_subscriber/0}.

fault_subscriber() ->
    Dir = scratch("ern_fault_subscriber_"),
    ok = file:write_file(filename:join(Dir, "bad.ern"),
                         "export let zero = List.size([])\nexport let boom = 1 / zero\n"),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ["send(via(self(), fn(x) = x / List.size([])), 1)\n",
                                     "1 + 1\n",
                                     "let r = restarting(RestartLimit(restarts = 1,"
                                     " within = 60000),"
                                     " fn() : Unit with Never = Io.println(Int.toString("
                                     "1 / List.size([]))))\n",
                                     "{ let _ = spawnMonitored(r, fn(d) = d);"
                                     " receive { d -> d } }\n",
                                     ":faults\n",
                                     ":load Bad\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> fault: division by zero\n> 2 : Int">>)),
    %% the process is spawned by the fourth input
    ?assertEqual(2, count(Output, <<"input 4:1 faulted, restarted: division by zero">>)),
    ?assertEqual(2, count(Output, <<"input 4:1 faulted: division by zero">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Bad.boom:2 faulted">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"Shell.load">>)).

%% report §11.2, §8.2: the shell shows each byte a program writes that is
%% not UTF-8 as U+FFFD, a character cut across two writes whole, and text
%% as UTF-8 whatever the host's locale
shown_bytes_test_() ->
    {timeout, 60, fun shown_bytes/0}.

shown_bytes() ->
    InputFile = scratch_file("ern_bytes_"),
    ok = file:write_file(InputFile, "Io.write(<<104, 255, 105, 10>>)\nIo.write(<<195>>)\n"
                         "Io.write(<<169, 10>>)\nIo.println(\"h\\u{e9}\")\n"),
    {0, Output} = sh("LANG=C ../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"h", 16#fffd/utf8, "i\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> ", 16#e9/utf8, "\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"h", 16#e9/utf8, "\n">>)).

%% report §9, §11.2: `:doc` finds a prelude name's documentation, a
%% function, a type, and a value, and still finds an operation
%% in its type's module. A regression test: the prelude had none, and `:doc
%% monitor` said "no documentation"
prelude_doc_test_() ->
    {timeout, 60, fun prelude_doc/0}.

prelude_doc() ->
    InputFile = scratch_file("ern_pdoc_"),
    ok = file:write_file(InputFile, ":doc monitor\n:doc Down\n:doc restarting\n:doc Int.compare\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> monitor\n\n    monitor : ">>)),
    ?assertMatch({_, _},
                 binary:match(Output, <<"type Down = Down(process : Process, reason : Reason">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> restarting\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Int.compare\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"no documentation">>)).

%% report §11.2, §11.5: an input that is one name has its type printed as
%% the declaration writes it, under the declaration's variable names, asked
%% for with `:type` or evaluated; any other expression prints its own type.
%% A regression test: `:type Io.readLine` printed `with e` where `:browse Io`
%% printed `with m`
one_name_type_test_() ->
    {timeout, 60, fun one_name_type/0}.

one_name_type() ->
    InputFile = scratch_file("ern_name_"),
    ok = file:write_file(InputFile, ":type Io.readLine\n:type spawn\nIo.readLine\n"
                                    ":type List.map([1], fn(x) = x)\n"),
    {0, Output} = sh("../bin/ern shell < " ++ InputFile),
    ?assertMatch({_, _},
                 binary:match(Output, <<"Io.readLine : () -> Optional(String) with m+\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"spawn : (() -> Unit with n) -> Address(n)"
                                                " with m+\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"<function> : () -> Optional(String) with m+\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"List.map([1], fn(x) = x) : List(Int)\n">>)).

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
    SourceRoot = scratch("ern_docroot_"),
    ok = file:write_file(filename:join(SourceRoot, "m.ern"),
                         "/// A little module.\n///\n/// since 0.1.0\n\n"
                         "/// A colour.\nexport type Colour = Red | Green\n"),
    ok = filelib:ensure_path(filename:join(SourceRoot, "net")),
    ok = file:write_file(filename:join([SourceRoot, "net", "http.ern"]),
                         "export fn get() : Int = 1\n"),
    InputFile = filename:join(SourceRoot, "session.in"),
    ok = file:write_file(InputFile, ["let zeta = 1\n", "fn sz() : Int = 1\n",
                                     "type Tree = Leaf | Node(left : Tree, right : Tree)\n",
                                     ":doc zeta\n", ":doc sz\n", ":doc Leaf\n",
                                     ":doc Tcp.ListenerMsg\n",
                                     ":doc Some\n", ":doc Fs\n", ":load M\n", ":doc M.Red\n",
                                     ":doc M\n", ":load Net.Http\n", ":doc Net\n", ":doc List\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ SourceRoot) ++ " < " ++ InputFile),
    ?assertEqual(nomatch, binary:match(Output, <<"no documentation">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"Input">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> zeta\n\n    zeta : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> sz\n\n    sz : () -> Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Tree\n\n    type Tree = Leaf">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Tcp.ListenerMsg\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Optional\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Ernest module Fs\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> M.Colour\n\n    type Colour = Red | Green"
                                                "\n\nA colour.">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> Ernest module M\n\n*Since 0.1.0.*\n\n"
                                                "A little module.">>)),
    %% a namespace lists what it holds, and a type that is a module too
    %% shows both
    ?assertMatch({_, _}, binary:match(Output, <<"> namespace Net\n\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"`Net.Http.get : () -> Int`">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"    type List(a)">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"\nErnest module List\n">>)).

%% report §11.2, §6.9: a spawn site in the session is written as the
%% session writes names, `input 5:1` in an input's own expression and
%% `start:1` in a function an input declares, and the input's own wrapper
%% shadows no name the session declares. A regression test for findings
%% of the session of real use: `:processes` showed `Input2.main:1`, a name
%% the session shows only for a shadowed type, and `main()` after `fn main` called the
%% wrapper, which was named `main`, forever
session_names_test_() ->
    {timeout, 60, fun session_names/0}.

session_names() ->
    InputFile = scratch_file("ern_names_"),
    Wait = "receive { n -> Io.println(Int.toString(n)) }",
    ok = file:write_file(InputFile, ["fn main() : Int = 1\n", "main()\n",
                                     "fn start() : Address(Int) with m = spawn(fn() = ", Wait,
                                     ")\n", "start()\n", "spawn(fn() = ", Wait, ")\n",
                                     ":processes\n"]),
    {0, Output} = sh(alone("../bin/ern shell") ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 1 : Int\n">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"input 5:1\nstart:1\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"Input">>)).

%% report §11.2: text that is typed and not run makes no name the host
%% keeps: a `Tab`, a `Shift-Tab`, and a command given a name of nothing make
%% none, and answer as for any name of nothing. A regression test: each
%% made a name of every word, which the host keeps for ever (findings.md's
%% C3-30). Written after the code; an input that is run makes its names, as
%% it must
typing_makes_no_names_test_() ->
    {timeout, 60, fun typing_makes_no_names/0}.

%% In a host of its own, since the count of names is the host's, and other
%% tests make names beside this one.
typing_makes_no_names() ->
    Paths = [filename:absname(Path)
             || Path <- filelib:wildcard("../erl/*/ebin") ++ ["../build/stdlib"]],
    Script = filename:join(fresh_home(), "names.escript"),
    ok = file:write_file(
           Script,
           ["#!/usr/bin/env escript\n"
            "main(_) ->\n"
            "    code:add_pathsa(", io_lib:format("~p", [Paths]), "),\n"
            "    Typed = fun(Word) ->\n"
            "        [ern_shell:slot(<<Word/binary, \"a(\", Word/binary, \"b, \">>),\n"
            "         ern_shell:slot(<<\"Zqx\", Word/binary, \"C.Zqx\", Word/binary, \"D(\">>),\n"
            "         ern_shell:signature(<<\"Zqx\", Word/binary, \"E.\", Word/binary,"
            " \"f(1, \">>),\n"
            "         ern_shell:documentation(<<\"Zqx\", Word/binary, \"G.\", Word/binary,"
            " \"h\">>)]\n"
            "    end,\n"
            %% once for what reading loads, and again with other names
            "    Typed(<<\"zqxFirst\">>),\n"
            "    Before = erlang:system_info(atom_count),\n"
            "    Answers = Typed(<<\"zqxSecond\">>),\n"
            "    io:format(\"~p ~p\", [erlang:system_info(atom_count) - Before, Answers]).\n"]),
    {0, Output} = sh("escript " ++ Script),
    ?assertEqual(<<"0 ['Expression','Expression','None','None']">>, Output).

%% report §11.2: `:output` takes a terminal or a file, and a path that
%% names neither is refused, the session going on. A regression test: a
%% pipe with no reader held the session where it was opened (findings.md's
%% C3-31); a command given a name of no module answers as before
output_to_a_pipe_test_() ->
    {timeout, 60, fun output_to_a_pipe/0}.

output_to_a_pipe() ->
    Home = fresh_home(),
    Pipe = filename:join(Home, "pipe"),
    {0, _} = sh("mkfifo " ++ Pipe),
    InputFile = filename:join(Home, "session.in"),
    ok = file:write_file(InputFile, [":output ", Pipe, "\n:output ", Home, "\n",
                                     ":browse Zqxunmet\n:load Zqxunmet\n1 + 1\n"]),
    {0, Output} = sh("HOME=" ++ Home ++ " ../bin/ern shell < " ++ InputFile),
    Refusal = fun(Path) -> list_to_binary(["cannot write to ", Path,
                                           ": it is no terminal and no file"]) end,
    ?assertMatch({_, _}, binary:match(Output, Refusal(Pipe))),
    ?assertMatch({_, _}, binary:match(Output, Refusal(Home))),
    ?assertMatch({_, _}, binary:match(Output, <<"no module Zqxunmet is in scope">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"no module Zqxunmet under the source root or on"
                                                " the load path">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)).

%% The tests that call the front end in this host, which keeps one session
%% for all of it: they run one after the other, where the module's tests
%% run side by side.
front_end_test_() ->
    {inorder, [{"signature", fun signature/0},
               {"fields by module", fun fields_by_module/0},
               {"browse an effect parameter", fun browse_effect_parameter/0},
               {"not a name", fun not_a_name/0},
               {"load words segment", fun load_words_segment/0}]}.

%% report §11.2, Appendix E.0 rule 6: `Shift-Tab`'s two answers from the
%% front end. Inside a call, the callee's signature with its parameters as
%% declared, in three parts around the one at the cursor, which the shell
%% colours; the prelude's too, without
%% names it does not declare; nothing outside a call. On a name, its page
%% with the version it appeared in, its own or its module's
signature() ->
    ?assertEqual({'Some', {<<"List.map(list : List(a), ">>, <<"f : (a) -> b with e">>,
                           <<") : List(b) with e">>}},
                 ern_shell:signature(<<"List.map([1], ">>)),
    ?assertEqual({'Some', {<<"send(Address(a), ">>, <<"a">>, <<") -> Unit with m+">>}},
                 ern_shell:signature(<<"send(a, ">>)),
    ?assertEqual('None', ern_shell:signature(<<"1 + ">>)),
    %% a callee that is no function has no signature; a regression test,
    %% where a system reference's showed its type glued to its name
    ?assertEqual('None', ern_shell:signature(<<"Map.empty(">>)),
    {'Some', MapPage} = ern_shell:documentation(<<"List.map">>),
    ?assertMatch({_, _}, binary:match(MapPage, <<"*Since 0.1.0.*">>)),
    {'Some', SendPage} = ern_shell:documentation(<<"send">>),
    ?assertMatch({_, _}, binary:match(SendPage, <<"*Since 0.1.0.*">>)).

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
    Lines = [Line || Line <- binary:split(Screen, <<"\n">>, [global]), Line =/= <<>>],
    Answers = [Line || Line <- Lines, Line =:= <<"1 : Int">> orelse Line =:= <<"4 : Int">>],
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
    Dir = scratch("ern_reload_"),
    ok = file:write_file(filename:join(Dir, "demo.ern"), demo(1)),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Demo\n",
                                     "Demo.answer()\n",
                                     "let g = Demo.answer\n",
                                     "spawn(fn() = Demo.tick())\n",
                                     write_demo(Dir, 2),
                                     ":reload\n",
                                     "Demo.answer()\n",
                                     "g()\n",
                                     write_demo(Dir, 3),
                                     ":reload\n",
                                     "Demo.answer()\n",
                                     ":processes\n"]),
    {0, Output} = sh("../bin/ern shell --source-root " ++ Dir ++ " --load-path " ++ Dir
                     ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"Demo, compiled from demo.ern">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"1 : Int">>)),
    %% the first reload names what is still in the version it replaced
    ?assertMatch({_, _}, binary:match(Output, <<"input 4:1, a process, g, a binding in the previous"
                                                " version; a further reload of it ends them">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int">>)),
    %% a binding holding a function of the module keeps the version it was
    %% taken from, a regression test for a finding of the shell's review,
    %% where it ran the new code: the new answer, then the old one
    ?assertMatch({_, _}, binary:match(Output, <<"2 : Int\n> 1 : Int">>)),
    %% the second ends it, and says so
    ?assertMatch({_, _}, binary:match(Output, <<"ended ">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"no process of the session's is running">>)).

demo(Value) ->
    ["export fn answer() : Int = ", integer_to_list(Value), "\n\n",
     "export fn tick() : Unit with Unit = {\n",
     "    Clock.alarm(50, fn(_) = Unit);\n",
     "    receive { _ -> Unit };\n",
     "    tick()\n",
     "}\n"].

write_demo(Dir, Value) ->
    write_source(Dir, "demo.ern", demo(Value)).

%% An input that writes a module's source, so that the session is what
%% changes it (E.17).
write_source(Dir, File, Source) ->
    Text = lists:flatten(Source),
    Escaped = lists:flatten([case Char of $\n -> "\\n"; $" -> "\\\""; _ -> Char end
                             || Char <- Text]),
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
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Alpha\n", ":load Beta\n",
                                     write_source(Dir, "alpha.ern", answer(2)),
                                     write_source(Dir, "beta.ern",
                                                  "export fn answer() : Int = \"no\"\n"),
                                     ":reload\n",
                                     "Alpha.answer() + 10\n",
                                     write_source(Dir, "beta.ern", answer(3)),
                                     ":reload\n",
                                     "Alpha.answer() + 20\n",
                                     "Beta.answer() + 30\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"beta.ern:1:">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"nothing was reloaded">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 11 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Alpha, compiled again">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Beta, compiled again">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 22 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 33 : Int">>)).

answer(Value) ->
    ["export fn answer() : Int = ", integer_to_list(Value), "\n"].

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
                   "fn serve(n : Int) : Unit with Msg =\n",
                   "    receive { Get(reply = r) -> { answer(r, n); serve(n) } }\n",
                   "export let service : Address(Msg) =\n",
                   "    spawn(fn() : Unit with Msg = serve(", integer_to_list(Start), "))\n",
                   "export let base = ", integer_to_list(Start), " * 10\n"]
              end,
    Ask = "Address.callForever(Counter.service, fn(r) = Counter.Get(reply = r))\n",
    ok = file:write_file(filename:join(Dir, "counter.ern"), Counter(1)),
    ok = file:write_file(filename:join(Dir, "bad.ern"),
                         "export let zero = List.size([])\nexport let boom = 1 / zero\n"),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Counter\n",
                                     "Counter.base\n",
                                     Ask,
                                     ":load Bad\n",
                                     "Bad.zero\n",
                                     write_source(Dir, "counter.ern", Counter(2)),
                                     ":reload\n",
                                     "Counter.base\n",
                                     Ask,
                                     write_source(Dir, "counter.ern",
                                                  [Counter(3),
                                                   "export let late = 1 / List.size([])\n"]),
                                     ":reload\n",
                                     "Counter.base\n",
                                     "Counter.late\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 10 : Int\n> 1 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"Bad.boom:2 faulted: division by zero;"
                                                " nothing was loaded">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"unknown name Bad.zero">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 20 : Int\n> 2 : Int">>)),
    %% the bindings before the one that faults take the new version's values
    ?assertMatch({match, _}, re:run(Output, "Counter.late:[0-9]+ faulted: division by zero; it and"
                                            " the bindings after it keep")),
    ?assertMatch({_, _}, binary:match(Output, <<"> 30 : Int">>)),
    %% one the previous version did not have has no value
    ?assertMatch({_, _}, binary:match(Output, <<"the binding has no value, since one before it"
                                                " faulted">>)).

%% A directory of its own under /tmp, for a test's sources or a home. The
%% operating system's pid as well as the counter: the counter starts again
%% in every run, so a name made by it alone could be one an earlier run
%% left, and a session would read what it holds, a history, as its own.
scratch(Prefix) ->
    Dir = scratch_name(Prefix),
    ok = filelib:ensure_path(Dir),
    Dir.

%% The integers a session answered with, `> n : Int`, each of at least
%% Digits digits, in the order it answered them.
answers(Output, Digits) ->
    Pattern = "^> ([0-9]{" ++ integer_to_list(Digits) ++ ",}) : Int$",
    [binary_to_integer(Number)
     || Line <- binary:split(Output, <<"\n">>, [global]),
        {match, [Number]} <- [re:run(Line, Pattern, [{capture, all_but_first, binary}])]].

%% A file of its own under /tmp, for a session's inputs.
scratch_file(Prefix) ->
    scratch_name(Prefix) ++ ".in".

scratch_name(Prefix) ->
    filename:join("/tmp", Prefix ++ os:getpid() ++ "_"
                  ++ integer_to_list(erlang:unique_integer([positive]))).

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
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load Demo\n", "spawn(fn() = Demo.tick())\n",
                                     ":load Demo\n", ":load Demo\n", ":processes\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertEqual(2, count(Output, <<"Demo is loaded already; :reload compiles it again">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"input 2:1\n">>)),
    ?assertEqual(nomatch, binary:match(Output, <<"no process of the session's is running">>)).

%% report §8.5, §11.2: `:reload` evaluates the changed modules' bindings in
%% dependency order. A regression test: it took them in the order of their
%% names, so a module read the value its dependency's previous version gave.
%% B is compiled on the load path, since a module `:load` loaded cannot yet
%% be another's dependency (findings T12, MVP 2.98)
reload_in_dependency_order_test_() ->
    {timeout, 60, fun reload_in_dependency_order/0}.

reload_in_dependency_order() ->
    Dir = scratch("ern_reload_order_"),
    ModuleA = fun(Value) -> ["export let y : Int = B.x + ", integer_to_list(Value), "\n"] end,
    ModuleB = fun(Value) -> ["export let x : Int = ", integer_to_list(Value), "\n"] end,
    ok = file:write_file(filename:join(Dir, "a.ern"), ModuleA(100)),
    ok = file:write_file(filename:join(Dir, "b.ern"), ModuleB(1)),
    {0, _} = sh("../bin/ern build " ++ Dir),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load A\n", "A.y\n",
                                     write_source(Dir, "a.ern", ModuleA(200)),
                                     write_source(Dir, "b.ern", ModuleB(2)),
                                     ":reload\n", "A.y\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir ++ " --load-path " ++ Dir)
                     ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"101 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"202 : Int">>)).

%% report §11.2: a `:load` whose binding faults leaves nothing of the
%% module, the processes its bindings started among it. A regression test:
%% such a process ran on in the code that was not loaded
failed_load_leaves_nothing_test_() ->
    {timeout, 60, fun failed_load_leaves_nothing/0}.

failed_load_leaves_nothing() ->
    Dir = scratch("ern_failed_load_"),
    ok = file:write_file(filename:join(Dir, "bad.ern"),
                         ["let worker : Address(Unit) = spawn(fn() = loop())\n",
                          "fn loop() : Unit with Unit = receive { _ -> loop() }\n",
                          "export let late : Int = 1 / List.size([])\n"]),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ":load Bad\n:processes\n"),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"nothing was loaded">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"no process of the session's is running">>)).

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
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, ["fn f() : Int = 1\n", "let x = 2\n", ":load Input1\n",
                                     ":load Bindings2\n", "f() + x\n", "Input1.answer()\n",
                                     "Bindings2.answer()\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Dir) ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"> 3 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 7 : Int">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 8 : Int">>)).

%% report §11.2, §11.1: `:load` finds what the module uses as `ern build`
%% finds it, on every root of the load path. A regression test: the
%% compiler the shell calls read the dependencies' interfaces from the
%% first root alone, and did not look on the load path for a dependency
load_path_dependency_test_() ->
    {timeout, 60, fun load_path_dependency/0}.

load_path_dependency() ->
    Dir = scratch("ern_load_deps_"),
    Library = filename:join(Dir, "lib"),
    SourceRoot = filename:join(Dir, "src"),
    First = filename:join(Dir, "first"),
    Second = filename:join(Dir, "second"),
    [ok = filelib:ensure_path(Path) || Path <- [Library, SourceRoot, First]],
    ok = file:write_file(filename:join(Library, "dep.ern"), answer(5)),
    ok = file:write_file(filename:join(SourceRoot, "user.ern"),
                         "export fn twice() : Int = Dep.answer() * 2\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Library ++ " --build-root " ++ Second ++ " "
                ++ filename:join(Library, "dep.ern")),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load User\n", "User.twice()\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ SourceRoot
                           ++ " --load-path " ++ First ++ " --load-path " ++ Second)
                     ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"User, compiled from user.ern">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"> 10 : Int">>)).

%% report §11.2: `:load` refuses a compiled module as `ern run` does, one
%% compiled against another interface of a module it uses than the session
%% holds, and loads nothing. A regression test: `:load` took such a module
%% and it faulted where the two differed (findings.md's C3-9)
load_refuses_stale_compiled_test_() ->
    {timeout, 60, fun load_refuses_stale_compiled/0}.

load_refuses_stale_compiled() ->
    Dir = scratch("ern_load_stale_"),
    Library = filename:join(Dir, "lib"),
    Build = filename:join(Dir, "build"),
    Empty = filename:join(Dir, "empty"),
    [ok = filelib:ensure_path(Path) || Path <- [Library, Build, Empty]],
    ok = file:write_file(filename:join(Library, "dep.ern"), answer(5)),
    ok = file:write_file(filename:join(Library, "user.ern"),
                         "export fn twice() : Int = Dep.answer() * 2\n"),
    BuildPath = fun(Path) ->
                    {0, _} = sh("../bin/ern build --source-root " ++ Library ++ " --build-root "
                                ++ Build ++ " " ++ Path)
                end,
    BuildPath(Library),
    %% Dep's interface changes, and Dep alone is built again
    ok = file:write_file(filename:join(Library, "dep.ern"),
                         "export fn answer() : String = \"five\"\n"),
    BuildPath(filename:join(Library, "dep.ern")),
    InputFile = filename:join(Dir, "session.in"),
    ok = file:write_file(InputFile, [":load User\n", "User.twice()\n"]),
    {0, Output} = sh(alone("../bin/ern shell --source-root " ++ Empty ++ " --load-path " ++ Build)
                     ++ " < " ++ InputFile),
    ?assertMatch({_, _}, binary:match(Output, <<"User was compiled against another Dep; build User"
                                                " again">>)),
    ?assertMatch({_, _}, binary:match(Output, <<"unknown name User.twice">>)).

%% report §11.2: the fields completion offers inside a constructor are
%% those of the constructor written there, found as the checker finds it:
%% a qualified one in its module, in an expression and in a pattern alike.
%% A regression test: the fields were looked up by the constructor's bare
%% name, so a constructor another module also declares offered the fields
%% of whichever module came first
fields_by_module() ->
    Dir = scratch("ern_fields_"),
    ok = file:write_file(filename:join(Dir, "circles.ern"),
                         "export type Shape = Round(radius : Int)\n"),
    ok = file:write_file(filename:join(Dir, "discs.ern"),
                         "export type Shape = Round(diameter : Int, hole : Bool)\n"),
    Texts = fun({'Fields', Names}) -> [Text || {'Name', Text, _, _} <- Names];
               (Other) -> Other
            end,
    try
        with_loaded(Dir, [<<"Circles">>, <<"Discs">>]),
        ?assertEqual([<<"diameter">>, <<"hole">>], Texts(ern_shell:slot(<<"Discs.Round(">>))),
        ?assertEqual([<<"radius">>], Texts(ern_shell:slot(<<"Circles.Round(">>))),
        ?assertEqual([<<"diameter">>, <<"hole">>],
                     Texts(ern_shell:slot(<<"Discs.Round(hole = true, ">>))),
        ?assertEqual([<<"diameter">>, <<"hole">>],
                     Texts(ern_shell:slot(<<"match s { Discs.Round(">>))),
        ?assertEqual([<<"radius">>], Texts(ern_shell:slot(<<"match s { Circles.Round(">>))),
        %% an unqualified `Round` is neither module's, and has no fields
        ?assertEqual('Expression', ern_shell:slot(<<"Round(">>))
    after
        forget_session()
    end.

%% report §11.2, §3.9: `:browse` prints a type whose parameter is no value
%% position as the checker does, so a variable found only there is an
%% effect variable. A regression test: the shell printed under the
%% prelude's state alone, which knows no module's types, and the printer
%% named a variable `e` only after `with`, so it was `a`
browse_effect_parameter() ->
    Dir = scratch("ern_hooks_"),
    ok = file:write_file(filename:join(Dir, "hooks.ern"),
                         "export type H(e) = H(f : (Int) -> Unit with e)\n"
                         "export fn drop(h) = { let H(f = _) = h; Unit }\n"),
    try
        Session = with_loaded(Dir, [<<"Hooks">>]),
        {'Right', Lines} = ern_shell:browse(Session, <<"Hooks">>),
        %% report §11.5: the type as the session writes it
        ?assert(lists:member(<<"Hooks.drop : (Hooks.H(e)) -> Unit">>, Lines), Lines)
    after
        forget_session()
    end.

%% report §11.2, §4.2: what a command is given that is not a name is
%% refused as one, and the refusal names what was given; a name longer
%% than any the host can hold among them. A regression test: `:load .`
%% was refused as ` is not a module name`, naming nothing, and a long name
%% raised the host's limit on a name out of the front end
not_a_name() ->
    Long = list_to_binary(lists:duplicate(300, $a)),
    try
        ern_shell:loaded(#loaded{}),
        Session = ern_shell:start(),
        ?assertMatch({'Left', <<". is not a module name", _/binary>>},
                     ern_shell:load(Session, <<".">>)),
        ?assertMatch({'Left', <<". is not a module name", _/binary>>},
                     ern_shell:browse(Session, <<".">>)),
        ?assertMatch({'Left', _}, ern_shell:load(Session, <<"A", Long/binary>>)),
        ?assertMatch({'Left', _}, ern_shell:browse(Session, <<"A", Long/binary>>)),
        ?assertMatch({'Left', _}, ern_shell:forget(Session, Long)),
        ?assertMatch({'Left', _}, ern_shell:doc(Session, Long)),
        ?assertMatch({'Left', _}, ern_shell:doc(Session, <<".">>)),
        ?assertEqual('None', ern_shell:documentation(<<".">>)),
        ?assertEqual('None', ern_shell:documentation(Long)),
        ?assertEqual('None', ern_shell:documentation(<<"List.", Long/binary>>))
    after
        forget_session()
    end.

%% report §4.2, §11.2: `:load WordCount` finds `word_count.ern` under the
%% source root, a name that is not words beginning with a capital is
%% refused, and completion names the segment from the file
load_words_segment() ->
    Dir = scratch("ern_words_"),
    ok = file:write_file(filename:join(Dir, "word_count.ern"), "export fn size() : Int = 2\n"),
    try
        Session = with_loaded(Dir, [<<"WordCount">>]),
        ?assertMatch({'Left', <<"Word_Count is not a module name", _/binary>>},
                     ern_shell:load(Session, <<"Word_Count">>)),
        ?assertMatch({'Left', <<"wordCount is not a module name", _/binary>>},
                     ern_shell:load(Session, <<"wordCount">>)),
        ?assertEqual({'Some', <<"WordCount">>}, ern_shell:segment(<<"word_count">>))
    after
        forget_session()
    end.

%% A session begun with the modules of Dir loaded by `:load`, one after
%% the other, kept where completion reads it.
with_loaded(Dir, Modules) ->
    ern_shell:loaded(#loaded{source_root = Dir}),
    lists:foldl(fun(Module, Session) ->
                    {'Right', {Session1, _}} = ern_shell:load(Session, Module),
                    Session1
                end, ern_shell:start(), Modules).

%% The front end keeps the session where completion reads it; a test that
%% set it leaves none behind for the next.
forget_session() ->
    persistent_term:erase({ern_shell, loaded}),
    ets:whereis(ern_shell) =/= undefined andalso ets:delete(ern_shell),
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
                 [{expect, "HOME is no absolute path"},
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

%% A home of its own, which holds no history but the session's.
fresh_home() ->
    scratch("ern_home_").

hex(Text) ->
    lists:flatten([io_lib:format("~2.16.0b", [Char]) || Char <- Text]).

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
    {0, Output} = sh("./ern_pty.py --timeout " ++ integer_to_list(Seconds) ++ " --steps " ++ File
                     ++ Extra ++ " -- " ++ Command),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    %% a step the harness could not meet is a failure of the test, not a
    %% screen to assert against
    ?assertEqual([], [Line || <<"unmet ", _/binary>> = Line <- Lines]),
    [<<"data ", Data/binary>>] = [Line || <<"data ", _/binary>> = Line <- Lines],
    base64:decode(Data).

%% The steps go in a file: one holds whatever the program prints, and a
%% shell reading `>` would take it for a redirection.
steps_file(Steps) ->
    File = "build/steps-" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, [[step(Step), "\n"] || Step <- Steps]),
    File.

step({expect, Text}) -> "expect:" ++ Text;
step({send, Hex}) -> "send:" ++ Hex;
step({sleep, Ms}) -> "sleep:" ++ integer_to_list(Ms).

sh(Command) ->
    Shell = open_port({spawn, "sh -c '" ++ Command ++ "'"},
                      [exit_status, stderr_to_stdout, binary]),
    collect(Shell, []).

collect(Shell, Acc) ->
    receive
        {Shell, {data, Data}} -> collect(Shell, [Data | Acc]);
        {Shell, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.
