-module(mixer).
-export([run/1]).

%% A loop carrying five values across four calls per iteration, three to
%% leaves and one to a function that calls a leaf twice; every value a
%% small integer, masked to 24 bits.
run(N) -> loop(N, 1, 2, 3, 0).

loop(0, _, _, _, Acc) -> Acc;
loop(I, A, B, C, Acc) ->
    A1 = lcg(A),
    B1 = mix(B, A1),
    C1 = rot(C, I),
    D = mix3(A1, B1, C1),
    loop(I - 1, A1, B1, C1, (Acc + D) band 16#FFFFFF).

lcg(X) -> (X * 1103515245 + 12345) band 16#FFFFFF.

mix(X, Y) -> (X bxor (Y bsl 3)) band 16#FFFFFF.

rot(X, I) ->
    S = I band 7,
    ((X bsl S) bor (X bsr (24 - S))) band 16#FFFFFF.

mix3(X, Y, Z) ->
    M = mix(X, Y),
    (mix(M, Z) + Z * 7) band 16#FFFFFF.
