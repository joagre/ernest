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
%% is 0.
ran(File) ->
    Before = byte_size(captured_output()),
    ?assertEqual(0, ern_cli:ern(["run", File])),
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
          "export fn greet(name : String) : Unit with m =\n"
          "    Io.println(Plug.Util.shout(Plug.Util.greeting <> \" \" <> name))\n"),
    write(Lib, "plug/bad.ern",
          "let worker : Address(Int) =\n"
          "    spawn(fn() : Unit with Int = receive {\n"
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
%% path lacks answer NotFound, and a file that is no `.erc` Invalid
load_test() ->
    Dir = tmp(),
    Lib = library(Dir),
    write(Dir, "lone/plug/greet.erc", element(2, file:read_file(filename:join(Lib,
                                                                         "plug/greet.erc")))),
    Main = write(Dir, "main.ern",
                 "fn shown(path : String) : Unit with m =\n"
                 "    Io.println(Io.show(Code.load(Path(path))))\n\n"
                 "export fn main() : Unit with Never = {\n"
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
    %% report §11.2: nothing of the faulting load stays loaded
    ?assertNot(erlang:module_loaded('ern@plug@bad')).

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
                 "export fn main() : Unit with Never =\n"
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
                 "export fn main() : Unit with Never = {\n"
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
    "type Msg = Ping(reply : Reply(Unit)) | Stop | Upgrade(next : () -> Unit with Msg)\n\n"
    "fn waiter() : Unit with Msg =\n"
    "    receive {\n"
    "        Ping(reply = reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            waiter()\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "      | Upgrade(next = next) -> next()\n"
    "    }\n\n"
    "fn idle() : Unit with Msg =\n"
    "    receive {\n"
    "        Ping(reply = reply) -> {\n"
    "            answer(reply, Unit);\n"
    "            idle()\n"
    "        }\n"
    "      | Stop -> Unit\n"
    "      | Upgrade(next = _) -> idle()\n"
    "    }\n\n"
    "fn bottom() : Unit with Msg = {\n"
    "    let _ = climb(30);\n"
    "    Unit\n"
    "}\n\n"
    "fn climb(n : Int) : Int with Msg =\n"
    "    if n == 0 then {\n"
    "        idle();\n"
    "        0\n"
    "    } else 1 + descend(n - 1)\n\n"
    "fn descend(n : Int) : Int with Msg =\n"
    "    if n == 0 then {\n"
    "        idle();\n"
    "        0\n"
    "    } else 1 + climb(n - 1)\n\n"
    "fn spawner() : Unit with Msg = {\n"
    "    let _ = spawn(fn() : Unit with Msg = idle());\n"
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
    "fn ping(process : Address(Msg)) : Unit with m = {\n"
    "    let _ = Address.call(process, fn(reply) = Ping(reply = reply), 5000);\n"
    "    Unit\n"
    "}\n\n"
    "fn counted(name : String, count : Int) : Unit with m =\n"
    "    Io.println(name <> \" \" <> Int.toString(count))\n\n"
    "export fn main() : Unit with Down = {\n"
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
    "fn ended(left : Int) : Unit with Down =\n"
    "    if left == 0 then\n"
    "        Unit\n"
    "    else receive {\n"
    "        _ -> ended(left - 1)\n"
    "    }\n".
