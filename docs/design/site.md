# The site

Status: the site's design note, which changes when the site does. It is not a proposal, and not authoritative.

The website, ernest-lang.org, is a compact language manual with a working terminal. Its homepage answers what Ernest is, why one would use it, and where to start. Every page is generated from this repository at a release's tag by `tools/site.ern`, its modules under `tools/site/` and their one Erlang helper, `ern_site.erl`, from the templates and the assets under `site/`. [`architecture.md`](../architecture.md)'s *The site's generator* says what each module does. [`site/templates/README.md`](../../site/templates/README.md) owns what each template binds, and [`site/projects.md`](../../site/projects.md) the projects' list.

The server is ernest-httpd, a program in a repository of its own. What the server does, the session behind the shell among it, is its own design's, https://github.com/joagre/ernest-httpd/blob/main/docs/design.md, cited below as the server's design.

The plan's MVP 4.2 built the site, and each section below names the log entries that argue it. `make test-site` holds the generator, `make test-site-shell` the blocks the pages offer the shell, and `make test-browser` the client in a browser. A test's comment names the section it holds.

## The root

The site's files as served.

    /                               the homepage
    /404.html                       any unmatched path, served with HTTP 404
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
    /projects/                      site/projects.md
    /assets/css/                    site.<digest>.css, xterm's stylesheet
    /assets/js/                     xterm.js, its fit addon, site.<digest>.js, the session client
    /assets/img/icons/              the Lucide icons and their LICENSE
    /assets/img/icons.<digest>.svg  the same icons, one symbol each
    /assets/img/projects/           each project's icon, <project>.png
    /assets/<logo>                  the logos the site shows, at their paths in assets/

- The site is ernest-lang.org. Every path on ernest-lang.se redirects to the same path there, which is the server's configuration.
- A report page is one of the report's files, whole. A citation's first number or letter names its page.
- A chapter is addressed by its number, as a citation names it.
- Every contents page is generated: a book's from its headings, the report's with its opening from `report/README.md`, and the library's from the indexes of the build's pages, which `make doc` writes: `build/man/README.md`, `build/stdlib/index.md` and `build/man/libs/README.md`. There is no symlink, and no page at two addresses.
- The `/man/` pages are rendered from the build's pages, the Markdown `make doc` writes under `build/stdlib/` and `build/libs/`. The site calls them Library. A module's page shows its `since` line as its metadata under its heading, as a report file shows its version line.
- `/man/` lists the standard library's modules and the libraries in two groups, a module a line, its name and the purpose its own page opens with, and ends with the toolchain's §11. `/man/stdlib/` and `/man/libs/` hold the same lists' halves, so a page's address trimmed to its directory finds a page.
- `site/root/` holds the assets, laid out as served, and no page is written by hand. The templates and their README stand beside it, in `site/templates/`.
- A link names a directory by its own form, `/guide/`, never `/guide/index.html`.
- The server serves a directory's `index.html` without a redirect. It redirects only a directory named without its slash, `/report` to `/report/`, and every path on ernest-lang.se.
- No path holds a version: the site shows one version.
- The header and the footer reach every page.

The log's *ehttpd and the Website*, *The Pages Read Against the Principles* and *The Site's Proposal Read* argue the root.

## Anchors

- An anchor is the citation's own text without its `§`: `#6.5`, `#E.17`, and `#4.2` in the guide. A chapter's is its number or letter: `#6`, `#E`.
- A declaration's anchor is its qualified name as its module's page's heading writes it: `#List.removeAt`, `#Address.call`, `#spawn`. An operator stays as written.
- In a document that numbers its headings, only numbered headings and declarations have anchors, and no anchor is made from a heading's words.
- In a document that numbers none, Why, the questions, Install, Releases and Projects, a heading's anchor is its GitHub slug, which the generator computes as the documents test does: the heading in lower case, keeping a letter, a mark, a number, `_` and `-`, a space written `-`, and every other character dropped, the second heading of one slug numbered `-1`. A link written for GitHub then holds on the site: `#a-deadlock-of-the-whole-program-is-found`. A reworded heading breaks a link from outside, and the generator's check catches every link inside.
- The questions' questions are `###` headings, so each has an anchor and the page a sidebar.
- A citation becomes a link to its anchor, its page found as the documents test finds it: "§6.5" is `/report/language.html#6.5`, "Appendix E.17" `/report/library.html#E.17`, "guide §4.2" `/guide/4.html#4.2`, "deployment guide §6" `/deployment/#6`, `List.sort` `/man/stdlib/list.html#List.sort`.

The log's *The Generator's First Stage*, *The Generator's Second Stage* and *The Site's Proposal Read* argue the anchors.

## The homepage

- It is `home.html`, its text the site's own. The README is the repository's, and the homepage takes nothing from it.
- In order: an opening under its heading, Why's list beside it, and a small example with its output.
- The heading and the opening lead with what Ernest adds that no reader expects, a process started on another node bringing its code along. Then they say what kind of language it is and what it is for. They state what Ernest does and never what another language lacks.
- Each thing is said once on the page: the opening says the effect, and the list beside it the means.
- The list, "What Ernest adds", is four of `guide/why.md`'s claims, the ones a newcomer reads at once: code travels, the mailbox in the function's type, a distribution built for a WAN, and a deadlock of the whole program is found. Each is shown as its bold name and its first sentence alone, word for word, linking to its heading in Why. The rest is Why's.
- A test runs the example, so the example's button runs what the page shows: a process started on the container's second node, its code typed into the shell and sent there.
- The opening and the list are visible on a desktop without scrolling. Where they are not, the page is cut, not the rule.
- Under the example stands its button, "Try it", alone, the page's one action and its one strong color. It is a block's Paste made prominent, and its label never changes. It puts the example's code into the shell, opening the panel and starting a session where needed, and the code waits there for Enter.
- On a phone the button opens `/shell/` with the code waiting, and without the script it is a link to `/shell/`.
- After it stand three doors, in this order, each with its question and of one weight: Tour, "show me the language"; Guide, "help me write programs"; Report, "tell me the rules".
- Why is the link ending the introduction's paragraph, "the whole argument".
- Deployment is reached from Install, the guide, the tour, Why, the questions and the footer, never from the homepage's body.

The log's *The Site's Look, by Hand*, *The README Recut* and *The Site's Proposal Read* argue the homepage.

## Every page

- The header holds Why, Tour, Guide, Report, Library, Shell, Install, and Source, the GitHub link. The terminal is labeled Shell, as `ern shell` names it.
- There is one footer, the homepage's too, in two lines. The first holds the rooms the header leaves out: the questions, Deployment, Releases and Projects.
- The second holds the page: "This page:" and its source file's path in the repository, with its last commit date at the tag, which the checkout's `git log` gives, since an export has no history. Then the version the site is built from, "0BSD license", "Report a defect" for the issues, and "Served by ernest-httpd, written in Ernest".
- Previous and next stand above the footer on a tour, guide or report page, and not at its top. At the top, the book's title above the chapter's heading links to its contents page.
- On a narrow screen the header is the stoat with "Ernest" and a `<details>` menu holding its links, folded as the contents list is, by the browser and no script.
- Each page has a title, a one-line description and `ernest-social-light.png` as the image a shared link shows. The description is the page's first sentence, a label that opens its paragraph, `**Note.**`, passed over, but for a tour chapter, which takes its line from the book's opening, a library's contents page, which takes its heading, and the homepage and the shell's page, whose sentence the generator states.

The log's *The Pages Read Against the Principles* and *The Site's Proposal Read* argue it.

## The other pages

- Install is the README's *Installing* section, which holds the supported platforms, the installation, its verification and the first command.
- Releases is `CHANGES.md` rendered as it stands, newest first, each release's note as the release step writes it there.
- Projects is `site/projects.md`, which owns its list and its form, and a test holds each line to that form. A line opens with the project's icon, copied byte for byte into `/assets/img/projects/<project>.png` and shown at 40 × 40 with the site's rounded corners. The project's name is in the text's face and links to its repository.
- Library does not lead to Projects. The footer does, and one sentence of Why's *Reading on*.
- The shell page is the heading, one line, and the panel in the page's frame, with no hide and no header buttons. The terminal takes most of the space, with the panel's controls above it and the warning banner when it comes (*The live shell*). There is no Examples control: the pages' blocks are the examples.
- Beneath the frame stand two short columns, the session's limits as a list and the privacy line: no accounts, one cookie, the layout kept in the browser, what the server logs, nothing kept. Without the script the frame says to install Ernest and run `ern shell`.
- On the shell page a dropped connection and an expired session are told apart, nothing is erased silently on a reconnect, and nothing runs but by the visitor's act. Nothing starts until the visitor presses Start or a Paste brings an input.

The log's *Projects, a Page of Their Own*, *The Release's Note, Written Once* and *The Site's Proposal Read* argue them.

## The look

- Semantic HTML and one shared stylesheet. No framework, font download or icon runtime.
- No inline script, since the server's `Content-Security-Policy` allows only its own scripts (the server's design, *The deployment*). No inline style in the site's own pages; the policy allows inline style, which xterm.js sets.
- System sans-serif for prose, system monospace for code and the terminal.
- The browser's light or dark preference. Neutral backgrounds, dark text, and one accent color for links, active navigation and focus. The logo's brown and cream are for warmth, not on every control.
- Thin rules between sections. No cards, shadows, oversized panels or decorative illustration.
- Prose is 70 to 80 characters wide, code and the terminal wider. A narrow contents sidebar stands on a desktop, an expandable contents list on a phone.
- Keyboard focus is visible.
- The logos are the repository's `assets/`, of which the generator copies the three the site shows to `/assets/`, each at its path in the repository. `site/root/` holds no copy. A file the site takes from the repository keeps the repository's hierarchy, as `/man/` keeps the build's pages' under `build/`, `/man/stdlib/list.html` for `build/stdlib/list.md`.
- The site shows no full logo. Every page's header, the homepage's too, links home with the stoat, `ernest-mark.svg`, beside "Ernest" in text, and the homepage opens with its paragraph under a heading in text. The full logo stays where no header stands: the READMEs and the image a shared link shows.
- The favicon is `ernest-avatar-64.png`, which every page names, and the root serves no `/favicon.ico`.

The log's *The Site's Look, by Hand* and *The Site's Proposal Read* argue the look.

## Links

- A source's own link is written for GitHub and is relative: one that begins with `/` is refused.
- The generator maps a source's own link one of four ways. To the page of a document the site shows, `library.md` to `/report/library.html`. To a numbered heading's number anchor, found by the digits the link's fragment begins with, the whole slug deciding only where two headings' numbers give the same digits, a second heading of one text numbered `-1` as GitHub numbers it. A directory as its `README.md`, by which GitHub shows it, `report/` to `/report/`. And where the site does not show its target, to it on GitHub at the tag the site is built from: a file, `LICENSE`, or a directory, which the link names by its own form, `examples/`. A directory named without its `/` gets GitHub's address of a file, which GitHub redirects to the directory.
- A static page or a template links by hand, to a page's directory form.
- A citation is a form the documents test reads: `§x.y`, alone or after "report", "guide" or "deployment guide"; an appendix, `Appendix E`, or one of its sections, `Appendix E.17`; and `E.n`; besides the log's *Title* and a qualified name. A bare `§` is the guide's own in `guide/language.md`, and the report's in every other document. A reference finer than a section is written with its section, "E.0 shape rule 10", whose `E.0` links.
- A link into the guide holds while the guide's numbers hold. A link from outside, made before a renumbering, may land on the section that took its number, and nothing redirects it, since a fragment never reaches the server.
- A report section carries a computed margin line naming the guide's sections that cite it, each once and each a link: "Taught in guide §2.5, §3.6". What else cites it is not listed.
- A citation of the log links to the log on GitHub, by the file and the anchor the log's own index gives the entry, which the documents test holds equal to the heading's. The form is the log's *Title*, and in `CHANGES.md` an entry's title alone, as the release step writes a change's line. A title that no entry or two entries hold is refused.
- On a module's page a declaration's own name links nowhere within its own section. The code that declares a type is a program's, and a signature and a prelude block show the library's own.
- Ernest code is colored when the site is generated, by `ern`'s own lexer. The generator reaches it by a `foreign` declaration over its own helper, `ern_site`, which calls the toolchain's lexer module.
- A console block that is no transcript is plain monospace, as written: `ern build` colors nothing (report §11.2), and only the live shell shows the shell's colors. A transcript's inputs, their prompts and what the shell printed are marked, the prompt and the output muted.
- A qualified name in code, or in backticks in prose, `List.sort` or `Markdown.Block`, links to its declaration in `/man/` where it is a heading of a module's page, a type or a function, and no code on its page declares a type of that name. Any other name is text, never an error: a bare name, and a member of a type the page declares (report §4.2).
- The generator's last step checks every internal link and anchor of the directory it wrote, made or written, and fails on one that does not resolve. So every run is checked, a test's as `make site`'s.

The log's *The Generator's First Stage*, *The Generator's Third Stage*, *The Start Line's Length*, *The Rationale Is a Synthesis* and *The Site's Proposal Read* argue the links.

## The templates

[`site/templates/README.md`](../../site/templates/README.md) lists each template with its tokens, and a test holds each template to its list. The rules they are written by:

- The HTML is written to be read, by hand in a template and by the generator in a page alike, so that a page's source reads as its template does. Each block element stands on a line of its own, indented four spaces a level, as `docs/code_style.md`'s *Every language* says of every file. Inline content stays on its block's line, a paragraph one line however long. A `<pre>` begins at its line's indentation and holds its body as shown, from the line's start.
- HTML5 as written today: lower case, every attribute quoted with `"`, no `/>` on a void element, and every end tag written, `</p>` and `</li>` among them. A plain token's escape leaves `'`, which an attribute quoted so holds.
- An icon is one line, a `<use>` of its symbol in the icons' file, `{{icons}}#name` in a template, which the generator gathers from the icon files as it writes the site. `site/root/` holds the icon files alone.
- The stylesheet lays out with flex and grid and their gaps, so the whitespace between elements never shows.
- No control the script works stands in the HTML: Copy, Paste and Load, a transcript's Paste for each input, the example's button and the panel's toggle are made by the script, and a page without it shows none. The HTML holds what the generator decided, a block's `data-shell="paste"` or `"load"` and a signature's `data-tools="none"`, and `home.html`'s own `data-shell="start"` for the example's button, and the script reads it.
- A template is a flat token file, cut at its tokens once and joined with the values. There is no templating language.
- A plain token is escaped. A `*_html` token takes only HTML the generator makes from the repository: rendered Markdown or code, navigation or a template's fragment. An HTML block a document writes is written into its page as it is, and so are an icon file's attributes and children into the icons' file.
- The generator is given the server's configuration file. It reads from it the shell's path, its lifetime, its warning, the shells at once, the starts allowed within a time and the command's memory flag, each a plain token. So the shell page says what the server enforces and nothing is written twice.
- A list in a page, `contents_html`, `navigation_html` or `entries_html`, takes its item's look from a fragment file beside the page's.

The log's *The Site's Look, by Hand*, *The Client's Questions* and *The Site's Proposal Read* argue the templates.

## The generation

- One generator, `tools/site.ern`, written in Ernest. It reads the repository, writes static files, and ends. It refuses an output directory that is there already, a configuration with no `shell`, and a template given the wrong tokens.
- `site/` holds `templates/` and `root/`, the homepage's example, `example.md`, the projects' list, `projects.md`, and `unrunnable.md` (*The live shell*).
- The site is this repository's whole, its shell page among its pages. The generator reads this repository's documents at a tag. A test holds it to the pages written from a fixture, `test/fixtures/site/`: a tree with each document at the path of the one it plays, a configuration, and the expected pages.
- Every page is generated from what the repository owns: two templates and two pages of their own, all four standing on `base.html` with its header and footer.
- `page.html` is a Markdown document with a sidebar of its headings and a footer naming its source. It serves every chapter of the tour and the guide, each file of the report, every `/man/` page, Why, the questions, the deployment guide, Install, Releases, Projects, and the 404 page with its fixed body. What differs between them, a previous and a next, and what the footer names, is data the generator passes, and a slot without it is empty.
- `toc.html` is a contents page, a book's or a directory's opening and its list of links: `/tour/`, `/guide/`, `/report/`, `/man/`, `/man/stdlib/`, `/man/libs/` and `/man/libs/<name>/`. `home.html` is the homepage and `shell.html` the full-page shell; each is one page, not a template.
- A template is named for what it is, and what it is written as is the root's. A directory's page is its `index.html`, the homepage's, a contents page's, Why's and the shell's alike, and a chapter is its number, `/guide/3.html`.
- A book's opening, its title and its paragraphs before its first chapter, heads its contents page.
- A page's footer names the file it renders: `site/templates/home.html` for the homepage and `site/templates/shell.html` for the shell's page, the README for Install, `CHANGES.md` for Releases, a document's Markdown, and a module's `.ern` for a `/man/` page, since the page is itself the build's. The prelude's page, whose source is no file, a contents page and the 404 page name none.
- A page's sidebar lists its anchored headings, two levels deep. A module's page lists its declarations instead, by their short names, and a document of one page has a sidebar only where it has two headings for it. The sidebar stays in view, scrolling on its own where it is longer than the window, and the script marks the section being read and keeps it in the sidebar's view. Its label shows on a phone alone, where it opens the fold.
- The sources stay Markdown: the report, the guide, the build's pages, and the tour's document, `tour/README.md`. A source's opening logo and its contents block are dropped, since the site has its own.
- A chapter of the guide or the tour is a second-level heading. Previous and next follow their order, and the report's pages run language, toolchain, library.
- The library's pages are written first, and the modules' pages they read are held no longer than that, so that no later collection of the run copies them (the log's *Lean at the Limits*).
- `make site` builds the site from a release's tag without a worktree. It exports the tag with `git archive` into `build/site-source/`, builds the toolchain there, the checkout untouched, and runs `make doc` there, which writes the pages. It wipes `build/site/`, copies the root and the logos there, and writes every generated page beside them, so a page whose source is gone goes. `build/site/` is never edited in place, and its copy to the host is the operator's step, the server's own.
- `make site` takes any revision as its tag, a release's for the site and `HEAD` for a look at the work in hand. A revision whose tree holds no `site/templates/` is refused, since the generator comes from it.
- Everything comes from the tag, the documents and the site's own files, its templates, its root and its generator. So the site is a release exactly, and a fix to the site's look or its generator goes live with the next release.
- A page's text, links and navigation are complete in its HTML, and read without a script. A script adds to a page, the shell panel, the navigation that keeps it and the code blocks' buttons, and never holds what the page says.
- A stylesheet, a script or the icons' file is written under a name that holds a digest of its content, the first eight hexadecimal digits of its SHA-1, `site.3f9a2c1e.js`, and every page names it so. The server sends no `Cache-Control`. The vendored files keep their own names inside it.
- The site runs on ernest-httpd (the server's design, *The deployment*).
- `make install` ships no page of the site: the pages are the server's, their links absolute and the shell panel on each. An installation's documents stay each in the form its reader uses (the log's *Every User's Document Installed*).

The log's *The Generator Before MVP 4.15*, *The Generator's First Stage*, *The Generator's Second Stage*, *The Generator's Third Stage* and *The Site's Proposal Read* argue the generation.

## The live shell

The server side of the shell is the server's: the pseudo-terminal, the container per visitor and its image, the session's timeouts and a second tab's takeover. It stands in the server's design, from *The WebSocket* to *The deployment*. What follows is the page's side.

**The container's two nodes.** The visitor's container runs two nodes, so that a visitor tries the homepage's claim: `foo`, started with no program, and the shell, started with `--config-dir a`. The two list each other's keys, made when the image is built. Each node's `ernest.conf` states `"limits": {"processes": 65536, "ports": 4096}` (report §12.5). The image, the container's memory and its numbers are the server's (the server's design, *The deployment*).

**The terminal.**

- xterm.js, its stylesheet, a fit addon and a session client, self-hosted, each vendored file with its row in `THIRD_PARTY_LICENSES`. xterm.js and its stylesheet load only when a session first starts. A terminal that does not load is *disconnected*, and a second Start while it loads opens no second socket. A WebSocket at the configuration's `shell.path`, which the generator reads from the server's configuration file, leads to a pseudo-terminal running `ern shell` unchanged (the server's design, *The shell*).
- xterm.js keeps a scrollback, a scrollbar, the wheel and Shift+PageUp, in the browser alone. The shell writes above its live region on the ordinary screen, and a program on the alternate screen has no scrollback while it runs.
- The client sends the panel's size as its first message and at each resize, which the server takes as the session's start and its terminal's size. The messages' forms are the server's design's, *The shell*. A session the server says this browser joined is asked to draw its line again, and a paste into it is bracketed by the page itself.
- xterm.js takes Alt, and Option on a Mac, as Meta, so the shell's M-Enter works in the panel.
- Everything is reachable by keyboard. Focus lands in the shell after a Paste, and xterm.js's screen-reader mode is on. The shell takes Tab, Shift-Tab and Escape, so F6 in the terminal moves the focus to the panel's controls. It is the client's own key, since §11.2's editor binds no function key, and `/shell/`'s notes name it once.

**The session's states.**

- Seven states, each announced once: connecting, running and disconnected, the page's own, and expired, taken over, unavailable and stopped, one for each close code the server sends, 4001 to 4004 (the server's design, *The shell* and *The sessions*).
- A session's warning is a banner with Extend, shown when the server's warning comes, and the banner is no dialog. It says once the seconds the warning carries, as "ends in" and the seconds, and nothing counts down. A key or Extend keeps the session, by the lifetime the server's design owns, *The sessions*.
- A session that expires closes its panel and gives the page back its width. A short line says that the shell ended after the configuration's lifetime without a key, which the generator reads, and that opening it starts a new one. The layout kept in local storage is unchanged, so the next Paste or Open shell opens the panel as the visitor last had it. A takeover and *unavailable* show in the panel.
- The line is a snackbar, a slim notice at the window's bottom edge, whatever the layout was: the sentence, an icon that opens the shell and one that closes the notice. It stays until the visitor clicks one of them or anywhere on the page, or presses Escape outside the terminal, and no timer removes it. It is announced as a polite live region; the warning alone is an alert. Its open icon opens the panel and starts a session. `/shell/` shows no notice, its frame holding the end's mark.
- Stop ends the session, and Restart is a deliberate act that ends the old one. What they end, the container, is the server's (the server's design, *The sessions*).
- A session's end is marked in the terminal, dim, after its last output, in the bar's word for it. The screen stays to be read, and the terminal takes no keys until a new session starts. A Start after an end begins below the ended screen, and a Restart begins on a clear one.

**The panel.**

- The script makes the panel and its toggle on every page, and no template holds them. Its layout is kept in the browser's local storage and never sent to the server. No panel opens until the visitor asks, and a page loaded whole opens it where the visitor left it open.
- Its toggle is two buttons in the header, beside and below. The open layout's is pressed, pressing it again closes the panel, and pressing the other moves it. The header spans the window.
- Beside, the panel fills the window's right side below the header, at 45% of the width, and the page scrolls in the rest. Below, it takes 40% of the height and the page scrolls above it. A handle on its inner edge resizes it, by the pointer or the arrow keys, within 25 to 70% of the width and 20 to 75% of the height, the size kept with the layout. Below 1000 px only below is offered. On a phone, a window of 760 px or less, no panel is offered, and `/shell/` still serves.
- The panel's bar holds the session's state, Start where no session runs and Restart while one does, Stop, and Hide. Hide is the icon of the header button that opened the panel; it hides the panel and keeps the session, and Stop alone ends one. A session that runs while the panel is hidden marks that header button with a dot.
- Opening moves focus into the terminal. Closing returns it to what opened the panel, a block's Paste among them, and to the header's button where that is gone. Escape is the terminal's.
- The session's limits and the privacy line stay on `/shell/`.
- Copy, Paste, Load, Hide and the header's two buttons are small icons, each with a tooltip and an accessible name, `Paste into the shell`. Start, Restart and Stop are an icon with its word, and Extend its word alone.

**A page kept under the panel.** While the panel is open, or its session runs hidden, a link to another page of the site fetches that page and puts its `<main>`, its title, its footer and the header's links in place of the old, the address moved by the history. The panel, its socket and its screen stay, and no page counts as shown while one is on its way. Back, forward, the scroll, an anchor and focus behave as on a page loaded whole, which the browser test checks.

With the panel closed a link loads its page whole, and on a phone always. So does a page that names another script or stylesheet, a newer site's. Every page stays a whole file.

**Which block has which button.**

- Copy is on every block but a declaration's signature on a module's page, which has no tool.
- Only an `ernest` block that runs alone in a bare shell has Paste or Load: one the guide tests take as a module of its own. One joined with the other blocks that name its file is a piece of a program and has Copy alone. The generator decides it by the guide tests' own grouping, for the guide, Why and the questions alike, and no mark is written by hand.
- A block of the guide, Why or the questions with `export fn main` is Loaded: pasted as one declaring input and entered (report §11.2), and then `main()` typed and not entered, so that it is one Enter away. Any other is Pasted. No file is written, and nothing crosses the socket but the terminal's bytes.
- Every block of the tour has Copy alone, as have the README's, the release notes', the deployment guide's and the report's.
- Three more kinds of `ernest` block have Copy alone. One is a block the shell cannot take as one input, a top-level `let` beside another declaration, or declarations followed by an expression. The generator reads it from the block's paragraphs, as `ern test` reads an example's (report §11.2), and a paragraph whose first token is indented or a closing delimiter continues the one before, since the shell takes a paste whole. One is an example on the page of a library outside the standard library, which the panel's shell reaches only by `:load`. One is a block the bare-shell test finds it cannot run, a program that needs its own terminal or arguments.
- `site/unrunnable.md` lists each block of that last kind by its page and its first line. The generator reads it, and the test holds it equal to what it finds, so no source is marked.
- `ernest-fragment`, `ernest-rejected`, `ernest-prelude`, a console that is not a transcript, and another language's block have Copy alone.
- A transcript is a console whose inputs are `> ` lines. Each input ends in its own Paste, which puts that input into the shell without its prompt, as one input. No button pastes them all. The shell's output has no button, and the `>` stays text.
- A transcript whose session a bare shell cannot hold has Copy alone, which the generator reads from the session's first line: one begun with a module loaded, `ern shell words.erc`; one that loads a module by `:load`; and one begun with `ern shell --config-dir`, a node's, or `--attach`, an operator's (§11.2 *The attached shell*). The homepage's example alone is a node's session with Paste on each input, since the container's shell is that node, and `ern_tour_tests` runs it on two nodes.
- A test runs every block given Paste or Load, and every transcript input given Paste, in a bare shell, the homepage's aside. The guide's transcripts are tested as transcripts, so every input offered is one the tests have run.

**A Paste.**

- A Paste arrives as one input, as bracketed paste does, and nothing of it runs until Enter.
- A Paste or a Load is the visitor asking for the shell. Where no panel is open, the click opens it in the layout kept in local storage, beside at first and below where the window is under 1000 px, and starts the session where none runs, the input arriving once the prompt does. On a phone the click opens `/shell/` with the input waiting there.
- A paste for a session that is starting waits for the session's first output.
- An input's Paste is a small icon drawn bold, in the accent's color when pointed at or focused, and visible without a hover. It is held at the block's visible right edge where the input is longer than the block is wide.
- A block's tools show on hover or focus where there is a fine pointer, on the block's own color. On a touch screen they stand on a row of their own above the block, so they never cover its code.

**The browser test.** `make test-browser` stands outside `make test` and is a step of the release review. Erlang under `test/` drives a headless Chrome over its DevTools protocol, Chrome the one dependency it adds. It serves the fixture's pages by OTP's `httpd`, with a stub socket that speaks ernest-httpd's protocol for the session's states. A real shell behind the socket stays the check by hand on a server before a release ([`reviews/release.md`](../reviews/release.md)).

The log's *The Site's Look, by Hand*, *The Generator's First Stage*, *The Generator's Second Stage*, *The Client's Questions*, *A Node's Limits*, *A Node's Schedulers*, *The Browser Test's Flake* and *The Site's Proposal Read* argue the live shell.

## The documents

The site shows one document for each question a reader brings.

| The question | The document | Its page |
|---|---|---|
| Should I care? | `guide/why.md` | `/why/` |
| Show me, in order | the tour, `tour/README.md` | `/tour/` |
| How do I write it? | the guide, `guide/language.md` | `/guide/` |
| What exactly is the rule? | the report | `/report/` |
| What does this function do? | the library's pages, which `make doc` writes under `build/` | `/man/` |
| How do I run it? | `guide/deployment.md` | `/deployment/` |
| What does this command do? | the report's §11, and `man ern` at a terminal | `/report/toolchain.html` |
| Let me try it | the shell | `/shell/` |
| What is in each release? | `CHANGES.md` | `/releases/` |

The questions, `guide/faq.md`, stand at `/faq/`. `src/shell/README.md` is for a reader of the code, and `CONTRIBUTING.md` for one who would take part; neither is on the site.
