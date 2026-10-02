%% ern_diagnostic renders report §11.5's error format.
-module(ern_diagnostic_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

-define(SRC, "fn g() : Int =\n    f(\"x\")\nfn f(n : Int) : Int = n\n").

%% report §11.5: the source shows a control character as its picture, one
%% column, so the caret stays under it. A regression test: the line was
%% quoted as it was, and the diagnostic wrote the character to the terminal
control_picture_test() ->
    Diagnostic = #diagnostic{span = {1, 7, {1, 8}}, message = "control character U+001B"},
    ?assertEqual("main.ern:1:7: control character U+001B\n"
                 "1 | /// a \x{241B}[2J\n"
                 "  |       ^\n",
                 lists:flatten(ern_diagnostic:format("main.ern", "/// a \e[2J\n", Diagnostic))).

%% report §11.5: the source shows a byte that begins no UTF-8 character
%% as U+FFFD, one column. A regression test: the release review found
%% `ern build` of such a source ending as a failure of ern itself
not_utf8_test() ->
    Diagnostic = #diagnostic{span = {2, 5, {2, 6}}, message = "input is not valid UTF-8"},
    ?assertEqual("main.ern:2:5: input is not valid UTF-8\n"
                 "1 | é\n"
                 "2 | a = \x{FFFD}\x{FFFD}\n"
                 "  |     ^\n",
                 lists:flatten(ern_diagnostic:format("main.ern",
                                                     <<"\xC3\xA9\na = ", 16#FF, 16#C3>>,
                                                     Diagnostic))).

%% report §11.5: a carriage return that ends a line with its line feed is
%% not shown, and one anywhere else is a column, shown as its picture, so
%% the caret after it stands under what the lexer counted. A regression
%% test: every carriage return was dropped, and the caret stood one column
%% early
carriage_return_test() ->
    Source = "a\r\nx\r y\r\n",
    {ok, [_, _, {ident, Position, y} | _]} = ern_lexer:tokenize(Source, []),
    Diagnostic = #diagnostic{span = ern_diagnostic:span(Position), message = "unknown name y"},
    ?assertEqual("main.ern:2:4: unknown name y\n"
                 "1 | a\n"
                 "2 | x\x{240D} y\n"
                 "  |    ^\n",
                 lists:flatten(ern_diagnostic:format("main.ern", Source, Diagnostic))).

%% report §11.5: the first line is file:line:column: message
short_test() ->
    Diagnostic = #diagnostic{span = {2, 7, {2, 10}}, message = "expected Int, found String"},
    ?assertEqual("main.ern:2:7: expected Int, found String",
                 ern_diagnostic:short("main.ern", Diagnostic)).

%% report §11.5: the source with a gutter, the line before, the span
%% underlined with ^, a label's span with - and its text, and the help line
format_test() ->
    Diagnostic = #diagnostic{span = {2, 7, {2, 10}}, message = "expected Int, found String",
                             labels = [{{1, 11, {1, 14}}, "result type Int declared here"}],
                             help = "give f an Int"},
    ?assertEqual("main.ern:2:7: expected Int, found String\n"
                 "1 | fn g() : Int =\n"
                 "  |           --- result type Int declared here\n"
                 "2 |     f(\"x\")\n"
                 "  |       ^^^\n"
                 "  | = help: give f an Int\n",
                 ern_diagnostic:format("main.ern", ?SRC, Diagnostic)).

%% report §11.5: a line `...` stands for the lines an excerpt passes over.
%% A regression test: the gutter went from line 1 to line 4 unmarked
%% (findings.md's T34)
format_gap_test() ->
    Diagnostic = #diagnostic{span = {4, 5, {4, 8}}, message = "expected Int, found String",
                             labels = [{{1, 10, {1, 13}}, "declared Int here"}]},
    ?assertEqual("main.ern:4:5: expected Int, found String\n"
                 "1 | fn f() : Int = {\n"
                 "  |          --- declared Int here\n"
                 "...\n"
                 "4 |     \"x\"\n"
                 "  |     ^^^\n",
                 lists:flatten(ern_diagnostic:format("main.ern",
                                                     "fn f() : Int = {\n    let a = 1;\n"
                                                     "    let b = 2;\n    \"x\"\n}\n",
                                                     Diagnostic))).

%% report §11.5: without labels or help, only the primary span; the gutter
%% widens with the line number; a span past the line's end underlines to
%% the end; a span with no width is one caret
format_plain_test() ->
    Lines = lists:duplicate(11, "x = 1\n"),
    Diagnostic = #diagnostic{span = {11, 5, {12, 1}}, message = "m"},
    ?assertEqual("f:11:5: m\n"
                 "10 | x = 1\n"
                 "11 | x = 1\n"
                 "   |     ^\n",
                 ern_diagnostic:format("f", Lines, Diagnostic)),
    ?assertEqual("f:1:3: m\n"
                 "1 | x = 1\n"
                 "  |   ^\n",
                 ern_diagnostic:format("f", "x = 1\n",
                                       #diagnostic{span = {1, 3, {1, 3}}, message = "m"})).

%% report §11.5: a token position becomes its span
span_test() ->
    ?assertEqual({1, 2, {1, 5}}, ern_diagnostic:span({1, 2, {1, 5}, {1, 1}})),
    ?assertEqual({1, 2, {1, 5}}, ern_diagnostic:span({1, 2, {1, 5}})).
