%% Report §8.2, Appendix E.23: the process behind Os's reference, the
%% process behind each program Os.start starts, and the program's
%% environment. A program's process owns the port of ern_exec
%% (c_src/ern_exec.c), the helper that runs the program, and asks the helper
%% for a piece of the program's output only for a read that waits, so that
%% a program no one reads waits on its output. A read and a write each wait
%% their own milliseconds (E.0 shape rule 8); the program runs until it
%% exits, until its process is killed, since the port closing ends the
%% helper, or until the process that started it dies. A running program is
%% a source (report §8.6) from its start until it has exited or been killed.
-module(ern_os).

-export([loop/0, helper_failed/0, helper/0, environment/0, working_directory/0]).

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
        {'Start', Command, Owner, Reply} ->
            Program = erlang:spawn(fun() ->
                                       link(Os),
                                       receive go -> start(Command, Owner, Reply) end
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
start({'Command', Arguments, Input, Program}, Owner, Reply) ->
    case lists:any(fun(A) -> binary:match(A, <<0>>) =/= nomatch end, [Program | Arguments]) of
        true ->
            answered(Reply, {'Left', 'Invalid'});
        false ->
            try open(["run"]) of
                Port ->
                    %% the command comes as the first frame, not on the
                    %% helper's command line, so that an argument too long
                    %% for the host is the program's failure to start
                    Parts = << <<Part/binary, 0>> || Part <- [Program | Arguments] >>,
                    command(Port, <<"c", Parts/binary>>),
                    started(Port, Input, Owner, Reply)
            catch
                error:_ -> answered(Reply, helper_failed())
            end
    end.

open(Args) ->
    erlang:open_port({spawn_executable, helper()},
                     [{args, Args}, {packet, 4}, binary, exit_status]).

started(Port, Input, Owner, Reply) ->
    command(Port, <<"i", Input/binary>>),
    Watch = erlang:monitor(process, Owner),
    %% the input given at the start is answered by the helper as a write is,
    %% with no one waiting for it
    starting(#{port => Port, watch => Watch, writes => queue:in(none, queue:new())}, Reply).

%% Report §7.4, Appendix E.23: the helper's failure is the runtime's own,
%% which faults the caller that meets it.
-spec helper_failed() -> {fault, binary()}.
helper_failed() ->
    {fault, <<"the runtime's helper ern_exec failed">>}.

%% The helper beside the runtime's modules: erl/runtime/priv/ern_exec, whose
%% jobs are Os's programs and Fs's removal of a tree.
-spec helper() -> file:filename().
helper() ->
    filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "ern_exec"]).

%% Until the helper says whether the program started, the Start is
%% answered by nothing else, and nothing else knows the process. Report
%% Appendix E.23: a start waits for the helper alone, and is not bounded.
starting(#{port := Port} = Run, Reply) ->
    receive
        {Port, {data, <<"s">>}} ->
            ern_rt:answer(Reply, {'Right', erlang:self()}),
            running(Run, queue:new(), 0, queue:new());
        {Port, {data, <<"f", Name/binary>>}} ->
            stop(Run),
            answered(Reply, {'Left', not_started(Name)});
        {Port, {exit_status, _}} ->
            stop(Run),
            answered(Reply, helper_failed());
        {'DOWN', _, process, _, _} ->
            killed(Run)
    end.

%% Waiting: the reads that wait, oldest first, each {Reply, Ref}. Owed: the
%% pieces the helper owes, one asked for each read that came with nothing
%% kept. Kept: the answers the helper gave while no read waited, which the
%% next reads take, in order. The helper sends one piece of output for each
%% piece it was asked for, and the exit status once the program has exited
%% and both its outputs have ended, which it can learn only while a piece is
%% owed. Report Appendix E.23: a read answers `Left(Timeout)` when its
%% milliseconds pass, the program running on, and the piece asked for it is
%% the next read's; a write is answered when the helper says the program has
%% taken its bytes, `a`, or dropped them, `d`, one for each input in order,
%% the replies kept in the run's `writes`, or `Left(Timeout)` first, which
%% does not undo it.
running(#{port := Port} = Run, Waiting, Owed, Kept) ->
    receive
        {'Read', Ms, Reply} ->
            case queue:out(Kept) of
                {{value, Answer}, Rest} ->
                    told(Run, Reply, Answer, Waiting, Owed, Rest);
                {empty, _} ->
                    Ref = make_ref(),
                    arm({read, Ref}, ern_rt:deadline(Ms)),
                    Waiting1 = queue:in({Reply, Ref}, Waiting),
                    %% a piece owed to a read that has gone is this one's
                    case Owed > queue:len(Waiting) of
                        true -> running(Run, Waiting1, Owed, Kept);
                        false -> command(Port, <<"n">>), running(Run, Waiting1, Owed + 1, Kept)
                    end
            end;
        {'Write', Bytes, Ms, Reply} ->
            command(Port, <<"i", Bytes/binary>>),
            arm({write, Reply}, ern_rt:deadline(Ms)),
            running(Run#{writes := queue:in(Reply, maps:get(writes, Run))}, Waiting, Owed, Kept);
        {Port, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d ->
            {{value, Written}, Rest} = queue:out(maps:get(writes, Run)),
            Written =:= none orelse ern_rt:answer(Written, written(Tag)),
            running(Run#{writes := Rest}, Waiting, Owed, Kept);
        'CloseInput' ->
            command(Port, <<"e">>),
            running(Run, Waiting, Owed, Kept);
        {Port, {data, <<"x", Status:32>>}} ->
            %% the program has exited: what it was written meanwhile is
            %% dropped, and its exit status is the last answer
            stop(Run),
            unwritten(Run, {'Left', 'Closed'}),
            given(Run, {'Right', {'Exited', Status}}, Waiting, Owed - 1, Kept);
        {Port, {data, <<Tag, Bytes/binary>>}} ->
            given(Run, {'Right', piece(Tag, Bytes)}, Waiting, Owed - 1, Kept);
        {Port, {exit_status, _}} ->
            %% the helper ended with no status to send: it failed
            stop(Run),
            unwritten(Run, helper_failed()),
            ern_rt:source_end(),
            [respond(Reply, helper_failed()) || {Reply, _} <- queue:to_list(Waiting)],
            over(helper_failed());
        {'DOWN', _, process, _, _} ->
            killed(Run);
        {timeout, _, Timer} ->
            running(Run, timed_out(Timer, Waiting), Owed, Kept)
    end.

%% An answer of the helper's, to the oldest read that waits, or kept for the
%% next read where none does.
given(Run, Answer, Waiting, Owed, Kept) ->
    case queue:out(Waiting) of
        {{value, {Reply, _}}, Rest} -> told(Run, Reply, Answer, Rest, Owed, Kept);
        {empty, _} -> kept(Run, Answer, Waiting, Owed, queue:in(Answer, Kept))
    end.

%% A read answered; the exit status is the last answer, after which the
%% process returns.
told(_Run, Reply, {'Right', {'Exited', _}} = Answer, _Waiting, _Owed, _Kept) ->
    answered(Reply, Answer);
told(Run, Reply, Answer, Waiting, Owed, Kept) ->
    ern_rt:answer(Reply, Answer),
    running(Run, Waiting, Owed, Kept).

%% Where the exit status waits for a read, the program no longer runs: the
%% process answers the reads to come from what is kept, and writes as to a
%% program that has exited.
kept(_Run, {'Right', {'Exited', _}}, _Waiting, _Owed, Kept) ->
    ern_rt:source_end(),
    exited(Kept);
kept(Run, _Answer, Waiting, Owed, Kept) ->
    running(Run, Waiting, Owed, Kept).

exited(Kept) ->
    receive
        {'Read', _, Reply} ->
            {{value, Answer}, Rest} = queue:out(Kept),
            ern_rt:answer(Reply, Answer),
            case Answer of
                {'Right', {'Exited', _}} -> ok;
                _ -> exited(Rest)
            end;
        {'Write', _, _, Reply} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            exited(Kept);
        {'DOWN', _, process, _, _} ->
            %% the process that started it died, and no read is to come
            exit({ern, killed});
        _ ->
            exited(Kept)
    end.

%% A time passed: a write's answers `Left(Timeout)` at once, any answer of the
%% helper's after it dropped as a second answer is; a read's, where it still
%% waits, answers it too and takes it from the reads that wait. A wait
%% longer than the host's longest timer is armed again until it has passed
%% (report §6.3).
timed_out({Kind, Deadline}, Waiting) ->
    case ern_rt:remaining(Deadline) of
        0 -> passed(Kind, Waiting);
        _ -> arm(Kind, Deadline), Waiting
    end.

passed({write, Reply}, Waiting) ->
    ern_rt:answer(Reply, {'Left', 'Timeout'}),
    Waiting;
passed({read, Ref}, Waiting) ->
    queue:filter(fun({Reply, R}) when R =:= Ref ->
                         ern_rt:answer(Reply, {'Left', 'Timeout'}),
                         false;
                    (_) ->
                         true
                 end, Waiting).

arm(Kind, Deadline) ->
    erlang:start_timer(ern_rt:remaining(Deadline), erlang:self(), {Kind, Deadline}).

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
    [respond(R, Answer) || R <- queue:to_list(Writes), R =/= none],
    ok.

piece($o, Bytes) -> {'Stdout', Bytes};
piece($r, Bytes) -> {'Stderr', Bytes}.

%% A program whose helper failed: each read and write to come faults its
%% caller. The process that started it may still die first, which ends this
%% one as it would have ended the program.
over(Answer) ->
    receive
        {'Read', _, Reply} -> respond(Reply, Answer), over(Answer);
        {'Write', _, _, Written} -> respond(Written, Answer), over(Answer);
        {'DOWN', _, process, _, _} -> exit({ern, killed});
        _ -> over(Answer)
    end.

%% The port closed, which ends the helper and kills the program if it runs.
%% The watch on the process that started it stays.
stop(#{port := Port}) ->
    try erlang:port_close(Port) catch error:badarg -> closed end.

%% The last answer while the program counts as a source, given before the
%% count ends, so that no deadlock is found between the two (report §8.6).
answered(Reply, Answer) ->
    respond(Reply, Answer),
    ern_rt:source_end().

%% An answer, or the caller faulted where the runtime failed.
respond(Reply, {fault, Cause}) -> ern_rt:refuse(Reply, Cause);
respond(Reply, Answer) -> ern_rt:answer(Reply, Answer).

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
