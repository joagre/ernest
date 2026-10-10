%% The canonical form of report Appendix H: each definition of a checked
%% module as the term its hash is taken of, the hashes, and the chunk
%% "ErnC" of a compiled module that holds them (§8.7, §11.1). The emitter
%% calls module/5 and writes the chunk, and the interface carries each
%% definition's hash by its qualified name (interface/2), by which a
%% dependent's forms name it, and each function's reach, the bindings and
%% the foreign declarations it names transitively, by which a dependent's
%% reaches take it in (§11.1). Beside them module/4 gives the emitter the
%% hash of each type a service is made at, and the identity and the reach of
%% each lambda and local function, by its span, which a spawn on a peer
%% names (§8.7).
%%
%% A form is made in two steps. The walk writes each definition with a
%% reference to another definition of its own module left open, `{'$own',
%% QualifiedName}`, a tuple no program can write, since no Ernest name
%% begins with `$`; the module's definitions then fall into the strongly
%% connected components of those references, which are hashed in
%% dependency order, each open reference closed as its component's place
%% or the hash of what it names.
-module(ern_canonical).

-export([form_version/0, chunk_name/0, bytes/1, module/4, module/5, interface/2, lambdas/2,
         encode/1, read/1]).

-export_type([canonical/0, reach/0]).

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
                       references := [{[atom()], binary()}],
                       reaches := #{[atom()] => reach()},
                       functions := #{term() => {[atom()], pos_integer(), reach()}},
                       services := #{term() => binary()}}.

%% Report §8.7, §11.1: what a function's reach names that a peer must hold
%% for it to run there: each top-level binding by its identity, and each
%% foreign declaration of a program by its qualified name; the standard
%% library and the prelude, named by name, are the floor's (Appendix H).
-type reach() :: {[{[atom()], binary()}], [[atom()]]}.

%% The walk of one definition (Appendix H): env, the checker's; namespace,
%% the module's; form_namespace, the namespace a form writes a name the
%% session declares under (module/5, form_name/2); standard, whether the
%% module is the standard library's own, whose every reference is by name;
%% own, the module's declarations by qualified name, each function,
%% binding, type or foreign; scope, each local's name to its number; outer,
%% the scope where the pattern being walked began, undefined outside a
%% pattern; bound, the locals that pattern has bound; segments, the locals
%% a bitstring pattern's earlier segments bound; locals, the numbers taken;
%% variables, each type variable, {tvar, Id} or {name, Name}, to its
%% number; names, each variable the annotation being walked writes, by its
%% name, to the type variable the checker gave its place (matched/3);
%% references, the other modules' definitions referenced by hash;
%% functions, the span of each lambda and local function met, reversed, in
%% the order the walk meets them, which is their positions' (lambdas/2);
%% services, each service's message type with its form, its own module's
%% types left open.
-record(walk, {env, namespace, form_namespace, standard, own, scope = #{}, outer,
               bound = #{}, segments = #{}, locals = 0, variables = #{}, names = #{},
               references = [], functions = [], services = []}).

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
%% `foreign` for each foreign declaration; the definitions of other
%% modules the forms reference by hash, which the build compares (§11.1);
%% each definition's reach; each lambda and local function by its span,
%% with its enclosing definition, its position there and its reach; and the
%% hash of each type a service is made at. Standard: whether the module is the
%% standard library's own.
-spec module([atom()], [tuple()], ern_typecheck:env(), boolean()) -> canonical().
module(Namespace, Typed, Env, Standard) ->
    module(Namespace, Typed, Env, Standard, Namespace).

%% The same, each name a declaration of the module's makes written in its
%% forms under FormNamespace: the module's own, or, for an input of a
%% shell's session, the session's one namespace, as is every name another
%% input or a holder of the session declares, a type's, a top-level
%% binding's and a foreign declaration's, whatever input declares it, so
%% that one declaration is one definition in every session and at every
%% input (Appendix H, §11.2). The checker's names, the unit, the
%% references the build compares and what prints keep the input's
%% namespace.
-spec module([atom()], [tuple()], ern_typecheck:env(), boolean(), [atom()]) -> canonical().
module(Namespace, Typed, Env, Standard, FormNamespace) ->
    Own = maps:from_list([{QualifiedName, Kind}
                          || Declaration <- Typed,
                             {QualifiedName, Kind} <- declared(Namespace, Declaration)]),
    Walk = #walk{env = Env, namespace = Namespace, form_namespace = FormNamespace,
                 standard = Standard, own = Own},
    Opened = [{QualifiedName, Kind, opened(Declaration, Walk)}
              || Declaration <- Typed,
                 {QualifiedName, Kind} <- declared(Namespace, Declaration), Kind =/= foreign],
    Definitions = closed([{QualifiedName, Kind, Form}
                          || {QualifiedName, Kind, {Form, _}} <- Opened]),
    References = lists:usort(lists:append([Walked#walk.references
                                           || {_, _, {_, Walked}} <- Opened])),
    Reaches = reaches(Definitions, maps:from_list([{Hash, ern_typecheck:reach(QualifiedName, Env)}
                                                   || {QualifiedName, Hash} <- References])),
    Closing = lists:foldl(fun closing/2, #{}, Definitions),
    ByName = maps:from_list([{QualifiedName, Definition}
                             || #definition{qualified_name = QualifiedName} = Definition
                                    <- Definitions]),
    #{definitions => Definitions,
      identities => maps:from_list([{QualifiedName, Hash}
                                    || #definition{qualified_name = QualifiedName,
                                                   hash = Hash} <- Definitions]
                                   ++ [{QualifiedName, foreign}
                                       || QualifiedName := foreign <- Own]),
      references => References,
      reaches => maps:from_list([{QualifiedName, maps:get(Hash, Reaches)}
                                 || #definition{qualified_name = QualifiedName, kind = function,
                                                hash = Hash} <- Definitions]),
      functions => maps:from_list(
                     lists:append([functions(maps:get(QualifiedName, ByName), Walked, Reaches)
                                    || {QualifiedName, _, {_, Walked}} <- Opened])),
      services => maps:from_list([{Type, hash({ernest_type, ?FORM_VERSION, close(Form, Closing)})}
                                  || {_, _, {_, Walked}} <- Opened,
                                     {Type, Form} <- Walked#walk.services])}.

%% Report §11.1: the interface with the hashes a dependent's forms name, and
%% the reaches of its functions that name a binding or a foreign
%% declaration, which a dependent's reaches take in.
-spec interface(#interface{}, canonical()) -> #interface{}.
interface(Interface, #{identities := Identities, reaches := Reaches}) ->
    Interface#interface{identities = Identities,
                        reaches = maps:filter(fun(_, Reach) -> Reach =/= {[], []} end,
                                              Reaches)}.

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
%% walk that made it, which holds the other modules' definitions it
%% references by hash, its lambdas' and local functions' spans, and its
%% services' types.
opened(#fn_declaration{} = Declaration, Walk) ->
    function(Declaration, Walk);
opened(#let_declaration{scheme = #scheme{type = Type} = Scheme, annotation = Annotation,
                        body = Body}, Walk) ->
    {SchemeForm, Walk1} = scheme(Scheme, matched(Annotation, Type, Walk)),
    {AnnotationForm, Walk2} = annotation(Annotation, Walk1),
    {BodyForm, Walk3} = expr(Body, Walk2),
    {{binding, SchemeForm, AnnotationForm, BodyForm}, Walk3};
opened(#abstract_declaration{declaration = Declaration}, Walk) ->
    opened(Declaration, Walk);
opened(#type_declaration{name = Name, derives = Derives},
       #walk{namespace = Namespace, env = Env, own = Own} = Walk) ->
    #type_info{params = Params, constructors = Constructors} =
        ern_typecheck:lookup_type(Namespace ++ [Name], Env),
    %% report Appendix H: the parameters are the variables 1 to its arity
    Walk1 = lists:foldl(fun(Param, Acc) -> element(2, variable(Param, Acc)) end, Walk, Params),
    %% report §3.10, §8.7: the order the module declares for it, which
    %% references the type in turn, so that the two are one group
    Compare = Namespace ++ [Name, compare],
    {CompareForm, Walk2} = case Own of
                               #{Compare := _} -> declaration_reference(Namespace, Compare, Walk1);
                               _ -> {none, Walk1}
                           end,
    {ConstructorForms, Walk3} = lists:mapfoldl(fun constructor_declared/2, Walk2, Constructors),
    {{type, form_name(Namespace ++ [Name], Walk3), length(Params), Derives =/= undefined,
      CompareForm, ConstructorForms},
     Walk3}.

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
%% Reaches, report §8.7 and §11.1
%%

%% Each definition's reach by its hash: the bindings and the foreign
%% declarations its form names, and those of every definition it references
%% by hash, its own module's from its form and another module's from its
%% interface (Others); the members of a group share the group's.
reaches(Definitions, Others) ->
    Groups = maps:groups_from_list(fun(#definition{group = Group, hash = Hash}) ->
                                       case Group of
                                           none -> Hash;
                                           {GroupHash, _} -> GroupHash
                                       end
                                   end, Definitions),
    ByHash = maps:from_list([{Hash, maps:get(case Group of none -> Hash; {Of, _} -> Of end, Groups)}
                             || #definition{hash = Hash, group = Group} <- Definitions]),
    lists:foldl(fun(#definition{hash = Hash}, Known) -> element(2, reach(Hash, ByHash, Known)) end,
                Others, Definitions).

%% A definition's reach, with every reach found on the way known; one of
%% another module, or a type's, which names neither, is known or empty. A
%% group's binding members are in its reach, since its members name one
%% another by position (named/4): a type's compare that reads a binding is
%% one group with both.
reach(Hash, ByHash, Known) ->
    case {Known, ByHash} of
        {#{Hash := Reach}, _} ->
            {Reach, Known};
        {_, #{Hash := Members}} ->
            {Reach, Known1} = lists:foldl(fun(#definition{form = Form}, {Acc, KnownAcc}) ->
                                              {Named, KnownAcc1} =
                                                  named(Form, none, ByHash, KnownAcc),
                                              {union(Acc, Named), KnownAcc1}
                                          end, {group_bindings(Members), Known}, Members),
            {Reach, lists:foldl(fun(#definition{hash = Member}, Acc) -> Acc#{Member => Reach} end,
                                Known1, Members)};
        _ ->
            {{[], []}, Known}
    end.

%% The binding members of a group of two or more, by their identities.
group_bindings([_, _ | _] = Members) ->
    {lists:sort([{QualifiedName, Hash}
                 || #definition{qualified_name = QualifiedName, kind = binding, hash = Hash}
                        <- Members]),
     []};
group_bindings(_) ->
    {[], []}.

%% What a closed form's reach names: a binding by its identity, a foreign
%% declaration of a program by its qualified name, and a definition it
%% references by hash through that definition's reach; a member of its own
%% group is Group's, the reach of the definition the form is part of, which
%% a definition's own form leaves to the group's union (none).
named({binding, QualifiedName, Hash}, _, _, Known) when is_binary(Hash) ->
    {{[{QualifiedName, Hash}], []}, Known};
named({foreign, QualifiedName, {scheme, _, _, _}}, _, _, Known) ->
    {{[], [QualifiedName]}, Known};
named({hash, Hash}, _, ByHash, Known) when is_binary(Hash) ->
    reach(Hash, ByHash, Known);
named({in_group, Position}, Group, _, Known) when is_integer(Position) ->
    case Group of
        none -> {{[], []}, Known};
        _ -> {Group, Known}
    end;
named(Term, Group, ByHash, Known) when is_tuple(Term) ->
    named(tuple_to_list(Term), Group, ByHash, Known);
named(Terms, Group, ByHash, Known) when is_list(Terms) ->
    lists:foldl(fun(Part, {Acc, KnownAcc}) ->
                    {Named, KnownAcc1} = named(Part, Group, ByHash, KnownAcc),
                    {union(Acc, Named), KnownAcc1}
                end, {{[], []}, Known}, Terms);
named(_, _, _, Known) ->
    {{[], []}, Known}.

union({Bindings, Foreigns}, {MoreBindings, MoreForeigns}) ->
    {lists:umerge(Bindings, MoreBindings), lists:umerge(Foreigns, MoreForeigns)}.

%% Report §8.7: each lambda and local function of a definition by its span,
%% with the definition's qualified name, its position and its reach; the
%% walk met them in the order of their positions.
functions(#definition{qualified_name = QualifiedName, hash = Hash, form = Form}, Walked, Reaches) ->
    Spans = lists:reverse(Walked#walk.functions),
    Found = lambdas(Hash, Form),
    length(Spans) =:= length(Found)
        orelse erlang:error({functions_out_of_order, ern_namespace:text(QualifiedName)}),
    Reach = maps:get(Hash, Reaches),
    [{Span, {QualifiedName, Position, element(1, named(Function, Reach, #{}, Reaches))}}
     || {Span, {{_, Position}, Function}} <- lists:zip(Spans, Found)].

%%
%% Functions and schemes
%%

%% Report Appendix H: a function, top-level or local, its scheme first; its
%% signature's variables numbered by the type variables of its scheme.
function(#fn_declaration{scheme = #scheme{type = Type} = Scheme, params = Params,
                         result_type = Result, effect = Effect, requirement = Needs,
                         body = Body},
         #walk{scope = Scope, names = Names} = Walk) ->
    Signature = signature(Params, Result, Effect),
    {SchemeForm, Walk1} = scheme(Scheme, matched(Signature, Type, Walk)),
    {ParamForms, Walk2} = lists:mapfoldl(fun param/2, Walk1, Params),
    {ResultForm, Walk3} = annotation(Result, Walk2),
    {EffectForm, Walk4} = annotation(Effect, Walk3),
    {NeedsForms, Walk5} = lists:mapfoldl(fun needs/2, Walk4, Needs),
    {BodyForm, Walk6} = expr(Body, Walk5),
    {{function, SchemeForm, ParamForms, ResultForm, EffectForm, NeedsForms, BodyForm},
     Walk6#walk{scope = Scope, names = Names}}.

%% The annotations of a function's or a lambda's parameters, result and
%% effect, as the function type they write.
signature(Params, Result, Effect) ->
    #t_fn{params = [Annotation || #param{annotation = Annotation} <- Params],
          result_type = Result, effect = Effect}.

param(#param{pattern = Pattern, annotation = Annotation}, Walk) ->
    {PatternForm, Walk1} = pattern(Pattern, Walk),
    {AnnotationForm, Walk2} = annotation(Annotation, Walk1),
    {{param, PatternForm, AnnotationForm}, Walk2}.

%% A member of the `needs` clause as written (§4.9), its type variable the
%% signature's of its name.
needs(#member{member_of = Variable, name = Member}, Walk) ->
    {Number, Walk1} = annotation_variable(Variable, Walk),
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
                            form_namespace = FormNamespace, references = References} = Walk) ->
    {Form, #walk{references = Named}} =
        scheme(Scheme, #walk{env = Env, standard = Standard, own = Own, namespace = Namespace,
                             form_namespace = FormNamespace, references = References}),
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
%% variable it writes numbered by the type variable the checker resolved it
%% to (matched/3), so that two local functions or lambdas that each name
%% their own variable are numbered as their schemes are, whatever the
%% names (§3.9).
annotation(undefined, Walk) ->
    {none, Walk};
annotation(Annotation, Walk) ->
    annotated(Annotation, Walk).

annotated(#t_var{name = Name}, Walk) ->
    {Number, Walk1} = annotation_variable(Name, Walk),
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

%% Report §3.9: an annotation variable's number, that of the type variable
%% the checker gave its place, and by its name where it gave none.
annotation_variable(Name, #walk{names = Names} = Walk) ->
    variable(maps:get(Name, Names, {name, Name}), Walk).

%% Report §3.9: Walk with the variables Annotation writes taken to the type
%% variables of Type, the type the checker gave the annotated place, which
%% is a variable at each of them, an annotation variable being rigid.
matched(Annotation, Type, #walk{env = Env, names = Names} = Walk) ->
    Walk#walk{names = matching(Annotation, Type, Env, Names)}.

matching(Annotation, Type, Env, Names) ->
    case {Annotation, ern_typecheck:resolve_type(Type, Env)} of
        {#t_var{name = Name}, {tvar, _} = Variable} ->
            Names#{Name => Variable};
        {#t_named{args = Args}, {tcon, _, Types}} when length(Args) =:= length(Types) ->
            matching_all(Args, Types, Env, Names);
        {#t_tuple{elements = Elements}, {ttuple, Types}} when length(Elements) =:= length(Types) ->
            matching_all(Elements, Types, Env, Names);
        {#t_fn{params = Params, result_type = Result, effect = Effect},
         {tfn, ParamTypes, EffectType, ResultType}} when length(Params) =:= length(ParamTypes) ->
            matching_all([Result, Effect | Params], [ResultType, EffectType | ParamTypes], Env,
                         Names);
        _ ->
            Names
    end.

matching_all(Annotations, Types, Env, Names) ->
    lists:foldl(fun({Annotation, Type}, Acc) -> matching(Annotation, Type, Env, Acc) end, Names,
                lists:zip(Annotations, Types)).

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
                            true -> {binding, form_name(QualifiedName, Walk), Hash};
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
            {{named, form_name(QualifiedName, Walk)}, Walk};
        Scheme ->
            {Form, Walk1} = closed_scheme(Scheme, Walk),
            {{foreign, form_name(QualifiedName, Walk), Form}, Walk1}
    end.

%% Report Appendix H, §11.2, §2.3: a qualified name as a form writes it:
%% where a shell's session declared it, an input or the holder of what a
%% `let` at the prompt binds, whose namespace begins with `$` as no Ernest
%% name does, under the session's one namespace, so that one declaration
%% is one name in every session and at every input; any other as it is.
%% Only an input's form is written under the session's namespace.
form_name([Segment | Rest] = QualifiedName,
          #walk{namespace = Namespace, form_namespace = FormNamespace})
  when FormNamespace =/= Namespace ->
    case atom_to_list(Segment) of
        "$" ++ _ -> FormNamespace ++ Rest;
        _ -> QualifiedName
    end;
form_name(QualifiedName, _) ->
    QualifiedName.

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
expr(#e_lambda{span = Span, params = Params, result_type = Result, effect = Effect,
               body = Body, type = Type},
     #walk{scope = Scope, names = Names, functions = Functions} = Walk) ->
    %% report §8.7: its position, in the order the walk meets it
    Walk1 = matched(signature(Params, Result, Effect), Type,
                    Walk#walk{functions = [Span | Functions]}),
    {ParamForms, Walk2} = lists:mapfoldl(fun param/2, Walk1, Params),
    {ResultForm, Walk3} = annotation(Result, Walk2),
    {EffectForm, Walk4} = annotation(Effect, Walk3),
    {BodyForm, Walk5} = expr(Body, Walk4),
    {{lambda, ParamForms, ResultForm, EffectForm, BodyForm},
     Walk5#walk{scope = Scope, names = Names}};
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
statement(#fn_declaration{span = Span} = Declaration, #walk{functions = Functions} = Walk) ->
    %% report §8.7: its position, in the order the walk meets it
    function(Declaration, Walk#walk{functions = [Span | Functions]});
statement(#binding{pattern = Pattern, annotation = Annotation, operator = '=', expr = Expr},
          #walk{names = Names} = Walk) ->
    {AnnotationForm, Walk1} =
        annotation(Annotation, matched(Annotation, ern_typecheck:node_type(Expr), Walk)),
    {ExprForm, Walk2} = expr(Expr, Walk1#walk{names = Names}),
    {PatternForm, Walk3} = pattern(Pattern, Walk2),
    {{bind, AnnotationForm, ExprForm, PatternForm}, Walk3};
statement(#binding{pattern = Pattern, annotation = Annotation, operator = '<-', expr = Expr},
          #walk{env = Env, names = Names} = Walk) ->
    %% report §5.5: the sum a `<-` unwraps, the annotation the type of what
    %% it unwraps to, its last argument
    {tcon, [Sum], Args} = ern_typecheck:resolve_type(ern_typecheck:node_type(Expr), Env),
    {AnnotationForm, Walk1} = annotation(Annotation, matched(Annotation, lists:last(Args), Walk)),
    {ExprForm, Walk2} = expr(Expr, Walk1#walk{names = Names}),
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
supply(#shown_type{type = Type, member = show}, Walk) ->
    %% Appendix H, E.1: `show` at the type with the view the site has of
    %% it, the types it prints as `<abstract>`
    {Form, Walk1} = type(Type, Walk),
    {AbstractForms, Walk2} = lists:mapfoldl(fun type_reference/2, Walk1,
                                            shown_abstract(Type, Walk1)),
    {{shown, Form, AbstractForms}, Walk2};
supply(#shown_type{type = Type, member = exposed}, Walk) ->
    %% Appendix H, E.12: the type Foreign.term gives its value at
    {Form, Walk1} = type(Type, Walk),
    {{shown, Form}, Walk1};
supply(#service_type{type = Type}, Walk) ->
    %% report §8.7: the service's message type, whose hash it carries
    {Form, #walk{services = Services} = Walk1} = type(Type, Walk),
    {{service, Form}, Walk1#walk{services = [{Type, Form} | Services]}}.

%% Appendix E.1, §4.4: the types a `show` at Type, known whole, prints as
%% `<abstract>` from the walk's module, each once, in the order the printer
%% meets them, as the emitter's descriptor marks them (ern_descriptor):
%% each abstract type of another module where the printer reads the value,
%% in a tuple's elements, a list's, a set's or a map's, and a declared
%% type's fields at its arguments, and nothing inside one; nor an
%% address's, a reply's or a function's, which it prints by their kind
%% alone, nor a foreign type's.
shown_abstract(Type, #walk{env = Env, namespace = Namespace}) ->
    {_, Abstract} = shown_abstract(ern_typecheck:resolve_type(Type, Env), Env, Namespace,
                                   {#{}, []}),
    lists:reverse(Abstract).

shown_abstract({ttuple, Elements}, Env, Namespace, Acc) ->
    shown_abstract_all(Elements, Env, Namespace, Acc);
shown_abstract({tcon, [Name], Args}, Env, Namespace, Acc)
  when Name =:= 'List'; Name =:= 'Set'; Name =:= 'Map' ->
    shown_abstract_all(Args, Env, Namespace, Acc);
shown_abstract({tcon, QualifiedName, Args} = Type, Env, Namespace, {Seen, Found} = Acc) ->
    case is_map_key(Type, Seen) of
        true ->
            Acc;
        false ->
            Seen1 = Seen#{Type => true},
            Outside = lists:droplast(QualifiedName) =/= Namespace,
            case ern_typecheck:described_type(QualifiedName, Env) of
                #type_info{abstract = true} when Outside ->
                    case lists:member(QualifiedName, Found) of
                        true -> {Seen1, Found};
                        false -> {Seen1, [QualifiedName | Found]}
                    end;
                _ ->
                    case ern_typecheck:declared_fields(QualifiedName, Args, Env) of
                        {ok, Fields} -> shown_abstract_all(Fields, Env, Namespace, {Seen1, Found});
                        none -> {Seen1, Found}
                    end
            end
    end;
shown_abstract(_, _, _, Acc) ->
    Acc.

shown_abstract_all(Types, Env, Namespace, Acc) ->
    lists:foldl(fun(Type, Acc1) -> shown_abstract(Type, Env, Namespace, Acc1) end, Acc, Types).

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
%% another version of the form reads as an error that says so.
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
                    {error, "the canonical forms are of another version of the form"}
            end;
        {error, beam_lib, _} ->
            {error, "not a compiled module"}
    end.
