# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log.md`](log.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone ends the file. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in a dated entry of the log; nothing stands between.

---

## Where we are

**MVP 4.0 is done**, a shell attached to a running node, on 2026-10-31, and Ernest 0.7.0 of
2026-10-31 is the last release, the release review before it read, its eight batches decided and
built (the log's *The Release Review Before 0.7.0* and the entries its row names). No promise of
stability is made, and a change to the language, the standard library or the libraries is driven
by a need met in use and recorded as `docs/language_feedback.md` records one.

Next is the pun; then ernest-httpd, the website and the shell's second round (the log's *The Road
to 1.0, Ordered*), and MVP 4.4 last, the promise, the cost, the full review and Ernest 1.0, where
the road ends and a program begins (the log's *MVP 4.4, the Road's End*); the back end to BEAM's own instructions that closed the road is not built,
decided 2026-10-30 (the log's *No Back End to BEAM's Own Instructions*). A finished milestone is a
row of the table at the end, its reasons in the log entries the row names.

---

## The pun (`Desk(=local)`), a day, next

A field given or matched by the variable of its own name is written once, `Desk(=local, =size)`
for `Desk(local = local, size = size)`, in a construction and in a pattern alike, decided with the
user on 2026-10-30 (the log's *The Pun*): the repository's own Ernest writes the pair at 190
sites. The mark is the pair's own `=` with the repeated name left out; the log weighs the bare
name, which Ernest's parentheses make a call, the dot, and the marks other languages chose.

1. **The report first**: Appendix A's `FieldSet` and `FieldPats` gain `"=" ident`; one sentence
   each in §5.6 and §5.10 naming the *pun*; principle 2's sentence on a second spelling admits the
   pair of a field with the variable of its name beside its pair with a namespace's declaration;
   Appendix F's line.
2. **The parser and the checker**, the emitter untouched, with a test citing each section; a pun
   in a single-positional constructor, `Some(=x)`, is refused naming the form to write.
3. **The sweep**: every site of the repository's Ernest, the guide's and the tour's blocks among
   them, written as a pun where the names agree; `guide/style.md`'s rule that they are; and
   `ern format` leaves it to the writer, decided (the log's *The Pun's Opening Round*), the style
   test refusing `name = name` in the repository's own sources.
4. **The programs outside**: the pun needs the release that carries it, so ernest-template's
   floor rises to that release, and each copy's by hand, ernest-epx's and ernest-httpd's, as the
   template's memory of copies says; ernest-epx's Ernest is swept as item 3 sweeps this
   repository's, every `Foo(line = line)` written `Foo(=line)`, and ernest-httpd's where it has
   any; and each loses the `receiving e` written on a timed wait, which §4.5 now refuses.
5. **`make version V=x.y.z`**, done 2026-11-01 (the log's *`make version`, Appendix D Whole, the
   Settler's Restart*): after a tag the release step runs it to the next minor at once, so the
   checkout says `0.8.0-dev` while 0.7.0 is the latest release.
6. **Appendix D writes out `libs/ets` whole**, done 2026-11-01 (the same entry), a test holding
   D's code to the source from then on.
7. **The settler's restart case tested**, done 2026-11-01 (the same entry); E.28 gained that what
   a load's undoing kills has ended before the load answers or the caller goes on.
8. **The guides' lines of the release review read.** The deployment guide's §5.3, the language
   guide's §8.9 and the README's opening were written by the review's batches and read by no
   reader, since the round read the report's diff alone (`docs/release_review.md` now reads the
   guide's too): one cold reader over `git diff 36b94d31 v0.7.0 -- guide tour README.md`, its
   lines sorted and made as a review's are.
9. **The shell's `session_names` test, red once under the full run's load** on 2026-11-01 and
   green in thirty reruns alone: `:processes` is asked before a process just spawned has reached
   its `receive`, so the line it shows lacks `receiving`. The fix's shape is the test's, which
   waits for the two processes to be receiving before it asks, as `Test.until` waits; made with
   item 3's sweep of the shell's tests, and diagnosed there if the wait does not end it.

The round that opened the milestone on 2026-10-31 decided the formatter's answer and the ten lines
of `language_feedback.md` open that day, so that the milestone closes with the file empty (the
log's *The Pun's Opening Round*). Three are built before item 1, each with a test citing its
section: a `receive` guard's operand may be a field selected from a variable in scope (§6.3), the
help line that named a `let` before the `receive` going; a `receive` with an `after` clause alone
makes no function process-only (§3.9), the checker's mark changing and every `receiving e` written
on a timed wait, which §4.5 now refuses, swept from the repository's Ernest; and the shell's line at
a binding's end names the site alone, `Tcp.listen ended with l` (§11.2). The seven others are kept
or dropped in the entry.

---

## MVP 4.1 (ernest-httpd, and the libraries it wants)

**ernest-httpd**, an HTTP/1.1 server written in Ernest, in a repository of its own, decided with
the user on 2026-10-10 (the log's *ehttpd and the Website*): the base of Ernest's own website, MVP
4.2, and the first program built against an installed Ernest by a build of its own, which the
examples cannot be.

What it asks of Ernest is `docs/proposals/httpd/proposal.md`, begun 2026-10-26 as the server's
whole proposal, read back on 2026-10-30 and ready the same day, and split that day when the
server's repository was made: TLS in `Tcp`, a pseudo-terminal in `Os`, the five libraries with
their shapes, the installation and the release stay here; the server itself, what of HTTP/1.1 and
WebSocket it implements, its sessions, its limits, its configuration, its log and its life under
systemd, is its repository's own proposal and plan. This plan records what it asks of Ernest,
written as it asks, in the proposal's order.

What it lacks is added where it belongs and never worked around in Erlang or behind a `foreign
fn`: a function the standard library lacks enters by E.0's admission rules, our need the occasion
and the rules deciding the function; a format or a protocol is a library's; what the prelude or the
language lacks goes to `language_feedback.md` first, as any Ernest written here, and is discussed
before any code goes around it (decided with the user on 2026-10-10, with the site's generator,
MVP 4.2).

The work goes in three steps, decided 2026-10-30: items 1 to 3 here, closing with an archive;
then the server's milestone 1 whole in its repository, item 4, which is that milestone and no
item of this one; then items 5 and 6 here, the libraries reshaped by their first user. The
server's CLAUDE.md carries the procedure its side follows.

1. **The report first**: `Tcp.listenTls` and `Tcp.connectTls` in E.18, answering the same socket
   as a plain one, the handshake in the socket's process after `accept`, `listenTls`'s
   `Other(text)` for a certificate or key the host refuses, and the host's backlog stated;
   `Os.startTerminal` and `Os.resize` in E.23 through E.0's admission rules, one address with
   `start` and one stream out; and a section in Appendix G for each of the five libraries.
2. **The runtime's two additions**, the riskiest work, before anything stands on them: TLS in
   `Tcp`'s socket process over the host's `ssl`, and the C helper's `forkpty` and resize behind
   `Os`, on Linux and macOS.
3. **The five libraries**, each a source root under `src/libs/` with the standard library's
   discipline and its page: `base64` and `crypto`, which `websocket` needs; `time`, the calendar,
   with no `sleep`, since a `receive` with an `after` clause alone is the language's wait for a
   time and a program that paces itself by the clock derives the delay from the clock (decided
   2026-10-31, the log's *`sleep` Is a `receive` With `after`*); `http` with its client half, whose first use beside the tests is a `fetch` example that
   reads JSON over HTTPS with a verified certificate; then `websocket`, with a client's masked
   frames.
4. **The server, ernest-httpd's milestone 1 whole**, by its own repository's plan, written once
   item 1's sentences stand and built once items 2 and 3 do, against Ernest installed from
   `make release`'s archive and never a checkout; what it meets of Ernest's, an attached shell at
   the server's node among it, comes here as a line of `language_feedback.md`, is fixed in the
   checkout and the archive made again, with no public release between.
5. **The terminal tests over `Os.startTerminal`**, dropping `test/ern_pty.py`, an item of its own
   once item 2 stands.
6. **A release of Ernest**, 0.8.0, when the server first serves the site, carrying the libraries
   after their first real user has shaped them; 0.7.0 is the attached shell's.

The site's content, MVP 4.2, runs beside any of it, since its generator needs nothing of the
server.

---

## MVP 4.2 (the website)

Ernest's website, served by ernest-httpd (MVP 4.1), decided with the user on 2026-10-10 (the log's
*ehttpd and the Website*): what Ernest is and its six claims, the three ways in, the tour, the
guide and the report, each with the reader it is for (the log's *The Tour Written*), the
library's pages, and a live shell, a terminal in the visitor's browser connected by WebSocket to
`ern shell` behind a pseudo-terminal on the server, since no full BEAM runs in a browser.

Its design is `docs/proposals/site/decisions.md`, begun 2026-10-13, read back on 2026-10-30 and
ready the same day: the docroot, the anchors, the homepage, every page, the look, the links, the
templates, the generation, the live shell's page side and the documents; the first design's
templates and mockup stand beside it. Its sandbox is the operating system's, one container per
visitor running the plain shell, whose server side is the httpd proposal's; a sandbox of the
language's was weighed and set aside on 2026-10-13 (the log's *ehttpd and the Website*), and the
attached shell, MVP 4.0, is the operator's alone.

1. **The look, by hand, before any generation**, decided 2026-10-30, at least a day: the
   templates and the mockup pages read against the decisions in a browser, each kind of page
   for its look, its navigation, its icons and its feel, held consistent with every other kind, `page.html`,
   `toc.html`, `home.html` and `shell.html` on `base.html`, the fragments for a list's items,
   the stoat in the header, the favicon, the footer's rooms, the homepage's order and the
   panel's controls, no inline script or style under the server's policy.

   The mockups are written over a fixture document in Lorem ipsum that carries every shape a page holds, prose,
   headings, a code block, a console transcript, a table, citations and a margin line, and one
   mockup over a real report section beside them, since Lorem never wraps a long title; `site/`
   at the repository's root holding `templates/` and `docroot/`; xterm.js and its fit addon
   vendored, with their row in `THIRD_PARTY_LICENSES`.
2. **The generator**, `tools/site.ern` beside `tools/manual.ern`, in Ernest over `libs/markdown`'s
   tree, `Block` and `Inline`, an `html` function of one clause per constructor; the library
   renders to its tree and to the terminal alone, and nothing of the site enters it (decided
   2026-10-10), `roff` moving to `tools/manual.ern`, its one user, when something next touches the
   library. Its first job is item 1's mockups, rendered from the fixture through the templates,
   with a test holding what it writes equal to the committed pages, so that the look decided by
   hand and the generation never drift; a test holds each template to its tokens the same way.

   It reads the repository and writes static files: the pages of the report, the guide,
   the tour, Why, the questions, the deployment guide, the README's *Installing*, the release
   notes and `docs/man/`'s Markdown; the contents pages; the anchors, the citations' links and a
   report section's margin line; Ernest code colored by a `foreign` declaration over the
   toolchain's lexer; which buttons a block gets, Copy alone for a transcript the container
   cannot hold, a node's or an attached session's, read from its first line; the shell page's
   limits read from the server's configuration; each page's sidebar, title, description and
   footer.
3. **The document the site lacks**: the root `CONTRIBUTING.md`, written before the site goes
   live, saying that Ernest takes no contribution before 1.0, a defect found going to the
   repository's issues and nothing else (decided 2026-10-30); the Releases page is `CHANGES.md`, which the release step writes from the next release
   on (the log's *A Release Carries No History*, sharpened 2026-10-30).
4. **The live shell's page side**, the session client in JavaScript over ernest-httpd's socket:
   the panel's size sent first and at each resize, the seven states, the panel on every page with
   its layout in local storage, Copy, Paste and Load on a code block, Load pasting the block as
   declarations with `main()` typed, a transcript's Paste for each input, the warning banner with Extend,
   the snackbar at a session's end, and everything reachable by keyboard with xterm.js's
   screen-reader mode on.
5. **The build and the deployment**: `make site` from a release's tag by `git archive`, given the
   server's configuration file, the toolchain built there and `make man` run, the check of every internal link and anchor, the
   copy of `build/site/` to the host, and the site live at ernest-lang.org with the smoke test
   against it.

## MVP 4.3 (`:trace f`), about a week

The shell's second round, decided with the user on 2026-09-30 (the log's *The Shell's Second
Round*) and decided again on 2026-10-30 against the attached shell (the log's *The Shell's Second
Round, Decided Again*): of its eight items one remains, three moved into MVP 4.0's shell, where
the operator's prompt is, and four were dropped with their verdicts in the log.

1. **`:trace f`**, a proposal first: each call of `f` on the node and each return printed at the
   operator's prompt, the values by their descriptors (§11.2), with a bound a busy node needs, as
   Erlang's `recon_trace` has one; the runtime has no tracing hook today, so the design decides
   how a function of a unit is traced by its position and what the bound is. Built after MVP 4.0,
   on the node.

---

## MVP 4.4 (the promise, the cost, the full review and Ernest 1.0), about three weeks, last

Decided with the user on 2026-10-31 (the log's *MVP 4.4, the Road's End*): the road's last
milestone, after the shell's second round, so that the review reads a language that ernest-httpd,
the website and the operator's prompt have used. After 1.0 the road is a program's.

1. **The promise first.** A program written for 1.0 builds, and means the same, under every 1.x:
   the standard library and the libraries only grow within 1.x, and a rule's change or a
   function's removal is 2.0's; `ern`'s commands and their options stay, their diagnostics'
   wording free. Nodes of two 1.x minors do not connect, the floor as §12.5 has it, a fleet moving
   minor by minor as the deployment guide shows. Stated in the README's *Where it stands* and
   here, the argument in the log; the report keeps the floor alone.
2. **The cost.** The fault row made readable first, a median over runs with more iterations,
   since its spread in one run is half its value (the log's *The Release Review Before 0.7.0*,
   *The raise's rise is noise*). Then the bench whole, idle, and each row above a fraction of the
   host's read: by design, a message §10 states and the log argues, with what it buys and the rate
   at which a program feels it; or a defect, the fault's report at 36 times the host the one
   candidate, whether the trace is taken at the raise or when a line is written. The verdicts and
   rates are one log entry and the rules a section of the runtime's design note beside how it
   keeps its books, `why.md`'s cost claims held to them; read before the review.
3. **The full review**, as `full_review.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says, the batches' sentences read cold before the build.
4. **Ernest 1.0.0**, by `docs/release_review.md`'s step, on Linux: macOS unverified and said so
   in the README's installing sentence and the note; the three application repositories' floors
   raised to 1.0 the same week; the feedback file and the findings file empty.

---

## Milestones

| | What | Done | Release | Where its reasons are |
|---|---|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | 2026-09-18 | tag `mvp1` | the log's entries of 2026-09-17 and 2026-09-18; [`architecture.md`](architecture.md) |
| MVP 2 | the rest of the report on one node | 2026-09-19 | | the log's entries of 2026-09-19 |
| MVP 2.5 | a complete standard library | 2026-09-20 | | *The Erlang Standard Library, Read for Ernest*, *Fs by Its Structure, and the Table*, *One Token for the Project* |
| MVP 2.9 | an Emacs major mode | 2026-09-23, out of order | | [`emacs_mode.md`](design/emacs_mode.md) |
| The report read as a Wirth report | the report read against Wirth's register and §0, about thirty issues decided one at a time | 2026-09-23 and 2026-09-24 | | the log's entries of those two days, one an issue |
| MVP 2.61 | the guide as the user's document | 2026-09-24, out of order | | the log's entries of 2026-09-24 |
| MVP 2.6 | the shell | 2026-09-25 | | [`design/shell.md`](design/shell.md); the log's entries from 2026-09-20 to 2026-09-25 |
| `libs/markdown` | a CommonMark renderer, now under MVP 4.1 | 2026-09-25 | | Appendix G.2 |
| The code read back after the shell | every line of Ernest and Erlang read for the principles, clumsiness and defects | 2026-09-25 | | *The Code Read Back* |
| MVP 2.65 | the language and the toolchain read back | 2026-09-26 | | *The Report Read Cold, Its Plain Half* to *The Closing of Step 10*; the log's entries of 2026-09-25 and 2026-09-26 |
| MVP 2.66 | the standard library's `Supervisor` | 2026-09-27 | | *No Remote Computation in the Language*, *A Sibling Restarts at Its Next Wait*, *The `Supervisor`'s Shape* |
| MVP 2.8 | the formatter | 2026-09-28, out of order | | *What the Formatter Keeps*, *Layout for the Reader*, *Format on Save*, *The Formatter Before the Release* |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | 2026-09-28 | | *A Program's Command Line Is `Os`'s* to *The Working Directory*, *What the Loads Found*, *The Shell's Code Memory*, *Atoms, Counted*, *Running as a Service*, *The Libraries in the Report*, *Back Pressure, Again*, *What Ernest Adds Stays at Four*, *The Guide Read in Order* |
| MVP 2.95 | manual pages, an installation, the review | 2026-09-28 | | *Manual Pages Named `Ernest.List`*, *`ern(1)` Is §11*, *What Building the Manual Pages Found*, *`bin/ern` Is a Launcher*, *The Layout Under the Prefix*, *One Archive, Compiled Where It Is Installed*, *A Lean Review*, *The Time of `make test`*, *What MVP 2.95 Takes From the Rest*, *What `Fs` Holds*, *No Mac for the First Release* |
| MVP 2.96 | a result annotation written with `:`, and a process's addresses taught | 2026-09-29 | | *A Result Is Annotated With `:`*, *A Process's Addresses, Taught in Order* |
| MVP 2.98 | what the first review left | 2026-09-30 | | the log's entries of 2026-09-29 and 2026-09-30, *The Report's Cheap Lines* to *`closeListener` Names What It Closes*; `findings.md` as it stood at `b7d34c0`, its readers' lists in its history to `08edfda` |
| MVP 2.99 | a restart begins afresh, and the first release | 2026-09-30 | tag `v0.1.0` | *The First Release Is for Others*, *The First Release Follows MVP 2.99*, *A Restart Begins Afresh*, *`ern(1)` Has Its Sections*, *The Release Review*, *The Release Review's Security Lines* to *The Release Review's Questions* |
| The principles review | the report and the guide against §0, and §0 against what it decided | 2026-10-01, and again 2026-10-09 before MVP 3.1 | | *The Principles Review*, *The Attack Plan*, *The Principles Review Closed*; *The Principles Review of 2026-10-09* and its *Judgments* |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | 2026-10-01 | tag `v0.2.0` | *The Release Review Before 0.2.0*, *A Release After the Review*, *The Release's Pages in `man/`* |
| MVP 2.99b | what the release review left, names that read among it; operations records: the requirement `needs a.compare`, a record filled from a namespace, an ordered set and an ordered map; running as a service | 2026-10-03 | | *The Erlang Read and Renamed*, *The Ernest Read and Renamed*, *The Requirement Built*, *MVP 2.99b's Questions, One by One*, *`Address.ask` Is Taken Out*, *The Operators Stay Ernest*, *The Hardening Built*, *The Runtime as a Service, Built*, *The Service Manager's Checks*, *The Reaper's Look at Rest*, *The Boundary Trusts a Type Variable*, *The Report in Three Files*; `findings.md` as it stood at `d6996f1`; `docs/proposals/operations/` as it stood at `42a51d22` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | 2026-10-05 | | *The Full Review Run*, *The Full Review's Questions, One by One*, *A Release Carries No History*; `findings.md` as it stood at `0d2de61` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | 2026-10-05 | tag `v0.3.0` | *The Language Argued Before Peers*, *The Grammar Generated Against*, *The Library's Laws Held*, *The Typed Programs Generated*, *The Replies Generated*, *The Type System Argued*, *What Erlang Held, Moved*, *The Release Review Before 0.3.0*; [`soundness.md`](soundness.md) |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | 2026-10-05 | tag `v0.3.1` | MVP 2.99d's entries |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | 2026-10-06 | | *MVP 2.99d's First Measurements*, *The Prelude Measured*, *The Library Stands on the Host*, *The Emitted Code Measured*, *Spawn Keeps Its Wait*, *Kept Only for Speed, Taken Out*, *Fs.removeAll Removed*; [`otp_bugs.md`](otp_bugs.md) |
| The shell shows a bracket's match | a closing bracket stands the cursor on its match, ahead of MVP 4.3 | 2026-10-06 | | *The Shell Shows a Bracket's Match* |
| MVP 3.0 | peers: one program on several nodes, by its proposal | 2026-10-09 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Carrier*, *Addresses, Messages and Monitors Across Nodes*, *Calls Across Nodes*, *A Node's End and Its Reload*, *The Module Peer*, *Load and Balancer*, *The Module Json*, *The Tests Wait on What They Mean*, *The Milestones After 3.0, Weighed Again*, *The Plan Rewritten from the Split Proposals*, *MVP 3.0's Findings Decided* |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing`; then a read of what it built | 2026-10-10 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Canonical Form, Built*, *The Code Table, Built*, *The Spawn by Hash, Built*, *The Shell's Reload by Hash, Built*, *Termination Told, Built*, *Standing and the Refusal, Built*, *What MVP 3.1 Costs, Measured*, *MVP 3.1 Read*, *MVP 3.1 Done*, *The Feedback Pass Before MVP 3.2*, *A Milestone for Placing Work by Load*, *The Back End Last* |
| MVP 3.25 | placing work by name: `Peer.compute` on a named peer, `Peer.utilization` with the node's measure its maintainer's, and `Placement` in `Balancer`'s place | 2026-10-11 | | *The Placement Proposals Swept*; *Placing Work by Name* |
| MVP 3.26 | kill darlings: the reply's obligation and `!` gone, `receiving M` in place of `with M` on a function that receives alone, the value restriction relaxed for data, the held replies gone, and the guide's *A library that waits* | 2026-10-16 | | `docs/proposals/kill_darlings/` as it stood at `42a51d22`; *Kill Darlings*, *§0 Read Again* |
| MVP 3.2 | code with a spawn: the exchange, the bare node, every unit held for the node's life, and `Code`; then a release, Ernest 0.4.0, the first with nodes | the code by 2026-10-15; the release 2026-10-18 | tag `v0.4.0` | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Feedback Pass Before MVP 3.2*, *The Typed-Channels Example*, *The Service Named*, *Names Read as a Newcomer Reads Them*, *The Report for Code with a Spawn*, *Placing Work by Name*, *American English Throughout*, *The Pages Written From `main`*, *Pages Written Where Out of Date*, *The Tools Measured*, *The Tools Measured Again*, *The Repository Laid Out Again*, *The Layout Completed*, *Tables in `libs/markdown`*, *The Programs Tests' Bounds*, *The Design Notes Leave the Proposals*, *The Examples Are Programs*, *The Runtime's Own Processes*, *The Shell on a Private Type*, *Before the Tag, the Last Builds*, *Ernest 0.4.0 Ends MVP 3.2*, *The Release Review Before 0.4.0* |
| MVP 3.27 | measured across machines: the exchange's numbers of 2026-10-13 again between three machines on one LAN, the push against the pull across them, the spawn's end at the reaper and the bench's three other rows that grew measured piece by piece, every fault with a trace, the programs tests' limits derived, and the annotation out of the hash | 2026-10-21 | | *The Numbers Across Machines*; *The Machines*, *The Numbers Across Machines*, *The Rows That Grew*, *Every Fault Carries a Trace*, *The Nodes Tests' Bounds*, *The Later List Sorted*, *The Annotation Out of the Hash* |
| MVP 3.28 | what stands before the tour: a clause's body all or none, which §11.6 states and `ern format` writes; `--libs-dir dir`; `--verbose`; and seven items the feedback left: four messages that name the form, the rules of an Ernest program installed, the libraries on the default load path, `ok` as `Unit`, `Test.faults`, the foreign call measured, and doc examples run by `ern test`; with what the builds found: a type and the module of its name share a namespace, a module under a taken namespace refused, `List.mapFold`, a mailbox type ending in `Msg`, the prelude's `Unit` as a descriptor word, a `make` with nothing to do measured, and each doc example a program of its own in a directory of its own | 2026-10-22 | | *The Later List Sorted*; *Clause Bodies All or None*; *A Libs Flag Instead of the Environment*; *A Build Says What It Decided*; *A Make With Nothing to Do*; *What the Feedback Left*; *The Window's Three Asks*; *Nothing Waits for a Program*; *The Foreign Call Measured* |
| MVP 3.29 | the bookkeeping behind §8.6 on one rule, the look reads what a process marks and no operation writes a shared row: the foreign call's count gone for a read of the waiting process, the timed receive's and the call's marks in the process's own dictionary, every slow wait of the runtime's own marked and held by a test, the callees' row kept on a write-concurrent table and measured against two other kinds, a kill one function and a frame from another node; a ground `let` compiled to its term; the foreign cause naming the function; one checker of the library's examples; a launch a row of its own table, halved; the runtime's fixed waits and the tests' sleeps, polls and limits gone for waits on what each means; `make bench` with a memory of its last run and of the release's, by ratio; the language measured against the host's own Erlang, construct by construct and in three programs written twice; the runtime's design note; and a deadlock found among *Why Ernest*'s claims | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*; *`make bench` Read Against the Cost Rules*; *The Language Against the Host*; *The Foreign Call Measured*; *Deadlock Is Quiescence* |
| MVP 3.295 | what the language measurement found: a `Float` operation the host's own with no `try`, the runtime reading a `badarith`'s frame, a chain of five from 1.65 to 1.23 times the host's and the ray tracer from 1.95 to 1.70; `Map.get`'s number closed as the type's; and the bench's parts as targets, its memory kept a table at a time | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*, its paragraphs *The Float chain* and *Built*; *The Language Against the Host* |
| MVP 3.296 | what the tour's outline asked: a restart runs the function it was given, stated in §6.9 and the deployment guide, with the guide's sentence that a binding is its node's own; `ern config --listen` and `--peer-dir dir`; the Erlang and the Gleam programmer reading `why.md` and `faq.md`, and every guide read for a word used before it is said; two messages the tour's spike found wanting; and the runtime's own frames out of a designed fault's trace | 2026-10-23 | | *What the Outline Asked*, *Two Nodes on One Machine, Built*, *The Skeptics' Read*, *What the Skeptics Found*, *The Hash's Parents*, *Two Messages, and the Runtime's Frames Weighed Again*; `findings.md` as it stood at `fd5b361c` |
| The full review's findings before 0.5.0 | the 218 lines of the review run over `1329d1d2`: 159 `fix` made in ten batches by area and an integration pass, 52 `decide` taken one at a time, 9 dropped; the service monitor and `demonitor` added to the language, `Reply.process` and `compare` over tuples, lists, `Optional` and `Either` to the library, each with its page and its test | 2026-10-24 | | *The Review's Fixes, First Round*, *The Runtime's Note States No Why*, *The Review's Decisions*; `findings.md` as it stood at `08997105` |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program, the counter, grown through eight chapters from a process with a typed mailbox, through the same counter on a peer that holds none of its code, to its move to new code there, where the deployment guide takes over; with it a README for `report/` and for `guide/`, the README's three ways in, the guide's taste of the rest, and the path read by a fresh reader and the two skeptics | 2026-10-24 | | *The Tour*, *The Tour, Shorter*, *What the Outline Asked*, *The Skeptics' Read*, *What the Skeptics Found*, *The Tour's Programs, Built*, *The Tour Written*; the outline, `docs/proposals/tour/` as it stood at `688ffa03` |
| MVP 3.9 | the review, and Ernest 0.5.0: the nodes' and the code's design notes, the proposals built by then swept, the full review and its findings, the process-only mark narrowed and a wrap's `self` its recipient's, what the lease broker found, the release review and Ernest 0.5.0, a release with no promise of stability | 2026-10-25 | tag `v0.5.0` | *MVP 3.9 Weighed*, *The Nodes' and the Code's Notes*, *The Design Notes Leave the Proposals*, *The Full Review Before 0.5.0*, *The Review's Fixes, First Round*, *The Review's Decisions*, *The Process-Only Mark Marks a Wait*, *A Wrap's `self` Is Its Recipient's*, *Two Nodes Tests Take the Fault's Line*, *One Name for Every Order*, *The Shell's End Writes What It Was Told*, *A Restart Empties Before It Tells*, *A Member Has One Face*, *The Release Review Before 0.5.0*; `findings.md` as it stood at `105fb3fc` |
| MVP 3.95 | what the review and 0.5.0 left: the release review read back, a restart told across nodes by the runtime's own frames, the harness counting a test's steps, the review round's method with an owner, the site proposal's sitting, the first fault's cost measured, the member regime's missing test, the teller's late delivery closed, dialyzer in the full run, and Ernest 0.6.0, the protocol's version moved | 2026-10-25 | tag `v0.6.0` | *The Release Review Read Back*, *A Restart Told Across Nodes*, *A Restart Told Across Nodes, Built*, *The Report's Readers Read the Diff*, *The Teller's Late Delivery*, *The Teller's Late Delivery, Built*, *The Harness Counts a Test's Steps*, *The First Fault's Cost*, *The Review's Decisions*, *A Member Has One Face*, *The Report Pared After 0.6.0*, *The Release Review Before 0.6.0*; `findings.md` as it stood at `c6eab569` |
| MVP 3.96 | the report pared to the language, `language.md` holding what decides what a program means and the runtime's mechanism chapter 12 of `toolchain.md`, and what the paring found: the build's cost per function linear, one function per initializer, the nested group's third restart, the newcomer's feedback decided, the second cut to E.27, the comments' paragraphs, the emitter's calls as the host's, `<-` at the prompt and `Test.until` | 2026-10-30 | | *The Report Pared After 0.6.0*, *The Report Pared, Built*, *The Build's Cost per Function*, *One Function per Initializer*, *The Nested Group's Third Restart*, *What the Newcomer's Feedback Left*, *The Second Cut, §8.7 to E.27*, *The Comments' Paragraphs*, *The Emitter's Calls Against the Host's, Built*, *Small Library Functions Stay Calls*, *`<-` at the Prompt*, *`Test.until`, Built* |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches, its proposal `docs/proposals/shell/attached.md` as it stood at `facbd285`; and the release review before 0.7.0, eight readers over what changed since 0.6.0, its fix lines and its eight batches decided and built | 2026-10-31 | tag `v0.7.0` | *The Attached Shell's Cut*, *The Attached Shell's Sentences*, *The Session's Screen and the Toolchain's Units, Built*, *The Attached Shell, Built*, *The Guides Over the Attached Shell*, *The Attached Shell, Tested*, *The End's Lines Reach the Screen*, *A Line-Mode Input's Cost*, *The Attached Shell's Last Row*, *The Attached Shell's Own Node, Quiet*, *An Expression's One Unit, and an Input's Cost Flat*, *The Detach Keeps What Declares a Function*, *The Release Review Before 0.7.0*, *The Release Review's Code Fixes*, *The Argument's Four Decisions*, *Sites, Sessions and Their Names*, *The Input's Process*, *One Word to Leave*, *The Shell's Own Node*, *Reload, Services and Tests*, *The Library's Lines*, *The Claims, the README and the Tour* |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | | | above |
| MVP 4.2 | the website, served by ernest-httpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | above |
| MVP 4.3 | the shell's second round | | | above |
| MVP 4.4 | the promise of 1.x, the cost analysis, the full review and Ernest 1.0.0, Linux | | | above |
