%% Report §8.2: the system modules, Terminal, Os, Fs and Tcp, in programs
%% run as the runner runs them (ern_emitter_tests:run/3).
-module(ern_system_module_tests).

-include_lib("eunit/include/eunit.hrl").

%%
%% Report §12.1: the terminal, read as lines or as keys.
%%

%% report §12.1: keys and lines are the same terminal, so the process that
%% claims it the other way faults, naming the side that holds it
terminal_is_lines_or_keys_test() ->
    {Result1, _} = ern_emitter_tests:run_at_terminal(
        "type Msg = Pressed(Terminal.Event)\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let _ = Io.readLine();\n"
        "    let _ = Terminal.subscribe(Pressed);\n"
        "    receive { Pressed(_) -> Unit }\n"
        "}\n"),
    ?assertMatch({fault, <<"the terminal is already read as lines">>, _}, Result1).

%% report §12.1, §7.4: a claim of the terminal the other way faults the
%% process that makes it, and the first claim stands: a worker that
%% subscribes after main read a line faults, and main reads on. A
%% regression test: the entry process faulted, whoever asked
terminal_claim_faults_its_caller_test() ->
    ?assertEqual({ok, <<"the terminal is already read as lines\nread on\n">>},
                 ern_emitter_tests:run_at_terminal(
                     "type Msg = Pressed(Terminal.Event)\n"
                     "type MainMsg = Ended(Down)\n"
                     "fn watch() : Unit receiving Msg = {\n"
                     "    let _ = Terminal.subscribe(Pressed);\n"
                     "    Unit\n"
                     "}\n"
                     "export fn main() : Unit receiving MainMsg = {\n"
                     "    let _ = Io.readLine();\n"
                     "    let _ = spawnMonitored(watch, Ended);\n"
                     "    receive {\n"
                     "        Ended(Down(reason = Fault(c), site = _)) ->\n"
                     "            Io.println(c)\n"
                     "      | Ended(_) -> Io.println(\"ended\")\n"
                     "    };\n"
                     "    let _ = Io.readLine();\n"
                     "    Io.println(\"read on\")\n"
                     "}\n")).

%%
%% Report Appendix E.23: Os.run, each program run through ern_exec.
%%

%% A program that prints what Os.run answered for one command.
os_run(Program, Arguments, Input, Ms) ->
    ern_emitter_tests:run(
        ["fn show(r : Either(Io.Error, Os.Finished)) : String = match r {\n"
         "    Right(f) -> Int.toString(f.status) <> \"|\" <> Io.show(String.fromUtf8(f.stdout))\n"
         "        <> \"|\" <> Io.show(String.fromUtf8(f.stderr))\n"
         "  | Left(e) -> Io.show(e)\n"
         "}\n"
         "export fn main() : Unit = Io.println(show(Os.run(Os.Command(program = ",
         Program, ", arguments = ", Arguments, ", input = ", Input,
         ", environment = [], workingDirectory = Os.workingDirectory), ", Ms, ")))\n"]).

%% Appendix E.23: the exit status, the output and the standard error, apart
os_run_status_and_streams_test() ->
    {ok, Output} = os_run("\"sh\"", "[\"-c\", \"echo out; echo err >&2; exit 2\"]", "<<>>", "5000"),
    ?assertEqual(<<"2|Some(\"out\\n\")|Some(\"err\\n\")\n">>, Output).

%% Appendix E.23: the program reads its input and then the end of it, so
%% one that reads to the end, as sort does, ends
os_run_input_then_end_test() ->
    {ok, Output} = os_run("\"sort\"", "[]", "String.toUtf8(\"b\\na\\n\")", "5000"),
    ?assertEqual(<<"0|Some(\"a\\nb\\n\")|Some(\"\")\n">>, Output).

%% Appendix E.23: each argument reaches the program as it is, no shell
%% between, so a space or a `;` is part of the argument
os_run_arguments_as_they_are_test() ->
    {ok, Output} = os_run("\"printf\"", "[\"%s|\", \"a b\", \"c;d\", \"$HOME\"]", "<<>>", "5000"),
    ?assertEqual(<<"0|Some(\"a b|c;d|$HOME|\")|Some(\"\")\n">>, Output).

%% Appendix E.23: a program a signal ended has 128 and the signal's number
os_run_signal_status_test() ->
    {ok, Output} = os_run("\"sh\"", "[\"-c\", \"kill -TERM $$\"]", "<<>>", "5000"),
    ?assertEqual(<<"143|Some(\"\")|Some(\"\")\n">>, Output).

%% Appendix E.23: NotFound for a program not found, an empty name among
%% them, Denied for one that may not be run, and Invalid for an argument no
%% program could be given. A regression test of the empty name, which
%% faulted as the helper's failure
os_run_refusals_test() ->
    ?assertEqual({ok, <<"Io.NotFound\n">>},
                 os_run("\"no-such-program-ern\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Io.NotFound\n">>}, os_run("\"\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Io.Denied\n">>}, os_run("\"/dev/null\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Io.Invalid\n">>},
                 os_run("\"echo\"", "[\"a\\u{0}b\"]", "<<>>", "5000")).

%% Appendix E.23: Timeout when the time runs out first, and the program,
%% still running, killed, so the mark it would leave is never made. An
%% absence: the program, started before the run's time ran out, would
%% have left its mark within its own second, so the test waits that second
%% from the run's return
os_run_timeout_kills_test() ->
    Mark = filename:join(ern_emitter_tests:scratch(), "mark"),
    {ok, Output} = os_run("\"sh\"", "[\"-c\", \"sleep 1; touch " ++ Mark ++ "\"]", "<<>>", "200"),
    ?assertEqual(<<"Io.Timeout\n">>, Output),
    timer:sleep(1000),
    Marked = filelib:is_file(Mark),
    ok = file:del_dir_r(filename:dirname(Mark)),
    ?assertNot(Marked).

%% Appendix E.23: a program whose caller dies is killed with it. The caller
%% says once the program has started; an absence then: the program would
%% have left its mark within its own second, which began before it was
%% killed, so the test waits that second from the end of the run
os_run_dies_with_its_caller_test() ->
    Mark = filename:join(ern_emitter_tests:scratch(), "mark"),
    {ok, _} = ern_emitter_tests:run(
        "type Msg = Started\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let me = self();\n"
        "    let w = spawn(fn() = match Os.start(Os.Command(program = \"sh\",\n"
        "        arguments = [\"-c\", \"sleep 1; touch " ++ Mark ++ "\"], input = <<>>,\n"
        "        environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "        Right(p) -> { send(me, Started); let _ = Os.read(p, 5000); Unit }\n"
        "      | Left(_) -> Unit\n"
        "    });\n"
        "    receive { Started -> Unit };\n"
        "    kill(Process.fromAddress(w))\n"
        "}\n"),
    timer:sleep(1000),
    Marked = filelib:is_file(Mark),
    ok = file:del_dir_r(filename:dirname(Mark)),
    ?assertNot(Marked).

%% Appendix E.23: run kills the program's process once it has read the exit
%% status, so that it leaves no process behind: what the caller owns after
%% it, if anything, is the process the kill is still ending. A regression
%% test: before the rule, the process lived on after its exit; a run that
%% times out kills it as before, which os_run_timeout_kills_test reads of
%% the program
os_run_leaves_no_process_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Ended(Down)\n"
        "fn ended(left : List(Process)) : Unit receiving Msg = match left {\n"
        "    [] -> Unit\n"
        "  | _ :: rest -> receive { Ended(_) -> ended(rest) }\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let command = Os.Command(program = \"true\", arguments = [], input = <<>>,\n"
        "        environment = [], workingDirectory = Os.workingDirectory);\n"
        "    let ran = Os.run(command, 5000);\n"
        "    let left = Process.owned(Process.current());\n"
        "    List.forEach(left, fn(p) = monitor(p, Ended));\n"
        "    ended(left);\n"
        "    let ownsNothing = List.isEmpty(Process.owned(Process.current()));\n"
        "    Io.println(Io.show(#(Either.isRight(ran), ownsNothing)))\n"
        "}\n"),
    ?assertEqual(<<"#(true, true)\n">>, Output).

%% report §8.6, Appendix E.23: a program running is a source, so a caller
%% that only waits for it is in no deadlock
os_run_is_a_source_test() ->
    ?assertEqual({ok, <<"0|Some(\"\")|Some(\"\")\n">>},
                 os_run("\"sleep\"", "[\"0.5\"]", "<<>>", "5000")).

%% A shell command's exit status and its output, standard error with it.
%% Whether the host's process Pid has ended within Ms, which bounds a
%% failure. Nothing tells this process of another program's end, so the
%% host is asked again at once each time, each ask a program of its own.
gone(Pid, Ms) ->
    asked(Pid, erlang:monotonic_time(millisecond) + Ms).

asked(Pid, Deadline) ->
    case sh("kill -0 " ++ Pid) of
        {0, _} ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true -> asked(Pid, Deadline);
                false -> alive
            end;
        _ ->
            gone
    end.

sh(Cmd) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    sh_collect(Port, []).

sh_collect(Port, Acc) ->
    receive
        {Port, {data, Data}} -> sh_collect(Port, [Data | Acc]);
        {Port, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.

%%
%% Report Appendix E.23: a running program is a process, Os.start's
%% address, read and fed piece by piece. Regression tests, written after
%% the code; the host's output order within one stream is its own, and a
%% name the host gives twice in the environment is not covered here.
%%

%% What a program wrote, a line a piece, until its exit status or why not.
drain() ->
    "fn text(b : Bytes) : String = Optional.withDefault(String.fromUtf8(b), \"?\")\n"
    "fn drain(p : Address(Os.ProgramMsg)) : Unit = match Os.read(p, 5000) {\n"
    "    Right(Os.Stdout(b)) -> { Io.print(\"out \" <> text(b)); drain(p) }\n"
    "  | Right(Os.Stderr(b)) -> { Io.print(\"err \" <> text(b)); drain(p) }\n"
    "  | Right(Os.Exited(s)) -> Io.println(\"exit \" <> Int.toString(s))\n"
    "  | Left(e) -> Io.println(Io.show(e))\n"
    "}\n".

%% Appendix E.23: each read answers the next piece from either stream, in
%% the order the host delivered them, and last the exit status
os_start_reads_in_order_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [drain(),
        "export fn main() : Unit = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"echo a; sleep 0.1; echo b >&2; sleep 0.1; echo c; exit 4\"],\n"
        "    input = <<>>, environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "    Right(p) -> drain(p)\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"out a\nerr b\nout c\nexit 4\n">>, Output).

%% Appendix E.23: the host takes the program's output only while a read
%% waits, so a program that writes more than a pipe holds, and that no one
%% reads, waits on its output and has not gone on to leave its mark. An
%% absence: the same program, its output read, ends within the time it is
%% timed at first, so the test waits twice that, rounded up to the
%% millisecond, before it looks for the mark
os_start_output_waits_for_a_read_test() ->
    Scratch = ern_emitter_tests:scratch(),
    Mark = filename:join(Scratch, "mark"),
    Timed = filename:join(Scratch, "timed"),
    {ok, Output} = ern_emitter_tests:run(
        [
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int = match Os.read(p, 5000) {\n"
        "    Right(Os.Exited(_)) -> n\n"
        "  | Right(_) -> drain(p, n + 1)\n"
        "  | Left(_) -> -1\n"
        "}\n"
        "fn marked() : Bool = Either.isRight(Fs.stat(Path(\"", Mark, "\"), 1000))\n"
        "fn writer(mark : String) : Address(Os.ProgramMsg) =\n"
        "    match Os.start(Os.Command(program = \"sh\",\n"
        "        arguments = [\"-c\", \"head -c 1000000 /dev/zero; touch \" <> mark],\n"
        "        input = <<>>, environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "        Right(p) -> p\n"
        "      | Left(e) -> fault(Io.show(e))\n"
        "    }\n"
        "export fn main() : Unit receiving Never = {\n"
        "    let before = Clock.monotonic();\n"
        "    let _ = drain(writer(\"", Timed, "\"), 0);\n"
        "    let took = Clock.monotonic() - before;\n"
        "    let p = writer(\"", Mark, "\");\n"
        "    Clock.sleep(2 * (took + 1));\n"
        "    let unread = marked();\n"
        "    let pieces = drain(p, 0);\n"
        "    Io.println(Io.show(#(unread, pieces > 0, marked())))\n"
        "}\n"]),
    ok = file:del_dir_r(Scratch),
    ?assertEqual(<<"#(false, true, true)\n">>, Output).

%% Appendix E.23: the program reads `input`, then what write gives it,
%% until closeInput; what is written after that is dropped, and the write
%% answers Left(Closed)
os_start_write_then_close_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "fn collect(p : Address(Os.ProgramMsg), got : Bytes) : Bytes =\n"
        "    match Os.read(p, 5000) {\n"
        "    Right(Os.Stdout(b)) -> collect(p, got <> b)\n"
        "  | _ -> got\n"
        "}\n"
        "export fn main() : Unit = match Os.start(Os.Command(program = \"cat\",\n"
        "    arguments = [], input = String.toUtf8(\"a\"),\n"
        "    environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "    Right(p) -> {\n"
        "        let taken = Os.write(p, String.toUtf8(\"b\"), 5000);\n"
        "        Os.closeInput(p);\n"
        "        let dropped = Os.write(p, String.toUtf8(\"c\"), 5000);\n"
        "        Io.println(Io.show(#(taken, dropped, String.fromUtf8(collect(p, <<>>)))))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Left(Io.Closed), Some(\"ab\"))\n">>, Output).

%% Appendix E.23, report §6.9: a running program is a process, which
%% `monitor` watches and `kill` stops, the program and its process group
%% with it; one that has answered its exit status lives on, answering it
%% again, until it is killed
os_program_is_a_process_test() ->
    Dir = ern_emitter_tests:scratch(),
    Pids = filename:join(Dir, "pids"),
    {ok, Output} = ern_emitter_tests:run(
        [
        "type Msg = Ended(Down)\n"
        "fn started(script : String) : Address(Os.ProgramMsg) receiving Msg =\n"
        "    match Os.start(Os.Command(program = \"sh\", arguments = [\"-c\", script],\n"
        "        input = <<>>, environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "        Right(p) -> p\n"
        "      | Left(_) -> fault(\"not started\")\n"
        "    }\n"
        "fn reason() : String receiving Msg =\n"
        "    receive { Ended(Down(reason = r, site = _)) -> Io.show(r) }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let sleeper = started(\"tail -f /dev/null & echo $$ $! > ", Pids,
        "; echo written; wait\");\n"
        "    // the process numbers are written once the shell says so\n"
        "    let _ = Os.read(sleeper, 5000);\n"
        "    monitor(Process.fromAddress(sleeper), Ended);\n"
        "    kill(Process.fromAddress(sleeper));\n"
        "    Io.println(reason());\n"
        "    let quick = started(\"exit 0\");\n"
        "    monitor(Process.fromAddress(quick), Ended);\n"
        "    let _ = Os.read(quick, 5000);\n"
        "    Io.println(Io.show(Os.read(quick, 5000)));\n"
        "    kill(Process.fromAddress(quick));\n"
        "    Io.println(reason())\n"
        "}\n"]),
    ?assertEqual(<<"Killed\nRight(Os.Exited(0))\nKilled\n">>, Output),
    {ok, Written} = file:read_file(Pids),
    ok = file:del_dir_r(Dir),
    [begin
         ?assertEqual(gone, gone(binary_to_list(Pid), 5000))
     end || Pid <- binary:split(Written, [<<" ">>, <<"\n">>], [global, trim_all])].

%% Appendix E.23, E.0 shape rule 8: a read whose milliseconds pass answers
%% Timeout and the program runs on, the next read taking what it wrote. A
%% regression test: before the rule, the start's time killed the program
os_read_time_limit_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "export fn main() : Unit = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"sleep 0.3; echo late\"], input = <<>>,\n"
        "    environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "    Right(p) -> {\n"
        "        Io.println(Io.show(Os.read(p, 50)));\n"
        "        Io.println(Io.show(Os.read(p, 5000)));\n"
        "        Io.println(Io.show(Os.read(p, 5000)))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertEqual(<<"Left(Io.Timeout)\nRight(Os.Stdout(<<108, 97, 116, 101, 10>>))\n"
                   "Right(Os.Exited(0))\n">>,
                 Output).

%%
%% Report Appendix E.23: a command's environment and working directory, and
%% a signal named. Regression tests, written after the code.
%%

%% What one command answered: its status and its output, trimmed, or why
%% it did not run.
ran() ->
    "fn ran(program : String, arguments : List(String),\n"
    "       environment : List(#(String, String)), directory : Path) : String =\n"
    "    match Os.run(Os.Command(=program, =arguments, input = <<>>, =environment,\n"
    "                            workingDirectory = directory), 5000) {\n"
    "        Right(f) -> Int.toString(f.status) <> \" \"\n"
    "            <> String.trim(String.fromUtf8Lossy(f.stdout))\n"
    "      | Left(e) -> Io.show(e)\n"
    "    }\n".

%% A command that inherits the environment and the working directory.
inheriting() ->
    "fn command(program : String, arguments : List(String)) : Os.Command =\n"
    "    Os.Command(=program, =arguments, input = <<>>, environment = [],\n"
    "               workingDirectory = Os.workingDirectory)\n".

%% What a running program wrote from here, and its exit status.
rest() ->
    "fn rest(p : Address(Os.ProgramMsg), text : String) : String = match Os.read(p, 5000) {\n"
    "    Right(Os.Stdout(b)) -> rest(p, text <> String.fromUtf8Lossy(b))\n"
    "  | Right(Os.Exited(s)) -> text <> \"exit \" <> Int.toString(s)\n"
    "  | other -> text <> Io.show(other)\n"
    "}\n".

%% What a running program wrote from here until it has written a word.
read_to() ->
    "fn readTo(p : Address(Os.ProgramMsg), word : String, text : String) : String =\n"
    "    if String.contains(text, word) then text else match Os.read(p, 5000) {\n"
    "        Right(Os.Stdout(b)) -> readTo(p, word, text <> String.fromUtf8Lossy(b))\n"
    "      | other -> text <> Io.show(other)\n"
    "    }\n".

%% Appendix E.23: the interrupt sent to a running program until it answers
%% other than `Right(Unit)`, `Left(Closed)` once the program has exited, which
%% no read asks for meanwhile.
closed() ->
    "fn closed(p : Address(Os.ProgramMsg)) : Either(Io.Error, Unit) =\n"
    "    match Os.signal(p, Os.Interrupt) {\n"
    "        Right(_) -> closed(p)\n"
    "      | other -> other\n"
    "    }\n".

%% An executable script at Path, its text the shell's.
script(Path, Text) ->
    ok = file:write_file(Path, ["#!/bin/sh\n", Text, "\n"]),
    ok = file:change_mode(Path, 8#755).

%% Appendix E.23: each variable of `environment` is set over the environment
%% the program inherits, the last of two with one name standing, the rest
%% inherited; a name without `/` is found in the directories of the `PATH`
%% the program starts with
os_command_environment_test() ->
    Dir = ern_emitter_tests:scratch(),
    script(filename:join(Dir, "tool"), "echo tool"),
    {ok, Output} = ern_emitter_tests:run(
        [ran(),
         "export fn main() : Unit = {\n"
         "    Io.println(ran(\"sh\", [\"-c\", \"echo $A $B\"],\n"
         "        [#(\"A\", \"1\"), #(\"B\", \"2\"), #(\"A\", \"3\")], Os.workingDirectory));\n"
         "    Io.println(ran(\"sh\", [\"-c\", \"echo $HOME\"], [#(\"A\", \"1\")],\n"
         "        Os.workingDirectory));\n"
         "    Io.println(ran(\"tool\", [], [#(\"PATH\", \"", Dir, "\")], Os.workingDirectory))\n"
         "}\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(iolist_to_binary(["0 3 2\n0 ", os:getenv("HOME"), "\n0 tool\n"]), Output).

%% Appendix E.23: the program runs in `workingDirectory`, a relative one
%% resolved against `Os.workingDirectory`, and a relative name with `/` is
%% resolved against it, after the directory is entered; a relative
%% directory of `PATH` is not covered
os_command_working_directory_test() ->
    Dir = ern_emitter_tests:scratch(),
    Sub = filename:join(Dir, "sub"),
    ok = file:make_dir(Sub),
    script(filename:join(Sub, "tool"), "pwd -P"),
    {ok, Cwd} = file:get_cwd(),
    %% the scratch directory named from the working directory, up to the
    %% root and down again
    Relative = filename:join(lists:duplicate(length(filename:split(Cwd)) - 1, "..")
                             ++ tl(filename:split(Sub))),
    {ok, Output} = ern_emitter_tests:run(
        [ran(),
         "export fn main() : Unit = {\n"
         "    Io.println(ran(\"pwd\", [\"-P\"], [], Path(\"", Relative, "\")));\n"
         "    Io.println(ran(\"./tool\", [], [], Path(\"", Sub, "\")))\n"
         "}\n"]),
    Physical = string:trim(os:cmd("cd " ++ Sub ++ " && pwd -P")),
    ok = file:del_dir_r(Dir),
    ?assertEqual(iolist_to_binary(["0 ", Physical, "\n0 ", Physical, "\n"]), Output).

%% Appendix E.23: a working directory the program cannot be started in
%% answers Other, the directory and the answer Fs gives for its path on one
%% line, before the program is looked for: NotFound for no directory and
%% for a path through a file, NotAFile for a file. A variable whose name is
%% empty or holds `=` or U+0000, or whose value holds U+0000, and a
%% directory that holds U+0000 answer Invalid. A directory the program may
%% not enter is not covered, since the superuser enters any
os_command_refusals_test() ->
    Dir = ern_emitter_tests:scratch(),
    ok = file:write_file(filename:join(Dir, "file"), <<>>),
    {ok, Output} = ern_emitter_tests:run(
        [ran(),
         "export fn main() : Unit = {\n"
         "    Io.println(ran(\"no-such-program-ern\", [], [], Path(\"", Dir, "/none\")));\n"
         "    Io.println(ran(\"true\", [], [], Path(\"", Dir, "/file\")));\n"
         "    Io.println(ran(\"true\", [], [], Path(\"", Dir, "/file/x\")));\n"
         "    Io.println(ran(\"true\", [], [#(\"\", \"x\")], Os.workingDirectory));\n"
         "    Io.println(ran(\"true\", [], [#(\"A=B\", \"x\")], Os.workingDirectory));\n"
         "    Io.println(ran(\"true\", [], [#(\"A\\u{0}\", \"x\")], Os.workingDirectory));\n"
         "    Io.println(ran(\"true\", [], [#(\"A\", \"x\\u{0}\")], Os.workingDirectory));\n"
         "    Io.println(ran(\"true\", [], [], Path(\"a\\u{0}b\")))\n"
         "}\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(iolist_to_binary(["Io.Other(\"", Dir, "/none: NotFound\")\n"
                                   "Io.Other(\"", Dir, "/file: NotAFile\")\n"
                                   "Io.Other(\"", Dir, "/file/x: NotFound\")\n"
                                   "Io.Invalid\nIo.Invalid\nIo.Invalid\nIo.Invalid\n"
                                   "Io.Invalid\n"]),
                 Output).

%% Appendix E.23: `signal` sends the program the signal it names: one it
%% does not handle ends it, its status 128 and the signal's number, and one
%% it handles is its own; once it has exited the answer is Closed
os_signal_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [inheriting(), rest(),
         "fn ended(signal : Os.Signal) : String =\n"
         "    match Os.start(command(\"sleep\", [\"10\"])) {\n"
         "        Right(p) -> {\n"
         "            let sent = Os.signal(p, signal);\n"
         "            let last = Os.read(p, 5000);\n"
         "            let again = Os.signal(p, signal);\n"
         "            kill(Process.fromAddress(p));\n"
         "            Io.show(#(sent, last, again))\n"
         "        }\n"
         "      | Left(e) -> Io.show(e)\n"
         "    }\n"
         "export fn main() : Unit = {\n"
         "    Io.println(ended(Os.Termination));\n"
         "    Io.println(ended(Os.Hangup));\n"
         "    Io.println(ended(Os.Interrupt));\n"
         "    match Os.start(command(\"sh\",\n"
         "        [\"-c\", \"trap 'exit 7' HUP; echo ready;\"\n"
         "         <> \" sleep 10 > /dev/null 2>&1 & wait\"])) {\n"
         "        Right(p) -> {\n"
         "            let ready = Os.read(p, 5000);\n"
         "            let sent = Os.signal(p, Os.Hangup);\n"
         "            Io.println(Io.show(#(ready, sent)) <> \" \" <> rest(p, \"\"))\n"
         "        }\n"
         "      | Left(e) -> Io.println(Io.show(e))\n"
         "    }\n"
         "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Right(Os.Exited(143)), Left(Io.Closed))\n"
                   "#(Right(Unit), Right(Os.Exited(129)), Left(Io.Closed))\n"
                   "#(Right(Unit), Right(Os.Exited(130)), Left(Io.Closed))\n"
                   "#(Right(Os.Stdout(<<114, 101, 97, 100, 121, 10>>)), Right(Unit)) exit 7\n">>,
                 Output).

%% Appendix E.23: a signal goes to the program alone, not to the processes
%% it started: the shell's child, which a signal to the group would end,
%% reads the line its parent writes to it at the termination
os_signal_to_the_program_alone_test() ->
    Dir = ern_emitter_tests:scratch(),
    Fifo = filename:join(Dir, "fifo"),
    {ok, Output} = ern_emitter_tests:run(
        [inheriting(), rest(),
         "export fn main() : Unit =\n"
         "    match Os.start(command(\"sh\", [\"-c\", \"mkfifo $0; trap 'echo > $0' TERM;\"\n"
         "        <> \" (trap 'echo child-term; exit' TERM; echo ready; read line < $0;\"\n"
         "        <> \" echo child-saw) & wait; wait\", \"", Fifo, "\"])) {\n"
         "        Right(p) -> {\n"
         "            let ready = Os.read(p, 5000);\n"
         "            let sent = Os.signal(p, Os.Termination);\n"
         "            Io.println(Io.show(#(ready, sent)) <> \" \" <> rest(p, \"\"))\n"
         "        }\n"
         "      | Left(e) -> Io.println(Io.show(e))\n"
         "    }\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(<<"#(Right(Os.Stdout(<<114, 101, 97, 100, 121, 10>>)), Right(Unit))"
                   " child-saw\nexit 0\n">>,
                 Output).

%% Appendix E.23: a signal to a program that has exited answers Closed
%% though no read has yet taken its exit, which no read asks for here. The
%% child says `gone` on reading the end of the pipe the shell held, which
%% the host closes as the shell exits but before it reports the exit, so
%% the signal is sent until it answers Closed: each one sent before reaches
%% a shell that takes no signal any longer, as its status of 0 shows
os_signal_after_an_unread_exit_test() ->
    Dir = ern_emitter_tests:scratch(),
    Fifo = filename:join(Dir, "fifo"),
    {ok, Output} = ern_emitter_tests:run(
        [inheriting(), rest(), read_to(), closed(),
         "export fn main() : Unit =\n"
         "    match Os.start(command(\"sh\",\n"
         "        [\"-c\", \"mkfifo $0; (read line < $0; echo gone) &\"\n"
         "        <> \" exec 4> $0; echo started\", \"", Fifo, "\"])) {\n"
         "        Right(p) -> {\n"
         "            let text = readTo(p, \"gone\", \"\");\n"
         "            let sent = closed(p);\n"
         "            Io.println(Io.show(sent) <> \" \" <> rest(p, text))\n"
         "        }\n"
         "      | Left(e) -> Io.println(Io.show(e))\n"
         "    }\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(<<"Left(Io.Closed) started\ngone\nexit 0\n">>, Output).

%% Appendix E.23: a write to a program that has exited answers Closed
%% though no read has yet taken its exit, and though a process the program
%% started holds its input open, as `sleep` does here. The shell ignores
%% the interrupt, so the signal is sent until it answers Closed, which says
%% the shell has exited, and its status is 0
os_write_after_an_unread_exit_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [inheriting(), rest(), read_to(), closed(),
         "export fn main() : Unit =\n"
         "    match Os.start(command(\"sh\", [\"-c\", \"trap '' INT; exec 3<&0;\"\n"
         "        <> \" sleep 1000 <&3 >/dev/null 2>&1 & echo started\"])) {\n"
         "        Right(p) -> {\n"
         "            let text = readTo(p, \"\\n\", \"\");\n"
         "            let sent = closed(p);\n"
         "            let written = Os.write(p, <<120>>, 5000);\n"
         "            Io.println(Io.show(#(sent, written)) <> \" \" <> rest(p, text))\n"
         "        }\n"
         "      | Left(e) -> Io.println(Io.show(e))\n"
         "    }\n"]),
    ?assertEqual(<<"#(Left(Io.Closed), Left(Io.Closed)) started\nexit 0\n">>, Output).

%% Appendix E.23: a resize and a write to a program under a terminal that
%% has exited answer Closed though no read has yet taken its exit, and
%% though a process the program started holds the terminal open, as `sleep`
%% does here, ignoring the hangup the shell's exit sends it. The hangup
%% `closeInput` makes ends the run, as the program has exited
os_resize_after_an_unread_exit_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [inheriting(), rest(), read_to(), closed(),
         "export fn main() : Unit =\n"
         "    match Os.startTerminal(command(\"sh\", [\"-c\", \"trap '' HUP INT;\"\n"
         "        <> \" sleep 1000 & echo started\"]), Terminal.Size(rows = 24, columns = 80)) {\n"
         "        Right(p) -> {\n"
         "            let text = readTo(p, \"\\r\\n\", \"\");\n"
         "            let sent = closed(p);\n"
         "            let resized = Os.resize(p, Terminal.Size(rows = 30, columns = 100));\n"
         "            let written = Os.write(p, <<120>>, 5000);\n"
         "            Os.closeInput(p);\n"
         "            Io.println(Io.show(#(sent, resized, written)) <> \" \" <> rest(p, text))\n"
         "        }\n"
         "      | Left(e) -> Io.println(Io.show(e))\n"
         "    }\n"]),
    ?assertEqual(<<"#(Left(Io.Closed), Left(Io.Closed), Left(Io.Closed)) started\r\nexit 0\n">>,
                 Output).

%% Appendix E.23, report §8.6: Os.exit ends the program with its status,
%% from any process, the output written before it flushed; a status
%% outside 0 to 255 faults the caller (§7.4)
os_exit_test() ->
    ?assertEqual({{exit, 3}, <<"bye\n">>},
                 ern_emitter_tests:run(
                     "export fn main() : Unit = {\n"
                     "    Io.println(\"bye\");\n"
                     "    Os.exit(3)\n"
                     "}\n")),
    ?assertEqual({{exit, 5}, <<>>},
                 ern_emitter_tests:run(
                     "export fn main() : Unit receiving Unit = {\n"
                     "    let _ = spawn(fn() = Os.exit(5));\n"
                     "    receive { _ -> Unit }\n"
                     "}\n")),
    ?assertMatch({{fault, <<"an exit status is from 0 to 255">>, _}, <<>>},
                 ern_emitter_tests:run("export fn main() : Unit = Os.exit(256)\n")).

%% report §11.2: where Os.exit faults its caller, as in the shell and under
%% `ern test`, it ends only the process that calls it
os_exit_faults_where_asked_test() ->
    ?assertMatch({{fault, <<"exited with status 2">>, _}, <<>>},
                 ern_emitter_tests:run(
                     ['M'], "export fn main() : Unit = Os.exit(2)\n",
                     #{exit => fault})).

%% Appendix E.23, report §11.2: Os.arguments is what the program was run
%% with, and the empty list where it was run with none
os_arguments_test() ->
    Main = "export fn main() : Unit = Io.println(Io.show(Os.arguments))\n",
    ?assertEqual({ok, <<"[\"a\", \"b c\", \"--x\"]\n">>},
                 ern_emitter_tests:run(
                     ['M'], Main, #{arguments => [<<"a">>, <<"b c">>, <<"--x">>]})),
    ?assertEqual({ok, <<"[]\n">>}, ern_emitter_tests:run(Main)).

%%
%% Report Appendix E.17: Fs.
%%

%% Appendix E.17: a path that holds U+0000 names no file, `Invalid`. A
%% regression test for the host's own term, badarg, answered as the cause
fs_path_with_nul_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "export fn main() : Unit =\n"
        "    Io.println(Io.show(Fs.read(Path(\"a\\u{0}b\"), 1000)))\n"),
    ?assertEqual(<<"Left(Io.Invalid)\n">>, Output).

%% Appendix E.17, §12.1: a name in a directory that is not UTF-8 makes
%% Fs.list answer NotUtf8 with its bytes; a regression test for the host's
%% warning printed in its place, and of the rule, before which the name was
%% left out
fs_list_names_a_name_not_utf8_test() ->
    Dir = ern_emitter_tests:scratch(),
    ok = file:write_file(<<(list_to_binary(Dir))/binary, "/caf", 16#e9>>, <<>>),
    ok = file:write_file(filename:join(Dir, "ok"), <<>>),
    {ok, Output} = ern_emitter_tests:run(
        ["export fn main() : Unit = match Fs.list(Path(\"", Dir,
         "\"), 1000) {\n"
         "    Right(entries) -> Io.println(Io.show(List.map(entries,\n"
         "        fn(e) = Path.name(e.path))))\n"
         "  | Left(e) -> Io.println(Io.show(e))\n"
         "}\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(<<"Io.NotUtf8(<<99, 97, 102, 233>>)\n">>, Output).

%%
%% Report Appendix E.18: Tcp.
%%

%% report Appendix E.18: a socket is owned by the process that opened it and
%% killed when its owner dies; `give` makes another its owner, and a socket
%% given to a process that has ended is killed at once. A regression test:
%% a socket outlived a handler that faulted, one leaked connection each
socket_owner_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "type Msg = Opened(Address(Tcp.SocketMsg)) | Ended(Down)\n"
        "fn opener(port : Int, to : Address(Msg)) : Unit =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> send(to, Opened(s))\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn keeper() : Unit receiving Int = receive { _ -> Unit }\n"
        "fn giver(port : Int, keep : Process, to : Address(Msg)) : Unit =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> {\n"
        "            Tcp.give(s, keep);\n"
        "            send(to, Opened(s))\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn opened() : Address(Tcp.SocketMsg) receiving Msg = receive { Opened(s) -> s }\n"
        "fn ends(s : Address(Tcp.SocketMsg), ms : Int) : String receiving Msg = {\n"
        "    monitor(Process.fromAddress(s), Ended);\n"
        "    receive { Ended(_) -> \"ended\" | after ms -> \"alive\" }\n"
        "}\n"
        "fn check(port : Int) : Unit receiving Msg = {\n"
        "    let me = self();\n"
        "    let first = spawnMonitored(fn() = opener(port, me), Ended);\n"
        "    let orphan = opened();\n"
        "    receive { Ended(_) -> Unit };\n"
        "    Io.println(\"opener's: \" <> ends(orphan, 2000));\n"
        "    let keep = spawn(keeper);\n"
        "    let _ = spawnMonitored(fn() = giver(port, Process.fromAddress(keep), me), Ended);\n"
        "    let given = opened();\n"
        "    receive { Ended(_) -> Unit };\n"
        "    Io.println(\"given, giver gone: \" <> ends(given, 300));\n"
        "    send(keep, 1);\n"
        "    Io.println(\"given, keeper gone: \" <> ends(given, 2000));\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> {\n"
        "            Tcp.give(s, Process.fromAddress(first));\n"
        "            Io.println(\"given to the dead: \" <> ends(s, 2000))\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit receiving Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(listener) -> {\n"
        "        let _ = Either.map(Tcp.port(listener), check);\n"
        "        Tcp.closeListener(listener)\n"
        "    }\n"
        "  | Left(_) -> Unit\n"
        "}\n"),
    ?assertEqual(<<"opener's: ended\ngiven, giver gone: alive\ngiven, keeper gone: ended\n"
                   "given to the dead: ended\n">>, Output).

%% report Appendix E.18: over TLS from Ernest, `listenTls` and `connectTls`
%% answer the addresses `listen` and `connect` answer, which `accept`,
%% `port`, `read`, `write` and `close` take, each opened at its function's
%% site; a missing key answers `Left(Other(text))`, the file's name and
%% `NotFound`, as `Fs` answers the path, and a `connectTls` where nothing
%% listens `Left(Refused)`. Written after the code, a regression test of the
%% requests the module sends TCP's process, the file named after the code
%% too; the cases of the runtime's own are ern_tcp_tests'
tcp_tls_test() ->
    #{dir := Dir, ca := Ca, server := {Certificate, Key}} = ern_tcp_tests:pki(),
    {ok, Output} = ern_emitter_tests:run(
        ["fn site(p : Process) : String = match Process.status(p) {\n"
         "    Some(Process.Status(site = s, queued = _, activity = _)) -> s\n"
         "  | None -> \"none\"\n"
         "}\n"
         "fn echoed() : Either(Io.Error, #(Bytes, List(String))) = {\n"
         "    let certificate = Path(\"", Certificate, "\");\n"
         "    let listener <- Tcp.listenTls(\"127.0.0.1\", 0, certificate, Path(\"", Key, "\"));\n"
         "    let port <- Tcp.port(listener);\n"
         "    let _ = spawn(fn() = match Tcp.accept(listener, 5000) {\n"
         "        Right(accepted) -> {\n"
         "            let _ = Either.andThen(Tcp.read(accepted, 5000),\n"
         "                                   fn(bytes) = Tcp.write(accepted, bytes, 5000));\n"
         "            Tcp.close(accepted)\n"
         "        }\n"
         "      | Left(_) -> Unit\n"
         "    });\n"
         "    let check = Tcp.Verified(Path(\"", Ca, "\"));\n"
         "    let client <- Tcp.connectTls(\"localhost\", port, check, 5000);\n"
         "    let _ <- Tcp.write(client, String.toUtf8(\"ping\"), 5000);\n"
         "    let received <- Tcp.read(client, 5000);\n"
         "    let sites = List.map([Process.fromAddress(listener), Process.fromAddress(client)],"
         " site);\n"
         "    Tcp.close(client);\n"
         "    Tcp.closeListener(listener);\n"
         "    Right(#(received, sites))\n"
         "}\n"
         "fn refused(answer : Either(Io.Error, a)) : String = match answer {\n"
         "    Left(Io.Other(text)) -> text\n"
         "  | Left(error) -> Io.show(error)\n"
         "  | Right(_) -> \"right\"\n"
         "}\n"
         "export fn main() : Unit = {\n"
         "    Io.println(Io.show(echoed()));\n"
         "    let missing = Path(\"", filename:join(Dir, "missing.key"), "\");\n"
         "    let served = Path(\"", Certificate, "\");\n"
         "    Io.println(refused(Tcp.listenTls(\"127.0.0.1\", 0, served, missing)));\n"
         "    Io.println(refused(Tcp.connectTls(\"127.0.0.1\", 1, Tcp.Unverified, 1000)))\n"
         "}\n"]),
    ?assertEqual(iolist_to_binary(["Right(#(<<112, 105, 110, 103>>, [\"Tcp.listenTls\","
                                   " \"Tcp.connectTls\"]))\n",
                                   filename:join(Dir, "missing.key"), ": NotFound\nIo.Refused\n"]),
                 Output).

%% Appendix E.18, E.21, E.23: a listener, a socket and a running program are
%% processes of the program's: Process.live lists them, and Process.status
%% gives the function that opened each as its site. A regression test: the
%% runtime did not know them
opened_processes_are_live_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "fn site(p : Process) : String = match Process.status(p) {\n"
        "    Some(Process.Status(site = s, queued = _, activity = _)) -> s\n"
        "  | None -> \"none\"\n"
        "}\n"
        "fn listed(p : Process) : Bool = List.any(Process.live(), fn(q) = q == p)\n"
        "export fn main() : Unit = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "            Right(c) -> {\n"
        "                let pl = Process.fromAddress(l);\n"
        "                let pc = Process.fromAddress(c);\n"
        "                Io.println(Io.show(#(site(pl), site(pc), listed(pl), listed(pc))));\n"
        "                match Os.start(Os.Command(program = \"cat\", arguments = [],"
        " input = <<>>, environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "                    Right(p) -> Io.println(site(Process.fromAddress(p)))\n"
        "                  | Left(e) -> Io.println(Io.show(e))\n"
        "                }\n"
        "            }\n"
        "          | Left(e) -> Io.println(Io.show(e))\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(\"Tcp.listen\", \"Tcp.connect\", true, true)\nOs.start\n">>, Output).

%% Appendix E.21, E.18, E.23: `Process.owned` answers the listener, the
%% socket and the running program a process opened, told apart by their
%% sites, a socket given to another process no longer among them once it
%% has taken the gift, which a write after it orders; and none
%% once the process has ended, what it owned ending with it. A regression
%% test, written after the code; the tables and a proxy's process, which
%% the libraries make, are ern_shell_tests' owned_said_test_'s
owned_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "type Msg = Opened(listener : Process, socket : Address(Tcp.SocketMsg)) | Ended(Down)\n"
        "fn sites(ps : List(Process)) : List(String) =\n"
        "    List.sort(List.filterMap(ps, fn(p) = Optional.map(Process.status(p),"
        " fn(s) = s.site)))\n"
        "fn opener(main : Address(Msg)) : Unit receiving Unit =\n"
        "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Either.andThen(Tcp.port(l), fn(port) ="
        " Tcp.connect(\"127.0.0.1\", port, 1000)) {\n"
        "        Right(c) -> {\n"
        "            let _ = Os.start(Os.Command(program = \"cat\", arguments = [],"
        " input = <<>>, environment = [], workingDirectory = Os.workingDirectory));\n"
        "            send(main, Opened(listener = Process.fromAddress(l), socket = c));\n"
        "            receive { _ -> Unit }\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "  | Left(_) -> Unit\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let main = self();\n"
        "    let o = spawn(fn() = opener(main));\n"
        "    let p = Process.fromAddress(o);\n"
        "    receive {\n"
        "        Opened(=listener, socket = c) -> {\n"
        "            Io.println(Io.show(sites(Process.owned(p))));\n"
        "            Tcp.give(c, Process.current());\n"
        "            let _ = Tcp.write(c, <<>>, 1000);\n"
        "            Io.println(Io.show(sites(Process.owned(p))));\n"
        "            monitor(p, Ended);\n"
        "            monitor(listener, Ended);\n"
        "            kill(Process.fromAddress(o));\n"
        "            receive { _ -> Unit };\n"
        "            receive { _ -> Unit };\n"
        "            Io.println(Io.show(#(Process.owned(p), Process.status(listener))))\n"
        "        }\n"
        "      | Ended(_) -> Unit\n"
        "    }\n"
        "}\n"]),
    ?assertEqual(<<"[\"Os.start\", \"Tcp.connect\", \"Tcp.listen\"]\n"
                   "[\"Os.start\", \"Tcp.listen\"]\n"
                   "#([], None)\n">>, Output).

%% Appendix E.21, report §6.9, §7.3: `Process.run` answers the value its
%% function returned, or the reason its process ended with before it
%% returned, a fault and a kill. The fault is the process's own, reported
%% under the site where `run` is written, as a spawn's is, and the
%% process's site is that one, where `run` is called and where it is named
%% as a value. A process its function spawns lives on; what it opens ends
%% with it, the listener's end found by its monitor. A regression test,
%% written after the code; a site passed in a session's input is
%% ern_shell_tests' run_site_test_'s
process_run_test() ->
    Self = self(),
    Faults = fun({'FaultReport', _, Site, Cause, _, _, _, _, _, _}, _) ->
                     Self ! {fault, Site, Cause}
             end,
    {ok, Output} = ern_emitter_tests:run(['M'],
        "type Msg = Ended(Down)\n"
        "type Waits = Waits\n"
        "fn waits() : Unit receiving Waits = receive { Waits -> Unit }\n"
        "fn site() : Optional(String) =\n"
        "    Optional.map(Process.status(Process.current()), fn(status) = status.site)\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    Io.println(Io.show(Process.run(fn() = 6 * 7)));\n"
        "    Io.println(Io.show(Process.run(fn() : Int = fault(\"boom\"))));\n"
        "    Io.println(Io.show(Process.run(fn() = kill(Process.current()))));\n"
        "    Io.println(Io.show(Process.run(site)));\n"
        "    Io.println(Io.show(List.map([site], Process.run)));\n"
        "    match Process.run(fn() = Process.fromAddress(spawn(waits))) {\n"
        "        Right(spawned) -> {\n"
        "            Io.println(Io.show(Optional.isSome(Process.status(spawned))));\n"
        "            kill(spawned)\n"
        "        }\n"
        "      | Left(reason) -> Io.println(Io.show(reason))\n"
        "    };\n"
        "    match Process.run(fn() = Tcp.listen(\"127.0.0.1\", 0)) {\n"
        "        Right(Right(listener)) -> {\n"
        "            monitor(Process.fromAddress(listener), Ended);\n"
        "            receive { Ended(_) -> Io.println(\"ended\") }\n"
        "        }\n"
        "      | _ -> Io.println(\"no listener\")\n"
        "    }\n"
        "}\n",
        #{faults => Faults, stderr => fun(_) -> ok end}),
    ?assertEqual(<<"Right(42)\n"
                   "Left(Fault(\"boom\"))\n"
                   "Left(Killed)\n"
                   "Right(Some(\"M.main:10\"))\n"
                   "[Right(Some(\"M.main:11\"))]\n"
                   "true\n"
                   "ended\n">>, Output),
    ?assertEqual([{<<"M.main:8">>, <<"boom">>}],
                 [receive {fault, Site, Cause} -> {Site, Cause} after 0 -> none end]).

%% Appendix E.21, report §6.9: the process `Process.run` started is killed
%% where its caller ends while it waits, and where its caller restarts,
%% here at its sibling's fault under OneForAll (Appendix E.22), which a
%% plain monitor is not told of; `Process.owned` does not list it among the
%% caller's. A regression test, written after the code
process_run_caller_ends_test() ->
    {ok, Output} = ern_emitter_tests:run(['M'],
        "type Msg = Started(Process) | Ended(Down)\n"
        "type ChildMsg = Go(Address(Msg)) | Boom\n"
        "type Waits = Waits\n"
        "let sup : Address(Supervisor.GroupMsg) = spawn(Supervisor.group(Supervisor.OneForAll,\n"
        "    RestartLimit(restarts = 3, within = 5000)))\n"
        "let a : Address(ChildMsg) = spawn(Supervisor.child(sup, runs))\n"
        "let b : Address(ChildMsg) = spawn(Supervisor.child(sup, runs))\n"
        "fn waits() : Unit receiving Waits = receive { Waits -> Unit }\n"
        "fn started(main : Address(Msg)) : Unit receiving Waits = {\n"
        "    send(main, Started(Process.current()));\n"
        "    waits()\n"
        "}\n"
        "fn runs() : Unit receiving ChildMsg = receive {\n"
        "    Go(main) -> {\n"
        "        let _ = Process.run(fn() = started(main));\n"
        "        Unit\n"
        "    }\n"
        "  | Boom -> fault(\"boom\")\n"
        "}\n"
        "fn ended(worker : Process) : Unit receiving Msg = {\n"
        "    monitor(worker, Ended);\n"
        "    receive { Ended(down) -> Io.println(Io.show(down.reason)) | Started(_) -> Unit }\n"
        "}\n"
        "fn worker() : Process receiving Msg =\n"
        "    receive { Started(process) -> process | Ended(_) -> worker() }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let main = self();\n"
        "    let caller = spawn(fn() = {\n"
        "        let _ = Process.run(fn() = started(main));\n"
        "        Unit\n"
        "    });\n"
        "    let killed = worker();\n"
        "    Io.println(Io.show(Process.owned(Process.fromAddress(caller))));\n"
        "    kill(Process.fromAddress(caller));\n"
        "    ended(killed);\n"
        "    send(a, Go(main));\n"
        "    let restarted = worker();\n"
        "    send(b, Boom);\n"
        "    ended(restarted)\n"
        "}\n",
        #{stderr => fun(_) -> ok end}),
    ?assertEqual(<<"[]\nKilled\nKilled\n">>, Output).

%% Appendix E.18: a write answers Right(Unit) once the socket has taken the
%% bytes, and Left(Closed) once the connection has closed; the far end's
%% close is learned here by a read, so that the answer does not depend on
%% when the host reports it
tcp_write_answers_closed_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "export fn main() : Unit = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let _ = spawn(fn() = match Tcp.accept(l, 5000) {\n"
        "                Right(s) -> {\n"
        "                    let _ = Tcp.read(s, 5000);\n"
        "                    Tcp.close(s)\n"
        "                }\n"
        "              | Left(_) -> Unit\n"
        "            });\n"
        "            match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "                Right(c) -> {\n"
        "                    let taken = Tcp.write(c, <<1>>, 5000);\n"
        "                    let ended = Tcp.read(c, 5000);\n"
        "                    Io.println(Io.show(#(taken, ended, Tcp.write(c, <<2>>, 5000))))\n"
        "                }\n"
        "              | Left(e) -> Io.println(Io.show(e))\n"
        "            }\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Left(Io.Closed), Left(Io.Closed))\n">>, Output).

%%
%% Report §12.1, Appendix E.18, E.23: a write returns once its stream has
%% taken the bytes, and waits while the stream is behind. Regression
%% tests, written after the code: each write returned at once, and what the
%% reader had not taken was held in the node.
%%

%% A writer of four megabytes, and whether it has finished while nothing
%% reads, then after everything is read. An absence: the same writes, read
%% as they come, are timed first, and the writer read by no one is looked
%% at once twice that time, rounded up to the millisecond, has passed.
paced(Setup) ->
    ern_emitter_tests:run(
        ["type Msg = Done | Ended(Down) | Gone(Down)\n",
         Setup,
         "fn chunk() : Bytes = String.toUtf8(String.repeat(\"x\", 65536))\n"
         "fn writes(write : (Bytes) -> Either(Io.Error, Unit), n : Int) : Unit =\n"
         "    if n == 0 then Unit else { let _ = write(chunk()); writes(write, n - 1) }\n"
         "fn done() : Bool receiving Msg =\n"
         "    receive { Done -> true | after 0 -> false }\n"]).

%% Appendix E.23: a program that stops reading its input, since no one
%% reads its output, holds its writer, and a write after its exit answers
%% Left(Closed)
os_write_waits_test() ->
    {ok, Output} = paced(
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int = match Os.read(p, 5000) {\n"
        "    Right(Os.Stdout(b)) -> drain(p, n + Bytes.size(b))\n"
        "  | _ -> n\n"
        "}\n"
        "fn written() : Address(Os.ProgramMsg) receiving Msg =\n"
        "    match Os.start(Os.Command(program = \"cat\", arguments = [], input = <<>>,\n"
        "        environment = [], workingDirectory = Os.workingDirectory)) {\n"
        "        Right(p) -> {\n"
        "            let me = self();\n"
        "            let _ = spawn(fn() = {\n"
        "                writes(fn(b) = Os.write(p, b, 30000), 64);\n"
        "                Os.closeInput(p);\n"
        "                send(me, Done)\n"
        "            });\n"
        "            p\n"
        "        }\n"
        "      | Left(e) -> fault(Io.show(e))\n"
        "    }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let before = Clock.monotonic();\n"
        "    let _ = drain(written(), 0);\n"
        "    receive { Done -> Unit };\n"
        "    let took = Clock.monotonic() - before;\n"
        "    let p = written();\n"
        "    Clock.sleep(2 * (took + 1));\n"
        "    let early = done();\n"
        "    let n = drain(p, 0);\n"
        "    receive { Done -> Unit };\n"
        "    Io.println(Io.show(#(early, n)));\n"
        "    Io.println(Io.show(Os.write(p, <<1>>, 5000)))\n"
        "}\n"),
    ?assertEqual(<<"#(false, 4194304)\nLeft(Io.Closed)\n">>, Output).

%% Appendix E.18: a socket whose far end does not read holds its writer,
%% and a write to a socket that has been closed faults
tcp_write_waits_test() ->
    {ok, Output} = paced(
        "fn drain(s : Address(Tcp.SocketMsg), n : Int) : Int =\n"
        "    if n >= 4194304 then n\n"
        "    else match Tcp.read(s, 5000) {\n"
        "        Right(b) -> drain(s, n + Bytes.size(b))\n"
        "      | Left(_) -> n\n"
        "    }\n"
        "fn written(l : Address(Tcp.ListenerMsg),\n"
        "           port : Int) : Address(Tcp.SocketMsg) receiving Msg = {\n"
        "    let me = self();\n"
        "    let _ = spawn(fn() = match\n"
        "        Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(c) -> {\n"
        "            writes(fn(b) = Tcp.write(c, b, 30000), 64);\n"
        "            send(me, Done)\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    });\n"
        "    match Tcp.accept(l, 5000) {\n"
        "        Right(s) -> s\n"
        "      | Left(e) -> fault(Io.show(e))\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit receiving Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let before = Clock.monotonic();\n"
        "            let timed = written(l, port);\n"
        "            let _ = drain(timed, 0);\n"
        "            receive { Done -> Unit };\n"
        "            let took = Clock.monotonic() - before;\n"
        "            Tcp.close(timed);\n"
        "            let s = written(l, port);\n"
        "            Clock.sleep(2 * (took + 1));\n"
        "            let early = done();\n"
        "            let n = drain(s, 0);\n"
        "            receive { Done -> Unit };\n"
        "            // the socket's process ends as it closes\n"
        "            monitor(Process.fromAddress(s), Gone);\n"
        "            Tcp.close(s);\n"
        "            receive { Gone(_) -> Unit };\n"
        "            Io.println(Io.show(#(early, n)));\n"
        "            let late = fn() = {\n"
        "                let _ = Tcp.write(s, <<1>>, 5000);\n"
        "                Unit\n"
        "            };\n"
        "            let _ = spawnMonitored(late, Ended);\n"
        "            receive { Ended(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "        }\n"
        "      | Left(e) -> Io.println(Io.show(e))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertEqual(<<"#(false, 4194304)\nFault(\"callee had ended\")\n">>, Output).
