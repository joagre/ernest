-module(tree).
-export([eval/1, build/2, main/0]).

%% An interpreter for an expression tree of four constructors, the
%% arithmetic masked to 24 bits so that integers are not what is measured.
eval({'Num', N}) -> N;
eval({'Add', A, B}) -> (eval(A) + eval(B)) rem 16777216;
eval({'Mul', A, B}) -> (eval(A) * eval(B)) rem 16777216;
eval({'Neg', A}) -> 16777215 - (eval(A) rem 16777216).

%% A tree of the given depth, three nodes in four binary, its shape and
%% leaves drawn from an LCG over Seed.
build(0, Seed) -> {'Num', Seed rem 65536};
build(D, Seed) ->
    S1 = (Seed * 75 + 74) rem 65537,
    S2 = (S1 * 75 + 74) rem 65537,
    case S1 rem 4 of
        0 -> {'Neg', build(D - 1, S2)};
        1 -> {'Mul', build(D - 1, S1), build(D - 1, S2)};
        _ -> {'Add', build(D - 1, S1), build(D - 1, S2)}
    end.

%% Timed eleven times, each run a thousand evaluations of one depth-22
%% tree, as tree.ern times itself.
main() -> timed(build(22, 1), 11).

evaluated(_, 0, Value) -> Value;
evaluated(Tree, Times, _) -> evaluated(Tree, Times - 1, eval(Tree)).

timed(_, 0) -> ok;
timed(Tree, Left) ->
    Start = erlang:monotonic_time(microsecond),
    Value = evaluated(Tree, 1000, 0),
    Took = erlang:monotonic_time(microsecond) - Start,
    io:format("~p ~p~n", [Value, Took div 1000]),
    timed(Tree, Left - 1).
