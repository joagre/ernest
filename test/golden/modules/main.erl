-module(ern@main).

-dialyzer(no_return).

-export(['$1'/0, '$spawned'/2]).

%% Main.main
'$1'() ->
    case ern@net@http:'$2'(<<"GET /">>) of
        {'Some', {'Request', Method_1, Path_2}} ->
            ern@io:'$8'(<<Method_1/binary, " ", Path_2/binary>>);
        'None' -> ern@io:'$8'(<<"bad request">>)
    end.

'$spawned'('$1', []) -> '$1'().
