-module(ernest@stack).

-export([main/0,
         'Stack.empty'/0,
         'Stack.push'/2,
         'Stack.pop'/1,
         '$init'/0]).

main() ->
    S_1 = 'Stack.push'(2, 'Stack.push'(1, 'Stack.empty'())),
    case 'Stack.pop'(S_1) of
        {'Some', {Top_2, _}} ->
            ernest@io:println(<<"top is ",
                                (ernest@int:toString(Top_2))/binary>>);
        'None' -> ernest@io:println(<<"empty">>)
    end.

'Stack.empty'() ->
    persistent_term:get({ernest@stack, 'Stack.empty'}).

'Stack.push'(X_3, {'Stack', Xs_4}) ->
    {'Stack', [X_3 | Xs_4]}.

'Stack.pop'({'Stack', Xs_5}) ->
    case Xs_5 of
        [] -> 'None';
        [X_6 | Rest_7] -> {'Some', {X_6, {'Stack', Rest_7}}}
    end.

'$init'() ->
    persistent_term:put({ernest@stack, 'Stack.empty'},
                        {'Stack', []}),
    ok.
