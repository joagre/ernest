%% The stdlib modules of Appendix E, by module, and the operations of
%% report §9.6 that live in them.
-module(ern_stdlib_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% report Appendix E.2
list_test() ->
    List = 'ern@list',
    ?assertEqual(3, List:size([1, 2, 3])),
    ?assertEqual(true, List:isEmpty([])),
    ?assertEqual({'Some', 2}, List:last([1, 2])),
    ?assertEqual('None', List:last([])),
    ?assertEqual({'Some', 2}, List:get([1, 2, 3], 1)),
    ?assertEqual('None', List:get([1, 2, 3], 3)),
    ?assertEqual('None', List:get([1, 2, 3], -1)),
    ?assertEqual([2, 1], List:reverse([1, 2])),
    ?assertEqual([1, 2], List:take([1, 2, 3], 2)),
    ?assertEqual([1, 2, 3], List:take([1, 2, 3], 5)),
    ?assertEqual([], List:take([1, 2, 3], -1)),
    ?assertEqual([3], List:drop([1, 2, 3], 2)),
    ?assertEqual([], List:drop([1, 2, 3], 5)),
    ?assertEqual([1, 2, 3], List:drop([1, 2, 3], -1)),
    ?assertEqual([1, 2], List:dropLast([1, 2, 3], 1)),
    ?assertEqual([], List:dropLast([], 1)),
    %% report Appendix E.2: a count, as drop takes one, a regression test of the
    %% rule; one past the length leaves none, one below 0 all
    ?assertEqual([1], List:dropLast([1, 2, 3], 2)),
    ?assertEqual([], List:dropLast([1, 2], 5)),
    ?assertEqual([1, 2], List:dropLast([1, 2], -1)),
    ?assertEqual(true, List:contains([1, 2], 2)),
    ?assertEqual({'Some', 2}, List:find([1, 2, 3], fun(X) -> X > 1 end)),
    ?assertEqual('None', List:find([1], fun(X) -> X > 1 end)),
    ?assertEqual(true, List:any([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual(false, List:all([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual([2, 4], List:map([1, 2], fun(X) -> X * 2 end)),
    ?assertEqual([2], List:filter([1, 2], fun(X) -> X > 1 end)),
    ?assertEqual([20], List:filterMap([1, 2], fun(1) -> 'None'; (X) -> {'Some', X * 10} end)),
    ?assertEqual(6, List:foldLeft([1, 2, 3], 0, fun(A, X) -> A + X end)),
    ?assertEqual('Unit', List:foreach([1], fun(_) -> 'Unit' end)),
    ?assertEqual({[1, 2], [3, 1]}, List:span([1, 2, 3, 1], fun(X) -> X < 3 end)),
    ?assertEqual({[1, 2, 1], [3]}, List:partition([1, 2, 3, 1], fun(X) -> X < 3 end)),
    %% the predicate meets the elements in order; a regression test, it met
    %% them from the last
    Seen = fun(X) -> put(seen, [X | get(seen)]), X > 1 end,
    put(seen, []),
    _ = List:partition([1, 2, 3], Seen),
    ?assertEqual([1, 2, 3], lists:reverse(get(seen))),
    ?assertEqual([2, 1, 3], List:unique([2, 1, 2, 3, 1])),
    ?assertEqual([{0, a}, {1, b}], List:indexed([a, b])),
    ?assertEqual([x, x], List:repeat(x, 2)),
    ?assertEqual([], List:repeat(x, -1)),
    ?assertEqual({[1, 2], [a, b]}, List:unzip([{1, a}, {2, b}])),
    ?assertEqual({'Right', [2, 4]}, List:tryMap([1, 2], fun(X) -> {'Right', X * 2} end)),
    Even = fun(X) when X rem 2 =:= 0 -> {'Right', X}; (_) -> {'Left', odd} end,
    ?assertEqual({'Left', odd}, List:tryMap([2, 3, 4], Even)),
    ?assertEqual({'Right', 3}, List:tryFold([1, 2], 0, fun(A, X) -> {'Right', A + X} end)),
    Bounded = fun(A, X) when A + X > 2 -> {'Left', big}; (A, X) -> {'Right', A + X} end,
    ?assertEqual({'Left', big}, List:tryFold([1, 2, 3], 0, Bounded)),
    ?assertEqual(<<"ab">>, List:foldRight([<<"a">>, <<"b">>], <<>>,
                                          fun(X, Acc) -> <<X/binary, Acc/binary>> end)),
    ?assertEqual([1, 2, 3], List:sort([3, 1, 2], fun 'ern@int':compare/2)),
    %% report Appendix E.2: sort is stable, and orders a long list as
    %% Erlang's does
    ByFirst = fun({A, _}, {B, _}) -> 'ern@int':compare(A, B) end,
    ?assertEqual([{1, a}, {1, b}, {2, c}],
                 List:sort([{1, a}, {2, c}, {1, b}], ByFirst)),
    Many = [(N * 7919) rem 1009 || N <- lists:seq(1, 2000)],
    ?assertEqual(lists:sort(Many), List:sort(Many, fun 'ern@int':compare/2)),
    ?assertEqual([1, 3, 2], List:remove([1, 2, 3, 2], 2)),
    ?assertEqual([{1, a}, {2, b}], List:zip([1, 2, 3], [a, b])),
    ?assertEqual([1, 1, 2, 2], List:flatMap([1, 2], fun(X) -> [X, X] end)),
    ?assertEqual([2, 3, 4], List:range(2, 4)),
    ?assertEqual([], List:range(3, 2)).

%% report §8.4: foreign code receives a Map as a map from each key's term to
%% its value's term, and a Set as {set, S}, S a version 2 set, which is a map
%% from each element to []. A regression test, written after the report
%% gave the terms
map_set_terms_test() ->
    ern_rt:init_stdlib(),
    Map = 'ern@map',
    Set = 'ern@set',
    ?assertEqual(#{a => 1}, Map:put(Map:empty(), a, 1)),
    ?assertEqual({set, #{a => []}}, Set:put(Set:empty(), a)).

%% report Appendix E.3, §3.10
map_test() ->
    %% report §8.5: Map.empty is a top-level let, evaluated at program start
    ern_rt:init_stdlib(),
    Map = 'ern@map',
    Empty = Map:empty(),
    ?assertEqual(true, Map:isEmpty(Empty)),
    Filled = Map:put(Map:put(Empty, a, 1), b, 2),
    ?assertEqual(2, Map:size(Filled)),
    ?assertEqual(true, Map:contains(Filled, a)),
    ?assertEqual({'Some', 2}, Map:get(Filled, b)),
    ?assertEqual('None', Map:get(Filled, c)),
    ?assertEqual(1, Map:size(Map:remove(Filled, a))),
    Count = fun({'Some', V}) -> V + 1; ('None') -> 0 end,
    ?assertEqual({'Some', 2}, Map:get(Map:update(Filled, a, Count), a)),
    ?assertEqual({'Some', 0}, Map:get(Map:update(Filled, z, Count), z)),
    ?assertEqual([a, b], lists:sort(Map:keys(Filled))),
    ?assertEqual([1, 2], lists:sort(Map:values(Filled))),
    ?assertEqual({'Some', 20}, Map:get(Map:map(Filled, fun(_, V) -> V * 10 end), b)),
    ?assertEqual(3, Map:foldLeft(Filled, 0, fun(A, _, V) -> A + V end)),
    ?assert(Map:put(Map:put(Empty, a, 1), b, 2) =:= Map:put(Map:put(Empty, b, 2), a, 1)),
    ?assertEqual([{b, 2}], Map:toList(Map:filter(Filled, fun(_, V) -> V > 1 end))),
    ?assertEqual([{b, 20}], Map:toList(Map:filterMap(Filled, fun(_, 1) -> 'None';
                                                               (_, V) -> {'Some', V * 10} end))),
    ?assertEqual('Unit', Map:foreach(Filled, fun(_, _) -> 'Unit' end)),
    ?assertEqual(true, Map:any(Filled, fun(K, _) -> K =:= a end)),
    ?assertEqual(false, Map:all(Filled, fun(_, V) -> V > 1 end)),
    ?assertEqual({'Some', {b, 2}}, Map:find(Filled, fun(_, V) -> V =:= 2 end)),
    ?assertEqual('None', Map:find(Filled, fun(_, V) -> V =:= 3 end)),
    ?assertEqual(Filled, Map:fromList([{a, 0}, {a, 1}, {b, 2}])),
    ?assertEqual([{a, 1}, {b, 3}],
                 lists:sort(Map:toList(Map:merge(Filled, Map:fromList([{b, 3}]))))),
    ?assertEqual([{a, 1}, {b, 2}], lists:sort(Map:toList(Filled))).

%% report Appendix E.4, §3.10
set_test() ->
    ern_rt:init_stdlib(),
    Set = 'ern@set',
    ?assertEqual(true, Set:isEmpty(Set:empty())),
    Filled = Set:put(Set:put(Set:put(Set:empty(), 1), 2), 2),
    ?assertEqual(2, Set:size(Filled)),
    ?assertEqual(true, Set:contains(Filled, 2)),
    ?assertEqual(false, Set:contains(Set:remove(Filled, 2), 2)),
    ?assertEqual([1, 2, 3], lists:sort(Set:toList(Set:union(Filled, Set:fromList([3]))))),
    ?assertEqual([2], Set:toList(Set:intersection(Filled, Set:fromList([2, 3])))),
    ?assertEqual([1], Set:toList(Set:difference(Filled, Set:fromList([2, 3])))),
    ?assertEqual(true, Set:isSubset(Set:fromList([2]), Filled)),
    ?assertEqual(false, Set:isSubset(Filled, Set:fromList([2]))),
    ?assert(Set:fromList([1, 2]) =:= Set:fromList([2, 1])),
    ?assertEqual([2, 4], lists:sort(Set:toList(Set:map(Filled, fun(X) -> X * 2 end)))),
    ?assertEqual([2], Set:toList(Set:filter(Filled, fun(X) -> X > 1 end))),
    ?assertEqual([20], Set:toList(Set:filterMap(Filled, fun(1) -> 'None';
                                                           (X) -> {'Some', X * 10}
                                                        end))),
    ?assertEqual('Unit', Set:foreach(Filled, fun(_) -> 'Unit' end)),
    ?assertEqual(3, Set:foldLeft(Filled, 0, fun(A, X) -> A + X end)),
    ?assertEqual(true, Set:any(Filled, fun(X) -> X > 1 end)),
    ?assertEqual(false, Set:all(Filled, fun(X) -> X > 1 end)),
    ?assertEqual({'Some', 2}, Set:find(Filled, fun(X) -> X > 1 end)),
    ?assertEqual('None', Set:find(Filled, fun(X) -> X > 2 end)).

%% report Appendix E.5, E.0 rule 1: the searches written over indexOf match
%% whole graphemes, so a letter under a combining mark is not found alone;
%% an empty part is at the start and the end; the trims strip White_Space
%% by Char.isSpace, U+00A0 and U+3000 among it and U+200E not; case mapping
%% is full, without the rules of a language or a context. Written with the
%% searches' move to Ernest; the earlier shims split and ended by bytes.
string_graphemes_test() ->
    String = 'ern@string',
    Composed = <<"e\x{301}"/utf8>>,
    ?assertEqual(false, String:contains(Composed, <<"e">>)),
    ?assertEqual([Composed], String:split(Composed, <<"e">>)),
    ?assertEqual(false, String:startsWith(Composed, <<"e">>)),
    ?assertEqual(false, String:endsWith(<<"ae\x{301}"/utf8>>, <<"\x{301}"/utf8>>)),
    ?assertEqual(Composed, String:replace(Composed, <<"e">>, <<"x">>)),
    ?assertEqual([<<"a">>, <<"b">>, <<>>], String:split(<<"a,b,">>, <<",">>)),
    ?assertEqual(true, String:contains(<<"abc">>, <<>>)),
    ?assertEqual(true, String:startsWith(<<"abc">>, <<>>)),
    ?assertEqual(true, String:endsWith(<<"abc">>, <<>>)),
    ?assertEqual(<<"a">>, String:trim(<<"\x{a0}a\x{3000}"/utf8>>)),
    ?assertEqual(<<"\x{200e}a"/utf8>>, String:trimStart(<<" \x{200e}a"/utf8>>)),
    ?assertEqual(<<"a ">>, String:trimStart(<<"\r\n a ">>)),
    ?assertEqual(<<" a">>, String:trimEnd(<<" a \r\n">>)),
    %% report Appendix E.5, E.0 rule 1: a grapheme is removed by its first
    %% code point, a space that a combining mark joins among them, and one a
    %% prepended code point begins is kept; `trimEnd` is Ernest over the
    %% private `lastGrapheme`, which splits from an ASCII byte near the end
    %% and steps back to the one before where that leaves one grapheme: a
    %% line feed after a carriage return, a long cluster, flags and a joined
    %% emoji before a space, and text with no ASCII, split whole. A
    %% regression test of the primitive that replaced the shim, and before
    %% it a list of every grapheme, 34 times the host's trim over 100 KB
    ?assertEqual(<<"a">>, String:trimEnd(<<"a \x{301}\t"/utf8>>)),
    ?assertEqual(<<"a\x{600} "/utf8>>, String:trimEnd(<<"a\x{600} \n"/utf8>>)),
    ?assertEqual(<<"é"/utf8>>, String:trimEnd(<<"é\x{3000}"/utf8>>)),
    ?assertEqual(<<>>, String:trimEnd(<<" \r\n\x{2028}"/utf8>>)),
    ?assertEqual(<<>>, String:trimEnd(<<>>)),
    ?assertEqual(<<"a">>, String:trimEnd(<<"a\r\n\r\n">>)),
    ?assertEqual(<<>>, String:trimEnd(<<"\r\n">>)),
    Cluster = unicode:characters_to_binary([$a | lists:duplicate(300, 16#301)]),
    ?assertEqual(Cluster, String:trimEnd(<<Cluster/binary, " \x{301} "/utf8>>)),
    ?assertEqual(<<"\x{1F1F8}\x{1F1EA}\x{1F1F8}"/utf8>>,
                 String:trimEnd(<<"\x{1F1F8}\x{1F1EA}\x{1F1F8} "/utf8>>)),
    ?assertEqual(<<"\x{1F468}\x{200D}\x{1F469}"/utf8>>,
                 String:trimEnd(<<"\x{1F468}\x{200D}\x{1F469}\x{3000} \n"/utf8>>)),
    ?assertEqual(<<"éé"/utf8>>, String:trimEnd(<<"éé\x{3000}\x{2003}"/utf8>>)),
    ?assertEqual(<<"\x{915}\x{94D}\x{937}"/utf8>>,
                 String:trimEnd(<<"\x{915}\x{94D}\x{937} \x{A0}"/utf8>>)),
    ?assertEqual(<<"SS">>, String:toUpper(<<"ß"/utf8>>)),
    ?assertEqual(<<"σασ"/utf8>>, String:toLower(<<"ΣΑΣ"/utf8>>)),
    ?assertEqual('Less', String:compare(<<"z">>, <<"é"/utf8>>)).

%% report Appendix E.5: a search matches whole graphemes, beginning where
%% the string's own graphemes begin as well as ending where they end, so
%% `split` and `replace` keep every grapheme whole; `lines` ends a line at
%% a carriage return with a line feed, one grapheme, as at a line feed. A
%% regression test: a part that began inside a grapheme, a lone combining
%% mark, the line feed of a carriage return's, one person of a joined emoji,
%% was found there, and splitting at it lost the grapheme's first part
string_searches_begin_at_a_grapheme_test() ->
    String = 'ern@string',
    Mark = <<"\x{301}"/utf8>>,
    Family = <<"x\x{1F468}\x{200D}\x{1F469}y"/utf8>>,
    ?assertEqual('None', String:indexOf(<<"e\x{301}x"/utf8>>, Mark)),
    ?assertEqual([<<"e\x{301}x"/utf8>>], String:split(<<"e\x{301}x"/utf8>>, Mark)),
    ?assertEqual([<<"a\r\nb">>], String:split(<<"a\r\nb">>, <<"\n">>)),
    ?assertEqual(Family, String:replace(Family, <<"\x{1F469}"/utf8>>, <<"X">>)),
    ?assertEqual({'Some', 2}, String:lastIndexOf(<<"aa\x{301}a"/utf8>>, <<"a">>)),
    ?assertEqual([<<"a">>, <<"b">>], String:lines(<<"a\r\nb\r\n">>)),
    ?assertEqual([<<"a">>, <<"b">>], String:lines(<<"a\nb">>)).

%% report Appendix E.5: `words` splits at runs of White_Space, the Unicode
%% property, a no-break space and a line separator among them, and gives
%% no empty word. Written with the code
string_words_test() ->
    String = 'ern@string',
    ?assertEqual([], String:words(<<>>)),
    ?assertEqual([<<"a">>], String:words(<<"a">>)),
    ?assertEqual([<<"a">>, <<"b">>, <<"c">>],
                 String:words(<<" a\x{A0}b\x{2028}\r\n c "/utf8>>)),
    ?assertEqual([<<"e\x{301}"/utf8>>], String:words(<<"e\x{301}"/utf8>>)).

%% report Appendix E.5: `split`, `lines` and `replace` read the string
%% once. A regression test: each part measured the rest again, a cost that
%% grew as the square of the parts, 2.6 s for 16,000 of them; 64,000 now
%% take a fraction of EUnit's five seconds, and took about forty before
string_split_reads_once_test() ->
    String = 'ern@string',
    Text = iolist_to_binary(lists:duplicate(64000, <<"abcd,">>)),
    ?assertEqual(64001, length(String:split(Text, <<",">>))),
    ?assertEqual(64000, length(String:lines(binary:replace(Text, <<",">>, <<"\n">>, [global])))),
    ?assertEqual(byte_size(Text), byte_size(String:replace(Text, <<",">>, <<";">>))).

%% report Appendix E.5, §9.6
string_test() ->
    String = 'ern@string',
    ?assertEqual(2, String:size(<<"hé"/utf8>>)),
    ?assertEqual(true, String:isEmpty(<<>>)),
    ?assertEqual(true, String:contains(<<"hello">>, <<"ell">>)),
    ?assertEqual({'Some', 2}, String:indexOf(<<"hello">>, <<"ll">>)),
    ?assertEqual('None', String:indexOf(<<"hello">>, <<"x">>)),
    ?assertEqual({'Some', 3}, String:lastIndexOf(<<"hello">>, <<"l">>)),
    ?assertEqual(true, String:startsWith(<<"hello">>, <<"he">>)),
    ?assertEqual(false, String:startsWith(<<"hello">>, <<"lo">>)),
    ?assertEqual(true, String:endsWith(<<"héllo"/utf8>>, <<"llo">>)),
    ?assertEqual(false, String:endsWith(<<"he">>, <<"hello">>)),
    ?assertEqual(<<"hella wald">>, String:replace(<<"hello wold">>, <<"o">>, <<"a">>)),
    ?assertEqual(<<"abc">>, String:replace(<<"abc">>, <<>>, <<"x">>)),
    ?assertEqual(<<"éll"/utf8>>, String:slice(<<"héllo"/utf8>>, 1, 3)),
    ?assertEqual(<<"lo">>, String:slice(<<"hello">>, 3, 10)),
    ?assertEqual(<<>>, String:slice(<<"hello">>, -1, -1)),
    ?assertEqual(<<"007">>, String:padStart(<<"7">>, 3, <<"0">>)),
    ?assertEqual(<<"7  ">>, String:padEnd(<<"7">>, 3, <<" ">>)),
    ?assertEqual(<<"hello">>, String:padStart(<<"hello">>, 3, <<"0">>)),
    %% report Appendix E.5: the pad is text, its copies cut to fit, and an
    %% empty pad adds none
    ?assertEqual(<<"ab-7">>, String:padStart(<<"7">>, 4, <<"ab-">>)),
    ?assertEqual(<<"7éaé"/utf8>>, String:padEnd(<<"7">>, 4, <<"éa"/utf8>>)),
    ?assertEqual(<<"7">>, String:padStart(<<"7">>, 3, <<>>)),
    ?assertEqual(<<"ababab">>, String:repeat(<<"ab">>, 3)),
    ?assertEqual(<<>>, String:repeat(<<"ab">>, -1)),
    ?assertEqual(<<"a b">>, String:trim(<<" \ta b\n">>)),
    ?assertEqual(<<"abc">>, String:toLower(<<"AbC">>)),
    ?assertEqual({'Some', -12}, String:toInt(<<"-12">>)),
    ?assertEqual('None', String:toInt(<<"1a">>)),
    ?assertEqual('None', String:toInt(<<"-">>)),
    ?assertEqual('None', String:toInt(<<>>)),
    %% report Appendix E.5: an integer the host cannot hold is None. A
    %% regression test: the host's system_limit faulted the caller
    Huge = binary:copy(<<"9">>, 1300000),
    ?assertEqual('None', String:toInt(Huge)),
    ?assertEqual('None', String:toIntBase(<<"-", Huge/binary>>, 16)),
    %% report Appendix E.5, E.0 rule 1: the digits are read in Ernest, a long
    %% numeral in halves joined by a power of the base, so its value is the
    %% host's at every length past the forty digits read in one pass; a `+`
    %% and a sign alone read as nothing. A regression test of the reading
    %% that replaced the host's, which covers no length past a few thousand
    ?assertEqual('None', String:toIntBase(<<"+5">>, 10)),
    ?assertEqual('None', String:toIntBase(<<"-">>, 16)),
    ?assertEqual('None', String:toIntBase(<<"z">>, 35)),
    ?assertEqual({'Some', 35}, String:toIntBase(<<"Z">>, 36)),
    [?assertEqual({'Some', binary_to_integer(Numeral, Base)}, String:toIntBase(Numeral, Base))
     || Length <- [40, 41, 81, 1000, 3001],
        Base <- [2, 10, 16, 36],
        Sign <- [<<>>, <<"-">>],
        Numeral <- [<<Sign/binary,
                      (list_to_binary([lists:nth(Index rem Base + 1,
                                                 "0123456789abcdefghijklmnopqrstuvwxyz")
                                       || Index <- lists:seq(1, Length)]))/binary>>]],
    ?assertEqual({'Some', -1.5}, String:toFloat(<<"-1.5">>)),
    ?assertEqual({'Some', 1.0e-9}, String:toFloat(<<"1.0e-9">>)),
    ?assertEqual('None', String:toFloat(<<"1">>)),
    %% report §2.5, Appendix E.5: an exponent alone is a float's literal
    %% form
    ?assertEqual({'Some', 1.0e5}, String:toFloat(<<"1e5">>)),
    ?assertEqual({'Some', -2.0e-3}, String:toFloat(<<"-2E-3">>)),
    ?assertEqual('None', String:toFloat(<<"1e">>)),
    ?assertEqual('None', String:toFloat(<<"1.0e999">>)),
    %% the form read by a scan of its own, which a pattern once checked; a
    %% regression test for the edges of the form
    ?assertEqual({'Some', 150.0}, String:toFloat(<<"1.5E+2">>)),
    ?assertEqual({'Some', 0.0}, String:toFloat(<<"-0.0">>)),
    [?assertEqual('None', String:toFloat(Text))
     || Text <- [<<"1.">>, <<".5">>, <<"1.5e">>, <<"1.5e+">>, <<"1.5.3">>, <<"--1.5">>,
                 <<"+1.5">>, <<"1.5 ">>, <<"-">>, <<>>]],
    ?assertEqual(<<"ABC">>, String:toUpper(<<"abC">>)),
    ?assertEqual([$a, $b], String:toList(<<"ab">>)),
    ?assertEqual(<<"ab">>, String:fromList([$a, $b])),
    ?assertEqual({'Some', <<"ab">>}, String:fromUtf8(<<"ab">>)),
    ?assertEqual('None', String:fromUtf8(<<255>>)),
    ?assertEqual(<<"ab">>, String:toUtf8(<<"ab">>)),
    ?assertEqual([<<"a">>, <<"b">>], String:lines(<<"a\nb\n">>)),
    ?assertEqual([<<"a">>, <<>>, <<"b">>], String:lines(<<"a\n\nb">>)),
    ?assertEqual([], String:lines(<<>>)),
    ?assertEqual([<<"a">>, <<>>, <<"b">>], String:split(<<"a,,b">>, <<",">>)),
    ?assertEqual([<<>>], String:split(<<>>, <<",">>)),
    ?assertEqual(<<"a, b">>, String:join([<<"a">>, <<"b">>], <<", ">>)),
    ?assertEqual(<<>>, String:join([], <<", ">>)),
    ?assertEqual({'Some', true}, String:toBool(<<"true">>)),
    ?assertEqual({'Some', false}, String:toBool(<<"false">>)),
    ?assertEqual('None', String:toBool(<<"yes">>)),
    ?assertEqual({'Some', 255}, String:toIntBase(<<"ff">>, 16)),
    ?assertEqual({'Some', 255}, String:toIntBase(<<"FF">>, 16)),
    ?assertEqual('None', String:toIntBase(<<"fg">>, 16)),
    ?assertEqual('None', String:toIntBase(<<"1">>, 40)),
    ?assertEqual(<<"hel">>, String:slice(<<"hello">>, -1, 3)),
    ?assertEqual(<<>>, String:slice(<<"hello">>, 1, -1)),
    ?assertEqual({'Some', 7}, String:toInt(<<"007">>)),
    ?assertEqual('None', String:toInt(<<"-">>)),
    ?assertEqual({'Some', -255}, String:toIntBase(<<"-ff">>, 16)),
    ?assertEqual([<<"a">>], String:split(<<"a">>, <<>>)),
    ?assertEqual('Less', String:compare(<<"a">>, <<"b">>)),
    ?assertEqual('Equal', String:compare(<<"a">>, <<"a">>)).

%% report Appendix E.5, §2.5: String.toFloat reads the float literal form
%% without `_` grouping; an exponent below the smallest Float gives 0.0, one
%% beyond the largest gives None. A regression test, written after the
%% code; it does not cover a form without a digit on each side of the point
string_to_float_edges_test() ->
    String = 'ern@string',
    ?assertEqual('None', String:toFloat(<<"3.141_592">>)),
    ?assertEqual({'Some', 0.0}, String:toFloat(<<"1.0e-400">>)),
    ?assertEqual('None', String:toFloat(<<"1.0e400">>)).

%% report Appendix E.6, §9.6
char_test() ->
    Char = 'ern@char',
    ?assertEqual(true, Char:isDigit($7)),
    ?assertEqual(true, Char:isDigit(16#663)),
    ?assertEqual(false, Char:isDigit($a)),
    %% the digits String.toInt reads, and no other script's
    ?assertEqual(true, Char:isAsciiDigit($7)),
    ?assertEqual(false, Char:isAsciiDigit(16#663)),
    ?assertEqual(false, Char:isAsciiDigit($a)),
    ?assertEqual(true, Char:isAlpha($z)),
    ?assertEqual(true, Char:isAlpha(16#4E2D)),
    ?assertEqual(false, Char:isAlpha($1)),
    ?assertEqual(false, Char:isAlpha(16#663)),
    ?assertEqual(true, Char:isSpace($\n)),
    ?assertEqual(true, Char:isSpace($\s)),
    ?assertEqual(false, Char:isSpace($a)),
    ?assertEqual(true, Char:isSpace(16#85)),
    ?assertEqual(true, Char:isSpace(16#3000)),
    ?assertEqual(false, Char:isSpace(16#200E)),
    %% the host's own tables, which its string module follows: White_Space
    %% as Unicode has it, and a letter Unicode 17 added. A regression test
    %% for the regular expression the properties were once read by, whose
    %% tables were older than the host's
    ?assertEqual(true, Char:isSpace(16#2028)),
    ?assertEqual(false, Char:isSpace(16#180E)),
    ?assertEqual(false, Char:isSpace(16#200B)),
    ?assertEqual(true, Char:isUpper(16#A7CE)),
    ?assertEqual(true, Char:isUpper($A)),
    ?assertEqual(false, Char:isUpper($a)),
    ?assertEqual(true, Char:isLower(16#E9)),
    ?assertEqual(false, Char:isLower(16#C9)),
    ?assertEqual($A, Char:toUpper($a)),
    ?assertEqual(16#C9, Char:toUpper(16#E9)),
    ?assertEqual(16#DF, Char:toUpper(16#DF)),
    ?assertEqual($a, Char:toLower($A)),
    ?assertEqual($1, Char:toLower($1)),
    ?assertEqual({'Some', 16#E9}, Char:fromInt(16#E9)),
    ?assertEqual('None', Char:fromInt(16#D800)),
    ?assertEqual('None', Char:fromInt(16#110000)),
    ?assertEqual('None', Char:fromInt(-1)),
    ?assertEqual(<<"é"/utf8>>, Char:toString(16#E9)),
    ?assertEqual(16#E9, Char:toInt(16#E9)),
    ?assertEqual('Greater', Char:compare($b, $a)).

%% report Appendix E.20
bytes_test() ->
    Bytes = 'ern@bytes',
    ?assertEqual(3, Bytes:size(<<1, 2, 3>>)),
    ?assertEqual(true, Bytes:isEmpty(<<>>)),
    ?assertEqual({'Some', 8}, Bytes:get(<<7, 8>>, 1)),
    ?assertEqual('None', Bytes:get(<<7, 8>>, 2)),
    ?assertEqual('None', Bytes:get(<<7, 8>>, -1)),
    ?assertEqual(<<2, 3>>, Bytes:slice(<<1, 2, 3>>, 1, 5)),
    ?assertEqual(<<>>, Bytes:slice(<<1, 2, 3>>, 3, 1)),
    ?assertEqual(<<>>, Bytes:slice(<<1, 2, 3>>, 0, -1)),
    ?assertEqual([104, 105], Bytes:toList(<<"hi">>)),
    ?assertEqual({'Some', <<104, 105>>}, Bytes:fromList([104, 105])),
    ?assertEqual('None', Bytes:fromList([256])),
    ?assertEqual(<<1, 2>>, Bytes:'<>'(<<1>>, <<2>>)).

%% report Appendix E.20: the text functions over octets, at their edges: an
%% empty second is at 0 for `indexOf` and at the end for `lastIndexOf`, is
%% in every `Bytes`, begins and ends every one, splits nothing and
%% replaces nothing; a count below 0 repeats nothing; hexadecimal is
%% upper-case out and either case in, and an odd count or another
%% character is None. A regression test: the ten functions were tested only
%% by their pages' examples, and `lastIndexOf` was missing
bytes_text_test() ->
    Bytes = 'ern@bytes',
    ?assertEqual(true, Bytes:contains(<<1, 2>>, <<>>)),
    ?assertEqual(false, Bytes:contains(<<1, 2>>, <<2, 1>>)),
    ?assertEqual({'Some', 0}, Bytes:indexOf(<<1>>, <<>>)),
    ?assertEqual({'Some', 1}, Bytes:indexOf(<<0, 1, 2, 1, 2>>, <<1, 2>>)),
    ?assertEqual({'Some', 3}, Bytes:lastIndexOf(<<0, 1, 2, 1, 2>>, <<1, 2>>)),
    ?assertEqual({'Some', 2}, Bytes:lastIndexOf(<<1, 2>>, <<>>)),
    ?assertEqual('None', Bytes:lastIndexOf(<<1>>, <<1, 1>>)),
    ?assertEqual(true, Bytes:startsWith(<<1>>, <<>>)),
    ?assertEqual(true, Bytes:endsWith(<<1>>, <<>>)),
    ?assertEqual(false, Bytes:endsWith(<<1>>, <<0, 1>>)),
    ?assertEqual([<<1, 2>>], Bytes:split(<<1, 2>>, <<>>)),
    ?assertEqual([<<>>, <<1>>, <<>>], Bytes:split(<<0, 1, 0>>, <<0>>)),
    ?assertEqual(<<1, 2>>, Bytes:replace(<<1, 2>>, <<>>, <<9>>)),
    ?assertEqual(<<9, 2, 9>>, Bytes:replace(<<1, 2, 1>>, <<1>>, <<9>>)),
    ?assertEqual(<<1, 0, 2>>, Bytes:join([<<1>>, <<2>>], <<0>>)),
    ?assertEqual(<<>>, Bytes:join([], <<0>>)),
    ?assertEqual(<<1, 1, 1>>, Bytes:repeat(<<1>>, 3)),
    ?assertEqual(<<>>, Bytes:repeat(<<1>>, -2)),
    ?assertEqual(<<"00FF1A">>, Bytes:toHex(<<0, 255, 26>>)),
    ?assertEqual({'Some', <<0, 255, 26>>}, Bytes:fromHex(<<"00ff1A">>)),
    ?assertEqual('None', Bytes:fromHex(<<"0">>)),
    ?assertEqual('None', Bytes:fromHex(<<"0g">>)).

%% report Appendix E.19
erl_test() ->
    ?assertEqual(ready, 'ern@erl':atom(<<"ready">>)).

%% report Appendix E.7
bool_test() ->
    ?assertEqual(false, 'ern@bool':'not'(true)),
    ?assertEqual(<<"true">>, 'ern@bool':toString(true)).

%% report Appendix E.8, §7.4: a shift whose result is beyond the host's
%% integers faults as `*` does at that limit, a limit of the host met. A
%% regression test: it faulted as a foreign function's raise, naming
%% erlang:bsl/2, which no program wrote
int_shift_limit_test() ->
    ?assertThrow({ern, fault, <<"error:system_limit">>}, 'ern@int':shiftLeft(1, 1 bsl 40)).

%% report Appendix E.8, §3.1, §7.4, §9.6
int_test() ->
    Int = 'ern@int',
    ?assertEqual(3, Int:abs(-3)),
    ?assertEqual(1, Int:min(1, 2)),
    ?assertEqual(2, Int:max(1, 2)),
    ?assertEqual(2, Int:bitAnd(6, 3)),
    ?assertEqual(7, Int:bitOr(6, 3)),
    ?assertEqual(5, Int:bitXor(6, 3)),
    ?assertEqual(-7, Int:bitNot(6)),
    ?assertEqual(12, Int:shiftLeft(3, 2)),
    ?assertEqual(-2, Int:shiftRight(-7, 2)),
    ?assertEqual(<<"-7">>, Int:toString(-7)),
    ?assertEqual(7.0, Int:toFloat(7)),
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, Int:toFloat(1 bsl 2000)),
    ?assertEqual({'Some', -2}, Int:'div'(-7, 3)),
    ?assertEqual({'Some', -1}, Int:'rem'(-7, 3)),
    ?assertEqual('None', Int:'div'(1, 0)),
    ?assertEqual('Less', Int:compare(1, 2)),
    ?assertEqual(-1, Int:negate(1)),
    ?assertEqual({'Some', 1024}, Int:pow(2, 10)),
    ?assertEqual({'Some', 1}, Int:pow(7, 0)),
    ?assertEqual({'Some', -8}, Int:pow(-2, 3)),
    ?assertEqual('None', Int:pow(2, -1)),
    ?assertEqual({'Some', <<"FF">>}, Int:toStringBase(255, 16)),
    ?assertEqual({'Some', <<"-11">>}, Int:toStringBase(-3, 2)),
    ?assertEqual('None', Int:toStringBase(5, 37)).

%% report Appendix E.8, §3.1, §7.4: Int.toFloat rounds to the nearest
%% Float and faults only where the rounding gives no finite Float: the
%% largest finite Float as an Int, plus 2^970 - 1, rounds down to it, and
%% plus 2^970 faults, of either sign. Int.pow(0, 0) is 1, and a count
%% below 0 shifts by none. A regression test, written after the code;
%% it does not cover the rounding of an Int within the range
int_edges_test() ->
    Int = 'ern@int',
    Max = (1 bsl 53 - 1) bsl 971,
    ?assertEqual(1.7976931348623157e308, Int:toFloat(Max)),
    ?assertEqual(1.7976931348623157e308, Int:toFloat(Max + (1 bsl 970) - 1)),
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, Int:toFloat(Max + (1 bsl 970))),
    ?assertThrow({ern, fault, <<"Int out of Float range">>}, Int:toFloat(-(Max + (1 bsl 970)))),
    ?assertEqual({'Some', 1}, Int:pow(0, 0)),
    %% report §7.4, E.8: a count below 0 is none; a regression test of the rule,
    %% before which it shifted the other way
    ?assertEqual(8, Int:shiftLeft(8, -2)),
    ?assertEqual(8, Int:shiftRight(8, -2)).

%% report Appendix E.9, §3.1, §7.4, §9.6
float_test() ->
    Float = 'ern@float',
    %% E.0 rule 3: a constant of the type, the host's own nearest Float
    ?assertEqual(math:pi(), Float:pi()),
    ?assertEqual(3.5, Float:'+'(Float:'*'(1.5, 2.0), 0.5)),
    ?assertEqual(-1.0, Float:'-'(1.0, 2.0)),
    ?assertEqual(0.5, Float:'/'(1.0, 2.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, Float:'/'(1.0, 0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, Float:'*'(1.0e308, 10.0)),
    ?assertEqual(1.5, Float:abs(-1.5)),
    ?assertEqual(0.0, Float:abs(0.0)),
    ?assertEqual(2.0, Float:abs(2.0)),
    ?assertEqual(1.0, Float:min(1.0, 2.0)),
    ?assertEqual(2.0, Float:max(1.0, 2.0)),
    ?assertEqual(<<"0.1">>, Float:toString(0.1)),
    ?assertEqual(<<"100.0">>, Float:toString(100.0)),
    ?assertEqual(2, Float:round(2.5)),
    ?assertEqual(4, Float:round(3.5)),
    ?assertEqual(-2, Float:round(-2.5)),
    ?assertEqual(3, Float:round(2.7)),
    ?assertEqual(-3, Float:floor(-2.5)),
    ?assertEqual(-2, Float:ceil(-2.5)),
    ?assertEqual('Greater', Float:compare(2.0, 1.0)),
    ?assertEqual(-1.0, Float:negate(1.0)),
    ?assertEqual(-2, Float:truncate(-2.7)),
    ?assertEqual({'Some', 3.0}, Float:sqrt(9.0)),
    ?assertEqual('None', Float:sqrt(-1.0)),
    ?assertEqual({'Some', 1024.0}, Float:pow(2.0, 10.0)),
    %% Appendix E.9: the domain is None, as for sqrt and log, and an
    %% integral exponent keeps a negative base in it; overflow still faults
    ?assertEqual('None', Float:pow(-8.0, 0.5)),
    ?assertEqual('None', Float:pow(0.0, -1.0)),
    ?assertEqual({'Some', -8.0}, Float:pow(-2.0, 3.0)),
    ?assertEqual({'Some', 1.0}, Float:pow(0.0, 0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, Float:pow(10.0, 400.0)),
    ?assertEqual(1.0, Float:exp(0.0)),
    ?assertThrow({ern, fault, <<"float arithmetic error">>}, Float:exp(1000.0)),
    ?assertEqual({'Some', 0.0}, Float:log(1.0)),
    ?assertEqual('None', Float:log(0.0)),
    ?assertEqual({0.0, 1.0, 0.0}, {Float:sin(0.0), Float:cos(0.0), Float:tan(0.0)}),
    ?assertEqual({'Some', 0.0}, Float:asin(0.0)),
    ?assertEqual('None', Float:acos(-2.0)),
    ?assertEqual(0.0, Float:atan2(0.0, 1.0)).

%% report §3.1, §3.10: there is no negative zero, so a negative result too
%% small for the range is the one zero, which `==` and `Float.compare` both
%% call equal to `0.0`. A regression test: `Float.atan2` and `Float.pow`
%% answered the host's `-0.0`, which printed as `0.0`, compared `Equal` to
%% it and was not `==` to it, so a `Map` held both as keys
float_has_one_zero_test() ->
    Float = 'ern@float',
    Small = Float:atan2(-1.0e-300, 1.0e300),
    {'Some', Power} = Float:pow(-1.0e-200, 3.0),
    ?assert(Small =:= +0.0),
    ?assert(Power =:= +0.0),
    ?assertEqual('Equal', Float:compare(Small, 0.0)).

%% report Appendix E.10
optional_test() ->
    Optional = 'ern@optional',
    ?assertEqual(true, Optional:isSome({'Some', 1})),
    ?assertEqual(true, Optional:isNone('None')),
    ?assertEqual(1, Optional:withDefault({'Some', 1}, 0)),
    ?assertEqual(0, Optional:withDefault('None', 0)),
    ?assertEqual({'Some', 2}, Optional:map({'Some', 1}, fun(X) -> X + 1 end)),
    ?assertEqual('None', Optional:andThen({'Some', 1}, fun(_) -> 'None' end)).

%% report Appendix E.11
either_test() ->
    Either = 'ern@either',
    ?assertEqual(true, Either:isLeft({'Left', e})),
    ?assertEqual(true, Either:isRight({'Right', 1})),
    ?assertEqual(1, Either:withDefault({'Right', 1}, 0)),
    ?assertEqual(0, Either:withDefault({'Left', e}, 0)),
    ?assertEqual({'Right', 2}, Either:map({'Right', 1}, fun(X) -> X + 1 end)),
    ?assertEqual({'Left', f}, Either:mapLeft({'Left', e}, fun(e) -> f end)),
    ?assertEqual({'Left', e}, Either:andThen({'Left', e}, fun(X) -> {'Right', X} end)),
    ?assertEqual({'Some', 1}, Either:toOptional({'Right', 1})),
    ?assertEqual({'Left', e}, Either:fromOptional('None', e)).

%% report Appendix E.1, §8.2: print and println write to Io's stdout,
%% printError, printlnError and debug to its stderr, each as a message;
%% report §9.4, §4.9: debug takes its requirement's member, the
%% descriptor of the value's type, after the value
io_test() ->
    Self = self(),
    Sink = fun(Tag) -> fun(Bytes) -> Self ! {Tag, Bytes} end end,
    Result = ern_rt:run_main(fun() ->
                                 'ern@io':print(<<"a">>),
                                 'ern@io':println(<<"b">>),
                                 'ern@io':printError(<<"c">>),
                                 'ern@io':printlnError(<<"d">>),
                                 'ern@io':debug(42, int)
                             end, <<"io_test">>,
                             #{stdout => Sink(out), stderr => Sink(err)}),
    ?assertEqual(ok, Result),
    ?assertEqual([<<"a">>, <<"b\n">>], collect(out, [])),
    ?assertEqual([<<"c">>, <<"d\n">>, <<"42\n">>], collect(err, [])).

%% report Appendix E.1, §8.2: readLine gives the next line without its line
%% feed, and None at end of input
io_read_line_test() ->
    Self = self(),
    Lines = ern_rt_tests:queued_input(["one\n", "two"], fun() -> eof end),
    Result = ern_rt:run_main(fun() ->
                                 Self ! {read, 'ern@io':readLine()},
                                 Self ! {read, 'ern@io':readLine()},
                                 Self ! {read, 'ern@io':readLine()}
                             end, <<"io_read_line_test">>, #{stdin => Lines}),
    ?assertEqual(ok, Result),
    ?assertEqual([{'Some', <<"one">>}, {'Some', <<"two">>}, 'None'], collect(read, [])).

collect(Tag, Acc) ->
    receive {Tag, Bytes} -> collect(Tag, [Bytes | Acc])
    after 0 -> lists:reverse(Acc)
    end.

%% report Appendix E.17, E.23: an entry holds its file's permission bits,
%% as Fs.setMode takes them and without the host's type bits, and the
%% host's number for the user it belongs to, which is Os.user for a file
%% the program made; Fs.stat follows a link, and Fs.list describes it as
%% it is. A regression test, written after the code; it does not cover a
%% file of another user, which a test cannot make
entry_mode_and_user_test() ->
    Self = self(),
    Dir = scratch("ern_owned_"),
    ok = filelib:ensure_path(Dir),
    InDir = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    ok = ern_rt:run_main(
           fun() ->
               {'Right', 'Unit'} = Fs:write(InDir("private.txt"), <<"secret">>, 5000),
               {'Right', 'Unit'} = Fs:setMode(InDir("private.txt"), 8#640, 5000),
               {'Right', 'Unit'} = Fs:makeLink(InDir("link"), InDir("private.txt"), 5000),
               Self ! {owned, {Fs:stat(InDir("private.txt"), 5000), Fs:stat(InDir("link"), 5000),
                               Fs:list({'Path', unicode:characters_to_binary(Dir)}, 5000),
                               'ern@os':user()}}
           end, <<"entry_mode_and_user_test">>, #{}),
    {Stat, ThroughLink, {'Right', Listed}, User} = receive {owned, Owned} -> Owned end,
    {ok, #file_info{uid = Uid}} = file:read_file_info(filename:join(Dir, "private.txt")),
    ?assertEqual(Uid, User),
    ?assertMatch({'Right', {'Entry', _, _, 6, 'File', 8#640, User}}, Stat),
    ?assertMatch({'Right', {'Entry', _, _, 6, 'File', 8#640, User}}, ThroughLink),
    [{'Entry', _, _, _, 'Link', LinkMode, User}] =
        [Entry || {'Entry', {'Path', Path}, _, _, _, _, _} = Entry <- Listed,
                  filename:basename(Path) =:= <<"link">>],
    ?assert(LinkMode =< 8#7777),
    file:del_dir_r(Dir).

%% report Appendix E.17, §8.2: the file system through Fs's reference, each answer
%% Right or Left(Io.Error), and Left(Timeout) when the wait runs out
fs_test() ->
    Self = self(),
    Dir = scratch("ern_fs_"),
    ok = filelib:ensure_path(Dir),
    InDir = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    Result = ern_rt:run_main(
               fun() ->
                   Self ! {fs, Fs:write(InDir("a.txt"), <<"hello">>, 5000)},
                   Self ! {fs, Fs:read(InDir("a.txt"), 5000)},
                   Self ! {fs, Fs:append(InDir("a.txt"), <<"!">>, 5000)},
                   Self ! {fs, Fs:read(InDir("a.txt"), 5000)},
                   Self ! {fs, Fs:stat(InDir("a.txt"), 5000)},
                   Self ! {fs, Fs:rename(InDir("a.txt"), InDir("b.txt"), 5000)},
                   Self ! {fs, Fs:copy(InDir("b.txt"), InDir("c.txt"), 5000)},
                   Self ! {fs, Fs:makeDir(InDir("d/e"), 5000)},
                   Self ! {fs, Fs:list({'Path', unicode:characters_to_binary(Dir)}, 5000)},
                   Self ! {fs, Fs:remove(InDir("c.txt"), 5000)},
                   Self ! {fs, Fs:read(InDir("c.txt"), 5000)}
               end, <<"fs_test">>, #{}),
    ?assertEqual(ok, Result),
    [Write, Read, Append, ReadAppended, Stat, Rename, Copy, MakeDir, List, Remove, Gone] =
        collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Write),
    ?assertEqual({'Right', <<"hello">>}, Read),
    ?assertEqual({'Right', 'Unit'}, Append),
    ?assertEqual({'Right', <<"hello!">>}, ReadAppended),
    ?assertMatch({'Right', {'Entry', _, _, 6, 'File', _, _}}, Stat),
    ?assertEqual({'Right', 'Unit'}, Rename),
    ?assertEqual({'Right', 'Unit'}, Copy),
    ?assertEqual({'Right', 'Unit'}, MakeDir),
    {'Right', Entries} = List,
    ?assertEqual([<<"b.txt">>, <<"c.txt">>, <<"d">>],
                 lists:sort([filename:basename(Path)
                             || {'Entry', {'Path', Path}, _, _, _, _, _} <- Entries])),
    ?assertEqual({'Right', 'Unit'}, Remove),
    ?assertEqual({'Left', 'NotFound'}, Gone),
    file:del_dir_r(Dir).

%% report Appendix E.17: a copy made where nothing was has the source's
%% permission bits less the program's mask, as cp(1) makes it, and one
%% made over a file keeps that file's. A regression test: a copy of a
%% file only its owner could read was made as the mask leaves `0o666`, so
%% every user could read it
fs_copy_mode_test() ->
    Self = self(),
    Dir = scratch("ern_copy_mode_"),
    ok = filelib:ensure_path(Dir),
    Name = fun(File) -> filename:join(Dir, File) end,
    InDir = fun(File) -> {'Path', unicode:characters_to_binary(Name(File))} end,
    ok = file:write_file(Name("private"), <<"secret">>),
    ok = file:change_mode(Name("private"), 8#600),
    ok = file:write_file(Name("script"), <<"run">>),
    ok = file:change_mode(Name("script"), 8#755),
    ok = file:write_file(Name("kept"), <<"old">>),
    ok = file:change_mode(Name("kept"), 8#640),
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:copy(InDir("private"), InDir("private_copy"), 5000)},
                           Self ! {fs, Fs:copy(InDir("script"), InDir("script_copy"), 5000)},
                           Self ! {fs, Fs:copy(InDir("script"), InDir("kept"), 5000)}
                       end, <<"fs_copy_mode_test">>, #{})),
    ?assertEqual([{'Right', 'Unit'}, {'Right', 'Unit'}, {'Right', 'Unit'}], collect(fs, [])),
    Mask = list_to_integer(string:trim(os:cmd("umask")), 8),
    ModeOf = fun(File) ->
                 {ok, #file_info{mode = Mode}} = file:read_file_info(Name(File)),
                 Mode band 8#7777
             end,
    ?assertEqual(8#600 band bnot Mask, ModeOf("private_copy")),
    ?assertEqual(8#755 band bnot Mask, ModeOf("script_copy")),
    ?assertEqual(8#640, ModeOf("kept")),
    ?assertEqual({ok, <<"secret">>}, file:read_file(Name("private_copy"))),
    ?assertEqual({ok, <<"run">>}, file:read_file(Name("kept"))),
    file:del_dir_r(Dir).

%% report Appendix E.17: read, write and copy work on regular files, and
%% append on a regular file and a device; each refuses a named pipe and a
%% directory at once. A regression test: a
%% named pipe's read waited for a writer in the host's file server, which
%% then answered no other request of the node's, the read of a plain file
%% after it among them
fs_named_pipe_test() ->
    Self = self(),
    Dir = scratch("ern_fifo_"),
    ok = filelib:ensure_path(Dir),
    "" = os:cmd("mkfifo " ++ filename:join(Dir, "pipe")),
    ok = file:write_file(filename:join(Dir, "plain"), <<"hi">>),
    InDir = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:read(InDir("pipe"), 1000)},
                           Self ! {fs, Fs:write(InDir("pipe"), <<"x">>, 1000)},
                           Self ! {fs, Fs:append(InDir("pipe"), <<"x">>, 1000)},
                           Self ! {fs, Fs:copy(InDir("pipe"), InDir("copy"), 1000)},
                           Self ! {fs, Fs:copy(InDir("plain"), InDir("pipe"), 1000)},
                           Self ! {fs, Fs:read(InDir("."), 1000)},
                           Self ! {fs, Fs:read(InDir("plain"), 1000)}
                       end, <<"fs_named_pipe_test">>, #{})),
    Refused = {'Left', 'NotAFile'},
    ?assertEqual(lists:duplicate(6, Refused) ++ [{'Right', <<"hi">>}], collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.17: append writes a device, a terminal among them, and
%% read, write and copy refuse one, as append refuses a directory; the
%% device here is the null device, which every host has. A regression test
%% of the change that let the shell's `:output` append through Fs
%% (report §11.2), which covers no terminal, since a test has none
fs_append_device_test() ->
    Self = self(),
    Null = {'Path', <<"/dev/null">>},
    Dir = scratch("ern_device_"),
    ok = filelib:ensure_path(Dir),
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:append(Null, <<"x">>, 1000)},
                           Self ! {fs, Fs:write(Null, <<"x">>, 1000)},
                           Self ! {fs, Fs:read(Null, 1000)},
                           Self ! {fs, Fs:copy(Null, {'Path', <<"/dev/null">>}, 1000)},
                           Self ! {fs, Fs:append({'Path', unicode:characters_to_binary(Dir)},
                                                 <<"x">>, 1000)}
                       end, <<"fs_append_device_test">>, #{})),
    Refused = {'Left', 'NotAFile'},
    ?assertEqual([{'Right', 'Unit'}, Refused, Refused, Refused, Refused], collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.17: `setMode` sets a file's and a directory's
%% permission bits to the mode, a path that names nothing is NotFound, and a
%% mode beyond the bits, or with 0o1000, which the host does not write, is
%% Invalid. A regression test of the rule that replaced `makePrivate` with
%% it, and of 0o1777, which set 0o777 and answered Right(Unit)
fs_set_mode_test() ->
    Self = self(),
    Dir = scratch("ern_private_"),
    ok = filelib:ensure_path(Dir),
    File = filename:join(Dir, "notes"),
    ok = file:write_file(File, <<"x">>),
    ok = file:change_mode(Dir, 8#755),
    ok = file:change_mode(File, 8#664),
    InDir = fun(Name) -> {'Path', unicode:characters_to_binary(Name)} end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, 'ern@fs':setMode(InDir(File), 8#600, 1000)},
                           Self ! {fs, 'ern@fs':setMode(InDir(Dir), 8#700, 1000)},
                           Self ! {fs, 'ern@fs':setMode(InDir(Dir ++ "/none"), 8#700, 1000)},
                           Self ! {fs, 'ern@fs':setMode(InDir(File), 8#10000, 1000)},
                           Self ! {fs, 'ern@fs':setMode(InDir(Dir), 8#1777, 1000)}
                       end, <<"fs_set_mode_test">>, #{})),
    ?assertEqual([{'Right', 'Unit'}, {'Right', 'Unit'}, {'Left', 'NotFound'},
                  {'Left', 'Invalid'}, {'Left', 'Invalid'}], collect(fs, [])),
    {ok, FileInfo} = file:read_file_info(File),
    {ok, DirInfo} = file:read_file_info(Dir),
    ?assertEqual({8#600, 8#700}, {FileInfo#file_info.mode band 8#777,
                                  DirInfo#file_info.mode band 8#777}),
    file:del_dir_r(Dir).

%% report Appendix E.17: a file is created with the permission bits the
%% host's mask leaves of 0o666, by `makeFile`, `write` and `append` alike.
%% Written with the sentence, after the code
fs_created_mode_test() ->
    Self = self(),
    Dir = scratch("ern_mask_"),
    ok = filelib:ensure_path(Dir),
    InDir = fun(Name) -> {'Path', unicode:characters_to_binary(filename:join(Dir, Name))} end,
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, 'ern@fs':makeFile(InDir("made"), <<"x">>, 1000)},
                           Self ! {fs, 'ern@fs':write(InDir("written"), <<"x">>, 1000)},
                           Self ! {fs, 'ern@fs':append(InDir("appended"), <<"x">>, 1000)}
                       end, <<"fs_created_mode_test">>, #{})),
    ?assertEqual([{'Right', 'Unit'}, {'Right', 'Unit'}, {'Right', 'Unit'}], collect(fs, [])),
    Mask = list_to_integer(string:trim(os:cmd("umask")), 8),
    [?assertEqual(8#666 band bnot Mask, Mode band 8#777)
     || Name <- ["made", "written", "appended"],
        {ok, #file_info{mode = Mode}} <- [file:read_file_info(filename:join(Dir, Name))]],
    file:del_dir_r(Dir).

%% report Appendix E.17: `list` describes each entry as it is, a link as
%% the link itself, a link to nothing among them. A regression test: a link
%% to nothing failed the list of the whole directory with NotFound
fs_list_dangling_link_test() ->
    Self = self(),
    Dir = scratch("ern_links_"),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "plain"), <<"four">>),
    ok = file:make_symlink("plain", filename:join(Dir, "to_plain")),
    ok = file:make_symlink("nowhere", filename:join(Dir, "to_nothing")),
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, 'ern@fs':list({'Path', list_to_binary(Dir)}, 1000)}
                       end, <<"fs_list_dangling_link_test">>, #{})),
    [{'Right', Entries}] = collect(fs, []),
    Described = lists:sort([{filename:basename(Name), Kind, Size}
                            || {'Entry', {'Path', Name}, _, Size, Kind, _, _} <- Entries]),
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
    Self = self(),
    Dir = scratch("ern_links_"),
    ok = filelib:ensure_path(filename:join(Dir, "shelf")),
    InDir = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:makeLink(InDir("to_shelf"), {'Path', <<"shelf">>}, 1000)},
                           Self ! {fs, Fs:readLink(InDir("to_shelf"), 1000)},
                           Self ! {fs, Fs:stat(InDir("to_shelf"), 1000)},
                           Self ! {fs, Fs:list({'Path', list_to_binary(Dir)}, 1000)},
                           Self ! {fs, Fs:makeLink(InDir("to_shelf"), InDir("elsewhere"), 1000)},
                           Self ! {fs, Fs:readLink(InDir("shelf"), 1000)},
                           Self ! {fs, Fs:remove(InDir("to_shelf"), 1000)},
                           Self ! {fs, Fs:list({'Path', list_to_binary(Dir)}, 1000)}
                       end, <<"fs_links_test">>, #{})),
    [Made, Read, Stat, Listed, Again, NotLink, Removed, After] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Made),
    ?assertEqual({'Right', {'Some', {'Path', <<"shelf">>}}}, Read),
    ?assertMatch({'Right', {'Entry', _, _, _, 'Directory', _, _}}, Stat),
    {'Right', Entries} = Listed,
    ?assertEqual([{<<"shelf">>, 'Directory'}, {<<"to_shelf">>, 'Link'}],
                 lists:sort([{filename:basename(Path), Kind}
                             || {'Entry', {'Path', Path}, _, _, Kind, _, _} <- Entries])),
    ?assertEqual({'Left', 'Exists'}, Again),
    ?assertEqual({'Right', 'None'}, NotLink),
    ?assertEqual({'Right', 'Unit'}, Removed),
    {'Right', Kept} = After,
    ?assertEqual([<<"shelf">>],
                 [filename:basename(Path) || {'Entry', {'Path', Path}, _, _, _, _, _} <- Kept]),
    file:del_dir_r(Dir).

%% report Appendix E.17: a hard link is a second name for a regular file,
%% which outlives the first; a path that names something is `Exists`, and
%% a target that is a directory, a link or nothing is `NotAFile` or
%% `NotFound`. Written with the code
fs_hard_links_test() ->
    Self = self(),
    Dir = scratch("ern_hard_"),
    ok = filelib:ensure_path(filename:join(Dir, "shelf")),
    ok = file:write_file(filename:join(Dir, "orig"), <<"o">>),
    ok = file:make_symlink("orig", filename:join(Dir, "to_orig")),
    InDir = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:makeHardLink(InDir("twin"), InDir("orig"), 1000)},
                           Self ! {fs, Fs:stat(InDir("twin"), 1000)},
                           Self ! {fs, Fs:makeHardLink(InDir("twin"), InDir("orig"), 1000)},
                           Self ! {fs, Fs:makeHardLink(InDir("dir"), InDir("shelf"), 1000)},
                           Self ! {fs, Fs:makeHardLink(InDir("link"), InDir("to_orig"), 1000)},
                           Self ! {fs, Fs:makeHardLink(InDir("none"), InDir("missing"), 1000)},
                           Self ! {fs, Fs:remove(InDir("orig"), 1000)},
                           Self ! {fs, Fs:read(InDir("twin"), 1000)}
                       end, <<"fs_hard_links_test">>, #{})),
    [Made, Stat, Again, OfDir, OfLink, OfNone, Removed, Read] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Made),
    ?assertMatch({'Right', {'Entry', _, _, 1, 'File', _, _}}, Stat),
    ?assertEqual({'Left', 'Exists'}, Again),
    ?assertEqual({'Left', 'NotAFile'}, OfDir),
    ?assertEqual({'Left', 'NotAFile'}, OfLink),
    ?assertEqual({'Left', 'NotFound'}, OfNone),
    ?assertEqual({'Right', 'Unit'}, Removed),
    ?assertEqual({'Right', <<"o">>}, Read),
    file:del_dir_r(Dir).

%% report Appendix E.17: `readRange` reads a part of a file, fewer bytes at
%% its end and none past it, a regular file only, and an offset or a count
%% below 0 is none (§7.4, a regression test of the rule, before which one
%% was refused in words). Written with the code (MVP 2.98); the counts and
%% the offset past what the host can hold are a regression test, since the
%% host made room for the count first and answered `Other("not enough
%% memory")` or `Other("invalid argument")`
fs_read_range_test() ->
    Self = self(),
    Dir = scratch("ern_range_"),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(filename:join(Dir, "abc.txt"), <<"abcdef">>),
    InDir = {'Path', list_to_binary(filename:join(Dir, "abc.txt"))},
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           [Self ! {fs, Fs:readRange(InDir, Offset, Count, 1000)}
                            || {Offset, Count} <- [{0, 2}, {4, 9}, {6, 1}, {9, 1}, {1, 0}, {-1, 2},
                                                   {1, -1}, {2, 1 bsl 62}, {3, 1 bsl 80},
                                                   {1 bsl 80, 1}]],
                           Self ! {fs, Fs:readRange({'Path', list_to_binary(Dir)}, 0, 1, 1000)}
                       end, <<"fs_read_range_test">>, #{})),
    ?assertEqual([{'Right', <<"ab">>}, {'Right', <<"ef">>}, {'Right', <<>>}, {'Right', <<>>},
                  {'Right', <<>>}, {'Right', <<"ab">>}, {'Right', <<>>},
                  {'Right', <<"cdef">>}, {'Right', <<"def">>}, {'Right', <<>>},
                  {'Left', 'NotAFile'}],
                 collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.17: `makeFile` makes a new file or none; `setModified`
%% sets the time a `stat` then reads, to the second. Written with the code
%% (MVP 2.98); a write that fails after the file is made is not covered,
%% since a test cannot make one fail there
fs_create_modified_test() ->
    Self = self(),
    Dir = scratch("ern_fs3_"),
    ok = filelib:ensure_path(Dir),
    InDir = fun(Name) -> {'Path', list_to_binary(filename:join(Dir, Name))} end,
    Fs = 'ern@fs',
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Self ! {fs, Fs:makeFile(InDir("new.txt"), <<"a">>, 1000)},
                           Self ! {fs, Fs:makeFile(InDir("new.txt"), <<"b">>, 1000)},
                           Self ! {fs, Fs:read(InDir("new.txt"), 1000)},
                           Self ! {fs, Fs:setModified(InDir("new.txt"), 86400999, 1000)},
                           Self ! {fs, Fs:stat(InDir("new.txt"), 1000)}
                       end, <<"fs_create_modified_test">>, #{})),
    [Made, Taken, Kept, Set, Stat] = collect(fs, []),
    ?assertEqual({'Right', 'Unit'}, Made),
    ?assertEqual({'Left', 'Exists'}, Taken),
    ?assertEqual({'Right', <<"a">>}, Kept),
    ?assertEqual({'Right', 'Unit'}, Set),
    ?assertMatch({'Right', {'Entry', _, 86400000, 1, 'File', _, _}}, Stat),
    file:del_dir_r(Dir).

%% report Appendix E.17, E.1: `setModified` with a time the host cannot
%% hold answers Invalid, an argument the host cannot take. A regression
%% test: it answered Other("bad argument")
fs_set_modified_past_the_host_test() ->
    Self = self(),
    Dir = scratch("ern_fs6_"),
    File = filename:join(Dir, "f"),
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(File, <<>>),
    ?assertEqual(ok, ern_rt:run_main(
                       fun() ->
                           Path = {'Path', list_to_binary(File)},
                           Self ! {fs, 'ern@fs':setModified(Path, 1 bsl 80, 1000)},
                           Self ! {fs, 'ern@fs':setModified(Path, -(1 bsl 80), 1000)}
                       end, <<"fs_set_modified_past_the_host_test">>, #{})),
    ?assertEqual([{'Left', 'Invalid'}, {'Left', 'Invalid'}], collect(fs, [])),
    file:del_dir_r(Dir).

%% report Appendix E.18, §8.2: a listener and a socket are processes, a
%% write arrives at the peer's read, and a closed socket answers Left(Closed)
tcp_test() ->
    Self = self(),
    Tcp = 'ern@tcp',
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Listener} = Tcp:listen(<<"127.0.0.1">>, 0),
                   {'Right', Port} = Tcp:port(Listener),
                   {'Right', Client} = Tcp:connect(<<"127.0.0.1">>, Port, 1000),
                   {'Right', Server} = Tcp:accept(Listener, 1000),
                   Tcp:write(Client, <<"ping">>, 5000),
                   Self ! {tcp, Tcp:read(Server, 1000)},
                   Tcp:write(Server, <<"pong">>, 5000),
                   Self ! {tcp, Tcp:read(Client, 1000)},
                   Tcp:close(Client),
                   Self ! {tcp, Tcp:read(Server, 1000)}
               end, <<"tcp_test">>, #{}),
    ?assertEqual(ok, Result),
    ?assertEqual([{'Right', <<"ping">>}, {'Right', <<"pong">>}, {'Left', 'Closed'}],
                 collect(tcp, [])).

%% report §8.6, Appendix E.18: a listener ends with the program, so the
%% port is free for the next. A regression test: listeners and sockets
%% were started outside the runtime's reach and outlived their program,
%% and a second program listening on the port was refused `eaddrinuse`.
%% The first listens on a port the host chooses, which the second asks for.
tcp_ends_with_program_test() ->
    Self = self(),
    Tcp = 'ern@tcp',
    First = fun() ->
                {'Right', Listener} = Tcp:listen(<<"127.0.0.1">>, 0),
                Self ! {listened, Tcp:port(Listener)}
            end,
    ?assertEqual(ok, ern_rt:run_main(First, <<"first">>, #{})),
    [{'Right', Port}] = collect(listened, []),
    Second = fun() ->
                 {Side, _} = Tcp:listen(<<"127.0.0.1">>, Port),
                 Self ! {listened, Side}
             end,
    ?assertEqual(ok, ern_rt:run_main(Second, <<"second">>, #{})),
    ?assertEqual(['Right'], collect(listened, [])).

%% report Appendix E.12, §3.8, §8.4
foreign_test() ->
    Foreign = 'ern@foreign',
    ?assertEqual(42, Foreign:from(42)),
    ?assertEqual({'Some', 0.0}, Foreign:toFloat(-0.0)),
    ?assertEqual({'Some', 3}, Foreign:toInt(3)),
    ?assertEqual('None', Foreign:toInt(3.0)),
    ?assertEqual({'Some', 1.5}, Foreign:toFloat(1.5)),
    ?assertEqual('None', Foreign:toFloat(1)),
    ?assertEqual({'Some', <<"s">>}, Foreign:toString(<<"s">>)),
    ?assertEqual('None', Foreign:toString(<<255>>)),
    ?assertEqual('None', Foreign:toString("s")),
    ?assertEqual({'Some', true}, Foreign:toBool(true)),
    ?assertEqual('None', Foreign:toBool(1)),
    ?assertEqual({'Some', [1, x]}, Foreign:toList([1, x])),
    ?assertEqual('None', Foreign:toList(<<>>)),
    %% an improper list is no List; a regression test, it was answered as one
    ?assertEqual('None', Foreign:toList([1 | x])).

%% report Appendix E.9: the shortest digits, plain from 0.0001 to below
%% 1.0e16 and with an exponent beyond, its sign only when negative, each
%% reading back as the same value. A regression test: 1.0e15 was written with
%% an exponent, as the host writes it.
float_to_string_test() ->
    Float = 'ern@float',
    String = 'ern@string',
    Cases = [{1.0e15, <<"1000000000000000.0">>},
             {9.999999999999998e15, <<"9999999999999998.0">>},
             {1.0e16, <<"1.0e16">>}, {1.0e-5, <<"1.0e-5">>}, {0.0001, <<"0.0001">>},
             {1.5e-7, <<"1.5e-7">>}, {123.0, <<"123.0">>}, {0.1, <<"0.1">>},
             {1.2345e20, <<"1.2345e20">>}, {0.0, <<"0.0">>}, {-2.5, <<"-2.5">>},
             {-1.0e-9, <<"-1.0e-9">>}, {12.5, <<"12.5">>}],
    [?assertEqual({Number, Text}, {Number, Float:toString(Number)}) || {Number, Text} <- Cases],
    [?assertEqual({'Some', Number}, String:toFloat(Float:toString(Number)))
     || {Number, _} <- Cases].

%% report Appendix E.13: the same seed gives the same sequence, every draw
%% is within the bounds on either side of zero, and the seed moves
random_test() ->
    Random = 'ern@random',
    Draw = fun Draw(_, _, 0) -> [];
               Draw(Seed, Bound, Count) ->
                   {Drawn, Seed1} = Random:next(Seed, Bound),
                   [Drawn | Draw(Seed1, Bound, Count - 1)]
           end,
    Draws = Draw(Random:seed(42), 5, 200),
    ?assertEqual(Draws, Draw(Random:seed(42), 5, 200)),
    ?assert(lists:all(fun(Drawn) -> Drawn >= 0 andalso Drawn =< 5 end, Draws)),
    ?assertEqual([0, 1, 2, 3, 4, 5], lists:usort(Draws)),
    NegativeDraws = Draw(Random:seed(42), -3, 200),
    ?assertEqual([-3, -2, -1, 0], lists:usort(NegativeDraws)),
    ?assertEqual([0, 0], Draw(Random:seed(1), 0, 2)),
    {_, Seed1} = Random:next(Random:seed(7), 1),
    ?assertNotEqual(Random:seed(7), Seed1).

%% report Appendix E.13: the generator is SplitMix64, so a seed's draws are
%% the reference sequence: from 0, a draw over the whole 64-bit range is the
%% reference output itself, and a seed names its number's low 64 bits. A
%% regression test, written with the move from the host's `exsss`, whose
%% sequence no report could promise.
random_splitmix64_test() ->
    Random = 'ern@random',
    Whole = 16#FFFF_FFFF_FFFF_FFFF,
    {First, Seed1} = Random:next(Random:seed(0), Whole),
    {Second, Seed2} = Random:next(Seed1, Whole),
    {Third, _} = Random:next(Seed2, Whole),
    ?assertEqual([16#E220A8397B1DCDAF, 16#6E789E6AA1B965F4, 16#06C45D188009454F],
                 [First, Second, Third]),
    ?assertEqual(Random:seed(5), Random:seed(5 + (1 bsl 64))),
    {Fraction, _} = Random:nextFloat(Random:seed(0)),
    ?assertEqual((float(16#E220A8397B1DCDAF bsr 12) + 0.5) / 4503599627370496.0, Fraction),
    %% a bound beyond 64 bits draws from as many words as it needs
    {Big, _} = Random:next(Random:seed(1), 1 bsl 100),
    ?assert(Big >= 0 andalso Big =< 1 bsl 100).

%% report Appendix E.14: Path's edge cases, now that it is Ernest over String
%% and two primitives: a trailing separator, an absolute second operand, the
%% root alone, a name with an empty extension, and a dot file. Written with
%% the move, where `filename` had answered them.
path_edges_test() ->
    Path = 'ern@path',
    AsPath = fun(Text) -> {'Path', Text} end,
    ?assertEqual({'Some', <<"b">>}, Path:name(AsPath(<<"a/b/">>))),
    ?assertEqual([<<"a">>, <<"b">>], Path:split(AsPath(<<"a//b/">>))),
    ?assertEqual({'Some', AsPath(<<"a">>)}, Path:parent(AsPath(<<"a/b/">>))),
    ?assertEqual(AsPath(<<"/var">>), Path:'<>'(AsPath(<<"/etc">>), AsPath(<<"/var">>))),
    ?assertEqual(AsPath(<<"/etc/hosts">>), Path:'<>'(AsPath(<<"/etc/">>), AsPath(<<"hosts">>))),
    ?assertEqual(AsPath(<<"b">>), Path:'<>'(AsPath(<<"">>), AsPath(<<"b">>))),
    ?assertEqual([<<"/">>], Path:split(AsPath(<<"/">>))),
    %% report Appendix E.14: the root has no name, a regression test of the
    %% rule, before which it was ""
    ?assertEqual('None', Path:name(AsPath(<<"/">>))),
    ?assertEqual({'Some', <<>>}, Path:extension(AsPath(<<"a.">>))),
    ?assertEqual('None', Path:extension(AsPath(<<"a.d/b">>))),
    ?assertEqual(AsPath(<<"a/b/">>), Path:withoutExtension(AsPath(<<"a/b.txt/">>))),
    %% report Appendix E.14: an empty extension leaves the dot, and removing
    %% one is withoutExtension's
    ?assertEqual(AsPath(<<"a/b.">>), Path:withExtension(AsPath(<<"a/b.txt">>), <<>>)),
    ?assertEqual(AsPath(<<"a.d/b.md">>), Path:withExtension(AsPath(<<"a.d/b">>), <<"md">>)),
    %% a dot that begins a name begins no extension, and the root has no name
    %% to extend; a regression test, `.bashrc`'s extension was `bashrc`, so
    %% removing it left an empty path
    ?assertEqual('None', Path:extension(AsPath(<<".profile">>))),
    %% report Appendix E.14: an empty path, a `.` between separators and a
    %% trailing separator under a root, which the laws do not draw, the last
    %% joined as `<>` joins it; written with `under`
    ?assertEqual('None', Path:under(AsPath(<<"/srv">>), AsPath(<<"">>))),
    ?assertEqual('None', Path:under(AsPath(<<"/srv">>), AsPath(<<"a/./b">>))),
    ?assertEqual({'Some', AsPath(<<"/srv/a">>)}, Path:under(AsPath(<<"/srv">>), AsPath(<<"a/">>))),
    ?assertEqual({'Some', <<"bak">>}, Path:extension(AsPath(<<".profile.bak">>))),
    ?assertEqual(AsPath(<<".bashrc">>), Path:withoutExtension(AsPath(<<".bashrc">>))),
    ?assertEqual(AsPath(<<"dir/.bashrc.txt">>),
                 Path:withExtension(AsPath(<<"dir/.bashrc">>), <<"txt">>)),
    ?assertEqual(AsPath(<<"/">>), Path:withExtension(AsPath(<<"/">>), <<"txt">>)),
    %% the dots that begin a name begin no extension, `..` is left as it is,
    %% and the rest of a path stays as written; a regression test, `..` had
    %% the extension "", which removing turned into `.`, and a doubled
    %% separator was made one
    ?assertEqual('None', Path:extension(AsPath(<<"..">>))),
    ?assertEqual('None', Path:extension(AsPath(<<"...">>))),
    ?assertEqual({'Some', <<"b">>}, Path:extension(AsPath(<<"..a.b">>))),
    ?assertEqual(AsPath(<<"a/..">>), Path:withoutExtension(AsPath(<<"a/..">>))),
    ?assertEqual(AsPath(<<"a/..">>), Path:withExtension(AsPath(<<"a/..">>), <<"md">>)),
    ?assertEqual(AsPath(<<"a//b.md">>), Path:withExtension(AsPath(<<"a//b.txt">>), <<"md">>)),
    ?assertEqual(AsPath(<<"a/b/c">>), Path:'<>'(AsPath(<<"a//b">>), AsPath(<<"c">>))).

%% report Appendix E.16, E.5: columns counts by grapheme, by its first code
%% point that counts: a combining mark adds none, alone it takes none; an
%% emoji sequence joined by ZWJ and a flag are one wide grapheme; a
%% pictograph is wide only with U+FE0F; a fullwidth letter is wide; a tab
%% and an escape sequence take none. Written with the code
columns_test() ->
    Terminal = 'ern@terminal',
    Columns = fun(Chars) -> Terminal:columns(unicode:characters_to_binary(Chars)) end,
    ?assertEqual(1, Columns([$e, 16#301])),
    ?assertEqual(0, Columns([16#301])),
    ?assertEqual(2, Columns([16#1F468, 16#200D, 16#1F469, 16#200D, 16#1F467])),
    ?assertEqual(2, Columns([16#1F1F8, 16#1F1EA])),
    ?assertEqual(1, Columns([16#2764])),
    ?assertEqual(2, Columns([16#2764, 16#FE0F])),
    ?assertEqual(2, Columns([16#FF21])),
    ?assertEqual(0, Columns("\t")),
    ?assertEqual(2, Columns("\e[1;31mab\e[0m")),
    ?assertEqual(1, Columns("\e7a")),
    ?assertEqual([<<"a">>, <<"e", 16#301/utf8>>], ern_string:graphemes(<<"ae", 16#301/utf8>>)).

%% report Appendix E.14, §9.3
path_test() ->
    Path = 'ern@path',
    ?assertEqual({'Path', <<"a/b">>}, Path:'<>'({'Path', <<"a">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"a/b">>}, Path:'<>'({'Path', <<"a/">>}, {'Path', <<"b">>})),
    ?assertEqual({'Path', <<"/b">>}, Path:'<>'({'Path', <<"a">>}, {'Path', <<"/b">>})),
    %% report Appendix E.14: join is split's inverse, a root first staying
    %% one; a regression test of the rule, before which join took two paths,
    %% which `<>` now does
    ?assertEqual({'Path', <<"/etc/hosts">>}, Path:join([<<"/">>, <<"etc">>, <<"hosts">>])),
    ?assertEqual({'Path', <<"a/b">>}, Path:join(Path:split({'Path', <<"a//b/">>}))),
    ?assertEqual({'Path', <<>>}, Path:join([])),
    ?assertEqual([<<"/">>, <<"a">>, <<"b">>], Path:split({'Path', <<"/a/b">>})),
    ?assertEqual([<<"a">>, <<"b">>], Path:split({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"a">>}}, Path:parent({'Path', <<"a/b">>})),
    ?assertEqual({'Some', {'Path', <<"/">>}}, Path:parent({'Path', <<"/a">>})),
    ?assertEqual('None', Path:parent({'Path', <<"a">>})),
    ?assertEqual('None', Path:parent({'Path', <<"/">>})),
    ?assertEqual({'Some', <<"b.txt">>}, Path:name({'Path', <<"a/b.txt">>})),
    ?assertEqual({'Some', <<"txt">>}, Path:extension({'Path', <<"a/b.txt">>})),
    ?assertEqual('None', Path:extension({'Path', <<"a/b">>})),
    ?assertEqual({'Path', <<"a/b.md">>}, Path:withExtension({'Path', <<"a/b.txt">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b.md">>}, Path:withExtension({'Path', <<"a/b">>}, <<"md">>)),
    ?assertEqual({'Path', <<"a/b">>}, Path:withoutExtension({'Path', <<"a/b.txt">>})),
    ?assertEqual(true, Path:isAbsolute({'Path', <<"/a">>})),
    ?assertEqual(false, Path:isAbsolute({'Path', <<"a">>})),
    ?assertEqual(<<"a">>, Path:toString({'Path', <<"a">>})).

%% report §7.4: `fault(c)` faults with the cause
fault_test() ->
    ?assertThrow({ern, fault, <<"x">>}, ern_rt:fault(<<"x">>)).

%% A directory of the test's own under /tmp, named for it and not yet made.
scratch(Prefix) ->
    filename:join("/tmp", Prefix ++ os:getpid() ++ "_"
                          ++ integer_to_list(erlang:unique_integer([positive]))).

%% report Appendix E.25, §4.9: the ordered set, a sorted list, each function
%% that needs the order taking it after the arguments the program writes, as
%% the compiler supplies it; `put` and `fromList` keep the element already
%% there; written after the code
ordered_set_test() ->
    Set = 'ern@ordered_set',
    Compare = fun 'ern@int':compare/2,
    Small = Set:fromList([3, 1, 3], Compare),
    ?assertEqual([1, 3], Set:toList(Small)),
    ?assertEqual({2, false, true}, {Set:size(Small), Set:isEmpty(Small), Set:isEmpty(Set:empty())}),
    ?assertEqual({true, false}, {Set:contains(Small, 3, Compare), Set:contains(Small, 2, Compare)}),
    ?assertEqual([1, 2, 3], Set:toList(Set:put(Small, 2, Compare))),
    ?assertEqual([3], Set:toList(Set:remove(Small, 1, Compare))),
    ?assertEqual([1, 3], Set:toList(Set:remove(Small, 2, Compare))),
    Other = Set:fromList([2, 3], Compare),
    ?assertEqual([1, 2, 3], Set:toList(Set:union(Small, Other, Compare))),
    ?assertEqual([3], Set:toList(Set:intersection(Small, Other, Compare))),
    ?assertEqual([1], Set:toList(Set:difference(Small, Other, Compare))),
    ?assertEqual({true, false}, {Set:isSubset(Set:fromList([3], Compare), Small, Compare),
                                 Set:isSubset(Other, Small, Compare)}),
    ?assertEqual({{'Some', 1}, {'Some', 3}, 'None'}, {Set:min(Small), Set:max(Small),
                                                      Set:min(Set:empty())}),
    %% map and filterMap take the result's order
    ?assertEqual([0, 1], Set:toList(Set:map(Small, fun(X) -> X div 2 end, Compare))),
    Tens = fun(1) -> 'None'; (X) -> {'Some', X * 10} end,
    ?assertEqual([30], Set:toList(Set:filterMap(Small, Tens, Compare))),
    ?assertEqual([3], Set:toList(Set:filter(Small, fun(X) -> X > 1 end))),
    ?assertEqual(4, Set:foldLeft(Small, 0, fun(Acc, X) -> Acc + X end)),
    ?assertEqual({true, false, {'Some', 3}},
                 {Set:any(Small, fun(X) -> X > 2 end), Set:all(Small, fun(X) -> X > 2 end),
                  Set:find(Small, fun(X) -> X > 1 end)}),
    %% two elements the order calls Equal are one, the first kept
    ByKey = fun({Key, _}, {Other1, _}) -> 'ern@int':compare(Key, Other1) end,
    Kept = Set:fromList([{1, first}, {1, second}], ByKey),
    ?assertEqual([{1, first}], Set:toList(Kept)),
    ?assertEqual([{1, first}], Set:toList(Set:put(Kept, {1, third}, ByKey))).

%% report Appendix E.26, §4.9: the ordered map, a sorted list of pairs, each
%% function that needs the keys' order taking it after the arguments the
%% program writes; `put` and `fromList` keep the later value; written after
%% the code
ordered_map_test() ->
    Map = 'ern@ordered_map',
    Compare = fun 'ern@int':compare/2,
    Ages = Map:fromList([{2, b}, {1, a}, {2, c}], Compare),
    ?assertEqual([{1, a}, {2, c}], Map:toList(Ages)),
    ?assertEqual({[1, 2], [a, c]}, {Map:keys(Ages), Map:values(Ages)}),
    ?assertEqual({2, false, true}, {Map:size(Ages), Map:isEmpty(Ages), Map:isEmpty(Map:empty())}),
    ?assertEqual({{'Some', a}, 'None'}, {Map:get(Ages, 1, Compare), Map:get(Ages, 3, Compare)}),
    ?assertEqual({true, false}, {Map:contains(Ages, 2, Compare), Map:contains(Ages, 3, Compare)}),
    ?assertEqual([{1, z}, {2, c}], Map:toList(Map:put(Ages, 1, z, Compare))),
    ?assertEqual([{2, c}], Map:toList(Map:remove(Ages, 1, Compare))),
    Counted = Map:update(Map:empty(), 7, fun('None') -> 1; ({'Some', N}) -> N + 1 end, Compare),
    ?assertEqual([{7, 1}], Map:toList(Counted)),
    ?assertEqual([{1, b}, {3, d}],
                 Map:toList(Map:merge(Map:fromList([{1, a}], Compare),
                                      Map:fromList([{1, b}, {3, d}], Compare), Compare))),
    ?assertEqual([{1, 3}],
                 Map:toList(Map:mergeWith(Map:fromList([{1, 1}], Compare),
                                          Map:fromList([{1, 2}], Compare),
                                          fun(_, Mine, Theirs) -> Mine + Theirs end, Compare))),
    ?assertEqual([{1, 1}, {2, 2}],
                 Map:toList(Map:map(Ages, fun(Key, _) -> Key end))),
    ?assertEqual([{2, c}], Map:toList(Map:filter(Ages, fun(Key, _) -> Key > 1 end))),
    ?assertEqual(3, Map:foldLeft(Ages, 0, fun(Acc, Key, _) -> Acc + Key end)),
    ?assertEqual({'Some', {2, c}}, Map:find(Ages, fun(Key, _) -> Key > 1 end)).
