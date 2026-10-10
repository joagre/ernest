# Ernest Implementation Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`decisions.md`](decisions.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first. The milestones to come follow in order, then what is done. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in the log's *Later*; nothing stands between.

---

## Where we are

**MVP 3.0 is done** on 2026-10-09: one program on several nodes, by its proposal, read by
five of the review's readers and every finding worked (*Done* below). MVP 3.1's and MVP 3.2's
designs, [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md) and
[`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md), were read through with the user on
2026-10-09, and their sections below are written from them. The principles review ran the same day over
MVP 3.1's proposal and over peers, and its decisions are built (the log's *The Principles Review
of 2026-10-09*). MVP 3.1 is done on 2026-10-10 (the log's *MVP 3.1 Done*). The road to 1.0 is MVP 3.1, 3.2,
3.25, the tour and the review; ehttpd, the website, the shell's second round and the back end follow
1.0 (the log's *The Road to 1.0, Ordered*). MVP 3.1 ended with a read of what it built, its item
9, and MVP 3.2 ends with a release, Ernest 0.4.0, its item 9 (the log's *A Read Before MVP 3.2* and
*Ernest 0.4.0 Ends MVP 3.2*); any other release waits until the user calls it.

**MVP 2.99d is done** on 2026-10-06: the standard library stands on the host and is
measured, with the prelude and the emitted code, and the report's and the guide's feedback
shipped as Ernest 0.3.1 (*Done* below).

**Ernest 0.3.1 is tagged** `v0.3.1` on 2026-10-05, a documentation release from MVP 2.99d:
the manual pages rewritten to teach, the examples made to teach, the guide staged for its
reader and the report's contracts made precise, no rule changed.

**Ernest 0.3.0 is tagged** `v0.3.0` on 2026-10-05, the end of MVP 2.99c: the core
language argued sound in [`soundness.md`](soundness.md) and generated against, the grammar,
the standard library's laws and well-typed programs as machines, and a full review of every
area, whose 570 findings were worked before the tag. Next is MVP 2.99d, the library and the
prelude measured against their lines, and the report's and the guide's feedback. MVP 2.99b,
what the release review left, the code's names read and made to read, operations records,
and running as a service, was done on 2026-10-03; the principles review closed on
2026-10-01, and Ernest 0.2.0, the second release, is tagged `v0.2.0` the same day. Ernest
0.1.0, the first release, is tagged `v0.1.0` and was published on 2026-09-30 with MVP 2.99;
MVP 2.9, MVP 2.61, `libs/markdown` and MVP 2.8 were taken out of order. Each has its
paragraph under "Done".

---

## Milestones

| | What | State |
|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | done 2026-09-18, tag `mvp1` |
| MVP 2 | the rest of the report on one node | done 2026-09-19 |
| MVP 2.5 | a complete standard library | done 2026-09-20 |
| MVP 2.6 | the shell | done 2026-09-25 |
| MVP 2.61 | the guide as the user's document | done 2026-09-24, out of order |
| MVP 2.65 | the language and the toolchain read back | done 2026-09-26 |
| MVP 2.66 | the standard library's `Supervisor` | done 2026-09-27 |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | done 2026-09-28 |
| MVP 2.8 | the formatter | done 2026-09-28, out of order |
| MVP 2.9 | an Emacs major mode | done 2026-09-23, out of order |
| MVP 2.95 | manual pages, an installation, the review | done 2026-09-28 |
| MVP 2.96 | a result annotation written with `:`, and a process's addresses taught | done 2026-09-29 |
| MVP 2.98 | what the first review left | done 2026-09-30 |
| MVP 2.99 | a restart begins afresh, and the first release | done 2026-09-30, tag `v0.1.0` |
| MVP 2.99b | what the release review left, names that read among it; operations records: the requirement `needs a.compare`, a record filled from a namespace, an ordered set and an ordered map; running as a service | done 2026-10-03 |
| The principles review | the report and the guide against §0, and §0 against what it decided | done 2026-10-01, and again 2026-10-09 before MVP 3.1 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | done 2026-10-01, tag `v0.2.0` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | done 2026-10-05, tag `v0.3.0` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | done 2026-10-05 |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | done 2026-10-05, tag `v0.3.1` |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | done 2026-10-06 |
| MVP 3.0 | peers: one program on several nodes, by its proposal | done 2026-10-09 |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing`; then a read of what it built | done 2026-10-10 |
| MVP 3.2 | code with a spawn: the exchange, the bare node, a unit let go, and `Code`; then a release, Ernest 0.4.0 | design read through 2026-10-09; stands on MVP 3.1 |
| MVP 3.25 | placing work by load: the proposal `proposals/balancer/suggestion.md`, a computation run where there is room and its value back, discussed with the user before MVP 3.2's report is written and built here after it | the proposal stands on MVP 3.2; added 2026-10-10 |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program grown from one node to a rolling upgrade | outline to be written with the user |
| MVP 3.9 | the review before 1.0: the full review, the numbering decided once, the promise | |
| MVP 4.1 | ehttpd, an HTTP/1.1 server in Ernest in a repository of its own, and the libraries it wants | `libs/markdown` done 2026-09-25 |
| MVP 4.2 | the website, served by ehttpd: what Ernest is, its characteristics, the three doors, and a live shell in the browser | |
| MVP 4.3 | the shell's second round | |
| MVP 4.4 | after 1.0: a back end to BEAM's own instructions, Ernest's types as the loader's typed registers | a proposal first |

---

## MVP 3.2 (code with a spawn), about four weeks

Designed in [`mvp3.2.md`](../proposals/nodes_and_code/mvp3.2.md), split from `mvp3.1.md` on
2026-10-09 and read through with the user the same day; its reasons are
[`code.md`](../proposals/nodes_and_code/code.md)'s sections 1, 3 and 5. It stands on MVP 3.1
and changes nothing of it. The proposal is the specification and this list the order. What the
milestone gives: a spawn whose function the peer lacks ships the lacking definitions of its
reach, as canonical forms, verified, compiled and loaded on the peer before the process
starts; the bare node, `ern run --config-dir dir` with no `.erc`, which runs what its peers spawn
on it; a function typed at the shell spawned on a peer with its code; a unit let go when no
process runs it and the node nears a limit; `Code`, with `load`, `hashes` and `running`; and
a unit a table's function holds never let go, a limit stated in place of a refusal.

The items, in build order, each with the report's sentences first, its tests, and a commit.
The order is the dependency's: the report first; the limit a table sets on the let-go, stated
before anything is let go; the exchange before the unit it fills; the let-go once units arrive; then
what stands on the exchange, the bare node and the shell; `Code`, which reads the table; and the
tests and measurements over all of it.

**Before item 1, the feedback pass.** The lines of [`language_feedback.md`](language_feedback.md)
are sorted as a read's findings are (`full_review.md`, *The findings*): fixed now, decided with the
user one at a time against §0, folded into the item of this milestone that touches them, or
dropped with the principle named; none is deferred again. The log's *Later* is read with one
question, which entries this milestone's work touches, code crossing with a spawn, the bare node,
`Code` and the unit let go, so that an entry whose "what would change it" this milestone
supplies is decided inside it and not found again by its read. Decided with the user on
2026-10-10 and run the same evening (the log's *The Feedback Pass Before MVP 3.2*): 94 is item 2's, 96
went to *Later*, 97 and 98 are MVP 4.3's, 99 and 100 are settled, and 91's rule, the shell's
evaluation process living while the session runs, is §11.2's, built with MVP 3.1's read; item 1
rewrites *Later*'s five entries this milestone touches.

**Second, before item 1, MVP 3.25's discussion.** The proposal `proposals/balancer/suggestion.md`
is discussed with the user before this milestone's report is written, since what it decides, the
shape of a spawn that chooses its peer, whether a node is a place for its own work, and whether
`Balancer` and `Load` stay as they are, may change what item 1 writes into §8.7 and Appendix G;
deciding it after would write the spawn twice. The discussion stays in the proposal until the user
says it is ready, as CLAUDE.md has it, and nothing of it enters the report before item 1; what it
decides is built as MVP 3.25 after this milestone, or as this milestone's own items where it is the
spawn's shape. Decided with the user on 2026-10-10 (the log's *A Milestone for Placing Work by Load*).

**Third, before item 1, an example of typed channels.** Written on 2026-10-10 (the log's *The
Typed-Channels Example*): `examples/typed_channels.ern`, a counter whose mailbox has one type, met
with four doubts a reader may have of a typed channel, each answered in a line of `main` under a
numbered comment with the refused line quoted beside it in the compiler's words, a send of another
type, a reply answered twice, a clause that cannot run; and `examples/typed_channels_nodes.ern`, the
same counter on a node of its own, offered under a key and found and called from another, the hash
the key carries and a lost connection's cost in one comment. Both are plain programs: what the first
draft carried of `restarting`, `Os.terminating`, `kill`, monitors, `Standing`, a reply answered from a
peer and a foreign send was cut, each a concept beside the one the example teaches. Run by the tests
as the other examples are, and on two real nodes. What writing it found is `language_feedback.md`'s
101 and 102; it seeds the tour's outline (MVP 3.3).

1. **The report and the soundness argument.** §8.7 for the spawn that carries its code, the
   four frames, verification, quarantine and one load, `Refused` with the peer's text, a peer
   that may spawn on a node running what it sends, and the bare node; §11.2 for a bare node, for
   what a node lets go and for a function typed at the shell spawned with its code; §8.1, §8.5,
   §8.6 and §11.8 for a bare node's entry process, which runs no `main` and ends by termination;
   §6.10, whose cross-node sentence is completed by a spawn that carries its code; Appendix G.1
   for a unit a table's function holds, never let go; Appendix E's page for `Code`, its hashes
   `String`s, and `running` a form counted as `Peer.spawn` is (§3.11, §0); Appendix F
   and `style.md`'s glossary for exchange and bare node; `soundness.md`'s section 7 extended to
   code that crosses. The log's entries, pointing at `code.md`. With them, as the build reaches
   each: `architecture.md` for the exchange's process and the let-go; `memory.md` for what a
   node holds of received code and when it lets go; `docs/development.md`'s table, from which the refusal of a node without a program
   goes.
2. **The limit a table sets.** A unit whose function an `Ets.Table` holds is never let go, since
   the host's check sees a process's functions and not a table's, stated in §11.2 and G.1 and
   counted against the limits of section 7; no refusal of the compiler's (the review of
   2026-10-09, S7, §0's principle 5); a test that such a unit survives a sweep.
3. **The exchange.** The spawn frame MVP 3.1's; a peer that has the hash starting at once; a
   peer that lacks it asking for the reach's list, the sender listing the hashes the function
   reaches transitively, code and types, with the foreign declarations it names, the peer
   answering the hashes it lacks or `NotLoaded` for a foreign module or a binding, and the sender
   shipping the lacking definitions dependencies first, each code frame one definition's canonical
   form with its immediate references and never a compiled binary; the four frames beside MVP
   3.0's six; each frame verified against its hash as it arrives and held apart until the reach
   is complete, what the peer said it has pinned meanwhile; a faulty frame ending the connection;
   a reach the peer cannot compile or load failing the spawn with `Refused` and the peer's
   text; the exchange in a process of its own on each node, the gateways only passing its frames,
   the spawn's time covering it, two spawns waiting on one hash sharing one exchange.
4. **A unit on arrival, and the let-go.** Every unit's functions named by their position in it,
   the build's as an arrival's, so that a unit adds one atom, its name, a trace and the shell
   showing a function by the name its build gives its hash, and every caller by name, the entry
   point, a test, the shell, a binding's initialization, `ern doc`'s calls into `Markdown`,
   finding its function through the code table; every unit made by the back end from the
   canonical forms alone, the build's path typed tree, form, unit, so that a form lacking what
   the back end needs fails a test; the golden files of emitted Erlang regenerated. The
   definitions that arrive in one exchange one unit, under a name from the node's pool, each
   reference linked through the table before the unit is compiled by the build's back end from
   the same forms;
   the canonical form of a received definition, and of one typed at the shell, kept beside its
   compiled code and shipped onward as the node's own; a compiled module the shell loads beside
   another unit of its name made a unit of its own from its forms, which MVP 3.1 refuses, the
   refusal lifted from `docs/development.md`'s table; loading by the host's `prepare_loading`
   and `atomic_load`, one batch per reach, no `-on_load`; the node's units off the code path;
   nothing on disk but the build directory, a node restarted sent the rest again. The let-go: a
   unit that arrived by an exchange or a load unloaded when no process executes it or holds a
   function of it, which `erlang:check_process_code` tells, when the node nears a limit of
   section 7, oldest first, until it is under; an idle unit staying until then; the build's own
   units never; a unit let go leaving the table and returning its name to the pool, and crossing
   again at the next spawn that needs it.
5. **The bare node, and the shell.** `ern run --config-dir dir` with no `.erc`: the runtime and
   the system processes, the entry process evaluating the standard library's bindings and
   waiting, the node listening and taking spawns, ending by termination alone, refused without
   `listen`, offering what the processes spawned on it offer; a balancer placing work on it and
   installing its measure there; a shell whose load path holds no program a bare node with a
   prompt. A function typed at the shell spawning on a peer with its code, where MVP 3.1 answered
   `NotLoaded`; the refusal of a node without a program lifted from `docs/development.md`'s
   table.
6. **`Code`.** §11.1's outcome for a build written under a running node, which MVP 3.1 states as reaching the node at its next start alone, is restated here for a node that reads a unit after its start. `Code.load(path)`, `ern run`'s loading reached from Ernest, the module's canonical
   forms and its reach's read from the load path, verified against their hashes and made a unit
   as a load of the shell's is, counted against the limits, `Left` for a file that is no `.erc`
   of this `ern` or whose reach the load path lacks; `Code.hashes(path)`, the `.erc`'s table of
   names and hashes; `Code.running(f)`, a form checked as `Peer.spawn`'s function is, `f` a top-level
   declaration of any arity whose result is `Unit with m` known whole where it is written, the
   host's stack of each process mapped through the table to hashes, the processes with a frame of
   `f` itself, typed `Address(m)`, a snapshot; hashes as `String`s, the digest in hexadecimal;
   the page with its executed examples, section 3's upgrade tool among them under `examples/`.
7. **The tests, the measurements and the guide.** The proposal's section 8 whole, on nodes on
   one machine: a spawn of a function typed at a shell that is a node ships exactly the lacking
   definitions, verified and loaded at once, and the process runs; a spawn onto a bare node ships
   the program's reach once and nothing the second time, and the process offers a service the
   program finds; `NotLoaded` for a binding and for a foreign declaration; a faulty frame ends the
   connection; a late or broken exchange leaves nothing half-loaded; a fix crosses with its
   callers, which compile on the peer; a unit whose processes have ended stays until the node
   nears a limit, is then let go and crosses again at the next spawn that needs it, and one a
   process holds a function of stays, and so does one whose function a table holds; a node told to load
   many units says so at four fifths of a limit, once, measured; the shell fixes a service on a
   peer through `Upgrade`; `Code.load`, `Code.hashes` and `Code.running` as section 8 states them.
   The measurements of section 7, and of what a spawn that ships code costs, a bare node's first
   spawn and the callers of a fix above all, against the spawn's time. `mvp3.2.md`'s status line,
   and `mvp3.1.md`'s for what this milestone changed in it.
8. **The deployment guide.** `guide/deployment.md`, written whole here as a teaching document of
   its own, which owns running nodes: a node's configuration directory, `ern reload` and `ern
   stop`, the service manager, and what code by its hash gives a system of nodes, several builds
   running at once and connecting on one floor, two versions of a type as two types, a fix
   shipped with a spawn, the bare node given its work, and a running service moved to new code
   by the program's own upgrade over `Code.running`. Its outline is discussed with the user
   before a line is written, as a design is (requested on 2026-10-10). Decided with it, a named
   decision of this milestone: whether `Code.upgrade` returns, a function that sends a process
   its `Upgrade`, which `mvp3.2.md` set aside as a second way to write one `send` (principle 2)
   and the user reopened for the guide's reader.
9. **The release, Ernest 0.4.0.** The first release with nodes, and the first since `v0.3.1`:
   the review before a release as [`release_review.md`](release_review.md) says, its readers
   over what MVP 3.0, 3.1 and 3.2 changed, the code's reader since `v0.3.1`, the guide's over
   chapter 8 and the deployment guide, and the argument's over `soundness.md`'s section 7;
   every finding fixed, planned or dropped; then `VERSION` at 0.4.0, the `since` of every module
   and exported declaration that appeared since 0.3.1, the pages in `man/`, the notes, which say
   what a program written for 0.3.1 changes, the tag `v0.4.0` and the archive (decided with the
   user on 2026-10-10, the log's *Ernest 0.4.0 Ends MVP 3.2*).

---

## MVP 3.25 (placing work by load)

The proposal [`suggestion.md`](../proposals/balancer/suggestion.md), written on 2026-10-10 from a
program written against `Balancer` that day, asks how a program runs a computation where there is
room and gets its value back, and what `Balancer`, `Load` and `Peer` give today. It stands on MVP
3.2 as `mvp3.2.md` designs it, so it is built once MVP 3.2 is, and discussed before MVP 3.2's
item 1 writes its report, in the proposal and nowhere else until the user says it is ready, as CLAUDE.md's rule for a proposal has it; nothing of
it is in the report, this plan or the log meanwhile, and this milestone says only that the
discussion happens here. What the discussion decides, a shape in the library, in `Peer`, or none,
is built as this milestone's items, written then. Added at the user's word on 2026-10-10 (the
log's *A Milestone for Placing Work by Load*).

## MVP 3.3 (the tour)

A third way into Ernest beside the report and the guide, `tour/`, for the reader who wants the
whole picture in an evening and will read neither: the report is for whoever builds or checks a
toolchain, the guide for the programmer learning the language, and the tour a crash course. It
is a directory of its own at the top level, its document and the programs it grows side by side,
and the README opens on the three doors, each with the reader it is for, what it gives and how
long it takes, so that a reader chooses one and walks in; CLAUDE.md's table of owners gains its
row when the tour exists. One program, the counter of the guide and the proposals, grown chapter by chapter
through every part of Ernest that matters, each shown working, from a process with a typed
mailbox on one node to a rolling upgrade across three nodes written in Ernest. Decided with the
user on 2026-10-10 (the log's *The Tour*); `guide/deployment.md` stays about deployment (MVP
3.2's item 8). It comes after MVP 3.2, whose code with a spawn, bare node and `Code.running` its
last chapters need, and before MVP 3.9, whose newcomer reads it: it is the language's hardest
test, so what it finds is found before the promise of 1.0 (the log's *The Road to 1.0, Ordered*).

- **The outline first, written with the user**, as a design is: the chapters, the program's
  growth from one to the next, and what each shows, explicitly or by the way. A first sketch to
  start from, not a decision: the counter and its client calling with a reply; faults, restarts
  and a supervisor; a fix in the shell, two versions side by side as two types, and the service
  moved by its own `Upgrade`; its total kept across the program's end with `Os.terminating`;
  three nodes, a key and a find, `Standing`, a balancer; a bare node given its work with the
  code; and the rolling upgrade, an old and a new build connected meanwhile.
- **It narrates and points, and teaches no rule a third time**: what a rule is and why is the
  report's and the guides', and the tour names the section.
- **Every program in it runs in the tests**, nodes among them, as the guide's examples do.
- **What writing it finds goes to `language_feedback.md`** before any code goes around it, since
  one program grown across every feature is the language's hardest test before 1.0.

## MVP 3.9 (the review before 1.0)

What a promise of stability needs and a first release could leave out (the log's *The First
Release Is for Others*), after the language was argued in MVP 2.99c:

- **The full review**, when the user says so: every reader over the whole of its area
  ([`full_review.md`](full_review.md)), and its findings worked.
- **The numbering decided once.** Whether the report's section numbers have drifted enough since
  0.1.0 to renumber, with the mapping table written first and one commit that rewrites every
  citation, in the report, the guide, the log, the code, the tests and the diagnostics; or the
  numbers kept for good (the log's *The Language Argued Before Peers*).
- **The promise**: what 1.0 holds stable, stated in the report's §0 and the release's notes.
  Until then a release may refuse a program the previous release accepted, and its notes
  point at what changed rather than list it (the log's *A Release Carries No History*).

---

## MVP 4.1 (ehttpd, and the libraries it wants)

**ehttpd**, an HTTP/1.1 server written in Ernest, in a repository of its own, decided with the
user on 2026-10-10 (the log's *ehttpd and the Website*): the base of Ernest's own website, MVP
4.2, and the first program built against an installed Ernest by a build of its own, which the
examples cannot be. Its plan lives in its repository; this one records what it asks of the
language and the libraries, and each is written as it asks, the libraries below among them.
Named so far for it: HTTP's message format, `libs/http`; WebSocket, RFC 6455, for the website's
terminal, a library over `libs/http` and `Tcp`; base64; TLS on a socket; and what of `Tcp` a
server needs beyond what E.18 gives. What writing it finds against the principles goes to
`language_feedback.md` first, as any Ernest written here.

A library not yet written waits, and is written when our work needs it, MVP 3.0 and 3.1 among
that work, when someone asks for it, or when we want it, decided 2026-09-25 (the log's
*Libraries As They Are Wanted*). Each is an Ernest source root under `libs/<name>/` that a
program adds with `--load-path`, with `stdlib/`'s test discipline, documented in one pass to
[`module_doc_template.md`](module_doc_template.md) with its executed examples as its first
user, and a section in the appendix of libraries. Own repositories come later, when there is a
package story. Written: `libs/ets`, `libs/markdown`, `libs/ansi`, `libs/load`,
`libs/balancer` and `libs/json` (Appendix G; `libs/markdown` under "Done", `load`, `balancer`
and `json` in MVP 3.0). Named so far:

- **`libs/base64`**, a shim over `base64`.
- **`libs/tls`**, a shim over `ssl` and `public_key`: `listen`, `accept`, `connect`. Whether
  it answers `Tcp`'s `Address(SocketMsg)`, its foreign process then speaking an encoding private
  to `Tcp` (E.18), or a socket type of its own with its own `read`, `write` and `close`, is
  decided when it is written. Certificate verification is the caller's to ask for.
- **`libs/http`**, Ernest over `Tcp` and `Tls`: request and response types, their parsing and
  rendering in both directions, and a client. No server loop; that is the web server example's,
  whose hand-written parser and renderer the library replaces (feedback item 55; the log's *The
  Web Server Waits for Its Library*). With it, `examples/fetch.ern`, a command-line tool that
  fetches JSON over HTTPS and prints a report, and `Time` in Appendix E over the clock's
  milliseconds.
- **`libs/regex`**, a shim over `re`, a library and never syntax: `Regex.compile : (String) ->
  Either(RegexError, Regex)`, `Regex` a foreign type.
- **`libs/crypto`**, a shim over `crypto` for hashes, HMAC and random bytes; **`libs/uri`**,
  pure Ernest or a shim over `uri_string`; **`libs/zlib`**, a shim over `zlib`.
- **A listing by bytes in `Fs`**, decided when a program must manage a directory others
  write by names it does not choose: `Fs.names` and `Fs.removeName`, through E.0's rules,
  beside an `Fs.list` that stays whole or an error (§8.2; the log's *Later*, S17).
- **A read and a write in `Fs` that refuse a link under a root**, decided when a program
  serving files from a root others can write is written: `Fs.readUnder` and `Fs.writeUnder`,
  through E.0 rule 1, walking by opened directories in the runtime's helper, started per call
  or resident as that program's cost decides (E.17; the log's *Later*, S16).
- **A file made with a mode in `Fs`**, decided when a program must write a file only its owner
  may read into a directory others may enter: a function beside `makeFile` that takes the mode,
  through E.0 rule 1, opening with it in the runtime's helper (E.17; the log's *Later*, S9).
- **`Udp`**, a system module of Appendix E beside `Tcp` and not a library, admitted by E.0
  rule 1 and written as wanted too, with `Tcp`'s shapes: a socket an address, a read pulled
  with a time, a datagram `Bytes` (the log's *`Clock.monotonic` Is In, and `Udp` Is
  Placed*).

---

## MVP 4.2 (the website)

Ernest's website, served by ehttpd (MVP 4.1), decided with the user on 2026-10-10: what Ernest
is, its characteristics, and the three doors of MVP 3.3, the tour, the guide and the report,
each with the reader it is for; and a live shell, a terminal in the visitor's browser, a
JavaScript terminal such as xterm.js, connected by WebSocket to `ern shell` behind a
pseudo-terminal on the server. The shell runs on the server, since no full BEAM runs in a
browser, and the shell drives a terminal through `Terminal` and so runs behind one unchanged.
Its sandbox is the first decision of the milestone, and the operating system's and not the
language's, since Ernest's system modules are ambient by design: one isolated container per
visitor, with limits on time, memory, processes and network, and nothing kept when the
visitor leaves. The site's pages are written in Markdown and rendered by `libs/markdown`.

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
4. **A shell attached to a running node**, about a week: each input run on the peer, over MVP
   3.0's peers and MVP 3.1's shipping of code. The shell's design does not assume it runs on
   the node whose code it evaluates.
5. **Whether the session owns what its inputs open**, a decision with the user: a socket and
   a running program an input opens end with the input's process, their owner (§11.2), and
   the session could own them instead, so that they live until it ends, by a way the shell
   names an owner for its inputs (`findings.md`'s C1-2, placed here 2026-09-30). Half decided
   2026-10-10 by feedback entry 91: what a `:load`'s binding opens is the evaluation process's,
   which lives while the session runs (§11.2), so the decision left is the input's own process
   alone, which MVP 3.1's read kept ending with the input (its W10).
6. **A previous version at the prompt**, a decision with the user: whether a previous version's
   constructors may be written at the prompt, `Counter$1.Inc`, and whether `:processes` names
   the version a process runs (`language_feedback.md`'s entries 97 and 98, placed here
   2026-10-10 by MVP 3.1's item 5).
7. **The `live_region` test's one miss**, 2026-10-05 in a full `make test` under load (MVP
   2.99d's item 11), passed again alone and under `make test-shell`, and not failed since: when
   it fails again its step file in the run's directory says which expectation went unmet, and
   the fix follows from it; diagnosed here where it recurs, and nowhere before.

## MVP 4.4 (a back end to BEAM's own instructions)

The first milestone after Ernest 1.0, decided with the user on 2026-10-10 (the log's *The Road
to 1.0, Ordered*): a second back end beside the emitter's Erlang abstract format, writing the
BEAM's own instructions, its generic opcodes (`genop.tab`, format 0, additions only, OTP 29's
record instructions among them), with Ernest's proven types written as the loader's typed
registers, so that the JIT emits code without the run-time type tests the Erlang compiler must
keep. It changes no rule of the language, and it makes the soundness argument load-bearing for
the VM's memory safety: a value from outside, a peer's message, foreign code's return, is fully
checked before its register is typed, which §8.4's checks and the argument's section 7 must
then be read as carrying. Conditions before it is built: the language promised (MVP 3.9), OTP
pinned for the long term, and `make bench`'s numbers for what the type tests cost today, which
decide whether it is worth its cost. A first, safe step to measure against: a type guard at each
function's entry, from which the Erlang compiler's own inference types the body. Its design is a
proposal first, discussed with the user, as MVP 3.1's was.

---

## Done

A paragraph a milestone: what it delivered, and where its reasons are.

### MVP 1 — the chain (done 2026-09-18, tag `mvp1`)

Parser, types and BEAM proved with the report's language unchanged, a subset accepted: no
`Float`, no ownership rule for abstract types, no foreign code, no `Tcp`, no distribution, and
exhaustiveness checking from the start. A hand-written lexer and a precedence-climbing parser,
Hindley-Milner with an effect slot (§3.9), the reply discipline (§6.6), one Erlang module per
Ernest module, and one diagnostic record from every stage (§11.5);
[`architecture.md`](architecture.md) says how they are arranged, and the log's entries of
2026-09-17 and 2026-09-18 why.

### MVP 2 — the rest of the report on one node (done 2026-09-19)

Each item a rule MVP 1 refused or did not check: `Float` and operators on user types (§3.1,
§4.8, §5.1); `foreign fn` and `foreign type`, checked at the boundary (§4.7, §8.4); bitstrings
(§5.11); pattern alternatives (§5.9); `Io.debug` (E.1); raw strings (§2.5); abstract-type
ownership (§4.4); the reply discipline through function values (§6.6); `Deadlock` as global
quiescence (§8.6); and nine points from the consistency pass. The log's entries of 2026-09-19
hold the arguments.

### MVP 2.5 — a complete standard library (done 2026-09-20)

Twenty-one modules in Ernest under E.0's rules; the system processes, each used through its
Appendix E module and never by `send`; the checker reading the standard library's compiled
interfaces as any dependency's; the shape of a module's documentation,
[`module_doc_template.md`](module_doc_template.md), carried in the `.erc`'s EEP 48 chunk; and
four paper programs, three under test. `Tcp` was measured at 1.8 times raw Erlang with a
process per socket, and the processes kept. Erlang's standard library was read module by
module against Appendix E (the log's *The Erlang Standard Library, Read for Ernest* and *Fs by
Its Structure, and the Table*). The toolchain's
naming, `ern_<thing>` and `ern@<namespace>`, was done on the way (the log's *One Token for the
Project*).

### MVP 2.9 — an Emacs major mode (done 2026-09-23, out of order)

`emacs/ernest-mode.el` and its tests, run by `make test-emacs`;
[`emacs_mode.md`](../proposals/emacs/emacs_mode.md) owns the mode. It gave the style guide six indentation rules,
and a test holds the mode's word lists equal to the lexer's.

### The report read as a Wirth report (done 2026-09-23 and 2026-09-24)

The report read as a Wirth report and against §0: its plain errors fixed and about thirty
issues decided one at a time, each a report change with its entry in the log. The largest: a
statement other than a block's last has type `Unit`, and a value is discarded with `let _ = e`
(§5.4); `Ets` left the standard library for `libs/ets` (§10, E.0 rule 1); a fault is a death
with `Fault(cause)`, every cause listed in §7.4, a deadlock the entry process's (§8.6);
`Prelude.X` reaches a shadowed prelude name (§4.2); a parenthesized right side of `|>` is a
value (§5.7); §9 states what makes a type the prelude's; a `String`'s unit is a grapheme
(E.5); the bit syntax dropped `bits` and `native` (§5.11); and §6.6 was rewritten top-down.

### MVP 2.61 — the guide as the user's document (done 2026-09-24, out of order)

The guide rewritten to teach Ernest on its own, in nine steps: every example checked by
`test/ern_guide_tests.erl`, an opening that shows four mistakes the compiler finds, one running
example, a section on failure with a supervisor, pages for the tools and for the Erlang
programmer, a two-reader sweep, and a cold read by a reader new to Ernest. It changed §11.2 and
§11.5 and fixed two defects of the toolchain; the log has each.

### MVP 2.6 — the shell (done 2026-09-25)

The shell, an Ernest program under `shell/`, designed in [`shell_design.md`](../proposals/shell/shell_design.md)
and specified by §11.2; the guide to its code is [`shell/README.md`](../shell/README.md). Five
checkpoints: expressions (2026-09-20); bindings, the commands, fault reports and the startup
files (2026-09-20); the terminal and its live region (2026-09-21); the line editor, the history
and its search, multi-line input and paste (2026-09-21); and completion and documentation
(2026-09-24). Then a closing sweep by two readers, a session of real use and an independent
review, whose thirteen and five findings each became a rule of §11.2 with a regression test,
and a last sweep of the documents. On the way it built `test/ern_pty.py`, the pseudo-terminal
harness every terminal test runs through, turned `Keys` into `Terminal`, split `make test`
into areas, and found about twenty defects in the toolchain. The log's entries from 2026-09-20
to 2026-09-25 hold every argument.

### `libs/markdown` — a CommonMark renderer (done 2026-09-25, now under MVP 4.1)

Pure Ernest, about five hundred lines: `Markdown.parse` reads CommonMark 0.31's blocks and
inlines, and `Markdown.render` lays them out at a width, with the terminal's styles or as
written; where it is simpler than the specification, its doc block says so. It is a library by
E.0, and Appendix G.2 is its section. The shell renders `:doc` and `Shift-Tab` with it.

### The code read back after the shell (done 2026-09-25)

Every line of Ernest under `shell/`, `stdlib/` and `libs/`, and of Erlang under `erl/`, read
for what goes against the principles, for clumsy code and for defects: about twenty-five
defects fixed, each with a regression test, and the report's §2.3, §7.4 and §11.2 changed first
where a fix needed a rule. The shell gained `Shell.Command` and
[`shell/README.md`](../shell/README.md). The log's *The Code Read Back* has the decisions; the
Ernest questions went to the feedback list, and the Erlang ones to MVP 2.65's step 8.

### MVP 2.65 — the language and the toolchain read back (done 2026-09-26)

Every entry the shell and the libraries raised in
[`language_feedback.md`](language_feedback.md) was decided on §0's principles, and a standard
library entry on E.0's rules, each ending in a report change, a "Later" entry in the log, or a
line saying it was weighed and left alone. Ten steps: the list consolidated (step 1); the
report read cold, its plain half written in (step 2; the log's *The Report Read Cold, Its Plain
Half*); five themes, names and namespaces (step 3), expressions, patterns and types (step 4),
processes and the system (step 5; *Names, Restarts and Supervision*), the standard library
under E.0 (step 6; *A Shim Reaches the Representation*, *A Name Follows the Vocabulary* and
*What the Library Lacked*) and the toolchain (step 7; *One Tool, the Job Its First Word*); the
Erlang code's open questions (step 8); the cold read's last findings (step 9; *The Cold Read's
Last Findings*); and the build (step 10). The build had a gate that read steps 5 to 9 whole,
its findings G1 to G16 (*A Gate Before the Build*); a ledger of rows A1 to E1, with decisions
L1 to L8 (*What the Ledger Found*); the report changed in one pass (*The Report Pass of Step
10*) and read cold again (*The Report Read Cold After the Pass*), feedback items 55 to 58
decided with it; the toolchain first, then the rest in six groups (the log's entries from *The
Build's First Group* to *The Build's Sixth Group*); and a closing sweep (*The Closing of Step
10*). What it gave the language: the abstract type's boundary at its module, field selection,
a pure function standing for one with a mailbox, services as top-level bindings with
`restarting` and `fault` and no registry, `Process` and every fault delivered, the system
references in their modules, standard input as bytes, and one tool, `ern`. The log's entries
of 2026-09-25 and 2026-09-26 hold every decision.

### MVP 2.66 — the standard library's `Supervisor` (done 2026-09-27)

Its opening decided the three questions left in the feedback list. `remote` left the language,
placement by load going to MVP 3.0's `Peer.nodes` and the libraries `Load` and `Balancer` (items
8 and 9; §6.7; the log's *No Remote Computation in the Language*). The command line is
`Os`'s, with `Os.run` and `Os.exit`, built in MVP 2.7 (item 16; the log's *A Program's Command
Line Is `Os`'s* and *A Program Ends With `Os.exit`*). The build is `stdlib/supervisor.ern`
(Appendix E.22): `Supervisor.group(strategy, limit)` and `Supervisor.child(sup, f)`, each
spawned by its caller; one limit, the group's; three strategies; children that join at any
time; a supervisor restarted in place restarting its subtree; and `kill(sup)` stopping a group
through a watcher, the last child first. A sibling restarts at its next wait, through a
priority message every wait takes (§6.9; `callee was restarted` in §6.6 and §7.4; the log's *A
Sibling Restarts at Its Next Wait* and *The `Supervisor`'s Shape*). `examples/services.ern`
and the guide's §6.6 show it. Feedback item 61, how a client knows that a group's restart is
over, stays as it is (the log's *The `Supervisor`'s Shape*).

### MVP 2.8 — the formatter (done 2026-09-28)

`ern format` lays out each module named, every module under a directory, or standard input,
changing only line breaks and spaces, and `--check` names each module not laid out (report
§11.6; the log's *What the Formatter Keeps*). `make format` lays out every source and the
Ernest blocks of the report and the guide, and `formatted_test_` holds all of them to it. The
layout is [`style.md`](style.md)'s (the log's *Layout for the Reader*). The Emacs mode indents
as the formatter lays out, from a table of how tightly each operator binds that a test holds
equal to the parser's, and `ernest-format-on-save-mode` lays out a buffer as it is saved
([`emacs_mode.md`](../proposals/emacs/emacs_mode.md); the log's *Format on Save*). Built ahead of MVP 2.7's last
two items (the log's *The Formatter Before the Release*).

### MVP 2.7 — a program started from a command line, and the appendix of libraries (done 2026-09-28)

`Os` gives a program its command line, its environment, its working directory, its exit status
and the programs it runs, a running program being a process (§8.2, §8.6, §11, Appendix E.23;
the log's *A Program's Command Line Is `Os`'s*, *A Program Ends With `Os.exit`*, *`Os.run` Runs
Through a Helper in C*, *A Running Program Is a Process*, *The Environment Read Through the
Helper*, *What Building `Os` Found* and *The Working Directory*). `make load` holds the
runtime's processes, the `Supervisor`, `Tcp`, `Os`, `Fs`, `Clock` and the shell to no growth,
and the reading behind it fixed four growths, the shell's code memory and a false deadlock
([`memory.md`](memory.md); the log's *What the Loads Found*, *The Shell's Code Memory* and
*Atoms, Counted*). A program meant to keep running runs in the foreground under a service
manager: a stream that has gone ends it with status 141, `ern`'s fault lines carry the time
where standard error is a file, and a stop ends it by its signal (the language guide §9.5; the log's
*Running as a Service*). Appendix G lists the libraries under `libs/`, held to their
interfaces (the log's *The Libraries in the Report*). A mailbox stays unbounded, and a write
waits for its stream (the log's *Back Pressure, Again*). The list of what Ernest adds stays at
four (the log's *What Ernest Adds Stays at Four*). The guide was read in order by a reader new
to it, and what it used before teaching is now taught first or points ahead (the log's *The
Guide Read in Order*). `Fs.watch` stays out (the log's *Later*).

### MVP 2.95 — manual pages, an installation, and the review (done 2026-09-28)

`ern doc --man` writes a module's manual page, `Ernest.List(3ern)`, and `ern(1)` is §11
(report §11, §11.4, Appendix G.2; the log's *Manual Pages Named `Ernest.List`*, *`ern(1)` Is
§11* and *What Building the Manual Pages Found*). `make install` installs Ernest under
`PREFIX`, and `make release` writes one archive for every system, compiled where it is
installed ([`install.md`](../proposals/install/install.md); the log's *`bin/ern` Is a Launcher*, *The Layout Under
the Prefix* and *One Archive, Compiled Where It Is Installed*). The review ran a machine for
every check and twelve readers, and is now [`release_review.md`](release_review.md)'s one page (the log's *A
Lean Review*); `make test` went from 280 seconds to under a minute (the log's *The Time of
`make test`*). The readers' findings that lose data, expose a user or break a program were
fixed, each with a regression test, and the rest were MVP 2.98's (`findings.md`, under MVP
2.98 below; the log's entries from *The Sweep Removes What a Build Wrote* to *An Unfinished
Line Leaves the Region a Row at a Time*). Three entries of the language feedback were decided: names stay
qualified and the shell's completion moved into `Shell.Complete`, `List.intersperse` is
refused, and `Fs` sees a symbolic link (the log's *What MVP 2.95 Takes From the Rest* and
*What `Fs` Holds*). An intermittent failure of the guide's diagnostics was EUnit's capture,
not the toolchain's. It is verified on Linux alone (the log's *No Mac for the First
Release*), and the release itself is MVP 2.99's (the log's *The First Release Follows MVP
2.99*).

### MVP 2.96 — a result annotation written with `:`, and a process's addresses taught (done 2026-09-29)

A function's result annotation is written `: T`, as a parameter's is, in every head; a
function type keeps its arrow, and `->` after a head's `)` is refused with the spelling that
replaces it (Appendix A's `Return`, §3.4, §4.5, §8.1; the log's *A Result Is Annotated With
`:`*). 2,154 heads were respelled in one move, and `Shift-Tab`'s signature, which names the
parameters as a head does, writes its result after `:`. The guide's §5.5 teaches that a
mailbox has one type and a process many addresses, made with `via`: why, the system modules'
wraps, where the function runs, what does not deliver, the one process behind them all, and
addresses that travel; a `send` applies an adapted address's function in the sender, and the
runtime a wrap as it delivers (§6.5, §6.9; the log's *A Process's Addresses, Taught in
Order*).

### MVP 2.98 — what the first review left (done 2026-09-30)

Every finding of the first review that MVP 2.95 left was fixed or decided, and `findings.md`
went: its lines with what was done stand at commit `b7d34c0`, and its readers' lists in the
file's history up to commit `08edfda` (the log's entries of 2026-09-29 and 2026-09-30, from
*The Report's Cheap Lines* to *`closeListener` Names What It Closes*). The report's
contradictions and silent cases were decided with the user, each argued in the log's entry
of its name. The formatter lays a type of one constructor as it lays several, `==` reads a
function through a type's arguments, and `Fs` gained `create`, `removeAll`, `setModified`,
`readRange` and `append` (E.17). The foreign boundary checks only what crosses, the runtime's
own left unchecked, and a check lasts as long as the process behind it (§8.4); what Ernest
adds to a host call is measured by `make bench`, and supervision stays in the reaper.
`RestartLimit` gained `Unlimited` (§6.9), `Io.Error`'s `Other` says the host's words (E.1),
and a supervisor's group restarts whole (E.22). Erlang's scheduling hints and a registry of
libraries are out, and the shell's later work is MVP 4.3's. A load samples a node at rest,
the loads flat within 15 KB ([`memory.md`](memory.md)), and make runs `ern build` every
time, its own rule deciding by content (§11.1).

### MVP 2.99 — a restart begins afresh, and the first release (done 2026-09-30, tag `v0.1.0`)

Ernest 0.1.0, the first release, for programs on one node, installed from its archive (the
log's *The First Release Is for Others* and *The First Release Follows MVP 2.99*). A restart
became a new run in all but its address (§6.9, *A Restart Begins Afresh*), and `ern(1)` gained
the sections man-pages(7) names (§11.7, §11.8, *`ern(1)` Has Its Sections*). The release review
ran as [`release_review.md`](release_review.md) says (*The Release Review*), and its findings were fixed area by
area, the security lines first, and its questions decided with the user one at a time (the
log's entries from *The Release Review's Security Lines* to *The Release Review's
Questions*). Among what they decided: `String.split` reads the string once over a private
primitive (E.5); `Fs.removeAll` walks a tree by the directories it has opened, the C helper's
second job (E.17); a socket is owned by the process that opened it, and `Tcp.give` passes it
on (E.18); an address foreign code gives back is the program's own only at the type it went
out at (§8.4); a bitstring literal that does not fit is a compile-time error (§5.11); and
`Prelude.T.name` reaches the standard library's namespaces (§4.2). What the review left is
MVP 2.99b's, its first, third and eighth items, and `findings.md` held it until they were
done.

### The principles review (done 2026-10-01)

The report and the guide read against §0, and §0 against what it decided, as
[`principles_review.md`](principles_review.md) says; decided 2026-09-30 (the log's *The
Principles Review*), its readers run that day on `57b8356`, and worked on 2026-10-01 in the
seven phases the log's *The Attack Plan* gives: the principles' sentences and the sections',
MVP 2.99b's items 1 to 3, the defects, the families' rules and the edits they asked for, the
log, and the closure, whose counts and bench are the log's *The Principles Review Closed*.
Each family is closed by its entry and is not reopened before 1.0 but by a program that shows
a case it did not. What it leaves is dated: the `since` lines of what it added, written with
`VERSION` at the release (the release review's step 5); `Udp` to MVP 4.1 (the log's
*`Clock.monotonic` Is In, and `Udp` Is Placed*); placing work without `Where` to MVP 3.0 (the
log's *Placing Work Without `Where`*); and the guide's §7.3 to MVP 2.99b's item 16. The
release review ran next, and Ernest 0.2.0 shipped the review's rules as one (the log's *A
Release After the Review*); MVP 2.99b resumed at item 7, done on 2026-10-02 with items 4 and 6,
and item 5 followed it, done on 2026-10-03.

### Ernest 0.2.0 — the review's rules shipped as one (done 2026-10-01, tag `v0.2.0`)

Ernest 0.2.0, the second release, after the review before a release ran as
[`release_review.md`](release_review.md) says on `067ef80` (the log's *The Release Review
Before 0.2.0*). Its machines passed, and its readers, the report's, a newcomer's, who wrote a
key-value cache whose entries expire after a time or with the process that leased them, and
the code's over what changed since `691b4d6`, found 55 lines: 33 fixed before the tag, none a
defect in what a program computes, and the rest planned, asked, recorded or dropped as
`findings.md` said. What a program written for 0.1.0 changes is in the
release's notes. What the release leaves: the timers `Os` and `Tcp` leave armed after an
answer, with MVP 2.99b's item 8; the glossary's five names, with items 7 and 15; `ern test`
over a directory, item 19; and four of the six rules that buy little, item 20, the principles review having decided the other two.
After the tag, `man/` took 0.2.0's pages as CommonMark, which GitHub shows, and each release
writes them again (`release_review.md`'s step 5; the log's *The Release's Pages in `man/`*).

### MVP 2.99b — what the release review left, operations records, and running as a service (done 2026-10-03)

Every line the two release reviews left was built or decided, and `findings.md` went: its
lines with what was done stand at commit `d6996f1`. The tests were made trusted first, and
the code's names were read and made to read, in Erlang and in Ernest, the glossary in
[`style.md`](style.md) their word (the log's *The Erlang Read and Renamed* and *The Ernest
Read and Renamed*). Code written once over several representations takes an operations
record: a requirement, `needs a.compare`, which a call supplies without writing it; a record
filled from a namespace; `derives compare`; and `OrderedSet` and `OrderedMap` (§4.9, §5.6,
§3.5; *The Requirement Built*), which the guide's §7.3 teaches. A file's words joined by `_`
name one namespace segment (§4.2). The feedback the reviews left was decided with the user
one entry at a time (*MVP 2.99b's Questions, One by One*): `monitor` takes a `Process`, a test
may receive, `Char.isAsciiDigit` is back, and a recursive type names itself only at its own
parameters (§3.9); `Address.ask` was built and taken out again, and the built-in operators
were made shims and reverted (*`Address.ask` Is Taken Out*, *The Operators Stay Ernest*). The
code readers' hardening was built (*The Hardening Built*). A program takes the environment
`ern` was started in and no ignored signal, a stream that fails ends it with status 141, an
alarm at a time follows a clock that is set, and `make service` runs a program under systemd
(§8.6, E.15, E.23; *The Runtime as a Service, Built*, *The Service Manager's Checks*); the
reaper looks for a deadlock seldom at rest (*The Reaper's Look at Rest*). `Foreign.from`
crosses at its type, and §8.4 states the foreign side's promise (*The Boundary Trusts a Type
Variable*). `ern test` takes a directory, an `Fs.Entry` holds its file's mode and user and
`Os.user` is the program's, and the report is three files under `report/`, each normative
(*The Report in Three Files*). What it leaves: the launchd checks of the service manager's
item, written and waiting for a Mac, which MVP 2.99c's release runs or names in its notes;
and the Erlang that Ernest can hold, MVP 2.99c's item 5. `language_feedback.md` holds no
entry, and stays as the place new feedback is written.

### The full review's findings (done 2026-10-05)

The 570 findings of MVP 2.99c's item 6 were worked, and `findings.md` went: its lines with
what was done stand at commit `0d2de61`, and the log's *The Full Review Run* counts them, 539
done, 23 dropped and 8 placed here, in MVP 2.99d, 3.0, 3.1, 3.2 and 3.3. The 34 design
questions were decided with the user one at a time, and the cheap lines worked a reader's area
a commit (the log's *The Full Review's Questions, One by One*). One fix departs from its
triage: `PWD` reaches a program as the launcher's shell sets it, which §11 states, and no
compiled launcher is built, decided with the user. A release's notes list no change, and
`ern` refuses no spelling of an earlier toolchain with its replacement (*A Release Carries
No History*).

### MVP 2.99c — the language argued, and Ernest 0.3.0 (done 2026-10-05, tag `v0.3.0`)

The core language argued sound and generated against, before peers build on it (the log's
*The Language Argued Before Peers*). Three machines run in `make test`: programs derived
from Appendix A as data, each parsed, laid out and given as a near miss (*The Grammar
Generated Against*); 101 laws of Appendix E's modules checked on cases drawn afresh (*The
Library's Laws Held*); and well-typed programs built by type, the pure ones held to an
interpreter of the report's rules and the reply discipline's changed at one consumption
(*The Typed Programs Generated*, *The Replies Generated*). [`soundness.md`](soundness.md)
argues that a well-typed program does not go wrong, and closed the ten places where the
reply discipline was short (*The Type System Argued*). What Erlang held that Ernest can
moved into Ernest, and E.0 rule 1's line is three times the host's (*What Erlang Held,
Moved*). The full review read every area on `d90a5b3`, and its 570 findings were worked
before the release (*The full review's findings* above). The release review's machines ran
on `6e07e7d` and the tag (the log's *The Release Review Before 0.3.0*), item 6's readers
serving as its readers; a release's notes list no change (*A Release Carries No History*).

### MVP 2.99d — the library stands on the host, measured (done 2026-10-06)

Every function of the standard library and the libraries is measured beside the host's by a
machine `make bench` runs in seconds, `test/ern_measure.erl`, and the prelude beside the
host's operations (the log's *MVP 2.99d's First Measurements* and *The Prelude Measured*).
E.0 rule 1 changed with the user: its line of three times went, and where a host function
does exactly an operation's work by its page, the operation stands on it (*The Library
Stands on the Host*); a foreign function marks its equality, `a=` (§3, §4.7), and no second
mark lifts its reply restriction. `List`, `String`, `Bytes`, `Map`, `Set` and
`Ets.contains` stand on the host, an operation written as the host's operators is no shim,
and `Path` is read by its code points, as the runtime reads it (E.14). `Clock.now` reads the
host's clock, and no count of a foreign call surrounds a primitive read as waiting on no
process (*The Emitted Code Measured*); `spawn` and `monitor` keep waiting for the reaper,
whose wait holds a spawning loop to its pace (*Spawn Keeps Its Wait*); `Path.<>` is `split`
then `join`, and nothing is kept only for speed: on a value the language owns, an operation
a host function almost does is Ernest alone unless that is past three times the host's (E.0
rule 1, *Kept Only for Speed, Taken Out*). `Fs.removeAll` refused the root and was then
removed, its failure too great to carry (*Fs.removeAll Removed*). `OrderedMap` keeps the key
it holds (E.26), which the laws' draws, read module by module, found. A program's exit is
reported at once, and a fault at the program's end is not reported (§8.6). Four defects of
OTP's are written as reports in [`otp_bugs.md`](otp_bugs.md), the compiler's worked around
meanwhile. The report's and the guide's feedback, the manual pages and the examples made to
teach, shipped as Ernest 0.3.1. The shell's `live_region` test, unmet once, stands in
MVP 4.3.

### The shell shows a bracket's match (done 2026-10-06, ahead of MVP 4.3)

A `)`, `]` or `}` typed at the prompt stands the cursor on the bracket it closes for half a
second or until the next key, as Readline's `blink-matching-paren` does, and a mismatch shows
nothing (§11.2 *Editing*). The compiler's lexer finds the bracket, so a string, a character or
a comment hides what it holds (the log's *The Shell Shows a Bracket's Match*).

### MVP 3.0 — peers (done 2026-10-09)

One program on several nodes, by [`mvp3.0.md`](../proposals/nodes_and_code/mvp3.0.md), kept as
the record of its design; the report's §8.3, §8.7 and §10 own the rules. A node is a program
started with `--config-dir`, identified by its key and listing its peers by name, key and
address; two nodes connect over TLS by the listed key alone, and only under the name the key
gives (the log's *The Carrier*, *MVP 3.0's Findings Decided*); one build on every node, proved
by the handshake. Addresses, monitors, calls and the loss across nodes are the host's, read
and stated (*Addresses, Messages and Monitors Across Nodes*, *Calls Across Nodes*); the
runtime's six frames pass through one gateway with a worker per peer; the node ends in order
and reloads on hangup (*A Node's End and Its Reload*). `Peer` offers a service under a key and
finds it by the configuration's order, spawns on a peer with the function's captures, and
answers one `Failure` (*The Module Peer*); `Load`, `Balancer` and `Json` are the first
libraries written on it (*Load and Balancer*, *The Module Json*). The real-node tests wait on
what they mean, no sleep among them (*The Tests Wait on What They Mean*), and the guide's
chapter 8 teaches peers. The milestone's end weighed what follows it and set the ordered
rolling restart aside (*The Milestones After 3.0, Weighed Again*); the proposals for MVP 3.1
and 3.2 were written and read through (*The Plan Rewritten from the Split Proposals*). Read
without a release by five readers, 93 findings, 87 fixed in item 14, four dropped, one MVP
3.1's (*MVP 3.0's Findings Decided*): a free mailbox type at `Peer.spawn` is `Never`, a local
`fn` spawns as a lambda does, `Peer.nodes` became `Peer.peers`, a peer's name is resolved at
the dial alone, an adapted address dies with its node's start, and the compiler names no
library type. What waits: `Peer.spawn` as an ordinary function, MVP 3.1's item 1; the two
libraries' tests back in their modules, its item 4.

### The principles review again (done 2026-10-09, before MVP 3.1)

Five readers on the most advanced model over the report, the guide, the log since the review of
2026-10-01 and the two proposals, peers read against §0 for the first time; twenty-six
sentences proposed, fifteen accepted into §0, the three files' prefaces, §7.4, §9, §10, §11 and
E.0, and the families decided and built the same day: `Peer.Failure` folded into `Io.Error`,
`Erl.atom` into `Foreign.atom`, `List.remove` by index, `takeLast`, `Float.div`, `foldRight`'s
accumulator first, a constructor named as a type refused, and MVP 3.2's table rule replaced by
a stated limit (the log's *The Principles Review of 2026-10-09* and its *Judgments*).

### MVP 3.1 — code by its hash (done 2026-10-10)

Code by its hash, by [`mvp3.1.md`](../proposals/nodes_and_code/mvp3.1.md), kept as the record
of its design; the report's §8.6, §8.7, §11.1, §11.2, Appendix H, E.23 and G.7 own the rules.
Every definition has a hash, the SHA-256 of its canonical form, which Appendix H states node
by node and `ern_canonical` computes (the log's *The Canonical Form, Built*); a node's code
table reads each unit's `'$code'/0` as it loads (*The Code Table, Built*; positional names
wait for MVP 3.2, *Positional Names Wait for Code That Arrives*); nodes of different builds
connect on one floor, a key naming its type by hash and a spawn its function, so that a find
answers `OtherType` and a spawn `NotLoaded` exactly where the builds disagree (*The Spawn by
Hash, Built*); the shell's `:load` and `:reload` make each version a unit of its own, two
versions of a type two types in one session (*The Shell's Reload by Hash, Built*); a program
is told of its termination and the end waits for its subscribers' answers (*Termination Told,
Built*); `Standing` holds a service's address across its ends, and E.22's refusal names a
child's function run in a restarting function (*Standing and the Refusal, Built*); the costs
are measured and the guide's chapter 8 teaches two builds, the end and `Standing` (*What MVP
3.1 Costs, Measured*). Read without a release by seven readers over `a5747617`, 106 findings:
55 fixed at once, 49 decided one at a time against §0 and built in six batches, two planned
for MVP 3.2 (*MVP 3.1 Read*, *MVP 3.1 Done*): among them a fault while the end waits is the
process's own, a restart cancels the subscription to the end, the wait's lines name the
subscribers by site, a reload reaches the session's own declarations, an input that builds a
function is kept, a `show`'s view and every session declaration are in the form, `ern stop`
waits on the lock the node holds on `ernest.pid`, the floor is `ern`'s minor on OTP's major,
a key is its name and its hash and `Peer.name` reads the name, `Standing` makes one find at a
time and faults on `OtherType`, and the guide's store owns its life. The named decision of its
item 9, whether the end's lines are a node's alone, kept them wherever a program has a
subscriber (`language_feedback.md`'s entry 100, *The Feedback Pass Before MVP 3.2*); that pass
ran before MVP 3.2, MVP 3.25 was added and the back end made last (*A Milestone for Placing
Work by Load*, *The Back End Last*). What waits: `language_feedback.md`'s 97 and 98 and
`:processes`' columns, MVP 4.3's; a unit let go and the bare node, MVP 3.2's.
