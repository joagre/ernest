%% Tests of ern_code: the code table of report §8.7, filled as a unit
%% loads, its lookups, and the host's limits of §11.2, said once each at
%% four fifths. The table's fill by `ern run` over a build of two modules
%% is erl/cli/test/ern_cli_tests.erl's code_table_test. Regression tests,
%% written after the code. The decision is tested on given counts, and the
%% host's counts are read; the line a run says once its atoms reach four
%% fifths of the limit is test/ern_integration_tests.erl's, which fills
%% them in a host of its own.
-module(ern_code_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("checker/include/ern_canonical.hrl").

%% A module compiled as the build compiles it, with its canonical forms and
%% the '$code'/0 the table reads, loaded, and put in the table as the
%% runner puts a unit; its compiled bytes.
loaded(Namespace, Text) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => []},
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    code:purge(Unit),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    ok = ern_code:loaded(Unit, Beam),
    Beam.

definitions(Beam) ->
    {ok, #recorded{definitions = Definitions}} = ern_canonical:read(Beam),
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

%% report §11.2, §8.7: a unit loaded from its compiled form's file is
%% described by the forms that file records while it holds the unit's code,
%% and by none once the file holds other code, as where a build is written
%% under a running node, so that no load takes the unit for one made of
%% the file's forms and no peer is sent forms the code was not compiled
%% from. A regression test, written after the code: the forms were read
%% from whatever the file held when first asked for
file_forms_hold_the_units_code_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                        "ern_code_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    File = filename:join(Dir, "tablefile.erc"),
    Compiled = fun(Text) ->
                   {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Tablefile'], Text),
                   {ok, _, Beam} = ern_compile:compile(['Tablefile'], Typed, Interface, Env,
                                                       #{source_hash => <<>>, deps => []}),
                   Beam
               end,
    First = Compiled("export fn one() : Int = 1\n"),
    Second = Compiled("export fn two() : Int = 2\n"),
    Unit = 'ern@tablefile',
    ok = file:write_file(File, First),
    {module, Unit} = code:load_binary(Unit, File, First),
    ok = ern_code:loaded(Unit, First),
    ok = file:write_file(File, Second),
    Changed = ern_code:forms(Unit),
    ok = file:write_file(File, First),
    {ok, Recorded} = ern_canonical:read(First),
    Held = ern_code:forms(Unit),
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit),
    code:purge(Unit),
    ?assertEqual(none, Changed),
    ?assertEqual({ok, Recorded}, Held).

%% report §11.1, §11.2: a unit of the toolchain's own is no `.beam` of the
%% code path but its `.erc`, found by the namespace its Erlang name gives
%% in the standard library's directory, here a test's, and loaded from it
%% at its first call: through the runtime's error handler, which every
%% process the runtime starts has, and through a lookup by name, which a
%% job's process makes, and in the code table as it loads. A module no
%% build of the toolchain's holds has no such file. A regression test,
%% written after the code; it does not cover the shell's build and its
%% libraries', which the shell's tests and `ern doc --man`'s reach
own_unit_loaded_at_first_call_test() ->
    Dir = filename:join([os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
                         "ern_code_" ++ os:getpid() ++ "_"
                         ++ integer_to_list(erlang:unique_integer([positive])), "stdlib"]),
    ok = filelib:ensure_path(Dir),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Firstcall'],
                                                             "export fn one() : Int = 1\n"),
    {ok, Unit, Beam} = ern_compile:compile(['Firstcall'], Typed, Interface, Env,
                                           #{source_hash => <<>>, deps => []}),
    File = filename:join(Dir, "firstcall.erc"),
    ok = file:write_file(File, Beam),
    Library = ern_prelude:set_stdlib_directory(Dir),
    Gone = fun() -> ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit),
                    code:purge(Unit) end,
    try
        ?assertEqual({ok, File}, ern_code:own_file(Unit)),
        ?assertEqual(none, ern_code:own_file('ern@firstcall@absent')),
        ?assertEqual(none, ern_code:own_file(lists)),
        Self = self(),
        {ok, {Unit, Md5}} = beam_lib:md5(Beam),
        %% the host calls an error handler only where it holds its code
        {module, ern_rt} = code:ensure_loaded(ern_rt),
        _ = spawn(fun() ->
                      erlang:process_flag(error_handler, ern_rt),
                      Self ! {called, Unit:module_info(md5)}
                  end),
        ?assertEqual(Md5, receive {called, Called} -> Called after 5000 -> none end),
        ?assertEqual({file, File}, code:is_loaded(Unit)),
        Gone(),
        ?assertMatch({_, 0}, ern_code:function(Unit, ['Firstcall', one])),
        ?assertEqual({file, File}, code:is_loaded(Unit))
    after
        ern_prelude:set_stdlib_directory(Library),
        Gone(),
        file:delete(File)
    end.

%% report §8.7: a unit's load puts each of its definitions in the code table
%% by its identity, the hash its canonical form has, with the unit and the
%% function that hold it, read as the runtime reads them: a function, a
%% member and a private function by their hashes, which a spawn finds; a
%% type by its hash, which runs nothing; a binding by its qualified name
%% with its hash, whose value a run finds absent before its unit's
%% initializers have run; a foreign declaration's implementation by its
%% qualified name; and the units its code calls, here none. Report §11.1:
%% each function is named by its number in the unit, the definitions in the
%% order of their forms, the type Box taking 1, and the foreign function
%% after them
unit_load_fills_table_test() ->
    Beam = loaded(['Tablefill'], ?SOURCE),
    Definitions = definitions(Beam),
    Unit = 'ern@tablefill',
    ?assertEqual({Unit, '$3', 1, {[], []}},
                 ern_code:spawnable({hash, hash(['Tablefill', twice], Definitions)})),
    ?assertEqual({Unit, '$2', 2, {[], []}},
                 ern_code:spawnable({hash, hash(['Tablefill', 'Box', compare], Definitions)})),
    ?assertEqual({Unit, '$4', 1, {[], []}},
                 ern_code:spawnable({hash, hash(['Tablefill', hidden], Definitions)})),
    ?assertEqual(none, ern_code:spawnable({hash, hash(['Tablefill', 'Box'], Definitions)})),
    Answer = {['Tablefill', answer], hash(['Tablefill', answer], Definitions)},
    Missing = {['Tablefill', missing], <<0:256>>},
    Self = self(),
    Entry = fun() ->
                Self ! {absent, [ern_code:absent_binding(Unit, [Identity])
                                 || Identity <- [Answer, Missing]]}
            end,
    ok = ern_rt:run_main(Entry, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual({absent, [Answer, Missing]}, receive {absent, _} = Absent -> Absent end),
    Called = ern_code:called(Unit),
    ?assertEqual(#{Unit => true}, Called),
    ?assertEqual([{Unit, lists, reverse}], ern_code:foreign(Called, ['Tablefill', backwards])),
    ?assertEqual([{Unit, lists, reverse}],
                 ern_code:foreign(Called, [<<"Tablefill">>, <<"backwards">>])),
    ?assertEqual({Unit, '$6', 1, {[], [['Tablefill', backwards]]}},
                 ern_code:spawnable({foreign, ['Tablefill', backwards]})),
    ?assertEqual([], ern_code:foreign(Called, ['Tablefill', missing])),
    %% every definition the chunk holds, and nothing else, the namespace
    %% its sites name its declarations under, and the calls
    ?assertEqual(lists:sort(maps:keys(Definitions)),
                 lists:sort([QualifiedName
                             || {QualifiedName, Held} <- Unit:'$code'(),
                                not lists:member(element(1, Held),
                                                 [foreign, sites, calls])])),
    ?assertEqual([{['Tablefill'], {sites, ['Tablefill']}}],
                 [Sites || {_, {sites, _}} = Sites <- Unit:'$code'()]),
    ?assertEqual([{['Tablefill'], {calls, []}}],
                 [Calls || {_, {calls, _}} = Calls <- Unit:'$code'()]),
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit).

%% report §8.7, §11.1: what another unit's code reaches of this node's by
%% hash: a function its unit exports, with its unit, its function and its
%% reach, and a type, which has no function, by the unit that holds it; a
%% function its unit holds without exporting it is not reached, since a
%% build's unit exports the functions its module exports, so a peer's
%% exchange counts it lacked. A regression test, written after the code;
%% it does not cover two units holding one hash
linkable_test() ->
    Beam = loaded(['Tablelink'], ?SOURCE),
    Definitions = definitions(Beam),
    Unit = 'ern@tablelink',
    ?assertEqual({function, Unit, '$3', 1, {[], []}},
                 ern_code:linkable(hash(['Tablelink', twice], Definitions))),
    ?assertEqual({type, Unit}, ern_code:linkable(hash(['Tablelink', 'Box'], Definitions))),
    ?assertEqual(none, ern_code:linkable(hash(['Tablelink', hidden], Definitions))),
    ?assertEqual(none, ern_code:linkable(<<0:256>>)),
    ern_code:unloaded(Unit),
    code:purge(Unit),
    code:delete(Unit).

%% report §8.7, §11.1: what a spawn on a peer names is in the table by its
%% identity, with the function that runs it, the number of values it
%% captured and its reach: a function by its hash, its reach the bindings
%% and the foreign declarations it names through the functions it calls;
%% a lambda a spawn on a peer starts by its definition's hash and its
%% position, its reach its own; and a foreign function by its qualified
%% name. A regression test, written after the code; the
%% names are the units' functions' by their numbers (report §11.1), the
%% lambda's entry by its definition's and its position
spawnable_test() ->
    Beam = loaded(['Tablespawn'],
                  "let note : Int = 1\n"
                  "foreign fn now() : Int = \"erlang:monotonic_time/0\"\n"
                  "fn noted() : Unit = { let _ = note + now(); Unit }\n"
                  "export fn calls() : Unit = noted()\n"
                  "export fn start(n : Int) : Either(Io.Error, Address(Never)) = {\n"
                  "    let _ = calls;\n"
                  "    Peer.spawn(\"p\", fn() = { let _ = n; Unit }, 100)\n"
                  "}\n"),
    Definitions = definitions(Beam),
    Unit = 'ern@tablespawn',
    Note = {['Tablespawn', note], hash(['Tablespawn', note], Definitions)},
    Reach = {[Note], [['Tablespawn', now]]},
    ?assertEqual({Unit, '$3', 0, Reach},
                 ern_code:spawnable({hash, hash(['Tablespawn', calls], Definitions)})),
    ?assertEqual({Unit, '$4.1.entry', 1, {[], []}},
                 ern_code:spawnable({lambda, hash(['Tablespawn', start], Definitions), 1})),
    ?assertEqual({Unit, '$5', 0, {[], [['Tablespawn', now]]}},
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
    Held = {'ern@tablereload', '$1', 1, {[], []}},
    ?assertEqual(Held, ern_code:spawnable({hash, F1})),
    Again = loaded(['Tablereload'], "export fn f(n : Int) : Int = n + 2\n"),
    After = definitions(Again),
    F2 = hash(['Tablereload', f], After),
    ?assertNotEqual(F1, F2),
    ?assertEqual(none, ern_code:spawnable({hash, F1})),
    ?assertEqual(Held, ern_code:spawnable({hash, F2})),
    ok = ern_code:loaded('ern@tablereload', Again),
    ?assertEqual(Held, ern_code:spawnable({hash, F2})),
    ern_code:unloaded('ern@tablereload'),
    ?assertEqual(none, ern_code:spawnable({hash, F2})),
    code:purge('ern@tablereload'),
    code:delete('ern@tablereload').

%% report §8.7: two definitions with one body are one definition, held by
%% two units; one unit's unload leaves the other's row
one_hash_in_two_units_test() ->
    Text = "export fn same(n : Int) : Int = n * 3\n",
    Hash = hash(['Tablesame', same], definitions(loaded(['Tablesame'], Text))),
    Hash = hash(['Tableother', same], definitions(loaded(['Tableother'], Text))),
    ern_code:unloaded('ern@tablesame'),
    ?assertEqual({'ern@tableother', '$1', 1, {[], []}}, ern_code:spawnable({hash, Hash})),
    ern_code:unloaded('ern@tableother'),
    ?assertEqual(none, ern_code:spawnable({hash, Hash})),
    [begin code:purge(Unit), code:delete(Unit) end || Unit <- ['ern@tablesame', 'ern@tableother']].

%% report §8.7, §8.5, §11.1: a binding by its identity has its value in the
%% run in progress where its unit's initializers have run, and none where
%% they have not, or where no unit holds it; a ground binding has its term
%% wherever its unit is held, its initializers run or not (the ground case
%% a regression test, written after the code)
binding_value_test() ->
    Run = definitions(loaded(['Tableran'], "export let answer : Int = 6 * 7\n")),
    NotRun = definitions(loaded(['Tablenotrun'], "export let other : Int = 1 + 1\n"
                                                 "export let fixed : Int = 1\n")),
    Ran = {['Tableran', answer], hash(['Tableran', answer], Run)},
    Unrun = {['Tablenotrun', other], hash(['Tablenotrun', other], NotRun)},
    Fixed = {['Tablenotrun', fixed], hash(['Tablenotrun', fixed], NotRun)},
    Unknown = {['Tableran', gone], <<0:256>>},
    Self = self(),
    Entry = fun() ->
                Self ! {absent, [ern_code:absent_binding('ern@tableran', [Ran]),
                                 ern_code:absent_binding('ern@tablenotrun', [Unrun]),
                                 ern_code:absent_binding('ern@tablenotrun', [Fixed]),
                                 ern_code:absent_binding('ern@tableran', [Ran, Unknown])]}
            end,
    ok = ern_rt:run_main(Entry, <<"main">>,
                         #{init => fun() -> ern_rt:init_modules(['ern@tableran']) end,
                           stdout => fun(_) -> ok end}),
    ?assertEqual({absent, [none, Unrun, none, Unknown]}, receive {absent, _} = V -> V end),
    [begin ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit) end
     || Unit <- ['ern@tableran', 'ern@tablenotrun']].

%% report §8.7, §11.2: two versions of a module, each a unit of its own as
%% the shell's load and reload make them, hold the definitions the second
%% did not change under one identity; a lookup answers, for the function,
%% the latest loaded of the units whose initializers have run, whose code
%% reads its own bindings, and where none has run, the latest loaded, its
%% binding then without its value. The first is a node's build's, loaded at
%% its start and never evaluated, beside a unit the shell's load brought;
%% then both evaluated, as a reload leaves them. A regression test, written
%% after the fix (findings S2, N1, N5): the first unit loaded answered, so
%% a peer's spawn of a function the shell's load had evaluated was refused,
%% the binding said to have no value here, and after a reload a peer found
%% the previous version's value
versions_answer_the_evaluated_unit_test() ->
    Namespace = ['Tableversions'],
    Text = "export let answer : Int = 6 * 7\nexport fn same(n : Int) : Int = n * 3\n",
    Versions = [{'ern@tableversions', #{}},
                {'ern@tableversions$2', #{Namespace => 'ern@tableversions$2'}}],
    [First, Second] =
        [begin
             {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
             Build = #{source_hash => <<>>, deps => [], units => Units},
             {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
             {module, Unit} = code:load_binary(Unit, "test", Beam),
             ok = ern_code:loaded(Unit, Beam),
             definitions(Beam)
         end || {_, Units} <- Versions],
    Same = hash(['Tableversions', same], First),
    Same = hash(['Tableversions', same], Second),
    Answer = {['Tableversions', answer], hash(['Tableversions', answer], First)},
    Self = self(),
    Entry = fun() ->
                {Unit, '$2', 1, _} = ern_code:spawnable({hash, Same}),
                Self ! {answered, Unit, ern_code:absent_binding(Unit, [Answer])}
            end,
    Answered = fun(Initialized) ->
                   Init = fun() -> ern_rt:init_modules(Initialized) end,
                   ok = ern_rt:run_main(Entry, <<"main">>,
                                        #{init => Init, stdout => fun(_) -> ok end}),
                   receive {answered, _, _} = Found -> Found end
               end,
    %% none evaluated: the latest loaded runs a function, without the value
    ?assertEqual({answered, 'ern@tableversions$2', Answer}, Answered([])),
    %% the build's alone evaluated, a node running a program over it
    ?assertEqual({answered, 'ern@tableversions', none}, Answered(['ern@tableversions'])),
    %% the shell's load evaluated and the build's not
    ?assertEqual({answered, 'ern@tableversions$2', none}, Answered(['ern@tableversions$2'])),
    %% both evaluated, as after a reload: the latest version's
    ?assertEqual({answered, 'ern@tableversions$2', none},
                 Answered(['ern@tableversions', 'ern@tableversions$2'])),
    [persistent_term:erase({Unit, answer}) || {Unit, _} <- Versions],
    [begin ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit) end
     || {Unit, _} <- Versions].

%% A module compiled against Interfaces, each namespace Units names called
%% as that unit, its own among them, as the shell compiles a version,
%% loaded and put in the table: its unit, its interface as compiled, and
%% its definitions.
compiled(Namespace, Text, Interfaces, Units) ->
    {ok, Declarations} = ern_parser:parse_string(Text),
    {ok, Typed, Interface, Env} = ern_typecheck:check(Namespace, Declarations, Interfaces),
    Build = #{source_hash => <<>>, deps => [], units => Units},
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    ok = ern_code:loaded(Unit, Beam),
    {ok, #{interface := Compiled}} = ern_interface:read(Beam),
    {Unit, Compiled, definitions(Beam)}.

%% report §8.7, §11.2: a reach's binding is read in the unit the code of
%% the unit that runs the function reads it from, the units its code calls
%% walked: a build's caller, never evaluated, calls the build's greeter,
%% never evaluated either, though a second version of the greeter, which
%% holds the binding under one identity, has been; the caller compiled
%% again against the second version reads the second's. A regression test,
%% written after the fix (finding S2's read-back): the binding was found by
%% its identity alone, in the second version, and the build's caller then
%% ran and read the build's greeter, which had no value
reach_read_where_the_code_reads_test() ->
    Greeter = ['Tablegreet'],
    Caller = ['Tablecaller'],
    Greet = "let greeting : String = if true then \"hello\" else \"bye\"\n"
            "export fn hello() : String = greeting\n",
    Call = "export fn call() : String = Tablegreet.hello()\n",
    Second = #{Greeter => 'ern@tablegreet$2'},
    {_, BuildGreet, BuildGreetDefinitions} = compiled(Greeter, Greet, [], #{}),
    {_, LoadedGreet, _} = compiled(Greeter, [Greet, "export fn other() : Int = 1\n"], [], Second),
    {_, _, CallDefinitions} = compiled(Caller, Call, [BuildGreet], #{}),
    {_, _, _} = compiled(Caller, Call, [LoadedGreet], Second#{Caller => 'ern@tablecaller$2'}),
    Greeting = {['Tablegreet', greeting], hash(['Tablegreet', greeting], BuildGreetDefinitions)},
    {_, _, _, {[Greeting], []}} = ern_code:spawnable({hash, hash(['Tablecaller', call],
                                                                 CallDefinitions)}),
    ?assertEqual(#{'ern@tablecaller' => true, 'ern@tablegreet' => true},
                 ern_code:called('ern@tablecaller')),
    Self = self(),
    Entry = fun() ->
                Self ! {absent, [ern_code:absent_binding(Unit, [Greeting])
                                 || Unit <- ['ern@tablecaller', 'ern@tablecaller$2']]}
            end,
    Absent = fun(Initialized) ->
                 Init = fun() -> ern_rt:init_modules(Initialized) end,
                 ok = ern_rt:run_main(Entry, <<"main">>,
                                      #{init => Init, stdout => fun(_) -> ok end}),
                 receive {absent, Found} -> Found end
             end,
    ?assertEqual([Greeting, none], Absent(['ern@tablegreet$2'])),
    ?assertEqual([none, none], Absent(['ern@tablegreet', 'ern@tablegreet$2'])),
    Units = ['ern@tablegreet', 'ern@tablegreet$2', 'ern@tablecaller', 'ern@tablecaller$2'],
    [persistent_term:erase({Unit, greeting}) || Unit <- Units],
    [begin ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit) end || Unit <- Units].

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

%% report §11.2: the host's counts are kept as sums, the host's own from
%% the first load on: a unit loaded adds a module name, an export entry for
%% each function its export and import tables name, and a function entry
%% for each lambda its table of lambdas names; and a sum that reaches four
%% fifths reads the host's counts before any line is said, so that, the
%% host's own count below it, no line is said and the sums are the host's
%% counts from then on. A regression test, written with the code
sums_test() ->
    _ = loaded(['Tablesums'], "export fn f(n : Int) : Int = n + 1\n"),
    Sums = fun() ->
               maps:from_list([{Table, Sum} || {Table, Sum, _} <- ets:tab2list(ern_code_sums)])
           end,
    Before = Sums(),
    Beam = loaded(['Tablesumstwo'],
                  "export fn g(n : Int) : Int = List.foldLeft([n], 0, fn(acc, x) = acc + x)\n"),
    {ok, {_, Chunks}} = beam_lib:chunks(Beam, ["ExpT", "ImpT", "FunT"]),
    [Exports, Imports, Lambdas] = [Count || {_, <<Count:32, _/binary>>} <- Chunks],
    ?assert(Lambdas > 0),
    ?assertEqual(#{module_names => maps:get(module_names, Before) + 1,
                   exports => maps:get(exports, Before) + Exports + Imports,
                   lambdas => maps:get(lambdas, Before) + Lambdas},
                 Sums()),
    true = ets:insert(ern_code_sums, {module_names, 52429, 65536}),
    ?assertEqual([], ern_code:nearing()),
    [{module_names, Host, 65536} | _] = ern_code:counts(),
    ?assertEqual(Host, maps:get(module_names, Sums())),
    ?assert(Host < 52429),
    [begin ern_code:unloaded(Unit), code:purge(Unit), code:delete(Unit) end
     || Unit <- ['ern@tablesums', 'ern@tablesumstwo']].

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

%% Appendix E.21, §7.4, §12.3: a trace leaves out a frame of the runtime's
%% wherever it stands, one of a unit that names no definition of the
%% program's among them, a helper the compiler writes into the unit, the
%% boundary's wrapper here; a failure's trace keeps it, as the host writes
%% the function, quoted where the host quotes it, as a frame of the
%% host's is. A regression test, written after the code: the wrapper's
%% frame was printed in host form in every trace; it does not cover a
%% unit an exchange made, whose names are a peer's text
trace_leaves_out_a_units_helper_test() ->
    _ = loaded(['Tracehelper'], "export fn main() : Int = 1\n"),
    Unit = 'ern@tracehelper',
    try
        {Main, 0} = ern_code:function(Unit, ['Tracehelper', main]),
        Stack = [{Unit, '-$type_1/0-fun-0-', 3, []}, {lists, map, 2, [{line, 1}]},
                 {Unit, Main, 0, [{line, 3}]}],
        ?assertEqual(<<"lists:map/2:1\nTracehelper.main:3\n">>, ern_rt:trace(Stack)),
        ?assertEqual(<<"ern@tracehelper:'-$type_1/0-fun-0-'/3\nlists:map/2:1\n"
                       "Tracehelper.main:3\n">>, ern_rt:failure_trace(Stack))
    after
        ern_code:unloaded(Unit),
        code:purge(Unit),
        code:delete(Unit),
        code:purge(Unit)
    end.
