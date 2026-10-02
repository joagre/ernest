-module(ern@kv_parser).

-export([main/0, '$fun'/2]).

main() ->
    ern@list:foreach([<<"a=12">>,
                      <<"=1">>,
                      <<"a">>,
                      <<"a=x">>],
                     fun (Line_1) -> ern@io:println(show(parse(Line_1)))
                     end).

show(Parsed_2) ->
    case Parsed_2 of
        {'Right', {Key_3, Value_4}} ->
            <<Key_3/binary, " ",
              (ern@int:toString(Value_4))/binary>>;
        {'Left', Error_5} -> Error_5
    end.

parse(Line_6) ->
    case keyOf(ern@string:toList(Line_6)) of
        {'Left', E_13} -> {'Left', E_13};
        {'Right', {Key_7, Rest_8}} ->
            case expectEquals(Rest_8, Line_6) of
                {'Left', E_12} -> {'Left', E_12};
                {'Right', AfterEquals_9} ->
                    case number(AfterEquals_9, Line_6) of
                        {'Left', E_11} -> {'Left', E_11};
                        {'Right', Value_10} -> {'Right', {Key_7, Value_10}}
                    end
            end
    end.

keyOf(Chars_14) ->
    {Letters_15, Rest_16} = ern@list:span(Chars_14,
                                          ern@char:'$fun'(isAlpha, 1)),
    case not ern@list:isEmpty(Letters_15) of
        true ->
            {'Right', {ern@string:fromList(Letters_15), Rest_16}};
        false ->
            {'Left',
             <<"bad key: ", (ern@string:fromList(Chars_14))/binary>>}
    end.

expectEquals(Chars_17, Line_18) ->
    case Chars_17 of
        [$= | Rest_19] -> {'Right', Rest_19};
        _ -> {'Left', <<"expected =: ", Line_18/binary>>}
    end.

number(Chars_20, Line_21) ->
    case ern@string:toInt(ern@string:fromList(Chars_20)) of
        {'Some', Value_22} -> {'Right', Value_22};
        'None' -> {'Left', <<"bad number: ", Line_21/binary>>}
    end.

'$fun'(main, 0) -> fun main/0.
