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
         prelude_names/0,
         prelude_con/1, prelude_cons/0, prelude_env/0, lookup_type/2, is_member_path/3,
         member_qname/3, is_reply_carrying/2, assume_reply_carrying/2, foreign_impl/1,
         declared_scheme/3, let_order/1, lookup_con/4,
         con_info/2, is_value/2, resolve_type/2, node_type/1]).

-export_type([env/0, session/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diag.hrl").

-record(env, {ns = [], types = #{}, cons = #{}, globals = #{}, lets = #{},
              local_types = #{}, local_cons = #{}, local_values = #{}, session = #{},
              vars = #{}, effect = pure, st, pending = [], deferred = [],
              ann_vars = #{}, rigid = [], effect_origin = undefined,
              groups = #{}, typed = [], errs = [], reply_vars = [],
              reply_params = #{}, let_order = []}).
%% let_order: the module's top-level lets in the order §8.5 evaluates them,
%% which the emitter reads.
%% reply_params: for each declared type with parameters, whether each can
%% make an instantiation reply-carrying (report §6.6)
%% reply_vars: type variables the reply discipline takes for reply-carrying
%% while it asks whether a body would keep §6.6 if they were (§3.9)
%% lets: the qualified names, this module's and its dependencies', that
%% were declared with `let`; the emitter reaches a value through its getter
%% session: the shell's session, a scope between this module's own
%% declarations and the prelude (report §11.2), empty in every other module
%% groups: qname => the dependency group not yet checked that declares it,
%% checked on first demand (a reference, or an operator resolving to it);
%% typed: the groups checked so far; errs: their errors
%% effect_origin: undefined | {what, span, label, help}: what is pure here
%% ("f", "the lambda", "a top-level `let`", "a guard"), the span that
%% made it so, and what to do; named by an effect error (report §11.5)
-opaque env() :: #env{}.

-type error() :: ern_diag:diag().
-type key() :: atom() | {atom(), atom()}.
-type session() :: #{values => #{key() => [atom()]}, types => #{atom() => [atom()]},
                     cons => #{atom() => [atom()]}}.

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
-spec check([atom()], [tuple()], [#iface{}]) ->
          {ok, [tuple()], #iface{}, env()} | {error, [error()]}.
check(Ns, Decls0, Ifaces) ->
    check(Ns, Decls0, Ifaces, #{}).

%% Report §11.2: the shell's session is a scope of its own, looked in after
%% the input's own declarations and before the prelude. Its three maps take
%% an unqualified name, as a module's own do, to the qualified name of the
%% input that declared it.
-spec check([atom()], [tuple()], [#iface{}], session()) ->
          {ok, [tuple()], #iface{}, env()} | {error, [error()]}.
check(Ns, Decls0, Ifaces, Session) ->
    Decls = builtin_operators(Ns, Decls0),
    Seeded = lists:foldl(fun add_iface/2, (prelude_env())#env{ns = Ns}, Ifaces),
    Env0 = Seeded#env{session = Session},
    try
        {Env1a, Errs1} = declare_types(Decls, Env0),
        %% report §11.5: the module's types print unqualified, except those
        %% that shadow a prelude name
        Shadows = [N || N <- maps:keys(Env1a#env.local_types), is_map_key([N], Env1a#env.types)],
        %% report §11.2: a session type prints unqualified, except one a
        %% later input has shadowed, which prints as the input that declared it
        SessionTypes = maps:values(maps:get(types, Session, #{})),
        St1 = ern_types:set_scope(effect_params(Env1a), Ns, SessionTypes, Shadows),
        Env1 = mark_abstract(Decls, Env1a#env{st = St1}),
        {Typed, Env2, Errs2} = check_values(Decls, Env1),
        Errs3 = check_abstract(Decls) ++ check_exports(Decls, Env2),
        case lists:sort(Errs1 ++ Errs2 ++ Errs3) of
            [] -> {ok, Typed, make_iface(Decls, Env2), Env2};
            Errs -> {error, Errs}
        end
    catch
        throw:{type_error, Pos, Msg} -> {error, [diag(Pos, Msg)]};
        throw:{type_error, #diag{} = D} -> {error, [D]}
    end.

%% Report §4.8: in the standard library module of a built-in type, an
%% operator declared as that type's, `fn Float.+` in float.ern, is the
%% module's own `+`, as a self-qualified name is (§4.2).
builtin_operators([T], Decls) ->
    case lists:keymember(T, 1, ern_prelude:builtin_types()) of
        true -> [own_operator(T, D) || D <- Decls];
        false -> Decls
    end;
builtin_operators(_, Decls) ->
    Decls.

own_operator(T, #fn_decl{owner = T, name = N} = D) ->
    case is_operator(N) of
        true -> D#fn_decl{owner = undefined};
        false -> D
    end;
own_operator(T, #foreign_fn_decl{owner = T, name = N} = D) ->
    case is_operator(N) of
        true -> D#foreign_fn_decl{owner = undefined};
        false -> D
    end;
own_operator(_, D) ->
    D.

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

%% The state a type is printed under outside a check: the prelude's, and
%% which parameters of the types of Ifaces are no value position (report
%% §3.9), so a variable found only in one prints as an effect variable does.
-spec scope_state([#iface{}]) -> ern_types:st().
scope_state(Ifaces) ->
    effect_params(lists:foldl(fun add_iface/2, prelude_env(), Ifaces)).

-spec set_type_state(ern_types:st(), env()) -> env().
set_type_state(St, Env) -> Env#env{st = St}.

%%
%% The prelude
%%

%% Report §11.2: the types and constructors the prelude declares, for
%% the shell's completion, which offers them as it offers a module's.
-spec prelude_names() -> {[[atom()]], [[atom()]]}.
prelude_names() ->
    #env{types = Ts, cons = Cs} = prelude_env(),
    {maps:keys(Ts), maps:keys(Cs)}.

%% Report §11.2: a prelude constructor, whose type is the page that
%% documents it and whose scheme a listing shows, for the shell.
-spec prelude_con(atom()) -> {ok, #cinfo{}} | none.
prelude_con(Name) ->
    case prelude_cons() of
        #{[Name] := CI} -> {ok, CI};
        _ -> none
    end.

%% Every prelude constructor by its qualified name, read once where many are.
-spec prelude_cons() -> #{[atom()] => #cinfo{}}.
prelude_cons() ->
    #env{cons = Cs} = prelude_env(),
    Cs.

-spec prelude_env() -> env().
prelude_env() ->
    Env0 = #env{st = ern_types:new()},
    Env1 = lists:foldl(fun({Name, Arity, _Doc}, E) ->
                           Params = lists:seq(1, Arity),
                           add_type(E, #tinfo{qname = [Name], params = Params, foreign = true,
                                              eq = ern_prelude:equality_params(Name)})
                       end, Env0, ern_prelude:builtin_types()),
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    {Env2a, []} = declare_types(Decls, Env1),
    Env2 = Env2a#env{st = effect_params(Env2a)},
    Env3 = lists:foldl(fun({QName, Text, _Doc}, E) ->
                           {ok, Syntax} = ern_parser:parse_type(Text),
                           ProcessOnly = lists:member(QName, ern_prelude:process_only()),
                           {Scheme, E1} = signature_scheme(Syntax, ProcessOnly, E),
                           E1#env{globals = maps:put(QName, Scheme, E1#env.globals)}
                       end,
                       Env2#env{ns = [], local_types = #{}, local_cons = #{}, local_values = #{}},
                       ern_prelude:values()),
    %% the standard library modules written in Ernest, by their interfaces
    lists:foldl(fun add_iface/2, Env3, ern_prelude:stdlib_ifaces()).

%% Report §4.4: the type's info, and so the compiled interface, marks an
%% abstract type; lookup_con refuses its constructor from another module.
mark_abstract(Decls, #env{local_types = LT, types = Ts} = Env) ->
    Env#env{types = lists:foldl(fun(#abstract_decl{type = #type_decl{name = N}}, Acc) ->
                                    maps:update_with(maps:get(N, LT),
                                                     fun(TI) -> TI#tinfo{abstract = true} end, Acc);
                                   (_, Acc) -> Acc
                                end, Ts, Decls)}.

add_iface(#iface{types = Ts, values = Vs, lets = Lets}, #env{types = ET, globals = EG} = Env) ->
    Cons = maps:fold(fun(_, #tinfo{constructors = Cs}, Acc) ->
                         lists:foldl(fun(#cinfo{qname = Q} = C, A) -> A#{Q => C} end, Acc, Cs)
                     end, Env#env.cons, Ts),
    Env#env{types = maps:merge(ET, Ts), globals = maps:merge(EG, Vs), cons = Cons,
            lets = maps:merge(Env#env.lets, maps:from_list([{Q, true} || Q <- Lets]))}.

add_type(#env{types = Ts, cons = Cs} = Env, #tinfo{qname = Q, constructors = Cons} = TI) ->
    Cs1 = lists:foldl(fun(#cinfo{qname = CQ} = C, A) -> A#{CQ => C} end, Cs, Cons),
    Env#env{types = Ts#{Q => TI}, cons = Cs1}.

%% A signature from the prelude tables: every annotation variable is
%% generalized; effect variables of the process primitives are process-only.
signature_scheme(Syntax, ProcessOnly, Env) ->
    St0 = ern_types:enter(Env#env.st),
    {T, VarMap, St1} = ann(Syntax, #{}, Env#env{st = St0}),
    Z = ern_types:zonk(T, St1),
    Effs = ern_types:effect_vars(Z),
    Vals = ern_types:value_vars(Z, St1),
    St2 = lists:foldl(fun(Id, S) -> ern_types:add_flag({tvar, Id}, process_only, S) end, St1,
                      [Id || Id <- Effs, ProcessOnly orelse lists:member(Id, Vals)]),
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
    %% report §3.10, §4.7, §9.2: a parameter declared `k=` puts the
    %% equality constraint on every variable of its argument, wherever the
    %% type is written; an argument that holds a function or an address is
    %% refused at the type's first operation, not here
    Keys = case lookup_type(QName, Env) of
               #tinfo{eq = [_ | _] = Eq} -> [A || {A, true} <- lists:zip(ArgTs, Eq)];
               _ -> []
           end,
    St1 = lists:foldl(fun(T, S) -> ern_types:add_flag(T, eq, S) end, St,
                      [{tvar, Id} || K <- Keys, not has_fn_or_address(K),
                                     Id <- ern_types:free_vars(K, St)]),
    {{tcon, QName, ArgTs}, VarMap1, St1};
ann(#t_tuple{elems = Es}, VarMap, Env) ->
    {Ts, VarMap1, St} = ann_list(Es, VarMap, Env),
    {{ttuple, Ts}, VarMap1, St};
ann(#t_fn{params = Ps, ret = R, effect = E}, VarMap, Env) ->
    {PTs, VarMap1, St1} = ann_list(Ps, VarMap, Env),
    {RT, VarMap2, St2} = ann(R, VarMap1, Env#env{st = St1}),
    {ET, VarMap3, St3} = ann(E, VarMap2, Env#env{st = St2}),
    {{tfn, PTs, ET, RT}, VarMap3, St3}.

ann_list(Syntaxes, VarMap, Env) ->
    {Ts, {VarMap1, St}} = lists:mapfoldl(fun(S, {VM, St0}) ->
                                             {T, VM1, St1} = ann(S, VM, Env#env{st = St0}),
                                             {T, {VM1, St1}}
                                         end, {VarMap, Env#env.st}, Syntaxes),
    {Ts, VarMap1, St}.

lookup_type_name(Pos, [], Name, #env{local_types = LT, types = Ts} = Env) ->
    case LT of
        #{Name := Q} -> {Q, length((maps:get(Q, Ts))#tinfo.params)};
        _ ->
            case session(types, Name, Env) of
                {ok, Q} -> {Q, length((maps:get(Q, Ts))#tinfo.params)};
                error ->
                    case Ts of
                        #{[Name] := #tinfo{params = Ps}} -> {[Name], length(Ps)};
                        _ -> fail(Pos, "unknown type " ++ atom_to_list(Name))
                    end
            end
    end;
lookup_type_name(Pos, ['Prelude'], Name, #env{types = Ts}) ->
    %% report §4.2: `Prelude.T` is the prelude's T, whatever the module declares
    case Ts of
        #{[Name] := #tinfo{params = Ps}} -> {[Name], length(Ps)};
        _ -> fail(Pos, "the prelude declares no type " ++ atom_to_list(Name))
    end;
lookup_type_name(Pos, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Pos, Path, Name);
lookup_type_name(Pos, Path, Name, #env{types = Ts}) ->
    Q = Path ++ [Name],
    case Ts of
        #{Q := #tinfo{params = Ps}} -> {Q, length(Ps)};
        _ -> fail(Pos, "unknown type " ++ format_qname(Q))
    end.

-spec lookup_type([atom()], env()) -> #tinfo{} | undefined.
lookup_type(QName, #env{types = Ts}) -> maps:get(QName, Ts, undefined).

%% Report §4.2, §11.2: whether Path is a module and the type that owns the
%% member Name: a type of that module, or, at the prompt, a type the session
%% declares whose member a later input declared.
-spec is_member_path([atom()], atom(), env()) -> boolean().
is_member_path(Path, Name, Env) ->
    case lookup_type(Path, Env) of
        #tinfo{qname = Q} when length(Q) > 1 -> true;
        _ -> session(values, {lists:last(Path), Name}, Env) =:= {ok, Path ++ [Name]}
    end.

%% Report §4.8, §11.2: the qualified name of the member an operator on the
%% type Q resolves to, which at the prompt a later input may have declared.
-spec member_qname([atom()], atom(), env()) -> [atom()].
member_qname(Q, Member, Env) ->
    session_member(Q, Member, Env).

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
    Env2 = lists:foldl(fun(#foreign_type_decl{pos = Pos, name = Name, params = Params,
                                              eq = Eq}, Env) ->
                           check_unique_type(Pos, Name, Env),
                           Q = Env#env.ns ++ [Name],
                           EqFlags = case Eq of
                                         [] -> [];
                                         _ -> [lists:member(P, Eq) || P <- Params]
                                     end,
                           Env3 = add_type(Env, #tinfo{qname = Q, params = Params,
                                                       foreign = true, eq = EqFlags}),
                           Env3#env{local_types = maps:put(Name, Q, Env3#env.local_types)}
                       end, Env1, [D || #foreign_type_decl{} = D <- Decls]),
    %% pass two: constructors
    {Env3, Errs} = lists:foldl(fun(TD, {Env, Errs}) ->
                                   try
                                       {declare_constructors(TD, Env), Errs}
                                   catch
                                       throw:{type_error, Pos, Msg} ->
                                           {Env, [diag(Pos, Msg) | Errs]};
                                       throw:{type_error, #diag{} = D} ->
                                           {Env, [D | Errs]}
                                   end
                               end, {Env2, []}, TypeDecls),
    {mark_reply_carrying(reply_params(Env3)), Errs}.

%% Report §3.9: a type argument is a value position where its parameter
%% occurs in a value position of the type's fields; one of a built-in or
%% foreign type always is. The state keeps the types that have a parameter
%% that is not.
effect_params(#env{types = Ts, st = St}) ->
    Flags = param_flags(Ts, fun in_value/3),
    ern_types:set_effect_params(St, maps:filter(fun(_, Fs) -> lists:member(false, Fs) end,
                                                Flags)).

%% Report §6.6: a declared type is reply-carrying at an instantiation whose
%% fields, its arguments substituted, have a reply-carrying type. An
%% argument can make them so only where its parameter reaches a field
%% outside function types and the arguments of built-in and foreign types,
%% which never carry a reply.
reply_params(#env{types = Ts} = Env) ->
    Env#env{reply_params = param_flags(Ts, fun in_reply/3)}.

%% For each declared type with parameters, whether each parameter occurs in
%% its fields as In says. A parameter may occur only as an argument of
%% another type, or of its own, so the flags are a least fixpoint over
%% every declared type in scope. A type whose constructors failed to
%% declare keeps its parameters' names, and has no fields to read.
param_flags(Ts, In) ->
    Declared = maps:from_list([{Q, TI} || Q := #tinfo{foreign = false, params = [_ | _] = Ps} = TI
                                              <- Ts,
                                          lists:all(fun(P) -> is_tuple(P) end, Ps)]),
    param_fixpoint(Declared, In, maps:map(fun(_, #tinfo{params = Ps}) -> [false || _ <- Ps] end,
                                          Declared)).

param_fixpoint(Declared, In, Flags) ->
    Flags1 = maps:map(fun(Q, Fs) ->
                          #tinfo{params = Ps, constructors = Cs} = maps:get(Q, Declared),
                          Fields = lists:append([FTs || #cinfo{scheme = #scheme{type = T}} <- Cs,
                                                        {tfn, FTs, _, _} <- [T]]),
                          [F orelse lists:any(fun(FT) -> In(Id, FT, Flags) end, Fields)
                           || {F, {tvar, Id}} <- lists:zip(Fs, Ps)]
                      end, Flags),
    case Flags1 =:= Flags of
        true -> Flags;
        false -> param_fixpoint(Declared, In, Flags1)
    end.

%% Does variable Id occur in a value position of T, given which parameters
%% of the declared types are value positions so far?
in_value(Id, {tvar, Id}, _Flags) ->
    true;
in_value(Id, {tcon, Q, As}, Flags) ->
    Values = case Flags of
                 #{Q := Fs} -> [A || {A, true} <- lists:zip(As, Fs)];
                 _ -> As
             end,
    lists:any(fun(A) -> in_value(Id, A, Flags) end, Values);
in_value(Id, {ttuple, Es}, Flags) ->
    lists:any(fun(E) -> in_value(Id, E, Flags) end, Es);
in_value(Id, {tfn, Ps, _, R}, Flags) ->
    lists:any(fun(X) -> in_value(Id, X, Flags) end, [R | Ps]);
in_value(_, _, _) ->
    false.

%% Does variable Id reach T outside function types and the arguments of
%% built-in and foreign types, given which parameters of the declared types
%% reach their fields so far?
in_reply(Id, {tvar, Id}, _Flags) ->
    true;
in_reply(Id, {tcon, Q, As}, Flags) ->
    Reaching = case Flags of
                   #{Q := Fs} -> [A || {A, true} <- lists:zip(As, Fs)];
                   _ -> []
               end,
    lists:any(fun(A) -> in_reply(Id, A, Flags) end, Reaching);
in_reply(Id, {ttuple, Es}, Flags) ->
    lists:any(fun(E) -> in_reply(Id, E, Flags) end, Es);
in_reply(_, _, _) ->
    false.

type_decl_of(#type_decl{} = TD) -> [TD];
type_decl_of(#abstract_decl{type = TD}) -> [TD];
type_decl_of(_) -> [].

check_unique_type(Pos, 'Prelude', _Env) ->
    %% report §4.2: `Prelude.X` names the prelude's X, so no type is Prelude
    fail(Pos, "Prelude names the prelude, and a type may not take it");
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
        {tvar, _} = V -> lists:member(V, Env#env.reply_vars);
        {tcon, ['Reply'], _} -> true;
        {tcon, Q, Args} ->
            case Ts of
                #{Q := #tinfo{foreign = true}} -> false;
                #{Q := #tinfo{reply_carrying = true}} -> true;
                _ ->
                    Reaching = case Env#env.reply_params of
                                   #{Q := Fs} -> [A || {A, true} <- lists:zip(Args, Fs)];
                                   _ -> []
                               end,
                    lists:any(fun(A) -> reply_in(A, Ts, Env) end, Reaching)
            end;
        {ttuple, Es} -> lists:any(fun(E) -> reply_in(E, Ts, Env) end, Es);
        _ -> false
    end.

-spec is_reply_carrying(ern_types:type(), env()) -> boolean().
is_reply_carrying(T, #env{types = Ts} = Env) -> reply_in(T, Ts, Env).

%% Report §3.9, §6.6: the environment in which the type variables Vars are
%% taken for reply-carrying.
-spec assume_reply_carrying([ern_types:type()], env()) -> env().
assume_reply_carrying(Vars, Env) -> Env#env{reply_vars = Vars}.

%%
%% Values: fn, let, foreign fn, in dependency order
%%

check_values(Decls, Env0) ->
    Values = [D || D <- Decls, is_value_decl(D)],
    %% names first, so every body can see every other
    Env1 = lists:foldl(fun(D, Env) -> register_value_name(D, Env) end, Env0, Values),
    Groups = dependency_groups(Values, Env1),
    Pending = maps:from_list([{group_qname(D, Env1), G} || G <- Groups, D <- G]),
    Env2 = lists:foldl(fun run_group/2, Env1#env{groups = Pending, typed = [], errs = []}, Groups),
    Errs = let_cycles(Env2#env.typed, Env2) ++ Env2#env.errs,
    Order = case Errs of
                [] -> initialization_order(Env2#env.typed, Env2);
                _ -> []
            end,
    %% restore declaration order for the typed output
    Typed = [replace_typed(D, Env2#env.typed) || D <- Decls],
    {Typed, Env2#env{groups = #{}, typed = [], errs = [], let_order = Order}, Errs}.

%% Report §8.5: the order the module's top-level lets are evaluated in, a
%% let after every let its initializer reaches, directly or through the
%% functions it names; the cycle check has passed.
-spec let_order(env()) -> [{atom() | undefined, atom()}].
let_order(#env{let_order = Order}) ->
    Order.

group_qname(D, Env) ->
    {Owner, Name} = decl_key(D),
    value_qname(Env, Owner, Name).

%% A group is checked once, when the fold reaches it or when a definition
%% under inference demands one of its names first (report §4.8: an
%% operator names its member only once the operand type is known, so the
%% reference graph cannot order it). A failed group gets placeholders so
%% later groups report their own errors.
run_group(Group, #env{groups = Pending} = Env) ->
    Keys = [group_qname(D, Env) || D <- Group],
    case maps:is_key(hd(Keys), Pending) of
        false ->
            Env;
        true ->
            Env1 = Env#env{groups = maps:without(Keys, Pending)},
            try check_group(Group, Env1) of
                {Typed, Env2} -> Env2#env{typed = Env2#env.typed ++ Typed}
            catch
                throw:{type_error, Pos, Msg} ->
                    E = placeholder_group(Group, Env1),
                    E#env{typed = E#env.typed ++ Group, errs = [diag(Pos, Msg) | E#env.errs]};
                throw:{type_error, #diag{} = D} ->
                    E = placeholder_group(Group, Env1),
                    E#env{typed = E#env.typed ++ Group, errs = [D | E#env.errs]}
            end
    end.

%% A name demanded before its group ran: the group is checked now, with
%% the demanding definition's own scope set aside and restored after.
demand(Q, #env{groups = Pending} = Env) ->
    case Pending of
        #{Q := Group} ->
            Clean = Env#env{vars = #{}, effect = pure, pending = [], deferred = [], ann_vars = #{},
                            rigid = [], effect_origin = undefined},
            restore_scope(run_group(Group, Clean), Env);
        _ ->
            Env
    end.

%% A definition's own scope set aside: Checked, the environment after it,
%% with the scope of Env, the environment before it.
restore_scope(Checked, Env) ->
    Checked#env{vars = Env#env.vars, effect = Env#env.effect, pending = Env#env.pending,
                deferred = Env#env.deferred, ann_vars = Env#env.ann_vars, rigid = Env#env.rigid,
                effect_origin = Env#env.effect_origin}.

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
    %% report §11.2: at the prompt, a member of a type the session declares
    Owner =:= undefined orelse maps:is_key(Owner, Env#env.local_types)
        orelse session(types, Owner, Env) =/= error
        orelse fail(Pos, atom_to_list(Owner) ++ " is not a type declared in this module"),
    %% report §4.8: an operator is declared with `fn`
    case is_record(D, let_decl) andalso is_operator(Name) of
        true -> fail(Pos, "an operator is declared with `fn`, not `let`");
        false -> ok
    end,
    Q = value_qname(Env, Owner, Name),
    Lets = case D of
               #let_decl{} -> (Env#env.lets)#{Q => true};
               _ -> Env#env.lets
           end,
    Env#env{local_values = LV#{Key => Q}, lets = Lets}.

is_operator(Name) ->
    case atom_to_list(Name) of
        [C | _] when C >= $a, C =< $z; C =:= $_ -> false;
        _ -> true
    end.

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

%% Local value keys a declaration's body refers to: by name, and through
%% an operator whose operand type is known, the member it resolves to
%% (report §4.8, §3.10, §5.1). Before inference no operand type is known,
%% so the graph that orders the groups holds names only and a member is
%% checked on demand (run_group); after it, the typed AST names every
%% member, which the §8.5 cycle rule reads.
references(#fn_decl{params = Ps} = D, Env) ->
    lists:usort(refs(body_of(D), Env, [], binds_params(Ps, #{})));
references(D, Env) ->
    lists:usort(refs(body_of(D), Env, [], #{})).

body_of(#fn_decl{body = B}) -> B;
body_of(#let_decl{body = B}) -> B;
body_of(_) -> undefined.

%% Report §8.5: what a definition refers to, with the names bound inside
%% it left out. A lambda's parameter, a pattern's variable, or a block's
%% binding shadows a top-level name (§4.2), and counting it as a
%% reference made a definition depend on a `let` it never reads, which
%% the cycle check then reported as a cycle.
refs(#e_lambda{params = Ps, body = Body}, Env, Acc, B) ->
    refs(Body, Env, Acc, binds_params(Ps, B));
refs(#clause{pattern = P, guard = G, body = Body}, Env, Acc, B) ->
    B1 = binds(P, B),
    refs(Body, Env, refs(G, Env, refs_in_pattern(P, Env, Acc, B), B1), B1);
refs(#e_block{stmts = Stmts}, Env, Acc, B) ->
    %% a local `fn` is in scope for the whole block, a binding from the
    %% statement after it
    B0 = lists:foldl(fun(#fn_decl{owner = undefined, name = N}, Bs) -> Bs#{N => true};
                        (_, Bs) -> Bs
                     end, B, Stmts),
    {Acc1, _} = lists:foldl(fun(#binding{pattern = P, expr = E}, {A, Bs}) ->
                                {refs(E, Env, A, Bs), binds(P, Bs)};
                               (#fn_decl{params = Ps, body = Body}, {A, Bs}) ->
                                {refs(Body, Env, A, binds_params(Ps, Bs)), Bs};
                               (Stmt, {A, Bs}) ->
                                {refs(Stmt, Env, A, Bs), Bs}
                            end, {Acc, B0}, Stmts),
    Acc1;
refs(#e_var{path = [], name = N}, _Env, Acc, B) when is_map_key(N, B) -> Acc;
refs(#e_var{path = [], name = N}, _Env, Acc, _B) -> [{undefined, N} | Acc];
refs(#e_var{path = Ns, name = N}, #env{ns = Ns}, Acc, _B) when Ns =/= [] ->
    %% the module's own qualified name (report §4.2), which a local binding
    %% of the same name does not hide
    [{undefined, N} | Acc];
refs(#e_var{path = [Owner], name = N}, #env{local_types = LT}, Acc, _B) ->
    case maps:is_key(Owner, LT) of true -> [{Owner, N} | Acc]; false -> Acc end;
refs(#e_var{path = P} = V, #env{ns = Ns} = Env, Acc, B) when length(P) > 1 ->
    case own_type_path(P, Ns) of
        true -> refs(V#e_var{path = [lists:last(P)]}, Env, Acc, B);
        false -> Acc
    end;
refs(#e_binop{op = Op, left = L, right = R}, Env, Acc, B) when is_atom(Op) ->
    Member = case lists:member(Op, ?ORDER) of
                 true -> compare;
                 false -> case lists:member(Op, ?ARITH) orelse Op =:= '<>' of
                              true -> Op;
                              false -> none
                          end
             end,
    refs(R, Env, refs(L, Env, operator_ref(Member, L, Env) ++ Acc, B), B);
refs(#e_not{expr = X}, Env, Acc, B) ->
    refs(X, Env, Acc, B);
refs(#e_neg{expr = X}, Env, Acc, B) ->
    refs(X, Env, operator_ref(negate, X, Env) ++ Acc, B);
refs(T, Env, Acc, B) when is_tuple(T) ->
    lists:foldl(fun(X, A) -> refs(X, Env, A, B) end, Acc, tl(tuple_to_list(T)));
refs(L, Env, Acc, B) when is_list(L) ->
    lists:foldl(fun(X, A) -> refs(X, Env, A, B) end, Acc, L);
refs(_, _, Acc, _B) -> Acc.

%% A pattern binds its variables; an expression inside it, a bitstring
%% segment's size, refers as any expression does.
binds(P, B) ->
    lists:foldl(fun({N, _}, Bs) -> Bs#{N => true} end, B, ern_ast:pattern_bindings(P)).

binds_params(Ps, B) ->
    lists:foldl(fun(#param{pattern = P}, Bs) -> binds(P, Bs) end, B, Ps).

refs_in_pattern(P, Env, Acc, B) ->
    case P of
        #bit_seg{specs = Specs} -> refs(Specs, Env, Acc, B);
        _ when is_tuple(P) ->
            lists:foldl(fun(X, A) -> refs_in_pattern(X, Env, A, B) end, Acc,
                        tl(tuple_to_list(P)));
        _ when is_list(P) ->
            lists:foldl(fun(X, A) -> refs_in_pattern(X, Env, A, B) end, Acc, P);
        _ -> Acc
    end.

%% The member an operator on Operand calls, once typed and of a local type.
operator_ref(none, _, _) -> [];
operator_ref(Member, Operand, #env{ns = Ns, local_types = LT}) ->
    case node_type(Operand) of
        {tcon, Q, _} ->
            Owner = lists:last(Q),
            case own_type_path(Q, Ns) andalso maps:is_key(Owner, LT) of
                true -> [{Owner, Member}];
                false -> []
            end;
        _ ->
            []
    end.

%% Report §4.2: is Path the module's own namespace and one name below it,
%% as `M.T` in module M, where T may be a type the module declares?
own_type_path(Path, Ns) ->
    length(Path) =:= length(Ns) + 1 andalso lists:prefix(Ns, Path).

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
    lists:foreach(fun ern_scope:names/1, Group),
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
                                        member_shape(D, Scheme, E#env{st = St}),
                                        Q = value_qname(E, Owner, Name),
                                        E1 = E#env{st = St,
                                                   globals = maps:put(Q, Scheme, E#env.globals)},
                                        {zonk_ast(set_decl_type(D, Scheme), St), E1}
                                    end, Env3, Typed),
    {Typed2, Env4}.

%% Report §4.8: a member named by an operator has the type (T, T) -> R for
%% its type T, T.compare the type (T, T) -> Ordering, and T.negate the type
%% (T) -> R, each pure. T is the member's type with any type arguments, the
%% same in both parameters. In the module of a built-in type, the module's
%% own operators, compare, and negate are the type's (§4.8, §9.6).
member_shape(D, #scheme{type = {tfn, Ps, Eff, R}} = Scheme, Env) ->
    case member_type(D, Env) of
        none ->
            ok;
        {TQ, Member} ->
            {Arity, Help} = case Member of
                                negate -> {1, "negate takes one value of its type and is pure"};
                                compare -> {2, "compare takes two values of its type, returns an"
                                               " Ordering, and is pure"};
                                _ -> {2, "a member named by an operator takes two values of its"
                                         " type and is pure"}
                            end,
            {TT, St} = case Ps of
                           [{tcon, TQ, _} = P | _] -> {P, Env#env.st};
                           _ -> own_type(TQ, Env)
                       end,
            Result = case Member of
                         compare -> {tcon, ['Ordering'], []};
                         _ -> R
                     end,
            Expected = {tfn, lists:duplicate(Arity, TT), pure, Result},
            case ern_types:zonk({tfn, Ps, Eff, R}, St) =:= Expected of
                true ->
                    ok;
                false ->
                    Shown = fun(T) -> ern_types:format_scheme(Scheme#scheme{type = T}, St) end,
                    fail(element(2, D), format_qname([lists:last(TQ), Member])
                                        ++ " must have the type "
                                        ++ Shown(Expected) ++ ", not "
                                        ++ Shown(Scheme#scheme.type), [], Help)
            end
    end;
member_shape(_, _, _) ->
    ok.

%% The type and the member a declaration names by an operator, compare, or
%% negate, or none.
member_type(D, #env{ns = Ns} = Env) when is_record(D, fn_decl); is_record(D, foreign_fn_decl) ->
    {Owner, Name} = decl_key(D),
    Member = lists:member(Name, [compare, negate | ?ARITH ++ ['<>']]),
    Builtin = case Ns of
                  [B] -> lists:keymember(B, 1, ern_prelude:builtin_types());
                  _ -> false
              end,
    case {Member, Owner} of
        {false, _} -> none;
        {true, undefined} when Builtin -> {Ns, Name};
        {true, undefined} -> none;
        {true, _} -> {owner_qname(Owner, Env), Name}
    end;
member_type(_, _) ->
    none.

%% Report §11.2: the type a member names, the module's own or, at the
%% prompt, one the session declared.
owner_qname(Owner, #env{local_types = LT} = Env) ->
    case LT of
        #{Owner := Q} -> Q;
        _ -> {ok, Q} = session(types, Owner, Env), Q
    end.

%% The type TQ over fresh variables, for its parameters.
own_type(TQ, #env{types = Ts, st = St0}) ->
    #tinfo{params = Params} = maps:get(TQ, Ts),
    {Args, St} = lists:mapfoldl(fun(_, S) -> ern_types:fresh(S) end, St0, Params),
    {{tcon, TQ, Args}, St}.

zonk_ast({tvar, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast({tcon, _, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast({ttuple, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast({tfn, _, _, _} = T, St) -> ern_types:zonk(T, St);
zonk_ast(T, St) when is_tuple(T) -> list_to_tuple([zonk_ast(X, St) || X <- tuple_to_list(T)]);
zonk_ast(L, St) when is_list(L) -> [zonk_ast(X, St) || X <- L];
zonk_ast(X, _) -> X.

%% Report §8.5: a cycle among top-level let initializers, directly or through
%% functions they call, is a compile-time error. Read off the typed
%% declarations, since an operator names its member only once typed; one
%% error per cycle, at its first let.
let_cycles(Decls, Env) ->
    G = reference_graph(Decls, Env),
    Lets = lists:keysort(2, [D || #let_decl{} = D <- Decls]),
    {Errs, _} = lists:foldl(fun(D, {Acc, Seen}) -> let_cycle(D, G, Acc, Seen) end,
                            {[], []}, Lets),
    digraph:delete(G),
    lists:reverse(Errs).

initialization_order(Decls, Env) ->
    G = reference_graph(Decls, Env),
    Lets = [decl_key(D) || #let_decl{} = D <- Decls],
    L = digraph:new(),
    lists:foreach(fun(K) -> digraph:add_vertex(L, K) end, Lets),
    lists:foreach(fun(K) ->
                      [digraph:add_edge(L, K, R)
                       || R <- digraph_utils:reachable_neighbours([K], G), lists:member(R, Lets)]
                  end, Lets),
    Sorted = digraph_utils:topsort(L),
    digraph:delete(L),
    digraph:delete(G),
    lists:reverse(Sorted).

reference_graph(Decls, Env) ->
    Keys = [decl_key(D) || D <- Decls],
    G = digraph:new(),
    lists:foreach(fun(K) -> digraph:add_vertex(G, K) end, Keys),
    lists:foreach(fun(D) ->
                      [digraph:add_edge(G, decl_key(D), Ref)
                       || Ref <- references(D, Env), lists:member(Ref, Keys)]
                  end, Decls),
    G.

let_cycle(#let_decl{pos = Pos, name = Name} = D, G, Errs, Seen) ->
    Key = decl_key(D),
    case lists:member(Key, Seen) of
        true ->
            {Errs, Seen};
        false ->
            case digraph:get_cycle(G, Key) of
                false ->
                    {Errs, Seen};
                Cycle ->
                    Others = [local_name(O, N) || {O, N} <- lists:usort(Cycle), {O, N} =/= Key],
                    Through = case Others of
                                  [] -> "";
                                  _ -> ", through " ++ lists:join(", ", Others)
                              end,
                    Msg = lists:flatten(["the initializer of ", atom_to_list(Name),
                                         " depends on itself", Through]),
                    {[diag(Pos, Msg) | Errs], Cycle ++ Seen}
            end
    end.

%% Unify a placeholder with what the annotations say, before any body. A
%% local fn's annotations name the enclosing definition's variables where
%% they share a name (report §3.9).
signature_shape(#fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect}, V, Env) ->
    {PTs, {AnnVars, St1}} = lists:mapfoldl(fun(#param{type = undefined}, {AV, St}) ->
                                                   {T, St0} = ern_types:fresh(St),
                                                   {T, {AV, St0}};
                                              (#param{type = Syntax}, {AV, St}) ->
                                                   {T, AV1, St0} = ann(Syntax, AV,
                                                                       Env#env{st = St}),
                                                   {T, {AV1, St0}}
                                           end, {Env#env.ann_vars, Env#env.st}, Params),
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
set_decl_type(#foreign_fn_decl{} = D, S) -> D#foreign_fn_decl{type = S};
set_decl_type(D, _) -> D.

check_value(#fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect, body = Body} = D,
            Placeholder, Env) ->
    %% report §3.9: a local fn's signature shares the enclosing one's
    %% variables; at top level there are none
    {TypedParams, ParamTypes, Env1, AnnVars} = bind_params(Params, Env, Env#env.ann_vars),
    {RetT, EffT, AnnVars1, St} = return_annotation(Ret, Effect, AnnVars, Env1),
    FnT = {tfn, ParamTypes, EffT, RetT},
    Env2 = Env1#env{st = mark_process_only(FnT, St), effect = EffT, pending = [], deferred = [],
                    ann_vars = AnnVars1, rigid = maps:to_list(AnnVars1),
                    effect_origin = effect_origin(decl_name(D), Ret, Effect, RetT, EffT, St)},
    Context = ret_context(Ret, "the body does not have the declared return type"),
    {TypedBody, _BodyT, Env4} = check_expr(Body, RetT, Context, ret_origin(Ret, RetT, Env2), Env2),
    Env5 = unify_at(Pos, Placeholder, FnT, Env4, "recursive use does not match the definition"),
    {D#fn_decl{params = TypedParams, body = TypedBody},
     post(Pos, TypedParams, TypedBody, FnT, Env5), restore_scope(Env5, Env)};
check_value(#let_decl{pos = Pos, ann = Ann, body = Body} = D, Placeholder, Env) ->
    {AnnT, AnnVars, St} = case Ann of
                              undefined -> {undefined, #{}, Env#env.st};
                              _ -> {T, VM, S} = ann(Ann, #{}, Env), {T, VM, S}
                          end,
    %% a top-level initializer is pure (report §4.6)
    Env0 = Env#env{st = St, effect = pure, pending = [], deferred = [], ann_vars = AnnVars,
                   rigid = maps:to_list(AnnVars),
                   effect_origin = {"a top-level `let`", Pos, "a top-level `let` is pure",
                                    "compute the value in a function with a mailbox type"}},
    {TypedBody, BodyT, Env2} =
        case AnnT of
            undefined -> infer(Body, Env0);
            _ -> check_expr(Body, AnnT, "the value does not have the declared type",
                            ann_origin(Ann, AnnT, Env0), Env0)
        end,
    Env3 = unify_at(Pos, Placeholder, BodyT, Env2, "recursive use does not match the definition"),
    {D#let_decl{body = TypedBody}, post(Pos, [], TypedBody, BodyT, Env3), restore_scope(Env3, Env)};
check_value(#foreign_fn_decl{pos = Pos, params = Params, ret = Ret, effect = Effect,
                             impl = Impl} = D, Placeholder, Env) ->
    %% report §8.4: the implementation is module:function/arity
    case foreign_impl(Impl) of
        {ok, {_, _, A}} when A =:= length(Params) -> ok;
        {ok, {_, _, A}} ->
            fail(Pos, io_lib:format("the implementation names arity ~B, and ~s has ~B parameter~s",
                                    [A, decl_name(D), length(Params), plural(length(Params))]));
        error ->
            fail(Pos, "the implementation of " ++ decl_name(D)
                      ++ " is named module:function/arity, as \"ets:new/2\"")
    end,
    Syntax = #t_fn{pos = Pos, params = [T || #param{type = T} <- Params], ret = Ret,
                   effect = Effect},
    {T, _, St} = ann(Syntax, #{}, Env),
    Env1 = unify_at(Pos, Placeholder, T, Env#env{st = foreign_effect(T, St)}, "foreign signature"),
    {D, none, Env1}.

%% What the checks after inference need of a definition: its scope as it
%% ends, since a deferred operator calls its member under the definition's
%% own mailbox and adds its restrictions to the definition's (report §4.8,
%% §3.4, §3.10).
post(Pos, TypedParams, TypedBody, T, Env) ->
    {Pos, TypedParams, TypedBody, T, Env#env.effect, Env#env.effect_origin, Env#env.rigid,
     Env#env.pending, Env#env.deferred}.

%% Report §3.9: a foreign fn's effect is its own, and so process-only,
%% unless it is the effect of one of its parameters' function types, where
%% it is that callback's and the function is effect-polymorphic.
foreign_effect({tfn, Ps, {tvar, Id} = E, _}, St) ->
    case lists:any(fun(P) -> parameter_effect(P, Id) end, Ps) of
        true -> St;
        false -> ern_types:add_flag(E, process_only, St)
    end;
foreign_effect(_, St) -> St.

parameter_effect({tfn, _, {tvar, Id}, _}, Id) -> true;
parameter_effect(_, _) -> false.

%% Report §8.4: the implementation name of a foreign fn, module:function/arity.
-spec foreign_impl(binary()) -> {ok, {atom(), atom(), non_neg_integer()}} | error.
foreign_impl(Impl) ->
    case re:run(Impl, "^([a-z][A-Za-z0-9_@]*):([a-z][A-Za-z0-9_]*)/([0-9]+)$",
                [{capture, all_but_first, list}]) of
        {match, [M, F, A]} -> {ok, {list_to_atom(M), list_to_atom(F), list_to_integer(A)}};
        nomatch -> error
    end.

%% Parameters bind pattern variables monomorphically; annotation variables
%% are shared across the parameters and the return annotation.
bind_params(Params, Env, AnnVars) ->
    {Typed, {Env1, AnnVars1}} = lists:mapfoldl(fun bind_param/2, {Env, AnnVars}, Params),
    {TypedParams, Ts} = lists:unzip(Typed),
    {TypedParams, Ts, Env1, AnnVars1}.

bind_param(#param{pos = Pos, pattern = P, type = Ann} = Param, {Env, AnnVars}) ->
    {TypedP, PT, Bindings, Env1} = check_pattern(P, Env),
    irrefutable(P, Env1) orelse fail(Pos, "a parameter pattern must be irrefutable"),
    {AnnVars1, Env2} = case Ann of
                           undefined -> {AnnVars, Env1};
                           _ ->
                               {AT, AV, St} = ann(Ann, AnnVars, Env1),
                               {AV, unify_at(Pos, AT, PT, Env1#env{st = St},
                                             "the parameter pattern does not fit its annotation")}
                       end,
    {{Param#param{pattern = TypedP}, PT}, {bind_vars(Bindings, Env2), AnnVars1}}.

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
    Vals = ern_types:value_vars(Z, St),
    Both = [Id || Id <- ern_types:effect_vars(Z), lists:member(Id, Vals)],
    lists:foldl(fun(Id, S) -> ern_types:add_flag({tvar, Id}, process_only, S) end, St, Both).

%% Report §11.5: the labels an error carries. A return annotation is the
%% origin of the body's expected type; a `with` or a bare `->` is the
%% origin of the function's effect.
ret_context(undefined, _Context) -> undefined;
ret_context(_Ret, Context) -> Context.

ret_origin(undefined, _RetT, _Env) -> undefined;
ret_origin(Ret, RetT, Env) ->
    {node_span(Ret), "declared to return " ++ ern_types:format(RetT, Env#env.st) ++ " here"}.

ann_origin(Ann, AnnT, Env) ->
    {node_span(Ann), "declared " ++ ern_types:format(AnnT, Env#env.st) ++ " here"}.

effect_origin(_Name, undefined, undefined, _RetT, _EffT, _St) -> undefined;
effect_origin(Name, Ret, undefined, RetT, _EffT, St) ->
    {Name, node_span(Ret), "`-> " ++ ern_types:format(RetT, St) ++ "` with no `with` declares "
                           ++ Name ++ " pure", "give " ++ Name ++ " a mailbox type with `with`"};
effect_origin(Name, _Ret, Effect, _RetT, EffT, St) ->
    {Name, node_span(Effect), Name ++ " is declared `with " ++ ern_types:format(EffT, St)
                              ++ "` here", undefined}.

decl_name(D) ->
    {Owner, Name} = decl_key(D),
    local_name(Owner, Name).

node_span(Node) -> element(2, Node).

bind_vars(Bindings, #env{vars = Vs} = Env) ->
    Env#env{vars = lists:foldl(fun({Name, T}, M) -> M#{Name => ern_types:mono(T)} end, Vs,
                               Bindings)}.

%%
%% Post checks per definition
%%

post_checks(none, Env) ->
    Env;
post_checks({Pos, TypedParams, TypedBody, FnT, Effect, Origin, Rigid, Pending, Deferred},
            Env0) ->
    Env1 = solve_deferred(Env0#env{effect = Effect, effect_origin = Origin, pending = Pending,
                                   deferred = Deferred}),
    rigid_annotation_vars(Pos, Rigid, Env1),
    ern_scope:order(TypedBody),
    undetermined_bindings(TypedBody, FnT, Env1),
    ern_exhaust:check(TypedBody, Env1),
    Env2 = ern_reply:check(TypedParams, TypedBody, FnT, Env1),
    no_reply_instantiations(Env2),
    Env2#env{effect = Env0#env.effect, effect_origin = Env0#env.effect_origin,
             pending = Env0#env.pending, deferred = Env0#env.deferred}.

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
            case hd(Left) of
                {bind_arrow, Pos, _, _, _} ->
                    fail(Pos, "`<-` needs to know whether the value is an Either or an"
                              " Optional; annotate it");
                {operator, Pos, Op, _, _} ->
                    %% report §4.8: resolution precedes generalization
                    fail(Pos, "the operand type of `" ++ atom_to_list(Op)
                              ++ "` is not determined; annotate it");
                {select, Pos, F, _, _} ->
                    fail(Pos, "the type whose field " ++ atom_to_list(F)
                              ++ " is read is not determined; annotate it")
            end
    end.

solve_one({select, Pos, F, XT, Res}, Env) ->
    case ern_types:resolve(XT, Env#env.st) of
        {tvar, _} -> unsolved;
        _ ->
            {T0, Env1} = resolve_select(Pos, F, XT, Env),
            %% opened as a selection resolved at once is (report §3.9)
            {T, St} = open_effect(T0, Env1#env.st),
            {solved, unify_at(Pos, Res, T, Env1#env{st = St}, "the field " ++ atom_to_list(F))}
    end;
solve_one({operator, Pos, Op, LT, Res}, Env) ->
    case ern_types:resolve(LT, Env#env.st) of
        {tvar, _} -> unsolved;
        _ ->
            {T0, Env1} = resolve_operator(Pos, Op, LT, Env),
            {T, St} = open_effect(T0, Env1#env.st),
            {solved, unify_at(Pos, Res, T, Env1#env{st = St},
                              "the result of `" ++ op_text(Op) ++ "`")}
    end;
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
                     ({eq, Id, Pos, Need}) ->
                          T = ern_types:zonk({tvar, Id}, Env#env.st),
                          case has_fn_or_address(T) of
                              true -> fail(Pos, ern_types:format(T, Env#env.st)
                                                ++ " does not support equality (it contains"
                                                " a function or an address), " ++ Need);
                              false -> ok
                          end
                  end, Pending).

%% The restrictions an instance of a scheme carries, checked when its
%% definition ends: each no-reply variable, and each equality-constrained
%% one with what needs the equality: a Map's key or a Set's element it
%% stands in, or else a comparison (report §3.10).
instance_pending(T, Pos, St) ->
    [case Flag of
         no_reply -> {no_reply, Id, Pos};
         eq -> {eq, Id, Pos, equality_need(Id, T, St)}
     end || Id <- ern_types:free_vars(T, St), Flag <- ern_types:flags(Id, St),
            Flag =:= no_reply orelse Flag =:= eq].

equality_need(Id, T, St) ->
    case container_of(Id, T, St) of
        map -> "and a Map's key needs it";
        set -> "and a Set's element needs it";
        none -> "but it is compared here"
    end.

container_of(Id, T, St) ->
    case ern_types:resolve(T, St) of
        {tcon, ['Map'], [K, V]} ->
            case lists:member(Id, ern_types:free_vars(K, St)) of
                true -> map;
                false -> container_of(Id, V, St)
            end;
        {tcon, ['Set'], [A]} ->
            case lists:member(Id, ern_types:free_vars(A, St)) of
                true -> set;
                false -> none
            end;
        {tcon, _, Args} -> first_container(Id, Args, St);
        {ttuple, Es} -> first_container(Id, Es, St);
        {tfn, Ps, _, R} -> first_container(Id, Ps ++ [R], St);
        _ -> none
    end.

first_container(_Id, [], _St) -> none;
first_container(Id, [T | Ts], St) ->
    case container_of(Id, T, St) of
        none -> first_container(Id, Ts, St);
        Found -> Found
    end.

%% Report §3.1: a literal's type, in an expression and in a pattern.
lit_type(int) -> ?INT;
lit_type(float) -> ?FLOAT;
lit_type(char) -> ?CHAR;
lit_type(string) -> ?STRING;
lit_type(bool) -> ?BOOL.

%% Report §4.8, §3.10, §5.1: an operator resolves against its operand
%% type as soon as that type is known; an operand still a variable is
%% deferred to the end of the definition, where it must be known. The
%% result: the operand type for Int, Float, and `<>`; Bool for an
%% ordering; a user type's own member, `T.+` or `T.compare`, instantiated
%% and applied to two operands of the type, or `T.negate` to one, since
%% prefix `-` is `negate` in the operand type's namespace (§5.1).
operator_result(Pos, Op, LT, Env) ->
    case ern_types:resolve(LT, Env#env.st) of
        {tvar, _} ->
            {Res, St} = ern_types:fresh(Env#env.st),
            {Res, Env#env{st = St, deferred = [{operator, Pos, Op, LT, Res} | Env#env.deferred]}};
        _ ->
            resolve_operator(Pos, Op, LT, Env)
    end.

%% Report §3.5, §4.8: a field selection resolves against its operand's type
%% as an operator does, deferred while that type is still a variable.
select_result(Pos, F, XT, Env) ->
    case ern_types:resolve(XT, Env#env.st) of
        {tvar, _} ->
            {Res, St} = ern_types:fresh(Env#env.st),
            {Res, Env#env{st = St, deferred = [{select, Pos, F, XT, Res} | Env#env.deferred]}};
        _ ->
            resolve_select(Pos, F, XT, Env)
    end.

%% Report §3.5: the selector f exists where every constructor of the type
%% has a named field f, of one type; an abstract type's fields are its
%% module's (§4.4).
resolve_select(Pos, F, XT, #env{st = St, types = Types, local_types = LT} = Env) ->
    T = ern_types:resolve(XT, St),
    Field = atom_to_list(F),
    Shown = ern_types:format(T, St),
    case T of
        {tcon, Q, _} ->
            Own = maps:get(lists:last(Q), LT, undefined) =:= Q,
            case maps:get(Q, Types, undefined) of
                #tinfo{abstract = true} when not Own ->
                    fail(Pos, Shown ++ " is abstract, and its fields are its module's alone");
                #tinfo{constructors = [_ | _] = Cs} ->
                    field_type(Pos, F, T, Cs, Env);
                _ ->
                    fail(Pos, Shown ++ " has no field " ++ Field)
            end;
        _ ->
            fail(Pos, Shown ++ " has no field " ++ Field)
    end.

field_type(Pos, F, T, Cs, Env) ->
    Shown = ern_types:format(T, Env#env.st),
    lists:any(fun(#cinfo{fields = {named, Ns}}) -> lists:member(F, Ns); (_) -> false end, Cs)
        orelse fail(Pos, Shown ++ " has no field " ++ atom_to_list(F)),
    lists:foldl(
      fun(#cinfo{name = C, fields = Fields, scheme = Scheme}, {FT0, E}) ->
              Names = case Fields of {named, Ns} -> Ns; _ -> [] end,
              case index_of(F, Names) of
                  none ->
                      fail(Pos, Shown ++ " has no field " ++ atom_to_list(F)
                                ++ " in every constructor: " ++ atom_to_list(C) ++ " has none");
                  I ->
                      {{tfn, FTs, pure, RT}, St1} = ern_types:instantiate(Scheme, E#env.st),
                      E1 = unify_at(Pos, T, RT, E#env{st = St1}, "the value whose field "
                                                                  ++ atom_to_list(F) ++ " is read"),
                      FT = lists:nth(I, FTs),
                      E2 = case FT0 of
                               undefined -> E1;
                               _ -> unify_at(Pos, FT0, FT, E1, "the field " ++ atom_to_list(F)
                                                               ++ " in every constructor")
                           end,
                      {FT, E2}
              end
      end, {undefined, Env}, Cs).

index_of(X, L) -> index_of(X, L, 1).
index_of(_, [], _) -> none;
index_of(X, [X | _], I) -> I;
index_of(X, [_ | R], I) -> index_of(X, R, I + 1).

resolve_operator(Pos, Op, LT, #env{st = St} = Env) ->
    T = ern_types:resolve(LT, St),
    case T of
        ?INT when Op =:= negate -> {LT, Env};
        ?FLOAT when Op =:= negate -> {LT, Env};
        ?INT -> arith_or_order(Op, LT, ?ARITH, Pos, Env);
        ?FLOAT -> arith_or_order(Op, LT, ['+', '-', '*', '/'], Pos, Env);
        ?STRING when Op =:= '<>' -> {LT, Env};
        ?STRING -> arith_or_order(Op, LT, [], Pos, Env);
        ?CHAR -> arith_or_order(Op, LT, [], Pos, Env);
        {tcon, ['List'], _} when Op =:= '<>' -> {LT, Env};
        ?BYTES when Op =:= '<>' -> {LT, Env};
        {tcon, Q, _} when length(Q) > 1 -> user_operator(Pos, Op, LT, Q, Env);
        _ -> not_defined(Pos, Op, T, Env)
    end.

arith_or_order(Op, LT, Arith, Pos, Env) ->
    case lists:member(Op, Arith) of
        true -> {LT, Env};
        false ->
            case lists:member(Op, ?ORDER) of
                true -> {?BOOL, Env};
                false -> not_defined(Pos, Op, LT, Env)
            end
    end.

user_operator(Pos, Op, LT, Q, Env0) ->
    Member = case lists:member(Op, ?ORDER) of true -> compare; false -> Op end,
    Name = format_qname([lists:last(Q), Member]),
    case member_scheme(Q, Member, Env0) of
        {undefined, Env} -> not_defined(Pos, Op, LT, Env);
        {Scheme, Env} ->
            {FT, St1} = ern_types:instantiate(Scheme, Env#env.st),
            %% as a reference to the member would, report §3.9
            Pending = instance_pending(FT, Pos, St1),
            {Eff, St2} = ern_types:fresh_effect(St1),
            {Res, St3} = ern_types:fresh(St2),
            {Operands, Context} =
                case Op of
                    negate -> {[LT], Name ++ " does not fit an operand of "};
                    _ -> {[LT, LT], Name ++ " does not fit two operands of "}
                end,
            Env1 = unify_at(Pos, {tfn, Operands, Eff, Res}, FT,
                            Env#env{st = St3, pending = Pending ++ Env#env.pending},
                            Context ++ ern_types:format(LT, St3)),
            Env2 = use_effect(Pos, Name, Eff, Env1),
            case Member of
                compare ->
                    Env3 = unify_at(Pos, {tcon, ['Ordering'], []}, Res, Env2,
                                    Name ++ " must return an Ordering"),
                    {?BOOL, Env3};
                _ ->
                    {Res, Env2}
            end
    end.

not_defined(Pos, Op, T, Env) ->
    fail(Pos, "`" ++ op_text(Op) ++ "` is not defined on " ++ ern_types:format(T, Env#env.st)).

op_text(negate) -> "-";
op_text(Op) -> atom_to_list(Op).

%% The scheme of Member in the type Q: in this module, a local value,
%% checked now if its group has not run; in another, through its compiled
%% interface.
member_scheme(Q, Member, #env{ns = Ns, local_values = LV} = Env) ->
    Key = case own_type_path(Q, Ns) of
              true -> maps:get({lists:last(Q), Member}, LV, undefined);
              false -> session_member(Q, Member, Env)
          end,
    case Key of
        undefined -> {undefined, Env};
        _ ->
            Env1 = demand(Key, Env),
            {maps:get(Key, Env1#env.globals, undefined), Env1}
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
    ern_ast:walk(fun(#binding{pos = Pos, pattern = P}, E) ->
                 lists:foreach(fun({Name, T}) ->
                                   case ern_types:free_vars(T, St) -- Escaping of
                                       [] -> ok;
                                       _ -> fail(Pos, "the type of " ++ atom_to_list(Name)
                                                      ++ " is not determined ("
                                                      ++ ern_types:format(T, St)
                                                      ++ "); use it, or annotate it")
                                   end
                               end, ern_ast:pattern_bindings(P)),
                 E;
            (_, E) -> E
         end, Node, Env),
    ok.

%% Report §11.2: the type of a name as its declaration writes it, for the
%% shell's input that is one name; the scheme keeps the declaration's
%% variable names, which an instance does not.
-spec declared_scheme(env(), [atom()], atom()) -> {ok, #scheme{}} | error.
declared_scheme(Env, Path, Name) ->
    %% the position is never shown: an unknown name answers `error`
    try lookup_value({1, 1, {1, 1}}, Path, Name, Env) of
        {Scheme, _, _} -> {ok, Scheme}
    catch
        throw:{type_error, _, _} -> error
    end.


%%
%% Expressions: infer(Expr, Env) -> {TypedExpr, Type, Env}
%%

%% Report §3.9: a pure function stands where one with a mailbox type is
%% expected, so an expression whose type is a pure function type takes a
%% fresh effect variable in its outermost arrow, which the context binds.
open_effect(T, St) ->
    case ern_types:resolve(T, St) of
        {tfn, Ps, Eff, R} ->
            case ern_types:resolve(Eff, St) of
                pure ->
                    {Fresh, St1} = ern_types:fresh_effect(St),
                    {{tfn, Ps, Fresh, R}, St1};
                _ -> {T, St}
            end;
        _ -> {T, St}
    end.

infer(#e_lit{kind = Kind} = E, Env) ->
    T = lit_type(Kind),
    {E#e_lit{type = T}, T, Env};
infer(#e_var{pos = Pos, path = Path, name = Name} = E, Env0) ->
    %% report §11.2: a name the session declared resolves to the input that
    %% declared it, which its `ref` records; its path stays as written
    {Scheme, Ref, Env} = lookup_value(Pos, Path, Name, Env0),
    {T0, St0} = ern_types:instantiate(Scheme, Env#env.st),
    {T, St} = open_effect(T0, St0),
    Pending = instance_pending(T, Pos, St),
    %% report §4.2: what the name resolved to is recorded, so that the
    %% emitter reads the decision rather than making it again
    {E#e_var{type = T, ref = Ref}, T, Env#env{st = St, pending = Pending ++ Env#env.pending}};
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
            {TypedArg, _AT, Env3} = check_expr(Arg, FT, "the field of " ++ atom_to_list(Name),
                                               undefined, Env1),
            {E#e_con{args = {positional, TypedArg}, type = RT}, RT, Env3};
        {positional, none} ->
            %% a single-positional constructor is a function value (§5.6)
            {OT, St1} = open_effect(CT, St),
            {E#e_con{type = OT}, OT, Env1#env{st = St1}};
        {positional, {named, _, _}} ->
            fail(Pos, atom_to_list(Name) ++ " has one positional field, not named fields");
        {{named, Names}, {named, Base, Sets}} ->
            {tfn, FTs, pure, RT} = CT,
            Base =:= undefined orelse one_constructor(Pos, CI, Env1),
            infer_named(E, Names, FTs, RT, Base, Sets, Env1);
        {{named, _}, _} ->
            fail(Pos, atom_to_list(Name) ++ " has named fields; write "
                      ++ atom_to_list(Name) ++ "(field = value, ...)")
    end;
infer(#e_tuple{elems = Es} = E, Env) ->
    {TypedEs, Ts, Env1} = infer_list(Es, Env),
    T = {ttuple, Ts},
    {E#e_tuple{elems = TypedEs, type = T}, T, Env1};
infer(#e_list{elems = Es} = E, Env) ->
    {ElemT, St} = ern_types:fresh(Env#env.st),
    {TypedEs, {Env1, _}} =
        lists:mapfoldl(fun(X, {En, Origin}) ->
                           {TX, _, En1} = check_expr(X, ElemT,
                                                     "list elements must have one type", Origin,
                                                     En),
                           Origin1 = case Origin of
                                         undefined -> {node_span(X), "the first element has type "
                                                       ++ ern_types:format(ElemT, En1#env.st)};
                                         _ -> Origin
                                     end,
                           {TX, {En1, Origin1}}
                       end, {Env#env{st = St}, undefined}, Es),
    T = {tcon, ['List'], [ElemT]},
    {E#e_list{elems = TypedEs, type = T}, T, Env1};
infer(#e_bits{pos = Pos, segments = Segs} = E, Env) ->
    %% report §5.11
    {TypedSegs, Env1} = lists:mapfoldl(fun(S, En) -> bit_segment(S, construct, En) end, Env,
                                       Segs),
    alignment(Pos, TypedSegs, "the bitstring"),
    {E#e_bits{segments = TypedSegs, type = ?BYTES}, ?BYTES, Env1};
infer(#e_block{pos = Pos, stmts = Stmts} = E, Env) ->
    {TypedStmts, T, Env1} = infer_block(Stmts, Pos, undefined, Env),
    {E#e_block{stmts = TypedStmts, type = T}, T, Env1#env{vars = Env#env.vars}};
infer(#e_call{pos = Pos, callee = Callee, args = Args} = E, Env) ->
    {TypedCallee, CalleeT, Env1} = infer(Callee, Env),
    Name = callee_name(Callee),
    case ern_types:resolve(CalleeT, Env1#env.st) of
        {tfn, Ps, _, _} when length(Ps) =/= length(Args) ->
            fail(Pos, io_lib:format("~s takes ~B argument~s, not ~B",
                                    [Name, length(Ps), plural(length(Ps)), length(Args)]),
                 [], "a call supplies all the arguments");
        {tfn, Ps, Eff, RetT} ->
            Origin = {node_span(Callee), Name ++ " : " ++ ern_types:format(CalleeT, Env1#env.st)},
            {TypedArgs, Env2} =
                lists:mapfoldl(fun({Arg, P}, En) ->
                                   {TA, _, En1} = check_expr(Arg, P, "the argument does not fit "
                                                             ++ Name, Origin, En),
                                   {TA, En1}
                               end, Env1, lists:zip(Args, Ps)),
            Env3 = use_effect(Pos, Name, Eff, Env2),
            {OT, St3} = open_effect(RetT, Env3#env.st),
            {E#e_call{callee = TypedCallee, args = TypedArgs, type = OT}, OT, Env3#env{st = St3}};
        {tvar, _} ->
            {TypedArgs, ArgTs, Env2} = infer_list(Args, Env1),
            {RetT, St} = ern_types:fresh(Env2#env.st),
            {Eff, St1} = ern_types:fresh_effect(St),
            Env3 = unify_at(Pos, CalleeT, {tfn, ArgTs, Eff, RetT}, Env2#env{st = St1},
                            "not a function"),
            Env4 = use_effect(Pos, Name, Eff, Env3),
            {E#e_call{callee = TypedCallee, args = TypedArgs, type = RetT}, RetT, Env4};
        Other ->
            fail(Pos, Name ++ " is not a function; it has type "
                      ++ ern_types:format(Other, Env1#env.st))
    end;
infer(#e_not{pos = Pos, expr = X} = E, Env) ->
    %% report §4.8: `!` is Bool's, as `&&` and `||` are
    {TypedX, XT, Env1} = infer(X, Env),
    Env2 = unify_at(Pos, ?BOOL, XT, Env1, "the operand of `!`"),
    {E#e_not{expr = TypedX, type = ?BOOL}, ?BOOL, Env2};
infer(#e_select{pos = Pos, expr = X, field = F} = E, Env) ->
    {TypedX, XT, Env1} = infer(X, Env),
    {T0, Env2} = select_result(Pos, F, XT, Env1),
    {T, St} = open_effect(T0, Env2#env.st),
    {E#e_select{expr = TypedX, type = T}, T, Env2#env{st = St}};
infer(#e_neg{pos = Pos, expr = X} = E, Env) ->
    {TypedX, XT, Env1} = infer(X, Env),
    {T0, Env2} = operator_result(Pos, negate, XT, Env1),
    {T, St} = open_effect(T0, Env2#env.st),
    {E#e_neg{expr = TypedX, type = T}, T, Env2#env{st = St}};
infer(#e_binop{pos = Pos, op = Op, left = L, right = R} = E, Env) ->
    {TypedL, LT, Env1} = infer(L, Env),
    {TypedR, RT, Env2} = infer(R, Env1),
    {T0, Env3} = binop_type(Pos, Op, L, LT, R, RT, Env2),
    {T, St} = open_effect(T0, Env3#env.st),
    {E#e_binop{left = TypedL, right = TypedR, type = T}, T, Env3#env{st = St}};
infer(#e_lambda{params = Params, ret = Ret, effect = Effect, body = Body} = E,
      Env) ->
    {TypedParams, ParamTypes, Env1, AnnVars} = bind_params(Params, Env, Env#env.ann_vars),
    {RetT, EffT, AnnVars1, St} = return_annotation(Ret, Effect, AnnVars, Env1),
    T = {tfn, ParamTypes, EffT, RetT},
    %% the definition's annotation variables are in scope and rigid; a
    %% name new here is the lambda's own and not rigid (report §3.9)
    Env2 = Env1#env{st = mark_process_only(T, St), effect = EffT, ann_vars = AnnVars1,
                    %% report §11.5: the label names the annotation that fixed the
                    %% mailbox, and an unannotated lambda's is its own, not the
                    %% enclosing definition's
                    effect_origin = effect_origin("the lambda", Ret, Effect, RetT, EffT, St)},
    Context = ret_context(Ret, "the lambda body does not have the declared type"),
    {TypedBody, _BodyT, Env4} = check_expr(Body, RetT, Context, ret_origin(Ret, RetT, Env2), Env2),
    %% the body was checked as the annotation says; a lambda written pure
    %% stands where one with a mailbox type is expected, as any expression
    %% of a pure function type does (report §3.9)
    {OT, St4} = open_effect(T, Env4#env.st),
    {E#e_lambda{params = TypedParams, body = TypedBody, type = T}, OT,
     Env4#env{st = St4, vars = Env#env.vars, effect = Env#env.effect, ann_vars = Env#env.ann_vars,
              effect_origin = Env#env.effect_origin}};
infer(E, Env) when is_record(E, e_if); is_record(E, e_match); is_record(E, e_receive) ->
    {T, St} = ern_types:fresh(Env#env.st),
    check_expr(E, T, undefined, undefined, Env#env{st = St}).

%% Report §11.5: an expression checked against an expected type. The
%% expectation is pushed into branches, clauses, and a block's last
%% statement, so a mismatch is reported at the leaf; Context names the
%% rule and Origin the span that fixed the expectation, or undefined when
%% it is the first branch, which then becomes the origin for the rest.
check_expr(#e_if{condition = C, then_branch = Th, else_branch = El} = E, Expected, Context,
           Origin, Env) ->
    {TypedC, _, Env1} = check_expr(C, ?BOOL, "the condition of `if`", undefined, Env),
    {TypedTh, _, Env2} = check_expr(Th, Expected, Context, Origin, Env1),
    {Context1, Origin1} = sibling(Context, Origin, "the branches of `if` must have one type",
                                  Th, "the then branch", Expected, Env2),
    {TypedEl, _, Env3} = check_expr(El, Expected, Context1, Origin1, Env2),
    {E#e_if{condition = TypedC, then_branch = TypedTh, else_branch = TypedEl, type = Expected},
     Expected, Env3};
check_expr(#e_match{scrutinee = S, clauses = Clauses} = E, Expected, Context, Origin, Env) ->
    {TypedS, ST, Env1} = infer(S, Env),
    ScrutOrigin = {node_span(S), "the value matched has type "
                                 ++ ern_types:format(ST, Env1#env.st)},
    {TypedClauses, Env2} = check_clauses(match, Clauses, ST, ScrutOrigin, Expected, Context, Origin,
                                         "the clauses must have one type", Env1),
    {E#e_match{scrutinee = TypedS, clauses = TypedClauses, type = Expected}, Expected, Env2};
check_expr(#e_receive{pos = Pos, clauses = Clauses, 'after' = After} = E, Expected, Context,
           Origin, Env) ->
    {MailboxT, Env1} = mailbox_type(Pos, Env),
    case Clauses =/= [] andalso ern_types:resolve(MailboxT, Env1#env.st) =:= ?NEVER of
        true -> fail(Pos, "a function with mailbox Never cannot receive", [],
                     "only an `after` clause is allowed; give the function another mailbox"
                     " type with `with`");
        false -> ok
    end,
    {TypedClauses, Env2} = check_clauses(rcv, Clauses, MailboxT, undefined, Expected, Context,
                                         Origin, "the clauses must have one type", Env1),
    {TypedAfter, Env3} =
        case After of
            undefined -> {undefined, Env2};
            #after_clause{timeout = Timeout, body = Body} = A ->
                {TypedTimeout, _, En1} = check_expr(Timeout, ?INT, "the `after` time is in"
                                                    " milliseconds", undefined, Env2),
                {Context1, Origin1} =
                    case {Clauses, Origin} of
                        {[#clause{body = First} | _], undefined} ->
                            sibling(Context, Origin, "the `after` body must have the clauses'"
                                    " type", First, "the first clause", Expected, En1);
                        _ -> {default(Context, "the `after` body"), Origin}
                    end,
                {TypedBody, _, En3} = check_expr(Body, Expected, Context1, Origin1, En1),
                {A#after_clause{timeout = TypedTimeout, body = TypedBody}, En3}
        end,
    {E#e_receive{clauses = TypedClauses, 'after' = TypedAfter, type = Expected}, Expected, Env3};
check_expr(#e_block{pos = Pos, stmts = Stmts} = E, Expected, Context, Origin, Env) ->
    {TypedStmts, T, Env1} = infer_block(Stmts, Pos, {Expected, Context, Origin}, Env),
    {E#e_block{stmts = TypedStmts, type = T}, T, Env1#env{vars = Env#env.vars}};
check_expr(E, Expected, Context, Origin, Env) ->
    {Typed, T, Env1} = infer(E, Env),
    Env2 = unify_at(node_span(E), Expected, T, Env1, default(Context, "this expression"),
                    Origin),
    {Typed, T, Env2}.

%% Report §6.3: a receive guard is a guard expression, since it selects a
%% message without removing it: `true`, `false`, a Bool operand, or a
%% comparison of two operands, under `!`, `&&`, and `||`. The guard is
%% already a Bool, so a bare operand is a Bool one.
receive_guard(#e_binop{op = Op, left = L, right = R}, Env) when Op =:= '&&'; Op =:= '||' ->
    receive_guard(L, Env),
    receive_guard(R, Env);
receive_guard(#e_binop{op = Op, left = L, right = R}, Env) when Op =:= '=='; Op =:= '!=' ->
    guard_operand(L, Env),
    guard_operand(R, Env);
receive_guard(#e_binop{pos = Pos, op = Op, left = L, right = R}, Env)
  when Op =:= '<'; Op =:= '<='; Op =:= '>'; Op =:= '>=' ->
    case ern_types:resolve(node_type(L), Env#env.st) of
        T when T =:= ?INT; T =:= ?FLOAT; T =:= ?STRING; T =:= ?CHAR -> ok;
        T -> fail(Pos, "a `receive` guard orders only Int, Float, String, and Char, not "
                       ++ ern_types:format(T, Env#env.st))
    end,
    guard_operand(L, Env),
    guard_operand(R, Env);
receive_guard(#e_not{expr = X}, Env) -> receive_guard(X, Env);
receive_guard(#e_lit{kind = bool}, _) -> ok;
receive_guard(#e_var{} = V, Env) -> guard_operand(V, Env);
receive_guard(G, _) ->
    fail(node_span(G), "a `receive` guard combines `true`, `false`, Bool variables, and"
                       " comparisons with `!`, `&&`, and `||`, and calls nothing",
         [], "receive the message and `match` it").

%% An operand: a variable of the pattern or of the enclosing function, a
%% literal, a negative numeric literal, or a nullary constructor.
guard_operand(#e_lit{}, _) -> ok;
guard_operand(#e_neg{expr = #e_lit{kind = K}}, _) when K =:= int; K =:= float -> ok;
guard_operand(#e_con{args = none}, _) -> ok;
guard_operand(#e_var{path = [], name = N}, #env{vars = Vs}) when is_map_key(N, Vs) -> ok;
guard_operand(#e_var{} = V, _) ->
    fail(node_span(V), callee_name(V) ++ " is bound at top level, and a `receive` guard reads"
                                         " only the function's variables",
         [], "bind its value to a variable before the `receive`");
guard_operand(X, _) ->
    fail(node_span(X), "a comparison in a `receive` guard compares variables, literals, and"
                       " nullary constructors",
         [], "receive the message and `match` it").

%% After the first branch, the expectation's origin is that branch when
%% nothing outside fixed it.
sibling(Context, undefined, SiblingContext, First, What, Expected, Env) ->
    {default(Context, SiblingContext),
     {node_span(First), What ++ " has type " ++ ern_types:format(Expected, Env#env.st)}};
sibling(Context, Origin, _SiblingContext, _First, _What, _Expected, _Env) ->
    {Context, Origin}.

default(undefined, Text) -> Text;
default(Context, _) -> Context.

infer_list(Es, Env) ->
    {Typed, Env1} = lists:mapfoldl(fun(X, En) ->
                                       {TX, XT, En1} = infer(X, En),
                                       {{TX, XT}, En1}
                                   end, Env, Es),
    {TypedEs, Ts} = lists:unzip(Typed),
    {TypedEs, Ts, Env1}.

callee_name(#e_var{path = Path, name = Name}) -> format_qname(Path ++ [Name]);
callee_name(_) -> "the callee".

%% A callee's effect: pure constrains nothing; anything else is the
%% enclosing function's effect.
use_effect(Pos, Name, Eff, #env{st = St, effect = Have, effect_origin = Origin} = Env) ->
    case ern_types:resolve(Eff, St) of
        pure -> Env;
        _ ->
            case ern_types:unify(Have, Eff, St) of
                {ok, St1} ->
                    Env#env{st = St1};
                {error, {mismatch, _, _}} ->
                    fail(Pos, Name ++ " needs mailbox " ++ ern_types:format(Eff, St)
                              ++ ", and the mailbox here is " ++ ern_types:format(Have, St),
                         labels(Origin), undefined);
                {error, _Reason} ->
                    fail(Pos, Name ++ " needs a process, and " ++ what(Origin) ++ " is pure",
                         labels(Origin), help(Origin))
            end
    end.

labels(undefined) -> [];
labels({Span, Label}) -> [{ern_diag:span(Span), Label}];
labels({_What, Span, Label, _Help}) -> [{ern_diag:span(Span), Label}].

what(undefined) -> "this function";
what({What, _, _, _}) -> What.

help(undefined) -> "give the function a mailbox type with `with`";
help({_, _, _, Help}) -> Help.

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

%% Report §5.6: `..` takes the unlisted fields from a value that has them,
%% so its type has one constructor.
one_constructor(Pos, #cinfo{name = Name, type_qname = TQ}, #env{types = Ts} = Env) ->
    case maps:get(TQ, Ts) of
        #tinfo{constructors = [_]} ->
            true;
        #tinfo{constructors = Cs} ->
            fail(Pos, io_lib:format("`..` is allowed only on a type with one constructor, and"
                                    " ~s has ~B", [ern_types:format({tcon, TQ, []}, Env#env.st),
                                                   length(Cs)]),
                 [], "give every field of " ++ atom_to_list(Name))
    end.

binop_type(Pos, Op, L, LT, R, RT, Env) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/';
                                            Op =:= '%'; Op =:= '<>' ->
    operator_result(Pos, Op, LT, same_operands(Op, L, LT, R, RT, Env));
binop_type(Pos, Op, L, LT, R, RT, Env) when Op =:= '=='; Op =:= '!=' ->
    Env1 = same_operands(Op, L, LT, R, RT, Env),
    Env2 = equality_constraint(Pos, LT, Env1),
    {?BOOL, Env2};
binop_type(Pos, Op, L, LT, R, RT, Env) when Op =:= '<'; Op =:= '<='; Op =:= '>'; Op =:= '>=' ->
    operator_result(Pos, Op, LT, same_operands(Op, L, LT, R, RT, Env));
binop_type(_Pos, Op, L, LT, R, RT, Env) when Op =:= '&&'; Op =:= '||' ->
    Env1 = unify_at(node_span(L), ?BOOL, LT, Env, "the left operand of `" ++ atom_to_list(Op)
                                                 ++ "`"),
    Env2 = unify_at(node_span(R), ?BOOL, RT, Env1, "the right operand of `" ++ atom_to_list(Op)
                                                  ++ "`"),
    {?BOOL, Env2};
binop_type(_Pos, '::', L, LT, R, RT, Env) ->
    ListT = {tcon, ['List'], [LT]},
    Env1 = unify_at(node_span(R), ListT, RT, Env, "the right operand of `::` must be a list of"
                                                 " the left operand's type",
                    {node_span(L), "the left operand has type "
                                   ++ ern_types:format(LT, Env#env.st)}),
    {ListT, Env1}.

same_operands(Op, L, LT, R, RT, Env) ->
    unify_at(node_span(R), LT, RT, Env, "both operands of `" ++ atom_to_list(Op)
                                        ++ "` must have the same type",
             {node_span(L), "the left operand has type " ++ ern_types:format(LT, Env#env.st)}).

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
        pure -> fail(Pos, "`receive` needs a process, and " ++ what(Env#env.effect_origin)
                          ++ " is pure",
                     labels(Env#env.effect_origin), help(Env#env.effect_origin));
        {tvar, _} = V ->
            {M, St} = ern_types:fresh(Env#env.st, [process_only]),
            Env1 = unify_at(Pos, V, M, Env#env{st = St}, "receive"),
            {M, Env1};
        T ->
            {T, Env}
    end.

check_clauses(Kind, Clauses, ScrutT, ScrutOrigin, Expected, Context, Origin, SiblingContext, Env) ->
    {Typed, {Env1, _, _}} =
        lists:mapfoldl(
          fun(#clause{pattern = P, guard = G, body = B} = C, {En, Ctx, Or}) ->
                  {TypedP, PT, Bindings, En1} = check_pattern(P, En),
                  En2 = unify_at(node_span(P), ScrutT, PT, En1,
                                 "the pattern does not fit the value", ScrutOrigin),
                  En3 = bind_vars(Bindings, alternatives_agree(TypedP, En2)),
                  {TypedG, En4} =
                      case G of
                          undefined -> {undefined, En3};
                          _ ->
                              %% a guard is pure (report §5.9)
                              Guarded = En3#env{effect = pure,
                                                effect_origin = {"a guard", node_span(G),
                                                                 "a guard is pure (report §5.9)",
                                                                 "compute the value before"
                                                                 " the match"}},
                              {TG, _, En3a} = check_expr(G, ?BOOL, "a guard is a Bool",
                                                         undefined, Guarded),
                              case Kind of
                                  rcv -> receive_guard(TG, En3a);
                                  match -> ok
                              end,
                              {TG, En3a#env{effect = En3#env.effect,
                                            effect_origin = En3#env.effect_origin}}
                      end,
                  {TypedB, _, En5} = check_expr(B, Expected, Ctx, Or, En4),
                  {Ctx1, Or1} = sibling(Ctx, Or, SiblingContext, B, "the first clause", Expected,
                                        En5),
                  {C#clause{pattern = TypedP, guard = TypedG, body = TypedB},
                   {En5#env{vars = En#env.vars}, Ctx1, Or1}}
          end, {Env, Context, Origin}, Clauses),
    {Typed, Env1}.

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
infer_block(Stmts, Pos, Expect, Env) ->
    Fns = [S || #fn_decl{} = S <- Stmts],
    FnNames = [N || #fn_decl{name = N} <- Fns],
    one_local_fn(Fns, []),
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
    Deps = maps:from_list([{N, ern_scope:free_refs(B, Params, FnNames) -- [N]}
                           || #fn_decl{name = N, params = Params, body = B} <- Fns]),
    Local = #{placeholders => maps:from_list(Placeholders), deps => Deps,
              checked => [], waiting => []},
    {Typed, T, Env2} = infer_stmts(Stmts, Pos, Expect, Env1a, Local, []),
    %% every fn is generalized by now; put the schemes on the nodes
    Typed1 = [case S of
                  #fn_decl{name = N} -> S#fn_decl{type = maps:get(N, Env2#env.vars)};
                  _ -> S
              end || S <- Typed],
    {Typed1, T, Env2}.

%% Report §4.2, §5.4: a block declares each local fn name once, as a
%% module declares each top-level name once.
one_local_fn([], _Seen) ->
    ok;
one_local_fn([#fn_decl{pos = Pos, name = N} | Rest], Seen) ->
    lists:member(N, Seen) andalso
        fail(Pos, "local function " ++ atom_to_list(N) ++ " is declared twice in the block"),
    one_local_fn(Rest, [N | Seen]).

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

infer_stmts([Last], _Pos, Expect, Env, _Fns, Acc) ->
    case Last of
        #binding{} -> fail(element(2, Last), "a block ends with an expression");
        #fn_decl{} -> fail(element(2, Last), "a block ends with an expression");
        _ ->
            {Typed, T, Env1} = case Expect of
                                   undefined -> infer(Last, Env);
                                   {Ex, Ctx, Or} -> check_expr(Last, Ex, Ctx, Or, Env)
                               end,
            {lists:reverse([Typed | Acc]), T, Env1}
    end;
infer_stmts([#fn_decl{pos = FPos, owner = Owner} | _], _Pos, _Expect, _Env, _Fns, _Acc)
  when Owner =/= undefined ->
    fail(FPos, "a type-member name, `fn " ++ atom_to_list(Owner) ++ ".name`, is a top-level"
               " form; a local function has a plain name");
infer_stmts([#fn_decl{name = N} = D | Rest], Pos, Expect, Env, Local, Acc) ->
    V = maps:get(N, maps:get(placeholders, Local)),
    Env1 = Env#env{st = ern_types:enter(Env#env.st)},
    {TypedD, Post, Env2a} = check_value(D, V, Env1),
    Env2 = post_checks(Post, Env2a),
    Env3 = Env2#env{st = ern_types:leave(Env2#env.st)},
    Local1 = Local#{checked => [N | maps:get(checked, Local)],
                    waiting => [N | maps:get(waiting, Local)]},
    {Env4, Local2} = release(Env3, Local1),
    infer_stmts(Rest, Pos, Expect, Env4, Local2, [TypedD | Acc]);
infer_stmts([#binding{pos = BPos, pattern = P, ann = Ann, op = '=', expr = X} = B | Rest],
            Pos, Expect, Env, Fns, Acc) ->
    {TypedX, XT, Env1} =
        case Ann of
            undefined -> infer(X, Env);
            _ ->
                %% the definition's annotation variables are in scope and
                %% rigid; a name new here is the binding's own (report §3.9)
                {AT, _, St} = ann(Ann, Env#env.ann_vars, Env),
                En = Env#env{st = St},
                check_expr(X, AT, "the value does not have the declared type",
                           ann_origin(Ann, AT, En), En)
        end,
    {TypedP, PT, Bindings, Env2} = check_pattern(P, Env1),
    irrefutable(P, Env2) orelse fail(BPos, "a `let` pattern must be irrefutable", [],
                                     "use `match` for a pattern that can fail"),
    Env3 = unify_at(node_span(P), PT, XT, Env2, "the pattern does not fit the value",
                    {node_span(X), "the value has type " ++ ern_types:format(XT, Env2#env.st)}),
    Env5 = bind_vars(Bindings, Env3),
    infer_stmts(Rest, Pos, Expect, Env5, Fns, [B#binding{pattern = TypedP, expr = TypedX} | Acc]);
infer_stmts([#binding{pos = BPos, pattern = P, ann = Ann, op = '<-', expr = X} = B | Rest],
            Pos, Expect, Env, Fns, Acc) ->
    %% report §5.5: e : Either(err, a) binds p : a; the rest is Either(err, _).
    %% Which sum type is decided at the end of the definition (solve_deferred).
    {TypedX, XT, Env1} = infer(X, Env),
    {TypedP, PT, Bindings, Env2} = check_pattern(P, Env1),
    irrefutable(P, Env2) orelse fail(BPos, "a `let` pattern must be irrefutable; use match"),
    Env3 = case Ann of
               undefined -> Env2;
               _ ->
                   {AT, _, St} = ann(Ann, Env2#env.ann_vars, Env2),
                   unify_at(BPos, AT, PT, Env2#env{st = St}, "the value does not have the"
                                                             " declared type")
           end,
    Env4 = bind_vars(Bindings, Env3),
    {TypedRest, RestT, Env5} = infer_stmts(Rest, Pos, Expect, Env4, Fns, []),
    Env6 = Env5#env{deferred = [{bind_arrow, BPos, XT, PT, RestT} | Env5#env.deferred]},
    {lists:reverse(Acc) ++ [B#binding{pattern = TypedP, expr = TypedX} | TypedRest], RestT, Env6};
infer_stmts([X | Rest], Pos, Expect, Env, Fns, Acc) ->
    {TypedX, T, Env1} = infer(X, Env),
    Env2 = statement_unit(X, T, Env1),
    infer_stmts(Rest, Pos, Expect, Env2, Fns, [TypedX | Acc]).

%% Report §5.4: an expression that is not a block's last statement has type
%% Unit, so no value is dropped unseen; §11.5 reports it whole.
statement_unit(X, T, #env{st = St} = Env) ->
    case ern_types:unify(?UNIT, T, St) of
        {ok, St1} -> Env#env{st = St1};
        {error, _} ->
            fail(node_span(X), "this statement's value is discarded: expected Unit, found "
                               ++ ern_types:format(T, St), [],
                 "`let _ = ...` discards it on purpose")
    end.

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

%% Report §5.9: the alternatives bind each variable at one type, checked
%% once the clause's pattern has met the value's type.
alternatives_agree(#p_or{alts = [First | Rest]}, Env) ->
    Bindings = ern_ast:pattern_bindings(First),
    lists:foldl(fun(A, En) ->
                    lists:foldl(fun({N, TN}, E) ->
                                    {N, TF} = lists:keyfind(N, 1, Bindings),
                                    unify_at(node_span(A), TF, TN, E,
                                             "the alternatives bind `" ++ atom_to_list(N)
                                             ++ "` at one type", undefined)
                                end, En, ern_ast:pattern_bindings(A))
                end, Env, Rest);
alternatives_agree(_, Env) ->
    Env.

alternatives_differ(Pos, Names, NamesA) ->
    Text = case Names -- NamesA of
               [N | _] -> "`" ++ atom_to_list(N) ++ "` is bound by the first alternative"
                          " and not by this one";
               [] -> [N | _] = NamesA -- Names,
                     "`" ++ atom_to_list(N) ++ "` is bound by this alternative and not by"
                     " the first"
           end,
    fail(Pos, "the alternatives of a clause bind different variables: " ++ Text).

pat(#p_wild{} = P, Env) ->
    {T, St} = ern_types:fresh(Env#env.st),
    {P#p_wild{type = T}, T, [], Env#env{st = St}};
pat(#p_var{name = N} = P, Env) ->
    {T, St} = ern_types:fresh(Env#env.st),
    {P#p_var{type = T}, T, [{N, T}], Env#env{st = St}};
pat(#p_lit{kind = Kind} = P, Env) ->
    T = lit_type(Kind),
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
            {Typed, Env2} =
                lists:mapfoldl(
                  fun(#field_pat{pos = FPos, name = N, pattern = Sub} = FP, En) ->
                          lists:member(N, Names) orelse
                              fail(FPos, atom_to_list(Name) ++ " has no field "
                                         ++ atom_to_list(N)),
                          FT = lists:nth(index_of(N, Names), FTs),
                          {TypedSub, SubT, SubBs, En1} = pat(Sub, En),
                          En2 = unify_at(FPos, FT, SubT, En1, "field " ++ atom_to_list(N)),
                          {{FP#field_pat{pattern = TypedSub}, SubBs}, En2}
                  end, Env1, FieldPats),
            {TypedFPs, Bs} = lists:unzip(Typed),
            {P#p_con{args = {named, TypedFPs}, type = RT}, RT, lists:append(Bs), Env2};
        {{named, _}, none} ->
            {tfn, _, pure, RT} = CT,
            {P#p_con{type = RT}, RT, [], Env1};
        {{named, _}, _} ->
            fail(Pos, atom_to_list(Name) ++ " has named fields; write "
                      ++ atom_to_list(Name) ++ "(field = p, ...)")
    end;
pat(#p_tuple{elems = Es} = P, Env) ->
    {Typed, Env1} = lists:mapfoldl(fun(E, En) ->
                                       {TE, T, B, En1} = pat(E, En),
                                       {{TE, T, B}, En1}
                                   end, Env, Es),
    {TypedEs, Ts, Bs} = lists:unzip3(Typed),
    T = {ttuple, Ts},
    {P#p_tuple{elems = TypedEs, type = T}, T, lists:append(Bs), Env1};
pat(#p_list{pos = Pos, elems = Es} = P, Env) ->
    {ElemT, St} = ern_types:fresh(Env#env.st),
    {Typed, Env1} = lists:mapfoldl(fun(E, En) ->
                                       {TE, T, B, En1} = pat(E, En),
                                       En2 = unify_at(Pos, ElemT, T, En1,
                                                      "list elements must have one type"),
                                       {{TE, B}, En2}
                                   end, Env#env{st = St}, Es),
    {TypedEs, Bs} = lists:unzip(Typed),
    T = {tcon, ['List'], [ElemT]},
    {P#p_list{elems = TypedEs, type = T}, T, lists:append(Bs), Env1};
pat(#p_cons{pos = Pos, head = H, tail = Tl} = P, Env) ->
    {TypedH, HT, HBs, Env1} = pat(H, Env),
    {TypedTl, TlT, TlBs, Env2} = pat(Tl, Env1),
    T = {tcon, ['List'], [HT]},
    Env3 = unify_at(Pos, T, TlT, Env2, "the tail of `::` must be a list of the head's type"),
    {P#p_cons{head = TypedH, tail = TypedTl, type = T}, T, HBs ++ TlBs, Env3};
pat(#p_as{pattern = Sub, name = N} = P, Env) ->
    {TypedSub, T, Bs, Env1} = pat(Sub, Env),
    {P#p_as{pattern = TypedSub, type = T}, T, Bs ++ [{N, T}], Env1};
pat(#p_or{alts = [First | Rest]} = P, Env) ->
    %% report §5.9: every alternative binds the same variables at the same types
    {TypedFirst, T, Bindings, Env1} = check_pattern(First, Env),
    Names = lists:sort([N || {N, _} <- Bindings]),
    {TypedRest, Env2} =
        lists:mapfoldl(
          fun(A, En) ->
                  {TA, TT, BA, En1} = check_pattern(A, En),
                  En2 = unify_at(node_span(A), T, TT, En1,
                                 "the alternatives of a clause match one type", undefined),
                  NamesA = lists:sort([N || {N, _} <- BA]),
                  NamesA =:= Names orelse alternatives_differ(element(2, A), Names, NamesA),
                  {TA, En2}
          end, Env1, Rest),
    {P#p_or{alts = [TypedFirst | TypedRest], type = T}, T, Bindings, Env2};
pat(#p_bits{pos = Pos, segments = Segs} = P, Env) ->
    %% report §5.11: each segment pattern in turn, the size expressions in
    %% the scope of the earlier segments' variables
    {TypedSegs, {Bindings, Env1}} =
        lists:mapfoldl(fun(S, {Bs, En}) ->
                           {TS, SBs, En1} = bit_pattern(S, Bs, En),
                           {TS, {Bs ++ SBs, En1}}
                       end, {[], Env}, Segs),
    alignment(Pos, TypedSegs, "the pattern"),
    last_sizeless(TypedSegs),
    {P#p_bits{segments = TypedSegs, type = ?BYTES}, ?BYTES, Bindings, Env1}.

%% Report §5.11: a segment's value against its specifiers' type.
bit_segment(#bit_seg{pos = Pos, value = V, specs = Specs} = S, construct, Env) ->
    Spec = spec_of(Pos, Specs),
    {TypedSpecs, Env1} = size_expr(Specs, Env),
    {TypedV, _, Env2} = check_expr(V, segment_type(Spec), segment_context(Spec), undefined,
                                   Env1),
    {S#bit_seg{value = TypedV, specs = TypedSpecs}, Env2}.

bit_pattern(#bit_seg{pos = Pos, value = V, specs = Specs} = S, Bindings, Env) ->
    Spec = spec_of(Pos, Specs),
    case V of
        #p_var{} -> ok;
        #p_wild{} -> ok;
        #p_lit{} -> ok;
        _ -> fail(element(2, V), "a segment pattern is a variable, `_`, or a literal")
    end,
    %% a size expression is pure and sees the earlier segments (report §5.11)
    Scoped = bind_vars(Bindings, Env#env{effect = pure,
                                         effect_origin = {"a size expression", Pos,
                                                          "a size expression is pure",
                                                          "compute the size before the match"}}),
    {TypedSpecs, Scoped1} = size_expr(Specs, Scoped),
    lists:foreach(fun({size, E}) -> size_shape(E, Scoped1); (_) -> ok end, TypedSpecs),
    Env1 = Scoped1#env{vars = Env#env.vars, effect = Env#env.effect,
                       effect_origin = Env#env.effect_origin},
    {TypedV, VT, Bs, Env2} = pat(V, Env1),
    Env3 = unify_at(element(2, V), segment_type(Spec), VT, Env2, segment_context(Spec)),
    {S#bit_seg{value = TypedV, specs = TypedSpecs}, Bs, Env3}.

size_expr(Specs, Env) ->
    lists:mapfoldl(fun({size, E}, En) ->
                           {TE, _, En1} = check_expr(E, ?INT, "the size of a segment",
                                                     undefined, En),
                           {{size, TE}, En1};
                      (Other, En) ->
                           {Other, En}
                   end, Env, Specs).

%% Report §5.11: a size in a pattern is a variable, a literal, or +, -, * of
%% them, since the runtime evaluates it while matching.
size_shape(E, Env) ->
    size_expression(E, Env) orelse
        fail(node_span(E), "a size in a pattern is a variable, an Int literal, or `+`, `-`, `*`"
                           " of them").

size_expression(#e_lit{kind = int}, _) -> true;
size_expression(#e_var{path = [], name = N}, #env{vars = Vs}) -> maps:is_key(N, Vs);
size_expression(#e_neg{expr = E}, Env) -> size_expression(E, Env);
size_expression(#e_binop{op = Op, left = L, right = R}, Env) when Op =:= '+'; Op =:= '-';
                                                                Op =:= '*' ->
    size_expression(L, Env) andalso size_expression(R, Env);
size_expression(_, _) -> false.

segment_type(#{kind := int}) -> ?INT;
segment_type(#{kind := float}) -> ?FLOAT;
segment_type(#{kind := K}) when K =:= utf8; K =:= utf16; K =:= utf32 -> ?CHAR;
segment_type(_) -> ?BYTES.

segment_context(#{kind := K}) when K =:= int; K =:= utf8; K =:= utf16; K =:= utf32 ->
    "an `" ++ atom_to_list(K) ++ "` segment";
segment_context(#{kind := K}) -> "a `" ++ atom_to_list(K) ++ "` segment".

spec_of(Pos, Specs) ->
    case ern_bitspec:spec(Specs) of
        {ok, Spec} -> Spec;
        {error, Msg} -> fail(Pos, Msg)
    end.

%% Report §5.11: a bit count that is constant and not a multiple of 8 is
%% an error. A segment with a dynamic size and a unit that is not a
%% multiple of 8 leaves the count open; every other segment keeps it.
alignment(Pos, Segs, What) ->
    {Bits, Open} = lists:foldl(fun(#bit_seg{specs = Specs}, {B, O}) ->
                                   {ok, #{size := Size, unit := Unit}} = ern_bitspec:spec(Specs),
                                   case Size of
                                       {const, N} -> {B + N * Unit, O};
                                       {expr, _} when Unit rem 8 =:= 0 -> {B, O};
                                       {expr, _} -> {B, true};
                                       none -> {B, O}
                                   end
                               end, {0, false}, Segs),
    case not Open andalso Bits rem 8 =/= 0 of
        true -> fail(Pos, What ++ " is " ++ integer_to_list(Bits) ++ " bits, not a multiple of 8");
        false -> ok
    end.

%% A `bytes` segment without a size takes the rest, so it is last.
last_sizeless([]) -> ok;
last_sizeless([_]) -> ok;
last_sizeless([#bit_seg{pos = Pos, specs = Specs} | Rest]) ->
    case ern_bitspec:spec(Specs) of
        {ok, #{kind := bytes, size := none}} ->
            fail(Pos, "a `bytes` segment without a size takes the rest, so it is the last"
                      " segment");
        _ -> last_sizeless(Rest)
    end.

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

%% A name's scheme, what it refers to (the `ref` of #e_var{}), and the
%% environment, since a local name whose group has not run is checked on
%% demand.
lookup_value(Pos, [], Name, #env{vars = Vs, local_values = LV} = Env) ->
    case Vs of
        #{Name := Scheme} -> {Scheme, var, Env};
        _ ->
            case LV of
                #{Name := Q} -> local_global(Q, Env);
                _ ->
                    case session(values, Name, Env) of
                        {ok, Q} -> session_global(Q, Name, Env);
                        error ->
                            case Env#env.globals of
                                #{[Name] := Scheme} -> {Scheme, {prelude, [Name]}, Env};
                                _ -> fail(Pos, "unknown name " ++ atom_to_list(Name))
                            end
                    end
            end
    end;
lookup_value(Pos, ['Prelude'], Name, #env{globals = Gs} = Env) ->
    %% report §4.2: `Prelude.x` is the prelude's x, whatever the module declares
    case Gs of
        #{[Name] := Scheme} -> {Scheme, {prelude, [Name]}, Env};
        _ -> fail(Pos, "the prelude declares no " ++ atom_to_list(Name))
    end;
lookup_value(Pos, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Pos, Path, Name);
lookup_value(Pos, [Owner] = Path, Name, #env{local_values = LV} = Env) ->
    case LV of
        #{{Owner, Name} := Q} -> local_global(Q, Env);
        _ ->
            case session(values, {Owner, Name}, Env) of
                {ok, Q} -> session_global(Q, Name, Env);
                error -> lookup_global(Pos, Path, Name, Env)
            end
    end;
lookup_value(Pos, Path, Name, #env{ns = Ns, local_values = LV} = Env) ->
    %% report §4.2: a module may name its own declarations qualified
    case Path =:= Ns of
        true ->
            case LV of
                #{Name := Q} -> local_global(Q, Env);
                _ -> lookup_global(Pos, Path, Name, Env)
            end;
        false ->
            %% report §4.2: `M.T.name` in module M is M's own member where M
            %% declares T, and the module M.T's `name` otherwise; only one of
            %% the two can exist, a module namespace may not coincide with a
            %% type-member namespace
            Own = case own_type_path(Path, Ns) of
                      true -> own_member(lists:last(Path), Name, Env);
                      false -> error
                  end,
            case Own of
                {ok, Q} -> local_global(Q, Env);
                error -> lookup_global(Pos, Path, Name, Env)
            end
    end.

%% Report §4.2: `Prelude.` takes one name the prelude declares; what is
%% below a namespace of its own is reached by that namespace.
prelude_one(Pos, Path, Name) ->
    fail(Pos, format_qname(Path ++ [Name]) ++ ": Prelude takes one name the prelude declares,"
              " as `Prelude.Close`").

own_member(Owner, Name, #env{local_values = LV} = Env) ->
    case LV of
        #{{Owner, Name} := Q} -> {ok, Q};
        _ -> session(values, {Owner, Name}, Env)
    end.

%% Report §4.4: an abstract type's constructor is its module's alone, and
%% each input of a session is a module of its own (report §11.2).
session_con(Pos, Q, #env{cons = Cs, types = Ts}) ->
    #cinfo{type_qname = TQ} = CI = maps:get(Q, Cs),
    case Ts of
        #{TQ := #tinfo{abstract = true}} ->
            %% report §11.2: the session writes its names unqualified, and
            %% an input, not a module, is what the constructor belongs to
            fail(Pos, atom_to_list(lists:last(Q)) ++ " is the constructor of an abstract type"
                      " and is not visible outside the input that declared it");
        _ ->
            CI
    end.

%% Report §11.2: a member of the session's latest type of its name may have
%% been declared by a later input than the type.
session_member(Q, Member, Env) ->
    Name = lists:last(Q),
    case session(types, Name, Env) of
        {ok, Q} ->
            case session(values, {Name, Member}, Env) of
                {ok, MQ} -> MQ;
                error -> Q ++ [Member]
            end;
        _ ->
            Q ++ [Member]
    end.

%% Report §11.2: what the session declared under this unqualified name.
session(Which, Name, #env{session = Session}) ->
    case maps:get(Which, Session, #{}) of
        #{Name := Q} -> {ok, Q};
        _ -> error
    end.

%% This module's own declaration, Q being its namespace and the owner and
%% the name.
local_global(Q, #env{ns = Ns} = Env) ->
    Env1 = demand(Q, Env),
    Ref = case lists:nthtail(length(Ns), Q) of
              [Name] -> {own, undefined, Name};
              [Owner, Name] -> {own, Owner, Name}
          end,
    {maps:get(Q, Env1#env.globals), Ref, Env1}.

%% Report §11.2: a declaration of an earlier input, another module.
session_global(Q, Name, Env) ->
    Env1 = demand(Q, Env),
    {maps:get(Q, Env1#env.globals), other_ref(lists:droplast(Q), Name, Env1), Env1}.

lookup_global(Pos, Path, Name, #env{globals = Gs} = Env) ->
    Q = Path ++ [Name],
    case Gs of
        #{Q := Scheme} ->
            Ref = case lookup_type(Q, Env) =:= undefined
                       andalso lists:keymember(Q, 1, ern_prelude:values()) of
                      true -> {prelude, Q};
                      false -> other_ref(Path, Name, Env)
                  end,
            {Scheme, Ref, Env};
        _ ->
            fail(Pos, "unknown name " ++ format_qname(Q))
    end.

%% Report §4.2: another module's declaration, Path its namespace or its
%% namespace and the type that owns the member.
other_ref(Path, Name, #env{ns = Ns} = Env) ->
    {Module, Owner} = case is_member_path(Path, Name, Env) of
                          true -> {lists:droplast(Path), lists:last(Path)};
                          false -> {Path, undefined}
                      end,
    case Module =:= Ns of
        true -> {own, Owner, Name};
        false -> {remote, Module, Owner, Name}
    end.

%% A constructor as a name written at Pos, `C` or `M.C`, names it (report
%% §4.2, §4.4): the error for one unknown or not visible here is thrown.
-spec lookup_con(ern_lexer:pos(), [atom()], atom(), env()) -> #cinfo{}.
lookup_con(Pos, [], Name, #env{local_cons = LC, cons = Cs} = Env) ->
    case LC of
        #{Name := Q} -> maps:get(Q, Cs);
        _ ->
            case session(cons, Name, Env) of
                {ok, Q} -> session_con(Pos, Q, Env);
                error ->
                    case Cs of
                        #{[Name] := CI} -> CI;
                        _ -> fail(Pos, "unknown constructor " ++ atom_to_list(Name))
                    end
            end
    end;
lookup_con(Pos, ['Prelude'], Name, #env{cons = Cs}) ->
    %% report §4.2: `Prelude.C` is the prelude's C, whatever the module declares
    case Cs of
        #{[Name] := CI} -> CI;
        _ -> fail(Pos, "the prelude declares no constructor " ++ atom_to_list(Name))
    end;
lookup_con(Pos, ['Prelude' | _] = Path, Name, _Env) ->
    prelude_one(Pos, Path, Name);
lookup_con(Pos, Path, Name, #env{cons = Cs, types = Types, local_types = LT}) ->
    Q = Path ++ [Name],
    case Cs of
        #{Q := #cinfo{type_qname = TQ} = CI} ->
            %% report §4.4: an abstract type's constructor is its module's alone
            Local = maps:get(lists:last(TQ), LT, undefined) =:= TQ,
            case Types of
                #{TQ := #tinfo{abstract = true}} when not Local ->
                    fail(Pos, format_qname(Q) ++ " is the constructor of an abstract type and is"
                              " not visible outside its module");
                _ -> CI
            end;
        _ -> fail(Pos, "unknown constructor " ++ format_qname(Q))
    end.

%% A constructor by its qualified name, one a checked pattern or a type's
%% own list of constructors gave, so known and not a name to resolve.
-spec con_info([atom()], env()) -> #cinfo{}.
con_info(QName, #env{cons = Cs}) -> maps:get(QName, Cs).

%%
%% Abstract types (report §4.4)
%%

%% An abstract type hides its constructors from every other module, so one
%% the module keeps private hides nothing.
check_abstract(Decls) ->
    [#diag{span = abstract_word(ern_diag:span(Pos)),
           message = atom_to_list(N) ++ " is an abstract type the module keeps private, which"
                     " hides its constructors from no module",
           help = "export it, or declare it `type`"}
     || #abstract_decl{export = false, pos = Pos, type = #type_decl{name = N}} <- Decls].

%% The word `abstract`, where the declaration begins.
abstract_word({L, C, _}) -> {L, C, {L, C + length("abstract")}}.

%%
%% Interface
%%

make_iface(Decls, #env{ns = Ns, types = Ts, globals = Gs} = Env) ->
    ExportedTypes = maps:from_list([{Q, maps:get(Q, Ts)}
                                    || D <- Decls, {true, Q} <- [exported_type(D, Env)]]),
    ExportedValues = maps:from_list([{Q, maps:get(Q, Gs)}
                                     || D <- Decls, {true, Q} <- [exported_value(D, Env)]]),
    %% report §4.6: a `let` is a value, and the emitter reaches it through
    %% its getter even where its type is a function
    Lets = [Q || #let_decl{} = D <- Decls, {true, Q} <- [exported_value(D, Env)]],
    #iface{namespace = Ns, types = ExportedTypes, values = ExportedValues, lets = Lets}.

%% Report §4.2: an exported declaration is made of the types that cross the
%% boundary with it. A private type in an exported signature would leave a
%% dependent module holding a value it cannot build or lay out; a type whose
%% values cross but whose constructors do not is an abstract type (§4.4).
%% A function's effect names no value and is not part of this.
check_exports(Decls, #env{local_types = LT, globals = Gs, types = Ts} = Env) ->
    Exported = [Q || D <- Decls, {true, Q} <- [exported_type(D, Env)]],
    Own = maps:values(LT),
    Private = fun(Q) -> lists:member(Q, Own) andalso not lists:member(Q, Exported) end,
    lists:append(
      [begin
           Named = case {exported_value(D, Env), exported_type(D, Env)} of
                       {{true, Q}, _} -> tcons(scheme_type(maps:get(Q, Gs, undefined), Env));
                       %% report §4.2: an abstract type's constructors do not
                       %% cross, so its fields may name a private type
                       {false, {true, _}} when is_record(D, abstract_decl) -> [];
                       {false, {true, TQ}} ->
                           constructor_tcons(maps:get(TQ, Ts, undefined), Env);
                       {false, false} -> []
                   end,
           [private_type(D, T) || T <- lists:usort(Named), Private(T)]
       end || D <- Decls]).

private_type(D, Q) ->
    Name = lists:last(Q),
    #diag{span = ern_diag:span(element(2, D)),
          message = declared_text(D) ++ " is exported and its type names "
                    ++ atom_to_list(Name) ++ ", which this module keeps private",
          help = "export " ++ atom_to_list(Name) ++ ", or declare it `abstract type` so that"
                 " its constructors stay private (§4.4)"}.

declared_text(#type_decl{name = N}) -> atom_to_list(N);
declared_text(#abstract_decl{type = #type_decl{name = N}}) -> atom_to_list(N);
declared_text(#foreign_type_decl{name = N}) -> atom_to_list(N);
declared_text(D) -> decl_name(D).

scheme_type(#scheme{type = T}, Env) -> resolve_type(T, Env);
scheme_type(_, _) -> pure.

constructor_tcons(#tinfo{constructors = Cs}, Env) ->
    lists:append([tcons(scheme_type(S, Env)) || #cinfo{scheme = S} <- Cs]);
constructor_tcons(_, _) ->
    [].

%% The type constructors a type names, its arrows' effects aside.
tcons({tcon, Q, Args}) -> [Q | lists:append([tcons(A) || A <- Args])];
tcons({ttuple, Es}) -> lists:append([tcons(E) || E <- Es]);
tcons({tfn, Ps, _Effect, R}) -> lists:append([tcons(T) || T <- Ps ++ [R]]);
tcons(_) -> [].

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

%% Report §4.6, §8.5: a name declared with `let` is a value, whatever its
%% type, and the emitter reaches it through the getter of its module. A
%% name declared with `fn` is a function.
-spec is_value([atom()], env()) -> boolean().
is_value(QName, #env{lets = Lets}) ->
    maps:is_key(QName, Lets).

-spec resolve_type(ern_types:type(), env()) -> ern_types:type().
resolve_type(T, #env{st = St}) -> ern_types:zonk(T, St).

-spec node_type(tuple()) -> ern_types:type().
node_type(Node) ->
    lists:last(tuple_to_list(Node)).

unify_at(Pos, Expected, Actual, Env, Context) ->
    unify_at(Pos, Expected, Actual, Env, Context, undefined).

%% Report §11.5: a mismatch is reported at Pos, the leaf, with Origin, the
%% span that fixed the expectation, as its label.
unify_at(Pos, Expected, Actual, #env{st = St} = Env, Context, Origin) ->
    case ern_types:unify(Expected, Actual, St) of
        {ok, St1} ->
            Env#env{st = St1};
        {error, Reason} ->
            fail(Pos, unify_message(Context, Reason, Expected, Actual, St), labels(Origin),
                 differing_help(Reason, Expected, Actual, St))
    end.

%% The message shows the whole types; when they differ inside, the help
%% line names the differing part.
differing_help({mismatch, _, _}, Expected, Actual, St) ->
    case ern_types:mismatch_pair(Expected, Actual, St) of
        {E, A} when E =:= Expected; A =:= Actual -> undefined;
        {E, A} -> "the types differ at " ++ ern_types:format(E, St) ++ " and "
                  ++ ern_types:format(A, St)
    end;
differing_help(_, _, _, _) -> undefined.

unify_message(Context, {mismatch, _, _}, Expected, Actual, St) ->
    lists:flatten([Context, ": expected ", ern_types:format(Expected, St), ", found ",
                   ern_types:format(Actual, St)]);
unify_message(Context, Reason, _, _, _) when Reason =:= pure_where_process_needed;
                                              Reason =:= process_where_pure_needed ->
    lists:flatten([Context, ": ", ern_types:format_error(Reason)]);
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

fail(Pos, Message, Labels, Help) ->
    throw({type_error, #diag{span = ern_diag:span(Pos), message = lists:flatten(Message),
                             labels = Labels, help = Help}}).
