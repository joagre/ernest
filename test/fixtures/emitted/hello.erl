-module(ern@hello).

-dialyzer(no_return).

-export(['$1'/0, '$spawned'/2]).

%% Hello.main
'$1'() -> ern@io:'$8'(<<"hello, world">>).

'$spawned'('$1', []) -> '$1'().
