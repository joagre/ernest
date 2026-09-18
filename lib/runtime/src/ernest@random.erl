%% Appendix E.13, namespace Random, as an Erlang module for MVP 1. A pure
%% generator: the seed is Seed(Int) under the ABI of report §8.4, and next
%% is SplitMix64 on the low 64 bits of the state, so the same seed gives the
%% same sequence on every node. The draw is the output modulo the width of
%% the range, between 0 and the bound inclusive on either side of zero.
-module('ernest@random').

-export([next/2]).

-define(MASK, 16#FFFFFFFFFFFFFFFF).

-spec next({'Seed', integer()}, integer()) -> {integer(), {'Seed', integer()}}.
next({'Seed', S0}, Bound) ->
    S = (S0 + 16#9E3779B97F4A7C15) band ?MASK,
    Z1 = ((S bxor (S bsr 30)) * 16#BF58476D1CE4E5B9) band ?MASK,
    Z2 = ((Z1 bxor (Z1 bsr 27)) * 16#94D049BB133111EB) band ?MASK,
    Z = Z2 bxor (Z2 bsr 31),
    X = case Bound >= 0 of
            true -> Z rem (Bound + 1);
            false -> -(Z rem (1 - Bound))
        end,
    {X, {'Seed', S}}.
