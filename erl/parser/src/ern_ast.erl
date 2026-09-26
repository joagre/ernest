%% The one walk over the AST the parser builds, typed or not: every node
%% in pre-order, a node being a tuple whose first element is its record's
%% name, with an accumulator threaded through. The checker's passes, the
%% reply check and the exhaustiveness check each walk with it.
-module(ern_ast).

-export([walk/3]).

-spec walk(fun((tuple(), Acc) -> Acc), term(), Acc) -> Acc.
walk(F, Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    Acc1 = F(Node, Acc),
    lists:foldl(fun(X, A) -> walk(F, X, A) end, Acc1, tl(tuple_to_list(Node)));
walk(F, L, Acc) when is_list(L) ->
    lists:foldl(fun(X, A) -> walk(F, X, A) end, Acc, L);
walk(_, _, Acc) ->
    Acc.
