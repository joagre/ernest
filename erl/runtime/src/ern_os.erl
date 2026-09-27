%% Report §8.2, Appendix E.23: the process behind Os's reference, and the
%% process behind each program Os.run runs. A run's process owns the port
%% of ern_exec (c_src/ern_exec.c), the helper that runs the program, and
%% answers each Next with the program's next output, standard error, or
%% exit status, in the order they came. Its deadline, fixed when it starts,
%% ends the run with Timeout; the program is killed then, and when the
%% process that called run dies. A run is a source (report §8.6) from its
%% start to its end.
-module(ern_os).

-export([loop/0]).

%% Report §8.6: every run's process is linked to this one, which the
%% runtime kills when the program ends, so that none outlives it, and the
%% port it owns closing kills the program; this process traps the exits and
%% forgets what the runtime recorded of a run that ended.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self()).

serve(Os) ->
    receive
        {'Start', Command, Ms, Owner, Reply} ->
            Run = erlang:spawn(fun() ->
                                   link(Os),
                                   receive go -> start(Command, Ms, Owner, Reply) end
                               end),
            ern_rt:opened(Run),
            ern_rt:source_begin(Run),
            Run ! go,
            serve(Os);
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Os)
    end.

%% Command is `Command(program, arguments, input)`, its fields in their
%% canonical order.
start({'Command', Arguments, Input, Program}, Ms, Owner, Reply) ->
    case lists:any(fun(A) -> binary:match(A, <<0>>) =/= nomatch end, [Program | Arguments]) of
        true ->
            finish(Reply, {'Left', {'Other', <<"an argument holds U+0000">>}});
        false ->
            try erlang:open_port({spawn_executable, helper()},
                                 [{args, [Program | Arguments]}, {packet, 4}, binary,
                                  exit_status]) of
                Port -> started(Port, Input, Ms, Owner, Reply)
            catch
                error:_ -> finish(Reply, {'Left', helper_failed()})
            end
    end.

started(Port, Input, Ms, Owner, Reply) ->
    erlang:port_command(Port, <<"i", Input/binary>>),
    erlang:port_command(Port, <<"e">>),
    Watch = erlang:monitor(process, Owner),
    Deadline = ern_rt:deadline(Ms),
    starting(#{port => Port, watch => Watch, deadline => Deadline, timer => arm(Deadline)},
             Reply).

helper_failed() ->
    {'Other', <<"the runtime's helper ern_exec did not run">>}.

%% The helper beside the runtime's modules: erl/runtime/priv/ern_exec.
helper() ->
    filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "ern_exec"]).

%% Until the helper says whether the program started, the Start is
%% answered by nothing else.
starting(#{port := Port} = Run, Reply) ->
    receive
        {Port, {data, <<"s">>}} ->
            ern_rt:answer(Reply, {'Right', erlang:self()}),
            running(Run, queue:new(), none);
        {Port, {data, <<"f", Name/binary>>}} ->
            stop(Run),
            finish(Reply, {'Left', not_started(Name)});
        {Port, {exit_status, _}} ->
            stop(Run),
            finish(Reply, {'Left', helper_failed()});
        {'DOWN', _, process, _, _} ->
            stop(Run),
            ern_rt:source_end();
        {timeout, _} = Tick ->
            case timed_out(Run, Tick) of
                {again, Run1} -> starting(Run1, Reply);
                over -> stop(Run), finish(Reply, {'Left', 'Timeout'})
            end
    end.

%% Events: what the program sent that no Next has taken yet. Waiting: the
%% reply of a Next with nothing to take, or none. A run's last event is its
%% exit status, after which its process ends.
running(#{port := Port} = Run, Events, Waiting) ->
    receive
        {'Next', Reply} when Waiting =:= none ->
            case queue:out(Events) of
                {{value, {'Exited', _} = Last}, _} ->
                    stop(Run),
                    finish(Reply, {'Right', Last});
                {{value, Event}, Rest} ->
                    ern_rt:answer(Reply, {'Right', Event}),
                    running(Run, Rest, none);
                {empty, _} ->
                    running(Run, Events, Reply)
            end;
        {Port, {data, <<Tag, Data/binary>>}} ->
            Event = case Tag of
                        $o -> {'Stdout', Data};
                        $r -> {'Stderr', Data};
                        $x -> <<Status:32>> = Data, {'Exited', Status}
                    end,
            case Waiting of
                none ->
                    running(Run, queue:in(Event, Events), none);
                _ when Tag =:= $x ->
                    stop(Run),
                    finish(Waiting, {'Right', Event});
                _ ->
                    ern_rt:answer(Waiting, {'Right', Event}),
                    running(Run, Events, none)
            end;
        {Port, {exit_status, _}} ->
            %% the helper ended with no status to send: it failed
            stop(Run),
            Waiting =:= none orelse ern_rt:answer(Waiting, {'Left', helper_failed()}),
            ern_rt:source_end();
        {'DOWN', _, process, _, _} ->
            stop(Run),
            ern_rt:source_end();
        {timeout, _} = Tick ->
            case timed_out(Run, Tick) of
                {again, Run1} ->
                    running(Run1, Events, Waiting);
                over ->
                    stop(Run),
                    case Waiting of
                        none -> timed_out_loop();
                        _ -> finish(Waiting, {'Left', 'Timeout'})
                    end
            end
    end.

%% A run whose time ran out between two Nexts answers the next with
%% Timeout, and ends.
timed_out_loop() ->
    receive
        {'Next', Reply} -> finish(Reply, {'Left', 'Timeout'})
    end.

%% The deadline, armed as the host's longest timer allows and armed again
%% until it has passed (report §6.3).
arm(Deadline) ->
    Ref = make_ref(),
    erlang:send_after(ern_rt:remaining(Deadline), erlang:self(), {timeout, Ref}),
    Ref.

timed_out(#{deadline := Deadline, timer := Ref} = Run, {timeout, Ref}) ->
    case ern_rt:remaining(Deadline) of
        0 -> over;
        _ -> {again, Run#{timer := arm(Deadline)}}
    end;
timed_out(Run, _) ->
    {again, Run}.

%% The port closed, which ends the helper and kills the program if it runs,
%% and the watch on the caller removed.
stop(#{port := Port, watch := Watch}) ->
    erlang:demonitor(Watch, [flush]),
    try erlang:port_close(Port) catch error:badarg -> closed end,
    ok.

%% The last answer of a run, and the end of its count as a source.
finish(Reply, Answer) ->
    ern_rt:answer(Reply, Answer),
    ern_rt:source_end().

%% Report Appendix E.23: why a program did not start, by the error's name
%% the helper sends.
not_started(<<"enoent">>) -> 'NotFound';
not_started(<<"enotdir">>) -> 'NotFound';
not_started(<<"eacces">>) -> 'Denied';
not_started(<<"eperm">>) -> 'Denied';
not_started(Text) -> {'Other', Text}.
