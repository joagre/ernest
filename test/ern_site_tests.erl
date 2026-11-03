%% The site's generator, tools/site.ern (plan, MVP 4.2 item 2), run over a
%% tree of its own: the fixture fixtures/site/language.md standing as the
%% guide, beside the site's files, ../site/, and the logos. The pages it
%% writes are held to the expected ones under fixtures/site/expected/,
%% their assets' digests aside, so that the look and the generation never
%% drift; the assets, the links and the templates' tokens are held each by
%% a test of its own. `make site-expected` writes the expected pages again
%% after a change to the look that is meant (write_expected/0). Run from
%% this directory by its Makefile, after `make`, which builds the generator
%% into ../build/tools. Every test here was written after the generator, a
%% regression test.
-module(ern_site_tests).

-include_lib("eunit/include/eunit.hrl").

-export([write_expected/0]).

-define(FIXTURE, "fixtures/site/language.md").
-define(EXPECTED, "fixtures/site/expected").
-define(SOURCE, "build/site/source").
-define(OUT, "build/site/out").
%% The release the pages name, and the tag their links to GitHub and their
%% date name: guide/language.md's last commit at a tag stays as it is.
-define(VERSION, "9.9.9").
-define(TAG, "v0.9.0").
%% The files whose names hold a digest of their content
%% (docs/proposals/site/decisions.md *The generation*).
-define(DIGESTED, ["assets/css/site.css", "assets/js/site.js", "assets/img/icons.svg"]).
-define(LOGOS, ["ernest-mark.svg", "ernest-avatar-64.png", "ernest-social-light.png"]).

generated_test_() ->
    {setup, fun generated/0, fun(_) -> ok end,
     [{"pages", fun pages/0}, {"assets", fun assets/0}, {"links", fun links/0},
      {"refused", {timeout, 30, fun refused/0}}]}.

%% plan MVP 4.2 item 2, docs/proposals/site/decisions.md *Every page*,
%% *Anchors*, *Links*, *The templates* and *The live shell*: the guide's
%% contents page and a page for each chapter, as the expected pages show
%% them: each numbered heading anchored by its number, a citation a link to
%% its section, a link written for GitHub led to the site's page of its
%% target, Ernest colored by the toolchain's lexer, each block's buttons as
%% the guide tests group the blocks, the sidebar, the book's title, the
%% chapters before and after, and the footer naming the source with its
%% date, all in the readable form. It does not cover the browser's reading
%% of a page, which the mockup's look was checked by.
pages() ->
    Expected = files(?EXPECTED),
    ?assertEqual(["guide/0.html", "guide/1.html", "guide/2.html", "guide/index.html"], Expected),
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
%% to a page or an anchor of the guide, or to an asset, leads to a file
%% written and to an anchor it holds; the other pages are not written yet,
%% and the site's check of every link is the build's (plan, MVP 4.2 item 5).
links() ->
    Pages = [File || File <- files(?OUT), filename:extension(File) =:= ".html"],
    Anchors = maps:from_list([{File, anchors(read(?OUT, File))} || File <- Pages]),
    IconsFile = digested("assets/img/icons.svg"),
    Written = Anchors#{IconsFile => icons(read(?OUT, IconsFile))},
    Unresolved = [{Page, Link} || Page <- Pages, Link <- hrefs(read(?OUT, Page)),
                                  not resolves(Page, Link, Written)],
    ?assert(length(Pages) =:= 4),
    ?assertEqual([], Unresolved).

%% plan MVP 4.2 item 2: the generator writes the site into a directory of
%% its own, so that no page whose source is gone stays, and refuses one
%% that is there already.
refused() ->
    {Status, Output} = ern_integration_tests:sh(generate()),
    ?assertEqual(1, Status),
    ?assertMatch({_, _}, binary:match(Output, <<"build/site/out is there already">>)).

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
%% fixture as the guide, the site's files and the logos.
generated() ->
    _ = file:del_dir_r("build/site"),
    copied(?FIXTURE, ?SOURCE ++ "/guide/language.md"),
    [copied(filename:join("../site", File), filename:join(?SOURCE ++ "/site", File))
     || File <- files("../site")],
    [copied("../assets/" ++ Logo, ?SOURCE ++ "/assets/" ++ Logo) || Logo <- ?LOGOS],
    ern_integration_tests:succeed(generate()).

copied(From, To) ->
    ok = filelib:ensure_dir(To),
    {ok, _} = file:copy(From, To).

generate() ->
    "../bin/ern run ../build/tools/site.erc " ++ ?SOURCE ++ " " ++ ?OUT ++ " " ++ ?VERSION ++ " "
        ++ ?TAG.

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

%% Whether a link of Page leads to a file written and an anchor it holds;
%% a link elsewhere, to a page not written yet or another site, is not read.
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
    case lists:prefix("guide/", File) orelse lists:prefix("assets/", File) of
        false -> true;
        true when Anchor =:= none -> Written;
        true -> Written andalso lists:member(Anchor, maps:get(File, Anchors, []))
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
