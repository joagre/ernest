%% The shim behind Io.debug (report Appendix E.1): the value is printed by
%% the descriptor of its type at the call, which the compiler passes, and
%% by the runtime's representation where the call has no type to give.
-module(ern_io).

-export([debug/1, debug/2]).

-spec debug(term()) -> term().
debug(V) -> debug(V, any).

-spec debug(term(), term()) -> term().
debug(V, Desc) ->
    Line = <<(ern_show:show(Desc, V))/binary, "\n">>,
    ern_rt:send(ern_rt:sys(stdout), Line),
    V.
