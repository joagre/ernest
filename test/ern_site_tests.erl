%% The site's generator, tools/site.ern (plan, MVP 4.2 item 2), run over a
%% tree of its own: the documents under fixtures/site/tree/, each standing
%% at the path of the document it plays, the guide, the tour, the report,
%% the library's pages, Why, the questions, the deployment guide, the README
%% and the release notes, beside the site's files, ../site/, and the logos,
%% with fixtures/site/config.json as the server's configuration.
%%
%% The pages it writes are held to the expected ones under fixtures/site/expected/,
%% their assets' digests aside, so that the look and the generation never
%% drift; the assets, the links, the descriptions of the site's own pages,
%% the refusals and the templates' tokens are held each by a test of its
%% own. `make site-expected` writes the expected pages again after a change
%% to the look that is meant (write_expected/0). Run from this directory by
%% its Makefile, after `make`, which builds the generator into
%% ../build/tools. Every test here was written after the generator, a
%% regression test.
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
%% The files whose names hold a digest of their content
%% (docs/proposals/site/decisions.md *The generation*).
-define(DIGESTED, ["assets/css/site.css", "assets/js/site.js", "assets/img/icons.svg"]).
-define(LOGOS, ["ernest-mark.svg", "ernest-avatar-64.png", "ernest-social-light.png"]).

generated_test_() ->
    {setup, fun generated/0, fun(_) -> ok end,
     [{"pages", fun pages/0}, {"assets", fun assets/0}, {"links", fun links/0},
      {"described", fun described/0}, {"refused", {timeout, 30, fun refused/0}},
      {"unconfigured", {timeout, 30, fun unconfigured/0}}]}.

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
    Named = maps:from_list([{File, digested(File)} || File <- ?DIGESTED]),
    ?assertEqual(lists:sort([maps:get(File, Named, File) || File <- Root]
                            ++ ["assets/" ++ Logo || Logo <- ?LOGOS]),
                 [File || File <- files(?OUT), filename:extension(File) =/= ".html"]),
    ?assertEqual([], [File || File <- Root,
                              read("../site/root", File)
                                  =/= read(?OUT, maps:get(File, Named, File))]),
    Page = read(?OUT, "guide/1.html"),
    ?assertEqual([], [Name || Name <- maps:values(Named),
                              binary:match(Page, list_to_binary("\"/" ++ Name)) =:= nomatch]).

%% docs/proposals/site/decisions.md *Links*: every link of a written page
%% to the site, to a page, an anchor of a page or an asset, leads to a file
%% written and to an anchor it holds. The site's check of every link of the
%% real site is the build's (plan, MVP 4.2 item 5).
links() ->
    Pages = [File || File <- files(?OUT), filename:extension(File) =:= ".html"],
    Anchors = maps:from_list([{File, anchors(read(?OUT, File))} || File <- Pages]),
    IconsFile = digested("assets/img/icons.svg"),
    Written = Anchors#{IconsFile => icons(read(?OUT, IconsFile))},
    Unresolved = [{Page, Link} || Page <- Pages, Link <- hrefs(read(?OUT, Page)),
                                  not resolves(Page, Link, Written)],
    ?assert(length(Pages) =:= 26),
    ?assertEqual([], Unresolved).

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
    "../bin/ern run ../build/tools/site.erc " ++ ?SOURCE ++ " " ++ Out ++ " " ++ ?VERSION ++ " "
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

%% A digested file's name, as the generator writes it.
digested(File) ->
    Digest = string:lowercase(binary:encode_hex(crypto:hash(sha, read("../site/root", File)))),
    filename:rootname(File) ++ "." ++ binary_to_list(binary:part(Digest, 0, 8))
        ++ filename:extension(File).

%% A page with each digest in an asset's name masked, so that a change to
%% the stylesheet or the script alone changes no expected page.
undigested(Page) ->
    re:replace(Page, "\\.[0-9a-f]{8}\\.(css|js|svg)", ".DIGEST.\\1", [global, {return, binary}]).

hrefs(Page) ->
    {match, Found} = re:run(Page, "(?:href|src)=\"([^\"]*)\"",
                            [global, {capture, all_but_first, list}]),
    [Link || [Link] <- Found].

anchors(Page) ->
    case re:run(Page, " id=\"([^\"]*)\"", [global, {capture, all_but_first, list}]) of
        {match, Found} -> [Anchor || [Anchor] <- Found];
        nomatch -> []
    end.

icons(Svg) ->
    {match, Found} = re:run(Svg, "<symbol[^>]* id=\"([^\"]*)\"",
                            [global, {capture, all_but_first, list}]),
    [Icon || [Icon] <- Found].

%% Whether a link of Page leads to a file written and an anchor it holds,
%% each as its attribute writes it; a link to another site is not read.
resolves(Page, "#" ++ Anchor, Anchors) ->
    lists:member(Anchor, maps:get(Page, Anchors));
resolves(_, "/" ++ Link, Anchors) ->
    {Path, Anchor} = case string:split(Link, "#") of
                         [Before, After] -> {Before, After};
                         [Before] -> {Before, none}
                     end,
    File = case lists:suffix("/", Path) orelse Path =:= "" of
               true -> Path ++ "index.html";
               false -> Path
           end,
    Written = filelib:is_regular(filename:join(?OUT, File)),
    case Anchor of
        none -> Written;
        _ -> Written andalso lists:member(Anchor, maps:get(File, Anchors, []))
    end;
resolves(_, _, _) ->
    true.

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
