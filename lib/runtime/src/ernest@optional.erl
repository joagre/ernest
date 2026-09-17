%% Appendix E.10, namespace Optional, as an Erlang module for MVP 1.
-module('ernest@optional').

-export([isSome/1, isNone/1, withDefault/2, map/2, andThen/2]).

isSome({'Some', _}) -> true;
isSome('None') -> false.
isNone(O) -> not isSome(O).
withDefault({'Some', X}, _) -> X;
withDefault('None', D) -> D.
map({'Some', X}, F) -> {'Some', F(X)};
map('None', _) -> 'None'.
andThen({'Some', X}, F) -> F(X);
andThen('None', _) -> 'None'.
