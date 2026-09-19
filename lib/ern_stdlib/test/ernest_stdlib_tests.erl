%% The stdlib modules of Appendix E, one test per module, and the
%% operations of report §9.6 that live in them.
-module(ernest_stdlib_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.2
list_test() ->
    L = 'ernest@list',
    ?assertEqual(3, L:size([1, 2, 3])),
    ?assertEqual(true, L:isEmpty([])),
    ?assertEqual({'Some', 2}, L:last([1, 2])),
    ?assertEqual('None', L:last([])),
    ?assertEqual({'Some', 2}, L:get([1, 2, 3], 1)),
    ?assertEqual('None', L:get([1, 2, 3], 3)),
    ?assertEqual('None', L:get([1, 2, 3], -1)),
    ?assertEqual([2, 1], L:reverse([1, 2])),
    ?assertEqual([1, 2], L:take([1, 2, 3], 2)),
    ?assertEqual([1, 2, 3], L:take([1, 2, 3], 5)),
    ?assertEqual([], L:take([1, 2, 3], -1)),
    ?assertEqual([3], L:drop([1, 2, 3], 2)),
    ?assertEqual([], L:drop([1, 2, 3], 5)),
    ?assertEqual([1, 2, 3], L:drop([1, 2, 3], -1)),
    ?assertEqual([1, 2], L:dropLast([1, 2, 3])),
    ?assertEqual([], L:dropLast([])),
    ?assertEqual(true, L:contains([1, 2], 2)),
    ?assertEqual({'Some', 2}, L:find([1, 2, 3], fun(X) -> X > 1 end)),
    ?assertEqual('None', L:find([1], fun(X) -> X > 1 end)),
    ?assertEqual(true, L:any([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual(false, L:all([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual([2, 4], L:map([1, 2], fun(X) -> X * 2 end)),
    ?assertEqual([2], L:filter([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual([20], L:filterMap([1, 2], fun(1) -> 'None'; (X) -> {'Some', X * 10} end)),
    ?assertEqual(6, L:foldLeft([1, 2, 3], 0, fun(A, X) -> A + X end)),
    ?assertEqual('Unit', L:foreach([1], fun(_) -> 'Unit' end)),
    ?assertEqual({[1, 2], [3, 1]}, L:span([1, 2, 3, 1], fun(X) -> X < 3 end)),
    ?assertEqual({[1, 2, 1], [3]}, L:partition([1, 2, 3, 1], fun(X) -> X < 3 end)),
    ?assertEqual([2, 1, 3], L:unique([2, 1, 2, 3, 1])),
    ?assertEqual([{0, a}, {1, b}], L:indexed([a, b])),
    ?assertEqual([x, x], L:repeat(x, 2)),
    ?assertEqual([], L:repeat(x, -1)),
    ?assertEqual({[1, 2], [a, b]}, L:unzip([{1, a}, {2, b}])),
    ?assertEqual({'Right', [2, 4]}, L:tryMap([1, 2], fun(X) -> {'Right', X * 2} end)),
    Even = fun(X) when X rem 2 =:= 0 -> {'Right', X}; (_) -> {'Left', odd} end,
    ?assertEqual({'Left', odd}, L:tryMap([2, 3, 4], Even)),
    ?assertEqual({'Right', 3}, L:tryFold([1, 2], 0, fun(A, X) -> {'Right', A + X} end)),
    Bounded = fun(A, X) when A + X > 2 -> {'Left', big}; (A, X) -> {'Right', A + X} end,
    ?assertEqual({'Left', big}, L:tryFold([1, 2, 3], 0, Bounded)),
    ?assertEqual([1, 2, 3], L:sort([3, 1, 2], fun 'ernest@int':compare/2)),
    ?assertEqual([1, 3, 2], L:remove([1, 2, 3, 2], 2)),
    ?assertEqual([{1, a}, {2, b}], L:zip([1, 2, 3], [a, b])),
    ?assertEqual([1, 1, 2, 2], L:flatMap([1, 2], fun(X) -> [X, X] end)),
    ?assertEqual([2, 3, 4], L:range(2, 4)),
    ?assertEqual([], L:range(3, 2)).

%% report Appendix E.3, §3.10
map_test() ->
    M = 'ernest@map',
    E = M:empty(),
    ?assertEqual(true, M:isEmpty(E)),
    M1 = M:put(M:put(E, a, 1), b, 2),
    ?assertEqual(2, M:size(M1)),
    ?assertEqual(true, M:contains(M1, a)),
    ?assertEqual({'Some', 2}, M:get(M1, b)),
    ?assertEqual('None', M:get(M1, c)),
    ?assertEqual(1, M:size(M:remove(M1, a))),
    Count = fun({'Some', V}) -> V + 1; ('None') -> 0 end,
    ?assertEqual({'Some', 2}, M:get(M:update(M1, a, Count), a)),
    ?assertEqual({'Some', 0}, M:get(M:update(M1, z, Count), z)),
    ?assertEqual([a, b], lists:sort(M:keys(M1))),
    ?assertEqual([1, 2], lists:sort(M:values(M1))),
    ?assertEqual({'Some', 20}, M:get(M:map(M1, fun(_, V) -> V * 10 end), b)),
    ?assertEqual(3, M:foldLeft(M1, 0, fun(A, _, V) -> A + V end)),
    ?assert(M:put(M:put(E, a, 1), b, 2) =:= M:put(M:put(E, b, 2), a, 1)),
    ?assertEqual([{b, 2}], M:toList(M:filter(M1, fun(_, V) -> V > 1 end))),
    ?assertEqual([{b, 20}], M:toList(M:filterMap(M1, fun(_, 1) -> 'None';
                                                       (_, V) -> {'Some', V * 10} end))),
    ?assertEqual('Unit', M:foreach(M1, fun(_, _) -> 'Unit' end)),
    ?assertEqual(true, M:any(M1, fun(K, _) -> K =:= a end)),
    ?assertEqual(false, M:all(M1, fun(_, V) -> V > 1 end)),
    ?assertEqual({'Some', {b, 2}}, M:find(M1, fun(_, V) -> V =:= 2 end)),
    ?assertEqual('None', M:find(M1, fun(_, V) -> V =:= 3 end)),
    ?assertEqual(M1, M:fromList([{a, 0}, {a, 1}, {b, 2}])),
    ?assertEqual([{a, 1}, {b, 3}], lists:sort(M:toList(M:merge(M1, M:fromList([{b, 3}]))))),
    ?assertEqual([{a, 1}, {b, 2}], lists:sort(M:toList(M1))).

%% report Appendix E.4, §3.10
set_test() ->
    S = 'ernest@set',
    ?assertEqual(true, S:isEmpty(S:empty())),
    S1 = S:put(S:put(S:put(S:empty(), 1), 2), 2),
    ?assertEqual(2, S:size(S1)),
    ?assertEqual(true, S:contains(S1, 2)),
    ?assertEqual(false, S:contains(S:remove(S1, 2), 2)),
    ?assertEqual([1, 2, 3], lists:sort(S:toList(S:union(S1, S:fromList([3]))))),
    ?assertEqual([2], S:toList(S:intersect(S1, S:fromList([2, 3])))),
    ?assertEqual([1], S:toList(S:difference(S1, S:fromList([2, 3])))),
    ?assertEqual(true, S:isSubset(S:fromList([2]), S1)),
    ?assertEqual(false, S:isSubset(S1, S:fromList([2]))),
    ?assert(S:fromList([1, 2]) =:= S:fromList([2, 1])),
    ?assertEqual([2, 4], lists:sort(S:toList(S:map(S1, fun(X) -> X * 2 end)))),
    ?assertEqual([2], S:toList(S:filter(S1, fun(X) -> X > 1 end))),
    ?assertEqual([20], S:toList(S:filterMap(S1, fun(1) -> 'None'; (X) -> {'Some', X * 10} end))),
    ?assertEqual('Unit', S:foreach(S1, fun(_) -> 'Unit' end)),
    ?assertEqual(3, S:foldLeft(S1, 0, fun(A, X) -> A + X end)),
    ?assertEqual(true, S:any(S1, fun(X) -> X > 1 end)),
    ?assertEqual(false, S:all(S1, fun(X) -> X > 1 end)),
    ?assertEqual({'Some', 2}, S:find(S1, fun(X) -> X > 1 end)),
    ?assertEqual('None', S:find(S1, fun(X) -> X > 2 end)).

%% report Appendix E.5, §9.6
string_test() ->
    S = 'ernest@string',
    ?assertEqual(2, S:size(<<"hé"/utf8>>)),
    ?assertEqual(true, S:isEmpty(<<>>)),
    ?assertEqual(true, S:contains(<<"hello">>, <<"ell">>)),
    ?assertEqual(true, S:startsWith(<<"hello">>, <<"he">>)),
    ?assertEqual(false, S:startsWith(<<"hello">>, <<"lo">>)),
    ?assertEqual(true, S:endsWith(<<"héllo"/utf8>>, <<"llo">>)),
    ?assertEqual(false, S:endsWith(<<"he">>, <<"hello">>)),
    ?assertEqual(<<"hella wald">>, S:replace(<<"hello wold">>, <<"o">>, <<"a">>)),
    ?assertEqual(<<"abc">>, S:replace(<<"abc">>, <<>>, <<"x">>)),
    ?assertEqual(<<"éll"/utf8>>, S:slice(<<"héllo"/utf8>>, 1, 3)),
    ?assertEqual(<<"lo">>, S:slice(<<"hello">>, 3, 10)),
    ?assertEqual(<<>>, S:slice(<<"hello">>, -1, -1)),
    ?assertEqual(<<"007">>, S:padStart(<<"7">>, 3, $0)),
    ?assertEqual(<<"7  ">>, S:padEnd(<<"7">>, 3, $\s)),
    ?assertEqual(<<"hello">>, S:padStart(<<"hello">>, 3, $0)),
    ?assertEqual(<<"ababab">>, S:repeat(<<"ab">>, 3)),
    ?assertEqual(<<>>, S:repeat(<<"ab">>, -1)),
    ?assertEqual(<<"a b">>, S:trim(<<" \ta b\n">>)),
    ?assertEqual(<<"abc">>, S:toLower(<<"AbC">>)),
    ?assertEqual({'Some', -12}, S:toInt(<<"-12">>)),
    ?assertEqual('None', S:toInt(<<"1a">>)),
    ?assertEqual('None', S:toInt(<<"-">>)),
    ?assertEqual('None', S:toInt(<<>>)),
    ?assertEqual({'Some', -1.5}, S:toFloat(<<"-1.5">>)),
    ?assertEqual({'Some', 1.0e-9}, S:toFloat(<<"1.0e-9">>)),
    ?assertEqual('None', S:toFloat(<<"1">>)),
    ?assertEqual('None', S:toFloat(<<"1e5">>)),
    ?assertEqual('None', S:toFloat(<<"1.0e999">>)),
    ?assertEqual(<<"ABC">>, S:toUpper(<<"abC">>)),
    ?assertEqual([$a, $b], S:toList(<<"ab">>)),
    ?assertEqual(<<"ab">>, S:fromList([$a, $b])),
    ?assertEqual({'Some', <<"ab">>}, S:fromUtf8(<<"ab">>)),
    ?assertEqual('None', S:fromUtf8(<<255>>)),
    ?assertEqual(<<"ab">>, S:toUtf8(<<"ab">>)),
    ?assertEqual([<<"a">>, <<"b">>], S:lines(<<"a\nb\n">>)),
    ?assertEqual([<<"a">>, <<>>, <<"b">>], S:lines(<<"a\n\nb">>)),
    ?assertEqual([], S:lines(<<>>)),
    ?assertEqual([<<"a">>, <<>>, <<"b">>], S:split(<<"a,,b">>, <<",">>)),
    ?assertEqual([<<>>], S:split(<<>>, <<",">>)),
    ?assertEqual(<<"a, b">>, S:join([<<"a">>, <<"b">>], <<", ">>)),
    ?assertEqual(<<>>, S:join([], <<", ">>)),
    ?assertEqual('Less', S:compare(<<"a">>, <<"b">>)),
    ?assertEqual('Equal', S:compare(<<"a">>, <<"a">>)).

%% report Appendix E.6, §9.6
char_test() ->
    C = 'ernest@char',
    ?assertEqual(true, C:isDigit($7)),
    ?assertEqual(true, C:isDigit(16#663)),
    ?assertEqual(false, C:isDigit($a)),
    ?assertEqual(true, C:isAlpha($z)),
    ?assertEqual(true, C:isAlpha(16#4E2D)),
    ?assertEqual(false, C:isAlpha($1)),
    ?assertEqual(false, C:isAlpha(16#663)),
    ?assertEqual(true, C:isSpace($\n)),
    ?assertEqual(true, C:isSpace($\s)),
    ?assertEqual(false, C:isSpace($a)),
    ?assertEqual(true, C:isSpace(16#85)),
    ?assertEqual(true, C:isSpace(16#3000)),
    ?assertEqual(false, C:isSpace(16#200E)),
    ?assertEqual(true, C:isUpper($A)),
    ?assertEqual(false, C:isUpper($a)),
    ?assertEqual(true, C:isLower(16#E9)),
    ?assertEqual(false, C:isLower(16#C9)),
    ?assertEqual($A, C:toUpper($a)),
    ?assertEqual(16#C9, C:toUpper(16#E9)),
    ?assertEqual(16#DF, C:toUpper(16#DF)),
    ?assertEqual($a, C:toLower($A)),
    ?assertEqual($1, C:toLower($1)),
    ?assertEqual({'Some', 16#E9}, C:fromInt(16#E9)),
    ?assertEqual('None', C:fromInt(16#D800)),
    ?assertEqual('None', C:fromInt(16#110000)),
    ?assertEqual('None', C:fromInt(-1)),
    ?assertEqual(<<"é"/utf8>>, C:toString(16#E9)),
    ?assertEqual(16#E9, C:toInt(16#E9)),
    ?assertEqual('Greater', C:compare($b, $a)).

%% report Appendix E.7
%% report Appendix E.19
erl_test() ->
    ?assertEqual(ready, 'ernest@erl':atom(<<"ready">>)).

bool_test() ->
    ?assertEqual(false, 'ernest@bool':'not'(true)),
    ?assertEqual(<<"true">>, 'ernest@bool':toString(true)).

%% report Appendix E.8, §3.1, §7.4, §9.6
int_test() ->
    I = 'ernest@int',
    ?assertEqual(3, I:abs(-3)),
    ?assertEqual(1, I:min(1, 2)),
    ?assertEqual(2, I:max(1, 2)),
    ?assertEqual(2, I:bitAnd(6, 3)),
    ?assertEqual(7, I:bitOr(6, 3)),
    ?assertEqual(5, I:bitXor(6, 3)),
    ?assertEqual(-7, I:bitNot(6)),
    ?assertEqual(12, I:shiftLeft(3, 2)),
    ?assertEqual(-2, I:shiftRight(-7, 2)),
    ?assertEqual(<<"-7">>, I:toString(-7)),
    ?assertEqual(7.0, I:toFloat(7)),
    ?assertThrow({ernest, fault, <<"Int out of Float range">>}, I:toFloat(1 bsl 2000)),
    ?assertEqual({'Some', -2}, I:'div'(-7, 3)),
    ?assertEqual({'Some', -1}, I:'mod'(-7, 3)),
    ?assertEqual('None', I:'div'(1, 0)),
    ?assertEqual('Less', I:compare(1, 2)),
    ?assertEqual(-1, I:negate(1)).

%% report Appendix E.9, §3.1, §7.4, §9.6
float_test() ->
    F = 'ernest@float',
    ?assertEqual(3.5, F:'+'(F:'*'(1.5, 2.0), 0.5)),
    ?assertEqual(-1.0, F:'-'(1.0, 2.0)),
    ?assertEqual(0.5, F:'/'(1.0, 2.0)),
    ?assertThrow({ernest, fault, <<"float arithmetic error">>}, F:'/'(1.0, 0.0)),
    ?assertThrow({ernest, fault, <<"float arithmetic error">>}, F:'*'(1.0e308, 10.0)),
    ?assertEqual(1.5, F:abs(-1.5)),
    ?assertEqual(0.0, F:abs(-0.0)),
    ?assertEqual(2.0, F:abs(2.0)),
    ?assertEqual(1.0, F:min(1.0, 2.0)),
    ?assertEqual(2.0, F:max(1.0, 2.0)),
    ?assertEqual(<<"0.1">>, F:toString(0.1)),
    ?assertEqual(<<"100.0">>, F:toString(100.0)),
    ?assertEqual(2, F:round(2.5)),
    ?assertEqual(4, F:round(3.5)),
    ?assertEqual(-2, F:round(-2.5)),
    ?assertEqual(3, F:round(2.7)),
    ?assertEqual(-3, F:floor(-2.5)),
    ?assertEqual(-2, F:ceil(-2.5)),
    ?assertEqual('Greater', F:compare(2.0, 1.0)),
    ?assertEqual(-1.0, F:negate(1.0)).

%% report Appendix E.10
optional_test() ->
    O = 'ernest@optional',
    ?assertEqual(true, O:isSome({'Some', 1})),
    ?assertEqual(true, O:isNone('None')),
    ?assertEqual(1, O:withDefault({'Some', 1}, 0)),
    ?assertEqual(0, O:withDefault('None', 0)),
    ?assertEqual({'Some', 2}, O:map({'Some', 1}, fun(X) -> X + 1 end)),
    ?assertEqual('None', O:andThen({'Some', 1}, fun(_) -> 'None' end)).

%% report Appendix E.11
either_test() ->
    E = 'ernest@either',
    ?assertEqual(true, E:isLeft({'Left', e})),
    ?assertEqual(true, E:isRight({'Right', 1})),
    ?assertEqual(1, E:withDefault({'Right', 1}, 0)),
    ?assertEqual(0, E:withDefault({'Left', e}, 0)),
    ?assertEqual({'Right', 2}, E:map({'Right', 1}, fun(X) -> X + 1 end)),
    ?assertEqual({'Left', f}, E:mapLeft({'Left', e}, fun(e) -> f end)),
    ?assertEqual({'Left', e}, E:andThen({'Left', e}, fun(X) -> {'Right', X} end)),
    ?assertEqual({'Some', 1}, E:toOptional({'Right', 1})),
    ?assertEqual({'Left', e}, E:fromOptional('None', e)).

%% report Appendix E.12, §3.8, §8.4
foreign_test() ->
    F = 'ernest@foreign',
    ?assertEqual({'Some', 3}, F:toInt(3)),
    ?assertEqual('None', F:toInt(3.0)),
    ?assertEqual({'Some', 1.5}, F:toFloat(1.5)),
    ?assertEqual('None', F:toFloat(1)),
    ?assertEqual({'Some', <<"s">>}, F:toString(<<"s">>)),
    ?assertEqual('None', F:toString(<<255>>)),
    ?assertEqual('None', F:toString("s")),
    ?assertEqual({'Some', true}, F:toBool(true)),
    ?assertEqual('None', F:toBool(1)),
    ?assertEqual({'Some', [1, x]}, F:toList([1, x])),
    ?assertEqual('None', F:toList(<<>>)).

%% report Appendix E.13: the same seed gives the same sequence, every draw
%% is within the bounds on either side of zero, and the seed moves
random_test() ->
    R = 'ernest@random',
    Draw = fun Draw(_, _, 0) -> [];
               Draw(S, B, N) -> {X, S1} = R:next(S, B), [X | Draw(S1, B, N - 1)] end,
    Xs = Draw(R:seed(42), 5, 200),
    ?assertEqual(Xs, Draw(R:seed(42), 5, 200)),
    ?assert(lists:all(fun(X) -> X >= 0 andalso X =< 5 end, Xs)),
    ?assertEqual([0, 1, 2, 3, 4, 5], lists:usort(Xs)),
    Ys = Draw(R:seed(42), -3, 200),
    ?assertEqual([-3, -2, -1, 0], lists:usort(Ys)),
    ?assertEqual([0, 0], Draw(R:seed(1), 0, 2)),
    {_, S1} = R:next(R:seed(7), 1),
    ?assertNotEqual(R:seed(7), S1).

%% report Appendix E.14, §9.3
path_test() ->
    P = 'ernest@path',
    ?assertEqual({'Path', <<"a/b">>}, P:join({'Path', <<"a">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"a/b">>}, P:join({'Path', <<"a/">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"/b">>}, P:join({'Path', <<"a">>}, {'Path', <<"/b">>})),
    ?assertEqual([<<"/">>, <<"a">>, <<"b">>], P:split({'Path', <<"/a/b">>})),
    ?assertEqual([<<"a">>, <<"b">>], P:split({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"a">>}}, P:parent({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"/">>}}, P:parent({'Path', <<"/a">>})),
    ?assertEqual('None', P:parent({'Path', <<"a">>})),
    ?assertEqual('None', P:parent({'Path', <<"/">>})),
    ?assertEqual(<<"b.txt">>, P:name({'Path', <<"a/b.txt">>})),
    ?assertEqual({'Some', <<"txt">>}, P:extension({'Path', <<"a/b.txt">>})),
    ?assertEqual('None', P:extension({'Path', <<"a/b">>})),
    ?assertEqual({'Path', <<"a/b.md">>}, P:withExtension({'Path', <<"a/b.txt">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b.md">>}, P:withExtension({'Path', <<"a/b">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b">>}, P:withExtension({'Path', <<"a/b.txt">>}, <<>>)),
    ?assertEqual(true, P:isAbsolute({'Path', <<"/a">>})),
    ?assertEqual(false, P:isAbsolute({'Path', <<"a">>})),
    ?assertEqual(<<"a">>, P:toString({'Path', <<"a">>})).

%% report §6.7: no peer is configured in MVP 1
remote_test() ->
    ?assertEqual({'Left', 'NoRemotePeer'}, ern_rt:remote(fun() -> 1 end)),
    ?assertEqual([{'Left', 'NoRemotePeer'}], ern_rt:parallel_remote([fun() -> 1 end])).

%% report §7.4
todo_test() ->
    ?assertThrow({ernest, fault, <<"todo: x">>}, ern_rt:todo(<<"x">>)).
