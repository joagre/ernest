%% The pseudo-terminal harness, the Ernest program fixtures/pty/pty.ern,
%% which test/Makefile's pty target builds, as the shell's and the
%% terminal's tests call it, and the helpers both share: a command run
%% with a terminal of its own and the steps it is sent, one whose end a
%% watcher tells while the harness reads nothing, a command run without
%% one, and a count of what a screen shows.
-module(ern_pty).

-export([run/3, tried/3, watched/5, watcher/0, settings/2, paste_off/0, run_dir/0, sh/1,
         count/2]).

-include_lib("eunit/include/eunit.hrl").

-type option() :: {size, non_neg_integer(), non_neg_integer()} | screen.

%% A step of the harness's (fixtures/pty/pty.ern), its signal named as the
%% harness names it, `termination`, `hangup` or `interrupt`.
-type step() :: {expect | resize | send | put | signal, string()} | hangup | stall | release.

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
-spec run(string(), [step()], [option()]) -> {integer() | timeout, binary()}.
run(Command, Steps, Options) ->
    {Status, Data, Unmet} = tried(Command, Steps, Options),
    ?assertEqual([], Unmet),
    {Status, Data}.

%% As run/3, for a test that judges a run whose steps were not all met, a
%% program that never answered among them: the harness stops at the first
%% step it cannot meet (fixtures/pty/pty.ern), and `Unmet` holds its line
%% naming the steps left, none where it met them all.
-spec tried(string(), [step()], [option()]) ->
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

%% Command, its last word an `exec`, run by run/3 with Steps after a watcher
%% of its end that outlives it: the watcher reads the named pipe Watched,
%% which the command holds open for writing, to its end, which comes as the
%% command ends, writes the terminal's settings as `stty -g` reads them,
%% and opens the named pipe Ended for reading, which a `put` waits for; the
%% settings the command found are written first (settings/2). So a step
%% after a stall learns of the end, which the harness reads only with the
%% rest.
%%
%% The watcher has a process group of its own, which the runtime's
%% kill of the command's group at its end misses, reads the terminal by a
%% descriptor of its own, since a command the shell runs in the background
%% reads none, and takes no hangup, which the command's end sends the
%% terminal's process group. Its group is killed by its number once the
%% harness has ended, since one whose put was not met waits in its open.
-spec watched(file:filename(), file:filename(), file:filename(), string(), [step()]) ->
          {integer() | timeout, binary()}.
watched(Watcher, Watched, Ended, Command, Steps) ->
    try
        run("exec 6<&0; stty -g > " ++ Watcher ++ ".found; set -m; ( trap '' HUP; read _ < "
            ++ Watched ++ "; stty -g <&6 > " ++ Watcher ++ ".left; : < " ++ Ended
            ++ " ) & echo $! > " ++ Watcher ++ ".pid; set +m; exec 5> " ++ Watched ++ "; "
            ++ Command, Steps, [])
    after
        case file:read_file(Watcher ++ ".pid") of
            {ok, Group} -> _ = os:cmd("kill -KILL -" ++ string:trim(binary_to_list(Group)));
            {error, _} -> ok
        end
    end.

%% The name the files of a watcher of a command's end begin with
%% (watched/5), one of its own under the run's directory.
-spec watcher() -> file:filename().
watcher() ->
    filename:join(run_dir(), "ern_watcher_" ++ os:getpid() ++ "_"
                             ++ integer_to_list(erlang:unique_integer([positive]))).

%% The terminal's settings as `stty -g` read them, as the command found
%% them or as it left them, where a watcher (watched/5) wrote them.
-spec settings(file:filename(), found | left) -> {ok, binary()} | {error, term()}.
settings(Watcher, When) ->
    file:read_file(Watcher ++ "." ++ atom_to_list(When)).

%% Report §12.1: what ends the terminal's bracketed-paste mode, which the
%% end of a program the keys were read for writes.
-spec paste_off() -> binary().
paste_off() ->
    <<"\e[?2004l">>.

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
step({signal, Name}) -> "signal:" ++ Name;
step(hangup) -> "hangup";
step(stall) -> "stall";
step(release) -> "release".

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
