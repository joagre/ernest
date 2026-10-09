-module(ern@net@http).

-dialyzer(no_return).

-export([parse/1]).

parse(Text_1) ->
    case Text_1 =:= <<"GET /">> of
        true -> {'Some', {'Request', <<"GET">>, <<"/">>}};
        false -> 'None'
    end.
