%% The shell's front end (report §11.2, plan MVP 2.6): the toolchain behind
%% the foreign interface the shell in `shell/` calls. Checkpoint 0 is
%% expressions only, so an input is wrapped as the entry point of a module
%% of its own, `Input<n>`, checked against the load path, compiled, and run
%% in a process of its own; the value is printed by E.1's printer, which
%% `Io.debug` uses, over the descriptor of the input's type.
-module(ern_shell).

-export([start/2, check/2, type_text/1, declared/1, run/3, show/1]).
-export([is_terminal/0, write/1, screen/1, to_screen/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

%% The session so far. Checkpoint 0 keeps no bindings, so it is the roots to
%% look in and the count of inputs seen.
-record(env, {roots = [], source_root = ".", n = 0, bindings = #{}}).
%% bindings: name => {the holder module's namespace, its scheme}
%% A checked input: the module it became, its typed tree, its type.
-record(checked, {ns, typed, iface, env, type, binds}).
%% binds: the name this input binds, or `it` for an expression
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
        {error, Diag} ->
            {'Left', diagnostic(Input, [Diag])}
    end.

%% Report §11.2: an input is an expression, whose value is `it`, or a `let`,
%% whose value is the name it binds. A `let` at the prompt is a block `let`
%% (§4.6 is for a module's), so it is the entry point's body and the name is
%% bound to what the input answers.
input(Text) ->
    case ern_parser:parse_expr(Text) of
        {ok, Expr} ->
            {ok, it, Expr};
        {error, Diag} ->
            case ern_parser:parse_string(Text) of
                {ok, [#let_decl{name = Name, body = Body}]} -> {ok, Name, Body};
                _ -> {error, Diag}
            end
    end.

%% `export fn main() -> a with m = <the input>`, the entry point of §8.1.
entry(Expr) ->
    [#fn_decl{pos = {1, 1, {1, 1}}, export = true, name = main, params = [], body = Expr}].

check_module(#env{bindings = Bs} = Env, Ns, Input, Decls, Binds) ->
    Session = maps:map(fun(Name, {Holder, _}) -> Holder ++ [Name] end, Bs),
    Ifaces = [#iface{namespace = Holder,
                     values = #{Holder ++ [Name] => Scheme}}
              || {Name, {Holder, Scheme}} <- maps:to_list(Bs)],
    case ern_typecheck:check(Ns, Decls, Ifaces, Session) of
        {ok, Typed, Iface, TEnv} ->
            [#fn_decl{type = Scheme}] = [D || #fn_decl{name = main} = D <- Typed],
            {'Right', {Env, #checked{ns = Ns, typed = Typed, iface = Iface, env = TEnv,
                                     type = result_type(Scheme), binds = Binds}}};
        {error, Diags} ->
            {'Left', diagnostic(Input, Diags)}
    end.

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
                                   V = Mod:main(),
                                   {'Ok', bind(Env, Binds, Ns, V, T, TEnv),
                                    #value{term = V, desc = Desc}}
                               catch
                                   throw:{ern, fault, Msg} -> {'Failed', Msg};
                                   Class:Reason -> {'Failed', fault_text(Class, Reason)}
                               end,
                     ern_rt:send(To, Outcome)
                 end, Site).

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
bind(#env{n = N, bindings = Bs} = Env, Name, _Ns, Value, Type, TEnv) ->
    Holder = [list_to_atom("Bindings" ++ integer_to_list(N))],
    Mod = ern_emitter:module_atom(Holder),
    persistent_term:put({Mod, Name}, Value),
    Zonked = ern_types:zonk(Type, ern_typecheck:type_state(TEnv)),
    {module, Mod} = code:load_binary(Mod, atom_to_list(Mod), holder(Mod, Name, arity(Zonked))),
    Scheme = ern_types:mono(Zonked),
    Env#env{bindings = Bs#{Name => {Holder, Scheme}}}.

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

%% Report §11.2: what an input declares, for the line the shell prints.
-spec declared(#checked{}) -> [{binary(), binary()}].
declared(#checked{binds = it}) -> [];
declared(#checked{binds = Name} = C) -> [{atom_to_binary(Name), type_text(C)}].
