%% Report §8.2, Appendix E.23: the process behind Os's reference, the
%% process behind each program Os.start starts, and the program's
%% environment. A program's process owns the port of ern_exec
%% (c_src/ern_exec.c), the helper that runs the program, and asks the helper
%% for a piece of the program's output only for a read that waits, so that
%% a program no one reads waits on its output. Its time limit, fixed when it
%% starts, kills the program; the program is killed too when its process is
%% killed, since the port closing ends the helper, and when the process that
%% started it dies. A running program is a source (report §8.6) from its
%% start until it has exited or been killed.
-module(ern_os).

-export([loop/0, environment/0, working_directory/0]).

%% Report §8.6: every program's process is linked to this one, which the
%% runtime kills when the program ends, so that none outlives it; this
%% process traps the exits and forgets what the runtime recorded of a
%% program's process that ended.
-spec loop() -> no_return().
loop() ->
    process_flag(trap_exit, true),
    serve(erlang:self()).

serve(Os) ->
    receive
        {'Start', Command, Ms, Owner, Reply} ->
            Program = erlang:spawn(fun() ->
                                       link(Os),
                                       receive go -> start(Command, Ms, Owner, Reply) end
                                   end),
            ern_rt:opened(Program, <<"Os.start">>),
            ern_rt:source_begin(Program),
            Program ! go,
            serve(Os);
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Os)
    end.

%% Command is `Command(program, arguments, input)`, its fields in their
%% canonical order.
%% Report Appendix E.23: the time runs from the start, armed before the
%% helper is, so that a time that passes before the program has started is
%% seen to.
start({'Command', Arguments, Input, Program}, Ms, Owner, Reply) ->
    Deadline = ern_rt:deadline(Ms),
    Timer = arm(Deadline),
    case lists:any(fun(A) -> binary:match(A, <<0>>) =/= nomatch end, [Program | Arguments]) of
        true ->
            answered(Reply, {'Left', {'Other', <<"an argument holds U+0000">>}});
        false ->
            try open([Program | Arguments]) of
                Port -> started(Port, Input, {Deadline, Timer}, Owner, Reply)
            catch
                error:_ -> answered(Reply, {'Left', helper_failed()})
            end
    end.

open(Args) ->
    erlang:open_port({spawn_executable, helper()},
                     [{args, Args}, {packet, 4}, binary, exit_status]).

started(Port, Input, {Deadline, Timer}, Owner, Reply) ->
    command(Port, <<"i", Input/binary>>),
    Watch = erlang:monitor(process, Owner),
    %% the input given at the start is answered by the helper as a write is,
    %% with no one waiting for it
    starting(#{port => Port, watch => Watch, deadline => Deadline, timer => Timer,
               writes => queue:in(none, queue:new())},
             Reply).

helper_failed() ->
    {'Other', <<"the runtime's helper ern_exec failed">>}.

%% The helper beside the runtime's modules: erl/runtime/priv/ern_exec.
helper() ->
    filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "ern_exec"]).

%% Until the helper says whether the program started, the Start is
%% answered by nothing else, and nothing else knows the process. Report
%% Appendix E.23: a start learned after the time has passed is a time
%% passed, whichever of the helper's word and the timer's arrived first, so
%% a time of 0 always answers `Left(Timeout)`. A regression: a fast helper
%% was answered `Right` before the timer's message came.
starting(#{port := Port, deadline := Deadline} = Run, Reply) ->
    receive
        {Port, {data, <<"s">>}} ->
            case ern_rt:remaining(Deadline) of
                0 ->
                    stop(Run),
                    answered(Reply, {'Left', 'Timeout'});
                _ ->
                    ern_rt:answer(Reply, {'Right', erlang:self()}),
                    running(Run, queue:new())
            end;
        {Port, {data, <<"f", Name/binary>>}} ->
            stop(Run),
            answered(Reply, {'Left', not_started(Name)});
        {Port, {exit_status, _}} ->
            stop(Run),
            answered(Reply, {'Left', helper_failed()});
        {'DOWN', _, process, _, _} ->
            killed(Run);
        {timeout, _} = Tick ->
            case timed_out(Run, Tick) of
                {again, Run1} -> starting(Run1, Reply);
                over -> stop(Run), answered(Reply, {'Left', 'Timeout'})
            end
    end.

%% Waiting: the replies of the reads that wait, oldest first. The helper
%% sends one piece of output for each read it was asked for, and the exit
%% status once the program has exited and both its outputs have ended,
%% which it can learn only while a read waits; so a read waits for every
%% piece and for the status. The exit status is the last answer, and the process
%% returns after it. Report Appendix E.23: a write is answered when the
%% helper says the program has taken its bytes, `a`, or dropped them, `d`,
%% one for each input in order, the replies kept in the run's `writes`, so
%% that a writer waits while the program is behind; what still waits when
%% the program ends is answered then.
running(#{port := Port} = Run, Waiting) ->
    receive
        {'Read', Reply} ->
            command(Port, <<"n">>),
            running(Run, queue:in(Reply, Waiting));
        {'Write', Bytes, Reply} ->
            command(Port, <<"i", Bytes/binary>>),
            running(Run#{writes := queue:in(Reply, maps:get(writes, Run))}, Waiting);
        {Port, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d ->
            {{value, Written}, Rest} = queue:out(maps:get(writes, Run)),
            Written =:= none orelse ern_rt:answer(Written, written(Tag)),
            running(Run#{writes := Rest}, Waiting);
        'CloseInput' ->
            command(Port, <<"e">>),
            running(Run, Waiting);
        {Port, {data, <<"x", Status:32>>}} ->
            {{value, Reply}, _} = queue:out(Waiting),
            stop(Run),
            unwritten(Run, {'Left', 'Closed'}),
            answered(Reply, {'Right', {'Exited', Status}});
        {Port, {data, <<Tag, Bytes/binary>>}} ->
            {{value, Reply}, Rest} = queue:out(Waiting),
            ern_rt:answer(Reply, {'Right', piece(Tag, Bytes)}),
            running(Run, Rest);
        {Port, {exit_status, _}} ->
            %% the helper ended with no status to send: it failed
            stop(Run),
            unwritten(Run, {'Left', helper_failed()}),
            over(Waiting, {'Left', helper_failed()});
        {'DOWN', _, process, _, _} ->
            killed(Run);
        {timeout, _} = Tick ->
            case timed_out(Run, Tick) of
                {again, Run1} -> running(Run1, Waiting);
                over ->
                    stop(Run),
                    unwritten(Run, {'Left', 'Closed'}),
                    over(Waiting, {'Left', 'Timeout'})
            end
    end.

%% A frame for the helper. A port the helper's end has closed has sent its
%% exit status first, which ends the run, so a frame after it is dropped.
command(Port, Frame) ->
    try erlang:port_command(Port, Frame) catch error:badarg -> closed end.

%% Report Appendix E.23: bytes the program took, and bytes dropped, given
%% after the end of its input or after it closed it.
written($a) -> {'Right', 'Unit'};
written($d) -> {'Left', 'Closed'}.

%% The writes still waiting when the program has ended: their bytes are
%% dropped, and each is answered that its input is closed, or why the
%% runtime lost the program.
unwritten(#{writes := Writes}, Answer) ->
    [ern_rt:answer(R, Answer) || R <- queue:to_list(Writes), R =/= none],
    ok.

piece($o, Bytes) -> {'Stdout', Bytes};
piece($r, Bytes) -> {'Stderr', Bytes}.

%% A program killed for its time, or whose helper failed: the first read,
%% waiting or to come, is answered why, and the process returns; what is
%% written to it meanwhile is dropped, and answered as unwritable/1 says.
%% The process that started it may
%% still die first, which ends this one as it would have ended the program.
over(Waiting, Answer) ->
    case queue:out(Waiting) of
        {{value, Reply}, _} ->
            answered(Reply, Answer);
        {empty, _} ->
            ern_rt:source_end(),
            over(Answer)
    end.

over(Answer) ->
    receive
        {'Read', Reply} -> ern_rt:answer(Reply, Answer);
        {'Write', _, Written} -> ern_rt:answer(Written, unwritable(Answer)), over(Answer);
        'CloseInput' -> over(Answer);
        {'DOWN', _, process, _, _} -> exit({ern, killed})
    end.

%% A write to a program killed for its time finds its input closed; one to
%% a program the runtime lost is told why, as a read is.
unwritable({'Left', 'Timeout'}) -> {'Left', 'Closed'};
unwritable(Answer) -> Answer.

%% The time limit, armed as the host's longest timer allows and armed again
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

%% The port closed, which ends the helper and kills the program if it runs.
%% The watch on the process that started it stays, since this process lives
%% on after a time limit.
stop(#{port := Port}) ->
    try erlang:port_close(Port) catch error:badarg -> closed end.

%% The last answer while the program counts as a source, given before the
%% count ends, so that no deadlock is found between the two (report §8.6).
answered(Reply, Answer) ->
    ern_rt:answer(Reply, Answer),
    ern_rt:source_end().

%% The process that started the program died: the program is killed with
%% this process, which ends as a killed process does.
killed(Run) ->
    stop(Run),
    ern_rt:source_end(),
    exit({ern, killed}).

%% Report Appendix E.23: why a program did not start, by the error's name
%% the helper sends.
not_started(<<"enoent">>) -> 'NotFound';
not_started(<<"enotdir">>) -> 'NotFound';
not_started(<<"eacces">>) -> 'Denied';
not_started(<<"eperm">>) -> 'Denied';
not_started(Text) -> {'Other', Text}.

%% Report Appendix E.23: the program's environment, as the helper run with
%% no program writes it back, byte for byte, since the host decodes a value
%% that is not UTF-8 without a sign. A variable whose name or value is not
%% UTF-8 is left out, and a name that occurs twice keeps its first value.
-spec environment() -> #{binary() => binary()}.
environment() ->
    Port = try open([])
           catch error:_ -> ern_rt:fault(<<"the runtime's helper ern_exec failed">>)
           end,
    variables(Port, #{}).

%% Report Appendix E.23: a name that occurs twice keeps its first value, and
%% one whose first value is not UTF-8 is left out, a later value of it too;
%% the names seen are kept, a value left out as `dropped`, until the end.
variables(Port, Env) ->
    receive
        {Port, {data, <<"v", Variable/binary>>}} ->
            variables(Port, variable(binary:split(Variable, <<"=">>), Env));
        {Port, {data, <<"x", _/binary>>}} ->
            receive
                {Port, {exit_status, _}} -> maps:filter(fun(_, V) -> V =/= dropped end, Env)
            end;
        {Port, {exit_status, _}} ->
            ern_rt:fault(<<"the runtime's helper ern_exec failed">>)
    end.

variable([Name, Value], Env) ->
    case {is_map_key(Name, Env), utf8(Name) andalso utf8(Value)} of
        {true, _} -> Env;
        {false, true} -> Env#{Name => Value};
        {false, false} -> Env#{Name => dropped}
    end;
variable([_], Env) ->
    Env.

utf8(Bytes) ->
    is_binary(unicode:characters_to_binary(Bytes, utf8, utf8)).

%% Report Appendix E.23, §7.4: the directory the program was started in,
%% absolute, whose name ern has found UTF-8 before starting (report §11):
%% decoded where the host's names are UTF-8, and its bytes where they are
%% bytes. One the host can no longer read, removed since, faults the
%% binding with the host's reason.
-spec working_directory() -> binary().
working_directory() ->
    case file:get_cwd() of
        {ok, Dir} -> name(file:native_name_encoding(), Dir);
        {error, Reason} ->
            ern_rt:fault(iolist_to_binary(["the working directory cannot be read: ",
                                           atom_to_list(Reason)]))
    end.

name(latin1, Dir) -> list_to_binary(Dir);
name(utf8, Dir) -> unicode:characters_to_binary(Dir).
