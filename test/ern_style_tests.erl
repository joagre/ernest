%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ROOT, "..").

%% The documents whose ```ernest fences the Ernest style guide governs.
-define(DOCUMENTS, ["ernest_guide.md", "ernest_report.md"]).

%% docs/style.md: code lines are at most 100 characters, in the compiler's
%% Erlang, its C and in Ernest alike; the vendored getopt keeps its upstream form
line_length_test() ->
    Patterns = ["erl/*/src/*.erl", "erl/*/test/*.erl", "erl/*/c_src/*.c", "test/*.erl",
                "stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern", "test/**/*.ern",
                "test/*.py", "emacs/*.el", "emacs/test/*.el", "libs/**/*.ern"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                  filename:basename(F) =/= "getopt.erl",
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
                "libs/**/*.ern", "libs/*/*.md", "*.md", "docs/*.md"],
    Files = [F || P <- Patterns, F <- filelib:wildcard(P, ?ROOT),
                 filename:basename(F) =/= "getopt.erl",
                 not editor_artifact(filename:basename(F))],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{F, N} || F <- Files, {N, Line} <- numbered(F),
                                lists:member($\t, Line)]).

%% docs/style.md: one statement a line; a line of Ernest holds no `;` with
%% more code after it, in every module, every example in a module's doc
%% blocks, and every Ernest block of the guide and the report. A string, a
%% character and a comment are not code, and an input at the shell's prompt,
%% a console's line, is not checked. Written with the rule.
one_statement_a_line_test() ->
    Lines = [{F, N, L} || F <- modules(), {N, L} <- ernest_lines(F)]
        ++ [{F, N, L} || F <- ?DOCUMENTS, {N, L} <- lists:append(fences(numbered(F)))],
    ?assertEqual([], [{F, N} || {F, N, L} <- Lines, more_after_semicolon(L)]).

%% docs/style.md: a function's head ends at `=` and its body begins on the
%% next line, one step in from the line the head begins on; a body that is
%% a block opens its brace at the end of the head's line, and nothing
%% follows the brace there; a `foreign fn`'s string stays on the head's
%% line. Read from the tokens of every text one_statement_a_line_test
%% reads. Written with the rule.
function_head_test() ->
    ?assertEqual([], [{F, N} || {F, Toks} <- ernest_tokens(), N <- head_breaks(Toks)]).

%% docs/style.md: a block holds more than one statement, in every text
%% one_statement_a_line_test reads. A brace after an expression or after
%% `receive` holds clauses and is not a block. Written with the rule.
block_of_one_test() ->
    ?assertEqual([], [{F, N} || {F, Toks} <- ernest_tokens(), N <- blocks_of_one(Toks)]).

%% The modules the Ernest style guide governs.
modules() ->
    Modules = [F || P <- ["stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern",
                          "libs/**/*.ern", "test/**/*.ern"],
                    F <- filelib:wildcard(P, ?ROOT),
                    not lists:prefix("test/build/", F),
                    not editor_artifact(filename:basename(F))],
    ?assert(length(Modules) > 20),
    Modules.

%% A module's lines of Ernest: its code, and the examples in its doc blocks.
ernest_lines(F) ->
    {Docs, Code} = lists:partition(fun({_, L}) -> lists:prefix("///", string:trim(L)) end,
                                   numbered(F)),
    Code ++ lists:append(fences(doc_lines(Docs))).

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
    Texts = [{F, numbered(F)} || F <- modules()]
        ++ [{F, Fence} || F <- modules(),
                          Fence <- fences(doc_lines([{N, L} || {N, L} <- numbered(F),
                                                               lists:prefix("///",
                                                                            string:trim(L))]))]
        ++ [{F, Fence} || F <- ?DOCUMENTS, Fence <- fences(numbered(F))],
    [{F, tokens(F, Lines)} || {F, Lines} <- Texts, Lines =/= []].

tokens(F, [{First, _} | _] = Lines) ->
    case ern_lexer:tokenize(lists:join("\n", [L || {_, L} <- Lines])) of
        {ok, Toks} ->
            [setelement(2, T, setelement(1, element(2, T), line(T) + First - 1)) || T <- Toks];
        {error, _} ->
            error({not_lexed, F, First})
    end.

%% The lines of the function heads that break the rule. A `fn` followed
%% by a name declares a function; a lambda's is followed by `(`.
head_breaks(Toks) ->
    First = maps:from_list(lists:reverse([{line(T), column(T)} || T <- Toks])),
    head_breaks(Toks, First).

head_breaks([], _) -> [];
head_breaks([{foreign, _}, {fn, _} | Rest], First) ->
    {Eq, [Impl | _]} = after_head(Rest),
    [line(Eq) || line(Impl) =/= line(Eq)] ++ head_breaks(Rest, First);
head_breaks([{fn, _} = Fn, {Kind, _, _} = Name | Rest], First)
  when Kind =:= ident; Kind =:= typename ->
    {Eq, [Body | After]} = after_head(Rest),
    Broken = case Body of
                 {'{', _} -> line(Body) =/= line(Eq) orelse line(hd(After)) =:= line(Body);
                 _ -> line(Body) =:= line(Eq)
                          orelse column(Body) =/= maps:get(line(Fn), First) + 4
             end,
    [line(Eq) || Broken] ++ head_breaks([Name | Rest], First);
head_breaks([_ | Rest], First) ->
    head_breaks(Rest, First).

%% The `=` that ends a head, the first outside a bracket after the
%% parameters open, and the tokens after it.
after_head(Toks) ->
    equals(lists:dropwhile(fun(T) -> element(1, T) =/= '(' end, Toks), 0).

equals([{'=', _} = Eq | Rest], 0) -> {Eq, Rest};
equals([T | Rest], Depth) -> equals(Rest, Depth + depth(T)).

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

column(T) -> element(2, element(2, T)).

%% Whether a `;` has code after it on the line, strings, characters and a
%% comment aside.
more_after_semicolon(Line) ->
    Code = code_of(Line),
    case string:split(Code, ";") of
        [_, After] -> string:trim(After) =/= "" orelse more_after_semicolon(After);
        [_] -> false
    end.

code_of([]) -> [];
code_of("//" ++ _) -> [];
code_of([$" | Rest]) -> [$" | code_of(after_quote(Rest, $"))];
code_of([$', $\\, _, $' | Rest]) -> "''" ++ code_of(Rest);
code_of([$', _, $' | Rest]) -> "''" ++ code_of(Rest);
code_of([C | Rest]) -> [C | code_of(Rest)].

after_quote([], _) -> [];
after_quote([$\\, _ | Rest], Q) -> after_quote(Rest, Q);
after_quote([Q | Rest], Q) -> Rest;
after_quote([_ | Rest], Q) -> after_quote(Rest, Q).

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
