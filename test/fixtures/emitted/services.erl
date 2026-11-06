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
    fun Wait_9(After_10) ->
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
                after After_10 -> ern_rt:collect(), Wait_9(infinity)
            end
    end(1).

%% Services.ids
'$8'() -> ern_rt:binding({ern@services, '$8'}).

%% Services.counting
'$9'(Next_11) ->
    fun Wait_14(After_15) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_13} -> erlang:throw(Fault_13);
                {'NextId', Reply_12} ->
                    ern_rt:answer(Reply_12, Next_11),
                    '$9'(Next_11 + 1)
                after After_15 -> ern_rt:collect(), Wait_14(infinity)
            end
    end(1).

%% Services.audit
'$10'() -> ern_rt:binding({ern@services, '$10'}).

%% Services.recording
'$11'(Entries_16) ->
    fun Wait_20(After_21) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_19} -> erlang:throw(Fault_19);
                {'Record', Entry_17} ->
                    '$11'(ern@list:'$1'(Entries_16, [Entry_17]));
                {'Entries', Reply_18} ->
                    ern_rt:answer(Reply_18, Entries_16),
                    '$11'(Entries_16)
                after After_21 -> ern_rt:collect(), Wait_20(infinity)
            end
    end(1).

%% Services.main
'$12'() ->
    case ern@io:'$12'() of
        'None' -> 'Unit';
        {'Some', Line_22} ->
            case '$16'(Line_22) of
                {'Some', Command_23} ->
                    '$13'(Command_23, ern@string:'$13'(Line_22));
                'None' ->
                    ern@io:'$8'(<<"commands: add KEY COUNT, take KEY COUNT, "
                                  "count KEY, audit">>)
            end,
            '$12'()
    end.

%% Services.obey
'$13'(Command_24, Line_25) ->
    case Command_24 of
        {'Add', Key_26, Count_27} ->
            '$14'(Key_26, Count_27, Line_25);
        {'Take', Key_28, Count_29} ->
            '$14'(Key_28, -Count_29, Line_25);
        {'Count', Key_30} ->
            case ern_rt:call('$6'(),
                             fun (Reply_31) -> {'Get', Key_30, Reply_31} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', Held_32} ->
                    ern@io:'$8'(<<Key_30/binary, ": ",
                                  (erlang:integer_to_binary(Held_32))/binary>>);
                'None' -> ern@io:'$8'(<<Line_25/binary, ": no answer">>)
            end;
        'Audit' ->
            ern@io:'$8'(<<"audit: ",
                          ('$19'('$15'('$10'(),
                                       fun (Argument_33) ->
                                               {'Entries', Argument_33}
                                       end)))/binary>>)
    end.

%% Services.change
'$14'(Key_34, By_35, Line_36) ->
    case ern_rt:call('$6'(),
                     fun (Reply_37) -> {'Change', Key_34, By_35, Reply_37}
                     end,
                     5000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', Held_38} ->
            Id_40 = '$15'('$8'(),
                          fun (Argument_39) -> {'NextId', Argument_39} end),
            ern_rt:send('$10'(),
                        {'Record',
                         <<"#", (erlang:integer_to_binary(Id_40))/binary, " ",
                           Line_36/binary>>}),
            ern@io:'$8'(<<Key_34/binary, ": ",
                          (erlang:integer_to_binary(Held_38))/binary>>);
        'None' -> ern@io:'$8'(<<Line_36/binary, ": no answer">>)
    end.

%% Services.asked
'$15'(Service_41, Request_42) ->
    case ern_rt:call(Service_41, Request_42, 1000, none) of
        {'Some', Value_43} -> Value_43;
        'None' -> '$15'(Service_41, Request_42)
    end.

%% Services.parsed
'$16'(Line_44) ->
    case ern@string:'$18'(Line_44) of
        [<<"add">>, Key_45, Count_46] ->
            ern@optional:'$5'('$17'(Count_46),
                              fun (N_47) -> {'Add', Key_45, N_47} end);
        [<<"take">>, Key_48, Count_49] ->
            ern@optional:'$5'('$17'(Count_49),
                              fun (N_50) -> {'Take', Key_48, N_50} end);
        [<<"count">>, Key_51] -> {'Some', {'Count', Key_51}};
        [<<"audit">>] -> {'Some', 'Audit'};
        _ -> 'None'
    end.

%% Services.counted
'$17'(Text_52) ->
    case ern@list:'$15'(try ern_string:to_list(Text_52)
                        catch
                            Class_53:Error_54:Trace_55 ->
                                ern_boundary:raised(ern_string,
                                                    to_list,
                                                    1,
                                                    Class_53,
                                                    Error_54,
                                                    Trace_55)
                        end,
                        fun ern@char:'$1'/1)
        of
        true -> ern@string:'$25'(Text_52);
        false -> 'None'
    end.

%% Services.inStock
'$18'(Stock_56, Key_57) ->
    ern@optional:'$4'(try ern_map:get(Stock_56, Key_57)
                      catch
                          Class_58:Error_59:Trace_60 ->
                              ern_boundary:raised(ern_map,
                                                  get,
                                                  2,
                                                  Class_58,
                                                  Error_59,
                                                  Trace_60)
                      end,
                      0).

%% Services.audited
'$19'(Entries_61) ->
    case ern@list:'$3'(Entries_61) of
        true -> <<"none">>;
        false -> ern@string:'$24'(Entries_61, <<", ">>)
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
                        ern_rt:spawn(ern@supervisor:'$8'('RestForOne',
                                                         {'RestartLimit',
                                                          3,
                                                          10000}),
                                     <<"Services.services:63">>)).

%% the initializer of Services.store
'$6.init'() ->
    ern_rt:initializing(<<"Services.store:65">>),
    persistent_term:put({ern@services, '$6'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () ->
                                                                  '$7'(ern@map:'$1'())
                                                          end),
                                     <<"Services.store:65">>)).

%% the initializer of Services.ids
'$8.init'() ->
    ern_rt:initializing(<<"Services.ids:86">>),
    persistent_term:put({ern@services, '$8'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () -> '$9'(1)
                                                          end),
                                     <<"Services.ids:86">>)).

%% the initializer of Services.audit
'$10.init'() ->
    ern_rt:initializing(<<"Services.audit:96">>),
    persistent_term:put({ern@services, '$10'},
                        ern_rt:spawn(ern@supervisor:'$21'('$5'(),
                                                          fun () -> '$11'([])
                                                          end),
                                     <<"Services.audit:96">>)).

'$spawned'('$12', []) -> '$12'().
