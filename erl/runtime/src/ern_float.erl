%% The shims behind Float.toString, pow, and exp, and behind Float's
%% operators, `negate` and `compare` (report Appendix E.9, §9.6): Erlang
%% prints the shortest form only when asked, raises badarith where §3.1
%% names the fault, keeps a negative zero the language has none of, and has
%% no function in the shape of `compare`.
-module(ern_float).

-export([to_string/1, text/1, pow/2, exp/1, add/2, subtract/2, multiply/2, divide/2, negate/1,
         compare/2]).

%% Report Appendix E.9: the shortest digits that read back as the same
%% value, which float_to_list/2's `short` gives, written plain from 0.0001
%% to below 1.0e16 and as one digit, the point, the rest and the exponent
%% beyond, the exponent's sign only when negative. `Io.debug` and the shell
%% print a Float the same way (ern_show).
-spec to_string(float()) -> binary().
to_string(Float) -> list_to_binary(text(Float)).

-spec text(float()) -> string().
text(Float) when Float < 0 -> [$- | text(-Float)];
text(Float) when Float == 0 -> "0.0";
text(Float) ->
    {Digits, Point} = digits(float_to_list(Float, [short])),
    case Float >= 1.0e-4 andalso Float < 1.0e16 of
        true -> plain(Digits, Point);
        false -> scientific(Digits, Point)
    end.

%% The significant digits of short's text, and where the point stands among
%% them: the value is 0.Digits times ten to Point.
digits(Short) ->
    {Mantissa, Exponent} = case string:split(Short, "e") of
                               [Before, After] -> {Before, list_to_integer(After)};
                               [Before] -> {Before, 0}
                           end,
    [Whole, Fraction] = string:split(Mantissa, "."),
    All = Whole ++ Fraction,
    Leading = length(lists:takewhile(fun(Char) -> Char =:= $0 end, All)),
    Digits = lists:reverse(lists:dropwhile(fun(Char) -> Char =:= $0 end,
                                           lists:reverse(lists:nthtail(Leading, All)))),
    {Digits, length(Whole) - Leading + Exponent}.

plain(Digits, Point) when Point =< 0 ->
    "0." ++ lists:duplicate(-Point, $0) ++ Digits;
plain(Digits, Point) when Point >= length(Digits) ->
    Digits ++ lists:duplicate(Point - length(Digits), $0) ++ ".0";
plain(Digits, Point) ->
    {Whole, Fraction} = lists:split(Point, Digits),
    Whole ++ "." ++ Fraction.

scientific([First | Rest], Point) ->
    [First, $. | case Rest of [] -> "0"; _ -> Rest end] ++ "e" ++ integer_to_list(Point - 1).

%% Report §3.1: a result the finite range cannot hold is the float fault,
%% not Erlang's badarith; Float.pow keeps the domain out before it gets here
-spec pow(float(), float()) -> float().
pow(Base, Exponent) -> arith(fun() -> math:pow(Base, Exponent) end).

-spec exp(float()) -> float().
exp(Power) -> arith(fun() -> math:exp(Power) end).

%% Report §9.6, §3.1: Float's operators as functions, each what the
%% emitter writes for the operator in line (float_operation/5): a result
%% the finite range cannot hold is the float fault, and a product or a
%% quotient that is negative zero is 0.0, as is the negation of 0.0. A
%% test holds the two equal.
-spec add(float(), float()) -> float().
add(Left, Right) ->
    try Left + Right
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

-spec subtract(float(), float()) -> float().
subtract(Left, Right) ->
    try Left - Right
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

-spec multiply(float(), float()) -> float().
multiply(Left, Right) ->
    try Left * Right + 0.0
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

-spec divide(float(), float()) -> float().
divide(Dividend, Divisor) ->
    try Dividend / Divisor + 0.0
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

-spec negate(float()) -> float().
negate(Float) -> 0.0 - Float.

%% Report §3.10, §9.6: the host's ordering of floats, as an Ordering.
-spec compare(float(), float()) -> 'Less' | 'Equal' | 'Greater'.
compare(Left, Right) when Left < Right -> 'Less';
compare(Left, Right) when Left > Right -> 'Greater';
compare(_, _) -> 'Equal'.

arith(Compute) ->
    try Compute()
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.
