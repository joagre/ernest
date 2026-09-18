%% Appendix E.1, namespace Io, as an Erlang module for MVP 1 (implementation
%% plan, Phase 2.4). Strings are UTF-8 binaries (report §8.4).
-module('ernest@io').

-export([print/1, println/1, printTo/2, printlnTo/2]).

-spec print(binary()) -> 'Unit'.
print(S) -> ern_rt:send(ern_rt:sys(stdout), S).

-spec println(binary()) -> 'Unit'.
println(S) -> ern_rt:send(ern_rt:sys(stdout), <<S/binary, "\n">>).

-spec printTo(binary(), pid()) -> 'Unit'.
printTo(S, A) -> ern_rt:send(A, S).

-spec printlnTo(binary(), pid()) -> 'Unit'.
printlnTo(S, A) -> ern_rt:send(A, <<S/binary, "\n">>).
