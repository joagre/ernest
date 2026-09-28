%% make untested (docs/coherence.md C13): the functions of the toolchain
%% that make test never runs. A host started with +JPcover function keeps
%% the host's own count of every function of every module it loads, with
%% nothing recompiled. make untested runs make test with every host given
%% this module through ERL_AFLAGS and every EUnit run given it as a
%% listener, so that each host that ran the toolchain writes the functions
%% it ran into the directory ERN_COVERAGE names; report/0 then prints each
%% function of the toolchain that no host ran.
-module(ern_cover).
-behaviour(eunit_listener).

-export([launched/0, report/0]).
-export([start/0, start/1, init/1, handle_begin/3, handle_end/3, handle_cancel/3,
         terminate/2]).

%% A host the launcher started, which names its program ern and whose
%% `-run ern_cli start` follows this module's in ERL_AFLAGS: the
%% launcher's work run, what it ran written, and the host ended as the
%% launcher ends it. Any other host is left to its own commands.
-spec launched() -> ok.
launched() ->
    Names = case init:get_argument(progname) of
                {ok, Ns} -> Ns;
                error -> []
            end,
    case lists:reverse(Names) of
        [["ern"] | _] ->
            Status = ern_cli:launched(init:get_plain_arguments()),
            write(),
            ern_cli:finish(Status);
        _ ->
            ok
    end.

%% EUnit's listener: at the end of a run, before the host halts, what the
%% run ran is written.
-spec start() -> pid().
start() ->
    start([]).

-spec start(list()) -> pid().
start(Options) ->
    eunit_listener:start(?MODULE, Options).

-spec init(list()) -> none.
init(_) ->
    none.

-spec handle_begin(atom(), list(), none) -> none.
handle_begin(_, _, State) ->
    State.

-spec handle_end(atom(), list(), none) -> none.
handle_end(_, _, State) ->
    State.

-spec handle_cancel(atom(), list(), none) -> none.
handle_cancel(_, _, State) ->
    State.

-spec terminate(term(), none) -> ok.
terminate(_, _) ->
    write().

%% The functions of the toolchain's loaded modules this host ran, in a
%% file of its own.
write() ->
    Ran = [{M, [FA || {FA, true} <- code:get_coverage(function, M)]}
           || {M, _} <- code:all_loaded(), toolchain(M),
              code:get_coverage_mode(M) =:= function],
    File = filename:join(os:getenv("ERN_COVERAGE"),
                         os:getpid() ++ "-" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:write_file(File, term_to_binary(Ran)).

toolchain(M) ->
    Name = atom_to_list(M),
    lists:prefix("ern_", Name) andalso not lists:suffix("_tests", Name) andalso M =/= ern_cover.

%% Each function of the toolchain's modules that no host ran and that is
%% not decided below, a line each, with how many of how many; a fun is its
%% function's, and module_info the host's. A decision that no longer holds,
%% a function below that a host ran or that is gone, is printed too. The
%% check fails where it prints one.
-spec report() -> no_return().
report() ->
    Ran = sets:from_list([{M, F, A} || File <- filelib:wildcard(os:getenv("ERN_COVERAGE") ++ "/*"),
                                       {M, FAs} <- binary_to_term(element(2, file:read_file(File))),
                                       {F, A} <- FAs]),
    Modules = [list_to_atom(filename:basename(F, ".beam"))
               || F <- filelib:wildcard("erl/*/ebin/ern_*.beam"),
                  not lists:suffix("_tests.beam", F)],
    All = [{M, F, A} || M <- Modules, {F, A} <- M:module_info(functions),
                        F =/= module_info, hd(atom_to_list(F)) =/= $-],
    Never = [MFA || MFA <- All, not sets:is_element(MFA, Ran)],
    Decided = [MFA || {MFA, _} <- unreached()],
    New = Never -- Decided,
    Stale = [MFA || MFA <- Decided, not lists:member(MFA, Never)],
    [io:format("~s:~s/~B~n", [M, F, A]) || {M, F, A} <- lists:sort(New)],
    [io:format("~s:~s/~B is decided below as never run, and is run or gone~n", [M, F, A])
     || {M, F, A} <- Stale],
    io:format("make untested: ~B of the toolchain's ~B functions never run, "
              "~B of them decided in tools/ern_cover.erl~n",
              [length(Never), length(All), length(Never -- New)]),
    halt(case New ++ Stale of [] -> 0; _ -> 1 end).

%% The functions make test cannot run, or cannot see run, each decided and
%% why. A function joins only where a test cannot reach it; a missing test
%% is written instead.
unreached() ->
    [{{ern_cli, start, 0}, "the launcher's entry, which a measured host runs through this module"},
     {{ern_cli, finish, 1}, "the launcher's end, run in every launch after the count is written"},
     {{ern_signals, ended, 0}, "run by the launcher's end after the count is written"},
     {{ern_signals, die, 2},
      "run by the launcher's end after the count is written, and by a signal that ends a "
      "job, which ends the host before it writes its count"},
     {{ern_signals, handle_call, 2}, "a callback gen_event requires, which nothing calls"},
     {{ern_tty_signal, handle_call, 2}, "a callback gen_event requires, which nothing calls"},
     {{ern_io, show, 1},
      "Io.show's own implementation, which the emitter writes past at every call and every "
      "use as a value, by the argument's type (report Appendix E.1)"},
     {{ern_rt, undefined_lambda, 3},
      "the host's error handler for a fun of a module that is not loaded, which no program "
      "on one node holds"},
     {{ern_os, over, 1},
      "a run that ends while no read of it waits, a moment inside Os.run's own reading that "
      "no test can place"},
     {{ern_os, helper_failed, 0},
      "a helper that fails as it starts or ends with no status, which a test cannot cause "
      "without breaking the installation"},
     {{ern_tty, flush_port, 1}, "an stty that does not end within two seconds"}].
