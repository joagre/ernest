-module(ern_types_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("checker/include/ern_types.hrl").

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
                 ern_types:unify({tfn, [int()], none, int()}, {tfn, [int(), int()], none, int()},
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
    %% an unrestricted effect variable may become none
    ?assertMatch({ok, _}, ern_types:unify(E, none, TypeState1)),
    %% a process-only one may not
    TypeState2 = ern_types:add_restriction(E, process_only, TypeState1),
    %% the reason says which side, the expected (first) or the actual, is none
    ?assertEqual({error, none_where_mailbox_needed}, ern_types:unify(E, none, TypeState2)),
    ?assertEqual({error, mailbox_where_none_needed}, ern_types:unify(none, E, TypeState2)),
    %% none against a mailbox type is an error; two mailbox types must match
    ?assertMatch({error, {none_vs_mailbox, _}}, ern_types:unify(none, int(), TypeState)),
    ?assertMatch({error, {mismatch, _, _}}, ern_types:unify(int(), bool(), TypeState)),
    %% restrictions merge when two variables are unified
    {F, TypeState3} = ern_types:fresh(TypeState2),
    TypeState4 = unify_ok(F, E, TypeState3),
    ?assertEqual({error, none_where_mailbox_needed}, ern_types:unify(F, none, TypeState4)).

%% report §3.9
generalize_by_level_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {A, TypeState1} = ern_types:fresh(TypeState),
    {B, TypeState2} = ern_types:fresh(TypeState1),
    TypeState3 = ern_types:leave(TypeState2),
    {#scheme{quantified = Quantified, type = Type}, _} =
        ern_types:generalize({tfn, [A], none, B}, TypeState3),
    ?assertEqual(2, length(Quantified)),
    ?assertMatch({tfn, [{tvar, _}], none, {tvar, _}}, Type).

%% report §3.9, §4.6
no_generalize_outer_variable_test() ->
    TypeState = ern_types:new(),
    {Outer, TypeState1} = ern_types:fresh(TypeState),
    TypeState2 = ern_types:enter(TypeState1),
    {Inner, TypeState3} = ern_types:fresh(TypeState2),
    TypeState4 = unify_ok(Inner, list(Outer), TypeState3),
    TypeState5 = ern_types:leave(TypeState4),
    {#scheme{quantified = Quantified}, _} =
        ern_types:generalize({tfn, [Inner], none, Inner}, TypeState5),
    ?assertEqual([], Quantified).

%% report §3.9
instantiate_copies_restrictions_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {A, TypeState1} = ern_types:fresh(TypeState, [equality]),
    TypeState2 = ern_types:leave(TypeState1),
    {Scheme, TypeState3} = ern_types:generalize({tfn, [A, A], none, bool()}, TypeState2),
    {{tfn, [{tvar, FirstId}, {tvar, SecondId}], none, _}, TypeState4} =
        ern_types:instantiate(Scheme, TypeState3),
    ?assertEqual(FirstId, SecondId),
    ?assertEqual([equality], ern_types:restrictions(FirstId, TypeState4)).

%% report §3.9, §6.1, §11.5: a function's own effect variable that occurs
%% nowhere else is none, in a result's function type too; one within a
%% parameter's type stays, since none would refuse a function with a
%% mailbox type there. The parameter's case is a regression test, written
%% after the code: the variable was made none, and `fn ignore(f : () ->
%% Unit receiving e)` refused every function with a mailbox type
elide_unused_effect_test() ->
    TypeState = ern_types:enter(ern_types:new()),
    {E, TypeState1} = ern_types:fresh(TypeState),
    TypeState2 = ern_types:leave(TypeState1),
    %% an effect variable used nowhere else becomes none
    {#scheme{type = Unused}, _} = ern_types:generalize({tfn, [int()], E, int()}, TypeState2),
    ?assertEqual({tfn, [int()], none, int()}, Unused),
    %% one that also appears on a callback stays a variable
    {#scheme{type = Shared}, _} =
        ern_types:generalize({tfn, [{tfn, [int()], E, int()}], E, int()}, TypeState2),
    ?assertMatch({tfn, [{tfn, [_], {tvar, _}, _}], {tvar, _}, _}, Shared),
    %% one that is a parameter's function's own, and nothing else, stays
    {#scheme{type = Parameter}, _} =
        ern_types:generalize({tfn, [{tfn, [int()], E, int()}], none, int()}, TypeState2),
    ?assertMatch({tfn, [{tfn, [_], {tvar, _}, _}], none, _}, Parameter),
    ?assertEqual("((Int) -> Int receiving e) -> Int", ern_types:format(Parameter, TypeState2)),
    %% one that is a result's function's own becomes none
    {#scheme{type = Result}, _} =
        ern_types:generalize({tfn, [], none, {tfn, [int()], E, int()}}, TypeState2),
    ?assertEqual({tfn, [], none, {tfn, [int()], none, int()}}, Result),
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
    ?assertEqual("() -> Int", ern_types:format({tfn, [], none, int()}, TypeState3)),
    %% report §11.5: an effect variable that occurs once prints as none
    ?assertEqual("(a, b) -> a", ern_types:format({tfn, [A, B], E, A}, TypeState3)),
    ?assertEqual("() -> Address(a) receiving a",
                 ern_types:format({tfn, [], A, {tcon, ['Address'], [A]}}, TypeState3)),
    ?assertEqual("((a) -> b receiving e, a) -> b receiving e",
                 ern_types:format({tfn, [{tfn, [A], E, B}, A], E, B}, TypeState3)),
    %% report §3.4: `receiving` binds to the nearest arrow, so a function
    %% result is parenthesized only under an outer `receiving`. A regression
    %% test: an
    %% outer effect printed after a bare result, which reads as the
    %% result's
    ?assertEqual("(Int) -> (Int) -> Int receiving Never",
                 ern_types:format({tfn, [int()], none,
                                   {tfn, [int()], {tcon, ['Never'], []}, int()}}, TypeState3)),
    ?assertEqual("(Int) -> ((Int) -> Int) receiving Never",
                 ern_types:format({tfn, [int()], {tcon, ['Never'], []},
                                   {tfn, [int()], none, int()}}, TypeState3)),
    ?assertEqual("(Int) -> (Int) -> Int",
                 ern_types:format({tfn, [int()], none, {tfn, [int()], none, int()}}, TypeState3)),
    TypeState4 = ern_types:add_restriction(A, equality, TypeState3),
    ?assertEqual("(a=, a=) -> Bool", ern_types:format({tfn, [A, A], none, bool()}, TypeState4)).

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
    ?assertEqual({"(xs : List(a), ", "f : (a) -> b receiving e", ") : List(b) receiving e"},
                 ern_types:format_call(Scheme, [xs, f], 1, TypeState3)),
    ?assertEqual({"(", "List(a)", ", (a) -> b receiving e) -> List(b) receiving e"},
                 ern_types:format_call(Scheme, none, 0, TypeState3)),
    ?assertEqual({"(", "List(a)", ", (a) -> b receiving e) : List(b) receiving e"},
                 ern_types:format_call(Scheme, ['_', '_'], 0, TypeState3)),
    %% an argument past the last parameter marks nothing
    ?assertEqual({"(List(a), (a) -> b receiving e) -> List(b) receiving e", "", ""},
                 ern_types:format_call(Scheme, none, 2, TypeState3)),
    ?assertEqual({"() : Int", "", ""},
                 ern_types:format_call(#scheme{type = {tfn, [], none, int()}}, [], 0, TypeState3)),
    ?assertEqual({"Int", "", ""},
                 ern_types:format_call(#scheme{type = int()}, none, 0, TypeState3)).

%% report §11.5
format_error_test() ->
    ?assertEqual("a function of 2 arguments where one of 1 was expected",
                 ern_types:format_error({arity, 1, 2})),
    ?assertEqual("a function that receives nothing where one that receives is needed",
                 ern_types:format_error(none_where_mailbox_needed)),
    ?assertEqual("a function that receives where one that receives nothing is needed",
                 ern_types:format_error(mailbox_where_none_needed)).
