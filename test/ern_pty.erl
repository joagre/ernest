%% The pseudo-terminal harness, the Ernest program fixtures/pty/pty.ern,
%% which test/Makefile's pty target builds, as the shell's and the
%% terminal's tests call it, and the helpers both share: a command run
%% with a terminal of its own and the steps it is sent, a command run
%% without one, and a count of what a screen shows.
-module(ern_pty).

-export([run/3, run_dir/0, sh/1, count/2]).

-include_lib("eunit/include/eunit.hrl").

-type option() :: {size, non_neg_integer(), non_neg_integer()} | screen.

%% Command with a terminal of its own, under the harness's Options, the
%% terminal's size, 24 rows and 80 columns where none is given, and
%% `screen`: {exit status, what the program wrote, or with `screen` the
%% screen as a reader sees it}, the status `timeout` where it did not end.
%%
%% The steps are the harness's, `{expect, Text}` before a `{send, Hex}` so
%% that a program slower under load is waited for rather than raced; a step
%% the harness could not meet fails the test. Each wait the harness runs,
%% an expect's and the program's end, is a step of the test's
%% (ern_nodes_tests:step/2), bounded by the time for one wait
%% (ern_nodes_tests:wait_ms/0), so that the session's bound is its steps'
%% sum, to which the harness's run is held too (ern_nodes_tests:collected/2),
%% and a step that fails is told by its own bound before the test's runs
%% out.
-spec run(string(), [tuple()], [option()]) -> {integer() | timeout, binary()}.
run(Command, Steps, Options) ->
    File = steps_file(Steps),
    Arguments = ["--timeout", integer_to_list(ern_nodes_tests:wait_ms()), "--steps", File]
                ++ lists:append([option(Option) || Option <- Options]) ++ ["--", Command],
    {0, Output} = ern_nodes_tests:collected(harness(Arguments),
                                            length([Text || {expect, Text} <- Steps]) + 1),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    ?assertEqual([], [Line || <<"unmet ", _/binary>> = Line <- Lines]),
    [<<"status ", Status/binary>>] = [Line || <<"status ", _/binary>> = Line <- Lines],
    [<<"data ", Data/binary>>] = [Line || <<"data ", _/binary>> = Line <- Lines],
    {status(Status), base64:decode(Data)}.

option({size, Rows, Columns}) ->
    ["--size", integer_to_list(Rows) ++ "x" ++ integer_to_list(Columns)];
option(screen) ->
    ["--screen"].

%% The directory a run of the tests makes what it needs under, its homes,
%% sources, inputs and step files: the one `make` makes for the run and
%% removes when it ends, or the host's for a run of a test by itself.
-spec run_dir() -> file:filename().
run_dir() ->
    os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")).

%% The steps go in a file, which the harness reads a step a line from: a
%% step holds whatever the program prints.
steps_file(Steps) ->
    File = filename:join(run_dir(), "steps-" ++ os:getpid() ++ "_"
                                    ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, [[step(Step), "\n"] || Step <- Steps]),
    File.

step({expect, Text}) -> "expect:" ++ Text;
step({resize, Size}) -> "resize:" ++ Size;
step({send, Hex}) -> "send:" ++ Hex;
step({put, Path}) -> "put:" ++ Path.

status(<<"timeout">>) -> timeout;
status(Text) -> binary_to_integer(Text).

%% A command run by the host's shell: its exit status and what it wrote to
%% its output and its standard error, a step of the test's, a session whose
%% inputs a file gives among them. The command is the shell's argument as
%% it stands, a variable's setting before it among what it may hold.
-spec sh(string()) -> {non_neg_integer(), binary()}.
sh(Command) ->
    ern_nodes_tests:collected(shell(Command), 1).

%% The port of the harness run with Arguments, which reach it as they are,
%% so that the command reaches it whole, a quote or a `;` among it, and
%% the harness runs it under `/bin/sh -c`; its standard error beside its
%% standard output.
harness(Arguments) ->
    open_port({spawn_executable, "../bin/ern"},
              [{args, ["run", "build/pty/pty.erc" | Arguments]},
               exit_status, stderr_to_stdout, binary]).

%% The port of the host's shell running Command, its standard error beside
%% its standard output.
shell(Command) ->
    open_port({spawn_executable, "/bin/sh"},
              [{args, ["-c", Command]}, exit_status, stderr_to_stdout, binary]).

%% How many times Needle stands in Haystack.
-spec count(binary(), binary()) -> non_neg_integer().
count(Haystack, Needle) ->
    length(binary:matches(Haystack, Needle)).
