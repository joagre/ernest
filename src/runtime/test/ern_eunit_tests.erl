%% The repository's runs of EUnit side by side (ern_eunit:side_by_side/2),
%% each run inside a test by EUnit, with a listener of this module's that
%% answers the run's counts: how many tests the lanes run at once, the order
%% they take the tests in, and what a test's time limit ends. The tests of
%% ern_eunit:alone/1 are ern_flakes_tests', beside the hunt's that take them.
-module(ern_eunit_tests).

-behaviour(eunit_listener).

-include_lib("eunit/include/eunit.hrl").

-export([start/1, init/1, handle_begin/3, handle_end/3, handle_cancel/3, terminate/2]).

%% The test a run answers its counts to, and the run's reference.
-type answer() :: {pid(), reference()}.

%% docs/architecture.md, *Alone*: of seven tests that each run until this
%% test lets them end, three lanes run three at once, and no more; the
%% first of them to end makes room at once for the next in the tests'
%% order, while the other two still run; and each test runs once and is
%% counted. Each test counts itself in Running as it begins and out as it
%% ends, and says the count it began at.
%%
%% A regression test, written after the code. It does not cover the order
%% of two tests that two lanes freed at once take, which no test can tell.
lanes_take_the_next_test_as_one_ends_test() ->
    Test = self(),
    Running = atomics:new(1, []),
    Run = ran(ern_eunit:side_by_side(3, [fun() -> held(Test, Running, Index) end
                                         || Index <- lists:seq(1, 7)])),
    First = [began() || _ <- lists:seq(1, 3)],
    ?assertEqual({[1, 2, 3], [1, 2, 3]}, {lists:sort([Index || {Index, _, _} <- First]),
                                          lists:sort([Count || {_, _, Count} <- First])}),
    ended(lists:sort([{Index, Pid} || {Index, Pid, _} <- First]), 4, 7),
    ?assertEqual({ok, [{pass, 7}, {fail, 0}, {skip, 0}, {cancel, 0}]}, answered(Run)),
    receive
        {began, _, _, _} = Again -> ?assertEqual(nothing, Again)
    after 0 ->
        ok
    end.

%% A test of the lanes: it counts itself in Running, tells Test that it has
%% begun at that count, and ends once Test lets it, counted out first.
held(Test, Running, Index) ->
    Test ! {began, Index, self(), atomics:add_get(Running, 1, 1)},
    receive
        {ends, Test} -> atomics:sub(Running, 1, 1)
    end.

%% The next test to tell that it has begun: its index, its process and the
%% count it began at.
began() ->
    receive
        {began, Index, Pid, Count} -> {Index, Pid, Count}
    end.

%% The tests Held let end, the first first, and as each ends the next of the
%% tests, Next, begun at once, beside the two that still run, up to Last.
ended([], _, _) ->
    ok;
ended([{_, Pid} | Held], Next, Last) ->
    Pid ! {ends, self()},
    case Next =< Last of
        true ->
            {Index, Begun, Count} = began(),
            ?assertEqual({Next, 3}, {Index, Count}),
            ended(Held ++ [{Index, Begun}], Next + 1, Last);
        false ->
            ended(Held, Next, Last)
    end.

%% test/Makefile's EUNIT_SIDE_BY_SIDE, docs/architecture.md, *Alone*:
%% alone/1's tests side by side in one lane, so that they run one after
%% another. A test past its limit is ended alone, a test function's and one
%% of a generator's. The test after it in its generator, and the test after
%% both in the lane, run and are counted. That last test's limit is as
%% short, and it waited for its lane longer than that, so its limit counts
%% its own time alone.
%%
%% A regression test, written after the code. It does not cover a generator
%% that raises.
limits_end_their_own_tests_test() ->
    Module = ern_helpers:loaded(ern_eunit_limits, [
        %% each waits for a message no one sends, which its limit ends
        "passes_its_limit_test_() -> {timeout, 0.1, fun() -> receive never -> ok end end}.",
        "generator_test_() -> [fun() -> ok end,"
        " {timeout, 0.1, fun() -> receive never -> ok end end}, fun() -> ok end].",
        "after_the_limits_test_() -> {timeout, 0.1, fun() -> ok end}."]),
    try
        ?assertEqual({error, [{pass, 3}, {fail, 0}, {skip, 0}, {cancel, 2}]},
                     answered(ran(ern_eunit:side_by_side(1, ern_eunit:alone([Module])))))
    after
        ern_helpers:unloaded(Module)
    end.

%% docs/architecture.md, *Alone*: a failing test fails the run, which counts
%% it, and the tests beside it pass. A regression test, written after the
%% code.
a_failure_fails_the_run_test() ->
    Run = ran(ern_eunit:side_by_side(2, [fun() -> ok end, fun() -> error(fails) end,
                                         fun() -> ok end])),
    ?assertEqual({error, [{pass, 2}, {fail, 1}, {skip, 0}, {cancel, 0}]}, answered(Run)).

%% Tests run by EUnit in a process of their own, with no output, its answer
%% and its counts sent to this test under the run's reference, which
%% answered/1 takes.
ran(Tests) ->
    Test = self(),
    Ref = make_ref(),
    _ = spawn_link(fun() ->
                       Answer = eunit:test(Tests, [no_tty, {report, {?MODULE, {Test, Ref}}}]),
                       Test ! {Ref, answer, Answer}
                   end),
    Ref.

%% EUnit's answer to the run Ref and its counts, once it has ended.
answered(Ref) ->
    receive
        {Ref, answer, Answer} ->
            receive
                {Ref, counts, {ok, Counts}} -> {Answer, Counts}
            end
    end.

%% The listener ran/1 gives EUnit: as the run ends it sends the test that
%% ran it the run's counts, its passes, failures, skips and cancels.
-spec start(answer()) -> pid().
start(Answer) ->
    eunit_listener:start(?MODULE, [{answer, Answer}]).

-spec init(proplists:proplist()) -> answer().
init(Options) ->
    proplists:get_value(answer, Options).

-spec handle_begin(group | test, list(), answer()) -> answer().
handle_begin(_, _, Answer) ->
    Answer.

-spec handle_end(group | test, list(), answer()) -> answer().
handle_end(_, _, Answer) ->
    Answer.

-spec handle_cancel(group | test, list(), answer()) -> answer().
handle_cancel(_, _, Answer) ->
    Answer.

-spec terminate({ok, list()} | {error, term()}, answer()) -> ok.
terminate(Counted, {Test, Ref}) ->
    Test ! {Ref, counts, Counted},
    ok.
