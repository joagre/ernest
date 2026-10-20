%% A machine that MVP 3.27's tools start nodes on (plan, MVP 3.27 item 1),
%% and what is done there: a command run and its output read, a
%% directory's files copied to it, and a command that runs on, a node or a
%% host, whose output a reader of its own keeps until it is waited for.
%% This machine's commands run in the plain shell; another's over ssh,
%% through one ssh connection held for the run, since an ssh connection's
%% own handshake costs 0.5 to 1.5 seconds to the user's machines, and a
%% session over a held one about 25 ms. test/machines/machines.txt lists
%% the machines (docs/development.md).
-module(ern_machine).

-export([local/0, machine/4, name/1, host/1, interface/1, is_local/1, clone/1, ern/1,
         directory/1, directory/2, open/2, opened/1, closed/1, run/2, ran/2, load/1, copied/3,
         launched/2, seen/2, ended/1, quoted/1, fail/1]).

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
    connected(Machine, Port, <<>>).

connected(Machine, Port, Said) ->
    case binary:match(Said, <<"connected\n">>) of
        nomatch ->
            receive
                {Port, {data, Bytes}} ->
                    connected(Machine, Port, <<Said/binary, Bytes/binary>>);
                {Port, {exit_status, Status}} ->
                    fail(io_lib:format("~s, ~s, cannot be reached: ssh ended with status ~B: ~ts",
                                       [Machine#machine.name, Machine#machine.host, Status,
                                        string:trim(Said)]))
            end;
        _ ->
            Machine
    end.

%% The ssh connection closed, once ssh has ended it.
-spec closed(machine()) -> ok.
closed(#machine{ssh = none}) ->
    ok;
closed(#machine{host = Host, ssh = {Port, Socket}}) ->
    _ = command(os:find_executable("ssh"), ["-o", "ControlPath=" ++ Socket, "-O", "exit", Host]),
    receive {Port, {exit_status, _}} -> ok end.

%%
%% Commands
%%

%% The command run on the machine by its shell: its exit status, and what
%% it wrote to its standard output and its standard error together.
-spec run(machine(), string()) -> {non_neg_integer(), string()}.
run(#machine{clone = local}, Command) ->
    command("/bin/sh", ["-c", Command]);
run(Machine, Command) ->
    command(os:find_executable("ssh"), ssh(Machine) ++ ["-n", Machine#machine.host, Command]).

%% What the command wrote, where it ended with status 0; otherwise the run
%% fails, naming the machine, the command and what it wrote.
-spec ran(machine(), string()) -> string().
ran(Machine, Command) ->
    case run(Machine, Command) of
        {0, Output} ->
            Output;
        {Status, Output} ->
            fail(io_lib:format("on ~s, `~ts` ended with status ~B: ~ts",
                               [Machine#machine.name, Command, Status, string:trim(Output)]))
    end.

%% The machine's load average of the last minute, as ern_measure reads it,
%% Linux's or the BSDs' and macOS's, and its processors.
-spec load(machine()) -> {string(), string()}.
load(Machine) ->
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
    case command(os:find_executable("scp"), ssh(Machine) ++ ["-q" | Files]
                                                ++ [Host ++ ":" ++ Target ++ "/"]) of
        {0, _} -> Target;
        {Status, Output} ->
            fail(io_lib:format("the files of ~s could not be copied to ~s: scp ended with"
                               " status ~B: ~ts", [Dir, Name, Status, string:trim(Output)]))
    end.

ssh(#machine{ssh = {_, Socket}}) ->
    ["-o", "BatchMode=yes", "-o", "ControlMaster=no", "-o", "ControlPath=" ++ Socket].

command(Executable, Args) ->
    Port = open_port({spawn_executable, Executable},
                     [{args, Args}, binary, exit_status, stderr_to_stdout]),
    collected(Port, []).

collected(Port, Said) ->
    receive
        {Port, {data, Bytes}} -> collected(Port, [Said, Bytes]);
        {Port, {exit_status, Status}} -> {Status, unicode:characters_to_list(Said)}
    end.

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
%% it or for its end.
read(Port, Said, Waiting, Launch) ->
    receive
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
        {ended, From} -> From ! {self(), ended, Status, Said, Launch}
    end,
    gone(Status, Said, Launch).

%% Until the command's output matches Pattern; answers what it captured,
%% or fails with what the command said where it ended first.
-spec seen(pid(), string()) -> [string()].
seen(Reader, Pattern) ->
    Reader ! {waiting, Pattern, self()},
    receive
        {Reader, seen, Captured} ->
            Captured;
        {Reader, ended, Status, Said, {Name, Command}} ->
            fail(io_lib:format("on ~s, `~ts` ended with status ~B before it said ~s: ~ts",
                               [Name, Command, Status, Pattern, string:trim(Said)]))
    end.

%% Once the command has ended: its exit status and all it said.
-spec ended(pid()) -> {non_neg_integer(), binary()}.
ended(Reader) ->
    Reader ! {ended, self()},
    receive {Reader, ended, Status, Said, _} -> {Status, Said} end.

%% A word the shell reads as the text itself.
-spec quoted(string()) -> string().
quoted(Text) ->
    "'" ++ lists:flatten(string:replace(Text, "'", "'\\''", all)) ++ "'".

%% A failure of the machines' tools, its text the line they say before they
%% end (ern_machines:reported/1).
-spec fail(io_lib:chars()) -> no_return().
fail(Text) ->
    throw({failed, lists:flatten(Text)}).
