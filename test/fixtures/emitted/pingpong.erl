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
    fun Wait_4(After_5) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_3} -> erlang:throw(Fault_3);
                {'PongDone', _} -> 'Unit'
                after After_5 -> ern_rt:collect(), Wait_4(infinity)
            end
    end(1).

%% Pingpong.ping
'$4'(Opponent_6, Round_7) ->
    case Round_7 =:= 0 of
        true -> ern_rt:send(Opponent_6, 'Stop');
        false ->
            ern@io:'$8'(<<"ping ",
                          (erlang:integer_to_binary(Round_7))/binary>>),
            case ern_rt:call(Opponent_6,
                             fun (Reply_8) -> {'Ping', Round_7, Reply_8} end,
                             5000,
                             {int, <<"reply does not match Int">>})
                of
                {'Some', _} -> '$4'(Opponent_6, Round_7 - 1);
                'None' ->
                    ern@io:'$8'(<<"pong is not answering">>),
                    ern_rt:send(Opponent_6, 'Stop')
            end
    end.

%% Pingpong.pong
'$5'() ->
    fun Wait_12(After_13) ->
            receive
                '$ern_restart' -> ern_rt:restart_now();
                {'$ern_fault', Fault_11} -> erlang:throw(Fault_11);
                {'Ping', Round_9, Reply_10} ->
                    ern@io:'$8'(<<"pong ",
                                  (erlang:integer_to_binary(Round_9))/binary>>),
                    ern_rt:answer(Reply_10, Round_9),
                    '$5'();
                'Stop' -> 'Unit'
                after After_13 -> ern_rt:collect(), Wait_12(infinity)
            end
    end(1).

'$spawned'('$3', []) -> '$3'();
'$spawned'('$5', []) -> '$5'().
