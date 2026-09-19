%% The shims behind Float's arithmetic and printing (report Appendix E.9):
%% Erlang raises badarith where §7.4 names the fault, and prints the
%% shortest form only when asked.
-module(ern_float).

-export([add/2, subtract/2, multiply/2, divide/2, negate/1, to_string/1]).

-spec add(float(), float()) -> float().
add(A, B) -> arith(fun() -> A + B end).

-spec subtract(float(), float()) -> float().
subtract(A, B) -> arith(fun() -> A - B end).

-spec multiply(float(), float()) -> float().
multiply(A, B) -> arith(fun() -> A * B end).

-spec divide(float(), float()) -> float().
divide(A, B) -> arith(fun() -> A / B end).

arith(F) ->
    try F()
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

-spec negate(float()) -> float().
negate(F) -> -F.

-spec to_string(float()) -> binary().
to_string(F) -> float_to_binary(F, [short]).
