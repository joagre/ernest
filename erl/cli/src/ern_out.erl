%% Report §11: the standard output and standard error of a job that writes
%% text, through ports on the process's own descriptors rather than the
%% host's user process, which halts the host with a crash dump once a
%% stream's reader has gone. Where one has, the job ends at once and says
%% nothing, with the status 141 that shells give a process a closed pipe
%% ended. `ern run` and `ern test` write through the runtime, which learns
%% the same of its own streams (report §8.2); `ern shell` writes here where
%% its output is no terminal, and takes the bytes a program writes as they
%% are.
-module(ern_out).

-export([take/0, finish/1]).

%% Standard output becomes the calling process's group leader, which the
%% processes it starts inherit; the answer is standard error's device.
-spec take() -> pid().
take() ->
    group_leader(device(1), self()),
    device(2).

%% The job's streams written out before `ern` ends, standard output's and
%% the device given; where a reader has gone, `ern` ends there.
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
%% has set its encoding to latin1 (ern_rt's bytes_out/0).
device(Fd) ->
    spawn(fun() ->
              process_flag(trap_exit, true),
              loop(erlang:open_port({fd, 0, Fd}, [out, binary]), unicode)
          end).

loop(Port, Encoding) ->
    receive
        {io_request, From, ReplyAs, {setopts, Options}} ->
            From ! {io_reply, ReplyAs, ok},
            loop(Port, proplists:get_value(encoding, Options, Encoding));
        {io_request, From, ReplyAs, Request} ->
            From ! {io_reply, ReplyAs, request(Port, Encoding, Request)},
            loop(Port, Encoding);
        {finish, From, Ref} ->
            drain(Port),
            From ! {Ref, finished},
            loop(Port, Encoding);
        {'EXIT', Port, _} ->
            end_job()
    end.

%% Waits until what the port was given is written, or the reader has gone.
drain(Port) ->
    case erlang:port_info(Port, queue_size) of
        {queue_size, 0} -> ok;
        {queue_size, _} -> receive {'EXIT', Port, _} -> end_job() after 1 -> drain(Port) end;
        undefined -> end_job()
    end.

%% The requests io:format and io:put_chars make; nothing reads from here.
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
        error:badarg -> end_job()
    end.

%% The reader has gone: the job ends at once, as a closed pipe ends a
%% process, status 141.
end_job() ->
    erlang:halt(141).
