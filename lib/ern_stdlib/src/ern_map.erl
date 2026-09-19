%% The shims behind Map (report Appendix E.3, rule 1): Erlang's maps, whose
%% structure sharing is what the language wants, with Ernest's argument
%% order, subject first, and Optional where a key may be absent.
-module(ern_map).

-export([empty/0, size/1, contains/2, get/2, put/3, remove/2, map/2, filter/2, filtermap/2,
         fold/3, foreach/2]).

-spec empty() -> map().
empty() -> #{}.

-spec size(map()) -> non_neg_integer().
size(M) -> map_size(M).

-spec contains(map(), term()) -> boolean().
contains(M, K) -> is_map_key(K, M).

-spec get(map(), term()) -> {'Some', term()} | 'None'.
get(M, K) ->
    case M of
        #{K := V} -> {'Some', V};
        _ -> 'None'
    end.

-spec put(map(), term(), term()) -> map().
put(M, K, V) -> M#{K => V}.

-spec remove(map(), term()) -> map().
remove(M, K) -> maps:remove(K, M).

-spec map(map(), fun((term(), term()) -> term())) -> map().
map(M, F) -> maps:map(F, M).

-spec filter(map(), fun((term(), term()) -> boolean())) -> map().
filter(M, P) -> maps:filter(P, M).

%% Appendix E.3: the entries the function answers Some for, that value in
%% their place
-spec filtermap(map(), fun((term(), term()) -> {'Some', term()} | 'None')) -> map().
filtermap(M, F) ->
    maps:filtermap(fun(K, V) ->
                       case F(K, V) of
                           {'Some', W} -> {true, W};
                           'None' -> false
                       end
                   end, M).

-spec fold(map(), term(), fun((term(), term(), term()) -> term())) -> term().
fold(M, Acc, F) -> maps:fold(fun(K, V, A) -> F(A, K, V) end, Acc, M).

-spec foreach(map(), fun((term(), term()) -> 'Unit')) -> 'Unit'.
foreach(M, F) ->
    maps:foreach(F, M),
    'Unit'.
