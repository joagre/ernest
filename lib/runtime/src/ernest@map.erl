%% Appendix E.3, namespace Map, as an Erlang module for MVP 1: an Erlang map,
%% so equality on maps is structural and key order is unspecified.
-module('ernest@map').

-export([empty/0, size/1, isEmpty/1, contains/2, get/2, put/3, remove/2, keys/1, values/1,
         map/2, filter/2, foldLeft/3, any/2, all/2, find/2, fromList/1, toList/1]).

empty() -> #{}.
size(M) -> map_size(M).
isEmpty(M) -> map_size(M) =:= 0.
contains(M, K) -> is_map_key(K, M).
get(M, K) ->
    case M of
        #{K := V} -> {'Some', V};
        _ -> 'None'
    end.
put(M, K, V) -> M#{K => V}.
remove(M, K) -> maps:remove(K, M).
keys(M) -> maps:keys(M).
values(M) -> maps:values(M).
map(M, F) -> maps:map(F, M).
foldLeft(M, Acc, F) -> maps:fold(fun(K, V, A) -> F(A, K, V) end, Acc, M).
filter(M, P) -> maps:filter(P, M).
any(M, P) -> lists:any(fun({K, V}) -> P(K, V) end, maps:to_list(M)).
all(M, P) -> lists:all(fun({K, V}) -> P(K, V) end, maps:to_list(M)).
find(M, P) ->
    case lists:search(fun({K, V}) -> P(K, V) end, maps:to_list(M)) of
        {value, KV} -> {'Some', KV};
        false -> 'None'
    end.
fromList(KVs) -> maps:from_list(KVs).
toList(M) -> maps:to_list(M).
