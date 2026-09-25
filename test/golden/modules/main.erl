-module(ern@main).

-export([main/0, '$fun'/2]).

main() ->
    case ern@net@http:parse(<<"GET /">>) of
        {'Some', {'Request', Method_1, Path_2}} ->
            ern@io:println(<<Method_1/binary, " ", Path_2/binary>>);
        'None' -> ern@io:println(<<"bad request">>)
    end.

'$fun'(main, 0) -> fun main/0.
