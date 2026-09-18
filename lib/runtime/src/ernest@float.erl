%% Appendix E.9 and the Float operations of report §9.6 that are not emitted
%% inline, namespace Float, as an Erlang module for MVP 1. Floats are finite
%% (report §3.1), so every function here is total. toString prints the
%% shortest decimal that reads back to the same Float; round is ties-to-even.
%% The arithmetic operators live here rather than inline because a compiled
%% badarith carries no operands, so the runtime cannot tell the Float fault
%% of report §7.4 from the Int zero divisor; these catch it at the source.
-module('ernest@float').

-export(['+'/2, '-'/2, '*'/2, '/'/2, abs/1, min/2, max/2, toString/1, round/1, floor/1,
         ceil/1, compare/2, negate/1]).

'+'(A, B) -> arith(fun() -> A + B end).
'-'(A, B) -> arith(fun() -> A - B end).
'*'(A, B) -> arith(fun() -> A * B end).
'/'(A, B) -> arith(fun() -> A / B end).

arith(F) ->
    try F()
    catch error:badarith -> ern_rt:fault(<<"float arithmetic error">>)
    end.

abs(F) -> erlang:abs(F).
min(A, B) -> erlang:min(A, B).
max(A, B) -> erlang:max(A, B).
toString(F) -> float_to_binary(F, [short]).
round(F) ->
    Fl = erlang:floor(F),
    case F - Fl of
        0.5 ->
            case Fl rem 2 of
                0 -> Fl;
                _ -> Fl + 1
            end;
        D when D < 0.5 -> Fl;
        _ -> Fl + 1
    end.
floor(F) -> erlang:floor(F).
ceil(F) -> erlang:ceil(F).
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.
negate(F) -> -F.
