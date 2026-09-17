%% Appendix E.1, namespace Io, as an Erlang module for MVP 1 (implementation
%% plan, Phase 2.4). Strings are UTF-8 binaries (report §8.4). Compiled from
%% forms, so the file need not be named after the atom.
-module('Ernest.Io').

-export([print/1, println/1, printTo/2, printlnTo/2]).

-spec print(binary()) -> 'Unit'.
print(S) -> ern_rt:send(ern_rt:sys(stdout), S).

-spec println(binary()) -> 'Unit'.
println(S) -> ern_rt:send(ern_rt:sys(stdout), <<S/binary, "\n">>).

-spec printTo(pid(), binary()) -> 'Unit'.
printTo(A, S) -> ern_rt:send(A, S).

-spec printlnTo(pid(), binary()) -> 'Unit'.
printlnTo(A, S) -> ern_rt:send(A, <<S/binary, "\n">>).
