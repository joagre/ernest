%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. An input is a module
%% of its own, `$Input<n>`, checked against the load path and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
-module(ern_shell).

-export([loaded/1, start/0, spawn_program/0, config_startup/0, is_same_file/2, needs_more/1,
         check/3, is_unit/1, type_text/1, run/4, show/3, bindings/1, slot/1, names/0,
         session_names/0, session_texts/0, source_root/0, segment/1, component/1, forget/2,
         browse/2, doc/2,
         documentation/1, fields/1, signature/1, declared_type/2, load/2,
         reload/1, version/0, write/1, screen/1, to_screen/1,
         leaves_it_unchanged/1, collect/1, input_site/2, is_expression/1, declared/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").
-include_lib("cli/include/ern_build.hrl").
-include_lib("kernel/include/file.hrl").

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
                  scope = #{}, beams = #{}, source_hashes = #{}, last_holder = 0, prelude}).
%% last_input: the highest input number given; last_holder: the highest
%% `$Bindings` number given; a number freed is given again first, from the
%% kept row `free` (free_namespace/1)
%% source_hashes: the namespace of a module the session has loaded, to the hash
%% of the source it was compiled from, which `:reload` compares (§11.2)
%% beams: the namespace of an input that declared, and of a module `:load`
%% or `:reload` compiled, to its compiled module, which `:doc` reads the
%% documentation of (report §11.2, §11.4)
%% prelude: the prelude's environment, the standard library's interfaces
%% among it, built when the session starts and kept while it lives, since
%% neither changes while it runs; the queries of completion, `:browse` and
%% `:doc` read it rather than build it each time
%% A checked input: the namespace of the module it became, its typed tree,
%% the declarations it was checked as, the module's interface, the
%% checker's environment, its type, what it binds, and its site, the name
%% and the line offset its spawn sites are written with (site/1).
-record(checked, {namespace, typed, declarations, interface, env, type, binds, site,
                  printed_name}).
%% binds: `{name, Name}` for the name a `let` binds, `{lambda, Name,
%% Scheme}` for a `let` of a lambda, generalized, `{names, Names}` for the
%% names a `let` with a pattern binds, `it` for an expression, or
%% `declarations`; a name is tagged, so that no name stands for a tag.
%% printed_name: the name the input's module prints with (input_names/0).
%% A value with the descriptor of its type, so it prints as E.1 prints it.
-record(value, {term, descriptor}).
%% Where an input from a startup file came from: the file, the line it
%% stands on, and the column it begins in (report §11.2); a typed input's
%% origin is `{typed, Name}`.
-record(startup_input, {file, line, column}).

%% Report §11.2: what the runner loaded before the shell started, which the
%% shell begins from. What is set once, or by a command alone, is a
%% persistent term, which a read does not copy: what the runner loaded and
%% the screen. What the shell's own state changes to as inputs run is a row
%% of a table the runner owns, made here, since the host scans every
%% process when a persistent term is replaced or erased. Its rows are the
%% session as it stands (keep_session/1), the holders' and the inputs'
%% numbers free to give again and the modules not yet purged (release/3,
%% collected/1), what each session module needs (uses/0), each input's
%% name (input_site/2), and the values of a reloaded module's dropped lets
%% (dropped_lets/3). A binding's value
%% is §8.5's store, a persistent term, as a module's is, so that a later
%% input reads it as it reads another module's value; its release when it
%% is replaced, `it` at almost every input, scans every process, a cost
%% that grows with the processes the session has (the log's *The Hardening
%% Built*).
-spec loaded(#loaded{}) -> ok.
loaded(Loaded) ->
    persistent_term:put({?MODULE, loaded}, Loaded),
    %% the table of an earlier loading goes, where a host loads again, so
    %% that this one is the caller's own and lasts as long as it does
    try ets:delete(?MODULE) catch error:badarg -> true end,
    ?MODULE = ets:new(?MODULE, [named_table, public]),
    ok.

%% A row of the front end's table, and Default where there is none, or no
%% table, nothing having been loaded.
kept(Key, Default) ->
    try ets:lookup(?MODULE, Key) of
        [{_, Value}] -> Value;
        [] -> Default
    catch
        error:badarg -> Default
    end.

keep(Key, Value) ->
    ets:insert(?MODULE, {Key, Value}),
    Value.

-spec start() -> #session{}.
start() ->
    #loaded{load_path = LoadPath, source_root = SourceRoot, interfaces = Interfaces} =
        persistent_term:get({?MODULE, loaded}, #loaded{}),
    keep_session(#session{load_path = LoadPath, source_root = SourceRoot,
                          prelude = ern_typecheck:prelude_env(),
                          interfaces = [Interface || {Interface, _} <- Interfaces],
                          source_hashes = maps:from_list([{Interface#interface.namespace, Hash}
                                                    || {Interface, Hash} <- Interfaces])}).

%% Report §11.2: the session as it stands, which completion reads. The
%% reader asks for the names while an input runs, when the session is busy
%% answering nothing, so it cannot be a message to the session; the front
%% end keeps the latest, as it keeps what the runner loaded. An input's
%% declarations join the session when it has run, not when it is checked,
%% so this is set in both places.
keep_session(Session) ->
    keep(session, Session).

kept_session() ->
    kept(session, #session{}).

%% Report §11.2, §8.1: the file's entry point, spawned beside the prompt and
%% not entered, and nothing where the shell was started with no file. A
%% fault in it reaches the session through Process.faults, to which the
%% session subscribed before (E.21).
-spec spawn_program() -> 'Unit'.
spawn_program() ->
    case persistent_term:get({?MODULE, loaded}, #loaded{}) of
        #loaded{entry = #entry_point{erlang_module = ErlangModule, function = Function,
                                     site = Site}} ->
            ErlangFunction = ern_emitter:function_atom(Function),
            _ = ern_rt:spawn(fun() -> ErlangModule:ErlangFunction() end, Site),
            'Unit';
        _ ->
            'Unit'
    end.

%% Report §11.2: the startup file of the configuration directory
%% `--config-dir` names, named from the working directory as §11.5 names a
%% file, or none. The person's the shell finds itself, in Ernest, from the
%% environment, and it reads both, whether they are there and whose they
%% are among it.
-spec config_startup() -> {'Some', binary()} | 'None'.
config_startup() ->
    case persistent_term:get({?MODULE, loaded}, #loaded{}) of
        #loaded{config_startup = none} -> 'None';
        #loaded{config_startup = File} ->
            {'Some', unicode:characters_to_binary(ern_build:shown(File))}
    end.

%% Report §11.2: whether two paths name one file, both there, on one device,
%% with one node, which a file's entry in Ernest does not hold.
-spec is_same_file(binary(), binary()) -> boolean().
is_same_file(First, Second) ->
    case {file:read_file_info(First), file:read_file_info(Second)} of
        {{ok, #file_info{major_device = Device, inode = Inode}},
         {ok, #file_info{major_device = Device, inode = Inode}}} -> true;
        _ -> false
    end.

%% Report §11.2: at a terminal the shell takes another line where the
%% parser cannot finish the input. Every reading is tried, the expression,
%% the declarations and a `let` with a pattern, as `input/1` tries them: an
%% input that could still become any of them is unfinished.
-spec needs_more(binary()) -> boolean().
needs_more(Text) ->
    unfinished(ern_parser:parse_expr(Text)) orelse unfinished(ern_parser:parse_string(Text))
        orelse unfinished(ern_parser:parse_statement(Text)).

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
check(Session, Origin, Input) ->
    without_line_feed(checked_input(Session, Origin, Input)).

checked_input(#session{last_input = LastInput} = Session, Origin, Input) ->
    InputOrigin = case Origin of
                 {'Prompt', Number} -> {typed, <<"input ", (integer_to_binary(Number))/binary>>};
                 {'Startup', File, Line, Column} ->
                     #startup_input{file = File, line = Line, column = Column}
             end,
    %% an input takes the number of one whose module was unloaded, whose
    %% name is an atom already, before a new one (report §2.3)
    {Namespace, LastInput1} = case free_namespace(input) of
                                  {ok, Free} -> {Free, LastInput};
                                  none -> {input_namespace(LastInput + 1), LastInput + 1}
                              end,
    Numbered = Session#session{last_input = LastInput1},
    PrintedName = printed_name(Origin),
    case input(Input) of
        {ok, Binds, Expr} ->
            checked(check_module(Numbered, Namespace, InputOrigin, Input, input_entry(Expr),
                                 Binds), PrintedName);
        {declarations, Declarations} ->
            checked(check_module(Numbered, Namespace, InputOrigin, Input, Declarations,
                                 declarations), PrintedName);
        {error, Diagnostic} ->
            {'Left', diagnostic(InputOrigin, Input, [Diagnostic])}
    end.

%% Report §11.2: the name a session type a later input shadows prints
%% under, the input that declared it: `$Input4` for the fourth input typed,
%% as its diagnostics count it, and `$Startup2` for the second input
%% checked from the startup files, which the session does not count. The
%% module's own name is another, a slot a later input reuses (§2.3).
printed_name({'Prompt', Number}) ->
    "$Input" ++ integer_to_list(Number);
printed_name({'Startup', _, _, _}) ->
    "$Startup" ++ integer_to_list(keep(startup_inputs, kept(startup_inputs, 0) + 1)).

%% The name each module of the session's inputs prints with, of those the
%% session still holds.
input_names() ->
    maps:from_list([{Namespace, PrintedName}
                    || {ErlangModule, {Namespace, _, _}} <- maps:to_list(uses()),
                       PrintedName <- [kept({printed_name, ErlangModule}, none)],
                       PrintedName =/= none]).

%% Report §2.3: the modules the session makes are named as no Ernest name
%% is spelled, since an identifier holds no `$`: the module an input
%% becomes, `$Input<n>`; the one that holds what a `let` at the prompt
%% binds, `$Bindings<n>`; and the one a callee is checked in for
%% `Shift-Tab`. No input reaches them by name, and a module spelled as one
%% would be otherwise, `Input1`, is a module like any other.
input_namespace(Number) ->
    [list_to_atom("$Input" ++ integer_to_list(Number))].

checked({'Right', {Session, Checked}}, PrintedName) ->
    {'Right', {keep_session(Session), Checked#checked{printed_name = PrintedName}}};
checked(Other, _PrintedName) ->
    Other.

%% Report §11.2: an input is an expression, whose value is `it`; a `let`,
%% whose value is the name it binds; or declarations. A `let` at the prompt
%% is a block `let` (§4.6 is for a module's), so it is the entry point's
%% body and the name is bound to what the input answers.
input(Text) ->
    input(Text, []).

%% The same, read under the lexer's options: text that is read and not
%% run, a line being typed, is read with `no_new_names`.
input(Text, Read) ->
    case ern_parser:parse_expr(Text, Read) of
        {ok, Expr} ->
            {ok, it, Expr};
        {error, Diagnostic} ->
            case ern_parser:parse_string(Text, Read) of
                {ok, [#let_declaration{name = Name, body = Body, annotation = Annotation}]} ->
                    {ok, let_binds(Name, Body), annotated(Name, Body, Annotation)};
                {ok, Declarations} -> declarations(Declarations);
                {error, DeclarationDiagnostic} ->
                    case pattern_let(Text, Read) of
                        none ->
                            {error, reported_diagnostic(Text, Read, Diagnostic,
                                                        DeclarationDiagnostic)};
                        Parsed -> Parsed
                    end
            end
    end.

%% Report §11.2: a `let` whose pattern is not a name binds each name the
%% pattern binds. It is the block `{ let p = e; #(names) }`, whose value
%% holds the names in the order the pattern has them; `let _ = e` binds
%% none, and `<-` is refused, since no block follows it for it to end.
pattern_let(Text, Read) ->
    case ern_parser:parse_statement(Text, Read) of
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
%% only when a name follows it, a member's type name among them (§4.8).
reported_diagnostic(Text, Read, Diagnostic, DeclarationDiagnostic) ->
    case ern_lexer:tokenize(Text, Read) of
        {ok, Tokens} ->
            case declaration_start(Tokens) of
                true -> DeclarationDiagnostic;
                false -> Diagnostic
            end;
        _ ->
            Diagnostic
    end.

declaration_start([{'fn', _}, {ident, _, _} | _]) -> true;
declaration_start([{'fn', _}, {typename, _, _} | _]) -> true;
declaration_start([{Word, _} | _]) -> lists:member(Word, [type, abstract, foreign, export, 'let']);
declaration_start(_) -> false.

%% Report §11.2: what an input declares is the session's from then on, so
%% every declaration of an input is exported; a later input reaches it as it
%% reaches another module's declaration (§4.3). A declaring input holds no
%% `let`, which is refused here, so it has no top-level values to compute or
%% keep.
declarations(Declarations) ->
    case [Span || #let_declaration{span = Span} <- Declarations] of
        [] -> {declarations, [exported(Declaration) || Declaration <- Declarations]};
        [_, Second | _] -> {error, one_let(Second)};
        [Span] -> {error, one_let(Span)}
    end.

%% Report §11.2: a `let` at the prompt is a block `let`, and a block has one
%% of them per input; a `let` beside a declaration would be a top-level
%% `let`, which §4.6 generalizes and requires to be pure.
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
exported(#foreign_fn_declaration{} = Declaration) ->
    Declaration#foreign_fn_declaration{export = true};
exported(Declaration) ->
    Declaration.

%% Report §4.6, §11.2: a `let` that binds a name to a lambda is generalized,
%% as in a block; its scheme is known once the input is checked.
let_binds(Name, #e_lambda{}) -> {lambda, Name};
let_binds(Name, _) -> {name, Name}.

%% Report §11.2: a `let` at the prompt may carry an annotation, which the
%% checker holds its value to as it holds a `let` in a block's: the input
%% is `{ let x : T = e; x }`.
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

check_module(#session{interfaces = Interfaces, scope = Scope} = Session, Namespace, InputOrigin,
             Input, Declarations, Binds) ->
    case ern_typecheck:check(Namespace, Declarations, Interfaces,
                             Scope#{input_names => input_names()}) of
        {ok, Typed, Interface, Env} ->
            Type = input_type(Typed, Binds),
            Binds1 = generalized(Binds, Typed, Env),
            case refused(Type, Env, Binds1, Typed) of
                none ->
                    Checked = #checked{namespace = Namespace, typed = Typed,
                                       declarations = Declarations, interface = Interface,
                                       env = Env, type = Type, binds = Binds1,
                                       site = site(InputOrigin)},
                    {'Right', {Session, Checked}};
                {refused, Diagnostic} ->
                    {'Left', diagnostic(InputOrigin, Input, [Diagnostic])}
            end;
        {error, Diagnostics} ->
            {'Left', diagnostic(InputOrigin, Input,
                                [load_hinted(Session, Diagnostic) || Diagnostic <- Diagnostics])}
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
site(#startup_input{file = File, line = Line}) -> {File, Line - 1}.

%% Report §11.2: an input is compiled and run on its own, so what it
%% binds must have a type by the time it runs; a later input cannot
%% settle it, as a later statement of a block would. A binding whose
%% type is still open is refused with the annotation that would settle
%% it, rather than entering the session as a scheme whose variables mean
%% nothing to the inputs after it.
refused(Type, Env, Binds, Typed) ->
    case reply_refusal(Type, Env, Binds, Typed) of
        none -> undetermined(Type, Env, Binds, Typed);
        Refused -> Refused
    end.

%% Report §6.6, §11.2: an input's value is printed and dropped, and what a
%% `let` at the prompt binds is the session's, for any later input to use,
%% so neither may carry a reply, which is consumed exactly once.
reply_refusal(_Type, _Env, declarations, _Typed) ->
    none;
reply_refusal(Type, Env, _Binds, Typed) ->
    case ern_typecheck:is_reply_carrying(Type, Env) of
        false ->
            none;
        true ->
            TypeState = ern_typecheck:type_state(Env),
            {refused, #diagnostic{span = input_span(Typed),
                                  message = "an input's value cannot carry a reply, which is"
                                            " consumed exactly once; this one is "
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
            {refused, #diagnostic{span = input_span(Typed),
                                  message = lists:flatten(
                                              io_lib:format(undetermined_text(Binds),
                                                            [bound_names(Binds), Text])),
                                  help = undetermined_help(ern_types:resolve(Type, TypeState),
                                                           Binds)}}
    end.

%% Report §11.2, §6.1: an address whose mailbox type is open is settled by
%% its annotation or by the mailbox the spawned function declares, `Never`
%% for one that receives nothing; any other type by an annotation.
undetermined_help({tcon, ['Address'], _}, {name, Name}) ->
    "annotate the binding, `let " ++ atom_to_list(Name) ++ " : Address(T) = ...`, or write the"
    " spawned function's mailbox, `fn() : Unit with Never = ...` for one that receives nothing";
undetermined_help(_, _) ->
    "bind it with an annotation that settles the variable, as in `let xs : List(Int) = []`, or"
    " declare a function with `fn`".

undetermined_text({names, [_, _ | _]}) ->
    "the types of ~s are not determined by this input; together they are ~ts";
undetermined_text(_) ->
    "the type of ~s is not determined by this input; it is ~ts".

bound_names({names, Names}) -> lists:join(", ", [atom_to_list(Name) || Name <- Names]);
bound_names({name, Name}) -> atom_to_list(Name).

%% Report §11.5: the input's binding whole, from its start to the end of its
%% value, as `ern build` underlines a top-level `let`.
input_span([#fn_declaration{name = ?ENTRY, body = Body} | _]) ->
    {_, _, End} = ern_diagnostic:span(ern_ast:span(Body)),
    {1, 1, End};
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
               {Namespace, Name} ->
                   case ern_typecheck:declared_scheme(Namespace, Name, Env) of
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
        [#e_var{namespace = Namespace, name = Name}] -> {Namespace, Name};
        _ -> none
    end.

%% Report §11.2: the input runs in a process of its own; the outcome goes to
%% `Address`, so the shell's reader stays live and the address is what an
%% interruption kills.
-spec run(#session{}, #checked{}, integer(), term()) -> ern_rt:address().
run(Session, #checked{namespace = Namespace, typed = Typed, interface = Interface, env = Env,
                      type = Type, binds = Binds, site = {InputName, Offset}} = Checked,
    Serial, Address) ->
    Descriptor = ern_descriptor:describe(Type, Env, []),
    Build = #{source_hash => <<>>, deps => [], session_offset => Offset},
    {ok, ErlangModule, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    keep(free, kept(free, []) -- [Namespace]),
    record_uses(ErlangModule, Beam, Checked),
    %% report §11.2: an input that declares keeps its module for `:doc`;
    %% an expression's has no documentation, and is not kept
    Session1 = case Binds of
                   declarations ->
                       Session#session{beams = maps:put(Namespace, Beam, Session#session.beams)};
                   _ -> Session
               end,
    Body = fun() ->
               %% report §11.2: the input's own fault is its answer, caught
               %% here, so that its process does not end with a fault
               Outcome = try
                             Value = value(ErlangModule, Binds),
                             BoundSession = bind(Session1, Binds, Namespace, Value, Type, Env,
                                                 Interface),
                             {'Ok', keep_session(BoundSession), Serial,
                              #value{term = Value, descriptor = Descriptor}}
                         catch
                             Class:Error:Stack ->
                                 {'Faulted', fault_cause(Class, Error, Stack), Serial}
                         end,
               release(Namespace, Binds, Outcome),
               ern_rt:send(Address, Outcome)
           end,
    ern_rt:spawn(Body, <<InputName/binary, ":", (integer_to_binary(1 + Offset))/binary>>).

%% Report §11.2: what the input's module needs of the session's modules,
%% kept while it is (collected/1): those its code calls and, where it
%% declares, those whose types its declarations name; and the name its
%% spawn sites are written with. It stores no value (declarations/1).
record_uses(ErlangModule, Beam, #checked{namespace = Namespace, interface = Interface,
                                         binds = Binds, site = {InputName, _},
                                         printed_name = PrintedName}) ->
    {ok, {_, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    Calls = [Imported || {Imported, _, _} <- Imports, is_session_module(Imported),
                         Imported =/= ErlangModule],
    Named = case Binds of
                declarations -> mentions(Interface, Namespace);
                _ -> []
            end,
    set_uses(maps:put(ErlangModule, {Namespace, lists:usort(Calls ++ Named), []}, uses())),
    keep({input_name, ErlangModule}, InputName),
    keep({printed_name, ErlangModule}, PrintedName),
    ok.

%% An input that declares nothing, an expression or a `let`, is done with
%% its module once it has its answer, unless what it bound holds one of the
%% module's functions: it is deleted, and purged unless a process the input
%% spawned still runs it, which keeps it until that process ends; each
%% later input tries the purge again. An input that declares, and one whose
%% value holds its functions, is kept while the session can reach it, and
%% collected/1 lets it go.
release(Namespace, Binds, Outcome) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    Now = case {Binds, Outcome} of
              {declarations, _} -> kept;
              {_, {'Ok', _, _, #value{term = Value}}} ->
                  case lists:member(ErlangModule, fun_modules(Value, [])) of
                      true -> kept;
                      false -> unload(ErlangModule)
                  end;
              {_, {'Faulted', _, _}} -> unload(ErlangModule)
          end,
    case Now of
        kept ->
            ok;
        unpurged ->
            %% purged at a later collection (collected/1)
            keep(unpurged, kept(unpurged, []) ++ [Namespace]);
        purged ->
            %% report §2.3: an unloaded input's number, and so its name's
            %% atoms, are given to the next input; report §11.2: it reads
            %% no holder again
            keep(free, kept(free, []) ++ [Namespace]),
            forget_uses([ErlangModule])
    end,
    ok.

%% Report §2.3: the namespace of a holder or an input whose module was
%% purged, taken to be given again before a new number, or none.
free_namespace(Kind) ->
    case [Namespace || Namespace <- kept(free, []), kind_of_namespace(Namespace) =:= Kind] of
        [Namespace | _] when Kind =:= holder ->
            keep(free, kept(free, []) -- [Namespace]),
            {ok, Namespace};
        [Namespace | _] ->
            {ok, Namespace};
        [] ->
            none
    end.

kind_of_namespace([Segment]) ->
    case holder_number(Segment) of
        none -> input;
        _ -> holder
    end.

%% Deleted, and purged unless a process still runs it.
unload(ErlangModule) ->
    code:delete(ErlangModule),
    case code:soft_purge(ErlangModule) of
        true -> purged;
        false -> unpurged
    end.

%% The modules whose functions a value holds, in its data or in a
%% function's captures.
fun_modules(Value, Acc) ->
    [ErlangModule || {ErlangModule, _} <- held_functions(Value, [])] ++ Acc.

%% Each function a value holds, in its data or in a function's captures,
%% as its module and the version of the module's code it runs: the code's
%% md5 for a function the code made, which runs that version for as long as
%% it is held (report §6.10), and `current` for a function named by its
%% module and name, which runs whichever version is current.
held_functions(Function, Acc) when is_function(Function) ->
    {module, ErlangModule} = erlang:fun_info(Function, module),
    case erlang:fun_info(Function, type) of
        {type, local} ->
            {new_uniq, Version} = erlang:fun_info(Function, new_uniq),
            {env, Captured} = erlang:fun_info(Function, env),
            held_functions(Captured, [{ErlangModule, Version} | Acc]);
        {type, external} ->
            [{ErlangModule, current} | Acc]
    end;
held_functions(Tuple, Acc) when is_tuple(Tuple) ->
    held_functions(tuple_to_list(Tuple), Acc);
held_functions([Head | Rest], Acc) ->
    held_functions(Rest, held_functions(Head, Acc));
held_functions(Map, Acc) when is_map(Map) ->
    held_functions(maps:to_list(Map), Acc);
held_functions(_, Acc) ->
    Acc.

%% An input that declares runs nothing, having no top-level value to
%% compute (declarations/1). Its value is Unit, which prints nothing (report
%% §11.2).
value(_ErlangModule, declarations) ->
    'Unit';
value(ErlangModule, _Binds) ->
    ErlangModule:?ENTRY().

%% Report §7.3, §7.4: the cause of a fault the shell catches in a process
%% of its own, as the runtime gives a process's.
fault_cause(Class, Error, Stack) ->
    case ern_rt:fault_exit_reason(Class, Error, Stack) of
        {ern, fault, Cause} -> Cause;
        {ern, fault, Cause, _Trace} -> Cause
    end.

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
    Types = [unicode:characters_to_binary(type_line(Name, QualifiedName, Session))
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
%% name a slot admits; this only answers the slot, a `Shell.Complete.Slot`.
-spec slot(binary()) -> atom() | {'Fields', [{'Name', binary(), atom(), binary()}]}.
slot(Before) ->
    %% a line being typed is read and not run, so reading it makes no name:
    %% the host keeps a name for ever, and a `Tab` is pressed at every word
    ok = stdlib_met(),
    Read = [no_new_names],
    case [What || {true, What} <- [wanted(ern_parser:parse_expr(Before, Read)),
                                   wanted(ern_parser:parse_string(Before, Read))],
                  What =/= undefined] of
        [What | _] -> slot_for(What);
        [] -> 'Expression'
    end.

wanted({error, #diagnostic{incomplete = Incomplete, expected = What}}) -> {Incomplete, What};
wanted(_) -> {false, undefined}.

%% A name that names something has been met: the session's, when its input
%% ran, a loaded module's, when its interface was read, and the standard
%% library's once its interfaces are read, which is done here, once, before
%% a line is first read without making names.
stdlib_met() ->
    case persistent_term:get({?MODULE, stdlib_met}, false) of
        true ->
            ok;
        false ->
            _ = ern_prelude:stdlib_interfaces(),
            persistent_term:put({?MODULE, stdlib_met}, true)
    end.

slot_for(expression) -> 'Expression';
slot_for(typename) -> 'TypeName';
slot_for(pattern) -> 'Pattern';
slot_for(declaration) -> 'Declaration';
slot_for(#expected_field{kind = field, namespace = Namespace, constructor_name = ConstructorName,
                         segments = Segments}) ->
    {'Fields', fields_of(Namespace, ConstructorName, Segments)};
%% the parser could not tell a field's name from a value; the
%% constructor's type can, and only a named constructor has fields
slot_for(#expected_field{kind = field_or_value, namespace = Namespace,
                         constructor_name = ConstructorName}) ->
    case fields_of(Namespace, ConstructorName, []) of
        [] -> 'Expression';
        Fields -> {'Fields', Fields}
    end;
slot_for(#expected_field{kind = field_or_pattern, namespace = Namespace,
                         constructor_name = ConstructorName}) ->
    case fields_of(Namespace, ConstructorName, []) of
        [] -> 'Pattern';
        Fields -> {'Fields', Fields}
    end.

%% The fields of the constructor as it is written, found as the checker
%% finds it (report §4.2): unqualified, the session's or the prelude's, and
%% qualified, its module's; after a path's segments (report §5.6), the
%% fields of the type the path has reached.
%% Report §11.2: each as a `Shell.Complete.Name`, listed with its type, the
%% constructor's parameter in the field's place, both in declared order.
fields_of(Namespace, ConstructorName, Segments) ->
    Session = kept_session(),
    Written = named_constructor(Session, Namespace, ConstructorName),
    case along_path(Written, Segments, Session) of
        {ok, #constructor_info{fields = {named, Fields},
                               scheme = #scheme{type = {tfn, Params, _, _}}}} ->
            TypeState = session_type_state(Session),
            [name('Value', atom_to_list(Field),
                  atom_to_list(Field) ++ " : " ++ ern_types:format(Param, TypeState))
             || {Field, Param} <- lists:zip(Fields, Params)];
        _ ->
            []
    end.

%% Report §5.6, §11.2: the constructor a path's segments reach from one,
%% each segment a named field whose type has one constructor; none where
%% a segment is no such field.
along_path({ok, ConstructorInfo}, [], _Session) ->
    {ok, ConstructorInfo};
along_path({ok, #constructor_info{fields = {named, Fields},
                                  scheme = #scheme{type = {tfn, Params, _, _}}}},
           [Segment | Rest], Session) ->
    case field_index(Segment, Fields, none) of
        none -> none;
        Index ->
            case lists:nth(Index + 1, Params) of
                {tcon, QualifiedName, _} ->
                    along_path(one_constructor(QualifiedName, Session), Rest, Session);
                _ -> none
            end
    end;
along_path(_, _, _) ->
    none.

%% The one constructor of a type in scope, or none.
one_constructor(QualifiedName, #session{interfaces = Interfaces, prelude = Prelude}) ->
    Found = [TypeInfo || #interface{types = #{QualifiedName := TypeInfo}} <- Interfaces]
        ++ [TypeInfo || TypeInfo <- [ern_typecheck:lookup_type(QualifiedName, Prelude)],
                        TypeInfo =/= undefined],
    case Found of
        [#type_info{constructors = [ConstructorInfo]} | _] -> {ok, ConstructorInfo};
        _ -> none
    end.

%% Report §11.2: every name completion may reach — the session's, the
%% prelude's, and each module in scope with its exports — as
%% `Shell.Complete.Name`, whose fields are in declared order (§3.5): the
%% text as it is typed, its kind, the line a listing shows. Only the
%% reading of the interfaces is the host's; the matching is Ernest's.
-spec names() -> [{'Name', binary(), atom(), binary()}].
names() ->
    names(kept_session()).

names(#session{interfaces = Interfaces, scope = Scope, prelude = Prelude} = Session) ->
    TypeState = session_type_state(Session),
    Declared = [name('Value', name_text(Key),
                     scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{}))]
        ++ [name('Type', atom_to_list(Name), type_line(Name, QualifiedName, Session))
            || {Name, QualifiedName} <- maps:to_list(maps:get(types, Scope, #{}))]
        ++ [name('Constructor', atom_to_list(Name),
                 constructor_line(atom_to_list(Name),
                                  constructor_scheme(QualifiedName, Session), TypeState))
            || {Name, QualifiedName} <- maps:to_list(maps:get(constructors, Scope, #{}))],
    {PreludeTypes, _} = ern_typecheck:prelude_names(Prelude),
    %% report §11.5: a prelude value's type as `:type` prints it, its marks
    %% with it
    PreludeState = ern_typecheck:type_state(Prelude),
    PreludeNames = [name('Value', Text, Text ++ " : " ++ ern_types:format_scheme(Scheme,
                                                                                PreludeState))
                    || {QualifiedName, Scheme} <- ern_typecheck:prelude_values(Prelude),
                       Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Type', Text, "type " ++ Text)
            || QualifiedName <- PreludeTypes,
               Text <- [ern_namespace:text(QualifiedName)]]
        ++ [name('Constructor', Text, constructor_line(Text, {ok, Scheme}, TypeState))
            || {QualifiedName, #constructor_info{scheme = Scheme}}
                   <- maps:to_list(ern_typecheck:prelude_constructors(Prelude)),
               Text <- [ern_namespace:text(QualifiedName)]],
    ModuleNames = lists:append([module_names(Interface, TypeState)
                            || Interface <- Interfaces ++ ern_prelude:stdlib_interfaces()]),
    %% report §11.2: an operator is no name, and does not complete, and
    %% neither does a module the session made, which is spelled as no name
    lists:usort([Name || {'Name', Text, _, _} = Name <- Declared ++ PreludeNames ++ ModuleNames,
                         is_name_text(Text)]).

%% Every segment of a text begins with a letter or `_`, as a name's does.
is_name_text(Text) ->
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
    case constructor_info(QualifiedName, Interfaces) of
        {ok, #constructor_info{scheme = Scheme}} -> {ok, Scheme};
        none -> none
    end.

%% Report §11.2: the names `:forget` takes, the values and the types the
%% session declares; a member goes with its type.
-spec session_names() -> [{'Name', binary(), atom(), binary()}].
session_names() ->
    #session{scope = Scope} = Session = kept_session(),
    TypeState = session_type_state(Session),
    lists:usort([name('Value', name_text(Key),
                      scheme_line(name_text(Key), QualifiedName, Session, TypeState))
                 || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
                    is_atom(Key)]
                ++ [name('Type', atom_to_list(Name), type_line(Name, QualifiedName, Session))
                    || {Name, QualifiedName} <- maps:to_list(maps:get(types, Scope, #{}))]).

%% Report §11.2: every name the session declares, as it is written, its
%% values, members among them, its types, and its constructors: with
%% nothing typed, these and the modules are what completion lists.
-spec session_texts() -> [binary()].
session_texts() ->
    #session{scope = Scope} = kept_session(),
    lists:usort([unicode:characters_to_binary(name_text(Key))
                 || Which <- [values, types, constructors],
                    Key <- maps:keys(maps:get(Which, Scope, #{}))]).

%% Report §11.2: where `:load` finds a module's source, `--source-root`.
-spec source_root() -> binary().
source_root() ->
    #session{source_root = SourceRoot} = kept_session(),
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

%% Report §11.1, §4.2: the path component a namespace segment names, where
%% it is one, `kv_parser` for `KvParser`; the inverse of segment/1, asked of
%% the same owner.
-spec component(binary()) -> {'Some', binary()} | 'None'.
component(Segment) ->
    case ern_namespace:component(unicode:characters_to_list(Segment)) of
        {ok, Component} -> {'Some', unicode:characters_to_binary(Component)};
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
    [name('Type', Text, type_keyword(TypeInfo) ++ "type " ++ Text)
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
        TypeInfos -> lists:last(TypeInfos)
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
session_type_state(#session{scope = Scope, interfaces = Interfaces, prelude = Prelude}) ->
    TypeState = ern_typecheck:scope_state(Interfaces, Prelude),
    ern_types:set_scope([], maps:values(maps:get(types, Scope, #{})), [], input_names(),
                        TypeState).

%% Report §11.2: `:forget` removes a name the session declared, and `*`
%% every one of them. A type is forgotten with its constructors. A module
%% the session then no longer reaches, by a name or by a value that holds
%% its functions, collected/1 lets go; a value made before keeps the module
%% of its type while it is reached.
-spec forget(#session{}, binary()) -> {'Left', binary()} | {'Right', #session{}}.
forget(Session, <<"*">>) ->
    {'Right', keep_session(collected(Session#session{scope = #{}}))};
forget(#session{scope = Scope} = Session, Text) ->
    Values = maps:get(values, Scope, #{}),
    Types = maps:get(types, Scope, #{}),
    Constructors = maps:get(constructors, Scope, #{}),
    case segments(Session, Text) of
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
            {'Right', keep_session(collected(Session#session{scope = Scope1}))};
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
    case module_name(Session, Text) of
        {ok, ['Prelude']} -> {'Right', prelude_listing(Session)};
        {ok, Namespace} -> browse(Text, Namespace, Session);
        unmet -> {'Left', <<"no module ", (without_dot(Text))/binary, " is in scope",
                            (load_suffix(Session, Text))/binary>>};
        {error, Refusal} -> {'Left', Refusal}
    end.

%% Report §11.2, §9: the prelude's types and values, as `:browse` lists a
%% module's, since `Prelude` names its namespace (§4.2).
prelude_listing(#session{prelude = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    {Types, _} = ern_typecheck:prelude_names(Env),
    %% report §9.4: `Io.show` and `Io.debug` are the prelude's, typed by
    %% `io.ern`'s interface, since the table's text has no place for their
    %% requirement
    Shown = [{['Io', Name], Scheme} || Name <- [show, debug],
                                      {ok, Scheme} <- [ern_typecheck:declared_scheme(['Io'], Name,
                                                                                     Env)]],
    %% the environment holds the standard library's types too, each under
    %% its module's name; the prelude's own are unqualified
    [unicode:characters_to_binary(["type ", ern_namespace:text(QualifiedName)])
     || [_] = QualifiedName <- lists:sort(Types)]
        ++ [unicode:characters_to_binary([ern_namespace:text(QualifiedName), " : ",
                                          ern_types:format_scheme(Scheme, TypeState)])
            || {QualifiedName, Scheme} <- lists:sort(ern_typecheck:prelude_values(Env) ++ Shown)].

%% Report §11.5: each name and each type as the session writes it, the
%% names qualified and another module's types too.
browse(Text, Namespace, #session{interfaces = Interfaces, scope = Scope,
                                 prelude = Prelude} = Session) ->
    InScope = Interfaces ++ ern_prelude:stdlib_interfaces(),
    case [Interface || #interface{namespace = Found} = Interface <- InScope, Found =:= Namespace] of
        [] ->
            {'Left', <<"no module ", (without_dot(Text))/binary, " is in scope",
                       (load_suffix(Session, Text))/binary>>};
        Found ->
            #interface{types = InterfaceTypes, values = InterfaceValues} = Last = lists:last(Found),
            ScopeState = ern_typecheck:scope_state(Interfaces ++ [Last], Prelude),
            TypeState = ern_types:set_scope([], maps:values(maps:get(types, Scope, #{})), [],
                                            input_names(), ScopeState),
            Types = [unicode:characters_to_binary([type_keyword(TypeInfo), "type ",
                                                   ern_namespace:text(QualifiedName)])
                     || {QualifiedName, TypeInfo} <- lists:sort(maps:to_list(InterfaceTypes))],
            Values = [unicode:characters_to_binary(
                        [ern_namespace:text(QualifiedName), " : ",
                         ern_types:format_scheme(Scheme, TypeState)])
                      || {QualifiedName, Scheme} <- lists:sort(maps:to_list(InterfaceValues))],
            {'Right', Types ++ Values}
    end.

%% A type the session declares, as its declaration writes it.
type_line(Name, QualifiedName, Session) ->
    type_keyword(type_info(QualifiedName, Session)) ++ "type " ++ atom_to_list(Name).

%% Report §11.2: the word a type's declaration begins with before `type`,
%% as its declaration writes it; a built-in type, which the checker holds
%% as foreign under a name of one segment, is the prelude's and has none.
type_keyword(#type_info{abstract = true}) -> "abstract ";
type_keyword(#type_info{foreign = true, qualified_name = [_, _ | _]}) -> "foreign ";
type_keyword(_) -> "".

%% Report §2.3: a name as it is written, its segments between the dots,
%% or `none` for text that is no name: an empty segment, or one longer than
%% the host holds in a name, 255 characters. A trailing dot, which
%% completion leaves after a namespace, names the namespace. The host keeps
%% a name it has met for ever, so a name typed to a command is made one
%% only where it can name something: each segment met before, or the text,
%% or what stands before its last segments, a module there is a file of.
%% Otherwise it is `{unmet, Parts}`, its segments as they were typed.
segments(Session, Text) ->
    Parts = binary:split(without_dot(Text), <<".">>, [global]),
    case lists:all(fun(Part) -> Part =/= <<>> andalso byte_size(Part) =< 255 end, Parts) of
        true ->
            case lists:all(fun is_met/1, Parts) orelse names_a_module(Session, Parts) of
                true -> {ok, [binary_to_atom(Part) || Part <- Parts]};
                false -> {unmet, Parts}
            end;
        false ->
            none
    end.

is_met(Part) ->
    try binary_to_existing_atom(Part) of
        _ -> true
    catch
        error:badarg -> false
    end.

%% Whether the name, or what stands before its last segments, is a module
%% the host may not have met: one whose source the source root holds, or
%% one compiled, on the load path or the code path.
names_a_module(Session, Parts) ->
    lists:any(fun(Length) ->
                  is_module_file(Session, [binary_to_list(Part)
                                           || Part <- lists:sublist(Parts, Length)])
              end, lists:seq(length(Parts), 1, -1)).

is_module_file(#session{source_root = SourceRoot} = Session, Segments) ->
    case lists:all(fun(Segment) -> ern_namespace:component(Segment) =/= error end, Segments) of
        true ->
            Relative = ern_namespace:path(Segments),
            Beam = ern_namespace:erlang_module_text(Segments) ++ ".beam",
            filelib:is_regular(filename:join(SourceRoot, Relative ++ ".ern"))
                orelse lists:any(fun(Root) ->
                                     filelib:is_regular(filename:join(Root, Relative ++ ".erc"))
                                 end, load_path(Session))
                orelse code:where_is_file(Beam) =/= non_existing;
        false ->
            false
    end.

%% Report §11.2: every refusal the front end answers, a diagnostic among
%% them, ends with no line feed, and the shell ends each with one as it
%% says it.
without_line_feed({'Left', Text}) -> {'Left', string:trim(Text, trailing, "\n")};
without_line_feed(Answer) -> Answer.

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
module_name(Session, Text) ->
    case segments(Session, Text) of
        {ok, Namespace} ->
            case lists:all(fun(Segment) -> is_segment(atom_to_list(Segment)) end, Namespace) of
                true -> {ok, Namespace};
                false -> not_module(Text)
            end;
        %% a module's name in form, of no module there is a file of
        {unmet, Parts} ->
            case lists:all(fun(Part) -> is_segment(binary_to_list(Part)) end, Parts) of
                true -> unmet;
                false -> not_module(Text)
            end;
        none ->
            not_module(Text)
    end.

is_segment(Segment) ->
    ern_namespace:component(Segment) =/= error.

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
        none ->
            {'Left', <<"no documentation for ", Text/binary, (load_suffix(Session, Text))/binary>>}
    end.

%% Report §11.2: a name of a module the session has not loaded, but the
%% source root or the load path holds, is answered with the `:load` that
%% puts it in scope: the module the name is, or the longest that begins it.
load_suffix(Session, Text) ->
    Parts = [binary_to_list(Part) || Part <- binary:split(without_dot(Text), <<".">>, [global])],
    case load_help(Session, Parts) of
        {ok, Help} -> unicode:characters_to_binary(["; ", Help]);
        none -> <<>>
    end.

load_help(Session, Segments) ->
    Modules = [lists:sublist(Segments, Length) || Length <- lists:seq(length(Segments), 1, -1)],
    case lists:search(fun(Module) -> is_loadable(Session, Module) end, Modules) of
        {value, Module} -> {ok, [":load ", lists:join(".", Module), " puts it in scope"]};
        false -> none
    end.

%% Whether a module of these segments is not loaded and could be: its
%% source under the source root, or its compiled form on the load path.
is_loadable(#session{source_root = SourceRoot, interfaces = Interfaces} = Session, Segments) ->
    Name = lists:flatten(lists:join(".", Segments)),
    Loaded = [ern_namespace:text(Namespace)
              || #interface{namespace = Namespace} <- Interfaces
                     ++ ern_prelude:stdlib_interfaces()],
    lists:all(fun(Segment) -> ern_namespace:component(Segment) =/= error end, Segments)
        andalso not lists:member(Name, Loaded)
        andalso begin
                    Relative = ern_namespace:path(Segments),
                    filelib:is_regular(filename:join(SourceRoot, Relative ++ ".ern"))
                        orelse lists:any(fun(Root) ->
                                             filelib:is_regular(filename:join(Root,
                                                                              Relative ++ ".erc"))
                                         end, load_path(Session))
                end.

%% The documentation of a name as it is written, with its segments; none
%% for text that is no name.
page(Session, Text) ->
    case segments(Session, Text) of
        {ok, Segments} ->
            case doc_of(Session, Segments) of
                {ok, Page} -> {ok, Page, Segments};
                none -> none
            end;
        _ ->
            none
    end.

%% Report §11.2: the page for a name, as the session stands, for
%% `Shift-Tab`, the one `:doc` shows, and the version the name appeared in,
%% which the brief shows. The reader asks while an input runs, so it reads
%% the session the front end keeps rather than asking the session.
-spec documentation(binary()) -> 'None' | {'Some', {binary(), 'None' | {'Some', binary()}}}.
documentation(Text) ->
    Session = kept_session(),
    case page(Session, Text) of
        {ok, Page, Segments} ->
            {'Some', {unicode:characters_to_binary(Page), appeared(Session, Segments)}};
        none ->
            'None'
    end.

%% Appendix E.0 shape rule 6, report §11.2: the version a declaration
%% appeared in, its own `since` or, without one, its module's. Whether it
%% has one is its documentation entry's to say, not its text's.
appeared(Session, Segments) ->
    case declaring(Session, Segments) of
        {Declaring, Name} ->
            case {ern_page:declared_since(Declaring, Name), ern_page:since(Declaring)} of
                {undefined, undefined} -> 'None';
                {undefined, Version} -> {'Some', unicode:characters_to_binary(Version)};
                {Version, _} -> {'Some', unicode:characters_to_binary(Version)}
            end;
        none ->
            'None'
    end.

%% The compiled module, or the prelude, whose documentation entry a
%% documented name is, and the entry's name: a module's function, `map` of
%% `List.map`; a member of a module's type, `Point.compare` of
%% `Shape.Point.compare`; or the prelude's name.
declaring(Session, Segments) when length(Segments) >= 2 ->
    Namespace = lists:droplast(Segments),
    TypeNamespace = lists:droplast(Namespace),
    Member = lists:nthtail(length(Segments) - 2, Segments),
    Beams = [{Beam, entry_name([lists:last(Segments)])}
             || Beam <- [beam_of(Session, Namespace)], Beam =/= none]
        ++ [{Beam, entry_name(Member)}
            || TypeNamespace =/= [], Beam <- [beam_of(Session, TypeNamespace)], Beam =/= none],
    case [Found || {Beam, Name} = Found <- Beams, ern_page:declaration(Beam, Name, entry) =/= none]
    of
        [Found | _] -> Found;
        [] -> prelude_entry(Segments)
    end;
declaring(_, Segments) ->
    prelude_entry(Segments).

prelude_entry(Segments) ->
    case prelude_doc(Segments) of
        {ok, _} -> {prelude, entry_name(Segments)};
        none -> none
    end.

%% Report §11.2, §3.5: what a `.` after a value completes to. The text
%% before the last `.` is checked as an input in a module of its own that
%% does not enter the session, as `Shift-Tab`'s callee is, so a chain of
%% selections is the checker's, and a name the unfinished input binds is
%% not in scope; the fields its type selects are then the checker's too,
%% each listed with its type. A namespace checks as no value and has none.
-spec fields(binary()) -> [{'Name', binary(), 'Value', binary()}].
fields(Before) ->
    case string:split(Before, ".", trailing) of
        [Head, _] when Head =/= <<>> ->
            maybe
                %% a line being typed makes no name, as slot/1 says
                ok = stdlib_met(),
                {ok, Binds, Expr} ?= input(Head, [no_new_names]),
                {'Right', {_, #checked{type = Type, env = Env}}} ?=
                    check_module(kept_session(), ['$Fields'], {typed, <<"fields">>}, Head,
                                 input_entry(Expr), Binds),
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
    case enclosing_call(Before) of
        #enclosing{namespace = Namespace, name = Name, argument = Argument} ->
            %% a constructor's name begins with a capital (report §2.3)
            [First | _] = atom_to_list(Name),
            case not is_integer(Argument) orelse (First >= $A andalso First =< $Z) of
                true -> constructor_signature(Namespace, Name, Argument);
                false -> call_signature(Namespace, Name, Argument)
            end;
        none ->
            'None'
    end.

call_signature(Namespace, Name, Argument) ->
    Session = kept_session(),
    Text = unicode:characters_to_binary(ern_namespace:text(Namespace ++ [Name])),
    %% a callee that does not check, a name not in scope, has none, and
    %% neither has one whose declaration the checker does not hold or whose
    %% type is not a function's
    case scheme_of(Session, Text) of
        {ok, Scheme, Env} ->
            Params = parameters(Session, Namespace, Name),
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, Argument,
                                                         ern_typecheck:type_state(Env)),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
        none ->
            'None'
    end.

%% The declared type of a function's name, for its signature.
scheme_of(Session, Text) ->
    case declared_scheme(Session, Text) of
        {ok, #scheme{type = {tfn, _, _, _}}, _} = Found -> Found;
        _ -> none
    end.

%% Report §11.2, §4.9: the type of an input that is one name, as its
%% declaration writes it, which `:type` shows; any other input is checked.
-spec declared_type(#session{}, binary()) -> {'Some', binary()} | 'None'.
declared_type(Session, Input) ->
    case declared_scheme(Session, Input) of
        {ok, Scheme, Env} ->
            Text = ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env)),
            {'Some', unicode:characters_to_binary(Text)};
        none ->
            'None'
    end.

%% The declared scheme of an input that is one name, read in the session's
%% scope in a module of its own that does not enter the session, and not
%% taken as a value, which a declaration with a requirement is not without
%% a type for its variable (report §4.9).
declared_scheme(#session{interfaces = Interfaces, scope = Scope}, Text) ->
    maybe
        {ok, it, #e_var{namespace = Namespace, name = Name}} ?= input(Text),
        {ok, _, _, Env} ?= ern_typecheck:check(['$Signature'], [], Interfaces, Scope),
        {ok, Scheme} ?= ern_typecheck:declared_scheme(Namespace, Name, Env),
        {ok, Scheme, Env}
    else
        _ -> none
    end.

%% Report §11.2: a constructor's fields, as a signature, the one whose
%% value is at the cursor marked, and none where a field's name stands.
constructor_signature(Namespace, Name, Argument) ->
    Session = kept_session(),
    case named_constructor(Session, Namespace, Name) of
        {ok, #constructor_info{fields = Fields,
                               scheme = #scheme{type = {tfn, Params, _, _}} = Scheme}} ->
            %% a constructor is declared, so its signature is a head's
            Names = case Fields of
                        {named, Named} -> Named;
                        _ -> lists:duplicate(length(Params), '_')
                    end,
            MarkedIndex = case Argument of
                              {field, Field} -> field_index(Field, Names, length(Params));
                              none -> length(Params);
                              Index -> Index
                          end,
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Names, MarkedIndex,
                                                         session_type_state(Session)),
            Text = ern_namespace:text(Namespace ++ [Name]),
            {'Some', {unicode:characters_to_binary([Text, Head]),
                      unicode:characters_to_binary(Marked), unicode:characters_to_binary(Rest)}};
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
named_constructor(#session{scope = Scope, interfaces = Interfaces, prelude = Prelude}, [],
                  Name) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none -> ern_typecheck:prelude_constructor(Name, Prelude);
        QualifiedName -> constructor_info(QualifiedName, Interfaces)
    end;
named_constructor(#session{interfaces = Interfaces}, Namespace, Name) ->
    constructor_info(Namespace ++ [Name], Interfaces ++ ern_prelude:stdlib_interfaces()).

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
enclosing_call(Before) ->
    %% read and not run, so no name is made of it (slot/1)
    ok = stdlib_met(),
    Parsers = [fun ern_parser:parse_expr/2, fun ern_parser:parse_statement/2,
               fun ern_parser:parse_string/2],
    case [Enclosing || Parse <- Parsers,
                       {error, #diagnostic{incomplete = true, within = Enclosing}}
                           <- [Parse(Before, [no_new_names])],
                       Enclosing =/= undefined] of
        [Enclosing | _] -> Enclosing;
        [] -> none
    end.

%% The parameter names a function's documentation entry carries, from the
%% session's input or the module that declares it, or the prelude's; none
%% where no declaration carries them, a function value's.
parameters(Session, Namespace, Name) ->
    Beam = case session_beam(Session, Namespace, Name) of
               none when Namespace =/= [] -> beam_of(Session, Namespace);
               Found -> Found
           end,
    %% a module's function by its local name, a type's member as `Type.name`
    Keys = [entry_name([Name]) | [entry_name([lists:last(Namespace), Name]) || Namespace =/= []]],
    case Beam of
        none ->
            %% report §9.4, §9.5: a prelude function's parameters, named for
            %% their roles
            ern_prelude:parameters(Namespace ++ [Name]);
        _ ->
            {ok, {docs_v1, _, _, _, _, _, Entries}} = ern_docs:read(Beam),
            case [Params || {{function, Key, _}, _, _, _, #{params := Params}} <- Entries,
                            lists:member(atom_to_binary(Key), Keys)] of
                [Params | _] -> Params;
                [] -> none
            end
    end.

session_beam(#session{scope = Scope, beams = Beams}, Namespace, Name) ->
    Key = case Namespace of
              [] -> Name;
              [MemberOf] -> {MemberOf, Name};
              _ -> none
          end,
    case maps:get(Key, maps:get(values, Scope, #{}), none) of
        none -> none;
        QualifiedName -> declaring_beam(QualifiedName, Namespace ++ [Name], Beams)
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
        Listed -> {ok, ["# namespace ", ern_namespace:text(Segments), "\n\n",
                      [["- `", Shown, "`\n"] || Shown <- Listed]]}
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
constructor_doc(#session{scope = Scope, beams = Beams, prelude = Prelude} = Session, [Name]) ->
    case maps:get(Name, maps:get(constructors, Scope, #{}), none) of
        none ->
            case ern_typecheck:prelude_constructor(Name, Prelude) of
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
            Line = session_line(Key, QualifiedName, Session),
            Beam = declaring_beam(QualifiedName, Segments, Beams),
            {ok, ern_page:session_declaration(Beam, entry_name(Segments), [Line])}
    end.

%% Report §11.2, §11.4: a function the session declares is shown as a
%% module's page shows it, its declaration as a caller names it, in the
%% session's names; a `let`'s name has its type.
session_line(Key, QualifiedName, Session) ->
    TypeState = session_type_state(Session),
    {Namespace, Name} = case Key of
                            {MemberOf, Member} -> {[MemberOf], Member};
                            _ -> {[], Key}
                        end,
    case {scheme(QualifiedName, Session), parameters(Session, Namespace, Name)} of
        {{ok, Scheme}, Params} when is_list(Params) ->
            {Head, Marked, Rest} = ern_types:format_call(Scheme, Params, length(Params),
                                                         TypeState),
            unicode:characters_to_list([name_text(Key), Head, Marked, Rest]);
        _ ->
            scheme_line(name_text(Key), QualifiedName, Session, TypeState)
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
%% `Net.Http.Request.method`. Report §11.2: a value's declaration shows the
%% type the shell prints, `Fs.Entry` and not the page's `Entry`, and a
%% type's its own.
module_doc(Session, Segments) when length(Segments) >= 2 ->
    Namespace = lists:droplast(Segments),
    Name = lists:last(Segments),
    case entry(beam_of(Session, Namespace), entry_name([Name]),
               module_signature(Session, Segments, Namespace, Name)) of
        {ok, Page} ->
            {ok, Page};
        none when length(Segments) >= 3 ->
            [MemberOf, Member] = lists:nthtail(length(Segments) - 2, Segments),
            entry(beam_of(Session, lists:sublist(Segments, length(Segments) - 2)),
                  entry_name([MemberOf, Member]),
                  module_signature(Session, Segments, Namespace, Member));
        none ->
            none
    end;
module_doc(_, _) ->
    none.

%% The signature a module's value is shown with, its parameters as its
%% documentation names them and its type as `:type` prints it; a type's
%% entry keeps its own.
module_signature(Session, QualifiedName, Namespace, Name) ->
    Text = unicode:characters_to_binary(ern_namespace:text(QualifiedName)),
    case declared_scheme(Session, Text) of
        {ok, Scheme, Env} ->
            TypeState = ern_typecheck:type_state(Env),
            Line = case parameters(Session, Namespace, Name) of
                       Params when is_list(Params) ->
                           {Head, Marked, Rest} =
                               ern_types:format_call(Scheme, Params, length(Params), TypeState),
                           [Text, Head, Marked, Rest];
                       _ ->
                           [Text, " : ", ern_types:format_scheme(Scheme, TypeState)]
                   end,
            [unicode:characters_to_list(Line)];
        none ->
            entry
    end.

%% The compiled module behind a namespace the session can name, as bytes:
%% the one `:load` or `:reload` compiled, which is loaded from memory and
%% has no file; else the file the runner loaded it from, an `.erc`, or the
%% standard library's `.beam`. `beam_lib` takes either as a binary. A
%% module on the code path the session cannot name, the shell's own
%% libraries among them, has none (report §11.2).
beam_of(#session{beams = Beams, interfaces = Interfaces}, Namespace) ->
    case Beams of
        #{Namespace := Beam} -> Beam;
        _ ->
            IsLoaded = lists:any(fun(#interface{namespace = Known}) -> Known =:= Namespace end,
                                 Interfaces),
            beam_on_path(Namespace, IsLoaded)
    end.

%% A module's name is made an atom only where it is one already, so that a
%% name `:doc` or `Shift-Tab` is asked of, `List.filter` taken for a module,
%% makes none (report §11.2). One the session has not loaded is the
%% standard library's where its file lies in the library's directory, as
%% ern_prelude:stdlib_interfaces/0 finds the library.
beam_on_path(Namespace, IsLoaded) ->
    Text = ern_namespace:erlang_module_text(Namespace),
    Loaded = try code:which(list_to_existing_atom(Text)) catch error:badarg -> non_existing end,
    Paths = [Loaded, code:where_is_file(Text ++ ".beam")],
    case [Beam || Path <- Paths, is_list(Path),
                  IsLoaded orelse filename:basename(filename:dirname(Path)) =:= "stdlib",
                  {ok, Beam} <- [file:read_file(Path)]] of
        [] -> none;
        [Beam | _] -> Beam
    end.

entry(none, _, _) -> none;
entry(Beam, Name, Signature) -> ern_page:declaration(Beam, Name, Signature).

%% Report §11.2: a qualified name that names nothing in scope, of a module
%% the session could load, has the `:load` that puts it there as its help.
load_hinted(Session, #diagnostic{unknown_namespace = [_ | _] = Namespace,
                                 help = undefined} = Diagnostic) ->
    case load_help(Session, [atom_to_list(Segment) || Segment <- Namespace]) of
        {ok, Help} -> Diagnostic#diagnostic{help = lists:flatten(Help)};
        none -> Diagnostic
    end;
load_hinted(_Session, Diagnostic) ->
    Diagnostic.

%% Report §11.2: a typed input is the file `input`; an input from a startup
%% file is named by the file, its positions moved to the line it stands on
%% there and, on its first line, to the column it begins in, and its lines
%% quoted from the file.
diagnostic({typed, Name}, Input, Diagnostics) ->
    unicode:characters_to_binary([ern_diagnostic:format(binary_to_list(Name), Input, Diagnostic)
                                  || Diagnostic <- Diagnostics]);
diagnostic(#startup_input{file = File, line = Line, column = Column}, Input, Diagnostics) ->
    SourceText = case file:read_file(File) of
                     {ok, Read} -> Read;
                     {error, _} -> Input
                 end,
    unicode:characters_to_binary(
      [ern_diagnostic:format(ern_build:shown(binary_to_list(File)), SourceText,
                             moved(Diagnostic, Line - 1, Column - 1))
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
load(Session, Text) ->
    without_line_feed(load_named(Session, Text)).

load_named(#session{source_hashes = SourceHashes} = Session, Text) ->
    case module_name(Session, Text) of
        unmet ->
            {'Left', <<"no module ", (without_dot(Text))/binary,
                       " under the source root or on the load path\n">>};
        {ok, Namespace} ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            Standard = [Found || #interface{namespace = Found} <- ern_prelude:stdlib_interfaces()],
            case lists:member(Namespace, Standard) of
                %% report §4.2, §11.2: a standard library namespace is taken,
                %% and the module, in scope since the session began, is one
                %% the session has loaded, which is refused
                true ->
                    {'Left', <<Name/binary, " is the standard library's, in scope from the"
                               " start\n">>};
                false when is_map_key(Namespace, SourceHashes) ->
                    {'Left', <<Name/binary, " is loaded already; :reload compiles it again"
                               " when its source has changed\n">>};
                false ->
                    load(Session, Name, Namespace)
            end;
        {error, Refusal} ->
            {'Left', <<Refusal/binary, "\n">>}
    end.

%% A refusal ends in a line feed, as a diagnostic the compiler gives does,
%% since the shell prints both alike. What is loaded is kept, since
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
                        {ok, CompiledModules} ->
                            Lines = [[ern_namespace:text(Compiled), ", compiled from ",
                                      relative(SourceFile, Session)]
                                     || {Compiled, SourceFile} <- lists:reverse(Sources)],
                            with_needed(Session, CompiledModules,
                                        unicode:characters_to_binary(lists:join("\n", Lines)));
                        {error, Failed} ->
                            {'Left', iolist_to_binary(Failed)}
                    end;
                _ ->
                    {'Left', <<(unicode:characters_to_binary(ern_namespace:text(Declared)))/binary,
                               " is declared in ",
                               (unicode:characters_to_binary(relative(File, Session)))/binary,
                               ", which is not where ", Name/binary, " belongs\n">>}
            end;
        none ->
            case compiled_of(Session, Namespace) of
                {ok, File, Beam, Hash} ->
                    with_needed(Session, [{Namespace, Beam, Hash}],
                                <<Name/binary, ", from ",
                                  (unicode:characters_to_binary(relative(File, Session)))/binary>>);
                {error, Refusal} ->
                    {'Left', <<Refusal/binary, "\n">>};
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
with_sources(#session{source_root = SourceRoot, source_hashes = Loaded} = Session,
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
            More = [{Dependency, SourceFile} || Dependency <- Dependencies,
                                            not is_map_key(Dependency, Loaded),
                                            {ok, SourceFile} <- [source_of(Session, Dependency)]],
            with_sources(Session, Rest ++ More, Acc ++ [{Namespace, File}])
    end.

%% The modules loaded, after what they use that the session has not
%% loaded, and `:load`'s answer.
with_needed(Session, CompiledModules, Answer) ->
    case needed(Session, CompiledModules) of
        {ok, Needed} ->
            All = Needed ++ CompiledModules,
            case refused_compiled(Session, All) of
                none -> installed(Session, All, Answer);
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
    StdlibHash = ern_build:stdlib_hash(),
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
    {ok, #{interface := #interface{namespace = FileNamespace}, deps := DependencyHashes} = Chunk} =
        ern_interface:read(Beam),
    Name = ern_namespace:text(Namespace),
    [Name ++ "'s compiled file holds " ++ ern_namespace:text(FileNamespace)
     ++ "; build it again from its source root" || FileNamespace =/= Namespace]
        ++ [Name ++ " was compiled against another standard library; build " ++ Name ++ " again"
            || not lists:member(maps:get(stdlib, Chunk, none), [none, StdlibHash])]
        ++ [Name ++ " was compiled against another " ++ ern_namespace:text(Dependency)
            ++ "; build " ++ Name ++ " again"
            || {Dependency, Hash} <- DependencyHashes,
               [Interface | _] <- [held_interfaces(Dependency, Interfaces)],
               ern_interface:hash(Interface) =/= Hash].

held_interfaces(Namespace, Interfaces) ->
    [Interface || #interface{namespace = Found} = Interface <- Interfaces, Found =:= Namespace].

%% The modules installed and their bindings evaluated, and `:load`'s answer.
installed(Session, All, Answer) ->
    Session1 = install(Session, All),
    case initialize(in_order(All)) of
        ok ->
            {'Right', {keep_session(Session1), Answer}};
        {fault, Site, Cause} ->
            withdraw_all(All),
            {'Left', <<(binding_fault(Site, Cause))/binary, "; nothing was loaded\n">>}
    end.

%% Report §8.5, §11.2: the modules in the order their bindings are
%% evaluated, each after those it depends on.
in_order(CompiledModules) ->
    ErlangModules = [ern_namespace:erlang_module(Namespace)
                     || {Namespace, _, _} <- CompiledModules],
    ByErlangModule = maps:from_list(lists:zip(ErlangModules, CompiledModules)),
    [maps:get(ErlangModule, ByErlangModule) || ErlangModule <- ern_rt:ordered(ErlangModules)].

%% Report §11.2: the modules a failed `:load` or `:reload` had loaded, each
%% gone with the processes its bindings started, which end as a reload ends
%% those of a previous version, and with the values its bindings stored
%% (§8.5), so that the session is as it was.
withdraw_all(CompiledModules) ->
    [withdraw(Namespace, Beam) || {Namespace, Beam, _} <- CompiledModules],
    ok.

withdraw(Namespace, Beam) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    code:delete(ErlangModule),
    end_unloaded([Pid || {Pid, _} <- ern_rt:live(), erlang:check_process_code(Pid, ErlangModule)]),
    code:purge(ErlangModule),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    lists:foreach(fun persistent_term:erase/1, let_keys(ErlangModule, Interface)).

%% The keys §8.5's store holds a module's top-level lets under, as its
%% interface lists them.
let_keys(ErlangModule, #interface{lets = Lets}) ->
    [{ErlangModule, ern_emitter:function_name(undefined, lists:last(QualifiedName))}
     || QualifiedName <- Lets].

%% Report §7.3, §11.2: each process ends with its code unloaded, and is
%% waited for before its code is purged, since the purge kills one that has
%% not yet taken the signal, which would end `Killed`.
end_unloaded(Pids) ->
    MonitorRefs = [erlang:monitor(process, Pid) || Pid <- Pids],
    lists:foreach(fun(Pid) -> exit(Pid, {ern, code_unloaded}) end, Pids),
    lists:foreach(fun(MonitorRef) -> receive {'DOWN', MonitorRef, process, _, _} -> ok end end,
                  MonitorRefs).

%% Report §11.2, §8.5: the top-level bindings of each module, dependencies
%% first, each module's evaluated in a process of the shell's own, whose
%% fault is this answer's and not a fault report's; ok, or the module whose
%% binding faulted and its cause.
initialize([]) ->
    ok;
initialize([{Namespace, _, _} | Rest]) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
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
                            Class:Error:Stack ->
                                {fault, ern_rt:site(), fault_cause(Class, Error, Stack)}
                        end,
               Self ! {Ref, Result}
           end,
    %% monitored from its spawn, so that its end is known however soon it
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
kept_values_line(Site, Cause) ->
    <<(binding_fault(Site, Cause))/binary, "; it and the bindings after it keep the values of the"
      " previous version">>.

binding_fault(Site, Cause) ->
    <<Site/binary, " faulted: ", (ern_show:controls(Cause, line))/binary>>.

%% Report §11.2: what the modules use that the session has not loaded,
%% each found as the runner finds it, by namespace on the load path, and
%% loaded before them, the modules it uses first.
needed(Session, CompiledModules) ->
    Compiled = [Namespace || {Namespace, _, _} <- CompiledModules],
    lists:foldl(fun({_, Beam, _}, Found) -> needed(Session, Beam, Found, Compiled) end, {ok, []},
                CompiledModules).

%% What one module uses that neither the session nor the modules compiled
%% with it, Compiled, provide.
needed(_Session, _Beam, {error, _} = Error, _Compiled) ->
    Error;
needed(#session{source_hashes = Loaded} = Session, Beam, {ok, _} = Found, Compiled) ->
    {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
    lists:foldl(fun(_, {error, _} = Error) ->
                        Error;
                   ({Namespace, _}, {ok, Acc}) ->
                        case is_map_key(Namespace, Loaded) orelse lists:member(Namespace, Compiled)
                             orelse lists:keymember(Namespace, 1, Acc) of
                            true -> {ok, Acc};
                            false -> needed_one(Session, Namespace, Acc, Compiled)
                        end
                end, Found, DependencyHashes).

needed_one(Session, Namespace, Acc, Compiled) ->
    case compiled_of(Session, Namespace) of
        {ok, _, Beam, Hash} ->
            case needed(Session, Beam, {ok, Acc}, Compiled) of
                {ok, Acc1} -> {ok, Acc1 ++ [{Namespace, Beam, Hash}]};
                Error -> Error
            end;
        {error, Refusal} ->
            {error, <<Refusal/binary, "\n">>};
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
reload(Session) ->
    without_line_feed(reload_changed(Session)).

reload_changed(#session{source_hashes = SourceHashes} = Session) ->
    Sources = [{Namespace, LoadedHash, source_of(Session, Namespace)}
               || {Namespace, LoadedHash} <- lists:sort(maps:to_list(SourceHashes))],
    ChangedSources = [{Namespace, File}
               || {Namespace, LoadedHash, {ok, File}} <- Sources,
                  {ok, Hash} <- [source_hash(File)],
                  Hash =/= LoadedHash],
    SourcelessLines = sourceless(Session, [Namespace || {Namespace, _, none} <- Sources]),
    case ChangedSources of
        [] ->
            {'Right', {Session, [<<"no source has changed">> | SourcelessLines]}};
        _ ->
            case compile_all(Session, ChangedSources) of
                {ok, Needed, Compiled} -> reloaded(Session, Needed, Compiled, SourcelessLines);
                {error, Text} -> {'Left', iolist_to_binary([Text, "nothing was reloaded\n"])}
            end
    end.

%% Report §11.2: the changed modules loaded again, after what they use that
%% the session had not loaded, which is loaded as `:load` loads it.
reloaded(Session, Needed, Compiled, SourcelessLines) ->
    Session1 = install(Session, Needed),
    case initialize(Needed) of
        ok ->
            {Session2, Lines} = lists:foldl(fun reload_one/2, {Session1, []}, Compiled),
            Faulted = case initialize(in_order(Compiled)) of
                          ok -> [];
                          {fault, Site, Cause} -> [kept_values_line(Site, Cause)]
                      end,
            {'Right', {keep_session(Session2), lists:reverse(Lines) ++ Faulted ++ SourcelessLines}};
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
%% it, with each they have come to use that the session has not loaded and
%% whose source the source root holds, as `:load` compiles it; and, while
%% one's interface differs from the one the session holds, every loaded
%% module that uses it compiled again with them, from its source. The
%% modules compiled, with what they use that the session has not loaded
%% and the source root does not hold; or why they cannot all be.
compile_all(Session, ChangedSources) ->
    case compile_in_order(Session, with_sources(Session, ChangedSources, [])) of
        {ok, CompiledModules} ->
            case stale_users(Session, ChangedSources, CompiledModules) of
                [] ->
                    case needed(Session, CompiledModules) of
                        {ok, Needed} -> {ok, Needed, CompiledModules};
                        Error -> Error
                    end;
                Users ->
                    Sources = [{Namespace, source_of(Session, Namespace)} || Namespace <- Users],
                    case [Namespace || {Namespace, none} <- Sources] of
                        [] ->
                            More = [{Namespace, File} || {Namespace, {ok, File}} <- Sources],
                            compile_all(Session, ChangedSources ++ More);
                        SourcelessUsers ->
                            {error, [unicode:characters_to_binary(
                                       [ern_namespace:text(Namespace),
                                        " uses a module whose interface changed,"
                                        " and the source root holds no source of it\n"])
                                     || Namespace <- SourcelessUsers]}
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
            Compile = fun(Module, {Interfaces, Failed}) ->
                          compiled_in_order(Session, Module, Interfaces, Failed)
                      end,
            {Compiled, _} = lists:mapfoldl(Compile, {loaded_interfaces(Session), []}, Ordered),
            case [Text || {_, {error, Text}} <- Compiled] of
                [] ->
                    {ok, [{Namespace, Beam, Hash} || {Namespace, {ok, _, Beam, Hash}} <- Compiled]};
                Texts -> {error, Texts}
            end
    catch
        throw:{cli_error, Message} ->
            {error, [unicode:characters_to_binary([Message, "\n"])]};
        throw:{errors, FailedFile, Diagnostics} ->
            {ok, SourceText} = file:read_file(FailedFile),
            {error, [unicode:characters_to_binary(
                       [ern_diagnostic:format(ern_build:shown(FailedFile), SourceText, Diagnostic)
                        || Diagnostic <- Diagnostics])]}
    end.

%% Report §11.2: one module of a `:load`, compiled where every module it
%% uses did, and said not to be loaded where one did not; the build's
%% advice to compile that one first does not apply in the shell.
compiled_in_order(Session, #build_module{namespace = Namespace, file = File,
                                         dependencies = Dependencies}, Interfaces, Failed) ->
    case [Dependency || Dependency <- Dependencies, lists:member(Dependency, Failed)] of
        [Dependency | _] ->
            Text = unicode:characters_to_binary([ern_namespace:text(Namespace),
                                                 " is not loaded, since ",
                                                 ern_namespace:text(Dependency),
                                                 " does not compile\n"]),
            {{Namespace, {error, Text}}, {Interfaces, [Namespace | Failed]}};
        [] ->
            case compile_source(Session, File, Interfaces) of
                {ok, _, Beam, _} = Ok ->
                    {ok, #{interface := Interface}} = ern_interface:read(Beam),
                    {{Namespace, Ok}, {Interfaces#{Namespace => Interface}, Failed}};
                Error ->
                    {{Namespace, Error}, {Interfaces, [Namespace | Failed]}}
            end
    end.

%% The loaded modules, outside those compiled, that use a compiled module
%% whose interface is not the one the session holds.
stale_users(#session{source_hashes = Loaded} = Session, Set, CompiledModules) ->
    LoadedInterfaces = loaded_interfaces(Session),
    InterfaceChanged = [Namespace || {Namespace, Beam, _} <- CompiledModules,
                            {ok, #{interface := Interface}} <- [ern_interface:read(Beam)],
                            not is_map_key(Namespace, LoadedInterfaces)
                                orelse ern_interface:hash(maps:get(Namespace, LoadedInterfaces))
                                       =/= ern_interface:hash(Interface)],
    UsesChanged = fun(Namespace) ->
                      lists:any(fun({Dependency, _}) ->
                                        lists:member(Dependency, InterfaceChanged)
                                end, dependency_hashes(Session, Namespace))
                  end,
    [Namespace || Namespace <- lists:sort(maps:keys(Loaded)),
                  not lists:keymember(Namespace, 1, Set), UsesChanged(Namespace)].

%% The dependencies a loaded module was compiled against, with their
%% interfaces' hashes, as its compiled form records them: the session's, or
%% the file it was loaded from.
dependency_hashes(#session{beams = Beams}, Namespace) ->
    Beam = case Beams of
               #{Namespace := Found} -> Found;
               _ ->
                   {ok, Found} = file:read_file(code:which(ern_namespace:erlang_module(Namespace))),
                   Found
           end,
    {ok, #{deps := DependencyHashes}} = ern_interface:read(Beam),
    DependencyHashes.

%% The interfaces of the modules the session has loaded, by namespace.
loaded_interfaces(#session{interfaces = Interfaces, source_hashes = SourceHashes}) ->
    maps:from_list([{Namespace, Interface}
                    || #interface{namespace = Namespace} = Interface <- Interfaces,
                       is_map_key(Namespace, SourceHashes)]).

%% Report §11.2: a module the session had loaded, loaded again, and one it
%% had not, which a changed module has come to use, loaded as `:load`
%% loads it.
reload_one({Namespace, Beam, Hash}, {#session{source_hashes = SourceHashes} = Session, Lines})
  when not is_map_key(Namespace, SourceHashes) ->
    {ok, File} = source_of(Session, Namespace),
    Line = unicode:characters_to_binary([ern_namespace:text(Namespace), ", compiled from ",
                                         relative(File, Session)]),
    {install(Session, Namespace, Beam, Hash), [Line | Lines]};
reload_one({Namespace, Beam, Hash}, {Session, Lines}) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
    {Ended, Session1} = case erlang:check_old_code(ErlangModule) of
                            true -> end_previous(Session, ErlangModule);
                            false -> {{[], []}, Session}
                        end,
    code:purge(ErlangModule),
    dropped_lets(Session1, Namespace, Beam),
    Session2 = install(Session1, Namespace, Beam, Hash),
    Waiting = in_previous(Session2, ErlangModule),
    {Session2, waiting_line(Name, Waiting) ++ ended_lines(Name, Ended)
               ++ [<<Name/binary, ", compiled again">> | Lines]}.

%% Report §8.5, §11.2: the values of the lets the version just purged
%% declared and the one after it no longer does are erased, since nothing
%% reads them now; those the version being replaced declares and the new
%% one does not are kept until the reload that purges it, since a process
%% or a binding still in it may read them.
dropped_lets(#session{interfaces = Interfaces}, Namespace, Beam) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    lists:foreach(fun persistent_term:erase/1, kept({dropped_lets, ErlangModule}, [])),
    [Replaced] = [Interface || #interface{namespace = Found} = Interface <- Interfaces,
                               Found =:= Namespace],
    {ok, #{interface := New}} = ern_interface:read(Beam),
    keep({dropped_lets, ErlangModule},
         let_keys(ErlangModule, Replaced) -- let_keys(ErlangModule, New)).

%% Report §11.2: what the reload that purged the previous version did,
%% `Geo.Shape: the previous version is unloaded; the reload ended the
%% process spawned at input 4:1 and forgot the binding f`.
ended_lines(_, {[], []}) ->
    [];
ended_lines(Name, {Processes, Bindings}) ->
    Done = [["ended ", processes_at(Processes)] || Processes =/= []]
        ++ [["forgot ", bindings_named(Bindings)] || Bindings =/= []],
    [unicode:characters_to_binary([Name, ": the previous version is unloaded; the reload ",
                                   lists:join(" and ", Done)])].

%% Report §11.2: what holds the version a reload replaced, and what the
%% next reload does to it, `Geo.Shape: the previous version is held by the
%% binding f; the next reload of Geo.Shape forgets it`.
waiting_line(_, {[], []}) ->
    [];
waiting_line(Name, {Processes, Bindings}) ->
    Holders = lists:join(" and by ", [processes_at(Processes) || Processes =/= []]
                                     ++ [bindings_named(Bindings) || Bindings =/= []]),
    It = counted(Processes ++ Bindings, "it", "them"),
    Fate = case {Processes, Bindings} of
               {_, []} -> ["ends ", It];
               {[], _} -> ["forgets ", It];
               _ -> ["ends ", counted(Processes, "the process", "the processes"),
                     " and forgets ", counted(Bindings, "the binding", "the bindings")]
           end,
    [unicode:characters_to_binary([Name, ": the previous version is held by ", Holders,
                                   "; the next reload of ", Name, " ", Fate])].

%% Processes by their spawn sites (§6.9) and bindings by their names, the
%% last two of a list joined by `and`.
processes_at(Sites) ->
    [counted(Sites, "the process", "the processes"), " spawned at ", listed(Sites)].

bindings_named(Names) ->
    [counted(Names, "the binding", "the bindings"), " ", listed(Names)].

counted([_], One, _) -> One;
counted(_, _, Many) -> Many.

listed([Item]) -> Item;
listed(Items) -> [lists:join(", ", lists:droplast(Items)), " and ", lists:last(Items)].

%% Report §11.2: what is left in the version a reload replaced, the spawn
%% sites (§6.9) of its processes and the names of its bindings.
in_previous(Session, ErlangModule) ->
    {[Site || {Pid, Site} <- ern_rt:live(), erlang:check_process_code(Pid, ErlangModule)],
     [atom_to_binary(Name) || {Name, _} <- bindings_of(Session, ErlangModule)]}.

%% Report §7.3, §11.2: the processes still in it end with the cause the
%% report gives them, a fault reported as every fault is, and the bindings
%% that hold a function of it are forgotten.
end_previous(#session{scope = Scope} = Session, ErlangModule) ->
    Processes = [{Pid, Site} || {Pid, Site} <- ern_rt:live(),
                                erlang:check_process_code(Pid, ErlangModule)],
    end_unloaded([Pid || {Pid, _} <- Processes]),
    Bindings = bindings_of(Session, ErlangModule),
    Values = maps:without([Key || {_, Key} <- Bindings], maps:get(values, Scope, #{})),
    {{[Site || {_, Site} <- Processes], [atom_to_binary(Name) || {Name, _} <- Bindings]},
     Session#session{scope = Scope#{values => Values}}}.

%% Report §11.2: the session's bindings that run a version of the module
%% other than its current one: before a reload installs its version, the
%% one the reload purges; after, the one it replaced. A binding taken from
%% a version is so listed by the reload that replaces the version and
%% forgotten by the one that purges it, and no other.
bindings_of(#session{scope = Scope}, ErlangModule) ->
    Current = ErlangModule:module_info(md5),
    Previous = fun({HeldModule, Version}) ->
                   HeldModule =:= ErlangModule
                       andalso Version =/= current andalso Version =/= Current
               end,
    Uses = uses(),
    [{name_atom(Key), Key}
     || {Key, QualifiedName} <- maps:to_list(maps:get(values, Scope, #{})),
        lists:any(Previous, functions_run(value_of(QualifiedName), Uses))].

%% The functions a value can run: those it holds, and those the values of
%% the session's modules it reaches hold, since a function of an input
%% reads the bindings it names from their holders when it runs.
functions_run(Value, Uses) ->
    Own = held_functions(Value, []),
    Reached = reached([Held || {Held, _} <- Own, is_session_module(Held)], Uses, #{}),
    Own ++ lists:append([held_functions(Stored, [])
                         || Module <- maps:keys(Reached), is_map_key(Module, Uses),
                            {_, Stored} <- stored(Module)]).

name_atom({_, Name}) -> Name;
name_atom(Name) -> Name.

value_of(QualifiedName) ->
    ErlangModule = ern_namespace:erlang_module(lists:droplast(QualifiedName)),
    persistent_term:get({ErlangModule, lists:last(QualifiedName)}, undefined).

%% Each module loaded, in order, and in scope by its namespace.
install(Session, CompiledModules) ->
    lists:foldl(fun({Namespace, Beam, Hash}, Acc) ->
                    install(Acc, Namespace, Beam, Hash)
                end, Session, CompiledModules).

install(#session{interfaces = Interfaces, source_hashes = SourceHashes} = Session, Namespace, Beam,
        Hash) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    {module, ErlangModule} = code:load_binary(ErlangModule, atom_to_list(ErlangModule), Beam),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    Others = [Other || #interface{namespace = Found} = Other <- Interfaces, Found =/= Namespace],
    Session#session{interfaces = Others ++ [Interface],
                    source_hashes = SourceHashes#{Namespace => Hash},
                    beams = maps:put(Namespace, Beam, Session#session.beams)}.

%% Report §11.2: a module compiled against the modules the session has
%% loaded, as Interfaces holds them, a dependency `:load` compiled in
%% memory among them.
compile_source(#session{source_root = SourceRoot} = Session, File, Interfaces) ->
    case ern_build:compile_source(File, SourceRoot, load_path(Session), Interfaces) of
        {ok, Namespace, Beam, Hash} ->
            {ok, Namespace, Beam, Hash};
        {refused, Text} ->
            {error, unicode:characters_to_binary([Text, "\n"])};
        {error, FailedFile, Diagnostics} ->
            {ok, SourceText} = file:read_file(FailedFile),
            %% report §11.5: the file named from the working directory
            {error, unicode:characters_to_binary(
                      [ern_diagnostic:format(ern_build:shown(FailedFile), SourceText, Diagnostic)
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

%% Report §11.2, §11.8: a module's compiled form on the load path, or
%% none; one that cannot be read is refused with the file and the host's
%% reason, as the build refuses a file it cannot read.
compiled_of(Session, Namespace) ->
    Relative = ern_build:module_path(Namespace) ++ ".erc",
    case [Candidate || Dir <- load_path(Session), Candidate <- [filename:join(Dir, Relative)],
                       filelib:is_regular(Candidate)] of
        [File | _] ->
            case file:read_file(File) of
                {ok, Beam} ->
                    case ern_interface:read(Beam) of
                        {ok, #{source_hash := Hash}} -> {ok, File, Beam, Hash};
                        {error, _} -> none
                    end;
                {error, Error} ->
                    {error, unicode:characters_to_binary([ern_build:bytes_text(File), ": ",
                                                          file:format_error(Error)])}
            end;
        [] ->
            none
    end.

source_hash(File) ->
    case file:read_file(File) of
        {ok, SourceText} -> {ok, crypto:hash(sha256, SourceText)};
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

-spec to_screen(binary()) -> 'Unit' | ok | {error, term()}.
to_screen(Bytes) ->
    case persistent_term:get({?MODULE, screen}, undefined) of
        undefined -> file:write(standard_io, Bytes);
        Address -> ern_rt:send(Address, shown(Bytes))
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

%% Report §11.2: the name an input binds is the session's from then on. Its
%% value is held by a module of its own, as a module's own value is
%% (§8.5's store), so a later input reads it with the call the emitter
%% already makes for another module's value.
bind(Session, declarations, _Namespace, _Value, _Type, _Env, Interface) ->
    joined(Session, Interface);
bind(Session, it, _Namespace, Value, Type, Env, _Interface) ->
    case is_open(Type, Env) of
        true -> Session;
        false -> bound(Session, [{it, Value, Type}], Env)
    end;
bind(Session, {names, Names}, _Namespace, Value, Type, Env, _Interface) ->
    bound(Session, components(Names, Value, Type, Env), Env);
bind(Session, {lambda, Name, Scheme}, _Namespace, Value, _Type, Env, _Interface) ->
    bound(Session, [{Name, Value, Scheme}], Env);
bind(Session, {name, Name}, _Namespace, Value, Type, Env, _Interface) ->
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

%% Report §11.2: whether the input leaves `it` as it was, its value's type
%% not being determined by the input itself.
-spec leaves_it_unchanged(#checked{}) -> boolean().
leaves_it_unchanged(#checked{binds = it, type = Type, env = Env}) -> is_open(Type, Env);
leaves_it_unchanged(#checked{}) -> false.

%% Report §11.2: a value whose type its own input did not settle is
%% printed but not bound, since a scheme with a variable of that input's
%% type state means nothing to the inputs after it. A named binding is
%% refused outright when it is checked; `it` is the one this can still
%% reach, and `declared/1` says that it was not bound.
is_open(Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    ern_types:free_variables(ern_types:substitute(Type, TypeState), TypeState) =/= [].

%% The names an input binds, held by one module, a getter for each, which
%% needs the session's modules whose functions the values hold and whose
%% types their types name.
bound(Session, [], _Env) ->
    Session;
bound(#session{last_holder = LastHolder} = Session, Bindings, Env) ->
    {HolderNamespace, Session1} =
        case free_namespace(holder) of
            {ok, Freed} ->
                {Freed, Session};
            none ->
                {[list_to_atom("$Bindings" ++ integer_to_list(LastHolder + 1))],
                 Session#session{last_holder = LastHolder + 1}}
        end,
    ErlangModule = ern_namespace:erlang_module(HolderNamespace),
    TypeState = ern_typecheck:type_state(Env),
    [persistent_term:put({ErlangModule, Name}, Value) || {Name, Value, _} <- Bindings],
    Names = [Name || {Name, _, _} <- Bindings],
    {module, ErlangModule} =
        code:load_binary(ErlangModule, atom_to_list(ErlangModule), holder(ErlangModule, Names)),
    Values = maps:from_list([{HolderNamespace ++ [Name], binding_scheme(Type, TypeState)}
                             || {Name, _, Type} <- Bindings]),
    Interface = #interface{namespace = HolderNamespace, values = Values,
                           lets = [HolderNamespace ++ [Name] || Name <- Names]},
    FunctionModules = lists:foldl(fun({_, Value, _}, Acc) -> fun_modules(Value, Acc) end, [],
                                  Bindings),
    Needs = [HeldModule || HeldModule <- FunctionModules, is_session_module(HeldModule)]
        ++ mentions(Interface, HolderNamespace),
    Keys = [{ErlangModule, Name} || Name <- Names],
    set_uses(maps:put(ErlangModule, {HolderNamespace, lists:usort(Needs), Keys}, uses())),
    joined(Session1, Interface).

%% A bound name's scheme: a generalized `let`'s own, or its type alone.
binding_scheme(#scheme{} = Scheme, _TypeState) -> Scheme;
binding_scheme(Type, TypeState) -> ern_types:monomorphic(ern_types:substitute(Type, TypeState)).

%% Report §11.2: the session after an input has answered, what nothing
%% reaches any more let go, in the session's own process.
-spec collect(#session{}) -> #session{}.
collect(Session) ->
    keep_session(collected(Session)).

%% Report §11.2: the session's modules are the holders of what inputs
%% bound, the inputs that declared, and the inputs whose value holds one of
%% their functions. One is kept while the session can reach it, and let go
%% when it cannot: its values, its code, its interface, and its number,
%% which a later holder or input takes (report §2.3). What reaches one is a
%% name in the session's scope, a module whose old code a process is still
%% inside, and, from either, what that module needs (uses/0). A module whose
%% old code a process is inside is purged at a later collection, a holder
%% as an input, and its values are let go once it is purged, since that
%% process may still read them.
%% The session collects in its own process, once an input has answered
%% (collect/1), so that an input killed while it runs has let nothing go
%% that the session still names.
collected(#session{interfaces = Interfaces, scope = Scope, beams = Beams} = Session) ->
    Uses = uses(),
    Unpurged = kept(unpurged, []),
    Old = [ern_namespace:erlang_module(Namespace) || Namespace <- Unpurged],
    Named = [ern_namespace:erlang_module([hd(QualifiedName)])
             || Which <- [values, types, constructors],
                QualifiedName <- maps:values(maps:get(Which, Scope, #{})),
                is_session_segment(hd(QualifiedName))],
    Live = reached(Named ++ Old, Uses, #{}),
    Dead = [Namespace || ErlangModule := {Namespace, _, _} <- Uses,
                         not is_map_key(ErlangModule, Live)],
    lists:foreach(fun(Namespace) -> code:delete(ern_namespace:erlang_module(Namespace)) end, Dead),
    Purgeable = fun(Namespace) -> code:soft_purge(ern_namespace:erlang_module(Namespace)) end,
    {Purged, StillRun} = lists:partition(Purgeable, Unpurged ++ Dead),
    [persistent_term:erase(Key) || Namespace <- Purged,
                                   {Key, _} <- stored(ern_namespace:erlang_module(Namespace))],
    keep(unpurged, StillRun),
    keep(free, kept(free, []) ++ Purged),
    forget_uses([ern_namespace:erlang_module(Namespace) || Namespace <- Purged]),
    Kept = [Interface || #interface{namespace = Namespace} = Interface <- Interfaces,
                         not lists:member(Namespace, Dead)],
    Session#session{interfaces = Kept, beams = maps:without(Dead, Beams)}.

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
    lists:usort([ern_namespace:erlang_module([Atom]) || Atom <- atoms(Term, []), Atom =/= Own,
                                                      is_session_segment(Atom)]).

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

%% Whether a namespace segment is one the session made (report §2.3).
is_session_segment(Segment) ->
    case atom_to_list(Segment) of
        "$Bindings" ++ _ -> true;
        "$Input" ++ _ -> true;
        _ -> false
    end.

%% Whether an Erlang module is a session module, its name the one
%% ern_namespace gives a holder's or an input's namespace.
is_session_module(ErlangModule) ->
    Name = atom_to_list(ErlangModule),
    lists:any(fun(Segment) -> lists:prefix(ern_namespace:erlang_module_text([Segment]), Name) end,
              ['$Bindings', '$Input']).

%% What each session module needs of the others, by the module: the
%% namespace it is, the session's modules its code calls, whose types its
%% interface names, and whose functions its values hold, and the keys its
%% top-level bindings are stored under.
uses() ->
    kept(uses, #{}).

set_uses(Uses) ->
    keep(uses, Uses).

%% The modules let go: what each needed, and an input's name, which goes
%% with its uses.
forget_uses(ErlangModules) ->
    set_uses(maps:without(ErlangModules, uses())),
    lists:foreach(fun(ErlangModule) ->
                      ets:delete(?MODULE, {input_name, ErlangModule}),
                      ets:delete(?MODULE, {printed_name, ErlangModule})
                  end, ErlangModules).

%% Report §6.9, §11.2: the site of a spawn an input's expression makes, the
%% input's name as its diagnostics give it, `input 3`, and the line. The
%% name is kept beside the module's uses and goes with them, since the
%% module's number is given to a later input once it is purged. It is a
%% row of its own, since every spawn of the input reads it.
-spec input_site(atom(), pos_integer()) -> binary().
input_site(ErlangModule, Line) ->
    InputName = ets:lookup_element(?MODULE, {input_name, ErlangModule}, 2),
    <<InputName/binary, ":", (integer_to_binary(Line))/binary>>.

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
    %% report §11: the host's compiler takes nothing from the environment
    {ok, _, Beam} = compile:noenv_forms([erl_syntax:revert(Form) || Form <- Forms],
                                        [return_errors]),
    Beam.

%% Report §11.2: whether the input is an expression, which binds `it`, and
%% not a `let` or declarations, which `:type` refuses.
-spec is_expression(#checked{}) -> boolean().
is_expression(#checked{binds = Binds}) ->
    Binds =:= it.

%% Report §11.2: what an input declares, a line for each, in the order they
%% were written. A value is its name and its type, a type its keyword and
%% its name.
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
    [unicode:characters_to_binary([atom_to_list(BoundName), " : ",
                                   ern_types:format(BoundType, TypeState)])
     || {BoundName, BoundType} <- lists:zip(Names, Types)];
declared(#checked{binds = {lambda, Name, Scheme}, env = Env}) ->
    TypeState = ern_typecheck:type_state(Env),
    [unicode:characters_to_binary([atom_to_list(Name), " : ",
                                   ern_types:format_scheme(Scheme, TypeState)])];
declared(#checked{binds = {name, Name}} = Checked) ->
    [<<(atom_to_binary(Name))/binary, " : ", (type_text(Checked))/binary>>].

kind(#type_declaration{}) -> <<"type">>;
kind(#abstract_declaration{}) -> <<"abstract type">>;
kind(#foreign_type_declaration{}) -> <<"foreign type">>;
kind(#fn_declaration{}) -> value;
kind(#foreign_fn_declaration{}) -> value;
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
declared_name(#type_declaration{name = Name}) -> {[], Name};
declared_name(#abstract_declaration{declaration = #type_declaration{name = Name}}) -> {[], Name};
declared_name(#foreign_type_declaration{name = Name}) -> {[], Name}.

local_name([], Name) -> atom_to_list(Name);
local_name([MemberOf], Name) -> [atom_to_list(MemberOf), ".", atom_to_list(Name)].
