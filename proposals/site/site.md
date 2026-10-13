# The Ernest website

A proposal, under discussion. What the site is for, how its pages are laid out,
how they are generated from what the repository already holds, and what has to
be decided before any of it enters the plan. The templates under
`templates/` are early versions of the same design, and `templates/README.md`
holds their rendering contract. The milestone is MVP 4.2, after 0.5.0; the
generator can come earlier, whenever it is wanted.

## What we are after

A compact language manual with a working terminal, with enough identity to be
recognizable as Ernest. The homepage answers three questions quickly: what is
it, why would I use it, where do I start. The live shell is the demonstration;
the tour, the guide and the report are three depths of explanation, each for a
reader who knows what they want. Read the explanation, inspect the example, try
the language, then choose the depth.

## The site

**Navigation.** One compact header, its list question 5's. The logo links
home. The terminal is labeled Shell, matching `ern shell`; a homepage link can
say "Try Ernest" without a navigation category of its own.

**Site map.** The tree and its addresses are [`decisions.md`](decisions.md)'s.
Shallow, and nothing duplicated: an About or a Getting Started page would
restate the homepage. The install page holds the supported platforms, the
installation, its verification and the first command; the changes page each
release's notes, with what a program written for the last release changes.

**The homepage, in order.** A compact introduction: "Ernest" and one factual
sentence, then one short paragraph on its intended use, no milestone numbers. A
small complete example of typed process communication, the behavior beside the
code, since the first audience knows BEAM; not a factorial, not a syntax
collage. Four or five characteristics, each linking to its explanation and
saying what it gives the programmer, no superiority claims: inferred types,
typed mailboxes, explicit process effects, checked reply ownership. The doors
as rows ([`decisions.md`](decisions.md)). A short dated status, what is available
against what is planned. A small footer: version, license, source, issues, and
"served by ehttpd, written in Ernest" once true. On a desktop display the
introduction, the example and the primary links are visible without scrolling.

**The shell page.** The terminal takes most of the space; above it only the
controls needed: Start or Restart, Stop, Examples, and the time remaining. The
session is explained plainly: it runs on the server in a temporary isolated
environment, and its contents are discarded when it ends; the actual limits are
shown beside it. A disconnected terminal and an expired session are told apart,
and nothing is erased silently during a reconnection. The tour's examples link
into the shell; execution is the visitor's act.

**Visual design.** Semantic HTML and one small shared stylesheet, no framework,
no font download, no icon runtime: system sans-serif for prose, system monospace
for code and the terminal; the browser's light or dark preference; one accent
color for links, active navigation and focus; the stoat beside "Ernest" in the
header and no decorative illustration; thin rules between sections, no cards,
shadows or oversized panels; prose 70 to 80 characters wide, code and the
terminal wider; on desktop a narrow contents sidebar, on mobile an expandable
contents list. Minimal CSS is not unstyled HTML: typography, spacing, responsive
layout and visible keyboard focus are what make it contemporary.

**The logotype.** The lockup is tall, about 63 px high at 140 px wide, and the
stoat's face goes small. The homepage shows the full logo at 220 to 260 px
beside the introduction; documentation pages carry a compact "Ernest" home link;
the favicon is a simplified stoat head; dark mode selects the dark variant
through `<picture>` and `prefers-color-scheme`. Neutral backgrounds, dark text,
one accent; the brown and cream give warmth and need not color every control.
The logo appears once near the top, with no banner and no repeated mascot.

## Linking

Discussed 2026-10-13. The site must shine here, since most language sites do
not, and the project already holds what makes it cheap: the report's section
numbers never change, and the documents test refuses a citation that does not
resolve. A citation is a link that is not yet rendered.

- **Citations become links, by the generator, never by hand.** Every "§3.9",
  "Appendix E.0", "shape rule 10", "guide §4.2", a library name such as
  `List.sort`, and "the log's *Placing Work by Name*" in any page renders as a
  link to its anchor. No page carries a hand-written internal link, so nothing
  rots, and the test that resolves citations is the link checker. The "See $X
  in the guide, and $Y in the report" lines of `but_why.md` are ordinary
  citations.
- **Every section has a permanent address**, by its number
  ([`decisions.md`](decisions.md)). The report's numbering rule guarantees the
  report's; the guide's numbers change only where a section cannot be placed
  otherwise, which a redirect covers.
- **Links go both ways, computed.** The report's register forbids it from
  pointing at the guide in prose. The generator inverts the citation graph
  instead: beside each report section a margin line, "taught in guide §4.2 and
  §6.1; used by `List.sort`; shown in but_why §1", computed from every citation
  in every page. Nothing restates anything to get it.
- **Names in code link too.** The generator has the compiled interfaces, so a
  function in a code block links to its library page, a type to its
  declaration, and a quoted compiler line to its entry in the diagnostics
  catalog.
- **One header, one footer, on every page.** The header's list is question
  5's. The footer carries the three depths with the reader's
  question beside each, "show me", "help me write", "tell me the rules", then
  Library, Shell, Changes, the page's source file in the repository with its
  revision date, and the version the page describes. Previous and next, in the
  tour, the guide and the report, sit above it.
- **The highlighter is the lexer.** Code on the site is colored at generation
  time by `ern` itself, from the tokens the compiler reads, so the site, the
  Emacs mode and the shell agree on what a keyword is, and no script guesses
  at Ernest. A quoted compiler line renders in the terminal's own colors
  through `libs/ansi`, so a reader sees on the page what the prompt will show.
- **Metadata for a shared link.** A title and a one-line description per
  page, so a link pasted into a chat shows what it is.
- **A test for all of it.** The site build fails on any internal link or anchor
  that does not resolve, the computed ones included, as the documents test
  fails on a bad citation.

## The templates

The templates are flat token files, `{{heading}}`, `{{markdown_html}}`, with a
stated contract and no templating language, which is what a generator written
in Ernest wants: a template is cut at its tokens once and joined with the
values, never a textual replace over rendered content. Eight files, 29 tokens
in all, each page kind binding a small fixed set.

What to sculpt, in the templates and beside them:

- **Keep the token sets fixed and listed**, one list per page kind, and let a
  test hold each template to its list, as the listing tests hold Appendix E to
  the modules: a token added or renamed in a template then fails the build
  instead of leaving `{{heading}}` on a page.
- **The line between a plain token and a `*_html` token is the contract.** A
  plain token is escaped; a `*_html` token takes a rendered fragment, which is
  only ever the rendered Markdown of the repository's own files or the
  navigation among them. Code examples are escaped before they stand in `pre`
  and `code`. If user Markdown is ever accepted, it is sanitised apart.
- **The lists inside the pages are the generator's**: `contents_html`,
  `navigation_html`, `entries_html`. Each is one shape,
  and its item's look lives in a fragment file beside the page's, not in
  Ernest strings.
- **The rest of the contract holds**: `asset_base` is `/assets` in production;
  `aria-current="page"` on the active link; previous and next omitted at the
  ends; stable chapter and declaration anchors; a real version in the footer;
  wide tables wrapped for scrolling; heading levels, list structure and
  descriptive links preserved.

**The starting point.** `templates/` already gives what this design asks of a
page: one body template per kind of page, `base.html` with `header.html` and
`footer.html` as the one header and footer, previous and next in
`chapter.html`, stable chapter and declaration anchors, no build step and no
script a page needs to be read, light and dark, a skip link and keyboard
focus, and print rules. `templates/README.md` holds the rendering contract.
What this design adds to them:

- the homepage's `doors` navigation as [`decisions.md`](decisions.md)'s rows,
  and the header's list once question 5 decides it;
- the shell panel in `base.html`, split side by side or stacked, with its
  toggle, and Paste, Load and Copy on every code block, added by the script
  and never required;
- the footer's version, the page's source file with its revision date, and
  the reader's question beside each depth;
- the computed margin line on a report section, taught here and used there.

## The generation

**The shape.** One generator, a program written in Ernest beside
`tools/manual.ern`, run by a `make site` target, turns what the repository holds
into static files in the templates' layout. ehttpd serves files; the live
shell is the one thing on the site that is not a file. The generator has no
state and no server: it reads the sources, writes the pages, and ends.

**The sources stay what they are.** The report's three files, the guide and the
tour are Markdown in the repository, and the HTML is a rendering of them, as the
man pages are a rendering of the doc blocks. Nothing is written twice, and the
report remains the normative text whatever the site shows.

**The library's part, and what stays out of it.** `libs/markdown` exports its
tree, `Block` and `Inline` with every constructor, and `parse`, which gives it.
That tree is the interface to every format: the terminal renderer the shell and
`ern doc` share is a function over it, the roff renderer the manual tool uses is
another, and the site's HTML is a third, written in the generator and not in
the library.

- The generator imports the library for `Markdown.parse`, the two types and
  `Markdown.firstSentence`. It holds the tree and walks it itself, so it calls
  the library and the library never calls it: no callback, no record of
  functions, no traversal the library would have to own. The public sum type is
  the callback; a record of functions would be the same constructors written a
  second time, a second way beside `match`.
- The `html` function is one `match` clause per constructor of `Block` and of
  `Inline`, producing the fragment a `*_html` field takes. Around it is
  everything the site's own: the tokens, the chapter layout, the filters.
- When the library is next touched, `roff` and its `Manual` record move to
  `tools/manual.ern`, their one user, so that the library is parse, the tree,
  the terminal renderer and `firstSentence`, and the pattern the site uses is
  shown in the tree itself.

**The book pages.** Each of the report's files, the guide and the tour is parsed
whole; a report file is one page, and the guide and the tour are cut at their
headings into chapters ([`decisions.md`](decisions.md)), each page rendered
into `chapter.html` with the base, header and footer fragments. Decided once:

- **Where a chapter is cut.** The guide's and the tour's chapters are their own
  second-level headings.
- **Cross-references become links.** The report writes `§6.5` and
  `Appendix E.17`, which Markdown cannot link and HTML should. The generator
  recognizes the two forms and links them to their anchors
  ([`decisions.md`](decisions.md)), by the rule the documents' tests use to
  check that every citation resolves.
- **Previous and next** come from the chapter order.

**The module pages** are rendered from `man/`'s Markdown
([`decisions.md`](decisions.md)) into `chapter.html`, as any other page is:
the declarations' headings are its contents and their anchors. The terminal's `man` and the shell's
`:doc` show the same parts: three renderings of one source, differing in
layout.

**What the library lacks, checked first.** The tree has headings, paragraphs,
code, quotes, lists, rules and raw HTML, and no tables, which the report and the
plan use. A table block is the library's first addition in a while, admitted
because our own work needs it. Before any template meets a document, a test
parses the three files whole and renders them back, so that every construct they
use and the tree lacks is found at once and not page by page.

**The tour and the shell.** The tour (MVP 3.3) is one more Markdown file through
the same door, its chapters the lessons. Each example is linked
to the live shell once the shell exists, so that a reader runs what the chapter
shows; until then the examples are code blocks as the guide's are.

**`/changes/`** is rendered from the release notes as any other page, and the
footer's version is the toolchain's version text.

## The live shell

The template reserves the terminal and three disabled controls and implements
no fake shell. The real service hosts xterm.js, its stylesheet, a fit addon and
a small session client locally. Start creates an isolated server session and
attaches a WebSocket to its pseudo-terminal; the shell runs on the server
unchanged, behind `Terminal`, since no full BEAM runs in a browser. The terminal
is fitted on resize and the rows and columns sent to the pseudo-terminal.
Connecting, running, disconnected, expired and unavailable are shown as
separate states, announced in one status element, not per output byte. Stop
destroys the session; Restart is a deliberate act and destroys the old one;
disconnection and expiry are never conflated. The sandbox is the operating
system's and not the language's, since Ernest's system modules are ambient by
design: one isolated container per visitor, with limits on time, memory,
processes and network, shown to the visitor, and nothing kept when the visitor
leaves. Isolation, quotas, origin checks, cleanup and the WebSocket are the
server's, the first decision of MVP 4.2.

**The shell beside every page.** Every page with code on it has a button that
splits the screen, side by side or stacked, with a live shell, the same
container the `/shell/` page allocates, and every code block has a button that
puts the block into the open shell so that the reader only presses Enter.
What makes it effortless is the site's to get right:

- **One container per visitor, all over the site.** The web server keeps a
  session for the visitor, and the container belongs to the session: it is
  allocated when the panel first opens and reused on every page after, so the
  shell opened on the guide is the shell on the report a click later. A link
  shared mid-session shares nothing, since the session is the visitor's
  browser's and not the address's. A dropped connection and an expired session
  are told apart. A shell inactive for five minutes goes: a popup warns for
  five seconds, then the panel closes and the container with it, and the next
  open of the panel allocates a fresh one.
- **Two kinds of block.** A snippet, a `type`, a `fn` or an expression, is
  pasted as input and the reader presses Enter. A whole program with
  `export fn main` is loaded as `:load` loads a file, so that `main()` is one
  more Enter away. The generator tells the two apart from the block, and the
  button says Paste or Load, never both.
- **Paste is the shell's input, not the terminal's keystrokes.** A multi-line
  declaration arrives whole, as bracketed paste does, so the prompt sees one
  input, which the shell's line mode handles for a declaration typed across
  lines. Nothing runs until the reader presses Enter, so a block is never run
  by accident and may be edited first.
- **The layout is a toggle**, remembered per visitor, stacked alone on a narrow
  screen. The panel's controls are the shell page's: Start, Stop, the time
  remaining.
- **Which blocks can run in the container.** The guide's chapter 8 needs two
  nodes, the socket examples a network the container does not have, `Os.run`
  programs in the image. Every block carries a mark, as the deployment guide
  marks which commands the tests run and which are shown alone: a block that
  cannot run in the container gets Copy and not Paste, so the button never
  lies. Copy stands beside Paste and Load on every block, for the reader with
  an install of their own. The mark is held by a test that reuses the guide
  tests, which already run the guide's examples: a block marked Paste or Load
  is one those tests run.
- **What is in the image**, decided and listed, since it bounds every example:
  `ern`, the library, the examples, a scratch directory, no network.
- **Capacity.** How many containers at once, what a visitor sees when all are
  taken, whether they wait or retry, and a limit on starts per visitor, so
  that a script cannot churn sessions. The suggestion's "unavailable" state
  needs this policy behind it.
- **A privacy line** on the shell page: no accounts, one cookie for the
  session, what the server logs, nothing kept when the container goes.
- **Two limits on a session, and two tabs.** Inactivity is decided; a hard cap
  on a session's whole time is the suggestion's "limits on time" and needs its
  number. One session opened in a second tab: the second attach takes the
  terminal over, or is refused, never both tabs typing into one prompt.

## What the generator may ask for

The generator and every tool of the site under this directory's `tools/` are written in
Ernest, and what they find missing is added where it belongs, never worked
around in Erlang or behind a `foreign fn`, and never by choosing a smaller task:

- A function the standard library lacks, in `fs.ern`, `string.ern`, `path.ern`
  or wherever it belongs, enters by E.0's four admission rules, weighed one by
  one, and takes the shape the nine shape rules and the tenth give it. Our need
  is the occasion; the rules decide the function.
- A pattern language, a data format or a protocol is a library's work: a
  regular-expression library under `libs/`, as `libs/json` and
  `libs/markdown` are, is written when the generator needs one, decided with
  the user first as CLAUDE.md says, and never improvised inside a tool.
- Something the prelude or the language lacks goes to `language_feedback.md`
  and is discussed before any code goes around it.

Writing the site in Ernest is also writing Ernest: what it feels against a
principle is as much a finding as the pages it produces. The same holds for
ehttpd (MVP 4.1), which the plan's section for it says. Let the need shape
what enters the standard library, the prelude and the libraries, and let the
rules shape how.

## Feasibility and size

Feasible with what exists. A generator of a few hundred lines of Ernest: the
HTML renderer about 150 of them, the token binder 50, and a golden test
rendering one page per kind. Nothing in it needs a feature the language or the
library lacks beyond the table block, and nothing of it enters the library. The
care goes into the templates' token contract and the decisions below, not into
the machinery.

## To decide, before it enters the plan

1. Where a chapter is cut, for the guide and the tour.
2. The token sets per page kind, listed and held by a test.
3. The table block in `libs/markdown`, and the whole-document parse test.
4. The output directory and the `make site` target, and where the templates
   and the generator live in the repository, `site/tools/` or beside
   `tools/manual.ern`, which may move to join it. Since `/man/` renders
   `man/`, `make site` runs `make man` first, or renders whatever `man/` last
   held.
5. The header's list beyond Library and Install
   ([`decisions.md`](decisions.md)): whether the doors, Source and Features are
   in it.
6. Whether a code block is pasted or loaded by its shape alone, or an author may
   mark one.
7. What counts as activity for the five minutes: input at the prompt alone, or
   any page view with the panel open.
8. Which version the site describes, a release's tag with the version in the
   footer, or `main` with a date. It changes how `/changes/` and every citation
   into the report are read.
9. Whether the pages are complete without JavaScript, the panel and the buttons
   added by the script and never required, which also makes the site readable
   by crawlers; and whether the site has a search, a static index, or says it
   has none.
10. Where a citation of the log goes, since the log is not on the site: its
   anchors fit GitHub's rendering, so the link goes there.
11. Accessibility: xterm.js's screen-reader mode, Paste, Load and the toggle
   from the keyboard, focus landing in the shell after a Paste; and whether the
   shell is offered on a phone at all, where the stacked panel and the soft
   keyboard leave half a screen.
12. How the site is built and published: `make site`, and the step that puts
   the output on the host, so that the site is reproducible from the repository
   and never edited in place.
13. The site as a deployment of Ernest's own: ehttpd under the deployment guide,
   the service manager, TLS for the site itself, what is watched and who is
   told. The operator's day applied to the site is the evidence `but_why.md`
   cites.

## Status

Early versions: the templates are a first design, and the generator is not
written. What the discussion has settled is in [`decisions.md`](decisions.md);
nothing enters the plan until the proposal is decided. When it does, the plan's
MVP 4.2 changes with it: it still builds the module pages from the doc chunk's
parts, where `decisions.md` renders them from `man/`. The plan's MVP 4.2
section records what was agreed on 2026-10-10: the generator is a program beside
`tools/manual.ern` against the library's tree, nothing of the site enters the
library, `roff` moves to the manual tool when the library is next touched, and
the generator may come before the rest of the milestone.
