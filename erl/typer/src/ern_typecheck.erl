%% Type inference for Ernest modules, report §3, §4, §5, §6: algorithm W
%% with levels for generalization over the AST of ern_parser, producing the
%% same AST with every type slot filled and the module's interface.
%%
%% Effects are the extra slot on the arrow (report §3.9): a call to a
%% function whose effect is pure constrains nothing; any other effect is
%% unified with the enclosing function's effect. receive, self, and the
%% process primitives force that effect to be a mailbox type.
%%
%% Per definition, after inference: operator resolution (report §4.8),
%% rigidity of annotation variables, undetermined block bindings (§4.6),
%% match exhaustiveness (ern_exhaust), and the reply discipline (ern_reply).
%% Errors are collected per definition; checking continues with the next.
-module(ern_typecheck).

-export([check/3, check/4, check_string/2, type_state/1, scope_state/1, set_type_state/2,
         prelude_names/0, prelude_values/0, prelude_constructor/1, prelude_constructors/0,
         prelude_env/0, lookup_type/2, member_qualified_name/3, is_reply_carrying/2,
         assume_reply_carrying/2, let_order/1, foreign_implementation/1, fields/2,
         declared_scheme/3, lookup_constructor/4, constructor_info/2, is_value/2, resolve_type/2,
         node_type/1]).

-export_type([env/0, session/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

%% The checker's environment. Of its fields:
%% lets: the qualified names, this module's and its dependencies', that
%% were declared with `let`; the emitter reaches a value through its getter
%% session: the shell's session, a scope between this module's own
%% declarations and the prelude (report §11.2), empty in every other module
%% pending, deferred: what the definition being checked leaves for its
%% end, the #pending_restriction{}s and the deferred records below
%% effect_origin: undefined or the #effect_origin{} of the mailbox here
%% groups: qualified name => the dependency group not yet checked that
%% declares it, checked on first demand (a reference, or an operator
%% resolving to it); typed: the groups checked so far; errors: their errors
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
-record(env, {namespace = [], types = #{}, constructors = #{}, globals = #{}, lets = #{},
              local_types = #{}, local_constructors = #{}, local_values = #{}, session = #{},
              locals = #{}, effect = pure, type_state, pending = [], deferred = [],
              annotation_variables = #{}, rigid = [], effect_origin = undefined,
              groups = #{}, typed = [], errors = [], reply_variables = [],
              reply_params = #{}, let_order = [], effectful = false, effectful_lets = [],
              generalizing = false, provided = [], inferring = []}).
-opaque env() :: #env{}.

%% What fixes the mailbox where an expression stands, which an effect error
%% names (report §11.5): what is pure or has the mailbox, "f", "the
%% lambda", "a guard", or top_let for a top-level `let`, whose mailbox is
%% Never; the span that made it so, its label, and what to do.
-record(effect_origin, {what, span, label, help}).

%% A restriction an instance carries, checked when its definition ends
%% (report §3.9, §3.10): equality or not_reply_carrying, the type
%% variable's id, where the instance stands, what needs the equality, and
%% the name and printed type the instance was taken of.
-record(pending_restriction, {restriction, id, span, need, who}).

%% What waits for the end of a definition, where its types are known: an
%% operator and a field selection whose operand type is still a variable
%% (report §4.8, §3.5), with the origin of the type expected of the
%% result; a `<-` whose sum type is (§5.5); and the argument `Io.show` or
%% `Io.debug` writes (Appendix E.1).
-record(deferred_operator, {span, operator, operand_type, result, origin}).
-record(deferred_selection, {span, field, expr_type, result, origin}).
-record(deferred_bind_arrow, {span, spans, expr_type, pattern_type, rest_type, fixed}).
-record(deferred_show, {span, name, argument}).

%% What the checks after inference need of a definition: its scope as it
%% ends, since a deferred operator calls its member under the definition's
%% own mailbox and adds its restrictions to the definition's (report §4.8,
%% §3.4, §3.10).
-record(post_check, {span, params, body, type, effect, effect_origin, rigid, pending,
                     deferred}).

-type error() :: ern_diagnostic:diagnostic().
-type key() :: atom() | {atom(), atom()}.
-type session() :: #{values => #{key() => [atom()]}, types => #{atom() => [atom()]},
                     constructors => #{atom() => [atom()]}}.

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
          {ok, [tuple()], #interface{}, env()} | {error, [error()]}.
check(Namespace, Parsed, Interfaces) ->
    check(Namespace, Parsed, Interfaces, #{}).

%% Report §11.2: the shell's session is a scope of its own, looked in after
%% the input's own declarations and before the prelude. Its three maps take
%% an unqualified name, as a module's own do, to the qualified name of the
%% input that declared it.
-spec check([atom()], [tuple()], [#interface{}], session()) ->
          {ok, [tuple()], #interface{}, env()} | {error, [error()]}.
check(Namespace, Parsed, Interfaces, Session) ->
    Declarations = builtin_operators(Namespace, Parsed),
    Seeded = lists:foldl(fun add_interface/2, (prelude_env())#env{namespace = Namespace},
                         Interfaces),
    every_type_declared(Interfaces, Seeded),
    Env = Seeded#env{session = Session},
    try
        declared_twice(Declarations),
        {Env1, Errors1} = declare_types(Declarations, Env),
        %% report §11.5: the module's types print unqualified, except those
        %% that shadow a prelude name
        Shadows = [Name || Name <- maps:keys(Env1#env.local_types),
                           is_map_key([Name], Env1#env.types)],
        %% report §11.2: a session type prints unqualified, except one a
        %% later input has shadowed, which prints as the input that declared it
        SessionTypes = maps:values(maps:get(types, Session, #{})),
        TypeState1 = ern_types:set_scope(effect_params(Env1), Namespace, SessionTypes, Shadows),
        Env2 = mark_abstract(Declarations, Env1#env{type_state = TypeState1}),
        {Typed, Env3, Errors2} = check_values(Declarations, Env2),
        Errors3 = check_abstract(Declarations) ++ check_exports(Declarations, Env3),
        case lists:sort(Errors1 ++ Errors2 ++ Errors3) of
            [] -> {ok, Typed, interface_of(Declarations, Env3), Env3};
            Errors -> {error, hidden_notes(Declarations, Errors)}
        end
    catch
        throw:{type_error, Span, Message} ->
            {error, hidden_notes(Declarations, [diagnostic(Span, Message)])};
        throw:{type_error, #diagnostic{} = Diagnostic} ->
            {error, hidden_notes(Declarations, [Diagnostic])};
        throw:{type_errors, Diagnostics} ->
            {error, hidden_notes(Declarations, lists:sort(Diagnostics))}
    end.

%% Report §4.2, §11.5: a module's own declaration hides a prelude name of
%% the same spelling in the module, and an error at a use of such a name
%% says so, with the prelude's qualified name, since what the writer meant
%% may be the prelude's. The note is a label on the use.
hidden_notes(Declarations, Errors) ->
    {PreludeTypes, PreludeConstructors} = prelude_names(),
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
        [] -> Errors;
        _ ->
            Uses = hidden_uses(Declarations, Hidden),
            [hidden_note(Diagnostic, Uses) || Diagnostic <- Errors]
    end.

declared_types(Declarations) ->
    [Declaration || #type_declaration{} = Declaration <- Declarations]
        ++ [Declaration || #abstract_declaration{declaration = Declaration} <- Declarations].

top_value_name(#fn_declaration{owner = undefined, name = Name}) -> [Name];
top_value_name(#let_declaration{name = Name}) -> [Name];
top_value_name(#foreign_fn_declaration{owner = undefined, name = Name}) -> [Name];
top_value_name(_) -> [].

%% Each unqualified use of a hidden name, its span and what it names.
hidden_uses(Declarations, Hidden) ->
    Uses = fun Walk(#t_named{path = [], name = Name, span = Span} = Node) ->
                   [{Span, type, Name} || lists:member({type, Name}, Hidden)]
                       ++ Walk(Node#t_named.args);
               Walk(#e_constructor{path = [], name = Name, span = Span} = Node) ->
                   [{Span, constructor, Name} || lists:member({constructor, Name}, Hidden)]
                       ++ Walk(Node#e_constructor.args);
               Walk(#p_constructor{path = [], name = Name, span = Span} = Node) ->
                   [{Span, constructor, Name} || lists:member({constructor, Name}, Hidden)]
                       ++ Walk(Node#p_constructor.args);
               Walk(#e_var{path = [], name = Name, span = Span}) ->
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
             || {UseSpan, Kind, Name} <- Uses, within(ern_diagnostic:span(UseSpan), Span)],
    Diagnostic#diagnostic{labels = Labels ++ lists:usort(Notes)};
hidden_note(Diagnostic, _) ->
    Diagnostic.

note_text(Kind, Name) ->
    Text = atom_to_list(Name),
    "`" ++ Text ++ "` here is this module's " ++ atom_to_list(Kind)
    ++ ", and the prelude's is `Prelude." ++ Text ++ "`".

%% Whether a position lies inside a span, whose end is past its last
%% column (ern_diagnostic).
within({Line, Column, _}, {StartLine, StartColumn, {EndLine, EndColumn}}) ->
    ({Line, Column} >= {StartLine, StartColumn}) andalso ({Line, Column} < {EndLine, EndColumn});
within(_, _) ->
    false.

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
declaration_names(#fn_declaration{span = Span, owner = Owner, name = Name}) ->
    [{value, {Owner, Name}, Span}];
declaration_names(#let_declaration{span = Span, name = Name}) ->
    [{value, {undefined, Name}, Span}];
declaration_names(#foreign_fn_declaration{span = Span, owner = Owner, name = Name}) ->
    [{value, {Owner, Name}, Span}];
declaration_names(_) ->
    [].

key_text({Owner, Name}) -> local_name(Owner, Name);
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

own_operator(TypeName, #fn_declaration{owner = TypeName, name = Name} = Declaration) ->
    case is_operator(Name) of
        true -> Declaration#fn_declaration{owner = undefined};
        false -> Declaration
    end;
own_operator(TypeName, #foreign_fn_declaration{owner = TypeName, name = Name} = Declaration) ->
    case is_operator(Name) of
        true -> Declaration#foreign_fn_declaration{owner = undefined};
        false -> Declaration
    end;
own_operator(_, Declaration) ->
    Declaration.

-spec check_string([atom()], unicode:chardata()) ->
          {ok, [tuple()], #interface{}, env()} | {error, [error()]}.
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
-spec scope_state([#interface{}]) -> ern_types:type_state().
scope_state(Interfaces) ->
    effect_params(lists:foldl(fun add_interface/2, prelude_env(), Interfaces)).

-spec set_type_state(ern_types:type_state(), env()) -> env().
set_type_state(TypeState, Env) -> Env#env{type_state = TypeState}.

%%
%% The prelude
%%

%% Report §11.2: the types and constructors the prelude declares, for
%% the shell's completion, which offers them as it offers a module's.
-spec prelude_names() -> {[[atom()]], [[atom()]]}.
prelude_names() ->
    #env{types = Types, constructors = Constructors} = prelude_env(),
    {maps:keys(Types), maps:keys(Constructors)}.

%% Report §11.2: the values the prelude declares, each with its scheme, for
%% the shell's `:browse Prelude`.
-spec prelude_values() -> [{[atom()], #scheme{}}].
prelude_values() ->
    #env{globals = Globals} = prelude_env(),
    [{QualifiedName, maps:get(QualifiedName, Globals)}
     || {QualifiedName, _, _} <- ern_prelude:values(), is_map_key(QualifiedName, Globals)].

%% Report §11.2: a prelude constructor, whose type is the page that
%% documents it and whose scheme a listing shows, for the shell.
-spec prelude_constructor(atom()) -> {ok, #constructor_info{}} | none.
prelude_constructor(Name) ->
    case prelude_constructors() of
        #{[Name] := ConstructorInfo} -> {ok, ConstructorInfo};
        _ -> none
    end.

%% Every prelude constructor by its qualified name, read once where many are.
-spec prelude_constructors() -> #{[atom()] => #constructor_info{}}.
prelude_constructors() ->
    #env{constructors = Constructors} = prelude_env(),
    Constructors.

-spec prelude_env() -> env().
prelude_env() ->
    Env1 = #env{type_state = ern_types:new()},
    AddBuiltin = fun({Name, Arity, _Doc}, Acc) ->
                     Params = lists:seq(1, Arity),
                     add_type(Acc, #type_info{qualified_name = [Name], params = Params,
                                              foreign = true,
                                              equality = ern_prelude:equality_params(Name)})
                 end,
    Env2 = lists:foldl(AddBuiltin, Env1, ern_prelude:builtin_types()),
    {ok, Declarations} = ern_parser:parse_string(ern_prelude:declared_types()),
    {Env3, []} = declare_types(Declarations, Env2),
    Env4 = Env3#env{type_state = effect_params(Env3)},
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
            erlang:error({interface_names_undeclared_type, format_qualified_name(QualifiedName)})
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
annotation_type(#t_named{span = Span, path = Path, name = Name, args = Args},
                AnnotationVariables, Env) ->
    {QualifiedName, Arity} = lookup_type_name(Span, Path, Name, Env),
    length(Args) =:= Arity orelse
        fail(Span, io_lib:format("~s takes ~B type argument~s, not ~B",
                                 [format_qualified_name(QualifiedName), Arity, plural(Arity),
                                  length(Args)])),
    {ArgTypes, AnnotationVariables1, TypeState} = annotation_types(Args, AnnotationVariables, Env),
    %% report §3.10, §4.7, §9.2: a parameter declared `k=` puts the
    %% equality constraint on every variable of its argument, wherever the
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
            case session(types, Name, Env) of
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
                                 orelse session(types, Name, Env) =/= error),
            {[Name], length(Params)};
        _ ->
            fail(Span, "the prelude declares no type " ++ atom_to_list(Name))
    end;
lookup_type_name(Span, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Span, Path, Name);
lookup_type_name(Span, Path, Name, #env{types = Types}) ->
    QualifiedName = Path ++ [Name],
    case Types of
        #{QualifiedName := #type_info{params = Params}} -> {QualifiedName, length(Params)};
        _ -> fail(Span, "unknown type " ++ format_qualified_name(QualifiedName))
    end.

-spec lookup_type([atom()], env()) -> #type_info{} | undefined.
lookup_type(QualifiedName, #env{types = Types}) -> maps:get(QualifiedName, Types, undefined).

%% Report §4.2, §11.2: whether Path is a module and the type that owns the
%% member Name: a type of that module, or, at the prompt, a type the session
%% declares whose member a later input declared.
-spec is_member_path([atom()], atom(), env()) -> boolean().
is_member_path(Path, Name, Env) ->
    case lookup_type(Path, Env) of
        #type_info{qualified_name = QualifiedName} when length(QualifiedName) > 1 -> true;
        _ -> session(values, {lists:last(Path), Name}, Env) =:= {ok, Path ++ [Name]}
    end.

%% Report §4.8, §11.2: the qualified name of the member an operator on the
%% type QualifiedName resolves to, which at the prompt a later input may
%% have declared.
-spec member_qualified_name([atom()], atom(), env()) -> [atom()].
member_qualified_name(QualifiedName, Member, Env) ->
    session_member(QualifiedName, Member, Env).

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
    {Env4, Errors} = lists:foldl(fun try_declare_constructors/2, {Env3, []}, TypeDeclarations),
    {mark_reply_carrying(reply_params(Env4)), Errors}.

declare_type_name(#type_declaration{span = Span, name = Name, params = Params}, Env) ->
    check_unique_type(Span, Name, Env),
    QualifiedName = Env#env.namespace ++ [Name],
    Added = add_type(Env, #type_info{qualified_name = QualifiedName, params = Params}),
    Added#env{local_types = maps:put(Name, QualifiedName, Added#env.local_types)}.

%% Report §4.7: a foreign type, whose parameters written `k=` require
%% equality.
declare_foreign_type(#foreign_type_declaration{span = Span, name = Name, params = Params,
                                               equality = Equality}, Env) ->
    check_unique_type(Span, Name, Env),
    QualifiedName = Env#env.namespace ++ [Name],
    RequiresEquality = case Equality of
                           [] -> [];
                           _ -> [lists:member(Param, Equality) || Param <- Params]
                       end,
    Added = add_type(Env, #type_info{qualified_name = QualifiedName, params = Params,
                                     foreign = true, equality = RequiresEquality}),
    Added#env{local_types = maps:put(Name, QualifiedName, Added#env.local_types)}.

%% A type's constructors, an error in them collected, so that the module's
%% other types are declared.
try_declare_constructors(TypeDeclaration, {Env, Found}) ->
    try
        {declare_constructors(TypeDeclaration, Env), Found}
    catch
        throw:{type_error, Span, Message} -> {Env, [diagnostic(Span, Message) | Found]};
        throw:{type_error, #diagnostic{} = Diagnostic} -> {Env, [Diagnostic | Found]}
    end.

%% Report §3.9: a type argument is a value position where its parameter
%% occurs in a value position of the type's fields; one of a built-in or
%% foreign type always is. The state keeps the types that have a parameter
%% that is not.
effect_params(#env{types = Types, type_state = TypeState}) ->
    IsValue = param_occurrences(Types, fun in_value/3),
    HasEffectParam = fun(_, TypeIsValue) -> lists:member(false, TypeIsValue) end,
    ern_types:set_effect_params(TypeState, maps:filter(HasEffectParam, IsValue)).

%% Report §6.6: a declared type is reply-carrying at an instantiation whose
%% fields, its arguments substituted, have a reply-carrying type. An
%% argument can make them so only where its parameter reaches a field
%% outside function types and the arguments of built-in and foreign types,
%% which never carry a reply.
reply_params(#env{types = Types} = Env) ->
    Env#env{reply_params = param_occurrences(Types, fun in_reply/3)}.

%% For each declared type with parameters, whether each parameter occurs in
%% its fields as Occurs says. A parameter may occur only as an argument of
%% another type, or of its own, so the occurrences are a least fixpoint over
%% every declared type in scope. A type whose constructors failed to
%% declare keeps its parameters' names, and has no fields to read.
param_occurrences(Types, Occurs) ->
    Declared = maps:from_list([{QualifiedName, TypeInfo}
                               || QualifiedName := #type_info{foreign = false,
                                                              params = [_ | _] = Params} = TypeInfo
                                      <- Types,
                                  lists:all(fun(Param) -> is_tuple(Param) end, Params)]),
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

%% Does variable Id occur in a value position of T, given which parameters
%% of the declared types are value positions so far?
in_value(Id, {tvar, Id}, _IsValue) ->
    true;
in_value(Id, {tcon, QualifiedName, Args}, IsValue) ->
    Values = case IsValue of
                 #{QualifiedName := TypeIsValue} ->
                     [Arg || {Arg, true} <- lists:zip(Args, TypeIsValue)];
                 _ -> Args
             end,
    lists:any(fun(Arg) -> in_value(Id, Arg, IsValue) end, Values);
in_value(Id, {ttuple, Elements}, IsValue) ->
    lists:any(fun(Element) -> in_value(Id, Element, IsValue) end, Elements);
in_value(Id, {tfn, Params, _, Result}, IsValue) ->
    lists:any(fun(Part) -> in_value(Id, Part, IsValue) end, [Result | Params]);
in_value(_, _, _) ->
    false.

%% Does variable Id reach T outside function types and the arguments of
%% built-in and foreign types, given which parameters of the declared types
%% reach their fields so far?
in_reply(Id, {tvar, Id}, _Reaches) ->
    true;
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

check_unique_type(Span, 'Prelude', _Env) ->
    %% report §4.2: `Prelude.X` names the prelude's X, so no type is Prelude
    fail(Span, "Prelude names the prelude, and a type may not take it");
check_unique_type(Span, Name, #env{local_types = LocalTypes}) ->
    case LocalTypes of
        #{Name := _} -> fail(Span, "type " ++ atom_to_list(Name) ++ " is declared twice");
        _ -> ok
    end.

declare_constructors(#type_declaration{name = Name, params = Params, constructors = Constructors},
                     Env) ->
    QualifiedName = maps:get(Name, Env#env.local_types),
    %% one type variable per parameter, shared by all constructors
    Fresh = fun(Param, {Map, Acc}) ->
                {Variable, Acc1} = ern_types:fresh(Acc),
                {Map#{Param => Variable}, Acc1}
            end,
    {AnnotationVariables, TypeState1} =
        lists:foldl(Fresh, {#{}, ern_types:enter(Env#env.type_state)}, Params),
    ParamVariables = [maps:get(Param, AnnotationVariables) || Param <- Params],
    Result = {tcon, QualifiedName, ParamVariables},
    Declare = fun(Constructor, Acc) ->
                  declare_constructor(Constructor, QualifiedName, AnnotationVariables, Result, Acc)
              end,
    Env1 = Env#env{type_state = TypeState1},
    {ConstructorInfos, Env2} = lists:mapfoldl(Declare, Env1, Constructors),
    TypeInfo = (maps:get(QualifiedName, Env2#env.types))#type_info{params = ParamVariables,
                                                                   constructors = ConstructorInfos},
    Env3 = Env2#env{type_state = ern_types:leave(Env2#env.type_state)},
    Env3#env{types = maps:put(QualifiedName, TypeInfo, Env3#env.types)}.

%% Report §3.5: a constructor of the type TypeQualifiedName, whose value is
%% Result, its fields' annotation variables the type's parameters.
declare_constructor(#constructor{span = Span, name = Name, fields = Fields}, TypeQualifiedName,
                    AnnotationVariables, {tcon, _, ParamVariables} = Result, Env) ->
    check_unique_constructor(Span, Name, Env),
    QualifiedName = Env#env.namespace ++ [Name],
    {FieldSpec, FieldTypes, Env1} = constructor_fields(Fields, AnnotationVariables, Env),
    Type = case FieldSpec of
               none -> Result;
               _ -> {tfn, FieldTypes, pure, Result}
           end,
    Quantified = [{Id, []} || {tvar, Id} <- ParamVariables],
    ConstructorInfo = #constructor_info{name = Name, qualified_name = QualifiedName,
                                        type_qualified_name = TypeQualifiedName,
                                        fields = FieldSpec, tag_arity = length(FieldTypes),
                                        scheme = #scheme{quantified = Quantified, type = Type}},
    {ConstructorInfo,
     Env1#env{local_constructors = maps:put(Name, QualifiedName, Env1#env.local_constructors),
              constructors = maps:put(QualifiedName, ConstructorInfo, Env1#env.constructors)}}.

check_unique_constructor(Span, Name, #env{local_constructors = LocalConstructors}) ->
    case LocalConstructors of
        #{Name := _} -> fail(Span, "constructor " ++ atom_to_list(Name) ++ " is declared twice");
        _ -> ok
    end.

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

%%
%% Values: fn, let, foreign fn, in dependency order
%%

check_values(Declarations, Env1) ->
    Values = [Declaration || Declaration <- Declarations, is_value_declaration(Declaration)],
    %% names first, so every body can see every other
    Env2 = lists:foldl(fun register_value_name/2, Env1, Values),
    Groups = dependency_groups(Values, Env2),
    Pending = maps:from_list([{group_qualified_name(Declaration, Env2), Group}
                              || Group <- Groups, Declaration <- Group]),
    Env3 = lists:foldl(fun run_group/2, Env2#env{groups = Pending, typed = [], errors = []},
                       Groups),
    Graph = reference_graph(Env3#env.typed, Env3),
    Errors = let_cycles(Env3#env.typed, Graph) ++ Env3#env.errors,
    %% restore declaration order for the typed output
    Typed = [replace_typed(Declaration, Env3#env.typed) || Declaration <- Declarations],
    Order = case Errors of
                [] ->
                    initialization_order([Declaration || Declaration <- Typed,
                                                         is_value_declaration(Declaration)], Graph);
                _ -> []
            end,
    digraph:delete(Graph),
    {Typed, Env3#env{groups = #{}, typed = [], errors = [], let_order = Order}, Errors}.

%% Report §8.5: the order the module's top-level lets are evaluated in, a
%% let after every let its initializer reaches, directly or through the
%% functions it names, and otherwise in declaration order; the cycle check
%% has passed.
-spec let_order(env()) -> [{atom() | undefined, atom()}].
let_order(#env{let_order = Order}) ->
    Order.

group_qualified_name(Declaration, Env) ->
    {Owner, Name} = declaration_key(Declaration),
    value_qualified_name(Env, Owner, Name).

%% A group is checked once, when the fold reaches it or when a definition
%% under inference demands one of its names first (report §4.8: an
%% operator names its member only once the operand type is known, so the
%% reference graph cannot order it). A failed group gets placeholders so
%% later groups report their own errors.
run_group(Group, #env{groups = Pending} = Env) ->
    Keys = [group_qualified_name(Declaration, Env) || Declaration <- Group],
    case maps:is_key(hd(Keys), Pending) of
        false ->
            Env;
        true ->
            Env1 = Env#env{groups = maps:without(Keys, Pending)},
            try check_group(Group, Env1) of
                {Typed, Env2} -> Env2#env{typed = Env2#env.typed ++ Typed}
            catch
                throw:{type_error, Span, Message} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               errors = [diagnostic(Span, Message) | Failed#env.errors]};
                throw:{type_error, #diagnostic{} = Diagnostic} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               errors = [Diagnostic | Failed#env.errors]};
                throw:{type_errors, Diagnostics} ->
                    Failed = placeholder_group(Group, Env1),
                    Failed#env{typed = Failed#env.typed ++ Group,
                               errors = Diagnostics ++ Failed#env.errors}
            end
    end.

%% A name demanded before its group ran: the group is checked now, with
%% the demanding definition's own scope set aside and restored after.
demand(QualifiedName, #env{groups = Pending} = Env) ->
    case Pending of
        #{QualifiedName := Group} ->
            Clean = Env#env{locals = #{}, effect = pure, pending = [], deferred = [],
                            annotation_variables = #{}, rigid = [], effect_origin = undefined,
                            inferring = []},
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
                effectful = Env#env.effectful, inferring = Env#env.inferring}.

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

declaration_key(#fn_declaration{owner = Owner, name = Name}) -> {Owner, Name};
declaration_key(#let_declaration{name = Name}) -> {undefined, Name};
declaration_key(#foreign_fn_declaration{owner = Owner, name = Name}) -> {Owner, Name};
declaration_key(Declaration) -> {other, ern_ast:span(Declaration)}.

value_qualified_name(#env{namespace = Namespace}, undefined, Name) -> Namespace ++ [Name];
value_qualified_name(#env{namespace = Namespace}, Owner, Name) -> Namespace ++ [Owner, Name].

register_value_name(Declaration, #env{local_values = LocalValues} = Env) ->
    {Owner, Name} = declaration_key(Declaration),
    Span = ern_ast:span(Declaration),
    Key = local_key(Owner, Name),
    not is_map_key(Key, LocalValues)
        orelse fail(Span, "value " ++ local_name(Owner, Name) ++ " is declared twice"),
    %% report §11.2: at the prompt, a member of a type the session declares
    Declared = Owner =:= undefined orelse maps:is_key(Owner, Env#env.local_types)
                   orelse session(types, Owner, Env) =/= error,
    Declared orelse fail(Span, atom_to_list(Owner) ++ " is not a type declared in this module"),
    QualifiedName = value_qualified_name(Env, Owner, Name),
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
local_key(Owner, Name) -> {Owner, Name}.

local_name(undefined, Name) -> atom_to_list(Name);
local_name(Owner, Name) -> atom_to_list(Owner) ++ "." ++ atom_to_list(Name).

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
    BlockBound = lists:foldl(fun(#fn_declaration{owner = undefined, name = Name}, InScope) ->
                                     InScope#{Name => true};
                                (_, InScope) ->
                                     InScope
                             end, Bound, Statements),
    {Acc1, _} = lists:foldl(fun(Statement, FoundAndScope) ->
                                statement_references(Statement, FoundAndScope, Env)
                            end, {Acc, BlockBound}, Statements),
    Acc1;
references_in(#e_var{path = [], name = Name}, _Env, Acc, Bound) when is_map_key(Name, Bound) -> Acc;
references_in(#e_var{path = [], name = Name}, _Env, Acc, _Bound) -> [{undefined, Name} | Acc];
references_in(#e_var{path = Namespace, name = Name}, #env{namespace = Namespace}, Acc, _Bound)
  when Namespace =/= [] ->
    %% the module's own qualified name (report §4.2), which a local binding
    %% of the same name does not hide
    [{undefined, Name} | Acc];
references_in(#e_var{path = [Owner], name = Name}, #env{local_types = LocalTypes}, Acc, _Bound) ->
    case maps:is_key(Owner, LocalTypes) of true -> [{Owner, Name} | Acc]; false -> Acc end;
references_in(#e_var{path = Path} = Variable, #env{namespace = Namespace} = Env, Acc, Bound)
  when length(Path) > 1 ->
    case own_type_path(Path, Namespace) of
        true -> references_in(Variable#e_var{path = [lists:last(Path)]}, Env, Acc, Bound);
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

references_in_pattern(Pattern, Env, Acc, Bound) ->
    case Pattern of
        #bit_segment{specs = Specs} -> references_in(Specs, Env, Acc, Bound);
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
            Owner = lists:last(QualifiedName),
            case own_type_path(QualifiedName, Namespace) andalso maps:is_key(Owner, LocalTypes) of
                true -> [{Owner, Member}];
                false -> []
            end;
        _ ->
            []
    end.

%% Report §4.2: is Path the module's own namespace and one name below it,
%% as `M.T` in module M, where T may be a type the module declares?
own_type_path(Path, Namespace) ->
    length(Path) =:= length(Namespace) + 1 andalso lists:prefix(Namespace, Path).

%% A group failed: give its names a fresh polymorphic type so that later
%% groups report their own errors rather than cascades.
placeholder_group(Group, Env) ->
    lists:foldl(fun(Declaration, Acc) ->
                    {Owner, Name} = declaration_key(Declaration),
                    {Variable, TypeState} = ern_types:fresh(ern_types:enter(Acc#env.type_state)),
                    {Scheme, TypeState1} = ern_types:generalize(Variable,
                                                                ern_types:leave(TypeState)),
                    QualifiedName = value_qualified_name(Acc, Owner, Name),
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
    Typed = [TypedDeclaration || {TypedDeclaration, _} <- TypedAndPost],
    Env4 = lists:foldl(fun({_, Post}, Acc) -> post_checks(Post, Acc) end, Env3, TypedAndPost),
    Env5 = Env4#env{type_state = ern_types:leave(Env4#env.type_state),
                    inferring = Env#env.inferring},
    %% generalize and publish; the typed AST is substituted so consumers read
    %% resolved types off the nodes
    Publish = fun(Declaration, Acc) -> publish(Declaration, Placeholder(Declaration), Acc) end,
    lists:mapfoldl(Publish, Env5, Typed).

%% A member's placeholder among the globals, its definition under inference.
declare_placeholder({{Owner, Name}, Variable}, Env) ->
    QualifiedName = value_qualified_name(Env, Owner, Name),
    Env#env{globals = maps:put(QualifiedName, ern_types:monomorphic(Variable), Env#env.globals),
            inferring = [{global, QualifiedName} | Env#env.inferring]}.

%% A checked member generalized, its shape as a member checked, and its
%% scheme published and set on its typed declaration.
publish(Declaration, Variable, Env) ->
    {Owner, Name} = declaration_key(Declaration),
    {Scheme, TypeState} = generalized(Declaration, Variable, Env),
    member_shape(Declaration, Scheme, Env#env{type_state = TypeState}),
    QualifiedName = value_qualified_name(Env, Owner, Name),
    Env1 = Env#env{type_state = TypeState,
                   globals = maps:put(QualifiedName, Scheme, Env#env.globals)},
    {substitute_ast(set_declaration_scheme(Declaration, Scheme), TypeState), Env1}.

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
            {OwnerType, TypeState} = case Params of
                                         [{tcon, TypeQualifiedName, _} = First | _] ->
                                             {First, Env#env.type_state};
                                         _ -> own_type(TypeQualifiedName, Env)
                                     end,
            Result = case Member of
                         compare -> {tcon, ['Ordering'], []};
                         _ -> ResultType
                     end,
            Expected = {tfn, lists:duplicate(Arity, OwnerType), pure, Result},
            case ern_types:substitute({tfn, Params, Effect, ResultType}, TypeState) =:= Expected of
                true ->
                    ok;
                false ->
                    Shown = fun(Type) ->
                                ern_types:format_scheme(Scheme#scheme{type = Type}, TypeState)
                            end,
                    fail(ern_ast:span(Declaration),
                         format_qualified_name([lists:last(TypeQualifiedName), Member])
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
    {Owner, Name} = declaration_key(Declaration),
    Member = lists:member(Name, [compare, negate | ?ARITH ++ ['<>']]),
    Builtin = case Namespace of
                  [TypeName] -> lists:member(TypeName, ern_prelude:member_types());
                  _ -> false
              end,
    case {Member, Owner} of
        {false, _} -> none;
        {true, undefined} when Builtin -> {Namespace, Name};
        {true, undefined} -> none;
        {true, _} -> {owner_qualified_name(Owner, Env), Name}
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
                 format_qualified_name([lists:last(TypeQualifiedName), compare])
                 ++ " must have the type "
                 ++ Shown({tfn, [Self, Self], pure, {tcon, ['Ordering'], []}})
                 ++ ", not " ++ Shown({tfn, Params, pure, ResultType}), [],
                 "compare takes two values of its type, returns an Ordering, and is pure");
        _ ->
            ok
    end.

%% Report §11.2: the type a member names, the module's own or, at the
%% prompt, one the session declared.
owner_qualified_name(Owner, #env{local_types = LocalTypes} = Env) ->
    case LocalTypes of
        #{Owner := QualifiedName} -> QualifiedName;
        _ -> {ok, QualifiedName} = session(types, Owner, Env), QualifiedName
    end.

%% The type TypeQualifiedName over fresh variables, for its parameters.
own_type(TypeQualifiedName, #env{types = Types, type_state = TypeState}) ->
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
    Lets = lists:keysort(2, [Declaration || #let_declaration{} = Declaration <- Declarations]),
    Fns = [declaration_key(Declaration) || #fn_declaration{} = Declaration <- Declarations],
    {Errors, _} = lists:foldl(fun(Declaration, {Acc, Seen}) ->
                                  let_cycle(Declaration, Graph, Fns, Acc, Seen)
                              end, {[], []}, Lets),
    lists:reverse(Errors).

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
          Errors, Seen) ->
    Key = declaration_key(Declaration),
    case lists:member(Key, Seen) of
        true ->
            {Errors, Seen};
        false ->
            case digraph:get_cycle(Graph, Key) of
                false ->
                    {Errors, Seen};
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
                                      Names = [local_name(Owner, ValueName)
                                               || {Owner, ValueName} <- Between],
                                      ", through " ++ lists:join(", ", Names)
                              end,
                    Message = lists:flatten(["the initializer of ", LetName, " depends on itself",
                                             Through]),
                    Help = cycle_help(LetName, Body, Between, Fns),
                    {[(diagnostic(Span, Message))#diagnostic{help = Help} | Errors], Cycle ++ Seen}
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
    {Owner, Reader} = lists:last(Between),
    case lists:member({Owner, Reader}, Fns) of
        true ->
            lists:flatten(["`", local_name(Owner, Reader), "` reads ", LetName,
                           " when it is called; a `fn ", LetName, "() = ...` builds the value"
                           " when it is asked for"]);
        false ->
            undefined
    end.

%% Unify a placeholder with what the annotations say, before any body. A
%% local fn's annotations name the enclosing definition's variables where
%% they share a name (report §3.9).
signature_shape(#fn_declaration{params = Params, result_type = ResultAnnotation, effect = Effect},
                Placeholder, Env) ->
    ParamType = fun(Param, {Acc, TypeStateAcc}) ->
                    {Type, Acc1, TypeStateAcc1} =
                        param_type(Param, Acc, Env#env{type_state = TypeStateAcc}),
                    {Type, {Acc1, TypeStateAcc1}}
                end,
    {ParamTypes, {AnnotationVariables, TypeState1}} =
        lists:mapfoldl(ParamType, {Env#env.annotation_variables, Env#env.type_state}, Params),
    {ResultType, EffectType, _, TypeState2} =
        return_annotation(ResultAnnotation, Effect, AnnotationVariables,
                          Env#env{type_state = TypeState1}),
    FunctionType = {tfn, ParamTypes, EffectType, ResultType},
    bound(Placeholder, FunctionType,
          Env#env{type_state = mark_process_only(FunctionType, TypeState2)});
signature_shape(#let_declaration{annotation = Annotation}, Placeholder, Env)
  when Annotation =/= undefined ->
    {Type, _, TypeState} = annotation_type(Annotation, #{}, Env),
    bound(Placeholder, Type, Env#env{type_state = TypeState});
signature_shape(#foreign_fn_declaration{span = Span, params = Params,
                                        result_type = ResultAnnotation, effect = Effect},
                Placeholder, Env) ->
    Syntax = #t_fn{span = Span, params = [Type || #param{annotation = Type} <- Params],
                   result_type = ResultAnnotation, effect = Effect},
    {Type, _, TypeState} = annotation_type(Syntax, #{}, Env),
    bound(Placeholder, Type,
          Env#env{type_state = not_reply_carrying_params(Type, foreign_effect(Type, TypeState))});
signature_shape(_, _, Env) ->
    Env.

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
                            effect = Effect, body = Body} = Declaration,
            Placeholder, Env) ->
    %% report §3.9: a local fn's signature shares the enclosing one's
    %% variables; at top level there are none
    {TypedParams, ParamTypes, Env1, AnnotationVariables} =
        bind_params(Params, Env, Env#env.annotation_variables),
    {ResultType, EffectType, AnnotationVariables1, TypeState} =
        return_annotation(ResultAnnotation, Effect, AnnotationVariables, Env1),
    FunctionType = {tfn, ParamTypes, EffectType, ResultType},
    %% report §4.5, §11.5: a recursive call is at the definition's own type,
    %% so the name has it before the body is read, and a call at another
    %% type is refused at its argument, as any call is
    Env2 = unify_at(Span, Placeholder, FunctionType, Env1#env{type_state = TypeState},
                    "recursive use does not match the definition"),
    TypeState2 = Env2#env.type_state,
    Origin = effect_origin(declaration_name(Declaration), ResultAnnotation, Effect, ResultType,
                           EffectType, TypeState2),
    Env3 = Env2#env{type_state = mark_process_only(FunctionType, TypeState2), effect = EffectType,
                    pending = [], deferred = [], annotation_variables = AnnotationVariables1,
                    rigid = maps:to_list(AnnotationVariables1), effect_origin = Origin},
    early_compare_shape(Declaration, ResultAnnotation, FunctionType, Env3),
    Context = result_context(ResultAnnotation, "the body does not have the declared result type"),
    ResultOrigin = result_origin(ResultAnnotation, ResultType, Env3),
    {TypedBody, _BodyType, Env4} = check_expr(Body, ResultType, Context, ResultOrigin, Env3),
    Env5 = unify_at(Span, Placeholder, FunctionType, Env4,
                    "recursive use does not match the definition"),
    {Declaration#fn_declaration{params = TypedParams, body = TypedBody},
     post(Span, TypedParams, TypedBody, FunctionType, Env5), restore_scope(Env5, Env)};
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
    Env3 = unify_at(Span, BodyType, Placeholder, Env2,
                    "recursive use does not match the definition"),
    Effectful = case Env3#env.effectful of
                    true -> [declaration_key(Declaration) | Env#env.effectful_lets];
                    false -> Env#env.effectful_lets
                end,
    {Declaration#let_declaration{body = TypedBody}, post(Span, [], TypedBody, BodyType, Env3),
     (restore_scope(Env3, Env))#env{effectful_lets = Effectful}};
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
        error ->
            fail(ErrorSpan, io_lib:format("the implementation of ~s is named"
                                          " module:function/arity, here module:function/~B",
                                          [declaration_name(Declaration), length(Params)]))
    end,
    %% its type is its signature's, which signature_shape gave it
    {Declaration, none, Env}.

post(Span, TypedParams, TypedBody, Type, Env) ->
    #post_check{span = Span, params = TypedParams, body = TypedBody, type = Type,
                effect = Env#env.effect, effect_origin = Env#env.effect_origin,
                rigid = Env#env.rigid, pending = Env#env.pending, deferred = Env#env.deferred}.

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

%% Report §8.4: the implementation name of a foreign fn, module:function/arity.
-spec foreign_implementation(binary()) -> {ok, {atom(), atom(), non_neg_integer()}} | error.
foreign_implementation(Implementation) ->
    case re:run(Implementation, "^([a-z][A-Za-z0-9_@]*):([a-z][A-Za-z0-9_]*)/([0-9]+)$",
                %% `$` at the very end, not before a final line feed
                [dollar_endonly, {capture, all_but_first, list}]) of
        {match, [Module, Function, Arity]} ->
            {ok, {list_to_atom(Module), list_to_atom(Function), list_to_integer(Arity)}};
        nomatch -> error
    end.

%% Parameters bind pattern variables monomorphically; annotation variables
%% are shared across the parameters and the return annotation.
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

return_annotation(undefined, _Effect, AnnotationVariables, Env) ->
    {ResultType, TypeState1} = ern_types:fresh(Env#env.type_state),
    {EffectType, TypeState2} = ern_types:fresh_effect(TypeState1),
    {ResultType, EffectType, AnnotationVariables, TypeState2};
return_annotation(ResultAnnotation, Effect, AnnotationVariables, Env) ->
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

%% Report §11.5: the labels an error carries. A return annotation is the
%% origin of the body's expected type; a `with` or a bare `->` is the
%% origin of the function's effect.
result_context(undefined, _Context) -> undefined;
result_context(_ResultAnnotation, Context) -> Context.

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
    {Owner, Name} = declaration_key(Declaration),
    local_name(Owner, Name).


bind_locals(Bindings, #env{locals = Locals} = Env) ->
    Bind = fun({Name, Type}, Acc) -> Acc#{Name => ern_types:monomorphic(Type)} end,
    Env#env{locals = lists:foldl(Bind, Locals, Bindings)}.

%%
%% Post checks per definition
%%

post_checks(none, Env) ->
    Env;
post_checks(#post_check{span = Span, params = TypedParams, body = TypedBody,
                         type = FunctionType, effect = Effect, effect_origin = Origin,
                         rigid = Rigid, pending = Pending, deferred = Deferred},
            Env) ->
    {Shown, Resolved} = lists:partition(fun(Item) -> is_record(Item, deferred_show) end,
                                        Deferred),
    Env1 = solve_deferred(Env#env{effect = Effect, effect_origin = Origin, pending = Pending,
                                  deferred = Resolved}),
    lists:foreach(fun(Item) -> known_whole(Item, Env1) end, Shown),
    rigid_annotation_variables(Span, Rigid, Env1),
    ern_scope:order(TypedBody),
    ern_exhaust:check(TypedBody, Env1),
    Env2 = ern_reply:check(TypedParams, TypedBody, FunctionType, Env1),
    check_pending_restrictions(Env2),
    Env2#env{effect = Env#env.effect, effect_origin = Env#env.effect_origin,
             pending = Env#env.pending, deferred = Env#env.deferred}.

%% Report Appendix E.1: `Io.show` and `Io.debug` write a value by the type
%% at which the name is used, as a callee or an argument, the library's
%% own uses in io.ern among them; the type is read once the definition is
%% inferred, as an operator's operand type is (§4.8).
shown(Span, Referent, Type, #env{namespace = Namespace}) ->
    Name = case Referent of
               #remote_declaration{namespace = ['Io'], owner = undefined, name = Called} -> Called;
               #own_declaration{owner = undefined, name = Called} when Namespace =:= ['Io'] ->
                   Called;
               _ -> none
           end,
    case {lists:member(Name, [show, debug]), Type} of
        {true, {tfn, [Argument], _, _}} ->
            [#deferred_show{span = Span, name = Name, argument = Argument}];
        _ ->
            []
    end.

%% It must be known whole, with no type variable in it; an effect variable
%% changes nothing written, a function being `<function>`.
known_whole(#deferred_show{span = Span, name = Name, argument = Argument},
            #env{type_state = TypeState}) ->
    Type = ern_types:substitute(Argument, TypeState),
    case ern_types:value_variables(Type, TypeState) of
        [] ->
            ok;
        _ ->
            fail(Span, "Io." ++ atom_to_list(Name)
                       ++ " writes a value by its type, which is not known whole here: "
                       ++ ern_types:format(Type, TypeState), [],
                 "annotate the value where it is bound; a function generic in the type takes"
                 " one that shows it, `(a) -> String`, from its caller")
    end.

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
        false -> unresolved(hd(Left))
    end.

%% What is still unknown when nothing more resolves is an error, the first
%% one reported.
-spec unresolved(tuple()) -> no_return().
unresolved(#deferred_bind_arrow{span = Span}) ->
    fail(Span, "`<-` needs to know whether the value is an Either or an Optional; annotate it");
unresolved(#deferred_operator{span = Span, operator = Operator}) ->
    %% report §4.8: resolution precedes generalization
    fail(Span, "the operand type of `" ++ atom_to_list(Operator)
               ++ "` is not determined; annotate it");
unresolved(#deferred_selection{span = Span, field = Field}) ->
    fail(Span, "the type whose field " ++ atom_to_list(Field)
               ++ " is read is not determined; annotate it").

solve_one(#deferred_selection{span = Span, field = Field, expr_type = ExprType, result = Result,
                              origin = Origin},
          Env) ->
    case ern_types:resolve(ExprType, Env#env.type_state) of
        {tvar, _} -> unsolved;
        _ ->
            {Closed, Env1} = resolve_select(Span, Field, ExprType, Env),
            %% opened as a selection resolved at once is (report §3.9)
            {Opened, TypeState} = open_effect(Closed, Env1#env.type_state),
            {solved, unify_at(Span, Result, Opened, Env1#env{type_state = TypeState},
                              "the field " ++ atom_to_list(Field), Origin)}
    end;
solve_one(#deferred_operator{span = Span, operator = Operator, operand_type = OperandType,
                             result = Result, origin = Origin},
          Env) ->
    case ern_types:resolve(OperandType, Env#env.type_state) of
        {tvar, _} -> unsolved;
        _ ->
            {Closed, Env1} = resolve_operator(Span, Operator, OperandType, Env),
            {Opened, TypeState} = open_effect(Closed, Env1#env.type_state),
            {solved, unify_at(Span, Result, Opened, Env1#env{type_state = TypeState},
                              "the result of `" ++ operator_text(Operator) ++ "`", Origin)}
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

fixed_label({last, Span}, RestType, TypeState) ->
    {Span, "the block's value has type " ++ ern_types:format(RestType, TypeState)};
fixed_label(Origin, _, _) ->
    Origin.

%% Restrictions checked at instantiation (report §3.9, §3.10): a
%% not-reply-carrying variable bound to a reply-carrying type, an
%% equality-constrained one bound to a type containing a function or an
%% address. They are checked in the order they stand in the source, so
%% that the one reported is the first place that needed the restriction: a
%% map's first operation, and a comparison before a later use that made
%% its type one without equality.
check_pending_restrictions(#env{pending = Pending} = Env) ->
    Ordered = lists:sort(fun(First, Second) -> place(First) =< place(Second) end, Pending),
    lists:foreach(fun(Restriction) -> check_pending(Restriction, Env) end, Ordered).

%% Report §11.5: at a rejected call site the error names the function and
%% shows the restriction its type carries.
check_pending(#pending_restriction{restriction = not_reply_carrying, id = Id, span = Span,
                                   who = Who},
              Env) ->
    Type = ern_types:substitute({tvar, Id}, Env#env.type_state),
    not is_reply_carrying(Type, Env)
        orelse fail(Span, "a reply-carrying value, " ++ ern_types:format(Type, Env#env.type_state)
                          ++ ", passed where " ++ who(Who, "the function")
                          ++ " duplicates or discards its argument" ++ signature_of(Who), [],
                    "a reply is discharged by answering it, passing it on once, or matching it"
                    " (§6.6)");
check_pending(#pending_restriction{restriction = equality, id = Id, span = Span, need = Need,
                                   who = Who},
              Env) ->
    Type = ern_types:substitute({tvar, Id}, Env#env.type_state),
    case lacks_equality(Type, Env) of
        false ->
            ok;
        Lack ->
            fail(Span, ern_types:format(Type, Env#env.type_state) ++ " does not support equality ("
                       ++ Lack ++ "), " ++ need_text(Need, Who) ++ identity_hint(Type))
    end.

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
need_text(Need, _) -> Need.

%% The restrictions an instance of a scheme carries, checked when its
%% definition ends: each not-reply-carrying variable, and each
%% equality-constrained one with what needs the equality: a Map's key or a
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
        map -> "and a Map's key needs it";
        set -> "and a Set's element needs it";
        none -> compared
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
        {tvar, _} ->
            {Result, TypeState} = ern_types:fresh(Env#env.type_state),
            Deferred = #deferred_operator{span = Span, operator = Operator,
                                          operand_type = OperandType, result = Result},
            {Result, Env#env{type_state = TypeState, deferred = [Deferred | Env#env.deferred]}};
        _ ->
            resolve_operator(Span, Operator, OperandType, Env)
    end.

%% Report §3.5, §4.8: a field selection resolves against its operand's type
%% as an operator does, deferred while that type is still a variable.
select_result(Span, Field, ExprType, Env) ->
    case ern_types:resolve(ExprType, Env#env.type_state) of
        {tvar, _} ->
            {Result, TypeState} = ern_types:fresh(Env#env.type_state),
            Deferred = #deferred_selection{span = Span, field = Field, expr_type = ExprType,
                                           result = Result},
            {Result, Env#env{type_state = TypeState, deferred = [Deferred | Env#env.deferred]}};
        _ ->
            resolve_select(Span, Field, ExprType, Env)
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
resolve_select(Span, Field, ExprType,
               #env{type_state = TypeState, types = Types, local_types = LocalTypes} = Env) ->
    Type = ern_types:resolve(ExprType, TypeState),
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
                    erlang:error({undeclared_type, format_qualified_name(QualifiedName)})
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
    Name = format_qualified_name([lists:last(QualifiedName), Member]),
    case member_scheme(QualifiedName, Member, Env) of
        {undefined, Env1} -> not_defined(Span, Operator, OperandType, Env1);
        {Scheme, Env1} ->
            {MemberType, TypeState1} = ern_types:instantiate(Scheme, Env1#env.type_state),
            %% as a reference to the member would, report §3.9
            Pending = instance_pending(MemberType, Span, TypeState1),
            {Effect, TypeState2} = ern_types:fresh_effect(TypeState1),
            {Result, TypeState3} = ern_types:fresh(TypeState2),
            {Operands, Context} =
                case Operator of
                    negate -> {[OperandType], Name ++ " does not fit an operand of "};
                    _ -> {[OperandType, OperandType], Name ++ " does not fit two operands of "}
                end,
            Declared = member_declared(QualifiedName, Member, Name, MemberType,
                                       Env1#env{type_state = TypeState3}),
            Env2 = unify_at(Span, {tfn, Operands, Effect, Result}, MemberType,
                            Env1#env{type_state = TypeState3,
                                     pending = Pending ++ Env1#env.pending},
                            Context ++ ern_types:format(OperandType, TypeState3), Declared),
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
    IsOwn = own_type_path(QualifiedName, Namespace),
    case [Declaration || Declaration <- Typed, IsOwn,
                         declaration_key(Declaration) =:= {lists:last(QualifiedName), Member}] of
        [Declaration | _] ->
            {head_span(Declaration), Name ++ " : " ++ ern_types:format(MemberType, TypeState)};
        [] -> undefined
    end.

%% A declaration's head, through its return annotation where it has one.
head_span(#fn_declaration{span = Span, result_type = ResultAnnotation})
  when ResultAnnotation =/= undefined ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {_, _, End} = ern_diagnostic:span(ern_ast:span(ResultAnnotation)),
    {Line, Column, End};
head_span(Declaration) ->
    ern_ast:span(Declaration).

-spec not_defined(ern_diagnostic:position(), atom(), term(), env()) -> no_return().
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
    Key = case own_type_path(QualifiedName, Namespace) of
              true -> maps:get({lists:last(QualifiedName), Member}, LocalValues, undefined);
              false -> session_member(QualifiedName, Member, Env)
          end,
    case Key of
        undefined -> {undefined, Env};
        _ ->
            Env1 = demand(Key, Env),
            {maps:get(Key, Env1#env.globals, undefined), Env1}
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

%% Report §11.2: the type of a name as its declaration writes it, for the
%% shell's input that is one name; the scheme keeps the declaration's
%% variable names, which an instance does not.
-spec declared_scheme(env(), [atom()], atom()) -> {ok, #scheme{}} | error.
declared_scheme(Env, Path, Name) ->
    %% the position is never shown: an unknown name answers `error`
    try lookup_value({1, 1, {1, 1}}, Path, Name, Env) of
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
                    {Fresh, TypeState1} = ern_types:fresh_effect(TypeState),
                    {{tfn, Params, Fresh, Result}, TypeState1};
                _ -> {Type, TypeState}
            end;
        _ -> {Type, TypeState}
    end.

infer(#e_literal{kind = Kind} = Expr, Env) ->
    Type = literal_type(Kind),
    {Expr#e_literal{type = Type}, Type, Env};
infer(#e_var{span = Span, path = Path, name = Name} = Expr, Env) ->
    %% report §11.2: a name the session declared resolves to the input that
    %% declared it, which its referent records; its path stays as written
    {Scheme, Referent, Env1} = lookup_value(Span, Path, Name, Env),
    {Closed, Instantiated} = ern_types:instantiate(Scheme, Env1#env.type_state),
    {Type, TypeState} = open_effect(Closed, Instantiated),
    Who = case Scheme of
              #scheme{quantified = []} -> undefined;
              _ ->
                  {format_qualified_name(Path ++ [Name]),
                   ern_types:format_scheme(Scheme, TypeState)}
          end,
    Pending = instance_pending(Type, Span, TypeState, Who),
    Deferred = shown(Span, Referent, Type, Env1) ++ Env1#env.deferred,
    %% report §4.2: what the name resolved to is recorded, so that the
    %% emitter reads the decision rather than making it again
    {Expr#e_var{type = Type, referent = Referent}, Type,
     Env1#env{type_state = TypeState, pending = Pending ++ Env1#env.pending, deferred = Deferred}};
infer(#e_constructor{span = Span, path = Path, name = Name, args = Args} = Expr, Env) ->
    ConstructorInfo = lookup_constructor(Span, Path, Name, Env),
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
            {TypedArg, _ArgType, Env3} = check_expr(Arg, FieldType,
                                                    "the field of " ++ atom_to_list(Name),
                                                    undefined, Env1),
            {Expr#e_constructor{args = {positional, TypedArg}, type = Constructed}, Constructed,
             Env3};
        {positional, none} ->
            %% a single-positional constructor is a function value (§5.6)
            {Opened, TypeState1} = open_effect(ConstructorType, TypeState),
            {Expr#e_constructor{type = Opened}, Opened, Env1#env{type_state = TypeState1}};
        {positional, {named, _, _}} ->
            fail(Span, atom_to_list(Name) ++ " has one positional field, not named fields");
        {{named, Names}, {named, Base, FieldSets}} ->
            {tfn, FieldTypes, pure, Constructed} = ConstructorType,
            Base =:= undefined orelse one_constructor(Span, ConstructorInfo, Env1),
            infer_named(Expr, Names, FieldTypes, Constructed, Base, FieldSets, Env1);
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
            Origin = {ern_ast:span(Callee),
                      Name ++ " : " ++ ern_types:format(CalleeType, Env1#env.type_state)},
            Context = argument_context(Name, TypedCallee, Env1),
            Check = fun({Arg, ParamType}, Acc) ->
                        {TypedArg, _, Acc1} = check_expr(Arg, ParamType, Context, Origin, Acc),
                        {TypedArg, Acc1}
                    end,
            {TypedArgs, Env2} = lists:mapfoldl(Check, Env1, lists:zip(Args, ParamTypes)),
            Env3 = use_effect(Span, Name, Effect, Env2),
            {Opened, TypeState1} = open_effect(ResultType, Env3#env.type_state),
            {Expr#e_call{callee = TypedCallee, args = TypedArgs, type = Opened, returns = Returns},
             Opened, Env3#env{type_state = TypeState1}};
        {tvar, _} ->
            {TypedArgs, ArgTypes, Env2} = infer_list(Args, Env1),
            {ResultType, TypeState} = ern_types:fresh(Env2#env.type_state),
            {Effect, TypeState1} = ern_types:fresh_effect(TypeState),
            Env3 = unify_at(Span, CalleeType, {tfn, ArgTypes, Effect, ResultType},
                            Env2#env{type_state = TypeState1},
                            "calling " ++ Name ++ " needs it to be a function"),
            Env4 = use_effect(Span, Name, Effect, Env3),
            {Expr#e_call{callee = TypedCallee, args = TypedArgs, type = ResultType}, ResultType,
             Env4};
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
    {Expr#e_negation{expr = TypedOperand, type = Type}, Type, Env2#env{type_state = TypeState}};
infer(#e_binop{span = Span, operator = Operator, left = Left, right = Right} = Expr, Env) ->
    {TypedLeft, LeftType, Env1} = infer(Left, Env),
    {TypedRight, RightType, Env2} = infer(Right, Env1),
    {Closed, Env3} = binop_type(Span, Operator, Left, LeftType, Right, RightType, Env2),
    {Type, TypeState} = open_effect(Closed, Env3#env.type_state),
    {Expr#e_binop{left = TypedLeft, right = TypedRight, type = Type}, Type,
     Env3#env{type_state = TypeState}};
infer(#e_lambda{span = LambdaSpan, params = Params, result_type = ResultAnnotation,
                effect = Effect, body = Body} = Expr, Env) ->
    {TypedParams, ParamTypes, Env1, AnnotationVariables} =
        bind_params(Params, Env, Env#env.annotation_variables),
    {ResultType, EffectType, AnnotationVariables1, TypeState} =
        return_annotation(ResultAnnotation, Effect, AnnotationVariables, Env1),
    Type = {tfn, ParamTypes, EffectType, ResultType},
    %% report §3.9: the definition's annotation variables are in scope and
    %% rigid; a name new here means every type, as it does in a `fn`, and
    %% is rigid where the lambda is generalized; one that is not generalized
    %% may name none. A regression: a new name was the lambda's own and not
    %% rigid, so `fn(x : a) : a = x + 1` made `a` an Int
    New = [{Name, Variable} || Name := Variable <- AnnotationVariables1,
                               not is_map_key(Name, Env#env.annotation_variables)],
    New =:= [] orelse Env#env.generalizing orelse
        fail(LambdaSpan, "type variable " ++ atom_to_list(lists:min([Name || {Name, _} <- New]))
                         ++ " in the lambda's annotation means every type, and the lambda is not"
                         " generalized", [],
             "write the type, or leave the annotation out"),
    Env2 = Env1#env{type_state = mark_process_only(Type, TypeState), effect = EffectType,
                    annotation_variables = AnnotationVariables1,
                    generalizing = false, rigid = New ++ Env1#env.rigid,
                    %% report §11.5: the label names the annotation that fixed the
                    %% mailbox, and an unannotated lambda's is its own, not the
                    %% enclosing definition's
                    effect_origin = effect_origin("the lambda", ResultAnnotation, Effect,
                                                  ResultType, EffectType, TypeState)},
    Context = result_context(ResultAnnotation, "the lambda body does not have the declared type"),
    ResultOrigin = result_origin(ResultAnnotation, ResultType, Env2),
    {TypedBody, _BodyType, Env4} = check_expr(Body, ResultType, Context, ResultOrigin, Env2),
    rigid_annotation_variables(LambdaSpan, New, Env4),
    %% the body was checked as the annotation says; a lambda written pure
    %% stands where one with a mailbox type is expected, as any expression
    %% of a pure function type does (report §3.9)
    {Opened, TypeState4} = open_effect(Type, Env4#env.type_state),
    {Expr#e_lambda{params = TypedParams, body = TypedBody, type = Type}, Opened,
     Env4#env{type_state = TypeState4, locals = Env#env.locals, effect = Env#env.effect,
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
%% statement, so a mismatch is reported at the leaf; Context names the
%% rule and Origin the span that fixed the expectation, or undefined when
%% it is the first branch, which then becomes the origin for the rest.
check_expr(#e_if{condition = Condition, then_branch = Then, else_branch = Else} = Expr,
           Expected, Context, Origin, Env) ->
    {TypedCondition, _, Env1} =
        check_expr(Condition, ?BOOL, "the condition of `if`", undefined, Env),
    {TypedThen, _, Env2} = check_expr(Then, Expected, Context, Origin, Env1),
    {Context1, Origin1} = sibling(Context, Origin, "the branches of `if` must have one type",
                                  Then, "the then branch", Expected, Env2),
    {TypedElse, _, Env3} = check_expr(Else, Expected, Context1, Origin1, Env2),
    {Expr#e_if{condition = TypedCondition, then_branch = TypedThen, else_branch = TypedElse,
               type = Expected},
     Expected, Env3};
check_expr(#e_match{scrutinee = Scrutinee, clauses = Clauses} = Expr, Expected, Context,
           Origin, Env) ->
    {TypedScrutinee, ScrutineeType, Env1} = infer(Scrutinee, Env),
    ScrutineeOrigin = {ern_ast:span(Scrutinee), "the value matched has type "
                       ++ ern_types:format(ScrutineeType, Env1#env.type_state)},
    {TypedClauses, Env2} = check_clauses(match, Clauses, ScrutineeType, ScrutineeOrigin,
                                         Expected, Context, Origin,
                                         "the clauses must have one type", Env1),
    {Expr#e_match{scrutinee = TypedScrutinee, clauses = TypedClauses, type = Expected}, Expected,
     Env2};
check_expr(#e_receive{span = Span, clauses = Clauses, 'after' = After} = Expr, Expected, Context,
           Origin, Env) ->
    {MailboxType, Env1} = mailbox_type(Span, Env),
    case Clauses =/= [] andalso ern_types:resolve(MailboxType, Env1#env.type_state) =:= ?NEVER of
        true -> never_receives(Span, Env1#env.effect_origin);
        false -> ok
    end,
    {TypedClauses, Env2} = check_clauses('receive', Clauses, MailboxType, undefined, Expected,
                                         Context, Origin, "the clauses must have one type", Env1),
    {TypedAfter, Env3} =
        case After of
            undefined -> {undefined, Env2};
            #after_clause{timeout = Timeout, body = Body} = AfterClause ->
                {TypedTimeout, _, AfterEnv1} =
                    check_expr(Timeout, ?INT, "the `after` time is in milliseconds", undefined,
                               Env2),
                {Context1, Origin1} =
                    case {Clauses, Origin} of
                        {[#clause{body = First} | _], undefined} ->
                            sibling(Context, Origin, "the `after` body must have the clauses'"
                                    " type", First, "the first clause", Expected, AfterEnv1);
                        _ -> {Context, Origin}
                    end,
                {TypedBody, _, AfterEnv2} =
                    check_expr(Body, Expected, Context1, Origin1, AfterEnv1),
                {AfterClause#after_clause{timeout = TypedTimeout, body = TypedBody}, AfterEnv2}
        end,
    {Expr#e_receive{clauses = TypedClauses, 'after' = TypedAfter, type = Expected}, Expected, Env3};
check_expr(#e_block{span = Span, statements = Statements} = Expr, Expected, Context, Origin, Env) ->
    {TypedStatements, Type, Env1} = infer_block(Statements, Span, {Expected, Context, Origin}, Env),
    {Expr#e_block{statements = TypedStatements, type = Type}, Type,
     Env1#env{locals = Env#env.locals}};
check_expr(Expr, Expected, undefined, _Origin, Env) ->
    %% the first branch where nothing fixed the type: the expectation is a
    %% fresh variable, which the branch fixes
    {Typed, Type, Env1} = infer(Expr, Env),
    {Typed, Type, bound(Expected, Type, Env1)};
check_expr(Expr, Expected, Context, Origin, Env) ->
    {Typed, Type, Env1} = infer(Expr, Env),
    {Typed, Type,
     unify_at(ern_ast:span(Expr), Expected, Type, expecting(Type, Origin, Env1), Context, Origin)}.

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

%% Report §6.3: a receive guard is a guard expression, since it selects a
%% message without removing it: `true`, `false`, a Bool operand, or a
%% comparison of two operands, under `!`, `&&`, and `||`. The guard is
%% already a Bool, so a bare operand is a Bool one.
receive_guard(#e_binop{operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '&&'; Operator =:= '||' ->
    receive_guard(Left, Env),
    receive_guard(Right, Env);
receive_guard(#e_binop{operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '=='; Operator =:= '!=' ->
    guard_operand(Left, Env),
    guard_operand(Right, Env);
receive_guard(#e_binop{span = Span, operator = Operator, left = Left, right = Right}, Env)
  when Operator =:= '<'; Operator =:= '<='; Operator =:= '>'; Operator =:= '>=' ->
    case ern_types:resolve(node_type(Left), Env#env.type_state) of
        Type when Type =:= ?INT; Type =:= ?FLOAT; Type =:= ?STRING; Type =:= ?CHAR -> ok;
        Type -> fail(Span, "a `receive` guard orders only Int, Float, String, and Char, not "
                           ++ ern_types:format(Type, Env#env.type_state))
    end,
    guard_operand(Left, Env),
    guard_operand(Right, Env);
receive_guard(#e_not{expr = Operand}, Env) -> receive_guard(Operand, Env);
receive_guard(#e_literal{kind = bool}, _) -> ok;
receive_guard(#e_var{} = Variable, Env) -> guard_operand(Variable, Env);
receive_guard(Guard, _) ->
    fail(ern_ast:span(Guard), "a `receive` guard combines `true`, `false`, Bool variables, and"
                           " comparisons with `!`, `&&`, and `||`, and calls nothing",
         [], "receive the message and `match` it").

%% An operand: a variable of the pattern or of the enclosing function, a
%% top-level `let`, which the `receive` reads before it waits, a literal, a
%% negative numeric literal, or a nullary constructor. A regression: a
%% top-level binding was refused, the host's guard showing through.
guard_operand(#e_literal{}, _) -> ok;
guard_operand(#e_negation{expr = #e_literal{kind = Kind}}, _) when Kind =:= int; Kind =:= float ->
    ok;
guard_operand(#e_constructor{args = none}, _) -> ok;
guard_operand(#e_var{path = [], name = Name}, #env{locals = Locals})
  when is_map_key(Name, Locals) ->
    ok;
guard_operand(#e_var{referent = Referent} = Variable, Env) ->
    top_let(Referent, Env)
        orelse fail(ern_ast:span(Variable),
                    callee_name(Variable) ++ " is a function, and a `receive` guard calls nothing",
                    [], "receive the message and `match` it");
guard_operand(Operand, _) ->
    fail(ern_ast:span(Operand), "a comparison in a `receive` guard compares variables, literals,"
                             " and nullary constructors",
         [], "receive the message and `match` it").

%% Whether a name's referent is a top-level `let`, of this module or another.
top_let(#own_declaration{owner = Owner, name = Name}, #env{namespace = Namespace, lets = Lets}) ->
    is_map_key(Namespace ++ [Part || Part <- [Owner], Part =/= undefined] ++ [Name], Lets);
top_let(#remote_declaration{namespace = Namespace, owner = Owner, name = Name},
        #env{lets = Lets}) ->
    is_map_key(Namespace ++ [Part || Part <- [Owner], Part =/= undefined] ++ [Name], Lets);
top_let({prelude, QualifiedName}, #env{lets = Lets}) ->
    is_map_key(QualifiedName, Lets);
top_let(_, _) ->
    false.

%% After the first branch, the expectation's origin is that branch when
%% nothing outside fixed it.
sibling(Context, undefined, SiblingContext, First, What, Expected, Env) ->
    {default(Context, SiblingContext),
     {ern_ast:span(First), What ++ " has type " ++ ern_types:format(Expected, Env#env.type_state)}};
sibling(Context, Origin, _SiblingContext, _First, _What, _Expected, _Env) ->
    {Context, Origin}.

default(undefined, Text) -> Text;
default(Context, _) -> Context.

infer_list(Exprs, Env) ->
    {Typed, Env1} = lists:mapfoldl(fun(Expr, Acc) ->
                                       {TypedExpr, ExprType, Acc1} = infer(Expr, Acc),
                                       {{TypedExpr, ExprType}, Acc1}
                                   end, Env, Exprs),
    {TypedExprs, Types} = lists:unzip(Typed),
    {TypedExprs, Types, Env1}.

callee_name(#e_var{path = Path, name = Name}) -> format_qualified_name(Path ++ [Name]);
callee_name(_) -> "the callee".

%% Report §3.9, §11.5: an argument's mismatch in a recursive call, one to a
%% definition whose inference is under way, names the rule it breaks: no
%% polymorphic recursion.
argument_context(Name, Callee, #env{inferring = Inferring} = Env) ->
    Text = "the argument does not fit " ++ Name,
    Recursive = case Callee of
                    #e_var{referent = var, path = [], name = LocalName} ->
                        lists:member({local, LocalName}, Inferring);
                    #e_var{referent = #own_declaration{owner = Owner, name = LocalName}} ->
                        lists:member({global, value_qualified_name(Env, Owner, LocalName)},
                                     Inferring);
                    _ -> false
                end,
    case Recursive of
        true -> {help, Text, "a recursive call is at the definition's own type, so a call at"
                             " another type goes to a second function (§3.9)"};
        false -> Text
    end.

%% Report §6.6: a function whose result type is a variable no parameter's
%% type names does not return, `fault` among them, and a call to it
%% consumes every obligation open on its path. The variable is the
%% scheme's own; one the enclosing definition fixes may stand for a type
%% a value has.
returns(#e_var{span = Span, path = Path, name = Name}, Env) ->
    {#scheme{quantified = Quantified, type = Type}, _, _} = lookup_value(Span, Path, Name, Env),
    TypeState = Env#env.type_state,
    case ern_types:resolve(Type, TypeState) of
        {tfn, Params, _, Result} ->
            case ern_types:resolve(Result, TypeState) of
                {tvar, Id} ->
                    ParamVariables = ern_types:free_variables({ttuple, Params}, TypeState),
                    not (lists:keymember(Id, 1, Quantified)
                         andalso not lists:member(Id, ParamVariables));
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
-spec never_receives(ern_diagnostic:position(), term()) -> no_return().
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

infer_named(#e_constructor{span = Span, name = Name} = Expr, Names, FieldTypes, Constructed,
            Base, FieldSets, Env) ->
    SetNames = [FieldName || #field_set{name = FieldName} <- FieldSets],
    twice([{FieldName, FieldSpan} || #field_set{span = FieldSpan, name = FieldName} <- FieldSets],
          "given"),
    lists:foreach(fun(FieldName) ->
                      lists:member(FieldName, Names) orelse
                          fail(Span, atom_to_list(Name) ++ " has no field "
                                     ++ atom_to_list(FieldName))
                  end, SetNames),
    {TypedBase, Env1} = named_base(Expr, Base, Names -- SetNames, Constructed, Env),
    Check = fun(FieldSet, Acc) -> check_field_set(FieldSet, Expr, Names, FieldTypes, Acc) end,
    {TypedFieldSets, Env2} = lists:mapfoldl(Check, Env1, FieldSets),
    {Expr#e_constructor{args = {named, TypedBase, TypedFieldSets}, type = Constructed},
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

%% A field given in a construction, at the type its constructor declares.
check_field_set(#field_set{name = FieldName, expr = Value} = FieldSet,
                #e_constructor{name = Name} = Expr, Names, FieldTypes, Env) ->
    FieldType = lists:nth(index_of(FieldName, Names), FieldTypes),
    {TypedValue, ValueType, Env1} = infer(Value, Env),
    Declares = atom_to_list(Name) ++ " declares " ++ atom_to_list(FieldName) ++ " : "
               ++ ern_types:format(FieldType, Env1#env.type_state),
    {FieldSet#field_set{expr = TypedValue},
     unify_at(ern_ast:span(Value), FieldType, ValueType, Env1, "field " ++ atom_to_list(FieldName),
              {constructor_name_span(Expr), Declares})}.

%% The span of a construction's written constructor, `Point` or
%% `Shape.Circle`, which labels what fixed a field's type.
constructor_name_span(#e_constructor{span = Span, path = Path, name = Name}) ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {Line, Column, {Line, Column + length(format_qualified_name(Path ++ [Name]))}}.

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
    Env2 = equality_constraint(Span, LeftType, Env1),
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

%% Report §3.10: == on a type variable records the constraint, and the
%% comparison as where it was needed, so that a later use that makes the
%% type one without equality is reported here; on a concrete type without
%% equality it is an error now.
equality_constraint(Span, Type, Env) ->
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
            Map = maps:from_list([{Id, Arg} || {{tvar, Id}, Arg} <- lists:zip(Params, Args)]),
            {ok, [ern_types:replace_variables(FieldType, Map)
                  || #constructor_info{scheme = #scheme{type = {tfn, FieldTypes, _, _}}}
                         <- Constructors,
                     FieldType <- FieldTypes]};
        #type_info{} ->
            none;
        undefined ->
            erlang:error({undeclared_type, format_qualified_name(QualifiedName)})
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

check_clauses(Kind, Clauses, ScrutineeType, ScrutineeOrigin, Expected, Context, Origin,
              SiblingContext, Env) ->
    Check = fun(#clause{body = Body} = Clause, {Acc, ContextAcc, OriginAcc}) ->
                {Typed, Acc1} = check_clause(Kind, Clause, ScrutineeType, ScrutineeOrigin,
                                             Expected, ContextAcc, OriginAcc, Acc),
                {ContextAcc1, OriginAcc1} = sibling(ContextAcc, OriginAcc, SiblingContext, Body,
                                                    "the first clause", Expected, Acc1),
                {Typed, {Acc1, ContextAcc1, OriginAcc1}}
            end,
    {Typed, {Env1, _, _}} = lists:mapfoldl(Check, {Env, Context, Origin}, Clauses),
    {Typed, Env1}.

%% One clause: its pattern against the scrutinee's type, its guard, and its
%% body against the expected type; what it binds is its own.
check_clause(Kind, #clause{pattern = Pattern, guard = Guard, body = Body} = Clause,
             ScrutineeType, ScrutineeOrigin, Expected, Context, Origin, Env) ->
    {TypedPattern, PatternType, Bindings, Env1} = check_pattern(Pattern, Env),
    Env2 = unify_at(ern_ast:span(Pattern), ScrutineeType, PatternType, Env1,
                    "the pattern does not fit the value", ScrutineeOrigin),
    Env3 = bind_locals(Bindings, alternatives_agree(TypedPattern, Env2)),
    {TypedGuard, Env4} = check_guard(Kind, Guard, Env3),
    {TypedBody, _, Env5} = check_expr(Body, Expected, Context, Origin, Env4),
    {Clause#clause{pattern = TypedPattern, guard = TypedGuard, body = TypedBody},
     Env5#env{locals = Env#env.locals}}.

%% Report §5.9: a guard is pure; a receive's is a guard expression (§6.3).
check_guard(_Kind, undefined, Env) ->
    {undefined, Env};
check_guard(Kind, Guard, Env) ->
    Origin = #effect_origin{what = "a guard", span = ern_ast:span(Guard),
                            label = "a guard is pure (report §5.9)",
                            help = "compute the value before the match"},
    Guarded = Env#env{effect = pure, effect_origin = Origin},
    {TypedGuard, _, GuardEnv} = check_expr(Guard, ?BOOL, "a guard is a Bool", undefined, Guarded),
    case Kind of
        'receive' -> receive_guard(TypedGuard, GuardEnv);
        match -> ok
    end,
    {TypedGuard, GuardEnv#env{effect = Env#env.effect, effect_origin = Env#env.effect_origin}}.

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
    Local = #{placeholders => maps:from_list(Placeholders), dependencies => Dependencies,
              checked => [], waiting => []},
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

%% Local fns not yet checked that Name depends on, transitively.
pending(Name, #{dependencies := Dependencies, checked := Checked}) ->
    pending([Name], Dependencies, Checked, []) -- [Name].

pending([], _Dependencies, _Checked, Acc) ->
    Acc;
pending([Name | Names], Dependencies, Checked, Acc) ->
    case lists:member(Name, Acc) of
        true -> pending(Names, Dependencies, Checked, Acc);
        false ->
            pending(maps:get(Name, Dependencies, []) ++ Names, Dependencies, Checked, [Name | Acc])
    end.

%% Generalize every waiting fn whose dependencies are all checked.
release(Env, #{waiting := Waiting, placeholders := Placeholders, checked := Checked} = Local) ->
    Ready = [Name || Name <- Waiting, (pending(Name, Local) -- Checked) =:= []],
    Generalize = fun(Name, Acc) ->
                     {Scheme, TypeState} =
                         ern_types:generalize(maps:get(Name, Placeholders), Acc#env.type_state),
                     Acc#env{type_state = TypeState,
                             locals = maps:put(Name, Scheme, Acc#env.locals),
                             inferring = lists:delete({local, Name}, Acc#env.inferring)}
                 end,
    Env1 = lists:foldl(Generalize, Env, Ready),
    {Env1, Local#{waiting => Waiting -- Ready}}.

%% A block ends with an expression, which the parser ensures (report §5.4).
infer_statements([Last], _Span, Expect, Env, _Local, Acc) ->
    {Typed, Type, Env1} = case Expect of
                              undefined -> infer(Last, Env);
                              {ExpectedType, Context, Origin} ->
                                  check_expr(Last, ExpectedType, Context, Origin, Env)
                          end,
    {lists:reverse([Typed | Acc]), Type, Env1};
infer_statements([#fn_declaration{span = DeclarationSpan, owner = Owner, name = Name} | _],
                 _Span, _Expect, _Env, _Local, _Acc) when Owner =/= undefined ->
    fail(DeclarationSpan, "a member, `fn " ++ local_name(Owner, Name) ++ "`, is a top-level form;"
                          " a local function has a plain name");
infer_statements([#fn_declaration{name = Name} = Declaration | Rest], Span, Expect, Env, Local,
                 Acc) ->
    Placeholder = maps:get(Name, maps:get(placeholders, Local)),
    Env1 = Env#env{type_state = ern_types:enter(Env#env.type_state)},
    {TypedDeclaration, Post, Posted} = check_value(Declaration, Placeholder, Env1),
    Env2 = post_checks(Post, Posted),
    Env3 = Env2#env{type_state = ern_types:leave(Env2#env.type_state)},
    Local1 = Local#{checked => [Name | maps:get(checked, Local)],
                    waiting => [Name | maps:get(waiting, Local)]},
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
                throw:{type_error, _, _} = Error ->
                    recovered(Error, fun() -> Continue(Fallback, []) end);
                throw:{type_error, _} = Error ->
                    recovered(Error, fun() -> Continue(Fallback, []) end);
                throw:{type_errors, _} = Error ->
                    recovered(Error, fun() -> Continue(Fallback, []) end)
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
    Env3 = case Annotation of
               undefined -> Env2;
               _ ->
                   {AnnotationType, _, TypeState} =
                       annotation_type(Annotation, Env2#env.annotation_variables, Env2),
                   unify_at(BindingSpan, AnnotationType, PatternType,
                            Env2#env{type_state = TypeState},
                            "the value does not have the declared type")
           end,
    Env4 = bind_locals(Bindings, Env3),
    {TypedRest, RestType, Env5} = infer_statements(Rest, Span, Expect, Env4, Local, []),
    Spans = {ern_ast:span(Pattern), ern_ast:span(Expr)},
    %% report §11.5: what fixed the block's type, the annotation that did,
    %% or else the block's last expression
    Fixed = case Expect of
                {_, _, {_, _} = Origin} -> Origin;
                _ -> {last, ern_ast:span(lists:last(Rest))}
            end,
    Deferred = #deferred_bind_arrow{span = BindingSpan, spans = Spans, expr_type = ExprType,
                                    pattern_type = PatternType, rest_type = RestType,
                                    fixed = Fixed},
    Env6 = Env5#env{deferred = [Deferred | Env5#env.deferred]},
    Bound = Binding#binding{pattern = TypedPattern, expr = TypedExpr},
    {lists:reverse(Acc) ++ [Bound | TypedRest], RestType, Env6};
infer_statements([Expr | Rest], Span, Expect, Env, Local, Acc) ->
    %% report §11.5: a statement binds nothing, so the rest of its block is
    %% checked after its error too
    Continue = fun(Next, Typed) ->
                   infer_statements(Rest, Span, Expect, Next, Local, Typed ++ Acc)
               end,
    try
        {Checked, Type, Env1} = infer(Expr, Env),
        {Checked, statement_unit(Expr, Type, Env1)}
    of
        {TypedExpr, Env2} -> Continue(Env2, [TypedExpr])
    catch
        throw:{type_error, _, _} = Error -> recovered(Error, fun() -> Continue(Env, []) end);
        throw:{type_error, _} = Error -> recovered(Error, fun() -> Continue(Env, []) end);
        throw:{type_errors, _} = Error -> recovered(Error, fun() -> Continue(Env, []) end)
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
                   TypeState1 = ern_types:leave(Env3#env.type_state),
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
    New =:= [] orelse Generalize orelse
        fail(BindingSpan, "type variable " ++ atom_to_list(lists:min([Name || {Name, _} <- New]))
                          ++ " in the annotation means every type, and a `let` in a block is"
                          " generalized only over a lambda", [],
             "write the type, or leave the annotation out"),
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
recovered(Error, Rest) ->
    Later = try Rest() of
                _ -> []
            catch
                throw:{type_error, _, _} = Thrown -> diagnostics(Thrown);
                throw:{type_error, _} = Thrown -> diagnostics(Thrown);
                throw:{type_errors, _} = Thrown -> diagnostics(Thrown)
            end,
    throw({type_errors, diagnostics(Error) ++ Later}).

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
            BoundAt = fun(#p_var{span = VariableSpan, name = VariableName}, Acc)
                            when VariableName =:= Repeated ->
                              [VariableSpan | Acc];
                         (#p_as{name_span = NameSpan, name = VariableName}, Acc)
                            when VariableName =:= Repeated ->
                              [NameSpan | Acc];
                         (_, Acc) ->
                              Acc
                      end,
            [First, Second | _] = lists:sort(ern_ast:walk(BoundAt, Pattern, [])),
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
    ern_ast:walk(fun(#p_var{span = Span, name = VariableName}, undefined)
                       when VariableName =:= Name ->
                         Span;
                    (#p_as{span = Span, name = VariableName}, undefined)
                       when VariableName =:= Name ->
                         Span;
                    (_, Found) ->
                         Found
                 end, Pattern, undefined).

-spec alternatives_differ(ern_diagnostic:position(), [atom()], [atom()]) -> no_return().
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
infer_pattern(#p_constructor{span = Span, path = Path, name = Name, args = Args} = Pattern, Env) ->
    ConstructorInfo = lookup_constructor(Span, Path, Name, Env),
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
check_field_pattern(#field_pattern{span = FieldSpan, name = FieldName, pattern = SubPattern}
                        = FieldPattern, Name, Names, FieldTypes, Env) ->
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
        check_expr(SegmentValue, segment_type(Spec), segment_context(Spec), undefined, Env1),
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
                    segment_context(Spec)),
    {Segment#bit_segment{value = TypedValue, specs = TypedSpecs}, ValueBindings, Env3}.

%% Report §5.11: a literal the compiler sees not fitting a segment of
%% constant width is a compile-time error, in a construction and in a
%% pattern, which it would never match; any other value is checked at
%% construction, as the runtime's ern_bits checks it.
literal_fits(Literal, int, Value, #{kind := int, size := {const, Bits}, sign := Sign}) ->
    {Segment, Low, High} = case Sign of
                               unsigned -> {"an unsigned", 0, (1 bsl Bits) - 1};
                               signed -> {"a signed", -(1 bsl (Bits - 1)), (1 bsl (Bits - 1)) - 1}
                           end,
    (Value >= Low andalso Value =< High)
        orelse fail(ern_ast:span(Literal),
                    io_lib:format("the literal does not fit ~s segment of ~B bits, which holds"
                                  " ~B to ~B", [Segment, Bits, Low, High]));
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
size_expression(#e_var{path = [], name = Name}, #env{locals = Locals})
  when is_map_key(Name, Locals) ->
    true;
size_expression(#e_var{referent = Referent}, Env) -> top_let(Referent, Env);
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
    Bound = ern_ast:walk(fun(#p_var{span = Span, name = Name}, Acc) -> Acc ++ [{Name, Span}];
                            (#p_as{span = Span, name = Name}, Acc) -> Acc ++ [{Name, Span}];
                            (_, Acc) -> Acc
                         end, Pattern, []),
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

size_variables(#e_var{path = [], name = _} = Variable, Acc) -> Acc ++ [Variable];
size_variables(_, Acc) -> Acc.

sibling_size(#e_var{span = Span, name = Name}, Bound, Earlier, Env) ->
    case lists:keyfind(Name, 1, Bound) of
        {Name, BoundSpan} when not is_map_key(Name, Earlier) ->
            NameText = atom_to_list(Name),
            known_name(Name, Env) orelse
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
known_name(Name, #env{locals = Locals, local_values = LocalValues, globals = Globals} = Env) ->
    is_map_key(Name, Locals) orelse is_map_key(Name, LocalValues)
        orelse is_map_key([Name], Globals) orelse session(values, Name, Env) =/= error.

segment_type(#{kind := int}) -> ?INT;
segment_type(#{kind := float}) -> ?FLOAT;
segment_type(#{kind := Kind}) when Kind =:= utf8; Kind =:= utf16; Kind =:= utf32 -> ?CHAR;
segment_type(_) -> ?BYTES.

segment_context(#{kind := Kind})
  when Kind =:= int; Kind =:= utf8; Kind =:= utf16; Kind =:= utf32 ->
    "an `" ++ atom_to_list(Kind) ++ "` segment";
segment_context(#{kind := Kind}) -> "a `" ++ atom_to_list(Kind) ++ "` segment".

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
irrefutable(#p_constructor{span = Span, path = Path, name = Name, args = Args}, Env) ->
    #constructor_info{type_qualified_name = TypeQualifiedName} =
        lookup_constructor(Span, Path, Name, Env),
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
                                 orelse session(values, Name, Env) =/= error),
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
lookup_value(Span, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Span, Path, Name);
lookup_value(Span, [Owner] = Path, Name, #env{local_values = LocalValues} = Env) ->
    case LocalValues of
        #{{Owner, Name} := QualifiedName} -> local_global(QualifiedName, Env);
        _ ->
            case session(values, {Owner, Name}, Env) of
                {ok, QualifiedName} -> session_global(QualifiedName, Name, Env);
                error -> lookup_global(Span, Path, Name, Env)
            end
    end;
lookup_value(Span, Path, Name, #env{namespace = Namespace, local_values = LocalValues} = Env) ->
    %% report §4.2: a module may name its own declarations qualified
    case Path =:= Namespace of
        true ->
            case LocalValues of
                #{Name := QualifiedName} -> local_global(QualifiedName, Env);
                _ -> lookup_global(Span, Path, Name, Env)
            end;
        false ->
            %% report §4.2: `M.T.name` in module M is M's own member where M
            %% declares T, and the module M.T's `name` otherwise; only one of
            %% the two can exist, a module namespace may not coincide with a
            %% type-member namespace
            Own = case own_type_path(Path, Namespace) of
                      true -> own_member(lists:last(Path), Name, Env);
                      false -> error
                  end,
            case Own of
                {ok, QualifiedName} -> local_global(QualifiedName, Env);
                error -> lookup_global(Span, Path, Name, Env)
            end
    end.

%% Report §4.2: `Prelude.` is written where the module hides the prelude's
%% name, and nowhere else, where the plain name is the one way to write it.
hidden(_Span, _Name, true) ->
    ok;
hidden(Span, Name, false) ->
    Plain = format_qualified_name(Name),
    Written = "Prelude." ++ Plain,
    Hidden = case Name of
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
-spec prelude_one(ern_diagnostic:position(), [atom()], atom()) -> no_return().
prelude_one(Span, Path, Name) ->
    fail(Span, format_qualified_name(Path ++ [Name])
               ++ ": Prelude takes one name the prelude declares, as `Prelude.Some`, or a name"
               " of the prelude's or the standard library's namespaces, as"
               " `Prelude.Io.println`").

own_member(Owner, Name, #env{local_values = LocalValues} = Env) ->
    case LocalValues of
        #{{Owner, Name} := QualifiedName} -> {ok, QualifiedName};
        _ -> session(values, {Owner, Name}, Env)
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

%% Report §11.2: a member of the session's latest type of its name may have
%% been declared by a later input than the type.
session_member(QualifiedName, Member, Env) ->
    Name = lists:last(QualifiedName),
    case session(types, Name, Env) of
        {ok, QualifiedName} ->
            case session(values, {Name, Member}, Env) of
                {ok, MemberQualifiedName} -> MemberQualifiedName;
                error -> QualifiedName ++ [Member]
            end;
        _ ->
            QualifiedName ++ [Member]
    end.

%% Report §11.2: what the session declared under this unqualified name.
session(Which, Name, #env{session = Session}) ->
    case maps:get(Which, Session, #{}) of
        #{Name := QualifiedName} -> {ok, QualifiedName};
        _ -> error
    end.

%% An unqualified name the module neither binds nor declares: at the
%% prompt the session's (report §11.2), and else the prelude's (§4.2).
lookup_outside(Span, Name, Env) ->
    case {session(values, Name, Env), Env#env.globals} of
        {{ok, QualifiedName}, _} -> session_global(QualifiedName, Name, Env);
        {error, #{[Name] := Scheme}} -> {Scheme, {prelude, [Name]}, Env};
        {error, _} -> fail(Span, "unknown name " ++ atom_to_list(Name))
    end.

%% This module's own declaration, QualifiedName being its namespace and the
%% owner and the name.
local_global(QualifiedName, #env{namespace = Namespace} = Env) ->
    Env1 = demand(QualifiedName, Env),
    Referent = case lists:nthtail(length(Namespace), QualifiedName) of
                   [Name] -> #own_declaration{owner = undefined, name = Name};
                   [Owner, Name] -> #own_declaration{owner = Owner, name = Name}
               end,
    {maps:get(QualifiedName, Env1#env.globals), Referent, Env1}.

%% Report §11.2: a declaration of an earlier input, another module.
session_global(QualifiedName, Name, Env) ->
    Env1 = demand(QualifiedName, Env),
    {maps:get(QualifiedName, Env1#env.globals),
     qualified_referent(lists:droplast(QualifiedName), Name, Env1), Env1}.

lookup_global(Span, Path, Name, #env{globals = Globals} = Env) ->
    QualifiedName = Path ++ [Name],
    case Globals of
        #{QualifiedName := Scheme} ->
            Referent = case lookup_type(QualifiedName, Env) =:= undefined
                            andalso lists:keymember(QualifiedName, 1, ern_prelude:values()) of
                           true -> {prelude, QualifiedName};
                           false -> qualified_referent(Path, Name, Env)
                       end,
            {Scheme, Referent, Env};
        _ when Path =:= ['Peer'] ->
            %% Report §8.3: a spawn on a peer is the module Peer's, which
            %% MVP 3.0 builds; a module of the program's may take the name
            case lists:any(fun(Key) -> lists:droplast(Key) =:= Path end, maps:keys(Globals)) of
                true -> fail(Span, "unknown name " ++ format_qualified_name(QualifiedName));
                false ->
                    fail(Span, format_qualified_name(QualifiedName)
                               ++ " is not here yet: the module Peer, which acts on peers,"
                               " arrives in MVP 3.0")
            end;
        _ ->
            fail(Span, "unknown name " ++ format_qualified_name(QualifiedName))
    end.

%% Report §4.2: the declaration a qualified name names, Path its namespace
%% or its namespace and the type that owns the member.
qualified_referent(Path, Name, #env{namespace = Namespace} = Env) ->
    {Declaring, Owner} = case is_member_path(Path, Name, Env) of
                             true -> {lists:droplast(Path), lists:last(Path)};
                             false -> {Path, undefined}
                         end,
    case Declaring =:= Namespace of
        true -> #own_declaration{owner = Owner, name = Name};
        false -> #remote_declaration{namespace = Declaring, owner = Owner, name = Name}
    end.

%% A constructor as a name written at Span, `C` or `M.C`, names it (report
%% §4.2, §4.4): the error for one unknown or not visible here is thrown.
-spec lookup_constructor(ern_lexer:position(), [atom()], atom(), env()) -> #constructor_info{}.
lookup_constructor(Span, [], Name,
                   #env{local_constructors = LocalConstructors,
                        constructors = Constructors} = Env) ->
    case LocalConstructors of
        #{Name := QualifiedName} -> maps:get(QualifiedName, Constructors);
        _ ->
            case session(constructors, Name, Env) of
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
                                 orelse session(constructors, Name, Env) =/= error),
            ConstructorInfo;
        _ ->
            fail(Span, "the prelude declares no constructor " ++ atom_to_list(Name))
    end;
lookup_constructor(Span, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Span, Path, Name);
lookup_constructor(Span, Path, Name,
                   #env{constructors = Constructors, types = Types, local_types = LocalTypes}) ->
    QualifiedName = Path ++ [Name],
    case Constructors of
        #{QualifiedName := #constructor_info{type_qualified_name = TypeQualifiedName}
                               = ConstructorInfo} ->
            %% report §4.4: an abstract type's constructor is its module's alone
            Local = maps:get(lists:last(TypeQualifiedName), LocalTypes, undefined),
            IsLocal = Local =:= TypeQualifiedName,
            case Types of
                #{TypeQualifiedName := #type_info{abstract = true}} when not IsLocal ->
                    fail(Span, format_qualified_name(QualifiedName)
                               ++ " is the constructor of an abstract type and is not visible"
                               " outside its module");
                _ -> ConstructorInfo
            end;
        _ -> fail(Span, "unknown constructor " ++ format_qualified_name(QualifiedName))
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
    lists:append([[private_type(Declaration, Type)
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

private_type(Declaration, QualifiedName) ->
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

exported_value(#fn_declaration{export = true, owner = Owner, name = Name}, Env) ->
    {true, value_qualified_name(Env, Owner, Name)};
exported_value(#let_declaration{export = true, name = Name}, Env) ->
    {true, value_qualified_name(Env, undefined, Name)};
exported_value(#foreign_fn_declaration{export = true, owner = Owner, name = Name}, Env) ->
    {true, value_qualified_name(Env, Owner, Name)};
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

unify_at(Span, Expected, Actual, Env, Context) ->
    unify_at(Span, Expected, Actual, Env, Context, undefined).

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
%% A context may carry its own help line, {help, Text, Help}, which names
%% the rule the mismatch breaks, as a recursive call's does.
unify_at(Span, Expected, Actual, #env{type_state = TypeState, rigid = Rigid} = Env, Given,
         Origin) ->
    {Context, RuleHelp} = case Given of
                              {help, Text, GivenHelp} -> {Text, GivenHelp};
                              _ -> {Given, undefined}
                          end,
    case ern_types:unify(Expected, Actual, TypeState) of
        {ok, TypeState1} ->
            rigid_kept(Rigid, TypeState1) orelse not rigid_kept(Rigid, TypeState) orelse
                fail(Span, unify_message(Context, {mismatch, Expected, Actual}, Expected, Actual,
                                         TypeState),
                     labels(Origin), RuleHelp),
            Env#env{type_state = TypeState1};
        {error, Reason} ->
            Help = case {RuleHelp, not_an_alias(Expected, Actual, Env)} of
                       {undefined, undefined} ->
                           differing_help(Reason, Expected, Actual, TypeState);
                       {undefined, Alias} -> Alias;
                       {Rule, _} -> Rule
                   end,
            fail(Span, unify_message(Context, Reason, Expected, Actual, TypeState),
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
    Type = ern_types:format(Wrapper, TypeState),
    Name = atom_to_list(lists:last(OtherQualifiedName)),
    Wrapped = ern_types:format(Other, TypeState),
    "`type " ++ Type ++ " = " ++ Name ++ "` declares a type whose one value is `" ++ Name
    ++ "`, not another name for " ++ Wrapped ++ "; there are no type aliases, and a wrapper is"
    " `type " ++ Type ++ " = " ++ Type ++ "(" ++ Wrapped ++ ")`".

%% Whether the rigid variables are still distinct variables.
rigid_kept(Rigid, TypeState) ->
    Resolved = [ern_types:resolve(Variable, TypeState) || {_, Variable} <- Rigid],
    Ids = [Id || {tvar, Id} <- Resolved],
    length(Ids) =:= length(Resolved) andalso length(lists:usort(Ids)) =:= length(Ids).

%% The message shows the whole types; when they differ inside, the help
%% line names the differing part.
differing_help({mismatch, _, _}, Expected, Actual, TypeState) ->
    {ExpectedPart, ActualPart} = ern_types:mismatch_pair(Expected, Actual, TypeState),
    ExpectedText = ern_types:format(ExpectedPart, TypeState),
    ActualText = ern_types:format(ActualPart, TypeState),
    case ExpectedText =:= ern_types:format(Expected, TypeState)
         orelse ActualText =:= ern_types:format(Actual, TypeState) of
        true -> undefined;
        false -> "the types differ at " ++ ExpectedText ++ " and " ++ ActualText
    end;
differing_help(_, _, _, _) -> undefined.

unify_message(Context, {mismatch, _, _}, Expected, Actual, TypeState) ->
    lists:flatten([Context, ": expected ", ern_types:format(Expected, TypeState), ", found ",
                   ern_types:format(Actual, TypeState)]);
unify_message(Context, Reason, _, _, _) when Reason =:= pure_where_process_needed;
                                              Reason =:= process_where_pure_needed ->
    lists:flatten([Context, ": ", ern_types:format_error(Reason)]);
unify_message(Context, {pure_vs_effect, _}, Expected, Actual, TypeState) ->
    lists:flatten([Context, ": expected ", ern_types:format(Expected, TypeState), ", found ",
                   ern_types:format(Actual, TypeState), " (a pure function and one with a mailbox"
                   " effect do not match)"]);
unify_message(Context, Reason, Expected, Actual, TypeState) ->
    lists:flatten([Context, ": ", ern_types:format_error(Reason), " (",
                   ern_types:format(Expected, TypeState), " against ",
                   ern_types:format(Actual, TypeState), ")"]).

format_qualified_name(Parts) ->
    lists:flatten(lists:join(".", [atom_to_list(Part) || Part <- Parts])).

plural(1) -> "";
plural(_) -> "s".

fail(Span, Message) ->
    throw({type_error, Span, lists:flatten(Message)}).

fail(Span, Message, Labels, Help) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = lists:flatten(Message),
                                   labels = Labels, help = Help}}).
