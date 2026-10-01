%% The documents' citations resolve: every `§x.y`, `Appendix X`, and `E.n`
%% written in a live document names a heading of the report, and the
%% guide's own bare `§x.y` names a heading of the guide. docs/decisions.md
%% is history and is not checked.
-module(ern_docs_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_contents/0]).

-define(ROOT, "..").

%% The documents with a contents list, and the lines that bound it.
-define(CONTENTS, ["ernest_report.md", "ernest_guide.md"]).
-define(BEGIN, <<"<!-- contents -->">>).
-define(END, <<"<!-- /contents -->">>).

%% report §11, docs/development.md "Building": `make xref`
citations_resolve_test() ->
    Report = read("ernest_report.md"),
    Guide = read("ernest_guide.md"),
    ReportHeads = headings(Report),
    GuideHeads = headings(Guide),
    %% docs/findings.md's lines cite each document as its reader did, the
    %% guide's sections bare beside the report's, and the list goes when a
    %% review's findings are done
    Live = (documents() -- ["docs/findings.md"]) ++ examples() ++ stdlib() ++ shell() ++ tools(),
    Dangling =
        [{F, C} || F <- Live, C <- cites(read(F)), not resolves(C, report, ReportHeads, GuideHeads)]
        ++ [{"ernest_guide.md", C} || C <- cites(Guide),
                                      not resolves(C, guide, ReportHeads, GuideHeads)],
    ?assertEqual([], Dangling).

%% ernest_report.md, ernest_guide.md, docs/development.md "Building": a document's
%% contents list is its top-level sections, its headings of level two, each
%% linked to its heading, which `make contents` writes
contents_test() ->
    [?assertEqual({F, contents(Bin)}, {F, listed(Bin)}) || F <- ?CONTENTS, Bin <- [read(F)]].

%% Rewrite the contents list of every document that has one.
-spec write_contents() -> ok.
write_contents() ->
    lists:foreach(fun(F) ->
                      Bin = read(F),
                      [Before, Rest] = binary:split(Bin, ?BEGIN),
                      [_, After] = binary:split(Rest, ?END),
                      ok = file:write_file(filename:join(?ROOT, F),
                                           [Before, ?BEGIN, contents(Bin), ?END, After])
                  end, ?CONTENTS).

listed(Bin) ->
    [_, Rest] = binary:split(Bin, ?BEGIN),
    [List, _] = binary:split(Rest, ?END),
    List.

%% The list: a line per heading of level two, linked by the anchor a
%% renderer gives it; the anchors are counted over every heading, since a
%% renderer numbers a repeated one whatever its level.
contents(Bin) ->
    Entries = [["- [", Text, "](#", Anchor, ")\n"]
               || {2, Text, Anchor} <- anchored(heads(Bin))],
    iolist_to_binary(["\n", Entries]).

%% Every heading outside a fenced block, with its level and its text.
heads(Bin) ->
    heads(binary:split(Bin, <<"\n">>, [global]), false, []).

heads([], _, Acc) ->
    lists:reverse(Acc);
heads([<<"```", _/binary>> | Rest], Fenced, Acc) ->
    heads(Rest, not Fenced, Acc);
heads([L | Rest], false, Acc) ->
    case re:run(L, "^(#{1,6}) +(.*?) *$", [{capture, all_but_first, binary}, unicode]) of
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
              N = maps:get(Base, Seen, 0),
              Anchor = case N of
                           0 -> Base;
                           _ -> <<Base/binary, "-", (integer_to_binary(N))/binary>>
                       end,
              {{Level, Text, Anchor}, Seen#{Base => N + 1}}
          end, #{}, Heads),
    Anchored.

%% README.md, guide §0, CLAUDE.md *Who owns each fact*: the front
%% page's list of what Ernest adds is the guide's, word for word, so that the
%% two cannot drift apart
what_ernest_adds_test() ->
    ?assertEqual(adds(read("ernest_guide.md")), adds(read("README.md"))).

adds(Bin) ->
    [_, Rest] = binary:split(Bin, <<"What Ernest adds is where the parts meet:\n\n">>),
    [List | _] = binary:split(Rest, <<"\n\n">>),
    List.

%% docs/style.md, docs/development.md "The layout of the repository": a document that says
%% where things are names things that are there, from the repository's root
%% or, as shell/README.md does, from its own directory. The report and the
%% guide name paths a program might have, `net/http.ern`, the plan
%% paths not yet written, and the findings' lists the paths of the tree
%% their readers read, so every other document is checked.
document_paths_test() ->
    Missing = [{F, P} || F <- described(), P <- paths(read(F)),
                         not exists(P), not exists(filename:join(filename:dirname(F), P))],
    ?assertEqual([], Missing).

%% docs/release_review.md, step 5: man/ holds the pages of the release
%% VERSION names, which `make pages` writes, so the release that changes
%% VERSION writes them again; a page names the version of the ern that
%% wrote it on its last line, man/index.md the release in its title, and
%% every page and index but man/index.md is linked from one index
release_pages_test() ->
    Version = string:trim(read("VERSION")),
    Files = filelib:wildcard("man/**/*.md", ?ROOT),
    Indexes = [F || F <- Files, filename:basename(F) =:= "index.md"],
    Pages = Files -- Indexes,
    ?assert(length(Pages) > 25),
    ?assertMatch(<<"# Ernest ", Version:(byte_size(Version))/binary, "\n", _/binary>>,
                 read("man/index.md")),
    Written = <<"Generated by ern ", Version/binary, " from ">>,
    ?assertEqual([], [P || P <- Pages, binary:match(read(P), Written) =:= nomatch]),
    Linked = [filename:join(filename:dirname(I), L) || I <- Indexes, L <- page_links(read(I))],
    ?assertEqual(lists:sort(Files -- ["man/index.md"]), lists:sort(Linked)).

%% An index's links to pages within man/.
page_links(Index) ->
    {match, Links} = re:run(Index, "\\]\\(([^)]+\\.md)\\)",
                            [global, {capture, all_but_first, list}]),
    [L || [L] <- Links, not lists:prefix("../", L)].

%% Every document the repository tracks, the guide aside, whose citations
%% are its own sections, and the log, whose entries say what was; man/'s
%% pages are what `ern doc` wrote of sources these tests read. A
%% regression: the lists were written out, and left out five documents
%% and four directories (findings.md's D4)
documents() ->
    Tracked = string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files '*.md'"), "\n"),
    Found = [F || F <- Tracked, not lists:member(F, ["ernest_guide.md", "docs/decisions.md"]),
                  not lists:prefix("man/", F)],
    ?assert(length(Found) > 15),
    Found.

%% The documents that describe the repository as it is.
described() ->
    documents() -- ["ernest_report.md", "docs/implementation_plan.md"].

%% A backticked path under one of the repository's own directories. A
%% metavariable is written `<name>`, as docs/style.md writes `ern_<thing>`,
%% and a wildcard stands for a set, so neither names one file.
paths(Bin) ->
    Tops = ["erl/", "docs/", "test/", "bin/", "stdlib/", "examples/", "build/", "shell/",
            "libs/", "tools/", "emacs/"],
    Quoted = [B || B <- binary:split(Bin, <<"`">>, [global])],
    [binary_to_list(P) || {I, P} <- lists:zip(lists:seq(1, length(Quoted)), Quoted),
                          I rem 2 =:= 0,
                          lists:any(fun(T) -> lists:prefix(T, binary_to_list(P)) end, Tops),
                          binary:match(P, [<<"*">>, <<"<">>]) =:= nomatch,
                          binary:last(P) =/= $/].

exists(Rel) ->
    filelib:is_file(filename:join(?ROOT, Rel)).

%% THIRD_PARTY_LICENSES: every tracked file that
%% carries an upstream author's copyright, and every file that holds a
%% table a tool generated, is an entry's path; and every entry names a
%% file that is there, and its licence
third_party_test() ->
    Entries = [E || E <- binary:split(read("THIRD_PARTY_LICENSES"), <<"\n----">>, [global]),
                    binary:match(E, <<"  Path:">>) =/= nomatch],
    Listed = [path(E) || E <- Entries],
    Tracked = [F || F <- string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files"), "\n"),
                    not lists:member(F, ["LICENSE", "THIRD_PARTY_LICENSES"])],
    Owed = [F || F <- Tracked, filelib:is_regular(filename:join(?ROOT, F)),
                 borrowed(read(F)) orelse generated(read(F))],
    ?assert(length(Owed) >= 2),
    ?assertEqual([], Owed -- Listed),
    ?assertEqual([], [P || P <- Listed, not filelib:is_regular(filename:join(?ROOT, P))]),
    ?assertEqual([], [path(E) || E <- Entries, binary:match(E, <<"  License:">>) =:= nomatch]).

%% An entry's path, the first word after its `Path:`.
path(Entry) ->
    {match, [P]} = re:run(Entry, "^  Path: +([^ ,\n]+)",
                          [multiline, {capture, all_but_first, list}]),
    P.

%% report §7.4: a cause of a fault quoted in sections
%% 0 to 11 outside §7.4 is one §7.4 lists, since §7.4 holds the causes
%% (§7.3); a library function's own section holds its faults (Appendix E.0
%% shape rule 4). In §7.4's texts `...`, `m:f/n` and a placeholder of one
%% letter stand for any text.
fault_causes_test() ->
    Report = read("ernest_report.md"),
    [Before, Rest] = binary:split(Report, <<"### 7.4 Causes of faults">>),
    [Own, After] = binary:split(Rest, <<"\n## 8. Programs">>),
    [Body, _] = binary:split(After, <<"\n## Appendix A">>),
    Templates = [template(C) || C <- causes(Own)],
    ?assert(length(Templates) > 20),
    ?assertEqual([], [C || C <- causes(Before) ++ causes(Body),
                           not lists:any(fun(T) -> re:run(C, T) =/= nomatch end, Templates)]).

causes(Bin) ->
    case re:run(Bin, "Fault\\(\"([^\"]*)\"\\)", [global, {capture, all_but_first, binary}]) of
        {match, Found} -> [C || [C] <- Found];
        nomatch -> []
    end.

%% A cause as a pattern: its text, with `...`, `m:f/n` and a word of one
%% letter matching any text.
template(Cause) ->
    Words = [case W of
                 <<"...">> -> <<".*">>;
                 <<"m:f/n">> -> <<".+">>;
                 <<_>> when W =/= <<"a">> -> <<".+">>;
                 _ -> re:replace(W, "[.^$*+?()\\[\\]{}|\\\\]", "\\\\&",
                                 [global, {return, binary}])
             end || W <- binary:split(Cause, <<" ">>, [global])],
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

read(Rel) ->
    {ok, Bin} = file:read_file(filename:join(?ROOT, Rel)),
    Bin.

%% A name that begins with a dot is no module (report §11.1's path shape),
%% and an editor's lock file, `.#main.ern`, is one that may not be readable.
examples() ->
    [filename:join("examples", F)
     || F <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "examples")),
        not editor_file(F)].

%% The shell's Ernest source, whose comments cite the report as the
%% standard library's do.
shell() ->
    [filename:join("shell", F)
     || F <- filelib:wildcard("**/*.ern", filename:join(?ROOT, "shell")),
        not editor_file(F)].

%% The programs of the build written in Ernest, whose comments cite the
%% report too.
tools() ->
    [filename:join("tools", F)
     || F <- filelib:wildcard("*.ern", filename:join(?ROOT, "tools")), not editor_file(F)].

stdlib() ->
    [filename:join("stdlib", F)
     || F <- filelib:wildcard("*.ern", filename:join(?ROOT, "stdlib")), not editor_file(F)]
    ++ [filename:join("libs", F)
        || F <- filelib:wildcard("*/*.ern", filename:join(?ROOT, "libs")), not editor_file(F)].

%% An editor's lock file, `.#editor.ern`, a link to nothing while the file
%% is open, and its auto-save file, `#editor.ern#`: neither is a module.
editor_file(F) ->
    lists:member(hd(filename:basename(F)), ".#").

%% "3.9", "3", "Appendix A", "E.12" for the headings of a document.
headings(Bin) ->
    Lines = binary:split(Bin, <<"\n">>, [global]),
    lists:append([heading(L) || L <- Lines]).

heading(L) ->
    case re:run(L, "^#{1,3} (?:([0-9]+(?:\\.[0-9]+)?)\\.? |Appendix ([A-Z])(?:\\.([0-9]+))?\\.)",
                [{capture, all_but_first, list}]) of
        {match, [N]} -> [N];
        {match, [[], A]} -> ["Appendix " ++ A];
        {match, [[], A, E]} -> ["Appendix " ++ A, A ++ "." ++ E];
        nomatch -> []
    end.

%% Every citation in a document: {Kind, Target} with Kind report, guide,
%% or bare, the bare ones resolved by the document's own convention.
cites(Bin) ->
    Sec = case re:run(Bin, "([Rr]eport|[Gg]uide)?,? ?§([0-9]+(?:\\.[0-9]+)?)",
                      [global, unicode, {capture, all_but_first, list}]) of
              {match, Ms} -> [{kind(W), N} || [W, N] <- Ms];
              nomatch -> []
          end,
    App = case re:run(Bin, "Appendix ([A-Z])(?:\\.([0-9]+))?",
                      [global, {capture, all_but_first, list}]) of
              {match, As} -> lists:append([case A of [X] -> [{report, "Appendix " ++ X}];
                                                     [X, E] -> [{report, X ++ "." ++ E}]
                                           end || A <- As]);
              nomatch -> []
          end,
    E0 = case re:run(Bin, "\\bE\\.([0-9]+)\\b", [global, {capture, all_but_first, list}]) of
             {match, Es} -> [{report, "E." ++ E} || [E] <- Es];
             nomatch -> []
         end,
    lists:usort(Sec ++ App ++ E0).

kind([]) -> bare;
kind(W) -> list_to_atom(string:lowercase(W)).

resolves({report, T}, _, ReportHeads, _) -> lists:member(T, ReportHeads);
resolves({guide, T}, _, _, GuideHeads) -> lists:member(T, GuideHeads);
resolves({bare, T}, report, ReportHeads, _) -> lists:member(T, ReportHeads);
resolves({bare, T}, guide, _, GuideHeads) -> lists:member(T, GuideHeads).
