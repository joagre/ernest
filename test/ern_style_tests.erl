%% The style guides, docs/style.md, where a machine can check them.
-module(ern_style_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_formatted/0]).

-define(ROOT, "..").

%% The documents whose ```ernest fences the Ernest style guide governs.
-define(DOCUMENTS, ["ernest_guide.md", "report/language.md", "report/toolchain.md",
                    "report/library.md"]).

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
                "test/Makefile", "erl/*/src/Makefile", "erl/app.mk", "tools/release/Makefile"],
    Files = [File || File <- ern_repository:files(Patterns),
                     filename:basename(File) =/= "getopt.erl",
                     not lists:prefix("test/build/", File)],
    ?assert(length(Files) > 20),
    Long = [{File, Number} || File <- Files,
                              {Number, Line} <- numbered(File),
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
    Files = [File || File <- ern_repository:files(Patterns),
                     filename:basename(File) =/= "getopt.erl",
                     not lists:prefix("test/build/", File)],
    ?assert(length(Files) > 20),
    ?assertEqual([], [{File, Number} || File <- Files, {Number, Line} <- numbered(File),
                                        lists:member($\t, Line)]).

%% docs/style.md: one `-export` list, in the order the functions appear,
%% and a `-spec` on every exported function, in the toolchain's modules;
%% the vendored getopt keeps its upstream form. Written after the rule,
%% when six modules had fallen out of order and one had lost its specs
exports_test() ->
    Files = [File || File <- ern_repository:files(["erl/*/src/*.erl"]),
                     filename:basename(File) =/= "getopt.erl"],
    ?assert(length(Files) > 20),
    ?assertEqual([],
                 [{File, Fault} || File <- Files,
                                   Fault <- export_faults(filename:join(?ROOT, File))]).

export_faults(File) ->
    {ok, Forms} = epp_dodger:quick_parse_file(File),
    Lists = [Exported || {attribute, _, export, Exported} <- Forms],
    Exports = lists:append(Lists),
    Specs = [FunctionArity || {attribute, _, spec, {FunctionArity, _}} <- Forms],
    Appear = [{Name, Arity} || {function, _, Name, Arity, _} <- Forms,
                               lists:member({Name, Arity}, Exports)],
    [lists_of_exports || length(Lists) > 1]
        ++ [out_of_order
            || Appear =/= [FunctionArity || FunctionArity <- Exports,
                                            lists:member(FunctionArity, Appear)]]
        ++ [{no_spec, FunctionArity} || FunctionArity <- Exports,
                                        not lists:member(FunctionArity, Specs)].

%% docs/style.md: a block holds more than one statement, in every module,
%% every example in a module's doc blocks, and every Ernest block of the
%% guide and the report. A brace after an expression or after `receive`
%% holds clauses and is not a block. Written with the rule.
block_of_one_test() ->
    ?assertEqual([],
                 [{File, Number} || {File, Tokens} <- ernest_tokens(),
                                    Number <- blocks_of_one(Tokens)]).

%% report §11.6: every module is in the layout `ern format`
%% writes, the examples of its doc blocks with it, and so is every Ernest
%% block of the guide and the report that parses; `make format` lays out
%% what is not. Written with the formatter, as the style guide's hand-made
%% checks of a statement a line, a function's head and the blank line
%% between declarations, which it holds, went.
formatted_test_() ->
    {timeout, 120,
     fun() ->
         ?assertEqual([], [File || File <- modules(), not formatted(File)]),
         ?assertEqual([], [File || File <- ?DOCUMENTS, not document_formatted(File)])
     end}.

formatted(File) ->
    Bytes = ern_repository:read(File),
    ern_format:format(Bytes) =:= {ok, Bytes}.

document_formatted(File) ->
    Bytes = ern_repository:read(File),
    ern_format:markdown(Bytes) =:= Bytes.

%% The Ernest blocks of the documents laid out, for `make format`.
write_formatted() ->
    lists:foreach(fun(Document) ->
                      Path = filename:join(?ROOT, Document),
                      Bytes = ern_repository:read(Document),
                      case ern_format:markdown(Bytes) of
                          Bytes -> ok;
                          Formatted -> ok = file:write_file(Path, Formatted)
                      end
                  end, ?DOCUMENTS).

%% The modules the Ernest style guide governs.
modules() ->
    Patterns = ["stdlib/**/*.ern", "examples/**/*.ern", "shell/**/*.ern", "libs/**/*.ern",
                "tools/*.ern", "test/**/*.ern", "proposals/operations/programs/*.ern",
                "proposals/nodes_and_code/experiments/code_update/**/*.ern"],
    Modules = [File || File <- ern_repository:files(Patterns),
                       not lists:prefix("test/build/", File)],
    ?assert(length(Modules) > 20),
    Modules.

doc_lines(Docs) ->
    [{Number, lists:nthtail(3, string:trim(Line, leading))} || {Number, Line} <- Docs].

%% The ```ernest fences, each its lines, an example that must not compile
%% among them.
fences(Lines) ->
    fences(Lines, none).

fences([], _) -> [];
fences([{Number, Line} | Rest], Inside) ->
    case {lists:prefix("```", string:trim(Line)), Inside} of
        {true, none} ->
            case lists:prefix("```ernest", string:trim(Line)) of
                true -> fences(Rest, []);
                false -> fences(Rest, other)
            end;
        {true, other} -> fences(Rest, none);
        {true, Fence} -> [lists:reverse(Fence) | fences(Rest, none)];
        {false, other} -> fences(Rest, other);
        {false, none} -> fences(Rest, none);
        {false, Fence} -> fences(Rest, [{Number, Line} | Fence])
    end.

%% Each text of Ernest as the lexer's tokens, their lines the file's: a
%% module whole, each example of its doc blocks, and each fence of the
%% documents. A text the lexer refuses fails the test with its file.
ernest_tokens() ->
    [{File, tokens(File, Lines)} || {File, Lines} <- ernest_texts()].

%% Each text of Ernest as its numbered lines.
ernest_texts() ->
    Texts = [{File, numbered(File)} || File <- modules()]
        ++ [{File, Fence} || File <- modules(),
                             Fence <- fences(doc_lines([{Number, Line}
                                                        || {Number, Line} <- numbered(File),
                                                           lists:prefix("///",
                                                                        string:trim(Line))]))]
        ++ [{File, Fence} || File <- ?DOCUMENTS, Fence <- fences(numbered(File))],
    [{File, Lines} || {File, Lines} <- Texts, Lines =/= []].

tokens(File, [{First, _} | _] = Lines) ->
    case ern_lexer:tokenize(lists:join("\n", [Line || {_, Line} <- Lines])) of
        {ok, Tokens} ->
            [moved(Token, First - 1) || Token <- Tokens];
        {error, _} ->
            error({not_lexed, File, First})
    end.

%% The lines of the blocks of one statement. A brace is a block's unless
%% it follows an expression or `receive`, where it holds clauses.
blocks_of_one(Tokens) ->
    blocks_of_one(Tokens, none).

blocks_of_one([], _) -> [];
blocks_of_one([{'{', _} = Brace | Rest], Before) ->
    [line(Brace) || not ends_expression(Before), statements(Rest, 0) =:= 1]
        ++ blocks_of_one(Rest, Brace);
blocks_of_one([Token | Rest], _) ->
    blocks_of_one(Rest, Token).

statements([{'}', _} | _], 0) -> 1;
statements([{';', _} | Rest], 0) -> 1 + statements(Rest, 0);
statements([Token | Rest], Depth) -> statements(Rest, Depth + depth(Token)).

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

%% A token's line, the first of its position, which ern_parser reads so too.
line(Token) ->
    {Line, _, _, _} = element(2, Token),
    Line.

%% A token whose line is a number of lines further down; only its line is
%% read here.
moved(Token, Offset) ->
    {Line, Column, End, Previous} = element(2, Token),
    setelement(2, Token, {Line + Offset, Column, End, Previous}).

%% docs/style.md: every Erlang module is ern_<thing>, unique across the
%% repository, and a module compiled from an Ernest source is ern@<namespace>;
%% the one exception is a vendored file, which THIRD_PARTY_LICENSES names
module_name_test() ->
    ErlangFiles = ern_repository:files(["erl/*/src/*.erl", "erl/*/test/*.erl", "test/*.erl"]),
    ?assert(length(ErlangFiles) > 20),
    Names = [filename:basename(File, ".erl") || File <- ErlangFiles],
    ?assertEqual([], [Name || Name <- Names, string:prefix(Name, "ern_") =:= nomatch,
                              not vendored(Name)]),
    %% the module attribute agrees with the file name, so a grep finds both
    ?assertEqual([], [File || File <- ErlangFiles,
                              not has_line(File, "-module(" ++ filename:basename(File, ".erl")
                                                 ++ ").")]),
    %% unique across the repository, which the directory no longer disambiguates
    ?assertEqual([], Names -- lists:usort(Names)),
    Sources = lists:usort(ern_repository:files(["stdlib/**/*.ern"])),
    ?assert(length(Sources) > 10),
    ?assertEqual([], [File || File <- Sources, not compiled_as(File)]).

%% emacs/README.md: the lines an init file needs are in the README and in
%% the header of emacs/ernest-mode.el, which is installed alone, and the two
%% give the same lines in the same order
emacs_installation_test() ->
    Readme = ern_repository:read("emacs/README.md"),
    Mode = ern_repository:read("emacs/ernest-mode.el"),
    Blocks = tl(binary:split(Readme, <<"```elisp\n">>, [global])),
    FromReadme = lists:append([lines(hd(binary:split(Block, <<"```">>))) || Block <- Blocks]),
    [_, AfterHead] = binary:split(Mode, <<";;; Installation:\n">>),
    [Installation, _] = binary:split(AfterHead, <<";;; Code:\n">>),
    FromHeader = [Line
                  || <<";;     ", Line/binary>> <- binary:split(Installation, <<"\n">>, [global])],
    ?assert(length(FromReadme) >= 5),
    ?assertEqual(FromReadme, FromHeader).

lines(Text) ->
    [Line || Line <- binary:split(Text, <<"\n">>, [global]), Line =/= <<>>].

%% proposals/emacs/emacs_mode.md: the Emacs mode restates §2.4's reserved words, but
%% true and false, which it paints as constants, and a subset of §2.6's
%% symbols, so a test keeps the two equal. It found `=>`
%% and `do`, which the mode painted and the language does not have.
%% report §2.4, Appendix A
emacs_mode_mirrors_the_lexer_test() ->
    Lexer = unicode:characters_to_list(ern_repository:read("erl/lexer/src/ern_lexer.erl")),
    Mode = unicode:characters_to_list(ern_repository:read("emacs/ernest-mode.el")),
    ?assertEqual(lists:sort(atoms_of(Lexer, "-define(RESERVED,")),
                 lists:sort(strings_of(Mode, "(defconst ernest-reserved-words"))),
    Symbols = strings_of(Lexer, "-define(SYMBOLS,"),
    ?assert(length(Symbols) > 20),
    Painted = strings_of(Mode, "(defconst ernest-operators"),
    ?assert(length(Painted) > 5),
    ?assertEqual([], Painted -- Symbols).

%% proposals/emacs/emacs_mode.md: the Emacs mode restates how tightly each binary
%% operator binds, which places a line an operator opens, so a test keeps
%% its table equal to the parser's. Written with the table.
%% report §2.6
emacs_mode_mirrors_the_parser_test() ->
    Parser = unicode:characters_to_list(ern_repository:read("erl/parser/src/ern_parser.erl")),
    Mode = unicode:characters_to_list(ern_repository:read("emacs/ernest-mode.el")),
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
        {match, Found} -> [String || [String] <- Found];
        nomatch -> []
    end.

atoms_of(Text, Marker) ->
    [string:trim(Piece, both, "' \n\t") || Piece <- string:split(body(Text, Marker), ",", all)].

%% From the list that opens after Marker to the bracket that closes it. A
%% bracket inside a string is not one: the symbol table lists "(" and ")".
body(Text, Marker) ->
    Rest = string:find(Text, Marker),
    ?assertNotEqual(nomatch, Rest),
    {_, [Open | Body]} = string:take(string:slice(Rest, length(Marker)), "[(", true),
    Close = case Open of $[ -> $]; $( -> $) end,
    scan(Body, Open, Close, 0, []).

scan([], _, _, _, Acc) -> lists:reverse(Acc);
scan([$" | Rest], Open, Close, Depth, Acc) -> in_string(Rest, Open, Close, Depth, [$" | Acc]);
scan([Char | Rest], Open, Close, Depth, Acc) when Char =:= Open ->
    scan(Rest, Open, Close, Depth + 1, [Char | Acc]);
scan([Char | _], _, Close, 0, Acc) when Char =:= Close -> lists:reverse(Acc);
scan([Char | Rest], Open, Close, Depth, Acc) when Char =:= Close ->
    scan(Rest, Open, Close, Depth - 1, [Char | Acc]);
scan([Char | Rest], Open, Close, Depth, Acc) -> scan(Rest, Open, Close, Depth, [Char | Acc]).

in_string([$\\, Char | Rest], Open, Close, Depth, Acc) ->
    in_string(Rest, Open, Close, Depth, [Char, $\\ | Acc]);
in_string([$" | Rest], Open, Close, Depth, Acc) -> scan(Rest, Open, Close, Depth, [$" | Acc]);
in_string([Char | Rest], Open, Close, Depth, Acc) ->
    in_string(Rest, Open, Close, Depth, [Char | Acc]);
in_string([], _, _, _, Acc) -> lists:reverse(Acc).

%% THIRD_PARTY_LICENSES names every borrowed file, so the exception is checked
%% rather than listed twice.
vendored(Name) ->
    string:find(ern_repository:read("THIRD_PARTY_LICENSES"), Name ++ ".erl") =/= nomatch.

%% build/stdlib holds the standard library under the name erlang_module/1 gives it.
compiled_as(Relative) ->
    Namespace = string:replace(filename:rootname(filename:basename(Relative)), "/", "@", all),
    Beam = filename:join([?ROOT, "build", "stdlib", "ern@" ++ lists:flatten(Namespace) ++ ".beam"]),
    filelib:is_regular(Beam).

has_line(Relative, Line) ->
    lists:member(Line, [Text || {_, Text} <- numbered(Relative)]).

numbered(Relative) ->
    Text = unicode:characters_to_list(ern_repository:read(Relative)),
    Lines = string:split(Text, "\n", all),
    lists:zip(lists:seq(1, length(Lines)), Lines).
