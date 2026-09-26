%% Report §5.4: the rules for a local fn, read off a definition. Its name
%% may not be one bound where it is declared (names/1); it may be used only
%% after the lets of its block it references (order/1); and what its body
%% refers to among given names (free_refs/3), which the checker's grouping
%% of a block's local fns reads too. A breach is thrown as the checker's
%% type errors are.
-module(ern_scope).

-export([names/1, order/1, free_refs/3]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("utils/include/ern_diag.hrl").

%% Report §5.4: a local fn may not take the name of a parameter or a
%% variable in scope where it is declared, nor of a `let` of its block.
%% The scope is read off the declaration as written: the variables bound
%% around each local fn, with where each is bound. A local fn of an
%% enclosing block is no variable, and one of its name may be declared.
-spec names(tuple()) -> ok.
names(#fn_decl{params = Ps, body = B}) -> fn_names(B, param_vars(Ps));
names(#let_decl{body = B}) -> fn_names(B, []);
names(_) -> ok.

fn_names(#e_lambda{params = Ps, body = B}, Vars) ->
    fn_names(B, param_vars(Ps) ++ Vars);
fn_names(#clause{pattern = P, guard = G, body = B}, Vars) ->
    Vars1 = pattern_vars(P) ++ Vars,
    fn_names(G, Vars1),
    fn_names(B, Vars1);
fn_names(#e_block{stmts = Stmts}, Vars) ->
    Lets = lists:append([pattern_vars(P) || #binding{pattern = P} <- Stmts]),
    lists:foldl(fun(#binding{pattern = P, expr = X}, Vs) ->
                        fn_names(X, Vs),
                        pattern_vars(P) ++ Vs;
                   (#fn_decl{pos = Pos, name = N, params = Ps, body = B}, Vs) ->
                        local_fn_name(Pos, N, Vs, "a variable in scope where it is declared"),
                        local_fn_name(Pos, N, Lets, "a `let` of its block"),
                        fn_names(B, param_vars(Ps) ++ Vs),
                        Vs;
                   (S, Vs) ->
                        fn_names(S, Vs),
                        Vs
                end, Vars, Stmts),
    ok;
fn_names(T, Vars) when is_tuple(T) ->
    fn_names(tl(tuple_to_list(T)), Vars);
fn_names(L, Vars) when is_list(L) ->
    lists:foreach(fun(X) -> fn_names(X, Vars) end, L);
fn_names(_, _) ->
    ok.

local_fn_name(Pos, N, Vars, What) ->
    case lists:keyfind(N, 1, Vars) of
        false ->
            ok;
        {N, At} ->
            fail(Pos, "local function " ++ atom_to_list(N) ++ " has the name of " ++ What,
                 [{ern_diag:span(At), atom_to_list(N) ++ " is bound here"}],
                 "rename the function or the variable")
    end.

param_vars(Ps) -> lists:append([pattern_vars(P) || #param{pattern = P} <- Ps]).

%% The variables a pattern binds, each with where it is bound.
pattern_vars(#p_var{pos = Pos, name = N}) -> [{N, Pos}];
pattern_vars(#p_as{pos = Pos, pattern = P, name = N}) -> [{N, Pos} | pattern_vars(P)];
pattern_vars(#p_or{alts = [A | _]}) -> pattern_vars(A);
pattern_vars(P) when is_tuple(P) -> pattern_vars(tl(tuple_to_list(P)));
pattern_vars(L) when is_list(L) -> lists:append([pattern_vars(X) || X <- L]);
pattern_vars(_) -> [].

%% Report §5.4: a local fn may be used only after every `let` of its block
%% that it references, directly or through other local fns, has been
%% evaluated. Uses are calls and value references alike.
-spec order(tuple()) -> ok.
order(Node) ->
    ern_ast:walk(fun(#e_block{stmts = Stmts}, E) -> block_order(Stmts), E;
            (_, E) -> E
         end, Node, ok),
    ok.

block_order(Stmts) ->
    Fns = [D || #fn_decl{} = D <- Stmts],
    FnNames = [N || #fn_decl{name = N} <- Fns],
    Indexed = lists:zip(lists:seq(1, length(Stmts)), Stmts),
    %% every let binding of the block as an instance {Name, Index}
    Lets = [{N, I} || {I, #binding{pattern = P}} <- Indexed, N <- pattern_names(P)],
    LetNames = lists:usort([N || {N, _} <- Lets]),
    %% what each local fn references: its siblings, and the binding of each
    %% let name in force at its declaration (report §5.4, §4.6)
    Direct = maps:from_list(
               [{N, [R || R <- free_refs(B, Params, LetNames ++ FnNames), lists:member(R, FnNames)]
                     ++ [{R, I} || R <- free_refs(B, Params, LetNames),
                                   I <- [in_force(R, D, Lets)], I =/= none]}
                || {D, #fn_decl{name = N, params = Params, body = B}} <- Indexed]),
    Needs = fun(N) -> needed_lets(N, Direct, [], []) end,
    lists:foldl(fun({I, #binding{pattern = P, expr = X}}, Bound) ->
                    check_uses(X, FnNames, Needs, Bound),
                    [{N, I} || N <- pattern_names(P)] ++ Bound;
                   ({_, #fn_decl{}}, Bound) ->
                    Bound;
                   ({_, X}, Bound) ->
                    check_uses(X, FnNames, Needs, Bound),
                    Bound
                end, [], Indexed).

%% The latest binding of Name before statement D, or none.
in_force(Name, D, Lets) ->
    case [I || {N, I} <- Lets, N =:= Name, I < D] of
        [] -> none;
        Is -> lists:max(Is)
    end.

%% The let instances a local fn needs, following references between local
%% fns.
needed_lets(N, Direct, Seen, Acc) ->
    case lists:member(N, Seen) of
        true -> Acc;
        false ->
            Refs = maps:get(N, Direct, []),
            Acc1 = lists:usort(Acc ++ [R || R <- Refs, is_tuple(R)]),
            lists:foldl(fun(R, A) when is_atom(R) -> needed_lets(R, Direct, [N | Seen], A);
                           (_, A) -> A
                        end, Acc1, Refs)
    end.

check_uses(Expr, FnNames, Needs, Bound) ->
    ern_ast:walk(fun(#e_var{pos = Pos, path = [], name = N}, E) ->
                 case lists:member(N, FnNames) of
                     true ->
                         case Needs(N) -- Bound of
                             [] -> E;
                             [{L, _} | _] -> fail(Pos, "local function " ++ atom_to_list(N)
                                                       ++ " is used before `let "
                                                       ++ atom_to_list(L)
                                                       ++ "`, which it references")
                         end;
                     false -> E
                 end;
            (_, E) -> E
         end, Expr, ok).

%% Unqualified names of the given set free in a local fn's body: outside
%% its parameters and the bindings inside the body.
-spec free_refs(term(), [tuple()], [atom()]) -> [atom()].
free_refs(Body, Params, Names) ->
    lists:usort([N || N <- ern_ast:free_names(Body, param_names(Params)), lists:member(N, Names)]).

pattern_names(P) -> [N || {N, _} <- ern_ast:pattern_bindings(P)].

param_names(Params) -> lists:append([pattern_names(P) || #param{pattern = P} <- Params]).

fail(Pos, Message) ->
    throw({type_error, Pos, lists:flatten(Message)}).

fail(Pos, Message, Labels, Help) ->
    throw({type_error, #diag{span = ern_diag:span(Pos), message = lists:flatten(Message),
                             labels = Labels, help = Help}}).
