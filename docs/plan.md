# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log/`](log/README.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone ends the file. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in a dated entry of the log; nothing stands between.

---

## Where we are

**Ernest 0.10.0 is the last release**, of 2026-11-10, what the server taught: a node at the
host's limits, relative names, `kill` on a `Process`, a worker's value or its end, a program's
environment and signals, `libs/uri`, and the release review before it, which read the
milestone's diff, its 126 lines fixed and 25 decided in eighteen decisions (the log's *The
Release Review Before 0.10.0* and the entries MVP 4.15's row names), and the checkout works
toward 0.11.0. No promise of stability is made, and a change to the language, the standard
library or the libraries is driven by a need met in use and recorded as
`docs/language_feedback.md` records one.

MVP 4.16 comes next, a deadlock's scope and its report, packages and the flake hunt, before the
launch (the log's *MVP 4.16, the Proposals Before the Launch*). Then MVP 4.6, the server owning
both ends of its socket, moved before the launch on 2026-11-10 (the log's *MVP 4.6 Before the
Launch*). Then MVP 4.4, the cost, the full review and the launch's release, where the road ends
and a program begins (the log's *MVP 4.4, the Road's End*). MVP 4.5, the shell's second round,
follows the launch (the log's *MVP 4.3 Becomes MVP 4.5*).

Ernest stays at 0.x until someone outside the project depends on it, as MVP 4.4's opening
says.

---

## MVP 4.16 (a deadlock's scope and its report, packages, and the flake hunt), about a week

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*): two
proposals built before the launch, so that the full review reads them and the launch shows them.
It follows Ernest 0.10.0, and the checkout then works toward the launch's minor. Its item 11,
the flake hunt, stands apart from the two, and its item 12, the feedback, is taken first.

The first three items are the deadlock proposal's,
[`proposals/deadlock/`](proposals/deadlock/README.md), each part named as the proposal numbers
it.

1. **A deadlock's claim given its scope**, Part 2: "A deadlock of the whole program is found" in
   the README's list, `guide/why.md`, the tour's chapter 5 and `docs/design/site.md`; the limit
   stated in Why and guide §5.4; the typed mailbox dropped from Why's argument; the status
   premise named in `docs/design/runtime.md`'s *The look*; and the proposal's programs held as
   regression tests. The log's entry that argues the proposal is written with it. The two claims
   the proposal makes from memory, of Pony's collector and Go's work on leaked goroutines, are
   checked against their documents or cut. It closes on `make test-docs` and the runtime's
   target.
2. **The callee in a deadlock's report**, Part 4: each waiting group's line says on whom it
   waits, a group split by its callee's site. It cuts a restated clause of §8.6, so its sentences
   in §8.6 and §12.4 are read cold, and it is decided the day it is built. It touches the runtime
   and closes on `make test-full`.
3. **Who waits on whom**, Part 3: `Process.Calling` gains its callee, whether a limit ends the
   wait and the moment the call began (E.21); `Process.peer` names a process's peer; and
   `:processes` writes them, with a line for each cycle of calls without limit (§11.2). It
   reports and never faults. It breaks a match on `Process.Calling`, one site here and four in
   ernest-httpd, whose session meets it at its floor's rise. It closes on `make test-full`, and
   `make bench` confirms the call's rows within their noise, before MVP 4.4's item 2 reads the
   cost.

The other seven are the packages proposal's build order,
[`proposals/package_manager/`](proposals/package_manager/README.md).

4. **The report's sentences on a package**: a new section at the end of §11, §11's opening,
   §11.1, §11.2, Appendix F and Appendix G's opening, read cold before the build. The log's
   entry that argues the proposal is written with them. It supersedes in part *Packages*, *MVP
   2.7, the Fetcher, and No Server* and *A Library Is Fetched by Its URL*, and records the
   argument of *A Libs Flag Instead of the Environment* beside the one that won.
5. **The manifest read and the load path**: every job finds `package.conf` in the directory it
   is started in and puts the named packages on its load path, `lib/` filled by hand. The look
   is measured on a job with no manifest before anything is built on it.
6. **`ern build`'s checks**: each named package's claims held against the root's lines, a
   package's `src` and `build` as its roots, and the named packages built in their order. The
   trial's table of refusals is its first test.
7. **`Crypto.sha256`, and libraries over the host's gzip and tar**, each an E.0 reading and its
   section of Appendix G first.
8. **`ern unpack`**, in Ernest, over the three: an archive's digest checked against its line,
   and the archive unpacked whole or not at all, one with an entry outside its own directory
   refused. Where the job's module stands under `Ernest` is decided as the item opens.
9. **The guide's section on a package.**
10. **The other repositories**, with MVP 4.4's items 4 and 5: at its floor's rise each takes its
    manifest, ernest-template first with its Makefile cut, and ernest-epx's release carries its
    host part as the proposal's question 5 says.
11. **The flake hunt**, decided with the user 2026-11-10 (the log's *The Listings Before a
    Review*): a target of its own that runs the split suites of `make test-full` again and
    again in warm hosts beside busy loops, for as long as it is given, writes each failing test
    with its output, and ends the loops by their numbers. It runs on the user's word alone, in
    neither review, and `docs/development.md` names it.
12. **The feedback of the release review before 0.10.0, and the applications'**, feedback 237 to
    247, decided with the user 2026-11-10 (the log's *The Review's Feedback After Its Release*):
    one design session right after 0.10.0's release, each line weighed alone against the
    principles and E.0. The same session reads every line the applications' feedback files hold
    as it opens, as `docs/clean_room.md`'s *The reading here* says. A verdict that builds becomes
    an item of this milestone or of MVP 4.4, before the launch's review, and one that does not
    goes to the log, its line leaving the feedback file.

## MVP 4.6 (the server owns both ends of its socket), a few days, before the launch

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*), the
proposal [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md), and moved before the
launch on 2026-11-10, once the server's reset under load was fixed and the three floors stood at
0.10 (the log's *MVP 4.6 Before the Launch*). The site's script speaks the server's wire, its
generator reads the server's configuration and its browser test stubs the server's socket. Each
goes, for a client the server ships. The order keeps the proposal's: the server's part first,
which adds and takes nothing away, and no day but the launch's switch changes both repositories,
on a path the rehearsal has walked.

1. **The ask**, sent to ernest-httpd's session by a message on 2026-11-10, as
   `docs/clean_room.md` says: a client script served at `/shell/client.js`, the limits the server
   enforces, a client that is never stale, and its own test. The server's part goes into the
   release its item 5 makes for the launch, and its rehearsal of the switch (MVP 4.4's item 6)
   serves the client on scratch ports, so that the switch walks the client's path. The server's
   proposal for its client, read by each session against the other's on 2026-11-10, holds the
   interface as the proposal's decision 7 states it (the log's *The Client's Interface Agreed*),
   and waits on the user's word that it is ready; nothing of it stands in the server's design
   until then, and item 2 begins after that word and after MVP 4.16.
2. **Ernest's side**, built against the rehearsal's server once it serves the client. `site.js`'s
   session imports the client, an ES module, on demand. The generator takes no configuration, and `make site` the tag alone.
   The shell's page takes its numbers from the client's limits and names no memory. The browser
   test serves a stub client that speaks the agreed interface. `docs/design/site.md` changes in five sections, citing the server's
   design's *The client* for the interface, with the sweep the proposal lists. It goes live with the launch's switch, and closes on `make test`, the site's
   targets and `make test-browser`.

---

## MVP 4.4 (the cost, the full review and the launch's release), about three weeks

Decided with the user on 2026-10-31 (the log's *MVP 4.4, the Road's End*): the road's last
milestone before a program, so that the review reads a language that ernest-httpd,
the website and the operator's prompt have used. After it the road is a program's.

Its release is the next minor of 0.x, decided with the user on 2026-11-05. Ernest stays at 0.x
until someone outside this project depends on it, so that a break would cost them something,
and 1.0 has no date (the log's *Ernest Stays at 0.x*, which keeps what 1.0 will promise).

1. **The promise**, dropped 2026-11-05 (the log's *Ernest Stays at 0.x*).
2. **The cost.** The fault row made readable first, a median over runs with more iterations,
   since its spread in one run is half its value (the log's *The Release Review Before 0.7.0*,
   *The raise's rise is noise*). Then the bench whole, idle, and each row above a fraction of the
   host's read: by design, a message §10 states and the log argues, with what it buys and the rate
   at which a program feels it; or a defect, the fault's report at 36 times the host the one
   candidate, whether the trace is taken at the raise or when a line is written. The verdicts and
   rates are one log entry and the rules a section of the runtime's design note beside how it
   keeps its books, `why.md`'s cost claims held to them; read before the review.

   A `match` guard that calls a function, feedback 235, is read with them: it compiles into a
   chain of closures, which cost `Base64.decode`'s loop about four times the host where the same
   test in the body cost 1.4 to 2.3 (the log's *The Libraries' Shims Read Against E.0 Rule 1*).
   The emitter compiles it so that a loop pays the call alone, or §11 states the cost.
3. **The raise a primitive catches**, `ern_json:decode` among them, whose cost grows with the
   caller's stack, 0.4 microseconds on a shallow stack and 110 at 100,000 frames, the trace's
   capture (found 2026-11-01; the log's *The Four Libraries*): read in erts and taken to
   `otp_bugs.md`, or decided against the trace `backtrace_depth` keeps.
4. **The full review**, as `docs/reviews/full.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says, the batches' sentences read cold before the build.

   Before its readers start, `tools/paragraphs.sh`, `tools/comments.sh` and
   `tools/unicode_width.escript` are weighed against CLAUDE.md's *Shims*, each written in Ernest
   or its reason to stay stated (the log's *The Layout's Proposal Read*).

   Before them too, `docs/soundness.md`'s section 7 is recut, decided 2026-11-07: its paragraphs
   cut at their turns and ordered by claim, not by the history of the rules that wrote them, and
   section 1 naming the two claims it argues beyond the four, that no process runs after the end
   and that a process's code stands while it runs, with no paragraph's content changed, so that
   the cold reader reads the argument and not its history (the log's *The Argument Recut*).

   Before them too, the checks that cost cycles are built, decided with the user 2026-11-10, so
   that the readers start from what a tool lists (the log's *The Listings Before a Review*). The
   refusals left after the four built before the release review before 0.10.0 (the log's *The
   Refusals Before the Release Review, Built*), each added with the tree cleaned to zero: `xref`'s
   unused exports and its layers, with a short list of the exports called by name, each with
   its reason, and near misses for the checker beside the typed programs. From then on each
   runs with the checks of its kind: `xref`'s in `make xref`, and the near misses
   in `make test-full`.

   The listings, which a review runs: `cover` over `make test-full` for the full review, clones
   and each module's size for the full and the release reviews, and the slowest tests for the
   release review. `docs/reviews/full.md`, `release.md` and `development.md` name each check in
   the commit that builds it.

   Decided first, in a design session: whether the checker warns of a private function no code
   calls (§11).

   Beside it, on the user's word, ernest-template, ernest-epx and ernest-httpd are each reviewed
   whole by their own sessions, by the `docs/full_review.md` each took at the layout's stop, against the archive of the
   commit the readers read; ernest-httpd's review has a security reader, since it goes public at
   item 6. What they find of Ernest's comes as lines of their feedback files and is sorted in this
   round (the log's *The Applications' Full Review*, *Ernest Stays at 0.x*). As they begin, the
   three floors rise to the launch's minor, each by its own session, since a development build of
   the floor is what an archive before the release is (the log's *The Floors and the Releases*).
   Ernest's session names the minor, the archive's path and its commit to all three by a message,
   and asks for the reviews, on the user's word.

   The template rose to floor 0.10 on 2026-11-10, before this item, on the user's word, by its
   own session: `Os.command("git", ["ls-files", pattern])` at `tools/docs.ern`'s `Os.run`,
   `ERN_VERSION` in its Makefile, the `ern` version under its README's *Building*, and a dated
   entry in its TEMPLATE_LOG.md, the other rules of 0.10.0 touching nothing in it; ernest-httpd
   and ernest-epx took the file from that tag the same evening and stand on 0.10, so the three
   floors rise together from 0.10 here (the log's *The Release Review Before 0.10.0*, its last
   paragraph).
5. **The launch's release**, the next minor of 0.x, by `docs/reviews/release.md`'s step, on Linux:
   macOS unverified and said so in the README's installing sentence and the note, which also
   says that the installed layout changed, for a script that points inside an installation (the
   log's *The Layout Built*); the feedback file and the findings file empty.

   The same week, in this order, each by its own session on the user's word: ernest-template's
   release, since the others copy from it; ernest-epx's, not waiting for its milestone 9; and
   ernest-httpd's, with its readers (the log's *The Floors and the Releases*). Ernest's session
   tells all three the tag by a message, and asks each in turn when the one before it is out.
   The message names every line of the application's that the release answers, MVP 4.16's item
   12's among them, each by Ernest's number. Each application checks every verdict against the
   release before its own, and answers with any line it keeps, as `docs/clean_room.md`'s *The
   answer* says.

   The release review decides the segmentation fault of the host in the typed programs, moved
   there on 2026-11-08 (the log's *The Items Left Read Again*): the target runs with core
   dumps on, so the next fault leaves its core in `test/`, whose stack goes to `docs/otp_bugs.md`
   and to the OTP team, and where none comes by the review, the review decides whether the
   watch stays.
6. **The site live at ernest-lang.org**, last, so that each project it lists builds on the release
   it names (the log's *The Site Goes Live With 1.0*, *Ernest Stays at 0.x*): `make site` from
   that tag, the copy of `build/site/` to the host, and the smoke test against the live site.

   Before it, the generator writes `/robots.txt` and `/sitemap.xml`, the second naming
   ernest-lang.org alone, which the site's proposal decided and MVP 4.2 did not build (the log's
   *The Site's Proposal Read*); `docs/design/site.md`'s *The root* lists them then.

   ernest-httpd rehearses the switch on the machine,
   under a second unit on scratch ports, with Ernest 0.10.0's archive and, once its part of MVP
   4.6 serves the client, with the client, so that the
   switch at the launch swaps one archive for another on a path already walked; then, with its
   release of item 5 made, it switches once, the machine serving its one page meanwhile. Its
   container, two nodes capped at 128 processes, 128 MiB and one core, was built 2026-11-04
   (the log's *A Node's Schedulers*).

---

## MVP 4.5 (`:trace f`), about a week, after the launch

The shell's second round, decided with the user on 2026-09-30 (the log's *The Shell's Second
Round*) and decided again on 2026-10-30 against the attached shell (the log's *The Shell's Second
Round, Decided Again*), and following the launch since 2026-11-05 (the log's *MVP 4.3 Becomes
MVP 4.5*): of its eight items one remains, three moved into MVP 4.0's shell, where
the operator's prompt is, and four were dropped with their verdicts in the log.

1. **`:trace f`**, a proposal first: each call of `f` on the node and each return printed at the
   operator's prompt, the values by their descriptors (§11.2), with a bound a busy node needs, as
   Erlang's `recon_trace` has one; the runtime has no tracing hook today, so the design decides
   how a function of a unit is traced by its position and what the bound is. Built after MVP 4.0,
   on the node.

---

## Milestones

| | What | Done | Release | Where its reasons are |
|---|---|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | 2026-09-18 | commit `7913df85` | the log's entries of 2026-09-17 and 2026-09-18; [`architecture.md`](architecture.md) |
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
| The shell shows a bracket's match | a closing bracket stands the cursor on its match, ahead of the shell's second round | 2026-10-06 | | *The Shell Shows a Bracket's Match* |
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
| The pun | a field given or matched by the variable of its own name written once, `Desk(=local)`, swept over 874 sites with the style test holding it; the round that opened it, ten feedback lines decided and three rules built, a guard's field read, the shell's line by site, and the timed wait's effect, superseded the same day by a `receive` that always receives and `Clock.sleep`; an alarm that can be canceled; `make version`, Appendix D whole, the settler's restart tested, the guide's lines after the release review read; the three outside programs on floor 0.8 | 2026-11-01 | the release after 0.7.0 | *The Pun*, *The Pun's Opening Round*, *A `receive` Always Receives*, *An Alarm Can Be Canceled*, *`make version`, Appendix D Whole, the Settler's Restart*, *The Guide's Lines After the Release Review* |
| Ernest 0.8.0 | a small release, the pun's: a doc example run at its own mailbox type, a census of forms over the repository's Ernest, a one-field request's reply declared positional and passed bare, and the release review before it, 92 findings | 2026-11-01 | tag `v0.8.0` | the log's *Ernest 0.8.0, a Small Release*, *The Release Review Before 0.8.0* |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, which serves ernest-lang.org since 2026-11-02, and what it asked of Ernest: TLS in `Tcp`, a program under a pseudo-terminal in `Os`, the libraries `base64`, `crypto`, `time` and `http`, seventeen lines of feedback decided the days they came, the terminal tests' harness in Ernest, and the release | 2026-11-03 | ernest-httpd 0.1.0, tag `v0.1.0` in its repository; Ernest 0.9.0 | the proposal `docs/proposals/httpd/`, gone with this row, the server's own at https://github.com/joagre/ernest-httpd/blob/v0.1.0/docs/proposals/basic/proposal.md; the log's *TLS in `Tcp` and a Terminal in `Os`*, *WebSocket Is the Server's*, *The Four Libraries*, *A Path Through a File*, *Three Lines From the Server*, *No Numbered Variables*, *A Close, an Exit and a Write*, *An Archive Says Its Commit*, *Two Lines on TLS*, *A Program After Its Exit*, *Four Lines From the Deployment*, *What the Server Taught*, *The Hangup's Order*, *The Error's Place*, *The Harness in Ernest*, *Three Flakes Read* |
| Ernest 0.9.0 | the server's release: what ernest-httpd asked of Ernest, and the release review before it, 112 lines fixed and 23 decided | 2026-11-03 | tag `v0.9.0` | the log's *The Release Review Before 0.9.0* |
| MVP 4.2 | the website, built and live with MVP 4.4's item 6: what Ernest is, its characteristics, the three doors, the tour, the guide, the report and the library's pages, generated from a tag by `make site`, the projects' page, the live shell's page side, and the browser test that holds it | 2026-11-06 | | the design note `docs/design/site.md`; the log's *ehttpd and the Website*, *The Tour Written*, *The Generator Before MVP 4.15*, *A Node's Limits*, *The Site's Look, by Hand*, *The Generator's First Stage*, *The Generator's Second Stage*, *The Generator's Third Stage*, *The Pages Read Against the Principles*, *A Release Carries No History*, *The Start Line's Length*, *The Client's Questions*, *The Site Goes Live With 1.0*, *The Mode's Brackets*, *Projects, a Page of Their Own*, *The Browser Test's Flake*, *The Site's Proposal Read* |
| MVP 4.15 | what the server taught: a node at the host's limits, of processes, of ports and of open files; nothing at the wait and memory shown; `kill` on a `Process`; text from bytes that are not all UTF-8; a worker's value or its end; a program's environment and a signal named; `libs/http`'s values and `libs/uri`; an error across a library; the libraries' shims read against E.0 rule 1; what a lambda's reach finds on a peer; relative names; a terminal that is gone and the host's warnings on standard error; the compiled modules the host cannot read or load, and a load past its limits; four refusals before the review; a listener's backlog; 48 items, the repository's layout between the first two, and the release review before 0.10.0 | 2026-11-10 | Ernest 0.10.0, tag `v0.10.0` | the proposals `docs/proposals/relative_names/` and `docs/proposals/errors_across_libraries/`, gone with item 15 (the log's *A Built Proposal's Sweep Is an Item*); the log's *What the Server Taught*, *The Items Left Read Again*, *Lean at the Limits*, *What `running` Finds*, *The Shell at a Full Table*, *A Terminal That Is Gone*, *The Host Says Running*, *Relative Names*, *A Built Proposal's Sweep Is an Item*, *Nothing at the Wait*, *Both Applications at the Milestone's End*, *The Floors and the Releases*, *Relative Names, Built*, *The Repository's Layout*, *The Layout Built*, *One Stop for the Layout*, *The Other Repositories' Shape*, *CLAUDE.md Redrafted*, *The Template Cut Again*, *The Layout's Proposal Read*, *A Node's Limits*, *A Node's Schedulers*, *The Hangup's Order*, *ernest-httpd's Lines 18 to 21*, *Nothing at the Wait Built*, *Memory Shown*, *`kill` Takes a `Process`*, *Text from Bytes*, *A Text after Its Prefix*, *A Worker's Value or Its End*, *A Worker's Value or Its End Built*, *A Test's Scratch, and JSON on One Line*, *A Case's Standard Error*, *A Program's Environment, and a Signal Named*, *A Program's Environment, and a Signal Named Built*, *`libs/http`'s Values*, *`libs/uri`*, *`libs/uri` Built*, *A Process Owns What It Opens*, *An Error Across a Library*, *The Libraries' Shims Read Against E.0 Rule 1*, *What a Lambda's Reach Finds on a Peer*, *A Top-Level Binding Stays the Node's*, *The Shell Attaches as a Program Spawns*, *An `or` Stands Between Patterns*, *An `or` Inside a Pattern Refused*, *A Node's Own Processes at a Full Table*, *A Terminal That Is Gone, Built*, *The Runtime at the Limit of Open Files*, *What `running` Finds, Built*, *The Sockets Load on One Scheduler*, *A Capture Written Back at the End*, *`Float.atan2` at the Origin*, *The Shell Attaches as a Program Spawns Built*, *A Node Holds the Shell*, *A Waiting Process Collected*, *A Full Table's Answers, Built*, *The Carrier's Acceptor at a Full Table*, *A Program's TLS at a Full Table*, *The Flake of `broken_exchange_test_`*, *TLS as the Host Loads It*, *A Write to a Terminal That Is Gone*, *A Write to a Terminal That Is Gone, Built*, *A Write to a Terminal That Is Gone, Swept*, *The Host's Log Handler at a Terminal That Is Gone, Built*, *The Host's Log Handler at a Terminal That Is Gone, Swept*, *A Pipe Into a Parenthesized Pipe*, *Where the Host's Warnings Go*, *The Flake of `shell_write_terminal_gone_test_`*, *A Compiled Module the Host Cannot Read*, *A Compiled Module the Host Cannot Load*, *A Load Past the Host's Limits*, *The Flake of `os_signal_after_an_unread_exit_test`*, *A Write and a Resize after an Unread Exit*, *The Listings Before a Review*, *The Refusals Before the Release Review, Built*, *One Name for xref*, *A Listener's Backlog*, *The Release Review Before 0.10.0* |
| Ernest 0.10.0 | the release of what the server taught, and the release review before it, 126 lines fixed and 25 decided | 2026-11-10 | tag `v0.10.0` | the log's *The Release Review Before 0.10.0* |
| MVP 4.16 | a deadlock's scope and its report, packages, and the flake hunt | | | above |
| MVP 4.4 | the cost analysis, the full review and the launch's release, Linux | | | above |
| MVP 4.5 | the shell's second round | | | above |
| MVP 4.6 | the server owning both ends of its socket | | | above |
