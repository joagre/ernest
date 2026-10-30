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

**MVP 3.96 is done**, the report pared to the language and what the paring found, on 2026-10-30
(the log's *One Function per Initializer*, its last item): `language.md` holds what decides what a
program means and the runtime's mechanism is chapter 12 of `toolchain.md`; the build's cost per
function measured and made linear, `Test.until`, `<-` at the prompt, the comments' paragraphs, and
the emitter's calls as the host's. Ernest 0.6.0 of 2026-10-25 is the last release; no promise of
stability is made, and a change to the language, the standard library or the libraries is driven
by a need met in use and recorded as `docs/language_feedback.md` records one.

Next is the attached shell, MVP 4.0; then ernest-httpd, the website and the shell's second round
(the log's *The Road to 1.0, Ordered*); the back end to BEAM's own instructions that closed the
road is not built, decided 2026-10-30 (the log's *No Back End to BEAM's Own Instructions*). A
finished milestone is a row of the table at the end, its reasons in the log entries the row names.

---

## MVP 4.0 (a shell attached to a running node), about a week

Made on 2026-10-13 from MVP 4.3's item 4 when the deployment guide's section 6 was written and
the user saw how thin a shell beside a node is for an operator: every look is a compute wrapped by
hand, and nothing of the node's own is at the prompt.

Its design is `docs/proposals/shell/attached.md`, read back against the shell's design note and rewritten on 2026-10-30, ready the same day (the
log's *The Attached Shell's Cut*): the operator's machine is the terminal and the files, and
everything else is the node's, so the shell of the design note runs on the node, touching the
terminal and the files through the local half alone, spawned there by the operator's `ern shell --config-dir ops --attach name`, and what crosses the
carrier is the terminal's events and bytes and the operator's files.

One form of attaching, by a listed peer, since a node accepts a connection from a peer it lists and no other (§12.5).

1. **The report first**, the proposal's section 6: §11.2's attached shell, `--attach name`, which
   takes no file, `:detach` in `:quit`'s place, sessions many on a node each with a number, what
   `:processes`, `:load`, `:reload`, `:output` and `:faults` are there, the operator's files read by
   the operator's machine, and what the shell says and exits with at an attach that fails, at the
   node's loss and at its end;
   Appendix H's one session namespace becoming each session's, `$Session3`; §12.1's write to
   standard output or standard error routed by the writing process's root; Appendix E.21's
   `Process.live()` leaving out every session's own processes; §12.7's definition a peer lacks
   that a unit of the toolchain's own holds, loaded from its own tree as a load places one and
   asked for from no node. Nothing of §3 to §9 changes.
2. **The runtime**: a write routed by its root, a session's to its screen and a root with no screen
   to the node's, by a row of the session's root and its screen that the standard streams read; the runtime's own processes a set every session adds its own to and takes them
   from; a lacked definition of the toolchain's own loaded from the node's tree at a spawn, its
   bindings evaluated as a load's, which `docs/design/code.md` gains with the build.
3. **The shell**: the local half in Ernest, holding the terminal, reading the history, the startup
   files and the environment, spawning the shell's entry on the node with its address and what it
   read, forwarding the terminal's events, writing the bytes the screen sends and answering its
   `Flush`, reading a source for `:load` and `:reload` and listing the source root for its
   completion, appending the history and `:output`'s file, and reading each line in line mode.

   On the node, the session's number, given once in a node's life, in every host name an input
   makes, the names counted by the code table's sums, `:detach` leaving the evaluators, what
   they started and what inputs spawned to the node, the node's reload shared by every session,
   and the session's end at the local half's loss; at the local half, an attach that fails said
   as the job's refusal, `NotLoaded` naming another build of `ern` than this shell's.
4. **The guides and the documents**: the deployment guide's sections 5.3 and 6 rewritten over the
   attached shell, an attach made with the node's own release of `ern` among what section 6
   says, the language guide's §8.9 upgrade becoming a `:load` of the new build at the node's
   prompt with `Code.running` run there, `docs/development.md`'s row on attaching gone with
   the gap (asked by the user 2026-10-18).

   The design notes: `docs/design/shell.md` gaining the attached shell's
   section, the cut and the local half, `docs/design/runtime.md` the row of a session's screen
   with its reader, and `docs/design/code.md` each session's namespace, the
   toolchain's own units at a spawn, and its rule on unloading narrowed to a load's, an arrival's
   and a version's units, and `docs/design/nodes.md`'s rule on evaluating nothing for a peer
   narrowed for the toolchain's own units.
5. **The tests and the release**: the nodes tests over a shell attached to a bare node and to a
   program's node, two sessions on one node, a `:load` shipped as text, a detach that leaves a
   service running, the node's loss and an attach that fails; the guide's section 6 run by them; the session golden
   test over an attached session; then the release that follows, 0.7.0, by `docs/release_review.md`.
6. **The shell's end loses its last lines**, found 2026-10-30 while MVP 3.96's item 7 was
   measured: `reload_version_sites` in `test/ern_shell_tests.erl` goes red in about three runs of
   a hundred under the harness, quiet or loaded, on the code of 0.6.0 as on today's, the session
   exiting with status 0 while the end's lines on standard error, `the end waits for 2
   subscribers` or a subscriber's `answered`, end short, the last one or two never written. The
   shape of its fix: find which process says the end's lines and what the job's exit waits for of
   it (the runtime's note's *The process model*, `wait_for_later/0`), since a line of the
   toolchain's own is to wait until standard error has taken it; diagnosed with the session's end,
   which the detach rewrites, and before the release.

The attached shell is the operator's alone, trusted as a peer is, with no sandbox: the website runs
the plain shell in a container per visitor (MVP 4.2).

## MVP 4.1 (ernest-httpd, and the libraries it wants)

**ernest-httpd**, an HTTP/1.1 server written in Ernest, in a repository of its own, decided with
the user on 2026-10-10 (the log's *ehttpd and the Website*): the base of Ernest's own website, MVP
4.2, and the first program built against an installed Ernest by a build of its own, which the
examples cannot be.

Its design is `docs/proposals/httpd/proposal.md`, begun 2026-10-26, read back
on 2026-10-30 and ready the same day: what of HTTP/1.1 and WebSocket it implements and leaves out,
TLS in `Tcp`, the live shell's server side, its limits and its security, its configuration, its
log, its life under systemd, and the five libraries it asks for. Its own plan lives in its
repository; this one records what it asks of Ernest, written as it asks, in the proposal's order.

What it lacks is added where it belongs and never worked around in Erlang or behind a `foreign
fn`: a function the standard library lacks enters by E.0's admission rules, our need the occasion
and the rules deciding the function; a format or a protocol is a library's; what the prelude or the
language lacks goes to `language_feedback.md` first, as any Ernest written here, and is discussed
before any code goes around it (decided with the user on 2026-10-10, with the site's generator,
MVP 4.2).

1. **The report first**: `Tcp.listenTls` and `Tcp.connectTls` in E.18, answering the same socket
   as a plain one, the handshake in the socket's process after `accept`, `listenTls`'s
   `Other(text)` for a certificate or key the host refuses, and the host's backlog stated;
   `Os.startTerminal` and `Os.resize` in E.23 through E.0's admission rules, one address with
   `start` and one stream out; and a section in Appendix G for each of the five libraries.
2. **The runtime's two additions**, the riskiest work, before anything stands on them: TLS in
   `Tcp`'s socket process over the host's `ssl`, and the C helper's `forkpty` and resize behind
   `Os`, on Linux and macOS.
3. **The five libraries**, each a source root under `src/libs/` with the standard library's
   discipline and its page: `base64` and `crypto`, which `websocket` needs; `time`, the calendar
   alone; `http` with its client half, whose first use beside the tests is a `fetch` example that
   reads JSON over HTTPS with a verified certificate; then `websocket`, with a client's masked
   frames.
4. **An installation from the checkout**: `make install` into a prefix exists
   (`docs/design/install.md`), and ernest-httpd builds against it and never against the source
   tree; a gap the server finds in a library is fixed in the checkout and installed again, with no
   release between.
5. **ernest-httpd**, in its own repository: `Config` and `Static` as pure functions; `Listener`,
   `Connection` and `AccessLog`, serving the site over plain HTTP; TLS, the redirect listener and
   the hosts; `Shell` and `Sessions` last, since they stand on the rest.
6. **The deployment**: the node's directory with the operator's shell listed, since the server
   runs as a node on the loopback for the attached shell, the systemd unit, certbot's certificate
   for the four names with the deploy hook that gives the server its key, the podman image, and
   the smoke test against the deployed site, an attached shell's `:processes` among it.
7. **A release of Ernest**, 0.8.0, when the server first serves the site, carrying the libraries
   after their first real user has shaped them; 0.7.0 is the attached shell's.
8. **The terminal tests over `Os.startTerminal`**, dropping `test/ern_pty.py`, an item of its own
   once item 2 stands.

The site's content, MVP 4.2, runs beside any of it, since its generator needs nothing of the
server.

**Libraries named and not the server's**, written when our work needs one, when someone asks for
it, or when we want it, decided 2026-09-25 (the log's *Libraries As They Are Wanted*). Each is an
Ernest source root under `src/libs/<name>/` whose build ends every job's load path, so that a
program names none (§11.2), with `src/stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first user,
and a section in the appendix of libraries. Own repositories come later, when there is a package
story.

Written: `libs/ets`, `libs/markdown`, `libs/ansi`, `libs/utilization`, `libs/json` and
`libs/proxy` (Appendix G; `libs/markdown` in the table of milestones, `utilization`, named `load`
until 2026-10-13, and `json` in MVP 3.0, and `proxy`, named `standing` until 2026-10-10, in MVP
3.1). Named so far:

- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
  Either(RegexError, Regex)`, `Regex` a foreign type (the log's *A Regex Literal Weighed*).
- **`libs/uri`**, pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`,
  which the site's precompressed pages would want first.
- **A listing by bytes in `Fs`**, decided when a program must manage a directory others
  write by names it does not choose: `Fs.names` and `Fs.removeName`, through E.0's rules,
  beside an `Fs.list` that stays whole or an error (§8.2; the log's *The Full Review's Questions,
  One by One*, S17).
- **A read and a write in `Fs` that refuse a link under a root**, decided when a program
  serving files from a root others can write is written: `Fs.readUnder` and `Fs.writeUnder`,
  through E.0 rule 1, walking by opened directories in the runtime's helper, started per call
  or resident as that program's cost decides (E.17; the log's *The Full Review's Questions, One by
  One*, S16). ernest-httpd serves a root no one else writes and waits for neither.
- **A file made with a mode in `Fs`**, decided when a program must write a file only its owner
  may read into a directory others may enter: a function beside `makeFile` that takes the mode,
  through E.0 rule 1, opening with it in the runtime's helper (E.17; the log's *The Full Review's
  Questions, One by One*, S9).
- **`Udp`**, a system module of Appendix E beside `Tcp` and not a library, admitted by E.0
  rule 1 and written as wanted too, with `Tcp`'s shapes: a socket an address, a read pulled
  with a time, a datagram `Bytes` (the log's *`Clock.monotonic` Is In, and `Udp` Is
  Placed*).

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
language's was weighed and set aside on 2026-10-13 (`docs/proposals/shell/attached.md`), and the
attached shell, MVP 4.0, is the operator's alone.

1. **The generator**, `tools/site.ern` beside `tools/manual.ern`, in Ernest over `libs/markdown`'s
   tree, `Block` and `Inline`, an `html` function of one clause per constructor; the library
   renders to its tree and to the terminal alone, and nothing of the site enters it (decided
   2026-10-10), `roff` moving to `tools/manual.ern`, its one user, when something next touches the
   library.

   It reads the repository and writes static files: the pages of the report, the guide,
   the tour, Why, the questions, the deployment guide, the README's *Installing*, the release
   notes and `docs/man/`'s Markdown; the contents pages; the anchors, the citations' links and a
   report section's margin line; Ernest code colored by a `foreign` declaration over the
   toolchain's lexer; which buttons a block gets, Copy alone for a transcript the container
   cannot hold, a node's or an attached session's, read from its first line; the shell page's
   limits read from the server's configuration; each page's sidebar, title, description and
   footer. It may come before the rest whenever it is wanted.
2. **The templates and the docroot** brought to the decisions: `page.html`, `toc.html`,
   `home.html` and `shell.html` on `base.html`, the fragments for a list's items, the stoat in
   the header, the favicon, the footer's rooms, the homepage's order and the panel's controls,
   no inline script or style under the server's policy, a test holding each template to its
   tokens; `site/` at the repository's root holding
   `templates/` and `docroot/`; xterm.js and its fit addon vendored, with their row in
   `THIRD_PARTY_LICENSES`.
3. **The document the site lacks**: the root `CONTRIBUTING.md`, written before the site goes
   live; the Releases page is `CHANGES.md`, which the release step writes from the next release
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

## MVP 4.3 (the shell's second round), about three weeks

The shell's later work that its parts' merits take, decided with the user 2026-09-30 (the
log's *The Shell's Second Round*), in this order. The first three need nothing of MVP 3.0 or
3.1 and may be taken earlier where the user wants them.

1. **Readline's remaining keys**, about a day: the kill ring with `M-y` cycling the earlier
   kills, `C-t` and `M-t` transposing, and `M-u`, `M-l` and `M-c` for case, each a change to
   `Shell.Editor`'s pure `edit`, with key-stream tests.
2. **`:trace f`**, about two days: each call of `f` and each return printed, the values by
   their types (§11.2).
3. **Completion by type**, about one to two weeks: a `match`'s clauses, a mailbox's
   constructors, the functions after `|>`, and an argument's bindings. It needs the checker to
   check an unfinished input, designed first.
4. **A shell attached to a running node**: MVP 4.0's since 2026-10-13.
5. **Whether the session owns what its inputs open**, a decision with the user: a socket and a
   running program an input opens end with the input's process, their owner (§11.2), and the session
   could own them instead, so that they live until it ends, by a way the shell names an owner for
   its inputs (`findings.md`'s C1-2 as it stood on 2026-09-30, placed here that day).

   Half decided 2026-10-10 by feedback entry 91: what a `:load`'s binding opens is the evaluation
   process's, which lives while the session runs (§11.2), so the decision left is the input's own
   process alone, which MVP 3.1's read kept ending with the input (its W10).
6. **A previous version at the prompt**, a decision with the user: whether a previous version's
   constructors may be written at the prompt, `Counter$1.Inc`, and whether `:processes` names
   the version a process runs (`language_feedback.md`'s entries 97 and 98 as they stood on 2026-10-10,
   placed here that day by MVP 3.1's item 5).
7. **The `live_region` test's one miss**, 2026-10-05 in a full `make test` under load (MVP
   2.99d's item 11), passed again alone and under `make test-shell`, and not failed since: when
   it fails again its step file in the run's directory says which expectation went unmet, and
   the fix follows from it; diagnosed here where it recurs, and nowhere before.
8. **`:processes` shows what each process waits on**, its activity beside its site, so that a hung
   process is found without `List.map(Process.live(), Process.status)` (the full review's B-H3,
   placed here 2026-10-24).

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
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches | made 2026-10-13 from MVP 4.3's item 4 | | above |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | | | above |
| MVP 4.2 | the website, served by ernest-httpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | above |
| MVP 4.3 | the shell's second round | | | above |
