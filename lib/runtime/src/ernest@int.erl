%% Appendix E.8 and the Int operations of report §9.6 that are not emitted
%% inline, namespace Int, as an Erlang module for MVP 1. Division and modulo
%% truncate toward zero (report §3.1), which is Erlang's div and rem.
-module('ernest@int').

-export([abs/1, min/2, max/2, bitAnd/2, bitOr/2, bitXor/2, bitNot/1, shiftLeft/2,
         shiftRight/2, toString/1, toFloat/1, 'div'/2, 'mod'/2, compare/2, negate/1]).

abs(N) -> erlang:abs(N).
min(A, B) -> erlang:min(A, B).
max(A, B) -> erlang:max(A, B).
bitAnd(A, B) -> A band B.
bitOr(A, B) -> A bor B.
bitXor(A, B) -> A bxor B.
bitNot(A) -> bnot A.
shiftLeft(A, B) -> A bsl B.
shiftRight(A, B) -> A bsr B.
toString(N) -> integer_to_binary(N).
toFloat(N) ->
    try float(N)
    catch error:badarg -> ern_rt:fault(<<"Int out of Float range">>)
    end.
'div'(_, 0) -> 'None';
'div'(A, B) -> {'Some', A div B}.
'mod'(_, 0) -> 'None';
'mod'(A, B) -> {'Some', A rem B}.
compare(A, B) when A < B -> 'Less';
compare(A, B) when A > B -> 'Greater';
compare(_, _) -> 'Equal'.
negate(N) -> -N.
