-module(ern_cli_tests).

-include_lib("eunit/include/eunit.hrl").

%%
%% Helpers: a fresh directory per test, sources written into it
%%

%% Unique within this VM; a leftover from an earlier run is removed first.
tmp() ->
    Dir = filename:join(["/tmp", "ern_cli_" ++ integer_to_list(erlang:unique_integer([positive]))]),
    file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

write(Dir, Rel, Text) ->
    Path = filename:join(Dir, Rel),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, Text),
    Path.

example(Base) ->
    "../../../examples/" ++ Base.

hello() ->
    "export fn main() -> Unit with Never = Io.println(\"hello, world\")\n".

%% The two-module program of the guide, as sources.
pair(Dir) ->
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = match Net.Http.parse(\"GET /\") {\n"
          "    Some(Net.Http.Request(method = m, path = p)) -> Io.println(m <> \" \" <> p)\n"
          "  | None -> Io.println(\"bad request\")\n"
          "}\n"),
    Dir.

%%
%% ernc, report §11.1
%%

%% report §11.1, §11.2, §8.1: a file compiles to .erc beside it and runs
single_file_test() ->
    Dir = tmp(),
    File = write(Dir, "hello.ern", hello()),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assert(filelib:is_regular(filename:join(Dir, "hello.erc"))),
    ?assertEqual(0, ern_cli:ern([filename:join(Dir, "hello.erc")])),
    ?assertEqual(<<"hello, world\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1, §4.2: directory mode compiles in dependency order into a
%% mirrored build tree; §11.2 loads the dependency by namespace
directory_mode_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.1: output mirrors the source root, not the directory argument
source_root_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/net"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/http.erc")).

%% report §11.1: a dependency outside the compiled subtree must have been
%% compiled into the build directory already
dependency_not_built_test() ->
    Dir = pair(tmp()),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/net"])),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])).

%% report §11.1: path components below the root are one lowercase word each
path_shape_test() ->
    Dir = tmp(),
    File = write(Dir, "Net/http.ern", hello()),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertNot(filelib:is_regular(filename:join(Dir, "Net/http.erc"))),
    Dir2 = tmp(),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir2, write(Dir2, "9x.ern", hello())])),
    Dir3 = tmp(),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir3, write(Dir3, "http_server.ern", hello())])),
    ?assertNot(filelib:is_regular(filename:join(Dir3, "http_server.erc"))).

%% report §11.1, §11.5: a parse error in directory mode is reported as
%% file:line:column: text, status 1
parse_error_test() ->
    Dir = tmp(),
    write(Dir, "a.ern", "export fn f() -> Int = \n"),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir])).

%% report §4.2, §11.2: a type member of another module is called by its
%% module path, type, and member, and loads from the module that owns it
type_member_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/stack.ern",
          "export abstract type Stack(a) = Stack(List(a)) with {\n"
          "    empty : Stack(a);\n"
          "    push : (a, Stack(a)) -> Stack(a);\n"
          "    size : (Stack(a)) -> Int\n"
          "}\n"
          "export let Stack.empty : Stack(a) = Stack([])\n"
          "export fn Stack.push(x : a, Stack(xs) : Stack(a)) -> Stack(a) = Stack(x :: xs)\n"
          "export fn Stack.size(Stack(xs) : Stack(a)) -> Int = List.size(xs)\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = {\n"
          "    let s = Lib.Stack.Stack.push(1, Lib.Stack.Stack.empty);\n"
          "    Io.println(Int.toString(Lib.Stack.Stack.size(s)))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"1\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.2: a module may not take a prelude namespace
prelude_namespace_test() ->
    Dir = tmp(),
    write(Dir, "src/io.ern", "export fn println(s : String) -> Unit with m = Unit\n"),
    write(Dir, "src/main.ern", hello()),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")).

%% report §11.1: a module cycle is an error naming the modules
module_cycle_test() ->
    Dir = tmp(),
    write(Dir, "a.ern", "export fn f() -> Int = B.g()\n"),
    write(Dir, "b.ern", "export fn g() -> Int = A.f()\n"),
    ?assertEqual(1, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir])).

%% report §11.1: a module is recompiled when its source or a dependency's
%% interface changed, and not when only a dependency's bodies changed
recompile_rule_test() ->
    Dir = pair(tmp()),
    Args = ["--out-dir", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ernc(Args)),
    {ok, Main1} = file:read_file(Dir ++ "/build/main.erc"),
    {ok, Http1} = file:read_file(Dir ++ "/build/net/http.erc"),
    %% nothing changed: nothing rewritten
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% a body change in the dependency: it is rebuilt, its dependent is not
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\"))\n"
          "    else None\n"),
    ?assertEqual(0, ern_cli:ernc(Args)),
    {ok, Http2} = file:read_file(Dir ++ "/build/net/http.erc"),
    ?assertNotEqual(Http1, Http2),
    ?assertEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")),
    %% an interface change in the dependency: the dependent is rebuilt
    write(Dir, "src/net/http.ern",
          "export type Request = Request(method : String, path : String)\n"
          "export fn parse(s : String) -> Optional(Request) =\n"
          "    if s == \"GET /\" then Some(Request(method = \"GET\", path = \"/\")) else None\n"
          "export fn version() -> Int = 2\n"),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertNotEqual({ok, Main1}, file:read_file(Dir ++ "/build/main.erc")).

%% report §11.1: the sweep removes .erc files whose source is gone and
%% directories left empty; --no-clean keeps them; single-file mode does
%% not sweep
sweep_test() ->
    Dir = pair(tmp()),
    Args = ["--out-dir", Dir ++ "/build", Dir ++ "/src"],
    ?assertEqual(0, ern_cli:ernc(Args)),
    write(Dir, "src/main.ern", hello()),
    ok = file:delete(Dir ++ "/src/net/http.ern"),
    ?assertEqual(0, ern_cli:ernc(["--no-clean" | Args])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build",
                                  Dir ++ "/src/main.ern"])),
    ?assert(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(0, ern_cli:ernc(Args)),
    ?assertNot(filelib:is_dir(Dir ++ "/build/net")),
    ?assert(filelib:is_regular(Dir ++ "/build/main.erc")).

%% report §11.1: --emit erl writes the Erlang source and no .erc
emit_erl_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--emit", "erl", "--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    {ok, Src} = file:read_file(Dir ++ "/build/net/http.erl"),
    ?assertMatch({_, _}, binary:match(Src, <<"-module(ernest@net@http).">>)),
    ?assertNot(filelib:is_regular(Dir ++ "/build/net/http.erc")),
    ?assertEqual(1, ern_cli:ernc(["--emit", "asm", Dir ++ "/src"])).

%% report §11.1, §11.5: an error is file:line:column: text, status 1
compile_error_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() -> Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertNot(filelib:is_regular(filename:join(Dir, "bad.erc"))).

%% report §11.4, §11.5: every exported and every documented declaration,
%% with its type and its doc comment, as Markdown
doc_test() ->
    Dir = tmp(),
    File = write(Dir, "shapes.ern",
                 "/// A shape.\n"
                 "export type Shape = Dot | At(x : Int, y : Int)\n"
                 "export abstract type Box(a) = Box(List(a)) with {\n"
                 "    empty : Box(a);\n"
                 "    put : (a, Box(a)) -> Box(a)\n"
                 "}\n"
                 "export let Box.empty : Box(a) = Box([])\n"
                 "/// Put x in the box.\n"
                 "export fn Box.put(x : a, Box(xs) : Box(a)) -> Box(a) = Box(x :: xs)\n"
                 "export fn same(a, b) = a == b\n"
                 "/// Documented but private.\n"
                 "fn twice(n : Int) -> Int = 2 * n\n"
                 "fn hidden(n : Int) -> Int = n\n"),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--source-root", Dir, File])),
    Out = iolist_to_binary(?capturedOutput),
    Expect = fun(Text) -> ?assertMatch({_, _}, binary:match(Out, Text)) end,
    Expect(<<"### type Shape\n\n    type Shape = Dot | At(x : Int, y : Int)\n\nA shape.\n">>),
    Expect(<<"### abstract type Box\n\n    abstract type Box(a) = Box(List(a)) with {\n"
             "        empty : Box(a);\n        put : (a, Box(a)) -> Box(a)\n    }\n">>),
    Expect(<<"### let Box.empty\n\n    Box.empty : Box(a)\n">>),
    Expect(<<"### fn Box.put\n\n    Box.put : (a, Box(a)) -> Box(a)\n\n"
             "Put x in the box.\n">>),
    Expect(<<"### fn same\n\n    same : (a=, a=) -> Bool\n">>),
    Expect(<<"### fn twice\n\n    twice : (Int) -> Int\n\nDocumented but private.\n">>),
    ?assertEqual(nomatch, binary:match(Out, <<"hidden">>)),
    %% a type error is reported as for a compilation
    ?assertEqual(1, ern_cli:ernc(["--doc", "--source-root", Dir,
                                  write(Dir, "bad.ern", "export fn f() -> Int = \"s\"\n")])).

%% report §11: options are long; --help and --version stop with status 0
options_test() ->
    ?assertEqual(1, ern_cli:ernc(["-o", "x", example("hello.ern")])),
    ?assertEqual(1, ern_cli:ernc([])),
    ?assertEqual(0, ern_cli:ernc(["--version"])),
    ?assertEqual(0, ern_cli:ernc(["--help"])),
    ?assertEqual(0, ern_cli:ern(["--help"])).

%%
%% ern, report §11.2 and §11.3
%%

%% report §11.2: --load-path adds roots searched by namespace
load_path_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ok = filelib:ensure_dir(Dir ++ "/lib/net/http.erc"),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/lib/net/http.erc"),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(0, ern_cli:ern(["--load-path", Dir ++ "/lib", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"GET /\n">>, iolist_to_binary(?capturedOutput)).

%% report §11.2: --main picks another exported entry point; one that takes
%% arguments is refused (§8.1)
main_option_test() ->
    Dir = pair(tmp()),
    write(Dir, "src/tools.ern",
          "export fn check() -> Unit with Never = Io.println(\"checked\")\n"
          "export fn twice(n : Int) -> Int = 2 * n\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern(["--main", "Tools.check", Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"checked\n">>, iolist_to_binary(?capturedOutput)),
    ?assertEqual(1, ern_cli:ern(["--main", "Tools.twice", Dir ++ "/build/main.erc"])),
    ?assertEqual(1, ern_cli:ern(["--main", "check", Dir ++ "/build/main.erc"])).

%% report §8.5, §8.2, §11.2: top-level lets of every loaded module are
%% evaluated before main, dependencies first, with Sys.* bound
init_order_test() ->
    Dir = tmp(),
    write(Dir, "src/lib/values.ern", "export let base = 40\nexport let out = Sys.stdout\n"),
    write(Dir, "src/main.ern",
          "let total = Lib.Values.base + 2\n"
          "export fn main() -> Unit with Never =\n"
          "    Io.printlnTo(Lib.Values.out, Int.toString(total))\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"42\n">>, iolist_to_binary(?capturedOutput)).

%% report §7.3, §8.6, §11.2: a faulting main is status 1
fault_status_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() -> Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertEqual(1, ern_cli:ern([filename:join(Dir, "boom.erc")])).

%% report §11.2: the file must lie at the path of its namespace
misplaced_module_test() ->
    Dir = pair(tmp()),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ok = file:rename(Dir ++ "/build/net/http.erc", Dir ++ "/build/http.erc"),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/http.erc"])),
    ?assertEqual(1, ern_cli:ern([Dir ++ "/build/nothing.erc"])).

%% report §11.2, plan 3.1: the shell is not in MVP 1, with or without a file
shell_test() ->
    ?assertEqual(1, ern_cli:ern(["--shell"])),
    ?assertEqual(1, ern_cli:ern(["--shell", "--load-path", ".", example("hello.ern")])).

%% report §11.3, Appendix C: the configuration directory with an empty
%% peer list and a private key readable only by its owner; a second
%% creation fails
create_config_dir_test() ->
    Dir = tmp(),
    ?assertEqual(0, ern_cli:ern(["--create-config-dir", Dir])),
    {ok, Conf} = file:read_file(Dir ++ "/.ernest/ernest.conf"),
    #{<<"peers">> := [], <<"public-key">> := <<"-----BEGIN PUBLIC KEY-----", _/binary>>,
      <<"network-address">> := _} = json:decode(Conf),
    {ok, Info} = file:read_file_info(Dir ++ "/.ernest/private-key.pem"),
    ?assertEqual(8#600, element(8, Info) band 8#777),
    {ok, Pem} = file:read_file(Dir ++ "/.ernest/private-key.pem"),
    ?assertMatch([{'PrivateKeyInfo', _, not_encrypted}], public_key:pem_decode(Pem)),
    ?assertEqual(1, ern_cli:ern(["--create-config-dir", Dir])).
