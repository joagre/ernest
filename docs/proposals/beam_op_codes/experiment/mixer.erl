-module(mixer).
-export([run/1, main/0]).

%% A loop carrying five values across four calls per iteration, three to
%% leaves and one to a function that calls a leaf twice; every value a
%% small non-negative integer, kept below 2^24 by rem, with no bitwise
%% operation.
run(N) -> loop(N, 1, 2, 3, 0).

loop(0, _, _, _, Acc) -> Acc;
loop(I, A, B, C, Acc) ->
    A1 = lcg(A),
    B1 = mix(B, A1),
    C1 = rot(C, I),
    D = mix3(A1, B1, C1),
    loop(I - 1, A1, B1, C1, (Acc + D) rem 16777216).

lcg(X) -> (X * 1103515245 + 12345) rem 16777216.

mix(X, Y) -> (X + Y * 8) rem 16777216.

rot(X, I) ->
    S = I rem 8,
    (X * (S + 1) + (24 - S)) rem 16777216.

mix3(X, Y, Z) ->
    M = mix(X, Y),
    (mix(M, Z) + Z * 7) rem 16777216.

%% Timed eleven times at ten million iterations, as mixer.ern times itself.
main() -> timed(11).

timed(0) -> ok;
timed(Left) ->
    Start = erlang:monotonic_time(microsecond),
    Value = loop(10000000, 1, 2, 3, 0),
    Took = erlang:monotonic_time(microsecond) - Start,
    io:format("~p ~p~n", [Value, Took div 1000]),
    timed(Left - 1).
