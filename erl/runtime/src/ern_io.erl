%% The shims behind Io.show and Io.debug (report Appendix E.1): the value
%% is written by the descriptor of its type at the call, which the compiler
%% passes, and by the runtime's representation where the call has no type
%% to give. And Io.Error for a reason of the host's, which the system
%% modules answer, the one mapping of the host's errors to it.
-module(ern_io).

-export([show/1, show/2, debug/1, debug/2, host_error/2, helper_error/1, helper_reason/1, other/2]).

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

%% Report Appendix E.1: Io.Error for a reason of the host's, the constructor
%% that names it, or Other.
-spec host_error(term(), fun((atom()) -> string())) -> term().
host_error(enoent, _) -> 'NotFound';
host_error(eacces, _) -> 'Denied';
host_error(eperm, _) -> 'Denied';
host_error(econnrefused, _) -> 'Refused';
host_error(eexist, _) -> 'Exists';
%% an argument the host cannot take, a time it cannot hold among them, by
%% Erlang's word or the kernel's
host_error(badarg, _) -> 'Invalid';
host_error(einval, _) -> 'Invalid';
host_error(Error, Describe) -> other(Error, Describe).

%% Report Appendix E.1: Io.Error for an error the runtime's helper names,
%% by Erlang's name for it, described as the file module's errors are, and
%% by the host's own words where Erlang has no name. A name is one of the
%% helper's table (c_src/ern_exec.c, posix_name), which bounds the atoms
%% made of them; the host's words have a space or a capital.
-spec helper_error(binary()) -> term().
helper_error(Name) ->
    case helper_reason(Name) of
        Error when is_atom(Error) -> host_error(Error, fun file:format_error/1);
        Words -> {'Other', Words}
    end.

%% The reason an error the helper names stands for: Erlang's name for it,
%% or the host's own words where Erlang has none (above).
-spec helper_reason(binary()) -> atom() | binary().
helper_reason(Name) ->
    case is_posix_name(Name) of
        true -> binary_to_atom(Name);
        false -> Name
    end.

is_posix_name(<<$e, Rest/binary>>) when Rest =/= <<>> ->
    lists:all(fun(Char) -> (Char >= $a andalso Char =< $z) orelse (Char >= $0 andalso Char =< $9)
              end, binary_to_list(Rest));
is_posix_name(_) ->
    false.

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
