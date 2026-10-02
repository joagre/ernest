%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_formatted/0]).

-define(ROOT, "..").

%% The documents whose ```ernest fences the Ernest style guide governs.
-define(DOCUMENTS, ["ernest_guide.md", "ernest_report.md"]).

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang, its C, its Makefiles and its scripts, and in Ernest alike; the
%% vendored getopt keeps its upstream form, and test/build holds a build's
%% copies, which a stale one failed. A regression test for the Makefiles,
%% scripts and headers it once left unread
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/c_src/*.c", "test/*.erl",
                "stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern", "test/**/*.ern",
                "test/*.py", "emacs/*.el", "emacs/test/*.el", "libs/**/*.ern", "tools/*.ern",
                "tools/*.sh", "tools/*.escript", "bin/ern", "erl/*/include/*.hrl", "Makefile",
                "test/Makefile", "erl/*/src/Makefile", "tools/release/Makefile"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
                  not lists:prefix("test/build/", F),
                  not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    Long = [{F, N} || F <- Files,
                      {N, Line} <- numbered(F),
                      string:length(Line) > 100],
    ?assertEqual([], Long).

%% docs/style.md: no file holds a tab but a Makefile; the vendored getopt keeps its
%% upstream form
no_tab_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/include/*.hrl", "erl/*/c_src/*.c",
                "test/*.erl",
                "stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern", "test/**/*.ern",
                "test/*.py", "emacs/*.el", "emacs/test/*.el", "emacs/test/broken/*.ern",
                "libs/**/*.ern", "libs/*/*.md", "tools/*.ern", "tools/*.sh", "bin/ern", "*.md",
                "docs/*.md"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                 filename:basename(F) =/= "getopt.erl",
                 not lists:prefix("test/build/", F),
                 not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{F, N} || F <- Files, {N, Line} <- numbered(F),
                                lists:member($\t, Line)]).

%% docs/style.md: one `-export` list, in the order the functions appear,
%% and a `-spec` on every exported function, in the toolchain's modules;
%% the vendored getopt keeps its upstream form. Written after the rule,
%% when six modules had fallen out of order and one had lost its specs
%% (findings.md's C42, C43)
exports_test() ->
    Files = [F || F <- filelib:wildcard("erl/*/src/*.erl", ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
                  not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{F, Why} || F <- Files, Why <- export_faults(filename:join(?ROOT, F))]).

export_faults(File) ->
    {ok, Forms} = epp_dodger:quick_parse_file(File),
    Lists = [Es || {attribute, _, export, Es} <- Forms],
    Exports = lists:append(Lists),
    Specs = [FA || {attribute, _, spec, {FA, _}} <- Forms],
    Appear = [{N, A} || {function, _, N, A, _} <- Forms, lists:member({N, A}, Exports)],
    [lists_of_exports || length(Lists) > 1]
        ++ [out_of_order || Appear =/= [FA || FA <- Exports, lists:member(FA, Appear)]]
        ++ [{no_spec, FA} || FA <- Exports, not lists:member(FA, Specs)].

%% docs/style.md: a block holds more than one statement, in every module,
%% every example in a module's doc blocks, and every Ernest block of the
%% guide and the report. A brace after an expression or after `receive`
%% holds clauses and is not a block. Written with the rule.
block_of_one_test() ->
    ?assertEqual([], [{F, N} || {F, Toks} <- ernest_tokens(), N <- blocks_of_one(Toks)]).

%% report §11.6: every module is in the layout `ern format`
%% writes, the examples of its doc blocks with it, and so is every Ernest
%% block of the guide and the report that parses; `make format` lays out
%% what is not. Written with the formatter, as the style guide's hand-made
%% checks of a statement a line, a function's head and the blank line
%% between declarations, which it holds, went.
formatted_test_() ->
    {timeout, 120,
     fun() ->
         ?assertEqual([], [F || F <- modules(), not formatted(F)]),
         ?assertEqual([], [F || F <- ?DOCUMENTS, not document_formatted(F)])
     end}.

formatted(F) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, F)),
    ern_format:format(Bin) =:= {ok, Bin}.

document_formatted(F) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, F)),
    ern_format:markdown(Bin) =:= Bin.

%% The Ernest blocks of the documents laid out, for `make format`.
write_formatted() ->
    lists:foreach(fun(F) ->
                      Path = filename:join(?ROOT, F),
                      {ok, Bin} = file:read_file(Path),
                      case ern_format:markdown(Bin) of
                          Bin -> ok;
                          Out -> ok = file:write_file(Path, Out)
                      end
                  end, ?DOCUMENTS).

%% The modules the Ernest style guide governs.
modules() ->
    Modules = [F || P <- ["stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern",
                          "libs/**/*.ern", "tools/*.ern", "test/**/*.ern"],
                    F <- filelib:wildcard(P, ?ROOT),
                    not lists:prefix("test/build/", F),
                    not editor_artifact(filename:basename(F))],
    ?assert(length(Modules) > 20),
    Modules.

doc_lines(Docs) ->
    [{N, lists:nthtail(3, string:trim(L, leading))} || {N, L} <- Docs].

%% The ```ernest fences, each its lines, an example that must not compile
%% among them.
fences(Lines) ->
    fences(Lines, none).

fences([], _) -> [];
fences([{N, L} | Rest], In) ->
    case {lists:prefix("```", string:trim(L)), In} of
        {true, none} ->
            case lists:prefix("```ernest", string:trim(L)) of
                true -> fences(Rest, []);
                false -> fences(Rest, other)
            end;
        {true, other} -> fences(Rest, none);
        {true, Fence} -> [lists:reverse(Fence) | fences(Rest, none)];
        {false, other} -> fences(Rest, other);
        {false, none} -> fences(Rest, none);
        {false, Fence} -> fences(Rest, [{N, L} | Fence])
    end.

%% Each text of Ernest as the lexer's tokens, their lines the file's: a
%% module whole, each example of its doc blocks, and each fence of the
%% documents. A text the lexer refuses fails the test with its file.
ernest_tokens() ->
    [{F, tokens(F, Lines)} || {F, Lines} <- ernest_texts()].

%% Each text of Ernest as its numbered lines.
ernest_texts() ->
    Texts = [{F, numbered(F)} || F <- modules()]
        ++ [{F, Fence} || F <- modules(),
                          Fence <- fences(doc_lines([{N, L} || {N, L} <- numbered(F),
                                                               lists:prefix("///",
                                                                            string:trim(L))]))]
        ++ [{F, Fence} || F <- ?DOCUMENTS, Fence <- fences(numbered(F))],
    [{F, Lines} || {F, Lines} <- Texts, Lines =/= []].

tokens(F, [{First, _} | _] = Lines) ->
    case ern_lexer:tokenize(lists:join("\n", [L || {_, L} <- Lines])) of
        {ok, Toks} ->
            [setelement(2, T, setelement(1, element(2, T), line(T) + First - 1)) || T <- Toks];
        {error, _} ->
            error({not_lexed, F, First})
    end.

%% The lines of the blocks of one statement. A brace is a block's unless
%% it follows an expression or `receive`, where it holds clauses.
blocks_of_one(Toks) ->
    blocks_of_one(Toks, none).

blocks_of_one([], _) -> [];
blocks_of_one([{'{', _} = B | Rest], Before) ->
    [line(B) || not ends_expression(Before), statements(Rest, 0) =:= 1]
        ++ blocks_of_one(Rest, B);
blocks_of_one([T | Rest], _) ->
    blocks_of_one(Rest, T).

statements([{'}', _} | _], 0) -> 1;
statements([{';', _} | Rest], 0) -> 1 + statements(Rest, 0);
statements([T | Rest], Depth) -> statements(Rest, Depth + depth(T)).

%% A name or a literal, a token of three, ends an expression, as a
%% closing bracket does.
ends_expression({_, _, _}) -> true;
ends_expression({Kind, _}) -> lists:member(Kind, [')', ']', '}', '>>', 'receive']);
ends_expression(none) -> false.

depth({Kind, _}) ->
    case Kind of
        _ when Kind =:= '('; Kind =:= '#('; Kind =:= '['; Kind =:= '{'; Kind =:= '<<' -> 1;
        _ when Kind =:= ')'; Kind =:= ']'; Kind =:= '}'; Kind =:= '>>' -> -1;
        _ -> 0
    end;
depth(_) -> 0.

line(T) -> element(1, element(2, T)).

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

%% emacs/README.md: the lines an init file needs are in the README and in
%% the header of emacs/ernest-mode.el, which is installed alone, and the two
%% give the same lines in the same order
emacs_installation_test() ->
    {ok, Readme} = file:read_file(filename:join(?ROOT, "emacs/README.md")),
    {ok, Mode} = file:read_file(filename:join(?ROOT, "emacs/ernest-mode.el")),
    Blocks = tl(binary:split(Readme, <<"```elisp\n">>, [global])),
    FromReadme = lists:append([lines(hd(binary:split(B, <<"```">>))) || B <- Blocks]),
    [_, AfterHead] = binary:split(Mode, <<";;; Installation:\n">>),
    [Installation, _] = binary:split(AfterHead, <<";;; Code:\n">>),
    FromHeader = [L || <<";;     ", L/binary>> <- binary:split(Installation, <<"\n">>, [global])],
    ?assert(length(FromReadme) >= 5),
    ?assertEqual(FromReadme, FromHeader).

lines(Text) ->
    [L || L <- binary:split(Text, <<"\n">>, [global]), L =/= <<>>].

%% docs/emacs_mode.md: the Emacs mode restates §2.4's reserved words, but
%% true and false, which it paints as constants, and a subset of §2.6's
%% symbols, so a test keeps the two equal. It found `=>`
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

%% docs/emacs_mode.md: the Emacs mode restates how tightly each binary
%% operator binds, which places a line an operator opens, so a test keeps
%% its table equal to the parser's. Written with the table.
%% report §2.6
emacs_mode_mirrors_the_parser_test() ->
    Parser = read("erl/parser/src/ern_parser.erl"),
    Mode = read("emacs/ernest-mode.el"),
    {match, InParser} = re:run(Parser, "^precedence\\('([^']+)'\\) -> \\{([0-9]+),",
                               [global, multiline, {capture, all_but_first, list}]),
    {match, InMode} = re:run(body(Mode, "(defconst ernest--precedence"),
                             "\\(\"([^\"]+)\" \\. ([0-9]+)\\)",
                             [global, {capture, all_but_first, list}]),
    ?assert(length(InParser) > 10),
    ?assertEqual(lists:sort(InParser), lists:sort(InMode)).

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
