%% Appendix E.14, namespace Path, as an Erlang module for MVP 1. A Path is
%% {'Path', String} under the ABI (report §8.4, §9.3), in the runtime's
%% syntax; join is filename:join, so an absolute second stands alone.
-module('ernest@path').

-export([join/2, withSuffix/2, toString/1]).

join({'Path', A}, {'Path', B}) -> {'Path', unicode:characters_to_binary(filename:join(A, B))}.
withSuffix({'Path', P}, S) -> {'Path', <<P/binary, S/binary>>}.
toString({'Path', P}) -> P.
