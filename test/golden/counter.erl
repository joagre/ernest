-module(ern@counter).

-export([main/0, '$fun'/2]).

main() ->
    Counter_1 = ern_rt:spawn(fun () -> count(0) end,
                             <<"Counter.main:17">>),
    ern_rt:send(Counter_1, {'Inc', 5}),
    ern_rt:send(Counter_1, {'Inc', 3}),
    case ern_rt:call(Counter_1,
                     fun (Reply_2) -> {'Get', Reply_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_3} ->
            ern@io:println(<<"count is ",
                             (ern@int:toString(Total_3))/binary>>);
        'None' -> ern@io:println(<<"counter is not answering">>)
    end.

count(Total_4) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_9} -> ern_rt:fault(Cause_9);
        {'Inc', Amount_5} -> count(Total_4 + Amount_5);
        {'Get', Reply_6} ->
            ern_rt:answer(Reply_6, Total_4),
            count(Total_4);
        {'Upgrade', Migrate_7, Next_8} ->
            Next_8(Migrate_7(Total_4))
    end.

'$fun'(main, 0) -> fun main/0.
