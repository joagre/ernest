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
-include_lib("utils/include/ern_diagnostic.hrl").
-include_lib("cli/include/ern_build.hrl").

-define(UNIT, {tcon, ['Unit'], []}).

%% The function an expression input is wrapped in. No Ernest identifier is
%% spelled so, so the wrapper never shadows a name the session declares,
%% `main` among them (report §11.2's scope), and the emitter knows a site
%% inside it for the input's own.
-define(ENTRY, '$input').

%% The session so far: the load path, the source root, the interfaces of
%% the modules behind the session, and the scope those modules make
%% (report §11.2), which the checker takes as its fourth argument.
-record(session, {load_path = [], source_root = ".", last_input = 0, interfaces = [],
                  scope = #{}, beams = #{}, modules = #{}, last_holder = 0, free_holders = [],
                  draining = []}).
%% last_input: the highest input number given; last_holder: the highest
%% `$Bindings` number given; free_holders: the numbers of holders freed
%% (collected/1), given again first, as an input's number is once its
%% module is unloaded (release/3); draining: holders deleted whose old code
%% a process still ran, purged at the next collection
%% modules: the namespace of a module the session has loaded, to the hash
%% of the source it was compiled from, which `:reload` compares (§11.2)
%% beams: the namespace of an input that declared, to its compiled module,
%% which `:doc` reads the documentation of (report §11.2, §11.4)
%% A checked input: the module it became, its typed tree, the checker's
%% environment, its type.
-record(checked, {namespace, typed, declarations, interface, env, type, binds, site}).
%% binds: the name a `let` binds, `{lambda, Name, Scheme}` for a `let` of a
%% lambda, generalized, `{names, Names}` for the names a `let` with a
%% pattern binds, `it` for an expression, or `declarations`
%% A value with the descriptor of its type, so it prints as E.1 prints it.
-record(value, {term, descriptor}).
%% Where an input from a startup file came from: the file, the line it
%% stands on, and the column it begins in (report §11.2); a typed input's
%% origin is `{typed, Name}`.
-record(startup_input, {file, first, column}).

%% Report §11.2: what the runner loaded before the shell started, which the
%% shell begins from: the load path, where a module's source is found, the
%% interfaces of the loaded modules, and the entry point to spawn beside the
%% prompt.
-spec loaded(map()) -> ok.
loaded(What) ->
    persistent_term:put({?MODULE, loaded}, What).

-spec start() -> #session{}.
start() ->
    What = persistent_term:get({?MODULE, loaded}, #{}),
    Loaded = maps:get(interfaces, What, []),
    remember(#session{load_path = maps:get(load_path, What, []),
                      source_root = maps:get(source_root, What, "."),
                      interfaces = [Interface || {Interface, _} <- Loaded],
                      modules = maps:from_list([{Interface#interface.namespace, Hash}
                                                || {Interface, Hash} <- Loaded])}).

%% Report §11.2: the session as it stands, which completion reads. The
%% reader asks for the names while an input runs, when the session is busy
%% answering nothing, so it cannot be a message to the session; the front
%% end keeps the latest, as it keeps what the runner loaded. An input's
%% declarations join the session when it has run, not when it is checked,
%% so this is set in both places.
remember(Session) ->
    persistent_term:put({?MODULE, session}, Session),
    Session.

%% Report §11.2, §8.1: the file's entry point, spawned beside the prompt and
%% not entered, and nothing where the shell was started with no file. A
%% fault in it reaches the session through Process.faults, to which the
%% session subscribed before (E.21).
-spec program() -> {'Some', pid()} | 'None'.
program() ->
    case persistent_term:get({?MODULE, loaded}, #{}) of
        #{entry := {ErlangModule, Function, Site}} ->
            ErlangFunction = ern_emitter:function_atom(Function),
            {'Some', ern_rt:spawn(fun() -> ErlangModule:ErlangFunction() end, Site)};
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

unfinished({error, #diagnostic{incomplete = Incomplete}}) -> Incomplete;
unfinished(_) -> false.

%% Report §11.2: an input is checked before it is run; a failure is §11.5's
%% text, as `ern build` shows it, under the name of where the input came from:
%% `input 3` for the third thing entered at the prompt, the file's path for
%% an input from a startup file. The shell's `Origin` says which:
%% `Prompt(n)`, or `Startup(file, line, column)`, its fields in declared
%% order, the column where the input begins on the line.
-spec check(#session{}, {'Prompt', pos_integer()}
                        | {'Startup', binary(), pos_integer(), pos_integer()}, binary()) ->
          {'Left', binary()} | {'Right', {#session{}, #checked{}}}.
check(#session{last_input = LastInput} = Session, From, Input) ->
    Origin = case From of
                 {'Prompt', Count} -> {typed, <<"input ", (integer_to_binary(Count))/binary>>};
                 {'Startup', File, First, Column} ->
                     #startup_input{file = File, first = First, column = Column}
             end,
    %% an input takes the number of one whose module was unloaded, whose
    %% name is an atom already, before a new one (report §2.3)
    {Namespace, LastInput1} = case persistent_term:get({?MODULE, free_inputs}, []) of
                                  [Free | _] -> {Free, LastInput};
                                  [] -> {input_namespace(LastInput + 1), LastInput + 1}
                              end,
    Numbered = Session#session{last_input = LastInput1},
    case input(Input) of
        {ok, Binds, Expr} ->
            checked(check_module(Numbered, Namespace, Origin, Input, input_entry(Expr), Binds));
        {declarations, Declarations} ->
            checked(check_module(Numbered, Namespace, Origin, Input, Declarations, declarations));
        {error, Diagnostic} ->
            {'Left', diagnostic(Origin, Input, [Diagnostic])}
    end.

%% Report §2.3: the modules the session makes are named as no Ernest name
%% is spelled, since an identifier holds no `$`: the module an input
%% becomes, `$Input<n>`; the one that holds what a `let` at the prompt
%% binds, `$Bindings<n>`; and the one a callee is checked in for
%% `Shift-Tab`. No input reaches them by name, and a module spelled as one
%% would be otherwise, `Input1`, is a module like any other.
input_namespace(Number) ->
    [list_to_atom("$Input" ++ integer_to_list(Number))].

checked({'Right', {Session, Checked}}) ->
    {'Right', {remember(Session), Checked}};
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
        {error, Diagnostic} ->
            case ern_parser:parse_string(Text) of
                {ok, [#let_declaration{name = Name, body = Body, annotation = Annotation}]} ->
                    {ok, let_binds(Name, Body), annotated(Name, Body, Annotation)};
                {ok, Declarations} -> declarations(Declarations);
                {error, DeclarationDiagnostic} ->
                    case pattern_let(Text) of
                        none -> {error, which(Text, Diagnostic, DeclarationDiagnostic)};
                        Input -> Input
                    end
            end
    end.

%% Report §11.2: a `let` whose pattern is not a name binds each name the
%% pattern binds. It is the block `{ let p = e; #(names) }`, whose value
%% holds the names in the order the pattern has them; `let _ = e` binds
%% none, and `<-` is refused, since no block follows it for it to end.
pattern_let(Text) ->
    case ern_parser:parse_statement(Text) of
        {ok, #binding{operator = '<-', span = Span}} ->
            {error, #diagnostic{span = ern_diagnostic:span(Span),
                                message = "a `let` with `<-` at the prompt has no block to end",
                                help = "write it in a block, `{ let x <- e; ... }`"}};
        {ok, #binding{span = Span, pattern = Pattern} = Binding} ->
            Names = [Name || {Name, _} <- ern_ast:pattern_bindings(Pattern)],
            Variables = [#e_var{span = Span, name = Name} || Name <- Names],
            Last = case Variables of
                       [] -> #e_constructor{span = Span, name = 'Unit'};
                       [Variable] -> Variable;
                       _ -> #e_tuple{span = Span, elements = Variables}
                   end,
            {ok, {names, Names}, #e_block{span = Span, statements = [Binding, Last]}};
        _ ->
            none
    end.

%% Report §11.5: an input that begins where only a declaration may begin is
%% a declaration a person got wrong, and the declaration parser's error is
%% the one that names what is wrong; anything else is an expression, whose
%% error names it. `fn` begins a lambda as well, and begins a declaration
%% only when a name follows it.
which(Text, Diagnostic, DeclarationDiagnostic) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} ->
            case declaration_start(Tokens) of
                true -> DeclarationDiagnostic;
                false -> Diagnostic
            end;
        _ ->
            Diagnostic
    end.

declaration_start([{'fn', _}, {ident, _, _} | _]) -> true;
declaration_start([{Word, _} | _]) -> lists:member(Word, [type, abstract, foreign, export, 'let']);
declaration_start(_) -> false.

%% Report §11.2: what an input declares is the session's from then on, so
%% every declaration of an input is exported; a later input reaches it as it
%% reaches another module's declaration (§4.3).
declarations(Declarations) ->
    case [Span || #let_declaration{span = Span} <- Declarations] of
        [] -> {declarations, [exported(Declaration) || Declaration <- Declarations]};
        [_, Second | _] -> {error, one_let(Second)};
        [Span] -> {error, one_let(Span)}
    end.

%% Report §11.2: a `let` at the prompt is a block `let`, and a block has one
%% of them per input; a `let` beside a declaration would be a top-level
%% `let`, which §4.6 generalizes and requires to be pure. A `let` that
%% declares a type member, `let T.name`, is a declaration and not this.
one_let(Span) ->
    #diagnostic{span = ern_diagnostic:span(Span),
                message = "a `let` at the prompt is an input of its own",
                help = "run this `let` on an input of its own, or make it a `let`"
                       " inside a declaration's body"}.

exported(#type_declaration{} = Declaration) ->
    Declaration#type_declaration{export = true};
exported(#abstract_declaration{} = Declaration) ->
    Declaration#abstract_declaration{export = true};
exported(#foreign_type_declaration{} = Declaration) ->
    Declaration#foreign_type_declaration{export = true};
exported(#fn_declaration{} = Declaration) ->
    Declaration#fn_declaration{export = true};
exported(#let_declaration{} = Declaration) ->
    Declaration#let_declaration{export = true};
exported(#foreign_fn_declaration{} = Declaration) ->
    Declaration#foreign_fn_declaration{export = true};
exported(Declaration) ->
    Declaration.

%% Report §11.2: a `let` at the prompt may carry an annotation, which the
%% checker holds its value to as it holds a `let` in a block's: the input
%% is `{ let x : T = e; x }`.
%% Report §4.6, §11.2: a `let` that binds a name to a lambda is generalized,
%% as in a block; its scheme is known once the input is checked.
let_binds(Name, #e_lambda{}) -> {lambda, Name};
let_binds(Name, _) -> Name.

annotated(_Name, Body, undefined) ->
    Body;
annotated(Name, Body, Annotation) ->
    Span = ern_ast:span(Body),
    #e_block{span = Span,
             statements = [#binding{span = Span, pattern = #p_var{span = Span, name = Name},
                                    annotation = Annotation, operator = '=', expr = Body},
                           #e_var{span = Span, name = Name}]}.

%% `export fn '$input'() = <the input>`, the entry point of §8.1.
input_entry(Expr) ->
    [#fn_declaration{span = {1, 1, {1, 1}}, export = true, name = ?ENTRY, params = [],
                     body = Expr}].

check_module(#session{interfaces = Interfaces, scope = Scope} = Session, Namespace, From, Input,
             Declarations, Binds) ->
    case ern_typecheck:check(Namespace, Declarations, Interfaces, Scope) of
        {ok, Typed, Interface, Env} ->
            Type = input_type(Typed, Binds),
            Binds1 = generalized(Binds, Typed, Env),
            case refused(Type, Env, Binds1, Typed) of
                none ->
                    Checked = #checked{namespace = Namespace, typed = Typed,
                                       declarations = Declarations, interface = Interface,
                                       env = Env, type = Type, binds = Binds1, site = site(From)},
                    {'Right', {Session, Checked}};
                {open, Diagnostic} ->
                    {'Left', diagnostic(From, Input, [Diagnostic])}
            end;
        {error, Diagnostics} ->
            {'Left', diagnostic(From, Input, Diagnostics)}
    end.

%% Report §4.6: the scheme a `let` of a lambda binds its name to, the
%% input's entry point's own over its result, the variables it quantifies
%% kept with their restrictions.
generalized({lambda, Name}, Typed, Env) ->
    [#scheme{quantified = Quantified} = Scheme] =
        [EntryScheme || #fn_declaration{name = ?ENTRY, scheme = EntryScheme} <- Typed],
    Result = result_type(Scheme),
    TypeState = ern_typecheck:type_state(Env),
    Free = ern_types:free_variables(ern_types:substitute(Result, TypeState), TypeState),
    Kept = [Variable || {Id, _} = Variable <- Quantified, lists:member(Id, Free)],
    {lambda, Name, Scheme#scheme{quantified = Kept, type = Result}};
generalized(Binds, _Typed, _Env) ->
    Binds.

%% Report §11.2: the name and the line offset a spawn site in the input is
%% written with, as its diagnostics name and count it.
site({typed, Name}) -> {Name, 0};
site(#startup_input{file = File, first = First}) -> {File, First - 1}.

%% Report §11.2: an input is compiled and run on its own, so what it
%% binds must have a type by the time it runs; a later input cannot
%% settle it, as a later statement of a block would. A binding whose
%% type is still open is refused with the annotation that would settle
%% it, rather than entering the session as a scheme whose variables mean
%% nothing to the inputs after it.
refused(Type, Env, Binds, Typed) ->
    case carries_reply(Type, Env, Binds, Typed) of
        none -> undetermined(Type, Env, Binds, Typed);
        Refused -> Refused
    end.

%% Report §6.6, §11.2: an input's value is printed and dropped, and what a
%% `let` at the prompt binds is the session's, for any later input to use,
%% so neither may carry a reply, which is consumed exactly once.
carries_reply(_Type, _Env, declarations, _Typed) ->
    none;
carries_reply(Type, Env, _Binds, Typed) ->
    case ern_typecheck:is_reply_carrying(Type, Env) of
        false ->
            none;
        true ->
            TypeState = ern_typecheck:type_state(Env),
            {open, #diagnostic{span = input_span(Typed),
                               message = "an input's value cannot carry a reply, which is consumed"
                                         " exactly once; this one is "
                                         ++ ern_types:format(Type, TypeState),
                               help = "answer the reply within the input"}}
    end.

undetermined(_Type, _Env, declarations, _Typed) ->
    none;
undetermined(_Type, _Env, it, _Typed) ->
    %% a bare expression runs and prints whatever its type; what it
    %% cannot do is bind `it`, which `declared/1` says
    none;
undetermined(_Type, _Env, {names, []}, _Typed) ->
    none;
undetermined(_Type, _Env, {lambda, _, _}, _Typed) ->
    %% its variables are its scheme's, quantified (report §4.6)
    none;
undetermined(Type, Env, Binds, Typed) ->
    TypeState = ern_typecheck:type_state(Env),
    case ern_types:free_variables(ern_types:substitute(Type, TypeState), TypeState) of
        [] ->
            none;
        _ ->
            Text = ern_types:format(Type, TypeState),
            {open, #diagnostic{span = input_span(Typed),
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

bound_names({names, Names}) -> lists:join(", ", [atom_to_list(Name) || Name <- Names]);
bound_names(Name) -> atom_to_list(Name).

input_span([#fn_declaration{span = Span} | _]) -> ern_diagnostic:span(Span);
input_span(_) -> {1, 1, {1, 2}}.

%% An input that declares has no value; report §11.2 prints what it
%% declared, as an input of type Unit prints nothing.
input_type(_Typed, declarations) ->
    ?UNIT;
input_type(Typed, _Binds) ->
    [Scheme] = [Scheme || #fn_declaration{name = ?ENTRY, scheme = Scheme} <- Typed],
    result_type(Scheme).

result_type(#scheme{type = {tfn, [], _, Result}}) -> Result;
result_type(#scheme{type = Type}) -> Type.

%% Report §11.2: a value of type `Unit` prints nothing.
-spec is_unit(#checked{}) -> boolean().
is_unit(#checked{type = Type, env = Env}) ->
    ern_typecheck:resolve_type(Type, Env) =:= ?UNIT.

%% Report §11.5: the type as the checker prints it.
-spec type_text(#checked{}) -> binary().
type_text(#checked{typed = Typed, type = Type, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    Text = case one_name(Typed) of
               {Path, Name} ->
                   case ern_typecheck:declared_scheme(Env, Path, Name) of
                       {ok, Scheme} -> ern_types:format_scheme(Scheme, TypeState);
                       error -> ern_types:format(Type, TypeState)
                   end;
               none ->
                   ern_types:format(Type, TypeState)
           end,
    unicode:characters_to_binary(Text).

%% Report §11.2: an input that is one name is printed with the name's
%% declared type, its variables named as the declaration names them.
one_name(Typed) ->
    case [Body || #fn_declaration{name = ?ENTRY, body = Body} <- Typed] of
        [#e_var{path = Path, name = Name}] -> {Path, Name};
        _ -> none
    end.

%% Report §11.2: the input runs in a process of its own; the outcome goes to
%% `Address`, so the shell's reader stays live and the address is what an
%% interruption kills.
-spec run(#session{}, #checked{}, integer(), term()) -> term().
run(Session, #checked{namespace = Namespace, typed = Typed, interface = Interface, env = Env,
                      type = Type, binds = Binds, site = {Where, Offset}} = Checked,
    Count, Address) ->
    Descriptor = ern_descriptor:describe(Type, Env, []),
    Options = #{source_hash => <<>>, deps => [], session => Offset},
    {ok, ErlangModule, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Options),
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) -- [Namespace]),
    record_uses(ErlangModule, Beam, Checked),
    %% report §11.2: an input that declares keeps its module for `:doc`;
    %% an expression's has no documentation, and is not kept
    Session1 = case Binds of
                   declarations ->
                       Session#session{beams = maps:put(Namespace, Beam, Session#session.beams)};
                   _ -> Session
               end,
    Input = fun() ->
                %% report §11.2: the input's own fault is its answer, caught
                %% here, so that its process does not end with a fault
                Outcome = try
                              Value = value(ErlangModule, Binds),
                              Bound = bind(Session1, Binds, Namespace, Value, Type, Env, Interface),
                              {'Ok', remember(Bound), Count,
                               #value{term = Value, descriptor = Descriptor}}
                          catch
                              throw:{ern, fault, Cause} -> {'Faulted', Cause, Count};
                              throw:{ern, fault, Cause, _} -> {'Faulted', Cause, Count};
                              Class:Error -> {'Faulted', fault_text(Class, Error), Count}
                          end,
                release(Namespace, Binds, Outcome),
                ern_rt:send(Address, Outcome)
            end,
    ern_rt:spawn(Input, <<Where/binary, ":", (integer_to_binary(1 + Offset))/binary>>).

%% Report §11.2: what the input's module needs of the session's modules,
%% kept while it is (collected/1): those its code calls and, where it
%% declares, those whose types its declarations name; with the keys its
%% top-level lets are stored under (§8.5), which go when it does, and the
%% name its spawn sites are written with.
record_uses(ErlangModule, Beam, #checked{namespace = Namespace, typed = Typed,
                                         interface = Interface, binds = Binds,
                                         site = {Where, _}}) ->
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    Calls = [Imported || {Imported, _, _} <- Imports, session_module(Imported),
                         Imported =/= ErlangModule],
    Named = case Binds of
                declarations -> mentions(Interface, Namespace);
                _ -> []
            end,
    Keys = [{ErlangModule, ern_emitter:function_name(undefined, Name)}
            || #let_declaration{name = Name} <- Typed],
    set_uses(maps:put(ErlangModule, {Namespace, lists:usort(Calls ++ Named), Keys}, uses())),
    set_names(maps:put(ErlangModule, Where, names_of_inputs())).

%% An input that declares nothing, an expression or a `let`, is done with
%% its module once it has its answer, unless what it bound holds one of the
%% module's functions: it is deleted, and purged unless a process the input
%% spawned still runs it, which keeps it until that process ends; each
%% later input tries the purge again. An input that declares, and one whose
%% value holds its functions, is kept while the session can reach it, and
%% collected/1 lets it go.
release(Namespace, Binds, Outcome) ->
    ErlangModule = ern_emitter:erlang_module(Namespace),
    Pending = persistent_term:get({?MODULE, unpurged}, []),
    Purgeable = fun(Input) -> code:soft_purge(ern_emitter:erlang_module(Input)) end,
    {Purged, Unpurged} = lists:partition(Purgeable, Pending),
    Now = case {Binds, Outcome} of
              {declarations, _} -> kept;
              {_, {'Ok', _, _, #value{term = Value}}} ->
                  case lists:member(ErlangModule, fun_modules(Value, [])) of
                      true -> kept;
                      false -> unload(ErlangModule)
                  end;
              {_, {'Faulted', _, _}} -> unload(ErlangModule)
          end,
    Left = case Now of
               unpurged -> [Namespace | Unpurged];
               _ -> Unpurged
           end,
    Left =/= Pending andalso persistent_term:put({?MODULE, unpurged}, Left),
    %% report §2.3: an unloaded input's number, and so its name's atoms, are
    %% given to the next input
    Freed = Purged ++ [Namespace || Now =:= purged],
    Freed =/= [] andalso
        set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) ++ Freed),
    %% report §11.2: an input purged reads no holder again
    set_uses(maps:without([ern_emitter:erlang_module(Input) || Input <- Freed], uses())),
    ok.

set_free_inputs(Free) ->
    persistent_term:get({?MODULE, free_inputs}, []) =/= Free
        andalso persistent_term:put({?MODULE, free_inputs}, Free).

%% Deleted, and purged unless a process still runs it.
unload(ErlangModule) ->
    code:delete(ErlangModule),
    case code:soft_purge(ErlangModule) of
        true -> purged;
        false -> unpurged
    end.

%% The modules whose functions a value holds, in its data or in a
%% function's captures.
fun_modules(Function, Acc) when is_function(Function) ->
    {module, ErlangModule} = erlang:fun_info(Function, module),
    {env, Captured} = erlang:fun_info(Function, env),
    fun_modules(Captured, [ErlangModule | Acc]);
fun_modules(Tuple, Acc) when is_tuple(Tuple) ->
    fun_modules(tuple_to_list(Tuple), Acc);
fun_modules([Head | Rest], Acc) ->
    fun_modules(Rest, fun_modules(Head, Acc));
fun_modules(Map, Acc) when is_map(Map) ->
    fun_modules(maps:to_list(Map), Acc);
fun_modules(_, Acc) ->
    Acc.

%% An input that declares runs its initializers and nothing else. Report
%% §8.5: a module's top-level values are computed by them, which the runner
%% does when it loads a module; an input's module is loaded here, so they
%% run here, in the input's own process. Its value is Unit, which prints
%% nothing (report §11.2).
value(ErlangModule, declarations) ->
    erlang:function_exported(ErlangModule, '$init', 0) andalso ErlangModule:'$init'(),
    'Unit';
value(ErlangModule, _Binds) ->
    ErlangModule:?ENTRY().

fault_text(error, badarith) -> <<"division by zero">>;
fault_text(Class, Error) ->
    unicode:characters_to_binary(io_lib:format("~p:~p", [Class, Error])).

%% Appendix E.1: the value as Ernest writes it, by the descriptor of its
%% type; report §11.2: to the depth and the length the session is set to,
%% where 0 is neither.
-spec show(#value{}, integer(), integer()) -> binary().
show(#value{term = Value, descriptor = Descriptor}, Depth, Length) ->
    ern_show:show(Descriptor, Value, limit(Depth), limit(Length)).

limit(Count) when Count =< 0 -> unbounded;
limit(Count) -> Count.

%% Report §11.2: what the session declares, a line for each as an input's
%% own declarations print, its types first and then its values by name.
-spec bindings(#session{}) -> [binary()].
bindings(#session{scope = Scope} = Session) ->
    Types = [unicode:characters_to_binary([abstract_text(type_info(QualifiedName, Session)),
                                           "type ", atom_to_list(Name)])
             || {Name, QualifiedName} <- lists:sort(maps:to_list(maps:get(types, Scope, #{})))],
    TypeState = session_type_state(Session),
    Schemes = [{name_text(Key), Scheme}
               || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                  {ok, Scheme} <- [scheme(QualifiedName, Session)]],
    Values = [unicode:characters_to_binary(
                [Text, " : ", ern_types:format_scheme(Scheme, TypeState)])
              || {Text, Scheme} <- lists:sort(Schemes)],
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

wanted({error, #diagnostic{incomplete = Incomplete, expected = What}}) -> {Incomplete, What};
wanted(_) -> {false, undefined}.

where(expression) -> 'Expression';
where(typename) -> 'TypeName';
where(pattern) -> 'Pattern';
where(declaration) -> 'Declaration';
where(#expected_field{kind = field, path = Path, constructor_name = ConstructorName}) ->
    {'Fields', fields_of(Path, ConstructorName)};
%% the parser could not tell a field's name from a value; the
%% constructor's type can, and only a named constructor has fields
where(#expected_field{kind = field_or_value, path = Path, constructor_name = ConstructorName}) ->
    case fields_of(Path, ConstructorName) of
        [] -> 'Expression';
        Fields -> {'Fields', Fields}
    end;
where(#expected_field{kind = field_or_pattern, path = Path,
                      constructor_name = ConstructorName}) ->
    case fields_of(Path, ConstructorName) of
        [] -> 'Pattern';
        Fields -> {'Fields', Fields}
    end.

%% The fields of the constructor as it is written, found as the checker
%% finds it (report §4.2): unqualified, the session's or the prelude's, and
%% qualified, its module's.
%% Report §11.2: each as a `Shell.Complete.Name`, listed with its type, the
%% constructor's parameter in the field's place, both in declared order.
fields_of(Path, ConstructorName) ->
    Session = persistent_term:get({?MODULE, session}, #session{}),
    case named_constructor(Session, Path, ConstructorName) of
        {ok, #constructor_info{fields = {named, Fields},
                               scheme = #scheme{type = {tfn, Params, _, _}}}} ->
            TypeState = session_type_state(Session),
            [name('Value', atom_to_list(Field),
                  atom_to_list(Field) ++ " : " ++ ern_types:format(Param, TypeState))
             || {Field, Param} <- lists:zip(Fields, Params)];
        _ ->
            []
    end.

%% Report §11.2: every name completion may reach — the session's, the
%% prelude's, and each module in scope with its exports — as
%% `Shell.Complete.Name`, whose fields are in declared order (§3.5): the
%% text as it is typed, its kind, the line a listing shows. Only the
%% reading of the interfaces is the host's; the matching is Ernest's.
-spec names() -> [{'Name', binary(), atom(), binary()}].
names() ->
    names(persistent_term:get({?MODULE, session}, #session{})).

names(#session{interfaces = Interfaces, scope = Scope} = Session) ->
    TypeState = session_type_state(Session),
    Declared = [name('Value', name_text(Key),
                     scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{}))]
        ++ [name('Type', atom_to_list(Name), "type " ++ atom_to_list(Name))
            || {Name, _} <- maps:to_list(maps:get(types, Scope, #{}))]
        ++ [name('Constructor', atom_to_list(Name),
                 constructor_line(atom_to_list(Name),
                                  constructor_scheme(QualifiedName, Session), TypeState))
            || {Name, QualifiedName} <- maps:to_list(maps:get(constructors, Scope, #{}))],
    {PreludeTypes, _} = ern_typecheck:prelude_names(),
    Prelude = [name('Value', Text, Text ++ " : " ++ Type)
               || {QualifiedName, Type, _} <- ern_prelude:values(),
                  Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Type', Text, "type " ++ Text)
            || QualifiedName <- PreludeTypes,
               Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Constructor', Text, constructor_line(Text, {ok, Scheme}, TypeState))
            || {QualifiedName, #constructor_info{scheme = Scheme}}
                   <- maps:to_list(ern_typecheck:prelude_constructors()),
               Text <- [ern_namespace:text(QualifiedName)]],
    Modules = lists:append([module_names(Interface, TypeState)
                            || Interface <- Interfaces ++ ern_prelude:stdlib_interfaces()]),
    %% report §11.2: an operator is no name, and does not complete, and
    %% neither does a module the session made, which is spelled as no name
    lists:usort([Name || {'Name', Text, _, _} = Name <- Declared ++ Prelude ++ Modules,
                         words(Text)]).

%% Every segment of a text begins with a letter or `_`, as a name's does.
words(Text) ->
    lists:all(fun(<<Char, _/binary>>) ->
                      Char =:= $_ orelse (Char >= $a andalso Char =< $z)
                          orelse (Char >= $A andalso Char =< $Z);
                 (_) ->
                      false
              end, binary:split(Text, <<".">>, [global])).

%% Report §11.2: a constructor is listed with its type, as a value is.
constructor_line(Text, {ok, Scheme}, TypeState) ->
    Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState);
constructor_line(Text, none, _) -> Text.

constructor_scheme(QualifiedName, #session{interfaces = Interfaces}) ->
    case [Scheme || #interface{types = Types} <- Interfaces,
                    {_, #type_info{constructors = Constructors}} <- maps:to_list(Types),
                    #constructor_info{qualified_name = Found, scheme = Scheme} <- Constructors,
                    Found =:= QualifiedName] of
        [Scheme | _] -> {ok, Scheme};
        [] -> none
    end.

%% Report §11.2: the names `:forget` takes, the values and the types the
%% session declares; a member goes with its type.
-spec session_names() -> [{'Name', binary(), atom(), binary()}].
session_names() ->
    #session{scope = Scope} = Session = persistent_term:get({?MODULE, session}, #session{}),
    TypeState = session_type_state(Session),
    lists:usort([name('Value', name_text(Key),
                      scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                 || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                    is_atom(Key)]
                ++ [name('Type', atom_to_list(Name), "type " ++ atom_to_list(Name))
                    || Name <- maps:keys(maps:get(types, Scope, #{}))]).

%% Report §11.2: every name the session declares, as it is written, its
%% values, members among them, its types, and its constructors: with
%% nothing typed, these and the modules are what completion lists.
-spec session_texts() -> [binary()].
session_texts() ->
    #session{scope = Scope} = persistent_term:get({?MODULE, session}, #session{}),
    lists:usort([unicode:characters_to_binary(name_text(Key))
                 || Which <- [values, types, constructors],
                    Key <- maps:keys(maps:get(Which, Scope, #{}))]).

%% Report §11.2: where `:load` finds a module's source, `--source-root`.
-spec source_root() -> binary().
source_root() ->
    #session{source_root = SourceRoot} = persistent_term:get({?MODULE, session}, #session{}),
    unicode:characters_to_binary(SourceRoot).

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
module_names(#interface{namespace = Namespace, types = Types, values = Values}, TypeState) ->
    ModuleText = ern_namespace:text(Namespace),
    [name('Module', ModuleText, "module " ++ ModuleText)]
        ++ [name('Value', Text, Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState))
            || {QualifiedName, Scheme} <- maps:to_list(Values),
               Text <- [ern_namespace:text(QualifiedName)]]
        ++ lists:append([type_names(QualifiedName, TypeInfo, TypeState)
                         || {QualifiedName, TypeInfo} <- maps:to_list(Types)]).

%% A type in scope and, unless it is abstract, its constructors, each named
%% in the type's namespace.
type_names(QualifiedName, #type_info{constructors = Constructors} = TypeInfo, TypeState) ->
    Text = ern_namespace:text(QualifiedName),
    Namespace = lists:droplast(QualifiedName),
    [name('Type', Text, abstract_text(TypeInfo) ++ "type " ++ Text)
     | [name('Constructor', ConstructorText,
             constructor_line(ConstructorText, {ok, Scheme}, TypeState))
        || not TypeInfo#type_info.abstract,
           #constructor_info{name = ConstructorName, scheme = Scheme} <- Constructors,
           ConstructorText <- [ern_namespace:text(Namespace ++ [ConstructorName])]]].

name(Kind, Text, Shown) ->
    {'Name', unicode:characters_to_binary(Text), Kind, unicode:characters_to_binary(Shown)}.

scheme_line(Text, QualifiedName, Session, TypeState) ->
    case scheme(QualifiedName, Session) of
        {ok, Scheme} -> Text ++ " : " ++ ern_types:format_scheme(Scheme, TypeState);
        none -> Text
    end.

type_info(QualifiedName, #session{interfaces = Interfaces}) ->
    case [TypeInfo || #interface{types = Types} <- Interfaces,
                      #{QualifiedName := TypeInfo} <- [Types]] of
        [] -> none;
        Infos -> lists:last(Infos)
    end.

name_text({MemberOf, Name}) -> atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name);
name_text(Name) -> atom_to_list(Name).

scheme(QualifiedName, #session{interfaces = Interfaces}) ->
    case [Scheme || #interface{values = Values} <- Interfaces,
                    #{QualifiedName := Scheme} <- [Values]] of
        [] -> none;
        Schemes -> {ok, lists:last(Schemes)}
    end.

%% The state a session name's type is printed under: the session's types
%% print unqualified, as they do in an input (report §11.2).
session_type_state(#session{scope = Scope, interfaces = Interfaces}) ->
    TypeState = ern_typecheck:scope_state(Interfaces),
    ern_types:set_scope(TypeState, [], maps:values(maps:get(types, Scope, #{})), []).

%% Report §11.2: `:forget` removes a name the session declared, and `*`
%% every one of them. A type is forgotten with its constructors. A module
%% the session then no longer reaches, by a name or by a value that holds
%% its functions, collected/1 lets go; a value made before keeps the module
%% of its type while it is reached.
-spec forget(#session{}, binary()) -> {'Left', binary()} | {'Right', #session{}}.
forget(Session, <<"*">>) ->
    {'Right', remember(collected(Session#session{scope = #{}}))};
forget(#session{scope = Scope} = Session, Text) ->
    Values = maps:get(values, Scope, #{}),
    Types = maps:get(types, Scope, #{}),
    Constructors = maps:get(constructors, Scope, #{}),
    case segments(Text) of
        {ok, [Name]} when is_map_key(Name, Values); is_map_key(Name, Types) ->
            Members = [{MemberOf, Member} || {MemberOf, Member} <- maps:keys(Values),
                                             MemberOf =:= Name],
            Gone = constructors(maps:get(Name, Types, none), Constructors, Session),
            %% remembered, since completion and `Shift-Tab` read the
            %% session from where the front end keeps it; what nothing
            %% reaches any longer is let go
            Scope1 = Scope#{values => maps:without([Name | Members], Values),
                            types => maps:remove(Name, Types),
                            constructors => maps:without(Gone, Constructors)},
            {'Right', remember(collected(Session#session{scope = Scope1}))};
        _ ->
            {'Left', <<"the session declares no ", Text/binary>>}
    end.

%% The constructors of the type being forgotten that still stand for it; one
%% whose name a later type took belongs to that type now.
constructors(none, _, _) ->
    [];
constructors(QualifiedName, ScopeConstructors, #session{interfaces = Interfaces}) ->
    [Name || #interface{types = Types} <- Interfaces,
             #{QualifiedName := #type_info{constructors = Constructors}} <- [Types],
             #constructor_info{qualified_name = ConstructorQualifiedName} <- Constructors,
             Name <- [lists:last(ConstructorQualifiedName)],
             maps:get(Name, ScopeConstructors, none) =:= ConstructorQualifiedName].

%% Report §11.2, §4.2: the exports of a module in scope, its types and then
%% its values, each with its type as §11.5 prints it.
-spec browse(#session{}, binary()) -> {'Left', binary()} | {'Right', [binary()]}.
browse(Session, Text) ->
    case module_name(Text) of
        {ok, ['Prelude']} -> {'Right', prelude_listing()};
        {ok, Namespace} -> browse(Text, Namespace, Session);
        {error, Refusal} -> {'Left', Refusal}
    end.

%% Report §11.2, §9: the prelude's types and values, as `:browse` lists a
%% module's, since `Prelude` names its namespace (§4.2).
prelude_listing() ->
    TypeState = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    {Types, _} = ern_typecheck:prelude_names(),
    %% the environment holds the standard library's types too, each under
    %% its module's name; the prelude's own are unqualified
    [unicode:characters_to_binary(["type ", ern_namespace:text(QualifiedName)])
     || [_] = QualifiedName <- lists:sort(Types)]
    ++ [unicode:characters_to_binary([ern_namespace:text(QualifiedName), " : ",
                                      ern_types:format_scheme(Scheme, TypeState)])
        || {QualifiedName, Scheme} <- lists:sort(ern_typecheck:prelude_values())].

%% Report §11.5: each name and each type as the session writes it, the
%% names qualified and another module's types too.
browse(Text, Namespace, #session{interfaces = Interfaces, scope = Scope}) ->
    InScope = Interfaces ++ ern_prelude:stdlib_interfaces(),
    case [Interface || #interface{namespace = Held} = Interface <- InScope, Held =:= Namespace] of
        [] ->
            {'Left', <<"no module ", Text/binary, " is in scope">>};
        Found ->
            #interface{types = InterfaceTypes, values = InterfaceValues} = Last = lists:last(Found),
            ScopeState = ern_typecheck:scope_state(Interfaces ++ [Last]),
            TypeState = ern_types:set_scope(ScopeState, [],
                                            maps:values(maps:get(types, Scope, #{})), []),
            Types = [unicode:characters_to_binary([abstract_text(TypeInfo), "type ",
                                                   ern_namespace:text(QualifiedName)])
                     || {QualifiedName, TypeInfo} <- lists:sort(maps:to_list(InterfaceTypes))],
            Values = [unicode:characters_to_binary(
                        [ern_namespace:text(QualifiedName), " : ",
                         ern_types:format_scheme(Scheme, TypeState)])
                      || {QualifiedName, Scheme} <- lists:sort(maps:to_list(InterfaceValues))],
            {'Right', Types ++ Values}
    end.

abstract_text(#type_info{abstract = true}) -> "abstract ";
abstract_text(_) -> "".

%% Report §2.3: a name as it is written, its segments between the dots,
%% or `none` for text that is no name: an empty segment, or one longer than
%% the host holds in a name, 255 characters. A trailing dot, which
%% completion leaves after a namespace, names the namespace.
segments(Text) ->
    Parts = binary:split(without_dot(Text), <<".">>, [global]),
    case lists:all(fun(Part) -> Part =/= <<>> andalso byte_size(Part) =< 255 end, Parts) of
        true -> {ok, [binary_to_atom(Part) || Part <- Parts]};
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
%% is words each beginning with a capital letter, `Http.Parser` for
%% `http/parser.ern` and `OrderedSet` for `ordered_set.ern`; a name that
%% is not one is refused rather than looked for.
module_name(Text) ->
    case segments(Text) of
        {ok, Namespace} ->
            case lists:all(fun is_segment/1, Namespace) of
                true -> {ok, Namespace};
                false -> not_module(Text)
            end;
        none ->
            not_module(Text)
    end.

is_segment(Segment) ->
    ern_namespace:component(atom_to_list(Segment)) =/= error.

not_module(Text) ->
    {error, <<Text/binary, " is not a module name: each segment of one is words beginning with"
              " a capital letter, as in Http.Parser or OrderedSet">>}.

%% Report §11.2, §11.4: the documentation of one declaration, as
%% `ern doc` renders it, read from the module that declares it: an input
%% of this session, or a module on the load path.
-spec doc(#session{}, binary()) -> {'Left', binary()} | {'Right', binary()}.
doc(Session, Text) ->
    case page(Session, Text) of
        {ok, Page, _} -> {'Right', unicode:characters_to_binary(Page)};
        none -> {'Left', <<"no documentation for ", Text/binary>>}
    end.

%% The documentation of a name as it is written, with its segments; none
%% for text that is no name.
page(Session, Text) ->
    maybe
        {ok, Segments} ?= segments(Text),
        {ok, Page} ?= doc_of(Session, Segments),
        {ok, Page, Segments}
    end.

%% Report §11.2: the page for a name, as the session stands, for
%% `Shift-Tab`. The reader asks while an input runs, so it reads the
%% session the front end keeps rather than asking the session.
-spec documentation(binary()) -> 'None' | {'Some', binary()}.
documentation(Text) ->
    Session = persistent_term:get({?MODULE, session}, #session{}),
    case page(Session, Text) of
        {ok, Page, Segments} ->
            %% Appendix E.0 rule 6: a declaration without a `since` of its
            %% own has its module's, which the brief shows
            Since = case string:find(unicode:characters_to_binary(Page), <<"*Since ">>) of
                        nomatch -> since_line(Session, Segments);
                        _ -> []
                    end,
            {'Some', unicode:characters_to_binary([Page, Since])};
        none ->
            'None'
    end.

since_line(Session, Segments) ->
    Version = case module_of_name(Session, Segments) of
                  none -> undefined;
                  prelude -> ern_page:since(prelude);
                  Beam -> ern_page:since(Beam)
              end,
    case Version of
        undefined -> [];
        _ -> ["*Since ", Version, ".*\n"]
    end.

%% The compiled module a documented name comes from, or the prelude.
module_of_name(Session, Segments) when length(Segments) >= 2 ->
    case beam_of(Session, lists:droplast(Segments)) of
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
-spec fields(binary()) -> [{'Name', binary(), 'Value', binary()}].
fields(Typed) ->
    Session = persistent_term:get({?MODULE, session}, #session{}),
    case string:split(Typed, ".", trailing) of
        [Head, _] when Head =/= <<>> ->
            maybe
                {ok, Binds, Expr} ?= input(Head),
                {'Right', {_, #checked{type = Type, env = Env}}} ?=
                    check_module(Session#session{last_input = Session#session.last_input + 1},
                                 ['$Fields'], {typed, <<"fields">>}, Head, input_entry(Expr),
                                 Binds),
                TypeState = ern_typecheck:type_state(Env),
                [name('Value', [Head, ".", atom_to_list(Field)],
                      [Head, ".", atom_to_list(Field), " : ",
                       ern_types:format(FieldType, TypeState)])
                 || {Field, FieldType} <- ern_typecheck:fields(Type, Env)]
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
        #enclosing{path = Path, name = Name, argument = Argument} ->
            %% a constructor's name begins with a capital (report §2.3)
            case not is_integer(Argument) orelse hd(atom_to_list(Name)) < $a of
                true -> constructor_signature(Path, Name, Argument);
                false -> call_signature(Path, Name, Argument)
            end;
        none ->
            'None'
    end.

call_signature(Path, Name, Argument) ->
    Session = persistent_term:get({?MODULE, session}, #session{}),
    Text = unicode:characters_to_binary(ern_namespace:text(Path ++ [Name])),
    %% a callee that does not check, a name not in scope, has none, and
    %% neither has one whose declaration the checker does not hold or whose
    %% type is not a function's
    case scheme_of(Session, Text) of
        {ok, Scheme, Env} ->
            Params = parameters(Session, Path, Name),
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, Argument,
                                                         ern_typecheck:type_state(Env)),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
        none ->
            'None'
    end.

%% The declared type of a name, checked as an input of that one name in a
%% module of its own that does not enter the session.
scheme_of(Session, Text) ->
    maybe
        {ok, Binds, Expr} ?= input(Text),
        {'Right', {_, #checked{typed = Typed, env = Env}}} ?=
            check_module(Session#session{last_input = Session#session.last_input + 1},
                         ['$Signature'], {typed, <<"signature">>}, Text, input_entry(Expr),
                         Binds),
        {Path, Name} ?= one_name(Typed),
        {ok, #scheme{type = {tfn, _, _, _}} = Scheme} ?=
            ern_typecheck:declared_scheme(Env, Path, Name),
        {ok, Scheme, Env}
    else
        _ -> none
    end.

%% Report §11.2: a constructor's fields, as a signature, the one whose
%% value is at the cursor marked, and none where a field's name stands.
constructor_signature(Path, Name, Argument) ->
    Session = persistent_term:get({?MODULE, session}, #session{}),
    case named_constructor(Session, Path, Name) of
        {ok, #constructor_info{fields = Fields,
                               scheme = #scheme{type = {tfn, Params, _, _}} = Scheme}} ->
            %% a constructor is declared, so its signature is a head's
            Names = case Fields of
                        {named, Named} -> Named;
                        _ -> lists:duplicate(length(Params), '_')
                    end,
            Marked = case Argument of
                         {field, Field} -> field_index(Field, Names, length(Params));
                         none -> length(Params);
                         Index -> Index
                     end,
            {Head, This, Rest} = ern_types:format_call(Scheme, Names, Marked,
                                                       session_type_state(Session)),
            Text = ern_namespace:text(Path ++ [Name]),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(This), unicode:characters_to_binary(Rest)}};
        _ ->
            'None'
    end.

field_index(Field, Names, Otherwise) ->
    Indexed = lists:zip(lists:seq(0, length(Names) - 1), Names),
    case lists:search(fun({_, Name}) -> Name =:= Field end, Indexed) of
        {value, {Index, _}} -> Index;
        false -> Otherwise
    end.

%% A constructor by the name written: the session's, the prelude's, or a
%% module's.
named_constructor(#session{scope = Scope, interfaces = Interfaces}, [], Name) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none -> ern_typecheck:prelude_constructor(Name);
        QualifiedName -> constructor_info(QualifiedName, Interfaces)
    end;
named_constructor(#session{interfaces = Interfaces}, Path, Name) ->
    constructor_info(Path ++ [Name], Interfaces ++ ern_prelude:stdlib_interfaces()).

constructor_info(QualifiedName, Interfaces) ->
    case [ConstructorInfo || #interface{types = Types} <- Interfaces,
                             {_, #type_info{constructors = Constructors}} <- maps:to_list(Types),
                             #constructor_info{qualified_name = Found} = ConstructorInfo
                                 <- Constructors,
                             Found =:= QualifiedName] of
        [ConstructorInfo | _] -> {ok, ConstructorInfo};
        [] -> none
    end.

%% Report §11.2: the call is found wherever the input stands, so the text
%% is read as an expression, as a block's statement, a `let`, and as
%% declarations, the first that stops inside a call answering.
within(Before) ->
    Parsers = [fun ern_parser:parse_expr/1, fun ern_parser:parse_statement/1,
               fun ern_parser:parse_string/1],
    case [Enclosing || Parse <- Parsers,
                       {error, #diagnostic{incomplete = true, within = Enclosing}}
                           <- [Parse(Before)],
                       Enclosing =/= undefined] of
        [Enclosing | _] -> Enclosing;
        [] -> none
    end.

%% The parameter names a function's documentation entry carries, from the
%% session's input or the module that declares it; none where no
%% declaration carries them, the prelude's and a function value's.
parameters(Session, Path, Name) ->
    Beam = case session_beam(Session, Path, Name) of
               none when Path =/= [] -> beam_of(Session, Path);
               Found -> Found
           end,
    %% a module's function by its local name, a type's member as `Type.name`
    Keys = [entry_name([Name]) | [entry_name([lists:last(Path), Name]) || Path =/= []]],
    case Beam of
        none ->
            none;
        _ ->
            {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
            case [Params || {{function, Key, _}, _, _, _, #{params := Params}} <- Entries,
                            lists:member(atom_to_binary(Key), Keys)] of
                [Params | _] -> Params;
                [] -> none
            end
    end.

session_beam(#session{scope = Scope, beams = Beams}, Path, Name) ->
    Key = case Path of
              [] -> Name;
              [MemberOf] -> {MemberOf, Name};
              _ -> none
          end,
    case maps:get(Key, maps:get(values, Scope, #{}), none) of
        none -> none;
        QualifiedName -> declaring_beam(QualifiedName, Path ++ [Name], Beams)
    end.

%% The session's own names first, then a module's, then the prelude's,
%% which is where a name no module declares is documented (report §9);
%% then a constructor, whose documentation is its type's, and a module,
%% whose documentation is the head of its page (report §11.2).
%% A name that is a type and a module too, `List`, shows the type's section
%% and then the module's head; a namespace that is neither lists what it
%% holds.
doc_of(_Session, ['Prelude']) ->
    %% report §11.2, §4.2: `Prelude` names the prelude, whose page it is
    {ok, ern_page:prelude_page()};
doc_of(Session, ['Prelude' | Segments]) ->
    %% the prelude's name, past one the session declares; a member of a
    %% built-in type is documented by its type's module (§9.6)
    first([fun() -> prelude_doc(Segments) end, fun() -> module_doc(Session, Segments) end]);
doc_of(Session, Segments) ->
    case first([fun() -> session_doc(Session, Segments) end,
                fun() -> module_doc(Session, Segments) end,
                fun() -> prelude_doc(Segments) end,
                fun() -> constructor_doc(Session, Segments) end]) of
        {ok, Page} ->
            case module_head(Session, Segments) of
                {ok, Head} -> {ok, [Page, "\n", Head]};
                none -> {ok, Page}
            end;
        none ->
            first([fun() -> module_head(Session, Segments) end,
                   fun() -> namespace_doc(Session, Segments) end])
    end.

%% Report §11.2: a namespace that is no module and no documented type,
%% `Net` where only `net/http.ern` is, is documented by what it holds, each
%% name with its type.
namespace_doc(_, []) ->
    none;
namespace_doc(Session, Segments) ->
    Prefix = unicode:characters_to_binary(ern_namespace:text(Segments) ++ "."),
    case [Shown || {'Name', Text, _, Shown} <- names(Session),
                   binary:match(Text, Prefix) =:= {0, byte_size(Prefix)}] of
        [] -> none;
        Held -> {ok, ["# namespace ", ern_namespace:text(Segments), "\n\n",
                      [["- `", Shown, "`\n"] || Shown <- Held]]}
    end.

first([]) ->
    none;
first([Find | Rest]) ->
    case Find() of
        {ok, Page} -> {ok, Page};
        none -> first(Rest)
    end.

%% Report §11.4: a constructor is documented in its type's section, so its
%% documentation is its type's: a session constructor's the session's type,
%% a module's its module's type, and an unqualified one the prelude's.
constructor_doc(#session{scope = Scope, beams = Beams} = Session, [Name]) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none ->
            case ern_typecheck:prelude_constructor(Name) of
                {ok, #constructor_info{type_qualified_name = TypeQualifiedName}} ->
                    prelude_doc(TypeQualifiedName);
                none -> none
            end;
        QualifiedName ->
            case constructor_type(QualifiedName, Session) of
                {ok, TypeQualifiedName} ->
                    TypeName = lists:last(TypeQualifiedName),
                    Beam = declaring_beam(TypeQualifiedName, [TypeName], Beams),
                    {ok, ern_page:session_declaration(Beam, entry_name([TypeName]), entry)};
                none ->
                    none
            end
    end;
constructor_doc(Session, Segments) ->
    case constructor_type(Segments, Session) of
        {ok, TypeQualifiedName} -> module_doc(Session, TypeQualifiedName);
        none -> none
    end.

%% The type a constructor belongs to, from the interfaces in scope.
constructor_type(QualifiedName, #session{interfaces = Interfaces}) ->
    Namespace = lists:droplast(QualifiedName),
    Constructor = lists:last(QualifiedName),
    InScope = Interfaces ++ ern_prelude:stdlib_interfaces(),
    case [TypeQualifiedName
          || #interface{types = Types} <- InScope,
             {TypeQualifiedName, #type_info{constructors = Constructors, abstract = false}}
                 <- maps:to_list(Types),
             lists:droplast(TypeQualifiedName) =:= Namespace,
             #constructor_info{name = Name} <- Constructors, Name =:= Constructor] of
        [TypeQualifiedName | _] -> {ok, TypeQualifiedName};
        [] -> none
    end.

%% Report §11.2: a module's documentation is the head of its page.
module_head(Session, Segments) ->
    case beam_of(Session, Segments) of
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
session_doc(#session{scope = Scope, beams = Beams} = Session, Segments) ->
    Key = case Segments of
              [Name] -> Name;
              [MemberOf, Name] -> {MemberOf, Name};
              _ -> none
          end,
    Values = maps:get(values, Scope, #{}),
    Types = maps:get(types, Scope, #{}),
    case {maps:get(Key, Values, none), maps:get(Key, Types, none)} of
        {none, none} ->
            none;
        {none, QualifiedName} ->
            TypeName = lists:last(QualifiedName),
            Beam = declaring_beam(QualifiedName, [TypeName], Beams),
            {ok, ern_page:session_declaration(Beam, entry_name([TypeName]), entry)};
        {QualifiedName, _} ->
            TypeState = session_type_state(Session),
            Line = scheme_line(name_text(Key), QualifiedName, Session, TypeState),
            Beam = declaring_beam(QualifiedName, Segments, Beams),
            {ok, ern_page:session_declaration(Beam, entry_name(Segments), [Line])}
    end.

%% The input that declared the name: the qualified name without the
%% segments the name itself is written with.
declaring_beam(QualifiedName, Segments, Beams) ->
    Namespace = lists:sublist(QualifiedName, length(QualifiedName) - length(Segments)),
    maps:get(Namespace, Beams, none).

%% The name a documentation entry is under, as it is written: `map`, a
%% member as `Stack.push`, and a prelude name as `Address.call`.
entry_name(Segments) ->
    unicode:characters_to_binary(ern_namespace:text(Segments)).

%% A module on the load path, `List.map`, or one of its type's members,
%% `Net.Http.Request.method`.
module_doc(Session, Segments) when length(Segments) >= 2 ->
    case entry(beam_of(Session, lists:droplast(Segments)), entry_name([lists:last(Segments)])) of
        {ok, Page} ->
            {ok, Page};
        none when length(Segments) >= 3 ->
            [MemberOf, Member] = lists:nthtail(length(Segments) - 2, Segments),
            entry(beam_of(Session, lists:sublist(Segments, length(Segments) - 2)),
                  entry_name([MemberOf, Member]));
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
beam_of(#session{beams = Beams}, Namespace) ->
    case Beams of
        #{Namespace := Beam} -> Beam;
        _ -> beam_on_path(Namespace)
    end.

beam_on_path(Namespace) ->
    ErlangModule = ern_emitter:erlang_module(Namespace),
    Paths = [code:which(ErlangModule), code:where_is_file(atom_to_list(ErlangModule) ++ ".beam")],
    case [Beam || Path <- Paths, is_list(Path), {ok, Beam} <- [file:read_file(Path)]] of
        [] -> none;
        [Beam | _] -> Beam
    end.

entry(none, _) -> none;
entry(Beam, Name) -> ern_page:declaration(Beam, Name).

%% Report §11.2: a typed input is the file `input`; an input from a startup
%% file is named by the file, its positions moved to the line it stands on
%% there and, on its first line, to the column it begins in, and its lines
%% quoted from the file.
diagnostic({typed, Name}, Input, Diagnostics) ->
    unicode:characters_to_binary([ern_diagnostic:format(binary_to_list(Name), Input, Diagnostic)
                                  || Diagnostic <- Diagnostics]);
diagnostic(#startup_input{file = Path, first = First, column = Column}, Input, Diagnostics) ->
    Source = case file:read_file(Path) of
                 {ok, Text} -> Text;
                 {error, _} -> Input
             end,
    unicode:characters_to_binary(
      [ern_diagnostic:format(ern_build:shown(binary_to_list(Path)), Source,
                             moved(Diagnostic, First - 1, Column - 1))
       || Diagnostic <- Diagnostics]).

%% A diagnostic's positions, a number of lines further down, and on the
%% input's first line a number of columns further right.
moved(#diagnostic{span = Span, labels = Labels} = Diagnostic, Lines, Columns) ->
    Moved = fun(Spanned) -> moved_span(ern_diagnostic:span(Spanned), Lines, Columns) end,
    Diagnostic#diagnostic{span = Moved(Span),
                          labels = [{Moved(LabelSpan), Text} || {LabelSpan, Text} <- Labels]}.

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
-spec load(#session{}, binary()) -> {'Left', binary()} | {'Right', {#session{}, binary()}}.
load(#session{modules = Modules} = Session, Text) ->
    case module_name(Text) of
        {ok, Namespace} ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            Standard = [Held || #interface{namespace = Held} <- ern_prelude:stdlib_interfaces()],
            case lists:member(Namespace, Standard) of
                %% report §4.2, §11.2: a standard library namespace is taken,
                %% and the module, in scope since the session began, is one
                %% the session has loaded, which is refused
                true ->
                    {'Left', <<Name/binary, " is the standard library's, in scope from the"
                               " start\n">>};
                false when is_map_key(Namespace, Modules) ->
                    {'Left', <<Name/binary, " is loaded already; :reload compiles it again"
                               " when its source has changed\n">>};
                false ->
                    load(Session, Name, Namespace)
            end;
        {error, Refusal} ->
            {'Left', <<Refusal/binary, "\n">>}
    end.

%% A refusal ends in a line feed, as a diagnostic the compiler gives does,
%% since the shell prints both alike. What is loaded is remembered, since
%% completion and `Shift-Tab` read the session from where it is kept.
load(#session{source_root = SourceRoot} = Session, Name, Namespace) ->
    case source_of(Session, Namespace) of
        {ok, File} ->
            #build_module{namespace = Declared} =
                ern_build:module_of(ern_build:absolute(File), SourceRoot),
            case Declared of
                Namespace ->
                    %% report §11.2: what it uses that the session has not
                    %% loaded and whose source the root holds is compiled too
                    Sources = with_sources(Session, [{Namespace, File}], []),
                    case compile_in_order(Session, Sources) of
                        {ok, Modules} ->
                            Lines = [[ern_namespace:text(Compiled), ", compiled from ",
                                      relative(Source, Session)]
                                     || {Compiled, Source} <- lists:reverse(Sources)],
                            with_needed(Session, Modules,
                                        unicode:characters_to_binary(lists:join("\n", Lines)));
                        {error, Failed} ->
                            {'Left', iolist_to_binary(Failed)}
                    end;
                _ ->
                    {'Left', <<(list_to_binary(ern_namespace:text(Declared)))/binary,
                               " is declared in ",
                               (list_to_binary(relative(File, Session)))/binary,
                               ", which is not where ", Name/binary, " belongs\n">>}
            end;
        none ->
            case compiled_of(Session, Namespace) of
                {ok, File, Beam, Hash} ->
                    with_needed(Session, [{Namespace, Beam, Hash}],
                                <<Name/binary, ", from ",
                                  (list_to_binary(relative(File, Session)))/binary>>);
                none ->
                    {'Left', <<"no module ", Name/binary, " under the source root or on the"
                               " load path\n">>}
            end
    end.

%% Report §11.2: the modules to compile for `:load`, each with its source:
%% the one named, and each it uses, directly or through another, that the
%% session has not loaded and whose source the source root holds. A module
%% that does not parse uses nothing here; compiling it reports why.
with_sources(_Session, [], Acc) ->
    Acc;
with_sources(#session{source_root = SourceRoot, modules = Loaded} = Session,
             [{Namespace, File} | Rest], Acc) ->
    case lists:keymember(Namespace, 1, Acc) of
        true ->
            with_sources(Session, Rest, Acc);
        false ->
            Dependencies =
                try ern_build:compile_order([ern_build:module_of(ern_build:absolute(File),
                                                                 SourceRoot)],
                                            SourceRoot, load_path(Session)) of
                    [#build_module{dependencies = Found}] -> Found
                catch
                    throw:_ -> []
                end,
            More = [{Dependency, Source} || Dependency <- Dependencies,
                                            not is_map_key(Dependency, Loaded),
                                            {ok, Source} <- [source_of(Session, Dependency)]],
            with_sources(Session, Rest ++ More, Acc ++ [{Namespace, File}])
    end.

%% The modules loaded, after what they use that the session has not
%% loaded, and `:load`'s answer.
with_needed(Session, Modules, Line) ->
    case needed(Session, Modules) of
        {ok, Needed} ->
            All = Needed ++ Modules,
            case refused_compiled(Session, All) of
                none -> installed(Session, All, Line);
                Refusal -> {'Left', <<(unicode:characters_to_binary(Refusal))/binary, "\n">>}
            end;
        {error, Text} ->
            {'Left', Text}
    end.

%% Report §11.2: a compiled module is refused as `ern run` refuses one: a
%% file that holds another module than its path names, and a module compiled
%% against another interface of a module it uses, or of the standard
%% library, than the session holds; none, or the refusal.
refused_compiled(Session, All) ->
    StdlibHash = ern_build:stdlib_hash("."),
    Interfaces = [Interface || {_, Beam, _} <- All,
                               {ok, #{interface := Interface}} <- [ern_interface:read(Beam)]]
        ++ Session#session.interfaces ++ ern_prelude:stdlib_interfaces(),
    Refusals = lists:append([compiled_refusals(Namespace, Beam, Interfaces, StdlibHash)
                             || {Namespace, Beam, _} <- All]),
    case Refusals of
        [] -> none;
        [First | _] -> First
    end.

compiled_refusals(Namespace, Beam, Interfaces, StdlibHash) ->
    {ok, #{interface := #interface{namespace = Held}, deps := Dependencies} = Chunk} =
        ern_interface:read(Beam),
    Name = ern_namespace:text(Namespace),
    [Name ++ "'s compiled file holds " ++ ern_namespace:text(Held)
     ++ "; build it again from its source root" || Held =/= Namespace]
        ++ [Name ++ " was compiled against another standard library; build " ++ Name ++ " again"
            || not lists:member(maps:get(stdlib, Chunk, none), [none, StdlibHash])]
        ++ [Name ++ " was compiled against another " ++ ern_namespace:text(Dependency)
            ++ "; build " ++ Name ++ " again"
            || {Dependency, Hash} <- Dependencies,
               [Interface | _] <- [held_interfaces(Dependency, Interfaces)],
               ern_interface:hash(Interface) =/= Hash].

held_interfaces(Namespace, Interfaces) ->
    [Interface || #interface{namespace = Held} = Interface <- Interfaces, Held =:= Namespace].

%% The modules installed and their bindings evaluated, and `:load`'s answer.
installed(Session, All, Line) ->
    Session1 = install(Session, All),
    case initialize(in_order(All)) of
        ok ->
            {'Right', {remember(Session1), Line}};
        {fault, Site, Cause} ->
            withdraw_all(All),
            {'Left', <<(binding_fault(Site, Cause))/binary, "; nothing was loaded\n">>}
    end.

%% Report §8.5, §11.2: the modules in the order their bindings are
%% evaluated, each after those it depends on.
in_order(Modules) ->
    ErlangModules = [ern_emitter:erlang_module(Namespace) || {Namespace, _, _} <- Modules],
    ByErlangModule = maps:from_list(lists:zip(ErlangModules, Modules)),
    [maps:get(ErlangModule, ByErlangModule) || ErlangModule <- ern_rt:ordered(ErlangModules)].

%% Report §11.2: the modules a failed `:load` or `:reload` had loaded, each
%% gone with the processes its bindings started, which end as a reload ends
%% those of a previous version, so that the session is as it was.
withdraw_all(Modules) ->
    [withdraw(ern_emitter:erlang_module(Namespace)) || {Namespace, _, _} <- Modules],
    ok.

withdraw(ErlangModule) ->
    code:delete(ErlangModule),
    unloaded([Pid || {Pid, _} <- ern_rt:live(), erlang:check_process_code(Pid, ErlangModule)]),
    code:purge(ErlangModule).

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
initialize([{Namespace, _, _} | Rest]) ->
    ErlangModule = ern_emitter:erlang_module(Namespace),
    case erlang:function_exported(ErlangModule, '$init', 0) of
        true -> initialize(Namespace, ErlangModule, Rest);
        false -> initialize(Rest)
    end.

%% A binding's fault is :load's to report, so the process catches it and
%% ends without one, and no subscriber of Process.faults hears of it twice;
%% a kill, which nothing catches, is seen by the monitor. The fault is
%% named by the binding's site, which '$init' gave the process (report
%% §8.5, §11.2), and a kill by the module.
initialize(Namespace, ErlangModule, Rest) ->
    Self = self(),
    Ref = make_ref(),
    Init = fun() ->
               Result = try ErlangModule:'$init'() of
                            _ -> ok
                        catch
                            throw:{ern, fault, Cause} -> {fault, ern_rt:site(), Cause};
                            throw:{ern, fault, Cause, _} -> {fault, ern_rt:site(), Cause};
                            Class:Error -> {fault, ern_rt:site(), fault_text(Class, Error)}
                        end,
               Self ! {Ref, Result}
           end,
    %% watched from its spawn, so that its end is known however soon it
    %% comes (report §6.9)
    _ = ern_rt:spawn_monitored(Init, fun(Down) -> {Ref, Down} end, <<"Shell.load">>),
    receive
        {Ref, ok} ->
            receive {Ref, {'Down', _, _, _}} -> ok end,
            initialize(Rest);
        {Ref, {fault, _, _} = Fault} ->
            receive {Ref, {'Down', _, _, _}} -> ok end,
            Fault;
        {Ref, {'Down', _, Reason, _}} ->
            {fault, unicode:characters_to_binary(ern_namespace:text(Namespace)),
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
needed(Session, Modules) ->
    Compiled = [Namespace || {Namespace, _, _} <- Modules],
    lists:foldl(fun({_, Beam, _}, Found) -> needed(Session, Beam, Found, Compiled) end, {ok, []},
                Modules).

%% What one module uses that neither the session nor the modules compiled
%% with it, Compiled, provide.
needed(_Session, _Beam, {error, _} = Error, _Compiled) ->
    Error;
needed(#session{modules = Loaded} = Session, Beam, {ok, _} = Found, Compiled) ->
    {ok, #{deps := Dependencies}} = ern_interface:read(Beam),
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   ({Namespace, _}, {ok, Acc}) ->
                        case is_map_key(Namespace, Loaded) orelse lists:member(Namespace, Compiled)
                             orelse lists:keymember(Namespace, 1, Acc) of
                            true -> {ok, Acc};
                            false -> needed_one(Session, Namespace, Acc, Compiled)
                        end
                end, Found, Dependencies).

needed_one(Session, Namespace, Acc, Compiled) ->
    case compiled_of(Session, Namespace) of
        {ok, _, Beam, Hash} ->
            case needed(Session, Beam, {ok, Acc}, Compiled) of
                {ok, Acc1} -> {ok, Acc1 ++ [{Namespace, Beam, Hash}]};
                Error -> Error
            end;
        none ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            {error, <<"no module ", Name/binary, " on the load path\n">>}
    end.

%% Report §11.2: every module the session loaded whose source has changed,
%% compiled and loaded again. A process still in the previous version, and
%% a binding that holds a function of it, keep it; the reload that needs
%% that version ends them, and the one before names them. Every changed
%% module is compiled before any is loaded, and where one does not compile
%% none is, so the session goes on with every module as it was.
-spec reload(#session{}) -> {'Left', binary()} | {'Right', {#session{}, [binary()]}}.
reload(#session{modules = Modules} = Session) ->
    Sources = [{Namespace, Loaded, source_of(Session, Namespace)}
               || {Namespace, Loaded} <- lists:sort(maps:to_list(Modules))],
    Changed = [{Namespace, File}
               || {Namespace, Loaded, {ok, File}} <- Sources,
                  {ok, Hash} <- [source_hash(File)],
                  Hash =/= Loaded],
    Sourceless = sourceless(Session, [Namespace || {Namespace, _, none} <- Sources]),
    case Changed of
        [] ->
            {'Right', {Session, [<<"no source has changed">> | Sourceless]}};
        _ ->
            case compile_all(Session, Changed) of
                {ok, Needed, Compiled} -> reloaded(Session, Needed, Compiled, Sourceless);
                {error, Text} -> {'Left', iolist_to_binary([Text, "nothing was reloaded\n"])}
            end
    end.

%% Report §11.2: the changed modules loaded again, after what they use that
%% the session had not loaded, which is loaded as `:load` loads it.
reloaded(Session, Needed, Compiled, Sourceless) ->
    Session1 = install(Session, Needed),
    case initialize(Needed) of
        ok ->
            {Session2, Lines} = lists:foldl(fun reload_one/2, {Session1, []}, Compiled),
            Faulted = case initialize(in_order(Compiled)) of
                          ok -> [];
                          {fault, Site, Cause} -> [kept_values(Site, Cause)]
                      end,
            {'Right', {remember(Session2), lists:reverse(Lines) ++ Faulted ++ Sourceless}};
        {fault, Site, Cause} ->
            withdraw_all(Needed),
            {'Left', <<(binding_fault(Site, Cause))/binary, "; nothing was reloaded\n">>}
    end.

%% Report §11.2: a loaded module whose source the source root does not
%% hold is named, since `:reload` cannot compile it again.
sourceless(_Session, []) ->
    [];
sourceless(#session{source_root = SourceRoot}, Names) ->
    Text = lists:join(", ", [ern_namespace:text(Namespace) || Namespace <- Names]),
    [unicode:characters_to_binary(["the source root ", ern_build:shown(SourceRoot),
                                   " holds no source of ", Text])].

%% Report §11.2: the changed modules compiled in the order they use one
%% another, each against the session's modules and those compiled before
%% it; and, while one's interface differs from the one the session holds,
%% every loaded module that uses it compiled again with them, from its
%% source. The modules compiled, with what they use that the session has
%% not loaded; or why they cannot all be. A regression: a module that used
%% a changed interface kept running against the previous one, and faulted.
compile_all(Session, Changed) ->
    case compile_in_order(Session, Changed) of
        {ok, Modules} ->
            case stale_users(Session, Changed, Modules) of
                [] ->
                    case needed(Session, Modules) of
                        {ok, Needed} -> {ok, Needed, Modules};
                        Error -> Error
                    end;
                Users ->
                    Sources = [{Namespace, source_of(Session, Namespace)} || Namespace <- Users],
                    case [Namespace || {Namespace, none} <- Sources] of
                        [] ->
                            More = [{Namespace, File} || {Namespace, {ok, File}} <- Sources],
                            compile_all(Session, Changed ++ More);
                        Sourceless ->
                            {error, [unicode:characters_to_binary(
                                       [ern_namespace:text(Namespace),
                                        " uses a module whose interface changed,"
                                        " and the source root holds no source of it\n"])
                                     || Namespace <- Sourceless]}
                    end
            end;
        Error ->
            Error
    end.

%% Each module compiled, a module before those that use it, against the
%% interfaces of the session and of the modules compiled before it.
compile_in_order(#session{source_root = SourceRoot} = Session, Set) ->
    try ern_build:compile_order([ern_build:module_of(ern_build:absolute(File), SourceRoot)
                                 || {_, File} <- Set], SourceRoot, load_path(Session)) of
        Ordered ->
            Compile = fun(#build_module{namespace = Namespace, file = File}, Interfaces) ->
                          case compile_source(Session, File, Interfaces) of
                              {ok, _, Beam, _} = Ok ->
                                  {ok, #{interface := Interface}} = ern_interface:read(Beam),
                                  {{Namespace, Ok}, Interfaces#{Namespace => Interface}};
                              Error ->
                                  {{Namespace, Error}, Interfaces}
                          end
                      end,
            {Compiled, _} = lists:mapfoldl(Compile, loaded_interfaces(Session), Ordered),
            case [Text || {_, {error, Text}} <- Compiled] of
                [] ->
                    {ok, [{Namespace, Beam, Hash} || {Namespace, {ok, _, Beam, Hash}} <- Compiled]};
                Failed -> {error, Failed}
            end
    catch
        throw:{cli_error, Message} ->
            {error, [unicode:characters_to_binary([Message, "\n"])]};
        throw:{errors, Failed, Diagnostics} ->
            {ok, Source} = file:read_file(Failed),
            {error, [unicode:characters_to_binary(
                       [ern_diagnostic:format(ern_build:shown(Failed), Source, Diagnostic)
                        || Diagnostic <- Diagnostics])]}
    end.

%% The loaded modules, outside those compiled, that use a compiled module
%% whose interface is not the one the session holds.
stale_users(#session{modules = Loaded} = Session, Set, Modules) ->
    Held = loaded_interfaces(Session),
    Changed = [Namespace || {Namespace, Beam, _} <- Modules,
                            {ok, #{interface := Interface}} <- [ern_interface:read(Beam)],
                            not is_map_key(Namespace, Held)
                                orelse ern_interface:hash(maps:get(Namespace, Held))
                                       =/= ern_interface:hash(Interface)],
    UsesChanged = fun(Namespace) ->
                      lists:any(fun({Dependency, _}) -> lists:member(Dependency, Changed) end,
                                recorded_dependencies(Session, Namespace))
                  end,
    [Namespace || Namespace <- lists:sort(maps:keys(Loaded)),
                  not lists:keymember(Namespace, 1, Set), UsesChanged(Namespace)].

%% The dependencies a loaded module was compiled against, as its compiled
%% form records them: the session's, or the file it was loaded from.
recorded_dependencies(#session{beams = Beams}, Namespace) ->
    Beam = case Beams of
               #{Namespace := Found} -> Found;
               _ ->
                   {ok, Found} = file:read_file(code:which(ern_emitter:erlang_module(Namespace))),
                   Found
           end,
    {ok, #{deps := Dependencies}} = ern_interface:read(Beam),
    Dependencies.

%% The interfaces of the modules the session has loaded, by namespace.
loaded_interfaces(#session{interfaces = Interfaces, modules = Modules}) ->
    maps:from_list([{Namespace, Interface}
                    || #interface{namespace = Namespace} = Interface <- Interfaces,
                       is_map_key(Namespace, Modules)]).

reload_one({Namespace, Beam, Hash}, {Session, Lines}) ->
    ErlangModule = ern_emitter:erlang_module(Namespace),
    Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
    {Ended, Session1} = case erlang:check_old_code(ErlangModule) of
                            true -> end_previous(Session, ErlangModule);
                            false -> {[], Session}
                        end,
    code:purge(ErlangModule),
    Session2 = install(Session1, Namespace, Beam, Hash),
    Waiting = in_previous(Session2, ErlangModule),
    {Session2, waiting_line(Name, Waiting) ++ ended_lines(Name, Ended)
               ++ [<<Name/binary, ", compiled again">> | Lines]}.

ended_lines(_, []) ->
    [];
ended_lines(Name, Ended) ->
    [<<Name/binary, ": ended ", (listed(Ended))/binary, " in the previous version">>].

waiting_line(_, []) ->
    [];
waiting_line(Name, Waiting) ->
    [<<Name/binary, ": ", (listed(Waiting))/binary, " in the previous version; a further reload"
       " of it ends them">>].

listed(Items) ->
    unicode:characters_to_binary(lists:join(", ", Items)).

%% Report §11.2: what is left in the version a reload replaced, a process
%% by its spawn site (§6.9) and a binding by its name.
in_previous(Session, ErlangModule) ->
    [<<Site/binary, ", a process">> || {Pid, Site} <- ern_rt:live(),
                                       erlang:check_process_code(Pid, ErlangModule)]
        ++ [<<(atom_to_binary(Name))/binary, ", a binding">>
            || {Name, _} <- bindings_of(Session, ErlangModule)].

%% Report §7.3, §11.2: the processes still in it end with the cause the
%% report gives them, a fault reported as every fault is, and the bindings
%% that hold a function of it are forgotten.
end_previous(#session{scope = Scope} = Session, ErlangModule) ->
    Processes = [{Pid, Site} || {Pid, Site} <- ern_rt:live(),
                                erlang:check_process_code(Pid, ErlangModule)],
    unloaded([Pid || {Pid, _} <- Processes]),
    Bindings = bindings_of(Session, ErlangModule),
    Values = maps:without([Key || {_, Key} <- Bindings], maps:get(values, Scope, #{})),
    {[<<Site/binary, ", a process">> || {_, Site} <- Processes]
     ++ [<<(atom_to_binary(Name))/binary, ", a binding">> || {Name, _} <- Bindings],
     Session#session{scope = Scope#{values => Values}}}.

%% The session's bindings whose value holds a function of the module.
bindings_of(#session{scope = Scope}, ErlangModule) ->
    [{name_atom(Key), Key}
     || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
        holds_fun(value_of(QualifiedName), ErlangModule)].

name_atom({_, Name}) -> Name;
name_atom(Name) -> Name.

value_of(QualifiedName) ->
    Holder = ern_emitter:erlang_module(lists:droplast(QualifiedName)),
    persistent_term:get({Holder, lists:last(QualifiedName)}, undefined).

holds_fun(Function, ErlangModule) when is_function(Function) ->
    {module, Held} = erlang:fun_info(Function, module),
    Held =:= ErlangModule;
holds_fun([Head | Tail], ErlangModule) ->
    holds_fun(Head, ErlangModule) orelse holds_fun(Tail, ErlangModule);
holds_fun(Tuple, ErlangModule) when is_tuple(Tuple) ->
    holds_fun(tuple_to_list(Tuple), ErlangModule);
holds_fun(Map, ErlangModule) when is_map(Map) ->
    holds_fun(maps:to_list(Map), ErlangModule);
holds_fun(_, _) ->
    false.

%% Each module loaded, in order, and in scope by its namespace.
install(Session, Modules) ->
    lists:foldl(fun({Namespace, Beam, Hash}, Acc) ->
                    install(Acc, Namespace, Beam, Hash)
                end, Session, Modules).

install(#session{interfaces = Interfaces, modules = Modules} = Session, Namespace, Beam, Hash) ->
    ErlangModule = ern_emitter:erlang_module(Namespace),
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    Others = [Other || #interface{namespace = Found} = Other <- Interfaces, Found =/= Namespace],
    Session#session{interfaces = Others ++ [Interface], modules = Modules#{Namespace => Hash},
                    beams = maps:put(Namespace, Beam, Session#session.beams)}.

%% Report §11.2: a module compiled against the modules the session has
%% loaded, as Interfaces holds them. A regression: a dependency `:load` had
%% compiled in memory was sought as a `.erc`, and the dependent refused.
compile_source(#session{source_root = SourceRoot} = Session, File, Interfaces) ->
    case ern_build:compile_source(File, SourceRoot, load_path(Session), Interfaces) of
        {ok, Namespace, Beam, Hash} ->
            {ok, Namespace, Beam, Hash};
        {refused, Text} ->
            {error, unicode:characters_to_binary([Text, "\n"])};
        {error, Failed, Diagnostics} ->
            {ok, Source} = file:read_file(Failed),
            %% report §11.5: the file named from the working directory
            {error, unicode:characters_to_binary(
                      [ern_diagnostic:format(ern_build:shown(Failed), Source, Diagnostic)
                       || Diagnostic <- Diagnostics])}
    end.

%% Report §11.2, §11.1: where a compiled module is found by its namespace,
%% one `:load` names or one a module uses: the load path, and then the
%% source root, which is where `ern build` writes by default.
load_path(#session{load_path = LoadPath, source_root = SourceRoot}) ->
    lists:uniq(LoadPath ++ [filename:absname(SourceRoot)]).

source_of(#session{source_root = SourceRoot}, Namespace) ->
    File = filename:join(SourceRoot, ern_build:module_path(Namespace) ++ ".ern"),
    case filelib:is_regular(File) of
        true -> {ok, File};
        false -> none
    end.

compiled_of(Session, Namespace) ->
    Relative = ern_build:module_path(Namespace) ++ ".erc",
    case [Candidate || Dir <- load_path(Session), Candidate <- [filename:join(Dir, Relative)],
                       filelib:is_regular(Candidate)] of
        [File | _] ->
            {ok, Beam} = file:read_file(File),
            case ern_interface:read(Beam) of
                {ok, #{source_hash := Hash}} -> {ok, File, Beam, Hash};
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

relative(File, #session{source_root = SourceRoot}) ->
    case string:prefix(filename:absname(File), filename:absname(SourceRoot) ++ "/") of
        nomatch -> File;
        Relative -> Relative
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
to_screen(Bytes) ->
    case persistent_term:get({?MODULE, output}, undefined) of
        undefined ->
            case persistent_term:get({?MODULE, screen}, undefined) of
                undefined -> file:write(standard_io, Bytes);
                Address -> ern_rt:send(Address, shown(Bytes))
            end;
        {_, Device} ->
            %% report §11.2: a program's output goes where `:output` sent
            %% it, which is another terminal and its own scrolling
            file:write(Device, Bytes),
            ok
    end.

%% Report §11.2: the text the screen shows of what a program wrote, with
%% U+FFFD for each byte that is not UTF-8. A character cut across two
%% writes waits for its end, which each sink keeps, one to a process.
shown(Bytes) ->
    Whole = <<(erase_cut())/binary, Bytes/binary>>,
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
        {error, Error} ->
            {'Left', <<"cannot write to ", Path/binary, ": ",
                       (unicode:characters_to_binary(file:format_error(Error)))/binary>>}
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
bind(Session, declarations, Namespace, _Value, _Type, _Env, Interface) ->
    %% the functions its own values hold join what the input needs
    ErlangModule = ern_emitter:erlang_module(Namespace),
    Held = lists:foldl(fun({_, Stored}, Acc) -> fun_modules(Stored, Acc) end, [],
                       stored(ErlangModule)),
    {Namespace, Needs, Keys} = maps:get(ErlangModule, uses()),
    HeldModules = [HeldModule || HeldModule <- Held, session_module(HeldModule),
                                 HeldModule =/= ErlangModule],
    set_uses(maps:put(ErlangModule, {Namespace, lists:usort(Needs ++ HeldModules), Keys}, uses())),
    joined(Session, Interface);
bind(Session, it, _Namespace, Value, Type, Env, _Interface) ->
    case open(Type, Env) of
        true -> Session;
        false -> bound(Session, [{it, Value, Type}], Env)
    end;
bind(Session, {names, Names}, _Namespace, Value, Type, Env, _Interface) ->
    bound(Session, components(Names, Value, Type, Env), Env);
bind(Session, {lambda, Name, Scheme}, _Namespace, Value, _Type, Env, _Interface) ->
    bound(Session, [{Name, Value, Scheme}], Env);
bind(Session, Name, _Namespace, Value, Type, Env, _Interface) ->
    bound(Session, [{Name, Value, Type}], Env).

%% Each name a pattern bound, with its value and type: the whole of the
%% input's value for one name, a component of its tuple for more.
components([], _Value, _Type, _Env) ->
    [];
components([Name], Value, Type, _Env) ->
    [{Name, Value, Type}];
components(Names, Value, Type, Env) ->
    {ttuple, Types} = ern_types:substitute(Type, ern_typecheck:type_state(Env)),
    lists:zip3(Names, tuple_to_list(Value), Types).

%% Report §11.2: whether the input's value was left unbound, its type
%% not being determined by the input itself.
-spec unbound(#checked{}) -> boolean().
unbound(#checked{binds = it, type = Type, env = Env}) -> open(Type, Env);
unbound(#checked{}) -> false.

%% Report §11.2: a value whose type its own input did not settle is
%% printed but not bound, since a scheme with a variable of that input's
%% type state means nothing to the inputs after it. A named binding is
%% refused outright when it is checked; `it` is the one this can still
%% reach, and `declared/1` says that it was not bound.
open(Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    ern_types:free_variables(ern_types:substitute(Type, TypeState), TypeState) =/= [].

%% The names an input binds, held by one module, a getter for each, which
%% needs the session's modules whose functions the values hold and whose
%% types their types name.
bound(Session, [], _Env) ->
    Session;
bound(#session{last_holder = LastHolder, free_holders = Free} = Session, Bound, Env) ->
    {Number, Session1} = case Free of
                             [Freed | Rest] -> {Freed, Session#session{free_holders = Rest}};
                             [] -> {LastHolder + 1, Session#session{last_holder = LastHolder + 1}}
                         end,
    Holder = [list_to_atom("$Bindings" ++ integer_to_list(Number))],
    ErlangModule = ern_emitter:erlang_module(Holder),
    TypeState = ern_typecheck:type_state(Env),
    [persistent_term:put({ErlangModule, Name}, Value) || {Name, Value, _} <- Bound],
    Names = [Name || {Name, _, _} <- Bound],
    {module, ErlangModule} =
        code:load_binary(ErlangModule, atom_to_list(ErlangModule), holder(ErlangModule, Names)),
    Values = maps:from_list([{Holder ++ [Name], binding_scheme(Type, TypeState)}
                             || {Name, _, Type} <- Bound]),
    Interface = #interface{namespace = Holder, values = Values,
                           lets = [Holder ++ [Name] || Name <- Names]},
    Held = lists:foldl(fun({_, Value, _}, Acc) -> fun_modules(Value, Acc) end, [], Bound),
    Needs = [HeldModule || HeldModule <- Held, session_module(HeldModule)]
        ++ mentions(Interface, Holder),
    Keys = [{ErlangModule, Name} || Name <- Names],
    set_uses(maps:put(ErlangModule, {Holder, lists:usort(Needs), Keys}, uses())),
    joined(Session1, Interface).

%% A bound name's scheme: a generalized `let`'s own, or its type alone.
binding_scheme(#scheme{} = Scheme, _TypeState) -> Scheme;
binding_scheme(Type, TypeState) -> ern_types:monomorphic(ern_types:substitute(Type, TypeState)).

%% Report §11.2: the session after an input has answered, what nothing
%% reaches any more let go, in the session's own process.
-spec collect(#session{}) -> #session{}.
collect(Session) ->
    remember(collected(Session)).

%% Report §11.2: the session's modules are the holders of what inputs
%% bound, the inputs that declared, and the inputs whose value holds one of
%% their functions. One is kept while the session can reach it, and let go
%% when it cannot: its values, its code, its interface, and its number,
%% which a later holder or input takes (report §2.3). What reaches one is a
%% name in the session's scope, a module whose old code a process is still
%% inside, and, from either, what that module needs (uses/0). A module whose
%% old code a process is inside is purged at a later collection, holders
%% here and inputs here and at each input's end (release/3), and its values
%% are let go once it is purged, since that process may still read them.
%% The session collects in its own process, once an input has answered
%% (collect/1), so that an input killed while it runs has let nothing go
%% that the session still names.
collected(#session{interfaces = Interfaces, scope = Scope, beams = Beams, free_holders = Free,
                   draining = Draining} = Session) ->
    Uses = uses(),
    Unpurged = persistent_term:get({?MODULE, unpurged}, []),
    Old = [ern_emitter:erlang_module(Namespace) || Namespace <- Unpurged]
        ++ [ern_emitter:erlang_module([Segment]) || Segment <- Draining],
    Named = [ern_emitter:erlang_module([hd(QualifiedName)])
             || Which <- [values, types, constructors],
                QualifiedName <- maps:values(maps:get(Which, Scope, #{})),
                session_segment(hd(QualifiedName))],
    Live = reached(Named ++ Old, Uses, #{}),
    Dead = [Namespace || ErlangModule := {Namespace, _, _} <- Uses,
                         not is_map_key(ErlangModule, Live)],
    lists:foreach(fun(Namespace) -> code:delete(ern_emitter:erlang_module(Namespace)) end, Dead),
    IsHolder = fun([Segment]) -> holder_number(Segment) =/= none end,
    {DeadHolders, DeadInputs} = lists:partition(IsHolder, Dead),
    Purgeable = fun(Namespace) -> code:soft_purge(ern_emitter:erlang_module(Namespace)) end,
    {Purged, Held} = lists:partition(fun(Segment) -> Purgeable([Segment]) end,
                                     Draining ++ [Segment || [Segment] <- DeadHolders]),
    {InputsPurged, InputsHeld} = lists:partition(Purgeable, Unpurged ++ DeadInputs),
    [persistent_term:erase(Key) || Namespace <- [[Segment] || Segment <- Purged] ++ InputsPurged,
                                   {Key, _} <- stored(ern_emitter:erlang_module(Namespace))],
    InputsHeld =/= Unpurged andalso persistent_term:put({?MODULE, unpurged}, InputsHeld),
    InputsPurged =/= [] andalso
        set_free_inputs(persistent_term:get({?MODULE, free_inputs}, []) ++ InputsPurged),
    set_uses(maps:without([ern_emitter:erlang_module(Namespace)
                           || Namespace <- [[Segment] || Segment <- Purged] ++ InputsPurged],
                          Uses)),
    Kept = [Interface || #interface{namespace = Namespace} = Interface <- Interfaces,
                         not lists:member(Namespace, Dead)],
    Session#session{interfaces = Kept,
                    beams = maps:without(Dead, Beams),
                    free_holders = Free ++ [holder_number(Segment) || Segment <- Purged],
                    draining = Held}.

%% The values a session module's top-level bindings hold, each under its
%% key, as the emitter keeps them (report §8.5): read by the module's own
%% keys, and not by every term the node holds, which reading would copy.
stored(ErlangModule) ->
    {_, _, Keys} = maps:get(ErlangModule, uses()),
    Missing = make_ref(),
    [{Key, Value} || Key <- Keys, Value <- [persistent_term:get(Key, Missing)], Value =/= Missing].

%% The session's modules the given ones reach, through what each needs.
reached([], _Uses, Live) ->
    Live;
reached([ErlangModule | Rest], Uses, Live) when is_map_key(ErlangModule, Live) ->
    reached(Rest, Uses, Live);
reached([ErlangModule | Rest], Uses, Live) ->
    Needs = case Uses of
                #{ErlangModule := {_, Needed, _}} -> Needed;
                _ -> []
            end,
    reached(Needs ++ Rest, Uses, Live#{ErlangModule => true}).

%% The session's modules whose names a term mentions, but its own: a type an
%% interface names is such a mention.
mentions(Term, [Own]) ->
    lists:usort([ern_emitter:erlang_module([Atom]) || Atom <- atoms(Term, []), Atom =/= Own,
                                                      session_segment(Atom)]).

atoms(Atom, Acc) when is_atom(Atom) -> [Atom | Acc];
atoms(Tuple, Acc) when is_tuple(Tuple) -> atoms(tuple_to_list(Tuple), Acc);
atoms([Head | Rest], Acc) -> atoms(Rest, atoms(Head, Acc));
atoms(Map, Acc) when is_map(Map) -> atoms(maps:to_list(Map), Acc);
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

session_module(ErlangModule) ->
    Name = atom_to_list(ErlangModule),
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
input_site(ErlangModule, Line) ->
    <<(maps:get(ErlangModule, names_of_inputs()))/binary, ":", (integer_to_binary(Line))/binary>>.

names_of_inputs() ->
    persistent_term:get({?MODULE, input_names}, #{}).

set_names(Names) ->
    names_of_inputs() =/= Names andalso persistent_term:put({?MODULE, input_names}, Names).

%% Report §11.2: the session is a scope of its own. The interface behind an
%% input joins the ones the checker is given, and what it declares joins the
%% scope under the unqualified name, which a later declaration of that name
%% overwrites.
joined(#session{interfaces = Interfaces, scope = Scope} = Session, #interface{} = Interface) ->
    #interface{namespace = Namespace, types = InterfaceTypes, values = InterfaceValues} = Interface,
    %% a type declared again starts with no members: the earlier type's
    %% belong to it, and its name now names another
    Declared = [lists:last(QualifiedName) || QualifiedName <- maps:keys(InterfaceTypes)],
    Kept = maps:filter(fun({MemberOf, _}, _) -> not lists:member(MemberOf, Declared);
                          (_, _) -> true
                       end, maps:get(values, Scope, #{})),
    Values = maps:merge(Kept, maps:from_list([{value_key(Namespace, QualifiedName), QualifiedName}
                                              || QualifiedName <- maps:keys(InterfaceValues)])),
    Types = maps:merge(maps:get(types, Scope, #{}),
                       maps:from_list([{lists:last(QualifiedName), QualifiedName}
                                       || QualifiedName <- maps:keys(InterfaceTypes)])),
    NewConstructors = [{lists:last(QualifiedName), QualifiedName}
                       || #type_info{constructors = TypeConstructors}
                              <- maps:values(InterfaceTypes),
                          #constructor_info{qualified_name = QualifiedName} <- TypeConstructors],
    Constructors = maps:merge(maps:get(constructors, Scope, #{}), maps:from_list(NewConstructors)),
    Session#session{interfaces = Interfaces ++ [Interface],
                    scope = Scope#{values => Values, types => Types, constructors => Constructors}}.

%% A name as an input after this one writes it: a type member under the
%% type that owns it (report §4.2), anything else under its own name.
value_key(Namespace, QualifiedName) ->
    case lists:nthtail(length(Namespace), QualifiedName) of
        [Name] -> Name;
        [MemberOf, Name] -> {MemberOf, Name}
    end.

%% The getter the emitter emits for a module's own value (§8.5). A binding
%% is a `let`, so a later input reaches it as it reaches any other module's
%% value, and calls it by applying what the getter answers (§4.6).
%%
%% Report §8.6: the host's compiler waits for a process of its own, and the
%% input's process is an Ernest process waiting with it. It is marked as a
%% foreign call in progress, which is what it is, so that `Deadlock` is not
%% declared over a binding being made.
holder(ErlangModule, Names) ->
    ern_rt:in_foreign(fun() -> holder_beam(ErlangModule, Names) end).

holder_beam(ErlangModule, Names) ->
    Get = fun(Name) ->
              erl_syntax:application(
                erl_syntax:module_qualifier(erl_syntax:atom(persistent_term),
                                            erl_syntax:atom(get)),
                [erl_syntax:tuple([erl_syntax:atom(ErlangModule), erl_syntax:atom(Name)])])
          end,
    Forms = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(ErlangModule)]),
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list(
                                     [erl_syntax:arity_qualifier(
                                        erl_syntax:atom(ern_emitter:function_atom(Name)),
                                        erl_syntax:integer(0))
                                      || Name <- Names])])
             | [erl_syntax:function(erl_syntax:atom(ern_emitter:function_atom(Name)),
                                    [erl_syntax:clause([], none, [Get(Name)])])
                || Name <- Names]],
    {ok, _, Beam} = compile:forms([erl_syntax:revert(Form) || Form <- Forms], [return_errors]),
    Beam.

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
declared(#checked{binds = declarations, namespace = Namespace, declarations = Declarations,
                  interface = Interface, env = Env}) ->
    [line(Declaration, Namespace, Interface, Env) || Declaration <- Declarations,
                                                     kind(Declaration) =/= other];
declared(#checked{binds = {names, []}}) ->
    [];
declared(#checked{binds = {names, Names}, type = Type, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    Types = case Names of
                [_] ->
                    [Type];
                _ ->
                    {ttuple, Components} = ern_types:substitute(Type, TypeState),
                    Components
            end,
    [unicode:characters_to_binary([atom_to_list(Bound), " : ",
                                   ern_types:format(BoundType, TypeState)])
     || {Bound, BoundType} <- lists:zip(Names, Types)];
declared(#checked{binds = {lambda, Name, Scheme}, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    [unicode:characters_to_binary([atom_to_list(Name), " : ",
                                   ern_types:format_scheme(Scheme, TypeState)])];
declared(#checked{binds = Name} = Checked) ->
    [<<(atom_to_binary(Name))/binary, " : ", (type_text(Checked))/binary>>].

kind(#type_declaration{}) -> <<"type">>;
kind(#abstract_declaration{}) -> <<"abstract type">>;
kind(#foreign_type_declaration{}) -> <<"foreign type">>;
kind(#fn_declaration{}) -> value;
kind(#foreign_fn_declaration{}) -> value;
kind(#let_declaration{}) -> value;
kind(_) -> other.

line(Declaration, Namespace, #interface{values = Values}, Env) ->
    case kind(Declaration) of
        value ->
            {MemberOf, Name} = declared_name(Declaration),
            Scheme = maps:get(Namespace ++ MemberOf ++ [Name], Values),
            Text = ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env)),
            unicode:characters_to_binary([local_name(MemberOf, Name), " : ", Text]);
        Keyword ->
            {_, Name} = declared_name(Declaration),
            <<Keyword/binary, " ", (atom_to_binary(Name))/binary>>
    end.

declared_name(#fn_declaration{member_of = undefined, name = Name}) -> {[], Name};
declared_name(#fn_declaration{member_of = MemberOf, name = Name}) -> {[MemberOf], Name};
declared_name(#foreign_fn_declaration{member_of = undefined, name = Name}) -> {[], Name};
declared_name(#foreign_fn_declaration{member_of = MemberOf, name = Name}) -> {[MemberOf], Name};
declared_name(#let_declaration{name = Name}) -> {[], Name};
declared_name(#type_declaration{name = Name}) -> {[], Name};
declared_name(#abstract_declaration{declaration = #type_declaration{name = Name}}) -> {[], Name};
declared_name(#foreign_type_declaration{name = Name}) -> {[], Name}.

local_name([], Name) -> atom_to_list(Name);
local_name([MemberOf], Name) -> [atom_to_list(MemberOf), ".", atom_to_list(Name)].
