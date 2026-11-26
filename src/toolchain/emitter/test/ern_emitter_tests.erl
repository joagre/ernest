%% The emitter's tests: the code it makes and the programs it compiles,
%% run as the runner runs them (report §8.5, §11.2) by ern_program:run/3.
-module(ern_emitter_tests).

-export([write_golden/0, frame_of/1, poke/1, stack_here/0, stack_size/0, calls_held/0, pair/0,
         funs/0, opt/1, improper/1, remember/1, junk/1, good/1, tell/1, junk_server/0,
         hello_junk/0, hello_good/0, relay_junk/1, relay_good/1, same/1, identical/2,
         call_nested_bad/1, call_nested_good/1, ask_junk/1, ask_good/1, checker_ended/1]).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("checker/include/ern_canonical.hrl").
-include_lib("emitter/include/ern_unit.hrl").
-include_lib("builder/include/ern_build.hrl").
-include_lib("runtime/include/ern_rt.hrl").

%% Appendix E.21, report §12.3: the first line of the trace of a foreign
%% `binary_to_integer/1` given text that is no integer, its frame and what
%% the host says of the raise.
-define(UNPARSED, <<"erlang:binary_to_integer/1, argument 1: not a textual representation of an"
                    " integer">>).

%% The same, given an integer.
-define(NOT_TEXT, <<"erlang:binary_to_integer/1, argument 1: not a binary">>).

%%
%% Helpers
%%

%% report §11: a declaration the checker would not have passed is a defect
%% of the toolchain, which the emitter raises as one, for `ern` to report
%% as its own failure, and never answers as a program's diagnostic. The
%% typed tree is the checker's with a block's last expression taken away,
%% as no program can write it. A regression test: the emitter answered a
%% diagnostic, which `make untested` found no test ever reached.
emitter_defect_test() ->
    {ok, Typed, Interface, Env} =
        ern_typecheck:check_string(['M'], "fn f() : Int = {\n    let x = 1;\n    x\n}\n"),
    Broken = without_last_statement(Typed),
    ?assertError({emitter_defect, _, "a block ends with a `let`"},
                 ern_compile:compile(['M'], Broken, Interface, Env)).

without_last_statement(#e_block{statements = Statements} = Block) ->
    Block#e_block{statements = lists:droplast(Statements)};
without_last_statement(Node) when is_tuple(Node) ->
    list_to_tuple([without_last_statement(Element) || Element <- tuple_to_list(Node)]);
without_last_statement(Nodes) when is_list(Nodes) ->
    [without_last_statement(Element) || Element <- Nodes];
without_last_statement(Other) ->
    Other.

%% What a run ended with, its output left aside.
outcome(Text) ->
    {Result, _} = ern_program:run(Text),
    Result.

%% The cause of a run that faulted.
cause_of({fault, Cause, _}) -> Cause.

%% Report §12.3: the cause of a return of the foreign function Named that
%% does not match Type, Part naming the first part that fails and the
%% host's term there.
return_cause(Named, Type, Part) ->
    iolist_to_binary(["the return of foreign function ", Named, " does not match ", Type, ": ",
                      Part]).

example(Base) ->
    {ok, Source} = file:read_file(source_file(Base)),
    {[list_to_atom(string:titlecase(Base))], Source}.

%% Two of the programs are examples a reader opens; the others are kept
%% for the tests.
source_file(Base) when Base =:= "hello"; Base =:= "services" ->
    "examples/" ++ Base ++ ".ern";
source_file(Base) ->
    "test/fixtures/programs/" ++ Base ++ ".ern".

%% The forms of an example and of a target file, made comparable: no
%% annotations, and variables renamed in order of first occurrence, each
%% clause's pattern variables fresh in that clause, so that a hand-written
%% target may reuse a name across clauses where the emitter does not.
example_forms(Base) ->
    {Namespace, Source} = example(Base),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    normalize(ern_compile:forms(Namespace, Typed, Env)).

target_forms(File) ->
    {ok, Forms} = epp:parse_file("test/fixtures/target/" ++ File, []),
    normalize([Form || Form <- Forms, not is_eof(Form), not is_file_attribute(Form)]).

is_eof({eof, _}) -> true;
is_eof(_) -> false.

is_file_attribute({attribute, _, file, _}) -> true;
is_file_attribute(_) -> false.

normalize(Forms) ->
    [normalized(Form) || Form <- Forms].

normalized(Form) ->
    {Renamed, _} = rename(Form, {#{}, 0}),
    erl_parse:map_anno(fun(_) -> 0 end, erl_syntax:revert(Renamed)).

%% State: {Name => New, Counter}.
rename(Node, {Names, Counter} = State) ->
    case erl_syntax:type(Node) of
        variable ->
            Name = erl_syntax:variable_name(Node),
            case Names of
                #{Name := New} -> {erl_syntax:variable(New), State};
                _ ->
                    New = list_to_atom("V" ++ integer_to_list(Counter)),
                    {erl_syntax:variable(New), {Names#{Name => New}, Counter + 1}}
            end;
        clause ->
            Patterns = erl_syntax:clause_patterns(Node),
            PatternVariables = lists:append([sets:to_list(erl_syntax_lib:variables(Pattern))
                                             || Pattern <- Patterns]),
            Inner = {maps:without(PatternVariables, Names), Counter},
            {Patterns1, State1} = lists:mapfoldl(fun rename/2, Inner, Patterns),
            {Guard, State2} = case erl_syntax:clause_guard(Node) of
                                  none -> {none, State1};
                                  GuardNode -> rename(GuardNode, State1)
                              end,
            {Body, {_, Next}} = lists:mapfoldl(fun rename/2, State2, erl_syntax:clause_body(Node)),
            {erl_syntax:clause(Patterns1, Guard, Body), {Names, Next}};
        _ ->
            case erl_syntax:subtrees(Node) of
                [] -> {Node, State};
                Groups ->
                    {Groups1, State1} =
                        lists:mapfoldl(fun(Group, Acc) ->
                                           lists:mapfoldl(fun rename/2, Acc, Group)
                                       end, State, Groups),
                    {erl_syntax:update_tree(Node, Groups1), State1}
            end
    end.

%%
%% Golden tests: the emitter reproduces the hand-written targets
%%

%% report §11, and docs/otp_bugs.md's report 3, the compiler's validator
%% refusing what its type pass made through rem: a module the host's own validator refuses,
%% its type pass narrowing a recursive function's parameter to a range the
%% call's argument breaks, is compiled again without that pass, and runs.
%% Written with the workaround; the shape is the one `make test-typed`
%% found (seed 74183997), reduced. It also holds that the host still
%% refuses the module, so that it fails, and says the workaround can go,
%% once an OTP with the fix runs it
validator_refusal_compiled_again_test() ->
    Text = "fn h(xs : List(Int), acc : Int) : Int =\n"
           "    match xs {\n"
           "        [] -> acc\n"
           "      | x :: rest -> h(rest, x % (x - 3))\n"
           "    }\n"
           "\n"
           "export fn main() : Unit = Io.println(Int.toString(h([1000, -79], -62)))\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    Forms = ern_compile:forms(['M'], Typed, Env),
    ?assertMatch({error, [{_, [{_, beam_validator, _} | _]}], _},
                 compile:noenv_forms(Forms, [return_errors])),
    ?assertEqual({ok, <<"-79\n">>}, ern_program:run(Text)).

%% report §3.5, §4.8, §5.8, §11.1, and docs/otp_bugs.md's report 27, the
%% compiler's destructive update pass growing a literal binary in place: a
%% field selected from an `if` whose arm the host's compiler can tell
%% builds the record with "", the left operand of `<>`, compiles to an
%% append in place onto that literal, which ends the host, unless the
%% emitter turns the pass off. A regression test; the shape is the one
%% `make test-typed` found, reduced. The compiled module is read before it
%% runs, so that a module with the defect fails the test and does not end
%% the test's host. It also holds that the host's pass still appends in
%% place where the module makes no writable binary, so that it fails, and
%% says the workaround can go, once an OTP with the fix runs it
literal_grown_in_place_test() ->
    Text = "type Box = Box(item : String)\n"
           "\n"
           "fn suffixed(flag : Bool, suffix : String) : String =\n"
           "    (if flag then Box(item = \"\") else Box(item = \"a\")).item <> suffix\n"
           "\n"
           "export fn main() : Unit =\n"
           "    Io.println(suffixed(true, \"x\"))\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], Text),
    {ok, _, Faulty} = compile:noenv_forms(ern_compile:forms(['M'], Typed, Env), [return_errors]),
    {beam_file, _, _, _, _, Functions} = beam_disasm:file(Faulty),
    ?assertMatch([_ | _], appends_in_place(Faulty)),
    ?assertNot(lists:member(bs_init_writable,
                            lists:append([Code || {function, _, _, _, Code} <- Functions]))),
    {ok, _, Beam} = ern_compile:compile(['M'], Typed, Interface, Env),
    ?assertEqual([], appends_in_place(Beam)),
    ?assertEqual({ok, <<"x\n">>}, ern_program:run(Text)).

%% The instructions of a compiled unit that grow a binary in place, the
%% host's `private_append`.
appends_in_place(Beam) ->
    {beam_file, _, _, _, _, Functions} = beam_disasm:file(Beam),
    [Instruction || {function, _, _, _, Code} <- Functions,
                    {bs_create_bin, _, _, _, _, _, {list, [{atom, private_append} | _]}}
                        = Instruction <- Code].

%% report §8.6, Appendix E.0 rule 1: a function the standard library is
%% given runs as Ernest code, not as foreign code, so that a deadlock in it
%% is found, the host's frames of the library's primitive beneath it.
%% Written with the rule that has the library stand on the host: such a
%% primitive was counted, and a callback waiting for what no one sends hid
%% the deadlock, the program never ending
standard_shim_callback_deadlock_test_() ->
    {timeout, 30, fun standard_shim_callback_deadlock/0}.

standard_shim_callback_deadlock() ->
    Text = "foreign fn applied(f : (Int) -> Int receiving e, args : List(Int)) : Int receiving e"
           " =\n"
           "    \"erlang:apply/2\"\n"
           "\n"
           "export fn main() : Unit receiving Int =\n"
           "    Io.println(Int.toString(applied(fn(x : Int) : Int receiving Int = receive {\n"
           "        n -> n + x\n"
           "    }, [1])))\n",
    ?assertMatch({{fault, <<"deadlock">>, _}, _}, ern_program:run(
        ['M'], Text, #{standard => true})).

%% report §11.1: a call of a foreign function of the standard library's
%% is a call of the host's function its declaration names, written and
%% through a pipe, and one the host compiles to an instruction is that
%% instruction, so that `Int.bitAnd` and its kin call nothing. A regression
%% test, written after the code; it does not cover a call of the function
%% taken as a value, which calls the declaration's own function.
shim_call_is_the_host_function_test() ->
    %% exported, so that the host's compiler knows nothing of its arguments
    Text = "export fn mixed(x : Int, y : Int) : Int =\n"
           "    Int.bitAnd(Int.bitXor(x, y), y |> Int.bitOr(3))\n"
           "\n"
           "export fn main() : Unit = Io.println(Int.toString(mixed(12, 10)))\n",
    Code = function_code(Text, '$1'),
    ?assertEqual([], external_calls(Code)),
    ?assertEqual(['band', 'bor', 'bxor'],
                 lists:usort([element(2, Instruction) || Instruction <- Code,
                                                         element(1, Instruction) =:= gc_bif
                                                             orelse element(1, Instruction)
                                                                        =:= bif])),
    ?assertEqual({ok, <<"2\n">>}, ern_program:run(Text)).

%% report §11.1: the interface of a module of the standard library holds
%% the host's module and function of each exported foreign declaration, and
%% a program's holds none, its foreign function called through its check
%% (§8.4). A regression test, written after the code.
interface_shims_test() ->
    [IntShims] = [shims(Interface) || #interface{namespace = ['Int']} = Interface
                                          <- ern_prelude:stdlib_interfaces()],
    ?assertEqual({erlang, 'band'}, maps:get(['Int', bitAnd], IntShims)),
    ?assertNot(is_map_key(['Int', shiftedRight], IntShims)),
    Text = "export foreign fn size(list : List(Int)) : Int =\n    \"erlang:length/1\"\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], Text),
    Canonical = ern_canonical:module(['M'], Typed, Env, false),
    ?assertEqual(#{}, shims(ern_compile:interface(['M'], Interface, Canonical, Env, #{}))).

%% An interface's shims, by qualified name.
shims(#interface{back_end = BackEnd}) ->
    #{QualifiedName => Shim || QualifiedName := #back_end{shim = Shim} <- BackEnd, Shim =/= none}.

%% report §12.3, Appendix E.21, §11.1: a raise in a foreign function of the
%% standard library's, called at the call site, faults with the cause that
%% names the host's function, as it did through the declaration's function,
%% and its trace shows the host's function above the frame of the program's
%% that called it, at the call's line, with no frame of the library's; an
%% argument's own fault, evaluated before the call, is no raise of the
%% function. A regression test, written after the code; it does not cover
%% a raise through the function taken as a value, whose frame the trace
%% shows.
shim_raise_test() ->
    Raising = "fn atom(text : String) : Foreign.Term = {\n"
              "    let made = Foreign.atom(text);\n"
              "    made\n"
              "}\n"
              "\n"
              "export fn main() : Unit = Io.println(Io.show(atom(String.repeat(\"a\", 300))))\n",
    {{fault, Cause, Trace}, _} = ern_program:run(Raising),
    ?assertEqual(<<"foreign function erlang:binary_to_atom/1 raised error:system_limit">>, Cause),
    ?assertEqual([<<"erlang:binary_to_atom/1">>, <<"M.atom:2">>, <<"M.main:6">>],
                 binary:split(Trace, <<"\n">>, [global, trim])),
    Argument = "fn zero() : Int = 0\n"
               "\n"
               "export fn main() : Unit =\n"
               "    Io.println(Io.show(Foreign.atom(Int.toString(1 / zero()))))\n",
    ?assertMatch({{fault, <<"division by zero">>, _}, _}, ern_program:run(Argument)).

%% report §11.1, §12.3: within a module of the standard library, a call of
%% the module's own foreign function is the host's function too, and its
%% raise faults naming it, the trace showing the host's function above the
%% caller's frame; the private foreign function the module calls only so
%% has no function of its own, and one it takes as a value keeps its own.
%% A regression test, written after the code.
standard_own_shim_test() ->
    Text = "foreign fn octets(list : List(Int)) : Bytes =\n"
           "    \"erlang:list_to_binary/1\"\n"
           "\n"
           "foreign fn listed(bytes : Bytes) : List(Int) =\n"
           "    \"erlang:binary_to_list/1\"\n"
           "\n"
           "export fn main() : Unit = {\n"
           "    let lists = List.map([<<1>>], listed);\n"
           "    Io.println(Int.toString(Bytes.size(octets([1, 256]))))\n"
           "}\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    Functions = [Name || {function, _, Name, _, _}
                             <- ern_compile:forms(['M'], Typed, Env, #{standard => true})],
    %% main is '$1', the definitions first, and octets and listed '$2' and '$3'
    ?assertEqual({false, true}, {lists:member('$2', Functions), lists:member('$3', Functions)}),
    {{fault, Cause, Trace}, _} = ern_program:run(['M'], Text, #{standard => true}),
    ?assertEqual(<<"foreign function erlang:list_to_binary/1 raised error:badarg">>, Cause),
    ?assertMatch([<<"erlang:list_to_binary/1, argument 1: not an iolist term">>, <<"M.main:9">>],
                 binary:split(Trace, <<"\n">>, [global, trim])).

%% report §3.10, §9.6, §11.1: compare at Int, Float, String, Char and Bool is
%% the host's comparison, answering what each type's module's compare answers,
%% its operands evaluated once and in order (§5.1), and calls no module. A
%% regression test, written after the code; it does not cover compare taken
%% as a value, a supply a function that needs it is given, which is still
%% the type's module's function.
host_compare_test() ->
    Text = "fn said(text : String, value : a) : a = {\n"
           "    Io.println(text);\n"
           "    value\n"
           "}\n"
           "\n"
           "export fn compared() : List(Ordering) =\n"
           "    [compare(said(\"left\", 1), said(\"right\", 2)), compare(2, 2), compare(3, 2),\n"
           "     compare(1.5, 2.5), compare(0.0, -0.0), compare(2.5, 1.5),\n"
           "     compare(\"a\", \"b\"), compare(\"é\", \"é\"), compare(\"b\", \"a\"),\n"
           "     compare('a', 'b'), compare('z', 'z'), compare('é', 'e'),\n"
           "     compare(false, true), compare(true, true), compare(true, false)]\n"
           "\n"
           "export fn main() : Unit = Io.println(Io.show(compared()))\n",
    ?assertEqual([], [Call || {Module, _, _} = Call <- external_calls(function_code(Text, '$2')),
                              Module =/= 'ern@m']),
    ?assertEqual({ok, <<"left\nright\n[Less, Equal, Greater, Less, Equal, Greater, Less, Equal, "
                        "Greater, Less, Equal, Greater, Less, Equal, Greater]\n">>},
                 ern_program:run(Text)).

%% report §3.10, §9.6, §3.5: Bool is ordered, `false` before `true`: `<`
%% and the other comparisons on two Bools, a sort by the prelude's compare,
%% which Bool's module supplies, a tuple's order over a Bool, and a derived
%% compare over a Bool field.
bool_order_test() ->
    {ok, Output} =
        ern_program:run(
            "type Task = Task(due : Int, done : Bool) derives compare\n"
            "export fn main() : Unit = {\n"
            "    Io.println(Io.show(#(false < true, true <= false, true >= true, true > false)));\n"
            "    Io.println(Io.show(List.sort([true, false, true])));\n"
            "    Io.println(Io.show(List.sort([#(1, true), #(0, true), #(1, false)])));\n"
            "    let tasks = [Task(due = 1, done = true), Task(due = 1, done = false)];\n"
            "    Io.println(Io.show(List.sort(tasks)))\n"
            "}\n"),
    ?assertEqual(<<"#(true, false, true, true)\n[false, true, true]\n"
                   "[#(0, true), #(1, false), #(1, true)]\n"
                   "[M.Task(due = 1, done = false), M.Task(due = 1, done = true)]\n">>, Output).

%% report §11.1: the host functions the emitter calls with no handler for
%% their raise are each called by the standard library at the types its
%% reason names alone, every declaration over one listed here with its
%% parameters, so that one added over another type is read against the
%% host's page before the table holds it. A regression test, written after
%% the code.
raiseless_declarations_test() ->
    Raiseless = ern_emitter:raiseless(),
    Declared = lists:sort(
                 [{{HostModule, HostFunction, length(Params)}, ern_namespace:text(QualifiedName),
                   [parameter_text(Param) || Param <- Params]}
                  || Erc <- filelib:wildcard("build/stdlib/*.erc"),
                     {ok, Beam} <- [file:read_file(Erc)],
                     {ok, #recorded{foreign = Foreign}} <- [ern_canonical:read(Beam)],
                     #foreign_function{qualified_name = QualifiedName, host_module = HostModule,
                                       host_function = HostFunction,
                                       scheme = {scheme, _, {arrow, Params, _, _}, _}}
                         <- Foreign,
                     lists:member({HostModule, HostFunction, length(Params)}, Raiseless)]),
    ?assertEqual([{{erlang, 'band', 2}, "Int.bitAnd", ["Int", "Int"]},
                  {{erlang, binary_to_list, 1}, "Bytes.toList", ["Bytes"]},
                  {{erlang, 'bor', 2}, "Int.bitOr", ["Int", "Int"]},
                  {{erlang, 'bxor', 2}, "Int.bitXor", ["Int", "Int"]},
                  {{erlang, byte_size, 1}, "Bytes.size", ["Bytes"]},
                  {{erlang, ceil, 1}, "Float.ceil", ["Float"]},
                  {{erlang, floor, 1}, "Float.floor", ["Float"]},
                  {{erlang, integer_to_binary, 1}, "Int.toString", ["Int"]},
                  {{erlang, iolist_to_binary, 1}, "Bytes.concatenated", ["List(Bytes)"]},
                  {{erlang, iolist_to_binary, 1}, "String.concatenated", ["List(String)"]},
                  {{erlang, length, 1}, "List.size", ["List(a)"]},
                  {{erlang, map_size, 1}, "Map.size", ["Map(a, a)"]},
                  {{erlang, trunc, 1}, "Float.truncate", ["Float"]}],
                 Declared),
    ?assertEqual(lists:usort(Raiseless), lists:usort([Host || {Host, _, _} <- Declared])).

%% A declared parameter type as text, each type variable `a`.
parameter_text({applied, {named, Name}, []}) ->
    ern_namespace:text(Name);
parameter_text({applied, {named, Name}, Args}) ->
    lists:flatten([ern_namespace:text(Name), "(",
                   lists:join(", ", [parameter_text(Arg) || Arg <- Args]), ")"]);
parameter_text({variable, _}) ->
    "a".

%% report §12.3: no host function a shim of the standard library's names
%% raises in its caller's frame, with no frame of its own, as
%% `erlang:error/1,2,3`, `exit/1`, `throw/1`, `raise/3` and `apply/2,3`
%% raise, so that the frame of a shim's call site is never the innermost
%% of a raise the shim catches, and ern_boundary:shim_raised/6 reads an
%% Ernest frame there as one of a function the shim gave the host. A shim
%% added over one of them fails here and is read then. Written with the
%% shim's handler, which rests on it
shim_hosts_raise_in_a_frame_of_their_own_test() ->
    Hosts = [{HostModule, HostFunction, scheme_arity(Scheme)}
             || Erc <- filelib:wildcard("build/stdlib/*.erc"),
                {ok, Beam} <- [file:read_file(Erc)],
                {ok, #recorded{foreign = Foreign}} <- [ern_canonical:read(Beam)],
                #foreign_function{host_module = HostModule, host_function = HostFunction,
                                  scheme = Scheme} <- Foreign],
    ?assert(lists:member({maps, fold, 3}, Hosts)),
    InCallersFrame = [{erlang, error, 1}, {erlang, error, 2}, {erlang, error, 3},
                      {erlang, exit, 1}, {erlang, throw, 1}, {erlang, raise, 3},
                      {erlang, apply, 2}, {erlang, apply, 3}],
    ?assertEqual([], [Host || Host <- Hosts, lists:member(Host, InCallersFrame)]).

%% The arity of a foreign function's scheme.
scheme_arity({scheme, _, {arrow, Params, _, _}, _}) ->
    length(Params).

%% The code of the function Function of the module M that Text compiles to,
%% as the host's disassembler reads it.
function_code(Text, Function) ->
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    {ok, _, Beam} = ern_compile:compiled(ern_compile:forms(['M'], Typed, Env), []),
    {beam_file, _, _, _, _, Functions} = beam_disasm:file(Beam),
    [Code] = [Code || {function, Name, _, _, Code} <- Functions, Name =:= Function],
    Code.

%% The host's functions a function's code calls, each {Module, Function,
%% Arity}.
external_calls(Code) ->
    [{Module, Function, Arity} || Instruction <- Code,
                                  {extfunc, Module, Function, Arity} <- tuple_parts(Instruction)].

tuple_parts(Term) when is_tuple(Term) ->
    [Term | lists:append([tuple_parts(Part) || Part <- tuple_to_list(Term)])];
tuple_parts(Terms) when is_list(Terms) ->
    lists:append([tuple_parts(Part) || Part <- Terms]);
tuple_parts(_) ->
    [].

%% report §8.1, §12.2, Appendix B
hello_golden_test() ->
    ?assertEqual(target_forms("hello.erl"), example_forms("hello")).

%% report §6.2, §6.3, §6.6, §12.2, Appendix B
counter_golden_test() ->
    ?assertEqual(target_forms("counter.erl"), example_forms("counter")).

%%
%% Golden files: the Erlang source of each example golden_names/0 lists, as
%% --emit-erl writes it, kept under test/fixtures/emitted and regenerated
%% with make golden
%%

-define(GOLDEN, "test/fixtures/emitted/").

golden_names() ->
    ["hello", "counter", "upgrade", "pingpong", "stack", "patterns", "kv_parser", "services",
     "modules/net/http", "modules/main"].

%% report §4.6, §8.5, §11.1: a `let` is a value whatever its type, so one
%% that holds a function is reached through its getter and called by
%% applying what the getter answers, in its own module and in another; a
%% `fn` of the same type is called directly. The interface says which of
%% the two a name is.
let_of_function_type_test() ->
    {_, Output} = ern_program:run("let g = fn() = 1\n"
                                  "let h = fn(x : Int) = x + 1\n"
                                  "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"
                                  "export fn main() : Unit = {\n"
                                  "    Io.println(Int.toString(g()));\n"
                                  "    Io.println(Int.toString(h(2)));\n"
                                  "    Io.println(Int.toString(twice(h, 0)))\n"
                                  "}\n"),
    ?assertEqual(<<"1\n3\n2\n">>, Output).

%% report §4.6, §11.1: the same across modules, where the interface is all
%% the emitter has to tell a `let` from a `fn`
let_of_function_type_remote_test() ->
    {ok, DependencyTyped, DependencyInterface, DependencyEnv} =
        ern_typecheck:check_string(['M'], "export let g = fn() = 1\n"
                                          "export let h = fn(x : Int) = x + 1\n"
                                          "export fn f(x : Int) : Int = x * 2\n"),
    {ok, DependencyModule, DependencyBeam} = ern_compile:compile(['M'], DependencyTyped,
                                                                 DependencyInterface,
                                                                 DependencyEnv),
    {module, DependencyModule} = code:load_binary(DependencyModule, "test", DependencyBeam),
    %% the interface the dependent is checked against is the compiled one
    {ok, #{interface := Interface}} = ern_interface:read(DependencyBeam),
    ?assertEqual([['M', g], ['M', h]], lists:sort(Interface#interface.lets)),
    {ok, Declarations} = ern_parser:parse_string(
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(M.g()));\n"
        "    Io.println(Int.toString(M.h(2)));\n"
        "    Io.println(Int.toString(twice(M.h, 0)));\n"
        "    Io.println(Int.toString(M.f(3)))\n"
        "}\n"
        "fn twice(f : (Int) -> Int, n : Int) : Int = f(f(n))\n"),
    {ok, Typed, Interface2, Env} = ern_typecheck:check(['Main'], Declarations, [Interface]),
    {ok, ErlangModule, Beam} = ern_compile:compile(['Main'], Typed, Interface2, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    ern_rt:run_main(fun() -> (ern_named:main(ErlangModule))() end, <<"main">>,
                    #{init => fun() -> ern_program:init(
                        DependencyModule), ern_program:init(ErlangModule) end,
                      stdout => fun(Text) -> Self ! {out, Text} end}),
    ?assertEqual(<<"1\n3\n2\n6\n">>, ern_program:collect([])).

%% The source the compiler emits for an example; the modules pair is
%% checked in dependency order, main against http's interface.
golden_source("modules/" ++ _ = Name) ->
    {ok, HttpSource} = file:read_file("test/fixtures/programs/modules/net/http.ern"),
    {ok, HttpTyped, Checked, HttpEnv} = ern_typecheck:check_string(['Net', 'Http'], HttpSource),
    %% report §11.1: the interface as compiled, with its definitions' hashes
    Canonical = ern_canonical:module(['Net', 'Http'], HttpTyped, HttpEnv, false),
    HttpInterface = ern_canonical:interface(Checked, Canonical),
    case Name of
        "modules/net/http" ->
            emitted(['Net', 'Http'], HttpTyped, HttpEnv);
        "modules/main" ->
            {ok, MainSource} = file:read_file("test/fixtures/programs/modules/main.ern"),
            {ok, Declarations} = ern_parser:parse_string(MainSource),
            {ok, Typed, _, Env} = ern_typecheck:check(['Main'], Declarations, [HttpInterface]),
            emitted(['Main'], Typed, Env)
    end;
golden_source(Name) ->
    {Namespace, Source} = example(Name),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    emitted(Namespace, Typed, Env).

emitted(Namespace, Typed, Env) ->
    unicode:characters_to_binary(ern_compile:erl_source(Namespace, Typed, Env)).

%% report §11.1: the emitted source of every example is what the
%% golden file holds; a difference is written beside it as .new
golden_test_() ->
    [{Name, fun() ->
                File = ?GOLDEN ++ Name ++ ".erl",
                Actual = golden_source(Name),
                case file:read_file(File) of
                    {ok, Actual} ->
                        ok;
                    _ ->
                        ok = file:write_file(File ++ ".new", Actual),
                        ?assert(false, "golden file differs; see " ++ File ++ ".new,"
                                       " or run make golden")
                end
            end} || Name <- golden_names()].

%% make golden: rewrite the golden files from the current emitter.
-spec write_golden() -> ok.
write_golden() ->
    lists:foreach(fun(Name) ->
                      File = ?GOLDEN ++ Name ++ ".erl",
                      ok = filelib:ensure_dir(File),
                      ok = file:write_file(File, golden_source(Name)),
                      file:delete(File ++ ".new"),
                      io:format("~s~n", [File])
                  end, golden_names()).

%%
%% Every unit from its forms, report §11.1 and Appendix H
%%

%% report Appendix H, §11.1, §8.7: the emitter makes every unit from its
%% definitions' canonical forms, with what the build adds that is no
%% definition's and the link of what the forms reference outside it, and
%% reads no typed tree: each module of test/fixtures/programs, of the standard
%% library and of the shell, made from its forms as the hash takes them,
%% which hold no line and no local's name, is the code made from them with
%% the source woven in but for its lines, its variables' names and its
%% spawn sites' lines, and the host compiles it. A form that lacked what
%% the emitter reads would fail here, as a definition that arrives (§12.7)
%% would. Written after the code
units_from_forms_alone_test_() ->
    {timeout, 600, fun units_from_forms_alone/0}.

units_from_forms_alone() ->
    Programs = "test/fixtures/programs",
    Roots = [{Programs, filelib:wildcard(Programs ++ "/*.ern"), []},
             {Programs ++ "/modules", ern_build:sources(Programs ++ "/modules"), []},
             {"src/stdlib", ern_build:sources("src/stdlib"), []},
             {"src/shell", ern_build:sources("src/shell"),
              ["build/libs/ansi", "build/libs/markdown",
               "build/libs/ets", "build/libs/crypto"]}],
    %% every program, every module of the library and every one of the
    %% shell's root, `ern unpack`'s among them
    [?assertEqual(length(Files), units_from_forms(SourceRoot, Files, LoadPath))
     || {SourceRoot, Files, LoadPath} <- Roots].

%% Each module of Files under Root in the order a build compiles it, checked
%% against its dependencies as the build checks it, its unit made from its
%% forms with and without the source and compared; how many were made.
units_from_forms(Root, Files, LoadPath) ->
    SourceRoot = ern_build:absolute(Root),
    Roots = ern_build:load_path_of([filename:join(ern_program:scratch(), "build") | LoadPath]),
    Standard = ern_build:is_stdlib_root(SourceRoot),
    Modules = [ern_build:module_of(ern_build:absolute(File), SourceRoot) || File <- Files],
    {_, Made} =
        lists:foldl(
          fun(#build_module{namespace = Namespace, dependencies = Dependencies} = Module,
              {Interfaces, Acc}) ->
                  Given = ern_build:dependency_interfaces(Namespace, Dependencies, Interfaces,
                                                          Roots, SourceRoot, {build, true}),
                  {ok, Typed, Interface, Env} =
                      ern_build:checked(Module, [Used || {_, Used} <- Given], SourceRoot,
                                        Roots),
                  Canonical = ern_canonical:module(Namespace, Typed, Env, Standard),
                  Build = #{standard => Standard, code => true,
                            deps => [{Dependency, <<>>} || {Dependency, _} <- Given]},
                  Sourced = ern_compile:unit(Namespace, Typed, Env, Canonical, Build),
                  Alone = [Definition#definition{sourced = none}
                           || Definition <- Sourced#unit.definitions],
                  same_but_the_source(Sourced, Sourced#unit{definitions = Alone}),
                  {Interfaces#{Namespace => ern_canonical:interface(Interface, Canonical)},
                   [Namespace | Acc]}
          end, {#{}, []}, ern_build:compile_order(Modules, SourceRoot, Roots)),
    length(Made).

%% The unit made with the source and from its forms alone, the same code but
%% for the source's lines, names and sites' lines, and the host compiles
%% the second.
same_but_the_source(Sourced, Alone) ->
    {WithSource, _} = ern_emitter:unit(Sourced),
    {FromForms, _} = ern_emitter:unit(Alone),
    ?assertMatch({ok, _, _}, compile:noenv_forms(FromForms, [return_errors])),
    ?assertEqual(ok, same_code(normalize(WithSource), normalize(FromForms))).

%% Two normalized forms the same but where a string of the first is the
%% second's with a line after a colon, a spawn site's (report §6.9).
same_code({string, Anno, Text}, {string, Anno, Text}) ->
    ok;
same_code({string, Anno, WithLine}, {string, Anno, Text}) ->
    case lists:prefix(Text ++ ":", WithLine)
         andalso lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end,
                           lists:nthtail(length(Text) + 1, WithLine)) of
        true -> ok;
        false -> {differs, WithLine, Text}
    end;
same_code(First, Second) when is_tuple(First), is_tuple(Second),
                              tuple_size(First) =:= tuple_size(Second) ->
    same_code(tuple_to_list(First), tuple_to_list(Second));
same_code([First | Firsts], [Second | Seconds]) ->
    case same_code(First, Second) of
        ok -> same_code(Firsts, Seconds);
        Differs -> Differs
    end;
same_code(Same, Same) ->
    ok;
same_code(First, Second) ->
    {differs, First, Second}.

%% report §11.1: a unit's functions are named by their position in it, its
%% definitions in the order of their forms, a type taking its position, and
%% its foreign functions after them; a local function lifted to its own
%% function by its definition's position and its own among the
%% definition's lambdas and local functions, and the entry a spawn on a
%% peer starts one by, '.entry' after; report §8.5: the initializer of a
%% binding whose initializer is no ground term by the binding's position,
%% '.init' after, exported; and two builds of one module, as on two nodes,
%% name them alike. Written after the code, and the initializer's name with
%% it
functions_named_by_position_test() ->
    Text = "export type Box = Box(Int)\n"
           "export fn Box.compare(a : Box, b : Box) : Ordering = Equal\n"
           "let base : Int = twice(1)\n"
           "export fn twice(n : Int) : Int = {\n"
           "    fn add(k : Int) : Int = k + n;\n"
           "    add(n)\n"
           "}\n"
           "export fn start(n : Int) : Either(Io.Error, Address(Never)) =\n"
           "    Peer.spawn(\"p\", fn() = { let _ = n + base; Unit }, 100)\n"
           "export foreign fn backwards(list : List(Int)) : List(Int) = \"lists:reverse/1\"\n",
    Compiled = fun() ->
                       {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Numbered'], Text),
                       {ok, Unit, Beam} = ern_compile:compile(['Numbered'], Typed, Interface, Env),
                       {Unit, Beam}
               end,
    {Unit, Beam} = Compiled(),
    {module, Unit} = code:load_binary(Unit, "test", Beam),
    Functions = [Function || {Function, _} <- Unit:module_info(functions)],
    ?assertEqual(['$2', '$3', '$3.init', '$4', '$4.1', '$5', '$5.1.entry', '$6', '$code',
                  '$init', '$spawned'],
                 lists:sort([Function || Function <- Functions,
                                         lists:prefix("$", atom_to_list(Function)),
                                         not lists:prefix("$type_", atom_to_list(Function))])),
    %% '$init'/0 calls an initializer by the unit's name, which exports it
    ?assert(erlang:function_exported(Unit, '$3.init', 0)),
    ?assertEqual({'$4', 1}, ern_code:function(Unit, ['Numbered', twice])),
    ?assertEqual({'$2', 2}, ern_code:function(Unit, ['Numbered', 'Box', compare])),
    ?assertEqual({'$3', 0}, ern_code:function(Unit, ['Numbered', base])),
    ?assertEqual({'$6', 1}, ern_code:function(Unit, ['Numbered', backwards])),
    ?assertEqual(none, ern_code:function(Unit, ['Numbered', 'Box'])),
    %% a second build of the module names every function alike
    {Unit, Again} = Compiled(),
    ?assertEqual(beam_functions(Beam), beam_functions(Again)),
    code:purge(Unit),
    code:delete(Unit).

beam_functions(Beam) ->
    {ok, {_, [{exports, Exports}]}} = beam_lib:chunks(Beam, [exports]),
    Exports.

%% Appendix E.21, report §11.2, §11.1: a fault's trace writes a frame of a
%% unit's function, which the unit names by its position, as a spawn site
%% is written, by the name its sites give the definition and its line: a
%% foreign function's by its name and its declaration's line, a
%% member's by its type's and its own, a local function lifted to a
%% function of its own and a lambda by the top-level declaration they are
%% written in and the frame's line, as a spawn site there is named, and
%% the standard library's by its own.
%%
%% A frame of the host's or the runtime's above the program's is written by
%% the function as the host names it, and its line where it gives one; the
%% trace ends with the program's outermost frame, `main`'s, the runtime's
%% beneath it left out. A regression test of the frame's shape, written
%% after the code (the log's *Every Fault Carries a Trace*); a received
%% definition's frame is test/ern_nodes_tests.erl's
trace_names_functions_test() ->
    Text = "foreign fn boom(x : Int) : Int = \"erlang:binary_to_integer/1\"\n"
           "type Vec = Vec(Int)\n"
           "fn Vec.+(a : Vec, b : Vec) : Vec = {\n"
           "    fn inner(n : Int) : Int = boom(n) + 1;\n"
           "    Vec(inner(1))\n"
           "}\n"
           "fn helper(n : Int) : Int =\n"
           "    List.size(List.map([n], fn(k : Int) : Int = match Vec(k) + Vec(n) {\n"
           "        Vec(m) -> m\n"
           "    })) + 1\n"
           "export fn main() : Unit = Io.println(Int.toString(helper(3)))\n",
    {Result, _} = ern_program:run(['Traced'], Text, #{}),
    {fault, _, Trace} = Result,
    ?assertMatch([?NOT_TEXT, <<"Traced.boom:1">>, <<"Traced.Vec.+:4">>,
                  <<"Traced.Vec.+:5">>, <<"Traced.helper:8">>, <<"List.map:", _/binary>>,
                  <<"Traced.helper:8">>, <<"Traced.main:11">>],
                 frames(Trace)).

%% report §7.3, Appendix E.21: a fault's trace holds the frame of the
%% function that meets it and of each caller beneath, as a host error's
%% does, though the function's every way out for that argument faults:
%% the workers of the probe call `first([])` as an argument and as an
%% operand, and `average(1, 0)` divides by zero. A regression test: `fault`
%% was the host's throw written in place, from which the host's compiler
%% took the call of `first` for one that never returns and made it the
%% caller's last, the worker's frame gone; it does not cover a call of
%% `fault` in a lambda, whose frame is its declaration's as any frame is
fault_keeps_its_callers_frames_test() ->
    Declarations = "fn first(list : List(Int)) : Int =\n"
                   "    match list {\n"
                   "        x :: _ -> x\n"
                   "      | [] -> fault(\"first of an empty list\")\n"
                   "    }\n"
                   "fn average(total : Int, count : Int) : Int =\n"
                   "    total / count\n"
                   "fn worker() : Unit =\n"
                   "    Io.println(Int.toString(first([])))\n"
                   "fn worker2() : Unit =\n"
                   "    Io.println(Int.toString(average(1, 0)))\n"
                   "fn worker3() : Unit =\n"
                   "    Io.println(Int.toString(first([]) + 1))\n",
    Traced = fun(Worker) ->
                 Main = "export fn main() : Unit = {\n    " ++ Worker ++ "();\n    Unit\n}\n",
                 {{fault, _, Trace}, _} = ern_program:run(['Tr2'], Declarations ++ Main, #{}),
                 frames(Trace)
             end,
    ?assertEqual([<<"Tr2.first:4">>, <<"Tr2.worker:9">>, <<"Tr2.main:15">>], Traced("worker")),
    ?assertEqual([<<"erlang:'div'/2">>, <<"Tr2.average:7">>, <<"Tr2.worker2:11">>,
                  <<"Tr2.main:15">>],
                 Traced("worker2")),
    ?assertEqual([<<"Tr2.first:4">>, <<"Tr2.worker3:13">>, <<"Tr2.main:15">>], Traced("worker3")).

%% Appendix E.21, report §8.5, §11.2: a fault in a top-level binding's
%% initializer is reported under the binding's site and traced by the
%% binding's name and the frame's line, beneath the frames of what it
%% called, and the trace ends there, the binding's frame the program's
%% outermost. A regression test, written after the code: the trace was the
%% same when every initializer was written into '$init'/0, whose frame was
%% named by the binding whose source held its line; it does not cover a
%% fault in a lambda of a binding's value, which raise_has_line_test reads
initializer_fault_traced_test() ->
    Text = "fn half(n : Int) : Int = 10 / n\n"
           "let zero : Int = List.size([])\n"
           "let doubled : Int = List.size([1, 2]) * 2\n"
           "let bad : Int =\n"
           "    half(zero) + doubled\n"
           "export fn main() : Unit = Io.println(Int.toString(bad))\n",
    {{initializer_fault, <<"Inits.bad:4">>, <<"division by zero">>, Trace}, _} =
        ern_program:run(['Inits'], Text, #{}),
    ?assertEqual([<<"erlang:'div'/2">>, <<"Inits.half:1">>, <<"Inits.bad:5">>], frames(Trace)).

%% report §7.3, Appendix E.21: a fault met in place carries its line, so
%% that the trace's first frame is the Ernest site with it: a Float
%% quotient's in a lambda of a top-level `let`, the host's own operation in
%% its float registers, its frame named by the binding, and a foreign
%% function's return declared `Unit` or a word that is no value of it, the
%% emitter's raise, its frame the foreign function's at its declaration's
%% line. A regression test, written after the code: each frame had no
%% line, and the lambda's was the host's name; it does not cover a fault
%% the runtime raises, whose frames are the runtime's
raise_has_line_test() ->
    {{fault, <<"float arithmetic error">>, FloatTrace}, _} =
        ern_program:run(
            ['Floats'], "let divide = fn(x : Float) =\n"
                        "    x / 0.0\n"
                        "export fn main() : Unit = Io.println(Float.toString(divide(1.0)))\n",
            #{}),
    ?assertEqual([<<"Floats.divide:2">>, <<"Floats.main:3">>], frames(FloatTrace)),
    %% a host function whose result the host's compiler does not know, so
    %% that the caller's frame stays: where it knows the result never
    %% matches, as a reference never does, it takes the call for one that
    %% never returns, and the caller keeps no frame for it
    Called = "export fn main() : Unit = {\n"
             "    let _ = wrong(1);\n"
             "    Io.println(\"after\")\n"
             "}\n",
    {{fault, UnitCause, UnitTrace}, _} =
        ern_program:run(
            ['Units'], "foreign fn wrong(key : Int) : Unit = \"erlang:get/1\"\n" ++ Called, #{}),
    ?assertEqual(return_cause("erlang:get/1", "Unit", "is undefined"), UnitCause),
    ?assertEqual([<<"Units.wrong:1">>, <<"Units.main:3">>], frames(UnitTrace)),
    {{fault, WordCause, WordTrace}, _} =
        ern_program:run(
            ['Words'], "foreign fn wrong(key : Int) : Int = \"erlang:get/1\"\n" ++ Called, #{}),
    ?assertEqual(return_cause("erlang:get/1", "Int", "is undefined"), WordCause),
    ?assertEqual([<<"Words.wrong:1">>, <<"Words.main:3">>], frames(WordTrace)).

%% report §11.1, Appendix E.21, §7.3: a fault a standard library's shim
%% raises, the runtime's own `float arithmetic error`, keeps the line of
%% the frame that called the shim, as a host function's raise keeps it:
%% `Float.exp` called at line 2, and `Float.pow`, whose own call of its
%% shim keeps its line in float.ern above the caller's. Written before the
%% fix, each frame having lost its line where the boundary passed the
%% fault on
shim_fault_keeps_line_test() ->
    {{fault, <<"float arithmetic error">>, Exp}, _} =
        ern_program:run("export fn main() : Unit = {\n"
                        "    let x = Float.exp(1000.0);\n"
                        "    Io.println(Float.toString(x))\n"
                        "}\n"),
    ?assertEqual([<<"M.main:2">>], frames(Exp)),
    {{fault, <<"float arithmetic error">>, Pow}, _} =
        ern_program:run("export fn main() : Unit = {\n"
                        "    let x = Float.pow(10.0, 400.0);\n"
                        "    Io.println(Io.show(x))\n"
                        "}\n"),
    [Library, <<"M.main:2">>] = frames(Pow),
    ?assertMatch(<<"Float.pow:", Line/binary>> when Line =/= <<>>, Library).

%% report §11.1, §12.7, §11.5: the `.erc` records beside each definition's
%% form the lines of its source, the locals' names left out, its name where
%% its sites write another, and what prints a type in a cause as its module
%% writes it, and the module's bindings' order: read back, each form with
%% its lines is its form once they are taken out; a module of a shell's
%% session records its lines as the session counts them and its
%% declaration's name as its sites write it, under the session's namespace
%% (§11.2 *Faults*). Written with the code; the namespace in the name a
%% regression test (the log's *Sites, Sessions and Their Names*)
recorded_source_test() ->
    Text = "export fn twice(n : Int) : Int = {\n"
           "    let doubled = n * 2;\n"
           "    doubled\n"
           "}\n"
           "export let base : Int = 1\n",
    Recorded = fun(Namespace, Build) ->
                       {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
                       {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env,
                                                           Build#{source_hash => <<>>,
                                                                  deps => []}),
                       {ok, Read} = ern_canonical:read(Beam),
                       Read
               end,
    #recorded{definitions = Definitions, binding_order = Order} = Recorded(['Lined'], #{}),
    ?assertEqual([['Lined', base]], Order),
    [begin
         ?assertEqual(Form, ern_canonical:stripped(Sourced)),
         ?assertEqual([], local_names(Sourced))
     end || #definition{form = Form, sourced = Sourced} <- Definitions],
    ?assertMatch([#definition{qualified_name = ['Lined', twice], name = none,
                              sourced = {'$at', {1, _, none}, _}},
                  #definition{qualified_name = ['Lined', base], name = none,
                              sourced = {'$at', {5, _, none}, _}}],
                 Definitions),
    #recorded{definitions = [Twice, Base]} =
        Recorded(['$Input7'], #{session_offset => 10, form_namespace => ['$Session'],
                                site_namespace => ['$Session'],
                                input_name => <<"$Session.input 7">>}),
    ?assertMatch(#definition{name = [<<"$Session">>, <<"twice">>],
                             sourced = {'$at', {11, _, none}, _}},
                 Twice),
    ?assertMatch(#definition{name = [<<"$Session">>, <<"base">>],
                             sourced = {'$at', {15, _, none}, _}}, Base).

%% report Appendix E.21, §11.1, §11.2: a foreign function's frame has the
%% line of its declaration however its unit is made: from the source as a
%% build makes it; as an input of a shell's session, whose lines the
%% session counts and whose sites name what it declares under the session's
%% namespace;
%% and from what a compiled form records, as the shell and `Code.load` make
%% a unit beside another of its name (ern_compile:from_compiled/5), the
%% compiled form recording each foreign declaration with its place. A
%% regression test, written after the fix (the log's *The Full Review
%% Before 0.5.0*: an input's foreign declaration kept the line within its
%% input, and one made from a compiled form had none); a unit an exchange
%% makes is ern_exchange_tests' received_linked_test's
foreign_line_test() ->
    Text = "foreign fn boom(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
           "fn go() : Int = boom(\"x\") + 1\n"
           "export fn main() : Unit = Io.println(Int.toString(go()))\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Placed'], Text),
    Compiled = fun(Build) ->
                       {ok, ErlangModule, Beam} =
                           ern_compile:compile(['Placed'], Typed, Interface, Env,
                                               Build#{source_hash => <<>>, deps => []}),
                       {ErlangModule, Beam}
               end,
    Traced = fun(ErlangModule, Beam) ->
                     code:purge(ErlangModule),
                     {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
                     {{fault, _, Trace}, _} = ern_program:run_loaded(ErlangModule, #{}),
                     code:purge(ErlangModule),
                     code:delete(ErlangModule),
                     frames(Trace)
             end,
    {Built, Beam} = Compiled(#{}),
    ?assertMatch({ok, #recorded{foreign = [#foreign_function{qualified_name = ['Placed', boom],
                                                             host_module = erlang,
                                                             host_function = binary_to_integer,
                                                             source = {1, 1, none}}]}},
                 ern_canonical:read(Beam)),
    {ok, Made} = ern_compile:from_compiled(Beam, 'ern@placed$2', [], ern_typecheck:prelude_env(),
                                           #{}),
    Frames = [?UNPARSED, <<"Placed.boom:1">>, <<"Placed.go:2">>,
              <<"Placed.main:3">>],
    ?assertEqual(Frames, Traced(Built, Beam)),
    ?assertEqual(Frames, Traced('ern@placed$2', Made)),
    {Input, InputBeam} = Compiled(#{session_offset => 10, site_namespace => ['$Session1']}),
    ?assertMatch({ok, #recorded{foreign = [#foreign_function{source = {11, 1, none}}]}},
                 ern_canonical:read(InputBeam)),
    ?assertEqual([?UNPARSED, <<"$Session1.boom:11">>,
                  <<"$Session1.go:12">>, <<"$Session1.main:13">>],
                 Traced(Input, InputBeam)).

%% report §11.2, §11.1, §8.7: a compiled module made a unit of another name
%% from what it records lists the entry of a lambda written in a top-level
%% binding that a spawn on a peer starts, with its reach, as the build's
%% unit lists it. A regression test, written after the fix (the log's *The
%% Full Review Before 0.5.0*: the reaches of a unit made so held no
%% binding's lambda, so the shell's load of such a module beside another
%% unit of its name, and `Code.load`'s, failed in the back end); the shell
%% and `Code.load` themselves are not run
from_compiled_lambda_in_binding_test() ->
    Text = "fn heavy(n : Int) : Int = n * n\n"
           "export let job = fn() = Peer.compute(\"p\", fn() = heavy(4), 100)\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Inbound'], Text),
    {ok, Built, Beam} = ern_compile:compile(['Inbound'], Typed, Interface, Env,
                                            #{source_hash => <<>>, deps => []}),
    {ok, Made} = ern_compile:from_compiled(Beam, 'ern@inbound$2', [],
                                           ern_typecheck:prelude_env(), #{}),
    Lambdas = fun(ErlangModule, Compiled) ->
                      code:purge(ErlangModule),
                      {module, ErlangModule} = code:load_binary(ErlangModule, "test", Compiled),
                      Rows = [Row || {_, {lambda, _, _, _, _, _} = Row} <- ErlangModule:'$code'()],
                      code:purge(ErlangModule),
                      code:delete(ErlangModule),
                      Rows
              end,
    ?assertMatch([{lambda, _, 2, '$2.2.entry', 0, {[], []}}], Lambdas(Built, Beam)),
    ?assertEqual(Lambdas(Built, Beam), Lambdas('ern@inbound$2', Made)).

%% The names of the locals a form with its source's lines holds.
local_names({'$at', {_, _, Name}, Node}) ->
    [Name || Name =/= none] ++ local_names(Node);
local_names(Term) when is_tuple(Term) ->
    local_names(tuple_to_list(Term));
local_names(Terms) when is_list(Terms) ->
    lists:append([local_names(Term) || Term <- Terms]);
local_names(_) ->
    [].

%% Appendix E.21, E.28, report §10: a fault's trace is the innermost twelve
%% frames of the host's stack, which the runtime keeps 64 of from its start
%% (E.28), the host eight unless told, the innermost first: under a
%% recursion twenty deep, the host's raise above the program's frames, then
%% the foreign function's and the recursion's; and a thirteenth line counts
%% the frames the cut leaves out, the recursion's other thirty and main's,
%% `... 1 more frame` for main's alone under a recursion five deep. A
%% regression test of a defect, a trace of eight lines under a deeper
%% stack, written in Ernest since the trace ends with the program's frames
trace_twelve_frames_test() ->
    Text = fun(Depth) ->
                   "foreign fn parsed(text : String) : Int = \"erlang:binary_to_integer/1\"\n"
                   "fn nested(count : Int, text : String) : Int =\n"
                   "    if count == 0 then parsed(text) else 1 + again(count - 1, text)\n"
                   "fn again(count : Int, text : String) : Int = 1 + nested(count, text)\n"
                   "export fn main() : Unit = Io.println(Int.toString(nested(" ++ Depth ++
                       ", \"x\")))\n"
           end,
    {{fault, _, Shallow}, _} = ern_program:run(['Deep'], Text("5"), #{}),
    ?assertMatch([_, _, _, _, _, _, _, _, _, _, _, _, <<"... 1 more frame">>], frames(Shallow)),
    {{fault, _, Trace}, _} = ern_program:run(['Deep'], Text("20"), #{}),
    Frames = frames(Trace),
    ?assertMatch([?UNPARSED, <<"Deep.parsed:1">> | _], Frames),
    %% each call returns to another function than the last, so that the
    %% host keeps every frame, which it does not of a function's own
    %% recursion; `nested`'s last call is a tail call, which leaves no frame
    Again = <<"Deep.again:4">>,
    Nested = <<"Deep.nested:3">>,
    ?assertEqual([Again, Nested, Again, Nested, Again, Nested, Again, Nested, Again, Nested,
                  <<"... 31 more frames">>],
                 lists:nthtail(2, Frames)).

%% Appendix E.21: a frame of the runtime's is left out of the trace of a
%% fault the runtime raises by design wherever it stands, and the trace
%% still ends with the program's outermost frame: a callForever found
%% deadlocked, its process waiting in the runtime's receive, and one whose
%% callee had ended, its fault raised in the runtime's code, each show the
%% frame of `main` that called it alone, the deadlock's naming the callee
%% it waits on (report §12.4). A regression test, written after
%% the code: the runtime's frame, `ern_rt:call_forever/3:639`, stood above
%% the program's (the log's *What the Skeptics Found*). The host's frame
%% above the program's, which stays, is
%% trace_twelve_frames_test's; a frame of the runtime's between two of the
%% program's is not covered; a failure's trace, which keeps them, is
%% trace_keeps_the_runtime_of_a_failure_test's
trace_leaves_the_runtime_out_test() ->
    Types = "type Msg = Ask(reply : Reply(Int))\n"
            "type MainMsg = Died(Down)\n"
            "fn deaf() : Unit receiving Msg = receive { Ask(reply = _) -> deaf() }\n"
            "export fn main() : Unit receiving MainMsg = {\n",
    Called = "    Io.println(Int.toString(Address.callForever(s, fn(r) = Ask(reply = r))))\n"
             "}\n",
    ?assertMatch({{fault, <<"deadlock">>, <<"M.main:6 on M.main:5\n">>}, _},
                 ern_program:run(Types ++ "    let s = spawn(deaf);\n" ++ Called)),
    ?assertMatch({{fault, <<"callee had ended">>, <<"M.main:7\n">>}, _},
                 ern_program:run(
                     Types ++ "    let s = spawnMonitored(fn() : Unit receiving Msg = Unit,"
                              " Died);\n"
                              "    receive { Died(_) -> Unit };\n" ++ Called)).

%% Appendix E.21, report §7.3: a process that waits in a receive shows one
%% line, the receive's own. A receive without an `after` is the host's,
%% whose frame names the receive's line, the line of the call of the
%% runtime's before it, whether it is its function's first expression or
%% stands after a call, and a fault in a clause's body shows no line of the
%% receive's. One with an `after` is a fun, whose frame names the receive's
%% line whether or not it is the last thing its function does, and a fault
%% in a clause's body stands above the receive it is in, a frame of the
%% host's stack.
%%
%% A fault taken at the wait names the receive's line, with an `after` and
%% without, and not its first clause's, which stands on the line after. A
%% regression test, written after the code: a timed receive's frame was
%% taken for a helper's and its line lost before it, and a fault at a wait
%% had no line; the untimed receive's own line written with the call
%% before it, where its frame named the last call before the wait or its
%% function's head
trace_through_a_wait_test() ->
    Types = "type Msg = Msg\n",
    Deadlock = fun(Body) ->
                   {{fault, <<"deadlock">>, Trace}, _} =
                       ern_program:run(
                           Types ++ "export fn main() : Unit receiving Msg = {\n" ++ Body ++ "}\n"),
                   Trace
               end,
    ?assertEqual(<<"M.main:3\n">>, Deadlock("    receive { Msg -> Unit }\n")),
    ?assertEqual(<<"M.main:3\n">>, Deadlock("    receive { Msg -> Unit };\n    Unit\n")),
    ?assertEqual(<<"M.main:4\n">>,
                 Deadlock("    Io.println(\"\");\n    receive { Msg -> Unit }\n")),
    Faulted = fun(After) ->
                  {{fault, _, Body}, _} =
                      ern_program:run(Types ++ "foreign fn boom(x : Int) : Int = "
                                               "\"erlang:binary_to_integer/1\"\n"
                                               "export fn main() : Unit receiving Msg = {\n"
                                               "    send(self(), Msg);\n"
                                               "    receive {\n"
                                               "        Msg -> Io.println(Int.toString(boom(1)))\n"
                                               ++ After ++
                                               "    };\n"
                                               "    Unit\n"
                                               "}\n"),
                  frames(Body)
              end,
    ?assertEqual([?NOT_TEXT, <<"M.boom:2">>, <<"M.main:6">>], Faulted("")),
    ?assertEqual([?NOT_TEXT, <<"M.boom:2">>, <<"M.main:6">>, <<"M.main:5">>],
                 Faulted("      | after 5000 -> Unit\n")),
    {ok, Waiting} =
        ern_program:run("foreign fn frameOf(process : Address(Msg)) : String = "
                        "\"ern_emitter_tests:frame_of/1\"\n"
                        ++ Types ++
                        "fn timed() : Unit receiving Msg = {\n"
                        "    receive { Msg -> Unit | after 60000 -> Unit };\n"
                        "    Unit\n"
                        "}\n"
                        "fn tailTimed() : Unit receiving Msg =\n"
                        "    receive { Msg -> Unit | after 60000 -> Unit }\n"
                        "export fn main() : Unit = {\n"
                        "    Io.print(frameOf(spawn(timed)));\n"
                        "    Io.print(frameOf(spawn(tailTimed)))\n"
                        "}\n"),
    ?assertEqual(<<"M.timed:4\nM.tailTimed:8\n">>, Waiting),
    Poked = fun(Receive) ->
                {{fault, <<"poked">>, Trace}, _} =
                    ern_program:run(Types ++ "foreign fn poke(process : Address(Msg)) : Unit = "
                                             "\"ern_emitter_tests:poke/1\"\n"
                                             "export fn main() : Unit receiving Msg = {\n"
                                             "    poke(self());\n"
                                             "\n"
                                             "    " ++ Receive ++ ";\n"
                                             "    Unit\n"
                                             "}\n"),
                Trace
            end,
    ?assertEqual(<<"M.main:6\n">>, Poked("receive {\n        Msg -> Unit\n    }")),
    ?assertEqual(<<"M.main:6\n">>,
                 Poked("receive {\n        Msg -> Unit\n      | after 5000 -> Unit\n    }")).

%% The trace of the process behind Address, once it waits.
-spec frame_of(ern_rt:address()) -> binary().
frame_of(Address) ->
    Pid = ern_rt:process_of(Address),
    ok = ern_waits:waiting(Pid),
    {current_stacktrace, Stack} = erlang:process_info(Pid, current_stacktrace),
    ern_rt:trace(Stack).

%% A fault left in the mailbox of the process behind Address, as a foreign
%% message that did not match leaves one (report §8.4).
-spec poke(ern_rt:address()) -> 'Unit'.
poke(Address) ->
    ern_rt:process_of(Address) ! {'$ern_fault', {ern, fault, <<"poked">>}},
    'Unit'.

%% Appendix E.21, report §7.4, §12.3: a fault whose cause names a host error
%% keeps the runtime's frames above the program's outermost frame. A foreign
%% function whose host code is the runtime's own, given what it cannot take,
%% raises inside it, by the path every library function's foreign call
%% takes, and the trace shows the host's frame and the runtime's where the
%% raise was met. A failure in the runtime named by the host's class and
%% reason, a spawn past the host's limit of processes, no program can meet
%% at a cost a test can pay, so that fault is made from a unit's own stack
%% with a frame of the runtime's laid above it, beside a fault the runtime
%% raises by design over the same stack, which leaves that frame out. A
%% regression test, written after the code
trace_keeps_the_runtime_of_a_failure_test() ->
    {{fault, Raised, Trace}, _} =
        ern_program:run("foreign fn systemProcess(name : Int) : Int = \"ern_rt:system_process/1\"\n"
                        "export fn main() : Unit = Io.println(Int.toString(systemProcess(3)))\n"),
    ?assertEqual(<<"foreign function ern_rt:system_process/1 raised error:badarg">>, Raised),
    ?assertMatch([<<"persistent_term:get/1, argument 1: ", _/binary>>,
                  <<"ern_rt:system_process/1:", _/binary>>,
                  <<"M.systemProcess:1">>, <<"M.main:2">>], frames(Trace)),
    true = register(ern_stack_here, self()),
    {ok, _} = ern_program:run("foreign fn here() : Int = \"ern_emitter_tests:stack_here/0\"\n"
                              "export fn main() : Unit = Io.println(Int.toString(here()))\n"),
    true = unregister(ern_stack_here),
    Here = receive {stack_here, Stack} -> Stack after 0 -> error(no_stack) end,
    Laid = [{erlang, spawn_opt, 4, []}, {ern_rt, spawn, 2, [{line, 1}]} | Here],
    #fault{cause = <<"error:system_limit">>, trace = Failure} =
        ern_rt:met(error, system_limit, Laid),
    ?assertMatch([<<"erlang:spawn_opt/4">>, <<"ern_rt:spawn/2:1">>, <<"M.here:1">>,
                  <<"M.main:2">>], frames(Failure)),
    #fault{cause = <<"designed">>, trace = Designed} =
        ern_rt:met(throw, {ern, fault, <<"designed">>}, Laid),
    ?assertEqual(frames(Failure) -- [<<"ern_rt:spawn/2:1">>], frames(Designed)).

%% A fault's trace as its frames, a line each (Appendix E.21).
frames(Trace) ->
    binary:split(Trace, <<"\n">>, [global, trim]).

%% A foreign function of trace_keeps_the_runtime_of_a_failure_test's, which
%% hands the test its caller's stack, its own frame taken off.
-spec stack_here() -> 0.
stack_here() ->
    {current_stacktrace, [_ | Stack]} = erlang:process_info(self(), current_stacktrace),
    ern_stack_here ! {stack_here, Stack},
    0.

%% report Appendix H, §8.7, §6.9, Appendix E.21: two functions of one body
%% are two definitions, a top-level function's qualified name being in
%% its form, so a fault's trace, a spawn site and a deadlock's trace name
%% the function that ran, the second of two, and not the first declared.
%% Written with the change that put the name in the form: the two were one
%% definition, and each of the three named the first
two_functions_of_one_body_test() ->
    {{fault, <<"division by zero">>, Divided}, _} =
        ern_program:run(
            ['Twins'], "fn first(n : Int) : Int = 10 / n\n"
                       "fn second(n : Int) : Int = 10 / n\n"
                       "export fn main() : Unit = Io.println(Int.toString(second(0)))\n"),
    ?assertEqual([<<"erlang:'div'/2">>, <<"Twins.second:2">>, <<"Twins.main:3">>],
                 frames(Divided)),
    Watched = "    let _ = spawnMonitored(work, fn(down) = down);\n"
              "    receive { down -> Io.println(down.site) }\n"
              "}\n",
    ?assertEqual({ok, <<"Sites.evening:7\n">>},
                 ern_program:run(
                     ['Sites'], lists:flatten(["fn work() : Unit = Unit\n"
                                               "fn morning() : Unit receiving Down = {\n",
                                               Watched,
                                               "fn evening() : Unit receiving Down = {\n",
                                               Watched,
                                               "export fn main() : Unit receiving Down = "
                                               "evening()\n"]))),
    Waiting = "    let got = receive { m -> m };\n"
              "    got + n\n"
              "}\n",
    {{fault, <<"deadlock">>, Waited}, _} =
        ern_program:run(
            ['Waits'], lists:flatten(["fn patient(n : Int) : Int receiving Int = {\n", Waiting,
                                      "fn stubborn(n : Int) : Int receiving Int = {\n", Waiting,
                                      "export fn main() : Unit receiving Int = {\n"
                                      "    let _ = spawn(fn() = { let _ = stubborn(1); Unit });\n"
                                      "    let _ = stubborn(2);\n"
                                      "    Unit\n"
                                      "}\n"])),
    ?assertEqual([<<"Waits.stubborn:6">>, <<"Waits.main:11">>], frames(Waited)).

%%
%% The test programs and hello run and print what their headers promise;
%% services reads its commands from standard input, and runs in
%% ern_integration_tests
%%

%% report Appendix B
examples_test_() ->
    Expected = [{"hello", <<"hello, world\n">>},
                {"counter", <<"count is 8\n">>},
                {"upgrade", <<"before upgrade: 8\nafter upgrade: 10\n">>},
                {"pingpong", <<"ping 3\npong 3\nping 2\npong 2\nping 1\npong 1\n">>},
                {"stack", <<"top is 2\n">>},
                {"patterns", <<"minus one\nzero\nother\na 2\nnothing\n-3\n3\n4\n">>},
                {"kv_parser", <<"a 12\nbad key: =1\nexpected =: a\nbad number: a=x\n">>}],
    [{Base, fun() ->
                {Namespace, Source} = example(Base),
                ?assertEqual({ok, Output}, ern_program:run(Namespace, Source))
            end} || {Base, Output} <- Expected].

%% report §11.1, §11.4: a compiled module without the Docs chunk reads as
%% an error that names the chunk and quotes no bytes. A regression test:
%% the host's text of the error was given, and it quotes the whole module.
docs_chunk_missing_test() ->
    {ok, _, Beam} = compile:forms([{attribute, 1, module, nodocs}], [binary]),
    ?assertEqual({error, "the module has no documentation chunk"}, ern_docs:read(Beam)).

%% report §11.1: the documentation travels in the BEAM chunk Docs, EEP 48's,
%% and a type's parts are structured in its entry rather than rendered
docs_chunk_test() ->
    Namespace = ['Shapes'],
    Source = <<"/// The module.\n\n"
               "/// A shape.\n"
               "export type Shape = Dot\n"
               "    /// somewhere\n"
               "    | At(\n"
               "        /// across\n"
               "        x : Int,\n"
               "        y : Int)\n"
               "export fn area(shape : Shape) : Int = 0\n">>,
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    Build = #{source_hash => <<>>, deps => [], source => <<"shapes.ern">>},
    {ok, 'ern@shapes', Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {ok, {docs_v1, _, ernest, <<"text/markdown">>, ModuleDoc, Meta, Entries}} =
        ern_docs:read(Beam),
    ?assertEqual(#{<<"en">> => <<"The module.">>}, ModuleDoc),
    ?assertEqual(<<"shapes.ern">>, maps:get(source, Meta)),
    [{{type, 'Shape', 0}, _, Signature, Doc, TypeMeta},
     {{function, area, 1}, _, _, _, FunctionMeta}] = Entries,
    ?assertEqual([<<"type Shape = Dot | At(x : Int, y : Int)">>], Signature),
    ?assertEqual(#{<<"en">> => <<"A shape.">>}, Doc),
    ?assertEqual([#{kind => constructor, name => 'Dot', doc => none, fields => []},
                  #{kind => constructor, name => 'At', doc => <<"somewhere">>,
                    fields => [#{name => x, type => <<"Int">>, doc => <<"across">>},
                               #{name => y, type => <<"Int">>, doc => none}]}],
                 maps:get(items, TypeMeta)),
    ?assertEqual([shape], maps:get(params, FunctionMeta)),
    %% the interface chunk keeps its own shape, the source name being the
    %% documentation's
    {ok, Read} = ern_interface:read(Beam),
    ?assertEqual(false, is_map_key(source, Read)).

%% report §11.4, §3.4, §4.9: the Docs chunk keys a function by the arity
%% the module exports it at, a requirement's members among it, and writes
%% a function-typed result under an outer `receiving` in its parentheses. A
%% regression test: `unique/1` was keyed where `unique/2` is exported, and
%% the field's type was printed as another type
docs_chunk_keys_and_types_test() ->
    Namespace = ['Holders'],
    Source = <<"export type Msg = Go\n"
               "export type Holder = Holder(make : (Int) -> ((Int) -> Int) receiving Msg)\n"
               "export fn unique(list : List(a)) : List(a) needs a.compare =\n"
               "    OrderedSet.toList(OrderedSet.fromList(list))\n">>,
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, #{}),
    {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
    Keys = [Key || {Key, _, _, _, _} <- Entries],
    ?assert(lists:member({function, unique, 2}, Keys)),
    [Signature] = [Signature || {{type, 'Holder', 0}, _, Signature, _, _} <- Entries],
    ?assertEqual([<<"type Holder = Holder(make : (Int) -> ((Int) -> Int) receiving Msg)">>],
                 Signature).

%% report §11.4, §4.5: the Docs chunk writes a member's form as its
%% signature, the member applied to its parameters' names, a pattern's as
%% `_`, its result and its requirement after them, and keeps its type and
%% its name beside its parameters, by which a page orders it; a function
%% keeps its head. Written with the form
docs_chunk_member_form_test() ->
    Namespace = ['Stacks'],
    Source = <<"export type Stack(a) = Stack(items : List(a))\n"
               "export fn Stack.compare(left : Stack(a), right : Stack(a)) : Ordering"
               " needs a.compare =\n"
               "    compare(left.items, right.items)\n"
               "export fn Stack.<>(Stack(items = xs) : Stack(a), other : Stack(a)) : Stack(a) =\n"
               "    Stack(items = xs <> other.items)\n"
               "export type Point = Point(x : Int)\n"
               "export fn Point.negate(point : Point) : Point = Point(x = -point.x)\n"
               "export fn size(stack : Stack(a)) : Int = List.size(stack.items)\n">>,
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, #{}),
    {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
    Functions = [{Name, Signature, Meta}
                 || {{function, Name, _}, _, Signature, _, Meta} <- Entries],
    ?assertEqual([{'Stack.compare', [<<"compare(left, right) : Ordering needs a.compare">>],
                   #{params => [left, right], member => #{type => 'Stack', name => compare}}},
                  {'Stack.<>', [<<"_ <> other : Stack(a)">>],
                   #{params => ['_', other], member => #{type => 'Stack', name => '<>'}}},
                  {'Point.negate', [<<"-point : Point">>],
                   #{params => [point], member => #{type => 'Point', name => negate}}},
                  {size, [<<"Stacks.size(stack : Stack(a)) : Int">>], #{params => [stack]}}],
                 Functions).

%% report §11.1, §8.5, §3.1: the bindings whose initializers are ground
%% terms, whose values the interface holds for a dependent: a literal of
%% each kind, a negated number literal, -0.0 as 0.0, a constructor of no
%% fields, a constructor applied to ground terms, its named fields in any
%% order, and a tuple or a list of them, nested; and not an operator, a
%% name or a negated one, a lambda, a call, a constructor of a field
%% written without it, which is a function, an update, a bitstring, whose
%% segment may overflow, nor `::`, an operator. The unit reads each as its
%% value and gives every one its value first in '$init'/0, with no site,
%% since none can fault. Written after the code, so a regression test
ground_terms_test() ->
    Text = "export type Point = Point(x : Int, y : Int)\n"
           "export type Color = Red | Wrapped(Int)\n"
           "export let anInt = 16777216\n"
           "export let aFloat = 1.5\n"
           "export let aString = \"> \"\n"
           "export let aChar = 'c'\n"
           "export let aBool = true\n"
           "export let aUnit = Unit\n"
           "export let negated = -1\n"
           "export let zero = -0.0\n"
           "export let red = Red\n"
           "export let wrapped = Wrapped(3)\n"
           "export let point = Point(y = 2, x = 1)\n"
           "export let nested = [#(1, \"a\"), #(2, \"b\")]\n"
           "export let none : Optional(Int) = None\n"
           "export let empty : List(Int) = []\n"
           "export let product = 1024 * 1024\n"
           "export let named = anInt\n"
           "export let negatedName = -anInt\n"
           "export let lambda = fn(x) = x\n"
           "export let called = Int.toString(1)\n"
           "export let wrap = Wrapped\n"
           "export let moved = Point(..point, x = 3)\n"
           "export let bits = <<1, 2>>\n"
           "export let consed = 1 :: []\n"
           "export fn summed() : Int = anInt + negated\n",
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Ground'], Text),
    Canonical = ern_canonical:module(['Ground'], Typed, Env, false),
    Terms = terms(ern_compile:interface(['Ground'], Interface, Canonical, Env, #{})),
    ?assertEqual(#{anInt => 16777216, aFloat => 1.5, aString => <<"> ">>, aChar => $c,
                   aBool => true, aUnit => 'Unit', negated => -1, zero => 0.0, red => 'Red',
                   wrapped => {'Wrapped', 3}, point => {'Point', 1, 2},
                   nested => [{1, <<"a">>}, {2, <<"b">>}], none => 'None', empty => []},
                 #{Name => Term || ['Ground', Name] := Term <- Terms}),
    ?assertNotEqual(-0.0, maps:get(['Ground', zero], Terms)),
    Source = iolist_to_binary(ern_compile:erl_source(['Ground'], Typed, Env)),
    ?assertMatch({_, _}, binary:match(Source, <<"-> 16777216 + -1.">>)),
    %% empty, the last ground binding, is '$16', and product, the first
    %% computed, '$17'
    {Given, _} = binary:match(Source, <<"persistent_term:put({ern@ground, '$16'}">>),
    {Sited, _} = binary:match(Source, <<"ern_rt:initializing(<<\"Ground.product:17\">>)">>),
    ?assert(Given < Sited),
    ?assertEqual(nomatch, binary:match(Source, <<"Ground.anInt:">>)).

%% An interface's ground terms, by qualified name.
terms(#interface{back_end = BackEnd}) ->
    #{QualifiedName => Term || QualifiedName := #back_end{term = {term, Term}} <- BackEnd}.

%% report §11.1: the interface travels in the BEAM chunk ErnI
%% with the source hash and the dependencies' interface hashes, and its
%% hash does not depend on the numbering of type variables; it holds the
%% value of an exported binding whose initializer is a ground term
interface_chunk_test() ->
    {Namespace, Source} = example("stack"),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    Build = #{source_hash => <<"s">>, deps => [{['Net', 'Http'], <<"h">>}]},
    {ok, 'ern@stack', Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {ok, #{interface := Read, source_hash := <<"s">>, deps := [{['Net', 'Http'], <<"h">>}]}} =
        ern_interface:read(Beam),
    ?assertEqual(['Stack'], Read#interface.namespace),
    ?assert(is_map_key(['Stack', push], Read#interface.values)),
    %% the checker's interface, with the numbers the compiler gives the
    %% unit's functions and the values of its ground bindings (report §11.1)
    ?assertEqual(#{['Stack', empty] => {'Stack', []}}, terms(Read)),
    ?assertEqual(ern_interface:hash(Interface#interface{back_end = Read#interface.back_end}),
                 ern_interface:hash(Read)),
    Termless = maps:map(fun(_, Facts) -> Facts#back_end{term = none} end,
                        Read#interface.back_end),
    ?assertNotEqual(ern_interface:hash(Read#interface{back_end = Termless}),
                    ern_interface:hash(Read)),
    {ok, _, Interface2, _} = ern_typecheck:check_string(Namespace,
                                                        <<"fn f(x) = x\n", Source/binary>>),
    ?assertEqual(ern_interface:hash(Interface), ern_interface:hash(Interface2)),
    %% nor on that of a type's parameters: a regression test, a private type
    %% declared before an exported one changed the exported one's numbers
    Shape = <<"export type Shape(a) = Circle(a) | Square(a)\n">>,
    {ok, _, Alone, _} = ern_typecheck:check_string(['Shape'], Shape),
    {ok, _, AfterHidden, _} =
        ern_typecheck:check_string(['Shape'], <<"type Hidden(b) = Hidden(b)\n\n", Shape/binary>>),
    ?assertEqual(ern_interface:hash(Alone), ern_interface:hash(AfterHidden)).

%% report §11.2: the interface chunk says whether the module builds a
%% function value, a function of its own code that may then be held
%% anywhere, by which the shell keeps an input's code: a lambda, a function
%% of the module taken as a value, a constructor taken as one, a member of
%% the module supplied to a requirement, a foreign function's result
%% checked as it crosses; and not a call, another module's function taken
%% as a value, a function the emitter makes and calls where it makes it, a
%% timed receive's or the body pattern alternatives share, nor the
%% function of the unit a guard falls through to. Written with the code
builds_functions_test() ->
    Builds = fun(Source) ->
                 Namespace = ['Builds'],
                 {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
                 {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env),
                 {ok, #{builds_functions := Built}} = ern_interface:read(Beam),
                 {Source, Built}
             end,
    [?assertEqual({Source, true}, Builds(Source))
     || Source <- ["fn adder(n : Int) : (Int) -> Int = fn(m) = m + n\n",
                   "fn f(n : Int) : Int = n\nfn g() : (Int) -> Int = f\n",
                   "type Box = Box(Int)\nfn g() : (Int) -> Box = Box\n",
                   "type T = A | B derives compare\n"
                   "fn sorted(ts : List(T)) : List(T) =\n"
                   "    OrderedSet.toList(OrderedSet.fromList(ts))\n",
                   "foreign fn made() : (Int) -> Int = \"erlang:self/0\"\n"]],
    [?assertEqual({Source, false}, Builds(Source))
     || Source <- ["fn f(n : Int) : Int = n + 1\nfn g() : Int = f(2)\n",
                   "fn g() : (List(Int)) -> Int = List.size\n",
                   "fn w() : Unit receiving Int = receive { _ -> Unit | after 10 -> Unit }\n",
                   "fn h(n : Int) : Int = match n { 1 or 2 -> 0 | _ -> 1 }\n",
                   "fn big(m : Int) : Bool = m > 3\n"
                   "fn s(n : Int) : Int = match n { m when big(m) -> 0 | _ -> 1 }\n"]].

%% report §11.1: a chunk of another compiler version reads as an error,
%% so the module counts as stale; and the interface hash ignores the names
%% of type variables
stale_chunk_test() ->
    {Namespace, Source} = example("stack"),
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Source),
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env),
    {ok, {_, [{"ErnI", Chunk}]}} = beam_lib:chunks(Beam, ["ErnI"]),
    Old = term_to_binary((binary_to_term(Chunk))#{format => 0}),
    {ok, _, Stale} = compile:forms([{attribute, 1, module, x}],
                                   [binary, {extra_chunks, [{<<"ErnI">>, Old}]}]),
    ?assertMatch({error, _}, ern_interface:read(Stale)),
    {ok, _, InterfaceA, _} = ern_typecheck:check_string(['M'], "export fn id(x : a) : a = x\n"),
    {ok, _, InterfaceT, _} = ern_typecheck:check_string(['M'], "export fn id(x : t) : t = x\n"),
    ?assertEqual(ern_interface:hash(InterfaceA), ern_interface:hash(InterfaceT)).

%% report §11.1: --emit-erl gives the module as Erlang source
erl_source_test() ->
    {Namespace, Source} = example("hello"),
    {ok, Typed, _, Env} = ern_typecheck:check_string(Namespace, Source),
    Emitted = unicode:characters_to_binary(ern_compile:erl_source(Namespace, Typed, Env)),
    ?assertMatch({_, _}, binary:match(Emitted, <<"-module(ern@hello).">>)).

%% report §4.2: the module atom is ern@ and the path with @ for /
erlang_module_test() ->
    ?assertEqual('ern@counter', ern_namespace:erlang_module(['Counter'])),
    ?assertEqual('ern@net@http', ern_namespace:erlang_module(['Net', 'Http'])),
    %% a segment of several words is its file's name, joined by `_`
    ?assertEqual('ern@ordered_set', ern_namespace:erlang_module(['OrderedSet'])),
    ?assertEqual('ern@net@http_client', ern_namespace:erlang_module(['Net', 'HttpClient'])).

%%
%% Blocks, bindings, and local functions
%%

%% report §4.6, §5.4: a local fn closes over earlier bindings and calls
%% itself; used as a value it becomes a closure
local_fn_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    let base = 10;\n"
        "    fn add(x : Int) : Int = base + x;\n"
        "    fn count(n : Int) : Int = if n == 0 then 0 else 1 + count(n - 1);\n"
        "    let ys = List.map([1, 2], add);\n"
        "    Io.println(Int.toString(List.foldLeft(ys, 0, fn(a, b) = a + b)));\n"
        "    Io.println(Int.toString(count(3)))\n"
        "}\n"),
    ?assertEqual(<<"23\n3\n">>, Output).

%% report §4.6, §5.4: a local fn sees the bindings in force at its
%% declaration, whatever is rebound after it, and through the local fns it
%% references, theirs; it may be used before its declaration
local_fn_bindings_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    let x = 1;\n"
        "    fn f() : Int = x;\n"
        "    let x = 2;\n"
        "    Io.println(Int.toString(f() * 10 + x));\n"
        "    let a = 1;\n"
        "    fn g() : Int = h();\n"
        "    let a = 2;\n"
        "    fn h() : Int = a;\n"
        "    Io.println(Int.toString(g()));\n"
        "    let b = 5;\n"
        "    let early = k();\n"
        "    fn k() : Int = b + 1;\n"
        "    Io.println(Int.toString(early));\n"
        "    let k2 = 10;\n"
        "    fn add(n : Int) : Int = n + k2;\n"
        "    let r = { fn twice(n : Int) : Int = add(add(n)); twice(1) };\n"
        "    Io.println(Int.toString(r))\n"
        "}\n"),
    ?assertEqual(<<"12\n2\n6\n21\n">>, Output).

%% report §5.4, §5.11: a local fn is free in no block of its own, before
%% its declaration as after, and a pattern's size expression reads the
%% names around it, which a local fn captures. A regression test: both
%% crashed the emitter, looking up a name the free names had missed or kept
free_names_test() ->
    {ok, Output} = ern_program:run(
        "fn width(n : Int, b : Bytes) : Int = {\n"
        "    fn read(x : Bytes) : Int = match x {\n"
        "        <<v:size(n), _:bytes>> -> v\n"
        "      | _ -> 0\n"
        "    };\n"
        "    read(b)\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    fn outer() : Int = {\n"
        "        fn first() : Int = second();\n"
        "        fn second() : Int = 1;\n"
        "        first()\n"
        "    };\n"
        "    let x = outer();\n"
        "    let second = 5;\n"
        "    Io.println(Int.toString(x + second + width(8, <<7, 1>>)))\n"
        "}\n"),
    ?assertEqual(<<"13\n">>, Output).

%% report §4.2, §5.4: a local fn reads the local binding, or calls the
%% local fn, that a top-level declaration's name names in its block. A
%% regression test: both crashed the emitter, which took the name for the
%% top-level one
local_name_over_top_level_test() ->
    {ok, Output} = ern_program:run(
        "fn helper() : Int = 1\n"
        "export fn main() : Unit = {\n"
        "    let helper = 5;\n"
        "    fn f() : Int = helper;\n"
        "    let base = 10;\n"
        "    fn g() : Int = later() + 1;\n"
        "    fn later() : Int = base;\n"
        "    Io.println(Int.toString(f() + g()))\n"
        "}\n"),
    ?assertEqual(<<"16\n">>, Output).

%% report §5.11: a pattern's size reads the scope before the pattern, not a
%% variable the same pattern binds elsewhere. A regression test: the
%% emitted Erlang read the tuple's own `n`, and did not compile
pattern_size_reads_the_outer_scope_test() ->
    {ok, Output} = ern_program:run(
        "fn pick(n : Int, pair : #(Int, Bytes)) : Int = match pair {\n"
        "    #(n, <<x:size(n)>>) -> x + n\n"
        "  | _ -> 0\n"
        "}\n"
        "export fn main() : Unit = Io.println(Int.toString(pick(8, #(16, <<5>>))))\n"),
    ?assertEqual(<<"21\n">>, Output).

%% report §5.1, §5.11: a construction evaluates a segment's size once, in
%% order. A regression test: the size stood twice, its width checked and
%% its field built, and its effect happened twice
construction_size_once_test() ->
    {ok, Output} = ern_program:run(
        "fn width() : Int = {\n    Io.println(\"width\");\n    16\n}\n"
        "fn value() : Int = {\n    Io.println(\"value\");\n    5\n}\n"
        "export fn main() : Unit = {\n"
        "    let b = <<value():size(width()), 1:size(8)>>;\n"
        "    Io.println(Int.toString(Bytes.size(b)))\n"
        "}\n"),
    ?assertEqual(<<"value\nwidth\n3\n">>, Output).

%% report §2.3, §11.1: a name of §2.3's 255 characters compiles, the
%% emitter cutting the names it makes from it to the host's limit. A
%% regression test: a variable's Erlang name passed it and crashed the
%% emitter
longest_names_test() ->
    Variable = lists:duplicate(255, $a),
    Function = lists:duplicate(255, $b),
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    let " ++ Variable ++ " = 1;\n"
        "    fn " ++ Function ++ "() : Int = " ++ Variable ++ " + 1;\n"
        "    Io.println(Int.toString(" ++ Function ++ "()))\n"
        "}\n"),
    ?assertEqual(<<"2\n">>, Output).

%% report §5.1: a list literal of more calls than the host keeps live at
%% one, and a long tuple, are built with their elements evaluated first to
%% last. A regression test: the host's compiler refused the module
long_literals_test_() ->
    {timeout, 60, fun long_literals/0}.

long_literals() ->
    Calls = lists:join(", ", ["f(" ++ integer_to_list(N) ++ ")" || N <- lists:seq(1, 1100)]),
    Numbers = lists:join(", ", [integer_to_list(N) || N <- lists:seq(1, 300)]),
    {ok, Output} = ern_program:run(
        "fn f(n : Int) : Int = {\n"
        "    if n == 1 || n == 1100 then Io.println(Int.toString(n)) else Unit;\n"
        "    n\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    let calls = [" ++ Calls ++ "];\n"
        "    Io.println(Io.show(#(List.size(calls), List.last(calls))));\n"
        "    Io.println(Io.show(#(" ++ Numbers ++ ")))\n"
        "}\n"),
    ?assertEqual(iolist_to_binary(["1\n1100\n#(1100, Some(1100))\n#(", Numbers, ")\n"]),
                 Output).

%% report §5.1: a call's arguments, a tuple's and a list's elements and an
%% operator's operands are evaluated left to right. Written after the
%% code, which leaves the order to the host's compiler, so that a change of
%% the host's order fails here
order_of_evaluation_test() ->
    {ok, Output} = ern_program:run(
        "fn say(word : String, n : Int) : Int = {\n"
        "    Io.println(word);\n"
        "    n\n"
        "}\n"
        "fn pair(x : Int, y : Int) : Int = x + y\n"
        "export fn main() : Unit = {\n"
        "    let _ = pair(say(\"call 1\", 1), say(\"call 2\", 2));\n"
        "    let _ = #(say(\"tuple 1\", 1), say(\"tuple 2\", 2));\n"
        "    let _ = [say(\"list 1\", 1), say(\"list 2\", 2)];\n"
        "    let _ = say(\"operand 1\", 1) + say(\"operand 2\", 2);\n"
        "    let _ = say(\"compared 1\", 1) < say(\"compared 2\", 2);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"call 1\ncall 2\ntuple 1\ntuple 2\nlist 1\nlist 2\noperand 1\n"
                   "operand 2\ncompared 1\ncompared 2\n">>, Output).

%% report §4.6: shadowing rebinds; each binding is its own variable
shadowing_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    let x = 1;\n"
        "    let x = x + 1;\n"
        "    let #(x, y) = #(x * 10, x);\n"
        "    Io.println(Int.toString(x + y))\n"
        "}\n"),
    ?assertEqual(<<"22\n">>, Output).

%% report §5.5, §7.1: a value error is an Either or Optional; `<-` on Either
%% returns the Left, on Optional the None
bind_arrow_test() ->
    {ok, Output} = ern_program:run(
        "fn half(n : Int) : Either(String, Int) =\n"
        "    if n % 2 == 0 then Right(n / 2) else Left(\"odd\")\n"
        "fn quarter(n : Int) : Either(String, Int) = {\n"
        "    let h <- half(n);\n"
        "    let q <- half(h);\n"
        "    Right(q)\n"
        "}\n"
        "fn both(a : Optional(Int), b : Optional(Int)) : Optional(Int) = {\n"
        "    let x <- a;\n"
        "    let y <- b;\n"
        "    Some(x + y)\n"
        "}\n"
        "fn show(e : Either(String, Int)) : String = match e {\n"
        "    Right(n) -> Int.toString(n)\n"
        "  | Left(s) -> s\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    Io.println(show(quarter(8)));\n"
        "    Io.println(show(quarter(6)));\n"
        "    Io.println(Int.toString(Optional.withDefault(both(Some(1), Some(2)), -1)));\n"
        "    Io.println(Int.toString(Optional.withDefault(both(Some(1), None), -1)))\n"
        "}\n"),
    ?assertEqual(<<"2\nodd\n3\n-1\n">>, Output).

%% report §4.6, §8.5: top-level lets are evaluated before main, in
%% dependency order whatever their textual order, a dependency through a
%% called function included
top_level_let_test() ->
    {ok, Output} = ern_program:run(
        "let total = base * 2\n"
        "let base = count()\n"
        "fn count() : Int = List.size(items)\n"
        "let items = [1, 2, 3]\n"
        "export fn main() : Unit = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"6\n">>, Output).

%%
%% Expressions
%%

%% report §5.9, §5.10: a guard that is not an Erlang guard falls through
%% to the next clause
match_general_guard_test() ->
    {ok, Output} = ern_program:run(
        "fn small(n : Int) : Bool = n < 3\n"
        "fn name(n : Int) : String = match n {\n"
        "    k when small(k) -> \"small\"\n"
        "  | k when k % 2 == 0 -> \"even\"\n"
        "  | _ -> \"odd\"\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    Io.println(name(1));\n"
        "    Io.println(name(4));\n"
        "    Io.println(name(5))\n"
        "}\n"),
    ?assertEqual(<<"small\neven\nodd\n">>, Output).

%% report §5.9: a guard that faults faults the process; it never becomes a
%% silent `false` as an Erlang guard would, since only comparisons that
%% cannot fault are emitted as Erlang guards and every other guard runs as
%% an expression that falls through on `false` alone
match_guard_faults_test() ->
    {Result, _} = ern_program:run(
        "fn name(n : Int) : String = match n {\n"
        "    k when k == 7 -> \"seven\"\n"
        "  | k when 10 / k == 5 -> \"half\"\n"
        "  | _ -> \"other\"\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    Io.println(name(7));\n"
        "    Io.println(name(2));\n"
        "    Io.println(name(0))\n"
        "}\n"),
    ?assertMatch({fault, <<"division by zero">>, _}, Result).

%% report §5.9: a clause with alternatives runs one body for whichever
%% alternative matched, with that alternative's variables; a guard applies to
%% every alternative, as an Erlang guard or as an expression; a faulting guard
%% still faults
or_pattern_test() ->
    Shape = "type Shape = Circle(Int) | Square(Int) | Dot\n",
    Kind = "fn kind(s : Shape) : String = match s {\n"
           "    Circle(n) or Square(n) when 10 / n > 0 -> \"sized\"\n"
           "  | _ -> \"dot\"\n"
           "}\n",
    {ok, Output} = ern_program:run(Shape ++ Kind ++
        "fn area(s : Shape) : Int = match s {\n"
        "    Circle(n) or Square(n) when n > 1 -> n * 10\n"
        "  | Circle(n) or Square(n) -> n\n"
        "  | Dot -> 0\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(area(Circle(1))));\n"
        "    Io.println(Int.toString(area(Square(2))));\n"
        "    Io.println(Int.toString(area(Dot)));\n"
        "    Io.println(kind(Square(5)));\n"
        "    Io.println(kind(Dot))\n"
        "}\n"),
    ?assertEqual(<<"1\n20\n0\nsized\ndot\n">>, Output),
    {Result, _} = ern_program:run(Shape ++ Kind ++
        "export fn main() : Unit = Io.println(kind(Circle(0)))\n"),
    ?assertMatch({fault, <<"division by zero">>, _}, Result).

%% report §5.9: a guard that is no Erlang guard falls through to the
%% clauses after it, in each shape: a guard false and a pattern failing,
%% beside a clause with an Erlang guard before it and a second such guard
%% after; an or-pattern; a match in a guard and in a clause's body; a size
%% read from a local and from a top-level `let`; a requirement's member
%% and a local fn the clauses after use; a match in a lambda and in a
%% local fn, reading what they capture; in a binding's initializer; a
%% clause after that binds its own variables; and a guard that faults,
%% which faults the process. Written with the clauses after a guard made a
%% function of the unit (the log's *A Guard's Fallthrough Is a Function*)
guard_fallthrough_shapes_test() ->
    {Result, Output} = ern_program:run(
        "type Shape = Circle(Int) | Square(Int) | Dot\n"
        "let width : Int = List.size([1, 2, 3, 4, 5, 6, 7, 8])\n"
        "fn small(n : Int) : Bool = n < 3\n"
        "fn even(n : Int) : Bool = n % 2 == 0\n"
        "fn name(n : Int, label : String) : String = match n {\n"
        "    0 -> \"zero\"\n"
        "  | k when small(k) -> label <> \" small\"\n"
        "  | 10 -> \"ten\"\n"
        "  | k when k > 100 -> \"big\"\n"
        "  | k when even(k) -> label <> \" even \" <> Int.toString(k)\n"
        "  | other -> label <> \" odd \" <> Int.toString(other)\n"
        "}\n"
        "fn kind(s : Shape, limit : Int) : String = match s {\n"
        "    Circle(n) or Square(n) when small(n) -> \"small\"\n"
        "  | Circle(n) when n > limit -> \"large circle\"\n"
        "  | Square(n) -> \"square \" <> Int.toString(n + limit)\n"
        "  | _ -> \"other\"\n"
        "}\n"
        "fn nested(n : Int, m : Int) : String = match n {\n"
        "    k when (match m { j when small(j) -> true | _ -> false }) -> \"m small\"\n"
        "  | k when even(k) -> match m {\n"
        "        j when even(j) -> \"both even\"\n"
        "      | j -> \"n even \" <> Int.toString(j + k)\n"
        "    }\n"
        "  | _ -> \"neither\"\n"
        "}\n"
        "fn sized(n : Int, b : Bytes) : Int = match b {\n"
        "    <<x:size(n), _:bytes>> when small(x) -> x\n"
        "  | <<y:size(n), z:size(width)>> -> y * 1000 + z\n"
        "  | _ -> -1\n"
        "}\n"
        "fn least(x : a, y : a, fallback : Int) : Int needs a.compare = {\n"
        "    let offset = 5;\n"
        "    fn shifted(k : Int) : Int = k + offset;\n"
        "    match fallback {\n"
        "        k when small(k) -> k\n"
        "      | k -> match compare(x, y) { Less -> shifted(k) | _ -> shifted(-k) }\n"
        "    }\n"
        "}\n"
        "fn captured(base : Int) : List(String) = {\n"
        "    let suffix = \"!\";\n"
        "    fn local(k : Int) : String = match k {\n"
        "        j when small(j) -> \"local small\"\n"
        "      | j -> \"local \" <> Int.toString(j + base) <> suffix\n"
        "    };\n"
        "    List.map([1, 5], fn(k : Int) : String = match k {\n"
        "        j when small(j) -> \"lambda small\" <> suffix\n"
        "      | j -> \"lambda \" <> Int.toString(j * base)\n"
        "    }) <> [local(1), local(7)]\n"
        "}\n"
        "let classified : List(String) = List.map([1, 4, 9], fn(k : Int) : String = match k {\n"
        "    j when small(j) -> \"s\"\n"
        "  | j when even(j) -> \"e\"\n"
        "  | _ -> \"o\"\n"
        "})\n"
        "fn quotient(n : Int) : String = match n {\n"
        "    k when 10 / k > 2 -> \"big quotient\"\n"
        "  | _ -> \"small quotient\"\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    List.forEach([0, 1, 10, 200, 4, 7], fn(n : Int) = Io.println(name(n, \"n\")));\n"
        "    List.forEach([Circle(1), Square(2), Circle(9), Circle(4), Square(7), Dot],\n"
        "                 fn(s : Shape) = Io.println(kind(s, 5)));\n"
        "    Io.println(nested(4, 1));\n"
        "    Io.println(nested(4, 6));\n"
        "    Io.println(nested(4, 7));\n"
        "    Io.println(nested(5, 7));\n"
        "    List.forEach([<<1, 9>>, <<7, 9>>, <<7>>],\n"
        "                 fn(b : Bytes) = Io.println(Int.toString(sized(8, b))));\n"
        "    Io.println(Int.toString(least(1, 2, 1)));\n"
        "    Io.println(Int.toString(least(1, 2, 7)));\n"
        "    Io.println(Int.toString(least(\"b\", \"a\", 7)));\n"
        "    List.forEach(captured(3) <> classified, Io.println);\n"
        "    Io.println(quotient(1));\n"
        "    Io.println(quotient(5));\n"
        "    Io.println(quotient(0))\n"
        "}\n"),
    ?assertMatch({fault, <<"division by zero">>, _}, Result),
    ?assertEqual(<<"zero\nn small\nten\nbig\nn even 4\nn odd 7\n"
                   "small\nsmall\nlarge circle\nother\nsquare 12\nother\n"
                   "m small\nboth even\nn even 11\nneither\n"
                   "1\n7009\n-1\n"
                   "1\n12\n-2\n"
                   "lambda small!\nlambda 15\nlocal small\nlocal 10!\ns\ne\no\n"
                   "big quotient\nsmall quotient\n">>, Output).

%% report §5.9, Appendix E.21: a fault in the clauses a guard falls through
%% to is traced by the top-level declaration they are written in and the
%% frame's own line, in the declaration's own body, in a lambda's and in a
%% local fn's, as a frame of a lambda is named. Written with the clauses
%% after a guard made a function of the unit
guard_fallthrough_traced_test() ->
    Traced = fun(Body) ->
                 {{fault, <<"division by zero">>, Trace}, _} =
                     ern_program:run(
                         ['Fell'], "fn small(n : Int) : Bool = n < 0\n" ++ Body
                                   ++ "export fn main() : Unit = Io.println(Int.toString(f(7)))\n",
                         #{}),
                 frames(Trace)
             end,
    ?assertEqual([<<"erlang:'div'/2">>, <<"Fell.f:5">>, <<"Fell.main:7">>],
                 Traced("fn f(n : Int) : Int = match n {\n"
                        "    k when small(k) -> 0\n"
                        "  | k ->\n"
                        "      10 / (k - 7)\n"
                        "}\n")),
    ?assertMatch([<<"erlang:'div'/2">>, <<"Fell.f:6">>, <<"List.map:", _/binary>>, <<"Fell.f:3">>,
                  <<"Fell.main:8">>],
                 Traced("fn f(n : Int) : Int =\n"
                        "    List.size(List.map([n], fn(m : Int) : Int = match m {\n"
                        "        k when small(k) -> 0\n"
                        "      | k ->\n"
                        "          10 / (k - 7)\n"
                        "    }))\n")),
    ?assertEqual([<<"erlang:'div'/2">>, <<"Fell.f:5">>, <<"Fell.f:7">>, <<"Fell.main:9">>],
                 Traced("fn f(n : Int) : Int = {\n"
                        "    fn g(m : Int) : Int = match m {\n"
                        "        k when small(k) -> 0\n"
                        "      | k -> 10 / (k - 7)\n"
                        "    };\n"
                        "    g(n) + 1\n"
                        "}\n")).

%% report §5.9, §10: the clauses a guard falls through to are in tail
%% position where the match is, so that a loop through the fallthrough
%% keeps constant stack: the stack at the bottom of a hundred thousand
%% fallthroughs is the stack at the bottom of ten. Written with the clauses
%% after a guard made a function of the unit
guard_fallthrough_keeps_constant_stack_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn stackSize() : Int = \"ern_emitter_tests:stack_size/0\"\n"
        "fn negative(n : Int) : Bool = n < 0\n"
        "fn depth(n : Int) : Int = match n {\n"
        "    0 -> stackSize()\n"
        "  | k when negative(k) -> 0\n"
        "  | k -> depth(k - 1)\n"
        "}\n"
        "export fn main() : Unit = Io.println(Int.toString(depth(100000) - depth(10)))\n"),
    ?assertEqual(<<"0\n">>, Output).

%% The words of the calling process's stack, which
%% guard_fallthrough_keeps_constant_stack_test reads at a loop's bottom.
-spec stack_size() -> non_neg_integer().
stack_size() ->
    {stack_size, Words} = erlang:process_info(self(), stack_size),
    Words.

%% report §5.9, §11.1: the clauses a guard falls through to are a function
%% of the unit, '$N.fallthroughK', unexported, given the matched value and
%% each local in scope that they use and no other, and the unit holds no
%% fun for the match: the guard on `small` falls through to clauses that read
%% `label`, the guard on `even` to one that reads nothing more, and a guard
%% of a match in a clause's body to one that reads `label`; `unused` is
%% passed to none. Written with the clauses after a guard made a function
%% of the unit
guard_fallthrough_makes_no_fun_test() ->
    Text = "fn small(n : Int) : Bool = n < 3\n"
           "fn even(n : Int) : Bool = n % 2 == 0\n"
           "export fn name(n : Int, label : String, unused : Int) : String = match n {\n"
           "    0 -> \"zero\"\n"
           "  | k when small(k) -> \"small\"\n"
           "  | k when even(k) -> match k {\n"
           "        j when j > 100 -> \"big\"\n"
           "      | j when small(j - 98) -> \"near\"\n"
           "      | _ -> label\n"
           "    }\n"
           "  | _ -> \"odd\"\n"
           "}\n",
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    {ok, _, Beam} = ern_compile:compiled(ern_compile:forms(['M'], Typed, Env), []),
    {beam_file, _, Exports, _, _, Functions} = beam_disasm:file(Beam),
    ?assertEqual([{'$3', 3}, {'$3.fallthrough1', 2}, {'$3.fallthrough2', 1},
                  {'$3.fallthrough3', 2}],
                 lists:sort([{Name, Arity} || {function, Name, Arity, _, _} <- Functions,
                                              lists:prefix("$3", atom_to_list(Name))])),
    ?assertEqual([], [Name || {function, Name, _, _, _} <- Functions,
                              lists:prefix("-$3", atom_to_list(Name))]),
    ?assertEqual([], [Name || {Name, _, _} <- Exports,
                              lists:prefix("$3.", atom_to_list(Name))]).

%% report Appendix E.1: Io.debug prints a value as Ernest writes it, by the
%% argument's type at the call, known whole there, and returns it; a type
%% variable there is a type error (ern_typecheck_tests)
io_debug_test() ->
    {ok, Output} = ern_program:run(
        "type Shape = Circle(Int) | Dot\n"
        "type Snap = Snap(seen : Int, dir : String)\n"
        "type State = Ready | Busy\n"
        "export fn main() : Unit = {\n"
        "    let n = Io.debug(4) + 1;\n"
        "    let _ = Io.debug(n);\n"
        "    let _ = Io.debug([Circle(-3), Dot]);\n"
        "    let _ = Io.debug(#(1.5, \"a\\nb\", true, Unit));\n"
        "    let _ = Io.debug(Snap(dir = \"x\", seen = 2));\n"
        "    let _ = Io.debug(Map.put(Map.empty, \"k\", [1]));\n"
        "    let _ = Io.debug(Set.fromList([2, 1]));\n"
        "    let _ = Io.debug(fn(x : Int) = x);\n"
        "    let _ = Io.debug(#(true, false));\n"
        "    let _ = Io.debug(\"é中\");\n"
        "    let _ = Io.debug(#('a', '\\'', Some('\\n')));\n"
        "    let _ = Io.debug(#(Ready, 1));\n"
        "    let _ = Io.debug(<<104, 105>>);\n"
        "    let _ = List.map(['x'], Io.debug);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"4\n5\n[M.Circle(-3), M.Dot]\n#(1.5, \"a\\nb\", true, Unit)\n"
                   "M.Snap(seen = 2, dir = \"x\")\n"
                   "Map.fromList([#(\"k\", [1])])\nSet.fromList([1, 2])\n<function>\n"
                   "#(true, false)\n\"é中\"\n#('a', '\\'', Some('\\n'))\n#(M.Ready, 1)\n"
                   "<<104, 105>>\n'x'\n"/utf8>>, Output).

%% report Appendix E.1: Io.show writes a value by its type at the call, as
%% a function value too, and pure
show_test() ->
    {ok, Output} = ern_program:run(
        "type Snap = Snap(seen : Int, dir : String)\n"
        "fn pure(c : Char) : String = Io.show(Some(c))\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Io.show(Snap(dir = \"x\", seen = 2)));\n"
        "    Io.println(pure('a'));\n"
        "    Io.println(String.join(List.map([<<1>>, <<2, 3>>], Io.show), \" \"))\n"
        "}\n"),
    ?assertEqual(<<"M.Snap(seen = 2, dir = \"x\")\nSome('a')\n<<1>> <<2, 3>>\n">>, Output).

%% report §6.6, Appendix E.1: a server keeps the replies it cannot answer
%% yet as it keeps any value, in a list, in a map and captured by a lambda
%% in a list, and answers each once it holds all three; a second answer is
%% dropped, and a reply prints as `<reply>`. A regression test written after
%% the code, when the reply's obligation went, which refused the map, the
%% lambda and the second answer; it does not cover an answer that comes
%% after its caller's deadline
replies_kept_as_values_test() ->
    {ok, Output} = ern_program:run(
        "type Request = Ask(n : Int, reply : Reply(Int))\n"
        "type Main = Got(Int)\n"
        "fn serve(pending : List(Reply(Int)), byKey : Map(Int, Reply(Int)),\n"
        "         later : List(() -> Unit receiving Request), count : Int) : Unit receiving"
        " Request =\n"
        "    if count == 3 then release(pending, byKey, later)\n"
        "    else receive {\n"
        "        Ask(=n, =reply) ->\n"
        "            if n == 1 then serve(reply :: pending, byKey, later, count + 1)\n"
        "            else if n == 2 then\n"
        "                serve(pending, Map.put(byKey, n, reply), later, count + 1)\n"
        "            else\n"
        "                serve(pending, byKey, (fn() = answer(reply, n * 10)) :: later,\n"
        "                      count + 1)\n"
        "    }\n"
        "fn release(pending : List(Reply(Int)), byKey : Map(Int, Reply(Int)),\n"
        "           later : List(() -> Unit receiving Request)) : Unit receiving Request = {\n"
        "    Io.println(Io.show(pending));\n"
        "    List.forEach(pending, fn(reply) = { answer(reply, 10); answer(reply, 100) });\n"
        "    Map.forEach(byKey, fn(key, reply) = answer(reply, key * 10));\n"
        "    List.forEach(later, fn(f) = f())\n"
        "}\n"
        "export fn main() : Unit receiving Main = {\n"
        "    let server = spawn(fn() = serve([], Map.empty, [], 0));\n"
        "    let me = self();\n"
        "    List.forEach([1, 2, 3], fn(n) = {\n"
        "        let _ = spawn(fn() =\n"
        "            send(me, Got(Address.callForever(server,\n"
        "                                             fn(reply) = Ask(=n, =reply)))));\n"
        "        Unit\n"
        "    });\n"
        "    let a = receive { Got(v) -> v };\n"
        "    let b = receive { Got(v) -> v };\n"
        "    let c = receive { Got(v) -> v };\n"
        "    Io.println(Io.show(List.sort([a, b, c])))\n"
        "}\n"),
    ?assertEqual(<<"[<reply>]\n[10, 20, 30]\n">>, Output).

%% report §4.2, §4.5: a module's own type named Float may have members
%% negate and compare, and prefix `-`, in a lambda too, `compare` and `<`
%% on the type reach the module's. A regression test, rewritten when a
%% member became an operator, `compare` or `negate`, and when a member's
%% name left the expressions: it held the same of `Io.show` and `Io.debug`,
%% where the emitter read the written path and called the library's in
%% their place
own_member_over_prelude_test() ->
    {ok, Output} = ern_program:run(
        "type Float = Float(n : Int)\n"
        "fn Float.negate(x : Float) : String = \"mine \" <> Int.toString(x.n)\n"
        "fn Float.compare(a : Float, b : Float) : Ordering = Less\n"
        "export fn main() : Unit = {\n"
        "    Io.println(-Float(n = 1));\n"
        "    let f = fn(x : Float) = -x;\n"
        "    Io.println(f(Float(n = 2)));\n"
        "    Io.println(Io.show(compare(Float(n = 1), Float(n = 1))));\n"
        "    Io.println(Io.show(Float(n = 1) < Float(n = 1)))\n"
        "}\n"),
    ?assertEqual(<<"mine 1\nmine 2\nLess\ntrue\n">>, Output).

%% report Appendix E.1: Io.debug writes a String as a literal, with `"`,
%% `\\`, a line feed and a tab escaped by name, another control character
%% by its code point, and every other character as itself. A regression
%% test, written after the code; it does not cover a character outside
%% the Basic Multilingual Plane
io_debug_escapes_test() ->
    {ok, Output} = ern_program:run("export fn main() : Unit = {\n"
                                   "    let _ = Io.debug(\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\");\n"
                                   "    Unit\n"
                                   "}\n"),
    ?assertEqual(<<"\"a\\\"b\\\\c\\n\\t\\u{1}\\u{7F}é\"\n"/utf8>>, Output).

%% report §6.3, §6.6, Appendix E.0 rule 8, E.15: a time below 0 is 0, in
%% `after`, in `Address.call`, in `Clock.alarm` and in `Clock.sleep`. A
%% regression test: the first two faulted with the host's `timeout_value`,
%% and the alarm crashed the clock, which left the program waiting for
%% ever; the sleep's case was written with it, after the code
negative_time_test() ->
    {ok, Output} = ern_program:run(
        "type M = M | Get(reply : Reply(Int))\n"
        "export fn main() : Unit receiving M = {\n"
        "    receive { Get(reply = r) -> answer(r, 1) | after 0 - 5 ->"
        " Io.println(\"after\") };\n"
        "    let quiet = spawn(fn() : Unit receiving M = receive { M -> Unit });\n"
        "    let asked = Address.call(quiet, fn(r) = Get(reply = r), 0 - 1);\n"
        "    Io.println(match asked { Some(_) -> \"some\" | None -> \"none\" });\n"
        "    let _ = Clock.alarm(0 - 10, fn(_) = M);\n"
        "    receive { M -> Io.println(\"alarm\") | Get(reply = r) -> answer(r, 0)"
        " };\n"
        "    Clock.sleep(0 - 5);\n"
        "    Io.println(\"slept\")\n"
        "}\n"),
    ?assertEqual(<<"after\nnone\nalarm\nslept\n">>, Output).

%% report §6.3, §6.6, Appendix E.0 rule 8: a time has no upper bound, so a
%% time beyond the host's longest wait, 2^32 - 1 ms, waits as any other: a
%% message that comes after 50 ms is received, a call is answered, and a
%% file is read. A regression test: each faulted with the host's
%% timeout_value. The message and the answer come once the waiting side
%% waits, so that each wait is made with its time. It does not cover a wait
%% that outlasts one slice of 2^32 - 1 ms, nor an alarm, which ern_rt_tests
%% covers
long_time_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ping | Go | Get(reply : Reply(Int), caller : Process)\n"
        "foreign fn waiting(process : Process) : Foreign.Term = \"ern_waits:waiting/1\"\n"
        "fn later(to : Address(Msg)) : Unit receiving Msg = {\n"
        "    receive { Go -> Unit };\n"
        "    let _ = waiting(Process.fromAddress(to));\n"
        "    send(to, Ping)\n"
        "}\n"
        "fn server() : Unit receiving Msg = receive {\n"
        "    Get(reply = r, caller = c) -> { let _ = waiting(c); answer(r, 7) }\n"
        "  | Ping -> Unit\n"
        "  | Go -> Unit\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let me = self();\n"
        "    let sender = spawn(fn() = later(me));\n"
        "    send(sender, Go);\n"
        "    receive {\n"
        "        Ping -> Io.println(\"ping\")\n"
        "      | after 5000000000 -> Io.println(\"after\")\n"
        "    };\n"
        "    let a = spawn(server);\n"
        "    let caller = Process.fromAddress(me);\n"
        "    let _ = Io.debug(Address.call(a, fn(r) = Get(reply = r, =caller),"
        " 5000000000));\n"
        "    match Fs.read(Path(\"VERSION\"), 5000000000) {\n"
        "        Right(_) -> Io.println(\"read\")\n"
        "      | Left(_) -> Io.println(\"not read\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"ping\nSome(7)\nread\n">>, Output).

%% report §3.10, §9.3, §9.6, §4.9, §3.5: a tuple and a list order
%% component by component from the left, a list before a longer one it
%% begins, Optional None before Some and Either Left before Right, then by
%% the element: `<` on each, a sort of tuples, a requirement
%% reaching through a tuple and a list to the element, a derived compare
%% over fields of the four, and an ordered set of lists. Written with the
%% rule (the log's *The Review's Decisions*)
structural_compare_test() ->
    {ok, Output} = ern_program:run(
        "type Date = Date(year : Int, at : Optional(Int), tags : List(String),"
        " pair : #(Int, String)) derives compare\n"
        "type Box(a) = Box(items : List(a), first : Optional(a)) derives compare\n"
        "fn largest(list : List(a)) : Optional(a) needs a.compare =\n"
        "    List.foldLeft(list, None, fn(acc, x) = if Some(x) > acc then Some(x) else acc)\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Io.show(#(#(1, \"b\") < #(1, \"c\"), #(2, 'a') <= #(1, 'z'))));\n"
        "    Io.println(Io.show(#([1, 2] < [1, 2, 0], [] < [0], [3] >= [2, 9])));\n"
        "    Io.println(Io.show(#(None < Some(0), Some(2) < Some(1))));\n"
        "    let right : Either(Int, Int) = Right(1);\n"
        "    Io.println(Io.show(#(Left(9) < Right(\"a\"), right < Right(2))));\n"
        "    let pairs = [#(2, \"a\"), #(1, \"z\"), #(1, \"b\")];\n"
        "    Io.println(Io.show(List.sort(pairs)));\n"
        "    Io.println(Io.show(largest([#(1, [2]), #(1, [3]), #(0, [9])])));\n"
        "    let earlier = Date(year = 1, at = None, tags = [], pair = #(1, \"a\"));\n"
        "    let later = Date(year = 1, at = Some(0), tags = [], pair = #(0, \"a\"));\n"
        "    Io.println(Io.show(compare(earlier, later)));\n"
        "    let empty = Box(items = [1], first = None);\n"
        "    Io.println(Io.show(empty < Box(items = [1], first = Some(0))));\n"
        "    Io.println(Io.show(OrderedSet.toList(OrderedSet.fromList([[2], [1, 5], [1]]))))\n"
        "}\n"),
    ?assertEqual(<<"#(true, false)\n#(true, true, true)\n#(true, false)\n#(true, true)\n"
                   "[#(1, \"b\"), #(1, \"z\"), #(2, \"a\")]\nSome(#(1, [3]))\nLess\ntrue\n"
                   "[[1], [1, 5], [2]]\n">>, Output).

%% report §3.10, §9.6, §4.9: the prelude's `compare(a, b)` runs the
%% operand type's compare, as `<` does: an Int's, a String's, a tuple's, a
%% list's, a derived one, the requirement's member in a generic function,
%% and as a value and in a piped call, beside a sort of pairs, which needs
%% the order and writes none. Written with the rule (the log's *One Name
%% for Every Order*)
prelude_compare_test() ->
    {ok, Output} = ern_program:run(
        "type Day = Mon | Tue | Wed derives compare\n"
        "fn ordered(x : a, y : a) : Ordering needs a.compare = compare(x, y)\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Io.show(#(compare(1, 2), compare(\"b\", \"a\"), compare(2.5, 2.5))));\n"
        "    Io.println(Io.show(#(compare(#(1, \"a\"), #(1, \"b\")), compare([1, 2], [1]))));\n"
        "    Io.println(Io.show(#(compare(Tue, Mon), ordered(#(Wed, [1]), #(Wed, [2])))));\n"
        "    let pairs = [#(\"pear\", 2), #(\"fig\", 3), #(\"pear\", 1)];\n"
        "    Io.println(Io.show(List.sort(pairs)));\n"
        "    let order = compare;\n"
        "    Io.println(Io.show(#(order('b', 'a'), 5 |> compare(5))))\n"
        "}\n"),
    ?assertEqual(<<"#(Less, Greater, Equal)\n#(Less, Greater)\n#(Greater, Less)\n"
                   "[#(\"fig\", 3), #(\"pear\", 1), #(\"pear\", 2)]\n#(Greater, Equal)\n">>,
                 Output).

%% report §6.6, Appendix E.21: `Process.fromReply(r)` is the caller's
%% `Process`, which the callee compares and monitors: the caller is told it
%% is itself, and the callee, keeping a second caller's reply, is told of
%% that caller's end by the monitor the reply gave it; taken as a value it
%% is the same function
from_reply_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ask(Reply(Process)) | Hold(Reply(Unit)) | Ended(Down)\n"
        "type MainMsg = Holding | Told(Bool)\n"
        "fn serve(main : Address(MainMsg), held : Optional(Process)) : Unit receiving Msg =\n"
        "    receive {\n"
        "        Ask(r) -> {\n"
        "            let process = Process.fromReply;\n"
        "            answer(r, process(r));\n"
        "            serve(main, held)\n"
        "        }\n"
        "      | Hold(r) -> {\n"
        "            monitor(Process.fromReply(r), Ended);\n"
        "            send(main, Holding);\n"
        "            serve(main, Some(Process.fromReply(r)))\n"
        "        }\n"
        "      | Ended(Down(process = p)) -> send(main, Told(Some(p) == held))\n"
        "    }\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let me = self();\n"
        "    let server = spawn(fn() = serve(me, None));\n"
        "    let asker = Address.callForever(server, Ask);\n"
        "    Io.println(\"itself: \" <> Io.show(asker == Process.current()));\n"
        "    let caller = spawn(fn() = Address.callForever(server, Hold));\n"
        "    receive {\n"
        "        Holding -> kill(Process.fromAddress(caller))\n"
        "      | Told(_) -> Unit\n"
        "    };\n"
        "    receive {\n"
        "        Told(same) -> Io.println(\"the caller ended: \" <> Io.show(same))\n"
        "      | Holding -> Unit\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"itself: true\nthe caller ended: true\n">>, Output).

%% report §4.6, §6.5, §8.5: a service is a top-level binding whose
%% initializer spawns the process, before main, in the entry process;
%% functions reach it by its name, and a restarting one keeps its address
service_binding_test() ->
    {ok, Output} = ern_program:run(
        "export type LogMsg = Log(String) | Crash | Count(reply : Reply(Int))\n"
        "fn logger(n : Int) : Unit receiving LogMsg = receive {\n"
        "    Log(_) -> logger(n + 1)\n"
        "  | Crash -> fault(\"crash\")\n"
        "  | Count(reply = r) -> { answer(r, n); logger(n) }\n"
        "}\n"
        "export let log : Address(LogMsg) =\n"
        "    spawn(restarting(RestartLimit(restarts = 3, within = 60000),\n"
        "                     fn() : Unit receiving LogMsg = logger(0)))\n"
        "let started = Io.println(\"started\")\n"
        "fn note(s : String) : Unit = send(log, Log(s))\n"
        "fn counted() : Int = match Address.call(log, fn(r) = Count(reply = r), 1000) {\n"
        "    Some(n) -> n\n"
        "  | None -> counted()\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    note(\"a\");\n"
        "    send(log, Crash);\n"
        "    // answered by the new run, whose start empties the mailbox (§6.9); a\n"
        "    // call the restart ends is made again\n"
        "    let _ = counted();\n"
        "    note(\"b\");\n"
        "    Io.println(Int.toString(counted()))\n"
        "}\n"),
    ?assertEqual(<<"started\n1\n">>, Output).

%% report §6.9, §8.5: a process a top-level initializer spawns names that
%% binding's declaration as its spawn site
service_site_test() ->
    {ok, Output} = ern_program:run(
        "type MainMsg = Died(Down)\n"
        "export let quick : Address(Int) =\n"
        "    spawn(fn() : Unit receiving Int = receive { _ -> fault(\"x\") })\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    monitor(Process.fromAddress(quick), Died);\n"
        "    send(quick, 1);\n"
        "    receive { Died(Down(reason = _, site = s)) -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"M.quick:3\n">>, Output).

%% Appendix E.15, §5.6: an alarm carries the time it fired, so a
%% single-positional constructor passes as its wrap, as `Died` does to
%% `monitor`
alarm_time_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Tick(Int)\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let before = Clock.now();\n"
        "    let _ = Clock.alarm(5, Tick);\n"
        "    receive { Tick(at) -> Io.println(Bool.toString(at >= before)) }\n"
        "}\n"),
    ?assertEqual(<<"true\n">>, Output).

%% report §5.9, §6.3: alternatives in a receive clause select either message
receive_or_pattern_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Inc(Int) | Dec(Int) | Stop\n"
        "fn loop(n : Int) : Int receiving Msg = receive {\n"
        "    Inc(k) or Dec(k) -> loop(n + k)\n"
        "  | Stop -> n\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let me = self();\n"
        "    send(me, Inc(2));\n"
        "    send(me, Dec(3));\n"
        "    send(me, Stop);\n"
        "    Io.println(Int.toString(loop(0)))\n"
        "}\n"),
    ?assertEqual(<<"5\n">>, Output).

%% report §6.3: a receive guard is a guard expression, emitted as an Erlang
%% guard, tested while the message stays in the mailbox
receive_guard_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = N(Int)\n"
        "type Seen = Ended(Down)\n"
        "fn loop(acc : Int) : Unit receiving Msg = receive {\n"
        "    N(k) when k > 0 -> loop(acc + k)\n"
        "  | N(_) -> Io.println(Int.toString(acc))\n"
        "}\n"
        "export fn main() : Unit receiving Seen = {\n"
        "    let p = spawn(fn() = loop(0));\n"
        "    monitor(Process.fromAddress(p), Ended);\n"
        "    send(p, N(2));\n"
        "    send(p, N(3));\n"
        "    send(p, N(0));\n"
        "    receive { Ended(_) -> Unit }\n"
        "}\n"),
    ?assertEqual(<<"5\n">>, Output).

%% report §6.3: a compound guard expression; a message the guard rejects
%% stays in the mailbox
receive_guard_compound_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = N(Int) | Stop\n"
        "fn loop(limit : Int) : Unit receiving Msg = receive {\n"
        "    N(k) when k > limit && k != 7 -> { Io.println(Int.toString(k)); loop(limit) }\n"
        "  | Stop -> Unit\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    send(self(), N(1));\n"
        "    send(self(), N(9));\n"
        "    send(self(), N(7));\n"
        "    send(self(), Stop);\n"
        "    loop(5)\n"
        "}\n"),
    ?assertEqual(<<"9\n">>, Output).

%% report §6.3, §3.10: a receive guard orders two Bools, `false` before
%% `true`, as it orders two Ints; a message the guard rejects stays in the
%% mailbox
receive_guard_bool_order_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Flags(#(Bool, Bool)) | Stop\n"
        "fn take() : Int receiving Msg =\n"
        "    receive { Flags(#(a, b)) when a < b -> 1 | Stop -> 0 }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    send(self(), Flags(#(true, false)));\n"
        "    send(self(), Flags(#(false, true)));\n"
        "    send(self(), Stop);\n"
        "    Io.println(Int.toString(take()));\n"
        "    Io.println(Int.toString(take()));\n"
        "    receive { Flags(pair) -> Io.println(Io.show(pair)) }\n"
        "}\n"),
    ?assertEqual(<<"1\n0\n#(true, false)\n">>, Output).

%% report §6.3: `!` before a guard expression and a negative literal in a
%% receive guard, emitted as an Erlang guard; the messages the guard
%% rejects stay in the mailbox
receive_guard_not_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = N(Int) | Stop\n"
        "fn take(flag : Bool) : Int receiving Msg = receive {\n"
        "    N(k) when !flag && !(k > 5) && k > -3 -> k\n"
        "  | Stop -> 100\n"
        "}\n"
        "fn negative() : Int receiving Msg = receive { N(k) when k < -1 -> k }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    send(self(), N(9));\n"
        "    send(self(), N(-4));\n"
        "    send(self(), N(2));\n"
        "    send(self(), Stop);\n"
        "    Io.println(Int.toString(take(false)));\n"
        "    Io.println(Int.toString(take(true)));\n"
        "    Io.println(Int.toString(negative()))\n"
        "}\n"),
    ?assertEqual(<<"2\n100\n-4\n">>, Output).

%% report §6.3: an operand, and a guard expression, in parentheses select as
%% the bare form does, the messages a guard rejects staying in the mailbox:
%% operands in parentheses on both sides of a comparison, and a joined
%% guard expression in parentheses with each of its parts. A regression
%% test, written after the code; the forms the checker takes are its own
%% tests'
receive_guard_parentheses_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = N(Int) | Stop\n"
        "fn operands(limit : Int) : Int receiving Msg = receive {\n"
        "    N(k) when (k) > (limit) -> k\n"
        "  | Stop -> 0\n"
        "}\n"
        "fn grouped(limit : Int) : Int receiving Msg = receive {\n"
        "    N(k) when ((k > limit) && (k != 7)) -> k\n"
        "  | Stop -> 0\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    List.forEach([N(1), N(7), N(9), N(3), Stop, Stop], fn(m) = send(self(), m));\n"
        "    Io.println(Int.toString(grouped(5)));\n"
        "    Io.println(Int.toString(operands(5)));\n"
        "    Io.println(Int.toString(grouped(5)));\n"
        "    Io.println(Int.toString(operands(5)));\n"
        "    receive { N(k) -> Io.println(Int.toString(k)) };\n"
        "    receive { N(k) -> Io.println(Int.toString(k)) }\n"
        "}\n"),
    ?assertEqual(<<"9\n7\n0\n0\n1\n3\n">>, Output).

%% report §5.9, §4.6: a match guard may read a top-level `let`, which is
%% read through its getter, so the guard is not compiled as an Erlang guard
match_guard_top_level_let_test() ->
    {ok, Output} = ern_program:run(
        "let limit = 5\n"
        "fn size(n : Int) : String = match n { m when m > limit -> \"big\" | _ -> \"small\" }\n"
        "export fn main() : Unit = {\n"
        "    Io.println(size(9));\n"
        "    Io.println(size(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Output).

%% report §3.1, §4.8, §9.6: Int arithmetic, comparison, and the Boolean
%% operators
operators_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(-7 / 3));\n"
        "    Io.println(Int.toString(-7 % 3));\n"
        "    Io.println(Int.toString(2 + 3 * 4 - 1));\n"
        "    Io.println(Bool.toString(1 < 2 && 2 <= 2 && 3 > 2 && 3 >= 3));\n"
        "    Io.println(Bool.toString(1 == 2 || 1 != 2));\n"
        "    Io.println(Bool.toString(\"a\" < \"b\"));\n"
        "    Io.println(Int.toString(List.size(1 :: [2] <> [3])))\n"
        "}\n"),
    ?assertEqual(<<"-2\n-1\n13\ntrue\ntrue\ntrue\n3\n">>, Output).

%% report §3.1, §5.1, §9.6, Appendix E.9: Float arithmetic, negation, and
%% ordering; the Float functions of E.9
float_operators_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    Io.println(Float.toString(1.5 + 2.25 * 2.0 - 1.0 / 4.0));\n"
        "    Io.println(Float.toString(-(1.0e-9)));\n"
        "    Io.println(Bool.toString(1.5 < 2.0 && 2.0 <= 2.0 && 3.5 > 2.0 && 3.0 >= 3.0));\n"
        "    Io.println(Int.toString(Float.round(2.5) + Float.round(3.5) + Float.floor(-0.5)"
        " + Float.ceil(0.5)));\n"
        "    Io.println(Float.toString(Int.toFloat(3)))\n"
        "}\n"),
    ?assertEqual(<<"5.75\n-1.0e-9\ntrue\n6\n3.0\n">>, Output).

%% report §3.1, §7.4: a Float result outside the finite range faults with
%% its own cause, distinct from the Int zero divisor
float_fault_test() ->
    Zero = "fn zero() : Float = Int.toFloat(List.size([]))\n",
    {Result1, _} = ern_program:run(Zero ++ "export fn main() : Unit = "
                                   "Io.println(Float.toString(1.0 / zero()))\n"),
    ?assertMatch({fault, <<"float arithmetic error">>, _}, Result1),
    {Result2, _} = ern_program:run(Zero ++ "export fn main() : Unit = "
                                   "Io.println(Float.toString((zero() + 1.0e308) * 10.0))\n"),
    ?assertMatch({fault, <<"float arithmetic error">>, _}, Result2),
    {Result3, _} = ern_program:run(Zero ++ "export fn main() : Unit = "
                                   "Io.println(Float.toString(zero() / zero()))\n"),
    ?assertMatch({fault, <<"float arithmetic error">>, _}, Result3),
    %% an Int zero divisor inside a Float operand keeps its own cause
    {Result4, _} = ern_program:run("fn n() : Int = List.size([])\n"
                                   "export fn main() : Unit = "
                                   "Io.println(Float.toString(Int.toFloat(1 / n()) + 1.0))\n"),
    ?assertMatch({fault, <<"division by zero">>, _}, Result4),
    %% an addition in a function value faults the same way
    {Result5, _} = ern_program:run(
        "export fn main() : Unit = "
        "Io.println(Float.toString(List.foldLeft([1.0e308, 1.0e308], 0.0,"
        " fn(sum, x) = sum + x)))\n"),
    ?assertMatch({fault, <<"float arithmetic error">>, _}, Result5).

%% report §3.1, §7.3, §7.4: a Float operation is the host's own, and the
%% runtime reads its fault from the host's stack: the cause, and the trace
%% naming the operation's line, the line its expression begins on (§11.5).
%% Where the host's compiler does not know the operands are floats, its
%% operation's frame stands first, holding them; where it knows, it
%% computes in its float registers and raises in the program's own frame,
%% as in a chain of three operations on three lines whose middle one
%% faults. An Int zero divisor keeps its own cause, the host's `div` first.
%% A regression test, written after the code (the log's *The Float
%% chain*): each operation was a `try` of its own; it holds the host's
%% compiler as OTP 29 has it, and a change of what that compiler knows of
%% the operands changes the first frame
float_chain_fault_test() ->
    Big = "fn big() : Float = Float.max(1.0e300, 0.0)\n",
    {{fault, <<"float arithmetic error">>, Product}, _} =
        ern_program:run(Big ++ "export fn main() : Unit =\n"
                               "    Io.println(Float.toString(big() * big()))\n"),
    ?assertEqual([<<"erlang:'*'/2">>, <<"M.main:3">>], frames(Product)),
    {{fault, <<"float arithmetic error">>, Chain}, _} =
        ern_program:run(Big ++ "fn chain(x : Float, y : Float) : Float = {\n"
                               "    let sum = x + y;\n"
                               "    let product = sum * x;\n"
                               "    product - y\n"
                               "}\n"
                               "export fn main() : Unit =\n"
                               "    Io.println(Float.toString(chain(big(), 1.0)))\n"),
    ?assertEqual([<<"M.chain:4">>, <<"M.main:8">>], frames(Chain)),
    {{fault, <<"float arithmetic error">>, Undefined}, _} =
        ern_program:run("export fn main() : Unit =\n"
                        "    Io.println(Float.toString(0.0 / 0.0))\n"),
    ?assertEqual([<<"M.main:2">>], frames(Undefined)),
    {{fault, <<"division by zero">>, Division}, _} =
        ern_program:run("fn zero() : Int = List.size([])\n"
                        "export fn main() : Unit =\n"
                        "    Io.println(Int.toString(1 / zero()))\n"),
    ?assertEqual([<<"erlang:'div'/2">>, <<"M.main:3">>], frames(Division)).

%% report §3.1, §7.4, §11.1: a chain of Float operations is written as the
%% host's own, with no `try`, a product and a quotient adding 0.0 so that
%% neither is a negative zero, as `--emit-erl` writes it. A regression test,
%% written after the code (the log's *The Float chain*): each operation was
%% a `try` of its own, its operands bound first
float_chain_emitted_test() ->
    {ok, Typed, _, Env} =
        ern_typecheck:check_string(['M'], "export fn f(a : Float, b : Float, c : Float) : Float =\n"
                                          "    a * b + b * c - c / a\n"),
    Emitted = emitted(['M'], Typed, Env),
    ?assertMatch({_, _}, binary:match(Emitted, <<"'$1'(A_1, B_2, C_3) ->\n"
                                                 "    A_1 * B_2 + 0.0 + (B_2 * C_3 + 0.0) -"
                                                 " (C_3 / A_1 + 0.0).\n">>)),
    ?assertEqual(nomatch, binary:match(Emitted, <<"try">>)).

%% report §3.1, §7.3, §7.4, §6.9, Appendix E.24: the float fault the
%% runtime reads is the same wherever the process is: a restarting run's,
%% reported as it restarts and at its last fault with the operation's
%% line, a run `Test.faults` judges, and the program's function foreign
%% code calls, which the foreign function passes on as itself (§12.3). A
%% regression test, written after the code (the log's *The Float chain*)
float_fault_everywhere_test() ->
    Self = self(),
    Faults = fun({'FaultReport', _, Site, Cause, Restarted, Trace, _, _, _, _}, _) ->
                     Self ! {fault, Site, Cause, Restarted, Trace}
             end,
    Big = "fn big() : Float = Float.max(1.0e300, 0.0)\n",
    {Restarting, Output} =
        ern_program:run(['M'], "type Msg = Ended(Down)\n" ++ Big ++
                               "export fn main() : Unit receiving Msg = {\n"
                               "    let limit = RestartLimit(restarts = 1, within = 60000);\n"
                               "    let _ = spawnMonitored(restarting(limit, fn() =\n"
                               "        Io.println(Float.toString(big() * big()))), Ended);\n"
                               "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
                               "}\n",
                        #{faults => Faults}),
    ?assertEqual({ok, <<"Fault(\"float arithmetic error\")\n">>}, {Restarting, Output}),
    Reported = [receive {fault, Site, Cause, Restarted, Trace} -> {Site, Cause, Restarted, Trace}
                after 0 -> none
                end || _ <- [first, last]],
    Trace = <<"erlang:'*'/2\nM.main:6\n">>,
    ?assertEqual([{<<"M.main:5">>, <<"float arithmetic error">>, true, Trace},
                  {<<"M.main:5">>, <<"float arithmetic error">>, false, Trace}], Reported),
    {ok, Judged} =
        ern_program:run(Big ++ "fn zero() : Int = List.size([])\n"
                               "export fn main() : Unit = {\n"
                               "    Io.println(Io.show(Test.faults(fn() = big() * big(),"
                               " \"float arithmetic error\")));\n"
                               "    Io.println(Io.show(Test.faults(fn() = 1 / zero(),"
                               " \"float arithmetic error\")))\n"
                               "}\n"),
    ?assertEqual(<<"Test.Passed\nTest.Failed(\"expected the fault float arithmetic error, got"
                   " the fault division by zero\")\n">>, Judged),
    {{fault, <<"float arithmetic error">>, Called}, Printed} =
        ern_program:run(
            "foreign fn each(f : (a) -> Unit receiving m, xs : List(a)) : Unit receiving m ="
            " \"lists:foreach/2\"\n"
            "export fn main() : Unit =\n"
            "    each(fn(x : Float) = Io.println(Float.toString(x * x)),\n"
            "        [2.0, 1.0e300])\n"),
    ?assertEqual(<<"4.0\n">>, Printed),
    ?assertMatch([<<"erlang:'*'/2">>, <<"M.main:3">> | _], frames(Called)).

%% report §3.1: there is no negative zero; an operation, a negation, a
%% float segment, parsed text, and a foreign value give 0.0. A sum or a
%% difference is not normalized, and gives 0.0 all the same
no_negative_zero_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn parse(s : String) : Float = \"erlang:binary_to_float/1\"\n"
        "fn tiny() : Float = 1.0e-300\n"
        "export fn main() : Unit = {\n"
        "    let z = 0.0;\n"
        "    let _ = Io.debug(#(z * -1.0, -z, z / -2.0, -tiny() * tiny()));\n"
        "    let _ = Io.debug(#(-5.0 + 5.0, 5.0 - 5.0, -z - z, -1.0e-200 * 1.0e-200));\n"
        "    let _ = Io.debug(z * -1.0 == 0.0);\n"
        "    let _ = Io.debug(Map.size(Map.fromList([#(z, 1), #(-z, 2)])));\n"
        "    let b = <<128, 0, 0, 0, 0, 0, 0, 0>>;\n"
        "    let _ = match b { <<x:size(64)-float>> -> Io.debug(x) | _ -> 1.0 };\n"
        "    let _ = match b { <<0.0:size(64)-float>> -> Io.debug(\"zero\") | _ -> \"other\" };\n"
        "    let _ = Io.debug(String.toFloat(\"-0.0\"));\n"
        "    let _ = Io.debug(parse(\"-0.0\"));\n"
        "    let _ = match b { <<x:size(64)-float>> when x == 0.0 -> Io.debug(\"guard\")"
        " | _ -> \"no\" };\n"
        "    let _ = match b { <<x:size(64)-float>> -> { fn g() : Float = x; Io.debug(g()) }"
        " | _ -> 1.0 };\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(0.0, 0.0, 0.0, 0.0)\n#(0.0, 0.0, 0.0, 0.0)\ntrue\n1\n0.0\n\"zero\"\n"
                   "Some(0.0)\n0.0\n\"guard\"\n0.0\n">>, Output).

%% report §3.1, §8.4: a negative zero inside a value foreign code returns,
%% or inside a message it sends, is 0.0, as a float returned alone is. A
%% regression test, written after the code: the check rebuilt every value
%% whose type holds a float, a negative zero in it or not, which cost more
%% than the host's work it checked; now a float matches only where it is
%% no negative zero, and a value that fails so is made again. It does not
%% show that a value holding none is walked once
foreign_negative_zero_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn decoded(bytes : Bytes) : List(#(String, Float)) =\n"
        "    \"erlang:binary_to_term/1\"\n"
        "foreign fn term(bytes : Bytes) : Foreign.Term = \"erlang:binary_to_term/1\"\n"
        "foreign fn send(to : Address(List(Float)), message : Foreign.Term) : Foreign.Term =\n"
        "    \"erlang:send/2\"\n"
        "export fn main() : Unit receiving List(Float) = {\n"
        "    let pairs = decoded(<<131, 108, 0, 0, 0, 2, 104, 2, 109, 0, 0, 0, 1, 97, 70,"
        " 128, 0, 0, 0, 0, 0, 0, 0, 104, 2, 109, 0, 0, 0, 1, 98, 70, 63, 248, 0, 0, 0, 0, 0,"
        " 0, 106>>);\n"
        "    let _ = Io.debug(pairs == [#(\"a\", 0.0), #(\"b\", 1.5)]);\n"
        "    let _ = send(self(), term(<<131, 108, 0, 0, 0, 2, 70, 128, 0, 0, 0, 0, 0, 0, 0, 70,"
        " 63, 248, 0, 0, 0, 0, 0, 0, 106>>));\n"
        "    receive {\n"
        "        floats -> { let _ = Io.debug(floats == [0.0, 1.5]); Unit }\n"
        "    }\n"
        "}\n"),
    %% `==` is exact, and tells the host's two zeros apart, where `Io.debug`
    %% writes both 0.0
    ?assertEqual(<<"true\ntrue\n">>, Output).

%% report §5.1: a callee is evaluated before its arguments; in `x |> e`,
%% x is evaluated before e, a callee a call computes among it
evaluation_order_test() ->
    {ok, Output} = ern_program:run(
        "fn show(s : String, n : Int) : Int = { Io.println(s); n }\n"
        "fn f(a : Int) : ((Int, Int) -> Int) = {\n"
        "    Io.println(\"f(a)\");\n"
        "    fn(x, y) = x + y + a\n"
        "}\n"
        "fn g(a : Int) : ((Int) -> Int) = { Io.println(\"g(1)\"); fn(x) = x + a }\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(show(\"x\", 1) |> f(show(\"a\", 2))(show(\"b\", 3))));\n"
        "    Io.println(Int.toString(g(1)(show(\"h()\", 4))))\n"
        "}\n"),
    ?assertEqual(<<"x\na\nf(a)\nb\n6\ng(1)\nh()\n5\n">>, Output).

%% report §5.7, §5.1: a pipe in parentheses is a value the outer pipe
%% applies and does not fill, `x |> (a |> f)` being `f(a)(x)`, with x
%% evaluated first and the inner pipe in its own order; a call whose callee
%% is such a pipe is filled. A regression test, of the fill, which evaluated
%% the inner pipe's left side after its right
pipe_into_pipe_test() ->
    {ok, Output} = ern_program:run(
        "fn show(s : String, n : Int) : Int = { Io.println(s); n }\n"
        "fn f(a : Int) : ((Int) -> Int) = fn(x) = a - x\n"
        "fn g(a : Int) : ((Int, Int) -> Int) = fn(x, c) = a - x - c\n"
        "export fn main() : Unit = {\n"
        "    let applied = show(\"x\", 10) |> (show(\"a\", 3) |> { Io.println(\"f\"); f });\n"
        "    Io.println(Int.toString(applied));\n"
        "    Io.println(Int.toString(10 |> (3 |> g)(5)))\n"
        "}\n"),
    ?assertEqual(<<"x\na\nf\n-7\n-12\n">>, Output).

%% report §4.8: `!` negates a Bool, in an expression and in a guard
not_operator_test() ->
    {ok, Output} = ern_program:run(
        "fn small(n : Int) : String = match n { m when !(m > 5) -> \"small\" | _ -> \"big\" }\n"
        "export fn main() : Unit = {\n"
        "    let _ = Io.debug(!true);\n"
        "    let _ = Io.debug(List.filter([1, 2, 3, 4], fn(n) = !(n % 2 == 1)));\n"
        "    let _ = Io.debug(small(3));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"false\n[2, 4]\n\"small\"\n">>, Output).

%% report §4.8, §3.10, §5.1: a user type's operator is its member, its
%% ordering goes through its compare, and prefix - through its negate
user_operators_test() ->
    Vec = "export type Vec = Vec(Int)\n"
          "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec(a + b)\n"
          "export fn Vec.*(Vec(a), Vec(b)) : Float = Int.toFloat(a * b)\n"
          "export fn Vec.compare(Vec(a), Vec(b)) : Ordering = compare(b, a)\n"
          "export fn Vec.negate(Vec(a)) : Vec = Vec(-a)\n"
          "fn show(Vec(n)) : String = Int.toString(n)\n",
    {ok, Output} = ern_program:run(Vec ++
        "export fn main() : Unit = {\n"
        "    let a = Vec(1);\n"
        "    let b = Vec(2);\n"
        "    Io.println(show(-(a + b)));\n"
        "    Io.println(Float.toString((a * b) + 0.5));\n"
        "    Io.println(Bool.toString(a < b));\n"
        "    Io.println(Bool.toString(a >= b && b <= a && a > b))\n"
        "}\n"),
    ?assertEqual(<<"-3\n2.5\nfalse\ntrue\n">>, Output).

%% report §8.5: a top-level let evaluated through an operator's member
%% comes after the lets that member reads
let_order_through_operator_test() ->
    {ok, Output} = ern_program:run(
        "export type Vec = Vec(Int)\n"
        "let sum = Vec(1) + Vec(2)\n"
        "export fn Vec.+(Vec(a), Vec(b)) : Vec = Vec((a + b) * scale)\n"
        "let scale = 10\n"
        "fn show(Vec(n)) : String = Int.toString(n)\n"
        "export fn main() : Unit = Io.println(show(sum))\n"),
    ?assertEqual(<<"30\n">>, Output).

%% report §8.5, §4.9, §5.6, §3.5: a top-level let comes after the lets a
%% member reads that a requirement supplies in its initializer, at a call,
%% in a fill, and through a derived compare. A regression test: only an
%% operator's member was counted, and `sorted` read `scale` before it had a
%% value
let_order_through_supplied_member_test() ->
    {ok, Output} = ern_program:run(
        "type T = T(Int)\n"
        "type P = P(t : T) derives compare\n"
        "type Ops(a) = Ops(fromList : (List(a)) -> OrderedSet.Set(a))\n"
        "let sorted = OrderedSet.toList(OrderedSet.fromList([T(2), T(1)]))\n"
        "let filled = {\n"
        "    let ops : Ops(T) = Ops(..OrderedSet);\n"
        "    OrderedSet.toList(ops.fromList([T(4), T(3)]))\n"
        "}\n"
        "let derived = OrderedSet.toList(OrderedSet.fromList([P(t = T(6)), P(t = T(5))]))\n"
        "fn T.compare(T(a) : T, T(b) : T) : Ordering = compare(a * scale, b * scale)\n"
        "let scale = 1\n"
        "export fn main() : Unit =\n"
        "    Io.println(Io.show(#(sorted, filled, derived)))\n"),
    ?assertEqual(<<"#([M.T(1), M.T(2)], [M.T(3), M.T(4)], [M.P(t = M.T(5)), M.P(t = M.T(6))])\n">>,
                 Output).

%% report §8.5: a top-level let is evaluated after the lets it depends
%% on, and otherwise in the order the module declares it. A regression
%% test: the order of independent lets was the digraph's, which moved with
%% unrelated changes, and `:reload` kept an unpredictable set of values
let_order_declared_test() ->
    {ok, Output} = ern_program:run(
        "let a = { Io.println(\"a\"); 1 }\n"
        "let c = { Io.println(\"c\"); b + 1 }\n"
        "let b = { Io.println(\"b\"); 2 }\n"
        "let d = { Io.println(\"d\"); 4 }\n"
        "export fn main() : Unit = Io.println(Int.toString(a + c + d))\n"),
    ?assertEqual(<<"a\nb\nc\nd\n8\n">>, Output).

%% report §4.7, §8.4, §12.2: a foreign fn calls its implementation with the
%% arguments as the ABI maps them, and a foreign type's values pass through
%% unchecked
foreign_fn_test() ->
    {ok, Output} = ern_program:run(
        "foreign type Table\n"
        "foreign fn size(s : String) : Int = \"erlang:byte_size/1\"\n"
        "foreign fn atom(s : String) : Foreign.Term = \"erlang:binary_to_atom/1\"\n"
        "foreign fn newTable(n : Foreign.Term, o : List(Foreign.Term)) : Table =\n"
        "    \"ets:new/2\"\n"
        "foreign fn insert(t : Table, row : #(Int, String)) : Bool = \"ets:insert/2\"\n"
        "foreign fn lookup(t : Table, k : Int) : List(#(Int, String)) = \"ets:lookup/2\"\n"
        "foreign fn each(f : (Int) -> Unit receiving m, xs : List(Int)) : Foreign.Term receiving m"
        " = \"lists:foreach/2\"\n"
        "export fn main() : Unit = {\n"
        "    let t = newTable(atom(\"t\"), [atom(\"set\")]);\n"
        "    let _ = insert(t, #(1, \"one\"));\n"
        "    match lookup(t, 1) { [#(_, v)] -> Io.println(v) | _ -> Io.println(\"none\") };\n"
        "    Io.println(Int.toString(size(\"abc\")));\n"
        "    let _ = each(fn(n : Int) = Io.println(Int.toString(n)), [1, 2]);\n"
        "    let f = size;\n"
        "    Io.println(Int.toString(List.foldLeft(List.map([\"a\", \"bb\"], f), 0,"
        " fn(sum, n) = sum + n)))\n"
        "}\n"),
    ?assertEqual(<<"one\n3\n1\n2\n3\n">>, Output).

%% report §4.7, §8.4: a foreign return whose type holds the same user type
%% twice, side by side, is checked; each is described in full
foreign_sibling_types_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn pair(xs : List(Optional(Int))) : #(Optional(Int), Optional(Int))"
        " = \"erlang:list_to_tuple/1\"\n"
        "export fn main() : Unit = {\n"
        "    let _ = Io.debug(pair([Some(1), None]));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(Some(1), None)\n">>, Output).

%% report §4.7, §12.3, §8.4: a return of another shape faults on first
%% observation, naming the declared type; a nested breach is found; an
%% exception is a fault naming the implementation; an Ernest fault raised
%% inside foreign code passes through as itself
foreign_faults_test() ->
    Main = "export fn main() : Unit = ",
    {Result1, _} = ern_program:run("foreign fn bad() : Int = \"erlang:node/0\"\n"
                                   ++ Main ++ "Io.println(Int.toString(bad()))\n"),
    ?assertEqual(return_cause("erlang:node/0", "Int", ["is ", atom_to_list(node())]),
                 cause_of(Result1)),
    {Result2, _} = ern_program:run(
        "foreign fn pair() : #(Int, String) = \"ern_emitter_tests:pair/0\"\n"
        ++ Main ++ "{ let #(_, s) = pair(); Io.println(s) }\n"),
    ?assertEqual(return_cause("ern_emitter_tests:pair/0", "#(Int, String)", "field 2, is 2"),
                 cause_of(Result2)),
    {Result3, _} = ern_program:run(
        "foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
        ++ Main ++ "match opt(1) { Some(n) -> Io.println(Int.toString(n))"
        " | None -> Io.println(\"none\") }\n"),
    ?assertEqual(return_cause("ern_emitter_tests:opt/1", "Optional(Int)", "field 1, is <<\"x\">>"),
                 cause_of(Result3)),
    {ok, Output} = ern_program:run(
        "foreign fn opt(k : Int) : Optional(Int) = \"ern_emitter_tests:opt/1\"\n"
        ++ Main ++ "match opt(0) { Some(n) -> Io.println(Int.toString(n))"
        " | None -> Io.println(\"none\") }\n"),
    ?assertEqual(<<"3\n">>, Output),
    {Result4, _} = ern_program:run("foreign fn boom(x : Int) : Int = \"erlang:error/1\"\n"
                                   ++ Main ++ "Io.println(Int.toString(boom(7)))\n"),
    %% report §11.2: the raise carries the host's stack beside its cause
    ?assertMatch({fault, <<"foreign function erlang:error/1 raised error:7">>, <<_/binary>>},
                 Result4),
    {Result5, _} = ern_program:run(
        "foreign fn each(f : (Int) -> Unit receiving m, xs : List(Int)) : Unit"
        " receiving m"
        " = \"lists:foreach/2\"\n"
        ++ Main ++ "each(fn(n : Int) = fault(\"later\"), [1])\n"),
    ?assertMatch({fault, <<"later">>, _}, Result5).

%% report §12.3: a return's cause names the first part of the return that
%% fails and the host's term there, a list's element and a tuple's field
%% by their places, a map's key or the value of one, a set's member, and
%% the return itself where it fails whole; the term on one line as the host
%% writes it with a `chars_limit` of 80, which ends what it cuts with `...`
foreign_return_part_test() ->
    Main = "export fn main() : Unit = ",
    Cause = fun(Declaration, Body) ->
                {Result, _} = ern_program:run(Declaration ++ Main ++ Body ++ "\n"),
                cause_of(Result)
            end,
    ?assertEqual(return_cause("lists:reverse/1", "List(#(Int, String))",
                              "element 3, field 2, is three"),
                 Cause("foreign fn rows(items : List(Foreign.Term)) : List(#(Int, String)) ="
                       " \"lists:reverse/1\"\n",
                       "Io.println(Int.toString(List.size(rows([Foreign.term(#(3,"
                       " Foreign.atom(\"three\"))), Foreign.term(#(2, \"two\")),"
                       " Foreign.term(#(1, \"one\"))]))))")),
    Keyed = "foreign fn keyed(pairs : List(Foreign.Term)) : Map(Int, String) ="
            " \"maps:from_list/1\"\n",
    ?assertEqual(return_cause("maps:from_list/1", "Map(Int, String)", "the value of key 2, is 3"),
                 Cause(Keyed, "Io.println(Int.toString(Map.size(keyed([Foreign.term(#(1, \"a\")),"
                       " Foreign.term(#(2, 3))]))))")),
    ?assertEqual(return_cause("maps:from_list/1", "Map(Int, String)", "a key, is a"),
                 Cause(Keyed, "Io.println(Int.toString(Map.size(keyed([Foreign.term(#("
                       "Foreign.atom(\"a\"), \"a\"))]))))")),
    ?assertEqual(return_cause("sets:from_list/1", "Set(Int)", "a member, is x"),
                 Cause("foreign fn members(items : List(Foreign.Term)) : Set(Int) ="
                       " \"sets:from_list/1\"\n",
                       "Io.println(Int.toString(Set.size(members([Foreign.term(1),"
                       " Foreign.atom(\"x\")]))))")),
    ?assertEqual(return_cause("lists:seq/2", "Int",
                              "is [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,"
                              "25,26,27,28|...]"),
                 Cause("foreign fn seq(from : Int, to : Int) : Int = \"lists:seq/2\"\n",
                       "Io.println(Int.toString(seq(1, 200)))")).

%% report §12.3, §8.4: a call of a foreign function whose module the host
%% lacks faults naming the module, and one the module does not export
%% naming the function, each with a raise's trace, the implementation's
%% frame first; an undef met deeper, in what the foreign function called,
%% stays a raise. Report §11.2: a term of the host's in a cause stands on
%% one line, however long
foreign_lacked_test() ->
    Main = "export fn main() : Unit = ",
    {Lacked, _} = ern_program:run("foreign fn seven() : Int = \"tpkhelp:seven/0\"\n"
                                  ++ Main ++ "Io.println(Int.toString(seven()))\n"),
    ?assertMatch({fault, <<"foreign function tpkhelp:seven/0: no module tpkhelp on the load path">>,
                  <<"tpkhelp:seven/0\n", _/binary>>},
                 Lacked),
    {Unexported, _} = ern_program:run("foreign fn none(xs : List(Int)) : Int = \"lists:nosuch/1\"\n"
                                      ++ Main ++ "Io.println(Int.toString(none([1])))\n"),
    ?assertMatch({fault, <<"foreign function lists:nosuch/1: lists exports no nosuch/1">>,
                  <<"lists:nosuch/1\n", _/binary>>},
                 Unexported),
    {Deeper, _} = ern_program:run(
        "foreign fn applied(m : Foreign.Term, f : Foreign.Term, xs : List(Int)) : Int"
        " = \"erlang:apply/3\"\n"
        ++ Main ++ "Io.println(Int.toString(applied(Foreign.atom(\"tpkhelp\"),"
        " Foreign.atom(\"seven\"), [])))\n"),
    ?assertMatch({fault, <<"foreign function erlang:apply/3 raised error:undef">>,
                  <<"tpkhelp:seven/0\n", _/binary>>},
                 Deeper),
    {Long, _} = ern_program:run(
        "foreign fn boom(term : Foreign.Term) : Int = \"erlang:error/1\"\n"
        ++ Main ++ "Io.println(Int.toString(boom(Foreign.term(#(List.range(1, 40),"
        " \"a string here\", \"another string there\")))))\n"),
    ?assertEqual(<<"foreign function erlang:error/1 raised error:{[1,2,3,4,5,6,7,8,9,10,11,12,13,"
                   "14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,"
                   "40],<<\"a string here\">>,<<\"another string there\">>}">>,
                 cause_of(Long)).

%% Appendix E.21, report §12.3: what the host says of a raise stands after
%% the frame on its trace's first line and in no cause: each argument it
%% describes in their order, the frame's own, which is the function that
%% raised and not always the one the cause names; a raise the host says
%% nothing of has its frame alone
host_description_test() ->
    Main = "export fn main() : Unit = ",
    {Parsed, _} = ern_program:run("foreign fn parsed(text : String) : Int"
                                  " = \"erlang:binary_to_integer/1\"\n"
                                  ++ Main ++ "Io.println(Int.toString(parsed(\"x\")))\n"),
    ?assertMatch({fault, <<"foreign function erlang:binary_to_integer/1 raised error:badarg">>,
                  <<"erlang:binary_to_integer/1, argument 1: not a textual representation of"
                    " an integer\n", _/binary>>},
                 Parsed),
    {Deeper, _} = ern_program:run("foreign fn stamped(time : Foreign.Term) : String"
                                  " = \"calendar:system_time_to_rfc3339/1\"\n"
                                  ++ Main ++ "Io.println(stamped(Foreign.term(\"x\")))\n"),
    ?assertMatch({fault, <<"foreign function calendar:system_time_to_rfc3339/1 raised"
                           " error:badarg">>,
                  <<"erlang:convert_time_unit/3, argument 1: ", _/binary>>},
                 Deeper),
    {Both, _} = ern_program:run("foreign fn written(n : Foreign.Term, base : Int) : String"
                                " = \"erlang:integer_to_binary/2\"\n"
                                ++ Main ++ "Io.println(written(Foreign.atom(\"a\"), 99))\n"),
    {fault, _, BothTrace} = Both,
    [BothFirst | _] = binary:split(BothTrace, <<"\n">>),
    ?assertMatch({match, _}, re:run(BothFirst, <<"^erlang:integer_to_binary/2, argument 1: .*,"
                                                 " argument 2: ">>)),
    {Unsaid, _} = ern_program:run("foreign fn nth(n : Int, xs : List(Int)) : Int"
                                  " = \"lists:nth/2\"\n"
                                  ++ Main ++ "Io.println(Int.toString(nth(5, [1])))\n"),
    ?assertMatch({fault, _, <<"lists:nth_1/2:", _/binary>>}, Unsaid),
    {fault, _, UnsaidTrace} = Unsaid,
    [UnsaidFirst | _] = binary:split(UnsaidTrace, <<"\n">>),
    ?assertEqual(nomatch, re:run(UnsaidFirst, <<", ">>)).

%% report §6.5, §8.4: an address `adapted` made, given to foreign code and given
%% back, is the address that went out, its function kept. A regression
%% test: the program got the process behind it, and a message sent to it
%% arrived without the function applied, not of the mailbox type
adapted_address_round_trip_test() ->
    {ok, Output} = ern_program:run("type Msg = Wrapped(Int)\n"
                                   "foreign fn first(xs : List(Address(Int))) : Address(Int) ="
                                   " \"erlang:hd/1\"\n"
                                   "export fn main() : Unit receiving Msg = {\n"
                                   "    let back = first([adapted(self(), Wrapped)]);\n"
                                   "    send(back, 7);\n"
                                   "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                                   "}\n"),
    ?assertEqual(<<"7\n">>, Output).

%% report §12.3, §8.4: a fault of the program's own function where foreign
%% code calls it passes through as the fault it would be anywhere, with no
%% foreign function named. A regression test: it took the foreign
%% function's cause, `foreign function lists:foreach/2 raised
%% error:badarith`
callback_fault_passes_through_test() ->
    {Result, Output} = ern_program:run(
        "foreign fn each(f : (a) -> Unit receiving m, xs : List(a)) : Unit"
        " receiving m ="
        " \"lists:foreach/2\"\n"
        "export fn main() : Unit =\n"
        "    each(fn(n : Int) = Io.println(Int.toString(10 /"
        " n)),"
        " [2, 0])\n"),
    ?assertMatch({{fault, <<"division by zero">>, _}, <<"5\n">>}, {Result, Output}).

%% report §6.9, §12.3: a restart asked for while foreign code calls the
%% program's function is a restart, the cause of the new start `Asked`. A
%% regression test: it was a fault of the foreign function, and the process
%% restarted after a fault. The restart is taken at the callback's wait at
%% once; the wait's time only bounds a failure to take it
callback_restart_passes_through_test() ->
    {ok, Output} = ern_program:run(
        "type Start = First | Asked | AfterFault\n"
        "foreign fn startCause() : Start = \"ern_rt:start_cause/0\"\n"
        "foreign fn askRestart(child : Process) : Bool = \"ern_rt:ask_restart/1\"\n"
        "foreign fn each(f : (a) -> Unit receiving m, xs : List(a)) : Unit receiving m ="
        " \"lists:foreach/2\"\n"
        "export fn main() : Unit receiving String = {\n"
        "    let me = self();\n"
        "    let body = fn() = {\n"
        "        let cause = startCause();\n"
        "        send(me, Io.show(cause));\n"
        "        match cause {\n"
        "            First -> each(fn(_ : Int) = {\n"
        "                let _ = askRestart(Process.fromAddress(self()));\n"
        "                Clock.sleep(5000)\n"
        "            }, [1])\n"
        "          | _ -> Unit\n"
        "        }\n"
        "    };\n"
        "    let _ = spawn(restarting(Unlimited, body));\n"
        "    receive { s -> Io.println(s) };\n"
        "    receive { s -> Io.println(s) }\n"
        "}\n"),
    ?assertEqual(<<"M.First\nM.Asked\n">>, Output).

%% report §3.1, §5.10: there is no negative zero, so the pattern `-0.0`
%% matches the zero, however it was made. A regression test: the pattern
%% was the host's negative zero, which no value matched
negative_zero_pattern_test() ->
    {ok, Output} = ern_program:run("fn kind(x : Float) : String = match x {\n"
                                   "    -0.0 -> \"zero\"\n"
                                   "  | _ -> \"other\"\n"
                                   "}\n"
                                   "export fn main() : Unit = {\n"
                                   "    Io.println(kind(0.0));\n"
                                   "    Io.println(kind(-0.0));\n"
                                   "    Io.println(kind(0.0 * -1.0))\n"
                                   "}\n"),
    ?assertEqual(<<"zero\nzero\nzero\n">>, Output).

%% report §8.4: a type variable a parameter names may stand in the result
%% more than once. A regression test: only its first place was taken as
%% named, the second was checked as matching no value, and every return
%% faulted
foreign_result_names_a_variable_twice_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn pair(n : Int, x : a) : #(a, a) = \"erlang:make_tuple/2\"\n"
        "export fn main() : Unit = {\n"
        "    let _ = Io.debug(pair(2, \"x\"));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(\"x\", \"x\")\n">>, Output).

%% report §3.8, §3.10: two `Foreign` values are equal where foreign code
%% made them as the same term, the runtime's exact equality. A regression
%% test: before the rule, the checker refused it
foreign_exact_equality_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    Io.println(Io.show(Foreign.term(1) == Foreign.term(1)));\n"
        "    Io.println(Io.show(Foreign.term(1) == Foreign.term(1.0)));\n"
        "    Io.println(Io.show([Foreign.term(\"a\")] != [Foreign.term(\"b\")]))\n"
        "}\n"),
    ?assertEqual(<<"true\nfalse\ntrue\n">>, Output).

%% report §12.2, §12.3, §8.4: a List is a proper list, so an improper one a foreign
%% function returns faults naming the declared type, whether its elements
%% are checked or a parameter's type variable names them, that variable
%% printed with its restriction (§4.7, §11.5). A regression test:
%% the check raised function_clause instead. It does not cover what a check
%% costs, which make bench shows.
foreign_improper_list_test() ->
    Main = "export fn main() : Unit = ",
    {Result1, _} = ern_program:run("foreign fn improper(x : Int) : List(Int) ="
                                   " \"ern_emitter_tests:improper/1\"\n"
                                   ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual(return_cause("ern_emitter_tests:improper/1", "List(Int)", "is [1|1]"),
                 cause_of(Result1)),
    {Result2, _} = ern_program:run(
        "foreign fn improper(x : a) : List(a) = \"ern_emitter_tests:improper/1\"\n"
        ++ Main ++ "Io.println(Int.toString(List.size(improper(1))))\n"),
    ?assertEqual(return_cause("ern_emitter_tests:improper/1", "List(a)", "is [1|1]"),
                 cause_of(Result2)).

%% report §12.3: a function value foreign code returns is checked when it is
%% called, its result against its declared result type, in the caller, and
%% one that keeps to it runs. A regression test: such a function's result
%% was never checked, so an ill-typed one reached Ernest code unchecked.
foreign_function_value_test() ->
    Source = "foreign fn funs() : List((Int) -> Int) = \"ern_emitter_tests:funs/0\"\n"
             "export fn main() : Unit = match funs() {\n"
             "    [good, bad] -> {\n"
             "        Io.println(Int.toString(good(1)));\n"
             "        Io.println(Int.toString(bad(1)))\n"
             "    }\n"
             "  | _ -> Unit\n"
             "}\n",
    {{fault, Cause, _}, Output} = ern_program:run(Source),
    ?assertEqual(<<"2\n">>, Output),
    %% the bad function is a fun of funs/0, which the host names by its
    %% compiler's count of the module's funs, written in the host's quoted
    %% form
    ?assertMatch({match, _}, re:run(Cause, "^the return of foreign function"
                                           " ern_emitter_tests:'-funs/0-fun-[0-9]+-'/1"
                                           " does not match Int: is not_an_int$")).

%% report §12.3: a function value foreign code gives inside a value of a type
%% whose recursion passes through another type, `B` inside `A`, has its
%% result checked against its result type at each call: a result of that
%% type is taken, and one of no type faults. Written before its code, and
%% red there: a result of the type faulted with the host's
%% `error:{badkey,1}`, the check reading `A` unbound
foreign_function_value_through_another_type_test() ->
    Types = "type A = A1(B) | ANone\n"
            "type B = B1(A) | BF(() -> B)\n",
    ?assertEqual({ok, <<"M.B1(M.ANone)\n">>}, ern_program:run(
        Types ++
        "foreign fn first(values : List(A)) : A = \"erlang:hd/1\"\n"
        "export fn main() : Unit =\n"
        "    match first([A1(BF(fn() = B1(ANone)))]) {\n"
        "        A1(BF(f)) -> Io.println(Io.show(f()))\n"
        "      | _ -> Unit\n"
        "    }\n")),
    {Bad, _} = ern_program:run(
        Types ++
        "foreign fn made(module : Foreign.Term, function : Foreign.Term, arity : Int)\n"
        "    : Foreign.Term = \"erlang:make_fun/3\"\n"
        "foreign fn tuple(parts : List(Foreign.Term)) : Foreign.Term =\n"
        "    \"erlang:list_to_tuple/1\"\n"
        "foreign fn outer(parts : List(Foreign.Term)) : A = \"erlang:list_to_tuple/1\"\n"
        "export fn main() : Unit = {\n"
        "    let f = made(Foreign.atom(\"erlang\"), Foreign.atom(\"self\"), 0);\n"
        "    match outer([Foreign.atom(\"A1\"), tuple([Foreign.atom(\"BF\"), f])]) {\n"
        "        A1(BF(g)) -> Io.println(Io.show(g()))\n"
        "      | _ -> Unit\n"
        "    }\n"
        "}\n"),
    ?assertMatch(<<"the return of foreign function erlang:self/0 does not match M.B: is <",
                   _/binary>>,
                 cause_of(Bad)).

%% report §12.2, §8.4: a foreign function's return declared `Unit` that is
%% the host's `ok`, as `lists:foreach/2` answers, is `Unit`, the type's one
%% value and no other term. A regression test, written after the code; it
%% does not cover the standard library's foreign functions, which are not
%% checked and answer `Unit` themselves
foreign_ok_is_unit_test() ->
    {ok, Output} = ern_program:run(
        "foreign fn each(f : (Int) -> Unit, list : List(Int)) : Unit = \"lists:foreach/2\"\n"
        "export fn main() : Unit = {\n"
        "    let done = each(fn(n) = Io.println(Int.toString(n)), [1, 2]);\n"
        "    Io.println(Io.show(done));\n"
        "    Io.println(Io.show(done == Unit))\n"
        "}\n"),
    ?assertEqual(<<"1\n2\nUnit\ntrue\n">>, Output).

%% report §12.2, §8.4: a function value foreign code gave, whose result is
%% declared `Unit`, answers the host's `ok` as `Unit` at a call, the type's
%% one value. A regression test, written after the code; it does not cover
%% a function value inside another value foreign code gave, whose wrapper
%% is the same
function_value_ok_is_unit_test() ->
    {ok, Output} =
        ern_program:run(
            "foreign fn made(module : Foreign.Term, function : Foreign.Term, arity : Int)\n"
            "    : ((Int) -> Unit, List(Int)) -> Unit = \"erlang:make_fun/3\"\n"
            "export fn main() : Unit = {\n"
            "    let each = made(Foreign.atom(\"lists\"), Foreign.atom(\"foreach\"), 2);\n"
            "    let done = each(fn(n) = Io.println(Int.toString(n)), [1]);\n"
            "    Io.println(Io.show(done));\n"
            "    Io.println(Io.show(done == Unit))\n"
            "}\n"),
    ?assertEqual(<<"1\nUnit\ntrue\n">>, Output).

%% report §12.2, §8.4: nothing else takes `ok`: a return declared `Unit`
%% that is another atom faults, and so do an `ok` inside a list and inside
%% a tuple a return holds, an `ok` inside a list a function value foreign
%% code gave answers at a call, and an `ok` a foreign function or a
%% function value answers where its result is declared a program's own
%% type named `Unit`, which is not the prelude's, and which the cause names
%% plain, as §11.5 prints it in the module (§12.3). A regression test,
%% written after the code
foreign_ok_elsewhere_faults_test() ->
    Main = "export fn main() : Unit = ",
    {Result1, _} = ern_program:run("foreign fn collect() : Unit = \"erlang:garbage_collect/0\"\n"
                                   ++ Main ++ "collect()\n"),
    ?assertEqual(return_cause("erlang:garbage_collect/0", "Unit", "is true"), cause_of(Result1)),
    {Result2, _} = ern_program:run(
        "foreign fn copies(count : Int, word : Foreign.Term) : List(Unit) ="
        " \"lists:duplicate/2\"\n"
        ++ Main ++ "Io.println(Io.show(copies(1, Foreign.atom(\"ok\"))))\n"),
    ?assertEqual(return_cause("lists:duplicate/2", "List(Unit)", "element 1, is ok"),
                 cause_of(Result2)),
    {Result3, _} = ern_program:run("foreign fn tuple(parts : List(Foreign.Term)) : #(Unit, Int) ="
                                   " \"erlang:list_to_tuple/1\"\n"
                                   ++ Main ++ "Io.println(Io.show(tuple([Foreign.atom(\"ok\"),"
                                   " Foreign.term(1)])))\n"),
    ?assertEqual(return_cause("erlang:list_to_tuple/1", "#(Unit, Int)", "field 1, is ok"),
                 cause_of(Result3)),
    {Result4, _} =
        ern_program:run(
            "foreign fn made(module : Foreign.Term, function : Foreign.Term, arity : Int)\n"
            "    : (Int, Foreign.Term) -> List(Unit) = \"erlang:make_fun/3\"\n"
            ++ Main ++ "{\n"
            "    let copies = made(Foreign.atom(\"lists\"), Foreign.atom(\"duplicate\"), 2);\n"
            "    Io.println(Io.show(copies(1, Foreign.atom(\"ok\"))))\n"
            "}\n"),
    ?assertEqual(return_cause("lists:duplicate/2", "List(Unit)", "element 1, is ok"),
                 cause_of(Result4)),
    Own = "type Unit = Unit\n"
          "foreign fn pause(ms : Int) : Unit = \"timer:sleep/1\"\n"
          "foreign fn made(module : Foreign.Term, function : Foreign.Term, arity : Int)\n"
          "    : (Int) -> Unit = \"erlang:make_fun/3\"\n"
          "export fn main() : Prelude.Unit = ",
    {Result5, _} = ern_program:run(Own ++ "Io.println(Io.show(pause(0)))\n"),
    %% report §12.3: the module's own Unit written whole from the root
    ?assertEqual(return_cause("timer:sleep/1", "M.Unit", "is ok"), cause_of(Result5)),
    {Result6, _} = ern_program:run(Own ++ "Io.println(Io.show(made(Foreign.atom(\"timer\"),"
                                   " Foreign.atom(\"sleep\"), 1)(0)))\n"),
    ?assertEqual(return_cause("timer:sleep/1", "M.Unit", "is ok"), cause_of(Result6)).

%% report §8.4: the proxy in front of an exposed address is one per address
%% and mailbox type, so exposing the same address twice gives the same one
foreign_proxy_is_one_test() ->
    persistent_term:erase({?MODULE, proxy_seen}),
    {ok, Output} = ern_program:run("type Msg = Go(Int)\n"
                                   "foreign fn remember(a : Address(Msg)) : Bool ="
                                   " \"ern_emitter_tests:remember/1\"\n"
                                   "export fn main() : Unit receiving Msg = {\n"
                                   "    let _ = remember(self());\n"
                                   "    let again = remember(self());\n"
                                   "    Io.println(if again then \"same\" else \"another\")\n"
                                   "}\n"),
    ?assertEqual(<<"same\n">>, Output),
    persistent_term:erase({?MODULE, proxy_seen}).

%% report §3.10, §3.8: a foreign type's equality is the host's, of the
%% terms: a reference equals itself and not another, and two values that
%% are the same term are equal. `Foreign` has none, which the checker's
%% tests hold. A regression test, written after the code; it does not
%% cover a foreign value that holds a function
foreign_equality_test() ->
    {ok, Output} = ern_program:run(
        "foreign type Ref\n"
        "foreign fn makeRef() : Ref = \"erlang:make_ref/0\"\n"
        "foreign fn same(x : Int) : Ref = \"erlang:abs/1\"\n"
        "export fn main() : Unit = {\n"
        "    let a = makeRef();\n"
        "    let b = makeRef();\n"
        "    let _ = Io.debug(#(a == a, a == b, same(1) == same(-1), same(1) == same(2)));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(true, false, true, false)\n">>, Output).

%% report §6.3: a receive guard reads a top-level `let`, in a receive with
%% and without an `after`, the value read before the receive waits. A
%% regression test, written with the rule
receive_guard_reads_top_level_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Tick(Int)\n"
        "let limit = 10\n"
        "fn first() : Int receiving Msg = receive { Tick(k) when k > limit -> k }\n"
        "fn timed() : Int receiving Msg =\n"
        "    receive {\n"
        "        Tick(k) when k > limit -> k\n"
        "      | after 1000 -> 0\n"
        "    }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let me = self();\n"
        "    send(me, Tick(3));\n"
        "    send(me, Tick(20));\n"
        "    send(me, Tick(30));\n"
        "    let _ = Io.debug(#(first(), timed()));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"#(20, 30)\n">>, Output).

%% report §6.3, §3.5: a receive guard reads a field of a variable in scope,
%% of a selection of one and of a top-level `let`, in place, in an Erlang
%% guard, a message the guard rejects staying in the mailbox; where the
%% field's place differs between the type's constructors, the guard reads
%% the place from the tag, and a field of a value whose type a later use
%% fixes is read so too. A regression test, written after the code
receive_guard_reads_a_field_test() ->
    Text = "type Msg = Tick(Int) | Stop\n"
           "type Lot = Lot(at : Int)\n"
           "type Shape = Round(name : String, at : Int) | Square(at : Int, name : String)\n"
           "type State = State(at : Int, lot : Lot)\n"
           "let held = Lot(at = 4)\n"
           "fn take(s : State, shape : Shape) : List(Int) receiving Msg = receive {\n"
           "    Tick(k) when k == s.at || k == s.lot.at -> k :: take(s, shape)\n"
           "  | Tick(k) when k == held.at || k == shape.at -> k :: take(s, shape)\n"
           "  | Stop -> []\n"
           "}\n"
           "export fn main() : Unit receiving Msg = {\n"
           "    let me = self();\n"
           "    List.forEach([9, 1, 9, 2, 3, 4, 5, 9], fn(k) = send(me, Tick(k)));\n"
           "    send(me, Stop);\n"
           "    let s = State(at = 1, lot = Lot(at = 2));\n"
           "    let _ = Io.debug(take(s, Square(at = 5, name = \"s\")));\n"
           "    let _ = Io.debug(receive { Tick(k) -> k });\n"
           "    Unit\n"
           "}\n",
    ?assertEqual({ok, <<"[1, 2, 4, 5]\n9\n">>}, ern_program:run(Text)),
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    Guards = [erl_syntax:clause_guard(Clause)
              || Form <- ern_compile:forms(['M'], Typed, Env),
                 Receive <- erl_syntax_lib:fold(fun(Node, Acc) ->
                                                       case erl_syntax:type(Node) of
                                                           receive_expr -> [Node | Acc];
                                                           _ -> Acc
                                                       end
                                                   end, [], Form),
                 Clause <- erl_syntax:receive_expr_clauses(Receive),
                 erl_syntax:clause_guard(Clause) =/= none],
    Read = fun(Guard) ->
               erl_syntax_lib:fold(fun(Node, Acc) ->
                                       case erl_syntax:type(Node) =:= application
                                           andalso erl_syntax_lib:analyze_application(Node) of
                                           {erlang, {Function, _}} -> [Function | Acc];
                                           _ -> Acc
                                       end
                                   end, [], Guard)
           end,
    ?assertEqual([[element, element, element], [element, element, element, map_get]],
                 lists:sort([lists:sort(Read(Guard)) || Guard <- Guards])),
    ?assertEqual({ok, <<"took 1\n">>}, ern_program:run(
        "type Msg = At(at : Int) | Stop\n"
        "type State = State(at : Int)\n"
        "fn loop(s) : Unit receiving Msg = {\n"
        "    receive {\n"
        "        At(at = a) when a == s.at -> Io.println(\"took \" <> Int.toString(a))\n"
        "      | Stop -> Unit\n"
        "    };\n"
        "    let State(at = _) = s;\n"
        "    Unit\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    send(self(), At(at = 2));\n"
        "    send(self(), At(at = 1));\n"
        "    loop(State(at = 1))\n"
        "}\n")).

%% report §5.9, §6.3: a match guard that is §6.3's guard expression, a
%% field read among its operands, is an Erlang guard too, the field's place
%% read from the tag where it differs between the constructors. A
%% regression test, written after the code, with the receive guard's field
match_guard_reads_a_field_test() ->
    Text = "type Shape = Round(name : String, at : Int) | Square(at : Int, name : String)\n"
           "fn near(n : Int, shape : Shape) : String = match n {\n"
           "    k when k == shape.at -> shape.name\n"
           "  | _ -> \"far\"\n"
           "}\n"
           "export fn main() : Unit = {\n"
           "    Io.println(near(1, Round(name = \"round\", at = 1)));\n"
           "    Io.println(near(2, Square(at = 2, name = \"square\")));\n"
           "    Io.println(near(3, Square(at = 2, name = \"square\")))\n"
           "}\n",
    ?assertEqual({ok, <<"round\nsquare\nfar\n">>}, ern_program:run(Text)),
    {ok, Typed, _, Env} = ern_typecheck:check_string(['M'], Text),
    Guarded = [Clause || Form <- ern_compile:forms(['M'], Typed, Env),
                         Clause <- erl_syntax_lib:fold(fun(Node, Acc) ->
                                                               [Node | Acc]
                                                       end, [], Form),
                         erl_syntax:type(Clause) =:= clause,
                         erl_syntax:clause_guard(Clause) =/= none],
    ?assertMatch([_], Guarded).

%% report §8.4, §12.3: an address given to foreign code is a proxy that
%% checks each message on delivery, a bad one faulting the target even
%% when no clause would bind it; a good one arrives, also from inside a
%% list; a reply is checked by the call that observes it
foreign_messages_test() ->
    Junk = "foreign fn junk(a : Address(Msg)) : Unit = \"ern_emitter_tests:junk/1\"\n",
    {Result1, _} = ern_program:run("type Msg = Go(Int)\n" ++ Junk ++
                                   "export fn main() : Unit receiving Msg = {\n"
                                   "    junk(self());\n"
                                   "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                                   "}\n"),
    ?assertMatch({fault, <<"message does not match M.Msg">>, _}, Result1),
    {WithStop, _} = ern_program:run("type Msg = Go(Int) | Stop\n" ++ Junk ++
                                    "export fn main() : Unit receiving Msg = {\n"
                                    "    junk(self());\n"
                                    "    receive { Stop -> Unit }\n"
                                    "}\n"),
    ?assertMatch({fault, <<"message does not match M.Msg">>, _}, WithStop),
    {ok, Output} = ern_program:run("type Msg = Go(Int)\n"
                                   "foreign fn good(a : Address(Msg)) : Unit ="
                                   " \"ern_emitter_tests:good/1\"\n"
                                   "foreign fn tell(targets : List(Address(Msg))) : Unit"
                                   " = \"ern_emitter_tests:tell/1\"\n"
                                   "export fn main() : Unit receiving Msg = {\n"
                                   "    good(self());\n"
                                   "    receive { Go(n) -> Io.println(Int.toString(n)) };\n"
                                   "    tell([self()]);\n"
                                   "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                                   "}\n"),
    ?assertEqual(<<"1\n2\n">>, Output),
    %% report §6.5, §8.4: an adapted address reaches foreign code through
    %% the same proxy, and the wrap is applied on the way back
    {ok, Wrapped} = ern_program:run("type Msg = Wrapped(Int)\n"
                                    "type Inner = Go(Int)\n"
                                    "foreign fn good(a : Address(Inner)) : Unit ="
                                    " \"ern_emitter_tests:good/1\"\n"
                                    "export fn main() : Unit receiving Msg = {\n"
                                    "    good(adapted(self(), fn(Go(n) : Inner) = Wrapped(n)));\n"
                                    "    receive { Wrapped(n) -> Io.println(Int.toString(n)) }\n"
                                    "}\n"),
    ?assertEqual(<<"1\n">>, Wrapped),
    {Result2, _} = ern_program:run(
        "type Ask = Ask(reply : Reply(Int))\n"
        "foreign fn server() : Address(Ask) ="
        " \"ern_emitter_tests:junk_server/0\"\n"
        "export fn main() : Unit = {\n"
        "    let n = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
        "    Io.println(Int.toString(n))\n"
        "}\n"),
    ?assertMatch({fault, <<"reply does not match Int">>, _}, Result2).

%% report §8.4, Appendix E.21: a bad message foreign code sends to a
%% process the runtime started faults it at the wait that reaches it, and
%% the fault's trace is its own stack there, the receive's own line, its
%% clause on the line after. A regression test, written after the code:
%% only a fault laid in the mailbox by hand held the trace
%% (trace_through_a_wait_test/0), and not one the check sends; it does not
%% cover a wait for a call's answer, nor a receiver on another node
bad_message_trace_is_the_receivers_test() ->
    ?assertMatch({{fault, <<"message does not match M.Msg">>, <<"M.main:6\n">>}, _},
                 ern_program:run(
                     "type Msg = Go(Int)\n"
                     "foreign fn junk(a : Address(Msg)) : Unit = \"ern_emitter_tests:junk/1\"\n"
                     "export fn main() : Unit receiving Msg = {\n"
                     "    junk(self());\n"
                     "\n"
                     "    receive {\n"
                     "        Go(n) -> Io.println(Int.toString(n))\n"
                     "    };\n"
                     "    Unit\n"
                     "}\n")).

%% report §8.4: a function that stands inside a foreign function's argument
%% crosses as one given alone does, each argument foreign code calls it with
%% checked. A regression test: only a parameter that was itself a function
%% was wrapped, and the bad argument faulted inside the function
nested_function_checked_test() ->
    Source = fun(Name) ->
                 "foreign fn call(p : #(Int, (Int) -> Int)) : Int = \"ern_emitter_tests:"
                 ++ Name ++ "/1\"\n"
                 "export fn main() : Unit =\n"
                 "    Io.println(Int.toString(call(#(4, fn(n) = n * 2))))\n"
             end,
    ?assertMatch({fault, <<"an argument of M.main from foreign code does not match Int">>, _},
                 outcome(Source("call_nested_bad"))),
    ?assertEqual({ok, <<"8\n">>}, ern_program:run(Source("call_nested_good"))).

%% report §8.4: an address sent in a message to a foreign address crosses
%% into foreign code, so a bad message foreign code sends it back faults the
%% receiver on delivery, and a good one arrives. A regression test: only a
%% foreign function's arguments crossed, and the bad message was delivered
%% unchecked, its binary bound where an Int was declared
foreign_address_message_test() ->
    Source = fun(Server) ->
                 "type Msg = Go(Int)\n"
                 "type Out = Hello(Address(Msg))\n"
                 "foreign fn start() : Address(Out) = \"ern_emitter_tests:" ++ Server
                 ++ "/0\"\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    send(start(), Hello(self()));\n"
                 "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                 "}\n"
             end,
    ?assertMatch({fault, <<"message does not match M.Msg">>, _}, outcome(Source("hello_junk"))),
    ?assertEqual({ok, <<"1\n">>}, ern_program:run(Source("hello_good"))).

%% report §8.4: foreign code answers a Reply an Ernest process hands on to it
%% in foreign code's form, which the caller checks; a good answer arrives
reply_handed_on_test() ->
    Source = fun(Relay) ->
                 "type Ask = Ask(reply : Reply(Int))\n"
                 "foreign fn relay(r : Reply(Int)) : Unit = \"ern_emitter_tests:" ++ Relay
                 ++ "/1\"\n"
                 "fn serve() : Unit receiving Ask = receive { Ask(reply = r) -> relay(r) }\n"
                 "export fn main() : Unit = {\n"
                 "    let n = Address.callForever(spawn(serve), fn(r) = Ask(reply = r));\n"
                 "    Io.println(Int.toString(n))\n"
                 "}\n"
             end,
    ?assertMatch({fault, <<"reply does not match Int">>, _}, outcome(Source("relay_junk"))),
    ?assertEqual({ok, <<"5\n">>}, ern_program:run(Source("relay_good"))).

%% report §8.4: a Reply foreign code gives back is held as foreign, so an
%% answer an Ernest process gives it is checked, as foreign code's is: a
%% Reply handed back with another type declared cannot carry an answer of
%% that type to a caller that waits for its own
reply_given_back_test() ->
    {Result, _} = ern_program:run(
        "type Ask = Ask(reply : Reply(Int))\n"
        "foreign fn same(r : Reply(Int)) : Reply(String) ="
        " \"ern_emitter_tests:same/1\"\n"
        "fn serve() : Unit receiving Ask =\n"
        "    receive { Ask(reply = r) -> answer(same(r), \"x\") }\n"
        "export fn main() : Unit = {\n"
        "    let n = Address.callForever(spawn(serve), fn(r) = Ask(reply = r));\n"
        "    Io.println(Int.toString(n))\n"
        "}\n"),
    ?assertMatch({fault, <<"reply does not match Int">>, _}, Result).

%% report §8.4: an answer given to a Reply foreign code gave crosses into
%% foreign code, so an address in it reaches foreign code through the
%% proxy, and a bad message foreign code sends there faults its process; a
%% good one arrives. A regression test: the answer went out as it was, and
%% the bad message was delivered unchecked. It does not cover a function
%% in the answer, which crosses as one in a message does
answer_to_foreign_reply_test() ->
    Source = fun(Asker) ->
                 "type Msg = Go(Int)\n"
                 "type Ask = Ask(reply : Reply(Address(Msg)))\n"
                 "foreign fn ask(server : Address(Ask)) : Unit = \"ern_emitter_tests:"
                 ++ Asker ++ "/1\"\n"
                 "fn serve(me : Address(Msg)) : Unit receiving Ask =\n"
                 "    receive { Ask(reply = r) -> answer(r, me) }\n"
                 "export fn main() : Unit receiving Msg = {\n"
                 "    let me = self();\n"
                 "    ask(spawn(fn() = serve(me)));\n"
                 "    receive { Go(n) -> Io.println(Int.toString(n)) }\n"
                 "}\n"
             end,
    ?assertMatch({fault, <<"message does not match M.Msg">>, _}, outcome(Source("ask_junk"))),
    ?assertEqual({ok, <<"1\n">>}, ern_program:run(Source("ask_good"))).

%% report §8.4: the standard library is the runtime's own, so the return of
%% one of its foreign functions and the reply to a call it makes are not
%% checked; the same declarations in a program's module fault
%% (foreign_faults_test, foreign_messages_test)
standard_library_unchecked_test() ->
    Text = "type Ask = Ask(reply : Reply(Int))\n"
           "foreign fn bad() : Int = \"erlang:node/0\"\n"
           "foreign fn server() : Address(Ask) = \"ern_emitter_tests:junk_server/0\"\n"
           "export fn main() : Unit = {\n"
           "    let _ = bad();\n"
           "    let _ = Address.callForever(server(), fn(r) = Ask(reply = r));\n"
           "    Io.println(\"unchecked\")\n"
           "}\n",
    ?assertEqual({ok, <<"unchecked\n">>}, ern_program:run(['M'], Text, #{standard => true})),
    ?assertEqual(return_cause("erlang:node/0", "Int", ["is ", atom_to_list(node())]),
                 cause_of(outcome(Text))).

%% report §8.4, Appendix E.2: `List.reverse`, a foreign function of the
%% library's, takes a list of any element type, functions, replies and
%% addresses among them, and what it answers is used as the list was.
%% Written when it became the host's `lists:reverse/1`
list_reverse_of_any_element_test() ->
    ?assertEqual({ok, <<"[20, 3]\n#(1, 2)\n">>}, ern_program:run(
        "type ServerMsg = Ask(reply : Reply(Int))\n"
        "type MainMsg = Got(Int)\n"
        "fn serve(held : List(Reply(Int))) : Unit receiving ServerMsg =\n"
        "    if List.size(held) == 2 then\n"
        "        List.forEach(List.indexed(List.reverse(held)),\n"
        "                     fn(#(index, reply)) = answer(reply, index))\n"
        "    else\n"
        "        receive { Ask(reply = r) -> serve(r :: held) }\n"
        "fn asking(server : Address(ServerMsg), me : Address(MainMsg)) : Unit =\n"
        "    send(me, Got(Address.callForever(server, fn(r) = Ask(reply = r))))\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let functions = List.reverse([fn(x : Int) = x + 1, fn(x : Int) = x * 10]);\n"
        "    Io.println(Io.show(List.map(functions, fn(f) = f(2))));\n"
        "    let server = spawn(fn() = serve([]));\n"
        "    let me = self();\n"
        "    let addresses = List.reverse([server, server]);\n"
        "    let _ = spawn(fn() = asking(server, me));\n"
        "    let _ = spawn(fn() = asking(server, me));\n"
        "    let sum = receive { Got(first) -> receive { Got(second) -> first + second } };\n"
        "    Io.println(Io.show(#(sum, List.size(addresses))))\n"
        "}\n")).

%% report §12.3, Appendix E.21: a function of the program's that a shim of
%% the standard library's calls faults as it would anywhere: a division by
%% zero in it is `division by zero`, its trace the host's `erlang:'div'/2`
%% above the program's frame that met it, as through `List.map`, for each
%% shim that is given a function and calls it in the caller, `fold`'s
%% among them; a `fault` passes as it is; and a foreign function's own
%% raise names the foreign function, the host's operator where it is the
%% function, one that raises in its caller's frame, and one of the
%% library's, each called in the function given. A
%% regression test, written after the code: each was the shim's raise,
%% `foreign function maps:map/2 raised error:badarith`
shim_function_faults_as_anywhere_test() ->
    Program = fun(Call) ->
                  "type Bad = Bad(Int)\n"
                  "fn Bad.compare(left : Bad, right : Bad) : Ordering = {\n"
                  "    let Bad(l) = left;\n"
                  "    let Bad(r) = right;\n"
                  "    compare(divided(l, r), 0)\n"
                  "}\n"
                  "fn divided(key : Int, value : Int) : Int = key / value\n"
                  "foreign fn quotient(key : Int, value : Int) : Int = \"erlang:div/2\"\n"
                  "foreign fn boom(x : Int) : Int = \"erlang:error/1\"\n"
                  "export fn main() : Unit = {\n"
                  "    let pairs = [#(1, 0)];\n"
                  "    let zeros = [0];\n"
                  "    let _ = " ++ Call ++ ";\n"
                  "    Io.println(\"unreached\")\n"
                  "}\n"
              end,
    Divisions = ["List.map(zeros, fn(v) = divided(1, v))",
                 "Map.map(Map.fromList(pairs), divided)",
                 "Map.filter(Map.fromList(pairs), fn(k, v) = divided(k, v) > 0)",
                 "Map.mergeWith(Map.fromList(pairs), Map.fromList(pairs),"
                 " fn(_, a, b) = divided(a, b))",
                 "Map.fold(Map.fromList(pairs), 0, fn(acc, k, v) = acc + divided(k, v))",
                 "Set.map(Set.fromList(zeros), fn(v) = divided(1, v))",
                 "Set.filter(Set.fromList(zeros), fn(v) = divided(1, v) > 0)",
                 "List.sort([Bad(1), Bad(0)])"],
    [begin
         {{fault, Cause, Trace}, _} = ern_program:run(Program(Call)),
         Frames = frames(Trace),
         ?assertEqual({Call, <<"division by zero">>, [<<"erlang:'div'/2">>, <<"M.divided:7">>]},
                      {Call, Cause, lists:sublist(Frames, 2)}),
         ?assertEqual({Call, <<"M.main:13">>}, {Call, lists:last(Frames)})
     end || Call <- Divisions],
    [?assertMatch({{fault, Cause, _}, _}, ern_program:run(Program(Call)))
     || {Call, Cause} <- [{"Map.map(Map.fromList(pairs), fn(_, _) = fault(\"x\"))", <<"x">>},
                          {"Map.map(Map.fromList(pairs), quotient)",
                           <<"foreign function erlang:'div'/2 raised error:badarith">>},
                          {"Map.map(Map.fromList(pairs), fn(_, v) = boom(v))",
                           <<"foreign function erlang:error/1 raised error:0">>},
                          {"Map.map(Map.fromList(pairs),"
                           " fn(_, _) = Foreign.atom(String.repeat(\"a\", 300)))",
                           <<"foreign function erlang:binary_to_atom/1 raised"
                             " error:system_limit">>}]].

%% report §6.6, §6.5: a request that makes a call of its own, as printing
%% does, and an adapted address's function that prints, each applied in the
%% caller, leave no call noted once the calls are over. A regression test,
%% written after the fix: once a function that receives nothing could print,
%% the request was made after its call was noted, and the call it made took
%% the caller's row, so that the outer call's stayed in the table of
%% callees. The calls held are the callees' rows and the caller's CALL key
%% (report §8.6). It does not cover a call that a monitor's wrap makes,
%% whose process is its own.
nested_call_is_settled_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Get(Reply(Int))\n"
        "foreign fn held() : Int = \"ern_emitter_tests:calls_held/0\"\n"
        "fn count(total : Int) : Unit receiving Msg = receive {\n"
        "    Get(reply) -> { answer(reply, total); count(total) }\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    let counter = spawn(fn() = count(7));\n"
        "    let printed = adapted(counter, fn(m) = { Io.println(\"adapted\"); m });\n"
        "    let asked = Address.call(counter, fn(reply) = {\n"
        "        Io.println(\"asking\");\n"
        "        Get(reply)\n"
        "    }, 1000);\n"
        "    let forever = Address.callForever(printed, Get);\n"
        "    Io.println(Io.show(#(asked, forever, held())))\n"
        "}\n"),
    ?assertEqual(<<"asking\nadapted\n#(Some(7), 7, 0)\n">>, Output).

%% The foreign side of the tests above.
-spec calls_held() -> non_neg_integer().
calls_held() ->
    ets:info(ern_callees, size) + case get('$ern_call') of undefined -> 0; _ -> 1 end.
-spec pair() -> {integer(), integer()}.
pair() -> {1, 2}.
-spec funs() -> [fun((term()) -> term())].
funs() -> [fun(X) -> X + 1 end, fun(_) -> not_an_int end].
-spec opt(integer()) -> {'Some', integer() | binary()}.
opt(0) -> {'Some', 3};
opt(_) -> {'Some', <<"x">>}.
-spec improper(Element) -> nonempty_improper_list(Element, Element).
improper(Element) -> [Element | Element].
%% report §8.4: remembers the first address it is given and says whether
%% the next is the same one
-spec remember(pid()) -> boolean().
remember(Pid) ->
    case persistent_term:get({?MODULE, proxy_seen}, undefined) of
        undefined -> persistent_term:put({?MODULE, proxy_seen}, Pid), false;
        Pid -> true;
        _ -> false
    end.

-spec junk(pid()) -> 'Unit'.
junk(Pid) -> Pid ! {'Go', <<"x">>}, 'Unit'.
-spec good(pid()) -> 'Unit'.
good(Pid) -> Pid ! {'Go', 1}, 'Unit'.
-spec tell([pid()]) -> 'Unit'.
tell(Pids) -> [P ! {'Go', 2} || P <- Pids], 'Unit'.
-spec junk_server() -> pid().
junk_server() ->
    spawn(fun() -> receive {'Ask', {Alias, _}} -> Alias ! {Alias, <<"x">>} end end).
%% report §8.4: a foreign process that answers a Hello with a message to the
%% address it holds, of another type or of the declared one
-spec hello_junk() -> pid().
hello_junk() ->
    spawn(fun() -> receive {'Hello', Address} -> Address ! {'Go', <<"x">>} end end).
-spec hello_good() -> pid().
hello_good() ->
    spawn(fun() -> receive {'Hello', Address} -> Address ! {'Go', 1} end end).
%% report §12.2: foreign code given a Reply answers it as the ABI says
-spec relay_junk({reference(), pid()}) -> 'Unit'.
relay_junk({Alias, _}) -> Alias ! {Alias, <<"x">>}, 'Unit'.
-spec relay_good({reference(), pid()}) -> 'Unit'.
relay_good({Alias, _}) -> Alias ! {Alias, 5}, 'Unit'.
%% report §8.4: a Reply handed back as it was given, its type declared anew
-spec same(Reply) -> Reply.
same(Reply) -> Reply.
%% report §8.4: whether foreign code given two values at type variables,
%% which cross as the runtime holds them, is given one term, by which a test
%% tells an address the program holds as its own from one it holds as
%% foreign
-spec identical(term(), term()) -> boolean().
identical(Given, Own) -> Given =:= Own.
%% report §8.4: foreign code that calls the function inside its argument
%% with a value of another type, or of the declared one
-spec call_nested_bad({integer(), fun((term()) -> integer())}) -> integer().
call_nested_bad({_, Function}) -> Function(<<"bad">>).
-spec call_nested_good({integer(), fun((term()) -> integer())}) -> integer().
call_nested_good({Number, Function}) -> Function(Number).
%% report §8.4: foreign code that asks an Ernest server with a Reply of its
%% own, its alias and its process, and sends the address it is answered a
%% message of another type or of the declared one
-spec ask_junk(pid()) -> 'Unit'.
ask_junk(Server) -> ask(Server, <<"x">>).
-spec ask_good(pid()) -> 'Unit'.
ask_good(Server) -> ask(Server, 1).
ask(Server, Value) ->
    spawn(fun() ->
              Reply = erlang:alias(),
              Server ! {'Ask', {Reply, self()}},
              receive {Reply, Address} -> Address ! {'Go', Value} end
          end),
    'Unit'.
%% report §8.4: foreign code that ends the checker it was given, as the host
%% ends a process, waited for until the reaper, which holds the checker, has
%% taken its end
-spec checker_ended(pid()) -> 'Unit'.
checker_ended(Checker) ->
    exit(Checker, kill),
    ok = ern_waits:until(ern_rt:launch_reaper(),
                         fun() -> ets:lookup(ern_checkers, {behind, Checker}) =:= [] end),
    'Unit'.

%% report §4.5: an Ernest function named like an auto-imported
%% Erlang BIF, `size`, `max`, is called by its own name
bif_names_test() ->
    {ok, Output} = ern_program:run(
        "fn max(a : Int, b : Int) : Int = if a > b then a else b\n"
        "fn size(xs : List(Int)) : Int = List.size(xs) * 10\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    Io.println(Int.toString(size([1])))\n"
        "}\n"),
    ?assertEqual(<<"2\n10\n">>, Output).

%% report §4.2, §4.6, §8.5: a module names its own declaration qualified
%% where a binding hides the plain name, a private function and a `let`,
%% called and taken as values, and a `let` so named is still ordered after
%% the one it reads; where nothing hides it, and for a type, a constructor
%% or a member, which no binding hides, the qualified name is refused. A
%% regression test: each was a remote call, undefined for a private
%% function, and the `let` was not seen as a dependency
qualified_own_name_test() ->
    {ok, Output} = ern_program:run(
        "let total = { let base = 0; M.base * 2 + base }\n"
        "let base = 3\n"
        "fn two() : Int = 2\n"
        "export fn main() : Unit = {\n"
        "    let two = fn() : Int = 10;\n"
        "    let f = M.two;\n"
        "    Io.println(Int.toString(M.two() + f() + two()));\n"
        "    Io.println(Int.toString(total))\n"
        "}\n"),
    ?assertEqual(<<"14\n6\n">>, Output),
    Refused = fun(Text) ->
                      {error, [Diagnostic | _]} = ern_typecheck:check_string(['M'], Text),
                      Diagnostic#diagnostic.message
              end,
    ?assertEqual("M.two is written only where a binding hides two",
                 Refused("fn two() : Int = 2\nfn f() : Int = M.two()\n")),
    ?assertEqual("M.Box is the module's own Box, which no binding hides",
                 Refused("type Box = Box(Int)\nfn f() : M.Box = Box(1)\n")),
    ?assertEqual("M.Box is the module's own Box, which no binding hides",
                 Refused("type Box = Box(Int)\nfn f() : Box = M.Box(1)\n")),
    ?assertEqual("`M.Box.negate` names a member, which an expression reaches through prefix `-`",
                 Refused("type Box = Box(Int)\n"
                         "fn Box.negate(b : Box) : Box = b\n"
                         "fn f() : Box = M.Box.negate(Box(1))\n")).

%% report §6.3, §4.5: a timed receive's time below 0 is 0 whatever the
%% module calls `max`. A regression test: the emitted `max(0, t)` called
%% the module's own `max/2`, here a difference, which gave a negative time
qualified_max_test() ->
    {ok, Output} = ern_program:run(
        "fn max(a : Int, b : Int) : Int = a - b\n"
        "type Msg = Ping\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    Io.println(Int.toString(max(1, 2)));\n"
        "    receive { Ping -> Unit | after 10 -> Io.println(\"after\") }\n"
        "}\n"),
    ?assertEqual(<<"-1\nafter\n">>, Output).

%% report §6.6, §8.4: `Address.call` and `Address.callForever` taken as
%% values answer as the calls do, and check a reply whose Reply crossed into
%% foreign code as the calls do. A regression test: as values they once
%% left the reply unchecked
call_as_value_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Get(reply : Reply(Int))\n"
        "fn serve() : Unit receiving Msg = receive { Get(reply = r) -> answer(r, 7) }\n"
        "export fn main() : Unit = {\n"
        "    let c : (Address(Msg), (Reply(Int)) -> Msg, Int) -> Optional(Int) = Address.call;\n"
        "    let w : (Address(Msg), (Reply(Int)) -> Msg) -> Int = Address.callForever;\n"
        "    let asked = c(spawn(serve), fn(r) = Get(reply = r), 1000);\n"
        "    let n = Optional.withDefault(asked, 0);\n"
        "    Io.println(Int.toString(n + w(spawn(serve), fn(r) = Get(reply = r))))\n"
        "}\n"),
    ?assertEqual(<<"14\n">>, Output),
    {Result, _} = ern_program:run(
        "type Ask = Ask(reply : Reply(Int))\n"
        "foreign fn server() : Address(Ask) ="
        " \"ern_emitter_tests:junk_server/0\"\n"
        "export fn main() : Unit = {\n"
        "    let w : (Address(Ask), (Reply(Int)) -> Ask) -> Int ="
        " Address.callForever;\n"
        "    Io.println(Int.toString(w(server(), fn(r) = Ask(reply = r))))\n"
        "}\n"),
    ?assertMatch({fault, <<"reply does not match Int">>, _}, Result).

%% report §5.11, §6.3: a pattern's size names a top-level `let`, which the
%% `match` or the `receive` reads before it begins. A regression test: the
%% checker refused it, the host's pattern showing through
bitstring_size_reads_a_top_level_let_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Packet(Bytes)\n"
        "let headerSize = 2\n"
        "fn header(b : Bytes) : Optional(Bytes) = match b {\n"
        "    <<h:size(headerSize)-bytes, _:bytes>> -> Some(h)\n"
        "  | _ -> None\n"
        "}\n"
        "fn take() : Optional(Bytes) receiving Msg = receive {\n"
        "    Packet(<<h:size(headerSize * 2)-bytes, _:bytes>>) -> Some(h)\n"
        "  | Packet(_) -> None\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    Io.println(Io.show(#(header(<<1, 2, 3>>), header(<<1>>))));\n"
        "    send(self(), Packet(<<1, 2, 3, 4, 5>>));\n"
        "    Io.println(Io.show(take()))\n"
        "}\n"),
    ?assertEqual(<<"#(Some(<<1, 2>>), None)\nSome(<<1, 2, 3, 4>>)\n">>, Output).

%% report §5.1, §5.11: a match evaluates its scrutinee before it reads a
%% top-level `let` a pattern's size names. The module runs without its
%% initializers, so the read faults, and what the scrutinee printed shows
%% that it came first; the binding is computed, since a ground term's is
%% no read (§11.1). A regression test: the read came before the
%% scrutinee, against §5.1's left to right
size_read_after_scrutinee_test() ->
    Text = "let width = 1 + 0\n"
           "fn first(b : Bytes) : Bytes = match Io.debug(b) {\n"
           "    <<h:size(width)-bytes, _:bytes>> -> h\n"
           "  | _ -> b\n"
           "}\n"
           "export fn main() : Unit = {\n"
           "    let _ = first(<<7, 8>>);\n"
           "    Unit\n"
           "}\n",
    %% a namespace of its own: a binding's value is kept under its unit and
    %% its getter, which a unit of another test's of one name may have set
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['SizeRead'], Text),
    Build = #{source_hash => <<>>, deps => [], standard => false},
    {ok, ErlangModule, Beam} = ern_compile:compile(['SizeRead'], Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    %% Io.debug writes to standard error (Appendix E.1)
    Result = ern_rt:run_main(fun() -> (ern_named:main(ErlangModule))() end, <<"main">>,
                             #{init => fun() -> ok end,
                               stderr => fun(Written) -> Self ! {out, Written} end,
                               stdin => fun() -> eof end}),
    ?assertNotEqual(ok, Result),
    ?assertEqual(<<"<<7, 8>>\n">>, ern_program:collect([])).

%% report §5.11: the report's frame round trip, sub-octet fields, utf8,
%% float and signed and little segments, a dynamic size in a pattern, and
%% an unaligned rest that fails the match
bitstrings_test() ->
    {ok, Output} = ern_program:run(
        "fn frame(len : Int, body : Bytes) : Bytes = <<len:size(16)-big, body:bytes>>\n"
        "fn parseFrame(bytes : Bytes) : Optional(#(Int, Bytes, Bytes)) = match bytes {\n"
        "    <<len:size(16)-big, body:size(len)-bytes, rest:bytes>> -> Some(#(len, body, rest))\n"
        "  | _ -> None\n"
        "}\n"
        "fn show(b : Bytes) : String = match b {\n"
        "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn nibbles(b : Bytes) : String = match b {\n"
        "    <<hi:size(4), lo:size(4), rest:bytes>> ->"
        " Int.toString(hi) <> \":\" <> Int.toString(lo) <> \" \" <> nibbles(rest)\n"
        "  | _ -> \"\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) : String = match b {\n"
        "    <<_:size(n)-bytes, rest:bytes>> -> show(rest)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    let f = frame(1, <<65, 66>>);\n"
        "    Io.println(show(f));\n"
        "    match parseFrame(f) {\n"
        "        Some(#(len, body, rest)) ->"
        " Io.println(Int.toString(len) <> \": \" <> show(body) <> \"| \" <> show(rest))\n"
        "      | None -> Io.println(\"none\")\n"
        "    };\n"
        "    match parseFrame(<<0>>) {"
        " Some(_) -> Io.println(\"some\") | None -> Io.println(\"none\") };\n"
        "    match <<'é':utf8, 0>> { <<c:utf8, _:bytes>> -> Io.println(String.fromList([c]))"
        " | _ -> Io.println(\"?\") };\n"
        "    Io.println(nibbles(<<31, 42>>));\n"
        "    Io.println(show(<<1.5:size(32)-float, -1:size(8)-signed, 258:size(16)-little>>));\n"
        "    Io.println(tail(1, <<1, 2>>));\n"
        "    Io.println(tail(3, <<1, 2>>));\n"
        "    Io.println(show(<<(String.toUtf8(\"hi\")):bytes, 3:size(4), 4:size(4)>>))\n"
        "}\n"),
    ?assertEqual(<<"0 1 65 66 \n1: 65 | 66 \nnone\né\n1:15 2:10 \n63 192 0 0 255 2 1 \n2 \nno\n"
                   "104 105 52 \n"/utf8>>, Output).

%% report §7.4, §5.11: a computed value that does not fit its width faults
%% with segment overflow, an Int, a Float, a Bytes of another size, the
%% cause saying what did not fit; a dynamic size that leaves the count
%% unaligned faults at construction. Report §7.3, Appendix E.21: the
%% frame that meets the fault has the bitstring's line, a regression test
%% of that, written with the fix (the log's *The Full Review Before
%% 0.5.0*: the frame had none)
bitstring_faults_test() ->
    Main = "export fn main() : Unit =\n    ",
    Three = "fn three() : Int = List.size([1, 2, 3])\n",
    Faults = [{"<<(299 + 1):size(8)>>", <<"segment overflow: 300 does not fit 8 bits">>},
              {"<<(0 - 129):size(8)-signed>>",
               <<"segment overflow: -129 does not fit 8 signed bits">>},
              {"<<(1.0e300 * 1.0):size(32)-float>>",
               <<"segment overflow: 1.0e300 does not fit a 32-bit float">>},
              {"<<(<<1, 2, 3>>):size(2)-bytes>>",
               <<"segment overflow: a 3-byte value does not fit 2 bytes">>},
              {"<<7:size(three())>>", <<"bitstring not byte-aligned">>}],
    lists:foreach(fun({Bits, Cause}) ->
                      {Result, _} = ern_program:run(
                          Three ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertMatch({fault, Cause, _}, Result),
                      {fault, _, Trace} = Result,
                      ?assertEqual([<<"M.main:3">>], frames(Trace))
                  end, Faults).

%% report §5.11: a bare segment is an unsigned big-endian int of size 8;
%% a sized int is big-endian; `signed` alone is 8 bits. A regression test,
%% written after the code; it does not cover `little` or a pattern with a
%% signed segment
bitstring_defaults_test() ->
    Show = "fn show(b : Bytes) : String = match b {\n"
           "    <<x, rest:bytes>> -> Int.toString(x) <> \" \" <> show(rest)\n"
           "  | _ -> \"\"\n"
           "}\n",
    {ok, Output} = ern_program:run(Show ++
        "export fn main() : Unit = {\n"
        "    Io.println(show(<<258:size(16)>>));\n"
        "    Io.println(match <<255>> { <<x>> -> Int.toString(x) | _ -> \"no\" });\n"
        "    Io.println(show(<<-1:signed>>))\n"
        "}\n"),
    ?assertEqual(<<"1 2 \n255\n255 \n">>, Output),
    {Result, _} =
        ern_program:run("export fn main() : Unit = { let n = 0 - 1; let _ = <<n>>; Unit }\n"),
    ?assertMatch({fault, <<"segment overflow: -1 does not fit 8 bits">>, _}, Result).

%% report §8.5: top-level lets run in the order the checker's let_order/1
%% gives, a let after every let it reaches through the functions it names,
%% whatever the order they are declared in. A regression test, written when
%% the emitter came to read that order in place of computing its own, which
%% was the same.
initialization_order_test() ->
    {ok, Output} = ern_program:run("let total = twice() + 1\n"
                                   "fn twice() : Int = base * 2\n"
                                   "let base = 10\n"
                                   "export fn main() : Unit = Io.println(Int.toString(total))\n"),
    ?assertEqual(<<"21\n">>, Output).

%% report §4.2: a name shadowed at each step of the lookup order compiles
%% to the declaration the checker resolved it to, which the emitter reads
%% from the name's `ref` rather than resolving again: a type's member,
%% which prefix `-` reaches, beside a function of the member's name, the
%% module's own function over the prelude's `self`, the module named
%% qualified past a local binding that hides it, `Prelude.self`, and a
%% local binding over them all. A regression test for the single decision;
%% the order it had was the same.
lookup_order_test() ->
    {ok, Output} = ern_program:run(
        "type Box = Box(Int)\n"
        "fn Box.negate(b : Box) : Int = match b { Box(n) -> n }\n"
        "fn negate(b : Box) : Int = 100\n"
        "fn self() : Int = 5\n"
        "export fn main() : Unit receiving Never = {\n"
        "    let me = Prelude.self();\n"
        "    let first = -Box(1) + negate(Box(1)) + self();\n"
        "    let self = fn() : Int = 10;\n"
        "    let second = self() + M.self();\n"
        "    let negate = fn(b : Box) : Int = 1000;\n"
        "    Io.println(Int.toString(first + second + negate(Box(1))))\n}\n"),
    ?assertEqual(<<"1121\n">>, Output).

%% report §11.1: a function may be named `module_info` or `record_info`,
%% the names the host gives every module, since a unit names its functions
%% by their position and never by their Ernest names. A regression test:
%% the compiler once refused them with Erlang's "function module_info/0
%% already defined", and the shell faulted. Not covered here: a call from
%% another module, which the shell test reaches.
host_reserved_names_test() ->
    {ok, Output} = ern_program:run(
        "export fn module_info() : Int = 7\n"
        "fn record_info(x : Int) : Int = x + 1\n"
        "export let total = module_info() + record_info(1)\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(total));\n"
        "    Io.println(Int.toString(List.foldLeft(List.map([1, 2], record_info), 0,"
        " fn(a, b) = a + b)))\n}\n"),
    ?assertEqual(<<"9\n5\n">>, Output).

%% report §5.11, §5.4: a variable a bitstring pattern binds is the
%% pattern's own, not a use of an outer name. A regression test: a local
%% fn whose pattern bound `y` was read as depending on the later `let y`,
%% and the compiler crashed with an Erlang exception; used after the `let`,
%% it captured the outer `y` it never read.
bitstring_pattern_binds_test() ->
    Local = "    fn first(b : Bytes) : Int = match b { <<y, _:bytes>> -> y | _ -> 0 };\n",
    {ok, Before} = ern_program:run("export fn main() : Unit = {\n" ++ Local ++
                                   "    let n = first(<<5, 6>>);\n    let y = 10;\n"
                                   "    Io.println(Int.toString(n + y))\n}\n"),
    ?assertEqual(<<"15\n">>, Before),
    {ok, After} = ern_program:run("export fn main() : Unit = {\n    let y = 10;\n" ++ Local ++
                                  "    Io.println(Int.toString(first(<<5, 6>>) + y))\n}\n"),
    ?assertEqual(<<"15\n">>, After).

%% report §5.11, §7.4, §3.1: a Bytes shorter than its size and a negative
%% size fault at construction; a Float narrowed to 16 bits rounds to the
%% nearest, one too small becomes 0.0, one above the largest 16-bit float
%% faults; a float pattern does not match the bytes of an infinity or a
%% NaN; a rest that a dynamic size leaves unaligned does not match. A
%% regression test, written after the code; it does not cover a 32-bit
%% float's rounding, nor a negative size in a pattern
bitstring_edges_test() ->
    Neg = "fn neg() : Int = 0 - List.size([1, 2, 3, 4, 5, 6, 7, 8])\n",
    Main = "export fn main() : Unit = ",
    Faults = ["<<(<<1>>):size(2)-bytes>>", "<<1:size(neg())>>", "<<(<<1>>):size(neg())-bytes>>",
              "<<(65519.0 * 1.0):size(16)-float>>"],
    lists:foreach(fun(Bits) ->
                      {Result, _} = ern_program:run(
                          Neg ++ Main ++ "{ let _ = " ++ Bits ++ "; Unit }\n"),
                      ?assertMatch({Bits, {fault, <<"segment overflow", _/binary>>, _}},
                                   {Bits, Result})
                  end, Faults),
    {ok, Output} = ern_program:run(
        "fn half(b : Bytes) : String = match b {\n"
        "    <<f:size(16)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn single(b : Bytes) : String = match b {\n"
        "    <<f:size(32)-float>> -> Float.toString(f)\n"
        "  | _ -> \"no\"\n"
        "}\n"
        "fn tail(n : Int, b : Bytes) : String = match b {\n"
        "    <<_:size(n), rest:bytes>> -> Int.toString(Bytes.size(rest))\n"
        "  | _ -> \"no\"\n"
        "}\n"
        ++ Main ++ "{\n"
        "    Io.println(half(<<3.14159:size(16)-float>>));\n"
        "    Io.println(half(<<1.0e-10:size(16)-float>>));\n"
        "    Io.println(half(<<65504.0:size(16)-float>>));\n"
        "    Io.println(single(<<127, 128, 0, 0>>));\n"
        "    Io.println(single(<<255, 128, 0, 0>>));\n"
        "    Io.println(single(<<127, 192, 0, 0>>));\n"
        "    Io.println(half(<<124, 0>>));\n"
        "    Io.println(tail(8, <<1, 2>>));\n"
        "    Io.println(tail(4, <<1, 2>>))\n"
        "}\n"),
    ?assertEqual(<<"3.140625\n0.0\n65504.0\nno\nno\nno\nno\n1\nno\n">>, Output).

%% report §7.4: a zero divisor faults main with its cause
division_fault_test() ->
    {Result, _} = ern_program:run("export fn main() : Unit = {\n"
                                  "    let z = List.size([]);\n"
                                  "    Io.println(Int.toString(1 / z))\n"
                                  "}\n"),
    ?assertMatch({fault, <<"division by zero">>, _}, Result).

%% report §7.4, §9.6: fault compiles at any type and faults with its cause
fault_test() ->
    {Result, _} = ern_program:run("fn later() : Int = fault(\"later\")\n"
                                  "export fn main() : Unit = Io.println(Int.toString(later()))\n"),
    ?assertMatch({fault, <<"later">>, _}, Result).

%% report §5.6, §12.2: named fields in canonical order, and update from a
%% base value
constructors_test() ->
    {ok, Output} = ern_program:run(
        "type Point = Point(y : Int, x : Int)\n"
        "type Shape = Dot | At(Point)\n"
        "fn show(s : Shape) : String = match s {\n"
        "    Dot -> \"dot\"\n"
        "  | At(Point(=x, =y)) -> Int.toString(x) <> \",\" <> Int.toString(y)\n"
        "}\n"
        "export fn main() : Unit = {\n"
        "    let p = Point(x = 1, y = 2);\n"
        "    Io.println(show(At(Point(..p, x = 5))));\n"
        "    Io.println(show(Dot));\n"
        "    let wrapped = List.map([p], At);\n"
        "    Io.println(Int.toString(List.size(wrapped)))\n"
        "}\n"),
    ?assertEqual(<<"5,2\ndot\n1\n">>, Output).

%% report §3.5, §12.2: a selected field, one element of the tuple where every
%% constructor holds it at one place and a case on the tag where the places
%% differ, its operand evaluated once
field_selection_test() ->
    {ok, Output} = ern_program:run(
        "type Pair = Left(a : Int, name : String) | Right(name : String, z : Int)\n"
        "type Point = Point(x : Int, y : Int)\n"
        "fn v(p : Pair) : Pair = { Io.println(\"once\"); p }\n"
        "export fn main() : Unit = {\n"
        "    Io.println(v(Left(a = 1, name = \"l\")).name <> Right(name = \"r\", z = 2).name);\n"
        "    Io.println(Int.toString(Point(x = 3, y = 4).y))\n"
        "}\n"),
    ?assertEqual(<<"once\nlr\n4\n">>, Output).

%% report §3.5, §5.1: named fields are stored and shown in their declared
%% order and evaluated in the order written, in a construction and in an
%% update from a base value, whose base is evaluated first. A regression
%% test: the fields were evaluated in the order of their names, and then
%% stored so. It does not cover a positional constructor, whose one field
%% has no order
field_order_test() ->
    {ok, Output} = ern_program:run(
        "type Snap = Snap(z : Int, a : Int, m : Int)\n"
        "fn v(s : String, n : Int) : Int = { Io.println(s); n }\n"
        "export fn main() : Unit = {\n"
        "    let s = Snap(m = v(\"m\", 3), z = v(\"z\", 1), a = v(\"a\", 2));\n"
        "    let t = Snap(..{ Io.println(\"base\"); s }, m = v(\"m\", 4), a = v(\"a\", 5));\n"
        "    let _ = Io.debug(#(s, t));\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"m\nz\na\nbase\nm\na\n"
                   "#(M.Snap(z = 1, a = 2, m = 3), M.Snap(z = 1, a = 5, m = 4))\n">>, Output).

%% report §5.3, §5.8: lambdas capture, if is an expression
lambda_if_test() ->
    {ok, Output} = ern_program:run(
        "export fn main() : Unit = {\n"
        "    let k = 3;\n"
        "    let f = fn(x : Int) = if x > k then \"big\" else \"small\";\n"
        "    Io.println(f(5));\n"
        "    Io.println(f(1))\n"
        "}\n"),
    ?assertEqual(<<"big\nsmall\n">>, Output).

%% report §6.2, §6.9: a process monitored from its start that faults
%% reports its spawn site and its cause, however soon it faults
monitor_site_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down)\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(site = f, reason = Fault(msg))) -> Io.println(f <> \" \" <> msg)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"M.main:4 division by zero\n">>, Output).

%% report §6.9: a spawn site names the declaration by its Ernest name, one
%% the host's own names collide with among them. A regression test: a
%% function named module_info was named `module_info$`
host_named_site_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down)\n"
        "fn module_info() : Unit receiving Msg = {\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive { Died(Down(site = f, reason = _)) -> Io.println(f) }\n"
        "}\n"
        "export fn main() : Unit receiving Msg = module_info()\n"),
    ?assertEqual(<<"M.module_info:4\n">>, Output).

%% report §6.9: a Down's function is the top-level declaration the spawn
%% is written in: one inside a local fn or a lambda counts as written in
%% the enclosing declaration, and `spawn` taken as a value counts where
%% its name is written. A regression test, written after the code; it does
%% not cover a spawn in a top-level `let`'s initializer
down_site_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down)\n"
        "fn idle() : Unit receiving Unit = receive { _ -> Unit }\n"
        "fn report() : Unit receiving Msg = receive {\n"
        "    Died(Down(site = f, reason = _)) -> Io.println(f)\n"
        "}\n"
        "fn outer() : Unit receiving Msg = {\n"
        "    fn inner() : Address(Unit) receiving Msg = spawn(idle);\n"
        "    watched(inner());\n"
        "    let viaLambda = fn() = spawn(idle);\n"
        "    watched(viaLambda());\n"
        "    let s = spawn;\n"
        "    watched(s(idle))\n"
        "}\n"
        "// monitored while it waits, then killed\n"
        "fn watched(idler : Address(Unit)) : Unit receiving Msg = {\n"
        "    monitor(Process.fromAddress(idler), Died);\n"
        "    kill(Process.fromAddress(idler));\n"
        "    report()\n"
        "}\n"
        "export fn main() : Unit receiving Msg = outer()\n"),
    ?assertEqual(<<"M.outer:7\nM.outer:9\nM.outer:11\n">>, Output).

%% report §9.4, §9.6: spawn, spawnMonitored and compare are functions and
%% may be passed as values, a spawn's site where its name is written
%% (§6.9); report §4.5: an operator's member is no value, and a lambda
%% passes the operation
prelude_values_test() ->
    {ok, Output} = ern_program:run(
        "fn apply2(f : (Int, Int) -> Int, a : Int, b : Int) : Int = f(a, b)\n"
        "fn twice(f : (Int) -> Int, a : Int) : Int = f(f(a))\n"
        "fn join(f : (String, String) -> String) : String = f(\"a\", \"b\")\n"
        "fn order(f : (Int, Int) -> Ordering) : Ordering = f(1, 2)\n"
        "fn start(s : (() -> Unit receiving Never) -> Address(Never)) : Address(Never) ="
        " s(fn() = Unit)\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Int.toString(apply2(fn(a, b) = a + b, 2, 3)));\n"
        "    Io.println(Int.toString(apply2(fn(a, b) = a / b, 7, 2)));\n"
        "    Io.println(Int.toString(apply2(fn(a, b) = a % b, 7, 2)));\n"
        "    Io.println(Int.toString(twice(fn(a) = -a, 5)));\n"
        "    Io.println(join(fn(a, b) = a <> b));\n"
        "    Io.println(Io.show(order(compare)));\n"
        "    let _ = start(spawn);\n"
        "    Unit\n"
        "}\n"),
    ?assertEqual(<<"5\n3\n1\n5\nab\nLess\n">>, Output),
    {ok, Monitored} = ern_program:run(
        "type Msg = Died(Down)\n"
        "fn start(s : (() -> Unit receiving Never, (Down) -> Msg) -> Address(Never)"
        " receiving Msg) : Address(Never) receiving Msg =\n"
        "    s(fn() = { let _ = fault(\"boom\"); Unit }, Died)\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let _ = start(spawnMonitored);\n"
        "    receive {\n"
        "        Died(Down(site = f, reason = Fault(m))) -> Io.println(f <> \" \" <> m)\n"
        "      | Died(_) -> Io.println(\"other\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"M.main:5 boom\n">>, Monitored).

%% report Appendix E, §5.2: a stdlib function and an Address function
%% passed as values
stdlib_values_test() ->
    {ok, Output} = ern_program:run(
        "fn call(f : (Address(m), (Reply(Int)) -> m, Int) -> Optional(Int) receiving n,"
        " a : Address(m), mk : (Reply(Int)) -> m) : Optional(Int) receiving n = f(a, mk, 100)\n"
        "type Msg = Ask(Reply(Int))\n"
        "fn answerer() : Unit receiving Msg = receive { Ask(r) -> answer(r, 7) }\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Bool.toString(List.all(String.toList(\"123\"), Char.isDigit)));\n"
        "    let a = spawn(fn() = answerer());\n"
        "    match call(Address.call, a, Ask) {\n"
        "        Some(n) -> Io.println(Int.toString(n))\n"
        "      | None -> Io.println(\"none\")\n"
        "    }\n"
        "}\n"),
    ?assertEqual(<<"true\n7\n">>, Output).

%% report §8.5, §8.2: a system module's reference is bound before the
%% program's own top-level lets are evaluated, so an initializer may print
system_reference_in_let_test() ->
    {ok, Output} = ern_program:run("let greeting = Io.println(\"from a let\")\n"
                                   "export fn main() : Unit = Io.println(\"from main\")\n"),
    ?assertEqual(<<"from a let\nfrom main\n">>, Output).

%% report §9, Appendix E: every prelude value the
%% checker knows is emitted as a call to a function that exists, with the
%% arity of its type, so no accepted name can reach the runtime as undef
prelude_targets_test() ->
    Missing = [QualifiedName || {QualifiedName, Text, _, _} <- ern_prelude:values(),
                                not is_inline(QualifiedName),
                                {ErlangModule, Function, Arity}
                                    <- [prelude_target(QualifiedName, Text)],
                                code:ensure_loaded(ErlangModule) =/= {module, ErlangModule}
                                    orelse not erlang:function_exported(ErlangModule, Function,
                                                                        Arity)],
    ?assertEqual([], Missing).

%% Whether ern_emitter writes a prelude name inline, as the host's
%% operation, with no function to call: Int's arithmetic and negate, the
%% `<>` of String and Bytes, and `compare`, which applies its supply
%% (report §3.10, §9.6).
is_inline(['Int', compare]) -> false;
is_inline(['Int', _]) -> true;
is_inline([TypeName, '<>']) -> TypeName =:= 'String' orelse TypeName =:= 'Bytes';
is_inline([compare]) -> true;
is_inline(_) -> false.

%% The function a prelude name's emission calls: a primitive the runtime's
%% (ern_emitter:primitive/1); Float's operators, and the `<>` of List and
%% Path, their modules' functions (report §4.8), each the function its unit
%% names it by (report §11.1, ern_code:function/2), a parameter after the
%% function's own for each member its requirement names (report §4.9).
prelude_target(QualifiedName, Text) ->
    {TypeText, Requirement} = ern_prelude:signature(Text),
    {ok, Syntax} = ern_parser:parse_type(TypeText),
    Arity = case Syntax of
                #t_fn{params = Params} -> length(Params) + length(Requirement);
                _ -> 0
            end,
    case {ern_emitter:primitive(QualifiedName), QualifiedName} of
        {{Function, PrimitiveArity}, _} ->
            {ern_rt, Function, PrimitiveArity};
        {none, [Namespace, _]} ->
            Unit = ern_namespace:erlang_module([Namespace]),
            case ern_code:function(Unit, QualifiedName) of
                {Function, _} -> {Unit, Function, Arity};
                none -> {Unit, none, Arity}
            end
    end.

%% report §6.5, §6.9, §7.3, §9.5: kill is a Down with Killed, a fault a
%% Down with its cause, and an adapted address turns a message, all
%% through compiled code
process_functions_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down) | Tick\n"
        "fn idle() : Unit receiving Unit = receive { _ -> Unit }\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let w = spawn(fn() = idle());\n"
        "    monitor(Process.fromAddress(w), Died);\n"
        "    kill(Process.fromAddress(w));\n"
        "    receive {\n"
        "        Died(Down(reason = Killed, site = _)) -> Io.println(\"killed\")\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    let z = List.size([]);\n"
        "    let _ = spawnMonitored(fn() = { let _ = 1 / z; Unit },"
        " Died);\n"
        "    receive {\n"
        "        Died(Down(reason = Fault(m), site = _)) -> Io.println(m)\n"
        "      | _ -> Io.println(\"other\")\n"
        "    };\n"
        "    send(adapted(self(), fn(u : Unit) = Tick), Unit);\n"
        "    receive { Tick -> Io.println(\"tick\") | _ -> Io.println(\"other\") }\n"
        "}\n"),
    ?assertEqual(<<"killed\ndivision by zero\ntick\n">>, Output).

%% report §6.9, §6.5, §4.5: a wrap may call a function written `: T`
%% that calls `self` or `monitor` without showing the address, and what it
%% asks of the runtime is the process it delivers to: `kill(Process.fromAddress(self()))` kills
%% that process, whose monitor sees Killed, and a monitor made there
%% delivers to that process, whose wrap's fault is the process's own at its
%% next wait, after the delivery that made the monitor has ended. A
%% regression test, written after the code: the helpers' `: T` was
%% refused, and in a wrap `self()` answered the delivery, so the kill ended
%% the delivery and the Down vanished, and the monitor was the delivery's
wrap_asks_for_its_recipient_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down) | Ready\n"
        "type Ward = Wrapped\n"
        "fn stop() : Unit = kill(Process.fromAddress(self()))\n"
        "fn watch(p : Process) : Unit = monitor(p, fn(d) = fault(\"seen\"))\n"
        "fn idle() : Unit receiving Unit = receive { _ -> Unit }\n"
        "fn short() : Process = Process.fromAddress(spawn(fn() = Unit))\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let _ = spawnMonitored(fn() : Unit receiving Ward = {\n"
        "        monitor(short(), fn(d) = { stop(); Wrapped });\n"
        "        receive { Wrapped -> Unit }\n"
        "    }, Died);\n"
        "    receive { Died(d) -> Io.println(Io.show(d.reason)) };\n"
        "    let watched = spawn(fn() = idle());\n"
        "    let me = self();\n"
        "    let _ = spawnMonitored(fn() : Unit receiving Ward = {\n"
        "        monitor(short(), fn(d) = { watch(Process.fromAddress(watched)); Wrapped });\n"
        "        receive { Wrapped -> send(me, Ready) };\n"
        "        receive { Wrapped -> Unit }\n"
        "    }, Died);\n"
        "    receive { Ready -> kill(Process.fromAddress(watched)) };\n"
        "    receive { Died(d) -> Io.println(Io.show(d.reason)) }\n"
        "}\n"),
    ?assertEqual(<<"Killed\nFault(\"seen\")\n">>, Output).

%% report §8.4, §12.3: a function value inside a recursive type that comes
%% back from foreign code has its result checked against the type at each
%% call, the recursive type's own among them. A regression test: the check
%% met the type's reference back to itself with nothing to look it up in,
%% and the call faulted with badkey
recursive_function_value_test() ->
    ?assertEqual({ok, <<"3\n">>}, ern_program:run(
        "type Chain = Chain(n : Int, next : () -> Chain)\n"
        "foreign fn first(chains : List(Chain)) : Chain = \"erlang:hd/1\"\n"
        "fn from(n : Int) : Chain = Chain(=n, next = fn() = from(n + 1))\n"
        "export fn main() : Unit = {\n"
        "    let c = first([from(1)]);\n"
        "    Io.println(Int.toString(c.next().next().n))\n"
        "}\n")).

%% Appendix E.12: a text longer than 255 characters makes no atom, and
%% `Foreign.atom` faults as a foreign function that raises does (report §12.3)
foreign_atom_too_long_test() ->
    {Result, _} = ern_program:run("export fn main() : Unit = {\n"
                                  "    let _ = Foreign.atom(String.padStart(\"\", 256, \"a\"));\n"
                                  "    Unit\n"
                                  "}\n"),
    ?assertMatch({fault, <<"foreign function erlang:binary_to_atom/1 raised error:system_limit">>,
                  _}, Result).

%% docs/memory_checks.md, *Atoms*: a program's work makes no atoms, since the host
%% never frees one; the same work done again, processes and calls,
%% a socket, a host program, a file and an alarm, leaves the count as it
%% was. Written after the reading that found none; `make load` measures the
%% same at length (docs/memory_checks.md).
work_makes_no_atoms_test_() ->
    {timeout, 60, fun work_makes_no_atoms/0}.

work_makes_no_atoms() ->
    Dir = ern_program:scratch(),
    {ok, Output} = ern_program:run([
        "type Msg = Tick(Int) | Ended(Down)\n"
        "foreign fn info(k : Foreign.Term) : Int = \"erlang:system_info/1\"\n"
        "fn work() : Unit receiving Msg = {\n"
        "    let w = spawn(fn() : Unit receiving Int = receive { _ -> Unit });\n"
        "    monitor(Process.fromAddress(w), Ended);\n"
        "    kill(Process.fromAddress(w));\n"
        "    receive { Ended(_) -> Unit };\n"
        "    let _ = Clock.alarm(1, Tick);\n"
        "    receive { Tick(_) -> Unit };\n"
        "    let _ = Os.run(Os.command(\"true\", []), 5000);\n"
        "    let _ = Fs.write(Path(\"", Dir, "/f\"), <<1>>, 1000);\n"
        "    let _ = Fs.read(Path(\"", Dir, "/f\"), 1000);\n"
        "    match Tcp.listen(\"127.0.0.1\", 0) {\n"
        "        Right(l) -> Tcp.closeListener(l)\n"
        "      | Left(_) -> Unit\n"
        "    }\n"
        "}\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    work();\n"
        "    let before = info(Foreign.atom(\"atom_count\"));\n"
        "    work();\n"
        "    work();\n"
        "    Io.println(Io.show(info(Foreign.atom(\"atom_count\")) - before))\n"
        "}\n"]),
    ok = file:del_dir_r(Dir),
    ?assertEqual(<<"0\n">>, Output).

%% report §8.4, §12.3: a type variable of a foreign function's result that no
%% parameter names matches no value, so a return that holds one faults, and
%% an empty list of it passes, as does a value of a foreign type over it,
%% which the check does not look into; a function given to foreign code has
%% the arguments it is called with checked. A regression test: the first was
%% an unchecked cast, and the second let any value in;
%% the foreign type's case was written after the code
foreign_casts_and_callbacks_test() ->
    ResultOf = fun(Declaration, Body) ->
                   {Result, _} = ern_program:run(Declaration ++ "export fn main() : Unit = {\n"
                                                 "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                   Result
               end,
    ?assertEqual(return_cause("erlang:abs/1", "a", "is 1"),
                 cause_of(ResultOf("foreign fn cast(n : Int) : a =\n    \"erlang:abs/1\"\n",
                                   "cast(1) + 1"))),
    ?assertEqual(ok, ResultOf("foreign fn none(xs : List(Int)) : List(a) =\n    \"erlang:tl/1\"\n",
                              "List.size(none([1]))")),
    ?assertEqual(ok, ResultOf("foreign type Handle(a)\n"
                              "foreign fn handle() : Handle(a) =\n    \"erlang:make_ref/0\"\n",
                              "handle()")),
    ?assertMatch({fault, <<"an argument of M.main from foreign code does not match Int">>, _},
                 ResultOf("foreign fn each(f : (Int) -> Int, xs : List(String)) : List(Int) =\n"
                          "    \"lists:map/2\"\n", "each(fn(n) = n + 1, [\"x\"])")).

%% report §12.3, §8.4: a cause names the function. An argument foreign code
%% calls a function of the program's with that does not match names the
%% function as a caller writes it, `Main.handler`, another module's,
%% `Int.toString`, and a top-level `let` bound to a lambda, `Main.bound`;
%% a lambda or a local fn by the top-level declaration it is written in,
%% `Main.main`, and a lambda inside a top-level binding's value, a tuple's,
%% `Main.paired`, as a trace names its frame (Appendix E.21); a function
%% foreign code gave that a top-level binding holds, given back, by the
%% binding, `Main.given`. A function value foreign code gave names itself
%% as the host does, its return that does not match and an exception it
%% raises alike, as a foreign function's.
%%
%% A regression test, written after the code, but for the lambda inside a
%% tuple, written with each initializer's function of its own, before which
%% it kept the host's name; it does not cover a function foreign code gave
%% and was given back that no binding holds, which is named by the wrapper
%% the boundary made
function_named_in_cause_test() ->
    Each = "foreign fn each(f : (Int) -> Int, xs : List(String)) : List(Int) = \"lists:map/2\"\n"
           "foreign fn strings(f : (Int) -> String, xs : List(String)) : List(String) =\n"
           "    \"lists:map/2\"\n"
           "fn handler(n : Int) : Int = n + 1\n"
           "let bound = fn(n : Int) = n + 2\n"
           "let paired = #(fn(n : Int) = n + 3, 1)\n"
           "foreign fn made(module : Foreign.Term, function : Foreign.Term, arity : Int)\n"
           "    : (Int) -> Int = \"erlang:make_fun/3\"\n"
           "let given = made(Foreign.atom(\"erlang\"), Foreign.atom(\"abs\"), 1)\n",
    Cause = fun(Body) ->
                {{fault, Faulted, _}, _} =
                    ern_program:run(['Main'], Each ++ "export fn main() : Unit = {\n" ++ Body
                                              ++ "    Unit\n}\n", #{}),
                Faulted
            end,
    Argument = fun(Name) ->
                   iolist_to_binary(["an argument of ", Name,
                                     " from foreign code does not match Int"])
               end,
    ?assertEqual(Argument("Main.handler"), Cause("    let _ = each(handler, [\"x\"]);\n")),
    ?assertEqual(Argument("Int.toString"), Cause("    let _ = strings(Int.toString, [\"x\"]);\n")),
    ?assertEqual(Argument("Main.bound"), Cause("    let _ = each(bound, [\"x\"]);\n")),
    ?assertEqual(Argument("Main.paired"), Cause("    let #(inPair, _) = paired;\n"
                                                "    let _ = each(inPair, [\"x\"]);\n")),
    ?assertEqual(Argument("Main.given"), Cause("    let _ = each(given, [\"x\"]);\n")),
    ?assertEqual(Argument("Main.main"), Cause("    let _ = each(fn(n) = n * 2, [\"x\"]);\n")),
    ?assertEqual(Argument("Main.main"), Cause("    fn local(n : Int) : Int = n * 3;\n"
                                              "    let _ = each(local, [\"x\"]);\n")),
    Made = fun(Type, Function, Call) ->
               {{fault, Faulted, _}, _} =
                   ern_program:run(
                       ['Main'], "foreign fn made(module : Foreign.Term, function : Foreign.Term,"
                                 " arity : Int)\n"
                                 "    : " ++ Type ++ " = \"erlang:make_fun/3\"\n"
                                 "export fn main() : Unit = {\n"
                                 "    let f = made(Foreign.atom(\"erlang\"), Foreign.atom(\""
                                 ++ Function ++ "\"), 1);\n"
                                 "    Io.println(Io.show(" ++ Call ++ "))\n"
                                 "}\n", #{}),
               Faulted
           end,
    ?assertEqual(return_cause("erlang:abs/1", "String", "is 3"),
                 Made("(Int) -> String", "abs", "f(-3)")),
    ?assertEqual(<<"foreign function erlang:binary_to_integer/1 raised error:badarg">>,
                 Made("(String) -> Int", "binary_to_integer", "f(\"x\")")).

%% report §8.4: a type variable a parameter's type names matches any value at
%% the boundary, in a foreign function's result and in an argument foreign
%% code calls a function with. A regression test of what the report states
foreign_type_variables_unchecked_test() ->
    ResultOf = fun(Declaration, Body) ->
                   {Result, _} = ern_program:run(Declaration ++ "export fn main() : Unit = {\n"
                                                 "    let _ = " ++ Body ++ ";\n    Unit\n}\n"),
                   Result
               end,
    ?assertEqual(ok, ResultOf("foreign fn weird(x : a) : a =\n    \"erlang:length/1\"\n",
                              "weird([1, 2])")),
    ?assertEqual(ok, ResultOf("foreign fn each(f : (a) -> Int, x : a) : List(Int) =\n"
                              "    \"lists:map/2\"\n", "each(fn(_) = 1, [[\"x\"]])")).

%% report §6.9, §6.6: a callee's own answer to a call is not overtaken by
%% its end, so a worker that answers and returns at once is answered, every
%% time. A regression test of what the report states;
%% the order of a `Down` and the ended process's own messages is not
%% promised, and so not tested
answer_before_end_test() ->
    {ok, Output} = ern_program:run(
        "fn worker() : Unit receiving Reply(Int) = receive { r -> answer(r, 7) }\n"
        "fn rounds(n : Int, sum : Int) : Int =\n"
        "    if n == 0 then sum\n"
        "    else rounds(n - 1, sum + Address.callForever(spawn(worker), fn(r) = r))\n"
        "export fn main() : Unit = Io.println(Int.toString(rounds(200, 0)))\n"),
    ?assertEqual(<<"1400\n">>, Output).

%% report §8.4: an address foreign code gives back is the program's own at
%% the type it went out at, and foreign at another, so that what is sent
%% through it is checked against the process's own type. A regression test:
%% the proxy was undone whatever the type it came back at, and a String
%% reached a process of Int. The first target's end is
%% waited for, so that its line is written before the program ends
retyped_address_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Ended(Down)\n"
        "fn target() : Unit receiving Int = receive { n -> Io.println(\"got \" <>"
        " Int.toString(n)) }\n"
        "foreign fn retyped(addresses : List(Address(Int))) : Address(String) =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn same(addresses : List(Address(Int))) : Address(Int) =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let kept = spawnMonitored(target, Ended);\n"
        "    send(same([kept]), 5);\n"
        "    receive { Ended(_) -> Unit };\n"
        "    let wronged = spawnMonitored(target, Ended);\n"
        "    send(retyped([wronged]), \"x\");\n"
        "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
        "}\n"),
    ?assertEqual(<<"got 5\nFault(\"message does not match Int\")\n">>, Output).

%% report §8.4, §6.4: an address of a recursive type that crosses into
%% foreign code alone and inside a message of its type is one address with
%% one check, so the notes foreign code sends in turn through the two
%% arrive in the order sent. Written before its code, and red there: each
%% crossing had a check of its own, and the notes arrived out of order
recursive_address_in_order_test() ->
    ?assertEqual({ok, <<"true\n">>}, ern_program:run(
        "type QMsg = QNote(Int) | Carry(Address(QMsg))\n" ++ foreign_sent() ++
        "foreign fn alone(addresses : List(Address(QMsg))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn inside(index : Int, message : QMsg) : Foreign.Term =\n"
        "    \"erlang:element/2\"\n"
        "fn arrived(notes : List(Int), count : Int) : List(Int) receiving QMsg =\n"
        "    if count == 0 then List.reverse(notes)\n"
        "    else receive { QNote(note) -> arrived(note :: notes, count - 1) }\n"
        "export fn main() : Unit receiving QMsg = {\n"
        "    let first = alone([self()]);\n"
        "    let second = inside(2, Carry(self()));\n"
        "    List.forEach(List.range(1, 50), fn(index) = {\n"
        "        let _ = sent(first, Foreign.term(QNote(2 * index - 1)));\n"
        "        let _ = sent(second, Foreign.term(QNote(2 * index)));\n"
        "        Unit\n"
        "    });\n"
        "    Io.println(Io.show(arrived([], 100) == List.range(1, 100)))\n"
        "}\n")).

%% report §8.4, §8.7: "there is one for each distinct address that has
%% crossed, at each type it crossed at", a type the type an address crossed
%% at where the two have one hash: an address of a recursive type crosses
%% alone, inside a value of its own type and inside a value of another type
%% of the program's as one check, and foreign code is given one address.
%% Written before its code, and red there inside the other type, whose
%% descriptor numbered the recursion by the types around it
recursive_address_checked_once_test() ->
    ?assertEqual({ok, <<"#(true, true)\n">>}, ern_program:run(
        queue_declarations() ++
        "export fn main() : Unit receiving QMsg = {\n"
        "    let alone = listed([self()]);\n"
        "    let carried = fieldOfCarry(2, Carry(self()));\n"
        "    let entered = fieldOfEntry(2, Entry(self()));\n"
        "    Io.println(Io.show(#(alone == carried, alone == entered)))\n"
        "}\n")).

%% report §8.4: "An address of the program's that foreign code gives back is
%% the program's own at the type it crossed at": an address of a recursive
%% type that went out alone comes back inside a value of its own type and of
%% another type as the program's own, and one that went out inside either
%% comes back alone so. Written before its code, and red there through the
%% other type, where it came back foreign
recursive_address_back_as_its_own_test() ->
    ?assertEqual({ok, <<"#(true, true, true, true)\n">>}, ern_program:run(
        queue_declarations() ++
        "foreign fn asCarry(parts : List(Foreign.Term)) : QMsg =\n"
        "    \"erlang:list_to_tuple/1\"\n"
        "foreign fn asEntry(parts : List(Foreign.Term)) : Entry =\n"
        "    \"erlang:list_to_tuple/1\"\n"
        "foreign fn asAlone(terms : List(Foreign.Term)) : Address(QMsg) =\n"
        "    \"erlang:hd/1\"\n" ++ foreign_identical() ++
        "export fn main() : Unit receiving QMsg = {\n"
        "    let alone = listed([self()]);\n"
        "    let inCarry = match asCarry([Foreign.atom(\"Carry\"), alone]) {\n"
        "        Carry(address) -> identical(address, self())\n"
        "      | QNote(_) -> false\n"
        "    };\n"
        "    let Entry(entered) = asEntry([Foreign.atom(\"Entry\"), alone]);\n"
        "    let fromCarry = asAlone([fieldOfCarry(2, Carry(self()))]);\n"
        "    let fromEntry = asAlone([fieldOfEntry(2, Entry(self()))]);\n"
        "    Io.println(Io.show(#(inCarry, identical(entered, self()),\n"
        "                         identical(fromCarry, self()), identical(fromEntry, self()))))\n"
        "}\n")).

%% `type QMsg = QNote(Int) | Carry(Address(QMsg))`, a type that holds an
%% address of it, `Entry`, and foreign functions that give foreign code an
%% address of it alone, inside a QMsg and inside an Entry.
queue_declarations() ->
    "type QMsg = QNote(Int) | Carry(Address(QMsg))\n"
    "type Entry = Entry(Address(QMsg))\n"
    "foreign fn listed(addresses : List(Address(QMsg))) : Foreign.Term =\n"
    "    \"erlang:hd/1\"\n"
    "foreign fn fieldOfCarry(index : Int, message : QMsg) : Foreign.Term =\n"
    "    \"erlang:element/2\"\n"
    "foreign fn fieldOfEntry(index : Int, entry : Entry) : Foreign.Term =\n"
    "    \"erlang:element/2\"\n".

%% A foreign function given two values at type variables, which cross as
%% the runtime holds them (report §8.4), whether they are one term.
foreign_identical() ->
    "foreign fn identical(given : a, own : b) : Bool =\n"
    "    \"ern_emitter_tests:identical/2\"\n".

%% report §8.4, §8.7: an address that crosses from two modules at one type
%% is one check, where its message type holds an address of a type one
%% module writes `Note` and the other `Kept.Note`. Written before its code,
%% and red there: each module's crossing had a check of its own, its
%% descriptor holding the nested address's cause as its module prints it
address_from_two_modules_checked_once_test() ->
    ?assertEqual({ok, <<"true\n">>}, crossed_from_two_modules(kept_module(), "KeptMsg")).

%% report §8.4, §8.7: the same where the message type holds a function.
%% Written before its code, and red there: each module's crossing had a
%% check of its own, its descriptor holding two funs of its unit's code
function_field_from_two_modules_checked_once_test() ->
    ?assertEqual({ok, <<"true\n">>}, crossed_from_two_modules(
        "export type TaskMsg = Task(() -> Int) | Count(Int)\n"
        "export fn handedAlone(address : Address(TaskMsg)) : Foreign.Term =\n"
        "    listed([address])\n"
        "foreign fn listed(addresses : List(Address(TaskMsg))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n",
        "TaskMsg")).

%% Whether foreign code is given one address for the process of main, whose
%% mailbox type is Kept's Message, by a crossing of the module Kept, its
%% handedAlone, and one of main's module.
crossed_from_two_modules(Kept, Message) ->
    ern_program:run_modules(
      [{['Kept'], Kept},
       {['Main'],
        "foreign fn listed(addresses : List(Address(Kept." ++ Message ++ "))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit receiving Kept." ++ Message ++ " = {\n"
        "    let here = listed([self()]);\n"
        "    let there = Kept.handedAlone(self());\n"
        "    Io.println(Io.show(here == there))\n"
        "}\n"}]).

%% report §8.4: an address that went out through one module's crossing comes
%% back through the other module's, at the type it crossed at, as the
%% program's own. Written before its code, and red there: it came back
%% foreign each way
address_from_two_modules_back_as_its_own_test() ->
    ?assertEqual({ok, <<"#(true, true)\n">>}, ern_program:run_modules(
        [{['Kept'], kept_module()},
         {['Main'],
          kept_listed() ++
          "foreign fn asAlone(terms : List(Foreign.Term)) : Address(Kept.KeptMsg) =\n"
          "    \"erlang:hd/1\"\n" ++ foreign_identical() ++
          "export fn main() : Unit receiving Kept.KeptMsg = {\n"
          "    let fromKept = asAlone([Kept.handedAlone(self())]);\n"
          "    let fromHere = Kept.back(listed([self()]));\n"
          "    Io.println(Io.show(#(identical(fromKept, self()), identical(fromHere, self()))))\n"
          "}\n"}])).

%% report §6.4, §8.4: what foreign code sends in turn through one address,
%% given it by two modules' crossings, arrives in the order sent. Written
%% before its code, and red there: each crossing had a check of its own,
%% and the counts arrived out of order
address_from_two_modules_in_order_test() ->
    ?assertEqual({ok, <<"true\n">>}, ern_program:run_modules(
        [{['Kept'], kept_module()},
         {['Main'],
          kept_listed() ++ foreign_sent() ++
          "fn arrived(numbers : List(Int), count : Int) : List(Int) receiving Kept.KeptMsg =\n"
          "    if count == 0 then List.reverse(numbers)\n"
          "    else receive { Kept.Count(number) -> arrived(number :: numbers, count - 1) }\n"
          "export fn main() : Unit receiving Kept.KeptMsg = {\n"
          "    let here = listed([self()]);\n"
          "    let there = Kept.handedAlone(self());\n"
          "    List.forEach(List.range(1, 50), fn(index) = {\n"
          "        let _ = sent(here, Foreign.term(Kept.Count(2 * index - 1)));\n"
          "        let _ = sent(there, Foreign.term(Kept.Count(2 * index)));\n"
          "        Unit\n"
          "    });\n"
          "    Io.println(Io.show(arrived([], 100) == List.range(1, 100)))\n"
          "}\n"}])).

%% report §12.3: a message that does not match through a check two modules'
%% crossings share faults the receiver with the type written whole from
%% the root, whichever module's crossing made the check, in either order
%% of crossing. Written before its code, and red there: each crossing had a
%% check of its own, which printed the type as its own module does
shared_check_cause_test() ->
    Faulted = fun(First, Second) ->
                  {Result, _} = ern_program:run_modules(
                    [{['Kept'], kept_module()},
                     {['Main'],
                      kept_listed() ++ foreign_sent() ++
                      "export fn main() : Unit receiving Kept.KeptMsg = {\n"
                      "    let _ = " ++ First ++ ";\n"
                      "    let second = " ++ Second ++ ";\n"
                      "    let _ = sent(second, Foreign.term(\"no message\"));\n"
                      "    receive { _ -> Unit }\n"
                      "}\n"}]),
                  cause_of(Result)
              end,
    ?assertEqual({<<"message does not match Kept.KeptMsg">>,
                  <<"message does not match Kept.KeptMsg">>},
                 {Faulted("Kept.handedAlone(self())", "listed([self()])"),
                  Faulted("listed([self()])", "Kept.handedAlone(self())")}).

%% A module Kept whose mailbox type holds an address of another of its
%% types, which gives foreign code an address of it, and takes one back.
kept_module() ->
    "export type Note = Note(Int)\n"
    "export type KeptMsg = Hand(Address(Note)) | Count(Int)\n"
    "export fn handedAlone(address : Address(KeptMsg)) : Foreign.Term =\n"
    "    listed([address])\n"
    "export fn back(term : Foreign.Term) : Address(KeptMsg) =\n"
    "    asAlone([term])\n"
    "foreign fn listed(addresses : List(Address(KeptMsg))) : Foreign.Term =\n"
    "    \"erlang:hd/1\"\n"
    "foreign fn asAlone(terms : List(Foreign.Term)) : Address(KeptMsg) =\n"
    "    \"erlang:hd/1\"\n".

%% Another module's foreign function that gives foreign code an address of
%% Kept's mailbox type.
kept_listed() ->
    "foreign fn listed(addresses : List(Address(Kept.KeptMsg))) : Foreign.Term =\n"
    "    \"erlang:hd/1\"\n".

%% report §8.4: "once every type variable in each is written as the same
%% variable": an address that crosses at `Address(a)` and at `Address(b)`
%% is one check, and so is one that crosses at `Address(#(a, b))` and at
%% `Address(#(a, a))`, each of which takes any message of its shape; one
%% that crosses at `Address(a)` and at `Address(PingMsg)` is two. A
%% regression test of what the report states
address_at_type_variables_test() ->
    ?assertEqual({ok, <<"#(true, true, false)\n">>}, ern_program:run(
        "type PingMsg = Ping(Int)\n"
        "fn pairs() : Unit receiving #(Int, Int) =\n"
        "    receive { #(left, right) -> Io.println(Int.toString(left + right)) }\n"
        "foreign fn atA(addresses : List(Address(a))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn atB(addresses : List(Address(b))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn atPair(addresses : List(Address(#(a, b)))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn atSame(addresses : List(Address(#(a, a)))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn atPing(addresses : List(Address(PingMsg))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit receiving PingMsg = {\n"
        "    let pair = spawn(pairs);\n"
        "    Io.println(Io.show(#(atA([self()]) == atB([self()]),\n"
        "                         atPair([pair]) == atSame([pair]),\n"
        "                         atA([self()]) == atPing([self()]))))\n"
        "}\n")).

%% report §8.4, §8.7: "the program's own at the type it crossed at, and
%% foreign at any other": an address whose type's recursion passes through
%% the type around it, `B(a) = B1(a) | B2(Address(B(a)))` of a module Z,
%% that crosses inside `X.T = TB(Z.B(T)) | TN`, comes back inside an `X.T`
%% as the program's own and inside a `Y.T`, declared the same, as foreign.
%% A regression test of what the report states
recursive_address_foreign_through_another_type_test() ->
    Around = "export type T = TB(Z.B(T)) | TN\n",
    ?assertEqual({ok, <<"#(true, false)\n">>}, ern_program:run_modules(
        [{['Z'], "export type B(a) = B1(a) | B2(Address(B(a)))\n"},
         {['X'], Around},
         {['Y'], Around},
         {['Main'],
          "foreign fn fieldOf(index : Int, value : X.T) : Foreign.Term =\n"
          "    \"erlang:element/2\"\n"
          "foreign fn asX(parts : List(Foreign.Term)) : X.T =\n"
          "    \"erlang:list_to_tuple/1\"\n"
          "foreign fn asY(parts : List(Foreign.Term)) : Y.T =\n"
          "    \"erlang:list_to_tuple/1\"\n" ++ foreign_identical() ++
          "export fn main() : Unit receiving Z.B(X.T) = {\n"
          "    let inner = fieldOf(2, X.TB(Z.B2(self())));\n"
          "    let same = match asX([Foreign.atom(\"TB\"), inner]) {\n"
          "        X.TB(Z.B2(address)) -> identical(address, self())\n"
          "      | _ -> false\n"
          "    };\n"
          "    let other = match asY([Foreign.atom(\"TB\"), inner]) {\n"
          "        Y.TB(Z.B2(address)) -> identical(address, self())\n"
          "      | _ -> false\n"
          "    };\n"
          "    Io.println(Io.show(#(same, other)))\n"
          "}\n"}])).

%% report §8.4, §8.7: a type's hash holds its arguments where its descriptor
%% does not, so an address that crossed at `Address(Tagged(Int))`, of `type
%% Tagged(a) = Tagged(Int)`, comes back as the program's own there and
%% foreign at `Address(Tagged(String))`. Written before its code, and red
%% there: it came back as the program's own at either
phantom_argument_foreign_test() ->
    ?assertEqual({ok, <<"#(true, false)\n">>}, ern_program:run(
        "type Tagged(a) = Tagged(Int)\n"
        "foreign fn atInt(addresses : List(Address(Tagged(Int)))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn backAtInt(terms : List(Foreign.Term)) : Address(Tagged(Int)) =\n"
        "    \"erlang:hd/1\"\n"
        "foreign fn backAtString(terms : List(Foreign.Term)) : Address(Tagged(String)) =\n"
        "    \"erlang:hd/1\"\n" ++ foreign_identical() ++
        "export fn main() : Unit receiving Tagged(Int) = {\n"
        "    let crossed = atInt([self()]);\n"
        "    Io.println(Io.show(#(identical(backAtInt([crossed]), self()),\n"
        "                         identical(backAtString([crossed]), self()))))\n"
        "}\n")).

%% report §8.4, Appendix H: a type at a crossing in a definition of the
%% group of the type it names, the type's own `compare`, names the type as
%% every other definition does, by its hash, so the address that crosses
%% there and in `main` is one check. A regression test of what the report
%% states
group_member_crossing_checked_once_test() ->
    ?assertEqual({ok, <<"true\n">>}, ern_program:run(
        "type CountMsg = Ranked(rank : Int, owner : Address(CountMsg)) | Seen(Foreign.Term)\n"
        "fn CountMsg.compare(left : CountMsg, right : CountMsg) : Ordering =\n"
        "    match left {\n"
        "        Ranked(=owner) -> {\n"
        "            send(owner, Seen(Foreign.term(owner)));\n"
        "            Equal\n"
        "        }\n"
        "      | Seen(_) -> Equal\n"
        "    }\n"
        "foreign fn listed(addresses : List(Address(CountMsg))) : Foreign.Term =\n"
        "    \"erlang:hd/1\"\n"
        "export fn main() : Unit receiving CountMsg = {\n"
        "    let here = listed([self()]);\n"
        "    let _ = Ranked(rank = 1, owner = self()) < Ranked(rank = 2, owner = self());\n"
        "    receive { Seen(there) -> Io.println(Io.show(here == there)) }\n"
        "}\n")).

%% report §8.4: a process of the program's whose address foreign code was
%% never given is a bad value where foreign code gives it as an address: its
%% own `self()` in a foreign function, and a `Process` it was given, but as
%% an `Address(Never)`, through which nothing passes; an address that
%% crossed comes back as the program's own at its type. A regression test:
%% each was the program's own at whatever type foreign code named, and a
%% String reached a process of Int
never_given_address_test() ->
    Program = fun(Forged) ->
                  "foreign fn me() : Address(String) =\n"
                  "    \"erlang:self/0\"\n"
                  "foreign fn retyped(processes : List(Process)) : Address(String) =\n"
                  "    \"erlang:hd/1\"\n"
                  "foreign fn same(addresses : List(Address(Int))) : Address(Int) =\n"
                  "    \"erlang:hd/1\"\n"
                  "export fn main() : Unit receiving Int = {\n"
                  "    send(same([self()]), 5);\n"
                  "    receive { n -> Io.println(Int.toString(n)) };\n"
                  "    send(" ++ Forged ++ ", \"x\")\n"
                  "}\n"
              end,
    Refused = fun(Call, Named) ->
                  {Result, Output} = ern_program:run(Program(Call)),
                  ?assertEqual(<<"5\n">>, Output),
                  ?assertEqual({match, [<<"is <">>]},
                               re:run(cause_of(Result),
                                      ["^the return of foreign function \\Q", Named,
                                       "\\E does not match Address\\(String\\): (is <)"],
                                      [{capture, all_but_first, binary}]))
              end,
    Refused("me()", "erlang:self/0"),
    Refused("retyped([Process.fromAddress(self())])", "erlang:hd/1"),
    ?assertEqual({ok, <<"true\n">>},
                 ern_program:run(
                     "foreign fn handle() : Address(Never) =\n"
                     "    \"erlang:self/0\"\n"
                     "export fn main() : Unit receiving Int =\n"
                     "    Io.println(Bool.toString(Process.fromAddress(handle())\n"
                     "                             == Process.fromAddress(self())))\n")).

%% report §8.4, §6.9: a foreign message that does not match takes its place
%% in the receiver's mailbox as a fault, which lands at the wait that
%% reaches it, in a `receive` or for a call's answer, as a fault of the
%% receiver's own, so that `restarting` restarts it until its limit. A
%% regression test: the fault came as an exit signal, which ended the
%% process whatever wrapped it, at its first run
foreign_fault_restarts_test() ->
    Common = "type Msg = Ended(Down)\n"
             "type Hold = Hold(reply : Reply(Int))\n"
             "foreign fn retyped(addresses : List(Address(Int))) : Address(String) =\n"
             "    \"erlang:hd/1\"\n"
             "fn holder(held : List(Reply(Int))) : Unit receiving Hold =\n"
             "    receive { Hold(reply = r) -> holder(r :: held) }\n",
    Main = fun(Run) ->
                   "export fn main() : Unit receiving Msg = {\n"
                   "    let h = spawn(fn() = holder([]));\n"
                   "    let limit = RestartLimit(restarts = 2, within = 60000);\n"
                   "    let _ = spawnMonitored(restarting(limit, fn() = " ++ Run ++ "), Ended);\n"
                   "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
                   "}\n"
           end,
    Expected = <<"run\nrun\nrun\nFault(\"message does not match Int\")\n">>,
    %% at a receive
    ?assertEqual({ok, Expected},
                 ern_program:run(Common ++
                                 "fn wait(h : Address(Hold)) : Unit receiving Int = {\n"
                                 "    Io.println(\"run\");\n"
                                 "    send(retyped([self()]), \"x\");\n"
                                 "    receive { n -> Io.println(Int.toString(n)) }\n"
                                 "}\n" ++ Main("wait(h)"))),
    %% at a call's wait, which nothing else would end
    ?assertEqual({ok, Expected},
                 ern_program:run(Common ++
                                 "fn ask(h : Address(Hold)) : Unit receiving Int = {\n"
                                 "    Io.println(\"run\");\n"
                                 "    send(retyped([self()]), \"x\");\n"
                                 "    Io.println(Int.toString(Address.callForever(h,"
                                 " fn(r) = Hold(reply = r))))\n"
                                 "}\n" ++ Main("ask(h)"))).

%% report §8.4, §6.5, Appendix E.21: an adapted address that crossed into
%% foreign code on the node that made it has its function applied as on
%% arrival, in the checker, which acts for the target: `Process.current()`
%% in the function is the target, and `self()` the target's address, the
%% process `Process.fromAddress` gives for it
checker_acts_for_the_target_test() ->
    ?assertEqual({ok, <<"#(true, true)\n">>}, ern_program:run(
        "type MainMsg = Seen(current : Process, own : Process)\n" ++ foreign_sent() ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let seeing = adapted(self(), fn(_ : Int) : MainMsg =\n"
        "        Seen(current = Process.current(), own = Process.fromAddress(self())));\n"
        "    let _ = sent(Foreign.term(seeing), Foreign.term(1));\n"
        "    receive {\n"
        "        Seen(=current, =own) ->\n"
        "            Io.println(Io.show(#(current == Process.current(),"
        " own == Process.current())))\n"
        "    }\n"
        "}\n")).

%% report §8.4, §6.5, §6.9: a kill of `Process.current()` in the function a
%% checker applies ends the target, as the target's kill of itself does, and
%% nothing of the function after the kill is done
checker_kill_ends_the_target_test() ->
    Killed = {ok, <<"Killed\n">>},
    ?assertEqual(Killed, ern_program:run(checked_target("Unit", "{ kill(Process.current()); Stop }",
                                                        "Foreign.term(1)"))),
    ?assertEqual(Killed, ern_program:run(checked_target("kill(Process.current())", "Stop",
                                                        "Foreign.term(1)"))).

%% report §8.4, §6.9, §7.4: a restarting function called in the function a
%% checker applies faults before anything of a restart begins, and the
%% target meets the fault at its next wait
checker_refuses_a_restart_test() ->
    ?assertEqual({ok, <<"Fault(\"restart in a function the runtime applies\")\n">>},
                 ern_program:run(checked_target("Unit",
                                                "{\n"
                                                "        restarting(RestartLimit(restarts = 1,"
                                                " within = 60000), fn() = Unit)();\n"
                                                "        Stop\n"
                                                "    }", "Foreign.term(1)"))).

%% report §8.4: a check lasts until the process its address names ends, so
%% where foreign code ends the checker first, the reaper, which holds it,
%% takes its rows, and a later exposure of the same address at the same type
%% is checked by another checker, through which the message arrives
ended_checker_is_checked_again_test() ->
    ?assertEqual({ok, <<"Ping\n">>}, ern_program:run(
        "type MainMsg = Ping\n"
        "foreign fn ended(checker : Foreign.Term) : Unit =\n"
        "    \"ern_emitter_tests:checker_ended/1\"\n" ++ foreign_sent() ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    ended(Foreign.term(self()));\n"
        "    let _ = sent(Foreign.term(self()), Foreign.atom(\"Ping\"));\n"
        "    receive { Ping -> Io.println(\"Ping\") }\n"
        "}\n")).

%% report §8.4, §6.5, §12.3: a message foreign code sends to an adapted
%% address is checked against the type the address crossed at before its
%% function is applied, so a bad one faults the target with the check's
%% cause, which names that type, and the function, which would fault with a
%% cause of its own, is not applied. A regression test, written after the
%% code
checked_before_applied_test() ->
    ?assertEqual({ok, <<"Fault(\"message does not match Int\")\n">>},
                 ern_program:run(
                     checked_target("Unit", "fault(\"applied\")", "Foreign.atom(\"junk\")"))).

%% report §8.4, §6.5: a function that runs in the checker as its target
%% ends runs on, as it does in a process kept for a peer's messages, and
%% the checker ends once it returns. The target ends while the function
%% waits in a call, which the gate answers only once main has the target's
%% Down; the function then tells main. A regression test, written after the
%% code; it does not cover what the checker does with a message that comes
%% after the target's Down
checker_runs_on_past_its_target_test() ->
    ?assertEqual({ok, <<"Returned\napplied\n">>}, ern_program:run(
        "type MainMsg = Ended(Down) | Applied\n" ++
        gating() ++ foreign_sent() ++
        "fn target(main : Address(MainMsg), gate : Address(GateMsg)) : Unit receiving Int = {\n"
        "    let applying = adapted(self(), fn(n : Int) : Int = {\n"
        "        Address.callForever(gate, Pass);\n"
        "        send(main, Applied);\n"
        "        n\n"
        "    });\n"
        "    let _ = sent(Foreign.term(applying), Foreign.term(1));\n"
        "    Unit\n"
        "}\n"
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let gate = spawn(gating);\n"
        "    let me = self();\n"
        "    let _ = spawnMonitored(fn() = target(me, gate), Ended);\n"
        "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) };\n"
        "    send(gate, Open);\n"
        "    receive { Applied -> Io.println(\"applied\") }\n"
        "}\n")).

%% report §8.4, §6.4: "Messages one process sends through one check are
%% received in sending order": a run foreign code sends from main through
%% one address it was given, main's own and then an adapted address of
%% main's, whose function the check's process applies, arrives in the order
%% sent. Written after the code, which held it already
check_keeps_sending_order_test() ->
    ?assertEqual({ok, <<"#(true, true)\n">>}, ern_program:run(
        "type RunMsg = Plain(Int) | Wrapped(Int)\n" ++ foreign_sent() ++
        "fn arrived(numbers : List(Int), count : Int) : List(Int) receiving RunMsg =\n"
        "    if count == 0 then List.reverse(numbers)\n"
        "    else receive {\n"
        "        Plain(number) -> arrived(number :: numbers, count - 1)\n"
        "      | Wrapped(number) -> arrived(number :: numbers, count - 1)\n"
        "    }\n"
        "fn sentRun(address : Foreign.Term, message : (Int) -> Foreign.Term) : Unit =\n"
        "    List.forEach(List.range(1, 1000), fn(index) = {\n"
        "        let _ = sent(address, message(index));\n"
        "        Unit\n"
        "    })\n"
        "export fn main() : Unit receiving RunMsg = {\n"
        "    sentRun(Foreign.term(self()), fn(index) = Foreign.term(Plain(index)));\n"
        "    let plain = arrived([], 1000) == List.range(1, 1000);\n"
        "    sentRun(Foreign.term(adapted(self(), Wrapped)), fn(index) = Foreign.term(index));\n"
        "    Io.println(Io.show(#(plain, arrived([], 1000) == List.range(1, 1000))))\n"
        "}\n")).

%% report §8.4, §6.4, §6.5: "a message it sends the same receiver after one
%% of them another way can pass it": a message foreign code sends main
%% through one address of main's is passed by one it sends after it through
%% another, main's own, since the first address's function, which its
%% check's process applies, waits on a gate that opens only once main has
%% taken the later message. Written after the code, which held it already
another_check_passes_a_checked_message_test() ->
    ?assertEqual({ok, <<"later earlier\n">>},
                 ern_program:run(gated_earlier("let _ = sent(Foreign.term(self()),"
                                               " Foreign.term(Later(2)))"))).

%% report §8.4, §6.4, §6.5: the same where main sends itself the later
%% message with `send` once the foreign function that sent the earlier one
%% has returned. Written after the code, which held it already
callers_send_passes_a_checked_message_test() ->
    ?assertEqual({ok, <<"later earlier\n">>}, ern_program:run(
        gated_earlier("send(self(), Later(2))"))).

%% report §8.4: "It need not be in its receiver's mailbox when the foreign
%% function that sent it has returned": a message foreign code sends main
%% through an adapted address whose function waits on a gate is not there
%% for a `receive` with `after 0` once the foreign function has returned,
%% and arrives once main opens the gate. Written after the code, which held
%% it already
checked_message_not_yet_placed_test() ->
    ?assertEqual({ok, <<"nothing\narrived 1\n">>}, ern_program:run(
        "type MainMsg = Earlier(Int)\n" ++ gating() ++ foreign_sent() ++
        "export fn main() : Unit receiving MainMsg = {\n"
        "    let gate = spawn(gating);\n"
        "    let held = adapted(self(), fn(n : Int) : MainMsg = {\n"
        "        Address.callForever(gate, Pass);\n"
        "        Earlier(n)\n"
        "    });\n"
        "    let _ = sent(Foreign.term(held), Foreign.term(1));\n"
        "    receive {\n"
        "        Earlier(_) -> Io.println(\"placed\")\n"
        "      | after 0 -> Io.println(\"nothing\")\n"
        "    };\n"
        "    send(gate, Open);\n"
        "    receive { Earlier(n) -> Io.println(\"arrived \" <> Int.toString(n)) }\n"
        "}\n")).

%% A program whose main has foreign code send `Earlier(1)` to it through an
%% adapted address whose function waits in a call to a gate, then does
%% SendLater, which sends it `Later(2)`, and opens the gate only once it has
%% taken a message; it prints the two messages' order of arrival.
gated_earlier(SendLater) ->
    "type MainMsg = Earlier(Int) | Later(Int)\n" ++
    gating() ++ foreign_sent() ++
    "fn arrival() : String receiving MainMsg = receive {\n"
    "    Earlier(_) -> \"earlier\"\n"
    "  | Later(_) -> \"later\"\n"
    "}\n"
    "export fn main() : Unit receiving MainMsg = {\n"
    "    let gate = spawn(gating);\n"
    "    let held = adapted(self(), fn(n : Int) : MainMsg = {\n"
    "        Address.callForever(gate, Pass);\n"
    "        Earlier(n)\n"
    "    });\n"
    "    let _ = sent(Foreign.term(held), Foreign.term(1));\n"
    "    " ++ SendLater ++ ";\n"
    "    let first = arrival();\n"
    "    send(gate, Open);\n"
    "    Io.println(first <> \" \" <> arrival())\n"
    "}\n".

%% A gate, a process that answers the call `Pass` only once it is sent
%% `Open`.
gating() ->
    "type GateMsg = Pass(Reply(Unit)) | Open\n"
    "fn gating() : Unit receiving GateMsg = receive {\n"
    "    Pass(reply) -> receive { Open -> answer(reply, Unit) }\n"
    "}\n".

%% A program whose target does Before and then gives foreign code an
%% adapted address of Int, whose function is Function, which foreign code
%% sends Message; main prints how the target ended.
checked_target(Before, Function, Message) ->
    "type TargetMsg = Stop\n"
    "type MainMsg = Ended(Down)\n" ++ foreign_sent() ++
    "fn target() : Unit receiving TargetMsg = {\n"
    "    " ++ Before ++ ";\n"
    "    let checked = adapted(self(), fn(_ : Int) : TargetMsg = " ++ Function ++ ");\n"
    "    let _ = sent(Foreign.term(checked), " ++ Message ++ ");\n"
    "    receive { Stop -> Io.println(\"Stop\") }\n"
    "}\n"
    "export fn main() : Unit receiving MainMsg = {\n"
    "    let _ = spawnMonitored(target, Ended);\n"
    "    receive { Ended(Down(reason = r)) -> Io.println(Io.show(r)) }\n"
    "}\n".

%% The declaration by which a program stands in for foreign code that sends
%% an address a message, as the host sends it.
foreign_sent() ->
    "foreign fn sent(to : Foreign.Term, message : Foreign.Term) : Foreign.Term =\n"
    "    \"erlang:send/2\"\n".

%% report §8.4, Appendix E.12: `Foreign.term` gives its value as a foreign
%% function's argument of the value's type crosses: an address goes behind
%% the proxy that faults its process on a message of another type, and a
%% function checks what foreign code calls it with, as each does given in
%% an argument of its own type. A value nothing in which crosses is the
%% value itself. A regression test: `Foreign.term` gave the address and the
%% function as the runtime held them, unchecked
foreign_from_crosses_as_an_argument_test() ->
    %% the fault the proxy sends takes the message's place; where none came,
    %% the program would end in a deadlock, which no case expects
    Main = "export fn main() : Unit receiving Int = {\n    let _ = ~s;\n"
           "    receive { _ -> Unit }\n}\n",
    Typed = "foreign fn rawSend(to : Address(Int), message : String) : String =\n"
            "    \"erlang:send/2\"\n",
    Untyped = "foreign fn rawSend(to : Foreign.Term, message : String) : String =\n"
              "    \"erlang:send/2\"\n",
    Applied = "foreign fn applied(f : Foreign.Term, arguments : List(String)) : Int =\n"
              "    \"erlang:apply/2\"\n",
    Program = fun(Declaration, Call) ->
                  Declaration ++ lists:flatten(io_lib:format(Main, [Call]))
              end,
    Fault = fun(Source) ->
                {{fault, Cause, _}, _} = ern_program:run(Source),
                Cause
            end,
    ?assertEqual(<<"message does not match Int">>,
                 Fault(Program(Typed, "rawSend(self(), \"x\")"))),
    ?assertEqual(<<"message does not match Int">>,
                 Fault(Program(Untyped, "rawSend(Foreign.term(self()), \"x\")"))),
    ?assertEqual(<<"an argument of M.main from foreign code does not match Int">>,
                 Fault(Program(Applied, "applied(Foreign.term(fn(n : Int) = n + 1), [\"x\"])"))),
    ?assertEqual({ok, <<"Some(42)\n">>},
                 ern_program:run("export fn main() : Unit =\n"
                                 "    Io.println(Io.show(Foreign.toInt(Foreign.term(42))))\n")).

%% report §8.5: a module the program does not depend on is not initialized,
%% though it is on the code path; a regression test for the shell's modules,
%% which every run initialized, before the standard library's
unrelated_module_not_initialized_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['Aside'],
        "let noisy = Io.debug(\"initialized\")\n"),
    {ok, ErlangModule, Beam} = ern_compile:compile(['Aside'], Typed, Interface, Env),
    Dir = ern_program:scratch(),
    ok = file:write_file(filename:join(Dir, atom_to_list(ErlangModule) ++ ".beam"), Beam),
    true = code:add_patha(Dir),
    try
        ?assertEqual({ok, <<"ran\n">>},
                     ern_program:run("export fn main() : Unit = Io.println(\"ran\")\n"))
    after
        code:del_path(Dir),
        code:purge(ErlangModule),
        code:delete(ErlangModule),
        file:del_dir_r(Dir)
    end.

%% report §10: a tail call takes constant stack space, through the branches
%% of an `if`, the clauses of a `match`, and the last expression of a block:
%% ten million calls run in a process whose heap, its stack counted, may not
%% pass a hundred thousand words
tail_calls_constant_stack_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "export fn count(n : Int, acc : Int) : Int =\n"
        "    if n == 0 then acc\n"
        "    else match n % 2 {\n"
        "        0 -> { let next = acc + 1; count(n - 1, next) }\n"
        "      | _ -> count(n - 1, acc + 1)\n"
        "    }\n"),
    {ok, ErlangModule, Beam} = ern_compile:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    Counting = ern_named:function(ErlangModule, count),
    {_, MonitorRef} = spawn_opt(fun() -> Self ! {counted, Counting(10000000, 0)} end,
                                [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                            error_logger => false}}]),
    Result = receive
                 {counted, Count} -> Count;
                 {'DOWN', MonitorRef, process, _, ExitReason} -> {died, ExitReason}
             end,
    ?assertEqual(10000000, Result).

%% report §10: the right operand of `&&` and `||`, and the call a pipe
%% makes, are in tail position where their expression is, and take constant
%% stack space as the test above measures it. A regression test, written
%% after the report stated it: the emitter gave these the host's own tail
%% calls from the start
tail_calls_through_operators_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'],
        "export fn all(n : Int) : Bool =\n"
        "    n == 0 || (n > 0 && all(n - 1))\n"
        "export fn down(n : Int) : Int =\n"
        "    if n == 0 then 0 else n - 1 |> down\n"),
    {ok, ErlangModule, Beam} = ern_compile:compile(['M'], Typed, Interface, Env),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    Self = self(),
    OutcomeOf = fun(Function) ->
                    {_, MonitorRef} =
                        spawn_opt(fun() -> Self ! {ran, Function()} end,
                                  [monitor, {max_heap_size, #{size => 100000, kill => true,
                                                              error_logger => false}}]),
                    receive
                        {ran, Value} -> Value;
                        {'DOWN', MonitorRef, process, _, ExitReason} -> {died, ExitReason}
                    end
                end,
    All = ern_named:function(ErlangModule, all),
    Down = ern_named:function(ErlangModule, down),
    ?assertEqual(true, OutcomeOf(fun() -> All(10000000) end)),
    ?assertEqual(0, OutcomeOf(fun() -> Down(10000000) end)).

%% report §6.9, §9.3: a `Down` names the process behind the address
%% monitored, through an adapted address, as `Process.fromAddress` gives it
down_names_its_process_test() ->
    {ok, Output} = ern_program:run(
        "type Msg = Died(Down) | Go\n"
        "export fn main() : Unit receiving Msg = {\n"
        "    let w = spawnMonitored(fn() = Unit, Died);\n"
        "    let first = receive { Died(d) -> d.process == Process.fromAddress(w) };\n"
        "    let v = spawn(fn() : Unit receiving Msg = receive { Go -> Unit });\n"
        "    monitor(Process.fromAddress(adapted(v, fn(u : Unit) = Go)), Died);\n"
        "    send(v, Go);\n"
        "    let second = receive { Died(d) -> d.process == Process.fromAddress(v) };\n"
        "    Io.println(Io.show(#(first, second)))\n"
        "}\n"),
    ?assertEqual(<<"#(true, true)\n">>, Output).

%% report §8.2, §9.7, §11.5: a system reference is private to its module,
%% refused as the binding its module keeps private, and the prelude binds
%% none, so a program names neither `Io.stdout` nor `Sys.stdout`, and a
%% system module's message is not a program's to make
system_reference_private_test() ->
    Refused = fun(Main) ->
                  ern_typecheck:check_string(['M'],
                                             "export fn main() : Unit = "
                                             ++ Main ++ "\n")
              end,
    %% each refused for the reason the test names, not another; a
    %% regression test of the test, which took any error
    ?assertMatch({error, [#diagnostic{message = "Io.stdout is a binding Io keeps private"} | _]},
                 Refused("send(Io.stdout, String.toUtf8(\"hi\"))")),
    ?assertMatch({error, [#diagnostic{message = "unknown name Sys.stdout"} | _]},
                 Refused("send(Sys.stdout, \"hi\")")),
    ?assertMatch({error, [#diagnostic{message = "unknown constructor Clock.Now"} | _]},
                 Refused("{ let _ = Clock.Now; Unit }")).

%% report §8.5: a compiled module declares the modules it depends on, as
%% `'$deps'/0`, so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file; a module that
%% depends on none declares none
deps_test() ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(['M'], "export let one = 1\n"),
    Build = #{source_hash => <<>>, deps => [{['Net', 'Http'], <<"hash">>}]},
    {ok, ErlangModule, Beam} = ern_compile:compile(['M'], Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    ?assert(erlang:function_exported(ErlangModule, '$deps', 0)),
    ?assertEqual(['ern@net@http'], ErlangModule:'$deps'()),
    {ok, Typed2, Interface2, Env2} = ern_typecheck:check_string(['N'], "export let one = 1\n"),
    {ok, ErlangModule2, Beam2} = ern_compile:compile(['N'], Typed2, Interface2, Env2),
    {module, ErlangModule2} = code:load_binary(ErlangModule2, "test", Beam2),
    ?assertNot(erlang:function_exported(ErlangModule2, '$deps', 0)).

%% report §8.5: the top-level lets run in the order the checker's
%% let_order/1 gives, which takes no name a function's pattern binds for a
%% reference to the `let` of its name. A regression test: a program like
%% this once crashed the emitter, whose own order of the lets took it so
shadowed_name_in_init_order_test() ->
    ?assertEqual({ok, <<"3\n">>},
                 ern_program:run(
                     "let three = pick([3])\n"
                     "fn pick(xs : List(Int)) : Int = match xs { [three] -> three | _ -> 0 }\n"
                     "export fn main() : Unit = Io.println(Int.toString(three))\n")).

%%
%% Requirements (report §4.9), derived members (§3.5) and the fill (§5.6)
%%

%% report §4.9: a requirement's members are arguments the program does not
%% write: a known type's member supplied at a call, a requirement's passed
%% along, through a block fn that shares it and one with its own, a lambda,
%% a declaration taken as a value, an operator, prefix `-`, and `show`; and
%% a prelude type's `negate` and `<>` supplied (§9.6), Int's and the `<>`
%% of String and Bytes as the host's operations. Written after the code
requirement_supplied_test() ->
    {ok, Output} =
        ern_program:run(
            "type Money = Money(Int)\n"
            "fn Money.+(Money(a) : Money, Money(b) : Money) : Money =\n    Money(a + b)\n"
            "fn Money.negate(Money(a) : Money) : Money =\n    Money(0 - a)\n"
            "fn total(list : List(a), zero : a) : a needs a.+ =\n"
            "    List.foldLeft(list, zero, fn(acc, x) = acc + x)\n"
            "fn opposite(x : a) : a needs a.negate =\n    -x\n"
            "fn largest(list : List(a)) : Optional(a) needs a.compare = {\n"
            "    fn larger(x : a, y : a) : a =\n        if x < y then y else x;\n"
            "    match list {\n        [] -> None\n"
            "      | first :: rest -> Some(List.foldLeft(rest, first, larger))\n    }\n}\n"
            "fn sorted(list : List(a)) : List(a) needs a.compare = {\n"
            "    fn into(set : OrderedSet.Set(b), x : b) : OrderedSet.Set(b) needs b.compare =\n"
            "        OrderedSet.put(set, x);\n"
            "    OrderedSet.toList(List.foldLeft(list, OrderedSet.empty, into))\n}\n"
            "fn shown(list : List(a)) : String needs a.show =\n"
            "    String.join(List.map(list, fn(x) = Io.show(x)), \" \")\n"
            "fn putAll(list : List(a)) : OrderedSet.Set(a) needs a.compare =\n"
            "    List.foldLeft(list, OrderedSet.empty, OrderedSet.put)\n"
            "export fn main() : Unit = {\n"
            "    Io.println(Io.show(total([Money(1), Money(2)], Money(0))));\n"
            "    Io.println(Io.show(opposite(Money(3))));\n"
            "    Io.println(Io.show(largest([3, 9, 4])));\n"
            "    Io.println(Io.show(sorted([\"c\", \"a\", \"b\"])));\n"
            "    Io.println(shown([1, 2]));\n"
            "    Io.println(Io.show(OrderedSet.toList(putAll([2, 1, 2]))))\n}\n"),
    ?assertEqual(<<"M.Money(3)\nM.Money(-3)\nSome(9)\n[\"a\", \"b\", \"c\"]\n1 2\n[1, 2]\n">>,
                 Output),
    {ok, Prelude} =
        ern_program:run("fn neg(x : a) : a needs a.negate = -x\n"
                        "fn join(x : a, y : a) : a needs a.<> = x <> y\n"
                        "export fn main() : Unit = {\n"
                        "    Io.println(Int.toString(neg(5)));\n"
                        "    Io.println(Float.toString(neg(1.5)));\n"
                        "    Io.println(join(\"a\", \"b\"));\n"
                        "    Io.println(Io.show(join([1], [2])));\n"
                        "    Io.println(Path.toString(join(Path(\"x\"), Path(\"y\"))));\n"
                        "    Io.println(Io.show(join(<<1>>, <<2>>)));\n"
                        "    let f = neg;\n"
                        "    Io.println(Int.toString(f(7)))\n}\n"),
    ?assertEqual(<<"-5\n-1.5\nab\n[1, 2]\nx/y\n<<1, 2>>\n-7\n">>, Prelude).

%% report §9.4, §4.9, Appendix E.1: under `needs a.show`, Io.show writes a
%% type built from `a`, its descriptor composed of the one passed in for
%% `a`; a recursive type stands in the place of `a` inside a recursive type,
%% each descriptor's mu binding its own refs. A regression test: a type
%% built from a variable was refused
show_composed_test() ->
    {ok, Output} = ern_program:run(
        "type Tree(a) = Leaf | Node(left : Tree(a), item : a, right : Tree(a))\n"
        "fn showAll(list : List(a)) : String needs a.show = Io.show(list)\n"
        "fn showOne(x : a) : String needs a.show = Io.show(Some(#(x, 1)))\n"
        "fn showTree(tree : Tree(a)) : String needs a.show = Io.show(tree)\n"
        "fn twice(x : a) : String needs a.show = showAll([x, x])\n"
        "export fn main() : Unit = {\n"
        "    Io.println(showAll([1, 2]));\n"
        "    Io.println(showOne(\"hi\"));\n"
        "    let inner = Node(left = Leaf, item = 'c', right = Leaf);\n"
        "    Io.println(showTree(Node(left = Leaf, item = Some(inner), right = Leaf)));\n"
        "    Io.println(twice([Some(1.5)]))\n"
        "}\n"),
    ?assertEqual(<<"[1, 2]\nSome(#(\"hi\", 1))\n"
                   "M.Node(left = M.Leaf, item = Some(M.Node(left = M.Leaf, item = 'c',"
                   " right = M.Leaf)), right = M.Leaf)\n"
                   "[[Some(1.5)], [Some(1.5)]]\n">>, Output).

%% report §2.4, §4.9, §3.5: `needs`, `derives`, `compare`, `negate` and
%% `show` are words only where they stand, and identifiers elsewhere, a
%% field, a binding, a parameter and a function among them, beside a
%% requirement and a derived compare. A regression test: `needs` and
%% `derives` were reserved, and a task's field `needs` was refused; the last
%% three added when §2.4 named them, and passed at once
words_by_position_test() ->
    {ok, Output} = ern_program:run(
        "type Task = Task(name : String, needs : List(String))\n"
        "type Pair = Pair(left : Int, right : Int) derives compare\n"
        "fn largest(list : List(a)) : Optional(a) needs a.compare =\n"
        "    List.foldLeft(list, None, fn(best, x) = match best {\n"
        "        Some(b) -> if x < b then Some(b) else Some(x)\n"
        "      | None -> Some(x)\n"
        "    })\n"
        "fn count(derives : List(String)) : Int = List.size(derives)\n"
        "fn negate(show : Int) : Int = 0 - show\n"
        "export fn main() : Unit = {\n"
        "    let task = Task(name = \"build\", needs = [\"fetch\", \"unpack\"]);\n"
        "    let needs = task.needs;\n"
        "    let compare = negate(count(needs));\n"
        "    Io.println(Int.toString(compare));\n"
        "    Io.println(Io.show(largest([Pair(left = 1, right = 2), Pair(left = 1, right = 3)])))\n"
        "}\n"),
    ?assertEqual(<<"-2\nSome(M.Pair(left = 1, right = 3))\n">>, Output).

%% report §3.5, §4.9: a derived compare orders by constructor in declaration
%% order, then field by field from the left, its parameters' members
%% supplied where it is used, each field by the prelude's `compare`, which a
%% module's own `compare` does not hide from it (§4.2). Written after the
%% code, it found a defect: the member an operator resolves to supplied its
%% own requirement as the operator's, Int's compare as the runtime's own
%% operation, and so none; the module's own `compare` is a regression test,
%% written after the change
derived_compare_test() ->
    {ok, Hidden} =
        ern_program:run(
            "type Pair = Pair(first : Int, second : String) derives compare\n"
            "fn compare(a : Int, b : Int) : Int = a - b\n"
            "export fn main() : Unit = {\n"
            "    let one = Pair(first = 2, second = \"b\");\n"
            "    Io.println(Io.show(#(one < Pair(first = 2, second = \"c\"), compare(3, 1))))\n"
            "}\n"),
    ?assertEqual(<<"#(true, 2)\n">>, Hidden),
    {ok, Output} =
        ern_program:run(
            "type Shape = Dot | Circle(Int) | Rect(w : Int, h : Int) derives compare\n"
            "type Pair(a, b) = Pair(first : a, second : b) derives compare\n"
            "type Tree(a) = Leaf | Node(left : Tree(a), value : a, right : Tree(a))"
            " derives compare\n"
            "export fn main() : Unit = {\n"
            "    let shapes =\n"
            "        [Rect(w = 1, h = 2), Dot, Circle(3), Rect(w = 1, h = 1), Circle(2)];\n"
            "    Io.println(Io.show(OrderedSet.toList(OrderedSet.fromList(shapes))));\n"
            "    let one = Pair(first = 1, second = \"b\");\n"
            "    Io.println(Io.show(one < Pair(first = 1, second = \"c\")));\n"
            "    let leaf = Node(left = Leaf, value = 2, right = Leaf);\n"
            "    Io.println(Io.show(leaf > Node(left = Leaf, value = 1, right = Leaf)));\n"
            "    Io.println(Io.show(compare(one, one)))\n}\n"),
    ?assertEqual(<<"[M.Dot, M.Circle(2), M.Circle(3), M.Rect(w = 1, h = 1), M.Rect(w = 1, h = 2)]\n"
                   "true\ntrue\nEqual\n">>, Output).

%% report §5.6, §4.9: a record filled from a namespace holds its
%% declarations, a requirement's members supplied at the record's type;
%% written after the code
fill_test() ->
    {ok, Output} =
        ern_program:run("type Ops(s, a) = Ops(fromList : (List(a)) -> s, toList : (s) -> List(a))\n"
                        "let ordered : Ops(OrderedSet.Set(Int), Int) = Ops(..OrderedSet)\n"
                        "let hashed : Ops(Set(Int), Int) = Ops(..Set, toList = Set.toList)\n"
                        "fn roundTrip(list : List(a), ops : Ops(s, a)) : List(a) =\n"
                        "    ops.toList(ops.fromList(list))\n"
                        "export fn main() : Unit = {\n"
                        "    Io.println(Io.show(roundTrip([3, 1, 3], ordered)));\n"
                        "    Io.println(Io.show(List.size(roundTrip([3, 1, 3], hashed))))\n}\n"),
    ?assertEqual(<<"[1, 3]\n2\n">>, Output).

%% report §5.6, §5.1: a path in a record update builds the nested update,
%% two paths sharing a prefix in one, the base and the field expressions
%% evaluated once each, in source order; written after the code
update_path_test() ->
    {ok, Output} =
        ern_program:run("type Stats = Stats(indexed : Int, hits : Int)\n"
                        "type Pool = Pool(name : String, stats : Stats)\n"
                        "type Site = Site(pool : Pool, visits : Int)\n"
                        "fn counted(pool : Pool) : Pool =\n"
                        "    Pool(..pool, stats.indexed = pool.stats.indexed + 1)\n"
                        "export fn main() : Unit = {\n"
                        "    let pool = Pool(name = \"p\", stats = Stats(indexed = 0, hits = 0));\n"
                        "    Io.println(Io.show(counted(pool)));\n"
                        "    Io.println(Io.show(Pool(..pool, stats.indexed = 1, name = \"q\","
                        " stats.hits = 2)));\n"
                        "    let site = Site(=pool, visits = 0);\n"
                        "    Io.println(Io.show(Site(..site, pool.stats.hits = 5, visits = 1)));\n"
                        "    let shown = Pool(..{ Io.println(\"base\"); pool },\n"
                        "                     stats.indexed = { Io.println(\"a\"); 1 },\n"
                        "                     name = { Io.println(\"b\"); \"r\" },\n"
                        "                     stats.hits = { Io.println(\"c\"); 3 });\n"
                        "    Io.println(Io.show(shown))\n}\n"),
    ?assertEqual(<<"M.Pool(name = \"p\", stats = M.Stats(indexed = 1, hits = 0))\n"
                   "M.Pool(name = \"q\", stats = M.Stats(indexed = 1, hits = 2))\n"
                   "M.Site(pool = M.Pool(name = \"p\", stats = M.Stats(indexed = 0, hits = 5)),"
                   " visits = 1)\n"
                   "base\na\nb\nc\n"
                   "M.Pool(name = \"r\", stats = M.Stats(indexed = 1, hits = 3))\n">>, Output).

%% report §8.7, Appendix E.27: a service holds the name it was made with,
%% which `Peer.name` answers, and the hash of its message type, which the
%% checker's supply gives it whether `Peer.service` is called or taken as a
%% value, so that two services of one name at one type are one service. A
%% regression test of the service of a name and a hash, written after the
%% code; a find's comparison of the hash is the nodes'
%% (test/ern_nodes_tests.erl)
peer_service_name_test() ->
    {ok, Output} =
        ern_program:run(
            "type Msg = Add(Int)\n"
            "fn made(make : (String) -> Peer.Service(Msg), name : String) : Peer.Service(Msg) =\n"
            "    make(name)\n"
            "export fn main() : Unit = {\n"
            "    let counter : Peer.Service(Msg) = Peer.service(\"counter\");\n"
            "    let other = made(Peer.service, \"other\");\n"
            "    Io.println(Peer.name(counter) <> \" \" <> Peer.name(other));\n"
            "    Io.println(Io.show(#(made(Peer.service, \"counter\") == counter,"
            " other == counter)))\n"
            "}\n"),
    ?assertEqual(<<"counter other\n#(true, false)\n">>, Output).
