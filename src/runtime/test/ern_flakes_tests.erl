%% The flake hunt: its host (ern_flakes), which tools/flakes.ern starts for
%% each part of the split suites, with the tests make test gives it, each
%% alone (ern_eunit), and the program, over hosts that stand in for the
%% real ones.
-module(ern_flakes_tests).

-include_lib("eunit/include/eunit.hrl").

%% docs/development.md "Building", `make flakes`: a round of the tests of a
%% module, each alone, writes each test that fails to the part's file with
%% its name, its reason and what it wrote, and the one canceled at its time
%% limit with its name and its reason, and nothing of a test that passes.
%% The limit ends its own test alone: the test after it runs, is counted, as
%% its failure's record shows, and begins in the run's directory, though
%% the canceled one was ended in another. A regression test, written after
%% the code; it does not cover the rounds of hunt/1, which the program's
%% test does not run either, nor a generator that answers several tests,
%% whose tests after a canceled one still do not run.
round_writes_what_did_not_pass_test() ->
    Dir = os:getenv("ERN_TEST_DIR"),
    File = filename:join(Dir, "flakes-round.txt"),
    {ok, Cwd} = file:get_cwd(),
    Module = loaded(ern_flakes_round, [
        "says_and_fails_test() -> io:format(\"said before failing~n\"), error(broken).",
        "passes_test() -> io:format(\"said by the passing one~n\").",
        %% waits for a message no one sends, which its limit ends
        io_lib:format("passes_its_limit_test_() -> {timeout, 0.1, {\"passes its limit\","
                      " fun() -> ok = file:set_cwd(~p), receive never -> ok end end}}.", [Dir]),
        io_lib:format("runs_after_the_limit_test() ->"
                      " error({began_in_the_runs_directory, file:get_cwd() =:= {ok, ~p}}).",
                      [Cwd])]),
    try
        ?assertEqual(error, ern_flakes:round(ern_eunit:alone([Module]), 7, "emitter-1", File))
    after
        ok = file:set_cwd(Cwd),
        unloaded(Module)
    end,
    {ok, Text} = file:read_file(File),
    Records = [Record || Record <- binary:split(Text, <<"\n== ">>, [global]), Record =/= <<>>],
    ?assertMatch([<<"== emitter-1, round 7: ", _/binary>>, _, _], Records),
    [Failed, Canceled, After] = Records,
    ?assertMatch({match, _}, re:run(Failed, "^== emitter-1, round 7: ern_flakes_round:"
                                    "says_and_fails_test/0 failed\n")),
    ?assertMatch({_, _}, binary:match(Failed, <<"broken">>)),
    ?assertMatch({_, _}, binary:match(Failed, <<"said before failing">>)),
    ?assertMatch({match, _}, re:run(Canceled, "^emitter-1, round 7: ern_flakes_round:\\S+"
                                    " \"passes its limit\" canceled\n")),
    ?assertMatch({_, _}, binary:match(Canceled, <<"timeout">>)),
    ?assertMatch({match, _}, re:run(After, "^emitter-1, round 7: ern_flakes_round:"
                                    "runs_after_the_limit_test/0 failed\n")),
    ?assertMatch({_, _}, binary:match(After, <<"{began_in_the_runs_directory,true}">>)),
    ?assertEqual(nomatch, binary:match(Text, <<"passes_test">>)),
    ?assertEqual(nomatch, binary:match(Text, <<"said by the passing one">>)).

%% docs/development.md "Building": the tests make test gives a host are
%% each test function of its modules, in the order each module exports
%% them, a function whose name ends in `_test_` a generator, and no other
%% function. A regression test, written after the code.
alone_takes_each_test_function_test() ->
    Module = loaded(ern_flakes_listed, [
        "second_test() -> ok.", "first_test_() -> [].", "helper() -> ok.",
        "helper_test(_) -> ok."]),
    try
        ?assertMatch([{setup, spawn, _, {Module, second_test}},
                      {setup, spawn, _, {generator, Module, first_test_}}],
                     ern_eunit:alone([Module]))
    after
        unloaded(Module)
    end.

%% Module compiled from Lines, each a form, every function of no argument
%% exported, and loaded; it is purged once the test ends, since the hunt
%% runs the test again in the same host.
loaded(Module, Lines) ->
    Source = [io_lib:format("-module(~w).~n-compile([export_all, nowarn_export_all]).~n",
                            [Module]) | [[Line, "\n"] || Line <- Lines]],
    File = filename:join(os:getenv("ERN_TEST_DIR"), atom_to_list(Module) ++ ".erl"),
    ok = file:write_file(File, Source),
    {ok, Module, Binary} = compile:file(File, [binary, report]),
    {module, Module} = code:load_binary(Module, File, Binary),
    Module.

unloaded(Module) ->
    _ = code:purge(Module),
    true = code:delete(Module),
    _ = code:purge(Module),
    ok.

%% docs/development.md "Building", `make flakes`, tools/flakes.ern: the
%% program refuses a MINUTES that is not a positive whole number and a
%% LOOPS that is not a whole number, each in one line with the status 1. A
%% regression test, written after the program.
program_refusals_test_() ->
    {timeout, 60, fun program_refusals/0}.

program_refusals() ->
    Dir = program_dir("refusals"),
    Hosts = ["--", "one", "sh", "-c", "exit 0"],
    Minutes = <<"make flakes: MINUTES=n, a positive whole number, is required\n">>,
    Loops = <<"make flakes: LOOPS=n, a whole number, is required\n">>,
    ?assertEqual({1, Minutes}, ran(Dir, ["", "1", records(Dir) | Hosts])),
    ?assertEqual({1, Minutes}, ran(Dir, ["0", "1", records(Dir) | Hosts])),
    ?assertEqual({1, Loops}, ran(Dir, ["1", "x", records(Dir) | Hosts])),
    ?assertEqual({1, Loops}, ran(Dir, ["1", "-1", records(Dir) | Hosts])).

%% docs/development.md "Building", `make flakes`, tools/flakes.ern, report
%% Appendix E.23: the program, over two hosts that stand in for a part's,
%% beside two busy loops. Each line a host writes on standard output is
%% relayed whole, one host's half line kept while the other's whole line
%% passes; what a host writes on standard error goes to the part's .err;
%% the summary gives each part's rounds, the tests its file records, and a
%% host that ended with a status but 0; the status is 1; and every process
%% the program started, and the rounds' directory, are gone once it has
%% ended. Of what stood in the records' directory, a part's own file is
%% removed first and any other file kept.
%%
%% A regression test, written after the program; it does not cover the
%% hunt's real hosts, its time, nor the host's interrupt, which ends the
%% program at once and leaves the rounds' directory.
program_relays_and_sums_up_test_() ->
    {timeout, 60, fun program_relays_and_sums_up/0}.

program_relays_and_sums_up() ->
    Dir = program_dir("relays"),
    Records = records(Dir),
    ok = filelib:ensure_path(Records),
    ok = file:write_file(filename:join(Records, "one.dump"), <<"an earlier hunt's">>),
    ok = file:write_file(filename:join(Records, "kept.txt"), <<"no part's">>),
    {Port, Number} = started(Dir, ["1", "2", Records | stand_ins(Dir)]),
    Written = read_until(Port, <<"two-line\n">>, <<>>),
    Started = descendants(Number),
    ?assertEqual(2, length([Line || {_, Line} <- Started,
                                    string:find(Line, "while :; do :; done") =/= nomatch])),
    "" = os:cmd("echo go > " ++ fifo(Dir, "release")),
    {Status, Output} = ended(Port, Written),
    ?assertEqual(1, Status),
    Lines = binary:split(Output, <<"\n">>, [global, trim]),
    ?assert(lists:member(<<"one-first-half one-second-half">>, Lines)),
    ?assert(lists:member(<<"two-line">>, Lines)),
    Shown = list_to_binary(Records),
    ?assertEqual([<<"make flakes: the rounds each part ran in 1 min beside 2 busy loops:">>,
                  <<"  one: 2 rounds, the longest 7 s">>,
                  <<"  two: 0 rounds, then ended before its time, with status 3">>,
                  <<"Each that did not pass, after the number of rounds it did not pass in:">>,
                  <<"  1 one: m:t/0 failed">>,
                  <<"Each part's records are in ", Shown/binary, "/<part>.txt, and what its host"
                    " wrote on standard error in ", Shown/binary, "/<part>.err.">>],
                 lists:nthtail(2, Lines)),
    ?assertEqual({ok, <<"one-error\n">>}, file:read_file(filename:join(Records, "one.err"))),
    {ok, Two} = file:read_file(filename:join(Records, "two.txt")),
    ?assertEqual(<<"\n== two ended before its time, with status 3\n">>, Two),
    ?assertEqual([], [Line || {Process, Line} <- Started, not gone(Process)]),
    ?assertEqual({ok, []}, file:list_dir(filename:join(Dir, "tmp"))),
    ?assertEqual({ok, <<"no part's">>}, file:read_file(filename:join(Records, "kept.txt"))),
    ?assertEqual({error, enoent}, file:read_file(filename:join(Records, "one.dump"))).

%% tools/flakes.ern: a rounds' directory that cannot be made, its TMPDIR a
%% file, is refused in one line with the status 1, after the loops have
%% started, and nothing is made. A regression test, written after the
%% program; that the loops end with it is not covered.
program_without_rounds_test_() ->
    {timeout, 60, fun program_without_rounds/0}.

program_without_rounds() ->
    Dir = program_dir("without-rounds"),
    Tmp = filename:join(Dir, "tmp"),
    ok = file:del_dir(Tmp),
    ok = file:write_file(Tmp, <<"no directory">>),
    {Status, Output} = ran(Dir, ["1", "2", records(Dir) | stand_ins(Dir)]),
    ?assertEqual(1, Status),
    ?assertMatch([<<"make flakes: cannot make the rounds' directory: ", _/binary>>],
                 binary:split(Output, <<"\n">>, [global, trim])),
    ?assertEqual({ok, <<"no directory">>}, file:read_file(Tmp)),
    ?assertEqual({ok, []}, file:list_dir(records(Dir))).

%% report §8.6, Appendix E.23, tools/flakes.ern: a termination while a host
%% runs ends the program with the signal's status, every process it
%% started gone and the rounds' directory removed. A regression test,
%% written after the program.
program_terminated_test_() ->
    {timeout, 60, fun program_terminated/0}.

program_terminated() ->
    Dir = program_dir("terminated"),
    {Port, Number} = started(Dir, ["1", "2", records(Dir) | stand_ins(Dir)]),
    _ = read_until(Port, <<"two-line\n">>, <<>>),
    Started = descendants(Number),
    "" = os:cmd("kill -TERM " ++ Number),
    {Status, Output} = ended(Port, <<>>),
    ?assertEqual(143, Status),
    ?assertEqual(nomatch, binary:match(Output, <<"make flakes: the rounds">>)),
    ?assertEqual([], [Line || {Process, Line} <- Started, not gone(Process)]),
    ?assertEqual({ok, []}, file:list_dir(filename:join(Dir, "tmp"))).

%% The hosts that stand in for two parts': one writes a record, two rounds,
%% a line on standard error, and half a line, then the rest of it once the
%% test writes the named pipe release; the other writes a line once the
%% first has written its half, which it says through the named pipe half,
%% and ends with the status 3.
stand_ins(Dir) ->
    One = "printf '%s\\n' '== one, round 1: m:t/0 failed' 'what it wrote'"
          " >> \"$ERN_FLAKES_RECORDS/one.txt\"; "
          "printf '4\\n7\\n' >> \"$ERN_FLAKES_RECORDS/one.rounds\"; "
          "echo one-error >&2; printf one-first-half; echo > " ++ fifo(Dir, "half") ++ "; "
          "read line < " ++ fifo(Dir, "release") ++ "; echo ' one-second-half'",
    Two = "read line < " ++ fifo(Dir, "half") ++ "; echo two-line; exit 3",
    ["--", "one", "sh", "-c", One, "--", "two", "sh", "-c", Two].

%% A directory of the test's own under the run's, with the named pipes and
%% the directory the program makes the rounds' directory in, its TMPDIR.
program_dir(Name) ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR"), "flakes-" ++ Name),
    ok = filelib:ensure_path(filename:join(Dir, "tmp")),
    "" = os:cmd("mkfifo " ++ fifo(Dir, "half") ++ " " ++ fifo(Dir, "release")),
    Dir.

fifo(Dir, Name) ->
    filename:join(Dir, Name).

records(Dir) ->
    filename:join(Dir, "records").

%% The program run with Arguments from the repository's root, the run's,
%% and its operating system's number.
started(Dir, Arguments) ->
    Port = open_port({spawn_executable, filename:absname("bin/ern")},
                     [{args, ["run", "build/tools/flakes.erc" | Arguments]},
                      {env, [{"TMPDIR", filename:join(Dir, "tmp")}]},
                      binary, exit_status, stderr_to_stdout]),
    {os_pid, Number} = erlang:port_info(Port, os_pid),
    {Port, integer_to_list(Number)}.

ran(Dir, Arguments) ->
    {Port, _} = started(Dir, Arguments),
    ended(Port, <<>>).

%% What the port wrote, once it holds Text; ten seconds bound a failure.
read_until(Port, Text, Output) ->
    case binary:match(Output, Text) of
        nomatch ->
            receive
                {Port, {data, Data}} -> read_until(Port, Text, <<Output/binary, Data/binary>>)
            after 10000 -> error({not_written, Text, Output})
            end;
        _ ->
            Output
    end.

%% The port's exit status and all it wrote.
ended(Port, Output) ->
    receive
        {Port, {data, Data}} -> ended(Port, <<Output/binary, Data/binary>>);
        {Port, {exit_status, Status}} -> {Status, Output}
    end.

%% Every process under the operating system's number Number, by its
%% parent's number, each its number and its command.
descendants(Number) ->
    Rows = [{Process, Parent, Command}
            || Line <- string:split(os:cmd("ps -A -o pid= -o ppid= -o args="), "\n", all),
               [Process, Parent | Words] <- [string:lexemes(Line, " ")],
               Command <- [lists:join(" ", Words)]],
    under([Number], Rows, []).

under([], _, Found) ->
    Found;
under([Number | Rest], Rows, Found) ->
    Children = [{Process, lists:flatten(Command)} || {Process, Parent, Command} <- Rows,
                                                    Parent =:= Number],
    under([Process || {Process, _} <- Children] ++ Rest, Rows, Children ++ Found).

%% Whether the process Number has ended, or is ended and not yet taken by
%% its parent, within ten seconds, which bound a failure. Nothing tells
%% this process of another program's end, so the host is asked again at
%% once each time.
gone(Number) ->
    asked(Number, erlang:monotonic_time(millisecond) + 10000).

asked(Number, Deadline) ->
    case string:trim(os:cmd("ps -o stat= -p " ++ Number)) of
        "" -> true;
        "Z" ++ _ -> true;
        _ -> erlang:monotonic_time(millisecond) < Deadline andalso asked(Number, Deadline)
    end.
