-module(ern@net@http).

-export([parse/1, '$fun'/2]).

parse(S_1) ->
    case S_1 =:= <<"GET /">> of
        true -> {'Some', {'Request', <<"GET">>, <<"/">>}};
        false -> 'None'
    end.

'$fun'(parse, 1) -> fun parse/1.
