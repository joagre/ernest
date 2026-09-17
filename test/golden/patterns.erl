-module(ernest@patterns).

-export([main/0]).

main() ->
    ernest@io:println(sign(-1)),
    ernest@io:println(sign(0)),
    ernest@io:println(sign(7)),
    ernest@io:println(describe({'Some',
                                {'Snapshot', <<"a">>, 2}})),
    ernest@io:println(describe('None')),
    ernest@io:println(ernest@int:toString(negate(3))),
    ernest@io:println(ernest@int:toString(ernest@list:size(whole([1,
                                                                  2,
                                                                  3])))).

sign(N_1) ->
    case N_1 of
        -1 -> <<"minus one">>;
        0 -> <<"zero">>;
        _ -> <<"other">>
    end.

describe(O_2) ->
    case O_2 of
        {'Some', Snap_4 = {'Snapshot', D_3, _}} ->
            <<D_3/binary, " ",
              (ernest@int:toString(seen(Snap_4)))/binary>>;
        'None' -> <<"nothing">>
    end.

seen({'Snapshot', _, N_5}) -> N_5.

negate(N_6) -> -N_6.

whole(Xs_7) ->
    case Xs_7 of
        All_10 = [X_8 | Rest_9] -> All_10;
        [] -> []
    end.
