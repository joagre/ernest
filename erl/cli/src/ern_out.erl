%% Report §11: the standard output and standard error of a job that writes
%% text, through ports on the process's own descriptors rather than the
%% host's user process, which halts the host with a crash dump once a
%% stream's reader has gone. Where one has, the job ends at once and says
%% nothing, with the status 141 that shells give a process a closed pipe
%% ended. `ern run`, `ern test` and `ern shell` write through the runtime,
%% which learns the same of its own streams (report §8.2).
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
finish(Err) when is_pid(Err) ->
    lists:foreach(fun(Device) ->
                      Ref = erlang:monitor(process, Device),
                      Device ! {finish, self(), Ref},
                      receive
                          {Ref, finished} -> erlang:demonitor(Ref, [flush]);
                          {'DOWN', Ref, process, _, _} -> ok
                      end
                  end, [group_leader(), Err]);
finish(_) ->
    ok.

device(Fd) ->
    spawn(fun() ->
              process_flag(trap_exit, true),
              loop(erlang:open_port({fd, 0, Fd}, [out, binary]))
          end).

loop(Port) ->
    receive
        {io_request, From, ReplyAs, Request} ->
            From ! {io_reply, ReplyAs, request(Port, Request)},
            loop(Port);
        {finish, From, Ref} ->
            drained(Port),
            From ! {Ref, finished},
            loop(Port);
        {'EXIT', Port, _} ->
            gone()
    end.

%% What the port was given is written, or the reader has gone.
drained(Port) ->
    case erlang:port_info(Port, queue_size) of
        {queue_size, 0} -> ok;
        {queue_size, _} -> receive {'EXIT', Port, _} -> gone() after 1 -> drained(Port) end;
        undefined -> gone()
    end.

%% The requests io:format and io:put_chars make; nothing reads from here.
request(Port, {put_chars, Encoding, Chars}) ->
    case unicode:characters_to_binary(Chars, Encoding, utf8) of
        Bin when is_binary(Bin) -> write(Port, Bin);
        _ -> {error, no_translation}
    end;
request(Port, {put_chars, Encoding, M, F, A}) ->
    request(Port, {put_chars, Encoding, apply(M, F, A)});
request(Port, {requests, Requests}) ->
    lists:foldl(fun(R, ok) -> request(Port, R);
                   (_, Error) -> Error
                end, ok, Requests);
request(_, {setopts, _}) ->
    ok;
request(_, getopts) ->
    [{binary, false}, {encoding, unicode}];
request(_, _) ->
    {error, enotsup}.

write(Port, Bin) ->
    try erlang:port_command(Port, Bin) of
        true -> ok
    catch
        error:badarg -> gone()
    end.

gone() ->
    erlang:halt(141).
