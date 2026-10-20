%% `make bench-pick`'s probe (test/ern_pick_costs.erl): what a node shows
%% of itself while the measuring program places work on its peers, read
%% where the host shows it: the node's name on the carrier, by which a
%% compute's answer says where it ran (report §8.7); and a sample of the
%% host's counts, the packets each connection of the node has carried, the
%% time the node's schedulers have been busy, and the processor time of the
%% machine it runs on, where the machine has a /proc/stat. Each function
%% is a foreign function of the measuring program, run on a peer by a
%% compute of its name (report §8.7) or called on the measuring node
%% itself; none is any program's.
-module(ern_pick_probe).

-export([here/0, sampled/0]).

%% Report §8.7: the node's name on the carrier.
-spec here() -> binary().
here() ->
    atom_to_binary(node()).

%% A sample of the host's counts, a line each: `time` and the host's
%% monotonic clock in microseconds; `packets`, a peer's name on the carrier
%% and the packets its connection has carried in and out; `schedulers`, the
%% time the node's schedulers have been busy and the time they have been
%% counted, in the host's unit; and `processors`, the machine's idle time
%% and its whole time, in its clock's ticks, where it has a /proc/stat.
%% The schedulers that run processes are counted, from the first sample
%% on.
-spec sampled() -> [binary()].
sampled() ->
    ok = counting(),
    Time = erlang:monotonic_time(microsecond),
    Packets = [{Node, proplists:get_value(in, Info), proplists:get_value(out, Info)}
               || Node <- nodes(connected), {ok, Info} <- [net_kernel:node_info(Node)]],
    %% the host's list holds its dirty schedulers after the normal ones,
    %% which run the processes
    Normal = erlang:system_info(schedulers),
    Schedulers = [{Active, Total} || {Id, Active, Total} <- erlang:statistics(scheduler_wall_time),
                                     Id =< Normal],
    Busy = lists:sum([Active || {Active, _} <- Schedulers]),
    Counted = lists:sum([Total || {_, Total} <- Schedulers]),
    [iolist_to_binary(io_lib:format("time ~B", [Time]))
     | [iolist_to_binary(io_lib:format("packets ~s ~B ~B", [Node, In, Out]))
        || {Node, In, Out} <- Packets]]
        ++ [iolist_to_binary(io_lib:format("schedulers ~B ~B", [Busy, Counted]))]
        ++ processors().

%% The host counts its schedulers' time while a process that asked for it
%% lives, so a process of the probe's own asks, at the first sample, and
%% lives as long as the node.
counting() ->
    case whereis(?MODULE) of
        undefined ->
            Caller = self(),
            Counter = spawn(fun() ->
                                true = register(?MODULE, self()),
                                _ = erlang:system_flag(scheduler_wall_time, true),
                                Caller ! {self(), counting},
                                receive after infinity -> ok end
                            end),
            receive {Counter, counting} -> ok end;
        _ ->
            ok
    end.

%% Linux's processor time across the machine, its first line of
%% /proc/stat: the idle time, the waiting for input and output among it,
%% and the time of the eight states that make the whole.
processors() ->
    case file:read_file("/proc/stat") of
        {ok, <<"cpu ", Rest/binary>>} ->
            [Line | _] = binary:split(Rest, <<"\n">>),
            Ticks = [binary_to_integer(Word)
                     || Word <- binary:split(Line, <<" ">>, [global, trim_all])],
            [User, Nice, System, Idle, Waiting, Interrupts, SoftInterrupts, Stolen | _] = Ticks,
            [iolist_to_binary(io_lib:format("processors ~B ~B",
                                            [Idle + Waiting,
                                             User + Nice + System + Idle + Waiting + Interrupts
                                                 + SoftInterrupts + Stolen]))];
        _ ->
            []
    end.
