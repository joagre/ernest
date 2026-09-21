%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. An input is a module
%% of its own, `Input<n>`, checked against the load path and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
-module(ern_shell).

-export([loaded/1, start/0, program/0, startup_files/0, history_file/0,
         needs_more/1, check/3,
         type_text/1, declared/1, run/3,
         show/3]).
-export([bindings/1, forget/2, browse/2, doc/2, names/0, context/1]).
-export([deaths/1, mine/0, faults/0, processes/0, load/2, reload/1, output/1]).
-export([is_terminal/0, write/1, screen/1, to_screen/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-define(UNIT, {tcon, ['Unit'], []}).

%% The session so far: the roots to look in, the count of inputs seen, the
%% interfaces of the modules behind the session, and the scope those
%% modules make (report §11.2), which the checker takes as its fourth
%% argument.
-record(env, {roots = [], source_root = ".", n = 0, ifaces = [], session = #{}, beams = #{},
              modules = #{}}).
%% modules: the namespace of a module the session has loaded, to the hash
%% of the source it was compiled from, which `:reload` compares (§11.2)
%% beams: the namespace of an input that declared, to its compiled module,
%% which `:doc` reads the documentation of (report §11.2, §11.4)
%% A checked input: the module it became, its typed tree, its type.
-record(checked, {ns, typed, decls, iface, env, type, binds}).
%% binds: the name a `let` binds, `it` for an expression, or `decls`
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
%% not entered, and nothing where the shell was started with no file. The
%% shell monitors what it gets back (§6.9), so a fault in it is seen.
-spec program() -> {'Some', pid()} | 'None'.
program() ->
    case persistent_term:get({?MODULE, loaded}, #{}) of
        #{entry := {Mod, Fn, Site}} ->
            {'Some', ern_rt:spawn('Local', fun() -> Mod:Fn() end, Site)};
        _ ->
            'None'
    end.

%% Report §11.2, §8.1: where the startup files are, the person's first
%% and then the node's. The shell reads them itself, in Ernest: only
%% where they are is the host's to say.
-spec startup_files() -> [binary()].
startup_files() ->
    What = persistent_term:get({?MODULE, loaded}, #{}),
    [unicode:characters_to_binary(File) || File <- maps:get(startups, What, [])].

%% Report §11.2: where the person's history is kept, and none where the
%% environment names no home. The shell does the reading and the writing
%% itself, in Ernest.
-spec history_file() -> 'None' | {'Some', binary()}.
history_file() ->
    What = persistent_term:get({?MODULE, loaded}, #{}),
    case maps:get(history, What, none) of
        none -> 'None';
        File -> {'Some', unicode:characters_to_binary(File)}
    end.

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
%% text, as `ernc` shows it, under the name of where the input came from:
%% `input` for one that was typed, the file's path for one from a startup
%% file.
-spec check(#env{}, binary(), binary()) ->
          {'Left', binary()} | {'Right', {#env{}, #checked{}}}.
check(#env{n = N} = Env, From, Input) ->
    Ns = [list_to_atom("Input" ++ integer_to_list(N + 1))],
    case input(Input) of
        {ok, Binds, Expr} ->
            checked(check_module(Env#env{n = N + 1}, Ns, From, Input, entry(Expr), Binds));
        {decls, Decls} ->
            checked(check_module(Env#env{n = N + 1}, Ns, From, Input, Decls, decls));
        {error, Diag} ->
            {'Left', diagnostic(From, Input, [Diag])}
    end.

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
                {ok, [#let_decl{owner = undefined, name = Name, body = Body}]} -> {ok, Name, Body};
                {ok, Decls} -> declarations(Decls);
                {error, DeclDiag} -> {error, which(Text, Diag, DeclDiag)}
            end
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
    case [P || #let_decl{owner = undefined, pos = P} <- Decls] of
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

%% `export fn main() -> a with m = <the input>`, the entry point of §8.1.
entry(Expr) ->
    [#fn_decl{pos = {1, 1, {1, 1}}, export = true, name = main, params = [], body = Expr}].

check_module(#env{ifaces = Ifaces, session = Session} = Env, Ns, From, Input, Decls, Binds) ->
    case ern_typecheck:check(Ns, Decls, Ifaces, Session) of
        {ok, Typed, Iface, TEnv} ->
            {'Right', {Env, #checked{ns = Ns, typed = Typed, decls = Decls, iface = Iface,
                                     env = TEnv, type = input_type(Typed, Binds),
                                     binds = Binds}}};
        {error, Diags} ->
            {'Left', diagnostic(From, Input, Diags)}
    end.

%% An input that declares has no value; report §11.2 prints what it
%% declared, as an input of type Unit prints nothing.
input_type(_Typed, decls) ->
    ?UNIT;
input_type(Typed, _Binds) ->
    [#fn_decl{type = Scheme}] = [D || #fn_decl{name = main} = D <- Typed],
    result_type(Scheme).

result_type(#scheme{type = {tfn, [], _, Result}}) -> Result;
result_type(#scheme{type = T}) -> T.

%% Report §11.5: the type as the checker prints it.
-spec type_text(#checked{}) -> binary().
type_text(#checked{type = T, env = Env}) ->
    unicode:characters_to_binary(
      ern_types:format(T, ern_typecheck:type_state(Env))).

%% Report §11.2: the input runs in a process of its own; the outcome goes to
%% `To`, so the shell's reader stays live and the address is what an
%% interruption kills.
-spec run(#env{}, #checked{}, term()) -> term().
run(Env, #checked{ns = Ns, typed = Typed, iface = Iface, env = TEnv, type = T,
                  binds = Binds}, To) ->
    Desc = ern_emitter:descriptor(T, TEnv),
    {ok, Mod, Beam} = ern_emitter:compile(Ns, Typed, Iface, TEnv),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), Beam),
    Env1 = Env#env{beams = maps:put(Ns, Beam, Env#env.beams)},
    Site = unicode:characters_to_binary(lists:flatten(io_lib:format("~s.main:1", [hd(Ns)]))),
    input_process(ern_rt:spawn('Local',
                 fun() ->
                     Outcome = try
                                   V = value(Mod, Binds),
                                   {'Ok', remember(bind(Env1, Binds, Ns, V, T, TEnv, Iface)),
                                    #value{term = V, desc = Desc}}
                               catch
                                   throw:{ern, fault, Msg} -> {'Faulted', Msg};
                                   Class:Reason -> {'Faulted', fault_text(Class, Reason)}
                               end,
                     ern_rt:send(To, Outcome)
                 end, Site)).

input_process(Pid) ->
    quiet(Pid),
    Pid.

%% A death the shell does not report, having reported it another way.
quiet(Pid) ->
    case persistent_term:get({?MODULE, watcher}, undefined) of
        undefined -> ok;
        Watcher -> Watcher ! {quiet, Pid}
    end,
    ok.

%% An input that declares runs its initializers and nothing else. Report
%% §8.5: a module's top-level values are computed by them, which the runner
%% does when it loads a module; an input's module is loaded here, so they
%% run here, in the input's own process. Its value is Unit, which prints
%% nothing (report §11.2).
value(Mod, decls) ->
    erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'(),
    'Unit';
value(Mod, _Binds) ->
    Mod:main().

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
where({field, Con}) -> {'Fields', fields_of(Con)};
%% the parser could not tell a field's name from a value; the
%% constructor's type can, and only a named constructor has fields
where({field_or_value, Con}) ->
    case fields_of(Con) of
        [] -> 'Expression';
        Fields -> {'Fields', Fields}
    end.

%% The fields of a constructor in scope, which the interfaces carry.
fields_of(Con) ->
    Env = persistent_term:get({?MODULE, env}, #env{}),
    case [Fs || #iface{types = Ts} <- Env#env.ifaces ++ ern_prelude:stdlib_ifaces(),
                {_, #tinfo{constructors = Cs}} <- maps:to_list(Ts),
                #cinfo{name = N, fields = {named, Fs}} <- Cs, N =:= Con] of
        [Fields | _] -> [unicode:characters_to_binary(atom_to_list(F)) || F <- Fields];
        [] -> []
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
        ++ [name('Constructor', atom_to_list(N), atom_to_list(N))
            || {N, _} <- maps:to_list(maps:get(cons, S, #{}))],
    {TypeQs, ConQs} = ern_typecheck:prelude_names(),
    Prelude = [name('Value', qname_text(Q), qname_text(Q) ++ " : " ++ Type)
               || {Q, Type} <- ern_prelude:values()]
        ++ [name('Type', qname_text(Q), "type " ++ qname_text(Q)) || Q <- TypeQs]
        ++ [name('Constructor', qname_text(Q), qname_text(Q)) || Q <- ConQs],
    Modules = lists:append([module_names(I, St) || I <- Ifaces ++ ern_prelude:stdlib_ifaces()]),
    lists:usort(Session ++ Prelude ++ Modules).

%% A module in scope: the module itself, its exported values and types,
%% and the constructors of those types, each by the name a person types.
module_names(#iface{namespace = Ns, types = Ts, values = Vs}, St) ->
    [name('Module', qname_text(Ns), "module " ++ qname_text(Ns))]
        ++ [name('Value', qname_text(Q),
                 qname_text(Q) ++ " : " ++ ern_types:format_scheme(Sc, St))
            || {Q, Sc} <- maps:to_list(Vs)]
        ++ lists:append(
             [[name('Type', qname_text(Q), abstract_text(TI) ++ "type " ++ qname_text(Q))
               | [name('Constructor', qname_text(lists:droplast(Q) ++ [CN]), atom_to_list(CN))
                  || #cinfo{name = CN} <- Cs, not TI#tinfo.abstract]]
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
session_state(#env{session = S}) ->
    St = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    ern_types:set_scope(St, [], maps:values(maps:get(types, S, #{})), []).

%% Report §11.2: `:forget` removes a name the session declared, and `*`
%% every one of them. A type is forgotten with its constructors; nothing is
%% unloaded, since a value made before carries the type it was made with.
-spec forget(#env{}, binary()) -> {'Left', binary()} | {'Right', #env{}}.
forget(Env, <<"*">>) ->
    {'Right', Env#env{session = #{}}};
forget(#env{session = S} = Env, Text) ->
    Name = binary_to_atom(Text),
    Values = maps:get(values, S, #{}),
    Types = maps:get(types, S, #{}),
    Cons = maps:get(cons, S, #{}),
    case maps:is_key(Name, Values) orelse maps:is_key(Name, Types) of
        false ->
            {'Left', <<"the session declares no ", Text/binary>>};
        true ->
            Members = [{O, M} || {O, M} <- maps:keys(Values), O =:= Name],
            Gone = constructors(maps:get(Name, Types, none), Cons, Env),
            {'Right', Env#env{session = S#{values => maps:without([Name | Members], Values),
                                           types => maps:remove(Name, Types),
                                           cons => maps:without(Gone, Cons)}}}
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
browse(#env{ifaces = Ifaces}, Text) ->
    Ns = namespace(Text),
    case [I || #iface{namespace = N} = I <- Ifaces ++ ern_prelude:stdlib_ifaces(), N =:= Ns] of
        [] ->
            {'Left', <<"no module ", Text/binary, " is in scope">>};
        Found ->
            #iface{types = Ts, values = Vs} = lists:last(Found),
            St0 = ern_typecheck:type_state(ern_typecheck:prelude_env()),
            St = ern_types:set_scope(St0, Ns, [], []),
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

namespace(Text) ->
    [binary_to_atom(S) || S <- binary:split(Text, <<".">>, [global]), S =/= <<>>].

%% Report §11.2, §11.4: the documentation of one declaration, as
%% `ernc --doc` renders it, read from the module that declares it: an input
%% of this session, or a module on the load path.
-spec doc(#env{}, binary()) -> {'Left', binary()} | {'Right', binary()}.
doc(Env, Text) ->
    Segments = namespace(Text),
    case doc_of(Env, Segments) of
        {ok, Page} -> {'Right', unicode:characters_to_binary(Page)};
        none -> {'Left', <<"no documentation for ", Text/binary>>}
    end.

doc_of(Env, Segments) ->
    case session_doc(Env, Segments) of
        {ok, Page} -> {ok, Page};
        none -> module_doc(Segments)
    end.

%% A name the session declared: the beam of the input that declared it, and
%% the entry under its unqualified name, a member under `Type.name`.
session_doc(#env{session = S, beams = Beams}, Segments) ->
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
            entry(beam(Q, [lists:last(Q)], Beams), lists:last(Q));
        {Q, _} ->
            entry(beam(Q, Segments, Beams), entry_name(Segments))
    end.

%% The input that declared the name: the qualified name without the
%% segments the name itself is written with.
beam(Q, Segments, Beams) ->
    maps:get(lists:sublist(Q, length(Q) - length(Segments)), Beams, none).

entry_name([Name]) -> Name;
entry_name([Owner, Name]) -> list_to_atom(atom_to_list(Owner) ++ "." ++ atom_to_list(Name)).

%% A module on the load path, `List.map`, or one of its type's members,
%% `Net.Http.Request.method`.
module_doc(Segments) when length(Segments) >= 2 ->
    Name = lists:last(Segments),
    case entry(beam_of(lists:droplast(Segments)), Name) of
        {ok, Page} ->
            {ok, Page};
        none when length(Segments) >= 3 ->
            [Owner, Member] = lists:nthtail(length(Segments) - 2, Segments),
            entry(beam_of(lists:sublist(Segments, length(Segments) - 2)),
                  entry_name([Owner, Member]));
        none ->
            none
    end;
module_doc(_) ->
    none.

%% The compiled module behind a namespace, as bytes: the file the runner
%% loaded it from, an `.erc`, or the `.beam` of a module on the code path,
%% the standard library's among them. `beam_lib` takes either as a binary.
beam_of(Ns) ->
    Mod = ern_emitter:module_atom(Ns),
    Paths = [code:which(Mod), code:where_is_file(atom_to_list(Mod) ++ ".beam")],
    case [Bin || P <- Paths, is_list(P), {ok, Bin} <- [file:read_file(P)]] of
        [] -> none;
        [Bin | _] -> Bin
    end.

entry(none, _) -> none;
entry(Beam, Name) ->
    try ern_page:declaration(Beam, Name)
    catch _:_ -> none
    end.

diagnostic(From, Input, Diags) ->
    unicode:characters_to_binary(
      [ern_diag:format(binary_to_list(From), Input, D) || D <- Diags]).

%% Report §11.2: the shell reports a process that faults, and the runtime
%% is what knows. The watcher is told of every death the runtime records
%% (§6.9), keeps the faults for `:faults`, and forwards the ones that are
%% news to the session: not the shell's own processes, and not an input's,
%% whose fault is already its answer.
-define(FAULTS, 100).

-spec deaths(term()) -> 'Unit'.
deaths(To) ->
    Watcher = erlang:spawn(fun() -> watch(To, [], []) end),
    persistent_term:put({?MODULE, watcher}, Watcher),
    ern_rt:deaths(Watcher),
    'Unit'.

watch(To, Quiet, Faults) ->
    receive
        {death, Pid, Site, {'Fault', _} = Reason} ->
            case lists:member(Pid, Quiet ++ own()) of
                true ->
                    watch(To, Quiet, Faults);
                false ->
                    Down = {'Down', Site, Reason},
                    ern_rt:send(To, Down),
                    watch(To, Quiet, lists:sublist([Down | Faults], ?FAULTS))
            end;
        {death, _, _, _} ->
            watch(To, Quiet, Faults);
        %% an input's own fault is its answer, and a process `:reload` ends
        %% is named by `:reload` itself
        {quiet, Pid} ->
            watch(To, [Pid | Quiet], Faults);
        {faults, From, Ref} ->
            From ! {Ref, lists:reverse(Faults)},
            watch(To, Quiet, Faults)
    end.

%% Report §11.2: a process of the shell's own, the session, the screen and
%% the reader. Each says so from inside itself: an address handed to a
%% foreign function arrives as the checking proxy in front of it (§8.4), so
%% the process behind it is not what the front end would be holding.
-spec mine() -> 'Unit'.
mine() ->
    persistent_term:put({?MODULE, own}, [ern_rt:self() | own()]),
    'Unit'.

own() ->
    persistent_term:get({?MODULE, own}, []).

%% Report §11.2: the faults reported since the session began, oldest first;
%% the last few hundred are kept, a session never shrinking (§11.2).
-spec faults() -> [term()].
faults() ->
    case persistent_term:get({?MODULE, watcher}, undefined) of
        undefined ->
            [];
        Watcher ->
            Ref = make_ref(),
            Watcher ! {faults, erlang:self(), Ref},
            receive {Ref, Faults} -> Faults after 5000 -> [] end
    end.

%% Report §11.2, §6.9: the live processes by their spawn sites, the
%% session's own left out; a site and never an address, which §6.3 gives
%% no way to compare anyway.
-spec processes() -> [binary()].
processes() ->
    Own = [ern_rt:self() | own()],
    lists:sort([Site || {Pid, Site} <- ern_rt:live(), not lists:member(Pid, Own)]).

%% Report §11.2: `:load` takes a module by its namespace. Its source under
%% the source root is compiled as `ernc` would compile it and nothing is
%% written; a module with no source there is loaded from its compiled
%% form, on the load path. Afterwards it is in scope by its qualified
%% name, as every loaded module is (§4.2).
-spec load(#env{}, binary()) -> {'Left', binary()} | {'Right', {#env{}, binary()}}.
load(Env, Text) ->
    Ns = namespace(Text),
    Name = unicode:characters_to_binary(qname_text(Ns)),
    case source_of(Env, Ns) of
        {ok, File} ->
            case compile_source(Env, File) of
                {ok, Ns2, Beam, Hash} when Ns2 =:= Ns ->
                    {'Right', {install(Env, Ns, Beam, Hash),
                               <<Name/binary, ", compiled from ",
                                 (list_to_binary(relative(File, Env)))/binary>>}};
                {ok, Ns2, _, _} ->
                    {'Left', <<(list_to_binary(qname_text(Ns2)))/binary, " is declared in ",
                               (list_to_binary(relative(File, Env)))/binary,
                               ", which is not where ", Name/binary, " belongs">>};
                {error, Diags} ->
                    {'Left', Diags}
            end;
        none ->
            case compiled_of(Env, Ns) of
                {ok, File, Beam, Hash} ->
                    {'Right', {install(Env, Ns, Beam, Hash),
                               <<Name/binary, ", from ",
                                 (list_to_binary(relative(File, Env)))/binary>>}};
                none ->
                    {'Left', <<"no module ", Name/binary, " under the source root or on the"
                               " load path">>}
            end
    end.

%% Report §11.2: every module the session loaded whose source has changed,
%% compiled and loaded again. A process still in the previous version, and
%% a binding that holds a function of it, keep it; the reload that needs
%% that version ends them, and the one before names them.
-spec reload(#env{}) -> {'Left', binary()} | {'Right', {#env{}, [binary()]}}.
reload(#env{modules = Modules} = Env) ->
    Changed = [{Ns, File, Hash}
               || {Ns, Loaded} <- lists:sort(maps:to_list(Modules)),
                  {ok, File} <- [source_of(Env, Ns)],
                  {ok, Hash} <- [source_hash(File)],
                  Hash =/= Loaded],
    case Changed of
        [] ->
            {'Right', {Env, [<<"no source has changed">>]}};
        _ ->
            case lists:foldl(fun reload_one/2, {Env, [], ok}, Changed) of
                {_, _, {error, Text}} -> {'Left', Text};
                {Env1, Lines, ok} -> {'Right', {Env1, lists:reverse(Lines)}}
            end
    end.

reload_one(_, {Env, Lines, {error, _} = Stop}) ->
    {Env, Lines, Stop};
reload_one({Ns, File, _Hash}, {Env, Lines, ok}) ->
    Mod = ern_emitter:module_atom(Ns),
    Name = unicode:characters_to_binary(qname_text(Ns)),
    {Ended, Env1} = case erlang:check_old_code(Mod) of
                        true -> end_previous(Env, Mod);
                        false -> {[], Env}
                    end,
    code:purge(Mod),
    case compile_source(Env1, File) of
        {ok, _, Beam, Hash2} ->
            Env2 = install(Env1, Ns, Beam, Hash2),
            Waiting = in_previous(Env2, Mod),
            {Env2, waiting_line(Name, Waiting) ++ ended_lines(Name, Ended)
                   ++ [<<Name/binary, ", compiled again">> | Lines], ok};
        {error, Diags} ->
            {Env1, Lines, {error, Diags}}
    end.

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
%% report gives them, and the bindings that hold a function of it are
%% forgotten; the fault reports leave out a process ended here, `:reload`
%% being the one that says so.
end_previous(#env{session = S} = Env, Mod) ->
    Processes = [{Pid, Site} || {Pid, Site} <- ern_rt:live(),
                                erlang:check_process_code(Pid, Mod)],
    lists:foreach(fun({Pid, _}) ->
                      quiet(Pid),
                      exit(Pid, {ern, code_replaced})
                  end, Processes),
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

install(#env{ifaces = Ifaces, modules = Modules} = Env, Ns, Beam, Hash) ->
    Mod = ern_emitter:module_atom(Ns),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), Beam),
    {ok, #{iface := Iface}} = ern_emitter:read_interface(Beam),
    Env#env{ifaces = [I || I <- Ifaces, I#iface.namespace =/= Ns] ++ [Iface],
            modules = Modules#{Ns => Hash},
            beams = maps:put(Ns, Beam, Env#env.beams)}.

compile_source(#env{source_root = Root} = Env, File) ->
    case ern_cli:compile_source(File, Root, out_dir(Env)) of
        {ok, Ns, Beam, Hash} ->
            {ok, Ns, Beam, Hash};
        {error, _, [Text]} when is_list(Text) ->
            {error, unicode:characters_to_binary([Text, "\n"])};
        {error, _, Diags} ->
            {ok, Source} = file:read_file(File),
            {error, unicode:characters_to_binary(
                      [ern_diag:format(File, Source, D) || D <- Diags])}
    end.

out_dir(#env{roots = [Root | _]}) -> Root;
out_dir(#env{source_root = Root}) -> Root.

source_of(#env{source_root = Root}, Ns) ->
    File = filename:join(Root, ern_cli:module_path(Ns) ++ ".ern"),
    case filelib:is_regular(File) of
        true -> {ok, File};
        false -> none
    end.

compiled_of(#env{roots = Roots}, Ns) ->
    Rel = ern_cli:module_path(Ns) ++ ".erc",
    case [F || R <- Roots, F <- [filename:join(R, Rel)], filelib:is_regular(F)] of
        [File | _] ->
            {ok, Bin} = file:read_file(File),
            case ern_emitter:read_interface(Bin) of
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

%% Report §11.2: the shell edits a line when it has a terminal and reads
%% lines when it has not.
-spec is_terminal() -> boolean().
is_terminal() ->
    try prim_tty:isatty(stdin) =:= true
    catch _:_ -> false
    end.

%% The screen writes to the terminal itself: `Sys.stdout` is the screen's,
%% so a screen that printed through it would print to itself.
-spec write(binary()) -> 'Unit'.
write(Text) ->
    io:put_chars(unicode:characters_to_binary(Text)),
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
                undefined -> io:put_chars(Bin);
                Address -> ern_rt:send(Address, Bin)
            end;
        {_, Device} ->
            %% report §11.2: a program's output goes where `:output` sent
            %% it, which is another terminal and its own scrolling
            file:write(Device, Bin),
            ok
    end.

%% Report §11.2: where a program's output goes. A path is another terminal
%% or a file, `-` is the tail again, and nothing is where it goes now. The
%% front end opens it, so the shell gains no file system of its own.
-spec output(binary()) -> {'Left', binary()} | {'Right', binary()}.
output(<<>>) ->
    {'Right', <<"output goes to ", (where_output())/binary>>};
output(<<"-">>) ->
    close_output(),
    {'Right', <<"output goes to the tail">>};
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
        undefined -> <<"the tail">>;
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
bind(Env, decls, _Ns, _Value, _Type, _TEnv, Iface) ->
    session(Env, Iface);
bind(#env{n = N} = Env, Name, _Ns, Value, Type, TEnv, _Iface) ->
    Holder = [list_to_atom("Bindings" ++ integer_to_list(N))],
    Mod = ern_emitter:module_atom(Holder),
    persistent_term:put({Mod, Name}, Value),
    Zonked = ern_types:zonk(Type, ern_typecheck:type_state(TEnv)),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), holder(Mod, Name)),
    Scheme = ern_types:mono(Zonked),
    session(Env, #iface{namespace = Holder, values = #{Holder ++ [Name] => Scheme},
                        lets = [Holder ++ [Name]]}).

%% Report §11.2: the session is a scope of its own. The interface behind an
%% input joins the ones the checker is given, and what it declares joins the
%% scope under the unqualified name, which a later declaration of that name
%% overwrites.
session(#env{ifaces = Ifaces, session = S} = Env, #iface{} = Iface) ->
    #iface{namespace = Ns, types = Ts, values = Vs} = Iface,
    Values = maps:merge(maps:get(values, S, #{}),
                        maps:from_list([{value_key(Ns, Q), Q} || Q <- maps:keys(Vs)])),
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
holder(Mod, Name) ->
    ern_rt:in_foreign(fun() -> holder_beam(Mod, Name) end).

holder_beam(Mod, Name) ->
    Get = erl_syntax:application(
            erl_syntax:module_qualifier(erl_syntax:atom(persistent_term), erl_syntax:atom(get)),
            [erl_syntax:tuple([erl_syntax:atom(Mod), erl_syntax:atom(Name)])]),
    Forms = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Mod)]),
             erl_syntax:attribute(erl_syntax:atom(export),
                                  [erl_syntax:list(
                                     [erl_syntax:arity_qualifier(erl_syntax:atom(Name),
                                                                 erl_syntax:integer(0))])]),
             erl_syntax:function(erl_syntax:atom(Name),
                                 [erl_syntax:clause([], none, [Get])])],
    {ok, _, Bin} = compile:forms([erl_syntax:revert(F) || F <- Forms], [return_errors]),
    Bin.

%% Report §11.2: what an input declares, a line for each, in the order they
%% were written. A value is its name and its type, a type its keyword and
%% its name.
-spec declared(#checked{}) -> [binary()].
declared(#checked{binds = it}) ->
    [];
declared(#checked{binds = decls, ns = Ns, decls = Decls, iface = Iface, env = TEnv}) ->
    [line(D, Ns, Iface, TEnv) || D <- Decls, kind(D) =/= other];
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
declared_name(#let_decl{owner = Owner, name = N}) -> {[Owner], N};
declared_name(#type_decl{name = N}) -> {[], N};
declared_name(#abstract_decl{type = #type_decl{name = N}}) -> {[], N};
declared_name(#foreign_type_decl{name = N}) -> {[], N}.

owned([], Name) -> atom_to_list(Name);
owned([Owner], Name) -> [atom_to_list(Owner), ".", atom_to_list(Name)].
