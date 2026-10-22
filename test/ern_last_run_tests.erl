%% `make bench`'s memory of its runs, test/ern_last_run.erl
%% (docs/development.md): small tables of two runs, the first kept in
%% `last/` as a run begins or in `release/` by hand, and the rows that moved
%% named as a run ends, against each. Regression tests, written after the
%% code. What they leave out runs only in `make bench`: the tables its parts
%% write, read against their own last run and the release's.
-module(ern_last_run_tests).

-include_lib("eunit/include/eunit.hrl").

%% The last run's tables of times: a table of medians with their ranges,
%% and one whose rows add a piece each.
-define(BEFORE,
        "the spawn, ns an iteration        median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0\n"
        "Ernest's spawn                    5000.0  4000.0 to 6000.0\n"
        "1000 processes                    1500.0  1400.0 to 1600.0\n"
        "5000 processes                    1500.0  1400.0 to 1600.0\n"
        "\n"
        "a model, a piece added on each row   median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0\n"
        "+ the row                          990 ns    1 to 2 +1000.0\n").

%% The run after: Ernest's spawn 30% slower and the second of two rows
%% named by a number 40% faster, which moved; the host's spawn 15% slower,
%% within a fifth; every range and difference moved far, which follow from
%% the medians; and the row's time written in another unit, the same time
%% within a fifth.
-define(NOW,
        "the spawn, ns an iteration        median        range\n"
        "the host's spawn                  1150.0   100.0 to 9100.0\n"
        "Ernest's spawn                    6500.0  1000.0 to 9000.0\n"
        "1000 processes                    1500.0  1400.0 to 1600.0\n"
        "5000 processes                     900.0  1400.0 to 1600.0\n"
        "\n"
        "a model, a piece added on each row   median        range\n"
        "the host's spawn                  1000.0   900.0 to 1100.0\n"
        "+ the row                          1.1 us   10 to 20 +5000.0\n").

%% A table with a ratio, each row's median over the host's, an indented
%% row a part of the row above it, and a row with no ratio.
-define(RATIOS_BEFORE,
        "the call, ns a call               median        range\n"
        "the host's call                   1000.0   900.0 to 1100.0    1.00x\n"
        "Address.call                      2000.0  1900.0 to 2100.0    2.00x\n"
        "  callForever                     1500.0  1400.0 to 1600.0    1.50x\n"
        "a note beside it                   100.0    90.0 to  110.0\n").

%% The run after, on a machine twice as slow: every time doubled, which the
%% ratios cancel; callForever's ratio up 27%, which moved; and the row with
%% no ratio tripled, which its table does not compare.
-define(RATIOS_NOW,
        "the call, ns a call               median        range\n"
        "the host's call                   2000.0  1800.0 to 2200.0    1.00x\n"
        "Address.call                      4000.0  3800.0 to 4200.0    2.00x\n"
        "  callForever                     3800.0  3600.0 to 4000.0    1.90x\n"
        "a note beside it                   300.0   270.0 to  330.0\n").

%% test/ern_last_run.erl: in a table with no ratio, a row whose number
%% moved by more than a fifth is named with both numbers, under its table's
%% title; a row named by a number is matched by its place among the rows
%% that read alike
moved_test() ->
    ?assertEqual([{"the spawn, ns an iteration median range",
                   [{"Ernest's spawn", {5000.0, "5000.0"}, {6500.0, "6500.0"}},
                    {"5000 processes", {1500.0, "1500.0"}, {900.0, "900.0"}}]}],
                 ern_last_run:moved(?BEFORE, ?NOW)).

%% test/ern_last_run.erl: a table some of whose rows carry a ratio is
%% compared by its ratios alone, so that times the machine's state moved
%% together are not named; a row of it with no ratio is not compared; an
%% indented row is named after the row above it
ratio_test() ->
    ?assertEqual([{"the call, ns a call median range",
                   [{"Address.call, callForever", {1.5, "1.50x"}, {1.9, "1.90x"}}]}],
                 ern_last_run:moved(?RATIOS_BEFORE, ?RATIOS_NOW)),
    ?assertEqual([], ern_last_run:moved(?RATIOS_BEFORE, ?RATIOS_BEFORE)).

%% test/ern_last_run.erl: a range's ends and a difference are not
%% compared, a time is compared in nanoseconds whatever its unit, and a
%% line that gives the load average is neither a row nor a title; a number
%% is named by its row's words before it but for the measures just before
%% it, a fraction among the words kept, and an indented row after the row
%% above it; a number among a row's words is compared too, and never moves
read_test() ->
    [_, _, _, _, _, {_, _, Values}] = ern_last_run:rows(?NOW),
    ?assertEqual([{1100.0, "1.1 us", "+ the row"}], Values),
    ?assertEqual([], ern_last_run:rows("Load average 1.72 on 8 processors.\n"
                                       "Load average 0.10 on 8 processors.\n")),
    Ratios = "Load average 1.72 on 8 processors.\n"
             "ns an iteration   Ernest   Erlang   ratio\n"
             "a fault, depth 8  111.6    3.3    34.13x\n"
             "  beneath 40      101.6    3.4    30.01x\n",
    ?assertEqual([{"a fault, depth 8", "34.13x"}, {"a fault, depth 8, beneath 40", "30.01x"}],
                 [{Name, Text} || {_, _, Read} <- ern_last_run:rows(Ratios),
                                  {_, Text, Name} <- Read]),
    Model = "a model\n+ the row as MVP 3.1 wrote it  1500.0  1400.0 to 1600.0\n",
    ?assertEqual(["+ the row as MVP", "+ the row as MVP 3.1 wrote it"],
                 [Name || {_, _, Read} <- ern_last_run:rows(Model), {_, _, Name} <- Read]).

%% test/ern_last_run.erl: a run's tables are kept as the next begins only
%% where it wrote them all; at its end the rows that moved are named, or
%% that none did, or that no last run is there
last_run_test() ->
    in_directory(
      fun(Directory) ->
              Tables = ["spawn.txt", "call.txt"],
              Last = filename:join(Directory, "last"),
              NoRelease = no_release(Directory),
              write(Directory, "spawn.txt", ?BEFORE),
              ok = ern_last_run:kept(Directory, Tables),
              ?assertNot(filelib:is_dir(Last)),
              ?assertEqual("No last run in " ++ Last
                           ++ "; the next run is compared with this one.\n" ++ NoRelease,
                           text(ern_last_run:compared(Directory, Tables))),
              write(Directory, "call.txt", ?BEFORE),
              ok = ern_last_run:kept(Directory, Tables),
              ?assertEqual(["call.txt", "spawn.txt"], lists:sort(element(2, file:list_dir(Last)))),
              write(Directory, "spawn.txt", ?NOW),
              write(Directory, "call.txt", ?BEFORE),
              ?assertEqual("Moved by more than a fifth since the last run, in " ++ Last ++ ":\n"
                           "spawn.txt: the spawn, ns an iteration median range\n"
                           "  Ernest's spawn: last 5000.0, now 6500.0, +30%\n"
                           "  5000 processes: last 1500.0, now 900.0, -40%\n" ++ NoRelease,
                           text(ern_last_run:compared(Directory, Tables))),
              write(Directory, "spawn.txt", ?BEFORE),
              ?assertEqual("No row moved by more than a fifth since the last run, in " ++ Last
                           ++ ".\n" ++ NoRelease,
                           text(ern_last_run:compared(Directory, Tables)))
      end).

%% test/ern_last_run.erl: the release's run is kept by hand, copied, only
%% where the last run wrote every table; a run is then compared with it as
%% with the last, each row that moved named under its reference
release_test() ->
    in_directory(
      fun(Directory) ->
              Tables = ["spawn.txt", "call.txt"],
              Last = filename:join(Directory, "last"),
              Release = filename:join(Directory, "release"),
              write(Directory, "spawn.txt", ?BEFORE),
              ?assertEqual({missing, ["call.txt"]}, ern_last_run:released(Directory, Tables)),
              ?assertNot(filelib:is_dir(Release)),
              write(Directory, "call.txt", ?RATIOS_BEFORE),
              ok = ern_last_run:released(Directory, Tables),
              ?assertEqual(["call.txt", "spawn.txt"],
                           lists:sort(element(2, file:list_dir(Release)))),
              ?assert(filelib:is_regular(filename:join(Directory, "spawn.txt"))),
              ok = ern_last_run:kept(Directory, Tables),
              write(Directory, "spawn.txt", ?BEFORE),
              write(Directory, "call.txt", ?RATIOS_NOW),
              ok = ern_last_run:kept(Directory, Tables),
              write(Directory, "spawn.txt", ?NOW),
              write(Directory, "call.txt", ?RATIOS_NOW),
              ?assertEqual("Moved by more than a fifth since the last run, in " ++ Last ++ ":\n"
                           "spawn.txt: the spawn, ns an iteration median range\n"
                           "  Ernest's spawn: last 5000.0, now 6500.0, +30%\n"
                           "  5000 processes: last 1500.0, now 900.0, -40%\n"
                           "Moved by more than a fifth since the release's run, in " ++ Release
                           ++ ":\n"
                           "spawn.txt: the spawn, ns an iteration median range\n"
                           "  Ernest's spawn: last 5000.0, now 6500.0, +30%\n"
                           "  5000 processes: last 1500.0, now 900.0, -40%\n"
                           "call.txt: the call, ns a call median range\n"
                           "  Address.call, callForever: last 1.50x, now 1.90x, +27%\n",
                           text(ern_last_run:compared(Directory, Tables)))
      end).

no_release(Directory) ->
    "No release's run in " ++ filename:join(Directory, "release")
        ++ "; make bench-release keeps this run as it.\n".

in_directory(Test) ->
    Directory = filename:join(os:getenv("TMPDIR", "/tmp"),
                              "ern_last_run_" ++ integer_to_list(erlang:unique_integer([positive]))
                              ++ "_" ++ os:getpid()),
    ok = file:make_dir(Directory),
    try Test(Directory)
    after file:del_dir_r(Directory)
    end.

write(Directory, Table, Text) ->
    ok = file:write_file(filename:join(Directory, Table), Text).

text(IoList) ->
    unicode:characters_to_list(IoList).
