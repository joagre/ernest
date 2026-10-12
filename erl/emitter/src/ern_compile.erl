%% The compile of one checked module, report §11.1: its definitions'
%% canonical forms and their hashes (ern_canonical, §8.7, Appendix H), what
%% its build adds that is no definition's, and the link of what the forms
%% reference outside its unit, read from the checker's environment, which
%% hold everything the emitter makes the unit of (ern_unit.hrl); and the
%% compiled unit with its chunks: the interface "ErnI", with the source's
%% hash and per dependency the hash of the interface compiled against, and
%% the documentation as EEP 48's "Docs" (§11.4), which are the build's and
%% no unit's and so are made from the typed tree and the environment; and
%% what the unit records of its definitions as "ErnC", their forms with the
%% lines of their source and their names, its foreign declarations and its
%% bindings' order (§8.7, §11.1). It gives too the link of a unit made from
%% forms alone, by name and through interfaces (link/5, named/2), and the
%% host's compile of any unit (compiled/2).
-module(ern_compile).

-export([compile/4, compile/5, from_compiled/5, compiled/2, forms/3, forms/4, erl_source/3,
         erl_source/4, unit/5, link/5, references/1, named/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("typer/include/ern_canonical.hrl").
-include_lib("emitter/include/ern_unit.hrl").

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
%% module of the standard library's own source root. `units` names the unit
%% of each namespace whose unit is not its module's Erlang name, the
%% module's own among them, as the shell gives them where a reload brought
%% a version as a unit of its own (report §11.2), and is not kept;
%% `site_namespace`, which the shell gives such a version, is the namespace
%% its spawn sites name its declarations under, `Counter$2` (§11.2), and is
%% not kept; `input_name`, which the shell gives an input, is the name its
%% expression's sites write, `input 3`, which the forms' chunk records
%% beside the expression's form (§8.7), and is not kept; `canonical`, the
%% module's canonical forms where the build made them already (ern_build),
%% is not kept either. The chunk records
%% beside the build's facts whether the module
%% builds a function value, `builds_functions`, by which the shell keeps an
%% input's code (§11.2). The declarations are the checker's, so every rule
%% a program can break has been checked: what the emitter cannot emit, or
%% emits and the host does not compile, is a defect of the toolchain,
%% raised as one, which `ern` reports as its own failure (report §11).
-spec compile([atom()], [tuple()], #interface{}, ern_typecheck:env(),
              #{source_hash := binary(), source_path => binary(),
                deps := [{[atom()], binary()}], compiler => binary(),
                stdlib => binary() | none, source => binary(),
                session_offset => non_neg_integer(), form_namespace => [atom()],
                standard => boolean(), units => #{[atom()] => atom()},
                site_namespace => [atom()], input_name => binary(),
                canonical => ern_canonical:canonical()}) ->
          {ok, atom(), binary()}.
compile(Namespace, Declarations, Interface, Env, Build) ->
    %% report §8.7, §11.1, Appendix H: the canonical forms and their hashes,
    %% the hashes in the interface, by which a dependent's forms name its
    %% definitions, and the hashes of other modules' definitions its own
    %% forms name, which the recompile rule compares
    Canonical = canonical(Namespace, Declarations, Env, Build),
    #{references := References} = Canonical,
    Unit = unit(Namespace, Declarations, Env, Canonical, Build#{code => true}),
    {Forms, BuildsFunctions} = ern_emitter:unit(Unit),
    Facts = (maps:without([source, session_offset, form_namespace, standard, units,
                           site_namespace, code, canonical, input_name], Build))
        #{references => References, builds_functions => BuildsFunctions},
    Chunk = ern_interface:encode(Facts, ern_canonical:interface(Interface, Canonical)),
    Docs = term_to_binary(ern_docs:build(Namespace, Declarations, Env,
                                         maps:get(source, Build, <<>>))),
    Chunks = [{ern_interface:chunk_name(), Chunk}, {ern_docs:chunk_name(), Docs},
              {ern_canonical:chunk_name(), ern_canonical:encode(recorded(Unit, Build))}],
    case compiled(Forms, Chunks) of
        {ok, ErlangModule, Beam} -> {ok, ErlangModule, Beam};
        {error, Errors} -> erlang:error({emitted_erlang_does_not_compile, Errors})
    end.

%% Report §11.2, §11.1: a compiled module made a unit of the name Unit from
%% what its compiled form records, by the back end as an exchange's unit is
%% made (§8.7): its definitions' forms with the lines of their source, its
%% foreign declarations and its bindings' order, beside what its interface
%% names, its exports and the modules it depends on; linked through the
%% interfaces Interfaces, of the modules its code names, over the prelude's
%% environment, each module's code calling the unit Units names for its
%% namespace, as the session links a version; and compiled with the
%% chunks of the compiled form, its interface, its documentation and its
%% forms, so that it is that module whatever its unit's name. The shell
%% loads so a compiled module beside another unit of its name, which no
%% source makes again. What the forms reference outside the module is a
%% definition of a module whose interface the session holds, so a failure
%% here is the toolchain's.
-spec from_compiled(binary(), atom(), [#interface{}], ern_typecheck:env(),
                    #{[atom()] => atom()}) -> {ok, binary()}.
from_compiled(Beam, Unit, Interfaces, Prelude, Units) ->
    {ok, #{interface := #interface{namespace = Namespace, values = Values},
           deps := Dependencies}} = ern_interface:read(Beam),
    {ok, #recorded{definitions = Definitions, foreign = Foreign,
                   binding_order = BindingOrder}} = ern_canonical:read(Beam),
    Env = ern_typecheck:with_interfaces(Interfaces, Prelude),
    Scoped = ern_types:set_scope(Namespace, [], [], #{}, ern_typecheck:type_state(Env)),
    ForeignFunctions = [#foreign_function{qualified_name = QualifiedName, scheme = Scheme,
                                          host_module = HostModule,
                                          host_function = HostFunction,
                                          export = is_map_key(QualifiedName, Values),
                                          printing = Printing}
                        || {QualifiedName, Scheme, HostModule, HostFunction, Printing}
                               <- Foreign],
    ForeignSchemes = maps:from_list([{QualifiedName, Scheme}
                                     || {QualifiedName, Scheme, _, _, _} <- Foreign]),
    %% the qualified name of each definition of another module by its hash,
    %% which its forms name it by
    Named = #{Hash => QualifiedName || #interface{identities = Identities} <- Interfaces,
                                       QualifiedName := Hash <- Identities, is_binary(Hash)},
    Forms = [Form || #definition{form = Form} <- Definitions],
    Hashes = [Hash || {hash, Hash} <- references(Forms), is_map_key(Hash, Named)],
    Canonical = #{definitions => Definitions, foreign_schemes => ForeignSchemes,
                  links => [{{hash, Hash}, maps:get(Hash, Named)} || Hash <- Hashes]},
    Link = link(Namespace, Namespace, Canonical,
                ern_typecheck:set_type_state(Scoped, Env), Units),
    Others = #{Hash => ern_typecheck:reach(maps:get(Hash, Named), Env) || Hash <- Hashes},
    Made = #unit{namespace = Namespace, name = Unit, definitions = Definitions,
                 foreign_functions = ForeignFunctions, exported = maps:keys(Values),
                 binding_order = BindingOrder,
                 dependencies = [unit_of(Dependency, Units) || {Dependency, _} <- Dependencies],
                 reaches = ern_canonical:unit_reaches(Definitions, Others), link = Link,
                 code = true, form_namespace = Namespace, site_namespace = Namespace},
    {Emitted, _} = ern_emitter:unit(Made),
    Names = [ern_interface:chunk_name(), ern_docs:chunk_name(), ern_canonical:chunk_name()],
    {ok, {_, Chunks}} = beam_lib:chunks(Beam, [binary_to_list(Name) || Name <- Names]),
    case compiled(Emitted, [{list_to_binary(Name), Chunk} || {Name, Chunk} <- Chunks]) of
        {ok, Unit, Compiled} -> {ok, Compiled};
        {error, Errors} -> erlang:error({emitted_erlang_does_not_compile, Errors})
    end.

%% Report §11.1: a unit's abstract forms compiled by the host, with its
%% chunks, or the host's errors. A build's errors are a defect of the
%% toolchain (compile/5); a unit made from forms that arrived answers them
%% as the peer's reason (ern_arrival, §8.7).
-spec compiled([erl_parse:abstract_form()], [{binary(), binary()}]) ->
          {ok, atom(), binary()} | {error, term()}.
compiled(Forms, Chunks) ->
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
        {error, Errors1, _} -> {error, Errors1}
    end.

refused_by_validator(Errors) ->
    lists:any(fun({_, Refusals}) -> lists:keymember(beam_validator, 2, Refusals) end, Errors).

%% The abstract forms, for the golden tests and erl_prettypr.
-spec forms([atom()], [tuple()], ern_typecheck:env()) -> [erl_parse:abstract_form()].
forms(Namespace, Declarations, Env) ->
    forms(Namespace, Declarations, Env, #{}).

%% Report §8.5: with the modules this one depends on, which it declares
%% as `'$deps'/0` so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file. Report §8.7: a
%% service's and a spawn's hashes are the canonical forms', which a build
%% gives as `canonical` and the forms for reading compute.
-spec forms([atom()], [tuple()], ern_typecheck:env(), map()) -> [erl_parse:abstract_form()].
forms(Namespace, Declarations, Env, Build) ->
    Canonical = canonical(Namespace, Declarations, Env, Build),
    {Forms, _} = ern_emitter:unit(unit(Namespace, Declarations, Env, Canonical, Build)),
    Forms.

%% The module as Erlang source, for --emit-erl (report §11.1), each
%% function under a comment that names it as the program does.
-spec erl_source([atom()], [tuple()], ern_typecheck:env()) -> unicode:chardata().
erl_source(Namespace, Declarations, Env) ->
    erl_source(Namespace, Declarations, Env, #{}).

-spec erl_source([atom()], [tuple()], ern_typecheck:env(), map()) -> unicode:chardata().
erl_source(Namespace, Declarations, Env, Build) ->
    Canonical = canonical(Namespace, Declarations, Env, Build),
    ern_emitter:source(unit(Namespace, Declarations, Env, Canonical, Build)).

canonical(Namespace, Declarations, Env, Build) ->
    case Build of
        #{canonical := Given} ->
            Given;
        _ ->
            ern_canonical:module(Namespace, Declarations, Env, maps:get(standard, Build, false),
                                 maps:get(form_namespace, Build, Namespace))
    end.

%%
%% The unit, report §11.1
%%

%% Report §11.1: what the emitter makes the module's unit of: its
%% definitions' forms as Canonical gives them, the source woven in, and
%% what the module's build adds that is no definition's: its foreign
%% functions, which have no form, what it exports, the order its bindings
%% are initialized in (§8.5), the units of its dependencies, its reaches,
%% and the link of what its forms reference outside it.
-spec unit([atom()], [tuple()], ern_typecheck:env(), ern_canonical:canonical(), map()) ->
          #unit{}.
unit(Namespace, Declarations, Env, Canonical, Build) ->
    Units = maps:get(units, Build, #{}),
    FormNamespace = maps:get(form_namespace, Build, Namespace),
    #{definitions := Definitions, reaches := Reaches, functions := Functions,
      foreign_schemes := ForeignSchemes} = Canonical,
    #unit{namespace = Namespace, name = unit_of(Namespace, Units), definitions = Definitions,
          foreign_functions = foreign_functions(Namespace, Declarations, ForeignSchemes),
          exported = [QualifiedName || Declaration <- Declarations, exported(Declaration),
                                       QualifiedName <- qualified(Namespace, Declaration)],
          binding_order = [Namespace ++ [Name]
                           || {undefined, Name} <- ern_typecheck:let_order(Env)],
          dependencies = [unit_of(Dependency, Units)
                          || {Dependency, _} <- maps:get(deps, Build, [])],
          reaches = maps:merge(Reaches,
                               maps:from_list([{{QualifiedName, Position}, Reach}
                                               || {QualifiedName, Position, Reach}
                                                      <- maps:values(Functions)])),
          link = link(Namespace, FormNamespace, Canonical, Env, Units),
          standard = maps:get(standard, Build, false), code = maps:get(code, Build, false),
          form_namespace = FormNamespace,
          site_namespace = maps:get(site_namespace, Build, Namespace),
          session_offset = maps:get(session_offset, Build, false)}.

%% Report §11.1, §8.7: what the unit's `.erc` records beside its code, by
%% which a definition is shipped onward and a compiled module loaded beside
%% another unit of its name is made a unit of its own (§11.2): each
%% definition with the lines of its source, an input's counted as its
%% session counts them, the locals' names left out, the name its sites
%% write it by where that is not its qualified name, and what prints a type
%% in a cause as its module writes it (§11.5); its foreign declarations,
%% each by its qualified name as the forms write it, an input's under the
%% session's one namespace as its unit lists it (Appendix H, §11.2), with
%% their schemes, what their implementations name and that too; and its
%% bindings' order (§8.5).
recorded(#unit{namespace = Namespace, definitions = Definitions, foreign_functions = Foreign,
               binding_order = BindingOrder, session_offset = SessionOffset,
               form_namespace = FormNamespace} = Unit, Build) ->
    Offset = case SessionOffset of
                 false -> 0;
                 _ -> SessionOffset
             end,
    Printing = printing(Unit),
    #recorded{definitions = [Definition#definition{
                               sourced = ern_canonical:recorded_source(Sourced, Offset),
                               name = sites_name(lists:nthtail(length(Namespace), QualifiedName),
                                                 QualifiedName, Unit, Build),
                               printing = Printing}
                             || #definition{qualified_name = QualifiedName, sourced = Sourced}
                                    = Definition <- Definitions],
              foreign = [{FormNamespace ++ lists:nthtail(length(Namespace), QualifiedName),
                          Scheme, HostModule, HostFunction, Printing}
                         || #foreign_function{qualified_name = QualifiedName, scheme = Scheme,
                                              host_module = HostModule,
                                              host_function = HostFunction} <- Foreign],
              binding_order = BindingOrder}.

%% Report §11.5, §8.7: what prints a type of the unit's in a cause as its
%% module writes it, as text, which a code frame carries: the namespace its
%% forms write the module's types under, a session's one where an input's
%% types are its (Appendix H), and the prelude names its types shadow.
printing(#unit{form_namespace = FormNamespace, link = #link{printing = Printing}}) ->
    {_, Shadows} = ern_types:printed_scope(Printing),
    {[atom_to_binary(Segment) || Segment <- FormNamespace],
     [atom_to_binary(Shadow) || Shadow <- Shadows]}.

%% The name a definition's sites write, as text, where it is not its
%% qualified name (ern_emitter:site_name/2); an input's expression by the
%% name the shell gave it.
sites_name(Declaration, QualifiedName, Unit, Build) ->
    case ern_emitter:site_name(Declaration, Unit) of
        input -> case Build of
                     #{input_name := InputName} -> [InputName];
                     #{} -> none
                 end;
        QualifiedName -> none;
        Named -> [atom_to_binary(Segment) || Segment <- Named]
    end.

%% Report §11.2: the unit a module's namespace is, its Erlang name but where
%% the shell gave it another, a reload's version being a unit of its own.
unit_of(Namespace, Units) ->
    case Units of
        #{Namespace := Unit} -> Unit;
        _ -> ern_namespace:erlang_module(Namespace)
    end.

exported(#fn_declaration{export = Export}) -> Export;
exported(#let_declaration{export = Export}) -> Export;
exported(_) -> false.

qualified(Namespace, #fn_declaration{member_of = MemberOf, name = Name}) ->
    [Namespace ++ [MemberOf || MemberOf =/= undefined] ++ [Name]];
qualified(Namespace, #let_declaration{name = Name}) ->
    [Namespace ++ [Name]].

%% Report §4.7, §8.4: the module's foreign functions, in the order it
%% declares them, each with its scheme as a form writes it and what its
%% implementation names.
foreign_functions(Namespace, Declarations, ForeignSchemes) ->
    [begin
         QualifiedName = Namespace ++ [MemberOf || MemberOf =/= undefined] ++ [Name],
         {ok, {HostModule, HostFunction, _}} =
             ern_typecheck:foreign_implementation(Implementation),
         {Line, Column, _} = ern_diagnostic:span(Span),
         #foreign_function{qualified_name = QualifiedName,
                           scheme = maps:get(QualifiedName, ForeignSchemes),
                           host_module = HostModule, host_function = HostFunction,
                           export = Export, source = {Line, Column, none}}
     end
     || #foreign_fn_declaration{span = Span, export = Export, member_of = MemberOf, name = Name,
                                implementation = Implementation} <- Declarations].

%%
%% The link, report §8.7 and §11.1
%%

%% Report §11.1: where each reference the module's forms make outside its
%% unit is, as the checker's environment, which holds the interfaces of the
%% modules it is compiled against, knows it: a function's, a binding's or
%% a foreign function's unit, function, arity, kind and identity, and a
%% type's name and constructors, those of every type a linked type names
%% among them; and the state a type prints under from the module (§11.5).
%% Links names the qualified name of each reference whose form does not,
%% a function's or a type's by its hash among them. The shell links so a
%% compiled module it loads beside another unit of its name, from its
%% interfaces (§11.2).
-spec link([atom()], [atom()], #{definitions := [#definition{}], links := [{term(), [atom()]}],
                                 foreign_schemes := #{[atom()] => term()}, atom() => term()},
           ern_typecheck:env(), #{[atom()] => atom()}) -> #link{}.
link(Namespace, FormNamespace, #{definitions := Definitions, links := Links,
                                 foreign_schemes := ForeignSchemes}, Env, Units) ->
    Named = maps:from_list(Links),
    Forms = [Form || #definition{form = Form} <- Definitions] ++ maps:values(ForeignSchemes),
    Own = own_references(Definitions, maps:keys(ForeignSchemes), Namespace, FormNamespace),
    External = [Reference || Reference <- references(Forms), not is_own(Reference, Own)],
    Scope = {Namespace, FormNamespace, Env, Units},
    {Types, Named1} = types([Reference || Reference <- External, is_type(Reference, Named, Env)],
                            #{}, Named, Scope),
    #link{functions = maps:from_list([{Reference, Linked}
                                      || Reference <- External,
                                         not is_type(Reference, Named1, Env),
                                         Linked <- linked(Reference, Named1, Scope)]),
          types = Types,
          printing = ern_types:printing(ern_typecheck:type_state(Env))}.

%% What the module's own definitions and foreign functions are named by in
%% its forms: each definition by its hash, a binding by its identity, each
%% by its name as the standard library's own forms name it, and a foreign
%% function by its qualified name as a form writes it.
own_references(Definitions, ForeignFunctions, Namespace, FormNamespace) ->
    FormName = fun(QualifiedName) ->
                       FormNamespace ++ lists:nthtail(length(Namespace), QualifiedName)
               end,
    #{hashes => [Hash || #definition{hash = Hash} <- Definitions],
      names => [QualifiedName || #definition{qualified_name = QualifiedName} <- Definitions]
          ++ ForeignFunctions,
      form_names => [FormName(QualifiedName)
                     || #definition{qualified_name = QualifiedName} <- Definitions]
          ++ [FormName(QualifiedName) || QualifiedName <- ForeignFunctions]}.

is_own({hash, Hash}, #{hashes := Hashes}) -> lists:member(Hash, Hashes);
is_own({binding, QualifiedName, _}, #{form_names := Names}) -> lists:member(QualifiedName, Names);
is_own({named, QualifiedName}, #{names := Names}) -> lists:member(QualifiedName, Names);
is_own({foreign, QualifiedName, _}, #{form_names := Names}) -> lists:member(QualifiedName, Names).

%% Report §11.1, Appendix H: every reference to a declaration forms make,
%% and the `<>` of a prelude type the runtime's own operation at that type
%% calls, each once.
-spec references([term()]) -> [term()].
references(Forms) ->
    lists:usort(references_in(Forms) ++ appended_in(Forms)).

%% Report §8.7: a reference by name to a function or a binding of the
%% standard library or the prelude, linked as the build links it, from an
%% environment that holds the library's interfaces, the prelude's; none
%% for a name of the prelude's that is no value. A unit an exchange makes
%% links so what its forms name by name (ern_arrival).
-spec named({named, [atom()]}, ern_typecheck:env()) -> [#linked{}].
named(Reference, Env) ->
    linked(Reference, #{}, {[], [], Env, #{}}).

%% Every reference to a declaration a term makes (Appendix H).
references_in({hash, Hash} = Reference) when is_binary(Hash), byte_size(Hash) =:= 32 ->
    [Reference];
references_in({binding, QualifiedName, Hash} = Reference)
  when is_list(QualifiedName), is_binary(Hash) ->
    [Reference];
references_in({named, QualifiedName} = Reference) when is_list(QualifiedName) ->
    case lists:all(fun is_atom/1, QualifiedName) of
        true -> [Reference];
        false -> references_in(QualifiedName)
    end;
references_in({foreign, QualifiedName, Scheme} = Reference) when is_list(QualifiedName) ->
    [Reference | references_in(Scheme)];
references_in(Term) when is_tuple(Term) ->
    references_in(tuple_to_list(Term));
references_in(Terms) when is_list(Terms) ->
    lists:append([references_in(Term) || Term <- Terms]);
references_in(_) ->
    [].

%% Report §9.6: the `<>` of a prelude type whose module provides it in
%% Ernest, `List.<>` and `Path.<>`, which the runtime's own operation at
%% that type calls (Appendix H's `{runtime, Type}`), by its name.
appended_in({operator, '<>', Left, Right, {runtime, {applied, {named, [Name]}, _}}})
  when Name =/= 'String', Name =/= 'Bytes' ->
    [{named, [Name, '<>']} | appended_in([Left, Right])];
appended_in(Term) when is_tuple(Term) ->
    appended_in(tuple_to_list(Term));
appended_in(Terms) when is_list(Terms) ->
    lists:append([appended_in(Term) || Term <- Terms]);
appended_in(_) ->
    [].

%% The qualified name a reference names, as the checker knows it: the one
%% the walk recorded, where the form names it otherwise, and else its own.
named_by({named, QualifiedName} = Reference, Named) ->
    maps:get(Reference, Named, QualifiedName);
named_by({binding, QualifiedName, _} = Reference, Named) ->
    maps:get(Reference, Named, QualifiedName);
named_by({foreign, QualifiedName, _} = Reference, Named) ->
    maps:get(Reference, Named, QualifiedName);
named_by(Reference, Named) ->
    maps:get(Reference, Named, undefined).

is_type({hash, _} = Reference, Named, Env) ->
    is_type_name(named_by(Reference, Named), Env);
is_type({named, _} = Reference, Named, Env) ->
    is_type_name(named_by(Reference, Named), Env);
is_type(_, _, _) ->
    false.

is_type_name(undefined, _) -> false;
is_type_name(QualifiedName, Env) -> ern_typecheck:described_type(QualifiedName, Env) =/= undefined.

%% Each type of References with its name and constructors, and those its
%% constructors name, each once; the qualified names their walks recorded
%% added to Named.
types([], Types, Named, _) ->
    {Types, Named};
types([Reference | References], Types, Named, Scope) when is_map_key(Reference, Types) ->
    types(References, Types, Named, Scope);
types([Reference | References], Types, Named, {Namespace, FormNamespace, Env, _} = Scope) ->
    QualifiedName = named_by(Reference, Named),
    case ern_canonical:declared_type(QualifiedName, Env, Namespace, FormNamespace) of
        foreign ->
            types(References, Types#{Reference => {QualifiedName, foreign}}, Named, Scope);
        {Arity, Constructors, Links} ->
            Named1 = maps:merge(maps:from_list(Links), Named),
            Inner = [Inner || Inner <- lists:usort(references_in(Constructors)),
                              is_type(Inner, Named1, Env)],
            types(Inner ++ References,
                  Types#{Reference => {QualifiedName, {Arity, Constructors}}}, Named1, Scope)
    end.

%% A reference to another unit's function, binding or foreign function, as
%% the link holds it; none for a name of the prelude's that is no value.
linked(Reference, Named, {_, _, Env, Units}) ->
    QualifiedName = named_by(Reference, Named),
    case ern_typecheck:global_scheme(QualifiedName, Env) of
        undefined ->
            [];
        Scheme ->
            {Unit, Function} = case ern_typecheck:position(QualifiedName, Env) of
                                   {Namespace, Held} ->
                                       {unit_of(Namespace, Units),
                                        ern_emitter:function_name(Held)};
                                   undefined ->
                                       {undefined, undefined}
                               end,
            Kind = case ern_typecheck:is_value(QualifiedName, Env) of
                       true -> value;
                       false -> function
                   end,
            [#linked{unit = Unit, function = Function, arity = scheme_arity(Scheme, Kind),
                     kind = Kind, identity = identity(Reference, QualifiedName, Env)}]
    end.

%% The arity of a declaration's function: a function's parameters and its
%% requirement's members (report §4.9), and a binding's getter none.
scheme_arity(_, value) -> 0;
scheme_arity(#scheme{type = {tfn, Params, _, _}, requirement = Requirement}, function) ->
    length(Params) + length(Requirement);
scheme_arity(#scheme{}, function) -> 0.

identity({hash, Hash}, _, _) -> Hash;
identity({binding, _, Hash}, _, _) -> Hash;
identity({foreign, _, _}, _, _) -> foreign;
identity({named, _}, QualifiedName, Env) -> ern_typecheck:identity(QualifiedName, Env).
