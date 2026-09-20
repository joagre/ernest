%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ROOT, "..").

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang and in Ernest alike; the vendored getopt keeps its upstream form
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl", "stdlib/**/*.ern",
                "examples/**/*.ern", "test/**/*.ern", "test/*.py"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
                  not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    Long = [{F, N} || F <- Files,
                      {N, Line} <- numbered(F),
                      string:length(Line) > 100],
    ?assertEqual([], Long).

%% docs/style.md: every Erlang module is ern_<thing>, unique across the
%% repository, and a module compiled from an Ernest source is ern@<namespace>;
%% the one exception is a vendored file, which THIRD_PARTY_LICENSES names
module_name_test() ->
    Erl = [F || P <- ["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl"],
                F <- filelib:wildcard(P, ?ROOT),
                not editor_artifact(filename:basename(F))],
    ?assert(length(Erl) > 20),
    Names = [filename:basename(F, ".erl") || F <- Erl],
    ?assertEqual([], [N || N <- Names, string:prefix(N, "ern_") =:= nomatch,
                           not vendored(N)]),
    %% the module attribute agrees with the file name, so a grep finds both
    ?assertEqual([], [F || F <- Erl,
                           not has_line(F, "-module(" ++ filename:basename(F, ".erl") ++ ").")]),
    %% unique across the repository, which the directory no longer disambiguates
    ?assertEqual([], Names -- lists:usort(Names)),
    Ern = lists:usort(filelib:wildcard("stdlib/**/*.ern", ?ROOT)),
    ?assert(length(Ern) > 10),
    ?assertEqual([], [F || F <- Ern, not compiled_as(F)]).

%% THIRD_PARTY_LICENSES names every borrowed file, so the exception is checked
%% rather than listed twice.
vendored(Name) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, "THIRD_PARTY_LICENSES")),
    string:find(Bin, Name ++ ".erl") =/= nomatch.

%% build/stdlib holds the standard library under the name module_atom/1 gives it.
compiled_as(Rel) ->
    Ns = string:replace(filename:rootname(filename:basename(Rel)), "/", "@", all),
    Beam = filename:join([?ROOT, "build", "stdlib", "ern@" ++ lists:flatten(Ns) ++ ".beam"]),
    filelib:is_regular(Beam).

has_line(Rel, Line) ->
    lists:member(Line, [L || {_, L} <- numbered(Rel)]).

%% Emacs lock files, `.#name`, and auto-save files, `#name#` (report §11.1).
editor_artifact([C | _]) -> C =:= $. orelse C =:= $#.

numbered(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    Lines = string:split(unicode:characters_to_list(Bin), "\n", all),
    lists:zip(lists:seq(1, length(Lines)), Lines).
