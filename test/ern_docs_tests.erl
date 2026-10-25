%% The documents held to what they name: every `§x.y`, appendix by its
%% letter, and `E.n` written in a live document or in the code names a
%% heading of the report, and `guide §x.y`, `the guide's §x.y` and the
%% guide's own bare `§x.y` a heading of the guide, docs/log.md
%% being history and not checked; the contents lists, the tour's blocks,
%% the paths the documents and the toolchain's comments name, the release's
%% pages, the third parties' licenses, the glossary, the fault causes, the
%% log's index, the runtime's tables and frames as its design note, §8.7 and
%% the map name them, why.md's claims and the README's, the reviews' counts
%% of their readers, the shell's modules and the loads are each current; and
%% the lists docs/development.md's *Lists in two places* names are kept by
%% hand.
-module(ern_docs_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_contents/0]).

-define(ROOT, "..").

%% The report's three files (report §0), the language's, the toolchain's
%% and the standard library's, which are one report.
-define(REPORT, ["report/language.md", "report/toolchain.md", "report/library.md"]).

%% The documents with a contents list, and the lines that bound it.
-define(CONTENTS, ?REPORT ++ ["guide/language.md"]).
-define(BEGIN, <<"<!-- contents -->">>).
-define(END, <<"<!-- /contents -->">>).

%% Each frame of the runtime's own (report §8.7) by its body's tag, with the
%% words the runtime's design note and §8.7's *What passes* name it by, a
%% `kill`'s backticks aside.
-define(FRAMES, [{adapted, "a message to an adapted address"}, {spawn, "a spawn"},
                 {answer, "its answer"}, {compute, "a compute"}, {find, "a find"},
                 {utilization, "a utilization"}, {telling, "a node's telling"},
                 {call_waits, "that a call waits"}, {call_over, "that it is over"},
                 {kill, "a kill of a process"}, {node_ends, "that a node ends"},
                 {reach_request, "the request for a reach"}, {reach, "the reach"},
                 {lacks, "the lacks"}, {code_frame, "a code frame"}]).

%% The code that reads a peer's frames: the gateway, which reads some
%% itself and hands the rest on, the worker for the peer, whose reader is
%% ern_peer:frame/2, and the exchange.
-define(FRAME_READERS, ["erl/cli/src/ern_gateway.erl", "erl/runtime/src/ern_peer.erl",
                        "erl/cli/src/ern_exchange.erl"]).

%% report §11, docs/development.md "Building": `make xref`
%% A regression test for the possessive, `the guide's §x.y`, read as a
%% bare `§x.y`, the report's, until 2026-10-13, and for `the deployment
%% guide's §x.y`, read as the language guide's until 2026-10-25; it does
%% not read a curly apostrophe, which no document writes before a `§`, nor
%% a citation whose words a line break parts.
citations_resolve_test() ->
    Guide = ern_repository:read("guide/language.md"),
    Sections = #{report => section_numbers(report()), guide => section_numbers(Guide),
                 deployment => section_numbers(ern_repository:read("guide/deployment.md"))},
    %% a review's findings, `findings.md` beside the plan while they are
    %% open, cite each document as their readers did, the guide's sections
    %% bare beside the report's, and the list goes when its plan item is done
    Live = (documents() -- ["docs/findings.md"])
        ++ examples() ++ stdlib() ++ shell() ++ tools() ++ toolchain(),
    Dangling =
        [{File, Citation} || File <- Live, Citation <- cites(ern_repository:read(File)),
                             not resolves(Citation, report, Sections)]
        %% a console of the guide quotes the toolchain, whose citations are
        %% the report's (report §11.5), held to it by docs/diagnostics.md
        ++ [{"guide/language.md", Citation}
            || Citation <- cites(without_consoles(Guide)),
               not resolves(Citation, guide, Sections)],
    ?assertEqual([], Dangling).

%% The document without its fenced console blocks.
without_consoles(Document) ->
    re:replace(Document, "```console\n.*?\n```", "", [global, dotall, {return, binary}]).

%% guide/language.md §7.3, report Appendix E.25: the guide shows parts of
%% src/stdlib/ordered_set.ern, its doc blocks left out, a restatement a teaching
%% document makes, and this holds each part equal to the module's lines, in
%% the module's order
ordered_set_shown_in_part_test() ->
    Guide = ern_repository:read("guide/language.md"),
    [_, Rest] = binary:split(Guide, <<"```ernest-fragment\n// src/stdlib/ordered_set.ern">>),
    [Block | _] = binary:split(Rest, <<"\n```">>),
    [_Named | Shown] = binary:split(Block, <<"\n">>, [global]),
    Source = ern_repository:read("src/stdlib/ordered_set.ern"),
    Code = [Line || Line <- binary:split(Source, <<"\n">>, [global]),
                    not lists:prefix("///", binary_to_list(Line))],
    Parts = parts(Shown),
    ?assert(length(Parts) > 1),
    ?assertEqual(ok, in_order(Parts, Code)).

%% Each part a run of the lines, after the one before it.
in_order([], _) ->
    ok;
in_order([Part | Parts], Lines) ->
    case Lines of
        [] -> {missing, Part};
        _ ->
            case lists:prefix(Part, Lines) of
                true -> in_order(Parts, lists:nthtail(length(Part), Lines));
                false -> in_order([Part | Parts], tl(Lines))
            end
    end.

%% The runs of lines between blank ones.
parts(Lines) ->
    case lists:dropwhile(fun(Line) -> Line =:= <<>> end, Lines) of
        [] ->
            [];
        Rest ->
            {Part, After} = lists:splitwith(fun(Line) -> Line =/= <<>> end, Rest),
            [Part | parts(After)]
    end.

%% tour/README.md, plan MVP 3.3, report §11.6: each `ernest` block of the
%% tour under a chapter's heading, `## 5. Per key`, is that chapter's
%% program as tour/5/ holds it, so that the tour shows what its tests run.
%% A block is one of the chapter's files, or the file with some of its
%% paragraphs left out, a paragraph being a run of lines between blank
%% ones: the block's paragraphs are the file's, each whole and byte for
%% byte, in the file's order, one blank line between two. A blank line of
%% the block so stands for the file's, or for the paragraphs left out
%% there, and no block shows part of a paragraph. The files are `ern
%% format`'s layout (report §11.6), which writes no two blank lines
%% together. A block that is not so, or stands under no chapter's heading,
%% is named by its chapter and its first line. A regression test, written
%% after the tour's blocks; it does not cover the console blocks, which
%% ern_tour_tests runs, nor which file the prose says a block shows.
tour_blocks_shown_test() ->
    Lines = binary:split(ern_repository:read("tour/README.md"), <<"\n">>, [global]),
    Blocks = tour_blocks(Lines, none),
    ?assertNotEqual([], Blocks),
    ?assertEqual([], [{Chapter, unicode:characters_to_list(hd(binary:split(Text, <<"\n">>)))}
                      || {Chapter, Text} <- Blocks, not shown(Chapter, Text)]).

%% The tour's `ernest` blocks, each with the number of the chapter whose
%% heading it stands under, or none, and its text.
tour_blocks([], _) ->
    [];
tour_blocks([<<"## ", Heading/binary>> | Rest], _) ->
    tour_blocks(Rest, chapter(Heading));
tour_blocks([<<"```", Info/binary>> | Rest], Chapter) ->
    {Code, [_ | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    Blocks = tour_blocks(After, Chapter),
    case Info of
        <<"ernest">> -> [{Chapter, iolist_to_binary(lists:join(<<"\n">>, Code))} | Blocks];
        _ -> Blocks
    end;
tour_blocks([_ | Rest], Chapter) ->
    tour_blocks(Rest, Chapter).

fence(<<"```", _/binary>>) -> true;
fence(_) -> false.

%% "5" for `## 5. Per key`, and none for a heading that is no chapter's.
chapter(Heading) ->
    case re:run(Heading, "^([0-9]+)\\. ", [{capture, all_but_first, list}]) of
        {match, [Number]} -> Number;
        nomatch -> none
    end.

%% Whether Text is one of the chapter's files, or such a file with some of
%% its paragraphs left out.
shown(none, _) ->
    false;
shown(Chapter, Text) ->
    lists:any(fun(File) ->
                  among(paragraphs(Text), paragraphs(string:chomp(ern_repository:read(File))))
              end, ern_repository:files(["tour/" ++ Chapter ++ "/*.ern"])).

paragraphs(Text) ->
    binary:split(Text, <<"\n\n">>, [global]).

%% Whether Shown are among Paragraphs, in their order.
among([], _) -> true;
among(_, []) -> false;
among([Paragraph | Shown], [Paragraph | Rest]) -> among(Shown, Rest);
among(Shown, [_ | Rest]) -> among(Shown, Rest).

%% README.md, tour/2/counter.ern: the README's counter, its one `ernest`
%% block, is the module the tour's chapter 2 spawns on a bare node, byte
%% for byte, so that the front page shows what the tour's test runs. A
%% regression test, written after the README's block; it does not cover the
%% README's console, the transcript of the spawn, which ern_tour_tests runs.
readme_counter_is_the_tours_test() ->
    Lines = binary:split(ern_repository:read("README.md"), <<"\n">>, [global]),
    {_, [_ | Rest]} = lists:splitwith(fun(Line) -> Line =/= <<"```ernest">> end, Lines),
    {Code, _} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    ?assertEqual(string:chomp(ern_repository:read("tour/2/counter.ern")),
                 iolist_to_binary(lists:join(<<"\n">>, Code))).

%% report/, guide/language.md, docs/development.md "Building": a document's
%% contents list is its top-level sections, its headings of level two, each
%% linked to its heading, which `make contents` writes
contents_test() ->
    [?assertEqual({File, contents(Document)}, {File, listed(Document)})
     || File <- ?CONTENTS, Document <- [ern_repository:read(File)]].

%% Rewrite the contents list of every document that has one.
-spec write_contents() -> ok.
write_contents() ->
    lists:foreach(fun(File) ->
                      Document = ern_repository:read(File),
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

%% docs/style.md, docs/development.md "The layout of the repository": a document that says
%% where things are names things that are there, from the repository's root
%% or, as src/shell/README.md does, from its own directory. The report and the
%% guide name paths a program might have, `net/http.ern`, the plan
%% paths not yet written, and the findings' lists the paths of the tree
%% their readers read, so every other document is checked. A regression
%% test for the paths a document writes from its own directory, which went
%% unchecked once src/shell/ and docs/proposals/ left the top of the
%% repository on 2026-10-15
document_paths_test() ->
    Missing = [{File, Path} || File <- described(), Path <- paths(File),
                               not exists(Path),
                               not exists(filename:join(filename:dirname(File), Path))],
    ?assertEqual([], Missing).

%% docs/style.md "Every language", docs/development.md "The layout of the
%% repository": a path under docs/ or test/ that a comment of the
%% toolchain's code names, a whole line's comment of its Erlang, its C or
%% its Makefiles, is there, but a build's product under test/build/, which a
%% run writes, and a path with a wildcard or a metavariable. A regression
%% test for the comments that cited documents a step had removed, a
%% proposal's outline and a review's findings among them, which no test
%% read (the full review of 2026-10-24); it does not read a comment that
%% follows code on its line, nor a path written from another directory.
comment_paths_test() ->
    Missing = [{File, Path} || File <- toolchain(), Path <- comment_paths(File),
                               not exists(Path)],
    ?assertEqual([], Missing).

%% The paths under docs/ and test/ that a file's whole-line comments name,
%% each without the punctuation that ends its sentence or the slash that
%% ends a directory.
comment_paths(File) ->
    Lines = binary:split(ern_repository:read(File), <<"\n">>, [global]),
    [Path || Line <- Lines, re:run(Line, "^\\s*(%|#|//|/\\*|\\*)") =/= nomatch,
             [Found] <- matches(Line, "(?:^|[\\s(`\"',])((?:docs|test)/[^\\s`\"'(),;:]*)"),
             Path <- [string:trim(string:trim(Found, trailing, "."), trailing, "/")],
             Path =/= "docs", Path =/= "test",
             not lists:prefix("test/build/", Path ++ "/"),
             string:find(Path, "*") =:= nomatch, string:find(Path, "<") =:= nomatch,
             string:find(Path, "$") =:= nomatch].

%% README.md, guide/why.md, docs/development.md "The layout of the
%% repository": the claims the README lists are the ones why.md lists under
%% its opening and argues each under a heading of its own in *The claims, in
%% code*, in one order and one wording, each of the README's linked to its
%% heading, and both documents count them in words. A regression test:
%% docs/development.md said a test held the two lists equal, and none did;
%% it does not read how many of the claims show a program.
claims_test() ->
    Readme = ern_repository:read("README.md"),
    Why = ern_repository:read("guide/why.md"),
    Lead = <<"What Ernest adds is where the parts meet">>,
    Entry = "^- \\*\\*\\[(.+?)\\]\\(guide/why\\.md#([^)]+)\\)",
    Linked = [{Title, Anchor}
              || [Title, Anchor] <- line_matches(list_after(Readme, Lead), Entry)],
    Listed = [Title || [Title] <- line_matches(list_after(Why, Lead), "^- \\*\\*(.+?)\\.\\*\\*")],
    [_, AfterClaims] = binary:split(Why, <<"\n## The claims, in code\n">>),
    [Claims | _] = binary:split(AfterClaims, <<"\n## ">>),
    Argued = [binary_to_list(Text) || {3, Text} <- heads(Claims)],
    Anchors = [{binary_to_list(Text), binary_to_list(Anchor)}
               || {3, Text, Anchor} <- anchored(heads(Why))],
    ?assert(length(Argued) > 3),
    ?assertEqual(Argued, Listed),
    ?assertEqual(Argued, [Title || {Title, _} <- Linked]),
    ?assertEqual([], Linked -- Anchors),
    Count = number_word(length(Argued)),
    ?assertEqual([{"README.md", Count}, {"guide/why.md", Count}],
                 [{File, string:lowercase(Word)}
                  || {File, Text} <- [{"README.md", Readme}, {"guide/why.md", Why}],
                     [[Word] | _] <- [matches(Text, "\\b([A-Za-z-]+) claims\\b")]]).

%% The list that follows the line holding Lead, after the blank line under
%% it, up to the blank line that ends it.
list_after(Document, Lead) ->
    [_, Rest] = binary:split(Document, Lead),
    [_, List] = binary:split(Rest, <<"\n\n">>),
    hd(binary:split(List, <<"\n\n">>)).

%% Every match of a pattern at the start of a line of a text.
line_matches(Text, Pattern) ->
    lists:append([matches(Line, Pattern) || Line <- binary:split(Text, <<"\n">>, [global])]).

%% docs/full_review.md, docs/principles_review.md, docs/release_review.md:
%% each review counts its readers as its *The readers* lists them, a reader
%% being an item named by its letter, and its sessions as their parts, a
%% reader read in parts being a session each; and the readers the release
%% review names are the full review's. A regression test: the full review
%% counted twelve readers and nineteen sessions where it listed fifteen in
%% twenty-two parts (the full review of 2026-10-24).
readers_counted_test() ->
    Reviews = [ern_repository:read(File)
               || File <- ["docs/full_review.md", "docs/principles_review.md"]],
    ?assertEqual([], [{Readers, Sessions}
                      || Review <- Reviews, {Letters, Parts} <- [readers(Review)],
                         Readers <- [number_word(length(Letters))],
                         Sessions <- [number_word(lists:sum(Parts))],
                         re:run(Review, ["\\b", Readers, " readers\\b"], [caseless]) =:= nomatch
                             orelse re:run(Review, ["\\b", Sessions, " sessions\\b"], [caseless])
                                    =:= nomatch]),
    {Full, _} = readers(hd(Reviews)),
    Release = ern_repository:read("docs/release_review.md"),
    [_, Step] = binary:split(Release, <<"**The readers**">>),
    [Named | _] = binary:split(Step, <<"**The findings:**">>),
    ?assertEqual([], [Letter || [Letter] <- matches(Named, "(?<![\\w*])([A-Z])(?=, | and | as )"),
                                not lists:member(Letter, Full)]).

%% A review's readers, each by its letter, and the parts each is read in.
readers(Review) ->
    [_, Section] = binary:split(Review, <<"\n## The readers\n">>),
    [Body | _] = binary:split(Section, <<"\n## ">>),
    [_ | Items] = re:split(Body, "\n(?=- \\*\\*[A-Z], )", [{return, binary}]),
    lists:unzip([{Letter, reader_parts(Item)}
                 || Item <- Items, [[Letter] | _] <- [matches(Item, "^- \\*\\*([A-Z]), ")]]).

%% The parts a reader's item says it is read in, one where it says none.
reader_parts(Item) ->
    case matches(Item, "\\bin ([a-z]+) parts\\b") of
        [[Word] | _] -> length(lists:takewhile(fun(N) -> number_word(N) =/= Word end,
                                               lists:seq(1, 29))) + 1;
        [] -> 1
    end.

%% A count as the documents write it, "six", "twenty-two".
number_word(Count) when Count =< 20 ->
    lists:nth(Count, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                      "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                      "seventeen", "eighteen", "nineteen", "twenty"]);
number_word(Count) when Count < 30 ->
    "twenty-" ++ number_word(Count - 20).

%% docs/architecture.md, report §8.6, §8.7: the map's table of the tables
%% names each table `ern_rt:tables/0` makes, `ern_rt` its owner, and no
%% other as `ern_rt`'s, with their count in words; and its row of
%% `ern_launch` names every row the runtime writes there, `#launch{}` and
%% each tuple by its key. A regression test, written after the map had left
%% out the launch's own row; it does not read another table's rows.
architecture_tables_test() ->
    [_, Section] = binary:split(ern_repository:read("docs/architecture.md"),
                                <<"\n### The tables\n">>),
    [Body | _] = binary:split(Section, <<"\n### ">>),
    Rows = [{list_to_atom(Table), Row}
            || Row <- binary:split(Body, <<"\n">>, [global]),
               [[Table, "ern_rt"]] <- [matches(Row, "^\\| `(ern_[a-z_]+)` \\| `([a-z_]+)`")]],
    ?assertEqual(lists:sort(ern_rt:tables()), lists:sort([Table || {Table, _} <- Rows])),
    ?assertNotEqual(nomatch, string:find(Body, ["`ern_rt`'s ", number_word(length(ern_rt:tables())),
                                                " (`tables/0`)"])),
    Source = ern_repository:read("erl/runtime/src/ern_rt.erl"),
    ?assertNotEqual(nomatch, binary:match(Source, <<"ets:insert(?LAUNCH, #launch{">>)),
    Written = "ets:insert(?:_new)?\\(\\?LAUNCH, \\{([a-z_]+)",
    Keys = lists:usort([Key || [Key] <- matches(Source, Written)]),
    ?assert(length(Keys) > 3),
    Launch = proplists:get_value(ern_launch, Rows),
    ?assertEqual([], [Shown || Shown <- ["`#launch{}`" | ["`{" ++ Key || Key <- Keys]],
                               string:find(Launch, Shown) =:= nomatch]).

%% src/shell/README.md, report §4.2, §11.1: the README's table of the
%% shell's modules names each module of the shell, `shell.ern` and those
%% under `shell/`, by the name its path gives it beside a link to its file,
%% and the count of those under `shell/` in words. A regression test,
%% written after the table; it does not read what a row says its module is.
shell_modules_test() ->
    Readme = ern_repository:read("src/shell/README.md"),
    Named = "\\| `(Shell[A-Za-z.]*)` \\| \\[`([a-z_/]+\\.ern)`\\]\\(([a-z_/]+\\.ern)\\)",
    Rows = matches(Readme, Named),
    Files = ern_repository:files(["src/shell/*.ern", "src/shell/shell/*.ern"]),
    ?assertEqual(lists:sort(Files), lists:sort(["src/shell/" ++ Link || [_, _, Link] <- Rows])),
    ?assertEqual([], [Row || [Module, Shown, Link] = Row <- Rows,
                             Shown =/= Link orelse Module =/= module_named(Link)]),
    ?assertNotEqual(nomatch, string:find(Readme, [number_word(length(Files) - 1),
                                                  " modules under"])).

%% The module a path under a source root names (report §4.2):
%% `shell/kv_parser.ern` is `Shell.KvParser`.
module_named(Path) ->
    ern_namespace:text(ern_namespace:namespace(string:lexemes(filename:rootname(Path), "/"))).

%% docs/memory.md, test/Makefile: the loads the document's table lists are
%% the programs under test/fixtures/load/, which `LOADS` runs, and the
%% shell's, which the Makefile runs by name. A regression test, written
%% after the table; it does not read what a row says its load does.
loads_listed_test() ->
    [_, Section] = binary:split(ern_repository:read("docs/memory.md"), <<"\n## The loads\n">>),
    [Body | _] = binary:split(Section, <<"\n## ">>),
    Listed = [Load || [Load] <- line_matches(Body, "^\\| `([a-z_]+)` \\|")],
    Makefile = ern_repository:read("test/Makefile"),
    {match, [Loads]} = re:run(Makefile, "^LOADS = (.*)$",
                              [multiline, {capture, all_but_first, list}]),
    Programs = [filename:basename(File, ".ern")
                || File <- ern_repository:files(["test/fixtures/load/*.ern"])],
    ?assert(length(Programs) > 3),
    ?assertEqual(lists:sort(Programs), lists:sort(string:lexemes(Loads, " "))),
    ?assertNotEqual(nomatch, binary:match(Makefile, <<"ern_load:main([\"shell\"])">>)),
    ?assertEqual(lists:sort(["shell" | Programs]), lists:sort(Listed)).

%% report §11.2, docs/release_review.md: a shell's start line a tracked
%% document shows, `Ernest 0.5.0. :help for the commands, :quit to leave.`,
%% names the release VERSION holds, in every document but the log, which is
%% history, and a proposal, so that a release that forgets one is told. The
%% guide's and the catalog's sessions are held to it as they run
%% (ern_guide_tests), and the README's by ern_tour_tests; the tour's two
%% were held by nothing. A regression test, written after the tour
start_lines_test() ->
    Version = string:trim(ern_repository:read("VERSION")),
    Expected = <<"Ernest ", Version/binary, ". :help for the commands, :quit to leave.">>,
    Files = [File || File <- string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files '*.md'"), "\n"),
                     File =/= "docs/log.md", not lists:prefix("docs/proposals/", File)],
    Found = [{File, Line} || File <- Files,
                             Line <- binary:split(ern_repository:read(File), <<"\n">>, [global]),
                             binary:match(Line, <<"Ernest ">>) =:= {0, 7},
                             binary:match(Line, <<". :help for the commands">>) =/= nomatch],
    ?assert(length(lists:usort([File || {File, _} <- Found])) >= 3),
    ?assertEqual([], [Each || {_, Line} = Each <- Found, Line =/= Expected]).

%% docs/release_review.md, step 5: docs/man/ holds the pages `make man`
%% writes from main, so the release that changes VERSION writes them again;
%% a page names the version text of the ern that wrote it on its last line,
%% the repository's build's, which marks it as no release (report §11.4,
%% ern_release), docs/man/README.md the last release, and every page and
%% index but docs/man/README.md is linked from one index, a directory's
%% README.md
pages_test() ->
    Version = string:trim(ern_repository:read("VERSION")),
    Files = ern_repository:files(["docs/man/**/*.md"]),
    Indexes = [File || File <- Files, filename:basename(File) =:= "README.md"],
    Pages = Files -- Indexes,
    ?assert(length(Pages) > 25),
    Release = <<"the last release then being Ernest ", Version/binary, ";">>,
    ?assertNotEqual(nomatch, binary:match(ern_repository:read("docs/man/README.md"), Release)),
    Written = iolist_to_binary(["Generated by ern ", ern_release:version_text(), " from "]),
    ?assertEqual([], [Page || Page <- Pages,
                              binary:match(ern_repository:read(Page), Written) =:= nomatch]),
    Linked = [filename:join(filename:dirname(Index), Link)
              || Index <- Indexes, Link <- page_links(ern_repository:read(Index))],
    ?assertEqual(lists:sort(Files -- ["docs/man/README.md"]), lists:sort(Linked)).

%% An index's links to pages within docs/man/.
page_links(IndexText) ->
    {match, Links} = re:run(IndexText, "\\]\\(([^)]+\\.md)\\)",
                            [global, {capture, all_but_first, list}]),
    [Link || [Link] <- Links, not lists:prefix("../", Link)].

%% Every document the repository tracks, the guide aside, whose citations
%% are its own sections, and the log, whose entries say what was; docs/man/'s
%% pages are what `ern doc` wrote of sources these tests read. A
%% regression: the lists were written out, and left out five documents
%% and four directories
documents() ->
    Tracked = string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files '*.md'"), "\n"),
    Found = [File || File <- Tracked,
                     not lists:member(File, ["guide/language.md", "docs/log.md"]),
                     not lists:prefix("docs/man/", File)],
    ?assert(length(Found) > 15),
    Found.

%% The documents that describe the repository as it is.
described() ->
    documents() -- (?REPORT ++ ["docs/plan.md", "docs/findings.md"]).

%% A backticked path a document writes under one of the repository's own
%% directories, or under a directory beside the document, as
%% src/shell/README.md writes `shell/editor.ern`. A metavariable is written
%% `<name>`, as docs/style.md writes `ern_<thing>`, and a wildcard stands for
%% a set, so neither names one file.
paths(File) ->
    Tops = ["erl/", "docs/", "test/", "bin/", "src/", "examples/", "build/", "tools/",
            "editors/", "assets/"],
    Beside = [Name ++ "/" || Name <- subdirectories(filename:dirname(File))],
    Pieces = binary:split(ern_repository:read(File), <<"`">>, [global]),
    [binary_to_list(Piece) || {Index, Piece} <- lists:zip(lists:seq(1, length(Pieces)), Pieces),
                              Index rem 2 =:= 0,
                              lists:any(fun(Top) -> lists:prefix(Top, binary_to_list(Piece)) end,
                                        Tops ++ Beside),
                              binary:match(Piece, [<<"*">>, <<"<">>]) =:= nomatch,
                              binary:last(Piece) =/= $/].

%% The directories in a directory of the repository, by their names.
subdirectories(Dir) ->
    {ok, Names} = file:list_dir(filename:join(?ROOT, Dir)),
    [Name || Name <- Names, filelib:is_dir(filename:join([?ROOT, Dir, Name]))].

exists(Relative) ->
    filelib:is_file(filename:join(?ROOT, Relative)).

%% THIRD_PARTY_LICENSES: every tracked file that
%% carries an upstream author's copyright, and every file that holds a
%% table a tool generated, is an entry's path; and every entry names a
%% file that is there, and its license
third_party_test() ->
    Licenses = ern_repository:read("THIRD_PARTY_LICENSES"),
    Entries = [Entry || Entry <- binary:split(Licenses, <<"\n----">>, [global]),
                        binary:match(Entry, <<"  Path:">>) =/= nomatch],
    Listed = [path(Entry) || Entry <- Entries],
    Tracked = [File || File <- string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files"), "\n"),
                       not lists:member(File, ["LICENSE", "THIRD_PARTY_LICENSES"])],
    Owed = [File || File <- Tracked, filelib:is_regular(filename:join(?ROOT, File)),
                    Text <- [ern_repository:read(File)], borrowed(Text) orelse generated(Text)],
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
    Language = ern_repository:read("report/language.md"),
    [_, Rest] = binary:split(Language, <<"## Appendix F. Glossary">>),
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
    Language = ern_repository:read("report/language.md"),
    [Before, Rest] = binary:split(Language, <<"### 7.4 Causes of faults">>),
    [Own, After] = binary:split(Rest, <<"\n## 8. Programs">>),
    [Chapters, _] = binary:split(After, <<"\n## Appendix A">>),
    [Toolchain, _] = binary:split(ern_repository:read("report/toolchain.md"),
                                  <<"\n## Appendix C">>),
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

%% docs/design/runtime.md, report §8.6, §6.9, §8.7: the note's list of the
%% shared rows names each table the runtime makes for a launch,
%% `ern_rt:tables/0`, by its Erlang name beside what it holds, each row of
%% the list naming one at least, and no table the runtime does not make. A
%% regression test, written after the note; it does not read what a row
%% says its table holds, nor a table of the gateway's or the code's.
runtime_tables_test() ->
    Note = ern_repository:read("docs/design/runtime.md"),
    [_, Section] = binary:split(Note, <<"\n## What the runtime keeps, and where\n">>),
    [_, Shared] = binary:split(Section, <<"(`ern_rt:tables/0`):\n\n">>),
    [List | _] = binary:split(Shared, <<"\n\n">>),
    Rows = binary:split(List, <<"\n- ">>, [global]),
    Named = [[list_to_atom(Name) || [Name] <- matches(Row, "`(ern_[a-z_]+)`")] || Row <- Rows],
    ?assertEqual([], [Row || {Row, []} <- lists:zip(Rows, Named)]),
    ?assertEqual(lists:sort(ern_rt:tables()), lists:sort(lists:append(Named))).

%% docs/design/runtime.md, report §8.7: the frames the runtime's code reads
%% of a peer are fifteen, and the note's list and §8.7's *What passes*, each
%% of which says so, name every one in the words ?FRAMES gives it. A
%% regression test, written after the note; a frame a list adds in words of
%% its own is found only by the count the list states.
runtime_frames_test() ->
    Read = lists:usort([Tag || File <- ?FRAME_READERS, Tag <- frames_read(File)]),
    ?assertEqual(lists:sort([Tag || {Tag, _} <- ?FRAMES]), Read),
    ?assertEqual(15, length(Read)),
    ?assertEqual([], [{File, Tag} || File <- ["docs/design/runtime.md", "report/language.md"],
                                     Sentence <- [frames_sentence(File)],
                                     {Tag, Words} <- ?FRAMES,
                                     binary:match(Sentence, list_to_binary(Words)) =:= nomatch]).

%% The tag of each frame a file's code reads: of a receive's pattern that
%% names it, `{ern_frame, From, {call_waits, Callee, Reply}}`, and of a
%% `frame` function's clause, its second argument.
frames_read(File) ->
    {ok, Forms} = epp_dodger:quick_parse_file(filename:join(?ROOT, File)),
    received_frames(Forms)
        ++ [Tag || {function, _, frame, _, Clauses} <- Forms,
                   {clause, _, [_, Body | _], _, _} <- Clauses, Tag <- body_tag(Body)].

%% Each receive's frames in a module's forms, nested receives among them.
received_frames({'receive', _, Clauses}) ->
    pattern_tags(Clauses) ++ received_frames(Clauses);
received_frames({'receive', _, Clauses, Timeout, After}) ->
    pattern_tags(Clauses) ++ received_frames([Clauses, Timeout, After]);
received_frames(Form) when is_tuple(Form) ->
    received_frames(tuple_to_list(Form));
received_frames(Forms) when is_list(Forms) ->
    lists:append([received_frames(Form) || Form <- Forms]);
received_frames(_) ->
    [].

pattern_tags(Clauses) ->
    [Tag || {clause, _, [Pattern], _, _} <- Clauses, Tag <- frame_tag(Pattern)].

%% A frame's tag where a pattern names it, `{ern_frame, From, Body} = Frame`
%% among them.
frame_tag({match, _, Left, Right}) -> frame_tag(Left) ++ frame_tag(Right);
frame_tag({tuple, _, [{atom, _, ern_frame}, _, Body]}) -> body_tag(Body);
frame_tag(_) -> [].

body_tag({atom, _, Tag}) -> [Tag];
body_tag({tuple, _, [{atom, _, Tag} | _]}) -> [Tag];
body_tag(_) -> [].

%% The sentence of a document that lists the frames, its backticks dropped.
frames_sentence(File) ->
    [_, Rest] = binary:split(ern_repository:read(File), <<"frames are the runtime's own">>),
    [Sentence | _] = binary:split(Rest, <<". ">>),
    binary:replace(Sentence, <<"`">>, <<>>, [global]).

%% docs/log.md: its index names every section by its title, the
%% standing ones and the dated entries. A regression test, written after the
%% index had missed thirty-eight entries (the log's *A Port Lost While It
%% Starts*); it does not check an anchor, which the reader's renderer makes.
log_index_names_every_section_test() ->
    Log = ern_repository:read("docs/log.md"),
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

%% The report, its three files read as one text.
report() ->
    iolist_to_binary([ern_repository:read(File) || File <- ?REPORT]).

%% The examples and the programs kept for the tests, whose comments cite
%% the report.
examples() ->
    ern_repository:files(["examples/**/*.ern", "test/fixtures/programs/**/*.ern"]).

%% The shell's Ernest source, whose comments cite the report as the
%% standard library's do.
shell() ->
    ern_repository:files(["src/shell/**/*.ern"]).

%% The programs of the build written in Ernest, whose comments cite the
%% report too.
tools() ->
    ern_repository:files(["tools/*.ern"]).

%% The toolchain's own code, whose comments cite the report as its rules
%% ask: the Erlang sources, includes and tests, the helper in C, the tests
%% under test/ and the Makefiles.
toolchain() ->
    ern_repository:files(["erl/*/src/*.erl", "erl/*/include/*.hrl", "erl/*/test/*.erl",
                          "erl/runtime/c_src/*.c", "test/*.erl", "Makefile", "test/Makefile",
                          "erl/app.mk", "erl/*/src/Makefile", "tools/release/Makefile"]).

stdlib() ->
    ern_repository:files(["src/stdlib/*.ern", "src/libs/*/*.ern"]).

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
%% deployment or bare, a `§x.y` after report, guide or deployment guide,
%% or after the report's, the guide's or the deployment guide's, being
%% that document's, and the bare ones resolved by the document's own
%% convention.
cites(Document) ->
    Cited = "([Rr]eport|[Dd]eployment guide|[Gg]uide)?(?:'s)?,? ?§([0-9]+(?:\\.[0-9]+)?)",
    SectionCites = [{kind(Word), Number} || [Word, Number] <- matches(Document, Cited)],
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
kind([$D | _]) -> deployment;
kind([$d | _]) -> deployment;
kind(Word) -> list_to_atom(string:lowercase(Word)).

%% Whether a citation names a section of the document it names, a bare
%% one of the document Own, as the document citing it reads a bare `§`.
resolves({bare, Target}, Own, Sections) -> lists:member(Target, maps:get(Own, Sections));
resolves({Kind, Target}, _, Sections) -> lists:member(Target, maps:get(Kind, Sections)).
