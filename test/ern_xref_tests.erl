%% The calls of the toolchain's own Erlang, its shims and the Erlang the
%% compiler writes for the standard library, the shell and the libraries,
%% the code Dialyzer reads (the Makefile), held by the host's xref: each
%% names a function that this code or the host's own applications define.
%% A call by a name the code computes, a foreign function's by its
%% declaration among them, is no call xref reads, and a test's module is
%% not read.
-module(ern_xref_tests).

-include_lib("eunit/include/eunit.hrl").

%% docs/development.md "Building": `make xref`. A regression test, written
%% where it found nothing; it reads the units the repository's `make units`
%% linked under build/units, since xref reads a module only from a file
%% whose name ends in .beam.
undefined_calls_test() ->
    Units = filelib:wildcard(filename:join(ern_tree:build("units"), "*.beam")),
    ?assertNotEqual([], Units),
    {ok, Xref} = xref:start([{xref_mode, functions}]),
    try
        ok = xref:set_default(Xref, [{warnings, false}, {verbose, false}]),
        ok = xref:set_library_path(Xref, [Directory || Directory <- code:get_path(),
                                                       lists:prefix(code:lib_dir(), Directory)]),
        [{ok, _} = xref:add_module(Xref, Beam) || Beam <- ern_tree:own_code() ++ Units],
        ?assertEqual({ok, []}, xref:analyze(Xref, undefined_function_calls))
    after
        xref:stop(Xref)
    end.
