%% The walks over the AST the parser builds that more than one stage needs,
%% typed or not: every node in pre-order; what a pattern binds; and the
%% unqualified names free in an expression. The checker, the reply check,
%% the exhaustiveness check and the emitter each use them rather than a
%% copy of their own, since copies of one rule drift.
-module(ern_ast).

-export([walk/3, pattern_bindings/1, free_names/2]).

-include_lib("parser/include/ern_ast.hrl").

%% Every node in pre-order, a node being a tuple whose first element is
%% its record's name, with an accumulator threaded through.
-spec walk(fun((tuple(), Acc) -> Acc), term(), Acc) -> Acc.
walk(F, Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    Acc1 = F(Node, Acc),
    lists:foldl(fun(X, A) -> walk(F, X, A) end, Acc1, tl(tuple_to_list(Node)));
walk(F, L, Acc) when is_list(L) ->
    lists:foldl(fun(X, A) -> walk(F, X, A) end, Acc, L);
walk(_, _, Acc) ->
    Acc.

%% Report §5.10: the names a pattern binds, in the order written, each with
%% the type its node holds, undefined before the pattern is checked. The
%% alternatives of a clause bind the same names (§5.9), so the first says.
-spec pattern_bindings(tuple()) -> [{atom(), term()}].
pattern_bindings(#p_var{name = N, type = T}) -> [{N, T}];
pattern_bindings(#p_as{name = N, type = T, pattern = P}) -> pattern_bindings(P) ++ [{N, T}];
pattern_bindings(#p_con{args = {positional, P}}) -> pattern_bindings(P);
pattern_bindings(#p_con{args = {named, Fs}}) ->
    lists:append([pattern_bindings(P) || #field_pat{pattern = P} <- Fs]);
pattern_bindings(#p_tuple{elems = Es}) -> lists:append([pattern_bindings(E) || E <- Es]);
pattern_bindings(#p_list{elems = Es}) -> lists:append([pattern_bindings(E) || E <- Es]);
pattern_bindings(#p_cons{head = H, tail = T}) -> pattern_bindings(H) ++ pattern_bindings(T);
pattern_bindings(#p_or{alts = [A | _]}) -> pattern_bindings(A);
pattern_bindings(#p_bits{segments = Segs}) ->
    %% report §5.11: a segment's value is a variable, a literal or `_`
    lists:append([pattern_bindings(V) || #bit_seg{value = V} <- Segs]);
pattern_bindings(_) -> [].

%% Report §5.4: the unqualified names free in an expression, outside the
%% names Bound around it, once for each use. A lambda's parameters, a
%% clause's pattern, a block's bindings from the statement after them and
%% a local fn's name for the rest of its block and its own body bind.
-spec free_names(term(), [atom()]) -> [atom()].
free_names(#e_var{path = [], name = N}, Bound) ->
    case lists:member(N, Bound) of true -> []; false -> [N] end;
free_names(#e_lambda{params = Ps, body = B}, Bound) ->
    free_names(B, param_names(Ps) ++ Bound);
free_names(#e_block{stmts = Stmts}, Bound) ->
    {Free, _} = lists:mapfoldl(fun(#binding{pattern = P, expr = X}, Bd) ->
                                       {free_names(X, Bd), names(P) ++ Bd};
                                  (#fn_decl{name = N, params = Ps, body = B}, Bd) ->
                                       {free_names(B, [N | param_names(Ps)] ++ Bd), [N | Bd]};
                                  (S, Bd) ->
                                       {free_names(S, Bd), Bd}
                               end, Bound, Stmts),
    lists:append(Free);
free_names(#clause{pattern = P, guard = G, body = B}, Bound) ->
    Bd = names(P) ++ Bound,
    free_names(G, Bd) ++ free_names(B, Bd);
free_names(T, Bound) when is_tuple(T) ->
    lists:append([free_names(X, Bound) || X <- tl(tuple_to_list(T))]);
free_names(L, Bound) when is_list(L) ->
    lists:append([free_names(X, Bound) || X <- L]);
free_names(_, _) ->
    [].

names(P) -> [N || {N, _} <- pattern_bindings(P)].

param_names(Params) -> lists:append([names(P) || #param{pattern = P} <- Params]).
