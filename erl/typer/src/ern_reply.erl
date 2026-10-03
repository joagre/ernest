%% The reply discipline, report §6.6: Reply(a) is linear. Every variable
%% bound to a reply-carrying value is used exactly once on every path;
%% a use is any occurrence, since the type checker already guarantees that
%% every position such a value can occupy is a consuming one. Also: no `as`
%% on a reply-carrying value; no wildcard or omitted reply-carrying field;
%% a lambda that captures a linear variable is linear itself: consumed
%% exactly once, by a call or as spawn's direct argument, bindable by let,
%% and legal nowhere else. Obligations holds a name for a value and
%% {lambda, Name} for such a lambda bound by let.
%%
%% A path with a call that does not return, to a function whose result type
%% is a variable no parameter's type names, `fault` among them, consumes
%% every obligation open on it (§6.6): its uses carry the mark
%% {'$fault', Span}, which no name is, so a branch that faults is left out
%% of the comparison of branches, and a name a faulting path leaves
%% unconsumed is not a name never consumed. The mark does not leave a
%% lambda or a local function, whose bodies are not on the enclosing path.
%%
%% Report §3.9: a type variable of a parameter's type gets the
%% not_reply_carrying restriction when the body, read with that variable
%% taken for reply-carrying, would break this discipline: a second use or
%% none, through a `let` or a pattern as much as by the parameter's own
%% name, a place a reply may not stand, or a user type that carries one
%% dropped.
-module(ern_reply).

-export([check/4]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

-spec check([#param{}], tuple(), ern_types:type(), ern_typecheck:env()) ->
          ern_typecheck:env().
check(Params, Body, Type, Env) ->
    discipline(Params, Body, Env),
    TypeState = ern_typecheck:type_state(Env),
    Variables = lists:usort(param_variables(Type, TypeState)),
    lists:foldl(fun(Variable, Acc) -> restricted(Variable, Params, Body, Acc) end, Env,
                Variables).

%% Report §3.9: the variable takes the not_reply_carrying restriction where
%% the body, with it taken for reply-carrying, breaks the discipline.
restricted(Variable, Params, Body, Env) ->
    case holds(Params, Body, ern_typecheck:assume_reply_carrying([Variable], Env)) of
        true ->
            Env;
        false ->
            TypeState = ern_types:add_restriction(Variable, not_reply_carrying,
                                                  ern_typecheck:type_state(Env)),
            ern_typecheck:set_type_state(TypeState, Env)
    end.

%% The whole discipline over one function: its illegal positions, and each
%% linear parameter consumed exactly once.
discipline(Params, Body, Env) ->
    positions(Params, Env),
    positions(Body, Env),
    Obligations = [Name || Param <- Params, Name <- obligations_bound(Param#param.pattern, Env)],
    Uses = uses(Body, Obligations, Env),
    lists:foreach(fun(Name) -> exactly_once(Name, Uses, ern_ast:span(Body)) end, Obligations).

%% Would the body keep the discipline under this environment's assumption?
holds(Params, Body, Env) ->
    try
        discipline(Params, Body, Env),
        true
    catch
        throw:{type_error, _, _} -> false;
        throw:{type_error, #diagnostic{}} -> false
    end.

%% The type variables of the parameters' types, where values stand: not a
%% function type's effect. A let's type has no parameters.
param_variables(Type, TypeState) ->
    case ern_types:resolve(Type, TypeState) of
        {tfn, ParamTypes, _, _} ->
            lists:append([value_variables(ParamType, TypeState) || ParamType <- ParamTypes]);
        _ -> []
    end.

value_variables(Type, TypeState) ->
    case ern_types:resolve(Type, TypeState) of
        {tvar, _} = Variable -> [Variable];
        {tcon, _, Args} -> lists:append([value_variables(Arg, TypeState) || Arg <- Args]);
        {ttuple, Elements} ->
            lists:append([value_variables(Element, TypeState) || Element <- Elements]);
        {tfn, Params, _, Result} ->
            lists:append([value_variables(Part, TypeState) || Part <- [Result | Params]]);
        _ -> []
    end.

%%
%% Illegal positions and patterns
%%

positions(Node, Env) ->
    walk(fun(Child) -> position(Child, Env) end, Node).

position(#p_wildcard{span = Span, type = Type}, Env) ->
    not ern_typecheck:is_reply_carrying(Type, Env)
        orelse throw({type_error, Span, "`_` would discard a reply-carrying value"});
position(#p_as{span = Span, type = Type}, Env) ->
    not ern_typecheck:is_reply_carrying(Type, Env)
        orelse throw({type_error, Span, "`as` on a reply-carrying value would duplicate it"});
position(#p_constructor{type = Type} = Pattern, Env) ->
    case ern_typecheck:is_reply_carrying(Type, Env) of
        true -> reply_fields(Pattern, Env);
        false -> ok
    end;
position(_, _) -> ok.

%% Report §6.6: a pattern on a reply-carrying constructor binds each of its
%% fields that carries a reply, at the field's type where the pattern
%% stands; `_` and an omitted field bind nothing.
reply_fields(#p_constructor{span = Span, namespace = Namespace, name = Name, args = Args,
                            type = Type}, Env) ->
    #constructor_info{fields = Fields, scheme = Scheme} =
        ern_typecheck:lookup_constructor(Span, Namespace, Name, Env),
    {FieldTypes, Env1} = field_types(Scheme, Type, Env),
    case {Fields, Args} of
        {positional, {positional, #p_wildcard{}}} ->
            wild_field(Span, Name, FieldTypes, Env1);
        {{named, Names}, {named, FieldPatterns}} ->
            Bound = [FieldName || #field_pattern{name = FieldName, pattern = Pattern}
                                      <- FieldPatterns,
                                  not is_record(Pattern, p_wildcard)],
            lists:foreach(fun({FieldName, FieldType}) ->
                              reply_field(Span, Name, FieldName, FieldType, Env1)
                          end, [Field || {FieldName, _} = Field <- lists:zip(Names, FieldTypes),
                                         not lists:member(FieldName, Bound)]);
        _ -> ok
    end.

%% The constructor's field types at the pattern's type, which unify, since
%% the pattern was checked as this constructor.
field_types(Scheme, Type, Env) ->
    {ConstructorType, TypeState1} = ern_types:instantiate(Scheme, ern_typecheck:type_state(Env)),
    {FieldTypes, ResultType} = case ConstructorType of
                                   {tfn, ParamTypes, _, Result} -> {ParamTypes, Result};
                                   Result -> {[], Result}
                               end,
    {ok, TypeState2} = ern_types:unify(ResultType, Type, TypeState1),
    {FieldTypes, ern_typecheck:set_type_state(TypeState2, Env)}.

wild_field(Span, Name, [FieldType], Env) ->
    not ern_typecheck:is_reply_carrying(FieldType, Env)
        orelse throw({type_error, Span, "the field of " ++ atom_to_list(Name)
                                        ++ " carries a reply and cannot be `_`"});
wild_field(_, _, _, _) -> ok.

reply_field(Span, Name, FieldName, FieldType, Env) ->
    not ern_typecheck:is_reply_carrying(FieldType, Env)
        orelse throw({type_error, Span, "field " ++ atom_to_list(FieldName) ++ " of "
                                        ++ atom_to_list(Name) ++ " carries a reply and must be"
                                        " bound"}).

%%
%% Uses of linear variables, per path
%%

%% uses(Expr, Obligations, Env) -> [{Name, Span}], one entry per use on the
%% path; a variable twice in the list is an error raised where it happens.
uses(#e_var{span = Span, namespace = [], name = Name}, Obligations, _Env) ->
    case lists:member(Name, Obligations) of
        true ->
            [{Name, Span}];
        false ->
            not lists:member({lambda, Name}, Obligations)
                orelse throw({type_error, Span, "the lambda " ++ atom_to_list(Name)
                                                ++ " captures a reply-carrying value and may only"
                                                " be called or passed directly to spawn or"
                                                " spawnMonitored"}),
            []
    end;
uses(#e_call{span = Span, returns = false} = Call, Obligations, Env) ->
    sequence([uses(Call#e_call{returns = true}, Obligations, Env), [{'$fault', Span}]]);
uses(#e_call{callee = #e_var{referent = {prelude, [Spawn]}}, args = [Arg | WrapArgs]},
     Obligations, Env)
  when Spawn =:= spawn, WrapArgs =:= []; Spawn =:= spawnMonitored, length(WrapArgs) =:= 1 ->
    %% spawn and spawnMonitored are the prelude's as the checker resolved
    %% them, not names spelled so
    ArgUses = spawned(Arg, Obligations, Env),
    sequence([ArgUses | [uses(WrapArg, Obligations, Env) || WrapArg <- WrapArgs]]);
uses(#e_call{span = Span, callee = #e_var{namespace = [], name = LambdaName}, args = Args},
     Obligations, Env) ->
    %% a call consumes a capturing lambda bound by let
    Callee = case lists:member({lambda, LambdaName}, Obligations) of
                 true -> [{LambdaName, Span}];
                 false -> []
             end,
    sequence([Callee, uses(Args, Obligations, Env)]);
uses(#e_call{callee = #e_lambda{} = Lambda, args = Args}, Obligations, Env) ->
    %% a call consumes the lambda's captures
    sequence([captures(Lambda, Obligations, Env), uses(Args, Obligations, Env)]);
uses(#e_lambda{span = Span} = Lambda, Obligations, Env) ->
    case captures(Lambda, Obligations, Env) of
        [] -> [];
        [{Name, _} | _] ->
            throw({type_error, Span, "the reply-carrying value " ++ atom_to_list(Name)
                                     ++ " is captured by a lambda that is not called, bound by"
                                     " `let`, or passed directly to spawn or spawnMonitored"})
    end;
uses(#fn_declaration{span = Span, body = Body}, Obligations, Env) ->
    case [Name || {Name, _} <- uses(Body, Obligations, Env), Name =/= '$fault'] of
        [] -> [];
        [Name | _] ->
            throw({type_error,
                   #diagnostic{span = ern_diagnostic:span(Span),
                               message = "the reply-carrying value " ++ atom_to_list(Name)
                                         ++ " is captured by a local function",
                               help = "a local fn may be called many times; pass "
                                      ++ atom_to_list(Name) ++ " to it as a parameter"}})
    end;
uses(#e_if{span = Span, condition = Condition, then_branch = Then, else_branch = Else},
     Obligations, Env) ->
    sequence([uses(Condition, Obligations, Env),
              branches(Span, [{ern_ast:span(Then), uses(Then, Obligations, Env)},
                              {ern_ast:span(Else), uses(Else, Obligations, Env)}])]);
uses(#e_match{span = Span, scrutinee = Scrutinee, clauses = Clauses}, Obligations, Env) ->
    sequence([uses(Scrutinee, Obligations, Env),
              branches(Span, [{ern_ast:span(Body), clause_uses(Clause, Obligations, Env)}
                              || #clause{body = Body} = Clause <- Clauses])]);
uses(#e_receive{span = Span, clauses = Clauses, 'after' = After}, Obligations, Env) ->
    AfterUses = case After of
                    undefined -> [];
                    #after_clause{timeout = Timeout, body = Body} ->
                        [{ern_ast:span(Body),
                          sequence([uses(Timeout, Obligations, Env),
                                    uses(Body, Obligations, Env)])}]
                end,
    branches(Span, [{ern_ast:span(Body), clause_uses(Clause, Obligations, Env)}
                    || #clause{body = Body} = Clause <- Clauses] ++ AfterUses);
uses(#e_block{statements = Statements}, Obligations, Env) ->
    block_uses(Statements, Obligations, Env, []);
uses(Node, Obligations, Env) when is_tuple(Node) ->
    sequence([uses(Child, Obligations, Env) || Child <- tl(tuple_to_list(Node))]);
uses(Nodes, Obligations, Env) when is_list(Nodes) ->
    sequence([uses(Child, Obligations, Env) || Child <- Nodes]);
uses(_, _, _) ->
    [].

%% Report §6.6: the function spawn and spawnMonitored take consumes a
%% capturing lambda, written there or bound by `let`.
spawned(#e_lambda{} = Lambda, Obligations, Env) ->
    captures(Lambda, Obligations, Env);
spawned(#e_var{span = Span, namespace = [], name = Name} = Arg, Obligations, Env) ->
    case lists:member({lambda, Name}, Obligations) of
        true -> [{Name, Span}];
        false -> uses(Arg, Obligations, Env)
    end;
spawned(Arg, Obligations, Env) ->
    uses(Arg, Obligations, Env).

clause_uses(#clause{span = Span, pattern = Pattern, guard = Guard, body = Body},
            Obligations, Env) ->
    Inner = obligations_bound(Pattern, Env),
    GuardUses = case Guard of undefined -> []; _ -> uses(Guard, Obligations ++ Inner, Env) end,
    All = sequence([GuardUses, uses(Body, Obligations ++ Inner, Env)]),
    lists:foreach(fun(Name) -> exactly_once(Name, All, Span) end, Inner),
    [Use || {Name, _} = Use <- All, not lists:member(Name, Inner)].

block_uses([], _Obligations, _Env, Acc) ->
    sequence(lists:reverse(Acc));
block_uses([#binding{span = Span, pattern = #p_var{name = LambdaName},
                     expr = #e_lambda{} = Lambda} = Binding | Rest],
           Obligations, Env, Acc) ->
    %% a let bound to a capturing lambda is a linear binding of the lambda
    case captures(Lambda, Obligations, Env) of
        [] ->
            binding_uses(Binding, Rest, Obligations, Env, Acc);
        Captures ->
            RestUses = block_uses(Rest, [{lambda, LambdaName} | Obligations], Env, []),
            exactly_once(LambdaName, RestUses, Span),
            Outer = [Use || {Name, _} = Use <- RestUses, Name =/= LambdaName],
            sequence(lists:reverse([Outer, Captures | Acc]))
    end;
block_uses([#binding{} = Binding | Rest], Obligations, Env, Acc) ->
    binding_uses(Binding, Rest, Obligations, Env, Acc);
block_uses([Statement | Rest], Obligations, Env, Acc) ->
    block_uses(Rest, Obligations, Env, [uses(Statement, Obligations, Env) | Acc]).

%% A `let`: each linear name its pattern binds is consumed once by the rest
%% of the block.
binding_uses(#binding{span = Span, pattern = Pattern, expr = Expr}, Rest, Obligations, Env, Acc) ->
    ExprUses = uses(Expr, Obligations, Env),
    Inner = obligations_bound(Pattern, Env),
    RestUses = block_uses(Rest, Obligations ++ Inner, Env, []),
    lists:foreach(fun(Name) -> exactly_once(Name, RestUses, Span) end, Inner),
    Outer = [Use || {Name, _} = Use <- RestUses, not lists:member(Name, Inner)],
    sequence(lists:reverse([Outer, ExprUses | Acc])).

%% The uses a lambda's body makes of the enclosing linear names: its
%% captures, each consumed once by the capture. The lambda's own linear
%% parameters are checked here.
captures(#e_lambda{span = Span, params = Params, body = Body}, Obligations, Env) ->
    Inner = [Name || Param <- Params, Name <- obligations_bound(Param#param.pattern, Env)],
    BodyUses = uses(Body, Obligations ++ Inner, Env),
    lists:foreach(fun(Name) -> exactly_once(Name, BodyUses, Span) end, Inner),
    [Use || {Name, _} = Use <- BodyUses, not lists:member(Name, Inner), Name =/= '$fault'].

%% Sequential composition: a second use of a name is an error there.
sequence(Lists) ->
    lists:foldl(fun(Uses, Acc) ->
                    lists:foreach(fun(Use) -> check_first_use(Use, Acc) end, Uses),
                    Acc ++ Uses
                end, [], Lists).

%% Report §11.5: a second use is reported where it stands, the first
%% labelled.
check_first_use({'$fault', _}, _Earlier) ->
    ok;
check_first_use({Name, Span}, Earlier) ->
    case lists:keyfind(Name, 1, Earlier) of
        {Name, First} ->
            throw({type_error,
                   #diagnostic{span = ern_diagnostic:span(Span),
                               message = "the reply-carrying value " ++ atom_to_list(Name)
                                         ++ " is consumed twice",
                               labels = [{ern_diagnostic:span(First), "first consumed here"}]}});
        false ->
            ok
    end.

%% Branches, each its path's span and its uses, consume the same names. A
%% path that faults consumes every obligation (§6.6) and is left out of the
%% comparison; where every path faults, the whole faults.
branches(Span, Branches) ->
    case [Branch || {_, BranchUses} = Branch <- Branches,
                    not lists:keymember('$fault', 1, BranchUses)] of
        [] when Branches =/= [] -> [{'$fault', Span}];
        Returning -> compared(Returning)
    end.

compared([]) ->
    [];
compared([{_, First} | _] = Branches) ->
    Names = lists:usort([Name || {_, BranchUses} <- Branches, {Name, _} <- BranchUses]),
    lists:foreach(fun(Name) -> check_every_path(Name, Branches) end, Names),
    First.

%% Report §11.5: a path that lacks a use is reported where it stands, the
%% use on another path labelled.
check_every_path(Name, Branches) ->
    case [Span || {Span, BranchUses} <- Branches, not lists:keymember(Name, 1, BranchUses)] of
        [] ->
            ok;
        [Lacking | _] ->
            [Used | _] = [UseSpan || {_, BranchUses} <- Branches,
                                     {UsedName, UseSpan} <- BranchUses, UsedName =:= Name],
            throw({type_error,
                   #diagnostic{span = ern_diagnostic:span(Lacking),
                               message = "the reply-carrying value " ++ atom_to_list(Name)
                                         ++ " is not consumed on this path",
                               labels = [{ern_diagnostic:span(Used),
                                          "consumed here, on another path"}]}})
    end.

%% Report §6.6: a name is consumed once on its path, or on none where the
%% path faults; a second use is sequence/1's to report.
exactly_once(Name, Uses, Span) ->
    case {count(Name, Uses), lists:keymember('$fault', 1, Uses)} of
        {0, false} ->
            throw({type_error, Span, "the reply-carrying value " ++ atom_to_list(Name)
                                     ++ " is never consumed"});
        _ ->
            ok
    end.

count(Name, Uses) -> length([x || {UsedName, _} <- Uses, UsedName =:= Name]).

%% Variables a pattern binds to reply-carrying values.
obligations_bound(Pattern, Env) ->
    [Name || {Name, Type} <- ern_ast:pattern_bindings(Pattern),
             ern_typecheck:is_reply_carrying(Type, Env)].

walk(Visit, Node) ->
    ern_ast:walk(fun(Child, ok) -> Visit(Child), ok end, Node, ok).
