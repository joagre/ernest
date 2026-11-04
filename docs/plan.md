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

**Ernest 0.9.0 is the last release**, of 2026-11-03, the server's: what ernest-httpd asked of
Ernest on its way to serving the site, and the release review before it, which read two days'
diff, its 112 lines fixed and 23 decided (the log's *The Release Review Before 0.9.0* and the
entries MVP 4.1's row names). No promise of
stability is made, and a change to the language, the standard library or the libraries is driven
by a need met in use and recorded as `docs/language_feedback.md` records one.

The server is released and so is what shaped Ernest on its way, and the checkout works toward
0.10.0.

MVP 4.2's first item, the site's look by hand, is done
(the log's *The Site's Look, by Hand*); next is its item 2, the generator, decided 2026-11-03
to come before MVP 4.15 (the log's *The Generator Before MVP 4.15*); then MVP 4.15, what the
server taught, the rest of the website and the shell's second round
(the log's *The Road to 1.0, Ordered*), and MVP 4.4 last, the promise, the cost, the full review and Ernest 1.0, where
the road ends and a program begins (the log's *MVP 4.4, the Road's End*); the back end to BEAM's own instructions that closed the road is not built,
decided 2026-10-30 (the log's *No Back End to BEAM's Own Instructions*). A finished milestone is a
row of the table at the end, its reasons in the log entries the row names.

---

## MVP 4.15 (what the server taught), about a week and a half

What building and deploying ernest-httpd showed of Ernest, decided 2026-11-02 (the log's *What
the Server Taught*), built after MVP 4.2's generator (the log's *The Generator Before MVP
4.15*). The items stand in build order, set 2026-11-03, each group done with one look at its
area: the runtime, the standard library's readings, the libraries, the nodes, and relative
names last, since they sweep every site of Ernest once. The five decisions for the user, in
items 8, 9, 13, 15 and 16, are discussed early, so that no build waits on them. When the
milestone ends, its reply to ernest-httpd's lines 18 to 21, `docs/tmp/language_feedback_reply.md`,
goes to that program's session, as `docs/clean_room.md` says.

1. **The runtime at the host's limits**, defects found 2026-11-03, fixed by 2026-11-12, after
   MVP 4.2's item 2 (the log's *The Generator Before MVP 4.15*). At a
   full process table the runtime's spawns on a request's behalf meet the host's
   `system_limit` uncaught: the reaper's `spawn_monitor`, the per-request spawns of the `Fs`,
   `Tcp` and `Os` system processes, and the runtime's own, a kept process, a kill and a
   delivery. Each dies, and the node hangs where §7.4 has the spawner fault with
   `Fault("error:system_limit")`. At a full port table the first read of standard input,
   which opens its port lazily, faults with the host's raw term, and the terminal's `stty`
   ports are opened the same way.

   One rule fixes them: every spawn and port the runtime
   makes for a request answers its asker with `Fault("error:system_limit")`, the system
   process living on, and standard input's port opens with the run's other streams. A full
   table leaves no room for the runtime's own end, decided 2026-11-04: everything the end
   uses exists from the run's start, so a node's limit is the one `limits` states; a step
   that cannot move there comes back to the user. A test under a
   node of 1024 processes, and one of 1024 ports, holds each (the log's *A Node's
   Limits*). Beside them, feedback 222, ernest-httpd's 18: a
   certificate or a key `Tcp.listenTls` cannot read, or that is not there, answers as a file
   it refuses does, `Other` naming the file and the reason, `Other("cert.pem: Denied")`,
   where it answers `Denied` or `NotFound` today, the answer a port refused gives; E.18
   first.

   Found the same day, under `make test`'s parallel load, once in four runs of the runtime's
   tests: `ern_os_tests`' `read_ends_before_the_hangup_test` saw its run fault with the host's
   `epipe`, where E.23 has a read the program waits in end before the hangup, its status 1 or
   129. The hangup can reach a program that has already ended, and the write of it to the
   helper's pipe faults instead of ending the read (the log's *The Hangup's Order*); fixed here,
   the test run under load a hundred times to hold it. A second, found 2026-11-04 under the
   same load, once in five runs that day and not alone: `ern_rt_tests`'
   `faults_before_the_end_are_reported_test` timed out in `ern_rt:entry_end/2`, its program's
   entry waiting for the reaper's word of its end while the test's reporter held the reaper
   until that end. Not yet diagnosed; diagnosed and fixed here, held the same way.

   Feedback 231, ernest-httpd's 24, built 2026-11-04 (the log's *A Node's Schedulers*): every
   host the launcher starts is sized by the processors it may run on. ernest-httpd's two-node
   container measures again on the next archive, and the container's caps and CPU share are
   decided from that.

2. **The host's collection at the wait.** A process that drops a value and waits holds it until
   its next collection, which the host runs only as the process allocates (§10): the server's
   idle connection held its last response. The runtime moves the host's own collection to the
   wait: a `receive` that finds nothing to take asks the host, before it waits, for the
   process's counts, and collects where the binaries referenced since its last collection pass
   the host's own threshold, `min_bin_vheap_size`; a receive that takes a message at once pays
   nothing, and one that waits pays one call of the host's beside its suspension.

   §10 states it, a test holds the probe, a process that drops a megabyte and waits and the node's binary
   memory falling, `make bench` measures a waiting receive before and after, and the server's
   measurement under its `measure/` shows the gain. Where the cost is more than a fraction of
   a wait, the design goes to the log with its number and the rule of §10 stands alone.
3. **Memory shown.** `Process.status` and `:processes` show each process's memory, the host's
   count with its binaries (E.21, §11.2), read against E.0's rules first, so that an operator
   sees what an idle connection holds.
4. **The deployment guide says what a waiting process holds**, one sentence in its section 7,
   pointing at §10 and item 2.
5. **`kill` takes a `Process`**, feedback 213, as `monitor` does, so that a function of an
   address passes it through `Process.fromAddress` once for both; Appendix E.21 first.
6. **Text from bytes that are not all UTF-8**, feedback 206, decided 2026-11-02, the policy
   §11.2 and §11.5 state for the shell's region and a diagnostic's source line: each byte that
   begins no character shows as U+FFFD. Two functions, `String.fromUtf8Lossy`, the bytes as
   text so, and `String.fromUtf8Piece`, the text of a piece of a stream and the bytes of a
   character the piece ends inside, which the reader keeps for the next piece; admitted by
   E.0's rule 3 as policies of `fromUtf8`, as `Float.round` and `Float.floor` are of one
   conversion, Ernest closing the difference around the host's decoder (rule 1), E.5 stating
   them. The shell's `foreign fn decoded` and the harness's own decoding go; the compiler's
   diagnostic keeps its Erlang, since the compiler calls no shim.
7. **A text after its prefix, and a slice to the end**, feedback 214 and 220, decided
   2026-11-03: `String.slice(x, i, String.size(x))` and `Bytes.slice` to the end stand at 23
   sites, and the text after a prefix is taken three ways at seven sites, counted 2026-11-04:
   two private `stripped` helpers, `String.splitOnce` matched against an empty first part, and
   `String.startsWith` with a slice. One reading against E.0's rules decides both, the
   functions admitted named by the guide's style, and every site written with them (the
   log's *The Generator's First Stage*). The same reading decides feedback 215: `String.contains(x, "\r")`
   finds no carriage return in `"\r\n"`, since E.5 searches by graphemes, and whether a
   search by code points stands beside it. And feedback 227, a text without its suffix,
   written as a slice after `String.endsWith` at three sites of the site's generator, the
   dual of 220.
8. **A worker's value or its end, and a test's scratch**, feedback 209 and 211: one reading
   against E.0's rules of a `Process` function that runs a function monitored and answers its
   value or its end, written by hand at five sites, of a temporary directory from `Fs`, and
   of `Test.equal`'s failure marking where two values differ. Feedback 226 joins them, `List.dropWhile`, the rest of a list after a run, written
   `let #(_, rest) = List.span(list, test)` at seven sites.

   With them two of ernest-httpd's lines: feedback 224, its 20,
   `Json.encode`, a value as JSON on one line, the host's `json:encode`, read against E.0's
   rules beside `format`'s layout; and feedback 225, its 21, a named decision for the user:
   `ern test` cannot read what a case writes on standard error, so a test of a line the design
   says a program writes there cannot check it, and the line stands among the passes, as four
   of ernest-httpd's do at every run; a case's standard error captured, or a `Test` function
   that runs a function and answers what it wrote, decided here first. And feedback 228, a listed entry's
   name: `Fs.list` answers each entry by its path, so the site's generator writes
   `Optional.withDefault(Path.name(entry.path), "")` at three sites; whether `Fs.Entry` carries
   its name is read against E.0's rules with E.17.

9. **A program's environment and working directory**, feedback 207, decided 2026-11-03: `Os.Command`
   gains what the host's `exec` takes, an environment and a working directory, so that an editor
   under a terminal gets its `TERM` and a program its directory without `env` or `sh -c 'cd'`
   in the arguments; the form, which every program that starts a program writes, decided here
   first, since `Command(program, arguments, input)` stands at ten sites of the standard library
   alone (feedback 184).
10. **`libs/http`'s values**, feedback 186: a value for its ordinary limits and one for HTTP/1.1,
    named by the guide's style, the examples and the pages using them.
11. **`libs/uri`**, feedback 210, decided with the user 2026-11-03: RFC 3986's authority and
    percent-decoding as a library, the published specification being a library's work, with
    `libs/http`'s target decoding and a cookie header's reading beside it, so that
    `examples/fetch.ern` and `web_server.ern` parse neither by hand.
12. **A process owns what it opens**, feedback 208: `examples/fetch.ern` closes its socket only
    on success, so it spawns a process for each fetch, whose end closes what it opened (§8.7),
    and the guide's section on sockets says so in a sentence; no form of the language closes
    on every way out of a block.
13. **An error across a library**, feedback 185: a block's `<-` takes one error type, so a
    library whose error wraps the host's makes a program lift every `Tcp` call. A proposal, to be written under
    `docs/proposals/errors_across_libraries/`, argues the three ways, the library answering
    `Io.Error` itself, a conversion declared at `<-`, or the form standing as the one way to lift
    with the library reading and writing the socket for the program, the third recommended;
    decided with the user, then built here or dropped.
14. **The libraries' shims read against E.0 rule 1**, from the release review before 0.9.0: `ern_http`
    runs the whole head loop in Erlang, the limits' accounting, the words and the values, where
    G.11 says a primitive reads a line and the rest is Ernest; `ern_json` computes a position, a
    too-long number's offset and a lone surrogate's in Erlang; `Base64.decode`'s strictness scan
    could be Ernest around an exact shim. Each measured first, and moved where the Ernest costs
    less than three times the host's function (the findings E4-25 to E4-27).
15. **What a lambda's reach finds on a peer**, feedback 217, a named decision for the user: a
    lambda naming `Ansi.clearScreen`, spawned on a bare node whose tree holds `libs/ansi`,
    answers `Left(Io.NotLoaded)`, since a reach crosses as forms and §12.7 loads a
    toolchain-owned unit only where the spawned function's own unit is the toolchain's;
    discussed with the user against principle 1 before §8.7 or §12.7 changes.
16. **Relative names**, feedback 204, decided 2026-11-02: a qualified name resolves from the
    writer's own namespace outward, as a relative path resolves from its directory, so that
    `Command.parse` in `Ernest.Shell` names `Ernest.Shell.Command.parse` and `Region.Region` in
    `Ernest.Shell.Complete` names its sibling's; a name written longer than its shortest
    resolving form is an error whose help names the short one, as `Prelude.x` is (§4.2), and
    Appendix H's canonical form keeps the full name. The lookup is C++'s and C#'s, with no
    import; a proposal under `docs/proposals/relative_names/` first, with how far a short name
    reaches, then §4.2 after the cold reading, the checker, the diagnostics, `ern doc`, the
    shell's completion, and the shell's own sites written short.
17. **`or` inside a pattern**, feedback 232, decided 2026-11-04: `#(Paste or Load, _) ->` is
    refused as `a tuple has two components or more`, with a help to add a component, which names
    a problem the code does not have. An `or` stands between a clause's whole patterns and
    nowhere inside one, as it does today, so §5's pattern section says so in one sentence
    first, beside "Patterns nest to any depth". The parser then names it: `an or stands between
    a clause's whole patterns`, the help writing the clause's alternatives out,
    `#(Paste, _) or #(Load, _)`. Small, and built in no particular order (the log's *An `or`
    Stands Between Patterns*).

Dropped on 2026-11-02, its verdict in the log: feedback 184, a shorter form for a command
started with no input.

## MVP 4.2 (the website)

Ernest's website, served by ernest-httpd (MVP 4.1), decided with the user on 2026-10-10 (the log's
*ehttpd and the Website*): what Ernest is and its six claims, the three ways in, the tour, the
guide and the report, each with the reader it is for (the log's *The Tour Written*), the
library's pages, and a live shell, a terminal in the visitor's browser connected by WebSocket to
`ern shell` behind a pseudo-terminal on the server, since no full BEAM runs in a browser.

Its design is `docs/proposals/site/decisions.md`, begun 2026-10-13, read back on 2026-10-30 and
ready the same day: the root, the anchors, the homepage, every page, the look, the links, the
templates, the generation, the live shell's page side and the documents; the first design's
templates and mockup stand beside it. Built ahead of its items on 2026-11-03: a node's `limits`
in `ernest.conf`, report §12.5, so that the two nodes of a visitor's container fit the
server's memory (the log's *A Node's Limits*). Its sandbox is the operating system's, one container per
visitor running the plain shell, whose server side is the httpd proposal's; a sandbox of the
language's was weighed and set aside on 2026-10-13 (the log's *ehttpd and the Website*), and the
attached shell, MVP 4.0, is the operator's alone.

1. **The look, by hand**, done 2026-11-03 (the log's *The Site's Look, by Hand*).
2. **The generator**, done 2026-11-03 (the log's *The Generator's First Stage*, *The Generator's
   Second Stage*, *The Generator's Third Stage* and *The Pages Read Against the Principles*).
   `roff` moves from `libs/markdown` to `tools/manual.ern`, its one user, when something next
   touches the library (decided 2026-10-10).
3. **The document the site lacks**, `CONTRIBUTING.md`, written 2026-11-03; the Releases page is
   `CHANGES.md` (the log's *A Release Carries No History*).
4. **The live shell's page side**, done 2026-11-04 (the log's *The Start Line's Length* and *The
   Client's Questions*).
5. **The build and the deployment**: `make site` from a tag by `git archive`, given the
   server's configuration file, with the check of every internal link and anchor, built
   2026-11-03 (the log's *The Generator's Third Stage*); the copy of `build/site/` to the host,
   and the site live at ernest-lang.org with the smoke test against it, which wait on a
   release of Ernest holding the site. ernest-httpd's container with its two nodes was built
   2026-11-04 on the archive from 612faac8, its caps 128 processes and 128 MiB, and its CPU
   share one core, the user's choice from its measure: 3.2 s from start to the homepage's
   example answered, against 6.7 s at half a core.
6. **The Emacs mode's indentation of a brace in a bracket's item**, done 2026-11-03 (the log's
   *The Mode's Brackets*).
7. **Projects**, done 2026-11-04 (the log's *Projects, a Page of Their Own*).
8. **The browser test's joined session flakes**, a defect found 2026-11-04, fixed by 2026-11-06:
   `make test-browser`'s "a whole load and a joined session" failed in two of five runs that day,
   once with no connection reaching its stub and once with Chrome's DevTools not answering an
   evaluation, which may be the page's script held busy. Diagnosed at its cause, the client's or
   the test's, and fixed there; then twenty runs in a row hold it.

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

A decision for the proposal, raised by the release review before 0.8.0 (the log's *The Release
Review Before 0.8.0*, L1): a fix inside a loop's reach changes the hash of the function the running
processes run, so `Code.running` no longer finds them, and a process found by its site alone can be
killed and not moved, since a `Process` cannot be sent to (§6.5). Whether the shell's round gives
the operator a way to reach such a process is decided with the proposal, against §6.5's decision
that an address is the permission to send.

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
3. **The raise a primitive catches**, `ern_base64:decode` and `ern_json:parse` among them, whose
   cost grows with the caller's stack, 0.4 microseconds on a shallow stack and 110 at 100,000
   frames, the trace's capture (found 2026-11-01; the log's *The Four Libraries*): read in erts
   and taken to `otp_bugs.md`, or decided against the trace `backtrace_depth` keeps.
4. **The full review**, as `full_review.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says, the batches' sentences read cold before the build.
5. **Ernest 1.0.0**, by `docs/release_review.md`'s step, on Linux: macOS unverified and said so
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
| The pun | a field given or matched by the variable of its own name written once, `Desk(=local)`, swept over 874 sites with the style test holding it; the round that opened it, ten feedback lines decided and three rules built, a guard's field read, the shell's line by site, and the timed wait's effect, superseded the same day by a `receive` that always receives and `Clock.sleep`; an alarm that can be canceled; `make version`, Appendix D whole, the settler's restart tested, the guide's lines after the release review read; the three outside programs on floor 0.8 | 2026-11-01 | the release after 0.7.0 | *The Pun*, *The Pun's Opening Round*, *A `receive` Always Receives*, *An Alarm Can Be Canceled*, *`make version`, Appendix D Whole, the Settler's Restart*, *The Guide's Lines After the Release Review* |
| Ernest 0.8.0 | a small release, the pun's: a doc example run at its own mailbox type, a census of forms over the repository's Ernest, a one-field request's reply declared positional and passed bare, and the release review before it, 92 findings | 2026-11-01 | tag `v0.8.0` | the log's *Ernest 0.8.0, a Small Release*, *The Release Review Before 0.8.0* |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, which serves ernest-lang.org since 2026-11-02, and what it asked of Ernest: TLS in `Tcp`, a program under a pseudo-terminal in `Os`, the libraries `base64`, `crypto`, `time` and `http`, seventeen lines of feedback decided the days they came, the terminal tests' harness in Ernest, and the release | 2026-11-03 | ernest-httpd 0.1.0, tag `v0.1.0` in its repository; Ernest 0.9.0 | the proposal `docs/proposals/httpd/`, gone with this row, the server's own at https://github.com/joagre/ernest-httpd/blob/main/docs/proposals/basic/proposal.md; the log's *TLS in `Tcp` and a Terminal in `Os`*, *WebSocket Is the Server's*, *The Four Libraries*, *A Path Through a File*, *Three Lines From the Server*, *No Numbered Variables*, *A Close, an Exit and a Write*, *An Archive Says Its Commit*, *Two Lines on TLS*, *A Program After Its Exit*, *Four Lines From the Deployment*, *What the Server Taught*, *The Hangup's Order*, *The Error's Place*, *The Harness in Ernest*, *Three Flakes Read* |
| Ernest 0.9.0 | the server's release: what ernest-httpd asked of Ernest, and the release review before it, 112 lines fixed and 23 decided | 2026-11-03 | tag `v0.9.0` | the log's *The Release Review Before 0.9.0* |
| MVP 4.2 | the website, served by ernest-httpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | | | above |
| MVP 4.3 | the shell's second round | | | above |
| MVP 4.4 | the promise of 1.x, the cost analysis, the full review and Ernest 1.0.0, Linux | | | above |
