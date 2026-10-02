%% The primitives of Set (report Appendix E.4, E.0 rule 1): Erlang's
%% version 2 sets, a map underneath, tagged {set, S} so that a Set and a
%% Map are told apart at runtime (report §8.4). The rest of Set is Ernest
%% over these six.
-module(ern_set).

-export([empty/0, size/1, contains/2, put/2, remove/2, to_list/1]).

-spec empty() -> {set, sets:set()}.
empty() -> wrap(sets:new([{version, 2}])).

-spec size({set, sets:set()}) -> non_neg_integer().
size({set, Set}) -> sets:size(Set).

-spec contains({set, sets:set()}, term()) -> boolean().
contains({set, Set}, Element) -> sets:is_element(Element, Set).

%% sets:add_element/2 answers the set unchanged for an element it has.
-spec put({set, sets:set()}, term()) -> {set, sets:set()}.
put({set, Set}, Element) -> wrap(sets:add_element(Element, Set)).

%% sets:del_element/2 answers the set unchanged for an element it lacks.
-spec remove({set, sets:set()}, term()) -> {set, sets:set()}.
remove({set, Set}, Element) -> wrap(sets:del_element(Element, Set)).

%% sets:to_list/1: the elements in an order the set does not promise.
-spec to_list({set, sets:set()}) -> [term()].
to_list({set, Set}) -> sets:to_list(Set).

wrap(Set) -> {set, Set}.
