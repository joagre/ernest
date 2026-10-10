%% The printer of Appendix E.1, by a type's descriptor and, where there is
%% none, by the runtime's representation (report §8.4).
-module(ern_show_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.1, §2.5: a string shows each control character as its
%% escape, one of U+0080 to U+009F among them. A regression test: those
%% were written as they were, U+009B the start of a terminal's command
controls_shown_test() ->
    ?assertEqual(<<"\"a\\u{1B}\\u{9B}b\\n\"">>,
                 ern_show:show(string, <<"a", 16#1B, 16#9B/utf8, "b\n">>)),
    ?assertEqual(<<"a\\u{9B}\\nb">>, ern_show:controls(<<"a", 16#9B/utf8, "\nb">>, line)),
    ?assertEqual(<<"a\\u{9B}\nb">>, ern_show:controls(<<"a", 16#9B/utf8, "\nb">>, lines)).

%% report Appendix E.1: by the descriptor of the argument's type
by_type_test() ->
    ?assertEqual(<<"'a'">>, ern_show:show(char, $a)),
    %% a negative number with `-` before it; a regression test, written after
    %% the code
    ?assertEqual(<<"#(-1, -2.5)">>, ern_show:show({tuple, [int, float]}, {-1, -2.5})),
    ?assertEqual(<<"\"hi\"">>, ern_show:show(string, <<"hi">>)),
    ?assertEqual(<<"<<104, 105>>">>, ern_show:show(bytes, <<"hi">>)),
    ?assertEqual(<<"#(1, true)">>, ern_show:show({tuple, [int, bool]}, {1, true})),
    Snap = {con, [{'Snap', [string, int], [dir, seen]}]},
    ?assertEqual(<<"Snap(dir = \"x\", seen = 2)">>, ern_show:show(Snap, {'Snap', <<"x">>, 2})),
    ?assertEqual(<<"<abstract>">>, ern_show:show({abstract, {con, []}}, {'Stack', []})),
    ?assertEqual(<<"<foreign>">>, ern_show:show(foreign, 1)).

%% report Appendix E.1, E.21: a process by its number, and an address by
%% the number of the process behind it, through every adapted address
identity_test() ->
    Pid = list_to_pid("<0.84.0>"),
    ?assertEqual(<<"<process 84>">>, ern_show:show(process, Pid)),
    ?assertEqual(<<"<address 84>">>, ern_show:show({address, any, <<>>}, Pid)),
    ?assertEqual(<<"<address 84>">>,
                 ern_show:show({address, any, <<>>}, ern_rt:adapted(Pid, fun(X) -> X end))),
    %% and where the type is a variable, by the representation. A
    %% regression test: an adapted address read as a tuple,
    %% `#(adapted, <function>, <address 84>)`
    ?assertEqual(<<"<address 84>">>, ern_show:show(any, ern_rt:adapted(Pid, fun(X) -> X end))).

%% report Appendix E.1: a foreign value reads by the representation, and as
%% <foreign> where it reads as none of Ernest's forms; an improper list,
%% which only foreign code can make, is one such
representation_test() ->
    ?assertEqual(<<"97">>, ern_show:show(any, $a)),
    ?assertEqual(<<"[1, 2]">>, ern_show:show(any, [1, 2])),
    ?assertEqual(<<"<foreign>">>, ern_show:show(any, [1 | 2])),
    ?assertEqual(<<"#(ok, 1)">>, ern_show:show(any, {ok, 1})),
    ?assertEqual(<<"Ready(1)">>, ern_show:show(any, {'Ready', 1})),
    ?assertEqual(<<"false">>, ern_show:show(any, false)).
