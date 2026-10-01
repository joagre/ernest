%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. An input is a module
%% of its own, `$Input<n>`, checked against the load path and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
-module(ern_shell).

-export([loaded/1, start/0, program/0, startup_files/0, needs_more/1, check/3,
         is_unit/1, type_text/1, run/4, show/3, bindings/1, context/1, names/0,
         session_names/0, session_texts/0, source_root/0, segment/1, forget/2, browse/2, doc/2,
         documentation/1, fields/1, signature/1, load/2,
         reload/1, version/0, write/1, screen/1, to_screen/1,
         output/1, unbound/1, collect/1, input_site/2, is_expression/1, declared/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diag.hrl").
-include_lib("cli/include/ern_build.hrl").

-define(UNIT, {tcon, ['Unit'], []}).

%% The function an expression input is wrapped in. No Ernest identifier is
%% spelled so, so the wrapper never shadows a name the session declares,
%% `main` among them (report §11.2's scope), and the emitter knows a site
%% inside it for the input's own.
-define(ENTRY, '$input').

%% The session so far: the roots to look in, the count of inputs seen, the
%% interfaces of the modules behind the session, and the scope those
%% modules make (report §11.2), which the checker takes as its fourth
%% argument.
-record(env, {roots = [], source_root = ".", n = 0, ifaces = [], session = #{}, beams = #{},
              modules = #{}, holders = 0, free_holders = [], draining = []}).
%% n: the highest input number given; holders: the highest `$Bindings`
%% number given; free_holders: the numbers of holders freed (collected/1),
%% given again first, as an input's number is once its module is unloaded
%% (forget/3); draining: holders deleted whose old code a process still
%% ran, purged at the next collection
%% modules: the namespace of a module the session has loaded, to the hash
%% of the source it was compiled from, which `:reload` compares (§11.2)
%% beams: the namespace of an input that declared, to its compiled module,
%% which `:doc` reads the documentation of (report §11.2, §11.4)
%% A checked input: the module it became, its typed tree, its type.
-record(checked, {ns, typed, decls, iface, env, type, binds, site}).
%% binds: the name a `let` binds, `{lambda, Name, Scheme}` for a `let` of a
%% lambda, generalized, `{names, Ns}` for the names a `let` with a pattern
%% binds, `it` for an expression, or `decls`
%% A value with the descriptor of its type, so it prints as E.1 prints it.
-record(value, {term, desc}).

%% Report §11.2: what the runner loaded before the shell started, which the
%% shell begins from: the load path, where a module's source is found, the
%% interfaces of the loaded modules, and the entry point to spawn beside the
%% prompt.
-spec loaded(map()) -> ok.
loaded(What) ->
    persistent_term:put({?MODULE, loaded}, What).

-spec start() -> #env{}.
start() ->
    What = persistent_term:get({?MODULE, loaded}, #{}),
    Loaded = maps:get(ifaces, What, []),
    remember(#env{roots = maps:get(roots, What, []),
                  source_root = maps:get(source_root, What, "."),
                  ifaces = [I || {I, _} <- Loaded],
                  modules = maps:from_list([{I#iface.namespace, H} || {I, H} <- Loaded])}).

%% Report §11.2: the session's environment as it stands, which
%% completion reads. The reader asks for the names while an input runs,
%% when the session is busy answering nothing, so it cannot be a message
%% to the session; the front end keeps the latest, as it keeps what the
%% runner loaded. An input's declarations join the session when it has
%% run, not when it is checked, so this is set in both places.
remember(Env) ->
    persistent_term:put({?MODULE, env}, Env),
    Env.

%% Report §11.2, §8.1: the file's entry point, spawned beside the prompt and
%% not entered, and nothing where the shell was started with no file. A
%% fault in it reaches the session through Process.faults, to which the
%% session subscribed before (E.21).
-spec program() -> {'Some', pid()} | 'None'.
program() ->
    case persistent_term:get({?MODULE, loaded}, #{}) of
        #{entry := {Mod, Fn, Site}} ->
            F = ern_emitter:function_atom(Fn),
            {'Some', ern_rt:spawn(fun() -> Mod:F() end, Site)};
        _ ->
            'None'
    end.

%% Report §11.2, §8.1: where the startup files are, the person's first
%% and then the node's, each named from the working directory as §11.5
%% names a file. The shell reads them itself, in Ernest: only where they
%% are is the host's to say.
-spec startup_files() -> [binary()].
startup_files() ->
    What = persistent_term:get({?MODULE, loaded}, #{}),
    [unicode:characters_to_binary(ern_build:shown(File)) || File <- maps:get(startups, What, [])].

%% Report §11.2: at a terminal the shell takes another line where the
%% parser cannot finish the input. Both readings are tried, the expression
%% and the declarations, as `input/1` tries them: an input that could
%% still become either is unfinished.
-spec needs_more(binary()) -> boolean().
needs_more(Text) ->
    unfinished(ern_parser:parse_expr(Text)) orelse unfinished(ern_parser:parse_string(Text)).

unfinished({error, #diag{incomplete = Incomplete}}) -> Incomplete;
unfinished(_) -> false.

%% Report §11.2: an input is checked before it is run; a failure is §11.5's
%% text, as `ern build` shows it, under the name of where the input came from:
%% `input 3` for the third thing entered at the prompt, the file's path for
%% an input from a startup file. The shell's `Origin` says which:
%% `Prompt(n)`, or `Startup(file, line, column)`, its fields in canonical
%% order, the column where the input begins on the line.
-spec check(#env{}, {'Prompt', pos_integer()}
                    | {'Startup', pos_integer(), binary(), pos_integer()}, binary()) ->
          {'Left', binary()} | {'Right', {#env{}, #checked{}}}.
check(#env{n = N} = Env, From, Input) ->
    Origin = case From of
                 {'Prompt', K} -> {typed, <<"input ", (integer_to_binary(K))/binary>>};
                 {'Startup', Column, File, First} -> {file, File, First, Column}
             end,
    %% an input takes the number of one whose module was unloaded, whose
    %% name is an atom already, before a new one (report §2.3)
    {Ns, N1} = case persistent_term:get({?MODULE, free_inputs}, []) of
                   [Free | _] -> {Free, N};
                   [] -> {input_namespace(N + 1), N + 1}
               end,
    case input(Input) of
        {ok, Binds, Expr} ->
            checked(check_module(Env#env{n = N1}, Ns, Origin, Input, input_entry(Expr), Binds));
        {decls, Decls} ->
            checked(check_module(Env#env{n = N1}, Ns, Origin, Input, Decls, decls));
        {error, Diag} ->
            {'Left', diagnostic(Origin, Input, [Diag])}
    end.

%% Report §2.3: the modules the session makes are named as no Ernest name
%% is spelled, since an identifier holds no `$`: the module an input
%% becomes, `$Input<n>`; the one that holds what a `let` at the prompt
%% binds, `$Bindings<n>`; and the one a callee is checked in for
%% `Shift-Tab`. No input reaches them by name, and a module spelled as one
%% would be otherwise, `Input1`, is a module like any other.
input_namespace(K) ->
    [list_to_atom("$Input" ++ integer_to_list(K))].

checked({'Right', {Env, Checked}}) ->
    {'Right', {remember(Env), Checked}};
checked(Other) ->
    Other.

%% Report §11.2: an input is an expression, whose value is `it`; a `let`,
%% whose value is the name it binds; or declarations. A `let` at the prompt
%% is a block `let` (§4.6 is for a module's), so it is the entry point's
%% body and the name is bound to what the input answers.
input(Text) ->
    case ern_parser:parse_expr(Text) of
        {ok, Expr} ->
            {ok, it, Expr};
        {error, Diag} ->
            case ern_parser:parse_string(Text) of
                {ok, [#let_decl{name = Name, body = Body, ann = Ann}]} ->
                    {ok, let_binds(Name, Body), annotated(Name, Body, Ann)};
                {ok, Decls} -> declarations(Decls);
                {error, DeclDiag} ->
                    case pattern_let(Text) of
                        none -> {error, which(Text, Diag, DeclDiag)};
                        Input -> Input
                    end
            end
    end.

%% Report §11.2: a `let` whose pattern is not a name binds each name the
%% pattern binds. It is the block `{ let p = e; #(names) }`, whose value
%% holds the names in the order the pattern has them; `let _ = e` binds
%% none, and `<-` is refused, since no block follows it for it to end.
pattern_let(Text) ->
    case ern_parser:parse_stmt(Text) of
        {ok, #binding{op = '<-', pos = Pos}} ->
            {error, #diag{span = ern_diag:span(Pos),
                          message = "a `let` with `<-` at the prompt has no block to end",
                          help = "write it in a block, `{ let x <- e; ... }`"}};
        {ok, #binding{pos = Pos, pattern = P} = B} ->
            Names = [N || {N, _} <- ern_ast:pattern_bindings(P)],
            Vars = [#e_var{pos = Pos, name = N} || N <- Names],
            Last = case Vars of
                       [] -> #e_con{pos = Pos, name = 'Unit'};
                       [V] -> V;
                       _ -> #e_tuple{pos = Pos, elems = Vars}
                   end,
            {ok, {names, Names}, #e_block{pos = Pos, stmts = [B, Last]}};
        _ ->
            none
    end.

%% Report §11.5: an input that begins where only a declaration may begin is
%% a declaration a person got wrong, and the declaration parser's error is
%% the one that names what is wrong; anything else is an expression, whose
%% error names it. `fn` begins a lambda as well, and begins a declaration
%% only when a name follows it.
which(Text, Diag, DeclDiag) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} ->
            case declaration_start(Tokens) of
                true -> DeclDiag;
                false -> Diag
            end;
        _ ->
            Diag
    end.

declaration_start([{'fn', _}, {ident, _, _} | _]) -> true;
declaration_start([{Word, _} | _]) -> lists:member(Word, [type, abstract, foreign, export, 'let']);
declaration_start(_) -> false.

%% Report §11.2: what an input declares is the session's from then on, so
%% every declaration of an input is exported; a later input reaches it as it
%% reaches another module's declaration (§4.3).
declarations(Decls) ->
    case [P || #let_decl{pos = P} <- Decls] of
        [] -> {decls, [exported(D) || D <- Decls]};
        [_, Second | _] -> {error, one_let(Second)};
        [Pos] -> {error, one_let(Pos)}
    end.

%% Report §11.2: a `let` at the prompt is a block `let`, and a block has one
%% of them per input; a `let` beside a declaration would be a top-level
%% `let`, which §4.6 generalizes and requires to be pure. A `let` that
%% declares a type member, `let T.name`, is a declaration and not this.
one_let(Pos) ->
    #diag{span = ern_diag:span(Pos),
          message = "a `let` at the prompt is an input of its own",
          help = "run this `let` on an input of its own, or make it a `let`"
                 " inside a declaration's body"}.

exported(#type_decl{} = D) -> D#type_decl{export = true};
exported(#abstract_decl{} = D) -> D#abstract_decl{export = true};
exported(#foreign_type_decl{} = D) -> D#foreign_type_decl{export = true};
exported(#fn_decl{} = D) -> D#fn_decl{export = true};
exported(#let_decl{} = D) -> D#let_decl{export = true};
exported(#foreign_fn_decl{} = D) -> D#foreign_fn_decl{export = true};
exported(D) -> D.

%% Report §11.2: a `let` at the prompt may carry an annotation, which the
%% checker holds its value to as it holds a `let` in a block's: the input
%% is `{ let x : T = e; x }`.
%% Report §4.6, §11.2: a `let` that binds a name to a lambda is generalized,
%% as in a block; its scheme is known once the input is checked.
let_binds(Name, #e_lambda{}) -> {lambda, Name};
let_binds(Name, _) -> Name.

annotated(_Name, Body, undefined) ->
    Body;
annotated(Name, Body, Ann) ->
    Pos = element(2, Body),
    #e_block{pos = Pos, stmts = [#binding{pos = Pos, pattern = #p_var{pos = Pos, name = Name},
                                          ann = Ann, op = '=', expr = Body},
                                 #e_var{pos = Pos, name = Name}]}.

%% `export fn '$input'() = <the input>`, the entry point of §8.1.
input_entry(Expr) ->
    [#fn_decl{pos = {1, 1, {1, 1}}, export = true, name = ?ENTRY, params = [], body = Expr}].

check_module(#env{ifaces = Ifaces, session = Session} = Env, Ns, From, Input, Decls, Binds) ->
    case ern_typecheck:check(Ns, Decls, Ifaces, Session) of
        {ok, Typed, Iface, TEnv} ->
            Type = input_type(Typed, Binds),
            Binds1 = generalized(Binds, Typed, TEnv),
            case refused(Type, TEnv, Binds1, Typed) of
                none ->
                    {'Right', {Env, #checked{ns = Ns, typed = Typed, decls = Decls,
                                             iface = Iface, env = TEnv, type = Type,
                                             binds = Binds1, site = site(From)}}};
                {open, Diag} ->
                    {'Left', diagnostic(From, Input, [Diag])}
            end;
        {error, Diags} ->
            {'Left', diagnostic(From, Input, Diags)}
    end.

%% Report §4.6: the scheme a `let` of a lambda binds its name to, the
%% input's entry point's own over its result, the variables it quantifies
%% kept with their restrictions.
generalized({lambda, Name}, Typed, TEnv) ->
    [#scheme{vars = Vars} = Scheme] = [S || #fn_decl{name = ?ENTRY, type = S} <- Typed],
    Result = result_type(Scheme),
    St = ern_typecheck:type_state(TEnv),
    Free = ern_types:free_vars(ern_types:zonk(Result, St), St),
    {lambda, Name, Scheme#scheme{vars = [V || {Id, _} = V <- Vars, lists:member(Id, Free)],
                                 type = Result}};
generalized(Binds, _Typed, _TEnv) ->
    Binds.

%% Report §11.2: the name and the line offset a spawn site in the input is
%% written with, as its diagnostics name and count it.
site({typed, Name}) -> {Name, 0};
site({file, File, First, _}) -> {File, First - 1}.

%% Report §11.2: an input is compiled and run on its own, so what it
%% binds must have a type by the time it runs; a later input cannot
%% settle it, as a later statement of a block would. A binding whose
%% type is still open is refused with the annotation that would settle
%% it, rather than entering the session as a scheme whose variables mean
%% nothing to the inputs after it.
refused(Type, TEnv, Binds, Typed) ->
    case carries_reply(Type, TEnv, Binds, Typed) of
        none -> undetermined(Type, TEnv, Binds, Typed);
        Refused -> Refused
    end.

%% Report §6.6, §11.2: an input's value is printed and dropped, and what a
%% `let` at the prompt binds is the session's, for any later input to use,
%% so neither may carry a reply, which is consumed exactly once.
carries_reply(_Type, _TEnv, decls, _Typed) ->
    none;
carries_reply(Type, TEnv, _Binds, Typed) ->
    case ern_typecheck:is_reply_carrying(Type, TEnv) of
        false ->
            none;
        true ->
            St = ern_typecheck:type_state(TEnv),
            {open, #diag{span = input_span(Typed),
                         message = "an input's value cannot carry a reply, which is consumed"
                                   " exactly once; this one is "
                                   ++ ern_types:format(Type, St),
                         help = "answer the reply within the input"}}
    end.

undetermined(_Type, _TEnv, decls, _Typed) ->
    none;
undetermined(_Type, _TEnv, it, _Typed) ->
    %% a bare expression runs and prints whatever its type; what it
    %% cannot do is bind `it`, which `declared/1` says
    none;
undetermined(_Type, _TEnv, {names, []}, _Typed) ->
    none;
undetermined(_Type, _TEnv, {lambda, _, _}, _Typed) ->
    %% its variables are its scheme's, quantified (report §4.6)
    none;
undetermined(Type, TEnv, Binds, Typed) ->
    St = ern_typecheck:type_state(TEnv),
    case ern_types:free_vars(ern_types:zonk(Type, St), St) of
        [] ->
            none;
        _ ->
            Text = ern_types:format(Type, St),
            {open, #diag{span = input_span(Typed),
                         message = lists:flatten(
                                     io_lib:format(undetermined_text(Binds),
                                                   [bound_names(Binds), Text])),
                         help = "bind it with an annotation that settles the variable,"
                                " as in `let xs : List(Int) = []`, or declare a function"
                                " with `fn`"}}
    end.

undetermined_text({names, [_, _ | _]}) ->
    "the types of ~s are not determined by this input; together they are ~ts";
undetermined_text(_) ->
    "the type of ~s is not determined by this input; it is ~ts".

bound_names({names, Names}) -> lists:join(", ", [atom_to_list(N) || N <- Names]);
bound_names(Name) -> atom_to_list(Name).

input_span([#fn_decl{pos = Pos} | _]) -> ern_diag:span(Pos);
input_span(_) -> {1, 1, {1, 2}}.

%% An input that declares has no value; report §11.2 prints what it
%% declared, as an input of type Unit prints nothing.
input_type(_Typed, decls) ->
    ?UNIT;
input_type(Typed, _Binds) ->
    [#fn_decl{type = Scheme}] = [D || #fn_decl{name = ?ENTRY} = D <- Typed],
    result_type(Scheme).

result_type(#scheme{type = {tfn, [], _, Result}}) -> Result;
result_type(#scheme{type = T}) -> T.

%% Report §11.2: a value of type `Unit` prints nothing.
-spec is_unit(#checked{}) -> boolean().
is_unit(#checked{type = T, env = Env}) ->
    ern_typecheck:resolve_type(T, Env) =:= ?UNIT.

%% Report §11.5: the type as the checker prints it.
-spec type_text(#checked{}) -> binary().
type_text(#checked{typed = Typed, type = T, env = Env}) ->
    St = ern_typecheck:type_state(Env),
    Text = case one_name(Typed) of
               {Path, Name} ->
                   case ern_typecheck:declared_scheme(Env, Path, Name) of
                       {ok, Scheme} -> ern_types:format_scheme(Scheme, St);
                       error -> ern_types:format(T, St)
                   end;
               none ->
                   ern_types:format(T, St)
           end,
    unicode:characters_to_binary(Text).

%% Report §11.2: an input that is one name is printed with the name's
%% declared type, its variables named as the declaration names them.
one_name(Typed) ->
    case [B || #fn_decl{name = ?ENTRY, body = B} <- Typed] of
        [#e_var{path = Path, name = Name}] -> {Path, Name};
        _ -> none
    end.

%% Report §11.2: the input runs in a process of its own; the outcome goes to
%% `To`, so the shell's reader stays live and the address is what an
%% interruption kills.
-spec run(#env{}, #checked{}, integer(), term()) -> term().
run(Env, #checked{ns = Ns, typed = Typed, iface = Iface, env = TEnv, type = T,
                  binds = Binds, site = {Where, Offset}}, Run, To) ->
    Desc = ern_descriptor:describe(T, TEnv, []),
    {ok, Mod, Beam} = ern_emitter:compile(Ns, Typed, Iface, TEnv,
                                          #{source_hash => <<>>, deps => [], session => Offset}),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), Beam),
    set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) -- [Ns]),
    %% report §11.2: the session's modules the input calls, and those whose
    %% types its declarations name, kept while it is (collected/2)
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    Named = case Binds of
                decls -> mentions(Iface, Ns);
                _ -> []
            end,
    %% the keys its top-level lets are stored under (report §8.5), which go
    %% when it does
    Keys = [{Mod, ern_emitter:function_name(undefined, N)} || #let_decl{name = N} <- Typed],
    set_uses(maps:put(Mod, {Ns, lists:usort([M || {M, _, _} <- Imports, session_module(M),
                                                  M =/= Mod] ++ Named), Keys},
                      uses())),
    set_names(maps:put(Mod, Where, names_of_inputs())),
    %% report §11.2: an input that declares keeps its module for `:doc`;
    %% an expression's has no documentation, and is not kept
    Env1 = case Binds of
               decls -> Env#env{beams = maps:put(Ns, Beam, Env#env.beams)};
               _ -> Env
           end,
    Input = fun() ->
                %% report §11.2: the input's own fault is its answer, caught
                %% here, so that its process does not end with a fault
                Outcome = try
                              V = value(Mod, Binds),
                              {'Ok', remember(bind(Env1, Binds, Ns, V, T, TEnv, Iface)), Run,
                               #value{term = V, desc = Desc}}
                          catch
                              throw:{ern, fault, Msg} -> {'Faulted', Msg, Run};
                              throw:{ern, fault, Msg, _} -> {'Faulted', Msg, Run};
                              Class:Reason -> {'Faulted', fault_text(Class, Reason), Run}
                          end,
                forget(Ns, Binds, Outcome),
                ern_rt:send(To, Outcome)
            end,
    ern_rt:spawn(Input, <<Where/binary, ":", (integer_to_binary(1 + Offset))/binary>>).

%% An input that declares nothing, an expression or a `let`, is done with
%% its module once it has its answer, unless what it bound holds one of the
%% module's functions: it is deleted, and purged unless a process the input
%% spawned still runs it, which keeps it until that process ends; each
%% later input tries the purge again. An input that declares, and one whose
%% value holds its functions, is kept while the session can reach it, and
%% collected/2 lets it go.
forget(Ns, Binds, Outcome) ->
    Mod = ern_emitter:module_atom(Ns),
    Pending = persistent_term:get({?MODULE, unpurged}, []),
    {Purged, Unpurged} = lists:partition(fun(P) -> code:soft_purge(ern_emitter:module_atom(P)) end,
                                         Pending),
    Now = case {Binds, Outcome} of
              {decls, _} -> kept;
              {_, {'Ok', _, _, #value{term = V}}} ->
                  case lists:member(Mod, fun_modules(V, [])) of
                      true -> kept;
                      false -> unload(Mod)
                  end;
              {_, {'Faulted', _, _}} -> unload(Mod)
          end,
    Left = case Now of
               unpurged -> [Ns | Unpurged];
               _ -> Unpurged
           end,
    Left =/= Pending andalso persistent_term:put({?MODULE, unpurged}, Left),
    %% report §2.3: an unloaded input's number, and so its name's atoms, are
    %% given to the next input
    Freed = Purged ++ [Ns || Now =:= purged],
    Freed =/= [] andalso
        set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) ++ Freed),
    %% report §11.2: an input purged reads no holder again
    set_uses(maps:without([ern_emitter:module_atom(F) || F <- Freed], uses())),
    ok.

set_free_inputs(Free) ->
    persistent_term:get({?MODULE, free_inputs}, []) =/= Free
        andalso persistent_term:put({?MODULE, free_inputs}, Free).

%% Deleted, and purged unless a process still runs it.
unload(Mod) ->
    code:delete(Mod),
    case code:soft_purge(Mod) of
        true -> purged;
        false -> unpurged
    end.

%% The modules whose functions a value holds, in its data or in a
%% function's captures.
fun_modules(F, Acc) when is_function(F) ->
    {module, Mod} = erlang:fun_info(F, module),
    {env, Captured} = erlang:fun_info(F, env),
    fun_modules(Captured, [Mod | Acc]);
fun_modules(T, Acc) when is_tuple(T) ->
    fun_modules(tuple_to_list(T), Acc);
fun_modules([H | Rest], Acc) ->
    fun_modules(Rest, fun_modules(H, Acc));
fun_modules(M, Acc) when is_map(M) ->
    fun_modules(maps:to_list(M), Acc);
fun_modules(_, Acc) ->
    Acc.

%% An input that declares runs its initializers and nothing else. Report
%% §8.5: a module's top-level values are computed by them, which the runner
%% does when it loads a module; an input's module is loaded here, so they
%% run here, in the input's own process. Its value is Unit, which prints
%% nothing (report §11.2).
value(Mod, decls) ->
    erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'(),
    'Unit';
value(Mod, _Binds) ->
    Mod:?ENTRY().

fault_text(error, badarith) -> <<"division by zero">>;
fault_text(Class, Reason) ->
    unicode:characters_to_binary(io_lib:format("~p:~p", [Class, Reason])).

%% Appendix E.1: the value as Ernest writes it, by the descriptor of its
%% type; report §11.2: to the depth and the length the session is set to,
%% where 0 is neither.
-spec show(#value{}, integer(), integer()) -> binary().
show(#value{term = V, desc = D}, Depth, Length) ->
    ern_show:show(D, V, bound(Depth), bound(Length)).

bound(N) when N =< 0 -> unbounded;
bound(N) -> N.

%% Report §11.2: what the session declares, a line for each as an input's
%% own declarations print, its types first and then its values by name.
-spec bindings(#env{}) -> [binary()].
bindings(#env{session = S} = Env) ->
    Types = [unicode:characters_to_binary([abstract_text(tinfo(Q, Env)), "type ",
                                           atom_to_list(Name)])
             || {Name, Q} <- lists:sort(maps:to_list(maps:get(types, S, #{})))],
    St = session_state(Env),
    Values = [unicode:characters_to_binary(
                [Text, " : ", ern_types:format_scheme(Scheme, St)])
              || {Text, Scheme} <- lists:sort(
                                     [{name_text(Key), Scheme}
                                      || {Key, Q} <- maps:to_list(maps:get(values, S, #{})),
                                         {ok, Scheme} <- [scheme(Q, Env)]])],
    Types ++ Values.

%% Report §11.2: what may stand where the cursor is, which the parser
%% knows and nothing else does: it says what it wanted where it stopped
%% (§11.5's diagnostic carries the tag). Both readings are tried, as
%% `input/1` tries them. Completion decides for itself which kinds of
%% name a context admits; this only answers the context.
-spec context(binary()) -> atom() | {'Fields', [binary()]}.
context(Before) ->
    case [What || {true, What} <- [wanted(ern_parser:parse_expr(Before)),
                                   wanted(ern_parser:parse_string(Before))],
                  What =/= undefined] of
        [What | _] -> where(What);
        [] -> 'Expression'
    end.

wanted({error, #diag{incomplete = Incomplete, expected = What}}) -> {Incomplete, What};
wanted(_) -> {false, undefined}.

where(expression) -> 'Expression';
where(typename) -> 'TypeName';
where(pattern) -> 'Pattern';
where(declaration) -> 'Declaration';
where({field, Path, Con}) -> {'Fields', fields_of(Path, Con)};
%% the parser could not tell a field's name from a value; the
%% constructor's type can, and only a named constructor has fields
where({field_or_value, Path, Con}) ->
    case fields_of(Path, Con) of
        [] -> 'Expression';
        Fields -> {'Fields', Fields}
    end;
where({field_or_pattern, Path, Con}) ->
    case fields_of(Path, Con) of
        [] -> 'Pattern';
        Fields -> {'Fields', Fields}
    end.

%% The fields of the constructor as it is written, found as the checker
%% finds it (report §4.2): unqualified, the session's or the prelude's, and
%% qualified, its module's.
%% Report §11.2: each as a `Shell.Complete.Name`, listed with its type, the
%% constructor's parameter in the field's place, both in canonical order.
fields_of(Path, Con) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    case con_info(Env, Path, Con) of
        {ok, #cinfo{fields = {named, Fields}, scheme = #scheme{type = {tfn, Ps, _, _}}}} ->
            St = session_state(Env),
            [name('Value', atom_to_list(F), atom_to_list(F) ++ " : " ++ ern_types:format(P, St))
             || {F, P} <- lists:zip(Fields, Ps)];
        _ ->
            []
    end.

%% Report §11.2: every name completion may reach — the session's, the
%% prelude's, and each module in scope with its exports — as
%% `Shell.Complete.Name`, whose fields are in canonical order (§3.5):
%% kind, the line a listing shows, the text as it is typed. Only the
%% reading of the interfaces is the host's; the matching is Ernest's.
-spec names() -> [{'Name', atom(), binary(), binary()}].
names() ->
    names(persistent_term:get({?MODULE, env}, #env{})).

names(#env{ifaces = Ifaces, session = S} = Env) ->
    St = session_state(Env),
    Session = [name('Value', name_text(Key), scheme_line(name_text(Key), Q, Env, St))
               || {Key, Q} <- maps:to_list(maps:get(values, S, #{}))]
        ++ [name('Type', atom_to_list(N), "type " ++ atom_to_list(N))
            || {N, _} <- maps:to_list(maps:get(types, S, #{}))]
        ++ [name('Constructor', atom_to_list(N), con_line(atom_to_list(N), con_scheme(CQ, Env), St))
            || {N, CQ} <- maps:to_list(maps:get(cons, S, #{}))],
    {TypeQs, _} = ern_typecheck:prelude_names(),
    Prelude = [name('Value', qname_text(Q), qname_text(Q) ++ " : " ++ Type)
               || {Q, Type, _} <- ern_prelude:values()]
        ++ [name('Type', qname_text(Q), "type " ++ qname_text(Q)) || Q <- TypeQs]
        ++ [name('Constructor', qname_text(Q), con_line(qname_text(Q), {ok, Sc}, St))
            || {Q, #cinfo{scheme = Sc}} <- maps:to_list(ern_typecheck:prelude_cons())],
    Modules = lists:append([module_names(I, St)
                            || I <- Ifaces ++ ern_prelude:stdlib_ifaces()]),
    %% report §11.2: an operator is no name, and does not complete, and
    %% neither does a module the session made, which is spelled as no name
    lists:usort([Name || {'Name', _, _, Text} = Name <- Session ++ Prelude ++ Modules,
                         words(Text)]).

%% Every segment of a text begins with a letter or `_`, as a name's does.
words(Text) ->
    lists:all(fun(<<C, _/binary>>) -> C =:= $_ orelse (C >= $a andalso C =< $z)
                                          orelse (C >= $A andalso C =< $Z);
                 (_) -> false
              end, binary:split(Text, <<".">>, [global])).

%% Report §11.2: a constructor is listed with its type, as a value is.
con_line(Text, {ok, Scheme}, St) -> Text ++ " : " ++ ern_types:format_scheme(Scheme, St);
con_line(Text, none, _) -> Text.

con_scheme(CQ, #env{ifaces = Ifaces}) ->
    case [Sc || #iface{types = Ts} <- Ifaces, {_, #tinfo{constructors = Cs}} <- maps:to_list(Ts),
                #cinfo{qname = Q, scheme = Sc} <- Cs, Q =:= CQ] of
        [Sc | _] -> {ok, Sc};
        [] -> none
    end.

%% Report §11.2: the names `:forget` takes, the values and the types the
%% session declares; a member goes with its type.
-spec session_names() -> [{'Name', atom(), binary(), binary()}].
session_names() ->
    #env{session = S} = Env = persistent_term:get({?MODULE, env}, #env{}),
    St = session_state(Env),
    lists:usort([name('Value', name_text(Key), scheme_line(name_text(Key), Q, Env, St))
                 || {Key, Q} <- maps:to_list(maps:get(values, S, #{})), is_atom(Key)]
                ++ [name('Type', atom_to_list(N), "type " ++ atom_to_list(N))
                    || N <- maps:keys(maps:get(types, S, #{}))]).

%% Report §11.2: every name the session declares, as it is written, its
%% values, members among them, its types, and its constructors: with
%% nothing typed, these and the modules are what completion lists.
-spec session_texts() -> [binary()].
session_texts() ->
    #env{session = S} = persistent_term:get({?MODULE, env}, #env{}),
    lists:usort([unicode:characters_to_binary(name_text(K))
                 || Which <- [values, types, cons], K <- maps:keys(maps:get(Which, S, #{}))]).

%% Report §11.2: where `:load` finds a module's source, `--source-root`.
-spec source_root() -> binary().
source_root() ->
    #env{source_root = Root} = persistent_term:get({?MODULE, env}, #env{}),
    unicode:characters_to_binary(Root).

%% Report §11.1, §4.2: the namespace segment a file or directory of the
%% source root names, by the compiler's own rule, or None where it names
%% no module.
-spec segment(binary()) -> 'None' | {'Some', binary()}.
segment(Name) ->
    case ern_build:segment(unicode:characters_to_list(Name)) of
        {ok, Segment} -> {'Some', unicode:characters_to_binary(Segment)};
        error -> 'None'
    end.

%% A module in scope: the module itself, its exported values and types,
%% and the constructors of those types, each by the name a person types.
module_names(#iface{namespace = Ns, types = Ts, values = Vs}, St) ->
    [name('Module', qname_text(Ns), "module " ++ qname_text(Ns))]
        ++ [name('Value', qname_text(Q),
                 qname_text(Q) ++ " : " ++ ern_types:format_scheme(Sc, St))
            || {Q, Sc} <- maps:to_list(Vs)]
        ++ lists:append(
             [[name('Type', qname_text(Q), abstract_text(TI) ++ "type " ++ qname_text(Q))
               | [name('Constructor', qname_text(lists:droplast(Q) ++ [CN]),
                       con_line(qname_text(lists:droplast(Q) ++ [CN]), {ok, Sc}, St))
                  || #cinfo{name = CN, scheme = Sc} <- Cs, not TI#tinfo.abstract]]
              || {Q, #tinfo{constructors = Cs} = TI} <- maps:to_list(Ts)]).

name(Kind, Text, Shown) ->
    {'Name', Kind, unicode:characters_to_binary(Shown), unicode:characters_to_binary(Text)}.

scheme_line(Text, Q, Env, St) ->
    case scheme(Q, Env) of
        {ok, Sc} -> Text ++ " : " ++ ern_types:format_scheme(Sc, St);
        none -> Text
    end.

tinfo(Q, #env{ifaces = Ifaces}) ->
    case [TI || #iface{types = Ts} <- Ifaces, #{Q := TI} <- [Ts]] of
        [] -> none;
        Infos -> lists:last(Infos)
    end.

name_text({Owner, Name}) -> atom_to_list(Owner) ++ "." ++ atom_to_list(Name);
name_text(Name) -> atom_to_list(Name).

scheme(Q, #env{ifaces = Ifaces}) ->
    case [Sc || #iface{values = Vs} <- Ifaces, #{Q := Sc} <- [Vs]] of
        [] -> none;
        Schemes -> {ok, lists:last(Schemes)}
    end.

%% The state a session name's type is printed under: the session's types
%% print unqualified, as they do in an input (report §11.2).
session_state(#env{session = S, ifaces = Ifaces}) ->
    St = ern_typecheck:scope_state(Ifaces),
    ern_types:set_scope(St, [], maps:values(maps:get(types, S, #{})), []).

%% Report §11.2: `:forget` removes a name the session declared, and `*`
%% every one of them. A type is forgotten with its constructors. A module
%% the session then no longer reaches, by a name or by a value that holds
%% its functions, collected/1 lets go; a value made before keeps the module
%% of its type while it is reached.
-spec forget(#env{}, binary()) -> {'Left', binary()} | {'Right', #env{}}.
forget(Env, <<"*">>) ->
    {'Right', remember(collected(Env#env{session = #{}}))};
forget(#env{session = S} = Env, Text) ->
    Values = maps:get(values, S, #{}),
    Types = maps:get(types, S, #{}),
    Cons = maps:get(cons, S, #{}),
    case segments(Text) of
        {ok, [Name]} when is_map_key(Name, Values); is_map_key(Name, Types) ->
            Members = [{O, M} || {O, M} <- maps:keys(Values), O =:= Name],
            Gone = constructors(maps:get(Name, Types, none), Cons, Env),
            %% remembered, since completion and `Shift-Tab` read the
            %% session from where the front end keeps it; what nothing
            %% reaches any longer is let go
            Env1 = Env#env{session = S#{values => maps:without([Name | Members], Values),
                                        types => maps:remove(Name, Types),
                                        cons => maps:without(Gone, Cons)}},
            {'Right', remember(collected(Env1))};
        _ ->
            {'Left', <<"the session declares no ", Text/binary>>}
    end.

%% The constructors of the type being forgotten that still stand for it; one
%% whose name a later type took belongs to that type now.
constructors(none, _, _) ->
    [];
constructors(Q, Cons, #env{ifaces = Ifaces}) ->
    [lists:last(CQ) || #iface{types = Ts} <- Ifaces,
                       #{Q := #tinfo{constructors = Cs}} <- [Ts],
                       #cinfo{qname = CQ} <- Cs,
                       maps:get(lists:last(CQ), Cons, none) =:= CQ].

%% Report §11.2, §4.2: the exports of a module in scope, its types and then
%% its values, each with its type as §11.5 prints it.
-spec browse(#env{}, binary()) -> {'Left', binary()} | {'Right', [binary()]}.
browse(Env, Text) ->
    case module_name(Text) of
        {ok, ['Prelude']} -> {'Right', prelude_listing()};
        {ok, Ns} -> browse(Text, Ns, Env);
        {error, Why} -> {'Left', Why}
    end.

%% Report §11.2, §9: the prelude's types and values, as `:browse` lists a
%% module's, since `Prelude` names its namespace (§4.2).
prelude_listing() ->
    St = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    {Types, _} = ern_typecheck:prelude_names(),
    %% the environment holds the standard library's types too, each under
    %% its module's name; the prelude's own are unqualified
    [unicode:characters_to_binary(["type ", qname_text(Q)]) || [_] = Q <- lists:sort(Types)]
    ++ [unicode:characters_to_binary([qname_text(Q), " : ", ern_types:format_scheme(Sc, St)])
        || {Q, Sc} <- lists:sort(ern_typecheck:prelude_values())].

%% Report §11.5: each name and each type as the session writes it, the
%% names qualified and another module's types too.
browse(Text, Ns, #env{ifaces = Ifaces, session = S}) ->
    case [I || #iface{namespace = N} = I <- Ifaces ++ ern_prelude:stdlib_ifaces(), N =:= Ns] of
        [] ->
            {'Left', <<"no module ", Text/binary, " is in scope">>};
        Found ->
            #iface{types = Ts, values = Vs} = Last = lists:last(Found),
            St0 = ern_typecheck:scope_state(Ifaces ++ [Last]),
            St = ern_types:set_scope(St0, [], maps:values(maps:get(types, S, #{})), []),
            Types = [unicode:characters_to_binary([abstract_text(TI), "type ", qname_text(Q)])
                     || {Q, TI} <- lists:sort(maps:to_list(Ts))],
            Values = [unicode:characters_to_binary(
                        [qname_text(Q), " : ", ern_types:format_scheme(Sc, St)])
                      || {Q, Sc} <- lists:sort(maps:to_list(Vs))],
            {'Right', Types ++ Values}
    end.

abstract_text(#tinfo{abstract = true}) -> "abstract ";
abstract_text(_) -> "".

qname_text(Q) -> lists:join(".", [atom_to_list(S) || S <- Q]).

%% Report §2.3: a name as it is written, its segments between the dots,
%% or `none` for text that is no name: an empty segment, or one longer than
%% the host holds in a name, 255 characters. A trailing dot, which
%% completion leaves after a namespace, names the namespace.
segments(Text) ->
    Parts = binary:split(without_dot(Text), <<".">>, [global]),
    case lists:all(fun(P) -> P =/= <<>> andalso byte_size(P) =< 255 end, Parts) of
        true -> {ok, [binary_to_atom(P) || P <- Parts]};
        false -> none
    end.

without_dot(<<>>) ->
    <<>>;
without_dot(Text) ->
    case binary:last(Text) of
        $. -> binary:part(Text, 0, byte_size(Text) - 1);
        _ -> Text
    end.

%% Report §4.2: a module is named by its namespace, each segment of which
%% begins with a capital letter, `Http.Parser` for `http/parser.ern`; a
%% name that is not one is refused rather than looked for.
module_name(Text) ->
    case segments(Text) of
        {ok, Ns} ->
            case lists:all(fun capital/1, Ns) of
                true -> {ok, Ns};
                false -> not_module(Text)
            end;
        none ->
            not_module(Text)
    end.

capital(Segment) ->
    [C | _] = atom_to_list(Segment),
    C >= $A andalso C =< $Z.

not_module(Text) ->
    {error, <<Text/binary, " is not a module name: each segment of one begins with a capital"
              " letter, as in Http.Parser">>}.

%% Report §11.2, §11.4: the documentation of one declaration, as
%% `ern doc` renders it, read from the module that declares it: an input
%% of this session, or a module on the load path.
-spec doc(#env{}, binary()) -> {'Left', binary()} | {'Right', binary()}.
doc(Env, Text) ->
    case page(Env, Text) of
        {ok, Page, _} -> {'Right', unicode:characters_to_binary(Page)};
        none -> {'Left', <<"no documentation for ", Text/binary>>}
    end.

%% The documentation of a name as it is written, with its segments; none
%% for text that is no name.
page(Env, Text) ->
    maybe
        {ok, Segments} ?= segments(Text),
        {ok, Page} ?= doc_of(Env, Segments),
        {ok, Page, Segments}
    end.

%% Report §11.2: the page for a name, as the session stands, for
%% `Shift-Tab`. The reader asks while an input runs, so it reads the
%% environment the front end keeps rather than asking the session.
-spec documentation(binary()) -> 'None' | {'Some', binary()}.
documentation(Text) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    case page(Env, Text) of
        {ok, Page, Segments} ->
            %% Appendix E.0 rule 6: a declaration without a `since` of its
            %% own has its module's, which the brief shows
            Since = case string:find(unicode:characters_to_binary(Page), <<"*Since ">>) of
                        nomatch -> since_line(Env, Segments);
                        _ -> []
                    end,
            {'Some', unicode:characters_to_binary([Page, Since])};
        none ->
            'None'
    end.

since_line(Env, Segments) ->
    V = case module_of_name(Env, Segments) of
            none -> undefined;
            prelude -> ern_page:since(prelude);
            Beam -> ern_page:since(Beam)
        end,
    case V of
        undefined -> [];
        _ -> ["*Since ", V, ".*\n"]
    end.

%% The compiled module a documented name comes from, or the prelude.
module_of_name(Env, Segments) when length(Segments) >= 2 ->
    case beam_of(Env, lists:droplast(Segments)) of
        none -> prelude_or_none(Segments);
        Beam -> Beam
    end;
module_of_name(_, Segments) ->
    prelude_or_none(Segments).

prelude_or_none(Segments) ->
    case prelude_doc(Segments) of
        {ok, _} -> prelude;
        none -> none
    end.

%% Report §11.2, §3.5: what a `.` after a value completes to. The text
%% before the last `.` is checked as an input in a module of its own that
%% does not enter the session, as `Shift-Tab`'s callee is, so a chain of
%% selections is the checker's, and a name the unfinished input binds is
%% not in scope; the fields its type selects are then the checker's too,
%% each listed with its type. A namespace checks as no value and has none.
-spec fields(binary()) -> [{'Name', 'Value', binary(), binary()}].
fields(Typed) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    case string:split(Typed, ".", trailing) of
        [Head, _] when Head =/= <<>> ->
            maybe
                {ok, Binds, Expr} ?= input(Head),
                {'Right', {_, #checked{type = T, env = TEnv}}} ?=
                    check_module(Env#env{n = Env#env.n + 1}, ['$Fields'], {typed, <<"fields">>},
                                 Head, input_entry(Expr), Binds),
                St = ern_typecheck:type_state(TEnv),
                [name('Value', [Head, ".", atom_to_list(F)],
                      [Head, ".", atom_to_list(F), " : ", ern_types:format(FT, St)])
                 || {F, FT} <- ern_typecheck:fields(T, TEnv)]
            else
                _ -> []
            end;
        _ ->
            []
    end.

%% Report §11.2: inside a call, `Shift-Tab` shows the callee's signature
%% with its parameters as declared and the one at the cursor marked, which
%% the shell does, in three parts: before, the parameter, after. The
%% parser says which call the unfinished input stops inside; the callee is
%% checked as an input of one name, without entering the session, and its
%% declared type is printed with the parameter names its documentation
%% carries.
-spec signature(binary()) -> 'None' | {'Some', {binary(), binary(), binary()}}.
signature(Before) ->
    case within(Before) of
        {Path, Name, At} ->
            %% a constructor's name begins with a capital (report §2.3)
            case not is_integer(At) orelse hd(atom_to_list(Name)) < $a of
                true -> con_signature(Path, Name, At);
                false -> call_signature(Path, Name, At)
            end;
        none ->
            'None'
    end.

call_signature(Path, Name, N) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    Text = unicode:characters_to_binary(qname_text(Path ++ [Name])),
    %% a callee that does not check, a name not in scope, has none, and
    %% neither has one whose declaration the checker does not hold or whose
    %% type is not a function's
    case scheme_of(Env, Text) of
        {ok, Scheme, TEnv} ->
            {Head, Marked, Rest} = ern_types:format_call(Scheme, parameters(Env, Path, Name), N,
                                                         ern_typecheck:type_state(TEnv)),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
        none ->
            'None'
    end.

%% The declared type of a name, checked as an input of that one name in a
%% module of its own that does not enter the session.
scheme_of(Env, Text) ->
    maybe
        {ok, Binds, Expr} ?= input(Text),
        {'Right', {_, #checked{typed = Typed, env = TEnv}}} ?=
            check_module(Env#env{n = Env#env.n + 1}, ['$Signature'], {typed, <<"signature">>},
                         Text, input_entry(Expr), Binds),
        {P, Nm} ?= one_name(Typed),
        {ok, #scheme{type = {tfn, _, _, _}} = Scheme} ?= ern_typecheck:declared_scheme(TEnv, P, Nm),
        {ok, Scheme, TEnv}
    else
        _ -> none
    end.

%% Report §11.2: a constructor's fields, as a signature, the one whose
%% value is at the cursor marked, and none where a field's name stands.
con_signature(Path, Name, At) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    case con_info(Env, Path, Name) of
        {ok, #cinfo{fields = Fields, scheme = #scheme{type = {tfn, Ps, _, _}} = Sc}} ->
            %% a constructor is declared, so its signature is a head's
            Names = case Fields of
                        {named, Fs} -> Fs;
                        _ -> lists:duplicate(length(Ps), '_')
                    end,
            Marked = case At of
                         {field, F} -> index(F, Names, length(Ps));
                         none -> length(Ps);
                         I -> I
                     end,
            {Head, This, Rest} = ern_types:format_call(Sc, Names, Marked, session_state(Env)),
            {'Some', {unicode:characters_to_binary([qname_text(Path ++ [Name]), Head]),
                      unicode:characters_to_binary(This), unicode:characters_to_binary(Rest)}};
        _ ->
            'None'
    end.

index(F, Names, Otherwise) ->
    case lists:search(fun({_, N}) -> N =:= F end, lists:zip(lists:seq(0, length(Names) - 1),
                                                           Names)) of
        {value, {I, _}} -> I;
        false -> Otherwise
    end.

%% A constructor by the name written: the session's, the prelude's, or a
%% module's.
con_info(#env{session = S, ifaces = Ifaces}, [], Name) ->
    case maps:get(Name, maps:get(cons, S, #{}), none) of
        none -> ern_typecheck:prelude_con(Name);
        CQ -> cinfo(CQ, Ifaces)
    end;
con_info(#env{ifaces = Ifaces}, Path, Name) ->
    cinfo(Path ++ [Name], Ifaces ++ ern_prelude:stdlib_ifaces()).

cinfo(CQ, Ifaces) ->
    case [CI || #iface{types = Ts} <- Ifaces, {_, #tinfo{constructors = Cs}} <- maps:to_list(Ts),
                #cinfo{qname = Q} = CI <- Cs, Q =:= CQ] of
        [CI | _] -> {ok, CI};
        [] -> none
    end.

%% Report §11.2: the call is found wherever the input stands, so the text
%% is read as an expression, as a block's statement, a `let`, and as
%% declarations, the first that stops inside a call answering.
within(Before) ->
    case [W || Parse <- [fun ern_parser:parse_expr/1, fun ern_parser:parse_stmt/1,
                         fun ern_parser:parse_string/1],
               {error, #diag{incomplete = true, within = W}} <- [Parse(Before)],
               W =/= undefined] of
        [W | _] -> W;
        [] -> none
    end.

%% The parameter names a function's documentation entry carries, from the
%% session's input or the module that declares it; none where no
%% declaration carries them, the prelude's and a function value's.
parameters(Env, Path, Name) ->
    Beam = case session_beam(Env, Path, Name) of
               none when Path =/= [] -> beam_of(Env, Path);
               B -> B
           end,
    %% a module's function by its local name, a type's member as `Type.name`
    Keys = [entry_name([Name]) | [entry_name([lists:last(Path), Name]) || Path =/= []]],
    case Beam of
        none ->
            none;
        _ ->
            {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
            case [Ps || {{function, K, _}, _, _, _, #{params := Ps}} <- Entries,
                        lists:member(atom_to_binary(K), Keys)] of
                [Ps | _] -> Ps;
                [] -> none
            end
    end.

session_beam(#env{session = S, beams = Beams}, Path, Name) ->
    Key = case Path of
              [] -> Name;
              [Owner] -> {Owner, Name};
              _ -> none
          end,
    case maps:get(Key, maps:get(values, S, #{}), none) of
        none -> none;
        Q -> beam(Q, Path ++ [Name], Beams)
    end.

%% The session's own names first, then a module's, then the prelude's,
%% which is where a name no module declares is documented (report §9);
%% then a constructor, whose documentation is its type's, and a module,
%% whose documentation is the head of its page (report §11.2).
%% A name that is a type and a module too, `List`, shows the type's section
%% and then the module's head; a namespace that is neither lists what it
%% holds.
doc_of(_Env, ['Prelude']) ->
    %% report §11.2, §4.2: `Prelude` names the prelude, whose page it is
    {ok, ern_page:prelude_page()};
doc_of(Env, ['Prelude' | Segments]) ->
    %% the prelude's name, past one the session declares; a member of a
    %% built-in type is documented by its type's module (§9.6)
    first([fun() -> prelude_doc(Segments) end, fun() -> module_doc(Env, Segments) end]);
doc_of(Env, Segments) ->
    case first([fun() -> session_doc(Env, Segments) end,
                fun() -> module_doc(Env, Segments) end,
                fun() -> prelude_doc(Segments) end,
                fun() -> constructor_doc(Env, Segments) end]) of
        {ok, Page} ->
            case module_head(Env, Segments) of
                {ok, Head} -> {ok, [Page, "\n", Head]};
                none -> {ok, Page}
            end;
        none ->
            first([fun() -> module_head(Env, Segments) end,
                   fun() -> namespace_doc(Env, Segments) end])
    end.

%% Report §11.2: a namespace that is no module and no documented type,
%% `Net` where only `net/http.ern` is, is documented by what it holds, each
%% name with its type.
namespace_doc(_, []) ->
    none;
namespace_doc(Env, Segments) ->
    Prefix = unicode:characters_to_binary(qname_text(Segments) ++ "."),
    case [Shown || {'Name', _, Shown, Text} <- names(Env),
                   binary:match(Text, Prefix) =:= {0, byte_size(Prefix)}] of
        [] -> none;
        Held -> {ok, ["# namespace ", qname_text(Segments), "\n\n",
                      [["- `", S, "`\n"] || S <- Held]]}
    end.

first([]) ->
    none;
first([F | Fs]) ->
    case F() of
        {ok, Page} -> {ok, Page};
        none -> first(Fs)
    end.

%% Report §11.4: a constructor is documented in its type's section, so its
%% documentation is its type's: a session constructor's the session's type,
%% a module's its module's type, and an unqualified one the prelude's.
constructor_doc(#env{session = S, beams = Beams} = Env, [Name]) ->
    case maps:get(Name, maps:get(cons, S, #{}), none) of
        none ->
            case ern_typecheck:prelude_con(Name) of
                {ok, #cinfo{type_qname = TQ}} -> prelude_doc(TQ);
                none -> none
            end;
        CQ ->
            case owner(CQ, Env) of
                {ok, TQ} ->
                    T = lists:last(TQ),
                    {ok, ern_page:session_declaration(beam(TQ, [T], Beams), entry_name([T]),
                                                      entry)};
                none ->
                    none
            end
    end;
constructor_doc(Env, Segments) ->
    case owner(Segments, Env) of
        {ok, TQ} -> module_doc(Env, TQ);
        none -> none
    end.

%% The type a constructor belongs to, from the interfaces in scope.
owner(CQ, #env{ifaces = Ifaces}) ->
    Ns = lists:droplast(CQ),
    Con = lists:last(CQ),
    case [TQ || #iface{types = Ts} <- Ifaces ++ ern_prelude:stdlib_ifaces(),
                {TQ, #tinfo{constructors = Cs, abstract = false}} <- maps:to_list(Ts),
                lists:droplast(TQ) =:= Ns,
                #cinfo{name = N} <- Cs, N =:= Con] of
        [TQ | _] -> {ok, TQ};
        [] -> none
    end.

%% Report §11.2: a module's documentation is the head of its page.
module_head(Env, Segments) ->
    case beam_of(Env, Segments) of
        none -> none;
        Beam -> {ok, ern_page:module_head(Beam)}
    end.

prelude_doc([]) ->
    none;
prelude_doc(Segments) ->
    ern_page:prelude_declaration(entry_name(Segments)).

%% A name the session declared: the beam of the input that declared it, and
%% the entry under its unqualified name, a member under `Type.name`, shown
%% under the name as the session writes it and with the type the shell
%% prints (report §11.2).
session_doc(#env{session = S, beams = Beams} = Env, Segments) ->
    Key = case Segments of
              [Name] -> Name;
              [Owner, Name] -> {Owner, Name};
              _ -> none
          end,
    Values = maps:get(values, S, #{}),
    Types = maps:get(types, S, #{}),
    case {maps:get(Key, Values, none), maps:get(Key, Types, none)} of
        {none, none} ->
            none;
        {none, Q} ->
            T = lists:last(Q),
            {ok, ern_page:session_declaration(beam(Q, [T], Beams), entry_name([T]), entry)};
        {Q, _} ->
            Line = scheme_line(name_text(Key), Q, Env, session_state(Env)),
            {ok, ern_page:session_declaration(beam(Q, Segments, Beams), entry_name(Segments),
                                              [Line])}
    end.

%% The input that declared the name: the qualified name without the
%% segments the name itself is written with.
beam(Q, Segments, Beams) ->
    maps:get(lists:sublist(Q, length(Q) - length(Segments)), Beams, none).

%% The name a documentation entry is under, as it is written: `map`, a
%% member as `Stack.push`, and a prelude name as `Address.call`.
entry_name(Segments) ->
    unicode:characters_to_binary(qname_text(Segments)).

%% A module on the load path, `List.map`, or one of its type's members,
%% `Net.Http.Request.method`.
module_doc(Env, Segments) when length(Segments) >= 2 ->
    case entry(beam_of(Env, lists:droplast(Segments)), entry_name([lists:last(Segments)])) of
        {ok, Page} ->
            {ok, Page};
        none when length(Segments) >= 3 ->
            [Owner, Member] = lists:nthtail(length(Segments) - 2, Segments),
            entry(beam_of(Env, lists:sublist(Segments, length(Segments) - 2)),
                  entry_name([Owner, Member]));
        none ->
            none
    end;
module_doc(_, _) ->
    none.

%% The compiled module behind a namespace, as bytes: the one `:load` or
%% `:reload` compiled, which is loaded from memory and has no file; else the
%% file the runner loaded it from, an `.erc`, or the `.beam` of a module on
%% the code path, the standard library's among them. `beam_lib` takes
%% either as a binary.
beam_of(#env{beams = Beams}, Ns) ->
    case Beams of
        #{Ns := Beam} -> Beam;
        _ -> beam_on_path(Ns)
    end.

beam_on_path(Ns) ->
    Mod = ern_emitter:module_atom(Ns),
    Paths = [code:which(Mod), code:where_is_file(atom_to_list(Mod) ++ ".beam")],
    case [Bin || P <- Paths, is_list(P), {ok, Bin} <- [file:read_file(P)]] of
        [] -> none;
        [Bin | _] -> Bin
    end.

entry(none, _) -> none;
entry(Beam, Name) -> ern_page:declaration(Beam, Name).

%% Report §11.2: a typed input is the file `input`; an input from a startup
%% file is named by the file, its positions moved to the line it stands on
%% there and, on its first line, to the column it begins in, and its lines
%% quoted from the file.
diagnostic({typed, Name}, Input, Diags) ->
    unicode:characters_to_binary([ern_diag:format(binary_to_list(Name), Input, D) || D <- Diags]);
diagnostic({file, Path, First, Column}, Input, Diags) ->
    Source = case file:read_file(Path) of
                 {ok, Text} -> Text;
                 {error, _} -> Input
             end,
    unicode:characters_to_binary(
      [ern_diag:format(ern_build:shown(binary_to_list(Path)), Source,
                       moved(D, First - 1, Column - 1))
       || D <- Diags]).

%% A diagnostic's positions, a number of lines further down, and on the
%% input's first line a number of columns further right.
moved(#diag{span = Span, labels = Labels} = D, Lines, Columns) ->
    D#diag{span = moved_span(ern_diag:span(Span), Lines, Columns),
           labels = [{moved_span(ern_diag:span(S), Lines, Columns), T} || {S, T} <- Labels]}.

moved_span({Line, Column, {EndLine, EndColumn}}, Lines, Columns) ->
    {Line + Lines, moved_column(Line, Column, Columns),
     {EndLine + Lines, moved_column(EndLine, EndColumn, Columns)}}.

moved_column(1, Column, Columns) -> Column + Columns;
moved_column(_, Column, _) -> Column.

%% Report §11.2: `:load` takes a module by its namespace. Its source under
%% the source root is compiled as `ern build` would compile it and nothing is
%% written; a module with no source there is loaded from its compiled
%% form, on the load path. Afterwards it is in scope by its qualified
%% name, as every loaded module is (§4.2). A module the session has loaded
%% is refused: loading it over itself would end what runs its previous
%% version, which `:reload` alone does, and says so.
-spec load(#env{}, binary()) -> {'Left', binary()} | {'Right', {#env{}, binary()}}.
load(#env{modules = Modules} = Env, Text) ->
    case module_name(Text) of
        {ok, Ns} ->
            Name = unicode:characters_to_binary(qname_text(Ns)),
            case lists:any(fun(#iface{namespace = N}) -> N =:= Ns end,
                           ern_prelude:stdlib_ifaces()) of
                %% report §4.2, §11.2: a standard library namespace is taken,
                %% and the module, in scope since the session began, is one
                %% the session has loaded, which is refused
                true ->
                    {'Left', <<Name/binary, " is the standard library's, in scope from the"
                               " start\n">>};
                false when is_map_key(Ns, Modules) ->
                    {'Left', <<Name/binary, " is loaded already; :reload compiles it again"
                               " when its source has changed\n">>};
                false ->
                    load(Env, Name, Ns)
            end;
        {error, Why} ->
            {'Left', <<Why/binary, "\n">>}
    end.

%% A refusal ends in a line feed, as a diagnostic the compiler gives does,
%% since the shell prints both alike. What is loaded is remembered, since
%% completion and `Shift-Tab` read the session from where it is kept.
load(#env{source_root = Root} = Env, Name, Ns) ->
    case source_of(Env, Ns) of
        {ok, File} ->
            case (ern_build:module_of(ern_build:absolute(File), Root))#mod.ns of
                Ns ->
                    %% report §11.2: what it uses that the session has not
                    %% loaded and whose source the root holds is compiled too
                    Sources = with_sources(Env, [{Ns, File}], []),
                    case compile_in_order(Env, Sources) of
                        {ok, Modules} ->
                            Lines = [[qname_text(N), ", compiled from ", relative(F, Env)]
                                     || {N, F} <- lists:reverse(Sources)],
                            with_needed(Env, Modules,
                                        unicode:characters_to_binary(lists:join("\n", Lines)));
                        {error, Failed} ->
                            {'Left', iolist_to_binary(Failed)}
                    end;
                Ns2 ->
                    {'Left', <<(list_to_binary(qname_text(Ns2)))/binary, " is declared in ",
                               (list_to_binary(relative(File, Env)))/binary,
                               ", which is not where ", Name/binary, " belongs\n">>}
            end;
        none ->
            case compiled_of(Env, Ns) of
                {ok, File, Beam, Hash} ->
                    with_needed(Env, [{Ns, Beam, Hash}],
                                <<Name/binary, ", from ",
                                  (list_to_binary(relative(File, Env)))/binary>>);
                none ->
                    {'Left', <<"no module ", Name/binary, " under the source root or on the"
                               " load path\n">>}
            end
    end.

%% Report §11.2: the modules to compile for `:load`, each with its source:
%% the one named, and each it uses, directly or through another, that the
%% session has not loaded and whose source the source root holds. A module
%% that does not parse uses nothing here; compiling it reports why.
with_sources(_Env, [], Acc) ->
    Acc;
with_sources(#env{source_root = Root, modules = Loaded} = Env, [{Ns, File} | Rest], Acc) ->
    case lists:keymember(Ns, 1, Acc) of
        true ->
            with_sources(Env, Rest, Acc);
        false ->
            Deps = try ern_build:compile_order([ern_build:module_of(ern_build:absolute(File),
                                                                    Root)],
                                               Root, load_path(Env)) of
                       [#mod{deps = Ds}] -> Ds
                   catch
                       throw:_ -> []
                   end,
            More = [{D, F} || D <- Deps, not is_map_key(D, Loaded), {ok, F} <- [source_of(Env, D)]],
            with_sources(Env, Rest ++ More, Acc ++ [{Ns, File}])
    end.

%% The modules loaded, after what they use that the session has not
%% loaded, and `:load`'s answer.
with_needed(Env, Modules, Line) ->
    case needed(Env, Modules) of
        {ok, Needed} ->
            All = Needed ++ Modules,
            case refused_compiled(Env, All) of
                none -> installed(Env, All, Line);
                Refusal -> {'Left', <<(unicode:characters_to_binary(Refusal))/binary, "\n">>}
            end;
        {error, Text} ->
            {'Left', Text}
    end.

%% Report §11.2: a compiled module is refused as `ern run` refuses one: a
%% file that holds another module than its path names, and a module compiled
%% against another interface of a module it uses, or of the standard
%% library, than the session holds; none, or the refusal.
refused_compiled(Env, All) ->
    Std = ern_build:stdlib_hash("."),
    Ifaces = [I || {_, Beam, _} <- All, {ok, #{iface := I}} <- [ern_iface:read(Beam)]]
        ++ Env#env.ifaces ++ ern_prelude:stdlib_ifaces(),
    Refusals = lists:append([compiled_refusals(Ns, Beam, Ifaces, Std) || {Ns, Beam, _} <- All]),
    case Refusals of
        [] -> none;
        [First | _] -> First
    end.

compiled_refusals(Ns, Beam, Ifaces, Std) ->
    {ok, #{iface := #iface{namespace = Held}, deps := Deps} = Chunk} = ern_iface:read(Beam),
    Name = ern_build:qname(Ns),
    [Name ++ "'s compiled file holds " ++ ern_build:qname(Held) ++ "; build it again from its"
     " source root" || Held =/= Ns]
        ++ [Name ++ " was compiled against another standard library; build " ++ Name
            ++ " again" || not lists:member(maps:get(stdlib, Chunk, none), [none, Std])]
        ++ [Name ++ " was compiled against another " ++ ern_build:qname(D) ++ "; build "
            ++ Name ++ " again"
            || {D, Hash} <- Deps,
               [I | _] <- [[I || I <- Ifaces, I#iface.namespace =:= D]],
               ern_iface:hash(I) =/= Hash].

%% The modules installed and their bindings evaluated, and `:load`'s answer.
installed(Env, All, Line) ->
    Env1 = install(Env, All),
    case initialize(in_order(All)) of
        ok ->
            {'Right', {remember(Env1), Line}};
        {fault, Site, Cause} ->
            lists:foreach(fun({N, _, _}) -> withdraw(ern_emitter:module_atom(N)) end, All),
            {'Left', <<(binding_fault(Site, Cause))/binary, "; nothing was loaded\n">>}
    end.

%% Report §8.5, §11.2: the modules in the order their bindings are
%% evaluated, each after those it depends on.
in_order(Modules) ->
    ByMod = maps:from_list([{ern_emitter:module_atom(Ns), M} || {Ns, _, _} = M <- Modules]),
    [maps:get(Mod, ByMod)
     || Mod <- ern_rt:ordered([ern_emitter:module_atom(Ns) || {Ns, _, _} <- Modules])].

%% Report §11.2: a module a failed `:load` or `:reload` had loaded, gone with
%% the processes its bindings started, which end as a reload ends those of a
%% previous version, so that the session is as it was.
withdraw(Mod) ->
    code:delete(Mod),
    unloaded([Pid || {Pid, _} <- ern_rt:live(), erlang:check_process_code(Pid, Mod)]),
    code:purge(Mod).

%% Report §7.3, §11.2: each process ends with its code unloaded, and is
%% waited for before its code is purged, since the purge kills one that has
%% not yet taken the signal, which would end `Killed`.
unloaded(Pids) ->
    Monitors = [erlang:monitor(process, Pid) || Pid <- Pids],
    lists:foreach(fun(Pid) -> exit(Pid, {ern, code_unloaded}) end, Pids),
    lists:foreach(fun(Monitor) -> receive {'DOWN', Monitor, process, _, _} -> ok end end,
                  Monitors).

%% Report §11.2, §8.5: the top-level bindings of each module, dependencies
%% first, each module's evaluated in a process of the shell's own, whose
%% fault is this answer's and not a fault report's; ok, or the module whose
%% binding faulted and its cause.
initialize([]) ->
    ok;
initialize([{Ns, _, _} | Rest]) ->
    Mod = ern_emitter:module_atom(Ns),
    case erlang:function_exported(Mod, '$init', 0) of
        true -> initialize(Ns, Mod, Rest);
        false -> initialize(Rest)
    end.

%% A binding's fault is :load's to report, so the process catches it and
%% ends without one, and no subscriber of Process.faults hears of it twice;
%% a kill, which nothing catches, is seen by the monitor. The fault is
%% named by the binding's site, which '$init' gave the process (report
%% §8.5, §11.2), and a kill by the module.
initialize(Ns, Mod, Rest) ->
    Me = self(),
    Ref = make_ref(),
    Init = fun() ->
               Result = try Mod:'$init'() of
                            _ -> ok
                        catch
                            throw:{ern, fault, Msg} -> {fault, ern_rt:site(), Msg};
                            throw:{ern, fault, Msg, _} -> {fault, ern_rt:site(), Msg};
                            Class:Reason -> {fault, ern_rt:site(), fault_text(Class, Reason)}
                        end,
               Me ! {Ref, Result}
           end,
    %% watched from its spawn, so that its end is known however soon it
    %% comes (report §6.9)
    _ = ern_rt:spawn_monitored(Init, fun(Down) -> {Ref, Down} end, <<"Shell.load">>),
    receive
        {Ref, Result} when Result =:= ok; element(1, Result) =:= fault ->
            receive {Ref, {'Down', _, _, _}} -> ok end,
            case Result of
                ok -> initialize(Rest);
                {fault, _, _} = Fault -> Fault
            end;
        {Ref, {'Down', _, Reason, _}} ->
            {fault, unicode:characters_to_binary(qname_text(Ns)),
             case Reason of
                 {'Fault', Cause} -> Cause;
                 Other -> atom_to_binary(Other)
             end}
    end.

%% Report §11.2: a reloaded module's binding that faulted, which with the
%% bindings after it keeps what the previous version gave them.
kept_values(Site, Cause) ->
    <<(binding_fault(Site, Cause))/binary, "; it and the bindings after it keep the values of the"
      " previous version">>.

binding_fault(Site, Cause) ->
    <<Site/binary, " faulted: ", (ern_show:controls(Cause, line))/binary>>.


%% Report §11.2: what the modules use that the session has not loaded,
%% each found as the runner finds it, by namespace on the load path, and
%% loaded before them, the modules it uses first.
needed(Env, Modules) ->
    Compiled = [Ns || {Ns, _, _} <- Modules],
    lists:foldl(fun({_, Beam, _}, Found) -> needed(Env, Beam, Found, Compiled) end, {ok, []},
                Modules).

%% What one module uses that neither the session nor the modules compiled
%% with it, Compiled, provide.
needed(_Env, _Beam, {error, _} = Error, _Compiled) ->
    Error;
needed(#env{modules = Loaded} = Env, Beam, {ok, _} = Found, Compiled) ->
    {ok, #{deps := Deps}} = ern_iface:read(Beam),
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   ({Ns, _}, {ok, Acc}) ->
                        case is_map_key(Ns, Loaded) orelse lists:member(Ns, Compiled)
                             orelse lists:keymember(Ns, 1, Acc) of
                            true -> {ok, Acc};
                            false -> needed_one(Env, Ns, Acc, Compiled)
                        end
                end, Found, Deps).

needed_one(Env, Ns, Acc, Compiled) ->
    case compiled_of(Env, Ns) of
        {ok, _, Beam, Hash} ->
            case needed(Env, Beam, {ok, Acc}, Compiled) of
                {ok, Acc1} -> {ok, Acc1 ++ [{Ns, Beam, Hash}]};
                Error -> Error
            end;
        none ->
            {error, <<"no module ", (unicode:characters_to_binary(qname_text(Ns)))/binary,
                      " on the load path\n">>}
    end.

%% Report §11.2: every module the session loaded whose source has changed,
%% compiled and loaded again. A process still in the previous version, and
%% a binding that holds a function of it, keep it; the reload that needs
%% that version ends them, and the one before names them. Every changed
%% module is compiled before any is loaded, and where one does not compile
%% none is, so the session goes on with every module as it was.
-spec reload(#env{}) -> {'Left', binary()} | {'Right', {#env{}, [binary()]}}.
reload(#env{modules = Modules} = Env) ->
    Sources = [{Ns, Loaded, source_of(Env, Ns)}
               || {Ns, Loaded} <- lists:sort(maps:to_list(Modules))],
    Changed = [{Ns, File}
               || {Ns, Loaded, {ok, File}} <- Sources,
                  {ok, Hash} <- [source_hash(File)],
                  Hash =/= Loaded],
    Sourceless = sourceless(Env, [Ns || {Ns, _, none} <- Sources]),
    case Changed of
        [] ->
            {'Right', {Env, [<<"no source has changed">> | Sourceless]}};
        _ ->
            case compile_all(Env, Changed) of
                {ok, Needed, Compiled} ->
                    %% what the changed modules use and the session had not
                    %% loaded is loaded as `:load` loads it, first
                    Env0 = install(Env, Needed),
                    case initialize(Needed) of
                        ok ->
                            {Env1, Lines} = lists:foldl(fun reload_one/2, {Env0, []}, Compiled),
                            Faulted = case initialize(in_order(Compiled)) of
                                          ok -> [];
                                          {fault, Site, Cause} -> [kept_values(Site, Cause)]
                                      end,
                            {'Right', {remember(Env1),
                                       lists:reverse(Lines) ++ Faulted ++ Sourceless}};
                        {fault, Site, Cause} ->
                            lists:foreach(fun({N, _, _}) -> withdraw(ern_emitter:module_atom(N))
                                          end, Needed),
                            {'Left', <<(binding_fault(Site, Cause))/binary,
                                       "; nothing was reloaded\n">>}
                    end;
                {error, Text} ->
                    {'Left', iolist_to_binary([Text, "nothing was reloaded\n"])}
            end
    end.

%% Report §11.2: a loaded module whose source the source root does not
%% hold is named, since `:reload` cannot compile it again.
sourceless(_Env, []) ->
    [];
sourceless(#env{source_root = Root}, Names) ->
    Text = lists:join(", ", [qname_text(Ns) || Ns <- Names]),
    [unicode:characters_to_binary(["the source root ", ern_build:shown(Root),
                                   " holds no source of ", Text])].

%% Report §11.2: the changed modules compiled in the order they use one
%% another, each against the session's modules and those compiled before
%% it; and, while one's interface differs from the one the session holds,
%% every loaded module that uses it compiled again with them, from its
%% source. The modules compiled, with what they use that the session has
%% not loaded; or why they cannot all be. A regression: a module that used
%% a changed interface kept running against the previous one, and faulted.
compile_all(Env, Changed) ->
    case compile_in_order(Env, Changed) of
        {ok, Modules} ->
            case stale_users(Env, Changed, Modules) of
                [] ->
                    case needed(Env, Modules) of
                        {ok, Needed} -> {ok, Needed, Modules};
                        Error -> Error
                    end;
                Users ->
                    case [Ns || Ns <- Users, source_of(Env, Ns) =:= none] of
                        [] ->
                            More = [{Ns, File} || Ns <- Users, {ok, File} <- [source_of(Env, Ns)]],
                            compile_all(Env, Changed ++ More);
                        Sourceless ->
                            {error, [unicode:characters_to_binary(
                                       [qname_text(Ns), " uses a module whose interface changed,"
                                        " and the source root holds no source of it\n"])
                                     || Ns <- Sourceless]}
                    end
            end;
        Error ->
            Error
    end.

%% Each module compiled, a module before those that use it, against the
%% interfaces of the session and of the modules compiled before it.
compile_in_order(#env{source_root = Root} = Env, Set) ->
    try ern_build:compile_order([ern_build:module_of(ern_build:absolute(F), Root)
                                 || {_, F} <- Set], Root, load_path(Env)) of
        Ordered ->
            {Compiled, _} =
                lists:mapfoldl(fun(#mod{ns = Ns, file = File}, Ifaces) ->
                                   case compile_source(Env, File, Ifaces) of
                                       {ok, _, Beam, _} = Ok ->
                                           {ok, #{iface := I}} = ern_iface:read(Beam),
                                           {{Ns, Ok}, Ifaces#{Ns => I}};
                                       Error ->
                                           {{Ns, Error}, Ifaces}
                                   end
                               end, loaded_ifaces(Env), Ordered),
            case [Text || {_, {error, Text}} <- Compiled] of
                [] -> {ok, [{Ns, Beam, Hash} || {Ns, {ok, _, Beam, Hash}} <- Compiled]};
                Failed -> {error, Failed}
            end
    catch
        throw:{cli_error, Message} ->
            {error, [unicode:characters_to_binary([Message, "\n"])]};
        throw:{errors, Failed, Diags} ->
            {ok, Source} = file:read_file(Failed),
            {error, [unicode:characters_to_binary(
                       [ern_diag:format(ern_build:shown(Failed), Source, D) || D <- Diags])]}
    end.

%% The loaded modules, outside those compiled, that use a compiled module
%% whose interface is not the one the session holds.
stale_users(#env{modules = Loaded} = Env, Set, Modules) ->
    Held = loaded_ifaces(Env),
    Changed = [Ns || {Ns, Beam, _} <- Modules,
                     {ok, #{iface := I}} <- [ern_iface:read(Beam)],
                     not is_map_key(Ns, Held)
                         orelse ern_iface:hash(maps:get(Ns, Held)) =/= ern_iface:hash(I)],
    [Ns || Ns <- lists:sort(maps:keys(Loaded)), not lists:keymember(Ns, 1, Set),
           lists:any(fun({D, _}) -> lists:member(D, Changed) end, recorded_deps(Env, Ns))].

%% The dependencies a loaded module was compiled against, as its compiled
%% form records them: the session's, or the file it was loaded from.
recorded_deps(#env{beams = Beams}, Ns) ->
    Beam = case Beams of
               #{Ns := B} -> B;
               _ ->
                   {ok, B} = file:read_file(code:which(ern_emitter:module_atom(Ns))),
                   B
           end,
    {ok, #{deps := Deps}} = ern_iface:read(Beam),
    Deps.

%% The interfaces of the modules the session has loaded, by namespace.
loaded_ifaces(#env{ifaces = Ifaces, modules = Modules}) ->
    maps:from_list([{I#iface.namespace, I} || I <- Ifaces,
                                               is_map_key(I#iface.namespace, Modules)]).

reload_one({Ns, Beam, Hash}, {Env, Lines}) ->
    Mod = ern_emitter:module_atom(Ns),
    Name = unicode:characters_to_binary(qname_text(Ns)),
    {Ended, Env1} = case erlang:check_old_code(Mod) of
                        true -> end_previous(Env, Mod);
                        false -> {[], Env}
                    end,
    code:purge(Mod),
    Env2 = install(Env1, Ns, Beam, Hash),
    Waiting = in_previous(Env2, Mod),
    {Env2, waiting_line(Name, Waiting) ++ ended_lines(Name, Ended)
           ++ [<<Name/binary, ", compiled again">> | Lines]}.

ended_lines(_, []) ->
    [];
ended_lines(Name, Ended) ->
    [<<Name/binary, ": ended ", (what(Ended))/binary, " in the previous version">>].

waiting_line(_, []) ->
    [];
waiting_line(Name, Waiting) ->
    [<<Name/binary, ": ", (what(Waiting))/binary, " in the previous version; a further reload"
       " of it ends them">>].

what(Items) ->
    unicode:characters_to_binary(lists:join(", ", Items)).

%% Report §11.2: what is left in the version a reload replaced, a process
%% by its spawn site (§6.9) and a binding by its name.
in_previous(Env, Mod) ->
    [<<Site/binary, ", a process">> || {Pid, Site} <- ern_rt:live(),
                                       erlang:check_process_code(Pid, Mod)]
        ++ [<<(atom_to_binary(Name))/binary, ", a binding">>
            || {Name, _} <- bindings_of(Env, Mod)].

%% Report §7.3, §11.2: the processes still in it end with the cause the
%% report gives them, a fault reported as every fault is, and the bindings
%% that hold a function of it are forgotten.
end_previous(#env{session = S} = Env, Mod) ->
    Processes = [{Pid, Site} || {Pid, Site} <- ern_rt:live(),
                                erlang:check_process_code(Pid, Mod)],
    unloaded([Pid || {Pid, _} <- Processes]),
    Bindings = bindings_of(Env, Mod),
    Values = maps:without([Key || {_, Key} <- Bindings], maps:get(values, S, #{})),
    {[<<Site/binary, ", a process">> || {_, Site} <- Processes]
     ++ [<<(atom_to_binary(Name))/binary, ", a binding">> || {Name, _} <- Bindings],
     Env#env{session = S#{values => Values}}}.

%% The session's bindings whose value holds a function of the module.
bindings_of(#env{session = S}, Mod) ->
    [{name_atom(Key), Key}
     || {Key, Q} <- maps:to_list(maps:get(values, S, #{})),
        holds_fun(value_of(Q), Mod)].

name_atom({_, Name}) -> Name;
name_atom(Name) -> Name.

value_of(Q) ->
    Holder = ern_emitter:module_atom(lists:droplast(Q)),
    persistent_term:get({Holder, lists:last(Q)}, undefined).

holds_fun(F, Mod) when is_function(F) ->
    element(2, erlang:fun_info(F, module)) =:= Mod;
holds_fun([H | T], Mod) -> holds_fun(H, Mod) orelse holds_fun(T, Mod);
holds_fun(T, Mod) when is_tuple(T) -> holds_fun(tuple_to_list(T), Mod);
holds_fun(M, Mod) when is_map(M) -> holds_fun(maps:to_list(M), Mod);
holds_fun(_, _) -> false.

%% Each module loaded, in order, and in scope by its namespace.
install(Env, Modules) ->
    lists:foldl(fun({Ns, Beam, Hash}, E) -> install(E, Ns, Beam, Hash) end, Env, Modules).

install(#env{ifaces = Ifaces, modules = Modules} = Env, Ns, Beam, Hash) ->
    Mod = ern_emitter:module_atom(Ns),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), Beam),
    {ok, #{iface := Iface}} = ern_iface:read(Beam),
    Env#env{ifaces = [I || I <- Ifaces, I#iface.namespace =/= Ns] ++ [Iface],
            modules = Modules#{Ns => Hash},
            beams = maps:put(Ns, Beam, Env#env.beams)}.

%% Report §11.2: a module compiled against the modules the session has
%% loaded, as Ifaces holds them. A regression: a dependency `:load` had
%% compiled in memory was sought as a `.erc`, and the dependent refused.
compile_source(#env{source_root = Root} = Env, File, Ifaces) ->
    case ern_build:compile_source(File, Root, load_path(Env), Ifaces) of
        {ok, Ns, Beam, Hash} ->
            {ok, Ns, Beam, Hash};
        {refused, Text} ->
            {error, unicode:characters_to_binary([Text, "\n"])};
        {error, Failed, Diags} ->
            {ok, Source} = file:read_file(Failed),
            %% report §11.5: the file named from the working directory
            {error, unicode:characters_to_binary(
                      [ern_diag:format(ern_build:shown(Failed), Source, D) || D <- Diags])}
    end.

%% Report §11.2, §11.1: where a compiled module is found by its namespace,
%% one `:load` names or one a module uses: the load path, and then the
%% source root, which is where `ern build` writes by default.
load_path(#env{roots = Roots, source_root = Root}) ->
    lists:uniq(Roots ++ [filename:absname(Root)]).

source_of(#env{source_root = Root}, Ns) ->
    File = filename:join(Root, ern_build:module_path(Ns) ++ ".ern"),
    case filelib:is_regular(File) of
        true -> {ok, File};
        false -> none
    end.

compiled_of(Env, Ns) ->
    Rel = ern_build:module_path(Ns) ++ ".erc",
    case [F || R <- load_path(Env), F <- [filename:join(R, Rel)], filelib:is_regular(F)] of
        [File | _] ->
            {ok, Bin} = file:read_file(File),
            case ern_iface:read(Bin) of
                {ok, #{source_hash := Hash}} -> {ok, File, Bin, Hash};
                {error, _} -> none
            end;
        [] ->
            none
    end.

source_hash(File) ->
    case file:read_file(File) of
        {ok, Source} -> {ok, crypto:hash(sha256, Source)};
        {error, _} -> none
    end.

relative(File, #env{source_root = Root}) ->
    case string:prefix(filename:absname(File), filename:absname(Root) ++ "/") of
        nomatch -> File;
        Rel -> Rel
    end.

%% The toolchain's version, the top-level VERSION file, passed by the
%% Makefile.
-spec version() -> binary().
version() ->
    list_to_binary(?VERSION).

%% The screen writes to the terminal itself: standard output is the screen's,
%% so a screen that printed through it would print to itself.
-spec write(binary()) -> 'Unit'.
write(Text) ->
    file:write(standard_io, unicode:characters_to_binary(Text)),
    'Unit'.

%% Report §11.2: the runner binds the sinks to the screen, which the shell
%% names once it has one; what is written before then goes straight out.
-spec screen(term()) -> 'Unit'.
screen(Address) ->
    persistent_term:put({?MODULE, screen}, Address),
    'Unit'.

-spec to_screen(binary()) -> ok.
to_screen(Bin) ->
    case persistent_term:get({?MODULE, output}, undefined) of
        undefined ->
            case persistent_term:get({?MODULE, screen}, undefined) of
                undefined -> file:write(standard_io, Bin);
                Address -> ern_rt:send(Address, shown(Bin))
            end;
        {_, Device} ->
            %% report §11.2: a program's output goes where `:output` sent
            %% it, which is another terminal and its own scrolling
            file:write(Device, Bin),
            ok
    end.

%% Report §11.2: the text the screen shows of what a program wrote, with
%% U+FFFD for each byte that is not UTF-8. A character cut across two
%% writes waits for its end, which each sink keeps, one to a process.
shown(Bin) ->
    Whole = <<(erase_cut())/binary, Bin/binary>>,
    case unicode:characters_to_binary(Whole, utf8, utf8) of
        Text when is_binary(Text) ->
            Text;
        {incomplete, Text, Cut} ->
            put({?MODULE, cut}, Cut),
            Text;
        {error, Text, <<_, Rest/binary>>} ->
            <<Text/binary, 16#FFFD/utf8, (shown(Rest))/binary>>
    end.

erase_cut() ->
    case erase({?MODULE, cut}) of
        undefined -> <<>>;
        Cut -> Cut
    end.

%% Report §11.2: where a program's output goes. A path is another terminal
%% or a file, `-` is the tail again, and nothing is where it goes now. The
%% front end opens it, so the shell gains no file system of its own.
-spec output(binary()) -> {'Left', binary()} | {'Right', binary()}.
output(<<>>) ->
    {'Right', <<"output goes to ", (where_output())/binary>>};
output(<<"-">>) ->
    close_output(),
    {'Right', <<"output goes to the live region">>};
output(Path) ->
    Name = unicode:characters_to_list(Path),
    %% not `raw`: a raw device belongs to the process that opened it, and
    %% what writes to it is the sink's process, not this one
    case file:open(Name, [append]) of
        {ok, Device} ->
            close_output(),
            persistent_term:put({?MODULE, output}, {Path, Device}),
            {'Right', <<"output goes to ", Path/binary>>};
        {error, Reason} ->
            {'Left', <<"cannot write to ", Path/binary, ": ",
                       (unicode:characters_to_binary(file:format_error(Reason)))/binary>>}
    end.

where_output() ->
    case persistent_term:get({?MODULE, output}, undefined) of
        undefined -> <<"the live region">>;
        {Path, _} -> Path
    end.

close_output() ->
    case persistent_term:get({?MODULE, output}, undefined) of
        undefined -> ok;
        {_, Device} ->
            file:close(Device),
            persistent_term:erase({?MODULE, output})
    end.

%% Report §11.2: the name an input binds is the session's from then on. Its
%% value is held by a module of its own, as a module's own value is
%% (§8.5's store), so a later input reads it with the call the emitter
%% already makes for another module's value.
bind(Env, decls, Ns, _Value, _Type, _TEnv, Iface) ->
    %% the functions its own values hold join what the input needs
    Mod = ern_emitter:module_atom(Ns),
    Held = lists:foldl(fun({_, V}, Acc) -> fun_modules(V, Acc) end, [], stored(Mod)),
    {Ns, Needs, Keys} = maps:get(Mod, uses()),
    set_uses(maps:put(Mod, {Ns, lists:usort(Needs ++ [M || M <- Held, session_module(M),
                                                           M =/= Mod]), Keys},
                      uses())),
    session(Env, Iface);
bind(Env, it, _Ns, Value, Type, TEnv, _Iface) ->
    case open(Type, TEnv) of
        true -> Env;
        false -> bound(Env, [{it, Value, Type}], TEnv)
    end;
bind(Env, {names, Names}, _Ns, Value, Type, TEnv, _Iface) ->
    bound(Env, components(Names, Value, Type, TEnv), TEnv);
bind(Env, {lambda, Name, Scheme}, _Ns, Value, _Type, TEnv, _Iface) ->
    bound(Env, [{Name, Value, Scheme}], TEnv);
bind(Env, Name, _Ns, Value, Type, TEnv, _Iface) ->
    bound(Env, [{Name, Value, Type}], TEnv).

%% Each name a pattern bound, with its value and type: the whole of the
%% input's value for one name, a component of its tuple for more.
components([], _Value, _Type, _TEnv) ->
    [];
components([Name], Value, Type, _TEnv) ->
    [{Name, Value, Type}];
components(Names, Value, Type, TEnv) ->
    {ttuple, Types} = ern_types:zonk(Type, ern_typecheck:type_state(TEnv)),
    lists:zip3(Names, tuple_to_list(Value), Types).

%% Report §11.2: whether the input's value was left unbound, its type
%% not being determined by the input itself.
-spec unbound(#checked{}) -> boolean().
unbound(#checked{binds = it, type = Type, env = TEnv}) -> open(Type, TEnv);
unbound(#checked{}) -> false.

%% Report §11.2: a value whose type its own input did not settle is
%% printed but not bound, since a scheme with a variable of that input's
%% type state means nothing to the inputs after it. A named binding is
%% refused outright when it is checked; `it` is the one this can still
%% reach, and `declared/1` says that it was not bound.
open(Type, TEnv) ->
    St = ern_typecheck:type_state(TEnv),
    ern_types:free_vars(ern_types:zonk(Type, St), St) =/= [].

%% The names an input binds, held by one module, a getter for each, which
%% needs the session's modules whose functions the values hold and whose
%% types their types name.
bound(Env, [], _TEnv) ->
    Env;
bound(#env{holders = N, free_holders = Free} = Env0, Bound, TEnv) ->
    {K, Env} = case Free of
                   [F | Rest] -> {F, Env0#env{free_holders = Rest}};
                   [] -> {N + 1, Env0#env{holders = N + 1}}
               end,
    Holder = [list_to_atom("$Bindings" ++ integer_to_list(K))],
    Mod = ern_emitter:module_atom(Holder),
    St = ern_typecheck:type_state(TEnv),
    [persistent_term:put({Mod, Name}, Value) || {Name, Value, _} <- Bound],
    Names = [Name || {Name, _, _} <- Bound],
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), holder(Mod, Names)),
    Values = maps:from_list([{Holder ++ [Name], binding_scheme(Type, St)}
                             || {Name, _, Type} <- Bound]),
    Iface = #iface{namespace = Holder, values = Values, lets = [Holder ++ [Name] || Name <- Names]},
    Held = lists:foldl(fun({_, Value, _}, Acc) -> fun_modules(Value, Acc) end, [], Bound),
    set_uses(maps:put(Mod, {Holder, lists:usort([M || M <- Held, session_module(M)]
                                                ++ mentions(Iface, Holder)),
                            [{Mod, Name} || Name <- Names]},
                      uses())),
    session(Env, Iface).

%% A bound name's scheme: a generalized `let`'s own, or its type alone.
binding_scheme(#scheme{} = Scheme, _St) -> Scheme;
binding_scheme(Type, St) -> ern_types:mono(ern_types:zonk(Type, St)).

%% Report §11.2: the session after an input has answered, what nothing
%% reaches any more let go, in the session's own process.
-spec collect(#env{}) -> #env{}.
collect(Env) ->
    remember(collected(Env)).

%% Report §11.2: the session's modules are the holders of what inputs
%% bound, the inputs that declared, and the inputs whose value holds one of
%% their functions. One is kept while the session can reach it, and let go
%% when it cannot: its values, its code, its interface, and its number,
%% which a later holder or input takes (report §2.3). What reaches one is a
%% name in the session's scope, a module whose old code a process is still
%% inside, and, from either, what that module needs (uses/0). A module whose
%% old code a process is inside is purged at a later collection, holders
%% here and inputs here and at each input's end (forget/3), and its values
%% are let go once it is purged, since that process may still read them.
%% The session collects in its own process, once an input has answered
%% (collect/1), so that an input killed while it runs has let nothing go
%% that the session still names.
collected(#env{ifaces = Ifaces, session = S, beams = Beams, free_holders = Free,
               draining = Draining} = Env) ->
    Uses = uses(),
    Unpurged = persistent_term:get({?MODULE, unpurged}, []),
    Old = [ern_emitter:module_atom(Ns) || Ns <- Unpurged]
        ++ [ern_emitter:module_atom([H]) || H <- Draining],
    Named = [ern_emitter:module_atom([hd(Q)]) || Which <- [values, types, cons],
                                                 Q <- maps:values(maps:get(Which, S, #{})),
                                                 session_segment(hd(Q))],
    Live = reached(Named ++ Old, Uses, #{}),
    Dead = [Ns || M := {Ns, _, _} <- Uses, not is_map_key(M, Live)],
    lists:foreach(fun(Ns) -> code:delete(ern_emitter:module_atom(Ns)) end, Dead),
    {DeadHolders, DeadInputs} = lists:partition(fun([Seg]) -> holder_number(Seg) =/= none end,
                                                Dead),
    Purgeable = fun(Ns) -> code:soft_purge(ern_emitter:module_atom(Ns)) end,
    {Purged, Held} = lists:partition(fun(H) -> Purgeable([H]) end,
                                     Draining ++ [H || [H] <- DeadHolders]),
    {InputsPurged, InputsHeld} = lists:partition(Purgeable, Unpurged ++ DeadInputs),
    [persistent_term:erase(Key) || Ns <- [[H] || H <- Purged] ++ InputsPurged,
                                   {Key, _} <- stored(ern_emitter:module_atom(Ns))],
    InputsHeld =/= Unpurged andalso persistent_term:put({?MODULE, unpurged}, InputsHeld),
    InputsPurged =/= [] andalso
        set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) ++ InputsPurged),
    set_uses(maps:without([ern_emitter:module_atom(Ns)
                           || Ns <- [[H] || H <- Purged] ++ InputsPurged], Uses)),
    Env#env{ifaces = [I || #iface{namespace = Ns} = I <- Ifaces, not lists:member(Ns, Dead)],
            beams = maps:without(Dead, Beams),
            free_holders = Free ++ [holder_number(H) || H <- Purged],
            draining = Held}.

%% The values a session module's top-level bindings hold, each under its
%% key, as the emitter keeps them (report §8.5): read by the module's own
%% keys, and not by every term the node holds, which reading would copy.
stored(Mod) ->
    {_, _, Keys} = maps:get(Mod, uses()),
    Missing = make_ref(),
    [{Key, V} || Key <- Keys, V <- [persistent_term:get(Key, Missing)], V =/= Missing].

%% The session's modules the given ones reach, through what each needs.
reached([], _Uses, Live) ->
    Live;
reached([M | Rest], Uses, Live) when is_map_key(M, Live) ->
    reached(Rest, Uses, Live);
reached([M | Rest], Uses, Live) ->
    Needs = case Uses of
                #{M := {_, N, _}} -> N;
                _ -> []
            end,
    reached(Needs ++ Rest, Uses, Live#{M => true}).

%% The session's modules whose names a term mentions, but its own: a type an
%% interface names is such a mention.
mentions(Term, [Own]) ->
    lists:usort([ern_emitter:module_atom([A]) || A <- atoms(Term, []), A =/= Own,
                                                 session_segment(A)]).

atoms(A, Acc) when is_atom(A) -> [A | Acc];
atoms(T, Acc) when is_tuple(T) -> atoms(tuple_to_list(T), Acc);
atoms([H | Rest], Acc) -> atoms(Rest, atoms(H, Acc));
atoms(M, Acc) when is_map(M) -> atoms(maps:to_list(M), Acc);
atoms(_, Acc) -> Acc.

%% The number of a holder's namespace segment, `$Bindings<n>`, or none.
holder_number(Segment) ->
    case atom_to_list(Segment) of
        "$Bindings" ++ Digits -> list_to_integer(Digits);
        _ -> none
    end.

%% Whether a namespace segment, or a module, is one the session made
%% (report §2.3).
session_segment(Segment) ->
    case atom_to_list(Segment) of
        "$Bindings" ++ _ -> true;
        "$Input" ++ _ -> true;
        _ -> false
    end.

session_module(M) ->
    Name = atom_to_list(M),
    lists:prefix("ern@$bindings", Name) orelse lists:prefix("ern@$input", Name).

%% What each session module needs of the others, by the module: the
%% namespace it is, the session's modules its code calls, whose types its
%% interface names, and whose functions its values hold, and the keys its
%% top-level bindings are stored under.
uses() ->
    persistent_term:get({?MODULE, uses}, #{}).

set_uses(Uses) ->
    uses() =/= Uses andalso persistent_term:put({?MODULE, uses}, Uses),
    set_names(maps:with(maps:keys(Uses), names_of_inputs())).

%% Report §6.9, §11.2: the site of a spawn an input's expression makes, the
%% input's name as its diagnostics give it, `input 3`, and the line. The
%% name is kept beside the module's uses and goes with them, since the
%% module's number is given to a later input once it is purged.
-spec input_site(atom(), pos_integer()) -> binary().
input_site(Mod, Line) ->
    <<(maps:get(Mod, names_of_inputs()))/binary, ":", (integer_to_binary(Line))/binary>>.

names_of_inputs() ->
    persistent_term:get({?MODULE, input_names}, #{}).

set_names(Names) ->
    names_of_inputs() =/= Names andalso persistent_term:put({?MODULE, input_names}, Names).

%% Report §11.2: the session is a scope of its own. The interface behind an
%% input joins the ones the checker is given, and what it declares joins the
%% scope under the unqualified name, which a later declaration of that name
%% overwrites.
session(#env{ifaces = Ifaces, session = S} = Env, #iface{} = Iface) ->
    #iface{namespace = Ns, types = Ts, values = Vs} = Iface,
    %% a type declared again starts with no members: the earlier type's
    %% belong to it, and its name now names another
    Declared = [lists:last(Q) || Q <- maps:keys(Ts)],
    Kept = maps:filter(fun({Owner, _}, _) -> not lists:member(Owner, Declared);
                          (_, _) -> true
                       end, maps:get(values, S, #{})),
    Values = maps:merge(Kept, maps:from_list([{value_key(Ns, Q), Q} || Q <- maps:keys(Vs)])),
    Types = maps:merge(maps:get(types, S, #{}),
                       maps:from_list([{lists:last(Q), Q} || Q <- maps:keys(Ts)])),
    Cons = maps:merge(maps:get(cons, S, #{}),
                      maps:from_list([{lists:last(CQ), CQ}
                                      || #tinfo{constructors = Cs} <- maps:values(Ts),
                                         #cinfo{qname = CQ} <- Cs])),
    Env#env{ifaces = Ifaces ++ [Iface],
            session = S#{values => Values, types => Types, cons => Cons}}.

%% A name as an input after this one writes it: a type member under the
%% type that owns it (report §4.2), anything else under its own name.
value_key(Ns, Q) ->
    case lists:nthtail(length(Ns), Q) of
        [Name] -> Name;
        [Owner, Name] -> {Owner, Name}
    end.

%% The getter the emitter emits for a module's own value (§8.5). A binding
%% is a `let`, so a later input reaches it as it reaches any other module's
%% value, and calls it by applying what the getter answers (§4.6).
%%
%% Report §8.6: the host's compiler waits for a process of its own, and the
%% input's process is an Ernest process waiting with it. It is marked as a
%% foreign call in progress, which is what it is, so that `Deadlock` is not
%% declared over a binding being made.
holder(Mod, Names) ->
    ern_rt:in_foreign(fun() -> holder_beam(Mod, Names) end).

holder_beam(Mod, Names) ->
    Get = fun(Name) ->
              erl_syntax:application(
                erl_syntax:module_qualifier(erl_syntax:atom(persistent_term),
                                            erl_syntax:atom(get)),
                [erl_syntax:tuple([erl_syntax:atom(Mod), erl_syntax:atom(Name)])])
          end,
    Forms = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Mod)]),
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list(
                                     [erl_syntax:arity_qualifier(
                                        erl_syntax:atom(ern_emitter:function_atom(Name)),
                                        erl_syntax:integer(0))
                                      || Name <- Names])])
             | [erl_syntax:function(erl_syntax:atom(ern_emitter:function_atom(Name)),
                                    [erl_syntax:clause([], none, [Get(Name)])])
                || Name <- Names]],
    {ok, _, Bin} = compile:forms([erl_syntax:revert(F) || F <- Forms], [return_errors]),
    Bin.

%% Report §11.2: what an input declares, a line for each, in the order they
%% were written. A value is its name and its type, a type its keyword and
%% its name.
%% Report §11.2: whether the input is an expression, which binds `it`, and
%% not a `let` or declarations, which `:type` refuses.
-spec is_expression(#checked{}) -> boolean().
is_expression(#checked{binds = Binds}) ->
    Binds =:= it.

-spec declared(#checked{}) -> [binary()].
declared(#checked{binds = it}) ->
    [];
declared(#checked{binds = decls, ns = Ns, decls = Decls, iface = Iface, env = TEnv}) ->
    [line(D, Ns, Iface, TEnv) || D <- Decls, kind(D) =/= other];
declared(#checked{binds = {names, []}}) ->
    [];
declared(#checked{binds = {names, Names}, type = Type, env = TEnv}) ->
    St = ern_typecheck:type_state(TEnv),
    Types = case Names of
                [_] -> [Type];
                _ -> element(2, ern_types:zonk(Type, St))
            end,
    [unicode:characters_to_binary([atom_to_list(N), " : ", ern_types:format(T, St)])
     || {N, T} <- lists:zip(Names, Types)];
declared(#checked{binds = {lambda, Name, Scheme}, env = TEnv}) ->
    St = ern_typecheck:type_state(TEnv),
    [unicode:characters_to_binary([atom_to_list(Name), " : ",
                                   ern_types:format_scheme(Scheme, St)])];
declared(#checked{binds = Name} = C) ->
    [<<(atom_to_binary(Name))/binary, " : ", (type_text(C))/binary>>].

kind(#type_decl{}) -> <<"type">>;
kind(#abstract_decl{}) -> <<"abstract type">>;
kind(#foreign_type_decl{}) -> <<"foreign type">>;
kind(#fn_decl{}) -> value;
kind(#foreign_fn_decl{}) -> value;
kind(#let_decl{}) -> value;
kind(_) -> other.

line(D, Ns, #iface{values = Vs}, TEnv) ->
    case kind(D) of
        value ->
            {Owner, Name} = declared_name(D),
            Scheme = maps:get(Ns ++ Owner ++ [Name], Vs),
            Text = ern_types:format_scheme(Scheme, ern_typecheck:type_state(TEnv)),
            unicode:characters_to_binary([owned(Owner, Name), " : ", Text]);
        Keyword ->
            {_, Name} = declared_name(D),
            <<Keyword/binary, " ", (atom_to_binary(Name))/binary>>
    end.

declared_name(#fn_decl{owner = undefined, name = N}) -> {[], N};
declared_name(#fn_decl{owner = Owner, name = N}) -> {[Owner], N};
declared_name(#foreign_fn_decl{owner = undefined, name = N}) -> {[], N};
declared_name(#foreign_fn_decl{owner = Owner, name = N}) -> {[Owner], N};
declared_name(#let_decl{name = N}) -> {[], N};
declared_name(#type_decl{name = N}) -> {[], N};
declared_name(#abstract_decl{type = #type_decl{name = N}}) -> {[], N};
declared_name(#foreign_type_decl{name = N}) -> {[], N}.

owned([], Name) -> atom_to_list(Name);
owned([Owner], Name) -> [atom_to_list(Owner), ".", atom_to_list(Name)].
