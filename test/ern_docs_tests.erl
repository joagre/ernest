%% The documents' citations resolve: every `§x.y`, `Appendix X`, and `E.n`
%% written in a live document names a heading of the report, and the
%% guide's own bare `§x.y` names a heading of the guide. docs/decisions.md
%% is history and is not checked.
-module(ern_docs_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_contents/0]).

-define(ROOT, "..").

%% The report's three files (report §0), the language's, the toolchain's
%% and the standard library's, which are one report.
-define(REPORT, ["report/language.md", "report/toolchain.md", "report/library.md"]).

%% The documents with a contents list, and the lines that bound it.
-define(CONTENTS, ?REPORT ++ ["ernest_guide.md"]).
-define(BEGIN, <<"<!-- contents -->">>).
-define(END, <<"<!-- /contents -->">>).

%% report §11, docs/development.md "Building": `make xref`
citations_resolve_test() ->
    Report = report(),
    Guide = read("ernest_guide.md"),
    ReportSections = section_numbers(Report),
    GuideSections = section_numbers(Guide),
    %% docs/findings.md's lines cite each document as its reader did, the
    %% guide's sections bare beside the report's, and the list goes when a
    %% review's findings are done
    Live = (documents() -- ["docs/findings.md"]) ++ examples() ++ stdlib() ++ shell() ++ tools(),
    Dangling =
        [{File, Citation} || File <- Live, Citation <- cites(read(File)),
                             not resolves(Citation, report, ReportSections, GuideSections)]
        ++ [{"ernest_guide.md", Citation}
            || Citation <- cites(Guide),
               not resolves(Citation, guide, ReportSections, GuideSections)],
    ?assertEqual([], Dangling).

%% ernest_guide.md §7.3, report Appendix E.25: the guide shows
%% stdlib/ordered_set.ern whole but for its doc blocks, a restatement a
%% teaching document makes, and this holds the two equal
ordered_set_shown_whole_test() ->
    Guide = read("ernest_guide.md"),
    [_, Rest] = binary:split(Guide, <<"```ernest-fragment\n// stdlib/ordered_set.ern">>),
    [Block | _] = binary:split(Rest, <<"\n```">>),
    [_Named | Shown] = binary:split(Block, <<"\n">>, [global]),
    Source = read("stdlib/ordered_set.ern"),
    Code = [Line || Line <- binary:split(Source, <<"\n">>, [global]),
                    not lists:prefix("///", binary_to_list(Line))],
    ?assertEqual(unpadded(Code), unpadded(Shown)).

%% Lines without the blank ones that begin and end them.
unpadded(Lines) ->
    Blank = fun(Line) -> Line =:= <<>> end,
    lists:reverse(lists:dropwhile(Blank, lists:reverse(lists:dropwhile(Blank, Lines)))).

%% report/, ernest_guide.md, docs/development.md "Building": a document's
%% contents list is its top-level sections, its headings of level two, each
%% linked to its heading, which `make contents` writes
contents_test() ->
    [?assertEqual({File, contents(Document)}, {File, listed(Document)})
     || File <- ?CONTENTS, Document <- [read(File)]].

%% Rewrite the contents list of every document that has one.
-spec write_contents() -> ok.
write_contents() ->
    lists:foreach(fun(File) ->
                      Document = read(File),
                      [Before, Rest] = binary:split(Document, ?BEGIN),
                      [_, After] = binary:split(Rest, ?END),
                      ok = file:write_file(filename:join(?ROOT, File),
                                           [Before, ?BEGIN, contents(Document), ?END, After])
                  end, ?CONTENTS).

listed(Document) ->
    [_, Rest] = binary:split(Document, ?BEGIN),
    [List, _] = binary:split(Rest, ?END),
    List.

%% The list: a line per heading of level two, linked by the anchor a
%% renderer gives it; the anchors are counted over every heading, since a
%% renderer numbers a repeated one whatever its level.
contents(Document) ->
    Entries = [["- [", Text, "](#", Anchor, ")\n"]
               || {2, Text, Anchor} <- anchored(heads(Document))],
    iolist_to_binary(["\n", Entries]).

%% Every heading outside a fenced block, with its level and its text.
heads(Document) ->
    heads(binary:split(Document, <<"\n">>, [global]), false, []).

heads([], _, Acc) ->
    lists:reverse(Acc);
heads([<<"```", _/binary>> | Rest], Fenced, Acc) ->
    heads(Rest, not Fenced, Acc);
heads([Line | Rest], false, Acc) ->
    case re:run(Line, "^(#{1,6}) +(.*?) *$", [{capture, all_but_first, binary}, unicode]) of
        {match, [Hashes, Text]} -> heads(Rest, false, [{byte_size(Hashes), Text} | Acc]);
        nomatch -> heads(Rest, false, Acc)
    end;
heads([_ | Rest], true, Acc) ->
    heads(Rest, true, Acc).

%% GitHub's anchors: lowercase, every character but a letter, a digit, an
%% underscore, a space or a hyphen dropped, spaces as hyphens, and a second
%% heading of the same anchor numbered `-1`, a third `-2`.
anchored(Heads) ->
    {Anchored, _} =
        lists:mapfoldl(
          fun({Level, Text}, Seen) ->
              Lower = string:lowercase(Text),
              Kept = re:replace(Lower, "[^\\p{L}\\p{M}\\p{N}_ \\-]", "",
                                [global, unicode, ucp, {return, binary}]),
              Base = binary:replace(Kept, <<" ">>, <<"-">>, [global]),
              Count = maps:get(Base, Seen, 0),
              Anchor = case Count of
                           0 -> Base;
                           _ -> <<Base/binary, "-", (integer_to_binary(Count))/binary>>
                       end,
              {{Level, Text, Anchor}, Seen#{Base => Count + 1}}
          end, #{}, Heads),
    Anchored.

%% README.md, guide §0, CLAUDE.md *Who owns each fact*: the front
%% page's list of what Ernest adds is the guide's, word for word, so that the
%% two cannot drift apart
what_ernest_adds_test() ->
    ?assertEqual(adds(read("ernest_guide.md")), adds(read("README.md"))).

adds(Document) ->
    [_, Rest] = binary:split(Document, <<"What Ernest adds is where the parts meet:\n\n">>),
    [List | _] = binary:split(Rest, <<"\n\n">>),
    List.

%% docs/style.md, docs/development.md "The layout of the repository": a document that says
%% where things are names things that are there, from the repository's root
%% or, as shell/README.md does, from its own directory. The report and the
%% guide name paths a program might have, `net/http.ern`, the plan
%% paths not yet written, and the findings' lists the paths of the tree
%% their readers read, so every other document is checked.
document_paths_test() ->
    Missing = [{File, Path} || File <- described(), Path <- paths(read(File)), not exists(Path),
                               not exists(filename:join(filename:dirname(File), Path))],
    ?assertEqual([], Missing).

%% docs/release_review.md, step 5: man/ holds the pages of the release
%% VERSION names, which `make pages` writes, so the release that changes
%% VERSION writes them again; a page names the version of the ern that
%% wrote it on its last line, man/README.md the release in its title, and
%% every page and index but man/README.md is linked from one index, a
%% directory's README.md
release_pages_test() ->
    Version = string:trim(read("VERSION")),
    Files = filelib:wildcard("man/**/*.md", ?ROOT),
    Indexes = [File || File <- Files, filename:basename(File) =:= "README.md"],
    Pages = Files -- Indexes,
    ?assert(length(Pages) > 25),
    ?assertMatch(<<"# Ernest ", Version:(byte_size(Version))/binary, "\n", _/binary>>,
                 read("man/README.md")),
    Written = <<"Generated by ern ", Version/binary, " from ">>,
    ?assertEqual([], [Page || Page <- Pages, binary:match(read(Page), Written) =:= nomatch]),
    Linked = [filename:join(filename:dirname(Index), Link) || Index <- Indexes,
                                                              Link <- page_links(read(Index))],
    ?assertEqual(lists:sort(Files -- ["man/README.md"]), lists:sort(Linked)).

%% An index's links to pages within man/.
page_links(IndexText) ->
    {match, Links} = re:run(IndexText, "\\]\\(([^)]+\\.md)\\)",
                            [global, {capture, all_but_first, list}]),
    [Link || [Link] <- Links, not lists:prefix("../", Link)].

%% Every document the repository tracks, the guide aside, whose citations
%% are its own sections, and the log, whose entries say what was; man/'s
%% pages are what `ern doc` wrote of sources these tests read. A
%% regression: the lists were written out, and left out five documents
%% and four directories (findings.md's D4)
documents() ->
    Tracked = string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files '*.md'"), "\n"),
    Found = [File || File <- Tracked,
                     not lists:member(File, ["ernest_guide.md", "docs/decisions.md"]),
                     not lists:prefix("man/", File)],
    ?assert(length(Found) > 15),
    Found.

%% The documents that describe the repository as it is.
described() ->
    documents() -- (?REPORT ++ ["docs/implementation_plan.md"]).

%% A backticked path under one of the repository's own directories. A
%% metavariable is written `<name>`, as docs/style.md writes `ern_<thing>`,
%% and a wildcard stands for a set, so neither names one file.
paths(Document) ->
    Tops = ["erl/", "docs/", "test/", "bin/", "stdlib/", "examples/", "build/", "shell/",
            "libs/", "tools/", "emacs/", "assets/"],
    Pieces = binary:split(Document, <<"`">>, [global]),
    [binary_to_list(Piece) || {Index, Piece} <- lists:zip(lists:seq(1, length(Pieces)), Pieces),
                              Index rem 2 =:= 0,
                              lists:any(fun(Top) -> lists:prefix(Top, binary_to_list(Piece)) end,
                                        Tops),
                              binary:match(Piece, [<<"*">>, <<"<">>]) =:= nomatch,
                              binary:last(Piece) =/= $/].

exists(Relative) ->
    filelib:is_file(filename:join(?ROOT, Relative)).

%% THIRD_PARTY_LICENSES: every tracked file that
%% carries an upstream author's copyright, and every file that holds a
%% table a tool generated, is an entry's path; and every entry names a
%% file that is there, and its licence
third_party_test() ->
    Entries = [Entry || Entry <- binary:split(read("THIRD_PARTY_LICENSES"), <<"\n----">>, [global]),
                        binary:match(Entry, <<"  Path:">>) =/= nomatch],
    Listed = [path(Entry) || Entry <- Entries],
    Tracked = [File || File <- string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files"), "\n"),
                       not lists:member(File, ["LICENSE", "THIRD_PARTY_LICENSES"])],
    Owed = [File || File <- Tracked, filelib:is_regular(filename:join(?ROOT, File)),
                    borrowed(read(File)) orelse generated(read(File))],
    ?assert(length(Owed) >= 2),
    ?assertEqual([], Owed -- Listed),
    ?assertEqual([], [Path || Path <- Listed, not filelib:is_regular(filename:join(?ROOT, Path))]),
    ?assertEqual([],
                 [path(Entry) || Entry <- Entries,
                                 binary:match(Entry, <<"  License:">>) =:= nomatch]).

%% An entry's path, the first word after its `Path:`.
path(Entry) ->
    {match, [Path]} = re:run(Entry, "^  Path: +([^ ,\n]+)",
                             [multiline, {capture, all_but_first, list}]),
    Path.

%% report Appendix F: the glossary holds a term a line, in alphabetical
%% order, the backticks of a keyword and the case of a letter aside, and
%% each with a section of the report that defines it, which
%% citations_resolve_test holds to a heading. A regression test, written
%% when the report was split: no test had read the glossary
glossary_test() ->
    [_, Rest] = binary:split(read("report/language.md"), <<"## Appendix F. Glossary">>),
    [Glossary | _] = binary:split(Rest, <<"\n## ">>),
    Entries = [Line || Line <- binary:split(Glossary, <<"\n">>, [global]),
                       binary:match(Line, <<"- **">>) =:= {0, 4}],
    ?assert(length(Entries) > 100),
    Terms = [string:lowercase(binary:replace(Term, <<"`">>, <<>>, [global]))
             || Entry <- Entries,
                {match, [Term]} <- [re:run(Entry, "^- \\*\\*(.+?)\\*\\*",
                                           [{capture, all_but_first, binary}])]],
    ?assertEqual(length(Entries), length(Terms)),
    ?assertEqual(lists:sort(Terms), Terms),
    ?assertEqual([], [Entry || Entry <- Entries,
                               re:run(Entry, "§[0-9]|Appendix [A-G]") =:= nomatch]).

%% report §7.4: a cause of a fault quoted in sections
%% 0 to 11 outside §7.4 is one §7.4 lists, since §7.4 holds the causes
%% (§7.3); a library function's own section holds its faults (Appendix E.0
%% shape rule 4). In §7.4's texts `...`, `m:f/n` and a placeholder of one
%% letter stand for any text.
fault_causes_test() ->
    Language = read("report/language.md"),
    [Before, Rest] = binary:split(Language, <<"### 7.4 Causes of faults">>),
    [Own, After] = binary:split(Rest, <<"\n## 8. Programs">>),
    [Chapters, _] = binary:split(After, <<"\n## Appendix A">>),
    [Toolchain, _] = binary:split(read("report/toolchain.md"), <<"\n## Appendix C">>),
    Body = <<Chapters/binary, Toolchain/binary>>,
    Templates = [template(Cause) || Cause <- causes(Own)],
    ?assert(length(Templates) > 20),
    ?assertEqual([], [Cause || Cause <- causes(Before) ++ causes(Body),
                               not lists:any(fun(Template) ->
                                                 re:run(Cause, Template) =/= nomatch
                                             end, Templates)]).

causes(Document) ->
    case re:run(Document, "Fault\\(\"([^\"]*)\"\\)", [global, {capture, all_but_first, binary}]) of
        {match, Found} -> [Cause || [Cause] <- Found];
        nomatch -> []
    end.

%% A cause as a pattern: its text, with `...`, `m:f/n` and a word of one
%% letter matching any text.
template(Cause) ->
    Words = [case Word of
                 <<"...">> -> <<".*">>;
                 <<"m:f/n">> -> <<".+">>;
                 <<_>> when Word =/= <<"a">> -> <<".+">>;
                 _ -> re:replace(Word, "[.^$*+?()\\[\\]{}|\\\\]", "\\\\&",
                                 [global, {return, binary}])
             end || Word <- binary:split(Cause, <<" ">>, [global])],
    iolist_to_binary(["^", lists:join(" ", Words), "$"]).

%% docs/decisions.md: its index names every section by its title, the
%% standing ones and the dated entries. A regression test, written after the
%% index had missed thirty-eight entries (the log's *A Port Lost While It
%% Starts*); it does not check an anchor, which the reader's renderer makes.
log_index_names_every_section_test() ->
    Log = read("docs/decisions.md"),
    [_, AfterHeading] = binary:split(Log, <<"\n## Index\n">>),
    [Index, _] = binary:split(AfterHeading, <<"\n## ">>),
    {match, Named} = re:run(Index, "\\[((?:[^][]|\\[[^]]*\\])+)\\]\\(#",
                            [global, {capture, all_but_first, binary}]),
    {match, Heads} = re:run(Log, "^## (.+)$",
                            [global, multiline, {capture, all_but_first, binary}]),
    Titles = [hd(binary:split(Head, <<", 2026-">>)) || [Head] <- Heads, Head =/= <<"Index">>],
    ?assert(length(Titles) > 500),
    ?assertEqual([], Titles -- [Name || [Name] <- Named]).

%% A copyright in the first lines, an upstream author's header.
borrowed(Text) ->
    Head = binary:part(Text, 0, min(byte_size(Text), 2000)),
    re:run(Head, "copyright", [caseless]) =/= nomatch.

%% A table a tool of the repository wrote, by the marker it begins with.
generated(Text) ->
    re:run(Text, "^// Generated by tools/", [multiline]) =/= nomatch.

read(Relative) ->
    {ok, Bytes} = file:read_file(filename:join(?ROOT, Relative)),
    Bytes.

%% The report, its three files read as one text.
report() ->
    iolist_to_binary([read(File) || File <- ?REPORT]).

%% A name that begins with a dot is no module (report §11.1's path shape),
%% and an editor's lock file, `.#main.ern`, is one that may not be readable.
examples() ->
    [filename:join("examples", File)
     || File <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "examples")),
        not is_editor_file(File)].

%% The shell's Ernest source, whose comments cite the report as the
%% standard library's do.
shell() ->
    [filename:join("shell", File)
     || File <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "shell")),
        not is_editor_file(File)].

%% The programs of the build written in Ernest, whose comments cite the
%% report too.
tools() ->
    [filename:join("tools", File)
     || File <- filelib:wildcard("*.ern", filename:join(?ROOT, "tools")), not is_editor_file(File)].

stdlib() ->
    [filename:join("stdlib", File)
     || File <- filelib:wildcard("*.ern", filename:join(?ROOT, "stdlib")), not is_editor_file(File)]
    ++ [filename:join("libs", File)
        || File <- filelib:wildcard("*/*.ern", filename:join(?ROOT, "libs")),
           not is_editor_file(File)].

%% An editor's lock file, `.#editor.ern`, a link to nothing while the file
%% is open, and its auto-save file, `#editor.ern#`: neither is a module.
is_editor_file(File) ->
    lists:member(hd(filename:basename(File)), ".#").

%% "3.9", "3", "Appendix A", "E.12" for the headings of a document.
section_numbers(Document) ->
    Lines = binary:split(Document, <<"\n">>, [global]),
    lists:append([line_section_numbers(Line) || Line <- Lines]).

%% The section numbers a line that is a heading names; none for any other.
line_section_numbers(Line) ->
    case re:run(Line, "^#{1,3} (?:([0-9]+(?:\\.[0-9]+)?)\\.? |Appendix ([A-Z])(?:\\.([0-9]+))?\\.)",
                [{capture, all_but_first, list}]) of
        {match, [Number]} -> [Number];
        {match, [[], Letter]} -> ["Appendix " ++ Letter];
        {match, [[], Letter, Section]} -> ["Appendix " ++ Letter, Letter ++ "." ++ Section];
        nomatch -> []
    end.

%% Every citation in a document: {Kind, Target} with Kind report, guide,
%% or bare, the bare ones resolved by the document's own convention.
cites(Document) ->
    SectionCites = [{kind(Word), Number}
                    || [Word, Number] <- matches(Document, "([Rr]eport|[Gg]uide)?,? ?"
                                                           "§([0-9]+(?:\\.[0-9]+)?)")],
    AppendixCites = [case Appendix of
                         [Letter] -> {report, "Appendix " ++ Letter};
                         [Letter, Section] -> {report, Letter ++ "." ++ Section}
                     end
                     || Appendix <- matches(Document, "Appendix ([A-Z])(?:\\.([0-9]+))?")],
    LibraryCites = [{report, "E." ++ Section}
                    || [Section] <- matches(Document, "\\bE\\.([0-9]+)\\b")],
    lists:usort(SectionCites ++ AppendixCites ++ LibraryCites).

%% Every match of a pattern in a document, each its captured groups.
matches(Document, Pattern) ->
    case re:run(Document, Pattern, [global, unicode, {capture, all_but_first, list}]) of
        {match, Found} -> Found;
        nomatch -> []
    end.

kind([]) -> bare;
kind(Word) -> list_to_atom(string:lowercase(Word)).

resolves({report, Target}, _, ReportSections, _) -> lists:member(Target, ReportSections);
resolves({guide, Target}, _, _, GuideSections) -> lists:member(Target, GuideSections);
resolves({bare, Target}, report, ReportSections, _) -> lists:member(Target, ReportSections);
resolves({bare, Target}, guide, _, GuideSections) -> lists:member(Target, GuideSections).
