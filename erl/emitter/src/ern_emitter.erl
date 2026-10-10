%% The compiler: typed AST to Erlang abstract format, then to a BEAM module
%% with the interface as the chunk "ErnI" (report §11.1): the
%% canonical interface, a hash of the source, and per dependency the hash
%% of the interface compiled against; the documentation as EEP 48's
%% chunk "Docs" (§11.4); and each definition's canonical form and hash as
%% the chunk "ErnC" (§8.7, Appendix H). Values follow report §8.4.
%%
%% Report §5.1's left-to-right order of a call's arguments, a tuple's and a
%% list's elements and an operator's operands rests on the host compiler's,
%% which evaluates them left to right though Erlang's manual leaves the
%% order open; order_of_evaluation_test pins each form, so a change of the
%% host's order fails `make test`. A long literal's elements, and a
%% bitstring's values and sizes where one is bound, are put in order here.
%%
%% One traversal does the three pre-passes on the way: every Ernest binding
%% gets a fresh Erlang variable (Ernest shadows, Erlang does not), local fns
%% are lifted to module functions taking the block's free variables first,
%% and `let p <- e` becomes a case (report §5.5).
-module(ern_emitter).

-export([compile/4, compile/5, forms/3, erl_source/3, erl_source/4, export/1, function_atom/1,
         function_name/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("typer/include/ern_canonical.hrl").

%% The elements past which a list or a tuple literal is built an element at
%% a time, so that the host's limit of values live at a call is never met.
-define(LONG_LITERAL, 256).


%% Emission context, threaded through everything. namespace: the module's;
%% erlang_module: the Erlang module it compiles to; env: the checker's
%% environment; declaration: the Ernest name of the declaration being
%% compiled, [Name] or [MemberOf, Name], which a spawn site names;
%% variables: Ernest name => Erlang variable name; counter: the last number
%% a made variable or name took; locals: local fn name => #local_fn{} (see
%% Blocks); lifted: module functions produced by lifting, reversed;
%% top_names: top-level {MemberOf, Name} => arity | value; descriptors:
%% descriptor term => the name of the module function returning it;
%% pattern_guards: Erlang guard forms a pattern needs on its clause, a
%% float segment's zero (report §3.1), taken by the clause that uses them;
%% session_offset: where the module is an input of the shell's session
%% (report §11.2), the lines before its first in its file, since its spawn
%% sites are written as the session writes names; else false. members:
%% {TypeVariableId, Member} => the Erlang variable of a member the
%% enclosing declarations' requirements name (report §4.9), each a
%% parameter the program does not write. standard: whether the module is
%% the standard library's own. outer: while a pattern is compiled, the
%% variables in scope where it began, else undefined. canonical: the
%% module's canonical forms as ern_canonical:module/5 gives them, by which
%% a key and a spawn on a peer name a type and a function (report §8.7).
%% let_lambdas: the Erlang variable a `let` binds to a lambda => the lambda
%% and the variables in force at it, which its captures are, for a spawn on
%% a peer that names it (§3.11). entries: each lambda's or local fn's
%% identity a spawn on a peer starts => its entry, the function of the
%% module that runs it over its captures (§8.7, §11.1). units: each
%% namespace whose unit is not its module's Erlang name => its unit, which
%% the shell gives where a reload brought a module's version as a unit of
%% its own (report §11.2). site_namespace: the namespace a spawn site names
%% a declaration under, the module's own, or a reload's version's, which
%% the shell gives (report §11.2). builds_functions: whether the module
%% builds a function value, a fun of its own code that may be held anywhere
%% (function_value/2), which the shell reads to keep an input (§11.2).
-record(emit_context, {namespace, erlang_module, env, declaration, variables = #{},
                       counter = 0, locals = #{}, lifted = [], top_names = #{},
                       descriptors = #{}, pattern_guards = [], session_offset = false,
                       standard = false, members = #{}, outer, canonical, let_lambdas = #{},
                       entries = #{}, units = #{}, site_namespace,
                       builds_functions = false}).
%% A spawn on a peer's entry (report §8.7, §11.1): the function's name and
%% arity, the enclosing definition's qualified name, the identity's hash
%% and position, and the reach, which the module's '$code'/0 lists.
-record(entry, {function, arity, qualified_name, hash, position, reach}).
%% A local fn of a block (see Blocks): lifted_name, the module function's
%% name; captured, the free Ernest names of its body that the enclosing
%% scopes or its block's lets bind; enclosing, the Erlang variables of the
%% enclosing blocks' local fns it references; references, the local fns of
%% its block it references; members, the Erlang variables of the enclosing
%% requirements' members its body uses; snapshot, the variables in force at
%% its declaration, once passed. All but references are what it closes over.
%% declaration: the fn itself, whose body a spawn on a peer reads (§8.7).
-record(local_fn, {lifted_name, captured, enclosing, references, members = [],
                   snapshot = pending, declaration}).

%%
%% Entry points
%%

-spec compile([atom()], [tuple()], #interface{}, ern_typecheck:env()) -> {ok, atom(), binary()}.
compile(Namespace, Declarations, Interface, Env) ->
    compile(Namespace, Declarations, Interface, Env, #{source_hash => <<>>, deps => []}).

%% Build: the source's hash and its path from the build root, and the
%% dependencies' interface hashes, go into the chunk beside the interface
%% (report §11.1); `source` goes to the documentation; `session_offset`
%% marks an input of the shell, which is compiled and not written, and is
%% not kept, with the line offset its spawn sites are written with;
%% `form_namespace`, which the shell gives an input, is the namespace its
%% forms and its '$code'/0 name what the session declares under, the
%% session's one (Appendix H, §11.2), and is not kept; `standard` marks a
%% module of the standard library's own source root.
%% `units` names the unit of each namespace whose unit is not its module's
%% Erlang name, the module's own among them, as the shell gives them where
%% a reload brought a version as a unit of its own (report §11.2), and is
%% not kept; `site_namespace`, which the shell gives such a version, is the
%% namespace its spawn sites name its declarations under, `Counter$2`
%% (§11.2), and is not kept. The chunk records beside the build's facts
%% whether the module builds a function value, `builds_functions`, by which
%% the shell keeps an input's code (§11.2). The declarations are the
%% checker's, so every rule a program can break has
%% been checked: what the emitter cannot emit, or emits and the host does not
%% compile, is a defect of the toolchain, raised as one, which `ern` reports
%% as its own failure (report §11).
-spec compile([atom()], [tuple()], #interface{}, ern_typecheck:env(),
              #{source_hash := binary(), source_path => binary(),
                deps := [{[atom()], binary()}], compiler => binary(),
                stdlib => binary() | none, source => binary(),
                session_offset => non_neg_integer(), form_namespace => [atom()],
                standard => boolean(), units => #{[atom()] => atom()},
                site_namespace => [atom()]}) ->
          {ok, atom(), binary()}.
compile(Namespace, Declarations, Interface, Env, Build) ->
    %% report §8.7, §11.1, Appendix H: the canonical forms and their hashes,
    %% the hashes in the interface, by which a dependent's forms name its
    %% definitions, and the hashes of other modules' definitions its own
    %% forms name, which the recompile rule compares
    Canonical = ern_canonical:module(Namespace, Declarations, Env,
                                     maps:get(standard, Build, false),
                                     maps:get(form_namespace, Build, Namespace)),
    #{references := References} = Canonical,
    {Forms, BuildsFunctions} =
        module_forms(Namespace, Declarations, Env, Build#{code => true, canonical => Canonical}),
    Facts = (maps:without([source, session_offset, form_namespace, standard, units,
                           site_namespace], Build))
        #{references => References, builds_functions => BuildsFunctions},
    Chunk = ern_interface:encode(Facts, ern_canonical:interface(Interface, Canonical)),
    Docs = term_to_binary(ern_docs:build(Namespace, Declarations, Env,
                                         maps:get(source, Build, <<>>))),
    Chunks = [{ern_interface:chunk_name(), Chunk}, {ern_docs:chunk_name(), Docs},
              {ern_canonical:chunk_name(), ern_canonical:encode(Canonical)}],
    %% report §11: the host's compiler takes nothing from the environment
    Options = [return_errors, debug_info, {extra_chunks, Chunks}],
    case compile:noenv_forms(Forms, Options) of
        {ok, ErlangModule, Beam} -> {ok, ErlangModule, Beam};
        {error, Errors, _} -> compiled_without_type_pass(Forms, Options, Errors)
    end.

%% A workaround of a defect of OTP's compiler, decided on 2026-10-05,
%% docs/otp_bugs.md's report 3, the compiler's validator refusing what its
%% type pass made through rem. OTP 29's compiler 10.0.5 narrows a recursive function's
%% parameter to a range its call's argument breaks, a `rem` whose divisor's
%% range holds 0 among them, and its own validator then refuses valid
%% Erlang. A module the validator refuses so is compiled again with that
%% type pass off, `no_type_opt`, its code then a little slower, and no other
%% module is. The workaround goes when an OTP that Ernest requires has the
%% fix; another refusal is the emitter's defect, as before.
compiled_without_type_pass(Forms, Options, Errors) ->
    Refused = case refused_by_validator(Errors) of
                  true -> compile:noenv_forms(Forms, [no_type_opt | Options]);
                  false -> {error, Errors, []}
              end,
    case Refused of
        {ok, ErlangModule, Beam} -> {ok, ErlangModule, Beam};
        {error, Errors1, _} -> erlang:error({emitted_erlang_does_not_compile, Errors1})
    end.

refused_by_validator(Errors) ->
    lists:any(fun({_, Refusals}) -> lists:keymember(beam_validator, 2, Refusals) end, Errors).

%% The abstract forms, for the golden tests and erl_prettypr.
-spec forms([atom()], [tuple()], ern_typecheck:env()) -> [erl_parse:abstract_form()].
forms(Namespace, Declarations, Env) ->
    forms(Namespace, Declarations, Env, #{}).

%% Report §8.5: with the modules this one depends on, which it declares
%% as `'$deps'/0` so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file. Report §8.7: a key's
%% and a spawn's hashes are the canonical forms', which a build gives and
%% the forms for reading compute.
-spec forms([atom()], [tuple()], ern_typecheck:env(), map()) -> [erl_parse:abstract_form()].
forms(Namespace, Declarations, Env, Build) ->
    {Forms, _} = module_forms(Namespace, Declarations, Env, Build),
    Forms.

%% The forms, and whether the module builds a function value.
module_forms(Namespace, Declarations, Env, Build) ->
    Units = maps:get(units, Build, #{}),
    ErlangModule = maps:get(Namespace, Units, ern_namespace:erlang_module(Namespace)),
    Dependencies = [Dependency || {Dependency, _} <- maps:get(deps, Build, [])],
    Standard = maps:get(standard, Build, false),
    Canonical = case Build of
                    #{canonical := Given} -> Given;
                    _ -> ern_canonical:module(Namespace, Declarations, Env, Standard)
                end,
    Context = #emit_context{namespace = Namespace, erlang_module = ErlangModule, env = Env,
                            top_names = top_names(Declarations),
                            session_offset = maps:get(session_offset, Build, false),
                            standard = Standard, canonical = Canonical, units = Units,
                            site_namespace = maps:get(site_namespace, Build, Namespace)},
    {DeclarationFunctions, Context1} = lists:mapfoldl(fun declaration/2, Context, Declarations),
    Lets = [Declaration || #let_declaration{} = Declaration <- Declarations],
    {InitFunction, Context2} = init_function(Lets, Context1),
    TestsFunction = tests_function(Lets),
    DependenciesFunction = dependencies_function(Dependencies, Context),
    Entries = maps:values(Context2#emit_context.entries),
    SpawnedFunction = spawned_function(Declarations, Entries),
    Bodies = lists:append(DeclarationFunctions) ++ InitFunction ++ TestsFunction
        ++ SpawnedFunction ++ Context2#emit_context.lifted,
    CodeFunction = case Build of
                       #{code := true} ->
                           Calls = calls(Bodies, ErlangModule, Standard),
                           Named = {Namespace, maps:get(form_namespace, Build, Namespace)},
                           code_function(code(Named, ErlangModule, Declarations, Canonical,
                                              Entries)
                                         ++ [{Namespace, {calls, Calls}}]);
                       _ ->
                           []
                   end,
    Exports = [export(Declaration) || Declaration <- Declarations, exported(Declaration)]
        ++ [{'$init', 0} || Lets =/= []] ++ [{'$tests', 0} || TestsFunction =/= []]
        ++ [{'$deps', 0} || DependenciesFunction =/= []]
        ++ [{'$spawned', 2} || SpawnedFunction =/= []] ++ [{'$code', 0} || CodeFunction =/= []],
    %% an Ernest function named like an auto-imported BIF, `size`, `max`,
    %% is called by its own name: the auto-import is switched off for it
    Clashes = [{Function, Arity}
               || {Function, Arity} <- top_functions(Context#emit_context.top_names),
                  erl_internal:bif(Function, Arity)],
    NoImport = case Clashes of
                   [] -> [];
                   _ -> [erl_syntax:attribute(erl_syntax:atom(compile),
                                              [erl_syntax:abstract({no_auto_import, Clashes})])]
               end,
    %% report §3.9: a function whose result is a type variable no parameter
    %% holds never returns, `fault` and `Os.exit` among them, so Dialyzer,
    %% which the release review runs over this code, is told it is meant
    NoReturn = erl_syntax:attribute(erl_syntax:atom(dialyzer), [erl_syntax:atom(no_return)]),
    Attrs = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(ErlangModule)]),
             NoReturn]
        ++ NoImport
        ++ [erl_syntax:attribute(erl_syntax:atom(export),
                                 [erl_syntax:list([erl_syntax:arity_qualifier(
                                                     erl_syntax:atom(Function),
                                                     erl_syntax:integer(Arity))
                                                   || {Function, Arity} <- Exports])])],
    Functions = lists:append(DeclarationFunctions) ++ InitFunction ++ TestsFunction
        ++ DependenciesFunction ++ SpawnedFunction ++ CodeFunction
        ++ lists:reverse(Context2#emit_context.lifted),
    {erl_syntax:revert_forms(Attrs ++ Functions), Context2#emit_context.builds_functions}.

%% Each top-level name as the Erlang function it compiles to, a `let` as
%% its getter of no argument.
top_functions(TopNames) ->
    [{function_name(MemberOf, Name), case Arity of value -> 0; _ -> Arity end}
     || {MemberOf, Name} := Arity <- TopNames].

%% Report Appendix E.24, §11.2: '$tests'/0 lists the module's tests, every
%% top-level let of type Test.Case(m), exported or not, for `ern test`; the
%% mailbox type is the test process's, and nothing here.
tests_function(Lets) ->
    Names = [function_name(undefined, Name)
             || #let_declaration{name = Name, scheme = #scheme{type = Type}} <- Lets,
                is_test_case(Type)],
    case Names of
        [] -> [];
        _ ->
            %% the list is built a test at a time, from the last, so that no
            %% more than the list so far is live at a call: a list of every
            %% call at once passes the host's limit of live values
            {Matches, List} =
                lists:foldl(fun(Function, {Acc, Tail}) ->
                                Name = list_to_atom("Tests" ++ integer_to_list(length(Acc))),
                                Variable = erl_syntax:variable(Name),
                                Head = erl_syntax:application(erl_syntax:atom(Function), []),
                                Extended = erl_syntax:cons(Head, Tail),
                                Match = erl_syntax:match_expr(Variable, Extended),
                                {[Match | Acc], Variable}
                            end, {[], erl_syntax:nil()}, lists:reverse(Names)),
            [erl_syntax:function(erl_syntax:atom('$tests'),
                                 [erl_syntax:clause([], none, lists:reverse(Matches) ++ [List])])]
    end.

is_test_case({tcon, ['Test', 'Case'], [_]}) -> true;
is_test_case(_) -> false.

%% Report §2.3: a function whose own name holds `$`, the entry of an input
%% at the shell's prompt, is named by no program.
nameable(#fn_declaration{name = Name}) -> not lists:member($$, atom_to_list(Name));
nameable(#foreign_fn_declaration{name = Name}) -> not lists:member($$, atom_to_list(Name)).

%% Report §8.7: what the module holds, which the code table reads as the
%% module loads (ern_code): each definition by its qualified name, with its
%% hash, from its canonical form, and the function that holds it, a
%% function with its reach, or for a binding the key its value is kept
%% under (§8.5); each foreign declaration's implementation and its
%% function, which the canonical forms name by its qualified name alone;
%% each lambda and local fn a spawn on a peer starts, by its identity,
%% with its entry and its reach; and, last, under the module's namespace,
%% the units its code calls (calls/3). Each qualified name is the forms'
%% (Appendix H): an input of a shell's session names what it declares
%% under the session's one namespace, FormNamespace, by which a reach finds
%% it. A literal '$code'/0 answers, so that a load reads it without
%% decoding the module's chunks, which costs more than the load. The forms
%% for reading, `--emit-erl` and the golden files, have no such function.
code(Named, ErlangModule, Declarations, #{identities := Hashes, reaches := Reaches},
     Entries) ->
    lists:append([declaration_code(Named, ErlangModule, Declaration, Hashes, Reaches)
                  || Declaration <- Declarations])
        ++ lists:sort([{form_name(QualifiedName, Named),
                        {lambda, Hash, Position, Function, Arity, Reach}}
                       || #entry{function = Function, arity = Arity, qualified_name = QualifiedName,
                                 hash = Hash, position = Position, reach = Reach} <- Entries]).

%% A qualified name of the module's own, under the namespace its forms
%% write it in.
form_name(QualifiedName, {Namespace, FormNamespace}) ->
    FormNamespace ++ lists:nthtail(length(Namespace), QualifiedName).

declaration_code({Namespace, _} = Named, _,
                 #fn_declaration{member_of = MemberOf, name = Name} = Declaration, Hashes,
                 Reaches) ->
    QualifiedName = Namespace ++ [MemberOf || MemberOf =/= undefined] ++ [Name],
    {Function, Arity} = export(Declaration),
    [{form_name(QualifiedName, Named),
      {function, maps:get(QualifiedName, Hashes), Function, Arity,
       maps:get(QualifiedName, Reaches)}}];
declaration_code({Namespace, _} = Named, ErlangModule, #let_declaration{name = Name}, Hashes, _) ->
    QualifiedName = Namespace ++ [Name],
    Key = {ErlangModule, function_name(undefined, Name)},
    [{form_name(QualifiedName, Named), {binding, maps:get(QualifiedName, Hashes), Key}}];
declaration_code({Namespace, _} = Named, _, #type_declaration{name = Name}, Hashes, _) ->
    QualifiedName = Namespace ++ [Name],
    [{form_name(QualifiedName, Named), {type, maps:get(QualifiedName, Hashes)}}];
declaration_code(Named, ErlangModule, #abstract_declaration{declaration = Declaration},
                 Hashes, Reaches) ->
    declaration_code(Named, ErlangModule, Declaration, Hashes, Reaches);
declaration_code({Namespace, _} = Named, _,
                 #foreign_fn_declaration{member_of = MemberOf, name = Name,
                                         implementation = Implementation} = Declaration, _, _) ->
    {ok, {HostModule, HostFunction, _}} = ern_typecheck:foreign_implementation(Implementation),
    {Function, Arity} = export(Declaration),
    [{form_name(Namespace ++ [MemberOf || MemberOf =/= undefined] ++ [Name], Named),
      {foreign, HostModule, HostFunction, Function, Arity}}];
declaration_code(_, _, _, _, _) ->
    [].

%% Report §8.7: '$spawned'/2 runs, in the calling process, a function of
%% this module a spawn on a peer may start, over the values it captured:
%% each function and foreign function of no parameter, by its name, and
%% each lambda's or local fn's entry. The peer's runtime calls it with the
%% function its code table holds under the frame's identity, so that a
%% function no other module may name runs where its identity is held.
spawned_function(Declarations, Entries) ->
    Clauses = [spawned_clause(Function, 0)
               || Declaration <- Declarations, {Function, 0} <- spawnable(Declaration)]
        ++ [spawned_clause(Function, Arity)
            || #entry{function = Function, arity = Arity} <- lists:keysort(#entry.function,
                                                                           Entries)],
    case Clauses of
        [] -> [];
        _ -> [erl_syntax:function(erl_syntax:atom('$spawned'), Clauses)]
    end.

%% '$spawned'(Function, [Capture1, ...]) -> Function(Capture1, ...).
spawned_clause(Function, Arity) ->
    Captures = [erl_syntax:variable(list_to_atom("Capture" ++ integer_to_list(Index)))
                || Index <- lists:seq(1, Arity)],
    erl_syntax:clause([erl_syntax:atom(Function), erl_syntax:list(Captures)], none,
                      [erl_syntax:application(erl_syntax:atom(Function), Captures)]).

%% A declaration a spawn may name, as the function it compiles to: a `fn`
%% or a `foreign fn`, but the entry of an input at the shell's prompt,
%% which no program names (§2.3).
spawnable(#fn_declaration{} = Declaration) -> [export(Declaration) || nameable(Declaration)];
spawnable(#foreign_fn_declaration{} = Declaration) ->
    [export(Declaration) || nameable(Declaration)];
spawnable(_) -> [].

code_function(Code) ->
    [erl_syntax:function(erl_syntax:atom('$code'),
                         [erl_syntax:clause([], none, [erl_syntax:abstract(Code)])])].

%% Report §8.7, §11.2: the other units the module's code calls, each the
%% module of a remote call or of a function value that is an Ernest unit,
%% whose name begins `ern@` (§11.1): the unit the shell's units name for a
%% module, or the module's Erlang name. A peer's spawn reads a reach's
%% bindings and foreign declarations in the units the code of the unit
%% that runs it calls, directly or through one it calls (ern_code). A
%% module of the standard library lists none, since no reach names what it
%% holds (Appendix H), so that a walk from a program's unit ends there.
calls(_Bodies, _ErlangModule, true) ->
    [];
calls(Bodies, ErlangModule, false) ->
    lists:usort([Unit || Function <- Bodies,
                         Unit <- erl_syntax_lib:fold(fun called_unit/2, [], Function),
                         Unit =/= ErlangModule]).

called_unit(Node, Units) ->
    case erl_syntax:type(Node) of
        module_qualifier ->
            Module = erl_syntax:module_qualifier_argument(Node),
            case erl_syntax:type(Module) =:= atom
                 andalso lists:prefix("ern@", atom_to_list(erl_syntax:atom_value(Module))) of
                true -> [erl_syntax:atom_value(Module) | Units];
                false -> Units
            end;
        _ ->
            Units
    end.

%% Report §8.5: the units of the modules this one depends on, whose
%% top-level bindings are evaluated before its own.
dependencies_function([], _Context) ->
    [];
dependencies_function(Dependencies, Context) ->
    Modules = erl_syntax:list([erl_syntax:atom(unit(Dependency, Context))
                               || Dependency <- Dependencies]),
    [erl_syntax:function(erl_syntax:atom('$deps'),
                         [erl_syntax:clause([], none, [Modules])])].

%% The module as Erlang source, for --emit-erl (report §11.1).
-spec erl_source([atom()], [tuple()], ern_typecheck:env()) -> unicode:chardata().
erl_source(Namespace, Declarations, Env) ->
    erl_source(Namespace, Declarations, Env, #{}).

-spec erl_source([atom()], [tuple()], ern_typecheck:env(), map()) -> unicode:chardata().
erl_source(Namespace, Declarations, Env, Build) ->
    Forms = forms(Namespace, Declarations, Env, Build),
    [erl_prettypr:format(erl_syntax:form_list(Forms)), "\n"].

%%
%% Declarations
%%

top_names(Declarations) ->
    maps:from_list([{{MemberOf, Name}, length(Params) + length(Requirement)}
                    || #fn_declaration{member_of = MemberOf, name = Name, params = Params,
                                       requirement = Requirement} <- Declarations]
                   ++ [{{MemberOf, Name}, length(Params) + length(Requirement)}
                       || #foreign_fn_declaration{member_of = MemberOf, name = Name,
                                                  params = Params,
                                                  scheme = #scheme{requirement = Requirement}}
                              <- Declarations]
                   ++ [{{undefined, Name}, value}
                       || #let_declaration{name = Name} <- Declarations]).

exported(#fn_declaration{export = Export}) -> Export;
exported(#let_declaration{export = Export}) -> Export;
exported(#foreign_fn_declaration{export = Export}) -> Export;
exported(_) -> false.

%% The function a declaration compiles to, its name and the arity the
%% module exports it at, a requirement's members after its parameters
%% (report §4.9), which the documentation chunk keys it by too.
-spec export(tuple()) -> {atom(), non_neg_integer()}.
export(#fn_declaration{member_of = MemberOf, name = Name, params = Params,
                       requirement = Requirement}) ->
    {function_name(MemberOf, Name), length(Params) + length(Requirement)};
export(#foreign_fn_declaration{member_of = MemberOf, name = Name, params = Params,
                               scheme = #scheme{requirement = Requirement}}) ->
    {function_name(MemberOf, Name), length(Params) + length(Requirement)};
export(#let_declaration{name = Name}) -> {function_name(undefined, Name), 0}.

%% The Erlang function a top-level Ernest name compiles to: its own name,
%% but for the names the host gives every module, `module_info/0,1` and the
%% pseudo-function `record_info/2`, which get a `$`, as no Ernest name can
%% spell. A program may name a function anything; the collision is the
%% host's, and nothing the program or the report sees.
-spec function_atom(atom()) -> atom().
function_atom(module_info) -> 'module_info$';
function_atom(record_info) -> 'record_info$';
function_atom(Name) -> Name.

%% A declaration's Ernest name, as a spawn site and a fault name it.
declaration_parts(undefined, Name) -> [Name];
declaration_parts(MemberOf, Name) -> [MemberOf, Name].

%% The Erlang function a top-level declaration compiles to, the type it is
%% a member of or undefined, which the documentation chunk's keys name too.
-spec function_name(atom() | undefined, atom()) -> atom().
function_name(undefined, Name) -> function_atom(Name);
function_name(MemberOf, Name) -> list_to_atom(atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name)).

declaration(#fn_declaration{span = Span, member_of = MemberOf, name = Name, params = Params,
                            requirement = Requirement, body = Body},
            Context) ->
    FunctionName = function_name(MemberOf, Name),
    {Head, Context1} =
        head_patterns(Params, Requirement,
                      Context#emit_context{declaration = declaration_parts(MemberOf, Name),
                                           variables = #{}, locals = #{}, members = #{}}),
    {BodyForms, Context2} = body(Body, Context1),
    Clause = at(Span, erl_syntax:clause(Head, none, BodyForms)),
    {[at(Span, erl_syntax:function(erl_syntax:atom(FunctionName), [Clause]))],
     Context2#emit_context{variables = #{}, members = #{}}};
declaration(#let_declaration{span = Span, name = Name}, Context) ->
    %% the getter; the value is computed by '$init'/0 (report §8.5)
    FunctionName = function_name(undefined, Name),
    Get = call_remote(ern_rt, binding, [key(Context, FunctionName)]),
    Clause = at(Span, erl_syntax:clause([], none, [Get])),
    {[at(Span, erl_syntax:function(erl_syntax:atom(FunctionName), [Clause]))], Context};
declaration(#foreign_fn_declaration{span = Span, member_of = MemberOf, name = Name, params = Params,
                                    implementation = Implementation, scheme = Scheme}, Context) ->
    %% report §4.7, §8.4: the implementation called in place, an exception
    %% it raises turned into a fault, and its return checked
    FunctionName = function_name(MemberOf, Name),
    {ok, {HostModule, HostFunction, _}} = ern_typecheck:foreign_implementation(Implementation),
    %% report §9.4: `Io.show` and `Io.debug` take their requirement's member,
    %% the descriptor, after their argument, and pass it to the host
    Prefixes = lists:duplicate(length(Params), "Argument")
        ++ lists:duplicate(length(Scheme#scheme.requirement), "Member"),
    {Variables, Context1} =
        named_variables(Prefixes,
                        Context#emit_context{declaration = declaration_parts(MemberOf, Name)}),
    {Args, Members} = lists:split(length(Params),
                                  [erl_syntax:variable(Variable) || Variable <- Variables]),
    {Body, Context2} = foreign_body({HostModule, HostFunction}, Scheme#scheme.type, Args, Members,
                                    Context1),
    Clause = at(Span, erl_syntax:clause(Args ++ Members, none, [Body])),
    {[at(Span, erl_syntax:function(erl_syntax:atom(FunctionName), [Clause]))], Context2};
declaration(_, Context) ->
    {[], Context}.

%% A function's parameters as patterns, then a parameter for each member
%% its requirement names (report §4.9).
head_patterns(Params, Requirement, Context) ->
    {Patterns, Context1} = lists:mapfoldl(fun(#param{pattern = Pattern}, Acc) ->
                                              pattern(Pattern, Acc)
                                          end, Context, Params),
    {Members, Context2} = members_taken(Requirement, Context1),
    {Patterns ++ Members, Context2}.

%% Report §8.4: a foreign function's body, its arguments exposed to the
%% host, the call, and its return checked.
foreign_body({HostModule, HostFunction}, {tfn, ParamTypes, Effect, ResultType}, Args, Members,
             Context) ->
    {Exposed, Context1} = lists:mapfoldl(fun exposed/2, Context, lists:zip(ParamTypes, Args)),
    Call = erl_syntax:application(erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                                  Exposed ++ Members),
    {Try, Context2} = foreign_call(Call, HostModule, HostFunction, length(Exposed ++ Members),
                                   {Effect, ParamTypes}, Context1),
    foreign_return(Try, ParamTypes, ResultType, Context2).

%% Report §4.9: the members a requirement names, each a parameter after the
%% written ones, in the order the requirement writes them.
members_taken(Requirement, Context) ->
    lists:mapfoldl(fun(#member{type = Variable, name = Member}, Acc) ->
                       {tvar, Id} = resolved(Variable, Acc),
                       {[Erlang], Acc1} = fresh_variables(1, "Member", Acc),
                       Members = Acc1#emit_context.members,
                       {erl_syntax:variable(Erlang),
                        Acc1#emit_context{members = Members#{{Id, Member} => Erlang}}}
                   end, Context, Requirement).

%% Report §4.7, §7.4: the foreign call, an exception it raises turned into
%% a fault. Report §8.6: a foreign call in progress can still deliver, so
%% it is counted while it runs. A standard library function with no
%% mailbox type of its own waits on no process, and is not: one that is
%% pure, and one whose effect is only a function's it is given, which runs
%% as Ernest and is counted as Ernest is, so that a deadlock in it is found
%% (Appendix E.0 rule 1). Nor is one whose implementation its runtime
%% module lists as waiting on no process, read function by function
%% (`ern_rt`'s `-waits_on_nothing`), since the count would cost a multiple
%% of the call.
foreign_call(Call, HostModule, HostFunction, Arity, {Effect, ParamTypes}, Context) ->
    Uncounted = Context#emit_context.standard
        andalso (waits_on_nothing(Effect, ParamTypes, Context)
                 orelse is_listed_waiting_on_nothing(HostModule, HostFunction, Arity)),
    Counted = case Uncounted of
                  true -> Call;
                  false -> call_remote(ern_rt, in_foreign,
                                       [erl_syntax:fun_expr([erl_syntax:clause([], none, [Call])])])
              end,
    {[Class, Error, Trace], Context1} = named_variables(["Class", "Error", "Trace"], Context),
    Raised = call_remote(ern_boundary, raised,
                         [erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                          erl_syntax:integer(Arity)
                          | [erl_syntax:variable(Variable) || Variable <- [Class, Error, Trace]]]),
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:variable(Class),
                                                            erl_syntax:variable(Error),
                                                            erl_syntax:variable(Trace))],
                                none, [Raised]),
    {erl_syntax:try_expr([Counted], [Handler]), Context1}.

is_listed_waiting_on_nothing(HostModule, HostFunction, Arity) ->
    case code:ensure_loaded(HostModule) of
        {module, HostModule} ->
            Attributes = HostModule:module_info(attributes),
            lists:member({HostFunction, Arity},
                         lists:append(proplists:get_all_values(waits_on_nothing, Attributes)));
        _ ->
            false
    end.

waits_on_nothing(Effect, ParamTypes, Context) ->
    case resolved(Effect, Context) of
        pure -> true;
        {tvar, _} = Variable ->
            lists:member(Variable, type_variables([resolved(Type, Context) || Type <- ParamTypes]));
        _ -> false
    end.

%% Report §8.4: the foreign call's return checked. The standard library's
%% is the runtime's own, and not checked; a type variable of the result
%% that no parameter names stands for no value the function could have
%% been given, so it matches none, and the return faults where it holds
%% one.
foreign_return(Try, _ParamTypes, _ResultType, #emit_context{standard = true} = Context) ->
    {Try, Context};
foreign_return(Try, ParamTypes, ResultType, Context) ->
    ParamVariables = lists:append([type_variables(ParamType) || ParamType <- ParamTypes]),
    Unnamed = [Variable || Variable <- lists:usort(type_variables(ResultType)),
                           not lists:member(Variable, ParamVariables)],
    check_form(as_never(Unnamed, ResultType), ResultType, Try, "foreign return does not match ",
               Context).

key(#emit_context{erlang_module = ErlangModule}, Name) ->
    erl_syntax:tuple([erl_syntax:atom(ErlangModule), erl_syntax:atom(Name)]).

%% '$init'/0 evaluates the top-level lets once, in dependency order, each
%% named as the process's site while it runs, so that its fault is reported
%% under it (report §8.5, §11.2).
init_function([], Context) ->
    {[], Context};
init_function(Lets, Context) ->
    {Stores, Context1} =
        lists:mapfoldl(fun(#let_declaration{span = Span, name = Name, body = Body}, Acc) ->
                           FunctionName = function_name(undefined, Name),
                           Acc1 = Acc#emit_context{declaration = [Name], variables = #{},
                                                   locals = #{}},
                           Named = call_remote(ern_rt, initializing, [site(Span, Acc1)]),
                           {BodyForm, Acc2} = expr(Body, Acc1),
                           Store = call_remote(persistent_term, put,
                                               [key(Acc, FunctionName), BodyForm]),
                           {[Named, Store], Acc2}
                       end, Context, let_order(Lets, Context)),
    Clause = erl_syntax:clause([], none, lists:append(Stores) ++ [erl_syntax:atom(ok)]),
    {[erl_syntax:function(erl_syntax:atom('$init'), [Clause])], Context1}.

%% Report §8.5: the lets in the order the checker found, a let after
%% those its initializer reaches and otherwise as declared.
let_order(Lets, #emit_context{env = Env}) ->
    ByKey = maps:from_list([{{undefined, Name}, Declaration}
                            || #let_declaration{name = Name} = Declaration <- Lets]),
    [maps:get(Key, ByKey) || Key <- ern_typecheck:let_order(Env)].

%%
%% Expressions: expr(Expr, Context) -> {Form, Context}
%%

expr(#e_literal{span = Span, kind = Kind, value = Value}, Context) ->
    {at(Span, literal(Kind, Value)), Context};
expr(#e_var{span = Span, namespace = Namespace, name = Name, type = Type, referent = Referent,
            supplies = Supplies}, Context) ->
    {Form, Context1} = name_form(Span, Namespace, Name, Referent, Type, Supplies, Context),
    {at(Span, Form), function_value(Form, Context1)};
expr(#e_constructor{span = Span, namespace = Namespace, name = Name, base = Base, args = Args},
     Context) ->
    constructor_expr(Span, Namespace, Name, Base, Args, Context);
expr(#e_tuple{span = Span, elements = Elements}, Context)
  when length(Elements) > ?LONG_LITERAL ->
    {Built, Context1} = built_in_order(Elements, Context),
    {at(Span, call_remote(erlang, list_to_tuple, [Built])), Context1};
expr(#e_list{span = Span, elements = Elements}, Context)
  when length(Elements) > ?LONG_LITERAL ->
    {Built, Context1} = built_in_order(Elements, Context),
    {at(Span, Built), Context1};
expr(#e_tuple{span = Span, elements = Elements}, Context) ->
    {Forms, Context1} = exprs(Elements, Context),
    {at(Span, erl_syntax:tuple(Forms)), Context1};
expr(#e_list{span = Span, elements = Elements}, Context) ->
    {Forms, Context1} = exprs(Elements, Context),
    {at(Span, erl_syntax:list(Forms)), Context1};
expr(#e_bitstring{span = Span, segments = Segments}, Context) ->
    %% report §5.11, §7.4: the runtime's bit syntax, each segment's value
    %% checked for its width by ern_bits, a badarg the segment overflow
    %% fault, and the result checked for alignment when a dynamic size
    %% leaves the bit count open
    {Compiled, {Context1, Open}} =
        lists:mapfoldl(fun(#bit_segment{value = Value, specs = Specs}, {Acc, OpenSoFar}) ->
                           {ok, Spec} = ern_bitspec:spec(Specs),
                           {ValueForm, Acc1} = expr(Value, Acc),
                           {SizeForm, Acc2} = size_form(Spec, Acc1),
                           {{Spec, ValueForm, SizeForm}, {Acc2, OpenSoFar orelse is_open(Spec)}}
                       end, {Context, false}, Segments),
    {Bindings, Parts, Context2} = segments_bound(Compiled, Context1),
    Fields = [erl_syntax:binary_field(segment_value(Spec, ValueForm, SizeForm), SizeForm,
                                      type_specs(Spec))
              || {Spec, ValueForm, SizeForm} <- Parts],
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:atom(error),
                                                            erl_syntax:atom(badarg))],
                                none, [call_remote(ern_bits, overflow, [])]),
    Built = erl_syntax:try_expr([erl_syntax:binary(Fields)], [], [Handler]),
    Checked = case Open of
                  true -> call_remote(ern_bits, aligned, [Built]);
                  false -> Built
              end,
    Form = case Bindings of
               [] -> Checked;
               _ -> erl_syntax:block_expr(Bindings ++ [Checked])
           end,
    {at(Span, Form), Context2};
expr(#e_block{span = Span, statements = Statements}, Context) ->
    {Forms, Context1} = block(Statements, Context),
    {at(Span, erl_syntax:block_expr(Forms)),
     Context1#emit_context{variables = Context#emit_context.variables,
                           locals = Context#emit_context.locals}};
expr(#e_call{span = Span, callee = Callee, args = [Expr | Rest], pipe = true}, Context)
  when not is_record(Callee, e_var), not is_record(Callee, e_constructor),
       not is_record(Callee, e_lambda) ->
    %% report §5.1: in `x |> e`, x is evaluated before a callee that is
    %% evaluated at all, and the other arguments after it
    {[ExprForm, CalleeForm | RestForms], Context1} = exprs([Expr, Callee | Rest], Context),
    {[PipedName], Context2} = fresh_variables(1, "Piped", Context1),
    Piped = erl_syntax:variable(PipedName),
    Application = erl_syntax:application(CalleeForm, [Piped | RestForms]),
    {at(Span, erl_syntax:block_expr([erl_syntax:match_expr(Piped, ExprForm), Application])),
     Context2};
expr(#e_call{span = Span, callee = Callee, args = Args}, Context) ->
    call(Span, Callee, Args, Context);
expr(#e_not{span = Span, expr = Expr}, Context) ->
    {Form, Context1} = expr(Expr, Context),
    {at(Span, erl_syntax:prefix_expr(erl_syntax:operator('not'), Form)), Context1};
expr(#e_selection{span = Span, expr = Expr, field = Field}, Context) ->
    {Form, Context1} = expr(Expr, Context),
    select(Span, Field, ern_typecheck:node_type(Expr), Form, Context1);
expr(#e_negation{span = Span, expr = Expr, member = undefined}, Context) ->
    {Form, Context1} = expr(Expr, Context),
    {at(Span, negate(resolved(ern_typecheck:node_type(Expr), Context), Form, Context)), Context1};
expr(#e_negation{span = Span, expr = Expr, member = Member}, Context) ->
    %% report §5.1, §4.9: `negate` in the operand type's namespace, or the
    %% member a requirement names
    {Form, Context1} = expr(Expr, Context),
    {Applied, Context2} = member_applied(Member, [Form], Context1),
    {at(Span, Applied), Context2};
expr(#e_binop{span = Span, operator = Operator, left = Left, right = Right, member = Member},
     Context)
  when is_record(Member, required_member);
       is_record(Member, known_member), Member#known_member.supplies =/= [];
       is_record(Member, known_member), length(Member#known_member.qualified_name) > 1 ->
    %% report §4.8, §4.9: an operator resolved to a member a requirement
    %% names, a member whose own requirement is supplied, or a member of a
    %% type a module declares; a prelude type's is the host's operation
    {Operands, Context1} = exprs([Left, Right], Context),
    {Applied, Context2} = member_applied(Member, Operands, Context1),
    {at(Span, ordered(Operator, Applied)), Context2};
expr(#e_binop{span = Span, operator = Operator, left = Left, right = Right}, Context) ->
    {[LeftForm, RightForm], Context1} = exprs([Left, Right], Context),
    case resolved(ern_typecheck:node_type(Left), Context) of
        {tcon, ['Float'], []}
          when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/' ->
            {[LeftName, RightName], Context2} = fresh_variables(2, "Operand", Context1),
            {at(Span, float_operation(Operator, LeftForm, RightForm, LeftName, RightName)),
             Context2};
        Type ->
            {at(Span, binop(Operator, Type, LeftForm, RightForm, Context)), Context1}
    end;
expr(#e_member{span = Span, supply = Supply}, Context) ->
    %% report §4.9: a member as a value
    {Form, Context1} = supply_form(Supply, Context),
    {at(Span, Form), function_value(Form, Context1)};
expr(#e_lambda{span = Span, params = Params, body = Body}, Context) ->
    {Patterns, Context1} = lists:mapfoldl(fun(#param{pattern = Pattern}, Acc) ->
                                              pattern(Pattern, Acc)
                                          end, Context, Params),
    {BodyForms, Context2} = body(Body, Context1),
    Clause = erl_syntax:clause(Patterns, none, BodyForms),
    {at(Span, erl_syntax:fun_expr([Clause])),
     Context2#emit_context{variables = Context#emit_context.variables,
                           builds_functions = true}};
expr(#e_if{span = Span, condition = Condition, then_branch = Then, else_branch = Else}, Context) ->
    {ConditionForm, Context1} = expr(Condition, Context),
    {[ThenForms, ElseForms], Context2} = lists:mapfoldl(fun body/2, Context1, [Then, Else]),
    Clauses = [erl_syntax:clause([erl_syntax:atom(true)], none, ThenForms),
               erl_syntax:clause([erl_syntax:atom(false)], none, ElseForms)],
    {at(Span, erl_syntax:case_expr(ConditionForm, Clauses)), Context2};
expr(#e_match{span = Span, scrutinee = ScrutineeExpr, clauses = Written}, Context) ->
    {ScrutineeForm, Context1} = expr(ScrutineeExpr, Context),
    {Form, Context2} = matched(ScrutineeForm, Written, Context1),
    {at(Span, Form), Context2};
expr(#e_receive{span = Span, clauses = Written, 'after' = After}, Context) ->
    %% report §6.3: a receive guard is a guard expression, which the
    %% checker holds it to, so it is an Erlang guard here, a top-level `let`
    %% it names, or a pattern's size names (§5.11), read into a variable
    %% before the receive; a message from a foreign process was checked by
    %% the proxy that delivered it (§8.4)
    {Clauses, {Reads, Context1}} = lists:mapfoldl(fun read_before/2, {[], Context}, Written),
    {Bindings, Receive, Context2} = receive_form(Clauses, After, Context1),
    {at(Span, with_bindings(Reads ++ Bindings, Receive)), Context2}.

%% Report §5.11: a top-level `let` a pattern's size names is read into a
%% variable when the match begins, after its scrutinee (§5.1: left to
%% right), which is then matched from a variable of its own.
matched(ScrutineeForm, Written, Context) ->
    case lists:mapfoldl(fun read_sizes/2, {[], Context}, Written) of
        {Clauses, {[], Context1}} ->
            match_clauses(ScrutineeForm, Clauses, Context1);
        {Clauses, {Reads, Context1}} ->
            read_first(ScrutineeForm, Reads, Clauses, Context1)
    end.

%% A match whose sizes read top-level lets, its scrutinee bound to a
%% variable before the reads.
read_first(ScrutineeForm, Reads, Clauses, Context) ->
    {[ScrutineeName], Context1} = fresh_variables(1, "Scrutinee", Context),
    Scrutinee = erl_syntax:variable(ScrutineeName),
    Evaluated = erl_syntax:match_expr(Scrutinee, ScrutineeForm),
    {Form, Context2} = match_clauses(Scrutinee, Clauses, Context1),
    {with_bindings([Evaluated | Reads], Form), Context2}.

%% A receive of Clauses with its `after`, if any: the bindings before it,
%% and the receive.
receive_form(Clauses, undefined, Context) ->
    {Bindings, ClauseForms, Context1} = receive_clauses(Clauses, Context),
    {Bindings, erl_syntax:receive_expr(ClauseForms), Context1};
receive_form(Clauses, #after_clause{timeout = Timeout, body = AfterBody}, Context) ->
    {Bindings, ClauseForms, Context1} = receive_clauses(Clauses, Context),
    {Enter, Wait, Context2} = timed_receive(ClauseForms, Timeout, AfterBody, Context1),
    {Bindings ++ Enter, Wait, Context2}.

%% A receive's clauses and the bindings they need. Report §6.9: a restart
%% a supervisor asks for arrives before every other message and is taken
%% here, first; report §8.4: a foreign message that did not match stands
%% in the mailbox as its fault, which is taken here before any clause of
%% the program's could bind it.
receive_clauses(Clauses, Context) ->
    {Parts, Context1} = lists:mapfoldl(fun simple_clauses/2, Context, Clauses),
    {Bindings, OwnForms} = join_parts(Parts),
    {[CauseName], Context2} = fresh_variables(1, "Cause", Context1),
    Cause = erl_syntax:variable(CauseName),
    ClauseForms = [erl_syntax:clause([erl_syntax:atom('$ern_restart')], none,
                                     [call_remote(ern_rt, restart_now, [])]),
                   erl_syntax:clause([erl_syntax:tuple([erl_syntax:atom('$ern_fault'), Cause])],
                                     none, [call_remote(ern_rt, fault, [Cause])])
                   | OwnForms],
    {Bindings, ClauseForms, Context2}.

%% A receive with an `after`: the bindings that enter it, and the call
%% that waits. Report §8.6: a timed receive counts itself in before, and
%% out first in every body, so the reaper knows it is not waiting. Report
%% §6.3: a time below 0 is 0, and none is too long; the host waits at most
%% 2^32 - 1 ms at once, so the receive is entered again until the deadline
%% has passed (ern_rt:deadline/1).
timed_receive(ClauseForms, Timeout, AfterBody, Context) ->
    {TimeoutForm, Context1} = expr(Timeout, Context),
    {AfterForms, Context2} = body(AfterBody, Context1),
    waiting(ClauseForms, TimeoutForm, AfterForms, Context2).

%% The timed receive of ClauseForms, entered again until its deadline has
%% passed: the bindings that enter it, and the call that waits.
waiting(ClauseForms, TimeoutForm, AfterForms, Context) ->
    {[DeadlineName, WaitName], Context1} = named_variables(["Deadline", "Wait"], Context),
    Deadline = erl_syntax:variable(DeadlineName),
    Remaining = call_remote(ern_rt, remaining, [Deadline]),
    Untimed = call_remote(ern_rt, untimed, []),
    Timed = [erl_syntax:clause(erl_syntax:clause_patterns(ClauseForm),
                               erl_syntax:clause_guard(ClauseForm),
                               [Untimed | erl_syntax:clause_body(ClauseForm)])
             || ClauseForm <- ClauseForms],
    WaitAgain = erl_syntax:application(erl_syntax:variable(WaitName), []),
    Due = erl_syntax:case_expr(
            Remaining,
            [erl_syntax:clause([erl_syntax:integer(0)], none, [Untimed | AfterForms]),
             erl_syntax:clause([erl_syntax:underscore()], none, [WaitAgain])]),
    Receive = erl_syntax:receive_expr(Timed, Remaining, [Due]),
    Wait = erl_syntax:named_fun_expr(erl_syntax:variable(WaitName),
                                     [erl_syntax:clause([], none, [Receive])]),
    Enter = [erl_syntax:match_expr(Deadline, call_remote(ern_rt, deadline, [TimeoutForm])),
             call_remote(ern_rt, timed, [])],
    {Enter, erl_syntax:application(Wait, []), Context1}.

exprs(Exprs, Context) ->
    lists:mapfoldl(fun expr/2, Context, Exprs).

%% Report §6.3, §5.11: each top-level `let` a receive clause's guard or its
%% pattern's sizes name, read into a fresh variable that names it in its
%% place.
read_before(Clause, Acc) ->
    {Clause1, Acc1} = read_sizes(Clause, Acc),
    read_guard(Clause1, Acc1).

read_guard(#clause{guard = undefined} = Clause, Acc) ->
    {Clause, Acc};
read_guard(#clause{guard = Guard} = Clause, Acc) ->
    {Guard1, Acc1} = read_top(Guard, Acc),
    {Clause#clause{guard = Guard1}, Acc1}.

%% Report §5.11: each top-level `let` a clause's pattern names in a size.
read_sizes(#clause{pattern = Pattern} = Clause, Acc) ->
    {Pattern1, Acc1} = read_pattern_sizes(Pattern, Acc),
    {Clause#clause{pattern = Pattern1}, Acc1}.

read_pattern_sizes(#bit_segment{specs = Specs} = Segment, Acc) ->
    {Specs1, Acc1} = lists:mapfoldl(fun({size, SizeExpr}, SpecAcc) ->
                                            {SizeExpr1, SpecAcc1} = read_top(SizeExpr, SpecAcc),
                                            {{size, SizeExpr1}, SpecAcc1};
                                       (Spec, SpecAcc) ->
                                            {Spec, SpecAcc}
                                    end, Acc, Specs),
    {Segment#bit_segment{specs = Specs1}, Acc1};
read_pattern_sizes(Node, Acc)
  when is_tuple(Node), tuple_size(Node) > 0, is_atom(element(1, Node)) ->
    [Tag | Fields] = tuple_to_list(Node),
    {Fields1, Acc1} = lists:mapfoldl(fun read_pattern_sizes/2, Acc, Fields),
    {list_to_tuple([Tag | Fields1]), Acc1};
read_pattern_sizes(Nodes, Acc) when is_list(Nodes) ->
    lists:mapfoldl(fun read_pattern_sizes/2, Acc, Nodes);
read_pattern_sizes(Other, Acc) ->
    {Other, Acc}.

read_top(#e_binop{left = Left, right = Right} = Binop, Acc) ->
    {Left1, Acc1} = read_top(Left, Acc),
    {Right1, Acc2} = read_top(Right, Acc1),
    {Binop#e_binop{left = Left1, right = Right1}, Acc2};
read_top(#e_not{expr = Expr} = Node, Acc) ->
    {Expr1, Acc1} = read_top(Expr, Acc),
    {Node#e_not{expr = Expr1}, Acc1};
read_top(#e_negation{expr = Expr} = Node, Acc) ->
    {Expr1, Acc1} = read_top(Expr, Acc),
    {Node#e_negation{expr = Expr1}, Acc1};
read_top(#e_var{referent = Referent} = Reference, {Reads, Context}) when Referent =/= var ->
    {Form, Context1} = expr(Reference, Context),
    {[ReadName], Context2} = fresh_variables(1, "Read", Context1),
    {Reference#e_var{namespace = [], name = ReadName, referent = var},
     {Reads ++ [erl_syntax:match_expr(erl_syntax:variable(ReadName), Form)],
      Context2#emit_context{variables = maps:put(ReadName, ReadName,
                                                 Context2#emit_context.variables)}}};
read_top(Expr, Acc) ->
    {Expr, Acc}.

%% A body: a block's statements spliced into the clause, else one expression.
body(#e_block{statements = Statements}, Context) ->
    {Forms, Context1} = block(Statements, Context),
    {Forms,
     Context1#emit_context{variables = Context#emit_context.variables,
                           locals = Context#emit_context.locals}};
body(Expr, Context) ->
    {Form, Context1} = expr(Expr, Context),
    {[Form], Context1}.

literal(int, Value) -> erl_syntax:integer(Value);
literal(float, Value) -> erl_syntax:float(Value);
literal(char, Value) -> erl_syntax:char(Value);
literal(string, Value) -> string_binary(Value);
literal(bool, Value) -> erl_syntax:atom(Value).

%% <<"text">>, with /utf8 only when a character is outside ASCII.
string_binary(Text) ->
    Chars = unicode:characters_to_list(Text),
    String = erl_syntax:string(Chars),
    Field = case lists:all(fun(Char) -> Char < 128 end, Chars) of
                true -> erl_syntax:binary_field(String);
                false -> erl_syntax:binary_field(String, [erl_syntax:atom(utf8)])
            end,
    erl_syntax:binary([Field]).

%%
%% Names
%%

%% A name used as a value: name_form(...) -> {Form, Context}. Report §4.2:
%% what the name refers to is the checker's referent, read and not decided
%% here.
name_form(Span, _, Name, var, Type, [],
          #emit_context{variables = Variables, locals = Locals} = Context) ->
    case Variables of
        #{Name := Variable} -> {variable_form(Variable), Context};
        _ ->
            #{Name := #local_fn{lifted_name = LiftedName}} = Locals,
            closure(LiftedName, captured_variables(Name, Context), arity_of(Type, Span), Context)
    end;
%% Appendix E.1: the library's Io.show and Io.debug as values too, by
%% what the checker supplied for the argument's type, named by the checker's
%% referent from another module and from the library's own, and never by
%% the namespace written
name_form(Span, _, Name,
          #remote_declaration{namespace = ['Io'], member_of = undefined, name = Name},
          Type, [Shown], Context)
  when Name =:= show; Name =:= debug ->
    io_value(Span, Name, Type, Shown, Context);
name_form(Span, _, Name, #own_declaration{member_of = undefined, name = Name}, Type, [Shown],
          #emit_context{erlang_module = 'ern@io'} = Context)
  when Name =:= show; Name =:= debug ->
    io_value(Span, Name, Type, Shown, Context);
%% Report §8.4, Appendix E.12: Foreign.from as a value, which gives its
%% argument as a foreign function's argument of the supplied type crosses
name_form(_Span, _, from,
          #remote_declaration{namespace = ['Foreign'], member_of = undefined, name = from},
          _Type, [#shown_type{type = Crossing}], Context) ->
    from_value(Crossing, Context);
name_form(_Span, _, from, #own_declaration{member_of = undefined, name = from}, _Type,
          [#shown_type{type = Crossing}], #emit_context{erlang_module = 'ern@foreign'} = Context) ->
    from_value(Crossing, Context);
%% Report §8.7: Peer.key as a value, its key's type's hash and text
%% supplied
name_form(_Span, _, key,
          #remote_declaration{namespace = ['Peer'], member_of = undefined, name = key},
          _Type, [Keyed], Context) ->
    {[Name], Context1} = fresh_variables(1, "Name", Context),
    {lambda([Name], call_remote(ern_peer, key, [erl_syntax:variable(Name)
                                                | key_type(Keyed, Context)])),
     Context1};
name_form(Span, _, _, {prelude, QualifiedName}, Type, [], Context) ->
    prelude_value(Span, QualifiedName, Type, Context);
name_form(_, _, _, #own_declaration{member_of = MemberOf, name = Name}, _, [], Context) ->
    {own_value(MemberOf, Name, Context), Context};
name_form(_, _, _, #remote_declaration{namespace = Declaring, member_of = MemberOf, name = Name},
          Type, [], Context) ->
    {remote_value(Declaring, MemberOf, Name, Type, Context), Context};
%% Report §4.9: a declaration with a requirement taken as a value is the
%% function with its members supplied
name_form(Span, Namespace, Name, Referent, Type, Supplies, Context) ->
    Arity = arity_of(Type, Span),
    {Function, Context1} = name_form(Span, Namespace, Name, Referent, widened(Type, Supplies), [],
                                     Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    Call = fun([FunctionVariable | SupplyVariables], Args) ->
                   erl_syntax:application(FunctionVariable, Args ++ SupplyVariables)
           end,
    supplied_lambda(Arity, [{"Function", Function} | supplied(SupplyForms)], Call, Context2).

%% Report §4.9: a function value with its members supplied, a lambda of
%% Arity parameters whose body is Call of the bound variables and the
%% parameters. Each of Bound, a variable's prefix and its form, is bound
%% before the lambda, so that it is computed once, where the value is.
supplied_lambda(Arity, Bound, Call, Context) ->
    {Params, Context1} = fresh_variables(Arity, "Argument", Context),
    {Variables, Context2} = named_variables([Prefix || {Prefix, _} <- Bound], Context1),
    Matches = [erl_syntax:match_expr(erl_syntax:variable(Variable), Form)
               || {Variable, {_, Form}} <- lists:zip(Variables, Bound)],
    Applied = Call([erl_syntax:variable(Variable) || Variable <- Variables],
                   [erl_syntax:variable(Param) || Param <- Params]),
    {erl_syntax:block_expr(Matches ++ [lambda(Params, Applied)]), Context2}.

%% The supplies' forms, each bound before the lambda to a variable of its
%% own.
supplied(SupplyForms) ->
    [{"Supplied", SupplyForm} || SupplyForm <- SupplyForms].

%% A function type with a parameter for each member supplied, which the
%% declaration's Erlang function takes after its written ones.
widened({tfn, Params, Effect, Result}, Supplies) ->
    {tfn, Params ++ [{tcon, ['Unit'], []} || _ <- Supplies], Effect, Result}.

%% Report §4.6: a `let` is a value, reached through its getter even where it
%% holds a function; a `fn` is the function itself.
own_value(MemberOf, Name, #emit_context{top_names = TopNames}) ->
    Local = erl_syntax:atom(function_name(MemberOf, Name)),
    case maps:get({MemberOf, Name}, TopNames) of
        value -> erl_syntax:application(Local, []);
        Arity -> erl_syntax:implicit_fun(Local, erl_syntax:integer(Arity))
    end.

remote_value(Declaring, MemberOf, Name, Type, #emit_context{env = Env} = Context) ->
    {HostModule, HostFunction} = remote_name(Declaring, MemberOf, Name, Context),
    case {is_value(Declaring, MemberOf, Name, Env), Type} of
        {false, {tfn, Params, _, _}} ->
            %% report §11.2: a unit never takes a second version, so the
            %% function keeps the code it was taken from
            remote_fun(HostModule, HostFunction, length(Params));
        _ ->
            call_remote(HostModule, HostFunction, [])
    end.

arity_of({tfn, Params, _, _}, _) -> length(Params);
arity_of(_, Span) -> fail(Span, "a function used as a value must have a function type").

%% Report §4.6: whether another module's declaration is a `let`, which
%% its interface says (§11.1).
is_value(Declaring, MemberOf, Name, Env) ->
    ern_typecheck:is_value(Declaring ++ [MemberOf || MemberOf =/= undefined] ++ [Name], Env).

%% Another Ernest module's declaration as a function of its unit.
remote_name(Declaring, MemberOf, Name, Context) ->
    {unit(Declaring, Context), function_name(MemberOf, Name)}.

%% Report §11.2: the unit a module's namespace calls, its Erlang name but
%% where the shell gave it another, a reload's version being a unit of its
%% own.
unit(Namespace, #emit_context{units = Units}) ->
    case Units of
        #{Namespace := Unit} -> Unit;
        _ -> ern_namespace:erlang_module(Namespace)
    end.

closure(LiftedName, Captures, Arity, Context) ->
    {Params, Context1} = fresh_variables(Arity, "Argument", Context),
    Args = [erl_syntax:variable(Variable) || Variable <- Captures ++ Params],
    Body = erl_syntax:application(erl_syntax:atom(LiftedName), Args),
    {erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(Param) || Param <- Params], none,
                                            [Body])]),
     Context1}.

%%
%% Calls
%%

call(Span, #e_var{referent = var, name = Name, supplies = Supplies}, Args, Context) ->
    #emit_context{variables = Variables, locals = Locals} = Context,
    {ArgForms, Context1} = exprs(Args, Context),
    case Variables of
        #{Name := Variable} ->
            {at(Span, erl_syntax:application(variable_form(Variable), ArgForms)), Context1};
        _ ->
            #{Name := #local_fn{lifted_name = LiftedName}} = Locals,
            Captures = [erl_syntax:variable(Variable)
                        || Variable <- captured_variables(Name, Context)],
            {SupplyForms, Context2} = supply_forms(Supplies, Context1),
            Application = erl_syntax:application(erl_syntax:atom(LiftedName),
                                                 Captures ++ ArgForms ++ SupplyForms),
            {at(Span, Application), Context2}
    end;
%% Appendix E.1: the library's Io.show and Io.debug, as name_form/7 names
%% them, written by what the checker supplied for the argument's type
call(Span, #e_var{referent = #remote_declaration{namespace = ['Io'], member_of = undefined,
                                                 name = Name},
                  supplies = [Shown]},
     [Argument], Context)
  when Name =:= show; Name =:= debug ->
    io_call(Span, Name, Argument, Shown, Context);
call(Span, #e_var{referent = #own_declaration{member_of = undefined, name = Name},
                  supplies = [Shown]}, [Argument],
     #emit_context{erlang_module = 'ern@io'} = Context)
  when Name =:= show; Name =:= debug ->
    io_call(Span, Name, Argument, Shown, Context);
%% Report §8.4, Appendix E.12: Foreign.from, the value as a foreign
%% function's argument of its type crosses, by what the checker supplied
call(Span, #e_var{referent = #remote_declaration{namespace = ['Foreign'], member_of = undefined,
                                                 name = from},
                  supplies = [#shown_type{type = Crossing}]},
     [Argument], Context) ->
    from_call(Span, Argument, Crossing, Context);
call(Span, #e_var{referent = #own_declaration{member_of = undefined, name = from},
                  supplies = [#shown_type{type = Crossing}]},
     [Argument], #emit_context{erlang_module = 'ern@foreign'} = Context) ->
    from_call(Span, Argument, Crossing, Context);
%% Report §8.7, Appendix E.27: Peer.key makes its key with its message
%% type's hash and text, which the checker supplied; Peer.spawn and
%% Peer.spawnMonitored send the function's identity and captures in place
%% of the function, and the spawn's site, as a spawn on this node keeps it
%% (§6.9)
call(Span, #e_var{referent = #remote_declaration{namespace = ['Peer'], member_of = undefined,
                                                 name = key},
                  supplies = [Keyed]},
     [Argument], Context) ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    {at(Span, call_remote(ern_peer, key, [ArgumentForm | key_type(Keyed, Context)])), Context1};
call(Span, #e_var{referent = #remote_declaration{namespace = ['Peer'], member_of = undefined,
                                                 name = Name}},
     [PeerName, Spawned | Rest], Context) when Name =:= spawn; Name =:= spawnMonitored ->
    {PeerForm, Context1} = expr(PeerName, Context),
    {SpawnedForm, Context2} = spawned(Spawned, Context1),
    {RestForms, Context3} = exprs(Rest, Context2),
    Function = case Name of spawn -> spawn; spawnMonitored -> spawn_monitored end,
    {at(Span, call_remote(ern_peer, Function,
                          [PeerForm, SpawnedForm | RestForms] ++ [site(Span, Context)])),
     Context3};
call(Span, #e_var{referent = {prelude, QualifiedName}} = Callee, Args, Context) ->
    %% report §4.2: the prelude's, `Prelude.x` among them
    {ArgForms, Context1} = exprs(Args, Context),
    prelude_call(Span, QualifiedName, Args, ArgForms, Callee, Context1);
call(Span, #e_var{referent = #own_declaration{member_of = MemberOf, name = Name},
                  supplies = Supplies}, Args, Context) ->
    {ArgForms, Context1} = exprs(Args, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    {at(Span, own_call(MemberOf, Name, ArgForms ++ SupplyForms, Context)), Context2};
%% report §4.9: a member called directly, `a.compare(x, y)` or a derived
%% compare's field
call(Span, #e_member{supply = #known_member{qualified_name = QualifiedName, member = Member,
                                            supplies = Supplies}},
     Args, Context) ->
    {ArgForms, Context1} = exprs(Args, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    {at(Span, member_call(QualifiedName, Member, ArgForms ++ SupplyForms, Context)), Context2};
call(Span,
     #e_var{referent = #remote_declaration{namespace = Declaring, member_of = MemberOf,
                                           name = Name},
            supplies = Supplies},
     Args, #emit_context{env = Env} = Context) ->
    {WrittenForms, Context1} = exprs(Args, Context),
    {SupplyForms, Context2} = supply_forms(Supplies, Context1),
    ArgForms = WrittenForms ++ SupplyForms,
    {HostModule, HostFunction} = remote_name(Declaring, MemberOf, Name, Context),
    %% report §4.6: calling a `let` applies what its getter answers;
    %% calling a `fn` is the call itself
    case is_value(Declaring, MemberOf, Name, Env) of
        true ->
            Get = call_remote(HostModule, HostFunction, []),
            {at(Span, erl_syntax:application(Get, ArgForms)), Context2};
        false ->
            {at(Span, call_remote(HostModule, HostFunction, ArgForms)), Context2}
    end;
call(Span, #e_constructor{} = Constructor, Args, Context) ->
    %% a single-positional constructor called as a function
    {ConstructorForm, Context1} = expr(Constructor, Context),
    {ArgForms, Context2} = exprs(Args, Context1),
    {at(Span, erl_syntax:application(ConstructorForm, ArgForms)), Context2};
call(Span, Callee, Args, Context) ->
    {CalleeForm, Context1} = expr(Callee, Context),
    {ArgForms, Context2} = exprs(Args, Context1),
    {at(Span, erl_syntax:application(CalleeForm, ArgForms)), Context2}.

io_call(Span, Name, Argument, Shown, Context) ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    {DescriptorForm, Context2} = supply_form(Shown, Context1),
    {at(Span, call_remote(ern_io, Name, [ArgumentForm, DescriptorForm])), Context2}.

%% Appendix E.1: Io.show or Io.debug as a value, the descriptor it writes
%% by supplied.
io_value(_Span, Name, {tfn, [_], _, _}, Shown, Context) ->
    {[Value], Context1} = fresh_variables(1, "Argument", Context),
    {DescriptorForm, Context2} = supply_form(Shown, Context1),
    {lambda([Value], call_remote(ern_io, Name, [erl_syntax:variable(Value), DescriptorForm])),
     Context2}.

from_call(Span, Argument, Crossing, Context) ->
    {[ArgumentForm], Context1} = exprs([Argument], Context),
    {Form, Context2} = exposed({Crossing, ArgumentForm}, Context1),
    {at(Span, Form), Context2}.

from_value(Crossing, Context) ->
    {[Value], Context1} = fresh_variables(1, "Argument", Context),
    {Form, Context2} = exposed({Crossing, erl_syntax:variable(Value)}, Context1),
    {lambda([Value], Form), Context2}.

%%
%% Supplies, report §4.9: what the checker resolved a requirement's members
%% to, each an argument the program does not write
%%

supply_forms(Supplies, Context) ->
    lists:mapfoldl(fun(Supply, Acc) ->
                       {Form, Acc1} = supply_form(Supply, Acc),
                       {Form, function_value(Form, Acc1)}
                   end, Context, Supplies).

%% A member the enclosing requirement names is the parameter it came in;
%% `show` at a known type is the type's descriptor; a known type's member
%% is that member as a function, its own requirement supplied.
supply_form(#required_member{variable = Variable, member = Member}, Context) ->
    {erl_syntax:variable(member_variable(Variable, Member, Context)), Context};
supply_form(#shown_type{type = Type}, #emit_context{env = Env, namespace = Namespace} = Context) ->
    %% report §4.9, Appendix E.1: a type built from type variables a
    %% requirement names `show` for is the descriptor composed of theirs,
    %% which came in as the requirement's members
    case ern_types:value_variables(Type, ern_typecheck:type_state(Env)) of
        [] ->
            {erl_syntax:abstract(descriptor(Type, Context)), Context};
        Holes ->
            Descriptor = ern_descriptor:describe(Type, Env, Namespace, Holes),
            {holes_filled(Descriptor, Context), Context}
    end;
supply_form(#known_member{qualified_name = [_] = QualifiedName, member = Member,
                          supplies = []}, Context) ->
    member_value(QualifiedName, Member, Context);
supply_form(#known_member{qualified_name = QualifiedName, member = Member, supplies = Supplies},
            Context) ->
    {SupplyForms, Context1} = supply_forms(Supplies, Context),
    Arity = member_arity(Member),
    case SupplyForms of
        [] ->
            {member_value(QualifiedName, Member, Arity, Context1), Context1};
        _ ->
            Call = fun(SupplyVariables, Args) ->
                           member_call(QualifiedName, Member, Args ++ SupplyVariables, Context1)
                   end,
            supplied_lambda(Arity, supplied(SupplyForms), Call, Context1)
    end.

%% A descriptor as a form, each hole the descriptor its variable's `show`
%% came in as.
holes_filled({hole, Id}, Context) ->
    erl_syntax:variable(member_variable({tvar, Id}, show, Context));
holes_filled(Part, Context) when is_tuple(Part) ->
    erl_syntax:tuple([holes_filled(Inner, Context) || Inner <- tuple_to_list(Part)]);
holes_filled(Parts, Context) when is_list(Parts) ->
    erl_syntax:list([holes_filled(Inner, Context) || Inner <- Parts]);
holes_filled(Leaf, _) ->
    erl_syntax:abstract(Leaf).

%% The parameter a requirement's member came in, in the declaration being
%% emitted or one that encloses it.
member_variable(Variable, Member, #emit_context{members = Members} = Context) ->
    {tvar, Id} = resolved(Variable, Context),
    maps:get({Id, Member}, Members).

member_arity(negate) -> 1;
member_arity(_) -> 2.

%% A member of a declared type as a function value: a local function of
%% this module's, or another module's unit's (report §11.2).
member_value(QualifiedName, Member, Arity,
             #emit_context{namespace = Namespace, env = Env} = Context) ->
    MemberOf = lists:last(QualifiedName),
    MemberQualifiedName = ern_typecheck:session_member(QualifiedName, Member, Env),
    Function = function_name(MemberOf, Member),
    case lists:droplast(lists:droplast(MemberQualifiedName)) of
        Namespace -> erl_syntax:implicit_fun(erl_syntax:atom(Function), erl_syntax:integer(Arity));
        Declaring -> remote_fun(unit(Declaring, Context), Function, Arity)
    end.

%% Report §4.6: a call of the module's own declaration, a `let` through
%% what its getter answers.
own_call(MemberOf, Name, ArgForms, #emit_context{top_names = TopNames}) ->
    Local = erl_syntax:atom(function_name(MemberOf, Name)),
    case maps:get({MemberOf, Name}, TopNames) of
        value -> erl_syntax:application(erl_syntax:application(Local, []), ArgForms);
        _ -> erl_syntax:application(Local, ArgForms)
    end.

%% fun M:F/A
remote_fun(HostModule, HostFunction, Arity) ->
    erl_syntax:implicit_fun(erl_syntax:atom(HostModule), erl_syntax:atom(HostFunction),
                            erl_syntax:integer(Arity)).

call_remote(HostModule, HostFunction, Args) ->
    erl_syntax:application(erl_syntax:module_qualifier(erl_syntax:atom(HostModule),
                                                       erl_syntax:atom(HostFunction)),
                           Args).

%%
%% The prelude, report §9
%%

prelude_call(Span, [self], [], [], _, Context) ->
    {at(Span, call_remote(ern_rt, self, [])), Context};
prelude_call(Span, [send], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, send, ArgForms)), Context};
prelude_call(Span, [answer], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, answer, ArgForms)), Context};
prelude_call(Span, [via], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, via, ArgForms)), Context};
prelude_call(Span, [monitor], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, monitor, ArgForms)), Context};
prelude_call(Span, [kill], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, kill, ArgForms)), Context};
prelude_call(Span, [spawn], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, spawn, ArgForms ++ [site(Span, Context)])), Context};
prelude_call(Span, [spawnMonitored], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, spawn_monitored, ArgForms ++ [site(Span, Context)])), Context};
prelude_call(Span, ['Address', call], _, ArgForms, #e_var{type = Type}, Context) ->
    {Form, Context1} = reply_call(call, ArgForms, Type, Context),
    {at(Span, Form), Context1};
prelude_call(Span, ['Address', callForever], _, ArgForms, #e_var{type = Type}, Context) ->
    {Form, Context1} = reply_call(call_forever, ArgForms, Type, Context),
    {at(Span, Form), Context1};
prelude_call(Span, [restarting], _, ArgForms, _, Context) ->
    {at(Span, call_remote(ern_rt, restarting, ArgForms)), Context};
prelude_call(Span, [fault], _, [CauseForm], _, Context) ->
    {at(Span, call_remote(ern_rt, fault, [CauseForm])), Context};
prelude_call(Span, ['Int', Operator], [Left | _], [LeftForm, RightForm], _, Context)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
       Operator =:= '%' ->
    OperandType = resolved(ern_typecheck:node_type(Left), Context),
    {at(Span, binop(Operator, OperandType, LeftForm, RightForm, Context)), Context};
prelude_call(Span, ['Int', negate], _, [OperandForm], _, Context) ->
    {at(Span, erl_syntax:prefix_expr(erl_syntax:operator('-'), OperandForm)), Context};
prelude_call(Span, [TypeName, '<>'], [Left | _], [LeftForm, RightForm], _, Context)
  when TypeName =:= 'String'; TypeName =:= 'List'; TypeName =:= 'Bytes' ->
    OperandType = resolved(ern_typecheck:node_type(Left), Context),
    {at(Span, binop('<>', OperandType, LeftForm, RightForm, Context)), Context};
prelude_call(Span, [Namespace | Rest], _, ArgForms, _, Context) when Rest =/= [] ->
    %% a stdlib function: the namespace's module
    Module = ern_namespace:erlang_module([Namespace]),
    {at(Span, call_remote(Module, lists:last(Rest), ArgForms)), Context};
prelude_call(Span, QualifiedName, _, _, _, _) ->
    fail(Span, "no emission for " ++ ern_namespace:text(QualifiedName)).

%% Report §6.6, §8.4: `Address.call` or `Address.callForever`, of type T,
%% and in a program what an answer from foreign code is checked by, the
%% Reply's type, as a foreign function's return is; a call the standard
%% library makes is the runtime's own, and checks nothing.
reply_call(Function, ArgForms, _, #emit_context{standard = true} = Context) ->
    {call_remote(ern_rt, Function, ArgForms), Context};
reply_call(Function, ArgForms, Type, Context) ->
    {tfn, [_, {tfn, [ReplyType], _, _} | _], _, _} = resolved(Type, Context),
    {tcon, ['Reply'], [AnswerType]} = resolved(ReplyType, Context),
    {Check, Context1} = case descriptor(AnswerType, Context) of
                            Unchecked when Unchecked =:= any; Unchecked =:= foreign ->
                                {erl_syntax:atom(none), Context};
                            Descriptor ->
                                {DescriptorForm, Described} = descriptor_form(Descriptor, Context),
                                Text = check_text("reply does not match ", AnswerType, Context),
                                {erl_syntax:tuple([DescriptorForm, Text]), Described}
                        end,
    {call_remote(ern_rt, Function, ArgForms ++ [Check]), Context1}.

%% A prelude name taken as a value: prelude_value(...) -> {Form, Context}.
prelude_value(Span, [spawn], _, Context) ->
    %% a closure, since spawn takes the site as a second argument
    {[Function], Context1} = fresh_variables(1, "Argument", Context),
    ArgForms = [erl_syntax:variable(Function), site(Span, Context)],
    {lambda([Function], call_remote(ern_rt, spawn, ArgForms)), Context1};
prelude_value(Span, [spawnMonitored], _, Context) ->
    {[Function, Wrap], Context1} = fresh_variables(2, "Argument", Context),
    ArgForms = [erl_syntax:variable(Variable) || Variable <- [Function, Wrap]]
        ++ [site(Span, Context)],
    {lambda([Function, Wrap], call_remote(ern_rt, spawn_monitored, ArgForms)), Context1};
prelude_value(Span, ['Address', Name], Type, Context) when Name =:= call; Name =:= callForever ->
    Function = case Name of call -> call; callForever -> call_forever end,
    {Variables, Context1} = fresh_variables(arity_of(Type, Span), "Argument", Context),
    ArgForms = [erl_syntax:variable(Variable) || Variable <- Variables],
    {Body, Context2} = reply_call(Function, ArgForms, Type, Context1),
    {lambda(Variables, Body), Context2};
prelude_value(_, ['Int', Member], _, Context) when Member =/= compare ->
    member_value(['Int'], Member, Context);
prelude_value(_, [TypeName, '<>'], _, Context) ->
    member_value([TypeName], '<>', Context);
prelude_value(Span, [Name], Type, Context) ->
    case lists:member(Name, [self, send, answer, via, monitor, kill, fault, restarting]) of
        true -> {remote_fun(ern_rt, Name, arity_of(Type, Span)), Context};
        false -> fail(Span, "no emission for " ++ atom_to_list(Name))
    end;
prelude_value(_, [Namespace | Rest], Type, Context) ->
    Form = case Type of
               {tfn, Params, _, _} ->
                   remote_fun(ern_namespace:erlang_module([Namespace]), lists:last(Rest),
                              length(Params));
               _ ->
                   %% a stdlib value: Map.empty, Set.empty
                   call_remote(ern_namespace:erlang_module([Namespace]), lists:last(Rest), [])
           end,
    {Form, Context}.

%% Report §9.6, §4.8: a prelude type's member as a value: Int's arithmetic
%% and negate, and `<>`, inline as the operators are, and any other its
%% type's module's function, of the member's arity.
member_value(['Int'], negate, Context) ->
    {[Operand], Context1} = fresh_variables(1, "Operand", Context),
    Negated = erl_syntax:prefix_expr(erl_syntax:operator('-'), erl_syntax:variable(Operand)),
    {lambda([Operand], Negated), Context1};
member_value(['Int'] = QualifiedName, Operator, Context)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
       Operator =:= '%' ->
    operator_value(Operator, QualifiedName, Context);
member_value(QualifiedName, '<>', Context) ->
    operator_value('<>', QualifiedName, Context);
member_value([TypeName], Member, Context) ->
    {remote_fun(ern_namespace:erlang_module([TypeName]), Member, member_arity(Member)), Context}.

operator_value(Operator, QualifiedName, Context) ->
    {[Left, Right], Context1} = fresh_variables(2, "Operand", Context),
    Body = binop(Operator, {tcon, QualifiedName, []}, erl_syntax:variable(Left),
                 erl_syntax:variable(Right), Context),
    {lambda([Left, Right], Body), Context1}.

lambda(Variables, Body) ->
    erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(Variable) || Variable <- Variables],
                                           none, [Body])]).

%% Report §11.2: Context marked as building a function value where Form,
%% what an expression or a supply emits, is one of this module's code, a
%% lambda's fun, a function of the module taken as a value, or one bound
%% beside the values it closes over; a function of another module's is
%% that module's code. A fun the emitter makes for its own use, a timed
%% receive's loop, a guard's way to the clauses after it, the body
%% alternatives share or a foreign call counted, is called where it is made
%% and held by nothing, and is no function value: it is never what an
%% expression emits.
function_value(Form, Context) ->
    case is_own_function(Form) of
        true -> Context#emit_context{builds_functions = true};
        false -> Context
    end.

is_own_function(Form) ->
    case erl_syntax:type(Form) of
        fun_expr -> true;
        named_fun_expr -> true;
        implicit_fun -> erl_syntax:type(erl_syntax:implicit_fun_name(Form)) =/= module_qualifier;
        block_expr -> is_own_function(lists:last(erl_syntax:block_expr_body(Form)));
        _ -> false
    end.

%% Whether a descriptor describes a function anywhere inside it.
holds_function({function, _, _, _, _, _}) -> true;
holds_function(Part) when is_tuple(Part) -> lists:any(fun holds_function/1, tuple_to_list(Part));
holds_function(Parts) when is_list(Parts) -> lists:any(fun holds_function/1, Parts);
holds_function(_) -> false.

%% Report §6.9: the function that called `spawn`, qualified, and the line;
%% report §11.2: a reload's version's under the version's namespace,
%% `Counter$2.service:5`, as its unit is named. In the session, as the
%% session writes names: a function an input declares by its own name, and
%% the input's expression as its diagnostics name it, `input 3`; the line
%% as they count it. The input's name is asked of the shell when the spawn
%% runs, and is not the module's code: an input typed again then compiles
%% to the code it did before, and the host keeps an entry for each lambda
%% of each version it loads (docs/memory.md).
site(Span,
     #emit_context{site_namespace = SiteNamespace, erlang_module = ErlangModule,
                   declaration = Declaration, session_offset = SessionOffset}) ->
    {Line, _, _} = ern_diagnostic:span(Span),
    case {SessionOffset, Declaration} of
        {false, _} ->
            text_site([ern_namespace:text(SiteNamespace ++ Declaration), ":",
                       integer_to_list(Line)]);
        {Offset, ['$input']} ->
            call_remote(ern_shell, input_site, [erl_syntax:atom(ErlangModule),
                                                erl_syntax:integer(Line + Offset)]);
        {Offset, _} ->
            text_site([ern_namespace:text(Declaration), ":", integer_to_list(Line + Offset)])
    end.

text_site(SiteParts) ->
    string_binary(unicode:characters_to_binary(SiteParts)).

%% Report §8.7, Appendix H: a key's message type's hash, of its canonical
%% form, and its text, as the checker printed it.
key_type(#type_text{text = Text, type = Type}, #emit_context{canonical = #{keys := Keys}}) ->
    [erl_syntax:abstract(maps:get(Type, Keys)),
     string_binary(unicode:characters_to_binary(Text))].

%%
%% Operators, report §4.8
%%

%% Report §4.8, §3.10, §5.1: by the operand type. Int's arithmetic, and
%% the ordering of the four ordered prelude types, Int, Float, String and
%% Char, are Erlang's operators; Float's arithmetic is
%% float_operation/5; a user type's operator is its member, applied by
%% member_applied/3 and ordered/2, and never reaches here.
binop(Operator, {tcon, ['Int'], []}, Left, Right, _)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*' ->
    erl_syntax:infix_expr(Left, erl_syntax:operator(Operator), Right);
binop('/', {tcon, ['Int'], []}, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('div'), Right);
binop('%', {tcon, ['Int'], []}, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('rem'), Right);
binop('<>', {tcon, ['String'], []}, Left, Right, _) -> binary_append(Left, Right);
binop('<>', {tcon, ['Bytes'], []}, Left, Right, _) -> binary_append(Left, Right);
%% Report §9.6: `<>` on a prelude type whose module provides it in Ernest,
%% `List.<>` and `Path.<>`, a call of that module's, and a local call within it
binop('<>', {tcon, [Name], _}, Left, Right, #emit_context{namespace = Namespace}) ->
    case Namespace of
        [Name] -> erl_syntax:application(erl_syntax:atom('<>'), [Left, Right]);
        _ -> call_remote(ern_namespace:erlang_module([Name]), '<>', [Left, Right])
    end;
binop('==', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=:='), Right);
binop('!=', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=/='), Right);
binop('&&', _, Left, Right, _) ->
    erl_syntax:infix_expr(Left, erl_syntax:operator('andalso'), Right);
binop('||', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('orelse'), Right);
binop('::', _, Left, Right, _) -> erl_syntax:cons(Left, Right);
binop('<=', _, Left, Right, _) -> erl_syntax:infix_expr(Left, erl_syntax:operator('=<'), Right);
binop(Operator, _, Left, Right, _) when Operator =:= '<'; Operator =:= '>'; Operator =:= '>=' ->
    erl_syntax:infix_expr(Left, erl_syntax:operator(Operator), Right).

%% Report §3.1, §7.4: a Float operation inline, its operands bound first so
%% that only its own badarith becomes the float fault; an Int division by
%% zero inside an operand stays that fault.
float_operation(Operator, Left, Right, LeftName, RightName) ->
    Cause = erl_syntax:string("float arithmetic error"),
    Text = erl_syntax:binary([erl_syntax:binary_field(Cause)]),
    Badarith = erl_syntax:class_qualifier(erl_syntax:atom(error), erl_syntax:atom(badarith)),
    Handler = erl_syntax:clause([Badarith], none, [call_remote(ern_rt, fault, [Text])]),
    Plain = erl_syntax:infix_expr(erl_syntax:variable(LeftName), erl_syntax:operator(Operator),
                                  erl_syntax:variable(RightName)),
    %% report §3.1: under round to nearest a sum or a difference of operands
    %% that are not negative zero is never one, and no operand is; a product
    %% or a quotient may be, and + 0.0 turns it into 0.0 and keeps any other
    Operation = case Operator of
                    _ when Operator =:= '*'; Operator =:= '/' ->
                        erl_syntax:infix_expr(Plain, erl_syntax:operator('+'),
                                              erl_syntax:float(0.0));
                    _ ->
                        Plain
                end,
    erl_syntax:block_expr([erl_syntax:match_expr(erl_syntax:variable(LeftName), Left),
                           erl_syntax:match_expr(erl_syntax:variable(RightName), Right),
                           erl_syntax:try_expr([Operation], [Handler])]).

negate({tcon, ['Float'], []}, Form, _) ->
    %% report §3.1: 0.0 - x, so that negating 0.0 gives 0.0
    erl_syntax:infix_expr(erl_syntax:float(0.0), erl_syntax:operator('-'), Form);
negate(_, Form, _) -> erl_syntax:prefix_expr(erl_syntax:operator('-'), Form).

%% Report §4.9: a member applied to its operands, the parameter a
%% requirement's member came in, or a known type's member with its own
%% requirement supplied.
member_applied(#required_member{variable = Variable, member = Member}, Args, Context) ->
    Function = erl_syntax:variable(member_variable(Variable, Member, Context)),
    {erl_syntax:application(Function, Args), Context};
member_applied(#known_member{qualified_name = QualifiedName, member = Member,
                             supplies = Supplies}, Args, Context) ->
    {SupplyForms, Context1} = supply_forms(Supplies, Context),
    {member_call(QualifiedName, Member, Args ++ SupplyForms, Context1), Context1}.

%% Report §3.10: an ordering is its compare against Less or Greater; any
%% other operator is the member's own result.
ordered(Operator, Compared) ->
    case Operator of
        '<' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=:='), erl_syntax:atom('Less'));
        '>' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=:='),
                                     erl_syntax:atom('Greater'));
        '<=' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=/='),
                                      erl_syntax:atom('Greater'));
        '>=' -> erl_syntax:infix_expr(Compared, erl_syntax:operator('=/='),
                                      erl_syntax:atom('Less'));
        _ -> Compared
    end.

%% A member of the type QualifiedName: a local function when the type is
%% this module's, otherwise a call into the module that owns it (report
%% §4.2).
member_call([_] = QualifiedName, Name, Args, #emit_context{namespace = Namespace}) ->
    %% report §9.6: a prelude type's member is its module's, which exports
    %% the runtime's own operation as a function
    case Namespace of
        QualifiedName -> erl_syntax:application(erl_syntax:atom(function_atom(Name)), Args);
        _ -> call_remote(ern_namespace:erlang_module(QualifiedName), function_atom(Name), Args)
    end;
member_call(QualifiedName, Name, Args, #emit_context{namespace = Namespace, env = Env} = Context) ->
    MemberOf = lists:last(QualifiedName),
    %% report §11.2: at the prompt a later input may have declared it
    MemberQualifiedName = ern_typecheck:session_member(QualifiedName, Name, Env),
    case lists:droplast(lists:droplast(MemberQualifiedName)) of
        Namespace -> erl_syntax:application(erl_syntax:atom(function_name(MemberOf, Name)), Args);
        Declaring -> call_remote(unit(Declaring, Context), function_name(MemberOf, Name), Args)
    end.

%% <<A/binary, B/binary>>, with a string literal as a plain segment and an
%% inner append flattened, so "a" <> f(x) <> "b" is one binary.
binary_append(Left, Right) ->
    erl_syntax:binary(segments(Left) ++ segments(Right)).

segments(Form) ->
    case erl_syntax:type(Form) of
        binary -> erl_syntax:binary_fields(Form);
        string -> [erl_syntax:binary_field(Form)];
        _ -> [erl_syntax:binary_field(Form, [erl_syntax:atom(binary)])]
    end.

resolved(Type, #emit_context{env = Env}) ->
    ern_typecheck:resolve_type(Type, Env).

%%
%% The foreign boundary, report §8.4: a declared type as the term
%% ern_boundary interprets
%%

%% Form's value checked against Type and the fault's text naming Shown
%% (report §7.4, §8.4). A word's check is written in place; a value that
%% holds no function, address or Reply to arm and no float to make the
%% language's is checked alone (ern_boundary:check/3); a type variable a
%% parameter names matches any value, and is not checked.
check_form(Type, Shown, Form, Prefix, Context) ->
    Text = check_text(Prefix, Shown, Context),
    case descriptor(Type, Context) of
        Unchecked when Unchecked =:= any; Unchecked =:= foreign ->
            {Form, Context};
        Word when Word =:= int; Word =:= bool; Word =:= bytes; Word =:= float ->
            {[Variable], Context1} = fresh_variables(1, "Checked", Context),
            VariableForm = erl_syntax:variable(Variable),
            Test = erl_syntax:application(erl_syntax:atom(word_test(Word)), [VariableForm]),
            %% report §3.1: X + 0.0 is 0.0 for either zero, and X otherwise
            Value = case Word of
                        float -> erl_syntax:infix_expr(VariableForm, erl_syntax:operator('+'),
                                                       erl_syntax:float(0.0));
                        _ -> VariableForm
                    end,
            Fault = call_remote(ern_rt, fault, [Text]),
            {erl_syntax:case_expr(Form, [erl_syntax:clause([VariableForm], Test, [Value]),
                                         erl_syntax:clause([erl_syntax:underscore()], none,
                                                           [Fault])]), Context1};
        Word when is_atom(Word) ->
            {call_remote(ern_boundary, value, [erl_syntax:abstract(Word), Form, Text]), Context};
        Descriptor ->
            {DescriptorForm, Context1} = descriptor_form(Descriptor, Context),
            Check = case is_plain(Descriptor) of
                        true -> check;
                        false -> value
                    end,
            {call_remote(ern_boundary, Check, [DescriptorForm, Form, Text]), Context1}
    end.

word_test(int) -> is_integer;
word_test(bool) -> is_boolean;
word_test(bytes) -> is_binary;
word_test(float) -> is_float.

%% Whether a descriptor holds no function, no address, no Reply and no
%% float, as ern_boundary reads one: a checked value of it is the value
%% itself.
is_plain(float) -> false;
is_plain({address, _, _}) -> false;
is_plain({reply, _, _}) -> false;
is_plain({function, _, _, _, _, _}) -> false;
is_plain(Part) when is_tuple(Part) -> lists:all(fun is_plain/1, tuple_to_list(Part));
is_plain(Parts) when is_list(Parts) -> lists:all(fun is_plain/1, Parts);
is_plain(_) -> true.

%% An argument of a foreign function as it is given (§8.4): one with an
%% address inside, through the proxy that checks what foreign code sends
%% it, and a Reply foreign code gave back as it gave it; a function,
%% wrapped to check the arguments foreign code calls it with; any other,
%% and every argument of the standard library's own, as it is.
exposed({_, Arg}, #emit_context{standard = true} = Context) ->
    {Arg, Context};
exposed({Type, Arg}, Context) ->
    case crosses(descriptor(Type, Context)) of
        true ->
            {DescriptorForm, Context1} = type_descriptor_form(Type, Context),
            {call_remote(ern_boundary, expose, [DescriptorForm, Arg]), Context1};
        false ->
            {Arg, Context}
    end.

%% The type variables a type holds.
type_variables({tvar, _} = Variable) -> [Variable];
type_variables(Type) when is_tuple(Type) ->
    lists:append([type_variables(Element) || Element <- tuple_to_list(Type)]);
type_variables(Types) when is_list(Types) ->
    lists:append([type_variables(Element) || Element <- Types]);
type_variables(_) -> [].

%% The type with each of Variables as `Never`.
as_never([], Type) -> Type;
as_never(Variables, {tvar, _} = Variable) ->
    case lists:member(Variable, Variables) of
        true -> {tcon, ['Never'], []};
        false -> Variable
    end;
as_never(Variables, Type) when is_tuple(Type) ->
    list_to_tuple([as_never(Variables, Element) || Element <- tuple_to_list(Type)]);
as_never(Variables, Types) when is_list(Types) ->
    [as_never(Variables, Element) || Element <- Types];
as_never(_, Type) -> Type.

%% A type's descriptor as a form.
type_descriptor_form(Type, Context) ->
    descriptor_form(descriptor(Type, Context), Context).

%% A descriptor as a form: a literal when it is a word, else a call of a
%% module function that returns it, one per distinct descriptor.
descriptor_form(Descriptor, Context) when is_atom(Descriptor) ->
    {erl_syntax:abstract(Descriptor), Context};
descriptor_form(Descriptor, Context) ->
    case Context#emit_context.descriptors of
        #{Descriptor := Name} ->
            {erl_syntax:application(erl_syntax:atom(Name), []), Context};
        Descriptors ->
            Name = list_to_atom("$type_" ++ integer_to_list(map_size(Descriptors) + 1)),
            Clause = erl_syntax:clause([], none, [built_descriptor(Descriptor)]),
            Function = erl_syntax:function(erl_syntax:atom(Name), [Clause]),
            %% report §11.2: a function's descriptor builds the function
            %% that checks the one crossing, of this module's code, which
            %% the program holds in its place
            Builds = Context#emit_context.builds_functions orelse holds_function(Descriptor),
            {erl_syntax:application(erl_syntax:atom(Name), []),
             Context#emit_context{descriptors = Descriptors#{Descriptor => Name},
                                  lifted = [Function | Context#emit_context.lifted],
                                  builds_functions = Builds}}
    end.

%% A descriptor as the form that builds it. A function's descriptor also
%% carries the maker of its checked wrapper, a fun of its arity that checks
%% each result (report §7.4), which only generated code can spell for every
%% arity; ern_boundary applies it to a function value foreign code gives,
%% and to the result's descriptor closed over the recursive types around it.
built_descriptor({function, Arity, ResultDescriptor, Text, ParamDescriptors, ParamTexts}) ->
    Function = erl_syntax:variable('Function'),
    Result = erl_syntax:variable('Result'),
    Bound = erl_syntax:variable('Bound'),
    Args = [erl_syntax:variable(list_to_atom("Argument" ++ integer_to_list(Index)))
            || Index <- lists:seq(1, Arity)],
    Check = call_remote(ern_boundary, value,
                        [Result, erl_syntax:application(Function, Args),
                         erl_syntax:abstract(Text)]),
    Wrapper = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [Check])]),
    Maker = erl_syntax:fun_expr([erl_syntax:clause([Function, Result], none, [Wrapper])]),
    %% report §8.4: the same function crossing into foreign code, wherever
    %% it stands in what crosses, each argument checked against its
    %% parameter's type, the recursive types around it in Bound
    Checked = [call_remote(ern_boundary, argument, [built_descriptor(Descriptor), Argument,
                                                    erl_syntax:abstract(ParamText), Bound])
               || {Descriptor, Argument, ParamText}
                      <- lists:zip3(ParamDescriptors, Args, ParamTexts)],
    Exposed = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [called(Function, Checked)])]),
    Exposer = erl_syntax:fun_expr([erl_syntax:clause([Function, Bound], none, [Exposed])]),
    erl_syntax:tuple([erl_syntax:atom('fun'), erl_syntax:integer(Arity),
                      built_descriptor(ResultDescriptor),
                      erl_syntax:abstract(Text), Maker, Exposer]);
built_descriptor(Tuple) when is_tuple(Tuple) ->
    erl_syntax:tuple([built_descriptor(Element) || Element <- tuple_to_list(Tuple)]);
built_descriptor(Elements) when is_list(Elements) ->
    erl_syntax:list([built_descriptor(Element) || Element <- Elements]);
built_descriptor(Other) ->
    erl_syntax:abstract(Other).

%% Report §7.4: the program's Function where foreign code calls it, an
%% exception it raises the fault it would be anywhere (called_raised/3).
called(Function, Arguments) ->
    [Class, Error, Trace] = Raised = [erl_syntax:variable(Name)
                                      || Name <- ['Class', 'Error', 'Trace']],
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(Class, Error, Trace)], none,
                                [call_remote(ern_boundary, called_raised, Raised)]),
    erl_syntax:try_expr([erl_syntax:application(Function, Arguments)], [Handler]).

check_text(Prefix, Type, Context) ->
    string_binary(ern_descriptor:cause(Prefix, Type, Context#emit_context.env)).

%% Appendix E.1, §8.4: the descriptor of a type, which ern_descriptor
%% makes, an abstract type seen from this module.
descriptor(Type, #emit_context{env = Env, namespace = Namespace}) ->
    ern_descriptor:describe(Type, Env, Namespace).

%% Whether a descriptor holds what crossing into foreign code changes: an
%% address, a Reply, or a function.
crosses({address, _, _}) -> true;
crosses({reply, _, _}) -> true;
crosses({function, _, _, _, _, _}) -> true;
crosses(Part) when is_tuple(Part) -> lists:any(fun crosses/1, tuple_to_list(Part));
crosses(Parts) when is_list(Parts) -> lists:any(fun crosses/1, Parts);
crosses(_) -> false.

%%
%% Constructors, report §8.4
%%

%% Report §3.5, §8.4: a selected field. A named constructor is its tag and
%% its fields in declared order, so the field is one element of the tuple
%% where every constructor has it at one place, and a case on the tag where
%% the places differ.
select(Span, Field, OperandType, Form, #emit_context{env = Env} = Context) ->
    {tcon, QualifiedName, _} = ern_typecheck:resolve_type(OperandType, Env),
    #type_info{constructors = Constructors} = ern_typecheck:lookup_type(QualifiedName, Env),
    Places = [{ConstructorName, place(Field, Names) + 1, length(Names)}
              || #constructor_info{name = ConstructorName, fields = {named, Names}}
                     <- Constructors],
    case lists:usort([Index || {_, Index, _} <- Places]) of
        [Index] ->
            {at(Span, call_remote(erlang, element, [erl_syntax:integer(Index), Form])), Context};
        _ ->
            {[Variable], Context1} = fresh_variables(1, "Field", Context),
            VariableForm = erl_syntax:variable(Variable),
            Clauses = [erl_syntax:clause([selecting_pattern(ConstructorName, Index, Count,
                                                            VariableForm)],
                                         none, [VariableForm])
                       || {ConstructorName, Index, Count} <- Places],
            {at(Span, erl_syntax:case_expr(Form, Clauses)), Context1}
    end.

%% A named constructor's tuple as a pattern, the field at Index bound to the
%% variable and the others `_`.
selecting_pattern(ConstructorName, Index, Count, VariableForm) ->
    Fields = [case Place of
                  Index -> VariableForm;
                  _ -> erl_syntax:underscore()
              end || Place <- lists:seq(2, Count + 1)],
    erl_syntax:tuple([erl_syntax:atom(ConstructorName) | Fields]).

place(Field, [Field | _]) -> 1;
place(Field, [_ | Rest]) -> 1 + place(Field, Rest).

constructor_expr(Span, Namespace, Name, Base, Args, #emit_context{env = Env} = Context) ->
    #constructor_info{fields = Fields} =
        ern_typecheck:lookup_constructor(Span, Namespace, Name, Env),
    Tag = erl_syntax:atom(Name),
    case {Fields, Args} of
        {none, none} ->
            {at(Span, Tag), Context};
        {positional, none} ->
            %% as a function value
            {[Variable], Context1} = fresh_variables(1, "Argument", Context),
            VariableForm = erl_syntax:variable(Variable),
            Wrap = erl_syntax:clause([VariableForm], none, [erl_syntax:tuple([Tag, VariableForm])]),
            {at(Span, erl_syntax:fun_expr([Wrap])),
             Context1#emit_context{builds_functions = true}};
        {positional, {positional, Arg}} ->
            {Form, Context1} = expr(Arg, Context),
            {at(Span, erl_syntax:tuple([Tag, Form])), Context1};
        {{named, Names}, {named, FieldSets}} when Base =:= undefined ->
            {Bindings, ByName, Context1} = field_sets(Names, FieldSets, Context),
            Tuple = erl_syntax:tuple([Tag | [maps:get(FieldName, ByName) || FieldName <- Names]]),
            {at(Span, with_bindings(Bindings, Tuple)), Context1};
        {{named, Names}, {named, FieldSets}} ->
            %% T(..base, f = e): bind the base to a tuple pattern, take the
            %% unlisted fields from it
            {Bind, BaseFields, Context1} = base_bound(Tag, Base, length(Names), Context),
            {Bindings, ByName, Context2} = field_sets(Names, FieldSets, Context1),
            Forms = [maps:get(FieldName, ByName, BaseField)
                     || {FieldName, BaseField} <- lists:zip(Names, BaseFields)],
            {at(Span, with_bindings([Bind | Bindings], erl_syntax:tuple([Tag | Forms]))), Context2};
        _ ->
            fail(Span, "constructor " ++ atom_to_list(Name) ++ " used with the wrong field shape,"
                       " which the checker refuses")
    end.

%% The base of an update matched against its constructor's tuple of Count
%% fields: the match, and a variable for each field.
base_bound(Tag, Base, Count, Context) ->
    {BaseForm, Context1} = expr(Base, Context),
    {Variables, Context2} = fresh_variables(Count, "Base", Context1),
    BaseFields = [erl_syntax:variable(Variable) || Variable <- Variables],
    {erl_syntax:match_expr(erl_syntax:tuple([Tag | BaseFields]), BaseForm), BaseFields, Context2}.

%% Report §3.5, §5.1: named fields are stored in declared order and
%% evaluated in the order written. Where the two differ, each field is
%% bound to a variable first, as written. The field forms by name, and
%% the bindings that go before the tuple.
field_sets(Names, FieldSets, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun(#field_set{expr = Expr}, Acc) ->
                                           expr(Expr, Acc)
                                       end, Context, FieldSets),
    Written = [Name || #field_set{name = Name} <- FieldSets],
    case [Name || Name <- Names, lists:member(Name, Written)] of
        Written ->
            {[], maps:from_list(lists:zip(Written, Forms)), Context1};
        _ ->
            {Variables, Context2} = fresh_variables(length(FieldSets), "Field", Context1),
            VariableForms = [erl_syntax:variable(Variable) || Variable <- Variables],
            Bindings = [erl_syntax:match_expr(VariableForm, Form)
                        || {VariableForm, Form} <- lists:zip(VariableForms, Forms)],
            {Bindings, maps:from_list(lists:zip(Written, VariableForms)), Context2}
    end.

%%
%% A spawn on a peer, report §8.7 and §3.11
%%

%% The function a spawn on a peer starts, as its frame names it in place of
%% the function: a declaration by its identity, `{function, Hash}`, or a
%% foreign one by its qualified name, `{foreign, Names}`, its names as text
%% so that a peer that lacks it makes no atom of them; a lambda or a local
%% fn by its identity and the values it captured, in the order its body
%% first names them, `{lambda, Hash, Position, Captures}`, an entry of this
%% module running it over them; and `restarting` over one of these with its
%% limit, `{restarting, Limit, Spawned}`. The checker admitted only these
%% (ern_bound).
spawned(#e_call{callee = #e_var{referent = {prelude, [restarting]}}, args = [Limit, Function]},
        Context) ->
    {LimitForm, Context1} = expr(Limit, Context),
    {Inner, Context2} = spawned(Function, Context1),
    {erl_syntax:tuple([erl_syntax:atom(restarting), LimitForm, Inner]), Context2};
spawned(#e_lambda{} = Lambda, #emit_context{variables = Variables} = Context) ->
    spawned_lambda(Lambda, Variables, Context);
spawned(#e_var{span = Span, referent = var, name = Name},
        #emit_context{variables = Variables, locals = Locals,
                      let_lambdas = LetLambdas} = Context) ->
    case {Variables, Locals} of
        {#{Name := Variable}, _} ->
            case LetLambdas of
                #{Variable := {Lambda, Before}} -> spawned_lambda(Lambda, Before, Context);
                _ -> fail(Span, "a spawn on a peer starts a local that names no lambda")
            end;
        {_, #{Name := Local}} ->
            spawned_local(Name, Local, Context)
    end;
spawned(#e_var{span = Span, referent = Referent}, #emit_context{env = Env} = Context) ->
    QualifiedName = case Referent of
                        #own_declaration{member_of = MemberOf, name = Name} ->
                            Context#emit_context.namespace ++ [MemberOf || MemberOf =/= undefined]
                                ++ [Name];
                        #remote_declaration{namespace = Declaring, member_of = MemberOf,
                                            name = Name} ->
                            Declaring ++ [MemberOf || MemberOf =/= undefined] ++ [Name];
                        _ ->
                            fail(Span, "a spawn on a peer starts a name that is no declaration")
                    end,
    #emit_context{canonical = #{identities := Own}} = Context,
    Identity = case Own of
                   #{QualifiedName := OwnIdentity} -> OwnIdentity;
                   _ -> ern_typecheck:identity(QualifiedName, Env)
               end,
    case Identity of
        foreign ->
            Names = [atom_to_binary(Part) || Part <- QualifiedName],
            {erl_syntax:abstract({foreign, Names}), Context};
        Hash when is_binary(Hash) ->
            {erl_syntax:abstract({function, Hash}), Context}
    end;
spawned(Function, _Context) ->
    fail(ern_ast:span(Function), "a spawn on a peer starts a function the checker refuses").

%% A lambda a spawn on a peer starts, its captures the variables in force
%% at it, Scope.
spawned_lambda(#e_lambda{span = Span, body = Body} = Lambda, Scope, Context) ->
    Captures = capture_names(Lambda, []),
    Context1 = entry(Span, Captures, fun(Function, Acc) -> lambda_entry(Function, Body, Span,
                                                                         Captures, Acc)
                                     end, Context),
    {spawned_identity(Span, [variable_form(maps:get(Name, Scope)) || Name <- Captures], Context1),
     Context1}.

%% A local fn a spawn on a peer starts, its captures the variables in force
%% at its declaration, or at the spawn where it comes first (report §5.4).
spawned_local(Name, #local_fn{snapshot = Snapshot,
                              declaration = #fn_declaration{span = Span, params = Params,
                                                            body = Body}} = Local,
              #emit_context{variables = Variables} = Context) ->
    Captures = capture_names(Body, [Name | lists:append([pattern_names(Pattern)
                                                         || #param{pattern = Pattern} <- Params])]),
    Scope = case Snapshot of
                pending -> Variables;
                _ -> Snapshot
            end,
    Context1 = entry(Span, Captures, fun(Function, Acc) -> local_entry(Function, Name, Local,
                                                                        Captures, Scope, Acc)
                                     end, Context),
    {spawned_identity(Span, [variable_form(maps:get(Captured, Scope)) || Captured <- Captures],
                      Context1),
     Context1}.

%% Report §3.11: the locals a lambda's or a local fn's body names, Bound
%% aside, each once, in the order it first names them, which is the order
%% its spawn's frame carries them in and its entry takes them.
capture_names(Node, Bound) ->
    lists:uniq([Name || #e_var{referent = var, name = Name} <- ern_ast:free_uses(Node, Bound)]).

%% The frame's identity of the lambda or local fn at Span, and its captures.
spawned_identity(Span, CaptureForms, #emit_context{entries = Entries,
                                                   canonical = #{functions := Functions}}) ->
    #{Span := {_, Position, _}} = Functions,
    #{{Span, Position} := #entry{hash = Hash}} = Entries,
    erl_syntax:tuple([erl_syntax:atom(lambda), erl_syntax:abstract(Hash),
                      erl_syntax:integer(Position), erl_syntax:list(CaptureForms)]).

%% Report §8.7, §11.1: the entry of the lambda or local fn at Span, made
%% once however many spawns name it: a function of the module, named by its
%% enclosing declaration and its position, that takes its captures and runs
%% it, which '$spawned'/2 and '$code'/0 list under its identity.
entry(Span, Captures, Made, #emit_context{entries = Entries, canonical = Canonical} = Context) ->
    #{functions := #{Span := {QualifiedName, Position, Reach}}, identities := Identities} =
        Canonical,
    case Entries of
        #{{Span, Position} := _} ->
            Context;
        _ ->
            Own = lists:nthtail(length(Context#emit_context.namespace), QualifiedName),
            [Name | MemberOf] = lists:reverse(Own),
            Declared = function_name(case MemberOf of [] -> undefined; [Of] -> Of end, Name),
            Function = host_name(atom_to_list(Declared), "$spawn$" ++ integer_to_list(Position)),
            Entry = #entry{function = Function, arity = length(Captures),
                           qualified_name = QualifiedName,
                           hash = maps:get(QualifiedName, Identities), position = Position,
                           reach = Reach},
            Made(Function, Context#emit_context{entries = Entries#{{Span, Position} => Entry}})
    end.

%% A lambda's entry: its body over its captures, each a fresh variable, in
%% a scope of its own.
lambda_entry(Function, Body, Span, Captures,
             #emit_context{variables = Variables, locals = Locals, members = Members,
                           let_lambdas = LetLambdas} = Context) ->
    {Parameters, Context1} = named_variables(["Capture" || _ <- Captures], Context),
    Inner = Context1#emit_context{variables = maps:from_list(lists:zip(Captures, Parameters)),
                                  locals = #{}, members = #{}, let_lambdas = #{}},
    {BodyForms, Context2} = body(Body, Inner),
    Clause = at(Span, erl_syntax:clause([erl_syntax:variable(Parameter)
                                         || Parameter <- Parameters], none, BodyForms)),
    Entry = at(Span, erl_syntax:function(erl_syntax:atom(Function), [Clause])),
    Context2#emit_context{variables = Variables, locals = Locals, members = Members,
                          let_lambdas = LetLambdas,
                          lifted = [Entry | Context2#emit_context.lifted]}.

%% A local fn's entry: its lifted function called with what it closes
%% over, which are its captures, each the variable in force at its
%% declaration, Scope; nothing else, since a spawn of one that closes over a
%% local fn or a requirement's member is refused (report §3.11).
local_entry(Function, Name, #local_fn{lifted_name = LiftedName}, Captures, Scope, Context) ->
    Parameters = [erl_syntax:variable(variable_atom(maps:get(Captured, Scope)))
                  || Captured <- Captures],
    Call = erl_syntax:application(erl_syntax:atom(LiftedName),
                                  [erl_syntax:variable(Variable)
                                   || Variable <- captured_variables(Name, Context)]),
    Entry = erl_syntax:function(erl_syntax:atom(Function),
                                [erl_syntax:clause(Parameters, none, [Call])]),
    Context#emit_context{lifted = [Entry | Context#emit_context.lifted]}.

%% Report §3.11: a `let` of a lambda, by the variable it binds, with the
%% variables in force at the lambda, which a spawn on a peer that names it
%% captures from.
let_lambda(#p_var{name = Name}, #e_lambda{} = Lambda, #emit_context{variables = Before},
           #emit_context{variables = Variables, let_lambdas = LetLambdas} = Context) ->
    #{Name := Variable} = Variables,
    Context#emit_context{let_lambdas = LetLambdas#{Variable => {Lambda, Before}}};
let_lambda(_, _, _, Context) ->
    Context.

%%
%% Blocks, report §5.4 and §5.5, with local fns lifted
%%

%% A local fn becomes a module function whose leading parameters are the
%% Erlang variables it closes over: for each free name of its body, the
%% variable in force at its declaration (report §5.4, §4.6), and, through
%% the local fns it references, theirs. A use before the declaration
%% resolves against the variables in force at the use, which §5.4 makes
%% the same ones. Bodies are emitted when the block ends, every
%% declaration passed.

block(Statements, Context) ->
    Fns = [Declaration || #fn_declaration{} = Declaration <- Statements],
    Context1 = declare_locals(Fns, Statements, Context),
    {Forms, Context2} = statements(Statements, Context1, []),
    {Forms, emit_locals(Fns, Context2)}.

%% A block that ends in a `let`, `=` or `<-`, the checker refuses (report
%% §5.4); this guards the emitter alone.
statements([#binding{span = Span}], _Context, _Acc) ->
    fail(Span, "a block ends with a `let`");
statements([Last], Context, Acc) ->
    {Form, Context1} = expr(Last, Context),
    {lists:reverse([Form | Acc]), Context1};
statements([#fn_declaration{name = Name} | Rest],
           #emit_context{locals = Locals, variables = Variables} = Context, Acc) ->
    Local = (maps:get(Name, Locals))#local_fn{snapshot = Variables},
    statements(Rest, Context#emit_context{locals = Locals#{Name => Local}}, Acc);
statements([#binding{span = Span, pattern = Pattern, operator = '=', expr = Expr} | Rest],
           Context, Acc) ->
    {ExprForm, Context1} = expr(Expr, Context),
    {PatternForm, Context2} = pattern(Pattern, Context1),
    Context3 = let_lambda(Pattern, Expr, Context, Context2),
    statements(Rest, Context3, [at(Span, erl_syntax:match_expr(PatternForm, ExprForm)) | Acc]);
statements([#binding{span = Span, pattern = Pattern, operator = '<-', expr = Expr} | Rest],
           Context, Acc) ->
    %% report §5.5
    {ExprForm, Context1} = expr(Expr, Context),
    Type = resolved(ern_typecheck:node_type(Expr), Context),
    {Clauses, Context2} = unwrapping_clauses(Span, Type, Pattern, Rest, Context1),
    {lists:reverse([at(Span, erl_syntax:case_expr(ExprForm, Clauses)) | Acc]), Context2};
statements([Expr | Rest], Context, Acc) ->
    {Form, Context1} = expr(Expr, Context),
    statements(Rest, Context1, [Form | Acc]).

%% Report §5.5: the clauses of `let p <- e` on e's value: a Left or None
%% is the block's value, and the rest of the block runs on the value p
%% matches.
unwrapping_clauses(_, {tcon, ['Either'], _}, Pattern, Rest, Context) ->
    {[LeftName], Context1} = fresh_variables(1, "Left", Context),
    Left = erl_syntax:tuple([erl_syntax:atom('Left'), erl_syntax:variable(LeftName)]),
    {Right, Context2} = unwrapped('Right', Pattern, Rest, Context1),
    {[erl_syntax:clause([Left], none, [Left]), Right], Context2};
unwrapping_clauses(_, {tcon, ['Optional'], _}, Pattern, Rest, Context) ->
    None = erl_syntax:atom('None'),
    {Some, Context1} = unwrapped('Some', Pattern, Rest, Context),
    {[erl_syntax:clause([None], none, [None]), Some], Context1};
unwrapping_clauses(Span, _, _, _, _) ->
    fail(Span, "`<-` on a value that is neither Either nor Optional").

%% The clause on Tag(p) that runs the rest of the block.
unwrapped(Tag, Pattern, Rest, Context) ->
    {PatternForm, Context1} = pattern(Pattern, Context),
    {RestForms, Context2} = statements(Rest, Context1, []),
    Wrapped = erl_syntax:tuple([erl_syntax:atom(Tag), PatternForm]),
    {erl_syntax:clause([Wrapped], none, RestForms), Context2}.

declare_locals([], _Statements, Context) ->
    Context;
declare_locals(Fns, Statements, #emit_context{locals = Locals} = Context) ->
    Names = [Name || #fn_declaration{name = Name} <- Fns],
    BlockLets = lists:append([pattern_names(Pattern) || #binding{pattern = Pattern} <- Statements]),
    {Declared, Context1} =
        lists:mapfoldl(fun(Fn, Acc) ->
                           declared_local(Fn, Names, BlockLets, lets_before(Fn, Statements),
                                          Context, Acc)
                       end, Context, Fns),
    Context1#emit_context{locals = maps:merge(Locals, maps:from_list(Declared))}.

%% The names the block's lets before Fn bind, which are in force at its
%% declaration (report §5.4).
lets_before(Fn, Statements) ->
    Before = lists:takewhile(fun(Statement) -> Statement =/= Fn end, Statements),
    lists:append([pattern_names(Pattern) || #binding{pattern = Pattern} <- Before]).

%% A local fn of the block named Names, as its #local_fn{} under a fresh
%% name, from the scope the block opens in, Context. A free name is a
%% top-level declaration's only where nothing in scope at the fn's
%% declaration binds it: a parameter, a variable, a local fn or a let
%% before it (report §4.2, §5.4).
declared_local(#fn_declaration{name = Name, params = Params, requirement = Requirement,
                               body = Body} = Declaration, Names, BlockLets, LetsBefore,
               #emit_context{variables = Variables, locals = Locals,
                             top_names = TopNames} = Context,
               Acc) ->
    Bound = lists:append([pattern_names(Pattern) || #param{pattern = Pattern} <- Params]),
    InScope = fun(FreeName) ->
                  is_map_key(FreeName, Variables) orelse is_map_key(FreeName, Locals)
                      orelse lists:member(FreeName, Names) orelse lists:member(FreeName, LetsBefore)
              end,
    Free = [FreeName || FreeName <- lists:usort(ern_ast:free_names(Body, Bound)),
                        InScope(FreeName) orelse not is_map_key({undefined, FreeName}, TopNames)],
    References = [FreeName || FreeName <- Free, lists:member(FreeName, Names)],
    Captured = [FreeName || FreeName <- Free, not lists:member(FreeName, Names),
                            is_map_key(FreeName, Variables)
                                orelse lists:member(FreeName, BlockLets)],
    Enclosing = lists:append([captured_variables(FreeName, Context)
                              || FreeName <- Free, not lists:member(FreeName, Names),
                                 not lists:member(FreeName, Captured),
                                 is_map_key(FreeName, Locals)]),
    {LiftedName, Acc1} = fresh_name(Name, Acc),
    Local = #local_fn{lifted_name = LiftedName, captured = Captured,
                      enclosing = lists:usort(Enclosing), references = References,
                      members = enclosing_members(Body, Requirement, Context),
                      declaration = Declaration},
    {{Name, Local}, Acc1}.

%% Report §4.9: the parameters of the enclosing requirements' members a
%% local fn's body uses, which it closes over, its own requirement's aside.
enclosing_members(Body, Requirement, #emit_context{members = Members} = Context) ->
    Own = [{Id, Member} || #member{type = Variable, name = Member} <- Requirement,
                           {tvar, Id} <- [resolved(Variable, Context)]],
    Used = ern_ast:walk(fun(#required_member{variable = Variable, member = Member}, Found) ->
                                {tvar, Id} = resolved(Variable, Context),
                                [{Id, Member} | Found];
                           (_, Found) ->
                                Found
                        end, Body, []),
    lists:usort([maps:get(Key, Members) || Key <- Used, not lists:member(Key, Own),
                                           is_map_key(Key, Members)]).

%% The Erlang variables a local fn closes over, which its lifted function
%% takes first, in order, each once.
captured_variables(Name, #emit_context{locals = Locals, variables = Variables}) ->
    lists:usort(captured_variables([Name], Locals, Variables, [], [])).

captured_variables([], _Locals, _Variables, _Seen, Acc) ->
    Acc;
captured_variables([Name | Rest], Locals, Variables, Seen, Acc) ->
    case lists:member(Name, Seen) of
        true ->
            captured_variables(Rest, Locals, Variables, Seen, Acc);
        false ->
            #local_fn{captured = Captured, enclosing = Enclosing, references = References,
                      members = Members, snapshot = Snapshot} = maps:get(Name, Locals),
            Scope = case Snapshot of pending -> Variables; _ -> Snapshot end,
            Found = [variable_atom(maps:get(CapturedName, Scope)) || CapturedName <- Captured]
                ++ Enclosing
                ++ Members,
            captured_variables(References ++ Rest, Locals, Variables, [Name | Seen], Found ++ Acc)
    end.

%% The lifted functions of a block, once every declaration has passed.
emit_locals(Fns, Context) ->
    lists:foldl(fun emit_local/2, Context, Fns).

emit_local(#fn_declaration{span = Span, name = Name, params = Params, requirement = Requirement,
                           body = Body},
           #emit_context{variables = Variables, locals = Locals, members = Members} = Context) ->
    #local_fn{lifted_name = LiftedName, captured = Captured, snapshot = Snapshot} =
        maps:get(Name, Locals),
    Captures = captured_variables(Name, Context),
    CapturedVariables = maps:from_list([{CapturedName, maps:get(CapturedName, Snapshot)}
                                       || CapturedName <- Captured]),
    {Head, Context1} = head_patterns(Params, Requirement,
                                     Context#emit_context{variables = CapturedVariables}),
    {BodyForms, Context2} = body(Body, Context1),
    Clause = at(Span, erl_syntax:clause([erl_syntax:variable(Variable) || Variable <- Captures]
                                        ++ Head, none, BodyForms)),
    Function = at(Span, erl_syntax:function(erl_syntax:atom(LiftedName), [Clause])),
    Context2#emit_context{variables = Variables, members = Members,
                          lifted = [Function | Context2#emit_context.lifted]}.

%% The names a pattern binds.
pattern_names(Pattern) -> [Name || {Name, _} <- ern_ast:pattern_bindings(Pattern)].

%%
%% match and receive clauses
%%

%% A clause whose guard is not an Erlang guard expression falls through by
%% a continuation over the remaining clauses (report §5.9).
match_clauses(ScrutineeForm, Clauses, Context) ->
    InScope = maps:keys(Context#emit_context.variables),
    HasErlangGuard = fun(#clause{guard = undefined}) -> true;
                        (#clause{pattern = Pattern, guard = Guard}) ->
                             is_erlang_guard(Guard, pattern_names(Pattern) ++ InScope, Context)
                     end,
    case lists:all(HasErlangGuard, Clauses) of
        true ->
            {Parts, Context1} = lists:mapfoldl(fun simple_clauses/2, Context, Clauses),
            {Bindings, Forms} = join_parts(Parts),
            {with_bindings(Bindings, erl_syntax:case_expr(ScrutineeForm, Forms)), Context1};
        false ->
            {[ScrutineeName], Context1} = fresh_variables(1, "Scrutinee", Context),
            Scrutinee = erl_syntax:variable(ScrutineeName),
            {Body, Context2} = general_clauses(Scrutinee, Clauses, Context1),
            {erl_syntax:block_expr([erl_syntax:match_expr(Scrutinee, ScrutineeForm), Body]),
             Context2}
    end.

general_clauses(Scrutinee, [#clause{pattern = #p_or{}} = Clause | Rest], Context) ->
    {RestBind, Fallthrough, Context1} = rest_fun(Scrutinee, Rest, Context),
    MakeClause = fun(Span, PatternForm, Guard, Call, Acc) ->
                     PatternGuard = joined_guard(none, Acc),
                     case Guard of
                         undefined ->
                             {at(Span, erl_syntax:clause([PatternForm], PatternGuard, Call)), Acc};
                         _ ->
                             {GuardForm, Acc1} = expr(Guard, Acc),
                             Test = guard_test(GuardForm, Call, Fallthrough),
                             {at(Span, erl_syntax:clause([PatternForm], PatternGuard, [Test])),
                              Acc1}
                     end
                 end,
    {{Bindings, Forms}, Context2} = alternatives(Clause, MakeClause, Context1),
    Otherwise = erl_syntax:clause([erl_syntax:underscore()], none, [Fallthrough]),
    Case = erl_syntax:case_expr(Scrutinee, Forms ++ [Otherwise]),
    {erl_syntax:block_expr([RestBind | Bindings] ++ [Case]),
     Context2#emit_context{variables = Context#emit_context.variables}};
general_clauses(Scrutinee, [#clause{pattern = Pattern, guard = undefined, body = ClauseBody}],
                #emit_context{variables = Variables} = Context) ->
    {PatternForm, PatternGuard, Context1} = clause_head(Pattern, undefined, Context),
    {BodyForms, Context2} = body(ClauseBody, Context1),
    Clause = erl_syntax:clause([PatternForm], PatternGuard, BodyForms),
    {erl_syntax:case_expr(Scrutinee, [Clause]), Context2#emit_context{variables = Variables}};
general_clauses(Scrutinee, [Clause | Rest], #emit_context{variables = Variables} = Context) ->
    {Bind, Fallthrough, Context1} = rest_fun(Scrutinee, Rest, Context),
    {ClauseForm, Context2} = general_clause(Clause, Fallthrough, Context1),
    Otherwise = erl_syntax:clause([erl_syntax:underscore()], none, [Fallthrough]),
    Case = erl_syntax:case_expr(Scrutinee, [ClauseForm, Otherwise]),
    {erl_syntax:block_expr([Bind, Case]), Context2#emit_context{variables = Variables}}.

%% A clause that falls through: its pattern, with the guard the pattern
%% asks for, and its body behind its own guard, if any.
general_clause(#clause{pattern = Pattern, guard = Guard, body = ClauseBody}, Fallthrough,
               Context) ->
    {PatternForm, PatternGuard, Context1} = clause_head(Pattern, undefined, Context),
    {Body, Context2} = case Guard of
                           undefined ->
                               body(ClauseBody, Context1);
                           _ ->
                               guarded_body(Guard, ClauseBody, Fallthrough, Context1)
                       end,
    {erl_syntax:clause([PatternForm], PatternGuard, Body), Context2}.

guarded_body(Guard, ClauseBody, Fallthrough, Context) ->
    {GuardForm, Context1} = expr(Guard, Context),
    {BodyForms, Context2} = body(ClauseBody, Context1),
    {[guard_test(GuardForm, BodyForms, Fallthrough)], Context2}.

%% A clause's pattern and its guard, the guards the pattern asks for joined
%% to Guard, which is an Erlang guard here, or undefined.
clause_head(Pattern, Guard, #emit_context{pattern_guards = Guards} = Context) ->
    {PatternForm, Context1} = pattern(Pattern, Context#emit_context{pattern_guards = []}),
    {OwnGuard, Context2} = case Guard of
                               undefined -> {none, Context1};
                               _ -> expr(Guard, Context1)
                           end,
    {PatternForm, joined_guard(OwnGuard, Context2),
     Context2#emit_context{pattern_guards = Guards}}.

%% A guard that is no Erlang guard, as a test inside its clause: the body
%% where it holds, the clauses after it where it does not.
guard_test(GuardForm, Body, Fallthrough) ->
    erl_syntax:case_expr(GuardForm, [erl_syntax:clause([erl_syntax:atom(true)], none, Body),
                                     erl_syntax:clause([erl_syntax:atom(false)], none,
                                                       [Fallthrough])]).

%% The clauses after the one being compiled, bound as Rest = fun() -> ...
%% end, and the call Rest() by which a guard falls through to them.
rest_fun(Scrutinee, Rest, Context) ->
    {[RestName], Context1} = fresh_variables(1, "Rest", Context),
    RestVariable = erl_syntax:variable(RestName),
    {RestBody, Context2} =
        case Rest of
            [] -> {call_remote(erlang, error, [erl_syntax:atom(no_match)]), Context1};
            _ -> general_clauses(Scrutinee, Rest, Context1)
        end,
    RestFun = erl_syntax:fun_expr([erl_syntax:clause([], none, [RestBody])]),
    {erl_syntax:match_expr(RestVariable, RestFun), erl_syntax:application(RestVariable, []),
     Context2}.

simple_clause(#clause{span = Span, pattern = Pattern, guard = Guard, body = ClauseBody},
              #emit_context{variables = Variables} = Context) ->
    {PatternForm, GuardForm, Context1} = clause_head(Pattern, Guard, Context),
    {BodyForms, Context2} = body(ClauseBody, Context1),
    {at(Span, erl_syntax:clause([PatternForm], GuardForm, BodyForms)),
     Context2#emit_context{variables = Variables}}.

%% The Erlang clauses of one Ernest clause and the bindings they need.
simple_clauses(#clause{pattern = #p_or{}} = Clause, Context) ->
    MakeClause = fun(Span, PatternForm, Guard, Call, Acc) ->
                     {OwnGuard, Acc1} = case Guard of
                                            undefined -> {none, Acc};
                                            _ -> expr(Guard, Acc)
                                        end,
                     GuardForm = joined_guard(OwnGuard, Acc1),
                     {at(Span, erl_syntax:clause([PatternForm], GuardForm, Call)), Acc1}
                 end,
    alternatives(Clause, MakeClause, Context);
simple_clauses(Clause, Context) ->
    {Form, Context1} = simple_clause(Clause, Context),
    {{[], [Form]}, Context1}.

join_parts(Parts) ->
    {lists:append([PartBindings || {PartBindings, _} <- Parts]),
     lists:append([PartForms || {_, PartForms} <- Parts])}.

with_bindings([], Form) -> Form;
with_bindings(Bindings, Form) -> erl_syntax:block_expr(Bindings ++ [Form]).

%% Report §5.9: a clause with pattern alternatives is one Erlang clause per
%% alternative. The body is compiled once, into a fun over the variables
%% every alternative binds, and each clause calls it; MakeClause builds a
%% clause from the clause's span, the pattern form, the Ernest guard, and
%% that call.
alternatives(#clause{span = Span, pattern = #p_or{alternatives = [First | _] = Alternatives},
                     guard = Guard, body = ClauseBody},
             MakeClause, Context) ->
    Names = pattern_names(First),
    {[BodyName], Context1} = fresh_variables(1, "Body", Context),
    #emit_context{variables = Variables, pattern_guards = Guards} = Context1,
    BodyFunction = erl_syntax:variable(BodyName),
    {_, PatternContext} = pattern(First, Context1#emit_context{pattern_guards = []}),
    Params = bound_variables(Names, PatternContext),
    {BodyForms, BodyContext} = body(ClauseBody,
                                    PatternContext#emit_context{pattern_guards = Guards}),
    Bind = erl_syntax:match_expr(BodyFunction,
                                 erl_syntax:fun_expr([erl_syntax:clause(Params, none, BodyForms)])),
    {Forms, Context2} =
        lists:mapfoldl(fun(Alternative, Acc) ->
                           {PatternForm, Acc1} =
                               pattern(Alternative, Acc#emit_context{pattern_guards = []}),
                           Args = bound_variables(Names, Acc1),
                           Call = [at(Span, erl_syntax:application(BodyFunction, Args))],
                           {Form, Acc2} = MakeClause(Span, PatternForm, Guard, Call, Acc1),
                           #emit_context{variables = Before, pattern_guards = Kept} = Acc,
                           {Form, Acc2#emit_context{variables = Before, pattern_guards = Kept}}
                       end, BodyContext#emit_context{variables = Variables}, Alternatives),
    {{[Bind], Forms}, Context2}.

%% The Erlang variables of the names a pattern bound.
bound_variables(Names, #emit_context{variables = Variables}) ->
    [erl_syntax:variable(variable_atom(maps:get(Name, Variables))) || Name <- Names].

%% Report §6.3's guard expression over the variables in Bound, the
%% clause's and the enclosing function's: it is an Erlang guard. A name
%% bound at top level is read through its getter, a call, so it is not one.
is_erlang_guard(#e_binop{operator = Operator, left = Left, right = Right}, Bound, Context)
  when Operator =:= '&&'; Operator =:= '||' ->
    is_erlang_guard(Left, Bound, Context) andalso is_erlang_guard(Right, Bound, Context);
is_erlang_guard(#e_binop{operator = Operator, left = Left, right = Right}, Bound, _)
  when Operator =:= '=='; Operator =:= '!=' ->
    is_guard_operand(Left, Bound) andalso is_guard_operand(Right, Bound);
is_erlang_guard(#e_binop{operator = Operator, left = Left, right = Right}, Bound, Context)
  when Operator =:= '<'; Operator =:= '<='; Operator =:= '>'; Operator =:= '>=' ->
    %% an ordering through T.compare is a call (report §3.10)
    IsPreludeType = case resolved(ern_typecheck:node_type(Left), Context) of
                        {tcon, [_], []} -> true;
                        _ -> false
                    end,
    IsPreludeType andalso is_guard_operand(Left, Bound) andalso is_guard_operand(Right, Bound);
is_erlang_guard(#e_not{expr = Expr}, Bound, Context) -> is_erlang_guard(Expr, Bound, Context);
is_erlang_guard(#e_literal{kind = bool}, _, _) -> true;
is_erlang_guard(#e_var{namespace = [], name = Name}, Bound, _) -> lists:member(Name, Bound);
is_erlang_guard(_, _, _) -> false.

is_guard_operand(#e_literal{}, _) -> true;
is_guard_operand(#e_negation{expr = #e_literal{kind = Kind}}, _)
  when Kind =:= int; Kind =:= float ->
    true;
is_guard_operand(#e_var{namespace = [], name = Name}, Bound) -> lists:member(Name, Bound);
is_guard_operand(#e_constructor{args = none}, _) -> true;
is_guard_operand(_, _) -> false.

%%
%% Patterns: pattern(Pattern, Context) -> {Form, Context} with the
%% variables bound
%%

%% The variables in scope where a pattern begins are kept as the context's
%% outer while its parts are compiled, since its bitstrings' sizes read
%% them and no variable the same pattern binds elsewhere (report §5.11).
pattern(Pattern, #emit_context{outer = undefined, variables = Variables} = Context) ->
    {Form, Context1} = pattern_part(Pattern, Context#emit_context{outer = Variables}),
    {Form, Context1#emit_context{outer = undefined}};
pattern(Pattern, Context) ->
    pattern_part(Pattern, Context).

pattern_part(#p_wildcard{span = Span}, Context) ->
    {at(Span, erl_syntax:underscore()), Context};
pattern_part(#p_var{span = Span, name = Name}, Context) ->
    {Variable, Context1} = bind(Name, Context),
    {at(Span, erl_syntax:variable(Variable)), Context1};
pattern_part(#p_literal{span = Span, kind = Kind, value = Value}, Context) ->
    {at(Span, literal(Kind, Value)), Context};
pattern_part(#p_constructor{span = Span, namespace = Namespace, name = Name, args = Args},
        #emit_context{env = Env} = Context) ->
    #constructor_info{fields = Fields} =
        ern_typecheck:lookup_constructor(Span, Namespace, Name, Env),
    Tag = erl_syntax:atom(Name),
    case {Fields, Args} of
        {none, _} -> {at(Span, Tag), Context};
        {positional, {positional, SubPattern}} ->
            {PatternForm, Context1} = pattern(SubPattern, Context),
            {at(Span, erl_syntax:tuple([Tag, PatternForm])), Context1};
        {{named, Names}, {named, FieldPatterns}} ->
            {Forms, Context1} = lists:mapfoldl(fun(FieldName, Acc) ->
                                                   named_field_pattern(FieldName, FieldPatterns,
                                                                       Acc)
                                               end, Context, Names),
            {at(Span, erl_syntax:tuple([Tag | Forms])), Context1}
    end;
pattern_part(#p_tuple{span = Span, elements = Elements}, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun pattern/2, Context, Elements),
    {at(Span, erl_syntax:tuple(Forms)), Context1};
pattern_part(#p_list{span = Span, elements = Elements}, Context) ->
    {Forms, Context1} = lists:mapfoldl(fun pattern/2, Context, Elements),
    {at(Span, erl_syntax:list(Forms)), Context1};
pattern_part(#p_cons{span = Span, head = Head, tail = Tail}, Context) ->
    {HeadForm, Context1} = pattern(Head, Context),
    {TailForm, Context2} = pattern(Tail, Context1),
    {at(Span, erl_syntax:cons(HeadForm, TailForm)), Context2};
pattern_part(#p_as{span = Span, pattern = SubPattern, name = Name}, Context) ->
    {PatternForm, Context1} = pattern(SubPattern, Context),
    {Variable, Context2} = bind(Name, Context1),
    {at(Span, erl_syntax:match_expr(erl_syntax:variable(Variable), PatternForm)), Context2};
pattern_part(#p_bitstring{span = Span, segments = Segments},
             #emit_context{outer = Outer} = Context) ->
    %% report §5.11: a size expression must be an Erlang guard expression
    %% here, in the scope before the pattern and of the earlier segments;
    %% a `bytes` segment is Erlang's `binary`, so an unaligned rest fails
    %% the match
    Segment = fun(#bit_segment{value = ValuePattern, specs = Specs}, {Acc, SizeScope}) ->
                  {ok, Spec} = ern_bitspec:spec(Specs),
                  {SizeForm, Acc1} = size_form(Spec, Acc#emit_context{variables = SizeScope}),
                  {ValueForm, Acc2} =
                      bits_pattern_value(Spec, ValuePattern,
                                         Acc1#emit_context{variables = Acc#emit_context.variables}),
                  Bound = maps:with(pattern_names(ValuePattern), Acc2#emit_context.variables),
                  {erl_syntax:binary_field(ValueForm, SizeForm, type_specs(Spec)),
                   {Acc2, maps:merge(SizeScope, Bound)}}
              end,
    {Fields, {Context1, _}} = lists:mapfoldl(Segment, {Context, Outer}, Segments),
    {at(Span, erl_syntax:binary(Fields)), Context1}.

%% Report §5.10: a field the pattern omits matches any value.
named_field_pattern(FieldName, FieldPatterns, Context) ->
    case [SubPattern || #field_pattern{name = Name, pattern = SubPattern} <- FieldPatterns,
                        Name =:= FieldName] of
        [SubPattern] -> pattern(SubPattern, Context);
        [] -> {erl_syntax:underscore(), Context}
    end.

bits_pattern_value(#{kind := float}, #p_var{span = Span, name = Name}, Context) ->
    {Variable, Context1} = bind(Name, Context),
    Variables = (Context1#emit_context.variables)#{Name => {zero, Variable}},
    {at(Span, erl_syntax:variable(Variable)), Context1#emit_context{variables = Variables}};
bits_pattern_value(#{kind := float}, #p_literal{span = Span, value = Zero}, Context)
  when Zero == 0.0 ->
    %% report §3.1: the literal 0.0 matches the bytes of either zero
    {[ZeroName], Context1} = fresh_variables(1, "Zero", Context),
    Guard = erl_syntax:infix_expr(erl_syntax:variable(ZeroName), erl_syntax:operator('=='),
                                  erl_syntax:float(0.0)),
    Guards = Context1#emit_context.pattern_guards ++ [Guard],
    {at(Span, erl_syntax:variable(ZeroName)), Context1#emit_context{pattern_guards = Guards}};
bits_pattern_value(_, Pattern, Context) ->
    pattern(Pattern, Context).

%% A clause's guard: the guards its pattern asked for, joined to its own.
joined_guard(GuardForm, #emit_context{pattern_guards = []}) -> GuardForm;
joined_guard(GuardForm, #emit_context{pattern_guards = Guards}) ->
    All = case GuardForm of none -> Guards; _ -> Guards ++ [GuardForm] end,
    Joined = lists:foldl(fun(Guard, Acc) ->
                             erl_syntax:infix_expr(Acc, erl_syntax:operator('andalso'), Guard)
                         end, hd(All), tl(All)),
    Joined.

%%
%% Bitstring segments, report §5.11
%%

size_form(#{size := none}, Context) -> {none, Context};
size_form(#{size := {const, Size}}, Context) -> {erl_syntax:integer(Size), Context};
size_form(#{size := {expr, SizeExpr}}, Context) -> expr(SizeExpr, Context).

%% The width in bits as a form: size times unit.
bits_form(#{size := {const, Size}, unit := Unit}, _) -> erl_syntax:integer(Size * Unit);
bits_form(#{unit := 1}, SizeForm) -> SizeForm;
bits_form(#{unit := Unit}, SizeForm) ->
    erl_syntax:infix_expr(SizeForm, erl_syntax:operator('*'), erl_syntax:integer(Unit)).

segment_value(#{kind := int, sign := Sign} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, int, [ValueForm, bits_form(Spec, SizeForm), erl_syntax:atom(Sign)]);
segment_value(#{kind := float} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, float, [ValueForm, bits_form(Spec, SizeForm)]);
segment_value(#{kind := bytes, size := none}, ValueForm, _) -> ValueForm;
segment_value(#{kind := bytes} = Spec, ValueForm, SizeForm) ->
    call_remote(ern_bits, bytes, [ValueForm, bits_form(Spec, SizeForm)]);
segment_value(_, ValueForm, _) -> ValueForm.

%% Report §5.1: a long literal's elements, evaluated first to last, each
%% put before the list so far, which alone stays live at the next, and the
%% list reversed at the end.
built_in_order(Elements, Context) ->
    {Matches, {Last, Context1}} =
        lists:mapfoldl(fun(Element, {SoFar, Acc}) ->
                           {Form, Acc1} = expr(Element, Acc),
                           {[Name], Acc2} = fresh_variables(1, "Built", Acc1),
                           {erl_syntax:match_expr(erl_syntax:variable(Name),
                                                  erl_syntax:cons(Form, SoFar)),
                            {erl_syntax:variable(Name), Acc2}}
                       end, {erl_syntax:nil(), Context}, Elements),
    {erl_syntax:block_expr(Matches ++ [call_remote(lists, reverse, [Last])]), Context1}.

%% Report §5.1, §5.11: a size that is an expression stands in a segment
%% twice, its width checked and its field built, so where one is, every
%% segment's value and every such size is bound once, in order, before the
%% binary; one that faults faults there, outside the overflow's handler.
segments_bound(Compiled, Context) ->
    case lists:all(fun({_, _, SizeForm}) -> is_plain_size(SizeForm) end, Compiled) of
        true ->
            {[], Compiled, Context};
        false ->
            {Bound, Context1} = lists:mapfoldl(fun segment_bound/2, Context, Compiled),
            {Bindings, Parts} = lists:unzip(Bound),
            {lists:append(Bindings), Parts, Context1}
    end.

segment_bound({Spec, ValueForm, SizeForm}, Context) ->
    {[ValueName], Context1} = fresh_variables(1, "Value", Context),
    ValueBinding = erl_syntax:match_expr(erl_syntax:variable(ValueName), ValueForm),
    case is_plain_size(SizeForm) of
        true ->
            {{[ValueBinding], {Spec, erl_syntax:variable(ValueName), SizeForm}}, Context1};
        false ->
            {[SizeName], Context2} = fresh_variables(1, "Size", Context1),
            SizeBinding = erl_syntax:match_expr(erl_syntax:variable(SizeName), SizeForm),
            {{[ValueBinding, SizeBinding],
              {Spec, erl_syntax:variable(ValueName), erl_syntax:variable(SizeName)}},
             Context2}
    end.

is_plain_size(none) -> true;
is_plain_size(SizeForm) -> lists:member(erl_syntax:type(SizeForm), [integer, variable]).

%% A dynamic size counted in bits, a unit of 1, leaves the bit count open;
%% the built value is then checked for alignment.
is_open(#{size := {expr, _}, unit := 1}) -> true;
is_open(_) -> false.

type_specs(#{kind := Kind, unit := Unit, endian := Endian, sign := Sign, size := Size}) ->
    Type = case Kind of
               int -> integer; bytes -> binary; Other -> Other
           end,
    IsUtf = lists:member(Kind, [utf8, utf16, utf32]),
    [erl_syntax:atom(Type)]
        ++ [erl_syntax:atom(Endian) || not IsUtf orelse Endian =/= big]
        ++ [erl_syntax:atom(Sign) || Kind =:= int]
        ++ [erl_syntax:size_qualifier(erl_syntax:atom(unit), erl_syntax:integer(Unit))
            || not IsUtf, Size =/= none].

%%
%% Variables: every Ernest binding gets a fresh Erlang variable
%%

bind(Name, #emit_context{variables = Variables, counter = Counter} = Context) ->
    Variable = erlang_variable(Name, Counter + 1),
    {Variable,
     Context#emit_context{variables = Variables#{Name => Variable}, counter = Counter + 1}}.

%% Report §3.1: a variable a float segment bound may hold the runtime's
%% negative zero, so the map holds {zero, V} and each read is V + 0.0,
%% which is 0.0 for either zero and V otherwise; a capture passes V itself,
%% and the reads inside normalize it the same way.
variable_form({zero, Variable}) ->
    erl_syntax:infix_expr(erl_syntax:variable(Variable), erl_syntax:operator('+'),
                          erl_syntax:float(0.0));
variable_form(Variable) ->
    erl_syntax:variable(Variable).

variable_atom({zero, Variable}) -> Variable;
variable_atom(Variable) -> Variable.

erlang_variable(Name, Number) ->
    Text = atom_to_list(Name),
    Base = case Text of
               [$_ | Rest] -> "V_" ++ Rest;
               %% a name the checker makes, which no program spells (§2.3)
               [$$ | Rest] -> "V_" ++ Rest;
               [First | Rest] -> [string:to_upper(First) | Rest]
           end,
    host_name(Base, "_" ++ integer_to_list(Number)).

fresh_variables(Count, Prefix, #emit_context{counter = Counter} = Context) ->
    Variables = [list_to_atom(Prefix ++ "_" ++ integer_to_list(Counter + Index))
                 || Index <- lists:seq(1, Count)],
    {Variables, Context#emit_context{counter = Counter + Count}}.

named_variables(Prefixes, Context) ->
    lists:mapfoldl(fun(Prefix, Acc) ->
                           {[Variable], Acc1} = fresh_variables(1, Prefix, Acc),
                           {Variable, Acc1}
                   end, Context, Prefixes).

fresh_name(Name, #emit_context{counter = Counter} = Context) ->
    {host_name(atom_to_list(Name), "$" ++ integer_to_list(Counter + 1)),
     Context#emit_context{counter = Counter + 1}}.

%% Report §11.1: a name the emitter makes, Base cut so that Base and its
%% numbered Suffix fit the host's 255 characters; the suffix keeps it apart
%% from every other.
host_name(Base, Suffix) ->
    list_to_atom(lists:sublist(Base, 255 - length(Suffix)) ++ Suffix).

%%
%% Helpers
%%

at(Span, Form) ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    erl_syntax:set_pos(Form, {Line, Column}).

%% A declaration the checker would not have passed: a defect of the
%% toolchain, not of the program.
-spec fail(term(), iodata()) -> no_return().
fail(Span, Message) ->
    erlang:error({emitter_defect, Span, lists:flatten(Message)}).
