%% Report §4.2: a qualified name resolves from the writer's namespace
%% outward. Its first segment is looked up as a module namespace directly
%% under the writer's own namespace, then under each enclosing namespace in
%% turn, and last at the root; the segments after it descend from the
%% namespace found. A name is written in its shortest resolving form, and
%% one written longer is an error whose help writes the short one (§11.5).
%%
%% The build resolves a module's names here, once it is parsed and before
%% its dependencies are found and it is checked, so that every later stage
%% reads each name whole, as it did before names were relative. The pass
%% asks the build which namespaces below the root hold a module,
%% IsNamespace, since only the build reads the roots; the root holds every
%% first segment no nearer namespace does, and is asked of only for the help
%% of a name unknown where a nearer namespace hid it (out_of_reach/4).
%%
%% A type or a constructor of the module's own namespace written qualified
%% is refused here, since no binding hides one (§4.2). `Prelude.` and a
%% value of the module's own namespace are left to the checker, whose rules
%% for them read which binding hides a name.
-module(ern_resolve).

-export([resolved/3, qualifiers/3, shortest/3, too_long/4, out_of_reach/4, name_span/2]).

-export_type([is_namespace/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").

%% Whether a namespace below the root, one segment under the writer's own
%% namespace or under a namespace the writer stands in, holds a module.
-type is_namespace() :: fun(([atom(), ...]) -> boolean()).

%% Report §4.2, §11.1: Declarations with each qualified name's namespace the
%% one it resolves to from OwnNamespace, its `written` the namespace as the
%% source writes it; each qualifier the source writes with the namespace it
%% resolves to, which the `.erc` records; and the error of each name written
%% longer than its shortest resolving form.
-spec resolved([tuple()], [atom()], is_namespace()) ->
          {[tuple()], [{[atom()], [atom()]}], [ern_diagnostic:diagnostic()]}.
resolved(Declarations, OwnNamespace, IsNamespace) ->
    WithShortest = with_shortest(lists:usort(written(Declarations, [])), OwnNamespace,
                                 IsNamespace),
    Resolved = {OwnNamespace, maps:from_list(WithShortest)},
    {Rewritten, Errors} = rewritten(Declarations, Resolved, []),
    {Rewritten, [{Qualifier, Namespace} || {Qualifier, {Namespace, _}} <- WithShortest],
     lists:sort(Errors)}.

%% Report §11.1, §11.2: each qualifier of Written, as a `.erc` records them,
%% with the namespace it resolves to from OwnNamespace in the tree as it now
%% is, by which the shell's reload finds a module `ern build` recompiles
%% though its source is as it was.
-spec qualifiers([[atom(), ...]], [atom()], is_namespace()) -> [{[atom()], [atom()]}].
qualifiers(Written, OwnNamespace, IsNamespace) ->
    [{Qualifier, Namespace}
     || {Qualifier, {Namespace, _}} <- with_shortest(Written, OwnNamespace, IsNamespace)].

%% Report §4.2: the shortest form of a namespace from OwnNamespace, which the
%% checker asks of the module's own, a name of which a module writes
%% qualified where a binding hides its plain name.
-spec shortest([atom(), ...], [atom()], is_namespace()) -> [atom(), ...].
shortest(Namespace, OwnNamespace, IsNamespace) ->
    {Shortest, _} = shortest_form(length(Namespace), Namespace, OwnNamespace, IsNamespace, #{}),
    Shortest.

%%
%% The qualifiers a source writes
%%

%% Every qualifier the source writes: a qualified name's namespace, and the
%% namespace a fill names after `..`, of which the name is the last
%% segment (report §5.6). `Prelude.` reaches the prelude's names and is the
%% checker's (§4.2).
written(#e_constructor{written = Written, base = Base, args = Args}, Acc) ->
    written(Args, written_base(Base, qualifier(Written, Acc)));
written(#e_var{written = Written}, Acc) ->
    qualifier(Written, Acc);
written(#p_constructor{written = Written, args = Args}, Acc) ->
    written(Args, qualifier(Written, Acc));
written(#t_named{written = Written, args = Args}, Acc) ->
    written(Args, qualifier(Written, Acc));
written(Node, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    written(tl(tuple_to_list(Node)), Acc);
written(Nodes, Acc) when is_list(Nodes) ->
    lists:foldl(fun written/2, Acc, Nodes);
written(_, Acc) ->
    Acc.

%% Report §5.6: the name after `..` is a namespace where it is a qualified
%% name of type names alone, which the parser reads as a constructor, and
%% an expression otherwise.
written_base(#e_constructor{written = Written, name = Name, args = none, base = undefined},
             Acc) ->
    qualifier(Written ++ [Name], Acc);
written_base(Base, Acc) ->
    written(Base, Acc).

qualifier(['Prelude' | _], Acc) -> Acc;
qualifier([_ | _] = Written, Acc) -> [Written | Acc];
qualifier([], Acc) -> Acc.

%%
%% Resolution
%%

%% Each qualifier of Written with the namespace it resolves to and its
%% shortest form (qualifier_resolved/4), Probed shared among them.
with_shortest(Written, OwnNamespace, IsNamespace) ->
    {Qualifiers, _} = lists:mapfoldl(fun(Qualifier, Probed) ->
                                         qualifier_resolved(Qualifier, OwnNamespace, IsNamespace,
                                                            Probed)
                                     end, #{}, Written),
    Qualifiers.

%% A written qualifier with the namespace it resolves to, and its shortest
%% form where that is to be held to: none for the module's own namespace,
%% which the checker holds (§4.2), and for a namespace that holds no
%% module, which names nothing, as the checker says. Probed holds each
%% namespace IsNamespace was asked of in the module's pass, asked once.
qualifier_resolved([First | Rest] = Written, OwnNamespace, IsNamespace, Probed) ->
    {Above, Probed1} = climbed(First, OwnNamespace, IsNamespace, Probed),
    Namespace = Above ++ [First | Rest],
    {Held, Probed2} = held(Namespace, OwnNamespace, IsNamespace, Probed1),
    case Held of
        true ->
            {Shortest, Probed3} = shortest_form(length(Namespace), Namespace, OwnNamespace,
                                                IsNamespace, Probed2),
            {{Written, {Namespace, Shortest}}, Probed3};
        false ->
            {{Written, {Namespace, none}}, Probed2}
    end.

%% The namespace a first segment stands under: the nearest of OwnNamespace
%% and the namespaces it stands in under which the segment is a namespace
%% that holds a module, and the root, [], where none is.
climbed(Segment, OwnNamespace, IsNamespace, Probed) ->
    climbed_from(lists:reverse(OwnNamespace), Segment, IsNamespace, Probed).

climbed_from([], _Segment, _IsNamespace, Probed) ->
    {[], Probed};
climbed_from([_ | Outer] = Reversed, Segment, IsNamespace, Probed) ->
    Above = lists:reverse(Reversed),
    case probed(Above ++ [Segment], IsNamespace, Probed) of
        {true, Probed1} -> {Above, Probed1};
        {false, Probed1} -> climbed_from(Outer, Segment, IsNamespace, Probed1)
    end.

%% Whether a resolved namespace is one to hold to its shortest form: not the
%% module's own, and below the root in the writer's tree, holding a module;
%% one at the root of another tree has no shorter form.
held(OwnNamespace, OwnNamespace, _IsNamespace, Probed) ->
    {false, Probed};
held([First, _ | _] = Namespace, [First | _], IsNamespace, Probed) ->
    probed(Namespace, IsNamespace, Probed);
held(_Namespace, _OwnNamespace, _IsNamespace, Probed) ->
    {false, Probed}.

%% From the last segment back: the fewest last segments of Namespace whose
%% first, looked up from OwnNamespace, is found under the segments before
%% it, which OwnNamespace stands in; the whole name where none is.
shortest_form(1, Namespace, _OwnNamespace, _IsNamespace, Probed) ->
    {Namespace, Probed};
shortest_form(Index, Namespace, OwnNamespace, IsNamespace, Probed) ->
    Above = lists:sublist(Namespace, Index - 1),
    case lists:prefix(Above, OwnNamespace) of
        true ->
            case climbed(lists:nth(Index, Namespace), OwnNamespace, IsNamespace, Probed) of
                {Above, Probed1} ->
                    {lists:nthtail(Index - 1, Namespace), Probed1};
                {_, Probed1} ->
                    shortest_form(Index - 1, Namespace, OwnNamespace, IsNamespace, Probed1)
            end;
        false ->
            shortest_form(Index - 1, Namespace, OwnNamespace, IsNamespace, Probed)
    end.

probed(Namespace, IsNamespace, Probed) ->
    case Probed of
        #{Namespace := Holds} ->
            {Holds, Probed};
        _ ->
            Holds = IsNamespace(Namespace),
            {Holds, Probed#{Namespace => Holds}}
    end.

%%
%% The rewrite
%%

%% Each qualified node with its namespace the one its qualifier resolves to,
%% and an error, gathered in Acc, for each written longer than its shortest
%% form.
rewritten(#e_var{written = [_ | _] = Written, name = Name, span = Span} = Var, Resolved, Acc) ->
    {Namespace, Acc1} = named(value, Span, Written, [Name], Resolved, Acc),
    {Var#e_var{namespace = Namespace}, Acc1};
rewritten(#e_constructor{written = Written, name = Name, span = Span, base = Base,
                         args = Args} = Constructor, Resolved, Acc) ->
    {Base1, Acc1} = rewritten_base(Base, Resolved, Acc),
    {Args1, Acc2} = rewritten(Args, Resolved, Acc1),
    {Namespace, Acc3} = named(type, Span, Written, [Name], Resolved, Acc2),
    {Constructor#e_constructor{namespace = Namespace, base = Base1, args = Args1}, Acc3};
rewritten(#p_constructor{written = Written, name = Name, span = Span, args = Args} = Pattern,
          Resolved, Acc) ->
    {Args1, Acc1} = rewritten(Args, Resolved, Acc),
    {Namespace, Acc2} = named(type, Span, Written, [Name], Resolved, Acc1),
    {Pattern#p_constructor{namespace = Namespace, args = Args1}, Acc2};
rewritten(#t_named{written = Written, name = Name, span = Span, args = Args} = Type, Resolved,
          Acc) ->
    {Args1, Acc1} = rewritten(Args, Resolved, Acc),
    {Namespace, Acc2} = named(type, Span, Written, [Name], Resolved, Acc1),
    {Type#t_named{namespace = Namespace, args = Args1}, Acc2};
rewritten(Node, Resolved, Acc) when is_tuple(Node), is_atom(element(1, Node)) ->
    [Tag | Children] = tuple_to_list(Node),
    {Children1, Acc1} = rewritten(Children, Resolved, Acc),
    {list_to_tuple([Tag | Children1]), Acc1};
rewritten(Nodes, Resolved, Acc) when is_list(Nodes) ->
    lists:mapfoldl(fun(Child, Errors) -> rewritten(Child, Resolved, Errors) end, Acc, Nodes);
rewritten(Other, _Resolved, Acc) ->
    {Other, Acc}.

%% Report §5.6: a fill's namespace resolved whole, as one qualifier whose
%% last segment is the name; any other base is an expression.
rewritten_base(#e_constructor{written = Written, name = Name, span = Span, args = none,
                              base = undefined} = Fill, Resolved, Acc) ->
    case named(fill, Span, Written ++ [Name], [], Resolved, Acc) of
        {['Prelude' | _], Acc1} -> {Fill, Acc1};
        {Namespace, Acc1} -> {Fill#e_constructor{namespace = lists:droplast(Namespace)}, Acc1}
    end;
rewritten_base(Base, Resolved, Acc) ->
    rewritten(Base, Resolved, Acc).

%% The namespace Written resolves to, beside an error where Written is
%% longer than its shortest form, Name the segment after it that the
%% source writes, none for a fill's namespace. Kind is what the name
%% names: a value, a type or a constructor, or a fill's namespace.
named(_Kind, _Span, [], _Name, _Resolved, Acc) ->
    {[], Acc};
named(_Kind, _Span, ['Prelude' | _] = Written, _Name, _Resolved, Acc) ->
    {Written, Acc};
named(type, Span, Written, Name, {OwnNamespace, Qualifiers}, Acc) ->
    case maps:get(Written, Qualifiers) of
        {OwnNamespace, _} ->
            {OwnNamespace, [written_plain(Span, Written, OwnNamespace, Name) | Acc]};
        Found -> held_to_shortest(Span, Written, Name, Found, Acc)
    end;
named(_Kind, Span, Written, Name, {_OwnNamespace, Qualifiers}, Acc) ->
    held_to_shortest(Span, Written, Name, maps:get(Written, Qualifiers), Acc).

%% The namespace Written resolves to, held to its shortest form where it
%% has one (held/4): an error beside it where Written is longer.
held_to_shortest(Span, Written, Name, {Namespace, [_ | _] = Shortest}, Acc)
  when length(Shortest) < length(Written) ->
    {Namespace, [too_long(Span, Written ++ Name, Namespace ++ Name, Shortest ++ Name) | Acc]};
held_to_shortest(_Span, _Written, _Name, {Namespace, _}, Acc) ->
    {Namespace, Acc}.

%% Report §4.2: a module's own type or constructor, which no binding can
%% hide, is written by its plain name, a case of the shortest resolving
%% form; the message names it whole.
written_plain(Span, Written, OwnNamespace, Plain) ->
    PlainText = ern_namespace:text(Plain),
    #diagnostic{span = name_span(Span, Written ++ Plain),
                message = ern_namespace:text(OwnNamespace ++ Plain) ++ " is the module's own "
                          ++ PlainText ++ ", which no binding hides",
                help = "write `" ++ PlainText ++ "`"}.

%% Report §11.5: a name written longer than its shortest resolving form,
%% reported at the name as written, Written, which the message names whole,
%% with a help line that writes the short one.
-spec too_long(ern_diagnostic:position() | ern_diagnostic:span(), [atom()], [atom()],
               [atom()]) -> ern_diagnostic:diagnostic().
too_long(Span, Written, Whole, Short) ->
    #diagnostic{span = name_span(Span, Written),
                message = ern_namespace:text(Whole)
                          ++ " is written longer than its shortest resolving form",
                help = "write `" ++ ern_namespace:text(Short) ++ "`"}.

%% Report §4.2, §11.5: Diagnostic, a qualified name unknown in the namespace
%% its qualifier resolved to, with a help naming the module that hides one
%% at the root: where the qualifier's first segment was found nearer than
%% the root, and AtRoot says a module of that segment stands there, out of
%% reach from OwnNamespace. Resolved holds each qualifier the source writes
%% with the namespace it resolved to; a name whose first segment was found
%% at the root asks nothing more.
-spec out_of_reach(ern_diagnostic:diagnostic(), [atom()], [{[atom()], [atom()]}],
                   fun((atom()) -> boolean())) -> ern_diagnostic:diagnostic().
out_of_reach(#diagnostic{unknown_namespace = [_ | _] = Namespace, help = undefined} = Diagnostic,
             OwnNamespace, Resolved, AtRoot) ->
    %% the shortest qualifier of the namespace, since a longer is an error
    %% of its own
    case lists:sort([{length(Written), Written} || {Written, Found} <- Resolved,
                                                   Found =:= Namespace]) of
        [{Length, [First | _]} | _] when Length < length(Namespace) ->
            Hiding = lists:sublist(Namespace, length(Namespace) - Length + 1),
            case AtRoot(First) of
                true ->
                    Segment = atom_to_list(First),
                    Diagnostic#diagnostic{help = "`" ++ Segment ++ "` here is `"
                                                 ++ ern_namespace:text(Hiding) ++ "`; the root's `"
                                                 ++ Segment ++ "` is out of reach from `"
                                                 ++ ern_namespace:text(OwnNamespace) ++ "`"};
                false ->
                    Diagnostic
            end;
        _ ->
            Diagnostic
    end;
out_of_reach(Diagnostic, _OwnNamespace, _Resolved, _AtRoot) ->
    Diagnostic.

%% The span of a name as the source writes it, Written, from where its
%% node begins (report §11.5).
-spec name_span(ern_diagnostic:position() | ern_diagnostic:span(), [atom()]) ->
          ern_diagnostic:span().
name_span(Span, Written) ->
    {Line, Column, _} = ern_diagnostic:span(Span),
    {Line, Column, {Line, Column + length(ern_namespace:text(Written))}}.
