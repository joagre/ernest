%% The site's client in a browser, `make test-browser` (docs/design/site.md,
%% *The live shell*): a headless Chrome, driven over its
%% DevTools protocol, reads the fixture's pages, which OTP's httpd serves,
%% and its panel's session runs on a stub of the server's client at
%% /shell/client.js, fixtures/site/client.js, which has the interface of
%% ernest-httpd's design's *The client* and no socket behind it. The stub
%% keeps what the page asked of each session, which the test reads in the
%% page, and tells the page what the test sets: the attach, the warning, the
%% output and each end. It answers no input as a shell does, and a real
%% shell behind the server's client is a server's to show by hand before a
%% release.
%%
%% The homepage's measures are made on the repository's own site, which a
%% second httpd serves, since the page's height is its claims', which Why
%% gives and the fixture's tree does not hold.
%%
%% The run needs Chrome, which development.md names among what the tests
%% need; where none is found it says so and stops (run/0). It is no part of
%% make test or make test-full. Every test here was written after the code,
%% a regression test, but the homepage's first screen, the placing of a
%% block's tools and the homepage on a narrower page, each written before
%% the code it holds.
-module(ern_browser_tests).

-include_lib("eunit/include/eunit.hrl").

-export([run/0]).

-define(SITE_BASE, "build/browser").
-define(STUB, "fixtures/site/client.js").

%% What the browsers are, by the names their programs go by.
-define(CHROMES, ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]).

%% make test-browser: the tests, where a Chrome is found, and otherwise
%% the reason they cannot run, with the status 2.
-spec run() -> no_return().
run() ->
    case chrome() of
        false ->
            io:format("make test-browser: no Chrome found (~s); the test of the site's client"
                      " runs in one~n", [string:join(?CHROMES, ", ")]),
            halt(2);
        _ ->
            halt(case eunit:test(?MODULE, [verbose]) of ok -> 0; _ -> 1 end)
    end.

chrome() ->
    case [Found || Name <- ?CHROMES, Found <- [os:find_executable(Name)], Found =/= false] of
        [Path | _] -> Path;
        [] -> false
    end.

%%
%% The tests
%%

%% docs/design/site.md *The live shell*, *A page kept under the panel* and
%% *The homepage*: each check below, in one browser over the fixture's pages
%% and the repository's own homepage.
client_test_() ->
    {setup, fun started/0, fun stopped/1,
     fun(World) ->
         [{timeout, 120, {Name, fun() -> Check(World) end}} || {Name, Check} <- checks()]
     end}.

checks() ->
    [{"the panel and a session", fun session/1},
     {"Paste, Load and a transcript's Paste", fun pastes/1},
     {"the example's Try it", fun example/1},
     {"the homepage's first screen", fun first_screen/1},
     {"a block's tools placed by its first line", fun tools_placed/1},
     {"the homepage on a narrower page", fun narrower/1},
     {"the navigation that keeps the panel", fun navigation/1},
     {"an address whose fragment is no percent-encoding", fun unencoded/1},
     {"a page still on its way", fun on_its_way/1},
     {"a whole load and a joined session", fun joined/1},
     {"Hide, the handle and F6", fun keyboard/1},
     {"Stop, Start and Restart", fun ends/1},
     {"the warning and an expiry's notice", fun expiry/1},
     {"the other ends", fun closes/1},
     {"a paste waits for the first output", fun waiting/1},
     {"a terminal or a client that does not load", fun unloaded/1},
     {"two starts while the terminal loads", fun started_twice/1},
     {"a terminal whose stylesheet loads last", fun styled/1},
     {"the shell's page and a phone", fun pages/1},
     {"every page on a phone", fun phone/1}].

%% docs/design/site.md *The live shell*: no panel opens until
%% the visitor asks; the header's beside button opens it, pressed, and puts
%% the focus in the terminal; the bar names no state before a session, and
%% Start starts one at the panel's size, connecting, the attach new
%% answered by nothing of the page's, then running; the terminal fills the
%% panel with no scrollbar of its own.
session(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    ?assert(eval(Page, "document.querySelector('.shell-panel').hidden")),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside') && document"
                       ".querySelector('.panel-toggle .beside').getAttribute('aria-pressed')"
                       " === 'true'")),
    ?assertEqual(<<>>, eval(Page, state())),
    ?assertEqual(<<"status">>, eval(Page, "document.querySelector('.panel-state').role")),
    Session = start(Page),
    [Rows, Columns] = eval(Page, stubbed(Session) ++ ".size"),
    ?assert(Rows > 0 andalso Columns > 0),
    until(Page, state() ++ " === 'running'"),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assertEqual(<<>>, eval(Page, stubbed(Session) ++ ".keys")),
    ?assert(eval(Page, "document.activeElement.classList.contains('xterm-helper-textarea')")),
    ?assertEqual([0, 0], eval(Page, overflow(".panel-screen"))),
    stop(Page, Session).

%% docs/design/site.md *The live shell*: a block's Paste
%% sends it as one input, bracketed as the shell asked the terminal, and
%% nothing after it; a Load the same, then Enter and `main()`, typed and
%% not entered; a transcript's input its own Paste, its prompt left out; and
%% a long input's Paste stands at the block's visible right edge.
pastes(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    Pasted = keys(Page, Session, <<"\e[201~">>),
    ?assertEqual(<<"\e[200~fn double(value : Int) : Int =\r    value * 2\e[201~">>, Pasted),
    click_tool(Page, "pre.code[data-shell=\"load\"]", "Load into the shell"),
    ?assertEqual(<<"\e[200~export fn main() : Unit =\r    Io.println(\"hello, world\")\e[201~"
                   "\rmain()">>, keys(Page, Session, <<"\rmain()">>)),
    eval(Page, "document.querySelector('pre.transcript[data-shell=\"paste\"] .line-paste')"
               ".click()"),
    ?assertEqual(<<"\e[200~1 + 2\e[201~">>, keys(Page, Session, <<"\e[201~">>)),
    Edge = eval(Page, "(() => { const button = [...document.querySelectorAll('.line-paste')]"
                      ".at(-1); const pre = button.closest('pre'); const at = button"
                      ".getBoundingClientRect(), box = pre.getBoundingClientRect(); return"
                      " [pre.scrollWidth > pre.clientWidth, at.right <= box.right + 0.5,"
                      " at.left >= box.left]; })()"),
    ?assertEqual([true, true, true], Edge),
    stop(Page, Session).

%% docs/design/site.md *The homepage*: the example's button,
%% Try it, puts the example's code into the shell, opening the panel and
%% starting a session, and its label never changes.
example(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/", {1440, 900}),
    Code = eval(Page, "document.querySelector('.home-use pre.code').textContent"),
    eval(Page, "[...document.querySelectorAll('button')].find((button) => button.textContent"
               " === 'Try it').click()"),
    Session = connected(Page, 0),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside')")),
    Typed = binary:replace(string:trim(Code, trailing), <<"\n">>, <<"\r">>, [global]),
    ?assertEqual(<<"\e[200~", Typed/binary, "\e[201~">>, keys(Page, Session, <<"\e[201~">>)),
    ?assert(eval(Page, "[...document.querySelectorAll('button')].some((button) =>"
                       " button.textContent === 'Try it')")),
    stop(Page, Session).

%% docs/design/site.md *The homepage*: the repository's own
%% homepage at three sizes of the page, each the page's own after the
%% browser's and the system's bars. At 1366 by 650 its first screen holds
%% the heading, the opening and the four claims; at 1536 by 730 the
%% counter's code, the session and Try it as well, the counter's block
%% ending under it by less than its own padding; and at 1920 by 950 that
%% block whole and the tour's sentence as well. A part is held by its
%% lower edge.
first_screen(#{page := Page, repository := Url}) ->
    Sizes = [{{1366, 650}, ["#intro-title", ".opening .lead:last-child", ".claims ol"]},
             {{1536, 730}, [".counter-column code", ".session-column .block", ".run button"]},
             {{1920, 950}, [".counter-column .block", ".next"]}],
    lists:foldl(fun({Size, Parts}, Held) ->
                        fresh(Page, Url ++ "/", Size),
                        drawn(Page),
                        Shown = Held ++ Parts,
                        ?assertEqual({Size, []}, {Size, below_first_screen(Page, Shown)}),
                        Shown
                end, [], Sizes).

%% docs/design/site.md *The live shell*: a block's tools are always shown,
%% over its upper right corner where its first line leaves them room, and
%% on a row of their own above it where it does not, so that the first line
%% is never under them; and they move when the block's width changes. The
%% counter's block, on the fixture's homepage, is wide enough for its first
%% line beside its Copy at the page's full width, and not at a phone's.
tools_placed(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/", {1440, 900}),
    drawn(Page),
    Counter = "document.querySelector('.counter-column .block')",
    ?assertEqual([false, true, true], eval(Page, placing(Counter))),
    resized(Page, {400, 844}),
    until(Page, Counter ++ ".classList.contains('tools-above')"),
    ?assertEqual([true, true, true], eval(Page, placing(Counter))),
    resized(Page, {1440, 900}),
    until(Page, "!" ++ Counter ++ ".classList.contains('tools-above')"),
    ?assertEqual([false, true, true], eval(Page, placing(Counter))).

%% A block's tools as they stand: whether they are on the row above; that
%% they stand where that says, above the code's box or inside it at its
%% corner; and that its first line is not under them, which on the row
%% above is that the line reaches past the room their buttons take.
placing(Block) ->
    "(() => { const block = " ++ Block ++ "; const pre = block.querySelector('pre');"
    " const tools = block.querySelector('.block-tools'); const box ="
    " pre.getBoundingClientRect(); const at = tools.getBoundingClientRect();"
    " const room = tools.lastElementChild.getBoundingClientRect().right -"
    " tools.firstElementChild.getBoundingClientRect().left; const walker ="
    " document.createTreeWalker(pre, NodeFilter.SHOW_TEXT); const line ="
    " document.createRange(); line.selectNodeContents(pre); while (walker.nextNode()) {"
    " const newline = walker.currentNode.data.indexOf('\\n'); if (newline >= 0) {"
    " line.setEnd(walker.currentNode, newline); break; } } const end ="
    " line.getBoundingClientRect().right; const above ="
    " block.classList.contains('tools-above'); return [above, above ? at.bottom <= box.top :"
    " at.top >= box.top && at.right <= box.right, above ? end > box.right - room :"
    " end <= at.left]; })()".

%% docs/design/site.md *The homepage*: on a page of 960 by 950, narrower
%% than the page's full width, the repository's homepage stands the
%% example's parts one under the other, the counter, Try it, the session
%% and the tour's sentence; neither block scrolls sideways; and Try it is
%% on the first screen.
narrower(#{page := Page, repository := Url}) ->
    fresh(Page, Url ++ "/", {960, 950}),
    drawn(Page),
    Parts = [".counter-column .block", ".run button", ".session-column .block", ".next"],
    Edges = eval(Page, selectors(Parts) ++ ".map((part) => { const box ="
                       " document.querySelector(part).getBoundingClientRect(); return [box.top,"
                       " box.bottom]; })"),
    ?assertEqual([], overlapping(Parts, Edges)),
    ?assertEqual([0, 0], [lists:nth(2, eval(Page, overflow(Block)))
                          || Block <- [".counter-column pre", ".session-column pre"]]),
    ?assertEqual([], below_first_screen(Page, [".run button"])).

%% The parts, by their selectors, whose lower edge stands below the first
%% screen, each with that edge in pixels from the page's top.
below_first_screen(Page, Parts) ->
    eval(Page, selectors(Parts) ++ ".map((part) => [part, document.querySelector(part)"
               ".getBoundingClientRect().bottom + document.scrollingElement.scrollTop])"
               ".filter(([, edge]) => edge > innerHeight)").

%% The parts, each with the one after it, where the one after begins above
%% the lower edge of the one before, by their edges, each its top and its
%% bottom.
overlapping([Upper, Lower | Parts], [[_, Bottom], [Top, _] = Edge | Edges]) ->
    [{Upper, Lower} || Top < Bottom] ++ overlapping([Lower | Parts], [Edge | Edges]);
overlapping(_, _) ->
    [].

%% The selectors as a list in the page's script.
selectors(Parts) ->
    "[" ++ string:join(["'" ++ Part ++ "'" || Part <- Parts], ", ") ++ "]".

%% docs/design/site.md *The live shell*: while the panel is
%% open a link fetches its page and puts its main in place, the panel, its
%% session and its screen kept; the new page's blocks have their tools, the
%% header marks its room, it starts at its top, the next Tab reaches the
%% skip link and its title is said; back returns to the page and its
%% scroll, forward again, and a link to another page's anchor puts it in
%% view.
navigation(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    eval(Page, "window.kept = document.querySelector('.xterm'); document.querySelector('.page')"
               ".scrollTop = 300"),
    Kept = eval(Page, "document.querySelector('.page').scrollTop"),
    ?assert(Kept > 0),
    eval(Page, "document.querySelector('.page-nav [rel=\"next\"]').click()"),
    until(Page, "location.pathname === '/guide/2.html' && document.title.startsWith('2.')"),
    ?assert(eval(Page, "window.kept === document.querySelector('.xterm') && " ++ state()
                       ++ " === 'running'")),
    ?assert(eval(Page, "document.querySelectorAll('main .block-tools').length > 0")),
    ?assertEqual(<<"Guide">>, eval(Page, "document.querySelector('.site-nav"
                                         " [aria-current=\"page\"]').textContent")),
    ?assertEqual(0, eval(Page, "document.querySelector('.page').scrollTop")),
    key(Page, "Tab", 9),
    ?assertEqual(<<"skip-link">>, eval(Page, "document.activeElement.className")),
    ?assert(eval(Page, "document.querySelector('.announcer').textContent === document.title")),
    eval(Page, "history.back()"),
    until(Page, "location.pathname === '/guide/1.html' && document.title.startsWith('1.')"),
    ?assertEqual(Kept, eval(Page, "document.querySelector('.page').scrollTop")),
    ?assert(eval(Page, "window.kept === document.querySelector('.xterm')")),
    eval(Page, "history.forward()"),
    until(Page, "location.pathname === '/guide/2.html'"),
    eval(Page, "history.back()"),
    until(Page, "location.pathname === '/guide/1.html' && document.title.startsWith('1.')"),
    eval(Page, "document.querySelector('main a[href=\"/guide/2.html#2.1\"]').click()"),
    until(Page, "location.pathname + location.hash === '/guide/2.html#2.1'"),
    ?assert(eval(Page, "(() => { const top = document.getElementById('2.1')"
                       ".getBoundingClientRect().top; return top >= 0 && top < innerHeight; })()")),
    ?assertEqual(1, eval(Page, "stub.sessions.length")),
    stop(Page, Session).

%% docs/design/site.md *Anchors* and *The live shell*: an address from
%% outside the site's links may hold a fragment that is no
%% percent-encoding, as one copied before the site encoded its fragments
%% did, `#Int.%`; back to it under the panel puts its page in place, says
%% its title and throws nothing, the fragment read as the browser reads it.
%% A regression test, written after the code.
unencoded(#{page := Page, url := Url, cdp := Cdp}) ->
    fresh(Page, Url ++ "/guide/2.html", {1440, 900}),
    open(Page, Url ++ "/guide/1.html#100%", {1440, 900}),
    Before = length(exceptions(Cdp)),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    eval(Page, "document.querySelector('.page-nav [rel=\"next\"]').click()"),
    until(Page, "location.pathname === '/guide/2.html' && document.title.startsWith('2.')"),
    eval(Page, "history.back()"),
    until(Page, "shown === '/guide/1.html' && document.querySelector('.announcer').textContent"
                " === document.title && document.title.startsWith('1.')"),
    ?assertEqual(<<"#100%">>, eval(Page, "location.hash")),
    ?assertEqual([], lists:nthtail(Before, exceptions(Cdp))).

%% docs/design/site.md *The live shell*: back and forward go
%% where the visitor last asked. A move made while a page is on its way
%% fetches its own, even the page that still shows, and the one it replaced
%% is dropped, its failure with it. The fetches are held here, so that the
%% order is the test's.
on_its_way(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    eval(Page, "document.querySelector('.page-nav [rel=\"next\"]').click()"),
    until(Page, "location.pathname === '/guide/2.html' && document.title.startsWith('2.')"),
    eval(Page, "window.stayed = true; window.held = []; window.real = window.fetch;"
               " window.fetch = (...args) => new Promise((resolve, reject) =>"
               " held.push({ args, resolve, reject }))"),
    eval(Page, "history.back()"),
    until(Page, "location.pathname === '/guide/1.html' && held.length === 1"),
    eval(Page, "history.forward()"),
    until(Page, "location.pathname === '/guide/2.html' && held.length === 2"),
    eval(Page, "held[0].reject(new Error('dropped'))"),
    eval(Page, "real(...held[1].args).then(held[1].resolve)"),
    until(Page, "document.querySelector('main a[href=\"/guide/2.html#2.1\"]') === null"
                " && document.title.startsWith('2.') && shown === '/guide/2.html'"),
    ?assert(eval(Page, "location.pathname === '/guide/2.html' && window.stayed === true")).

%% docs/design/site.md *The live shell*, ernest-httpd's design
%% *The client*: a page loaded whole opens the panel as it was kept; a
%% session the client says this browser joined is asked to draw its line
%% again, C-l, and a paste into it is bracketed by the page itself, since
%% its shell asked an earlier terminal.
joined(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    open(Page, Url ++ "/guide/1.html", {1440, 900}),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside') && !document"
                       ".querySelector('.shell-panel').hidden")),
    eval(Page, "window.stubMode = { joined: true }"),
    Session = start(Page),
    ?assertEqual(<<12>>, keys(Page, Session, <<12>>)),
    until(Page, rows() ++ ".includes('again')"),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(Page, Session, <<"\e[201~">>)),
    stop(Page, Session).

%% docs/design/site.md *The live shell*: Hide hides the panel
%% and keeps the session, the header's button marked with a dot and the
%% focus given back to it, and a link keeps the hidden session's page; the
%% handle is a separator the arrow keys move; F6 in the terminal moves the
%% focus to the panel's controls.
keyboard(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    eval(Page, "session.terminal.focus()"),
    key(Page, "F6", 117),
    ?assert(eval(Page, "document.activeElement === panel.start")),
    Before = eval(Page, "document.querySelector('.shell-panel').getBoundingClientRect().width"),
    eval(Page, "document.querySelector('.panel-handle').focus()"),
    key(Page, "ArrowLeft", 37),
    After = eval(Page, "document.querySelector('.shell-panel').getBoundingClientRect().width"),
    ?assert(After > Before),
    eval(Page, "session.terminal.focus()"),
    eval(Page, "document.querySelector('.panel-bar [aria-label=\"Hide the shell\"]').click()"),
    ?assert(eval(Page, "document.querySelector('.shell-panel').hidden && " ++ state()
                       ++ " === 'running'")),
    ?assert(eval(Page, "document.querySelector('.panel-toggle .beside').classList"
                       ".contains('waiting')")),
    ?assertEqual(<<"BUTTON">>, eval(Page, "document.activeElement.tagName")),
    eval(Page, "window.kept = document.querySelector('.xterm');"
               " document.querySelector('.site-nav a[href=\"/tour/\"]').click()"),
    until(Page, "location.pathname === '/tour/'"),
    ?assert(eval(Page, "window.kept === document.querySelector('.xterm')")),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    stop(Page, Session).

%% docs/design/site.md *The live shell*: Stop asks the client
%% to stop, and the session's end `stopped` is marked in the terminal in the
%% bar's word, which then takes no keys; Start after an end begins below the
%% ended screen, and Restart, a stop and a new session, on a clear one.
ends(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    First = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    stop(Page, First),
    until(Page, rows() ++ ".endsWith('stopped |')"),
    ?assert(eval(Page, "session.terminal.options.disableStdin")),
    ?assertEqual(<<"Start">>, eval(Page, "panel.start.textContent")),
    Second = start(Page),
    until(Page, state() ++ " === 'running' && " ++ rows() ++ ".includes('stopped')"),
    eval(Page, "panel.start.click()"),
    asked(Page, Second, "stop"),
    Third = connected(Page, Second + 1),
    until(Page, state() ++ " === 'running' && !" ++ rows() ++ ".includes('stopped')"),
    stop(Page, Third).

%% docs/design/site.md *The live shell*: the client's warning
%% is a banner that says the seconds once, and Extend asks the client to
%% extend and takes it down; an expiry closes the panel and gives the page
%% its width, the layout kept as it was, and the notice at the window's
%% bottom says why, in the client's lifetime spoken, with an icon that opens
%% the shell and one that closes it, closed by a click anywhere or by Escape
%% outside the terminal.
expiry(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    told(Page, Session, "told.warning(60000)"),
    until(Page, "!document.querySelector('.panel-warning').hidden"),
    ?assertEqual(<<"alert">>, eval(Page, "document.querySelector('.panel-warning').role")),
    ?assertEqual(<<"The session ends in 60 seconds.Extend">>,
                 eval(Page, "document.querySelector('.panel-warning').textContent")),
    eval(Page, "document.querySelector('.panel-warning button').click()"),
    asked(Page, Session, "extend"),
    ?assert(eval(Page, "document.querySelector('.panel-warning').hidden")),
    told(Page, Session, "end('expired')"),
    until(Page, state() ++ " === 'expired'"),
    ?assert(eval(Page, "document.querySelector('.shell-panel').hidden && !document.body"
                       ".classList.contains('panel-beside')")),
    ?assertEqual(<<"The shell ended after 5 minutes without a key; opening it starts a new one.">>,
                 eval(Page, "document.querySelector('.notice span').textContent")),
    ?assertEqual([<<"Open the shell">>, <<"Close this notice">>],
                 eval(Page, "[...document.querySelectorAll('.notice button')]"
                            ".map((button) => button.getAttribute('aria-label'))")),
    ?assertEqual(<<"beside">>, eval(Page, "localStorage.getItem('ernest.panel')")),
    click(Page, 300, 400),
    ?assertEqual(0, eval(Page, "document.querySelector('.notice').childElementCount")),
    eval(Page, "panel.notice.append('x')"),
    key(Page, "Escape", 27),
    ?assertEqual(0, eval(Page, "document.querySelector('.notice').childElementCount")).

%% docs/design/site.md *The live shell*, ernest-httpd's design
%% *The client*: a session taken over is `taken over` and one unavailable
%% `unavailable`, each shown in the panel, and a lost one is `disconnected`.
closes(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    lists:foreach(fun({Reason, Word}) ->
                      Session = start(Page),
                      until(Page, state() ++ " === 'running'"),
                      told(Page, Session, "end('" ++ Reason ++ "')"),
                      until(Page, state() ++ " === '" ++ Word ++ "'"),
                      until(Page, rows() ++ ".endsWith('" ++ Word ++ " |')"),
                      ?assertNot(eval(Page, "document.querySelector('.shell-panel').hidden"))
                  end, [{"takenOver", "taken over"}, {"unavailable", "unavailable"},
                        {"lost", "disconnected"}]).

%% docs/design/site.md *The live shell*: a paste for a session
%% that is starting waits for the session's first output, as a person
%% waits for the prompt, and goes once it comes.
waiting(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "window.stubMode = { held: true }"),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    Session = connected(Page, 0),
    until(Page, state() ++ " === 'running'"),
    ?assertEqual(<<>>, eval(Page, stubbed(Session) ++ ".keys")),
    told(Page, Session, "prompt()"),
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(Page, Session, <<"\e[201~">>)),
    stop(Page, Session).

%% docs/design/site.md *The live shell*: a terminal whose script
%% does not load is `disconnected`, the page's own word, and the next Start
%% loads it again; and so is a client the server does not answer, here one
%% moved aside. The check at the end of the run reads that no exception was
%% left. The terminal's failure is made in the page, so that it comes when
%% asked.
unloaded(#{page := Page, url := Url, site := Site}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    eval(Page, "document.head.append = function (element) { if (element.src?.includes('xterm'))"
               " { setTimeout(() => element.onerror(new Event('error'))); } else"
               " { Element.prototype.append.call(this, element); } }"),
    eval(Page, "panel.start.click()"),
    until(Page, state() ++ " === 'disconnected'"),
    eval(Page, "delete document.head.append"),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    stop(Page, Session),
    Client = filename:join([Site, "shell", "client.js"]),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    ok = file:rename(Client, Client ++ ".aside"),
    try
        eval(Page, "panel.start.click()"),
        until(Page, state() ++ " === 'disconnected'")
    after
        ok = file:rename(Client ++ ".aside", Client)
    end,
    Again = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    stop(Page, Again).

%% docs/design/site.md *The live shell*: a second Start made
%% while the terminal still loads starts no second session.
started_twice(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    eval(Page, "panel.start.click(); panel.start.click()"),
    Session = connected(Page, 0),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assertEqual(1, eval(Page, "stub.sessions.length")),
    stop(Page, Session).

%% docs/design/site.md *The live shell*: the terminal opens once its
%% stylesheet has loaded, however long after its scripts, and fills its
%% panel from the session's first line. One opened before it was drawn
%% unstyled, its screen and its accessibility tree in the page's flow and
%% taller than the panel. The stylesheet is held in the page, so that it
%% comes last when asked. The shell's page has loaded its client for its
%% numbers, so a terminal that did not wait would be open once the fit
%% addon has run. A regression test, written after the code.
styled(#{page := Page, url := Url}) ->
    fresh(Page, Url ++ "/shell/", {1440, 900}),
    until(Page, "document.querySelector('[data-limit]').textContent !== 'a while'"),
    eval(Page, "document.head.append = function (element) { if (element.href?.includes"
               "('xterm.css')) { window.heldStyle = element; } else"
               " { Element.prototype.append.call(this, element); } }"),
    eval(Page, "panel.start.click()"),
    until(Page, "window.heldStyle !== undefined && typeof FitAddon === 'object'"),
    ?assert(eval(Page, "document.querySelector('.panel-screen .xterm') === null && "
                       ++ state() ++ " === ''")),
    eval(Page, "delete document.head.append; document.head.append(heldStyle)"),
    Session = connected(Page, 0),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assertEqual([0, 0], eval(Page, overflow(".panel-screen"))),
    stop(Page, Session).

%% docs/design/site.md *The live shell* and *The other pages*:
%% the shell's page says the client's limits in its list, the times spoken
%% and the counts in digits, holds the panel in its frame and scrolls in
%% neither direction, its terminal filling what the page leaves; on a phone
%% no panel is offered, and a Paste opens the shell's page with the input
%% arriving there, which does not scroll sideways.
pages(#{page := Page, url := Url, cdp := Cdp}) ->
    fresh(Page, Url ++ "/shell/", {1440, 900}),
    until(Page, "document.querySelector('[data-limit]').textContent !== 'a while'"),
    ?assertEqual([<<"It ends after 5 minutes without a key. The panel says so a minute before"
                    " and offers Extend.">>,
                  <<"It runs in a container of its own, with no network. The container is"
                    " removed when the session ends.">>,
                  <<"At most 6 sessions run at once, and one address starts at most 10 in an"
                    " hour. Past either limit the shell says it is unavailable.">>],
                 eval(Page, "[...document.querySelectorAll('.shell-notes li')].slice(0, 3)"
                            ".map((item) => item.textContent)")),
    ?assertEqual([0, 0], eval(Page, overflow("document.scrollingElement"))),
    Session = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assertEqual([0, 0], eval(Page, overflow(".panel-screen"))),
    ?assertEqual([0, 0], eval(Page, overflow("document.scrollingElement"))),
    ?assert(eval(Page, "document.querySelector('.panel-toggle').hidden")),
    stop(Page, Session),
    Phone = page(Cdp, {390, 844}, true),
    fresh(Phone, Url ++ "/guide/1.html", {390, 844}),
    ?assertNot(eval(Phone, "getComputedStyle(document.querySelector('.panel-toggle')).display"
                           " !== 'none'")),
    click_tool(Phone, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    arrived(Phone, "location.pathname === '/shell/' && document.readyState === 'complete'"),
    PhoneSession = connected(Phone, 0),
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(Phone, PhoneSession, <<"\e[201~">>)),
    ?assertEqual(0, lists:nth(2, eval(Phone, overflow("document.scrollingElement")))),
    stop(Phone, PhoneSession),
    ?assertEqual([], exceptions(Cdp)).

%% docs/design/site.md *The look*: no page the site writes scrolls sideways
%% on a phone, at 390 by 844, each read on the repository's own site as
%% make site writes it, the 404 page and the library's pages among them: a
%% block of code scrolls within itself, and a long run of inline code breaks
%% where it would leave its line. A page that does is named with the pixels
%% it is wider by. Each page's script throws nothing as it loads, and a page
%% whose script throws is named with what it threw: an exception stops the
%% steps of the script after it.
phone(#{cdp := Cdp, repository := Url, pages := Pages}) ->
    Phone = page(Cdp, {390, 844}, true),
    Read = [{Path, phone_read(Phone, Cdp, Url ++ "/" ++ Path)}
            || Path <- lists:sort(filelib:wildcard("**/*.html", Pages))],
    ?assertEqual([], [{Path, Width} || {Path, {Width, _}} <- Read, Width > 0]),
    ?assertEqual([], [{Path, Thrown} || {Path, {_, Thrown}} <- Read, Thrown =/= []]).

%% The pixels a page is wider than the phone's, once loaded, and what its
%% script threw meanwhile, each exception's description, the exceptions the
%% run kept before it left out.
phone_read(Phone, Cdp, Url) ->
    Before = length(exceptions(Cdp)),
    open(Phone, Url, {390, 844}),
    Width = lists:nth(2, eval(Phone, overflow("document.scrollingElement"))),
    {Width, [thrown(Exception) || Exception <- lists:nthtail(Before, exceptions(Cdp))]}.

%% An exception as the page's console would say it, or a request that
%% failed as it is kept.
thrown(#{<<"exceptionDetails">> := #{<<"exception">> := #{<<"description">> := Text}}}) ->
    Text;
thrown(#{<<"exceptionDetails">> := #{<<"text">> := Text}}) ->
    Text;
thrown(Other) ->
    Other.

%%
%% The world: the site with its stub client, httpd, and Chrome
%%

started() ->
    _ = file:del_dir_r(?SITE_BASE),
    Site = ern_site_tests:fixture_site(?SITE_BASE),
    {ok, _} = file:copy(?STUB, filename:join([Site, "shell", "client.js"])),
    Repository = ern_site_tests:repository_site(?SITE_BASE ++ "/repository"),
    ok = application:ensure_started(inets),
    {Httpd, Port} = served(Site),
    {Own, OwnPort} = served(Repository),
    {Chrome, Endpoint} = chrome_started(),
    Cdp = cdp_started(Endpoint),
    Page = page(Cdp, {1440, 900}, false),
    #{httpd => Httpd, own => Own, chrome => Chrome, cdp => Cdp, page => Page, site => Site,
      pages => Repository,
      url => "http://127.0.0.1:" ++ integer_to_list(Port),
      repository => "http://127.0.0.1:" ++ integer_to_list(OwnPort)}.

%% A site's pages served by an httpd of their own, and its port.
served(Pages) ->
    {ok, Httpd} = inets:start(httpd, [{port, 0}, {server_name, "browser"},
                                      {server_root, ?SITE_BASE},
                                      {document_root, Pages},
                                      {bind_address, {127, 0, 0, 1}},
                                      {directory_index, ["index.html"]},
                                      {modules, [mod_alias, mod_get, mod_head]},
                                      {mime_types, [{"html", "text/html"}, {"css", "text/css"},
                                                    {"js", "text/javascript"},
                                                    {"svg", "image/svg+xml"},
                                                    {"png", "image/png"}]}]),
    [{port, Port}] = httpd:info(Httpd, [port]),
    {Httpd, Port}.

stopped(#{httpd := Httpd, own := Own, chrome := Chrome, cdp := Cdp}) ->
    %% asked, not waited for: the browser may close before it answers
    Cdp ! {call, self(), <<"Browser.close">>, #{}, none},
    chrome_ended(Chrome),
    inets:stop(httpd, Httpd),
    inets:stop(httpd, Own).

%%
%% The stub client's sessions, as the page holds them
%%

%% The stub's session at its index, as the page's script names it.
stubbed(Index) ->
    "stub.sessions[" ++ integer_to_list(Index) ++ "]".

%% A session started at the panel's Start, and its index.
start(Page) ->
    Index = eval(Page, "window.stub?.sessions.length ?? 0"),
    eval(Page, "panel.start.click()"),
    connected(Page, Index).

%% The index, once the page has started a session there.
connected(Page, Index) ->
    until(Page, "window.stub?.sessions.length > " ++ integer_to_list(Index)),
    Index.

%% The keys the page gave the session since they were last read, once they
%% hold the bytes.
keys(Page, Index, Until) ->
    Session = stubbed(Index),
    Text = binary_to_list(iolist_to_binary(json:encode(Until))),
    until(Page, Session ++ ".keys.includes(" ++ Text ++ ")"),
    eval(Page, "(() => { const keys = " ++ Session ++ ".keys; " ++ Session ++ ".keys = '';"
               " return keys; })()").

%% Once the page has asked the session the ask: a resize, an extend or a
%% stop.
asked(Page, Index, Ask) ->
    until(Page, stubbed(Index) ++ ".asked.includes('" ++ Ask ++ "')").

%% What the server would tell the page, told through the stub's session.
told(Page, Index, Call) ->
    eval(Page, stubbed(Index) ++ "." ++ Call).

%% A session stopped by the panel's Stop, its stop asked and its end shown.
stop(Page, Index) ->
    eval(Page, "panel.stop.click()"),
    asked(Page, Index, "stop"),
    until(Page, state() ++ " === 'stopped'").

%%
%% The page's side
%%

%% A page loaded with nothing of the visitor's kept: the panel's layout,
%% its sizes and an input left waiting gone from the browser's storage.
fresh(Page, Url, Size) ->
    open(Page, Url, Size),
    eval(Page, "localStorage.clear()"),
    open(Page, Url, Size).

open(Page, Url, Size) ->
    resized(Page, Size),
    eval(Page, "window.leaving = true"),
    call(Page, <<"Page.navigate">>, #{url => list_to_binary(Url)}),
    until(Page, "!window.leaving && document.readyState === 'complete' && typeof panel ==="
                " 'object' && panel.element !== null").

%% The page given a size where it stands, as a window is resized.
resized(Page, {Width, Height}) ->
    call(Page, <<"Emulation.setDeviceMetricsOverride">>,
         #{width => Width, height => Height, deviceScaleFactor => 1,
           mobile => maps:get(mobile, Page)}).

%% The page drawn twice more, so that what a resize observer had to
%% measure by the next frame it has measured: a frame delivers its
%% observations after its animation frame's callbacks have run.
drawn(Page) ->
    eval(Page, "new Promise((resolve) => requestAnimationFrame(() =>"
               " requestAnimationFrame(() => resolve(true))))").

state() ->
    "document.querySelector('.panel-state').textContent".

%% The terminal's rows as text, each `|` ended, its empty rows left out.
rows() ->
    "([...document.querySelectorAll('.xterm-rows > div')].map((row) => row.textContent"
    ".replace(/\\u00a0/g, ' ').trimEnd()).filter((row) => row !== '').join(' | ') + ' |')".

overflow(Element) ->
    Found = case Element of
                "document." ++ _ -> Element;
                _ -> "document.querySelector('" ++ Element ++ "')"
            end,
    "(() => { const box = " ++ Found ++ "; return [box.scrollHeight - box.clientHeight,"
    " box.scrollWidth - box.clientWidth]; })()".

click_tool(Page, Block, Label) ->
    eval(Page, "document.querySelector('" ++ escaped(Block) ++ "').closest('.block')"
               ".querySelector('[aria-label=\"" ++ Label ++ "\"]').click()").

escaped(Text) ->
    lists:flatten(string:replace(Text, "'", "\\'", all)).

%% The value of an expression in the page, a promise's once it settles.
eval(Page, Expression) ->
    Reply = call(Page, <<"Runtime.evaluate">>,
                 #{expression => list_to_binary(Expression), awaitPromise => true,
                   returnByValue => true}),
    case Reply of
        #{<<"exceptionDetails">> := Details} -> error({page_exception, Expression, Details});
        #{<<"result">> := Result} -> maps:get(<<"value">>, Result, undefined)
    end.

%% A wait in the page itself: the condition read at each frame the
%% browser draws until it holds, within the time for one wait. A page that
%% then still answers was not busy, and the failure says where it stands
%% and what the condition says now: true means the wait stopped looking.
until(Page, Condition) ->
    try
        true = eval(Page, "new Promise((resolve) => { const test = () => { let holds = false;"
                          " try { holds = Boolean(" ++ Condition ++ "); } catch { } if (holds)"
                          " { resolve(true); } else { requestAnimationFrame(test); } }; test(); })")
    catch
        error:{devtools_did_not_answer, _} ->
            error({never_held, Condition,
                   eval(Page, "[location.href, document.title, document.readyState,"
                              " document.visibilityState, (() => { try { return Boolean("
                              ++ Condition ++ "); } catch { return 'throws'; } })()]")})
    end.

%% A wait for a page a navigation brings: one begun in the page that is
%% leaving is refused by DevTools when the next one arrives, and is begun
%% again there.
arrived(Page, Condition) ->
    try
        until(Page, Condition)
    catch
        error:{devtools, <<"Runtime.evaluate">>, _} -> until(Page, Condition)
    end.

key(Page, Key, Code) ->
    Common = #{key => list_to_binary(Key), code => list_to_binary(Key),
               windowsVirtualKeyCode => Code, nativeVirtualKeyCode => Code},
    call(Page, <<"Input.dispatchKeyEvent">>, Common#{type => <<"keyDown">>}),
    call(Page, <<"Input.dispatchKeyEvent">>, Common#{type => <<"keyUp">>}).

click(Page, X, Y) ->
    [call(Page, <<"Input.dispatchMouseEvent">>,
          #{type => Type, x => X, y => Y, button => <<"left">>, clickCount => 1})
     || Type <- [<<"mouseMoved">>, <<"mousePressed">>, <<"mouseReleased">>]].

%%
%% Chrome over its DevTools protocol
%%

%% Chrome, headless, its profile a directory of the run's own, its
%% DevTools on a port it chooses and says on its standard error. Google's
%% Chrome starts a component extension of its own some seconds in, and the
%% page that has just committed then loses its requests, its script among
%% them, so that none is started: version 157 needs both flags for that.
chrome_started() ->
    Profile = ern_helpers:tmp("ern_chrome_"),
    Port = open_port({spawn_executable, chrome()},
                     [{args, ["--headless=new", "--no-first-run", "--no-default-browser-check",
                              "--disable-gpu", "--remote-debugging-port=0",
                              "--disable-component-extensions-with-background-pages",
                              "--disable-extensions",
                              "--user-data-dir=" ++ Profile, "about:blank"]},
                      stderr_to_stdout, binary, exit_status]),
    {Port, endpoint(Port, <<>>)}.

endpoint(Port, Acc) ->
    receive
        {Port, {data, Bytes}} ->
            Got = <<Acc/binary, Bytes/binary>>,
            case re:run(Got, "DevTools listening on ws://([^/]+)(/[^\\s]+)",
                        [{capture, all_but_first, list}]) of
                {match, [Address, Path]} -> {Address, Path};
                nomatch -> endpoint(Port, Got)
            end;
        {Port, {exit_status, Status}} ->
            error({chrome_ended, Status, Acc})
    after ern_harness:wait_ms() ->
        error({chrome_said_no_endpoint, Acc})
    end.

%% Chrome's end, waited for: Browser.close asked it, and it is killed by
%% its process number where it has not ended within a wait.
chrome_ended(Port) ->
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    receive
        {Port, {exit_status, _}} -> ok
    after ern_harness:wait_ms() ->
        os:cmd("kill " ++ integer_to_list(Pid))
    end.

%% The DevTools client, a process of its own that holds the socket: a call
%% is answered at its id, and the page's exceptions are kept.
cdp_started({Address, Path}) ->
    [Host, PortText] = string:split(Address, ":"),
    Caller = self(),
    Cdp = spawn_link(fun() ->
                         {ok, Socket} = gen_tcp:connect(Host, list_to_integer(PortText),
                                                        [binary, {active, false}]),
                         Key = base64:encode(crypto:strong_rand_bytes(16)),
                         ok = gen_tcp:send(Socket, ["GET ", Path, " HTTP/1.1\r\nHost: ", Address,
                                                    "\r\nUpgrade: websocket\r\nConnection:"
                                                    " Upgrade\r\nSec-WebSocket-Key: ", Key,
                                                    "\r\nSec-WebSocket-Version: 13\r\n\r\n"]),
                         {_, Rest} = head(Socket, <<>>),
                         Caller ! {cdp_ready, self()},
                         ok = inet:setopts(Socket, [{active, once}]),
                         cdp(Socket, Rest, 1, #{}, [], #{})
                     end),
    receive {cdp_ready, Cdp} -> Cdp
    after ern_harness:wait_ms() -> error(no_devtools)
    end.

%% The head of the upgrade's response and what came after it.
head(Socket, Acc) ->
    case binary:split(Acc, <<"\r\n\r\n">>) of
        [Head, Rest] ->
            {Head, Rest};
        [_] ->
            {ok, Bytes} = gen_tcp:recv(Socket, 0),
            head(Socket, <<Acc/binary, Bytes/binary>>)
    end.

%% The page's exceptions are kept, and each request of the page's that
%% failed and was not canceled by a navigation, by its address, which the
%% requests sent name.
cdp(Socket, Buffer, Next, Waiting, Exceptions, Requests) ->
    case frame(Buffer) of
        {ok, 1, Payload, Rest} ->
            case json:decode(Payload) of
                #{<<"id">> := Id} = Reply ->
                    {From, Left} = maps:take(Id, Waiting),
                    From ! {cdp_reply, Id, Reply},
                    cdp(Socket, Rest, Next, Left, Exceptions, Requests);
                #{<<"method">> := <<"Runtime.exceptionThrown">>, <<"params">> := Params} ->
                    cdp(Socket, Rest, Next, Waiting, [Params | Exceptions], Requests);
                #{<<"method">> := <<"Network.requestWillBeSent">>,
                  <<"params">> := #{<<"requestId">> := Id,
                                    <<"request">> := #{<<"url">> := Url}}} ->
                    cdp(Socket, Rest, Next, Waiting, Exceptions, Requests#{Id => Url});
                #{<<"method">> := <<"Network.loadingFailed">>,
                  <<"params">> := #{<<"requestId">> := Id, <<"errorText">> := Why} = Params} ->
                    Failed = case maps:get(<<"canceled">>, Params, false) of
                                 true -> [];
                                 false -> [{failed, maps:get(Id, Requests, Id), Why}]
                             end,
                    cdp(Socket, Rest, Next, Waiting, Failed ++ Exceptions, Requests);
                _ ->
                    cdp(Socket, Rest, Next, Waiting, Exceptions, Requests)
            end;
        {ok, _, _, Rest} ->
            cdp(Socket, Rest, Next, Waiting, Exceptions, Requests);
        more ->
            receive
                {tcp, Socket, Bytes} ->
                    ok = inet:setopts(Socket, [{active, once}]),
                    cdp(Socket, <<Buffer/binary, Bytes/binary>>, Next, Waiting, Exceptions,
                        Requests);
                {tcp_closed, Socket} ->
                    ok;
                {call, From, Method, Params, Session} ->
                    Message = #{id => Next, method => Method, params => Params},
                    Sent = case Session of
                               none -> Message;
                               _ -> Message#{sessionId => Session}
                           end,
                    ok = gen_tcp:send(Socket, masked(json:encode(Sent))),
                    From ! {cdp_id, self(), Next},
                    cdp(Socket, Buffer, Next + 1, Waiting#{Next => From}, Exceptions, Requests);
                {exceptions, From} ->
                    From ! {exceptions, lists:reverse(Exceptions)},
                    cdp(Socket, Buffer, Next, Waiting, Exceptions, Requests)
            end
    end.

%% A call of the protocol's, on the browser or on a page's session: its
%% result, or the failure it answered.
call(#{cdp := Cdp, session := Session}, Method, Params) ->
    call(Cdp, Method, Params, Session).

call(Cdp, Method, Params, Session) ->
    Cdp ! {call, self(), Method, Params, Session},
    Id = receive {cdp_id, Cdp, Given} -> Given end,
    receive
        {cdp_reply, Id, #{<<"result">> := Result}} -> Result;
        {cdp_reply, Id, #{<<"error">> := Error}} -> error({devtools, Method, Error})
    after ern_harness:wait_ms() ->
        error({devtools_did_not_answer, Method})
    end.

exceptions(Cdp) ->
    Cdp ! {exceptions, self()},
    receive {exceptions, Found} -> Found end.

%% A page of the browser's, its session attached, at a size, a phone's
%% with touch. It keeps no response between loads, as the server's client
%% is served under no-store (ernest-httpd's design, *The client*), so that
%% a page loaded whole imports the client the server serves now.
page(Cdp, {Width, Height}, Mobile) ->
    #{<<"targetId">> := Target} = call(Cdp, <<"Target.createTarget">>,
                                       #{url => <<"about:blank">>}, none),
    #{<<"sessionId">> := Session} = call(Cdp, <<"Target.attachToTarget">>,
                                         #{targetId => Target, flatten => true}, none),
    Page = #{cdp => Cdp, session => Session, mobile => Mobile},
    call(Page, <<"Runtime.enable">>, #{}),
    call(Page, <<"Page.enable">>, #{}),
    call(Page, <<"Network.enable">>, #{}),
    call(Page, <<"Network.setCacheDisabled">>, #{cacheDisabled => true}),
    call(Page, <<"Emulation.setDeviceMetricsOverride">>,
         #{width => Width, height => Height, deviceScaleFactor => 1, mobile => Mobile}),
    Mobile andalso call(Page, <<"Emulation.setTouchEmulationEnabled">>,
                        #{enabled => true, maxTouchPoints => 5}),
    Page.

%%
%% The DevTools protocol's WebSocket frames, RFC 6455
%%

%% One frame of Chrome's read, unmasked as a server sends it: its opcode
%% and payload, and the bytes after it. A message of several frames is not
%% read whole, since the DevTools' messages here come in one each.
frame(<<_:4, Opcode:4, 0:1, Length:7, Rest/binary>>) ->
    case length_of(Length, Rest) of
        {ok, Size, After} ->
            case After of
                <<Payload:Size/binary, Left/binary>> -> {ok, Opcode, Payload, Left};
                _ -> more
            end;
        more ->
            more
    end;
frame(_) ->
    more.

length_of(126, <<Size:16, After/binary>>) -> {ok, Size, After};
length_of(127, <<Size:64, After/binary>>) -> {ok, Size, After};
length_of(Length, After) when Length < 126 -> {ok, Length, After};
length_of(_, _) -> more.

%% A text frame of a client's, masked.
masked(Iodata) ->
    Payload = iolist_to_binary(Iodata),
    <<A, B, C, D>> = Mask = crypto:strong_rand_bytes(4),
    Keys = {A, B, C, D},
    Hidden = << <<(Byte bxor element(1 + (Index rem 4), Keys))>>
                || {Index, Byte} <- lists:enumerate(0, binary_to_list(Payload)) >>,
    <<1:1, 0:3, 1:4, 1:1, (size_bits(byte_size(Payload)))/bitstring, Mask/binary, Hidden/binary>>.

size_bits(Size) when Size < 126 -> <<Size:7>>;
size_bits(Size) when Size < 65536 -> <<126:7, Size:16>>;
size_bits(Size) -> <<127:7, Size:64>>.
