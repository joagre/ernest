-module(ernest@remote).

-export([main/0]).

main() ->
    case ern_rt:remote(fun () -> heavy(3, 4) end) of
        {'Right', N_1} ->
            ernest@io:println(<<"remote returned ",
                                (ernest@int:toString(N_1))/binary>>);
        {'Left', 'NoRemotePeer'} ->
            ernest@io:println(<<"no remote peer configured">>);
        {'Left', 'PeerLost'} ->
            ernest@io:println(<<"peer lost or callback failed">>)
    end.

heavy(A_2, B_3) -> A_2 * A_2 + B_3 * B_3.
