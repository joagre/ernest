-module(ern@counter).

-dialyzer(no_return).

-export(['$2'/0, '$spawned'/2]).

%% Counter.main
'$2'() ->
    Counter_1 = ern_rt:spawn(fun () -> '$3'(0) end,
                             <<"Counter.main:17">>),
    ern_rt:send(Counter_1, {'Inc', 5}),
    ern_rt:send(Counter_1, {'Inc', 3}),
    case ern_rt:call(Counter_1,
                     fun (Reply_2) -> {'Get', Reply_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_3} ->
            ern@io:'$8'(<<"count is ",
                          (ern@int:'$24'(Total_3))/binary>>);
        'None' -> ern@io:'$8'(<<"counter is not answering">>)
    end.

%% Counter.count
'$3'(Total_4) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_9} -> erlang:throw(Fault_9);
        {'Inc', Amount_5} -> '$3'(Total_4 + Amount_5);
        {'Get', Reply_6} ->
            ern_rt:answer(Reply_6, Total_4),
            '$3'(Total_4);
        {'Upgrade', Migrate_7, Next_8} ->
            Next_8(Migrate_7(Total_4))
    end.

'$spawned'('$2', []) -> '$2'().
