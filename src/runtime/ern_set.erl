%% The primitives of Set (report Appendix E.4, E.0 rule 1) that make a set:
%% Erlang's version 2 sets, a map from each element to [] (report §12.2),
%% which the host makes only when asked. The rest of Set's primitives are
%% the `sets` module's own functions.
-module(ern_set).

-export([empty/0, from_list/1]).

-spec empty() -> sets:set().
empty() -> sets:new([{version, 2}]).

-spec from_list([term()]) -> sets:set().
from_list(List) -> sets:from_list(List, [{version, 2}]).
