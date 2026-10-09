%% The canonical form of report Appendix H: each definition of a checked
%% module as the term its hash is taken of, the hashes, and the chunk
%% "ErnC" of a compiled module that holds them (§8.7, §11.1). The emitter
%% calls module/4 and writes the chunk, and the interface carries each
%% definition's hash by its qualified name (interface/2), by which a
%% dependent's forms name it.
%%
%% A form is made in two steps. The walk writes each definition with a
%% reference to another definition of its own module left open, `{'$own',
%% QualifiedName}`, a tuple no program can write, since no Ernest name
%% begins with `$`; the module's definitions then fall into the strongly
%% connected components of those references, which are hashed in
%% dependency order, each open reference closed as its component's place
%% or the hash of what it names.
-module(ern_canonical).

-export([form_version/0, chunk_name/0, bytes/1, module/4, interface/2, lambdas/2, encode/1,
         read/1]).

-export_type([canonical/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("typer/include/ern_canonical.hrl").

-define(FORM_VERSION, 1).
-define(CHUNK, <<"ErnC">>).

%% The operators the runtime applies itself at their operand's type, which
%% their form holds (Appendix H).
-define(AT_TYPE, ['+', '-', '*', '/', '%', '<>', '<', '<=', '>', '>=']).

-type canonical() :: #{definitions := [#definition{}],
                       identities := #{[atom()] => binary() | foreign},
                       references := [{[atom()], binary()}]}.

%% The walk of one definition (Appendix H): env, the checker's; namespace,
%% the module's; standard, whether the module is the standard library's
%% own, whose every reference is by name; own, the module's declarations by
%% qualified name, each function, binding, type or foreign; scope, each
%% local's name to its number; outer, the scope where the pattern being
%% walked began, undefined outside a pattern; bound, the locals that pattern
%% has bound; segments, the locals a bitstring pattern's earlier segments
%% bound; locals, the numbers taken; variables, each type variable, {tvar,
%% Id} or {name, Name}, to its number; references, the other modules'
%% definitions referenced by hash.
-record(walk, {env, namespace, standard, own, scope = #{}, outer, bound = #{},
               segments = #{}, locals = 0, variables = #{}, references = []}).

-spec form_version() -> pos_integer().
form_version() ->
    ?FORM_VERSION.

-spec chunk_name() -> binary().
chunk_name() ->
    ?CHUNK.

%% Report Appendix H: the bytes a hash is taken of.
-spec bytes(term()) -> binary().
bytes(Term) ->
    term_to_binary(Term, [deterministic, {minor_version, 2}]).

hash(Term) ->
    crypto:hash(sha256, bytes(Term)).

%%
%% A module
%%

%% Report §8.7, Appendix H: the module's definitions in source order, each
%% with its form and its hash; the hash of each by its qualified name, and
%% `foreign` for each foreign declaration; and the definitions of other
%% modules the forms reference by hash, which the build compares (§11.1).
%% Standard: whether the module is the standard library's own.
-spec module([atom()], [tuple()], ern_typecheck:env(), boolean()) -> canonical().
module(Namespace, Typed, Env, Standard) ->
    Own = maps:from_list([{QualifiedName, Kind}
                          || Declaration <- Typed,
                             {QualifiedName, Kind} <- declared(Namespace, Declaration)]),
    Walk = #walk{env = Env, namespace = Namespace, standard = Standard, own = Own},
    Opened = [{QualifiedName, Kind, opened(Declaration, Walk)}
              || Declaration <- Typed,
                 {QualifiedName, Kind} <- declared(Namespace, Declaration), Kind =/= foreign],
    Definitions = closed([{QualifiedName, Kind, Form}
                          || {QualifiedName, Kind, {Form, _}} <- Opened]),
    #{definitions => Definitions,
      identities => maps:from_list([{QualifiedName, Hash}
                                    || #definition{qualified_name = QualifiedName,
                                                   hash = Hash} <- Definitions]
                                   ++ [{QualifiedName, foreign}
                                       || QualifiedName := foreign <- Own]),
      references => lists:usort(lists:append([References
                                              || {_, _, {_, References}} <- Opened]))}.

%% Report §11.1: the interface with the hashes a dependent's forms name.
-spec interface(#interface{}, canonical()) -> #interface{}.
interface(Interface, #{identities := Identities}) ->
    Interface#interface{identities = Identities}.

%% What a declaration declares: a function, a binding, a type, or a foreign
%% declaration, which has no hash (Appendix H).
declared(Namespace, #fn_declaration{member_of = MemberOf, name = Name}) ->
    [{qualified(Namespace, MemberOf, Name), function}];
declared(Namespace, #let_declaration{name = Name}) ->
    [{Namespace ++ [Name], binding}];
declared(Namespace, #type_declaration{name = Name}) ->
    [{Namespace ++ [Name], type}];
declared(Namespace, #abstract_declaration{declaration = Declaration}) ->
    declared(Namespace, Declaration);
declared(Namespace, #foreign_fn_declaration{member_of = MemberOf, name = Name}) ->
    [{qualified(Namespace, MemberOf, Name), foreign}];
declared(Namespace, #foreign_type_declaration{name = Name}) ->
    [{Namespace ++ [Name], foreign}];
declared(_, _) ->
    [].

qualified(Namespace, undefined, Name) -> Namespace ++ [Name];
qualified(Namespace, MemberOf, Name) -> Namespace ++ [MemberOf, Name].

%% A definition's form with its own module's references open, and the
%% other modules' definitions it references by hash.
opened(#fn_declaration{} = Declaration, Walk) ->
    {Form, #walk{references = References}} = function(Declaration, Walk),
    {Form, References};
opened(#let_declaration{scheme = Scheme, annotation = Annotation, body = Body}, Walk) ->
    {SchemeForm, Walk1} = scheme(Scheme, Walk),
    {AnnotationForm, Walk2} = annotation(Annotation, Walk1),
    {BodyForm, #walk{references = References}} = expr(Body, Walk2),
    {{binding, SchemeForm, AnnotationForm, BodyForm}, References};
opened(#abstract_declaration{declaration = Declaration}, Walk) ->
    opened(Declaration, Walk);
opened(#type_declaration{name = Name, derives = Derives},
       #walk{namespace = Namespace, env = Env} = Walk) ->
    #type_info{params = Params, constructors = Constructors} =
        ern_typecheck:lookup_type(Namespace ++ [Name], Env),
    %% report Appendix H: the parameters are the variables 1 to its arity
    Walk1 = lists:foldl(fun(Param, Acc) -> element(2, variable(Param, Acc)) end, Walk, Params),
    {ConstructorForms, #walk{references = References}} =
        lists:mapfoldl(fun constructor_declared/2, Walk1, Constructors),
    {{type, Namespace ++ [Name], length(Params), Derives =/= undefined, ConstructorForms},
     References}.

constructor_declared(#constructor_info{name = Name, fields = none}, Walk) ->
    {{Name, none}, Walk};
constructor_declared(#constructor_info{name = Name, fields = positional,
                                       scheme = #scheme{type = {tfn, [Field], _, _}}}, Walk) ->
    {FieldForm, Walk1} = type(Field, Walk),
    {{Name, {positional, FieldForm}}, Walk1};
constructor_declared(#constructor_info{name = Name, fields = {named, Fields},
                                       scheme = #scheme{type = {tfn, FieldTypes, _, _}}}, Walk) ->
    {FieldForms, Walk1} = lists:mapfoldl(fun({Field, FieldType}, Acc) ->
                                             {FieldForm, Acc1} = type(FieldType, Acc),
                                             {{Field, FieldForm}, Acc1}
                                         end, Walk, lists:zip(Fields, FieldTypes)),
    {{Name, {named, FieldForms}}, Walk1}.

%%
%% Groups and hashes, report §8.7 and Appendix H
%%

%% Opened, each definition with its own module's references open, in source
%% order, as definitions with their hashes, in source order: each strongly
%% connected component of the references, in dependency order, its open
%% references closed and its forms hashed.
closed(Opened) ->
    Graph = digraph:new(),
    Sources = maps:from_list([{QualifiedName, Index}
                              || {Index, {QualifiedName, _, _}} <- lists:enumerate(Opened)]),
    [digraph:add_vertex(Graph, QualifiedName) || {QualifiedName, _, _} <- Opened],
    [digraph:add_edge(Graph, QualifiedName, Referenced)
     || {QualifiedName, _, Form} <- Opened, Referenced <- open_references(Form)],
    Condensed = digraph_utils:condensation(Graph),
    Components = lists:reverse(digraph_utils:topsort(Condensed)),
    digraph:delete(Condensed),
    digraph:delete(Graph),
    ByName = maps:from_list([{QualifiedName, {Kind, Form}}
                             || {QualifiedName, Kind, Form} <- Opened]),
    {Definitions, _} =
        lists:foldl(fun(Component, {Acc, Closed}) ->
                        Members = lists:sort(fun(A, B) ->
                                                 maps:get(A, Sources) =< maps:get(B, Sources)
                                             end, Component),
                        Hashed = component(Members, ByName, Closed),
                        {Hashed ++ Acc, lists:foldl(fun closing/2, Closed, Hashed)}
                    end, {[], #{}}, Components),
    lists:sort(fun(#definition{qualified_name = A}, #definition{qualified_name = B}) ->
                   maps:get(A, Sources) =< maps:get(B, Sources)
               end, Definitions).

%% Report Appendix H: a definition alone is hashed as its form; a group of
%% two or more as its forms in source order, and each member as the
%% group's hash and its position.
component([QualifiedName], ByName, Closed) ->
    {Kind, Opened} = maps:get(QualifiedName, ByName),
    Form = close(Opened, Closed#{QualifiedName => {in_group, 1}}),
    [#definition{qualified_name = QualifiedName, kind = Kind, form = Form,
                 hash = hash({ernest_form, ?FORM_VERSION, Form})}];
component(Members, ByName, Closed) ->
    InGroup = maps:from_list([{QualifiedName, {in_group, Position}}
                              || {Position, QualifiedName} <- lists:enumerate(Members)]),
    Linking = maps:merge(Closed, InGroup),
    Forms = [{QualifiedName, Kind, close(Opened, Linking)}
             || QualifiedName <- Members, {Kind, Opened} <- [maps:get(QualifiedName, ByName)]],
    GroupHash = hash({ernest_form, ?FORM_VERSION, {group, [Form || {_, _, Form} <- Forms]}}),
    [#definition{qualified_name = QualifiedName, kind = Kind, form = Form,
                 hash = hash({ernest_member, ?FORM_VERSION, GroupHash, Position}),
                 group = {GroupHash, Position}}
     || {Position, {QualifiedName, Kind, Form}} <- lists:enumerate(Forms)].

%% A hashed definition as the reference that names it: a binding by its
%% qualified name with its hash, any other by its hash.
closing(#definition{qualified_name = QualifiedName, kind = binding, hash = Hash}, Closed) ->
    Closed#{QualifiedName => {binding, QualifiedName, Hash}};
closing(#definition{qualified_name = QualifiedName, hash = Hash}, Closed) ->
    Closed#{QualifiedName => {hash, Hash}}.

close({'$own', QualifiedName}, Linking) ->
    maps:get(QualifiedName, Linking);
close(Term, Linking) when is_tuple(Term) ->
    list_to_tuple(close(tuple_to_list(Term), Linking));
close([Head | Tail], Linking) ->
    [close(Head, Linking) | close(Tail, Linking)];
close(Term, _) ->
    Term.

open_references({'$own', QualifiedName}) ->
    [QualifiedName];
open_references(Term) when is_tuple(Term) ->
    open_references(tuple_to_list(Term));
open_references(Terms) when is_list(Terms) ->
    lists:usort(lists:append([open_references(Part) || Part <- Terms]));
open_references(_) ->
    [].

%% Report §8.7, Appendix H: each lambda and local function of a definition's
%% form with its identity, its definition's hash and its position, counted
%% from 1 in the order the walk meets them.
-spec lambdas(binary(), term()) -> [{{binary(), pos_integer()}, tuple()}].
lambdas(Hash, Form) ->
    [{{Hash, Position}, Function} || {Position, Function} <- lists:enumerate(functions(Form))].

functions({function, Scheme, Params, Result, Effect, Needs, Body}) ->
    within([Scheme, Params, Result, Effect, Needs, Body]);
functions(Form) ->
    within(Form).

within({function, _, Params, _, _, _, _} = Function) when is_list(Params) ->
    [Function | within(tuple_to_list(Function))];
within({lambda, Params, _, _, _} = Lambda) when is_list(Params) ->
    [Lambda | within(tuple_to_list(Lambda))];
within(Term) when is_tuple(Term) ->
    within(tuple_to_list(Term));
within(Terms) when is_list(Terms) ->
    lists:append([within(Part) || Part <- Terms]);
within(_) ->
    [].

%%
%% Functions and schemes
%%

%% Report Appendix H: a function, top-level or local, its scheme first.
function(#fn_declaration{scheme = Scheme, params = Params, result_type = Result,
                         effect = Effect, requirement = Needs, body = Body},
         #walk{scope = Scope} = Walk) ->
    {SchemeForm, Walk1} = scheme(Scheme, Walk),
    {ParamForms, Walk2} = lists:mapfoldl(fun param/2, Walk1, Params),
    {ResultForm, Walk3} = annotation(Result, Walk2),
    {EffectForm, Walk4} = annotation(Effect, Walk3),
    {NeedsForms, Walk5} = lists:mapfoldl(fun needs/2, Walk4, Needs),
    {BodyForm, Walk6} = expr(Body, Walk5),
    {{function, SchemeForm, ParamForms, ResultForm, EffectForm, NeedsForms, BodyForm},
     Walk6#walk{scope = Scope}}.

param(#param{pattern = Pattern, annotation = Annotation}, Walk) ->
    {PatternForm, Walk1} = pattern(Pattern, Walk),
    {AnnotationForm, Walk2} = annotation(Annotation, Walk1),
    {{param, PatternForm, AnnotationForm}, Walk2}.

%% A member of the `needs` clause as written (§4.9), its type variable by
%% its name.
needs(#member{member_of = Variable, name = Member}, Walk) ->
    {Number, Walk1} = variable({name, Variable}, Walk),
    {{needs, {variable, Number}, Member}, Walk1}.

%% Report Appendix H: a scheme lists its quantified variables in the order
%% they first stand in its type, which is the order the checker quantifies
%% them, and its requirement over their numbers. A local function's
%% requirement may name a variable the substitution has bound to an
%% enclosing one, which it names as the emitter does, resolved.
scheme(#scheme{quantified = Quantified, type = Type, requirement = Requirement},
       #walk{env = Env} = Walk) ->
    Resolved = ern_typecheck:resolve_type(Type, Env),
    Order = maps:from_list([{Id, Rank} || {Rank, Id} <- lists:enumerate(type_variables(Resolved))]),
    Ranked = lists:sort(fun({A, _}, {B, _}) ->
                            maps:get(A, Order, infinity) =< maps:get(B, Order, infinity)
                        end, Quantified),
    {QuantifiedForms, Walk1} =
        lists:mapfoldl(fun({Id, Restrictions}, Acc) ->
                           {Number, Acc1} = variable({tvar, Id}, Acc),
                           {{Number, lists:usort(Restrictions)}, Acc1}
                       end, Walk, Ranked),
    {TypeForm, Walk2} = type(Resolved, Walk1),
    {RequirementForms, Walk3} =
        lists:mapfoldl(fun({Id, Member}, Acc) ->
                           {tvar, _} = Variable = ern_typecheck:resolve_type({tvar, Id}, Env),
                           {Number, Acc1} = variable(Variable, Acc),
                           {{Number, Member}, Acc1}
                       end, Walk2, Requirement),
    {{scheme, QuantifiedForms, TypeForm, RequirementForms}, Walk3}.

%% The variables of a type in the order they first stand in it.
type_variables(Type) ->
    lists:uniq(type_variables(Type, [])).

type_variables({tvar, Id}, Acc) -> Acc ++ [Id];
type_variables({tcon, _, Args}, Acc) -> lists:foldl(fun type_variables/2, Acc, Args);
type_variables({ttuple, Elements}, Acc) -> lists:foldl(fun type_variables/2, Acc, Elements);
type_variables({tfn, Params, Effect, Result}, Acc) ->
    lists:foldl(fun type_variables/2, Acc, Params ++ [Effect, Result]);
type_variables(_, Acc) -> Acc.

%% A foreign function's scheme, numbered by itself (Appendix H), and the
%% other modules' types it names recorded.
closed_scheme(Scheme, #walk{env = Env, standard = Standard, own = Own, namespace = Namespace,
                            references = References} = Walk) ->
    {Form, #walk{references = Named}} =
        scheme(Scheme, #walk{env = Env, standard = Standard, own = Own, namespace = Namespace,
                             references = References}),
    {Form, Walk#walk{references = Named}}.

%%
%% Types and annotations
%%

%% Report Appendix H: a type the checker made, written out.
type(Type, #walk{env = Env} = Walk) ->
    written(ern_typecheck:resolve_type(Type, Env), Walk).

written({tvar, Id}, Walk) ->
    {Number, Walk1} = variable({tvar, Id}, Walk),
    {{variable, Number}, Walk1};
written({tcon, QualifiedName, Args}, Walk) ->
    {Reference, Walk1} = type_reference(QualifiedName, Walk),
    {ArgForms, Walk2} = lists:mapfoldl(fun written/2, Walk1, Args),
    {{applied, Reference, ArgForms}, Walk2};
written({ttuple, Elements}, Walk) ->
    {ElementForms, Walk1} = lists:mapfoldl(fun written/2, Walk, Elements),
    {{tuple, ElementForms}, Walk1};
written({tfn, Params, Effect, Result}, Walk) ->
    {ParamForms, Walk1} = lists:mapfoldl(fun written/2, Walk, Params),
    {EffectForm, Walk2} = written(Effect, Walk1),
    {ResultForm, Walk3} = written(Result, Walk2),
    {{arrow, ParamForms, EffectForm, ResultForm}, Walk3};
written(pure, Walk) ->
    {pure, Walk}.

%% Report Appendix H: an annotation as written, its names resolved, a type
%% variable it writes numbered by its name.
annotation(undefined, Walk) ->
    {none, Walk};
annotation(Annotation, Walk) ->
    annotated(Annotation, Walk).

annotated(#t_var{name = Name}, Walk) ->
    {Number, Walk1} = variable({name, Name}, Walk),
    {{variable, Number}, Walk1};
annotated(#t_named{namespace = Namespace, name = Name, args = Args}, #walk{env = Env} = Walk) ->
    {Reference, Walk1} =
        type_reference(ern_typecheck:type_qualified_name(Namespace, Name, Env), Walk),
    {ArgForms, Walk2} = lists:mapfoldl(fun annotated/2, Walk1, Args),
    {{applied, Reference, ArgForms}, Walk2};
annotated(#t_tuple{elements = Elements}, Walk) ->
    {ElementForms, Walk1} = lists:mapfoldl(fun annotated/2, Walk, Elements),
    {{tuple, ElementForms}, Walk1};
annotated(#t_fn{params = Params, result_type = Result, effect = Effect}, Walk) ->
    {ParamForms, Walk1} = lists:mapfoldl(fun annotated/2, Walk, Params),
    {EffectForm, Walk2} = case Effect of
                              undefined -> {pure, Walk1};
                              _ -> annotated(Effect, Walk1)
                          end,
    {ResultForm, Walk3} = annotated(Result, Walk2),
    {{arrow, ParamForms, EffectForm, ResultForm}, Walk3}.

%% A type variable's number, the next one where the walk meets it first.
variable(Key, #walk{variables = Variables} = Walk) ->
    case Variables of
        #{Key := Number} -> {Number, Walk};
        _ ->
            Number = map_size(Variables) + 1,
            {Number, Walk#walk{variables = Variables#{Key => Number}}}
    end.

%%
%% References, report Appendix H
%%

%% A type by its qualified name: a built-in or a prelude type, a type of
%% the standard library and a foreign type by name, a type of the module
%% left open, and another module's by its hash.
type_reference([_] = QualifiedName, Walk) ->
    {{named, QualifiedName}, Walk};
type_reference(QualifiedName, Walk) ->
    declaration_reference(lists:droplast(QualifiedName), QualifiedName, Walk).

%% A value's declaration as a name refers to it (report §4.2).
value_reference(var, Name, #walk{scope = Scope} = Walk) ->
    {{local, maps:get(Name, Scope)}, Walk};
value_reference({prelude, QualifiedName}, _, Walk) ->
    {{named, QualifiedName}, Walk};
value_reference(#own_declaration{member_of = MemberOf, name = Name}, _,
                #walk{namespace = Namespace} = Walk) ->
    declaration_reference(Namespace, qualified(Namespace, MemberOf, Name), Walk);
value_reference(#remote_declaration{namespace = Namespace, member_of = MemberOf, name = Name}, _,
                Walk) ->
    declaration_reference(Namespace, qualified(Namespace, MemberOf, Name), Walk).

%% A member a supply or an operator resolves to, as the function that
%% declares it (§4.8): a prelude type's by name, any other's as a
%% declaration of the module that declares it.
member_reference([_] = TypeQualifiedName, Member, Walk) ->
    {{named, TypeQualifiedName ++ [Member]}, Walk};
member_reference(TypeQualifiedName, Member, #walk{env = Env} = Walk) ->
    QualifiedName = ern_typecheck:session_member(TypeQualifiedName, Member, Env),
    declaration_reference(lists:droplast(lists:droplast(QualifiedName)), QualifiedName, Walk).

%% A declaration of the module Namespace by its qualified name.
declaration_reference(Namespace, QualifiedName, #walk{standard = Standard, env = Env} = Walk) ->
    case Standard orelse ern_typecheck:is_provided(hd(Namespace), Env) of
        true -> {{named, QualifiedName}, Walk};
        false -> program_reference(Namespace, QualifiedName, Walk)
    end.

program_reference(Namespace, QualifiedName,
                  #walk{namespace = Namespace, own = Own, env = Env} = Walk) ->
    case maps:get(QualifiedName, Own) of
        foreign -> foreign_reference(QualifiedName, Env, Walk);
        _ -> {{'$own', QualifiedName}, Walk}
    end;
program_reference(_, QualifiedName, #walk{env = Env, references = References} = Walk) ->
    case ern_typecheck:identity(QualifiedName, Env) of
        foreign ->
            foreign_reference(QualifiedName, Env, Walk);
        Hash when is_binary(Hash) ->
            Reference = case ern_typecheck:is_value(QualifiedName, Env) of
                            true -> {binding, QualifiedName, Hash};
                            false -> {hash, Hash}
                        end,
            {Reference, Walk#walk{references = [{QualifiedName, Hash} | References]}};
        undefined ->
            %% every interface the compiler is given was compiled with its
            %% hashes, so a name without one is the toolchain's defect
            erlang:error({no_hash, ern_namespace:text(QualifiedName)})
    end.

%% A foreign function by its qualified name and its scheme; a foreign type,
%% which has none, by its name.
foreign_reference(QualifiedName, Env, Walk) ->
    case ern_typecheck:global_scheme(QualifiedName, Env) of
        undefined ->
            {{named, QualifiedName}, Walk};
        Scheme ->
            {Form, Walk1} = closed_scheme(Scheme, Walk),
            {{foreign, QualifiedName, Form}, Walk1}
    end.

%%
%% Expressions, report Appendix H
%%

expr(#e_literal{kind = Kind, value = Value}, Walk) ->
    {{literal, Kind, literal(Kind, Value)}, Walk};
expr(#e_var{referent = {prelude, ['Address', Name]} = Referent, supplies = Supplies,
            type = Type}, Walk)
  when Name =:= call; Name =:= callForever ->
    %% report §6.6: the reply is checked against the answer's type
    {Reference, Walk1} = value_reference(Referent, Name, Walk),
    {SupplyForms, Walk2} = lists:mapfoldl(fun supply/2, Walk1, Supplies),
    {tfn, [_, {tfn, [{tcon, ['Reply'], [Answer]}], _, _} | _], _, _} =
        ern_typecheck:resolve_type(Type, Walk2#walk.env),
    {AnswerForm, Walk3} = type(Answer, Walk2),
    {{var, Reference, SupplyForms, AnswerForm}, Walk3};
expr(#e_var{referent = Referent, name = Name, supplies = Supplies}, Walk) ->
    {Reference, Walk1} = value_reference(Referent, Name, Walk),
    {SupplyForms, Walk2} = lists:mapfoldl(fun supply/2, Walk1, Supplies),
    {{var, Reference, SupplyForms}, Walk2};
expr(#e_constructor{span = Span, namespace = Namespace, name = Name, base = Base, args = Args},
     Walk) ->
    {Constructor, Walk1} = constructor(Span, Namespace, Name, Walk),
    {ArgForms, Walk2} = construction(Base, Args, Walk1),
    {{construct, Constructor, ArgForms}, Walk2};
expr(#e_tuple{elements = Elements}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun expr/2, Walk, Elements),
    {{tuple, Forms}, Walk1};
expr(#e_list{elements = Elements}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun expr/2, Walk, Elements),
    {{list, Forms}, Walk1};
expr(#e_bitstring{segments = Segments}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun(#bit_segment{value = Value, specs = Specs}, Acc) ->
                                        segment(Specs, fun(Acc1) -> expr(Value, Acc1) end, Acc)
                                    end, Walk, Segments),
    {{bitstring, Forms}, Walk1};
expr(#e_block{statements = Statements}, #walk{scope = Scope} = Walk) ->
    %% report §5.4: a block's local functions are named in all of it
    Walk1 = lists:foldl(fun(#fn_declaration{name = Name}, Acc) -> element(2, bind(Name, Acc));
                           (_, Acc) -> Acc
                        end, Walk, Statements),
    {Forms, Walk2} = lists:mapfoldl(fun statement/2, Walk1, Statements),
    {{block, Forms}, Walk2#walk{scope = Scope}};
expr(#e_call{callee = Callee, args = Args, pipe = Pipe}, Walk) ->
    %% report §5.1: a pipe evaluates its first argument before a callee that
    %% is not a name, a constructor or a lambda
    IsNameOrLiteral = is_record(Callee, e_var) orelse is_record(Callee, e_constructor)
        orelse is_record(Callee, e_lambda),
    Tag = case Pipe andalso not IsNameOrLiteral of
              true -> piped_call;
              false -> call
          end,
    {CalleeForm, Walk1} = expr(Callee, Walk),
    {ArgForms, Walk2} = lists:mapfoldl(fun expr/2, Walk1, Args),
    {{Tag, CalleeForm, ArgForms}, Walk2};
expr(#e_selection{expr = Expr, field = Field}, #walk{env = Env} = Walk) ->
    %% report §3.5: the type the field is selected from
    {Form, Walk1} = expr(Expr, Walk),
    {tcon, QualifiedName, _} = ern_typecheck:resolve_type(ern_typecheck:node_type(Expr), Env),
    {Reference, Walk2} = type_reference(QualifiedName, Walk1),
    {{select, Form, Reference, Field}, Walk2};
expr(#e_not{expr = Expr}, Walk) ->
    {Form, Walk1} = expr(Expr, Walk),
    {{'not', Form}, Walk1};
expr(#e_negation{expr = Expr, member = Member}, Walk) ->
    {Form, Walk1} = expr(Expr, Walk),
    {Operation, Walk2} = operation(negate, Expr, Member, Walk1),
    {{negate, Form, Operation}, Walk2};
expr(#e_binop{operator = Operator, left = Left, right = Right, member = Member}, Walk) ->
    {LeftForm, Walk1} = expr(Left, Walk),
    {RightForm, Walk2} = expr(Right, Walk1),
    {Operation, Walk3} = operation(Operator, Left, Member, Walk2),
    {{operator, Operator, LeftForm, RightForm, Operation}, Walk3};
expr(#e_member{supply = Supply}, Walk) ->
    {Form, Walk1} = supply(Supply, Walk),
    {{member, Form}, Walk1};
expr(#e_lambda{params = Params, result_type = Result, effect = Effect, body = Body},
     #walk{scope = Scope} = Walk) ->
    {ParamForms, Walk1} = lists:mapfoldl(fun param/2, Walk, Params),
    {ResultForm, Walk2} = annotation(Result, Walk1),
    {EffectForm, Walk3} = annotation(Effect, Walk2),
    {BodyForm, Walk4} = expr(Body, Walk3),
    {{lambda, ParamForms, ResultForm, EffectForm, BodyForm}, Walk4#walk{scope = Scope}};
expr(#e_if{condition = Condition, then_branch = Then, else_branch = Else}, Walk) ->
    {[ConditionForm, ThenForm, ElseForm], Walk1} =
        lists:mapfoldl(fun expr/2, Walk, [Condition, Then, Else]),
    {{'if', ConditionForm, ThenForm, ElseForm}, Walk1};
expr(#e_match{scrutinee = Scrutinee, clauses = Clauses}, Walk) ->
    {ScrutineeForm, Walk1} = expr(Scrutinee, Walk),
    {ClauseForms, Walk2} = lists:mapfoldl(fun clause/2, Walk1, Clauses),
    {{match, ScrutineeForm, ClauseForms}, Walk2};
expr(#e_receive{clauses = Clauses, 'after' = After}, Walk) ->
    {ClauseForms, Walk1} = lists:mapfoldl(fun clause/2, Walk, Clauses),
    {AfterForm, Walk2} = case After of
                             undefined ->
                                 {none, Walk1};
                             #after_clause{timeout = Timeout, body = Body} ->
                                 {[TimeoutForm, BodyForm], Acc} =
                                     lists:mapfoldl(fun expr/2, Walk1, [Timeout, Body]),
                                 {{'after', TimeoutForm, BodyForm}, Acc}
                         end,
    {{'receive', ClauseForms, AfterForm}, Walk2}.

%% Report Appendix H: a literal's value in its fixed encoding.
literal(string, Value) when is_list(Value) -> unicode:characters_to_binary(Value);
literal(_, Value) -> Value.

%% Report §4.8, Appendix H: what an operator or a negation is: the member it
%% resolves to, or the runtime's own operation, at its operand's type where
%% the emitted code depends on it.
operation(Operator, Operand, undefined, #walk{} = Walk) ->
    case Operator =:= negate orelse lists:member(Operator, ?AT_TYPE) of
        true ->
            {Form, Walk1} = type(ern_typecheck:node_type(Operand), Walk),
            {{runtime, Form}, Walk1};
        false ->
            {runtime, Walk}
    end;
operation(_, _, Member, Walk) ->
    supply(Member, Walk).

%% A block's statement: a local function, whose name the block bound, a
%% binding, `=` or `<-`, its expression before its pattern, or an
%% expression.
statement(#fn_declaration{} = Declaration, Walk) ->
    function(Declaration, Walk);
statement(#binding{pattern = Pattern, annotation = Annotation, operator = '=', expr = Expr},
          Walk) ->
    {AnnotationForm, Walk1} = annotation(Annotation, Walk),
    {ExprForm, Walk2} = expr(Expr, Walk1),
    {PatternForm, Walk3} = pattern(Pattern, Walk2),
    {{bind, AnnotationForm, ExprForm, PatternForm}, Walk3};
statement(#binding{pattern = Pattern, annotation = Annotation, operator = '<-', expr = Expr},
          #walk{env = Env} = Walk) ->
    %% report §5.5: the sum a `<-` unwraps
    {tcon, [Sum], _} = ern_typecheck:resolve_type(ern_typecheck:node_type(Expr), Env),
    {AnnotationForm, Walk1} = annotation(Annotation, Walk),
    {ExprForm, Walk2} = expr(Expr, Walk1),
    {PatternForm, Walk3} = pattern(Pattern, Walk2),
    {{unwrap, {named, [Sum]}, AnnotationForm, ExprForm, PatternForm}, Walk3};
statement(Expr, Walk) ->
    expr(Expr, Walk).

clause(#clause{pattern = Pattern, guard = Guard, body = Body}, #walk{scope = Scope} = Walk) ->
    {PatternForm, Walk1} = pattern(Pattern, Walk),
    {GuardForm, Walk2} = case Guard of
                             undefined -> {none, Walk1};
                             _ -> expr(Guard, Walk1)
                         end,
    {BodyForm, Walk3} = expr(Body, Walk2),
    {{clause, PatternForm, GuardForm, BodyForm}, Walk3#walk{scope = Scope}}.

%% Report §3.5, Appendix H: a constructor by its type and its position in
%% the type's declared constructors.
constructor(Span, Namespace, Name, #walk{env = Env} = Walk) ->
    #constructor_info{name = Name, type_qualified_name = TypeQualifiedName} =
        ern_typecheck:lookup_constructor(Span, Namespace, Name, Env),
    #type_info{constructors = Constructors} = ern_typecheck:lookup_type(TypeQualifiedName, Env),
    Position = length(lists:takewhile(fun(#constructor_info{name = Other}) -> Other =/= Name end,
                                      Constructors)) + 1,
    {Reference, Walk1} = type_reference(TypeQualifiedName, Walk),
    {{constructor, Reference, Position}, Walk1}.

%% A construction's arguments, its fields in the order written (§5.1); a
%% path in an update the checker has made constructions of (§5.6).
construction(_, none, Walk) ->
    {none, Walk};
construction(_, {positional, Arg}, Walk) ->
    {Form, Walk1} = expr(Arg, Walk),
    {{positional, Form}, Walk1};
construction(Base, {named, FieldSets}, Walk) ->
    {BaseForm, Walk1} = case Base of
                            undefined -> {none, Walk};
                            _ -> expr(Base, Walk)
                        end,
    {FieldForms, Walk2} = lists:mapfoldl(fun(#field_set{name = Field, path = [], expr = Expr},
                                             Acc) ->
                                             {Form, Acc1} = expr(Expr, Acc),
                                             {{field, Field, Form}, Acc1}
                                         end, Walk1, FieldSets),
    {{named, BaseForm, FieldForms}, Walk2}.

%% Report §5.11, Appendix H: a segment, its specifiers with their defaults,
%% its size before its value.
segment(Specs, Value, Walk) ->
    {ok, #{kind := Kind, size := Size, unit := Unit, endian := Endian, sign := Sign}} =
        ern_bitspec:spec(Specs),
    {SizeForm, Walk1} = case Size of
                            {expr, SizeExpr} ->
                                {Form, Acc} = size(SizeExpr, Walk),
                                {{expr, Form}, Acc};
                            _ ->
                                {Size, Walk}
                        end,
    {ValueForm, Walk2} = Value(Walk1),
    {{segment, Kind, SizeForm, Unit, Endian, Sign, ValueForm}, Walk2}.

%% A size: in an expression, an expression of the scope; in a pattern, of
%% the scope where the pattern began and the bitstring's earlier segments
%% (report §5.11).
size(SizeExpr, #walk{outer = undefined} = Walk) ->
    expr(SizeExpr, Walk);
size(SizeExpr, #walk{scope = Scope, outer = Outer, segments = Segments} = Walk) ->
    {Form, Walk1} = expr(SizeExpr, Walk#walk{scope = maps:merge(Outer, Segments)}),
    {Form, Walk1#walk{scope = Scope}}.

%%
%% Supplies, report §4.9 and Appendix H
%%

supply(#known_member{qualified_name = QualifiedName, member = Member, supplies = Supplies},
       Walk) ->
    {Reference, Walk1} = member_reference(QualifiedName, Member, Walk),
    {SupplyForms, Walk2} = lists:mapfoldl(fun supply/2, Walk1, Supplies),
    {{known, Reference, SupplyForms}, Walk2};
supply(#required_member{variable = Variable, member = Member}, Walk) ->
    {Form, Walk1} = type(Variable, Walk),
    {{required, Form, Member}, Walk1};
supply(#shown_type{type = Type}, Walk) ->
    {Form, Walk1} = type(Type, Walk),
    {{shown, Form}, Walk1};
supply(#type_text{text = Text}, Walk) ->
    {{text, unicode:characters_to_binary(Text)}, Walk}.

%%
%% Patterns, report Appendix H
%%

%% A pattern, the scope where it begins kept for its bitstrings' sizes, and
%% the locals it binds, so that its alternatives bind the same numbers.
pattern(Pattern, #walk{scope = Scope} = Walk) ->
    {Form, Walk1} = pattern_part(Pattern, Walk#walk{outer = Scope, bound = #{}, segments = #{}}),
    {Form, Walk1#walk{outer = undefined, bound = #{}, segments = #{}}}.

pattern_part(#p_wildcard{}, Walk) ->
    {wildcard, Walk};
pattern_part(#p_var{name = Name}, Walk) ->
    {Number, Walk1} = bind(Name, Walk),
    {{local, Number}, Walk1};
pattern_part(#p_literal{kind = Kind, value = Value}, Walk) ->
    {{literal, Kind, literal(Kind, Value)}, Walk};
pattern_part(#p_constructor{span = Span, namespace = Namespace, name = Name, args = Args},
             #walk{env = Env} = Walk) ->
    {Constructor, Walk1} = constructor(Span, Namespace, Name, Walk),
    {ArgForms, Walk2} =
        case Args of
            none ->
                {none, Walk1};
            {positional, Pattern} ->
                {Form, Acc} = pattern_part(Pattern, Walk1),
                {{positional, Form}, Acc};
            {named, FieldPatterns} ->
                %% report §5.10: the fields in declared order, a field left
                %% out matching anything
                #constructor_info{fields = {named, Fields}} =
                    ern_typecheck:lookup_constructor(Span, Namespace, Name, Env),
                Given = [{Field, Pattern} || #field_pattern{name = Field, pattern = Pattern}
                                                 <- FieldPatterns],
                {Forms, Acc} = lists:mapfoldl(fun(Field, FieldAcc) ->
                                                  case lists:keyfind(Field, 1, Given) of
                                                      {_, Pattern} ->
                                                          pattern_part(Pattern, FieldAcc);
                                                      false ->
                                                          {wildcard, FieldAcc}
                                                  end
                                              end, Walk1, Fields),
                {{fields, Forms}, Acc}
        end,
    {{construct, Constructor, ArgForms}, Walk2};
pattern_part(#p_tuple{elements = Elements}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun pattern_part/2, Walk, Elements),
    {{tuple, Forms}, Walk1};
pattern_part(#p_list{elements = Elements}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun pattern_part/2, Walk, Elements),
    {{list, Forms}, Walk1};
pattern_part(#p_cons{head = Head, tail = Tail}, Walk) ->
    {[HeadForm, TailForm], Walk1} = lists:mapfoldl(fun pattern_part/2, Walk, [Head, Tail]),
    {{cons, HeadForm, TailForm}, Walk1};
pattern_part(#p_as{pattern = Pattern, name = Name}, Walk) ->
    {Form, Walk1} = pattern_part(Pattern, Walk),
    {Number, Walk2} = bind(Name, Walk1),
    {{as, Form, {local, Number}}, Walk2};
pattern_part(#p_or{alternatives = Alternatives}, Walk) ->
    {Forms, Walk1} = lists:mapfoldl(fun pattern_part/2, Walk, Alternatives),
    {{alternatives, Forms}, Walk1};
pattern_part(#p_bitstring{segments = Segments}, #walk{segments = Outside} = Walk) ->
    {Forms, Walk1} =
        lists:mapfoldl(fun(#bit_segment{value = Value, specs = Specs},
                           #walk{bound = Before, segments = Earlier} = Acc) ->
                           {Form, #walk{bound = After} = Acc1} =
                               segment(Specs, fun(Acc2) -> pattern_part(Value, Acc2) end, Acc),
                           %% report §5.11: what the segment bound, which a
                           %% later segment's size may name
                           Bound = maps:without(maps:keys(Before), After),
                           {Form, Acc1#walk{segments = maps:merge(Earlier, Bound)}}
                       end, Walk#walk{segments = #{}}, Segments),
    {{bitstring, Forms}, Walk1#walk{segments = Outside}}.

%% A local bound: the number its pattern's first alternative gave, or the
%% next.
bind(Name, #walk{scope = Scope, bound = Bound, locals = Locals} = Walk) ->
    case Bound of
        #{Name := Number} ->
            {Number, Walk#walk{scope = Scope#{Name => Number}}};
        _ ->
            Number = Locals + 1,
            {Number, Walk#walk{scope = Scope#{Name => Number}, bound = Bound#{Name => Number},
                               locals = Number}}
    end.

%%
%% The chunk, report §11.1
%%

%% The chunk's bytes: the form's version and the module's definitions,
%% compressed by the host, since a form names each hash it references in
%% full wherever it stands (report §11.1); a hash is taken of a form's own
%% bytes, uncompressed (Appendix H).
-spec encode(canonical()) -> binary().
encode(#{definitions := Definitions}) ->
    term_to_binary({?FORM_VERSION, Definitions}, [compressed]).

%% A compiled module's definitions as its chunk holds them, read as data
%% alone, since a `.erc` may come from anywhere (ern_chunk); a chunk of
%% another version reads as an error.
-spec read(binary()) -> {ok, [#definition{}]} | {error, string()}.
read(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(?CHUNK)], [allow_missing_chunks]) of
        {ok, {_, [{_, missing_chunk}]}} ->
            {error, "the module holds no canonical forms"};
        {ok, {_, [{_, Chunk}]}} ->
            case ern_chunk:term(Chunk) of
                {ok, {?FORM_VERSION, Definitions}} when is_list(Definitions) ->
                    {ok, Definitions};
                _ ->
                    {error, "the canonical forms are of another compiler version"}
            end;
        {error, beam_lib, _} ->
            {error, "not a compiled module"}
    end.
