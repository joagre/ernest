-module(ernest@counter).

-export([main/0]).

main() ->
    C_1 = ern_rt:spawn('Local',
                       fun () -> counter(0) end,
                       <<"Counter.main:17">>),
    ern_rt:send(C_1, {'Inc', 5}),
    ern_rt:send(C_1, {'Inc', 3}),
    case ern_check:value('$type_1'(),
                         ern_rt:call(C_1, fun (R_2) -> {'Get', R_2} end, 1000),
                         <<"reply does not match Optional(Int)">>)
        of
        {'Some', N_3} ->
            ernest@io:println(<<"count is ",
                                (ernest@int:toString(N_3))/binary>>);
        'None' ->
            ernest@io:println(<<"counter is not answering">>)
    end.

counter(N_4) ->
    receive
        {'Inc', K_5} = M_6 ->
            ern_check:value('$type_2'(),
                            M_6,
                            <<"message does not match CounterMsg">>),
            counter(N_4 + K_5);
        {'Get', R_7} = M_8 ->
            ern_check:value('$type_2'(),
                            M_8,
                            <<"message does not match CounterMsg">>),
            ern_rt:answer(R_7, N_4),
            counter(N_4);
        {'Upgrade', M_9, K_10} = M_11 ->
            ern_check:value('$type_2'(),
                            M_11,
                            <<"message does not match CounterMsg">>),
            K_10(M_9(N_4))
    end.

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.

'$type_2'() ->
    {con,
     [{'Inc', [int]},
      {'Get', [ref]},
      {'Upgrade', [{'fun', 1}, {'fun', 1}]}]}.
