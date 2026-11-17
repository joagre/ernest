%% The tests of the repository's runs of EUnit, each alone: make test's of
%% each root (the repository's Makefile, UNIT_TESTS), the flake hunt's
%% rounds, which take the same tests (ern_flakes), and the areas' under
%% test/ (test/Makefile, EUNIT_ALONE and EUNIT_SIDE_BY_SIDE).
%%
%% EUnit runs a list of tests in one process, and ends that process where a
%% test passes its time limit: the tests after it in the list then neither
%% run nor are counted, and a test ended inside file:set_cwd/1 leaves the
%% host in its own directory. Here each test is a fixture of its own, which
%% EUnit runs in a process of its own and begins in the run's directory, so
%% that a limit ends its own test alone and the next test begins where the
%% run did.
%%
%% A generator's tests share its one process, so a limit inside a generator
%% that answers several tests still ends that generator's tests after it.
%%
%% EUnit's own `{inparallel, N, Tests}` starts N tests and starts the next N
%% only once all N have ended, so a run takes the sum of each N's longest
%% test. side_by_side/2 runs tests in lanes in its place: each lane runs one
%% test at a time and takes the next of the tests, in their order, as soon
%% as its own has ended.
-module(ern_eunit).

-export([alone/1, side_by_side/2]).

-type test() :: {module(), atom()} | {generator, module(), atom()}.

%% The tests of Modules, each test function's in the order its module
%% exports it, a function whose name ends in `_test_` a generator, each
%% alone and begun in the directory the host is in now, the run's.
-spec alone([module()]) -> [{setup, spawn, fun(() -> ok), test()}].
alone(Modules) ->
    {ok, Cwd} = file:get_cwd(),
    [{setup, spawn, fun() -> ok = file:set_cwd(Cwd) end, Test}
     || Module <- Modules, {Function, 0} <- Module:module_info(exports),
        Test <- tested(Module, Function)].

tested(Module, Function) ->
    Name = atom_to_list(Function),
    case {lists:suffix("_test", Name), lists:suffix("_test_", Name)} of
        {true, _} -> [{Module, Function}];
        {_, true} -> [{generator, Module, Function}];
        _ -> []
    end.

%% Tests, each one of EUnit's, run Lanes at once: each lane takes the first
%% test no lane has taken yet, runs it, and takes the next once it has
%% ended. So the tests are taken in their order, and a test's limit counts
%% from its own start and not from the run's.
%%
%% A lane's tests are a lazy generator, which EUnit calls as it reaches it,
%% once the lane's test before has ended. EUnit reads ahead into a group's
%% tests as it reads the group, calling a generator it finds there, and a
%% test taken so would never run. So each lane stands in a setup's
%% instantiator, which EUnit calls only as it runs the setup. A lane runs as
%% `{inparallel, 1, ...}`, each of its tests in a process of its own, a
%% generator's among them, so that a limit ends its own test alone.
-spec side_by_side(pos_integer(), [term()]) -> {inparallel, [term()]}.
side_by_side(Lanes, Tests) ->
    Queued = list_to_tuple(Tests),
    Taken = atomics:new(1, []),
    Lane = {inparallel, 1, {setup, local, fun() -> ok end, fun(ok) -> lane(Queued, Taken) end}},
    {inparallel, lists:duplicate(min(Lanes, tuple_size(Queued)), Lane)}.

%% The rest of a lane: the first test of Queued that no lane has taken, by
%% the count Taken that the lanes share, and the lane after it; nothing once
%% every test has been taken.
lane(Queued, Taken) ->
    {generator,
     fun() ->
         case atomics:add_get(Taken, 1, 1) of
             Index when Index =< tuple_size(Queued) ->
                 [element(Index, Queued), lane(Queued, Taken)];
             _ ->
                 []
         end
     end}.
