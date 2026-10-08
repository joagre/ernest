%% The pseudo-terminal harness, ern_pty.py, as the shell's and the
%% terminal's tests call it, and the helpers both share: a command run
%% with a terminal of its own and the steps it is sent, a command run
%% without one, and a count of what a screen shows.
-module(ern_pty).

-export([run/4, run_dir/0, sh/1, count/2]).

-include_lib("eunit/include/eunit.hrl").

%% Command with a terminal of its own, under the harness's options Extra:
%% {exit status, what the program wrote}, the status `timeout` where it did
%% not end. The steps are the harness's, `{expect, Text}` before a
%% `{send, Hex}` so that a program slower under load is waited for rather
%% than raced; a step the harness could not meet fails the test. The
%% command is one word to the shell that starts the harness, since its own
%% `;` and `|` belong to the shell inside the terminal; it may hold no
%% single quote.
-spec run(string(), [tuple()], pos_integer(), string()) -> {integer() | timeout, binary()}.
run(Command, Steps, Seconds, Extra) ->
    nomatch = binary:match(unicode:characters_to_binary(Command), <<"'">>),
    File = steps_file(Steps),
    {0, Output} = sh("./ern_pty.py --timeout " ++ integer_to_list(Seconds) ++ " --steps " ++ File
                     ++ Extra ++ " -- '" ++ Command ++ "'"),
    Lines = [Line || Line <- binary:split(Output, <<"\n">>, [global]), Line =/= <<>>],
    ?assertEqual([], [Line || <<"unmet ", _/binary>> = Line <- Lines]),
    [<<"status ", Status/binary>>] = [Line || <<"status ", _/binary>> = Line <- Lines],
    [<<"data ", Data/binary>>] = [Line || <<"data ", _/binary>> = Line <- Lines],
    {status(Status), base64:decode(Data)}.

%% The directory a run of the tests makes what it needs under, its homes,
%% sources, inputs and step files: the one `make` makes for the run and
%% removes when it ends, or the host's for a run of a test by itself.
-spec run_dir() -> file:filename().
run_dir() ->
    os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")).

%% The steps go in a file: one holds whatever the program prints, and a
%% shell reading `>` would take it for a redirection.
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
%% its output and its standard error. The command is the shell's argument
%% as it stands, a variable's setting before it among what it may hold.
-spec sh(string()) -> {non_neg_integer(), binary()}.
sh(Command) ->
    Shell = open_port({spawn_executable, "/bin/sh"},
                      [{args, ["-c", Command]}, exit_status, stderr_to_stdout, binary]),
    collect(Shell, []).

collect(Shell, Acc) ->
    receive
        {Shell, {data, Data}} -> collect(Shell, [Data | Acc]);
        {Shell, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.

%% How many times Needle stands in Haystack.
-spec count(binary(), binary()) -> non_neg_integer().
count(Haystack, Needle) ->
    length(binary:matches(Haystack, Needle)).
