%% The shims behind Float.toString, pow, and exp (report Appendix E.9):
%% Erlang prints the shortest form only when asked, and raises badarith
%% where §3.1 names the fault.
-module(ern_float).

-export([to_string/1, pow/2, exp/1]).

-spec to_string(float()) -> binary().
to_string(F) -> float_to_binary(F, [short]).

%% Report §3.1: a result the finite range cannot hold is the float fault,
%% not Erlang's badarith; Float.pow keeps the domain out before it gets here
-spec pow(float(), float()) -> float().
pow(Base, Exponent) -> arith(fun() -> math:pow(Base, Exponent) end).

-spec exp(float()) -> float().
exp(X) -> arith(fun() -> math:exp(X) end).

arith(F) ->
    try F()
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.
