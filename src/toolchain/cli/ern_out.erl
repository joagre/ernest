%% Report §11: the standard output and standard error of a job that writes
%% text, through ports on the process's own descriptors rather than the
%% host's user process, which halts the host with a crash dump once a
%% stream's reader has gone or its terminal has. `ern run` and `ern test`
%% write a program's output through the runtime, which learns the same of
%% its own streams (report §12.1); `ern shell` writes its screen here, and
%% takes the bytes a program writes as they are.
%%
%% Report §11.8: a stream is what it was as the job started, read here as
%% the job takes its streams, since a terminal that has hung up no longer
%% answers that it is one.
-module(ern_out).

-export([take/0, is_terminal/1, finish/1]).

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({own_process, [finish/1, loop/3, dropping/2]}).

%% Standard output becomes the calling process's group leader, which the
%% processes it starts inherit; the answer is standard error's device. Which
%% of the two is a terminal is read first, and kept for the job's life, a
%% persistent term put once.
-spec take() -> pid().
take() ->
    persistent_term:put({?MODULE, terminals},
                        [Stream || Stream <- [stdout, stderr], ern_tty:is_terminal(Stream)]),
    group_leader(device(stdout), self()),
    device(stderr).

%% Report §11.8: whether the stream was a terminal as the job started; no
%% stream was where the job took none, as a test of a job does not.
-spec is_terminal(stdout | stderr) -> boolean().
is_terminal(Stream) ->
    lists:member(Stream, persistent_term:get({?MODULE, terminals}, [])).

%% The job's streams written out before `ern` ends, standard output's and
%% the device given; where one can no longer be written, `ern` ends there.
-spec finish(pid() | atom()) -> ok.
finish(ErrorDevice) when is_pid(ErrorDevice) ->
    lists:foreach(fun(Device) ->
                      MonitorRef = erlang:monitor(process, Device),
                      Device ! {finish, self(), MonitorRef},
                      receive
                          {MonitorRef, finished} -> erlang:demonitor(MonitorRef, [flush]);
                          {'DOWN', MonitorRef, process, _, _} -> ok
                      end
                  end, [group_leader(), ErrorDevice]);
finish(_) ->
    ok.

%% A device writes text as UTF-8, and bytes as they are once the runtime
%% has set its encoding to latin1 (ern_rt's bytes_out/0). Its port is busy
%% while it holds a byte it has not written, its limits one byte, and the
%% host holds a writer to a busy port until it is not, as the runtime's
%% stream's port (ern_rt:stream/2).
device(Stream) ->
    Fd = case Stream of
             stdout -> 1;
             stderr -> 2
         end,
    spawn(fun() ->
              process_flag(trap_exit, true),
              loop(erlang:open_port({fd, 0, Fd}, [out, binary, {busy_limits_port, {1, 1}}]),
                   unicode, Stream)
          end).

loop(Port, Encoding, Stream) ->
    receive
        {io_request, From, ReplyAs, {setopts, Options}} ->
            From ! {io_reply, ReplyAs, ok},
            loop(Port, proplists:get_value(encoding, Options, Encoding), Stream);
        {io_request, From, ReplyAs, Request} ->
            case request(Port, Encoding, Request) of
                gone ->
                    told(Stream),
                    From ! {io_reply, ReplyAs, ok},
                    dropping(Encoding, Stream);
                Reply ->
                    From ! {io_reply, ReplyAs, Reply},
                    loop(Port, Encoding, Stream)
            end;
        {finish, From, Ref} ->
            case drained(Port) of
                ok ->
                    From ! {Ref, finished},
                    loop(Port, Encoding, Stream);
                gone ->
                    end_job(Stream)
            end;
        {'EXIT', Port, _} ->
            told(Stream),
            dropping(Encoding, Stream)
    end.

%% Waits until what the port was given is written, or the stream has gone:
%% a write of nothing returns once the port is not busy, which it is while
%% it holds anything (device/1), and fails where the port has ended.
drained(Port) ->
    write(Port, <<>>).

%% The requests io:format and io:put_chars make, and gone where the stream
%% could not take what a request wrote; nothing reads from here.
request(Port, Encoding, {put_chars, Given, Chars}) ->
    case unicode:characters_to_binary(Chars, Given, Encoding) of
        Bytes when is_binary(Bytes) -> write(Port, Bytes);
        _ -> {error, no_translation}
    end;
request(Port, Encoding, {put_chars, Given, Module, Function, Arguments}) ->
    request(Port, Encoding, {put_chars, Given, apply(Module, Function, Arguments)});
request(Port, Encoding, {requests, Requests}) ->
    lists:foldl(fun(Request, ok) -> request(Port, Encoding, Request);
                   (_, Error) -> Error
                end, ok, Requests);
request(_, Encoding, getopts) ->
    [{binary, false}, {encoding, Encoding}];
request(_, _, _) ->
    {error, enotsup}.

write(Port, Bytes) ->
    try erlang:port_command(Port, Bytes) of
        true -> ok
    catch
        error:badarg -> gone
    end.

%% Report §12.1, §8.6: the stream can no longer be written. A run in
%% progress is told, and ends as a stream of its own that has gone ends it
%% (ern_rt:stream_gone/1); outside a run the job ends at once, and the
%% writer is not answered.
told(Stream) ->
    case ern_rt:stream_gone(Stream) of
        ok -> ok;
        none -> end_job(Stream)
    end.

%% Report §8.6: what is written to a stream that has gone is dropped, so
%% that no writer waits or faults for a stream that ended, and the job's
%% end finds it gone, which ends the job by it in place of what ended it.
dropping(Encoding, Stream) ->
    receive
        {io_request, From, ReplyAs, {setopts, Options}} ->
            From ! {io_reply, ReplyAs, ok},
            dropping(proplists:get_value(encoding, Options, Encoding), Stream);
        {io_request, From, ReplyAs, getopts} ->
            From ! {io_reply, ReplyAs, request(none, Encoding, getopts)},
            dropping(Encoding, Stream);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, ok},
            dropping(Encoding, Stream);
        {finish, _, _} ->
            end_job(Stream);
        _ ->
            dropping(Encoding, Stream)
    end.

%% Report §11.8: the job ends at once and says nothing, by the hangup's
%% signal where the stream was a terminal as the job started, as keys that
%% can no longer be read end it, and otherwise with the status 141 that
%% shells give a process a closed pipe ended.
-spec end_job(stdout | stderr) -> no_return().
end_job(Stream) ->
    case is_terminal(Stream) of
        true -> ern_signals:die(sighup, ern_signals:status(sighup));
        false -> erlang:halt(141)
    end.
