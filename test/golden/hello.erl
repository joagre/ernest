-module(ern@hello).

-dialyzer(no_return).

-export([main/0, '$fun'/2, '$spawned'/2]).

main() -> ern@io:println(<<"hello, world">>).

'$fun'(main, 0) -> fun main/0.

'$spawned'(main, []) -> main().
