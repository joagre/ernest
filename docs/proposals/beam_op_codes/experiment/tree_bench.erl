-module(tree_bench).
-export([run/0]).

%% Each module's eval of one depth-22 tree, a thousand times a run, eleven runs.
run() ->
    T = tree:build(22, 1),
    [begin
         Runs = [timer:tc(fun() -> lists:foldl(fun(_, _) -> Mod:eval(T) end, 0, lists:seq(1, 1000)) end)
                 || _ <- lists:seq(1, 11)],
         Times = lists:sort([U div 1000 || {U, _} <- Runs]),
         io:format("~-12s ~p ms  value ~p  (~w)~n", [Mod, lists:nth(6, Times), element(2, hd(Runs)), Times])
     end || Mod <- [tree, tree_typed]],
    ok.
