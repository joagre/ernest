-module(ern@services).

-dialyzer(no_return).

-export(['$5'/0,
         '$6'/0,
         '$8'/0,
         '$10'/0,
         '$12'/0,
         '$init'/0,
         '$5.init'/0,
         '$6.init'/0,
         '$8.init'/0,
         '$10.init'/0,
         '$spawned'/2]).

%% Services.services
'$5'() -> ern_rt:binding({ern@services, '$5'}).

%% Services.store
'$6'() -> ern_rt:binding({ern@services, '$6'}).

%% Services.storing
'$7'(Stock_1) ->
    begin
        ern_rt:at_receive(),
        receive
            '$ern_restart' -> ern_rt:restart_now();
            {'$ern_fault', Fault_8} -> erlang:throw(Fault_8);
            {'Change', Key_2, By_3, Reply_4} ->
                Held_5 = '$18'(Stock_1, Key_2),
                case Held_5 + By_3 < 0 of
                    true ->
                        try ern_rt:fault(<<Key_2/binary, ": cannot take ",
                                           (erlang:integer_to_binary(-By_3))/binary,
                                           " of ",
                                           (erlang:integer_to_binary(Held_5))/binary>>)
                        after
                            ok
                        end;
                    false ->
                        ern_rt:answer(Reply_4, Held_5 + By_3),
                        '$7'(ern@map:'$4'(Stock_1, Key_2, Held_5 + By_3))
                end;
            {'Get', Key_6, Reply_7} ->
                ern_rt:answer(Reply_7, '$18'(Stock_1, Key_6)),
                '$7'(Stock_1)
        end
    end.

%% Services.ids
'$8'() -> ern_rt:binding({ern@services, '$8'}).

%% Services.counting
'$9'(Next_9) ->
    begin
        ern_rt:at_receive(),
        receive
            '$ern_restart' -> ern_rt:restart_now();
            {'$ern_fault', Fault_11} -> erlang:throw(Fault_11);
            {'NextId', Reply_10} ->
                ern_rt:answer(Reply_10, Next_9),
                '$9'(Next_9 + 1)
        end
    end.

%% Services.audit
'$10'() -> ern_rt:binding({ern@services, '$10'}).

%% Services.recording
'$11'(Entries_12) ->
    begin
        ern_rt:at_receive(),
        receive
            '$ern_restart' -> ern_rt:restart_now();
            {'$ern_fault', Fault_15} -> erlang:throw(Fault_15);
            {'Record', Entry_13} -> '$11'(Entries_12 ++ [Entry_13]);
            {'Entries', Reply_14} ->
                ern_rt:answer(Reply_14, Entries_12),
                '$11'(Entries_12)
        end
    end.

%% Services.main
'$12'() ->
    case ern@io:'$12'() of
        'None' -> 'Unit';
        {'Some', Line_16} ->
            case '$16'(Line_16) of
                {'Some', Command_17} ->
                    '$13'(Command_17, ern@string:'$16'(Line_16));
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
                                  (erlang:integer_to_binary(Held_26))/binary>>);
                'None' -> ern@io:'$8'(<<Line_19/binary, ": no answer">>)
            end;
        'Audit' ->
            case '$15'('$10'(),
                       fun (Argument_27) -> {'Entries', Argument_27} end)
                of
                {'Some', Entries_28} ->
                    ern@io:'$8'(<<"audit: ", ('$19'(Entries_28))/binary>>);
                'None' -> ern@io:'$8'(<<Line_19/binary, ": no answer">>)
            end
    end.

%% Services.change
'$14'(Key_29, By_30, Line_31) ->
    case ern_rt:call('$6'(),
                     fun (Reply_32) -> {'Change', Key_29, By_30, Reply_32}
                     end,
                     5000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Held_33} ->
            case '$15'('$8'(),
                       fun (Argument_34) -> {'NextId', Argument_34} end)
                of
                {'Some', Id_35} ->
                    ern_rt:send('$10'(),
                                {'Record',
                                 <<"#",
                                   (erlang:integer_to_binary(Id_35))/binary,
                                   " ", Line_31/binary>>});
                'None' -> ern@io:'$8'(<<Line_31/binary, ": no answer">>)
            end,
            ern@io:'$8'(<<Key_29/binary, ": ",
                          (erlang:integer_to_binary(Held_33))/binary>>);
        'None' -> ern@io:'$8'(<<Line_31/binary, ": no answer">>)
    end.

%% Services.asked
'$15'(Service_36, Request_37) ->
    case ern_rt:call(Service_36, Request_37, 1000, none) of
        {'Some', Value_38} -> {'Some', Value_38};
        'None' ->
            ern_rt:call(Service_36, Request_37, 1000, none)
    end.

%% Services.parsed
'$16'(Line_39) ->
    case ern@string:'$23'(Line_39) of
        [<<"add">>, Key_40, Count_41] ->
            ern@optional:'$5'('$17'(Count_41),
                              fun (N_42) -> {'Add', Key_40, N_42} end);
        [<<"take">>, Key_43, Count_44] ->
            ern@optional:'$5'('$17'(Count_44),
                              fun (N_45) -> {'Take', Key_43, N_45} end);
        [<<"count">>, Key_46] -> {'Some', {'Count', Key_46}};
        [<<"audit">>] -> {'Some', 'Audit'};
        _ -> 'None'
    end.

%% Services.counted
'$17'(Text_47) ->
    case ern@list:'$15'(try ern_string:to_list(Text_47)
                        catch
                            Class_48:Error_49:Trace_50 ->
                                ern_boundary:shim_raised(ern_string,
                                                         to_list,
                                                         1,
                                                         Class_48,
                                                         Error_49,
                                                         Trace_50)
                        end,
                        fun ern@char:'$1'/1)
        of
        true -> ern@string:'$30'(Text_47);
        false -> 'None'
    end.

%% Services.inStock
'$18'(Stock_51, Key_52) ->
    ern@optional:'$4'(try ern_map:get(Stock_51, Key_52)
                      catch
                          Class_53:Error_54:Trace_55 ->
                              ern_boundary:shim_raised(ern_map,
                                                       get,
                                                       2,
                                                       Class_53,
                                                       Error_54,
                                                       Trace_55)
                      end,
                      0).

%% Services.audited
'$19'(Entries_56) ->
    case ern@list:'$3'(Entries_56) of
        true -> <<"none">>;
        false -> ern@string:'$29'(Entries_56, <<", ">>)
    end.

'$init'() ->
    ern@services:'$5.init'(),
    ern@services:'$6.init'(),
    ern@services:'$8.init'(),
    ern@services:'$10.init'(),
    ok.

%% the initializer of Services.services
'$5.init'() ->
    ern_rt:initializing(<<"Services.services:62">>),
    persistent_term:put({ern@services, '$5'},
                        ern_rt:spawn(ern@supervisor:'$10'('RestForOne',
                                                          {'RestartLimit',
                                                           3,
                                                           10000}),
                                     <<"Services.services:63">>)).

%% the initializer of Services.store
'$6.init'() ->
    ern_rt:initializing(<<"Services.store:65">>),
    persistent_term:put({ern@services, '$6'},
                        ern_rt:spawn(ern@supervisor:'$28'('$5'(),
                                                          fun () ->
                                                                  '$7'(ern@map:'$1'())
                                                          end),
                                     <<"Services.store:65">>)).

%% the initializer of Services.ids
'$8.init'() ->
    ern_rt:initializing(<<"Services.ids:86">>),
    persistent_term:put({ern@services, '$8'},
                        ern_rt:spawn(ern@supervisor:'$28'('$5'(),
                                                          fun () -> '$9'(1)
                                                          end),
                                     <<"Services.ids:86">>)).

%% the initializer of Services.audit
'$10.init'() ->
    ern_rt:initializing(<<"Services.audit:96">>),
    persistent_term:put({ern@services, '$10'},
                        ern_rt:spawn(ern@supervisor:'$28'('$5'(),
                                                          fun () -> '$11'([])
                                                          end),
                                     <<"Services.audit:96">>)).

'$spawned'('$12', []) -> '$12'().
