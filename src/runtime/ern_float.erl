%% The shims behind Float.toString, div, pow, and exp (report Appendix E.9):
%% Erlang prints the shortest form only when asked, and raises badarith
%% where §3.1 names the fault.
-module(ern_float).

-export([to_string/1, divide/2, pow/2, exp/1, atan2/2]).

%% Report Appendix E.9: a Float as its literal is written, which
%% ern_literal lays out for every writer of one.
-spec to_string(float()) -> binary().
to_string(Float) -> list_to_binary(ern_literal:float_text(Float)).

%% Report Appendix E.9: `/` where it gives a finite quotient, and `None`
%% where it would fault (§3.1), a zero divisor or a quotient past the finite
%% range, which the host's badarith alone tells, short of dividing twice.
%% There is no negative zero: a negative quotient too small for the range is
%% the host's `-0.0`, which adding `0.0` makes the one zero.
-spec divide(float(), float()) -> {'Some', float()} | 'None'.
divide(Dividend, Divisor) ->
    try {'Some', Dividend / Divisor + 0.0}
    catch error:badarith -> 'None'
    end.

%% Report §3.1: a result the finite range cannot hold is the float fault,
%% not Erlang's badarith; Float.pow keeps the domain out before it gets here.
%% There is no negative zero: a negative result too small for the range is
%% the host's `-0.0`, which adding `0.0` makes the one zero.
-spec pow(float(), float()) -> float().
pow(Base, Exponent) -> arith(fun() -> math:pow(Base, Exponent) + 0.0 end).

-spec exp(float()) -> float().
exp(Power) -> arith(fun() -> math:exp(Power) end).

%% Report §3.1: no negative zero, which the host's atan2 gives for a
%% negative `y` beside an `x` large enough. Of the host's functions Float
%% stands on, this one and pow alone bring a negative result to zero: the
%% others answer a zero only for a zero.
-spec atan2(float(), float()) -> float().
atan2(Y, X) -> math:atan2(Y, X) + 0.0.

arith(Compute) ->
    try Compute()
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.
