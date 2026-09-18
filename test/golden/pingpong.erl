-module(ernest@pingpong).

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
    receive
        {'PongDone', _} = M_3 ->
            ern_check:value('$type_1'(),
                            M_3,
                            <<"message does not match MainMsg">>),
            'Unit'
    end.

ping(PongAddr_4, N_5) ->
    case N_5 =:= 0 of
        true -> ern_rt:send(PongAddr_4, 'Stop');
        false ->
            ernest@io:println(<<"ping ",
                                (ernest@int:toString(N_5))/binary>>),
            case ern_check:value('$type_2'(),
                                 ern_rt:call(PongAddr_4,
                                             fun (R_6) -> {'Ping', N_5, R_6}
                                             end,
                                             5000),
                                 <<"reply does not match Optional(Int)">>)
                of
                {'Some', _} -> ping(PongAddr_4, N_5 - 1);
                'None' ->
                    ernest@io:println(<<"pong is not answering">>),
                    ern_rt:send(PongAddr_4, 'Stop')
            end
    end.

pong() ->
    receive
        {'Ping', N_7, R_8} = M_9 ->
            ern_check:value('$type_3'(),
                            M_9,
                            <<"message does not match PongMsg">>),
            ernest@io:println(<<"pong ",
                                (ernest@int:toString(N_7))/binary>>),
            ern_rt:answer(R_8, N_7),
            pong();
        'Stop' = M_10 ->
            ern_check:value('$type_3'(),
                            M_10,
                            <<"message does not match PongMsg">>),
            'Unit'
    end.

'$type_1'() ->
    {con,
     [{'PongDone',
       [{con,
         [{'Down',
           [string,
            {con,
             [{'Returned', []},
              {'Killed', []},
              {'ProgramEnd', []},
              {'Fault', [string]}]}]}]}]}]}.

'$type_2'() -> {con, [{'None', []}, {'Some', [int]}]}.

'$type_3'() ->
    {con, [{'Ping', [int, ref]}, {'Stop', []}]}.
