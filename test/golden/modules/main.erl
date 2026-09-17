-module(ernest@main).

-export([main/0]).

main() ->
    case ernest@net@http:parse(<<"GET /">>) of
        {'Some', {'Request', Method_1, Path_2}} ->
            ernest@io:println(<<Method_1/binary, " ",
                                Path_2/binary>>);
        'None' -> ernest@io:println(<<"bad request">>)
    end.
