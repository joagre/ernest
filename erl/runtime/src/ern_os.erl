%% Report §8.2, Appendix E.23: the process behind Os's reference, the
%% process behind each program Os.start starts, and the program's
%% environment. A program's process owns the port of ern_exec
%% (c_src/ern_exec.c), the helper that runs the program, and asks the helper
%% for a piece of the program's output only for a read that waits, so that
%% a program no one reads waits on its output. A read and a write each wait
%% their own milliseconds (E.0 shape rule 8); the program runs until it
%% exits, until its process is killed, since the port closing ends the
%% helper, or until its owner dies (E.23). A running program is
%% a source (report §8.6) from its start until it has exited or been killed.
-module(ern_os).

-export([loop/0, helper_failed/0, helper/0, host/0, umask/0, working_directory/0]).

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
            Pid = erlang:spawn(fun() ->
                                   link(Os),
                                   receive go -> start(Command, Owner, Reply) end
                               end),
            ern_rt:opened(Pid, <<"Os.start">>),
            ern_rt:source_begin(Pid),
            Pid ! go,
            serve(Os);
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Os)
    end.

%% Command is `Command(program, arguments, input)`, its fields in their
%% declared order (report §3.5).
start({'Command', Program, Arguments, Input}, Owner, Reply) ->
    case lists:any(fun(Word) -> binary:match(Word, <<0>>) =/= nomatch end, [Program | Arguments]) of
        true ->
            answered(Reply, {'Left', 'Invalid'});
        false ->
            try open(["run"]) of
                Helper ->
                    %% the command comes as the first frame, not on the
                    %% helper's command line, so that an argument too long
                    %% for the host is the program's failure to start
                    Parts = << <<Part/binary, 0>> || Part <- [Program | Arguments] >>,
                    command(Helper, <<"c", Parts/binary>>),
                    started(Helper, Input, Owner, Reply)
            catch
                error:_ -> answered(Reply, helper_failed())
            end
    end.

open(Args) ->
    erlang:open_port({spawn_executable, helper()},
                     [{args, Args}, {packet, 4}, binary, exit_status]).

started(Helper, Input, Owner, Reply) ->
    command(Helper, <<"i", Input/binary>>),
    MonitorRef = erlang:monitor(process, Owner),
    %% the input given at the start is answered by the helper as a write is,
    %% with no one waiting for it
    Writes = queue:in(none, queue:new()),
    starting(#{helper => Helper, monitor_ref => MonitorRef, writes => Writes}, Reply).

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
starting(#{helper := Helper} = Running, Reply) ->
    receive
        {Helper, {data, <<"s">>}} ->
            ern_rt:answer(Reply, {'Right', erlang:self()}),
            running(Running, queue:new(), 0, queue:new());
        {Helper, {data, <<"f", Name/binary>>}} ->
            stop(Running),
            answered(Reply, {'Left', not_started(Name)});
        {Helper, {exit_status, _}} ->
            stop(Running),
            answered(Reply, helper_failed());
        {'DOWN', _, process, _, _} ->
            killed(Running)
    end.

%% Waiting: the reads that wait, oldest first, each {Reply, Ref, Timer}. Owed: the
%% pieces the helper owes, one asked for each read that came with nothing
%% kept. Kept: the answers the helper gave while no read waited, which the
%% next reads take, in order. The helper sends one piece of output for each
%% piece it was asked for, and the exit status once the program has exited
%% and both its outputs have ended, which it can learn only while a piece is
%% owed. Report Appendix E.23: a read answers `Left(Timeout)` when its
%% milliseconds pass, the program running on, and the piece asked for it is
%% the next read's; a write is answered when the helper says the program has
%% taken its bytes, `a`, or dropped them, `d`, one for each input in order,
%% the replies kept in the program's `writes`, each {Reply, Timer}, or
%% `Left(Timeout)` first, which does not undo it and leaves `none` in its
%% place. A request answered lets go of its timer.
running(#{helper := Helper} = Running, Waiting, Owed, Kept) ->
    receive
        {'Read', Ms, Reply} ->
            read(Ms, Reply, Running, Waiting, Owed, Kept);
        {'Write', Bytes, Ms, Reply} ->
            command(Helper, <<"i", Bytes/binary>>),
            Timer = arm({write, Reply}, ern_rt:deadline(Ms)),
            Writes = queue:in({Reply, Timer}, maps:get(writes, Running)),
            running(Running#{writes := Writes}, Waiting, Owed, Kept);
        {Helper, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d ->
            {{value, Write}, Rest} = queue:out(maps:get(writes, Running)),
            answered_write(Write, written(Tag)),
            running(Running#{writes := Rest}, Waiting, Owed, Kept);
        'CloseInput' ->
            command(Helper, <<"e">>),
            running(Running, Waiting, Owed, Kept);
        {'Give', Owner} ->
            running(given_to(Owner, Running), Waiting, Owed, Kept);
        {Helper, {data, <<"x", Status:32>>}} ->
            %% the program has exited: what it was written meanwhile is
            %% dropped, and its exit status is the last answer
            stop(Running),
            unwritten(Running, {'Left', 'Closed'}),
            given(Running, {'Right', {'Exited', Status}}, Waiting, Owed - 1, Kept);
        {Helper, {data, <<Tag, Bytes/binary>>}} ->
            given(Running, {'Right', piece(Tag, Bytes)}, Waiting, Owed - 1, Kept);
        {Helper, {exit_status, _}} ->
            failed(Running, Waiting);
        {'DOWN', MonitorRef, process, _, _} when MonitorRef =:= map_get(monitor_ref, Running) ->
            killed(Running);
        {timeout, _, {{write, Reply}, Deadline}} ->
            Writes = write_timed_out(Reply, Deadline, maps:get(writes, Running)),
            running(Running#{writes := Writes}, Waiting, Owed, Kept);
        {timeout, _, {{read, Ref}, Deadline}} ->
            running(Running, read_timed_out(Ref, Deadline, Waiting), Owed, Kept)
    end.

%% A read, answered a piece kept for it, or else waiting; the helper is
%% asked for a piece but where one is owed to a read that has gone, which
%% is this one's.
read(Ms, Reply, #{helper := Helper} = Running, Waiting, Owed, Kept) ->
    case queue:out(Kept) of
        {{value, Answer}, Rest} ->
            told(Running, Reply, Answer, Waiting, Owed, Rest);
        {empty, _} ->
            Ref = make_ref(),
            Timer = arm({read, Ref}, ern_rt:deadline(Ms)),
            Waiting1 = queue:in({Reply, Ref, Timer}, Waiting),
            case Owed > queue:len(Waiting) of
                true -> running(Running, Waiting1, Owed, Kept);
                false -> command(Helper, <<"n">>), running(Running, Waiting1, Owed + 1, Kept)
            end
    end.

%% The helper ended with no status to send: it failed, and each write and
%% each read waiting is answered so.
failed(Running, Waiting) ->
    stop(Running),
    unwritten(Running, helper_failed()),
    ern_rt:source_end(),
    lists:foreach(fun({Reply, _, Timer}) ->
                      let_go(Timer),
                      respond(Reply, helper_failed())
                  end, queue:to_list(Waiting)),
    over(helper_failed(), Running).

%% An answer of the helper's, to the oldest read that waits, or kept for the
%% next read where none does.
given(Running, Answer, Waiting, Owed, Kept) ->
    case queue:out(Waiting) of
        {{value, {Reply, _, Timer}}, Rest} ->
            let_go(Timer),
            told(Running, Reply, Answer, Rest, Owed, Kept);
        {empty, _} ->
            kept(Running, Answer, Waiting, Owed, queue:in(Answer, Kept))
    end.

%% A read answered; the exit status is the last answer, after which the
%% process returns.
told(_Running, Reply, {'Right', {'Exited', _}} = Answer, _Waiting, _Owed, _Kept) ->
    answered(Reply, Answer);
told(Running, Reply, Answer, Waiting, Owed, Kept) ->
    ern_rt:answer(Reply, Answer),
    running(Running, Waiting, Owed, Kept).

%% Where the exit status waits for a read, the program no longer runs: the
%% process answers the reads to come from what is kept, and writes as to a
%% program that has exited.
kept(Running, {'Right', {'Exited', _}}, _Waiting, _Owed, Kept) ->
    ern_rt:source_end(),
    exited(Kept, Running);
kept(Running, _Answer, Waiting, Owed, Kept) ->
    running(Running, Waiting, Owed, Kept).

exited(Kept, #{monitor_ref := MonitorRef} = Running) ->
    receive
        {'Read', _, Reply} ->
            {{value, Answer}, Rest} = queue:out(Kept),
            ern_rt:answer(Reply, Answer),
            case Answer of
                {'Right', {'Exited', _}} -> ok;
                _ -> exited(Rest, Running)
            end;
        {'Write', _, _, Reply} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            exited(Kept, Running);
        {'Give', Owner} ->
            exited(Kept, given_to(Owner, Running));
        {'DOWN', MonitorRef, process, _, _} ->
            %% its owner died, and no read is to come
            exit({ern, killed});
        _ ->
            exited(Kept, Running)
    end.

%% A time passed: a write's answers `Left(Timeout)` at once, any answer of the
%% helper's after it dropped as a second answer is; a read's, where it still
%% waits, answers it too and takes it from the reads that wait. A wait
%% longer than the host's longest timer is armed again until it has passed
%% (report §6.3).
write_timed_out(Reply, Deadline, Writes) ->
    queue:from_list([case Write of
                         {Reply, _} -> expired_write(Reply, Deadline);
                         _ -> Write
                     end || Write <- queue:to_list(Writes)]).

expired_write(Reply, Deadline) ->
    case ern_rt:remaining(Deadline) of
        0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            none;
        _ ->
            {Reply, arm({write, Reply}, Deadline)}
    end.

read_timed_out(Ref, Deadline, Waiting) ->
    queue:from_list(lists:append([case Read of
                                      {Reply, Ref, _} -> expired_read(Reply, Ref, Deadline);
                                      _ -> [Read]
                                  end || Read <- queue:to_list(Waiting)])).

expired_read(Reply, Ref, Deadline) ->
    case ern_rt:remaining(Deadline) of
        0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            [];
        _ ->
            [{Reply, Ref, arm({read, Ref}, Deadline)}]
    end.

%% A request's timer, which names the request and its deadline.
arm(Kind, Deadline) ->
    erlang:start_timer(ern_rt:remaining(Deadline), erlang:self(), {Kind, Deadline}).

%% Report Appendix E.23: a request answered holds no timer. One that fired
%% as its request was answered finds the request gone, and does nothing.
let_go(Timer) ->
    erlang:cancel_timer(Timer, [{async, true}, {info, false}]).

%% A write the helper has answered for: its caller is answered and its timer
%% let go. One whose time had passed was answered then, and the input given
%% at the start has no caller.
answered_write(none, _Answer) ->
    ok;
answered_write({Reply, Timer}, Answer) ->
    let_go(Timer),
    respond(Reply, Answer).

%% A frame for the helper. A helper whose end has closed has sent its exit
%% status first, which ends the program, so a frame after it is dropped.
command(Helper, Frame) ->
    try erlang:port_command(Helper, Frame) catch error:badarg -> closed end.

%% Report Appendix E.23: bytes the program took, and bytes dropped, given
%% after the end of its input or after it closed it.
written($a) -> {'Right', 'Unit'};
written($d) -> {'Left', 'Closed'}.

%% The writes still waiting when the program has ended: their bytes are
%% dropped, and each is answered that its input is closed, or why the
%% runtime lost the program.
unwritten(#{writes := Writes}, Answer) ->
    lists:foreach(fun(Write) -> answered_write(Write, Answer) end, queue:to_list(Writes)).

piece($o, Bytes) -> {'Stdout', Bytes};
piece($r, Bytes) -> {'Stderr', Bytes}.

%% A program whose helper failed: each read and write to come faults its
%% caller. Its owner may still die first, which ends this process as it
%% would have ended the program.
over(Answer, #{monitor_ref := MonitorRef} = Running) ->
    receive
        {'Read', _, Reply} -> respond(Reply, Answer), over(Answer, Running);
        {'Write', _, _, WriteReply} -> respond(WriteReply, Answer), over(Answer, Running);
        {'Give', Owner} -> over(Answer, given_to(Owner, Running));
        {'DOWN', MonitorRef, process, _, _} -> exit({ern, killed});
        _ -> over(Answer, Running)
    end.

%% Report §6.9, Appendix E.23: the program's owner from now on, watched in
%% place of the one before; a process that has ended is watched as one
%% that ends at once.
given_to(Owner, #{monitor_ref := MonitorRef} = Running) ->
    erlang:demonitor(MonitorRef, [flush]),
    Running#{monitor_ref := erlang:monitor(process, Owner)}.

%% The helper's port closed, which ends the helper and kills the program if
%% it runs. The monitor of its owner stays.
stop(#{helper := Helper}) ->
    try erlang:port_close(Helper) catch error:badarg -> closed end.

%% The last answer while the program counts as a source, given before the
%% count ends, so that no deadlock is found between the two (report §8.6).
answered(Reply, Answer) ->
    respond(Reply, Answer),
    ern_rt:source_end().

%% An answer, or the caller faulted where the runtime failed.
respond(Reply, {fault, Cause}) -> ern_rt:refuse(Reply, Cause);
respond(Reply, Answer) -> ern_rt:answer(Reply, Answer).

%% The program's owner died: the program is killed with
%% this process, which ends as a killed process does.
killed(Running) ->
    stop(Running),
    ern_rt:source_end(),
    exit({ern, killed}).

%% Report Appendix E.23: why a program did not start, by the error's name
%% the helper sends; a path through something that is no directory finds
%% no program.
not_started(<<"enotdir">>) -> 'NotFound';
not_started(Name) -> ern_io:helper_error(Name).

%% Report Appendix E.23: what the host says of the program as it starts, as
%% the helper run with no program writes it back, `Os.Host(user,
%% environment)` in declared field order: the user it runs as, which the
%% host has no word for, and the environment byte for byte, since the host
%% decodes a value that is not UTF-8 without a sign. Each value is its
%% bytes, which Os.environment decodes when it is asked for.
%% The mask the program creates files under comes in the same run, and is
%% kept (umask/0).
-spec host() -> {'Host', non_neg_integer(), #{binary() => binary()}}.
host() ->
    Helper = try open([])
             catch error:_ -> host_failed()
             end,
    receive
        {Helper, {data, <<"u", User:32>>}} ->
            receive
                {Helper, {data, <<"m", Mask:32>>}} ->
                    persistent_term:put({?MODULE, umask}, Mask),
                    {'Host', User, variables(Helper, #{})};
                {Helper, {exit_status, _}} -> host_failed()
            end;
        {Helper, {exit_status, _}} -> host_failed()
    end.

%% Report Appendix E.17: the program's file mode creation mask, which the
%% host has no word for, as the helper read it when the host was read,
%% and read so where it has not been. It is kept for the program's life,
%% since it is the process's own, set before the program starts, and
%% nothing the runtime runs changes it.
-spec umask() -> non_neg_integer().
umask() ->
    case persistent_term:get({?MODULE, umask}, none) of
        none ->
            _ = host(),
            persistent_term:get({?MODULE, umask});
        Mask ->
            Mask
    end.

%% Report Appendix E.23, §8.5: the helper failed as the host was read,
%% which ends the program before `main` runs.
host_failed() ->
    {fault, Cause} = helper_failed(),
    ern_rt:fault(Cause).

%% Report Appendix E.23: a name that occurs twice keeps its first value, and
%% each value is kept as its bytes, decoded when it is asked for. A name that
%% is not UTF-8 is none a String can ask for, and is not kept.
variables(Helper, Environment) ->
    receive
        {Helper, {data, <<"v", Variable/binary>>}} ->
            variables(Helper, variable(binary:split(Variable, <<"=">>), Environment));
        {Helper, {data, <<"x", _/binary>>}} ->
            receive
                {Helper, {exit_status, _}} -> Environment
            end;
        {Helper, {exit_status, _}} ->
            host_failed()
    end.

variable([Name, Value], Environment) ->
    case is_map_key(Name, Environment) orelse not ern_fs:is_utf8(Name) of
        true -> Environment;
        false -> Environment#{Name => Value}
    end;
variable([_], Environment) ->
    Environment.

%% Report Appendix E.23, §7.4: the directory the program was started in,
%% absolute, whose name ern has found UTF-8 before starting (report §11):
%% decoded where the host's names are UTF-8, and its bytes where they are
%% bytes. One the host can no longer read, removed since, faults the
%% binding with the host's reason.
-spec working_directory() -> binary().
working_directory() ->
    case file:get_cwd() of
        {ok, Dir} -> ern_fs:name_bytes(Dir);
        {error, Error} ->
            ern_rt:fault(iolist_to_binary(["the working directory cannot be read: ",
                                           atom_to_list(Error)]))
    end.
