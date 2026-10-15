-module(ern@net@http).

-dialyzer(no_return).

-export(['$2'/1]).

%% Net.Http.parse
'$2'(Text_1) ->
    case Text_1 =:= <<"GET /">> of
        true -> {'Some', {'Request', <<"GET">>, <<"/">>}};
        false -> 'None'
    end.
