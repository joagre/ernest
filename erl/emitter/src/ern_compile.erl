%% The compile of one checked module, report §11.1: its definitions'
%% canonical forms and their hashes (ern_canonical, §8.7, Appendix H), what
%% its build adds that is no definition's, and the link of what the forms
%% reference outside its unit, read from the checker's environment, which
%% hold everything the emitter makes the unit of (ern_unit.hrl); and the
%% compiled unit with its chunks: the interface "ErnI", with the source's
%% hash and per dependency the hash of the interface compiled against, and
%% the documentation as EEP 48's "Docs" (§11.4), which are the build's and
%% no unit's and so are made from the typed tree and the environment; and
%% the forms as "ErnC".
-module(ern_compile).

-export([compile/4, compile/5, forms/3, forms/4, erl_source/3, erl_source/4, unit/5]).

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
%% not kept. The chunk records beside the build's facts whether the module
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
                site_namespace => [atom()]}) ->
          {ok, atom(), binary()}.
compile(Namespace, Declarations, Interface, Env, Build) ->
    %% report §8.7, §11.1, Appendix H: the canonical forms and their hashes,
    %% the hashes in the interface, by which a dependent's forms name its
    %% definitions, and the hashes of other modules' definitions its own
    %% forms name, which the recompile rule compares
    Canonical = canonical(Namespace, Declarations, Env, Build),
    #{references := References} = Canonical,
    {Forms, BuildsFunctions} =
        ern_emitter:unit(unit(Namespace, Declarations, Env, Canonical, Build#{code => true})),
    Facts = (maps:without([source, session_offset, form_namespace, standard, units,
                           site_namespace, code, canonical], Build))
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
    #{definitions := Definitions, sourced := Sourced, reaches := Reaches,
      functions := Functions, foreign_schemes := ForeignSchemes} = Canonical,
    #unit{namespace = Namespace, name = unit_of(Namespace, Units), definitions = Definitions,
          sourced = Sourced,
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
%% a foreign function's unit, position, arity, kind and identity, and a type's
%% name and constructors, those of every type a linked type names among
%% them; and the state a type prints under from the module (§11.5).
link(Namespace, FormNamespace, #{definitions := Definitions, links := Links,
                                 foreign_schemes := ForeignSchemes}, Env, Units) ->
    Named = maps:from_list(Links),
    Forms = [Form || #definition{form = Form} <- Definitions] ++ maps:values(ForeignSchemes),
    Own = own_references(Definitions, maps:keys(ForeignSchemes), Namespace, FormNamespace),
    External = [Reference || Reference <- lists:usort(references_in(Forms)
                                                      ++ appended_in(Forms)),
                             not is_own(Reference, Own)],
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
            {Unit, Position} = case ern_typecheck:position(QualifiedName, Env) of
                                   {Namespace, Held} -> {unit_of(Namespace, Units), Held};
                                   undefined -> {undefined, undefined}
                               end,
            Kind = case ern_typecheck:is_value(QualifiedName, Env) of
                       true -> value;
                       false -> function
                   end,
            [#linked{unit = Unit, position = Position, arity = scheme_arity(Scheme, Kind),
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
