-module(ern_types_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_types.hrl").

int() -> {tcon, ['Int'], []}.
bool() -> {tcon, ['Bool'], []}.
list(Element) -> {tcon, ['List'], [Element]}.

unify_ok(Expected, Actual, TypeState) ->
    {ok, TypeState1} = ern_types:unify(Expected, Actual, TypeState),
    TypeState1.

%% report §3.4, §3.9
unify_concrete_test() ->
    TypeState = ern_types:new(),
    ?assertMatch({ok, _}, ern_types:unify(int(), int(), TypeState)),
    ?assertMatch({error, {mismatch, _, _}}, ern_types:unify(int(), bool(), TypeState)),
    ?assertMatch({error, {arity, 1, 2}},
                 ern_types:unify({tfn, [int()], pure, int()}, {tfn, [int(), int()], pure, int()},
                                 TypeState)).

%% report §3.9
unify_variable_test() ->
    TypeState = ern_types:new(),
    {A, TypeState1} = ern_types:fresh(TypeState),
    TypeState2 = unify_ok(A, list(int()), TypeState1),
    ?assertEqual(list(int()), ern_types:substitute(A, TypeState2)),
    {B, TypeState3} = ern_types:fresh(TypeState2),
    {C, TypeState4} = ern_types:fresh(TypeState3),
    TypeState5 = unify_ok(B, C, TypeState4),
    TypeState6 = unify_ok(C, bool(), TypeState5),
    ?assertEqual(bool(), ern_types:substitute(B, TypeState6)).

%% report §3.9
occurs_check_test() ->
    {A, TypeState} = ern_types:fresh(ern_types:new()),
    ?assertMatch({error, {occurs, _, _}}, ern_types:unify(A, list(A), TypeState)).

%% report §3.9
effect_rules_test() ->
    TypeState = ern_types:new(),
    {E, TypeState1} = ern_types:fresh(TypeState),
    %% an unrestricted effect variable may become pure
    ?assertMatch({ok, _}, ern_types:unify(E, pure, TypeState1)),
    %% a process-only one may not
    TypeState2 = ern_types:add_restriction(E, process_only, TypeState1),
    %% the reason says which side, the expected (first) or the actual, is pure
    ?assertEqual({error, pure_where_process_needed}, ern_types:unify(E, pure, TypeState2)),
    ?assertEqual({error, process_where_pure_needed}, ern_types:unify(pure, E, TypeState2)),
    %% pure against a mailbox type is an error; two mailbox types must match
    ?assertMatch({error, {pure_vs_effect, _}}, ern_types:unify(pure, int(), TypeState)),
    ?assertMatch({error, {mismatch, _, _}}, ern_types:unify(int(), bool(), TypeState)),
    %% restrictions merge when two variables are unified
    {F, TypeState3} = ern_types:fresh(TypeState2),
    TypeState4 = unify_ok(F, E, TypeState3),
    ?assertEqual({error, pure_where_process_needed}, ern_types:unify(F, pure, TypeState4)).

%% report §3.9
generalize_by_level_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {A, TypeState1} = ern_types:fresh(TypeState),
    {B, TypeState2} = ern_types:fresh(TypeState1),
    TypeState3 = ern_types:leave(TypeState2),
    {#scheme{quantified = Quantified, type = Type}, _} =
        ern_types:generalize({tfn, [A], pure, B}, TypeState3),
    ?assertEqual(2, length(Quantified)),
    ?assertMatch({tfn, [{tvar, _}], pure, {tvar, _}}, Type).

%% report §3.9, §4.6
no_generalize_outer_variable_test() ->
    TypeState = ern_types:new(),
    {Outer, TypeState1} = ern_types:fresh(TypeState),
    TypeState2 = ern_types:enter(TypeState1),
    {Inner, TypeState3} = ern_types:fresh(TypeState2),
    TypeState4 = unify_ok(Inner, list(Outer), TypeState3),
    TypeState5 = ern_types:leave(TypeState4),
    {#scheme{quantified = Quantified}, _} =
        ern_types:generalize({tfn, [Inner], pure, Inner}, TypeState5),
    ?assertEqual([], Quantified).

%% report §3.9
instantiate_copies_restrictions_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {A, TypeState1} = ern_types:fresh(TypeState, [equality]),
    TypeState2 = ern_types:leave(TypeState1),
    {Scheme, TypeState3} = ern_types:generalize({tfn, [A, A], pure, bool()}, TypeState2),
    {{tfn, [{tvar, FirstId}, {tvar, SecondId}], pure, _}, TypeState4} =
        ern_types:instantiate(Scheme, TypeState3),
    ?assertEqual(FirstId, SecondId),
    ?assertEqual([equality], ern_types:restrictions(FirstId, TypeState4)).

%% report §6.1
elide_unused_effect_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {E, TypeState1} = ern_types:fresh(TypeState),
    TypeState2 = ern_types:leave(TypeState1),
    %% an effect variable used nowhere else becomes pure
    {#scheme{type = Unused}, _} = ern_types:generalize({tfn, [int()], E, int()}, TypeState2),
    ?assertEqual({tfn, [int()], pure, int()}, Unused),
    %% one that also appears on a callback stays a variable
    {#scheme{type = Shared}, _} =
        ern_types:generalize({tfn, [{tfn, [int()], E, int()}], E, int()}, TypeState2),
    ?assertMatch({tfn, [{tfn, [_], {tvar, _}, _}], {tvar, _}, _}, Shared),
    %% a process-only one stays too
    TypeState3 = ern_types:add_restriction(E, process_only, TypeState2),
    {#scheme{type = ProcessOnly}, _} = ern_types:generalize({tfn, [int()], E, int()}, TypeState3),
    ?assertMatch({tfn, [_], {tvar, _}, _}, ProcessOnly).

%% report §11.5
format_test() ->
    TypeState = ern_types:new(),
    {A, TypeState1} = ern_types:fresh(TypeState),
    {B, TypeState2} = ern_types:fresh(TypeState1),
    {E, TypeState3} = ern_types:fresh(TypeState2),
    ?assertEqual("Int", ern_types:format(int(), TypeState3)),
    ?assertEqual("List(Int)", ern_types:format(list(int()), TypeState3)),
    ?assertEqual("Net.Http.Request",
                 ern_types:format({tcon, ['Net', 'Http', 'Request'], []}, TypeState3)),
    ?assertEqual("#(Int, Bool)", ern_types:format({ttuple, [int(), bool()]}, TypeState3)),
    ?assertEqual("() -> Int", ern_types:format({tfn, [], pure, int()}, TypeState3)),
    %% report §11.5: an effect variable that occurs once prints as pure
    ?assertEqual("(a, b) -> a", ern_types:format({tfn, [A, B], E, A}, TypeState3)),
    ?assertEqual("() -> Address(a) with a",
                 ern_types:format({tfn, [], A, {tcon, ['Address'], [A]}}, TypeState3)),
    ?assertEqual("((a) -> b with e, a) -> b with e",
                 ern_types:format({tfn, [{tfn, [A], E, B}, A], E, B}, TypeState3)),
    %% report §3.4: `with` binds to the nearest arrow, so a function result
    %% is parenthesized only under an outer `with`. A regression test: an
    %% outer effect printed after a bare result, which reads as the
    %% result's
    ?assertEqual("(Int) -> (Int) -> Int with Never",
                 ern_types:format({tfn, [int()], pure,
                                   {tfn, [int()], {tcon, ['Never'], []}, int()}}, TypeState3)),
    ?assertEqual("(Int) -> ((Int) -> Int) with Never",
                 ern_types:format({tfn, [int()], {tcon, ['Never'], []},
                                   {tfn, [int()], pure, int()}}, TypeState3)),
    ?assertEqual("(Int) -> (Int) -> Int",
                 ern_types:format({tfn, [int()], pure, {tfn, [int()], pure, int()}}, TypeState3)),
    TypeState4 = ern_types:add_restriction(A, equality, TypeState3),
    ?assertEqual("(a=, a=) -> Bool", ern_types:format({tfn, [A, A], pure, bool()}, TypeState4)),
    TypeState5 = ern_types:add_restriction(B, not_reply_carrying, TypeState4),
    ?assertEqual("(a!) -> #(a!, a!)",
                 ern_types:format({tfn, [B], pure, {ttuple, [B, B]}}, TypeState5)).

%% report §11.2, §11.5: a signature inside a call, each parameter under
%% its declared name, in three parts around the one at the cursor, the
%% variables named once across the whole; a declaration's head writes its
%% result after `:` however its parameters are written, and a function
%% with no declaration keeps its type's arrow. The heads with patterns for
%% parameters are a regression test: they were written as a type
format_call_test() ->
    TypeState = ern_types:new(),
    {A, TypeState1} = ern_types:fresh(TypeState),
    {B, TypeState2} = ern_types:fresh(TypeState1),
    {E, TypeState3} = ern_types:fresh(TypeState2),
    {Scheme, _} = ern_types:generalize({tfn, [list(A), {tfn, [A], E, B}], E, list(B)}, TypeState3),
    ?assertEqual({"(xs : List(a), ", "f : (a) -> b with e", ") : List(b) with e"},
                 ern_types:format_call(Scheme, [xs, f], 1, TypeState3)),
    ?assertEqual({"(", "List(a)", ", (a) -> b with e) -> List(b) with e"},
                 ern_types:format_call(Scheme, none, 0, TypeState3)),
    ?assertEqual({"(", "List(a)", ", (a) -> b with e) : List(b) with e"},
                 ern_types:format_call(Scheme, ['_', '_'], 0, TypeState3)),
    %% an argument past the last parameter marks nothing
    ?assertEqual({"(List(a), (a) -> b with e) -> List(b) with e", "", ""},
                 ern_types:format_call(Scheme, none, 2, TypeState3)),
    ?assertEqual({"() : Int", "", ""},
                 ern_types:format_call(#scheme{type = {tfn, [], pure, int()}}, [], 0, TypeState3)),
    ?assertEqual({"Int", "", ""},
                 ern_types:format_call(#scheme{type = int()}, none, 0, TypeState3)).

%% report §11.5
format_error_test() ->
    ?assertEqual("a function of 2 arguments where one of 1 was expected",
                 ern_types:format_error({arity, 1, 2})),
    ?assertEqual("a pure function where one that runs in a process is needed",
                 ern_types:format_error(pure_where_process_needed)),
    ?assertEqual("a function that runs in a process where a pure one is needed",
                 ern_types:format_error(process_where_pure_needed)).
