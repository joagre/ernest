%% A machine that MVP 3.27's tools start nodes on (plan, MVP 3.27 item 1),
%% and what is done there: a command run and its output read, a
%% directory's files copied to it, and a command that runs on, a node or a
%% host, whose output a reader of its own keeps until it is waited for.
%% This machine's commands run in the plain shell; another's over ssh,
%% through one ssh connection held for the run, since an ssh connection's
%% own handshake costs 0.5 to 1.5 seconds to the user's machines, and a
%% session over a held one about 25 ms. test/machines/machines.txt lists
%% the machines (docs/development.md). Each wait here is bounded by the
%% harness's time for one wait (ern_nodes_tests:wait_ms/0) and is one step
%% of the test that runs it (ern_nodes_tests:step/1), but a command given a
%% bound of its own, `infinity` for one that runs as long as its work does,
%% a clone's build or a measuring program's run.
-module(ern_machine).

-export([local/0, machine/4, name/1, host/1, interface/1, is_local/1, clone/1, ern/1,
         directory/1, directory/2, open/2, opened/1, closed/1, run/2, run/3, ran/2, ran/3,
         load_average/1, copied/3, launched/2, seen/2, ended/1, answering/3, quoted/1, fail/1]).

%% A machine: its name, the host ssh and scp take and its peers dial, the
%% clone of the repository there, `local` for this machine's checkout, the
%% directory its nodes go in, the address their listeners bind, and the
%% ssh connection held to it, its port and its socket.
-record(machine, {name :: string(),
                  host :: string(),
                  clone :: local | string(),
                  directory :: none | string(),
                  interface :: string(),
                  ssh = none :: none | {port(), string()}}).

-opaque machine() :: #machine{}.
-export_type([machine/0]).

%% This machine, as `make bench` starts its nodes on it: reached and
%% listening on the loopback address alone.
-spec local() -> machine().
local() ->
    #machine{name = "this machine", host = "127.0.0.1", clone = local, directory = none,
             interface = "127.0.0.1"}.

%% A machine of test/machines/machines.txt, whose nodes listen on every
%% interface, since its peers dial it from other machines (report §8.7).
-spec machine(string(), string(), local | string(), none | string()) -> machine().
machine(Name, Host, Clone, Directory) ->
    #machine{name = Name, host = Host, clone = Clone, directory = Directory,
             interface = "0.0.0.0"}.

-spec name(machine()) -> string().
name(#machine{name = Name}) -> Name.

-spec host(machine()) -> string().
host(#machine{host = Host}) -> Host.

%% Report §8.7: the address a node's `listen` binds on the machine.
-spec interface(machine()) -> string().
interface(#machine{interface = Interface}) -> Interface.

-spec is_local(machine()) -> boolean().
is_local(#machine{clone = Clone}) -> Clone =:= local.

%% The toolchain's tree on the machine: this checkout, or the clone.
-spec clone(machine()) -> string().
clone(#machine{clone = local}) -> ern_tree:tree();
clone(#machine{clone = Clone}) -> Clone.

%% The launcher of the machine's tree.
-spec ern(machine()) -> string().
ern(Machine) ->
    filename:join(clone(Machine), "bin/ern").

%% The directory another machine's nodes go in; none for this machine,
%% whose go under this checkout.
-spec directory(machine()) -> none | string().
directory(#machine{directory = Directory}) -> Directory.

%% The directory on the machine for what this run keeps in the local
%% directory Dir: Dir itself on this machine, and on another its
%% directory's entry of the same name.
-spec directory(machine(), file:filename()) -> string().
directory(#machine{clone = local}, Dir) ->
    filename:absname(Dir);
directory(#machine{directory = Directory}, Dir) ->
    filename:join(Directory, filename:basename(Dir)).

%%
%% The ssh connection
%%

%% The ssh connection to another machine opened, its socket in the local
%% directory SocketDir under the machine's name and this host's process
%% number, so that two runs never share one, and not waited for
%% (opened/1), so that several open at once. It runs a command that ends
%% when its input does, which the host closes as it ends however it ends,
%% so that no ssh connection outlives the run.
-spec open(machine(), file:filename()) -> machine().
open(#machine{clone = local} = Machine, _) ->
    Machine;
open(#machine{name = Name, host = Host} = Machine, SocketDir) ->
    ok = filelib:ensure_path(SocketDir),
    Socket = filename:join(filename:absname(SocketDir), Name ++ "." ++ os:getpid() ++ ".ssh"),
    Port = open_port({spawn_executable, os:find_executable("ssh")},
                     [{args, ["-o", "BatchMode=yes", "-M", "-o", "ControlPath=" ++ Socket, Host,
                              "echo connected; exec cat > /dev/null"]},
                      binary, exit_status, stderr_to_stdout]),
    Machine#machine{ssh = {Port, Socket}}.

%% Once the ssh connection says it is open; fails naming the machine where
%% it ended first, with what ssh said.
-spec opened(machine()) -> machine().
opened(#machine{ssh = none} = Machine) ->
    Machine;
opened(#machine{ssh = {Port, _}} = Machine) ->
    ern_nodes_tests:step({opened, Machine#machine.name}),
    connected(Machine, Port, <<>>, deadline(ern_nodes_tests:wait_ms())).

connected(Machine, Port, Said, Deadline) ->
    case binary:match(Said, <<"connected\n">>) of
        nomatch ->
            receive
                {Port, {data, Bytes}} ->
                    connected(Machine, Port, <<Said/binary, Bytes/binary>>, Deadline);
                {Port, {exit_status, Status}} ->
                    fail(io_lib:format("~s, ~s, cannot be reached: ssh ended with status ~B: ~ts",
                                       [Machine#machine.name, Machine#machine.host, Status,
                                        string:trim(Said)]))
            after left(Deadline) ->
                fail(io_lib:format("~s, ~s, cannot be reached: ssh did not connect within"
                                   " ~B ms: ~ts", [Machine#machine.name, Machine#machine.host,
                                                   ern_nodes_tests:wait_ms(), string:trim(Said)]))
            end;
        _ ->
            Machine
    end.

%% The ssh connection closed, once ssh has ended it.
-spec closed(machine()) -> ok.
closed(#machine{ssh = none}) ->
    ok;
closed(#machine{name = Name, host = Host, ssh = {Port, Socket}} = Machine) ->
    _ = command(Machine, os:find_executable("ssh"),
                ["-o", "ControlPath=" ++ Socket, "-O", "exit", Host], ern_nodes_tests:wait_ms()),
    ern_nodes_tests:step({closed, Name}),
    receive
        {Port, {exit_status, _}} -> ok
    after ern_nodes_tests:wait_ms() ->
        fail(io_lib:format("the ssh connection to ~s did not end within ~B ms",
                           [Name, ern_nodes_tests:wait_ms()]))
    end.

%%
%% Commands
%%

%% The command run on the machine by its shell: its exit status, and what
%% it wrote to its standard output and its standard error together; one
%% that has not ended within its bound fails the run, naming the machine
%% and the command, and its port is closed.
-spec run(machine(), string()) -> {non_neg_integer(), string()}.
run(Machine, Command) ->
    run(Machine, Command, ern_nodes_tests:wait_ms()).

-spec run(machine(), string(), timeout()) -> {non_neg_integer(), string()}.
run(#machine{clone = local} = Machine, Command, Ms) ->
    command(Machine, "/bin/sh", ["-c", Command], Ms);
run(Machine, Command, Ms) ->
    command(Machine, os:find_executable("ssh"),
            ssh(Machine) ++ ["-n", Machine#machine.host, Command], Ms).

%% What the command wrote, where it ended with status 0; otherwise the run
%% fails, naming the machine, the command and what it wrote.
-spec ran(machine(), string()) -> string().
ran(Machine, Command) ->
    ran(Machine, Command, ern_nodes_tests:wait_ms()).

-spec ran(machine(), string(), timeout()) -> string().
ran(Machine, Command, Ms) ->
    case run(Machine, Command, Ms) of
        {0, Output} ->
            Output;
        {Status, Output} ->
            fail(io_lib:format("on ~s, `~ts` ended with status ~B: ~ts",
                               [Machine#machine.name, Command, Status, string:trim(Output)]))
    end.

%% The machine's load average of the last minute, as ern_measure reads it,
%% Linux's or the BSDs' and macOS's, and its processors.
-spec load_average(machine()) -> {string(), string()}.
load_average(Machine) ->
    Said = ran(Machine, "{ cat /proc/loadavg 2> /dev/null || sysctl -n vm.loadavg; }"
                        " && getconf _NPROCESSORS_ONLN"),
    [Average, Processors] = string:lexemes(Said, "\n"),
    {hd(string:lexemes(Average, "{ ")), Processors}.

%% The regular files of the local directory Dir on the machine, in a
%% directory of the same name under Base's (directory/2), which answers;
%% on this machine Dir itself.
-spec copied(machine(), file:filename(), file:filename()) -> string().
copied(#machine{clone = local}, Dir, _) ->
    filename:absname(Dir);
copied(#machine{name = Name, host = Host} = Machine, Dir, Base) ->
    Target = filename:join(directory(Machine, Base), filename:basename(Dir)),
    _ = ran(Machine, "mkdir -p " ++ quoted(Target)),
    Files = [filename:join(Dir, File) || File <- filelib:wildcard("*", Dir),
                                         filelib:is_regular(filename:join(Dir, File))],
    case command(Machine, os:find_executable("scp"),
                 ssh(Machine) ++ ["-q" | Files] ++ [Host ++ ":" ++ Target ++ "/"],
                 ern_nodes_tests:wait_ms()) of
        {0, _} -> Target;
        {Status, Output} ->
            fail(io_lib:format("the files of ~s could not be copied to ~s: scp ended with"
                               " status ~B: ~ts", [Dir, Name, Status, string:trim(Output)]))
    end.

ssh(#machine{ssh = {_, Socket}}) ->
    ["-o", "BatchMode=yes", "-o", "ControlMaster=no", "-o", "ControlPath=" ++ Socket].

%% Executable run on this machine with Args, for the machine named: its
%% status and what it wrote, within Ms; one step.
command(#machine{name = Name}, Executable, Args, Ms) ->
    ern_nodes_tests:step({command, Name, Args}),
    Port = open_port({spawn_executable, Executable},
                     [{args, Args}, binary, exit_status, stderr_to_stdout]),
    collected(Port, [], deadline(Ms), {Name, lists:join(" ", Args), Ms}).

collected(Port, Said, Deadline, {Name, Command, Ms} = Run) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, [Said, Bytes], Deadline, Run);
        {Port, {exit_status, Status}} -> {Status, unicode:characters_to_list(Said)}
    after left(Deadline) ->
        port_close(Port),
        fail(io_lib:format("on ~s, `~ts` did not end within ~B ms: ~ts",
                           [Name, Command, Ms, string:trim(unicode:characters_to_list(Said))]))
    end.

%% The moment a wait of Ms ends, and what is left of a wait until it.
deadline(infinity) -> infinity;
deadline(Ms) -> erlang:monotonic_time(millisecond) + Ms.

left(infinity) -> infinity;
left(Deadline) -> max(Deadline - erlang:monotonic_time(millisecond), 0).

%%
%% A command that runs on
%%

%% A command started on the machine, its standard output and standard
%% error read by a process of its own, which keeps them so that the
%% command never waits on a full pipe, and which answers.
-spec launched(machine(), string()) -> pid().
launched(Machine, Command) ->
    {Executable, Args} =
        case Machine of
            #machine{clone = local} ->
                {"/bin/sh", ["-c", "exec " ++ Command ++ " 2>&1"]};
            #machine{host = Host} ->
                {os:find_executable("ssh"),
                 ssh(Machine) ++ ["-n", Host, "exec " ++ Command ++ " 2>&1"]}
        end,
    Self = self(),
    Reader = spawn(fun() ->
                       Port = open_port({spawn_executable, Executable},
                                        [{args, Args}, binary, exit_status]),
                       Self ! {self(), opened},
                       read(Port, <<>>, [], {Machine#machine.name, Command})
                   end),
    receive {Reader, opened} -> Reader end.

%% The reader keeps what the command said, and who waits for a pattern in
%% it or for its end, and tells what it has said to one that has waited
%% too long.
read(Port, Said, Waiting, Launch) ->
    receive
        {said, From} ->
            From ! {self(), said, Said, Launch},
            read(Port, Said, Waiting, Launch);
        {Port, {data, Bytes}} ->
            Said1 = <<Said/binary, Bytes/binary>>,
            read(Port, Said1, [Wait || Wait <- Waiting, not told(Said1, Wait)], Launch);
        {Port, {exit_status, Status}} ->
            [From ! {self(), ended, Status, Said, Launch} || {_, From} <- Waiting],
            gone(Status, Said, Launch);
        {waiting, Pattern, From} ->
            case told(Said, {Pattern, From}) of
                true -> read(Port, Said, Waiting, Launch);
                false -> read(Port, Said, [{Pattern, From} | Waiting], Launch)
            end;
        {ended, From} ->
            read(Port, Said, [{ended, From} | Waiting], Launch)
    end.

told(_, {ended, _}) ->
    false;
told(Said, {Pattern, From}) ->
    case re:run(Said, Pattern, [{capture, all_but_first, list}]) of
        {match, Captured} -> From ! {self(), seen, Captured}, true;
        nomatch -> false
    end.

gone(Status, Said, Launch) ->
    receive
        {waiting, _, From} -> From ! {self(), ended, Status, Said, Launch};
        {ended, From} -> From ! {self(), ended, Status, Said, Launch};
        {said, From} -> From ! {self(), said, Said, Launch}
    end,
    gone(Status, Said, Launch).

%% Until the command's output matches Pattern; answers what it captured,
%% or fails with what the command said where it ended first, or where it
%% has not said it within the harness's time for one wait: one step.
-spec seen(pid(), string()) -> [string()].
seen(Reader, Pattern) ->
    ern_nodes_tests:step({seen, Pattern}),
    Reader ! {waiting, Pattern, self()},
    receive
        {Reader, seen, Captured} ->
            Captured;
        {Reader, ended, Status, Said, {Name, Command}} ->
            fail(io_lib:format("on ~s, `~ts` ended with status ~B before it said ~s: ~ts",
                               [Name, Command, Status, Pattern, string:trim(Said)]))
    after ern_nodes_tests:wait_ms() ->
        unended(Reader, "said " ++ Pattern)
    end.

%% Once the command has ended: its exit status and all it said, or a
%% failure where it has not ended within the harness's time for one wait:
%% one step.
-spec ended(pid()) -> {non_neg_integer(), binary()}.
ended(Reader) ->
    ern_nodes_tests:step({ended, Reader}),
    Reader ! {ended, self()},
    receive
        {Reader, ended, Status, Said, _} -> {Status, Said}
    after ern_nodes_tests:wait_ms() ->
        unended(Reader, "ended")
    end.

%% The failure of a wait on what the reader's command did not do in time,
%% with what it has said.
unended(Reader, What) ->
    Reader ! {said, self()},
    receive
        {Reader, said, Said, {Name, Command}} ->
            fail(io_lib:format("on ~s, `~ts` has not ~s within ~B ms: ~ts",
                               [Name, Command, What, ern_nodes_tests:wait_ms(),
                                string:trim(Said)]))
    end.

%% Report §8.7: once the port Port of Host answers, asked from here: a node
%% listens only once its initializers have their values, and one started
%% apart from the run, whose line `listening on` goes to a log of earlier
%% starts too, shows that it listens by its port's answer. A refusal comes
%% at once, so the next ask waits as long as the node has been waited for
%% so far, and at least the one millisecond of the host's timer, within
%% which the first refusal comes: however long the node takes to listen,
%% it is seen within that time again, and the asks grow with the logarithm
%% of that time, not with the time, as asks without a pause would, which
%% keep a core busy while the node starts. At each refusal Refused is
%% called, which fails where the node has ended; a port that has not
%% answered within the harness's time for one wait fails the run. One step.
-spec answering(string(), inet:port_number(), fun(() -> ok)) -> ok.
answering(Host, Port, Refused) ->
    ern_nodes_tests:step({answering, Host, Port}),
    answering(Host, Port, Refused, erlang:monotonic_time(millisecond)).

answering(Host, Port, Refused, Asked) ->
    Now = erlang:monotonic_time(millisecond),
    Now - Asked =< ern_nodes_tests:wait_ms()
        orelse fail(io_lib:format("~s:~B did not answer within ~B ms",
                                  [Host, Port, ern_nodes_tests:wait_ms()])),
    case gen_tcp:connect(Host, Port, []) of
        {ok, Socket} ->
            gen_tcp:close(Socket);
        {error, econnrefused} ->
            ok = Refused(),
            receive after max(Now - Asked, 1) -> ok end,
            answering(Host, Port, Refused, Asked);
        {error, Error} ->
            fail(io_lib:format("~s:~B cannot be reached from here: ~s",
                               [Host, Port, inet:format_error(Error)]))
    end.

%% A word the shell reads as the text itself.
-spec quoted(string()) -> string().
quoted(Text) ->
    "'" ++ lists:flatten(string:replace(Text, "'", "'\\''", all)) ++ "'".

%% A failure of the machines' tools, its text the line they say before they
%% end (ern_machines:reported/1).
-spec fail(io_lib:chars()) -> no_return().
fail(Text) ->
    throw({failed, lists:flatten(Text)}).
