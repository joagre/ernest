%% The calls of the toolchain's own Erlang, its shims and the Erlang the
%% compiler writes for the standard library, the shell and the libraries,
%% the code Dialyzer reads (the Makefile), held by the host's xref: each
%% names a function that this code or the host's own applications define.
%% A call by a name the code computes, a foreign function's by its
%% declaration among them, is no call xref reads, and a test's module is
%% not read.
-module(ern_calls_tests).

-include_lib("eunit/include/eunit.hrl").

%% docs/development.md "Building": `make calls`. A regression test, written
%% where it found nothing; it reads the build as `make` left it.
undefined_calls_test() ->
    {ok, Xref} = xref:start([{xref_mode, functions}]),
    try
        ok = xref:set_default(Xref, [{warnings, false}, {verbose, false}]),
        ok = xref:set_library_path(Xref, [Directory || Directory <- code:get_path(),
                                                       lists:prefix(code:lib_dir(), Directory)]),
        [{ok, _} = xref:add_module(Xref, Beam) || Beam <- ern_tree:own_code() ++ units()],
        ?assertEqual({ok, []}, xref:analyze(Xref, undefined_function_calls))
    after
        xref:stop(Xref)
    end.

%% Each compiled module of the standard library, the shell and the
%% libraries, linked under its module's name into build/calls, since xref
%% reads a module only from a file whose name ends in .beam.
units() ->
    Directory = filename:absname("build/calls"),
    _ = file:del_dir_r(Directory),
    ok = filelib:ensure_path(Directory),
    [linked(Unit, Directory)
     || Build <- [ern_tree:build("stdlib"), ern_tree:build("shell") | ern_tree:libraries()],
        Unit <- filelib:wildcard(filename:join(Build, "**/*.erc"))].

linked(Unit, Directory) ->
    {ok, Bytes} = file:read_file(Unit),
    {ok, {ErlangModule, []}} = beam_lib:chunks(Bytes, []),
    Beam = filename:join(Directory, atom_to_list(ErlangModule) ++ ".beam"),
    ok = file:make_symlink(Unit, Beam),
    Beam.
