-module(ern@pingpong).

-dialyzer(no_return).

-export(['$3'/0, '$spawned'/2]).

%% Pingpong.main
'$3'() ->
    Opponent_2 = ern_rt:spawn_monitored(fun () -> '$5'()
                                        end,
                                        fun (Argument_1) ->
                                                {'PongDone', Argument_1}
                                        end,
                                        <<"Pingpong.main:16">>),
    _ = ern_rt:spawn(fun () -> '$4'(Opponent_2, 3) end,
                     <<"Pingpong.main:17">>),
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_3} -> erlang:throw(Fault_3);
        {'PongDone', _} -> 'Unit'
    end.

%% Pingpong.ping
'$4'(Opponent_4, Round_5) ->
    case Round_5 =:= 0 of
        true -> ern_rt:send(Opponent_4, 'Stop');
        false ->
            ern@io:'$8'(<<"ping ",
                          (ern@int:'$24'(Round_5))/binary>>),
            case ern_rt:call(Opponent_4,
                             fun (Reply_6) -> {'Ping', Round_5, Reply_6} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', _} -> '$4'(Opponent_4, Round_5 - 1);
                'None' ->
                    ern@io:'$8'(<<"pong is not answering">>),
                    ern_rt:send(Opponent_4, 'Stop')
            end
    end.

%% Pingpong.pong
'$5'() ->
    receive
        '$ern_restart' -> ern_rt:restart_now();
        {'$ern_fault', Fault_9} -> erlang:throw(Fault_9);
        {'Ping', Round_7, Reply_8} ->
            ern@io:'$8'(<<"pong ",
                          (ern@int:'$24'(Round_7))/binary>>),
            ern_rt:answer(Reply_8, Round_7),
            '$5'();
        'Stop' -> 'Unit'
    end.

'$spawned'('$3', []) -> '$3'();
'$spawned'('$5', []) -> '$5'().
