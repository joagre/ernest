-module(ern@pingpong).

-export([main/0, '$fun'/2]).

main() ->
    Opponent_2 = ern_rt:spawn_monitored(fun () -> pong()
                                        end,
                                        fun (V_1) -> {'PongDone', V_1} end,
                                        <<"Pingpong.main:16">>),
    _ = ern_rt:spawn(fun () -> ping(Opponent_2, 3) end,
                     <<"Pingpong.main:17">>),
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'PongDone', _} -> 'Unit'
    end.

ping(Opponent_3, Round_4) ->
    case Round_4 =:= 0 of
        true -> ern_rt:send(Opponent_3, 'Stop');
        false ->
            ern@io:println(<<"ping ",
                             (ern@int:toString(Round_4))/binary>>),
            case ern_rt:call(Opponent_3,
                             fun (Reply_5) -> {'Ping', Round_4, Reply_5} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', _} -> ping(Opponent_3, Round_4 - 1);
                'None' ->
                    ern@io:println(<<"pong is not answering">>),
                    ern_rt:send(Opponent_3, 'Stop')
            end
    end.

pong() ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'Ping', Round_6, Reply_7} ->
            ern@io:println(<<"pong ",
                             (ern@int:toString(Round_6))/binary>>),
            ern_rt:answer(Reply_7, Round_6),
            pong();
        'Stop' -> 'Unit'
    end.

'$fun'(main, 0) -> fun main/0.
