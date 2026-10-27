-module(ack_bench).
-export([run/0]).

%% Each module's A(3, 10), five runs, the median in milliseconds.
run() ->
    [begin
         Times = lists:sort([element(1, timer:tc(Mod, ack, [3, 11])) div 1000 || _ <- lists:seq(1, 11)]),
         io:format("~-12s ~p ms  (~w)~n", [Mod, lists:nth(6, Times), Times])
     end || Mod <- [ack, ack_caller, ack_callee]],
    ok.
