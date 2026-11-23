%% The recorder of two listings a review starts from, run in each host
%% where make test-full runs EUnit (docs/reviews/full.md, release.md):
%% make cover and make slowest run make test-full with EUNIT_TEST naming
%% this module's test function in place of EUnit's, which runs the same
%% tests and records what its environment asks.
%%
%% Where ERN_COVER_DIR names a directory, the host runs the toolchain's own
%% Erlang (own/0) as covered/1 compiled it there, each module
%% loaded under its own file's name, and records the lines each ran.
%% OTP's cover would load each as `cover_compiled`, and the tree is found
%% from where ern_tree was loaded (ern_tree:tree/0), so the host's own line
%% coverage is used, the counters cover itself reads. Where ERN_TIMES_DIR
%% names one, an EUnit listener records each test's time as EUnit gives it.
%% Each host writes a file of its own, named by its operating system's
%% process number and the moment it ended, and uncovered/1 and
%% tools/slowest.ern read them all.
%%
%% A host bin/ern starts, a program's run, a node, a peer and a shell, runs
%% the toolchain as it was built: the launcher clears the host's flags from
%% the environment and ends the host by halt/2 (ern_cli), so no line it
%% runs is recorded.
-module(ern_recorder).

-behaviour(eunit_listener).

-export([covered/1, compiled/2, test/1, test/2, loaded/2, uncovered/1, stretches/1, start/1,
         init/1, handle_begin/3, handle_end/3, handle_cancel/3, terminate/2]).

%% The toolchain's own Erlang (ern_tree:own_code/0) but what it vendors, a
%% module whose name does not begin `ern`, as make xref and make sizes
%% leave the vendored getopt out.
own() ->
    [Beam || Beam <- ern_tree:own_code(), lists:prefix("ern", filename:basename(Beam))].

%% Each module of the toolchain's own Erlang compiled from its abstract
%% code with the host's line coverage, into Directory/beams, a module's
%% under its name. Every module is compiled in a process of its own.
-spec covered(file:filename()) -> ok.
covered(Directory) ->
    Beams = filename:join(Directory, "beams"),
    ok = filelib:ensure_path(Beams),
    Self = self(),
    Compiling = [spawn_link(fun() -> Self ! {self(), compiled(Beam, Beams)} end)
                 || Beam <- own()],
    [ok = receive {Pid, Compiled} -> Compiled end || Pid <- Compiling],
    ok.

%% A module compiled with line coverage into the directory Beams.
-spec compiled(file:filename(), file:filename()) -> ok | {error, file:posix()}.
compiled(Beam, Beams) ->
    {Module, Forms} = forms(Beam),
    {ok, Module, Binary} = compile:forms(Forms, [binary, line_coverage, return_errors]),
    file:write_file(filename:join(Beams, filename:basename(Beam)), Binary).

%% A module's name and its abstract code, which make compiles into every
%% module (+debug_info).
forms(Beam) ->
    {ok, {Module, [{debug_info, {debug_info_v1, Backend, Data}}]}} =
        beam_lib:chunks(Beam, [debug_info]),
    {ok, Forms} = Backend:debug_info(erlang_v1, Module, Data, []),
    {Module, Forms}.

%% EUnit's own test function, with what ERN_COVER_DIR and ERN_TIMES_DIR ask
%% recorded around it.
-spec test(term()) -> ok | error | {error, term()}.
test(Tests) ->
    test(Tests, []).

-spec test(term(), [term()]) -> ok | error | {error, term()}.
test(Tests, Options) ->
    Cover = os:getenv("ERN_COVER_DIR"),
    case Cover of
        false -> ok;
        _ -> load_covered(Cover)
    end,
    Report = case os:getenv("ERN_TIMES_DIR") of
                 false -> [];
                 Times -> [{report, {?MODULE, [{file, recorded(Times, ".times")}]}}]
             end,
    Result = eunit:test(Tests, Report ++ Options),
    case Cover of
        false -> ok;
        _ -> write_lines(Cover)
    end,
    Result.

%% Each module covered/1 compiled, loaded in place of the one built, under
%% the name of the file the host's code path finds, or the tree's where no
%% directory of the path holds it, a shim's, so that code:which/1 answers
%% as it does in a host that records nothing and the tree is found as it is
%% found there (loaded/2). The host's coverage mode is line as they load,
%% and none again after, so that a unit a test loads is loaded as it would
%% be.
%%
%% The compiler's build, which a compiled module records, is digested from
%% its code as loaded (ern_build:compiler_build/0), so it is found first,
%% from the built code, and a module this host compiles is one a host
%% bin/ern starts reads as of its own build.
load_covered(Directory) ->
    _ = ern_build:compiler_build(),
    Mode = code:set_coverage_mode(line),
    Own = [{Beam, code:which(list_to_atom(filename:basename(Beam, ".beam")))}
           || Beam <- own()],
    [loaded(if is_list(Found) -> Found; true -> Beam end,
            filename:join([Directory, "beams", filename:basename(Beam)]))
     || {Beam, Found} <- Own],
    _ = code:set_coverage_mode(Mode),
    ok.

%% The module of the file Beam loaded from the file Covered, under Beam's
%% name made absolute from the host's working directory, as the host's code
%% server names a file it loads from a relative directory of its path, so
%% that a module that finds a file from its own, ern_os the helper's,
%% finds it after a test or an example's run has entered another directory
%% (ern_examples:in_directory/3).
-spec loaded(file:filename(), file:filename()) -> {module, module()}.
loaded(Beam, Covered) ->
    Module = list_to_atom(filename:basename(Beam, ".beam")),
    {ok, Binary} = file:read_file(Covered),
    _ = code:purge(Module),
    {module, Module} = code:load_binary(Module, filename:absname(Beam), Binary).

%% The lines of each module the host ran and did not, by the module.
write_lines(Directory) ->
    Lines = [{Module, Covered}
             || Beam <- own(),
                Module <- [list_to_atom(filename:basename(Beam, ".beam"))],
                {ok, Covered} <- [coverage(Module)]],
    ok = file:write_file(recorded(filename:join(Directory, "runs"), ".lines"),
                         term_to_binary(Lines)).

coverage(Module) ->
    try {ok, code:get_coverage(line, Module)}
    catch error:badarg -> error
    end.

%% A file of this host's own in Directory, by its process number and the
%% moment it is named.
recorded(Directory, Extension) ->
    filename:join(Directory, os:getpid() ++ "-"
                  ++ integer_to_list(os:system_time(microsecond)) ++ Extension).

%% The listing of the lines no host ran: each module of the toolchain's own
%% Erlang in the order of its source's path, with its counts of lines run and
%% not run, and each stretch of lines not run with no line run between them,
%% by its source's path, its lines and the function it is in. A line is run
%% where any host ran it. The last line counts the hosts that recorded and
%% the lines.
-spec uncovered(file:filename()) -> ok.
uncovered(Directory) ->
    Runs = filelib:wildcard(filename:join([Directory, "runs", "*.lines"])),
    Joined = lists:foldl(fun(Run, Acc) -> joined(Run, Acc) end, #{}, Runs),
    Modules = lists:sort([{source(Forms), Module, Forms}
                          || Beam <- own(), {Module, Forms} <- [forms(Beam)]]),
    Counts = [listed(Source, Forms, maps:get(Module, Joined, #{}))
              || {Source, Module, Forms} <- Modules],
    {Run, NotRun} = lists:foldl(fun({R, N}, {RAcc, NAcc}) -> {RAcc + R, NAcc + N} end, {0, 0},
                                Counts),
    io:format("~nThe records of ~b hosts: ~b modules, ~b lines run and ~b not run.~n",
              [length(Runs), length(Modules), Run, NotRun]).

%% A host's record joined to the others': each line run where any ran it.
joined(Run, Acc) ->
    {ok, Binary} = file:read_file(Run),
    lists:foldl(fun({Module, Covered}, Joined) ->
                        Lines = maps:get(Module, Joined, #{}),
                        Joined#{Module => lists:foldl(fun ran/2, Lines, Covered)}
                end, Acc, binary_to_term(Binary)).

ran({Line, Ran}, Lines) ->
    Lines#{Line => Ran orelse maps:get(Line, Lines, false)}.

%% The source's path as make gave it to erlc, from the module's first file
%% attribute.
source([{attribute, _, file, {Source, _}} | _]) -> Source;
source([_ | Forms]) -> source(Forms).

%% A module's lines printed, and its counts.
listed(Source, Forms, Lines) ->
    Sorted = lists:sort(maps:to_list(Lines)),
    Run = length([Line || {Line, true} <- Sorted]),
    NotRun = length(Sorted) - Run,
    io:format("~ts: ~b lines run, ~b not run~n", [Source, Run, NotRun]),
    Functions = lists:sort([{erl_anno:line(Anno), Name, Arity}
                            || {function, Anno, Name, Arity, _} <- Forms]),
    [io:format("  ~ts:~ts  ~ts~n", [Source, span(First, Last), function(First, Functions)])
     || {First, Last} <- stretches(Sorted)],
    {Run, NotRun}.

%% The stretches of lines not run, each its first line and its last, with
%% no line run between them.
-spec stretches([{pos_integer(), boolean()}]) -> [{pos_integer(), pos_integer()}].
stretches(Lines) ->
    stretches(Lines, none, []).

stretches([], none, Acc) -> lists:reverse(Acc);
stretches([], Open, Acc) -> lists:reverse([Open | Acc]);
stretches([{Line, false} | Rest], none, Acc) -> stretches(Rest, {Line, Line}, Acc);
stretches([{Line, false} | Rest], {First, _}, Acc) -> stretches(Rest, {First, Line}, Acc);
stretches([{_, true} | Rest], none, Acc) -> stretches(Rest, none, Acc);
stretches([{_, true} | Rest], Open, Acc) -> stretches(Rest, none, [Open | Acc]).

span(Line, Line) -> integer_to_list(Line);
span(First, Last) -> integer_to_list(First) ++ "-" ++ integer_to_list(Last).

%% The function a line is in: the last whose first line is not after it.
function(Line, Functions) ->
    case [{Name, Arity} || {Start, Name, Arity} <- Functions, Start =< Line] of
        [] -> "";
        Before -> {Name, Arity} = lists:last(Before), io_lib:format("~p/~b", [Name, Arity])
    end.

%%
%% The listener of each test's time
%%

-spec start([{file, file:filename()}]) -> pid().
start(Options) ->
    eunit_listener:start(?MODULE, Options).

%% The file the times go to, and the times, each test's milliseconds,
%% module, function and description, the last first.
-spec init([{file, file:filename()}]) -> {file:filename(), [iodata()]}.
init(Options) ->
    {proplists:get_value(file, Options), []}.

-spec handle_begin(group | test, [term()], State) -> State.
handle_begin(_, _, State) ->
    State.

%% A test's time as EUnit gives it, its source's module and function, and
%% its description, empty where it has none, a line tools/slowest.ern
%% reads, a tab or a line break in the description a space.
-spec handle_end(group | test, [term()], State) -> State when
      State :: {file:filename(), [iodata()]}.
handle_end(test, Data, {File, Times}) ->
    {Module, Function, _} = proplists:get_value(source, Data),
    Time = proplists:get_value(time, Data),
    Description = case proplists:get_value(desc, Data) of
                      undefined -> <<>>;
                      Text -> re:replace(Text, "[\t\r\n]", " ", [global, unicode, {return, binary}])
                  end,
    {File, [[integer_to_binary(Time), $\t, atom_to_binary(Module), $\t,
             atom_to_binary(Function), $\t, Description, $\n] | Times]};
handle_end(group, _, State) ->
    State.

-spec handle_cancel(group | test, [term()], State) -> State.
handle_cancel(_, _, State) ->
    State.

-spec terminate(term(), {file:filename(), [iodata()]}) -> ok.
terminate(_, {File, Times}) ->
    ok = file:write_file(File, lists:reverse(Times)).
