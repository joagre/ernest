%% The stdlib modules of Appendix E, one test per module, and the
%% operations of report §9.6 that live in them.
-module(ern_stdlib_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.2
list_test() ->
    L = 'ern@list',
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
    ?assertEqual([1, 2], L:dropLast([1, 2, 3], 1)),
    ?assertEqual([], L:dropLast([], 1)),
    %% report Appendix E.2: a count, as drop takes one, a regression test of the
    %% rule of 2026-10-01; one past the length leaves none, one below 0 all
    ?assertEqual([1], L:dropLast([1, 2, 3], 2)),
    ?assertEqual([], L:dropLast([1, 2], 5)),
    ?assertEqual([1, 2], L:dropLast([1, 2], -1)),
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
    %% the predicate meets the elements in order; a regression test, it met
    %% them from the last (findings.md's E11)
    Seen = fun(X) -> put(seen, [X | get(seen)]), X > 1 end,
    put(seen, []),
    _ = L:partition([1, 2, 3], Seen),
    ?assertEqual([1, 2, 3], lists:reverse(get(seen))),
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
    ?assertEqual(<<"ab">>, L:foldRight([<<"a">>, <<"b">>], <<>>,
                                       fun(X, Acc) -> <<X/binary, Acc/binary>> end)),
    ?assertEqual([1, 2, 3], L:sort([3, 1, 2], fun 'ern@int':compare/2)),
    %% report Appendix E.2: sort is stable, and orders a long list as
    %% Erlang's does
    ByFirst = fun({A, _}, {B, _}) -> 'ern@int':compare(A, B) end,
    ?assertEqual([{1, a}, {1, b}, {2, c}],
                 L:sort([{1, a}, {2, c}, {1, b}], ByFirst)),
    Many = [(N * 7919) rem 1009 || N <- lists:seq(1, 2000)],
    ?assertEqual(lists:sort(Many), L:sort(Many, fun 'ern@int':compare/2)),
    ?assertEqual([1, 3, 2], L:remove([1, 2, 3, 2], 2)),
    ?assertEqual([{1, a}, {2, b}], L:zip([1, 2, 3], [a, b])),
    ?assertEqual([1, 1, 2, 2], L:flatMap([1, 2], fun(X) -> [X, X] end)),
    ?assertEqual([2, 3, 4], L:range(2, 4)),
    ?assertEqual([], L:range(3, 2)).

%% report §8.4: foreign code receives a Map as a map from each key's term to
%% its value's term, and a Set as {set, S}, S a version 2 set, which is a map
%% from each element to []. A regression test, written after the report
%% gave the terms
map_set_terms_test() ->
    ern_rt:init_stdlib(),
    M = 'ern@map',
    S = 'ern@set',
    ?assertEqual(#{a => 1}, M:put(M:empty(), a, 1)),
    ?assertEqual({set, #{a => []}}, S:put(S:empty(), a)).

%% report Appendix E.3, §3.10
map_test() ->
    %% report §8.5: Map.empty is a top-level let, evaluated at program start
    ern_rt:init_stdlib(),
    M = 'ern@map',
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
    ern_rt:init_stdlib(),
    S = 'ern@set',
    ?assertEqual(true, S:isEmpty(S:empty())),
    S1 = S:put(S:put(S:put(S:empty(), 1), 2), 2),
    ?assertEqual(2, S:size(S1)),
    ?assertEqual(true, S:contains(S1, 2)),
    ?assertEqual(false, S:contains(S:remove(S1, 2), 2)),
    ?assertEqual([1, 2, 3], lists:sort(S:toList(S:union(S1, S:fromList([3]))))),
    ?assertEqual([2], S:toList(S:intersection(S1, S:fromList([2, 3])))),
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

%% report Appendix E.5, E.0 rule 1: the searches written over indexOf match
%% whole graphemes, so a letter under a combining mark is not found alone;
%% an empty part is at the start and the end; the trims strip White_Space
%% by Char.isSpace, U+00A0 and U+3000 among it and U+200E not; case mapping
%% is full, without the rules of a language or a context. Written with the
%% searches' move to Ernest; the earlier shims split and ended by bytes.
string_graphemes_test() ->
    S = 'ern@string',
    E = <<"e\x{301}"/utf8>>,
    ?assertEqual(false, S:contains(E, <<"e">>)),
    ?assertEqual([E], S:split(E, <<"e">>)),
    ?assertEqual(false, S:startsWith(E, <<"e">>)),
    ?assertEqual(false, S:endsWith(<<"ae\x{301}"/utf8>>, <<"\x{301}"/utf8>>)),
    ?assertEqual(E, S:replace(E, <<"e">>, <<"x">>)),
    ?assertEqual([<<"a">>, <<"b">>, <<>>], S:split(<<"a,b,">>, <<",">>)),
    ?assertEqual(true, S:contains(<<"abc">>, <<>>)),
    ?assertEqual(true, S:startsWith(<<"abc">>, <<>>)),
    ?assertEqual(true, S:endsWith(<<"abc">>, <<>>)),
    ?assertEqual(<<"a">>, S:trim(<<"\x{a0}a\x{3000}"/utf8>>)),
    ?assertEqual(<<"\x{200e}a"/utf8>>, S:trimStart(<<" \x{200e}a"/utf8>>)),
    ?assertEqual(<<"a ">>, S:trimStart(<<"\r\n a ">>)),
    ?assertEqual(<<" a">>, S:trimEnd(<<" a \r\n">>)),
    %% report Appendix E.5: a grapheme is removed by its first code point, a
    %% space that a combining mark joins among them, and one a prepended
    %% code point begins is kept; the fast pass over ASCII meets none of
    %% them. A regression test for the pass that replaced a list of every
    %% grapheme, 34 times the host's trim over 100 KB
    ?assertEqual(<<"a">>, S:trimEnd(<<"a \x{301}\t"/utf8>>)),
    ?assertEqual(<<"a\x{600} "/utf8>>, S:trimEnd(<<"a\x{600} \n"/utf8>>)),
    ?assertEqual(<<"é"/utf8>>, S:trimEnd(<<"é\x{3000}"/utf8>>)),
    ?assertEqual(<<>>, S:trimEnd(<<" \r\n\x{2028}"/utf8>>)),
    ?assertEqual(<<>>, S:trimEnd(<<>>)),
    ?assertEqual(<<"SS">>, S:toUpper(<<"ß"/utf8>>)),
    ?assertEqual(<<"σασ"/utf8>>, S:toLower(<<"ΣΑΣ"/utf8>>)),
    ?assertEqual('Less', S:compare(<<"z">>, <<"é"/utf8>>)).

%% report Appendix E.5: a search matches whole graphemes, beginning where
%% the string's own graphemes begin as well as ending where they end, so
%% `split` and `replace` keep every grapheme whole; `lines` ends a line at
%% a carriage return with a line feed, one grapheme, as at a line feed. A
%% regression test: a part that began inside a grapheme, a lone combining
%% mark, the line feed of a carriage return's, one person of a joined emoji,
%% was found there, and splitting at it lost the grapheme's first part
string_searches_begin_at_a_grapheme_test() ->
    S = 'ern@string',
    Mark = <<"\x{301}"/utf8>>,
    Family = <<"x\x{1F468}\x{200D}\x{1F469}y"/utf8>>,
    ?assertEqual('None', S:indexOf(<<"e\x{301}x"/utf8>>, Mark)),
    ?assertEqual([<<"e\x{301}x"/utf8>>], S:split(<<"e\x{301}x"/utf8>>, Mark)),
    ?assertEqual([<<"a\r\nb">>], S:split(<<"a\r\nb">>, <<"\n">>)),
    ?assertEqual(Family, S:replace(Family, <<"\x{1F469}"/utf8>>, <<"X">>)),
    ?assertEqual({'Some', 2}, S:lastIndexOf(<<"aa\x{301}a"/utf8>>, <<"a">>)),
    ?assertEqual([<<"a">>, <<"b">>], S:lines(<<"a\r\nb\r\n">>)),
    ?assertEqual([<<"a">>, <<"b">>], S:lines(<<"a\nb">>)).

%% report Appendix E.5: `words` splits at runs of White_Space, the Unicode
%% property, a no-break space and a line separator among them, and gives
%% no empty word. Written with the code, of 2026-10-01
string_words_test() ->
    S = 'ern@string',
    ?assertEqual([], S:words(<<>>)),
    ?assertEqual([<<"a">>], S:words(<<"a">>)),
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>],
                 S:words(<<" a\x{A0}b\x{2028}\r\n c "/utf8>>)),
    ?assertEqual([<<"e\x{301}"/utf8>>], S:words(<<"e\x{301}"/utf8>>)).

%% report Appendix E.5: `split`, `lines` and `replace` read the string
%% once. A regression test: each part measured the rest again, a cost that
%% grew as the square of the parts, 2.6 s for 16,000 of them; 64,000 now
%% take a fraction of EUnit's five seconds, and took about forty before
string_split_reads_once_test() ->
    S = 'ern@string',
    Text = iolist_to_binary(lists:duplicate(64000, <<"abcd,">>)),
    ?assertEqual(64001, length(S:split(Text, <<",">>))),
    ?assertEqual(64000, length(S:lines(binary:replace(Text, <<",">>, <<"\n">>, [global])))),
    ?assertEqual(byte_size(Text), byte_size(S:replace(Text, <<",">>, <<";">>))).

%% report Appendix E.5, §9.6
string_test() ->
    S = 'ern@string',
    ?assertEqual(2, S:size(<<"hé"/utf8>>)),
    ?assertEqual(true, S:isEmpty(<<>>)),
    ?assertEqual(true, S:contains(<<"hello">>, <<"ell">>)),
    ?assertEqual({'Some', 2}, S:indexOf(<<"hello">>, <<"ll">>)),
    ?assertEqual('None', S:indexOf(<<"hello">>, <<"x">>)),
    ?assertEqual({'Some', 3}, S:lastIndexOf(<<"hello">>, <<"l">>)),
    ?assertEqual(true, S:startsWith(<<"hello">>, <<"he">>)),
    ?assertEqual(false, S:startsWith(<<"hello">>, <<"lo">>)),
    ?assertEqual(true, S:endsWith(<<"héllo"/utf8>>, <<"llo">>)),
    ?assertEqual(false, S:endsWith(<<"he">>, <<"hello">>)),
    ?assertEqual(<<"hella wald">>, S:replace(<<"hello wold">>, <<"o">>, <<"a">>)),
    ?assertEqual(<<"abc">>, S:replace(<<"abc">>, <<>>, <<"x">>)),
    ?assertEqual(<<"éll"/utf8>>, S:slice(<<"héllo"/utf8>>, 1, 3)),
    ?assertEqual(<<"lo">>, S:slice(<<"hello">>, 3, 10)),
    ?assertEqual(<<>>, S:slice(<<"hello">>, -1, -1)),
    ?assertEqual(<<"007">>, S:padStart(<<"7">>, 3, <<"0">>)),
    ?assertEqual(<<"7  ">>, S:padEnd(<<"7">>, 3, <<" ">>)),
    ?assertEqual(<<"hello">>, S:padStart(<<"hello">>, 3, <<"0">>)),
    %% report Appendix E.5: the pad is text, its copies cut to fit, and an
    %% empty pad adds none (findings.md's P2-20)
    ?assertEqual(<<"ab-7">>, S:padStart(<<"7">>, 4, <<"ab-">>)),
    ?assertEqual(<<"7éaé"/utf8>>, S:padEnd(<<"7">>, 4, <<"éa"/utf8>>)),
    ?assertEqual(<<"7">>, S:padStart(<<"7">>, 3, <<>>)),
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
    %% report §2.5, Appendix E.5: an exponent alone is a float's literal
    %% form (findings.md's P1-23)
    ?assertEqual({'Some', 1.0e5}, S:toFloat(<<"1e5">>)),
    ?assertEqual({'Some', -2.0e-3}, S:toFloat(<<"-2E-3">>)),
    ?assertEqual('None', S:toFloat(<<"1e">>)),
    ?assertEqual('None', S:toFloat(<<"1.0e999">>)),
    %% the form read by a scan of its own, which a pattern once checked; a
    %% regression test for the edges of the form
    ?assertEqual({'Some', 150.0}, S:toFloat(<<"1.5E+2">>)),
    ?assertEqual({'Some', 0.0}, S:toFloat(<<"-0.0">>)),
    [?assertEqual('None', S:toFloat(T)) || T <- [<<"1.">>, <<".5">>, <<"1.5e">>, <<"1.5e+">>,
                                                 <<"1.5.3">>, <<"--1.5">>, <<"+1.5">>,
                                                 <<"1.5 ">>, <<"-">>, <<>>]],
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
    ?assertEqual({'Some', true}, S:toBool(<<"true">>)),
    ?assertEqual({'Some', false}, S:toBool(<<"false">>)),
    ?assertEqual('None', S:toBool(<<"yes">>)),
    ?assertEqual({'Some', 255}, S:toIntBase(<<"ff">>, 16)),
    ?assertEqual({'Some', 255}, S:toIntBase(<<"FF">>, 16)),
    ?assertEqual('None', S:toIntBase(<<"fg">>, 16)),
    ?assertEqual('None', S:toIntBase(<<"1">>, 40)),
    ?assertEqual(<<"hel">>, S:slice(<<"hello">>, -1, 3)),
    ?assertEqual(<<>>, S:slice(<<"hello">>, 1, -1)),
    ?assertEqual({'Some', 7}, S:toInt(<<"007">>)),
    ?assertEqual('None', S:toInt(<<"-">>)),
    ?assertEqual({'Some', -255}, S:toIntBase(<<"-ff">>, 16)),
    ?assertEqual([<<"a">>], S:split(<<"a">>, <<>>)),
    ?assertEqual('Less', S:compare(<<"a">>, <<"b">>)),
    ?assertEqual('Equal', S:compare(<<"a">>, <<"a">>)).

%% report Appendix E.5, §2.5: String.toFloat reads the float literal form
%% without `_` grouping; an exponent below the smallest Float gives 0.0, one
%% beyond the largest gives None. A regression test, written after the
%% code; it does not cover a form without a digit on each side of the point
string_to_float_edges_test() ->
    S = 'ern@string',
    ?assertEqual('None', S:toFloat(<<"3.141_592">>)),
    ?assertEqual({'Some', 0.0}, S:toFloat(<<"1.0e-400">>)),
    ?assertEqual('None', S:toFloat(<<"1.0e400">>)).

%% report Appendix E.6, §9.6
char_test() ->
    C = 'ern@char',
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
    %% the host's own tables, which its string module follows: White_Space
    %% as Unicode has it, and a letter Unicode 17 added. A regression test
    %% for the regular expression the properties were once read by, whose
    %% tables were older than the host's
    ?assertEqual(true, C:isSpace(16#2028)),
    ?assertEqual(false, C:isSpace(16#180E)),
    ?assertEqual(false, C:isSpace(16#200B)),
    ?assertEqual(true, C:isUpper(16#A7CE)),
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

%% report Appendix E.20
bytes_test() ->
    B = 'ern@bytes',
    ?assertEqual(3, B:size(<<1, 2, 3>>)),
    ?assertEqual(true, B:isEmpty(<<>>)),
    ?assertEqual({'Some', 8}, B:get(<<7, 8>>, 1)),
    ?assertEqual('None', B:get(<<7, 8>>, 2)),
    ?assertEqual('None', B:get(<<7, 8>>, -1)),
    ?assertEqual(<<2, 3>>, B:slice(<<1, 2, 3>>, 1, 5)),
    ?assertEqual(<<>>, B:slice(<<1, 2, 3>>, 3, 1)),
    ?assertEqual(<<>>, B:slice(<<1, 2, 3>>, 0, -1)),
    ?assertEqual([104, 105], B:toList(<<"hi">>)),
    ?assertEqual({'Some', <<104, 105>>}, B:fromList([104, 105])),
    ?assertEqual('None', B:fromList([256])),
    ?assertEqual(<<1, 2>>, B:'<>'(<<1>>, <<2>>)).

%% report Appendix E.20: the text functions over octets, at their edges: an
%% empty second is at 0 for `indexOf` and at the end for `lastIndexOf`, is
%% in every `Bytes`, begins and ends every one, splits nothing and
%% replaces nothing; a count below 0 repeats nothing; hexadecimal is
%% upper-case out and either case in, and an odd count or another
%% character is None. A regression test: the ten functions were tested only
%% by their pages' examples, and `lastIndexOf` was missing
bytes_text_test() ->
    B = 'ern@bytes',
    ?assertEqual(true, B:contains(<<1, 2>>, <<>>)),
    ?assertEqual(false, B:contains(<<1, 2>>, <<2, 1>>)),
    ?assertEqual({'Some', 0}, B:indexOf(<<1>>, <<>>)),
    ?assertEqual({'Some', 1}, B:indexOf(<<0, 1, 2, 1, 2>>, <<1, 2>>)),
    ?assertEqual({'Some', 3}, B:lastIndexOf(<<0, 1, 2, 1, 2>>, <<1, 2>>)),
    ?assertEqual({'Some', 2}, B:lastIndexOf(<<1, 2>>, <<>>)),
    ?assertEqual('None', B:lastIndexOf(<<1>>, <<1, 1>>)),
    ?assertEqual(true, B:startsWith(<<1>>, <<>>)),
    ?assertEqual(true, B:endsWith(<<1>>, <<>>)),
    ?assertEqual(false, B:endsWith(<<1>>, <<0, 1>>)),
    ?assertEqual([<<1, 2>>], B:split(<<1, 2>>, <<>>)),
    ?assertEqual([<<>>, <<1>>, <<>>], B:split(<<0, 1, 0>>, <<0>>)),
    ?assertEqual(<<1, 2>>, B:replace(<<1, 2>>, <<>>, <<9>>)),
    ?assertEqual(<<9, 2, 9>>, B:replace(<<1, 2, 1>>, <<1>>, <<9>>)),
    ?assertEqual(<<1, 0, 2>>, B:join([<<1>>, <<2>>], <<0>>)),
    ?assertEqual(<<>>, B:join([], <<0>>)),
    ?assertEqual(<<1, 1, 1>>, B:repeat(<<1>>, 3)),
    ?assertEqual(<<>>, B:repeat(<<1>>, -2)),
    ?assertEqual(<<"00FF1A">>, B:toHex(<<0, 255, 26>>)),
    ?assertEqual({'Some', <<0, 255, 26>>}, B:fromHex(<<"00ff1A">>)),
    ?assertEqual('None', B:fromHex(<<"0">>)),
    ?assertEqual('None', B:fromHex(<<"0g">>)).

%% report Appendix E.19
erl_test() ->
    ?assertEqual(ready, 'ern@erl':atom(<<"ready">>)).

%% report Appendix E.7
bool_test() ->
    ?assertEqual(false, 'ern@bool':'not'(true)),
    ?assertEqual(<<"true">>, 'ern@bool':toString(true)).

%% report Appendix E.8, §3.1, §7.4, §9.6
int_test() ->
    I = 'ern@int',
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
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, I:toFloat(1 bsl 2000)),
    ?assertEqual({'Some', -2}, I:'div'(-7, 3)),
    ?assertEqual({'Some', -1}, I:'rem'(-7, 3)),
    ?assertEqual('None', I:'div'(1, 0)),
    ?assertEqual('Less', I:compare(1, 2)),
    ?assertEqual(-1, I:negate(1)),
    ?assertEqual({'Some', 1024}, I:pow(2, 10)),
    ?assertEqual({'Some', 1}, I:pow(7, 0)),
    ?assertEqual({'Some', -8}, I:pow(-2, 3)),
    ?assertEqual('None', I:pow(2, -1)),
    ?assertEqual({'Some', <<"FF">>}, I:toStringBase(255, 16)),
    ?assertEqual({'Some', <<"-11">>}, I:toStringBase(-3, 2)),
    ?assertEqual('None', I:toStringBase(5, 37)).

%% report Appendix E.8, §3.1, §7.4: Int.toFloat rounds to the nearest
%% Float and faults only where the rounding gives no finite Float: the
%% largest finite Float as an Int, plus 2^970 - 1, rounds down to it, and
%% plus 2^970 faults, of either sign. Int.pow(0, 0) is 1, and a count
%% below 0 shifts by none. A regression test, written after the code;
%% it does not cover the rounding of an Int within the range
int_edges_test() ->
    I = 'ern@int',
    Max = (1 bsl 53 - 1) bsl 971,
    ?assertEqual(1.7976931348623157e308, I:toFloat(Max)),
    ?assertEqual(1.7976931348623157e308, I:toFloat(Max + (1 bsl 970) - 1)),
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, I:toFloat(Max + (1 bsl 970))),
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, I:toFloat(-(Max + (1 bsl 970)))),
    ?assertEqual({'Some', 1}, I:pow(0, 0)),
    %% report §7.4, E.8: a count below 0 is none; a regression test of the rule
    %% of 2026-10-01, before which it shifted the other way
    ?assertEqual(8, I:shiftLeft(8, -2)),
    ?assertEqual(8, I:shiftRight(8, -2)).

%% report Appendix E.9, §3.1, §7.4, §9.6
float_test() ->
    F = 'ern@float',
    %% E.0 rule 3: a constant of the type, the host's own nearest Float
    ?assertEqual(math:pi(), F:pi()),
    ?assertEqual(3.5, F:'+'(F:'*'(1.5, 2.0), 0.5)),
    ?assertEqual(-1.0, F:'-'(1.0, 2.0)),
    ?assertEqual(0.5, F:'/'(1.0, 2.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, F:'/'(1.0, 0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, F:'*'(1.0e308, 10.0)),
    ?assertEqual(1.5, F:abs(-1.5)),
    ?assertEqual(0.0, F:abs(0.0)),
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
    ?assertEqual(-1.0, F:negate(1.0)),
    ?assertEqual(-2, F:truncate(-2.7)),
    ?assertEqual({'Some', 3.0}, F:sqrt(9.0)),
    ?assertEqual('None', F:sqrt(-1.0)),
    ?assertEqual({'Some', 1024.0}, F:pow(2.0, 10.0)),
    %% Appendix E.9: the domain is None, as for sqrt and log, and an
    %% integral exponent keeps a negative base in it; overflow still faults
    ?assertEqual('None', F:pow(-8.0, 0.5)),
    ?assertEqual('None', F:pow(0.0, -1.0)),
    ?assertEqual({'Some', -8.0}, F:pow(-2.0, 3.0)),
    ?assertEqual({'Some', 1.0}, F:pow(0.0, 0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, F:pow(10.0, 400.0)),
    ?assertEqual(1.0, F:exp(0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, F:exp(1000.0)),
    ?assertEqual({'Some', 0.0}, F:log(1.0)),
    ?assertEqual('None', F:log(0.0)),
    ?assertEqual({0.0, 1.0, 0.0}, {F:sin(0.0), F:cos(0.0), F:tan(0.0)}),
    ?assertEqual({'Some', 0.0}, F:asin(0.0)),
    ?assertEqual('None', F:acos(-2.0)),
    ?assertEqual(0.0, F:atan2(0.0, 1.0)).

%% report Appendix E.10
optional_test() ->
    O = 'ern@optional',
    ?assertEqual(true, O:isSome({'Some', 1})),
    ?assertEqual(true, O:isNone('None')),
    ?assertEqual(1, O:withDefault({'Some', 1}, 0)),
    ?assertEqual(0, O:withDefault('None', 0)),
    ?assertEqual({'Some', 2}, O:map({'Some', 1}, fun(X) -> X + 1 end)),
    ?assertEqual('None', O:andThen({'Some', 1}, fun(_) -> 'None' end)).

%% report Appendix E.11
either_test() ->
    E = 'ern@either',
    ?assertEqual(true, E:isLeft({'Left', e})),
    ?assertEqual(true, E:isRight({'Right', 1})),
    ?assertEqual(1, E:withDefault({'Right', 1}, 0)),
    ?assertEqual(0, E:withDefault({'Left', e}, 0)),
    ?assertEqual({'Right', 2}, E:map({'Right', 1}, fun(X) -> X + 1 end)),
    ?assertEqual({'Left', f}, E:mapLeft({'Left', e}, fun(e) -> f end)),
    ?assertEqual({'Left', e}, E:andThen({'Left', e}, fun(X) -> {'Right', X} end)),
    ?assertEqual({'Some', 1}, E:toOptional({'Right', 1})),
    ?assertEqual({'Left', e}, E:fromOptional('None', e)).

%% report Appendix E.1, §8.2: print and println write to Io's stdout,
%% printError, printlnError and debug to its stderr, each as a message
io_test() ->
    Me = self(),
    Sink = fun(Tag) -> fun(Bin) -> Me ! {Tag, Bin} end end,
    Result = ern_rt:run_main(fun() ->
                                 'ern@io':print(<<"a">>),
                                 'ern@io':println(<<"b">>),
                                 'ern@io':printError(<<"c">>),
                                 'ern@io':printlnError(<<"d">>),
                                 'ern@io':debug(42)
                             end, <<"io_test">>,
                             #{stdout => Sink(out), stderr => Sink(err)}),
    ?assertEqual(ok, Result),
    ?assertEqual([<<"a">>, <<"b\n">>], collect(out, [])),
    ?assertEqual([<<"c">>, <<"d\n">>, <<"42\n">>], collect(err, [])).

%% report Appendix E.1, §8.2: readLine gives the next line without its line
%% feed, and None at end of input
io_read_line_test() ->
    Me = self(),
    %% the reader runs in the stdin process, so the queue is shared
    Tab = ets:new(lines, [public]),
    ets:insert(Tab, {queue, ["one\n", "two"]}),
    Lines = fun() ->
                case ets:lookup(Tab, queue) of
                    [{_, [L | Rest]}] -> ets:insert(Tab, {queue, Rest}), L;
                    _ -> eof
                end
            end,
    Result = ern_rt:run_main(fun() ->
                                 Me ! {read, 'ern@io':readLine()},
                                 Me ! {read, 'ern@io':readLine()},
                                 Me ! {read, 'ern@io':readLine()}
                             end, <<"io_read_line_test">>, #{stdin => Lines}),
    ?assertEqual(ok, Result),
    ?assertEqual([{'Some', <<"one">>}, {'Some', <<"two">>}, 'None'], collect(read, [])).

collect(Tag, Acc) ->
    receive {Tag, Bin} -> collect(Tag, [Bin | Acc])
    after 0 -> lists:reverse(Acc)
    end.

%% report Appendix E.17, §8.2: the file system through Fs's reference, each answer
%% Right or Left(Io.Error), and Left(Timeout) when the wait runs out
fs_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_fs_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    P = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    F = 'ern@fs',
    Result = ern_rt:run_main(
               fun() ->
                   Me ! {fs, F:write(P("a.txt"), <<"hello">>, 5000)},
                   Me ! {fs, F:read(P("a.txt"), 5000)},
                   Me ! {fs, F:append(P("a.txt"), <<"!">>, 5000)},
                   Me ! {fs, F:read(P("a.txt"), 5000)},
                   Me ! {fs, F:stat(P("a.txt"), 5000)},
                   Me ! {fs, F:rename(P("a.txt"), P("b.txt"), 5000)},
                   Me ! {fs, F:copy(P("b.txt"), P("c.txt"), 5000)},
                   Me ! {fs, F:makeDir(P("d/e"), 5000)},
                   Me ! {fs, F:list({'Path', unicode:characters_to_binary(Dir)}, 5000)},
                   Me ! {fs, F:remove(P("c.txt"), 5000)},
                   Me ! {fs, F:read(P("c.txt"), 5000)}
               end, <<"fs_test">>, #{}),
    ?assertEqual(ok, Result),
    [Write, Read, Append, Read2, Stat, Rename, Copy, MakeDir, List, Remove, Gone] =
        collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Write),
    ?assertEqual({'Right', <<"hello">>}, Read),
    ?assertEqual({'Right', 'Unit'}, Append),
    ?assertEqual({'Right', <<"hello!">>}, Read2),
    ?assertMatch({'Right', {'Entry', _, _, 6, 'File'}}, Stat),
    ?assertEqual({'Right', 'Unit'}, Rename),
    ?assertEqual({'Right', 'Unit'}, Copy),
    ?assertEqual({'Right', 'Unit'}, MakeDir),
    {'Right', Entries} = List,
    ?assertEqual([<<"b.txt">>, <<"c.txt">>, <<"d">>],
                 lists:sort([filename:basename(Path)
                             || {'Entry', {'Path', Path}, _, _, _} <- Entries])),
    ?assertEqual({'Right', 'Unit'}, Remove),
    ?assertEqual({'Left', 'NotFound'}, Gone),
    file:del_dir_r(Dir).

%% report Appendix E.17: read, write, append and copy work on regular files,
%% and refuse a named pipe and a directory at once. A regression test: a
%% named pipe's read waited for a writer in the host's file server, which
%% then answered no other request of the node's, the read of a plain file
%% after it among them
fs_named_pipe_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_fifo_" ++ os:getpid() ++ "_"
                                ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    "" = os:cmd("mkfifo " ++ filename:join(Dir, "pipe")),
    ok = file:write_file(filename:join(Dir, "plain"), <<"hi">>),
    P = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    F = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, F:read(P("pipe"), 1000)},
                           Me ! {fs, F:write(P("pipe"), <<"x">>, 1000)},
                           Me ! {fs, F:append(P("pipe"), <<"x">>, 1000)},
                           Me ! {fs, F:copy(P("pipe"), P("copy"), 1000)},
                           Me ! {fs, F:copy(P("plain"), P("pipe"), 1000)},
                           Me ! {fs, F:read(P("."), 1000)},
                           Me ! {fs, F:read(P("plain"), 1000)}
                       end, <<"fs_named_pipe_test">>, #{})),
    Refused = {'Left', 'NotAFile'},
    ?assertEqual(lists:duplicate(6, Refused) ++ [{'Right', <<"hi">>}], collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.17: `setMode` sets a file's and a directory's
%% permission bits to the mode, a path that names nothing is NotFound, and a
%% mode beyond the bits is Invalid. A regression test of the rule of
%% 2026-10-01, which replaced `makePrivate` with it
fs_set_mode_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_private_" ++ os:getpid() ++ "_"
                                   ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    File = filename:join(Dir, "notes"),
    ok = file:write_file(File, <<"x">>),
    ok = file:change_mode(Dir, 8#755),
    ok = file:change_mode(File, 8#664),
    P = fun(Name) -> {'Path', unicode:characters_to_binary(Name)} end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, 'ern@fs':setMode(P(File), 8#600, 1000)},
                           Me ! {fs, 'ern@fs':setMode(P(Dir), 8#700, 1000)},
                           Me ! {fs, 'ern@fs':setMode(P(Dir ++ "/none"), 8#700, 1000)},
                           Me ! {fs, 'ern@fs':setMode(P(File), 8#10000, 1000)}
                       end, <<"fs_set_mode_test">>, #{})),
    ?assertEqual([{'Right', 'Unit'}, {'Right', 'Unit'}, {'Left', 'NotFound'},
                  {'Left', 'Invalid'}], collect(fs, [])),
    {ok, FileInfo} = file:read_file_info(File),
    {ok, DirInfo} = file:read_file_info(Dir),
    ?assertEqual({8#600, 8#700}, {element(8, FileInfo) band 8#777, element(8, DirInfo) band 8#777}),
    file:del_dir_r(Dir).

%% report Appendix E.17: `list` describes each entry as it is, a link as
%% the link itself, a link to nothing among them. A regression test: a link
%% to nothing failed the list of the whole directory with NotFound
fs_list_dangling_link_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_links_" ++ os:getpid() ++ "_"
                                 ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "plain"), <<"four">>),
    ok = file:make_symlink("plain", filename:join(Dir, "to_plain")),
    ok = file:make_symlink("nowhere", filename:join(Dir, "to_nothing")),
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, 'ern@fs':list({'Path', list_to_binary(Dir)}, 1000)}
                       end, <<"fs_list_dangling_link_test">>, #{})),
    [{'Right', Entries}] = collect(fs, []),
    Described = lists:sort([{filename:basename(P), K, S}
                            || {'Entry', {'Path', P}, _, S, K} <- Entries]),
    %% a link is the link itself, whose size is its target's name
    ?assertEqual([{<<"plain">>, 'File', 4}, {<<"to_nothing">>, 'Link', 7},
                  {<<"to_plain">>, 'Link', 5}], Described),
    file:del_dir_r(Dir).

%% report Appendix E.17: a link made to a path is read back as it was
%% written; `stat` follows it and `list` does not; `remove` takes the link
%% and leaves what it leads to; a link where something is is answered
%% `Exists`, and a read of what is no link with None. Written with the code
%% (language feedback 65); a link's target that is not UTF-8 is not
%% covered, since a test cannot make one where the host's names are UTF-8
fs_links_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_links_" ++ os:getpid() ++ "_"
                                 ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(filename:join(Dir, "shelf")),
    P = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    F = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, F:makeLink(P("to_shelf"), {'Path', <<"shelf">>}, 1000)},
                           Me ! {fs, F:readLink(P("to_shelf"), 1000)},
                           Me ! {fs, F:stat(P("to_shelf"), 1000)},
                           Me ! {fs, F:list({'Path', list_to_binary(Dir)}, 1000)},
                           Me ! {fs, F:makeLink(P("to_shelf"), P("elsewhere"), 1000)},
                           Me ! {fs, F:readLink(P("shelf"), 1000)},
                           Me ! {fs, F:remove(P("to_shelf"), 1000)},
                           Me ! {fs, F:list({'Path', list_to_binary(Dir)}, 1000)}
                       end, <<"fs_links_test">>, #{})),
    [Made, Read, Stat, Listed, Again, NotLink, Removed, After] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Made),
    ?assertEqual({'Right', {'Some', {'Path', <<"shelf">>}}}, Read),
    ?assertMatch({'Right', {'Entry', _, _, _, 'Directory'}}, Stat),
    {'Right', Entries} = Listed,
    ?assertEqual([{<<"shelf">>, 'Directory'}, {<<"to_shelf">>, 'Link'}],
                 lists:sort([{filename:basename(Path), K}
                             || {'Entry', {'Path', Path}, _, _, K} <- Entries])),
    ?assertEqual({'Left', 'Exists'}, Again),
    ?assertEqual({'Right', 'None'}, NotLink),
    ?assertEqual({'Right', 'Unit'}, Removed),
    {'Right', Kept} = After,
    ?assertEqual([<<"shelf">>],
                 [filename:basename(Path) || {'Entry', {'Path', Path}, _, _, _} <- Kept]),
    file:del_dir_r(Dir).

%% report Appendix E.17: `readRange` reads a part of a file, fewer bytes at
%% its end and none past it, a regular file only, and an offset or a count
%% below 0 is none (§7.4, a regression test of the rule of 2026-10-01, which
%% refused one in words). Written with the code (MVP 2.98); the counts and
%% the offset past what the host can hold are a regression test, since the
%% host made room for the count first and answered `Other("not enough
%% memory")` or `Other("invalid argument")`
fs_read_range_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_range_" ++ os:getpid() ++ "_"
                                 ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "abc.txt"), <<"abcdef">>),
    P = {'Path', list_to_binary(filename:join(Dir, "abc.txt"))},
    F = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           [Me ! {fs, F:readRange(P, O, N, 1000)}
                            || {O, N} <- [{0, 2}, {4, 9}, {6, 1}, {9, 1}, {1, 0}, {-1, 2}, {1, -1},
                                          {2, 1 bsl 62}, {3, 1 bsl 80}, {1 bsl 80, 1}]],
                           Me ! {fs, F:readRange({'Path', list_to_binary(Dir)}, 0, 1, 1000)}
                       end, <<"fs_read_range_test">>, #{})),
    ?assertEqual([{'Right', <<"ab">>}, {'Right', <<"ef">>}, {'Right', <<>>}, {'Right', <<>>},
                  {'Right', <<>>}, {'Right', <<"ab">>}, {'Right', <<>>},
                  {'Right', <<"cdef">>}, {'Right', <<"def">>}, {'Right', <<>>},
                  {'Left', 'NotAFile'}],
                 collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.17: `makeFile` makes a new file or none; `removeAll`
%% removes a tree, a link in it removed and what it leads to kept;
%% `setModified` sets the time a `stat` then reads, to the second. Written
%% with the code (MVP 2.98); a write that fails after the file is made is
%% not covered, since a test cannot make one fail there
fs_create_remove_all_modified_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_fs3_" ++ os:getpid() ++ "_"
                                 ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(filename:join([Dir, "tree", "branch"])),
    ok = filelib:ensure_path(filename:join(Dir, "kept")),
    ok = file:write_file(filename:join([Dir, "kept", "precious.txt"]), <<"keep">>),
    ok = file:write_file(filename:join([Dir, "tree", "branch", "leaf.txt"]), <<"x">>),
    ok = file:make_symlink(filename:join(Dir, "kept"), filename:join([Dir, "tree", "to_kept"])),
    P = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    F = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, F:makeFile(P("new.txt"), <<"a">>, 1000)},
                           Me ! {fs, F:makeFile(P("new.txt"), <<"b">>, 1000)},
                           Me ! {fs, F:read(P("new.txt"), 1000)},
                           Me ! {fs, F:removeAll(P("tree"), 1000)},
                           Me ! {fs, F:setModified(P("new.txt"), 86400999, 1000)},
                           Me ! {fs, F:stat(P("new.txt"), 1000)}
                       end, <<"fs_create_remove_all_modified_test">>, #{})),
    [Made, Taken, Kept, Removed, Set, Stat] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Made),
    ?assertEqual({'Left', 'Exists'}, Taken),
    ?assertEqual({'Right', <<"a">>}, Kept),
    ?assertEqual({'Right', 'Unit'}, Removed),
    ?assertNot(filelib:is_file(filename:join(Dir, "tree"))),
    ?assertEqual({ok, <<"keep">>}, file:read_file(filename:join([Dir, "kept", "precious.txt"]))),
    ?assertEqual({'Right', 'Unit'}, Set),
    ?assertMatch({'Right', {'Entry', _, 86400000, 1, 'File'}}, Stat),
    file:del_dir_r(Dir).

%% report Appendix E.17: `removeAll` removes a link where it stands, at the
%% root as inside, and never what it leads to, removes a named pipe without
%% waiting on it, and answers the error that stopped it: a directory it
%% cannot list is Denied, and a path that names nothing NotFound. A
%% regression test, written with the walk by open directories that replaced
%% one by paths (findings.md's C1-3); it cannot put a link in a directory's
%% place between two steps of the walk, which the walk makes harmless by
%% opening each directory refusing a link
fs_remove_all_by_directories_test() ->
    Me = self(),
    Dir = filename:join("/tmp", "ern_fs4_" ++ os:getpid() ++ "_"
                                 ++ integer_to_list(erlang:unique_integer([positive]))),
    Kept = filename:join(Dir, "kept"),
    ok = filelib:ensure_path(Kept),
    ok = file:write_file(filename:join(Kept, "precious.txt"), <<"keep">>),
    ok = filelib:ensure_path(filename:join([Dir, "tree", "deep"])),
    ok = file:make_symlink(Kept, filename:join([Dir, "tree", "deep", "to_kept"])),
    ok = file:make_symlink(Kept, filename:join(Dir, "root_link")),
    "" = os:cmd("mkfifo " ++ filename:join([Dir, "tree", "pipe"])),
    ok = filelib:ensure_path(filename:join([Dir, "locked", "inner"])),
    ok = file:write_file(filename:join([Dir, "locked", "inner", "f"]), <<>>),
    ok = file:change_mode(filename:join([Dir, "locked", "inner"]), 8#000),
    P = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    F = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Me ! {fs, F:removeAll(P("tree"), 5000)},
                           Me ! {fs, F:removeAll(P("root_link"), 5000)},
                           Me ! {fs, F:removeAll(P("locked"), 5000)},
                           Me ! {fs, F:removeAll(P("nothing"), 5000)}
                       end, <<"fs_remove_all_by_directories_test">>, #{})),
    [Tree, RootLink, Locked, Nothing] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Tree),
    ?assertNot(filelib:is_file(filename:join(Dir, "tree"))),
    ?assertEqual({'Right', 'Unit'}, RootLink),
    ?assertEqual({error, enoent}, file:read_link_info(filename:join(Dir, "root_link"))),
    ?assertEqual({ok, <<"keep">>}, file:read_file(filename:join(Kept, "precious.txt"))),
    ?assertEqual({'Left', 'Denied'}, Locked),
    ?assertEqual({'Left', 'NotFound'}, Nothing),
    ok = file:change_mode(filename:join([Dir, "locked", "inner"]), 8#755),
    file:del_dir_r(Dir).

%% report Appendix E.18, §8.2: a listener and a socket are processes, a
%% write arrives at the peer's read, and a closed socket answers Left(Closed)
tcp_test() ->
    Me = self(),
    T = 'ern@tcp',
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Listener} = T:listen(<<"127.0.0.1">>, 7411),
                   {'Right', Client} = T:connect(<<"127.0.0.1">>, 7411, 1000),
                   {'Right', Server} = T:accept(Listener, 1000),
                   T:write(Client, <<"ping">>, 5000),
                   Me ! {tcp, T:read(Server, 1000)},
                   T:write(Server, <<"pong">>, 5000),
                   Me ! {tcp, T:read(Client, 1000)},
                   T:close(Client),
                   Me ! {tcp, T:read(Server, 1000)}
               end, <<"tcp_test">>, #{}),
    ?assertEqual(ok, Result),
    ?assertEqual([{'Right', <<"ping">>}, {'Right', <<"pong">>}, {'Left', 'Closed'}],
                 collect(tcp, [])).

%% report §8.6, Appendix E.18: a listener ends with the program, so the
%% port is free for the next. A regression test: listeners and sockets
%% were started outside the runtime's reach and outlived their program,
%% and a second program listening on the port was refused `eaddrinuse`.
tcp_ends_with_program_test() ->
    Me = self(),
    T = 'ern@tcp',
    Listen = fun() -> Me ! {listened, element(1, T:listen(<<"127.0.0.1">>, 7412))} end,
    ?assertEqual(ok, ern_rt:run_main(Listen, <<"first">>, #{})),
    ?assertEqual(ok, ern_rt:run_main(Listen, <<"second">>, #{})),
    ?assertEqual(['Right', 'Right'], collect(listened, [])).

%% report Appendix E.12, §3.8, §8.4
foreign_test() ->
    F = 'ern@foreign',
    ?assertEqual(42, F:from(42)),
    ?assertEqual({'Some', 0.0}, F:toFloat(-0.0)),
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
    ?assertEqual('None', F:toList(<<>>)),
    %% an improper list is no List; a regression test, it was answered as one
    ?assertEqual('None', F:toList([1 | x])).

%% report Appendix E.9: the shortest digits, plain from 0.0001 to below
%% 1.0e16 and with an exponent beyond, its sign only when negative, each
%% reading back as the same value. A regression test: 1.0e15 was written with
%% an exponent, as the host writes it.
float_to_string_test() ->
    F = 'ern@float',
    S = 'ern@string',
    Cases = [{1.0e15, <<"1000000000000000.0">>},
             {9.999999999999998e15, <<"9999999999999998.0">>},
             {1.0e16, <<"1.0e16">>}, {1.0e-5, <<"1.0e-5">>}, {0.0001, <<"0.0001">>},
             {1.5e-7, <<"1.5e-7">>}, {123.0, <<"123.0">>}, {0.1, <<"0.1">>},
             {1.2345e20, <<"1.2345e20">>}, {0.0, <<"0.0">>}, {-2.5, <<"-2.5">>},
             {-1.0e-9, <<"-1.0e-9">>}, {12.5, <<"12.5">>}],
    [?assertEqual({X, Text}, {X, F:toString(X)}) || {X, Text} <- Cases],
    [?assertEqual({'Some', X}, S:toFloat(F:toString(X))) || {X, _} <- Cases].

%% report Appendix E.13: the same seed gives the same sequence, every draw
%% is within the bounds on either side of zero, and the seed moves
random_test() ->
    R = 'ern@random',
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

%% report Appendix E.13: the generator is SplitMix64, so a seed's draws are
%% the reference sequence: from 0, a draw over the whole 64-bit range is the
%% reference output itself, and a seed names its number's low 64 bits. A
%% regression test, written with the move from the host's `exsss`, whose
%% sequence no report could promise.
random_splitmix64_test() ->
    R = 'ern@random',
    Whole = 16#FFFF_FFFF_FFFF_FFFF,
    {A, S1} = R:next(R:seed(0), Whole),
    {B, S2} = R:next(S1, Whole),
    {C, _} = R:next(S2, Whole),
    ?assertEqual([16#E220A8397B1DCDAF, 16#6E789E6AA1B965F4, 16#06C45D188009454F], [A, B, C]),
    ?assertEqual(R:seed(5), R:seed(5 + (1 bsl 64))),
    {X, _} = R:nextFloat(R:seed(0)),
    ?assertEqual((float(16#E220A8397B1DCDAF bsr 12) + 0.5) / 4503599627370496.0, X),
    %% a bound beyond 64 bits draws from as many words as it needs
    {Big, _} = R:next(R:seed(1), 1 bsl 100),
    ?assert(Big >= 0 andalso Big =< 1 bsl 100).

%% report Appendix E.14: Path's edge cases, now that it is Ernest over String
%% and two primitives: a trailing separator, an absolute second operand, the
%% root alone, a name with an empty extension, and a dot file. Written with
%% the move, where `filename` had answered them.
path_edges_test() ->
    P = 'ern@path',
    T = fun(Text) -> {'Path', Text} end,
    ?assertEqual({'Some', <<"b">>}, P:name(T(<<"a/b/">>))),
    ?assertEqual([<<"a">>, <<"b">>], P:split(T(<<"a//b/">>))),
    ?assertEqual({'Some', T(<<"a">>)}, P:parent(T(<<"a/b/">>))),
    ?assertEqual(T(<<"/var">>), P:'<>'(T(<<"/etc">>), T(<<"/var">>))),
    ?assertEqual(T(<<"/etc/hosts">>), P:'<>'(T(<<"/etc/">>), T(<<"hosts">>))),
    ?assertEqual(T(<<"b">>), P:'<>'(T(<<"">>), T(<<"b">>))),
    ?assertEqual([<<"/">>], P:split(T(<<"/">>))),
    %% report Appendix E.14: the root has no name, a regression test of the
    %% rule of 2026-10-01, before which it was ""
    ?assertEqual('None', P:name(T(<<"/">>))),
    ?assertEqual({'Some', <<>>}, P:extension(T(<<"a.">>))),
    ?assertEqual('None', P:extension(T(<<"a.d/b">>))),
    ?assertEqual(T(<<"a/b/">>), P:withoutExtension(T(<<"a/b.txt/">>))),
    %% report Appendix E.14: an empty extension leaves the dot, and removing
    %% one is withoutExtension's (findings.md's P2-28)
    ?assertEqual(T(<<"a/b.">>), P:withExtension(T(<<"a/b.txt">>), <<>>)),
    ?assertEqual(T(<<"a.d/b.md">>), P:withExtension(T(<<"a.d/b">>), <<"md">>)),
    %% a dot that begins a name begins no extension, and the root has no name
    %% to extend; a regression test, `.bashrc`'s extension was `bashrc`, so
    %% removing it left an empty path (findings.md's E12)
    ?assertEqual('None', P:extension(T(<<".profile">>))),
    ?assertEqual({'Some', <<"bak">>}, P:extension(T(<<".profile.bak">>))),
    ?assertEqual(T(<<".bashrc">>), P:withoutExtension(T(<<".bashrc">>))),
    ?assertEqual(T(<<"dir/.bashrc.txt">>), P:withExtension(T(<<"dir/.bashrc">>), <<"txt">>)),
    ?assertEqual(T(<<"/">>), P:withExtension(T(<<"/">>), <<"txt">>)),
    %% the dots that begin a name begin no extension, `..` is left as it is,
    %% and the rest of a path stays as written; a regression test, `..` had
    %% the extension "", which removing turned into `.`, and a doubled
    %% separator was made one
    ?assertEqual('None', P:extension(T(<<"..">>))),
    ?assertEqual('None', P:extension(T(<<"...">>))),
    ?assertEqual({'Some', <<"b">>}, P:extension(T(<<"..a.b">>))),
    ?assertEqual(T(<<"a/..">>), P:withoutExtension(T(<<"a/..">>))),
    ?assertEqual(T(<<"a/..">>), P:withExtension(T(<<"a/..">>), <<"md">>)),
    ?assertEqual(T(<<"a//b.md">>), P:withExtension(T(<<"a//b.txt">>), <<"md">>)),
    ?assertEqual(T(<<"a/b/c">>), P:'<>'(T(<<"a//b">>), T(<<"c">>))).

%% report Appendix E.16, E.5: columns counts by grapheme, by its first code
%% point that counts: a combining mark adds none, alone it takes none; an
%% emoji sequence joined by ZWJ and a flag are one wide grapheme; a
%% pictograph is wide only with U+FE0F; a fullwidth letter is wide; a tab
%% and an escape sequence take none. Written with the code
columns_test() ->
    T = 'ern@terminal',
    C = fun(Chars) -> T:columns(unicode:characters_to_binary(Chars)) end,
    ?assertEqual(1, C([$e, 16#301])),
    ?assertEqual(0, C([16#301])),
    ?assertEqual(2, C([16#1F468, 16#200D, 16#1F469, 16#200D, 16#1F467])),
    ?assertEqual(2, C([16#1F1F8, 16#1F1EA])),
    ?assertEqual(1, C([16#2764])),
    ?assertEqual(2, C([16#2764, 16#FE0F])),
    ?assertEqual(2, C([16#FF21])),
    ?assertEqual(0, C("\t")),
    ?assertEqual(2, C("\e[1;31mab\e[0m")),
    ?assertEqual(1, C("\e7a")),
    ?assertEqual([<<"a">>, <<"e", 16#301/utf8>>], ern_string:graphemes(<<"ae", 16#301/utf8>>)).

%% report Appendix E.14, §9.3
path_test() ->
    P = 'ern@path',
    ?assertEqual({'Path', <<"a/b">>}, P:'<>'({'Path', <<"a">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"a/b">>}, P:'<>'({'Path', <<"a/">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"/b">>}, P:'<>'({'Path', <<"a">>}, {'Path', <<"/b">>})),
    %% report Appendix E.14: join is split's inverse, a root first staying
    %% one; a regression test of the rule of 2026-10-01, before which join
    %% took two paths, which `<>` now does
    ?assertEqual({'Path', <<"/etc/hosts">>}, P:join([<<"/">>, <<"etc">>, <<"hosts">>])),
    ?assertEqual({'Path', <<"a/b">>}, P:join(P:split({'Path', <<"a//b/">>}))),
    ?assertEqual({'Path', <<>>}, P:join([])),
    ?assertEqual([<<"/">>, <<"a">>, <<"b">>], P:split({'Path', <<"/a/b">>})),
    ?assertEqual([<<"a">>, <<"b">>], P:split({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"a">>}}, P:parent({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"/">>}}, P:parent({'Path', <<"/a">>})),
    ?assertEqual('None', P:parent({'Path', <<"a">>})),
    ?assertEqual('None', P:parent({'Path', <<"/">>})),
    ?assertEqual({'Some', <<"b.txt">>}, P:name({'Path', <<"a/b.txt">>})),
    ?assertEqual({'Some', <<"txt">>}, P:extension({'Path', <<"a/b.txt">>})),
    ?assertEqual('None', P:extension({'Path', <<"a/b">>})),
    ?assertEqual({'Path', <<"a/b.md">>}, P:withExtension({'Path', <<"a/b.txt">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b.md">>}, P:withExtension({'Path', <<"a/b">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b">>}, P:withoutExtension({'Path', <<"a/b.txt">>})),
    ?assertEqual(true, P:isAbsolute({'Path', <<"/a">>})),
    ?assertEqual(false, P:isAbsolute({'Path', <<"a">>})),
    ?assertEqual(<<"a">>, P:toString({'Path', <<"a">>})).

%% report §7.4: `fault(c)` faults with the cause
fault_test() ->
    ?assertThrow({ern, fault, <<"x">>}, ern_rt:fault(<<"x">>)).
