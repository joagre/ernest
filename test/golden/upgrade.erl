-module(ernest@upgrade).

-export([main/0]).

main() ->
    C_1 = ern_rt:spawn('Local',
                       fun () -> counter(0) end,
                       <<"Upgrade.main:17">>),
    ern_rt:send(C_1, {'Inc', 5}),
    ern_rt:send(C_1, {'Inc', 3}),
    case ern_check:value('$type_1'(),
                         ern_rt:call(C_1, fun (R_2) -> {'Get', R_2} end, 1000),
                         <<"reply does not match Optional(Int)">>)
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
    case ern_check:value('$type_1'(),
                         ern_rt:call(C_1, fun (R_5) -> {'Get', R_5} end, 1000),
                         <<"reply does not match Optional(Int)">>)
        of
        {'Some', N_6} ->
            ernest@io:println(<<"after upgrade: ",
                                (ernest@int:toString(N_6))/binary>>);
        'None' -> ernest@io:println(<<"timeout">>)
    end.

counter(N_7) ->
    receive
        {'Inc', K_8} = M_9 ->
            ern_check:value('$type_2'(),
                            M_9,
                            <<"message does not match CounterMsg">>),
            counter(N_7 + K_8);
        {'Get', R_10} = M_11 ->
            ern_check:value('$type_2'(),
                            M_11,
                            <<"message does not match CounterMsg">>),
            ern_rt:answer(R_10, N_7),
            counter(N_7);
        {'Upgrade', M_12, K_13} = M_14 ->
            ern_check:value('$type_2'(),
                            M_14,
                            <<"message does not match CounterMsg">>),
            K_13(M_12(N_7))
    end.

doublingCounter(N_15) ->
    receive
        {'Inc', K_16} = M_17 ->
            ern_check:value('$type_2'(),
                            M_17,
                            <<"message does not match CounterMsg">>),
            doublingCounter(N_15 + 2 * K_16);
        {'Get', R_18} = M_19 ->
            ern_check:value('$type_2'(),
                            M_19,
                            <<"message does not match CounterMsg">>),
            ern_rt:answer(R_18, N_15),
            doublingCounter(N_15);
        {'Upgrade', M_20, K_21} = M_22 ->
            ern_check:value('$type_2'(),
                            M_22,
                            <<"message does not match CounterMsg">>),
            K_21(M_20(N_15))
    end.

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.

'$type_2'() ->
    {con,
     [{'Inc', [int]},
      {'Get', [ref]},
      {'Upgrade', [{'fun', 1}, {'fun', 1}]}]}.
