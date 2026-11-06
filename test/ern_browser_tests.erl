%% The site's client in a browser, `make test-browser` (docs/proposals/site/
%% decisions.md, *The live shell*): a headless Chrome, driven over its
%% DevTools protocol, reads the fixture's pages, which OTP's httpd serves,
%% and its panel talks to a stub at the shell's path that speaks
%% ernest-httpd's protocol, its design's §11: the size, the attach's word,
%% the warning, an extend, a stop and the four close codes, each sent as
%% that server writes it. The stub answers no input as a shell does; what
%% the page sends it is what the test reads, and a real shell behind the
%% socket is a server's to show by hand before a release.
%%
%% One port takes the browser's connections: one to the shell's path goes
%% to the stub, and any other is carried to httpd, byte for byte both ways.
%% The run needs Chrome, which development.md names among what the tests
%% need; where none is found it says so and stops (run/0). It is no part of
%% make test or make test-full. Every test here was written after the code,
%% a regression test.
-module(ern_browser_tests).

-include_lib("eunit/include/eunit.hrl").

-export([run/0]).

-define(SITE_BASE, "build/browser").
-define(SHELL_PATH, <<"/shell/session">>).
-define(GUID, <<"258EAFA5-E914-47DA-95CA-C5AB0DC85B11">>).

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

client_test_() ->
    {setup, fun started/0, fun stopped/1,
     fun(World) ->
         [{timeout, 120, {Name, fun() -> checked(Check, World) end}} || {Name, Check} <- checks()]
     end}.

%% A check, the stub telling this process what the page sent it.
checked(Check, World) ->
    persistent_term:put({?MODULE, test}, self()),
    Check(World).

checks() ->
    [{"the panel and a session", fun session/1},
     {"Paste, Load and a transcript's Paste", fun pastes/1},
     {"the example's Try it", fun example/1},
     {"the navigation that keeps the panel", fun navigation/1},
     {"a page still on its way", fun on_its_way/1},
     {"a whole load and a joined session", fun joined/1},
     {"Hide, the handle and F6", fun keyboard/1},
     {"Stop, Start and Restart", fun ends/1},
     {"the warning and an expiry's notice", fun expiry/1},
     {"the other close codes", fun closes/1},
     {"a paste waits for the first output", fun waiting/1},
     {"the shell's page and a phone", fun pages/1}].

%% docs/proposals/site/decisions.md *The live shell*: no panel opens until
%% the visitor asks; the header's beside button opens it, pressed, and puts
%% the focus in the terminal; the bar names no state before a session, and
%% Start connects, the panel's size its first message, the attach's word
%% `new` answered by nothing of the client's, then running; the terminal
%% fills the panel with no scrollbar of its own.
session(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    ?assert(eval(Page, "document.querySelector('.shell-panel').hidden")),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside') && document"
                       ".querySelector('.panel-toggle .beside').getAttribute('aria-pressed')"
                       " === 'true'")),
    ?assertEqual(<<>>, eval(Page, state())),
    ?assertEqual(<<"status">>, eval(Page, "document.querySelector('.panel-state').role")),
    Conn = start(Page),
    {text, #{<<"resize">> := [Rows, Columns]}} = first_message(Conn),
    ?assert(Rows > 0 andalso Columns > 0),
    until(Page, state() ++ " === 'running'"),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assert(eval(Page, "document.activeElement.classList.contains('xterm-helper-textarea')")),
    ?assertEqual([0, 0], eval(Page, overflow(".panel-terminal"))),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell*: a block's Paste
%% sends it as one input, bracketed as the shell asked the terminal, and
%% nothing after it; a Load the same, then Enter and `main()`, typed and
%% not entered; a transcript's input its own Paste, its prompt left out; and
%% a long input's Paste stands at the block's visible right edge.
pastes(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Conn = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    Pasted = keys(Conn, <<"\e[201~">>),
    ?assertEqual(<<"\e[200~fn double(value : Int) : Int =\r    value * 2\e[201~">>, Pasted),
    click_tool(Page, "pre.code[data-shell=\"load\"]", "Load into the shell"),
    ?assertEqual(<<"\e[200~export fn main() : Unit =\r    Io.println(\"hello, world\")\e[201~"
                   "\rmain()">>, keys(Conn, <<"\rmain()">>)),
    eval(Page, "document.querySelector('pre.transcript[data-shell=\"paste\"] .line-paste')"
               ".click()"),
    ?assertEqual(<<"\e[200~1 + 2\e[201~">>, keys(Conn, <<"\e[201~">>)),
    Edge = eval(Page, "(() => { const button = [...document.querySelectorAll('.line-paste')]"
                      ".at(-1); const pre = button.closest('pre'); const at = button"
                      ".getBoundingClientRect(), box = pre.getBoundingClientRect(); return"
                      " [pre.scrollWidth > pre.clientWidth, at.right <= box.right + 0.5,"
                      " at.left >= box.left]; })()"),
    ?assertEqual([true, true, true], Edge),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The homepage*: the example's button,
%% Try it, puts the example's code into the shell, opening the panel and
%% starting a session, and its label never changes.
example(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/", {1440, 900}),
    Code = eval(Page, "document.querySelector('.home-use pre.code').textContent"),
    eval(Page, "[...document.querySelectorAll('button')].find((button) => button.textContent"
               " === 'Try it').click()"),
    Conn = connected(),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside')")),
    Typed = binary:replace(string:trim(Code, trailing), <<"\n">>, <<"\r">>, [global]),
    ?assertEqual(<<"\e[200~", Typed/binary, "\e[201~">>, keys(Conn, <<"\e[201~">>)),
    ?assert(eval(Page, "[...document.querySelectorAll('button')].some((button) =>"
                       " button.textContent === 'Try it')")),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell*: while the panel is
%% open a link fetches its page and puts its main in place, the panel, its
%% socket and its screen kept; the new page's blocks have their tools, the
%% header marks its room, it starts at its top, the next Tab reaches the
%% skip link and its title is said; back returns to the page and its
%% scroll, forward again, and a link to another page's anchor puts it in
%% view.
navigation(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Conn = start(Page),
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
    ?assertEqual(none, receive {stub_connected, _} -> another after 0 -> none end),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell*: back and forward go
%% where the visitor last asked. A move made while a page is on its way
%% fetches its own, even the page that still shows, and the one it replaced
%% is dropped, its failure with it. The fetches are held here, so that the
%% order is the test's.
on_its_way(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
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

%% docs/proposals/site/decisions.md *The live shell*, ernest-httpd's design
%% §11: a page loaded whole opens the panel as it was kept; a session the
%% server says this browser joined, `{"attached": "joined"}`, is asked to
%% draw its line again, C-l, and a paste into it is bracketed by the page
%% itself, since its shell asked an earlier terminal.
joined(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"joined">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    open(Page, Url ++ "/guide/1.html", {1440, 900}),
    ?assert(eval(Page, "document.body.classList.contains('panel-beside') && !document"
                       ".querySelector('.shell-panel').hidden")),
    Conn = start(Page),
    ?assertEqual(<<12>>, keys(Conn, <<12>>)),
    until(Page, rows() ++ ".includes('again')"),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(Conn, <<"\e[201~">>)),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell*: Hide hides the panel
%% and keeps the session, the header's button marked with a dot and the
%% focus given back to it, and a link keeps the hidden session's page; the
%% handle is a separator the arrow keys move; F6 in the terminal moves the
%% focus to the panel's controls.
keyboard(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Conn = start(Page),
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
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell*: Stop sends
%% `{"stop": true}`, and the server's 4004 is `stopped`, marked in the
%% terminal in the bar's word, which then takes no keys; Start after an end
%% begins below the ended screen, and Restart, a stop and a new session,
%% on a clear one.
ends(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    First = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    stop(Page, First),
    until(Page, rows() ++ ".endsWith('stopped |')"),
    ?assert(eval(Page, "session.terminal.options.disableStdin")),
    ?assertEqual(<<"Start">>, eval(Page, "panel.start.textContent")),
    Second = start(Page),
    {text, #{<<"resize">> := _}} = first_message(Second),
    until(Page, state() ++ " === 'running' && " ++ rows() ++ ".includes('stopped')"),
    eval(Page, "panel.start.click()"),
    ?assertEqual(#{<<"stop">> => true}, next_text(Second, <<"stop">>)),
    Third = connected(),
    {text, #{<<"resize">> := _}} = first_message(Third),
    until(Page, state() ++ " === 'running' && !" ++ rows() ++ ".includes('stopped')"),
    stop(Page, Third).

%% docs/proposals/site/decisions.md *The live shell*: the server's warning,
%% `{"warning": seconds}`, is a banner that says the seconds once, and
%% Extend sends `{"extend": true}` and takes it down; an expiry, 4001,
%% closes the panel and gives the page its width, the layout kept as it
%% was, and the notice at the window's bottom says why with an icon that
%% opens the shell and one that closes it, closed by a click anywhere or
%% by Escape outside the terminal.
expiry(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    Conn = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    say(Conn, #{<<"warning">> => 60}),
    until(Page, "!document.querySelector('.panel-warning').hidden"),
    ?assertEqual(<<"alert">>, eval(Page, "document.querySelector('.panel-warning').role")),
    ?assertEqual(<<"The session ends in 60 seconds.Extend">>,
                 eval(Page, "document.querySelector('.panel-warning').textContent")),
    eval(Page, "document.querySelector('.panel-warning button').click()"),
    ?assertEqual(#{<<"extend">> => true}, next_text(Conn, <<"extend">>)),
    ?assert(eval(Page, "document.querySelector('.panel-warning').hidden")),
    close(Conn, 4001),
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

%% docs/proposals/site/decisions.md *The live shell*, ernest-httpd's design
%% §11 and §12: 4002 is `taken over` and 4003 `unavailable`, each shown in
%% the panel, and a connection that drops is `disconnected`.
closes(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    eval(Page, "document.querySelector('.panel-toggle .beside').click()"),
    lists:foreach(fun({Code, Word}) ->
                      Conn = start(Page),
                      until(Page, state() ++ " === 'running'"),
                      case Code of
                          dropped -> Conn ! drop;
                          _ -> close(Conn, Code)
                      end,
                      until(Page, state() ++ " === '" ++ Word ++ "'"),
                      until(Page, rows() ++ ".endsWith('" ++ Word ++ " |')"),
                      ?assertNot(eval(Page, "document.querySelector('.shell-panel').hidden"))
                  end, [{4002, "taken over"}, {4003, "unavailable"}, {dropped, "disconnected"}]).

%% docs/proposals/site/decisions.md *The live shell*: a paste for a session
%% that is starting waits for the session's first output, as a person
%% waits for the prompt, and goes once it comes.
waiting(#{page := Page, url := Url}) ->
    stub_mode(#{attach => <<"new">>, prompt => held}),
    fresh(Page, Url ++ "/guide/1.html", {1440, 900}),
    click_tool(Page, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    Conn = connected(),
    {text, #{<<"resize">> := _}} = first_message(Conn),
    until(Page, state() ++ " === 'running'"),
    ?assertEqual(none, next_message(Conn, 0)),
    Conn ! prompt,
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(Conn, <<"\e[201~">>)),
    stop(Page, Conn).

%% docs/proposals/site/decisions.md *The live shell* and *The other pages*:
%% the shell's page holds the panel in its frame and scrolls in neither
%% direction, its terminal filling what the page leaves; on a phone no
%% panel is offered, no page scrolls sideways, and a Paste opens the
%% shell's page with the input arriving there.
pages(#{page := Page, url := Url, cdp := Cdp}) ->
    stub_mode(#{attach => <<"new">>}),
    fresh(Page, Url ++ "/shell/", {1440, 900}),
    ?assertEqual([0, 0], eval(Page, overflow("document.scrollingElement"))),
    Conn = start(Page),
    until(Page, rows() ++ ".includes('session 1')"),
    ?assertEqual([0, 0], eval(Page, overflow(".panel-terminal"))),
    ?assertEqual([0, 0], eval(Page, overflow("document.scrollingElement"))),
    ?assert(eval(Page, "document.querySelector('.panel-toggle').hidden")),
    stop(Page, Conn),
    Phone = page(Cdp, {390, 844}, true),
    fresh(Phone, Url ++ "/guide/1.html", {390, 844}),
    ?assertNot(eval(Phone, "getComputedStyle(document.querySelector('.panel-toggle')).display"
                           " !== 'none'")),
    ?assertEqual(0, lists:nth(2, eval(Phone, overflow("document.scrollingElement")))),
    click_tool(Phone, "pre.code[data-shell=\"paste\"]", "Paste into the shell"),
    %% The connection first: a wait begun in the page that is leaving is
    %% refused by DevTools when the next one arrives, and only the shell's
    %% page connects.
    PhoneConn = connected(),
    until(Phone, "location.pathname === '/shell/' && document.readyState === 'complete'"),
    ?assertMatch(<<"\e[200~fn double", _/binary>>, keys(PhoneConn, <<"\e[201~">>)),
    ?assertEqual(0, lists:nth(2, eval(Phone, overflow("document.scrollingElement")))),
    stop(Phone, PhoneConn),
    ?assertEqual([], exceptions(Cdp)).

%%
%% The world: the site, httpd, the front port with its stub, and Chrome
%%

started() ->
    _ = file:del_dir_r(?SITE_BASE),
    Site = ern_site_tests:fixture_site(?SITE_BASE),
    ok = application:ensure_started(inets),
    {ok, Httpd} = inets:start(httpd, [{port, 0}, {server_name, "browser"},
                                      {server_root, ?SITE_BASE},
                                      {document_root, Site},
                                      {bind_address, {127, 0, 0, 1}},
                                      {directory_index, ["index.html"]},
                                      {modules, [mod_alias, mod_get, mod_head]},
                                      {mime_types, [{"html", "text/html"}, {"css", "text/css"},
                                                    {"js", "text/javascript"},
                                                    {"svg", "image/svg+xml"},
                                                    {"png", "image/png"}]}]),
    [{port, HttpdPort}] = httpd:info(Httpd, [port]),
    {ok, Listener} = gen_tcp:listen(0, [binary, {active, false}, {ip, {127, 0, 0, 1}},
                                        {reuseaddr, true}]),
    {ok, Port} = inet:port(Listener),
    Front = spawn(fun() -> front(Listener, HttpdPort) end),
    ok = gen_tcp:controlling_process(Listener, Front),
    {Chrome, Endpoint} = chrome_started(),
    Cdp = cdp_started(Endpoint),
    persistent_term:put({?MODULE, cdp}, Cdp),
    Page = page(Cdp, {1440, 900}, false),
    #{httpd => Httpd, front => Front, chrome => Chrome, cdp => Cdp, page => Page,
      url => "http://127.0.0.1:" ++ integer_to_list(Port)}.

stopped(#{httpd := Httpd, front := Front, chrome := Chrome, cdp := Cdp}) ->
    %% asked, not waited for: the browser may close before it answers
    Cdp ! {call, self(), <<"Browser.close">>, #{}, none},
    chrome_ended(Chrome),
    exit(Front, kill),
    inets:stop(httpd, Httpd).

%%
%% The front: the shell's path to the stub, the rest to httpd
%%

front(Listener, HttpdPort) ->
    {ok, Socket} = gen_tcp:accept(Listener),
    Handler = spawn(fun() -> receive go -> connection(Socket, HttpdPort) end end),
    ok = gen_tcp:controlling_process(Socket, Handler),
    Handler ! go,
    front(Listener, HttpdPort).

connection(Socket, HttpdPort) ->
    {Head, Rest} = head(Socket, <<>>),
    case binary:split(Head, <<" ">>, [global]) of
        [<<"GET">>, ?SHELL_PATH | _] -> stub(Socket, Head, Rest);
        _ -> carried(Socket, Head, Rest, HttpdPort)
    end.

%% A request's head and what came after it; a connection the browser
%% opened ahead and closed unused has none.
head(Socket, Acc) ->
    case binary:split(Acc, <<"\r\n\r\n">>) of
        [Head, Rest] ->
            {Head, Rest};
        [_] ->
            case gen_tcp:recv(Socket, 0) of
                {ok, Bytes} -> head(Socket, <<Acc/binary, Bytes/binary>>);
                {error, _} -> exit(normal)
            end
    end.

%% A connection carried to httpd as it came, each way until either closes.
carried(Socket, Head, Rest, HttpdPort) ->
    {ok, Httpd} = gen_tcp:connect({127, 0, 0, 1}, HttpdPort, [binary, {active, false}]),
    ok = gen_tcp:send(Httpd, [Head, "\r\n\r\n", Rest]),
    Back = spawn_link(fun() -> relayed(Httpd, Socket) end),
    ok = gen_tcp:controlling_process(Httpd, Back),
    relayed(Socket, Httpd).

relayed(From, To) ->
    case gen_tcp:recv(From, 0) of
        {ok, Bytes} ->
            case gen_tcp:send(To, Bytes) of
                ok -> relayed(From, To);
                {error, _} -> gen_tcp:close(From)
            end;
        {error, _} ->
            gen_tcp:close(To)
    end.

%%
%% The stub: ernest-httpd's protocol, design §11, with no shell behind it
%%

%% How the next connection behaves: the attach's word it says, and whether
%% it holds its prompt until told.
stub_mode(Mode) ->
    persistent_term:put({?MODULE, mode}, Mode).

stub(Socket, Head, Rest) ->
    {match, [Key]} = re:run(Head, "Sec-WebSocket-Key: *([^\r\n]+)", [{capture, all_but_first,
                                                                       binary}, caseless]),
    Accept = base64:encode(crypto:hash(sha, <<Key/binary, ?GUID/binary>>)),
    ok = gen_tcp:send(Socket, ["HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
                               "Connection: Upgrade\r\nSec-WebSocket-Accept: ", Accept,
                               "\r\n\r\n"]),
    Mode = persistent_term:get({?MODULE, mode}),
    tell({stub_connected, self()}),
    ok = inet:setopts(Socket, [{active, once}]),
    served(#{socket => Socket, mode => Mode, attached => false}, Rest).

%% What the stub tells the check that runs.
tell(Message) ->
    persistent_term:get({?MODULE, test}) ! Message.

served(Stub, Buffer) ->
    case frame(Buffer) of
        {ok, Opcode, Payload, Rest} ->
            case message(Stub, Opcode, Payload) of
                closed -> ok;
                Next -> served(Next, Rest)
            end;
        more ->
            #{socket := Socket} = Stub,
            receive
                {tcp, Socket, Bytes} ->
                    ok = inet:setopts(Socket, [{active, once}]),
                    served(Stub, <<Buffer/binary, Bytes/binary>>);
                {tcp_closed, Socket} ->
                    ok;
                {say, Message} ->
                    served(said(Stub, Message), Buffer);
                prompt ->
                    served(prompted(Stub), Buffer);
                {close, Code} ->
                    ok = gen_tcp:send(Socket, encoded(8, <<Code:16>>)),
                    gen_tcp:close(Socket);
                drop ->
                    gen_tcp:close(Socket)
            end
    end.

%% A message from the page: its first resize attaches, the attach's word
%% said as Json.format writes it, then the prompt where the mode does not
%% hold it; a stop closes with 4004; keys are read, and C-l draws the line
%% again. Each is told the test.
message(Stub, 1, Payload) ->
    Message = json:decode(Payload),
    tell({stub_text, self(), Message}),
    case Message of
        #{<<"resize">> := _} when not map_get(attached, Stub) ->
            #{mode := #{attach := Word} = Mode} = Stub,
            Said = said(Stub#{attached := true}, #{<<"attached">> => Word}),
            case {Word, maps:get(prompt, Mode, shown)} of
                {<<"new">>, shown} -> prompted(Said);
                _ -> Said
            end;
        #{<<"stop">> := true} ->
            #{socket := Socket} = Stub,
            ok = gen_tcp:send(Socket, encoded(8, <<4004:16>>)),
            gen_tcp:close(Socket),
            closed;
        _ ->
            Stub
    end;
message(#{socket := Socket} = Stub, 2, Payload) ->
    tell({stub_keys, self(), Payload}),
    case Payload of
        <<12>> -> ok = gen_tcp:send(Socket, encoded(2, <<"\r\e[Jdrawn again\r\n> ">>));
        _ -> ok
    end,
    Stub;
message(#{socket := Socket}, 8, _) ->
    gen_tcp:close(Socket),
    closed;
message(#{socket := Socket} = Stub, 9, Payload) ->
    ok = gen_tcp:send(Socket, encoded(10, Payload)),
    Stub;
message(Stub, _, _) ->
    Stub.

%% A text message as ernest-httpd writes one, Json.format's layout, the
%% members spaced and a line feed after (design §11).
said(#{socket := Socket} = Stub, Message) ->
    [{Name, Value}] = maps:to_list(Message),
    Text = iolist_to_binary(["{ ", json:encode(Name), ": ", json:encode(Value), " }\n"]),
    ok = gen_tcp:send(Socket, encoded(1, Text)),
    Stub.

prompted(#{socket := Socket} = Stub) ->
    ok = gen_tcp:send(Socket, encoded(2, <<"\e[?2004hErnest 9.9.9, session 1. :help for help."
                                           "\r\n> ">>)),
    Stub.

%% What the stub was sent of the test's: a connection, its first message,
%% and each after.
connected() ->
    receive {stub_connected, Conn} -> Conn
    after ern_nodes_tests:wait_ms() -> error({no_connection, exceptions(cdp())})
    end.

cdp() ->
    persistent_term:get({?MODULE, cdp}).

first_message(Conn) ->
    next_message(Conn).

next_message(Conn) ->
    case next_message(Conn, ern_nodes_tests:wait_ms()) of
        none -> error({no_message, Conn});
        Message -> Message
    end.

next_message(Conn, Ms) ->
    receive
        {stub_text, Conn, Message} -> {text, Message};
        {stub_keys, Conn, Keys} -> {keys, Keys}
    after Ms -> none
    end.

%% The keys the stub was sent, from the next on, up to the first that
%% holds the bytes.
keys(Conn, Until) ->
    keys(Conn, Until, <<>>).

keys(Conn, Until, Acc) ->
    receive
        {stub_keys, Conn, Keys} ->
            Got = <<Acc/binary, Keys/binary>>,
            case binary:match(Got, Until) of
                nomatch -> keys(Conn, Until, Got);
                _ -> Got
            end;
        {stub_text, Conn, _} ->
            keys(Conn, Until, Acc)
    after ern_nodes_tests:wait_ms() ->
        error({keys_short_of, Until, Acc})
    end.

say(Conn, Message) ->
    Conn ! {say, Message}.

close(Conn, Code) ->
    Conn ! {close, Code}.

%% A session started at the panel's Start, and its connection.
start(Page) ->
    eval(Page, "panel.start.click()"),
    connected().

%% A session stopped by the panel's Stop, its stop read and its close
%% shown.
stop(Page, Conn) ->
    eval(Page, "panel.stop.click()"),
    until_stopped(Conn),
    until(Page, state() ++ " === 'stopped'").

until_stopped(Conn) ->
    #{<<"stop">> := true} = next_text(Conn, <<"stop">>).

%% The next text message of the page's that holds the member, a resize
%% of the panel's along the way passed over.
next_text(Conn, Member) ->
    case next_message(Conn) of
        {text, #{Member := _} = Message} -> Message;
        _ -> next_text(Conn, Member)
    end.

%%
%% The page's side
%%

%% A page loaded with nothing of the visitor's kept: the panel's layout,
%% its sizes and an input left waiting gone from the browser's storage.
fresh(Page, Url, Size) ->
    open(Page, Url, Size),
    eval(Page, "localStorage.clear()"),
    open(Page, Url, Size).

open(Page, Url, {Width, Height}) ->
    call(Page, <<"Emulation.setDeviceMetricsOverride">>,
         #{width => Width, height => Height, deviceScaleFactor => 1,
           mobile => maps:get(mobile, Page)}),
    eval(Page, "window.leaving = true"),
    call(Page, <<"Page.navigate">>, #{url => list_to_binary(Url)}),
    until(Page, "!window.leaving && document.readyState === 'complete' && typeof panel ==="
                " 'object' && panel.element !== null").

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
%% then still answers was not busy: the condition never held, and the
%% failure says so with where the page stands.
until(Page, Condition) ->
    try
        true = eval(Page, "new Promise((resolve) => { const test = () => { let holds = false;"
                          " try { holds = Boolean(" ++ Condition ++ "); } catch { } if (holds)"
                          " { resolve(true); } else { requestAnimationFrame(test); } }; test(); })")
    catch
        error:{devtools_did_not_answer, _} ->
            error({never_held, Condition,
                   eval(Page, "[location.href, document.title, document.readyState]")})
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
%% DevTools on a port it chooses and says on its standard error.
chrome_started() ->
    Profile = filename:join(ern_pty:run_dir(),
                            "ern_chrome_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_dir(Profile ++ "/"),
    Port = open_port({spawn_executable, chrome()},
                     [{args, ["--headless=new", "--no-first-run", "--no-default-browser-check",
                              "--disable-gpu", "--remote-debugging-port=0",
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
    after ern_nodes_tests:wait_ms() ->
        error({chrome_said_no_endpoint, Acc})
    end.

%% Chrome's end, waited for: Browser.close asked it, and it is killed by
%% its process number where it has not ended within a wait.
chrome_ended(Port) ->
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    receive
        {Port, {exit_status, _}} -> ok
    after ern_nodes_tests:wait_ms() ->
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
    after ern_nodes_tests:wait_ms() -> error(no_devtools)
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
    after ern_nodes_tests:wait_ms() ->
        error({devtools_did_not_answer, Method})
    end.

exceptions(Cdp) ->
    Cdp ! {exceptions, self()},
    receive {exceptions, Found} -> Found end.

%% A page of the browser's, its session attached, at a size, a phone's
%% with touch.
page(Cdp, {Width, Height}, Mobile) ->
    #{<<"targetId">> := Target} = call(Cdp, <<"Target.createTarget">>,
                                       #{url => <<"about:blank">>}, none),
    #{<<"sessionId">> := Session} = call(Cdp, <<"Target.attachToTarget">>,
                                         #{targetId => Target, flatten => true}, none),
    Page = #{cdp => Cdp, session => Session, mobile => Mobile},
    call(Page, <<"Runtime.enable">>, #{}),
    call(Page, <<"Page.enable">>, #{}),
    call(Page, <<"Network.enable">>, #{}),
    call(Page, <<"Emulation.setDeviceMetricsOverride">>,
         #{width => Width, height => Height, deviceScaleFactor => 1, mobile => Mobile}),
    Mobile andalso call(Page, <<"Emulation.setTouchEmulationEnabled">>,
                        #{enabled => true, maxTouchPoints => 5}),
    Page.

%%
%% WebSocket frames, RFC 6455
%%

%% One frame read: its opcode and payload, unmasked where it came masked,
%% and the bytes after it. A message of several frames is not read whole,
%% since the browser's and the DevTools' messages here come in one each.
frame(<<_:4, Opcode:4, Masked:1, Length:7, Rest/binary>>) ->
    case length_of(Length, Rest) of
        {ok, Size, After} ->
            MaskSize = Masked * 4,
            case After of
                <<Mask:MaskSize/binary, Payload:Size/binary, Left/binary>> ->
                    {ok, Opcode, unmasked(Payload, Mask), Left};
                _ ->
                    more
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

unmasked(Payload, <<>>) ->
    Payload;
unmasked(Payload, <<A, B, C, D>>) ->
    Keys = {A, B, C, D},
    << <<(Byte bxor element(1 + (Index rem 4), Keys))>>
       || {Index, Byte} <- lists:enumerate(0, binary_to_list(Payload)) >>.

%% A frame of the server's, unmasked, and one of a client's, masked.
encoded(Opcode, Payload) ->
    <<1:1, 0:3, Opcode:4, 0:1, (size_bits(byte_size(Payload)))/bitstring, Payload/binary>>.

masked(Iodata) ->
    Payload = iolist_to_binary(Iodata),
    Mask = crypto:strong_rand_bytes(4),
    <<1:1, 0:3, 1:4, 1:1, (size_bits(byte_size(Payload)))/bitstring, Mask/binary,
      (unmasked(Payload, Mask))/binary>>.

size_bits(Size) when Size < 126 -> <<Size:7>>;
size_bits(Size) when Size < 65536 -> <<126:7, Size:16>>;
size_bits(Size) -> <<127:7, Size:64>>.
