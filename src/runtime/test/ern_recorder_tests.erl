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
        ern_helpers:unloaded(ern_recorded_probe)
    end.

%% docs/development.md "Building": `make cover`; report §11.2, Appendix
%% E.23. A regression test: a module found in a relative directory of the
%% code path, as the hosts under test/ name theirs, is loaded under the
%% name the host's code server gives a file it loads, absolute, so that
%% ern_os finds the helper from its own file after `ern test` has entered
%% an example's directory. Loaded under the relative name, the guide's
%% example of `ern test` faulted in Os.host under recording.
loaded_under_the_code_servers_name_test() ->
    Dir = filename:join(os:getenv("ERN_TEST_DIR"), "recorder_relative"),
    Covered = filename:join(Dir, "covered"),
    ok = filelib:ensure_path(Covered),
    Source = filename:join(Dir, "ern_recorded_relative.erl"),
    ok = file:write_file(Source, <<"-module(ern_recorded_relative).\n">>),
    {ok, ern_recorded_relative} = compile:file(Source, [debug_info, {outdir, Dir}]),
    ok = ern_recorder:compiled(filename:join(Dir, "ern_recorded_relative.beam"), Covered),
    Relative = relative(Dir),
    true = code:add_patha(Relative),
    try
        {module, ern_recorded_relative} = code:ensure_loaded(ern_recorded_relative),
        Plain = code:which(ern_recorded_relative),
        ern_helpers:unloaded(ern_recorded_relative),
        Found = code:which(ern_recorded_relative),
        ern_recorder:loaded(Found, filename:join(Covered, "ern_recorded_relative.beam")),
        ?assertEqual({relative, Plain},
                     {filename:pathtype(Found), code:which(ern_recorded_relative)})
    after
        ern_helpers:unloaded(ern_recorded_relative),
        code:del_path(Relative)
    end.

%% Dir's name relative to the host's working directory.
relative(Dir) ->
    {ok, Cwd} = file:get_cwd(),
    filename:join([".." || _ <- tl(filename:split(Cwd))] ++ tl(filename:split(Dir))).

%% docs/development.md "Building": `make cover`. The lines not run are
%% printed in stretches, each from its first line to its last with no line
%% run between.
stretches_test() ->
    ?assertEqual([{2, 3}, {7, 7}],
                 ern_recorder:stretches([{1, true}, {2, false}, {3, false}, {5, true},
                                         {7, false}])).
