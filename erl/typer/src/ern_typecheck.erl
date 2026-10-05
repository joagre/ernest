%% Type inference for Ernest modules, report §3, §4, §5, §6: algorithm W
%% with levels for generalization over the AST of ern_parser, producing the
%% same AST with every type slot filled and the module's interface.
%%
%% Effects are the extra slot on the arrow (report §3.9): a call to a
%% function whose effect is pure constrains nothing; any other effect is
%% unified with the enclosing function's effect. receive, self, and the
%% process primitives force that effect to be a mailbox type.
%%
%% Per definition, after inference, as post_checks/3 runs them: what was
%% deferred, operators, selections, `<-` and receive guards' orderings
%% (report §4.8, §3.5, §5.5, §6.3); what each requirement is supplied with
%% (§4.9); rigidity of annotation variables (§3.9); the order of a block's
%% local fns and lets (§5.4, ern_scope); match exhaustiveness (ern_exhaust);
%% a top-level let that holds no reply and the reply discipline (§6.6,
%% ern_reply); the restrictions instances carry (§3.9, §3.10); and a
%% `with m` that names no effect (§4.5). Errors are collected per
%% definition; checking continues with the next.
-module(ern_typecheck).

-export([check/3, check/4, check_string/2, type_state/1, scope_state/2, set_type_state/2,
         prelude_names/1, prelude_values/1, prelude_constructor/2, prelude_constructors/1,
         prelude_env/0, lookup_type/2, is_reply_carrying/2, assume_reply_carrying/2,
         restricted_reply_carrying/1, let_order/1, foreign_implementation/1, fields/2,
         declared_scheme/3, session_member/3, lookup_constructor/4, constructor_info/2,
         is_value/2, resolve_type/2, node_type/1]).

-export_type([env/0, session_scope/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

%% The checker's environment. Of its fields:
%% lets: the qualified names, this module's and its dependencies', that
%% were declared with `let`; the emitter reaches a value through its getter
%% session_scope: the shell's session, a scope between this module's own
%% declarations and the prelude (report §11.2), empty in every other module
%% pending, deferred: what the definition being checked leaves for its
%% end, the #pending_restriction{}s and the deferred records below
%% effect_origin: undefined or the #effect_origin{} of the mailbox here
%% groups: qualified name => the dependency group not yet checked that
%% declares it, checked on first demand (a reference, or an operator
%% resolving to it); typed: the groups checked so far; diagnostics: their
%% errors
%% reply_variables: type variables the reply discipline takes for
%% reply-carrying while it asks whether a body would keep §6.6 if they
%% were (§3.9)
%% reply_params: for each declared type with parameters, whether each can
%% make an instantiation reply-carrying (report §6.6)
%% let_order: the module's top-level lets in the order §8.5 evaluates
%% them, which the emitter reads
%% effectful: whether the definition being checked has called a
%% process-only function; effectful_lets: the top-level lets whose
%% initializer has, which are not generalized (report §4.6)
%% generalizing: whether the lambda about to be inferred is a binding's
%% whole value that is generalized, so that a type variable its annotation
%% names first is rigid and quantified (report §3.9)
%% provided: the namespaces the toolchain provides, the prelude's and the
%% standard library's, which `Prelude.T.name` reaches (report §4.2)
%% inferring: the definitions whose inference is under way, {global,
%% QualifiedName} for a top-level group's members and {local, Name} for a
%% block's local fns, so that a call to one is known as a recursive call
%% (report §3.9, §11.5)
%% requirement: the members in force in the definition being checked, the
%% enclosing `fn` declarations' requirements, [{TypeVariable, Member}]
%% (report §4.9); signature: the type variables their signatures write,
%% [{TypeVariable, Name, DeclarationName}], which an error names;
%% definition: the top-level or local definition being checked, {fn, Name}
%% or {'let', Name}
-record(env, {namespace = [], types = #{}, constructors = #{}, globals = #{}, lets = #{},
              local_types = #{}, local_constructors = #{}, local_values = #{}, session_scope = #{},
              locals = #{}, effect = pure, type_state, pending = [], deferred = [],
              annotation_variables = #{}, rigid = [], effect_origin = undefined,
              groups = #{}, typed = [], diagnostics = [], reply_variables = [],
              reply_params = #{}, let_order = [], effectful = false, effectful_lets = [],
              generalizing = false, provided = [], inferring = [], requirement = [],
              signature = [], definition}).
-opaque env() :: #env{}.

%% What fixes the mailbox where an expression stands, which an effect error
%% names (report §11.5): what is pure or has the mailbox, "f", "the
%% lambda", "a guard", or top_let for a top-level `let`, whose mailbox is
%% Never; the span that made it so, its label, and what to do.
-record(effect_origin, {what, span, label, help}).

%% A restriction an instance carries, checked when its definition ends
%% (report §3.9, §3.10): equality or not_reply_carrying, the type
%% variable's id, where the instance stands, what needs the equality, the
%% name and printed type the instance was taken of, and the span and place
%% of the argument a call passes the variable in, {Span, Index}.
-record(pending_restriction, {restriction, id, span, need, who, argument}).

%% What waits for the end of a definition, where its types are known: an
%% operator and a field selection whose operand type is still a variable
%% (report §4.8, §3.5), with the origin of the type expected of the
%% result; and a `<-` whose sum type is (§5.5). What a requirement is
%% supplied with, and what `Io.show` writes by (§4.9, Appendix E.1), waits
%% in the typed AST as a #pending_member{}. settled: the span of the
%% unification that fixed the operand type, a label of the mismatch (§11.5).
-record(deferred_operator, {span, operator, operand_type, result, origin, settled}).
-record(deferred_selection, {span, field, operand_type, result, origin, settled}).
-record(deferred_bind_arrow, {span, spans, expr_type, pattern_type, rest_type, fixed}).
%% A `receive` guard's ordering whose operand type is still a variable
%% (report §6.3), checked once the type is known.
-record(deferred_guard_order, {span, operator, operand_type}).

%% What the checks after inference need of a definition: its scope as it
%% ends, since a deferred operator calls its member under the definition's
%% own mailbox and adds its restrictions to the definition's (report §4.8,
%% §3.4, §3.10), and a requirement is supplied from the members in force
%% there (§4.9).
-record(post_check, {span, type, effect, effect_origin, rigid, pending, deferred, requirement,
                     signature, definition}).

%% A block's local fns as its statements are checked (report §5.4, §3.9):
%% the placeholder type of each, the local fns each names, those checked,
%% and those checked but not yet generalized, which wait for the fns they
%% depend on.
-record(local_fns, {placeholders, dependencies, checked = [], waiting = []}).

-type key() :: atom() | {atom(), atom()}.
-type session_scope() :: #{values => #{key() => [atom()]}, types => #{atom() => [atom()]},
                           constructors => #{atom() => [atom()]},
                           input_names => #{[atom()] => string()}}.

-define(INT, {tcon, ['Int'], []}).
-define(FLOAT, {tcon, ['Float'], []}).
-define(CHAR, {tcon, ['Char'], []}).
-define(STRING, {tcon, ['String'], []}).
-define(BYTES, {tcon, ['Bytes'], []}).
-define(BOOL, {tcon, ['Bool'], []}).
-define(UNIT, {tcon, ['Unit'], []}).
-define(NEVER, {tcon, ['Never'], []}).
-define(ARITH, ['+', '-', '*', '/', '%']).
-define(ORDER, ['<', '<=', '>', '>=']).

%%
%% Entry points
%%

%% On success: the typed declarations, the module's interface, and the
%% environment, which the compiler needs for the layouts of private types.
-spec check([atom()], [tuple()], [#interface{}]) ->
          {ok, [tuple()], #interface{}, env()} | {error, [ern_diagnostic:diagnostic()]}.
check(Namespace, Parsed, Interfaces) ->
    check(Namespace, Parsed, Interfaces, #{}).

%% Report §11.2: the shell's session is a scope of its own, looked in after
%% the input's own declarations and before the prelude. Its three maps take
%% an unqualified name, as a module's own do, to the qualified name of the
%% input that declared it.
-spec check([atom()], [tuple()], [#interface{}], session_scope()) ->
          {ok, [tuple()], #interface{}, env()} | {error, [ern_diagnostic:diagnostic()]}.
check(Namespace, Parsed, Interfaces, SessionScope) ->
    Declarations = builtin_operators(Namespace, Parsed),
    Seeded = lists:foldl(fun add_interface/2, (prelude_env())#env{namespace = Namespace},
                         Interfaces),
    every_type_declared(Interfaces, Seeded),
    Env = Seeded#env{session_scope = SessionScope},
    try
        one_clause(Parsed),
        declared_twice(Declarations),
        host_names(Declarations),
        {Env1, TypeDiagnostics} = declare_types(Declarations, Env),
        %% report §11.5: the module's types print unqualified, except those
        %% that shadow a prelude name
        Shadows = [Name || Name <- maps:keys(Env1#env.local_types),
                           is_map_key([Name], Env1#env.types)],
        %% report §11.2: a session type prints unqualified, except one a
        %% later input has shadowed, which prints as the input that declared it
        SessionTypes = maps:values(maps:get(types, SessionScope, #{})),
        TypeState1 = ern_types:set_scope(Namespace, SessionTypes, Shadows,
                                         maps:get(input_names, SessionScope, #{}),
                                         effect_param_state(Env1)),
        Env2 = mark_abstract(Declarations, Env1#env{type_state = TypeState1}),
        %% report §3.5: a type that derives compare gains the member
        WithDerived = derived_members(Declarations, Env2),
        {Typed, Env3, ValueDiagnostics} = check_values(WithDerived, Env2),
        ExportDiagnostics = check_abstract(Declarations) ++ check_exports(WithDerived, Env3),
        case lists:sort(TypeDiagnostics ++ ValueDiagnostics ++ ExportDiagnostics) of
            [] -> {ok, Typed, interface_of(WithDerived, Env3), Env3};
            Found -> {error, hidden_notes(Declarations, Found, Seeded)}
        end
    catch
        throw:{type_error, Span, Message} ->
            {error, hidden_notes(Declarations, [diagnostic(Span, Message)], Seeded)};
        throw:{type_error, #diagnostic{} = Diagnostic} ->
            {error, hidden_notes(Declarations, [Diagnostic], Seeded)};
        throw:{type_errors, Diagnostics} ->
            {error, hidden_notes(Declarations, lists:sort(Diagnostics), Seeded)}
    end.

%% Report §4.2, §11.5: a module's own declaration hides a prelude name of
%% the same spelling in the module, and an error at a use of such a name
%% says so, with the prelude's qualified name, since what the writer meant
%% may be the prelude's. The note is a label on the use. Seeded is the
%% environment the check began with, the prelude's names among it.
hidden_notes(Declarations, Diagnostics, Seeded) ->
    {PreludeTypes, PreludeConstructors} = prelude_names(Seeded),
    PreludeValues = [QualifiedName || {[_] = QualifiedName, _, _} <- ern_prelude:values()],
    Types = [Name || #type_declaration{name = Name} <- declared_types(Declarations)],
    ConstructorNames = [Name || #type_declaration{constructors = Constructors}
                                    <- declared_types(Declarations),
                                #constructor{name = Name} <- Constructors],
    Values = [Name || Declaration <- Declarations, Name <- top_value_name(Declaration)],
    Hidden = [{type, Name} || Name <- Types, lists:member([Name], PreludeTypes)]
        ++ [{constructor, Name} || Name <- ConstructorNames,
                                   lists:member([Name], PreludeConstructors)]
        ++ [{value, Name} || Name <- Values, lists:member([Name], PreludeValues)],
    case Hidden of
        [] -> Diagnostics;
        _ ->
            Uses = hidden_uses(Declarations, Hidden),
            [hidden_note(Diagnostic, Uses) || Diagnostic <- Diagnostics]
    end.

declared_types(Declarations) ->
    [Declaration || #type_declaration{} = Declaration <- Declarations]
        ++ [Declaration || #abstract_declaration{declaration = Declaration} <- Declarations].

top_value_name(#fn_declaration{member_of = undefined, name = Name}) -> [Name];
top_value_name(#let_declaration{name = Name}) -> [Name];
top_value_name(#foreign_fn_declaration{member_of = undefined, name = Name}) -> [Name];
top_value_name(_) -> [].

%% Each unqualified use of a hidden name, its span and what it names.
hidden_uses(Declarations, Hidden) ->
    Uses = fun Walk(#t_named{namespace = [], name = Name, span = Span} = Node) ->
                   [{Span, type, Name} || lists:member({type, Name}, Hidden)]
                       ++ Walk(Node#t_named.args);
               Walk(#e_constructor{namespace = [], name = Name, span = Span} = Node) ->
                   [{Span, constructor, Name} || lists:member({constructor, Name}, Hidden)]
                       ++ Walk(Node#e_constructor.base) ++ Walk(Node#e_constructor.args);
               Walk(#p_constructor{namespace = [], name = Name, span = Span} = Node) ->
                   [{Span, constructor, Name} || lists:member({constructor, Name}, Hidden)]
                       ++ Walk(Node#p_constructor.args);
               Walk(#e_var{namespace = [], name = Name, span = Span}) ->
                   [{Span, value, Name} || lists:member({value, Name}, Hidden)];
               Walk(Node) when is_tuple(Node) ->
                   lists:append([Walk(Child) || Child <- tuple_to_list(Node)]);
               Walk(Nodes) when is_list(Nodes) -> lists:append([Walk(Child) || Child <- Nodes]);
               Walk(_) -> []
           end,
    Uses(Declarations).

%% A diagnostic whose primary span holds a use of a hidden name gains the
%% note at that use.
hidden_note(#diagnostic{span = Span, labels = Labels} = Diagnostic, Uses) ->
    Notes = [{ern_diagnostic:span(UseSpan), note_text(Kind, Name)}
             || {UseSpan, Kind, Name} <- Uses, is_within(ern_diagnostic:span(UseSpan), Span)],
    Diagnostic#diagnostic{labels = Labels ++ lists:usort(Notes)};
hidden_note(Diagnostic, _) ->
    Diagnostic.

note_text(Kind, Name) ->
    Text = atom_to_list(Name),
    "`" ++ Text ++ "` here is this module's " ++ atom_to_list(Kind)
    ++ ", and the prelude's is `Prelude." ++ Text ++ "`".

%% Whether a position lies inside a span, whose end is past its last
%% column (ern_diagnostic).
is_within({Line, Column, _}, {StartLine, StartColumn, {EndLine, EndColumn}}) ->
    ({Line, Column} >= {StartLine, StartColumn}) andalso ({Line, Column} < {EndLine, EndColumn});
is_within(_, _) ->
    false.

%% Report §4.5, §11.5: a function has one clause, and a second fn of one
%% name directly after the first, the habit of languages whose functions
%% have clauses, is said to be that, at the second with the first labelled.
one_clause([#fn_declaration{span = First, member_of = MemberOf, name = Name},
            #fn_declaration{span = Second, member_of = MemberOf, name = Name} | _]) ->
    fail(Second, "a function has one clause", [{ern_diagnostic:span(First), "first clause"}],
         "write one clause whose body is a `match`");
one_clause([_ | Rest]) ->
    one_clause(Rest);
one_clause([]) ->
    ok.

%% Report §4.2, §11.5: a type, a constructor or a value a module declares
%% twice is an error at the second, with the first labelled.
declared_twice(Declarations) ->
    Named = [{{Kind, Key}, Span} || Declaration <- Declarations,
                                    {Kind, Key, Span} <- declaration_names(Declaration)],
    case repeated(Named) of
        none ->
            ok;
        {{Kind, Key}, First, Second} ->
            fail(Second, atom_to_list(Kind) ++ " " ++ key_text(Key) ++ " is declared twice",
                 [{ern_diagnostic:span(First), "first declared here"}], undefined)
    end.

%% Report §11.1: the host holds a name of at most 255 characters, so a
%% member whose Erlang function name, its type's name and its own joined by
%% `.`, passes it is refused, a foreign one and a derived `compare` among
%% them. A module's Erlang name is the build's to refuse
%% (ern_build:module_of/3), and a foreign fn's implementation's names are
%% refused where it is checked. Every other name the module compiles to is
%% a name of §2.3's length or the emitter's own, which it cuts to fit.
host_names(Declarations) ->
    Members = [{Span, MemberOf, Name}
               || #fn_declaration{span = Span, member_of = MemberOf, name = Name} <- Declarations,
                  MemberOf =/= undefined]
        ++ [{Span, MemberOf, Name}
            || #foreign_fn_declaration{span = Span, member_of = MemberOf, name = Name}
                   <- Declarations,
               MemberOf =/= undefined]
        ++ [{Span, Name, compare}
            || #type_declaration{name = Name, derives = Span} <- declared_types(Declarations),
               Span =/= undefined],
    lists:foreach(fun({Span, MemberOf, Name}) ->
                      Function = atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name),
                      length(Function) =< ern_namespace:host_name_limit()
                          orelse fail(Span, host_member_text(Function), [],
                                      host_member_help(MemberOf, Function))
                  end, Members).

host_member_text(Function) ->
    ern_namespace:host_name_text("the member's Erlang name, its type's and its own joined by"
                                 " `.`,", Function).

host_member_help(MemberOf, Function) ->
    Most = length(atom_to_list(MemberOf)) - (length(Function) - ern_namespace:host_name_limit()),
    lists:flatten(io_lib:format("shorten the type's name to at most ~B characters", [Most])).

%% The first of Items whose key an earlier one has, with that earlier one's
%% value and its own, `{Key, First, Second}`, or `none`.
repeated(Items) ->
    repeated(Items, #{}).

repeated([], _Seen) ->
    none;
repeated([{Key, Value} | Rest], Seen) ->
    case Seen of
        #{Key := First} -> {Key, First, Value};
        _ -> repeated(Rest, Seen#{Key => Value})
    end.

declaration_names(#type_declaration{span = Span, name = Name, constructors = Constructors}) ->
    [{type, Name, Span}
     | [{constructor, ConstructorName, ConstructorSpan}
        || #constructor{span = ConstructorSpan, name = ConstructorName} <- Constructors]];
declaration_names(#abstract_declaration{declaration = TypeDeclaration}) ->
    declaration_names(TypeDeclaration);
declaration_names(#foreign_type_declaration{span = Span, name = Name}) ->
    [{type, Name, Span}];
declaration_names(#fn_declaration{span = Span, member_of = MemberOf, name = Name}) ->
    [{value, {MemberOf, Name}, Span}];
declaration_names(#let_declaration{span = Span, name = Name}) ->
    [{value, {undefined, Name}, Span}];
declaration_names(#foreign_fn_declaration{span = Span, member_of = MemberOf, name = Name}) ->
    [{value, {MemberOf, Name}, Span}];
declaration_names(_) ->
    [].

key_text({MemberOf, Name}) -> local_name(MemberOf, Name);
key_text(Name) -> atom_to_list(Name).

%% Report §4.8: in the standard library module of a built-in type with
%% members, an operator declared as that type's, `fn Float.+` in float.ern,
%% is the module's own `+`, as a self-qualified name is (§4.2). A prelude
%% type without members takes no namespace, and a module named after one,
%% `never.ern`, is a program's own.
builtin_operators([TypeName], Declarations) ->
    case lists:member(TypeName, ern_prelude:member_types()) of
        true -> [own_operator(TypeName, Declaration) || Declaration <- Declarations];
        false -> Declarations
    end;
builtin_operators(_, Declarations) ->
    Declarations.

own_operator(TypeName, #fn_declaration{member_of = TypeName, name = Name} = Declaration) ->
    case is_operator(Name) of
        true -> Declaration#fn_declaration{member_of = undefined};
        false -> Declaration
    end;
own_operator(TypeName, #foreign_fn_declaration{member_of = TypeName, name = Name} = Declaration) ->
    case is_operator(Name) of
        true -> Declaration#foreign_fn_declaration{member_of = undefined};
        false -> Declaration
    end;
own_operator(_, Declaration) ->
    Declaration.

-spec check_string([atom()], unicode:chardata()) ->
          {ok, [tuple()], #interface{}, env()} | {error, [ern_diagnostic:diagnostic()]}.
check_string(Namespace, Text) ->
    case ern_parser:parse_string(Text) of
        {ok, Declarations} -> check(Namespace, Declarations, []);
        {error, Diagnostic} -> {error, [Diagnostic]}
    end.

diagnostic(Span, Message) -> #diagnostic{span = ern_diagnostic:span(Span), message = Message}.

-spec type_state(env()) -> ern_types:type_state().
type_state(#env{type_state = TypeState}) -> TypeState.

%% The state a type is printed under outside a check: the prelude's, and
%% which parameters of the types of Interfaces are no value position (report
%% §3.9), so a variable found only in one prints as an effect variable does.
-spec scope_state([#interface{}], env()) -> ern_types:type_state().
scope_state(Interfaces, PreludeEnv) ->
    effect_param_state(lists:foldl(fun add_interface/2, PreludeEnv, Interfaces)).

-spec set_type_state(ern_types:type_state(), env()) -> env().
set_type_state(TypeState, Env) -> Env#env{type_state = TypeState}.

%%
%% The prelude
%%

%% Report §11.2: the types and constructors the prelude declares, for
%% the shell's completion, which offers them as it offers a module's. Env
%% is the prelude's environment, prelude_env/0's or one built over it.
-spec prelude_names(env()) -> {[[atom()]], [[atom()]]}.
prelude_names(#env{types = Types, constructors = Constructors}) ->
    {maps:keys(Types), maps:keys(Constructors)}.

%% Report §11.2: the values the prelude declares, each with its scheme, for
%% the shell's `:browse Prelude` and its completion.
-spec prelude_values(env()) -> [{[atom()], #scheme{}}].
prelude_values(#env{globals = Globals}) ->
    [{QualifiedName, maps:get(QualifiedName, Globals)}
     || {QualifiedName, _, _} <- ern_prelude:values(), is_map_key(QualifiedName, Globals)].

%% Report §11.2: a prelude constructor, whose type is the page that
%% documents it and whose scheme a listing shows, for the shell.
-spec prelude_constructor(atom(), env()) -> {ok, #constructor_info{}} | none.
prelude_constructor(Name, Env) ->
    case prelude_constructors(Env) of
        #{[Name] := ConstructorInfo} -> {ok, ConstructorInfo};
        _ -> none
    end.

%% Every prelude constructor by its qualified name.
-spec prelude_constructors(env()) -> #{[atom()] => #constructor_info{}}.
prelude_constructors(#env{constructors = Constructors}) ->
    Constructors.

-spec prelude_env() -> env().
prelude_env() ->
    Env1 = #env{type_state = ern_types:new()},
    AddBuiltin = fun({Name, Arity, _Doc}, Acc) ->
                     {Params, Acc1} = parameter_variables(lists:seq(1, Arity), Acc),
                     add_type(Acc1, #type_info{qualified_name = [Name], params = Params,
                                               foreign = true,
                                               equality = ern_prelude:equality_params(Name)})
                 end,
    Env2 = lists:foldl(AddBuiltin, Env1, ern_prelude:builtin_types()),
    {ok, Declarations} = ern_parser:parse_string(ern_prelude:declared_types()),
    {Env3, []} = declare_types(Declarations, Env2),
    Env4 = Env3#env{type_state = effect_param_state(Env3)},
    Env5 = lists:foldl(fun({QualifiedName, Text, _Doc}, Acc) ->
                           {ok, Syntax} = ern_parser:parse_type(Text),
                           ProcessOnly = lists:member(QualifiedName, ern_prelude:process_only()),
                           {Scheme, Acc1} = signature_scheme(Syntax, ProcessOnly, Acc),
                           Acc1#env{globals = maps:put(QualifiedName, Scheme, Acc1#env.globals)}
                       end,
                       Env4#env{namespace = [], local_types = #{}, local_constructors = #{},
                                local_values = #{}},
                       ern_prelude:values()),
    %% the standard library modules written in Ernest, by their interfaces
    Stdlib = ern_prelude:stdlib_interfaces(),
    Provided = lists:usort(ern_prelude:member_types()
                           ++ [hd(Interface#interface.namespace) || Interface <- Stdlib]),
    lists:foldl(fun add_interface/2, Env5#env{provided = Provided}, Stdlib).

%% Report §11.1: every type the interfaces given name, in a value's scheme
%% or a constructor's, has a declaration among them or the prelude's, but
%% for a type of the interface's own module, which may be private, a
%% mailbox type an exported function receives (§4.2). One that has none is
%% the toolchain's own defect, since a module depends on each module that
%% declares a type an interface it depends on names, so the check fails
%% closed rather than read such a type as a built-in one.
every_type_declared(Interfaces, #env{types = Types}) ->
    Undeclared = [QualifiedName
                  || #interface{namespace = Namespace, types = InterfaceTypes, values = Values}
                         <- Interfaces,
                     QualifiedName <- lists:usort(type_names({maps:values(Values),
                                                              maps:values(InterfaceTypes)}, [])),
                     lists:droplast(QualifiedName) =/= Namespace,
                     not is_map_key(QualifiedName, Types)],
    case Undeclared of
        [] -> ok;
        [QualifiedName | _] ->
            erlang:error({interface_names_undeclared_type, ern_namespace:text(QualifiedName)})
    end.

type_names({tcon, QualifiedName, Args}, Acc) when is_list(QualifiedName) ->
    type_names(Args, [QualifiedName | Acc]);
type_names(Term, Acc) when is_tuple(Term) ->
    type_names(tuple_to_list(Term), Acc);
type_names(Term, Acc) when is_map(Term) ->
    type_names(maps:to_list(Term), Acc);
type_names([Head | Tail], Acc) ->
    type_names(Tail, type_names(Head, Acc));
type_names(_, Acc) ->
    Acc.

%% Report §4.4: the type's info, and so the compiled interface, marks an
%% abstract type; lookup_constructor refuses its constructor from another
%% module.
mark_abstract(Declarations, #env{local_types = LocalTypes, types = Types} = Env) ->
    Abstract = fun(TypeInfo) -> TypeInfo#type_info{abstract = true} end,
    Mark = fun(#abstract_declaration{declaration = #type_declaration{name = Name}}, Acc) ->
                   maps:update_with(maps:get(Name, LocalTypes), Abstract, Acc);
              (_, Acc) -> Acc
           end,
    Env#env{types = lists:foldl(Mark, Types, Declarations)}.

add_interface(#interface{types = InterfaceTypes, values = Values, lets = Lets},
              #env{types = Types, globals = Globals} = Env) ->
    Constructors = maps:fold(fun(_, #type_info{constructors = TypeConstructors}, Acc) ->
                                 add_constructors(TypeConstructors, Acc)
                             end, Env#env.constructors, InterfaceTypes),
    Env#env{types = maps:merge(Types, InterfaceTypes), globals = maps:merge(Globals, Values),
            constructors = Constructors,
            lets = maps:merge(Env#env.lets,
                              maps:from_list([{QualifiedName, true} || QualifiedName <- Lets]))}.

add_type(#env{types = Types, constructors = Known} = Env,
         #type_info{qualified_name = QualifiedName, constructors = Constructors} = TypeInfo) ->
    Env#env{types = Types#{QualifiedName => TypeInfo},
            constructors = add_constructors(Constructors, Known)}.

%% Constructors by their qualified names, added to Known.
add_constructors(ConstructorInfos, Known) ->
    lists:foldl(fun(#constructor_info{qualified_name = QualifiedName} = ConstructorInfo, Acc) ->
                    Acc#{QualifiedName => ConstructorInfo}
                end, Known, ConstructorInfos).

%% A signature from the prelude tables: every annotation variable is
%% generalized; effect variables of the process primitives are process-only.
signature_scheme(Syntax, ProcessOnly, Env) ->
    TypeState1 = ern_types:enter(Env#env.type_state),
    {Type, AnnotationVariables, TypeState2} =
        annotation_type(Syntax, #{}, Env#env{type_state = TypeState1}),
    Substituted = ern_types:substitute(Type, TypeState2),
    Effects = ern_types:effect_variables(Substituted),
    Values = ern_types:value_variables(Substituted, TypeState2),
    ProcessOnlyIds = [Id || Id <- Effects, ProcessOnly orelse lists:member(Id, Values)],
    TypeState3 = lists:foldl(fun(Id, Acc) ->
                                 ern_types:add_restriction({tvar, Id}, process_only, Acc)
                             end, TypeState2, ProcessOnlyIds),
    TypeState4 = ern_types:leave(TypeState3),
    Kept = [Id || {tvar, Id} <- maps:values(AnnotationVariables)],
    {Scheme, TypeState5} = ern_types:generalize(Substituted, Kept, TypeState4),
    {Scheme, Env#env{type_state = TypeState5}}.

%%
%% Annotations: syntactic types to semantic types. AnnotationVariables maps
%% annotation variable names to type variables shared across one signature.
%%

annotation_type(undefined, AnnotationVariables, Env) ->
    {pure, AnnotationVariables, Env#env.type_state};
annotation_type(#t_var{name = Name}, AnnotationVariables, Env) ->
    case AnnotationVariables of
        #{Name := Variable} -> {Variable, AnnotationVariables, Env#env.type_state};
        _ ->
            {Variable, TypeState} = ern_types:fresh_named(Name, Env#env.type_state),
            {Variable, AnnotationVariables#{Name => Variable}, TypeState}
    end;
annotation_type(#t_named{span = Span, namespace = Namespace, name = Name, args = Args},
                AnnotationVariables, Env) ->
    {QualifiedName, Arity} = lookup_type_name(Span, Namespace, Name, Env),
    length(Args) =:= Arity orelse
        fail(Span, io_lib:format("~s takes ~B type argument~s, not ~B",
                                 [ern_namespace:text(QualifiedName), Arity, plural(Arity),
                                  length(Args)])),
    {ArgTypes, AnnotationVariables1, TypeState} = annotation_types(Args, AnnotationVariables, Env),
    %% report §3.10, §4.7, §9.2: a parameter declared `k=` puts the
    %% equality restriction on every variable of its argument, wherever the
    %% type is written; an argument that holds a function or an address is
    %% refused at the type's first operation, not here
    Keys = case lookup_type(QualifiedName, Env) of
               #type_info{equality = [_ | _] = Equality} ->
                   [Arg || {Arg, true} <- lists:zip(ArgTypes, Equality)];
               _ -> []
           end,
    Restricted = [{tvar, Id} || Key <- Keys,
                                lacks_equality(Key, Env#env{type_state = TypeState}) =:= false,
                                Id <- ern_types:free_variables(Key, TypeState)],
    TypeState1 = lists:foldl(fun(Type, Acc) -> ern_types:add_restriction(Type, equality, Acc) end,
                             TypeState, Restricted),
    {{tcon, QualifiedName, ArgTypes}, AnnotationVariables1, TypeState1};
annotation_type(#t_tuple{elements = Elements}, AnnotationVariables, Env) ->
    {Types, AnnotationVariables1, TypeState} = annotation_types(Elements, AnnotationVariables, Env),
    {{ttuple, Types}, AnnotationVariables1, TypeState};
annotation_type(#t_fn{params = Params, result_type = Result, effect = Effect},
                AnnotationVariables, Env) ->
    {ParamTypes, AnnotationVariables1, TypeState1} =
        annotation_types(Params, AnnotationVariables, Env),
    {ResultType, AnnotationVariables2, TypeState2} =
        annotation_type(Result, AnnotationVariables1, Env#env{type_state = TypeState1}),
    {EffectType, AnnotationVariables3, TypeState3} =
        annotation_type(Effect, AnnotationVariables2, Env#env{type_state = TypeState2}),
    {{tfn, ParamTypes, EffectType, ResultType}, AnnotationVariables3, TypeState3}.

annotation_types(Syntaxes, AnnotationVariables, Env) ->
    Step = fun(Syntax, {Acc, TypeStateAcc}) ->
               {Type, Acc1, TypeStateAcc1} =
                   annotation_type(Syntax, Acc, Env#env{type_state = TypeStateAcc}),
               {Type, {Acc1, TypeStateAcc1}}
           end,
    {Types, {AnnotationVariables1, TypeState}} =
        lists:mapfoldl(Step, {AnnotationVariables, Env#env.type_state}, Syntaxes),
    {Types, AnnotationVariables1, TypeState}.

lookup_type_name(Span, [], Name, #env{local_types = LocalTypes, types = Types} = Env) ->
    case LocalTypes of
        #{Name := QualifiedName} ->
            {QualifiedName, length((maps:get(QualifiedName, Types))#type_info.params)};
        _ ->
            case session_name(types, Name, Env) of
                {ok, QualifiedName} ->
                    {QualifiedName, length((maps:get(QualifiedName, Types))#type_info.params)};
                error ->
                    case Types of
                        #{[Name] := #type_info{params = Params}} -> {[Name], length(Params)};
                        _ -> fail(Span, "unknown type " ++ atom_to_list(Name))
                    end
            end
    end;
lookup_type_name(Span, ['Prelude'], Name, #env{types = Types, local_types = LocalTypes} = Env) ->
    %% report §4.2: `Prelude.T` is the prelude's T, where the module hides it
    case Types of
        #{[Name] := #type_info{params = Params}} ->
            hidden(Span, [Name], is_map_key(Name, LocalTypes)
                                 orelse session_name(types, Name, Env) =/= error),
            {[Name], length(Params)};
        _ ->
            fail(Span, "the prelude declares no type " ++ atom_to_list(Name))
    end;
lookup_type_name(Span, ['Prelude' | _] = Namespace, Name, _Env) ->
    prelude_one(Span, Namespace, Name);
lookup_type_name(Span, Namespace, Name, #env{namespace = OwnNamespace, types = Types}) ->
    Namespace =:= OwnNamespace andalso written_plain(Span, Namespace, [Name]),
    QualifiedName = Namespace ++ [Name],
    case Types of
        #{QualifiedName := #type_info{params = Params}} -> {QualifiedName, length(Params)};
        _ -> unknown(Span, "type", QualifiedName)
    end.

-spec lookup_type([atom()], env()) -> #type_info{} | undefined.
lookup_type(QualifiedName, #env{types = Types}) -> maps:get(QualifiedName, Types, undefined).

%% Report §4.2, §11.2: whether Namespace is a module and the type that owns the
%% member Name: a type of that module, or, at the prompt, a type the session
%% declares whose member a later input declared.
-spec is_member_namespace([atom()], atom(), env()) -> boolean().
is_member_namespace(Namespace, Name, Env) ->
    case lookup_type(Namespace, Env) of
        #type_info{qualified_name = QualifiedName} when length(QualifiedName) > 1 -> true;
        _ -> session_name(values, {lists:last(Namespace), Name}, Env) =:= {ok, Namespace ++ [Name]}
    end.

%%
%% Type declarations
%%

declare_types(Declarations, Env1) ->
    TypeDeclarations = [TypeDeclaration || Declaration <- Declarations,
                                           TypeDeclaration <- type_declaration_of(Declaration)],
    %% pass one: names and arities, so recursive references resolve
    Env2 = lists:foldl(fun declare_type_name/2, Env1, TypeDeclarations),
    Env3 = lists:foldl(fun declare_foreign_type/2, Env2,
                       [Declaration || #foreign_type_declaration{} = Declaration <- Declarations]),
    %% pass two: constructors
    {Env4, Diagnostics, Constructed} = lists:foldl(fun try_declare_constructors/2, {Env3, [], []},
                                                   TypeDeclarations),
    %% pass three: each recursive group's types named at their parameters,
    %% over the declarations whose constructors declared, so every name resolves
    GroupDiagnostics = check_recursive_groups(lists:reverse(Constructed), Env4),
    {mark_reply_carrying(with_reply_params(Env4)), Diagnostics ++ GroupDiagnostics}.

%% Report §3.9: within a recursive group of the module's types, a type of
%% the group is named in the group's fields at type variables that are
%% parameters of the type declared, and at nothing else, so that every
%% type can be walked: a walker of `Deeper(Nest(List(a)))` would call
%% itself at `Nest(List(a))`, then at `Nest(List(List(a)))`, without end.
%% The groups are the cyclic strong components of the types over the
%% names in their fields.
check_recursive_groups(TypeDeclarations, #env{local_types = LocalTypes} = Env) ->
    Declared = [{maps:get(Name, LocalTypes), TypeDeclaration}
                || #type_declaration{name = Name} = TypeDeclaration <- TypeDeclarations],
    Graph = digraph:new(),
    lists:foreach(fun({QualifiedName, _}) -> digraph:add_vertex(Graph, QualifiedName) end,
                  Declared),
    lists:foreach(fun({QualifiedName, TypeDeclaration}) ->
                      [digraph:add_edge(Graph, QualifiedName, Named)
                       || Named <- named_types_of(TypeDeclaration, Env),
                          lists:keymember(Named, 1, Declared)]
                  end, Declared),
    Groups = digraph_utils:cyclic_strong_components(Graph),
    digraph:delete(Graph),
    lists:append([[Diagnostic || QualifiedName <- Group,
                                 {_, TypeDeclaration} <-
                                     [lists:keyfind(QualifiedName, 1, Declared)],
                                 Diagnostic <- group_named(TypeDeclaration, Group, Env)]
                  || Group <- Groups]).

%% The types a declaration's fields name, by qualified name.
named_types_of(#type_declaration{constructors = Constructors}, Env) ->
    lists:usort(lists:append([named_in(Annotation, Env)
                              || #constructor{fields = Fields} <- Constructors,
                                 Annotation <- field_annotations(Fields)])).

named_in(#t_named{span = Span, namespace = Namespace, name = Name, args = Args}, Env) ->
    {QualifiedName, _} = lookup_type_name(Span, Namespace, Name, Env),
    [QualifiedName | lists:append([named_in(Arg, Env) || Arg <- Args])];
named_in(Node, Env) when is_tuple(Node) ->
    lists:append([named_in(Child, Env) || Child <- tl(tuple_to_list(Node))]);
named_in(Nodes, Env) when is_list(Nodes) ->
    lists:append([named_in(Node, Env) || Node <- Nodes]);
named_in(_, _) ->
    [].

%% The diagnostic of the first name of a group's type at other than the
%% declaring type's parameters in the declaration's fields, if any.
group_named(#type_declaration{name = Name, params = Params, constructors = Constructors},
            Group, Env) ->
    try
        lists:foreach(fun(Annotation) -> at_parameters(Annotation, Name, Params, Group, Env) end,
                      [Annotation || #constructor{fields = Fields} <- Constructors,
                                     Annotation <- field_annotations(Fields)]),
        []
    catch
        throw:{type_error, #diagnostic{} = Diagnostic} -> [Diagnostic]
    end.

at_parameters(#t_named{span = Span, namespace = Namespace, name = Named, args = Args} = Annotation,
              Declaring, Params, Group, Env) ->
    {QualifiedName, _} = lookup_type_name(Span, Namespace, Named, Env),
    case lists:member(QualifiedName, Group) of
        true ->
            Where = case Named =:= Declaring of
                        true -> "its own fields";
                        false -> "the fields of " ++ atom_to_list(Declaring)
                    end,
            Listed = fun(Names) ->
                             lists:flatten(lists:join(", ", [atom_to_list(Name) || Name <- Names]))
                     end,
            case [Arg || Arg <- Args, not is_parameter(Arg, Params)] of
                [] ->
                    %% the parameters, each in its place: named at them in
                    %% another order, a walk would call itself at another type
                    Written = [Name || #t_var{name = Name} <- Args],
                    Written =:= Params
                        orelse fail(ern_ast:span(Annotation),
                                    atom_to_list(Named) ++ " is named at " ++ atom_to_list(Named)
                                    ++ "(" ++ Listed(Written) ++ ") in " ++ Where
                                    ++ ", and a type of a recursive group is named in its fields"
                                    " at the declaring type's parameters, each in its place, ("
                                    ++ Listed(Params) ++ ")", [],
                                    at_parameters_help(Named, Args, Params, undefined, Listed));
                [First | _] ->
                    {Type, _, TypeState} = annotation_type(First, #{}, Env),
                    fail(ern_ast:span(Annotation),
                         atom_to_list(Named) ++ " is named at " ++ ern_types:format(Type, TypeState)
                         ++ " in " ++ Where ++ ", and a type of a recursive group is named in its"
                         " fields at the declaring type's parameters alone", [],
                         at_parameters_help(Named, Args, Params, First, Listed))
            end;
        false ->
            lists:foreach(fun(Arg) -> at_parameters(Arg, Declaring, Params, Group, Env) end, Args)
    end;
at_parameters(#t_tuple{elements = Elements}, Declaring, Params, Group, Env) ->
    lists:foreach(fun(Element) -> at_parameters(Element, Declaring, Params, Group, Env) end,
                  Elements);
at_parameters(#t_fn{params = FnParams, result_type = Result, effect = Effect}, Declaring, Params,
              Group, Env) ->
    lists:foreach(fun(Part) -> at_parameters(Part, Declaring, Params, Group, Env) end,
                  [Part || Part <- [Result, Effect | FnParams], Part =/= undefined]);
at_parameters(_, _, _, _, _) ->
    ok.

%% Report §11.5: the fix, the type named at the declaring type's parameters,
%% held in the type it was named at where that one takes it, `List(Nest(a))`
%% for `Nest(List(a))`; where the arities differ, the parameters alone.
at_parameters_help(Named, Args, Params, _, _) when length(Args) =/= length(Params) ->
    "name " ++ atom_to_list(Named) ++ " at the declaring type's parameters, each in its place";
at_parameters_help(Named, _, Params, First, Listed) ->
    AtParameters = atom_to_list(Named) ++ "(" ++ Listed(Params) ++ ")",
    case First of
        #t_named{namespace = Namespace, name = Holder, args = [_]} ->
            HolderText = ern_namespace:text(Namespace ++ [Holder]),
            "write `" ++ AtParameters ++ "`, or `" ++ HolderText ++ "(" ++ AtParameters
            ++ ")` to hold it in a " ++ HolderText;
        _ ->
            "write `" ++ AtParameters ++ "`"
    end.

is_parameter(#t_var{name = Name}, Params) ->
    lists:member(Name, Params);
is_parameter(_, _) ->
    false.

declare_type_name(#type_declaration{span = Span, name = Name, params = Params,
                                    param_spans = ParamSpans}, Env) ->
    not_prelude(Span, Name),
    distinct_parameters(Name, Params, ParamSpans),
    QualifiedName = Env#env.namespace ++ [Name],
    {Variables, Env1} = parameter_variables(Params, Env),
    Added = add_type(Env1, #type_info{qualified_name = QualifiedName, params = Variables,
                                      param_names = Params}),
    Added#env{local_types = maps:put(Name, QualifiedName, Added#env.local_types)}.

%% A type variable for each of a type's parameters, which its constructors'
%% schemes are over.
parameter_variables(Params, #env{type_state = TypeState} = Env) ->
    {Variables, TypeState1} = lists:mapfoldl(fun(_, Acc) -> ern_types:fresh(Acc) end,
                                             TypeState, Params),
    {Variables, Env#env{type_state = TypeState1}}.

%% Report §4.7: a foreign type, whose parameters written `k=` require
%% equality.
declare_foreign_type(#foreign_type_declaration{span = Span, name = Name, params = Params,
                                               param_spans = ParamSpans, equality = Equality},
                     Env) ->
    not_prelude(Span, Name),
    distinct_parameters(Name, Params, ParamSpans),
    QualifiedName = Env#env.namespace ++ [Name],
    RequiresEquality = case lists:member(true, Equality) of
                           true -> Equality;
                           false -> []
                       end,
    {Variables, Env1} = parameter_variables(Params, Env),
    Added = add_type(Env1, #type_info{qualified_name = QualifiedName, params = Variables,
                                      param_names = Params, foreign = true,
                                      equality = RequiresEquality}),
    Added#env{local_types = maps:put(Name, QualifiedName, Added#env.local_types)}.

%% A type's constructors, an error in them collected, so that the module's
%% other types are declared.
%% The declarations whose constructors declared are kept for pass three.
try_declare_constructors(TypeDeclaration, {Env, Found, Constructed}) ->
    try
        {declare_constructors(TypeDeclaration, Env), Found, [TypeDeclaration | Constructed]}
    catch
        throw:{type_error, Span, Message} ->
            {Env, [diagnostic(Span, Message) | Found], Constructed};
        throw:{type_error, #diagnostic{} = Diagnostic} ->
            {Env, [Diagnostic | Found], Constructed}
    end.

%% Report §3.9: a type argument is a value position where its parameter
%% occurs in a value position of the type's fields; one of a built-in or
%% foreign type always is. The type state is given the types that have a
%% parameter that is not.
effect_param_state(#env{types = Types, type_state = TypeState}) ->
    IsValue = param_occurrences(Types, fun in_value/3),
    HasEffectParam = fun(_, TypeIsValue) -> lists:member(false, TypeIsValue) end,
    ern_types:set_effect_params(maps:filter(HasEffectParam, IsValue), TypeState).

%% Report §6.6: a declared type is reply-carrying at an instantiation whose
%% fields, its arguments substituted, have a reply-carrying type. An
%% argument can make them so only where its parameter reaches a field
%% outside function types, foreign types' arguments and the built-in types'
%% but a List's element, which carries a reply as reply_in/3 reads it.
with_reply_params(#env{types = Types} = Env) ->
    Env#env{reply_params = param_occurrences(Types, fun in_reply/3)}.

%% For each declared type with parameters, whether each parameter occurs in
%% its fields as Occurs says. A parameter may occur only as an argument of
%% another type, or of its own, so the occurrences are a least fixpoint over
%% every declared type in scope. A type whose constructors failed to
%% declare has no fields to read.
param_occurrences(Types, Occurs) ->
    Declared = maps:from_list([{QualifiedName, TypeInfo}
                               || QualifiedName := #type_info{foreign = false,
                                                              params = [_ | _]} = TypeInfo
                                      <- Types]),
    None = maps:map(fun(_, #type_info{params = Params}) -> [false || _ <- Params] end, Declared),
    param_fixpoint(Declared, Occurs, None).

param_fixpoint(Declared, Occurs, Occurring) ->
    Occurring1 = maps:map(fun(QualifiedName, TypeOccurring) ->
                              type_occurring(maps:get(QualifiedName, Declared), TypeOccurring,
                                             Occurs, Occurring)
                          end, Occurring),
    case Occurring1 =:= Occurring of
        true -> Occurring;
        false -> param_fixpoint(Declared, Occurs, Occurring1)
    end.

%% One step of the fixpoint for one type: a parameter occurs where it did,
%% or where Occurs finds it in a field.
type_occurring(#type_info{params = Params, constructors = Constructors}, TypeOccurring, Occurs,
               Occurring) ->
    Fields = lists:append([FieldTypes
                           || #constructor_info{scheme = #scheme{type = Type}} <- Constructors,
                              {tfn, FieldTypes, _, _} <- [Type]]),
    [Occurred orelse lists:any(fun(FieldType) -> Occurs(Id, FieldType, Occurring) end, Fields)
     || {Occurred, {tvar, Id}} <- lists:zip(TypeOccurring, Params)].

%% Does variable Id occur in a value position of the type, given which
%% parameters of the declared types are value positions so far?
in_value(Id, {tvar, Id}, _IsValue) ->
    true;
in_value(Id, {tcon, QualifiedName, Args}, IsValue) ->
    lists:any(fun(Arg) -> in_value(Id, Arg, IsValue) end,
              ern_types:args_in_value(QualifiedName, Args, IsValue));
in_value(Id, {ttuple, Elements}, IsValue) ->
    lists:any(fun(Element) -> in_value(Id, Element, IsValue) end, Elements);
in_value(Id, {tfn, Params, _, Result}, IsValue) ->
    lists:any(fun(Part) -> in_value(Id, Part, IsValue) end, [Result | Params]);
in_value(_, _, _) ->
    false.

%% Does variable Id reach the type outside function types and the
%% arguments of foreign types and of the built-in types but a List's
%% element, given which parameters of the declared types reach their
%% fields so far?
in_reply(Id, {tvar, Id}, _Reaches) ->
    true;
in_reply(Id, {tcon, ['List'], [Element]}, Reaches) ->
    in_reply(Id, Element, Reaches);
in_reply(Id, {tcon, QualifiedName, Args}, Reaches) ->
    Reaching = case Reaches of
                   #{QualifiedName := TypeReaches} ->
                       [Arg || {Arg, true} <- lists:zip(Args, TypeReaches)];
                   _ -> []
               end,
    lists:any(fun(Arg) -> in_reply(Id, Arg, Reaches) end, Reaching);
in_reply(Id, {ttuple, Elements}, Reaches) ->
    lists:any(fun(Element) -> in_reply(Id, Element, Reaches) end, Elements);
in_reply(_, _, _) ->
    false.

type_declaration_of(#type_declaration{} = TypeDeclaration) -> [TypeDeclaration];
type_declaration_of(#abstract_declaration{declaration = TypeDeclaration}) -> [TypeDeclaration];
type_declaration_of(_) -> [].

%% Report §4.2: `Prelude.X` names the prelude's X, so no type is Prelude.
%% A type declared twice is declared_twice/1's to refuse, before any is.
not_prelude(Span, 'Prelude') ->
    fail(Span, "Prelude names the prelude, and a type may not take it");
not_prelude(_, _) ->
    ok.

%% Report §4.3, §4.7: a type's parameters are distinct type variables; the
%% second of two alike is underlined and the first labelled (§11.5).
distinct_parameters(Name, Params, ParamSpans) ->
    lists:foldl(fun({Param, Span}, Seen) ->
                    case lists:keyfind(Param, 1, Seen) of
                        {Param, First} ->
                            fail(Span, "type variable " ++ atom_to_list(Param)
                                       ++ " appears twice among the parameters of "
                                       ++ atom_to_list(Name),
                                 [{First, "first written here"}], undefined);
                        false ->
                            [{Param, Span} | Seen]
                    end
                end, [], lists:zip(Params, ParamSpans)),
    ok.

declare_constructors(#type_declaration{name = Name, params = Params, constructors = Constructors},
                     Env) ->
    QualifiedName = maps:get(Name, Env#env.local_types),
    %% the type variable of each parameter, shared by all constructors
    #type_info{params = ParamVariables} = maps:get(QualifiedName, Env#env.types),
    AnnotationVariables = maps:from_list(lists:zip(Params, ParamVariables)),
    TypeState1 = ern_types:enter(Env#env.type_state),
    Result = {tcon, QualifiedName, ParamVariables},
    Declare = fun(Constructor, Acc) ->
                  declare_constructor(Constructor, QualifiedName, AnnotationVariables, Result, Acc)
              end,
    Env1 = Env#env{type_state = TypeState1},
    {ConstructorInfos, Env2} = lists:mapfoldl(Declare, Env1, Constructors),
    TypeInfo = (maps:get(QualifiedName, Env2#env.types))#type_info{constructors = ConstructorInfos},
    Env3 = Env2#env{type_state = ern_types:leave(Env2#env.type_state)},
    Env3#env{types = maps:put(QualifiedName, TypeInfo, Env3#env.types)}.

%% Report §3.5: a constructor of the type TypeQualifiedName, whose value is
%% Result, its fields' annotation variables the type's parameters.
declare_constructor(#constructor{name = Name, fields = Fields}, TypeQualifiedName,
                    AnnotationVariables, {tcon, _, ParamVariables} = Result, Env) ->
    QualifiedName = Env#env.namespace ++ [Name],
    {FieldSpec, FieldTypes, Env1} = constructor_fields(Fields, AnnotationVariables, Env),
    Type = case FieldSpec of
               none -> Result;
               _ -> {tfn, FieldTypes, pure, Result}
           end,
    Quantified = [{Id, []} || {tvar, Id} <- ParamVariables],
    %% report §11.5: the type's parameters print under the names its
    %% declaration gives them
    Names = #{Id => Param || Param := {tvar, Id} <- AnnotationVariables},
    ConstructorInfo = #constructor_info{name = Name, qualified_name = QualifiedName,
                                        type_qualified_name = TypeQualifiedName,
                                        fields = FieldSpec, tag_arity = length(FieldTypes),
                                        scheme = #scheme{quantified = Quantified, type = Type,
                                                         names = Names}},
    {ConstructorInfo,
     Env1#env{local_constructors = maps:put(Name, QualifiedName, Env1#env.local_constructors),
              constructors = maps:put(QualifiedName, ConstructorInfo, Env1#env.constructors)}}.

%% Field types; annotation variables must be parameters (report §3.9).
constructor_fields(none, _AnnotationVariables, Env) ->
    {none, [], Env};
constructor_fields({positional, Syntax}, AnnotationVariables, Env) ->
    {Type, Env1} = declared_field_type(Syntax, AnnotationVariables, Env),
    {positional, [Type], Env1};
constructor_fields({named, Fields}, AnnotationVariables, Env) ->
    %% report §3.5: the fields in the order the declaration writes them
    Names = [Name || #field{name = Name} <- Fields],
    %% report §11.5: at the second, named, the first labelled
    case repeated([{Name, Span} || #field{name = Name, span = Span} <- Fields]) of
        none ->
            ok;
        {Name, First, Second} ->
            fail(Second, "field " ++ atom_to_list(Name) ++ " is declared twice",
                 [{ern_diagnostic:span(First), "first declared here"}], undefined)
    end,
    {Types, Env1} = lists:mapfoldl(fun(#field{annotation = Syntax}, Acc) ->
                                       declared_field_type(Syntax, AnnotationVariables, Acc)
                                   end, Env, Fields),
    {{named, Names}, Types, Env1}.

declared_field_type(Syntax, AnnotationVariables, Env) ->
    {Type, AnnotationVariables1, TypeState} = annotation_type(Syntax, AnnotationVariables, Env),
    case maps:keys(AnnotationVariables1) -- maps:keys(AnnotationVariables) of
        [] -> {Type, Env#env{type_state = TypeState}};
        [Extra | _] -> fail(ern_ast:span(Syntax), "type variable " ++ atom_to_list(Extra)
                                                  ++ " is not a parameter of the type")
    end.


%% Fixpoint over the module's types (report §6.6).
mark_reply_carrying(#env{types = Types} = Env) ->
    Marked = reply_fixpoint(Types, Env),
    Env#env{types = Marked}.

reply_fixpoint(Types, Env) ->
    Mark = fun(_, #type_info{constructors = Constructors, reply_carrying = false} = TypeInfo) ->
                   Carry = lists:any(fun(#constructor_info{scheme = #scheme{type = Type}}) ->
                                         field_types_reply(Type, Types, Env)
                                     end, Constructors),
                   TypeInfo#type_info{reply_carrying = Carry};
              (_, TypeInfo) ->
                   TypeInfo
           end,
    Types1 = maps:map(Mark, Types),
    case Types1 =:= Types of
        true -> Types;
        false -> reply_fixpoint(Types1, Env)
    end.

field_types_reply({tfn, Fields, pure, _}, Types, Env) ->
    lists:any(fun(Field) -> reply_in(Field, Types, Env) end, Fields);
field_types_reply(_, _, _) ->
    false.

reply_in(Type, Types, Env) ->
    case ern_types:resolve(Type, Env#env.type_state) of
        {tvar, _} = Variable -> lists:member(Variable, Env#env.reply_variables);
        {tcon, ['Reply'], _} -> true;
        %% report §6.6: `List` is reply-carrying through its elements; a type
        %% whose operations are the runtime's is not through its arguments
        {tcon, ['List'], [Element]} -> reply_in(Element, Types, Env);
        {tcon, QualifiedName, Args} ->
            case Types of
                #{QualifiedName := #type_info{foreign = true}} -> false;
                #{QualifiedName := #type_info{reply_carrying = true}} -> true;
                _ ->
                    Reaching = case Env#env.reply_params of
                                   #{QualifiedName := TypeReaches} ->
                                       [Arg || {Arg, true} <- lists:zip(Args, TypeReaches)];
                                   _ -> []
                               end,
                    lists:any(fun(Arg) -> reply_in(Arg, Types, Env) end, Reaching)
            end;
        {ttuple, Elements} ->
            lists:any(fun(Element) -> reply_in(Element, Types, Env) end, Elements);
        _ -> false
    end.

-spec is_reply_carrying(ern_types:type(), env()) -> boolean().
is_reply_carrying(Type, #env{types = Types} = Env) -> reply_in(Type, Types, Env).

%% Report §3.9, §6.6: the environment in which the type variables Variables
%% are taken for reply-carrying.
-spec assume_reply_carrying([ern_types:type()], env()) -> env().
assume_reply_carrying(Variables, Env) -> Env#env{reply_variables = Variables}.

%% Report §3.9: whether a value whose type carries a reply, as the
%% environment takes its variables, was passed where a function has the
%% not-reply-carrying restriction, in the definition under check.
-spec restricted_reply_carrying(env()) -> boolean().
restricted_reply_carrying(#env{pending = Pending} = Env) ->
    lists:any(fun(#pending_restriction{restriction = not_reply_carrying, id = Id}) ->
                      is_reply_carrying({tvar, Id}, Env);
                 (_) ->
                      false
              end, Pending).

%%
%% Values: fn, let, foreign fn, in dependency order
%%

check_values(Declarations, Env1) ->
    Values = [Declaration || Declaration <- Declarations, is_value_declaration(Declaration)],
    %% names first, so every body can see every other
    Env2 = lists:foldl(fun register_value_name/2, Env1, Values),
    Groups = dependency_groups(Values, Env2),
    UncheckedGroups = maps:from_list([{group_qualified_name(Declaration, Env2), Group}
                                      || Group <- Groups, Declaration <- Group]),
    Env3 = lists:foldl(fun run_group/2,
                       Env2#env{groups = UncheckedGroups, typed = [], diagnostics = []}, Groups),
    Graph = reference_graph(Env3#env.typed, Env3),
    Diagnostics = let_cycles(Env3#env.typed, Graph) ++ Env3#env.diagnostics,
    %% restore declaration order for the typed output
    Typed = [replace_typed(Declaration, Env3#env.typed) || Declaration <- Declarations],
    Order = case Diagnostics of
                [] ->
                    initialization_order([Declaration || Declaration <- Typed,
                                                         is_value_declaration(Declaration)], Graph);
                _ -> []
            end,
    digraph:delete(Graph),
    {Typed, Env3#env{groups = #{}, typed = [], diagnostics = [], let_order = Order}, Diagnostics}.

%% Report §8.5: the order the module's top-level lets are evaluated in, a
%% let after every let its initializer reaches, directly or through the
%% functions it names, and otherwise in declaration order; the cycle check
%% has passed.
-spec let_order(env()) -> [{atom() | undefined, atom()}].
let_order(#env{let_order = Order}) ->
    Order.

group_qualified_name(Declaration, Env) ->
    {MemberOf, Name} = declaration_key(Declaration),
    value_qualified_name(Env, MemberOf, Name).

%% A group is checked once, when the fold reaches it or when a definition
%% under inference demands one of its names first (report §4.8: an
%% operator names its member only once the operand type is known, so the
%% reference graph cannot order it). A failed group gets placeholders so
%% later groups report their own errors.
run_group(Group, #env{groups = UncheckedGroups} = Env) ->
    Keys = [group_qualified_name(Declaration, Env) || Declaration <- Group],
    case maps:is_key(hd(Keys), UncheckedGroups) of
        false ->
            Env;
        true ->
            Env1 = Env#env{groups = maps:without(Keys, UncheckedGroups)},
            try check_group(Group, Env1) of
                {Typed, Env2} -> Env2#env{typed = Env2#env.typed ++ Typed}
            catch
                throw:{type_error, Span, Message} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               diagnostics = [diagnostic(Span, Message) | Failed#env.diagnostics]};
                throw:{type_error, #diagnostic{} = Diagnostic} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               diagnostics = [Diagnostic | Failed#env.diagnostics]};
                throw:{type_errors, Diagnostics} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               diagnostics = Diagnostics ++ Failed#env.diagnostics}
            end
    end.

%% A name demanded before its group ran: the group is checked now, with
%% the demanding definition's own scope set aside and restored after.
demand(QualifiedName, #env{groups = UncheckedGroups} = Env) ->
    case UncheckedGroups of
        #{QualifiedName := Group} ->
            Clean = Env#env{locals = #{}, effect = pure, pending = [], deferred = [],
                            annotation_variables = #{}, rigid = [], effect_origin = undefined,
                            inferring = [], requirement = [], signature = [],
                            definition = undefined},
            restore_scope(run_group(Group, Clean), Env);
        _ ->
            Env
    end.

%% A definition's own scope set aside: Checked, the environment after it,
%% with the scope of Env, the environment before it.
restore_scope(Checked, Env) ->
    Checked#env{locals = Env#env.locals, effect = Env#env.effect, pending = Env#env.pending,
                deferred = Env#env.deferred, annotation_variables = Env#env.annotation_variables,
                rigid = Env#env.rigid, effect_origin = Env#env.effect_origin,
                effectful = Env#env.effectful, inferring = Env#env.inferring,
                requirement = Env#env.requirement, signature = Env#env.signature,
                definition = Env#env.definition}.

is_value_declaration(#fn_declaration{}) -> true;
is_value_declaration(#let_declaration{}) -> true;
is_value_declaration(#foreign_fn_declaration{}) -> true;
is_value_declaration(_) -> false.

replace_typed(Declaration, Typed) ->
    Key = declaration_key(Declaration),
    case [TypedDeclaration || TypedDeclaration <- Typed,
                              declaration_key(TypedDeclaration) =:= Key] of
        [TypedDeclaration | _] -> TypedDeclaration;
        [] -> Declaration
    end.

declaration_key(#fn_declaration{member_of = MemberOf, name = Name}) -> {MemberOf, Name};
declaration_key(#let_declaration{name = Name}) -> {undefined, Name};
declaration_key(#foreign_fn_declaration{member_of = MemberOf, name = Name}) -> {MemberOf, Name};
declaration_key(Declaration) -> {other, ern_ast:span(Declaration)}.

value_qualified_name(#env{namespace = Namespace}, undefined, Name) -> Namespace ++ [Name];
value_qualified_name(#env{namespace = Namespace}, MemberOf, Name) -> Namespace ++ [MemberOf, Name].

register_value_name(Declaration, #env{local_values = LocalValues} = Env) ->
    {MemberOf, Name} = declaration_key(Declaration),
    Span = ern_ast:span(Declaration),
    Key = local_key(MemberOf, Name),
    %% report §11.2: at the prompt, a member of a type the session declares
    Declared = MemberOf =:= undefined orelse maps:is_key(MemberOf, Env#env.local_types)
                   orelse session_name(types, MemberOf, Env) =/= error,
    Declared orelse fail(Span, atom_to_list(MemberOf) ++ " is not a type declared in this module"),
    QualifiedName = value_qualified_name(Env, MemberOf, Name),
    Lets = case Declaration of
               #let_declaration{} -> (Env#env.lets)#{QualifiedName => true};
               _ -> Env#env.lets
           end,
    Env#env{local_values = LocalValues#{Key => QualifiedName}, lets = Lets}.

is_operator(Name) ->
    case atom_to_list(Name) of
        [First | _] when First >= $a, First =< $z; First =:= $_ -> false;
        _ -> true
    end.

local_key(undefined, Name) -> Name;
local_key(MemberOf, Name) -> {MemberOf, Name}.

local_name(undefined, Name) -> atom_to_list(Name);
local_name(MemberOf, Name) -> atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name).

%% Strongly connected components of the reference graph, in dependency order.
dependency_groups(Values, Env) ->
    Graph = digraph:new(),
    Keys = [declaration_key(Declaration) || Declaration <- Values],
    lists:foreach(fun(Key) -> digraph:add_vertex(Graph, Key) end, Keys),
    lists:foreach(fun(Declaration) ->
                      Key = declaration_key(Declaration),
                      lists:foreach(fun(Reference) ->
                                        case lists:member(Reference, Keys) of
                                            true -> digraph:add_edge(Graph, Key, Reference);
                                            false -> ok
                                        end
                                    end, references(Declaration, Env))
                  end, Values),
    Components = digraph_utils:strong_components(Graph),
    Condensed = digraph_utils:condensation(Graph),
    Order = digraph_utils:topsort(Condensed),
    digraph:delete(Graph), digraph:delete(Condensed),
    ByKey = maps:from_list([{declaration_key(Declaration), Declaration} || Declaration <- Values]),
    Ordered = lists:reverse([Component || Component <- Order, lists:member(Component, Components)]),
    [[maps:get(Key, ByKey) || Key <- Component] || Component <- Ordered].

%% Local value keys a declaration's body refers to: by name, and through
%% an operator whose operand type is known, the member it resolves to
%% (report §4.8, §3.10, §5.1). Before inference no operand type is known,
%% so the graph that orders the groups holds names only and a member is
%% checked on demand (run_group); after it, the typed AST names every
%% member, which the §8.5 cycle rule reads.
references(#fn_declaration{params = Params} = Declaration, Env) ->
    lists:usort(references_in(body_of(Declaration), Env, [], binds_params(Params, #{})));
references(Declaration, Env) ->
    lists:usort(references_in(body_of(Declaration), Env, [], #{})).

body_of(#fn_declaration{body = Body}) -> Body;
body_of(#let_declaration{body = Body}) -> Body;
body_of(_) -> undefined.

%% Report §8.5: what a definition refers to, with the names bound inside
%% it left out. A lambda's parameter, a pattern's variable, or a block's
%% binding shadows a top-level name (§4.2), and counting it as a
%% reference made a definition depend on a `let` it never reads, which
%% the cycle check then reported as a cycle.
references_in(#e_lambda{params = Params, body = Body}, Env, Acc, Bound) ->
    references_in(Body, Env, Acc, binds_params(Params, Bound));
references_in(#clause{pattern = Pattern, guard = Guard, body = Body}, Env, Acc, Bound) ->
    Bound1 = binds(Pattern, Bound),
    references_in(Body, Env,
                  references_in(Guard, Env, references_in_pattern(Pattern, Env, Acc, Bound),
                                Bound1), Bound1);
references_in(#e_block{statements = Statements}, Env, Acc, Bound) ->
    %% a local `fn` is in scope for the whole block, a binding from the
    %% statement after it
    BlockBound = lists:foldl(fun(#fn_declaration{member_of = undefined, name = Name}, InScope) ->
                                     InScope#{Name => true};
                                (_, InScope) ->
                                     InScope
                             end, Bound, Statements),
    {Acc1, _} = lists:foldl(fun(Statement, FoundAndScope) ->
                                statement_references(Statement, FoundAndScope, Env)
                            end, {Acc, BlockBound}, Statements),
    Acc1;
references_in(#e_var{supplies = [_ | _] = Supplies} = Variable, Env, Acc, Bound) ->
    %% report §4.9, §8.5: the members a requirement supplies at a use are
    %% named there, a fill's and a derived compare's among them
    references_in(Variable#e_var{supplies = []}, Env, references_in(Supplies, Env, Acc, Bound),
                  Bound);
references_in(#e_var{namespace = [], name = Name}, _Env, Acc, Bound) when is_map_key(Name, Bound) ->
    Acc;
references_in(#e_var{namespace = [], name = Name}, _Env, Acc, _Bound) -> [{undefined, Name} | Acc];
references_in(#e_var{namespace = Namespace, name = Name}, #env{namespace = Namespace}, Acc, _Bound)
  when Namespace =/= [] ->
    %% the module's own qualified name (report §4.2), which a local binding
    %% of the same name does not hide
    [{undefined, Name} | Acc];
references_in(#e_var{namespace = [MemberOf], name = Name}, #env{local_types = LocalTypes}, Acc,
              _Bound) ->
    case maps:is_key(MemberOf, LocalTypes) of true -> [{MemberOf, Name} | Acc]; false -> Acc end;
references_in(#e_var{namespace = Namespace} = Variable, #env{namespace = OwnNamespace} = Env, Acc,
              Bound)
  when length(Namespace) > 1 ->
    case is_own_type_namespace(Namespace, OwnNamespace) of
        true -> references_in(Variable#e_var{namespace = [lists:last(Namespace)]}, Env, Acc, Bound);
        false -> Acc
    end;
references_in(#e_binop{operator = Operator, left = Left, right = Right}, Env, Acc, Bound)
  when is_atom(Operator) ->
    Member = case lists:member(Operator, ?ORDER) of
                 true -> compare;
                 false -> case lists:member(Operator, ?ARITH) orelse Operator =:= '<>' of
                              true -> Operator;
                              false -> none
                          end
             end,
    references_in(Right, Env,
                  references_in(Left, Env, operator_ref(Member, Left, Env) ++ Acc, Bound), Bound);
references_in(#e_not{expr = Operand}, Env, Acc, Bound) ->
    references_in(Operand, Env, Acc, Bound);
references_in(#known_member{qualified_name = QualifiedName, member = Member,
                            supplies = Supplies},
              #env{namespace = Namespace, local_types = LocalTypes} = Env, Acc, Bound) ->
    %% report §4.9, §8.5: a supplied member is called where it is supplied
    MemberOf = lists:last(QualifiedName),
    Own = [{MemberOf, Member} || is_own_type_namespace(QualifiedName, Namespace),
                                 is_map_key(MemberOf, LocalTypes)],
    references_in(Supplies, Env, Own ++ Acc, Bound);
references_in(#e_negation{expr = Operand}, Env, Acc, Bound) ->
    references_in(Operand, Env, operator_ref(negate, Operand, Env) ++ Acc, Bound);
references_in(Node, Env, Acc, Bound) when is_tuple(Node) ->
    lists:foldl(fun(Child, Found) ->
                    references_in(Child, Env, Found, Bound)
                end, Acc, tl(tuple_to_list(Node)));
references_in(Nodes, Env, Acc, Bound) when is_list(Nodes) ->
    lists:foldl(fun(Child, Found) -> references_in(Child, Env, Found, Bound) end, Acc, Nodes);
references_in(_, _, Acc, _Bound) -> Acc.

%% A statement's references, and the names in scope for the statements
%% after it.
statement_references(#binding{pattern = Pattern, expr = Expr}, {Found, InScope}, Env) ->
    {references_in(Expr, Env, Found, InScope), binds(Pattern, InScope)};
statement_references(#fn_declaration{params = Params, body = Body}, {Found, InScope}, Env) ->
    {references_in(Body, Env, Found, binds_params(Params, InScope)), InScope};
statement_references(Statement, {Found, InScope}, Env) ->
    {references_in(Statement, Env, Found, InScope), InScope}.

%% A pattern binds its variables; an expression inside it, a bitstring
%% segment's size, refers as any expression does.
binds(Pattern, Bound) ->
    lists:foldl(fun({Name, _}, Acc) ->
                    Acc#{Name => true}
                end, Bound, ern_ast:pattern_bindings(Pattern)).

binds_params(Params, Bound) ->
    lists:foldl(fun(#param{pattern = Pattern}, Acc) -> binds(Pattern, Acc) end, Bound, Params).

references_in_pattern(#p_bitstring{segments = Segments}, Env, Acc, Bound) ->
    %% report §5.11: a size expression sees the earlier segments' variables
    {Found, _} = lists:foldl(fun(#bit_segment{value = Value, specs = Specs}, {Reached, Earlier}) ->
                                 {references_in(Specs, Env, Reached, Earlier),
                                  binds(Value, Earlier)}
                             end, {Acc, Bound}, Segments),
    Found;
references_in_pattern(Pattern, Env, Acc, Bound) ->
    case Pattern of
        _ when is_tuple(Pattern) ->
            lists:foldl(fun(Child, Found) ->
                            references_in_pattern(Child, Env, Found, Bound)
                        end, Acc, tl(tuple_to_list(Pattern)));
        _ when is_list(Pattern) ->
            lists:foldl(fun(Child, Found) ->
                            references_in_pattern(Child, Env, Found, Bound)
                        end, Acc, Pattern);
        _ -> Acc
    end.

%% The member an operator on Operand calls, once typed and of a local type.
operator_ref(none, _, _) -> [];
operator_ref(Member, Operand, #env{namespace = Namespace, local_types = LocalTypes}) ->
    case node_type(Operand) of
        {tcon, QualifiedName, _} ->
            MemberOf = lists:last(QualifiedName),
            IsLocal = is_own_type_namespace(QualifiedName, Namespace)
                andalso maps:is_key(MemberOf, LocalTypes),
            case IsLocal of
                true -> [{MemberOf, Member}];
                false -> []
            end;
        _ ->
            []
    end.

%% Report §4.2: is Namespace the module's own and one name below it,
%% as `M.T` in module M, where T may be a type the module declares?
is_own_type_namespace(Namespace, OwnNamespace) ->
    length(Namespace) =:= length(OwnNamespace) + 1 andalso lists:prefix(OwnNamespace, Namespace).

%% A group failed: give its names the type their signatures state, what
%% the annotations leave open and a signature in error being any type, so
%% that later groups report their own errors rather than cascades (report
%% §11.5).
placeholder_group(Group, Env) ->
    lists:foldl(fun(Declaration, Acc) ->
                    {MemberOf, Name} = declaration_key(Declaration),
                    QualifiedName = value_qualified_name(Acc, MemberOf, Name),
                    {Variable, TypeState} = ern_types:fresh(ern_types:enter(Acc#env.type_state)),
                    Placed = Acc#env{type_state = TypeState,
                                     globals = maps:put(QualifiedName,
                                                        ern_types:monomorphic(Variable),
                                                        Acc#env.globals)},
                    Shaped = try signature_shape(Declaration, Variable, Placed)
                             catch
                                 throw:{type_error, _, _} -> Placed;
                                 throw:{type_error, #diagnostic{}} -> Placed
                             end,
                    {Generalized, TypeState1} =
                        ern_types:generalize(Variable, ern_types:leave(Shaped#env.type_state)),
                    Scheme = with_requirement(Generalized,
                                              maps:get(QualifiedName, Shaped#env.globals),
                                              TypeState1),
                    Acc#env{type_state = TypeState1,
                            globals = maps:put(QualifiedName, Scheme, Acc#env.globals)}
                end, Env, Group).

check_group(Group, Env) ->
    lists:foreach(fun ern_scope:names/1, Group),
    TypeState1 = ern_types:enter(Env#env.type_state),
    %% a monomorphic placeholder per member for recursion
    Fresh = fun(Declaration, Acc) ->
                {Variable, Acc1} = ern_types:fresh(Acc),
                {{declaration_key(Declaration), Variable}, Acc1}
            end,
    {Placeholders, TypeState2} = lists:mapfoldl(Fresh, TypeState1, Group),
    Placeholder = fun(Declaration) ->
                      proplists:get_value(declaration_key(Declaration), Placeholders)
                  end,
    Env1 = lists:foldl(fun declare_placeholder/2, Env#env{type_state = TypeState2}, Placeholders),
    %% annotated shapes first, so every member sees every other's signature
    Env2 = lists:foldl(fun(Declaration, Acc) ->
                           signature_shape(Declaration, Placeholder(Declaration), Acc)
                       end, Env1, Group),
    Check = fun(Declaration, Acc) ->
                {TypedDeclaration, Post, Acc1} =
                    check_value(Declaration, Placeholder(Declaration), Acc),
                {{TypedDeclaration, Post}, Acc1}
            end,
    {TypedAndPost, Env3} = lists:mapfoldl(Check, Env2, Group),
    {Typed, Env4} = lists:mapfoldl(fun({TypedDeclaration, Post}, Acc) ->
                                       post_checks(TypedDeclaration, Post, Acc)
                                   end, Env3, TypedAndPost),
    Env5 = Env4#env{type_state = ern_types:leave(Env4#env.type_state),
                    inferring = Env#env.inferring},
    %% generalize and publish; the typed AST is substituted so consumers read
    %% resolved types off the nodes
    Publish = fun(Declaration, Acc) -> publish(Declaration, Placeholder(Declaration), Acc) end,
    lists:mapfoldl(Publish, Env5, Typed).

%% A member's placeholder among the globals, its definition under inference.
declare_placeholder({{MemberOf, Name}, Variable}, Env) ->
    QualifiedName = value_qualified_name(Env, MemberOf, Name),
    Env#env{globals = maps:put(QualifiedName, ern_types:monomorphic(Variable), Env#env.globals),
            inferring = [{global, QualifiedName} | Env#env.inferring]}.

%% A checked member generalized, its shape as a member checked, and its
%% scheme published and set on its typed declaration.
publish(Declaration, Variable, Env) ->
    {MemberOf, Name} = declaration_key(Declaration),
    QualifiedName = value_qualified_name(Env, MemberOf, Name),
    {Generalized, TypeState} = generalized(Declaration, Variable, Env),
    Placeholder = maps:get(QualifiedName, Env#env.globals),
    Scheme = with_requirement(Generalized, Placeholder, TypeState),
    member_shape(Declaration, Scheme, Env#env{type_state = TypeState}),
    Env1 = Env#env{type_state = TypeState,
                   globals = maps:put(QualifiedName, Scheme, Env#env.globals)},
    {substitute_ast(set_declaration_scheme(Declaration, Scheme), TypeState), Env1}.

%% Report §4.9: a generalized scheme with the requirement its placeholder
%% carried, each member's variable the scheme's own.
with_requirement(Scheme, #scheme{requirement = Requirement}, TypeState) ->
    Scheme#scheme{requirement = [{Quantified, Member}
                                 || {Id, Member} <- Requirement,
                                    {tvar, Quantified}
                                        <- [ern_types:resolve({tvar, Id}, TypeState)]]}.

%% Report §3.9, §4.6: a definition's scheme, generalized over its free
%% variables, except a top-level let whose initializer calls a process-only
%% function, which is not, and whose type may keep no variable.
generalized(#let_declaration{span = Span, name = Name} = Declaration, Variable,
            #env{type_state = TypeState} = Env) ->
    case lists:member(declaration_key(Declaration), Env#env.effectful_lets) of
        false ->
            ern_types:generalize(Variable, TypeState);
        true ->
            case ern_types:free_variables(Variable, TypeState) of
                [] -> {ern_types:monomorphic(ern_types:substitute(Variable, TypeState)), TypeState};
                _ -> fail(Span, "the type of " ++ atom_to_list(Name) ++ " is not determined ("
                                ++ ern_types:format(Variable, TypeState)
                                ++ "), and a top-level `let` whose initializer calls a"
                                " process-only function is not generalized; annotate it")
            end
    end;
generalized(_, Variable, #env{type_state = TypeState}) ->
    ern_types:generalize(Variable, TypeState).

%% Report §4.8: a member named by an operator has the type (T, T) -> R for
%% its type T, T.compare the type (T, T) -> Ordering, and T.negate the type
%% (T) -> R, each pure. T is the member's type with any type arguments, the
%% same in both parameters. In the module of a built-in type, the module's
%% own operators, compare, and negate are the type's (§4.8, §9.6).
member_shape(Declaration, #scheme{type = {tfn, Params, Effect, ResultType}} = Scheme, Env) ->
    case member_type(Declaration, Env) of
        none ->
            ok;
        {TypeQualifiedName, Member} ->
            {Arity, Help} = case Member of
                                negate -> {1, "negate takes one value of its type and is pure"};
                                compare -> {2, "compare takes two values of its type, returns an"
                                               " Ordering, and is pure"};
                                _ -> {2, "a member named by an operator takes two values of its"
                                         " type and is pure"}
                            end,
            {MemberOfType, TypeState} = case Params of
                                            [{tcon, TypeQualifiedName, _} = First | _] ->
                                                {First, Env#env.type_state};
                                            _ -> fresh_instance(TypeQualifiedName, Env)
                                        end,
            Result = case Member of
                         compare -> {tcon, ['Ordering'], []};
                         _ -> ResultType
                     end,
            Expected = {tfn, lists:duplicate(Arity, MemberOfType), pure, Result},
            case ern_types:substitute({tfn, Params, Effect, ResultType}, TypeState) =:= Expected of
                true ->
                    ok;
                false ->
                    Shown = fun(Type) ->
                                ern_types:format_scheme(Scheme#scheme{type = Type}, TypeState)
                            end,
                    fail(ern_ast:span(Declaration),
                         ern_namespace:text([lists:last(TypeQualifiedName), Member])
                         ++ " must have the type " ++ Shown(Expected) ++ ", not "
                         ++ Shown(Scheme#scheme.type), [], Help)
            end
    end;
member_shape(_, _, _) ->
    ok.

%% The type and the member a declaration names by an operator, compare, or
%% negate, or none.
member_type(Declaration, #env{namespace = Namespace} = Env)
  when is_record(Declaration, fn_declaration); is_record(Declaration, foreign_fn_declaration) ->
    {MemberOf, Name} = declaration_key(Declaration),
    IsOperatorMember = lists:member(Name, [compare, negate | ?ARITH ++ ['<>']]),
    IsBuiltin = case Namespace of
                    [TypeName] -> lists:member(TypeName, ern_prelude:member_types());
                    _ -> false
                end,
    case {IsOperatorMember, MemberOf} of
        {false, _} -> none;
        {true, undefined} when IsBuiltin -> {Namespace, Name};
        {true, undefined} -> none;
        {true, _} -> {member_of_qualified_name(MemberOf, Env), Name}
    end;
member_type(_, _) ->
    none.

%% Report §4.8, §11.5: a compare whose declared result is another type is
%% an error at that result, before its body, whose own `<` would call it.
%% A regression: the body's use was reported, not the declaration.
early_compare_shape(Declaration, ResultAnnotation, {tfn, Params, _, ResultType},
                    #env{type_state = TypeState} = Env) ->
    case {member_type(Declaration, Env), ern_types:resolve(ResultType, TypeState)} of
        {{TypeQualifiedName, compare}, {tcon, QualifiedName, _}}
          when QualifiedName =/= ['Ordering'] ->
            Self = case Params of
                       [First | _] -> First;
                       [] -> {tcon, TypeQualifiedName, []}
                   end,
            Shown = fun(Type) -> ern_types:format(Type, TypeState) end,
            fail(ern_ast:span(ResultAnnotation),
                 ern_namespace:text([lists:last(TypeQualifiedName), compare])
                 ++ " must have the type "
                 ++ Shown({tfn, [Self, Self], pure, {tcon, ['Ordering'], []}})
                 ++ ", not " ++ Shown({tfn, Params, pure, ResultType}), [],
                 "compare takes two values of its type, returns an Ordering, and is pure");
        _ ->
            ok
    end.

%% Report §11.2: the type a member names, the module's own or, at the
%% prompt, one the session declared.
member_of_qualified_name(MemberOf, #env{local_types = LocalTypes} = Env) ->
    case LocalTypes of
        #{MemberOf := QualifiedName} -> QualifiedName;
        _ -> {ok, QualifiedName} = session_name(types, MemberOf, Env), QualifiedName
    end.

%% The type TypeQualifiedName over fresh variables, for its parameters.
fresh_instance(TypeQualifiedName, #env{types = Types, type_state = TypeState}) ->
    #type_info{params = Params} = maps:get(TypeQualifiedName, Types),
    {Args, TypeState1} = lists:mapfoldl(fun(_, Acc) -> ern_types:fresh(Acc) end, TypeState, Params),
    {{tcon, TypeQualifiedName, Args}, TypeState1}.

substitute_ast({tvar, _} = Type, TypeState) -> ern_types:substitute(Type, TypeState);
substitute_ast({tcon, _, _} = Type, TypeState) -> ern_types:substitute(Type, TypeState);
substitute_ast({ttuple, _} = Type, TypeState) -> ern_types:substitute(Type, TypeState);
substitute_ast({tfn, _, _, _} = Type, TypeState) -> ern_types:substitute(Type, TypeState);
substitute_ast(Node, TypeState) when is_tuple(Node) ->
    list_to_tuple([substitute_ast(Child, TypeState) || Child <- tuple_to_list(Node)]);
substitute_ast(Nodes, TypeState) when is_list(Nodes) ->
    [substitute_ast(Child, TypeState) || Child <- Nodes];
substitute_ast(Leaf, _) -> Leaf.

%% Report §8.5: a cycle among top-level let initializers, directly or through
%% functions they call, is a compile-time error. Read off the typed
%% declarations, since an operator names its member only once typed; one
%% error per cycle, at its first let.
let_cycles(Declarations, Graph) ->
    %% in source order, a node's span being its first field (ern_ast:span/1)
    Lets = lists:keysort(2, [Declaration || #let_declaration{} = Declaration <- Declarations]),
    Fns = [declaration_key(Declaration) || #fn_declaration{} = Declaration <- Declarations],
    {Diagnostics, _} = lists:foldl(fun(Declaration, {Acc, Seen}) ->
                                       let_cycle(Declaration, Graph, Fns, Acc, Seen)
                                   end, {[], []}, Lets),
    lists:reverse(Diagnostics).

%% Report §8.5: the lets of Declarations, which are in declaration order, each
%% after every let its initializer reaches and otherwise as declared.
initialization_order(Declarations, Graph) ->
    Lets = [declaration_key(Declaration) || #let_declaration{} = Declaration <- Declarations],
    Needs = maps:from_list([{Key, [Reached
                                   || Reached <- digraph_utils:reachable_neighbours([Key], Graph),
                                      Reached =/= Key, lists:member(Reached, Lets)]}
                            || Key <- Lets]),
    in_order(Lets, Needs, []).

%% Each let once every let it needs is placed, the first declared of those
%% that can go next first.
in_order([], _, Placed) ->
    lists:reverse(Placed);
in_order(Lets, Needs, Placed) ->
    IsPlaced = fun(Needed) -> lists:member(Needed, Placed) end,
    [Next | _] = [Key || Key <- Lets, lists:all(IsPlaced, maps:get(Key, Needs))],
    in_order(Lets -- [Next], Needs, [Next | Placed]).

%% The module's references, from each declaration to those it names.
reference_graph(Declarations, Env) ->
    Keys = [declaration_key(Declaration) || Declaration <- Declarations],
    Graph = digraph:new(),
    lists:foreach(fun(Key) -> digraph:add_vertex(Graph, Key) end, Keys),
    lists:foreach(fun(Declaration) ->
                      [digraph:add_edge(Graph, declaration_key(Declaration), Reference)
                       || Reference <- references(Declaration, Env),
                          lists:member(Reference, Keys)]
                  end, Declarations),
    Graph.

let_cycle(#let_declaration{span = Span, name = Name, body = Body} = Declaration, Graph, Fns,
          Diagnostics, Seen) ->
    Key = declaration_key(Declaration),
    case lists:member(Key, Seen) of
        true ->
            {Diagnostics, Seen};
        false ->
            case digraph:get_cycle(Graph, Key) of
                false ->
                    {Diagnostics, Seen};
                Cycle ->
                    LetName = atom_to_list(Name),
                    %% the cycle is [Key, ..., Key], or [Key] where the let
                    %% names itself; what stands between, in the cycle's
                    %% order, and the last of it reads the let
                    Between = case Cycle of
                                  [_] -> [];
                                  [_ | After] -> lists:droplast(After)
                              end,
                    Through = case Between of
                                  [] -> "";
                                  _ ->
                                      Names = [local_name(MemberOf, ValueName)
                                               || {MemberOf, ValueName} <- Between],
                                      ", through " ++ lists:join(", ", Names)
                              end,
                    Message = lists:flatten(["the initializer of ", LetName, " depends on itself",
                                             Through]),
                    Help = cycle_help(LetName, Body, Between, Fns),
                    {[(diagnostic(Span, Message))#diagnostic{help = Help} | Diagnostics],
                     Cycle ++ Seen}
            end
    end.

%% Report §11.5: a lambda on a cycle is a recursive function, which is a
%% `fn` whatever else the cycle holds; a value that a function reads, the
%% function that closes the cycle, is built by a `fn` when it is asked for;
%% a cycle closed by a let has no help.
cycle_help(LetName, #e_lambda{}, _, _) ->
    "a recursive function is declared with `fn " ++ LetName ++ "(...) = ...`";
cycle_help(_, _, [], _) ->
    undefined;
cycle_help(LetName, _, Between, Fns) ->
    {MemberOf, Reader} = lists:last(Between),
    case lists:member({MemberOf, Reader}, Fns) of
        true ->
            lists:flatten(["`", local_name(MemberOf, Reader), "` reads ", LetName,
                           " when it is called; a `fn ", LetName, "() = ...` builds the value"
                           " when it is asked for"]);
        false ->
            undefined
    end.

%% Unify a placeholder with what the annotations say, before any body. A
%% local fn's annotations name the enclosing definition's variables where
%% they share a name (report §3.9).
signature_shape(#fn_declaration{params = Params, result_type = ResultAnnotation,
                                effect = Effect} = Declaration,
                Placeholder, Env) ->
    binds_no_type_variable(Declaration),
    ParamType = fun(Param, {Acc, TypeStateAcc}) ->
                    {Type, Acc1, TypeStateAcc1} =
                        param_type(Param, Acc, Env#env{type_state = TypeStateAcc}),
                    {Type, {Acc1, TypeStateAcc1}}
                end,
    {ParamTypes, {AnnotationVariables, TypeState1}} =
        lists:mapfoldl(ParamType, {Env#env.annotation_variables, Env#env.type_state}, Params),
    {ResultType, EffectType, AnnotationVariables1, TypeState2} =
        result_types(ResultAnnotation, Effect, AnnotationVariables,
                     Env#env{type_state = TypeState1}),
    FunctionType = {tfn, ParamTypes, EffectType, ResultType},
    Requirement = requirement_variables(Declaration, AnnotationVariables1, FunctionType,
                                        TypeState2),
    Env1 = bound(Placeholder, FunctionType,
                 Env#env{type_state = mark_process_only(FunctionType, TypeState2)}),
    placeholder_requirement(Declaration, Placeholder,
                            [{Id, Member} || {{tvar, Id}, Member} <- Requirement], Env1);
signature_shape(#let_declaration{annotation = Annotation}, Placeholder, Env)
  when Annotation =/= undefined ->
    {Type, _, TypeState} = annotation_type(Annotation, #{}, Env),
    bound(Placeholder, Type, Env#env{type_state = TypeState});
signature_shape(#foreign_fn_declaration{span = Span, params = Params,
                                        result_type = ResultAnnotation, effect = Effect}
                = Declaration, Placeholder, Env) ->
    Syntax = #t_fn{span = Span, params = [Type || #param{annotation = Type} <- Params],
                   result_type = ResultAnnotation, effect = Effect},
    {Type, _, TypeState} = annotation_type(Syntax, #{}, Env),
    Env1 = bound(Placeholder, Type,
                 Env#env{type_state = not_reply_carrying_params(Type,
                                                                foreign_effect(Type, TypeState))}),
    placeholder_requirement(Declaration, Placeholder, shown_requirement(Declaration, Type, Env),
                            Env1);
signature_shape(_, _, Env) ->
    Env.

%% Report §3.5, §4.9: a declaration with a requirement binds no name that
%% is one of its signature's type variables, in a parameter, a pattern or
%% a local fn's name, so that `a.compare` names a member and nothing else.
%% The first such binding in the source is the error.
binds_no_type_variable(#fn_declaration{requirement = []}) ->
    ok;
binds_no_type_variable(#fn_declaration{params = Params, body = Body} = Declaration) ->
    Variables = ern_ast:signature_variables(Declaration),
    Bindings = ern_ast:walk(fun(Node, Acc) -> bindings_of(Node, Variables) ++ Acc end,
                            [Params, Body], []),
    case lists:sort(Bindings) of
        [] ->
            ok;
        [{Span, Name} | _] ->
            Text = atom_to_list(Name),
            fail(Span, "`" ++ Text ++ "` names a type variable of the signature, and a"
                       " declaration with a requirement binds no name that is one of its type"
                       " variables", [],
                 "rename the binding; " ++ Text ++ ".compare names the member of " ++ Text
                 ++ "'s type")
    end.

%% The names among Variables a node binds itself, each where it stands.
bindings_of(#fn_declaration{span = Span, name = Name}, Variables) ->
    [{ern_diagnostic:span(Span), Name} || lists:member(Name, Variables)];
bindings_of(Node, Variables) ->
    case ern_ast:binder(Node) of
        {Name, Span, _} -> [{ern_diagnostic:span(Span), Name} || lists:member(Name, Variables)];
        none -> []
    end.

%% Report §4.9: each member a requirement names, with the type variable of
%% the signature it names, which stands in a value position.
requirement_variables(#fn_declaration{requirement = Members}, AnnotationVariables, FunctionType,
                      TypeState) ->
    named_once(Members),
    Values = ern_types:value_variables(ern_types:substitute(FunctionType, TypeState), TypeState),
    [case AnnotationVariables of
         #{Variable := Type} ->
             {tvar, Id} = ern_types:resolve(Type, TypeState),
             lists:member(Id, Values)
                 orelse fail(Span, atom_to_list(Variable) ++ " is an effect variable, and a"
                                   " requirement names a type variable in a value position"),
             {{tvar, Id}, Member};
         _ ->
             fail(Span, atom_to_list(Variable) ++ " is no type variable of the signature")
     end
     || #member{span = Span, member_of = Variable, name = Member} <- Members].

%% Report §4.9, §11.5: a requirement names each member once; the second
%% naming is the error, the first labelled.
named_once(Members) ->
    lists:foldl(fun(#member{span = Span, member_of = Variable, name = Name}, Seen) ->
                    case Seen of
                        #{{Variable, Name} := First} ->
                            fail(Span, "the requirement names " ++ atom_to_list(Variable) ++ "."
                                       ++ atom_to_list(Name) ++ " twice",
                                 [{ern_diagnostic:span(First), "first named here"}], undefined);
                        _ ->
                            Seen#{{Variable, Name} => Span}
                    end
                end, #{}, Members),
    ok.

%% A requirement's members on the placeholder that names its declaration
%% while the declaration's group is checked, so that a recursive use is
%% supplied as a later one is: a local fn's among the names bound around
%% it, a top-level one's among the module's.
placeholder_requirement(_Declaration, _Placeholder, [], Env) ->
    Env;
placeholder_requirement(#foreign_fn_declaration{member_of = MemberOf, name = Name}, _Placeholder,
                        Requirement, #env{globals = Globals} = Env) ->
    QualifiedName = value_qualified_name(Env, MemberOf, Name),
    Scheme = maps:get(QualifiedName, Globals),
    Env#env{globals = Globals#{QualifiedName => Scheme#scheme{requirement = Requirement}}};
placeholder_requirement(#fn_declaration{member_of = MemberOf, name = Name}, Placeholder,
                        Requirement, #env{locals = Locals, globals = Globals} = Env) ->
    case Locals of
        #{Name := #scheme{type = Placeholder} = Scheme} ->
            Env#env{locals = Locals#{Name => Scheme#scheme{requirement = Requirement}}};
        _ ->
            QualifiedName = value_qualified_name(Env, MemberOf, Name),
            Scheme = maps:get(QualifiedName, Globals),
            Env#env{globals = Globals#{QualifiedName => Scheme#scheme{requirement = Requirement}}}
    end.

%% Report §9.4: `Io.show` and `Io.debug` need `a.show`, the requirement
%% their type states; a foreign function declares none of its own.
shown_requirement(#foreign_fn_declaration{member_of = undefined, name = Name},
                  {tfn, [{tvar, Id}], _, _}, #env{namespace = ['Io']})
  when Name =:= show; Name =:= debug ->
    [{Id, show}];
shown_requirement(_, _, _) ->
    [].

%% A parameter's type as its annotation shapes it, a fresh variable where
%% it has none.
param_type(#param{annotation = undefined}, AnnotationVariables, Env) ->
    {Type, TypeState} = ern_types:fresh(Env#env.type_state),
    {Type, AnnotationVariables, TypeState};
param_type(#param{annotation = Syntax}, AnnotationVariables, Env) ->
    annotation_type(Syntax, AnnotationVariables, Env).

%% Report §4.7, §3.9: a foreign function has no body to infer from, and its
%% code may copy a value it is given or drop it, so a type variable whose
%% values a parameter holds is not reply-carrying: one the parameter's type
%% reaches through tuples and type arguments, and not under an address, a
%% reply or a function type, whose values the parameter does not hold. A
%% regression: `Foreign.from(r)` dropped a reply, and `Ets.put(t, k, r)`
%% stored one.
not_reply_carrying_params({tfn, Params, _, _}, TypeState) ->
    lists:foldl(fun(Id, Acc) ->
                    ern_types:add_restriction({tvar, Id}, not_reply_carrying, Acc)
                end, TypeState,
                [Id || Param <- Params, Id <- held_variables(Param, TypeState)]).

held_variables(Type, TypeState) ->
    case ern_types:resolve(Type, TypeState) of
        {tvar, Id} -> [Id];
        {tcon, ['Address'], _} -> [];
        {tcon, ['Reply'], _} -> [];
        {tcon, QualifiedName, Args} ->
            lists:append([held_variables(Arg, TypeState)
                          || Arg <- ern_types:value_args(QualifiedName, Args, TypeState)]);
        {ttuple, Elements} ->
            lists:append([held_variables(Element, TypeState) || Element <- Elements]);
        _ -> []
    end.

set_declaration_scheme(#fn_declaration{} = Declaration, Scheme) ->
    Declaration#fn_declaration{scheme = Scheme};
set_declaration_scheme(#let_declaration{} = Declaration, Scheme) ->
    Declaration#let_declaration{scheme = Scheme};
set_declaration_scheme(#foreign_fn_declaration{} = Declaration, Scheme) ->
    Declaration#foreign_fn_declaration{scheme = Scheme};
set_declaration_scheme(Declaration, _) -> Declaration.

check_value(#fn_declaration{span = Span, params = Params, result_type = ResultAnnotation,
                            effect = Effect, requirement = Requirement, body = Body} = Declaration,
            Placeholder, Env) ->
    %% report §3.9: a local fn's signature shares the enclosing one's
    %% variables; at top level there are none
    {TypedParams, ParamTypes, Env1, AnnotationVariables} =
        bind_params(Params, Env, Env#env.annotation_variables),
    {ResultType, EffectType, AnnotationVariables1, TypeState} =
        result_types(ResultAnnotation, Effect, AnnotationVariables, Env1),
    FunctionType = {tfn, ParamTypes, EffectType, ResultType},
    %% report §4.5, §11.5: a recursive call is at the definition's own type,
    %% so the name has it before the body is read, and a call at another
    %% type is refused at its argument, as any call is
    Env2 = unify_at(Span, Placeholder, FunctionType, Env1#env{type_state = TypeState},
                    "recursive use does not match the definition"),
    TypeState1 = Env2#env.type_state,
    Origin = effect_origin(declaration_name(Declaration), ResultAnnotation, Effect, ResultType,
                           EffectType, TypeState1),
    %% report §4.9: the declaration's requirement is in force in its body,
    %% beside the enclosing declarations' for the variables it shares
    Name = declaration_name(Declaration),
    Members = [Member#member{type = maps:get(Variable, AnnotationVariables1)}
               || #member{member_of = Variable} = Member <- Requirement],
    Signature = [{Variable, VariableName, Name}
                 || VariableName := Variable <- AnnotationVariables1,
                    not is_map_key(VariableName, Env#env.annotation_variables)],
    Env3 = Env2#env{type_state = mark_process_only(FunctionType, TypeState1), effect = EffectType,
                    pending = [], deferred = [], annotation_variables = AnnotationVariables1,
                    rigid = maps:to_list(AnnotationVariables1), effect_origin = Origin,
                    requirement = [{Variable, Member} || #member{type = Variable, name = Member}
                                                             <- Members]
                                  ++ Env#env.requirement,
                    signature = Signature ++ Env#env.signature, definition = {fn, Name}},
    early_compare_shape(Declaration, ResultAnnotation, FunctionType, Env3),
    {TypedBody, Env4} = checked_body(Body, ResultAnnotation, ResultType, Name, Env3),
    Env5 = unify_at(Span, Placeholder, FunctionType, Env4,
                    "recursive use does not match the definition"),
    {Declaration#fn_declaration{params = TypedParams, requirement = Members, body = TypedBody},
     post(Span, FunctionType, Env5), restore_scope(Env5, Env)};
check_value(#let_declaration{span = Span, annotation = Annotation, body = Body} = Declaration,
            Placeholder, Env) ->
    {AnnotationType, AnnotationVariables, TypeState} =
        case Annotation of
            undefined -> {undefined, #{}, Env#env.type_state};
            _ -> annotation_type(Annotation, #{}, Env)
        end,
    %% report §4.6: a top-level initializer is a body of mailbox type Never,
    %% which may spawn, send, and call, and may not receive
    Env1 = Env#env{type_state = TypeState, effect = ?NEVER, effectful = false, pending = [],
                   deferred = [], annotation_variables = AnnotationVariables,
                   rigid = maps:to_list(AnnotationVariables),
                   definition = {'let', declaration_name(Declaration)},
                   %% report §3.9: a lambda that is the whole initializer is
                   %% generalized with it, and may name variables of its own
                   generalizing = is_record(Body, e_lambda),
                   effect_origin = #effect_origin{
                                      what = top_let, span = Span,
                                      label = "the initializer of " ++ declaration_name(Declaration)
                                              ++ " runs as a body of mailbox type Never",
                                      help = "receive in a process the initializer spawns"}},
    {TypedBody, BodyType, Env2} =
        case AnnotationType of
            undefined -> infer(Body, Env1);
            _ -> check_expr(Body, AnnotationType, "the value does not have the declared type",
                            annotation_origin(Annotation, AnnotationType, Env1), Env1)
        end,
    %% report §8.5, §11.5: only a use in the let's own group binds its
    %% placeholder, and a group holding the let and a use of it is a cycle
    %% through the let, refused with its own error; a mismatch here follows
    %% from that one, so it is not reported and the let keeps its body's type
    Env3 = case ern_types:unify(BodyType, Placeholder, Env2#env.type_state) of
               {ok, TypeState1} ->
                   case rigid_kept(Env2#env.rigid, TypeState1) of
                       true -> Env2#env{type_state = TypeState1};
                       false -> Env2
                   end;
               {error, _} ->
                   Env2
           end,
    EffectfulLets = case Env3#env.effectful of
                        true -> [declaration_key(Declaration) | Env#env.effectful_lets];
                        false -> Env#env.effectful_lets
                    end,
    {Declaration#let_declaration{body = TypedBody}, post(Span, BodyType, Env3),
     (restore_scope(Env3, Env))#env{effectful_lets = EffectfulLets}};
check_value(#foreign_fn_declaration{span = Span, params = Params, implementation = Implementation,
                                    implementation_span = ImplementationSpan} = Declaration,
            _Placeholder, Env) ->
    %% report §8.4: the implementation is module:function/arity; report
    %% §11.5: the error stands at the string
    ErrorSpan = case ImplementationSpan of
                    undefined -> Span;
                    _ -> ImplementationSpan
                end,
    case foreign_implementation(Implementation) of
        {ok, {_, _, Arity}} when Arity =:= length(Params) -> ok;
        {ok, {_, _, Arity}} ->
            Count = length(Params),
            fail(ErrorSpan, io_lib:format("the implementation names arity ~B, and ~s has ~B"
                                          " parameter~s",
                                          [Arity, declaration_name(Declaration), Count,
                                           plural(Count)]));
        {too_long, Part, Name} ->
            fail(ErrorSpan, ern_namespace:host_name_text("the implementation's " ++ Part
                                                         ++ " name", Name));
        error ->
            Count = length(Params),
            fail(ErrorSpan, "the implementation of " ++ declaration_name(Declaration)
                            ++ " is not written `module:function/arity`", [],
                 lists:flatten(io_lib:format("write the host's module and function and the"
                                             " arity ~B, as `module:function/~B`",
                                             [Count, Count])))
    end,
    %% its type is its signature's, which signature_shape gave it
    {Declaration, none, Env}.

post(Span, Type, Env) ->
    #post_check{span = Span, type = Type, effect = Env#env.effect,
                effect_origin = Env#env.effect_origin, rigid = Env#env.rigid,
                pending = Env#env.pending, deferred = Env#env.deferred,
                requirement = Env#env.requirement, signature = Env#env.signature,
                definition = Env#env.definition}.

%% Report §3.9: a foreign fn's effect is its own, and so process-only,
%% unless it is the effect of one of its parameters' function types, where
%% it is that callback's and the function is effect-polymorphic.
foreign_effect({tfn, Params, {tvar, Id} = Effect, _}, TypeState) ->
    case lists:any(fun(Param) -> parameter_effect(Param, Id) end, Params) of
        true -> TypeState;
        false -> ern_types:add_restriction(Effect, process_only, TypeState)
    end;
foreign_effect(_, TypeState) -> TypeState.

parameter_effect({tfn, _, {tvar, Id}, _}, Id) -> true;
parameter_effect(_, _) -> false.

%% Report §8.4: the implementation name of a foreign fn, module:function/arity,
%% the function named as the host names it, a name or one of its operators.
%% Report §11.1: a module or function name the host does not hold is
%% answered `{too_long, Part, Name}` before any atom is made of it.
-spec foreign_implementation(binary()) ->
          {ok, {atom(), atom(), non_neg_integer()}} | {too_long, string(), string()} | error.
foreign_implementation(Implementation) ->
    case re:run(Implementation,
                "^([a-z][A-Za-z0-9_@]*):([a-z][A-Za-z0-9_]*|[-+*/=<>!:]{1,3})/([0-9]+)$",
                %% `$` at the very end, not before a final line feed
                [dollar_endonly, {capture, all_but_first, list}]) of
        {match, [Module, Function, Arity]} ->
            case [{Part, Name} || {Part, Name} <- [{"module", Module}, {"function", Function}],
                                  length(Name) > ern_namespace:host_name_limit()] of
                [] -> {ok, {list_to_atom(Module), list_to_atom(Function),
                            list_to_integer(Arity)}};
                [{Part, Name} | _] -> {too_long, Part, Name}
            end;
        nomatch -> error
    end.

%% Parameters bind pattern variables monomorphically; annotation variables
%% are shared across the parameters and the result annotation.
bind_params(Params, Env, AnnotationVariables) ->
    {Typed, {Env1, AnnotationVariables1}} =
        lists:mapfoldl(fun bind_param/2, {Env, AnnotationVariables}, Params),
    {TypedParams, Types} = lists:unzip(Typed),
    {TypedParams, Types, Env1, AnnotationVariables1}.

bind_param(#param{span = Span, pattern = Pattern, annotation = Annotation} = Param,
           {Env, AnnotationVariables}) ->
    {TypedPattern, PatternType, Bindings, Env1} = check_pattern(Pattern, Env),
    irrefutable(Pattern, Env1) orelse fail(Span, "a parameter pattern must be irrefutable", [],
                                           "take the value whole, and match on it in the body"),
    {AnnotationVariables1, Env2} =
        param_annotation(Annotation, Pattern, PatternType, AnnotationVariables, Env1),
    {{Param#param{pattern = TypedPattern}, PatternType},
     {bind_locals(Bindings, Env2), AnnotationVariables1}}.

%% A parameter's pattern against its annotation, the annotation's new
%% variables added to those of the signature.
param_annotation(undefined, _Pattern, _PatternType, AnnotationVariables, Env) ->
    {AnnotationVariables, Env};
param_annotation(Annotation, Pattern, PatternType, AnnotationVariables, Env) ->
    {AnnotationType, Extended, TypeState} = annotation_type(Annotation, AnnotationVariables, Env),
    Annotated = Env#env{type_state = TypeState},
    {Extended, unify_at(ern_ast:span(Pattern), AnnotationType, PatternType, Annotated,
                        "the parameter pattern does not fit its annotation",
                        annotation_origin(Annotation, AnnotationType, Annotated))}.

%% The result type and the effect a function's annotation writes, fresh
%% variables where it writes none.
result_types(undefined, _Effect, AnnotationVariables, Env) ->
    {ResultType, TypeState1} = ern_types:fresh(Env#env.type_state),
    {EffectType, TypeState2} = ern_types:fresh(TypeState1),
    {ResultType, EffectType, AnnotationVariables, TypeState2};
result_types(ResultAnnotation, Effect, AnnotationVariables, Env) ->
    {ResultType, AnnotationVariables1, TypeState1} =
        annotation_type(ResultAnnotation, AnnotationVariables, Env),
    {EffectType, AnnotationVariables2, TypeState2} =
        annotation_type(Effect, AnnotationVariables1, Env#env{type_state = TypeState1}),
    {ResultType, EffectType, AnnotationVariables2, TypeState2}.

%% An effect variable that also occurs in a value position of the same
%% signature is process-only (report §3.9).
mark_process_only(FunctionType, TypeState) ->
    Substituted = ern_types:substitute(FunctionType, TypeState),
    Values = ern_types:value_variables(Substituted, TypeState),
    Both = [Id || Id <- ern_types:effect_variables(Substituted), lists:member(Id, Values)],
    lists:foldl(fun(Id, Acc) ->
                    ern_types:add_restriction({tvar, Id}, process_only, Acc)
                end, TypeState, Both).

%% Report §11.5: the labels an error carries. A result annotation is the
%% origin of the body's expected type; a `with` or a bare `->` is the
%% origin of the function's effect.
%% Report §3.9, §11.5: a fn's body against its result type. An annotated
%% one is checked against the annotation. An unannotated one is inferred
%% against a variable of its own, since its result type is no fresh one:
%% an earlier use, or the body's own recursive one, may have given it a
%% type, and the body that disagrees is the mismatch.
checked_body(Body, undefined, ResultType, Name, Env) ->
    {Fresh, TypeState} = ern_types:fresh(Env#env.type_state),
    {TypedBody, BodyType, Env1} =
        check_expr(Body, Fresh, undefined, undefined, Env#env{type_state = TypeState}),
    {TypedBody, unify_at(ern_ast:span(Body), ResultType, BodyType, Env1,
                         "the body does not have the result type " ++ Name ++ "'s uses give it")};
checked_body(Body, ResultAnnotation, ResultType, _Name, Env) ->
    {TypedBody, _, Env1} =
        check_expr(Body, ResultType, "the body does not have the declared result type",
                   result_origin(ResultAnnotation, ResultType, Env), Env),
    {TypedBody, Env1}.

result_rule(undefined, _Rule) -> undefined;
result_rule(_ResultAnnotation, Rule) -> Rule.

result_origin(undefined, _ResultType, _Env) -> undefined;
result_origin(ResultAnnotation, ResultType, Env) ->
    {ern_ast:span(ResultAnnotation),
     "result type " ++ ern_types:format(ResultType, Env#env.type_state) ++ " declared here"}.

annotation_origin(Annotation, AnnotationType, Env) ->
    {ern_ast:span(Annotation),
     "declared " ++ ern_types:format(AnnotationType, Env#env.type_state) ++ " here"}.

effect_origin(_Name, undefined, undefined, _ResultType, _EffectType, _TypeState) -> undefined;
effect_origin(Name, ResultAnnotation, undefined, ResultType, _EffectType, TypeState) ->
    #effect_origin{what = Name, span = ern_ast:span(ResultAnnotation),
                   label = "`: " ++ ern_types:format(ResultType, TypeState)
                           ++ "` with no `with` declares " ++ Name ++ " pure",
                   help = "give " ++ Name ++ " a mailbox type with `with`"};
effect_origin(Name, _ResultAnnotation, Effect, _ResultType, EffectType, TypeState) ->
    #effect_origin{what = Name, span = ern_ast:span(Effect),
                   label = Name ++ " is declared `with " ++ ern_types:format(EffectType, TypeState)
                           ++ "` here"}.

declaration_name(Declaration) ->
    {MemberOf, Name} = declaration_key(Declaration),
    local_name(MemberOf, Name).


bind_locals(Bindings, #env{locals = Locals} = Env) ->
    Bind = fun({Name, Type}, Acc) -> Acc#{Name => ern_types:monomorphic(Type)} end,
    Env#env{locals = lists:foldl(Bind, Locals, Bindings)}.

%%
%% Post checks per definition
%%

post_checks(Declaration, none, Env) ->
    {Declaration, Env};
post_checks(Declaration,
            #post_check{span = Span, type = Type, effect = Effect, effect_origin = Origin,
                        rigid = Rigid, pending = Pending, deferred = Deferred,
                        requirement = Requirement, signature = Signature,
                        definition = Definition},
            Env) ->
    Env1 = solve_deferred(Env#env{effect = Effect, effect_origin = Origin, pending = Pending,
                                  deferred = Deferred, requirement = Requirement,
                                  signature = Signature, definition = Definition}),
    %% report §4.9: what each use of a requirement is supplied with, read
    %% now that the definition's types are known
    {Supplied, Env2} = supplied(Declaration, Env1),
    {TypedParams, TypedBody} = params_and_body(Supplied),
    rigid_annotation_variables(Span, Rigid, Env2),
    ern_scope:order(TypedBody),
    ern_exhaust:check(TypedBody, Env2),
    holds_no_reply(Declaration, Span, Type, Env2),
    Env3 = ern_reply:check(TypedParams, TypedBody, Type, Env2),
    check_pending_restrictions(Env3),
    %% the lesser error last, so that a reply or a restriction the body
    %% breaks is what a refusal names first
    needless_effect(Declaration, Type, Env3),
    {Supplied, Env3#env{effect = Env#env.effect, effect_origin = Env#env.effect_origin,
                        pending = Env#env.pending, deferred = Env#env.deferred,
                        requirement = Env#env.requirement, signature = Env#env.signature,
                        definition = Env#env.definition}}.

%% Report §4.5, §3.9: a `fn` whose result annotation writes an effect
%% variable that names no parameter's effect, and whose body acts through
%% no process, is pure, and is written so: the variable would be pure at
%% every call, and the printed type already leaves it out.
needless_effect(#fn_declaration{member_of = MemberOf, name = Name,
                                effect = #t_var{span = EffectSpan, name = Written}},
                Type, #env{type_state = TypeState}) ->
    case ern_types:substitute(Type, TypeState) of
        {tfn, Params, {tvar, Id}, Result} ->
            Elsewhere = lists:member(Id, ern_types:free_variables({ttuple, Params ++ [Result]},
                                                                  TypeState)),
            ProcessOnly = lists:member(process_only, ern_types:restrictions(Id, TypeState)),
            case Elsewhere orelse ProcessOnly of
                true ->
                    ok;
                false ->
                    Declared = local_name(MemberOf, Name),
                    fail(EffectSpan, Declared ++ " acts through no process, and `with "
                                     ++ atom_to_list(Written) ++ "` names no parameter's effect",
                         [], "write " ++ Declared ++ "'s type without `with`: it is pure")
            end;
        _ ->
            ok
    end;
needless_effect(_, _, _) ->
    ok.

%% Report §6.6: a top-level binding is read by every function and is no
%% obligation, so its type carries no reply.
holds_no_reply(#let_declaration{name = Name}, Span, Type, Env) ->
    not is_reply_carrying(Type, Env)
        orelse fail(Span, atom_to_list(Name) ++ " has the reply-carrying type "
                          ++ ern_types:format(Type, Env#env.type_state)
                          ++ ", and a top-level `let` holds no reply: every function may read it",
                    [], "hold the reply in the process that answers it, as a parameter of its"
                        " loop (§6.6)");
holds_no_reply(_, _, _, _) ->
    ok.

params_and_body(#fn_declaration{params = Params, body = Body}) -> {Params, Body};
params_and_body(#let_declaration{body = Body}) -> {[], Body}.

%% Report Appendix E.1: `Io.show` and `Io.debug` write a value by the type
%% at which the name is used, as a callee or an argument, the library's
%% own uses in io.ern among them; the type is read once the definition is
%% inferred, as an operator's operand type is (§4.8), and supplied as a
%% requirement's `show` is (§4.9).
%% Report §8.4, Appendix E.12: `Foreign.from` gives its value by the type
%% at which the name is used, read the same way.
shown(Span, Referent, Type, Env) ->
    case {declared(Referent, Env), Type} of
        {{'Foreign', from}, {tfn, [Argument], _, _}} ->
            [#pending_member{span = Span, type = Argument, member = exposed, need = exposed}];
        _ ->
            []
    end.

%% Report §9.4, Appendix E.1: `Io.show` and `Io.debug`, whose requirement is
%% named for the function in what a refusal says.
io_shown(Referent, Env) ->
    case declared(Referent, Env) of
        {'Io', Name} when Name =:= show; Name =:= debug -> {ok, Name};
        _ -> none
    end.

%% The module and name of a prelude-provided function a name resolved to.
declared(#remote_declaration{namespace = [Module], member_of = undefined, name = Called}, _) ->
    {Module, Called};
declared(#own_declaration{member_of = undefined, name = Called}, #env{namespace = Namespace})
  when Namespace =:= ['Io']; Namespace =:= ['Foreign'] ->
    {hd(Namespace), Called};
declared(_, _) ->
    none.

%% Report §5.5: `let p <- e` is resolved from the type of e, or from the
%% block's type, once the definition is inferred. Solving one may resolve
%% another, so iterate to a fixpoint.
solve_deferred(#env{deferred = []} = Env) ->
    Env;
solve_deferred(#env{deferred = Deferred} = Env) ->
    {Left, Env1} = lists:foldl(fun(Item, {Acc, EnvAcc}) ->
                                   case solve_one(Item, EnvAcc) of
                                       {solved, EnvAcc1} -> {Acc, EnvAcc1};
                                       unsolved -> {[Item | Acc], EnvAcc}
                                   end
                               end, {[], Env#env{deferred = []}}, Deferred),
    case length(Left) < length(Deferred) of
        true -> solve_deferred(Env1#env{deferred = Left});
        false -> unresolved(earliest(Left), Env1)
    end.

%% The deferred item that stands first in the source, each record's span
%% being its first field; the rounds of solving leave them in no order.
earliest(Items) ->
    Place = fun(Item) ->
                {Line, Column, _} = ern_diagnostic:span(element(2, Item)),
                {Line, Column}
            end,
    hd(lists:sort(fun(First, Second) -> Place(First) =< Place(Second) end, Items)).

%% What is still unknown when nothing more resolves is an error, the first
%% one reported.
-spec unresolved(tuple(), env()) -> no_return().
unresolved(#deferred_bind_arrow{span = Span}, _Env) ->
    fail(Span, "`<-` needs to know whether the value is an Either or an Optional; annotate it");
unresolved(#deferred_operator{span = Span, operator = Operator, operand_type = OperandType},
           Env) ->
    %% report §4.9: on a type variable of the signature, its member is the
    %% requirement's to name; report §4.8: resolution precedes
    %% generalization
    Member = operator_member_name(Operator),
    case signature_variable(OperandType, Env) of
        {Variable, Declaration} ->
            Wanted = Variable ++ "." ++ atom_to_list(Member),
            fail(Span, "`" ++ operator_text(Operator) ++ "` needs " ++ Wanted ++ ", which "
                       ++ Declaration ++ " does not declare", [],
                 requirement_help(Wanted, Declaration));
        none ->
            fail(Span, "the operand type of `" ++ atom_to_list(Operator)
                       ++ "` is not determined; annotate it")
    end;
unresolved(#deferred_guard_order{span = Span, operator = Operator}, _Env) ->
    fail(Span, "the operand type of `" ++ atom_to_list(Operator)
               ++ "` is not determined; annotate it");
unresolved(#deferred_selection{span = Span, field = Field}, _Env) ->
    fail(Span, "the type whose field " ++ atom_to_list(Field)
               ++ " is read is not determined; annotate it").

solve_one(#deferred_selection{span = Span, field = Field, operand_type = OperandType,
                              result = Result} = Deferred,
          Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} -> unsolved;
        _ ->
            {Closed, Env1} = resolve_select(Span, Field, OperandType, Env),
            %% opened as a selection resolved at once is (report §3.9)
            {Opened, TypeState} = open_effect(Closed, Env1#env.type_state),
            {solved, unify_at(Span, Result, Opened, Env1#env{type_state = TypeState},
                              "the field " ++ atom_to_list(Field),
                              settled_origin(Deferred, Env1))}
    end;
solve_one(#deferred_operator{span = Span, operator = Operator, operand_type = OperandType,
                             result = Result, origin = Origin} = Deferred,
          Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} = Variable ->
            case required_operator(Operator, Variable, Env) of
                {ok, Resolved} ->
                    {solved, unify_at(Span, Result, Resolved, Env,
                                      "the result of `" ++ operator_text(Operator) ++ "`",
                                      Origin)};
                error ->
                    unsolved
            end;
        _ ->
            {Closed, Env1} = resolve_operator(Span, Operator, OperandType, Env),
            {Opened, TypeState} = open_effect(Closed, Env1#env.type_state),
            {solved, unify_at(Span, Result, Opened, Env1#env{type_state = TypeState},
                              "the result of `" ++ operator_text(Operator) ++ "`",
                              settled_origin(Deferred, Env1))}
    end;
solve_one(#deferred_guard_order{span = Span, operand_type = OperandType}, Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} ->
            unsolved;
        Type ->
            guard_order(Span, Type, Env),
            {solved, Env}
    end;
solve_one(#deferred_bind_arrow{span = Span, spans = {_, ExprSpan}, expr_type = ExprType,
                               pattern_type = PatternType, rest_type = RestType,
                               fixed = Fixed} = BindArrow,
          Env) ->
    TypeState = Env#env.type_state,
    case {ern_types:resolve(ExprType, TypeState), ern_types:resolve(RestType, TypeState)} of
        {{tcon, ['Either'], [ErrorType, ValueType]}, _} ->
            {solved, bind_arrow(BindArrow, either, ErrorType, ValueType, Env)};
        {{tcon, ['Optional'], [ValueType]}, _} ->
            {solved, bind_arrow(BindArrow, optional, none, ValueType, Env)};
        {{tvar, _}, {tcon, ['Either'], [ErrorType, _]}} ->
            Env1 = unify_at(ExprSpan, {tcon, ['Either'], [ErrorType, PatternType]}, ExprType, Env,
                            "`<-` on an Either",
                            fixed_label(Fixed, RestType, TypeState)),
            {solved, bind_arrow(BindArrow, either, ErrorType, PatternType, Env1)};
        {{tvar, _}, {tcon, ['Optional'], [_]}} ->
            Env1 = unify_at(ExprSpan, {tcon, ['Optional'], [PatternType]}, ExprType, Env,
                            "`<-` on an Optional",
                            fixed_label(Fixed, RestType, TypeState)),
            {solved, bind_arrow(BindArrow, optional, none, PatternType, Env1)};
        {{tvar, _}, _} ->
            unsolved;
        {Other, _} ->
            fail(Span, "`<-` needs an Either or an Optional, not "
                       ++ ern_types:format(Other, TypeState))
    end.

%% Report §11.5: the pattern is reported where it stands, against the value
%% inside, whose type the value's span labels. The value is reported against
%% the block's sum type, labelled where that type was fixed.
bind_arrow(#deferred_bind_arrow{spans = {PatternSpan, ExprSpan}, expr_type = ExprType,
                                pattern_type = PatternType, rest_type = RestType, fixed = Fixed},
           Wrap, ErrorType, ValueType, Env) ->
    Label = "the value inside has type " ++ ern_types:format(ValueType, Env#env.type_state),
    Env1 = unify_at(PatternSpan, ValueType, PatternType, Env,
                    "the pattern does not fit the value inside the sum type",
                    {ExprSpan, Label}),
    {RestValue, TypeState} = ern_types:fresh(Env1#env.type_state),
    Rest = case Wrap of
               either -> {tcon, ['Either'], [ErrorType, RestValue]};
               optional -> {tcon, ['Optional'], [RestValue]}
           end,
    case ern_types:unify(RestType, Rest, TypeState) of
        {ok, TypeState1} ->
            Env1#env{type_state = TypeState1};
        {error, _} ->
            fail(ExprSpan, "the value of `<-` must have the block's sum type: expected "
                           ++ ern_types:format(RestType, TypeState) ++ ", found "
                           ++ ern_types:format(ExprType, TypeState),
                 labels(fixed_label(Fixed, RestType, TypeState)), undefined)
    end.

%% Report §11.5: the block's last expression fixed its type; an `if` or a
%% `match` there did so by its branches, which are labelled each, since two
%% of them together may tie the value inside the sum to the sum itself.
fixed_label({last, Last}, RestType, TypeState) ->
    Text = "the block's value has type " ++ ern_types:format(RestType, TypeState),
    case Last of
        #e_if{then_branch = Then, else_branch = Else} ->
            branch_labels(Text, [Then, Else]);
        #e_match{clauses = Clauses} ->
            branch_labels(Text, [Body || #clause{body = Body} <- Clauses]);
        _ ->
            {ern_ast:span(Last), Text}
    end;
fixed_label(Origin, _, _) ->
    Origin.

branch_labels(Text, [First | Others]) ->
    [{ern_ast:span(First), Text ++ " here"}
     | [{ern_ast:span(Other), "and here"} || Other <- Others]].

%% Restrictions checked at instantiation (report §3.9, §3.10): a
%% not-reply-carrying variable bound to a reply-carrying type, an
%% equality-restricted one bound to a type containing a function or an
%% address. They are checked in the order they stand in the source, so
%% that the one reported is the first place that needed the restriction: a
%% map's first operation, and a comparison before a later use that made
%% its type one without equality.
check_pending_restrictions(#env{pending = Pending} = Env) ->
    Ordered = lists:sort(fun(First, Second) -> place(First) =< place(Second) end, Pending),
    lists:foreach(fun(Restriction) -> check_pending(Restriction, Env) end, Ordered).

%% Report §11.5: a rejected call site is reported at the argument, naming
%% its place among the parameters, with the callee's type, which carries the
%% restriction, as the label; an instance no call applies is reported where
%% it stands, its type in the message.
check_pending(#pending_restriction{restriction = not_reply_carrying, id = Id, span = Span,
                                   who = Who, argument = undefined},
              Env) ->
    Type = ern_types:substitute({tvar, Id}, Env#env.type_state),
    not is_reply_carrying(Type, Env)
        orelse fail(Span, "a reply-carrying value, " ++ ern_types:format(Type, Env#env.type_state)
                          ++ ", passed where " ++ who(Who, "the function")
                          ++ " duplicates or discards its argument" ++ signature_of(Who), [],
                    ern_reply:consume_help());
check_pending(#pending_restriction{restriction = not_reply_carrying, id = Id, span = Span,
                                   who = {Name, _} = Who, argument = {ArgumentSpan, Index}},
              Env) ->
    Type = ern_types:substitute({tvar, Id}, Env#env.type_state),
    not is_reply_carrying(Type, Env)
        orelse fail(ArgumentSpan, "a reply-carrying value, "
                                  ++ ern_types:format(Type, Env#env.type_state)
                                  ++ ", passed in the " ++ ordinal(Index) ++ " argument of "
                                  ++ Name ++ ", which duplicates or discards it",
                    [callee_label(Span, Who)], ern_reply:consume_help());
check_pending(#pending_restriction{restriction = equality, id = Id, span = Span, need = Need,
                                   who = Who, argument = Argument},
              Env) ->
    Type = ern_types:substitute({tvar, Id}, Env#env.type_state),
    case {lacks_equality(Type, Env), Argument} of
        {false, _} ->
            ok;
        {Lack, undefined} ->
            fail(Span, ern_types:format(Type, Env#env.type_state) ++ " does not support equality ("
                       ++ Lack ++ "), " ++ need_text(Need, Who) ++ identity_hint(Type));
        {Lack, {ArgumentSpan, Index}} ->
            fail(ArgumentSpan, ern_types:format(Type, Env#env.type_state)
                               ++ " does not support equality (" ++ Lack ++ "), "
                               ++ argument_need_text(Need, Who, Index) ++ identity_hint(Type),
                 [callee_label(Span, Who)], undefined)
    end.

callee_label(Span, {Name, Type}) -> {Span, Name ++ " : " ++ Type}.

argument_need_text(compared, {Name, _}, Index) ->
    "which " ++ Name ++ " requires of its " ++ ordinal(Index) ++ " argument";
argument_need_text(map, {Name, _}, Index) ->
    "which " ++ Name ++ " requires of a Map's key, in its " ++ ordinal(Index) ++ " argument";
argument_need_text(set, {Name, _}, Index) ->
    "which " ++ Name ++ " requires of a Set's element, in its " ++ ordinal(Index) ++ " argument".

%% A parameter's place, as a word to the tenth and as a number after it.
ordinal(Index) when Index =< 10 ->
    lists:nth(Index, ["first", "second", "third", "fourth", "fifth", "sixth", "seventh",
                      "eighth", "ninth", "tenth"]);
ordinal(Index) when Index rem 100 >= 11, Index rem 100 =< 13 ->
    integer_to_list(Index) ++ "th";
ordinal(Index) ->
    integer_to_list(Index) ++ case Index rem 10 of
                                  1 -> "st";
                                  2 -> "nd";
                                  3 -> "rd";
                                  _ -> "th"
                              end.

%% Report §11.5: each restriction the callee's instance carries, where the
%% callee is a name, that the argument just checked breaks is placed at
%% that argument, the first of the call to break it. A callee that is itself
%% a call, `pair()(r)`, places none, since the arguments are not the named
%% function's; a restriction a later use breaks is placed at no argument.
placed_argument(CalleeSpan, Arg, Index, #env{pending = Pending, type_state = TypeState} = Env) ->
    Placed = fun(#pending_restriction{argument = undefined, who = {_, _}, span = Span, id = Id,
                                      restriction = Restriction} = Pending1) ->
                     Type = ern_types:substitute({tvar, Id}, TypeState),
                     case ern_diagnostic:span(Span) =:= CalleeSpan
                          andalso is_broken(Restriction, Type, Env) of
                         true ->
                             Pending1#pending_restriction{
                               argument = {ern_diagnostic:span(ern_ast:span(Arg)), Index}};
                         false ->
                             Pending1
                     end;
                (Pending1) ->
                     Pending1
             end,
    Env#env{pending = lists:map(Placed, Pending)}.

is_broken(not_reply_carrying, Type, Env) -> is_reply_carrying(Type, Env);
is_broken(equality, Type, Env) -> lacks_equality(Type, Env) =/= false.

%% Where a pending restriction was needed, as a line and a column.
place(#pending_restriction{span = Span}) ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {Line, Column}.

who(undefined, Default) -> Default;
who({Name, _}, _) -> Name.

signature_of(undefined) -> "";
signature_of({Name, Type}) -> ": " ++ Name ++ " : " ++ Type.

need_text(compared, undefined) -> "but it is compared here";
need_text(compared, Who) -> "which " ++ who(Who, "") ++ " requires" ++ signature_of(Who);
need_text(map, _) -> "and a Map's key needs it";
need_text(set, _) -> "and a Set's element needs it".

%% The restrictions an instance of a scheme carries, checked when its
%% definition ends: each not-reply-carrying variable, and each
%% equality-restricted one with what needs the equality: a Map's key or a
%% Set's element it stands in, or else a comparison (report §3.10).
instance_pending(Type, Span, TypeState) ->
    instance_pending(Type, Span, TypeState, undefined).

%% Who: the name the instance was taken of, and its printed type.
instance_pending(Type, Span, TypeState, Who) ->
    [#pending_restriction{restriction = Restriction, id = Id, span = Span,
                          need = need(Restriction, Id, Type, TypeState), who = Who}
     || Id <- ern_types:free_variables(Type, TypeState),
        Restriction <- ern_types:restrictions(Id, TypeState),
        Restriction =:= not_reply_carrying orelse Restriction =:= equality].

need(not_reply_carrying, _Id, _Type, _TypeState) ->
    undefined;
need(equality, Id, Type, TypeState) ->
    case container_of(Id, Type, TypeState) of
        none -> compared;
        Container -> Container
    end.

container_of(Id, Type, TypeState) ->
    case ern_types:resolve(Type, TypeState) of
        {tcon, ['Map'], [Key, Value]} ->
            case lists:member(Id, ern_types:free_variables(Key, TypeState)) of
                true -> map;
                false -> container_of(Id, Value, TypeState)
            end;
        {tcon, ['Set'], [Element]} ->
            case lists:member(Id, ern_types:free_variables(Element, TypeState)) of
                true -> set;
                false -> none
            end;
        {tcon, _, Args} -> first_container(Id, Args, TypeState);
        {ttuple, Elements} -> first_container(Id, Elements, TypeState);
        {tfn, Params, _, Result} -> first_container(Id, Params ++ [Result], TypeState);
        _ -> none
    end.

first_container(_Id, [], _TypeState) -> none;
first_container(Id, [Type | Types], TypeState) ->
    case container_of(Id, Type, TypeState) of
        none -> first_container(Id, Types, TypeState);
        Found -> Found
    end.

%% Report §3.1: a literal's type, in an expression and in a pattern.
literal_type(int) -> ?INT;
literal_type(float) -> ?FLOAT;
literal_type(char) -> ?CHAR;
literal_type(string) -> ?STRING;
literal_type(bool) -> ?BOOL.

%% Report §4.8, §3.10, §5.1: an operator resolves against its operand
%% type as soon as that type is known; an operand still a variable is
%% deferred to the end of the definition, where it must be known. The
%% result: the operand type for Int, Float, and `<>`; Bool for an
%% ordering; a user type's own member, `T.+` or `T.compare`, instantiated
%% and applied to two operands of the type, or `T.negate` to one, since
%% prefix `-` is `negate` in the operand type's namespace (§5.1).
operator_result(Span, Operator, OperandType, Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} = Variable ->
            case required_operator(Operator, Variable, Env) of
                {ok, Result} ->
                    {Result, Env};
                error ->
                    {Result, TypeState} = ern_types:fresh(Env#env.type_state),
                    Deferred = #deferred_operator{span = Span, operator = Operator,
                                                  operand_type = OperandType, result = Result},
                    {Result, Env#env{type_state = TypeState,
                                     deferred = [Deferred | Env#env.deferred]}}
            end;
        _ ->
            resolve_operator(Span, Operator, OperandType, Env)
    end.

%% Report §4.9, §4.8: an operator on a type variable whose member the
%% requirement in force names resolves to it, with its shape: an ordering
%% answers Bool, and an operator and `negate` the type itself.
required_operator(Operator, Variable, Env) ->
    Member = operator_member_name(Operator),
    case is_in_force(Variable, Member, Env) of
        true when Member =:= compare -> {ok, ?BOOL};
        true -> {ok, Variable};
        false -> error
    end.

operator_member_name(Operator) ->
    case lists:member(Operator, ?ORDER) of
        true -> compare;
        false -> Operator
    end.

%% Report §4.8, §4.9: the member an arithmetic or ordering operator, or
%% prefix `-`, resolves to, read at the definition's end, where its operand
%% type is known; the runtime's own operation needs none.
operator_member(Span, Operator, OperandType)
  when Operator =:= negate; Operator =:= '<>' ->
    #pending_member{span = Span, type = OperandType, member = Operator,
                    need = {operator, Operator}};
operator_member(Span, Operator, OperandType) ->
    case lists:member(Operator, ?ARITH ++ ?ORDER) of
        true ->
            #pending_member{span = Span, type = OperandType,
                            member = operator_member_name(Operator), need = {operator, Operator}};
        false ->
            undefined
    end.

%%
%% Derived members (report §3.5)
%%

%% Report §3.5: each type that derives compare gains the member, a `fn`
%% declaration made here and checked as any other, with the requirement
%% the comparison reaches (§4.9).
derived_members(Declarations, Env) ->
    Derived = [{TypeDeclaration, Export}
               || Declaration <- Declarations,
                  {#type_declaration{derives = Derives} = TypeDeclaration, Export}
                      <- [derivable(Declaration)],
                  Derives =/= undefined],
    lists:foreach(fun({TypeDeclaration, _}) -> declared_too(TypeDeclaration, Declarations) end,
                  Derived),
    Requirements = derived_requirements([TypeDeclaration || {TypeDeclaration, _} <- Derived],
                                        Declarations, Env),
    %% each after its type, where the page lists it (report §11.4, §3.5)
    lists:append([case derivable(Declaration) of
                      {#type_declaration{name = Name, derives = Derives} = TypeDeclaration, Export}
                        when Derives =/= undefined ->
                          [Declaration, derived_compare(TypeDeclaration, Export,
                                                        maps:get(Name, Requirements), Env)];
                      _ ->
                          [Declaration]
                  end || Declaration <- Declarations]).

derivable(#type_declaration{export = Export} = TypeDeclaration) -> {TypeDeclaration, Export};
derivable(#abstract_declaration{export = Export, declaration = TypeDeclaration}) ->
    {TypeDeclaration, Export};
derivable(_) -> {none, false}.

%% A type that derives compare declares none of its own.
declared_too(#type_declaration{name = Name, derives = Span}, Declarations) ->
    case [Declared || #fn_declaration{member_of = MemberOf, name = compare, span = Declared}
                          <- Declarations, MemberOf =:= Name] of
        [] -> ok;
        [Declared | _] ->
            fail(Span, atom_to_list(Name) ++ " derives compare and declares it too",
                 [{ern_diagnostic:span(Declared), "declared here"}],
                 "keep the declaration, or `derives compare`")
    end.

%% Report §3.5, §4.9: the requirement each derived compare declares, the
%% members of its parameters its fields' comparisons reach, read through
%% each field type's own compare; a derived type's own is what the others
%% reach so far, to a fixpoint.
derived_requirements(TypeDeclarations, Declarations, Env) ->
    Initial = maps:from_list([{Name, []} || #type_declaration{name = Name} <- TypeDeclarations]),
    derived_fixpoint(TypeDeclarations, Declarations, Env, Initial).

derived_fixpoint(TypeDeclarations, Declarations, Env, Requirements) ->
    Next = maps:from_list([{Name, derived_requirement(TypeDeclaration, TypeDeclarations,
                                                      Requirements, Declarations, Env)}
                           || #type_declaration{name = Name} = TypeDeclaration
                                  <- TypeDeclarations]),
    case Next =:= Requirements of
        true -> Requirements;
        false -> derived_fixpoint(TypeDeclarations, Declarations, Env, Next)
    end.

%% In the order of the type's parameters, and of the members after.
derived_requirement(#type_declaration{name = Name, params = Params, constructors = Constructors},
                    TypeDeclarations, Requirements, Declarations, Env) ->
    Known = {TypeDeclarations, Requirements, Declarations},
    Reached = lists:usort(lists:append([reach(Annotation, compare, Name, Known, Env)
                                        || #constructor{fields = Fields} <- Constructors,
                                           Annotation <- field_annotations(Fields)])),
    [{Param, Member} || Param <- Params, {Reaching, Member} <- Reached, Reaching =:= Param].

field_annotations(none) -> [];
field_annotations({positional, Annotation}) -> [Annotation];
field_annotations({named, Fields}) -> [Annotation || #field{annotation = Annotation} <- Fields].

%% The members of the derived type's parameters a field's Member reaches:
%% a parameter's own, and through a named type's member the members its
%% requirement names at the type's arguments.
reach(#t_var{name = Param}, Member, _MemberOf, _Known, _Env) ->
    [{Param, Member}];
reach(#t_named{span = Span, namespace = Namespace, name = Name, args = Args} = Annotation, Member,
      MemberOf, Known, Env) ->
    {QualifiedName, _} = lookup_type_name(Span, Namespace, Name, Env),
    case member_requirement(QualifiedName, Member, Known, Env) of
        none ->
            cannot_derive(MemberOf, Annotation, Member, Env);
        {ok, Routes} ->
            lists:append([reach(Argument, Needed, MemberOf, Known, Env)
                          || {ArgumentRoute, Needed} <- Routes,
                             Argument <- argument_at(Args, ArgumentRoute)])
    end;
reach(Annotation, Member, MemberOf, _Known, Env) ->
    cannot_derive(MemberOf, Annotation, Member, Env).

%% Report §3.5: a field whose type has no compare is an error at the
%% declaration, at that field.
-spec cannot_derive(atom(), tuple(), atom(), env()) -> no_return().
cannot_derive(MemberOf, Annotation, Member, Env) ->
    {Type, _, TypeState} = annotation_type(Annotation, #{}, Env),
    fail(ern_ast:span(Annotation),
         atom_to_list(MemberOf) ++ ".compare cannot be derived: "
         ++ ern_types:format(Type, TypeState) ++ " has no " ++ atom_to_list(Member)).

%% The requirement of the member Member of the type QualifiedName, each of
%% its members with the route, through the type's arguments, to the type
%% variable it names: a derived compare's as reached so far, a member of
%% this module's as its declaration writes it, another's as its interface
%% has it; none where the type has no such member.
member_requirement(QualifiedName, Member, {TypeDeclarations, Requirements, Declarations},
                   #env{namespace = Namespace} = Env) ->
    case is_own_type_namespace(QualifiedName, Namespace) of
        true -> own_member_requirement(lists:last(QualifiedName), Member, TypeDeclarations,
                                       Requirements, Declarations);
        false ->
            case maps:get(session_member(QualifiedName, Member, Env), Env#env.globals, undefined) of
                #scheme{type = {tfn, [First | _], _, _}, requirement = Requirement} ->
                    {ok, [{Route, Needed} || {Id, Needed} <- Requirement,
                                            Route <- type_routes(First, Id)]};
                #scheme{} -> {ok, []};
                undefined -> none
            end
    end.

own_member_requirement(Name, compare, TypeDeclarations, Requirements, _Declarations)
  when is_map_key(Name, Requirements) ->
    [#type_declaration{params = Params}] =
        [TypeDeclaration || #type_declaration{name = Derived} = TypeDeclaration <- TypeDeclarations,
                            Derived =:= Name],
    {ok, [{[index_of(Param, Params)], Needed} || {Param, Needed} <- maps:get(Name, Requirements)]};
own_member_requirement(Name, Member, _TypeDeclarations, _Requirements, Declarations) ->
    case [Declaration || Declaration <- Declarations,
                         declaration_key(Declaration) =:= {Name, Member}] of
        [#fn_declaration{params = Params, requirement = Members}] ->
            %% the variable's place is read from whichever parameter the
            %% member annotates; a requirement names a variable the
            %% signature writes, so one does
            {ok, lists:usort([{Route, Needed}
                              || #member{member_of = Variable, name = Needed} <- Members,
                                 #param{annotation = Annotation} <- Params,
                                 Route <- annotation_routes(Annotation, Variable)])};
        [_] -> {ok, []};
        [] -> none
    end.

%% The routes through a type's arguments to a variable, a route a list of
%% argument indexes.
type_routes({tcon, _, Args}, Id) ->
    lists:append([case Arg of
                      {tvar, Id} -> [[Index]];
                      _ -> [[Index | Route] || Route <- type_routes(Arg, Id)]
                  end || {Index, Arg} <- lists:enumerate(Args)]);
type_routes(_, _) ->
    [].

annotation_routes(#t_named{args = Args}, Variable) ->
    lists:append([case Arg of
                      #t_var{name = Variable} -> [[Index]];
                      _ -> [[Index | Route] || Route <- annotation_routes(Arg, Variable)]
                  end || {Index, Arg} <- lists:enumerate(Args)]);
annotation_routes(_, _) ->
    [].

%% The annotation at a route through a named type's arguments, if it has one.
argument_at(Args, [Index]) when Index =< length(Args) ->
    [lists:nth(Index, Args)];
argument_at(Args, [Index | Route]) when Index =< length(Args) ->
    case lists:nth(Index, Args) of
        #t_named{args = Inner} -> argument_at(Inner, Route);
        _ -> []
    end;
argument_at(_, _) ->
    [].

%% Report §3.5: the derived member, `fn T.compare(left : T(a), right : T(a))
%% : Ordering`, which orders two values by constructor in declaration order
%% and then field by field from the left, each by its type's compare.
derived_compare(#type_declaration{name = Name, params = Params, constructors = Constructors,
                                  derives = Span}, Export, Requirement, Env) ->
    Self = #t_named{span = Span, name = Name, args = [#t_var{span = Span, name = Param}
                                                      || Param <- Params]},
    Side = fun(Variable) ->
               #param{span = Span, pattern = #p_var{span = Span, name = Variable},
                      annotation = Self}
           end,
    Scrutinee = #e_tuple{span = Span, elements = [#e_var{span = Span, name = left},
                                                  #e_var{span = Span, name = right}]},
    #fn_declaration{span = Span, doc = derived_doc(), export = Export, member_of = Name,
                    name = compare, params = [Side(left), Side(right)],
                    result_type = #t_named{span = Span,
                                           namespace = prelude_namespace(types, 'Ordering', Env),
                                           name = 'Ordering'},
                    requirement = [#member{span = Span, member_of = Param, name = Member}
                                   || {Param, Member} <- Requirement],
                    body = #e_match{span = Span, scrutinee = Scrutinee,
                                    clauses = derived_clauses(Constructors, Span, Env)}}.

derived_doc() ->
    <<"The order of two values: by constructor in the order the type declares them, then by"
      " field from left to right, each by its type's `compare`.">>.

%% Of two values of one constructor, their fields compared; of two
%% constructors, the one declared first is less.
derived_clauses([Last], Span, Env) ->
    [same_constructor(Last, Span, Env)];
derived_clauses([Constructor | Rest], Span, Env) ->
    Any = any_of(Constructor, Span),
    Wildcard = #p_wildcard{span = Span},
    [same_constructor(Constructor, Span, Env),
     #clause{span = Span, pattern = #p_tuple{span = Span, elements = [Any, Wildcard]},
             body = ordering('Less', Span, Env)},
     #clause{span = Span, pattern = #p_tuple{span = Span, elements = [Wildcard, Any]},
             body = ordering('Greater', Span, Env)}
     | derived_clauses(Rest, Span, Env)].

same_constructor(#constructor{name = Name, fields = Fields}, Span, Env) ->
    Annotations = field_annotations(Fields),
    Pattern = #p_tuple{span = Span, elements = [fields_bound(Name, Fields, "left", Span),
                                                fields_bound(Name, Fields, "right", Span)]},
    Compared = [{Annotation, side_name("left", Index), side_name("right", Index)}
                || {Index, Annotation} <- lists:enumerate(Annotations)],
    #clause{span = Span, pattern = Pattern, body = compared(Compared, Span, Env)}.

%% A constructor's pattern binding each field to the side's name and index.
fields_bound(Name, none, _Side, Span) ->
    #p_constructor{span = Span, name = Name};
fields_bound(Name, {positional, _}, Side, Span) ->
    #p_constructor{span = Span, name = Name,
                   args = {positional, #p_var{span = Span, name = side_name(Side, 1)}}};
fields_bound(Name, {named, Fields}, Side, Span) ->
    #p_constructor{span = Span, name = Name,
                   args = {named, [#field_pattern{span = Span, name = Field,
                                                  pattern = #p_var{span = Span,
                                                                   name = side_name(Side, Index)}}
                                   || {Index, #field{name = Field}} <- lists:enumerate(Fields)]}}.

any_of(#constructor{name = Name, fields = none}, Span) ->
    #p_constructor{span = Span, name = Name};
any_of(#constructor{name = Name, fields = {positional, _}}, Span) ->
    #p_constructor{span = Span, name = Name, args = {positional, #p_wildcard{span = Span}}};
any_of(#constructor{name = Name, fields = {named, _}}, Span) ->
    #p_constructor{span = Span, name = Name, args = {named, []}}.

side_name(Side, Index) -> list_to_atom(Side ++ integer_to_list(Index)).

%% The fields compared in turn, the first that is not Equal deciding.
compared([], Span, Env) ->
    ordering('Equal', Span, Env);
compared([Last], _Span, _Env) ->
    field_compared(Last);
compared([Field | Rest], Span, Env) ->
    Order = #p_var{span = Span, name = order},
    #e_match{span = Span, scrutinee = field_compared(Field),
             clauses = [#clause{span = Span,
                                pattern = #p_constructor{span = Span,
                                                         namespace = prelude_namespace(constructors,
                                                                             'Equal', Env),
                                                         name = 'Equal'},
                                body = compared(Rest, Span, Env)},
                        #clause{span = Span, pattern = Order,
                                body = #e_var{span = Span, name = order}}]}.

field_compared({Annotation, Left, Right}) ->
    Span = ern_ast:span(Annotation),
    Of = case Annotation of
             #t_var{name = Param} -> Param;
             _ -> Annotation
         end,
    #e_call{span = Span, callee = #e_member{span = Span, member_of = Of, name = compare},
            args = [#e_var{span = Span, name = Left}, #e_var{span = Span, name = Right}]}.

ordering(Name, Span, Env) ->
    #e_constructor{span = Span, namespace = prelude_namespace(constructors, Name, Env),
                   name = Name}.

%% Report §4.2: the prelude's name as the module may write it, `Prelude.`
%% before it where the module or the session hides it.
prelude_namespace(types, Name, #env{local_types = LocalTypes} = Env) ->
    hidden_namespace(is_map_key(Name, LocalTypes) orelse session_name(types, Name, Env) =/= error);
prelude_namespace(constructors, Name, #env{local_constructors = LocalConstructors} = Env) ->
    hidden_namespace(is_map_key(Name, LocalConstructors)
                orelse session_name(constructors, Name, Env) =/= error).

hidden_namespace(true) -> ['Prelude'];
hidden_namespace(false) -> [].

%%
%% The fill (report §5.6)
%%

%% Report §5.6: the name after `..` is a namespace where it is a qualified
%% name of type names alone, a constructor of the same name notwithstanding,
%% since no constructor is a record an update could take fields from; and
%% an expression otherwise. `Prelude.` reaches a name, not a namespace
%% (§4.2).
fill_namespace(#e_constructor{span = Span, namespace = ['Prelude'], name = Name, args = none,
                              base = undefined}, _) ->
    fail(Span, "`Prelude." ++ atom_to_list(Name) ++ "` names no namespace: `Prelude.` reaches"
               " one of the prelude's names", [],
         "write the namespace after `..` as it is, `.." ++ atom_to_list(Name) ++ "` (§5.6)");
fill_namespace(#e_constructor{namespace = Namespace, name = Name, args = none, base = undefined},
               _) ->
    {namespace, Namespace ++ [Name]};
fill_namespace(_, _) ->
    expression.

%% Report §5.6: `Ops(..Set)`, each field not given beside the namespace the
%% declaration of its name there, at the field's type, as the construction
%% that names each would be.
filled(#e_constructor{namespace = ConstructorNamespace, name = Name, base = Base} = Expr, Namespace,
       Names, FieldTypes, Constructed, FieldSets, Env) ->
    BaseSpan = ern_ast:span(Base),
    Written = ern_namespace:text(ConstructorNamespace ++ [Name]) ++ "(.."
        ++ ern_namespace:text(Namespace) ++ ")",
    %% report §5.6: a path updates a value, which a namespace is not
    lists:foreach(fun(#field_set{span = SetSpan, name = Field, path = [_ | _] = Rest}) ->
                          fail(SetSpan, "`" ++ path_text([Field | Rest]) ++ "` is a path, which"
                                        " updates a value, and `.." ++ ern_namespace:text(Namespace)
                                        ++ "` names a namespace");
                     (_) ->
                          ok
                  end, FieldSets),
    Given = [Field || #field_set{name = Field} <- FieldSets],
    Missing = [Field || Field <- Names, not lists:member(Field, Given)],
    {Filled, Env1} = lists:mapfoldl(fun(Field, Acc) ->
                                        fill_field(BaseSpan, Written, Namespace, Field, Acc)
                                    end, Env, Missing),
    infer_named(Expr#e_constructor{base = undefined}, Names, FieldTypes, Constructed, undefined,
                FieldSets ++ Filled, {Written, Namespace, Missing}, Env1).

%% A field filled from the namespace, which must declare its name.
fill_field(Span, Written, Namespace, Field, Env) ->
    Declared = try lookup_value(Span, Namespace, Field, Env) of
                   {_, _, Env1} -> {ok, Env1}
               catch
                   throw:{type_error, _, _} -> none;
                   throw:{type_error, _} -> none
               end,
    case Declared of
        {ok, Env2} ->
            {#field_set{span = Span, name = Field,
                        expr = #e_var{span = Span, namespace = Namespace, name = Field}}, Env2};
        none ->
            fail(Span, Written ++ " lacks " ++ atom_to_list(Field) ++ ": "
                       ++ ern_namespace:text(Namespace) ++ " has no " ++ atom_to_list(Field))
    end.

%%
%% A path in a record update (report §5.6)
%%

%% Report §5.6: `Pool(..pool, stats.indexed = e)` is `Pool(..pool, stats =
%% Stats(..pool.stats, indexed = e))`, the base and each value bound once,
%% in source order, before the construction reads them (§5.1); each type
%% along a path has one constructor with the named field. The bindings
%% take names no program spells (§2.3).
updated_through_paths(#e_constructor{span = Span, name = Name} = Expr, Names, FieldTypes,
                      Constructed, Base, FieldSets, Env) ->
    lists:foreach(fun(#field_set{span = SetSpan, name = FieldName}) ->
                      lists:member(FieldName, Names)
                          orelse fail(SetSpan, atom_to_list(Name) ++ " has no field "
                                               ++ atom_to_list(FieldName))
                  end, FieldSets),
    no_path_covers_another(FieldSets),
    {TypedBase, BaseType, Env1} = infer(Base, Env),
    Label = {constructor_name_span(Expr),
             "a constructor of " ++ ern_types:format(Constructed, Env1#env.type_state)},
    Env2 = unify_at(ern_ast:span(Base), Constructed, BaseType, Env1,
                    "the base of `..` must have the constructor's type", Label),
    BaseSpan = ern_ast:span(Base),
    Env3 = bind_locals([{'$base', BaseType}], Env2),
    {Bound, Env4} = lists:mapfoldl(fun bound_value/2, Env3, lists:enumerate(FieldSets)),
    Bindings = [binding('$base', BaseSpan, TypedBase, BaseType)
                | [Binding || {_, {Binding, _}} <- Bound, Binding =/= none]],
    Sets = [{FieldName, Path, ValueName, SetSpan}
            || {#field_set{span = SetSpan, name = FieldName, path = Path}, {_, ValueName}}
                   <- Bound],
    Construction = Expr#e_constructor{base = #e_var{span = BaseSpan, name = '$base'},
                                      args = {named, [update_set(Group, Names, FieldTypes, Env4)
                                                      || Group <- by_first_segment(Sets)]}},
    {TypedConstruction, _, Env5} = infer(Construction, Env4),
    {#e_block{span = Span, statements = Bindings ++ [TypedConstruction], type = Constructed},
     Constructed, Env5#env{locals = Env#env.locals}}.

%% A value bound to a name of its own, unless it is such a name already,
%% as the values of an inner update are.
bound_value({_, #field_set{expr = #e_var{namespace = [], name = Bound}} = FieldSet}, Env)
  when is_atom(Bound) ->
    case atom_to_list(Bound) of
        [$$ | _] -> {{FieldSet, {none, Bound}}, Env};
        _ -> fresh_bound_value(FieldSet, Env)
    end;
bound_value({_, FieldSet}, Env) ->
    fresh_bound_value(FieldSet, Env).

fresh_bound_value(#field_set{span = SetSpan, expr = Value} = FieldSet, Env) ->
    ValueName = list_to_atom("$value" ++ integer_to_list(map_size(Env#env.locals))),
    {TypedValue, ValueType, Env1} = infer(Value, Env),
    {{FieldSet, {binding(ValueName, SetSpan, TypedValue, ValueType), ValueName}},
     bind_locals([{ValueName, ValueType}], Env1)}.

binding(Name, Span, TypedExpr, Type) ->
    #binding{span = Span, pattern = #p_var{span = Span, name = Name, type = Type},
             operator = '=', expr = TypedExpr}.

%% The field sets by their first segment, in the order the segments first
%% stand, each with its members in source order.
by_first_segment(Sets) ->
    Ordered = [FieldName || {FieldName, _, _, _} <- Sets],
    [{FieldName, [Set || {Name, _, _, _} = Set <- Sets, Name =:= FieldName]}
     || FieldName <- lists:uniq(Ordered)].

%% A field given plainly reads its bound value; one reached by paths is the
%% inner update, whose base is the field of the outer base and whose field
%% sets are the paths shortened by their first segment.
update_set({FieldName, [{FieldName, [], ValueName, SetSpan}]}, _Names, _FieldTypes, _Env) ->
    #field_set{span = SetSpan, name = FieldName,
               expr = #e_var{span = SetSpan, name = ValueName}};
update_set({FieldName, [{_, _, _, FirstSpan} | _] = Members}, Names, FieldTypes, Env) ->
    {Namespace, Inner} = reached_constructor(FieldName, Members, Names, FieldTypes, Env),
    Base = #e_selection{span = FirstSpan, expr = #e_var{span = FirstSpan, name = '$base'},
                        field = FieldName, field_span = FirstSpan},
    #field_set{span = FirstSpan, name = FieldName,
               expr = #e_constructor{span = FirstSpan, namespace = Namespace, name = Inner,
                                     base = Base,
                                     args = {named, [#field_set{span = SetSpan, name = Next,
                                                                path = Rest,
                                                                expr = #e_var{span = SetSpan,
                                                                              name = ValueName}}
                                                     || {_, [Next | Rest], ValueName, SetSpan}
                                                            <- Members]}}}.

%% Report §5.6, §11.5: the one constructor of the type a path reaches
%% through the field, as the construction writes it.
reached_constructor(FieldName, [{_, Path, _, FirstSpan} | _], Names, FieldTypes,
                    #env{type_state = TypeState} = Env) ->
    Written = path_text([FieldName | Path]),
    FieldType = ern_types:resolve(lists:nth(index_of(FieldName, Names), FieldTypes), TypeState),
    Shown = ern_types:format(FieldType, TypeState),
    case FieldType of
        {tcon, QualifiedName, _} ->
            case lookup_type(QualifiedName, Env) of
                #type_info{constructors = [#constructor_info{qualified_name = Constructor}]} ->
                    {constructor_namespace(Constructor, Env), lists:last(Constructor)};
                #type_info{constructors = []} ->
                    fail(FirstSpan, "`" ++ Written ++ "` reaches " ++ Shown
                                    ++ ", which has no fields");
                #type_info{constructors = Constructors} ->
                    fail(FirstSpan, io_lib:format("`~s` reaches ~s, which has ~B constructors,"
                                                  " and a path goes through a type with one",
                                                  [Written, Shown, length(Constructors)]))
            end;
        {tvar, _} ->
            fail(FirstSpan, "the type of " ++ atom_to_list(FieldName) ++ " under `" ++ Written
                            ++ "` is not determined; annotate it");
        _ ->
            fail(FirstSpan, "`" ++ Written ++ "` reaches " ++ Shown ++ ", which has no fields")
    end.

%% Report §4.2: a constructor as the module writes it, the prelude's past a
%% name the module hides, and its own plain.
constructor_namespace([Name], Env) ->
    prelude_namespace(constructors, Name, Env);
constructor_namespace(QualifiedName, #env{namespace = OwnNamespace}) ->
    case lists:droplast(QualifiedName) of
        OwnNamespace -> [];
        Namespace -> Namespace
    end.

%% Report §5.6, §11.5: no path is a prefix of another, and none is given
%% twice; the second is reported, the first labelled.
no_path_covers_another(FieldSets) ->
    Paths = [{[FieldName | Path], SetSpan}
             || #field_set{span = SetSpan, name = FieldName, path = Path} <- FieldSets],
    lists:foldl(fun({Path, Span}, Earlier) ->
                    [case {Path =:= Other,
                           lists:prefix(Path, Other) orelse lists:prefix(Other, Path)} of
                         {true, _} ->
                             fail(Span, "field " ++ path_text(Path) ++ " is given twice",
                                  [{ern_diagnostic:span(OtherSpan), "first given here"}],
                                  undefined);
                         {false, true} ->
                             fail(Span, "`" ++ path_text(Path) ++ "` and `" ++ path_text(Other)
                                        ++ "` update one field",
                                  [{ern_diagnostic:span(OtherSpan), "given here"}],
                                  "give the field once, or paths into it that do not overlap");
                         _ -> ok
                     end || {Other, OtherSpan} <- Earlier],
                    [{Path, Span} | Earlier]
                end, [], Paths),
    ok.

path_text(Path) -> lists:join(".", [atom_to_list(Segment) || Segment <- Path]).

%%
%% Requirements (report §4.9)
%%

%% The type variable a member written `a.compare` names, which the
%% requirement in force must name.
in_force(Span, Variable, Member, #env{annotation_variables = AnnotationVariables} = Env) ->
    Wanted = atom_to_list(Variable) ++ "." ++ atom_to_list(Member),
    case AnnotationVariables of
        #{Variable := TypeVariable} ->
            is_in_force(TypeVariable, Member, Env)
                orelse fail(Span, declaration_text(Env) ++ " does not declare " ++ Wanted, [],
                            requirement_help(Wanted, declaration_text(Env))),
            TypeVariable;
        _ ->
            fail(Span, atom_to_list(Variable) ++ " is no type variable of the signature", [],
                 "a member is written on a type variable the signature names, as a.compare")
    end.

%% Whether the requirement in force names the member at the type variable.
is_in_force(TypeVariable, Member, #env{requirement = Requirement, type_state = TypeState}) ->
    Resolved = ern_types:resolve(TypeVariable, TypeState),
    lists:any(fun({Named, Name}) ->
                  Name =:= Member andalso ern_types:resolve(Named, TypeState) =:= Resolved
              end, Requirement).

%% Report §4.9: a member's shape at the type it is taken of: `compare`
%% answers an Ordering, `negate` and an operator the type itself.
member_arity(negate) -> 1;
member_arity(_) -> 2.

member_shape_at(compare, Type) -> {tfn, [Type, Type], pure, {tcon, ['Ordering'], []}};
member_shape_at(negate, Type) -> {tfn, [Type], pure, Type};
member_shape_at(_Operator, Type) -> {tfn, [Type, Type], pure, Type}.

%% The name a use of a declaration is reported under, a member with its
%% type's.
needer_name(#own_declaration{member_of = MemberOf}, Name) -> local_name(MemberOf, Name);
needer_name(#remote_declaration{member_of = MemberOf}, Name) -> local_name(MemberOf, Name);
needer_name(_, Name) -> atom_to_list(Name).

declaration_text(#env{definition = {_, Name}}) -> Name;
declaration_text(_) -> "the definition".

%% The variable's name and the declaration whose signature writes it, or
%% none.
signature_variable(Type, #env{signature = Signature, type_state = TypeState}) ->
    Resolved = ern_types:resolve(Type, TypeState),
    case [{atom_to_list(Name), Declaration}
          || {Variable, Name, Declaration} <- Signature,
             ern_types:resolve(Variable, TypeState) =:= Resolved] of
        [Found | _] -> Found;
        [] -> none
    end.

%% The definition with each #pending_member{} its uses left replaced by what
%% supplies it (report §4.9): every one is resolved where it stands, since
%% a local fn's were resolved at its own end.
supplied(#pending_member{span = Span, type = Type, member = Member, need = Need}, Env) ->
    supply(Span, Type, Member, Need, undefined, Env);
supplied(Node, Env) when is_tuple(Node) ->
    {Elements, Env1} = lists:mapfoldl(fun supplied/2, Env, tuple_to_list(Node)),
    {list_to_tuple(Elements), Env1};
supplied(Nodes, Env) when is_list(Nodes) ->
    lists:mapfoldl(fun supplied/2, Env, Nodes);
supplied(Leaf, Env) ->
    {Leaf, Env}.

%% Report §4.9: what supplies the member at the type once the definition is
%% inferred. A type variable is the requirement's in force; `show` at a type
%% known whole its descriptor; an operator on a prelude type the runtime's
%% own operation; and a known type its member, with that member's own
%% requirement supplied at its type, members supplying members. Outer is the
%% member first needed, where this one supplies another's requirement.
supply(Span, Type, exposed, _Need, _Outer, #env{type_state = TypeState} = Env) ->
    %% report §8.4, Appendix E.12: Foreign.from gives its value at a type
    %% known whole, and no requirement names it, a record's fill among
    %% what cannot
    Substituted = ern_types:substitute(ern_types:resolve(Type, TypeState), TypeState),
    case ern_types:value_variables(Substituted, TypeState) of
        [] -> {#shown_type{type = Substituted}, Env};
        _ -> not_exposed(Span, Substituted, Env)
    end;
supply(Span, Type, Member, Need, Outer, #env{type_state = TypeState} = Env) ->
    case ern_types:resolve(Type, TypeState) of
        {tvar, _} = Variable ->
            case is_in_force(Variable, Member, Env) of
                true -> {#required_member{variable = Variable, member = Member}, Env};
                false -> not_in_force(Span, Variable, Member, Need, Env)
            end;
        Resolved when Member =:= show ->
            %% report §9.4, Appendix E.1: a type known whole is written by
            %% its descriptor, and one built from type variables the
            %% requirement in force names `show` for by the descriptor
            %% composed of theirs
            Substituted = ern_types:substitute(Resolved, TypeState),
            Unnamed = [Id || Id <- ern_types:value_variables(Substituted, TypeState),
                             not is_in_force({tvar, Id}, show, Env)],
            case Unnamed of
                [] ->
                    {#shown_type{type = Substituted}, Env};
                [Id | _] ->
                    case signature_variable({tvar, Id}, Env) of
                        none -> not_shown(Span, Substituted, Need, Env);
                        _ -> not_in_force(Span, {tvar, Id}, show, Need, Env)
                    end
            end;
        {tcon, [_], _} when element(1, Need) =:= operator ->
            %% report §4.8, §9.6: a prelude type's operator is the runtime's
            %% own operation, or its module's, which the emitter names
            {undefined, Env};
        {tcon, QualifiedName, _} = Resolved ->
            known_member(Span, QualifiedName, Resolved, Member, Need, Outer, Env);
        Resolved ->
            no_member(Span, Resolved, Member, Need, Outer, Env)
    end.

%% The member of a known type, its shape checked where it supplies a
%% requirement (§4.9: an operator's and negate's result is the type itself),
%% and its own requirement supplied at the type, as any requirement is, the
%% operator that needed the member named in its errors.
known_member(Span, QualifiedName, Type, Member, Need, Outer, Env) ->
    case member_scheme(QualifiedName, Member, Env) of
        {undefined, Env1} ->
            no_member(Span, Type, Member, Need, Outer, Env1);
        {Scheme, Env1} ->
            {Requirement, TypeState} = member_at(Span, Scheme, Type, Member, Need,
                                                 Env1#env.type_state),
            Outer1 = case Outer of
                         undefined -> member_text(Type, Member, TypeState);
                         _ -> Outer
                     end,
            Supplying = case Need of
                            {operator, Operator} -> {operand, Operator};
                            _ -> Need
                        end,
            {Supplies, Env2} =
                lists:mapfoldl(fun({Instanced, Needed}, Acc) ->
                                   supply(Span, Instanced, Needed, Supplying, Outer1, Acc)
                               end, Env1#env{type_state = TypeState}, Requirement),
            {#known_member{qualified_name = QualifiedName, member = Member,
                           supplies = Supplies}, Env2}
    end.

%% The member's instance at the type, and its requirement there: its
%% operands are the type, and where it supplies a requirement its result
%% is too.
member_at(Span, Scheme, Type, Member, Need, TypeState) ->
    {Instance, Requirement, TypeState1} = ern_types:instance(Scheme, TypeState),
    {Operands, Result, TypeState2} = operands(Member, Type, TypeState1),
    Shape = member_shape_at(Member, Type),
    Fitted = case ern_types:unify(Operands, Instance, TypeState2) of
                 {ok, Unified} -> Unified;
                 {error, _} -> misfit(Span, Type, Member, Shape, Instance, Need, TypeState2)
             end,
    case {element(1, Need), Member} of
        {operator, _} -> {Requirement, Fitted};
        {_, compare} -> {Requirement, Fitted};
        _ -> {Requirement, answers(Span, Type, Member, Shape, Result, Need, Fitted)}
    end.

%% A member's function type over operands of the type, its effect and its
%% result open; a member whose own check failed has a variable for its
%% type, which takes this shape.
operands(Member, Type, TypeState) ->
    {Effect, TypeState1} = ern_types:fresh(TypeState),
    {Result, TypeState2} = ern_types:fresh(TypeState1),
    {{tfn, lists:duplicate(member_arity(Member), Type), Effect, Result}, Result, TypeState2}.

%% An operator member and negate supply a requirement only where they answer
%% the type itself.
answers(Span, Type, Member, Shape, Result, Need, TypeState) ->
    case ern_types:unify(Result, Type, TypeState) of
        {ok, TypeState1} ->
            TypeState1;
        {error, _} ->
            Wanted = member_text(Type, Member, TypeState),
            fail(Span, needer_text(Need) ++ " needs " ++ Wanted ++ " : "
                       ++ ern_types:format(Shape, TypeState) ++ ", and " ++ Wanted ++ " answers "
                       ++ ern_types:format(Result, TypeState), [],
                 "a function over an operation of another shape takes it as a parameter")
    end.

-spec misfit(ern_diagnostic:span(), term(), atom(), term(), term(), term(), term()) ->
          no_return().
misfit(Span, Type, Member, Shape, Instance, Need, TypeState) ->
    fail(Span, needer_text(Need) ++ " needs " ++ member_text(Type, Member, TypeState) ++ " : "
               ++ ern_types:format(Shape, TypeState) ++ ", and the member's type is "
               ++ ern_types:format(Instance, TypeState)).

-spec no_member(ern_diagnostic:span(), term(), atom(), term(), term(), env()) -> no_return().
no_member(Span, Type, Member, Need, Outer, #env{type_state = TypeState}) ->
    Wanted = case Outer of
                 undefined -> member_text(Type, Member, TypeState);
                 _ -> Outer
             end,
    fail(Span, needer_text(Need) ++ " needs " ++ Wanted ++ ", and "
               ++ ern_types:format(Type, TypeState) ++ " has no " ++ atom_to_list(Member)).

-spec not_in_force(ern_diagnostic:span(), term(), atom(), term(), env()) -> no_return().
not_in_force(Span, Variable, Member, {fill, _} = Need, #env{type_state = TypeState}) ->
    Name = variable_text(Variable, TypeState),
    fail(Span, needer_text(Need) ++ " needs " ++ Name ++ "." ++ atom_to_list(Member)
               ++ ", and the record's type leaves the variable " ++ Name
               ++ " undetermined; annotate it");
not_in_force(Span, Variable, Member, Need, Env) ->
    case signature_variable(Variable, Env) of
        none when element(1, Need) =:= shown ->
            not_shown(Span, ern_types:substitute(Variable, Env#env.type_state), Need, Env);
        {Name, Declaration} ->
            Wanted = Name ++ "." ++ atom_to_list(Member),
            fail(Span, needer_text(Need) ++ " needs " ++ Wanted ++ ", which " ++ Declaration
                       ++ " does not declare", [], requirement_help(Wanted, Declaration));
        none ->
            Wanted = variable_text(Variable, Env#env.type_state) ++ "." ++ atom_to_list(Member),
            case Env#env.definition of
                {'let', _} ->
                    fail(Span, needer_text(Need) ++ " needs " ++ Wanted
                               ++ ", which a top-level let cannot declare", [],
                         "declare a `fn` with `needs " ++ Wanted ++ "`");
                {fn, [$$ | _]} ->
                    %% report §11.2: an input at the prompt, named as no
                    %% program names a function (§2.3), has no signature
                    fail(Span, needer_text(Need) ++ " needs " ++ Wanted
                               ++ ", at a type variable no requirement can name", [],
                         "apply it at a known type, or declare a `fn` with the requirement");
                _ ->
                    fail(Span, needer_text(Need) ++ " needs " ++ Wanted
                               ++ ", at a type variable no requirement can name", [],
                         "annotate it with a type variable of " ++ declaration_text(Env)
                         ++ "'s signature, and add the requirement there")
            end
    end.

%% Report §11.5: the help line that adds a requirement, written as code.
requirement_help(Wanted, Declaration) ->
    "add `needs " ++ Wanted ++ "` to " ++ Declaration ++ "'s signature".

-spec not_shown(ern_diagnostic:span(), term(), term(), env()) -> no_return().
not_shown(Span, Type, {shown, Name}, #env{type_state = TypeState}) ->
    fail(Span, "the type " ++ ern_types:format(Type, TypeState) ++ " is not known whole here, and"
               " Io." ++ atom_to_list(Name) ++ " writes a value by its type", [],
         "annotate the value where it is bound; at a type variable of the signature, a"
         " requirement `needs a.show` lets it write the value");
not_shown(Span, Type, Need, #env{type_state = TypeState}) ->
    fail(Span, needer_text(Need) ++ " needs " ++ ern_types:format(Type, TypeState)
               ++ ".show, and Io.show writes a type known whole, or a requirement's type"
               " variable").

%% Report §11.5, E.12: a type that holds a signature's variable is no
%% annotation's to fix, and a `foreign fn` gives such a value.
-spec not_exposed(ern_diagnostic:span(), term(), env()) -> no_return().
not_exposed(Span, Type, #env{type_state = TypeState} = Env) ->
    Help = case holds_signature_variable(Type, Env) of
               true -> "a value of a type variable is given by a `foreign fn` whose parameter is"
                       " of that variable";
               false -> "annotate the value where it is bound"
           end,
    fail(Span, "the type " ++ ern_types:format(Type, TypeState) ++ " is not known whole here, and"
               " Foreign.from gives foreign code a value by its type", [], Help).

holds_signature_variable(Type, #env{signature = Signature, type_state = TypeState}) ->
    Free = ern_types:free_variables(Type, TypeState),
    lists:any(fun({Variable, _, _}) ->
                      case ern_types:resolve(Variable, TypeState) of
                          {tvar, Id} -> lists:member(Id, Free);
                          _ -> false
                      end
              end, Signature).

needer_text({call, Name}) -> Name;
needer_text({fill, Name}) -> Name;
needer_text({shown, Name}) -> "Io." ++ atom_to_list(Name);
needer_text({operator, Operator}) -> "`" ++ operator_text(Operator) ++ "`";
needer_text({operand, Operator}) -> "`" ++ operator_text(Operator) ++ "`".

member_text(Type, Member, TypeState) ->
    ern_types:format(Type, TypeState) ++ "." ++ atom_to_list(Member).

%% A type variable as an error names it, without the marks a printed type
%% gives it (report §11.5).
variable_text(Variable, TypeState) ->
    string:trim(ern_types:format(Variable, TypeState), trailing, "=!+").

%% Report §3.5, §4.8: a field selection resolves against its operand's type
%% as an operator does, deferred while that type is still a variable.
select_result(Span, Field, OperandType, Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} ->
            {Result, TypeState} = ern_types:fresh(Env#env.type_state),
            Deferred = #deferred_selection{span = Span, field = Field, operand_type = OperandType,
                                           result = Result},
            {Result, Env#env{type_state = TypeState, deferred = [Deferred | Env#env.deferred]}};
        _ ->
            resolve_select(Span, Field, OperandType, Env)
    end.

%% Report §3.5, §11.2: the fields a value of the type selects, each with
%% its type, by the rule selection itself follows: those every constructor
%% has, and none of an abstract type outside its module. The shell's
%% completion asks it.
-spec fields(ern_types:type(), env()) -> [{atom(), ern_types:type()}].
fields(Type, #env{type_state = TypeState, types = Types} = Env) ->
    case ern_types:resolve(Type, TypeState) of
        {tcon, QualifiedName, _} ->
            case maps:get(QualifiedName, Types, undefined) of
                #type_info{constructors = [#constructor_info{fields = {named, Names}} | _]} ->
                    lists:filtermap(fun(Field) -> selected(Field, Type, Env) end, Names);
                _ ->
                    []
            end;
        _ ->
            []
    end.

selected(Field, Type, Env) ->
    %% the position is never shown: a field that selects nothing is left out
    try resolve_select({1, 1, {1, 1}}, Field, Type, Env) of
        {FieldType, Env1} -> {true, {Field, ern_types:substitute(FieldType, Env1#env.type_state)}}
    catch
        throw:_ -> false
    end.

%% Report §3.5: the selector f exists where every constructor of the type
%% has a named field f, of one type; an abstract type's fields are its
%% module's (§4.4).
resolve_select(Span, Field, OperandType,
               #env{type_state = TypeState, types = Types, local_types = LocalTypes} = Env) ->
    Type = ern_types:resolve(OperandType, TypeState),
    FieldText = atom_to_list(Field),
    Shown = ern_types:format(Type, TypeState),
    case Type of
        {tcon, QualifiedName, _} ->
            IsOwn = maps:get(lists:last(QualifiedName), LocalTypes, undefined) =:= QualifiedName,
            case maps:get(QualifiedName, Types, undefined) of
                #type_info{abstract = true} when not IsOwn ->
                    fail(Span, Shown ++ " is abstract, and its fields are its module's alone");
                #type_info{constructors = [_ | _] = Constructors} ->
                    selected_field_type(Span, Field, Type, Constructors, Env);
                #type_info{} ->
                    fail(Span, Shown ++ " has no field " ++ FieldText);
                undefined ->
                    %% report §11.1: a type no interface declares is the
                    %% toolchain's own defect, not a type without fields
                    erlang:error({undeclared_type, ern_namespace:text(QualifiedName)})
            end;
        _ ->
            fail(Span, Shown ++ " has no field " ++ FieldText)
    end.

selected_field_type(Span, Field, Type, Constructors, Env) ->
    Shown = ern_types:format(Type, Env#env.type_state),
    HasField = fun(#constructor_info{fields = {named, FieldNames}}) ->
                       lists:member(Field, FieldNames);
                  (_) ->
                       false
               end,
    lists:any(HasField, Constructors)
        orelse fail(Span, Shown ++ " has no field " ++ atom_to_list(Field)),
    %% report §11.5: each message names the constructors it compares
    Step = fun(ConstructorInfo, Acc) ->
               constructor_field_type(Span, Field, Type, Shown, ConstructorInfo, Acc)
           end,
    {FieldType, _, Env1} = lists:foldl(Step, {undefined, undefined, Env}, Constructors),
    {FieldType, Env1}.

%% The field's type in one constructor, unified with its type in the
%% constructor before, which the accumulator carries.
constructor_field_type(Span, Field, Type, Shown,
                       #constructor_info{name = Constructor, fields = Fields, scheme = Scheme},
                       {PreviousType, Previous, Env}) ->
    FieldNames = case Fields of {named, Named} -> Named; _ -> [] end,
    case index_of(Field, FieldNames) of
        none ->
            fail(Span, "not every constructor of " ++ Shown ++ " has the field "
                       ++ atom_to_list(Field) ++ ": " ++ atom_to_list(Constructor) ++ " has none");
        Index ->
            {{tfn, FieldTypes, pure, Constructed}, TypeState1} =
                ern_types:instantiate(Scheme, Env#env.type_state),
            %% Constructed is Type's constructor applied to fresh variables
            Env1 = bound(Type, Constructed, Env#env{type_state = TypeState1}),
            ThisType = lists:nth(Index, FieldTypes),
            Env2 = case PreviousType of
                       undefined -> Env1;
                       _ -> one_field_type(Span, Field, Shown, {Previous, PreviousType},
                                           {Constructor, ThisType}, Env1)
                   end,
            {ThisType, Constructor, Env2}
    end.

one_field_type(Span, Field, Shown, {Previous, PreviousType}, {Constructor, FieldType},
               #env{type_state = TypeState} = Env) ->
    case ern_types:unify(PreviousType, FieldType, TypeState) of
        {ok, TypeState1} ->
            Env#env{type_state = TypeState1};
        {error, _} ->
            Name = atom_to_list(Field),
            fail(Span, Shown ++ " has no field " ++ Name ++ " of one type: " ++ Name ++ " is "
                       ++ ern_types:format(PreviousType, TypeState) ++ " in "
                       ++ atom_to_list(Previous) ++ " and "
                       ++ ern_types:format(FieldType, TypeState) ++ " in "
                       ++ atom_to_list(Constructor))
    end.

index_of(Item, Items) -> index_of(Item, Items, 1).
index_of(_, [], _) -> none;
index_of(Item, [Item | _], Index) -> Index;
index_of(Item, [_ | Rest], Index) -> index_of(Item, Rest, Index + 1).

resolve_operator(Span, Operator, OperandType, #env{type_state = TypeState} = Env) ->
    Type = ern_types:resolve(OperandType, TypeState),
    case Type of
        ?INT when Operator =:= negate -> {OperandType, Env};
        ?FLOAT when Operator =:= negate -> {OperandType, Env};
        ?INT -> arith_or_order(Operator, OperandType, ?ARITH, Span, Env);
        ?FLOAT -> arith_or_order(Operator, OperandType, ['+', '-', '*', '/'], Span, Env);
        ?STRING when Operator =:= '<>' -> {OperandType, Env};
        ?STRING -> arith_or_order(Operator, OperandType, [], Span, Env);
        ?CHAR -> arith_or_order(Operator, OperandType, [], Span, Env);
        {tcon, ['List'], _} when Operator =:= '<>' -> {OperandType, Env};
        ?BYTES when Operator =:= '<>' -> {OperandType, Env};
        {tcon, QualifiedName, _} when length(QualifiedName) > 1 ->
            user_operator(Span, Operator, OperandType, QualifiedName, Env);
        %% report §9.6: a prelude type's member, `Path.<>`, which the type's
        %% module provides
        {tcon, [_] = QualifiedName, _} ->
            user_operator(Span, Operator, OperandType, QualifiedName, Env);
        _ -> not_defined(Span, Operator, Type, Env)
    end.

arith_or_order(Operator, OperandType, Arith, Span, Env) ->
    case lists:member(Operator, Arith) of
        true -> {OperandType, Env};
        false ->
            case lists:member(Operator, ?ORDER) of
                true -> {?BOOL, Env};
                false -> not_defined(Span, Operator, OperandType, Env)
            end
    end.

user_operator(Span, Operator, OperandType, QualifiedName, Env) ->
    Member = case lists:member(Operator, ?ORDER) of true -> compare; false -> Operator end,
    Name = ern_namespace:text([lists:last(QualifiedName), Member]),
    case member_scheme(QualifiedName, Member, Env) of
        {undefined, Env1} -> not_defined(Span, Operator, OperandType, Env1);
        {Scheme, Env1} ->
            {MemberType, TypeState1} = ern_types:instantiate(Scheme, Env1#env.type_state),
            %% as a reference to the member would, report §3.9
            Pending = instance_pending(MemberType, Span, TypeState1),
            {Effect, TypeState2} = ern_types:fresh(TypeState1),
            {Result, TypeState3} = ern_types:fresh(TypeState2),
            {Operands, Rule} =
                case Operator of
                    negate -> {[OperandType], Name ++ " does not fit an operand of "};
                    _ -> {[OperandType, OperandType], Name ++ " does not fit two operands of "}
                end,
            Declared = member_declared(QualifiedName, Member, Name, MemberType,
                                       Env1#env{type_state = TypeState3}),
            Env2 = unify_at(Span, {tfn, Operands, Effect, Result}, MemberType,
                            Env1#env{type_state = TypeState3,
                                     pending = Pending ++ Env1#env.pending},
                            Rule ++ ern_types:format(OperandType, TypeState3), Declared),
            Env3 = use_effect(Span, Name, Effect, Env2),
            case Member of
                compare ->
                    Env4 = unify_at(Span, {tcon, ['Ordering'], []}, Result, Env3,
                                    Name ++ " must return an Ordering"),
                    {?BOOL, Env4};
                _ ->
                    {Result, Env3}
            end
    end.

%% Report §11.5: a member this module declares is labelled at its
%% declaration with its type; another module's is not in the source shown.
member_declared(QualifiedName, Member, Name, MemberType,
                #env{namespace = Namespace, typed = Typed, type_state = TypeState}) ->
    IsOwn = is_own_type_namespace(QualifiedName, Namespace),
    case [Declaration || Declaration <- Typed, IsOwn,
                         declaration_key(Declaration) =:= {lists:last(QualifiedName), Member}] of
        [Declaration | _] ->
            {head_span(Declaration), Name ++ " : " ++ ern_types:format(MemberType, TypeState)};
        [] -> undefined
    end.

%% A declaration's head, through its result annotation where it has one.
head_span(#fn_declaration{span = Span, result_type = ResultAnnotation})
  when ResultAnnotation =/= undefined ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {_, _, End} = ern_diagnostic:span(ern_ast:span(ResultAnnotation)),
    {Line, Column, End};
head_span(Declaration) ->
    ern_ast:span(Declaration).

-spec not_defined(ern_diagnostic:span(), atom(), term(), env()) -> no_return().
not_defined(Span, Operator, Type, Env) ->
    fail(Span, "`" ++ operator_text(Operator) ++ "` is not defined on "
               ++ ern_types:format(Type, Env#env.type_state)).

operator_text(negate) -> "-";
operator_text(Operator) -> atom_to_list(Operator).

%% The scheme of Member in the type QualifiedName: in this module, a local
%% value, checked now if its group has not run; in another, through its
%% compiled interface.
member_scheme(QualifiedName, Member,
              #env{namespace = Namespace, local_values = LocalValues} = Env) ->
    MemberQualifiedName =
        case is_own_type_namespace(QualifiedName, Namespace) of
            true -> maps:get({lists:last(QualifiedName), Member}, LocalValues, undefined);
            false -> session_member(QualifiedName, Member, Env)
        end,
    case MemberQualifiedName of
        undefined -> {undefined, Env};
        _ ->
            Env1 = demand(MemberQualifiedName, Env),
            {maps:get(MemberQualifiedName, Env1#env.globals, undefined), Env1}
    end.

%% Annotation variables scope over the definition and must stay distinct
%% and unbound: `fn id(x : a) : a = 1` is an error.
rigid_annotation_variables(Span, Rigid, #env{type_state = TypeState}) ->
    Resolved = [{Name, ern_types:resolve(Variable, TypeState)} || {Name, Variable} <- Rigid],
    lists:foreach(fun({_Name, {tvar, _}}) ->
                          ok;
                     ({Name, Type}) ->
                          fail(Span, "type variable " ++ atom_to_list(Name)
                                     ++ " in the annotation is used as "
                                     ++ ern_types:format(Type, TypeState))
                  end, Resolved),
    case [{First, Second} || {First, {tvar, FirstId}} <- Resolved,
                             {Second, {tvar, SecondId}} <- Resolved, First < Second,
                             FirstId =:= SecondId] of
        [] -> ok;
        [{First, Second} | _] ->
            fail(Span, "type variables " ++ atom_to_list(First) ++ " and " ++ atom_to_list(Second)
                       ++ " in the annotation are used as one type")
    end.

%% Report §11.5: a callee's type for the label at its call: a name's as its
%% declaration writes it, under the declaration's own variable names, as
%% `:type` prints it; any other callee's as inferred, with the requirement
%% it carries.
callee_text(#e_var{namespace = Namespace, name = Name}, TypedCallee, CalleeType, Env)
  when Name =/= undefined ->
    case declared_scheme(Namespace, Name, Env) of
        {ok, Scheme} -> ern_types:format_scheme(Scheme, Env#env.type_state);
        error -> ern_types:format_with_requirement(CalleeType, requirement_of(TypedCallee),
                                                   Env#env.type_state)
    end;
callee_text(_, TypedCallee, CalleeType, Env) ->
    ern_types:format_with_requirement(CalleeType, requirement_of(TypedCallee),
                                      Env#env.type_state).

%% Report §11.2: the type of a name as its declaration writes it, for the
%% shell's input that is one name; the scheme keeps the declaration's
%% variable names, which an instance does not.
-spec declared_scheme([atom()], atom(), env()) -> {ok, #scheme{}} | error.
declared_scheme(Namespace, Name, Env) ->
    %% the position is never shown: an unknown name answers `error`
    try lookup_value({1, 1, {1, 1}}, Namespace, Name, Env) of
        {Scheme, _, _} -> {ok, Scheme}
    catch
        throw:{type_error, _, _} -> error;
        throw:{type_error, _} -> error
    end.


%%
%% Expressions: infer(Expr, Env) -> {TypedExpr, Type, Env}
%%

%% Report §3.9: a pure function stands where one with a mailbox type is
%% expected, so an expression whose type is a pure function type takes a
%% fresh effect variable in its outermost arrow, which the context binds.
open_effect(Type, TypeState) ->
    case ern_types:resolve(Type, TypeState) of
        {tfn, Params, Effect, Result} ->
            case ern_types:resolve(Effect, TypeState) of
                pure ->
                    {Fresh, TypeState1} = ern_types:fresh(TypeState),
                    {{tfn, Params, Fresh, Result}, TypeState1};
                _ -> {Type, TypeState}
            end;
        _ -> {Type, TypeState}
    end.

infer(#e_literal{kind = Kind} = Expr, Env) ->
    Type = literal_type(Kind),
    {Expr#e_literal{type = Type}, Type, Env};
infer(#e_var{span = Span, namespace = Namespace, name = Name} = Expr, Env) ->
    %% report §11.2: a name the session declared resolves to the input that
    %% declared it, which its referent records; its namespace stays as written
    {Scheme, Referent, Env1} = lookup_value(Span, Namespace, Name, Env),
    {Closed, Requirement, TypeState1} = ern_types:instance(Scheme, Env1#env.type_state),
    {Type, TypeState} = open_effect(Closed, TypeState1),
    Who = case Scheme of
              #scheme{quantified = []} -> undefined;
              _ ->
                  {ern_namespace:text(Namespace ++ [Name]),
                   ern_types:format_scheme(Scheme, TypeState)}
          end,
    Pending = instance_pending(Type, Span, TypeState, Who),
    %% report §4.9: a call writes nothing for a requirement; what supplies
    %% it is read at the definition's end, as is what `Io.show` writes by
    Need = case io_shown(Referent, Env1) of
               {ok, Shown} -> {shown, Shown};
               none -> {call, needer_name(Referent, Name)}
           end,
    Supplies = [#pending_member{span = Span, type = Instance, member = Member, need = Need}
                || {Instance, Member} <- Requirement]
        ++ shown(Span, Referent, Type, Env1),
    %% report §4.2: what the name resolved to is recorded, so that the
    %% emitter reads the decision rather than making it again
    {Expr#e_var{type = Type, referent = Referent, supplies = Supplies}, Type,
     Env1#env{type_state = TypeState, pending = Pending ++ Env1#env.pending}};
infer(#e_constructor{span = Span, namespace = ConstructorNamespace, name = Name, base = Base,
                     args = Args} = Expr, Env) ->
    ConstructorInfo = lookup_constructor(Span, ConstructorNamespace, Name, Env),
    {ConstructorType, TypeState} =
        ern_types:instantiate(ConstructorInfo#constructor_info.scheme, Env#env.type_state),
    Env1 = Env#env{type_state = TypeState},
    case {ConstructorInfo#constructor_info.fields, Args} of
        {none, none} ->
            {Expr#e_constructor{type = ConstructorType}, ConstructorType, Env1};
        {none, _} ->
            fail(Span, atom_to_list(Name) ++ " takes no fields");
        {positional, {positional, Arg}} ->
            {tfn, [FieldType], pure, Constructed} = ConstructorType,
            {TypedArg, _ArgType, Env2} = check_expr(Arg, FieldType,
                                                    "the field of " ++ atom_to_list(Name),
                                                    undefined, Env1),
            {Expr#e_constructor{args = {positional, TypedArg}, type = Constructed}, Constructed,
             Env2};
        {positional, none} ->
            %% a single-positional constructor is a function value (§5.6)
            {Opened, TypeState1} = open_effect(ConstructorType, TypeState),
            {Expr#e_constructor{type = Opened}, Opened, Env1#env{type_state = TypeState1}};
        {positional, {named, _}} ->
            fail(Span, atom_to_list(Name) ++ " has one positional field, not named fields");
        {{named, Names}, {named, FieldSets}} ->
            {tfn, FieldTypes, pure, Constructed} = ConstructorType,
            Base =:= undefined orelse one_constructor(Span, ConstructorInfo, Env1),
            case fill_namespace(Base, Env1) of
                {namespace, Namespace} ->
                    filled(Expr, Namespace, Names, FieldTypes, Constructed, FieldSets, Env1);
                expression ->
                    %% report §5.6: a record update gives at least one field
                    Base =:= undefined orelse FieldSets =/= []
                        orelse fail(Span, "a record update gives at least one field after its"
                                          " `..`", [],
                                    "give the fields that change; with none, the value after"
                                    " `..` is the record"),
                    infer_named(Expr, Names, FieldTypes, Constructed, Base, FieldSets, none, Env1)
            end;
        {{named, Names}, _} ->
            fail(Span, atom_to_list(Name) ++ " has named fields; write "
                       ++ named_form(Name, Names, "value"))
    end;
infer(#e_tuple{elements = Elements} = Expr, Env) ->
    {TypedElements, Types, Env1} = infer_list(Elements, Env),
    Type = {ttuple, Types},
    {Expr#e_tuple{elements = TypedElements, type = Type}, Type, Env1};
infer(#e_list{elements = Elements} = Expr, Env) ->
    {ElementType, TypeState} = ern_types:fresh(Env#env.type_state),
    Check = fun(Element, {Acc, Origin}) ->
                {TypedElement, _, Acc1} = check_expr(Element, ElementType,
                                                     "list elements must have one type", Origin,
                                                     Acc),
                {TypedElement, {Acc1, first_origin(Origin, Element, ElementType, Acc1)}}
            end,
    {TypedElements, {Env1, _}} =
        lists:mapfoldl(Check, {Env#env{type_state = TypeState}, undefined}, Elements),
    Type = {tcon, ['List'], [ElementType]},
    {Expr#e_list{elements = TypedElements, type = Type}, Type, Env1};
infer(#e_bitstring{span = Span, segments = Segments} = Expr, Env) ->
    %% report §5.11
    Check = fun(Segment, Acc) -> bit_segment(Segment, construct, Acc) end,
    {TypedSegments, Env1} = lists:mapfoldl(Check, Env, Segments),
    alignment(Span, TypedSegments, "the bitstring"),
    {Expr#e_bitstring{segments = TypedSegments, type = ?BYTES}, ?BYTES, Env1};
infer(#e_block{span = Span, statements = Statements} = Expr, Env) ->
    {TypedStatements, Type, Env1} = infer_block(Statements, Span, undefined, Env),
    {Expr#e_block{statements = TypedStatements, type = Type}, Type,
     Env1#env{locals = Env#env.locals}};
infer(#e_call{pipe = true,
              callee = #e_constructor{span = ConstructorSpan, args = ConstructorArgs}}, _Env)
  when ConstructorArgs =/= none ->
    %% report §5.7, Appendix A: a construction is a value of its type, never
    %% a function, which the pipe applies and does not fill
    fail(ConstructorSpan, "a construction is a value, not a call, and `|>` does not fill it", [],
         "put the piped value in the construction itself");
infer(#e_call{span = Span, callee = Callee, args = Args} = Expr, Env) ->
    {TypedCallee, CalleeType, Env1} = infer(Callee, Env),
    Name = callee_name(Callee),
    case ern_types:resolve(CalleeType, Env1#env.type_state) of
        {tfn, ParamTypes, _, _} when length(ParamTypes) =/= length(Args) ->
            fail(Span, io_lib:format("~s takes ~B argument~s, not ~B",
                                     [Name, length(ParamTypes), plural(length(ParamTypes)),
                                      length(Args)]),
                 [], "a call supplies all the arguments");
        {tfn, ParamTypes, Effect, ResultType} ->
            Returns = returns(Callee, Env1),
            %% report §11.5: the callee's type ends in its requirement
            Origin = {ern_ast:span(Callee), Name ++ " : " ++ callee_text(Callee, TypedCallee,
                                                                       CalleeType, Env1)},
            Rule = argument_rule(Name, TypedCallee, Env1),
            CalleeSpan = ern_diagnostic:span(ern_ast:span(Callee)),
            Check = fun({Index, Arg, ParamType}, Acc) ->
                        {TypedArg, _, Acc1} = check_expr(Arg, ParamType, Rule, Origin, Acc),
                        {TypedArg, placed_argument(CalleeSpan, Arg, Index, Acc1)}
                    end,
            {TypedArgs, Env2} = lists:mapfoldl(Check, Env1,
                                               lists:zip3(lists:seq(1, length(Args)), Args,
                                                          ParamTypes)),
            Env3 = use_effect(Span, Name, Effect, Env2),
            {Opened, TypeState1} = open_effect(ResultType, Env3#env.type_state),
            {Expr#e_call{callee = TypedCallee, args = TypedArgs, type = Opened, returns = Returns},
             Opened, Env3#env{type_state = TypeState1}};
        {tvar, _} ->
            {TypedArgs, ArgTypes, Env2} = infer_list(Args, Env1),
            {ResultType, TypeState} = ern_types:fresh(Env2#env.type_state),
            {Effect, TypeState1} = ern_types:fresh(TypeState),
            Env3 = unify_at(Span, CalleeType, {tfn, ArgTypes, Effect, ResultType},
                            Env2#env{type_state = TypeState1},
                            "calling " ++ Name ++ " needs it to be a function"),
            Env4 = use_effect(Span, Name, Effect, Env3),
            {Expr#e_call{callee = TypedCallee, args = TypedArgs, type = ResultType}, ResultType,
             Env4};
        _ when Args =:= [], is_record(Callee, e_constructor) ->
            %% Appendix A: empty parentheses after a constructor are a call
            %% of its value, and one without fields is no function (report
            %% §5.6)
            fail(Span, "empty parentheses after " ++ Name, [],
                 "a constructor without fields is written without parentheses, " ++ Name);
        Other ->
            fail(Span, Name ++ " is not a function; it has type "
                       ++ ern_types:format(Other, Env1#env.type_state))
    end;
infer(#e_not{span = Span, expr = Operand} = Expr, Env) ->
    %% report §4.8: `!` is Bool's, as `&&` and `||` are
    {TypedOperand, OperandType, Env1} = infer(Operand, Env),
    Env2 = unify_at(Span, ?BOOL, OperandType, Env1, "the operand of `!`"),
    {Expr#e_not{expr = TypedOperand, type = ?BOOL}, ?BOOL, Env2};
infer(#e_selection{span = Span, expr = Operand, field = Field, field_span = FieldSpan} = Expr,
      Env) ->
    {TypedOperand, OperandType, Env1} = infer(Operand, Env),
    %% report §11.5: a selection's error stands at the selector
    ErrorSpan = case FieldSpan of
                    undefined -> Span;
                    _ -> FieldSpan
                end,
    {Closed, Env2} = select_result(ErrorSpan, Field, OperandType, Env1),
    {Type, TypeState} = open_effect(Closed, Env2#env.type_state),
    {Expr#e_selection{expr = TypedOperand, type = Type}, Type, Env2#env{type_state = TypeState}};
infer(#e_negation{span = Span, expr = Operand} = Expr, Env) ->
    {TypedOperand, OperandType, Env1} = infer(Operand, Env),
    {Closed, Env2} = operator_result(Span, negate, OperandType, Env1),
    {Type, TypeState} = open_effect(Closed, Env2#env.type_state),
    Member = operator_member(Span, negate, OperandType),
    {Expr#e_negation{expr = TypedOperand, member = Member, type = Type}, Type,
     Env2#env{type_state = TypeState}};
infer(#e_binop{span = Span, operator = Operator, left = Left, right = Right} = Expr, Env) ->
    {TypedLeft, LeftType, Env1} = infer(Left, Env),
    {TypedRight, RightType, Env2} = infer(Right, Env1),
    {Closed, Env3} = binop_type(Span, Operator, Left, LeftType, Right, RightType, Env2),
    {Type, TypeState} = open_effect(Closed, Env3#env.type_state),
    Member = operator_member(Span, Operator, LeftType),
    {Expr#e_binop{left = TypedLeft, right = TypedRight, member = Member, type = Type}, Type,
     Env3#env{type_state = TypeState}};
infer(#e_member{span = Span, member_of = Variable, name = Member} = Expr, Env)
  when is_atom(Variable) ->
    %% report §4.9: `a.compare` under a requirement that names it, a value
    %% of the member's shape at a
    TypeVariable = in_force(Span, Variable, Member, Env),
    {Type, TypeState} = open_effect(member_shape_at(Member, TypeVariable),
                                    Env#env.type_state),
    {Expr#e_member{supply = #required_member{variable = TypeVariable, member = Member},
                   type = Type},
     Type, Env#env{type_state = TypeState}};
infer(#e_member{span = Span, member_of = #t_named{} = Annotation, name = Member} = Expr, Env) ->
    %% report §3.5: a derived compare's field compared by its type's own,
    %% supplied at the definition's end as any member is
    {FieldType, _, TypeState} = annotation_type(Annotation, Env#env.annotation_variables, Env),
    {Type, TypeState1} = open_effect(member_shape_at(Member, FieldType), TypeState),
    Supply = #pending_member{span = Span, type = FieldType, member = Member,
                             need = {call, declaration_text(Env)}},
    {Expr#e_member{supply = Supply, type = Type}, Type, Env#env{type_state = TypeState1}};
infer(#e_lambda{span = LambdaSpan, params = Params, result_type = ResultAnnotation,
                effect = Effect, body = Body} = Expr, Env) ->
    {TypedParams, ParamTypes, Env1, AnnotationVariables} =
        bind_params(Params, Env, Env#env.annotation_variables),
    {ResultType, EffectType, AnnotationVariables1, TypeState} =
        result_types(ResultAnnotation, Effect, AnnotationVariables, Env1),
    Type = {tfn, ParamTypes, EffectType, ResultType},
    %% report §3.9: the definition's annotation variables are in scope and
    %% rigid; a name new here means every type, as it does in a `fn`, and
    %% is rigid where the lambda is generalized; one that is not generalized
    %% may name none. A regression: a new name was the lambda's own and not
    %% rigid, so `fn(x : a) : a = x + 1` made `a` an Int
    New = [{Name, Variable} || Name := Variable <- AnnotationVariables1,
                               not is_map_key(Name, Env#env.annotation_variables)],
    case {New, Env#env.generalizing} of
        {[_ | _], false} ->
            fail(LambdaSpan,
                 "type variable " ++ atom_to_list(lists:min([Name || {Name, _} <- New]))
                 ++ " in the lambda's annotation means every type, and the lambda is not"
                 " generalized", [],
                 "write the type, or leave the annotation out");
        _ ->
            ok
    end,
    Env2 = Env1#env{type_state = mark_process_only(Type, TypeState), effect = EffectType,
                    annotation_variables = AnnotationVariables1,
                    generalizing = false, rigid = New ++ Env1#env.rigid,
                    %% report §11.5: the label names the annotation that fixed the
                    %% mailbox, and an unannotated lambda's is its own, not the
                    %% enclosing definition's
                    effect_origin = effect_origin("the lambda", ResultAnnotation, Effect,
                                                  ResultType, EffectType, TypeState)},
    Rule = result_rule(ResultAnnotation, "the lambda body does not have the declared type"),
    ResultOrigin = result_origin(ResultAnnotation, ResultType, Env2),
    {TypedBody, _BodyType, Env3} = check_expr(Body, ResultType, Rule, ResultOrigin, Env2),
    rigid_annotation_variables(LambdaSpan, New, Env3),
    %% the body was checked as the annotation says; a lambda written pure
    %% stands where one with a mailbox type is expected, as any expression
    %% of a pure function type does (report §3.9)
    {Opened, TypeState1} = open_effect(Type, Env3#env.type_state),
    {Expr#e_lambda{params = TypedParams, body = TypedBody, type = Type}, Opened,
     Env3#env{type_state = TypeState1, locals = Env#env.locals, effect = Env#env.effect,
              annotation_variables = Env#env.annotation_variables,
              effect_origin = Env#env.effect_origin, effectful = Env#env.effectful,
              generalizing = false, rigid = Env#env.rigid}};
infer(Expr, Env) when is_record(Expr, e_if); is_record(Expr, e_match); is_record(Expr, e_receive) ->
    {Type, TypeState} = ern_types:fresh(Env#env.type_state),
    check_expr(Expr, Type, undefined, undefined, Env#env{type_state = TypeState}).

%% Report §11.5: after a sequence's first element, its type is the origin
%% of the rest's expected type.
first_origin(undefined, Element, ElementType, Env) ->
    {ern_ast:span(Element),
     "the first element has type " ++ ern_types:format(ElementType, Env#env.type_state)};
first_origin(Origin, _, _, _) ->
    Origin.

%% Report §11.5: an expression checked against an expected type. The
%% expectation is pushed into branches, clauses, and a block's last
%% statement, so a mismatch is reported at the leaf; Rule is the rule its
%% message opens with, and Origin the span that fixed the expectation, or
%% undefined when it is the first branch, which then becomes the origin for
%% the rest.
check_expr(#e_if{condition = Condition, then_branch = Then, else_branch = Else} = Expr,
           Expected, Rule, Origin, Env) ->
    {TypedCondition, _, Env1} =
        check_expr(Condition, ?BOOL, "the condition of `if`", undefined, Env),
    {TypedThen, _, Env2} = check_expr(Then, Expected, Rule, Origin, Env1),
    {Rule1, Origin1} = sibling(Rule, Origin, "the branches of `if` must have one type",
                               Then, "the then branch", Expected, Env2),
    {TypedElse, _, Env3} = check_expr(Else, Expected, Rule1, Origin1, Env2),
    {Expr#e_if{condition = TypedCondition, then_branch = TypedThen, else_branch = TypedElse,
               type = Expected},
     Expected, Env3};
check_expr(#e_match{scrutinee = Scrutinee, clauses = Clauses} = Expr, Expected, Rule,
           Origin, Env) ->
    {TypedScrutinee, ScrutineeType, Env1} = infer(Scrutinee, Env),
    ScrutineeOrigin = {ern_ast:span(Scrutinee), "the value matched has type "
                       ++ ern_types:format(ScrutineeType, Env1#env.type_state)},
    {TypedClauses, Env2} = check_clauses(match, Clauses, ScrutineeType, ScrutineeOrigin,
                                         Expected, Rule, Origin,
                                         "the clauses must have one type", Env1),
    {Expr#e_match{scrutinee = TypedScrutinee, clauses = TypedClauses, type = Expected}, Expected,
     Env2};
check_expr(#e_receive{span = Span, clauses = Clauses, 'after' = After} = Expr, Expected, Rule,
           Origin, Env) ->
    {MailboxType, Env1} = mailbox_type(Span, Env),
    case Clauses =/= [] andalso ern_types:resolve(MailboxType, Env1#env.type_state) =:= ?NEVER of
        true -> never_receives(Span, Env1#env.effect_origin);
        false -> ok
    end,
    {TypedClauses, Env2} = check_clauses('receive', Clauses, MailboxType, undefined, Expected,
                                         Rule, Origin, "the clauses must have one type", Env1),
    {TypedAfter, Env3} =
        case After of
            undefined -> {undefined, Env2};
            #after_clause{timeout = Timeout, body = Body} = AfterClause ->
                {TypedTimeout, _, AfterEnv1} =
                    check_expr(Timeout, ?INT, "the `after` time is in milliseconds", undefined,
                               Env2),
                {Rule1, Origin1} =
                    case {Clauses, Origin} of
                        {[#clause{body = First} | _], undefined} ->
                            sibling(Rule, Origin, "the `after` body must have the clauses' type",
                                    First, "the first clause", Expected, AfterEnv1);
                        _ -> {Rule, Origin}
                    end,
                {TypedBody, _, AfterEnv2} =
                    check_expr(Body, Expected, Rule1, Origin1, AfterEnv1),
                {AfterClause#after_clause{timeout = TypedTimeout, body = TypedBody}, AfterEnv2}
        end,
    {Expr#e_receive{clauses = TypedClauses, 'after' = TypedAfter, type = Expected}, Expected, Env3};
check_expr(#e_block{span = Span, statements = Statements} = Expr, Expected, Rule, Origin, Env) ->
    {TypedStatements, Type, Env1} = infer_block(Statements, Span, {Expected, Rule, Origin}, Env),
    {Expr#e_block{statements = TypedStatements, type = Type}, Type,
     Env1#env{locals = Env#env.locals}};
check_expr(Expr, Expected, undefined, _Origin, Env) ->
    %% the first branch where nothing fixed the type: the expectation is a
    %% fresh variable, which the branch fixes
    {Typed, Type, Env1} = infer(Expr, Env),
    {Typed, Type, bound(Expected, Type, Env1)};
check_expr(Expr, Expected, Rule, Origin, Env) ->
    {Typed, Type, Env1} = infer(Expr, Env),
    {Typed, Type,
     unify_at(ern_ast:span(Expr), Expected, Type, expecting(Type, Origin, Env1), Rule, Origin)}.

%% Report §11.5: a selection or an operator deferred until its operand's
%% type is known keeps the span that fixed its expected type, the label of
%% its mismatch when it is resolved.
expecting(_Type, undefined, Env) ->
    Env;
expecting(Type, Origin, #env{deferred = Deferred} = Env) ->
    Env#env{deferred = [with_origin(Item, Type, Origin) || Item <- Deferred]}.

with_origin(#deferred_operator{result = Type, origin = undefined} = Item, Type, Origin) ->
    Item#deferred_operator{origin = Origin};
with_origin(#deferred_selection{result = Type, origin = undefined} = Item, Type, Origin) ->
    Item#deferred_selection{origin = Origin};
with_origin(Item, _Type, _Origin) ->
    Item.

%% Report §11.5: a deferred operand type that a unification at Span fixes,
%% a variable under Before and no longer one now, keeps Span, where the
%% definition settled it.
settle(Span, Before, #env{deferred = Deferred, type_state = TypeState} = Env) ->
    Fixes = fun(OperandType) ->
                is_variable(OperandType, Before) andalso not is_variable(OperandType, TypeState)
            end,
    Settled = fun(#deferred_operator{settled = undefined, operand_type = OperandType} = Item) ->
                      case Fixes(OperandType) of
                          true -> Item#deferred_operator{settled = ern_diagnostic:span(Span)};
                          false -> Item
                      end;
                 (#deferred_selection{settled = undefined, operand_type = OperandType} = Item) ->
                      case Fixes(OperandType) of
                          true -> Item#deferred_selection{settled = ern_diagnostic:span(Span)};
                          false -> Item
                      end;
                 (Item) ->
                      Item
              end,
    Env#env{deferred = lists:map(Settled, Deferred)}.

is_variable(Type, TypeState) ->
    element(1, ern_types:resolve(Type, TypeState)) =:= tvar.

%% Report §11.5: a deferred mismatch's labels, the span that fixed the
%% expected type and the one that settled the operand type, which a later
%% use in the definition did.
settled_origin(#deferred_operator{origin = Origin, settled = undefined}, _Env) ->
    Origin;
settled_origin(#deferred_operator{origin = Origin, settled = Span, operator = Operator,
                                  operand_type = OperandType}, #env{type_state = TypeState}) ->
    [Origin, {Span, "this fixes `" ++ operator_text(Operator) ++ "`'s operands as "
                    ++ ern_types:format(OperandType, TypeState)}];
settled_origin(#deferred_selection{origin = Origin, settled = undefined}, _Env) ->
    Origin;
settled_origin(#deferred_selection{origin = Origin, settled = Span, field = Field,
                                   operand_type = OperandType}, #env{type_state = TypeState}) ->
    [Origin, {Span, "this fixes the value whose " ++ atom_to_list(Field) ++ " is read as "
                    ++ ern_types:format(OperandType, TypeState)}].

%% Report §6.3: a receive guard is a guard expression, since it selects a
%% message without removing it: `true`, `false`, a Bool operand, or a
%% comparison of two operands, under `!`, `&&`, and `||`. The guard is
%% already a Bool, so a bare operand is a Bool one.
receive_guard(#e_binop{operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '&&'; Operator =:= '||' ->
    receive_guard(Right, receive_guard(Left, Env));
receive_guard(#e_binop{operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '=='; Operator =:= '!=' ->
    guard_operand(Left, Env),
    guard_operand(Right, Env),
    Env;
receive_guard(#e_binop{span = Span, operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '<'; Operator =:= '<='; Operator =:= '>'; Operator =:= '>=' ->
    %% report §4.8: an operand type a later use fixes is known at the
    %% definition's end, where the ordering is checked
    Env1 = case ern_types:resolve(node_type(Left), Env#env.type_state) of
               {tvar, _} ->
                   Deferred = #deferred_guard_order{span = Span, operator = Operator,
                                                    operand_type = node_type(Left)},
                   Env#env{deferred = [Deferred | Env#env.deferred]};
               Type ->
                   guard_order(Span, Type, Env),
                   Env
           end,
    guard_operand(Left, Env1),
    guard_operand(Right, Env1),
    Env1;
receive_guard(#e_not{expr = Operand}, Env) -> receive_guard(Operand, Env);
receive_guard(#e_literal{kind = bool}, Env) -> Env;
receive_guard(#e_var{} = Variable, Env) ->
    guard_operand(Variable, Env),
    Env;
receive_guard(Guard, _) ->
    fail(ern_ast:span(Guard), "a `receive` guard combines `true`, `false`, Bool variables, and"
                              " comparisons with `!`, `&&`, and `||`, and calls nothing",
         [], "receive the message and `match` it").

%% Report §6.3: a `receive` guard orders Int, Float, String and Char, the
%% host's own order, and no type whose order is its `compare`.
guard_order(_Span, Type, _Env) when Type =:= ?INT; Type =:= ?FLOAT; Type =:= ?STRING;
                                   Type =:= ?CHAR ->
    ok;
guard_order(Span, Type, Env) ->
    fail(Span, "a `receive` guard orders only Int, Float, String, and Char, not "
               ++ ern_types:format(Type, Env#env.type_state),
         [], "receive the message and `match` it").

%% An operand: a variable of the pattern or of the enclosing function, a
%% top-level `let`, which the `receive` reads before it waits, a literal, a
%% negative numeric literal, or a nullary constructor. A regression: a
%% top-level binding was refused, the host's guard showing through.
guard_operand(#e_literal{}, _) -> ok;
guard_operand(#e_negation{expr = #e_literal{kind = Kind}}, _) when Kind =:= int; Kind =:= float ->
    ok;
guard_operand(#e_constructor{args = none}, _) -> ok;
guard_operand(#e_var{namespace = [], name = Name}, #env{locals = Locals})
  when is_map_key(Name, Locals) ->
    ok;
guard_operand(#e_var{referent = Referent} = Variable, Env) ->
    is_top_let(Referent, Env)
        orelse fail(ern_ast:span(Variable),
                    callee_name(Variable) ++ " is a function, and a `receive` guard calls nothing",
                    [], "receive the message and `match` it");
guard_operand(Operand, _) ->
    fail(ern_ast:span(Operand), "a comparison in a `receive` guard compares variables, literals,"
                                " and nullary constructors",
         [], "receive the message and `match` it").

%% Whether a name's referent is a top-level `let`, of this module or another.
is_top_let(#own_declaration{member_of = MemberOf, name = Name},
           #env{namespace = Namespace, lets = Lets}) ->
    is_map_key(Namespace ++ [Part || Part <- [MemberOf], Part =/= undefined] ++ [Name], Lets);
is_top_let(#remote_declaration{namespace = Namespace, member_of = MemberOf, name = Name},
           #env{lets = Lets}) ->
    is_map_key(Namespace ++ [Part || Part <- [MemberOf], Part =/= undefined] ++ [Name], Lets);
is_top_let({prelude, QualifiedName}, #env{lets = Lets}) ->
    is_map_key(QualifiedName, Lets);
is_top_let(_, _) ->
    false.

%% After the first branch, the expectation's origin is that branch when
%% nothing outside fixed it.
sibling(Rule, undefined, SiblingRule, First, What, Expected, Env) ->
    {default(Rule, SiblingRule),
     {ern_ast:span(First), What ++ " has type " ++ ern_types:format(Expected, Env#env.type_state)}};
sibling(Rule, Origin, _SiblingRule, _First, _What, _Expected, _Env) ->
    {Rule, Origin}.

default(undefined, Text) -> Text;
default(Rule, _) -> Rule.

infer_list(Exprs, Env) ->
    {Typed, Env1} = lists:mapfoldl(fun(Expr, Acc) ->
                                       {TypedExpr, ExprType, Acc1} = infer(Expr, Acc),
                                       {{TypedExpr, ExprType}, Acc1}
                                   end, Env, Exprs),
    {TypedExprs, Types} = lists:unzip(Typed),
    {TypedExprs, Types, Env1}.

%% The requirement a callee's use carries, each member at its type there.
requirement_of(#e_var{supplies = Supplies}) ->
    [{Type, Member} || #pending_member{type = Type, member = Member, need = {call, _}}
                           <- Supplies];
requirement_of(_) ->
    [].

callee_name(#e_var{namespace = Namespace, name = Name}) -> ern_namespace:text(Namespace ++ [Name]);
%% report §11.5: a selected field called, named as written, `ops.toList`
callee_name(#e_selection{expr = Expr, field = Field}) ->
    case callee_name(Expr) of
        "the callee" -> "the callee";
        Name -> Name ++ "." ++ atom_to_list(Field)
    end;
callee_name(#e_member{member_of = Variable, name = Member}) when is_atom(Variable) ->
    atom_to_list(Variable) ++ "." ++ atom_to_list(Member);
%% report §5.6: a constructor's value called, named as written, `None()`
callee_name(#e_constructor{namespace = Namespace, name = Name, args = none}) ->
    ern_namespace:text(Namespace ++ [Name]);
callee_name(_) -> "the callee".

%% Report §3.9, §11.5: an argument's mismatch in a recursive call, one to a
%% definition whose inference is under way, names the rule it breaks: no
%% polymorphic recursion.
argument_rule(Name, Callee, #env{inferring = Inferring} = Env) ->
    Recursive = case Callee of
                    #e_var{referent = var, namespace = [], name = LocalName} ->
                        lists:member({local, LocalName}, Inferring);
                    #e_var{referent = #own_declaration{member_of = MemberOf,
                                                       name = DeclarationName}} ->
                        lists:member({global,
                                      value_qualified_name(Env, MemberOf, DeclarationName)},
                                     Inferring);
                    _ -> false
                end,
    case Recursive of
        true -> {help, "the argument of a recursive call does not fit " ++ Name ++ " at its own"
                       " type (§3.9)",
                 "declare a second function for the call at another type"};
        false -> "the argument does not fit " ++ Name
    end.

%% Report §6.6: a function whose result type is a variable neither a
%% parameter's type nor its mailbox type names does not return, `fault`
%% among them, and a call to it consumes every obligation open on its
%% path. One whose result is its mailbox type returns what it receives.
%% The variable is the scheme's own; one the enclosing definition fixes
%% may stand for a type a value has.
returns(#e_var{span = Span, namespace = Namespace, name = Name}, Env) ->
    {#scheme{quantified = Quantified, type = Type}, _, _} =
        lookup_value(Span, Namespace, Name, Env),
    TypeState = Env#env.type_state,
    case ern_types:resolve(Type, TypeState) of
        {tfn, Params, Effect, Result} ->
            case ern_types:resolve(Result, TypeState) of
                {tvar, Id} ->
                    Named = ern_types:free_variables({tfn, Params, Effect, {ttuple, []}},
                                                     TypeState),
                    not (lists:keymember(Id, 1, Quantified)
                         andalso not lists:member(Id, Named));
                _ ->
                    true
            end;
        _ ->
            true
    end;
returns(_, _) ->
    true.

%% A callee's effect: pure constrains nothing; anything else is the
%% enclosing function's effect.
use_effect(Span, Name, Effect,
           #env{type_state = TypeState, effect = Have, effect_origin = Origin} = Env) ->
    case ern_types:resolve(Effect, TypeState) of
        pure -> Env;
        Resolved ->
            case ern_types:unify(Have, Effect, TypeState) of
                {ok, TypeState1} ->
                    %% report §3.9, §4.6: a call of a process-only function,
                    %% not one whose effect is still open
                    Env#env{type_state = TypeState1,
                            effectful = Env#env.effectful orelse process_only(Resolved, TypeState)};
                {error, {mismatch, _, _}} ->
                    fail(Span, Name ++ " needs mailbox " ++ ern_types:format(Effect, TypeState)
                               ++ ", and the mailbox here is " ++ ern_types:format(Have, TypeState),
                         labels(Origin), undefined);
                {error, _Reason} ->
                    fail(Span, Name ++ " needs a process, and " ++ what(Origin) ++ " is pure",
                         labels(Origin), help(Origin))
            end
    end.

%% Report §6.8, §4.6: a receive with a pattern clause where the mailbox is
%% Never, in a function or in a top-level initializer.
-spec never_receives(ern_diagnostic:span(), term()) -> no_return().
never_receives(Span, #effect_origin{what = top_let, help = Help} = Origin) ->
    fail(Span, "a top-level initializer runs with mailbox Never and cannot receive",
         labels(Origin), Help);
never_receives(Span, #effect_origin{what = Name} = Origin) ->
    %% report §11.5: the function named, and the `with` that fixed its
    %% mailbox labelled
    fail(Span, Name ++ " is declared with mailbox Never and cannot receive", labels(Origin),
         "only an `after` clause is allowed; give " ++ Name ++ " another mailbox type with"
         " `with`");
never_receives(Span, _) ->
    fail(Span, "a function with mailbox Never cannot receive", [],
         "only an `after` clause is allowed; give the function another mailbox type with `with`").

process_only({tvar, Id}, TypeState) ->
    lists:member(process_only, ern_types:restrictions(Id, TypeState));
process_only(_, _) -> true.

labels(undefined) -> [];
labels(Origins) when is_list(Origins) -> lists:append([labels(Origin) || Origin <- Origins]);
labels({Span, Label}) -> [{ern_diagnostic:span(Span), Label}];
labels(#effect_origin{span = Span, label = Label}) -> [{ern_diagnostic:span(Span), Label}].

what(undefined) -> "this function";
what(#effect_origin{what = top_let}) -> "a top-level `let`";
what(#effect_origin{what = What}) -> What.

%% Report §11.5: a field given or matched twice, named, at the second, the
%% first labelled.
twice(Fields, Verb) ->
    case repeated(Fields) of
        none -> ok;
        {Name, First, Second} ->
            fail(Second, "field " ++ atom_to_list(Name) ++ " is " ++ Verb ++ " twice",
                 [{ern_diagnostic:span(First), "first " ++ Verb ++ " here"}], undefined)
    end.

help(undefined) -> "give the function a mailbox type with `with`";
help(#effect_origin{help = Help}) -> Help.

infer_named(Expr, Names, FieldTypes, Constructed, Base, FieldSets, none, Env)
  when Base =/= undefined ->
    case [FieldSet || #field_set{path = [_ | _]} = FieldSet <- FieldSets] of
        [] -> infer_fields(Expr, Names, FieldTypes, Constructed, Base, FieldSets, none, Env);
        _ -> updated_through_paths(Expr, Names, FieldTypes, Constructed, Base, FieldSets, Env)
    end;
infer_named(Expr, Names, FieldTypes, Constructed, Base, FieldSets, Fill, Env) ->
    infer_fields(Expr, Names, FieldTypes, Constructed, Base, FieldSets, Fill, Env).

infer_fields(#e_constructor{span = Span, name = Name} = Expr, Names, FieldTypes, Constructed,
             Base, FieldSets, Fill, Env) ->
    SetNames = [FieldName || #field_set{name = FieldName} <- FieldSets],
    twice([{FieldName, FieldSpan} || #field_set{span = FieldSpan, name = FieldName} <- FieldSets],
          "given"),
    lists:foreach(fun(FieldName) ->
                      lists:member(FieldName, Names) orelse
                          fail(Span, atom_to_list(Name) ++ " has no field "
                                     ++ atom_to_list(FieldName))
                  end, SetNames),
    {TypedBase, Env1} = named_base(Expr, Base, Names -- SetNames, Constructed, Env),
    Check = fun(FieldSet, Acc) ->
                    check_field_set(FieldSet, Expr, Names, FieldTypes, Fill, Acc)
            end,
    {TypedFieldSets, Env2} = lists:mapfoldl(Check, Env1, FieldSets),
    {Expr#e_constructor{base = TypedBase, args = {named, TypedFieldSets}, type = Constructed},
     Constructed, Env2}.

%% Report §5.6: the base of `..`, of the constructed type, or, where there
%% is none, every field given.
named_base(#e_constructor{span = Span}, undefined, Missing, _Constructed, Env) ->
    Missing =:= [] orelse
        fail(Span, "missing field" ++ plural(length(Missing)) ++ " "
                   ++ lists:join(", ", [atom_to_list(Field) || Field <- Missing])),
    {undefined, Env};
named_base(Expr, Base, _Missing, Constructed, Env) ->
    {Typed, BaseType, BaseEnv} = infer(Base, Env),
    Label = {constructor_name_span(Expr),
             "a constructor of " ++ ern_types:format(Constructed, BaseEnv#env.type_state)},
    {Typed, unify_at(ern_ast:span(Base), Constructed, BaseType, BaseEnv,
                     "the base of `..` must have the constructor's type", Label)}.

%% A field given in a construction, at the type its constructor declares;
%% one a fill gave (report §5.6) is named with the namespace it came from,
%% and what its requirement is supplied with is the record's to fix.
check_field_set(#field_set{name = FieldName, expr = Value} = FieldSet,
                #e_constructor{name = Name} = Expr, Names, FieldTypes, Fill, Env) ->
    FieldType = lists:nth(index_of(FieldName, Names), FieldTypes),
    {TypedValue, ValueType, Env1} = infer(Value, Env),
    Declares = atom_to_list(Name) ++ " declares " ++ atom_to_list(FieldName) ++ " : "
               ++ declared_field_text(Expr, index_of(FieldName, Names), Env1),
    {Rule, Given} =
        case Fill of
            {Written, Namespace, Filled} ->
                case lists:member(FieldName, Filled) of
                    true ->
                        #e_var{supplies = Supplies} = TypedValue,
                        Need = {fill, atom_to_list(FieldName)},
                        {Written ++ " fills " ++ atom_to_list(FieldName) ++ " with "
                         ++ ern_namespace:text(Namespace ++ [FieldName]),
                         TypedValue#e_var{supplies = [Supply#pending_member{need = Need}
                                                      || Supply <- Supplies]}};
                    false -> {"field " ++ atom_to_list(FieldName), TypedValue}
                end;
            none -> {"field " ++ atom_to_list(FieldName), TypedValue}
        end,
    {FieldSet#field_set{expr = Given},
     unify_at(ern_ast:span(Value), FieldType, ValueType, Env1, Rule,
              {constructor_name_span(Expr), Declares})}.

%% Report §11.5: a field's type as its constructor's declaration writes it,
%% under the type's own parameter names, for the label at a field given.
declared_field_text(#e_constructor{span = Span, namespace = Namespace, name = Name}, Index,
                    Env) ->
    #constructor_info{scheme = #scheme{type = {tfn, Params, _, _}} = Scheme} =
        lookup_constructor(Span, Namespace, Name, Env),
    ern_types:format_scheme(Scheme#scheme{type = lists:nth(Index, Params), requirement = []},
                            Env#env.type_state).

%% The span of a construction's written constructor, `Point` or
%% `Shape.Circle`, which labels what fixed a field's type.
constructor_name_span(#e_constructor{span = Span, namespace = Namespace, name = Name}) ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {Line, Column, {Line, Column + length(ern_namespace:text(Namespace ++ [Name]))}}.

%% Report §5.6: `..` takes the unlisted fields from a value that has them,
%% so its type has one constructor.
one_constructor(Span, #constructor_info{name = Name, type_qualified_name = TypeQualifiedName},
                #env{types = Types} = Env) ->
    case maps:get(TypeQualifiedName, Types) of
        #type_info{constructors = [_]} ->
            true;
        #type_info{constructors = Constructors} ->
            Shown = ern_types:format({tcon, TypeQualifiedName, []}, Env#env.type_state),
            fail(Span, io_lib:format("`..` is allowed only on a type with one constructor, and"
                                     " ~s has ~B", [Shown, length(Constructors)]),
                 [], "give every field of " ++ atom_to_list(Name))
    end.

%% Report §5.6, §5.10: a constructor with named fields as it is written,
%% each field given `Part`: `Point(x = value, y = value)`.
named_form(Name, Fields, Part) ->
    atom_to_list(Name) ++ "("
        ++ lists:join(", ", [atom_to_list(Field) ++ " = " ++ Part || Field <- Fields]) ++ ")".

binop_type(Span, Operator, Left, LeftType, Right, RightType, Env)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*'; Operator =:= '/';
       Operator =:= '%'; Operator =:= '<>' ->
    operator_result(Span, Operator, LeftType,
                    same_operands(Operator, Left, LeftType, Right, RightType, Env));
binop_type(Span, Operator, Left, LeftType, Right, RightType, Env)
  when Operator =:= '=='; Operator =:= '!=' ->
    Env1 = same_operands(Operator, Left, LeftType, Right, RightType, Env),
    Env2 = restrict_equality(Span, LeftType, Env1),
    {?BOOL, Env2};
binop_type(Span, Operator, Left, LeftType, Right, RightType, Env)
  when Operator =:= '<'; Operator =:= '<='; Operator =:= '>'; Operator =:= '>=' ->
    operator_result(Span, Operator, LeftType,
                    same_operands(Operator, Left, LeftType, Right, RightType, Env));
binop_type(_Span, Operator, Left, LeftType, Right, RightType, Env)
  when Operator =:= '&&'; Operator =:= '||' ->
    Text = atom_to_list(Operator),
    Env1 = unify_at(ern_ast:span(Left), ?BOOL, LeftType, Env,
                    "the left operand of `" ++ Text ++ "`"),
    Env2 = unify_at(ern_ast:span(Right), ?BOOL, RightType, Env1,
                    "the right operand of `" ++ Text ++ "`"),
    {?BOOL, Env2};
binop_type(_Span, '::', Left, LeftType, Right, RightType, Env) ->
    ListType = {tcon, ['List'], [LeftType]},
    Env1 = unify_at(ern_ast:span(Right), ListType, RightType, Env,
                    "the right operand of `::` must be a list of the left operand's type",
                    {ern_ast:span(Left), "the left operand has type "
                                         ++ ern_types:format(LeftType, Env#env.type_state)}),
    {ListType, Env1}.

same_operands(Operator, Left, LeftType, Right, RightType, Env) ->
    unify_at(ern_ast:span(Right), LeftType, RightType, Env,
             "both operands of `" ++ atom_to_list(Operator) ++ "` must have the same type",
             {ern_ast:span(Left), "the left operand has type "
                                  ++ ern_types:format(LeftType, Env#env.type_state)}).

%% Report §3.10: == on a type variable records the restriction, and the
%% comparison as where it was needed, so that a later use that makes the
%% type one without equality is reported here; on a concrete type without
%% equality it is an error now.
restrict_equality(Span, Type, Env) ->
    TypeState = Env#env.type_state,
    Substituted = ern_types:substitute(Type, TypeState),
    case lacks_equality(Substituted, Env) of
        false ->
            Variables = ern_types:free_variables(Substituted, TypeState),
            TypeState1 = lists:foldl(fun(Id, Acc) ->
                                         ern_types:add_restriction({tvar, Id}, equality, Acc)
                                     end, TypeState, Variables),
            Compared = [#pending_restriction{restriction = equality, id = Id, span = Span,
                                             need = compared}
                        || Id <- Variables],
            Env#env{type_state = TypeState1, pending = Compared ++ Env#env.pending};
        Lack ->
            fail(Span, "`==` is not defined on " ++ ern_types:format(Substituted, TypeState)
                       ++ ": " ++ Lack ++ identity_hint(Substituted))
    end.

%% Report §3.10, Appendix E.21: where an address is what is compared, the
%% process behind it is what has equality.
identity_hint(Type) ->
    case has_address(Type) of
        true -> "; compare the processes behind addresses, `Process.fromAddress(a)`";
        false -> ""
    end.

has_address({tcon, ['Address'], _}) -> true;
has_address({tcon, _, Args}) -> lists:any(fun has_address/1, Args);
has_address({ttuple, Elements}) -> lists:any(fun has_address/1, Elements);
has_address(_) -> false.

%% Report §3.10: false where a value of the type has equality, and else
%% what it may hold that has none: a function, an address or a reply. A
%% `Foreign` value has the runtime's exact equality (§3.8). A built-in or
%% foreign type holds its arguments, and a declared type its fields with
%% its arguments in place of its parameters.
%% A declared type met again inside its own fields is not read again: what
%% its fields hold of their own is being read already, and what its
%% arguments bring is read in their place. A regression: a declared type's
%% fields were not read, and `Box(f) == Box(f)` compared two functions.
lacks_equality(Type, Env) ->
    lacks(Type, Env, []).

lacks(Type, #env{type_state = TypeState} = Env, Seen) ->
    case ern_types:resolve(Type, TypeState) of
        {tfn, _, _, _} ->
            "it contains a function or an address";
        {tcon, ['Address'], _} ->
            "it contains a function or an address";
        {tcon, ['Reply'], _} ->
            "it contains a function or an address";
        {tcon, QualifiedName, Args} ->
            case {lists:member(QualifiedName, Seen), declared_fields(QualifiedName, Args, Env)} of
                {false, {ok, Fields}} ->
                    Inside = [QualifiedName | Seen],
                    first_lack(fun(Field) -> lacks(Field, Env, Inside) end, Fields);
                _ ->
                    first_lack(fun(Arg) -> lacks(Arg, Env, Seen) end,
                               ern_types:value_args(QualifiedName, Args, TypeState))
            end;
        {ttuple, Elements} ->
            first_lack(fun(Element) -> lacks(Element, Env, Seen) end, Elements);
        _ ->
            false
    end.

first_lack(_, []) ->
    false;
first_lack(Lacks, [Type | Types]) ->
    case Lacks(Type) of
        false -> first_lack(Lacks, Types);
        Lack -> Lack
    end.

%% The field types of a declared type's constructors, its arguments in
%% place of its parameters; none for a built-in or a foreign type. A type
%% with no declaration at all is the toolchain's own defect (report §11.1),
%% and the check fails closed rather than read it as a built-in one.
declared_fields(QualifiedName, Args, Env) ->
    case lookup_type(QualifiedName, Env) of
        #type_info{foreign = false, params = Params, constructors = [_ | _] = Constructors}
          when length(Params) =:= length(Args) ->
            Replacements = maps:from_list([{Id, Arg}
                                           || {{tvar, Id}, Arg} <- lists:zip(Params, Args)]),
            {ok, [ern_types:replace_variables(FieldType, Replacements)
                  || #constructor_info{scheme = #scheme{type = {tfn, FieldTypes, _, _}}}
                         <- Constructors,
                     FieldType <- FieldTypes]};
        #type_info{} ->
            none;
        undefined ->
            erlang:error({undeclared_type, ern_namespace:text(QualifiedName)})
    end.

%% The enclosing function's effect must be a mailbox type here.
mailbox_type(Span, Env) ->
    case ern_types:resolve(Env#env.effect, Env#env.type_state) of
        pure -> fail(Span, "`receive` needs a process, and " ++ what(Env#env.effect_origin)
                           ++ " is pure",
                     labels(Env#env.effect_origin), help(Env#env.effect_origin));
        {tvar, _} = Variable ->
            {Mailbox, TypeState} = ern_types:fresh(Env#env.type_state, [process_only]),
            {Mailbox, bound(Variable, Mailbox, Env#env{type_state = TypeState})};
        Type ->
            {Type, Env}
    end.

check_clauses(Kind, Clauses, ScrutineeType, ScrutineeOrigin, Expected, Rule, Origin,
              SiblingRule, Env) ->
    Check = fun(#clause{body = Body} = Clause, {Acc, RuleAcc, OriginAcc}) ->
                {Typed, Acc1} = check_clause(Kind, Clause, ScrutineeType, ScrutineeOrigin,
                                             Expected, RuleAcc, OriginAcc, Acc),
                {RuleAcc1, OriginAcc1} = sibling(RuleAcc, OriginAcc, SiblingRule, Body,
                                                 "the first clause", Expected, Acc1),
                {Typed, {Acc1, RuleAcc1, OriginAcc1}}
            end,
    {Typed, {Env1, _, _}} = lists:mapfoldl(Check, {Env, Rule, Origin}, Clauses),
    {Typed, Env1}.

%% One clause: its pattern against the scrutinee's type, its guard, and its
%% body against the expected type; what it binds is its own.
check_clause(Kind, #clause{pattern = Pattern, guard = Guard, body = Body} = Clause,
             ScrutineeType, ScrutineeOrigin, Expected, Rule, Origin, Env) ->
    {TypedPattern, PatternType, Bindings, Env1} = check_pattern(Pattern, Env),
    Env2 = unify_at(ern_ast:span(Pattern), ScrutineeType, PatternType, Env1,
                    "the pattern does not fit the value", ScrutineeOrigin),
    Env3 = bind_locals(Bindings, alternatives_agree(TypedPattern, Env2)),
    {TypedGuard, Env4} = check_guard(Kind, Guard, Env3),
    {TypedBody, _, Env5} = check_expr(Body, Expected, Rule, Origin, Env4),
    {Clause#clause{pattern = TypedPattern, guard = TypedGuard, body = TypedBody},
     Env5#env{locals = Env#env.locals}}.

%% Report §5.9: a guard is pure; a receive's is a guard expression (§6.3).
check_guard(_Kind, undefined, Env) ->
    {undefined, Env};
check_guard(Kind, Guard, Env) ->
    Origin = #effect_origin{what = "a guard", span = ern_ast:span(Guard),
                            label = "a guard is pure (§5.9)",
                            help = "compute the value before the match"},
    Guarded = Env#env{effect = pure, effect_origin = Origin},
    {TypedGuard, _, GuardEnv} = check_expr(Guard, ?BOOL, "a guard is a Bool", undefined, Guarded),
    GuardEnv1 = case Kind of
                    'receive' -> receive_guard(TypedGuard, GuardEnv);
                    match -> GuardEnv
                end,
    {TypedGuard, GuardEnv1#env{effect = Env#env.effect, effect_origin = Env#env.effect_origin}}.

%%
%% Blocks (report §5.4, §5.5)
%%

%% Report §5.4: local fn names are visible throughout the block, so each
%% gets a placeholder type up front; its body is checked where it stands,
%% with the earlier `let`s in scope, and generalized there.
%% A local fn is generalized only once every later local fn it references,
%% transitively, has been checked; until then it is monomorphic, as any
%% recursive reference is. Generalizing earlier would close its scheme over
%% variables the later fn still has to pin.
infer_block(Statements, Span, Expect, Env) ->
    Fns = [Statement || #fn_declaration{} = Statement <- Statements],
    FnNames = [Name || #fn_declaration{name = Name} <- Fns],
    one_clause(Statements),
    one_local_fn(Fns, []),
    TypeState1 = ern_types:enter(Env#env.type_state),
    Fresh = fun(#fn_declaration{name = Name}, Acc) ->
                {Placeholder, Acc1} = ern_types:fresh(Acc),
                {{Name, Placeholder}, Acc1}
            end,
    {Placeholders, TypeState2} = lists:mapfoldl(Fresh, TypeState1, Fns),
    Env1 = lists:foldl(fun declare_local_placeholder/2, Env#env{type_state = TypeState2},
                       Placeholders),
    %% the annotations shape the placeholder before any use, as at top
    %% level, at the block's level so that the fn still generalizes
    Env2 = lists:foldl(fun({Declaration, {_, Placeholder}}, Acc) ->
                           signature_shape(Declaration, Placeholder, Acc)
                       end, Env1, lists:zip(Fns, Placeholders)),
    Env3 = Env2#env{type_state = ern_types:leave(Env2#env.type_state)},
    Dependencies = maps:from_list([{Name, ern_scope:free_references(Body, Params, FnNames)
                                          -- [Name]}
                                   || #fn_declaration{name = Name, params = Params, body = Body}
                                          <- Fns]),
    Local = #local_fns{placeholders = maps:from_list(Placeholders),
                       dependencies = Dependencies},
    {Typed, Type, Env4} = infer_statements(Statements, Span, Expect, Env3, Local, []),
    %% every fn is generalized by now; put the schemes on the nodes
    Schemed = [case Statement of
                   #fn_declaration{name = Name} ->
                       Statement#fn_declaration{scheme = maps:get(Name, Env4#env.locals)};
                   _ -> Statement
               end || Statement <- Typed],
    {Schemed, Type, Env4}.

%% A local fn's placeholder in scope, its definition under inference.
declare_local_placeholder({Name, Placeholder}, Env) ->
    Env#env{locals = maps:put(Name, ern_types:monomorphic(Placeholder), Env#env.locals),
            inferring = [{local, Name} | Env#env.inferring]}.

%% Report §4.2, §5.4: a block declares each local fn name once, as a
%% module declares each top-level name once.
one_local_fn([], _Seen) ->
    ok;
one_local_fn([#fn_declaration{span = Span, name = Name} | Rest], Seen) ->
    case lists:keyfind(Name, 1, Seen) of
        {Name, First} ->
            fail(Span, "local function " ++ atom_to_list(Name) ++ " is declared twice in the block",
                 [{ern_diagnostic:span(First), "first declared here"}], undefined);
        false ->
            one_local_fn(Rest, [{Name, Span} | Seen])
    end.

%% The local fns Name depends on, transitively.
transitive_dependencies(Name, #local_fns{dependencies = Dependencies}) ->
    transitive_dependencies([Name], Dependencies, []) -- [Name].

transitive_dependencies([], _Dependencies, Acc) ->
    Acc;
transitive_dependencies([Name | Names], Dependencies, Acc) ->
    case lists:member(Name, Acc) of
        true -> transitive_dependencies(Names, Dependencies, Acc);
        false ->
            transitive_dependencies(maps:get(Name, Dependencies, []) ++ Names, Dependencies,
                                    [Name | Acc])
    end.

%% Generalize every waiting fn whose dependencies are all checked.
release(Env, #local_fns{waiting = Waiting, placeholders = Placeholders,
                        checked = Checked} = Local) ->
    Ready = [Name || Name <- Waiting, (transitive_dependencies(Name, Local) -- Checked) =:= []],
    Generalize = fun(Name, Acc) ->
                     {Generalized, TypeState} =
                         ern_types:generalize(maps:get(Name, Placeholders), Acc#env.type_state),
                     Scheme = with_requirement(Generalized, maps:get(Name, Acc#env.locals),
                                               TypeState),
                     Acc#env{type_state = TypeState,
                             locals = maps:put(Name, Scheme, Acc#env.locals),
                             inferring = lists:delete({local, Name}, Acc#env.inferring)}
                 end,
    Env1 = lists:foldl(Generalize, Env, Ready),
    {Env1, Local#local_fns{waiting = Waiting -- Ready}}.

%% A block ends with an expression, which the parser ensures (report §5.4).
infer_statements([Last], _Span, Expect, Env, _Local, Acc) ->
    {Typed, Type, Env1} = case Expect of
                              undefined -> infer(Last, Env);
                              {ExpectedType, Rule, Origin} ->
                                  check_expr(Last, ExpectedType, Rule, Origin, Env)
                          end,
    {lists:reverse([Typed | Acc]), Type, Env1};
infer_statements([#fn_declaration{span = DeclarationSpan, member_of = MemberOf, name = Name} | _],
                 _Span, _Expect, _Env, _Local, _Acc) when MemberOf =/= undefined ->
    fail(DeclarationSpan, "a member, `fn " ++ local_name(MemberOf, Name)
                          ++ "`, is a top-level form;"
                          " a local function has a plain name");
infer_statements([#fn_declaration{name = Name} = Declaration | Rest], Span, Expect, Env, Local,
                 Acc) ->
    Placeholder = maps:get(Name, Local#local_fns.placeholders),
    Env1 = Env#env{type_state = ern_types:enter(Env#env.type_state)},
    {Checked, Post, CheckedEnv} = check_value(Declaration, Placeholder, Env1),
    {TypedDeclaration, Env2} = post_checks(Checked, Post, CheckedEnv),
    Env3 = Env2#env{type_state = ern_types:leave(Env2#env.type_state)},
    Local1 = Local#local_fns{checked = [Name | Local#local_fns.checked],
                             waiting = [Name | Local#local_fns.waiting]},
    {Env4, Local2} = release(Env3, Local1),
    infer_statements(Rest, Span, Expect, Env4, Local2, [TypedDeclaration | Acc]);
infer_statements([#binding{operator = '='} = Binding | Rest], Span, Expect, Env, Local, Acc) ->
    Continue = fun(Next, Typed) ->
                   infer_statements(Rest, Span, Expect, Next, Local, Typed ++ Acc)
               end,
    case annotated_fallback(Binding, Env) of
        none ->
            {TypedBinding, Env1} = let_binding(Binding, Env),
            Continue(Env1, [TypedBinding]);
        {ok, Fallback} ->
            %% report §11.5: the annotation fixes the name's type whatever
            %% the value is, so nothing after depends on the value's error
            try let_binding(Binding, Env) of
                {TypedBinding, Env1} -> Continue(Env1, [TypedBinding])
            catch
                throw:{type_error, _, _} = Thrown ->
                    recovered(Thrown, fun() -> Continue(Fallback, []) end);
                throw:{type_error, _} = Thrown ->
                    recovered(Thrown, fun() -> Continue(Fallback, []) end);
                throw:{type_errors, _} = Thrown ->
                    recovered(Thrown, fun() -> Continue(Fallback, []) end)
            end
    end;
infer_statements([#binding{span = BindingSpan, pattern = Pattern, annotation = Annotation,
                           operator = '<-', expr = Expr} = Binding | Rest],
                 Span, Expect, Env, Local, Acc) ->
    %% report §5.5: e : Either(err, a) binds p : a; the rest is Either(err, _).
    %% Which sum type is decided at the end of the definition (solve_deferred).
    {TypedExpr, ExprType, Env1} = infer(Expr, Env),
    {TypedPattern, PatternType, Bindings, Env2} = check_pattern(Pattern, Env1),
    irrefutable(Pattern, Env2) orelse fail(BindingSpan, "a `let` pattern must be irrefutable", [],
                                           "use `match` for a pattern that can fail"),
    Annotated = case Annotation of
                    undefined -> Env2;
                    _ ->
                        {AnnotationType, _, TypeState} =
                            annotation_type(Annotation, Env2#env.annotation_variables, Env2),
                        unify_at(BindingSpan, AnnotationType, PatternType,
                                 Env2#env{type_state = TypeState},
                                 "the value does not have the declared type")
                end,
    Spans = {ern_ast:span(Pattern), ern_ast:span(Expr)},
    Env3 = known_bind_arrow(BindingSpan, Spans, ExprType, PatternType, Annotated),
    Env4 = bind_locals(Bindings, Env3),
    {TypedRest, RestType, Env5} = infer_statements(Rest, Span, Expect, Env4, Local, []),
    %% report §11.5: what fixed the block's type, the annotation that did,
    %% or else the block's last expression
    Fixed = case Expect of
                {_, _, {_, _} = Origin} -> Origin;
                _ -> {last, lists:last(Rest)}
            end,
    Deferred = #deferred_bind_arrow{span = BindingSpan, spans = Spans, expr_type = ExprType,
                                    pattern_type = PatternType, rest_type = RestType,
                                    fixed = Fixed},
    Env6 = Env5#env{deferred = [Deferred | Env5#env.deferred]},
    TypedBinding = Binding#binding{pattern = TypedPattern, expr = TypedExpr},
    {lists:reverse(Acc) ++ [TypedBinding | TypedRest], RestType, Env6};
infer_statements([Expr | Rest], Span, Expect, Env, Local, Acc) ->
    %% report §11.5: a statement binds nothing, so the rest of its block is
    %% checked after its error too
    Continue = fun(Next, Typed) ->
                   infer_statements(Rest, Span, Expect, Next, Local, Typed ++ Acc)
               end,
    try
        {Typed, Type, Env1} = infer(Expr, Env),
        {Typed, statement_unit(Expr, Type, Env1)}
    of
        {TypedExpr, Env2} -> Continue(Env2, [TypedExpr])
    catch
        throw:{type_error, _, _} = Thrown -> recovered(Thrown, fun() -> Continue(Env, []) end);
        throw:{type_error, _} = Thrown -> recovered(Thrown, fun() -> Continue(Env, []) end);
        throw:{type_errors, _} = Thrown -> recovered(Thrown, fun() -> Continue(Env, []) end)
    end.

%% Report §11.5, §5.5: a `<-` whose value's sum type is known as it is read
%% is checked there, the value and the pattern inside it, so that an error
%% in it stops its block before what follows uses its names or settles its
%% types; one whose sum type is still open waits for the end of the
%% definition (solve_one), which checks the rest against the block.
known_bind_arrow(Span, {PatternSpan, ExprSpan}, ExprType, PatternType, Env) ->
    TypeState = Env#env.type_state,
    Inside = fun(ValueType) ->
                 unify_at(PatternSpan, ValueType, PatternType, Env,
                          "the pattern does not fit the value inside the sum type",
                          {ExprSpan, "the value inside has type "
                                     ++ ern_types:format(ValueType, TypeState)})
             end,
    case ern_types:resolve(ExprType, TypeState) of
        {tcon, ['Either'], [_, ValueType]} -> Inside(ValueType);
        {tcon, ['Optional'], [ValueType]} -> Inside(ValueType);
        {tvar, _} -> Env;
        Other -> fail(Span, "`<-` needs an Either or an Optional, not "
                            ++ ern_types:format(Other, TypeState))
    end.

%% Report §4.6: a block's `let p = e` checked: the binding as typed, and the
%% environment with its names bound.
let_binding(#binding{span = BindingSpan, pattern = Pattern, annotation = Annotation,
                     expr = Expr} = Binding, Env) ->
    %% report §4.6: a `let` of a lambda to a name is generalized, as a local
    %% `fn` is; any other block binding is not
    Generalize = is_record(Pattern, p_var) andalso is_record(Expr, e_lambda),
    Scoped = case Generalize of
                 true ->
                     Entered = ern_types:enter(Env#env.type_state),
                     Env#env{type_state = Entered, generalizing = true};
                 false -> Env
             end,
    {TypedExpr, ExprType, Env1} =
        case Annotation of
            undefined -> infer(Expr, Scoped);
            _ -> annotated_value(BindingSpan, Annotation, Expr, Generalize, Scoped)
        end,
    {TypedPattern, PatternType, Bindings, Env2} = check_pattern(Pattern, Env1),
    irrefutable(Pattern, Env2) orelse fail(BindingSpan, "a `let` pattern must be irrefutable", [],
                                           "use `match` for a pattern that can fail"),
    Env3 = unify_at(ern_ast:span(Pattern), ExprType, PatternType, Env2,
                    "the pattern does not fit the value",
                    {ern_ast:span(Expr), "the value has type "
                                         ++ ern_types:format(ExprType, Env2#env.type_state)}),
    Env4 = case Generalize of
               true ->
                   %% report §3.9: the lambda's variables take their
                   %% restrictions before they are generalized
                   #e_lambda{params = LambdaParams, body = LambdaBody} = TypedExpr,
                   Restricted = ern_reply:restrict(LambdaParams, LambdaBody, ExprType, Env3),
                   TypeState1 = ern_types:leave(Restricted#env.type_state),
                   {Scheme, TypeState2} = ern_types:generalize(ExprType, TypeState1),
                   #p_var{name = Name} = Pattern,
                   Env3#env{type_state = TypeState2, generalizing = false,
                            locals = maps:put(Name, Scheme, Env3#env.locals)};
               false ->
                   bind_locals(Bindings, Env3)
           end,
    {Binding#binding{pattern = TypedPattern, expr = TypedExpr}, Env4}.

%% Report §3.9: a block binding's value against its annotation. The
%% definition's annotation variables are in scope and rigid; a name new
%% here means every type, and only a generalized binding may name one.
annotated_value(BindingSpan, Annotation, Expr, Generalize, Env) ->
    {AnnotationType, AnnotationVariables, TypeState} =
        annotation_type(Annotation, Env#env.annotation_variables, Env),
    New = [{Name, Variable} || Name := Variable <- AnnotationVariables,
                               not is_map_key(Name, Env#env.annotation_variables)],
    case {New, Generalize} of
        {[_ | _], false} ->
            fail(BindingSpan,
                 "type variable " ++ atom_to_list(lists:min([Name || {Name, _} <- New]))
                 ++ " in the annotation means every type, and a `let` in a block is"
                 " generalized only over a lambda", [],
                 "write the type, or leave the annotation out");
        _ ->
            ok
    end,
    Annotated = Env#env{type_state = TypeState, annotation_variables = AnnotationVariables,
                        rigid = New ++ Env#env.rigid},
    Origin = annotation_origin(Annotation, AnnotationType, Annotated),
    {TypedValue, ValueType, Checked} =
        check_expr(Expr, AnnotationType, "the value does not have the declared type", Origin,
                   Annotated),
    rigid_annotation_variables(BindingSpan, New, Checked),
    {TypedValue, ValueType,
     Checked#env{annotation_variables = Env#env.annotation_variables, rigid = Env#env.rigid}}.

%% Report §11.5: a `let x : T = e` binds x at T whatever e's error, so the
%% rest of its block is checked with x at T; any other binding's error may
%% be the cause of one after it, and the block stops there. A lambda's
%% annotation may name variables of its own, and is not taken so.
annotated_fallback(#binding{pattern = #p_var{name = Name}, annotation = Annotation,
                            expr = Expr}, Env)
  when Annotation =/= undefined, not is_record(Expr, e_lambda) ->
    try annotation_type(Annotation, Env#env.annotation_variables, Env) of
        {AnnotationType, AnnotationVariables, TypeState}
          when map_size(AnnotationVariables) =:= map_size(Env#env.annotation_variables) ->
            {ok, bind_locals([{Name, AnnotationType}], Env#env{type_state = TypeState})};
        _ ->
            none
    catch
        throw:_ -> none
    end;
annotated_fallback(_, _) ->
    none.

%% Report §11.5: a statement's error, then those the rest of the block has
%% of its own, checked as though the statement had failed silently; the
%% definition fails with them all.
-spec recovered(term(), fun(() -> term())) -> no_return().
recovered(Thrown, Rest) ->
    Later = try Rest() of
                _ -> []
            catch
                throw:{type_error, _, _} = LaterThrown -> diagnostics(LaterThrown);
                throw:{type_error, _} = LaterThrown -> diagnostics(LaterThrown);
                throw:{type_errors, _} = LaterThrown -> diagnostics(LaterThrown)
            end,
    throw({type_errors, diagnostics(Thrown) ++ Later}).

diagnostics({type_error, Span, Message}) -> [diagnostic(Span, Message)];
diagnostics({type_error, #diagnostic{} = Diagnostic}) -> [Diagnostic];
diagnostics({type_errors, Diagnostics}) -> Diagnostics.

%% Report §5.4: an expression that is not a block's last statement has type
%% Unit, so no value is dropped unseen; §11.5 reports it whole.
statement_unit(Expr, Type, #env{type_state = TypeState, rigid = Rigid} = Env) ->
    %% a rigid annotation variable (§3.9) is no Unit either
    Unified = case ern_types:unify(?UNIT, Type, TypeState) of
                  {ok, UnitState} ->
                      case rigid_kept(Rigid, UnitState) orelse not rigid_kept(Rigid, TypeState) of
                          true -> {ok, UnitState};
                          false -> rigid
                      end;
                  Error -> Error
              end,
    case Unified of
        {ok, TypeState1} -> Env#env{type_state = TypeState1};
        _ ->
            fail(ern_ast:span(Expr), "this statement's value is discarded: expected Unit, found "
                                     ++ ern_types:format(Type, TypeState), [],
                 "`let _ = ...` discards it on purpose")
    end.

%%
%% Patterns: check_pattern(Pattern, Env) -> {TypedPattern, Type, Bindings, Env}
%%

check_pattern(Pattern, Env) ->
    sizes_see_no_sibling(Pattern, Env),
    {TypedPattern, Type, Bindings, Env1} = infer_pattern(Pattern, Env),
    Names = [Name || {Name, _} <- Bindings],
    case Names -- lists:usort(Names) of
        [] -> ok;
        [Repeated | _] ->
            %% report §11.5: at the second, the first labelled; a name
            %% after `as` binds as a variable does
            [First, Second | _] = [Span || {Name, Span, _} <- ern_ast:pattern_binders(Pattern),
                                           Name =:= Repeated],
            fail(Second, "variable " ++ atom_to_list(Repeated) ++ " appears twice in the pattern",
                 [{ern_diagnostic:span(First), "first bound here"}], undefined)
    end,
    {TypedPattern, Type, Bindings, Env1}.

%% Report §5.9: the alternatives bind each variable at one type, checked
%% once the clause's pattern has met the value's type.
alternatives_agree(#p_or{alternatives = [First | Rest]}, Env) ->
    Bindings = ern_ast:pattern_bindings(First),
    lists:foldl(fun(Alternative, Acc) ->
                    lists:foldl(fun(Binding, InnerAcc) ->
                                    agree(Binding, Alternative, First, Bindings, InnerAcc)
                                end, Acc, ern_ast:pattern_bindings(Alternative))
                end, Env, Rest);
alternatives_agree(_, Env) ->
    Env.

%% One name an alternative binds, at the type the first alternative binds
%% it at.
agree({Name, ThisType}, Alternative, First, Bindings, Env) ->
    {Name, FirstType} = lists:keyfind(Name, 1, Bindings),
    Label = atom_to_list(Name) ++ " is bound here at "
            ++ ern_types:format(FirstType, Env#env.type_state),
    unify_at(binds_at(Name, Alternative), FirstType, ThisType, Env,
             "the alternatives bind `" ++ atom_to_list(Name) ++ "` at one type",
             {binds_at(Name, First), Label}).

%% Where a pattern binds the variable Name.
binds_at(Name, Pattern) ->
    hd([Span || {Bound, Span, _} <- ern_ast:pattern_binders(Pattern), Bound =:= Name]).

-spec alternatives_differ(ern_diagnostic:span(), [atom()], [atom()]) -> no_return().
alternatives_differ(Span, Names, AlternativeNames) ->
    Text = case Names -- AlternativeNames of
               [Name | _] -> "`" ++ atom_to_list(Name) ++ "` is bound by the first alternative"
                             " and not by this one";
               [] -> [Name | _] = AlternativeNames -- Names,
                     "`" ++ atom_to_list(Name) ++ "` is bound by this alternative and not by"
                     " the first"
           end,
    %% report §5.10: `as` names what one alternative matches, and `or` stands
    %% between whole patterns, so each alternative names the value itself
    fail(Span, "the alternatives of a clause bind different variables: " ++ Text, [],
         "bind each name in every alternative, as `Some(1) as x or Some(2) as x`").

infer_pattern(#p_wildcard{} = Pattern, Env) ->
    {Type, TypeState} = ern_types:fresh(Env#env.type_state),
    {Pattern#p_wildcard{type = Type}, Type, [], Env#env{type_state = TypeState}};
infer_pattern(#p_var{name = Name} = Pattern, Env) ->
    {Type, TypeState} = ern_types:fresh(Env#env.type_state),
    {Pattern#p_var{type = Type}, Type, [{Name, Type}], Env#env{type_state = TypeState}};
infer_pattern(#p_literal{kind = Kind} = Pattern, Env) ->
    Type = literal_type(Kind),
    {Pattern#p_literal{type = Type}, Type, [], Env};
infer_pattern(#p_constructor{span = Span, namespace = Namespace, name = Name,
                             args = Args} = Pattern, Env) ->
    ConstructorInfo = lookup_constructor(Span, Namespace, Name, Env),
    {ConstructorType, TypeState} =
        ern_types:instantiate(ConstructorInfo#constructor_info.scheme, Env#env.type_state),
    Env1 = Env#env{type_state = TypeState},
    case {ConstructorInfo#constructor_info.fields, Args} of
        {none, none} ->
            {Pattern#p_constructor{type = ConstructorType}, ConstructorType, [], Env1};
        {none, _} ->
            fail(Span, atom_to_list(Name) ++ " takes no fields");
        {positional, {positional, SubPattern}} ->
            {tfn, [FieldType], pure, Constructed} = ConstructorType,
            {TypedSubPattern, SubType, Bindings, Env2} = infer_pattern(SubPattern, Env1),
            Env3 = unify_at(Span, FieldType, SubType, Env2, "the field of " ++ atom_to_list(Name)),
            {Pattern#p_constructor{args = {positional, TypedSubPattern}, type = Constructed},
             Constructed, Bindings, Env3};
        {positional, _} ->
            fail(Span, atom_to_list(Name) ++ " has one positional field; write "
                       ++ atom_to_list(Name) ++ "(p)");
        {{named, Names}, {named, FieldPatterns}} ->
            {tfn, FieldTypes, pure, Constructed} = ConstructorType,
            twice([{FieldName, FieldSpan}
                   || #field_pattern{span = FieldSpan, name = FieldName} <- FieldPatterns],
                  "matched"),
            Check = fun(FieldPattern, Acc) ->
                        check_field_pattern(FieldPattern, Name, Names, FieldTypes, Acc)
                    end,
            {Typed, Env2} = lists:mapfoldl(Check, Env1, FieldPatterns),
            {TypedFieldPatterns, Bindings} = lists:unzip(Typed),
            {Pattern#p_constructor{args = {named, TypedFieldPatterns}, type = Constructed},
             Constructed, lists:append(Bindings), Env2};
        {{named, _}, none} ->
            %% report §5.10: a constructor with named fields is written with
            %% its parentheses, `C()` matching any value of it
            Text = atom_to_list(Name),
            fail(Span, Text ++ " has named fields; write " ++ Text ++ "() to match any " ++ Text);
        {{named, Names}, _} ->
            fail(Span, atom_to_list(Name) ++ " has named fields; write "
                       ++ named_form(Name, Names, "p"))
    end;
infer_pattern(#p_tuple{elements = Elements} = Pattern, Env) ->
    Infer = fun(Element, Acc) ->
                {TypedElement, Type, ElementBindings, Acc1} = infer_pattern(Element, Acc),
                {{TypedElement, Type, ElementBindings}, Acc1}
            end,
    {Typed, Env1} = lists:mapfoldl(Infer, Env, Elements),
    {TypedElements, Types, Bindings} = lists:unzip3(Typed),
    Type = {ttuple, Types},
    {Pattern#p_tuple{elements = TypedElements, type = Type}, Type, lists:append(Bindings), Env1};
infer_pattern(#p_list{elements = Elements} = Pattern, Env) ->
    {ElementType, TypeState} = ern_types:fresh(Env#env.type_state),
    Infer = fun(Element, {Acc, Origin}) ->
                {TypedElement, Type, ElementBindings, Acc1} = infer_pattern(Element, Acc),
                Acc2 = case Origin of
                           undefined -> bound(ElementType, Type, Acc1);
                           _ -> unify_at(ern_ast:span(Element), ElementType, Type, Acc1,
                                         "list elements must have one type", Origin)
                       end,
                {{TypedElement, ElementBindings},
                 {Acc2, first_origin(Origin, Element, ElementType, Acc2)}}
            end,
    {Typed, {Env1, _}} =
        lists:mapfoldl(Infer, {Env#env{type_state = TypeState}, undefined}, Elements),
    {TypedElements, Bindings} = lists:unzip(Typed),
    Type = {tcon, ['List'], [ElementType]},
    {Pattern#p_list{elements = TypedElements, type = Type}, Type, lists:append(Bindings), Env1};
infer_pattern(#p_cons{head = Head, tail = Tail} = Pattern, Env) ->
    {TypedHead, HeadType, HeadBindings, Env1} = infer_pattern(Head, Env),
    {TypedTail, TailType, TailBindings, Env2} = infer_pattern(Tail, Env1),
    Type = {tcon, ['List'], [HeadType]},
    Env3 = unify_at(ern_ast:span(Tail), Type, TailType, Env2,
                    "the tail of `::` must be a list of the head's type",
                    {ern_ast:span(Head), "the head has type "
                                         ++ ern_types:format(HeadType, Env2#env.type_state)}),
    {Pattern#p_cons{head = TypedHead, tail = TypedTail, type = Type}, Type,
     HeadBindings ++ TailBindings, Env3};
infer_pattern(#p_as{pattern = SubPattern, name = Name} = Pattern, Env) ->
    {TypedSubPattern, Type, Bindings, Env1} = infer_pattern(SubPattern, Env),
    {Pattern#p_as{pattern = TypedSubPattern, type = Type}, Type, Bindings ++ [{Name, Type}], Env1};
infer_pattern(#p_or{alternatives = [First | Rest]} = Pattern, Env) ->
    %% report §5.9: every alternative binds the same variables at the same types
    {TypedFirst, Type, Bindings, Env1} = check_pattern(First, Env),
    Names = lists:sort([Name || {Name, _} <- Bindings]),
    Check = fun(Alternative, Acc) -> check_alternative(Alternative, First, Type, Names, Acc) end,
    {TypedRest, Env2} = lists:mapfoldl(Check, Env1, Rest),
    {Pattern#p_or{alternatives = [TypedFirst | TypedRest], type = Type}, Type, Bindings, Env2};
infer_pattern(#p_bitstring{span = Span, segments = Segments} = Pattern, Env) ->
    %% report §5.11: each segment pattern in turn, the size expressions in
    %% the scope of the earlier segments' variables
    Infer = fun(Segment, {Earlier, Acc}) ->
                {TypedSegment, SegmentBindings, Acc1} = bit_pattern(Segment, Earlier, Acc),
                {TypedSegment, {Earlier ++ SegmentBindings, Acc1}}
            end,
    {TypedSegments, {Bindings, Env1}} = lists:mapfoldl(Infer, {[], Env}, Segments),
    alignment(Span, TypedSegments, "the pattern"),
    last_sizeless(TypedSegments),
    {Pattern#p_bitstring{segments = TypedSegments, type = ?BYTES}, ?BYTES, Bindings, Env1}.

%% A field matched in a pattern, at the type its constructor declares.
check_field_pattern(#field_pattern{span = FieldSpan, name = FieldName,
                                   pattern = SubPattern} = FieldPattern,
                    Name, Names, FieldTypes, Env) ->
    lists:member(FieldName, Names) orelse
        fail(FieldSpan, atom_to_list(Name) ++ " has no field " ++ atom_to_list(FieldName)),
    FieldType = lists:nth(index_of(FieldName, Names), FieldTypes),
    {TypedSubPattern, SubType, SubBindings, Env1} = infer_pattern(SubPattern, Env),
    Env2 = unify_at(FieldSpan, FieldType, SubType, Env1, "field " ++ atom_to_list(FieldName)),
    {{FieldPattern#field_pattern{pattern = TypedSubPattern}, SubBindings}, Env2}.

%% Report §5.9: an alternative after the first, of its type and binding its
%% names.
check_alternative(Alternative, First, Type, Names, Env) ->
    {TypedAlternative, AlternativeType, AlternativeBindings, Env1} =
        check_pattern(Alternative, Env),
    Label = {ern_ast:span(First),
             "the first alternative has type " ++ ern_types:format(Type, Env1#env.type_state)},
    Env2 = unify_at(ern_ast:span(Alternative), Type, AlternativeType, Env1,
                    "the alternatives of a clause match one type", Label),
    AlternativeNames = lists:sort([Name || {Name, _} <- AlternativeBindings]),
    AlternativeNames =:= Names
        orelse alternatives_differ(ern_ast:span(Alternative), Names, AlternativeNames),
    {TypedAlternative, Env2}.

%% Report §5.11: a segment's value against its specifiers' type.
bit_segment(#bit_segment{span = Span, value = SegmentValue, specs = Specs} = Segment,
            construct, Env) ->
    Spec = spec_of(Span, Specs),
    case SegmentValue of
        #e_literal{kind = Kind, value = Value} -> literal_fits(SegmentValue, Kind, Value, Spec);
        #e_negation{expr = #e_literal{kind = Kind, value = Value}} ->
            literal_fits(SegmentValue, Kind, -Value, Spec);
        _ -> ok
    end,
    {TypedSpecs, Env1} = check_sizes(Specs, Env),
    {TypedValue, _, Env2} =
        check_expr(SegmentValue, segment_type(Spec), segment_rule(Spec), undefined, Env1),
    {Segment#bit_segment{value = TypedValue, specs = TypedSpecs}, Env2}.

bit_pattern(#bit_segment{span = Span, value = SegmentValue, specs = Specs} = Segment,
            Bindings, Env) ->
    Spec = spec_of(Span, Specs),
    case SegmentValue of
        #p_var{} -> ok;
        #p_wildcard{} -> ok;
        #p_literal{kind = Kind, value = Value} -> literal_fits(SegmentValue, Kind, Value, Spec);
        _ -> fail(ern_ast:span(SegmentValue), "a segment pattern is a variable, `_`, or a literal")
    end,
    %% a size expression is pure and sees the earlier segments (report §5.11)
    Origin = #effect_origin{what = "a size expression", span = Span,
                            label = "a size expression is pure",
                            help = "compute the size before the match"},
    Scoped = bind_locals(Bindings, Env#env{effect = pure, effect_origin = Origin}),
    {TypedSpecs, Scoped1} = check_sizes(Specs, Scoped),
    lists:foreach(fun({size, SizeExpr}) -> size_shape(SizeExpr, Scoped1);
                     (_) -> ok
                  end, TypedSpecs),
    Env1 = Scoped1#env{locals = Env#env.locals, effect = Env#env.effect,
                       effect_origin = Env#env.effect_origin},
    {TypedValue, ValueType, ValueBindings, Env2} = infer_pattern(SegmentValue, Env1),
    Env3 = unify_at(ern_ast:span(SegmentValue), segment_type(Spec), ValueType, Env2,
                    segment_rule(Spec)),
    {Segment#bit_segment{value = TypedValue, specs = TypedSpecs}, ValueBindings, Env3}.

%% Report §5.11: a literal the compiler sees not fitting a segment of
%% constant width is a compile-time error, in a construction and in a
%% pattern, which it would never match; any other value is checked at
%% construction, as the runtime's ern_bits checks it.
literal_fits(Literal, int, Value, #{kind := int, size := {const, Bits}, sign := Sign}) ->
    {Signedness, Low, High} =
        case Sign of
            unsigned -> {"an unsigned", 0, (1 bsl Bits) - 1};
            signed -> {"a signed", -(1 bsl (Bits - 1)), (1 bsl (Bits - 1)) - 1}
        end,
    (Value >= Low andalso Value =< High)
        orelse fail(ern_ast:span(Literal),
                    io_lib:format("the literal does not fit ~s segment of ~B bits, which holds"
                                  " ~B to ~B", [Signedness, Bits, Low, High]));
literal_fits(Literal, float, Value, #{kind := float, size := {const, Bits}}) ->
    Largest = case Bits of
                  16 -> 65504.0;
                  32 -> 3.4028234663852886e38;
                  64 -> infinity
              end,
    (Largest =:= infinity orelse abs(Value) =< Largest)
        orelse fail(ern_ast:span(Literal),
                    io_lib:format("the literal does not fit a float segment of ~B bits, whose"
                                  " largest finite value is ~s",
                                  [Bits, float_to_list(Largest, [short])]));
literal_fits(_, _, _, _) ->
    ok.

check_sizes(Specs, Env) ->
    lists:mapfoldl(fun({size, SizeExpr}, Acc) ->
                           {TypedSize, _, Acc1} =
                               check_expr(SizeExpr, ?INT, "the size of a segment", undefined, Acc),
                           {{size, TypedSize}, Acc1};
                      (Other, Acc) ->
                           {Other, Acc}
                   end, Env, Specs).

%% Report §5.11: a size in a pattern is a variable, a top-level `let`, a
%% literal, or +, -, * of them, since the runtime evaluates it while
%% matching; the `match` or `receive` reads a top-level `let` before it.
size_shape(Expr, Env) ->
    size_expression(Expr, Env) orelse
        fail(ern_ast:span(Expr), "a size in a pattern is a variable, a top-level `let`, an Int"
                                 " literal, or `+`, `-`, `*` of them").

size_expression(#e_literal{kind = int}, _) -> true;
size_expression(#e_var{namespace = [], name = Name}, #env{locals = Locals})
  when is_map_key(Name, Locals) ->
    true;
size_expression(#e_var{referent = Referent}, Env) -> is_top_let(Referent, Env);
size_expression(#e_negation{expr = Operand}, Env) -> size_expression(Operand, Env);
size_expression(#e_binop{operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '+'; Operator =:= '-'; Operator =:= '*' ->
    size_expression(Left, Env) andalso size_expression(Right, Env);
size_expression(_, _) -> false.

%% Report §5.11: a variable bound elsewhere in the same pattern is not in
%% scope in its sizes, only one an earlier segment of the same bitstring
%% binds; a size that names one is refused as such, where it would
%% otherwise be an unknown name.
sizes_see_no_sibling(Pattern, Env) ->
    Bound = [{Name, Span} || {Name, Span, _} <- ern_ast:pattern_binders(Pattern)],
    Check = fun(#bit_segment{value = SegmentValue, specs = Specs}, Earlier) ->
                [sibling_size(Variable, Bound, Earlier, Env)
                 || {size, Size} <- Specs,
                    Variable <- ern_ast:walk(fun size_variables/2, Size, [])],
                Own = #{Name => true || #p_var{name = Name} <- [SegmentValue]},
                maps:merge(Earlier, Own)
            end,
    ern_ast:walk(fun(#p_bitstring{segments = Segments}, ok) ->
                         lists:foldl(Check, #{}, Segments),
                         ok;
                    (_, ok) ->
                         ok
                 end, Pattern, ok).

size_variables(#e_var{namespace = [], name = _} = Variable, Acc) -> Acc ++ [Variable];
size_variables(_, Acc) -> Acc.

sibling_size(#e_var{span = Span, name = Name}, Bound, Earlier, Env) ->
    case lists:keyfind(Name, 1, Bound) of
        {Name, BoundSpan} when not is_map_key(Name, Earlier) ->
            NameText = atom_to_list(Name),
            is_known_name(Name, Env) orelse
                fail(Span, NameText ++ " is bound in the same pattern, and a size names a variable"
                           " an earlier segment of its bitstring binds, or one bound before the"
                           " pattern",
                     [{ern_diagnostic:span(BoundSpan), NameText ++ " is bound here"}],
                     "match the bitstring in a `match` of its own, once " ++ NameText
                     ++ " is bound");
        _ ->
            true
    end.

%% Whether an unqualified name is bound where the pattern stands.
is_known_name(Name, #env{locals = Locals, local_values = LocalValues, globals = Globals} = Env) ->
    is_map_key(Name, Locals) orelse is_map_key(Name, LocalValues)
        orelse is_map_key([Name], Globals) orelse session_name(values, Name, Env) =/= error.

segment_type(#{kind := int}) -> ?INT;
segment_type(#{kind := float}) -> ?FLOAT;
segment_type(#{kind := Kind}) when Kind =:= utf8; Kind =:= utf16; Kind =:= utf32 -> ?CHAR;
segment_type(_) -> ?BYTES.

segment_rule(#{kind := Kind})
  when Kind =:= int; Kind =:= utf8; Kind =:= utf16; Kind =:= utf32 ->
    "an `" ++ atom_to_list(Kind) ++ "` segment";
segment_rule(#{kind := Kind}) -> "a `" ++ atom_to_list(Kind) ++ "` segment".

spec_of(Span, Specs) ->
    case ern_bitspec:spec(Specs) of
        {ok, Spec} -> Spec;
        {error, Message} -> fail(Span, Message)
    end.

%% Report §5.11: a bit count that is constant and not a multiple of 8 is
%% an error. A segment with a dynamic size counted in bits, an `int` or a
%% `float` one, leaves the count open; one in octets keeps it.
alignment(Span, Segments, What) ->
    Count = fun(#bit_segment{specs = Specs}, {BitsAcc, OpenAcc}) ->
                {ok, #{size := Size, unit := Unit}} = ern_bitspec:spec(Specs),
                case Size of
                    {const, Width} -> {BitsAcc + Width * Unit, OpenAcc};
                    {expr, _} when Unit rem 8 =:= 0 -> {BitsAcc, OpenAcc};
                    {expr, _} -> {BitsAcc, true};
                    none -> {BitsAcc, OpenAcc}
                end
            end,
    {Bits, Open} = lists:foldl(Count, {0, false}, Segments),
    case not Open andalso Bits rem 8 =/= 0 of
        true ->
            fail(Span, What ++ " is " ++ integer_to_list(Bits) ++ " bits, not a multiple of 8");
        false ->
            ok
    end.

%% A `bytes` segment without a size takes the rest, so it is last.
last_sizeless([]) -> ok;
last_sizeless([_]) -> ok;
last_sizeless([#bit_segment{span = Span, specs = Specs} | Rest]) ->
    case ern_bitspec:spec(Specs) of
        {ok, #{kind := bytes, size := none}} ->
            fail(Span, "a `bytes` segment without a size takes the rest, so it is the last"
                       " segment");
        _ -> last_sizeless(Rest)
    end.

%% Report §5.10.
irrefutable(#p_wildcard{}, _) -> true;
irrefutable(#p_var{}, _) -> true;
irrefutable(#p_as{pattern = Pattern}, Env) -> irrefutable(Pattern, Env);
irrefutable(#p_tuple{elements = Elements}, Env) ->
    lists:all(fun(Element) -> irrefutable(Element, Env) end, Elements);
irrefutable(#p_constructor{span = Span, namespace = Namespace, name = Name, args = Args}, Env) ->
    #constructor_info{type_qualified_name = TypeQualifiedName} =
        lookup_constructor(Span, Namespace, Name, Env),
    #type_info{constructors = Constructors} = maps:get(TypeQualifiedName, Env#env.types),
    length(Constructors) =:= 1 andalso
        case Args of
            none -> true;
            {positional, Pattern} -> irrefutable(Pattern, Env);
            {named, FieldPatterns} ->
                lists:all(fun(#field_pattern{pattern = Pattern}) -> irrefutable(Pattern, Env) end,
                          FieldPatterns)
        end;
irrefutable(_, _) -> false.

%%
%% Name lookup (report §4.2)
%%

%% A name's scheme, what it refers to (the referent of #e_var{}), and the
%% environment, since a local name whose group has not run is checked on
%% demand. An unqualified name is the innermost of the names bound around
%% it, then the module's declaration (report §4.2).
lookup_value(Span, [], Name, #env{locals = Locals, local_values = LocalValues} = Env) ->
    case {Locals, LocalValues} of
        {#{Name := Scheme}, _} -> {Scheme, var, Env};
        {_, #{Name := QualifiedName}} -> local_global(QualifiedName, Env);
        _ -> lookup_outside(Span, Name, Env)
    end;
lookup_value(Span, ['Prelude'], Name,
             #env{globals = Globals, locals = Locals, local_values = LocalValues} = Env) ->
    %% report §4.2: `Prelude.x` is the prelude's x, where a binding or a
    %% declaration of the module's hides it
    case Globals of
        #{[Name] := Scheme} ->
            hidden(Span, [Name], is_map_key(Name, Locals) orelse is_map_key(Name, LocalValues)
                                 orelse session_name(values, Name, Env) =/= error),
            {Scheme, {prelude, [Name]}, Env};
        _ ->
            fail(Span, "the prelude declares no " ++ atom_to_list(Name))
    end;
lookup_value(Span, ['Prelude', TypeName], Name, #env{provided = Provided} = Env) ->
    %% report §4.2: `Prelude.T.name` is the name of T, a namespace of the
    %% prelude or the standard library, past a member of the same name that
    %% a type T of the module's own declares
    lists:member(TypeName, Provided) orelse prelude_one(Span, ['Prelude', TypeName], Name),
    hidden(Span, [TypeName, Name], own_member(TypeName, Name, Env) =/= error),
    lookup_global(Span, [TypeName], Name, Env);
lookup_value(Span, ['Prelude' | _] = Namespace, Name, _Env) ->
    prelude_one(Span, Namespace, Name);
lookup_value(Span, [MemberOf] = Namespace, Name, #env{namespace = OwnNamespace,
                                                      local_values = LocalValues} = Env) ->
    case LocalValues of
        #{{MemberOf, Name} := QualifiedName} -> local_global(QualifiedName, Env);
        #{Name := QualifiedName} when Namespace =:= OwnNamespace ->
            own_qualified(Span, Namespace, Name, Env),
            local_global(QualifiedName, Env);
        _ ->
            case session_name(values, {MemberOf, Name}, Env) of
                {ok, QualifiedName} -> session_global(QualifiedName, Name, Env);
                error -> lookup_global(Span, Namespace, Name, Env)
            end
    end;
lookup_value(Span, Namespace, Name,
             #env{namespace = OwnNamespace, local_values = LocalValues} = Env) ->
    %% report §4.2: a module may name its own declarations qualified where a
    %% binding hides the plain name
    case Namespace =:= OwnNamespace of
        true ->
            case LocalValues of
                #{Name := QualifiedName} ->
                    own_qualified(Span, Namespace, Name, Env),
                    local_global(QualifiedName, Env);
                _ -> lookup_global(Span, Namespace, Name, Env)
            end;
        false ->
            %% report §4.2: `M.T.name` in module M is M's own member where M
            %% declares T, and the module M.T's `name` otherwise; only one of
            %% the two can exist, a module namespace may not coincide with a
            %% type-member namespace
            Own = case is_own_type_namespace(Namespace, OwnNamespace) of
                      true -> own_member(lists:last(Namespace), Name, Env);
                      false -> error
                  end,
            case Own of
                {ok, QualifiedName} ->
                    written_plain(Span, OwnNamespace, [lists:last(Namespace), Name]),
                    local_global(QualifiedName, Env);
                error ->
                    lookup_global(Span, Namespace, Name, Env)
            end
    end.

%% Report §4.2: a module's own qualified name is written where a binding
%% hides the plain name, and nowhere else, as `Prelude.` is.
own_qualified(Span, Namespace, Name, #env{locals = Locals}) ->
    case is_map_key(Name, Locals) of
        true ->
            ok;
        false ->
            Plain = atom_to_list(Name),
            Written = ern_namespace:text(Namespace ++ [Name]),
            {Line, Column, _} = ern_diagnostic:span(Span),
            fail({Line, Column, {Line, Column + length(Written)}},
                 Written ++ " is written only where a binding hides " ++ Plain, [],
                 "nothing here hides it; write " ++ Plain)
    end.

%% Report §4.2: a module's own type, constructor or member, which no binding
%% can hide, is written by its plain name.
-spec written_plain(ern_diagnostic:span(), [atom()], [atom()]) -> no_return().
written_plain(Span, OwnNamespace, Plain) ->
    Written = ern_namespace:text(OwnNamespace ++ Plain),
    PlainText = ern_namespace:text(Plain),
    {Line, Column, _} = ern_diagnostic:span(Span),
    fail({Line, Column, {Line, Column + length(Written)}},
         Written ++ " is the module's own " ++ PlainText ++ ", which no binding hides", [],
         "write " ++ PlainText).

%% Report §4.2: `Prelude.` is written where the module hides the prelude's
%% name, and nowhere else, where the plain name is the one way to write it.
hidden(_Span, _QualifiedName, true) ->
    ok;
hidden(Span, QualifiedName, false) ->
    Plain = ern_namespace:text(QualifiedName),
    Written = "Prelude." ++ Plain,
    Hidden = case QualifiedName of
                 [_] -> "the prelude's " ++ Plain;
                 _ -> Plain
             end,
    {Line, Column, _} = ern_diagnostic:span(Span),
    fail({Line, Column, {Line, Column + length(Written)}},
         Written ++ " is written only where the module hides " ++ Hidden, [],
         "nothing here hides it; write " ++ Plain).

%% Report §4.2: `Prelude.` takes one name the prelude declares, or a
%% namespace of the prelude or the standard library and one of its names;
%% a module of the program's own is reached by its namespace alone.
-spec prelude_one(ern_diagnostic:span(), [atom()], atom()) -> no_return().
prelude_one(Span, Namespace, Name) ->
    fail(Span, ern_namespace:text(Namespace ++ [Name])
               ++ ": Prelude takes one name the prelude declares, as `Prelude.Some`, or a name"
               " of the prelude's or the standard library's namespaces, as"
               " `Prelude.Io.println`").

own_member(MemberOf, Name, #env{local_values = LocalValues} = Env) ->
    case LocalValues of
        #{{MemberOf, Name} := QualifiedName} -> {ok, QualifiedName};
        _ -> session_name(values, {MemberOf, Name}, Env)
    end.

%% Report §4.4: an abstract type's constructor is its module's alone, and
%% each input of a session is a module of its own (report §11.2).
session_constructor(Span, QualifiedName, #env{constructors = Constructors, types = Types}) ->
    #constructor_info{type_qualified_name = TypeQualifiedName} = ConstructorInfo =
        maps:get(QualifiedName, Constructors),
    case Types of
        #{TypeQualifiedName := #type_info{abstract = true}} ->
            %% report §11.2: the session writes its names unqualified, and
            %% an input, not a module, is what the constructor belongs to
            fail(Span, atom_to_list(lists:last(QualifiedName))
                       ++ " is the constructor of an abstract type and is not visible outside"
                       " the input that declared it");
        _ ->
            ConstructorInfo
    end.

%% Report §4.8, §11.2: the qualified name of the member an operator on the
%% type QualifiedName resolves to; at the prompt, a member of the session's
%% latest type of its name may have been declared by a later input than the
%% type.
-spec session_member([atom()], atom(), env()) -> [atom()].
session_member(QualifiedName, Member, Env) ->
    Name = lists:last(QualifiedName),
    case session_name(types, Name, Env) of
        {ok, QualifiedName} ->
            case session_name(values, {Name, Member}, Env) of
                {ok, MemberQualifiedName} -> MemberQualifiedName;
                error -> QualifiedName ++ [Member]
            end;
        _ ->
            QualifiedName ++ [Member]
    end.

%% Report §11.2: what the session declared under this unqualified name.
session_name(Which, Name, #env{session_scope = SessionScope}) ->
    case maps:get(Which, SessionScope, #{}) of
        #{Name := QualifiedName} -> {ok, QualifiedName};
        _ -> error
    end.

%% An unqualified name the module neither binds nor declares: at the
%% prompt the session's (report §11.2), and else the prelude's (§4.2).
lookup_outside(Span, Name, Env) ->
    case {session_name(values, Name, Env), Env#env.globals} of
        {{ok, QualifiedName}, _} -> session_global(QualifiedName, Name, Env);
        {error, #{[Name] := Scheme}} -> {Scheme, {prelude, [Name]}, Env};
        {error, _} ->
            %% report §4.9: a type variable's members are named under a
            %% requirement, and the variable is no value
            Help = case is_map_key(Name, Env#env.annotation_variables) of
                       true -> atom_to_list(Name) ++ " is a type variable of the signature;"
                               " its member, as " ++ atom_to_list(Name) ++ ".compare, is named"
                               " under a requirement, needs " ++ atom_to_list(Name)
                               ++ ".compare";
                       false -> undefined
                   end,
            fail(Span, "unknown name " ++ atom_to_list(Name), [], Help)
    end.

%% This module's own declaration, QualifiedName being its namespace, the
%% type it is a member of, and the name.
local_global(QualifiedName, #env{namespace = Namespace} = Env) ->
    Env1 = demand(QualifiedName, Env),
    Referent = case lists:nthtail(length(Namespace), QualifiedName) of
                   [Name] -> #own_declaration{member_of = undefined, name = Name};
                   [MemberOf, Name] -> #own_declaration{member_of = MemberOf, name = Name}
               end,
    {maps:get(QualifiedName, Env1#env.globals), Referent, Env1}.

%% Report §11.2: a declaration of an earlier input, another module.
session_global(QualifiedName, Name, Env) ->
    Env1 = demand(QualifiedName, Env),
    {maps:get(QualifiedName, Env1#env.globals),
     qualified_referent(lists:droplast(QualifiedName), Name, Env1), Env1}.

lookup_global(Span, Namespace, Name, #env{globals = Globals} = Env) ->
    QualifiedName = Namespace ++ [Name],
    case Globals of
        #{QualifiedName := Scheme} ->
            Referent = case lookup_type(QualifiedName, Env) =:= undefined
                            andalso lists:keymember(QualifiedName, 1, ern_prelude:values()) of
                           true -> {prelude, QualifiedName};
                           false -> qualified_referent(Namespace, Name, Env)
                       end,
            {Scheme, Referent, Env};
        _ when Namespace =:= ['Peer'] ->
            %% Report §8.3: a spawn on a peer is the module Peer's, which
            %% MVP 3.0 builds; a module of the program's may take the name
            case lists:any(fun(Key) -> lists:droplast(Key) =:= Namespace end, maps:keys(Globals)) of
                true -> fail(Span, "unknown name " ++ ern_namespace:text(QualifiedName));
                false ->
                    fail(Span, ern_namespace:text(QualifiedName)
                               ++ " is not here yet: the module Peer, which acts on peers,"
                               " arrives in MVP 3.0")
            end;
        _ ->
            unknown(Span, "name", QualifiedName)
    end.

%% Report §4.2: the declaration a qualified name names, Namespace the
%% module's namespace or that and the type that owns the member.
qualified_referent(Namespace, Name, #env{namespace = OwnNamespace} = Env) ->
    {Declaring, MemberOf} = case is_member_namespace(Namespace, Name, Env) of
                                true -> {lists:droplast(Namespace), lists:last(Namespace)};
                                false -> {Namespace, undefined}
                            end,
    case Declaring =:= OwnNamespace of
        true -> #own_declaration{member_of = MemberOf, name = Name};
        false -> #remote_declaration{namespace = Declaring, member_of = MemberOf, name = Name}
    end.

%% A constructor as a name written at Span, `C` or `M.C`, names it (report
%% §4.2, §4.4): the error for one unknown or not visible here is thrown.
-spec lookup_constructor(ern_diagnostic:span(), [atom()], atom(), env()) ->
          #constructor_info{}.
lookup_constructor(Span, [], Name,
                   #env{local_constructors = LocalConstructors,
                        constructors = Constructors} = Env) ->
    case LocalConstructors of
        #{Name := QualifiedName} -> maps:get(QualifiedName, Constructors);
        _ ->
            case session_name(constructors, Name, Env) of
                {ok, QualifiedName} -> session_constructor(Span, QualifiedName, Env);
                error ->
                    case Constructors of
                        #{[Name] := ConstructorInfo} -> ConstructorInfo;
                        _ -> fail(Span, "unknown constructor " ++ atom_to_list(Name))
                    end
            end
    end;
lookup_constructor(Span, ['Prelude'], Name,
                   #env{constructors = Constructors,
                        local_constructors = LocalConstructors} = Env) ->
    %% report §4.2: `Prelude.C` is the prelude's C, where the module hides it
    case Constructors of
        #{[Name] := ConstructorInfo} ->
            hidden(Span, [Name], is_map_key(Name, LocalConstructors)
                                 orelse session_name(constructors, Name, Env) =/= error),
            ConstructorInfo;
        _ ->
            fail(Span, "the prelude declares no constructor " ++ atom_to_list(Name))
    end;
lookup_constructor(Span, ['Prelude' | _] = Namespace, Name, _Env) ->
    prelude_one(Span, Namespace, Name);
lookup_constructor(Span, Namespace, Name,
                   #env{namespace = OwnNamespace, constructors = Constructors, types = Types,
                        local_types = LocalTypes}) ->
    Namespace =:= OwnNamespace andalso written_plain(Span, Namespace, [Name]),
    QualifiedName = Namespace ++ [Name],
    case Constructors of
        #{QualifiedName := ConstructorInfo} ->
            #constructor_info{type_qualified_name = TypeQualifiedName} = ConstructorInfo,
            %% report §4.4: an abstract type's constructor is its module's alone
            Local = maps:get(lists:last(TypeQualifiedName), LocalTypes, undefined),
            IsLocal = Local =:= TypeQualifiedName,
            case Types of
                #{TypeQualifiedName := #type_info{abstract = true}} when not IsLocal ->
                    fail(Span, ern_namespace:text(QualifiedName)
                               ++ " is the constructor of an abstract type and is not visible"
                               " outside its module");
                _ -> ConstructorInfo
            end;
        _ -> unknown(Span, "constructor", QualifiedName)
    end.

%% A constructor by its qualified name, one a checked pattern or a type's
%% own list of constructors gave, so known and not a name to resolve.
-spec constructor_info([atom()], env()) -> #constructor_info{}.
constructor_info(QualifiedName, #env{constructors = Constructors}) ->
    maps:get(QualifiedName, Constructors).

%%
%% Abstract types (report §4.4)
%%

%% An abstract type hides its constructors from every other module, so one
%% the module keeps private hides nothing.
check_abstract(Declarations) ->
    [#diagnostic{span = abstract_word(ern_diagnostic:span(Span)),
                 message = atom_to_list(Name) ++ " is an abstract type the module keeps"
                           " private, which hides its constructors from no module",
                 help = "export it, or declare it `type`"}
     || #abstract_declaration{export = false, span = Span,
                              declaration = #type_declaration{name = Name}} <- Declarations].

%% The word `abstract`, where the declaration begins.
abstract_word({Line, Column, _}) -> {Line, Column, {Line, Column + length("abstract")}}.

%%
%% Interface
%%

interface_of(Declarations, #env{namespace = Namespace, types = Types, globals = Globals} = Env) ->
    ExportedTypes = maps:from_list([{QualifiedName, maps:get(QualifiedName, Types)}
                                    || Declaration <- Declarations,
                                       {true, QualifiedName} <- [exported_type(Declaration, Env)]]),
    ExportedValues = maps:from_list([{QualifiedName, maps:get(QualifiedName, Globals)}
                                     || Declaration <- Declarations,
                                        {true, QualifiedName}
                                            <- [exported_value(Declaration, Env)]]),
    %% report §4.6: a `let` is a value, and the emitter reaches it through
    %% its getter even where its type is a function
    Lets = [QualifiedName || #let_declaration{} = Declaration <- Declarations,
                             {true, QualifiedName} <- [exported_value(Declaration, Env)]],
    #interface{namespace = Namespace, types = ExportedTypes, values = ExportedValues, lets = Lets}.

%% Report §4.2: an exported declaration is made of the types that cross the
%% boundary with it. A private type in an exported signature would leave a
%% dependent module holding a value it cannot build or lay out; a type whose
%% values cross but whose constructors do not is an abstract type (§4.4).
%% A function's effect names no value and is not part of this.
check_exports(Declarations,
              #env{local_types = LocalTypes, globals = Globals, types = Types} = Env) ->
    Exported = [QualifiedName || Declaration <- Declarations,
                                 {true, QualifiedName} <- [exported_type(Declaration, Env)]],
    OwnTypes = maps:values(LocalTypes),
    Private = fun(QualifiedName) ->
                  lists:member(QualifiedName, OwnTypes)
                      andalso not lists:member(QualifiedName, Exported)
              end,
    lists:append([[private_type_diagnostic(Declaration, Type)
                   || Type <- lists:usort(named_types(Declaration, Globals, Types, Env)),
                      Private(Type)]
                  || Declaration <- Declarations]).

%% The types an exported declaration names, which cross the boundary with
%% it.
named_types(Declaration, Globals, Types, Env) ->
    case {exported_value(Declaration, Env), exported_type(Declaration, Env)} of
        {{true, QualifiedName}, _} ->
            tcons(scheme_type(maps:get(QualifiedName, Globals, undefined), Env));
        %% report §4.2: an abstract type's constructors do not cross, so its
        %% fields may name a private type
        {false, {true, _}} when is_record(Declaration, abstract_declaration) ->
            [];
        {false, {true, TypeQualifiedName}} ->
            constructor_tcons(maps:get(TypeQualifiedName, Types, undefined), Env);
        {false, false} ->
            []
    end.

private_type_diagnostic(Declaration, QualifiedName) ->
    Name = lists:last(QualifiedName),
    #diagnostic{span = ern_diagnostic:span(ern_ast:span(Declaration)),
                message = declared_text(Declaration) ++ " is exported and its type names "
                          ++ atom_to_list(Name) ++ ", which this module keeps private",
                help = "export " ++ atom_to_list(Name) ++ ", or declare it `abstract type` so that"
                       " its constructors stay private (§4.4)"}.

declared_text(#type_declaration{name = Name}) -> atom_to_list(Name);
declared_text(#abstract_declaration{declaration = #type_declaration{name = Name}}) ->
    atom_to_list(Name);
declared_text(#foreign_type_declaration{name = Name}) -> atom_to_list(Name);
declared_text(Declaration) -> declaration_name(Declaration).

scheme_type(#scheme{type = Type}, Env) -> resolve_type(Type, Env);
scheme_type(_, _) -> pure.

constructor_tcons(#type_info{constructors = Constructors}, Env) ->
    lists:append([tcons(scheme_type(Scheme, Env))
                  || #constructor_info{scheme = Scheme} <- Constructors]);
constructor_tcons(_, _) ->
    [].

%% The type constructors a type names, its arrows' effects aside.
tcons({tcon, QualifiedName, Args}) -> [QualifiedName | lists:append([tcons(Arg) || Arg <- Args])];
tcons({ttuple, Elements}) -> lists:append([tcons(Element) || Element <- Elements]);
tcons({tfn, Params, _Effect, Result}) -> lists:append([tcons(Type) || Type <- Params ++ [Result]]);
tcons(_) -> [].

exported_type(#type_declaration{export = true, name = Name}, Env) ->
    {true, Env#env.namespace ++ [Name]};
exported_type(#abstract_declaration{export = true, declaration = #type_declaration{name = Name}},
              Env) ->
    {true, Env#env.namespace ++ [Name]};
exported_type(#foreign_type_declaration{export = true, name = Name}, Env) ->
    {true, Env#env.namespace ++ [Name]};
exported_type(_, _) -> false.

exported_value(#fn_declaration{export = true, member_of = MemberOf, name = Name}, Env) ->
    {true, value_qualified_name(Env, MemberOf, Name)};
exported_value(#let_declaration{export = true, name = Name}, Env) ->
    {true, value_qualified_name(Env, undefined, Name)};
exported_value(#foreign_fn_declaration{export = true, member_of = MemberOf, name = Name}, Env) ->
    {true, value_qualified_name(Env, MemberOf, Name)};
exported_value(_, _) -> false.

%%
%% Helpers
%%

%% Report §4.6, §8.5: a name declared with `let` is a value, whatever its
%% type, and the emitter reaches it through the getter of its module. A
%% name declared with `fn` is a function.
-spec is_value([atom()], env()) -> boolean().
is_value(QualifiedName, #env{lets = Lets}) ->
    maps:is_key(QualifiedName, Lets).

-spec resolve_type(ern_types:type(), env()) -> ern_types:type().
resolve_type(Type, #env{type_state = TypeState}) -> ern_types:substitute(Type, TypeState).

-spec node_type(tuple()) -> ern_types:type().
node_type(Node) ->
    lists:last(tuple_to_list(Node)).

unify_at(Span, Expected, Actual, Env, Rule) ->
    unify_at(Span, Expected, Actual, Env, Rule, undefined).

%% A unification that cannot fail, of a fresh variable or of a type with
%% its own constructor applied to fresh variables: a failure would be the
%% checker's defect and no program's error, so it has no words.
bound(Expected, Actual, #env{type_state = TypeState} = Env) ->
    {ok, TypeState1} = ern_types:unify(Expected, Actual, TypeState),
    Env#env{type_state = TypeState1}.

%% Report §11.5: a mismatch is reported at Span, the leaf, with Origin, the
%% span that fixed the expectation, as its label. An annotation variable is
%% rigid (§3.9), so a unification that binds one to a type, or two to one
%% another, is the mismatch.
%% Rule, which the message opens with, may carry its own help line,
%% {help, Text, Help}, as a recursive call's does.
unify_at(Span, Expected, Actual, #env{type_state = TypeState, rigid = Rigid} = Env, Rule,
         Origin) ->
    {RuleText, RuleHelp} = case Rule of
                               {help, Text, TextHelp} -> {Text, TextHelp};
                               _ -> {Rule, undefined}
                           end,
    case ern_types:unify(Expected, Actual, TypeState) of
        {ok, TypeState1} ->
            case {rigid_kept(Rigid, TypeState), rigid_kept(Rigid, TypeState1)} of
                {true, false} ->
                    Help = case RuleHelp of
                               undefined -> rigid_help(Rigid, TypeState1);
                               _ -> RuleHelp
                           end,
                    fail(Span, unify_message(RuleText, {mismatch, Expected, Actual}, Expected,
                                             Actual, TypeState),
                         labels(Origin), Help);
                _ ->
                    settle(Span, TypeState, Env#env{type_state = TypeState1})
            end;
        {error, Reason} ->
            Help = case {RuleHelp, not_an_alias(Expected, Actual, Env)} of
                       {undefined, undefined} ->
                           differing_help(Reason, Expected, Actual, TypeState);
                       {undefined, Alias} -> Alias;
                       _ -> RuleHelp
                   end,
            fail(Span, unify_message(RuleText, Reason, Expected, Actual, TypeState),
                 labels(Origin), Help)
    end.

%% Report §3.5, §11.5: `type Word = String` declares a type whose one value
%% is the constructor `String`, and not another name for the type `String`;
%% where one of the two meets the other, the help says so.
not_an_alias(Expected, Actual, #env{type_state = TypeState} = Env) ->
    Resolved = {ern_types:resolve(Expected, TypeState), ern_types:resolve(Actual, TypeState)},
    case {one_named(Resolved, Env), one_named(swap(Resolved), Env)} of
        {{Wrapper, Other}, _} -> alias_help(Wrapper, Other, TypeState);
        {_, {Wrapper, Other}} -> alias_help(Wrapper, Other, TypeState);
        _ -> undefined
    end.

swap({First, Second}) -> {Second, First}.

%% The first type where its one constructor is nullary and named as the
%% second type is.
one_named({{tcon, TypeQualifiedName, _} = Type, {tcon, OtherQualifiedName, _} = Other},
          #env{types = Types}) ->
    Name = lists:last(OtherQualifiedName),
    case maps:get(TypeQualifiedName, Types, undefined) of
        #type_info{constructors = [#constructor_info{name = Name, fields = none}]} ->
            {Type, Other};
        _ -> none
    end;
one_named(_, _) ->
    none.

alias_help(Wrapper, {tcon, OtherQualifiedName, _} = Other, TypeState) ->
    WrapperText = ern_types:format(Wrapper, TypeState),
    Name = atom_to_list(lists:last(OtherQualifiedName)),
    OtherText = ern_types:format(Other, TypeState),
    "`type " ++ WrapperText ++ " = " ++ Name ++ "` declares a type whose one value is `" ++ Name
    ++ "`, not another name for " ++ OtherText ++ "; there are no type aliases, and a wrapper is"
    " `type " ++ WrapperText ++ " = " ++ WrapperText ++ "(" ++ OtherText ++ ")`".

%% Whether the rigid variables are still distinct variables.
rigid_kept(Rigid, TypeState) ->
    Resolved = [ern_types:resolve(Variable, TypeState) || {_, Variable} <- Rigid],
    Ids = [Id || {tvar, Id} <- Resolved],
    length(Ids) =:= length(Resolved) andalso length(lists:usort(Ids)) =:= length(Ids).

%% Report §3.9, §11.5: an annotation's variable stands for every type, which
%% a unification that bound one to a type, or two to one another, forgot.
rigid_help(Rigid, TypeState) ->
    Resolved = [{Name, ern_types:resolve(Variable, TypeState)} || {Name, Variable} <- Rigid],
    case [{Name, Type} || {Name, Type} <- Resolved, element(1, Type) =/= tvar] of
        [{Name, Type} | _] ->
            "`" ++ atom_to_list(Name) ++ "` stands for every type a caller may choose, not for "
            ++ ern_types:format(Type, TypeState) ++ " alone";
        [] ->
            case [{First, Second} || {First, {tvar, Id}} <- Resolved,
                                     {Second, {tvar, OtherId}} <- Resolved,
                                     Id =:= OtherId, First < Second] of
                [{First, Second} | _] ->
                    "`" ++ atom_to_list(First) ++ "` and `" ++ atom_to_list(Second)
                    ++ "` stand for types a caller chooses apart, which may differ";
                [] ->
                    undefined
            end
    end.

%% The message shows the whole types; when they differ inside, the help
%% line names the differing part, and none where the two parts print
%% alike, as two variables printed apart both print `a`. A regression: the
%% help said "the types differ at a=! and a=!"
differing_help({mismatch, _, _}, Expected, Actual, TypeState) ->
    {ExpectedPart, ActualPart} = ern_types:mismatch_pair(Expected, Actual, TypeState),
    ExpectedText = ern_types:format(ExpectedPart, TypeState),
    ActualText = ern_types:format(ActualPart, TypeState),
    case ExpectedText =:= ern_types:format(Expected, TypeState)
         orelse ActualText =:= ern_types:format(Actual, TypeState)
         orelse ExpectedText =:= ActualText of
        true -> undefined;
        false -> "the types differ at " ++ ExpectedText ++ " and " ++ ActualText
    end;
differing_help(_, _, _, _) -> undefined.

unify_message(Rule, {mismatch, _, _}, Expected, Actual, TypeState) ->
    {ExpectedText, ActualText} = ern_types:format_pair(Expected, Actual, TypeState),
    lists:flatten([Rule, ": expected ", ExpectedText, ", found ", ActualText]);
unify_message(Rule, Reason, _, _, _) when Reason =:= pure_where_process_needed;
                                              Reason =:= process_where_pure_needed ->
    lists:flatten([Rule, ": ", ern_types:format_error(Reason)]);
unify_message(Rule, {pure_vs_effect, _}, Expected, Actual, TypeState) ->
    {ExpectedText, ActualText} = ern_types:format_pair(Expected, Actual, TypeState),
    lists:flatten([Rule, ": expected ", ExpectedText, ", found ", ActualText,
                   " (a pure function and one with a mailbox effect do not match)"]);
unify_message(Rule, Reason, Expected, Actual, TypeState) ->
    lists:flatten([Rule, ": ", ern_types:format_error(Reason), " (",
                   ern_types:format(Expected, TypeState), " against ",
                   ern_types:format(Actual, TypeState), ")"]).

plural(1) -> "";
plural(_) -> "s".

fail(Span, Message) ->
    throw({type_error, Span, lists:flatten(Message)}).

%% Report §11.2: a qualified name that names nothing in scope, its
%% namespace kept for the shell, which names the `:load` that would put
%% its module in scope.
unknown(Span, What, QualifiedName) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = "unknown " ++ What ++ " "
                                             ++ ern_namespace:text(QualifiedName),
                                   unknown_namespace = lists:droplast(QualifiedName)}}).

fail(Span, Message, Labels, Help) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = lists:flatten(Message),
                                   labels = Labels, help = Help}}).
