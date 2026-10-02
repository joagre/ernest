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
%% {'$fault', Span}, which no name is, so a branch that faults is left out of
%% the comparison of branches,
%% and a name a faulting path leaves unconsumed is not a name never
%% consumed. The mark does not leave a lambda or a local function, whose
%% bodies are not on the enclosing path.
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
check(Params, Body, FunctionType, Env) ->
    discipline(Params, Body, Env),
    TypeState = ern_typecheck:type_state(Env),
    Variables = lists:usort(param_variables(FunctionType, TypeState)),
    lists:foldl(fun(Variable, Acc) ->
                    case holds(Params, Body,
                               ern_typecheck:assume_reply_carrying([Variable], Acc)) of
                        true -> Acc;
                        false ->
                            ern_typecheck:set_type_state(
                              ern_types:add_restriction(Variable, not_reply_carrying,
                                                        ern_typecheck:type_state(Acc)), Acc)
                    end
                end, Env, Variables).

%% The whole discipline over one function: its illegal positions, and each
%% linear parameter consumed exactly once.
discipline(Params, Body, Env) ->
    positions(Params, Env),
    positions(Body, Env),
    Obligations = [Name || Param <- Params, Name <- obligations_bound(Param#param.pattern, Env)],
    Uses = uses(Body, Obligations, Env),
    lists:foreach(fun(Name) -> exactly_once(Name, Uses, element(2, Body)) end, Obligations).

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
%% function type's effect.
param_variables(FunctionType, TypeState) ->
    case ern_types:resolve(FunctionType, TypeState) of
        {tfn, ParamTypes, _, _} ->
            lists:append([value_variables(Type, TypeState) || Type <- ParamTypes]);
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
    case ern_typecheck:is_reply_carrying(Type, Env) of
        true -> throw({type_error, Span, "`_` would discard a reply-carrying value"});
        false -> ok
    end;
position(#p_as{span = Span, type = Type}, Env) ->
    case ern_typecheck:is_reply_carrying(Type, Env) of
        true -> throw({type_error, Span, "`as` on a reply-carrying value would duplicate it"});
        false -> ok
    end;
position(#p_constructor{span = Span, path = Path, name = Name, args = Args, type = Type}, Env) ->
    case ern_typecheck:is_reply_carrying(Type, Env) of
        false -> ok;
        true ->
            #constructor_info{fields = Fields, scheme = Scheme} =
                ern_typecheck:lookup_constructor(Span, Path, Name, Env),
            %% instantiate the constructor at the pattern's type to see the
            %% field types as they are here
            TypeState = ern_typecheck:type_state(Env),
            {ConstructorType, TypeState1} = ern_types:instantiate(Scheme, TypeState),
            {FieldTypes, ResultType} = case ConstructorType of
                                           {tfn, ParamTypes, _, Result} -> {ParamTypes, Result};
                                           Result -> {[], Result}
                                       end,
            %% the pattern was checked as this constructor, so this unifies
            {ok, TypeState2} = ern_types:unify(ResultType, Type, TypeState1),
            Env1 = ern_typecheck:set_type_state(TypeState2, Env),
            case {Fields, Args} of
                {positional, {positional, #p_wildcard{}}} ->
                    wild_field(Span, Name, FieldTypes, Env1);
                {{named, Names}, {named, FieldPatterns}} ->
                    lists:foreach(
                      fun({FieldName, FieldType}) ->
                              case [Pattern
                                    || #field_pattern{name = PatternField, pattern = Pattern}
                                           <- FieldPatterns,
                                       PatternField =:= FieldName] of
                                  [#p_wildcard{}] ->
                                      reply_field(Span, Name, FieldName, FieldType, Env1);
                                  [] -> reply_field(Span, Name, FieldName, FieldType, Env1);
                                  _ -> ok
                              end
                      end, lists:zip(Names, FieldTypes));
                _ -> ok
            end
    end;
position(_, _) -> ok.

wild_field(Span, Name, [FieldType], Env) ->
    case ern_typecheck:is_reply_carrying(FieldType, Env) of
        true -> throw({type_error, Span, "the field of " ++ atom_to_list(Name)
                                         ++ " carries a reply and cannot be `_`"});
        false -> ok
    end;
wild_field(_, _, _, _) -> ok.

reply_field(Span, Name, Field, FieldType, Env) ->
    case ern_typecheck:is_reply_carrying(FieldType, Env) of
        true -> throw({type_error, Span, "field " ++ atom_to_list(Field) ++ " of "
                                         ++ atom_to_list(Name) ++ " carries a reply and must be"
                                         " bound"});
        false -> ok
    end.

%%
%% Uses of linear variables, per path
%%

%% uses(Expr, Obligations, Env) -> [Name], one entry per use on the path; a
%% variable twice in the list is an error raised where it happens.
uses(#e_var{span = Span, path = [], name = Name}, Obligations, _Env) ->
    case lists:member(Name, Obligations) of
        true -> [{Name, Span}];
        false ->
            case lists:member({lambda, Name}, Obligations) of
                true -> throw({type_error, Span, "the lambda " ++ atom_to_list(Name)
                                                 ++ " captures a reply-carrying value and may only"
                                                 " be called or passed directly to spawn or"
                                                 " spawnMonitored"});
                false -> []
            end
    end;
uses(#e_call{span = Span, returns = false} = Call, Obligations, Env) ->
    sequence([uses(Call#e_call{returns = true}, Obligations, Env), [{'$fault', Span}]]);
uses(#e_call{callee = #e_var{ref = {prelude, [Spawn]}}, args = [Arg | Wrap]}, Obligations, Env)
  when Spawn =:= spawn, Wrap =:= []; Spawn =:= spawnMonitored, length(Wrap) =:= 1 ->
    %% report §6.6: the function argument of spawn or spawnMonitored
    %% consumes a capturing lambda; each is the prelude's as the checker
    %% resolved it, not a name spelled so
    ArgUses = case Arg of
                  #e_lambda{} -> captures(Arg, Obligations, Env);
                  #e_var{span = Span, path = [], name = LambdaName} ->
                      case lists:member({lambda, LambdaName}, Obligations) of
                          true -> [{LambdaName, Span}];
                          false -> uses(Arg, Obligations, Env)
                      end;
                  _ -> uses(Arg, Obligations, Env)
              end,
    sequence([ArgUses | [uses(WrapArg, Obligations, Env) || WrapArg <- Wrap]]);
uses(#e_call{span = Span, callee = #e_var{path = [], name = LambdaName}, args = Args},
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
              branches(Span, [{element(2, Then), uses(Then, Obligations, Env)},
                              {element(2, Else), uses(Else, Obligations, Env)}])]);
uses(#e_match{span = Span, scrutinee = Scrutinee, clauses = Clauses}, Obligations, Env) ->
    sequence([uses(Scrutinee, Obligations, Env),
              branches(Span, [{element(2, Body), clause_uses(Clause, Obligations, Env)}
                              || #clause{body = Body} = Clause <- Clauses])]);
uses(#e_receive{span = Span, clauses = Clauses, 'after' = After}, Obligations, Env) ->
    AfterUses = case After of
                    undefined -> [];
                    #after_clause{timeout = Timeout, body = Body} ->
                        [{element(2, Body),
                          sequence([uses(Timeout, Obligations, Env),
                                    uses(Body, Obligations, Env)])}]
                end,
    branches(Span, [{element(2, Body), clause_uses(Clause, Obligations, Env)}
                    || #clause{body = Body} = Clause <- Clauses] ++ AfterUses);
uses(#e_block{statements = Statements}, Obligations, Env) ->
    block_uses(Statements, Obligations, Env, []);
uses(Node, Obligations, Env) when is_tuple(Node) ->
    sequence([uses(Child, Obligations, Env) || Child <- tl(tuple_to_list(Node))]);
uses(Nodes, Obligations, Env) when is_list(Nodes) ->
    sequence([uses(Child, Obligations, Env) || Child <- Nodes]);
uses(_, _, _) ->
    [].

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
                    lists:foreach(fun({'$fault', _}) ->
                                      ok;
                                     ({Name, Span}) ->
                                      %% report §11.5: at the second use,
                                      %% the first labelled
                                      case lists:keyfind(Name, 1, Acc) of
                                          {Name, First} ->
                                              throw({type_error,
                                                     #diagnostic{span = ern_diagnostic:span(Span),
                                                                 message = "the reply-carrying"
                                                                           " value "
                                                                           ++ atom_to_list(Name)
                                                                           ++ " is consumed twice",
                                                                 labels =
                                                                     [{ern_diagnostic:span(First),
                                                                       "first consumed here"}]}});
                                          false -> ok
                                      end
                                  end, Uses),
                    Acc ++ Uses
                end, [], Lists).

%% Branches must consume the same names, but for a branch that faults.
%% Where every branch faults, the whole faults.
%% Branches: each path's span and its uses. A path that faults consumes
%% every obligation (§6.6), and the others must agree; report §11.5: one
%% that lacks a use is reported where it stands, the use on another path
%% labelled.
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
    lists:foreach(fun(Name) ->
                      case [Span || {Span, BranchUses} <- Branches,
                                    not lists:keymember(Name, 1, BranchUses)] of
                          [] ->
                              ok;
                          [Lacking | _] ->
                              [Used | _] = [UseSpan || {_, BranchUses} <- Branches,
                                                       {UsedName, UseSpan} <- BranchUses,
                                                       UsedName =:= Name],
                              throw({type_error,
                                     #diagnostic{span = ern_diagnostic:span(Lacking),
                                                 message = "the reply-carrying value "
                                                           ++ atom_to_list(Name)
                                                           ++ " is not consumed on this path",
                                                 labels = [{ern_diagnostic:span(Used),
                                                            "consumed here, on another path"}]}})
                      end
                  end, Names),
    First.

exactly_once(Name, Uses, Span) ->
    case {count(Name, Uses), lists:keymember('$fault', 1, Uses)} of
        {1, _} -> ok;
        {0, true} -> ok;
        {0, false} -> throw({type_error, Span, "the reply-carrying value " ++ atom_to_list(Name)
                                     ++ " is never consumed"});
        {_, _} -> ok  % the second use was reported by seq
    end.

count(Name, Uses) -> length([x || {UsedName, _} <- Uses, UsedName =:= Name]).

%% Variables a pattern binds to reply-carrying values.
obligations_bound(Pattern, Env) ->
    [Name || {Name, Type} <- ern_ast:pattern_bindings(Pattern),
          ern_typecheck:is_reply_carrying(Type, Env)].

walk(Visit, Node) ->
    ern_ast:walk(fun(Child, ok) -> Visit(Child), ok end, Node, ok).
