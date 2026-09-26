%% Report §8.6: the host's termination and hangup end the program as the
%% end of its entry process does, and the runtime prints nothing of its own
%% about them. A callback module of OTP's erl_signal_server, in place of
%% its default handler, which stops the node with status 0 on a
%% termination and ignores a hangup; not a process of the toolchain's own
%% (docs/style.md).
-module(ern_signals).
-behaviour(gen_event).

-export([install/0, status/1, init/1, handle_event/2, handle_call/2, handle_info/2]).

%% Handle the two signals here from now on. The host's interrupt cannot be
%% handled; it ends the node at once (report §8.6).
-spec install() -> ok.
install() ->
    ok = gen_event:swap_handler(erl_signal_server, {erl_signal_handler, []}, {?MODULE, []}),
    ok = os:set_signal(sigterm, handle),
    ok = os:set_signal(sighup, handle),
    ok.

%% Report §11.2: the status a signal ends `ern` with, 128 plus its number.
-spec status(sigterm | sighup) -> pos_integer().
status(sigterm) -> 128 + 15;
status(sighup) -> 128 + 1.

init(_) ->
    {ok, []}.

%% A run in progress ends as §8.6 says and its launcher returns the signal;
%% outside one there is nothing to end.
handle_event(Signal, State) when Signal =:= sigterm; Signal =:= sighup ->
    case ern_rt:signal(Signal) of
        ok -> ok;
        none -> erlang:halt(status(Signal))
    end,
    {ok, State};
handle_event(_, State) ->
    {ok, State}.

handle_call(_, State) ->
    {ok, ok, State}.

handle_info(_, State) ->
    {ok, State}.
