%% Type terms, substitution, unification, generalization, instantiation,
%% and printing. See include/ern_types.hrl for the term shapes. All state
%% is in #st{} and threaded; nothing is mutated.
-module(ern_types).

-export([new/0, fresh/1, fresh/2, fresh_effect/1, flags/2, var_level/2, add_flag/3,
         enter/1, leave/1, level/1,
         resolve/2, zonk/2, unify/3, occurs_free/2,
         generalize/2, generalize/3, instantiate/2, mono/1, free_vars/2,
         value_vars/1, effect_vars/1,
         format/2, format_scheme/2, format_error/1, set_scope/3]).

-export_type([st/0, type/0, effect/0, qname/0, id/0, flags/0]).

-include_lib("type_system/include/ern_types.hrl").

-type id() :: pos_integer().
-type qname() :: [atom()].
-type flags() :: [eq | process_only | no_reply].
-type effect() :: pure | type().
-type type() :: {tvar, id()} | {tcon, qname(), [type()]} | {ttuple, [type()]}
              | {tfn, [type()], effect(), type()}.

-record(st, {next = 1, level = 0, subst = #{}, vars = #{}, ns = [], shadows = []}).
%% ns, shadows: the module being checked and its type names that shadow
%% prelude names, for printing (report §11.5)
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

%% An effect variable for a function whose effect is inferred.
-spec fresh_effect(st()) -> {type(), st()}.
fresh_effect(St) -> fresh(St, []).

-spec flags(id(), st()) -> flags().
flags(Id, #st{vars = Vs}) -> (maps:get(Id, Vs))#tv.flags.

-spec var_level(id(), st()) -> non_neg_integer().
var_level(Id, #st{vars = Vs}) -> (maps:get(Id, Vs))#tv.level.

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

-spec level(st()) -> non_neg_integer().
level(#st{level = L}) -> L.

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
    bind_var(Id, V, T, St);
unify_(T, {tvar, Id} = V, St) ->
    bind_var(Id, V, T, St);
unify_({tcon, N, As}, {tcon, N, Bs}, St) when length(As) =:= length(Bs) ->
    unify_list(As, Bs, St);
unify_({ttuple, As}, {ttuple, Bs}, St) when length(As) =:= length(Bs) ->
    unify_list(As, Bs, St);
unify_({tfn, Ps1, E1, R1}, {tfn, Ps2, E2, R2}, St) ->
    case length(Ps1) =:= length(Ps2) of
        true ->
            St1 = unify_list(Ps1, Ps2, St),
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
bind_var(Id, _V, pure, St) ->
    case lists:member(process_only, flags(Id, St)) of
        true -> throw({unify_error, process_only_vs_pure});
        false -> bind(Id, pure, St)
    end;
bind_var(Id, _V, {tvar, Id2}, St) ->
    %% two variables: merge flags into the survivor, keep the lower level
    #st{vars = Vs} = St,
    #tv{level = L1, flags = F1} = maps:get(Id, Vs),
    #tv{level = L2, flags = F2} = TV2 = maps:get(Id2, Vs),
    TV2a = TV2#tv{level = min(L1, L2), flags = lists:usort(F1 ++ F2)},
    bind(Id, {tvar, Id2}, St#st{vars = Vs#{Id2 => TV2a}});
bind_var(Id, V, T, St) ->
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

-spec occurs_free(id(), type() | pure) -> boolean().
occurs_free(Id, T) ->
    lists:member(Id, free_vars(T, #st{})).

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
    {#scheme{vars = [{Id, (maps:get(Id, Vs))#tv.flags} || Id <- Ids], type = T2}, St}.

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

-spec format(type() | pure, st()) -> string().
format(T, St) ->
    T1 = zonk(T, St),
    EffectOnly = effect_only_vars(T1),
    {S, _} = fmt(T1, St, #{effect_only => EffectOnly, values => 0, effects => 0}),
    lists:flatten(S).

%% Variables that occur only in effect positions are named e, e1, ...; the
%% others a, b, c, d, f, ... (report §3.9 writes `e` for effect variables).
effect_only_vars(T) ->
    effect_vars(T) -- value_vars(T).

%% Variable ids in value positions / in effect positions of a zonked type.
-spec value_vars(type() | pure) -> [id()].
value_vars(T) -> lists:usort(value_positions(T, [])).

-spec effect_vars(type() | pure) -> [id()].
effect_vars(T) -> lists:usort(effect_positions(T, [])).

value_positions({tvar, Id}, Acc) -> [Id | Acc];
value_positions({tcon, _, As}, Acc) -> lists:foldl(fun value_positions/2, Acc, As);
value_positions({ttuple, Es}, Acc) -> lists:foldl(fun value_positions/2, Acc, Es);
value_positions({tfn, Ps, _E, R}, Acc) -> lists:foldl(fun value_positions/2, Acc, Ps ++ [R]);
value_positions(pure, Acc) -> Acc.

%% The module whose types print unqualified, and its type names that
%% shadow prelude names, which print qualified (report §11.5).
-spec set_scope(st(), qname(), [atom()]) -> st().
set_scope(St, Ns, Shadows) ->
    St#st{ns = Ns, shadows = Shadows}.

%% Report §11.5: a type name as the module would write it.
type_name([Name], _St) ->
    atom_to_list(Name);
type_name(QName, #st{ns = Ns, shadows = Shadows}) ->
    Name = lists:last(QName),
    case lists:droplast(QName) =:= Ns andalso not lists:member(Name, Shadows) of
        true -> atom_to_list(Name);
        false -> qname(QName)
    end.

%% The scheme's own flags apply, whatever state it is printed under.
-spec format_scheme(#scheme{}, st()) -> string().
format_scheme(#scheme{vars = Vars, type = T}, #st{vars = Vs} = St) ->
    Vs1 = lists:foldl(fun({Id, Flags}, Acc) ->
                          TV = maps:get(Id, Acc, #tv{id = Id, level = 0}),
                          Acc#{Id => TV#tv{flags = Flags}}
                      end, Vs, Vars),
    format(T, St#st{vars = Vs1}).

fmt({tvar, Id}, St, Names) ->
    case Names of
        #{Id := N} -> {N, Names};
        #{effect_only := EffectOnly, values := NV, effects := NE} ->
            {Base, Names1} = case lists:member(Id, EffectOnly) of
                                 true -> {effect_name(NE), Names#{effects => NE + 1}};
                                 false -> {var_name(NV), Names#{values => NV + 1}}
                             end,
            Marks = [$= || lists:member(eq, safe_flags(Id, St))]
                 ++ [$! || lists:member(no_reply, safe_flags(Id, St))],
            N = Base ++ Marks,
            {N, Names1#{Id => N}}
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
format_error(process_only_vs_pure) ->
    "process code called from a pure function";
format_error({occurs, _, _}) ->
    "a type that would contain itself";
format_error({mismatch, _, _}) ->
    "types do not match".

plural(1) -> "";
plural(_) -> "s".
