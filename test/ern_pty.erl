%% The pseudo-terminal harness, the Ernest program fixtures/pty/pty.ern,
%% which test/Makefile's pty target builds, as the shell's and the
%% terminal's tests call it, and the helpers both share: a command run
%% with a terminal of its own and the steps it is sent, a command run
%% without one, and a count of what a screen shows.
-module(ern_pty).

-export([run/3, tried/3, run_dir/0, sh/1, count/2]).

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
-spec run(string(), [tuple() | hangup], [option()]) -> {integer() | timeout, binary()}.
run(Command, Steps, Options) ->
    {Status, Data, Unmet} = tried(Command, Steps, Options),
    ?assertEqual([], Unmet),
    {Status, Data}.

%% As run/3, for a test that judges a run whose steps were not all met, a
%% program that never answered among them: the harness stops at the first
%% step it cannot meet (fixtures/pty/pty.ern), and `Unmet` holds its line
%% naming the steps left, none where it met them all.
-spec tried(string(), [tuple() | hangup], [option()]) ->
          {integer() | timeout, binary(), [binary()]}.
tried(Command, Steps, Options) ->
    Arguments = ["--timeout", integer_to_list(ern_nodes_tests:wait_ms())]
                ++ lists:append([["--step", step(Step)] || Step <- Steps])
                ++ lists:append([option(Option) || Option <- Options]) ++ ["--", Command],
    {0, Output} = ern_nodes_tests:collected(harness(Arguments),
                                            length([Text || {expect, Text} <- Steps]) + 1),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    [<<"status ", Status/binary>>] = [Line || <<"status ", _/binary>> = Line <- Lines],
    [<<"data ", Data/binary>>] = [Line || <<"data ", _/binary>> = Line <- Lines],
    {status(Status), base64:decode(Data), [Line || <<"unmet ", _/binary>> = Line <- Lines]}.

option({size, Rows, Columns}) ->
    ["--size", integer_to_list(Rows) ++ "x" ++ integer_to_list(Columns)];
option(screen) ->
    ["--screen"].

%% The directory a run of the tests makes what it needs under, its homes,
%% sources and inputs: the one `make` makes for the run and removes when it
%% ends, or the host's for a run of a test by itself.
-spec run_dir() -> file:filename().
run_dir() ->
    os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")).

%% A step as the harness's argument, which reaches it whole (harness/1).
%% An expect's text holds no line feed: the terminal writes a program's
%% line feed as a carriage return and a line feed, so such a text could
%% never be met, and a step that is refused tells the test's own mistake.
step({expect, Text}) ->
    not lists:member($\n, Text) orelse error({expect_holds_a_line_feed, Text}),
    "expect:" ++ Text;
step({resize, Size}) -> "resize:" ++ Size;
step({send, Hex}) -> "send:" ++ Hex;
step({put, Path}) -> "put:" ++ Path;
step(hangup) -> "hangup".

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
%% so that a step and the command reach it whole, a quote or a `;` among
%% them, and the harness runs the command under `/bin/sh -c`; its standard
%% error beside its standard output.
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
