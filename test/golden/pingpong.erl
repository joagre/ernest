-module(ern@pingpong).

-export([main/0]).

main() ->
    PongAddr_1 = ern_rt:spawn('Local',
                              fun () -> pong() end,
                              <<"Pingpong.main:15">>),
    _ = ern_rt:spawn('Local',
                     fun () -> ping(PongAddr_1, 3) end,
                     <<"Pingpong.main:16">>),
    ern_rt:monitor(PongAddr_1,
                   fun (V_2) -> {'PongDone', V_2} end),
    receive {'PongDone', _} -> 'Unit' end.

ping(PongAddr_3, N_4) ->
    case N_4 =:= 0 of
        true -> ern_rt:send(PongAddr_3, 'Stop');
        false ->
            ern@io:println(<<"ping ",
                             (ern@int:toString(N_4))/binary>>),
            case ern_boundary:value('$type_1'(),
                                    ern_rt:call(PongAddr_3,
                                                fun (R_5) -> {'Ping', N_4, R_5}
                                                end,
                                                5000),
                                    <<"reply does not match Optional(Int)">>)
                of
                {'Some', _} -> ping(PongAddr_3, N_4 - 1);
                'None' ->
                    ern@io:println(<<"pong is not answering">>),
                    ern_rt:send(PongAddr_3, 'Stop')
            end
    end.

pong() ->
    receive
        {'Ping', N_6, R_7} ->
            ern@io:println(<<"pong ",
                             (ern@int:toString(N_6))/binary>>),
            ern_rt:answer(R_7, N_6),
            pong();
        'Stop' -> 'Unit'
    end.

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.
