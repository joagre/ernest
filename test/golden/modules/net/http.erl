-module(ernest@net@http).

-export([parse/1]).

parse(S_1) ->
    case S_1 =:= <<"GET /">> of
        true -> {'Some', {'Request', <<"GET">>, <<"/">>}};
        false -> 'None'
    end.
