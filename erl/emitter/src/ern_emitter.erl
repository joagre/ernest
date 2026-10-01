%% The compiler: typed AST to Erlang abstract format, then to a BEAM module
%% with the interface as the chunk "ErnI" (report §11.1): the
%% canonical interface, a hash of the source, and per dependency the hash
%% of the interface compiled against. Values follow report §8.4.
%%
%% One traversal does the three pre-passes on the way: every Ernest binding
%% gets a fresh Erlang variable (Ernest shadows, Erlang does not), local fns
%% are lifted to module functions taking the block's free variables first,
%% and `let p <- e` becomes a case (report §5.5).
-module(ern_emitter).

-export([compile/4, compile/5, forms/3, erl_source/3, erl_source/4, module_atom/1,
         function_atom/1, function_name/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").


%% Emission context, threaded through everything. vars: Ernest name =>
%% Erlang variable name; locals: local fn name => #local{} (see Blocks);
%% lifted: module functions produced by lifting, reversed; tops: top-level
%% {Owner, Name} => arity | value; descs: descriptor term => the name of
%% the module function returning it; pat_guards: Erlang guard forms a
%% pattern needs on its clause, a float segment's zero (report §3.1),
%% taken by the clause that uses them; session: where the module is an
%% input of the shell's session (report §11.2), the lines before its first
%% in its file, since its spawn sites are written as the session writes
%% names; else false.
-record(cx, {ns, mod, env, fname, vars = #{}, counter = 0, locals = #{}, lifted = [],
             tops = #{}, descs = #{}, pat_guards = [], session = false, standard = false}).
%% A local fn of a block (see Blocks).
-record(local, {lifted, own, extra, refs, snap = pending}).

%%
%% Entry points
%%

-spec compile([atom()], [tuple()], #iface{}, ern_typecheck:env()) -> {ok, atom(), binary()}.
compile(Ns, Decls, Iface, Env) ->
    compile(Ns, Decls, Iface, Env, #{source_hash => <<>>, deps => []}).

%% Build: the source's hash and its path from the build root, and the
%% dependencies' interface hashes, go into the chunk beside the interface
%% (report §11.1); `source` goes to the documentation; `session` marks an
%% input of the shell, which is compiled and not written, and is not kept,
%% with the line offset its spawn sites are written with; `standard` marks a
%% module of the standard library's own source root.
%% The declarations are the checker's, so every rule a program can break has
%% been checked: what the emitter cannot emit, or emits and the host does not
%% compile, is a defect of the toolchain, raised as one, which `ern` reports
%% as its own failure (report §11).
-spec compile([atom()], [tuple()], #iface{}, ern_typecheck:env(),
              #{source_hash := binary(), source_path => binary(),
                deps := [{[atom()], binary()}], compiler => binary(),
                stdlib => binary() | none, source => binary(),
                session => non_neg_integer(), standard => boolean()}) ->
          {ok, atom(), binary()}.
compile(Ns, Decls, Iface, Env, Build) ->
    Forms = forms(Ns, Decls, Env, Build),
    Meta = maps:without([source, session, standard], Build),
    Chunk = ern_iface:encode(Meta, Iface),
    Docs = term_to_binary(ern_docs:build(Ns, Decls, Env, maps:get(source, Build, <<>>))),
    Chunks = [{ern_iface:chunk_name(), Chunk}, {ern_docs:chunk_name(), Docs}],
    case compile:forms(Forms, [return_errors, debug_info, {extra_chunks, Chunks}]) of
        {ok, Mod, Bin} -> {ok, Mod, Bin};
        {error, Errors, _} -> erlang:error({emitted_erlang_does_not_compile, Errors})
    end.

%% The abstract forms, for the golden tests and erl_prettypr.
-spec forms([atom()], [tuple()], ern_typecheck:env()) -> [erl_parse:abstract_form()].
forms(Ns, Decls, Env) ->
    forms(Ns, Decls, Env, #{}).

%% Report §8.5: with the modules this one depends on, which it declares
%% as `'$deps'/0` so that the runtime can evaluate top-level bindings in
%% dependency order without reading a compiled file.
-spec forms([atom()], [tuple()], ern_typecheck:env(), map()) -> [erl_parse:abstract_form()].
forms(Ns, Decls, Env, Build) ->
    Mod = module_atom(Ns),
    Deps = [D || {D, _} <- maps:get(deps, Build, [])],
    Cx0 = #cx{ns = Ns, mod = Mod, env = Env, tops = top_names(Decls),
              session = maps:get(session, Build, false),
              standard = maps:get(standard, Build, false)},
    {Funs, Cx1} = lists:mapfoldl(fun decl/2, Cx0, Decls),
    Lets = [D || #let_decl{} = D <- Decls],
    {Init, Cx2} = init_fun(Lets, Cx1),
    Tests = tests_fun(Lets),
    DepsFun = deps_fun(Deps),
    FunFun = fun_fun(Decls),
    Exports = [export(D) || D <- Decls, exported(D)] ++ [{'$init', 0} || Lets =/= []]
        ++ [{'$tests', 0} || Tests =/= []] ++ [{'$deps', 0} || DepsFun =/= []]
        ++ [{'$fun', 2} || FunFun =/= []],
    %% an Ernest function named like an auto-imported BIF, `size`, `max`,
    %% is called by its own name: the auto-import is switched off for it
    Clashes = [{F, A} || {F, A} <- maps:fold(fun({O, N}, Arity, Acc) when is_integer(Arity) ->
                                                    [{fname(O, N), Arity} | Acc];
                                                ({O, N}, value, Acc) ->
                                                    [{fname(O, N), 0} | Acc]
                                             end, [], Cx0#cx.tops),
                         erl_internal:bif(F, A)],
    NoImport = case Clashes of
                   [] -> [];
                   _ -> [erl_syntax:attribute(erl_syntax:atom(compile),
                                              [erl_syntax:abstract({no_auto_import, Clashes})])]
               end,
    Attrs = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Mod)])]
            ++ NoImport
            ++ [erl_syntax:attribute(erl_syntax:atom(export),
                                     [erl_syntax:list([erl_syntax:arity_qualifier(
                                                         erl_syntax:atom(F), erl_syntax:integer(A))
                                                       || {F, A} <- Exports])])],
    Functions = lists:append(Funs) ++ Init ++ Tests ++ DepsFun ++ FunFun
        ++ lists:reverse(Cx2#cx.lifted),
    erl_syntax:revert_forms(Attrs ++ Functions).

%% Report Appendix E.24, §11.2: '$tests'/0 lists the module's tests, every
%% top-level let of type Test.Case, exported or not, for `ern test`.
tests_fun(Lets) ->
    Names = [fname(undefined, N) || #let_decl{name = N, type = Scheme} <- Lets,
                            Scheme#scheme.type =:= {tcon, ['Test', 'Case'], []}],
    case Names of
        [] -> [];
        _ ->
            %% the list is built a test at a time, from the last, so that no
            %% more than the list so far is live at a call: a list of every
            %% call at once passes the host's limit of live values
            {Matches, List} =
                lists:foldl(fun(F, {Acc, Tail}) ->
                                    V = erl_syntax:variable(
                                          list_to_atom("T" ++ integer_to_list(length(Acc)))),
                                    Head = erl_syntax:application(erl_syntax:atom(F), []),
                                    {[erl_syntax:match_expr(V, erl_syntax:cons(Head, Tail)) | Acc],
                                     V}
                            end, {[], erl_syntax:nil()}, lists:reverse(Names)),
            [erl_syntax:function(erl_syntax:atom('$tests'),
                                 [erl_syntax:clause([], none, lists:reverse(Matches) ++ [List])])]
    end.

%% Report §11.2, §6.10: '$fun'/2 answers an exported function of this
%% module as a fun of the version that answers, so that a function value
%% another module takes from this one keeps the code it was taken from when
%% the module is loaded again; an external fun would reach the newest.
fun_fun(Decls) ->
    Clauses = [erl_syntax:clause([erl_syntax:atom(F), erl_syntax:integer(A)], none,
                                 [erl_syntax:implicit_fun(erl_syntax:atom(F),
                                                          erl_syntax:integer(A))])
               || D <- Decls, exported(D), not is_record(D, let_decl), nameable(D),
                  {F, A} <- [export(D)]],
    case Clauses of
        [] -> [];
        _ -> [erl_syntax:function(erl_syntax:atom('$fun'), Clauses)]
    end.

%% Report §2.3: a function whose own name holds `$`, the entry of an input
%% at the shell's prompt, is named by no program, so none takes it as a
%% value. It has no clause: each clause is a function the host keeps an
%% entry for as long as the node lives, for every version of the module it
%% loads.
nameable(#fn_decl{name = N}) -> not lists:member($$, atom_to_list(N));
nameable(#foreign_fn_decl{name = N}) -> not lists:member($$, atom_to_list(N)).

%% Report §8.5: the modules this one depends on, whose top-level
%% bindings are evaluated before its own.
deps_fun([]) ->
    [];
deps_fun(Deps) ->
    Mods = erl_syntax:list([erl_syntax:atom(module_atom(D)) || D <- Deps]),
    [erl_syntax:function(erl_syntax:atom('$deps'),
                         [erl_syntax:clause([], none, [Mods])])].

%% The module as Erlang source, for --emit-erl (report §11.1).
-spec erl_source([atom()], [tuple()], ern_typecheck:env()) -> unicode:chardata().
erl_source(Ns, Decls, Env) ->
    erl_source(Ns, Decls, Env, #{}).

-spec erl_source([atom()], [tuple()], ern_typecheck:env(), map()) -> unicode:chardata().
erl_source(Ns, Decls, Env, Build) ->
    Forms = forms(Ns, Decls, Env, Build),
    [erl_prettypr:format(erl_syntax:form_list(Forms)), "\n"].

%% Report §4.2: the path with @ for / and the prefix ern@.
-spec module_atom([atom()]) -> atom().
module_atom(Ns) ->
    list_to_atom(lists:flatten(["ern" | ["@" ++ string:lowercase(atom_to_list(P))
                                         || P <- Ns]])).

%%
%% Declarations
%%

top_names(Decls) ->
    maps:from_list([{{O, N}, length(Ps)} || #fn_decl{owner = O, name = N, params = Ps} <- Decls]
                   ++ [{{O, N}, length(Ps)}
                       || #foreign_fn_decl{owner = O, name = N, params = Ps} <- Decls]
                   ++ [{{undefined, N}, value} || #let_decl{name = N} <- Decls]).

exported(#fn_decl{export = E}) -> E;
exported(#let_decl{export = E}) -> E;
exported(#foreign_fn_decl{export = E}) -> E;
exported(_) -> false.

export(#fn_decl{owner = O, name = N, params = Ps}) -> {fname(O, N), length(Ps)};
export(#foreign_fn_decl{owner = O, name = N, params = Ps}) -> {fname(O, N), length(Ps)};
export(#let_decl{name = N}) -> {fname(undefined, N), 0}.

fname(undefined, N) -> function_atom(N);
fname(Owner, N) -> list_to_atom(atom_to_list(Owner) ++ "." ++ atom_to_list(N)).

%% The Erlang function a top-level Ernest name compiles to: its own name,
%% but for the names the host gives every module, `module_info/0,1` and the
%% pseudo-function `record_info/2`, which get a `$`, as no Ernest name can
%% spell. A program may name a function anything; the collision is the
%% host's, and nothing the program or the report sees.
-spec function_atom(atom()) -> atom().
function_atom(module_info) -> 'module_info$';
function_atom(record_info) -> 'record_info$';
function_atom(N) -> N.

%% The Erlang function a top-level declaration compiles to, its owner a type
%% or undefined, for the documentation chunk's keys.
-spec function_name(atom() | undefined, atom()) -> atom().
function_name(Owner, Name) ->
    fname(Owner, Name).

decl(#fn_decl{pos = Pos, owner = O, name = N, params = Params, body = Body}, Cx) ->
    Name = fname(O, N),
    Cx1 = Cx#cx{fname = Name, vars = #{}, locals = #{}},
    {Pats, Cx2} = lists:mapfoldl(fun(#param{pattern = P}, C) -> pattern(P, C) end, Cx1, Params),
    {BodyForms, Cx3} = body(Body, Cx2),
    Clause = at(Pos, erl_syntax:clause(Pats, none, BodyForms)),
    {[at(Pos, erl_syntax:function(erl_syntax:atom(Name), [Clause]))], Cx3#cx{vars = #{}}};
decl(#let_decl{pos = Pos, name = N}, Cx) ->
    %% the getter; the value is computed by '$init'/0 (report §8.5)
    Name = fname(undefined, N),
    Get = call_remote(ern_rt, binding, [key(Cx, Name)]),
    Clause = at(Pos, erl_syntax:clause([], none, [Get])),
    {[at(Pos, erl_syntax:function(erl_syntax:atom(Name), [Clause]))], Cx};
decl(#foreign_fn_decl{pos = Pos, owner = O, name = N, params = Params, impl = Impl,
                      type = Scheme}, Cx) ->
    %% report §4.7, §8.4: the implementation called in place, an exception
    %% it raises turned into a fault, and its return checked
    Name = fname(O, N),
    {ok, {M, F, _}} = ern_typecheck:foreign_impl(Impl),
    {Vars, Cx1} = fresh_vars(length(Params), "A", Cx#cx{fname = Name}),
    {tfn, ParamTs, Effect, Ret} = Scheme#scheme.type,
    Args = [erl_syntax:variable(V) || V <- Vars],
    {Exposed, Cx2} = lists:mapfoldl(fun exposed/2, Cx1, lists:zip(ParamTs, Args)),
    Call = erl_syntax:application(erl_syntax:atom(M), erl_syntax:atom(F), Exposed),
    %% report §8.6: a foreign call in progress can still deliver, so it is
    %% counted while it runs; a standard library function without a mailbox
    %% type waits on no process, and is not
    Run = case Cx#cx.standard andalso Effect =:= pure of
              true -> Call;
              false -> call_remote(ern_rt, in_foreign,
                                   [erl_syntax:fun_expr([erl_syntax:clause([], none, [Call])])])
          end,
    {[Class, Reason, Stack], Cx3} = fresh_vars(3, "E", Cx2),
    Raised = call_remote(ern_boundary, raised,
                         [erl_syntax:atom(M), erl_syntax:atom(F),
                          erl_syntax:integer(length(Params)) | [erl_syntax:variable(V)
                                                                 || V <- [Class, Reason, Stack]]]),
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:variable(Class),
                                                            erl_syntax:variable(Reason),
                                                            erl_syntax:variable(Stack))],
                                none, [Raised]),
    Try = erl_syntax:try_expr([Run], [Handler]),
    %% report §8.4: the standard library's return is the runtime's own, and
    %% not checked; a type variable of the result that no parameter names
    %% stands for no value the function could have been given, so it
    %% matches none, and the return faults where it holds one
    Named = lists:append([type_vars(P) || P <- ParamTs]),
    Unnamed = [V || V <- lists:usort(type_vars(Ret)), not lists:member(V, Named)],
    {Body, Cx4} = case Cx#cx.standard of
                      true -> {Try, Cx3};
                      false -> check_form(as_never(Unnamed, Ret), Ret, Try,
                                          "foreign return does not match ", Cx3)
                  end,
    Clause = at(Pos, erl_syntax:clause(Args, none, [Body])),
    {[at(Pos, erl_syntax:function(erl_syntax:atom(Name), [Clause]))], Cx4};
decl(_, Cx) ->
    {[], Cx}.

key(#cx{mod = Mod}, Name) ->
    erl_syntax:tuple([erl_syntax:atom(Mod), erl_syntax:atom(Name)]).

%% '$init'/0 evaluates the top-level lets once, in dependency order, each
%% named as the process's site while it runs, so that its fault is reported
%% under it (report §8.5, §11.2).
init_fun([], Cx) ->
    {[], Cx};
init_fun(Lets, Cx) ->
    {Stores, Cx1} = lists:mapfoldl(
                      fun(#let_decl{pos = Pos, name = N, body = Body}, C) ->
                              C0 = C#cx{fname = fname(undefined, N), vars = #{}, locals = #{}},
                              Named = call_remote(ern_rt, initializing, [site(Pos, C0)]),
                              {BodyForm, C1} = expr(Body, C0),
                              Store = call_remote(persistent_term, put,
                                                  [key(C, fname(undefined, N)), BodyForm]),
                              {[Named, Store], C1}
                      end, Cx, let_order(Lets, Cx)),
    Clause = erl_syntax:clause([], none, lists:append(Stores) ++ [erl_syntax:atom(ok)]),
    {[erl_syntax:function(erl_syntax:atom('$init'), [Clause])], Cx1}.

%% Report §8.5: the lets in the order the checker found, a let after
%% those its initializer reaches and otherwise as declared.
let_order(Lets, #cx{env = Env}) ->
    ByKey = maps:from_list([{{undefined, N}, D} || #let_decl{name = N} = D <- Lets]),
    [maps:get(K, ByKey) || K <- ern_typecheck:let_order(Env)].

%%
%% Expressions: expr(E, Cx) -> {Form, Cx}
%%

expr(#e_lit{pos = Pos, kind = Kind, value = V}, Cx) ->
    {at(Pos, literal(Kind, V)), Cx};
expr(#e_var{pos = Pos, path = Path, name = Name, type = T, ref = Ref}, Cx) ->
    {Form, Cx1} = var_ref(Pos, Path, Name, Ref, T, Cx),
    {at(Pos, Form), Cx1};
expr(#e_con{pos = Pos, path = Path, name = Name, args = Args}, Cx) ->
    con_expr(Pos, Path, Name, Args, Cx);
expr(#e_tuple{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = exprs(Es, Cx),
    {at(Pos, erl_syntax:tuple(Forms)), Cx1};
expr(#e_list{pos = Pos, elems = Es}, Cx) ->
    {Forms, Cx1} = exprs(Es, Cx),
    {at(Pos, erl_syntax:list(Forms)), Cx1};
expr(#e_bits{pos = Pos, segments = Segs}, Cx) ->
    %% report §5.11, §7.4: the runtime's bit syntax, each segment's value
    %% checked for its width by ern_bits, a badarg the segment overflow
    %% fault, and the result checked for alignment when a dynamic size
    %% leaves the bit count open
    {Fields, {Cx1, Open}} =
        lists:mapfoldl(fun(#bit_seg{value = V, specs = Specs}, {C, O}) ->
                           {ok, Spec} = ern_bitspec:spec(Specs),
                           {VF, C1} = expr(V, C),
                           {SizeF, C2} = size_form(Spec, C1),
                           Checked = segment_value(Spec, VF, SizeF),
                           {erl_syntax:binary_field(Checked, SizeF, type_specs(Spec)),
                            {C2, O orelse open(Spec)}}
                       end, {Cx, false}, Segs),
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(erl_syntax:atom(error),
                                                            erl_syntax:atom(badarg))],
                                none, [call_remote(ern_bits, overflow, [])]),
    Built = erl_syntax:try_expr([erl_syntax:binary(Fields)], [], [Handler]),
    Form = case Open of
               true -> call_remote(ern_bits, aligned, [Built]);
               false -> Built
           end,
    {at(Pos, Form), Cx1};
expr(#e_block{pos = Pos, stmts = Stmts}, Cx) ->
    {Forms, Cx1} = block(Stmts, Cx),
    {at(Pos, erl_syntax:block_expr(Forms)), Cx1#cx{vars = Cx#cx.vars, locals = Cx#cx.locals}};
expr(#e_call{pos = Pos, callee = Callee, args = [X | Rest], pipe = true}, Cx)
  when not is_record(Callee, e_var), not is_record(Callee, e_con),
       not is_record(Callee, e_lambda) ->
    %% report §5.1: in `x |> e`, x is evaluated before a callee that is
    %% evaluated at all, and the other arguments after it
    {XF, Cx1} = expr(X, Cx),
    {[V], Cx2} = fresh_vars(1, "Piped", Cx1),
    {CalleeForm, Cx3} = expr(Callee, Cx2),
    {RestForms, Cx4} = exprs(Rest, Cx3),
    Var = erl_syntax:variable(V),
    App = erl_syntax:application(CalleeForm, [Var | RestForms]),
    {at(Pos, erl_syntax:block_expr([erl_syntax:match_expr(Var, XF), App])), Cx4};
expr(#e_call{pos = Pos, callee = Callee, args = Args}, Cx) ->
    call(Pos, Callee, Args, Cx);
expr(#e_not{pos = Pos, expr = X}, Cx) ->
    {Form, Cx1} = expr(X, Cx),
    {at(Pos, erl_syntax:prefix_expr(erl_syntax:operator('not'), Form)), Cx1};
expr(#e_select{pos = Pos, expr = X, field = F}, Cx) ->
    {Form, Cx1} = expr(X, Cx),
    select(Pos, F, ern_typecheck:node_type(X), Form, Cx1);
expr(#e_neg{pos = Pos, expr = X}, Cx) ->
    {Form, Cx1} = expr(X, Cx),
    {at(Pos, negate(resolved(ern_typecheck:node_type(X), Cx), Form, Cx)), Cx1};
expr(#e_binop{pos = Pos, op = Op, left = L, right = R}, Cx) ->
    {LF, Cx1} = expr(L, Cx),
    {RF, Cx2} = expr(R, Cx1),
    case resolved(ern_typecheck:node_type(L), Cx) of
        {tcon, ['Float'], []} when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/' ->
            {[A, B], Cx3} = fresh_vars(2, "F", Cx2),
            {at(Pos, float_op(Op, LF, RF, A, B)), Cx3};
        T ->
            {at(Pos, binop(Op, T, LF, RF, Cx)), Cx2}
    end;
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
expr(#e_match{pos = Pos, scrutinee = S, clauses = Clauses0}, Cx) ->
    {SF, Cx1} = expr(S, Cx),
    %% report §5.11: a top-level `let` a pattern's size names is read into a
    %% variable when the match begins, after its scrutinee (§5.1: left to
    %% right), which is then matched from a variable of its own
    case lists:mapfoldl(fun read_sizes/2, {[], Cx1}, Clauses0) of
        {Clauses, {[], Cx2}} ->
            {Form, Cx3} = match_clauses(SF, Clauses, Cx2),
            {at(Pos, Form), Cx3};
        {Clauses, {Reads, Cx2}} ->
            {[Scrutinee], Cx3} = fresh_vars(1, "Scrutinee", Cx2),
            Evaluated = erl_syntax:match_expr(erl_syntax:variable(Scrutinee), SF),
            {Form, Cx4} = match_clauses(erl_syntax:variable(Scrutinee), Clauses, Cx3),
            {at(Pos, with_binds([Evaluated | Reads], Form)), Cx4}
    end;
expr(#e_receive{pos = Pos, clauses = Clauses0, 'after' = After}, Cx0) ->
    %% report §6.3: a receive guard is a guard expression, which the
    %% checker holds it to, so it is an Erlang guard here, a top-level `let`
    %% it names, or a pattern's size names (§5.11), read into a variable
    %% before the receive; a message from a foreign process was checked by
    %% the proxy that delivered it (§8.4)
    {Clauses, {Reads, Cx}} = lists:mapfoldl(fun read_before/2, {[], Cx0}, Clauses0),
    {Parts, Cx1} = lists:mapfoldl(fun simple_clauses/2, Cx, Clauses),
    {Binds0, OwnForms} = join_parts(Parts),
    Binds = Reads ++ Binds0,
    %% report §6.9: a restart a supervisor asks for arrives before every
    %% other message and is taken here, first
    ClauseForms = [erl_syntax:clause([erl_syntax:atom('$ern_restart')], none,
                                     [call_remote(ern_rt, restart_now, [])])
                   | OwnForms],
    case After of
        undefined ->
            {at(Pos, with_binds(Binds, erl_syntax:receive_expr(ClauseForms))), Cx1};
        #after_clause{timeout = T, body = B} ->
            %% report §8.6: a timed receive counts itself in before, and out
            %% first in every body, so the reaper knows it is not waiting
            {TF, Cx2} = expr(T, Cx1),
            {BF, Cx3} = body(B, Cx2),
            %% report §6.3: a time below 0 is 0, and none is too long; the
            %% host waits at most 2^32 - 1 ms at once, so the receive is
            %% entered again until the deadline has passed (ern_rt:deadline/1)
            {[D], Cx4} = fresh_vars(1, "Deadline", Cx3),
            {[W], Cx5} = fresh_vars(1, "Wait", Cx4),
            Deadline = erl_syntax:variable(D),
            Remaining = call_remote(ern_rt, remaining, [Deadline]),
            Untimed = call_remote(ern_rt, untimed, []),
            Timed = [erl_syntax:clause(erl_syntax:clause_patterns(C), erl_syntax:clause_guard(C),
                                       [Untimed | erl_syntax:clause_body(C)])
                     || C <- ClauseForms],
            Due = erl_syntax:case_expr(
                    Remaining,
                    [erl_syntax:clause([erl_syntax:integer(0)], none, [Untimed | BF]),
                     erl_syntax:clause([erl_syntax:underscore()], none,
                                       [erl_syntax:application(erl_syntax:variable(W), [])])]),
            Recv = erl_syntax:receive_expr(Timed, Remaining, [Due]),
            Wait = erl_syntax:named_fun_expr(erl_syntax:variable(W),
                                             [erl_syntax:clause([], none, [Recv])]),
            Enter = [erl_syntax:match_expr(Deadline, call_remote(ern_rt, deadline, [TF])),
                     call_remote(ern_rt, timed, [])],
            {at(Pos, with_binds(Binds ++ Enter, erl_syntax:application(Wait, []))), Cx5}
    end.

exprs(Es, Cx) ->
    lists:mapfoldl(fun expr/2, Cx, Es).

%% Report §6.3, §5.11: each top-level `let` a receive clause's guard or its
%% pattern's sizes name, read into a fresh variable that names it in its
%% place.
read_before(C, Acc) ->
    {C1, Acc1} = read_sizes(C, Acc),
    read_guard(C1, Acc1).

read_guard(#clause{guard = undefined} = C, Acc) ->
    {C, Acc};
read_guard(#clause{guard = G} = C, Acc) ->
    {G1, Acc1} = read_top(G, Acc),
    {C#clause{guard = G1}, Acc1}.

%% Report §5.11: each top-level `let` a clause's pattern names in a size.
read_sizes(#clause{pattern = P} = C, Acc) ->
    {P1, Acc1} = sizes_read(P, Acc),
    {C#clause{pattern = P1}, Acc1}.

sizes_read(#bit_seg{specs = Specs} = S, Acc) ->
    {Specs1, Acc1} = lists:mapfoldl(fun({size, E}, A) ->
                                            {E1, A1} = read_top(E, A),
                                            {{size, E1}, A1};
                                       (Spec, A) ->
                                            {Spec, A}
                                    end, Acc, Specs),
    {S#bit_seg{specs = Specs1}, Acc1};
sizes_read(T, Acc) when is_tuple(T), tuple_size(T) > 0, is_atom(element(1, T)) ->
    [Tag | Fields] = tuple_to_list(T),
    {Fields1, Acc1} = lists:mapfoldl(fun sizes_read/2, Acc, Fields),
    {list_to_tuple([Tag | Fields1]), Acc1};
sizes_read(L, Acc) when is_list(L) ->
    lists:mapfoldl(fun sizes_read/2, Acc, L);
sizes_read(X, Acc) ->
    {X, Acc}.

read_top(#e_binop{left = L, right = R} = B, Acc) ->
    {L1, Acc1} = read_top(L, Acc),
    {R1, Acc2} = read_top(R, Acc1),
    {B#e_binop{left = L1, right = R1}, Acc2};
read_top(#e_not{expr = X} = N, Acc) ->
    {X1, Acc1} = read_top(X, Acc),
    {N#e_not{expr = X1}, Acc1};
read_top(#e_neg{expr = X} = N, Acc) ->
    {X1, Acc1} = read_top(X, Acc),
    {N#e_neg{expr = X1}, Acc1};
read_top(#e_var{ref = Ref} = V, {Reads, Cx}) when Ref =/= var ->
    {Form, Cx1} = expr(V, Cx),
    {[E], Cx2} = fresh_vars(1, "Read", Cx1),
    {V#e_var{path = [], name = E, ref = var},
     {Reads ++ [erl_syntax:match_expr(erl_syntax:variable(E), Form)],
      Cx2#cx{vars = maps:put(E, E, Cx2#cx.vars)}}};
read_top(X, Acc) ->
    {X, Acc}.

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

%% A name used as a value: var_ref(...) -> {Form, Cx}. Report §4.2: what
%% the name refers to is the checker's `ref`, read and not decided here.
var_ref(Pos, _, Name, var, T, #cx{vars = Vars, locals = Locals} = Cx) ->
    case Vars of
        #{Name := V} -> {var_form(V), Cx};
        _ ->
            #{Name := #local{lifted = Lifted}} = Locals,
            closure(Lifted, instances(Name, Cx), arity_of(T, Pos), Cx)
    end;
%% Appendix E.1: the library's Io.show and Io.debug as values too, the
%% descriptor of the argument's type, named by the checker's ref from
%% another module and from the library's own, and never by the path
var_ref(Pos, _, Name, {remote, ['Io'], undefined, Name}, T, Cx)
  when Name =:= show; Name =:= debug ->
    prelude_value(Pos, ['Io', Name], T, Cx);
var_ref(Pos, _, Name, {own, undefined, Name}, T, #cx{mod = 'ern@io'} = Cx)
  when Name =:= show; Name =:= debug ->
    prelude_value(Pos, ['Io', Name], T, Cx);
var_ref(Pos, _, _, {prelude, Q}, T, Cx) ->
    prelude_value(Pos, Q, T, Cx);
var_ref(_, _, _, {own, Owner, Name}, _, Cx) ->
    {own_value(Owner, Name, Cx), Cx};
var_ref(_, _, _, {remote, Module, Owner, Name}, T, #cx{env = Env} = Cx) ->
    {remote_value(Module, Owner, Name, T, Env), Cx}.

%% Report §4.6: a `let` is a value, reached through its getter even where it
%% holds a function; a `fn` is the function itself.
own_value(Owner, Name, #cx{tops = Tops}) ->
    Local = erl_syntax:atom(fname(Owner, Name)),
    case maps:get({Owner, Name}, Tops) of
        value -> erl_syntax:application(Local, []);
        Arity -> erl_syntax:implicit_fun(Local, erl_syntax:integer(Arity))
    end.

remote_value(Module, Owner, Name, T, Env) ->
    {M, F} = remote_name(Module, Owner, Name),
    case {is_value(Module, Owner, Name, Env), T} of
        {false, {tfn, Ps, _, _}} ->
            %% report §11.2: a function of another module as a value keeps
            %% the version it was taken from
            call_remote(M, '$fun', [erl_syntax:atom(F), erl_syntax:integer(length(Ps))]);
        _ ->
            call_remote(M, F, [])
    end.

arity_of({tfn, Ps, _, _}, _) -> length(Ps);
arity_of(_, Pos) -> fail(Pos, "a local function used as a value must have a function type").

%% Report §4.6: whether another module's declaration is a `let`, which
%% its interface says (§11.1).
is_value(Module, Owner, Name, Env) ->
    ern_typecheck:is_value(Module ++ [Owner || Owner =/= undefined] ++ [Name], Env).

%% Another Ernest module's declaration as a function of its Erlang module.
remote_name(Module, Owner, Name) ->
    {module_atom(Module), fname(Owner, Name)}.

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

call(Pos, #e_var{ref = var, name = Name}, Args, Cx) ->
    #cx{vars = Vars, locals = Locals} = Cx,
    {ArgForms, Cx1} = exprs(Args, Cx),
    case Vars of
        #{Name := V} ->
            {at(Pos, erl_syntax:application(var_form(V), ArgForms)), Cx1};
        _ ->
            #{Name := #local{lifted = Lifted}} = Locals,
            Insts = [erl_syntax:variable(V) || V <- instances(Name, Cx)],
            App = erl_syntax:application(erl_syntax:atom(Lifted), Insts ++ ArgForms),
            {at(Pos, App), Cx1}
    end;
%% Appendix E.1: the library's Io.show and Io.debug, as var_ref/6 names
%% them, written by the argument's type at the call
call(Pos, #e_var{ref = {remote, ['Io'], undefined, Name}}, [A], Cx)
  when Name =:= show; Name =:= debug ->
    io_call(Pos, Name, A, Cx);
call(Pos, #e_var{ref = {own, undefined, Name}}, [A], #cx{mod = 'ern@io'} = Cx)
  when Name =:= show; Name =:= debug ->
    io_call(Pos, Name, A, Cx);
call(Pos, #e_var{ref = {prelude, Q}} = Callee, Args, Cx) ->
    %% report §4.2: the prelude's, `Prelude.x` among them
    {ArgForms, Cx1} = exprs(Args, Cx),
    prelude_call(Pos, Q, Args, ArgForms, Callee, Cx1);
call(Pos, #e_var{ref = {own, Owner, Name}}, Args, Cx) ->
    {ArgForms, Cx1} = exprs(Args, Cx),
    {at(Pos, own_call(Owner, Name, ArgForms, Cx)), Cx1};
call(Pos, #e_var{ref = {remote, Module, Owner, Name}}, Args, #cx{env = Env} = Cx) ->
    {ArgForms, Cx1} = exprs(Args, Cx),
    {M, F} = remote_name(Module, Owner, Name),
    %% report §4.6: calling a `let` applies what its getter answers;
    %% calling a `fn` is the call itself
    case is_value(Module, Owner, Name, Env) of
        true ->
            Get = call_remote(M, F, []),
            {at(Pos, erl_syntax:application(Get, ArgForms)), Cx1};
        false ->
            {at(Pos, call_remote(M, F, ArgForms)), Cx1}
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

io_call(Pos, Name, Argument, Cx) ->
    {[ArgumentForm], Cx1} = exprs([Argument], Cx),
    Descriptor = erl_syntax:abstract(descriptor(ern_typecheck:node_type(Argument), Cx)),
    {at(Pos, call_remote(ern_io, Name, [ArgumentForm, Descriptor])), Cx1}.

%% Report §4.6: a call of the module's own declaration, a `let` through
%% what its getter answers.
own_call(Owner, Name, ArgForms, #cx{tops = Tops}) ->
    Local = erl_syntax:atom(fname(Owner, Name)),
    case maps:get({Owner, Name}, Tops) of
        value -> erl_syntax:application(erl_syntax:application(Local, []), ArgForms);
        _ -> erl_syntax:application(Local, ArgForms)
    end.

%% fun M:F/A
remote_fun(M, F, Arity) ->
    erl_syntax:implicit_fun(erl_syntax:atom(M), erl_syntax:atom(F), erl_syntax:integer(Arity)).

call_remote(M, F, Args) ->
    erl_syntax:application(erl_syntax:module_qualifier(erl_syntax:atom(M), erl_syntax:atom(F)),
                           Args).

%%
%% The prelude, report §9
%%

prelude_call(Pos, [self], [], [], _, Cx) -> {at(Pos, call_remote(ern_rt, self, [])), Cx};
prelude_call(Pos, [send], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, send, Args)), Cx};
prelude_call(Pos, [answer], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, answer, Args)), Cx};
prelude_call(Pos, [via], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, via, Args)), Cx};
prelude_call(Pos, [monitor], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, monitor, Args)), Cx};
prelude_call(Pos, [kill], _, Args, _, Cx) -> {at(Pos, call_remote(ern_rt, kill, Args)), Cx};
prelude_call(Pos, [spawn], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, spawn, Args ++ [site(Pos, Cx)])), Cx};
prelude_call(Pos, [spawnMonitored], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, spawn_monitored, Args ++ [site(Pos, Cx)])), Cx};
prelude_call(Pos, ['Address', call], _, Args, #e_var{type = T}, Cx) ->
    {Form, Cx1} = reply_call(call, Args, T, Cx),
    {at(Pos, Form), Cx1};
prelude_call(Pos, ['Address', callForever], _, Args, #e_var{type = T}, Cx) ->
    {Form, Cx1} = reply_call(call_forever, Args, T, Cx),
    {at(Pos, Form), Cx1};
prelude_call(Pos, [restarting], _, Args, _, Cx) ->
    {at(Pos, call_remote(ern_rt, restarting, Args)), Cx};
prelude_call(Pos, [fault], _, [Msg], _, Cx) ->
    {at(Pos, call_remote(ern_rt, fault, [Msg])), Cx};
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

%% Report §6.6, §8.4: `Address.call` or `Address.callForever`, of type T,
%% and in a program what an answer from foreign code is checked by, the
%% Reply's type, as a foreign function's return is; a call the standard
%% library makes is the runtime's own, and checks nothing.
reply_call(F, Args, _, #cx{standard = true} = Cx) ->
    {call_remote(ern_rt, F, Args), Cx};
reply_call(F, Args, T, Cx) ->
    {tfn, [_, {tfn, [ReplyT], _, _} | _], _, _} = resolved(T, Cx),
    {tcon, ['Reply'], [A]} = resolved(ReplyT, Cx),
    {Check, Cx1} = case descriptor(A, Cx) of
                       any ->
                           {erl_syntax:atom(none), Cx};
                       Desc ->
                           {DescForm, C} = desc_ref(Desc, Cx),
                           {erl_syntax:tuple([DescForm,
                                              check_text("reply does not match ", A, Cx)]), C}
                   end,
    {call_remote(ern_rt, F, Args ++ [Check]), Cx1}.

%% A prelude name taken as a value: prelude_value(...) -> {Form, Cx}.
prelude_value(Pos, [spawn], _, Cx) ->
    %% a closure, since spawn takes the site as a third argument
    {[W, F], Cx1} = fresh_vars(2, "A", Cx),
    Args = [erl_syntax:variable(W), erl_syntax:variable(F), site(Pos, Cx)],
    {lambda([W, F], call_remote(ern_rt, spawn, Args)), Cx1};
prelude_value(Pos, [spawnMonitored], _, Cx) ->
    {[W, F, Wrap], Cx1} = fresh_vars(3, "A", Cx),
    Args = [erl_syntax:variable(V) || V <- [W, F, Wrap]] ++ [site(Pos, Cx)],
    {lambda([W, F, Wrap], call_remote(ern_rt, spawn_monitored, Args)), Cx1};
prelude_value(Pos, ['Address', Name], T, Cx) when Name =:= call; Name =:= callForever ->
    F = case Name of call -> call; callForever -> call_forever end,
    {Vars, Cx1} = fresh_vars(arity_of(T, Pos), "A", Cx),
    {Body, Cx2} = reply_call(F, [erl_syntax:variable(V) || V <- Vars], T, Cx1),
    {lambda(Vars, Body), Cx2};
prelude_value(_, ['Int', Op], _, Cx) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/';
                                          Op =:= '%' ->
    {[A, B], Cx1} = fresh_vars(2, "A", Cx),
    Body = binop(Op, {tcon, ['Int'], []}, erl_syntax:variable(A), erl_syntax:variable(B), Cx),
    {lambda([A, B], Body), Cx1};
prelude_value(_, ['Int', negate], _, Cx) ->
    {[A], Cx1} = fresh_vars(1, "A", Cx),
    {lambda([A], erl_syntax:prefix_expr(erl_syntax:operator('-'), erl_syntax:variable(A))), Cx1};
prelude_value(_, [_, '<>'], {tfn, [P | _], _, _}, Cx) ->
    {[A, B], Cx1} = fresh_vars(2, "A", Cx),
    Body = binop('<>', resolved(P, Cx), erl_syntax:variable(A), erl_syntax:variable(B), Cx),
    {lambda([A, B], Body), Cx1};
prelude_value(_, ['Io', Name], {tfn, [P], _, _}, Cx) when Name =:= show; Name =:= debug ->
    {[A], Cx1} = fresh_vars(1, "A", Cx),
    Desc = erl_syntax:abstract(descriptor(P, Cx)),
    {lambda([A], call_remote(ern_io, Name, [erl_syntax:variable(A), Desc])), Cx1};
prelude_value(Pos, [Name], T, Cx) ->
    case lists:member(Name, [self, send, answer, via, monitor, kill, fault, restarting]) of
        true -> {remote_fun(ern_rt, Name, arity_of(T, Pos)), Cx};
        false -> fail(Pos, "no emission for " ++ atom_to_list(Name))
    end;
prelude_value(_, [Ns | Rest], T, Cx) ->
    Form = case T of
               {tfn, Ps, _, _} -> remote_fun(module_atom([Ns]), lists:last(Rest), length(Ps));
               _ ->
                   %% a stdlib value: Map.empty, Set.empty
                   call_remote(module_atom([Ns]), lists:last(Rest), [])
           end,
    {Form, Cx}.

lambda(Vars, Body) ->
    erl_syntax:fun_expr([erl_syntax:clause([erl_syntax:variable(V) || V <- Vars], none, [Body])]).

%% Report §6.9: the function that called `spawn`, qualified, and the line.
%% Report §11.2: in the session, as the session writes names: a function an
%% input declares by its own name, and the input's expression as its
%% diagnostics name it, `input 3`; the line as they count it. The input's
%% name is asked of the shell when the spawn runs, and is not the module's
%% code: an input typed again then compiles to the code it did before, and
%% the host keeps an entry for each lambda of each version it loads
%% (docs/memory.md).
site(Pos, #cx{ns = Ns, mod = Mod, fname = F, session = Session}) ->
    Line = element(1, Pos),
    case {Session, F} of
        {false, _} ->
            text_site([qname(Ns ++ [F]), ":", integer_to_list(Line)]);
        {Offset, '$input'} ->
            call_remote(ern_shell, input_site, [erl_syntax:atom(Mod),
                                                 erl_syntax:integer(Line + Offset)]);
        {Offset, _} ->
            text_site([qname([F]), ":", integer_to_list(Line + Offset)])
    end.

text_site(Where) ->
    string_binary(unicode:characters_to_binary(Where)).

%%
%% Operators, report §4.8
%%

%% Report §4.8, §3.10, §5.1: by the operand type. Int and the four
%% ordered prelude types are Erlang's operators; Float's arithmetic is
%% float_op/5; a user type's operator is its member, and its ordering is
%% `T.compare(a, b)` against Less or Greater.
binop(Op, {tcon, ['Int'], []}, L, R, _) when Op =:= '+'; Op =:= '-'; Op =:= '*' ->
    erl_syntax:infix_expr(L, erl_syntax:operator(Op), R);
binop('/', {tcon, ['Int'], []}, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('div'), R);
binop('%', {tcon, ['Int'], []}, L, R, _) -> erl_syntax:infix_expr(L, erl_syntax:operator('rem'), R);
binop('<>', {tcon, ['String'], []}, L, R, _) -> binary_append(L, R);
binop('<>', {tcon, ['Bytes'], []}, L, R, _) -> binary_append(L, R);
%% Report §9.6: `<>` on a prelude type whose module provides it in Ernest,
%% `List.<>` and `Path.<>`, a call of that module's, and a local call within it
binop('<>', {tcon, [Name], _}, L, R, #cx{ns = Ns}) ->
    case Ns of
        [Name] -> erl_syntax:application(erl_syntax:atom('<>'), [L, R]);
        _ -> call_remote(module_atom([Name]), '<>', [L, R])
    end;
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

%% Report §3.1, §7.4: a Float operation inline, its operands bound first so
%% that only its own badarith becomes the float fault; an Int division by
%% zero inside an operand stays that fault.
float_op(Op, L, R, A, B) ->
    Cause = erl_syntax:string("float arithmetic error"),
    Text = erl_syntax:binary([erl_syntax:binary_field(Cause)]),
    Badarith = erl_syntax:class_qualifier(erl_syntax:atom(error), erl_syntax:atom(badarith)),
    Handler = erl_syntax:clause([Badarith], none, [call_remote(ern_rt, fault, [Text])]),
    Plain = erl_syntax:infix_expr(erl_syntax:variable(A), erl_syntax:operator(Op),
                                  erl_syntax:variable(B)),
    %% report §3.1: under round to nearest a sum or a difference of operands
    %% that are not negative zero is never one, and no operand is; a product
    %% or a quotient may be, and + 0.0 turns it into 0.0 and keeps any other
    Operation = case Op of
                    _ when Op =:= '*'; Op =:= '/' ->
                        erl_syntax:infix_expr(Plain, erl_syntax:operator('+'),
                                              erl_syntax:float(0.0));
                    _ ->
                        Plain
                end,
    erl_syntax:block_expr([erl_syntax:match_expr(erl_syntax:variable(A), L),
                           erl_syntax:match_expr(erl_syntax:variable(B), R),
                           erl_syntax:try_expr([Operation], [Handler])]).

negate({tcon, ['Float'], []}, Form, _) ->
    %% report §3.1: 0.0 - x, so that negating 0.0 gives 0.0
    erl_syntax:infix_expr(erl_syntax:float(0.0), erl_syntax:operator('-'), Form);
negate({tcon, Q, _}, Form, Cx) when length(Q) > 1 -> member_call(Q, negate, [Form], Cx);
negate(_, Form, _) -> erl_syntax:prefix_expr(erl_syntax:operator('-'), Form).

%% A member of the type Q: a local function when Q is this module's type,
%% otherwise a call into the module that owns it (report §4.2).
member_call(Q, Name, Args, #cx{ns = Ns, env = Env}) ->
    Owner = lists:last(Q),
    %% report §11.2: at the prompt a later input may have declared it
    MQ = ern_typecheck:member_qname(Q, Name, Env),
    case lists:droplast(lists:droplast(MQ)) of
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
%% The foreign boundary, report §8.4: a declared type as the term
%% ern_boundary interprets
%%

%% Form's value checked against T and the fault's text naming Named (report
%% §7.4, §8.4). A word's check is written in place; a value that holds no
%% function, address or Reply to arm and no float to make the language's is
%% checked alone (ern_boundary:check/3); a type variable a parameter names matches any
%% value, and is not checked.
check_form(T, Named, Form, Prefix, Cx) ->
    Text = check_text(Prefix, Named, Cx),
    case descriptor(T, Cx) of
        any ->
            {Form, Cx};
        Word when Word =:= int; Word =:= bool; Word =:= bytes; Word =:= float ->
            {[V], Cx1} = fresh_vars(1, "V", Cx),
            Var = erl_syntax:variable(V),
            Test = erl_syntax:application(erl_syntax:atom(word_test(Word)), [Var]),
            %% report §3.1: X + 0.0 is 0.0 for either zero, and X otherwise
            Value = case Word of
                        float -> erl_syntax:infix_expr(Var, erl_syntax:operator('+'),
                                                       erl_syntax:float(0.0));
                        _ -> Var
                    end,
            Fault = call_remote(ern_rt, fault, [Text]),
            {erl_syntax:case_expr(Form, [erl_syntax:clause([Var], Test, [Value]),
                                         erl_syntax:clause([erl_syntax:underscore()], none,
                                                           [Fault])]), Cx1};
        Word when is_atom(Word) ->
            {call_remote(ern_boundary, value, [erl_syntax:abstract(Word), Form, Text]), Cx};
        Desc ->
            {DescForm, Cx1} = desc_ref(Desc, Cx),
            Check = case plain(Desc) of
                        true -> check;
                        false -> value
                    end,
            {call_remote(ern_boundary, Check, [DescForm, Form, Text]), Cx1}
    end.

word_test(int) -> is_integer;
word_test(bool) -> is_boolean;
word_test(bytes) -> is_binary;
word_test(float) -> is_float.

%% Whether a descriptor holds no function, no address, no Reply and no
%% float, as ern_boundary reads one: a checked value of it is the value
%% itself.
plain(float) -> false;
plain({pid, _, _}) -> false;
plain({reply, _, _}) -> false;
plain(T) when is_tuple(T), element(1, T) =:= 'fun' -> false;
plain(T) when is_tuple(T) -> lists:all(fun plain/1, tuple_to_list(T));
plain(L) when is_list(L) -> lists:all(fun plain/1, L);
plain(_) -> true.

%% An argument of a foreign function as it is given (§8.4): one with an
%% address inside, through the proxy that checks what foreign code sends
%% it, and a Reply foreign code gave back as it gave it; a function,
%% wrapped to check the arguments foreign code calls it with; any other,
%% and every argument of the standard library's own, as it is.
exposed({_, Arg}, #cx{standard = true} = Cx) ->
    {Arg, Cx};
exposed({{tfn, Ps, _, _}, Arg}, Cx) ->
    {Ref, Cx1} = callback_ref(Ps, Cx),
    {call_remote(ern_boundary, expose, [Ref, Arg]), Cx1};
exposed({T, Arg}, Cx) ->
    case crosses(descriptor(T, Cx)) of
        true ->
            {Ref, Cx1} = descriptor_ref(T, Cx),
            {call_remote(ern_boundary, expose, [Ref, Arg]), Cx1};
        false ->
            {Arg, Cx}
    end.

%% The type variables a type holds.
type_vars({tvar, _} = V) -> [V];
type_vars(T) when is_tuple(T) -> lists:append([type_vars(E) || E <- tuple_to_list(T)]);
type_vars(L) when is_list(L) -> lists:append([type_vars(E) || E <- L]);
type_vars(_) -> [].

%% The type with each of the variables Vars as `Never`.
as_never([], T) -> T;
as_never(Vars, {tvar, _} = V) ->
    case lists:member(V, Vars) of
        true -> {tcon, ['Never'], []};
        false -> V
    end;
as_never(Vars, T) when is_tuple(T) -> list_to_tuple([as_never(Vars, E) || E <- tuple_to_list(T)]);
as_never(Vars, L) when is_list(L) -> [as_never(Vars, E) || E <- L];
as_never(_, T) -> T.

%% Report §8.4: the checks of a function an Ernest program gives a foreign
%% function, each argument against its parameter's type when foreign code
%% calls it.
callback_ref(Ps, Cx) ->
    desc_ref({callback, length(Ps), [descriptor(P, Cx) || P <- Ps],
              [text_binary("foreign argument does not match ", P, Cx) || P <- Ps]}, Cx).

%% A descriptor as a form: a literal when it is a word, else a call of a
%% module function that returns it, one per distinct descriptor.
descriptor_ref(T, Cx) ->
    desc_ref(descriptor(T, Cx), Cx).

desc_ref(Desc0, Cx) ->
    case Desc0 of
        Desc when is_atom(Desc) ->
            {erl_syntax:abstract(Desc), Cx};
        Desc ->
            case Cx#cx.descs of
                #{Desc := Name} ->
                    {erl_syntax:application(erl_syntax:atom(Name), []), Cx};
                Descs ->
                    Name = list_to_atom("$type_" ++ integer_to_list(map_size(Descs) + 1)),
                    Fun = erl_syntax:function(erl_syntax:atom(Name),
                                              [erl_syntax:clause([], none, [desc_form(Desc)])]),
                    {erl_syntax:application(erl_syntax:atom(Name), []),
                     Cx#cx{descs = Descs#{Desc => Name}, lifted = [Fun | Cx#cx.lifted]}}
            end
    end.

%% A descriptor as the form that builds it. A function's descriptor also
%% carries the maker of its checked wrapper, a fun of its arity that checks
%% each result (report §7.4), which only generated code can spell for every
%% arity; ern_boundary applies it to a function value foreign code gives,
%% and to the result's descriptor closed over the recursive types around it.
desc_form({callback, N, Ds, Texts}) ->
    F = erl_syntax:variable('F'),
    Args = [erl_syntax:variable(list_to_atom("A" ++ integer_to_list(I)))
            || I <- lists:seq(1, N)],
    Checked = [call_remote(ern_boundary, value, [desc_form(D), A, erl_syntax:abstract(T)])
               || {D, A, T} <- lists:zip3(Ds, Args, Texts)],
    Wrapper = erl_syntax:fun_expr([erl_syntax:clause(Args, none,
                                                      [called(F, Checked)])]),
    Maker = erl_syntax:fun_expr([erl_syntax:clause([F], none, [Wrapper])]),
    erl_syntax:tuple([erl_syntax:atom(callback), Maker]);
desc_form({'fun', N, R, Text, Ps, PTexts}) ->
    F = erl_syntax:variable('F'),
    Result = erl_syntax:variable('R'),
    Bound = erl_syntax:variable('B'),
    Args = [erl_syntax:variable(list_to_atom("A" ++ integer_to_list(I)))
            || I <- lists:seq(1, N)],
    Check = call_remote(ern_boundary, value,
                        [Result, erl_syntax:application(F, Args), erl_syntax:abstract(Text)]),
    Wrapper = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [Check])]),
    Maker = erl_syntax:fun_expr([erl_syntax:clause([F, Result], none, [Wrapper])]),
    %% report §8.4: the same function crossing into foreign code, wherever
    %% it stands in what crosses, each argument checked against its
    %% parameter's type, the recursive types around it in B
    Checked = [call_remote(ern_boundary, argument,
                           [desc_form(P), A, erl_syntax:abstract(T), Bound])
               || {P, A, T} <- lists:zip3(Ps, Args, PTexts)],
    Exposed = erl_syntax:fun_expr([erl_syntax:clause(Args, none, [called(F, Checked)])]),
    Exposer = erl_syntax:fun_expr([erl_syntax:clause([F, Bound], none, [Exposed])]),
    erl_syntax:tuple([erl_syntax:atom('fun'), erl_syntax:integer(N), desc_form(R),
                      erl_syntax:abstract(Text), Maker, Exposer]);
desc_form(T) when is_tuple(T) ->
    erl_syntax:tuple([desc_form(E) || E <- tuple_to_list(T)]);
desc_form(L) when is_list(L) ->
    erl_syntax:list([desc_form(E) || E <- L]);
desc_form(Other) ->
    erl_syntax:abstract(Other).

%% Report §7.4: the program's function F where foreign code calls it, an
%% exception it raises the fault it would be anywhere (called_raised/3).
called(Function, Arguments) ->
    [Class, Reason, Stack] = Raised = [erl_syntax:variable(Name)
                                       || Name <- ['Class', 'Reason', 'Stack']],
    Handler = erl_syntax:clause([erl_syntax:class_qualifier(Class, Reason, Stack)], none,
                                [call_remote(ern_boundary, called_raised, Raised)]),
    erl_syntax:try_expr([erl_syntax:application(Function, Arguments)], [Handler]).

check_text(Prefix, T, Cx) ->
    string_binary(text_binary(Prefix, T, Cx)).

text_binary(Prefix, T, #cx{env = Env}) ->
    unicode:characters_to_binary(Prefix ++ ern_types:format(T, ern_typecheck:type_state(Env))).

%% Appendix E.1, §8.4: the descriptor of a type, which ern_descriptor
%% makes, an abstract type seen from this module.
descriptor(T, #cx{env = Env, ns = Ns}) ->
    ern_descriptor:describe(T, Env, Ns).

%% Whether a descriptor holds what crossing into foreign code changes: an
%% address, a Reply, or a function.
crosses({pid, _, _}) -> true;
crosses({reply, _, _}) -> true;
crosses(T) when is_tuple(T), element(1, T) =:= 'fun' -> true;
crosses(T) when is_tuple(T) -> lists:any(fun crosses/1, tuple_to_list(T));
crosses(L) when is_list(L) -> lists:any(fun crosses/1, L);
crosses(_) -> false.

%%
%% Constructors, report §8.4
%%

%% Report §3.5, §8.4: a selected field. A named constructor is its tag and
%% its fields in canonical order, so the field is one element of the tuple
%% where every constructor has it at one place, and a case on the tag where
%% the places differ.
select(Pos, F, XT, Form, #cx{env = Env} = Cx) ->
    {tcon, Q, _} = ern_typecheck:resolve_type(XT, Env),
    #tinfo{constructors = Cs} = ern_typecheck:lookup_type(Q, Env),
    Places = [{C, place(F, Names) + 1, length(Names)}
              || #cinfo{name = C, fields = {named, Names}} <- Cs],
    case lists:usort([I || {_, I, _} <- Places]) of
        [I] ->
            {at(Pos, call_remote(erlang, element, [erl_syntax:integer(I), Form])), Cx};
        _ ->
            {[V], Cx1} = fresh_vars(1, "F", Cx),
            Var = erl_syntax:variable(V),
            Clauses = [erl_syntax:clause(
                         [erl_syntax:tuple([erl_syntax:atom(C)
                                            | [case J of I -> Var; _ -> erl_syntax:underscore() end
                                               || J <- lists:seq(2, N + 1)]])],
                         none, [Var])
                       || {C, I, N} <- Places],
            {at(Pos, erl_syntax:case_expr(Form, Clauses)), Cx1}
    end.

place(F, [F | _]) -> 1;
place(F, [_ | R]) -> 1 + place(F, R).

con_expr(Pos, Path, Name, Args, Cx) ->
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
            {Binds, Set, Cx1} = field_sets(Names, Sets, Cx),
            Tuple = erl_syntax:tuple([Tag | [maps:get(N, Set) || N <- Names]]),
            {at(Pos, with_binds(Binds, Tuple)), Cx1};
        {{named, Names}, {named, Base, Sets}} ->
            %% T(..base, f = e): bind the base to a tuple pattern, take the
            %% unlisted fields from it
            {BaseForm, Cx1} = expr(Base, Cx),
            {Vars, Cx2} = fresh_vars(length(Names), "B", Cx1),
            BasePat = erl_syntax:tuple([Tag | [erl_syntax:variable(V) || V <- Vars]]),
            {Binds, Set, Cx3} = field_sets(Names, Sets, Cx2),
            Forms = [maps:get(N, Set, erl_syntax:variable(V)) || {N, V} <- lists:zip(Names, Vars)],
            Bind = erl_syntax:match_expr(BasePat, BaseForm),
            {at(Pos, with_binds([Bind | Binds], erl_syntax:tuple([Tag | Forms]))), Cx3};
        _ ->
            fail(Pos, "constructor " ++ atom_to_list(Name) ++ " used with the wrong field shape;"
                      " T is the type checker's job")
    end.

%% Report §3.5, §5.1: named fields are stored in canonical order and
%% evaluated in the order written. Where the two differ, each field is
%% bound to a variable first, as written. The field forms by name, and
%% the bindings that go before the tuple.
field_sets(Names, Sets, Cx) ->
    {Forms, Cx1} = lists:mapfoldl(fun(#field_set{expr = X}, C) -> expr(X, C) end, Cx, Sets),
    Written = [N || #field_set{name = N} <- Sets],
    case [N || N <- Names, lists:member(N, Written)] of
        Written ->
            {[], maps:from_list(lists:zip(Written, Forms)), Cx1};
        _ ->
            {Vars, Cx2} = fresh_vars(length(Sets), "F", Cx1),
            Binds = [erl_syntax:match_expr(erl_syntax:variable(V), F)
                     || {V, F} <- lists:zip(Vars, Forms)],
            {Binds, maps:from_list(lists:zip(Written, [erl_syntax:variable(V) || V <- Vars])),
             Cx2}
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
    fail(Pos, "a block ends with a `let`");
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
                  Free = [F || F <- lists:usort(ern_ast:free_names(Body, Bound)),
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
            Vs = [var_atom(maps:get(O, Scope)) || O <- Own] ++ Extra,
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

%% The names a pattern binds.
pattern_names(P) -> [N || {N, _} <- ern_ast:pattern_bindings(P)].

%%
%% match and receive clauses
%%

%% A clause whose guard is not an Erlang guard expression falls through by
%% a continuation over the remaining clauses (report §5.9).
match_clauses(SF, Clauses, Cx) ->
    Erlang = fun(#clause{guard = undefined}) -> true;
                (#clause{pattern = P, guard = G}) ->
                     erlang_guard(G, pattern_names(P) ++ maps:keys(Cx#cx.vars), Cx)
             end,
    case lists:all(Erlang, Clauses) of
        true ->
            {Parts, Cx1} = lists:mapfoldl(fun simple_clauses/2, Cx, Clauses),
            {Binds, Forms} = join_parts(Parts),
            {with_binds(Binds, erl_syntax:case_expr(SF, Forms)), Cx1};
        false ->
            {[S], Cx1} = fresh_vars(1, "S", Cx),
            SVar = erl_syntax:variable(S),
            {Body, Cx2} = general_clauses(SVar, Clauses, Cx1),
            {erl_syntax:block_expr([erl_syntax:match_expr(SVar, SF), Body]), Cx2}
    end.

general_clauses(SVar, [#clause{pattern = #p_or{}} = C | Rest], Cx) ->
    {RestBind, Fallthrough, Cx2} = rest_fun(SVar, Rest, Cx),
    Mk = fun(Pos, PF, G, Call, C1) ->
             {PG, _} = take_pat_guards(none, C1),
             case G of
                 undefined ->
                     {at(Pos, erl_syntax:clause([PF], PG, Call)), C1};
                 _ ->
                     {GF, C2} = expr(G, C1),
                     Test = erl_syntax:case_expr(
                              GF, [erl_syntax:clause([erl_syntax:atom(true)], none, Call),
                                   erl_syntax:clause([erl_syntax:atom(false)], none,
                                                     [Fallthrough])]),
                     {at(Pos, erl_syntax:clause([PF], PG, [Test])), C2}
             end
         end,
    {{Binds, Forms}, Cx3} = alternatives(C, Mk, Cx2),
    Case = erl_syntax:case_expr(SVar, Forms ++ [erl_syntax:clause([erl_syntax:underscore()], none,
                                                                  [Fallthrough])]),
    {erl_syntax:block_expr([RestBind | Binds] ++ [Case]), Cx3#cx{vars = Cx#cx.vars}};
general_clauses(SVar, [#clause{pattern = P, guard = G, body = B}], Cx) when
      G =:= undefined ->
    {PF, Cx1} = pattern(P, Cx#cx{pat_guards = []}),
    {PG, _} = take_pat_guards(none, Cx1),
    {BF, Cx2} = body(B, Cx1#cx{pat_guards = Cx#cx.pat_guards}),
    {erl_syntax:case_expr(SVar, [erl_syntax:clause([PF], PG, BF)]), Cx2#cx{vars = Cx#cx.vars}};
general_clauses(SVar, [#clause{pattern = P, guard = G, body = B} | Rest], Cx) ->
    {Bind, Fallthrough, Cx2} = rest_fun(SVar, Rest, Cx),
    {PF, CxP} = pattern(P, Cx2#cx{pat_guards = []}),
    {PG, _} = take_pat_guards(none, CxP),
    Cx3 = CxP#cx{pat_guards = Cx2#cx.pat_guards},
    {Body, Cx4} = case G of
                      undefined -> body(B, Cx3);
                      _ ->
                          {GF, CxG} = expr(G, Cx3),
                          {BF, CxB} = body(B, CxG),
                          {[erl_syntax:case_expr(
                              GF, [erl_syntax:clause([erl_syntax:atom(true)], none, BF),
                                   erl_syntax:clause([erl_syntax:atom(false)], none,
                                                     [Fallthrough])])],
                           CxB}
                  end,
    Case = erl_syntax:case_expr(SVar, [erl_syntax:clause([PF], PG, Body),
                                       erl_syntax:clause([erl_syntax:underscore()], none,
                                                         [Fallthrough])]),
    {erl_syntax:block_expr([Bind, Case]), Cx4#cx{vars = Cx#cx.vars}}.

%% The clauses after the one being compiled, bound as Rest = fun() -> ...
%% end, and the call Rest() by which a guard falls through to them.
rest_fun(SVar, Rest, Cx) ->
    {[R], Cx1} = fresh_vars(1, "Rest", Cx),
    RVar = erl_syntax:variable(R),
    {RestBody, Cx2} = case Rest of
                          [] -> {call_remote(erlang, error, [erl_syntax:atom(no_match)]), Cx1};
                          _ -> general_clauses(SVar, Rest, Cx1)
                      end,
    Bind = erl_syntax:match_expr(RVar, erl_syntax:fun_expr([erl_syntax:clause([], none,
                                                                              [RestBody])])),
    {Bind, erl_syntax:application(RVar, []), Cx2}.

simple_clause(#clause{pos = Pos, pattern = P, guard = G, body = B}, Cx) ->
    {PF, Cx1} = pattern(P, Cx#cx{pat_guards = []}),
    {GF0, Cx2} = case G of
                     undefined -> {none, Cx1};
                     _ -> expr(G, Cx1)
                 end,
    {GF, _} = take_pat_guards(GF0, Cx2),
    {BF, Cx3} = body(B, Cx2#cx{pat_guards = Cx#cx.pat_guards}),
    {at(Pos, erl_syntax:clause([PF], GF, BF)), Cx3#cx{vars = Cx#cx.vars}}.

%% The Erlang clauses of one Ernest clause and the bindings they need.
simple_clauses(#clause{pattern = #p_or{}} = C, Cx) ->
    Mk = fun(Pos, PF, G, Call, C1) ->
             {GF0, C2} = case G of
                             undefined -> {none, C1};
                             _ -> expr(G, C1)
                         end,
             {GF, _} = take_pat_guards(GF0, C2),
             {at(Pos, erl_syntax:clause([PF], GF, Call)), C2}
         end,
    alternatives(C, Mk, Cx);
simple_clauses(C, Cx) ->
    {Form, Cx1} = simple_clause(C, Cx),
    {{[], [Form]}, Cx1}.

join_parts(Parts) ->
    {lists:append([B || {B, _} <- Parts]), lists:append([F || {_, F} <- Parts])}.

with_binds([], Form) -> Form;
with_binds(Binds, Form) -> erl_syntax:block_expr(Binds ++ [Form]).

%% Report §5.9: a clause with pattern alternatives is one Erlang clause per
%% alternative. The body is compiled once, into a fun over the variables
%% every alternative binds, and each clause calls it; Mk builds a clause
%% from the clause's span, the pattern form, the Ernest guard, and that call.
alternatives(#clause{pos = Pos, pattern = #p_or{alts = [First | _] = Alts}, guard = G,
                     body = B}, Mk, Cx) ->
    Names = pattern_names(First),
    {[F], Cx0} = fresh_vars(1, "Body", Cx),
    FVar = erl_syntax:variable(F),
    {_, CxP} = pattern(First, Cx0#cx{pat_guards = []}),
    Params = [erl_syntax:variable(var_atom(maps:get(N, CxP#cx.vars))) || N <- Names],
    {BF, CxB} = body(B, CxP#cx{pat_guards = Cx0#cx.pat_guards}),
    Bind = erl_syntax:match_expr(FVar, erl_syntax:fun_expr([erl_syntax:clause(Params, none, BF)])),
    {Forms, CxN} =
        lists:mapfoldl(fun(A, C0) ->
                           {PF, C1} = pattern(A, C0#cx{pat_guards = []}),
                           Args = [erl_syntax:variable(var_atom(maps:get(N, C1#cx.vars)))
                                   || N <- Names],
                           Call = [at(Pos, erl_syntax:application(FVar, Args))],
                           {Form, C2} = Mk(Pos, PF, G, Call, C1),
                           {Form, C2#cx{vars = C0#cx.vars, pat_guards = C0#cx.pat_guards}}
                       end, CxB#cx{vars = Cx0#cx.vars}, Alts),
    {{[Bind], Forms}, CxN}.

%% Report §6.3's guard expression over the variables in Bound, the
%% clause's and the enclosing function's: it is an Erlang guard. A name
%% bound at top level is read through its getter, a call, so it is not one.
erlang_guard(#e_binop{op = Op, left = L, right = R}, Bound, Cx) when Op =:= '&&'; Op =:= '||' ->
    erlang_guard(L, Bound, Cx) andalso erlang_guard(R, Bound, Cx);
erlang_guard(#e_binop{op = Op, left = L, right = R}, Bound, _) when Op =:= '=='; Op =:= '!=' ->
    guard_operand(L, Bound) andalso guard_operand(R, Bound);
erlang_guard(#e_binop{op = Op, left = L, right = R}, Bound, Cx) when Op =:= '<'; Op =:= '<=';
                                                                  Op =:= '>'; Op =:= '>=' ->
    %% an ordering through T.compare is a call (report §3.10)
    Prelude = case resolved(ern_typecheck:node_type(L), Cx) of
                  {tcon, [_], []} -> true;
                  _ -> false
              end,
    Prelude andalso guard_operand(L, Bound) andalso guard_operand(R, Bound);
erlang_guard(#e_not{expr = X}, Bound, Cx) -> erlang_guard(X, Bound, Cx);
erlang_guard(#e_lit{kind = bool}, _, _) -> true;
erlang_guard(#e_var{path = [], name = N}, Bound, _) -> lists:member(N, Bound);
erlang_guard(_, _, _) -> false.

guard_operand(#e_lit{}, _) -> true;
guard_operand(#e_neg{expr = #e_lit{kind = K}}, _) when K =:= int; K =:= float -> true;
guard_operand(#e_var{path = [], name = N}, Bound) -> lists:member(N, Bound);
guard_operand(#e_con{args = none}, _) -> true;
guard_operand(_, _) -> false.

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
pattern(#p_bits{pos = Pos, segments = Segs}, Cx) ->
    %% report §5.11: a size expression must be an Erlang guard expression
    %% here; a `bytes` segment is Erlang's `binary`, so an unaligned rest
    %% fails the match
    {Fields, Cx1} =
        lists:mapfoldl(fun(#bit_seg{value = V, specs = Specs}, C) ->
                           {ok, Spec} = ern_bitspec:spec(Specs),
                           {SizeF, C1} = size_form(Spec, C),
                           {VF, C2} = bits_pattern_value(Spec, V, C1),
                           {erl_syntax:binary_field(VF, SizeF, type_specs(Spec)), C2}
                       end, Cx, Segs),
    {at(Pos, erl_syntax:binary(Fields)), Cx1}.

bits_pattern_value(#{kind := float}, #p_var{pos = Pos, name = Name}, Cx) ->
    {V, Cx1} = bind(Name, Cx),
    {at(Pos, erl_syntax:variable(V)), Cx1#cx{vars = (Cx1#cx.vars)#{Name => {zero, V}}}};
bits_pattern_value(#{kind := float}, #p_lit{pos = Pos, value = Zero}, Cx) when Zero == 0.0 ->
    %% report §3.1: the literal 0.0 matches the bytes of either zero
    {[T], Cx1} = fresh_vars(1, "Z", Cx),
    Guard = erl_syntax:infix_expr(erl_syntax:variable(T), erl_syntax:operator('=='),
                                  erl_syntax:float(0.0)),
    {at(Pos, erl_syntax:variable(T)), Cx1#cx{pat_guards = Cx1#cx.pat_guards ++ [Guard]}};
bits_pattern_value(_, V, Cx) ->
    pattern(V, Cx).

%% The clause guards a pattern asked for, joined to the clause's own.
take_pat_guards(GF, #cx{pat_guards = []}) -> {GF, GF};
take_pat_guards(GF, #cx{pat_guards = Gs}) ->
    All = case GF of none -> Gs; _ -> Gs ++ [GF] end,
    Joined = lists:foldl(fun(G, Acc) -> erl_syntax:infix_expr(Acc, erl_syntax:operator('andalso'),
                                                              G) end,
                         hd(All), tl(All)),
    {Joined, GF}.

%%
%% Bitstring segments, report §5.11
%%

size_form(#{size := none}, Cx) -> {none, Cx};
size_form(#{size := {const, N}}, Cx) -> {erl_syntax:integer(N), Cx};
size_form(#{size := {expr, E}}, Cx) -> expr(E, Cx).

%% The width in bits as a form: size times unit.
bits_form(#{size := {const, N}, unit := U}, _) -> erl_syntax:integer(N * U);
bits_form(#{unit := 1}, SizeF) -> SizeF;
bits_form(#{unit := U}, SizeF) ->
    erl_syntax:infix_expr(SizeF, erl_syntax:operator('*'), erl_syntax:integer(U)).

segment_value(#{kind := int, sign := Sign} = Spec, VF, SizeF) ->
    call_remote(ern_bits, int, [VF, bits_form(Spec, SizeF), erl_syntax:atom(Sign)]);
segment_value(#{kind := float} = Spec, VF, SizeF) ->
    call_remote(ern_bits, float, [VF, bits_form(Spec, SizeF)]);
segment_value(#{kind := bytes, size := none}, VF, _) -> VF;
segment_value(#{kind := bytes} = Spec, VF, SizeF) ->
    call_remote(ern_bits, bytes, [VF, bits_form(Spec, SizeF)]);
segment_value(_, VF, _) -> VF.

%% A dynamic size counted in bits, a unit of 1, leaves the bit count open;
%% the built value is then checked for alignment.
open(#{size := {expr, _}, unit := 1}) -> true;
open(_) -> false.

type_specs(#{kind := Kind, unit := Unit, endian := Endian, sign := Sign, size := Size}) ->
    Type = case Kind of
               int -> integer; bytes -> binary; K -> K
           end,
    Utf = lists:member(Kind, [utf8, utf16, utf32]),
    [erl_syntax:atom(Type)]
    ++ [erl_syntax:atom(Endian) || not Utf orelse Endian =/= big]
    ++ [erl_syntax:atom(Sign) || Kind =:= int]
    ++ [erl_syntax:size_qualifier(erl_syntax:atom(unit), erl_syntax:integer(Unit))
        || not Utf, Size =/= none].

%%
%% Variables: every Ernest binding gets a fresh Erlang variable
%%

bind(Name, #cx{vars = Vars, counter = N} = Cx) ->
    V = erlang_var(Name, N + 1),
    {V, Cx#cx{vars = Vars#{Name => V}, counter = N + 1}}.

%% Report §3.1: a variable a float segment bound may hold the runtime's
%% negative zero, so the map holds {zero, V} and each read is V + 0.0,
%% which is 0.0 for either zero and V otherwise; a capture passes V itself,
%% and the reads inside normalize it the same way.
var_form({zero, V}) ->
    erl_syntax:infix_expr(erl_syntax:variable(V), erl_syntax:operator('+'),
                          erl_syntax:float(0.0));
var_form(V) ->
    erl_syntax:variable(V).

var_atom({zero, V}) -> V;
var_atom(V) -> V.

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

%% A declaration the checker would not have passed: a defect of the
%% toolchain, not of the program.
-spec fail(term(), iodata()) -> no_return().
fail(Pos, Message) ->
    erlang:error({emitter_defect, Pos, lists:flatten(Message)}).
