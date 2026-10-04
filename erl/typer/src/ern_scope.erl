%% Report §5.4: the rules for a local fn, read off a definition. Its name
%% may not be one bound where it is declared (names/1); it may be used only
%% after the lets of its block it references (order/1); and what its body
%% refers to among given names (free_references/3), which the checker's
%% grouping of a block's local fns reads too. A breach is thrown as the
%% checker's type errors are.
-module(ern_scope).

-export([names/1, order/1, free_references/3]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

%% Report §5.4: a local fn may not take the name of a parameter or a
%% variable in scope where it is declared, nor of a `let` of its block.
%% The scope is read off the declaration as written: the variables bound
%% around each local fn, with where each is bound. A local fn of an
%% enclosing block is no variable, and one of its name may be declared.
-spec names(tuple()) -> ok.
names(#fn_declaration{params = Params, body = Body}) ->
    check_fn_names(Body, param_variables(Params));
names(#let_declaration{body = Body}) -> check_fn_names(Body, []);
names(_) -> ok.

check_fn_names(#e_lambda{params = Params, body = Body}, InScope) ->
    check_fn_names(Body, param_variables(Params) ++ InScope);
check_fn_names(#clause{pattern = Pattern, guard = Guard, body = Body}, InScope) ->
    InScope1 = pattern_variables(Pattern) ++ InScope,
    check_fn_names(Guard, InScope1),
    check_fn_names(Body, InScope1);
check_fn_names(#e_block{statements = Statements}, InScope) ->
    Lets = lists:append([pattern_variables(Pattern) || #binding{pattern = Pattern} <- Statements]),
    lists:foldl(fun(#binding{pattern = Pattern, expr = Expr}, Acc) ->
                        check_fn_names(Expr, Acc),
                        pattern_variables(Pattern) ++ Acc;
                   (#fn_declaration{span = Span, name = Name, params = Params, body = Body}, Acc) ->
                        local_fn_name(Span, Name, Acc, "a variable in scope where it is declared"),
                        local_fn_name(Span, Name, Lets, "a `let` of its block"),
                        check_fn_names(Body, param_variables(Params) ++ Acc),
                        Acc;
                   (Statement, Acc) ->
                        check_fn_names(Statement, Acc),
                        Acc
                end, InScope, Statements),
    ok;
check_fn_names(Node, InScope) when is_tuple(Node) ->
    check_fn_names(tl(tuple_to_list(Node)), InScope);
check_fn_names(Nodes, InScope) when is_list(Nodes) ->
    lists:foreach(fun(Child) -> check_fn_names(Child, InScope) end, Nodes);
check_fn_names(_, _) ->
    ok.

local_fn_name(Span, Name, InScope, What) ->
    case lists:keyfind(Name, 1, InScope) of
        false ->
            ok;
        {Name, BoundSpan} ->
            fail(Span, "local function " ++ atom_to_list(Name) ++ " has the name of " ++ What,
                 [{ern_diagnostic:span(BoundSpan), atom_to_list(Name) ++ " is bound here"}],
                 "rename the function or the variable")
    end.

param_variables(Params) ->
    lists:append([pattern_variables(Pattern) || #param{pattern = Pattern} <- Params]).

%% The variables a pattern binds, each with where it is bound.
pattern_variables(Pattern) ->
    [{Name, Span} || {Name, Span, _} <- ern_ast:pattern_binders(Pattern)].

%% Report §5.4: a local fn may be used only after every `let` of its block
%% that it references, directly or through other local fns, has been
%% evaluated. Uses are calls and value references alike.
-spec order(tuple()) -> ok.
order(Node) ->
    ern_ast:walk(fun(#e_block{statements = Statements}, Acc) -> block_order(Statements), Acc;
                    (_, Acc) -> Acc
                 end, Node, ok),
    ok.

block_order(Statements) ->
    Fns = [Declaration || #fn_declaration{} = Declaration <- Statements],
    FnNames = [Name || #fn_declaration{name = Name} <- Fns],
    Indexed = lists:zip(lists:seq(1, length(Statements)), Statements),
    %% every let binding of the block as an instance {Name, Index}
    Lets = [{Name, LetIndex} || {LetIndex, #binding{pattern = Pattern}} <- Indexed,
                                Name <- pattern_names(Pattern)],
    Direct = maps:from_list([{Name, references(Declaration, FnIndex, FnNames, Lets)}
                             || {FnIndex, #fn_declaration{name = Name} = Declaration} <- Indexed]),
    Needs = fun(Name) -> needed_lets(Name, Direct, [], []) end,
    %% where each let instance is bound, for the error's label
    BoundSpans = maps:from_list([{{Name, LetIndex}, Span}
                                 || {LetIndex, #binding{pattern = Pattern}} <- Indexed,
                                    {Name, Span} <- pattern_variables(Pattern)]),
    lists:foldl(fun({LetIndex, #binding{pattern = Pattern, expr = Expr}}, Bound) ->
                        check_uses(Expr, FnNames, Needs, Bound, BoundSpans),
                        [{Name, LetIndex} || Name <- pattern_names(Pattern)] ++ Bound;
                   ({_, #fn_declaration{}}, Bound) ->
                        Bound;
                   ({_, Expr}, Bound) ->
                        check_uses(Expr, FnNames, Needs, Bound, BoundSpans),
                        Bound
                end, [], Indexed).

%% What a local fn references: its siblings, and the binding of each let
%% name in force at its declaration (report §5.4, §4.6).
references(#fn_declaration{params = Params, body = Body}, FnIndex, FnNames, Lets) ->
    LetNames = lists:usort([Name || {Name, _} <- Lets]),
    Siblings = [Reference || Reference <- free_references(Body, Params, LetNames ++ FnNames),
                             lists:member(Reference, FnNames)],
    InForce = [{Reference, LetIndex} || Reference <- free_references(Body, Params, LetNames),
                                        LetIndex <- [in_force(Reference, FnIndex, Lets)],
                                        LetIndex =/= none],
    Siblings ++ InForce.

%% The latest binding of Name before statement FnIndex, or none.
in_force(Name, FnIndex, Lets) ->
    case [LetIndex || {LetName, LetIndex} <- Lets, LetName =:= Name, LetIndex < FnIndex] of
        [] -> none;
        Indexes -> lists:max(Indexes)
    end.

%% The let instances a local fn needs, following references between local
%% fns.
needed_lets(Name, Direct, Seen, Acc) ->
    case lists:member(Name, Seen) of
        true -> Acc;
        false ->
            References = maps:get(Name, Direct, []),
            Acc1 = lists:usort(Acc ++ [Reference || Reference <- References, is_tuple(Reference)]),
            lists:foldl(fun(Reference, Found) when is_atom(Reference) ->
                                needed_lets(Reference, Direct, [Name | Seen], Found);
                           (_, Found) ->
                                Found
                        end, Acc1, References)
    end.

check_uses(Expr, FnNames, Needs, Bound, BoundSpans) ->
    ern_ast:walk(fun(#e_var{span = Span, namespace = [], name = FnName}, Acc) ->
                         case lists:member(FnName, FnNames) of
                             true -> check_use(Span, FnName, Needs(FnName) -- Bound, BoundSpans);
                             false -> ok
                         end,
                         Acc;
                    (_, Acc) ->
                         Acc
                 end, Expr, ok).

%% Report §5.4: a local fn used where a `let` it references is not yet
%% evaluated, the first such `let` labelled.
check_use(_Span, _FnName, [], _BoundSpans) ->
    ok;
check_use(Span, FnName, [{LetName, _} = Let | _], BoundSpans) ->
    LetText = atom_to_list(LetName),
    fail(Span, "local function " ++ atom_to_list(FnName) ++ " is used before `let " ++ LetText
               ++ "`, which it references",
         [{ern_diagnostic:span(maps:get(Let, BoundSpans)),
           "`let " ++ LetText ++ "` is evaluated here"}],
         "use " ++ atom_to_list(FnName) ++ " after `let " ++ LetText ++ "`").

%% Unqualified names of the given set free in a local fn's body: outside
%% its parameters and the bindings inside the body.
-spec free_references(term(), [tuple()], [atom()]) -> [atom()].
free_references(Body, Params, Names) ->
    lists:usort([Name || Name <- ern_ast:free_names(Body, param_names(Params)),
                         lists:member(Name, Names)]).

pattern_names(Pattern) -> [Name || {Name, _} <- ern_ast:pattern_bindings(Pattern)].

param_names(Params) ->
    lists:append([pattern_names(Pattern) || #param{pattern = Pattern} <- Params]).

fail(Span, Message, Labels, Help) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = lists:flatten(Message),
                                   labels = Labels, help = Help}}).
