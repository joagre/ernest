%% The printer of Appendix E.1, by a type's descriptor and, where there is
%% none, by the runtime's representation (report §8.4).
-module(ern_show_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.1: by the descriptor of the argument's type
by_type_test() ->
    ?assertEqual(<<"'a'">>, ern_show:show(char, $a)),
    ?assertEqual(<<"\"hi\"">>, ern_show:show(string, <<"hi">>)),
    ?assertEqual(<<"<<104, 105>>">>, ern_show:show(bytes, <<"hi">>)),
    ?assertEqual(<<"#(1, true)">>, ern_show:show({tuple, [int, bool]}, {1, true})),
    Snap = {con, [{'Snap', [string, int], [dir, seen]}]},
    ?assertEqual(<<"Snap(dir = \"x\", seen = 2)">>, ern_show:show(Snap, {'Snap', <<"x">>, 2})),
    ?assertEqual(<<"<abstract>">>, ern_show:show({abstract, {con, []}}, {'Stack', []})).

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
