-module(ern@kv_parser).

-dialyzer(no_return).

-export(['$1'/0, '$spawned'/2]).

%% Kv_parser.main
'$1'() ->
    ern@list:'$11'([<<"a=12">>,
                    <<"=1">>,
                    <<"a">>,
                    <<"a=x">>],
                   fun (Line_1) -> ern@io:'$8'('$2'('$3'(Line_1))) end).

%% Kv_parser.show
'$2'(Parsed_2) ->
    case Parsed_2 of
        {'Right', {Key_3, Value_4}} ->
            <<Key_3/binary, " ", (ern@int:'$24'(Value_4))/binary>>;
        {'Left', Error_5} -> Error_5
    end.

%% Kv_parser.parse
'$3'(Line_6) ->
    case '$4'(ern@string:'$42'(Line_6)) of
        {'Left', Left_7} -> {'Left', Left_7};
        {'Right', {Key_8, Rest_9}} ->
            case '$5'(Rest_9, Line_6) of
                {'Left', Left_10} -> {'Left', Left_10};
                {'Right', AfterEquals_11} ->
                    case '$6'(AfterEquals_11, Line_6) of
                        {'Left', Left_12} -> {'Left', Left_12};
                        {'Right', Value_13} -> {'Right', {Key_8, Value_13}}
                    end
            end
    end.

%% Kv_parser.keyOf
'$4'(Chars_14) ->
    {Letters_15, Rest_16} = ern@list:'$20'(Chars_14,
                                           fun ern@char:'$7'/1),
    case not ern@list:'$2'(Letters_15) of
        true ->
            {'Right', {ern@string:'$43'(Letters_15), Rest_16}};
        false ->
            {'Left',
             <<"bad key: ", (ern@string:'$43'(Chars_14))/binary>>}
    end.

%% Kv_parser.expectEquals
'$5'(Chars_17, Line_18) ->
    case Chars_17 of
        [$= | Rest_19] -> {'Right', Rest_19};
        _ -> {'Left', <<"expected =: ", Line_18/binary>>}
    end.

%% Kv_parser.number
'$6'(Chars_20, Line_21) ->
    case ern@string:'$24'(ern@string:'$43'(Chars_20)) of
        {'Some', Value_22} -> {'Right', Value_22};
        'None' -> {'Left', <<"bad number: ", Line_21/binary>>}
    end.

'$spawned'('$1', []) -> '$1'().
