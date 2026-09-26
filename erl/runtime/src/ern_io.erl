%% The shims behind Io.show and Io.debug (report Appendix E.1): the value
%% is written by the descriptor of its type at the call, which the compiler
%% passes, and by the runtime's representation where the call has no type
%% to give.
-module(ern_io).

-export([show/1, show/2, debug/1, debug/2]).

-spec show(term()) -> binary().
show(V) -> show(V, any).

-spec show(term(), term()) -> binary().
show(V, Desc) -> ern_show:show(Desc, V).

-spec debug(term()) -> term().
debug(V) -> debug(V, any).

-spec debug(term(), term()) -> term().
debug(V, Desc) ->
    Line = <<(show(V, Desc))/binary, "\n">>,
    ern_rt:send(ern_rt:sys(stdout), Line),
    V.
