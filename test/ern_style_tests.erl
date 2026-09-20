%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ROOT, "..").

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang and in Ernest alike; the vendored getopt keeps its upstream form
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl", "stdlib/**/*.ern",
                "examples/**/*.ern"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
                  not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    Long = [{F, N} || F <- Files,
                      {N, Line} <- numbered(F),
                      string:length(Line) > 100],
    ?assertEqual([], Long).

%% Emacs lock files, `.#name`, and auto-save files, `#name#` (report §11.1).
editor_artifact([C | _]) -> C =:= $. orelse C =:= $#.

numbered(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    Lines = string:split(unicode:characters_to_list(Bin), "\n", all),
    lists:zip(lists:seq(1, length(Lines)), Lines).
