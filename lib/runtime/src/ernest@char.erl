%% Appendix E.6 and Char.compare of report §9.6, namespace Char, as an Erlang
%% module for MVP 1. A Char is a code point (report §8.4). The predicates use
%% the Unicode properties Appendix E.6 names, through the property classes of
%% the re module: isDigit is general category Nd, isAlpha is category L,
%% isSpace is White_Space, which is the Z categories together with U+0009 to
%% U+000D and U+0085. ASCII is decided without the regular expression.
-module('ernest@char').

-export([isDigit/1, isAlpha/1, isSpace/1, toString/1, toInt/1, fromInt/1, compare/2]).

isDigit(C) when C < 16#80 -> C >= $0 andalso C =< $9;
isDigit(C) -> category(C, "Nd").
isAlpha(C) when C < 16#80 -> (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z);
isAlpha(C) -> category(C, "L").
isSpace(C) when C < 16#80 -> (C >= 16#9 andalso C =< 16#D) orelse C =:= $\s;
isSpace(C) -> C =:= 16#85 orelse category(C, "Z").
toString(C) -> unicode:characters_to_binary([C]).
toInt(C) -> C.
fromInt(N) when N >= 0, N =< 16#10FFFF, not (N >= 16#D800 andalso N =< 16#DFFF) -> {'Some', N};
fromInt(_) -> 'None'.
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.

category(C, Class) ->
    re:run(<<C/utf8>>, "^\\p{" ++ Class ++ "}$", [unicode]) =/= nomatch.
