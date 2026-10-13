# Decisions

What the discussion has settled, tersely. A decision changes here, with its
date.

## Purpose, 2026-10-13

- The site is a compact language manual with a working terminal. Its homepage
  answers what Ernest is, why one would use it, and where to start.
- No About and no Getting Started page.
- The site is ernest-lang.org. Every path on ernest-lang.se redirects to the
  same path there, and `sitemap.xml` names ernest-lang.org alone.

## The docroot, 2026-10-13

The site's files as served.

    /                               the homepage
    /404.html                       any unmatched path, served with HTTP 404
    /favicon.ico
    /robots.txt
    /sitemap.xml
    /why/                           guide/why.md
    /features/                      guide/features.md
    /tour/                          contents
    /tour/<n>.html                  chapter n, with previous and next
    /guide/                         contents
    /guide/<n>.html                 chapter n
    /deployment/                    guide/deployment.md
    /report/                        contents of the three files
    /report/language.html           §0 to §10, Appendices A, B and F
    /report/toolchain.html          §11, Appendices C and H
    /report/library.html            Appendices D, E and G
    /man/                           contents
    /man/stdlib/                    contents
    /man/stdlib/<module>.html
    /man/libs/                      contents
    /man/libs/<name>/               contents, a line per module
    /man/libs/<name>/<module>.html
    /shell/                         the full-page shell
    /install/
    /releases/                      releases/<version>.md, newest first
    /assets/css/                    site.css, xterm's stylesheet
    /assets/js/                     xterm.js, its fit addon, the session client
    /assets/img/                    the repository's logos, icons/

- A report page is one of the report's files, whole. A citation's first
  number or letter names its page.
- A chapter is addressed by its number, as a citation names it.
- Every contents page is generated, from the headings or from `libs/*/`.
  No symlink, and no page at two addresses.
- The `/man/` pages are rendered from `man/`'s Markdown, which `make man`
  writes. The site calls them Library.
- The docroot holds the assets, laid out as served; no page is written by
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
- A declaration's anchor is its qualified name as `man/`'s heading writes it:
  `#List.removeAt`, `#Address.call`, `#spawn`. An operator stays as written.
- Only numbered headings and declarations have anchors. No anchor is made from
  a heading's words.
- A citation becomes a link to its anchor, its page found as the documents test
  finds it: "§6.5" is `/report/language.html#6.5`, "Appendix E.17"
  `/report/library.html#E.17`, "guide §4.2" `/guide/4.html#4.2`, `List.sort`
  `/man/stdlib/list.html#List.sort`.

## The homepage, 2026-10-13

- It is the README's head, in the README's order: its opening paragraph; the
  guide's §0 list "What Ernest adds", which the README holds word for word,
  each item's bold name and first sentence linking to its section in Why, then
  a link, "everything Ernest has", to Features; the paragraph on intended use;
  and the counter example with its output, local, so that Try runs it. A test
  holds the four pieces where the generator finds them. The opening and the
  list are visible on a desktop without scrolling.
- After the example, its rows are four doors, in this order, each with its
  question: Try, "let me see it run", the shell's entry with Start; Tour, "show
  me the language"; Guide, "help me write programs"; Report, "tell me the
  rules".
- Why is the link ending the introduction's paragraph, "the whole argument".
- Deployment is reached from Install, from the guide's running chapter, from
  Why's code by its hash and from the footer, never from the homepage's body.

## Every page, 2026-10-13

- The header: Why, Tour, Guide, Report, Library, Shell, Install, and Source,
  the GitHub link. The terminal is labeled Shell, as `ern shell` names it; the
  homepage's door to it is Try.
  Features is not in the header.
- One footer, the homepage's too, in two lines. First the rooms the header
  leaves out: Features, Deployment and Releases. Then
  the page: its source file in the repository with its last commit date, the
  version the site is built from, the license, the issues, and "served by
  ehttpd, written in Ernest" once true.
- Previous and next stand above the footer on a tour, guide or report page.

## The other pages, 2026-10-13

- Install is the README's *Installing* section, which holds the supported
  platforms, the installation, its verification and the first command.
- Releases holds each release's notes as the release step writes them, newest
  first, from `releases/<version>.md`. The notes list no changes; they say
  where the changes are read.
- The shell page: the terminal takes most of the space, with Start or Restart,
  Stop, Examples and the time remaining above it. The session and its limits
  are explained beside it. A dropped connection and an expired session are
  told apart; nothing is erased silently on a reconnect; nothing runs but by
  the visitor's act.

## The look, 2026-10-13

- Semantic HTML and one shared stylesheet. No framework, font download or icon
  runtime.
- System sans-serif for prose, system monospace for code and the terminal.
- The browser's light or dark preference. Neutral backgrounds, dark text, one
  accent color for links, active navigation and focus; the logo's brown and
  cream for warmth, not on every control.
- Thin rules between sections. No cards, shadows, oversized panels or
  decorative illustration.
- Prose 70 to 80 characters wide, code and the terminal wider. A narrow
  contents sidebar on a desktop, an expandable contents list on a phone.
- Visible keyboard focus.
- The logos are the repository's `assets/`, which `make site` copies into
  `/assets/img/`; the docroot holds no copy.
- The full logo appears once, on the homepage, 230 px wide. Every other page's
  header links home with the stoat, `ernest-mark.svg`, beside "Ernest". Dark
  mode selects the dark logo through `<picture>`. The favicon is a simplified
  stoat head.

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
- A report section carries a computed margin line naming the pages that cite
  it: "taught in guide §4.2; used by `List.sort`".
- A citation of the log links to the log on GitHub.
- Ernest code is colored when the site is generated, by `ern`'s own lexer. A
  console block is plain monospace, as written: `ern build` colors nothing
  (report §11.2), and only the live shell shows the shell's colors.
- A qualified name in code, or in backticks in prose, `List.sort` or
  `Markdown.Block`, links to its declaration in `/man/` where it is a `man/`
  heading, a type or a function, and no code on its page declares a type of
  that name. Any other name is text, never an error: a bare name, since a
  module or a pattern may shadow a prelude name, and a member of a type the
  page declares, since a module's own type shadows the library's namespace
  (report §4.2).
- Each page has a title, a one-line description, its first sentence, and
  `ernest-social-preview.png` as the image a shared link shows.
- The site build checks every internal link and anchor in `build/site/`, made or
  written, and fails on one that does not resolve.

## The templates, 2026-10-13

- Flat token files, cut at their tokens once and joined with the values. No
  templating language.
- Each page kind binds a fixed list of tokens, and a test holds each template
  to its list.
- A plain token is escaped. A `*_html` token takes only HTML the generator
  makes from the repository, rendered Markdown or code, navigation or a
  template's fragment, or from the server's configuration, the session's
  limits.
- A list in a page, `contents_html`, `navigation_html` or `entries_html`, takes
  its item's look from a fragment file beside the page's.

## The generation, 2026-10-13

- One generator, `site.ern` in `tools/`, beside the manual tool, written in
  Ernest. It reads the repository, writes static files, and ends.
- In the repository, `site/` holds `templates/` and `docroot/`; in the
  prototype they stand in `proposals/site/`.
- Every page is generated from what the repository owns: the homepage and
  Install from the README; the report's, the guide's, the tour's, Why's,
  Features' and the deployment guide's pages and each `/man/` page from their
  Markdown, into `chapter.html`; the contents pages and Releases into
  `index.html`; the shell page into `shell.html`, its examples from `examples/`
  and its limits from the server's configuration; the 404 page into
  `error.html`.
- A book's opening, its title and its paragraphs before its first chapter,
  heads its contents page.
- A page's footer names the file it renders: the README for the homepage and
  Install, a document's Markdown, a module's `.ern` for a `/man/` page, since
  `man/` is itself generated. A contents page and the 404 page name none.
- A page's sidebar lists its anchored headings, two levels deep.
- The sources stay Markdown: the report, the guide, `man/`, and the tour's
  document under `tour/`, named when MVP 3.3 writes it. A source's opening logo
  and its contents block are dropped; the site has its own.
- A chapter of the guide or the tour is a second-level heading.
  Previous and next follow their order; the report's pages run language,
  toolchain, library.
- `libs/markdown` gains tables. A test parses the report and the guide whole and
  renders them back before any template meets them.
- `make site` builds the site from a release's tag without a worktree. It
  exports the tag with `git archive` into `build/site-source/` and builds the
  toolchain there, the checkout untouched, and runs `make man` there. It wipes
  `build/site/`, copies the docroot and the logos there, and writes every
  generated page beside them, so that a page whose source is gone goes. One step
  copies `build/site/` to the host; it is never edited in place.
- The pages are complete without JavaScript. The shell panel and the code
  blocks' buttons are the script's additions.
- No search: the report's whole pages serve the browser's find.
- The site runs on ehttpd, as the deployment guide runs a node.

## The live shell, 2026-10-13

- xterm.js, its stylesheet, a fit addon and a session client, self-hosted. A
  WebSocket at `/shell/session` to a pseudo-terminal running `ern shell`
  unchanged; the server behind it is MVP 4.2's first decision.
- Five states, each announced once: connecting, running, disconnected, expired
  and unavailable.
- Stop ends the session and its container. Restart is a deliberate act and
  ends the old ones.
- One operating-system container per visitor, shared by every page: allocated
  when the shell first opens, reused after.
- The image holds `ern`, the standard library, `libs/`, the examples and a
  scratch directory. No network.
- A session ends after five minutes without input at the prompt, a program
  running without input among them, after a five-second warning that a key
  press answers, or after 30 minutes in all.
- A second tab takes the session over, and the first says so.
- A fixed number of containers; when all are taken, the shell is unavailable.
  Starts per visitor are limited. The numbers come with the host.
- The shell page carries a privacy line: no accounts, one cookie, the layout
  kept in the browser, what the server logs, nothing kept.
- Every page with code has a panel, side by side or stacked, a toggle kept in
  the browser's local storage and never sent to the server. Stacked alone on a
  narrow screen; not offered on a phone, where `/shell/` still serves.
- No panel opens until the visitor asks. On a desktop, Try's Start opens the
  homepage's panel beside the example; on a phone, Try links to `/shell/`.
- Only an `ernest` block, which the guide tests compile, has Paste or Load.
  `ernest-fragment`, `ernest-rejected`, `ernest-prelude`, a console and another
  language's block have Copy alone. An `ernest` block that cannot run in the
  container is `ernest-shown`: the tests compile it as `ernest`, and it has
  Copy alone. Copy is on every block.
- A block with `export fn main` is Loaded: written into the session's scratch
  directory as `example.ern`, and `:load Example` typed, so that `main()` is
  one Enter away. Any other is Pasted.
- A Paste arrives as one input, as bracketed paste does. Nothing runs until
  Enter.
- Everything is reachable by keyboard. Focus lands in the shell after a Paste.
  xterm.js's screen-reader mode is on.

## The documents, 2026-10-13

- One document per question: Should I care? Why. What do I get? Features. Show
  me, in order: the tour. How do I write it? The guide. What exactly is the
  rule? The report. What does this function do? The library's pages. How do I
  run it? The deployment guide. What does this command do? `man ern`, and on
the site the report's §11.
  Let me try it: the shell. What is in each release? The release notes.
- Why and Features are `guide/why.md` and `guide/features.md`. The guide tests
  run their examples; each has a row in CLAUDE.md's owners table.
- Features is written first, then Why a section at a time, their lengths
  level.
- A section of Why states the rule, names its price before its gain, shows a
  program and the compiler's line about it, compiled before it is quoted, and
  points to the guide and the report. No sentence describes another language;
  no superiority claim; no sentence answers an objection the text did not
  raise.
- Why's four pieces are the guide's §0 list, found after its line "What Ernest
  adds is where the parts meet:" as the documents test finds it, in its order,
  its fourth item from 0.4.0 on: the mailbox in the function's type, a monitor's
  `Down` arriving in the mailbox's type among it; checked replies, a call ending
  with its callee's cause among it; purity in the type; and code by its hash
  across nodes, its subsections any number of revisions, code moving with a
  spawn, TLS between listed peers, and placement.
- The walk through one real program is the tour itself, which grows one
  program through every chapter (the plan's MVP 3.3).
- No comparison page: Why's FAQ answers "why not Erlang, Elixir or Gleam".
- A root `CONTRIBUTING.md`, written before the site goes live. Not a site page.
- `shell/README.md` is for a reader of the code, and not on the site.
- The module pages are the site's Library; at the terminal, `man` shows them
  after Install.
