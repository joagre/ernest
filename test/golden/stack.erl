-module(ern@stack).

-export([main/0,
         'Stack.empty'/0,
         'Stack.push'/2,
         'Stack.pop'/1,
         '$init'/0,
         '$fun'/2]).

main() ->
    S_1 = 'Stack.push'(2, 'Stack.push'(1, 'Stack.empty'())),
    case 'Stack.pop'(S_1) of
        {'Some', {Top_2, _}} ->
            ern@io:println(<<"top is ",
                             (ern@int:toString(Top_2))/binary>>);
        'None' -> ern@io:println(<<"empty">>)
    end.

'Stack.empty'() ->
    ern_rt:binding({ern@stack, 'Stack.empty'}).

'Stack.push'(X_3, {'Stack', Xs_4}) ->
    {'Stack', [X_3 | Xs_4]}.

'Stack.pop'({'Stack', Xs_5}) ->
    case Xs_5 of
        [] -> 'None';
        [X_6 | Rest_7] -> {'Some', {X_6, {'Stack', Rest_7}}}
    end.

'$init'() ->
    persistent_term:put({ern@stack, 'Stack.empty'},
                        {'Stack', []}),
    ok.

'$fun'(main, 0) -> fun main/0;
'$fun'('Stack.push', 2) -> fun 'Stack.push'/2;
'$fun'('Stack.pop', 1) -> fun 'Stack.pop'/1.
