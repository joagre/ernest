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

%% A tool run with the captured output as its error device, so a test
%% reads what the user sees on stderr.
ernc_err(Args) -> ern_cli:ernc(Args, group_leader()).
ern_err(Args) -> ern_cli:ern(Args, group_leader()).

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

%% report §4.1, §4.2, §11.1: a module is one file carrying a namespace;
%% directory mode compiles in dependency order into a
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
%% report §11.1: single-file mode with no --source-root uses the current
%% directory, so `ernc a.ern` in a project's directory works
default_root_test() ->
    Dir = tmp(),
    write(Dir, "hello.ern", hello()),
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try
        ?assertEqual(0, ern_cli:ernc(["hello.ern"])),
        ?assert(filelib:is_regular(filename:join(Dir, "hello.erc")))
    after
        file:set_cwd(Cwd)
    end.

parse_error_test() ->
    Dir = tmp(),
    File = write(Dir, "a.ern", "export fn f() -> Int = \n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir])),
    Out = iolist_to_binary(?capturedOutput),
    ?assertEqual(<<(list_to_binary(File))/binary, ":2:1: expected an expression instead of"
                   " end of input\n1 | export fn f() -> Int = \n2 | \n  | ^\n\n">>,
                 Out).

%% report Appendix D, §4.7, §8.4: the Ets library compiles as a module and
%% a program uses it through its interface
ets_library_test() ->
    Dir = tmp(),
    {ok, Ets} = file:read_file(example("ets.ern")),
    write(Dir, "src/ets.ern", Ets),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = {\n"
          "    let t = Ets.new();\n"
          "    Ets.insert(t, \"a\", 1);\n"
          "    Ets.insert(t, \"b\", 2);\n"
          "    match Ets.lookup(t, \"b\") {\n"
          "        Some(n) -> Io.println(Int.toString(n))\n"
          "      | None -> Io.println(\"none\")\n"
          "    };\n"
          "    Io.println(Int.toString(Ets.size(t)));\n"
          "    Io.println(Bool.toString(Ets.member(t, \"c\")))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"2\n2\nfalse\n">>, iolist_to_binary(?capturedOutput)).

%% report §4.8, §3.10, §4.2: an operator and an ordering on a type of a
%% compiled module resolve through its interface and call into its module;
%% a member it lacks is an error
operators_across_modules_test() ->
    Dir = tmp(),
    write(Dir, "src/geo/vec.ern",
          "export type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) -> Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) -> Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) -> Ordering = Int.compare(a, b)\n"
          "export fn show(Vec(n)) -> String = Int.toString(n)\n"),
    write(Dir, "src/main.ern",
          "export fn main() -> Unit with Never = {\n"
          "    let a = Geo.Vec.Vec(1);\n"
          "    let b = Geo.Vec.Vec(2);\n"
          "    Io.println(Geo.Vec.show(a + b));\n"
          "    Io.println(Float.toString((a * b) + 0.5));\n"
          "    Io.println(Bool.toString(a < b))\n"
          "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    ?assertEqual(<<"3\n2.5\ntrue\n">>, iolist_to_binary(?capturedOutput)),
    write(Dir, "src/bad.ern", "export fn f(a : Geo.Vec.Vec, b) = a - b\n"),
    ?assertEqual(1, ernc_err(["--errors", "short", "--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "bad.ern:1:35: `-` is not defined on Geo.Vec.Vec\n$")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/bad.erc")).

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

%% report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module, found from either file and in either mode
namespace_clash_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "type Stack = Stack(Int)\n" ++ hello()),
    write(Dir, "src/main/stack.ern", "export fn push(n : Int) -> Int = n\n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "main/stack.ern and type Stack in main.ern share the namespace"
                        " Main.Stack")),
    ?assertNot(filelib:is_regular(Dir ++ "/build/main.erc")),
    Single = ["--source-root", Dir ++ "/src", "--out-dir", Dir ++ "/build"],
    ?assertEqual(1, ernc_err(Single ++ [Dir ++ "/src/main.ern"])),
    ?assertEqual(1, ernc_err(Single ++ [Dir ++ "/src/main/stack.ern"])).

%% report §4.4: an abstract type's constructor is not visible outside its module
abstract_constructor_outside_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern",
          "export abstract type Stack(a) = Stack(List(a)) with { empty : Stack(a) }\n"
          "export let Stack.empty = Stack([])\n" ++ hello()),
    write(Dir, "src/other.ern", "export fn f() -> Main.Stack(Int) = Main.Stack([])\n"),
    ?assertEqual(1, ernc_err(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertMatch({match, _},
                 re:run(iolist_to_binary(?capturedOutput),
                        "Main.Stack is the constructor of an abstract type and is not visible"
                        " outside its module")).

%% report §4.2: a module that names itself qualified is not a module cycle
self_qualified_module_test() ->
    Dir = tmp(),
    write(Dir, "src/main.ern", "export fn g() -> Int = 1\nexport fn f() -> Int = Main.g()\n"
                               "export fn main() -> Unit with Never = Io.println(Int.toString(f()))\n"),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])).

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
    ?assertEqual(1, ernc_err(["--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:50: the argument does not fit Io.println:"
                   " expected String, found Int\n"
                   "1 | export fn main() -> Unit with Never = Io.println(1)\n"
                   "  |                                       ---------- Io.println : (String) ->"
                   " Unit with e\n"
                   "  |                                                  ^\n\n">>,
                 iolist_to_binary(?capturedOutput)),
    ?assertNot(filelib:is_regular(filename:join(Dir, "bad.erc"))).

%% report §11.5: --errors short is the first line alone
errors_short_test() ->
    Dir = tmp(),
    File = write(Dir, "bad.ern", "export fn main() -> Unit with Never = Io.println(1)\n"),
    ?assertEqual(1, ernc_err(["--errors", "short", "--source-root", Dir, File])),
    ?assertEqual(<<(list_to_binary(File))/binary, ":1:50: the argument does not fit Io.println:"
                   " expected String, found Int\n">>,
                 iolist_to_binary(?capturedOutput)).

%% report §8.6, §7.4: a fault in main is reported on stderr with its
%% cause, status 1
fault_test() ->
    Dir = tmp(),
    File = write(Dir, "boom.ern",
                 "export fn main() -> Unit with Never = {\n"
                 "    let z = List.size([]);\n"
                 "    Io.println(Int.toString(1 / z))\n"
                 "}\n"),
    ?assertEqual(0, ern_cli:ernc(["--source-root", Dir, File])),
    ?assertEqual(1, ern_err([filename:join(Dir, "boom.erc")])),
    ?assertEqual(<<"fault: division by zero\n">>, iolist_to_binary(?capturedOutput)).

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
    Expect(<<"# Ernest module Shapes\n\n## Shape\n\n```ernest\ntype Shape = Dot | At(x : Int, y : Int)\n```\n\nA shape.\n">>),
    Expect(<<"## Box\n\n```ernest\nabstract type Box(a) with {\n"
             "    empty : Box(a);\n    put : (a, Box(a)) -> Box(a)\n}\n```\n">>),
    Expect(<<"## Box.empty\n\n```ernest\nBox.empty : Box(a)\n```\n">>),
    Expect(<<"## Box.put\n\n```ernest\nBox.put : (a, Box(a)) -> Box(a)\n```\n\n"
             "Put x in the box.\n">>),
    Expect(<<"## same\n\n```ernest\nsame : (a=, a=) -> Bool\n```\n">>),
    Expect(<<"## twice\n\n```ernest\ntwice : (Int) -> Int\n```\n\nDocumented but private.\n">>),
    ?assertEqual(nomatch, binary:match(Out, <<"hidden">>)),
    %% a type error is reported as for a compilation
    ?assertEqual(1, ern_cli:ernc(["--doc", "--source-root", Dir,
                                  write(Dir, "bad.ern", "export fn f() -> Int = \"s\"\n")])).

%% report §11.4, Appendix E.0 rule 6: docs/module_doc_template.md is what
%% `ernc --doc` renders for examples/template.ern, after its marker line
doc_template_test() ->
    Src = example("template.ern"),
    ?assertEqual(0, ern_cli:ernc(["--doc", "--source-root", filename:dirname(Src), Src])),
    Out = iolist_to_binary(?capturedOutput),
    {ok, File} = file:read_file("../../../docs/module_doc_template.md"),
    [_, Generated] = binary:split(File, <<"<!-- generated: ernc --doc examples/template.ern -->\n">>),
    %% the last line names the compiler's version, which is compared to itself
    ?assertEqual(without_footer(Generated), without_footer(Out)),
    %% the module and every exported declaration say since which version, E.0 rule 6
    {match, Sinces} = re:run(Out, "\\*Since 0\\.1\\.0\\.\\*", [global]),
    ?assertEqual(1 + 8, length(Sinces)),
    %% every exported type and fn has an Examples section, E.0 rule 6
    Sections = tl(binary:split(Out, <<"\n## ">>, [global])),
    Named = fun(Name) -> hd([S || S <- Sections, binary:match(S, <<Name/binary, "\n">>) =:= {0, byte_size(Name) + 1}]) end,
    lists:foreach(fun(Name) -> ?assertMatch({_, _}, binary:match(Named(Name), <<"### Examples">>)) end,
                  [<<"Point">>, <<"Shape">>, <<"Stack">>, <<"circle">>, <<"area">>, <<"checked">>]),
    ?assertMatch({match, _}, re:run(Out, "\n---\n\nGenerated by ernc [0-9.]+ from template.ern.\n$")).

without_footer(Doc) ->
    hd(binary:split(Doc, <<"\n---\n\nGenerated by ernc">>)).

%% report §2.2, Appendix E.0 rule 6: every fenced Ernest block in the
%% template's doc blocks type-checks against the module, as the body of a
%% lambda, and one that ends in `// => v` is run, its value printed by
%% Io.debug and compared with v, so an example cannot rot
doc_examples_test() ->
    {ok, Src} = file:read_file(example("template.ern")),
    {ok, Decls} = ern_parser:parse_string(Src),
    Blocks = lists:append([fences(Doc) || Doc <- docs(Decls, [])]),
    ?assert(length(Blocks) >= 4),
    Numbered = lists:zip(lists:seq(1, length(Blocks)), [split_result(B) || B <- Blocks]),
    lists:foreach(fun({N, {Body, _}}) ->
                      Text = <<Src/binary, "\nfn docExample", (integer_to_binary(N))/binary,
                               "() = fn() = {\n", Body/binary, "\n}\n">>,
                      ?assertMatch({ok, _, _, _}, ern_typecheck:check_string(['Template'], Text))
                  end, Numbered),
    WithResult = [{N, Body, V} || {N, {Body, V}} <- Numbered, V =/= none],
    ?assert(length(WithResult) >= 4),
    Dir = tmp(),
    Fns = [<<"export fn docExample", (integer_to_binary(N))/binary, "() = {\n", Body/binary,
             "\n}\n">> || {N, Body, _} <- WithResult],
    write(Dir, "src/template.ern", [Src, "\n", Fns]),
    Calls = [<<"    let _ = Io.debug(Template.docExample", (integer_to_binary(N))/binary, "());\n">>
             || {N, _, _} <- WithResult],
    write(Dir, "src/main.ern", ["export fn main() -> Unit with Never = {\n", Calls, "    Unit\n}\n"]),
    ?assertEqual(0, ern_cli:ernc(["--out-dir", Dir ++ "/build", Dir ++ "/src"])),
    ?assertEqual(0, ern_cli:ern([Dir ++ "/build/main.erc"])),
    Expected = iolist_to_binary([[V, "\n"] || {_, _, V} <- WithResult]),
    ?assertEqual(Expected, iolist_to_binary(?capturedOutput)).

%% An example's body and the value its last line `// => v` promises, or none.
split_result(Block) ->
    Lines = binary:split(Block, <<"\n">>, [global]),
    case lists:last(Lines) of
        <<"// => ", V/binary>> -> {iolist_to_binary(lists:join(<<"\n">>, lists:droplast(Lines))), V};
        _ -> {Block, none}
    end.

%% Every doc text in an AST: the third element of the records that carry one.
docs(T, Acc) when is_tuple(T), tuple_size(T) >= 3 ->
    Acc1 = case lists:member(element(1, T), [module_doc, type_decl, abstract_decl, fn_decl,
                                              let_decl, foreign_type_decl, foreign_fn_decl,
                                              constructor, field, signature])
                    andalso is_binary(element(3, T)) of
               true -> [element(3, T) | Acc];
               false -> Acc
           end,
    lists:foldl(fun docs/2, Acc1, tuple_to_list(T));
docs(L, Acc) when is_list(L) -> lists:foldl(fun docs/2, Acc, L);
docs(_, Acc) -> Acc.

fences(Doc) ->
    case re:run(Doc, "```ernest\n(.*?)\n```", [global, dotall, {capture, all_but_first, binary}]) of
        {match, Ms} -> [B || [B] <- Ms];
        nomatch -> []
    end.

%% README, "What MVP 1 accepts": every error text in lib/*/src that names
%% an MVP appears in the README's table, by its first forty characters, so
%% the table cannot drift from what the code refuses
mvp_refusals_in_readme_test() ->
    {ok, Readme} = file:read_file("../../../README.md"),
    Sources = filelib:wildcard("../../*/src/*.erl"),
    Texts = lists:usort(lists:append(
                          [begin
                               {ok, Src} = file:read_file(F),
                               case re:run(Src, "\"([^\"\n]*\\bin MVP [0-9][^\"\n]*)\"",
                                           [global, {capture, all_but_first, binary}]) of
                                   {match, Ms} -> [M || [M] <- Ms];
                                   nomatch -> []
                               end
                           end || F <- Sources])),
    ?assert(length(Texts) >= 2),
    Missing = [T || T <- Texts, binary:match(Readme, binary:part(T, 0, min(40, byte_size(T))))
                                =:= nomatch],
    ?assertEqual([], Missing).

%% report §11: --version prints the top-level VERSION file's content
version_test() ->
    {ok, V} = file:read_file("../../../VERSION"),
    ?assertEqual(0, ern_cli:ernc(["--version"])),
    ?assertEqual(<<"ernc ", (string:trim(V))/binary, "\n">>, iolist_to_binary(?capturedOutput)).

%% report §11: options are long; --help and --version stop with status 0
options_test() ->
    ?assertEqual(1, ern_cli:ernc(["-o", "x", example("hello.ern")])),
    ?assertEqual(1, ernc_err([])),
    ?assertMatch({match, _}, re:run(iolist_to_binary(?capturedOutput),
                                    "^ernc: one file or directory argument is required\nUsage: ")),
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
          "    send(Lib.Values.out, Int.toString(total) <> \"\\n\")\n"),
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
