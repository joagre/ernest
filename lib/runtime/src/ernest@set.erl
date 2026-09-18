%% Appendix E.4, namespace Set, as an Erlang module for MVP 1: a version 2
%% sets:set, which is a map, so equality on sets is structural and element
%% order is unspecified.
-module('ernest@set').

-export([empty/0, size/1, isEmpty/1, contains/2, put/2, remove/2, union/2, intersect/2,
         difference/2, isSubset/2, fromList/1, toList/1, map/2, filter/2, filterMap/2, foldLeft/3,
         foreach/2, any/2, all/2, find/2]).

empty() -> sets:new([{version, 2}]).
size(S) -> sets:size(S).
isEmpty(S) -> sets:is_empty(S).
contains(S, X) -> sets:is_element(X, S).
put(S, X) -> sets:add_element(X, S).
remove(S, X) -> sets:del_element(X, S).
union(A, B) -> sets:union(A, B).
intersect(A, B) -> sets:intersection(A, B).
difference(A, B) -> sets:subtract(A, B).
isSubset(A, B) -> sets:is_subset(A, B).
fromList(Xs) -> sets:from_list(Xs, [{version, 2}]).
toList(S) -> sets:to_list(S).
map(S, F) -> sets:from_list([F(X) || X <- sets:to_list(S)], [{version, 2}]).
filter(S, P) -> sets:filter(P, S).
filterMap(S, F) ->
    fromList(lists:filtermap(fun(X) ->
                                 case F(X) of
                                     {'Some', Y} -> {true, Y};
                                     'None' -> false
                                 end
                             end, sets:to_list(S))).
foreach(S, F) -> lists:foreach(F, sets:to_list(S)), 'Unit'.
foldLeft(S, Acc, F) -> sets:fold(fun(X, A) -> F(A, X) end, Acc, S).
any(S, P) -> lists:any(P, sets:to_list(S)).
all(S, P) -> lists:all(P, sets:to_list(S)).
find(S, P) ->
    case lists:search(P, sets:to_list(S)) of
        {value, X} -> {'Some', X};
        false -> 'None'
    end.
