-module(mixer_bench).
-export([run/0]).

run() ->
    [begin
         Runs = [timer:tc(Mod, run, [10000000]) || _ <- lists:seq(1, 11)],
         Times = lists:sort([T div 1000 || {T, _} <- Runs]),
         io:format("~-14s ~p ms  value ~p  (~w)~n", [Mod, lists:nth(6, Times), element(2, hd(Runs)), Times])
     end || Mod <- [mixer, mixer_caller, mixer_callee]],
    ok.
