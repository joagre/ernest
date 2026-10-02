%% Type terms, substitution, unification, generalization, instantiation,
%% and printing. See include/ern_types.hrl for the term shapes. All state
%% is in #type_state{} and threaded; nothing is mutated.
-module(ern_types).

-export([new/0, fresh/1, fresh/2, fresh_named/2, fresh_effect/1, restrictions/2,
         add_restriction/3, enter/1, leave/1,
         resolve/2, substitute/2, unify/3, free_variables/2,
         monomorphic/1, generalize/2, generalize/3, instantiate/2, replace_variables/2,
         mismatch_pair/3, format/2, value_variables/2, value_args/3, effect_variables/1,
         set_scope/4, set_effect_params/2,
         format_scheme/2, format_call/4, format_error/1]).

-export_type([type_state/0, type/0, effect/0, qualified_name/0, id/0, restrictions/0]).

-include_lib("typer/include/ern_types.hrl").

-type id() :: pos_integer().
-type qualified_name() :: [atom()].
-type restriction() :: equality | process_only | not_reply_carrying.
-type restrictions() :: [restriction()].
-type effect() :: pure | type().
-type type() :: {tvar, id()} | {tcon, qualified_name(), [type()]} | {ttuple, [type()]}
              | {tfn, [type()], effect(), type()}.

-record(type_state, {next = 1, level = 0, substitution = #{}, variables = #{}, namespace = [],
                     session = [], shadows = [], effect_params = #{}}).
%% namespace, session, shadows: the module being checked, whose types print
%% unqualified; the session's types that print so too, each the latest
%% declaration of its name (report §11.2); and the module's type names that
%% shadow prelude names, which print qualified (report §11.5)
%% effect_params: for each type with a parameter that is no value position
%% (report §3.9), whether each of its arguments is one
-opaque type_state() :: #type_state{}.

%%
%% State and variables
%%

-spec new() -> type_state().
new() -> #type_state{}.

-spec fresh(type_state()) -> {type(), type_state()}.
fresh(TypeState) -> fresh(TypeState, []).

-spec fresh(type_state(), restrictions()) -> {type(), type_state()}.
fresh(#type_state{next = Id, level = Level, variables = Variables} = TypeState, Restrictions) ->
    Variable = #type_variable{id = Id, level = Level, restrictions = Restrictions},
    {{tvar, Id}, TypeState#type_state{next = Id + 1, variables = Variables#{Id => Variable}}}.

%% A variable an annotation names (report §3.9, §11.5).
-spec fresh_named(atom(), type_state()) -> {type(), type_state()}.
fresh_named(Name, TypeState) ->
    {{tvar, Id} = Type, #type_state{variables = Variables} = TypeState1} = fresh(TypeState),
    Variable = maps:get(Id, Variables),
    Named = Variable#type_variable{name = Name},
    {Type, TypeState1#type_state{variables = Variables#{Id => Named}}}.

%% An effect variable for a function whose effect is inferred.
-spec fresh_effect(type_state()) -> {type(), type_state()}.
fresh_effect(TypeState) -> fresh(TypeState, []).

-spec restrictions(id(), type_state()) -> restrictions().
restrictions(Id, #type_state{variables = Variables}) ->
    (maps:get(Id, Variables))#type_variable.restrictions.

-spec add_restriction(type(), restriction(), type_state()) -> type_state().
add_restriction(Type, Restriction, TypeState) ->
    case resolve(Type, TypeState) of
        {tvar, Id} ->
            #type_state{variables = Variables} = TypeState,
            #type_variable{restrictions = Restrictions} = Variable = maps:get(Id, Variables),
            Restricted = Variable#type_variable{restrictions =
                                                    lists:usort([Restriction | Restrictions])},
            TypeState#type_state{variables = Variables#{Id => Restricted}};
        _ ->
            TypeState
    end.

-spec enter(type_state()) -> type_state().
enter(#type_state{level = Level} = TypeState) -> TypeState#type_state{level = Level + 1}.

-spec leave(type_state()) -> type_state().
leave(#type_state{level = Level} = TypeState) -> TypeState#type_state{level = Level - 1}.

%%
%% Substitution
%%

%% Follow bindings at the root only.
-spec resolve(type() | pure, type_state()) -> type() | pure.
resolve({tvar, Id} = Type, #type_state{substitution = Substitution} = TypeState) ->
    case Substitution of
        #{Id := Bound} -> resolve(Bound, TypeState);
        _ -> Type
    end;
resolve(Type, _TypeState) ->
    Type.

%% Follow bindings everywhere: the type with the substitution applied.
-spec substitute(type() | pure, type_state()) -> type() | pure.
substitute(Type, TypeState) ->
    case resolve(Type, TypeState) of
        {tcon, QualifiedName, Args} ->
            {tcon, QualifiedName, [substitute(Arg, TypeState) || Arg <- Args]};
        {ttuple, Elements} ->
            {ttuple, [substitute(Element, TypeState) || Element <- Elements]};
        {tfn, Params, Effect, Result} ->
            {tfn, [substitute(Param, TypeState) || Param <- Params],
             substitute(Effect, TypeState), substitute(Result, TypeState)};
        Other ->
            Other
    end.

bind(Id, Type, #type_state{substitution = Substitution} = TypeState) ->
    TypeState#type_state{substitution = Substitution#{Id => Type}}.

%%
%% Unification
%%

%% Expected is the expected type and Actual the actual one; which is which
%% decides between pure_where_process_needed and process_where_pure_needed.
%% A function's parameters are unified the other way round, since there the
%% actual function is the one handed a value.
-spec unify(type() | pure, type() | pure, type_state()) -> {ok, type_state()} | {error, term()}.
unify(Expected, Actual, TypeState) ->
    try
        {ok, unify_resolved(resolve(Expected, TypeState), resolve(Actual, TypeState), TypeState)}
    catch
        throw:{unify_error, Reason} -> {error, Reason}
    end.

unify_resolved(Type, Type, TypeState) ->
    TypeState;
unify_resolved({tvar, Id} = Variable, Type, TypeState) ->
    bind_variable(Id, Variable, Type, pure_where_process_needed, TypeState);
unify_resolved(Type, {tvar, Id} = Variable, TypeState) ->
    bind_variable(Id, Variable, Type, process_where_pure_needed, TypeState);
unify_resolved({tcon, QualifiedName, ExpectedArgs}, {tcon, QualifiedName, ActualArgs}, TypeState)
  when length(ExpectedArgs) =:= length(ActualArgs) ->
    unify_list(ExpectedArgs, ActualArgs, TypeState);
unify_resolved({ttuple, ExpectedElements}, {ttuple, ActualElements}, TypeState)
  when length(ExpectedElements) =:= length(ActualElements) ->
    unify_list(ExpectedElements, ActualElements, TypeState);
unify_resolved({tfn, ExpectedParams, ExpectedEffect, ExpectedResult},
               {tfn, ActualParams, ActualEffect, ActualResult}, TypeState) ->
    case length(ExpectedParams) =:= length(ActualParams) of
        true ->
            TypeState1 = unify_list(ActualParams, ExpectedParams, TypeState),
            TypeState2 = unify_resolved(resolve(ExpectedEffect, TypeState1),
                                        resolve(ActualEffect, TypeState1), TypeState1),
            unify_resolved(resolve(ExpectedResult, TypeState2),
                           resolve(ActualResult, TypeState2), TypeState2);
        false ->
            throw({unify_error, {arity, length(ExpectedParams), length(ActualParams)}})
    end;
unify_resolved(pure, Type, _TypeState) ->
    throw({unify_error, {pure_vs_effect, Type}});
unify_resolved(Type, pure, _TypeState) ->
    throw({unify_error, {pure_vs_effect, Type}});
unify_resolved(Expected, Actual, _TypeState) ->
    throw({unify_error, {mismatch, Expected, Actual}}).

unify_list([], [], TypeState) ->
    TypeState;
unify_list([Expected | ExpectedRest], [Actual | ActualRest], TypeState) ->
    TypeState1 = unify_resolved(resolve(Expected, TypeState), resolve(Actual, TypeState),
                                TypeState),
    unify_list(ExpectedRest, ActualRest, TypeState1).

%% Binding a variable: the occurs check, the restrictions' rules, level
%% adjustment. Pure against a process-only variable fails with Reason,
%% which says on which side of the unification, the expected or the actual,
%% pure stood.
bind_variable(Id, _Variable, pure, Reason, TypeState) ->
    case lists:member(process_only, restrictions(Id, TypeState)) of
        true -> throw({unify_error, Reason});
        false -> bind(Id, pure, TypeState)
    end;
bind_variable(Id, _Variable, {tvar, SurvivorId}, _Reason, TypeState) ->
    %% two variables: merge the restrictions into the survivor, keep the
    %% lower level and the annotation's name, if only the bound one has it
    %% (§11.5)
    #type_state{variables = Variables} = TypeState,
    #type_variable{level = Level, restrictions = Restrictions, name = Name} =
        maps:get(Id, Variables),
    #type_variable{level = SurvivorLevel, restrictions = SurvivorRestrictions,
                   name = SurvivorName} = Survivor = maps:get(SurvivorId, Variables),
    KeptName = case SurvivorName of undefined -> Name; _ -> SurvivorName end,
    Merged = Survivor#type_variable{level = min(Level, SurvivorLevel),
                                    restrictions = lists:usort(Restrictions
                                                               ++ SurvivorRestrictions),
                                    name = KeptName},
    TypeState1 = TypeState#type_state{variables = Variables#{SurvivorId => Merged}},
    bind(Id, {tvar, SurvivorId}, TypeState1);
bind_variable(Id, Variable, Type, _Reason, TypeState) ->
    case occurs(Id, Type, TypeState) of
        true -> throw({unify_error, {occurs, Variable, Type}});
        false ->
            TypeState1 = adjust_levels(Id, Type, TypeState),
            bind(Id, Type, pass_equality(Id, Type, TypeState1))
    end.

%% Report §3.10: a variable with the equality restriction passes it to the
%% variables in value positions of the type it is bound to, so that what
%% they are bound to later is compared as the variable's own binding is. A
%% regression: `eq([x], [x])` left `x` free to be a function.
pass_equality(Id, Type, TypeState) ->
    case lists:member(equality, restrictions(Id, TypeState)) of
        true ->
            lists:foldl(fun(ValueId, Acc) -> add_restriction({tvar, ValueId}, equality, Acc) end,
                        TypeState, value_variables(substitute(Type, TypeState), TypeState));
        false ->
            TypeState
    end.

occurs(Id, Type, TypeState) ->
    case resolve(Type, TypeState) of
        {tvar, Id} -> true;
        {tvar, _} -> false;
        {tcon, _, Args} -> lists:any(fun(Arg) -> occurs(Id, Arg, TypeState) end, Args);
        {ttuple, Elements} ->
            lists:any(fun(Element) -> occurs(Id, Element, TypeState) end, Elements);
        {tfn, Params, Effect, Result} ->
            lists:any(fun(Part) -> occurs(Id, Part, TypeState) end, [Effect, Result | Params]);
        pure -> false
    end.

%% Variables inside Type inherit the bound variable's level if lower, so
%% that generalization never quantifies a variable that escaped outward.
adjust_levels(Id, Type, #type_state{variables = Variables} = TypeState) ->
    #type_variable{level = Level} = maps:get(Id, Variables),
    Lower = fun(FreeId, #type_state{variables = Current} = Acc) ->
                #type_variable{level = FreeLevel} = Free = maps:get(FreeId, Current),
                case FreeLevel > Level of
                    true ->
                        Acc#type_state{variables =
                                           Current#{FreeId => Free#type_variable{level = Level}}};
                    false ->
                        Acc
                end
            end,
    lists:foldl(Lower, TypeState, free_variables(Type, TypeState)).

%% Free variable ids of a type, in order of first occurrence.
-spec free_variables(type() | pure, type_state()) -> [id()].
free_variables(Type, TypeState) ->
    lists:reverse(free_variables(Type, TypeState, [])).

free_variables(Type, TypeState, Acc) ->
    Free = fun(Part, PartAcc) -> free_variables(Part, TypeState, PartAcc) end,
    case resolve(Type, TypeState) of
        {tvar, Id} ->
            case lists:member(Id, Acc) of
                true -> Acc;
                false -> [Id | Acc]
            end;
        {tcon, _, Args} -> lists:foldl(Free, Acc, Args);
        {ttuple, Elements} -> lists:foldl(Free, Acc, Elements);
        {tfn, Params, Effect, Result} -> lists:foldl(Free, Acc, Params ++ [Effect, Result]);
        pure -> Acc
    end.

%%
%% Schemes
%%

-spec monomorphic(type()) -> #scheme{}.
monomorphic(Type) -> #scheme{quantified = [], type = Type}.

%% Quantify the variables of Type created at a deeper level than the
%% current one, carrying their restrictions. An effect variable that is
%% free, unrestricted, and occurs nowhere else is replaced by pure: the two
%% are equivalent for callers and pure prints better.
-spec generalize(type(), type_state()) -> {#scheme{}, type_state()}.
generalize(Type, TypeState) -> generalize(Type, [], TypeState).

-spec generalize(type(), [id()], type_state()) -> {#scheme{}, type_state()}.
generalize(Type, Keep, #type_state{level = Level, variables = Variables} = TypeState) ->
    Elided = elide_pure_effects(substitute(Type, TypeState), Keep, TypeState),
    Ids = [Id || Id <- free_variables(Elided, TypeState),
                 (maps:get(Id, Variables))#type_variable.level > Level
                     orelse lists:member(Id, Keep)],
    Names = maps:from_list([{Id, Name} || Id <- Ids,
                                          Name <- [(maps:get(Id, Variables))#type_variable.name],
                                          Name =/= undefined]),
    Quantified = [{Id, (maps:get(Id, Variables))#type_variable.restrictions} || Id <- Ids],
    {#scheme{quantified = Quantified, type = Elided, names = Names}, TypeState}.

elide_pure_effects(Type, Keep, TypeState) ->
    Counts = count_variables(Type, #{}),
    Effects = effect_positions(Type, []),
    Elide = [Id || Id <- Effects,
                   maps:get(Id, Counts) =:= 1,
                   not lists:member(process_only, restrictions(Id, TypeState)),
                   not lists:member(Id, Keep)],
    replace_effects(Type, Elide).

count_variables({tvar, Id}, Counts) -> maps:update_with(Id, fun(Count) -> Count + 1 end, 1, Counts);
count_variables({tcon, _, Args}, Counts) -> lists:foldl(fun count_variables/2, Counts, Args);
count_variables({ttuple, Elements}, Counts) -> lists:foldl(fun count_variables/2, Counts, Elements);
count_variables({tfn, Params, Effect, Result}, Counts) ->
    lists:foldl(fun count_variables/2, Counts, Params ++ [Effect, Result]);
count_variables(pure, Counts) -> Counts.

effect_positions({tfn, Params, Effect, Result}, Acc) ->
    Acc1 = case Effect of {tvar, Id} -> [Id | Acc]; _ -> Acc end,
    lists:foldl(fun effect_positions/2, Acc1, Params ++ [Result]);
effect_positions({tcon, _, Args}, Acc) -> lists:foldl(fun effect_positions/2, Acc, Args);
effect_positions({ttuple, Elements}, Acc) -> lists:foldl(fun effect_positions/2, Acc, Elements);
effect_positions(_, Acc) -> Acc.

replace_effects({tfn, Params, Effect, Result}, Elide) ->
    Kept = case Effect of
               {tvar, Id} ->
                   case lists:member(Id, Elide) of
                       true -> pure;
                       false -> Effect
                   end;
               _ -> Effect
           end,
    {tfn, [replace_effects(Param, Elide) || Param <- Params], Kept,
     replace_effects(Result, Elide)};
replace_effects({tcon, QualifiedName, Args}, Elide) ->
    {tcon, QualifiedName, [replace_effects(Arg, Elide) || Arg <- Args]};
replace_effects({ttuple, Elements}, Elide) ->
    {ttuple, [replace_effects(Element, Elide) || Element <- Elements]};
replace_effects(Type, _) ->
    Type.

%% Fresh variables for the quantified ones, restrictions copied.
-spec instantiate(#scheme{}, type_state()) -> {type(), type_state()}.
instantiate(#scheme{quantified = [], type = Type}, TypeState) ->
    {Type, TypeState};
%% An instance's variables carry no names: a name belongs to the
%% annotation that wrote it, not to a use of the value (report §11.5).
instantiate(#scheme{quantified = Quantified, type = Type}, TypeState) ->
    Fresh = fun({Id, Restrictions}, {Map, Acc}) ->
                {Variable, Acc1} = fresh(Acc, Restrictions),
                {Map#{Id => Variable}, Acc1}
            end,
    {Map, TypeState1} = lists:foldl(Fresh, {#{}, TypeState}, Quantified),
    {replace_variables(Type, Map), TypeState1}.

%% The type with each variable the map names replaced by its type.
-spec replace_variables(type() | pure, #{id() => type()}) -> type() | pure.
replace_variables({tvar, Id} = Variable, Map) ->
    maps:get(Id, Map, Variable);
replace_variables({tcon, QualifiedName, Args}, Map) ->
    {tcon, QualifiedName, [replace_variables(Arg, Map) || Arg <- Args]};
replace_variables({ttuple, Elements}, Map) ->
    {ttuple, [replace_variables(Element, Map) || Element <- Elements]};
replace_variables({tfn, Params, Effect, Result}, Map) ->
    {tfn, [replace_variables(Param, Map) || Param <- Params], replace_variables(Effect, Map),
     replace_variables(Result, Map)};
replace_variables(pure, _) ->
    pure.

%%
%% Printing, report §11.5. Variables are named a, b, c, ... in order of
%% appearance; a variable with the equality restriction prints as a=, one
%% that is process-only prints unchanged in effect position (its restriction
%% is stated in messages), one that is not-reply-carrying prints as a!.
%%

%% Report §11.5: the differing part of two types that do not unify, so a
%% message shows Int against String rather than two whole function types.
-spec mismatch_pair(type() | pure, type() | pure, type_state()) ->
          {type() | pure, type() | pure}.
mismatch_pair(Expected, Actual, TypeState) ->
    differing(substitute(Expected, TypeState), substitute(Actual, TypeState)).

differing({tcon, QualifiedName, ExpectedArgs}, {tcon, QualifiedName, ActualArgs})
  when length(ExpectedArgs) =:= length(ActualArgs) ->
    first_differing(ExpectedArgs, ActualArgs,
                    {{tcon, QualifiedName, ExpectedArgs}, {tcon, QualifiedName, ActualArgs}});
differing({ttuple, ExpectedElements}, {ttuple, ActualElements})
  when length(ExpectedElements) =:= length(ActualElements) ->
    first_differing(ExpectedElements, ActualElements,
                    {{ttuple, ExpectedElements}, {ttuple, ActualElements}});
differing({tfn, ExpectedParams, ExpectedEffect, ExpectedResult} = Expected,
          {tfn, ActualParams, ActualEffect, ActualResult} = Actual)
  when length(ExpectedParams) =:= length(ActualParams) ->
    first_differing(ExpectedParams ++ [ExpectedEffect, ExpectedResult],
                    ActualParams ++ [ActualEffect, ActualResult], {Expected, Actual});
differing(Expected, Actual) ->
    {Expected, Actual}.

first_differing(ExpectedParts, ActualParts, Whole) ->
    case [{Expected, Actual} || {Expected, Actual} <- lists:zip(ExpectedParts, ActualParts),
                                Expected =/= Actual] of
        [{Expected, Actual} | _] -> differing(Expected, Actual);
        [] -> Whole
    end.

-spec format(type() | pure, type_state()) -> string().
format(Type, TypeState) ->
    %% report §11.5: an effect variable that occurs once, and is not
    %% process-only, prints as pure
    Elided = elide_pure_effects(substitute(Type, TypeState), [], TypeState),
    EffectOnly = effect_only_variables(Elided, TypeState),
    {Text, _} = format_type(Elided, TypeState, #{effect_only => EffectOnly, values => 0,
                                                 effects => 0, taken => []}),
    lists:flatten(Text).

%% Variables that occur in no value position are named e, e1, ...: those
%% after `with`, and those only in a type argument that is no value
%% position, `H(e)`; the others a, b, c, d, f, ... (report §3.9 writes `e`
%% for effect variables).
effect_only_variables(Type, TypeState) ->
    free_variables(Type, TypeState) -- value_variables(Type, TypeState).

%% Variable ids in value positions / in effect positions of a substituted
%% type. Report §3.9: a type argument is a value position unless the state
%% says its parameter occurs in no value position of the type's fields.
-spec value_variables(type() | pure, type_state()) -> [id()].
value_variables(Type, #type_state{effect_params = EffectParams}) ->
    lists:usort(value_positions(Type, EffectParams, [])).

%% The arguments of a type in value positions, those whose parameter occurs
%% in a value position of the type's fields (report §3.9).
-spec value_args(qualified_name(), [type()], type_state()) -> [type()].
value_args(QualifiedName, Args, #type_state{effect_params = EffectParams}) ->
    case EffectParams of
        #{QualifiedName := IsValue} -> [Arg || {Arg, true} <- lists:zip(Args, IsValue)];
        _ -> Args
    end.

-spec effect_variables(type() | pure) -> [id()].
effect_variables(Type) -> lists:usort(effect_positions(Type, [])).

value_positions({tvar, Id}, _EffectParams, Acc) ->
    [Id | Acc];
value_positions({tcon, QualifiedName, Args}, EffectParams, Acc) ->
    Values = case EffectParams of
                 #{QualifiedName := IsValue} -> [Arg || {Arg, true} <- lists:zip(Args, IsValue)];
                 _ -> Args
             end,
    value_positions_list(Values, EffectParams, Acc);
value_positions({ttuple, Elements}, EffectParams, Acc) ->
    value_positions_list(Elements, EffectParams, Acc);
value_positions({tfn, Params, _Effect, Result}, EffectParams, Acc) ->
    value_positions_list(Params ++ [Result], EffectParams, Acc);
value_positions(pure, _EffectParams, Acc) ->
    Acc.

value_positions_list(Types, EffectParams, Acc) ->
    lists:foldl(fun(Type, TypeAcc) -> value_positions(Type, EffectParams, TypeAcc) end, Acc,
                Types).

%% The module being checked, the session's types, and the type names that
%% shadow prelude names, which print qualified (report §11.5).
-spec set_scope(type_state(), qualified_name(), [qualified_name()], [atom()]) -> type_state().
set_scope(TypeState, Namespace, Session, Shadows) ->
    TypeState#type_state{namespace = Namespace, session = Session, shadows = Shadows}.

%% Report §3.9: the types with a parameter that occurs in no value position
%% of their fields, each with whether each of its arguments is a value
%% position.
-spec set_effect_params(type_state(), #{qualified_name() => [boolean()]}) -> type_state().
set_effect_params(TypeState, EffectParams) ->
    TypeState#type_state{effect_params = EffectParams}.

%% Report §11.5: a type name as the module would write it.
type_name([Name], _TypeState) ->
    atom_to_list(Name);
type_name(QualifiedName, #type_state{namespace = Namespace, session = Session,
                                     shadows = Shadows}) ->
    Name = lists:last(QualifiedName),
    IsOwn = lists:droplast(QualifiedName) =:= Namespace orelse lists:member(QualifiedName, Session),
    case IsOwn andalso not lists:member(Name, Shadows) of
        true -> atom_to_list(Name);
        false -> qualified_name_text(QualifiedName)
    end.

%% The scheme's own restrictions apply, whatever state it is printed under.
-spec format_scheme(#scheme{}, type_state()) -> string().
format_scheme(#scheme{type = Type} = Scheme, TypeState) ->
    format(Type, scheme_state(Scheme, TypeState)).

%% The state with a scheme's variables named as its declaration names them.
%% They are the scheme's own, bound by it, so the state's substitution does
%% not reach them: a scheme another module or an earlier input declared
%% numbers its variables in a state of its own, where the same id may be
%% bound here to something else.
scheme_state(#scheme{quantified = Quantified, names = Names},
             #type_state{variables = Variables, substitution = Substitution} = TypeState) ->
    Declare = fun({Id, Restrictions}, Acc) ->
                  Variable = maps:get(Id, Acc, #type_variable{id = Id, level = 0}),
                  Acc#{Id => Variable#type_variable{restrictions = Restrictions,
                                                    name = maps:get(Id, Names, undefined)}}
              end,
    TypeState#type_state{variables = lists:foldl(Declare, Variables, Quantified),
                         substitution = maps:without([Id || {Id, _} <- Quantified], Substitution)}.

%% Report §11.2: a function's signature as `Shift-Tab` shows it inside a
%% call, each parameter under the name its declaration gives it, where it
%% gives one, and the variables named once across the whole: the text
%% before the parameter at the cursor, counted from 0, that parameter, and
%% the text after it, so that whoever paints it can mark the middle part.
%% Params are the declaration's parameters, `_` for a pattern, or none for
%% a function that has no declaration of its own, a value of a function
%% type.
-spec format_call(#scheme{}, [atom()] | none, non_neg_integer(), type_state()) ->
          {string(), string(), string()}.
format_call(#scheme{type = Type} = Scheme, Params, Marked, TypeState) ->
    SchemeState = scheme_state(Scheme, TypeState),
    case elide_pure_effects(substitute(Type, SchemeState), [], SchemeState) of
        {tfn, ParamTypes, Effect, Result} = Elided ->
            Names = #{effect_only => effect_only_variables(Elided, SchemeState), values => 0,
                      effects => 0, taken => []},
            {Shown, Names1} = lists:mapfoldl(fun(ParamType, Acc) ->
                                                 format_type(ParamType, SchemeState, Acc)
                                             end, Names, ParamTypes),
            Named = [parameter(Name, Text)
                     || {Name, Text} <- lists:zip(padded(Params, length(ParamTypes)), Shown)],
            {ResultText, Names2} = format_result(Result, SchemeState, Names1),
            EffectText = case Effect of
                             pure -> [];
                             _ -> [" with ", element(1, format_type(Effect, SchemeState, Names2))]
                         end,
            %% a declaration's head, whatever its parameters, writes its
            %% result after `:`; a function's type alone keeps its arrow
            %% (§4.5)
            Arrow = case Params of
                        none -> ") -> ";
                        _ -> ") : "
                    end,
            Tail = [Arrow, ResultText, EffectText],
            case Marked < length(Named) of
                true ->
                    {Left, [This | Right]} = lists:split(Marked, Named),
                    {lists:flatten(["(", [[Param, ", "] || Param <- Left]]), lists:flatten(This),
                     lists:flatten([[[", ", Param] || Param <- Right], Tail])};
                false ->
                    {lists:flatten(["(", lists:join(", ", Named), Tail]), "", ""}
            end;
        _ ->
            {format_scheme(Scheme, TypeState), "", ""}
    end.

parameter('_', Type) -> Type;
parameter(Name, Type) -> [atom_to_list(Name), " : ", Type].

padded(Params, Count) when is_list(Params), length(Params) =:= Count -> Params;
padded(_, Count) -> lists:duplicate(Count, '_').

%% Report §11.5: the annotation's name if the variable has one and it is
%% not in use for another, else a fresh name that is not in use.
format_type({tvar, Id}, TypeState, Names) ->
    case Names of
        #{Id := Name} -> {Name, Names};
        #{effect_only := EffectOnly, taken := Taken} ->
            {Base, Names1} = case annotated_name(Id, TypeState) of
                                 undefined -> fresh_name(Id, EffectOnly, Names);
                                 Given ->
                                     case lists:member(Given, Taken) of
                                         true -> fresh_name(Id, EffectOnly, Names);
                                         false -> {Given, Names}
                                     end
                             end,
            %% report §11.5: a process-only variable is marked where it
            %% occurs in no value position, since one that does is never pure
            Restrictions = known_restrictions(Id, TypeState),
            Marks = [$= || lists:member(equality, Restrictions)]
                 ++ [$! || lists:member(not_reply_carrying, Restrictions)]
                 ++ [$+ || lists:member(process_only, Restrictions), lists:member(Id, EffectOnly)],
            Name = Base ++ Marks,
            {Name, Names1#{Id => Name, taken => [Base | Taken]}}
    end;
format_type({tcon, QualifiedName, []}, TypeState, Names) ->
    {type_name(QualifiedName, TypeState), Names};
format_type({tcon, QualifiedName, Args}, TypeState, Names) ->
    {ArgsText, Names1} = format_list(Args, TypeState, Names),
    {[type_name(QualifiedName, TypeState), "(", ArgsText, ")"], Names1};
format_type({ttuple, Elements}, TypeState, Names) ->
    {ElementsText, Names1} = format_list(Elements, TypeState, Names),
    {["#(", ElementsText, ")"], Names1};
format_type({tfn, Params, Effect, Result}, TypeState, Names) ->
    {ParamsText, Names1} = format_list(Params, TypeState, Names),
    {ResultText, Names2} = format_result(Result, TypeState, Names1),
    case Effect of
        pure -> {["(", ParamsText, ") -> ", ResultText], Names2};
        _ ->
            {EffectText, Names3} = format_type(Effect, TypeState, Names2),
            {["(", ParamsText, ") -> ", ResultText, " with ", EffectText], Names3}
    end;
format_type(pure, _TypeState, Names) ->
    {"pure", Names}.

%% A function type in result position is parenthesized when it carries an
%% effect, so `with` reads as belonging to the outer arrow (report §3.4).
format_result({tfn, _, Effect, _} = Type, TypeState, Names) when Effect =/= pure ->
    {Text, Names1} = format_type(Type, TypeState, Names),
    {["(", Text, ")"], Names1};
format_result(Type, TypeState, Names) ->
    format_type(Type, TypeState, Names).

format_list(Types, TypeState, Names) ->
    {Texts, Names1} = lists:mapfoldl(fun(Type, Acc) -> format_type(Type, TypeState, Acc) end,
                                     Names, Types),
    {lists:join(", ", Texts), Names1}.

%% a, b, c, ... or e, e1, ..., skipping names in use.
fresh_name(Id, EffectOnly,
           #{values := ValueCount, effects := EffectCount, taken := Taken} = Names) ->
    case lists:member(Id, EffectOnly) of
        true ->
            case lists:member(effect_variable_name(EffectCount), Taken) of
                true -> fresh_name(Id, EffectOnly, Names#{effects => EffectCount + 1});
                false -> {effect_variable_name(EffectCount), Names#{effects => EffectCount + 1}}
            end;
        false ->
            case lists:member(value_variable_name(ValueCount), Taken) of
                true -> fresh_name(Id, EffectOnly, Names#{values => ValueCount + 1});
                false -> {value_variable_name(ValueCount), Names#{values => ValueCount + 1}}
            end
    end.

annotated_name(Id, #type_state{variables = Variables}) ->
    case Variables of
        #{Id := #type_variable{name = undefined}} -> undefined;
        #{Id := #type_variable{name = Name}} -> atom_to_list(Name);
        _ -> undefined
    end.

known_restrictions(Id, #type_state{variables = Variables}) ->
    case Variables of
        #{Id := #type_variable{restrictions = Restrictions}} -> Restrictions;
        _ -> []
    end.

%% a, b, c, d, f, ... skipping e.
value_variable_name(Count) ->
    Letters = "abcdfghijklmnopqrstuvwxyz",
    [lists:nth(Count rem 25 + 1, Letters)] ++ [integer_to_list(Count div 25) || Count >= 25].

effect_variable_name(0) -> "e";
effect_variable_name(Count) -> "e" ++ integer_to_list(Count).

qualified_name_text(QualifiedName) ->
    lists:join(".", [atom_to_list(Part) || Part <- QualifiedName]).

-spec format_error(term()) -> string().
format_error({arity, Count, OtherCount}) ->
    lists:flatten(io_lib:format("a function of ~B argument~s where one of ~B was expected",
                                [Count, plural(Count), OtherCount]));
format_error({pure_vs_effect, _}) ->
    "a pure function where a function with a mailbox effect was expected, or the reverse";
format_error(pure_where_process_needed) ->
    "a pure function where one that runs in a process is needed";
format_error(process_where_pure_needed) ->
    "a function that runs in a process where a pure one is needed";
format_error({occurs, _, _}) ->
    "a type that would contain itself";
format_error({mismatch, _, _}) ->
    "types do not match".

plural(1) -> "";
plural(_) -> "s".
