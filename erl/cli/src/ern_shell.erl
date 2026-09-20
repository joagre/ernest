%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. An input is a module
%% of its own, `Input<n>`, checked against the load path and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
-module(ern_shell).

-export([loaded/1, start/0, program/0, check/2, type_text/1, declared/1, run/3, show/3]).
-export([bindings/1, forget/2, browse/2, doc/2]).
-export([deaths/1, mine/0, faults/0, processes/0]).
-export([is_terminal/0, write/1, screen/1, to_screen/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-define(UNIT, {tcon, ['Unit'], []}).

%% The session so far: the roots to look in, the count of inputs seen, the
%% interfaces of the modules behind the session, and the scope those
%% modules make (report §11.2), which the checker takes as its fourth
%% argument.
-record(env, {roots = [], source_root = ".", n = 0, ifaces = [], session = #{}, beams = #{}}).
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
    #env{roots = maps:get(roots, What, []),
         source_root = maps:get(source_root, What, "."),
         ifaces = maps:get(ifaces, What, [])}.

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

%% Report §11.2: an input is checked before it is run; a failure is §11.5's
%% text, as `ernc` shows it.
-spec check(#env{}, binary()) -> {'Left', binary()} | {'Right', {#env{}, #checked{}}}.
check(#env{n = N} = Env, Input) ->
    Ns = [list_to_atom("Input" ++ integer_to_list(N + 1))],
    case input(Input) of
        {ok, Binds, Expr} ->
            check_module(Env#env{n = N + 1}, Ns, Input, entry(Expr), Binds);
        {decls, Decls} ->
            check_module(Env#env{n = N + 1}, Ns, Input, Decls, decls);
        {error, Diag} ->
            {'Left', diagnostic(Input, [Diag])}
    end.

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

check_module(#env{ifaces = Ifaces, session = Session} = Env, Ns, Input, Decls, Binds) ->
    case ern_typecheck:check(Ns, Decls, Ifaces, Session) of
        {ok, Typed, Iface, TEnv} ->
            {'Right', {Env, #checked{ns = Ns, typed = Typed, decls = Decls, iface = Iface,
                                     env = TEnv, type = input_type(Typed, Binds),
                                     binds = Binds}}};
        {error, Diags} ->
            {'Left', diagnostic(Input, Diags)}
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
                                   {'Ok', bind(Env1, Binds, Ns, V, T, TEnv, Iface),
                                    #value{term = V, desc = Desc}}
                               catch
                                   throw:{ern, fault, Msg} -> {'Failed', Msg};
                                   Class:Reason -> {'Failed', fault_text(Class, Reason)}
                               end,
                     ern_rt:send(To, Outcome)
                 end, Site)).

%% An input's own fault is its answer, so the watcher leaves it out.
input_process(Pid) ->
    case persistent_term:get({?MODULE, watcher}, undefined) of
        undefined -> ok;
        Watcher -> Watcher ! {input, Pid}
    end,
    Pid.

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

diagnostic(Input, Diags) ->
    unicode:characters_to_binary(
      [ern_diag:format("input", Input, D) || D <- Diags]).

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

watch(To, Inputs, Faults) ->
    receive
        {death, Pid, Site, {'Fault', _} = Reason} ->
            case lists:member(Pid, Inputs ++ own()) of
                true ->
                    watch(To, Inputs, Faults);
                false ->
                    Down = {'Down', Site, Reason},
                    ern_rt:send(To, Down),
                    watch(To, Inputs, lists:sublist([Down | Faults], ?FAULTS))
            end;
        {death, _, _, _} ->
            watch(To, Inputs, Faults);
        {input, Pid} ->
            watch(To, [Pid | Inputs], Faults);
        {faults, From, Ref} ->
            From ! {Ref, lists:reverse(Faults)},
            watch(To, Inputs, Faults)
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
    case persistent_term:get({?MODULE, screen}, undefined) of
        undefined -> io:put_chars(Bin);
        Address -> ern_rt:send(Address, Bin)
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
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), holder(Mod, Name, arity(Zonked))),
    Scheme = ern_types:mono(Zonked),
    session(Env, #iface{namespace = Holder, values = #{Holder ++ [Name] => Scheme}}).

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

arity({tfn, Params, _, _}) -> length(Params);
arity(_) -> none.

%% The getter the emitter emits for a module's own value (§8.5), and, for a
%% binding that holds a function, the direct call the emitter emits for a
%% name it knows the arity of: `f(1)` is `ern@bindings1:f(1)` and `f` alone
%% is `ern@bindings1:f()`, so the holder answers both.
%%
%% Report §8.6: the host's compiler waits for a process of its own, and the
%% input's process is an Ernest process waiting with it. It is marked as a
%% foreign call in progress, which is what it is, so that `Deadlock` is not
%% declared over a binding being made.
holder(Mod, Name, Arity) ->
    ern_rt:in_foreign(fun() -> holder_beam(Mod, Name, Arity) end).

holder_beam(Mod, Name, Arity) ->
    Get = erl_syntax:application(
            erl_syntax:module_qualifier(erl_syntax:atom(persistent_term), erl_syntax:atom(get)),
            [erl_syntax:tuple([erl_syntax:atom(Mod), erl_syntax:atom(Name)])]),
    Exports = [erl_syntax:arity_qualifier(erl_syntax:atom(Name), erl_syntax:integer(0))
               | [erl_syntax:arity_qualifier(erl_syntax:atom(Name), erl_syntax:integer(Arity))
                  || is_integer(Arity), Arity > 0]],
    Args = [erl_syntax:variable("A" ++ integer_to_list(I))
            || is_integer(Arity), I <- lists:seq(1, Arity)],
    Applied = [erl_syntax:function(erl_syntax:atom(Name),
                                   [erl_syntax:clause(Args, none,
                                                      [erl_syntax:application(Get, Args)])])
               || is_integer(Arity), Arity > 0],
    Forms = [erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Mod)]),
             erl_syntax:attribute(erl_syntax:atom(export), [erl_syntax:list(Exports)]),
             erl_syntax:function(erl_syntax:atom(Name),
                                 [erl_syntax:clause([], none, [Get])]) | Applied],
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
