%% Report §8.2, Appendix E.23: the process behind Os's reference, the
%% process behind each program Os.start or Os.startTerminal starts, and the
%% program's environment. A program's process owns the port of ern_exec
%% (c_src/ern_exec.c), the helper that runs the program, under a
%% pseudo-terminal for Os.startTerminal, and asks the helper for a piece of
%% the program's output only for a read that waits, so that a program no
%% one reads waits on its output. Every frame for the helper goes through
%% the program's writer, a process of its own, which the host holds at a
%% port that takes no more, so that the program's process takes its
%% requests, its kill among them, while a write is given the helper. A read
%% and a write each wait their own milliseconds (E.0 shape rule 8), and a
%% read without a time, a ReadForever, waits with no deadline and no timer.
%%
%% The program runs until it exits, until its process is killed, since the
%% port closing ends the helper, or until its owner dies (E.23). Its
%% process lives on after the exit, as a socket's does after its close,
%% until it is killed or its owner dies. A running program is a source
%% (report §8.6) from its start until it has exited or been killed.
-module(ern_os).

-export([loop/0, input/5, signal/2, locked/2, node_signaled/3, job_locked/1,
         signal_number/1, host/0, umask/0, working_directory/0]).

%% The most bytes an `i` frame carries after its tag: the host writes a
%% frame's length, its tag among it, in 4 bytes, and cuts a longer one.
-define(INPUT_MOST, 16#FFFFFFFE).

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
%% The host's facts are read from a port, and a job's lock waited for at
%% one, each a wait inside foreign code for the look (host/0,
%% job_locked/1); the working directory is the host's file server's, whose
%% functions the look reads on top of the process's stack as the host's
%% work.
-receives({foreign_wait, [host_read/1, variables/2, job_lock_answer/1]}).
-receives({own_process, [serve/1, spawn_program/5, signal/2, locked/2, node_signaled/3,
                         ended/1, starting/3, running/4, over/2, writing/1]}).

%% Report Appendix E.23: a running program's own, beside the reads that
%% wait and what the helper owes them (running/4): the helper's port, the
%% writer that gives it every frame (writing/1), its owner and the owner's
%% monitor, the inputs the helper has yet to answer
%% and the timers of the writes still waiting, the signals and the resizes
%% it has been asked for and has yet to answer, whether the program runs
%% under a terminal, which a resize needs, whether `closeInput` has ended
%% its input, and the replies of the closes that wait for the terminal's
%% hangup, newest first.
-record(program, {helper :: port(), writer :: pid(), owner :: pid(), monitor_ref :: reference(),
                  writes :: queue:queue(), timers = #{} :: #{term() => reference()},
                  asked = queue:new() :: queue:queue(), terminal :: boolean(),
                  input_closed = false :: boolean(), hangups = [] :: [term()]}).

%% A read waiting: its reply, the reference of its caller's monitor and its
%% timer, the read named to both by its place among the reads (read/6), and
%% `none` for the timer of a read without a time.
-record(read, {reply, monitor_ref :: reference(), timer :: reference() | none}).

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
%% cannot be made, and the start answers `Left(Other("error:system_limit"))`,
%% this process living on.
%%
%% Report §7.4, Appendix E.23: the process traps exits, so that its
%% helper's port, which is linked to it, ending with a reason of the
%% host's, a write to the helper's closed pipe among them, is the helper's
%% failure and not the process's end; a kill, the program's end and the
%% end of a process it is linked to end it with their reason, the program
%% with it, as they would have. The host never holds it at the port, which
%% its writer writes to (writing/1), so it takes each of them at once.
%% Report §6.5, §8.4: a fault sent it, a fault in an adapted address's
%% function or a bad message's, which it has no wait of Ernest's to meet,
%% ends it as a kill does, with the fault's end (ern_rt:fault_ended/1).
spawn_program(Os, Command, Kind, Owner, Reply) ->
    try erlang:spawn(fun() ->
                         link(Os),
                         process_flag(trap_exit, true),
                         receive go -> start(Command, Kind, Owner, Reply) end
                     end) of
        Pid ->
            ern_rt:opened(Pid, site(Kind), Owner),
            ern_rt:source_begin(Pid),
            Pid ! go
    catch
        error:system_limit -> ern_rt:answer(Reply, {'Left', ern_io:limited()})
    end.

site(pipes) -> <<"Os.start">>;
site({terminal, _}) -> <<"Os.startTerminal">>.

%% Command is `Command(program, arguments, input, environment,
%% workingDirectory)`, its fields in their declared order (report §3.5),
%% its environment `Inherited(variables)` or `Only(variables)`, and Kind
%% `pipes`, or `{terminal, Size}` with Size `Terminal.Size(rows,
%% columns)`. Report Appendix E.23: what the host cannot take, and a count
%% of rows or columns it cannot take, are `Left(Invalid)`. Report §12.5,
%% §12, Appendix E.23: a host that holds as many ports as its limit, or as
%% many files as the operating system's, refuses the helper's, and the
%% start answers that refusal in the host's words, as Tcp answers its own;
%% any other failure to open the helper is the helper's. Report §7.4,
%% §12.5: the program's writer is made with the helper's port, and where
%% the host's table of processes is full, the start answers as one whose
%% process cannot be made, the port closed.
start({'Command', Program, Arguments, Input, Environment, {'Path', Directory}}, Kind, Owner,
      Reply) ->
    {_, Variables} = Environment,
    case is_taken(Program, Arguments, Variables, Directory) andalso is_size_taken(Kind) of
        false ->
            ern_rt:end_source(Reply, {'Left', 'Invalid'});
        true ->
            try open(helper_arguments(Kind)) of
                Helper ->
                    case writer(Helper) of
                        {ok, Writer} ->
                            ern_rt:writes_through(Writer),
                            %% the command comes as the first frames, not on
                            %% the helper's command line, so that an argument
                            %% too long for the host is the program's failure
                            %% to start
                            lists:foreach(fun(Frame) -> give(Writer, Frame) end,
                                          environment_frames(Environment)),
                            give(Writer, <<"p", Directory/binary>>),
                            Parts = << <<Part/binary, 0>> || Part <- [Program | Arguments] >>,
                            give(Writer, <<"c", Parts/binary>>),
                            wait_for_start(Helper, Writer, Input, Kind =/= pipes, Directory, Owner,
                                           Reply);
                        limited ->
                            erlang:port_close(Helper),
                            ern_rt:end_source(Reply, {'Left', ern_io:limited()})
                    end
            catch
                error:Limit when Limit =:= system_limit; Limit =:= emfile; Limit =:= enfile ->
                    Error = ern_io:host_error(Limit, fun file:format_error/1),
                    ern_rt:end_source(Reply, {'Left', Error});
                error:_ ->
                    ern_rt:end_source(Reply, helper_failed())
            end
    end.

%% Report Appendix E.23: what reaches a program as the host takes it: the
%% name, each argument, each variable's value and the directory without
%% U+0000, the directory besides not empty, and each variable's name not
%% empty and without `=`.
is_taken(Program, Arguments, Variables, Directory) ->
    Directory =/= <<>> andalso lists:all(fun is_word/1, [Program, Directory | Arguments])
        andalso lists:all(fun({Name, Value}) ->
                              Name =/= <<>> andalso binary:match(Name, <<"=">>) =:= nomatch
                                  andalso is_word(Name) andalso is_word(Value)
                          end, Variables).

%% Report Appendix E.23: the helper's frames of the program's environment:
%% under `Only` first the frame that empties the helper's own, which holds
%% the environment `ern` was started in, and then a frame for each variable
%% to set, in order, so that the last of two with one name stands.
environment_frames({'Inherited', Variables}) ->
    variable_frames(Variables);
environment_frames({'Only', Variables}) ->
    [<<"o">> | variable_frames(Variables)].

variable_frames(Variables) ->
    [<<"v", Name/binary, "=", Value/binary>> || {Name, Value} <- Variables].

is_word(Word) ->
    binary:match(Word, <<0>>) =:= nomatch.

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

open(Arguments) ->
    erlang:open_port({spawn_executable, helper()},
                     [{args, Arguments}, {packet, 4}, binary, exit_status]).

%% Report Appendix E.23: a running program's writer, a process of its own
%% that gives the helper each frame in the order the program's process
%% gives them (give/2): the command's, each input, each signal and resize,
%% the end of the input and each read's ask. The host holds the writer, and
%% not the program's process, at a port that takes no more. It is linked to
%% the program's process and does not trap exits, so that the process's
%% end ends it, held at the port among the ways; a process that lives on
%% ends it first (stop/1).
writer(Helper) ->
    try erlang:spawn_link(fun() -> writing(Helper) end) of
        Writer -> {ok, Writer}
    catch
        error:system_limit -> limited
    end.

writing(Helper) ->
    receive
        {frame, Frame} ->
            command(Helper, Frame),
            writing(Helper)
    end.

%% A frame for the helper, given the program's writer.
give(Writer, Frame) ->
    Writer ! {frame, Frame},
    ok.

%% The program's input given, its owner watched, and the helper's word on
%% its start waited for.
wait_for_start(Helper, Writer, Input, Terminal, Directory, Owner, Reply) ->
    %% the input given at the start is answered by the helper as a write is,
    %% with no one waiting for it
    Writes = input(Writer, Input, ?INPUT_MOST, none, queue:new()),
    MonitorRef = erlang:monitor(process, Owner),
    starting(#program{helper = Helper, writer = Writer, owner = Owner, monitor_ref = MonitorRef,
                      writes = Writes, terminal = Terminal}, Directory, Reply).

%% Report Appendix E.23: a write's bytes given the helper as `i` frames in
%% order, through Writer, the program's writer, each its tag and at most
%% Most of the bytes, parts of them that the runtime does not copy; and an
%% entry added to Writes for each frame, which the helper answers: `none`
%% for each but the last, whose answer answers no one, and Last, the
%% write's, for the last. The runtime gives Most as ?INPUT_MOST, the
%% longest a frame of the host's can be.
-spec input(pid(), binary(), pos_integer(), term(), queue:queue()) -> queue:queue().
input(Writer, Bytes, Most, Last, Writes) when byte_size(Bytes) > Most ->
    <<Part:Most/binary, Rest/binary>> = Bytes,
    give(Writer, [$i, Part]),
    input(Writer, Rest, Most, Last, queue:in(none, Writes));
input(Writer, Bytes, _Most, Last, Writes) ->
    give(Writer, [$i, Bytes]),
    queue:in(Last, Writes).

%% Report §7.4, Appendix E.23: the helper's failure is the runtime's own,
%% which faults the caller that meets it.
-spec helper_failed() -> {fault, binary()}.
helper_failed() ->
    {fault, <<"the runtime's helper ern_exec failed">>}.

%% The helper beside the runtime's modules: build/runtime/priv/ern_exec, which
%% runs Os's programs, holds and signals a node's ernest.pid (§12.5) and
%% holds a job's lock (§11.9).
-spec helper() -> file:filename().
helper() ->
    filename:join([filename:dirname(code:which(?MODULE)), "..", "priv", "ern_exec"]).

%% Report §12.5: the signal Number sent by the helper to the operating
%% system's process of the process number given, which the host has no
%% word for: `sent`, `none` where no such process lives, `others` where
%% it lives and is another user's, or `failed` where the helper ended
%% without saying, killed among it; the signal 0 sends nothing, and asks
%% whether the process lives. A helper the host cannot start, its table of
%% ports full, raises as open_port/2 does.
-spec signal(non_neg_integer(), pos_integer()) -> sent | none | others | failed.
signal(Number, ProcessNumber) ->
    Port = open_port({spawn_executable, helper()},
                     [{args, ["signal", integer_to_list(Number), integer_to_list(ProcessNumber)]},
                      exit_status]),
    receive
        {Port, {exit_status, 0}} -> sent;
        {Port, {exit_status, 1}} -> none;
        {Port, {exit_status, 2}} -> others;
        {Port, {exit_status, _}} -> failed
    end.

%% Report §12.5: a node's `ernest.pid` locked by the helper, which writes
%% ProcessNumber into it as its whole content, holds the lock until the
%% process of that number has ended, however it ends, and then removes the
%% file before it lets the lock go. The calling process owns the helper's
%% port, whose close at the host's halt lets nothing go.
%%
%% `locked`, or `{held, Text}` where a living node holds the file, Text the
%% number it holds, or empty where it holds none, `unopened` where its name
%% reaches no regular file, which the helper does not open (§11),
%% `{unwatched, Host}` where the host cannot watch a process for its end,
%% Host its system's name and release, and the helper makes no file, or
%% `{failed, Text}`, the words for what stopped the helper.
-spec locked(file:filename(), pos_integer()) ->
          locked | {held, binary()} | unopened | {unwatched, binary()} | {failed, string()}.
locked(PidFile, ProcessNumber) ->
    Helper = open(["lock", PidFile, integer_to_list(ProcessNumber)]),
    receive
        {Helper, {data, <<"l">>}} -> locked;
        {Helper, {data, <<"h", Text/binary>>}} -> ended(Helper), {held, Text};
        {Helper, {data, <<"k", Host/binary>>}} -> ended(Helper), {unwatched, Host};
        {Helper, {data, <<"f", Name/binary>>}} -> ended(Helper), {failed, error_text(Name)};
        {Helper, {exit_status, 9}} -> unopened;
        {Helper, {exit_status, _}} -> {failed, helper_failed_text()}
    end.

%% Report §12.5, §11.2: the signal Number sent by the helper to the node that
%% holds the lock on PidFile, the process the file names, and where Wait is
%% true, the node's end waited for, on its lock, which the node's helper
%% lets go once the node's process has ended (locked/2): `sent`; `no_file`;
%% `unopened` where its name reaches no regular file, which the helper does
%% not open (§11); `no_node` where no node holds the file; `no_process`
%% where the file names none; `none` where the process it names has ended;
%% `others` where that process is another user's; or `{failed, Text}`, a
%% file that is not this user's own among the ways, the superuser's to
%% another user and another user's to the superuser, whose number names no
%% node of this user's, since another user wrote it. The file's mode is not
%% tested.
-spec node_signaled(file:filename(), non_neg_integer(), boolean()) ->
          sent | no_file | unopened | no_node | no_process | none | others | {failed, string()}.
node_signaled(PidFile, Number, Wait) ->
    Helper = open(["node", PidFile, integer_to_list(Number) | ["wait" || Wait]]),
    receive
        {Helper, {data, <<"f", Name/binary>>}} -> ended(Helper), {failed, error_text(Name)};
        {Helper, {exit_status, 0}} -> sent;
        {Helper, {exit_status, 1}} -> no_file;
        {Helper, {exit_status, 9}} -> unopened;
        {Helper, {exit_status, 2}} -> no_node;
        {Helper, {exit_status, 3}} -> no_process;
        {Helper, {exit_status, 4}} -> none;
        {Helper, {exit_status, 5}} -> others;
        {Helper, {exit_status, 8}} ->
            {failed, "is another user's, and names no node of this user's"};
        {Helper, {exit_status, _}} -> {failed, helper_failed_text()}
    end.

%% Report §11.9: a job's lock on the file at Path, which the helper opens
%% for writing, through no link, making it where it is absent with the bits
%% the mask leaves of 0666 (Appendix E.17), and locks whole for writing,
%% waiting in the host while another holds it, as a second run of the job
%% waits. The helper holds the lock until its port closes, and leaves the
%% file. The calling process owns the port, so that the lock goes when that
%% process ends. Report §8.6: the wait is at a port, which the look cannot
%% see deliver.
%%
%% `locked`, `unopened` where the name names what is neither a regular file
%% nor a link, which the helper does not open (§11), or `{failed, Text}`,
%% the words for what stopped the helper, a link at Path among them, in the
%% host's words. A helper the host cannot start, its table of ports full,
%% raises as open_port/2 does.
-spec job_locked(file:filename_all()) -> locked | unopened | {failed, string()}.
job_locked(Path) ->
    Helper = open(["hold", Path]),
    ern_rt:entered_foreign(),
    try job_lock_answer(Helper) after ern_rt:left_foreign() end.

job_lock_answer(Helper) ->
    receive
        {Helper, {data, <<"l">>}} -> locked;
        {Helper, {data, <<"f", Name/binary>>}} -> ended(Helper), {failed, error_text(Name)};
        {Helper, {exit_status, 9}} -> unopened;
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
starting(#program{helper = Helper} = Running, Directory, Reply) ->
    receive
        {Helper, {data, <<"s">>}} ->
            ern_rt:answer(Reply, {'Right', erlang:self()}),
            running(Running, gb_trees:empty(), 0, queue:new());
        {Helper, {data, <<"f", Name/binary>>}} ->
            stop(Running),
            %% report Appendix E.23: the host's reason, a path through
            %% something that is no directory finding no program
            %% (ern_io:host_error/2)
            ern_rt:end_source(Reply, {'Left', ern_io:helper_error(Name)});
        {Helper, {data, <<"p", Name/binary>>}} ->
            stop(Running),
            ern_rt:end_source(Reply, {'Left', directory_error(Directory, Name)});
        {Helper, {data, <<"t", Name/binary>>}} ->
            stop(Running),
            ern_rt:end_source(Reply, {'Left', no_terminal(Name)});
        {Helper, {exit_status, _}} ->
            stop(Running),
            ern_rt:end_source(Reply, helper_failed());
        {'EXIT', Helper, _} ->
            stop(Running),
            ern_rt:end_source(Reply, helper_failed());
        {'EXIT', _, normal} ->
            starting(Running, Directory, Reply);
        {'EXIT', _, ExitReason} ->
            ended_with(Running, ExitReason);
        {'$ern_fault', Thrown} ->
            ended_with(Running, ern_rt:fault_ended(Thrown));
        {'DOWN', _, process, _, _} ->
            die_with_owner(Running)
    end.

%% Waiting: the reads that wait, each a #read{} by its place, oldest first,
%% so that a read whose time passes or whose caller ends is found by its
%% place, which its timer and its caller's `DOWN` carry. Owed: the
%% pieces the helper owes, one asked for each read that came with nothing
%% kept. Kept: the answers the helper gave while no read waited, which the
%% next reads take, in order. The helper sends one piece of output for
%% each piece it was asked for, and the exit status once the program has
%% exited and both its outputs have ended, which it can learn only while a
%% piece is owed.
%%
%% Report Appendix E.23: a read answers `Left(Timeout)` when its
%% milliseconds pass, the program running on, and the piece asked for it is
%% the next read's; a ReadForever is a read without a time, which waits
%% with no deadline and no timer; a read whose caller has ended before it
%% is answered is dropped, and the piece asked for it is the next read's
%% the same way. The caller's end is known by its `DOWN`, and before a
%% piece is answered by asking the host whether the caller lives
%% (given/5). E.0 shape rule 8: a read given no time has run out as it
%% begins, whatever has arrived, and takes nothing; a write given no time
%% has too, and gives the program nothing.
%%
%% A write is answered when the helper says the program has taken its
%% bytes, `a`, or dropped them, `d`, one for each input in order, each
%% input's entry kept in the program's `writes`: the write's reply for its
%% last frame, and `none` for a frame whose answer answers no one (input/5).
%% A write still waiting has its timer in the program's `timers` by its
%% reply, so that its time passing finds it there; `Left(Timeout)` answers
%% it first, which does not undo it, and takes it from `timers`, the
%% helper's answer then answering no one. A write after `closeInput`
%% answers `Left(Closed)` at once, and gives the helper nothing. A request
%% answered lets go of its timer, and a read of its caller's monitor.
%%
%% A signal and a resize are answered when the helper says it sent the
%% signal or set the size, `g`, or that the program had exited or, for a
%% resize, its terminal was hung up, `z`, one for each in order, the replies
%% kept in the program's `asked`: the program's process cannot know the
%% exit before the helper reads it, which a signal that reached nothing and
%% a size that told nothing must not hide (E.23).
%%
%% A `closeInput` answers once the close is made (E.23). Under pipes that is
%% once the end is given the writer, after every input before it, which the
%% helper takes in order, so it answers at once. Under a terminal it is the
%% hangup, which the helper says it has made, `h`, and a close that comes
%% while the hangup is owed waits for it too. One that comes once it is
%% made, and every one under pipes after the first, answers at once. The
%% closes still waiting are answered at the program's exit, and fault where
%% the helper fails.
running(#program{helper = Helper, writer = Writer, writes = Writes, timers = Timers,
                 asked = Asked, terminal = Terminal, input_closed = InputClosed,
                 hangups = Hangups, monitor_ref = MonitorRef} = Running, Waiting, Owed, Kept) ->
    receive
        {'Read', Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            running(Running, Waiting, Owed, Kept);
        {'Read', Ms, Reply} ->
            read(ern_rt:deadline(Ms), Reply, Running, Waiting, Owed, Kept);
        {'ReadForever', Reply} ->
            read(none, Reply, Running, Waiting, Owed, Kept);
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            running(Running, Waiting, Owed, Kept);
        {'Write', _, _, Reply} when InputClosed ->
            ern_rt:answer(Reply, {'Left', 'Closed'}),
            running(Running, Waiting, Owed, Kept);
        {'Write', Bytes, Ms, Reply} ->
            Writes1 = input(Writer, Bytes, ?INPUT_MOST, Reply, Writes),
            Timer = arm({write, Reply}, ern_rt:deadline(Ms)),
            running(Running#program{writes = Writes1, timers = Timers#{Reply => Timer}}, Waiting,
                    Owed, Kept);
        {Helper, {data, <<Tag>>}} when Tag =:= $a; Tag =:= $d ->
            {{value, Write}, Rest} = queue:out(Writes),
            running(answered_write(Write, written(Tag), Running#program{writes = Rest}), Waiting,
                    Owed, Kept);
        {'SendSignal', Signal, Reply} ->
            give(Writer, <<"k", (signal_number(Signal))>>),
            running(Running#program{asked = queue:in(Reply, Asked)}, Waiting, Owed, Kept);
        {Helper, {data, <<Tag>>}} when Tag =:= $g; Tag =:= $z ->
            {{value, Reply}, Rest} = queue:out(Asked),
            ern_rt:answer(Reply, made(Tag)),
            running(Running#program{asked = Rest}, Waiting, Owed, Kept);
        {'Resize', Size, Reply} ->
            case sizing(Size, Running) of
                sized ->
                    {'Size', Rows, Columns} = Size,
                    give(Writer, <<"w", Rows:16, Columns:16>>),
                    running(Running#program{asked = queue:in(Reply, Asked)}, Waiting, Owed,
                            Kept);
                Refused ->
                    ern_rt:answer(Reply, Refused),
                    running(Running, Waiting, Owed, Kept)
            end;
        %% report Appendix E.23: under a terminal the end of the input is
        %% the terminal's hangup, which the helper makes at once
        {'CloseInput', Reply} when InputClosed, Hangups =:= [] ->
            ern_rt:answer(Reply, 'Unit'),
            running(Running, Waiting, Owed, Kept);
        {'CloseInput', Reply} when InputClosed ->
            running(Running#program{hangups = [Reply | Hangups]}, Waiting, Owed, Kept);
        {'CloseInput', Reply} when Terminal ->
            give(Writer, <<"e">>),
            running(Running#program{input_closed = true, hangups = [Reply]}, Waiting, Owed, Kept);
        {'CloseInput', Reply} ->
            give(Writer, <<"e">>),
            ern_rt:answer(Reply, 'Unit'),
            running(Running#program{input_closed = true}, Waiting, Owed, Kept);
        {Helper, {data, <<"h">>}} ->
            hung_up(Hangups, 'Unit'),
            running(Running#program{hangups = []}, Waiting, Owed, Kept);
        {'Give', Owner} ->
            running(given_to(Owner, Running), Waiting, Owed, Kept);
        {Helper, {data, <<"x", Status:32>>}} ->
            %% the program has exited: what it was written meanwhile is
            %% dropped, and its exit status is the last answer
            stop(Running),
            unanswered(Running, {'Left', 'Closed'}),
            hung_up(Hangups, 'Unit'),
            given(Running, {'Right', {'Exited', Status}}, Waiting, Owed - 1, Kept);
        {Helper, {data, <<Tag, Bytes/binary>>}} ->
            given(Running, {'Right', piece(Tag, Bytes)}, Waiting, Owed - 1, Kept);
        {Helper, {exit_status, _}} ->
            failed(Running, Waiting);
        %% report Appendix E.23, §7.4: the helper's port ended by the host
        %% before the helper's exit status came, a write to its closed pipe
        %% among the ways: the helper failed
        {'EXIT', Helper, _} ->
            failed(Running, Waiting);
        {'EXIT', _, normal} ->
            running(Running, Waiting, Owed, Kept);
        {'EXIT', _, ExitReason} ->
            ended_with(Running, ExitReason);
        {'$ern_fault', Thrown} ->
            ended_with(Running, ern_rt:fault_ended(Thrown));
        {'DOWN', MonitorRef, process, _, _} ->
            die_with_owner(Running);
        {{read, Place}, _, process, _, _} ->
            running(Running, dropped(Place, Waiting), Owed, Kept);
        {timeout, _, {deadline, {write, Reply}, Deadline}} ->
            running(write_timed_out(Reply, Deadline, Running), Waiting, Owed, Kept);
        {timeout, _, {deadline, {read, Place}, Deadline}} ->
            running(Running, read_timed_out(Place, Deadline, Waiting), Owed, Kept)
    end.

%% A read, answered a piece kept for it, or else waiting until its
%% deadline, or without one; the helper is asked for a piece but where one
%% is owed to a read that has gone, which is this one's.
read(Deadline, Reply, #program{writer = Writer} = Running, Waiting, Owed, Kept) ->
    case queue:out(Kept) of
        {{value, Answer}, Rest} ->
            ern_rt:answer(Reply, Answer),
            running(Running, Waiting, Owed, Rest);
        {empty, _} ->
            Place = erlang:unique_integer([monotonic]),
            MonitorRef = erlang:monitor(process, ern_rt:reply_process(Reply),
                                        [{tag, {read, Place}}]),
            Timer = arm({read, Place}, Deadline),
            Waiting1 = gb_trees:insert(Place, #read{reply = Reply, monitor_ref = MonitorRef,
                                                    timer = Timer}, Waiting),
            case Owed > gb_trees:size(Waiting) of
                true -> running(Running, Waiting1, Owed, Kept);
                false -> give(Writer, <<"n">>), running(Running, Waiting1, Owed + 1, Kept)
            end
    end.

%% The helper ended with no status to send: it failed, and each write, each
%% read and each close waiting is answered so. Report Appendix E.28: the
%% program is no longer known to run, and the process is spent.
failed(#program{owner = Owner, hangups = Hangups} = Running, Waiting) ->
    stop(Running),
    unanswered(Running, helper_failed()),
    hung_up(Hangups, helper_failed()),
    ern_rt:source_end(),
    ern_rt:spent(Owner),
    lists:foreach(fun(Read) -> answered_read(Read, helper_failed()) end, gb_trees:values(Waiting)),
    over({failed, helper_failed()}, Running).

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
    lists:foreach(fun(Read) -> answered_read(Read, Answer) end, gb_trees:values(Waiting)),
    ern_rt:source_end(),
    ern_rt:spent(Owner),
    over({exited, queue:in(Answer, Kept)}, Running);
given(Running, Answer, Waiting, Owed, Kept) ->
    case gb_trees:is_empty(Waiting) of
        false ->
            {Place, #read{reply = Reply} = Read, Rest} = gb_trees:take_smallest(Waiting),
            case erlang:is_process_alive(ern_rt:reply_process(Reply)) of
                true ->
                    answered_read(Read, Answer),
                    running(Running, Rest, Owed, Kept);
                false ->
                    given(Running, Answer, dropped(Place, Waiting), Owed, Kept)
            end;
        true ->
            running(Running, Waiting, Owed, queue:in(Answer, Kept))
    end.

%% A read answered: its timer let go and its caller no longer watched. A
%% `DOWN` already on its way is not looked for among what waits in the
%% mailbox, which would cost as much as waits there: it comes, as a time
%% that has passed does, for a read that no longer waits, and does
%% nothing (dropped/2, read_timed_out/3).
answered_read(#read{reply = Reply, monitor_ref = MonitorRef, timer = Timer}, Answer) ->
    ern_rt:let_go(Timer),
    erlang:demonitor(MonitorRef),
    respond(Reply, Answer).

%% Report Appendix E.23: a read whose caller has ended before it was
%% answered is dropped, its timer let go and its caller no longer watched;
%% a piece the helper was asked for it is the next read's (given/5,
%% read/6). A caller's `DOWN` for a read no longer waiting does nothing.
dropped(Place, Waiting) ->
    case gb_trees:take_any(Place, Waiting) of
        {#read{monitor_ref = MonitorRef, timer = Timer}, Rest} ->
            ern_rt:let_go(Timer),
            erlang:demonitor(MonitorRef),
            Rest;
        error ->
            Waiting
    end.

%% A read of an exited program, answered the oldest of what is kept, and the
%% exit status, last, kept for the reads after it.
kept_read(Reply, Kept) ->
    {{value, Answer}, Rest} = queue:out(Kept),
    ern_rt:answer(Reply, Answer),
    case Answer of
        {'Right', {'Exited', _}} -> Kept;
        _ -> Rest
    end.

%% A time passed: a write's answers `Left(Timeout)` at once, where it still
%% waits, and takes it from the writes that wait, the helper's answer then
%% answering no one; a read's, where it still waits, answers it too and
%% takes it from the reads that wait. A wait longer than the host's longest
%% timer is armed again until it has passed (report §6.3).
write_timed_out(Reply, Deadline, #program{timers = Timers} = Running) ->
    case {Timers, ern_rt:remaining(Deadline)} of
        {#{Reply := _}, 0} ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            Running#program{timers = maps:remove(Reply, Timers)};
        {#{Reply := _}, _} ->
            Running#program{timers = Timers#{Reply := arm({write, Reply}, Deadline)}};
        _ ->
            Running
    end.

read_timed_out(Place, Deadline, Waiting) ->
    case {gb_trees:lookup(Place, Waiting), ern_rt:remaining(Deadline)} of
        {{value, #read{reply = Reply, monitor_ref = MonitorRef}}, 0} ->
            erlang:demonitor(MonitorRef),
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            gb_trees:delete(Place, Waiting);
        {{value, Read}, _} ->
            gb_trees:update(Place, Read#read{timer = arm({read, Place}, Deadline)}, Waiting);
        {none, _} ->
            Waiting
    end.

%% A request's timer, which names the request and its deadline; a read
%% without a time has none.
arm(_, none) ->
    none;
arm(Kind, Deadline) ->
    erlang:start_timer(ern_rt:remaining(Deadline), erlang:self(), {deadline, Kind, Deadline}).

%% An input the helper has answered for: a write's caller is answered and
%% its timer let go. One whose time had passed was answered then, and an
%% input that is not a write's last frame has no caller.
answered_write(none, _Answer, Running) ->
    Running;
answered_write(Reply, Answer, #program{timers = Timers} = Running) ->
    case maps:take(Reply, Timers) of
        {Timer, Rest} ->
            ern_rt:let_go(Timer),
            respond(Reply, Answer),
            Running#program{timers = Rest};
        error ->
            Running
    end.

%% A frame the writer gives the helper. A helper whose end has closed has
%% sent its exit status first, which ends the program, so a frame after it
%% is dropped.
command(Helper, Frame) ->
    try erlang:port_command(Helper, Frame) catch error:badarg -> closed end.

%% Report Appendix E.23: bytes the program took, and bytes dropped, given
%% after the end of its input or after it closed it.
written($a) -> {'Right', 'Unit'};
written($d) -> {'Left', 'Closed'}.

%% Report Appendix E.23, §8.6: the host's number for each signal Os.signal
%% names, as POSIX fixes it, the one table of them (ern_signals:number/1).
-spec signal_number('Termination' | 'Hangup' | 'Interrupt') -> pos_integer().
signal_number('Termination') -> 15;
signal_number('Hangup') -> 1;
signal_number('Interrupt') -> 2.

%% Report Appendix E.23: a signal sent or a size set, and one the program's
%% exit or its terminal's hangup left unmade.
made($g) -> {'Right', 'Unit'};
made($z) -> {'Left', 'Closed'}.

%% The writes, the signals and the resizes still waiting when the program
%% has ended: the writes' bytes are dropped, the signals sent nowhere and
%% the sizes set on nothing, and each is answered that the program is
%% closed, or why the runtime lost it.
unanswered(#program{timers = Timers, asked = Asked}, Answer) ->
    maps:foreach(fun(Reply, Timer) -> ern_rt:let_go(Timer), respond(Reply, Answer) end, Timers),
    lists:foreach(fun(Reply) -> respond(Reply, Answer) end, queue:to_list(Asked)).

%% Report Appendix E.23: the closes that waited for the terminal's hangup,
%% answered Answer in the order they came: `Unit` once it is made or the
%% program has exited, and the runtime's failure where the helper failed.
hung_up(Hangups, Answer) ->
    lists:foreach(fun(Reply) -> respond(Reply, Answer) end, lists:reverse(Hangups)).

piece($o, Bytes) -> {'Stdout', Bytes};
piece($r, Bytes) -> {'Stderr', Bytes}.

%% Report Appendix E.23: a resize's first two answers, in their order,
%% whatever the program's state, without the helper: a program `start`
%% started has no terminal, and answers `Left(NotATerminal)`, whatever the
%% size; a size the host cannot take answers `Left(Invalid)`. Any other
%% size is `sized`, the helper's to set or to answer `Left(Closed)`, once
%% the terminal is hung up or the program has exited, as a signal is.
sizing(_Size, #program{terminal = false}) ->
    {'Left', 'NotATerminal'};
sizing(Size, _Running) ->
    case is_size(Size) of
        true -> sized;
        false -> {'Left', 'Invalid'}
    end.

%% A resize once the helper has sent its last answer, the exit's or its
%% failure's: a size it would have set answers Answer, `Left(Closed)` or the
%% failure.
resize(Size, Reply, Running, Answer) ->
    case sizing(Size, Running) of
        sized -> respond(Reply, Answer);
        Refused -> ern_rt:answer(Reply, Refused)
    end.

%% Report Appendix E.23: a program past its last answer, whose process
%% lives on until it is killed or its owner dies, as a socket's does after
%% its close: Last is `{exited, Kept}` where the program has exited, and
%% `{failed, Answer}` where its helper failed. A read or a write given no
%% time answers `Left(Timeout)` either way (E.0 shape rule 8).
%%
%% Of a program that has exited, the reads take what is kept, in order, and
%% the exit status last, which stays for every read after it, a read
%% without a time among them; a write, a resize and a signal are answered
%% as to a program that has exited, and `closeInput` at once. Of one whose
%% helper failed, each read, write, signal and `closeInput` faults its
%% caller, a read without a time among them, and so does each resize of its
%% terminal whose size the host takes. The helper's port has ended, closed
%% as the exit came or as the helper failed, and whatever it ends with ends
%% nothing more.
over(Last, #program{helper = Helper, monitor_ref = MonitorRef} = Running) ->
    receive
        {'Read', Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            over(Last, Running);
        {'Write', _, Ms, Reply} when Ms =< 0 ->
            ern_rt:answer(Reply, {'Left', 'Timeout'}),
            over(Last, Running);
        {'Read', _, Reply} ->
            over(last_read(Reply, Last), Running);
        {'ReadForever', Reply} ->
            over(last_read(Reply, Last), Running);
        {'Write', _, _, Reply} ->
            respond(Reply, last_answer(Last, {'Left', 'Closed'})),
            over(Last, Running);
        {'SendSignal', _, Reply} ->
            respond(Reply, last_answer(Last, {'Left', 'Closed'})),
            over(Last, Running);
        {'CloseInput', Reply} ->
            respond(Reply, last_answer(Last, 'Unit')),
            over(Last, Running);
        {'Resize', Size, Reply} ->
            resize(Size, Reply, Running, last_answer(Last, {'Left', 'Closed'})),
            over(Last, Running);
        {'Give', Owner} ->
            over(Last, given_to(Owner, Running));
        %% its owner died, which kills it
        {'DOWN', MonitorRef, process, _, _} ->
            exit({ern, killed});
        {'EXIT', Helper, _} ->
            over(Last, Running);
        {'EXIT', _, normal} ->
            over(Last, Running);
        {'EXIT', _, ExitReason} ->
            exit(ExitReason);
        %% report §6.5, Appendix E.23: a fault ends it as a kill does
        {'$ern_fault', Thrown} ->
            exit(ern_rt:fault_ended(Thrown));
        _ ->
            over(Last, Running)
    end.

%% What a request past the program's last answer is answered: Exited, as
%% a program that has exited answers it, or the helper's failure.
last_answer({exited, _}, Exited) -> Exited;
last_answer({failed, Answer}, _) -> Answer.

%% A read past the program's last answer: what is kept, or the failure.
last_read(Reply, {exited, Kept}) ->
    {exited, kept_read(Reply, Kept)};
last_read(Reply, {failed, Answer} = Failed) ->
    respond(Reply, Answer),
    Failed.

%% Report §6.9, Appendix E.23: the program's owner from now on, watched in
%% place of the one before; a process that has ended is watched as one
%% that ends at once.
given_to(Owner, #program{monitor_ref = MonitorRef} = Running) ->
    erlang:demonitor(MonitorRef, [flush]),
    Running#program{owner = Owner, monitor_ref = erlang:monitor(process, Owner)}.

%% The program's writer ended and the helper's port closed, which ends the
%% helper and kills the program if it runs: the writer first, so that it
%% gives the helper nothing more, ended where the host holds it at the port
%% too, since it does not trap exits. The monitor of its owner stays.
stop(#program{helper = Helper, writer = Writer}) ->
    ern_rt:stop(Writer),
    try erlang:port_close(Helper) catch error:badarg -> closed end.

%% An answer, or the caller faulted where the runtime failed.
respond(Reply, {fault, Cause}) -> ern_rt:refuse(Reply, Cause);
respond(Reply, Answer) -> ern_rt:answer(Reply, Answer).

%% The program's owner died: the program is killed with this process,
%% which ends as a killed process does.
-spec die_with_owner(#program{}) -> no_return().
die_with_owner(Running) ->
    stop(Running),
    ern_rt:source_end(),
    exit({ern, killed}).

%% Report §6.9, §8.6: the process killed, ended with the program, or ended
%% with a process it is linked to, which it takes as a message since it
%% traps exits: the program is killed with it, and it ends with that
%% reason, as it would have without the trap. Report §6.5, Appendix E.23:
%% so too where a fault ends it, with the fault's end.
-spec ended_with(#program{}, term()) -> no_return().
ended_with(Running, ExitReason) ->
    stop(Running),
    exit(ExitReason).

%% Report Appendix E.23: why the program's terminal could not be opened, by
%% the error's name the helper sends, a reason of the host's for which the
%% program is neither missing nor denied.
no_terminal(Name) ->
    case ern_io:helper_reason(Name) of
        Error when is_atom(Error) -> ern_io:other(Error, fun file:format_error/1);
        Words -> {'Other', Words}
    end.

%% Report Appendix E.23, E.17: a working directory the helper could not
%% enter, the directory and the answer Fs gives for its path on one line,
%% by the error's name the helper sends; a path that names something other
%% than a directory answers NotAFile, as Fs.list answers it, where the host
%% says enotdir of it and of a path through a file alike.
directory_error(Directory, <<"enotdir">>) ->
    ern_io:path_error(Directory, case file:read_file_info(Directory, [raw]) of
                                     {ok, _} -> 'NotAFile';
                                     _ -> 'NotFound'
                                 end);
directory_error(Directory, Name) ->
    ern_io:path_error(Directory, ern_io:helper_error(Name)).

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
        {ok, Directory} -> ern_fs:name_bytes(Directory);
        {error, Error} ->
            ern_rt:fault(iolist_to_binary(["the working directory cannot be read: ",
                                           atom_to_list(Error)]))
    end.
