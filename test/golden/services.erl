-module(ern@services).

-compile({no_auto_import, [{put, 2}]}).

-export([main/0, '$init'/0, '$fun'/2]).

services() -> ern_rt:binding({ern@services, services}).

store() -> ern_rt:binding({ern@services, store}).

storing(Items_1) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_6} -> ern_rt:fault(Cause_6);
        {'Put', Key_2, Value_3} ->
            storing(ern@map:put(Items_1, Key_2, Value_3));
        {'Get', Key_4, Reply_5} ->
            ern_rt:answer(Reply_5, ern@map:get(Items_1, Key_4)),
            storing(Items_1);
        'Corrupt' -> ern_rt:fault(<<"the store was corrupted">>)
    end.

ids() -> ern_rt:binding({ern@services, ids}).

counting(Next_7) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_9} -> ern_rt:fault(Cause_9);
        {'NextId', Reply_8} ->
            ern_rt:answer(Reply_8, Next_7),
            counting(Next_7 + 1)
    end.

audit() -> ern_rt:binding({ern@services, audit}).

recording(Entries_10) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_13} -> ern_rt:fault(Cause_13);
        {'Record', Entry_11} ->
            recording(ern@list:'<>'(Entries_10, [Entry_11]));
        {'Entries', Reply_12} ->
            ern_rt:answer(Reply_12, Entries_10),
            recording(Entries_10)
    end.

main() ->
    put(<<"apples">>, 3),
    put(<<"pears">>, 5),
    report(<<"before">>),
    ern_rt:send(store(), 'Corrupt'),
    report(<<"after the restart">>).

put(Key_14, Value_15) ->
    Id_17 = ern_rt:call_forever(ids(),
                                fun (Reply_16) -> {'NextId', Reply_16} end,
                                {int, <<"reply does not match Int">>}),
    ern_rt:send(store(), {'Put', Key_14, Value_15}),
    ern_rt:send(audit(),
                {'Record',
                 <<(ern@int:toString(Id_17))/binary, ": put ",
                   Key_14/binary>>}).

report(Label_18) ->
    Apples_20 = case stored(<<"apples">>) of
                    {'Some', Count_19} -> ern@int:toString(Count_19);
                    'None' -> <<"none">>
                end,
    Entries_22 = ern_rt:call_forever(audit(),
                                     fun (Reply_21) -> {'Entries', Reply_21}
                                     end,
                                     {'$type_1'(),
                                      <<"reply does not match List(String)">>}),
    Id_24 = ern_rt:call_forever(ids(),
                                fun (Reply_23) -> {'NextId', Reply_23} end,
                                {int, <<"reply does not match Int">>}),
    ern@io:println(<<Label_18/binary, ": apples ",
                     Apples_20/binary, ", next id ",
                     (ern@int:toString(Id_24))/binary, ", audit [",
                     (ern@string:join(Entries_22, <<"; ">>))/binary, "]">>).

stored(Key_25) ->
    case ern_rt:call(store(),
                     fun (Reply_26) -> {'Get', Key_25, Reply_26} end,
                     1000,
                     {'$type_2'(), <<"reply does not match Optional(Int)">>})
        of
        {'Some', Value_27} -> Value_27;
        'None' -> stored(Key_25)
    end.

'$init'() ->
    ern_rt:initializing(<<"Services.services:22">>),
    persistent_term:put({ern@services, services},
                        ern_rt:spawn(ern@supervisor:group('RestForOne',
                                                          {'RestartLimit',
                                                           3,
                                                           10000}),
                                     <<"Services.services:23">>)),
    ern_rt:initializing(<<"Services.store:25">>),
    persistent_term:put({ern@services, store},
                        ern_rt:spawn(ern@supervisor:child(services(),
                                                          fun () ->
                                                                  storing(ern@map:empty())
                                                          end),
                                     <<"Services.store:25">>)),
    ern_rt:initializing(<<"Services.ids:37">>),
    persistent_term:put({ern@services, ids},
                        ern_rt:spawn(ern@supervisor:child(services(),
                                                          fun () -> counting(1)
                                                          end),
                                     <<"Services.ids:37">>)),
    ern_rt:initializing(<<"Services.audit:47">>),
    persistent_term:put({ern@services, audit},
                        ern_rt:spawn(ern@supervisor:child(services(),
                                                          fun () ->
                                                                  recording([])
                                                          end),
                                     <<"Services.audit:47">>)),
    ok.

'$fun'(main, 0) -> fun main/0.

'$type_1'() -> {list, string}.

'$type_2'() -> {con, [{'None', []}, {'Some', [int]}]}.
