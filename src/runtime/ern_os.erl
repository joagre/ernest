%% Report §8.2, Appendix E.23: the process behind Os's reference, the
%% process behind each program Os.start or Os.startTerminal starts, and the
%% program's environment. A program's process owns the port of ern_exec
%% (c_src/ern_exec.c), the helper that runs the program, under a
%% pseudo-terminal for Os.startTerminal, and asks the helper for a piece of
%% the program's output only for a read that waits, so that a program no
%% one reads waits on its output. A read and a write each wait their own
%% milliseconds (E.0 shape rule 8).
%%
%% The program runs until it exits, until its process is killed, since the
%% port closing ends the helper, or until its owner dies (E.23). Its
%% process lives on after the exit, as a socket's does after its close,
%% until it is killed or its owner dies. A running program is a source
%% (report §8.6) from its start until it has exited or been killed.
-module(ern_os).

-export([loop/0, helper_failed/0, helper/0, signal/2, locked/2, node_signaled/3, host/0, user/0,
         umask/0, working_directory/0]).

%% Report §8.6: each receive that can wait, by its kind (docs/style.md).
%% The host's facts are read from a port, a wait inside foreign code for
%% the look (host/0); the working directory is the host's file server's,
%% whose functions the look reads on top of the process's stack as the
%% host's work. user/0 reads the user `ern` runs as from a port in a
%% process that is no program's: the job's, as a node starts or `ern
%% config` reads a directory, and the carrier's at a reload (§12.5).
-receives({foreign_wait, [host_read/1, variables/2]}).
-receives({own_process, [serve/1, spawn_program/5, signal/2, locked/2, node_signaled/3,
                         ended/1, starting/2, running/4, exited/2, over/2, user/0]}).

%% Report Appendix E.23: a running program's own, beside the reads that
%% wait and what the helper owes them (running/4): the helper's port, its
%% owner and the owner's monitor, the writes the helper has yet to answer,
%% whether it runs under a terminal, which a resize needs, and whether that
%% terminal is hung up.
-record(program, {helper :: port(), owner :: pid(), monitor_ref :: reference(),
                  writes :: queue:queue(), terminal :: boolean(), hung_up = false :: boolean()}).

%% A read waiting: its reply, the reference of its caller's monitor, which
%% names the read to its timer too, and its timer.
-record(read, {reply, monitor_ref :: reference(), timer :: reference()}).

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
            spawn_program(Os, Command, pipes, Owner, Reply),
            serve(Os);
        {'StartTerminal', Command, Size, Owner, Reply} ->
            spawn_program(Os, Command, {terminal, Size}, Owner, Reply),
            serve(Os);
        {'EXIT', Pid, _} ->
            ern_rt:forget_opened(Pid),
            serve(Os)
    end.

%% Report §6.9, Appendix E.23: the program's process, its site the function
%% that started it, known to the runtime before it starts the program.
%% Report §7.4, §12.5: where the host's table of processes is full, it
%% cannot be made, and the caller faults with the host's class and reason,
%% `Fault("error:system_limit")`, this process living on.
spawn_program(Os, Command, Kind, Owner, Reply) ->
    try erlang:spawn(fun() ->
                         link(Os),
                         receive go -> start(Command, Kind, Owner, Reply) end
                     end) of
        Pid ->
            ern_rt:opened(Pid, site(Kind), Owner),
            ern_rt:source_begin(Pid),
            Pid ! go
    catch
        error:system_limit -> ern_rt:refuse(Reply, ern_rt:host_cause(error, system_limit))
    end.

site(pipes) -> <<"Os.start">>;
site({terminal, _}) -> <<"Os.startTerminal">>.

%% Command is `Command(program, arguments, input)`, its fields in their
%% declared order (report §3.5), and Kind `pipes`, or `{terminal, Size}`
%% with Size `Terminal.Size(rows, columns)`. Report Appendix E.23: a word
%% that holds U+0000, and a count of rows or columns the host cannot take,
%% are `Left(Invalid)`. Report §12.5, Appendix E.23: a host that holds as
%% many ports as its limit refuses the helper's, and the start answers that
%% refusal in the host's words, as Tcp answers its own; any other failure
%% to open the helper is the helper's.
start({'Command', Program, Arguments, Input}, Kind, Owner, Reply) ->
    case lists:any(fun(Word) -> binary:match(Word, <<0>>) =/= nomatch end, [Program | Arguments])
         orelse not is_size_taken(Kind) of
        true ->
            end_source(Reply, {'Left', 'Invalid'});
        false ->
            try open(helper_arguments(Kind)) of
                Helper ->
                    %% the command comes as the first frame, not on the
                    %% helper's command line, so that an argument too long
                    %% for the host is the program's failure to start
                    Parts = << <<Part/binary, 0>> || Part <- [Program | Arguments] >>,
                    command(Helper, <<"c", Parts/binary>>),
                    wait_for_start(Helper, Input, Kind =/= pipes, Owner, Reply)
            catch
                error:system_limit ->
                    end_source(Reply, {'Left', ern_io:host_error(system_limit,
                                                                 fun file:format_error/1)});
                error:_ ->
                    end_source(Reply, helper_failed())
            end
    end.

%% Whether the host takes the size a kind of run begins with: a run under
%% pipes has none.
is_size_taken(pipes) -> true;
is_size_taken({terminal, Size}) -> is_size(Size).

%% Report Appendix E.23: a size the host takes, each count from 0 to 65535.
is_size({'Size', Rows, Columns}) ->
    Rows >= 0 andalso Rows =< 65535 andalso Columns >= 0 andalso Columns =< 65535.

helper_arguments(pipes) ->
    ["run"];
helper_arguments({terminal, {'Size', Rows, Columns}}) ->
    ["terminal", integer_to_list(Rows), integer_to_list(Columns)].

open(Args) ->
    erlang:open_port({spawn_executable, helper()},
                     [{args, Args}, {packet, 4}, binary, exit_status]).

%% The program's input given, its owner watched, and the helper's word on
%% its start waited for.
wait_for_start(Helper, Input, Terminal, Owner, Reply) ->
    command(Helper, <<"i", Input/binary>>),
    MonitorRef = erlang:monitor(process, Owner),
    %% the input given at the start is answered by the helper as a write is,
    %% with no one waiting for it
    Writes = queue:in(none, queue:new()),
    starting(#program{helper = Helper, owner = Owner, monitor_ref = MonitorRef, writes = Writes,
                      terminal = Terminal}, Reply).

%% Report §7.4, Appendix E.23: the helper's failure is the runtime's own,
%% which faults the caller that meets it.
-spec helper_failed() -> {fault, binary()}.
helper_failed() ->
    {fault, <<"the runtime's helper ern_exec failed">>}.

%% The helper beside the runtime's modules: build/runtime/priv/ern_exec, which
%% runs Os's programs and holds and signals a node's ernest.pid (§12.5).
-spec helper() -> file:filename().
helper() ->
    filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "ern_exec"]).

%% Report §12.5: the signal Number sent by the helper to the operating
%% system's process of the process number given, which the host has no
%% word for: `sent`, `none` where no such process lives, or `others` where
%% it lives and is another user's; the signal 0 sends nothing, and asks
%% whether the process lives.
-spec signal(non_neg_integer(), pos_integer()) -> sent | none | others.
signal(Number, ProcessNumber) ->
    Port = open_port({spawn_executable, helper()},
                     [{args, ["signal", integer_to_list(Number), integer_to_list(ProcessNumber)]},
                      exit_status]),
    receive
        {Port, {exit_status, 0}} -> sent;
        {Port, {exit_status, 1}} -> none;
        {Port, {exit_status, 2}} -> others
    end.

%% Report §12.5: a node's `ernest.pid` locked by the helper for the node's
%% life, which writes ProcessNumber into it as its whole content. The
%% calling process owns the helper's port, which the host closes with the
%% node however it ends, and the lock goes then, and not before. `locked`,
%% or `{held, Text}` where a living node holds the file, Text the number it
%% holds, or empty where it holds none, or `{failed, Text}`, the words for
%% what stopped the helper.
-spec locked(file:filename(), pos_integer()) ->
          locked | {held, binary()} | {failed, string()}.
locked(PidFile, ProcessNumber) ->
    Helper = open(["lock", PidFile, integer_to_list(ProcessNumber)]),
    receive
        {Helper, {data, <<"l">>}} -> locked;
        {Helper, {data, <<"h", Text/binary>>}} -> ended(Helper), {held, Text};
        {Helper, {data, <<"f", Name/binary>>}} -> ended(Helper), {failed, error_text(Name)};
        {Helper, {exit_status, _}} -> {failed, helper_failed_text()}
    end.

%% Report §12.5, §11.2: the signal Number sent by the helper to the node that
%% holds the lock on PidFile, the process the file names, and where Wait is
%% true, the node's end waited for, on its lock, which the host lets go
%% when the node ends: `sent`; `no_file`; `no_node` where no node holds the
%% file; `no_process` where the file names none; `none` where the process
%% it names has ended; `others` where that process is another user's; or
%% `{failed, Text}`, a file that is another user's or that others than its
%% owner may write among the ways, whose number names no node of this
%% user's, since another could have written it.
-spec node_signaled(file:filename(), non_neg_integer(), boolean()) ->
          sent | no_file | no_node | no_process | none | others | {failed, string()}.
node_signaled(PidFile, Number, Wait) ->
    Helper = open(["node", PidFile, integer_to_list(Number) | ["wait" || Wait]]),
    receive
        {Helper, {data, <<"f", Name/binary>>}} -> ended(Helper), {failed, error_text(Name)};
        {Helper, {exit_status, 0}} -> sent;
        {Helper, {exit_status, 1}} -> no_file;
        {Helper, {exit_status, 2}} -> no_node;
        {Helper, {exit_status, 3}} -> no_process;
        {Helper, {exit_status, 4}} -> none;
        {Helper, {exit_status, 5}} -> others;
        {Helper, {exit_status, 8}} ->
            {failed, "is another user's, and names no node of this user's"};
        {Helper, {exit_status, 9}} -> {failed, "may be written by others than its owner"};
        {Helper, {exit_status, _}} -> {failed, helper_failed_text()}
    end.

%% Until the helper has ended, its last frame read.
ended(Helper) ->
    receive {Helper, {exit_status, _}} -> ok end.

%% The words for an error the helper names (ern_io:helper_reason/1).
error_text(Name) ->
    case ern_io:helper_reason(Name) of
        Error when is_atom(Error) -> file:format_error(Error);
        Words -> binary_to_list(Words)
    end.

helper_failed_text() ->
    {fault, Cause} = helper_failed(),
    binary_to_list(Cause).

%% Until the helper says whether the program started, the Start is
%% answered by nothing else, and nothing else knows the process. Report
%% Appendix E.23: a start waits for the helper alone, and is not bounded.
starting(#program{helper = Helper} = Running, Reply) ->
    receive
        {Helper, {data, <<"s">>}} ->
            ern_rt:answer(Reply, {'Right', erlang:self()}),
            running(Running, queue:new(), 0, queue:new());
        {Helper, {data, <<"f", Name/binary>>}} ->
            stop(Running),
            %% report Appendix E.23: the host's reason, a path through
            %% something that is no directory finding no program
            %% (ern_io:host_error/2)
            end_source(Reply, {'Left', ern_io:helper_error(Name)});
        {Helper, {data, <<"t", Name/binary>>}} ->
            stop(Running),
            end_source(Reply, {'Left', no_terminal(Name)});
        {Helper, {exit_status, _}} ->
            stop(Running),
            end_source(Reply, helper_failed());
        {'DOWN', _, process, _, _} ->
            die_with_owner(Running)
    end.

%% Waiting: the reads that wait, oldest first, each a #read{}. Owed: the
%% pieces the helper owes, one asked for each read that came with nothing
%% kept. Kept: the answers the helper gave while no read waited, which the
%% next reads take, in order. The helper sends one piece of output for
%% each piece it was asked for, and the exit status once the program has
%% exited and both its outputs have ended, which it can learn only while a
%% piece is owed.
%%
%% Report Appendix E.23: a read answers `Left(Timeout)` when its
%% milliseconds pass, the program running on, and the piece asked for it is
%% the next read's; a read whose caller has ended before it is answered is
%% dropped, and the piece asked for it is the next read's the same way. The
%% caller's end is known by its `DOWN`, and before a piece is answered by
%% asking the host whether the caller lives (given/5). E.0 shape rule 8: a
%% read given no time has run out as it begins, whatever has arrived, and
%% takes nothing; a write given no time has too, and gives the program
%% nothing.
%%
%% A write is answered when the helper says the program has taken its
%% bytes, `a`, or dropped them, `d`, one for each input in order, the
%% replies kept in the program's `writes`, each {Reply, Timer}, or
%% `Left(Timeout)` first, which does not undo it and leaves `none` in its
%% place. A request answered lets go of its timer, and a read of its
%% caller's monitor.
running(#program{helper = Helper, writes = Writes} = Running, Waiting, Owed, Kept) ->
    receive
        {'Read', Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            running(Running, Waiting, Owed, Kept);
        {'Read', Ms, Reply} ->
            read(Ms, Reply, Running, Waiting, Owed, Kept);
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            running(Running, Waiting, Owed, Kept);
        {'Write', Bytes, Ms, Reply} ->
            command(Helper, <<"i", Bytes/binary>>),
            Timer = arm({write, Reply}, ern_rt:deadline(Ms)),
            running(Running#program{writes = queue:in({Reply, Timer}, Writes)}, Waiting, Owed,
                    Kept);
        {Helper, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d ->
            {{value, Write}, Rest} = queue:out(Writes),
            answered_write(Write, written(Tag)),
            running(Running#program{writes = Rest}, Waiting, Owed, Kept);
        {'Resize', Size, Reply} ->
            resize(Size, Reply, Running, sized),
            running(Running, Waiting, Owed, Kept);
        %% report Appendix E.23: under a terminal the end of the input is
        %% the terminal's hangup, which the helper makes at once
        'CloseInput' ->
            command(Helper, <<"e">>),
            running(Running#program{hung_up = Running#program.terminal}, Waiting, Owed, Kept);
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
        {'DOWN', MonitorRef, process, _, _} when MonitorRef =:= Running#program.monitor_ref ->
            die_with_owner(Running);
        {'DOWN', MonitorRef, process, _, _} ->
            running(Running, dropped(MonitorRef, Waiting), Owed, Kept);
        {timeout, _, {deadline, {write, Reply}, Deadline}} ->
            Rest = write_timed_out(Reply, Deadline, Writes),
            running(Running#program{writes = Rest}, Waiting, Owed, Kept);
        {timeout, _, {deadline, {read, Ref}, Deadline}} ->
            running(Running, read_timed_out(Ref, Deadline, Waiting), Owed, Kept)
    end.

%% A read, answered a piece kept for it, or else waiting; the helper is
%% asked for a piece but where one is owed to a read that has gone, which
%% is this one's.
read(Ms, Reply, #program{helper = Helper} = Running, Waiting, Owed, Kept) ->
    case queue:out(Kept) of
        {{value, Answer}, Rest} ->
            ern_rt:answer(Reply, Answer),
            running(Running, Waiting, Owed, Rest);
        {empty, _} ->
            MonitorRef = erlang:monitor(process, ern_rt:reply_process(Reply)),
            Timer = arm({read, MonitorRef}, ern_rt:deadline(Ms)),
            Waiting1 = queue:in(#read{reply = Reply, monitor_ref = MonitorRef, timer = Timer},
                                Waiting),
            case Owed > queue:len(Waiting) of
                true -> running(Running, Waiting1, Owed, Kept);
                false -> command(Helper, <<"n">>), running(Running, Waiting1, Owed + 1, Kept)
            end
    end.

%% The helper ended with no status to send: it failed, and each write and
%% each read waiting is answered so. Report Appendix E.28: the program is
%% no longer known to run, and the process is spent.
failed(#program{owner = Owner} = Running, Waiting) ->
    stop(Running),
    unwritten(Running, helper_failed()),
    ern_rt:source_end(),
    ern_rt:spent(Owner),
    lists:foreach(fun(Read) -> answered_read(Read, helper_failed()) end, queue:to_list(Waiting)),
    over(helper_failed(), Running).

%% An answer of the helper's, to the oldest read that waits, or kept for the
%% next read where none does. The exit status is the last answer, given to
%% every read that waits, since the helper sends nothing more, and kept for
%% every read to come; the reads that wait have it before the program's
%% count as a source ends, as end_source/2 says.
%%
%% Report Appendix E.23: a piece goes to a read whose caller lives as it is
%% answered. A caller's `DOWN` comes after its end, ordered with nothing the
%% port sends, so the host is asked first, of a caller of this node, since
%% the program's address is bound to it (report §3.11); a read whose caller
%% has ended is dropped as its `DOWN` would drop it, and the piece goes to
%% the next. Report Appendix E.28: once the program has exited, the process
%% is spent.
given(#program{owner = Owner} = Running, {'Right', {'Exited', _}} = Answer, Waiting, _Owed,
      Kept) ->
    lists:foreach(fun(Read) -> answered_read(Read, Answer) end, queue:to_list(Waiting)),
    ern_rt:source_end(),
    ern_rt:spent(Owner),
    exited(queue:in(Answer, Kept), Running);
given(Running, Answer, Waiting, Owed, Kept) ->
    case queue:out(Waiting) of
        {{value, #read{reply = Reply, monitor_ref = MonitorRef} = Read}, Rest} ->
            case erlang:is_process_alive(ern_rt:reply_process(Reply)) of
                true ->
                    answered_read(Read, Answer),
                    running(Running, Rest, Owed, Kept);
                false ->
                    given(Running, Answer, dropped(MonitorRef, Waiting), Owed, Kept)
            end;
        {empty, _} ->
            running(Running, Waiting, Owed, queue:in(Answer, Kept))
    end.

%% A read answered: its timer let go and its caller no longer watched.
answered_read(#read{reply = Reply, monitor_ref = MonitorRef, timer = Timer}, Answer) ->
    let_go(Timer),
    erlang:demonitor(MonitorRef, [flush]),
    respond(Reply, Answer).

%% Report Appendix E.23: a read whose caller has ended before it was
%% answered is dropped, its timer let go and its caller no longer watched,
%% a `DOWN` on its way among it; a piece the helper was asked for it is the
%% next read's (given/5, read/6).
dropped(MonitorRef, Waiting) ->
    {value, #read{timer = Timer}, Rest} =
        lists:keytake(MonitorRef, #read.monitor_ref, queue:to_list(Waiting)),
    let_go(Timer),
    erlang:demonitor(MonitorRef, [flush]),
    queue:from_list(Rest).

%% Report Appendix E.23: the program has exited, and its process lives on,
%% as a socket's does after its close, until it is killed or its owner
%% dies. The reads take what is kept, in order, and the exit status last,
%% which stays for every read after it, a read given no time excepted; a
%% write and a resize are answered as to a program that has exited, a
%% write given no time excepted, and `closeInput` does nothing.
exited(Kept, #program{monitor_ref = MonitorRef} = Running) ->
    receive
        {'Read', Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            exited(Kept, Running);
        {'Read', _, Reply} ->
            {{value, Answer}, Rest} = queue:out(Kept),
            ern_rt:answer(Reply, Answer),
            case Answer of
                {'Right', {'Exited', _}} -> exited(Kept, Running);
                _ -> exited(Rest, Running)
            end;
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            exited(Kept, Running);
        {'Write', _, _, Reply} ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            exited(Kept, Running);
        {'Resize', Size, Reply} ->
            resize(Size, Reply, Running, {'Left', 'Closed'}),
            exited(Kept, Running);
        {'Give', Owner} ->
            exited(Kept, given_to(Owner, Running));
        {'DOWN', MonitorRef, process, _, _} ->
            %% its owner died, which kills it
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

read_timed_out(MonitorRef, Deadline, Waiting) ->
    queue:from_list(lists:append([case Read of
                                      #read{monitor_ref = MonitorRef} ->
                                          expired_read(Read, Deadline);
                                      _ ->
                                          [Read]
                                  end || Read <- queue:to_list(Waiting)])).

expired_read(#read{reply = Reply, monitor_ref = MonitorRef} = Read, Deadline) ->
    case ern_rt:remaining(Deadline) of
        0 ->
            erlang:demonitor(MonitorRef, [flush]),
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            [];
        _ ->
            [Read#read{timer = arm({read, MonitorRef}, Deadline)}]
    end.

%% A request's timer, which names the request and its deadline.
arm(Kind, Deadline) ->
    erlang:start_timer(ern_rt:remaining(Deadline), erlang:self(), {deadline, Kind, Deadline}).

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
unwritten(#program{writes = Writes}, Answer) ->
    lists:foreach(fun(Write) -> answered_write(Write, Answer) end, queue:to_list(Writes)).

piece($o, Bytes) -> {'Stdout', Bytes};
piece($r, Bytes) -> {'Stderr', Bytes}.

%% Report Appendix E.23: a resize's answers, in their order, whatever the
%% program's state, each but the size's answered here, without the helper:
%% a program `start` started has no terminal, and answers
%% `Left(NotATerminal)`, whatever the size; a size the host cannot take
%% answers `Left(Invalid)`; once the terminal is hung up or the program has
%% exited, `Left(Closed)`, as a write answers; and once the helper has
%% failed, its failure. Answer is the last of these the program's state
%% gives, or `sized`, where the size goes to the helper, a port that has
%% closed dropping it, and the resize answers `Right(Unit)`.
resize(_Size, Reply, #program{terminal = false}, _Answer) ->
    ern_rt:answer(Reply, {'Left', 'NotATerminal'});
resize(Size, Reply, Running, Answer) ->
    case {is_size(Size), Running, Answer} of
        {false, _, _} ->
            ern_rt:answer(Reply, {'Left', 'Invalid'});
        {true, #program{hung_up = true}, sized} ->
            ern_rt:answer(Reply, {'Left', 'Closed'});
        {true, #program{helper = Helper}, sized} ->
            {'Size', Rows, Columns} = Size,
            command(Helper, <<"w", Rows:16, Columns:16>>),
            ern_rt:answer(Reply, {'Right', 'Unit'});
        {true, _, _} ->
            respond(Reply, Answer)
    end.

%% A program whose helper failed: each read and write to come faults its
%% caller, one given no time excepted, and each resize of its terminal
%% whose size the host takes. Its owner may still die first, which ends
%% this process as it would have ended the program.
over(Answer, #program{monitor_ref = MonitorRef} = Running) ->
    receive
        {'Read', Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            over(Answer, Running);
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            over(Answer, Running);
        {'Read', _, Reply} -> respond(Reply, Answer), over(Answer, Running);
        {'Write', _, _, WriteReply} -> respond(WriteReply, Answer), over(Answer, Running);
        {'Resize', Size, ResizeReply} ->
            resize(Size, ResizeReply, Running, Answer),
            over(Answer, Running);
        {'Give', Owner} -> over(Answer, given_to(Owner, Running));
        {'DOWN', MonitorRef, process, _, _} -> exit({ern, killed});
        _ -> over(Answer, Running)
    end.

%% Report §6.9, Appendix E.23: the program's owner from now on, watched in
%% place of the one before; a process that has ended is watched as one
%% that ends at once.
given_to(Owner, #program{monitor_ref = MonitorRef} = Running) ->
    erlang:demonitor(MonitorRef, [flush]),
    Running#program{owner = Owner, monitor_ref = erlang:monitor(process, Owner)}.

%% The helper's port closed, which ends the helper and kills the program if
%% it runs. The monitor of its owner stays.
stop(#program{helper = Helper}) ->
    try erlang:port_close(Helper) catch error:badarg -> closed end.

%% The program's end as a source, its last answer given before its count
%% ends, so that no deadlock is found between the two (report §8.6).
end_source(Reply, Answer) ->
    respond(Reply, Answer),
    ern_rt:source_end().

%% An answer, or the caller faulted where the runtime failed.
respond(Reply, {fault, Cause}) -> ern_rt:refuse(Reply, Cause);
respond(Reply, Answer) -> ern_rt:answer(Reply, Answer).

%% The program's owner died: the program is killed with this process,
%% which ends as a killed process does.
die_with_owner(Running) ->
    stop(Running),
    ern_rt:source_end(),
    exit({ern, killed}).

%% Report Appendix E.23: why the program's terminal could not be opened, by
%% the error's name the helper sends, a reason of the host's for which the
%% program is neither missing nor denied.
no_terminal(Name) ->
    case ern_io:helper_reason(Name) of
        Error when is_atom(Error) -> ern_io:other(Error, fun file:format_error/1);
        Words -> {'Other', Words}
    end.

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
    ern_rt:entered_foreign(),
    try host_read(Helper) after ern_rt:left_foreign() end.

host_read(Helper) ->
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

%% Report §12.5: the user `ern` runs as, which the host has no word for, as
%% the helper run with `user` writes it back, and nothing else: a node
%% checks its directory by it as it starts and at each reload. The helper's
%% failure faults, as host/0's does.
-spec user() -> non_neg_integer().
user() ->
    Helper = try open(["user"])
             catch error:_ -> host_failed()
             end,
    receive
        {Helper, {data, <<"u", User:32>>}} ->
            receive
                {Helper, {exit_status, _}} -> User
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
%% which ends the program before `main` runs, or as the user was read for
%% a node (user/0, §12.5).
-spec host_failed() -> no_return().
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
