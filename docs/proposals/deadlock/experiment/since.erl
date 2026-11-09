%% What a start time would add to a call: the host's monotonic clock read
%% and the call's mark put with it, against a call's round trip as the
%% runtime makes it (a monitor with an alias, a send, a receive).
-module(since).
-export([main/0]).

main() ->
    N = 5000000,
    Echo = spawn(fun echo/0),
    [io:format("~-34s ~6.1f ns~n", [Name, best(F, N)])
     || {Name, F} <- [{"empty loop", fun(_) -> ok end},
                      {"put 2-tuple", fun(I) -> put(call, {Echo, I}) end},
                      {"put 3-tuple with monotonic ms",
                       fun(I) -> put(call, {Echo, I, erlang:monotonic_time(millisecond)}) end},
                      {"put 3-tuple with native time",
                       fun(I) -> put(call, {Echo, I, erlang:monotonic_time()}) end}]],
    M = 500000,
    io:format("~-34s ~6.1f ns~n", ["call round trip", best(fun(_) -> call(Echo) end, M)]),
    halt().

best(F, N) ->
    lists:min([run(F, N) || _ <- [1, 2, 3, 4, 5]]).

run(F, N) ->
    T0 = erlang:monotonic_time(nanosecond),
    loop(F, N),
    (erlang:monotonic_time(nanosecond) - T0) / N.

loop(_, 0) -> ok;
loop(F, N) -> F(N), loop(F, N - 1).

call(Echo) ->
    Ref = erlang:monitor(process, Echo, [{alias, demonitor}]),
    Echo ! {Ref, ask},
    receive
        {Ref, answer} -> erlang:demonitor(Ref, [flush]);
        {'DOWN', Ref, _, _, _} -> down
    end.

echo() ->
    receive {Ref, ask} -> Ref ! {Ref, answer} end,
    echo().
