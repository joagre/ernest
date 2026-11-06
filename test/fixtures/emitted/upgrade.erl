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
                     fun (Argument_2) -> {'Get', Argument_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_3} ->
            ern@io:'$8'(<<"before upgrade: ",
                          (erlang:integer_to_binary(Total_3))/binary>>);
        'None' -> ern@io:'$8'(<<"timeout">>)
    end,
    ern_rt:send(Counter_1,
                {'Upgrade', fun (Total_4) -> Total_4 end, fun '$4'/1}),
    ern_rt:send(Counter_1, {'Inc', 1}),
    case ern_rt:call(Counter_1,
                     fun (Argument_5) -> {'Get', Argument_5} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Total_6} ->
            ern@io:'$8'(<<"after upgrade: ",
                          (erlang:integer_to_binary(Total_6))/binary>>);
        'None' -> ern@io:'$8'(<<"timeout">>)
    end.

%% Upgrade.count
'$3'(Total_7) ->
    fun Wait_13(After_14) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_12} -> erlang:throw(Fault_12);
                {'Inc', Amount_8} -> '$3'(Total_7 + Amount_8);
                {'Get', Reply_9} ->
                    ern_rt:answer(Reply_9, Total_7),
                    '$3'(Total_7);
                {'Upgrade', Migrate_10, Next_11} ->
                    Next_11(Migrate_10(Total_7))
                after After_14 -> ern_rt:collect(), Wait_13(infinity)
            end
    end(1).

%% Upgrade.countTwice
'$4'(Total_15) ->
    fun Wait_21(After_22) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_20} -> erlang:throw(Fault_20);
                {'Inc', Amount_16} -> '$4'(Total_15 + 2 * Amount_16);
                {'Get', Reply_17} ->
                    ern_rt:answer(Reply_17, Total_15),
                    '$4'(Total_15);
                {'Upgrade', Migrate_18, Next_19} ->
                    Next_19(Migrate_18(Total_15))
                after After_22 -> ern_rt:collect(), Wait_21(infinity)
            end
    end(1).

'$spawned'('$2', []) -> '$2'().
