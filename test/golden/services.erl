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
        {'Record', E_9} -> recording(Entries_8 ++ [E_9]);
        {'Entries', R_10} ->
            ern_rt:answer(R_10, Entries_8),
            recording(Entries_8)
    end.

main() ->
    put(<<"apples">>, 3),
    put(<<"pears">>, 5),
    report(<<"before">>),
    ern_rt:send(store(), 'Corrupt'),
    begin
        Deadline_11 = ern_rt:deadline(500),
        ern_rt:timed(),
        fun Wait_12() ->
                receive
                    '$ern_restart' ->
                        ern_rt:untimed(),
                        ern_rt:restart_now()
                    after ern_rt:remaining(Deadline_11) ->
                              case ern_rt:remaining(Deadline_11) of
                                  0 ->
                                      ern_rt:untimed(),
                                      'Unit';
                                  _ -> Wait_12()
                              end
                end
        end()
    end,
    report(<<"after the restart">>).

put(Key_13, Value_14) ->
    Id_16 = ern_boundary:value(int,
                               ern_rt:call_forever(ids(),
                                                   fun (R_15) ->
                                                           {'NextId', R_15}
                                                   end),
                               <<"reply does not match Int">>),
    ern_rt:send(store(), {'Put', Key_13, Value_14}),
    ern_rt:send(audit(),
                {'Record',
                 <<(ern@int:toString(Id_16))/binary, ": put ",
                   Key_13/binary>>}).

report(Moment_17) ->
    Apples_20 = case ern_boundary:value('$type_1'(),
                                        ern_rt:call_forever(store(),
                                                            fun (R_18) ->
                                                                    {'Get',
                                                                     <<"apples">>,
                                                                     R_18}
                                                            end),
                                        <<"reply does not match Optional(Int)">>)
                    of
                    {'Some', N_19} -> ern@int:toString(N_19);
                    'None' -> <<"none">>
                end,
    Entries_22 = ern_boundary:value('$type_2'(),
                                    ern_rt:call_forever(audit(),
                                                        fun (R_21) ->
                                                                {'Entries',
                                                                 R_21}
                                                        end),
                                    <<"reply does not match List(String)">>),
    Id_24 = ern_boundary:value(int,
                               ern_rt:call_forever(ids(),
                                                   fun (R_23) ->
                                                           {'NextId', R_23}
                                                   end),
                               <<"reply does not match Int">>),
    ern@io:println(<<Moment_17/binary, ": apples ",
                     Apples_20/binary, ", next id ",
                     (ern@int:toString(Id_24))/binary, ", audit [",
                     (ern@string:join(Entries_22, <<"; ">>))/binary, "]">>).

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

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.

'$type_2'() -> {list, string}.
