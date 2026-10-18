%% Report §3.11: the type bound to its node, and the refusals that keep a
%% value of one from starting towards another node. A service at a bound
%% type is refused where the checker supplies the service's type
%% (ern_typecheck's supply of `service`); a spawn on a peer, and a compute,
%% on a peer named or on one the node picks, are read off a definition
%% here, once the definition is inferred: the function is a declaration's
%% name, or a lambda or a `fn` written in the definition, at the spawn or
%% the compute or bound by a `let` it names, or
%% `restarting` applied to one of these, and what that lambda or `fn`
%% captures, and the mailbox type of the process it starts, are neither
%% bound nor hold a type variable, a mailbox type nothing fixed being Never
%% by then (ern_typecheck's unfixed_mailboxes); nor does its body use a
%% member of a requirement in force, a function. A compute's
%% function's result type, which crosses back, is neither bound nor holds a
%% type variable. Nothing else is checked, and nothing is looked through at
%% a send. A breach is thrown as the checker's type errors are.
-module(ern_bound).

-export([binds/2, check/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").

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
            case {ern_prelude:is_builtin(QualifiedName),
                  ern_typecheck:described_type(QualifiedName, Env)} of
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

%% Report §3.11, Appendix E.18, E.23: the message types of the runtime's
%% processes for a socket, a listener and a running program, whose
%% addresses are resources; a library's resource is a foreign type, bound
%% as one.
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

%% Report §3.11: every spawn on a peer and every compute in a definition,
%% its typed body read once its types are known. Scope holds, for each
%% local name a `let` binds to a lambda or a block declares with `fn`, that
%% lambda or declaration, and for each name bound since, `value`.
-spec check(tuple(), ern_typecheck:env()) -> ok.
check(#fn_declaration{params = Params, body = Body}, Env) ->
    walk(Body, shadowed(param_names(Params), #{}), Env);
check(#let_declaration{body = Body}, Env) ->
    walk(Body, #{}, Env);
check(_, _) ->
    ok.

%% Each spawn on a peer, each compute and each `Code.running` under a node.
walk(#e_call{callee = #e_var{referent = Referent} = Callee, args = Args}, Scope, Env) ->
    case {spawn_name(Referent), is_running(Referent)} of
        {none, false} -> walk(Callee, Scope, Env);
        {none, true} -> running(Args, Env);
        {Name, _} -> spawned(Name, Callee, Args, Scope, Env)
    end,
    walk(Args, Scope, Env);
walk(#e_var{span = Span, referent = Referent}, _Scope, _Env) ->
    case {spawn_name(Referent), is_running(Referent)} of
        {none, false} ->
            ok;
        {none, true} ->
            fail(Span, "Code.running is called where it is named, so that the compiler sees the"
                       " declaration it names",
                 "call it: `Code.running(f)`, `f` a top-level `fn` (report §3.11)");
        {Name, _} ->
            fail(Span, Name ++ " is called where it is named, so that the compiler sees the"
                       " function it starts",
                 "call it: `" ++ Name ++ "(" ++ peer_argument(Name) ++ "fn() = ..., ms)`"
                 " (report §3.11)")
    end;
walk(#e_lambda{params = Params, body = Body}, Scope, Env) ->
    walk(Body, shadowed(param_names(Params), Scope), Env);
walk(#clause{pattern = Pattern, guard = Guard, body = Body}, Scope, Env) ->
    Scope1 = shadowed(pattern_names(Pattern), Scope),
    walk(Guard, Scope1, Env),
    walk(Body, Scope1, Env);
walk(#e_block{statements = Statements}, Scope, Env) ->
    Fns = maps:from_list([{Name, {local_fn, Fn}}
                          || #fn_declaration{name = Name} = Fn <- Statements]),
    lists:foldl(fun(Statement, Acc) -> statement(Statement, Acc, Env) end,
                maps:merge(Scope, Fns), Statements),
    ok;
walk(Node, Scope, Env) when is_tuple(Node) ->
    walk(tl(tuple_to_list(Node)), Scope, Env);
walk(Nodes, Scope, Env) when is_list(Nodes) ->
    lists:foreach(fun(Node) -> walk(Node, Scope, Env) end, Nodes);
walk(_, _, _) ->
    ok.

%% A block's statement walked, and the scope of the statements after it.
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

%% Appendix E.27: `Peer.spawn`, `Peer.spawnMonitored`, `Peer.compute` and
%% `Peer.computeAt`, the module's own functions as the checker resolved
%% them, not names spelled so.
spawn_name(#remote_declaration{namespace = ['Peer'], member_of = undefined, name = Name})
  when Name =:= spawn; Name =:= spawnMonitored; Name =:= compute; Name =:= computeAt ->
    "Peer." ++ atom_to_list(Name);
spawn_name(_) ->
    none.

%% Appendix E.27: the peer's name an operation takes before its function,
%% as a help writes the call: every one's but `Peer.compute`'s, whose peer
%% the node picks.
peer_argument("Peer.compute") -> "";
peer_argument(_) -> "name, ".

%% The function the operation takes among its arguments, at its position
%% among its parameters: after the peer's name, where it takes one.
function_position("Peer.compute") -> 1;
function_position(_) -> 2.

%% Appendix E.28: `Code.running`, the module's own function as the checker
%% resolved it, not a name spelled so.
is_running(#remote_declaration{namespace = ['Code'], member_of = undefined, name = running}) ->
    true;
is_running(_) ->
    false.

%% Report §3.11, Appendix E.28: the function `Code.running` names is a
%% top-level `fn` declaration of any arity, which has a hash, whose result
%% type is Unit and whose mailbox type, where it has one, holds no type
%% variable, read from its declaration and not from this use, since every
%% process listed has it as its mailbox type; one that receives nothing
%% names none.
running([#e_var{span = Span, namespace = Namespace, name = Name, referent = Referent}], Env) ->
    Written = ern_namespace:text(Namespace ++ [Name]),
    Help = "name a top-level `fn` whose result type is `Unit`: `Code.running(count)`"
        " (report §3.11)",
    What = fun(Text) -> "Code.running lists the processes that run a declaration, and "
                            ++ Written ++ Text end,
    case Referent of
        var ->
            fail(Span, What(" is a local, whose function is no declaration"), Help);
        {prelude, _} ->
            fail(Span, What(" is the prelude's, which no module declares"), Help);
        _ ->
            ern_typecheck:is_top_let(Referent, Env)
                andalso fail(Span, What(" is a top-level `let`, whose value is no declaration"),
                             "declare the function with `fn` and name it: "
                             "`Code.running(count)` (report §3.11)"),
            ern_typecheck:is_foreign(Referent, Env)
                andalso fail(Span, What(" is a foreign declaration, which has no hash"), Help),
            #scheme{type = Type} = ern_typecheck:declaration_scheme(Referent, Env),
            declared_running(Span, {Written, atom_to_list(Name)}, Type, Env)
    end;
running([Function], _Env) ->
    fail(ern_ast:span(Function),
         "Code.running lists the processes that run a declaration, named where the call is"
         " written",
         "name a top-level `fn` whose result type is `Unit`: `Code.running(count)` (report §3.11)").

%% The declaration's type: its result Unit, and its mailbox type, where it
%% has one, known whole, holding no type variable.
declared_running(Span, {Written, Declared}, Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    {tfn, _, Effect, Result} = ern_types:substitute(Type, TypeState),
    Annotated = "give " ++ Written ++ " its mailbox type, `fn " ++ Declared
        ++ "(...) : Unit receiving Msg = ...`: every process listed has it (report §3.11)",
    case Result of
        {tcon, ['Unit'], []} -> ok;
        _ -> fail(Span, "Code.running lists the processes that run " ++ Written
                        ++ ", whose result type is " ++ ern_types:format(Result, TypeState)
                        ++ ", not Unit",
                  "a process runs a function whose result type is `Unit` (report §3.11)")
    end,
    ern_types:free_variables(Effect, TypeState) =:= []
        orelse fail(Span, "Code.running lists the processes that run " ++ Written
                          ++ ", whose mailbox type " ++ ern_types:format(Effect, TypeState)
                          ++ " holds a type variable", Annotated).

%% Report §3.11: the function the spawn or the compute starts, written
%% where its captures are seen, each capture and the process's mailbox type
%% neither bound nor holding a type variable; and a compute's result type,
%% which crosses back, neither bound nor holding one.
spawned(Name, #e_var{type = CalleeType}, Args, Scope, Env) ->
    Position = function_position(Name),
    Function = lists:nth(Position, Args),
    Captures = restarted_captures(Name, Function, Scope, Env),
    lists:foreach(fun(Capture) -> capture_crosses(Name, Capture, Env) end, Captures),
    FunctionType = function_type(CalleeType, Position, Env),
    is_compute(Name)
        andalso result_crosses(Name, ern_ast:span(Function), FunctionType, Env),
    {tfn, [], Mailbox, _} = FunctionType,
    mailbox_crosses(Name, ern_ast:span(Function), Mailbox, Env).

%% Report §3.11, §6.9: `restarting` applied to a function the spawn admits
%% captures the limit, a `RestartLimit`, which crosses, and what that
%% function captures.
restarted_captures(Name, #e_call{callee = #e_var{referent = {prelude, [restarting]}},
                                 args = [_Limit, Function]}, Scope, Env) ->
    captures(Name, Function, Scope, Env);
restarted_captures(Name, Function, Scope, Env) ->
    captures(Name, Function, Scope, Env).

%% The locals the function captures, each once, with the type and the span
%% of its first use: none for a top-level declaration's name.
captures(Name, #e_lambda{} = Lambda, _Scope, Env) ->
    body_captures(Name, Lambda, ern_ast:free_uses(Lambda, []), Env);
captures(Name, #e_var{span = Span, namespace = [], name = Local, referent = var}, Scope, Env) ->
    case Scope of
        #{Local := {lambda, Lambda}} ->
            body_captures(Name, Lambda, ern_ast:free_uses(Lambda, []), Env);
        #{Local := {local_fn, #fn_declaration{params = Params, body = Body} = Fn}} ->
            body_captures(Name, Fn, ern_ast:free_uses(Body, [Local | param_names(Params)]), Env);
        _ ->
            fail(Span, Name ++ verb(Name) ++ atom_to_list(Local) ++ ", a function that came as"
                       " a value, whose captures the compiler does not see",
                 "write the lambda at " ++ act(Name) ++ ", bind it with `let`, or declare it"
                 " with `fn`, in this definition (report §3.11)")
    end;
captures(Name, #e_var{span = Span, name = Declared, referent = Referent}, _Scope, Env) ->
    case ern_typecheck:is_top_let(Referent, Env) of
        false ->
            [];
        true ->
            fail(Span, Name ++ verb(Name) ++ atom_to_list(Declared) ++ ", a top-level `let`,"
                       " whose value may hold captures the compiler does not see",
                 "declare it with `fn`, or write a lambda at " ++ act(Name) ++ " (report §3.11)")
    end;
captures(Name, Function, _Scope, _Env) ->
    fail(ern_ast:span(Function),
         Name ++ verb(Name) ++ "a function written where the compiler sees what it captures: a"
                 " declaration's name, or a lambda or a `fn` written in this definition",
         "write the lambda at " ++ act(Name) ++ ", bind it with `let`, or declare it with"
         " `fn`, in this definition (report §3.11)").

%% Report §3.11, §4.9: the locals a lambda's or a local fn's body names, its
%% captures, where the body uses no member of a requirement in force, which
%% the definition was given as a function, bound to its node; a member of
%% the requirement of a `fn` declared inside it is that fn's own.
body_captures(Name, Function, Uses, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Resolved = fun(Variable) -> ern_types:resolve(Variable, TypeState) end,
    Own = ern_ast:walk(fun(#fn_declaration{requirement = Requirement}, Acc) ->
                           [Resolved(Variable) || #member{type = Variable} <- Requirement] ++ Acc;
                          (_, Acc) ->
                           Acc
                       end, Function, []),
    Used = ern_ast:walk(fun(#required_member{variable = Variable, member = Member}, Acc) ->
                            [{Variable, Member} | Acc];
                           (_, Acc) ->
                            Acc
                        end, Function, []),
    case [Required || {Variable, _} = Required <- lists:reverse(Used),
                      not lists:member(Resolved(Variable), Own)] of
        [] ->
            first_uses(Uses);
        [{Variable, Member} | _] ->
            fail(ern_ast:span(Function),
                 %% the variable as an error names it, without a printed type's marks
                 Name ++ verb(Name) ++ "a function that uses "
                     ++ string:trim(ern_types:format(Variable, TypeState), trailing, "=+")
                     ++ "." ++ atom_to_list(Member) ++ ", a member of the requirement in force,"
                     " which is a function bound to its node",
                 "give the process what it needs as a value it captures, or "
                 ++ here(Name) ++ " (report §3.11)")
    end.

%% The locals among the uses, each once at its first use.
first_uses(Uses) ->
    Free = [Use || #e_var{referent = var} = Use <- Uses],
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
                orelse fail(Span, "the function " ++ Name ++ verb(Name) ++ "captures "
                                  ++ atom_to_list(Local) ++ ", whose type " ++ Text
                                  ++ " holds a type variable",
                            "a value " ++ act_on_peer(Name) ++ " captures has a type known"
                            " whole, since a type variable could stand for one bound to its node"
                            " (report §3.11)");
        Why ->
            %% a function's type at its use has the effect of its use's
            %% context (§3.9), not the binding's, so it is named, not shown
            What = case ern_types:resolve(Substituted, TypeState) of
                       {tfn, _, _, _} -> ", a function, which is bound to its node";
                       _ -> ", whose type " ++ Text ++ " is bound to its node, since it holds "
                                ++ Why
                   end,
            fail(Span, "the function " ++ Name ++ verb(Name) ++ "captures " ++ atom_to_list(Local)
                       ++ What,
                 "a value of a bound type never crosses to another node; give the process"
                 " what crosses (report §3.11)")
    end.

%% The function the spawn or the compute takes, the parameter at Position,
%% at this use; its effect is the mailbox type of the process it starts.
function_type(CalleeType, Position, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    {tfn, Params, _, _} = ern_types:substitute(CalleeType, TypeState),
    ern_types:resolve(lists:nth(Position, Params), TypeState).

%% Report §3.11, §8.7: the result type of the function a compute runs,
%% whose value crosses back to the caller's node, known whole where the
%% compute is written, and neither bound nor holding a type variable, which
%% an instance could make bound.
result_crosses(Name, Span, {tfn, [], _, Result}, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Substituted = ern_types:substitute(Result, TypeState),
    Text = ern_types:format(Substituted, TypeState),
    case binds(Substituted, Env) of
        false ->
            ern_types:free_variables(Substituted, TypeState) =:= []
                orelse fail(Span, Name ++ " answers a value of type " ++ Text ++ ", which holds a"
                                  " type variable, so whether it crosses is not known here",
                            "give the function its result type, `fn() : Int = ...`: the value"
                            " crosses back to this node, and its type is known whole where the"
                            " compute is written (report §3.11)");
        Why ->
            fail(Span, Name ++ " answers a value of type " ++ Text ++ ", which is bound to its"
                       " node, since it holds " ++ Why,
                 "the value crosses back to this node, so its type is one that crosses; answer"
                 " what crosses (report §3.11)")
    end.

%% A mailbox type that is still a variable is one an annotation names or
%% each call of the definition fixes, since one nothing fixed is Never by
%% now, and an instance of the definition could make it a bound type.
mailbox_crosses(Name, Span, Mailbox, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Text = ern_types:format(Mailbox, TypeState),
    case {binds(Mailbox, Env), ern_types:resolve(Mailbox, TypeState)} of
        {false, {tvar, _}} ->
            fail(Span, Name ++ " starts a process whose mailbox type " ++ Text
                       ++ " is not known whole here",
                 "give the function its mailbox type, " ++ annotated(Name) ++ ": an"
                 " instance of this definition could make the variable a type bound to"
                 " its node (report §3.11)");
        {false, _} ->
            ern_types:free_variables(Mailbox, TypeState) =:= []
                orelse fail(Span, Name ++ " starts a process whose mailbox type " ++ Text
                                  ++ " is not known whole here",
                            "give the function its mailbox type, " ++ annotated(Name) ++ ": a"
                            " type variable in it could stand for a type bound to its node"
                            " (report §3.11)");
        {Why, _} ->
            fail(Span, Name ++ " starts a process whose mailbox type " ++ Text
                       ++ " is bound to its node, since it holds " ++ Why,
                 bound_mailbox_help(Name))
    end.

%% Appendix E.27: whether the operation is a compute, on a peer named or on
%% one the node picks, whose function's value crosses back.
is_compute(Name) ->
    Name =:= "Peer.compute" orelse Name =:= "Peer.computeAt".

%% The help of a bound mailbox type: a spawn answers the process's address,
%% which may cross; a compute's function is checked as a spawn's, one rule
%% for the function a peer runs (§3.11).
bound_mailbox_help(Name) ->
    case is_compute(Name) of
        true -> "the function a peer runs, a compute's as a spawn's, has a mailbox type that"
                " crosses (report §3.11)";
        false -> "the spawn answers an address that may cross to another node, so its messages"
                 " are values that cross (report §3.11)"
    end.

%% What the operation does with its function, in the report's words
%% (§3.11): a spawn starts it, a compute runs it; and the operation as a
%% help names it, the one written.
verb(Name) -> by_kind(Name, " runs ", " starts ").

act(Name) -> by_kind(Name, "the compute", "the spawn").

act_on_peer(Name) -> by_kind(Name, "a compute on a peer", "a spawn on a peer").

here(Name) -> by_kind(Name, "run the function on this node, `f()`", "spawn on this node").

annotated(Name) -> by_kind(Name, "`fn() : Int receiving Msg = ...`",
                           "`fn() : Unit receiving Msg = ...`").

by_kind(Name, Compute, Spawn) ->
    case is_compute(Name) of
        true -> Compute;
        false -> Spawn
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
