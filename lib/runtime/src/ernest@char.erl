%% Appendix E.6 and Char.compare of report §9.6, namespace Char, as an Erlang
%% module for MVP 1. A Char is a code point (report §8.4). Where Appendix E
%% leaves the definition open, this module chooses ASCII: isDigit is 0-9,
%% isAlpha is A-Z and a-z, isSpace is space, tab, newline, carriage return,
%% form feed, and vertical tab.
-module('ernest@char').

-export([isDigit/1, isAlpha/1, isSpace/1, toString/1, toInt/1, compare/2]).

isDigit(C) -> C >= $0 andalso C =< $9.
isAlpha(C) -> (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z).
isSpace(C) -> lists:member(C, [$\s, $\t, $\n, $\r, $\f, $\v]).
toString(C) -> unicode:characters_to_binary([C]).
toInt(C) -> C.
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.
