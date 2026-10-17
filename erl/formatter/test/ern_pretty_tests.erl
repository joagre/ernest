%% The printer of report §11.6's layout: each part of the algebra on a
%% small layout. Regression tests, written with the printer; ern_format_tests
%% has the layouts the style guide asks for.
-module(ern_pretty_tests).

-include_lib("eunit/include/eunit.hrl").

words(Count) ->
    lists:join(line, [<<"word">> || _ <- lists:seq(1, Count)]).

%% report §11.6: a group on one line when it fits in 100 columns, and
%% every break of it taken when it does not
group_test() ->
    ?assertEqual(<<"word word word\n">>, ern_pretty:render({group, words(3)})),
    Long = ern_pretty:render({group, words(30)}),
    ?assertEqual(30, length(binary:split(string:trim(Long), <<"\n">>, [global]))).

%% report §11.6: an aligned layout's breaks indent to the column it began at,
%% a nested one's a step further
align_and_nest_test() ->
    ?assertEqual(<<"f(a,\n  b)\n">>,
                 ern_pretty:render([<<"f(">>, {align, [<<"a,">>, hardline, <<"b)">>]}])),
    ?assertEqual(<<"x =\n    y\n">>,
                 ern_pretty:render([<<"x =">>, {nest, 4, [hardline, <<"y">>]}])).

%% report §11.6: a hug takes its first layout where the first line fits and
%% ends in a brace; a body takes its first where the body fits whole
choice_test() ->
    Braced = [<<"f(fn() = {">>, {nest, 4, [hardline, <<"x">>]}, hardline, <<"})">>],
    ?assertEqual(<<"f(fn() = {\n    x\n})\n">>,
                 ern_pretty:render({choice, hug, Braced, <<"other">>})),
    ?assertEqual(<<"other\n">>,
                 ern_pretty:render({choice, hug, [<<"no brace">>, hardline], <<"other">>})),
    Short = {choice, body, [<<" short">>], {nest, 4, [hardline, <<"short">>]}},
    ?assertEqual(<<"x = short\n">>, ern_pretty:render([<<"x =">>, Short])),
    LongBody = binary:copy(<<"y">>, 99),
    ?assertEqual(<<"x =\n    ", LongBody/binary, "\n">>,
                 ern_pretty:render([<<"x =">>, {choice, body, [<<" ">>, LongBody],
                                                 {nest, 4, [hardline, LongBody]}}])).

%% report §11.6: a body holding a choice that its own first line holds
%% whole is not whole for that. A regression test: the inner choice's mark
%% was taken for the outer's
nested_choice_test() ->
    Inner = {choice, body, [<<" inner">>], {nest, 4, [hardline, <<"inner">>]}},
    Body = [<<"f(">>, Inner, <<")">>, line, <<"|> ">>, binary:copy(<<"g">>, 90)],
    ?assertEqual(<<"x =\n    f( inner)\n    |> ", (binary:copy(<<"g">>, 90))/binary, "\n">>,
                 ern_pretty:render([<<"x =">>,
                                    {choice, body, [<<" ">>, Body],
                                     {nest, 4, [hardline, Body]}}])).

%% report §11.6: a clauses choice takes its first layout, a table, where
%% each whole in it stands whole on its line, and its second otherwise
clauses_test() ->
    Clauses = fun(Bodies) ->
                  Table = lists:join(hardline, [[<<"x ->">>, <<" ">>, {whole, Body}]
                                                || Body <- Bodies]),
                  Down = lists:join(hardline, [[<<"x ->">>, {nest, 4, [hardline, Body]}]
                                               || Body <- Bodies]),
                  {choice, clauses, Table, Down}
              end,
    ?assertEqual(<<"x -> a\nx -> b\n">>, ern_pretty:render(Clauses([<<"a">>, <<"b">>]))),
    Long = binary:copy(<<"y">>, 97),
    ?assertEqual(<<"x ->\n    a\nx ->\n    ", Long/binary, "\n">>,
                 ern_pretty:render(Clauses([<<"a">>, Long]))),
    ?assertEqual(<<"x ->\n    a\nx ->\n    b\n    c\n">>,
                 ern_pretty:render(Clauses([<<"a">>, [<<"b">>, hardline, <<"c">>]]))).

%% report §11.6: a trailing comment ends its line, and a group that code
%% would follow it in cannot stay on one line
suffix_test() ->
    ?assertEqual(<<"a // why\n">>, ern_pretty:render([<<"a">>, {suffix, <<" // why">>}])),
    ?assertEqual(<<"[1, // one\n 2]\n">>,
                 ern_pretty:render({group, [<<"[">>, {align, [<<"1,">>, {suffix, <<" // one">>},
                                                              line, <<"2">>]}, <<"]">>]})).

%% report §11.6: a blank line where a line break falls, none mid-line; no
%% space the layout wrote at a line's end, and a text's own spaces kept
blank_test() ->
    ?assertEqual(<<"a\n\nb\n">>, ern_pretty:render([<<"a">>, hardline, blank, <<"b">>])),
    ?assertEqual(<<"a b\n">>, ern_pretty:render([<<"a ">>, blank, <<"b">>])),
    ?assertEqual(<<"a\nb\n">>, ern_pretty:render([<<"a">>, <<" ">>, <<" ">>, hardline, <<"b">>])),
    ?assertEqual(<<"a  \nb\n">>, ern_pretty:render([<<"a  ">>, hardline, <<"b">>])).
