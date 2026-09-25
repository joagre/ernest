-module(ern@hello).

-export([main/0, '$fun'/2]).

main() -> ern@io:println(<<"hello, world">>).

'$fun'(main, 0) -> fun main/0.
