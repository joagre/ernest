-module(ern@services).

-dialyzer(no_return).

-export(['$5'/0,
         '$6'/0,
         '$8'/0,
         '$10'/0,
         '$12'/0,
         '$init'/0,
         '$spawned'/2]).

%% Services.services
'$5'() -> ern_rt:binding({ern@services, '$5'}).

%% Services.store
'$6'() -> ern_rt:binding({ern@services, '$6'}).

%% Services.storing
'$7'(Stock_1) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_8} -> erlang:throw(Fault_8);
        {'Change', Key_2, By_3, Reply_4} ->
            Held_5 = '$18'(Stock_1, Key_2),
            case Held_5 + By_3 < 0 of
                true ->
                    erlang:throw({ern,
                                  fault,
                                  <<Key_2/binary, ": cannot take ",
                                    (ern@int:'$24'(-By_3))/binary, " of ",
                                    (ern@int:'$24'(Held_5))/binary>>});
                false ->
                    ern_rt:answer(Reply_4, Held_5 + By_3),
                    '$7'(ern@map:'$4'(Stock_1, Key_2, Held_5 + By_3))
            end;
        {'Get', Key_6, Reply_7} ->
            ern_rt:answer(Reply_7, '$18'(Stock_1, Key_6)),
            '$7'(Stock_1)
    end.

%% Services.ids
'$8'() -> ern_rt:binding({ern@services, '$8'}).

%% Services.counting
'$9'(Next_9) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_11} -> erlang:throw(Fault_11);
        {'NextId', Reply_10} ->
            ern_rt:answer(Reply_10, Next_9),
            '$9'(Next_9 + 1)
    end.

%% Services.audit
'$10'() -> ern_rt:binding({ern@services, '$10'}).

%% Services.recording
'$11'(Entries_12) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_15} -> erlang:throw(Fault_15);
        {'Record', Entry_13} ->
            '$11'(ern@list:'$1'(Entries_12, [Entry_13]));
        {'Entries', Reply_14} ->
            ern_rt:answer(Reply_14, Entries_12),
            '$11'(Entries_12)
    end.

%% Services.main
'$12'() ->
    case ern@io:'$12'() of
        'None' -> 'Unit';
        {'Some', Line_16} ->
            case '$16'(Line_16) of
                {'Some', Command_17} ->
                    '$13'(Command_17, ern@string:'$13'(Line_16));
                'None' ->
                    ern@io:'$8'(<<"commands: add KEY COUNT, take KEY COUNT, "
                                  "count KEY, audit">>)
            end,
            '$12'()
    end.

%% Services.obey
'$13'(Command_18, Line_19) ->
    case Command_18 of
        {'Add', Key_20, Count_21} ->
            '$14'(Key_20, Count_21, Line_19);
        {'Take', Key_22, Count_23} ->
            '$14'(Key_22, -Count_23, Line_19);
        {'Count', Key_24} ->
            case ern_rt:call('$6'(),
                             fun (Reply_25) -> {'Get', Key_24, Reply_25} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', Held_26} ->
                    ern@io:'$8'(<<Key_24/binary, ": ",
                                  (ern@int:'$24'(Held_26))/binary>>);
                'None' -> ern@io:'$8'(<<Line_19/binary, ": no answer">>)
            end;
        'Audit' ->
            ern@io:'$8'(<<"audit: ",
                          ('$19'('$15'('$10'(),
                                       fun (Reply_27) -> {'Entries', Reply_27}
                                       end)))/binary>>)
    end.

%% Services.change
'$14'(Key_28, By_29, Line_30) ->
    case ern_rt:call('$6'(),
                     fun (Reply_31) -> {'Change', Key_28, By_29, Reply_31}
                     end,
                     5000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Held_32} ->
            Id_34 = '$15'('$8'(),
                          fun (Reply_33) -> {'NextId', Reply_33} end),
            ern_rt:send('$10'(),
                        {'Record',
                         <<"#", (ern@int:'$24'(Id_34))/binary, " ",
                           Line_30/binary>>}),
            ern@io:'$8'(<<Key_28/binary, ": ",
                          (ern@int:'$24'(Held_32))/binary>>);
        'None' -> ern@io:'$8'(<<Line_30/binary, ": no answer">>)
    end.

%% Services.asked
'$15'(Service_35, Request_36) ->
    case ern_rt:call(Service_35, Request_36, 1000, none) of
        {'Some', Value_37} -> Value_37;
        'None' -> '$15'(Service_35, Request_36)
    end.

%% Services.parsed
'$16'(Line_38) ->
    case ern@string:'$18'(Line_38) of
        [<<"add">>, Key_39, Count_40] ->
            ern@optional:'$5'('$17'(Count_40),
                              fun (N_41) -> {'Add', Key_39, N_41} end);
        [<<"take">>, Key_42, Count_43] ->
            ern@optional:'$5'('$17'(Count_43),
                              fun (N_44) -> {'Take', Key_42, N_44} end);
        [<<"count">>, Key_45] -> {'Some', {'Count', Key_45}};
        [<<"audit">>] -> {'Some', 'Audit'};
        _ -> 'None'
    end.

%% Services.counted
'$17'(Text_46) ->
    case ern@list:'$15'(ern@string:'$42'(Text_46),
                        fun ern@char:'$1'/1)
        of
        true -> ern@string:'$24'(Text_46);
        false -> 'None'
    end.

%% Services.inStock
'$18'(Stock_47, Key_48) ->
    ern@optional:'$4'(ern@map:'$18'(Stock_47, Key_48), 0).

%% Services.audited
'$19'(Entries_49) ->
    case ern@list:'$3'(Entries_49) of
        true -> <<"none">>;
        false -> ern@string:'$23'(Entries_49, <<", ">>)
    end.

'$init'() ->
    ern_rt:initializing(<<"Services.services:62">>),
    persistent_term:put({ern@services, '$5'},
                        ern_rt:spawn(ern@supervisor:'$8'('RestForOne',
                                                         {'RestartLimit',
                                                          3,
                                                          10000}),
                                     <<"Services.services:63">>)),
    ern_rt:initializing(<<"Services.store:65">>),
    persistent_term:put({ern@services, '$6'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () ->
                                                                  '$7'(ern@map:'$1'())
                                                          end),
                                     <<"Services.store:65">>)),
    ern_rt:initializing(<<"Services.ids:86">>),
    persistent_term:put({ern@services, '$8'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () -> '$9'(1)
                                                          end),
                                     <<"Services.ids:86">>)),
    ern_rt:initializing(<<"Services.audit:96">>),
    persistent_term:put({ern@services, '$10'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () -> '$11'([])
                                                          end),
                                     <<"Services.audit:96">>)),
    ok.

'$spawned'('$12', []) -> '$12'().
