%% The machines of test/machines/machines.txt (plan, MVP 3.27 item 1),
%% read, reached and checked before any node starts on them, and the steps
%% of test/machines/nodes.sh over them: `check`, each machine's commit,
%% `ern --version` and floor against this checkout's; `pull`, each clone
%% pulled and built, the only writes to a clone; `start`, a bare node on
%% each machine listening on 8654, every node listing every other and a
%% shell's directory on this machine that lists them all; `stop`; and
%% `status`. `make bench-machines` reads the machines here too
%% (ern_node_costs, ern_code_costs). Each step says what failed, naming the
%% machine, and ends with status 1.
-module(ern_machines).

-export([main/1, reported/1, ready/1, machines/1, local/1, remote/1, closed/1]).

%% The file, from test/, where the tools run.
-define(MACHINES, "machines/machines.txt").
%% The connections' sockets, under test/ (ern_machine:open/2).
-define(SOCKETS, "build/ssh").
%% Where `start` makes its nodes' directories: this machine's under test/,
%% and another's of the same name under its directory (ern_machine:directory/2).
-define(NODES, "build/machines").
%% Report §11.3: the port `ern config` writes in `listen`, which `start`'s
%% nodes keep, one on each machine, as the deployment guide's do.
-define(PORT, 8654).

%% A step of test/machines/nodes.sh, its machines read from the file and
%% reached, and checked first but for `pull`, which pulls and builds the
%% clones a check would refuse, and checks them after.
-spec main([string()]) -> no_return().
main([Step]) ->
    reported(fun() ->
                 Machines = reached(?MACHINES),
                 try
                     Step =:= "pull" orelse checked(Machines),
                     step(Step, Machines)
                 after closed(Machines)
                 end
             end),
    halt(0).

step("check", _) -> ok;
step("pull", Machines) -> pulled(Machines);
step("start", Machines) -> started(Machines);
step("stop", Machines) -> stopped(Machines);
step("status", Machines) -> status(Machines).

%% Fun run; where it fails as the machines' tools fail (ern_machine:fail/1),
%% its line said on standard error, and the host ended with status 1.
-spec reported(fun(() -> Value)) -> Value.
reported(Fun) ->
    try Fun()
    catch throw:{failed, Text} ->
        io:format(standard_error, "machines: ~ts~n", [Text]),
        halt(1)
    end.

%%
%% The file
%%

%% The machines File lists, each reached, and checked against this one
%% (checked/1), before anything else is done on them.
-spec ready(file:filename()) -> [ern_machine:machine()].
ready(File) ->
    Machines = reached(File),
    checked(Machines),
    Machines.

%% The machines File lists, an ssh connection opened to each other one, all
%% at once.
reached(File) ->
    [ern_machine:opened(Opening)
     || Opening <- [ern_machine:open(Machine, ?SOCKETS) || Machine <- machines(File)]].

%% The machines File lists, reaching none: a line each, of words, a name,
%% a host, and the clone and the directory, or `local` for this machine;
%% `#` begins a comment. Exactly one line is this machine's.
-spec machines(file:filename()) -> [ern_machine:machine()].
machines(File) ->
    Text = case file:read_file(File) of
               {ok, Bytes} -> unicode:characters_to_list(Bytes);
               {error, Error} ->
                   ern_machine:fail(File ++ ": " ++ file:format_error(Error))
           end,
    Lines = [string:lexemes(hd(string:split(Line, "#")), " \t")
             || Line <- string:split(Text, "\n", all)],
    Machines = [machine(File, Words) || Words <- Lines, Words =/= []],
    length([Machine || Machine <- Machines, ern_machine:is_local(Machine)]) =:= 1
        orelse ern_machine:fail(File ++ " names this machine, a line whose third word is"
                                " `local`, other than once"),
    Machines.

machine(_, [Name, Host, "local"]) ->
    ern_machine:machine(Name, Host, local, none);
machine(File, [Name, Host, Clone, Directory] = Words) ->
    lists:all(fun(Path) -> filename:pathtype(Path) =:= absolute end, [Clone, Directory])
        orelse ern_machine:fail(File ++ ": the clone and the directory are absolute paths: "
                                ++ lists:join(" ", Words)),
    ern_machine:machine(Name, Host, Clone, Directory);
machine(File, Words) ->
    ern_machine:fail(File ++ ": a line is a name, a host, and a clone and a directory or"
                     " `local`: " ++ lists:join(" ", Words)).

%% This machine.
-spec local([ern_machine:machine()]) -> ern_machine:machine().
local(Machines) ->
    hd([Machine || Machine <- Machines, ern_machine:is_local(Machine)]).

%% The other machines, in the file's order.
-spec remote([ern_machine:machine()]) -> [ern_machine:machine()].
remote(Machines) ->
    [Machine || Machine <- Machines, not ern_machine:is_local(Machine)].

-spec closed([ern_machine:machine()]) -> ok.
closed(Machines) ->
    lists:foreach(fun ern_machine:closed/1, Machines).

%%
%% check
%%

%% Report §8.7: a node of a development build connects only to a node of
%% the same build, its floor the digest of its code. Each machine's commit,
%% version text, OTP release and floor, read side by side, and said; a
%% machine that is not built, whose clone holds a change no commit does,
%% or that stands on another floor than this one, fails the check, naming
%% it, since no node of it would connect to this one's.
checked(Machines) ->
    Facts = side_by_side(fun facts/1, Machines),
    Local = maps:get(floor, facts_of(local(Machines), Machines, Facts)),
    lists:foreach(
      fun({Machine, Of}) ->
          io:format("~s, ~s: ~s~n", [ern_machine:name(Machine), ern_machine:host(Machine),
                                     described(Of)]),
          ern_machine:is_local(Machine) orelse maps:get(changed, Of) =:= "0"
              orelse ern_machine:fail(ern_machine:name(Machine) ++ "'s clone, "
                                      ++ ern_machine:clone(Machine) ++ ", has changes no"
                                      " commit holds, and only git pull and make write"
                                      " there")
      end, lists:zip(Machines, Facts)),
    Other = [{Machine, Of} || {Machine, Of} <- lists:zip(Machines, Facts),
                              maps:get(floor, Of) =/= Local],
    Other =:= []
        orelse ern_machine:fail(
                 io_lib:format("~s stand~s on another floor than ~s, and no node there would"
                               " connect to one here (report §8.7); test/machines/nodes.sh"
                               " pull pulls and builds each clone at origin's main",
                               [lists:join(" and ", [ern_machine:name(Machine)
                                                     || {Machine, _} <- Other]),
                                [$s || length(Other) =:= 1],
                                ern_machine:name(local(Machines))])),
    ok.

facts_of(Machine, Machines, Facts) ->
    {_, Of} = lists:keyfind(Machine, 1, lists:zip(Machines, Facts)),
    Of.

%% The facts of the machine's tree, a line each: its commit, the files git
%% tracks that differ from it, whether it is built, its version text, and
%% its floor and its OTP release; fails naming the machine where it holds
%% no clone or is not built.
facts(Machine) ->
    Clone = ern_machine:quoted(ern_machine:clone(Machine)),
    Eval = "{ok, Otp} = file:read_file(filename:join([code:root_dir(), \"releases\","
           " erlang:system_info(otp_release), \"OTP_VERSION\"])),"
           " io:format(\"floor ~s~notp ~s~n\", [ern_carrier:cookie(), string:trim(Otp)]),"
           " halt().",
    Command = lists:flatten(
                ["if ! test -e ", Clone, "/.git; then echo clone no; exit; fi; ",
                 "echo commit $(git -C ", Clone, " rev-parse --short=8 HEAD); ",
                 "echo changed $(git -C ", Clone, " status --porcelain --untracked-files=no",
                 " | wc -l); ",
                 "if test -f ", Clone, "/erl/shared/ebin/ern_tree.beam",
                 " && test -f ", Clone, "/build/stdlib/io.erc; then ",
                 "echo version $(", Clone, "/bin/ern --version) && ",
                 "erl -noshell -noinput -pa ", Clone, "/erl/*/ebin -eval ",
                 ern_machine:quoted(Eval), "; else echo built no; fi"]),
    Output = ern_machine:ran(Machine, Command),
    Facts = maps:from_list([{list_to_atom(Key), string:trim(Value)}
                            || Line <- string:split(Output, "\n", all),
                               [Key, Value] <- [string:split(Line, " ")]]),
    case Facts of
        #{clone := "no"} ->
            ern_machine:fail(ern_machine:name(Machine) ++ " holds no clone of the repository at "
                             ++ ern_machine:clone(Machine));
        #{built := "no"} ->
            ern_machine:fail(ern_machine:name(Machine) ++ "'s tree, "
                             ++ ern_machine:clone(Machine) ++ ", is not built: "
                             ++ case ern_machine:is_local(Machine) of
                                    true -> "make at its top builds it";
                                    false -> "test/machines/nodes.sh pull builds it"
                                end);
        #{commit := _, changed := _, version := _, floor := _, otp := _} ->
            Facts;
        _ ->
            ern_machine:fail("on " ++ ern_machine:name(Machine) ++ ", the tree could not be"
                             " read: " ++ string:trim(Output))
    end.

described(#{commit := Commit, changed := Changed, version := Version, otp := Otp,
            floor := Floor}) ->
    io_lib:format("~s~s, ~s, OTP ~s, the floor ~s",
                  [Commit, [" with changes no commit holds" || Changed =/= "0"], Version, Otp,
                   string:slice(Floor, 0, 12)]).

%% Fun applied to each of Items, each in a process of its own, answering
%% in Items' order; where one fails as the tools fail, the first such
%% failure is this one's.
side_by_side(Fun, Items) ->
    Self = self(),
    Workers = [spawn_monitor(fun() -> Self ! {self(), catch_failed(Fun, Item)} end)
               || Item <- Items],
    Answers = [receive
                   {Pid, Answer} -> erlang:demonitor(MonitorRef, [flush]), Answer;
                   {'DOWN', MonitorRef, process, Pid, Reason} -> {crashed, Reason}
               end || {Pid, MonitorRef} <- Workers],
    case [Text || {failed, Text} <- Answers] of
        [Text | _] -> ern_machine:fail(Text);
        [] -> [case Answer of
                   {ok, Value} -> Value;
                   {crashed, Reason} -> erlang:error(Reason)
               end || Answer <- Answers]
    end.

catch_failed(Fun, Item) ->
    try {ok, Fun(Item)}
    catch throw:{failed, Text} -> {failed, Text}
    end.

%%
%% pull
%%

%% Each other machine's clone pulled from origin, fast-forward only, and
%% built by a make at its top, side by side, each said with its time; then
%% the machines checked again.
pulled(Machines) ->
    Pulled = side_by_side(
               fun(Machine) ->
                   Clone = ern_machine:quoted(ern_machine:clone(Machine)),
                   Started = erlang:monotonic_time(millisecond),
                   _ = ern_machine:ran(Machine, "git -C " ++ Clone ++ " pull --ff-only && make -C "
                                                ++ Clone),
                   {Machine, erlang:monotonic_time(millisecond) - Started}
               end, remote(Machines)),
    [io:format("~s: pulled and built in ~.1f s~n", [ern_machine:name(Machine), Ms / 1000])
     || {Machine, Ms} <- Pulled],
    checked(Machines).

%%
%% start, stop and status
%%

%% A bare node on each machine, listening on the port `ern config` writes,
%% each listing every other with the address it is dialed at, and a
%% shell's directory on this machine, which lists them all and which each
%% lists without an address, since a shell only dials (report §8.7, §11.2);
%% each node started apart from this run, with its two streams in a file
%% beside its directory, as the deployment guide's section 1.5 keeps a
%% node running without a service manager, and waited for until its port
%% answers.
started(Machines) ->
    [ern_machine_node:cleared(Machine, ern_machine:directory(Machine, ?NODES))
     || Machine <- Machines],
    Nodes = [ern_machine_node:configured(Machine, ern_machine:directory(Machine, ?NODES),
                                         ern_machine:name(Machine), ?PORT)
             || Machine <- Machines],
    Local = local(Machines),
    Shell = ern_machine_node:configured(Local, ern_machine:directory(Local, ?NODES), "shell",
                                        none),
    Addressed = [{Node, ern_machine_node:address(Node, ?PORT)} || Node <- Nodes],
    [ern_machine_node:listed(Node, [Peer || {Other, _} = Peer <- Addressed, Other =/= Node]
                                   ++ [{Shell, none}])
     || Node <- Nodes],
    ern_machine_node:listed(Shell, Addressed),
    Running = [{Node, detached(Node)} || Node <- Nodes],
    [answering(Node, Process) || {Node, Process} <- Running],
    io:format("a bare node listens on port ~B of each machine, ~s, its two streams in the"
              " file beside its directory~n"
              "a shell that lists them: ~s shell --config-dir ~s~n",
              [?PORT, lists:join(", ", [ern_machine:name(Machine) || Machine <- Machines]),
               ern_machine:ern(Local), ern_machine_node:config_dir(Shell)]).

%% Report §11.2: `ern run --config-dir dir` with no program, a bare node,
%% started on its machine apart from this run, its standard output and
%% standard error appended to `dir.log`; answers its process number.
detached(Node) ->
    Machine = ern_machine_node:machine(Node),
    Ern = ern_machine:quoted(ern_machine:ern(Machine)),
    ConfigDir = ern_machine:quoted(ern_machine_node:config_dir(Node)),
    Log = ern_machine:quoted(ern_machine_node:config_dir(Node) ++ ".log"),
    string:trim(ern_machine:ran(Machine, lists:flatten(["nohup ", Ern, " run --config-dir ",
                                                        ConfigDir, " >> ", Log,
                                                        " 2>&1 < /dev/null & echo $!"]))).

%% Report §8.7: a node listens only once its initializers have their
%% values, and where `listen` names a port says nothing of it, so what shows
%% that it listens is that its port answers, asked from here until it does.
%% A refusal comes at once, and the next ask waits as long as the node has
%% been waited for so far, at least the host timer's millisecond, as the
%% deployment tests' does (ern_deployment_tests:answering/1); at each
%% refusal the node's process is asked after on its machine, and a node
%% that has ended fails the start with what it wrote.
answering(Node, Process) ->
    Asked = erlang:monotonic_time(millisecond),
    answering(Node, Process, Asked).

answering(Node, Process, Asked) ->
    Machine = ern_machine_node:machine(Node),
    case gen_tcp:connect(ern_machine:host(Machine), ?PORT, [], infinity) of
        {ok, Socket} ->
            gen_tcp:close(Socket);
        {error, econnrefused} ->
            case ern_machine:run(Machine, "kill -0 " ++ Process) of
                {0, _} ->
                    Now = erlang:monotonic_time(millisecond),
                    receive after max(Now - Asked, 1) -> ok end,
                    answering(Node, Process, Asked);
                _ ->
                    Log = ern_machine_node:config_dir(Node) ++ ".log",
                    ern_machine:fail(io_lib:format(
                                       "the node on ~s ended before it listened, saying: ~ts",
                                       [ern_machine:name(Machine),
                                        ern_machine:ran(Machine,
                                                        "cat " ++ ern_machine:quoted(Log))]))
            end;
        {error, Error} ->
            ern_machine:fail(io_lib:format("~s:~B, the node on ~s, cannot be reached from here:"
                                           " ~s", [ern_machine:host(Machine), ?PORT,
                                                   ern_machine:name(Machine),
                                                   inet:format_error(Error)]))
    end.

%% Each machine's nodes stopped, and its directory of them removed, the
%% files of their two streams among it.
stopped(Machines) ->
    lists:foreach(
      fun(Machine) ->
          Dir = ern_machine:directory(Machine, ?NODES),
          case ern_machine_node:cleared(Machine, Dir) of
              [] -> io:format("~s: no node ran from ~s~n", [ern_machine:name(Machine), Dir]);
              Stopped -> [io:format("~s: the node of ~s stopped~n",
                                    [ern_machine:name(Machine), ConfigDir])
                          || ConfigDir <- Stopped]
          end
      end, Machines).

%% Report §8.7, §11.2: for each machine, whether a node holds its
%% `ernest.pid`, asked as `ern stop` asks with the signal 0, which sends
%% nothing, and the last line it wrote.
status(Machines) ->
    Said = side_by_side(fun held/1, Machines),
    [io:format("~s: ~ts~n", [ern_machine:name(Machine), Text])
     || {Machine, Text} <- lists:zip(Machines, Said)],
    ok.

held(Machine) ->
    ConfigDir = filename:join(ern_machine:directory(Machine, ?NODES), ern_machine:name(Machine)),
    PidFile = filename:join(ConfigDir, "ernest.pid"),
    Eval = lists:flatten(io_lib:format("io:format(\"~~p~~n\","
                                       " [ern_os:node_signaled(~p, 0, false)]), halt().",
                                       [PidFile])),
    Clone = ern_machine:quoted(ern_machine:clone(Machine)),
    Answer = string:trim(ern_machine:ran(Machine, "erl -noshell -noinput -pa " ++ Clone
                                                  ++ "/erl/*/ebin -eval "
                                                  ++ ern_machine:quoted(Eval))),
    case Answer of
        "sent" ->
            Number = string:trim(ern_machine:ran(Machine, "cat " ++ ern_machine:quoted(PidFile))),
            Log = ConfigDir ++ ".log",
            Last = ern_machine:ran(Machine, "tail -n 1 " ++ ern_machine:quoted(Log)),
            io_lib:format("the node ~s runs from ~s, ~ts",
                          [Number, ConfigDir, case string:trim(Last) of
                                                  "" -> "and has said nothing";
                                                  Line -> "and last said: " ++ Line
                                              end]);
        "no_file" ->
            "no node runs: " ++ PidFile ++ " is not there";
        Other ->
            io_lib:format("no node holds ~s: ~s", [PidFile, Other])
    end.
