-module(ern@counter).

-export([main/0]).

main() ->
    C_1 = ern_rt:spawn('Local',
                       fun () -> counter(0) end,
                       <<"Counter.main:17">>),
    ern_rt:send(C_1, {'Inc', 5}),
    ern_rt:send(C_1, {'Inc', 3}),
    case ern_boundary:value('$type_1'(),
                            ern_rt:call(C_1,
                                        fun (R_2) -> {'Get', R_2} end,
                                        1000),
                            <<"reply does not match Optional(Int)">>)
        of
        {'Some', N_3} ->
            ern@io:println(<<"count is ",
                             (ern@int:toString(N_3))/binary>>);
        'None' -> ern@io:println(<<"counter is not answering">>)
    end.

counter(N_4) ->
    receive
        {'Inc', K_5} -> counter(N_4 + K_5);
        {'Get', R_6} ->
            ern_rt:answer(R_6, N_4),
            counter(N_4);
        {'Upgrade', M_7, K_8} -> K_8(M_7(N_4))
    end.

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.
