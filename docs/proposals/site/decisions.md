# Decisions

What the discussion has settled, tersely. A decision changes here, with its
date. Read back on 2026-11-03 against the repository and the server's
design, and its findings applied the same day.

## Purpose, 2026-10-13

- The site is a compact language manual with a working terminal. Its homepage
  answers what Ernest is, why one would use it, and where to start.
- No About and no Getting Started page.
- The site is ernest-lang.org. Every path on ernest-lang.se redirects to the
  same path there, and `sitemap.xml` names ernest-lang.org alone.

## The root, 2026-10-13

The site's files as served.

    /                               the homepage
    /404.html                       any unmatched path, served with HTTP 404
    /robots.txt
    /sitemap.xml
    /why/                           guide/why.md
    /faq/                           guide/faq.md
    /tour/                          contents
    /tour/<n>.html                  chapter n, with previous and next
    /guide/                         contents
    /guide/<n>.html                 chapter n
    /deployment/                    guide/deployment.md
    /report/                        contents of the three files
    /report/language.html           §0 to §9, Appendices A, B and F
    /report/toolchain.html          §10 to §12, Appendices C and H
    /report/library.html            Appendices D, E and G
    /man/                           contents
    /man/stdlib/                    contents
    /man/stdlib/<module>.html
    /man/libs/                      contents
    /man/libs/<name>/               contents, a line per module
    /man/libs/<name>/<module>.html
    /shell/                         the full-page shell
    /install/
    /releases/                      CHANGES.md
    /assets/css/                    site.css, xterm's stylesheet
    /assets/js/                     xterm.js, its fit addon, the session client
    /assets/img/icons/              the Lucide icons and their LICENSE
    /assets/img/icons.svg           the same icons, one symbol each
    /assets/<logo>                  the logos the site shows, at their paths in assets/

- A report page is one of the report's files, whole. A citation's first
  number or letter names its page.
- A chapter is addressed by its number, as a citation names it.
- Every contents page is generated, from the headings or from `src/libs/*/`.
  No symlink, and no page at two addresses.
- The `/man/` pages are rendered from `docs/man/`'s Markdown, which `make man`
  writes. The site calls them Library.
- The root holds the assets, laid out as served; no page is written by
  hand. The templates and their README stand beside it, in `templates/`.
- A link names a directory by its own form, `/guide/`, never
  `/guide/index.html`.
- The server serves a directory's `index.html` without a redirect. It
  redirects only a directory named without its slash, `/report` to `/report/`,
  and every path on ernest-lang.se.
- No path holds a version: the site shows one version.
- No site-map page and no diagnostics page: the header and the footer reach
  every page, and a diagnostic names its rule and what to write. A diagnostics
  page returns if diagnostics gain stable ids.

## Anchors, 2026-10-13

- An anchor is the citation's own text without its `§`: `#6.5`, `#E.17`, and
  `#4.2` in the guide. A chapter's is its number or letter: `#6`, `#E`.
- A declaration's anchor is its qualified name as `docs/man/`'s heading writes it:
  `#List.removeAt`, `#Address.call`, `#spawn`. An operator stays as written.
- In a document that numbers its headings, only numbered headings and
  declarations have anchors, and no anchor is made from a heading's words.
- In a document that numbers none, Why, the questions, Install and
  Releases, a heading's anchor is its GitHub slug, computed as the
  documents test computes it, so that a link written for GitHub holds on
  the site: `#a-deadlock-is-found`. A reworded heading breaks a link from
  outside; the build's check catches every link inside (decided
  2026-11-03).
- The questions' questions are `###` headings, not bold paragraphs, so
  that each has an anchor and the page a sidebar; the guide changes so in
  MVP 4.2 (decided 2026-11-03).
- A citation becomes a link to its anchor, its page found as the documents test
  finds it: "§6.5" is `/report/language.html#6.5`, "Appendix E.17"
  `/report/library.html#E.17`, "guide §4.2" `/guide/4.html#4.2`, `List.sort`
  `/man/stdlib/list.html#List.sort`.

## The homepage, 2026-10-13

- It is `home.html`, its text the site's own; the README is the repository's,
  and the homepage takes nothing from it (decided 2026-10-13). In order: an
  opening under its heading, both leading with what Ernest adds that no
  reader expects, a process started on another node bringing its code
  along, and then what kind of language it is and what it is for,
  stating what Ernest does and never what another language lacks. Each
  thing is said once on the page: the opening says the effect, the list
  beside it the means (decided 2026-11-03); Why's list
  "What Ernest adds", four of `guide/why.md`'s claims, the ones a newcomer
  reads at once: code goes where it runs, the mailbox in the function's
  type, a distribution built for a WAN, and a deadlock is found. Each is
  shown as its bold name and its first sentence alone, word for word,
  linking to its heading in Why, so that the list fits beside the
  opening; the rest is Why's. Why and the README take that order and the
  first claim's name and sentence when they are rewritten (`todo.md`;
  decided 2026-11-03); and a small example with its output, which a
  test runs, so that the example's button runs what the page shows: a process started on
  the container's second node, its code typed into the shell and sent
  there (decided 2026-11-03). The opening and the list are visible on
  a desktop without scrolling, which the mockup's homepage is checked for
  first; where they are not, the page is cut, not the rule (decided
  2026-11-03).
- Under the example stands its button, "Try it", alone, the page's one
  action and its one strong color: a block's Paste made prominent, named
  by what the visitor does, and promising nothing it does not do, since
  the code waits in the shell for Enter. It puts the example's code into
  the shell, opening the panel and starting a session where needed, and its
  label never changes: the header's buttons show and hide the panel, and
  the panel's bar starts and stops the session, each control one job. On
  a phone it opens `/shell/` with the code waiting, and without the script
  it is a link to `/shell/` (decided 2026-11-03).
- After it, three doors, in this order, each with its question and of one
  weight: Tour, "show me the language"; Guide, "help me write programs";
  Report, "tell me the rules" (decided 2026-11-03).
- Why is the link ending the introduction's paragraph, "the whole argument".
- Deployment is reached from Install, from the guide's running chapter, from
  Why's code by its hash and from the footer, never from the homepage's body.

## Every page, 2026-10-13

- The header: Why, Tour, Guide, Report, Library, Shell, Install, and Source,
  the GitHub link. The terminal is labeled Shell, as `ern shell` names it; the
  homepage's way to it is the example's button.
- One footer, the homepage's too, in two lines. First the rooms the header
  leaves out: the questions, Deployment and Releases. Then
  the page, "This page:" and its source file's path in the repository,
  with its last commit date at
  the tag, which the checkout's `git log` gives since an export has no
  history, the
  version the site is built from, "0BSD license", "Report a defect" for
  the issues, and "Served by ernest-httpd, written in Ernest" (decided
  2026-11-03).
- Previous and next stand above the footer on a tour, guide or report page,
  and not at its top, where a reader has just arrived; there the book's
  title above the chapter's heading links to its contents page (decided
  2026-11-03).
- On a narrow screen the header is the stoat with "Ernest" and a
  `<details>` menu holding its links, folded as the contents list is, by
  the browser and no script (decided 2026-11-03).

## The other pages, 2026-10-13

- Install is the README's *Installing* section, which holds the supported
  platforms, the installation, its verification and the first command.
- Releases is `CHANGES.md` rendered as it stands, newest first, each
  release's note as the release step writes it there and copies it to
  GitHub, from the release after 0.6.0 on (decided 2026-10-30).
- The shell page: the terminal takes most of the space, with the panel's
  controls above it, Start or Restart and Stop, and the warning banner with
  Extend when it comes (*The live shell*), and there is no Examples control, the
  pages' blocks being the examples (decided 2026-10-30). The session and its
  limits are explained beside it. A dropped connection and an expired session are
  told apart; nothing is erased silently on a reconnect; nothing runs but by
  the visitor's act.

## The look, 2026-10-13

- Semantic HTML and one shared stylesheet. No framework, font download or icon
  runtime. No inline script, since the server's `Content-Security-Policy`
  allows only its own scripts (the server's design, *The deployment*), and no inline
  style in the site's own pages; the policy allows inline style, which
  xterm.js sets.
- System sans-serif for prose, system monospace for code and the terminal.
- The browser's light or dark preference. Neutral backgrounds, dark text, one
  accent color for links, active navigation and focus; the logo's brown and
  cream for warmth, not on every control.
- Thin rules between sections. No cards, shadows, oversized panels or
  decorative illustration.
- Prose 70 to 80 characters wide, code and the terminal wider. A narrow
  contents sidebar on a desktop, an expandable contents list on a phone.
- Visible keyboard focus.
- The logos are the repository's `assets/`, of which `make site` copies
  the three the site shows to `/assets/`, each at its path in the
  repository; the root holds no copy. A
  file the site takes from the repository keeps the repository's hierarchy, as
  `/man/` keeps `docs/man/`'s (decided 2026-10-13).
- The site shows no full logo: the wordmark would write the name a second
  time, as a picture, in the space the homepage's opening needs. Every
  page's header, the homepage's too, links home with the stoat,
  `ernest-mark.svg`, beside "Ernest" in text, and the homepage opens with
  its paragraph under a heading in text (decided 2026-11-03). The full
  logo stays where no header stands: the READMEs and the image a shared
  link shows. The favicon is
  `ernest-avatar-64.png`, which every page names, and the root serves no
  `/favicon.ico` (decided 2026-10-16).

## Links, 2026-10-13

- A source's own link, written for GitHub, is mapped by the generator: to the
  page of a document the site shows, `library.md` to `/report/library.html`; by
  a heading's GitHub slug to that heading's number anchor, as the documents
  test computes the slug; and to the file on GitHub, at the tag the site is
  built from, where the site does not show its target, `examples/` or `docs/`.
- A static page or a template links by hand, to a page's directory form.
- A citation is a form the documents test reads: `§x.y`, alone or after "report"
  or "guide"; an appendix, `Appendix E`, or one of its sections, `Appendix
  E.17`; and `E.n`; besides the log's *Title* and a qualified name. A bare `§`
  is the guide's own in `guide/language.md`, and the report's in every other
  document. A reference finer than a section is written with its section, "E.0
  shape rule 10", whose `E.0` links.
- A link into the guide holds while the guide's numbers hold, and they change
  only where a section cannot be placed otherwise. A link from outside, made
  before a renumbering, may land on the section that took its number; nothing
  redirects it, since a fragment never reaches the server.
- A report section carries a computed margin line naming the guide's
  sections that cite it, each once: "taught in guide §4.2". What else
  cites it is not listed, since a library page already links to the rule
  it follows (decided 2026-11-03). The mockup over a real section shows whether the line stays
  short.
- A citation of the log links to the log on GitHub.
- Ernest code is colored when the site is generated, by `ern`'s own lexer,
  which the generator reaches by a `foreign` declaration over the toolchain's
  lexer module, as the shell's front end is foreign to the toolchain: the
  generator is a tool of the repository's and the lexer a layer beneath it,
  and no command of `ern`'s is added for one tool's need (decided
  2026-10-30). A console block is plain monospace, as written: `ern build` colors nothing
  (report §11.2), and only the live shell shows the shell's colors.
- A qualified name in code, or in backticks in prose, `List.sort` or
  `Markdown.Block`, links to its declaration in `/man/` where it is a `docs/man/`
  heading, a type or a function, and no code on its page declares a type of
  that name. Any other name is text, never an error: a bare name, since a
  module or a pattern may shadow a prelude name, and a member of a type the
  page declares, since a module's own type shadows the library's namespace
  (report §4.2).
- Each page has a title, a one-line description, its first sentence, and
  `ernest-social-light.png` as the image a shared link shows.
- The site build checks every internal link and anchor in `build/site/`, made or
  written, and fails on one that does not resolve.

## The templates, 2026-10-13

- The HTML is written to be read, by hand in a template and by the
  generator in a page alike, so that a page's source reads as its
  template does (decided 2026-11-03). Each block element stands on a line
  of its own, indented two spaces a level; inline content stays on its
  block's line, a paragraph one line however long. A `<pre>` begins at its
  line's indentation and holds its body as shown, from the line's start.
- HTML5 as written today: lower case, every attribute quoted, no `/>` on
  a void element, and every end tag written, `</p>` and `</li>` among
  them, though the parser would supply it.
- An icon is one line, a `<use>` of its symbol in `/assets/img/icons.svg`,
  which `make site` gathers from the icon files; the prototype holds the
  gathered file.
- The stylesheet lays out with flex and grid and their gaps, so that the
  whitespace between elements never shows.
- No control the script works stands in the HTML: Copy, Paste and Load,
  a transcript's Paste for each input, the example's button and the panel's toggle
  are made by the script, so that a page without it shows none. The HTML
  holds what the generator decided, a block's `data-shell="paste"` or
  `"load"` and the example button's `data-shell="start"`, and the script reads it
  (decided 2026-11-03).

- Flat token files, cut at their tokens once and joined with the values. No
  templating language.
- Each page kind binds a fixed list of tokens, and a test holds each template
  to its list.
- A plain token is escaped. A `*_html` token takes only HTML the generator
  makes from the repository, rendered Markdown or code, navigation or a
  template's fragment, or from the server's configuration, the session's
  limits: `make site` is given the server's configuration file, from which
  the generator reads the shell's path, its lifetime, its warning, the shells at once
  and the command's memory flag, so that the shell page says what the server
  enforces and nothing is written twice (decided 2026-10-30).
- A list in a page, `contents_html`, `navigation_html` or `entries_html`, takes
  its item's look from a fragment file beside the page's.

## The generation, 2026-10-13

- One generator, `site.ern` in `tools/`, beside the manual tool, written in
  Ernest. It reads the repository, writes static files, and ends.
- In the repository, `site/` holds `templates/` and `root/`; in the
  prototype they stand in `docs/proposals/site/`. The site is this
  repository's whole, its shell page among its pages: the generator reads
  this repository's documents at a tag, and a test holds it to the
  mockups. The `ernest-lang.org` repository holds the one page served
  until the generated site goes live, and then goes (decided 2026-11-03).
- Every page is generated from what the repository owns: two templates and
  two pages of their own, all four standing on
  `base.html` with its header and footer.

  `page.html` is a Markdown document
  with a sidebar of its headings and a footer naming its source, for every
  chapter of the tour, the guide and the report, every `/man/` page, Why,
  the questions, the deployment guide, Install, Releases, which is `CHANGES.md`,
  and the 404 page with its fixed body;
  what differs between them, a previous and a next, and what the footer names,
  is data the generator passes, and a slot without it is empty.

  `toc.html` is a contents page: a book's or a directory's opening and its list of links, for
  `/tour/`, `/guide/`, `/report/`, `/man/`, `/man/stdlib/`, `/man/libs/` and
  `/man/libs/<name>/`. `home.html` is the homepage and `shell.html` the
  full-page shell; each is one page, not a template.

  A template is named for what it is;
  what it is written as is the root's: a directory's page is its
  `index.html`, the homepage's, a contents page's, Why's and the shell's
  alike, and a chapter is its number, `/guide/3.html`.
- A book's opening, its title and its paragraphs before its first chapter,
  heads its contents page.
- A page's footer names the file it renders: `home.html` for the homepage, the
  README for Install, `CHANGES.md` for Releases, a document's Markdown, a module's `.ern` for a `/man/` page, since
  `docs/man/` is itself generated. A contents page and the 404 page name none.
- A page's sidebar lists its anchored headings, two levels deep.
- The sources stay Markdown: the report, the guide, `docs/man/`, and the tour's
  document, `tour/README.md`. A source's opening logo
  and its contents block are dropped; the site has its own.
- A chapter of the guide or the tour is a second-level heading.
  Previous and next follow their order; the report's pages run language,
  toolchain, library.
- `libs/markdown` has tables. A test parses the report and the
  guide whole and renders them back before any template meets them.
- `make site` builds the site from a release's tag without a worktree. It
  exports the tag with `git archive` into `build/site-source/` and builds the
  toolchain there, the checkout untouched, and runs `make man` there. It wipes
  `build/site/`, copies the root and the logos there, and writes every
  generated page beside them, so that a page whose source is gone goes. One step
  copies `build/site/` to the host; it is never edited in place.
- Everything comes from the tag, the documents and the site's own files,
  its templates, its root and its generator, so the site is a release
  exactly, never a pairing the tests did not run; a fix to the site's look
  or its generator goes live with the next release. It is weighed again
  when releases come seldom, after 1.0, with the fix that waited in hand
  (decided 2026-11-03).
- A page's text, links and navigation are complete in its HTML, and read
  without a script. A script adds to a page, the shell panel, the
  navigation that keeps it and the code blocks' buttons, and never holds
  what the page says (decided 2026-11-03).
- A stylesheet, a script or the icons' file is written under a name that
  holds a digest of its content, `site.3f9a2c1e.js`, and every page names
  it so, so that a browser never runs a cached file against a newer page;
  the server sends no `Cache-Control`, and a browser keeps a file as long
  as it guesses. The vendored files keep their own names inside it
  (decided 2026-11-03).
- No search: the report's whole pages serve the browser's find.
- The site runs on ernest-httpd, a program under systemd and no node
  (the server's design, *The deployment*).
- `make install` ships no page of the site: the pages are the server's, their
  links absolute and the shell panel on each. An installation's documents stay
  each in the form its reader uses: the man pages as roff, the report and the
  guide, which have no roff form, as Markdown (`docs/design/install.md`).
  A form of the pages that works from a file, relative links and no panel,
  shipped apart as Rust ships its book, is decided with MVP 4.2 if it is wanted
  (decided 2026-10-13).

## The live shell, 2026-10-13

- The server side of the shell, the pseudo-terminal, the container per visitor and its image, the session's timeouts and a second tab's takeover, is the server's, which has no pool, in the server's design, ernest-httpd's design page, from *The WebSocket* to *The deployment*, https://github.com/joagre/ernest-httpd/blob/main/docs/design.md; every citation of the server's design below is of that page.
- The visitor's container runs two nodes, so that a visitor tries the
  homepage's claim and is not only told it: `foo`, started with no
  program, and the shell, started with `--config-dir a`, the two listing
  each other's keys, made when the image is built. A probe on 2026-11-03
  sent a counter typed into the shell to `foo`; a bare shell held 85 MB,
  the shell as a node 101 MB and `foo` 102 MB, its prompt after 1.3 s
  against 0.6 s. Most of that was the host's tables, reserved for a
  million processes and 65,536 ports; each node's `ernest.conf` states
  `"limits": {"processes": 65536, "ports": 4096}` (report §12.5), which
  brings a node to 37 MB, so that the two fit the server's 128 MB a
  visitor and its six at once on its 2 GB host, its numbers the server's;
  the host grows only when its log shows visitors turned away (decided
  2026-11-03).
- Whether a node transcript of the guide or the tour, whose `foo` matches
  the container's, gets Paste is decided with the generator's rules, the
  plan's MVP 4.2 item 2.
- xterm.js, its stylesheet, a fit addon and a session client, self-hosted. A
  WebSocket at the configuration's `shell.path`, which the generator reads
  from the server's configuration file, to a pseudo-terminal running
  `ern shell` unchanged; the server behind it is ernest-httpd's (the
  server's design, *The shell*).
  xterm.js and its addon get a row in `THIRD_PARTY_LICENSES` when they are
  vendored, as the Lucide icons have one (2026-10-30).
- xterm.js keeps a scrollback, a scrollbar, the wheel and Shift+PageUp, in
  the browser alone, so a session scrolls back as an xterm on Linux does;
  the shell writes above its live region on the ordinary screen, and a
  program on the alternate screen has none while it runs (decided
  2026-10-26).
- The client sends the panel's size as its first message and at each
  resize, which the server takes as the session's start and its terminal's
  size; the messages' forms are the server's design's, *The shell*.
- Seven states, each announced once: connecting, running and disconnected,
  the page's own, and expired, taken over, unavailable and stopped, one for
  each close code the server sends, 4001 to 4004 (the server's design, *The shell* and *The sessions*).
- A session's warning is a banner with Extend, shown when the server's
  warning comes, and the banner is no dialog. It says once the seconds the
  warning carries, as "ends in" and the seconds, and nothing counts down,
  since a key moves the server's deadline without a word (decided
  2026-11-03). A key or Extend keeps the session, by the lifetime the
  server's design owns, *The sessions* (decided 2026-10-27).
- A session that expires closes its panel and gives the page back its
  width, a short line saying for a moment that the shell ended after the
  configuration's lifetime without a key, which the generator reads, and
  that opening it starts a new one; the layout kept in local storage is
  unchanged, so the next Paste or Open shell opens the panel as the
  visitor last had it. A takeover and *unavailable* show in the panel,
  where the visitor is present to read them (decided
  2026-10-27).
- The line is a snackbar, a slim notice at the window's bottom edge, whatever the
  layout was, so that it covers nothing the visitor was reading: the
  sentence, an icon that opens the shell and one that closes the notice.
  It stays until the visitor clicks one of them or anywhere on the page,
  no timer deciding when a person has read it, and is announced as a
  polite live region (decided 2026-10-27).
- Each input of a transcript ends in its own Paste, a small icon drawn
  bold, in the accent's color when pointed at or focused, visible without a hover, so that a touch
  screen and a first look find it; the shell's output has none, and the
  `>` stays text (decided 2026-11-03). A block's tools show on hover or focus where there is a
  fine pointer, a mouse, on the block's own color, and on a touch screen
  stand on a row of their own above the block, since a phone's browser may
  say it hovers, so that they never cover its code
  (decided 2026-11-03).
- Copy, Paste, Load and the shell's own controls are small icons, each
  with a tooltip and an accessible name, `Paste into the shell`, so that
  the layout stays plain and a screen reader says what each does (decided
  2026-10-27).
- Stop ends the session, and Restart is a deliberate act that ends the old one; what they end, the container, is the server's (the server's design, *The sessions*).
- The shell page carries a privacy line: no accounts, one cookie, the layout
  kept in the browser, what the server logs, nothing kept.
- The shell panel is `base.html`'s, so every page has it, side by side or
  stacked, one toggle for every page, kept in the browser's local storage and
  never sent to the server; Paste and Load are a code block's, so a page
  without code offers the panel and nothing to put in it (decided 2026-10-13).
  Stacked alone on a narrow screen; not offered on a phone, where `/shell/`
  still serves.
- While the panel is open, a link to another page of the site fetches that
  page and puts its `<main>` and its title in place of the old, the
  address moved by the history, so that the panel, its socket and its
  screen stay; back, forward, the scroll, an anchor and focus behave as
  on a page loaded whole, which a test in a browser checks. With the panel
  closed a link loads its page whole. Every page stays a whole file
  (decided 2026-11-03).
- The panel's toggle splits the window vertically or horizontally, the
  visitor's choice, kept in local storage with the panel's layout
  (decided 2026-11-03). It is two buttons in the header, beside and
  below: the open layout's is pressed, pressing it again closes the
  panel, and pressing the other moves it. The header spans the window;
  beside, the panel fills its right side below the header, at 45% of the
  width, and the page scrolls in the rest; below, it takes 40% of the
  height and the page scrolls above it. A handle on its inner edge
  resizes it, the size kept with the layout. The panel's bar holds the
  session's state, Start where no session runs and Restart while one
  does, Stop, and Hide, the icon of the
  header button that opened the panel, which hides it and keeps the
  session; Stop alone ends one. A session's end is marked in the terminal, dim,
  after its last output, in the bar's word for it, the screen staying to
  be read and the terminal taking no keys until a new session starts. A
  Start after an end begins below the ended screen; a Restart begins on a
  clear one. A session that runs while the panel is
  hidden marks that header button with a dot. The session's limits and
  the privacy line stay on `/shell/`. Below 1000 px only below
  is offered. Opening moves focus into the terminal and closing returns
  it to the button; Escape is the terminal's (decided 2026-11-03).
- No panel opens until the visitor asks. On a desktop, the example's button
  opens the homepage's panel beside the example; on a phone, it opens
  `/shell/`.
- Only an `ernest` block that runs alone in a bare shell has Paste or
  Load: one the guide tests take as a module of its own. One joined with
  the other blocks that name its file is a piece of a program and has Copy
  alone. The generator decides it by the guide tests' own grouping, no mark
  being written by hand, and a test runs every block given Paste or Load,
  and every transcript input given Paste, in a bare shell (decided
  2026-11-03).
- `ernest-fragment`, `ernest-rejected`, `ernest-prelude`, a console that is
  not a transcript, and another language's block have Copy alone; a
  transcript is a console whose inputs are `> ` lines, below. Copy is on
  every block.
- A block with `export fn main` is Loaded: pasted as one declaring input,
  since an input may declare what a module may and every declaration is the
  session's (report §11.2), and then `main()` typed and not entered, so that
  it is one Enter away. Any other is Pasted. No file is written and nothing
  crosses the socket but the terminal's bytes, since no message of the
  socket's could write a file (decided 2026-10-30).
- A Paste arrives as one input, as bracketed paste does. Nothing runs until
  Enter.
- In a block that shows a shell session, each `> ` line has a Paste of its
  own, which puts that input into the shell without its prompt, as one
  input; a transcript is read input by input with what the shell answered,
  so no button pastes them all. The guide's and the tour's transcripts are
  tested as transcripts, so every input offered is one the tests have run
  (decided 2026-10-27). A transcript whose session a bare shell cannot
  hold has Copy alone: one begun with a module loaded, `ern shell
  words.erc`, one begun with `ern shell --config-dir`, a node's, or
  `--attach`, an operator's (§11.2 *The attached shell*), which the nodes
  chapters, the tour and the deployment guide show; the generator reads it
  from the session's first line (decided 2026-11-03).
- A Paste or a Load is the visitor asking for the shell: where no panel is
  open, the click opens it, side by side or stacked by the window's width,
  and starts the session where none runs, the input arriving once the
  prompt does; a visitor who never noticed the shell meets it so. On a
  phone, where no panel is offered, the click opens `/shell/` with the
  input waiting there (decided 2026-10-27).
- xterm.js takes Alt, and Option on a Mac, as Meta, so that the shell's
  M-Enter, which its own hint names, works in the panel (decided
  2026-11-03).
- Everything is reachable by keyboard. Focus lands in the shell after a Paste.
  xterm.js's screen-reader mode is on.

## The documents, 2026-10-13

- One document per question: Should I care? Why. Show
  me, in order: the tour. How do I write it? The guide. What exactly is the
  rule? The report. What does this function do? The library's pages. How do I
  run it? The deployment guide. What does this command do? `man ern`, and on
  the site the report's §11. Let me try it: the shell. What is in each release? The release notes.
- Why is `guide/why.md`, and the questions are `guide/faq.md`; the guide
  tests run their examples. No Features page: what it would list is the
  README's claims, the guide's contents and the manual pages' index, and a
  fourth list would drift from them.
- A section of Why states the rule, names its price before its gain, shows a
  program and the compiler's line about it, compiled before it is quoted, and
  points to the guide and the report. No sentence describes another language;
  no superiority claim; no sentence answers an objection the text did not
  raise.
- Why's pieces are `guide/why.md`'s claims, found after its line "What
  Ernest adds is where the parts meet:" as the documents test `claims_test`
  finds them and holds them equal to the README's, in their order: the mailbox
  in the function's type; code known by its hash; a distribution built for a
  WAN; abstract types and requirements; a deadlock is found; and little else.
  Four claims show a program, one its configuration file and one the
  report, and the site renders the list as it stands.
- The walk through one real program is the tour itself, which grows one
  program through every chapter, `tour/README.md`.
- No comparison page: `guide/faq.md`, at `/faq/`, answers "it looks like Gleam" and
  "where are the supervisors", and the guide's §10 answers the Erlang programmer.
- A root `CONTRIBUTING.md`, written before the site goes live. Not a site page.
- `src/shell/README.md` is for a reader of the code, and not on the site.
- The module pages are the site's Library; at the terminal, `man` shows them
  after Install.
