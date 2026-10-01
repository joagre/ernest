-module(ern@stack).

-export([main/0,
         empty/0,
         push/2,
         pop/1,
         '$init'/0,
         '$fun'/2]).

main() ->
    S_1 = push(push(empty(), 1), 2),
    case pop(S_1) of
        {'Some', {Top_2, _}} ->
            ern@io:println(<<"top is ",
                             (ern@int:toString(Top_2))/binary>>);
        'None' -> ern@io:println(<<"empty">>)
    end.

empty() -> ern_rt:binding({ern@stack, empty}).

push({'Stack', Xs_3}, X_4) -> {'Stack', [X_4 | Xs_3]}.

pop({'Stack', Xs_5}) ->
    case Xs_5 of
        [] -> 'None';
        [X_6 | Rest_7] -> {'Some', {X_6, {'Stack', Rest_7}}}
    end.

'$init'() ->
    ern_rt:initializing(<<"Stack.empty:23">>),
    persistent_term:put({ern@stack, empty}, {'Stack', []}),
    ok.

'$fun'(main, 0) -> fun main/0;
'$fun'(push, 2) -> fun push/2;
'$fun'(pop, 1) -> fun pop/1.
