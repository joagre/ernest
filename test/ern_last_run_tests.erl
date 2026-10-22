%% `make bench`'s memory of its last run, test/ern_last_run.erl
%% (docs/development.md): two small tables of two runs, the first kept in
%% `last/` as a run begins and the rows that moved named as it ends.
%% Regression tests, written after the code. What they leave out runs only
%% in `make bench`: the tables its parts write, read against their own
%% last run.
-module(ern_last_run_tests).

-include_lib("eunit/include/eunit.hrl").

%% The last run's table: a block of medians with their ranges and ratios,
%% and a block whose rows add a piece each.
-define(BEFORE,
        "the spawn, ns an iteration        median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0   1.0x\n"
        "Ernest's spawn                    5000.0  4000.0 to 6000.0   5.0x\n"
        "1000 processes                    1500.0  1400.0 to 1600.0   1.5x\n"
        "5000 processes                    1500.0  1400.0 to 1600.0   1.5x\n"
        "\n"
        "a model, a piece added on each row   median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0\n"
        "+ the row                          990 ns    1 to 2 +1000.0\n").

%% The run after: Ernest's spawn 30% slower and the second of two rows
%% named by a number 40% faster, which moved; the host's spawn 15% slower,
%% within a fifth; every range, ratio and difference moved far, which
%% follow from the medians; and the row's time written in another unit,
%% the same time within a fifth.
-define(NOW,
        "the spawn, ns an iteration        median        range\n"
        "the host's spawn                  1150.0   100.0 to 9100.0   1.0x\n"
        "Ernest's spawn                    6500.0  1000.0 to 9000.0   5.7x\n"
        "1000 processes                    1500.0  1400.0 to 1600.0   1.3x\n"
        "5000 processes                     900.0  1400.0 to 1600.0   0.8x\n"
        "\n"
        "a model, a piece added on each row   median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0\n"
        "+ the row                          1.1 us   10 to 20 +5000.0\n").

%% test/ern_last_run.erl: a row whose number moved by more than a fifth is
%% named with both numbers, under its block's title; a row named by a
%% number is matched by its place among the rows that read alike
moved_test() ->
    ?assertEqual([{"the spawn, ns an iteration median range",
                   [{"Ernest's spawn", {5000.0, "5000.0"}, {6500.0, "6500.0"}},
                    {"5000 processes", {1500.0, "1500.0"}, {900.0, "900.0"}}]}],
                 ern_last_run:moved(?BEFORE, ?NOW)).

%% test/ern_last_run.erl: a range's ends, a ratio and a difference are not
%% compared, a time is compared in nanoseconds whatever its unit, and a
%% line that gives the load average is no row
read_test() ->
    [_, _, _, _, _, {_, _, Words, Values}] = ern_last_run:rows(?NOW),
    ?assertEqual(["+", "the", "row", "1.1", "us", "10", "to", "20", "+5000.0"], Words),
    ?assertEqual([{1100.0, "1.1 us", 4}], Values),
    ?assertEqual([], ern_last_run:rows("Load average 1.72 on 8 processors.\n"
                                       "Load average 0.10 on 8 processors.\n")).

%% test/ern_last_run.erl: a run's tables are kept as the next begins only
%% where it wrote them all; at its end the rows that moved are named, or
%% that none did, or that no last run is there
last_run_test() ->
    Directory = directory(),
    try
        Tables = ["spawn.txt", "call.txt"],
        Last = filename:join(Directory, "last"),
        write(Directory, "spawn.txt", ?BEFORE),
        ok = ern_last_run:kept(Directory, Tables),
        ?assertNot(filelib:is_dir(Last)),
        ?assertEqual("No last run in " ++ Last ++ "; the next run is compared with this one.\n",
                     text(ern_last_run:compared(Directory, Tables))),
        write(Directory, "call.txt", ?BEFORE),
        ok = ern_last_run:kept(Directory, Tables),
        ?assertEqual(["call.txt", "spawn.txt"], lists:sort(element(2, file:list_dir(Last)))),
        write(Directory, "spawn.txt", ?NOW),
        write(Directory, "call.txt", ?BEFORE),
        ?assertEqual("Moved by more than a fifth since the last run, in " ++ Last ++ ":\n"
                     "spawn.txt: the spawn, ns an iteration median range\n"
                     "  Ernest's spawn: last 5000.0, now 6500.0, +30%\n"
                     "  5000 processes: last 1500.0, now 900.0, -40%\n",
                     text(ern_last_run:compared(Directory, Tables))),
        write(Directory, "spawn.txt", ?BEFORE),
        ?assertEqual("No row moved by more than a fifth since the last run, in " ++ Last ++ ".\n",
                     text(ern_last_run:compared(Directory, Tables)))
    after
        file:del_dir_r(Directory)
    end.

directory() ->
    Directory = filename:join(os:getenv("TMPDIR", "/tmp"),
                              "ern_last_run_" ++ integer_to_list(erlang:unique_integer([positive]))
                              ++ "_" ++ os:getpid()),
    ok = file:make_dir(Directory),
    Directory.

write(Directory, Table, Text) ->
    ok = file:write_file(filename:join(Directory, Table), Text).

text(IoList) ->
    unicode:characters_to_list(IoList).
