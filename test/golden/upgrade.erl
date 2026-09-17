-module(ernest@upgrade).

-export([main/0]).

main() ->
    C_1 = ern_rt:spawn('Local',
                       fun () -> counter(0) end,
                       <<"Upgrade.main:17">>),
    ern_rt:send(C_1, {'Inc', 5}),
    ern_rt:send(C_1, {'Inc', 3}),
    case ern_rt:call(C_1,
                     fun (R_2) -> {'Get', R_2} end,
                     1000)
        of
        {'Some', N_3} ->
            ernest@io:println(<<"before upgrade: ",
                                (ernest@int:toString(N_3))/binary>>);
        'None' -> ernest@io:println(<<"timeout">>)
    end,
    ern_rt:send(C_1,
                {'Upgrade',
                 fun (N_4) -> N_4 end,
                 fun doublingCounter/1}),
    ern_rt:send(C_1, {'Inc', 1}),
    case ern_rt:call(C_1,
                     fun (R_5) -> {'Get', R_5} end,
                     1000)
        of
        {'Some', N_6} ->
            ernest@io:println(<<"after upgrade: ",
                                (ernest@int:toString(N_6))/binary>>);
        'None' -> ernest@io:println(<<"timeout">>)
    end.

counter(N_7) ->
    receive
        {'Inc', K_8} -> counter(N_7 + K_8);
        {'Get', R_9} ->
            ern_rt:answer(R_9, N_7),
            counter(N_7);
        {'Upgrade', M_10, K_11} -> K_11(M_10(N_7))
    end.

doublingCounter(N_12) ->
    receive
        {'Inc', K_13} -> doublingCounter(N_12 + 2 * K_13);
        {'Get', R_14} ->
            ern_rt:answer(R_14, N_12),
            doublingCounter(N_12);
        {'Upgrade', M_15, K_16} -> K_16(M_15(N_12))
    end.
