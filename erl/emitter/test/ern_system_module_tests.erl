%% Report §8.2: the system modules, Terminal, Os, Fs and Tcp, in programs
%% run as the runner runs them (ern_emitter_tests:run/3).
-module(ern_system_module_tests).

-include_lib("eunit/include/eunit.hrl").

%%
%% Report §8.2: the terminal, read as lines or as keys.
%%

%% report §8.2: keys and lines are the same terminal, so the process that
%% claims it the other way faults, naming the side that holds it
terminal_is_lines_or_keys_test() ->
    {Result1, _} = ern_emitter_tests:run_at_terminal(
        "type Msg = Pressed(Terminal.Event)\n"
        "export fn main() : Unit with Msg = {\n"
        "    let _ = Io.readLine();\n"
        "    let _ = Terminal.subscribe(Pressed);\n"
        "    receive { Pressed(_) -> Unit }\n"
        "}\n"),
    ?assertEqual({fault, <<"the terminal is already read as lines">>}, Result1).

%% report §8.2, §7.4: a claim of the terminal the other way faults the
%% process that makes it, and the first claim stands: a worker that
%% subscribes after main read a line faults, and main reads on. A
%% regression test: the entry process faulted, whoever asked
terminal_claim_faults_its_caller_test() ->
    ?assertEqual({ok, <<"the terminal is already read as lines\nread on\n">>},
                 ern_emitter_tests:run_at_terminal(
                     "type Msg = Pressed(Terminal.Event)\n"
                     "type MainMsg = Ended(Down)\n"
                     "fn watch() : Unit with Msg = {\n"
                     "    let _ = Terminal.subscribe(Pressed);\n"
                     "    Unit\n"
                     "}\n"
                     "export fn main() : Unit with MainMsg = {\n"
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
         "export fn main() : Unit with Never = Io.println(show(Os.run(Os.Command(program = ",
         Program, ", arguments = ", Arguments, ", input = ", Input, "), ", Ms, ")))\n"]).

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
    ?assertEqual({ok, <<"NotFound\n">>}, os_run("\"no-such-program-ern\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"NotFound\n">>}, os_run("\"\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Denied\n">>}, os_run("\"/dev/null\"", "[]", "<<>>", "5000")),
    ?assertEqual({ok, <<"Invalid\n">>},
                 os_run("\"echo\"", "[\"a\\u{0}b\"]", "<<>>", "5000")).

%% Appendix E.23: Timeout when the time runs out first, and the program,
%% still running, killed, so the mark it would leave is never made. An
%% absence: the program, started before the run's time ran out, would
%% have left its mark within its own second, so the test waits that second
%% from the run's return
os_run_timeout_kills_test() ->
    Mark = filename:join(ern_emitter_tests:scratch(), "mark"),
    {ok, Output} = os_run("\"sh\"", "[\"-c\", \"sleep 1; touch " ++ Mark ++ "\"]", "<<>>", "200"),
    ?assertEqual(<<"Timeout\n">>, Output),
    timer:sleep(1000),
    ?assertNot(filelib:is_file(Mark)).

%% Appendix E.23: a program whose caller dies is killed with it. The caller
%% says once the program has started; an absence then: the program would
%% have left its mark within its own second, which began before it was
%% killed, so the test waits that second from the end of the run
os_run_dies_with_its_caller_test() ->
    Mark = filename:join(ern_emitter_tests:scratch(), "mark"),
    {ok, _} = ern_emitter_tests:run(
        "type Msg = Started\n"
        "export fn main() : Unit with Msg = {\n"
        "    let me = self();\n"
        "    let w = spawn(fn() : Unit with Never = match Os.start(Os.Command(program = \"sh\",\n"
        "        arguments = [\"-c\", \"sleep 1; touch " ++ Mark ++ "\"], input = <<>>)) {\n"
        "        Right(p) -> { send(me, Started); let _ = Os.read(p, 5000); Unit }\n"
        "      | Left(_) -> Unit\n"
        "    });\n"
        "    receive { Started -> Unit };\n"
        "    kill(w)\n"
        "}\n"),
    timer:sleep(1000),
    ?assertNot(filelib:is_file(Mark)).

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
    "fn drain(p : Address(Os.ProgramMsg)) : Unit with m = match Os.read(p, 5000) {\n"
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
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"echo a; sleep 0.1; echo b >&2; sleep 0.1; echo c; exit 4\"],\n"
        "    input = <<>>)) {\n"
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
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int with m = match Os.read(p, 5000) {\n"
        "    Right(Os.Exited(_)) -> n\n"
        "  | Right(_) -> drain(p, n + 1)\n"
        "  | Left(_) -> -1\n"
        "}\n"
        "fn marked() : Bool with m = Either.isRight(Fs.stat(Path(\"", Mark, "\"), 1000))\n"
        "fn writer(mark : String) : Address(Os.ProgramMsg) with m =\n"
        "    match Os.start(Os.Command(program = \"sh\",\n"
        "        arguments = [\"-c\", \"head -c 1000000 /dev/zero; touch \" <> mark],\n"
        "        input = <<>>)) {\n"
        "        Right(p) -> p\n"
        "      | Left(e) -> fault(Io.show(e))\n"
        "    }\n"
        "export fn main() : Unit with Never = {\n"
        "    let before = Clock.monotonic();\n"
        "    let _ = drain(writer(\"", Timed, "\"), 0);\n"
        "    let took = Clock.monotonic() - before;\n"
        "    let p = writer(\"", Mark, "\");\n"
        "    receive { after 2 * (took + 1) -> Unit };\n"
        "    let unread = marked();\n"
        "    let pieces = drain(p, 0);\n"
        "    Io.println(Io.show(#(unread, pieces > 0, marked())))\n"
        "}\n"]),
    ?assertEqual(<<"#(false, true, true)\n">>, Output).

%% Appendix E.23: the program reads `input`, then what write gives it,
%% until closeInput; what is written after that is dropped, and the write
%% answers Left(Closed)
os_start_write_then_close_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "fn collect(p : Address(Os.ProgramMsg), got : Bytes) : Bytes with m =\n"
        "    match Os.read(p, 5000) {\n"
        "    Right(Os.Stdout(b)) -> collect(p, got <> b)\n"
        "  | _ -> got\n"
        "}\n"
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"cat\",\n"
        "    arguments = [], input = String.toUtf8(\"a\"))) {\n"
        "    Right(p) -> {\n"
        "        let taken = Os.write(p, String.toUtf8(\"b\"), 5000);\n"
        "        Os.closeInput(p);\n"
        "        let dropped = Os.write(p, String.toUtf8(\"c\"), 5000);\n"
        "        Io.println(Io.show(#(taken, dropped, String.fromUtf8(collect(p, <<>>)))))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"]),
    ?assertEqual(<<"#(Right(Unit), Left(Closed), Some(\"ab\"))\n">>, Output).

%% Appendix E.23, report §6.9: a running program is a process, which
%% `monitor` watches and `kill` stops, the program and its process group
%% with it; one that has answered its exit status has returned
os_program_is_a_process_test() ->
    Dir = ern_emitter_tests:scratch(),
    Pids = filename:join(Dir, "pids"),
    {ok, Output} = ern_emitter_tests:run(
        [
        "type Msg = Ended(Down)\n"
        "fn started(script : String) : Address(Os.ProgramMsg) with Msg =\n"
        "    match Os.start(Os.Command(program = \"sh\", arguments = [\"-c\", script],\n"
        "        input = <<>>)) {\n"
        "        Right(p) -> p\n"
        "      | Left(_) -> fault(\"not started\")\n"
        "    }\n"
        "fn reason() : String with Msg =\n"
        "    receive { Ended(Down(reason = r, site = _)) -> Io.show(r) }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let sleeper = started(\"tail -f /dev/null & echo $$ $! > ", Pids,
        "; echo written; wait\");\n"
        "    // the process numbers are written once the shell says so\n"
        "    let _ = Os.read(sleeper, 5000);\n"
        "    monitor(Process.fromAddress(sleeper), Ended);\n"
        "    kill(sleeper);\n"
        "    Io.println(reason());\n"
        "    let quick = started(\"exit 0\");\n"
        "    monitor(Process.fromAddress(quick), Ended);\n"
        "    let _ = Os.read(quick, 5000);\n"
        "    Io.println(reason())\n"
        "}\n"]),
    ?assertEqual(<<"Killed\nReturned\n">>, Output),
    {ok, Written} = file:read_file(Pids),
    [begin
         ?assertEqual(gone, gone(binary_to_list(Pid), 5000))
     end || Pid <- binary:split(Written, [<<" ">>, <<"\n">>], [global, trim_all])].

%% Appendix E.23, E.0 shape rule 8: a read whose milliseconds pass answers
%% Timeout and the program runs on, the next read taking what it wrote. A
%% regression test of the rule of 2026-10-01, before which the start's time
%% killed the program
os_read_time_limit_test() ->
    {ok, Output} = ern_emitter_tests:run(
        "export fn main() : Unit with Never = match Os.start(Os.Command(program = \"sh\",\n"
        "    arguments = [\"-c\", \"sleep 0.3; echo late\"], input = <<>>)) {\n"
        "    Right(p) -> {\n"
        "        Io.println(Io.show(Os.read(p, 50)));\n"
        "        Io.println(Io.show(Os.read(p, 5000)));\n"
        "        Io.println(Io.show(Os.read(p, 5000)))\n"
        "    }\n"
        "  | Left(e) -> Io.println(Io.show(e))\n"
        "}\n"),
    ?assertEqual(<<"Left(Timeout)\nRight(Stdout(<<108, 97, 116, 101, 10>>))\nRight(Exited(0))\n">>,
                 Output).

%% Appendix E.23, report §8.6: Os.exit ends the program with its status,
%% from any process, the output written before it flushed; a status
%% outside 0 to 255 faults the caller (§7.4)
os_exit_test() ->
    ?assertEqual({{exit, 3}, <<"bye\n">>},
                 ern_emitter_tests:run(
                     "export fn main() : Unit with Never = {\n"
                     "    Io.println(\"bye\");\n"
                     "    Os.exit(3)\n"
                     "}\n")),
    ?assertEqual({{exit, 5}, <<>>},
                 ern_emitter_tests:run(
                     "export fn main() : Unit with Unit = {\n"
                     "    let _ = spawn(fn() : Unit with Never = Os.exit(5));\n"
                     "    receive { _ -> Unit }\n"
                     "}\n")),
    ?assertEqual({{fault, <<"an exit status is from 0 to 255">>}, <<>>},
                 ern_emitter_tests:run("export fn main() : Unit with Never = Os.exit(256)\n")).

%% report §11.2: where Os.exit faults its caller, as in the shell and under
%% `ern test`, it ends only the process that calls it
os_exit_faults_where_asked_test() ->
    ?assertEqual({{fault, <<"exited with status 2">>}, <<>>},
                 ern_emitter_tests:run(
                     ['M'], "export fn main() : Unit with Never = Os.exit(2)\n",
                     #{exit => fault})).

%% Appendix E.23, report §11.2: Os.arguments is what the program was run
%% with, and the empty list where it was run with none
os_arguments_test() ->
    Main = "export fn main() : Unit with Never = Io.println(Io.show(Os.arguments))\n",
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
        "export fn main() : Unit with Never =\n"
        "    Io.println(Io.show(Fs.read(Path(\"a\\u{0}b\"), 1000)))\n"),
    ?assertEqual(<<"Left(Invalid)\n">>, Output).

%% Appendix E.17, §8.2: a name in a directory that is not UTF-8 makes
%% Fs.list answer NotUtf8 with its bytes; a regression test for the host's
%% warning printed in its place, and of the rule of 2026-10-01, before which
%% the name was left out
fs_list_names_a_name_not_utf8_test() ->
    Dir = ern_emitter_tests:scratch(),
    ok = file:write_file(<<(list_to_binary(Dir))/binary, "/caf", 16#e9>>, <<>>),
    ok = file:write_file(filename:join(Dir, "ok"), <<>>),
    {ok, Output} = ern_emitter_tests:run(
        ["export fn main() : Unit with Never = match Fs.list(Path(\"", Dir,
         "\"), 1000) {\n"
         "    Right(entries) -> Io.println(Io.show(List.map(entries,\n"
         "        fn(e) = Path.name(e.path))))\n"
         "  | Left(e) -> Io.println(Io.show(e))\n"
         "}\n"]),
    ?assertEqual(<<"NotUtf8(<<99, 97, 102, 233>>)\n">>, Output).

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
        "fn opener(port : Int, to : Address(Msg)) : Unit with Never =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> send(to, Opened(s))\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn keeper() : Unit with Int = receive { _ -> Unit }\n"
        "fn giver(port : Int, keep : Process, to : Address(Msg)) : Unit with Never =\n"
        "    match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "        Right(s) -> {\n"
        "            Tcp.give(s, keep);\n"
        "            send(to, Opened(s))\n"
        "        }\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "fn opened() : Address(Tcp.SocketMsg) with Msg = receive { Opened(s) -> s }\n"
        "fn ends(s : Address(Tcp.SocketMsg), ms : Int) : String with Msg = {\n"
        "    monitor(Process.fromAddress(s), Ended);\n"
        "    receive { Ended(_) -> \"ended\" | after ms -> \"alive\" }\n"
        "}\n"
        "fn check(port : Int) : Unit with Msg = {\n"
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
        "export fn main() : Unit with Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(listener) -> {\n"
        "        let _ = Either.map(Tcp.port(listener), check);\n"
        "        Tcp.closeListener(listener)\n"
        "    }\n"
        "  | Left(_) -> Unit\n"
        "}\n"),
    ?assertEqual(<<"opener's: ended\ngiven, giver gone: alive\ngiven, keeper gone: ended\n"
                   "given to the dead: ended\n">>, Output).

%% Appendix E.18, E.21, E.23: a listener, a socket and a running program are
%% processes of the program's: Process.live lists them, and Process.info
%% gives the function that opened each as its site. A regression test: the
%% runtime did not know them
opened_processes_are_live_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "fn site(p : Process) : String with m = match Process.info(p) {\n"
        "    Some(Process.Info(site = s, queued = _, activity = _)) -> s\n"
        "  | None -> \"none\"\n"
        "}\n"
        "fn listed(p : Process) : Bool with m = List.any(Process.live(), fn(q) = q == p)\n"
        "export fn main() : Unit with Never = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> match Tcp.connect(\"127.0.0.1\", port, 1000) {\n"
        "            Right(c) -> {\n"
        "                let pl = Process.fromAddress(l);\n"
        "                let pc = Process.fromAddress(c);\n"
        "                Io.println(Io.show(#(site(pl), site(pc), listed(pl), listed(pc))));\n"
        "                match Os.start(Os.Command(program = \"cat\", arguments = [],"
        " input = <<>>)) {\n"
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

%% Appendix E.18: a write answers Right(Unit) once the socket has taken the
%% bytes, and Left(Closed) once the connection has closed; the far end's
%% close is learned here by a read, so that the answer does not depend on
%% when the host reports it
tcp_write_answers_closed_test() ->
    {ok, Output} = ern_emitter_tests:run(
        [
        "export fn main() : Unit with Never = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let _ = spawn(fn() : Unit with Never = match Tcp.accept(l, 5000) {\n"
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
    ?assertEqual(<<"#(Right(Unit), Left(Closed), Left(Closed))\n">>, Output).

%%
%% Report §8.2, Appendix E.18, E.23: a write returns once its stream has
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
         "fn writes(write : (Bytes) -> Either(Io.Error, Unit) with Never, n : Int)"
         " : Unit with Never =\n"
         "    if n == 0 then Unit else { let _ = write(chunk()); writes(write, n - 1) }\n"
         "fn done() : Bool with Msg =\n"
         "    receive { Done -> true | after 0 -> false }\n"]).

%% Appendix E.23: a program that stops reading its input, since no one
%% reads its output, holds its writer, and a write after its end faults
os_write_waits_test() ->
    {ok, Output} = paced(
        "fn drain(p : Address(Os.ProgramMsg), n : Int) : Int with Msg = match Os.read(p, 5000) {\n"
        "    Right(Os.Stdout(b)) -> drain(p, n + Bytes.size(b))\n"
        "  | _ -> n\n"
        "}\n"
        "fn written() : Address(Os.ProgramMsg) with Msg =\n"
        "    match Os.start(Os.Command(program = \"cat\", arguments = [], input = <<>>)) {\n"
        "        Right(p) -> {\n"
        "            let me = self();\n"
        "            let _ = spawn(fn() : Unit with Never = {\n"
        "                writes(fn(b) = Os.write(p, b, 30000), 64);\n"
        "                Os.closeInput(p);\n"
        "                send(me, Done)\n"
        "            });\n"
        "            p\n"
        "        }\n"
        "      | Left(e) -> fault(Io.show(e))\n"
        "    }\n"
        "export fn main() : Unit with Msg = {\n"
        "    let before = Clock.monotonic();\n"
        "    let _ = drain(written(), 0);\n"
        "    receive { Done -> Unit };\n"
        "    let took = Clock.monotonic() - before;\n"
        "    let p = written();\n"
        "    receive { after 2 * (took + 1) -> Unit };\n"
        "    let early = done();\n"
        "    let n = drain(p, 0);\n"
        "    receive { Done -> Unit };\n"
        "    Io.println(Io.show(#(early, n)));\n"
        "    let late = fn() : Unit with Never = {\n"
        "        let _ = Os.write(p, <<1>>, 5000);\n"
        "        Unit\n"
        "    };\n"
        "    let _ = spawnMonitored(late, Ended);\n"
        "    receive { Ended(Down(reason = r, site = _)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertMatch({match, _}, re:run(Output, "^#\\(false, 4194304\\)\nFault\\(\"callee (had ended|"
                                            "returned without answering)\"\\)\n$")).

%% Appendix E.18: a socket whose far end does not read holds its writer,
%% and a write to a socket that has been closed faults
tcp_write_waits_test() ->
    {ok, Output} = paced(
        "fn drain(s : Address(Tcp.SocketMsg), n : Int) : Int with Msg =\n"
        "    if n >= 4194304 then n\n"
        "    else match Tcp.read(s, 5000) {\n"
        "        Right(b) -> drain(s, n + Bytes.size(b))\n"
        "      | Left(_) -> n\n"
        "    }\n"
        "fn written(l : Address(Tcp.ListenerMsg),\n"
        "           port : Int) : Address(Tcp.SocketMsg) with Msg = {\n"
        "    let me = self();\n"
        "    let _ = spawn(fn() : Unit with Never = match\n"
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
        "export fn main() : Unit with Msg = match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "    Right(l) -> match Tcp.port(l) {\n"
        "        Right(port) -> {\n"
        "            let before = Clock.monotonic();\n"
        "            let timed = written(l, port);\n"
        "            let _ = drain(timed, 0);\n"
        "            receive { Done -> Unit };\n"
        "            let took = Clock.monotonic() - before;\n"
        "            Tcp.close(timed);\n"
        "            let s = written(l, port);\n"
        "            receive { after 2 * (took + 1) -> Unit };\n"
        "            let early = done();\n"
        "            let n = drain(s, 0);\n"
        "            receive { Done -> Unit };\n"
        "            // the socket's process ends as it closes\n"
        "            monitor(Process.fromAddress(s), Gone);\n"
        "            Tcp.close(s);\n"
        "            receive { Gone(_) -> Unit };\n"
        "            Io.println(Io.show(#(early, n)));\n"
        "            let late = fn() : Unit with Never = {\n"
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
