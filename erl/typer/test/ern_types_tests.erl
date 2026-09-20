-module(ern_types_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_types.hrl").

int() -> {tcon, ['Int'], []}.
bool() -> {tcon, ['Bool'], []}.
list(T) -> {tcon, ['List'], [T]}.

unify_ok(A, B, St) ->
    {ok, St1} = ern_types:unify(A, B, St),
    St1.

%% report §3.4, §3.9
unify_concrete_test() ->
    St = ern_types:new(),
    ?assertMatch({ok, _}, ern_types:unify(int(), int(), St)),
    ?assertMatch({error, {mismatch, _, _}}, ern_types:unify(int(), bool(), St)),
    ?assertMatch({error, {arity, 1, 2}},
                 ern_types:unify({tfn, [int()], pure, int()}, {tfn, [int(), int()], pure, int()},
                                 St)).

%% report §3.9
unify_variable_test() ->
    St0 = ern_types:new(),
    {A, St1} = ern_types:fresh(St0),
    St2 = unify_ok(A, list(int()), St1),
    ?assertEqual(list(int()), ern_types:zonk(A, St2)),
    {B, St3} = ern_types:fresh(St2),
    {C, St4} = ern_types:fresh(St3),
    St5 = unify_ok(B, C, St4),
    St6 = unify_ok(C, bool(), St5),
    ?assertEqual(bool(), ern_types:zonk(B, St6)).

%% report §3.9
occurs_check_test() ->
    {A, St} = ern_types:fresh(ern_types:new()),
    ?assertMatch({error, {occurs, _, _}}, ern_types:unify(A, list(A), St)).

%% report §3.9
effect_rules_test() ->
    St0 = ern_types:new(),
    {E, St1} = ern_types:fresh(St0),
    %% an unrestricted effect variable may become pure
    ?assertMatch({ok, _}, ern_types:unify(E, pure, St1)),
    %% a process-only one may not
    St2 = ern_types:add_flag(E, process_only, St1),
    ?assertEqual({error, process_only_vs_pure}, ern_types:unify(E, pure, St2)),
    ?assertEqual({error, process_only_vs_pure}, ern_types:unify(pure, E, St2)),
    %% pure against a mailbox type is an error; two mailbox types must match
    ?assertMatch({error, {pure_vs_effect, _}}, ern_types:unify(pure, int(), St0)),
    ?assertMatch({error, {mismatch, _, _}}, ern_types:unify(int(), bool(), St0)),
    %% flags merge when two variables are unified
    {F, St3} = ern_types:fresh(St2),
    St4 = unify_ok(F, E, St3),
    ?assertEqual({error, process_only_vs_pure}, ern_types:unify(F, pure, St4)).

%% report §3.9
generalize_by_level_test() ->
    St0 = ern_types:enter(ern_types:new()),
    {A, St1} = ern_types:fresh(St0),
    {B, St2} = ern_types:fresh(St1),
    St3 = ern_types:leave(St2),
    {#scheme{vars = Vars, type = T}, _} = ern_types:generalize({tfn, [A], pure, B}, St3),
    ?assertEqual(2, length(Vars)),
    ?assertMatch({tfn, [{tvar, _}], pure, {tvar, _}}, T).

%% report §3.9, §4.6
no_generalize_outer_variable_test() ->
    St0 = ern_types:new(),
    {Outer, St1} = ern_types:fresh(St0),
    St2 = ern_types:enter(St1),
    {Inner, St3} = ern_types:fresh(St2),
    St4 = unify_ok(Inner, list(Outer), St3),
    St5 = ern_types:leave(St4),
    {#scheme{vars = Vars}, _} = ern_types:generalize({tfn, [Inner], pure, Inner}, St5),
    ?assertEqual([], Vars).

%% report §3.9
instantiate_copies_flags_test() ->
    St0 = ern_types:enter(ern_types:new()),
    {A, St1} = ern_types:fresh(St0, [eq]),
    St2 = ern_types:leave(St1),
    {Scheme, St3} = ern_types:generalize({tfn, [A, A], pure, bool()}, St2),
    {{tfn, [{tvar, Id1}, {tvar, Id2}], pure, _}, St4} = ern_types:instantiate(Scheme, St3),
    ?assertEqual(Id1, Id2),
    ?assertEqual([eq], ern_types:flags(Id1, St4)).

%% report §6.1
elide_unused_effect_test() ->
    St0 = ern_types:enter(ern_types:new()),
    {E, St1} = ern_types:fresh_effect(St0),
    St2 = ern_types:leave(St1),
    %% an effect variable used nowhere else becomes pure
    {#scheme{type = T1}, _} = ern_types:generalize({tfn, [int()], E, int()}, St2),
    ?assertEqual({tfn, [int()], pure, int()}, T1),
    %% one that also appears on a callback stays a variable
    {#scheme{type = T2}, _} =
        ern_types:generalize({tfn, [{tfn, [int()], E, int()}], E, int()}, St2),
    ?assertMatch({tfn, [{tfn, [_], {tvar, _}, _}], {tvar, _}, _}, T2),
    %% a process-only one stays too
    St3 = ern_types:add_flag(E, process_only, St2),
    {#scheme{type = T3}, _} = ern_types:generalize({tfn, [int()], E, int()}, St3),
    ?assertMatch({tfn, [_], {tvar, _}, _}, T3).

%% report §11.5
format_test() ->
    St0 = ern_types:new(),
    {A, St1} = ern_types:fresh(St0),
    {B, St2} = ern_types:fresh(St1),
    {E, St3} = ern_types:fresh(St2),
    ?assertEqual("Int", ern_types:format(int(), St3)),
    ?assertEqual("List(Int)", ern_types:format(list(int()), St3)),
    ?assertEqual("Net.Http.Request", ern_types:format({tcon, ['Net', 'Http', 'Request'], []}, St3)),
    ?assertEqual("#(Int, Bool)", ern_types:format({ttuple, [int(), bool()]}, St3)),
    ?assertEqual("() -> Int", ern_types:format({tfn, [], pure, int()}, St3)),
    ?assertEqual("(a, b) -> a with e", ern_types:format({tfn, [A, B], E, A}, St3)),
    ?assertEqual("() -> Address(a) with a",
                 ern_types:format({tfn, [], A, {tcon, ['Address'], [A]}}, St3)),
    ?assertEqual("((a) -> b with e, a) -> b with e",
                 ern_types:format({tfn, [{tfn, [A], E, B}, A], E, B}, St3)),
    ?assertEqual("(Int) -> ((Int) -> Int with Never)",
                 ern_types:format({tfn, [int()], pure,
                                   {tfn, [int()], {tcon, ['Never'], []}, int()}}, St3)),
    ?assertEqual("(Int) -> (Int) -> Int",
                 ern_types:format({tfn, [int()], pure, {tfn, [int()], pure, int()}}, St3)),
    St4 = ern_types:add_flag(A, eq, St3),
    ?assertEqual("(a=, a=) -> Bool", ern_types:format({tfn, [A, A], pure, bool()}, St4)),
    St5 = ern_types:add_flag(B, no_reply, St4),
    ?assertEqual("(a!) -> #(a!, a!)", ern_types:format({tfn, [B], pure, {ttuple, [B, B]}}, St5)).

%% report §11.5
format_error_test() ->
    ?assertEqual("a function of 1 argument where one of 2 was expected",
                 ern_types:format_error({arity, 1, 2})),
    ?assertEqual("process code called from a pure function",
                 ern_types:format_error(process_only_vs_pure)).
