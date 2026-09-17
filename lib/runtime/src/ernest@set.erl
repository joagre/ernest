%% Appendix E.4, namespace Set, as an Erlang module for MVP 1: a version 2
%% sets:set, which is a map, so equality on sets is structural and element
%% order is unspecified.
-module('ernest@set').

-export([empty/0, size/1, isEmpty/1, contains/2, add/2, remove/2, union/2, intersect/2,
         difference/2, fromList/1, toList/1]).

empty() -> sets:new([{version, 2}]).
size(S) -> sets:size(S).
isEmpty(S) -> sets:is_empty(S).
contains(S, X) -> sets:is_element(X, S).
add(S, X) -> sets:add_element(X, S).
remove(S, X) -> sets:del_element(X, S).
union(A, B) -> sets:union(A, B).
intersect(A, B) -> sets:intersection(A, B).
difference(A, B) -> sets:subtract(A, B).
fromList(Xs) -> sets:from_list(Xs, [{version, 2}]).
toList(S) -> sets:to_list(S).
