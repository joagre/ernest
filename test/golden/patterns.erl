-module(ern@patterns).

-dialyzer(no_return).

-export([main/0, '$fun'/2]).

main() ->
    ern@io:println(sign(-1)),
    ern@io:println(sign(0)),
    ern@io:println(sign(7)),
    ern@io:println(describe({'Some',
                             {'Snapshot', <<"a">>, 2}})),
    ern@io:println(describe('None')),
    ern@io:println(ern@int:toString(negate(3))),
    ern@io:println(ern@int:toString(ern@list:size(whole([1,
                                                         2,
                                                         3])))),
    ern@io:println(ern@int:toString(side({'Square', 4}))).

sign(Number_1) ->
    case Number_1 of
        -1 -> <<"minus one">>;
        0 -> <<"zero">>;
        _ -> <<"other">>
    end.

describe(Found_2) ->
    case Found_2 of
        {'Some', Snapshot_4 = {'Snapshot', Directory_3, _}} ->
            <<Directory_3/binary, " ",
              (ern@int:toString(seen(Snapshot_4)))/binary>>;
        'None' -> <<"nothing">>
    end.

seen({'Snapshot', _, Count_5}) -> Count_5.

negate(Number_6) -> -Number_6.

side(Shape_7) ->
    begin
        Body_8 = fun (Size_9) -> Size_9 end,
        case Shape_7 of
            {'Circle', Size_10} -> Body_8(Size_10);
            {'Square', Size_11} -> Body_8(Size_11);
            'Dot' -> 0
        end
    end.

whole(List_12) ->
    case List_12 of
        All_15 = [First_13 | Rest_14] -> All_15;
        [] -> []
    end.

'$fun'(main, 0) -> fun main/0.
