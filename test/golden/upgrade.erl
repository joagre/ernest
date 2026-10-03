-module(ern@upgrade).

-export([main/0, '$fun'/2]).

main() ->
    Counter_1 = ern_rt:spawn(fun () -> count(0) end,
                             <<"Upgrade.main:17">>),
    ern_rt:send(Counter_1, {'Inc', 5}),
    ern_rt:send(Counter_1, {'Inc', 3}),
    case ern_rt:call(Counter_1,
                     fun (Reply_2) -> {'Get', Reply_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_3} ->
            ern@io:println(<<"before upgrade: ",
                             (ern@int:toString(Total_3))/binary>>);
        'None' -> ern@io:println(<<"timeout">>)
    end,
    ern_rt:send(Counter_1,
                {'Upgrade',
                 fun (Total_4) -> Total_4 end,
                 fun countTwice/1}),
    ern_rt:send(Counter_1, {'Inc', 1}),
    case ern_rt:call(Counter_1,
                     fun (Reply_5) -> {'Get', Reply_5} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_6} ->
            ern@io:println(<<"after upgrade: ",
                             (ern@int:toString(Total_6))/binary>>);
        'None' -> ern@io:println(<<"timeout">>)
    end.

count(Total_7) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Inc', Amount_8} -> count(Total_7 + Amount_8);
        {'Get', Reply_9} ->
            ern_rt:answer(Reply_9, Total_7),
            count(Total_7);
        {'Upgrade', Migrate_10, Next_11} ->
            Next_11(Migrate_10(Total_7))
    end.

countTwice(Total_12) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Inc', Amount_13} ->
            countTwice(Total_12 + 2 * Amount_13);
        {'Get', Reply_14} ->
            ern_rt:answer(Reply_14, Total_12),
            countTwice(Total_12);
        {'Upgrade', Migrate_15, Next_16} ->
            Next_16(Migrate_15(Total_12))
    end.

'$fun'(main, 0) -> fun main/0.
