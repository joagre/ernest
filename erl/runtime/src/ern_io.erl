%% The shims behind Io.show and Io.debug (report Appendix E.1): the value
%% is written by the descriptor of its type at the call, which the compiler
%% passes, and by the runtime's representation where the call has no type
%% to give. And Io.Error's Other for a reason of the host's, which the
%% system modules answer.
-module(ern_io).

-export([show/1, show/2, debug/1, debug/2, other/2]).

-spec show(term()) -> binary().
show(V) -> show(V, any).

-spec show(term(), term()) -> binary().
show(V, Desc) -> ern_show:show(Desc, V).

-spec debug(term()) -> term().
debug(V) -> debug(V, any).

-spec debug(term(), term()) -> term().
debug(V, Desc) ->
    Line = <<(show(V, Desc))/binary, "\n">>,
    %% report §8.2, Appendix E.1: to standard error, as Io.OutMsg's
    %% Write(bytes, reply), answered once written
    ern_rt:call_forever(ern_rt:sys(stderr), fun(Reply) -> {'Write', Line, Reply} end),
    V.

%% Report Appendix E.1: Io.Error's Other for a reason of the host's that no
%% constructor names. It is the host's description, which Describe, the
%% module's format_error, gives for a POSIX code, "address already in use";
%% and the reason as the host prints it where there is none.
-spec other(term(), fun((atom()) -> string())) -> {'Other', binary()}.
other(Reason, Describe) when is_atom(Reason) ->
    case Describe(Reason) of
        "unknown POSIX error" ++ _ -> printed(Reason);
        Text -> {'Other', unicode:characters_to_binary(Text)}
    end;
other(Reason, _) ->
    printed(Reason).

printed(Reason) ->
    {'Other', unicode:characters_to_binary(io_lib:format("~p", [Reason]))}.
