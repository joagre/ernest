-module(ern@services).

-dialyzer(no_return).

-export(['$4'/0,
         '$5'/0,
         '$7'/0,
         '$9'/0,
         '$11'/0,
         '$init'/0,
         '$spawned'/2]).

%% Services.services
'$4'() -> ern_rt:binding({ern@services, '$4'}).

%% Services.store
'$5'() -> ern_rt:binding({ern@services, '$5'}).

%% Services.storing
'$6'(Items_1) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_6} -> ern_rt:fault(Cause_6);
        {'Put', Key_2, Value_3} ->
            '$6'(ern@map:'$4'(Items_1, Key_2, Value_3));
        {'Get', Key_4, Reply_5} ->
            ern_rt:answer(Reply_5, ern@map:'$18'(Items_1, Key_4)),
            '$6'(Items_1);
        'Corrupt' -> ern_rt:fault(<<"the store was corrupted">>)
    end.

%% Services.ids
'$7'() -> ern_rt:binding({ern@services, '$7'}).

%% Services.counting
'$8'(Next_7) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_9} -> ern_rt:fault(Cause_9);
        {'NextId', Reply_8} ->
            ern_rt:answer(Reply_8, Next_7),
            '$8'(Next_7 + 1)
    end.

%% Services.audit
'$9'() -> ern_rt:binding({ern@services, '$9'}).

%% Services.recording
'$10'(Entries_10) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_13} -> ern_rt:fault(Cause_13);
        {'Record', Entry_11} ->
            '$10'(ern@list:'$1'(Entries_10, [Entry_11]));
        {'Entries', Reply_12} ->
            ern_rt:answer(Reply_12, Entries_10),
            '$10'(Entries_10)
    end.

%% Services.main
'$11'() ->
    '$12'(<<"apples">>, 3),
    '$12'(<<"pears">>, 5),
    '$13'(<<"before">>),
    ern_rt:send('$5'(), 'Corrupt'),
    '$13'(<<"after the restart">>).

%% Services.put
'$12'(Key_14, Value_15) ->
    Id_17 = ern_rt:call_forever('$7'(),
                                fun (Reply_16) -> {'NextId', Reply_16} end,
                                {int, <<"reply does not match Int">>}),
    ern_rt:send('$5'(), {'Put', Key_14, Value_15}),
    ern_rt:send('$9'(),
                {'Record',
                 <<(ern@int:'$24'(Id_17))/binary, ": put ",
                   Key_14/binary>>}).

%% Services.report
'$13'(Label_18) ->
    Apples_20 = case '$14'(<<"apples">>) of
                    {'Some', Count_19} -> ern@int:'$24'(Count_19);
                    'None' -> <<"none">>
                end,
    Entries_22 = ern_rt:call_forever('$9'(),
                                     fun (Reply_21) -> {'Entries', Reply_21}
                                     end,
                                     {'$type_1'(),
                                      <<"reply does not match List(String)">>}),
    Id_24 = ern_rt:call_forever('$7'(),
                                fun (Reply_23) -> {'NextId', Reply_23} end,
                                {int, <<"reply does not match Int">>}),
    ern@io:'$8'(<<Label_18/binary, ": apples ",
                  Apples_20/binary, ", next id ",
                  (ern@int:'$24'(Id_24))/binary, ", audit [",
                  (ern@string:'$23'(Entries_22, <<"; ">>))/binary, "]">>).

%% Services.stored
'$14'(Key_25) ->
    case ern_rt:call('$5'(),
                     fun (Reply_26) -> {'Get', Key_25, Reply_26} end,
                     1000,
                     {'$type_2'(), <<"reply does not match Optional(Int)">>})
        of
        {'Some', Value_27} -> Value_27;
        'None' -> '$14'(Key_25)
    end.

'$init'() ->
    ern_rt:initializing(<<"Services.services:34">>),
    persistent_term:put({ern@services, '$4'},
                        ern_rt:spawn(ern@supervisor:'$8'('RestForOne',
                                                         {'RestartLimit',
                                                          3,
                                                          10000}),
                                     <<"Services.services:35">>)),
    ern_rt:initializing(<<"Services.store:37">>),
    persistent_term:put({ern@services, '$5'},
                        ern_rt:spawn(ern@supervisor:'$21'('$4'(),
                                                          fun () ->
                                                                  '$6'(ern@map:'$1'())
                                                          end),
                                     <<"Services.store:37">>)),
    ern_rt:initializing(<<"Services.ids:49">>),
    persistent_term:put({ern@services, '$7'},
                        ern_rt:spawn(ern@supervisor:'$21'('$4'(),
                                                          fun () -> '$8'(1)
                                                          end),
                                     <<"Services.ids:49">>)),
    ern_rt:initializing(<<"Services.audit:59">>),
    persistent_term:put({ern@services, '$9'},
                        ern_rt:spawn(ern@supervisor:'$21'('$4'(),
                                                          fun () -> '$10'([])
                                                          end),
                                     <<"Services.audit:59">>)),
    ok.

'$spawned'('$11', []) -> '$11'().

'$type_1'() -> {list, string}.

'$type_2'() -> {con, [{'None', []}, {'Some', [int]}]}.
