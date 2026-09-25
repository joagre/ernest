%% The shim behind Random (report Appendix E.13, rule 1): `rand` with the
%% exsss algorithm, its state passed in and out so the interface is pure.
%% A draw is uniform over the bound and zero, either sign.
-module(ern_random).

-export([seed/1, next_float/1, next/2]).

-spec seed(integer()) -> rand:state().
seed(N) -> rand:seed_s(exsss, N).

%% rand:uniform_real_s/1 is above 0.0 and below 1.0, as E.13 promises;
%% rand:uniform_s/1 may give 0.0.
-spec next_float(rand:state()) -> {float(), rand:state()}.
next_float(S) -> rand:uniform_real_s(S).

-spec next(rand:state(), integer()) -> {integer(), rand:state()}.
next(S, Bound) when Bound >= 0 ->
    {X, S1} = rand:uniform_s(Bound + 1, S),
    {X - 1, S1};
next(S, Bound) ->
    {X, S1} = rand:uniform_s(1 - Bound, S),
    {1 - X, S1}.
