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
%%
%% Report §11: the module is the job's log handler in the host's place, by
%% which what the host logs as a warning or worse goes the way the job's
%% own lines go (log/2).
-module(ern_out).

-export([take/0, logged/0, log/2, is_terminal/1, finish/1]).

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({own_process, [finish/1, loop/2, dropping/1]}).

%% Standard output becomes the calling process's group leader, which the
%% processes it starts inherit; the answer is standard error's device. Which
%% of the two is a terminal is read first, and kept for the job's life, a
%% persistent term put once. The host's log handler becomes the job's own
%% (logged/0).
-spec take() -> pid().
take() ->
    persistent_term:put({?MODULE, terminals},
                        [Stream || Stream <- [stdout, stderr], ern_tty:is_terminal(Stream)]),
    group_leader(device(stdout), self()),
    ok = logged(),
    device(stderr).

%% Report §11, §11.2: what the host logs as a warning or worse the job
%% writes on standard error as the host formats it. This module takes the
%% place of the host's default log handler, under its name and with its
%% formatter, and stands at warning; an event logged between the host's
%% removal and its own start, as the job starts, is not written. The
%% process the handler says each event through is started first, while
%% the job has room for it (log/2). The launcher's first start takes the
%% handler too, so that nothing the host logs reaches the standard output
%% that carries the flags alone (ern_cli:node_flags/0).
%%
%% Of the host's filters the handler keeps one, which stops here an event
%% of a process whose group leader is on another node: the host sends the
%% event to that node, which writes it. The host's others drop an event
%% logged under a domain other than the host's own, and so would drop a
%% warning a library logs under a domain of its own.
-spec logged() -> ok.
logged() ->
    _ = ern_rt:later_sayer(),
    {ok, #{formatter := Formatter}} = logger:get_handler_config(default),
    ok = logger:remove_handler(default),
    ok = logger:add_handler(default, ?MODULE,
                            #{level => warning, formatter => Formatter,
                              filters => [{remote_gl, {fun logger_filters:remote_gl/2, stop}}],
                              filter_default => log}).

%% The host's call of its handler, in the process that logs: the event's
%% text is a line the job says later (ern_rt:say_later/2), in the order
%% logged, so that the logging process waits on no stream, a stream that
%% has gone ends the job as any line there does (report §12.1), a shell of
%% its own shows it as it shows a program's standard error, a node writes
%% it on its own whichever process logged it, and the job's end waits until
%% it is written (ern_rt:wait_for_later/0).
%%
%% The text is the one the host's own handler writes (logger_h_common): a
%% report that names no function to format it is formatted as the host's
%% own reports are, a line for each pair, and where Unicode refuses what
%% the formatter gives, the text is a line that says so. A raise here would
%% have the host remove the handler for the rest of the job, so the process
%% that says the line runs from the handler's start (logged/0), and a full
%% table of processes, which keeps a process from being made, raises
%% nothing here (report §12.5).
-spec log(logger:log_event(), logger:handler_config()) -> ok.
log(#{msg := {report, _}, meta := Meta} = Event, HandlerConfig)
  when not is_map_key(report_cb, Meta) ->
    log(Event#{meta := Meta#{report_cb => fun logger:format_otp_report/1}}, HandlerConfig);
log(Event, #{formatter := {Formatter, Config}}) ->
    Text = case unicode:characters_to_binary(Formatter:format(Event, Config)) of
               Formatted when is_binary(Formatted) -> Formatted;
               _ -> <<"FORMATTER ERROR: bad return value\n">>
           end,
    ern_rt:say_later(Text, fun ern_cli:error_line/1).

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

%% A device writes each request in the encoding the request names: text as
%% UTF-8, and Latin-1, the bytes file:write gives, as they are. So it keeps
%% no encoding of its own, and refuses a run's setting for bytes (ern_rt's
%% bytes_out/0), which it needs no setting to write. Its port is busy while
%% it holds a byte it has not written, its limits one byte, and the host
%% holds a writer to a busy port until it is not, as the runtime's stream's
%% port (ern_rt:stream/2).
device(Stream) ->
    Fd = case Stream of
             stdout -> 1;
             stderr -> 2
         end,
    spawn(fun() ->
              process_flag(trap_exit, true),
              loop(erlang:open_port({fd, 0, Fd}, [out, binary, {busy_limits_port, {1, 1}}]),
                   Stream)
          end).

loop(Port, Stream) ->
    receive
        {io_request, From, ReplyAs, Request} ->
            case request(Port, Request) of
                gone ->
                    told(Stream),
                    From ! {io_reply, ReplyAs, ok},
                    dropping(Stream);
                Reply ->
                    From ! {io_reply, ReplyAs, Reply},
                    loop(Port, Stream)
            end;
        {finish, From, Ref} ->
            case drained(Port) of
                ok ->
                    From ! {Ref, finished},
                    loop(Port, Stream);
                gone ->
                    end_job(Stream)
            end;
        {'EXIT', Port, _} ->
            told(Stream),
            dropping(Stream)
    end.

%% Waits until what the port was given is written, or the stream has gone:
%% a write of nothing returns once the port is not busy, which it is while
%% it holds anything (device/1), and fails where the port has ended.
drained(Port) ->
    write(Port, <<>>).

%% The requests io:format, io:put_chars and file:write make, each written in
%% the encoding it names (device/1), and gone where the stream could not take
%% what a request wrote; nothing reads from here, and no option is set.
request(Port, {put_chars, Encoding, Chars}) ->
    case unicode:characters_to_binary(Chars, Encoding, Encoding) of
        Bytes when is_binary(Bytes) -> write(Port, Bytes);
        _ -> {error, no_translation}
    end;
request(Port, {put_chars, Encoding, Module, Function, Arguments}) ->
    request(Port, {put_chars, Encoding, apply(Module, Function, Arguments)});
request(Port, {requests, Requests}) ->
    lists:foldl(fun(Request, ok) -> request(Port, Request);
                   (_, Error) -> Error
                end, ok, Requests);
request(_, getopts) ->
    [{binary, false}, {encoding, unicode}];
request(_, _) ->
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

%% Report §8.6: what is written to a stream that has gone is dropped, and
%% every request but getopts is answered ok, a setting among them, so that
%% no caller waits or faults for a stream that ended; and the job's end
%% finds it gone, which ends the job by it in place of what ended it.
dropping(Stream) ->
    receive
        {io_request, From, ReplyAs, getopts} ->
            From ! {io_reply, ReplyAs, request(none, getopts)},
            dropping(Stream);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, ok},
            dropping(Stream);
        {finish, _, _} ->
            end_job(Stream);
        _ ->
            dropping(Stream)
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
