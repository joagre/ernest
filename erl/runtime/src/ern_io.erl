%% The shims behind Io.show and Io.debug (report Appendix E.1): the value
%% is written by the descriptor of its type at the call, which the compiler
%% passes, and by the runtime's representation where the call has no type
%% to give. And Io.Error's Other for a reason of the host's, which the
%% system modules answer.
-module(ern_io).

-export([show/1, show/2, debug/1, debug/2, other/2]).

-spec show(term()) -> binary().
show(Value) -> show(Value, any).

-spec show(term(), ern_descriptor:descriptor()) -> binary().
show(Value, Descriptor) -> ern_show:show(Descriptor, Value).

-spec debug(term()) -> term().
debug(Value) -> debug(Value, any).

-spec debug(term(), ern_descriptor:descriptor()) -> term().
debug(Value, Descriptor) ->
    Line = <<(show(Value, Descriptor))/binary, "\n">>,
    %% report §8.2, Appendix E.1: to standard error, as Io.OutMsg's
    %% Write(bytes, reply), answered once written
    ern_rt:call_forever(ern_rt:system_process(stderr), fun(Reply) -> {'Write', Line, Reply} end),
    Value.

%% Report Appendix E.1: Io.Error's Other for a reason of the host's that no
%% constructor names. It is the host's description, which Describe, the
%% module's format_error, gives for a POSIX code, "address already in use";
%% and the reason as the host prints it where there is none.
-spec other(term(), fun((atom()) -> string())) -> {'Other', binary()}.
other(Error, Describe) when is_atom(Error) ->
    case Describe(Error) of
        "unknown POSIX error" ++ _ -> printed(Error);
        Text -> {'Other', unicode:characters_to_binary(Text)}
    end;
other(Error, _) ->
    printed(Error).

printed(Error) ->
    {'Other', unicode:characters_to_binary(io_lib:format("~p", [Error]))}.
