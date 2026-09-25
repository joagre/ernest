%% Report §8.2: a resize is news to the terminal's subscribers. The host
%% delivers SIGWINCH to OTP's signal server, which calls this handler; it
%% forwards the signal to the terminal's process as a message and runs no
%% loop of its own, as OTP's prim_tty_sighandler does (docs/style.md).
-module(ern_tty_signal).

-behaviour(gen_event).

-export([init/1, handle_event/2, handle_call/2]).

-spec init(pid()) -> {ok, pid()}.
init(Tty) ->
    ok = os:set_signal(sigwinch, handle),
    {ok, Tty}.

-spec handle_event(atom(), pid()) -> {ok, pid()}.
handle_event(sigwinch, Tty) ->
    Tty ! resized,
    {ok, Tty};
handle_event(_Signal, Tty) ->
    {ok, Tty}.

-spec handle_call(term(), pid()) -> {ok, ok, pid()}.
handle_call(_Request, Tty) ->
    {ok, ok, Tty}.
