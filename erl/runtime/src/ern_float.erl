%% The shims behind Float.toString, pow, and exp (report Appendix E.9):
%% Erlang prints the shortest form only when asked, and raises badarith
%% where §3.1 names the fault.
-module(ern_float).

-export([to_string/1, text/1, pow/2, exp/1]).

%% Report Appendix E.9: the shortest digits that read back as the same
%% value, which float_to_list/2's `short` gives, written plain from 0.0001
%% to below 1.0e16 and as one digit, the point, the rest and the exponent
%% beyond, the exponent's sign only when negative. `Io.debug` and the shell
%% print a Float the same way (ern_show).
-spec to_string(float()) -> binary().
to_string(F) -> list_to_binary(text(F)).

-spec text(float()) -> string().
text(F) when F < 0 -> [$- | text(-F)];
text(F) when F == 0 -> "0.0";
text(F) ->
    {Digits, Point} = digits(float_to_list(F, [short])),
    case F >= 1.0e-4 andalso F < 1.0e16 of
        true -> plain(Digits, Point);
        false -> scientific(Digits, Point)
    end.

%% The significant digits of short's text, and where the point stands among
%% them: the value is 0.Digits times ten to Point.
digits(Short) ->
    {Mantissa, Exponent} = case string:split(Short, "e") of
                               [M, E] -> {M, list_to_integer(E)};
                               [M] -> {M, 0}
                           end,
    [Whole, Fraction] = string:split(Mantissa, "."),
    All = Whole ++ Fraction,
    Leading = length(lists:takewhile(fun(C) -> C =:= $0 end, All)),
    Digits = lists:reverse(lists:dropwhile(fun(C) -> C =:= $0 end,
                                           lists:reverse(lists:nthtail(Leading, All)))),
    {Digits, length(Whole) - Leading + Exponent}.

plain(Digits, Point) when Point =< 0 ->
    "0." ++ lists:duplicate(-Point, $0) ++ Digits;
plain(Digits, Point) when Point >= length(Digits) ->
    Digits ++ lists:duplicate(Point - length(Digits), $0) ++ ".0";
plain(Digits, Point) ->
    {Whole, Fraction} = lists:split(Point, Digits),
    Whole ++ "." ++ Fraction.

scientific([D | Rest], Point) ->
    [D, $. | case Rest of [] -> "0"; _ -> Rest end] ++ "e" ++ integer_to_list(Point - 1).

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
