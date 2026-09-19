%% The shims behind Set (report Appendix E.4, rule 1): Erlang's version 2
%% sets, a map underneath, tagged {set, S} so that a Set and a Map are told
%% apart at runtime (report §8.4).
-module(ern_set).

-export([empty/0, size/1, contains/2, put/2, remove/2, union/2, intersect/2, difference/2,
         is_subset/2, from_list/1, to_list/1, filter/2, fold/3, foreach/2]).

-spec empty() -> {set, sets:set()}.
empty() -> wrap(sets:new([{version, 2}])).

-spec size({set, sets:set()}) -> non_neg_integer().
size({set, S}) -> sets:size(S).

-spec contains({set, sets:set()}, term()) -> boolean().
contains({set, S}, X) -> sets:is_element(X, S).

-spec put({set, sets:set()}, term()) -> {set, sets:set()}.
put({set, S}, X) -> wrap(sets:add_element(X, S)).

-spec remove({set, sets:set()}, term()) -> {set, sets:set()}.
remove({set, S}, X) -> wrap(sets:del_element(X, S)).

-spec union({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
union({set, A}, {set, B}) -> wrap(sets:union(A, B)).

-spec intersect({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
intersect({set, A}, {set, B}) -> wrap(sets:intersection(A, B)).

-spec difference({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
difference({set, A}, {set, B}) -> wrap(sets:subtract(A, B)).

-spec is_subset({set, sets:set()}, {set, sets:set()}) -> boolean().
is_subset({set, A}, {set, B}) -> sets:is_subset(A, B).

-spec from_list([term()]) -> {set, sets:set()}.
from_list(Xs) -> wrap(sets:from_list(Xs, [{version, 2}])).

-spec to_list({set, sets:set()}) -> [term()].
to_list({set, S}) -> sets:to_list(S).

-spec filter({set, sets:set()}, fun((term()) -> boolean())) -> {set, sets:set()}.
filter({set, S}, P) -> wrap(sets:filter(P, S)).

-spec fold({set, sets:set()}, term(), fun((term(), term()) -> term())) -> term().
fold({set, S}, Acc, F) -> sets:fold(fun(X, A) -> F(A, X) end, Acc, S).

-spec foreach({set, sets:set()}, fun((term()) -> 'Unit')) -> 'Unit'.
foreach({set, S}, F) ->
    lists:foreach(F, sets:to_list(S)),
    'Unit'.

wrap(S) -> {set, S}.
