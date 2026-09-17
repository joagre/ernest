-module(ernest@kv_parser).

-export([main/0]).

main() ->
    ernest@list:foreach([<<"a=12">>,
                         <<"=1">>,
                         <<"a">>,
                         <<"a=x">>],
                        fun (S_1) -> ernest@io:println(show(parse(S_1))) end).

show(R_2) ->
    case R_2 of
        {'Right', {K_3, V_4}} ->
            <<K_3/binary, " ", (ernest@int:toString(V_4))/binary>>;
        {'Left', E_5} -> E_5
    end.

parse(S_6) ->
    case keyOf(ernest@string:chars(S_6)) of
        {'Left', E_13} -> {'Left', E_13};
        {'Right', {Key_7, Rest_8}} ->
            case expectEq(Rest_8, S_6) of
                {'Left', E_12} -> {'Left', E_12};
                {'Right', Rest2_9} ->
                    case number(Rest2_9, S_6) of
                        {'Left', E_11} -> {'Left', E_11};
                        {'Right', N_10} -> {'Right', {Key_7, N_10}}
                    end
            end
    end.

keyOf(Cs_14) ->
    {K_15, Rest_16} = ernest@list:span(Cs_14,
                                       fun ernest@char:isAlpha/1),
    case ernest@list:isEmpty(K_15) of
        true ->
            {'Left',
             <<"bad key: ",
               (ernest@string:fromChars(Cs_14))/binary>>};
        false ->
            {'Right', {ernest@string:fromChars(K_15), Rest_16}}
    end.

expectEq(Cs_17, S_18) ->
    case Cs_17 of
        [$= | Rest_19] -> {'Right', Rest_19};
        _ -> {'Left', <<"expected =: ", S_18/binary>>}
    end.

number(Cs_20, S_21) ->
    case ernest@string:toInt(ernest@string:fromChars(Cs_20))
        of
        {'Some', N_22} -> {'Right', N_22};
        'None' -> {'Left', <<"bad number: ", S_21/binary>>}
    end.
