%% `make bench`'s fifth part (docs/development.md), beside
%% ern_spawn_costs: what each piece of entering `restarting` adds to the
%% host's try (report §6.9, Appendix E.22, §10; plan, MVP 3.27 item 3).
%% The function `restarting` answers runs `f()` in a try, which catches a
%% fault and runs `f()` again within the limit; before it, the process is
%% made one a supervisor can ask to restart, by an alias the runtime keeps
%% in a row of its own beside the process, and its start cause is set; and
%% once `f` returns, the alias and the row go, with a request to restart
%% that came as `f` returned (ern_rt's restarting/2, restartable/0,
%% unrestartable/0, restarts/4).
%%
%% Measured, in restarting.txt: the host's try and Ernest's `restarting`
%% entered and returning, through the runtime in a launch, as the bench's
%% row measures them, and the same with a hundred messages waiting in the
%% mailbox; a model of the function, a piece added on each row, so that the
%% runtime's multiple of the host's try is accounted for piece by piece; and
%% each operation of the model's alone, in a loop of its own. Each row is
%% the median of seven runs, in nanoseconds an iteration, the loop's own
%% cost included, with their range, as ern_spawn_costs measures them. It
%% measures and asserts nothing, so it is not part of `make test-full`.
-module(ern_restarting_costs).

-export([main/1]).

%% Each loop's iterations, and the messages that wait in the mailbox where
%% some do.
-define(COUNT, 1000000).
-define(WAITING, 100).

%% The pieces of the model, in the order they are added: the function
%% `restarting` answers, made and called; whether a restarting function
%% runs already, read from the process's dictionary; the alias a
%% supervisor asks through, made and dropped; the row that holds it,
%% written, and taken at the end; the start cause put and erased; and the
%% look for a request to restart that came as `f` returned.
-define(PIECES, [function, running, alias, row, cause, look]).

%% Prints the tables, writes them to restarting.txt in Directory, and
%% halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Entered = [{"the host's try around a call", fun host_tries/1},
               {"Ernest's restarting entered and returning",
                ern_spawn_costs:launched(fun ernest_restartings/1)},
               {"  the same with 100 messages waiting",
                ern_spawn_costs:launched(fun ernest_restartings_waiting/1)}],
    Model = [{named(Pieces), fun(Count) -> modeled(Pieces, Count) end} || Pieces <- ladder()],
    Measured = ern_spawn_costs:measured(Entered ++ Model, ?COUNT),
    Text = unicode:characters_to_binary(
             [ern_spawn_costs:table("restarting, ns an iteration",
                                    lists:sublist(Measured, length(Entered)), ratio),
              ern_spawn_costs:table("a model of restarting, a piece added on each row",
                                    lists:nthtail(length(Entered), Measured), added),
              ern_spawn_costs:table("its operations, each alone, ns an operation",
                                    ern_spawn_costs:measured(operations(), ?COUNT), none)]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "restarting.txt"), Text),
    halt(0).

%%
%% The host's, and the runtime's in a launch
%%

%% The host's try around a call of a function that returns, as the bench's
%% Erlang row, with the call it makes.
host_tries(Count) ->
    Function = fun() -> 'Unit' end,
    ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                     Loop(Left) ->
                                         try Function() catch _:_ -> ok end,
                                         Loop(Left - 1)
                                 end).

%% Report §6.9: Ernest's restarting entered and returning, the code the
%% compiler writes for `restarting(Unlimited, fn() = Unit)()`.
ernest_restartings(Count) ->
    ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                     Loop(Left) ->
                                         _ = (ern_rt:restarting('Unlimited',
                                                                fun() -> 'Unit' end))(),
                                         Loop(Left - 1)
                                 end).

%% The same with ?WAITING messages in the mailbox.
ernest_restartings_waiting(Count) ->
    waiting(fun ernest_restartings/1, Count).

%% Measure run with ?WAITING messages in the mailbox, taken out after.
waiting(Measure, Count) ->
    [self() ! {waiting, Index} || Index <- lists:seq(1, ?WAITING)],
    Measured = Measure(Count),
    [receive {waiting, Index} -> ok end || Index <- lists:seq(1, ?WAITING)],
    Measured.

%%
%% The model
%%

%% The model's rows: none of the pieces, then each added in turn.
ladder() ->
    [lists:sublist(?PIECES, Count) || Count <- lists:seq(0, length(?PIECES))].

%% A run of the model with Pieces on, in a process of its own, over a
%% table of the runtime's kind made for the run (ern_rt's table_kind/1).
modeled(Pieces, Count) ->
    On = maps:from_list([{Piece, true} || Piece <- Pieces]),
    Function = fun() -> 'Unit' end,
    in_process(fun(Restarts) ->
                   ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                                    Loop(Left) ->
                                                        _ = entered(On, Restarts, Function),
                                                        Loop(Left - 1)
                                                end)
               end).

%% Run(Restarts) in a process of its own, Restarts a table made for it,
%% and its answer.
in_process(Run) ->
    Caller = self(),
    Pid = spawn(fun() ->
                    Restarts = ets:new(ern_restarting_costs, [public, set]),
                    Caller ! {self(), Run(Restarts)}
                end),
    receive {Pid, Answer} -> Answer end.

%% ern_rt's restarting/2 entered, piece by piece: the try around f's call
%% alone, or the function restarting answers, made and called, which
%% marks the process first and unmarks it after (restartable/0,
%% unrestartable/0).
entered(#{function := true} = On, Restarts, Function) ->
    (restarting(On, Restarts, Function))();
entered(_, _, Function) ->
    try Function() catch _:_ -> ok end.

restarting(On, Restarts, Function) ->
    fun() ->
        Level = restartable(On, Restarts),
        try
            try Function() catch _:_ -> ok end
        after
            Level =:= outer andalso unrestartable(On, Restarts)
        end
    end.

%% ern_rt's restartable/0, piece by piece.
restartable(On, Restarts) ->
    case maps:is_key(running, On) andalso get('$ern_start') =/= undefined of
        true ->
            inner;
        false ->
            Alias = case On of
                        #{alias := true} -> erlang:alias([priority]);
                        _ -> none
                    end,
            %% without the row, the alias kept where the model finds it
            _ = [put('$ern_alias', Alias) || is_map_key(alias, On), not is_map_key(row, On)],
            _ = [ets:insert(Restarts, {self(), Alias}) || is_map_key(row, On)],
            _ = [put('$ern_start', 'First') || is_map_key(cause, On)],
            outer
    end.

%% ern_rt's unrestartable/0, piece by piece.
unrestartable(On, Restarts) ->
    Alias = case On of
                #{row := true} -> element(2, hd(ets:take(Restarts, self())));
                #{alias := true} -> erase('$ern_alias');
                _ -> none
            end,
    _ = [erlang:unalias(Alias) || is_map_key(alias, On)],
    _ = [erase('$ern_start') || is_map_key(cause, On)],
    [receive '$ern_restart' -> ok after 0 -> ok end || is_map_key(look, On)].

named([]) -> "the host's try around a call";
named(Pieces) -> "+ " ++ piece(lists:last(Pieces)).

piece(function) -> "the function restarting answers, made and called";
piece(running) -> "whether one runs already, read from the process's dictionary";
piece(alias) -> "the alias a supervisor asks through, made and dropped";
piece(row) -> "the row that holds it, written, and taken at the end";
piece(cause) -> "the start cause put and erased";
piece(look) -> "the look for a request to restart as f returned".

%%
%% The operations, each alone
%%

%% Each operation of the model's alone in a loop, in a process of its own
%% over a table made for its run: the loop alone, the host's try, the
%% function made and called, the dictionary read, and the row looked for
%% as the runtime looked for it before, an alias made and dropped, with
%% and without the priority a supervisor's request needs, the row written
%% and taken, and written, read and deleted as before, the start cause
%% put and erased, and the look for a request on an empty mailbox and on
%% one where a hundred messages wait.
operations() ->
    Function = fun() -> 'Unit' end,
    Look = fun(_) -> receive '$ern_restart' -> ok after 0 -> ok end end,
    [{Name, fun(Count) -> operated(Operation, Count) end}
     || {Name, Operation} <-
            [{"the loop alone", fun(_) -> ok end},
             {"the host's try around a call", fun(_) -> try Function() catch _:_ -> ok end end},
             {"the function made and called", fun(_) -> (fun() -> Function() end)() end},
             {"the dictionary read, nothing there", fun(_) -> get('$ern_start') end},
             {"the process's row looked for, none there",
              fun(Restarts) -> ets:lookup(Restarts, self()) end},
             {"an alias made and dropped",
              fun(_) -> erlang:unalias(erlang:alias([priority])) end},
             {"  the same without priority", fun(_) -> erlang:unalias(erlang:alias()) end},
             {"the row written and taken", fun(Restarts) ->
                                                ets:insert(Restarts, {self(), none}),
                                                ets:take(Restarts, self())
                                            end},
             {"  written, read and deleted",
              fun(Restarts) ->
                  ets:insert(Restarts, {self(), none}),
                  _ = ets:lookup(Restarts, self()),
                  ets:delete(Restarts, self())
              end},
             {"the start cause put and erased",
              fun(_) -> put('$ern_start', 'First'), erase('$ern_start') end},
             {"the look for a request, an empty mailbox", Look}]]
        ++ [{"  with 100 messages waiting", fun(Count) -> operated(Look, Count, ?WAITING) end}].

operated(Operation, Count) ->
    operated(Operation, Count, 0).

%% Count iterations of Operation, in a process of its own over a table made
%% for it, with Waiting messages in its mailbox.
operated(Operation, Count, Waiting) ->
    in_process(fun(Restarts) ->
                   [self() ! {waiting, Index} || Index <- lists:seq(1, Waiting)],
                   ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                                    Loop(Left) ->
                                                        _ = Operation(Restarts),
                                                        Loop(Left - 1)
                                                end)
               end).
