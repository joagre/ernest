%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ROOT, "..").

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang and in Ernest alike; the vendored getopt keeps its upstream form
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl", "stdlib/**/*.ern",
                "examples/**/*.ern", "shell/**/*.ern", "test/**/*.ern", "test/*.py",
                "emacs/*.el", "emacs/test/*.el", "libs/**/*.ern"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
                  not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    Long = [{F, N} || F <- Files,
                      {N, Line} <- numbered(F),
                      string:length(Line) > 100],
    ?assertEqual([], Long).

%% docs/style.md: no file holds a tab; the vendored getopt keeps its upstream form
no_tab_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/include/*.hrl", "test/*.erl",
                "stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern", "test/**/*.ern",
                "test/*.py", "emacs/*.el", "emacs/test/*.el", "emacs/test/broken/*.ern",
                "libs/**/*.ern", "libs/*/*.md", "*.md", "docs/*.md"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                 filename:basename(F) =/= "getopt.erl",
                 not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{F, N} || F <- Files, {N, Line} <- numbered(F),
                                lists:member($\t, Line)]).

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

%% docs/emacs_mode.md: the Emacs mode restates Appendix A's reserved words
%% and a subset of its symbols, so a test keeps the two equal. It found `=>`
%% and `do`, which the mode painted and the language does not have.
%% report §2.4, Appendix A
emacs_mode_mirrors_the_lexer_test() ->
    Lexer = read("erl/lexer/src/ern_lexer.erl"),
    Mode = read("emacs/ernest-mode.el"),
    ?assertEqual(lists:sort(atoms_of(Lexer, "-define(RESERVED,")),
                 lists:sort(strings_of(Mode, "(defconst ernest-reserved-words"))),
    Symbols = strings_of(Lexer, "-define(SYMBOLS,"),
    ?assert(length(Symbols) > 20),
    Painted = strings_of(Mode, "(defconst ernest-operators"),
    ?assert(length(Painted) > 5),
    ?assertEqual([], Painted -- Symbols).

%% The strings, or the atoms, of the list that opens at Marker: the same
%% two shapes in Erlang and in Elisp.
strings_of(Text, Marker) ->
    case re:run(body(Text, Marker), "\"([^\"]*)\"", [global, {capture, all_but_first, list}]) of
        {match, Found} -> [S || [S] <- Found];
        nomatch -> []
    end.

atoms_of(Text, Marker) ->
    [string:trim(T, both, "' \n\t") || T <- string:split(body(Text, Marker), ",", all)].

%% From the list that opens after Marker to the bracket that closes it. A
%% bracket inside a string is not one: the symbol table lists "(" and ")".
body(Text, Marker) ->
    Rest = string:find(Text, Marker),
    ?assertNotEqual(nomatch, Rest),
    {_, [Open | Body]} = string:take(string:slice(Rest, length(Marker)), "[(", true),
    Close = case Open of $[ -> $]; $( -> $) end,
    scan(Body, Open, Close, 0, []).

scan([], _, _, _, Acc) -> lists:reverse(Acc);
scan([$" | T], O, C, D, Acc) -> in_string(T, O, C, D, [$" | Acc]);
scan([Ch | T], O, C, D, Acc) when Ch =:= O -> scan(T, O, C, D + 1, [Ch | Acc]);
scan([Ch | _], _, C, 0, Acc) when Ch =:= C -> lists:reverse(Acc);
scan([Ch | T], O, C, D, Acc) when Ch =:= C -> scan(T, O, C, D - 1, [Ch | Acc]);
scan([Ch | T], O, C, D, Acc) -> scan(T, O, C, D, [Ch | Acc]).

in_string([$\\, Ch | T], O, C, D, Acc) -> in_string(T, O, C, D, [Ch, $\\ | Acc]);
in_string([$" | T], O, C, D, Acc) -> scan(T, O, C, D, [$" | Acc]);
in_string([Ch | T], O, C, D, Acc) -> in_string(T, O, C, D, [Ch | Acc]);
in_string([], _, _, _, Acc) -> lists:reverse(Acc).

read(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    unicode:characters_to_list(Bin).

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
