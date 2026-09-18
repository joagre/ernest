%% Appendix E.13, namespace Random, as an Erlang module for MVP 1. The
%% runtime's generator, rand with exsss, behind a pure interface: a Seed is
%% rand's state term, a foreign value (report §3.8), and next draws uniform_s
%% over the width of the range, between 0 and the bound inclusive on either
%% side of zero.
-module('ernest@random').

-export([seed/1, next/2]).

-spec seed(integer()) -> rand:state().
seed(N) -> rand:seed_s(exsss, N).

-spec next(rand:state(), integer()) -> {integer(), rand:state()}.
next(S, Bound) when Bound >= 0 ->
    {X, S1} = rand:uniform_s(Bound + 1, S),
    {X - 1, S1};
next(S, Bound) ->
    {X, S1} = rand:uniform_s(1 - Bound, S),
    {1 - X, S1}.
