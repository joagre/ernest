-module(ernest@remote).

-export([main/0]).

heavy(A_1, B_2) -> A_1 * A_1 + B_2 * B_2.

main() ->
    case ern_rt:remote(fun () -> heavy(3, 4) end) of
        {'Right', N_3} ->
            ernest@io:println(<<"remote returned ",
                                (ernest@int:toString(N_3))/binary>>);
        {'Left', 'NoRemotePeer'} ->
            ernest@io:println(<<"no remote peer configured">>);
        {'Left', 'PeerLost'} ->
            ernest@io:println(<<"peer lost or callback failed">>)
    end.
