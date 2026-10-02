%% The reply discipline, report §6.6: Reply(a) is linear. Every variable
%% bound to a reply-carrying value is used exactly once on every path;
%% a use is any occurrence, since the type checker already guarantees that
%% every position such a value can occupy is a consuming one. Also: no `as`
%% on a reply-carrying value; no wildcard or omitted reply-carrying field;
%% a lambda that captures a linear variable is linear itself: consumed
%% exactly once, by a call or as spawn's direct argument, bindable by let,
%% and legal nowhere else. Linear holds a name N for a value and {lambda, N}
%% for such a lambda bound by let.
%%
%% A path with a call that does not return, to a function whose result type
%% is a variable no parameter's type names, `fault` among them, consumes
%% every obligation open on it (§6.6): its uses carry the mark
%% {'$fault', Pos}, which no name is, so a branch that faults is left out of
%% the comparison of branches,
%% and a name a faulting path leaves unconsumed is not a name never
%% consumed. The mark does not leave a lambda or a local function, whose
%% bodies are not on the enclosing path.
%%
%% Report §3.9: a type variable of a parameter's type gets the no_reply flag
%% when the body, read with that variable taken for reply-carrying, would
%% break this discipline: a second use or none, through a `let` or a
%% pattern as much as by the parameter's own name, a place a reply may not
%% stand, or a user type that carries one dropped.
-module(ern_reply).

-export([check/4]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

-spec check([#param{}], tuple(), ern_types:type(), ern_typecheck:env()) ->
          ern_typecheck:env().
check(Params, Body, FnT, Env) ->
    discipline(Params, Body, Env),
    St = ern_typecheck:type_state(Env),
    Vars = lists:usort(param_vars(FnT, St)),
    lists:foldl(fun(V, E) ->
                    case holds(Params, Body, ern_typecheck:assume_reply_carrying([V], E)) of
                        true -> E;
                        false ->
                            ern_typecheck:set_type_state(
                              ern_types:add_flag(V, no_reply, ern_typecheck:type_state(E)), E)
                    end
                end, Env, Vars).

%% The whole discipline over one function: its illegal positions, and each
%% linear parameter consumed exactly once.
discipline(Params, Body, Env) ->
    positions(Params, Env),
    positions(Body, Env),
    Linear = [N || P <- Params, N <- linear_bindings(P#param.pattern, Env)],
    Uses = uses(Body, Linear, Env),
    lists:foreach(fun(N) -> exactly_once(N, Uses, element(2, Body)) end, Linear).

%% Would the body keep the discipline under this environment's assumption?
holds(Params, Body, Env) ->
    try
        discipline(Params, Body, Env),
        true
    catch
        throw:{type_error, _, _} -> false;
        throw:{type_error, #diagnostic{}} -> false
    end.

%% The type variables of the parameters' types, where values stand: not a
%% function type's effect.
param_vars(FnT, St) ->
    case ern_types:resolve(FnT, St) of
        {tfn, Ps, _, _} -> lists:append([value_vars(T, St) || T <- Ps]);
        _ -> []
    end.

value_vars(T, St) ->
    case ern_types:resolve(T, St) of
        {tvar, _} = V -> [V];
        {tcon, _, Args} -> lists:append([value_vars(A, St) || A <- Args]);
        {ttuple, Es} -> lists:append([value_vars(E, St) || E <- Es]);
        {tfn, Ps, _, R} -> lists:append([value_vars(X, St) || X <- [R | Ps]]);
        _ -> []
    end.

%%
%% Illegal positions and patterns
%%

positions(Node, Env) ->
    walk(fun(N) -> position(N, Env) end, Node).

position(#p_wild{pos = Pos, type = T}, Env) ->
    case ern_typecheck:is_reply_carrying(T, Env) of
        true -> throw({type_error, Pos, "`_` would discard a reply-carrying value"});
        false -> ok
    end;
position(#p_as{pos = Pos, type = T}, Env) ->
    case ern_typecheck:is_reply_carrying(T, Env) of
        true -> throw({type_error, Pos, "`as` on a reply-carrying value would duplicate it"});
        false -> ok
    end;
position(#p_con{pos = Pos, path = Path, name = Name, args = Args, type = T}, Env) ->
    case ern_typecheck:is_reply_carrying(T, Env) of
        false -> ok;
        true ->
            #cinfo{fields = Fields, scheme = Scheme} =
                ern_typecheck:lookup_con(Pos, Path, Name, Env),
            %% instantiate the constructor at the pattern's type to see the
            %% field types as they are here
            St0 = ern_typecheck:type_state(Env),
            {CT, St1} = ern_types:instantiate(Scheme, St0),
            {FieldTs, ResT} = case CT of {tfn, Fs, _, R} -> {Fs, R}; R -> {[], R} end,
            %% the pattern was checked as this constructor, so this unifies
            {ok, St2} = ern_types:unify(ResT, T, St1),
            Env1 = ern_typecheck:set_type_state(St2, Env),
            case {Fields, Args} of
                {positional, {positional, #p_wild{}}} ->
                    wild_field(Pos, Name, FieldTs, Env1);
                {{named, Names}, {named, FPs}} ->
                    lists:foreach(
                      fun({N, FT}) ->
                              case [P || #field_pat{name = FN, pattern = P} <- FPs, FN =:= N] of
                                  [#p_wild{}] -> reply_field(Pos, Name, N, FT, Env1);
                                  [] -> reply_field(Pos, Name, N, FT, Env1);
                                  _ -> ok
                              end
                      end, lists:zip(Names, FieldTs));
                _ -> ok
            end
    end;
position(_, _) -> ok.

wild_field(Pos, Name, [FT], Env) ->
    case ern_typecheck:is_reply_carrying(FT, Env) of
        true -> throw({type_error, Pos, "the field of " ++ atom_to_list(Name)
                                        ++ " carries a reply and cannot be `_`"});
        false -> ok
    end;
wild_field(_, _, _, _) -> ok.

reply_field(Pos, Name, Field, FT, Env) ->
    case ern_typecheck:is_reply_carrying(FT, Env) of
        true -> throw({type_error, Pos, "field " ++ atom_to_list(Field) ++ " of "
                                        ++ atom_to_list(Name) ++ " carries a reply and must be"
                                        " bound"});
        false -> ok
    end.

%%
%% Uses of linear variables, per path
%%

%% uses(Expr, Linear, Env) -> [Name], one entry per use on the path; a
%% variable twice in the list is an error raised where it happens.
uses(#e_var{pos = Pos, path = [], name = N}, Linear, _Env) ->
    case lists:member(N, Linear) of
        true -> [{N, Pos}];
        false ->
            case lists:member({lambda, N}, Linear) of
                true -> throw({type_error, Pos, "the lambda " ++ atom_to_list(N)
                                                ++ " captures a reply-carrying value and may only"
                                                " be called or passed directly to spawn or"
                                                " spawnMonitored"});
                false -> []
            end
    end;
uses(#e_call{pos = Pos, returns = false} = Call, Linear, Env) ->
    seq([uses(Call#e_call{returns = true}, Linear, Env), [{'$fault', Pos}]]);
uses(#e_call{callee = #e_var{ref = {prelude, [Spawn]}}, args = [Arg | Wrap]}, Linear, Env)
  when Spawn =:= spawn, Wrap =:= []; Spawn =:= spawnMonitored, length(Wrap) =:= 1 ->
    %% report §6.6: the function argument of spawn or spawnMonitored
    %% consumes a capturing lambda; each is the prelude's as the checker
    %% resolved it, not a name spelled so
    ArgUses = case Arg of
                  #e_lambda{} -> captures(Arg, Linear, Env);
                  #e_var{pos = Pos, path = [], name = F} ->
                      case lists:member({lambda, F}, Linear) of
                          true -> [{F, Pos}];
                          false -> uses(Arg, Linear, Env)
                      end;
                  _ -> uses(Arg, Linear, Env)
              end,
    seq([ArgUses | [uses(W, Linear, Env) || W <- Wrap]]);
uses(#e_call{pos = Pos, callee = #e_var{path = [], name = F}, args = Args}, Linear, Env) ->
    %% a call consumes a capturing lambda bound by let
    Callee = case lists:member({lambda, F}, Linear) of
                 true -> [{F, Pos}];
                 false -> []
             end,
    seq([Callee, uses(Args, Linear, Env)]);
uses(#e_call{callee = #e_lambda{} = L, args = Args}, Linear, Env) ->
    %% a call consumes the lambda's captures
    seq([captures(L, Linear, Env), uses(Args, Linear, Env)]);
uses(#e_lambda{pos = Pos} = L, Linear, Env) ->
    case captures(L, Linear, Env) of
        [] -> [];
        [{N, _} | _] -> throw({type_error, Pos, "the reply-carrying value " ++ atom_to_list(N)
                                                ++ " is captured by a lambda that is not called,"
                                                " bound by `let`, or passed directly to spawn or"
                                                " spawnMonitored"})
    end;
uses(#fn_decl{pos = Pos, body = Body}, Linear, Env) ->
    case [N || {N, _} <- uses(Body, Linear, Env), N =/= '$fault'] of
        [] -> [];
        [N | _] -> throw({type_error,
                          #diagnostic{span = ern_diagnostic:span(Pos),
                                      message = "the reply-carrying value " ++ atom_to_list(N)
                                                ++ " is captured by a local function",
                                      help = "a local fn may be called many times; pass "
                                             ++ atom_to_list(N) ++ " to it as a parameter"}})
    end;
uses(#e_if{pos = Pos, condition = C, then_branch = T, else_branch = E}, Linear, Env) ->
    seq([uses(C, Linear, Env), branches(Pos, [{element(2, T), uses(T, Linear, Env)},
                                              {element(2, E), uses(E, Linear, Env)}])]);
uses(#e_match{pos = Pos, scrutinee = S, clauses = Clauses}, Linear, Env) ->
    seq([uses(S, Linear, Env), branches(Pos, [{element(2, B), clause_uses(C, Linear, Env)}
                                              || #clause{body = B} = C <- Clauses])]);
uses(#e_receive{pos = Pos, clauses = Clauses, 'after' = After}, Linear, Env) ->
    AfterUses = case After of
                    undefined -> [];
                    #after_clause{timeout = T, body = B} ->
                        [{element(2, B), seq([uses(T, Linear, Env), uses(B, Linear, Env)])}]
                end,
    branches(Pos, [{element(2, B), clause_uses(C, Linear, Env)} || #clause{body = B} = C <- Clauses]
                  ++ AfterUses);
uses(#e_block{stmts = Stmts}, Linear, Env) ->
    block_uses(Stmts, Linear, Env, []);
uses(Node, Linear, Env) when is_tuple(Node) ->
    seq([uses(X, Linear, Env) || X <- tl(tuple_to_list(Node))]);
uses(L, Linear, Env) when is_list(L) ->
    seq([uses(X, Linear, Env) || X <- L]);
uses(_, _, _) ->
    [].

clause_uses(#clause{pos = Pos, pattern = P, guard = G, body = B}, Linear, Env) ->
    Inner = linear_bindings(P, Env),
    GuardUses = case G of undefined -> []; _ -> uses(G, Linear ++ Inner, Env) end,
    All = seq([GuardUses, uses(B, Linear ++ Inner, Env)]),
    lists:foreach(fun(N) -> exactly_once(N, All, Pos) end, Inner),
    [U || {N, _} = U <- All, not lists:member(N, Inner)].

block_uses([], _Linear, _Env, Acc) ->
    seq(lists:reverse(Acc));
block_uses([#binding{pos = Pos, pattern = #p_var{name = F}, expr = #e_lambda{} = L} = B | Rest],
           Linear, Env, Acc) ->
    %% a let bound to a capturing lambda is a linear binding of the lambda
    case captures(L, Linear, Env) of
        [] ->
            binding_uses(B, Rest, Linear, Env, Acc);
        Caps ->
            RestUses = block_uses(Rest, [{lambda, F} | Linear], Env, []),
            exactly_once(F, RestUses, Pos),
            Outer = [U || {N, _} = U <- RestUses, N =/= F],
            seq(lists:reverse([Outer, Caps | Acc]))
    end;
block_uses([#binding{} = B | Rest], Linear, Env, Acc) ->
    binding_uses(B, Rest, Linear, Env, Acc);
block_uses([S | Rest], Linear, Env, Acc) ->
    block_uses(Rest, Linear, Env, [uses(S, Linear, Env) | Acc]).

%% A `let`: each linear name its pattern binds is consumed once by the rest
%% of the block.
binding_uses(#binding{pos = Pos, pattern = P, expr = X}, Rest, Linear, Env, Acc) ->
    XUses = uses(X, Linear, Env),
    Inner = linear_bindings(P, Env),
    RestUses = block_uses(Rest, Linear ++ Inner, Env, []),
    lists:foreach(fun(N) -> exactly_once(N, RestUses, Pos) end, Inner),
    Outer = [U || {N, _} = U <- RestUses, not lists:member(N, Inner)],
    seq(lists:reverse([Outer, XUses | Acc])).

%% The uses a lambda's body makes of the enclosing linear names: its
%% captures, each consumed once by the capture. The lambda's own linear
%% parameters are checked here.
captures(#e_lambda{pos = Pos, params = Params, body = Body}, Linear, Env) ->
    Inner = [N || P <- Params, N <- linear_bindings(P#param.pattern, Env)],
    BodyUses = uses(Body, Linear ++ Inner, Env),
    lists:foreach(fun(N) -> exactly_once(N, BodyUses, Pos) end, Inner),
    [U || {N, _} = U <- BodyUses, not lists:member(N, Inner), N =/= '$fault'].

%% Sequential composition: a second use of a name is an error there.
seq(Lists) ->
    lists:foldl(fun(Uses, Acc) ->
                    lists:foreach(fun({'$fault', _}) ->
                                      ok;
                                     ({N, Pos}) ->
                                      %% report §11.5: at the second use,
                                      %% the first labelled
                                      case lists:keyfind(N, 1, Acc) of
                                          {N, First} ->
                                              throw({type_error,
                                                     #diagnostic{span = ern_diagnostic:span(Pos),
                                                                 message = "the reply-carrying"
                                                                           " value "
                                                                           ++ atom_to_list(N)
                                                                           ++ " is consumed twice",
                                                                 labels =
                                                                     [{ern_diagnostic:span(First),
                                                                       "first consumed here"}]}});
                                          false -> ok
                                      end
                                  end, Uses),
                    Acc ++ Uses
                end, [], Lists).

%% Branches must consume the same names, but for a branch that faults.
%% Where every branch faults, the whole faults.
%% Branches: each path's span and its uses. A path that faults consumes
%% every obligation (§6.6), and the others must agree; report §11.5: one
%% that lacks a use is reported where it stands, the use on another path
%% labelled.
branches(Pos, Branches) ->
    case [B || {_, U} = B <- Branches, not lists:keymember('$fault', 1, U)] of
        [] when Branches =/= [] -> [{'$fault', Pos}];
        Returning -> compared(Returning)
    end.

compared([]) ->
    [];
compared([{_, First} | _] = Branches) ->
    Names = lists:usort([N || {_, U} <- Branches, {N, _} <- U]),
    lists:foreach(fun(N) ->
                      case [S || {S, U} <- Branches, not lists:keymember(N, 1, U)] of
                          [] ->
                              ok;
                          [Lacking | _] ->
                              [Used | _] = [P || {_, U} <- Branches, {M, P} <- U, M =:= N],
                              throw({type_error,
                                     #diagnostic{span = ern_diagnostic:span(Lacking),
                                                 message = "the reply-carrying value "
                                                           ++ atom_to_list(N)
                                                           ++ " is not consumed on this path",
                                                 labels = [{ern_diagnostic:span(Used),
                                                            "consumed here, on another path"}]}})
                      end
                  end, Names),
    First.

exactly_once(N, Uses, Pos) ->
    case {count(N, Uses), lists:keymember('$fault', 1, Uses)} of
        {1, _} -> ok;
        {0, true} -> ok;
        {0, false} -> throw({type_error, Pos, "the reply-carrying value " ++ atom_to_list(N)
                                     ++ " is never consumed"});
        {_, _} -> ok  % the second use was reported by seq
    end.

count(N, Uses) -> length([x || {M, _} <- Uses, M =:= N]).

%% Variables a pattern binds to reply-carrying values.
linear_bindings(P, Env) ->
    [N || {N, T} <- ern_ast:pattern_bindings(P),
          ern_typecheck:is_reply_carrying(T, Env)].

walk(F, Node) ->
    ern_ast:walk(fun(N, ok) -> F(N), ok end, Node, ok).
