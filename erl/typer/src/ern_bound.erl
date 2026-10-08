%% Report §3.11: the type bound to its node, and the refusals that keep a
%% value of one from starting towards another node. A key of a bound type
%% is refused where the checker supplies the key's text (ern_typecheck's
%% supply of `keyed`); a spawn on a peer is read off a definition here,
%% once the definition is inferred: its function is a declaration's name
%% or a lambda written in the definition, at the spawn or bound by a `let`
%% the spawn names, and what that lambda captures, and the mailbox type of
%% the process it starts, are neither bound nor hold a type variable.
%% Nothing else is checked, and nothing is looked through at a send. A
%% breach is thrown as the checker's type errors are.
-module(ern_bound).

-export([binds/2, check/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

%% Report §3.11: false where a value of the type crosses to another node,
%% and else what binds it there, as a phrase: a function, a value of a
%% foreign type, the address of a resource, or an address or a reply whose
%% message type is bound. A declared type holds its fields with its
%% arguments in place of its parameters, a private type of another module
%% among them (§11.1), and a built-in type its arguments; a declared type
%% met again inside its own fields is not read again, as the equality
%% check has it (§3.10).
-spec binds(ern_types:type(), ern_typecheck:env()) -> false | string().
binds(Type, Env) ->
    binds(Type, Env, []).

binds(Type, Env, Seen) ->
    TypeState = ern_typecheck:type_state(Env),
    case ern_types:resolve(Type, TypeState) of
        {tfn, _, _, _} ->
            "a function";
        {tcon, ['Address'], [Message]} ->
            case resource(ern_types:resolve(Message, TypeState)) of
                false -> holding("an address whose message type holds ", Message, Env, Seen);
                Resource -> Resource
            end;
        {tcon, ['Reply'], [Answer]} ->
            holding("a reply whose answer holds ", Answer, Env, Seen);
        {tcon, QualifiedName, Args} ->
            case {is_builtin(QualifiedName), ern_typecheck:described_type(QualifiedName, Env)} of
                {false, #type_info{foreign = true}} ->
                    "a value of the foreign type " ++ ern_namespace:text(QualifiedName);
                _ ->
                    declared_binds(QualifiedName, Args, Env, Seen)
            end;
        {ttuple, Elements} ->
            first(fun(Element) -> binds(Element, Env, Seen) end, Elements);
        _ ->
            false
    end.

declared_binds(QualifiedName, Args, Env, Seen) ->
    case {lists:member(QualifiedName, Seen),
          ern_typecheck:declared_fields(QualifiedName, Args, Env)} of
        {false, {ok, Fields}} ->
            first(fun(Field) -> binds(Field, Env, [QualifiedName | Seen]) end, Fields);
        _ ->
            ValueArgs = ern_types:value_args(QualifiedName, Args, ern_typecheck:type_state(Env)),
            first(fun(Arg) -> binds(Arg, Env, Seen) end, ValueArgs)
    end.

holding(Prefix, Type, Env, Seen) ->
    case binds(Type, Env, Seen) of
        false -> false;
        Inner -> Prefix ++ Inner
    end.

%% Report §3.1, §9.1, §9.2: a type of the prelude's own, which the checker
%% keeps as a foreign one and which is no foreign type of §3.8.
is_builtin([Name]) -> lists:keymember(Name, 1, ern_prelude:builtin_types());
is_builtin(_) -> false.

%% Report §3.11, Appendix E.18, E.23: the message types of the runtime's
%% processes for a socket, a listener and a running program, whose
%% addresses are resources; an `Ets.Table` is a foreign type (Appendix
%% G.1), bound as one.
resource({tcon, ['Tcp', 'SocketMsg'], []}) -> "the address of a socket";
resource({tcon, ['Tcp', 'ListenerMsg'], []}) -> "the address of a listener";
resource({tcon, ['Os', 'ProgramMsg'], []}) -> "the address of a running program";
resource(_) -> false.

first(_, []) ->
    false;
first(Binds, [Type | Types]) ->
    case Binds(Type) of
        false -> first(Binds, Types);
        Found -> Found
    end.

%%
%% A spawn on a peer
%%

%% Report §3.11: every spawn on a peer in a definition, its typed body read
%% once its types are known. Scope holds, for each local name a `let` binds
%% to a lambda, that lambda, and for each name bound since, `value`.
-spec check(tuple(), ern_typecheck:env()) -> ok.
check(#fn_declaration{params = Params, body = Body}, Env) ->
    walk(Body, shadowed(param_names(Params), #{}), Env);
check(#let_declaration{body = Body}, Env) ->
    walk(Body, #{}, Env);
check(_, _) ->
    ok.

walk(#e_call{callee = #e_var{referent = Referent} = Callee, args = Args}, Scope, Env) ->
    case spawn_name(Referent) of
        none -> walk(Callee, Scope, Env);
        Name -> spawned(Name, Callee, Args, Scope, Env)
    end,
    walk(Args, Scope, Env);
walk(#e_var{span = Span, referent = Referent}, _Scope, _Env) ->
    case spawn_name(Referent) of
        none ->
            ok;
        Name ->
            fail(Span, Name ++ " is called where it is named, so that the compiler sees the"
                       " function it starts",
                 "call it: `" ++ Name ++ "(name, fn() = ..., ms)` (§3.11)")
    end;
walk(#e_lambda{params = Params, body = Body}, Scope, Env) ->
    walk(Body, shadowed(param_names(Params), Scope), Env);
walk(#clause{pattern = Pattern, guard = Guard, body = Body}, Scope, Env) ->
    Scope1 = shadowed(pattern_names(Pattern), Scope),
    walk(Guard, Scope1, Env),
    walk(Body, Scope1, Env);
walk(#e_block{statements = Statements}, Scope, Env) ->
    Fns = [Name || #fn_declaration{name = Name} <- Statements],
    lists:foldl(fun(Statement, Acc) -> statement(Statement, Acc, Env) end,
                shadowed(Fns, Scope), Statements),
    ok;
walk(Node, Scope, Env) when is_tuple(Node) ->
    walk(tl(tuple_to_list(Node)), Scope, Env);
walk(Nodes, Scope, Env) when is_list(Nodes) ->
    lists:foreach(fun(Node) -> walk(Node, Scope, Env) end, Nodes);
walk(_, _, _) ->
    ok.

%% A block's statement, and the scope of the statements after it.
statement(#binding{pattern = #p_var{name = Name}, operator = '=', expr = #e_lambda{} = Lambda},
          Scope, Env) ->
    walk(Lambda, Scope, Env),
    Scope#{Name => {lambda, Lambda}};
statement(#binding{pattern = Pattern, expr = Expr}, Scope, Env) ->
    walk(Expr, Scope, Env),
    shadowed(pattern_names(Pattern), Scope);
statement(#fn_declaration{params = Params, body = Body}, Scope, Env) ->
    walk(Body, shadowed(param_names(Params), Scope), Env),
    Scope;
statement(Expr, Scope, Env) ->
    walk(Expr, Scope, Env),
    Scope.

%% Appendix E.27: `Peer.spawn` and `Peer.spawnMonitored`, the module's own
%% functions as the checker resolved them, not names spelled so.
spawn_name(#remote_declaration{namespace = ['Peer'], member_of = undefined, name = Name})
  when Name =:= spawn; Name =:= spawnMonitored ->
    "Peer." ++ atom_to_list(Name);
spawn_name(_) ->
    none.

%% Report §3.11: the function the spawn starts, written where its captures
%% are seen, each capture and the process's mailbox type neither bound nor
%% holding a type variable.
spawned(Name, #e_var{type = CalleeType}, [_Peer, Function | _], Scope, Env) ->
    Captures = captures(Name, Function, Scope, Env),
    lists:foreach(fun(Capture) -> capture_crosses(Name, Capture, Env) end, Captures),
    mailbox_crosses(Name, ern_ast:span(Function), mailbox(CalleeType, Env), Env).

%% The locals the function captures, each once, with the type and the span
%% of its first use: none for a declaration's name.
captures(_Name, #e_lambda{} = Lambda, _Scope, _Env) ->
    lambda_captures(Lambda);
captures(Name, #e_var{span = Span, namespace = [], name = Local, referent = var}, Scope, _Env) ->
    case Scope of
        #{Local := {lambda, Lambda}} ->
            lambda_captures(Lambda);
        _ ->
            fail(Span, Name ++ " starts " ++ atom_to_list(Local) ++ ", a function that came as a"
                       " value, whose captures the compiler does not see",
                 "write the lambda at the spawn, or bind it with `let` in this definition"
                 " (§3.11)")
    end;
captures(Name, #e_var{span = Span, name = Declared, referent = Referent}, _Scope, Env) ->
    case ern_typecheck:is_top_let(Referent, Env) of
        false ->
            [];
        true ->
            fail(Span, Name ++ " starts " ++ atom_to_list(Declared) ++ ", a top-level `let`,"
                       " whose value may hold captures the compiler does not see",
                 "declare it with `fn`, or write a lambda at the spawn (§3.11)")
    end;
captures(Name, Function, _Scope, _Env) ->
    fail(ern_ast:span(Function),
         Name ++ " starts a function written where the compiler sees what it captures: a"
                 " declaration's name, or a lambda written in this definition",
         "write the lambda at the spawn, or bind it with `let` in this definition (§3.11)").

%% The locals free in a lambda, each once at its first use.
lambda_captures(#e_lambda{} = Lambda) ->
    Free = [Use || #e_var{referent = var} = Use <- ern_ast:free_uses(Lambda, [])],
    lists:reverse(lists:foldl(fun(#e_var{name = Local} = Use, Acc) ->
                                  case lists:keymember(Local, #e_var.name, Acc) of
                                      true -> Acc;
                                      false -> [Use | Acc]
                                  end
                              end, [], Free)).

capture_crosses(Name, #e_var{span = Span, name = Local, type = Type}, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Substituted = ern_types:substitute(Type, TypeState),
    Text = ern_types:format(Substituted, TypeState),
    case binds(Substituted, Env) of
        false ->
            ern_types:free_variables(Substituted, TypeState) =:= []
                orelse fail(Span, "the function " ++ Name ++ " starts captures "
                                  ++ atom_to_list(Local) ++ ", whose type " ++ Text
                                  ++ " holds a type variable",
                            "a value a spawn on a peer captures has a type known whole, since"
                            " a type variable could stand for one bound to its node (§3.11)");
        Why ->
            fail(Span, "the function " ++ Name ++ " starts captures " ++ atom_to_list(Local)
                       ++ ", whose type " ++ Text ++ " is bound to its node, since it holds "
                       ++ Why,
                 "a value of a bound type never crosses to another node; give the process"
                 " what crosses (§3.11)")
    end.

%% The mailbox type of the process the spawn starts: the effect of the
%% function it takes, its second parameter, at this use.
mailbox(CalleeType, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    {tfn, [_, Function | _], _, _} = ern_types:substitute(CalleeType, TypeState),
    {tfn, [], Mailbox, _} = ern_types:resolve(Function, TypeState),
    Mailbox.

mailbox_crosses(Name, Span, Mailbox, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Text = ern_types:format(Mailbox, TypeState),
    case binds(Mailbox, Env) of
        false ->
            ern_types:free_variables(Mailbox, TypeState) =:= []
                orelse fail(Span, Name ++ " starts a process whose mailbox type " ++ Text
                                  ++ " is not known whole here",
                            "give the function its mailbox type, `fn() : Unit with Never = ...`"
                            " for a process that never receives (§3.11)");
        Why ->
            fail(Span, Name ++ " starts a process whose mailbox type " ++ Text
                       ++ " is bound to its node, since it holds " ++ Why,
                 "the spawn answers an address that may cross to another node, so its"
                 " messages are values that cross (§3.11)")
    end.

%%
%% Utilities
%%

shadowed(Names, Scope) ->
    lists:foldl(fun(Name, Acc) -> Acc#{Name => value} end, Scope, Names).

param_names(Params) ->
    lists:append([pattern_names(Pattern) || #param{pattern = Pattern} <- Params]).

pattern_names(Pattern) ->
    [Name || {Name, _} <- ern_ast:pattern_bindings(Pattern)].

-spec fail(term(), string(), string()) -> no_return().
fail(Span, Message, Help) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = lists:flatten(Message), help = Help}}).
