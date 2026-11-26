%% Report §8.7: what the programs of test/fixtures/peers/ ask of the host and no
%% module of Ernest's gives, for the tests alone: the count of the node's
%% atoms, the count of the notes of calls on a callee it keeps for other
%% nodes, a connection ended by a frame its peer's gateway cannot read, the
%% host's own round trip to another node, timed, for `make bench`, and
%% foreign code that holds an address it is given and sends through it, or
%% gives it back (report §8.4).
-module(ern_peers_host).

-export([atoms/0, notes/1, sever/1, pings/2, hold/2, held/1, sent_through/2, held_alive/1,
         held_end/2, lookouts_left/1, back/1]).

-spec atoms() -> non_neg_integer().
atoms() ->
    erlang:system_info(atom_count).

-spec notes(pid()) -> non_neg_integer().
notes(Callee) ->
    ets:select_count(ern_notes, [{{'_', Callee, '_'}, [], [true]}]).

-spec sever(pid()) -> 'Unit'.
sever(Pid) ->
    erlang:send({ern_gateway, node(Pid)}, {ern_frame, self(), unreadable}),
    'Unit'.

%% The microseconds of one of the host's round trips to the process's node,
%% its ping, over as many as asked.
-spec pings(pid(), pos_integer()) -> float().
pings(Pid, Count) ->
    Node = node(Pid),
    pong = net_adm:ping(Node),
    Started = erlang:monotonic_time(microsecond),
    [pong = net_adm:ping(Node) || _ <- lists:seq(1, Count)],
    (erlang:monotonic_time(microsecond) - Started) / Count.

%% Report §8.4: foreign code holds each address it is given under a key, as
%% the host process given to it, the check in front of the address, and
%% sends through it straight to that process.
-spec hold(binary(), pid()) -> 'Unit'.
hold(Key, Pid) when is_pid(Pid) ->
    persistent_term:put({?MODULE, Key}, Pid),
    'Unit'.

%% The process held under Key, as the host writes it.
-spec held(binary()) -> binary().
held(Key) ->
    list_to_binary(pid_to_list(held_process(Key))).

-spec sent_through(binary(), integer()) -> 'Unit'.
sent_through(Key, N) ->
    held_process(Key) ! N,
    'Unit'.

-spec held_alive(binary()) -> boolean().
held_alive(Key) ->
    erlang:is_process_alive(held_process(Key)).

%% `ended` once the process held under Key has ended, or `alive` where it
%% lives for Ms, the bound the program gives the end of a check that
%% should end.
-spec held_end(binary(), non_neg_integer()) -> binary().
held_end(Key, Ms) ->
    case ended(held_process(Key), erlang:monotonic_time(millisecond) + Ms) of
        true -> <<"ended">>;
        false -> <<"alive">>
    end.

%% Report §8.4, §10, §12.9: how many lookouts of the node are left once
%% each has ended, or Ms has passed: a lookout, the process beside a check
%% whose target's node is out of reach, is told apart by the function it
%% waits in, the runtime's own (ern_boundary:lookout_loop/4), and one about
%% to end is waited for, so that what is counted is a lookout that stays.
-spec lookouts_left(non_neg_integer()) -> non_neg_integer().
lookouts_left(Ms) ->
    Deadline = erlang:monotonic_time(millisecond) + Ms,
    Lookouts = [Pid || Pid <- erlang:processes(),
                       erlang:process_info(Pid, current_function)
                           =:= {current_function, {ern_boundary, lookout_loop, 4}}],
    length([Pid || Pid <- Lookouts, not ended(Pid, Deadline)]).

%% Report §8.4: foreign code that gives back the address it was given, as
%% the host process it was given, the check in front of the address.
-spec back(pid()) -> pid().
back(Pid) when is_pid(Pid) ->
    Pid.

%% Whether Pid has ended by Deadline, waited for by a monitor of it.
ended(Pid, Deadline) ->
    MonitorRef = erlang:monitor(process, Pid),
    receive
        {'DOWN', MonitorRef, process, _, _} -> true
    after max(Deadline - erlang:monotonic_time(millisecond), 0) ->
        erlang:demonitor(MonitorRef, [flush]),
        false
    end.

held_process(Key) ->
    persistent_term:get({?MODULE, Key}).
