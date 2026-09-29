%% The formatter: each rule of docs/style.md's layout on a small module,
%% what report §11.6 says it keeps, and a module that does not parse.
%% Regression tests, written with the formatter after the repository had
%% been laid out by it; test/ern_style_tests.erl's formatted_test_ holds
%% the repository's own modules and documents in its layout. Not covered
%% here: every production of Appendix A in every position, which the
%% repository's sources exercise.
-module(ern_format_tests).

-include_lib("eunit/include/eunit.hrl").

%% The lines a text of lines is laid out as.
laid(Lines) ->
    {ok, Out} = ern_format:format(iolist_to_binary(lists:join("\n", Lines))),
    binary:split(string:trim(Out, trailing, "\n"), <<"\n">>, [global]).

%% A text laid out is laid out already.
fixed(Lines) ->
    Text = iolist_to_binary([lists:join("\n", Lines), "\n"]),
    ?assertEqual({ok, Text}, ern_format:format(Text)).

%% report §11.6: a block comment on a line of code stands apart from the
%% token after it, but a closing bracket or a separator, by one space. A
%% regression test: it was glued to a token the layout puts no space
%% before, `- /* neg */1` (findings.md's C-B5)
block_comment_apart_test() ->
    ?assertEqual([<<"fn f(x) =">>, <<"    - /* neg */ 1">>], laid(["fn f(x) = - /* neg */1"])),
    ?assertEqual([<<"fn g(x) =">>, <<"    h( /* f */ x)">>], laid(["fn g(x) = h( /* f */x)"])),
    fixed(["fn k(x) =", "    h(x /* last */)"]),
    fixed(["fn m(x) =", "    x /* a */ + 1"]).

%% report §11.6: only line breaks and the spaces between tokens change; a
%% literal's spelling, a parenthesis and the form a pipe took stay
keeps_what_was_written_test() ->
    ?assertEqual([<<"fn f(x) =">>,
                  <<"    (x + 0x1F_FF) |> g">>,
                  <<>>,
                  <<"fn h(x) =">>,
                  <<"    x |> f() |> `raw`">>],
                 laid(["fn f(x)=(x+0x1F_FF)|>g", "fn h(x) = x |> f() |> `raw`"])).

%% docs/style.md: a function's head ends at `=` and its body begins on the
%% next line, one step in; a block's brace ends the head's line
head_test() ->
    ?assertEqual([<<"fn f(x : Int) : Int =">>,
                  <<"    x + 1">>,
                  <<>>,
                  <<"fn g() = {">>,
                  <<"    let y = 1;">>,
                  <<"    y">>,
                  <<"}">>],
                 laid(["fn f(x : Int) : Int = x + 1", "fn g() = { let y = 1; y }"])).

%% docs/style.md: a bracket that does not fit holds one item a line, each
%% under the first, and closes on the last; one that fits stays on its line
bracket_test() ->
    Head = "fn run(state : State, screen : Address(ScreenMsg), from : String, line : Int, "
           "input : String, printing : Bool) : State with ShellMsg = go(state)",
    ?assertEqual([<<"fn run(state : State,">>,
                  <<"       screen : Address(ScreenMsg),">>,
                  <<"       from : String,">>,
                  <<"       line : Int,">>,
                  <<"       input : String,">>,
                  <<"       printing : Bool) : State with ShellMsg =">>,
                  <<"    go(state)">>],
                 laid([Head])),
    fixed(["let point = Point(x = 1, y = 2)"]).

%% docs/style.md: a last item that opens a brace keeps the items on the
%% bracket's line, its contents a step in from that line
hug_test() ->
    ?assertEqual([<<"let s = spawn(Local, fn() = {">>,
                  <<"    tick();">>,
                  <<"    s">>,
                  <<"})">>],
                 laid(["let s = spawn(Local, fn() = { tick(); s })"])).

%% docs/style.md: a match, a receive and a block run over lines however
%% short, an arm a line, a further one led by its bar
brace_test() ->
    ?assertEqual([<<"fn f(x) =">>,
                  <<"    match x {">>,
                  <<"        Some(y) -> y">>,
                  <<"      | None -> 0">>,
                  <<"    }">>],
                 laid(["fn f(x) = match x { Some(y) -> y | None -> 0 }"])).

%% docs/style.md: an `if` stays on one line when it fits, and otherwise
%% breaks at every `then` and `else`, `else if` on one line; a block
%% branch stays beside its `then`, and `else` follows its brace
if_test() ->
    fixed(["let a = if b then c else d"]),
    ?assertEqual([<<"fn f(x) =">>,
                  <<"    if x < 0 then">>,
                  <<"        \"a negative number, which the rest of this does not take\"">>,
                  <<"    else if x == 0 then">>,
                  <<"        \"zero\"">>,
                  <<"    else">>,
                  <<"        \"positive\"">>],
                 laid(["fn f(x) = if x < 0 then \"a negative number, which the rest of this"
                       " does not take\" else if x == 0 then \"zero\" else \"positive\""])),
    ?assertEqual([<<"fn g(x) =">>,
                  <<"    if x then {">>,
                  <<"        a();">>,
                  <<"        b()">>,
                  <<"    } else">>,
                  <<"        c()">>],
                 laid(["fn g(x) = if x then { a(); b() } else c()"])).

%% docs/style.md: an arm's body stays on its line when it fits, or when its
%% first line ends in a brace or `then`, and otherwise begins the next line
arm_test() ->
    ?assertEqual([<<"fn f(x) =">>,
                  <<"    match x {">>,
                  <<"        Markdown.Paragraph([Markdown.Emphasis([Markdown.Text(text)])]) ->">>,
                  <<"            String.startsWith(text, \"Since \")">>,
                  <<"      | _ -> if x then">>,
                  <<"            \"a branch long enough that this if cannot stand on one line"
                    " with its else\"">>,
                  <<"        else">>,
                  <<"            \"no\"">>,
                  <<"    }">>],
                 laid(["fn f(x) = match x {",
                       "    Markdown.Paragraph([Markdown.Emphasis([Markdown.Text(text)])]) ->"
                       " String.startsWith(text, \"Since \")",
                       "  | _ -> if x then \"a branch long enough that this if cannot stand on"
                       " one line with its else\" else \"no\"",
                       "}"])).

%% docs/style.md: a lambda has no rule of its own; its body is an arm's
lambda_test() ->
    fixed(["let f = List.map(xs, fn(x) = x + 1)"]),
    ?assertEqual([<<"let names =">>,
                  <<"    List.map(Shell.Command.commands,">>,
                  <<"             fn(c) =">>,
                  <<"                 Shell.Complete.Name(text = \":\" <> c.name,">>,
                  <<"                                     kind = Shell.Complete.Value,">>,
                  <<"                                     shown = Shell.Command.line(c)))">>],
                 laid(["let names = List.map(Shell.Command.commands, fn(c) ="
                       " Shell.Complete.Name(text = \":\" <> c.name, kind = Shell.Complete.Value,"
                       " shown = Shell.Command.line(c)))"])).

%% docs/style.md: a `let`'s value is a body, as an arm's and a lambda's
%% are: on the `let`'s line when it fits whole or its first line ends in a
%% brace or `then`, and otherwise on the next line, a step in
let_test() ->
    ?assertEqual([<<"let group : Address(Supervisor.Msg) =">>,
                  <<"    spawn(Local, Supervisor.group(Supervisor.OneForAll,"
                    " RestartLimit(restarts = 3, within = 5000)))">>],
                 laid(["let group : Address(Supervisor.Msg) = spawn(Local,"
                       " Supervisor.group(Supervisor.OneForAll, RestartLimit(restarts = 3,"
                       " within = 5000)))"])),
    fixed(["let readers = match keys {",
           "    Some(#(reader, _)) -> [Process.fromAddress(reader)]",
           "  | None -> []",
           "}"]),
    ?assertEqual([<<"fn f(x) = {">>,
                  <<"    let y <-">>,
                  <<"        Either.map(Fs.read(Path(\"a file name of thir"
                    "ty-seven character\"), 5000), String.fromUtf8);">>,
                  <<"    y">>,
                  <<"}">>],
                 laid(["fn f(x) = { let y <- Either.map(Fs.read(Path(\"a file name of thir"
                       "ty-seven character\"), 5000), String.fromUtf8); y }"])).

%% docs/style.md: a line an operator opens carries its expression on, a step
%% in; an operator binding tighter carries on the operand above, a step more
operators_test() ->
    ?assertEqual([<<"let ok =">>,
                  <<"    negative == \":set depth takes 0 or more\"">>,
                  <<"        && unknown">>,
                  <<"            == \":set takes depth, length, output or timing, and not a thing"
                    " more than these four ones\"">>],
                 laid(["let ok = negative == \":set depth takes 0 or more\" && unknown =="
                       " \":set takes depth, length, output or timing, and not a thing more"
                       " than these four ones\""])).

%% docs/style.md: a type whose alternatives run past the line breaks after
%% its `=` and holds one alternative a line, a doc block before a later one
%% at its bar
types_test() ->
    ?assertEqual([<<"type ShellMsg =">>,
                  <<"    Typed(String)">>,
                  <<"  | Eof">>,
                  <<"  | Interrupted">>,
                  <<"  | Done(Outcome)">>,
                  <<"  | Reported(Process.FaultReport)">>,
                  <<"  | Ready">>,
                  <<"  | NoKeys">>],
                 laid(["type ShellMsg = Typed(String) | Eof | Interrupted | Done(Outcome)"
                       " | Reported(Process.FaultReport) | Ready | NoKeys"])),
    fixed(["type Inline =",
           "    /// Text.",
           "    Text(String)",
           "  /// A break.",
           "  | Break"]),
    %% a type of one alternative that does not fit breaks after its `=` too,
    %% before a bracket of its own parameters or of its fields; a
    %% regression test: it broke inside its parameters (MVP 2.98)
    ?assertEqual([<<"type SetOps(s, a) =">>,
                  <<"    SetOps(empty : s, put : (s, a) -> s, contains : (s, a) -> Bool,"
                    " union : (s, s) -> s)">>],
                 laid(["type SetOps(s, a) = SetOps(empty : s, put : (s, a) -> s,"
                       " contains : (s, a) -> Bool, union : (s, s) -> s)"])),
    fixed(["type Msg =",
           "    Start(command : Command,",
           "          ms : Int,",
           "          owner : Process,",
           "          reply : Reply(Either(Io.Error, Address(ProgramMessage))))"]),
    fixed(["type P = P(x : Int, y : Int)"]),
    %% a doc block before the first field puts the fields a step in
    fixed(["type Point = Point(",
           "    /// Across.",
           "    x : Int,",
           "    /// Up.",
           "    y : Int)"]).

%% report §11.6: a comment stays beside the token it was beside: a line
%% comment ends its line, one on a line of its own stands at the code's
%% indentation, and one before a closing brace with the content before it
comments_test() ->
    ?assertEqual([<<"// A file's comment.">>,
                  <<"fn f(x) = {">>,
                  <<"    // the first">>,
                  <<"    let y =">>,
                  <<"        [1, // one">>,
                  <<"         2];">>,
                  <<"    y /* inline */ + x">>,
                  <<"    // the last">>,
                  <<"}">>],
                 laid(["// A file's comment.",
                       "fn f(x) = {",
                       "// the first",
                       "  let y = [1, // one",
                       " 2];",
                       "  y /* inline */ + x",
                       "        // the last",
                       "}"])).

%% report §11.6: a comment that ends the text, with no line feed after it,
%% is kept; it had been lost (regression test)
last_comment_test() ->
    ?assertEqual({ok, <<"fn f(n) =\n    n * 2 // doubled\n">>},
                 ern_format:format(<<"fn f(n) =\n    n * 2       // doubled">>)).

%% report §11.6: a blank line inside a construct is kept, one where there
%% were several, and none after an opening bracket or before a closing
%% one; one blank line stands between two top-level declarations
blank_lines_test() ->
    ?assertEqual([<<"fn f() = {">>,
                  <<"    let a = 1;">>,
                  <<>>,
                  <<"    a">>,
                  <<"}">>,
                  <<>>,
                  <<"fn g() =">>,
                  <<"    2">>],
                 laid(["fn f() = {", "", "    let a = 1;", "", "", "", "    a", "", "}",
                       "fn g() = 2"])).

%% report §11.6: a doc block is kept as written, and the Ernest examples in
%% it are laid out as a function's body is
doc_examples_test() ->
    ?assertEqual([<<"/// Adds one.">>,
                  <<"///">>,
                  <<"/// ```ernest">>,
                  <<"/// match f(1) {">>,
                  <<"///     2 -> true">>,
                  <<"///   | _ -> false">>,
                  <<"/// }">>,
                  <<"/// // => true">>,
                  <<"/// ```">>,
                  <<"export fn f(n : Int) : Int =">>,
                  <<"    n + 1">>],
                 laid(["/// Adds one.",
                       "///",
                       "/// ```ernest",
                       "/// match f(1) { 2 -> true | _ -> false }",
                       "/// // => true",
                       "/// ```",
                       "export fn f(n : Int) : Int = n + 1"])).

%% report §11.6: a module that does not parse is not laid out
not_parsed_test() ->
    ?assertMatch({error, _}, ern_format:format(<<"fn f( = 1">>)),
    ?assertMatch({error, _}, ern_format:format(<<"let s = \"open">>)).

%% report §11.6: in a CommonMark text, an Ernest block that parses as a
%% module or as a function's body is laid out, and any other is left
markdown_test() ->
    In = <<"Text.\n\n```ernest\nfn f() = { a; b }\n```\n\n```ernest\n1 +\n```\n\n"
           "```ernest-rejected\nlet x = match y { A -> 1 }\n```\n">>,
    ?assertEqual(<<"Text.\n\n```ernest\nfn f() = {\n    a;\n    b\n}\n```\n\n```ernest\n1 +\n"
                   "```\n\n```ernest-rejected\nlet x = match y {\n    A -> 1\n}\n```\n">>,
                 ern_format:markdown(In)).

%% report §11.6: a doc block is kept as written, the spaces that end a line
%% among them, and so is a raw string in one of its examples. A regression
%% test: both lost their trailing spaces (findings C11, C16)
doc_trailing_spaces_test() ->
    fixed(["/// A line  ", "/// broken.", "export let x : Int = 1"]),
    fixed(["/// A value.", "///", "/// ```ernest", "/// let s = `a   ", "/// b`", "/// ```",
           "export let x : Int = 1"]).

%% report §11.6: a blank line after a comment on a line of its own is kept,
%% where the comment follows an opening bracket too. A regression test: it
%% was dropped (findings C25)
blank_after_comment_test() ->
    fixed(["fn f(x : Int) : Int = {", "    // one", "", "    let y = x;", "    y", "}"]).

%% report §11.6: comments directly under a declaration, with a blank line
%% after them, stay beside it, and the blank line between two declarations
%% comes after them; one directly above a declaration is its. A regression
%% test: the blank line went before them (findings C24)
comment_under_declaration_test() ->
    fixed(["type T = A | B", "// after the type", "", "export let x : Int = 1"]),
    fixed(["export let y : Int = 2", "// one", "// two", "", "// before x",
           "export let x : Int = 1"]),
    ?assertEqual([<<"export let y : Int = 2">>, <<>>, <<"// before x">>,
                  <<"export let x : Int = 1">>],
                 laid(["export let y : Int = 2", "// before x", "export let x : Int = 1"])).

%% report §11.6: an Ernest block of a CommonMark text that does not parse
%% is left as it is, the indentation of its lines too. A regression test:
%% an indented one was re-indented (findings C26)
markdown_unparsed_indented_test() ->
    In = <<"- an item\n\n   ```ernest\n   let  = (\n  x\n   ```\n">>,
    ?assertEqual(In, ern_format:markdown(In)).

%% report §2.2, §11.6: a `///` after code is an error, and the module is
%% left as it is. A regression test: the formatter stopped with an
%% internal error (findings C17)
doc_comment_after_code_test() ->
    ?assertMatch({error, _}, ern_format:format(<<"export let x : Int = 1 /// note\n">>)).
