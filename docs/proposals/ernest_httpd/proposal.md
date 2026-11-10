# The server owns both ends of its socket

Decided with the user on 2026-11-09 and planned as MVP 4.6, after the launch, and moved before it on 2026-11-10 (the log's *MVP 4.6 Before the Launch*). Nothing here is authoritative. It states Ernest's side and what Ernest asks of ernest-httpd. The server's side is its own sessions' to design ([`docs/clean_room.md`](../../clean_room.md)).

The server's design is https://github.com/joagre/ernest-httpd/blob/main/docs/design.md, cited below as the server's design. It is read from here and never written.

## What stands today

ernest-httpd is built on a floor of Ernest. That is a dependency of the ordinary kind.

Ernest's repository holds the site, and the site knows the server in three places.

- **The wire.** `site/root/assets/js/site.js` opens the WebSocket and speaks the server's messages: `{"resize": [rows, columns]}`, `{"extend": true}`, `{"stop": true}`, the warning, the word that a session was joined, and the close codes 4001 to 4004.
- **The configuration.** `tools/site.ern` reads the server's configuration file. It takes the `shell` member's `path`, `lifetime`, `warning`, `most-at-once` and `starts`, and reads the container's memory out of `shell.command`'s `--memory`. `make site` takes the file as `CONFIG`.
- **The stub.** `test/ern_browser_tests.erl` holds a stub socket that speaks the server's protocol.

So a release of Ernest holds a site written for one version of the server, and the server is built on one floor of Ernest. Neither `ern`, the libraries nor `make test` needs the server. The cycle is the site's.

Each of the three is a fact of the server's that stands a second time in Ernest. The server's design owns the messages, the configuration's form and the command, and Ernest's files restate them.

The server holds a client of its own besides, its example site's `examples/site/root/shell.js`, which its log calls the protocol's reference client. So the wire stands in script twice, once in each repository.

## The line

What a page says and how it looks is Ernest's. What the socket says and what the server enforces is the server's, at both ends.

The panel, the terminal, the buttons on a block, the navigation that keeps the panel and the wording of every state stay in `site.js`. The socket, its messages and its codes leave it.

The log's *WebSocket Is the Server's* drew the same line for the frames: a protocol one program speaks is that program's own. This draws it for the page's end of that protocol.

## What Ernest asks of ernest-httpd

Four things, each the server's to design and to state in its own design. The server's session reads nothing of this repository, so the message that carries the ask carries this section whole, and the section cites no file of Ernest's.

1. **A client.** A script the server ships and serves on the site's own host, at the path the site names for it, `/shell/client.js`, which the operator writes into the server's configuration. It holds no element of a page and no terminal.

   It opens the socket and speaks the messages. It offers a session by what it means: start with a size, keys, a resize, extend, stop. It tells output, the session attached and whether this browser joined it, the warning with the milliseconds left, and each end by its name: expired, taken over, unavailable, stopped, or lost, which is every other close. A stop asked for before the session is attached is the client's to order.
2. **The limits.** The client answers the limits the server enforces, without a session: the lifetime without a key, the warning before the end, the most sessions at once, and the starts an address may make and their window.
3. **Never stale.** A page loaded whole runs the client of the server it talks to, and never one a browser kept from the server before it.
4. **Its own test.** The client against a server the test starts itself, on the machine it runs on, in the server's repository.

The client's interface is then the one thing the two share, stated in the server's design, its section *The client*, and cited from the site's design note by that address. Decision 7 states it as agreed.

## What changes in Ernest

**`site.js`.** The session's part imports the client, an ES module, from `/shell/client.js`, a path it names once, when a session is first started; the shell's page imports it at its load, for its numbers. A page the panel's navigation keeps is one document, so the client is fetched once for it. It names no WebSocket, no message and no close code. The seven states stay, and the page words each: connecting from the page's start of a session, running from the client's word that it is attached, and the five ends the client names. A terminal or a client that does not load is *disconnected*, as a lost connection is.

**The generator.** `tools/site.ern` takes no configuration and nothing in its place: `site root out version tag`. `Shell`, `shellRead`, `member`, `integer`, `memoryOf`, `megabytes` and the use of `Json` go, and `spoken` goes to the script. `data-shell-path` and `data-lifetime` go from the script's element, with `base.html`'s two tokens and `Site.Run.Run`'s two fields for them.

**The shell's page.** `shell.html` loses its six numbers and its tokens. Its list says each rule in words, each sentence whole without a number, and the script writes five numbers into it from the client's limits. The sentence on the container names no memory: a container of its own, with no network, removed when the session ends. The notice at an expiry takes the lifetime from the client too.

**`make site`.** `CONFIG` goes, and `make site` takes the tag alone. `libs/json` leaves what the generator's build needs.

**The browser test.** The fixture serves a stub client at `/shell/client.js`, a module with the client's interface whose states the test sets. The stub socket goes, with the front port that parted the shell's path from the pages and the frames' codec. The test still holds the panel, the paste, the states and the navigation in a browser, and it now holds the shell page's numbers.

**The design note.** `docs/design/site.md` changes in five sections.

- *The root* lists `/shell/client.js` as an address the server serves, no file of the site's, and `/assets/js/` holds no session client.
- *The other pages* says the limits' numbers are the running server's.
- *The templates* loses its sentence on the configuration file.
- *The generation* loses the refusal of a configuration with no `shell` and the fixture's configuration. Three of its sentences take an exception: everything comes from the tag, but the client; a script is named by its digest, but the client; and a page's text is complete without a script, but the shell page's numbers.
- *The live shell* cites the server's design for the client's interface alone. Its sentences on the messages' forms, the codes, `shell.path` and the stub socket go.

**The release.** `docs/reviews/release.md` keeps the check by hand of the panel against a real shell on a server, since the test's client is a stub. A handover of the site gives the tag alone, and no configuration.

**The sweep.** The same commit changes every place that names the configuration or the stub socket: `site/templates/README.md`'s rows for `base.html` and `shell.html` and its line on `data-shell-path`, `docs/architecture.md`'s three paragraphs on the generator and its tests, `docs/development.md`'s four, the `Makefile`'s `site` and `tools`, `test/Makefile`, `test/ern_site_tests.erl`, `test/ern_site_shell_tests.erl`, and the fixture, whose `config.json` goes and whose expected pages are written again.

## The order

It is built before the launch, the server's part first.

1. The ask goes to the server's session by a message, on the user's word. The server's part adds and takes nothing away: a server that serves the client and answers the limits still speaks the wire to the site as it stands, so it goes into the release the server makes for the launch, and the server's rehearsal of the switch serves the client on scratch ports.
2. Ernest's side is built against the rehearsal's server once it serves the client, and goes live with the launch's switch.
3. The switch is the one day both repositories change, on the path the rehearsal walked.

The wire is then the server's alone, to keep or to change.

## What it buys

- Ernest's code reads no format of the server's: no message, no code, no member of its configuration, no flag of its command.
- The server changes its wire, its configuration and its container's command without a commit in Ernest.
- A site built from a tag is the same on any server that serves a client. It is built for no one configuration.
- The limits a visitor reads are the running server's, where today they are those of the file the site was built with.

## What it costs

**In Ernest.** `spoken`, which says a time in words, moves from Ernest to the page's script, since the numbers come when the page is read. The shell page's numbers leave `make test-site`, which `make test` runs, for `make test-browser`, which runs before a release. A site served by another server for a look shows the shell's page without its numbers. The page no longer says a container's memory.

**In the server**, named here and designed there. Its release holds a script, where it holds Ernest alone today. It answers a request with something that is no file of its root, the client and the limits, where its design's *What the program does* and *The static site* have files and one socket. Its configuration gains the client's path. Its test of a script needs a browser, as Ernest's does, driven from Ernest.

**Until it is built.** The full review reads some four hundred lines that then go, and the site goes live saying the numbers of the file it was built with.

## What stays

The site runs on ernest-httpd, and its panel needs a server whose client offers the interface. That is a fact of the deployment, owned by the site's design note and the release's procedure, as the OTP release Ernest runs on is. It is no dependency of a build or a test.

A change to the client's interface is a change across the two repositories, as a change to the wire is today: the server offers the new beside the old, and the site follows in its next release.

The stub client is Ernest's restatement of the interface, some twenty names, about as many as the wire and the configuration hold facts today. They are one interface in the page's terms and no format. The stub can drift from the server's client, and the check by hand before a release meets the real one.

A page that stays open across a restart of the server keeps the client it loaded, and a reload mends it.

The container's image, with its two nodes for the homepage's example, stays the server's `deploy/`. The server is ernest-lang.org's server and knows the site it serves. That direction is the ordinary one.

The shell page's sentences on what the server does stay the page's: the takeover by another tab, the one cookie and what the server logs. They restate the server's rules in words, and change by a commit in Ernest when a rule's shape does.

xterm.js and its addon stay vendored in the site, since the terminal is the page's.

No test in either repository names the running server, by its address or its host. A test starts the server it needs, or stubs it. The check against the running site is made by hand, the host given by whoever makes it.

## Decisions

Decided with the user on 2026-11-09, each with what decided it.

1. **The shell page's numbers leave its HTML.** The script writes them, each sentence of the list reads whole without its number, and the site's design note states the one exception to a page's text being complete without a script. The numbers are the server's facts, and `/shell/` says nothing useful without a script already. A file of numbers beside the generator was the other way, which no test would hold equal to the server.
2. **The client is never stale.** The ask's third line. A browser keeps a file fetched by a plain path for a share of its age without asking again. So a visitor who returns after the server changed its wire would speak the old one, and the session would fail with nothing to show why (principle 1). A changed wire is the case the client exists for. How the server meets the line is its own design's.
3. **The stub client is accepted**, as *What stays* says.
4. **After the launch**, as *The order* says. Before it, the switch would bring a client, a new response and a new script on a path the rehearsal did not walk, in the weeks that hold the server's reset under load, its floor's rise, its review and its release. The server's log argues the rehearsal on principle 1.
5. **The client's path is the site's.** The addresses a page names are the site's, *The root*'s, so the site names `/shell/client.js` once and the operator writes it into the server's configuration. A path the generator was given would build a site for one path, and the third line of *What it buys* would not hold.
6. **A container's memory is no limit of the server's.** The server enforces no memory: its command does, and its design keeps the command a program's words and knows no container. A client that answered the memory would have the server read its own command's flag, which is what the generator does today, moved. So the number leaves the page, and the ask names five limits.
7. **The interface, agreed with the server's session on 2026-11-10** (the log's *The Client's Interface Agreed*), read by each session against the other's proposal on the user's word, and stated in the server's proposal until its design's *The client* owns it. The client is an ES module with named exports and nothing on `window`: `limits`, the five in the configuration's units, milliseconds and counts, written by the server at the module's head; and `start(rows, columns, told)`, which answers a session with `keys`, `resize`, `extend` and `stop`, and tells the page by `told`'s four functions, `output`, `attached` with whether this browser joined, `warning` with the milliseconds left, and `ended` once with `expired`, `takenOver`, `unavailable`, `stopped` or `lost`. Keys and output are bytes. A size outside 1 to 65535, or a `told` whose four are not each a function, faults at the call. `site.js` imports it on demand, so that a page fetches it only for a session or for the shell page's numbers, one fetch per document under `no-store`, and the stub speaks the same names.

## What it meets

Read from both sides on 2026-11-09.

- `docs/design/site.md`: *The root*, *The other pages*, *The templates*, *The generation*, *The live shell*.
- `site/templates/README.md`, which owns what each template binds, and its test.
- `docs/architecture.md`'s *The site's generator* and its paragraphs on the site's tests, and `docs/development.md`'s on `make site`.
- `docs/reviews/release.md`, whose check by hand stays.
- The site's hand-over to the server at Ernest 0.10.0 (the log's *The Release Review Before 0.10.0*) and the plan's MVP 4.4's item 6, and the server's plan's items for the rehearsal and the switch. All stand as they are, since the launch's site is built with `CONFIG`.
- `docs/clean_room.md`: the ask goes to the server's session by a message, on the user's word, and the server's proposal is its own. What the ask durably is stands in the server's plan and design, written by its session, and this proposal then cites them by address.
- The server's design, *What the program does*, *Modules*, *The configuration*, *The static site*, *The connection*, *The shell*, *The sessions* and *The deployment*, its `deploy/config.json`, whose `Content-Security-Policy` admits a script of the site's own host, and its example site's `shell.js` and `shell.html`.
