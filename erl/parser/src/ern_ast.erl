%% What more than one stage reads of the AST the parser builds, typed or
%% not: a node's span; every node in pre-order; what a pattern binds; the
%% type variables a declaration's signature names; and the unqualified
%% names free in an expression. The parser, the formatter,
%% the checker, the reply check, the exhaustiveness check and the emitter
%% each use them rather than a copy of their own, since copies of one rule
%% drift.
-module(ern_ast).

-export([span/1, walk/3, binder/1, pattern_binders/1, pattern_bindings/1, signature_variables/1,
         free_names/2, free_uses/2]).

-include_lib("parser/include/ern_ast.hrl").

%% Report §11.5: a node's span, its first field, which a node fresh from
%% its token holds as the token's position until the parser spans it.
-spec span(tuple()) -> ern_diagnostic:span() | ern_diagnostic:position().
span(Node) ->
    element(2, Node).

%% Every node in pre-order, with an accumulator threaded through: every
%% tuple whose first element is an atom, a record or a tagged part of one,
%% such as `{positional, T}` or `{size, E}`.
-spec walk(fun((tuple(), Acc) -> Acc), term(), Acc) -> Acc.
walk(Visit, Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    Acc1 = Visit(Node, Acc),
    lists:foldl(fun(Child, ChildAcc) -> walk(Visit, Child, ChildAcc) end, Acc1,
                tl(tuple_to_list(Node)));
walk(Visit, Nodes, Acc) when is_list(Nodes) ->
    lists:foldl(fun(Node, NodeAcc) -> walk(Visit, Node, NodeAcc) end, Acc, Nodes);
walk(_, _, Acc) ->
    Acc.

%% Report §5.10: the name a pattern node binds itself, with where the name
%% stands and the type the node holds: a variable, and the name after
%% `as`; none for any other node.
-spec binder(tuple()) -> {atom(), term(), term()} | none.
binder(#p_var{span = Span, name = Name, type = Type}) -> {Name, Span, Type};
binder(#p_as{name_span = Span, name = Name, type = Type}) -> {Name, Span, Type};
binder(_) -> none.

%% Report §5.10: the names a pattern binds, in the order written, each with
%% where it stands and the type its node holds, undefined before the
%% pattern is checked. The alternatives of a clause bind the same names
%% (§5.9), so the first says.
-spec pattern_binders(tuple()) -> [{atom(), term(), term()}].
pattern_binders(#p_var{} = Pattern) ->
    [binder(Pattern)];
pattern_binders(#p_as{pattern = Pattern} = As) ->
    pattern_binders(Pattern) ++ [binder(As)];
pattern_binders(#p_constructor{args = {positional, Pattern}}) ->
    pattern_binders(Pattern);
pattern_binders(#p_constructor{args = {named, FieldPatterns}}) ->
    lists:append([pattern_binders(Pattern) || #field_pattern{pattern = Pattern} <- FieldPatterns]);
pattern_binders(#p_tuple{elements = Elements}) ->
    lists:append([pattern_binders(Element) || Element <- Elements]);
pattern_binders(#p_list{elements = Elements}) ->
    lists:append([pattern_binders(Element) || Element <- Elements]);
pattern_binders(#p_cons{head = Head, tail = Tail}) ->
    pattern_binders(Head) ++ pattern_binders(Tail);
pattern_binders(#p_or{alternatives = [First | _]}) ->
    pattern_binders(First);
pattern_binders(#p_bitstring{segments = Segments}) ->
    %% report §5.11: a segment's value is a variable, a literal or `_`
    lists:append([pattern_binders(Value) || #bit_segment{value = Value} <- Segments]);
pattern_binders(_) ->
    [].

%% The names a pattern binds, as pattern_binders/1 gives them, each with its
%% type.
-spec pattern_bindings(tuple()) -> [{atom(), term()}].
pattern_bindings(Pattern) ->
    [{Name, Type} || {Name, _, Type} <- pattern_binders(Pattern)].

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
%% names Bound around it, once for each use.
-spec free_names(term(), [atom()]) -> [atom()].
free_names(Node, Bound) ->
    [Name || #e_var{name = Name} <- free_uses(Node, Bound)].

%% Report §5.4, §3.11: the uses of the unqualified names free in an
%% expression, outside the names Bound around it, each a name node with
%% what the checker set on it, once for each use. A lambda's parameters, a
%% clause's pattern, a block's bindings from the statement after them and
%% a local fn's name throughout its block bind. A pattern's bitstring size
%% expressions read names too (§5.11).
-spec free_uses(term(), [atom()]) -> [#e_var{}].
free_uses(#e_var{namespace = [], name = Name} = Use, Bound) ->
    case lists:member(Name, Bound) of true -> []; false -> [Use] end;
free_uses(#e_lambda{params = Params, body = Body}, Bound) ->
    free_uses(Body, param_names(Params) ++ Bound);
free_uses(#e_block{statements = Statements}, Bound) ->
    Fns = [Name || #fn_declaration{name = Name} <- Statements],
    {Free, _} = lists:mapfoldl(fun statement_free_uses/2, Fns ++ Bound, Statements),
    lists:append(Free);
free_uses(#clause{pattern = Pattern, guard = Guard, body = Body}, Bound) ->
    Bound1 = bound_names(Pattern) ++ Bound,
    pattern_free_uses(Pattern, Bound) ++ free_uses(Guard, Bound1) ++ free_uses(Body, Bound1);
free_uses(Node, Bound) when is_tuple(Node) ->
    lists:append([free_uses(Child, Bound) || Child <- tl(tuple_to_list(Node))]);
free_uses(Nodes, Bound) when is_list(Nodes) ->
    lists:append([free_uses(Node, Bound) || Node <- Nodes]);
free_uses(_, _) ->
    [].

%% A block's statement: its free uses, and the names bound from the next
%% statement on.
statement_free_uses(#binding{pattern = Pattern, expr = Expr}, Bound) ->
    {free_uses(Expr, Bound) ++ pattern_free_uses(Pattern, Bound), bound_names(Pattern) ++ Bound};
statement_free_uses(#fn_declaration{params = Params, body = Body}, Bound) ->
    {free_uses(Body, param_names(Params) ++ Bound), Bound};
statement_free_uses(Statement, Bound) ->
    {free_uses(Statement, Bound), Bound}.

bound_names(Pattern) -> [Name || {Name, _} <- pattern_bindings(Pattern)].

%% Report §5.11: the uses a pattern's bitstrings read, each size expression
%% in the scope of its bitstring's earlier segments.
pattern_free_uses(Pattern, Bound) ->
    walk(fun(#p_bitstring{segments = Segments}, Acc) -> Acc ++ segments_free_uses(Segments, Bound);
            (_, Acc) -> Acc
         end, Pattern, []).

segments_free_uses(Segments, Bound) ->
    {Free, _} = lists:mapfoldl(fun(#bit_segment{value = Value, specs = Specs}, Earlier) ->
                                   {free_uses([Size || {size, Size} <- Specs], Earlier),
                                    bound_names(Value) ++ Earlier}
                               end, Bound, Segments),
    lists:append(Free).

param_names(Params) -> lists:append([bound_names(Pattern) || #param{pattern = Pattern} <- Params]).
