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

%% Appendix E.28, report §6.9, §11.2: a load whose binding faults while a
%% monitor's wrap of the module it brought still runs, in the runtime's own
%% process for the Down's delivery, is undone all the same: the process the
%% evaluation started is killed, the wrap's delivery to it ending with it
%% (§6.9), and nothing else ends, so the program goes on, a later
%% monitor's Down delivered and the load refused alike when asked again.
%% The unit the load brought stays loaded, out of reach (§11.2): a process
%% running before the load, the holder of a module the program uses, was
%% handed a function of it by a binding before the fault, and calls it
%% after; refused again, the module makes no unit. A regression test,
%% written after the code: the delivery's process was linked to the
%% runtime's reaper, which did not trap exits, so the purge of the unit
%% ended the reaper with it, and the program waited for ever at its next
%% monitor; once the reaper trapped exits, the purge left the holder a
%% function whose code was gone, which faulted at its call
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
    "        Ping(reply = reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            waiter()\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "      | Upgrade(next = next) -> next()\n"
    "    }\n\n"
    "fn idle() : Unit receiving Msg =\n"
    "    receive {\n"
    "        Ping(reply = reply) -> {\n"
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
    "        Ping(reply = reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            receive {\n"
    "                Stop -> Unit\n"
    "            }\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "    }\n"
    "}\n\n"
    "fn ping(process : Address(Msg)) : Unit = {\n"
    "    let _ = Address.call(process, fn(reply) = Ping(reply = reply), 5000);\n"
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
