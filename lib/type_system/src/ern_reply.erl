%% The reply discipline, report §6.6: Reply(a) is linear. Every variable
%% bound to a reply-carrying value is used exactly once on every path;
%% a use is any occurrence, since the type checker already guarantees that
%% every position such a value can occupy is a consuming one. Also: no
%% reply-carrying elements in List, Map, Set, Optional, or Either; no `as`
%% on a reply-carrying value; no wildcard or omitted reply-carrying field;
%% a lambda captures a linear variable only as spawn's direct argument.
%%
%% A polymorphic parameter that is used other than exactly once gets the
%% no_reply flag on its type variable (report §3.9).
-module(ern_reply).

-export([check/3]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").

-define(CONTAINERS, [['List'], ['Map'], ['Set'], ['Optional'], ['Either']]).

-spec check([#param{}], tuple(), ern_typecheck:env()) -> ern_typecheck:env().
check(Params, Body, Env) ->
    positions(Params, Env),
    positions(Body, Env),
    Linear = [N || P <- Params, N <- linear_bindings(P#param.pattern, Env)],
    Uses = uses(Body, Linear, Env),
    lists:foreach(fun(N) -> exactly_once(N, Uses, element(2, Body), Env) end, Linear),
    %% polymorphic parameter variables used other than once
    lists:foldl(fun({N, T}, E) ->
                    St = ern_typecheck:type_state(E),
                    case ern_types:resolve(T, St) of
                        {tvar, _} = V ->
                            case used_exactly_once(N, Body, E) of
                                true -> E;
                                false -> ern_typecheck:set_type_state(
                                           ern_types:add_flag(V, no_reply, St), E)
                            end;
                        _ -> E
                    end
                end, Env, [B || P <- Params, B <- var_bindings(P#param.pattern)]).

var_bindings(#p_var{name = N, type = T}) -> [{N, T}];
var_bindings(#p_as{name = N, type = T, pattern = P}) -> [{N, T} | var_bindings(P)];
var_bindings(#p_con{args = {positional, P}}) -> var_bindings(P);
var_bindings(#p_con{args = {named, FPs}}) ->
    lists:append([var_bindings(P) || #field_pat{pattern = P} <- FPs]);
var_bindings(#p_tuple{elems = Es}) -> lists:append([var_bindings(E) || E <- Es]);
var_bindings(#p_list{elems = Es}) -> lists:append([var_bindings(E) || E <- Es]);
var_bindings(#p_cons{head = H, tail = T}) -> var_bindings(H) ++ var_bindings(T);
var_bindings(#p_or{alts = [A | _]}) -> var_bindings(A);
var_bindings(_) -> [].

%% Would N pass the discipline if it were linear? A second use or a
%% path mismatch throws; both mean no.
used_exactly_once(N, Body, Env) ->
    try
        count(N, uses(Body, [N], Env)) =:= 1
    catch
        throw:{type_error, _, _} -> false
    end.

%%
%% Illegal positions and patterns
%%

positions(Node, Env) ->
    walk(fun(N) -> position(N, Env) end, Node).

position(#e_list{pos = Pos, type = T}, Env) -> container(Pos, T, Env);
position(#e_call{pos = Pos, type = T}, Env) -> container(Pos, T, Env);
position(#e_var{pos = Pos, type = T}, Env) -> container(Pos, T, Env);
position(#e_con{pos = Pos, type = T}, Env) -> container(Pos, T, Env);
position(#p_wild{pos = Pos, type = T}, Env) ->
    case ern_typecheck:is_reply_carrying(T, Env) of
        true -> throw({type_error, Pos, "`_` would discard a reply-carrying value"});
        false -> ok
    end;
position(#e_block{stmts = Stmts}, Env) ->
    %% every statement but the last is discarded
    lists:foreach(fun(#binding{}) -> ok;
                     (#fn_decl{}) -> ok;
                     (X) ->
                          T = ern_typecheck:node_type(X),
                          case ern_typecheck:is_reply_carrying(T, Env) of
                              true -> throw({type_error, element(2, X),
                                             "a reply-carrying value is discarded; it must be"
                                             " consumed"});
                              false -> ok
                          end
                  end, lists:droplast(Stmts));
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
            St2 = case ern_types:unify(ResT, T, St1) of {ok, S} -> S; _ -> St1 end,
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
position(#p_or{alts = Alts}, Env) -> lists:foreach(fun(A) -> position(A, Env) end, Alts);
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

container(Pos, T, Env) ->
    case ern_typecheck:resolve_type(T, Env) of
        {tcon, Q, Args} ->
            case lists:member(Q, ?CONTAINERS) andalso
                 lists:any(fun(A) -> ern_typecheck:is_reply_carrying(A, Env) end, Args) of
                true -> throw({type_error, Pos, "a reply-carrying value cannot be an element of "
                                                ++ atom_to_list(lists:last(Q))});
                false -> ok
            end;
        _ -> ok
    end.

%%
%% Uses of linear variables, per path
%%

%% uses(Expr, Linear, Env) -> [Name], one entry per use on the path; a
%% variable twice in the list is an error raised where it happens.
uses(#e_var{pos = Pos, path = [], name = N}, Linear, _Env) ->
    case lists:member(N, Linear) of
        true -> [{N, Pos}];
        false -> []
    end;
uses(#e_call{callee = #e_var{path = [], name = spawn}, args = [Where, #e_lambda{} = L]},
     Linear, Env) ->
    %% a lambda passed directly to spawn may capture linear variables
    seq([uses(Where, Linear, Env), uses(L#e_lambda.body, Linear, Env)]);
uses(#e_lambda{pos = Pos, params = Params, body = Body}, Linear, Env) ->
    Inner = [N || P <- Params, N <- linear_bindings(P#param.pattern, Env)],
    BodyUses = uses(Body, Linear ++ Inner, Env),
    lists:foreach(fun(N) -> exactly_once(N, BodyUses, Pos, Env) end, Inner),
    case [N || {N, _} <- BodyUses, lists:member(N, Linear)] of
        [] -> [];
        [N | _] -> throw({type_error, Pos, "the reply-carrying value " ++ atom_to_list(N)
                                           ++ " is captured by a lambda that is not passed"
                                           " directly to spawn"})
    end;
uses(#fn_decl{pos = Pos, body = Body}, Linear, Env) ->
    case [N || {N, _} <- uses(Body, Linear, Env)] of
        [] -> [];
        [N | _] -> throw({type_error, Pos, "the reply-carrying value " ++ atom_to_list(N)
                                           ++ " is captured by a local function"})
    end;
uses(#e_if{pos = Pos, condition = C, then_branch = T, else_branch = E}, Linear, Env) ->
    seq([uses(C, Linear, Env), branches(Pos, [uses(T, Linear, Env), uses(E, Linear, Env)], Env)]);
uses(#e_match{pos = Pos, scrutinee = S, clauses = Clauses}, Linear, Env) ->
    seq([uses(S, Linear, Env), branches(Pos, [clause_uses(C, Linear, Env) || C <- Clauses], Env)]);
uses(#e_receive{pos = Pos, clauses = Clauses, 'after' = After}, Linear, Env) ->
    AfterUses = case After of
                    undefined -> [];
                    #after_clause{timeout = T, body = B} ->
                        [seq([uses(T, Linear, Env), uses(B, Linear, Env)])]
                end,
    branches(Pos, [clause_uses(C, Linear, Env) || C <- Clauses] ++ AfterUses, Env);
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
    lists:foreach(fun(N) -> exactly_once(N, All, Pos, Env) end, Inner),
    [U || {N, _} = U <- All, not lists:member(N, Inner)].

block_uses([], _Linear, _Env, Acc) ->
    seq(lists:reverse(Acc));
block_uses([#binding{pos = Pos, pattern = P, expr = X} | Rest], Linear, Env, Acc) ->
    XUses = uses(X, Linear, Env),
    Inner = linear_bindings(P, Env),
    RestUses = block_uses(Rest, Linear ++ Inner, Env, []),
    lists:foreach(fun(N) -> exactly_once(N, RestUses, Pos, Env) end, Inner),
    Outer = [U || {N, _} = U <- RestUses, not lists:member(N, Inner)],
    seq(lists:reverse([Outer, XUses | Acc]));
block_uses([S | Rest], Linear, Env, Acc) ->
    block_uses(Rest, Linear, Env, [uses(S, Linear, Env) | Acc]).

%% Sequential composition: a second use of a name is an error there.
seq(Lists) ->
    lists:foldl(fun(Uses, Acc) ->
                    lists:foreach(fun({N, Pos}) ->
                                      case lists:keymember(N, 1, Acc) of
                                          true -> throw({type_error, Pos,
                                                         "the reply-carrying value "
                                                         ++ atom_to_list(N)
                                                         ++ " is consumed twice"});
                                          false -> ok
                                      end
                                  end, Uses),
                    Acc ++ Uses
                end, [], Lists).

%% Branches must consume the same names.
branches(_Pos, [], _Env) ->
    [];
branches(Pos, [First | Others], _Env) ->
    Names = lists:usort([N || {N, _} <- First]),
    lists:foreach(fun(Other) ->
                      case lists:usort([N || {N, _} <- Other]) of
                          Names -> ok;
                          Ns ->
                              [N | _] = (Names -- Ns) ++ (Ns -- Names),
                              throw({type_error, Pos, "the reply-carrying value "
                                                      ++ atom_to_list(N)
                                                      ++ " is consumed on one path but not"
                                                      " on another"})
                      end
                  end, Others),
    First.

exactly_once(N, Uses, Pos, _Env) ->
    case count(N, Uses) of
        1 -> ok;
        0 -> throw({type_error, Pos, "the reply-carrying value " ++ atom_to_list(N)
                                     ++ " is never consumed"});
        _ -> ok  % the second use was reported by seq
    end.

count(N, Uses) -> length([x || {M, _} <- Uses, M =:= N]).

%% Variables a pattern binds to reply-carrying values.
linear_bindings(#p_var{name = N, type = T}, Env) ->
    case ern_typecheck:is_reply_carrying(T, Env) of true -> [N]; false -> [] end;
linear_bindings(#p_as{name = N, type = T, pattern = P}, Env) ->
    Own = case ern_typecheck:is_reply_carrying(T, Env) of true -> [N]; false -> [] end,
    Own ++ linear_bindings(P, Env);
linear_bindings(#p_con{args = {positional, P}}, Env) -> linear_bindings(P, Env);
linear_bindings(#p_con{args = {named, FPs}}, Env) ->
    lists:append([linear_bindings(P, Env) || #field_pat{pattern = P} <- FPs]);
linear_bindings(#p_tuple{elems = Es}, Env) -> lists:append([linear_bindings(E, Env) || E <- Es]);
linear_bindings(#p_list{elems = Es}, Env) -> lists:append([linear_bindings(E, Env) || E <- Es]);
linear_bindings(#p_cons{head = H, tail = T}, Env) ->
    linear_bindings(H, Env) ++ linear_bindings(T, Env);
linear_bindings(#p_or{alts = [A | _]}, Env) -> linear_bindings(A, Env);
linear_bindings(_, _) -> [].

walk(F, Node) when is_tuple(Node), is_atom(element(1, Node)) ->
    F(Node),
    lists:foreach(fun(X) -> walk(F, X) end, tl(tuple_to_list(Node)));
walk(F, L) when is_list(L) ->
    lists:foreach(fun(X) -> walk(F, X) end, L);
walk(_, _) ->
    ok.
