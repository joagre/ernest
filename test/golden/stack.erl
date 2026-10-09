-module(ern@stack).

-dialyzer(no_return).

-export([main/0,
         empty/0,
         push/2,
         pop/1,
         '$init'/0,
         '$fun'/2,
         '$spawned'/2]).

main() ->
    Stack_1 = push(push(empty(), 1), 2),
    case pop(Stack_1) of
        {'Some', {Top_2, _}} ->
            ern@io:println(<<"top is ",
                             (ern@int:toString(Top_2))/binary>>);
        'None' -> ern@io:println(<<"empty">>)
    end.

empty() -> ern_rt:binding({ern@stack, empty}).

push({'Stack', Items_3}, Item_4) ->
    {'Stack', [Item_4 | Items_3]}.

pop({'Stack', Items_5}) ->
    case Items_5 of
        [] -> 'None';
        [Item_6 | Rest_7] ->
            {'Some', {Item_6, {'Stack', Rest_7}}}
    end.

'$init'() ->
    ern_rt:initializing(<<"Stack.empty:23">>),
    persistent_term:put({ern@stack, empty}, {'Stack', []}),
    ok.

'$fun'(main, 0) -> fun main/0;
'$fun'(push, 2) -> fun push/2;
'$fun'(pop, 1) -> fun pop/1.

'$spawned'(main, []) -> main().
