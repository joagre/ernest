%% ern_diag renders report §11.5's error format.
-module(ern_diag_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-define(SRC, "fn g() -> Int =\n    f(\"x\")\nfn f(n : Int) -> Int = n\n").

%% report §11.5: the first line is file:line:column: message
short_test() ->
    D = #diag{span = {2, 7, {2, 10}}, message = "expected Int, found String"},
    ?assertEqual("main.ern:2:7: expected Int, found String", ern_diag:short("main.ern", D)).

%% report §11.5: the source with a gutter, the line before, the span
%% underlined with ^, a label's span with - and its text, and the help line
format_test() ->
    D = #diag{span = {2, 7, {2, 10}}, message = "expected Int, found String",
              labels = [{{1, 11, {1, 14}}, "declared to return Int here"}],
              help = "give f an Int"},
    ?assertEqual("main.ern:2:7: expected Int, found String\n"
                 "1 | fn g() -> Int =\n"
                 "  |           --- declared to return Int here\n"
                 "2 |     f(\"x\")\n"
                 "  |       ^^^\n"
                 "  | = help: give f an Int\n",
                 ern_diag:format("main.ern", ?SRC, D)).

%% report §11.5: without labels or help, only the primary span; the gutter
%% widens with the line number; a span past the line's end underlines to
%% the end; a span with no width is one caret
format_plain_test() ->
    Lines = lists:duplicate(11, "x = 1\n"),
    D = #diag{span = {11, 5, {12, 1}}, message = "m"},
    ?assertEqual("f:11:5: m\n"
                 "10 | x = 1\n"
                 "11 | x = 1\n"
                 "   |     ^\n",
                 ern_diag:format("f", Lines, D)),
    ?assertEqual("f:1:3: m\n"
                 "1 | x = 1\n"
                 "  |   ^\n",
                 ern_diag:format("f", "x = 1\n", #diag{span = {1, 3, {1, 3}}, message = "m"})).

%% report §11.5: a token position becomes its span
span_test() ->
    ?assertEqual({1, 2, {1, 5}}, ern_diag:span({1, 2, {1, 5}, {1, 1}})),
    ?assertEqual({1, 2, {1, 5}}, ern_diag:span({1, 2, {1, 5}})).
