%% Appendix E.5 and the String operations of report §9.6 that are not
%% emitted inline, namespace String, as an Erlang module for MVP 1. A String
%% is a UTF-8 binary (report §8.4). Where Appendix E leaves the definition
%% open, this module chooses: trim strips Unicode whitespace; split keeps empty parts
%% between adjacent separators and at the ends; lines splits on
%% "\n" and a trailing newline ends the last line rather than adding an empty
%% one; toInt accepts an optional leading minus and decimal digits only.
-module('ernest@string').

-export([size/1, isEmpty/1, contains/2, trim/1, toLower/1, toUpper/1, toInt/1, toList/1,
         fromList/1, fromUtf8/1, toUtf8/1, lines/1, split/2, join/2, any/2, all/2, compare/2]).

size(S) -> string:length(S).
isEmpty(S) -> S =:= <<>>.
contains(S, Sub) -> string:find(S, Sub) =/= nomatch.
trim(S) -> unicode:characters_to_binary(string:trim(S)).
toLower(S) -> unicode:characters_to_binary(string:lowercase(S)).
toInt(S) ->
    case S of
        <<$-, Digits/binary>> when Digits =/= <<>> -> negate(digits(Digits));
        _ -> digits(S)
    end.

negate({'Some', N}) -> {'Some', -N};
negate('None') -> 'None'.

digits(<<>>) -> 'None';
digits(Bin) ->
    case lists:all(fun(C) -> C >= $0 andalso C =< $9 end, binary_to_list(Bin)) of
        true -> {'Some', binary_to_integer(Bin)};
        false -> 'None'
    end.

toUpper(S) -> unicode:characters_to_binary(string:uppercase(S)).
toList(S) -> unicode:characters_to_list(S).
fromList(Cs) -> unicode:characters_to_binary(Cs).
fromUtf8(B) ->
    case unicode:characters_to_binary(B, utf8, utf8) of
        S when is_binary(S) -> {'Some', S};
        _ -> 'None'
    end.
toUtf8(S) -> S.
lines(<<>>) -> [];
lines(S) ->
    Parts = binary:split(S, <<"\n">>, [global]),
    case lists:last(Parts) of
        <<>> -> lists:droplast(Parts);
        _ -> Parts
    end.
split(S, Sep) -> binary:split(S, Sep, [global]).
join(Parts, Sep) -> iolist_to_binary(lists:join(Sep, Parts)).
any(S, P) -> lists:any(P, unicode:characters_to_list(S)).
all(S, P) -> lists:all(P, unicode:characters_to_list(S)).
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.
