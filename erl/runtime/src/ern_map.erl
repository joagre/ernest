%% The primitives of Map (report Appendix E.3, E.0 rule 1): the operations
%% that reach Erlang's maps, whose structure sharing is what the language
%% wants, with Ernest's argument order, subject first, and Optional where a
%% key may be absent. The rest of Map is Ernest over these six.
-module(ern_map).

-export([empty/0, size/1, get/2, put/3, remove/2, to_list/1]).

-spec empty() -> map().
empty() -> #{}.

-spec size(map()) -> non_neg_integer().
size(Map) -> map_size(Map).

-spec get(map(), term()) -> {'Some', term()} | 'None'.
get(Map, Key) ->
    case Map of
        #{Key := Value} -> {'Some', Value};
        _ -> 'None'
    end.

-spec put(map(), term(), term()) -> map().
put(Map, Key, Value) -> Map#{Key => Value}.

%% maps:remove/2 answers the map unchanged for a key it lacks.
-spec remove(map(), term()) -> map().
remove(Map, Key) -> maps:remove(Key, Map).

%% maps:to_list/1: the pairs in an order the map does not promise, each
%% the tuple that is Ernest's #(k, v) (report §8.4).
-spec to_list(map()) -> [{term(), term()}].
to_list(Map) -> maps:to_list(Map).
