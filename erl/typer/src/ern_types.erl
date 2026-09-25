%% Type terms, substitution, unification, generalization, instantiation,
%% and printing. See include/ern_types.hrl for the term shapes. All state
%% is in #st{} and threaded; nothing is mutated.
-module(ern_types).

-export([new/0, fresh/1, fresh/2, fresh_named/2, fresh_effect/1, flags/2, add_flag/3,
         enter/1, leave/1,
         resolve/2, zonk/2, unify/3, free_vars/2,
         mono/1, generalize/2, generalize/3, instantiate/2,
         mismatch_pair/3, format/2, value_vars/2, effect_vars/1, set_scope/4,
         set_effect_params/2,
         format_scheme/2, format_call/4, format_error/1]).

-export_type([st/0, type/0, effect/0, qname/0, id/0, flags/0]).

-include_lib("typer/include/ern_types.hrl").

-type id() :: pos_integer().
-type qname() :: [atom()].
-type flags() :: [eq | process_only | no_reply].
-type effect() :: pure | type().
-type type() :: {tvar, id()} | {tcon, qname(), [type()]} | {ttuple, [type()]}
              | {tfn, [type()], effect(), type()}.

-record(st, {next = 1, level = 0, subst = #{}, vars = #{}, ns = [], session = [],
             shadows = [], effect_params = #{}}).
%% ns, session, shadows: the module being checked, whose types print
%% unqualified; the session's types that print so too, each the latest
%% declaration of its name (report §11.2); and the module's type names that
%% shadow prelude names, which print qualified (report §11.5)
%% effect_params: for each type with a parameter that is no value position
%% (report §3.9), whether each of its arguments is one
-opaque st() :: #st{}.

%%
%% State and variables
%%

-spec new() -> st().
new() -> #st{}.

-spec fresh(st()) -> {type(), st()}.
fresh(St) -> fresh(St, []).

-spec fresh(st(), flags()) -> {type(), st()}.
fresh(#st{next = Id, level = L, vars = Vs} = St, Flags) ->
    {{tvar, Id}, St#st{next = Id + 1, vars = Vs#{Id => #tv{id = Id, level = L, flags = Flags}}}}.

%% A variable an annotation names (report §3.9, §11.5).
-spec fresh_named(atom(), st()) -> {type(), st()}.
fresh_named(Name, St) ->
    {{tvar, Id} = V, #st{vars = Vs} = St1} = fresh(St),
    TV = maps:get(Id, Vs),
    {V, St1#st{vars = Vs#{Id => TV#tv{name = Name}}}}.

%% An effect variable for a function whose effect is inferred.
-spec fresh_effect(st()) -> {type(), st()}.
fresh_effect(St) -> fresh(St, []).

-spec flags(id(), st()) -> flags().
flags(Id, #st{vars = Vs}) -> (maps:get(Id, Vs))#tv.flags.

-spec add_flag(type(), eq | process_only | no_reply, st()) -> st().
add_flag(T, Flag, St) ->
    case resolve(T, St) of
        {tvar, Id} ->
            #st{vars = Vs} = St,
            #tv{flags = Fs} = TV = maps:get(Id, Vs),
            St#st{vars = Vs#{Id => TV#tv{flags = lists:usort([Flag | Fs])}}};
        _ ->
            St
    end.

-spec enter(st()) -> st().
enter(#st{level = L} = St) -> St#st{level = L + 1}.

-spec leave(st()) -> st().
leave(#st{level = L} = St) -> St#st{level = L - 1}.

%%
%% Substitution
%%

%% Follow bindings at the root only.
-spec resolve(type() | pure, st()) -> type() | pure.
resolve({tvar, Id} = T, #st{subst = S} = St) ->
    case S of
        #{Id := T1} -> resolve(T1, St);
        _ -> T
    end;
resolve(T, _St) ->
    T.

%% Follow bindings everywhere.
-spec zonk(type() | pure, st()) -> type() | pure.
zonk(T, St) ->
    case resolve(T, St) of
        {tcon, N, Args} -> {tcon, N, [zonk(A, St) || A <- Args]};
        {ttuple, Es} -> {ttuple, [zonk(E, St) || E <- Es]};
        {tfn, Ps, E, R} -> {tfn, [zonk(P, St) || P <- Ps], zonk(E, St), zonk(R, St)};
        Other -> Other
    end.

bind(Id, T, #st{subst = S} = St) ->
    St#st{subst = S#{Id => T}}.

%%
%% Unification
%%

%% A is the expected type and B the actual one; which is which decides
%% between pure_where_process_needed and process_where_pure_needed. A
%% function's parameters are unified the other way round, since there the
%% actual function is the one handed a value.
-spec unify(type() | pure, type() | pure, st()) -> {ok, st()} | {error, term()}.
unify(A, B, St) ->
    try
        {ok, unify_(resolve(A, St), resolve(B, St), St)}
    catch
        throw:{unify_error, Reason} -> {error, Reason}
    end.

unify_(T, T, St) ->
    St;
unify_({tvar, Id} = V, T, St) ->
    bind_var(Id, V, T, pure_where_process_needed, St);
unify_(T, {tvar, Id} = V, St) ->
    bind_var(Id, V, T, process_where_pure_needed, St);
unify_({tcon, N, As}, {tcon, N, Bs}, St) when length(As) =:= length(Bs) ->
    unify_list(As, Bs, St);
unify_({ttuple, As}, {ttuple, Bs}, St) when length(As) =:= length(Bs) ->
    unify_list(As, Bs, St);
unify_({tfn, Ps1, E1, R1}, {tfn, Ps2, E2, R2}, St) ->
    case length(Ps1) =:= length(Ps2) of
        true ->
            St1 = unify_list(Ps2, Ps1, St),
            St2 = unify_(resolve(E1, St1), resolve(E2, St1), St1),
            unify_(resolve(R1, St2), resolve(R2, St2), St2);
        false ->
            throw({unify_error, {arity, length(Ps1), length(Ps2)}})
    end;
unify_(pure, T, _St) ->
    throw({unify_error, {pure_vs_effect, T}});
unify_(T, pure, _St) ->
    throw({unify_error, {pure_vs_effect, T}});
unify_(A, B, _St) ->
    throw({unify_error, {mismatch, A, B}}).

unify_list([], [], St) ->
    St;
unify_list([A | As], [B | Bs], St) ->
    St1 = unify_(resolve(A, St), resolve(B, St), St),
    unify_list(As, Bs, St1).

%% Binding a variable: the occurs check, the flag rules, level adjustment.
%% Pure against a process-only variable fails with Reason, which says on
%% which side of the unification, the expected or the actual, pure stood.
bind_var(Id, _V, pure, Reason, St) ->
    case lists:member(process_only, flags(Id, St)) of
        true -> throw({unify_error, Reason});
        false -> bind(Id, pure, St)
    end;
bind_var(Id, _V, {tvar, Id2}, _Reason, St) ->
    %% two variables: merge flags into the survivor, keep the lower level
    #st{vars = Vs} = St,
    %% and the annotation's name, if only the bound one has it (§11.5)
    #tv{level = L1, flags = F1, name = N1} = maps:get(Id, Vs),
    #tv{level = L2, flags = F2, name = N2} = TV2 = maps:get(Id2, Vs),
    Name = case N2 of undefined -> N1; _ -> N2 end,
    TV2a = TV2#tv{level = min(L1, L2), flags = lists:usort(F1 ++ F2), name = Name},
    bind(Id, {tvar, Id2}, St#st{vars = Vs#{Id2 => TV2a}});
bind_var(Id, V, T, _Reason, St) ->
    case occurs(Id, T, St) of
        true -> throw({unify_error, {occurs, V, T}});
        false ->
            St1 = adjust_levels(Id, T, St),
            bind(Id, T, St1)
    end.

occurs(Id, T, St) ->
    case resolve(T, St) of
        {tvar, Id} -> true;
        {tvar, _} -> false;
        {tcon, _, Args} -> lists:any(fun(A) -> occurs(Id, A, St) end, Args);
        {ttuple, Es} -> lists:any(fun(E) -> occurs(Id, E, St) end, Es);
        {tfn, Ps, E, R} -> lists:any(fun(X) -> occurs(Id, X, St) end, [E, R | Ps]);
        pure -> false
    end.

%% Variables inside T inherit the bound variable's level if lower, so that
%% generalization never quantifies a variable that escaped outward.
adjust_levels(Id, T, #st{vars = Vs} = St) ->
    #tv{level = Level} = maps:get(Id, Vs),
    lists:foldl(fun(FId, S) ->
                    #st{vars = V} = S,
                    #tv{level = L} = TV = maps:get(FId, V),
                    case L > Level of
                        true -> S#st{vars = V#{FId => TV#tv{level = Level}}};
                        false -> S
                    end
                end, St, free_vars(T, St)).

%% Free variable ids of a type, in order of first occurrence.
-spec free_vars(type() | pure, st()) -> [id()].
free_vars(T, St) ->
    lists:reverse(free_vars(T, St, [])).

free_vars(T, St, Acc) ->
    case resolve(T, St) of
        {tvar, Id} -> case lists:member(Id, Acc) of true -> Acc; false -> [Id | Acc] end;
        {tcon, _, Args} -> lists:foldl(fun(A, Ac) -> free_vars(A, St, Ac) end, Acc, Args);
        {ttuple, Es} -> lists:foldl(fun(E, Ac) -> free_vars(E, St, Ac) end, Acc, Es);
        {tfn, Ps, E, R} -> lists:foldl(fun(X, Ac) -> free_vars(X, St, Ac) end, Acc, Ps ++ [E, R]);
        pure -> Acc
    end.

%%
%% Schemes
%%

-spec mono(type()) -> #scheme{}.
mono(T) -> #scheme{vars = [], type = T}.

%% Quantify the variables of T created at a deeper level than the current
%% one, carrying their flags. An effect variable that is free, unrestricted,
%% and occurs nowhere else is replaced by pure: the two are equivalent for
%% callers and pure prints better.
-spec generalize(type(), st()) -> {#scheme{}, st()}.
generalize(T, St) -> generalize(T, [], St).

-spec generalize(type(), [id()], st()) -> {#scheme{}, st()}.
generalize(T, Keep, #st{level = Level, vars = Vs} = St) ->
    T1 = zonk(T, St),
    T2 = elide_pure_effects(T1, Keep, St),
    Ids = [Id || Id <- free_vars(T2, St),
                 (maps:get(Id, Vs))#tv.level > Level orelse lists:member(Id, Keep)],
    Names = maps:from_list([{Id, N} || Id <- Ids, N <- [(maps:get(Id, Vs))#tv.name],
                                       N =/= undefined]),
    {#scheme{vars = [{Id, (maps:get(Id, Vs))#tv.flags} || Id <- Ids], type = T2, names = Names},
     St}.

elide_pure_effects(T, Keep, St) ->
    Counts = count_vars(T, #{}),
    Effects = effect_positions(T, []),
    Elide = [Id || Id <- Effects,
                   maps:get(Id, Counts) =:= 1,
                   not lists:member(process_only, flags(Id, St)),
                   not lists:member(Id, Keep)],
    replace_effects(T, Elide).

count_vars({tvar, Id}, M) -> maps:update_with(Id, fun(N) -> N + 1 end, 1, M);
count_vars({tcon, _, As}, M) -> lists:foldl(fun count_vars/2, M, As);
count_vars({ttuple, Es}, M) -> lists:foldl(fun count_vars/2, M, Es);
count_vars({tfn, Ps, E, R}, M) -> lists:foldl(fun count_vars/2, M, Ps ++ [E, R]);
count_vars(pure, M) -> M.

effect_positions({tfn, Ps, E, R}, Acc) ->
    Acc1 = case E of {tvar, Id} -> [Id | Acc]; _ -> Acc end,
    lists:foldl(fun effect_positions/2, Acc1, Ps ++ [R]);
effect_positions({tcon, _, As}, Acc) -> lists:foldl(fun effect_positions/2, Acc, As);
effect_positions({ttuple, Es}, Acc) -> lists:foldl(fun effect_positions/2, Acc, Es);
effect_positions(_, Acc) -> Acc.

replace_effects({tfn, Ps, E, R}, Elide) ->
    E1 = case E of
             {tvar, Id} -> case lists:member(Id, Elide) of true -> pure; false -> E end;
             _ -> E
         end,
    {tfn, [replace_effects(P, Elide) || P <- Ps], E1, replace_effects(R, Elide)};
replace_effects({tcon, N, As}, Elide) -> {tcon, N, [replace_effects(A, Elide) || A <- As]};
replace_effects({ttuple, Es}, Elide) -> {ttuple, [replace_effects(E, Elide) || E <- Es]};
replace_effects(T, _) -> T.

%% Fresh variables for the quantified ones, flags copied.
-spec instantiate(#scheme{}, st()) -> {type(), st()}.
instantiate(#scheme{vars = [], type = T}, St) ->
    {T, St};
%% An instance's variables carry no names: a name belongs to the
%% annotation that wrote it, not to a use of the value (report §11.5).
instantiate(#scheme{vars = Vars, type = T}, St) ->
    {Map, St1} = lists:foldl(fun({Id, Flags}, {M, S}) ->
                                 {V, S1} = fresh(S, Flags),
                                 {M#{Id => V}, S1}
                             end, {#{}, St}, Vars),
    {subst_vars(T, Map), St1}.

subst_vars({tvar, Id} = V, Map) -> maps:get(Id, Map, V);
subst_vars({tcon, N, As}, Map) -> {tcon, N, [subst_vars(A, Map) || A <- As]};
subst_vars({ttuple, Es}, Map) -> {ttuple, [subst_vars(E, Map) || E <- Es]};
subst_vars({tfn, Ps, E, R}, Map) ->
    {tfn, [subst_vars(P, Map) || P <- Ps], subst_vars(E, Map), subst_vars(R, Map)};
subst_vars(pure, _) -> pure.

%%
%% Printing, report §11.5. Variables are named a, b, c, ... in order of
%% appearance; a variable with the equality constraint prints as a=, one
%% that is process-only prints unchanged in effect position (its restriction
%% is stated in messages), one that is not-reply-carrying prints as a!.
%%

%% Report §11.5: the differing part of two types that do not unify, so a
%% message shows Int against String rather than two whole function types.
-spec mismatch_pair(type() | pure, type() | pure, st()) -> {type() | pure, type() | pure}.
mismatch_pair(E, A, St) ->
    differing(zonk(E, St), zonk(A, St)).

differing({tcon, Q, Es}, {tcon, Q, As}) when length(Es) =:= length(As) ->
    first_differing(Es, As, {{tcon, Q, Es}, {tcon, Q, As}});
differing({ttuple, Es}, {ttuple, As}) when length(Es) =:= length(As) ->
    first_differing(Es, As, {{ttuple, Es}, {ttuple, As}});
differing({tfn, EPs, EE, ER}, {tfn, APs, AE, AR}) when length(EPs) =:= length(APs) ->
    first_differing(EPs ++ [EE, ER], APs ++ [AE, AR], {{tfn, EPs, EE, ER}, {tfn, APs, AE, AR}});
differing(E, A) ->
    {E, A}.

first_differing(Es, As, Whole) ->
    case [{E, A} || {E, A} <- lists:zip(Es, As), E =/= A] of
        [{E, A} | _] -> differing(E, A);
        [] -> Whole
    end.

-spec format(type() | pure, st()) -> string().
format(T, St) ->
    T1 = zonk(T, St),
    EffectOnly = effect_only_vars(T1, St),
    {S, _} = fmt(T1, St, #{effect_only => EffectOnly, values => 0, effects => 0, taken => []}),
    lists:flatten(S).

%% Variables that occur in no value position are named e, e1, ...: those
%% after `with`, and those only in a type argument that is no value
%% position, `H(e)`; the others a, b, c, d, f, ... (report §3.9 writes `e`
%% for effect variables).
effect_only_vars(T, St) ->
    free_vars(T, St) -- value_vars(T, St).

%% Variable ids in value positions / in effect positions of a zonked type.
%% Report §3.9: a type argument is a value position unless the state says
%% its parameter occurs in no value position of the type's fields.
-spec value_vars(type() | pure, st()) -> [id()].
value_vars(T, #st{effect_params = EP}) -> lists:usort(value_positions(T, EP, [])).

-spec effect_vars(type() | pure) -> [id()].
effect_vars(T) -> lists:usort(effect_positions(T, [])).

value_positions({tvar, Id}, _EP, Acc) ->
    [Id | Acc];
value_positions({tcon, Q, As}, EP, Acc) ->
    Values = case EP of
                 #{Q := Flags} -> [A || {A, true} <- lists:zip(As, Flags)];
                 _ -> As
             end,
    value_positions_list(Values, EP, Acc);
value_positions({ttuple, Es}, EP, Acc) ->
    value_positions_list(Es, EP, Acc);
value_positions({tfn, Ps, _E, R}, EP, Acc) ->
    value_positions_list(Ps ++ [R], EP, Acc);
value_positions(pure, _EP, Acc) ->
    Acc.

value_positions_list(Ts, EP, Acc) ->
    lists:foldl(fun(T, A) -> value_positions(T, EP, A) end, Acc, Ts).

%% The module being checked, the session's types, and the type names that
%% shadow prelude names, which print qualified (report §11.5).
-spec set_scope(st(), qname(), [qname()], [atom()]) -> st().
set_scope(St, Ns, Session, Shadows) ->
    St#st{ns = Ns, session = Session, shadows = Shadows}.

%% Report §3.9: the types with a parameter that occurs in no value position
%% of their fields, each with whether each of its arguments is a value
%% position.
-spec set_effect_params(st(), #{qname() => [boolean()]}) -> st().
set_effect_params(St, EffectParams) ->
    St#st{effect_params = EffectParams}.

%% Report §11.5: a type name as the module would write it.
type_name([Name], _St) ->
    atom_to_list(Name);
type_name(QName, #st{ns = Ns, session = Session, shadows = Shadows}) ->
    Name = lists:last(QName),
    Own = lists:droplast(QName) =:= Ns orelse lists:member(QName, Session),
    case Own andalso not lists:member(Name, Shadows) of
        true -> atom_to_list(Name);
        false -> qname(QName)
    end.

%% The scheme's own flags apply, whatever state it is printed under.
-spec format_scheme(#scheme{}, st()) -> string().
format_scheme(#scheme{type = T} = Scheme, St) ->
    format(T, scheme_state(Scheme, St)).

%% The state with a scheme's variables named as its declaration names them.
%% They are the scheme's own, bound by it, so the state's substitution does
%% not reach them: a scheme another module or an earlier input declared
%% numbers its variables in a state of its own, where the same id may be
%% bound here to something else.
scheme_state(#scheme{vars = Vars, names = Names}, #st{vars = Vs, subst = S} = St) ->
    Vs1 = lists:foldl(fun({Id, Flags}, Acc) ->
                          TV = maps:get(Id, Acc, #tv{id = Id, level = 0}),
                          Acc#{Id => TV#tv{flags = Flags, name = maps:get(Id, Names, undefined)}}
                      end, Vs, Vars),
    St#st{vars = Vs1, subst = maps:without([Id || {Id, _} <- Vars], S)}.

%% Report §11.2: a function's signature as `Shift-Tab` shows it inside a
%% call, each parameter under the name its declaration gives it, where it
%% gives one, and the variables named once across the whole: the text
%% before the parameter at the cursor, counted from 0, that parameter, and
%% the text after it, so that whoever paints it can mark the middle part.
-spec format_call(#scheme{}, [atom()], non_neg_integer(), st()) ->
          {string(), string(), string()}.
format_call(#scheme{type = T} = Scheme, Params, Marked, St) ->
    St1 = scheme_state(Scheme, St),
    case zonk(T, St1) of
        {tfn, Ps, E, R} = T1 ->
            Names0 = #{effect_only => effect_only_vars(T1, St1), values => 0, effects => 0,
                       taken => []},
            {Shown, Names1} = lists:mapfoldl(fun(P, N) -> fmt(P, St1, N) end, Names0, Ps),
            Named = [parameter(Name, S) || {Name, S} <- lists:zip(padded(Params, length(Ps)),
                                                                   Shown)],
            {Rs, Names2} = fmt_ret(R, St1, Names1),
            Effect = case E of
                         pure -> [];
                         _ -> [" with ", element(1, fmt(E, St1, Names2))]
                     end,
            Tail = [") -> ", Rs, Effect],
            case Marked < length(Named) of
                true ->
                    {Left, [This | Right]} = lists:split(Marked, Named),
                    {lists:flatten(["(", [[P, ", "] || P <- Left]]), lists:flatten(This),
                     lists:flatten([[[", ", P] || P <- Right], Tail])};
                false ->
                    {lists:flatten(["(", lists:join(", ", Named), Tail]), "", ""}
            end;
        _ ->
            {format_scheme(Scheme, St), "", ""}
    end.

parameter('_', Type) -> Type;
parameter(Name, Type) -> [atom_to_list(Name), " : ", Type].

padded(Params, N) when length(Params) =:= N -> Params;
padded(_, N) -> lists:duplicate(N, '_').

%% Report §11.5: the annotation's name if the variable has one and it is
%% not in use for another, else a fresh name that is not in use.
fmt({tvar, Id}, St, Names) ->
    case Names of
        #{Id := N} -> {N, Names};
        #{effect_only := EffectOnly, taken := Taken} ->
            {Base, Names1} = case safe_name(Id, St) of
                                 undefined -> fresh_name(Id, EffectOnly, Names);
                                 Given ->
                                     case lists:member(Given, Taken) of
                                         true -> fresh_name(Id, EffectOnly, Names);
                                         false -> {Given, Names}
                                     end
                             end,
            Marks = [$= || lists:member(eq, safe_flags(Id, St))]
                 ++ [$! || lists:member(no_reply, safe_flags(Id, St))],
            N = Base ++ Marks,
            {N, Names1#{Id => N, taken => [Base | Taken]}}
    end;
fmt({tcon, QName, []}, St, Names) ->
    {type_name(QName, St), Names};
fmt({tcon, QName, Args}, St, Names) ->
    {Ss, Names1} = fmt_list(Args, St, Names),
    {[type_name(QName, St), "(", Ss, ")"], Names1};
fmt({ttuple, Es}, St, Names) ->
    {Ss, Names1} = fmt_list(Es, St, Names),
    {["#(", Ss, ")"], Names1};
fmt({tfn, Ps, E, R}, St, Names) ->
    {Ss, Names1} = fmt_list(Ps, St, Names),
    {Rs, Names2} = fmt_ret(R, St, Names1),
    case E of
        pure -> {["(", Ss, ") -> ", Rs], Names2};
        _ ->
            {Es, Names3} = fmt(E, St, Names2),
            {["(", Ss, ") -> ", Rs, " with ", Es], Names3}
    end;
fmt(pure, _St, Names) ->
    {"pure", Names}.

%% A function type in result position is parenthesized when it carries an
%% effect, so `with` reads as belonging to the outer arrow (report §3.4).
fmt_ret({tfn, _, E, _} = T, St, Names) when E =/= pure ->
    {S, N} = fmt(T, St, Names),
    {["(", S, ")"], N};
fmt_ret(T, St, Names) ->
    fmt(T, St, Names).

fmt_list(Ts, St, Names) ->
    {Ss, Names1} = lists:mapfoldl(fun(T, N) -> fmt(T, St, N) end, Names, Ts),
    {lists:join(", ", Ss), Names1}.

%% a, b, c, ... or e, e1, ..., skipping names in use.
fresh_name(Id, EffectOnly, #{values := NV, effects := NE, taken := Taken} = Names) ->
    case lists:member(Id, EffectOnly) of
        true ->
            case lists:member(effect_name(NE), Taken) of
                true -> fresh_name(Id, EffectOnly, Names#{effects => NE + 1});
                false -> {effect_name(NE), Names#{effects => NE + 1}}
            end;
        false ->
            case lists:member(var_name(NV), Taken) of
                true -> fresh_name(Id, EffectOnly, Names#{values => NV + 1});
                false -> {var_name(NV), Names#{values => NV + 1}}
            end
    end.

safe_name(Id, #st{vars = Vs}) ->
    case Vs of
        #{Id := #tv{name = undefined}} -> undefined;
        #{Id := #tv{name = Name}} -> atom_to_list(Name);
        _ -> undefined
    end.

safe_flags(Id, #st{vars = Vs}) ->
    case Vs of
        #{Id := #tv{flags = F}} -> F;
        _ -> []
    end.

%% a, b, c, d, f, ... skipping e.
var_name(N) ->
    Letters = "abcdfghijklmnopqrstuvwxyz",
    [lists:nth(N rem 25 + 1, Letters)] ++ [integer_to_list(N div 25) || N >= 25].

effect_name(0) -> "e";
effect_name(N) -> "e" ++ integer_to_list(N).

qname(Parts) -> lists:join(".", [atom_to_list(P) || P <- Parts]).

-spec format_error(term()) -> string().
format_error({arity, N, M}) ->
    lists:flatten(io_lib:format("a function of ~B argument~s where one of ~B was expected",
                                [N, plural(N), M]));
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
