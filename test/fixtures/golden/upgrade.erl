-module(ern@upgrade).

-dialyzer(no_return).

-export(['$2'/0, '$spawned'/2]).

%% Upgrade.main
'$2'() ->
    Counter_1 = ern_rt:spawn(fun () -> '$3'(0) end,
                             <<"Upgrade.main:17">>),
    ern_rt:send(Counter_1, {'Inc', 5}),
    ern_rt:send(Counter_1, {'Inc', 3}),
    case ern_rt:call(Counter_1,
                     fun (Reply_2) -> {'Get', Reply_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_3} ->
            ern@io:'$8'(<<"before upgrade: ",
                          (ern@int:'$24'(Total_3))/binary>>);
        'None' -> ern@io:'$8'(<<"timeout">>)
    end,
    ern_rt:send(Counter_1,
                {'Upgrade', fun (Total_4) -> Total_4 end, fun '$4'/1}),
    ern_rt:send(Counter_1, {'Inc', 1}),
    case ern_rt:call(Counter_1,
                     fun (Reply_5) -> {'Get', Reply_5} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_6} ->
            ern@io:'$8'(<<"after upgrade: ",
                          (ern@int:'$24'(Total_6))/binary>>);
        'None' -> ern@io:'$8'(<<"timeout">>)
    end.

%% Upgrade.count
'$3'(Total_7) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_12} -> erlang:throw(Fault_12);
        {'Inc', Amount_8} -> '$3'(Total_7 + Amount_8);
        {'Get', Reply_9} ->
            ern_rt:answer(Reply_9, Total_7),
            '$3'(Total_7);
        {'Upgrade', Migrate_10, Next_11} ->
            Next_11(Migrate_10(Total_7))
    end.

%% Upgrade.countTwice
'$4'(Total_13) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_18} -> erlang:throw(Fault_18);
        {'Inc', Amount_14} -> '$4'(Total_13 + 2 * Amount_14);
        {'Get', Reply_15} ->
            ern_rt:answer(Reply_15, Total_13),
            '$4'(Total_13);
        {'Upgrade', Migrate_16, Next_17} ->
            Next_17(Migrate_16(Total_13))
    end.

'$spawned'('$2', []) -> '$2'().
