-module(ern@counter).

-export([main/0, '$fun'/2]).

main() ->
    C_1 = ern_rt:spawn(fun () -> counter(0) end,
                       <<"Counter.main:17">>),
    ern_rt:send(C_1, {'Inc', 5}),
    ern_rt:send(C_1, {'Inc', 3}),
    case ern_rt:call(C_1,
                     fun (R_2) -> {'Get', R_2} end,
                     1000,
                     {int, <<"reply does not match Int">>})
        of
        {'Some', N_3} ->
            ern@io:println(<<"count is ",
                             (ern@int:toString(N_3))/binary>>);
        'None' -> ern@io:println(<<"counter is not answering">>)
    end.

counter(N_4) ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Inc', K_5} -> counter(N_4 + K_5);
        {'Get', R_6} ->
            ern_rt:answer(R_6, N_4),
            counter(N_4);
        {'Upgrade', M_7, K_8} -> K_8(M_7(N_4))
    end.

'$fun'(main, 0) -> fun main/0.
