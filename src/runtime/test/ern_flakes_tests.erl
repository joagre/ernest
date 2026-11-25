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
%% the canceled one was ended in another.
%%
%% The record before the cancel carries no mark, and the one after it
%% names the canceled test and its round, which the round answers.
%%
%% A regression test, written after the code but for the marks; it does
%% not cover a generator that answers several tests, whose tests after a
%% canceled one still do not run.
round_writes_what_did_not_pass_test() ->
    Dir = os:getenv("ERN_TEST_DIR"),
    File = filename:join(Dir, "flakes-round.txt"),
    {ok, Cwd} = file:get_cwd(),
    Module = ern_helpers:loaded(ern_flakes_round, [
        "says_and_fails_test() -> io:format(\"said before failing~n\"), error(broken).",
        "passes_test() -> io:format(\"said by the passing one~n\").",
        %% waits for a message no one sends, which its limit ends
        io_lib:format("passes_its_limit_test_() -> {timeout, 0.1, {\"passes its limit\","
                      " fun() -> ok = file:set_cwd(~p), receive never -> ok end end}}.", [Dir]),
        io_lib:format("runs_after_the_limit_test() ->"
                      " error({began_in_the_runs_directory, file:get_cwd() =:= {ok, ~p}}).",
                      [Cwd])]),
    try
        ?assertMatch({error, {"ern_flakes_round:" ++ _, 7}},
                     ern_flakes:round(ern_eunit:alone([Module]), 7, "emitter-1", File, none))
    after
        ok = file:set_cwd(Cwd),
        ern_helpers:unloaded(Module)
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
                                    "runs_after_the_limit_test/0 failed, after ern_flakes_round:"
                                    "\\S+ \"passes its limit\" was canceled in round 7\n")),
    ?assertMatch({_, _}, binary:match(After, <<"{began_in_the_runs_directory,true}">>)),
    ?assertEqual(nomatch, binary:match(Text, <<"passes_test">>)),
    ?assertEqual(nomatch, binary:match(Text, <<"said by the passing one">>)).

%% docs/development.md "Building", `make flakes`: each record that follows
%% a cancel that ended a test's process names the host's first such cancel
%% and its round, a later cancel's record among them, in the same round and
%% in a later one, which is given the first round's answer. A cancel for an
%% abort, a setup that raised, is recorded and ended no process, so the
%% record after it carries no mark. Each record's first line is written on
%% standard output too, in the record's words, its mark among them.
round_marks_what_follows_a_cancel_test() ->
    Dir = os:getenv("ERN_TEST_DIR"),
    File = filename:join(Dir, "flakes-marks.txt"),
    First = ern_helpers:loaded(ern_flakes_first, [
        "setup_raises_test_() -> {setup, fun() -> error(no_setup) end, [fun() -> ok end]}.",
        "after_the_abort_test() -> error(after_the_abort).",
        "first_limit_test_() -> {timeout, 0.1, {\"first\", fun waits/0}}.",
        "second_limit_test_() -> {timeout, 0.1, {\"second\", fun waits/0}}.",
        "after_the_limits_test() -> error(after_the_limits).",
        %% waits for a message no one sends, which a limit ends
        "waits() -> receive never -> ok end."]),
    Later = ern_helpers:loaded(ern_flakes_later, ["in_a_later_round_test() -> error(later)."]),
    Terminal = try
                   captured(fun() ->
                       {error, Canceled} =
                           ern_flakes:round(ern_eunit:alone([First]), 7, "cli-0", File, none),
                       ?assertMatch({"ern_flakes_first:" ++ _, 7}, Canceled),
                       ?assertMatch({error, Canceled},
                                    ern_flakes:round(ern_eunit:alone([Later]), 8, "cli-0", File,
                                                     Canceled))
                   end)
               after
                   ern_helpers:unloaded(First),
                   ern_helpers:unloaded(Later)
               end,
    Headers = headers(File, "cli-0"),
    ?assertEqual([<<"make flakes: ", Header/binary>> || <<"== ", Header/binary>> <- Headers],
                 binary:split(Terminal, <<"\n">>, [global, trim])),
    Mark = "after ern_flakes_first:\\S+ \"first\" was canceled in round 7$",
    ?assertMatch([_, _, _, _, _, _], Headers),
    [Abort, AfterAbort, FirstLimit, SecondLimit, AfterLimits, InLater] = Headers,
    ?assertMatch({match, _}, re:run(Abort, " canceled$")),
    ?assertMatch({match, _}, re:run(AfterAbort, "after_the_abort_test/0 failed$")),
    ?assertMatch({match, _}, re:run(FirstLimit, "\"first\" canceled$")),
    ?assertMatch({match, _}, re:run(SecondLimit, "\"second\" canceled, " ++ Mark)),
    ?assertMatch({match, _}, re:run(AfterLimits, "round 7: \\S+after_the_limits_test/0 failed, "
                                    ++ Mark)),
    ?assertMatch({match, _}, re:run(InLater, "round 8: \\S+in_a_later_round_test/0 failed, "
                                    ++ Mark)).

%% docs/development.md "Building", `make flakes`: hunt/1's rounds carry the
%% host's first cancel from one round to the next. Round 1's cancel carries
%% no mark, and the directory its round leaves, which cannot be removed, is
%% a record marked with that cancel. Every later round's cancel is marked
%% with round 1's, and no later round leaves its directory. Each round is a
%% whole number of seconds on a line of the part's .rounds, and a hunt whose
%% moment has come begins no round.
%%
%% A regression test, written after the code. It does not tell a round
%% finished past the moment from one that ended before it. Where this test
%% is ended at its own limit amid a hunt, it puts nothing back: the
%% environment, the scratch module and the held directory's mode.
hunt_carries_the_first_cancel_test_() ->
    {timeout, 60, fun hunt_carries_the_first_cancel/0}.

hunt_carries_the_first_cancel() ->
    Saved = [{Variable, os:getenv(Variable)}
             || Variable <- ["ERN_TEST_DIR", "ERN_FLAKES_UNTIL", "ERN_FLAKES_PART",
                             "ERN_FLAKES_RECORDS", "ERN_FLAKES_ROUNDS"]],
    Dir = filename:join(os:getenv("ERN_TEST_DIR"), "flakes-hunt"),
    ok = file:make_dir(Dir),
    Part = "runtime-9",
    Module = ern_helpers:loaded(ern_flakes_hunted, [
        %% waits for a message no one sends, which its limit ends
        io_lib:format("waits_test_() -> {timeout, ~p, {\"waits\","
                      " fun() -> receive never -> ok end end}}.", [limit()]),
        %% leaves, in round 1 alone, a directory the host cannot remove
        "holds_its_directory_test() -> Round = os:getenv(\"ERN_TEST_DIR\"),"
        " case lists:suffix(\".1\", Round) of"
        " true -> Held = filename:join(Round, \"held\"), ok = file:make_dir(Held),"
        " ok = file:write_file(filename:join(Held, \"kept\"), <<>>),"
        " ok = file:change_mode(Held, 8#500);"
        " false -> ok end."]),
    Tests = ern_eunit:alone([Module]),
    try
        Now = hunt_dir(Dir, "now"),
        ?assertEqual(0, hunted(Tests, Part, Now, os:system_time(millisecond))),
        ?assertEqual({ok, []}, file:list_dir(records(Now))),
        ?assertEqual({ok, []}, file:list_dir(rounds(Now))),
        Hunt = two_rounds(Tests, Part, Dir, 2 * round(limit() * 1000), 1),
        Lines = round_lines(Hunt, Part),
        ?assertEqual([], [Line || Line <- Lines, re:run(Line, "^[0-9]+$") =:= nomatch]),
        Records = hunt_records(Hunt, Part),
        %% a cancel in each round, and round 1's directory
        ?assertEqual([1 | lists:seq(1, length(Lines))], [Round || {Round, _} <- Records]),
        [{1, Canceled}, {1, Directory} | Later] = Records,
        ?assertMatch({match, _}, re:run(Canceled, "^ern_flakes_hunted:\\S+ \"waits\" canceled\n")),
        [Name | _] = binary:split(Canceled, <<" canceled\n">>),
        Mark = <<", after ", Name/binary, " was canceled in round 1">>,
        ?assertEqual(<<"its directory not removed", Mark/binary, "\n{error,eexist}">>, Directory),
        [begins(<<Name/binary, " canceled", Mark/binary, "\n">>, Record) || {_, Record} <- Later],
        ?assertEqual({ok, [Part ++ ".1"]}, file:list_dir(rounds(Hunt)))
    after
        [ok = file:change_mode(Held, 8#700)
         || Held <- filelib:wildcard(filename:join([Dir, "*", "rounds", Part ++ ".1", "held"]))],
        [case Value of
             false -> true = os:unsetenv(Variable);
             _ -> true = os:putenv(Variable, Value)
         end || {Variable, Value} <- Saved],
        ern_helpers:unloaded(Module)
    end.

%% The time limit of the scratch module's test that waits, in seconds.
limit() ->
    0.1.

%% The directory of a hunt under Dir, by its Name, with its records' and
%% its rounds' directories.
hunt_dir(Dir, Name) ->
    Hunt = filename:join(Dir, Name),
    ok = filelib:ensure_path(rounds(Hunt)),
    ok = file:make_dir(records(Hunt)),
    Hunt.

rounds(Dir) ->
    filename:join(Dir, "rounds").

%% hunt/1's answer over Tests as the part Part, its records and its rounds
%% in Hunt's directories, no round begun at or after Until.
hunted(Tests, Part, Hunt, Until) ->
    true = os:putenv("ERN_FLAKES_UNTIL", integer_to_list(Until)),
    true = os:putenv("ERN_FLAKES_PART", Part),
    true = os:putenv("ERN_FLAKES_RECORDS", records(Hunt)),
    true = os:putenv("ERN_FLAKES_ROUNDS", rounds(Hunt)),
    ern_flakes:hunt(Tests).

%% The directory of the first hunt that began two rounds, the first one's
%% moment Ms ahead and each next one's twice as far, each the Attempt'th in
%% a directory of its own under Dir. No round begins at or after the
%% moment, and round 1 takes at least the limit with nothing to bound it
%% above, so no time chosen ahead makes sure that two rounds begin.
two_rounds(Tests, Part, Dir, Ms, Attempt) ->
    Hunt = hunt_dir(Dir, integer_to_list(Attempt)),
    ?assertEqual(0, hunted(Tests, Part, Hunt, os:system_time(millisecond) + Ms)),
    case length(round_lines(Hunt, Part)) >= 2 of
        true -> Hunt;
        false -> two_rounds(Tests, Part, Dir, 2 * Ms, Attempt + 1)
    end.

%% The lines of Part's .rounds in Hunt's records' directory, none where no
%% round began.
round_lines(Hunt, Part) ->
    case file:read_file(filename:join(records(Hunt), Part ++ ".rounds")) of
        {ok, Text} -> binary:split(Text, <<"\n">>, [global, trim]);
        {error, enoent} -> []
    end.

%% The records of Part's file in Hunt's records' directory, in order, each
%% its round and what follows its `== Part, round N: `.
hunt_records(Hunt, Part) ->
    {ok, Text} = file:read_file(filename:join(records(Hunt), Part ++ ".txt")),
    Header = "^== " ++ Part ++ ", round ([0-9]+): (.*)$",
    [begin
         {match, [Round, Record]} = re:run(Whole, Header,
                                            [dotall, {capture, all_but_first, binary}]),
         {binary_to_integer(Round), Record}
     end || Whole <- binary:split(Text, <<"\n\n">>, [global, trim])].

%% docs/development.md "Building", `make flakes`: a cancel EUnit gives for
%% a test's process that an exit signal it does not trap ended, and one for
%% a group whose own time limit came, each ended a test's process, so the
%% record after it names it and its round. Each round begins with no
%% cancel before it.
round_marks_after_a_signal_and_a_groups_limit_test() ->
    Signal = ern_helpers:loaded(ern_flakes_signal, [
        "ended_by_a_signal_test() -> Test = self(), spawn(fun() -> exit(Test, gone) end),"
        " receive never -> ok end.",
        "after_the_signal_test() -> error(after_the_signal)."]),
    Group = ern_helpers:loaded(ern_flakes_group, [
        %% its first test passes, and its second waits until the group's limit
        "group_limit_test_() -> {timeout, 0.1, [fun() -> ok end,"
        " fun() -> receive never -> ok end end]}.",
        "after_the_group_test() -> error(after_the_group)."]),
    try
        %% EUnit tells of the test the signal ended as canceled with no
        %% reason, and of the group whose process it was with the signal's;
        %% a group's limit is told of so too
        {Ended, [Test, ByTheSignal, AfterTheSignal]} = round_records(Signal),
        begins("ern_flakes_signal:ended_by_a_signal_test/0 canceled\nundefined\n", Test),
        begins(Ended ++ " canceled\n{exit,gone}\n", ByTheSignal),
        begins("ern_flakes_signal:after_the_signal_test/0 failed, after " ++ Ended
               ++ " was canceled in round 3\n", AfterTheSignal),
        {Limited, [Waiting, ByTheLimit, AfterTheLimit]} = round_records(Group),
        ?assertMatch({_, _}, binary:match(Waiting, <<" canceled\nundefined\n">>)),
        begins(Limited ++ " canceled\n{timeout,", ByTheLimit),
        begins("ern_flakes_group:after_the_group_test/0 failed, after " ++ Limited
               ++ " was canceled in round 3\n", AfterTheLimit)
    after
        ern_helpers:unloaded(Signal),
        ern_helpers:unloaded(Group)
    end.

%% Round 3 of Module's tests, with no cancel before it: the first cancel
%% it answers, by its name, and its records, each after its `== part,
%% round 3: `.
round_records(Module) ->
    File = filename:join(os:getenv("ERN_TEST_DIR"), "flakes-" ++ atom_to_list(Module) ++ ".txt"),
    {error, {Name, 3}} = ern_flakes:round(ern_eunit:alone([Module]), 3, "cli-1", File, none),
    {ok, Text} = file:read_file(File),
    {Name, [Record || <<"== cli-1, round 3: ", Record/binary>>
                          <- binary:split(Text, <<"\n\n">>, [global, trim])]}.

%% Record begins with Prefix, a string.
begins(Prefix, Record) ->
    Bytes = unicode:characters_to_binary(Prefix),
    ?assertEqual(Bytes, binary:part(Record, 0, min(byte_size(Record), byte_size(Bytes)))).

%% The first line of each record File holds for Part.
headers(File, Part) ->
    {ok, Text} = file:read_file(File),
    Prefix = list_to_binary("== " ++ Part ++ ", round "),
    [Line || Line <- binary:split(Text, <<"\n">>, [global]),
             binary:match(Line, Prefix) =/= nomatch].

%% What the processes Run starts write on standard output while it runs,
%% the listener's among them, through a group leader that keeps it, the
%% test's own restored after.
captured(Run) ->
    Leader = group_leader(),
    Keeper = spawn_link(fun() -> kept(<<>>) end),
    group_leader(Keeper, self()),
    try
        Run()
    after
        group_leader(Leader, self())
    end,
    Keeper ! {written, self()},
    receive
        {written, Keeper, Bytes} -> Bytes
    end.

%% A group leader's answers to the requests io:format/2 and io:put_chars/1
%% send, the bytes kept until the test asks for them.
kept(Bytes) ->
    receive
        {io_request, From, ReplyAs, {put_chars, unicode, Chars}} ->
            From ! {io_reply, ReplyAs, ok},
            kept(<<Bytes/binary, (unicode:characters_to_binary(Chars))/binary>>);
        {io_request, From, ReplyAs, {put_chars, unicode, Module, Function, Arguments}} ->
            From ! {io_reply, ReplyAs, ok},
            Chars = apply(Module, Function, Arguments),
            kept(<<Bytes/binary, (unicode:characters_to_binary(Chars))/binary>>);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, request}},
            kept(Bytes);
        {written, Test} ->
            Test ! {written, self(), Bytes}
    end.

%% docs/development.md "Building": the tests make test gives a host are
%% each test function of its modules, in the order each module exports
%% them, a function whose name ends in `_test_` a generator, and no other
%% function. A regression test, written after the code.
alone_takes_each_test_function_test() ->
    Module = ern_helpers:loaded(ern_flakes_listed, [
        "second_test() -> ok.", "first_test_() -> [].", "helper() -> ok.",
        "helper_test(_) -> ok."]),
    try
        ?assertMatch([{setup, spawn, _, {Module, second_test}},
                      {setup, spawn, _, {generator, Module, first_test_}}],
                     ern_eunit:alone([Module]))
    after
        ern_helpers:unloaded(Module)
    end.

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
%% the summary gives each part's rounds, the tests its file records, a
%% record that follows a cancel apart from its test's others and with the
%% cancel it names, and a host that ended with a status but 0; the status
%% is 1; and every process the program started, and the rounds' directory,
%% are gone once it has ended. Of what stood in the records' directory, a
%% part's own file is removed first and any other file kept.
%%
%% A regression test, written after the program; the program reads the
%% mark in a record's first line as part of what did not pass, so the
%% record after the cancel holds what the program already did. It does not
%% cover the hunt's real hosts, its time, nor the host's interrupt, which
%% ends the program at once and leaves the rounds' directory.
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
                  <<"  1 one: m:c/0 canceled">>,
                  <<"  1 one: m:t/0 failed">>,
                  <<"  1 one: m:t/0 failed, after m:c/0 was canceled in round 1">>,
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

%% The hosts that stand in for two parts': one writes a cancel's record, a
%% record before it and one after it, as ern_flakes writes them, two rounds,
%% a line on standard error, and half a line, then the rest of it once the
%% test writes the named pipe release; the other writes a line once the
%% first has written its half, which it says through the named pipe half,
%% and ends with the status 3.
stand_ins(Dir) ->
    One = "printf '%s\\n' '== one, round 1: m:t/0 failed' 'what it wrote'"
          " '== one, round 1: m:c/0 canceled' 'timeout'"
          " '== one, round 2: m:t/0 failed, after m:c/0 was canceled in round 1' 'what it wrote'"
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
