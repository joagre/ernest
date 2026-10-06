%% The primitives of Set (report Appendix E.4, E.0 rule 1): Erlang's
%% version 2 sets, a map underneath, tagged {set, S} so that a Set and a
%% Map are told apart at runtime (report §8.4). Each is a function of the
%% `sets` module, the tag taken off and put back; the rest of Set is Ernest
%% over them.
-module(ern_set).

-export([empty/0, size/1, contains/2, put/2, remove/2, map/2, filter/2, from_list/1, to_list/1,
         union/2, intersection/2, difference/2, is_subset/2]).

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

%% Appendix E.4: the order in which the function meets the elements is
%% unspecified, as the host's page leaves it.
-spec map({set, sets:set()}, fun((term()) -> term())) -> {set, sets:set()}.
map({set, Set}, F) -> wrap(sets:map(F, Set)).

-spec filter({set, sets:set()}, fun((term()) -> boolean())) -> {set, sets:set()}.
filter({set, Set}, Keep) -> wrap(sets:filter(Keep, Set)).

-spec from_list([term()]) -> {set, sets:set()}.
from_list(List) -> wrap(sets:from_list(List, [{version, 2}])).

%% sets:to_list/1: the elements in an order the set does not promise.
-spec to_list({set, sets:set()}) -> [term()].
to_list({set, Set}) -> sets:to_list(Set).

-spec union({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
union({set, Set}, {set, Other}) -> wrap(sets:union(Set, Other)).

-spec intersection({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
intersection({set, Set}, {set, Other}) -> wrap(sets:intersection(Set, Other)).

%% Appendix E.4: the elements of the first not in the second.
-spec difference({set, sets:set()}, {set, sets:set()}) -> {set, sets:set()}.
difference({set, Set}, {set, Other}) -> wrap(sets:subtract(Set, Other)).

-spec is_subset({set, sets:set()}, {set, sets:set()}) -> boolean().
is_subset({set, Set}, {set, Other}) -> sets:is_subset(Set, Other).

wrap(Set) -> {set, Set}.
