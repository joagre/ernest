%% A program run as the runner runs it (report §8.5, §11.2), for the tests
%% of programs: its module type-checked, compiled, loaded and initialized,
%% its main run with an empty standard input, and what it writes collected.
%% The emitter's tests and the runtime's share it.
-module(ern_program).

-export([run/1, run/2, run_at_terminal/1, run/3, run_loaded/2, run_modules/1, init/1,
         collect/1, scratch/0]).

%% Type-check, compile, load, initialize, and run a program's main as the
%% runner does, with an empty standard input, collecting what reaches
%% stdout.
-spec run(unicode:chardata()) -> {ern_rt:outcome(), Output :: binary()}.
run(Text) ->
    run(['M'], Text).

-spec run([atom()], unicode:chardata()) -> {ern_rt:outcome(), Output :: binary()}.
run(Namespace, Text) ->
    run(Namespace, Text, #{}).

%% The same with keys that can come, as at a terminal, of which none does.
-spec run_at_terminal(unicode:chardata()) -> {ern_rt:outcome(), Output :: binary()}.
run_at_terminal(Text) ->
    run(['M'], Text, #{keys => fun() -> receive after infinity -> eof end end}).

%% `standard => true` compiles the module as the standard library's own.
-spec run([atom()], unicode:chardata(), map()) -> {ern_rt:outcome(), Output :: binary()}.
run(Namespace, Text, Options) ->
    {ok, Typed, Interface, Env} = ern_typecheck:check_string(Namespace, Text),
    Build = #{source_hash => <<>>, deps => [], standard => maps:get(standard, Options, false)},
    {ok, ErlangModule, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
    run_loaded(ErlangModule, Options).

%% The same of a unit loaded already.
-spec run_loaded(module(), map()) -> {ern_rt:outcome(), Output :: binary()}.
run_loaded(ErlangModule, Options) ->
    Self = self(),
    %% standard error is read with standard output, where `Io.debug` writes
    %% (Appendix E.1), unless the test reads it apart
    Collect = fun(Written) -> Self ! {out, Written} end,
    Result = ern_rt:run_main(fun() -> (ern_named:main(ErlangModule))() end, <<"main">>,
                             (maps:merge(#{stderr => Collect}, maps:remove(standard, Options)))
                                 #{init => fun() -> init(ErlangModule) end, stdout => Collect,
                                   stdin => fun() -> eof end}),
    {Result, collect([])}.

%% The same of a program of several modules, each {Namespace, Text}, in the
%% order a build compiles them, each checked against the compiled
%% interfaces of those before it (report §11.1), the last one's main run
%% once each module is initialized (§8.5).
-spec run_modules([{[atom()], unicode:chardata()}]) -> {ern_rt:outcome(), Output :: binary()}.
run_modules(Sources) ->
    {ErlangModules, _} =
        lists:mapfoldl(fun({Namespace, Text}, Interfaces) ->
                           {ok, Declarations} = ern_parser:parse_string(Text),
                           {ok, Typed, Interface, Env} =
                               ern_typecheck:check(Namespace, Declarations, Interfaces),
                           {ok, ErlangModule, Beam} =
                               ern_compile:compile(Namespace, Typed, Interface, Env),
                           {module, ErlangModule} = code:load_binary(ErlangModule, "test", Beam),
                           {ok, #{interface := Compiled}} = ern_interface:read(Beam),
                           {ErlangModule, Interfaces ++ [Compiled]}
                       end, [], Sources),
    Self = self(),
    Collect = fun(Written) -> Self ! {out, Written} end,
    Result = ern_rt:run_main(fun() -> (ern_named:main(lists:last(ErlangModules)))() end,
                             <<"main">>,
                             #{init => fun() -> lists:foreach(fun init/1, ErlangModules) end,
                               stdout => Collect, stderr => Collect, stdin => fun() -> eof end}),
    {Result, collect([])}.

%% The runner's job (report §8.5): top-level lets before main.
-spec init(module()) -> term().
init(ErlangModule) ->
    case erlang:function_exported(ErlangModule, '$init', 0) of
        true -> ErlangModule:'$init'();
        false -> ok
    end.

%% What a run wrote, the `{out, Text}` messages in the caller's mailbox in
%% the order they came, after those of Acc, the latest first.
-spec collect([binary()]) -> binary().
collect(Acc) ->
    receive
        {out, Text} -> collect([Text | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

%% A directory of the test's own, for a program to leave a mark in, named
%% by the run and a count so that no earlier run's is read; the test
%% removes it once it has what it needs, and the run's own directory, which
%% `make` removes when the run ends (RUN_UNIT_TESTS), holds it, so that
%% none is left where a test does not.
-spec scratch() -> file:filename().
scratch() ->
    ern_helpers:tmp("ern_os_").
