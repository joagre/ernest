%% The shell's host half, src/shell/ern_shell.erl: what its foreign functions
%% answer, without a terminal. The shell run whole is test/ern_shell_tests.erl's.
-module(ern_shell_host_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("cli/include/ern_build.hrl").

%% report §11.1, §4.2: the segment a path component names is the one the
%% path check accepts, since the shell's `:load` completion asks for it
%% rather than restating the rule; a regression test of the one owner
segment_test() ->
    ?assertEqual({'Some', <<"Http">>}, ern_shell:segment(<<"http">>)),
    ?assertEqual({'Some', <<"OrderedSet">>}, ern_shell:segment(<<"ordered_set">>)),
    ?assertEqual('None', ern_shell:segment(<<"Bad">>)).

%% report §11.2, §4.6: the type an input gives a name, `it` among them, is
%% closed as a top-level `let` that is not generalized closes its own, an
%% effect variable left in it none where it stands as a function type's
%% effect, and Never where it stands as a type argument; one a value
%% position holds, or a `receive` that takes anything makes process-only,
%% is still refused, and a lambda that sleeps receives nothing (Appendix
%% E.15). A regression test of the
%% release review's B-S1, written after the fix:
%% the prompt refused a pair of one lambda's type as undetermined, where a
%% module's top-level `let` closes it
input_type_closed_as_a_top_level_let_test() ->
    ern_shell:loaded(#loaded{}),
    Self = self(),
    Pair = <<"List.partition([fn(x : Int) = x], fn(f) = true)">>,
    Inputs = [<<"let p = ", Pair/binary>>, Pair,
              <<"let k = Test.Case(name = \"k\", run = fn() = Test.equal(1, 1))">>,
              <<"let s = List.partition([fn() = self()], fn(f) = true)">>,
              <<"let t = List.partition([fn() = receive { _ -> Unit }], fn(f) = true)">>,
              <<"let w = List.partition([fn() = Clock.sleep(1)], fn(f) = true)">>],
    %% report §11.2: a session's front end runs in a launch, its own screen
    %% the session's, and no local half, whose source root is none
    Main = fun() ->
               Session = ern_shell:start(undefined, self(), <<".">>, <<".">>, false, self()),
               Type = fun(Input) ->
                              case ern_shell:check(Session, {'Prompt', 1}, Input) of
                                  {'Right', {_, Checked}} -> ern_shell:type_text(Checked);
                                  {'Left', Refused} -> Refused
                              end
                      end,
               Self ! {types, [Type(Input) || Input <- Inputs]}
           end,
    try
        ok = ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})
    after
        persistent_term:erase({ern_shell, loaded})
    end,
    [OfLet, OfPair, OfCase, OfS, OfT, OfW] = receive {types, Types} -> Types end,
    ?assertEqual(<<"#(List((Int) -> Int), List((Int) -> Int))">>, OfLet),
    ?assertEqual(<<"#(List((Int) -> Int), List((Int) -> Int))">>, OfPair),
    ?assertEqual(<<"Test.Case(Never)">>, OfCase),
    ?assertEqual(<<"#(List(() -> Unit), List(() -> Unit))">>, OfW),
    Undetermined = fun(Name, Text) ->
                           Said = <<"the type of ", Name/binary,
                                    " is not determined by this input">>,
                           ?assertMatch({_, _}, binary:match(Text, Said))
                   end,
    Undetermined(<<"s">>, OfS),
    Undetermined(<<"t">>, OfT).

%% report §11.2: an input is checked against the prelude's environment
%% that the host built once, at its first session, and no session's record
%% holds that environment, so a check reads none of the standard library's
%% files and the record an input copies stays small. A regression test,
%% written after the fix (the log's *A Line-Mode Input's Cost*): the check
%% built the environment at every input, and the record held it, 52,592
%% words. It does not cover what the record holds beside, the session's
%% interfaces, which grow as the session declares (the plan's MVP 4.0, item
%% 12)
input_checked_against_the_prelude_built_once_test() ->
    ern_shell:loaded(#loaded{}),
    Self = self(),
    Main = fun() ->
               Session = ern_shell:start(undefined, self(), <<".">>, <<".">>, false, self()),
               Prelude = {ern_typecheck, prelude_env, 0},
               1 = erlang:trace_pattern(Prelude, true, [call_count]),
               Answers = [element(1, ern_shell:check(Session, {'Prompt', Count}, <<"1">>))
                          || Count <- [1, 2, 3]],
               {call_count, Built} = erlang:trace_info(Prelude, call_count),
               1 = erlang:trace_pattern(Prelude, false, [call_count]),
               Self ! {checked, Answers, Built, erts_debug:flat_size(Session)}
           end,
    try
        ok = ern_rt:run_main(Main, <<"main">>, #{stdout => fun(_) -> ok end})
    after
        persistent_term:erase({ern_shell, loaded})
    end,
    {Answers, Built, Words} = receive {checked, A, B, W} -> {A, B, W} end,
    ?assertEqual(['Right', 'Right', 'Right'], Answers),
    ?assertEqual(0, Built),
    ?assert(Words < 5000).
