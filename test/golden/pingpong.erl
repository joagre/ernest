-module(ern@pingpong).

-export([main/0, '$fun'/2]).

main() ->
    Opponent_2 = ern_rt:spawn_monitored(fun () -> pong()
                                        end,
                                        fun (Argument_1) ->
                                                {'PongDone', Argument_1}
                                        end,
                                        <<"Pingpong.main:16">>),
    _ = ern_rt:spawn(fun () -> ping(Opponent_2, 3) end,
                     <<"Pingpong.main:17">>),
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_3} -> ern_rt:fault(Cause_3);
        {'PongDone', _} -> 'Unit'
    end.

ping(Opponent_4, Round_5) ->
    case Round_5 =:= 0 of
        true -> ern_rt:send(Opponent_4, 'Stop');
        false ->
            ern@io:println(<<"ping ",
                             (ern@int:toString(Round_5))/binary>>),
            case ern_rt:call(Opponent_4,
                             fun (Reply_6) -> {'Ping', Round_5, Reply_6} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', _} -> ping(Opponent_4, Round_5 - 1);
                'None' ->
                    ern@io:println(<<"pong is not answering">>),
                    ern_rt:send(Opponent_4, 'Stop')
            end
    end.

pong() ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Cause_9} -> ern_rt:fault(Cause_9);
        {'Ping', Round_7, Reply_8} ->
            ern@io:println(<<"pong ",
                             (ern@int:toString(Round_7))/binary>>),
            ern_rt:answer(Reply_8, Round_7),
            pong();
        'Stop' -> 'Unit'
    end.

'$fun'(main, 0) -> fun main/0.
