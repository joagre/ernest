-module(ern@patterns).

-dialyzer(no_return).

-export(['$3'/0, '$spawned'/2]).

%% Patterns.main
'$3'() ->
    ern@io:'$8'('$4'(-1)),
    ern@io:'$8'('$4'(0)),
    ern@io:'$8'('$4'(7)),
    ern@io:'$8'('$5'({'Some', {'Snapshot', <<"a">>, 2}})),
    ern@io:'$8'('$5'('None')),
    ern@io:'$8'(ern@int:'$24'('$7'(3))),
    ern@io:'$8'(ern@int:'$24'(ern@list:'$38'('$9'([1,
                                                   2,
                                                   3])))),
    ern@io:'$8'(ern@int:'$24'('$8'({'Square', 4}))).

%% Patterns.sign
'$4'(Number_1) ->
    case Number_1 of
        -1 -> <<"minus one">>;
        0 -> <<"zero">>;
        _ -> <<"other">>
    end.

%% Patterns.describe
'$5'(Found_2) ->
    case Found_2 of
        {'Some', Snapshot_4 = {'Snapshot', Directory_3, _}} ->
            <<Directory_3/binary, " ",
              (ern@int:'$24'('$6'(Snapshot_4)))/binary>>;
        'None' -> <<"nothing">>
    end.

%% Patterns.seen
'$6'({'Snapshot', _, Count_5}) -> Count_5.

%% Patterns.negate
'$7'(Number_6) -> -Number_6.

%% Patterns.side
'$8'(Shape_7) ->
    begin
        Body_8 = fun (Size_9) -> Size_9 end,
        case Shape_7 of
            {'Circle', Size_10} -> Body_8(Size_10);
            {'Square', Size_11} -> Body_8(Size_11);
            'Dot' -> 0
        end
    end.

%% Patterns.whole
'$9'(List_12) ->
    case List_12 of
        All_15 = [First_13 | Rest_14] -> All_15;
        [] -> []
    end.

'$spawned'('$3', []) -> '$3'().
