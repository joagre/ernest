%% `make bench`'s fourth part (test/ern_code_costs.erl): what a node shows
%% of its own work while the measuring program spawns code onto it, read
%% where the host shows it. The exchange's steps (report §8.7), from the
%% host's call trace of the node's exchange process, each call with its
%% time, and the two steps of the spawner's node with their returns; the
%% host's four counts, as the runtime reads them (ern_code:counts/0, report
%% §11.2); what crossed each of the node's connections over a window of
%% the host's ticks; and the pick of a compute that names no peer, timed
%% where the node makes it (ern_peer:picked/0). Each function is a foreign
%% function of the measuring program, run on a peer by a compute of its name
%% (report §8.7) or called on the measuring node itself; none is any
%% program's.
-module(ern_code_probe).

-export([traced/0, read/0, counts/0, window/0, windowed/0, picks/1]).

%% The exchange's steps as the node that lacks a function takes its reach,
%% each a call alone, since a return would carry the exchange's state, the
%% prelude's environment within it, into the trace: the request asked, each
%% frame read, each code frame verified and its members read, a frame kept
%% or the reach completed, the prelude's environment built, the arrival
%% received, linked, emitted, compiled, loaded, put in the code table and
%% read against the host's limits, and the spawn started and answered.
-define(STEPS, [{ern_exchange, asked, 4}, {ern_exchange, frame, 3},
                {ern_canonical, verified, 2}, {ern_exchange, framed, 4},
                {ern_exchange, kept, 3}, {ern_exchange, completed, 3},
                {ern_typecheck, prelude_env, 0}, {ern_arrival, received, 5},
                {ern_emitter, unit, 1}, {ern_compile, compiled, 2}, {code, atomic_load, 1},
                {ern_code, loaded, 3}, {ern_cli, say_limits, 0}, {ern_exchange, started, 1},
                {ern_gateway, outcome, 2}]).

%% The spawner's node's two steps, each with its return: the reach answered
%% and the code frames made, which read the forms from the build's `.erc`.
-define(ANSWERS, [{ern_exchange, reach_answer, 2}, {ern_exchange, code_frames, 1}]).

%% The node's exchange traced from now on, its steps sent to the probe's
%% tracer, which keeps them until read/0; traced once, however often asked.
-spec traced() -> 'Unit'.
traced() ->
    Tracer = tracer(),
    Exchange = whereis(ern_exchange),
    case erlang:trace_info(Exchange, tracer) of
        {tracer, []} ->
            1 = erlang:trace(Exchange, true,
                             [call, arity, monotonic_timestamp, {tracer, Tracer}]);
        {tracer, _} ->
            ok
    end,
    [erlang:trace_pattern(Step, true, [local]) || Step <- ?STEPS],
    %% the frame's kind, and a code frame's members and bytes
    erlang:trace_pattern({ern_exchange, frame, 3},
                         [{['_', {code_frame, '_', '$1', '$2', '$3', '$4'}, '_'], [],
                           [{message, {{code_frame, {length, '$1'}, {byte_size, '$2'},
                                        {length, '$3'}, {byte_size, '$4'}}}}]},
                          {['_', '$1', '_'], [], [{message, {element, 1, '$1'}}]}],
                         [local]),
    %% the definitions an arrival holds
    erlang:trace_pattern({ern_arrival, received, 5},
                         [{['_', '$1', '_', '_', '_'], [], [{message, {length, '$1'}}]}],
                         [local]),
    [erlang:trace_pattern(Answer, [{'_', [], [{exception_trace}]}], [local])
     || Answer <- ?ANSWERS],
    'Unit'.

%% The tracer, started at the first call: it keeps each step as it comes,
%% and hands them over at read/0, keeping none after.
tracer() ->
    case whereis(?MODULE) of
        undefined ->
            Caller = self(),
            Tracer = spawn(fun() ->
                               true = register(?MODULE, self()),
                               Caller ! {self(), registered},
                               kept([])
                           end),
            receive {Tracer, registered} -> Tracer end;
        Tracer ->
            Tracer
    end.

kept(Steps) ->
    receive
        {trace_ts, _, call, Function, Extra, Time} ->
            kept([{Time, call, Function, Extra} | Steps]);
        {trace_ts, _, call, Function, Time} ->
            kept([{Time, call, Function, none} | Steps]);
        {trace_ts, _, Returned, Function, _, Time}
          when Returned =:= return_from; Returned =:= exception_from ->
            kept([{Time, return, Function, none} | Steps]);
        {read, From} ->
            From ! {steps, lists:reverse(Steps)},
            kept([])
    end.

%% Each step kept since the last read, in the order they came, as a line:
%% the microseconds of the host's monotonic clock, `call` or `return`, the
%% function, and what its trace pattern added, the frame's kind or a code
%% frame's members, bytes, references and source bytes, or the definitions
%% an arrival holds.
-spec read() -> [binary()].
read() ->
    Tracer = tracer(),
    Tracer ! {read, self()},
    receive {steps, Steps} -> [line(Step) || Step <- Steps] end.

line({Time, Kind, {Module, Function, Arity}, Extra}) ->
    iolist_to_binary(io_lib:format("~B ~s ~s:~s/~B~s",
                                   [erlang:convert_time_unit(Time, native, microsecond), Kind,
                                    Module, Function, Arity, extra(Extra)])).

extra(none) -> "";
extra({code_frame, Members, Bytes, References, Sources}) ->
    io_lib:format(" code_frame ~B ~B ~B ~B", [Members, Bytes, References, Sources]);
extra(Kind) when is_atom(Kind) -> [" ", atom_to_list(Kind)];
extra(Count) when is_integer(Count) -> [" ", integer_to_list(Count)].

%% Report §11.2: the host's four counts as the runtime reads them, a line of
%% each table's name and its entries.
-spec counts() -> binary().
counts() ->
    iolist_to_binary(lists:join(" ", [io_lib:format("~s ~B", [Table, Entries])
                                      || {Table, Entries, _} <- ern_code:counts()])).

%% Report §8.7: a window opened on what crosses each connection of the
%% node, by a process of the probe's own that reads the host's counts of
%% each connection's packets and the gateway's and the exchange's
%% reductions at its start and at its end, and holds them until
%% windowed/0. The window is four of the host's tick intervals, a quarter
%% of its tick time each (§8.7's 15 seconds), so that an idle connection
%% shows its ticks: a rate measured over a time, which nothing but the time
%% can show.
-spec window() -> 'Unit'.
window() ->
    Ms = net_kernel:get_net_ticktime() * 1000,
    Caller = self(),
    Window = spawn(fun() ->
                       true = register(ern_code_probe_window, self()),
                       Caller ! {self(), registered},
                       Started = sample(),
                       receive after Ms -> ok end,
                       held(Ms, Started, sample())
                   end),
    receive {Window, registered} -> 'Unit' end.

%% What crossed each connection over the window, once it has closed: a
%% line of the window's milliseconds, then one of each peer the node was
%% connected to throughout, by its node, with the packets in and out, and
%% one of the gateway's and the exchange's reductions.
-spec windowed() -> [binary()].
windowed() ->
    Window = whereis(ern_code_probe_window),
    MonitorRef = erlang:monitor(process, Window),
    Window ! {windowed, self()},
    receive
        {Window, Lines} -> erlang:demonitor(MonitorRef, [flush]), Lines;
        {'DOWN', MonitorRef, process, Window, Reason} -> erlang:error(Reason)
    end.

held(Ms, {Before, Reductions}, {After, ReductionsAfter}) ->
    Lines = [iolist_to_binary(io_lib:format("window ~B", [Ms]))
             | [iolist_to_binary(io_lib:format("peer ~s ~B ~B", [Node, In1 - In0, Out1 - Out0]))
                || {Node, {In0, Out0}} <- Before, {Node1, {In1, Out1}} <- After, Node1 =:= Node]]
        ++ [iolist_to_binary(io_lib:format("reductions ~s ~B", [Name, Count1 - Count0]))
            || {Name, Count0} <- Reductions, {Name1, Count1} <- ReductionsAfter, Name1 =:= Name],
    receive {windowed, From} -> From ! {self(), Lines} end.

sample() ->
    Packets = [{Node, {proplists:get_value(in, Info), proplists:get_value(out, Info)}}
               || Node <- nodes(connected), {ok, Info} <- [net_kernel:node_info(Node)]],
    Reductions = [{Name, Count} || Name <- [ern_gateway, ern_exchange],
                                   {reductions, Count}
                                       <- [erlang:process_info(whereis(Name), reductions)]],
    {Packets, Reductions}.

%% Report §8.7: the microseconds Count picks of a compute that names no peer
%% take on this node, each a read of the utilizations its peers told it and
%% a draw, and no frame.
-spec picks(integer()) -> integer().
picks(Count) ->
    {Micros, ok} = timer:tc(fun() -> picked(Count) end),
    Micros.

picked(0) ->
    ok;
picked(Count) ->
    {picked, _} = ern_peer:picked(),
    picked(Count - 1).
