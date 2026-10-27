-module(ern@kv_parser).

-dialyzer(no_return).

-export(['$1'/0, '$spawned'/2]).

%% Kv_parser.main
'$1'() ->
    ern@list:'$13'([<<"a=12">>,
                    <<"=1">>,
                    <<"a">>,
                    <<"a=x">>],
                   fun (Line_1) -> ern@io:'$8'('$2'('$3'(Line_1))) end).

%% Kv_parser.show
'$2'(Parsed_2) ->
    case Parsed_2 of
        {'Right', {Key_3, Value_4}} ->
            <<Key_3/binary, " ",
              (erlang:integer_to_binary(Value_4))/binary>>;
        {'Left', Error_5} -> Error_5
    end.

%% Kv_parser.parse
'$3'(Line_6) ->
    case '$4'(try ern_string:to_list(Line_6) catch
                  Class_7:Error_8:Trace_9 ->
                      ern_boundary:raised(ern_string,
                                          to_list,
                                          1,
                                          Class_7,
                                          Error_8,
                                          Trace_9)
              end)
        of
        {'Left', Left_10} -> {'Left', Left_10};
        {'Right', {Key_11, Rest_12}} ->
            case '$5'(Rest_12, Line_6) of
                {'Left', Left_13} -> {'Left', Left_13};
                {'Right', AfterEquals_14} ->
                    case '$6'(AfterEquals_14, Line_6) of
                        {'Left', Left_15} -> {'Left', Left_15};
                        {'Right', Value_16} -> {'Right', {Key_11, Value_16}}
                    end
            end
    end.

%% Kv_parser.keyOf
'$4'(Chars_17) ->
    {Letters_18, Rest_19} = ern@list:'$22'(Chars_17,
                                           fun ern@char:'$7'/1),
    case not ern@list:'$3'(Letters_18) of
        true ->
            {'Right',
             {try ern_string:from_list(Letters_18) catch
                  Class_20:Error_21:Trace_22 ->
                      ern_boundary:raised(ern_string,
                                          from_list,
                                          1,
                                          Class_20,
                                          Error_21,
                                          Trace_22)
              end,
              Rest_19}};
        false ->
            {'Left',
             <<"bad key: ",
               try ern_string:from_list(Chars_17) catch
                   Class_23:Error_24:Trace_25 ->
                       ern_boundary:raised(ern_string,
                                           from_list,
                                           1,
                                           Class_23,
                                           Error_24,
                                           Trace_25)
               end/binary>>}
    end.

%% Kv_parser.expectEquals
'$5'(Chars_26, Line_27) ->
    case Chars_26 of
        [$= | Rest_28] -> {'Right', Rest_28};
        _ -> {'Left', <<"expected =: ", Line_27/binary>>}
    end.

%% Kv_parser.number
'$6'(Chars_29, Line_30) ->
    case ern@string:'$25'(try ern_string:from_list(Chars_29)
                          catch
                              Class_31:Error_32:Trace_33 ->
                                  ern_boundary:raised(ern_string,
                                                      from_list,
                                                      1,
                                                      Class_31,
                                                      Error_32,
                                                      Trace_33)
                          end)
        of
        {'Some', Value_34} -> {'Right', Value_34};
        'None' -> {'Left', <<"bad number: ", Line_30/binary>>}
    end.

'$spawned'('$1', []) -> '$1'().
