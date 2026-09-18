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

-export([check/3, check_string/2, prelude_env/0]).
-export([is_reply_carrying/2, resolve_type/2, lookup_type/2, lookup_con/4, type_state/1,
         set_type_state/2, node_type/1]).

-export_type([env/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-record(env, {ns = [], types = #{}, cons = #{}, globals = #{},
              local_types = #{}, local_cons = #{}, local_values = #{},
              vars = #{}, effect = pure, st, pending = [], deferred = [],
              ann_vars = #{}, rigid = []}).
-opaque env() :: #env{}.

-type error() :: ern_diag:diag().

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
-define(CONTAINERS, [['List'], ['Map'], ['Set'], ['Optional'], ['Either']]).

%%
%% Entry points
%%

%% On success: the typed declarations, the module's interface, and the
%% environment, which the compiler needs for the layouts of private types.
-spec check([atom()], [tuple()], [#iface{}]) ->
          {ok, [tuple()], #iface{}, env()} | {error, [error()]}.
check(Ns, Decls, Ifaces) ->
    Env0 = lists:foldl(fun add_iface/2, (prelude_env())#env{ns = Ns}, Ifaces),
    try
        {Env1a, Errs1} = declare_types(Decls, Env0),
        %% report §11.5: the module's types print unqualified, except those
        %% that shadow a prelude name
        Shadows = [N || N <- maps:keys(Env1a#env.local_types), is_map_key([N], Env1a#env.types)],
        Env1 = Env1a#env{st = ern_types:set_scope(Env1a#env.st, Ns, Shadows)},
        {Typed, Env2, Errs2} = check_values(Decls, Env1),
        Errs3 = check_signatures(Decls, Env2),
        case lists:sort(Errs1 ++ Errs2 ++ Errs3) of
            [] -> {ok, Typed, make_iface(Decls, Env2), Env2};
            Errs -> {error, Errs}
        end
    catch
        throw:{type_error, Pos, Msg} -> {error, [diag(Pos, Msg)]}
    end.

-spec check_string([atom()], unicode:chardata()) ->
          {ok, [tuple()], #iface{}, env()} | {error, [error()]}.
check_string(Ns, Text) ->
    case ern_parser:parse_string(Text) of
        {ok, Decls} -> check(Ns, Decls, []);
        {error, E} -> {error, [E]}
    end.

diag(Pos, Message) -> #diag{span = ern_diag:span(Pos), message = Message}.

-spec type_state(env()) -> ern_types:st().
type_state(#env{st = St}) -> St.

-spec set_type_state(ern_types:st(), env()) -> env().
set_type_state(St, Env) -> Env#env{st = St}.

%%
%% The prelude
%%

-spec prelude_env() -> env().
prelude_env() ->
    Env0 = #env{st = ern_types:new()},
    Env1 = lists:foldl(fun({Name, Arity}, E) ->
                           Params = lists:seq(1, Arity),
                           add_type(E, #tinfo{qname = [Name], params = Params, foreign = true})
                       end, Env0, ern_prelude:builtin_types()),
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    {Env2, []} = declare_types(Decls, Env1),
    Env3 = lists:foldl(fun({Ns, Source}, E) ->
                           {ok, Ds} = ern_parser:parse_string(Source),
                           {E1, []} = declare_types(Ds, E#env{ns = Ns, local_types = #{},
                                                              local_cons = #{}}),
                           E1
                       end, Env2, ern_prelude:stdlib_types()),
    lists:foldl(fun({QName, Text}, E) ->
                    {ok, Syntax} = ern_parser:parse_type(Text),
                    ProcessOnly = lists:member(QName, ern_prelude:process_only()),
                    {Scheme, E1} = signature_scheme(Syntax, ProcessOnly,
                                                    ern_prelude:eq_vars(QName), E),
                    E1#env{globals = maps:put(QName, Scheme, E1#env.globals)}
                end, Env3#env{ns = [], local_types = #{}, local_cons = #{}, local_values = #{}},
                ern_prelude:values()).

add_iface(#iface{types = Ts, values = Vs}, #env{types = ET, globals = EG} = Env) ->
    Cons = maps:fold(fun(_, #tinfo{constructors = Cs}, Acc) ->
                         lists:foldl(fun(#cinfo{qname = Q} = C, A) -> A#{Q => C} end, Acc, Cs)
                     end, Env#env.cons, Ts),
    Env#env{types = maps:merge(ET, Ts), globals = maps:merge(EG, Vs), cons = Cons}.

add_type(#env{types = Ts, cons = Cs} = Env, #tinfo{qname = Q, constructors = Cons} = TI) ->
    Cs1 = lists:foldl(fun(#cinfo{qname = CQ} = C, A) -> A#{CQ => C} end, Cs, Cons),
    Env#env{types = Ts#{Q => TI}, cons = Cs1}.

%% A signature from the prelude tables: every annotation variable is
%% generalized; effect variables of the process primitives are process-only.
signature_scheme(Syntax, ProcessOnly, EqVars, Env) ->
    St0 = ern_types:enter(Env#env.st),
    {T, VarMap, St1} = ann(Syntax, #{}, Env#env{st = St0}),
    Z = ern_types:zonk(T, St1),
    Effs = ern_types:effect_vars(Z),
    Vals = ern_types:value_vars(Z),
    St2a = lists:foldl(fun(Id, S) -> ern_types:add_flag({tvar, Id}, process_only, S) end, St1,
                       [Id || Id <- Effs, ProcessOnly orelse lists:member(Id, Vals)]),
    St2 = lists:foldl(fun(Name, S) ->
                          case VarMap of
                              #{Name := V} -> ern_types:add_flag(V, eq, S);
                              _ -> S
                          end
                      end, St2a, EqVars),
    St3 = ern_types:leave(St2),
    {Scheme, St4} = ern_types:generalize(Z, [Id || {tvar, Id} <- maps:values(VarMap)], St3),
    {Scheme, Env#env{st = St4}}.

%%
%% Annotations: syntactic types to semantic types. VarMap maps annotation
%% variable names to type variables shared across one signature.
%%

ann(undefined, VarMap, Env) ->
    {pure, VarMap, Env#env.st};
ann(#t_var{name = Name}, VarMap, Env) ->
    case VarMap of
        #{Name := V} -> {V, VarMap, Env#env.st};
        _ ->
            {V, St} = ern_types:fresh_named(Name, Env#env.st),
            {V, VarMap#{Name => V}, St}
    end;
ann(#t_con{pos = Pos, path = Path, name = Name, args = Args}, VarMap, Env) ->
    {QName, Arity} = lookup_type_name(Pos, Path, Name, Env),
    length(Args) =:= Arity orelse
        fail(Pos, io_lib:format("~s takes ~B type argument~s, not ~B",
                                [format_qname(QName), Arity, plural(Arity), length(Args)])),
    {ArgTs, VarMap1, St} = ann_list(Args, VarMap, Env),
    {{tcon, QName, ArgTs}, VarMap1, St};
ann(#t_tuple{elems = Es}, VarMap, Env) ->
    {Ts, VarMap1, St} = ann_list(Es, VarMap, Env),
    {{ttuple, Ts}, VarMap1, St};
ann(#t_fn{params = Ps, ret = R, effect = E}, VarMap, Env) ->
    {PTs, VarMap1, St1} = ann_list(Ps, VarMap, Env),
    {RT, VarMap2, St2} = ann(R, VarMap1, Env#env{st = St1}),
    {ET, VarMap3, St3} = ann(E, VarMap2, Env#env{st = St2}),
    {{tfn, PTs, ET, RT}, VarMap3, St3}.

ann_list(Syntaxes, VarMap, Env) ->
    lists:foldl(fun(S, {Acc, VM, St}) ->
                    {T, VM1, St1} = ann(S, VM, Env#env{st = St}),
                    {Acc ++ [T], VM1, St1}
                end, {[], VarMap, Env#env.st}, Syntaxes).

lookup_type_name(Pos, [], Name, #env{local_types = LT, types = Ts}) ->
    case LT of
        #{Name := Q} -> {Q, length((maps:get(Q, Ts))#tinfo.params)};
        _ ->
            case Ts of
                #{[Name] := #tinfo{params = Ps}} -> {[Name], length(Ps)};
                _ -> fail(Pos, "unknown type " ++ atom_to_list(Name))
            end
    end;
lookup_type_name(Pos, Path, Name, #env{types = Ts}) ->
    Q = Path ++ [Name],
    case Ts of
        #{Q := #tinfo{params = Ps}} -> {Q, length(Ps)};
        _ -> fail(Pos, "unknown type " ++ format_qname(Q))
    end.

-spec lookup_type([atom()], env()) -> #tinfo{} | undefined.
lookup_type(QName, #env{types = Ts}) -> maps:get(QName, Ts, undefined).

%%
%% Type declarations
%%

declare_types(Decls, Env0) ->
    TypeDecls = [TD || D <- Decls, TD <- type_decl_of(D)],
    %% pass one: names and arities, so recursive references resolve
    Env1 = lists:foldl(fun(#type_decl{pos = Pos, name = Name, params = Params}, Env) ->
                           check_unique_type(Pos, Name, Env),
                           Q = Env#env.ns ++ [Name],
                           Env2 = add_type(Env, #tinfo{qname = Q, params = Params}),
                           Env2#env{local_types = maps:put(Name, Q, Env2#env.local_types)}
                       end, Env0, TypeDecls),
    Env2 = lists:foldl(fun(#foreign_type_decl{pos = Pos, name = Name, params = Params}, Env) ->
                           check_unique_type(Pos, Name, Env),
                           Q = Env#env.ns ++ [Name],
                           Env3 = add_type(Env, #tinfo{qname = Q, params = Params,
                                                       foreign = true}),
                           Env3#env{local_types = maps:put(Name, Q, Env3#env.local_types)}
                       end, Env1, [D || #foreign_type_decl{} = D <- Decls]),
    %% pass two: constructors
    {Env3, Errs} = lists:foldl(fun(TD, {Env, Errs}) ->
                                   try
                                       {declare_constructors(TD, Env), Errs}
                                   catch
                                       throw:{type_error, Pos, Msg} ->
                                           {Env, [diag(Pos, Msg) | Errs]}
                                   end
                               end, {Env2, []}, TypeDecls),
    {mark_reply_carrying(Env3), Errs}.

type_decl_of(#type_decl{} = TD) -> [TD];
type_decl_of(#abstract_decl{type = TD}) -> [TD];
type_decl_of(_) -> [].

check_unique_type(Pos, Name, #env{local_types = LT}) ->
    case LT of
        #{Name := _} -> fail(Pos, "type " ++ atom_to_list(Name) ++ " is declared twice");
        _ -> ok
    end.

declare_constructors(#type_decl{name = Name, params = Params, constructors = Cons}, Env) ->
    Q = maps:get(Name, Env#env.local_types),
    %% one type variable per parameter, shared by all constructors
    {VarMap, St1} = lists:foldl(fun(P, {M, S}) ->
                                    {V, S1} = ern_types:fresh(S),
                                    {M#{P => V}, S1}
                                end, {#{}, ern_types:enter(Env#env.st)}, Params),
    ParamVars = [maps:get(P, VarMap) || P <- Params],
    Result = {tcon, Q, ParamVars},
    Quant = [{Id, []} || {tvar, Id} <- ParamVars],
    Env1 = Env#env{st = St1},
    {CInfos, Env2} =
        lists:mapfoldl(
          fun(#constructor{pos = Pos, name = CName, fields = Fields}, E) ->
                  check_unique_con(Pos, CName, E),
                  CQ = E#env.ns ++ [CName],
                  {FieldSpec, FieldTypes, E1} = constructor_fields(Fields, VarMap, E),
                  T = case FieldSpec of
                          none -> Result;
                          _ -> {tfn, FieldTypes, pure, Result}
                      end,
                  CI = #cinfo{name = CName, qname = CQ, type_qname = Q, fields = FieldSpec,
                              tag_arity = length(FieldTypes),
                              scheme = #scheme{vars = Quant, type = T}},
                  {CI, E1#env{local_cons = maps:put(CName, CQ, E1#env.local_cons),
                              cons = maps:put(CQ, CI, E1#env.cons)}}
          end, Env1, Cons),
    TI = (maps:get(Q, Env2#env.types))#tinfo{params = ParamVars, constructors = CInfos},
    Env3 = Env2#env{st = ern_types:leave(Env2#env.st)},
    Env3#env{types = maps:put(Q, TI, Env3#env.types)}.

check_unique_con(Pos, Name, #env{local_cons = LC}) ->
    case LC of
        #{Name := _} -> fail(Pos, "constructor " ++ atom_to_list(Name) ++ " is declared twice");
        _ -> ok
    end.

%% Field types; annotation variables must be parameters (report §3.9).
constructor_fields(none, _VarMap, Env) ->
    {none, [], Env};
constructor_fields({positional, Syntax}, VarMap, Env) ->
    {T, Env1} = field_type(Syntax, VarMap, Env),
    {positional, [T], Env1};
constructor_fields({named, Fields}, VarMap, Env) ->
    Sorted = lists:sort(fun(#field{name = A}, #field{name = B}) -> A =< B end, Fields),
    Names = [N || #field{name = N} <- Sorted],
    length(lists:usort(Names)) =:= length(Names) orelse
        fail((hd(Sorted))#field.pos, "field names must be unique within a constructor"),
    {Types, Env1} = lists:mapfoldl(fun(#field{type = S}, E) -> field_type(S, VarMap, E) end,
                                   Env, Sorted),
    {{named, Names}, Types, Env1}.

field_type(Syntax, VarMap, Env) ->
    {T, VarMap1, St} = ann(Syntax, VarMap, Env),
    case maps:keys(VarMap1) -- maps:keys(VarMap) of
        [] -> {T, Env#env{st = St}};
        [Extra | _] -> fail(syntax_pos(Syntax), "type variable " ++ atom_to_list(Extra)
                                                ++ " is not a parameter of the type")
    end.

syntax_pos(T) -> element(2, T).

%% Fixpoint over the module's types (report §6.6).
mark_reply_carrying(#env{types = Ts} = Env) ->
    Marked = reply_fixpoint(Ts, Env),
    Env#env{types = Marked}.

reply_fixpoint(Ts, Env) ->
    Ts1 = maps:map(fun(_, #tinfo{constructors = Cs, reply_carrying = false} = TI) ->
                           Carry = lists:any(fun(#cinfo{scheme = #scheme{type = T}}) ->
                                                 field_types_reply(T, Ts, Env)
                                             end, Cs),
                           TI#tinfo{reply_carrying = Carry};
                      (_, TI) -> TI
                   end, Ts),
    case Ts1 =:= Ts of
        true -> Ts;
        false -> reply_fixpoint(Ts1, Env)
    end.

field_types_reply({tfn, Fields, pure, _}, Ts, Env) ->
    lists:any(fun(F) -> reply_in(F, Ts, Env) end, Fields);
field_types_reply(_, _, _) ->
    false.

reply_in(T, Ts, Env) ->
    case ern_types:resolve(T, Env#env.st) of
        {tcon, ['Reply'], _} -> true;
        {tcon, Q, Args} ->
            case Ts of
                #{Q := #tinfo{foreign = true}} -> false;
                #{Q := #tinfo{reply_carrying = true}} -> true;
                _ -> lists:any(fun(A) -> reply_in(A, Ts, Env) end, Args)
            end;
        {ttuple, Es} -> lists:any(fun(E) -> reply_in(E, Ts, Env) end, Es);
        _ -> false
    end.

-spec is_reply_carrying(ern_types:type(), env()) -> boolean().
is_reply_carrying(T, #env{types = Ts} = Env) -> reply_in(T, Ts, Env).

%%
%% Values: fn, let, foreign fn, in dependency order
%%

check_values(Decls, Env0) ->
    Values = [D || D <- Decls, is_value_decl(D)],
    %% names first, so every body can see every other
    Env1 = lists:foldl(fun(D, Env) -> register_value_name(D, Env) end, Env0, Values),
    Groups = dependency_groups(Values, Env1),
    {TypedGroups, Env2, Errs} =
        lists:foldl(fun(Group, {Acc, Env, Errs}) ->
                        try
                            {Typed, Env3} = check_group(Group, Env),
                            {Acc ++ Typed, Env3, Errs}
                        catch
                            throw:{type_error, Pos, Msg} ->
                                {Acc ++ Group, placeholder_group(Group, Env),
                                 [diag(Pos, Msg) | Errs]}
                        end
                    end, {[], Env1, []}, Groups),
    %% restore declaration order for the typed output
    Typed = [replace_typed(D, TypedGroups) || D <- Decls],
    {Typed, Env2, Errs}.

is_value_decl(#fn_decl{}) -> true;
is_value_decl(#let_decl{}) -> true;
is_value_decl(#foreign_fn_decl{}) -> true;
is_value_decl(_) -> false.

replace_typed(D, Typed) ->
    Key = decl_key(D),
    case [T || T <- Typed, decl_key(T) =:= Key] of
        [T | _] -> T;
        [] -> D
    end.

decl_key(#fn_decl{owner = O, name = N}) -> {O, N};
decl_key(#let_decl{owner = O, name = N}) -> {O, N};
decl_key(#foreign_fn_decl{owner = O, name = N}) -> {O, N};
decl_key(D) -> {other, element(2, D)}.

value_qname(#env{ns = Ns}, undefined, Name) -> Ns ++ [Name];
value_qname(#env{ns = Ns}, Owner, Name) -> Ns ++ [Owner, Name].

register_value_name(D, #env{local_values = LV} = Env) ->
    {Owner, Name} = decl_key(D),
    Pos = element(2, D),
    Key = local_key(Owner, Name),
    case LV of
        #{Key := _} -> fail(Pos, "value " ++ local_name(Owner, Name) ++ " is declared twice");
        _ -> ok
    end,
    Owner =:= undefined orelse maps:is_key(Owner, Env#env.local_types) orelse
        fail(Pos, atom_to_list(Owner) ++ " is not a type declared in this module"),
    Env#env{local_values = LV#{Key => value_qname(Env, Owner, Name)}}.

local_key(undefined, Name) -> Name;
local_key(Owner, Name) -> {Owner, Name}.

local_name(undefined, Name) -> atom_to_list(Name);
local_name(Owner, Name) -> atom_to_list(Owner) ++ "." ++ atom_to_list(Name).

%% Strongly connected components of the reference graph, in dependency order.
dependency_groups(Values, Env) ->
    G = digraph:new(),
    Keys = [decl_key(D) || D <- Values],
    lists:foreach(fun(K) -> digraph:add_vertex(G, K) end, Keys),
    lists:foreach(fun(D) ->
                      K = decl_key(D),
                      lists:foreach(fun(Ref) ->
                                        case lists:member(Ref, Keys) of
                                            true -> digraph:add_edge(G, K, Ref);
                                            false -> ok
                                        end
                                    end, references(D, Env))
                  end, Values),
    Components = digraph_utils:strong_components(G),
    C = digraph_utils:condensation(G),
    Order = digraph_utils:topsort(C),
    digraph:delete(G), digraph:delete(C),
    ByKey = maps:from_list([{decl_key(D), D} || D <- Values]),
    Ordered = lists:reverse([Comp || Comp <- Order, lists:member(Comp, Components)]),
    [[maps:get(K, ByKey) || K <- Comp] || Comp <- Ordered].

%% Local value keys a declaration's body refers to.
references(D, Env) ->
    Body = case D of
               #fn_decl{body = B} -> B;
               #let_decl{body = B} -> B;
               _ -> undefined
           end,
    lists:usort(refs(Body, Env, [])).

refs(#e_var{path = [], name = N}, _Env, Acc) -> [{undefined, N} | Acc];
refs(#e_var{path = [Owner], name = N}, #env{local_types = LT}, Acc) ->
    case maps:is_key(Owner, LT) of true -> [{Owner, N} | Acc]; false -> Acc end;
refs(T, Env, Acc) when is_tuple(T) ->
    lists:foldl(fun(X, A) -> refs(X, Env, A) end, Acc, tl(tuple_to_list(T)));
refs(L, Env, Acc) when is_list(L) ->
    lists:foldl(fun(X, A) -> refs(X, Env, A) end, Acc, L);
refs(_, _, Acc) -> Acc.

%% A group failed: give its names a fresh polymorphic type so that later
%% groups report their own errors rather than cascades.
placeholder_group(Group, Env) ->
    lists:foldl(fun(D, E) ->
                    {Owner, Name} = decl_key(D),
                    {V, St} = ern_types:fresh(ern_types:enter(E#env.st)),
                    {Scheme, St1} = ern_types:generalize(V, ern_types:leave(St)),
                    Q = value_qname(E, Owner, Name),
                    E#env{st = St1, globals = maps:put(Q, Scheme, E#env.globals)}
                end, Env, Group).

check_group(Group, Env0) ->
    let_cycle(Group, Env0),
    St0 = ern_types:enter(Env0#env.st),
    %% a monomorphic placeholder per member for recursion
    {Placeholders, St1} = lists:mapfoldl(fun(D, S) ->
                                             {V, S1} = ern_types:fresh(S),
                                             {{decl_key(D), V}, S1}
                                         end, St0, Group),
    Env1 = lists:foldl(fun({{Owner, Name}, V}, E) ->
                           Q = value_qname(E, Owner, Name),
                           E#env{globals = maps:put(Q, ern_types:mono(V), E#env.globals)}
                       end, Env0#env{st = St1}, Placeholders),
    %% annotated shapes first, so every member sees every other's signature
    Env1a = lists:foldl(fun(D, E) ->
                            V = proplists:get_value(decl_key(D), Placeholders),
                            signature_shape(D, V, E)
                        end, Env1, Group),
    {TypedAndPost, Env2} = lists:mapfoldl(fun(D, E) ->
                                              V = proplists:get_value(decl_key(D), Placeholders),
                                              {TD, Post, E1} = check_value(D, V, E),
                                              {{TD, Post}, E1}
                                          end, Env1a, Group),
    Typed = [TD || {TD, _} <- TypedAndPost],
    Env2a = lists:foldl(fun({_, Post}, E) -> post_checks(Post, E) end, Env2, TypedAndPost),
    Env3 = Env2a#env{st = ern_types:leave(Env2a#env.st)},
    %% generalize and publish; the typed AST is zonked so consumers read
    %% resolved types off the nodes
    {Typed2, Env4} = lists:mapfoldl(fun(D, E) ->
                                        {Owner, Name} = decl_key(D),
                                        V = proplists:get_value({Owner, Name}, Placeholders),
                                        {Scheme, St} = ern_types:generalize(V, E#env.st),
                                        Q = value_qname(E, Owner, Name),
                                        E1 = E#env{st = St,
                                                   globals = maps:put(Q, Scheme, E#env.globals)},
                                        {zonk_ast(set_decl_type(D, Scheme), St), E1}
                                    end, Env3, Typed),
    {Typed2, Env4}.

zonk_ast({Tag, _, _} = T, St) when Tag =:= tvar; Tag =:= tcon -> ern_types:zonk(T, St);
zonk_ast({tvar, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast({ttuple, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast({tfn, _, _, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast(T, St) when is_tuple(T) -> list_to_tuple([zonk_ast(X, St) || X <- tuple_to_list(T)]);
zonk_ast(L, St) when is_list(L) -> [zonk_ast(X, St) || X <- L];
zonk_ast(X, _) -> X.

%% Report §8.5: a cycle among top-level let initializers, directly or through
%% functions they call, is a compile-time error. A group is a strongly
%% connected component, so a let in a group of two or more, or one that
%% references itself, is on a cycle.
let_cycle(Group, Env) ->
    case lists:keysort(2, [D || #let_decl{} = D <- Group]) of
        [] -> ok;
        [#let_decl{pos = Pos, name = Name} = D | _] ->
            Others = [local_name(O, N) || {O, N} <- [decl_key(G) || G <- Group],
                                          {O, N} =/= decl_key(D)],
            Cyclic = Others =/= [] orelse lists:member(decl_key(D), references(D, Env)),
            Through = case Others of
                          [] -> "";
                          _ -> ", through " ++ lists:join(", ", Others)
                      end,
            Cyclic andalso fail(Pos, "the initializer of " ++ atom_to_list(Name)
                                     ++ " depends on itself" ++ Through),
            ok
    end.

%% Unify a placeholder with what the annotations say, before any body.
signature_shape(#fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect}, V, Env) ->
    {PTs, AnnVars, St1} = lists:foldl(fun(#param{type = undefined}, {Acc, AV, St}) ->
                                              {T, St0} = ern_types:fresh(St),
                                              {Acc ++ [T], AV, St0};
                                         (#param{type = Syntax}, {Acc, AV, St}) ->
                                              {T, AV1, St0} = ann(Syntax, AV, Env#env{st = St}),
                                              {Acc ++ [T], AV1, St0}
                                      end, {[], #{}, Env#env.st}, Params),
    {RetT, EffT, _, St2} = return_annotation(Ret, Effect, AnnVars, Env#env{st = St1}),
    FnT = {tfn, PTs, EffT, RetT},
    unify_at(Pos, V, FnT, Env#env{st = mark_process_only(FnT, St2)}, "signature");
signature_shape(#let_decl{pos = Pos, ann = Ann}, V, Env) when Ann =/= undefined ->
    {T, _, St} = ann(Ann, #{}, Env),
    unify_at(Pos, V, T, Env#env{st = St}, "signature");
signature_shape(#foreign_fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect}, V,
                Env) ->
    Syntax = #t_fn{pos = Pos, params = [T || #param{type = T} <- Params], ret = Ret,
                   effect = Effect},
    {T, _, St} = ann(Syntax, #{}, Env),
    unify_at(Pos, V, T, Env#env{st = foreign_effect(T, St)}, "foreign signature");
signature_shape(_, _, Env) ->
    Env.

set_decl_type(#fn_decl{} = D, S) -> D#fn_decl{type = S};
set_decl_type(#let_decl{} = D, S) -> D#let_decl{type = S};
set_decl_type(D, _) -> D.

check_value(#fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect, body = Body} = D,
            Placeholder, Env) ->
    {TypedParams, ParamTypes, Env1, AnnVars} = bind_params(Params, Env, #{}),
    {RetT, EffT, AnnVars1, St} = return_annotation(Ret, Effect, AnnVars, Env1),
    FnT = {tfn, ParamTypes, EffT, RetT},
    Env2 = Env1#env{st = mark_process_only(FnT, St), effect = EffT, pending = [], deferred = [],
                    ann_vars = AnnVars1, rigid = maps:to_list(AnnVars1)},
    {TypedBody, BodyT, Env3} = infer(Body, Env2),
    Env4 = unify_at(Pos, RetT, BodyT, Env3, "the body does not have the declared return type"),
    Env5 = unify_at(Pos, Placeholder, FnT, Env4, "recursive use does not match the definition"),
    Post = {Pos, TypedParams, TypedBody, FnT, Env5#env.rigid, Env5#env.pending,
            Env5#env.deferred},
    {D#fn_decl{params = TypedParams, body = TypedBody}, Post,
     Env5#env{vars = Env#env.vars, effect = Env#env.effect, pending = Env#env.pending,
              deferred = Env#env.deferred, ann_vars = Env#env.ann_vars, rigid = Env#env.rigid}};
check_value(#let_decl{pos = Pos, ann = Ann, body = Body} = D, Placeholder, Env) ->
    {AnnT, AnnVars, St} = case Ann of
                              undefined -> {undefined, #{}, Env#env.st};
                              _ -> {T, VM, S} = ann(Ann, #{}, Env), {T, VM, S}
                          end,
    %% a top-level initializer is pure (report §4.6)
    {TypedBody, BodyT, Env1} = infer(Body, Env#env{st = St, effect = pure, pending = [],
                                                deferred = [], ann_vars = AnnVars,
                                                rigid = maps:to_list(AnnVars)}),
    Env2 = case AnnT of
               undefined -> Env1;
               _ -> unify_at(Pos, AnnT, BodyT, Env1, "the value does not have the declared type")
           end,
    Env3 = unify_at(Pos, Placeholder, BodyT, Env2, "recursive use does not match the definition"),
    Post = {Pos, [], TypedBody, BodyT, Env3#env.rigid, Env3#env.pending, Env3#env.deferred},
    {D#let_decl{body = TypedBody}, Post,
     Env3#env{vars = Env#env.vars, effect = Env#env.effect, pending = Env#env.pending,
              deferred = Env#env.deferred, ann_vars = Env#env.ann_vars, rigid = Env#env.rigid}};
check_value(#foreign_fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect} = D,
            Placeholder, Env) ->
    Syntax = #t_fn{pos = Pos, params = [T || #param{type = T} <- Params], ret = Ret,
                   effect = Effect},
    {T, _, St} = ann(Syntax, #{}, Env),
    Env1 = unify_at(Pos, Placeholder, T, Env#env{st = foreign_effect(T, St)}, "foreign signature"),
    {D, none, Env1}.

%% A foreign fn declared `with m` is process-only (report §3.9).
foreign_effect({tfn, _, {tvar, _} = E, _}, St) -> ern_types:add_flag(E, process_only, St);
foreign_effect(_, St) -> St.

%% Parameters bind pattern variables monomorphically; annotation variables
%% are shared across the parameters and the return annotation.
bind_params(Params, Env, AnnVars) ->
    lists:foldl(fun(#param{pos = Pos, pattern = P, type = Ann} = Param, {Acc, Ts, E, AV}) ->
                    {TypedP, PT, Bindings, E1} = check_pattern(P, E),
                    irrefutable(P, E1) orelse
                        fail(Pos, "a parameter pattern must be irrefutable"),
                    {AV1, E2} = case Ann of
                                    undefined -> {AV, E1};
                                    _ ->
                                        {AT, AV0, St} = ann(Ann, AV, E1),
                                        {AV0, unify_at(Pos, AT, PT, E1#env{st = St},
                                                       "the parameter pattern does not fit its"
                                                       " annotation")}
                                end,
                    E3 = bind_vars(Bindings, E2),
                    {Acc ++ [Param#param{pattern = TypedP}], Ts ++ [PT], E3, AV1}
                end, {[], [], Env, AnnVars}, Params).

return_annotation(undefined, _Effect, AnnVars, Env) ->
    {RetT, St1} = ern_types:fresh(Env#env.st),
    {EffT, St2} = ern_types:fresh_effect(St1),
    {RetT, EffT, AnnVars, St2};
return_annotation(Ret, Effect, AnnVars, Env) ->
    {RetT, AnnVars1, St1} = ann(Ret, AnnVars, Env),
    {EffT, AnnVars2, St2} = ann(Effect, AnnVars1, Env#env{st = St1}),
    {RetT, EffT, AnnVars2, St2}.

%% An effect variable that also occurs in a value position of the same
%% signature is process-only (report §3.9).
mark_process_only(FnT, St) ->
    Z = ern_types:zonk(FnT, St),
    Both = [Id || Id <- ern_types:effect_vars(Z), lists:member(Id, ern_types:value_vars(Z))],
    lists:foldl(fun(Id, S) -> ern_types:add_flag({tvar, Id}, process_only, S) end, St, Both).

bind_vars(Bindings, #env{vars = Vs} = Env) ->
    Env#env{vars = lists:foldl(fun({Name, T}, M) -> M#{Name => ern_types:mono(T)} end, Vs,
                               Bindings)}.

%%
%% Post checks per definition
%%

post_checks(none, Env) ->
    Env;
post_checks({Pos, TypedParams, TypedBody, FnT, Rigid, Pending, Deferred}, Env0) ->
    Env = solve_deferred(Env0#env{deferred = Deferred}),
    Env1 = resolve_operators(TypedBody, Env),
    rigid_annotation_vars(Pos, Rigid, Env1),
    local_fn_order(TypedBody),
    undetermined_bindings(TypedBody, FnT, Env1),
    ern_exhaust:check(TypedBody, Env1),
    Env2 = ern_reply:check(TypedParams, TypedBody, Env1),
    no_reply_instantiations(Env2#env{pending = Pending}),
    Env2#env{pending = Env0#env.pending, deferred = Env0#env.deferred}.

%% Report §5.5: `let p <- e` is resolved from the type of e, or from the
%% block's type, once the definition is inferred. Solving one may resolve
%% another, so iterate to a fixpoint.
solve_deferred(#env{deferred = []} = Env) ->
    Env;
solve_deferred(#env{deferred = Deferred} = Env) ->
    {Left, Env1} = lists:foldl(fun(D, {Acc, E}) ->
                                   case solve_one(D, E) of
                                       {solved, E1} -> {Acc, E1};
                                       unsolved -> {[D | Acc], E}
                                   end
                               end, {[], Env#env{deferred = []}}, Deferred),
    case length(Left) < length(Deferred) of
        true -> solve_deferred(Env1#env{deferred = Left});
        false ->
            {bind_arrow, Pos, _, _, _} = hd(Left),
            fail(Pos, "`<-` needs to know whether the value is an Either or an Optional;"
                      " annotate it")
    end.

solve_one({bind_arrow, Pos, XT, PT, RestT}, Env) ->
    St = Env#env.st,
    case {ern_types:resolve(XT, St), ern_types:resolve(RestT, St)} of
        {{tcon, ['Either'], [Er, A]}, _} ->
            {solved, bind_arrow(Pos, either, Er, A, PT, RestT, Env)};
        {{tcon, ['Optional'], [A]}, _} ->
            {solved, bind_arrow(Pos, optional, none, A, PT, RestT, Env)};
        {{tvar, _}, {tcon, ['Either'], [Er, _]}} ->
            Env1 = unify_at(Pos, {tcon, ['Either'], [Er, PT]}, XT, Env, "`<-` on an Either"),
            {solved, bind_arrow(Pos, either, Er, PT, PT, RestT, Env1)};
        {{tvar, _}, {tcon, ['Optional'], [_]}} ->
            Env1 = unify_at(Pos, {tcon, ['Optional'], [PT]}, XT, Env, "`<-` on an Optional"),
            {solved, bind_arrow(Pos, optional, none, PT, PT, RestT, Env1)};
        {{tvar, _}, _} ->
            unsolved;
        {Other, _} ->
            fail(Pos, "`<-` needs an Either or an Optional, not " ++ ern_types:format(Other, St))
    end.

bind_arrow(Pos, Wrap, Er, A, PT, RestT, Env) ->
    Env1 = unify_at(Pos, PT, A, Env, "the pattern does not fit the value inside the sum type"),
    {RestVal, St} = ern_types:fresh(Env1#env.st),
    Expected = case Wrap of
                   either -> {tcon, ['Either'], [Er, RestVal]};
                   optional -> {tcon, ['Optional'], [RestVal]}
               end,
    unify_at(Pos, Expected, RestT, Env1#env{st = St},
             "after `let p <- e` the block must have the same sum type as e").

%% Restrictions checked at instantiation (report §3.9, §3.10): a no-reply
%% variable bound to a reply-carrying type, an equality-constrained one
%% bound to a type containing a function or an address.
no_reply_instantiations(#env{pending = Pending} = Env) ->
    lists:foreach(fun({no_reply, Id, Pos}) ->
                          T = ern_types:zonk({tvar, Id}, Env#env.st),
                          case is_reply_carrying(T, Env) of
                              true -> fail(Pos, "a reply-carrying value, "
                                                ++ ern_types:format(T, Env#env.st)
                                                ++ ", passed where the function duplicates"
                                                " or discards its argument");
                              false -> ok
                          end;
                     ({eq, Id, Pos}) ->
                          T = ern_types:zonk({tvar, Id}, Env#env.st),
                          case has_fn_or_address(T) of
                              true -> fail(Pos, ern_types:format(T, Env#env.st)
                                                ++ " does not support equality (it contains"
                                                " a function or an address), but it is"
                                                " compared here");
                              false -> ok
                          end
                  end, Pending).

%% Report §5.4: a local fn may be used only after every `let` of its block
%% that it references, directly or through other local fns, has been
%% evaluated. Uses are calls and value references alike.
local_fn_order(Node) ->
    walk(fun(#e_block{stmts = Stmts}, E) -> block_order(Stmts), E;
            (_, E) -> E
         end, Node, ok),
    ok.

block_order(Stmts) ->
    Fns = [D || #fn_decl{} = D <- Stmts],
    FnNames = [N || #fn_decl{name = N} <- Fns],
    Indexed = lists:zip(lists:seq(1, length(Stmts)), Stmts),
    %% every let binding of the block as an instance {Name, Index}
    Lets = lists:append([[{N, I} || {N, _} <- typed_pattern_bindings(P)]
                         || {I, #binding{pattern = P}} <- Indexed]),
    LetNames = lists:usort([N || {N, _} <- Lets]),
    %% what each local fn references: its siblings, and the binding of each
    %% let name in force at its declaration (report §5.4, §4.6)
    Direct = maps:from_list(
               [{N, [R || R <- free_refs(B, Params, LetNames ++ FnNames), lists:member(R, FnNames)]
                     ++ [{R, I} || R <- free_refs(B, Params, LetNames),
                                   I <- [in_force(R, D, Lets)], I =/= none]}
                || {D, #fn_decl{name = N, params = Params, body = B}} <- Indexed]),
    Needs = fun(N) -> needed_lets(N, Direct, [], []) end,
    lists:foldl(fun({I, #binding{pattern = P, expr = X}}, Bound) ->
                    check_uses(X, FnNames, Needs, Bound),
                    Bound ++ [{N, I} || {N, _} <- typed_pattern_bindings(P)];
                   ({_, #fn_decl{}}, Bound) ->
                    Bound;
                   ({_, X}, Bound) ->
                    check_uses(X, FnNames, Needs, Bound),
                    Bound
                end, [], Indexed).

%% The latest binding of Name before statement D, or none.
in_force(Name, D, Lets) ->
    case [I || {N, I} <- Lets, N =:= Name, I < D] of
        [] -> none;
        Is -> lists:max(Is)
    end.

%% The let instances a local fn needs, following references between local
%% fns.
needed_lets(N, Direct, Seen, Acc) ->
    case lists:member(N, Seen) of
        true -> Acc;
        false ->
            Refs = maps:get(N, Direct, []),
            Acc1 = lists:usort(Acc ++ [R || R <- Refs, is_tuple(R)]),
            lists:foldl(fun(R, A) when is_atom(R) -> needed_lets(R, Direct, [N | Seen], A);
                           (_, A) -> A
                        end, Acc1, Refs)
    end.

check_uses(Expr, FnNames, Needs, Bound) ->
    walk(fun(#e_var{pos = Pos, path = [], name = N}, E) ->
                 case lists:member(N, FnNames) of
                     true ->
                         case Needs(N) -- Bound of
                             [] -> E;
                             [{L, _} | _] -> fail(Pos, "local function " ++ atom_to_list(N)
                                                       ++ " is used before `let "
                                                       ++ atom_to_list(L)
                                                       ++ "`, which it references")
                         end;
                     false -> E
                 end;
            (_, E) -> E
         end, Expr, ok).

%% Unqualified names of the given set free in a local fn's body: outside
%% its parameters and the bindings inside the body.
free_refs(Body, Params, Names) ->
    Bound = lists:append([[N || {N, _} <- typed_pattern_bindings(P)]
                          || #param{pattern = P} <- Params]),
    lists:usort([N || N <- free_in(Body, Bound), lists:member(N, Names)]).

free_in(#e_var{path = [], name = N}, Bound) ->
    case lists:member(N, Bound) of true -> []; false -> [N] end;
free_in(#e_lambda{params = Ps, body = B}, Bound) ->
    free_in(B, Bound ++ lists:append([[N || {N, _} <- typed_pattern_bindings(P)]
                                      || #param{pattern = P} <- Ps]));
free_in(#e_block{stmts = Stmts}, Bound) ->
    {_, Acc} = lists:foldl(
                 fun(#binding{pattern = P, expr = X}, {Bd, A}) ->
                         {Bd ++ [N || {N, _} <- typed_pattern_bindings(P)], A ++ free_in(X, Bd)};
                    (#fn_decl{name = N, params = Ps, body = B}, {Bd, A}) ->
                         ParamNames = [[V || {V, _} <- typed_pattern_bindings(P)]
                                       || #param{pattern = P} <- Ps],
                         Inner = Bd ++ [N] ++ lists:append(ParamNames),
                         {Bd ++ [N], A ++ free_in(B, Inner)};
                    (S, {Bd, A}) -> {Bd, A ++ free_in(S, Bd)}
                 end, {Bound, []}, Stmts),
    Acc;
free_in(#clause{pattern = P, guard = G, body = B}, Bound) ->
    Bd = Bound ++ [N || {N, _} <- typed_pattern_bindings(P)],
    free_in(G, Bd) ++ free_in(B, Bd);
free_in(T, Bound) when is_tuple(T) ->
    lists:append([free_in(X, Bound) || X <- tl(tuple_to_list(T))]);
free_in(L, Bound) when is_list(L) ->
    lists:append([free_in(X, Bound) || X <- L]);
free_in(_, _) ->
    [].

%% Report §4.8: arithmetic, <>, and ordering resolve on the operand type.
resolve_operators(Node, Env) ->
    walk(fun(#e_binop{pos = Pos, op = Op, left = L}, E) when is_atom(Op) ->
                 case lists:member(Op, ?ARITH ++ ['<>' | ?ORDER]) of
                     true -> check_operand(Pos, Op, node_type(L), E);
                     false -> E
                 end;
            (#e_neg{pos = Pos, expr = X}, E) ->
                 check_operand(Pos, '-', node_type(X), E);
            (_, E) -> E
         end, Node, Env).

check_operand(Pos, Op, T, Env) ->
    case ern_types:resolve(T, Env#env.st) of
        {tvar, _} ->
            fail(Pos, "the operand type of `" ++ atom_to_list(Op)
                      ++ "` is not determined; annotate it");
        {tcon, Q, _} ->
            Allowed = case lists:member(Op, ?ARITH) of
                          true -> [['Int']];
                          false when Op =:= '<>' -> [['String'], ['List'], ['Bytes']];
                          false -> [['Int'], ['Float'], ['String'], ['Char']]
                      end,
            case lists:member(Q, Allowed) of
                true -> Env;
                false when Q =:= ['Float'], Op =/= '<>' ->
                    fail(Pos, "Float arithmetic is not in MVP 1");
                false -> fail(Pos, "`" ++ atom_to_list(Op) ++ "` is not defined on "
                                   ++ ern_types:format(T, Env#env.st))
            end;
        Other ->
            fail(Pos, "`" ++ atom_to_list(Op) ++ "` is not defined on "
                      ++ ern_types:format(Other, Env#env.st))
    end.

%% Annotation variables scope over the definition and must stay distinct
%% and unbound: `fn id(x : a) -> a = 1` is an error.
rigid_annotation_vars(Pos, Rigid, #env{st = St}) ->
    Resolved = [{Name, ern_types:resolve(V, St)} || {Name, V} <- Rigid],
    lists:foreach(fun({_Name, {tvar, _}}) ->
                          ok;
                     ({Name, T}) ->
                          fail(Pos, "type variable " ++ atom_to_list(Name)
                                    ++ " in the annotation is used as "
                                    ++ ern_types:format(T, St))
                  end, Resolved),
    Ids = [Id || {_, {tvar, Id}} <- Resolved],
    length(lists:usort(Ids)) =:= length(Ids) orelse
        fail(Pos, "two type variables in the annotation are used as one type").

%% Report §4.6: a block binding whose type is still undetermined, that is,
%% has a free variable that does not reach the definition's own type.
undetermined_bindings(Node, FnT, #env{st = St} = Env) ->
    Escaping = ern_types:free_vars(FnT, St),
    walk(fun(#binding{pos = Pos, pattern = P}, E) ->
                 lists:foreach(fun({Name, T}) ->
                                   case ern_types:free_vars(T, St) -- Escaping of
                                       [] -> ok;
                                       _ -> fail(Pos, "the type of " ++ atom_to_list(Name)
                                                      ++ " is not determined ("
                                                      ++ ern_types:format(T, St)
                                                      ++ "); use it, or annotate it")
                                   end
                               end, typed_pattern_bindings(P)),
                 E;
            (_, E) -> E
         end, Node, Env),
    ok.

typed_pattern_bindings(#p_var{name = N, type = T}) -> [{N, T}];
typed_pattern_bindings(#p_as{name = N, type = T, pattern = P}) ->
    [{N, T} | typed_pattern_bindings(P)];
typed_pattern_bindings(#p_con{args = {positional, P}}) -> typed_pattern_bindings(P);
typed_pattern_bindings(#p_con{args = {named, Fs}}) ->
    lists:append([typed_pattern_bindings(P) || #field_pat{pattern = P} <- Fs]);
typed_pattern_bindings(#p_tuple{elems = Es}) ->
    lists:append([typed_pattern_bindings(E) || E <- Es]);
typed_pattern_bindings(#p_list{elems = Es}) -> lists:append([typed_pattern_bindings(E) || E <- Es]);
typed_pattern_bindings(#p_cons{head = H, tail = T}) ->
    typed_pattern_bindings(H) ++ typed_pattern_bindings(T);
typed_pattern_bindings(_) -> [].

%% Generic pre-order walk over the typed AST, threading Env.
walk(F, Node, Env) when is_tuple(Node), is_atom(element(1, Node)) ->
    Env1 = F(Node, Env),
    lists:foldl(fun(X, E) -> walk(F, X, E) end, Env1, tl(tuple_to_list(Node)));
walk(F, L, Env) when is_list(L) ->
    lists:foldl(fun(X, E) -> walk(F, X, E) end, Env, L);
walk(_, _, Env) ->
    Env.

%%
%% Expressions: infer(Expr, Env) -> {TypedExpr, Type, Env}
%%

infer(#e_lit{kind = Kind} = E, Env) ->
    T = case Kind of
            int -> ?INT; float -> ?FLOAT; char -> ?CHAR; string -> ?STRING; bool -> ?BOOL
        end,
    {E#e_lit{type = T}, T, Env};
infer(#e_var{pos = Pos, path = Path, name = Name} = E, Env) ->
    Scheme = lookup_value(Pos, Path, Name, Env),
    {T, St} = ern_types:instantiate(Scheme, Env#env.st),
    Pending = [{Flag, Id, Pos} || Id <- ern_types:free_vars(T, St),
                                  Flag <- ern_types:flags(Id, St),
                                  Flag =:= no_reply orelse Flag =:= eq],
    {E#e_var{type = T}, T, Env#env{st = St, pending = Pending ++ Env#env.pending}};
infer(#e_con{pos = Pos, path = Path, name = Name, args = Args} = E, Env) ->
    CI = lookup_con(Pos, Path, Name, Env),
    {CT, St} = ern_types:instantiate(CI#cinfo.scheme, Env#env.st),
    Env1 = Env#env{st = St},
    case {CI#cinfo.fields, Args} of
        {none, none} ->
            {E#e_con{type = CT}, CT, Env1};
        {none, _} ->
            fail(Pos, atom_to_list(Name) ++ " takes no fields");
        {positional, {positional, Arg}} ->
            {tfn, [FT], pure, RT} = CT,
            {TypedArg, AT, Env2} = infer(Arg, Env1),
            Env3 = unify_at(Pos, FT, AT, Env2, "the field of " ++ atom_to_list(Name)),
            {E#e_con{args = {positional, TypedArg}, type = RT}, RT, Env3};
        {positional, none} ->
            %% a single-positional constructor is a function value (§5.6)
            {E#e_con{type = CT}, CT, Env1};
        {positional, {named, _, _}} ->
            fail(Pos, atom_to_list(Name) ++ " has one positional field, not named fields");
        {{named, Names}, {named, Base, Sets}} ->
            {tfn, FTs, pure, RT} = CT,
            infer_named(E, Names, FTs, RT, Base, Sets, Env1);
        {{named, _}, _} ->
            fail(Pos, atom_to_list(Name) ++ " has named fields; write "
                      ++ atom_to_list(Name) ++ "(field = value, ...)")
    end;
infer(#e_tuple{pos = _, elems = Es} = E, Env) ->
    {TypedEs, Ts, Env1} = infer_list(Es, Env),
    T = {ttuple, Ts},
    {E#e_tuple{elems = TypedEs, type = T}, T, Env1};
infer(#e_list{pos = Pos, elems = Es} = E, Env) ->
    {ElemT, St} = ern_types:fresh(Env#env.st),
    {TypedEs, Env1} = lists:mapfoldl(fun(X, En) ->
                                         {TX, XT, En1} = infer(X, En),
                                         {TX, unify_at(Pos, ElemT, XT, En1,
                                                       "list elements must have one type")}
                                     end, Env#env{st = St}, Es),
    T = {tcon, ['List'], [ElemT]},
    {E#e_list{elems = TypedEs, type = T}, T, Env1};
infer(#e_bits{pos = Pos}, _Env) ->
    fail(Pos, "bitstrings are not in MVP 1");
infer(#e_block{pos = Pos, stmts = Stmts} = E, Env) ->
    {TypedStmts, T, Env1} = infer_block(Stmts, Pos, Env),
    {E#e_block{stmts = TypedStmts, type = T}, T, Env1#env{vars = Env#env.vars}};
infer(#e_call{pos = Pos, callee = Callee, args = Args} = E, Env) ->
    {TypedCallee, CalleeT, Env1} = infer(Callee, Env),
    {TypedArgs, ArgTs, Env2} = infer_list(Args, Env1),
    {RetT, St} = ern_types:fresh(Env2#env.st),
    Env3 = Env2#env{st = St},
    Env4 = case ern_types:resolve(CalleeT, St) of
               {tfn, Ps, _, _} when length(Ps) =/= length(ArgTs) ->
                   fail(Pos, io_lib:format("~s takes ~B argument~s, not ~B; a call supplies"
                                           " them all", [callee_name(Callee), length(Ps),
                                                         plural(length(Ps)), length(ArgTs)]));
               {tfn, _, Eff, _} ->
                   Env3a = unify_at(Pos, CalleeT, {tfn, ArgTs, Eff, RetT}, Env3,
                                    "the arguments do not fit " ++ callee_name(Callee)),
                   use_effect(Pos, Eff, Env3a);
               {tvar, _} ->
                   {Eff, St1} = ern_types:fresh_effect(St),
                   Env3a = unify_at(Pos, CalleeT, {tfn, ArgTs, Eff, RetT}, Env3#env{st = St1},
                                    "not a function"),
                   use_effect(Pos, Eff, Env3a);
               Other ->
                   fail(Pos, callee_name(Callee) ++ " is not a function; it has type "
                             ++ ern_types:format(Other, St))
           end,
    {E#e_call{callee = TypedCallee, args = TypedArgs, type = RetT}, RetT, Env4};
infer(#e_neg{expr = X} = E, Env) ->
    {TypedX, XT, Env1} = infer(X, Env),
    {E#e_neg{expr = TypedX, type = XT}, XT, Env1};
infer(#e_binop{pos = Pos, op = Op, left = L, right = R} = E, Env) ->
    {TypedL, LT, Env1} = infer(L, Env),
    {TypedR, RT, Env2} = infer(R, Env1),
    {T, Env3} = binop_type(Pos, Op, LT, RT, Env2),
    {E#e_binop{left = TypedL, right = TypedR, type = T}, T, Env3};
infer(#e_lambda{pos = Pos, params = Params, ret = Ret, effect = Effect, body = Body} = E,
      Env) ->
    {TypedParams, ParamTypes, Env1, AnnVars} = bind_params(Params, Env, Env#env.ann_vars),
    {RetT, EffT, AnnVars1, St} = return_annotation(Ret, Effect, AnnVars, Env1),
    T = {tfn, ParamTypes, EffT, RetT},
    %% the definition's annotation variables are in scope and rigid; a
    %% name new here is the lambda's own and not rigid (report §3.9)
    Env2 = Env1#env{st = mark_process_only(T, St), effect = EffT, ann_vars = AnnVars1},
    {TypedBody, BodyT, Env3} = infer(Body, Env2),
    Env4 = unify_at(Pos, RetT, BodyT, Env3, "the lambda body does not have the declared type"),
    {E#e_lambda{params = TypedParams, body = TypedBody, type = T}, T,
     Env4#env{vars = Env#env.vars, effect = Env#env.effect, ann_vars = Env#env.ann_vars}};
infer(#e_if{pos = Pos, condition = C, then_branch = Th, else_branch = El} = E, Env) ->
    {TypedC, CT, Env1} = infer(C, Env),
    Env2 = unify_at(Pos, ?BOOL, CT, Env1, "the condition of `if`"),
    {TypedTh, ThT, Env3} = infer(Th, Env2),
    {TypedEl, ElT, Env4} = infer(El, Env3),
    Env5 = unify_at(Pos, ThT, ElT, Env4, "the branches of `if` must have one type"),
    {E#e_if{condition = TypedC, then_branch = TypedTh, else_branch = TypedEl, type = ThT}, ThT,
     Env5};
infer(#e_match{pos = Pos, scrutinee = S, clauses = Clauses} = E, Env) ->
    {TypedS, ST, Env1} = infer(S, Env),
    {ResultT, St} = ern_types:fresh(Env1#env.st),
    {TypedClauses, Env2} = infer_clauses(Clauses, ST, ResultT, Pos, Env1#env{st = St}),
    {E#e_match{scrutinee = TypedS, clauses = TypedClauses, type = ResultT}, ResultT, Env2};
infer(#e_receive{pos = Pos, clauses = Clauses, 'after' = After} = E, Env) ->
    {MailboxT, Env1} = mailbox_type(Pos, Env),
    case Clauses =/= [] andalso ern_types:resolve(MailboxT, Env1#env.st) =:= ?NEVER of
        true -> fail(Pos, "a function with mailbox Never cannot receive; only an `after`"
                          " clause is allowed");
        false -> ok
    end,
    {ResultT, St} = ern_types:fresh(Env1#env.st),
    {TypedClauses, Env2} = infer_clauses(Clauses, MailboxT, ResultT, Pos, Env1#env{st = St}),
    {TypedAfter, Env3} =
        case After of
            undefined -> {undefined, Env2};
            #after_clause{pos = APos, timeout = Timeout, body = Body} = A ->
                {TypedTimeout, TT, En1} = infer(Timeout, Env2),
                En2 = unify_at(APos, ?INT, TT, En1, "the `after` time is in milliseconds"),
                {TypedBody, BT, En3} = infer(Body, En2),
                En4 = unify_at(APos, ResultT, BT, En3, "the `after` body must have the"
                                                       " clauses' type"),
                {A#after_clause{timeout = TypedTimeout, body = TypedBody}, En4}
        end,
    {E#e_receive{clauses = TypedClauses, 'after' = TypedAfter, type = ResultT}, ResultT, Env3}.

infer_list(Es, Env) ->
    {Typed, {Ts, Env1}} = lists:mapfoldl(fun(X, {Acc, En}) ->
                                             {TX, XT, En1} = infer(X, En),
                                             {TX, {Acc ++ [XT], En1}}
                                         end, {[], Env}, Es),
    {Typed, Ts, Env1}.

callee_name(#e_var{path = Path, name = Name}) -> format_qname(Path ++ [Name]);
callee_name(_) -> "the callee".

%% A callee's effect: pure constrains nothing; anything else is the
%% enclosing function's effect.
use_effect(Pos, Eff, Env) ->
    case ern_types:resolve(Eff, Env#env.st) of
        pure -> Env;
        _ -> unify_at(Pos, Env#env.effect, Eff, Env, "this call needs a process")
    end.

infer_named(#e_con{pos = Pos, name = Name} = E, Names, FTs, RT, Base, Sets, Env) ->
    SetNames = [N || #field_set{name = N} <- Sets],
    length(lists:usort(SetNames)) =:= length(SetNames) orelse
        fail(Pos, "a field is given twice"),
    lists:foreach(fun(N) ->
                      lists:member(N, Names) orelse
                          fail(Pos, atom_to_list(Name) ++ " has no field " ++ atom_to_list(N))
                  end, SetNames),
    {TypedBase, Env1} = case Base of
                            undefined ->
                                Missing = Names -- SetNames,
                                Missing =:= [] orelse
                                    fail(Pos, "missing field" ++ plural(length(Missing)) ++ " "
                                              ++ lists:join(", ", [atom_to_list(M)
                                                                   || M <- Missing])),
                                {undefined, Env};
                            _ ->
                                {TB, BT, En} = infer(Base, Env),
                                {TB, unify_at(Pos, RT, BT, En, "the base of `..` must have"
                                                              " the constructor's type")}
                        end,
    {TypedSets, Env2} =
        lists:mapfoldl(fun(#field_set{pos = SPos, name = N, expr = X} = S, En) ->
                           FT = lists:nth(index_of(N, Names), FTs),
                           {TX, XT, En1} = infer(X, En),
                           {S#field_set{expr = TX},
                            unify_at(SPos, FT, XT, En1, "field " ++ atom_to_list(N))}
                       end, Env1, Sets),
    {E#e_con{args = {named, TypedBase, TypedSets}, type = RT}, RT, Env2}.

index_of(X, L) -> index_of(X, L, 1).
index_of(X, [X | _], I) -> I;
index_of(X, [_ | R], I) -> index_of(X, R, I + 1).

binop_type(Pos, Op, LT, RT, Env) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/';
                                      Op =:= '%'; Op =:= '<>' ->
    Env1 = unify_at(Pos, LT, RT, Env, "both operands of `" ++ atom_to_list(Op)
                                      ++ "` must have the same type"),
    {LT, Env1};
binop_type(Pos, Op, LT, RT, Env) when Op =:= '=='; Op =:= '!=' ->
    Env1 = unify_at(Pos, LT, RT, Env, "both operands of `" ++ atom_to_list(Op)
                                      ++ "` must have the same type"),
    Env2 = equality_constraint(Pos, LT, Env1),
    {?BOOL, Env2};
binop_type(Pos, Op, LT, RT, Env) when Op =:= '<'; Op =:= '<='; Op =:= '>'; Op =:= '>=' ->
    Env1 = unify_at(Pos, LT, RT, Env, "both operands of `" ++ atom_to_list(Op)
                                      ++ "` must have the same type"),
    {?BOOL, Env1};
binop_type(Pos, Op, LT, RT, Env) when Op =:= '&&'; Op =:= '||' ->
    Env1 = unify_at(Pos, ?BOOL, LT, Env, "the left operand of `" ++ atom_to_list(Op) ++ "`"),
    Env2 = unify_at(Pos, ?BOOL, RT, Env1, "the right operand of `" ++ atom_to_list(Op) ++ "`"),
    {?BOOL, Env2};
binop_type(Pos, '::', LT, RT, Env) ->
    ListT = {tcon, ['List'], [LT]},
    Env1 = unify_at(Pos, ListT, RT, Env, "the right operand of `::` must be a list of the"
                                        " left operand's type"),
    {ListT, Env1}.

%% Report §3.10: == on a type variable records the constraint; on a
%% concrete type containing a function or address it is an error now.
equality_constraint(Pos, T, Env) ->
    St = Env#env.st,
    Z = ern_types:zonk(T, St),
    case has_fn_or_address(Z) of
        true -> fail(Pos, "`==` is not defined on " ++ ern_types:format(Z, St)
                          ++ ": it contains a function or an address");
        false ->
            St1 = lists:foldl(fun(Id, S) -> ern_types:add_flag({tvar, Id}, eq, S) end,
                              St, ern_types:free_vars(Z, St)),
            Env#env{st = St1}
    end.

has_fn_or_address({tfn, _, _, _}) -> true;
has_fn_or_address({tcon, ['Address'], _}) -> true;
has_fn_or_address({tcon, ['Reply'], _}) -> true;
has_fn_or_address({tcon, _, Args}) -> lists:any(fun has_fn_or_address/1, Args);
has_fn_or_address({ttuple, Es}) -> lists:any(fun has_fn_or_address/1, Es);
has_fn_or_address(_) -> false.

%% The enclosing function's effect must be a mailbox type here.
mailbox_type(Pos, Env) ->
    case ern_types:resolve(Env#env.effect, Env#env.st) of
        pure -> fail(Pos, "`receive` in a pure function; give it a mailbox type with `with`");
        {tvar, _} = V ->
            {M, St} = ern_types:fresh(Env#env.st, [process_only]),
            Env1 = unify_at(Pos, V, M, Env#env{st = St}, "receive"),
            {M, Env1};
        T ->
            {T, Env}
    end.

infer_clauses(Clauses, ScrutT, ResultT, _Pos, Env) ->
    lists:mapfoldl(
      fun(#clause{pos = CPos, pattern = P, guard = G, body = B} = C, En) ->
              {TypedP, PT, Bindings, En1} = check_pattern(P, En),
              En2 = unify_at(CPos, ScrutT, PT, En1, "the pattern does not fit the value"),
              En3 = bind_vars(Bindings, En2),
              {TypedG, En4} = case G of
                                  undefined -> {undefined, En3};
                                  _ ->
                                      %% a guard is pure (report §5.9)
                                      {TG, GT, En3a} = infer(G, En3#env{effect = pure}),
                                      En3b = unify_at(CPos, ?BOOL, GT, En3a,
                                                      "a guard is a Bool"),
                                      {TG, En3b#env{effect = En3#env.effect}}
                              end,
              {TypedB, BT, En5} = infer(B, En4),
              En6 = unify_at(CPos, ResultT, BT, En5, "the clauses must have one type"),
              {C#clause{pattern = TypedP, guard = TypedG, body = TypedB},
               En6#env{vars = En#env.vars}}
      end, Env, Clauses).

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
infer_block(Stmts, Pos, Env) ->
    Fns = [S || #fn_decl{} = S <- Stmts],
    FnNames = [N || #fn_decl{name = N} <- Fns],
    St0 = ern_types:enter(Env#env.st),
    {Placeholders, St1} = lists:mapfoldl(fun(#fn_decl{name = N}, S) ->
                                             {V, S1} = ern_types:fresh(S),
                                             {{N, V}, S1}
                                         end, St0, Fns),
    Env1 = lists:foldl(fun({N, V}, E) ->
                           E#env{vars = maps:put(N, ern_types:mono(V), E#env.vars)}
                       end, Env#env{st = St1}, Placeholders),
    %% the annotations shape the placeholder before any use, as at top
    %% level, at the block's level so that the fn still generalizes
    Env1s = lists:foldl(fun({D, {_, V}}, E) -> signature_shape(D, V, E) end, Env1,
                        lists:zip(Fns, Placeholders)),
    Env1a = Env1s#env{st = ern_types:leave(Env1s#env.st)},
    Deps = maps:from_list([{N, free_refs(B, Params, FnNames) -- [N]}
                           || #fn_decl{name = N, params = Params, body = B} <- Fns]),
    Local = #{placeholders => maps:from_list(Placeholders), deps => Deps,
              checked => [], waiting => []},
    {Typed, T, Env2} = infer_stmts(Stmts, Pos, Env1a, Local, []),
    %% every fn is generalized by now; put the schemes on the nodes
    Typed1 = [case S of
                  #fn_decl{name = N} -> S#fn_decl{type = maps:get(N, Env2#env.vars)};
                  _ -> S
              end || S <- Typed],
    {Typed1, T, Env2}.

%% Local fns not yet checked that N depends on, transitively.
pending(N, #{deps := Deps, checked := Checked}) ->
    pending([N], Deps, Checked, []) -- [N].

pending([], _Deps, _Checked, Acc) ->
    Acc;
pending([N | Ns], Deps, Checked, Acc) ->
    case lists:member(N, Acc) of
        true -> pending(Ns, Deps, Checked, Acc);
        false -> pending(maps:get(N, Deps, []) ++ Ns, Deps, Checked, [N | Acc])
    end.

%% Generalize every waiting fn whose dependencies are all checked.
release(Env, #{waiting := Waiting, placeholders := Ps, checked := Checked} = Local) ->
    Ready = [N || N <- Waiting, (pending(N, Local) -- Checked) =:= []],
    Env1 = lists:foldl(fun(N, E) ->
                           {Scheme, St} = ern_types:generalize(maps:get(N, Ps), E#env.st),
                           E#env{st = St, vars = maps:put(N, Scheme, E#env.vars)}
                       end, Env, Ready),
    {Env1, Local#{waiting => Waiting -- Ready}}.

infer_stmts([Last], _Pos, Env, _Fns, Acc) ->
    case Last of
        #binding{} -> fail(element(2, Last), "a block ends with an expression");
        #fn_decl{} -> fail(element(2, Last), "a block ends with an expression");
        _ ->
            {Typed, T, Env1} = infer(Last, Env),
            {lists:reverse([Typed | Acc]), T, Env1}
    end;
infer_stmts([#fn_decl{pos = FPos, owner = Owner} | _], _Pos, _Env, _Fns, _Acc)
  when Owner =/= undefined ->
    fail(FPos, "a type-member name, `fn " ++ atom_to_list(Owner) ++ ".name`, is a top-level"
               " form; a local function has a plain name");
infer_stmts([#fn_decl{name = N} = D | Rest], Pos, Env, Local, Acc) ->
    V = maps:get(N, maps:get(placeholders, Local)),
    Env1 = Env#env{st = ern_types:enter(Env#env.st)},
    {TypedD, Post, Env2a} = check_value(D, V, Env1),
    Env2 = post_checks(Post, Env2a),
    Env3 = Env2#env{st = ern_types:leave(Env2#env.st)},
    Local1 = Local#{checked => [N | maps:get(checked, Local)],
                    waiting => maps:get(waiting, Local) ++ [N]},
    {Env4, Local2} = release(Env3, Local1),
    infer_stmts(Rest, Pos, Env4, Local2, [TypedD | Acc]);
infer_stmts([#binding{pos = BPos, pattern = P, ann = Ann, op = '=', expr = X} = B | Rest],
            Pos, Env, Fns, Acc) ->
    {TypedX, XT, Env1} = infer(X, Env),
    {TypedP, PT, Bindings, Env2} = check_pattern(P, Env1),
    irrefutable(P, Env2) orelse fail(BPos, "a `let` pattern must be irrefutable; use match"),
    Env3 = unify_at(BPos, PT, XT, Env2, "the pattern does not fit the value"),
    Env4 = case Ann of
               undefined -> Env3;
               _ ->
                   {AT, _, St} = ann(Ann, #{}, Env3),
                   unify_at(BPos, AT, XT, Env3#env{st = St}, "the value does not have the"
                                                             " declared type")
           end,
    Env5 = bind_vars(Bindings, Env4),
    infer_stmts(Rest, Pos, Env5, Fns, [B#binding{pattern = TypedP, expr = TypedX} | Acc]);
infer_stmts([#binding{pos = BPos, pattern = P, ann = Ann, op = '<-', expr = X} = B | Rest],
            Pos, Env, Fns, Acc) ->
    %% report §5.5: e : Either(err, a) binds p : a; the rest is Either(err, _).
    %% Which sum type is decided at the end of the definition (solve_deferred).
    {TypedX, XT, Env1} = infer(X, Env),
    {TypedP, PT, Bindings, Env2} = check_pattern(P, Env1),
    irrefutable(P, Env2) orelse fail(BPos, "a `let` pattern must be irrefutable; use match"),
    Env3 = case Ann of
               undefined -> Env2;
               _ ->
                   {AT, _, St} = ann(Ann, #{}, Env2),
                   unify_at(BPos, AT, PT, Env2#env{st = St}, "the value does not have the"
                                                             " declared type")
           end,
    Env4 = bind_vars(Bindings, Env3),
    {TypedRest, RestT, Env5} = infer_stmts(Rest, Pos, Env4, Fns, []),
    Env6 = Env5#env{deferred = [{bind_arrow, BPos, XT, PT, RestT} | Env5#env.deferred]},
    {lists:reverse(Acc) ++ [B#binding{pattern = TypedP, expr = TypedX} | TypedRest], RestT, Env6};
infer_stmts([X | Rest], Pos, Env, Fns, Acc) ->
    {TypedX, _T, Env1} = infer(X, Env),
    infer_stmts(Rest, Pos, Env1, Fns, [TypedX | Acc]).

%%
%% Patterns: check_pattern(P, Env) -> {TypedP, Type, Bindings, Env}
%%

check_pattern(P, Env) ->
    {TypedP, T, Bindings, Env1} = pat(P, Env),
    Names = [N || {N, _} <- Bindings],
    case Names -- lists:usort(Names) of
        [] -> ok;
        [Dup | _] -> fail(element(2, P), "variable " ++ atom_to_list(Dup)
                                         ++ " appears twice in the pattern")
    end,
    {TypedP, T, Bindings, Env1}.

pat(#p_wild{} = P, Env) ->
    {T, St} = ern_types:fresh(Env#env.st),
    {P#p_wild{type = T}, T, [], Env#env{st = St}};
pat(#p_var{name = N} = P, Env) ->
    {T, St} = ern_types:fresh(Env#env.st),
    {P#p_var{type = T}, T, [{N, T}], Env#env{st = St}};
pat(#p_lit{kind = Kind} = P, Env) ->
    T = case Kind of
            int -> ?INT; float -> ?FLOAT; char -> ?CHAR; string -> ?STRING; bool -> ?BOOL
        end,
    {P#p_lit{type = T}, T, [], Env};
pat(#p_con{pos = Pos, path = Path, name = Name, args = Args} = P, Env) ->
    CI = lookup_con(Pos, Path, Name, Env),
    {CT, St} = ern_types:instantiate(CI#cinfo.scheme, Env#env.st),
    Env1 = Env#env{st = St},
    case {CI#cinfo.fields, Args} of
        {none, none} ->
            {P#p_con{type = CT}, CT, [], Env1};
        {none, _} ->
            fail(Pos, atom_to_list(Name) ++ " takes no fields");
        {positional, {positional, Sub}} ->
            {tfn, [FT], pure, RT} = CT,
            {TypedSub, SubT, Bs, Env2} = pat(Sub, Env1),
            Env3 = unify_at(Pos, FT, SubT, Env2, "the field of " ++ atom_to_list(Name)),
            {P#p_con{args = {positional, TypedSub}, type = RT}, RT, Bs, Env3};
        {positional, _} ->
            fail(Pos, atom_to_list(Name) ++ " has one positional field; write "
                      ++ atom_to_list(Name) ++ "(p)");
        {{named, Names}, {named, FieldPats}} ->
            {tfn, FTs, pure, RT} = CT,
            FieldNames = [N || #field_pat{name = N} <- FieldPats],
            length(lists:usort(FieldNames)) =:= length(FieldNames) orelse
                fail(Pos, "a field is matched twice"),
            {TypedFPs, {Bs, Env2}} =
                lists:mapfoldl(
                  fun(#field_pat{pos = FPos, name = N, pattern = Sub} = FP, {BAcc, En}) ->
                          lists:member(N, Names) orelse
                              fail(FPos, atom_to_list(Name) ++ " has no field "
                                         ++ atom_to_list(N)),
                          FT = lists:nth(index_of(N, Names), FTs),
                          {TypedSub, SubT, SubBs, En1} = pat(Sub, En),
                          En2 = unify_at(FPos, FT, SubT, En1, "field " ++ atom_to_list(N)),
                          {FP#field_pat{pattern = TypedSub}, {BAcc ++ SubBs, En2}}
                  end, {[], Env1}, FieldPats),
            {P#p_con{args = {named, TypedFPs}, type = RT}, RT, Bs, Env2};
        {{named, _}, none} ->
            {tfn, _, pure, RT} = CT,
            {P#p_con{type = RT}, RT, [], Env1};
        {{named, _}, _} ->
            fail(Pos, atom_to_list(Name) ++ " has named fields; write "
                      ++ atom_to_list(Name) ++ "(field = p, ...)")
    end;
pat(#p_tuple{elems = Es} = P, Env) ->
    {TypedEs, {Ts, Bs, Env1}} = lists:mapfoldl(fun(E, {TAcc, BAcc, En}) ->
                                                   {TE, T, B, En1} = pat(E, En),
                                                   {TE, {TAcc ++ [T], BAcc ++ B, En1}}
                                               end, {[], [], Env}, Es),
    T = {ttuple, Ts},
    {P#p_tuple{elems = TypedEs, type = T}, T, Bs, Env1};
pat(#p_list{pos = Pos, elems = Es} = P, Env) ->
    {ElemT, St} = ern_types:fresh(Env#env.st),
    {TypedEs, {Bs, Env1}} = lists:mapfoldl(fun(E, {BAcc, En}) ->
                                               {TE, T, B, En1} = pat(E, En),
                                               En2 = unify_at(Pos, ElemT, T, En1,
                                                              "list elements must have one"
                                                              " type"),
                                               {TE, {BAcc ++ B, En2}}
                                           end, {[], Env#env{st = St}}, Es),
    T = {tcon, ['List'], [ElemT]},
    {P#p_list{elems = TypedEs, type = T}, T, Bs, Env1};
pat(#p_cons{pos = Pos, head = H, tail = Tl} = P, Env) ->
    {TypedH, HT, HBs, Env1} = pat(H, Env),
    {TypedTl, TlT, TlBs, Env2} = pat(Tl, Env1),
    T = {tcon, ['List'], [HT]},
    Env3 = unify_at(Pos, T, TlT, Env2, "the tail of `::` must be a list of the head's type"),
    {P#p_cons{head = TypedH, tail = TypedTl, type = T}, T, HBs ++ TlBs, Env3};
pat(#p_as{pattern = Sub, name = N} = P, Env) ->
    {TypedSub, T, Bs, Env1} = pat(Sub, Env),
    {P#p_as{pattern = TypedSub, type = T}, T, Bs ++ [{N, T}], Env1};
pat(#p_bits{pos = Pos}, _Env) ->
    fail(Pos, "bitstrings are not in MVP 1").

%% Report §5.10.
irrefutable(#p_wild{}, _) -> true;
irrefutable(#p_var{}, _) -> true;
irrefutable(#p_as{pattern = P}, Env) -> irrefutable(P, Env);
irrefutable(#p_tuple{elems = Es}, Env) -> lists:all(fun(E) -> irrefutable(E, Env) end, Es);
irrefutable(#p_con{pos = Pos, path = Path, name = Name, args = Args}, Env) ->
    CI = lookup_con(Pos, Path, Name, Env),
    #tinfo{constructors = Cs} = maps:get(CI#cinfo.type_qname, Env#env.types),
    length(Cs) =:= 1 andalso
        case Args of
            none -> true;
            {positional, P} -> irrefutable(P, Env);
            {named, FPs} -> lists:all(fun(#field_pat{pattern = P}) -> irrefutable(P, Env) end,
                                      FPs)
        end;
irrefutable(_, _) -> false.

%%
%% Name lookup (report §4.2)
%%

lookup_value(Pos, [], Name, #env{vars = Vs, local_values = LV, globals = Gs}) ->
    case Vs of
        #{Name := Scheme} -> Scheme;
        _ ->
            case LV of
                #{Name := Q} -> maps:get(Q, Gs);
                _ ->
                    case Gs of
                        #{[Name] := Scheme} -> Scheme;
                        _ -> fail(Pos, "unknown name " ++ atom_to_list(Name))
                    end
            end
    end;
lookup_value(Pos, [Owner] = Path, Name, #env{local_values = LV, globals = Gs}) ->
    case LV of
        #{{Owner, Name} := Q} -> maps:get(Q, Gs);
        _ -> lookup_global(Pos, Path ++ [Name], Gs)
    end;
lookup_value(Pos, Path, Name, #env{globals = Gs}) ->
    lookup_global(Pos, Path ++ [Name], Gs).

lookup_global(Pos, Q, Gs) ->
    case Gs of
        #{Q := Scheme} -> Scheme;
        _ -> fail(Pos, "unknown name " ++ format_qname(Q))
    end.

lookup_con(Pos, [], Name, #env{local_cons = LC, cons = Cs}) ->
    case LC of
        #{Name := Q} -> maps:get(Q, Cs);
        _ ->
            case Cs of
                #{[Name] := CI} -> CI;
                _ -> fail(Pos, "unknown constructor " ++ atom_to_list(Name))
            end
    end;
lookup_con(Pos, Path, Name, #env{cons = Cs}) ->
    Q = Path ++ [Name],
    case Cs of
        #{Q := CI} -> CI;
        _ -> fail(Pos, "unknown constructor " ++ format_qname(Q))
    end.

%%
%% Abstract type signatures (report §4.4; ownership is MVP 2)
%%

check_signatures(Decls, Env) ->
    lists:append([check_signature_list(D, Env) || #abstract_decl{} = D <- Decls]).

check_signature_list(#abstract_decl{type = #type_decl{name = TName}, signatures = Sigs}, Env) ->
    lists:append(
      [try
           Q = value_qname(Env, TName, Name),
           case maps:find(Q, Env#env.globals) of
               error -> fail(Pos, atom_to_list(TName) ++ "." ++ atom_to_list(Name)
                                  ++ " is in the signature but not defined");
               {ok, Scheme} ->
                   {Declared, VarMap, St} = ann(Syntax, #{}, Env),
                   {Actual, St1} = ern_types:instantiate(Scheme, St),
                   %% the signature is printed before unification, the member after
                   Mismatch = fun(S) ->
                                  fail(Pos, atom_to_list(TName) ++ "." ++ atom_to_list(Name)
                                            ++ " is " ++ ern_types:format_scheme(Scheme, S)
                                            ++ ", not the signature's "
                                            ++ ern_types:format(Declared, St1))
                              end,
                   case ern_types:unify(Declared, Actual, St1) of
                       {ok, St2} ->
                           %% the signature's variables must stay distinct and
                           %% unbound: the member is at least as general
                           Ids = [ern_types:resolve(V, St2) || V <- maps:values(VarMap)],
                           case lists:all(fun({tvar, _}) -> true; (_) -> false end, Ids)
                                andalso length(lists:usort(Ids)) =:= length(Ids) of
                               true -> [];
                               false -> Mismatch(St2)
                           end;
                       {error, _} ->
                           Mismatch(St1)
                   end
           end
       catch
           throw:{type_error, Pos, Msg} -> [diag(Pos, Msg)]
       end || #signature{pos = Pos, name = Name, type = Syntax} <- Sigs]).

%%
%% Interface
%%

make_iface(Decls, #env{ns = Ns, types = Ts, globals = Gs} = Env) ->
    ExportedTypes = maps:from_list([{Q, maps:get(Q, Ts)}
                                    || D <- Decls, {true, Q} <- [exported_type(D, Env)]]),
    ExportedValues = maps:from_list([{Q, maps:get(Q, Gs)}
                                     || D <- Decls, {true, Q} <- [exported_value(D, Env)]]),
    #iface{namespace = Ns, types = ExportedTypes, values = ExportedValues}.

exported_type(#type_decl{export = true, name = N}, Env) -> {true, Env#env.ns ++ [N]};
exported_type(#abstract_decl{export = true, type = #type_decl{name = N}}, Env) ->
    {true, Env#env.ns ++ [N]};
exported_type(#foreign_type_decl{export = true, name = N}, Env) -> {true, Env#env.ns ++ [N]};
exported_type(_, _) -> false.

exported_value(#fn_decl{export = true, owner = O, name = N}, Env) -> {true, value_qname(Env, O, N)};
exported_value(#let_decl{export = true, owner = O, name = N}, Env) ->
    {true, value_qname(Env, O, N)};
exported_value(#foreign_fn_decl{export = true, owner = O, name = N}, Env) ->
    {true, value_qname(Env, O, N)};
exported_value(_, _) -> false.

%%
%% Helpers
%%

-spec resolve_type(ern_types:type(), env()) -> ern_types:type().
resolve_type(T, #env{st = St}) -> ern_types:zonk(T, St).

-spec node_type(tuple()) -> ern_types:type().
node_type(Node) ->
    lists:last(tuple_to_list(Node)).

unify_at(Pos, Expected, Actual, #env{st = St} = Env, Context) ->
    case ern_types:unify(Expected, Actual, St) of
        {ok, St1} ->
            Env#env{st = St1};
        {error, Reason} ->
            fail(Pos, unify_message(Context, Reason, Expected, Actual, St))
    end.

unify_message(Context, {mismatch, _, _}, Expected, Actual, St) ->
    lists:flatten([Context, ": expected ", ern_types:format(Expected, St), ", found ",
                   ern_types:format(Actual, St)]);
unify_message(Context, process_only_vs_pure, _, _, _) ->
    lists:flatten([Context, ": ", ern_types:format_error(process_only_vs_pure)]);
unify_message(Context, {pure_vs_effect, _}, Expected, Actual, St) ->
    lists:flatten([Context, ": expected ", ern_types:format(Expected, St), ", found ",
                   ern_types:format(Actual, St), " (a pure function and one with a mailbox"
                   " effect do not match)"]);
unify_message(Context, Reason, Expected, Actual, St) ->
    lists:flatten([Context, ": ", ern_types:format_error(Reason), " (",
                   ern_types:format(Expected, St), " against ", ern_types:format(Actual, St),
                   ")"]).

format_qname(Parts) -> lists:flatten(lists:join(".", [atom_to_list(P) || P <- Parts])).

plural(1) -> "";
plural(_) -> "s".

fail(Pos, Message) ->
    throw({type_error, Pos, lists:flatten(Message)}).
