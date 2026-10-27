-module(ack).
-export([ack/2, main/0]).

ack(0, N) -> N + 1;
ack(M, 0) -> ack(M - 1, 1);
ack(M, N) -> ack(M - 1, ack(M, N - 1)).

%% Timed eleven times at A(3, 11), as ack.ern times itself.
main() -> timed(11).

timed(0) -> ok;
timed(Left) ->
    Start = erlang:monotonic_time(microsecond),
    Value = ack(3, 11),
    Took = erlang:monotonic_time(microsecond) - Start,
    io:format("~p ~p~n", [Value, Took div 1000]),
    timed(Left - 1).
