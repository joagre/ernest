%% Appendix E.28: the Code module's three primitives, run as `ern run`
%% runs a program in this node: Code.load's loads, its refusals and its
%% undone evaluation (ern_code_load), Code.hashes (ern_code:hashes/1), and
%% Code.running over the processes of a run (ern_code:running/1). A
%% regression test, written after the code; Code.load past a count of the
%% host's is not tested, since no test may near the host's limits, and the
%% loads on nodes, a bare node's among them, are ern_nodes_tests'.
-module(ern_code_load_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("checker/include/ern_canonical.hrl").

%%
%% Helpers
%%

%% A fresh directory under the run's own (erl/app.mk).
tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_code_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

write(Dir, Relative, Text) ->
    Path = filename:join(Dir, Relative),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Text),
    Path.

%% A module built under the source root Root.
built(Root, Relative) ->
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Root,
                                 filename:join(Root, Relative)])).

%% What a run of the program at File printed, its lines; the run's status
%% is 0. Options come before the file on the command line.
ran(File) ->
    ran(File, []).

ran(File, Options) ->
    Before = byte_size(captured_output()),
    ?assertEqual(0, ern_cli:ern(["run"] ++ Options ++ [File])),
    Output = binary:part(captured_output(), Before, byte_size(captured_output()) - Before),
    binary:split(Output, <<"\n">>, [global, trim]).

%% EUnit's captured output, asked of the test's group leader, as
%% ern_cli_tests asks it.
captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> iolist_to_binary(Output) end.

%% A compiled module with its interface chunk changed by Change, as
%% ern_cli_tests forges one.
forge(Beam, Change) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    Rewritten = [case Id of
                     "ErnI" -> {Id, term_to_binary(Change(binary_to_term(Chunk)))};
                     _ -> {Id, Chunk}
                 end || {Id, Chunk} <- Chunks],
    {ok, Forged} = beam_lib:build_module(Rewritten),
    Forged.

%%
%% Code.load, Appendix E.28
%%

%% A library of three modules: Util, which Greet uses, and Bad, whose
%% binding spawns a process and then faults.
library(Dir) ->
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/util.ern",
          "export let greeting : String = \"hello\"\n\n"
          "export fn shout(text : String) : String =\n"
          "    text <> \"!\"\n"),
    write(Lib, "plug/greet.ern",
          "let started : Unit = Io.println(\"Greet's bindings evaluated\")\n\n"
          "export fn greet(name : String) : Unit =\n"
          "    Io.println(Plug.Util.shout(Plug.Util.greeting <> \" \" <> name))\n"),
    write(Lib, "plug/bad.ern",
          "let worker : Address(Int) =\n"
          "    spawn(fn() : Unit receiving Int = receive {\n"
          "        n -> Io.println(Int.toString(n))\n"
          "    })\n\n"
          "let broken : Int = 1 / List.size([])\n"),
    built(Lib, "plug/util.ern"),
    built(Lib, "plug/greet.ern"),
    built(Lib, "plug/bad.ern"),
    Lib.

%% Appendix E.28, report §8.5, §11.2: a module loads with its reach from
%% its own root, its bindings evaluated once, in the calling process; a
%% load of what the node holds evaluates nothing again; a binding that
%% faults answers its fault as §8.5 reports it, every process the
%% evaluation started killed and nothing loaded, so that the same load
%% faults again; a path with no file and a module of the reach the load
%% path lacks answer NotFound, and a file that is no `.erc` Invalid. The
%% unit the refused load brought stays loaded, out of reach, and the load
%% refused again makes no unit: a regression test of that, written after
%% the code, which deleted and purged the unit
load_test() ->
    Dir = tmp(),
    Lib = library(Dir),
    write(Dir, "lone/plug/greet.erc", element(2, file:read_file(filename:join(Lib,
                                                                         "plug/greet.erc")))),
    Main = write(Dir, "main.ern",
                 "fn shown(path : String) : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(path))))\n\n"
                 "export fn main() : Unit = {\n"
                 "    shown(\"" ++ Lib ++ "/plug/greet.erc\");\n"
                 "    shown(\"" ++ Lib ++ "/plug/greet.erc\");\n"
                 "    shown(\"" ++ Lib ++ "/plug/bad.erc\");\n"
                 "    Io.println(Int.toString(List.size(Process.live())));\n"
                 "    shown(\"" ++ Lib ++ "/plug/bad.erc\");\n"
                 "    shown(\"" ++ Lib ++ "/plug/none.erc\");\n"
                 "    shown(\"" ++ Dir ++ "/lone/plug/greet.erc\");\n"
                 "    shown(\"" ++ Dir ++ "/main.ern\")\n"
                 "}\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Greet's bindings evaluated">>,
                  <<"Right(Unit)">>,
                  <<"Right(Unit)">>,
                  <<"Left(Other(\"Plug.Bad.broken:6 faulted: division by zero\"))">>,
                  <<"1">>,
                  <<"Left(Other(\"Plug.Bad.broken:6 faulted: division by zero\"))">>,
                  <<"Left(NotFound)">>,
                  <<"Left(NotFound)">>,
                  <<"Left(Invalid)">>],
                 ran(filename:rootname(Main) ++ ".erc")),
    %% report §11.2, Appendix E.28: the faulting load's unit stays, and the
    %% load refused again made no other
    ?assert(erlang:module_loaded('ern@plug@bad')),
    ?assertNot(erlang:module_loaded('ern@plug@bad$2')).

%% Appendix E.28, report §8.6: a binding a load evaluates that waits on
%% what nothing will send is a deadlock, which faults the load's evaluator
%% in the caller's place and refuses the load, the process the binding
%% spawned killed with it, so that the program goes on with the entry
%% process alone, since the load marks its caller inside foreign code only
%% while it reads, places and loads. A regression test, written after the
%% code: the whole load was marked, the evaluation among it, so the look
%% never saw the wait and the program waited for ever; then the deadlock
%% faulted the caller, before the evaluator; it does not cover a load on a
%% node, where the look seeks no deadlock (§8.6)
load_deadlock_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/stuck.ern",
          "type Msg = Ask(Reply(Int))\n\n"
          "fn silent() : Unit receiving Msg =\n"
          "    receive {\n"
          "        Ask(_) -> silent()\n"
          "    }\n\n"
          "let stuck : Int = Address.callForever(spawn(silent), Ask)\n"),
    built(Lib, "plug/stuck.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/stuck.erc\"))));\n"
                 "    Io.println(Int.toString(List.size(Process.live())))\n"
                 "}\n"),
    built(Dir, "main.ern"),
    Self = self(),
    Device = spawn(fun() -> said(Self, []) end),
    Before = byte_size(captured_output()),
    ?assertEqual(0, ern_cli:ern(["run", filename:rootname(Main) ++ ".erc"], Device)),
    Output = binary:part(captured_output(), Before, byte_size(captured_output()) - Before),
    Device ! {done, self()},
    Said = receive {said, Text} -> unicode:characters_to_binary(Text) end,
    ?assertEqual(<<"Left(Other(\"Plug.Stuck.stuck:8 faulted: deadlock\"))\n1\n">>, Output),
    %% report §8.6, Appendix E.28: the load's answer is the fault's one report
    ?assertEqual(<<>>, Said).

%% Appendix E.28, report §6.5, §6.9: a load whose caller ends while it
%% waits for the evaluator ends as where a binding faults: the evaluator
%% and every process the evaluation started killed and nothing loaded, so
%% that the same load evaluates the bindings again. The binding kills its
%% caller, and then a process its caller monitors through a wrap that
%% faults, and holds the evaluation for ever. A regression test, written
%% after the code: the evaluator and what it started ran on past a killed
%% caller, and the program deadlocked waiting for them; a restart asked for
%% at the wait is load_caller_restarts_test's
load_caller_ends_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/cut.ern",
          "type Watch = Ask(Reply(Unit))\n\n"
          "let started : Unit = Io.println(\"Cut's bindings evaluated\")\n\n"
          "let worker : Address(Int) =\n"
          "    spawn(fn() : Unit receiving Int = receive {\n"
          "        n -> Io.println(Int.toString(n))\n"
          "    })\n\n"
          "fn silent() : Unit receiving Watch =\n"
          "    receive {\n"
          "        Ask(_) -> silent()\n"
          "    }\n\n"
          "fn isTarget(process : Process) : Bool =\n"
          "    match Process.status(process) {\n"
          "        Some(status) -> status.site == \"Main.main:13\""
          " || status.site == \"Main.main:18\"\n"
          "      | None -> false\n"
          "    }\n\n"
          "let cut : Unit =\n"
          "    match List.filter(Process.live(), isTarget) {\n"
          "        [] -> Unit\n"
          "      | targets -> {\n"
          "            List.forEach(targets, Process.kill);\n"
          "            Address.callForever(spawn(silent), Ask)\n"
          "        }\n"
          "    }\n"),
    built(Lib, "plug/cut.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Ended(Down)\n\n"
                 "fn shown() : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/cut.erc\"))))\n\n"
                 "fn isLoads(process : Process) : Bool =\n"
                 "    match Process.status(process) {\n"
                 "        Some(status) -> String.startsWith(status.site, \"Plug.Cut.\")\n"
                 "      | None -> false\n"
                 "    }\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    let _ = spawnMonitored(fn() = shown(), Ended);\n"
                 "    ended();\n"
                 "    undone();\n"
                 "    let _ = spawnMonitored(\n"
                 "        fn() = {\n"
                 "            let watched : Address(Int) ="
                 " spawn(fn() : Unit receiving Int = receive { _ -> Unit });\n"
                 "            monitor(Process.fromAddress(watched),"
                 " fn(_) = fault(\"the watched process ended\"));\n"
                 "            shown()\n"
                 "        },\n"
                 "        Ended\n"
                 "    );\n"
                 "    ended();\n"
                 "    undone();\n"
                 "    shown()\n"
                 "}\n\n"
                 "fn ended() : Unit receiving Msg =\n"
                 "    receive {\n"
                 "        Ended(down) -> Io.println(Io.show(down.reason))\n"
                 "    }\n\n"
                 "fn undone() : Unit receiving Msg = {\n"
                 "    let started = List.filter(Process.live(), isLoads);\n"
                 "    List.forEach(started, fn(process) = monitor(process, Ended));\n"
                 "    awaited(List.size(started));\n"
                 "    Io.println(Int.toString(List.size(Process.live())))\n"
                 "}\n\n"
                 "fn awaited(count : Int) : Unit receiving Msg =\n"
                 "    if count == 0 then Unit"
                 " else receive { Ended(_) -> awaited(count - 1) }\n"),
    built(Dir, "main.ern"),
    Self = self(),
    Device = spawn(fun() -> said(Self, []) end),
    Before = byte_size(captured_output()),
    ?assertEqual(0, ern_cli:ern(["run", filename:rootname(Main) ++ ".erc"], Device)),
    Output = binary:part(captured_output(), Before, byte_size(captured_output()) - Before),
    Device ! {done, self()},
    Said = receive {said, Text} -> unicode:characters_to_binary(Text) end,
    ?assertEqual([<<"Cut's bindings evaluated">>,
                  <<"Killed">>,
                  <<"1">>,
                  <<"Cut's bindings evaluated">>,
                  <<"Fault(\"the watched process ended\")">>,
                  <<"1">>,
                  <<"Cut's bindings evaluated">>,
                  <<"Right(Unit)">>],
                 binary:split(Output, <<"\n">>, [global, trim])),
    ?assertMatch({_, _}, binary:match(Said, <<"Main.main:16 faulted: the watched process"
                                              " ended\n">>)).

%% Appendix E.28, report §6.9, Appendix E.22: a load whose caller is asked
%% to restart while it waits for the evaluator ends as where a binding
%% faults, the evaluator and every process the evaluation started killed
%% and nothing loaded, and the caller runs its function again. Its next
%% run waits for the processes the evaluation started to end, which the
%% undoing alone ends, and loads again, the bindings evaluated anew; the
%% settler hands the restart on only once the reaper has told it of the
%% evaluator's end.
%%
%% The caller is a child of a OneForAll group. The load's binding kills
%% the process main watches and holds the evaluation for ever; main then
%% asks the other child to fault, and the group asks the loading child to
%% restart, which it does at once, since it waits (§6.9). A regression
%% test, written after the code (the log's *The Release Review Before
%% 0.7.0*, *The round*); not covered: a restart asked for by a supervisor
%% that is itself a child, and one a service monitor's wrap holds up
load_caller_restarts_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/hold.ern",
          "type Watch = Ask(Reply(Unit))\n\n"
          "let started : Unit = Io.println(\"Hold's bindings evaluated\")\n\n"
          "let worker : Address(Int) =\n"
          "    spawn(fn() : Unit receiving Int = receive {\n"
          "        n -> Io.println(Int.toString(n))\n"
          "    })\n\n"
          "fn silent() : Unit receiving Watch =\n"
          "    receive {\n"
          "        Ask(_) -> silent()\n"
          "    }\n\n"
          "fn isSignal(process : Process) : Bool =\n"
          "    match Process.status(process) {\n"
          "        Some(status) -> status.site == \"Main.main:23\"\n"
          "      | None -> false\n"
          "    }\n\n"
          "let held : Unit =\n"
          "    match List.filter(Process.live(), isSignal) {\n"
          "        [] -> Unit\n"
          "      | signals -> {\n"
          "            List.forEach(signals, Process.kill);\n"
          "            Address.callForever(spawn(silent), Ask)\n"
          "        }\n"
          "    }\n"),
    built(Lib, "plug/hold.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Ended(Down) | Loaded\n\n"
                 "type FailMsg = Fail\n\n"
                 "fn isLoads(process : Process) : Bool =\n"
                 "    match Process.status(process) {\n"
                 "        Some(status) -> String.startsWith(status.site, \"Plug.Hold.\")\n"
                 "      | None -> false\n"
                 "    }\n\n"
                 "fn loading(entry : Address(Msg)) : Unit receiving Msg = {\n"
                 "    undone();\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/hold.erc\"))));\n"
                 "    send(entry, Loaded)\n"
                 "}\n\n"
                 "fn faulting() : Unit receiving FailMsg =\n"
                 "    receive {\n"
                 "        Fail -> fault(\"asked to fault\")\n"
                 "    }\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    let signal : Address(Int) ="
                 " spawn(fn() : Unit receiving Int = receive { _ -> Unit });\n"
                 "    monitor(Process.fromAddress(signal), Ended);\n"
                 "    let limit = RestartLimit(restarts = 3, within = 10000);\n"
                 "    let group = spawn(Supervisor.group(Supervisor.OneForAll, limit));\n"
                 "    let entry = self();\n"
                 "    let faulter = spawn(Supervisor.child(group, faulting));\n"
                 "    let _ = spawn(Supervisor.child(group, fn() = loading(entry)));\n"
                 "    receive {\n"
                 "        Ended(_) -> send(faulter, Fail)\n"
                 "    };\n"
                 "    receive {\n"
                 "        Loaded -> Unit\n"
                 "    }\n"
                 "}\n\n"
                 "fn undone() : Unit receiving Msg = {\n"
                 "    let started = List.filter(Process.live(), isLoads);\n"
                 "    List.forEach(started, fn(process) = monitor(process, Ended));\n"
                 "    awaited(List.size(started));\n"
                 "    Io.println(Int.toString(List.size(List.filter(Process.live(), isLoads))))\n"
                 "}\n\n"
                 "fn awaited(count : Int) : Unit receiving Msg =\n"
                 "    if count == 0 then Unit"
                 " else receive { Ended(_) -> awaited(count - 1) }\n"),
    built(Dir, "main.ern"),
    Self = self(),
    Device = spawn(fun() -> said(Self, []) end),
    Before = byte_size(captured_output()),
    ?assertEqual(0, ern_cli:ern(["run", filename:rootname(Main) ++ ".erc"], Device)),
    Output = binary:part(captured_output(), Before, byte_size(captured_output()) - Before),
    Device ! {done, self()},
    Said = receive {said, Text} -> unicode:characters_to_binary(Text) end,
    ?assertEqual([<<"0">>,
                  <<"Hold's bindings evaluated">>,
                  <<"0">>,
                  <<"Hold's bindings evaluated">>,
                  <<"Right(Unit)">>],
                 binary:split(Output, <<"\n">>, [global, trim])),
    %% report §6.9: the other child's fault is reported, and the restart
    %% asked for is not
    ?assertEqual(<<"Main.main:28 faulted, restarted: asked to fault\n    Main.faulting:19\n">>,
                 Said).

%% Appendix E.28, report §8.5, §8.6, §6.8: a load evaluates in an evaluator
%% of its own while the caller waits, so a binding that calls a function
%% generic in its mailbox type takes none of the caller's messages: it
%% waits at `Never` for one that cannot come, a deadlock, which faults the
%% evaluator in the caller's place and refuses the load, and the caller
%% then receives the message it sent itself. A regression test, the
%% readers' program (the log's *The Argument's Four Decisions*): the
%% binding ran in the caller, took its `Hello(41)` and faulted on it, and
%% the caller waited for ever
load_takes_no_message_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "grab.ern",
          "fn take() = receive { x -> x }\n\n"
          "export let shown : String = Io.show(take())\n"),
    built(Lib, "grab.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Hello(Int)\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    send(self(), Hello(41));\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/grab.erc\"))));\n"
                 "    receive {\n"
                 "        Hello(n) -> Io.println(Int.toString(n))\n"
                 "    }\n"
                 "}\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Other(\"Grab.shown:3 faulted: deadlock\"))">>, <<"41">>],
                 ran(filename:rootname(Main) ++ ".erc")).

%% Appendix E.28, E.18, E.21: the evaluator lives on after the load and
%% owns what a binding opened, a listener here, which stays open after the
%% load has answered and closes when the evaluator is killed; `self()` in
%% the binding is the evaluator's address, and `Process.live()` leaves the
%% evaluator out, the runtime's own, listing the program's processes and
%% the listener. Written with the code
load_evaluator_lives_on_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/registry.ern",
          "export type Msg =\n"
          "    Opened(listener : Address(Tcp.ListenerMsg), evaluator : Address(Never))\n"
          "  | Get(Reply(#(Address(Tcp.ListenerMsg), Address(Never))))\n\n"
          "fn waiting() : Unit receiving Msg =\n"
          "    receive {\n"
          "        Opened(=listener, =evaluator) ->"
          " holding(listener, evaluator)\n"
          "    }\n\n"
          "fn holding(listener : Address(Tcp.ListenerMsg), evaluator : Address(Never)) : Unit\n"
          "    receiving Msg =\n"
          "    receive {\n"
          "        Get(reply) -> {\n"
          "            answer(reply, #(listener, evaluator));\n"
          "            holding(listener, evaluator)\n"
          "        }\n"
          "    }\n\n"
          "export let holder : Address(Msg) = spawn(waiting)\n"),
    write(Lib, "plug/opener.ern",
          "let opened : Unit =\n"
          "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
          "        Right(listener) -> send(Plug.Registry.holder,"
          " Plug.Registry.Opened(=listener, evaluator = self()))\n"
          "      | Left(_) -> Unit\n"
          "    }\n"),
    built(Lib, "plug/registry.ern"),
    built(Lib, "plug/opener.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Closed(Down)\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/opener.erc\"))));\n"
                 "    match Address.callForever(Plug.Registry.holder, Plug.Registry.Get) {\n"
                 "        #(listener, evaluator) -> {\n"
                 "            let open = Process.status(Process.fromAddress(listener));\n"
                 "            Io.println(Io.show(Optional.isSome(open)));\n"
                 "            Io.println(Int.toString(List.size(Process.live())));\n"
                 "            monitor(Process.fromAddress(listener), Closed);\n"
                 "            kill(evaluator);\n"
                 "            receive {\n"
                 "                Closed(_) -> Io.println(\"closed\")\n"
                 "            }\n"
                 "        }\n"
                 "    }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--load-path", Lib, Main])),
    ?assertEqual([<<"Right(Unit)">>, <<"true">>, <<"3">>, <<"closed">>],
                 ran(filename:rootname(Main) ++ ".erc", ["--load-path", Lib])).

%% Appendix E.28, report §6.9: a load whose bindings open nothing leaves no
%% process: its evaluator, which a binding hands a process of the program,
%% has ended once the load answers, so a monitor made then gives the
%% reason `Unknown`. A regression test, written after the code: the
%% evaluator lived on, and the monitor's wait was a deadlock (the log's
%% *Sites, Sessions and Their Names*)
load_evaluator_ends_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/registry.ern",
          "export type Msg = Told(Process) | Get(Reply(Process))\n\n"
          "fn waiting() : Unit receiving Msg =\n"
          "    receive {\n"
          "        Told(process) -> holding(process)\n"
          "    }\n\n"
          "fn holding(process : Process) : Unit receiving Msg =\n"
          "    receive {\n"
          "        Get(reply) -> {\n"
          "            answer(reply, process);\n"
          "            holding(process)\n"
          "        }\n"
          "    }\n\n"
          "export let holder : Address(Msg) = spawn(waiting)\n"),
    write(Lib, "plug/teller.ern",
          "let told : Unit = send(Plug.Registry.holder, Plug.Registry.Told(Process.current()))\n"),
    built(Lib, "plug/registry.ern"),
    built(Lib, "plug/teller.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Gone(Down)\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/teller.erc\"))));\n"
                 "    let evaluator =\n"
                 "        Address.callForever(Plug.Registry.holder, Plug.Registry.Get);\n"
                 "    monitor(evaluator, Gone);\n"
                 "    receive {\n"
                 "        Gone(down) -> Io.println(Io.show(down.reason))\n"
                 "    }\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--load-path", Lib, Main])),
    ?assertEqual([<<"Right(Unit)">>, <<"Unknown">>],
                 ran(filename:rootname(Main) ++ ".erc", ["--load-path", Lib])).

%% What a job wrote on its error device, an I/O server of its own, for
%% Owner, once told it is done.
said(Owner, Acc) ->
    receive
        {io_request, From, ReplyAs, {put_chars, Encoding, Chars}} ->
            From ! {io_reply, ReplyAs, ok},
            said(Owner, [unicode:characters_to_list(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, {put_chars, Encoding, Module, Function, Arguments}} ->
            From ! {io_reply, ReplyAs, ok},
            Chars = apply(Module, Function, Arguments),
            said(Owner, [unicode:characters_to_list(Chars, Encoding) | Acc]);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, enotsup}},
            said(Owner, Acc);
        {done, Owner} ->
            Owner ! {said, lists:append(lists:reverse(Acc))}
    end.

%% Appendix E.28, report §3.1, §7.4, §8.5: a binding that meets the float
%% fault in a load's evaluation answers it as §8.5 reports it, with the
%% binding's line, as the runtime reads it anywhere. A regression test,
%% written after the code (the log's *The Float chain*)
load_float_fault_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/floats.ern",
          "fn big() : Float = Float.max(1.0e300, 0.0)\n\n"
          "let broken : Float = big() * big()\n"),
    built(Lib, "plug/floats.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/floats.erc\"))))\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Other(\"Plug.Floats.broken:3 faulted: float arithmetic error\"))">>],
                 ran(filename:rootname(Main) ++ ".erc")).

%% Appendix E.28, report §6.9, §11.2: a load whose binding faults while a
%% monitor's wrap of the module it brought still runs, in the runtime's own
%% process for the Down's delivery, is undone all the same: the process the
%% evaluation started is killed, the wrap's delivery to it ending with it
%% (§6.9), and nothing else ends, so the program goes on, a later
%% monitor's Down delivered and the load refused alike when asked again.
%% The unit the load brought stays loaded, out of reach (§11.2): a process
%% running before the load, the holder of a module the program uses, was
%% handed a function of it by a binding before the fault, and calls it
%% after; refused again, the module makes no unit.
%%
%% A regression test, written after the code: the delivery's process was
%% linked to the runtime's reaper, which did not trap exits, so the purge
%% of the unit ended the reaper with it, and the program waited for ever at
%% its next monitor; once the reaper trapped exits, the purge left the
%% holder a function whose code was gone, which faulted at its call
load_under_a_running_wrap_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/hold.ern",
          "export type Msg = Keep(() -> Int) | Run(Reply(Int))\n\n"
          "fn hold(kept : () -> Int) : Unit receiving Msg =\n"
          "    receive {\n"
          "        Keep(given) -> hold(given)\n"
          "      | Run(reply) -> {\n"
          "            answer(reply, kept());\n"
          "            hold(kept)\n"
          "        }\n"
          "    }\n\n"
          "export let holder : Address(Msg) = spawn(fn() : Unit receiving Msg = hold(fn() = 0))\n"),
    write(Lib, "plug/watch.ern",
          "type Msg = Spinning | Done(Int) | Ready(Reply(Unit))\n\n"
          "fn spin(count : Int) : Int = spin(count + 1)\n\n"
          "let watcher : Address(Msg) = spawn(fn() : Unit receiving Msg = {\n"
          "    let watching = self();\n"
          "    monitor(Process.fromAddress(spawn(fn() = Unit)), fn(_) = {\n"
          "        send(watching, Spinning);\n"
          "        Done(spin(0))\n"
          "    });\n"
          "    receive {\n"
          "        Spinning -> receive {\n"
          "            Ready(reply) -> answer(reply, Unit)\n"
          "        }\n"
          "    };\n"
          "    receive {\n"
          "        Done(_) -> Unit\n"
          "    }\n"
          "})\n\n"
          "let spinning : Unit = Address.callForever(watcher, fn(reply) = Ready(reply))\n\n"
          "let handed : Unit = send(Plug.Hold.holder, Plug.Hold.Keep(fn() = 42))\n\n"
          "let broken : Int = 1 / List.size([])\n"),
    built(Lib, "plug/hold.ern"),
    built(Lib, "plug/watch.ern"),
    Main = write(Dir, "main.ern",
                 "type Msg = Ended(Down)\n\n"
                 "fn shown(path : String) : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(path))))\n\n"
                 "fn called() : Unit =\n"
                 "    Io.println(Int.toString(Address.callForever(Plug.Hold.holder,"
                 " Plug.Hold.Run)))\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    shown(\"" ++ Lib ++ "/plug/watch.erc\");\n"
                 "    called();\n"
                 "    monitor(Process.fromAddress(spawn(fn() = Unit)), fn(down) = Ended(down));\n"
                 "    receive {\n"
                 "        Ended(_) -> Io.println(\"a later monitor told\")\n"
                 "    };\n"
                 "    shown(\"" ++ Lib ++ "/plug/watch.erc\");\n"
                 "    called()\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Dir, "--load-path", Lib, Main])),
    Refused = <<"Left(Other(\"Plug.Watch.broken:25 faulted: division by zero\"))">>,
    ?assertEqual([Refused, <<"42">>, <<"a later monitor told">>, Refused, <<"42">>],
                 ran(filename:rootname(Main) ++ ".erc", ["--load-path", Lib])),
    ?assert(erlang:module_loaded('ern@plug@watch')),
    ?assertNot(erlang:module_loaded('ern@plug@watch$2')).

%% Appendix E.28, report §6.9, §11.2: a process a monitor's wrap spawns,
%% where the monitor was made by a process the load's evaluation started,
%% is that process's, as if it had spawned it itself, and a refused load
%% kills it with that process, so that the program is left with the entry
%% process alone. A regression test, written after the code (finding D1):
%% the wrap's delivery had no row, so the process it spawned headed a chain
%% of its own and lived on
load_kills_what_a_wrap_spawned_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/helped.ern",
          "type Msg = Helped | Ready(Reply(Unit))\n\n"
          "let watcher : Address(Msg) = spawn(fn() : Unit receiving Msg = {\n"
          "    monitor(Process.fromAddress(spawn(fn() = Unit)), fn(_) = {\n"
          "        let _ = spawn(fn() : Unit receiving Int = receive {\n"
          "            n -> Io.println(Int.toString(n))\n"
          "        });\n"
          "        Helped\n"
          "    });\n"
          "    receive {\n"
          "        Helped -> receive {\n"
          "            Ready(reply) -> answer(reply, Unit)\n"
          "        }\n"
          "    };\n"
          "    receive {\n"
          "        Helped -> Unit\n"
          "    }\n"
          "})\n\n"
          "let helped : Unit = Address.callForever(watcher, fn(reply) = Ready(reply))\n\n"
          "let broken : Int = 1 / List.size([])\n"),
    built(Lib, "plug/helped.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/helped.erc\"))));\n"
                 "    Io.println(Int.toString(List.size(Process.live())))\n"
                 "}\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Other(\"Plug.Helped.broken:22 faulted: division by zero\"))">>,
                  <<"1">>],
                 ran(filename:rootname(Main) ++ ".erc")).

%% Appendix E.28, report §6.9: Code.load called in a monitor's wrap
%% evaluates the module's bindings in the wrap's delivery, as if the
%% process it delivers to had called it: a refusal names the binding that
%% faulted, and kills every process the evaluation started, so that the
%% program is left with the entry process alone. A regression test,
%% written after the code (finding D1): the delivery had no row to mark,
%% so the refusal killed nothing, and named no binding
load_in_a_wrap_test() ->
    Dir = tmp(),
    Lib = library(Dir),
    Main = write(Dir, "main.ern",
                 "type Msg = Loaded(Either(Io.Error, Unit))\n\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    monitor(Process.fromAddress(spawn(fn() = Unit)),\n"
                 "            fn(_) = Loaded(Code.load(Path(\"" ++ Lib ++ "/plug/bad.erc\"))));\n"
                 "    receive {\n"
                 "        Loaded(outcome) -> Io.println(Io.show(outcome))\n"
                 "    };\n"
                 "    Io.println(Int.toString(List.size(Process.live())))\n"
                 "}\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Other(\"Plug.Bad.broken:6 faulted: division by zero\"))">>, <<"1">>],
                 ran(filename:rootname(Main) ++ ".erc")).

%% Appendix E.28, report §11.2: a module compiled against another
%% interface of a module it uses than the load path holds is Invalid
other_interface_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/base.ern", "export fn one() : Int = 1\n"),
    write(Lib, "plug/user.ern", "export fn two() : Int = Plug.Base.one() + 1\n"),
    built(Lib, "plug/base.ern"),
    built(Lib, "plug/user.ern"),
    %% Base built again with another interface, User left as it was compiled
    write(Lib, "plug/base.ern", "export fn one() : Int = 1\n\nexport fn three() : Int = 3\n"),
    built(Lib, "plug/base.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/user.erc\"))))\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Invalid)">>], ran(filename:rootname(Main) ++ ".erc")).

%% Appendix E.28, report §11.1: a compiled form another build of `ern`
%% wrote is Invalid, the module loaded and a module it uses alike, and the
%% form this build wrote loads. Written with the code
another_build_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Lib, "plug/base.ern", "export fn one() : Int = 1\n"),
    write(Lib, "plug/user.ern", "export fn two() : Int = Plug.Base.one() + 1\n"),
    built(Lib, "plug/base.ern"),
    built(Lib, "plug/user.ern"),
    [Base, User] = [filename:join(Lib, Leaf) || Leaf <- ["plug/base.erc", "plug/user.erc"]],
    {ok, BaseBeam} = file:read_file(Base),
    {ok, UserBeam} = file:read_file(User),
    Another = fun(Chunk) -> Chunk#{compiler => <<?VERSION "+another">>} end,
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit =\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ User ++ "\"))))\n"),
    built(Dir, "main.ern"),
    Program = filename:rootname(Main) ++ ".erc",
    ok = file:write_file(User, forge(UserBeam, Another)),
    ?assertEqual([<<"Left(Invalid)">>], ran(Program)),
    ok = file:write_file(User, UserBeam),
    ok = file:write_file(Base, forge(BaseBeam, Another)),
    ?assertEqual([<<"Left(Invalid)">>], ran(Program)),
    ok = file:write_file(Base, BaseBeam),
    ?assertEqual([<<"Right(Unit)">>], ran(Program)).

%% Appendix E.28, report §4.1, §11.1: a module of a cycle through the load
%% path is Invalid, whichever of its modules is loaded: Plug.A uses Plug.B,
%% and B, compiled against an earlier A that used nothing, uses A. A
%% regression test, written after the fix: the load faulted its caller
%% with the host's badkey, placing B before the A it uses
load_path_cycle_test() ->
    Dir = tmp(),
    [Lib, App, Earlier] = [filename:join(Dir, Leaf) || Leaf <- ["lib", "app", "earlier"]],
    write(Lib, "plug/b.ern", "export fn twice(x : Int) : Int = x * 2\n"),
    built(Lib, "plug/b.ern"),
    A = write(App, "plug/a.ern", "export fn four() : Int = Plug.B.twice(2)\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", App, "--load-path", Lib, A])),
    write(Earlier, "plug/a.ern", "export fn four() : Int = 4\n"),
    built(Earlier, "plug/a.ern"),
    B = write(Lib, "plug/b.ern", "export fn twice(x : Int) : Int = x * 2\n\n"
                                 "export fn eight() : Int = Plug.A.four() * 2\n"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Lib, "--load-path", Earlier, B])),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ App ++ "/plug/a.erc\"))));\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/b.erc\"))))\n"
                 "}\n"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Left(Invalid)">>, <<"Left(Invalid)">>],
                 ran(filename:rootname(Main) ++ ".erc", ["--load-path", Lib, "--load-path", App])).

%% Appendix E.28, report §11.2: a module the node holds other code of
%% loads beside it, a unit of a name of its own made from its forms, and
%% what the node ran before keeps running the code it had; loaded again,
%% it makes no unit
beside_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    write(Dir, "plug/word.ern", "export fn word() : String = \"first\"\n"),
    write(Lib, "plug/word.ern", "export fn word() : String = \"second\"\n"),
    built(Lib, "plug/word.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/word.erc\"))));\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/word.erc\"))));\n"
                 "    Io.println(Plug.Word.word())\n"
                 "}\n"),
    built(Dir, "plug/word.ern"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"Right(Unit)">>, <<"Right(Unit)">>, <<"first">>],
                 ran(filename:rootname(Main) ++ ".erc")),
    ?assert(erlang:module_loaded('ern@plug@word$2')),
    ?assertNot(erlang:module_loaded('ern@plug@word$3')).

%% Appendix E.28, report §11.1, §11.2: a module whose binding's initializer
%% is a ground term, loaded beside another of its name as a unit made from
%% its forms, reads its binding's value, and so does a module of the load
%% that uses it, made from its forms too and linked through the interface
%% of the first, which holds the value; the program's own module of the
%% name reads its own. Written after the code, so a regression test; it
%% does not tell a read compiled to the value from one through the getter,
%% which ern_cli_tests' ground_binding_test and ern_exchange_tests do
load_ground_test() ->
    Dir = tmp(),
    Lib = filename:join(Dir, "lib"),
    Word = fun(Limit, Said) ->
                   ["export let limit = ", Limit, "\n\n"
                    "let said : Unit = Io.println(\"", Said, " \" <> Int.toString(limit))\n\n"
                    "export fn word() : String = \"", Said, "\"\n"]
           end,
    write(Dir, "plug/word.ern", Word("3", "first")),
    write(Lib, "plug/word.ern", Word("7", "second")),
    write(Lib, "plug/user.ern",
          "let told : Unit = Io.println(\"user \" <> Int.toString(Plug.Word.limit * 2))\n"),
    built(Lib, "plug/word.ern"),
    built(Lib, "plug/user.ern"),
    Main = write(Dir, "main.ern",
                 "export fn main() : Unit = {\n"
                 "    Io.println(Io.show(Code.load(Path(\"" ++ Lib ++ "/plug/user.erc\"))));\n"
                 "    Io.println(Plug.Word.word())\n"
                 "}\n"),
    built(Dir, "plug/word.ern"),
    built(Dir, "main.ern"),
    ?assertEqual([<<"first 3">>, <<"second 7">>, <<"user 14">>, <<"Right(Unit)">>, <<"first">>],
                 ran(filename:rootname(Main) ++ ".erc")),
    ?assert(erlang:module_loaded('ern@plug@word$2')).

%%
%% Code.hashes, Appendix E.28
%%

%% Appendix E.28, Appendix H: each definition the `.erc` records, its
%% qualified name and its hash in lowercase hexadecimal, in the module's
%% order, a foreign declaration left out; NotFound for a path with no file
%% and Invalid for a file that is no `.erc`
hashes_test() ->
    Dir = tmp(),
    File = write(Dir, "plug/shapes.ern",
                 "export type Shape = Dot | Box(Int)\n\n"
                 "foreign fn absolute(n : Int) : Int = \"erlang:abs/1\"\n\n"
                 "export fn size(shape : Shape) : Int =\n"
                 "    match shape {\n"
                 "        Dot -> 0\n"
                 "      | Box(side) -> absolute(side)\n"
                 "    }\n\n"
                 "export let one : Shape = Box(1)\n"),
    built(Dir, "plug/shapes.ern"),
    Erc = filename:rootname(File) ++ ".erc",
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(element(2,
                                                                         file:read_file(Erc))),
    Expected = [{unicode:characters_to_binary(ern_namespace:text(QualifiedName)),
                 binary:encode_hex(Hash, lowercase)}
                || #definition{qualified_name = QualifiedName, hash = Hash} <- Definitions],
    ?assertEqual([<<"Plug.Shapes.Shape">>, <<"Plug.Shapes.size">>, <<"Plug.Shapes.one">>],
                 [Name || {Name, _} <- Expected]),
    ?assertEqual({'Right', Expected}, ern_code:hashes({'Path', list_to_binary(Erc)})),
    ?assertEqual({'Left', 'NotFound'},
                 ern_code:hashes({'Path', list_to_binary(filename:join(Dir, "none.erc"))})),
    ?assertEqual({'Left', 'Invalid'}, ern_code:hashes({'Path', list_to_binary(File)})).

%%
%% Code.running, Appendix E.28
%%

%% Appendix E.28, report §3.11, §6.10: the processes whose stack holds a
%% frame of the declaration named: a process waiting in it, one whose
%% frame of it lies beneath thirty-two frames of others, and the caller
%% itself, but not a process a lambda written in it started; a process
%% moved off it by its own message, and ended, is listed no more. Two
%% declarations whose forms are one term are one definition (Appendix H),
%% so idle differs from waiter
running_test() ->
    Dir = tmp(),
    Main = write(Dir, "main.ern", running_program()),
    built(Dir, "main.ern"),
    ?assertEqual([<<"waiter 1">>, <<"bottom 1">>, <<"spawner 1">>, <<"main 1">>,
                  <<"moved 1">>, <<"waiter 0">>],
                 ran(filename:rootname(Main) ++ ".erc")).

running_program() ->
    "type Msg = Ping(reply : Reply(Unit)) | Stop | Upgrade(next : () -> Unit receiving Msg)\n\n"
    "fn waiter() : Unit receiving Msg =\n"
    "    receive {\n"
    "        Ping(=reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            waiter()\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "      | Upgrade(=next) -> next()\n"
    "    }\n\n"
    "fn idle() : Unit receiving Msg =\n"
    "    receive {\n"
    "        Ping(=reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            idle()\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "      | Upgrade(next = _) -> idle()\n"
    "    }\n\n"
    "fn bottom() : Unit receiving Msg = {\n"
    "    let _ = climb(30);\n"
    "    Unit\n"
    "}\n\n"
    "fn climb(n : Int) : Int receiving Msg =\n"
    "    if n == 0 then {\n"
    "        idle();\n"
    "        0\n"
    "    } else 1 + descend(n - 1)\n\n"
    "fn descend(n : Int) : Int receiving Msg =\n"
    "    if n == 0 then {\n"
    "        idle();\n"
    "        0\n"
    "    } else 1 + climb(n - 1)\n\n"
    "fn spawner() : Unit receiving Msg = {\n"
    "    let _ = spawn(fn() : Unit receiving Msg = idle());\n"
    "    receive {\n"
    "        Ping(=reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            receive {\n"
    "                Stop -> Unit\n"
    "            }\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "    }\n"
    "}\n\n"
    "fn ping(process : Address(Msg)) : Unit = {\n"
    "    let _ = Address.call(process, fn(reply) = Ping(=reply), 5000);\n"
    "    Unit\n"
    "}\n\n"
    "fn counted(name : String, count : Int) : Unit =\n"
    "    Io.println(name <> \" \" <> Int.toString(count))\n\n"
    "export fn main() : Unit receiving Down = {\n"
    "    let waiting = spawn(fn() = waiter());\n"
    "    let deep = spawn(fn() = bottom());\n"
    "    let spawning = spawn(fn() = spawner());\n"
    "    ping(waiting);\n"
    "    ping(deep);\n"
    "    ping(spawning);\n"
    "    counted(\"waiter\", List.size(Code.running(waiter)));\n"
    "    counted(\"bottom\", List.size(Code.running(bottom)));\n"
    "    counted(\"spawner\", List.size(Code.running(spawner)));\n"
    "    counted(\"main\", List.size(Code.running(main)));\n"
    "    let old = Code.running(waiter);\n"
    "    List.forEach(old, fn(process) = send(process, Upgrade(next = fn() = Unit)));\n"
    "    counted(\"moved\", List.size(old));\n"
    "    List.forEach(old, fn(process) = monitor(Process.fromAddress(process), fn(down) = down));\n"
    "    ended(List.size(old));\n"
    "    counted(\"waiter\", List.size(Code.running(waiter)));\n"
    "    List.forEach([deep, spawning], fn(process) = send(process, Stop))\n"
    "}\n\n"
    "fn ended(left : Int) : Unit receiving Down =\n"
    "    if left == 0 then\n"
    "        Unit\n"
    "    else receive {\n"
    "        _ -> ended(left - 1)\n"
    "    }\n".
