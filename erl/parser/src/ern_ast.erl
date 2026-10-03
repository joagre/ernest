%% What more than one stage reads of the AST the parser builds, typed or
%% not: a node's span; every node in pre-order; what a pattern binds; the
%% type variables a declaration's signature names; and the unqualified
%% names free in an expression. The parser, the formatter,
%% the checker, the reply check, the exhaustiveness check and the emitter
%% each use them rather than a copy of their own, since copies of one rule
%% drift.
-module(ern_ast).

-export([span/1, walk/3, pattern_bindings/1, signature_variables/1, free_names/2]).

-include_lib("parser/include/ern_ast.hrl").

%% Report §11.5: a node's span, its first field, which a node fresh from
%% its token holds as the token's position until the parser spans it.
-spec span(tuple()) -> ern_diagnostic:span() | ern_diagnostic:position().
span(Node) ->
    element(2, Node).

%% Every node in pre-order, a node being a tuple whose first element is
%% its record's name, with an accumulator threaded through.
-spec walk(fun((tuple(), Acc) -> Acc), term(), Acc) -> Acc.
walk(Visit, Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    Acc1 = Visit(Node, Acc),
    lists:foldl(fun(Child, ChildAcc) -> walk(Visit, Child, ChildAcc) end, Acc1,
                tl(tuple_to_list(Node)));
walk(Visit, Nodes, Acc) when is_list(Nodes) ->
    lists:foldl(fun(Node, NodeAcc) -> walk(Visit, Node, NodeAcc) end, Acc, Nodes);
walk(_, _, Acc) ->
    Acc.

%% Report §5.10: the names a pattern binds, in the order written, each with
%% the type its node holds, undefined before the pattern is checked. The
%% alternatives of a clause bind the same names (§5.9), so the first says.
-spec pattern_bindings(tuple()) -> [{atom(), term()}].
pattern_bindings(#p_var{name = Name, type = Type}) ->
    [{Name, Type}];
pattern_bindings(#p_as{name = Name, type = Type, pattern = Pattern}) ->
    pattern_bindings(Pattern) ++ [{Name, Type}];
pattern_bindings(#p_constructor{args = {positional, Pattern}}) ->
    pattern_bindings(Pattern);
pattern_bindings(#p_constructor{args = {named, FieldPatterns}}) ->
    lists:append([pattern_bindings(Pattern) || #field_pattern{pattern = Pattern} <- FieldPatterns]);
pattern_bindings(#p_tuple{elements = Elements}) ->
    lists:append([pattern_bindings(Element) || Element <- Elements]);
pattern_bindings(#p_list{elements = Elements}) ->
    lists:append([pattern_bindings(Element) || Element <- Elements]);
pattern_bindings(#p_cons{head = Head, tail = Tail}) ->
    pattern_bindings(Head) ++ pattern_bindings(Tail);
pattern_bindings(#p_or{alternatives = [First | _]}) ->
    pattern_bindings(First);
pattern_bindings(#p_bitstring{segments = Segments}) ->
    %% report §5.11: a segment's value is a variable, a literal or `_`
    lists:append([pattern_bindings(Value) || #bit_segment{value = Value} <- Segments]);
pattern_bindings(_) ->
    [].

%% Report §3.9, §4.9: the type variables a fn declaration's signature
%% names, in its parameters' annotations, its result type and its effect.
-spec signature_variables(tuple()) -> [atom()].
signature_variables(#fn_declaration{params = Params, result_type = ResultType,
                                    effect = Effect}) ->
    lists:usort(type_variables([ResultType, Effect
                                | [Annotation || #param{annotation = Annotation} <- Params]])).

type_variables(#t_var{name = Name}) -> [Name];
type_variables(Node) when is_tuple(Node) -> type_variables(tuple_to_list(Node));
type_variables(Nodes) when is_list(Nodes) -> lists:append([type_variables(Node) || Node <- Nodes]);
type_variables(_) -> [].

%% Report §5.4: the unqualified names free in an expression, outside the
%% names Bound around it, once for each use. A lambda's parameters, a
%% clause's pattern, a block's bindings from the statement after them and
%% a local fn's name for the rest of its block and its own body bind.
-spec free_names(term(), [atom()]) -> [atom()].
free_names(#e_var{namespace = [], name = Name}, Bound) ->
    case lists:member(Name, Bound) of true -> []; false -> [Name] end;
free_names(#e_lambda{params = Params, body = Body}, Bound) ->
    free_names(Body, param_names(Params) ++ Bound);
free_names(#e_block{statements = Statements}, Bound) ->
    {Free, _} = lists:mapfoldl(fun statement_free_names/2, Bound, Statements),
    lists:append(Free);
free_names(#clause{pattern = Pattern, guard = Guard, body = Body}, Bound) ->
    Bound1 = bound_names(Pattern) ++ Bound,
    free_names(Guard, Bound1) ++ free_names(Body, Bound1);
free_names(Node, Bound) when is_tuple(Node) ->
    lists:append([free_names(Child, Bound) || Child <- tl(tuple_to_list(Node))]);
free_names(Nodes, Bound) when is_list(Nodes) ->
    lists:append([free_names(Node, Bound) || Node <- Nodes]);
free_names(_, _) ->
    [].

%% A block's statement: its free names, and the names bound from the next
%% statement on.
statement_free_names(#binding{pattern = Pattern, expr = Expr}, Bound) ->
    {free_names(Expr, Bound), bound_names(Pattern) ++ Bound};
statement_free_names(#fn_declaration{name = Name, params = Params, body = Body}, Bound) ->
    {free_names(Body, [Name | param_names(Params)] ++ Bound), [Name | Bound]};
statement_free_names(Statement, Bound) ->
    {free_names(Statement, Bound), Bound}.

bound_names(Pattern) -> [Name || {Name, _} <- pattern_bindings(Pattern)].

param_names(Params) -> lists:append([bound_names(Pattern) || #param{pattern = Pattern} <- Params]).
