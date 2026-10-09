-module(ern@hello).

-dialyzer(no_return).

-export([main/0, '$spawned'/2]).

main() -> ern@io:println(<<"hello, world">>).

'$spawned'(main, []) -> main().
