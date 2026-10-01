-module(ern@services).

-compile({no_auto_import, [{put, 2}]}).

-export([main/0, '$init'/0, '$fun'/2]).

services() -> ern_rt:binding({ern@services, services}).

store() -> ern_rt:binding({ern@services, store}).

storing(Items_1) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Put', K_2, V_3} ->
            storing(ern@map:put(Items_1, K_2, V_3));
        {'Get', K_4, R_5} ->
            ern_rt:answer(R_5, ern@map:get(Items_1, K_4)),
            storing(Items_1);
        'Corrupt' -> ern_rt:fault(<<"the store was corrupted">>)
    end.

ids() -> ern_rt:binding({ern@services, ids}).

counting(Next_6) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'NextId', R_7} ->
            ern_rt:answer(R_7, Next_6),
            counting(Next_6 + 1)
    end.

audit() -> ern_rt:binding({ern@services, audit}).

recording(Entries_8) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Record', E_9} ->
            recording(ern@list:'<>'(Entries_8, [E_9]));
        {'Entries', R_10} ->
            ern_rt:answer(R_10, Entries_8),
            recording(Entries_8)
    end.

main() ->
    put(<<"apples">>, 3),
    put(<<"pears">>, 5),
    report(<<"before">>),
    ern_rt:send(store(), 'Corrupt'),
    report(<<"after the restart">>).

put(Key_11, Value_12) ->
    Id_14 = ern_rt:call_forever(ids(),
                                fun (R_13) -> {'NextId', R_13} end,
                                {int, <<"reply does not match Int">>}),
    ern_rt:send(store(), {'Put', Key_11, Value_12}),
    ern_rt:send(audit(),
                {'Record',
                 <<(ern@int:toString(Id_14))/binary, ": put ",
                   Key_11/binary>>}).

report(Moment_15) ->
    Apples_17 = case stored(<<"apples">>) of
                    {'Some', N_16} -> ern@int:toString(N_16);
                    'None' -> <<"none">>
                end,
    Entries_19 = ern_rt:call_forever(audit(),
                                     fun (R_18) -> {'Entries', R_18} end,
                                     {'$type_1'(),
                                      <<"reply does not match List(String)">>}),
    Id_21 = ern_rt:call_forever(ids(),
                                fun (R_20) -> {'NextId', R_20} end,
                                {int, <<"reply does not match Int">>}),
    ern@io:println(<<Moment_15/binary, ": apples ",
                     Apples_17/binary, ", next id ",
                     (ern@int:toString(Id_21))/binary, ", audit [",
                     (ern@string:join(Entries_19, <<"; ">>))/binary, "]">>).

stored(Key_22) ->
    case ern_rt:call(store(),
                     fun (R_23) -> {'Get', Key_22, R_23} end,
                     1000,
                     {'$type_2'(), <<"reply does not match Optional(Int)">>})
        of
        {'Some', Value_24} -> Value_24;
        'None' -> stored(Key_22)
    end.

'$init'() ->
    ern_rt:initializing(<<"Services.services:22">>),
    persistent_term:put({ern@services, services},
                        ern_rt:spawn('Local',
                                     ern@supervisor:group('RestForOne',
                                                          {'RestartLimit',
                                                           3,
                                                           10000}),
                                     <<"Services.services:23">>)),
    ern_rt:initializing(<<"Services.store:26">>),
    persistent_term:put({ern@services, store},
                        ern_rt:spawn('Local',
                                     ern@supervisor:child(services(),
                                                          fun () ->
                                                                  storing(ern@map:empty())
                                                          end),
                                     <<"Services.store:26">>)),
    ern_rt:initializing(<<"Services.ids:38">>),
    persistent_term:put({ern@services, ids},
                        ern_rt:spawn('Local',
                                     ern@supervisor:child(services(),
                                                          fun () -> counting(1)
                                                          end),
                                     <<"Services.ids:38">>)),
    ern_rt:initializing(<<"Services.audit:48">>),
    persistent_term:put({ern@services, audit},
                        ern_rt:spawn('Local',
                                     ern@supervisor:child(services(),
                                                          fun () ->
                                                                  recording([])
                                                          end),
                                     <<"Services.audit:48">>)),
    ok.

'$fun'(main, 0) -> fun main/0.

'$type_1'() -> {list, string}.

'$type_2'() -> {con, [{'None', []}, {'Some', [int]}]}.
