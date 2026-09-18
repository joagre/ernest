%% The compiler: typed AST to Erlang abstract format, then to a BEAM module
%% with the interface as the chunk "ErnI" (report §11.1, plan 2.4): the
%% canonical interface, a hash of the source, and per dependency the hash
%% of the interface compiled against. The two tables of the
%% implementation plan, Phase 2.1, are its specification; values follow
%% report §8.4.
%%
%% One traversal does the three pre-passes on the way: every Ernest binding
%% gets a fresh Erlang variable (Ernest shadows, Erlang does not), local fns
%% are lifted to module functions taking the block's free variables first,
%% and `let p <- e` becomes a case (report §5.5).
-module(ern_compiler).

-export([refused/1, compile/4, compile/5, forms/3, erl_source/3, read_interface/1, iface_hash/1,
         module_atom/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("lexer/include/ern_diag.hrl").
-include_lib("type_system/include/ern_types.hrl").

-define(CHUNK, <<"ErnI">>).
-define(CHUNK_FORMAT, 1).

%% Emission context, threaded through everything.
-record(cx, {ns, mod, env, fname, vars = #{}, counter = 0, locals = #{}, lifted = [],
             tops = #{}}).
-record(local, {lifted, own, extra, refs, snap = pending}).
%% vars: Ernest name => Erlang variable name; locals: local fn name =>
%% #local{} (see Blocks); tops: top-level names => arity | value;
%% lifted: module functions produced by lifting, reversed

-type error() :: ern_diag:diag().

%%
%% Entry points
%%

-type chunk() :: #{iface := #iface{}, source_hash := binary(), deps := [{[atom()], binary()}]}.

-spec compile([atom()], [tuple()], #iface{}, ern_typecheck:env()) ->
          {ok, atom(), binary()} | {error, [error()]}.
compile(Ns, Decls, Iface, Env) ->
    compile(Ns, Decls, Iface, Env, #{source_hash => <<>>, deps => []}).

%% Build: the source hash and the dependencies' interface hashes go into
%% the chunk beside the interface.
-spec compile([atom()], [tuple()], #iface{}, ern_typecheck:env(),
              #{source_hash := binary(), deps := [{[atom()], binary()}]}) ->
          {ok, atom(), binary()} | {error, [error()]}.
compile(Ns, Decls, Iface, Env, Build) ->
    try
        Forms = forms(Ns, Decls, Env),
        Chunk = term_to_binary(Build#{format => ?CHUNK_FORMAT, iface => canonical_iface(Iface)}),
        case compile:forms(Forms, [return_errors, debug_info, {extra_chunks, [{?CHUNK, Chunk}]}]) of
            {ok, Mod, Bin} -> {ok, Mod, Bin};
            {ok, Mod, Bin, _Warnings} -> {ok, Mod, Bin};
            {error, Errors, _} -> {error, erl_errors(Errors)}
        end
    catch
        throw:{compile_error, Pos, Msg} ->
            {error, [#diag{span = ern_diag:span(Pos), message = Msg}]}
    end.

%% The abstract forms, for the golden tests and erl_prettypr.
-spec forms([atom()], [tuple()], ern_typecheck:env()) -> [erl_parse:abstract_form()].
forms(Ns, Decls, Env) ->
    Mod = module_atom(Ns),
    Cx0 = #cx{ns = Ns, mod = Mod, env = Env, tops = top_names(Decls)},
    {Funs, Cx1} = lists:mapfoldl(fun decl/2, Cx0, Decls),
    Lets = [D || #let_decl{} = D <- Decls],
    {Init, Cx2} = init_fun(Lets, Decls, Cx1),
    Exports = [export(D) || D <- Decls, exported(D)] ++ [{'$init', 0} || Lets =/= []],
    Attrs = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Mod)]),
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list([erl_syntax:arity_qualifier(
                                                      erl_syntax:atom(F), erl_syntax:integer(A))
                                                    || {F, A} <- Exports])])],
    Functions = lists:append(Funs) ++ Init ++ lists:reverse(Cx2#cx.lifted),
    erl_syntax:revert_forms(Attrs ++ Functions).

%% The module as Erlang source, for --emit erl (report §11.1).
-spec erl_source([atom()], [tuple()], ern_typecheck:env()) -> iolist().
erl_source(Ns, Decls, Env) ->
    Forms = forms(Ns, Decls, Env),
    [erl_prettypr:format(erl_syntax:form_list(Forms)), "\n"].

%% The chunk of a compiled module, the interface as the checker takes it.
%% A chunk of another format, from another version of the compiler, reads
%% as an error, which makes the module stale (report §11.1).
-spec read_interface(binary() | file:filename()) -> {ok, chunk()} | {error, string()}.
read_interface(Beam) ->
    case beam_lib:chunks(Beam, [binary_to_list(?CHUNK)]) of
        {ok, {_, [{_, Chunk}]}} ->
            case catch binary_to_term(Chunk) of
                #{format := ?CHUNK_FORMAT, iface := {iface, Ns, Types, Values}} = Map ->
                    {ok, Map#{iface => #iface{namespace = Ns, types = maps:from_list(Types),
                                              values = maps:from_list(Values)}}};
                _ ->
                    {error, "the interface chunk is of another compiler version"}
            end;
        {error, beam_lib, Reason} ->
            {error, lists:flatten(beam_lib:format_error(Reason))}
    end.

-spec iface_hash(#iface{}) -> binary().
iface_hash(Iface) ->
    crypto:hash(sha256, term_to_binary(canonical_iface(Iface, strip))).

%% Report §4.2, plan 2.4: the path with @ for / and the prefix ernest@.
-spec module_atom([atom()]) -> atom().
module_atom(Ns) ->
    list_to_atom(lists:flatten(["ernest" | ["@" ++ string:lowercase(atom_to_list(P))
                                            || P <- Ns]])).

erl_errors(PerFile) ->
    [#diag{span = {line_of(Anno), 1, {line_of(Anno), 1}},
           message = lists:flatten(Mod:format_error(Desc))}
     || {_File, Items} <- PerFile, {Anno, Mod, Desc} <- Items].

line_of(Pos) when is_tuple(Pos) -> element(1, Pos);
line_of(L) when is_integer(L) -> L;
line_of(_) -> 0.

%% Quantified variables renumbered and maps as sorted lists, so that equal
%% interfaces have equal bytes (plan 2.4). The hash leaves the variables'
%% names out: a renamed annotation changes no dependent.
canonical_iface(Iface) ->
    canonical_iface(Iface, keep).

canonical_iface(#iface{namespace = Ns, types = Ts, values = Vs}, Names) ->
    {iface, Ns, lists:sort(maps:to_list(Ts)),
     lists:sort([{Q, canonical_scheme(S, Names)} || {Q, S} <- maps:to_list(Vs)])}.

canonical_scheme(#scheme{vars = Vars, type = T, names = Names}, Keep) ->
    Map = maps:from_list([{Id, N} || {{Id, _}, N} <- lists:zip(Vars, lists:seq(1, length(Vars)))]),
    #scheme{vars = [{maps:get(Id, Map), Flags} || {Id, Flags} <- Vars],
            type = renumber(T, Map),
            names = case Keep of
                        keep -> maps:from_list([{maps:get(Id, Map), N}
                                                || {Id, N} <- maps:to_list(Names)]);
                        strip -> #{}
                    end}.

renumber({tvar, Id}, Map) -> {tvar, maps:get(Id, Map, Id)};
renumber({tcon, N, As}, Map) -> {tcon, N, [renumber(A, Map) || A <- As]};
renumber({ttuple, Es}, Map) -> {ttuple, [renumber(E, Map) || E <- Es]};
renumber({tfn, Ps, E, R}, Map) -> {tfn, [renumber(P, Map) || P <- Ps], renumber(E, Map),
                                   renumber(R, Map)};
renumber(T, _) -> T.

%%
%% Declarations
%%

top_names(Decls) ->
    maps:from_list([{{O, N}, length(Ps)} || #fn_decl{owner = O, name = N, params = Ps} <- Decls]
                   ++ [{{O, N}, value} || #let_decl{owner = O, name = N} <- Decls]).

exported(#fn_decl{export = E}) -> E;
exported(#let_decl{export = E}) -> E;
exported(_) -> false.

export(#fn_decl{owner = O, name = N, params = Ps}) -> {fname(O, N), length(Ps)};
export(#let_decl{owner = O, name = N}) -> {fname(O, N), 0}.

fname(undefined, N) -> N;
fname(Owner, N) -> list_to_atom(atom_to_list(Owner) ++ "." ++ atom_to_list(N)).

decl(#fn_decl{pos = Pos, owner = O, name = N, params = Params, body = Body}, Cx) ->
    Name = fname(O, N),
    Cx1 = Cx#cx{fname = Name, vars = #{}, locals = #{}},
    {Pats, Cx2} = lists:mapfoldl(fun(#param{pattern = P}, C) -> pattern(P, C) end, Cx1, Params),
    {BodyForms, Cx3} = body(Body, Cx2),
    Clause = at(Pos, erl_syntax:clause(Pats, none, BodyForms)),
    {[at(Pos, erl_syntax:function(erl_syntax:atom(Name), [Clause]))], Cx3#cx{vars = #{}}};
decl(#let_decl{pos = Pos, owner = O, name = N}, Cx) ->
    %% the getter; the value is computed by '$init'/0 (report §8.5)
    Name = fname(O, N),
    Get = call_remote(persistent_term, get, [key(Cx, Name)]),
    Clause = at(Pos, erl_syntax:clause([], none, [Get])),
    {[at(Pos, erl_syntax:function(erl_syntax:atom(Name), [Clause]))], Cx};
decl(#foreign_fn_decl{pos = Pos}, _Cx) ->
    fail(Pos, "foreign functions are not in MVP 1");
decl(_, Cx) ->
    {[], Cx}.

key(#cx{mod = Mod}, Name) ->
    erl_syntax:tuple([erl_syntax:atom(Mod), erl_syntax:atom(Name)]).

%% '$init'/0 evaluates the top-level lets once, in dependency order.
init_fun([], _Decls, Cx) ->
    {[], Cx};
init_fun(Lets, Decls, Cx) ->
    {Stores, Cx1} = lists:mapfoldl(
                      fun(#let_decl{owner = O, name = N, body = Body}, C) ->
                              {BodyForm, C1} = expr(Body, C#cx{fname = fname(O, N), vars = #{},
                                                               locals = #{}}),
                              {call_remote(persistent_term, put, [key(C, fname(O, N)), BodyForm]),
                               C1}
                      end, Cx, let_order(Lets, Decls)),
    Clause = erl_syntax:clause([], none, Stores ++ [erl_syntax:atom(ok)]),
    {[erl_syntax:function(erl_syntax:atom('$init'), [Clause])], Cx1}.

%% Dependency order among the lets, report §8.5: a let after those its
%% initializer references, directly or through the functions it calls. The
%% checker has already rejected a cycle.
let_order(Lets, Decls) ->
    Keys = [{O, N} || #let_decl{owner = O, name = N} <- Lets],
    Fns = maps:from_list([{{O, N}, B} || #fn_decl{owner = O, name = N, body = B} <- Decls]),
    G = digraph:new(),
    lists:foreach(fun(K) -> digraph:add_vertex(G, K) end, Keys),
    lists:foreach(fun(#let_decl{owner = O, name = N, body = B}) ->
                      lists:foreach(fun(R) -> digraph:add_edge(G, {O, N}, R) end,
                                    [R || R <- closure(refs(B), Fns, []), lists:member(R, Keys)])
                  end, Lets),
    Order = lists:reverse(digraph_utils:topsort(G)),
    digraph:delete(G),
    ByKey = maps:from_list([{{O, N}, D} || #let_decl{owner = O, name = N} = D <- Lets]),
    [maps:get(K, ByKey) || K <- Order].

%% The names reached through function bodies.
closure([], _Fns, Seen) ->
    Seen;
closure([R | Rest], Fns, Seen) ->
    case lists:member(R, Seen) of
        true -> closure(Rest, Fns, Seen);
        false ->
            More = case Fns of
                       #{R := Body} -> refs(Body);
                       _ -> []
                   end,
            closure(More ++ Rest, Fns, [R | Seen])
    end.

refs(#e_var{path = [], name = N}) -> [{undefined, N}];
refs(#e_var{path = [O], name = N}) -> [{O, N}];
refs(#e_binop{op = Op, left = L, right = R}) ->
    %% an operator on a local type calls its member (report §4.8, §3.10)
    Member = case ern_typecheck:node_type(L) of
                 {tcon, Q, _} when length(Q) > 1 ->
                     case lists:member(Op, ['<', '<=', '>', '>=']) of
                         true -> [{lists:last(Q), compare}];
                         false -> [{lists:last(Q), Op}]
                     end;
                 _ -> []
             end,
    Member ++ refs(L) ++ refs(R);
refs(T) when is_tuple(T) -> lists:append([refs(X) || X <- tl(tuple_to_list(T))]);
refs(L) when is_list(L) -> lists:append([refs(X) || X <- L]);
refs(_) -> [].

%%
%% Expressions: expr(E, Cx) -> {Form, Cx}
%%

expr(#e_lit{pos = Pos, kind = Kind, value = V}, Cx) ->
    {at(Pos, literal(Kind, V)), Cx};
expr(#e_var{pos = Pos, path = Path, name = Name, type = T}, Cx) ->
    {Form, Cx1} = var_ref(Pos, Path, Name, T, Cx),
    {at(Pos, Form), Cx1};
expr(#e_con{pos = Pos, path = Path, name = Name, args = Args, type = T}, Cx) ->
    con_expr(Pos, Path, Name, Args, T, Cx);
expr(#e_tuple{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = exprs(Es, Cx),
    {at(Pos, erl_syntax:tuple(Forms)), Cx1};
expr(#e_list{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = exprs(Es, Cx),
    {at(Pos, erl_syntax:list(Forms)), Cx1};
expr(#e_bits{pos = Pos}, _Cx) ->
    fail(Pos, "bitstrings are not in MVP 1");
expr(#e_block{pos = Pos, stmts = Stmts}, Cx) ->
    {Forms, Cx1} = block(Stmts, Cx),
    {at(Pos, erl_syntax:block_expr(Forms)), Cx1#cx{vars = Cx#cx.vars, locals = Cx#cx.locals}};
expr(#e_call{pos = Pos, callee = Callee, args = Args}, Cx) ->
    call(Pos, Callee, Args, Cx);
expr(#e_neg{pos = Pos, expr = X}, Cx) ->
    {Form, Cx1} = expr(X, Cx),
    {at(Pos, negate(resolved(ern_typecheck:node_type(X), Cx), Form)), Cx1};
expr(#e_binop{pos = Pos, op = Op, left = L, right = R}, Cx) ->
    {LF, Cx1} = expr(L, Cx),
    {RF, Cx2} = expr(R, Cx1),
    {at(Pos, binop(Op, resolved(ern_typecheck:node_type(L), Cx), LF, RF, Cx)), Cx2};
expr(#e_lambda{pos = Pos, params = Params, body = Body}, Cx) ->
    {Pats, Cx1} = lists:mapfoldl(fun(#param{pattern = P}, C) -> pattern(P, C) end, Cx, Params),
    {BodyForms, Cx2} = body(Body, Cx1),
    Clause = erl_syntax:clause(Pats, none, BodyForms),
    {at(Pos, erl_syntax:fun_expr([Clause])), Cx2#cx{vars = Cx#cx.vars}};
expr(#e_if{pos = Pos, condition = C, then_branch = T, else_branch = E}, Cx) ->
    {CF, Cx1} = expr(C, Cx),
    {TF, Cx2} = body(T, Cx1),
    {EF, Cx3} = body(E, Cx2),
    {at(Pos, erl_syntax:case_expr(CF, [erl_syntax:clause([erl_syntax:atom(true)], none, TF),
                                       erl_syntax:clause([erl_syntax:atom(false)], none, EF)])),
     Cx3};
expr(#e_match{pos = Pos, scrutinee = S, clauses = Clauses}, Cx) ->
    {SF, Cx1} = expr(S, Cx),
    {Form, Cx2} = match_clauses(SF, Clauses, Cx1),
    {at(Pos, Form), Cx2};
expr(#e_receive{pos = Pos, clauses = Clauses, 'after' = After}, Cx) ->
    {ClauseForms, Cx1} = lists:mapfoldl(fun receive_clause/2, Cx, Clauses),
    case After of
        undefined ->
            {at(Pos, erl_syntax:receive_expr(ClauseForms)), Cx1};
        #after_clause{timeout = T, body = B} ->
            {TF, Cx2} = expr(T, Cx1),
            {BF, Cx3} = body(B, Cx2),
            {at(Pos, erl_syntax:receive_expr(ClauseForms, TF, BF)), Cx3}
    end.

exprs(Es, Cx) ->
    lists:mapfoldl(fun expr/2, Cx, Es).

%% A body: a block's statements spliced into the clause, else one expression.
body(#e_block{stmts = Stmts}, Cx) ->
    {Forms, Cx1} = block(Stmts, Cx),
    {Forms, Cx1#cx{vars = Cx#cx.vars, locals = Cx#cx.locals}};
body(E, Cx) ->
    {Form, Cx1} = expr(E, Cx),
    {[Form], Cx1}.

literal(int, V) -> erl_syntax:integer(V);
literal(float, V) -> erl_syntax:float(V);
literal(char, V) -> erl_syntax:char(V);
literal(string, V) -> string_binary(V);
literal(bool, V) -> erl_syntax:atom(V).

%% <<"text">>, with /utf8 only when a character is outside ASCII.
string_binary(Bin) ->
    Chars = unicode:characters_to_list(Bin),
    Str = erl_syntax:string(Chars),
    Field = case lists:all(fun(C) -> C < 128 end, Chars) of
                true -> erl_syntax:binary_field(Str);
                false -> erl_syntax:binary_field(Str, [erl_syntax:atom(utf8)])
            end,
    erl_syntax:binary([Field]).

%%
%% Names
%%

%% A name used as a value: var_ref(...) -> {Form, Cx}.
var_ref(Pos, [], Name, T, #cx{vars = Vars, locals = Locals, tops = Tops} = Cx) ->
    case Vars of
        #{Name := V} -> {erl_syntax:variable(V), Cx};
        _ ->
            case Locals of
                #{Name := #local{lifted = Lifted}} ->
                    closure(Lifted, instances(Name, Cx), arity_of(T, Pos), Cx);
                _ ->
                    case Tops of
                        #{{undefined, Name} := value} ->
                            {erl_syntax:application(erl_syntax:atom(Name), []), Cx};
                        #{{undefined, Name} := Arity} ->
                            {erl_syntax:implicit_fun(erl_syntax:atom(Name),
                                                     erl_syntax:integer(Arity)), Cx};
                        _ -> {prelude_value(Pos, mvp1(Pos, [Name]), T, Cx), Cx}
                    end
            end
    end;
var_ref(Pos, Path, Name, T, #cx{tops = Tops, env = Env} = Cx) ->
    Form = case Path of
               [Owner] when is_map_key({Owner, Name}, Tops) ->
                   case maps:get({Owner, Name}, Tops) of
                       value -> erl_syntax:application(erl_syntax:atom(fname(Owner, Name)), []);
                       Arity -> erl_syntax:implicit_fun(erl_syntax:atom(fname(Owner, Name)),
                                                        erl_syntax:integer(Arity))
                   end;
               _ ->
                   case is_prelude(Path ++ [Name], Env) of
                       true -> prelude_value(Pos, mvp1(Pos, Path ++ [Name]), T, Cx);
                       false ->
                           {M, F} = remote_name(Path, Name, Env),
                           case T of
                               {tfn, Ps, _, _} -> remote_fun(M, F, length(Ps));
                               _ -> call_remote(M, F, [])
                           end
                   end
           end,
    {Form, Cx}.

arity_of({tfn, Ps, _, _}, _) -> length(Ps);
arity_of(_, Pos) -> fail(Pos, "a local function used as a value must have a function type").

%% The prelude names of plan MVP 2.5 step 4: the checker knows them so the
%% MVP 2 programs type-check, and the compiler refuses them until the
%% system processes behind them exist (README, "What MVP 1 accepts").
-spec refused([atom()]) -> boolean().
refused(['Sys', N]) -> N =/= stdout andalso N =/= clock;
refused(['Io', readLine]) -> true;
refused([Ns | _]) -> Ns =:= 'Keys' orelse Ns =:= 'Fs' orelse Ns =:= 'Tcp';
refused(_) -> false.

mvp1(Pos, QName) ->
    case refused(QName) of
        true -> fail(Pos, qname(QName) ++ " is not in MVP 1");
        false -> QName
    end.

%% A prelude or stdlib name: the prelude tables know it and no module does.
is_prelude(QName, Env) ->
    ern_typecheck:lookup_type(QName, Env) =:= undefined andalso
        lists:keymember(QName, 1, ern_prelude:values()).

%% A qualified name in another Ernest module: Path names the module, or a
%% module plus a type-member owner (report §4.2).
remote_name(Path, Name, Env) ->
    case ern_typecheck:lookup_type(Path, Env) of
        #tinfo{qname = Q} when length(Q) > 1 ->
            %% Path is Module ++ [Owner]: the member lives in Module
            {module_atom(lists:droplast(Path)), fname(lists:last(Path), Name)};
        _ ->
            {module_atom(Path), Name}
    end.

closure(Lifted, Insts, Arity, Cx) ->
    {Params, Cx1} = fresh_vars(Arity, "A", Cx),
    Args = [erl_syntax:variable(V) || V <- Insts ++ Params],
    Body = erl_syntax:application(erl_syntax:atom(Lifted), Args),
    {erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(P) || P <- Params], none,
                                            [Body])]),
     Cx1}.

%%
%% Calls
%%

call(Pos, #e_var{path = [], name = Name} = Callee, Args, Cx) ->
    #cx{vars = Vars, locals = Locals, tops = Tops} = Cx,
    {ArgForms, Cx1} = exprs(Args, Cx),
    case Vars of
        #{Name := V} ->
            {at(Pos, erl_syntax:application(erl_syntax:variable(V), ArgForms)), Cx1};
        _ ->
            case Locals of
                #{Name := #local{lifted = Lifted}} ->
                    Insts = [erl_syntax:variable(V) || V <- instances(Name, Cx)],
                    App = erl_syntax:application(erl_syntax:atom(Lifted), Insts ++ ArgForms),
                    {at(Pos, App), Cx1};
                _ ->
                    case Tops of
                        #{{undefined, Name} := Arity} when is_integer(Arity) ->
                            {at(Pos, erl_syntax:application(erl_syntax:atom(Name), ArgForms)), Cx1};
                        _ ->
                            prelude_call(Pos, mvp1(Pos, [Name]), Args, ArgForms, Callee, Cx1)
                    end
            end
    end;
call(Pos, #e_var{path = Path, name = Name} = Callee, Args, Cx) ->
    #cx{tops = Tops, env = Env} = Cx,
    {ArgForms, Cx1} = exprs(Args, Cx),
    case Path of
        [Owner] when is_map_key({Owner, Name}, Tops) ->
            {at(Pos, erl_syntax:application(erl_syntax:atom(fname(Owner, Name)), ArgForms)), Cx1};
        _ ->
            case is_prelude(Path ++ [Name], Env) of
                true -> prelude_call(Pos, mvp1(Pos, Path ++ [Name]), Args, ArgForms, Callee, Cx1);
                false ->
                    {M, F} = remote_name(Path, Name, Env),
                    {at(Pos, call_remote(M, F, ArgForms)), Cx1}
            end
    end;
call(Pos, #e_con{} = Con, Args, Cx) ->
    %% a single-positional constructor called as a function
    {ConForm, Cx1} = expr(Con, Cx),
    {ArgForms, Cx2} = exprs(Args, Cx1),
    {at(Pos, erl_syntax:application(ConForm, ArgForms)), Cx2};
call(Pos, Callee, Args, Cx) ->
    {CalleeForm, Cx1} = expr(Callee, Cx),
    {ArgForms, Cx2} = exprs(Args, Cx1),
    {at(Pos, erl_syntax:application(CalleeForm, ArgForms)), Cx2}.

%% fun M:F/A
remote_fun(M, F, Arity) ->
    erl_syntax:implicit_fun(erl_syntax:atom(M), erl_syntax:atom(F), erl_syntax:integer(Arity)).

call_remote(M, F, Args) ->
    erl_syntax:application(erl_syntax:module_qualifier(erl_syntax:atom(M), erl_syntax:atom(F)),
                           Args).

%%
%% The prelude, plan 2.1 table two
%%

prelude_call(Pos, [self], [], [], _, Cx) -> {at(Pos, call_remote(ern_rt, self, [])), Cx};
prelude_call(Pos, [send], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, send, Args)), Cx};
prelude_call(Pos, [answer], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, answer, Args)), Cx};
prelude_call(Pos, [via], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, via, Args)), Cx};
prelude_call(Pos, [monitor], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, monitor, Args)), Cx};
prelude_call(Pos, [kill], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, kill, Args)), Cx};
prelude_call(Pos, [spawn], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, spawn, Args ++ [site(Pos, Cx)])), Cx};
prelude_call(Pos, ['Address', call], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, call, Args)), Cx};
prelude_call(Pos, ['Address', callForever], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, call_forever, Args)), Cx};
prelude_call(Pos, [remote], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, remote, Args)), Cx};
prelude_call(Pos, [parallelRemote], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, parallel_remote, Args)), Cx};
prelude_call(Pos, [todo], _, [Msg], _, Cx) ->
    {at(Pos, call_remote(ern_rt, todo, [Msg])), Cx};
prelude_call(Pos, ['Int', Op], [L | _], [LF, RF], _, Cx) when Op =:= '+'; Op =:= '-'; Op =:= '*';
                                                             Op =:= '/'; Op =:= '%' ->
    {at(Pos, binop(Op, resolved(ern_typecheck:node_type(L), Cx), LF, RF, Cx)), Cx};
prelude_call(Pos, ['Int', negate], _, [F], _, Cx) ->
    {at(Pos, erl_syntax:prefix_expr(erl_syntax:operator('-'), F)), Cx};
prelude_call(Pos, [Ns, '<>'], [L | _], [LF, RF], _, Cx) when Ns =:= 'String'; Ns =:= 'List';
                                                            Ns =:= 'Bytes' ->
    {at(Pos, binop('<>', resolved(ern_typecheck:node_type(L), Cx), LF, RF, Cx)), Cx};
prelude_call(Pos, [Ns | Rest], _, Args, _, Cx) when Rest =/= [] ->
    %% a stdlib function: the namespace's module
    {at(Pos, call_remote(module_atom([Ns]), lists:last(Rest), Args)), Cx};
prelude_call(Pos, QName, _, _, _, _) ->
    fail(Pos, "no emission for " ++ qname(QName)).

%% A prelude name taken as a value.
prelude_value(Pos, [spawn], T, Cx) ->
    %% a closure, since spawn takes the site as a third argument
    {[W, F], _} = fresh_vars(2, "A", Cx),
    Args = [erl_syntax:variable(W), erl_syntax:variable(F), site(Pos, Cx)],
    lambda([W, F], call_remote(ern_rt, spawn, Args), arity_of(T, Pos), 2);
prelude_value(Pos, ['Int', Op], T, Cx) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/';
                                             Op =:= '%' ->
    {[A, B], _} = fresh_vars(2, "A", Cx),
    Body = binop(Op, {tcon, ['Int'], []}, erl_syntax:variable(A), erl_syntax:variable(B), Cx),
    lambda([A, B], Body, arity_of(T, Pos), 2);
prelude_value(Pos, ['Int', negate], T, Cx) ->
    {[A], _} = fresh_vars(1, "A", Cx),
    Body = erl_syntax:prefix_expr(erl_syntax:operator('-'), erl_syntax:variable(A)),
    lambda([A], Body, arity_of(T, Pos), 1);
prelude_value(Pos, [_, '<>'], {tfn, [P | _], _, _} = T, Cx) ->
    {[A, B], _} = fresh_vars(2, "A", Cx),
    Body = binop('<>', resolved(P, Cx), erl_syntax:variable(A), erl_syntax:variable(B), Cx),
    lambda([A, B], Body, arity_of(T, Pos), 2);
prelude_value(Pos, QName, T, _Cx) ->
    prelude_value(Pos, QName, T).

lambda(Vars, Body, Arity, Arity) ->
    erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(V) || V <- Vars], none, [Body])]).

%% Without a closure over the context.
prelude_value(_Pos, ['Sys', stdout], _) -> call_remote(ern_rt, sys, [erl_syntax:atom(stdout)]);
prelude_value(_Pos, ['Sys', clock], _) -> call_remote(ern_rt, sys, [erl_syntax:atom(clock)]);
prelude_value(Pos, [Name], T) ->
    {M, F} = case Name of
                 self -> {ern_rt, self};
                 send -> {ern_rt, send};
                 answer -> {ern_rt, answer};
                 via -> {ern_rt, via};
                 monitor -> {ern_rt, monitor};
                 kill -> {ern_rt, kill};
                 remote -> {ern_rt, remote};
                 parallelRemote -> {ern_rt, parallel_remote};
                 todo -> {ern_rt, todo};
                 _ -> fail(Pos, "no emission for " ++ atom_to_list(Name))
             end,
    remote_fun(M, F, arity_of(T, Pos));
prelude_value(Pos, ['Address', call], T) ->
    remote_fun(ern_rt, call, arity_of(T, Pos));
prelude_value(Pos, ['Address', callForever], T) ->
    remote_fun(ern_rt, call_forever, arity_of(T, Pos));
prelude_value(_Pos, [Ns | Rest], T) when Rest =/= [] ->
    case T of
        {tfn, Ps, _, _} -> remote_fun(module_atom([Ns]), lists:last(Rest), length(Ps));
        _ ->
            %% a stdlib value: Map.empty, Set.empty
            call_remote(module_atom([Ns]), lists:last(Rest), [])
    end;
prelude_value(Pos, QName, _) ->
    fail(Pos, "no emission for " ++ qname(QName)).

site(Pos, #cx{ns = Ns, fname = F}) ->
    Line = element(1, Pos),
    string_binary(unicode:characters_to_binary(qname(Ns ++ [F]) ++ ":" ++ integer_to_list(Line))).

%%
%% Operators, report §4.8 and plan 2.1
%%

%% Report §4.8, §3.10, §5.1: by the operand type. Int and the four
%% ordered prelude types are Erlang's operators; Float goes through
%% 'ernest@float', which turns badarith into the §7.4 fault; a user type's
%% operator is its member, and its ordering is `T.compare(a, b)` against
%% Less or Greater.
binop(Op, {tcon, ['Int'], []}, L, R, _) when Op =:= '+'; Op =:= '-'; Op =:= '*' ->
    erl_syntax:infix_expr(L, erl_syntax:operator(Op), R);
binop('/', {tcon, ['Int'], []}, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('div'), R);
binop('%', {tcon, ['Int'], []}, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('rem'), R);
binop(Op, {tcon, ['Float'], []}, L, R, _) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/' ->
    call_remote('ernest@float', Op, [L, R]);
binop('<>', {tcon, ['String'], []}, L, R, _) -> binary_append(L, R);
binop('<>', {tcon, ['Bytes'], []}, L, R, _) -> binary_append(L, R);
binop('<>', {tcon, ['List'], _}, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('++'), R);
binop('==', _, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('=:='), R);
binop('!=', _, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('=/='), R);
binop('&&', _, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('andalso'), R);
binop('||', _, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('orelse'), R);
binop('::', _, L, R, _) -> erl_syntax:cons(L, R);
binop(Op, {tcon, Q, _}, L, R, Cx) when length(Q) > 1 ->
    case lists:member(Op, ['<', '<=', '>', '>=']) of
        true ->
            {Erl, Side} = case Op of
                              '<' -> {'=:=', 'Less'};
                              '>' -> {'=:=', 'Greater'};
                              '<=' -> {'=/=', 'Greater'};
                              '>=' -> {'=/=', 'Less'}
                          end,
            erl_syntax:infix_expr(member_call(Q, compare, [L, R], Cx), erl_syntax:operator(Erl),
                                  erl_syntax:atom(Side));
        false ->
            member_call(Q, Op, [L, R], Cx)
    end;
binop('<=', _, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('=<'), R);
binop(Op, _, L, R, _) when Op =:= '<'; Op =:= '>'; Op =:= '>=' ->
    erl_syntax:infix_expr(L, erl_syntax:operator(Op), R).

negate({tcon, ['Float'], []}, Form) -> call_remote('ernest@float', negate, [Form]);
negate(_, Form) -> erl_syntax:prefix_expr(erl_syntax:operator('-'), Form).

%% A member of the type Q: a local function when Q is this module's type,
%% otherwise a call into the module that owns it (report §4.2).
member_call(Q, Name, Args, #cx{ns = Ns}) ->
    Owner = lists:last(Q),
    case lists:droplast(Q) of
        Ns -> erl_syntax:application(erl_syntax:atom(fname(Owner, Name)), Args);
        Mod -> call_remote(module_atom(Mod), fname(Owner, Name), Args)
    end.

%% <<A/binary, B/binary>>, with a string literal as a plain segment and an
%% inner append flattened, so "a" <> f(x) <> "b" is one binary.
binary_append(L, R) ->
    erl_syntax:binary(segments(L) ++ segments(R)).

segments(Form) ->
    case erl_syntax:type(Form) of
        binary -> erl_syntax:binary_fields(Form);
        string -> [erl_syntax:binary_field(Form)];
        _ -> [erl_syntax:binary_field(Form, [erl_syntax:atom(binary)])]
    end.

resolved(T, #cx{env = Env}) ->
    ern_typecheck:resolve_type(T, Env).

%%
%% Constructors, report §8.4
%%

con_expr(Pos, Path, Name, Args, _T, Cx) ->
    #cinfo{fields = Fields} = ern_typecheck:lookup_con(Pos, Path, Name, Cx#cx.env),
    Tag = erl_syntax:atom(Name),
    case {Fields, Args} of
        {none, none} ->
            {at(Pos, Tag), Cx};
        {positional, none} ->
            %% as a function value
            {[V], Cx1} = fresh_vars(1, "V", Cx),
            Var = erl_syntax:variable(V),
            {at(Pos, erl_syntax:fun_expr([erl_syntax:clause([Var], none,
                                                            [erl_syntax:tuple([Tag, Var])])])),
             Cx1};
        {positional, {positional, Arg}} ->
            {Form, Cx1} = expr(Arg, Cx),
            {at(Pos, erl_syntax:tuple([Tag, Form])), Cx1};
        {{named, Names}, {named, undefined, Sets}} ->
            {Forms, Cx1} = lists:mapfoldl(fun(N, C) ->
                                              [X] = [X0 || #field_set{name = FN, expr = X0} <- Sets,
                                                           FN =:= N],
                                              expr(X, C)
                                          end, Cx, Names),
            {at(Pos, erl_syntax:tuple([Tag | Forms])), Cx1};
        {{named, Names}, {named, Base, Sets}} ->
            %% T(..base, f = e): bind the base to a tuple pattern, take the
            %% unlisted fields from it
            {BaseForm, Cx1} = expr(Base, Cx),
            {Vars, Cx2} = fresh_vars(length(Names), "B", Cx1),
            BasePat = erl_syntax:tuple([Tag | [erl_syntax:variable(V) || V <- Vars]]),
            {Forms, Cx3} = lists:mapfoldl(
                             fun({N, V}, C) ->
                                     case [X0 || #field_set{name = FN, expr = X0} <- Sets,
                                                 FN =:= N] of
                                         [X] -> expr(X, C);
                                         [] -> {erl_syntax:variable(V), C}
                                     end
                             end, Cx2, lists:zip(Names, Vars)),
            Bind = erl_syntax:match_expr(BasePat, BaseForm),
            {at(Pos, erl_syntax:block_expr([Bind, erl_syntax:tuple([Tag | Forms])])), Cx3};
        _ ->
            fail(Pos, "constructor " ++ atom_to_list(Name) ++ " used with the wrong field shape;"
                      " T is the type checker's job")
    end.

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
%% own: free names bound by the enclosing scopes or this block's lets;
%% extra: variables of enclosing blocks' local fns it references; refs:
%% local fns of this block it references; snap: the variables in force at
%% the declaration, once passed

block(Stmts, Cx) ->
    Fns = [D || #fn_decl{} = D <- Stmts],
    Cx1 = declare_locals(Fns, Stmts, Cx),
    {Forms, Cx2} = stmts(Stmts, Cx1, []),
    {Forms, emit_locals(Fns, Cx2)}.

stmts([#binding{pos = Pos, op = '='}], _Cx, _Acc) ->
    fail(Pos, "a block ends with an expression");
stmts([Last], Cx, Acc) ->
    {Form, Cx1} = expr(Last, Cx),
    {lists:reverse([Form | Acc]), Cx1};
stmts([#fn_decl{name = N} | Rest], #cx{locals = Locals, vars = Vars} = Cx, Acc) ->
    Local = maps:get(N, Locals),
    stmts(Rest, Cx#cx{locals = Locals#{N => Local#local{snap = Vars}}}, Acc);
stmts([#binding{pos = Pos, pattern = P, op = '=', expr = X} | Rest], Cx, Acc) ->
    {XF, Cx1} = expr(X, Cx),
    {PF, Cx2} = pattern(P, Cx1),
    stmts(Rest, Cx2, [at(Pos, erl_syntax:match_expr(PF, XF)) | Acc]);
stmts([#binding{pos = Pos, pattern = P, op = '<-', expr = X} | Rest], Cx, Acc) ->
    %% report §5.5
    {XF, Cx1} = expr(X, Cx),
    {PF, Cx2} = pattern(P, Cx1),
    {RestForms, Cx3} = stmts(Rest, Cx2, []),
    {[E], Cx4} = fresh_vars(1, "E", Cx3),
    Err = erl_syntax:variable(E),
    Clauses = case resolved(ern_typecheck:node_type(X), Cx) of
                  {tcon, ['Either'], _} ->
                      [erl_syntax:clause([erl_syntax:tuple([erl_syntax:atom('Left'), Err])], none,
                                         [erl_syntax:tuple([erl_syntax:atom('Left'), Err])]),
                       erl_syntax:clause([erl_syntax:tuple([erl_syntax:atom('Right'), PF])], none,
                                         RestForms)];
                  {tcon, ['Optional'], _} ->
                      [erl_syntax:clause([erl_syntax:atom('None')], none,
                                         [erl_syntax:atom('None')]),
                       erl_syntax:clause([erl_syntax:tuple([erl_syntax:atom('Some'), PF])], none,
                                         RestForms)];
                  _ ->
                      fail(Pos, "`<-` on a value that is neither Either nor Optional")
              end,
    {lists:reverse([at(Pos, erl_syntax:case_expr(XF, Clauses)) | Acc]), Cx4};
stmts([X | Rest], Cx, Acc) ->
    {Form, Cx1} = expr(X, Cx),
    stmts(Rest, Cx1, [Form | Acc]).

declare_locals([], _Stmts, Cx) ->
    Cx;
declare_locals(Fns, Stmts, #cx{vars = Vars, locals = Locals, tops = Tops} = Cx) ->
    Names = [N || #fn_decl{name = N} <- Fns],
    BlockLets = lists:append([pattern_names(P) || #binding{pattern = P} <- Stmts]),
    {Declared, Cx1} =
        lists:mapfoldl(
          fun(#fn_decl{name = N, params = Params, body = Body}, C) ->
                  Bound = lists:append([pattern_names(P) || #param{pattern = P} <- Params]),
                  Free = [F || F <- lists:usort(names(Body, Bound)),
                               not is_map_key({undefined, F}, Tops)],
                  Refs = [F || F <- Free, lists:member(F, Names)],
                  Own = [F || F <- Free, not lists:member(F, Names),
                              is_map_key(F, Vars) orelse lists:member(F, BlockLets)],
                  Extra = lists:append([instances(F, Cx) || F <- Free, not lists:member(F, Names),
                                                            not lists:member(F, Own),
                                                            is_map_key(F, Locals)]),
                  {Lifted, C1} = fresh_name(N, C),
                  {{N, #local{lifted = Lifted, own = Own, extra = lists:usort(Extra), refs = Refs}},
                   C1}
          end, Cx, Fns),
    Cx1#cx{locals = maps:merge(Locals, maps:from_list(Declared))}.

%% The variables a local fn closes over, in order, each once.
instances(Name, #cx{locals = Locals, vars = Vars}) ->
    lists:usort(instances([Name], Locals, Vars, [], [])).

instances([], _Locals, _Vars, _Seen, Acc) ->
    Acc;
instances([N | Rest], Locals, Vars, Seen, Acc) ->
    case lists:member(N, Seen) of
        true ->
            instances(Rest, Locals, Vars, Seen, Acc);
        false ->
            #local{own = Own, extra = Extra, refs = Refs, snap = Snap} = maps:get(N, Locals),
            Scope = case Snap of pending -> Vars; _ -> Snap end,
            Vs = [maps:get(O, Scope) || O <- Own] ++ Extra,
            instances(Refs ++ Rest, Locals, Vars, [N | Seen], Vs ++ Acc)
    end.

%% The lifted functions of a block, once every declaration has passed.
emit_locals(Fns, Cx) ->
    lists:foldl(
      fun(#fn_decl{pos = Pos, name = N, params = Params, body = Body}, C) ->
              #local{lifted = Lifted, own = Own, snap = Snap} = maps:get(N, C#cx.locals),
              Insts = instances(N, C),
              OwnVars = maps:from_list([{O, maps:get(O, Snap)} || O <- Own]),
              {Pats, C1} = lists:mapfoldl(fun(#param{pattern = P}, Cc) -> pattern(P, Cc) end,
                                          C#cx{vars = OwnVars}, Params),
              {BodyForms, C2} = body(Body, C1),
              Head = [erl_syntax:variable(V) || V <- Insts] ++ Pats,
              Clause = at(Pos, erl_syntax:clause(Head, none, BodyForms)),
              Fun = at(Pos, erl_syntax:function(erl_syntax:atom(Lifted), [Clause])),
              C2#cx{vars = C#cx.vars, lifted = [Fun | C2#cx.lifted]}
      end, Cx, Fns).

%% Unqualified names free in Node, given the names bound around it.
names(#e_var{path = [], name = N}, Bound) ->
    case lists:member(N, Bound) of true -> []; false -> [N] end;
names(#e_lambda{params = Ps, body = B}, Bound) ->
    names(B, Bound ++ lists:append([pattern_names(P) || #param{pattern = P} <- Ps]));
names(#e_block{stmts = Stmts}, Bound) ->
    {_, Acc} = lists:foldl(fun(#binding{pattern = P, expr = X}, {Bd, A}) ->
                                   {Bd ++ pattern_names(P), A ++ names(X, Bd)};
                              (#fn_decl{name = N, params = Ps, body = B}, {Bd, A}) ->
                                   ParamNames = [pattern_names(P) || #param{pattern = P} <- Ps],
                                   Inner = Bd ++ [N] ++ lists:append(ParamNames),
                                   {Bd ++ [N], A ++ names(B, Inner)};
                              (S, {Bd, A}) -> {Bd, A ++ names(S, Bd)}
                           end, {Bound, []}, Stmts),
    Acc;
names(#clause{pattern = P, guard = G, body = B}, Bound) ->
    Bd = Bound ++ pattern_names(P),
    names(G, Bd) ++ names(B, Bd);
names(T, Bound) when is_tuple(T) -> lists:append([names(X, Bound) || X <- tl(tuple_to_list(T))]);
names(L, Bound) when is_list(L) -> lists:append([names(X, Bound) || X <- L]);
names(_, _) -> [].

pattern_names(#p_var{name = N}) -> [N];
pattern_names(#p_as{name = N, pattern = P}) -> [N | pattern_names(P)];
pattern_names(#p_con{args = {positional, P}}) -> pattern_names(P);
pattern_names(#p_con{args = {named, FPs}}) ->
    lists:append([pattern_names(P) || #field_pat{pattern = P} <- FPs]);
pattern_names(#p_tuple{elems = Es}) -> lists:append([pattern_names(E) || E <- Es]);
pattern_names(#p_list{elems = Es}) -> lists:append([pattern_names(E) || E <- Es]);
pattern_names(#p_cons{head = H, tail = T}) -> pattern_names(H) ++ pattern_names(T);
pattern_names(_) -> [].

%%
%% match and receive clauses
%%

%% A clause whose guard is not an Erlang guard expression falls through by
%% a continuation over the remaining clauses (plan 2.1).
match_clauses(SF, Clauses, Cx) ->
    case lists:any(fun(#clause{guard = G}) -> G =/= undefined andalso not erlang_guard(G, Cx) end,
                   Clauses) of
        false ->
            {Forms, Cx1} = lists:mapfoldl(fun simple_clause/2, Cx, Clauses),
            {erl_syntax:case_expr(SF, Forms), Cx1};
        true ->
            {[S], Cx1} = fresh_vars(1, "S", Cx),
            SVar = erl_syntax:variable(S),
            {Body, Cx2} = general_clauses(SVar, Clauses, Cx1),
            {erl_syntax:block_expr([erl_syntax:match_expr(SVar, SF), Body]), Cx2}
    end.

general_clauses(SVar, [#clause{pattern = P, guard = G, body = B}], Cx) when
      G =:= undefined ->
    {PF, Cx1} = pattern(P, Cx),
    {BF, Cx2} = body(B, Cx1),
    {erl_syntax:case_expr(SVar, [erl_syntax:clause([PF], none, BF)]), Cx2#cx{vars = Cx#cx.vars}};
general_clauses(SVar, [#clause{pattern = P, guard = G, body = B} | Rest], Cx) ->
    %% Rest = fun() -> <remaining> end; the guard falls through to Rest()
    {[R], Cx1} = fresh_vars(1, "Rest", Cx),
    RVar = erl_syntax:variable(R),
    {RestBody, Cx2} = case Rest of
                          [] -> {call_remote(erlang, error, [erl_syntax:atom(no_match)]), Cx1};
                          _ -> general_clauses(SVar, Rest, Cx1)
                      end,
    RestFun = erl_syntax:fun_expr([erl_syntax:clause([], none, [RestBody])]),
    Bind = erl_syntax:match_expr(RVar, RestFun),
    {PF, Cx3} = pattern(P, Cx2),
    Fallthrough = erl_syntax:application(RVar, []),
    {Body, Cx4} = case G of
                      undefined -> body(B, Cx3);
                      _ ->
                          {GF, Cx3a} = expr(G, Cx3),
                          {BF, Cx3b} = body(B, Cx3a),
                          {[erl_syntax:case_expr(
                              GF, [erl_syntax:clause([erl_syntax:atom(true)], none, BF),
                                   erl_syntax:clause([erl_syntax:atom(false)], none,
                                                     [Fallthrough])])],
                           Cx3b}
                  end,
    Case = erl_syntax:case_expr(SVar, [erl_syntax:clause([PF], none, Body),
                                       erl_syntax:clause([erl_syntax:underscore()], none,
                                                         [Fallthrough])]),
    {erl_syntax:block_expr([Bind, Case]), Cx4#cx{vars = Cx#cx.vars}}.

simple_clause(#clause{pos = Pos, pattern = P, guard = G, body = B}, Cx) ->
    {PF, Cx1} = pattern(P, Cx),
    {GF, Cx2} = case G of
                    undefined -> {none, Cx1};
                    _ -> expr(G, Cx1)
                end,
    {BF, Cx3} = body(B, Cx2),
    {at(Pos, erl_syntax:clause([PF], GF, BF)), Cx3#cx{vars = Cx#cx.vars}}.

%% Plan 2.2: in MVP 1 a receive guard must be an Erlang guard expression.
receive_clause(#clause{pos = Pos, guard = G} = C, Cx) ->
    case G =:= undefined orelse erlang_guard(G, Cx) of
        true -> simple_clause(C, Cx);
        false -> fail(Pos, "in MVP 1 a receive guard is a comparison, or && and || of comparisons,"
                           " over variables and literals (report §5.9; general guards come with"
                           " MVP 4)")
    end.

%% Comparisons and Boolean operators over variables and literals.
erlang_guard(#e_binop{op = Op, left = L, right = R}, Cx) when Op =:= '&&'; Op =:= '||' ->
    erlang_guard(L, Cx) andalso erlang_guard(R, Cx);
erlang_guard(#e_binop{op = Op, left = L, right = R}, _) when Op =:= '=='; Op =:= '!=' ->
    guard_operand(L) andalso guard_operand(R);
erlang_guard(#e_binop{op = Op, left = L, right = R}, Cx) when Op =:= '<'; Op =:= '<=';
                                                           Op =:= '>'; Op =:= '>=' ->
    %% an ordering through T.compare is a call (report §3.10)
    Prelude = case resolved(ern_typecheck:node_type(L), Cx) of
                  {tcon, [_], []} -> true;
                  _ -> false
              end,
    Prelude andalso guard_operand(L) andalso guard_operand(R);
erlang_guard(#e_lit{kind = bool}, _) -> true;
erlang_guard(#e_var{path = []}, _) -> true;
erlang_guard(_, _) -> false.

guard_operand(#e_lit{}) -> true;
guard_operand(#e_var{path = []}) -> true;
guard_operand(#e_con{args = none}) -> true;
guard_operand(#e_neg{expr = #e_lit{}}) -> true;
guard_operand(_) -> false.

%%
%% Patterns: pattern(P, Cx) -> {Form, Cx} with the variables bound
%%

pattern(#p_wild{pos = Pos}, Cx) ->
    {at(Pos, erl_syntax:underscore()), Cx};
pattern(#p_var{pos = Pos, name = N}, Cx) ->
    {V, Cx1} = bind(N, Cx),
    {at(Pos, erl_syntax:variable(V)), Cx1};
pattern(#p_lit{pos = Pos, kind = Kind, value = V}, Cx) ->
    {at(Pos, literal(Kind, V)), Cx};
pattern(#p_con{pos = Pos, path = Path, name = Name, args = Args}, Cx) ->
    #cinfo{fields = Fields} = ern_typecheck:lookup_con(Pos, Path, Name, Cx#cx.env),
    Tag = erl_syntax:atom(Name),
    case {Fields, Args} of
        {none, _} -> {at(Pos, Tag), Cx};
        {positional, {positional, P}} ->
            {PF, Cx1} = pattern(P, Cx),
            {at(Pos, erl_syntax:tuple([Tag, PF])), Cx1};
        {{named, Names}, none} ->
            {at(Pos, erl_syntax:tuple([Tag | [erl_syntax:underscore() || _ <- Names]])), Cx};
        {{named, Names}, {named, FPs}} ->
            {Forms, Cx1} = lists:mapfoldl(fun(N, C) ->
                                              case [P || #field_pat{name = FN, pattern = P} <- FPs,
                                                         FN =:= N] of
                                                  [P] -> pattern(P, C);
                                                  [] -> {erl_syntax:underscore(), C}
                                              end
                                          end, Cx, Names),
            {at(Pos, erl_syntax:tuple([Tag | Forms])), Cx1}
    end;
pattern(#p_tuple{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = lists:mapfoldl(fun pattern/2, Cx, Es),
    {at(Pos, erl_syntax:tuple(Forms)), Cx1};
pattern(#p_list{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = lists:mapfoldl(fun pattern/2, Cx, Es),
    {at(Pos, erl_syntax:list(Forms)), Cx1};
pattern(#p_cons{pos = Pos, head = H, tail = T}, Cx) ->
    {HF, Cx1} = pattern(H, Cx),
    {TF, Cx2} = pattern(T, Cx1),
    {at(Pos, erl_syntax:cons(HF, TF)), Cx2};
pattern(#p_as{pos = Pos, pattern = P, name = N}, Cx) ->
    {PF, Cx1} = pattern(P, Cx),
    {V, Cx2} = bind(N, Cx1),
    {at(Pos, erl_syntax:match_expr(erl_syntax:variable(V), PF)), Cx2};
pattern(#p_bits{pos = Pos}, _Cx) ->
    fail(Pos, "bitstrings are not in MVP 1").

%%
%% Variables: every Ernest binding gets a fresh Erlang variable
%%

bind(Name, #cx{vars = Vars, counter = N} = Cx) ->
    V = erlang_var(Name, N + 1),
    {V, Cx#cx{vars = Vars#{Name => V}, counter = N + 1}}.

erlang_var(Name, N) ->
    S = atom_to_list(Name),
    Base = case S of
               [$_ | Rest] -> "V_" ++ Rest;
               [C | Rest] -> [string:to_upper(C) | Rest]
           end,
    list_to_atom(Base ++ "_" ++ integer_to_list(N)).

fresh_vars(Count, Prefix, #cx{counter = N} = Cx) ->
    Vars = [list_to_atom(Prefix ++ "_" ++ integer_to_list(N + I)) || I <- lists:seq(1, Count)],
    {Vars, Cx#cx{counter = N + Count}}.

fresh_name(Name, #cx{counter = N} = Cx) ->
    {list_to_atom(atom_to_list(Name) ++ "$" ++ integer_to_list(N + 1)), Cx#cx{counter = N + 1}}.

%%
%% Helpers
%%

at(Pos, Form) ->
    erl_syntax:set_pos(Form, {element(1, Pos), element(2, Pos)}).

qname(Parts) ->
    lists:flatten(lists:join(".", [atom_to_list(P) || P <- Parts])).

fail(Pos, Message) ->
    throw({compile_error, Pos, lists:flatten(Message)}).
