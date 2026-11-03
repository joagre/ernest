%% The site's generator, tools/site.ern (plan, MVP 4.2 items 2 and 5), run
%% over a tree of its own: the documents under fixtures/site/tree/, each
%% standing at the path of the document it plays, the guide, the tour, the
%% report, the library's pages, Why, the questions, the deployment guide,
%% the README, the release notes and the log, beside the site's files,
%% ../site/, and the logos, with fixtures/site/config.json as the server's
%% configuration.
%%
%% The pages it writes are held to the expected ones under fixtures/site/expected/,
%% their assets' digests aside, so that the look and the generation never
%% drift; the assets, the gathered icons, the qualified names' and the log's
%% links, the descriptions of the site's own pages, the refusals, the
%% build's check of its links and the templates' tokens are held each by a
%% test of its own, and the generator is run over the repository's own
%% documents, an export of HEAD. `make site-expected` writes the expected
%% pages again after a change to the look that is meant (write_expected/0).
%% Run from this directory by its Makefile, after `make`, which builds the
%% generator into ../build/tools. Every test here was written after the
%% generator, a regression test.
-module(ern_site_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_expected/0]).

-define(TREE, "fixtures/site/tree").
-define(CONFIG, "fixtures/site/config.json").
-define(EXPECTED, "fixtures/site/expected").
-define(SOURCE, "build/site/source").
-define(OUT, "build/site/out").
%% The release the pages name, and the revision their links to GitHub and
%% their dates name: a source's last commit at a commit stays as it is, and
%% this one, the generator's first stage, holds every source the pages name,
%% site/templates/ among them.
-define(VERSION, "9.9.9").
-define(TAG, "ebcc1ea855bc01ea87fc6f222d497dbf1b1633bd").
%% The root's files whose names hold a digest of their content
%% (docs/proposals/site/decisions.md *The generation*); the icons' file,
%% which the generator gathers, is named so too.
-define(DIGESTED, ["assets/css/site.css", "assets/js/site.js"]).
-define(ICONS, "../site/root/assets/img/icons").
-define(LOGOS, ["ernest-mark.svg", "ernest-avatar-64.png", "ernest-social-light.png"]).

generated_test_() ->
    {setup, fun generated/0, fun(_) -> ok end,
     [{"pages", fun pages/0}, {"assets", fun assets/0}, {"icons", fun icons/0},
      {"qualified", fun qualified/0}, {"logged", fun logged/0},
      {"described", fun described/0}, {"refused", {timeout, 30, fun refused/0}},
      {"unconfigured", {timeout, 30, fun unconfigured/0}},
      {"unlogged", {timeout, 30, fun unlogged/0}},
      {"dangling", {timeout, 30, fun dangling/0}},
      {"head", {timeout, 60, fun head/0}}]}.

%% plan MVP 4.2 item 2, docs/proposals/site/decisions.md *The root*,
%% *Anchors*, *The homepage*, *Every page*, *The other pages*, *Links*, *The
%% templates*, *The generation* and *The live shell*: every page the site
%% has, as the expected pages show them.
%%
%% The books' contents pages and
%% chapters, the guide's with its sections, the tour's with each chapter's
%% line; the report's three files whole, with their revisions, their
%% sections' margin lines and their contents page; each module's page with
%% its declarations anchored by name, its signatures and its examples, and
%% the library's contents pages; Why, the questions, Install, Releases and
%% the deployment guide, a heading anchored by its GitHub anchor or its
%% number, a GitHub anchor of a heading holding `§` or sharing its digits
%% with another's led to its number; the homepage, its claims and its
%% example; the shell's page, its numbers the configuration's; and the 404
%% page.
%%
%% Each with its citations made links, its links written for GitHub
%% led to the site's pages, its code colored by the toolchain's lexer, each
%% block's buttons as its document's tests give them, its sidebar, its
%% previous and next, and its footer naming its source with its date, all in
%% the readable form. It does not cover the browser's reading of a page,
%% which the mockup's look was checked by.
pages() ->
    Expected = files(?EXPECTED),
    ?assertEqual(["404.html", "deployment/index.html", "faq/index.html", "guide/0.html",
                  "guide/1.html", "guide/2.html", "guide/index.html", "index.html",
                  "install/index.html", "man/index.html", "man/libs/index.html",
                  "man/libs/markdown/index.html", "man/libs/markdown/markdown.html",
                  "man/stdlib/index.html", "man/stdlib/list.html", "man/stdlib/prelude.html",
                  "releases/index.html", "report/index.html", "report/language.html",
                  "report/library.html", "report/toolchain.html", "shell/index.html",
                  "tour/1.html", "tour/2.html", "tour/index.html", "why/index.html"], Expected),
    ?assertEqual(Expected, [File || File <- files(?OUT), filename:extension(File) =:= ".html"]),
    ?assertEqual([], [File || File <- Expected,
                              undigested(read(?EXPECTED, File)) =/= undigested(read(?OUT, File))]).

%% docs/proposals/site/decisions.md *The look* and *The generation*: the
%% root copied, laid out as served, the stylesheet, the script and the
%% icons' file each under a name holding the first eight hexadecimal digits
%% of its SHA-1 digest, and named so by every page; the vendored files and
%% the rest under their own names; and the three logos at their paths in
%% the repository's assets/.
assets() ->
    Root = files("../site/root"),
    Named = maps:from_list([{File, digested(read("../site/root", File), File)}
                            || File <- ?DIGESTED]),
    Icons = gathered(),
    ?assertEqual(lists:sort([maps:get(File, Named, File) || File <- Root]
                            ++ [Icons] ++ ["assets/" ++ Logo || Logo <- ?LOGOS]),
                 [File || File <- files(?OUT), filename:extension(File) =/= ".html"]),
    ?assertEqual([], [File || File <- Root,
                              read("../site/root", File)
                                  =/= read(?OUT, maps:get(File, Named, File))]),
    Page = read(?OUT, "guide/1.html"),
    ?assertEqual([], [Name || Name <- [Icons | maps:values(Named)],
                              binary:match(Page, list_to_binary("\"/" ++ Name)) =:= nomatch]).

%% docs/proposals/site/decisions.md *The templates*, site/templates/README.md:
%% the icons' file the generator gathers, a symbol for each icon of
%% site/root/assets/img/icons/, by its file's name and in their order, each
%% with its icon's viewBox and fill and its children as they are, and no
%% stroke of its own, which the stylesheet's .icon gives.
icons() ->
    Names = [filename:basename(File, ".svg") || File <- files(?ICONS),
                                                filename:extension(File) =:= ".svg"],
    Sprite = read(?OUT, gathered()),
    ?assertEqual([list_to_binary(Name) || Name <- Names],
                 [Name || [Name] <- matches(Sprite, "<symbol id=\"([^\"]+)\"")]),
    ?assertEqual(nomatch, binary:match(Sprite, <<"stroke">>)),
    ?assertEqual([], [Name || Name <- Names,
                              binary:match(Sprite, symbol(read(?ICONS, Name ++ ".svg"), Name))
                                  =:= nomatch]).

%% An icon's symbol as the sprite holds it, from the icon's file: its
%% viewBox and fill, and each child a level in.
symbol(Icon, Name) ->
    [[ViewBox]] = matches(Icon, "\n  viewBox=\"([^\"]+)\""),
    [[Fill]] = matches(Icon, "\n  fill=\"([^\"]+)\""),
    [_, Children] = binary:split(Icon, <<"\n>\n">>),
    Lines = [<<"  ", Line/binary>> || Line <- binary:split(Children, <<"\n">>, [global]),
                                      Line =/= <<>>, Line =/= <<"</svg>">>],
    iolist_to_binary(["\n  <symbol id=\"", Name, "\" viewBox=\"", ViewBox, "\" fill=\"", Fill,
                      "\">\n", [[Line, "\n"] || Line <- Lines], "  </symbol>\n"]).

%% docs/proposals/site/decisions.md *Links*: a qualified name in code or in
%% backticks links to its declaration in /man/ where a page of docs/man/
%% heads it, an operator among them, and on the declaration's own page to
%% its anchor alone; a bare name is text, and so is a name the library does
%% not declare, a code span that is more than a name, and a member of a type
%% the page's own code declares (report §4.2).
qualified() ->
    Guide = read(?OUT, "guide/1.html"),
    List = <<"<a href=\"/man/stdlib/list.html#List.">>,
    Parse = <<"<a href=\"/man/libs/markdown/markdown.html#Markdown.parse\">">>,
    [?assertMatch({_, _}, binary:match(Guide, Linked))
     || Linked <- [<<List/binary, "size\"><code>List.size</code></a>">>,
                   <<Parse/binary, "<code>Markdown.parse</code></a>">>,
                   <<List/binary, "&lt;&gt;\"><code>List.&lt;&gt;</code></a>">>,
                   <<List/binary, "size\"><span class=\"tok-type\">List</span>.size</a>(list)">>]],
    [?assertMatch({_, _}, binary:match(Guide, <<" <code>", Text/binary, "</code>">>))
     || Text <- [<<"spawn">>, <<"List.map">>, <<"List.size(list)">>]],
    ?assertMatch({_, _}, binary:match(Guide, <<"<span class=\"tok-type\">Markdown</span>.size">>)),
    ?assertMatch({_, _}, binary:match(read(?OUT, "guide/2.html"),
                                      <<" <code>Markdown.parse</code>">>)),
    ?assertMatch({_, _}, binary:match(read(?OUT, "man/stdlib/list.html"),
                                      <<"<a href=\"#List.size\"><code>List.size</code></a>">>)).

%% docs/proposals/site/decisions.md *Links*: a citation of the log, the
%% log's *Title*, links to its entry in the log on GitHub at the tag, by the
%% anchor the log's index gives it, and so does an entry the release notes
%% name by its title alone, as docs/release_review.md has them name it;
%% another emphasis of the notes is text.
logged() ->
    Log = "<a href=\"https://github.com/joagre/ernest/blob/" ++ ?TAG ++ "/docs/log.md#",
    Entry = list_to_binary(Log ++ "the-fixtures-entry-2026-11-03\"><em>The Fixture's Entry</em>"
                           "</a>"),
    ?assertMatch({_, _}, binary:match(read(?OUT, "guide/1.html"), <<"log's ", Entry/binary>>)),
    Releases = read(?OUT, "releases/index.html"),
    ?assertMatch({_, _}, binary:match(Releases, <<"; ", Entry/binary, ", ">>)),
    ?assertMatch({_, _}, binary:match(Releases, list_to_binary(
                                                  Log ++ "--at-the-prompt-2026-11-03\"><em><code>"
                                                  "&lt;-</code> at the Prompt</em></a>"))),
    ?assertMatch({_, _}, binary:match(Releases, <<" <em>Faults</em>;">>)),
    ?assertMatch({_, _}, binary:match(Releases, <<"the log's ", Entry/binary>>)).

%% docs/proposals/site/decisions.md *Links*: the site's own pages, the
%% homepage, the shell's and the 404 page, are each described by the first
%% sentence of their text, which the generator states for the two whose
%% text a template holds, home.html's heading and shell.html's opening.
described() ->
    ?assertEqual([], [Page || Page <- ["index.html", "shell/index.html", "404.html"],
                              not is_described(read(?OUT, Page))]).

is_described(Page) ->
    {match, [Description]} = re:run(Page, "<meta name=\"description\" content=\"([^\"]*)\">",
                                     [{capture, all_but_first, binary}]),
    [_, Main] = binary:split(Page, <<"<main">>),
    Text = re:replace(Main, "<[^>]*>", "", [global, {return, binary}]),
    binary:match(Text, string:trim(Description, trailing, ".")) =/= nomatch.

%% plan MVP 4.2 item 2: the generator writes the site into a directory of
%% its own, so that no page whose source is gone stays, and refuses one
%% that is there already.
refused() ->
    {Status, Output} = ern_integration_tests:sh(generate(?OUT, ?CONFIG)),
    ?assertEqual(1, Status),
    ?assertMatch({_, _}, binary:match(Output, <<"build/site/out is there already">>)).

%% docs/proposals/site/decisions.md *The templates*: the shell's page says
%% what the server enforces, so a configuration with no `shell`, a server
%% that serves none, is refused, and no site is written.
unconfigured() ->
    Config = "build/site/plain.json",
    ok = file:write_file(Config, <<"{\"listeners\": []}\n">>),
    {Status, Output} = ern_integration_tests:sh(generate("build/site/plain", Config)),
    ?assertEqual(1, Status),
    ?assertMatch({_, _}, binary:match(Output, <<"build/site/plain.json has no shell">>)).

%% docs/proposals/site/decisions.md *Links*: a citation of the log that
%% names no entry of the log's index, or a title two entries hold, is
%% refused, since its link would lead to neither.
unlogged() ->
    [begin
         Source = "build/site/unlogged",
         _ = file:del_dir_r(Source),
         _ = file:del_dir_r("build/site/unlogged-out"),
         [copied(filename:join(?SOURCE, File), filename:join(Source, File))
          || File <- files(?SOURCE)],
         appended(Source ++ "/guide/faq.md", ["\nThe reasons are the log's *", Title, "*.\n"]),
         {Status, Output} =
             ern_integration_tests:sh(generate(Source, "build/site/unlogged-out", ?CONFIG)),
         ?assertEqual(1, Status),
         ?assertMatch({_, _}, binary:match(Output, list_to_binary(
                                                     "guide/faq.md cites the log's *" ++ Title
                                                     ++ "*, " ++ Why)))
     end || {Title, Why} <- [{"No Such Entry", "which no entry is titled"},
                             {"Two of a Title", "a title several entries hold"}]].

%% plan MVP 4.2 item 5, docs/proposals/site/decisions.md *Links*: the
%% build's check of every internal link and anchor of the site it wrote,
%% made or written by hand, refuses a site with one that leads nowhere,
%% naming each with its page: here a raw block's link to a page that is not
%% there, to an anchor another page does not hold and to one its own page
%% does not, and every page's link to an icon whose file is gone, which the
%% icons' file then holds no symbol of.
dangling() ->
    Source = "build/site/dangling",
    _ = file:del_dir_r(Source),
    _ = file:del_dir_r("build/site/dangling-out"),
    [copied(filename:join(?SOURCE, File), filename:join(Source, File))
     || File <- files(?SOURCE), File =/= "site/root/assets/img/icons/arrow-right.svg"],
    appended(Source ++ "/guide/faq.md",
             ["\n<p>\n<a href=\"/nowhere/\">a page</a>, <a href=\"/guide/1.html#nowhere\">",
              "another's anchor</a> and <a href=\"#nowhere\">its own</a>\n</p>\n"]),
    {Status, Output} =
        ern_integration_tests:sh(generate(Source, "build/site/dangling-out", ?CONFIG)),
    ?assertEqual(1, Status),
    [?assertMatch({_, _}, binary:match(Output, Line))
     || Line <- [<<"build/site/dangling-out holds links that lead nowhere:\n">>,
                 <<"\n  /faq/ links to /nowhere/, which is no file of the site\n">>,
                 <<"\n  /faq/ links to /guide/1.html#nowhere, an anchor /guide/1.html does not",
                   " hold\n">>,
                 <<"\n  /faq/ links to #nowhere, an anchor /faq/ does not hold\n">>,
                 <<"\n  /guide/0.html links to /assets/img/icons.">>]],
    Icons = "icons\\.[0-9a-f]{8}\\.svg",
    ?assertMatch({match, [_]},
                 re:run(Output, "/guide/0.html links to /assets/img/" ++ Icons ++ "#arrow-right, an"
                                " anchor /assets/img/" ++ Icons ++ " does not hold\n",
                        [global])).

%% plan MVP 4.2 item 5, docs/proposals/site/decisions.md *The generation*:
%% the generator run as `make site` runs it, over an export of the
%% repository by git archive, here HEAD's, its documents, its library's
%% pages and its log, with the site's own files as they stand, the
%% generator's here; every page written and every link of the site
%% resolved. It does not cover `make site`'s build of the toolchain in the
%% export, nor its `make man`, nor a document of the working tree that HEAD
%% does not hold yet.
head() ->
    Source = "build/site/head",
    _ = file:del_dir_r("build/site/head-out"),
    _ = file:del_dir_r(Source),
    ok = filelib:ensure_dir(Source ++ "/"),
    ern_integration_tests:succeed("sh -c 'git -C .. archive HEAD | tar -x -C " ++ Source ++ "'"),
    ok = file:del_dir_r(Source ++ "/site"),
    [copied(filename:join("../site", File), filename:join(Source ++ "/site", File))
     || File <- files("../site")],
    Commit = string:trim(ern_integration_tests:succeed("git rev-parse HEAD")),
    ern_integration_tests:succeed("../bin/ern run ../build/tools/site.erc " ++ Source
                                  ++ " build/site/head-out 9.9.9 " ++ binary_to_list(Commit)
                                  ++ " " ++ ?CONFIG),
    ?assert(length([File || File <- files("build/site/head-out"),
                            filename:extension(File) =:= ".html"]) > 80).

%% docs/development.md *Building*: `make site` refuses to run without the tag
%% it builds from and the server's configuration, saying how it is called,
%% and refuses a tag that holds no site/, every tag before the generator's,
%% since the site's generator and its templates come from the tag. The
%% refusals are run; the export and the build they guard are not.
site_refusals_test() ->
    Make = "env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL make -s -C .. site",
    {Usage, Said} = ern_integration_tests:sh(Make),
    ?assertEqual(2, Usage),
    ?assertMatch({_, _}, binary:match(Said, <<"make site TAG=v0.x.y CONFIG=path/to/config.json">>)),
    {Before, Refused} = ern_integration_tests:sh(Make ++ " TAG=v0.9.0 CONFIG=test/" ++ ?CONFIG),
    ?assertEqual(2, Before),
    ?assertMatch({_, _}, binary:match(Refused, <<"v0.9.0 holds no site/">>)).

appended(File, Text) ->
    {ok, Device} = file:open(File, [append]),
    ok = file:write(Device, Text),
    ok = file:close(Device).

%% docs/proposals/site/decisions.md *The templates*, site/templates/README.md:
%% every template and fragment holds the tokens its row of the README lists,
%% and every file has a row.
templates_test() ->
    Rows = readme_rows(),
    Files = [File || File <- files("../site/templates"), filename:extension(File) =:= ".html"],
    ?assert(length(Files) > 20),
    ?assertEqual(Files, lists:sort([File || {File, _} <- Rows])),
    ?assertEqual([], [{File, Listed, Held} || {File, Listed} <- Rows,
                                              Held <- [tokens(read("../site/templates", File))],
                                              Held =/= Listed]).

%% The site generated from the fixture's tree, the tree made afresh: the
%% fixture's documents at their paths, the site's files and the logos.
generated() ->
    _ = file:del_dir_r("build/site"),
    [copied(filename:join(?TREE, File), filename:join(?SOURCE, File)) || File <- files(?TREE)],
    [copied(filename:join("../site", File), filename:join(?SOURCE ++ "/site", File))
     || File <- files("../site")],
    [copied("../assets/" ++ Logo, ?SOURCE ++ "/assets/" ++ Logo) || Logo <- ?LOGOS],
    ern_integration_tests:succeed(generate(?OUT, ?CONFIG)).

copied(From, To) ->
    ok = filelib:ensure_dir(To),
    {ok, _} = file:copy(From, To).

generate(Out, Config) ->
    generate(?SOURCE, Out, Config).

generate(Source, Out, Config) ->
    "../bin/ern run ../build/tools/site.erc " ++ Source ++ " " ++ Out ++ " " ++ ?VERSION ++ " "
        ++ ?TAG ++ " " ++ Config.

%% make site-expected: the expected pages written again from the fixture,
%% after a change to the look or the generation that is meant.
-spec write_expected() -> ok.
write_expected() ->
    _ = generated(),
    _ = file:del_dir_r(?EXPECTED),
    lists:foreach(fun(File) ->
                      Path = filename:join(?EXPECTED, File),
                      ok = filelib:ensure_dir(Path),
                      ok = file:write_file(Path, read(?OUT, File))
                  end, [File || File <- files(?OUT), filename:extension(File) =:= ".html"]).

%% A digested file's name, as the generator writes it, from its content.
digested(Content, File) ->
    Digest = string:lowercase(binary:encode_hex(crypto:hash(sha, Content))),
    filename:rootname(File) ++ "." ++ binary_to_list(binary:part(Digest, 0, 8))
        ++ filename:extension(File).

%% The icons' file the generator wrote, named by its own content's digest.
gathered() ->
    [Icons] = [File || File <- files(?OUT), lists:prefix("assets/img/icons.", File)],
    ?assertEqual(digested(read(?OUT, Icons), "assets/img/icons.svg"), Icons),
    Icons.

%% A page with each digest in an asset's name masked, so that a change to
%% the stylesheet or the script alone changes no expected page.
undigested(Page) ->
    re:replace(Page, "\\.[0-9a-f]{8}\\.(css|js|svg)", ".DIGEST.\\1", [global, {return, binary}]).

matches(Text, Pattern) ->
    case re:run(Text, Pattern, [global, {capture, all_but_first, binary}]) of
        {match, Found} -> Found;
        nomatch -> []
    end.

%% Each file under a directory, by its path there, in order.
files(Directory) ->
    lists:sort([File || File <- filelib:wildcard("**", Directory),
                        filelib:is_regular(filename:join(Directory, File))]).

read(Directory, File) ->
    {ok, Bytes} = file:read_file(filename:join(Directory, File)),
    Bytes.

%% The README's rows, each file it names, under fragments/ for the
%% fragments' table, with the tokens its last column lists.
readme_rows() ->
    Lines = binary:split(read("../site/templates", "README.md"), <<"\n">>, [global]),
    {Rows, _} = lists:mapfoldl(
                  fun(<<"## The fragments", _/binary>> = Line, _) -> {[], {Line, "fragments/"}};
                     (<<"| `", _/binary>> = Line, {_, Prefix} = State) ->
                          Cells = binary:split(Line, <<" | ">>, [global]),
                          Named = [Prefix ++ Name || Name <- quoted(hd(Cells))],
                          Tokens = lists:usort(quoted(lists:last(Cells))),
                          {[{File, Tokens} || File <- Named], State};
                     (_, State) -> {[], State}
                  end, {none, ""}, Lines),
    lists:append(Rows).

quoted(Cell) ->
    case re:run(Cell, "`([^`]+)`", [global, {capture, all_but_first, list}]) of
        {match, Found} -> [Text || [Text] <- Found];
        nomatch -> []
    end.

tokens(Template) ->
    case re:run(Template, "\\{\\{([a-z_]+)\\}\\}", [global, {capture, all_but_first, list}]) of
        {match, Found} -> lists:usort([Token || [Token] <- Found]);
        nomatch -> []
    end.
