%% The shims behind Int whose work the host's own operation does not do as
%% it stands (report §9.6, Appendix E.8): `/` and `%`, and Int.toFloat,
%% whose faults Erlang does not raise in the report's words (§7.4), and
%% `compare`, which the host has no function in the shape of.
-module(ern_int).

-export([to_float/1, divide/2, remainder/2, compare/2]).

-spec to_float(integer()) -> float().
to_float(Integer) ->
    try float(Integer)
    catch error:badarg -> ern_rt:fault(<<"Int out of Float range">>)
    end.

%% Report §7.4, §9.6: `/` and `%` as functions, a zero divisor the fault the
%% operators have in line, where an uncaught badarith is that fault.
-spec divide(integer(), integer()) -> integer().
divide(Dividend, Divisor) ->
    try Dividend div Divisor
    catch error:badarith -> ern_rt:fault(<<"division by zero">>)
    end.

-spec remainder(integer(), integer()) -> integer().
remainder(Dividend, Divisor) ->
    try Dividend rem Divisor
    catch error:badarith -> ern_rt:fault(<<"division by zero">>)
    end.

%% Report §3.10, §9.6: the host's ordering of integers, as an Ordering.
-spec compare(integer(), integer()) -> 'Less' | 'Equal' | 'Greater'.
compare(Left, Right) when Left < Right -> 'Less';
compare(Left, Right) when Left > Right -> 'Greater';
compare(_, _) -> 'Equal'.
