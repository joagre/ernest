%% The recorder of the review's listings (ern_recorder): a module compiled
%% with the host's line coverage and loaded under its own file's name, and
%% the stretches the cover listing prints.
-module(ern_recorder_tests).

-include_lib("eunit/include/eunit.hrl").

%% docs/development.md "Building": `make cover`. A module the recorder
%% compiled is loaded under its built file's name, so that code:which/1
%% answers that file, and the host counts the lines it runs and those it
%% does not.
loaded_under_its_file_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR"), "recorder"),
    Covered = filename:join(Dir, "covered"),
    ok = filelib:ensure_path(Covered),
    Source = filename:join(Dir, "ern_recorded_probe.erl"),
    ok = file:write_file(Source, <<"-module(ern_recorded_probe).\n-export([sign/1]).\n"
                                   "sign(Int) when Int > 0 ->\n    positive;\n"
                                   "sign(_) ->\n    other.\n">>),
    {ok, ern_recorded_probe} = compile:file(Source, [debug_info, {outdir, Dir}]),
    Beam = filename:join(Dir, "ern_recorded_probe.beam"),
    ok = ern_recorder:compiled(Beam, Covered),
    Mode = code:set_coverage_mode(line),
    try
        ern_recorder:loaded(Beam, filename:join(Covered, "ern_recorded_probe.beam"))
    after
        code:set_coverage_mode(Mode)
    end,
    try
        positive = ern_recorded_probe:sign(1),
        ?assertEqual({Beam, [{4, true}, {6, false}]},
                     {code:which(ern_recorded_probe),
                      code:get_coverage(line, ern_recorded_probe)})
    after
        code:purge(ern_recorded_probe),
        code:delete(ern_recorded_probe),
        code:purge(ern_recorded_probe)
    end.

%% docs/development.md "Building": `make cover`. The lines not run are
%% printed in stretches, each from its first line to its last with no line
%% run between.
stretches_test() ->
    ?assertEqual([{2, 3}, {7, 7}],
                 ern_recorder:stretches([{1, true}, {2, false}, {3, false}, {5, true},
                                         {7, false}])).
