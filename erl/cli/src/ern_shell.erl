%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. An input is a module
%% of its own, `Input<n>`, checked against the load path and the session,
%% compiled, and run in a process of its own; the value is printed by E.1's
%% printer, which `Io.debug` uses, over the descriptor of the input's type.
%% An expression and a `let` are the module's entry point, and what the
%% input declares is the module's declarations.
-module(ern_shell).

-export([start/2, check/2, type_text/1, declared/1, run/3, show/1]).
-export([is_terminal/0, write/1, screen/1, to_screen/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-define(UNIT, {tcon, ['Unit'], []}).

%% The session so far: the roots to look in, the count of inputs seen, the
%% interfaces of the modules behind the session, and the scope those
%% modules make (report §11.2), which the checker takes as its fourth
%% argument.
-record(env, {roots = [], source_root = ".", n = 0, ifaces = [], session = #{}}).
%% A checked input: the module it became, its typed tree, its type.
-record(checked, {ns, typed, decls, iface, env, type, binds}).
%% binds: the name a `let` binds, `it` for an expression, or `decls`
%% A value with the descriptor of its type, so it prints as E.1 prints it.
-record(value, {term, desc}).

-spec start(binary(), binary()) -> #env{}.
start(LoadPath, SourceRoot) ->
    #env{roots = [binary_to_list(D) || D <- binary:split(LoadPath, <<":">>, [global]), D =/= <<>>],
         source_root = binary_to_list(SourceRoot)}.

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
    Site = unicode:characters_to_binary(lists:flatten(io_lib:format("~s.main:1", [hd(Ns)]))),
    ern_rt:spawn('Local',
                 fun() ->
                     Outcome = try
                                   V = value(Mod, Binds),
                                   {'Ok', bind(Env, Binds, Ns, V, T, TEnv, Iface),
                                    #value{term = V, desc = Desc}}
                               catch
                                   throw:{ern, fault, Msg} -> {'Failed', Msg};
                                   Class:Reason -> {'Failed', fault_text(Class, Reason)}
                               end,
                     ern_rt:send(To, Outcome)
                 end, Site).

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

%% Appendix E.1: the value as Ernest writes it, by the descriptor of its type.
-spec show(#value{}) -> binary().
show(#value{term = V, desc = D}) ->
    ern_show:show(D, V).

diagnostic(Input, Diags) ->
    unicode:characters_to_binary(
      [ern_diag:format("input", Input, D) || D <- Diags]).

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
holder(Mod, Name, Arity) ->
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
