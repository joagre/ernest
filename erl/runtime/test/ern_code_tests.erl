%% Tests of ern_code: the code table of report §8.7, filled as a unit
%% loads, its lookups, and the host's limits of §11.2, said once each at
%% four fifths. The table's fill by `ern run` over a build of two modules
%% is erl/cli/test/ern_cli_tests.erl's code_table_test. Regression tests,
%% written after the code. They do not cover a line said by a run that has
%% loaded four fifths of a limit, which no test can approach: the decision
%% is tested on given counts, and the host's counts are read.
-module(ern_code_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typer/include/ern_canonical.hrl").

%% A module compiled as the build compiles it, with its canonical forms and
%% the '$code'/0 the table reads, loaded, and put in the table as the
%% runner puts a unit; its compiled bytes.
loaded(Namespace, Text) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => []},
    {ok, Unit, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    ok = ern_code:loaded(Unit),
    Beam.

definitions(Beam) ->
    {ok, Definitions} = ern_canonical:read(Beam),
    maps:from_list([{QualifiedName, Definition}
                    || #definition{qualified_name = QualifiedName} = Definition <- Definitions]).

hash(QualifiedName, Definitions) ->
    (maps:get(QualifiedName, Definitions))#definition.hash.

-define(SOURCE,
        "export type Box = Box(Int)\n"
        "export fn Box.compare(a : Box, b : Box) : Ordering = Equal\n"
        "export fn twice(n : Int) : Int = n * 2\n"
        "fn hidden(n : Int) : Int = n + 1\n"
        "export let answer : Int = hidden(41)\n"
        "export foreign fn backwards(list : List(Int)) : List(Int) = \"lists:reverse/1\"\n").

%% report §8.7: a unit's load puts each of its definitions in the code table
%% by its identity, the hash its canonical form has, with the unit and the
%% function that hold it: a function, a member and a private function by
%% their hashes, a type by its hash, a binding by its qualified name with
%% its hash; each identity by its qualified name; a foreign declaration's
%% implementation by its qualified name
unit_load_fills_table_test() ->
    Beam = loaded(['Tablefill'], ?SOURCE),
    Definitions = definitions(Beam),
    Unit = 'ern@tablefill',
    Twice = hash(['Tablefill', twice], Definitions),
    ?assertEqual({Unit, twice, 1}, ern_code:function(Twice)),
    ?assertEqual({Unit, 'Box.compare', 2},
                 ern_code:function(hash(['Tablefill', 'Box', compare], Definitions))),
    ?assertEqual({Unit, hidden, 1}, ern_code:function(hash(['Tablefill', hidden], Definitions))),
    ?assertEqual(Twice, ern_code:identity(['Tablefill', twice])),
    Box = hash(['Tablefill', 'Box'], Definitions),
    ?assertEqual(Box, ern_code:identity(['Tablefill', 'Box'])),
    ?assertEqual(none, ern_code:function(Box)),
    Answer = hash(['Tablefill', answer], Definitions),
    ?assertEqual({['Tablefill', answer], Answer}, ern_code:identity(['Tablefill', answer])),
    ?assertEqual({lists, reverse}, ern_code:foreign(['Tablefill', backwards])),
    ?assertEqual(none, ern_code:identity(['Tablefill', backwards])),
    ?assertEqual(none, ern_code:identity(['Tablefill', missing])),
    %% every definition the chunk holds, and nothing else
    ?assertEqual(lists:sort(maps:keys(Definitions)),
                 lists:sort([QualifiedName || {QualifiedName, Held} <- Unit:'$code'(),
                                              element(1, Held) =/= foreign])),
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit).

%% report §8.7, §11.1: what a spawn on a peer names is in the table by its
%% identity, with the function that runs it, the number of values it
%% captured and its reach: a function by its hash, its reach the bindings
%% and the foreign declarations it names through the functions it calls;
%% a lambda a spawn on a peer starts by its definition's hash and its
%% position, its reach its own; and a foreign function by its qualified
%% name. A regression test, written after the code (MVP 3.1's item 4)
spawnable_test() ->
    Beam = loaded(['Tablespawn'],
                  "let note : Int = 1\n"
                  "foreign fn now() : Int with m = \"erlang:monotonic_time/0\"\n"
                  "fn noted() : Unit with Never = { let _ = note + now(); Unit }\n"
                  "export fn calls() : Unit with Never = noted()\n"
                  "export fn start(n : Int) : Either(Io.Error, Address(Never)) with m = {\n"
                  "    let _ = calls;\n"
                  "    Peer.spawn(\"p\", fn() : Unit with Never = { let _ = n; Unit }, 100)\n"
                  "}\n"),
    Definitions = definitions(Beam),
    Unit = 'ern@tablespawn',
    Note = {['Tablespawn', note], hash(['Tablespawn', note], Definitions)},
    Reach = {[Note], [['Tablespawn', now]]},
    ?assertEqual({Unit, calls, 0, Reach},
                 ern_code:spawnable({hash, hash(['Tablespawn', calls], Definitions)})),
    ?assertEqual({Unit, 'start$spawn$1', 1, {[], []}},
                 ern_code:spawnable({lambda, hash(['Tablespawn', start], Definitions), 1})),
    ?assertEqual({Unit, now, 0, {[], [['Tablespawn', now]]}},
                 ern_code:spawnable({foreign, ['Tablespawn', now]})),
    ?assertEqual(none, ern_code:spawnable({lambda, hash(['Tablespawn', start], Definitions), 2})),
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit).

%% report §8.7: a unit loaded again with other code replaces its rows, so
%% that a definition it no longer holds is found nowhere; one loaded again
%% with the same code is passed over; one unloaded takes its rows with it
unit_loaded_again_replaces_its_rows_test() ->
    Before = definitions(loaded(['Tablereload'], "export fn f(n : Int) : Int = n + 1\n")),
    F1 = hash(['Tablereload', f], Before),
    ?assertEqual({'ern@tablereload', f, 1}, ern_code:function(F1)),
    After = definitions(loaded(['Tablereload'], "export fn f(n : Int) : Int = n + 2\n")),
    F2 = hash(['Tablereload', f], After),
    ?assertNotEqual(F1, F2),
    ?assertEqual(none, ern_code:function(F1)),
    ?assertEqual({'ern@tablereload', f, 1}, ern_code:function(F2)),
    ?assertEqual(F2, ern_code:identity(['Tablereload', f])),
    ok = ern_code:loaded('ern@tablereload'),
    ?assertEqual(F2, ern_code:identity(['Tablereload', f])),
    ern_code:unloaded('ern@tablereload'),
    ?assertEqual(none, ern_code:function(F2)),
    ?assertEqual(none, ern_code:identity(['Tablereload', f])),
    code:purge('ern@tablereload'),
    code:delete('ern@tablereload').

%% report §8.7: two definitions with one body are one definition, held by
%% two units; one unit's unload leaves the other's row
one_hash_in_two_units_test() ->
    Text = "export fn same(n : Int) : Int = n * 3\n",
    Hash = hash(['Tablesame', same], definitions(loaded(['Tablesame'], Text))),
    Hash = hash(['Tableother', same], definitions(loaded(['Tableother'], Text))),
    ern_code:unloaded('ern@tablesame'),
    ?assertEqual({'ern@tableother', same, 1}, ern_code:function(Hash)),
    ern_code:unloaded('ern@tableother'),
    ?assertEqual(none, ern_code:function(Hash)),
    [begin code:purge(Unit), code:delete(Unit) end || Unit <- ['ern@tablesame', 'ern@tableother']].

%% report §8.7, §8.5: a binding's value by its identity, in the run in
%% progress: its value where its unit's initializers have run, absent where
%% they have not, and none where no unit holds it
binding_value_test() ->
    Run = definitions(loaded(['Tableran'], "export let answer : Int = 6 * 7\n")),
    NotRun = definitions(loaded(['Tablenotrun'], "export let other : Int = 1\n")),
    Ran = {['Tableran', answer], hash(['Tableran', answer], Run)},
    Unrun = {['Tablenotrun', other], hash(['Tablenotrun', other], NotRun)},
    Unknown = {['Tableran', gone], <<0:256>>},
    Self = self(),
    Entry = fun() ->
                Self ! {values, [ern_code:value(Identity) || Identity <- [Ran, Unrun, Unknown]]}
            end,
    ok = ern_rt:run_main(Entry, <<"main">>,
                         #{init => fun() -> ern_rt:init_modules(['ern@tableran']) end,
                           stdout => fun(_) -> ok end}),
    ?assertEqual({values, [{value, 42}, absent, none]}, receive {values, _} = V -> V end),
    [begin ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit) end
     || Unit <- ['ern@tableran', 'ern@tablenotrun']].

%% report §8.7: a module a foreign declaration names is on the node where it
%% is loaded, or where the host would load it from
foreign_module_present_test() ->
    ?assert(ern_code:present(lists)),
    ?assert(ern_code:present(ern_char)),
    ?assertNot(ern_code:present('ern_no_such_module')).

%% report §11.2: the host's limits as the host states them under OTP 29,
%% each with how much of it is used: 65,536 module names, 524,288 export
%% entries, 524,288 lambdas, and the atoms its own function bounds
host_counts_test() ->
    Counts = ern_code:counts(),
    ?assertEqual([module_names, exports, lambdas, atoms], [Table || {Table, _, _} <- Counts]),
    #{module_names := {Modules, 65536}, exports := {_, 524288}, lambdas := {_, 524288},
      atoms := {_, AtomLimit}} = maps:from_list([{Table, {Entries, Limit}}
                                                 || {Table, Entries, Limit} <- Counts]),
    ?assertEqual(erlang:system_info(atom_limit), AtomLimit),
    ?assert(Modules >= length(code:all_loaded())),
    ?assert(lists:all(fun({_, Entries, Limit}) -> Entries > 0 andalso Entries < Limit end,
                      Counts)).

%% report §11.2: a limit is said where the host's use has reached four fifths
%% of it, and not below; one said already is not said again
four_fifths_test() ->
    ?assertEqual([], ern_code:nearing([{module_names, 52428, 65536}], [])),
    ?assertEqual([module_names], ern_code:nearing([{module_names, 52429, 65536}], [])),
    ?assertEqual([lambdas, atoms],
                 ern_code:nearing([{module_names, 1, 65536}, {exports, 419430, 524288},
                                   {lambdas, 419431, 524288}, {atoms, 1048576, 1048576}],
                                  [])),
    ?assertEqual([atoms], ern_code:nearing([{lambdas, 524288, 524288},
                                            {atoms, 900000, 1048576}],
                                           [lambdas])).

%% report §11.2: the line, as the report writes it, said once in the
%% runtime's life for each bound, given the counts a load would read
said_once_test() ->
    Counts = [{module_names, 52429, 65536}, {exports, 10, 524288}, {lambdas, 10, 524288},
              {atoms, 10, 1048576}],
    ?assertEqual([<<"the host has used 52429 of its 65536 module names,"
                    " which it never gives back">>],
                 ern_code:nearing(Counts)),
    ?assertEqual([], ern_code:nearing(Counts)),
    ?assertEqual([<<"the host has used 419431 of its 524288 export entries,"
                    " which it never gives back">>],
                 ern_code:nearing(lists:keyreplace(exports, 1, Counts,
                                                   {exports, 419431, 524288}))),
    %% the test's own lines forgotten, so that the host's are said
    ets:delete(ern_code, {said, module_names}),
    ets:delete(ern_code, {said, exports}).
