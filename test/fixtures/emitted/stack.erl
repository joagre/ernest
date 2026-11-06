-module(ern@stack).

-dialyzer(no_return).

-export(['$2'/0,
         '$3'/0,
         '$4'/2,
         '$5'/1,
         '$init'/0,
         '$spawned'/2]).

%% Stack.main
'$2'() ->
    Stack_1 = '$4'('$4'({'Stack', []}, 1), 2),
    case '$5'(Stack_1) of
        {'Some', {Top_2, _}} ->
            ern@io:'$8'(<<"top is ",
                          (erlang:integer_to_binary(Top_2))/binary>>);
        'None' -> ern@io:'$8'(<<"empty">>)
    end.

%% Stack.empty
'$3'() -> ern_rt:binding({ern@stack, '$3'}).

%% Stack.push
'$4'({'Stack', Items_3}, Item_4) ->
    {'Stack', [Item_4 | Items_3]}.

%% Stack.pop
'$5'({'Stack', Items_5}) ->
    case Items_5 of
        [] -> 'None';
        [Item_6 | Rest_7] ->
            {'Some', {Item_6, {'Stack', Rest_7}}}
    end.

'$init'() ->
    persistent_term:put({ern@stack, '$3'}, {'Stack', []}),
    ok.

'$spawned'('$2', []) -> '$2'().
