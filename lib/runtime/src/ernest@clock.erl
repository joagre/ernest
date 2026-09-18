%% Appendix E.15, namespace Clock, as an Erlang module for MVP 1: Sys.clock
%% spoken through the runtime. alarm and alarmAt deliver Wrap('Unit') to the
%% caller through a via proxy (report §6.5); now waits without a limit, as the
%% clock always answers.
-module('ernest@clock').

-export([now/0, alarm/2, alarmAt/2]).

-spec now() -> integer().
now() -> ern_rt:call_forever(ern_rt:sys(clock), fun(R) -> {'Now', R} end).

-spec alarm(integer(), fun(('Unit') -> term())) -> 'Unit'.
alarm(Ms, Wrap) -> ern_rt:send(ern_rt:sys(clock), {'After', Ms, ern_rt:via(Wrap, self())}).

-spec alarmAt(integer(), fun(('Unit') -> term())) -> 'Unit'.
alarmAt(At, Wrap) -> ern_rt:send(ern_rt:sys(clock), {'At', At, ern_rt:via(Wrap, self())}).
