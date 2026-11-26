%% Report §3.11: the type bound to its node, and the refusals that keep a
%% value of one from starting towards another node. A service at a bound
%% type is refused where the checker supplies the service's type
%% (ern_typecheck's supply of `service`).
%%
%% A spawn on a peer, and a compute, on a peer named or on one the node
%% picks, are read off a definition here, once the definition is inferred.
%% The function is a declaration's name, or a lambda or a `fn` written in
%% the definition, at the spawn or the compute or bound by a `let` it names,
%% or `restarting` applied to one of these. What that lambda or `fn`
%% captures, and the mailbox type of the process it starts, are neither
%% bound nor hold a type variable, a mailbox type nothing fixed being Never
%% by then (ern_typecheck's unfixed_mailboxes); nor does its body use a
%% member of a requirement in force, a function. A compute's function's
%% result type, which crosses back, is neither bound nor holds a type
%% variable.
%%
%% Nothing else is checked, and nothing is looked through at a send. A
%% breach is thrown as the checker's type errors are.
-module(ern_bound).

-export([binds/2, resource_message/1, check/2, primitive_note/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").

%% Report §3.11, Appendix E.18, E.23: the message types of the runtime's
%% processes for a socket, a listener and a running program.
-define(SOCKET_MSG, {tcon, ['Tcp', 'SocketMsg'], []}).
-define(LISTENER_MSG, {tcon, ['Tcp', 'ListenerMsg'], []}).
-define(PROGRAM_MSG, {tcon, ['Os', 'ProgramMsg'], []}).

%% Report §3.11: false where a value of the type crosses to another node,
%% and else what binds it there, as a phrase: a function, a value of a
%% foreign type, an alarm, the address of a resource or its message type,
%% or an address or a reply whose message type is bound, read through what the type holds,
%% a private type of another module among it (§11.1, ern_typecheck:found_in/3).
-spec binds(ern_types:type(), ern_typecheck:env()) -> false | string().
binds(Type, Env) ->
    ern_typecheck:found_in(fun(Resolved, Inside) -> bound_leaf(Resolved, Inside, Env) end,
                           Type, Env).

bound_leaf({tfn, _, _, _}, _, _) ->
    "a function";
bound_leaf({tcon, ['Address'], [Message]}, Inside, Env) ->
    case resource(ern_types:resolve(Message, ern_typecheck:type_state(Env))) of
        false -> holding("an address whose message type holds ", Inside(Message));
        Resource -> Resource
    end;
bound_leaf({tcon, ['Reply'], [Answer]}, Inside, _) ->
    holding("a reply whose answer holds ", Inside(Answer));
%% report §3.11, Appendix E.15: an alarm the clock holds is a resource,
%% named as one and not by its representation
bound_leaf({tcon, ['Clock', 'Alarm'], []}, _, _) ->
    "an alarm";
%% report §3.11, Appendix E.18, E.23: the message types of a socket, a
%% listener and a running program are bound themselves
bound_leaf({tcon, [_, _], []} = Message, _, _) when Message =:= ?SOCKET_MSG;
                                                     Message =:= ?LISTENER_MSG;
                                                     Message =:= ?PROGRAM_MSG ->
    {Phrase, _} = resource_message(Message),
    Phrase;
bound_leaf({tcon, QualifiedName, _}, _, Env) ->
    case {ern_prelude:is_builtin(QualifiedName),
          ern_typecheck:described_type(QualifiedName, Env)} of
        {false, #type_info{foreign = true}} ->
            "a value of the foreign type " ++ ern_namespace:text(QualifiedName);
        _ ->
            inside
    end;
bound_leaf(_, _, _) ->
    inside.

holding(_, false) -> false;
holding(Prefix, Inner) -> Prefix ++ Inner.

%% Report §3.11, Appendix E.18, E.23: the message types of the runtime's
%% processes for a socket, a listener and a running program, whose
%% addresses are resources; a library's resource is a foreign type, bound
%% as one.
resource(?SOCKET_MSG) -> "the address of a socket";
resource(?LISTENER_MSG) -> "the address of a listener";
resource(?PROGRAM_MSG) -> "the address of a running program";
resource(_) -> false.

%% Report §3.11, §11.5: one of the three message types, as a refusal names
%% it, and what the process that offers it in its place holds; none for
%% any other type.
-spec resource_message(ern_types:type()) -> {string(), string()} | none.
resource_message(?SOCKET_MSG) -> {"the message type of a socket", "socket"};
resource_message(?LISTENER_MSG) -> {"the message type of a listener", "listener"};
resource_message(?PROGRAM_MSG) -> {"the message type of a running program", "program"};
resource_message(_) -> none.

%% Report §3.11, §11.5: a bound type as a refusal writes it, Text, with
%% what binds it, Why: one of the three message types is named as itself.
bound_text(Type, Text, Why) ->
    case resource_message(Type) of
        {Phrase, _} -> Text ++ ", " ++ Phrase ++ ", which is bound to its node";
        none -> Text ++ ", which is bound to its node, since it holds " ++ Why
    end.

%%
%% A spawn on a peer
%%

%% Report §3.11: every spawn on a peer and every compute in a definition,
%% its typed body read once its types are known. Scope holds, for each
%% local name a `let` binds to a lambda or a block declares with `fn`, that
%% lambda or declaration, and for each name bound since, `value`; and, by
%% `{annotation, a}`, where the declaration's signature first writes each
%% type variable a, which a refusal labels.
-spec check(tuple(), ern_typecheck:env()) -> ok.
check(#fn_declaration{params = Params, result_type = Result, effect = Effect, body = Body},
      Env) ->
    Written = ern_ast:walk(fun(#t_var{name = Name, span = Span}, Acc) ->
                               maps:merge(#{{annotation, Name} => Span}, Acc);
                              (_, Acc) ->
                               Acc
                           end, [[Annotation || #param{annotation = Annotation} <- Params],
                                 Result, Effect], #{}),
    walk(Body, maps:merge(shadowed(param_names(Params), #{}), Written), Env);
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
                 "call it: `Code.running(f)`, `f` a top-level `fn`");
        {Name, _} ->
            Operation = operation_text(Name),
            fail(Span, Operation ++ " is called where it is named, so that the compiler sees the"
                       " function it starts",
                 "call it: `" ++ Operation ++ "(" ++ peer_argument(Name) ++ "fn() = ..., ms)`")
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
%% `Peer.computeAnywhere`, the module's own functions as the checker
%% resolved them, not names spelled so.
spawn_name(#remote_declaration{namespace = ['Peer'], member_of = undefined, name = Name})
  when Name =:= spawn; Name =:= spawnMonitored; Name =:= compute; Name =:= computeAnywhere ->
    Name;
spawn_name(_) ->
    none.

%% Report §11.2, §3.11: what `:type` says of one of the five primitives
%% on a second line, and of `Code.running` what its variables are
%% (Appendix E.28); none of any other name.
-spec primitive_note(term()) -> [string()].
primitive_note(Referent) ->
    case {spawn_name(Referent), is_running(Referent)} of
        {none, false} -> [];
        {none, true} -> ["a primitive: called where it is named; a is the name of a top-level fn"
                         " and m its mailbox type"];
        _ -> ["a primitive: called where it is named"]
    end.

%% The operation as a message names it.
operation_text(Name) ->
    "Peer." ++ atom_to_list(Name).

%% Appendix E.27: the peer's name an operation takes before its function,
%% as a help writes the call: every one's but `Peer.computeAnywhere`'s,
%% whose peer the node picks.
peer_argument(computeAnywhere) -> "";
peer_argument(_) -> "name, ".

%% The function the operation takes among its arguments, at its position
%% among its parameters: after the peer's name, where it takes one.
function_position(computeAnywhere) -> 1;
function_position(_) -> 2.

%% Appendix E.28: `Code.running`, the module's own function as the checker
%% resolved it, not a name spelled so.
is_running(#remote_declaration{namespace = ['Code'], member_of = undefined, name = running}) ->
    true;
is_running(_) ->
    false.

%% Appendix E.28: the function `Code.running` names is a top-level `fn`
%% declaration of any arity, which has a hash, whose result type is Unit
%% and whose mailbox type, where it has one, holds no type variable, read
%% from its declaration and not from this use, since every process listed
%% has it as its mailbox type; one that receives nothing, and one that is
%% process-only, list their processes at Never
%% (ern_typecheck:is_running_never/2). Report §11.5: the rule is E.28's, so
%% no help cites the report.
running([#e_var{span = Span, namespace = Namespace, name = Name, referent = Referent}], Env) ->
    Written = ern_namespace:text(Namespace ++ [Name]),
    Help = "name a top-level `fn` of this program whose result type is Unit",
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
                             "declare " ++ Written ++ " with `fn` and name it,"
                             " `Code.running(" ++ Written ++ ")`"),
            ern_typecheck:is_foreign(Referent, Env)
                andalso fail(Span, What(" is a foreign declaration, which has no hash"),
                             "declare a top-level `fn` that calls " ++ Written ++ ", and name"
                             " it"),
            Scheme = ern_typecheck:declaration_scheme(Referent, Env),
            declared_running(Span, {Written, atom_to_list(Name)}, Scheme,
                             ern_typecheck:is_running_never(Referent, Env), Env)
    end;
running([Function], _Env) ->
    fail(ern_ast:span(Function),
         "Code.running lists the processes that run a declaration, and "
         ++ running_argument(Function) ++ " is no declaration",
         "declare the function with `fn` at the top level and name it").

%% What `Code.running` was given where no name stands, as its message
%% names it.
running_argument(#e_lambda{}) -> "a lambda";
running_argument(#e_call{}) -> "a function a call answers";
running_argument(_) -> "a function an expression computes".

%% The declaration's type: its result Unit, and its mailbox type, where its
%% processes are not listed at Never, known whole, holding no type variable.
%% The type is the declaration's as the checker holds it, a scheme's own
%% variables apart from the type state's (ern_typecheck:declaration_type/2),
%% and prints so; its variables are read in a state of none, since no
%% substitution here applies to a scheme's own.
declared_running(Span, {Written, Declared}, Scheme, Never, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    {tfn, _, Effect, Result} = ern_typecheck:declaration_type(Scheme, TypeState),
    Shown = fun(Type) ->
                ern_types:format_scheme(Scheme#scheme{type = Type, requirement = []}, TypeState)
            end,
    case Result of
        {tcon, ['Unit'], []} -> ok;
        _ -> fail(Span, "Code.running lists the processes that run " ++ Written
                        ++ ", whose result type is " ++ Shown(Result) ++ ", not Unit",
                  "name the function the processes run, a top-level `fn` whose result type is"
                  " Unit")
    end,
    case Never orelse ern_types:free_variables(Effect, ern_types:new()) =:= [] of
        true ->
            ok;
        false ->
            fail(Span, "Code.running lists the processes that run " ++ Written
                       ++ ", whose mailbox type " ++ Shown(Effect) ++ " holds a type variable",
                 "give " ++ Written ++ " its mailbox type, `fn " ++ Declared
                 ++ "(...) : Unit receiving Msg = ...`: every process listed has it")
    end.

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
    mailbox_crosses(Name, ern_ast:span(Function), Mailbox, Scope, Env).

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
            fail(Span, does(Name) ++ atom_to_list(Local) ++ ", a function that came as"
                       " a value, whose captures the compiler does not see",
                 "write the lambda at " ++ act(Name) ++ ", bind it with `let`, or declare it"
                 " with `fn`, in this definition")
    end;
captures(Name, #e_var{span = Span, name = Declared, referent = Referent}, _Scope, Env) ->
    case ern_typecheck:is_top_let(Referent, Env) of
        false ->
            [];
        true ->
            fail(Span, does(Name) ++ atom_to_list(Declared) ++ ", a top-level `let`,"
                       " whose value may hold captures the compiler does not see",
                 "declare it with `fn`, or write a lambda at " ++ act(Name))
    end;
captures(Name, Function, _Scope, _Env) ->
    fail(ern_ast:span(Function),
         does(Name) ++ what_function(Function) ++ ", whose captures the compiler does"
                 " not see",
         "write the lambda at " ++ act(Name) ++ ", bind it with `let`, or declare it with"
         " `fn`, in this definition").

%% Report §3.11, §11.5: what a function the compiler does not see the
%% captures of is, as the message names it: a call's answer, the callee
%% named where it is a name, a field read, or else an expression.
what_function(#e_call{callee = #e_var{namespace = Namespace, name = Callee}, args = Args}) ->
    Arguments = case Args of
                    [] -> "()";
                    _ -> "(...)"
                end,
    "`" ++ ern_namespace:text(Namespace ++ [Callee]) ++ Arguments ++ "`, a function a call answers";
what_function(#e_call{}) ->
    "a function a call answers";
what_function(#e_selection{field = Field}) ->
    "the field " ++ atom_to_list(Field) ++ ", a function read from a value";
what_function(_) ->
    "a function an expression computes".

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
                 does(Name) ++ "a function that uses "
                     ++ string:trim(ern_types:format(Variable, TypeState), trailing, "=+")
                     ++ "." ++ atom_to_list(Member) ++ ", a member of the requirement in force,"
                     " which is a function bound to its node",
                 "give the process what it needs as a value it captures, or "
                 ++ here(Name))
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
    case crossing(Substituted, Env) of
        crosses ->
            ok;
        variable ->
            fail(Span, "the function " ++ does(Name) ++ "captures " ++ atom_to_list(Local)
                       ++ ", whose type " ++ Text ++ " holds a type variable",
                 "capture a value whose type is known whole: compute what the process needs of "
                 ++ atom_to_list(Local) ++ " before " ++ act(Name) ++ " and capture that");
        {bound, Why} ->
            %% a function's type at its use has the effect of its use's
            %% context (§3.9), not the binding's, so it is named, not shown
            What = case ern_types:resolve(Substituted, TypeState) of
                       {tfn, _, _, _} -> ", a function, which is bound to its node";
                       _ ->
                           case resource_message(ern_types:resolve(Substituted, TypeState)) of
                               {Phrase, _} ->
                                   ", whose type " ++ Text ++ ", " ++ Phrase
                                   ++ ", is bound to its node";
                               none ->
                                   ", whose type " ++ Text ++ " is bound to its node, since it"
                                   " holds " ++ Why
                           end
                   end,
            fail(Span, "the function " ++ does(Name) ++ "captures " ++ atom_to_list(Local)
                       ++ What,
                 "compute what the process needs of " ++ atom_to_list(Local) ++ " before "
                 ++ act(Name) ++ " and capture that, or " ++ here(Name))
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
    case crossing(Substituted, Env) of
        crosses ->
            ok;
        variable ->
            fail(Span, operation_text(Name) ++ " answers a value of type " ++ Text
                       ++ ", which holds a type variable, so whether it crosses is not known here",
                 "give the function its result type, `fn() : "
                 ++ ern_types:format_annotation(Substituted, TypeState)
                 ++ " = ...`: the value crosses back to this node, and its type is"
                 " known whole by the end of the definition the compute is written in");
        {bound, Why} ->
            fail(Span, operation_text(Name) ++ " answers a value of type "
                       ++ bound_text(Substituted, Text, Why),
                 "answer a value that crosses, from which this node builds what it needs")
    end.

%% A mailbox type that is still a variable is one an annotation names or
%% each call of the definition fixes, since one nothing fixed is Never by
%% now, and an instance of the definition could make it a bound type.
%% Report §11.5: where the variable is one the signature writes, that
%% annotation is labeled, and the help writes the type in its place.
mailbox_crosses(Name, Span, Mailbox, Scope, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    Text = ern_types:format(Mailbox, TypeState),
    Written = ern_types:annotation_name(Mailbox, TypeState),
    case {crossing(Mailbox, Env), ern_types:resolve(Mailbox, TypeState)} of
        {crosses, _} ->
            ok;
        {variable, {tvar, _}} when is_map_key({annotation, Written}, Scope) ->
            fail(Span, operation_text(Name) ++ " starts a process whose mailbox type " ++ Text
                       ++ " is not known whole here",
                 [{ern_diagnostic:span(maps:get({annotation, Written}, Scope)),
                   "the signature writes " ++ atom_to_list(Written) ++ " here"}],
                 "write the mailbox type in place of " ++ atom_to_list(Written));
        {variable, {tvar, _}} ->
            fail(Span, operation_text(Name) ++ " starts a process whose mailbox type " ++ Text
                       ++ " is not known whole here",
                 "give the function its mailbox type, " ++ annotated(Name) ++ ": an instance of"
                 " this definition could make the variable a type bound to its node");
        {variable, _} ->
            fail(Span, operation_text(Name) ++ " starts a process whose mailbox type " ++ Text
                       ++ " is not known whole here",
                 "give the function its mailbox type, " ++ annotated(Name) ++ ": a type"
                 " variable in it could stand for a type bound to its node");
        {{bound, _}, Resolved} when Resolved =:= ?SOCKET_MSG; Resolved =:= ?LISTENER_MSG;
                                    Resolved =:= ?PROGRAM_MSG ->
            %% report §3.11: a process that takes a resource's messages is
            %% the runtime's, and the program's own stands in its place
            {Phrase, Held} = resource_message(Resolved),
            fail(Span, operation_text(Name) ++ " starts a process at " ++ Text ++ ", " ++ Phrase
                       ++ ", which is bound to its node",
                 "start a process of the program's own, which holds the " ++ Held
                 ++ " and takes values that cross");
        {{bound, Why}, _} ->
            %% report §6.5, §8.7: the process is started on the peer at its
            %% own mailbox type, and an adapted address of a type that
            %% crosses reaches it from elsewhere
            fail(Span, operation_text(Name) ++ " starts a process whose mailbox type " ++ Text
                       ++ " is bound to its node, since it holds " ++ Why,
                 started_there(Name) ++ ", or keep " ++ Why ++ " on this node and send the"
                 " process values that cross")
    end.

%% Report §3.11: whether a value of the type crosses to another node, as a
%% capture, a compute's answer and a process's mailbox type are asked:
%% `crosses`, `variable` where it holds a type variable, which an instance
%% could make bound, or `{bound, Why}`, Why what binds it. Report §11.5: a
%% type variable a failed definition left open is that definition's error,
%% and crosses here.
crossing(Type, Env) ->
    TypeState = ern_typecheck:type_state(Env),
    case binds(Type, Env) of
        false ->
            case ern_types:free_variables(Type, TypeState) =:= []
                 orelse ern_types:is_unknown(Type, TypeState) of
                true -> crosses;
                false -> variable
            end;
        Why ->
            {bound, Why}
    end.

%% Appendix E.27: whether the operation is a compute, on a peer named or on
%% one the node picks, whose function's value crosses back.
is_compute(Name) ->
    Name =:= compute orelse Name =:= computeAnywhere.

%% The operation and what it does with its function, in the report's
%% words (§3.11): a spawn starts it, a compute runs it; and the operation
%% as a help names it, the one written.
does(Name) -> operation_text(Name) ++ by_kind(Name, " runs ", " starts ").

act(Name) -> by_kind(Name, "the compute", "the spawn").

here(Name) -> by_kind(Name, "run the function on this node, `f()`", "spawn on this node").

started_there(Name) ->
    by_kind(Name, "spawn the process in the function the compute runs, which answers an adapted"
                  " address of a type that crosses",
            "start it on the peer from `Peer.compute`, whose function spawns it and answers an"
            " adapted address of a type that crosses").

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
    fail(Span, Message, [], Help).

-spec fail(term(), string(), [{ern_diagnostic:span(), string()}], string()) -> no_return().
fail(Span, Message, Labels, Help) ->
    throw({type_error, #diagnostic{span = ern_diagnostic:span(Span),
                                   message = lists:flatten(Message), labels = Labels,
                                   help = Help}}).
