%% The harness's own steps (ern_harness): a test's count of the waits it
%% runs, which no node, shell or program of these tests is needed to hold.
-module(ern_harness_tests).

-include_lib("eunit/include/eunit.hrl").

%% the log's *The Harness Counts a Test's Steps*: a step past a test's
%% count fails the test at once, naming the step and the count, and a
%% failed test leaves no count behind in its process. A regression test,
%% written after the counter; it does not cover a step taken in another
%% process, which counts nothing.
steps_past_the_count_test() ->
    {timeout, _, {_, Counted}} = ern_harness:counted_test({waits, 1}, fun two_steps/0),
    ?assertError({steps_past_the_count, 1, second}, Counted()),
    ?assertEqual(undefined, ern_harness:counting()).

two_steps() ->
    ern_harness:step(first),
    ern_harness:step(second).

%% the log's *The Harness Counts a Test's Steps*: a test that ends short
%% of its count fails, naming the steps it took and its count. A regression
%% test, written after the counter.
fewer_steps_than_counted_test() ->
    {timeout, _, {_, Counted}} = ern_harness:counted_test({waits, 2}, fun one_step/0),
    ?assertError({fewer_steps_than_counted, 1, 2}, Counted()),
    ?assertEqual(undefined, ern_harness:counting()).

one_step() ->
    ern_harness:step(first).
