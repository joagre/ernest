%% Appendix E.11, namespace Either, as an Erlang module for MVP 1.
-module('ernest@either').

-export([isLeft/1, isRight/1, withDefault/2, map/2, mapLeft/2, andThen/2, toOptional/1,
         fromOptional/2]).

isLeft({'Left', _}) -> true;
isLeft({'Right', _}) -> false.
isRight(E) -> not isLeft(E).
withDefault({'Right', X}, _) -> X;
withDefault({'Left', _}, D) -> D.
map({'Right', X}, F) -> {'Right', F(X)};
map({'Left', _} = L, _) -> L.
mapLeft({'Left', E}, F) -> {'Left', F(E)};
mapLeft({'Right', _} = R, _) -> R.
andThen({'Right', X}, F) -> F(X);
andThen({'Left', _} = L, _) -> L.
toOptional({'Right', X}) -> {'Some', X};
toOptional({'Left', _}) -> 'None'.
fromOptional({'Some', X}, _) -> {'Right', X};
fromOptional('None', E) -> {'Left', E}.
