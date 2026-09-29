%% Report §8.6: the host's termination and hangup end the program as the
%% end of its entry process does, and the runtime prints nothing of its own
%% about them. A callback module of OTP's erl_signal_server, in place of
%% its default handler, which stops the node with status 0 on a
%% termination and ignores a hangup; not a process of the toolchain's own
%% (docs/style.md).
-module(ern_signals).
-behaviour(gen_event).

-export([install/0, status/1, ended/0, die/2, init/1, handle_event/2, handle_call/2]).

%% Handle the two signals here from now on (report §11). The launcher
%% installs this handler before its work, since the host's own handler
%% would stop the node only once that work had returned. A run installs it
%% again, which changes nothing where it is in place and matters where a
%% test runs the job. A termination the host's handler took as the host
%% started has asked the host to stop, which it would do only after the
%% work, so `ern` ends by that signal here, before this handler is asked:
%% the stopping host may have ended it. A hangup that came then the host's
%% handler ignored. A signal that came before the host could take signals
%% at all the host itself drops. The host's interrupt cannot be handled,
%% and ends the node at once (report §8.6).
-spec install() -> ok.
install() ->
    case init:get_status() of
        {stopping, _} -> die(sigterm, status(sigterm));
        _ -> ok
    end,
    case lists:member(?MODULE, gen_event:which_handlers(erl_signal_server)) of
        true ->
            ok;
        false ->
            ok = gen_event:swap_handler(erl_signal_server, {erl_signal_handler, []},
                                        {?MODULE, []}),
            ok = os:set_signal(sigterm, handle),
            ok = os:set_signal(sighup, handle),
            ok
    end.

%% Report §11.2: the status a signal ends `ern` with, 128 plus its number.
-spec status(sigterm | sighup) -> pos_integer().
status(sigterm) -> 128 + 15;
status(sighup) -> 128 + 1.

%% The signal that ended the run, or none.
-spec ended() -> sigterm | sighup | none.
ended() ->
    persistent_term:get({?MODULE, ended}, none).

%% Report §11.2: `ern` ends by the signal itself, once its output is
%% flushed, so that a service manager counts a stop it asked for as clean,
%% and a shell reports 128 plus its number either way. The signal's own
%% action is restored and the signal sent again; where that cannot be
%% done, the status stands in for it.
-spec die(sigterm | sighup, integer()) -> no_return().
die(Signal, Status) ->
    ok = os:set_signal(Signal, default),
    Name = case Signal of sigterm -> "TERM"; sighup -> "HUP" end,
    _ = os:cmd("kill -" ++ Name ++ " " ++ os:getpid()),
    timer:sleep(1000),
    erlang:halt(Status).

-spec init(term()) -> {ok, []}.
init(_) ->
    {ok, []}.

%% A run in progress ends as §8.6 says and its launcher returns the signal;
%% outside one there is nothing to end, and `ern` ends by it at once.
-spec handle_event(term(), []) -> {ok, []}.
handle_event(Signal, State) when Signal =:= sigterm; Signal =:= sighup ->
    persistent_term:put({?MODULE, ended}, Signal),
    case ern_rt:signal(Signal) of
        ok -> ok;
        none -> die(Signal, status(Signal))
    end,
    {ok, State};
handle_event(_, State) ->
    {ok, State}.

-spec handle_call(term(), []) -> {ok, ok, []}.
handle_call(_, State) ->
    {ok, ok, State}.
