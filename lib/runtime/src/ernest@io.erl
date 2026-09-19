%% Appendix E.1, namespace Io, as an Erlang module for MVP 1 (implementation
%% plan, Phase 2.4). Strings are UTF-8 binaries (report §8.4).
-module('ernest@io').

-export([print/1, println/1, debug/1, debug/2]).

-spec print(binary()) -> 'Unit'.
print(S) -> ern_rt:send(ern_rt:sys(stdout), S).

-spec println(binary()) -> 'Unit'.
println(S) -> ern_rt:send(ern_rt:sys(stdout), <<S/binary, "\n">>).

%% Appendix E.1: the value as Ernest writes it, by the descriptor of its
%% type at the call, printed and returned; debug/1 is the value with no
%% type to go by.
-spec debug(term()) -> term().
debug(V) ->
    debug(V, any).

-spec debug(term(), term()) -> term().
debug(V, Desc) ->
    println(ern_show:show(Desc, V)),
    V.
