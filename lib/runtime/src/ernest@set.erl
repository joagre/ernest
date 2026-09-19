%% Appendix E.4, namespace Set, as an Erlang module for MVP 1: a version 2
%% sets:set, which is a map, inside the tuple {set, Map}, so that a Set is
%% told apart from a Map at runtime (Io.debug, E.1); equality on sets is
%% structural and element order is unspecified.
-module('ernest@set').

-export([empty/0, size/1, isEmpty/1, contains/2, put/2, remove/2, union/2, intersect/2,
         difference/2, isSubset/2, fromList/1, toList/1, map/2, filter/2, filterMap/2, foldLeft/3,
         foreach/2, any/2, all/2, find/2]).

empty() -> wrap(sets:new([{version, 2}])).
size({set, S}) -> sets:size(S).
isEmpty({set, S}) -> sets:is_empty(S).
contains({set, S}, X) -> sets:is_element(X, S).
put({set, S}, X) -> wrap(sets:add_element(X, S)).
remove({set, S}, X) -> wrap(sets:del_element(X, S)).
union({set, A}, {set, B}) -> wrap(sets:union(A, B)).
intersect({set, A}, {set, B}) -> wrap(sets:intersection(A, B)).
difference({set, A}, {set, B}) -> wrap(sets:subtract(A, B)).
isSubset({set, A}, {set, B}) -> sets:is_subset(A, B).
fromList(Xs) -> wrap(sets:from_list(Xs, [{version, 2}])).
toList({set, S}) -> sets:to_list(S).
map({set, S}, F) -> fromList([F(X) || X <- sets:to_list(S)]).
filter({set, S}, P) -> wrap(sets:filter(P, S)).
filterMap({set, S}, F) ->
    fromList(lists:filtermap(fun(X) ->
                                 case F(X) of
                                     {'Some', Y} -> {true, Y};
                                     'None' -> false
                                 end
                             end, sets:to_list(S))).
foreach({set, S}, F) -> lists:foreach(F, sets:to_list(S)), 'Unit'.
foldLeft({set, S}, Acc, F) -> sets:fold(fun(X, A) -> F(A, X) end, Acc, S).
any({set, S}, P) -> lists:any(P, sets:to_list(S)).
all({set, S}, P) -> lists:all(P, sets:to_list(S)).
find({set, S}, P) ->
    case lists:search(P, sets:to_list(S)) of
        {value, X} -> {'Some', X};
        false -> 'None'
    end.

wrap(S) -> {set, S}.
