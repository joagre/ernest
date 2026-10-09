-module(ern@kv_parser).

-dialyzer(no_return).

-export([main/0, '$fun'/2, '$spawned'/2]).

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
        {'Left', Left_7} -> {'Left', Left_7};
        {'Right', {Key_8, Rest_9}} ->
            case expectEquals(Rest_9, Line_6) of
                {'Left', Left_10} -> {'Left', Left_10};
                {'Right', AfterEquals_11} ->
                    case number(AfterEquals_11, Line_6) of
                        {'Left', Left_12} -> {'Left', Left_12};
                        {'Right', Value_13} -> {'Right', {Key_8, Value_13}}
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

'$spawned'(main, []) -> main().
