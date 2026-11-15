%% The tests of the repository's runs of EUnit, each alone: make test's of
%% each root (the repository's Makefile, UNIT_TESTS), the flake hunt's
%% rounds, which take the same tests (ern_flakes), and the areas' under
%% test/ (test/Makefile, EUNIT).
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
-module(ern_eunit).

-export([alone/1]).

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
