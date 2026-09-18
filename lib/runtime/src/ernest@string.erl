%% Appendix E.5 and the String operations of report §9.6 that are not
%% emitted inline, namespace String, as an Erlang module for MVP 1. A String
%% is a UTF-8 binary (report §8.4). The contracts are Appendix E.5's: trim
%% strips Unicode whitespace; split keeps empty parts between adjacent
%% separators and at the ends; lines adds no empty line for a final line
%% feed; toInt takes the digits 0 to 9 with an optional leading minus;
%% toFloat takes the float literal form of report §2.5 the same way and
%% answers None outside the finite range. Character operations go through
%% toList (Appendix E.5).
-module('ernest@string').

-export([size/1, isEmpty/1, contains/2, startsWith/2, endsWith/2, replace/3, slice/3,
         padStart/3, padEnd/3, repeat/2, trim/1, toLower/1, toUpper/1, toInt/1, toFloat/1,
         toList/1, fromList/1, fromUtf8/1, toUtf8/1, lines/1, split/2, join/2, compare/2]).

size(S) -> string:length(S).
isEmpty(S) -> S =:= <<>>.
contains(S, Sub) -> string:find(S, Sub) =/= nomatch.
startsWith(S, Prefix) -> string:prefix(S, Prefix) =/= nomatch.
endsWith(S, Suffix) ->
    Size = byte_size(S),
    SSize = byte_size(Suffix),
    Size >= SSize andalso binary:part(S, Size - SSize, SSize) =:= Suffix.
replace(S, <<>>, _) -> S;
replace(S, From, To) -> unicode:characters_to_binary(string:replace(S, From, To, all)).
slice(S, From, Count) ->
    unicode:characters_to_binary(string:slice(S, max(From, 0), max(Count, 0))).
padStart(S, N, C) -> <<(padding(S, N, C))/binary, S/binary>>.
padEnd(S, N, C) -> <<S/binary, (padding(S, N, C))/binary>>.
repeat(S, N) -> binary:copy(S, max(N, 0)).

padding(S, N, C) ->
    unicode:characters_to_binary(lists:duplicate(max(N - string:length(S), 0), C)).
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

toFloat(S) ->
    case re:run(S, "^-?[0-9]+\\.[0-9]+([eE][+-]?[0-9]+)?$") of
        nomatch -> 'None';
        _ ->
            try {'Some', binary_to_float(S)}
            catch error:badarg -> 'None'
            end
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
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.
