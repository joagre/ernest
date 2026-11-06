%% `make bench`'s part `restarting` (docs/development.md), beside
%% ern_spawn_costs: what entering `restarting` costs beside the host's try
%% (report §6.9, Appendix E.22, §10; plan, MVP 3.27 item 3). The function
%% `restarting` answers runs `f()` in a try, which catches a fault and runs
%% `f()` again within the limit; before it, the process is made one a
%% supervisor can ask to restart, by an alias it keeps with its start cause
%% in its own dictionary; and once `f` returns, the alias goes, with a
%% request to restart that came as `f` returned.
%%
%% Measured, in restarting.txt: the host's try and Ernest's `restarting`
%% entered and returning, through the runtime in a launch, as the bench's
%% row measures them, and the same with a hundred messages waiting in the
%% mailbox. Each row is the median of seven runs, in nanoseconds an
%% iteration, the loop's own cost included, with their range, as ern_costs
%% measures them. It measures and asserts nothing, so it is not part of
%% `make test-full`.
-module(ern_restarting_costs).

-export([main/1]).

%% Each loop's iterations, and the messages that wait in the mailbox where
%% some do.
-define(COUNT, 1000000).
-define(WAITING, 100).

%% Prints the table, writes it to restarting.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Entered = [{"the host's try around a call", fun host_tries/1},
               {"Ernest's restarting entered and returning",
                ern_costs:launched(fun ernest_restartings/1)},
               {"  the same with 100 messages waiting",
                ern_costs:launched(fun ernest_restartings_waiting/1)}],
    Text = unicode:characters_to_binary(
             ern_costs:table("restarting, ns an iteration", ern_costs:measured(Entered, ?COUNT),
                             ratio)),
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
    ern_costs:timed(Count, ern_costs:looped(fun(_) -> try Function() catch _:_ -> ok end end)).

%% Report §6.9: Ernest's restarting entered and returning, the code the
%% compiler writes for `restarting(Unlimited, fn() = Unit)()`.
ernest_restartings(Count) ->
    ern_costs:timed(Count, ern_costs:looped(fun(_) ->
                                                (ern_rt:restarting('Unlimited',
                                                                   fun() -> 'Unit' end))()
                                            end)).

%% The same with ?WAITING messages in the mailbox.
ernest_restartings_waiting(Count) ->
    waiting(fun ernest_restartings/1, Count).

%% Measure run with ?WAITING messages in the mailbox, taken out after.
waiting(Measure, Count) ->
    [self() ! {waiting, Index} || Index <- lists:seq(1, ?WAITING)],
    Measured = Measure(Count),
    [receive {waiting, Index} -> ok end || Index <- lists:seq(1, ?WAITING)],
    Measured.
