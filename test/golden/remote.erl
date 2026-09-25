-module(ern@remote).

-export([main/0, '$fun'/2]).

main() ->
    case ern_rt:remote(fun () -> heavy(3, 4) end) of
        {'Right', N_1} ->
            ern@io:println(<<"remote returned ",
                             (ern@int:toString(N_1))/binary>>);
        {'Left', 'NoRemotePeer'} ->
            ern@io:println(<<"no remote peer configured">>);
        {'Left', 'PeerLost'} -> ern@io:println(<<"peer lost">>)
    end.

heavy(A_2, B_3) -> A_2 * A_2 + B_3 * B_3.

'$fun'(main, 0) -> fun main/0.
