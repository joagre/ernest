%% The waits the tests share (ern_waits), each on what it means rather than
%% on a time.
-module(ern_waits_tests).

-include_lib("eunit/include/eunit.hrl").

%% CLAUDE.md, *No fixed sleep*: until/2 answers `ended` for a process that
%% ends while it waits, and for one that had ended before. A regression
%% test: the wait read only the trace of the process's scheduling, which
%% shows no end, and waited for ever; a process that had ended raised as
%% its trace was turned on
until_ended_test() ->
    Pid = spawn(fun() -> receive go -> ok end end),
    Self = self(),
    Waiter = spawn(fun() -> Self ! {until, ern_waits:until(Pid, fun() -> false end)} end),
    ok = ern_waits:waiting(Waiter),
    Pid ! go,
    ?assertEqual({until, ended}, receive {until, _} = Answer -> Answer end),
    ?assertEqual(ended, ern_waits:until(Pid, fun() -> true end)).
