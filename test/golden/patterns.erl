-module(ern@patterns).

-export([main/0]).

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
              (ern@int:toString(seen(Snap_4)))/binary>>;
        'None' -> <<"nothing">>
    end.

seen({'Snapshot', _, N_5}) -> N_5.

negate(N_6) -> -N_6.

side(S_7) ->
    begin
        Body_8 = fun (N_9) -> N_9 end,
        case S_7 of
            {'Circle', N_10} -> Body_8(N_10);
            {'Square', N_11} -> Body_8(N_11);
            'Dot' -> 0
        end
    end.

whole(Xs_12) ->
    case Xs_12 of
        All_15 = [X_13 | Rest_14] -> All_15;
        [] -> []
    end.
